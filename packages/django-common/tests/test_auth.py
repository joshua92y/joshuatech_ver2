"""django_common.auth 계약 테스트(T062 · test-first — 짝 구현 T070이 초록으로 만든다).

계약: contracts/identity-admin-api.md §인증 계층 · §호출자 식별 · §웹훅 서명 규약 · §오류 슬러그, contracts/denylist.md
§조회 규약 · §ACL, rules/django-pod.md §Auth · §Dragonfly.
- 순서: Access(Cf-Access-Jwt-Assertion · aud ∈ {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN} · common_name == ACCESS_EXPECTED_CN —
  없거나 실패 403 access_required) → Bearer(JWKS · iss 공개 URL · aud identity-admin · exp · nbf · RS256 — 실패 401
  invalid_token) → AUTH_ACTOR_SUB가 설정된 경우에만 act.sub(불일치 401 invalid_token · 빈 값 = impersonation 모드) →
  거부 목록(revoked:sub:{sub} 값 nbf > iat 또는 revoked:sid:{sid} 존재 → 401 session_revoked · 조회 오류는 종류와
  무관하게 503 denylist_unavailable — fail-closed · 판정 0.2 s · 클라이언트 재시도 0 · 결과 캐시 없음).
- 면제(정확 일치 · 접두 아님): /healthz · /ready · /health · /webhooks/authentik. 웹훅은 HMAC 헬퍼가 대신 검증한다
  (실패는 모두 401 webhook_signature_invalid · 재전송 멱등 저장은 pod — 시험 뷰는 집합 대역).
- 오류는 RFC 9457: Content-Type application/problem+json · type = https://joshuatech.dev/problems/ + 슬러그의 `_`를 `-`로.

T070 가정(계약에 없는 이름·모양 — 설계 D3 · D4 · D5 · T070이 확정한다 · 바꾸면 이 파일 · tests/_jwt.py ·
tests/settings.py · tests/authapp/와 함께):
- 공개 이름: JwtAuthMiddleware(new-style · 설정 문자열 "django_common.auth.JwtAuthMiddleware"로만 단다) · AuthError
  (to_response() = RFC 9457 응답) · WebhookSignatureInvalid(AuthError 하위 · 401 webhook_signature_invalid) ·
  WebhookEvent(frozen dataclass — pk · created(aware datetime) · data(dict)) ·
  verify_authentik_webhook(body: bytes, signature: str | None, *, secret: str, now=None) -> WebhookEvent.
- 설정: AUTHENTIK_ISSUER · AUTHENTIK_JWKS_URL · AUTHENTIK_AUDIENCE · ACCESS_TEAM_DOMAIN(스킴이 있으면 base URL 그대로 ·
  없으면 https:// 접두 — certs = <base>/cdn-cgi/access/certs · Access iss = <base>) · ACCESS_AUD_M2M · ACCESS_AUD_ADMIN ·
  ACCESS_EXPECTED_CN · AUTH_ACTOR_SUB · DRAGONFLY_URL · AUTHENTIK_WEBHOOK_SECRET(이름은 T073). 면제 목록은 라이브러리
  기본값(설정을 두지 않는다). 설정은 미들웨어 인스턴스 생성·요청 시점에 읽는다(import 시 상수 금지) — 테스트는
  설정을 바꾼 뒤 새 Client(make_client)를 만든다.
- 요청 속성(성공 시): request.access_claims(dict) · request.auth_claims(dict) · request.tenant_id(tenant_id 클레임의
  uuid.UUID — 클레임이 없으면 속성 없음 · 403 tenant_required는 T068 TenantContextMiddleware의 몫 · UUID로 파싱되지 않는
  값은 401 invalid_token — auth-31).
- 필수 클레임(options={"require": [...]} — PyJWT 기본은 exp 부재도 허용한다): Bearer exp · iat · sub · aud · iss(sid · act ·
  tenant_id · nbf는 선택 — 있으면 검증·사용 · Authentik access 토큰 모양) · Access exp · iat · aud · iss(nbf 있으면 검증) +
  common_name 필수(ACCESS_EXPECTED_CN과 등호 비교만 — 값의 모양(`<32 hex>.access`)은 검증하지 않는다 · 시험 값은 읽기
  쉬운 가짜다) — auth-30.
- 실패 응답은 미들웨어가 직접 만든다: title(비어 있지 않은 str) · status(int) · detail(선택 · 토큰·비밀·URL 자격 금지).
- Denylist: redis-py from_url(DRAGONFLY_URL, socket_timeout=0.2, socket_connect_timeout=0.2, retry=Retry(NoBackoff(), 0)) ·
  파이프라인 1회 · 지표 denylist_lookup_seconds(Histogram · 레이블 result — 테스트는 result="error"의 _count만 읽는다).
  JWKS 클라이언트(PyJWKClient · 1시간 캐시)는 미들웨어 인스턴스마다 하나씩 만들어 재사용한다.

빨간 상태: 지금은 django.setup()이 testapp 모델의 django_common.tenancy(T068)를 못 찾아 수집 전에 멈춘다. T068 뒤에는
이 모듈의 django_common.auth import가 ModuleNotFoundError다(`pytest tests/test_auth.py -p no:django --collect-only`로
지금 확인할 수 있다) — 둘 다 "구현 없음"이 원인이다.

DB를 쓰지 않는다(django_db 마크 없음 — pg 컨테이너가 뜨지 않고, 미들웨어가 DB에 닿으면 pytest-django가 막는다).
인프라는 conftest의 jwks_server(로컬 JWKS) · dragonfly(ACL 사용자 4) · auth_settings · dragonfly_clean · make_client다.
비밀(ACL 비밀번호 · 자격이 든 URL · 웹훅 비밀)은 세션 랜덤이고 tests/_secret.Secret(repr 가림)으로 감싼다 — pytest가
실패 프레임의 함수 인자를 출력해도 값이 보이지 않는다. 노출 단언은 위치 번호 목록으로 접어 단언한다.
"""

from __future__ import annotations

import json
import secrets
import socket
import threading
import time
from collections.abc import Callable, Iterator
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, Any
from urllib.parse import urlsplit

import pytest
import redis
from django.utils.module_loading import import_string
from prometheus_client import REGISTRY

from django_common.auth import (
    AuthError,
    JwtAuthMiddleware,
    WebhookEvent,
    WebhookSignatureInvalid,
    verify_authentik_webhook,
)
from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    BEARER_SID,
    BEARER_SUB,
    CERTS_PATH,
    JWKS_PATH,
    TENANT_ID,
    WEBHOOK_SIGNATURE_PREFIX,
    access_claims,
    alg_none_token,
    bearer_claims,
    canonical_json,
    hs256_with_public_key,
    mint,
    public_pem,
    sign_webhook,
    webhook_body,
)
from tests._dragonfly import connections_received
from tests._secret import Secret
from tests.authapp.views import SEEN_PKS

if TYPE_CHECKING:
    from django.http import HttpResponse
    from django.test import Client
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, JwksInfo

pytestmark = pytest.mark.usefixtures("auth_settings", "dragonfly_clean")

PROBLEM_TYPE_BASE = "https://joshuatech.dev/problems/"
PROBLEM_CONTENT_TYPE = "application/problem+json"
DENYLIST_UNAVAILABLE_TYPE = "https://joshuatech.dev/problems/denylist-unavailable"  # 과제 문면 그대로
PROTECTED = "/protected"
WEBHOOK_PATH = "/webhooks/authentik"
HEALTH_PATHS = ("/healthz", "/ready", "/health")
SIGNATURE_HEADER = "X-Authentik-Signature"
# 거부 목록 판정 상한(D10): 판정 0.2 s(socket 시간 초과) + 처리 여유 0.3 s(로컬 JWKS 첫 fetch + RS256 검증 2회 —
# 첫 fetch + decode 0.076 s 실측). redis-py 8.1의 재시도 기본값(ExponentialWithJitterBackoff 10회)은 `Redis(...)`
# 생성자에 있다(`from_url`은 retry 인자가 없으면 연결 재시도 0). 그 재시도를 쓴 구현은 닫힌 포트 4.7 s · 응답 없는
# 소켓 6.8 s(클라이언트 실측) · 이 파일의 요청 6.1–6.4 s(2026-11-02 참조 구현 변이 실측)라 상한의 9배 밖에서 걸린다.
# 느린 호스트에서 넘으면 수치를 보고한다(상한은 그대로).
DENYLIST_VERDICT_LIMIT_S = 0.5
# socket 시간 초과가 없는 구현은 응답 없는 소켓에서 영구 대기한다(상한 단언에 닿지도 못한다) → 요청을 데몬 스레드에서
# 돌리고 이 시간 안에 끝나지 않으면 유한한 실패로 끝낸다(리뷰 r1 B-2).
VERDICT_HANG_LIMIT_S = 5.0
DENYLIST_TTL_S = 330  # contracts/denylist.md §키 스키마(access 토큰 TTL 300 s + 30 s)
ERROR_SAMPLE = "denylist_lookup_seconds_count"
WEBHOOK_WINDOW_S = 300  # 계약 §웹훅 서명 규약 — |now − created| > 300 s 거부


@pytest.fixture(autouse=True)
def _fresh_webhook_store() -> Iterator[None]:
    """시험 웹훅 뷰의 멱등 저장소 대역(SEEN_PKS)을 테스트마다 비운다."""
    SEEN_PKS.clear()
    yield
    SEEN_PKS.clear()


@pytest.fixture
def writer(dragonfly: DragonflyInfo) -> Iterator[redis.Redis]:
    """거부 목록 쓰기 클라이언트 — identity-admin 사용자(운영에서 revoked:*를 쓰는 유일한 주체)."""
    client = redis.Redis.from_url(dragonfly.writer_url)
    try:
        yield client
    finally:
        client.close()


def _problem_type(slug: str) -> str:
    """RFC 9457 type URI — 오류 슬러그의 `_`를 `-`로(contracts/bff-api.md 예시 …/problems/session-revoked)."""
    return PROBLEM_TYPE_BASE + slug.replace("_", "-")


def _headers(*, bearer: str | None = None, access: str | None = None) -> dict[str, str]:
    headers: dict[str, str] = {}
    if bearer is not None:
        headers["Authorization"] = f"Bearer {bearer}"
    if access is not None:
        headers["Cf-Access-Jwt-Assertion"] = access
    return headers


def _bearer(jwks: JwksInfo, **overrides: Any) -> str:
    """Authentik 키로 서명한 Bearer 토큰(기본 = 유효 — tests/_jwt.bearer_claims)."""
    return mint(bearer_claims(**overrides), jwks.authentik_key, AUTHENTIK_KID)


def _access(jwks: JwksInfo, **overrides: Any) -> str:
    """Access 키로 서명한 Cf-Access-Jwt-Assertion(기본 = 유효 서비스 토큰 — tests/_jwt.access_claims)."""
    return mint(access_claims(**overrides), jwks.access_key, ACCESS_KID)


def _valid_headers(jwks: JwksInfo) -> dict[str, str]:
    return _headers(bearer=_bearer(jwks), access=_access(jwks))


def _timed_get(client: Client, headers: dict[str, str]) -> tuple[HttpResponse, float]:
    """보호 경로 GET 한 번과 그 경과 시간(초). 토큰은 호출 전에 만들어 두므로 측정에 들지 않는다.

    요청은 데몬 스레드에서 돈다 — VERDICT_HANG_LIMIT_S 안에 끝나지 않으면(socket 시간 초과가 없는 구현 = 영구 대기)
    pytest.fail로 끝낸다. 스레드 안의 예외는 그대로 다시 던진다.
    """
    outcome: list[HttpResponse | BaseException] = []

    def run() -> None:
        try:
            outcome.append(client.get(PROTECTED, headers=headers))
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드에서 다시 던진다
            outcome.append(exc)

    worker = threading.Thread(target=run, name="auth-timed-get", daemon=True)
    start = time.perf_counter()
    worker.start()
    worker.join(VERDICT_HANG_LIMIT_S)
    elapsed = time.perf_counter() - start
    if worker.is_alive():
        pytest.fail(f"판정이 {VERDICT_HANG_LIMIT_S:.0f} s 안에 끝나지 않았다 — socket 시간 초과가 없는 구현인가")
    result = outcome[0]
    if isinstance(result, BaseException):
        raise result
    return result, elapsed


def _post_webhook(client: Client, body: bytes, signature: str | None) -> HttpResponse:
    headers = {} if signature is None else {SIGNATURE_HEADER: signature}
    return client.post(WEBHOOK_PATH, data=body, content_type="application/json", headers=headers)


def _closed_port() -> int:
    """연결을 받지 않는 127.0.0.1 포트 — bind로 번호만 받고 닫는다(Windows는 RST 대신 연결 시간 초과로 끝난다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port: int = probe.getsockname()[1]
    return port


def _unreachable_url(port: int) -> tuple[Secret, Secret]:
    """reader 모양의 접속 URL과 그 비밀번호(세션 랜덤 — 노출 단언용 · Secret). 대상 포트는 Dragonfly가 아니다."""
    password = Secret(secrets.token_urlsafe(16))
    return Secret(f"redis://test-pod:{password}@127.0.0.1:{port}/0"), password


def _password(url: str) -> Secret:
    """자격이 든 redis URL의 비밀번호(Secret — urlsplit이 돌려주는 평범한 str을 다시 가린다)."""
    return Secret(urlsplit(url).password or "")


def _error_count() -> float:
    """denylist_lookup_seconds{result="error"} 관측 수(아직 한 번도 없으면 0)."""
    return REGISTRY.get_sample_value(ERROR_SAMPLE, {"result": "error"}) or 0.0


def _assert_problem(response: HttpResponse, status: int, slug: str) -> dict[str, Any]:
    """RFC 9457 문제 응답 — 상태 · Content-Type problem+json · type 규칙 · title(비어 있지 않은 str) · status ·
    detail(있으면 str).

    단언은 꺼낸 값으로 한다 — 실패 출력에 본문 전체(detail 포함)가 실리지 않게.
    """
    assert response.status_code == status
    assert response["Content-Type"].startswith(PROBLEM_CONTENT_TYPE)
    body: dict[str, Any] = json.loads(response.content)
    problem_type = body.get("type")
    title = body.get("title")
    problem_status = body.get("status")
    detail_is_str = isinstance(body.get("detail", ""), str)
    assert problem_type == _problem_type(slug)
    assert isinstance(title, str) and title != ""
    assert problem_status == status
    assert detail_is_str
    return body


def _assert_no_leak(response: HttpResponse, *needles: str) -> None:
    """needles(토큰 · 비밀번호 · 자격이 든 URL)가 응답 본문과 헤더 어디에도 없다.

    값이 실패 출력에 실리지 않게 두 겹으로 막는다: ① pytest는 실패한 마지막 트레이스백 항목의 함수 인자를 repr로
    찍는다(실측) → 인자 이름 needles를 Secret(repr 가림)으로 다시 묶는다(호출자가 평범한 str을 넘겨도 안전하다) ·
    ② 단언 재작성은 비교 피연산자를 찍는다 → 위치 번호 목록으로 접어 단언한다.
    """
    needles = tuple(Secret(needle) for needle in needles)
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    text = f"{response.content.decode('utf-8', errors='replace')}\n{headers}"
    leaked = [index for index, needle in enumerate(needles) if needle and needle in text]
    assert leaked == [], f"응답에 민감 값이 있다(needles 위치 {leaked})"


# --- Bearer · Access 검증 -------------------------------------------------------------------------------------


def test_auth_1_valid(auth_client: Client, jwks_server: JwksInfo, settings: SettingsWrapper) -> None:
    """auth-1 — 유효 Access + 유효 Bearer → 200 · 뷰가 sub · tenant_id(uuid.UUID) · common_name을 비춘다."""
    assert import_string(settings.MIDDLEWARE[0]) is JwtAuthMiddleware  # 설정 문자열 = 공개 클래스(make_client)
    response = auth_client.get(PROTECTED, headers=_valid_headers(jwks_server))
    assert response.status_code == 200
    assert json.loads(response.content) == {
        "sub": BEARER_SUB,
        "tenant_id": TENANT_ID,
        "tenant_id_is_uuid": True,
        "common_name": settings.ACCESS_EXPECTED_CN,
    }


def test_auth_2_expired(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-2 — Bearer exp = 지금 − 60 s → 401 invalid_token(type …/problems/invalid-token)."""
    now = int(time.time())
    bearer = _bearer(jwks_server, iat=now - 360, exp=now - 60)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    _assert_problem(response, 401, "invalid_token")


def test_auth_3_audience_mismatch(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-3 — Bearer aud = "other"(identity-admin 아님) → 401 invalid_token."""
    bearer = _bearer(jwks_server, aud="other")
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    _assert_problem(response, 401, "invalid_token")


def test_auth_4_issuer_mismatch(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-4 — Bearer iss = 다른 URL(공개 issuer URL 아님) → 401 invalid_token."""
    bearer = _bearer(jwks_server, iss="https://auth.example.test/application/o/other/")
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    _assert_problem(response, 401, "invalid_token")


def test_auth_5_not_yet_valid(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-5 — Bearer nbf = 지금 + 600 s → 401 invalid_token."""
    bearer = _bearer(jwks_server, nbf=int(time.time()) + 600)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    _assert_problem(response, 401, "invalid_token")


def test_auth_6_signing_key(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-6 — 서명 키 이상 → 401 invalid_token: (a) JWKS에 없는 kid · (b) alg 혼동(Authentik 공개 키 PEM을 HS256
    비밀로 쓴 수제 토큰 · kid 유효 — 서명을 검증하지 않거나 kid로 찾은 키를 HMAC 비밀로 받는 구현을 잡는다; PyJWT는
    PEM 모양 HMAC 비밀도 거부하므로 알고리즘 핀의 증명은 아니다 · 토큰 구조는 infra-jwks-3이 자기검사한다) ·
    (c) Access 키로 서명한 Bearer(kid = Authentik kid → 서명 불일치 · kid = Access kid → Authentik JWKS에 없음) ·
    (d) alg none(서명 세그먼트 비어 있음 · kid 유효)."""
    claims = bearer_claims()
    tokens = {
        "a-unknown-kid": mint(claims, jwks_server.authentik_key, "unknown-kid"),
        "b-alg-confusion": hs256_with_public_key(claims, public_pem(jwks_server.authentik_key), AUTHENTIK_KID),
        "c-access-key-authentik-kid": mint(claims, jwks_server.access_key, AUTHENTIK_KID),
        "c-access-key-access-kid": mint(claims, jwks_server.access_key, ACCESS_KID),
        "d-alg-none": alg_none_token(claims, AUTHENTIK_KID),
    }
    access = _access(jwks_server)
    for case, bearer in tokens.items():
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 401, case
        _assert_problem(response, 401, "invalid_token")


def test_auth_7_bearer_missing(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-7 — Access 유효 · Authorization 없음 → 401 invalid_token · Bearer 형식이 아닌 Authorization(Basic) → 401."""
    access = _access(jwks_server)
    _assert_problem(auth_client.get(PROTECTED, headers=_headers(access=access)), 401, "invalid_token")
    basic = {"Authorization": "Basic abc", "Cf-Access-Jwt-Assertion": access}
    _assert_problem(auth_client.get(PROTECTED, headers=basic), 401, "invalid_token")


def test_auth_8_actor_unset(auth_client: Client, jwks_server: JwksInfo, settings: SettingsWrapper) -> None:
    """auth-8 — AUTH_ACTOR_SUB = ""(기본 · impersonation 모드): act가 없어도 200 · act.sub가 무엇이든 200(검사 생략)."""
    assert settings.AUTH_ACTOR_SUB == ""
    access = _access(jwks_server)
    for act in (None, {"sub": "anything"}):
        bearer = _bearer(jwks_server, act=act)
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 200, act


def test_auth_9_actor_set(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """auth-9 — AUTH_ACTOR_SUB = "web-bff-dev"(설정 뒤 새 Client): act.sub 일치 → 200 · 불일치 → 401 invalid_token ·
    act 없음 → 401 invalid_token."""
    settings.AUTH_ACTOR_SUB = "web-bff-dev"
    client = make_client()
    access = _access(jwks_server)

    def get(act: dict[str, str] | None) -> HttpResponse:
        return client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server, act=act), access=access))

    assert get({"sub": "web-bff-dev"}).status_code == 200
    _assert_problem(get({"sub": "other"}), 401, "invalid_token")
    _assert_problem(get(None), 401, "invalid_token")


def test_auth_10_access_missing(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-10 — Access 없음(Bearer 유효) → 403 access_required · 둘 다 없음 → 403(Access를 먼저 본다)."""
    response = auth_client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server)))
    _assert_problem(response, 403, "access_required")
    _assert_problem(auth_client.get(PROTECTED), 403, "access_required")


def test_auth_11_access_audience(
    auth_client: Client, jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """auth-11 — Access aud(배열)가 ACCESS_AUD_M2M · ACCESS_AUD_ADMIN 중 하나를 담으면 200 · 그 외 → 403 access_required."""
    bearer = _bearer(jwks_server)
    m2m, admin = settings.ACCESS_AUD_M2M, settings.ACCESS_AUD_ADMIN
    for aud in ([m2m], [admin], ["other", m2m]):
        access = _access(jwks_server, aud=aud)
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 200, aud
    access = _access(jwks_server, aud=["other"])
    _assert_problem(auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access)), 403, "access_required")


def test_auth_12_common_name(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-12 — Access common_name ≠ ACCESS_EXPECTED_CN → 403 access_required · common_name 없음 → 403."""
    bearer = _bearer(jwks_server)
    for common_name in ("someone-else.access", None):
        access = _access(jwks_server, common_name=common_name)
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 403, common_name
        _assert_problem(response, 403, "access_required")


def test_auth_13_access_invalid(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-13 — Access JWT 검증 실패 → 403 access_required: exp 과거 · iss 다름 · Authentik 키로 서명(kid = Access kid
    → 서명 불일치 · kid = Authentik kid → certs에 없음) · alg 혼동(Access 공개 키 PEM을 HS256 비밀로 · kid 유효 — Access
    검증기는 Bearer와 다른 코드 경로다) · alg none."""
    now = int(time.time())
    tokens = {
        "expired": _access(jwks_server, iat=now - 360, nbf=now - 360, exp=now - 60),
        "other-issuer": _access(jwks_server, iss="https://other-team.cloudflareaccess.com"),
        "authentik-key-access-kid": mint(access_claims(), jwks_server.authentik_key, ACCESS_KID),
        "authentik-key-authentik-kid": mint(access_claims(), jwks_server.authentik_key, AUTHENTIK_KID),
        "alg-confusion": hs256_with_public_key(access_claims(), public_pem(jwks_server.access_key), ACCESS_KID),
        "alg-none": alg_none_token(access_claims(), ACCESS_KID),
    }
    bearer = _bearer(jwks_server)
    for case, access in tokens.items():
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 403, case
        _assert_problem(response, 403, "access_required")


def test_auth_30_required_claims(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-30 — 필수 클레임이 없는 토큰은 거부된다(PyJWT는 require 목록이 없으면 exp 부재도 허용한다 — 영구 유효 토큰 ·
    iat 없는 토큰은 revoked:sub의 nbf > iat 판정 자체가 불가): Bearer exp · iat · sub · aud · iss 각각 없음 → 401
    invalid_token · Access exp · iat · aud · iss 각각 없음 → 403 access_required(Access sub는 서비스 토큰에서 빈 문자열이라
    "없음"을 따로 보지 않는다)."""
    access = _access(jwks_server)
    for claim in ("exp", "iat", "sub", "aud", "iss"):
        bearer = _bearer(jwks_server, **{claim: None})
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 401, f"bearer without {claim}"
        _assert_problem(response, 401, "invalid_token")
    bearer = _bearer(jwks_server)
    for claim in ("exp", "iat", "aud", "iss"):
        access_missing = _access(jwks_server, **{claim: None})
        response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access_missing))
        assert response.status_code == 403, f"access without {claim}"
        _assert_problem(response, 403, "access_required")


def test_auth_31_tenant_claim(auth_client: Client, jwks_server: JwksInfo) -> None:
    """auth-31 — tenant_id 클레임 없음 → 미들웨어는 200이고 request.tenant_id 속성이 없다(403 tenant_required는 T068
    TenantContextMiddleware의 몫 · 뷰는 "None" · tenant_id_is_uuid False를 비춘다) · UUID로 파싱되지 않는 tenant_id(slug)
    → 401 invalid_token(테넌트 컨텍스트에 slug가 닿기 전에 fail-closed)."""
    access = _access(jwks_server)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server, tenant_id=None), access=access))
    assert response.status_code == 200
    echoed = json.loads(response.content)
    assert (echoed["tenant_id"], echoed["tenant_id_is_uuid"]) == ("None", False)
    bearer = _bearer(jwks_server, tenant_id="joshuatech")
    _assert_problem(auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=access)), 401, "invalid_token")


# --- 거부 목록(Dragonfly) -----------------------------------------------------------------------------------------


def test_auth_14_revoked_sub(auth_client: Client, jwks_server: JwksInfo, writer: redis.Redis) -> None:
    """auth-14 — revoked:sub:{sub} 값(nbf) > 토큰 iat → 401 session_revoked · 값 = iat → 200 · 값 = iat − 60 → 200.

    iat는 민팅에 쓴 값을 그대로 쓴다. 같은 Client로 이어서 묻는다 — 401 뒤 200이면 결과를 캐시하지 않은 것이다.
    """
    iat = int(time.time())
    headers = _headers(bearer=_bearer(jwks_server, iat=iat), access=_access(jwks_server))
    key = f"revoked:sub:{BEARER_SUB}"
    writer.set(key, iat + 60, ex=DENYLIST_TTL_S)
    _assert_problem(auth_client.get(PROTECTED, headers=headers), 401, "session_revoked")
    for nbf in (iat, iat - 60):
        writer.set(key, nbf, ex=DENYLIST_TTL_S)
        response = auth_client.get(PROTECTED, headers=headers)
        assert response.status_code == 200, f"nbf = iat {nbf - iat:+d}"


def test_auth_15_revoked_sid(auth_client: Client, jwks_server: JwksInfo, writer: redis.Redis) -> None:
    """auth-15 — revoked:sid:{sid} 존재 → 401 session_revoked · sid 클레임이 없는 토큰은 sid 키와 무관(revoked:sid:other
    가 있어도 200)."""
    access = _access(jwks_server)
    writer.set(f"revoked:sid:{BEARER_SID}", 1, ex=DENYLIST_TTL_S)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server), access=access))
    _assert_problem(response, 401, "session_revoked")
    writer.set("revoked:sid:other", 1, ex=DENYLIST_TTL_S)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server, sid=None), access=access))
    assert response.status_code == 200


def test_auth_16_no_cache(auth_client: Client, jwks_server: JwksInfo, writer: redis.Redis) -> None:
    """auth-16 — 결과 캐시 없음: 같은 Client로 200 → writer가 revoked:sub를 쓰면 바로 다음 요청이 401 session_revoked."""
    iat = int(time.time())
    headers = _headers(bearer=_bearer(jwks_server, iat=iat), access=_access(jwks_server))
    assert auth_client.get(PROTECTED, headers=headers).status_code == 200
    writer.set(f"revoked:sub:{BEARER_SUB}", iat + 60, ex=DENYLIST_TTL_S)
    _assert_problem(auth_client.get(PROTECTED, headers=headers), 401, "session_revoked")


def test_auth_17_denylist_refused(
    make_client: Callable[[], Client],
    jwks_server: JwksInfo,
    dragonfly: DragonflyInfo,
    settings: SettingsWrapper,
) -> None:
    """auth-17 — DRAGONFLY_URL = 닫힌 포트 → 503 denylist_unavailable(problem+json) · 요청 전체 < 0.5 s · 응답에 자격
    (설정 URL · 그 비밀번호 · reader URL · reader 비밀번호)이 없다."""
    url, password = _unreachable_url(_closed_port())
    settings.DRAGONFLY_URL = url
    client = make_client()
    response, elapsed = _timed_get(client, _valid_headers(jwks_server))
    body = _assert_problem(response, 503, "denylist_unavailable")
    problem_type = body["type"]
    assert problem_type == DENYLIST_UNAVAILABLE_TYPE
    assert elapsed < DENYLIST_VERDICT_LIMIT_S, f"판정 {elapsed:.3f} s"
    _assert_no_leak(response, url, password, dragonfly.reader_url, _password(dragonfly.reader_url))


def test_auth_18_denylist_blackhole(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """auth-18 — 응답 없는 소켓(listen만 · accept 없음 — 연결은 성립하고 응답이 없다) → 503 denylist_unavailable · 요청
    전체 < 0.5 s(socket_timeout 0.2 s) · 응답에 자격이 없다. socket 시간 초과가 없는 구현은 _timed_get의 5 s 상한에서
    유한하게 실패한다."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as blackhole:
        blackhole.bind(("127.0.0.1", 0))
        blackhole.listen(1)
        url, password = _unreachable_url(blackhole.getsockname()[1])
        settings.DRAGONFLY_URL = url
        client = make_client()
        response, elapsed = _timed_get(client, _valid_headers(jwks_server))
    _assert_problem(response, 503, "denylist_unavailable")
    assert elapsed < DENYLIST_VERDICT_LIMIT_S, f"판정 {elapsed:.3f} s"
    _assert_no_leak(response, url, password)


def test_auth_19_denylist_noperm(
    make_client: Callable[[], Client],
    jwks_server: JwksInfo,
    dragonfly: DragonflyInfo,
    settings: SettingsWrapper,
) -> None:
    """auth-19 — revoked:* 키 패턴이 없는 사용자(NOPERM) → 503 denylist_unavailable · 요청 전체 < 0.5 s · 응답에 그
    자격이 없다."""
    settings.DRAGONFLY_URL = dragonfly.noperm_url
    client = make_client()
    response, elapsed = _timed_get(client, _valid_headers(jwks_server))
    _assert_problem(response, 503, "denylist_unavailable")
    assert elapsed < DENYLIST_VERDICT_LIMIT_S, f"판정 {elapsed:.3f} s"
    _assert_no_leak(response, dragonfly.noperm_url, _password(dragonfly.noperm_url))


def test_auth_20_error_metric(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """auth-20 — 조회 실패 1회 → denylist_lookup_seconds{result="error"} 관측 수 +1."""
    settings.DRAGONFLY_URL, _ = _unreachable_url(_closed_port())
    client = make_client()
    headers = _valid_headers(jwks_server)
    before = _error_count()
    assert client.get(PROTECTED, headers=headers).status_code == 503
    assert _error_count() == before + 1


def test_auth_21_health_exempt(
    make_client: Callable[[], Client], dragonfly: DragonflyInfo, settings: SettingsWrapper
) -> None:
    """auth-21 — 헬스 3종은 헤더 없이 200 · 거부 목록을 조회하지 않는다: 살아 있는 reader URL에서 헬스 요청 3회 동안
    Dragonfly가 새 연결을 받지 않고(INFO stats total_connections_received 전후 차이 0 — 요청 안에서 열고 닫는 연결도 세므로
    조회하되 오류를 삼키는 구현도 잡는다 · CLIENT LIST id 차집합은 그 연결을 놓친다 — T063 r1) · 닫힌 포트 설정에서도
    200 · error 관측 수 불변."""
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        client = make_client()
        before = connections_received(admin)
        for path in HEALTH_PATHS:
            response = client.get(path)
            assert (path, response.status_code, response.content) == (path, 200, b"ok")
        assert connections_received(admin) - before == 0, "헬스 요청이 Dragonfly에 새 연결을 만들었다"
    finally:
        admin.close()
    settings.DRAGONFLY_URL, _ = _unreachable_url(_closed_port())
    client = make_client()
    before = _error_count()
    for path in HEALTH_PATHS:
        response = client.get(path)
        assert (path, response.status_code, response.content) == (path, 200, b"ok")
    assert _error_count() == before


def test_auth_22_exempt_exact_match(auth_client: Client) -> None:
    """auth-22 — 면제는 정확 일치다: /healthzz · /health/x · /webhooks/authentik/x는 헤더 없이 403 access_required."""
    for path in ("/healthzz", "/health/x", "/webhooks/authentik/x"):
        response = auth_client.get(path)
        assert response.status_code == 403, path
        _assert_problem(response, 403, "access_required")


# --- 웹훅(/webhooks/authentik · HMAC 헬퍼) -------------------------------------------------------------------------
#
# 정규형 HMAC의 한계(계약 §웹훅 서명 규약 그대로 — 테스트가 더 주장하지 않는 것 · 리뷰 r1 B-5):
# ① ±300 s 창 안의 같은 본문·서명 재전송은 HMAC 층이 받아들인다 — pk 멱등(pod 저장 · 보존 기간 ≥ 창의 2배)이 막는다.
#    시험 뷰의 SEEN_PKS는 대역이고 실제 저장·단언은 T066이다.
# ② 정규형은 송·수신이 모두 Python json(ensure_ascii 이스케이프 · 정수 · 문자열 키 · float 없음)이라는 전제다 — authentik
#    매핑도 Python이다(VD-T062-1 · T081). 다른 언어 송신기는 바이트가 달라질 수 있다.
# ③ created 창은 pod 서버 시각 기준이다 — NTP 편차가 창을 잠식한다(시험은 같은 호스트 시각 · 운영 시각 감시는 관측 과제).


def test_auth_23_webhook_accept_duplicate(auth_client: Client, settings: SettingsWrapper) -> None:
    """auth-23 — POST /webhooks/authentik(Access · Bearer 없음 · 유효 HMAC) → 202 · 같은 본문·서명 재전송 → 200 no-op."""
    data = webhook_body()
    body = json.dumps(data).encode()
    signature = sign_webhook(body, settings.AUTHENTIK_WEBHOOK_SECRET)
    first = _post_webhook(auth_client, body, signature)
    assert first.status_code == 202
    assert json.loads(first.content) == {"status": "accepted", "pk": data["pk"]}
    second = _post_webhook(auth_client, body, signature)
    assert second.status_code == 200
    assert json.loads(second.content) == {"status": "duplicate"}


def test_auth_24_webhook_signature_invalid(auth_client: Client, settings: SettingsWrapper) -> None:
    """auth-24 — 서명 헤더 없음 · 다른 비밀로 서명 · `sha256=` 접두 없는 hex · 접두 대문자 · 길이 63 · 비ASCII 문자(latin-1
    범위 — 헤더 값은 latin-1로 디코드되므로 실제로 들어올 수 있고 `hmac.compare_digest(str, str)`는 비ASCII에 TypeError를
    낸다 → 형식 검사 없이 비교하는 구현은 401 대신 500) → 401 webhook_signature_invalid.

    마지막에 같은 본문을 올바른 서명으로 보내 202를 받는다 — 앞의 401이 서명 때문이었음을 보인다.
    """
    body = json.dumps(webhook_body()).encode()
    good = sign_webhook(body, settings.AUTHENTIK_WEBHOOK_SECRET)
    hex_digest = good.removeprefix(WEBHOOK_SIGNATURE_PREFIX)
    cases = {
        "missing": None,
        "other-secret": sign_webhook(body, secrets.token_urlsafe(32)),
        "bare-hex": hex_digest,
        "upper-prefix": "SHA256=" + hex_digest,
        "short": WEBHOOK_SIGNATURE_PREFIX + hex_digest[:-1],
        "non-ascii": WEBHOOK_SIGNATURE_PREFIX + "é" * len(hex_digest),
    }
    for case, signature in cases.items():
        response = _post_webhook(auth_client, body, signature)
        assert response.status_code == 401, case
        _assert_problem(response, 401, "webhook_signature_invalid")
    assert _post_webhook(auth_client, body, good).status_code == 202


def test_auth_25_webhook_window(auth_client: Client, settings: SettingsWrapper) -> None:
    """auth-25 — created가 서버 시각 ±300 s 밖(+301 s · −301 s) → 401 · 안(+299 s · −299 s) → 202(pk는 매번 새로) ·
    tz 없는 created → 401. created는 요청 직전 시각에서 잰다(요청 왕복 ms가 1 s 여유 안에 든다)."""
    secret = settings.AUTHENTIK_WEBHOOK_SECRET
    outside, inside = WEBHOOK_WINDOW_S + 1, WEBHOOK_WINDOW_S - 1
    for offset_s, status in ((outside, 401), (-outside, 401), (inside, 202), (-inside, 202)):
        created = datetime.now(UTC) + timedelta(seconds=offset_s)
        body = json.dumps(webhook_body(created=created.isoformat())).encode()
        response = _post_webhook(auth_client, body, sign_webhook(body, secret))
        assert response.status_code == status, f"created = now {offset_s:+d} s"
        if status == 401:
            _assert_problem(response, 401, "webhook_signature_invalid")
    # datetime.utcnow().isoformat() 모양(tz 없음) — utcnow 자체는 폐기 예정이라 쓰지 않는다.
    naive = datetime.now(UTC).replace(tzinfo=None).isoformat()
    body = json.dumps(webhook_body(created=naive)).encode()
    _assert_problem(_post_webhook(auth_client, body, sign_webhook(body, secret)), 401, "webhook_signature_invalid")


def test_auth_26_helper_canonical(settings: SettingsWrapper) -> None:
    """auth-26 — 헬퍼 직접(HTTP 없음): 정규형 본문 A와 키 역순 · indent=2 본문 B가 같은 서명으로 통과(WebhookEvent의 pk ·
    created · data) · B에서 sub 한 글자를 바꾼 C → WebhookSignatureInvalid · signature=None → WebhookSignatureInvalid
    (AuthError 하위 · to_response()는 401 webhook_signature_invalid 문제 응답)."""
    secret = settings.AUTHENTIK_WEBHOOK_SECRET
    data = webhook_body()
    body_a = canonical_json(data)
    body_b = json.dumps(dict(reversed(data.items())), indent=2).encode()
    assert body_a != body_b
    signature = sign_webhook(body_a, secret)
    for body in (body_a, body_b):
        event = verify_authentik_webhook(body, signature, secret=secret)
        assert isinstance(event, WebhookEvent)
        assert event.pk == data["pk"]
        assert event.created == datetime.fromisoformat(data["created"])
        assert event.data == data
    tampered = {**data, "sub": BEARER_SUB[:-1] + "2"}
    body_c = json.dumps(dict(reversed(tampered.items())), indent=2).encode()
    for case, body, candidate in (("tampered", body_c, signature), ("no-signature", body_a, None)):
        with pytest.raises(WebhookSignatureInvalid) as excinfo:
            verify_authentik_webhook(body, candidate, secret=secret)
        assert isinstance(excinfo.value, AuthError), case
        _assert_problem(excinfo.value.to_response(), 401, "webhook_signature_invalid")


def test_auth_29_helper_body_rejected(settings: SettingsWrapper) -> None:
    """auth-29 — 계약 §웹훅 서명 규약의 나머지 거부 사유(서명은 정규형 그대로 맞게 단다) → WebhookSignatureInvalid:
    본문이 JSON 객체가 아님(배열) · pk 없음 · pk 빈 문자열 · pk가 문자열이 아님 · created 없음 · created 파싱 불가 ·
    created가 문자열이 아님 · 본문이 JSON이 아님.

    다른 예외(KeyError · ValueError · TypeError 등)로 새면 뷰가 401 대신 500을 낸다 — 그 경우 이 테스트는 그 예외로
    실패한다.
    """
    secret = settings.AUTHENTIK_WEBHOOK_SECRET
    signed_cases = {
        "array": json.dumps([webhook_body()]).encode(),
        "no-pk": json.dumps(webhook_body(pk=None)).encode(),
        "empty-pk": json.dumps(webhook_body(pk="")).encode(),
        "int-pk": json.dumps(webhook_body(pk=123)).encode(),
        "no-created": json.dumps(webhook_body(created=None)).encode(),
        "bad-created": json.dumps(webhook_body(created="not-a-date")).encode(),
        "int-created": json.dumps(webhook_body(created=123)).encode(),
    }
    accepted: list[str] = []
    for case, body in signed_cases.items():
        try:
            verify_authentik_webhook(body, sign_webhook(body, secret), secret=secret)
        except WebhookSignatureInvalid:
            continue
        accepted.append(case)
    assert accepted == []
    with pytest.raises(WebhookSignatureInvalid):
        verify_authentik_webhook(b"not json", WEBHOOK_SIGNATURE_PREFIX + "0" * 64, secret=secret)


# --- 응답 모양 · JWKS 캐시 ------------------------------------------------------------------------------------------


def test_auth_27_problem_shape(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """auth-27 — 문제 응답 모양(401 · 403 · 503 각 하나): type 규칙 · title · status · Content-Type problem+json · detail
    (있으면 str)과 응답 어디에도 요청의 Bearer · Access 토큰 문자열이 없다."""
    now = int(time.time())
    expired = _bearer(jwks_server, iat=now - 360, exp=now - 60)
    bearer = _bearer(jwks_server)
    access = _access(jwks_server)
    client = make_client()
    unauthorized = client.get(PROTECTED, headers=_headers(bearer=expired, access=access))
    forbidden = client.get(PROTECTED, headers=_headers(bearer=bearer))
    settings.DRAGONFLY_URL, _ = _unreachable_url(_closed_port())
    unavailable = make_client().get(PROTECTED, headers=_headers(bearer=bearer, access=access))
    cases = (
        (unauthorized, 401, "invalid_token"),
        (forbidden, 403, "access_required"),
        (unavailable, 503, "denylist_unavailable"),
    )
    for response, status, slug in cases:
        _assert_problem(response, status, slug)
        _assert_no_leak(response, expired, bearer, access)


def test_auth_28_jwks_cache(make_client: Callable[[], Client], jwks_server: JwksInfo) -> None:
    """auth-28 — 같은 Client(= 같은 미들웨어 인스턴스)로 유효 요청 2회 → 두 번째 요청은 JWKS · certs를 다시 가져오지
    않는다(PyJWKClient 1시간 캐시 · 인스턴스당 클라이언트 하나)."""
    client = make_client()
    headers = _valid_headers(jwks_server)
    assert client.get(PROTECTED, headers=headers).status_code == 200
    after_first = (jwks_server.hits[JWKS_PATH], jwks_server.hits[CERTS_PATH])
    assert client.get(PROTECTED, headers=headers).status_code == 200
    assert (jwks_server.hits[JWKS_PATH], jwks_server.hits[CERTS_PATH]) == after_first
