"""T073 ia 시험 공용 픽스처 · 도우미(조각 ① · 설계 D26 〔Y14〕) — tests/conftest.py의 `pytest_plugins`로 적재한다.

배선: 생성물 tests/conftest.py가 `pytest_plugins = ("tests._ia_support",)` 한 줄로 이 모듈을 플러그인으로 올리고
`register_assert_rewrite`에 이 모듈과 tests._ia_fakes를 더한다(손 수정 ⑩ — 표식 `# identity-admin(T073)`). star-import는 쓰지
않는다 — 세션 픽스처가 모듈마다 다시 만들어진다(A-14).

autouse 픽스처는 없다 — 플러그인의 autouse는 T066 · 템플릿 시험에도 걸린다(템플릿 conftest의 원칙). `ia73_env`가 필요한 ia
모듈은 머리에서 `pytestmark = pytest.mark.usefixtures("ia73_env")`로 고르고, 정적 · 기동 시험이 섞인 모듈
(`tests/test_identity_infra.py`)은 그 환경이 필요한 시험에만 `@pytest.mark.usefixtures("ia73_env")`를 단다. 이름 접두 `ia73_`은
T066 모듈 픽스처 `ia_*`와 겹치지 않게 한다.

픽스처
- `ia73_env`(함수): ① pod 설정 덮기 — T066 `ia_settings`와 같은 값이되 DRAGONFLY_URL = conftest **pod 사용자**
  (`dragonfly.pod_url` — 설계 D24: 그 사용자의 ACL이 운영 규칙이다) · Authentik = 확장 가짜(`ia73_authentik`) · OpenFGA =
  `ia73_openfga` · 웹훅 비밀 = `ia73_webhook_secret` · Kafka 닫힌 포트 · AUTHENTIK_WRITES_ENABLED 거짓(dev 꼴) ② 가짜 서버
  초기화(reset — 상태 · 요청 기록 · 모드 · 주입 · 시험 앞뒤로) ③ Dragonfly FLUSHALL(admin — 시험 앞뒤로) ④ 공개 DNS 가드(T066
  public_dns_guard) + 프록시 env 끄기 — 끝에 공개 이름 조회 기록 0을 단언한다(단언이 실패해도 ②③의 끝 정리는 돈다).
  pytest-django `settings`를 돌려준다(끝나면 되돌린다).
- `ia73_authentik`(세션 — tests._ia_fakes.FakeAuthentikExt) · `ia73_openfga`(세션 — T066 FakeOpenFga) ·
  `ia73_webhook_secret`(세션 — Secret) · `ia73_df_admin`(함수 — Dragonfly admin 클라이언트 · 끝에 닫는다).
- Dragonfly 사용자를 새로 만들지 않는다(`ACL SETUSER` 없음 — T066의 identity-admin-test 사용자와 무관하다).

도우미(뒤 조각의 ia 시험이 쓴다): 자격 헤더(Access · Bearer — tests._jwt를 다시 쓴다 · 값은 Secret) · 웹훅 본문 서명 ·
요청 보내기(예외는 원 트레이스백 없이 실패로) · 시간 상한 호출(timed — 데몬 스레드 · 유한한 실패) · 행 넣기(owner 별칭 ·
모델은 apps.get_models()에서 db_table로) · DB 시각 · Dragonfly 키 · TTL 읽기 · 키 이름(계약 문자열) · log_lines 기록에서
이벤트 이름으로 줄 고르기 · 구현 모듈 지연 import. 행 넣기는 `DB` 마크(transaction=True · default + owner)가 전제다.

구현 모듈(`identity_admin.revocation` · `denylist_writer` · `session_floor` · `jobs` · `outbound` · `authentik` · 모델)은 머리에서
import하지 않는다 — 쓰는 함수 안에서 `importlib.import_module`(impl) · `apps.get_models()`(model)로 가져온다. 구현이 없는 동안에도
수집이 성공하고, 빨강의 사유가 노드마다 「구현 없음」으로 드러난다. T066 모듈(tests/test_api.py)에서는 아무것도 import하지 않는다
(그 파일의 autouse 픽스처가 딸려 오지 않게) — 상수는 여기 자기 것으로 둔다(값은 T066과 같다).

단언 꼴(build-notes R0-2 · 규칙 §Tests): 응답 · 결과를 지역 변수에 묶은 뒤 단언한다. 자격 헤더 · 토큰 · 비밀 · env 매핑을 assert
식 안의 호출 인자로 두지 않는다.
"""

from __future__ import annotations

import importlib
import json
import secrets
import threading
import time
from collections.abc import Callable, Iterable, Iterator, Mapping
from datetime import datetime, timedelta
from types import ModuleType
from typing import TYPE_CHECKING, Any, NoReturn

import pytest
import redis

from tests._ia_fakes import FakeAuthentikExt
from tests._identity_fakes import FakeOpenFga, closed_port, public_dns_guard
from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    TENANT_ID,
    TOKEN_TTL_S,
    access_claims,
    bearer_claims,
    mint,
    sign_webhook,
    webhook_body,
)
from tests._secret import Secret

if TYPE_CHECKING:
    from django.http import HttpResponse
    from django.test import Client
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, JwksInfo

# --- 상수(값은 T066 tests/test_api.py와 같다 — 그 모듈에서 import하지 않는다) -----------------------------------------------------

SVC_HOST = "identity-admin.jt-dev.svc"  # 클러스터 내부(웹훅 · 프로브) — contracts/identity-admin-api.md §호스트
M2M_HOST = "identity-m2m-dev.joshuatech.dev"  # BFF 호출 호스트(dev)
ADMIN_HOST_VALUE = "admin.joshuatech.dev"
PUBLIC_ISSUER = "https://auth.joshuatech.dev/application/o/identity-admin/"  # Bearer iss(공개 URL — 문자열 비교만)
ACCESS_AUD_M2M = "aud-m2m-test"
ACCESS_AUD_ADMIN = "aud-admin-test"
ACCESS_EXPECTED_CN = "web-bff-test-client-id.access"  # 서비스 토큰 Client ID 자리의 가짜 값(비밀 아님)
AUTHENTIK_AUDIENCE = "identity-admin"
TENANT_A = TENANT_ID  # tests._jwt 테넌트 A(UUID 문자열)
TENANT_B = "00000000-0000-4000-8000-00000000000b"
DENYLIST_TTL_S = 330  # contracts/denylist.md §키 스키마(access TTL 300 s + 30 s)
CHECK_PATH = "/session/check"
REVOKE_PATH = "/sessions/revoke"
WEBHOOK_PATH = "/webhooks/authentik"
TENANTS_ME = "/tenants/me"
SIGNATURE_HEADER = "X-Authentik-Signature"
OWNER_ALIAS = "owner"  # 시험 DB의 owner role 별칭(tests/settings.py) — 행 넣기 · 관측 준비용
# DB에 닿는 ia 시험의 마크(T066 tests/test_api.py `DB`와 같은 값 — 설계 D26). transaction=True: owner 연결에 넣은 행이 커밋되어
# app role(default) 연결의 뷰 · 작업이 읽는다 · owner를 열어야 그 별칭도 시험 끝에 flush된다(행이 시험 사이에 새지 않게).
DB = pytest.mark.django_db(transaction=True, databases=["default", OWNER_ALIAS])
PROXY_ENV = ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")
# Dragonfly 키(계약 문자열 — contracts/denylist.md §키 스키마 · 규칙 django-pod.md §Dragonfly · 설계 D29 · D14).
FRESHNESS_KEY = "identity-admin:denylist:reapplied-at"


def sub_key(sub: str) -> str:
    """사용자 단위 거부 목록 키 `revoked:sub:{sub}`."""
    return f"revoked:sub:{sub}"


def sid_key(sid: str) -> str:
    """세션 단위 거부 목록 키 `revoked:sid:{sid}`."""
    return f"revoked:sid:{sid}"


def floor_key(sub: str) -> str:
    """세션 하한 키 `identity-admin:session-floor:{sub}`(D29)."""
    return f"identity-admin:session-floor:{sub}"


def sid_floor_key(sid: str) -> str:
    """세션 단위 하한 키 `identity-admin:sid-floor:{sid}`(UD-7a(ㄴ) — t086-design.md D15 T-c)."""
    return f"identity-admin:sid-floor:{sid}"


# --- 픽스처 --------------------------------------------------------------------------------------------------------------


@pytest.fixture(scope="session")
def ia73_authentik() -> Iterator[FakeAuthentikExt]:
    """확장 가짜 Authentik(세션 1회) — `ia73_env` 없이 쓰지 않는다(상태는 그 픽스처가 시험 앞뒤로 비운다)."""
    server = FakeAuthentikExt()
    try:
        yield server
    finally:
        server.close()


@pytest.fixture(scope="session")
def ia73_openfga() -> Iterator[FakeOpenFga]:
    """T066 가짜 OpenFGA(세션 1회) — `ia73_env` 없이 쓰지 않는다(상태는 그 픽스처가 시험 앞뒤로 비운다)."""
    server = FakeOpenFga()
    try:
        yield server
    finally:
        server.close()


@pytest.fixture(scope="session")
def ia73_webhook_secret() -> Secret:
    """웹훅 HMAC 공유 비밀(세션 랜덤 · 출력하지 않는다)."""
    return Secret(secrets.token_urlsafe(32))


@pytest.fixture
def ia73_df_admin(dragonfly: DragonflyInfo) -> Iterator[redis.Redis]:
    """Dragonfly admin 클라이언트(GET · TTL · SET · FLUSHALL — 시험 관측 · 준비용) · 끝에 닫는다."""
    client = redis.Redis.from_url(dragonfly.admin_url)
    try:
        yield client
    finally:
        client.close()


def _flushall(dragonfly: DragonflyInfo) -> None:
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        admin.flushall()
    finally:
        admin.close()


@pytest.fixture
def ia73_env(
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    jwks_server: JwksInfo,
    dragonfly: DragonflyInfo,
    ia73_webhook_secret: Secret,
    ia73_authentik: FakeAuthentikExt,
    ia73_openfga: FakeOpenFga,
) -> Iterator[SettingsWrapper]:
    """ia 시험 환경(모듈 독스트링 「픽스처」 ①–④) — pytest-django settings를 돌려준다. 끝에 공개 이름 조회 기록 0을 단언하고
    (위반은 teardown ERROR) 단언이 실패해도 가짜 둘 reset · Dragonfly FLUSHALL을 한 번 더 한다(뒤 시험에 모드 · 키가 새지 않게).

    함정: `NO_PROXY` · `no_proxy`를 `*`로 두므로 urllib 기본 opener도 프록시를 건너뛴다. ia-22의 「프록시 env를 둬도 직접
    간다」 사례는 그 둘을 지우고(`monkeypatch.delenv`) `HTTP_PROXY`를 원시 서버(RawHttpServer)로 둔다 — 같은 준비물에서
    `urllib.request.build_opener()`가 그 원시 서버를 지난다는 양성 대조(원시 서버 count 1)를 먼저 단언한다(부정 사례의 짝).
    """
    settings.AUTHENTIK_JWKS_URL = jwks_server.jwks_url
    settings.ACCESS_TEAM_DOMAIN = jwks_server.base_url
    settings.ACCESS_AUD_M2M = ACCESS_AUD_M2M
    settings.ACCESS_AUD_ADMIN = ACCESS_AUD_ADMIN
    settings.ACCESS_EXPECTED_CN = ACCESS_EXPECTED_CN
    settings.AUTHENTIK_ISSUER = PUBLIC_ISSUER
    settings.AUTHENTIK_AUDIENCE = AUTHENTIK_AUDIENCE
    settings.AUTH_ACTOR_SUB = ""
    settings.DRAGONFLY_URL = dragonfly.pod_url
    settings.AUTHENTIK_WEBHOOK_SECRET = ia73_webhook_secret
    settings.ALLOWED_HOSTS = [SVC_HOST, M2M_HOST, ADMIN_HOST_VALUE]
    settings.ADMIN_HOST = ADMIN_HOST_VALUE
    settings.AUTHENTIK_API_URL = ia73_authentik.base_url
    settings.AUTHENTIK_API_TOKEN = ia73_authentik.token
    settings.OPENFGA_API_URL = ia73_openfga.base_url
    settings.OPENFGA_STORE_ID = ia73_openfga.store_id
    settings.OPENFGA_PRESHARED_KEY = ia73_openfga.key
    settings.AUTHENTIK_WRITES_ENABLED = False
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{closed_port()}"
    ia73_authentik.reset()
    ia73_openfga.reset()
    _flushall(dragonfly)
    # 프록시 경유 요청은 이름 조회가 프록시 이름으로 바뀌어 DNS 가드 밖이다 — 끈다(T066 dns_guard와 같다 · urllib은 env 프록시
    # 사전이 비어 있지 않으면 Windows 레지스트리 프록시를 읽지 않는다 · 하위 프로세스는 이 env를 물려받는다).
    for name in PROXY_ENV:
        monkeypatch.delenv(name, raising=False)
    for name in ("NO_PROXY", "no_proxy"):
        monkeypatch.setenv(name, "*")
    with public_dns_guard() as attempts:
        yield settings
    try:
        ia73_openfga.fail_next_write = None
        looked_up = sorted(set(attempts))
        assert looked_up == [], f"공개 호스트 이름 조회 시도: {looked_up}"
    finally:
        # 끝 정리 — 세션 가짜의 모드 · 주입 · 요청 기록과 Dragonfly 키(revoked:* · 세션 하한)를 다음 시험에 남기지 않는다.
        ia73_authentik.reset()
        ia73_openfga.reset()
        _flushall(dragonfly)


# --- 도우미: 자격 헤더 · 요청 --------------------------------------------------------------------------------------------------


def access_token(jwks: JwksInfo, **overrides: Any) -> Secret:
    """Access 키로 서명한 Cf-Access-Jwt-Assertion 값(기본 = 유효 서비스 토큰 · aud M2M · common_name = 설정값)."""
    return Secret(mint(access_claims(**overrides), jwks.access_key, ACCESS_KID))


def bearer_token(
    jwks: JwksInfo,
    sub: str,
    tenant: str | None,
    *,
    sid: str | None = "sid-1",
    groups: Any = None,
    iat: int | None = None,
    **claims: Any,
) -> Secret:
    """Authentik 키로 서명한 Bearer 토큰(iss = 설정 AUTHENTIK_ISSUER · aud identity-admin). 값이 None인 클레임은 뺀다 · iat를
    주면 exp = iat + 300 s · claims는 그 밖의 클레임 덮기(tests._jwt.bearer_claims)."""
    values: dict[str, Any] = {"sub": sub, "tenant_id": tenant, "sid": sid, "groups": groups, **claims}
    if iat is not None:
        values.setdefault("iat", iat)
        values.setdefault("exp", iat + TOKEN_TTL_S)
    return Secret(mint(bearer_claims(**values), jwks.authentik_key, AUTHENTIK_KID))


def auth_headers(
    jwks: JwksInfo,
    host: str = M2M_HOST,
    *,
    access: bool | str = True,
    bearer: str | None = None,
    extra: Mapping[str, str] | None = None,
) -> dict[str, str]:
    """요청 헤더 — Host는 늘 명시한다(ia73_env가 ALLOWED_HOSTS를 덮어 testserver가 빠진다). access=True면 유효 Access를 만들고
    str이면 그 값을 쓴다 · bearer는 토큰(헤더 값 `Bearer <토큰>`). 자격 헤더 값은 Secret이다(dict repr에 값이 실리지 않는다)."""
    headers: dict[str, str] = {"host": host}
    if access is True:
        headers["Cf-Access-Jwt-Assertion"] = access_token(jwks)
    elif isinstance(access, str):
        headers["Cf-Access-Jwt-Assertion"] = Secret(access)
    if bearer is not None:
        headers["Authorization"] = Secret(f"Bearer {bearer}")
    if extra:
        headers.update(extra)
    return headers


def signed_webhook(secret: str, **overrides: Any) -> tuple[dict[str, Any], bytes, str]:
    """유효한 웹훅 본문 dict · 그 바이트 · 서명 `sha256=<hex>`(tests._jwt.webhook_body · sign_webhook — pk는 매번 새 uuid4 ·
    값이 None인 override는 그 키를 뺀다)."""
    data = webhook_body(**overrides)
    body = json.dumps(data).encode()
    return data, body, sign_webhook(body, secret)


def webhook_headers(signature: str | None) -> dict[str, str]:
    """웹훅 요청 헤더 — svc 호스트 · 자격 헤더 없음(면제 경로) · 서명(있으면)."""
    headers = {"host": SVC_HOST}
    if signature is not None:
        headers[SIGNATURE_HEADER] = signature
    return headers


def fail_without_trace(what: str, exc: BaseException) -> NoReturn:
    """예외를 원 트레이스백 · 메시지 없이 실패로 바꾼다(pytrace=False — T063 · T066 꼴). 호출자는 except 블록 밖에서 부른다
    (연쇄된 원 예외가 남지 않게) — psycopg conninfo · Dragonfly URL 같은 프레임 인자의 비밀이 실패 출력에 실리지 않게."""
    kind = f"{type(exc).__module__}.{type(exc).__name__}"
    if isinstance(exc, RuntimeError) and str(exc).startswith("Database access not allowed"):
        # pytest-django DB 차단기의 고정 문구(비밀 없음) — DB 마크가 없는 시험의 경로가 DB에 닿았다는 뜻이다.
        pytest.fail(f"{what}: DB 마크가 없는 경로가 DB에 닿았다(pytest-django 차단 · {kind})", pytrace=False)
    pytest.fail(f"{what}: 예외로 끝났다({kind}) - 원 트레이스백 · 메시지는 비밀 노출을 막으려고 싣지 않는다", pytrace=False)


def timed(fn: Callable[[], Any], limit_s: float) -> tuple[Any, float]:
    """fn()을 데몬 스레드에서 돌리고 (결과, 경과 초)를 준다 — limit_s 안에 끝나지 않으면 유한한 실패(pytest.fail)로 끝낸다
    (T066 tests/test_api.py `_timed`와 같은 꼴 · 그 모듈에서 가져오지 않는다 · limit_s는 부르는 쪽이 정한다).

    스레드 안의 DB 연결은 그 스레드 것이다(settings.DATABASES의 같은 dict로 새로 연다) — 끝에 connections.close_all()로
    자기 연결만 닫는다. 스레드 안의 예외는 원 트레이스백 없이 실패로 바꾼다(fail_without_trace — pytest 실패 자체는 그대로 다시
    던진다). 상한을 넘긴 스레드는 데몬으로 남는다(세션 범위 가짜를 계속 부를 수 있다 — 쪽 상한은 가짜의 천장이 끝낸다).
    """
    from django.db import connections

    outcome: list[Any] = []

    def run() -> None:
        try:
            outcome.append(fn())
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드로 넘긴다
            outcome.append(exc)
        finally:
            connections.close_all()

    worker = threading.Thread(target=run, name="ia73-timed", daemon=True)
    start = time.perf_counter()
    worker.start()
    worker.join(limit_s)
    elapsed = time.perf_counter() - start
    if worker.is_alive():
        pytest.fail(f"{limit_s:g} s 안에 끝나지 않았다 - 의존 조회 · 위임 · 쪽 매김에 상한이 없는 구현인가", pytrace=False)
    result = outcome[0]
    if isinstance(result, pytest.fail.Exception):
        raise result
    if isinstance(result, BaseException):
        fail_without_trace("시간 상한 호출", result)
    return result, elapsed


_NO_BODY = object()


def send(
    client: Client,
    method: str,
    path: str,
    headers: Mapping[str, str],
    body: Any = _NO_BODY,
    *,
    content_type: str = "application/json",
) -> HttpResponse:
    """시험 Client 요청 한 번 — body가 있으면 본문(dict · list는 JSON · str · bytes는 그대로)과 content_type을 싣는다. 예외(시험
    Client는 뷰 예외를 다시 던진다)는 원 트레이스백 없이 실패로 바꾼다."""
    kwargs: dict[str, Any] = {"headers": dict(headers)}
    if body is not _NO_BODY:
        kwargs["data"] = body if isinstance(body, str | bytes) else json.dumps(body)
        kwargs["content_type"] = content_type
    failure: BaseException | None = None
    try:
        response: HttpResponse = getattr(client, method.lower())(path, **kwargs)
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    if failure is not None:
        fail_without_trace(f"{method.upper()} {path.split('?')[0]}", failure)
    return response


def post_webhook(client: Client, body: bytes, signature: str | None) -> HttpResponse:
    """웹훅 POST(svc 호스트 · application/json · 서명 헤더는 있으면)."""
    return send(client, "post", WEBHOOK_PATH, webhook_headers(signature), body)


# --- 도우미: 모델 · 행 · DB 시각 ---------------------------------------------------------------------------------------------


def model(table: str) -> Any:
    """db_table이 table인 모델 — apps.get_models()에서 정확히 하나여야 한다(T066 _model과 같은 방식 · 모듈 경로 무관)."""
    from django.apps import apps

    found = [candidate for candidate in apps.get_models() if candidate._meta.db_table == table]
    assert len(found) == 1, f"db_table {table!r} 모델 수 {len(found)}"
    return found[0]


def rows(table: str, *, using: str = "default") -> list[Any]:
    """table의 행 전부(using 별칭)."""
    return list(model(table).objects.using(using).all())


def insert_row(table: str, **fields: Any) -> Any:
    """table에 행 하나를 owner 별칭으로 넣는다(업무 필드만 — PK · created_at은 DB 기본값).

    전제: 시험에 `DB` 마크(transaction=True · default + owner). 비트랜잭션 `django_db`는 별칭마다 atomic을 열어 owner 연결에
    넣은 행이 커밋되지 않는다 — app role 연결(뷰 · 작업)이 그 행을 읽지 못해 부정 사례(「행이 있어도 … 하지 않는다」)가
    공허하게 통과한다. 그래서 owner 연결이 atomic 블록 안이면 넣기 전에 실패한다.
    """
    from django.db import connections

    in_atomic = connections[OWNER_ALIAS].in_atomic_block
    assert not in_atomic, (
        "insert_row: owner 연결이 atomic 블록 안이다 - 시험에 _ia_support.DB 마크(django_db(transaction=True, "
        "databases=['default', 'owner']))가 필요하다(비트랜잭션 django_db에서는 넣은 행이 커밋되지 않아 app role 연결이 "
        "읽지 못한다)"
    )
    return model(table).objects.using(OWNER_ALIAS).create(**fields)


def insert_log_row(
    sub: str,
    *,
    nbf: datetime,
    tenant_id: str = TENANT_A,
    sid: str | None = None,
    reason: str = "logout_all",
    expires_at: datetime | None = None,
    event_pk: str | None = None,
) -> Any:
    """session_revocation_log 행(owner 별칭 · 기본 = 테넌트 A · 사용자 단위(sid 없음) · expires_at = nbf + 330 s · event_pk 없음)."""
    fields: dict[str, Any] = {
        "tenant_id": tenant_id,
        "sub": sub,
        "sid": sid,
        "reason": reason,
        "nbf": nbf,
        "expires_at": nbf + timedelta(seconds=DENYLIST_TTL_S) if expires_at is None else expires_at,
    }
    if event_pk is not None:
        fields["event_pk"] = event_pk
    return insert_row("session_revocation_log", **fields)


def db_now(using: str = "default") -> datetime:
    """`SELECT now()`(aware) — 경계 시각은 DB 시계로 잰다(Python 시계 금지 — T061 교훈 · 설계 사실 ⑪)."""
    from django.db import connections

    with connections[using].cursor() as cursor:
        cursor.execute("SELECT now()")
        (now,) = cursor.fetchone()
    return now


# --- 도우미: Dragonfly · 로그 · 구현 모듈 --------------------------------------------------------------------------------------


def read_int(client: redis.Redis, key: str) -> int | None:
    """key의 값(정수 — 거부 목록 · 하한 · 신선도 키) · 없으면 None."""
    value = client.get(key)
    return None if value is None else int(value)


def read_ttl(client: redis.Redis, key: str) -> int:
    """key의 남은 TTL 초(redis TTL — 없으면 -2 · 만료 없음 -1)."""
    ttl: int = client.ttl(key)
    return ttl


def scan_keys(client: redis.Redis, pattern: str) -> list[str]:
    """pattern에 맞는 키(정렬 · 문자열)."""
    return sorted(key.decode() for key in client.scan_iter(match=pattern, count=1000))


def log_events(records: Iterable[Mapping[str, Any]], event: str) -> list[dict[str, Any]]:
    """log_lines() 기록에서 `event`가 정확히 event인 줄만(차례대로 · 사본).

    함정: 템플릿 `log_lines()`는 부를 때마다 지난 호출 뒤의 새 줄만 주고 비운다 — 여러 이벤트를 고를 때는 `records =
    log_lines()`를 한 번 묶은 뒤 `log_events(records, …)`를 되풀이한다(`log_events(log_lines(), …)`를 두 번 부르면 둘째
    호출은 첫 호출 앞의 줄을 보지 못해 「그 줄 없음」 단언이 공허해진다).
    """
    return [dict(record) for record in records if record.get("event") == event]


def impl(name: str) -> ModuleType:
    """구현 모듈 `identity_admin.<name>`을 쓰는 자리에서 가져온다(모듈 머리 import 금지 — 구현이 없으면 그 시험만
    ModuleNotFoundError로 빨강이다). 이음매(D26)는 돌려받은 모듈의 속성으로 덮는다(`monkeypatch.setattr(impl("revocation"), …)`)."""
    return importlib.import_module(f"identity_admin.{name}")
