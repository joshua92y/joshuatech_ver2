"""시험 인프라 검증(T062) — Django 없이 `pytest tests/test_fixtures_jwks.py -p no:django`로 돈다.

로컬 JWKS 서버(conftest `jwks_server` · ThreadingHTTPServer 127.0.0.1)와 민팅 헬퍼(tests/_jwt.py)가 PyJWT
`PyJWKClient`(research DJANGO-D9 · D10 — `cache_jwk_set=True, lifespan=3600` · RS256)와 맞물리는지를 먼저 고정한다.
tests/test_auth.py의 토큰 단언(auth-1..13 · auth-28)은 이 인프라 위에서 돈다.

Django 설정을 읽지 않도록 설정 기본값을 쓰는 클레임(iss · Access aud · common_name)은 전부 인자로 넘긴다.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
from typing import TYPE_CHECKING

import jwt
import pytest
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientError

from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    BEARER_AUDIENCE,
    JWKS_PATH,
    access_claims,
    alg_none_token,
    bearer_claims,
    hs256_with_public_key,
    mint,
    public_pem,
)

if TYPE_CHECKING:
    from tests.conftest import JwksInfo

ISSUER = "https://issuer.example.test/application/o/identity-admin/"  # 임의 상수(Django 설정 없이)
ACCESS_AUD = "aud-infra-test"
ACCESS_CN = "infra-test-client-id.access"
JWKS_LIFESPAN_S = 3600


def test_infra_jwks_1_authentik(jwks_server: JwksInfo) -> None:
    """infra-jwks-1 — Bearer 민팅 → PyJWKClient(JWKS URL · 1h 캐시) 서명 키 → RS256 decode OK · 두 번째 조회는 fetch 0.

    hit 수는 테스트 시작 값에서의 증가분으로 본다(세션 서버라 다른 테스트가 먼저 조회했을 수 있다).
    """
    claims = bearer_claims(iss=ISSUER)
    token = mint(claims, jwks_server.authentik_key, AUTHENTIK_KID)
    client = PyJWKClient(jwks_server.jwks_url, cache_jwk_set=True, lifespan=JWKS_LIFESPAN_S)
    before = jwks_server.hits[JWKS_PATH]

    key = client.get_signing_key_from_jwt(token)
    decoded = jwt.decode(token, key.key, algorithms=["RS256"], audience=BEARER_AUDIENCE, issuer=ISSUER)
    assert decoded == claims
    assert jwks_server.hits[JWKS_PATH] == before + 1

    assert client.get_signing_key_from_jwt(token).key_id == AUTHENTIK_KID
    assert jwks_server.hits[JWKS_PATH] == before + 1  # 캐시 — 다시 가져오지 않았다


def test_infra_jwks_2_access(jwks_server: JwksInfo) -> None:
    """infra-jwks-2 — Access 민팅(aud 배열 · common_name · sub "") → PyJWKClient(certs URL) decode OK · Authentik 키로
    서명한 토큰은 Access JWKS에서 kid를 못 찾아 PyJWKClientError다."""
    claims = access_claims(iss=jwks_server.base_url, aud=[ACCESS_AUD], common_name=ACCESS_CN)
    assert claims["sub"] == "" and claims["type"] == "app" and claims["aud"] == [ACCESS_AUD]
    token = mint(claims, jwks_server.access_key, ACCESS_KID)
    client = PyJWKClient(jwks_server.certs_url, cache_jwk_set=True, lifespan=JWKS_LIFESPAN_S)

    key = client.get_signing_key_from_jwt(token)
    decoded = jwt.decode(
        token, key.key, algorithms=["RS256"], audience=ACCESS_AUD, issuer=jwks_server.base_url
    )
    assert decoded == claims

    foreign = mint(claims, jwks_server.authentik_key, AUTHENTIK_KID)
    with pytest.raises(PyJWKClientError):
        client.get_signing_key_from_jwt(foreign)


def _b64url_decode(segment: str) -> bytes:
    return base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))


def test_infra_jwks_3_crafted_tokens(jwks_server: JwksInfo) -> None:
    """infra-jwks-3 — 수제 공격 토큰의 구조 자기검사(auth-6 (b)(d) · auth-13의 401/403이 조립 오류 때문이 아니게):
    alg 혼동 토큰은 헤더 {alg HS256 · typ JWT · kid} · 서명 미검증 decode == claims · 서명 세그먼트 == HMAC-SHA256(공개 키
    PEM, signing input)이고, PyJWT는 알고리즘을 RS256으로 고정하면 InvalidAlgorithmError로 거부한다. alg none 토큰은
    헤더 alg none · 빈 서명 세그먼트 · 같은 거부."""
    claims = bearer_claims(iss=ISSUER)
    pem = public_pem(jwks_server.authentik_key)
    confused = hs256_with_public_key(claims, pem, AUTHENTIK_KID)
    assert jwt.get_unverified_header(confused) == {"alg": "HS256", "typ": "JWT", "kid": AUTHENTIK_KID}
    assert jwt.decode(confused, options={"verify_signature": False}) == claims
    header_b64, payload_b64, signature_b64 = confused.split(".")
    expected = hmac.new(pem, f"{header_b64}.{payload_b64}".encode("ascii"), hashlib.sha256).digest()
    assert _b64url_decode(signature_b64) == expected

    none = alg_none_token(claims, AUTHENTIK_KID)
    assert jwt.get_unverified_header(none) == {"alg": "none", "typ": "JWT", "kid": AUTHENTIK_KID}
    assert none.endswith(".") and none.count(".") == 2
    assert jwt.decode(none, options={"verify_signature": False}) == claims

    key = PyJWKClient(jwks_server.jwks_url, cache_jwk_set=True, lifespan=JWKS_LIFESPAN_S).get_signing_key_from_jwt(
        confused
    )
    for token in (confused, none):
        with pytest.raises(jwt.InvalidAlgorithmError):
            jwt.decode(token, key.key, algorithms=["RS256"], audience=BEARER_AUDIENCE, issuer=ISSUER)
