"""시험 공용 JWT · 웹훅 헬퍼(T062 · D7) — conftest · tests/test_fixtures_jwks.py · tests/test_auth.py가 같이 쓴다.

- 키: make_rsa_key()가 세션마다 RSA 2048 개인 키를 만든다(저장소에 키 자료 0 · 생성 0.03 s 실측). to_jwk()는 공개
  키를 JWKS 항목(kid · use sig · alg RS256)으로 바꾼다.
- 민팅: mint(claims, key, kid) = RS256 서명 + 헤더 kid. bearer_claims() · access_claims()는 유효한 기본 클레임을 주고
  override로 바꾼다(값이 None인 override는 그 클레임을 지운다). hs256_with_public_key()는 alg 혼동 공격 토큰(공개 키
  PEM을 HS256 비밀로 쓴 수제 서명 — jwt.encode는 PEM 모양 비밀을 거부한다)을, alg_none_token()은 서명 세그먼트가 빈
  alg none 토큰을 만든다(둘 다 수제 — 라이브러리 정책에 기대지 않는다 · 구조는 tests/test_fixtures_jwks.py가 자기검사).
- 웹훅: webhook_body() = 유효한 Authentik 웹훅 본문 dict · sign_webhook(body_bytes, secret) = `sha256=<hex>`
  (contracts/identity-admin-api.md §웹훅 서명 규약의 정규형 HMAC 그대로).

Django를 모듈 수준에서 import하지 않는다(tests/test_fixtures_jwks.py는 `-p no:django`로 돈다). 클레임 기본값 가운데
설정에서 오는 것(Bearer iss · Access iss · aud · common_name)만 그 키가 override에 없을 때 함수 안에서 읽는다.
시각은 time.time() 정수(초)다.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
import uuid
from datetime import UTC, datetime
from typing import Any

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jwt.algorithms import RSAAlgorithm

# 로컬 JWKS 서버 경로 — Authentik JWKS(운영은 svc DNS `http://authentik-server.identity.svc:9000` 아래 같은 경로) ·
# Cloudflare Access certs(운영은 `https://<team>.cloudflareaccess.com` 아래 같은 경로).
JWKS_PATH = "/application/o/identity-admin/jwks/"
CERTS_PATH = "/cdn-cgi/access/certs"
AUTHENTIK_KID = "authentik-test-1"
ACCESS_KID = "access-test-1"

TOKEN_TTL_S = 300  # access 토큰 TTL(contracts/denylist.md §키 스키마 — 300 s)
BEARER_AUDIENCE = "identity-admin"  # contracts/identity-admin-api.md §인증 계층 2 — aud=identity-admin
BEARER_SUB = "user-sub-1"
BEARER_SID = "sid-1"
TENANT_ID = "00000000-0000-4000-8000-00000000000a"
WEBHOOK_SIGNATURE_PREFIX = "sha256="


def make_rsa_key() -> rsa.RSAPrivateKey:
    """세션용 RSA 2048 개인 키(공개 지수 65537)."""
    return rsa.generate_private_key(public_exponent=65537, key_size=2048)


def public_pem(key: rsa.RSAPrivateKey) -> bytes:
    """개인 키에 짝지어진 공개 키의 PEM(SubjectPublicKeyInfo) — alg 혼동 토큰의 HS256 비밀로 쓴다."""
    return key.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
    )


def to_jwk(public_key: rsa.RSAPublicKey, kid: str) -> dict[str, Any]:
    """공개 키 → JWKS 항목(kty RSA · n · e + kid · use sig · alg RS256)."""
    jwk: dict[str, Any] = json.loads(RSAAlgorithm.to_jwk(public_key))
    jwk.update(kid=kid, use="sig", alg="RS256")
    return jwk


def mint(claims: dict[str, Any], key: rsa.RSAPrivateKey, kid: str, alg: str = "RS256") -> str:
    """claims를 key로 서명한 compact JWT(헤더 kid · typ JWT)."""
    return jwt.encode(claims, key, algorithm=alg, headers={"kid": kid})


def _setting(name: str) -> Any:
    """Django 설정 값 — 함수 안에서 import한다(Django 없는 인프라 테스트는 설정 기본값을 모두 override로 넘긴다)."""
    from django.conf import settings

    return getattr(settings, name)


def _apply(base: dict[str, Any], overrides: dict[str, Any]) -> dict[str, Any]:
    """base에 overrides를 덮고, 값이 None인 키를 지운다."""
    merged = {**base, **overrides}
    return {name: value for name, value in merged.items() if value is not None}


def bearer_claims(**overrides: Any) -> dict[str, Any]:
    """유효한 Authentik access 토큰 클레임.

    iss = settings.AUTHENTIK_ISSUER(공개 URL) · aud identity-admin · sub user-sub-1 · sid sid-1 · iat 지금 ·
    exp 지금 + 300 s · tenant_id 테넌트 A(UUID 문자열). 값이 None인 override는 그 클레임을 지운다.
    """
    now = int(time.time())
    claims: dict[str, Any] = {
        "aud": BEARER_AUDIENCE,
        "sub": BEARER_SUB,
        "sid": BEARER_SID,
        "iat": now,
        "exp": now + TOKEN_TTL_S,
        "tenant_id": TENANT_ID,
    }
    if "iss" not in overrides:
        claims["iss"] = _setting("AUTHENTIK_ISSUER")
    return _apply(claims, overrides)


def access_claims(**overrides: Any) -> dict[str, Any]:
    """유효한 Cloudflare Access 서비스 토큰 JWT 클레임(서비스 토큰 모양 — sub 빈 문자열 · type app · aud 배열).

    iss = settings.ACCESS_TEAM_DOMAIN(시험 값은 스킴이 있는 base URL `http://127.0.0.1:<port>` — T070 가정: 스킴이
    있으면 그 값이 곧 iss) · aud = [settings.ACCESS_AUD_M2M] · common_name = settings.ACCESS_EXPECTED_CN(서비스 토큰
    Client ID 자리) · iat = nbf = 지금 · exp 지금 + 300 s. 값이 None인 override는 그 클레임을 지운다.
    """
    now = int(time.time())
    claims: dict[str, Any] = {"sub": "", "type": "app", "iat": now, "nbf": now, "exp": now + TOKEN_TTL_S}
    if "iss" not in overrides:
        claims["iss"] = _setting("ACCESS_TEAM_DOMAIN")
    if "aud" not in overrides:
        claims["aud"] = [_setting("ACCESS_AUD_M2M")]
    if "common_name" not in overrides:
        claims["common_name"] = _setting("ACCESS_EXPECTED_CN")
    return _apply(claims, overrides)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_json(obj: dict[str, Any]) -> str:
    return _b64url(json.dumps(obj, separators=(",", ":")).encode("utf-8"))


def hs256_with_public_key(claims: dict[str, Any], public_key_pem: bytes, kid: str) -> str:
    """alg 혼동 공격 토큰 — 헤더 alg HS256 + kid, 서명 = HMAC-SHA256(공개 키 PEM, signing input).

    검증 쪽이 알고리즘을 RS256으로 고정하지 않고 kid로 찾은 공개 키를 HMAC 비밀로 쓰면 통과해 버리는 토큰이다.
    """
    header = {"alg": "HS256", "typ": "JWT", "kid": kid}
    signing_input = f"{_b64url_json(header)}.{_b64url_json(claims)}"
    signature = hmac.new(public_key_pem, signing_input.encode("ascii"), hashlib.sha256).digest()
    return f"{signing_input}.{_b64url(signature)}"


def alg_none_token(claims: dict[str, Any], kid: str) -> str:
    """alg none 토큰 — 헤더 alg none + kid, 서명 세그먼트는 비어 있다(`header.payload.`).

    서명 없는 토큰을 받아들이는(알고리즘을 고정하지 않은) 검증기만 통과시키는 토큰이다.
    """
    header = {"alg": "none", "typ": "JWT", "kid": kid}
    return f"{_b64url_json(header)}.{_b64url_json(claims)}."


def webhook_body(**overrides: Any) -> dict[str, Any]:
    """유효한 Authentik 웹훅 본문 — pk(새 uuid4 문자열 · 멱등 키) · created(지금 · aware ISO 8601) · action logout ·
    sub · sid. 값이 None인 override는 그 키를 지운다."""
    body: dict[str, Any] = {
        "pk": str(uuid.uuid4()),
        "created": datetime.now(UTC).isoformat(),
        "action": "logout",
        "sub": BEARER_SUB,
        "sid": BEARER_SID,
    }
    return _apply(body, overrides)


def canonical_json(obj: Any) -> bytes:
    """계약 §웹훅 서명 규약의 정규형 — sort_keys · separators (",", ":") · ensure_ascii."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def sign_webhook(body: bytes, secret: str) -> str:
    """X-Authentik-Signature 값 `sha256=<hex 소문자>` = HMAC-SHA256(secret, 정규형(json.loads(body)))."""
    digest = hmac.new(secret.encode(), canonical_json(json.loads(body)), hashlib.sha256).hexdigest()
    return WEBHOOK_SIGNATURE_PREFIX + digest
