"""django_common.auth 계약 시험(T070 소유 · D11 ac-1..22) — T062 tests/test_auth.py(auth-1..32)가 고정하지 않은 결정을 가른다.

설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T070」(사실 ①–⑨ · 계약 보정 C1–C4 · 결정 D1–D14). 계약:
contracts/pod-template.md §런타임 계약 「인증」 · §django-common 공개 API · contracts/identity-admin-api.md §인증 계층 ·
§웹훅 서명 규약 · §오류 슬러그 · contracts/denylist.md §조회 규약(「T070 보정 2026-11-05」) · 규칙 .claude/rules/django-pod.md
§Auth · §Settings · §Errors · §Dragonfly.

- 공개 API · 오류 형(D2 · D8 · D10): __all__ 정확히 14(r3 check_settings 포함) · sync 전용 · 오류 형 표 · to_response = RFC
  9457(detail 없음 · 추가 헤더 없음 · 예외 인자를 싣지 않는다)(ac-1).
- 판정 순서(D2): 호스트 선행(ac-2) · 경로 설정 타입 검사 · 요청마다 읽기 · 면제 우선(ac-3) · 요청 속성(실패 · 면제 · Access
  전용 · 앞선 미들웨어가 둔 값 제거 — ac-17) · 설정을 요청마다 읽는다(ac-18) · 동시 실패 우선순위(ac-22).
- Access(D3): 팀 도메인 스킴 처리 · 루프백 밖 http 거부 · 꼴 검사 · 끝 슬래시 · 스킴 대소문자(ac-4) · 빈 ACCESS_AUD_ADMIN
  제외(ac-5) · leeway 5 s · 미래 nbf · iat(ac-11) · AccessJwtValidator 공개 API(ac-19).
- Bearer(D4): Authorization 꼴(ac-11) · 클레임 모양(빈 · 비str sub · sid · 비정규 tenant_id · act — ac-10).
- 키 가져오기(D5): fetch 실패 503 + WARNING 한 줄(ac-6) · 모르는 kid = 토큰 결함 · cooldown 안 재조회 없음(ac-7) · 1시간 캐시 ·
  만료 뒤 fetch 실패 503(ac-8) · cooldown 뒤 재조회 실패 503(ac-9) · 새 인스턴스 = 새 fetch(ac-21).
- 설정(D6): 필수 설정(빈 값 · 없음 · str 아님 → ImproperlyConfigured 이름만 · 연쇄 없음) · 키 URL 스킴 · 선택 설정(ac-5).
- 거부 목록(D7): 값이 정수가 아님 · URL 쿼리 = 503 + WARNING(ac-12) · Denylist 공개 API · 파이프라인 1회 · 결과 캐시 없음 ·
  메시지에 키 없음(ac-13) · 지표 레이블 ok · revoked · error(ac-14).
- 웹훅(D9): 빈 비밀 · 대문자 hex · Z · ±300 s 경계 · 깊은 중첩 · 비UTF-8 · UTF-16 · BOM · now · 값 없음(ac-15).
- import · 생성 부작용 0(ac-16) · 로그(D12): 판정마다 로그 없음(ac-20) · 의존성 장애만 WARNING 한 줄(ac-6 · ac-8 · ac-12 ·
  ac-13).
- r2 추가(리뷰 r1 반영 · build-notes 「T070 r1 결과 · r2 결정」 N1 · N3 · N4 · N9): 거부 판정 조합 — 오래된 sub 키 + 폐기 sid
  (ac-13 · ac-13b) · 거부 목록 클라이언트 재사용(ac-13c) · 면제 · Access 전용 = path_info 정확 일치(SCRIPT_NAME — ac-3c) ·
  auth_claims = 검증한 payload 전체(ac-17 · ac-17b) · 키 fetch 상한 2.8 s(timeout 2 s와 3 s를 가른다 — ac-4a · ac-6b) · 팀
  기준 URL 정규형(호스트 소문자 · 기본 · 빈 포트 · IPv6 다시 감싸기 — ac-4d) · 공백 · 제어 문자 · 비ASCII · 밑줄 · 괄호 호스트 ·
  빈 쿼리 · 조각 거부(ac-4e).
- r3 추가(리뷰 r2 반영 · build-notes 「T070 r2 결과 · r3 결정」 U1–U4): 웹훅 body는 bytes만(int · list · memoryview · bytearray ·
  str → TypeError — ac-15) · 팀 기준 URL 호스트 = LDH 이름 · 포트 1–65535(끝 점 · 빈 라벨 · 앞 점 · 앞 · 끝 하이픈 라벨 · 64자
  라벨 · 254자 호스트 · 숫자만인 마지막 라벨 · 포트 0 거부 — ac-4e / xn-- 라벨 · 숫자가 섞인 라벨 · 63자 라벨 · 253자 호스트 ·
  루프백 https 수락 — ac-4d) · 공개 check_settings()(좋은 설정 None · 네트워크 0 · 요청 때 설정 오류가 되는 값 전부와 DRAGONFLY_URL
  쿼리 · 생성 실패를 거부 · 순서 고정 — ac-23) · 키 fetch 실패 백오프(창 안은 fetch 0 · 503 error=backoff · 창 1 → 2 → … → 30 s ·
  성공하면 초기화 · 캐시 적중은 영향 없음 · 동시 요청 fetch 1 — ac-24 · ac-8 조정).
- r4 추가(리뷰 r3 반영 · build-notes 「T070 r3 결과 · r4 결정」 V1–V4): 팀 기준 URL 마지막 라벨의 16진 숫자 꼴(`0x` + 16진 숫자 ·
  빈 것 포함 — 0x7f000001 · 127.0.0.0x1 · 169.254.169.0xfe · a.0x1 · 0x) 거부 — ac-4e / 마지막이 아닌 `0x…` 라벨 · 16진이 아닌
  `0x…` 마지막 라벨 수락 — ac-4d · 인증 문자열 설정은 공백 없는 출력 가능 ASCII(`!`–`~`)만(끝 줄바꿈 · 앞 · 가운데 공백 · 탭 ·
  NBSP · 폭 0 · BOM · 한글 채움 문자 · 키릴 동형 글자 → 설정 오류 — ac-5a · ac-5b · ac-5c · ac-23b) · check_settings 순서를 깊은
  오류 값으로 한 번 더(JWKS 스킴 · DRAGONFLY_URL 쿼리 검사의 자리까지 — ac-23d) · 백오프 잠금은 자기 잠금(PyJWT `_client_lock`이
  없거나 재진입 불가 Lock이어도 창이 열리고 · 멈추지 않고 · fetch를 직렬화한다 — ac-24e · ac-24f · ac-24g).
- r5 추가(리뷰 r4 반영 · build-notes 「T070 r4 결과 · r5 결정」 W1 · W3): 인증 문자열 설정 값 꼴에 공백이 아닌 ASCII 제어 문자
  ESC · DEL(ac-5a · ac-5b · ac-5c · ac-23b — 「ASCII이고 공백이 아니면 받는다」 규칙과 상한에 DEL을 넣은 범위를 가른다) · 팀
  도메인에 폭 0 · BOM · 한글 채움 문자(ac-4e · ac-23b) · 빈 캐시 + 느린 성공 fetch + 동시 5건 → fetch 1 · 모두 통과(중복 제거는
  PyJWT 잠금 몫이다 — 실제 PyJWT 부모 · ac-24h).
- r6 추가(리뷰 r5 반영 · build-notes 「T070 r5 결과 · r6 결정」 X1): 인증 문자열 설정의 수락 쪽 경계(`!` U+0021 · `~` U+007E) —
  자유 꼴 6개에 공백 없는 출력 가능 ASCII 94자 전부 · 경로에 `~` · `!` · 하위 구분자가 든 루프백 JWKS URL · 비밀번호 자리에
  같은 글자가 든 DRAGONFLY_URL → check_settings() None · 네트워크 0(ac-23e) · ACCESS_EXPECTED_CN 94자 + 같은 common_name을
  실은 Access 토큰 → 200 · 마지막 글자를 뺀 common_name → 403(요청 경로 대조 — ac-5d). `!` · `~`를 거부하는 경계 변이(M125 ·
  M126)는 r5 사례 목록을 전부 통과했다.

인프라는 T062 conftest 그대로다(jwks_server · dragonfly · auth_settings · dragonfly_clean · make_client) — DB를 쓰지 않는다
(django_db 마크 없음). T070 도우미는 tests/_auth_fakes.py(키 서버 · 첫 바이트 서버 · 블랙홀 · PyJWT 캐시 시계 대역 · 이름 조회
가드) · tests/authcontractapp/(handler400 · 속성 비춤 뷰 · 속성 탐침 미들웨어)다. 시험 주소는 전부 127.0.0.1 · IP 리터럴이고
모든 시험에 이름 조회 가드가 걸린다(IP 리터럴이 아닌 이름 조회를 막고 기록 — 끝에 0을 단언한다 · 공개 DNS 조회 0).
값 없음 단언은 입력(설정 값 · 토큰 · 키 서버 오류 본문 · URL 쿼리 · 웹훅 비밀 · 본문 · 거부 목록 sub)에 감시 문자열 SENTINEL을
심어 공허하지 않게 한다(T069 J9). 이름에 비밀 낱말을 쓰지 않는다(gitleaks generic-api-key). 노출 단언은 위치 번호 목록으로
접는다(값이 실패 출력에 실리지 않게). pytest는 한 번에 하나만 돌린다.

빨간 상태: T070 구현 전에는 모듈 머리의 `from django_common import auth`가 ImportError(cannot import name 'auth' — 원인은
모듈 부재 · 수집 단계)다(tests/test_auth.py는 같은 원인으로 ModuleNotFoundError).
"""

from __future__ import annotations

import json
import logging
import os
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
import uuid
from collections.abc import Callable, Iterator
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING, Any
from urllib.parse import urlsplit

import jwt
import pytest
import redis
from django.core.exceptions import ImproperlyConfigured
from django.test import Client
from prometheus_client import REGISTRY

from django_common import auth
from django_common.auth import (
    AccessJwtValidator,
    AccessRequired,
    AuthError,
    AuthKeysUnavailable,
    Denylist,
    DenylistRecord,
    DenylistUnavailable,
    InvalidToken,
    JwtAuthMiddleware,
    SessionRevoked,
    WebhookEvent,
    WebhookSignatureInvalid,
    verify_authentik_webhook,
)
from tests._auth_fakes import (
    FirstByteServer,
    KeyServer,
    blackhole,
    closed_port,
    install_lockless_parent,
    install_plain_lock_parent,
    install_shifted_clock,
    name_lookups,
)
from tests._dragonfly import connections_received
from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    BEARER_SID,
    BEARER_SUB,
    CERTS_PATH,
    JWKS_PATH,
    TENANT_ID,
    access_claims,
    bearer_claims,
    mint,
    sign_webhook,
    to_jwk,
    webhook_body,
)
from tests._problem import assert_problem
from tests._secret import Secret
from tests.authcontractapp.middleware import ATTRS_HEADER, AUTH_ATTRIBUTES, SPOOF_HEADER

if TYPE_CHECKING:
    from django.http import HttpResponse
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, JwksInfo

pytestmark = pytest.mark.usefixtures("auth_settings", "dragonfly_clean")

SENTINEL = "ac-sentinel-4c9e1f07"  # 감시 문자열(설정 값 · 서버 오류 본문 · URL 쿼리 · 웹훅 비밀 · sub 자리) — 출력에 나오면 실패
PACKAGE_ROOT = Path(__file__).resolve().parents[1]
LOGGER = "django_common.auth"
AUTH_MIDDLEWARE = "django_common.auth.JwtAuthMiddleware"
PROBE_MIDDLEWARE = "tests.authcontractapp.middleware.AttributeProbeMiddleware"
CONTRACT_URLCONF = "tests.authcontractapp.urls"
PROTECTED = "/protected"
ACCESS_ONLY = "/access-only"
OPEN = "/open"
HEALTHZ = "/healthz"
BAD_HOST = "evil.invalid"  # ALLOWED_HOSTS 밖(pytest-django는 testserver만 더한다) — 헤더 값일 뿐 조회하지 않는다
ACTOR = "web-bff-dev"
SPOOF_TENANT = uuid.UUID("00000000-0000-4000-8000-0000000000ff")
DENYLIST_TTL_S = 330
LOOKUP_SAMPLE = "denylist_lookup_seconds_count"
# 키 fetch 시간 초과 2 s(D5 — 소켓 동작마다) + 처리 여유 0.8 s. 응답 없는 소켓의 판정 시간은 timeout과 거의 같아 2.8 s는
# timeout 2 s와 3 s를 가르고(T070 r2 N3 · 변이 M35b) BFF 예산 3 s보다 작다. PyJWKClient 기본 timeout 30 s면 30 s를 기다린다.
KEY_FETCH_LIMIT_S = 2.8
HANG_LIMIT_S = 15.0
# 키 fetch 실패 백오프(T070 r3 U4) — 연속 실패 1..7번째 뒤의 창(1 s에서 직전 창의 2배 · 30 s 상한). 창 끝 앞뒤를 BACKOFF_PROBE_S
# 여유로 잰다(백오프 시계는 ShiftedClock — 실제 시계는 시험 동안 ms 단위로만 흐른다).
BACKOFF_WINDOWS_S = (1, 2, 4, 8, 16, 30, 30)
BACKOFF_PROBE_S = 0.25
SLOW_FETCH_S = 0.4  # 동시 요청 시험의 메모리 안 fetch 실패 시간(r2 리뷰 B-1 재현 대역 · 실제 대기)
CONCURRENT_REQUESTS = 5
# 백오프 잠금 시험(T070 r4 V4) — 재진입 불가 부모 잠금에서 판정이 끝나기를 기다리는 상한(교착이면 이 시간 뒤 실패 · 정상은 ms
# 단위) · 잠금 없는 부모의 동시 요청 시험에서 fetch가 실패하기까지의 메모리 안 지연(실제 대기).
LOCK_HANG_LIMIT_S = 2.0
LOCK_FETCH_S = 0.2
# 느린 성공 fetch 시험(T070 r5 W3 · ac-24h) — 키 서버가 certs 응답 전에 기다리는 시간(루프백 · 실제 대기). 동시 판정 가운데 가장
# 늦은 것이 이 시간의 2배보다 짧아야 한다(중복 제거가 없으면 fetch가 요청 수만큼 직렬로 돌아 0.3 · 0.6 · … · 1.5 s 계단이다).
SLOW_SUCCESS_FETCH_S = 0.3
PUBLIC_NAMES = frozenset(
    {
        "AccessJwtValidator",
        "AccessRequired",
        "AuthError",
        "AuthKeysUnavailable",
        "Denylist",
        "DenylistRecord",
        "DenylistUnavailable",
        "InvalidToken",
        "JwtAuthMiddleware",
        "SessionRevoked",
        "WebhookEvent",
        "WebhookSignatureInvalid",
        "check_settings",
        "verify_authentik_webhook",
    }
)
ERROR_TABLE: dict[type[AuthError], tuple[str, int]] = {
    InvalidToken: ("invalid_token", 401),
    AccessRequired: ("access_required", 403),
    SessionRevoked: ("session_revoked", 401),
    DenylistUnavailable: ("denylist_unavailable", 503),
    AuthKeysUnavailable: ("auth_keys_unavailable", 503),
    WebhookSignatureInvalid: ("webhook_signature_invalid", 401),
}
# D6 — 비어 있으면 안 되는 설정(없거나 비거나 str이 아니면 요청 때 ImproperlyConfigured).
REQUIRED_SETTINGS = (
    "AUTHENTIK_ISSUER",
    "AUTHENTIK_JWKS_URL",
    "AUTHENTIK_AUDIENCE",
    "ACCESS_TEAM_DOMAIN",
    "ACCESS_AUD_M2M",
    "ACCESS_EXPECTED_CN",
    "DRAGONFLY_URL",
)
REQUIRED_SETTING_STATES = ("empty", "missing", "not-str")  # ac-5a — 빈 값 · 없음 · str 아님(감시 문자열을 담은 목록)
PATH_SETTINGS = ("AUTH_EXEMPT_PATHS", "AUTH_ACCESS_ONLY_PATHS")  # ac-3a — 경로 목록 설정(형 검사)
OPTIONAL_SETTINGS = ("ACCESS_AUD_ADMIN", "AUTH_ACTOR_SUB")  # ac-5b — 빈 값이 유효한 설정(str이 아니면 설정 오류)
KEY_FAILURE_MODES = ("status-500", "not-json", "non-object", "empty-keys", "no-signing-keys")
# D12 — 의존성 장애 WARNING 한 줄의 꼴(이벤트 이름 · 출처 · 예외 클래스 또는 사유 낱말 — 값 없음).
WARNING_LINE = re.compile(
    r"auth\.(?:keys_unavailable source=(?:access|authentik)|denylist_unavailable source=denylist)"
    r" error=[A-Za-z_][A-Za-z0-9_]*"
)


# --- 픽스처 · 도우미 ---------------------------------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _no_name_lookups(monkeypatch: pytest.MonkeyPatch) -> Iterator[None]:
    """모든 시험 — IP 리터럴이 아닌 이름 조회를 막고 기록한다(구현 · 시험 · 도우미의 공개 DNS 조회 0 — 끝에 0을 단언)."""
    with name_lookups(monkeypatch) as attempts:
        yield
    assert len(attempts) == 0, f"이름 조회 시도 {len(attempts)}건"


@pytest.fixture
def contract_client(settings: SettingsWrapper) -> Callable[..., Client]:
    """T070 계약 urlconf(handler400 · 속성 비춤 뷰)의 시험 Client를 만드는 함수 — probe=True면 MIDDLEWARE 맨 앞에 속성
    탐침을 둔다(Client는 첫 요청 때 미들웨어를 적재한다 — 만든 직후에 쓴다)."""

    def make(*, probe: bool = False) -> Client:
        settings.MIDDLEWARE = [PROBE_MIDDLEWARE, AUTH_MIDDLEWARE] if probe else [AUTH_MIDDLEWARE]
        settings.ROOT_URLCONF = CONTRACT_URLCONF
        return Client()

    return make


@pytest.fixture
def writer(dragonfly: DragonflyInfo) -> Iterator[redis.Redis]:
    """거부 목록 쓰기 클라이언트 — identity-admin 사용자(운영에서 revoked:*를 쓰는 유일한 주체)."""
    client = redis.Redis.from_url(dragonfly.writer_url)
    try:
        yield client
    finally:
        client.close()


@pytest.fixture
def df_admin(dragonfly: DragonflyInfo) -> Iterator[redis.Redis]:
    """Dragonfly admin 클라이언트 — 연결 수 · 명령 통계 관측용."""
    client = redis.Redis.from_url(dragonfly.admin_url)
    try:
        yield client
    finally:
        client.close()


@pytest.fixture
def key_server(jwks_server: JwksInfo) -> Iterator[KeyServer]:
    """모드를 바꿀 수 있는 키 서버 — 세션 서명 키 둘의 공개 키(같은 kid)를 서빙한다(세션 토큰이 그대로 통한다)."""
    documents = {
        JWKS_PATH: {"keys": [to_jwk(jwks_server.authentik_key.public_key(), AUTHENTIK_KID)]},
        CERTS_PATH: {"keys": [to_jwk(jwks_server.access_key.public_key(), ACCESS_KID)]},
    }
    server = KeyServer(documents, SENTINEL)
    try:
        yield server
    finally:
        server.close()


def _bearer(jwks: JwksInfo, **overrides: Any) -> str:
    return mint(bearer_claims(**overrides), jwks.authentik_key, AUTHENTIK_KID)


def _access(jwks: JwksInfo, **overrides: Any) -> str:
    return mint(access_claims(**overrides), jwks.access_key, ACCESS_KID)


def _headers(*, bearer: str | None = None, access: str | None = None) -> dict[str, str]:
    headers: dict[str, str] = {}
    if bearer is not None:
        headers["Authorization"] = f"Bearer {bearer}"
    if access is not None:
        headers["Cf-Access-Jwt-Assertion"] = access
    return headers


def _valid_headers(jwks: JwksInfo) -> dict[str, str]:
    return _headers(bearer=_bearer(jwks), access=_access(jwks))


def _unreachable_url(port: int) -> Secret:
    """reader 모양의 접속 URL(세션 랜덤 비밀번호 · Secret) — 대상 포트는 Dragonfly가 아니다."""
    return Secret(f"redis://test-pod:{secrets.token_urlsafe(16)}@127.0.0.1:{port}/0")


def _password(url: str) -> Secret:
    return Secret(urlsplit(url).password or "")


def _response_text(response: HttpResponse) -> Secret:
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    return Secret(f"{response.content.decode('utf-8', errors='replace')}\n{headers}")


def _assert_absent(text: str, *needles: str) -> None:
    """needles(토큰 · 비밀번호 · 자격이 든 URL · 감시 문자열)가 text에 없다 — 위치 번호 목록으로 접어 단언한다(값이 실패
    출력에 실리지 않게 · 인자를 Secret으로 다시 묶는다)."""
    text = Secret(text)
    needles = tuple(Secret(needle) for needle in needles)
    leaked = [index for index, needle in enumerate(needles) if needle and needle in text]
    assert leaked == [], f"민감 값이 있다(needles 위치 {leaked})"


def _assert_names_only(error: BaseException, name: str) -> None:
    """설정 오류(D6): 메시지에 설정 이름이 있고 값(감시 문자열)이 없다 · 연쇄 예외 없음(원인 · 문맥 둘 다)."""
    text = Secret(f"{error}\n{error.args!r}")
    assert name in text
    _assert_absent(text, SENTINEL)
    assert (error.__cause__, error.__context__) == (None, None)


def _assert_no_chain(error: BaseException) -> None:
    assert (error.__cause__, error.__context__) == (None, None)


def _lookup_count(result: str) -> float:
    """denylist_lookup_seconds{result} 관측 수(아직 없으면 0)."""
    return REGISTRY.get_sample_value(LOOKUP_SAMPLE, {"result": result}) or 0.0


def _auth_records(caplog: pytest.LogCaptureFixture) -> list[logging.LogRecord]:
    return [record for record in caplog.records if record.name == LOGGER or record.name.startswith(LOGGER + ".")]


def _error_words(caplog: pytest.LogCaptureFixture) -> list[str]:
    """django_common.auth 기록의 `error=` 값 차례(줄의 꼴은 _assert_warning_lines가 본다)."""
    return [record.getMessage().split(" error=")[1] for record in _auth_records(caplog)]


def _assert_warning_lines(caplog: pytest.LogCaptureFixture, *prefixes: str) -> None:
    """django_common.auth 기록 = WARNING 줄들 — 차례로 prefixes로 시작하고 꼴(WARNING_LINE)에 맞는다(값 없음)."""
    records = _auth_records(caplog)
    assert [record.levelno for record in records] == [logging.WARNING] * len(prefixes)
    messages = [record.getMessage() for record in records]
    assert [WARNING_LINE.fullmatch(message) is not None for message in messages] == [True] * len(prefixes)
    assert [message.split(" error=")[0] for message in messages] == list(prefixes)


def _timed(call: Callable[[], HttpResponse]) -> tuple[HttpResponse, float]:
    """call()을 데몬 스레드에서 돌려 (응답 · 경과 초) — HANG_LIMIT_S 안에 끝나지 않으면 유한하게 실패한다."""
    outcome: list[HttpResponse | BaseException] = []

    def run() -> None:
        try:
            outcome.append(call())
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드에서 다시 던진다
            outcome.append(exc)

    worker = threading.Thread(target=run, name="auth-contract-timed", daemon=True)
    start = time.perf_counter()
    worker.start()
    worker.join(HANG_LIMIT_S)
    elapsed = time.perf_counter() - start
    if worker.is_alive():
        pytest.fail(f"요청이 {HANG_LIMIT_S:.0f} s 안에 끝나지 않았다")
    result = outcome[0]
    if isinstance(result, BaseException):
        raise result
    return result, elapsed


# --- 공개 API · 오류 형(D2 · D8 · D10) ---------------------------------------------------------------------------------


def test_ac_1_public_api_and_error_types() -> None:
    """ac-1 — 공개 이름 = __all__ 정확히 14(D2 — Bearer 검증 단계 · Ninja auth callable은 공개하지 않는다 · D10 · r3 U3가
    check_settings를 더했다) · JwtAuthMiddleware sync 전용 · 오류 형 표(D8: 하위 여섯은 AuthError 하위 · slug · status) ·
    to_response() = RFC 9457 problem+json(detail 없음 · 헤더는 Content-Type 하나 — WWW-Authenticate 등 없음 · 예외
    인자(감시 문자열)를 싣지 않는다)."""
    assert set(auth.__all__) == PUBLIC_NAMES
    assert [name for name in sorted(PUBLIC_NAMES) if not hasattr(auth, name)] == []
    assert (JwtAuthMiddleware.sync_capable, JwtAuthMiddleware.async_capable) == (True, False)
    for error_type, (slug, status) in ERROR_TABLE.items():
        assert issubclass(error_type, AuthError), error_type.__name__
        error = error_type(SENTINEL)
        assert (error.slug, error.status) == (slug, status), error_type.__name__
        response = error.to_response()
        body = assert_problem(response, status, slug)
        assert "detail" not in body, error_type.__name__
        assert [name.lower() for name, _ in response.items()] == ["content-type"], error_type.__name__
        _assert_absent(_response_text(response), SENTINEL)


# --- 판정 순서 · 경로 설정 · 요청 속성(D2) -----------------------------------------------------------------------------


def test_ac_2_host_is_checked_before_credentials(
    contract_client: Callable[..., Client],
    jwks_server: JwksInfo,
    df_admin: redis.Redis,
    settings: SettingsWrapper,
) -> None:
    """ac-2 — 호스트 선행(D2 ①): ALLOWED_HOSTS 밖 Host → 업무 경로 · Access 전용 경로는 자격과 무관하게 400 invalid_host
    (요청 urlconf의 handler400 — 자격 없는 요청도 403이 아니다) · 그 동안 Access certs · Authentik JWKS fetch 0 · Dragonfly 새
    연결 0(호스트를 자격보다 먼저 본다) · 면제 경로(/healthz)는 호스트를 보지 않는다(200 — 프로브 Host = pod IP는 T072) ·
    양성 대조: 허용 호스트면 같은 자격으로 200."""
    settings.AUTH_ACCESS_ONLY_PATHS = (ACCESS_ONLY,)
    client = contract_client()
    full = _valid_headers(jwks_server)
    hits_before = (jwks_server.hits[JWKS_PATH], jwks_server.hits[CERTS_PATH])
    connections_before = connections_received(df_admin)
    cases = {
        "protected-no-credentials": (PROTECTED, {}),
        "protected-full-credentials": (PROTECTED, full),
        "access-only-with-access": (ACCESS_ONLY, _headers(access=_access(jwks_server))),
    }
    for case, (path, headers) in cases.items():
        response = client.get(path, headers={**headers, "host": BAD_HOST})
        assert response.status_code == 400, case
        assert_problem(response, 400, "invalid_host")
    assert connections_received(df_admin) - connections_before == 0
    assert (jwks_server.hits[JWKS_PATH], jwks_server.hits[CERTS_PATH]) == hits_before
    response = client.get(HEALTHZ, headers={"host": BAD_HOST})
    assert (response.status_code, response.content) == (200, b"ok")
    assert client.get(PROTECTED, headers=full).status_code == 200


def _bad_path_values() -> dict[str, object]:
    path = f"/{SENTINEL}"
    return {
        "str": path,
        "bytes": path.encode(),
        "dict": {path: True},
        "tuple-with-int": (path, 1),
        "list-with-bytes": [path.encode()],
        "none": None,
    }


@pytest.mark.parametrize("name", PATH_SETTINGS)
@pytest.mark.parametrize("case", list(_bad_path_values()))
def test_ac_3_path_setting_type_is_checked(
    name: str, case: str, contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-3a — 경로 설정(D2 ⓪ ②)은 str만 담은 tuple · list · set · frozenset이어야 한다: str 하나(`in`이 부분 문자열 검사가
    되어 면제가 넓어진다) · bytes · dict · str 아닌 원소 · None → 요청 때 ImproperlyConfigured(설정 이름만 · 값의 감시
    문자열 없음 · 연쇄 없음)."""
    setattr(settings, name, _bad_path_values()[case])
    headers = _valid_headers(jwks_server)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        contract_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, name)


def test_ac_3_path_settings_are_read_per_request(
    contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-3b — 같은 Client(= 같은 미들웨어 인스턴스)가 경로 설정을 요청마다 읽는다 · 네 컬렉션 타입을 모두 받는다:
    /open은 기본 면제 목록 밖이라 자격 없이 403 → AUTH_EXEMPT_PATHS에 넣으면 200(설정이 기본값을 갈음한다 — /healthz는 이제
    403) → 빈 tuple이면 /open도 403 / /access-only + Access만 → 기본(빈 목록) 401 → AUTH_ACCESS_ONLY_PATHS에 넣으면 200 /
    두 목록에 다 있으면 면제가 먼저다(자격 없이 200)."""
    client = contract_client()
    assert_problem(client.get(OPEN), 403, "access_required")
    for container in (tuple, list, set, frozenset):
        settings.AUTH_EXEMPT_PATHS = container([OPEN])
        response = client.get(OPEN)
        assert (response.status_code, response.content) == (200, b"ok"), container.__name__
    assert_problem(client.get(HEALTHZ), 403, "access_required")
    settings.AUTH_EXEMPT_PATHS = ()
    assert_problem(client.get(OPEN), 403, "access_required")
    access_only = _headers(access=_access(jwks_server))
    assert_problem(client.get(ACCESS_ONLY, headers=access_only), 401, "invalid_token")
    for container in (tuple, list, set, frozenset):
        settings.AUTH_ACCESS_ONLY_PATHS = container([ACCESS_ONLY])
        assert client.get(ACCESS_ONLY, headers=access_only).status_code == 200, container.__name__
    settings.AUTH_EXEMPT_PATHS = (OPEN,)
    settings.AUTH_ACCESS_ONLY_PATHS = (OPEN,)
    assert client.get(OPEN).status_code == 200


def test_ac_3_exempt_and_access_only_match_path_info(
    contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-3c — 면제 · Access 전용 판정은 request.path_info 정확 일치다(D2 · T070 r2 N4 ① — T068 tc-4와 같은 규칙):
    SCRIPT_NAME="/x"로 request.path가 /x/healthz · /x/access-only로 달라져도 path_info가 목록에 있으면 그 판정이다 —
    /healthz는 자격 없이 200 · /access-only는 Access만으로 200(request.path로 판정하면 403 · 401). 첫 단언은 SCRIPT_NAME이
    실제로 request.path를 바꿨는지 본다(공허하지 않게)."""
    settings.AUTH_ACCESS_ONLY_PATHS = (ACCESS_ONLY,)
    client = contract_client()
    response = client.get(HEALTHZ, SCRIPT_NAME="/x")
    assert (response.wsgi_request.path, response.wsgi_request.path_info) == ("/x/healthz", HEALTHZ)
    assert (response.status_code, response.content) == (200, b"ok")
    response = client.get(ACCESS_ONLY, SCRIPT_NAME="/x", headers=_headers(access=_access(jwks_server)))
    assert (response.wsgi_request.path, response.wsgi_request.path_info) == ("/x/access-only", ACCESS_ONLY)
    assert response.status_code == 200


def test_ac_17_request_attributes(
    contract_client: Callable[..., Client],
    jwks_server: JwksInfo,
    dragonfly: DragonflyInfo,
    settings: SettingsWrapper,
) -> None:
    """ac-17 — 요청 속성(D2 ⑦): 면제 경로는 손대지 않는다(앞선 미들웨어가 둔 값 그대로 · 없으면 없음) · 비면제 경로는 판정
    전에 세 속성을 지운다 — 실패 응답(403 · 401 · 503)에는 하나도 남지 않는다(앞선 미들웨어가 둔 가짜 값 포함 · Access가
    통과해도 Bearer가 실패하면 access_claims도 없다) · 성공하면 검증한 값만(tenant_id 클레임이 없으면 tenant_id 없음 — 가짜
    값이 뷰 · TenantContextMiddleware에 닿지 않는다) · Access 전용 경로는 access_claims만."""
    settings.AUTH_ACCESS_ONLY_PATHS = (ACCESS_ONLY,)
    client = contract_client(probe=True)
    spoof = {SPOOF_HEADER: str(SPOOF_TENANT)}
    all_three = ",".join(AUTH_ATTRIBUTES)
    response = client.get(HEALTHZ, headers=spoof)
    assert (response.status_code, response[ATTRS_HEADER]) == (200, all_three)
    assert client.get(HEALTHZ)[ATTRS_HEADER] == ""

    now = int(time.time())
    expired = _bearer(jwks_server, iat=now - 360, exp=now - 60)
    failures = {
        "no-access-403": (403, {}),
        "expired-bearer-401": (401, _headers(bearer=expired, access=_access(jwks_server))),
    }
    for case, (status, headers) in failures.items():
        response = client.get(PROTECTED, headers={**headers, **spoof})
        assert (response.status_code, response[ATTRS_HEADER]) == (status, ""), case
    settings.DRAGONFLY_URL = _unreachable_url(closed_port())
    response = client.get(PROTECTED, headers={**_valid_headers(jwks_server), **spoof})
    assert (response.status_code, response[ATTRS_HEADER]) == (503, "")
    settings.DRAGONFLY_URL = dragonfly.reader_url

    no_tenant = _headers(bearer=_bearer(jwks_server, tenant_id=None), access=_access(jwks_server))
    response = client.get(PROTECTED, headers={**no_tenant, **spoof})
    assert (response.status_code, response[ATTRS_HEADER]) == (200, "access_claims,auth_claims")
    assert json.loads(response.content) == {
        "sub": BEARER_SUB,
        "common_name": settings.ACCESS_EXPECTED_CN,
        "tenant_id": "None",
        "tenant_id_is_uuid": False,
        "auth_claim_names": sorted(bearer_claims(tenant_id=None)),
        "groups": None,
    }
    response = client.get(PROTECTED, headers={**_valid_headers(jwks_server), **spoof})
    assert (response.status_code, response[ATTRS_HEADER]) == (200, all_three)
    assert json.loads(response.content)["tenant_id"] == TENANT_ID
    response = client.get(ACCESS_ONLY, headers={**_headers(access=_access(jwks_server)), **spoof})
    assert (response.status_code, response[ATTRS_HEADER]) == (200, "access_claims")
    assert json.loads(response.content) == {
        "sub": None,
        "common_name": settings.ACCESS_EXPECTED_CN,
        "tenant_id": "None",
        "tenant_id_is_uuid": False,
        "auth_claim_names": None,
        "groups": None,
    }


def test_ac_17_auth_claims_is_the_whole_verified_payload(
    contract_client: Callable[..., Client], jwks_server: JwksInfo
) -> None:
    """ac-17b — request.auth_claims는 검증한 Bearer payload 전체다(D2 ⑦ · T070 r2 N4 ③ — T073 관리자 판정이 groups에
    기댄다): 추가 클레임(groups · preferred_username)이 값 그대로 남고, 클레임 이름 = 토큰 payload의 키 전부다(sub만 두거나
    골라 담으면 실패)."""
    groups = ["platform-admin", f"tenant:{TENANT_ID}"]
    token = _bearer(jwks_server, groups=groups, preferred_username="ac17b-user")
    payload = jwt.decode(token, options={"verify_signature": False})
    response = contract_client().get(PROTECTED, headers=_headers(bearer=token, access=_access(jwks_server)))
    assert response.status_code == 200
    body = json.loads(response.content)
    assert (body["auth_claim_names"], body["groups"]) == (sorted(payload), groups)
    assert {"groups", "preferred_username", "sub", "tenant_id"} <= set(body["auth_claim_names"])


def test_ac_18_middleware_reads_settings_per_request(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-18 — 같은 Client(= 같은 미들웨어 인스턴스)가 요청마다 설정을 읽는다(D2 · D6 — import 시점 · 인스턴스 생성 시점
    상수가 없다 · T062 시험은 설정을 바꾼 뒤 늘 새 Client를 만들어 이것을 가르지 못한다): 값 하나씩 바꾸면 그 단계가
    실패하고(403 · 401 · 503) 되돌리면 200이다."""
    client = make_client()
    headers = _valid_headers(jwks_server)
    assert client.get(PROTECTED, headers=headers).status_code == 200
    closed = f"http://127.0.0.1:{closed_port()}"
    changes = (
        ("ACCESS_EXPECTED_CN", "other-client-id.access", 403, "access_required"),
        ("ACCESS_AUD_M2M", "other-aud", 403, "access_required"),
        ("ACCESS_TEAM_DOMAIN", closed, 503, "auth_keys_unavailable"),
        ("AUTHENTIK_AUDIENCE", "other-audience", 401, "invalid_token"),
        ("AUTHENTIK_ISSUER", "https://issuer.example.test/other/", 401, "invalid_token"),
        ("AUTHENTIK_JWKS_URL", closed + JWKS_PATH, 503, "auth_keys_unavailable"),
        ("AUTH_ACTOR_SUB", ACTOR, 401, "invalid_token"),
        ("DRAGONFLY_URL", _unreachable_url(closed_port()), 503, "denylist_unavailable"),
    )
    for name, value, status, slug in changes:
        original = getattr(settings, name)
        setattr(settings, name, value)
        response = client.get(PROTECTED, headers=headers)
        assert response.status_code == status, name
        assert_problem(response, status, slug)
        setattr(settings, name, original)
        assert client.get(PROTECTED, headers=headers).status_code == 200, name


def test_ac_22_failure_precedence(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-22 — 동시 실패 우선순위 = 판정 순서(D2 ③–⑥): Dragonfly가 닫힌 포트여도 Access 실패 403 · Bearer 실패 401 · 클레임
    모양(tenant_id slug) 401 · act 불일치 401이 503보다 먼저다(토큰 결함은 의존성 장애와 무관하게 토큰 결함으로 답한다 —
    거부 목록은 마지막) · Authentik JWKS가 닫힌 포트여도 Access 실패가 먼저(403) · 다 맞으면 거부 목록 503."""
    settings.DRAGONFLY_URL = _unreachable_url(closed_port())
    settings.AUTH_ACTOR_SUB = ACTOR
    client = make_client()
    now = int(time.time())
    act = {"sub": ACTOR}
    access = _access(jwks_server)

    def bearer(**claims: Any) -> str:
        return _bearer(jwks_server, **{"act": act, **claims})

    cases = {
        "no-access": (403, "access_required", _headers(bearer=bearer())),
        "expired-bearer": (401, "invalid_token", _headers(bearer=bearer(exp=now - 60), access=access)),
        "slug-tenant": (401, "invalid_token", _headers(bearer=bearer(tenant_id="joshuatech"), access=access)),
        "actor-mismatch": (401, "invalid_token", _headers(bearer=bearer(act={"sub": "other"}), access=access)),
        "denylist-down": (503, "denylist_unavailable", _headers(bearer=bearer(), access=access)),
    }
    for case, (status, slug, headers) in cases.items():
        response = client.get(PROTECTED, headers=headers)
        assert response.status_code == status, case
        assert_problem(response, status, slug)
    settings.AUTHENTIK_JWKS_URL = f"http://127.0.0.1:{closed_port()}{JWKS_PATH}"
    response = make_client().get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server, act=act)))
    assert_problem(response, 403, "access_required")


# --- Access(D3) ------------------------------------------------------------------------------------------------------


def test_ac_4_team_domain_without_scheme_uses_https(
    contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-4a — 스킴 없는 ACCESS_TEAM_DOMAIN(운영 값 `joshua-tech.cloudflareaccess.com` 꼴)은 https://를 붙인다 · https://
    스킴(대소문자 무시)도 그대로 https다: certs fetch가 TLS 핸드셰이크로 시작한다(첫 바이트 0x16 — 평문 GET이면 `G`) → 첫
    바이트 서버는 TLS를 말하지 않으므로 키를 가져오지 못해 503 auth_keys_unavailable(fetch 시간 초과 안). 인증서 · 이름
    조회 없이(127.0.0.1 리터럴) 스킴 접두만 관찰한다."""
    server = FirstByteServer()
    try:
        values = (f"127.0.0.1:{server.port}", f"https://127.0.0.1:{server.port}", f"HTTPS://127.0.0.1:{server.port}")
        for count, value in enumerate(values, start=1):
            settings.ACCESS_TEAM_DOMAIN = value
            headers = _valid_headers(jwks_server)
            client = contract_client()
            response, elapsed = _timed(lambda client=client, headers=headers: client.get(PROTECTED, headers=headers))
            assert response.status_code == 503, value
            assert_problem(response, 503, "auth_keys_unavailable")
            assert elapsed < KEY_FETCH_LIMIT_S, f"{value}: {elapsed:.3f} s"
            assert server.wait_for(count)[-1:] == [0x16], value
    finally:
        server.close()


# ac-4b 사례 이름 → ACCESS_TEAM_DOMAIN 값({port}는 닫힌 포트 · {sentinel}은 감시 문자열) — ac-23b가 같은 목록을 쓴다(r3 U3).
# http + 이름(LDH 이름 · localhost) 두 사례는 r3 변이 M14(루프백 밖 http 허용)가 살아남아 더했다 — U2 뒤에는 0.0.0.0 · [::]가
# 호스트 규칙에서 먼저 걸려 http 규칙에 닿지 않는다(이름은 조회하지 않는다 — 조회하면 이름 조회 가드가 막고 기록한다).
TEAM_DOMAIN_SHAPE_CASES: dict[str, str] = {
    "http-unspecified-v4": "http://0.0.0.0:{port}",
    "http-unspecified-v6": "http://[::]:{port}",
    "http-name": "http://{sentinel}.cloudflareaccess.com",
    "http-localhost": "http://localhost:{port}",
    "ftp": "ftp://127.0.0.1:{port}",
    "userinfo": "https://{sentinel}@127.0.0.1:{port}",
    "path": "https://127.0.0.1:{port}/{sentinel}",
    "query": "https://127.0.0.1:{port}?{sentinel}=1",
    "fragment": "https://127.0.0.1:{port}#{sentinel}",
    "bad-port": "https://127.0.0.1:{sentinel}",
    "no-host": "https://",
}


@pytest.mark.parametrize("case", list(TEAM_DOMAIN_SHAPE_CASES))
def test_ac_4_team_domain_shape_is_checked(
    case: str, contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-4b — http://는 루프백 IP 리터럴만 받는다(시험 서버 — 0.0.0.0 · [::]처럼 루프백이 아닌 IP와 LDH 이름 · localhost
    같은 이름의 http는 거부 · 이름은 조회하지 않는다) · 팀 기준 URL 꼴(스킴 http · https · 호스트 필수 · 사용자 정보 · 경로 ·
    쿼리 · 조각 금지 · 잘못된 포트) → 요청 때 ImproperlyConfigured(설정 이름만 — 감시 문자열을 값의 여러 자리에 심는다 · 연쇄
    없음 · 연결 시도 0)."""
    settings.ACCESS_TEAM_DOMAIN = TEAM_DOMAIN_SHAPE_CASES[case].format(port=closed_port(), sentinel=SENTINEL)
    headers = _valid_headers(jwks_server)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        contract_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, "ACCESS_TEAM_DOMAIN")


def test_ac_4_team_domain_trailing_slash_and_scheme_case(
    contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-4c — 팀 기준 URL은 `<scheme>://<host[:port]>`다: 끝 `/` 하나는 뺀다 · 스킴은 소문자로 — certs URL(`<base>` +
    `/cdn-cgi/access/certs` — 시험 서버는 경로가 정확할 때만 키를 준다)과 Access iss(`<base>` — Cloudflare 꼴) 모두 정규형이라
    iss = `http://127.0.0.1:<port>` 토큰이 200이다."""
    base = jwks_server.base_url
    headers = _headers(bearer=_bearer(jwks_server), access=_access(jwks_server, iss=base))
    for value in (base + "/", base.replace("http://", "HTTP://", 1)):
        settings.ACCESS_TEAM_DOMAIN = value
        assert contract_client().get(PROTECTED, headers=headers).status_code == 200, value


# 팀 기준 URL 정규형(T070 r2 N9) 시험 값. 제어 · 비ASCII 글자는 chr()로 만든다(소스 바이트는 ASCII 그대로).
TAB, LF, SOH, DEL, NBSP = chr(0x09), chr(0x0A), chr(0x01), chr(0x7F), chr(0xA0)
CYRILLIC_IE = chr(0x0435)  # 키릴 소문자 ie(U+0435) — 라틴 e와 모양이 같은 비ASCII(동형 문자)
# 인증 문자열 설정 시험 값(T070 r4 V2) — 폭 0 공백(U+200B) · BOM(U+FEFF) · 한글 채움 문자(U+3164 — 보이지 않지만
# str.isprintable()이 참) · 키릴 소문자 a(U+0430 — 라틴 a와 모양이 같은 비ASCII · isprintable 참).
ZERO_WIDTH, BOM, HANGUL_FILLER, CYRILLIC_A = chr(0x200B), chr(0xFEFF), chr(0x3164), chr(0x0430)
# T070 r5 W1 — 공백이 아닌 ASCII 제어 문자 ESC(U+001B — 색 있는 터미널 출력에서 복사한 ANSI 시퀀스의 첫 글자). DEL(U+007F —
# `~` 바로 위 경계)은 위 줄의 DEL을 쓴다.
ESC = chr(0x1B)
CANONICAL_TEAM = "https://joshua-tech.cloudflareaccess.com"  # 운영 팀 도메인의 정규형(Cloudflare iss 꼴)
# LDH 길이 경계(T070 r3 U2) — 라벨 63자 · 전체 253자는 받고 64자 · 254자는 거부한다. 거부 쪽은 길이 말고는 규칙에 맞다(라벨은
# 영숫자로 시작하고 끝나며, 254자 호스트의 라벨은 모두 63자 이하) — 길이 검사 하나만 가른다. 감시 문자열을 첫 라벨에 심는다.
LABEL_63 = "a" * 63
LABEL_64 = SENTINEL + "x" * (64 - len(SENTINEL))
HOST_253 = ".".join(("a" * 63, "b" * 63, "c" * 63, "d" * 61))
HOST_254 = ".".join((SENTINEL + "a" * (63 - len(SENTINEL)), "b" * 63, "c" * 63, "d" * 62))
# 이름 → (ACCESS_TEAM_DOMAIN 값 · 기대 정규형). {port}는 닫힌 포트다(키 fetch는 가로채므로 연결 · 이름 조회가 없다).
TEAM_DOMAIN_CANONICAL_CASES: dict[str, tuple[str, str]] = {
    "upper-host": ("Joshua-Tech.CloudflareAccess.COM", CANONICAL_TEAM),
    "default-port": ("https://joshua-tech.cloudflareaccess.com:443", CANONICAL_TEAM),
    "empty-port": ("https://joshua-tech.cloudflareaccess.com:", CANONICAL_TEAM),
    "all-at-once": ("HTTPS://JOSHUA-TECH.CloudflareAccess.com:443/", CANONICAL_TEAM),
    "other-port-kept": ("joshua-tech.cloudflareaccess.com:{port}", CANONICAL_TEAM + ":{port}"),
    "http-default-port": ("http://127.0.0.1:80/", "http://127.0.0.1"),
    "ipv6-loopback": ("http://[::1]:{port}/", "http://[::1]:{port}"),
    "ipv6-loopback-long": ("HTTP://[0:0:0:0:0:0:0:1]:{port}", "http://[::1]:{port}"),
    # r3 U2 — LDH 이름은 받는다: xn-- 라벨(가운데 하이픈 둘) · 숫자가 섞인 라벨(마지막이 아닌 숫자만인 라벨 · 숫자로 끝나는
    # 라벨) · 63자 라벨 · 253자 호스트 · 루프백 IP 리터럴 https · 0으로 시작하는 포트(:0443 = 443 — 기본 포트라 뗀다).
    "punycode-label": ("xn--bcher-kva.example.test", "https://xn--bcher-kva.example.test"),
    "digits-in-labels": ("https://0123.team9.example.test", "https://0123.team9.example.test"),
    "label-63": (f"{LABEL_63}.example.test", f"https://{LABEL_63}.example.test"),
    "host-253": (HOST_253, f"https://{HOST_253}"),
    "https-loopback": ("https://127.0.0.1:{port}", "https://127.0.0.1:{port}"),
    "port-leading-zero": ("https://joshua-tech.cloudflareaccess.com:0443", CANONICAL_TEAM),
    # r4 V1 — 숫자 꼴 규칙은 마지막 라벨만 본다: 마지막이 아닌 라벨의 `0x…` · `0x`로 시작하지만 16진이 아닌 마지막 라벨은 이름이다.
    "hex-not-last-label": ("0x7f.example.com", "https://0x7f.example.com"),
    "non-hex-after-0x": ("a.0xg", "https://a.0xg"),
}
# 이름 → ACCESS_TEAM_DOMAIN 값(설정 오류여야 한다). urlsplit는 탭 · 줄바꿈을 지우고 앞쪽 공백을 떼므로 원문 단계에서 걸러야
# 한다. 감시 문자열을 호스트 자리에 심는다(값이 메시지에 실리면 실패). {port}는 닫힌 포트다.
TEAM_DOMAIN_REJECTED_CASES: dict[str, str] = {
    "space-in-host": f"{SENTINEL} x.cloudflareaccess.com",
    "leading-space": f" https://{SENTINEL}.cloudflareaccess.com",
    "trailing-space": f"{SENTINEL}.cloudflareaccess.com ",
    "tab": f"https://{SENTINEL}.cloudflare{TAB}access.com",
    "newline": f"{SENTINEL}.cloudflareaccess.com{LF}",
    "control": f"{SENTINEL}.cloudflare{SOH}access.com",
    "delete": f"{SENTINEL}.cloudflare{DEL}access.com",
    "non-ascii": f"{SENTINEL}.cloudflar{CYRILLIC_IE}access.com",
    "nbsp": f"{SENTINEL}{NBSP}.cloudflareaccess.com",
    "underscore": f"{SENTINEL}_x.cloudflareaccess.com",
    "ipvfuture": f"https://[v1.{SENTINEL}]",
    "ipv6-unspecified": "https://[::]:{port}",
    "empty-query": f"https://{SENTINEL}.cloudflareaccess.com?",
    "empty-fragment": f"https://{SENTINEL}.cloudflareaccess.com#",
    # r3 U2 — LDH 규칙 · 포트 1–65535: 끝 점(이름은 풀리지만 iss · certs가 `…com.`이 되어 조용히 403) · 빈 라벨 · 앞 점 · 라벨
    # 앞 · 끝 하이픈 · 64자 라벨 · 254자 호스트 · 마지막 라벨이 숫자만(이름 조회가 inet_aton 꼴로 다른 주소를 풀 수 있다 — 0 ·
    # 루프백 아닌 IPv4 · 줄인 IPv4) · 포트 0.
    "trailing-dot": f"https://{SENTINEL}.cloudflareaccess.com.",
    "empty-label": f"https://{SENTINEL}..cloudflareaccess.com",
    "leading-dot": f"https://.{SENTINEL}.cloudflareaccess.com",
    "label-leading-hyphen": f"https://-{SENTINEL}.cloudflareaccess.com",
    "label-trailing-hyphen": f"https://{SENTINEL}-.cloudflareaccess.com",
    "label-64": f"https://{LABEL_64}.cloudflareaccess.com",
    "host-254": f"https://{HOST_254}",
    "all-digits": "https://0",
    "private-ipv4": "https://10.0.0.1",
    "short-ipv4": "https://127.1",
    "port-zero": f"https://{SENTINEL}.cloudflareaccess.com:0",
    # r4 V1 — 마지막 라벨이 16진 숫자 꼴(`0x` + 16진 숫자 · 빈 것 포함 — WHATWG URL ends-in-a-number): inet_aton이 이름 조회
    # 없이 IP로 푼다(0x7f000001 · 127.0.0.0x1 → 127.0.0.1 · 169.254.169.0xfe → 169.254.169.254). 대문자 0X는 소문자로 맞춘 뒤
    # 본다. 마지막 사례는 감시 문자열을 앞 라벨에 심는다.
    "hex-ipv4": "https://0x7f000001",
    "hex-ipv4-upper": "https://0X7F000001",
    "hex-last-octet": "https://127.0.0.0x1",
    "hex-metadata": "https://169.254.169.0xfe",
    "hex-after-name": "https://a.0x1",
    "hex-prefix-only": "https://0x",
    "hex-after-sentinel": f"https://{SENTINEL}.0xfe",
    # r5 W1 — 인증 문자열 설정 값 꼴(AUTH_STRING_FORMS)의 비ASCII 셋을 팀 도메인에도: 폭 0 · BOM(앞 — 파일에서 복사한 값) · 한글
    # 채움 문자(보이지 않지만 str.isprintable()이 참). 감시 문자열을 첫 라벨에 심는다(값이 메시지에 실리면 실패).
    "zero-width": f"{SENTINEL}{ZERO_WIDTH}.cloudflareaccess.com",
    "bom": f"{BOM}{SENTINEL}.cloudflareaccess.com",
    "hangul-filler": f"{SENTINEL}{HANGUL_FILLER}.cloudflareaccess.com",
}


def _intercept_key_fetch(monkeypatch: pytest.MonkeyPatch, jwks: JwksInfo) -> list[str]:
    """PyJWKClient.fetch_data(네트워크 fetch)를 가로챈다 — 요청 URL(client.uri)을 차례로 기록하고 세션 Access 공개 키
    문서를 준다(소켓 · 이름 조회 0 — 키 집합 해석 · kid 매칭 · 서명 검증 · iss 비교는 실제 코드 그대로 돈다)."""
    fetched: list[str] = []

    def fetch_data(client: jwt.PyJWKClient) -> dict[str, Any]:
        fetched.append(client.uri)
        return {"keys": [to_jwk(jwks.access_key.public_key(), ACCESS_KID)]}

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", fetch_data)
    return fetched


@pytest.mark.parametrize("case", list(TEAM_DOMAIN_CANONICAL_CASES))
def test_ac_4_team_domain_is_rebuilt_in_canonical_form(
    case: str, jwks_server: JwksInfo, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ac-4d — 팀 기준 URL은 ACCESS_TEAM_DOMAIN을 정규형 `<scheme>://<host>[:<port>]`로 다시 만든 것이다(T070 r2 N9 —
    Cloudflare iss는 소문자 · 포트 없음 · 정규형이 아니면 모든 요청이 조용히 403): 스킴 · 호스트는 소문자로 · 기본 포트(https
    443 · http 80) · 빈 포트 · 끝 `/`는 떼고 다른 포트는 남긴다 · 루프백 IPv6는 정규 표기를 `[…]`로 다시 감싼다 · LDH 이름은
    받는다(r3 U2 — xn-- 라벨 · 숫자가 섞인 라벨 · 63자 라벨 · 253자 호스트 · 루프백 https · :0443). 키 fetch를 가로채(네트워크
    0) 키 클라이언트가 받은 certs URL = 정규형 + /cdn-cgi/access/certs이고, iss = 정규형인 Access 토큰이 통과한다(검증
    issuer도 같은 정규형 — 원문 그대로면 iss 불일치 AccessRequired). r4 V1 — 마지막이 아닌 `0x…` 라벨(0x7f.example.com) ·
    16진이 아닌 `0x…` 마지막 라벨(a.0xg)은 이름이다(정규형 그대로)."""
    port = closed_port()
    value, expected = (text.format(port=port) for text in TEAM_DOMAIN_CANONICAL_CASES[case])
    fetched = _intercept_key_fetch(monkeypatch, jwks_server)
    settings.ACCESS_TEAM_DOMAIN = value
    claims = AccessJwtValidator().validate(_access(jwks_server, iss=expected))
    assert claims["iss"] == expected
    assert fetched == [expected + CERTS_PATH]


@pytest.mark.parametrize("case", list(TEAM_DOMAIN_REJECTED_CASES))
def test_ac_4_team_domain_host_characters_are_checked(
    case: str,
    contract_client: Callable[..., Client],
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ac-4e — 팀 기준 URL 호스트(T070 r2 N9 · r3 U2): 소문자로 맞춘 뒤 LDH 이름(괄호 없이 — 라벨 1–63자 `[a-z0-9-]` · 영숫자로
    시작하고 끝남 · 빈 라벨 · 앞 · 끝 점 없음 · 전체 253자 이하 · 마지막 라벨이 숫자만이 아님) 또는 루프백 IP 리터럴이어야 하고,
    포트는 1–65535 · 원문에 공백 · 제어 문자 · 비ASCII가 있으면 안 된다(urlsplit가 지우는 탭 · 줄바꿈 · 앞 공백 포함) · 밑줄 ·
    IPvFuture · 루프백 아닌 IPv6 · 빈 쿼리(`?`) · 빈 조각(`#`) → 요청 때 ImproperlyConfigured(설정 이름만 · 감시 문자열 없음 ·
    연쇄 없음 · 키 fetch 0 · 이름 조회 0). r4 V1 — 마지막 라벨이 16진 숫자 꼴(`0x` + 16진 숫자 · 빈 것 포함 · 대문자 0X 포함 —
    WHATWG URL ends-in-a-number · inet_aton이 이름 조회 없이 IP로 푼다)이어도 거부한다. r5 W1 — 폭 0 · BOM · 한글 채움 문자도
    거부한다(이 설정의 글자 검사는 _required의 _printable_ascii와 _base_url_parts 원문 검사가 겹친다 — 어느 하나가 약해져도 이
    시험은 가르지 못한다 · 판별력은 ac-5a · ac-5b · ac-5c가 보인다)."""
    settings.ACCESS_TEAM_DOMAIN = TEAM_DOMAIN_REJECTED_CASES[case].format(port=closed_port())
    fetched = _intercept_key_fetch(monkeypatch, jwks_server)
    headers = _valid_headers(jwks_server)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        contract_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, "ACCESS_TEAM_DOMAIN")
    assert fetched == []


def test_ac_19_access_validator_public_api(jwks_server: JwksInfo, settings: SettingsWrapper) -> None:
    """ac-19 — AccessJwtValidator(D2 공개 API): validate(token) → 검증된 클레임 dict · 실패(없음 · 빈 값 · 꼴 아님 ·
    common_name · aud) → AccessRequired · 키를 가져오지 못하면 AuthKeysUnavailable(연쇄 없음) · 설정은 validate 호출 때
    읽는다(같은 인스턴스가 바뀐 ACCESS_EXPECTED_CN을 따른다)."""
    validator = AccessJwtValidator()
    claims = validator.validate(_access(jwks_server))
    assert isinstance(claims, dict)
    assert claims["common_name"] == settings.ACCESS_EXPECTED_CN
    bad_tokens = {
        "none": None,
        "empty": "",
        "garbage": "garbage",
        "other-common-name": _access(jwks_server, common_name="other.access"),
        "other-aud": _access(jwks_server, aud=["other"]),
    }
    accepted: list[str] = []
    for case, bad in bad_tokens.items():
        try:
            validator.validate(bad)  # type: ignore[arg-type]
        except AccessRequired:
            continue
        accepted.append(case)
    assert accepted == []
    token = _access(jwks_server)
    settings.ACCESS_EXPECTED_CN = "changed-client-id.access"
    with pytest.raises(AccessRequired):
        validator.validate(token)
    settings.ACCESS_TEAM_DOMAIN = f"http://127.0.0.1:{closed_port()}"
    with pytest.raises(AuthKeysUnavailable) as excinfo:
        validator.validate(token)
    _assert_no_chain(excinfo.value)


# --- 설정(D6) ----------------------------------------------------------------------------------------------------------


@pytest.mark.parametrize("name", REQUIRED_SETTINGS)
@pytest.mark.parametrize("state", REQUIRED_SETTING_STATES)
def test_ac_5_required_setting(
    name: str, state: str, make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5a — 필수 설정(D6)이 비었거나 · 없거나 · str이 아니면(감시 문자열을 담은 목록) 그 설정을 읽는 단계에서
    ImproperlyConfigured다(설정 이름만 · 값 없음 · 연쇄 없음 → 운영 500). 토큰은 설정을 바꾸기 전에 만든다 — 앞 단계는
    통과해 그 설정을 읽는 단계까지 간다."""
    headers = _valid_headers(jwks_server)
    if state == "empty":
        setattr(settings, name, "")
    elif state == "missing":
        delattr(settings, name)
    else:
        setattr(settings, name, [SENTINEL])
    with pytest.raises(ImproperlyConfigured) as excinfo:
        make_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, name)


# 인증 문자열 설정의 값 꼴(T070 r4 V2) — 이름 → (앞에 붙일 글자 · 감시 문자열 바로 뒤에 넣을 글자 · 끝에 붙일 글자). 공백 없는
# 출력 가능 ASCII(`!`–`~`) 밖 글자가 하나라도 있으면 설정 오류다: 끝 줄바꿈(YAML 블록 스칼라 `|`) · 앞 공백 · 가운데 공백 · 탭 ·
# NBSP · 폭 0 · BOM(앞 — 파일에서 복사한 값) · 한글 채움 문자 · 키릴 동형 글자(뒤의 둘은 str.isprintable()이 참인 비ASCII).
# r5 W1 — 공백이 아닌 ASCII 제어 문자 ESC · DEL(`~` 바로 위 경계)도 감시 문자열 바로 뒤에 넣는다. 둘이 없으면 「ASCII이고
# 공백이 아니면 받는다」 규칙(변이 M124)과 상한에 DEL을 넣은 범위(변이 M123)를 실제 규칙과 가르지 못한다(리뷰 r4 A-1 · B-2).
# 이 꼴들은 거부 쪽 경계를 가른다 — 수락 쪽 경계(`!` · `~`)는 PRINTABLE_ASCII · URL_PUNCTUATION이 가른다(ac-5d · ac-23e — r6 X1).
AUTH_STRING_FORMS: dict[str, tuple[str, str, str]] = {
    "trailing-newline": ("", "", LF),
    "leading-space": (" ", "", ""),
    "inner-space": ("", " ", ""),
    "tab": ("", TAB, ""),
    "nbsp": ("", NBSP, ""),
    "zero-width": ("", ZERO_WIDTH, ""),
    "bom": (BOM, "", ""),
    "hangul-filler": ("", HANGUL_FILLER, ""),
    "cyrillic-homoglyph": ("", CYRILLIC_A, ""),
    "escape": ("", ESC, ""),
    "delete": ("", DEL, ""),
}
# 설정 이름 → 그 꼴 말고는 유효한 기본 값 틀({sentinel} 자리 하나 · {port}는 시험이 채운다 — 닫힌 포트). 검사가 없으면 요청은
# 설정 오류가 아니라 판정 결과(403 · 401 · 503 · 200)가 되므로 ImproperlyConfigured만이 이 규칙의 증거다. AUTHENTIK_JWKS_URL은
# ac-5c(JWKS_URL_BAD_CASES의 v2-*)가 같은 꼴 전부를 덮는다. ACCESS_TEAM_DOMAIN은 ac-4e(TEAM_DOMAIN_REJECTED_CASES)가 같은 부류를
# 덮는다(끝 줄바꿈 · 앞 · 가운데 · 끝 공백 · 탭 · NBSP · 폭 0 · BOM · 한글 채움 문자 · 비ASCII 동형 글자 · 제어 문자 SOH · DEL —
# 폭 0 · BOM · 한글 채움 문자는 r5 W1). 다만 그 설정에서는 _base_url_parts의 원문 검사가 같은 글자 범위를 따로 거르므로
# _printable_ascii 변이(범위를 바꾸거나 검사를 뺀 것)를 가르지 못한다(M83 동치의 반대 방향). _printable_ascii의 판별력은 나머지
# 8개 설정(아래 7개 + AUTHENTIK_JWKS_URL)이 보인다.
AUTH_STRING_BASES: dict[str, str] = {
    "ACCESS_AUD_M2M": "{sentinel}-aud-m2m",
    "ACCESS_EXPECTED_CN": "{sentinel}.access",
    "AUTHENTIK_ISSUER": "https://{sentinel}.example.test/application/o/identity-admin/",
    "AUTHENTIK_AUDIENCE": "{sentinel}-audience",
    "DRAGONFLY_URL": "redis://test-pod:{sentinel}@127.0.0.1:{port}/0",
    "ACCESS_AUD_ADMIN": "{sentinel}-aud-admin",
    "AUTH_ACTOR_SUB": "{sentinel}-actor",
}


def _malformed(base: str, form: str) -> str:
    """기본 값 틀 base({sentinel} 자리 하나)를 값 꼴 form(AUTH_STRING_FORMS)으로 망가뜨린 틀."""
    head, inner, tail = AUTH_STRING_FORMS[form]
    return head + base.replace("{sentinel}", "{sentinel}" + inner, 1) + tail


# ac-5a(r4 V2) 사례 이름 → (설정 이름 · 값 틀) — _required로 읽는 인증 문자열 설정마다 값 꼴 열하나(r5 W1 ESC · DEL 포함).
# ac-23b가 같은 목록을 쓴다.
REQUIRED_STRING_CASES: dict[str, tuple[str, str]] = {
    f"{name}-{form}": (name, _malformed(AUTH_STRING_BASES[name], form))
    for name in ("ACCESS_AUD_M2M", "ACCESS_EXPECTED_CN", "AUTHENTIK_ISSUER", "AUTHENTIK_AUDIENCE", "DRAGONFLY_URL")
    for form in AUTH_STRING_FORMS
}


@pytest.mark.parametrize("case", list(REQUIRED_STRING_CASES))
def test_ac_5_required_setting_must_be_printable_ascii(
    case: str, make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5a(r4 V2) — 필수 인증 문자열 설정(_required)은 공백 없는 출력 가능 ASCII(`!`–`~`)만 받는다: 끝 줄바꿈 · 앞 · 가운데
    공백 · 탭 · NBSP · 폭 0 · BOM · 한글 채움 문자 · 키릴 동형 글자가 하나라도 있으면 그 설정을 읽는 단계(Access · Bearer ·
    거부 목록)에서 ImproperlyConfigured다(설정 이름만 · 값의 감시 문자열 없음 · 연쇄 없음 → 운영 500 · 기동 검사에서 기동
    실패). 검사가 없으면 비교(aud · common_name · iss)가 늘 어긋나 조용한 403 · 401이 되거나 URL 해석이 공백을 지워 통과한다.
    토큰은 설정을 바꾸기 전에 만든다 — 앞 단계는 통과해 그 설정을 읽는 단계까지 간다. r5 W1 — 공백이 아닌 ASCII 제어 문자
    ESC · DEL(`~` 바로 위 경계)도 같은 설정 오류다(escape · delete 사례)."""
    name, template = REQUIRED_STRING_CASES[case]
    headers = _valid_headers(jwks_server)
    setattr(settings, name, template.format(port=closed_port(), sentinel=SENTINEL))
    with pytest.raises(ImproperlyConfigured) as excinfo:
        make_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, name)


# ac-5c 사례 이름 → AUTHENTIK_JWKS_URL 값 — ac-23b가 같은 목록을 쓴다(r3 U3).
JWKS_URL_BAD_CASES: dict[str, str] = {"ftp": "ftp://127.0.0.1:9/jwks/", "no-scheme": "127.0.0.1:9/{sentinel}/jwks/"}
# r4 V2 — 공백 · 보이지 않는 글자가 든 http URL도 설정 오류다(앞뒤 공백 · 탭 · 줄바꿈은 urllib · urlsplit가 지워 fetch가 되던 값).
# 포트 9는 위 사례와 같다(검사가 있으면 연결하지 않는다).
JWKS_URL_BAD_CASES.update(
    {f"v2-{form}": _malformed("http://127.0.0.1:9/{sentinel}/jwks/", form) for form in AUTH_STRING_FORMS}
)


@pytest.mark.parametrize("case", list(JWKS_URL_BAD_CASES))
def test_ac_5_jwks_url_must_be_http(
    case: str, make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5c — AUTHENTIK_JWKS_URL이 http · https URL이 아니면(PyJWKClient가 생성에서 거부한다) 설정 오류다(D5 · D6):
    ImproperlyConfigured(설정 이름만 · 연쇄 없음) — 토큰 결함(401)으로 접지 않는다 · 연결 시도 0. r4 V2 — 공백 · 보이지 않는
    글자가 든 http URL(v2-* — 검사가 없으면 fetch가 공백을 지워 통과하거나 503)도 같은 설정 오류다(_required가 먼저 본다).
    r5 W1 — 공백이 아닌 ASCII 제어 문자 ESC · DEL이 든 http URL(v2-escape · v2-delete)도 같다."""
    headers = _valid_headers(jwks_server)
    settings.AUTHENTIK_JWKS_URL = JWKS_URL_BAD_CASES[case].format(sentinel=SENTINEL)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        make_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, "AUTHENTIK_JWKS_URL")


def test_ac_5_optional_settings(
    make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5b — 빈 값이 유효한 설정(D6): ACCESS_AUD_ADMIN 빈 값 · 없음 = 집합에서 뺀다(M2M aud 200 · aud [""] 토큰 403 — 빈 값을
    집합에 남기면 PyJWT가 [""]를 받아들인다 · 사실 J10) · AUTH_ACTOR_SUB 없음 = impersonation(act 없이 200) / str이 아닌 값 →
    ImproperlyConfigured(이름만)."""
    bearer = _bearer(jwks_server)
    m2m = _access(jwks_server)
    empty_aud = _access(jwks_server, aud=[""])
    for state in ("empty", "missing"):
        if state == "empty":
            settings.ACCESS_AUD_ADMIN = ""
        else:
            del settings.ACCESS_AUD_ADMIN
        client = make_client()
        assert client.get(PROTECTED, headers=_headers(bearer=bearer, access=m2m)).status_code == 200, state
        response = client.get(PROTECTED, headers=_headers(bearer=bearer, access=empty_aud))
        assert response.status_code == 403, state
        assert_problem(response, 403, "access_required")
    del settings.AUTH_ACTOR_SUB
    no_act = _headers(bearer=_bearer(jwks_server, act=None), access=m2m)
    assert make_client().get(PROTECTED, headers=no_act).status_code == 200
    for name in OPTIONAL_SETTINGS:
        setattr(settings, name, [SENTINEL])
        with pytest.raises(ImproperlyConfigured) as excinfo:
            make_client().get(PROTECTED, headers=_headers(bearer=bearer, access=m2m))
        _assert_names_only(excinfo.value, name)
        setattr(settings, name, "")


# ac-5b(r4 V2) 사례 이름 → (설정 이름 · 값 틀) — _optional로 읽는 설정마다 값 꼴 열하나(r5 W1 ESC · DEL 포함). ac-23b가 같은
# 목록을 쓴다.
OPTIONAL_STRING_CASES: dict[str, tuple[str, str]] = {
    f"{name}-{form}": (name, _malformed(AUTH_STRING_BASES[name], form))
    for name in OPTIONAL_SETTINGS
    for form in AUTH_STRING_FORMS
}


@pytest.mark.parametrize("case", list(OPTIONAL_STRING_CASES))
def test_ac_5_optional_setting_must_be_printable_ascii(
    case: str, make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5b(r4 V2) — 빈 값이 유효한 설정(_optional — ACCESS_AUD_ADMIN · AUTH_ACTOR_SUB)도 공백 없는 출력 가능 ASCII만 받는다:
    빈 값은 그대로 유효하고(같은 자격으로 200 — 대조) · 값 꼴 열하나(r5 W1 ESC · DEL 포함)는 그 설정을 읽는 단계에서
    ImproperlyConfigured다(설정 이름만 · 감시 문자열 없음 · 연쇄 없음 — 검사가 없으면 ADMIN 쪽은 M2M aud로 200 · ACTOR 쪽은
    act.sub 불일치로 401이 된다)."""
    name, template = OPTIONAL_STRING_CASES[case]
    headers = _valid_headers(jwks_server)
    setattr(settings, name, "")
    assert make_client().get(PROTECTED, headers=headers).status_code == 200
    setattr(settings, name, template.format(port=closed_port(), sentinel=SENTINEL))
    with pytest.raises(ImproperlyConfigured) as excinfo:
        make_client().get(PROTECTED, headers=headers)
    _assert_names_only(excinfo.value, name)


# T070 r6 X1 — 인증 문자열 설정의 수락 쪽 경계(리뷰 r5 A-1): 공백 없는 출력 가능 ASCII 94자 전부(`!` U+0021 – `~` U+007E ·
# 리터럴로 쓰지 않고 만든다). 거부 쪽 경계(U+0020 · U+007F · 제어 문자 · 비ASCII)는 AUTH_STRING_FORMS가 가른다. r5 사례 목록에는
# 수락을 기대하는 값에 `!` · `~`가 없어, 그 둘을 거부하는 경계 변이(M125 · M126)가 목록 전부를 통과했다.
PRINTABLE_ASCII = "".join(map(chr, range(0x21, 0x7F)))
# URL에 인코딩 없이 쓸 수 있는 문장 부호 — 비예약 `~` + 하위 구분자 전부(`!$&'()*+,;=` · RFC 3986 sub-delims). ac-23e가
# AUTHENTIK_JWKS_URL 경로와 DRAGONFLY_URL 비밀번호 자리에 넣는다(고정 시험 값 — 비밀이 아니다).
URL_PUNCTUATION = "~!$&'()*+,;="


def test_ac_5_expected_cn_accepts_printable_ascii_boundary(
    contract_client: Callable[..., Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-5d(r6 X1) — V2 수락 쪽 경계의 요청 경로 대조: ACCESS_EXPECTED_CN에 PRINTABLE_ASCII(94자 전부)를 두고 같은
    common_name을 실은 유효 Access 토큰(+ 유효 Bearer)을 보내면 Access 단계를 통과해 200이다(뷰가 본 common_name = 94자 값
    그대로). 글자 판정 함수가 하나라(_printable_ascii — 요청 경로 · check_settings 공통) 요청 경로는 사례 하나로 고정된다
    (설정마다의 수락은 ac-23e). 경계 글자를 거부하는 변이(M125 `!` · M126 `~`)면 Access 단계에서 ImproperlyConfigured가
    올라간다. 대조: 마지막 글자(`~`)를 뺀 common_name은 403 access_required다(94자 값이 실제로 비교된다)."""
    assert (len(PRINTABLE_ASCII), PRINTABLE_ASCII[0], PRINTABLE_ASCII[-1]) == (94, "!", "~")
    settings.ACCESS_EXPECTED_CN = PRINTABLE_ASCII
    bearer = _bearer(jwks_server)
    client = contract_client()
    matching = _headers(bearer=bearer, access=_access(jwks_server, common_name=PRINTABLE_ASCII))
    response = client.get(PROTECTED, headers=matching)
    assert response.status_code == 200
    assert json.loads(response.content)["common_name"] == PRINTABLE_ASCII
    other = _headers(bearer=bearer, access=_access(jwks_server, common_name=PRINTABLE_ASCII[:-1]))
    assert_problem(client.get(PROTECTED, headers=other), 403, "access_required")


# --- 설정 검사 check_settings(T070 r3 U3) -------------------------------------------------------------------------------

# check_settings가 검사하는 설정과 그 순서(함수 독스트링 ①–⑪ — 고정 · 첫 실패에서 멈춘다).
CHECK_SETTINGS_ORDER = (
    "AUTH_EXEMPT_PATHS",
    "AUTH_ACCESS_ONLY_PATHS",
    "ACCESS_TEAM_DOMAIN",
    "ACCESS_AUD_M2M",
    "ACCESS_AUD_ADMIN",
    "ACCESS_EXPECTED_CN",
    "AUTHENTIK_JWKS_URL",
    "AUTHENTIK_ISSUER",
    "AUTHENTIK_AUDIENCE",
    "AUTH_ACTOR_SUB",
    "DRAGONFLY_URL",
)
MISSING = object()  # 설정을 지운다(delattr — ac-5a의 missing)
# DRAGONFLY_URL — 요청 때는 503 denylist_unavailable(error=url_query · 예외 클래스 — ac-12b)이고 check_settings에서는 설정
# 오류인 값: 쿼리(redis-py가 타임아웃 · 재시도를 덮어쓴다 — 사실 ④) · Redis.from_url이 받지 않는 URL. 감시 문자열을 비밀번호 ·
# 쿼리 · 포트 자리에 심는다. {port}는 닫힌 포트다.
DRAGONFLY_URL_BAD_CASES: dict[str, str] = {
    "query-timeout": "redis://test-pod:{sentinel}@127.0.0.1:{port}/0?socket_timeout=5",
    "query-sentinel": "redis://test-pod@127.0.0.1:{port}/0?client_name={sentinel}",
    "http-scheme": "http://test-pod:{sentinel}@127.0.0.1:{port}/0",
    "non-numeric-port": "redis://test-pod:{sentinel}@127.0.0.1:{sentinel}/0",
    "unclosed-bracket": "redis://test-pod:{sentinel}@[::1/0",
}
# 사례 이름(출처 시험 접두) → (설정 이름 · 값) — 요청 때 ImproperlyConfigured가 되는 값 전부(ac-3a · ac-4b · ac-4e · ac-5a ·
# ac-5c · ac-5b의 매개 변수 목록 그대로)와 DRAGONFLY_URL_BAD_CASES. 문자열 값의 {port} · {sentinel}은 시험이 채운다.
CHECK_SETTINGS_REJECTED: dict[str, tuple[str, object]] = {
    **{f"ac3a-{name}-{case}": (name, value) for name in PATH_SETTINGS for case, value in _bad_path_values().items()},
    **{f"ac4b-{case}": ("ACCESS_TEAM_DOMAIN", value) for case, value in TEAM_DOMAIN_SHAPE_CASES.items()},
    **{f"ac4e-{case}": ("ACCESS_TEAM_DOMAIN", value) for case, value in TEAM_DOMAIN_REJECTED_CASES.items()},
    **{
        f"ac5a-{name}-{state}": (name, {"empty": "", "missing": MISSING, "not-str": [SENTINEL]}[state])
        for name in REQUIRED_SETTINGS
        for state in REQUIRED_SETTING_STATES
    },
    **{f"ac5c-{case}": ("AUTHENTIK_JWKS_URL", value) for case, value in JWKS_URL_BAD_CASES.items()},
    **{f"ac5b-{name}-not-str": (name, [SENTINEL]) for name in OPTIONAL_SETTINGS},
    **{f"dragonfly-{case}": ("DRAGONFLY_URL", value) for case, value in DRAGONFLY_URL_BAD_CASES.items()},
    # r4 V2 — 인증 문자열 설정의 값 꼴(ac-5a · ac-5b의 r4 목록 그대로 · ac-5c의 v2-* 사례는 위 ac5c-로 들어간다).
    **{f"ac5a-{case}": (name, value) for case, (name, value) in REQUIRED_STRING_CASES.items()},
    **{f"ac5b-{case}": (name, value) for case, (name, value) in OPTIONAL_STRING_CASES.items()},
}


def test_ac_23_check_settings_accepts_valid_settings_offline(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ac-23a — check_settings()(T070 r3 U3 · 공개 — 기동 검사(T072)가 부른다): 좋은 설정이면 None — 시험 설정(127.0.0.1 키
    서버 · Dragonfly reader)과 운영 꼴 이름 값(스킴 없는 팀 도메인 · svc DNS JWKS URL · Dragonfly svc URL · 빈 ACCESS_AUD_ADMIN ·
    AUTH_ACTOR_SUB 값) 둘 다. 네트워크 0: 소켓 연결(Dragonfly 연결 포함) · 키 fetch(PyJWKClient.fetch_data) · 스레드 시작 0 ·
    이름 조회 0(autouse 가드 — 운영 꼴 이름을 조회하면 기록돼 실패한다)."""
    counts = dict.fromkeys(("connect", "fetch", "thread"), 0)

    def counting(key: str, real: Callable[..., Any]) -> Callable[..., Any]:
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            counts[key] += 1
            return real(*args, **kwargs)

        return wrapper

    def no_fetch(client: jwt.PyJWKClient) -> dict[str, Any]:
        counts["fetch"] += 1
        raise jwt.PyJWKClientConnectionError("시험: check_settings는 키를 가져오지 않는다")

    monkeypatch.setattr(socket.socket, "connect", counting("connect", socket.socket.connect))
    monkeypatch.setattr(socket.socket, "connect_ex", counting("connect", socket.socket.connect_ex))
    monkeypatch.setattr(socket, "create_connection", counting("connect", socket.create_connection))
    monkeypatch.setattr(threading.Thread, "start", counting("thread", threading.Thread.start))
    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", no_fetch)
    assert auth.check_settings() is None
    settings.ACCESS_TEAM_DOMAIN = "joshua-tech.cloudflareaccess.com"
    settings.AUTHENTIK_JWKS_URL = "http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/"
    random_part = secrets.token_urlsafe(16)
    settings.DRAGONFLY_URL = Secret(f"redis://identity-admin:{random_part}@dragonfly-prod.data.svc:6379/0")
    settings.ACCESS_AUD_ADMIN = ""
    settings.AUTH_ACTOR_SUB = ACTOR
    assert auth.check_settings() is None
    assert counts == {"connect": 0, "fetch": 0, "thread": 0}


@pytest.mark.parametrize("case", list(CHECK_SETTINGS_REJECTED))
def test_ac_23_check_settings_rejects_every_config_error(case: str, settings: SettingsWrapper) -> None:
    """ac-23b — 요청 때 ImproperlyConfigured가 되는 값은 check_settings()도 거부한다(T070 r3 U3 — 요청 경로와 같은 판정 함수 ·
    ac-3a · ac-4b · ac-4e · ac-5a · ac-5c · ac-5b의 매개 변수 목록 그대로) · DRAGONFLY_URL의 쿼리 · Redis.from_url이 받지 않는
    URL(요청 때는 503)도 설정 오류다 → ImproperlyConfigured(그 설정 이름 · 값(감시 문자열) 없음 · __cause__ · __context__ 없음)."""
    name, value = CHECK_SETTINGS_REJECTED[case]
    if value is MISSING:
        delattr(settings, name)
    elif isinstance(value, str):
        setattr(settings, name, value.format(port=closed_port(), sentinel=SENTINEL))
    else:
        setattr(settings, name, value)
    with pytest.raises(ImproperlyConfigured) as excinfo:
        auth.check_settings()
    _assert_names_only(excinfo.value, name)


def test_ac_23_check_settings_fixed_order_stops_at_first_failure(settings: SettingsWrapper) -> None:
    """ac-23c — 검사 순서는 고정이고 첫 실패에서 멈춘다(T070 r3 U3 — 함수 독스트링 ①–⑪): 검사하는 설정 11개를 모두 틀린
    값(경로 목록 = str 하나 · 나머지 = 감시 문자열을 담은 목록)으로 둔 뒤 앞에서부터 하나씩 되돌리면, 오류는 차례로 그 설정 이름
    하나만 싣는다(뒤 설정 이름 · 값 없음) → 다 되돌리면 None."""
    good = {name: getattr(settings, name, MISSING) for name in CHECK_SETTINGS_ORDER}
    for name in CHECK_SETTINGS_ORDER:
        setattr(settings, name, SENTINEL if name in PATH_SETTINGS else [SENTINEL])
    named: list[list[str]] = []
    for name in CHECK_SETTINGS_ORDER:
        with pytest.raises(ImproperlyConfigured) as excinfo:
            auth.check_settings()
        _assert_names_only(excinfo.value, name)
        message = str(excinfo.value)
        named.append([other for other in CHECK_SETTINGS_ORDER if other in message])
        if good[name] is MISSING:
            delattr(settings, name)
        else:
            setattr(settings, name, good[name])
    assert named == [[name] for name in CHECK_SETTINGS_ORDER]
    assert auth.check_settings() is None


# ac-23d(r4 V3) — 설정마다 형 검사(_paths · _required · _optional의 비었거나 str 아님)를 통과하고 그 뒤 검사에서 걸리는 깊은 오류
# 값(감시 문자열을 심는다): 경로 목록 = str 아닌 원소를 담은 목록 · 팀 도메인 = LDH 위반(빈 라벨) · 문자열 설정 = V2 위반 ·
# AUTHENTIK_JWKS_URL = ftp(필수 · V2를 통과하고 스킴 검사에서 걸린다) · DRAGONFLY_URL = 쿼리(쿼리 검사에서 걸린다).
CHECK_SETTINGS_DEEP_VALUES: dict[str, object] = {
    "AUTH_EXEMPT_PATHS": (f"/{SENTINEL}", 1),
    "AUTH_ACCESS_ONLY_PATHS": [f"/{SENTINEL}", None],
    "ACCESS_TEAM_DOMAIN": f"https://{SENTINEL}..cloudflareaccess.com",
    "ACCESS_AUD_M2M": f"{SENTINEL}-aud-m2m{LF}",
    "ACCESS_AUD_ADMIN": f"{SENTINEL}{NBSP}-aud-admin",
    "ACCESS_EXPECTED_CN": f"{SENTINEL}{ZERO_WIDTH}.access",
    "AUTHENTIK_JWKS_URL": f"ftp://127.0.0.1:9/{SENTINEL}/jwks/",
    "AUTHENTIK_ISSUER": f" https://{SENTINEL}.example.test/application/o/identity-admin/",
    "AUTHENTIK_AUDIENCE": f"{SENTINEL}{TAB}-audience",
    "AUTH_ACTOR_SUB": f"{SENTINEL}{HANGUL_FILLER}-actor",
    "DRAGONFLY_URL": f"redis://test-pod:{SENTINEL}@127.0.0.1:9/0?socket_timeout=5",
}


def test_ac_23_check_settings_fixed_order_with_deep_errors(settings: SettingsWrapper) -> None:
    """ac-23d — 검사 순서 고정을 깊은 오류 값으로 한 번 더(T070 r4 V3 — ac-23c는 모든 값을 str 아님으로 두어 형 검사의 자리만
    고정한다): 검사하는 설정 11개를 CHECK_SETTINGS_DEEP_VALUES(형 검사는 통과하고 뒤 검사에서 걸리는 값)로 둔 뒤 앞에서부터 하나씩
    되돌리면, 오류는 차례로 그 설정 이름 하나만 싣는다(뒤 설정 이름 · 값 없음) — JWKS 스킴 검사(⑦ _key_client)는 ⑥ 뒤 · ⑧ 앞,
    DRAGONFLY_URL 쿼리 검사(⑪)는 마지막 자리에 고정된다 → 다 되돌리면 None."""
    assert list(CHECK_SETTINGS_DEEP_VALUES) == list(CHECK_SETTINGS_ORDER)
    good = {name: getattr(settings, name, MISSING) for name in CHECK_SETTINGS_ORDER}
    for name, value in CHECK_SETTINGS_DEEP_VALUES.items():
        setattr(settings, name, value)
    named: list[list[str]] = []
    for name in CHECK_SETTINGS_ORDER:
        with pytest.raises(ImproperlyConfigured) as excinfo:
            auth.check_settings()
        _assert_names_only(excinfo.value, name)
        message = str(excinfo.value)
        named.append([other for other in CHECK_SETTINGS_ORDER if other in message])
        if good[name] is MISSING:
            delattr(settings, name)
        else:
            setattr(settings, name, good[name])
    assert named == [[name] for name in CHECK_SETTINGS_ORDER]
    assert auth.check_settings() is None


# ac-23e(r6 X1) 설정 이름 → V2 수락 쪽 경계 값. 글자 검사(_printable_ascii)만 받는 자유 꼴 6개는 94자 전부 · AUTHENTIK_JWKS_URL은
# 경로에 URL_PUNCTUATION이 든 루프백 URL(check_settings는 fetch하지 않는다 · 포트 9는 ac-5c와 같다) · DRAGONFLY_URL은 비밀번호
# 자리에 같은 글자(사용자 · 호스트 · 포트 · DB는 ac-23a의 운영 꼴 — 연결 · 이름 조회 없음 · 자격이 든 URL이라 Secret으로 감싼다).
# ACCESS_TEAM_DOMAIN은 범위 밖이다(팀 기준 URL 원문 검사가 호스트 글자를 따로 거른다 — 수락 꼴은 ac-4d가 고정한다).
FREE_FORM_STRING_SETTINGS = (
    "ACCESS_AUD_M2M",
    "ACCESS_AUD_ADMIN",
    "ACCESS_EXPECTED_CN",
    "AUTHENTIK_ISSUER",
    "AUTHENTIK_AUDIENCE",
    "AUTH_ACTOR_SUB",
)
CHECK_SETTINGS_ACCEPTED_BOUNDARY: dict[str, str] = {
    **dict.fromkeys(FREE_FORM_STRING_SETTINGS, PRINTABLE_ASCII),
    "AUTHENTIK_JWKS_URL": f"http://127.0.0.1:9/{URL_PUNCTUATION}/jwks/",
    "DRAGONFLY_URL": Secret(f"redis://identity-admin:{URL_PUNCTUATION}@dragonfly-prod.data.svc:6379/0"),
}


def _count_network_calls(monkeypatch: pytest.MonkeyPatch) -> dict[str, int]:
    """ac-23a와 같은 네트워크 셈을 건다 — 소켓 연결(connect · connect_ex · create_connection) · 스레드 시작은 세고 그대로 부르며,
    키 fetch(PyJWKClient.fetch_data)는 세고 실패한다(check_settings는 키를 가져오지 않는다). 셈 dict를 돌려준다. 이름 조회는
    autouse 가드가 막고 기록한다(ac-23a는 같은 셈을 자기 본문에 둔다 — r3부터 그대로)."""
    counts = dict.fromkeys(("connect", "fetch", "thread"), 0)

    def counting(key: str, real: Callable[..., Any]) -> Callable[..., Any]:
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            counts[key] += 1
            return real(*args, **kwargs)

        return wrapper

    def no_fetch(client: jwt.PyJWKClient) -> dict[str, Any]:
        counts["fetch"] += 1
        raise jwt.PyJWKClientConnectionError("시험: check_settings는 키를 가져오지 않는다")

    monkeypatch.setattr(socket.socket, "connect", counting("connect", socket.socket.connect))
    monkeypatch.setattr(socket.socket, "connect_ex", counting("connect", socket.socket.connect_ex))
    monkeypatch.setattr(socket, "create_connection", counting("connect", socket.create_connection))
    monkeypatch.setattr(threading.Thread, "start", counting("thread", threading.Thread.start))
    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", no_fetch)
    return counts


@pytest.mark.parametrize("name", list(CHECK_SETTINGS_ACCEPTED_BOUNDARY))
def test_ac_23_check_settings_accepts_printable_ascii_boundary(
    name: str, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ac-23e(r6 X1 · 리뷰 r5 A-1) — V2 수락 쪽 경계: 설정 하나에 `!` · `~`가 든 정당한 값(CHECK_SETTINGS_ACCEPTED_BOUNDARY —
    나머지는 시험 기본 설정 그대로)을 두면 check_settings()는 None이다. 네트워크 0은 ac-23a 꼴이다(소켓 연결 · 키 fetch · 스레드
    시작 0 · 이름 조회 0 — autouse 가드). 계약 · 규칙 · 독스트링은 `!`–`~` 전체를 받는다고 약속한다 — 경계 글자를 거부하는
    변이(M125 `!` · M126 `~`)나 글자를 좁힌 규칙(RFC 3986 글자만 받는 꼴 등)이면 정당한 값이 기동 실패가 된다(예: 비밀번호에
    `~` · `!`가 든 DRAGONFLY_URL)."""
    value = CHECK_SETTINGS_ACCEPTED_BOUNDARY[name]
    assert {"!", "~"} <= set(value)  # 경계 글자 둘이 다 든 값이다(사례가 공허하지 않다)
    counts = _count_network_calls(monkeypatch)
    setattr(settings, name, value)
    assert auth.check_settings() is None
    assert counts == {"connect": 0, "fetch": 0, "thread": 0}


# --- Bearer(D4) ------------------------------------------------------------------------------------------------------

CLAIM_SHAPE_CASES: dict[str, dict[str, Any]] = {
    "empty-sub": {"sub": ""},
    "int-sub": {"sub": 123},
    "empty-sid": {"sid": ""},
    "int-sid": {"sid": 7},
    "null-sid": {"sid": None},
    "upper-tenant": {"tenant_id": TENANT_ID.upper()},
    "braced-tenant": {"tenant_id": "{" + TENANT_ID + "}"},
    "urn-tenant": {"tenant_id": "urn:uuid:" + TENANT_ID},
    "hex32-tenant": {"tenant_id": TENANT_ID.replace("-", "")},
    "int-tenant": {"tenant_id": 10},
    "list-tenant": {"tenant_id": [TENANT_ID]},
    "null-tenant": {"tenant_id": None},
}


@pytest.mark.parametrize("case", list(CLAIM_SHAPE_CASES))
def test_ac_10_bearer_claim_shape_is_401(case: str, auth_client: Client, jwks_server: JwksInfo) -> None:
    """ac-10a — Bearer 클레임 모양(D4 · fail-closed): sub는 비지 않은 str · sid는 있으면(JSON null 포함) 비지 않은 str ·
    tenant_id는 있으면 소문자 정규형 UUID 문자열(`str(uuid.UUID(v)) == v` — 대문자 · 중괄호 · urn:uuid: · 32 hex · 비str ·
    null 거부 · 비str은 uuid.UUID가 AttributeError라 검사 없이는 500) → 401 invalid_token(예외 · 500이 아니다)."""
    claims = bearer_claims()
    claims.update(CLAIM_SHAPE_CASES[case])
    bearer = mint(claims, jwks_server.authentik_key, AUTHENTIK_KID)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    assert_problem(response, 401, "invalid_token")


ACTOR_SHAPE_CASES: dict[str, object] = {
    "str-act": ACTOR,
    "list-act": [ACTOR],
    "list-act-sub": {"sub": [ACTOR]},
    "int-act-sub": {"sub": 1},
    "empty-act": {},
    "null-act": None,
}


@pytest.mark.parametrize("case", list(ACTOR_SHAPE_CASES))
def test_ac_10_actor_shape_is_401(
    case: str, make_client: Callable[[], Client], jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-10b — AUTH_ACTOR_SUB가 비어 있지 않으면 act는 dict이고 act.sub가 같아야 한다(D4): 문자열 · 목록 · null · 빈 dict ·
    act.sub가 목록 · 정수 → 401 invalid_token(비dict act는 검사 없이는 AttributeError 500)."""
    settings.AUTH_ACTOR_SUB = ACTOR
    claims = bearer_claims()
    claims["act"] = ACTOR_SHAPE_CASES[case]
    bearer = mint(claims, jwks_server.authentik_key, AUTHENTIK_KID)
    response = make_client().get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    assert_problem(response, 401, "invalid_token")


def test_ac_10_actor_is_ignored_in_impersonation_mode(auth_client: Client, jwks_server: JwksInfo) -> None:
    """ac-10c — AUTH_ACTOR_SUB 빈 값(impersonation 기본 모드)이면 act를 보지 않는다(D4 — 모양도 · 문자열 act도 200)."""
    claims = bearer_claims()
    claims["act"] = ACTOR
    bearer = mint(claims, jwks_server.authentik_key, AUTHENTIK_KID)
    response = auth_client.get(PROTECTED, headers=_headers(bearer=bearer, access=_access(jwks_server)))
    assert response.status_code == 200


def test_ac_11_authorization_header_forms(auth_client: Client, jwks_server: JwksInfo) -> None:
    """ac-11a — Authorization(D4): 스킴 대소문자 무시(bearer · BEARER · 섞임 200) · 구분은 공백 하나 · 토큰에 공백 없음 —
    공백 둘 · 탭 · 토큰 안 공백 · 끝 공백 · 앞 공백 · 빈 토큰 · 스킴만 · 스킴 없음 · 다른 스킴 → 401 invalid_token."""
    token = _bearer(jwks_server)
    access = _access(jwks_server)
    accepted = {"lower": f"bearer {token}", "upper": f"BEARER {token}", "mixed": f"bEaReR {token}"}
    rejected = {
        "two-spaces": f"Bearer  {token}",
        "tab": f"Bearer\t{token}",
        "space-in-token": f"Bearer {token[:20]} {token[20:]}",
        "trailing-space": f"Bearer {token} ",
        "leading-space": f" Bearer {token}",
        "empty-token": "Bearer ",
        "scheme-only": "Bearer",
        "no-scheme": token,
        "other-scheme": f"Token {token}",
    }
    for case, value in accepted.items():
        response = auth_client.get(PROTECTED, headers={"Authorization": value, "Cf-Access-Jwt-Assertion": access})
        assert response.status_code == 200, case
    for case, value in rejected.items():
        response = auth_client.get(PROTECTED, headers={"Authorization": value, "Cf-Access-Jwt-Assertion": access})
        assert response.status_code == 401, case
        assert_problem(response, 401, "invalid_token")


def test_ac_11_leeway_is_five_seconds(auth_client: Client, jwks_server: JwksInfo) -> None:
    """ac-11b — leeway 5 s(D3 · D4 — 발급자 · pod 시계 차 흡수 · auth-2/5/13의 ±60 s 경계 안): Bearer · Access 모두 exp =
    지금 − 2 s 수락 · − 9 s 거부 / nbf = 지금 + 2 s 수락 · + 9 s 거부(Access 미래 nbf 403 포함) / iat = 지금 + 2 s 수락 ·
    + 9 s 거부(미래 iat). 경계까지 여유가 2 s 이상이다(정수 초 · 요청 왕복 ms)."""
    now = int(time.time())

    def bearer(**claims: int) -> dict[str, str]:
        return _headers(bearer=_bearer(jwks_server, **claims), access=_access(jwks_server))

    def access(**claims: int) -> dict[str, str]:
        return _headers(bearer=_bearer(jwks_server), access=_access(jwks_server, **claims))

    accepted = {
        "bearer-exp-2": bearer(exp=now - 2),
        "bearer-nbf+2": bearer(nbf=now + 2),
        "bearer-iat+2": bearer(iat=now + 2),
        "access-exp-2": access(exp=now - 2),
        "access-nbf+2": access(nbf=now + 2),
        "access-iat+2": access(iat=now + 2),
    }
    rejected = {
        "bearer-exp-9": (401, "invalid_token", bearer(exp=now - 9)),
        "bearer-nbf+9": (401, "invalid_token", bearer(nbf=now + 9)),
        "bearer-iat+9": (401, "invalid_token", bearer(iat=now + 9)),
        "access-exp-9": (403, "access_required", access(exp=now - 9)),
        "access-nbf+9": (403, "access_required", access(nbf=now + 9)),
        "access-iat+9": (403, "access_required", access(iat=now + 9)),
    }
    for case, headers in accepted.items():
        assert auth_client.get(PROTECTED, headers=headers).status_code == 200, case
    for case, (status, slug, headers) in rejected.items():
        response = auth_client.get(PROTECTED, headers=headers)
        assert response.status_code == status, case
        assert_problem(response, status, slug)


# --- 키 가져오기(D5) ---------------------------------------------------------------------------------------------------


def _point_at(settings: SettingsWrapper, server: KeyServer, jwks: JwksInfo, source: str) -> dict[str, str]:
    """source(access · authentik) 쪽 키 URL만 키 서버로 돌리고, 그 설정에서 통과할 헤더를 만든다."""
    if source == "access":
        settings.ACCESS_TEAM_DOMAIN = server.base_url
        access = _access(jwks, iss=server.base_url)
    else:
        settings.AUTHENTIK_JWKS_URL = server.url(JWKS_PATH)
        access = _access(jwks)
    return _headers(bearer=_bearer(jwks), access=access)


@pytest.mark.parametrize("source", ["access", "authentik"])
@pytest.mark.parametrize("mode", KEY_FAILURE_MODES)
def test_ac_6_key_set_failure_is_503(
    source: str,
    mode: str,
    make_client: Callable[[], Client],
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-6a — 키 집합을 가져오거나 읽지 못하면(HTTP 500 · JSON 아님 · 객체 아닌 JSON · 빈 키 세트 · 서명 키 후보 없음 — kid
    없는 키만) 토큰 결함이 아니라 의존성 장애다(D5): Access · Authentik 어느 쪽이든 503 auth_keys_unavailable(Access 403 ·
    Bearer 401이 아니다 · PyJWT는 이 가운데 셋을 모르는 kid와 같은 PyJWKClientError로 올린다) · fetch 1번 · 응답에 감시
    문자열(서버 사유 문구 · 오류 본문) · 키 URL · 토큰이 없다 · django_common.auth WARNING 한 줄
    `auth.keys_unavailable source=<access|authentik> error=<예외 클래스>` — 로그에도 그 값들이 없다."""
    headers = _point_at(settings, key_server, jwks_server, source)
    path = CERTS_PATH if source == "access" else JWKS_PATH
    key_server.set_mode(path, mode)
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    response = make_client().get(PROTECTED, headers=headers)
    assert response.status_code == 503
    assert_problem(response, 503, "auth_keys_unavailable")
    assert key_server.hits[path] == 1
    _assert_absent(_response_text(response), SENTINEL, key_server.url(path), *headers.values())
    _assert_warning_lines(caplog, f"auth.keys_unavailable source={source}")
    _assert_absent(caplog.text, SENTINEL, key_server.url(path), *headers.values())


@pytest.mark.parametrize("source", ["access", "authentik"])
@pytest.mark.parametrize("failure", ["closed-port", "blackhole"])
def test_ac_6_key_endpoint_unreachable_is_503_within_fetch_timeout(
    source: str,
    failure: str,
    make_client: Callable[[], Client],
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-6b — 키 엔드포인트에 닿지 못함(닫힌 포트 · 응답 없는 소켓 — 연결은 성립하고 응답이 없다) → 503
    auth_keys_unavailable · 요청 전체 < 2.8 s(fetch 시간 초과 2 s · D5 — 응답 없는 소켓의 판정 시간은 timeout과 거의 같아
    timeout 2 s와 3 s를 가른다(T070 r2 N3) · BFF 예산 3 s 미만 · PyJWKClient 기본 30 s면 30 s) · WARNING 한 줄."""
    caplog.set_level(logging.DEBUG, logger=LOGGER)

    def run(port: int) -> tuple[HttpResponse, float]:
        url = f"http://127.0.0.1:{port}"
        if source == "access":
            settings.ACCESS_TEAM_DOMAIN = url
            access = _access(jwks_server, iss=url)
        else:
            settings.AUTHENTIK_JWKS_URL = url + JWKS_PATH
            access = _access(jwks_server)
        headers = _headers(bearer=_bearer(jwks_server), access=access)
        client = make_client()
        return _timed(lambda: client.get(PROTECTED, headers=headers))

    if failure == "blackhole":
        with blackhole() as port:
            response, elapsed = run(port)
    else:
        response, elapsed = run(closed_port())
    assert_problem(response, 503, "auth_keys_unavailable")
    assert elapsed < KEY_FETCH_LIMIT_S, f"판정 {elapsed:.3f} s"
    _assert_warning_lines(caplog, f"auth.keys_unavailable source={source}")


def test_ac_7_unknown_kid_is_token_defect_without_refetch_flood(
    make_client: Callable[[], Client], key_server: KeyServer, jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-7 — 모르는 kid(재조회 뒤에도 키 없음 · 헤더에 kid 없음 포함)는 토큰 결함이다(D5): Bearer 401 invalid_token · Access
    403 access_required(503이 아니다) · 마지막 성공 fetch 뒤 cooldown(30 s — PyJWT 기본값 그대로) 안에는 다시 가져오지
    않는다(모르는 kid 홍수가 fetch 폭주를 만들지 않는다 — 요청 6번 동안 경로마다 fetch 1)."""
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    settings.AUTHENTIK_JWKS_URL = key_server.url(JWKS_PATH)
    client = make_client()
    access = _access(jwks_server, iss=key_server.base_url)
    unknown_bearers = (
        mint(bearer_claims(), jwks_server.authentik_key, "rotated-kid-1"),
        mint(bearer_claims(), jwks_server.authentik_key, "rotated-kid-2"),
        jwt.encode(bearer_claims(), jwks_server.authentik_key, algorithm="RS256"),
    )
    for index, bearer in enumerate(unknown_bearers):
        response = client.get(PROTECTED, headers=_headers(bearer=bearer, access=access))
        assert response.status_code == 401, index
        assert_problem(response, 401, "invalid_token")
    bearer = _bearer(jwks_server)
    unknown_accesses = (
        mint(access_claims(iss=key_server.base_url), jwks_server.access_key, "rotated-kid-1"),
        mint(access_claims(iss=key_server.base_url), jwks_server.access_key, "rotated-kid-2"),
        jwt.encode(access_claims(iss=key_server.base_url), jwks_server.access_key, algorithm="RS256"),
    )
    for index, token in enumerate(unknown_accesses):
        response = client.get(PROTECTED, headers=_headers(bearer=bearer, access=token))
        assert response.status_code == 403, index
        assert_problem(response, 403, "access_required")
    assert (key_server.hits[JWKS_PATH], key_server.hits[CERTS_PATH]) == (1, 1)


def test_ac_8_keys_cached_one_hour_and_never_reused_after_expiry(
    make_client: Callable[[], Client],
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-8 — 서명 키 캐시 1시간(lifespan 3600 · D5 — PyJWT 기본 300 s가 아니다) · 만료 뒤 fetch가 실패하면 만료된 키를 쓰지
    않는다(503 auth_keys_unavailable · fail-closed). PyJWT 캐시 시계 · auth 백오프 시계(ShiftedClock)를 돌린다: 0 s 200(경로마다
    fetch 1) → 키 서버를 HTTP 500으로 → +301 s 200(캐시 · fetch 0) → +3601 s 503(Access가 먼저 만료 재조회 · source=access) →
    certs만 되살려도 그 실패가 연 백오프 창(1 s — T070 r3 U4) 안에서는 다시 가져오지 않는다(503 · fetch 0 · error=backoff) → 창
    밖이면 Access는 다시 가져와 통과하고 Authentik 쪽 만료 재조회가 503(source=authentik). 토큰 시각 검증은 실제 시계다."""
    clock = install_shifted_clock(monkeypatch)
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    settings.AUTHENTIK_JWKS_URL = key_server.url(JWKS_PATH)
    client = make_client()

    def get() -> HttpResponse:
        headers = _headers(bearer=_bearer(jwks_server), access=_access(jwks_server, iss=key_server.base_url))
        return client.get(PROTECTED, headers=headers)

    def hits() -> tuple[int, int]:
        return key_server.hits[JWKS_PATH], key_server.hits[CERTS_PATH]

    assert get().status_code == 200
    assert hits() == (1, 1)
    key_server.set_mode(JWKS_PATH, "status-500")
    key_server.set_mode(CERTS_PATH, "status-500")
    clock.advance(301)
    assert get().status_code == 200
    assert hits() == (1, 1)
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    clock.advance(3300)
    assert_problem(get(), 503, "auth_keys_unavailable")
    assert hits() == (1, 2)
    key_server.set_mode(CERTS_PATH, "ok")
    assert_problem(get(), 503, "auth_keys_unavailable")  # r3 U4 — 바로 앞 실패가 연 백오프 창(1 s) 안: fetch 0
    assert hits() == (1, 2)
    clock.advance(1 + BACKOFF_PROBE_S)  # 창 밖으로 — 아래는 r2까지의 단언 그대로다
    assert_problem(get(), 503, "auth_keys_unavailable")
    assert hits() == (2, 3)
    _assert_warning_lines(
        caplog,
        "auth.keys_unavailable source=access",
        "auth.keys_unavailable source=access",
        "auth.keys_unavailable source=authentik",
    )
    assert _error_words(caplog) == ["PyJWKClientConnectionError", "backoff", "PyJWKClientConnectionError"]


def test_ac_9_refresh_failure_after_cooldown_is_503(
    make_client: Callable[[], Client],
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """ac-9 — cooldown(30 s)이 지난 뒤 모르는 kid가 오면 PyJWT가 한 번 다시 가져온다 — 그 재조회의 실패(HTTP 500 · 객체 아닌
    JSON)는 의존성 장애다(503 auth_keys_unavailable — 객체 아닌 JSON은 PyJWT가 모르는 kid와 같은 PyJWKClientError로 올리므로
    예외 클래스로는 가를 수 없다 · D5). 그 사이에도 캐시(유효)의 kid는 200 · 재조회가 성공하고도 kid가 없으면 401
    invalid_token · fetch는 첫 1 + 재조회 3."""
    clock = install_shifted_clock(monkeypatch)
    settings.AUTHENTIK_JWKS_URL = key_server.url(JWKS_PATH)
    client = make_client()
    access = _access(jwks_server)
    assert client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server), access=access)).status_code == 200
    rotated = mint(bearer_claims(), jwks_server.authentik_key, "rotated-kid")
    for mode in ("status-500", "non-object"):
        key_server.set_mode(JWKS_PATH, mode)
        clock.advance(31)
        response = client.get(PROTECTED, headers=_headers(bearer=rotated, access=access))
        assert response.status_code == 503, mode
        assert_problem(response, 503, "auth_keys_unavailable")
        known = _headers(bearer=_bearer(jwks_server), access=access)
        assert client.get(PROTECTED, headers=known).status_code == 200, mode
    key_server.set_mode(JWKS_PATH, "ok")
    clock.advance(31)
    assert_problem(client.get(PROTECTED, headers=_headers(bearer=rotated, access=access)), 401, "invalid_token")
    assert key_server.hits[JWKS_PATH] == 4


def test_ac_21_each_middleware_instance_fetches_its_own_keys(
    make_client: Callable[[], Client], key_server: KeyServer, jwks_server: JwksInfo, settings: SettingsWrapper
) -> None:
    """ac-21 — 키 캐시는 미들웨어 인스턴스 안에 있다(D5 — 프로세스 전역 캐시가 아니다): 새 Client(= 새 인스턴스)마다 경로당
    fetch 1 · 같은 인스턴스 안에서는 0(auth-28) — T066 api-45가 기대는 동작."""
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    settings.AUTHENTIK_JWKS_URL = key_server.url(JWKS_PATH)
    for expected in (1, 2):
        client = make_client()
        for _ in range(2):
            headers = _headers(bearer=_bearer(jwks_server), access=_access(jwks_server, iss=key_server.base_url))
            assert client.get(PROTECTED, headers=headers).status_code == 200
        assert (key_server.hits[JWKS_PATH], key_server.hits[CERTS_PATH]) == (expected, expected)


# --- 키 fetch 실패 백오프(T070 r3 U4) ------------------------------------------------------------------------------------


@pytest.mark.parametrize("source", ["access", "authentik"])
def test_ac_24_fetch_failure_opens_backoff_window(
    source: str,
    make_client: Callable[[], Client],
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24a — 키 fetch가 실패하면 그 키 URL에 백오프 창(1 s)이 열린다(T070 r3 U4): 빈 캐시 + HTTP 500 → 첫 판정 503(fetch 1) ·
    창 안의 두 번째 판정은 네트워크 없이 곧바로 503 auth_keys_unavailable(fetch 0 — 키 서버 GET 수 그대로) · WARNING 두 줄의
    error = 원 예외 클래스 → backoff(백오프 신호가 예외 클래스 이름으로 새지 않는다) · 응답 · 로그에 감시 문자열 · 키 URL · 토큰
    없음."""
    headers = _point_at(settings, key_server, jwks_server, source)
    path = CERTS_PATH if source == "access" else JWKS_PATH
    key_server.set_mode(path, "status-500")
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    client = make_client()
    for attempt in range(2):
        response = client.get(PROTECTED, headers=headers)
        assert response.status_code == 503, attempt
        assert_problem(response, 503, "auth_keys_unavailable")
        assert key_server.hits[path] == 1, attempt
        _assert_absent(_response_text(response), SENTINEL, key_server.url(path), *headers.values())
    _assert_warning_lines(caplog, *[f"auth.keys_unavailable source={source}"] * 2)
    assert _error_words(caplog) == ["PyJWKClientConnectionError", "backoff"]
    _assert_absent(caplog.text, SENTINEL, key_server.url(path), *headers.values())


def test_ac_24_backoff_window_doubles_up_to_30s_and_resets(
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24b — 창 길이(T070 r3 U4): 연속 실패마다 직전 창의 2배 · 상한 30 s → 1 · 2 · 4 · 8 · 16 · 30 · 30 s(창 끝 0.25 s 전은
    fetch 0 · 503 / 0.25 s 뒤는 다시 가져온다) · 창이 지나 fetch가 성공하면 초기화 — 그 뒤 첫 실패(cooldown 30 s가 지난 모르는 kid
    재조회)는 다시 1 s 창이고, 창 안에서는 모르는 kid 재조회도 네트워크를 타지 않는다. 막힌 판정의 WARNING은 error=backoff다.
    백오프 시계는 auth 모듈의 time.monotonic(ShiftedClock — 실제 대기 0)이다."""
    clock = install_shifted_clock(monkeypatch)
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    key_server.set_mode(CERTS_PATH, "status-500")
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    validator = AccessJwtValidator()
    token = _access(jwks_server, iss=key_server.base_url)
    rotated = mint(access_claims(iss=key_server.base_url), jwks_server.access_key, "rotated-kid")

    def fetches(candidate: str) -> int:
        """candidate 판정 한 번의 키 서버 GET 수 — 판정은 키를 얻지 못해 AuthKeysUnavailable이어야 한다."""
        before = key_server.hits[CERTS_PATH]
        with pytest.raises(AuthKeysUnavailable):
            validator.validate(candidate)
        return key_server.hits[CERTS_PATH] - before

    assert fetches(token) == 1  # 빈 캐시 · 첫 실패 → 창 1 s
    observed: list[tuple[int, int]] = []
    for window in BACKOFF_WINDOWS_S:
        clock.advance(window - BACKOFF_PROBE_S)
        inside = fetches(token)
        clock.advance(2 * BACKOFF_PROBE_S)
        observed.append((inside, fetches(token)))
    assert observed == [(0, 1)] * len(BACKOFF_WINDOWS_S)
    key_server.set_mode(CERTS_PATH, "ok")
    clock.advance(BACKOFF_WINDOWS_S[-1] + BACKOFF_PROBE_S)
    assert validator.validate(token)["iss"] == key_server.base_url  # 창 밖 · fetch 성공 → 창 초기화
    key_server.set_mode(CERTS_PATH, "status-500")
    clock.advance(31)  # 마지막 성공 fetch 뒤 PyJWT cooldown(30 s) 밖 → 모르는 kid는 한 번 다시 가져온다
    assert fetches(rotated) == 1  # 재조회 실패 → 창 1 s(초기화됐으므로 30 s가 아니다)
    clock.advance(1 - BACKOFF_PROBE_S)
    assert fetches(rotated) == 0  # 창 안 — 모르는 kid 재조회도 네트워크 없이 503
    clock.advance(2 * BACKOFF_PROBE_S)
    assert fetches(rotated) == 1
    assert key_server.hits[CERTS_PATH] == 1 + len(BACKOFF_WINDOWS_S) + 1 + 2
    assert _error_words(caplog).count("backoff") == len(BACKOFF_WINDOWS_S) + 1


def test_ac_24_cached_keys_pass_inside_backoff_window(
    make_client: Callable[[], Client],
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24c — 백오프 창은 fetch만 막는다(T070 r3 U4): 유효 캐시 + cooldown이 지난 모르는 kid 재조회 실패(Access certs HTTP
    500 → 503 · 창 1 s) → 창 안에서도 캐시의 아는 kid는 200(fetch 0 — 캐시로 통과하는 판정은 영향이 없다) · 모르는 kid는
    네트워크 없이 503(error=backoff) → 창 밖에서는 모르는 kid가 다시 가져온다(fetch +1)."""
    clock = install_shifted_clock(monkeypatch)
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    client = make_client()
    bearer = _bearer(jwks_server)
    known = _headers(bearer=bearer, access=_access(jwks_server, iss=key_server.base_url))
    rotated = _headers(
        bearer=bearer, access=mint(access_claims(iss=key_server.base_url), jwks_server.access_key, "rotated-kid")
    )
    assert client.get(PROTECTED, headers=known).status_code == 200
    assert key_server.hits[CERTS_PATH] == 1
    key_server.set_mode(CERTS_PATH, "status-500")
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    clock.advance(31)
    assert_problem(client.get(PROTECTED, headers=rotated), 503, "auth_keys_unavailable")
    assert key_server.hits[CERTS_PATH] == 2
    assert client.get(PROTECTED, headers=known).status_code == 200
    assert_problem(client.get(PROTECTED, headers=rotated), 503, "auth_keys_unavailable")
    assert key_server.hits[CERTS_PATH] == 2
    clock.advance(1 + BACKOFF_PROBE_S)
    assert_problem(client.get(PROTECTED, headers=rotated), 503, "auth_keys_unavailable")
    assert key_server.hits[CERTS_PATH] == 3
    assert _error_words(caplog) == ["PyJWKClientConnectionError", "backoff", "PyJWKClientConnectionError"]


@pytest.mark.parametrize("initial_window_s", [None, 0.3], ids=["default-window", "window-shorter-than-fetch"])
def test_ac_24_concurrent_requests_wait_for_one_failed_fetch(
    initial_window_s: float | None,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24d — 빈 캐시 장애에서 동시 요청이 계단 없이 끝난다(T070 r3 U4 · r2 리뷰 B-1 재현): 검증기 하나에 동시 5건 · fetch는
    메모리 안 0.4 s 실패 대역 → fetch 1번 · 다섯 판정 모두 0.8 s 안에 AuthKeysUnavailable(백오프가 없으면 잠금 안에서 fetch를
    하나씩 되풀이해 0.4 · 0.8 · … · 2.0 s · fetch 5) · WARNING error = 원 예외 1 + backoff 4. 창이 fetch 시간보다 짧아도(0.3 s
    — 모듈 상수는 호출 때 읽는다) 같다 — 창은 실패를 안 시각부터 센다(fetch 시작부터 세면 기다리던 판정이 창 밖에서 다시
    가져온다). 실제 대기는 사례마다 0.4 s다."""
    if initial_window_s is not None:
        monkeypatch.setattr(auth, "_KEYS_BACKOFF_INITIAL_S", initial_window_s)
    calls: list[str] = []

    def failing_fetch(client: jwt.PyJWKClient) -> dict[str, Any]:
        calls.append(client.uri)
        time.sleep(SLOW_FETCH_S)
        raise jwt.PyJWKClientConnectionError(SENTINEL)

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", failing_fetch)
    settings.ACCESS_TEAM_DOMAIN = f"http://127.0.0.1:{closed_port()}"
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    validator = AccessJwtValidator()
    token = _access(jwks_server)
    barrier = threading.Barrier(CONCURRENT_REQUESTS)
    outcomes: list[tuple[str, float]] = []
    guard = threading.Lock()

    def run() -> None:
        barrier.wait(timeout=HANG_LIMIT_S)
        started = time.perf_counter()
        try:
            validator.validate(token)
            outcome = "accepted"
        except Exception as exc:  # noqa: BLE001 — 스레드 경계: 결과 이름만 모은다
            outcome = type(exc).__name__
        with guard:
            outcomes.append((outcome, time.perf_counter() - started))

    workers = [threading.Thread(target=run, name=f"ac24d-{index}", daemon=True) for index in range(CONCURRENT_REQUESTS)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join(HANG_LIMIT_S)
    assert [worker.is_alive() for worker in workers] == [False] * CONCURRENT_REQUESTS
    assert len(calls) == 1
    assert sorted(outcome for outcome, _ in outcomes) == ["AuthKeysUnavailable"] * CONCURRENT_REQUESTS
    slowest = max(elapsed for _, elapsed in outcomes)
    assert slowest < 2 * SLOW_FETCH_S, f"가장 늦은 판정 {slowest:.3f} s"
    assert sorted(_error_words(caplog)) == sorted(["PyJWKClientConnectionError"] + ["backoff"] * 4)


def test_ac_24_backoff_does_not_need_pyjwt_client_lock(
    make_client: Callable[[], Client],
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24e — 백오프 상태는 _KeyClient 자기 잠금이 지킨다(T070 r4 V4 — PyJWT 비공개 `_client_lock`에 기대지 않는다): 그
    속성이 없는 부모(모의 — 2.15.1에서 잠금만 뺀 get_signing_key · __init__ 뒤 속성 삭제)에서도 빈 캐시 + fetch 실패 → 첫 판정
    503(fetch 1 · error = 원 예외 클래스) → 창 안의 다음 판정은 fetch 0 · 503 error=backoff다(AttributeError가 아니다 — 그
    속성을 쥐는 fetch_data는 모든 판정이 AttributeError 503이고 창이 열리지 않는다) · 응답 · 로그에 감시 문자열 없음."""
    created = install_lockless_parent(monkeypatch)
    calls: list[str] = []

    def failing_fetch(client: jwt.PyJWKClient) -> dict[str, Any]:
        calls.append(client.uri)
        raise jwt.PyJWKClientConnectionError(SENTINEL)

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", failing_fetch)
    settings.ACCESS_TEAM_DOMAIN = f"http://127.0.0.1:{closed_port()}"
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    client = make_client()
    headers = _valid_headers(jwks_server)
    for attempt in range(2):
        response = client.get(PROTECTED, headers=headers)
        assert_problem(response, 503, "auth_keys_unavailable")
        assert len(calls) == 1, attempt
        _assert_absent(_response_text(response), SENTINEL)
    assert [hasattr(key_client, "_client_lock") for key_client in created] == [False]
    assert _error_words(caplog) == ["PyJWKClientConnectionError", "backoff"]
    _assert_absent(caplog.text, SENTINEL)


def test_ac_24_backoff_lock_never_reenters_pyjwt_lock(
    jwks_server: JwksInfo, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ac-24f — 자기 잠금은 PyJWT 잠금의 종류와 무관하다(T070 r4 V4): 클라이언트 잠금이 재진입 불가 threading.Lock인 부모(모의 —
    get_signing_key는 2.15.1 그대로라 그 잠금을 쥔 채 fetch_data를 부른다)에서도 판정이 멈추지 않고 끝난다(빈 캐시 → fetch 1 →
    통과). 판정은 데몬 스레드에서 돌리고 LOCK_HANG_LIMIT_S 뒤 살아 있지 않아야 한다 — fetch_data가 `_client_lock`을 다시 쥐면 같은
    스레드가 자기가 쥔 잠금을 기다려 영원히 멈춘다(리뷰 r3 B-2 제안 (a)의 위험). 끝난 뒤 그 잠금은 풀려 있다."""
    created = install_plain_lock_parent(monkeypatch)
    fetched = _intercept_key_fetch(monkeypatch, jwks_server)
    base = f"http://127.0.0.1:{closed_port()}"
    settings.ACCESS_TEAM_DOMAIN = base
    validator = AccessJwtValidator()
    token = _access(jwks_server, iss=base)
    outcome: list[object] = []

    def run() -> None:
        try:
            outcome.append(validator.validate(token)["iss"])
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 결과 이름만 모은다
            outcome.append(type(exc).__name__)

    worker = threading.Thread(target=run, name="ac24f", daemon=True)
    worker.start()
    worker.join(LOCK_HANG_LIMIT_S)
    assert worker.is_alive() is False, f"판정이 {LOCK_HANG_LIMIT_S} s 안에 끝나지 않았다(잠금 재진입 교착)"
    assert outcome == [base]
    assert fetched == [base + CERTS_PATH]
    assert [type(key_client._client_lock) for key_client in created] == [type(threading.Lock())]
    assert [key_client._client_lock.locked() for key_client in created] == [False]


def test_ac_24_own_lock_serializes_fetch_without_pyjwt_lock(
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24g — 자기 잠금이 fetch를 직렬화한다(T070 r4 V4): ac-24e의 잠금 없는 부모 + 빈 캐시 + 실패하는 fetch(LOCK_FETCH_S 뒤
    실패 — 메모리 안) + 동시 5건(Barrier로 함께 출발) → fetch 1 · 다섯 판정 모두 AuthKeysUnavailable(원 예외 1 + backoff 4).
    자기 잠금이 없으면 다섯이 함께 fetch하고(fetch 5) · `_client_lock`을 쥐려 하면 AttributeError로 fetch 0이다. 실제 대기는
    LOCK_FETCH_S 한 번이다."""
    created = install_lockless_parent(monkeypatch)
    calls: list[str] = []

    def failing_fetch(client: jwt.PyJWKClient) -> dict[str, Any]:
        calls.append(client.uri)
        time.sleep(LOCK_FETCH_S)
        raise jwt.PyJWKClientConnectionError(SENTINEL)

    monkeypatch.setattr(jwt.PyJWKClient, "fetch_data", failing_fetch)
    settings.ACCESS_TEAM_DOMAIN = f"http://127.0.0.1:{closed_port()}"
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    validator = AccessJwtValidator()
    token = _access(jwks_server)
    barrier = threading.Barrier(CONCURRENT_REQUESTS)
    outcomes: list[str] = []
    guard = threading.Lock()

    def run() -> None:
        barrier.wait(timeout=HANG_LIMIT_S)
        try:
            validator.validate(token)
            outcome = "accepted"
        except Exception as exc:  # noqa: BLE001 — 스레드 경계: 결과 이름만 모은다
            outcome = type(exc).__name__
        with guard:
            outcomes.append(outcome)

    workers = [threading.Thread(target=run, name=f"ac24g-{index}", daemon=True) for index in range(CONCURRENT_REQUESTS)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join(HANG_LIMIT_S)
    assert [worker.is_alive() for worker in workers] == [False] * CONCURRENT_REQUESTS
    assert len(calls) == 1
    assert outcomes == ["AuthKeysUnavailable"] * CONCURRENT_REQUESTS
    assert [hasattr(key_client, "_client_lock") for key_client in created] == [False]
    assert sorted(_error_words(caplog)) == sorted(["PyJWKClientConnectionError"] + ["backoff"] * 4)


def test_ac_24_concurrent_empty_cache_shares_one_successful_fetch(
    key_server: KeyServer,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-24h — 빈 캐시에 몰린 동시 판정은 느린 성공 fetch 한 번을 함께 쓴다(T070 r5 W3 — 중복 제거는 PyJWT 잠금 몫이다): 실제
    PyJWT 2.15.1 부모(모의 부모를 쓰지 않는다 — 실제 fetch_data가 urllib로 루프백 키 서버에서 받아 키 집합 캐시를 채운다) · 키
    서버는 certs 응답 전에 SLOW_SUCCESS_FETCH_S(0.3 s)를 기다린다(유효한 서명 키 집합 · GET 수는 서버가 센다) · 검증기 하나에 동시
    5건(Barrier로 함께 출발) → 키 서버 GET 1 · 다섯 판정 모두 통과(iss = 팀 기준 URL) · 가장 늦은 판정 < 2 × fetch 시간 · 스레드가
    모두 HANG_LIMIT_S 안에 끝난다 · django_common.auth 기록 0. 2.15.1 get_signing_key는 PyJWT 잠금 안에서 캐시를 확인하므로 기다리던
    판정은 잠금을 얻은 뒤 캐시로 통과한다. _KeyClient 자기 잠금은 fetch를 직렬화할 뿐 중복을 없애지 않는다 — PyJWT 잠금이 없으면
    기다리던 판정은 이미 캐시 확인을 지났으므로 자기 잠금을 얻은 뒤 다시 가져와 fetch 5 · 0.3 … 1.5 s 계단이 된다(잠금 없는 모의
    부모로 판별력을 확인했다 — 의존성 결합의 탐침이라 시험으로 남기지 않는다). 이 시험이 실패하면 PyJWT가 중복 제거를 그만둔
    것이다 — 자기 상태로 중복을 없애는 안(build-notes 「T070 r4 결과 · r5 결정」 W3의 고르지 않은 안 (a))을 다시 정한다. 실제
    대기는 키 서버의 0.3 s 한 번이다."""
    settings.ACCESS_TEAM_DOMAIN = key_server.base_url
    key_server.set_delay(CERTS_PATH, SLOW_SUCCESS_FETCH_S)
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    validator = AccessJwtValidator()
    token = _access(jwks_server, iss=key_server.base_url)
    barrier = threading.Barrier(CONCURRENT_REQUESTS)
    outcomes: list[tuple[str, float]] = []
    guard = threading.Lock()

    def run() -> None:
        barrier.wait(timeout=HANG_LIMIT_S)
        started = time.perf_counter()
        try:
            outcome = "accepted" if validator.validate(token)["iss"] == key_server.base_url else "other-iss"
        except Exception as exc:  # noqa: BLE001 — 스레드 경계: 결과 이름만 모은다
            outcome = type(exc).__name__
        with guard:
            outcomes.append((outcome, time.perf_counter() - started))

    workers = [threading.Thread(target=run, name=f"ac24h-{index}", daemon=True) for index in range(CONCURRENT_REQUESTS)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join(HANG_LIMIT_S)
    assert [worker.is_alive() for worker in workers] == [False] * CONCURRENT_REQUESTS
    timings = sorted(round(elapsed, 3) for _, elapsed in outcomes)
    assert key_server.hits[CERTS_PATH] == 1, f"fetch {key_server.hits[CERTS_PATH]}번 · 판정 경과(초) {timings}"
    assert sorted(outcome for outcome, _ in outcomes) == ["accepted"] * CONCURRENT_REQUESTS
    assert timings[-1] < 2 * SLOW_SUCCESS_FETCH_S, f"가장 늦은 판정 {timings[-1]:.3f} s · 판정 경과(초) {timings}"
    assert _auth_records(caplog) == []


# --- 거부 목록(D7) ------------------------------------------------------------------------------------------------------


@pytest.mark.parametrize("value", ["abc", "1.5", "", "0x10", "9" * 5000], ids=["word", "float", "empty", "hex", "huge"])
def test_ac_12_non_integer_denylist_value_is_503(
    value: str,
    auth_client: Client,
    writer: redis.Redis,
    jwks_server: JwksInfo,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-12a — revoked:sub 값이 정수가 아니면(int() 실패 — 단어 · 실수 · 빈 값 · 0x · 4300자리 초과) 조회 실패다(D7):
    503 denylist_unavailable(200 · 401로 접지 않는다) · error 관측 +1 · WARNING 한 줄(error=ValueError)."""
    writer.set(f"revoked:sub:{BEARER_SUB}", value, ex=DENYLIST_TTL_S)
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    before = _lookup_count("error")
    response = auth_client.get(PROTECTED, headers=_valid_headers(jwks_server))
    assert_problem(response, 503, "denylist_unavailable")
    assert _lookup_count("error") == before + 1
    _assert_warning_lines(caplog, "auth.denylist_unavailable source=denylist")
    assert [record.getMessage().split(" error=")[1] for record in _auth_records(caplog)] == ["ValueError"]


def test_ac_12_dragonfly_url_with_query_is_refused(
    make_client: Callable[[], Client],
    dragonfly: DragonflyInfo,
    df_admin: redis.Redis,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-12b — DRAGONFLY_URL에 쿼리가 있으면 조회하지 않고 503 denylist_unavailable이다(D7 · 사실 ④ — redis-py는 URL
    쿼리를 키워드 인자보다 우선해 0.2 s 시간 초과 · 재시도 0을 덮어쓴다): `?socket_timeout=5` · 감시 문자열 쿼리 둘 다 ·
    Dragonfly 새 연결 0 · 응답 · 로그에 URL · 비밀번호 · 감시 문자열 없음 · WARNING 줄마다 error=url_query · error 관측 +2."""
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    headers = _valid_headers(jwks_server)
    before_errors = _lookup_count("error")
    before_connections = connections_received(df_admin)
    urls = [Secret(f"{dragonfly.reader_url}?{query}") for query in ("socket_timeout=5", f"client_name={SENTINEL}")]
    for index, url in enumerate(urls):
        settings.DRAGONFLY_URL = url
        response = make_client().get(PROTECTED, headers=headers)
        assert response.status_code == 503, index
        assert_problem(response, 503, "denylist_unavailable")
        _assert_absent(_response_text(response), url, _password(dragonfly.reader_url), SENTINEL)
    assert connections_received(df_admin) - before_connections == 0
    assert _lookup_count("error") == before_errors + 2
    _assert_warning_lines(caplog, *["auth.denylist_unavailable source=denylist"] * 2)
    assert [record.getMessage().split(" error=")[1] for record in _auth_records(caplog)] == ["url_query"] * 2
    _assert_absent(caplog.text, *urls, _password(dragonfly.reader_url), SENTINEL)


def _command_calls(admin: redis.Redis) -> dict[str, int]:
    """Dragonfly INFO commandstats의 명령별 호출 수(이름 소문자)."""
    stats = admin.info("commandstats")
    calls: dict[str, int] = {}
    for name, value in stats.items():
        command = name.removeprefix("cmdstat_").lower()
        calls[command] = int(value["calls"]) if isinstance(value, dict) else 0
    return calls


def test_ac_13_denylist_public_api(
    writer: redis.Redis,
    df_admin: redis.Redis,
    dragonfly: DragonflyInfo,
    settings: SettingsWrapper,
    caplog: pytest.LogCaptureFixture,
) -> None:
    """ac-13 — Denylist 공개 API(D7 — T073 /session/check가 재사용): lookup(sub, sid=None) → DenylistRecord(원시 sub_nbf ·
    sid_revoked) · revokes(iat)(sub_nbf > iat 또는 sid_revoked — 같으면 폐기 아님) · sid가 없으면 sid 키를 보지 않는다
    (EXISTS 0 — 명령 통계) · 파이프라인 1회 = 비트랜잭션(MULTI · EXEC 0) · 결과 캐시 없음 · 생성은 연결하지 않는다 · 같은
    인스턴스가 바뀐 DRAGONFLY_URL을 따른다 · 조회 실패 = DenylistUnavailable(연쇄 없음 · 메시지 · 인자 · 응답 · 로그에 sub ·
    sid(감시 문자열) 없음 — NOPERM 메시지는 키를 싣는다 · 사실 ④) · 인자 검사(sub 비지 않은 str · sid None 또는 비지 않은 str)."""
    before = connections_received(df_admin)
    denylist = Denylist()
    assert connections_received(df_admin) - before == 0
    sub, sid = "ac13-sub", "ac13-sid"
    calls_before = _command_calls(df_admin)
    assert denylist.lookup(sub) == DenylistRecord(sub_nbf=None, sid_revoked=False)
    calls_after = _command_calls(df_admin)
    delta = {name: calls_after.get(name, 0) - calls_before.get(name, 0) for name in ("get", "exists", "multi", "exec")}
    assert delta == {"get": 1, "exists": 0, "multi": 0, "exec": 0}
    writer.set(f"revoked:sub:{sub}", 1730000000, ex=DENYLIST_TTL_S)
    record = denylist.lookup(sub)
    assert record == DenylistRecord(sub_nbf=1730000000, sid_revoked=False)
    assert (record.revokes(1729999999), record.revokes(1730000000), record.revokes(1730000001)) == (True, False, False)
    writer.set(f"revoked:sid:{sid}", 1, ex=DENYLIST_TTL_S)
    calls_before = _command_calls(df_admin)
    assert denylist.lookup(sub, sid) == DenylistRecord(sub_nbf=1730000000, sid_revoked=True)
    calls_after = _command_calls(df_admin)
    delta = {name: calls_after.get(name, 0) - calls_before.get(name, 0) for name in ("get", "exists", "multi", "exec")}
    assert delta == {"get": 1, "exists": 1, "multi": 0, "exec": 0}
    assert DenylistRecord(sub_nbf=None, sid_revoked=True).revokes(1730000000) is True
    assert DenylistRecord(sub_nbf=1730000000, sid_revoked=True).revokes(1730000001) is True
    assert denylist.lookup(sub, "other-sid").sid_revoked is False
    writer.delete(f"revoked:sub:{sub}")
    assert denylist.lookup(sub).sub_nbf is None
    settings.DRAGONFLY_URL = _unreachable_url(closed_port())
    with pytest.raises(DenylistUnavailable) as excinfo:
        denylist.lookup(sub)
    _assert_no_chain(excinfo.value)
    settings.DRAGONFLY_URL = dragonfly.reader_url
    assert denylist.lookup(sub) == DenylistRecord(sub_nbf=None, sid_revoked=False)
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    caplog.clear()  # 앞의 닫힌 포트 조회가 남긴 WARNING(기대한 것)은 여기서 비운다 — 아래 NOPERM 한 줄만 본다
    settings.DRAGONFLY_URL = dragonfly.noperm_url
    with pytest.raises(DenylistUnavailable) as excinfo:
        denylist.lookup(f"{SENTINEL}-sub", f"{SENTINEL}-sid")
    error = excinfo.value
    _assert_no_chain(error)
    _assert_absent(f"{error}\n{error.args!r}\n{_response_text(error.to_response())}", SENTINEL)
    _assert_warning_lines(caplog, "auth.denylist_unavailable source=denylist")
    _assert_absent(caplog.text, SENTINEL, dragonfly.noperm_url, _password(dragonfly.noperm_url))
    invalid_arguments: dict[str, tuple[type[Exception], tuple[object, ...]]] = {
        "empty-sub": (ValueError, ("",)),
        "int-sub": (TypeError, (1,)),
        "empty-sid": (ValueError, ("x", "")),
        "int-sid": (TypeError, ("x", 1)),
    }
    accepted: list[str] = []
    for case, (error_type, arguments) in invalid_arguments.items():
        try:
            denylist.lookup(*arguments)  # type: ignore[arg-type]
        except error_type:
            continue
        accepted.append(case)
    assert accepted == []


def test_ac_13_old_sub_key_with_revoked_sid_is_revoked(
    auth_client: Client, writer: redis.Redis, jwks_server: JwksInfo
) -> None:
    """ac-13b — 거부 판정 조합(D7 · T070 r2 N1 — revokes = sub_nbf > iat 또는 sid_revoked): 전체 로그아웃 → 재로그인 → 단일
    기기 로그아웃 순서에서는 330 s 동안 두 키가 같이 있다. 같은 토큰의 revoked:sub:{sub} = iat − 60(재로그인 뒤 토큰이라 sub
    키로는 폐기 아님 — 대조: 그 키만 있으면 200) + revoked:sid:{sid} → 401 session_revoked(sub 키가 있다고 sid를 보지 않으면
    200이 된다 — 미들웨어 · T073 /session/check 둘 다)."""
    iat = int(time.time())
    headers = _headers(bearer=_bearer(jwks_server, iat=iat), access=_access(jwks_server))
    writer.set(f"revoked:sub:{BEARER_SUB}", iat - 60, ex=DENYLIST_TTL_S)
    assert auth_client.get(PROTECTED, headers=headers).status_code == 200
    writer.set(f"revoked:sid:{BEARER_SID}", 1, ex=DENYLIST_TTL_S)
    assert_problem(auth_client.get(PROTECTED, headers=headers), 401, "session_revoked")


def test_ac_13_client_is_reused_per_url(
    df_admin: redis.Redis, dragonfly: DragonflyInfo, settings: SettingsWrapper
) -> None:
    """ac-13c — Denylist는 URL별 클라이언트(연결 풀)를 인스턴스 안에 두고 재사용한다(D7 · T070 r2 N4 ② — 조회마다 from_url이면
    연결 풀 · TCP · AUTH 왕복이 조회마다 붙는다): 같은 인스턴스로 3번 조회 → Dragonfly 새 연결 1 · 다른 URL(writer)은 그
    URL의 새 연결 1 · 처음 URL로 돌아오면 새 연결 0(INFO stats total_connections_received 차이)."""
    denylist = Denylist()
    before = connections_received(df_admin)
    for _ in range(3):
        assert denylist.lookup("ac13c-sub", "ac13c-sid") == DenylistRecord(sub_nbf=None, sid_revoked=False)
    assert connections_received(df_admin) - before == 1
    settings.DRAGONFLY_URL = dragonfly.writer_url
    assert denylist.lookup("ac13c-sub").sub_nbf is None
    assert connections_received(df_admin) - before == 2
    settings.DRAGONFLY_URL = dragonfly.reader_url
    assert denylist.lookup("ac13c-sub").sub_nbf is None
    assert connections_received(df_admin) - before == 2


def test_ac_14_lookup_metric_labels(
    writer: redis.Redis,
    make_client: Callable[[], Client],
    dragonfly: DragonflyInfo,
    jwks_server: JwksInfo,
    settings: SettingsWrapper,
) -> None:
    """ac-14 — 지표 denylist_lookup_seconds{result}(D7 — 조회 1회 = 관측 1회): ok(키 없음) · revoked(폐기 키가 있었다 — sub
    키 또는 sid 키 · 요청 거부 여부는 호출자의 revokes(iat)가 판정한다 — 오래된 sub 키도 revoked) · error(조회 실패).
    Denylist 직접 3회 · 미들웨어 경유(200 → ok · revoked:sid 401 → revoked)."""
    labels = ("ok", "revoked", "error")
    before = {label: _lookup_count(label) for label in labels}
    denylist = Denylist()
    denylist.lookup("ac14-none")
    writer.set("revoked:sub:ac14-old", 100, ex=DENYLIST_TTL_S)
    assert denylist.lookup("ac14-old").revokes(int(time.time())) is False
    settings.DRAGONFLY_URL = _unreachable_url(closed_port())
    with pytest.raises(DenylistUnavailable):
        denylist.lookup("ac14-none")
    assert {label: _lookup_count(label) - before[label] for label in labels} == {"ok": 1, "revoked": 1, "error": 1}
    settings.DRAGONFLY_URL = dragonfly.reader_url
    client = make_client()
    before = {label: _lookup_count(label) for label in labels}
    assert client.get(PROTECTED, headers=_valid_headers(jwks_server)).status_code == 200
    writer.set("revoked:sid:sid-1", 1, ex=DENYLIST_TTL_S)
    assert_problem(client.get(PROTECTED, headers=_valid_headers(jwks_server)), 401, "session_revoked")
    assert {label: _lookup_count(label) - before[label] for label in labels} == {"ok": 1, "revoked": 1, "error": 0}


# --- 웹훅(D9) ----------------------------------------------------------------------------------------------------------


def test_ac_15_webhook_helper_edges() -> None:
    """ac-15 — verify_authentik_webhook 가장자리(D9 — T062 auth-23..26 · 29가 고정하지 않은 것): 빈 비밀 = ValueError(설정
    오류 — 서명이 맞아도) · str 아닌 비밀 = TypeError · bytes 아닌 body(int · list · memoryview · bytearray · str — r3 U1) =
    TypeError · 대문자 hex 서명(같은 다이제스트) 거부(계약 = 소문자) · str 아닌 서명 거부 · `Z` 접미 created 수락 · |now −
    created| 경계(정확히 300 s 수락 · 300 s + 1 µs 거부 · 양쪽) · 깊은 중첩 본문(RecursionError) · 비UTF-8 · UTF-16
    본문(json.loads(bytes)는 받지만 계약은 UTF-8 — 서명이 맞아도 거부) · UTF-8 BOM · naive now = ValueError · 거부 예외의 메시지 ·
    인자 · 응답에 비밀 · 본문 값(감시 문자열) 없음 · 연쇄 없음 · 반환 created는 aware · data는 본문 dict 전체."""
    secret = Secret(f"{SENTINEL}-hmac")
    now = datetime(2026, 11, 5, 3, 0, 0, tzinfo=UTC)

    def body_of(created: str) -> bytes:
        return json.dumps(webhook_body(created=created, sub=f"{SENTINEL}-user")).encode()

    body = body_of(now.isoformat())
    signature = sign_webhook(body, secret)
    event = verify_authentik_webhook(body, signature, secret=secret, now=now)
    assert isinstance(event, WebhookEvent)
    assert (event.created, event.created.utcoffset()) == (now, timedelta(0))
    assert event.data == json.loads(body)

    for empty in ("", Secret("")):
        with pytest.raises(ValueError):
            verify_authentik_webhook(body, signature, secret=empty, now=now)
    with pytest.raises(TypeError):
        verify_authentik_webhook(body, signature, secret=secret.encode(), now=now)  # type: ignore[arg-type]
    with pytest.raises(ValueError):
        verify_authentik_webhook(body, signature, secret=secret, now=now.replace(tzinfo=None))
    # r3 U1 — body는 bytes만: 같은 바이트를 담은 bytearray · memoryview · str도(서명이 맞아도) TypeError · int · list도 TypeError
    # (WebhookSignatureInvalid 401로 접히거나 받아들여지면 실패 — 메시지에 본문 값(감시 문자열) 없음).
    non_bytes_bodies: dict[str, object] = {
        "int": 5,
        "list": [123],
        "memoryview": memoryview(body),
        "bytearray": bytearray(body),
        "str": body.decode("utf-8"),
    }
    not_type_error: list[str] = []
    for case, candidate in non_bytes_bodies.items():
        try:
            verify_authentik_webhook(candidate, signature, secret=secret, now=now)  # type: ignore[arg-type]
        except TypeError as error:
            _assert_absent(f"{error}\n{error.args!r}", SENTINEL)
            continue
        except Exception:  # noqa: BLE001, S110 — TypeError가 아닌 모든 결과(401 · 다른 예외)를 실패로 모은다
            pass
        not_type_error.append(case)
    assert not_type_error == []

    z_body = body_of(now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    assert verify_authentik_webhook(z_body, sign_webhook(z_body, secret), secret=secret, now=now).created == now

    window = timedelta(seconds=300)
    tick = timedelta(microseconds=1)
    for offset, accepted in ((window, True), (-window, True), (window + tick, False), (-(window + tick), False)):
        edge = body_of((now + offset).isoformat())
        edge_signature = sign_webhook(edge, secret)
        if accepted:
            assert verify_authentik_webhook(edge, edge_signature, secret=secret, now=now).pk, str(offset)
        else:
            with pytest.raises(WebhookSignatureInvalid):
                verify_authentik_webhook(edge, edge_signature, secret=secret, now=now)

    upper = "sha256=" + signature.removeprefix("sha256=").upper()
    utf16 = json.dumps(json.loads(body)).encode("utf-16")
    bom = b"\xef\xbb\xbf" + body
    deep = (
        b'{"pk":"deep","created":"' + now.isoformat().encode() + b'","nested":' + b"[" * 200_000 + b"]" * 200_000 + b"}"
    )
    rejected: dict[str, tuple[bytes, object]] = {
        "upper-hex": (body, upper),
        "bytes-signature": (body, signature.encode()),
        "utf16": (utf16, sign_webhook(utf16, secret)),
        "utf8-bom": (bom, sign_webhook(bom, secret)),
        "non-utf8": (b'{"pk":"\xff","created":"' + now.isoformat().encode() + b'"}', "sha256=" + "0" * 64),
        "deep-nesting": (deep, "sha256=" + "0" * 64),
    }
    assert upper != signature
    accepted: list[str] = []
    for case, (candidate, candidate_signature) in rejected.items():
        try:
            verify_authentik_webhook(candidate, candidate_signature, secret=secret, now=now)  # type: ignore[arg-type]
        except WebhookSignatureInvalid as error:
            _assert_no_chain(error)
            _assert_absent(f"{error}\n{error.args!r}\n{_response_text(error.to_response())}", SENTINEL)
            continue
        accepted.append(case)
    assert accepted == []


# --- import · 생성 부작용(D11) · 로그(D12) ----------------------------------------------------------------------------------


def test_ac_16_import_and_construction_have_no_side_effects() -> None:
    """ac-16 — import · 생성 부작용 0(D11 · auth-21): 새 프로세스(시험 설정)에서 django.setup() 뒤 django_common.auth를
    import하고 JwtAuthMiddleware · AccessJwtValidator · Denylist를 만들어도(키 URL · DRAGONFLY_URL은 127.0.0.1 닫힌 포트)
    소켓 연결 · 이름 조회 · 스레드 시작이 0이다(키 fetch · Redis 연결은 첫 판정 때 · import는 지표 등록만 한다) · 미들웨어는
    sync 전용. 자식 출력은 JSON 한 줄(정수 · 불린 · 예외 클래스 이름)뿐이다."""
    script = (
        "import json, socket, threading\n"
        "counts = {'connect': 0, 'lookup': 0, 'thread_start': 0}\n"
        "def counting(name, real):\n"
        "    def wrapper(*args, **kwargs):\n"
        "        counts[name] += 1\n"
        "        return real(*args, **kwargs)\n"
        "    return wrapper\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from django.conf import settings\n"
        "    settings.AUTHENTIK_JWKS_URL = 'http://127.0.0.1:9/application/o/identity-admin/jwks/'\n"
        "    settings.ACCESS_TEAM_DOMAIN = 'http://127.0.0.1:9'\n"
        "    settings.DRAGONFLY_URL = 'redis://127.0.0.1:9/0'\n"
        "    socket.socket.connect = counting('connect', socket.socket.connect)\n"
        "    socket.socket.connect_ex = counting('connect', socket.socket.connect_ex)\n"
        "    socket.create_connection = counting('connect', socket.create_connection)\n"
        "    socket.getaddrinfo = counting('lookup', socket.getaddrinfo)\n"
        "    threading.Thread.start = counting('thread_start', threading.Thread.start)\n"
        "    threads_before = threading.active_count()\n"
        "    import django_common.auth as auth\n"
        "    middleware = auth.JwtAuthMiddleware(lambda request: None)\n"
        "    auth.AccessJwtValidator()\n"
        "    auth.Denylist()\n"
        "    result = dict(counts)\n"
        "    result['threads_delta'] = threading.active_count() - threads_before\n"
        "    result['sync'] = [middleware.sync_capable, middleware.async_capable]\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    )
    env = {key: value for key, value in os.environ.items() if key.upper() != "PROMETHEUS_MULTIPROC_DIR"}
    env["DJANGO_SETTINGS_MODULE"] = "tests.settings"
    completed = subprocess.run(  # noqa: S603 — 이 인터프리터 · 고정 스크립트
        [sys.executable, "-c", script],
        cwd=PACKAGE_ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    assert completed.returncode == 0, f"자식 프로세스 종료 코드 {completed.returncode}"
    result = json.loads(completed.stdout.strip().splitlines()[-1])
    assert result == {"connect": 0, "lookup": 0, "thread_start": 0, "threads_delta": 0, "sync": [True, False]}


def test_ac_20_decisions_are_not_logged(
    auth_client: Client, writer: redis.Redis, jwks_server: JwksInfo, caplog: pytest.LogCaptureFixture
) -> None:
    """ac-20 — 미들웨어는 판정마다 로그를 남기지 않는다(D12 — 요청 로그는 T071 RequestIdMiddleware가 상태 코드로 남긴다):
    200 · 403 · 401(만료) · 401(session_revoked) 동안 django_common.auth 기록 0(DEBUG 포함)."""
    caplog.set_level(logging.DEBUG, logger=LOGGER)
    now = int(time.time())
    access = _access(jwks_server)
    assert auth_client.get(PROTECTED, headers=_valid_headers(jwks_server)).status_code == 200
    assert auth_client.get(PROTECTED, headers=_headers(bearer=_bearer(jwks_server))).status_code == 403
    expired = _bearer(jwks_server, iat=now - 360, exp=now - 60)
    assert auth_client.get(PROTECTED, headers=_headers(bearer=expired, access=access)).status_code == 401
    writer.set("revoked:sid:sid-1", 1, ex=DENYLIST_TTL_S)
    assert auth_client.get(PROTECTED, headers=_valid_headers(jwks_server)).status_code == 401
    assert _auth_records(caplog) == []
