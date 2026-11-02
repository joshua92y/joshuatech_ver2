"""django_common.observability · django_common.health 계약 테스트(T063 · test-first — 짝 구현 T071이 초록으로 만든다).

계약: contracts/identity-admin-api.md §엔드포인트(헬스 3종) · §관측 · §오류 슬러그(not_ready) · §타임아웃,
contracts/pod-template.md §런타임 계약(로그 · 트레이스 행) · §django-common 공개 API, rules/django-pod.md §Logging · §Tests.
- 로그: structlog JSON 한 줄 = 한 객체 · 필드 ts(ISO 8601 UTC) · level · logger · event · request_id(상류 X-Request-ID가
  형식 `^[A-Za-z0-9._:-]{1,128}$`에 맞으면 그대로 · 밖이거나 없으면 생성 · 응답 헤더 X-Request-ID로 되돌린다 — 2026-11-02
  보정) · tenant_id · sub_hash · trace_id/span_id(유효 span일 때만). processor가 authorization · cookie ·
  x-authentik-signature 값을 지우고 로그에 남는 URL의 쿼리스트링을 떼어 낸다.
- 트레이스: 상류 traceparent를 이어받은 SERVER span · 샘플러 = process env OTEL_TRACES_SAMPLER=parentbased_traceidratio ·
  OTEL_TRACES_SAMPLER_ARG=0.1 · 헬스 3종은 트레이스에서 뺀다 · span 속성은 tenant_id · sub_hash만 더하고 URL 속성에서
  쿼리스트링을 떼며 요청 헤더를 속성으로 담지 않는다(2026-11-02 보정 — 트레이스로 토큰·쿼리 값이 나가지 않게).
- 헬스: GET /healthz = 프로세스만(외부 의존 조회 없음) 200 {status: "ok", version, git_sha} · GET /ready = DB만(default 별칭
  = app role · SELECT 1) 200 / 503 RFC 9457 not_ready · Dragonfly·Kafka 다운에도 200 · GET /health = 항상 200
  {status, checks: {db, dragonfly, kafka_producer}} 항목마다 ok·fail + 지연 ms · 전체 ≤ 3 s(계약 §타임아웃 — BFF pod fetch
  3 s 안 · 의존 검사 병렬 — 2026-11-02 보정).

T071 가정(계약에 없는 이름·모양 — 설계 D2 · D3 · T071이 확정한다 · 바꾸면 이 파일 · tests/conftest.py T063 절 ·
tests/settings.py T063 절 · tests/obsapp/와 함께):
- 공개 이름: configure_logging(*, stream: TextIO | None = None) -> None(structlog + stdlib logging 모두 stream — 기본
  stdout — 에 JSON 한 줄씩) · configure_otel(*, span_exporter=None, excluded_urls=None) -> TracerProvider(샘플러는 SDK가
  env에서 읽는다 · span_exporter가 있으면 SimpleSpanProcessor · DjangoInstrumentor().instrument(tracer_provider=,
  excluded_urls=, response_hook=) · 이미 계측돼 있으면 uninstrument 뒤 재계측 · 기본 제외 = 헬스 3종 앵커 정규식 —
  0.66b2는 쿼리를 뗀 절대 URI에 정규식 search를 하므로 앵커가 없으면 부분 일치로 다른 경로까지 빠진다) ·
  RequestIdMiddleware(django-structlog RequestMiddleware 하위 · 설정 문자열 "django_common.observability.RequestIdMiddleware"
  로만 단다 — 응답 헤더 X-Request-ID · request_finished에 tenant_id(request.tenant_id가 있을 때 str) · sub_hash
  (request.auth_claims["sub"]가 있을 때) · 형식 밖 상류 X-Request-ID는 버리고 uuid4 생성) ·
  django_common.health.health_router(ninja Router — tests/obsapp/urls.py가 루트에 건다).
- 모양(계약이 정하지 않은 것): /health의 status 값 "ok"|"degraded" · 항목 {status: "ok"|"fail", latency_ms} · /health에도
  version · git_sha(tasks.md T066 :180 문면) · 마스킹은 중첩 매핑 재귀(dict뿐 아니라 collections.abc.Mapping — Django
  request.headers 포함 · 키는 대소문자 · `_`/`-` 무관) · span 속성 이름 tenant_id · sub_hash(tasks.md T071 :188
  "response_hook tenant/sub_hash" — 이름은 설계 D2) · 요청 로그의 경로 필드는 django-structlog `request`("<METHOD> <path>" ·
  쿼리 제거 대상) — 계약 §관측의 route · status · duration_ms를 어디서(라이브러리/pod) 어떤 이름(code → status)으로 낼지는
  T071/T072 결정이고 이 테스트는 단언하지 않는다.
- sub_hash는 성질만 단언한다: hex 16자 이상 · sub와 다름 · 같은 sub → 같은 값 · 다른 sub → 다른 값 · 출력에 원문 sub
  없음(알고리즘 · 키는 T071).
- 설정(tests/settings.py T063 절): 헬스 본문 version · git_sha = APP_VERSION · APP_GIT_SHA(이름 가정 · T071/T072) ·
  DJANGO_STRUCTLOG_TRUST_UPSTREAM_REQUEST_ID = True. /health의 Dragonfly 검사 = DRAGONFLY_URL로 PING(0.2 s · 재시도 0) ·
  Kafka 검사 = KAFKA_BOOTSTRAP_SERVERS + KAFKA_CLIENT_CONFIG로 list_topics(timeout=1.0) · 의존 검사는 병렬(psycopg
  connect_timeout 하한 2 s + 0.2 s + 1.0 s를 순차로 더하면 3 s를 넘는다). 설정은 요청 시점에 읽는다(테스트가 닫힌 포트로
  바꾼다). /ready의 DB 검사에 django-health-check DB 백엔드는 쓰지 않는다(자기 테이블에 써서 check_rls B 등급 허용 목록과
  충돌 — 컨트롤러 결정 · 테스트는 동작만 단언한다).
- 요청 로그에는 django-structlog 기본 ip(X-Forwarded-For 계열 헤더에서 뽑는다 · 클라이언트가 조작 가능 · PII 후보)와
  user_agent도 남는다 — 이 테스트는 단언도 금지도 하지 않는다. 유지/삭제(DJANGO_STRUCTLOG_IP_LOGGING_ENABLED)와 보존 기간은
  T071/T072의 프라이버시 결정이다.

빨간 상태: 지금은 django.setup()이 testapp 모델의 django_common.tenancy(T068)를 못 찾아 수집 전에 멈춘다. T068 뒤에는
이 모듈의 django_common.observability import가 ModuleNotFoundError다(`pytest tests/test_observability.py -p no:django
--collect-only`로 지금 확인할 수 있다) — 둘 다 "구현 없음"이 원인이다.

DB 마크(django_db(transaction=True) · default = app role)는 /ready · /health를 부르거나 쿼리 수를 재는 테스트(obs-11 ·
obs-13..17)에만 있다 — 나머지 로그·OTel 테스트는 pg 컨테이너를 띄우지 않고, 그 경로가 DB에 닿으면 pytest-django가 막는다.
인프라는 conftest의 log_sink/log_lines · obs_settings · otel · make_obs_client/obs_client · auth_settings(Dragonfly reader
URL) · kafka_settings · dragonfly(admin URL — INFO stats 연결 수)다. 비밀(PG app 비밀번호 · 자격이 든 Dragonfly URL)은
tests/_secret.Secret으로 감싸고 노출 단언은 위치 번호 목록으로 접는다 — 실패 출력에 값이 실리지 않게. DB에 닿는
요청(_safe_get · _timed_get)과 obs-13의 미리 연결(_connect_default_db)은 예외를 원 트레이스백 없이 실패로 바꾼다 — psycopg
Connection.connect 프레임의 conninfo 인자(비밀번호 포함)를 pytest 긴 트레이스백이 그대로 출력하기 때문이다(실측). 시험
뷰의 MARK-A…G와 QS-MARK는 표식 문자열이다(비밀 아님).
"""

from __future__ import annotations

import json
import os
import re
import secrets
import socket
import threading
import time
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timedelta
from typing import TYPE_CHECKING, Any, NoReturn

import pytest
import redis
from django.db import connections
from django.test.utils import CaptureQueriesContext
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.trace import SpanKind

from django_common.observability import configure_otel
from tests._dragonfly import connections_received
from tests._jwt import TENANT_ID
from tests._problem import assert_problem
from tests._secret import Secret

if TYPE_CHECKING:
    from collections.abc import Callable

    from django.http import HttpResponse
    from django.test import Client
    from opentelemetry.sdk.trace import ReadableSpan, TracerProvider
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, LogLines

    OTel = tuple[TracerProvider, InMemorySpanExporter]

REQUEST_ID_HEADER = "X-Request-ID"
REQUEST_EVENTS = ("request_started", "ping_handled", "request_finished")
SUB = "user-sub-1"
OTHER_SUB = "user-sub-2"
HEX_HASH = re.compile(r"[0-9a-f]{16,}")
SPAN_ID = re.compile(r"[0-9a-f]{16}")
MARKS = tuple(f"MARK-{letter}" for letter in "ABCDEFG")
HEADER_MARKS = ("MARK-H", "MARK-I", "MARK-J")  # obs-20 — 실제 요청 헤더에 실리는 표식
TRACE_MARKS = ("MARK-T", "MARK-S", "MARK-X")  # obs-19 — span 속성 누출 검사용 요청 헤더 표식
SENSITIVE_HEADERS = frozenset({"authorization", "cookie", "x-authentik-signature"})
URL_ATTRIBUTES = ("http.url", "http.target", "url.full", "url.query", "url.path")
QS_MARK = "QS-MARK"
HEALTH_PATHS = ("/healthz", "/ready", "/health")
CHECK_NAMES = frozenset({"db", "dragonfly", "kafka_producer"})
# obs-16: readiness·liveness가 Dragonfly·Kafka를 보지 않으면 남는 것은 DB SELECT 1(작업 스레드의 새 TLS 연결 포함 수십 ms)
# 뿐이다. 보조 증거다 — 본 증거는 두 리스너의 수락 수 0(어느 의존에도 다이얼하지 않음 · 시간·플랫폼 무관).
READY_LIMIT_S = 0.5
# obs-15/16/18: 의존 실패 판정 상한 = 계약 §타임아웃(BFF pod fetch 3 s 안). 닫힌 127.0.0.1 포트 실측(2026-11-02 · Windows
# 호스트): psycopg connect_timeout 1 → 2.01 s(libpq처럼 2 s 미만을 2 s로 올린다) · redis-py 0.2 s 시간 초과 → 0.21 s ·
# Kafka list_topics(timeout=1.0) → 1.04 s. 세 의존이 모두 다운이면 순차 합 3.2 s > 3 s → 병렬 검사만 통과한다(obs-18).
DOWN_LIMIT_S = 3.0
DB_DOWN_CONNECT_TIMEOUT_S = 1
# 시간 초과가 없는 구현(예: list_topics 기본 timeout -1 = 영구 대기)을 유한한 실패로 끝내는 상한(T062 리뷰 r1 B-2와 같은 방식).
HANG_LIMIT_S = 10.0


# --- 헬퍼 ------------------------------------------------------------------------------------------------------


def _new_trace() -> tuple[str, str]:
    """무작위 trace id(32 hex)와 상류 parent span id(16 hex)."""
    return secrets.token_hex(16), secrets.token_hex(8)


def _traceparent(trace_id: str, parent_id: str, *, sampled: bool = True) -> str:
    """W3C traceparent `00-<trace id>-<parent id>-<flags>`(sampled → 01 · 아니면 00)."""
    return f"00-{trace_id}-{parent_id}-{'01' if sampled else '00'}"


def _events(records: list[dict[str, Any]], event: str) -> list[dict[str, Any]]:
    return [record for record in records if record.get("event") == event]


def _one(records: list[dict[str, Any]], event: str) -> dict[str, Any]:
    """event 줄이 정확히 하나여야 한다."""
    matches = _events(records, event)
    assert len(matches) == 1, f"{event} 줄 수 {len(matches)}"
    return matches[0]


def _request_lines(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """요청 로그 3종(request_started · ping_handled · request_finished) 줄 — 셋 다 있어야 한다."""
    lines = [record for record in records if record.get("event") in REQUEST_EVENTS]
    present = sorted({line["event"] for line in lines})
    assert present == sorted(REQUEST_EVENTS)
    return lines


def _closed_port() -> int:
    """연결을 받지 않는 127.0.0.1 포트 — bind로 번호만 받고 닫는다(Windows는 RST 대신 연결 시간 초과로 끝난다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port: int = probe.getsockname()[1]
    return port


class _Listener:
    """연결을 받자마자 끊고 수락 수를 세는 127.0.0.1 리스너의 손잡이(_counting_listener)."""

    def __init__(self, address: str, counts: list[int], lock: threading.Lock) -> None:
        self.address = address
        self._counts = counts
        self._lock = lock

    @property
    def count(self) -> int:
        with self._lock:
            return self._counts[0]


@contextmanager
def _counting_listener() -> Iterator[_Listener]:
    """127.0.0.1 임시 포트에서 TCP 연결을 받자마자 닫고 수락 수를 세는 리스너(데몬 스레드).

    어떤 의존(Dragonfly · Kafka)에 "다이얼했는가"를 시간·플랫폼과 무관하게 증명한다(리뷰 r1 B-5) — 닫힌 포트는 Windows에서
    RST 대신 시간 초과로 끝나고, 짧은 시간 초과 프로브는 경과 시간으로 잡히지 않기 때문이다. 연결을 바로 끊으므로 클라이언트
    쪽은 즉시(redis-py) 또는 자기 시간 초과 안에(librdkafka) 실패한다.
    """
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.bind(("127.0.0.1", 0))
    server.listen(16)
    server.settimeout(0.1)
    host, port = server.getsockname()
    stop = threading.Event()
    lock = threading.Lock()
    counts = [0]

    def serve() -> None:
        while not stop.is_set():
            try:
                accepted, _ = server.accept()
            except TimeoutError:
                continue
            except OSError:
                break
            with lock:
                counts[0] += 1
            accepted.close()

    thread = threading.Thread(target=serve, name="obs-counting-listener", daemon=True)
    thread.start()
    try:
        yield _Listener(f"{host}:{port}", counts, lock)
    finally:
        stop.set()
        thread.join(2.0)
        server.close()


@contextmanager
def _db_down() -> Iterator[Secret]:
    """default 별칭을 닫힌 127.0.0.1 포트로 돌려 DB 다운을 흉내 낸다 · 끝나면 되돌린다 · app role 비밀번호(Secret)를 준다.

    connection.settings_dict는 settings.DATABASES["default"]와 같은 dict라 작업 스레드의 새 연결에도 유효하다. OPTIONS
    connect_timeout 1은 psycopg가 2 s로 올린다. HOST도 127.0.0.1로 둔다 — `localhost`는 ::1 시도가 먼저라(Docker Desktop 게시
    포트는 IPv4만) 판정이 두 배가 된다(실측 4.03 s).
    """
    connection = connections["default"]
    original = deepcopy(connection.settings_dict)
    try:
        connection.close()
        connection.settings_dict["HOST"] = "127.0.0.1"
        connection.settings_dict["PORT"] = str(_closed_port())
        connection.settings_dict["OPTIONS"] = {**original["OPTIONS"], "connect_timeout": DB_DOWN_CONNECT_TIMEOUT_S}
        yield Secret(os.environ["JT_TEST_PG_APP_PASSWORD"])
    finally:
        connection.close()
        connection.settings_dict.clear()
        connection.settings_dict.update(original)


def _span_text(span: ReadableSpan) -> str:
    """span의 이름 · 속성 · 이벤트(이름 + 속성) · 링크 속성 · 상태 설명을 한 문자열로(누출 검사용)."""
    parts: list[str] = [span.name, str(span.status.description or "")]
    parts.extend(f"{key}={value!r}" for key, value in dict(span.attributes or {}).items())
    for event in span.events:
        parts.append(event.name)
        parts.extend(f"{key}={value!r}" for key, value in dict(event.attributes or {}).items())
    for link in span.links:
        parts.extend(f"{key}={value!r}" for key, value in dict(link.attributes or {}).items())
    return "\n".join(parts)


def _response_text(response: HttpResponse) -> str:
    """응답 본문 + 헤더 전체(노출 검사용)."""
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    return f"{response.content.decode('utf-8', errors='replace')}\n{headers}"


def _log_text(log_lines: LogLines) -> str:
    """이 테스트가 지금까지 만든 로그 원문 전체 — 새 줄을 읽어(한 줄 = 한 JSON 객체 검사 포함) raw에 쌓은 뒤 돌려준다."""
    log_lines()
    return log_lines.raw


def _assert_absent(where: str, text: str, *needles: str) -> None:
    """needles(비밀번호 · 자격이 든 URL)가 text 어디에도 없다.

    값이 실패 출력에 실리지 않게 두 겹으로 막는다(tests/test_auth.py _assert_no_leak과 같은 방식): ① pytest는 실패한
    마지막 트레이스백 항목의 함수 인자를 지금 값의 repr로 찍는다 → 인자 이름 text · needles를 Secret(repr 가림)으로 다시
    묶는다 · ② 단언 재작성은 비교 피연산자를 찍는다 → 위치 번호 목록으로 접어 단언한다.
    """
    text = Secret(text)
    needles = tuple(Secret(needle) for needle in needles)
    leaked = [index for index, needle in enumerate(needles) if needle and needle in text]
    assert leaked == [], f"{where}에 민감 값이 있다(needles 위치 {leaked})"


def _fail_without_trace(what: str, exc: BaseException) -> NoReturn:
    """예외를 원 트레이스백·메시지 없이 실패로 바꾼다(pytrace=False — 이 메시지만 출력된다).

    pytest 긴 트레이스백은 마지막 항목의 함수 인자를 지금 값의 repr로 찍는다. psycopg 3.3 Connection.connect는 인자 이름
    conninfo를 비밀번호가 든 접속 문자열로 다시 묶는다 — DB 연결 실패가 요청 밖으로 새면 그 비밀번호가 출력된다
    (2026-11-02 참조 구현 변이 실측: /health가 DB 오류를 다시 던지자 app role 비밀번호가 찍혔다). 그래서 형식 이름만 싣고,
    호출자는 except 블록 밖에서 부른다(연쇄된 원 예외 __context__도 남지 않게).
    """
    kind = f"{type(exc).__module__}.{type(exc).__name__}"
    pytest.fail(f"{what}: 예외로 끝났다({kind}) — 원 트레이스백·메시지는 비밀 노출을 막으려고 싣지 않는다", pytrace=False)


def _safe_get(client: Client, path: str, **kwargs: Any) -> HttpResponse:
    """DB에 닿는 GET — 예외가 나면 _fail_without_trace로 끝난다(시험 Client는 뷰 예외를 그대로 다시 던진다)."""
    try:
        response = client.get(path, **kwargs)
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    else:
        return response
    _fail_without_trace(f"GET {path}", failure)


def _connect_default_db() -> None:
    """default 별칭 연결을 미리 연다(CaptureQueriesContext가 들어갈 때 여는 연결과 같다) — 실패는 _fail_without_trace."""
    failure: BaseException | None = None
    try:
        connections["default"].ensure_connection()
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    if failure is not None:
        _fail_without_trace("default DB 연결", failure)


def _timed_get(client: Client, path: str) -> tuple[HttpResponse, float]:
    """GET 한 번과 그 경과 시간(초) — 요청은 데몬 스레드에서 돈다(tests/test_auth.py _timed_get과 같은 방식).

    HANG_LIMIT_S 안에 끝나지 않으면(시간 초과가 없는 구현 = 영구 대기) pytest.fail로 끝낸다. 스레드 안의 예외는
    _fail_without_trace로 바꾼다(DB 연결 실패의 원 트레이스백은 비밀번호를 싣는다). Django DB 연결은 스레드마다 따로다:
    작업 스레드는 settings.DATABASES의 같은 dict(obs-15가 바꾼 HOST · PORT · OPTIONS 포함)로 새 연결을 열고, 끝날 때 자기
    연결만 닫는다(connections.close_all은 그 스레드 것만).
    """
    outcome: list[HttpResponse | BaseException] = []

    def run() -> None:
        try:
            outcome.append(client.get(path))
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드로 넘긴다
            outcome.append(exc)
        finally:
            connections.close_all()

    worker = threading.Thread(target=run, name="obs-timed-get", daemon=True)
    start = time.perf_counter()
    worker.start()
    worker.join(HANG_LIMIT_S)
    elapsed = time.perf_counter() - start
    if worker.is_alive():
        pytest.fail(f"GET {path}가 {HANG_LIMIT_S:.0f} s 안에 끝나지 않았다 — 의존 조회에 시간 초과가 없는 구현인가")
    result = outcome[0]
    if isinstance(result, BaseException):
        _fail_without_trace(f"GET {path}", result)
    return result, elapsed


def _health_body(response: HttpResponse) -> tuple[Any, dict[str, Any]]:
    """/health 본문의 status와 항목별 status(checks의 키 집합은 정확히 db · dragonfly · kafka_producer)."""
    body: dict[str, Any] = json.loads(response.content)
    checks = body.get("checks")
    assert isinstance(checks, dict)
    names = set(checks)
    assert names == CHECK_NAMES
    statuses = {name: check.get("status") if isinstance(check, dict) else None for name, check in checks.items()}
    return body.get("status"), statuses


# --- 구조 로그(request_id · tenant_id · sub_hash · 마스킹 · 형식) ------------------------------------------------------


def test_obs_1_request_id_forwarded(obs_client: Client, log_lines: LogLines) -> None:
    """obs-1 — 헤더 X-Request-ID: req-abc-123 → 요청 로그 3줄(request_started · ping_handled · request_finished) 전부
    request_id == req-abc-123 · 응답 헤더 X-Request-ID == req-abc-123."""
    response = obs_client.get("/obs/ping", headers={REQUEST_ID_HEADER: "req-abc-123"})
    assert response.status_code == 200
    lines = _request_lines(log_lines())
    assert len(lines) >= 3
    assert {line.get("request_id") for line in lines} == {"req-abc-123"}
    assert response[REQUEST_ID_HEADER] == "req-abc-123"


def test_obs_2_request_id_generated(obs_client: Client, log_lines: LogLines) -> None:
    """obs-2 — 헤더가 없으면 request_id를 만든다: 요청 로그 3줄이 같은 값 · UUID로 파싱 · 응답 헤더 X-Request-ID == 그 값 ·
    두 번째 요청의 값은 다르다."""
    generated: list[str] = []
    for _ in range(2):
        response = obs_client.get("/obs/ping")
        assert response.status_code == 200
        ids = {line.get("request_id") for line in _request_lines(log_lines())}
        assert len(ids) == 1
        (request_id,) = ids
        assert isinstance(request_id, str)
        uuid.UUID(request_id)
        assert response[REQUEST_ID_HEADER] == request_id
        generated.append(request_id)
    assert generated[0] != generated[1]


def test_obs_3_tenant_id(obs_client: Client, log_lines: LogLines) -> None:
    """obs-3 — 테넌트가 있는 요청(시험 상류 미들웨어 X-Test-Tenant → request.tenant_id)의 request_finished에 tenant_id ·
    테넌트가 없는 요청의 request_finished에는 tenant_id 키가 없다."""
    assert obs_client.get("/obs/ping", headers={"X-Test-Tenant": TENANT_ID}).status_code == 200
    assert _one(log_lines(), "request_finished").get("tenant_id") == TENANT_ID
    assert obs_client.get("/obs/ping").status_code == 200
    assert "tenant_id" not in _one(log_lines(), "request_finished")


def test_obs_4_sub_hash(obs_client: Client, log_lines: LogLines) -> None:
    """obs-4 — X-Test-Sub(→ request.auth_claims["sub"])가 있는 요청의 request_finished에 sub_hash: hex 16자 이상 · sub와
    다름 · 같은 sub → 같은 값 · 다른 sub → 다른 값 · sub가 없으면 키 없음 · 출력 어디에도 원문 sub가 없다."""

    def finished(headers: dict[str, str]) -> dict[str, Any]:
        assert obs_client.get("/obs/ping", headers=headers).status_code == 200
        return _one(log_lines(), "request_finished")

    first = finished({"X-Test-Sub": SUB}).get("sub_hash")
    assert isinstance(first, str)
    assert HEX_HASH.fullmatch(first)
    assert first != SUB
    assert finished({"X-Test-Sub": SUB}).get("sub_hash") == first
    assert finished({"X-Test-Sub": OTHER_SUB}).get("sub_hash") != first
    assert "sub_hash" not in finished({})  # 키 자체가 없다(null도 아니다)
    raw_has_sub = [needle for needle in (SUB, OTHER_SUB) if needle in log_lines.raw]
    assert raw_has_sub == [], "로그 출력에 sub 원문이 있다"


def test_obs_5_sensitive_keys_removed(obs_client: Client, log_lines: LogLines) -> None:
    """obs-5 — authorization · cookie · x-authentik-signature는 최상위 · headers 매핑 · 중첩 매핑 어디서든 지워진다
    (대소문자 · `_`/`-` 무관) · 표식 값 MARK-A…G가 출력 어디에도 없다 · 이웃 값(safe · headers의 Accept)은 남는다."""
    assert obs_client.get("/obs/leak").status_code == 200
    probe = _one(log_lines(), "leak_probe")
    for key in ("authorization", "cookie", "x_authentik_signature"):
        assert key not in probe, key
    headers = probe.get("headers")
    assert isinstance(headers, dict)
    for key in ("Authorization", "Cookie", "X-Authentik-Signature"):
        assert key not in headers, key
    assert headers.get("Accept") == "*/*"
    nested = probe.get("nested")
    assert isinstance(nested, dict)
    inner = nested.get("inner")
    assert isinstance(inner, dict)
    assert "cookie" not in inner
    assert probe.get("safe") == "keep-me"
    leaked = [mark for mark in MARKS if mark in log_lines.raw]
    assert leaked == []


def test_obs_6_query_string_dropped(obs_client: Client, log_lines: LogLines) -> None:
    """obs-6 — 쿼리스트링은 로그에 남지 않는다: request_started · request_finished의 request == "GET <경로>"(200 응답과
    404 응답 둘 다 — 404는 stdlib django.request 줄도 낸다) · 출력 어디에도 QS-MARK가 없다."""
    cases = (("/obs/ping", 200), ("/obs/missing", 404))
    for path, status in cases:
        response = obs_client.get(f"{path}?access_token={QS_MARK}&x=1")
        assert response.status_code == status
        records = log_lines()
        for event in ("request_started", "request_finished"):
            assert _one(records, event).get("request") == f"GET {path}", (path, event)
    leaked = QS_MARK in log_lines.raw
    assert not leaked, "로그 출력에 쿼리스트링 값이 있다"


def test_obs_7_line_shape(obs_client: Client, log_lines: LogLines) -> None:
    """obs-7 — 요청들이 만든 모든 줄(structlog · stdlib 둘 다): ts(ISO 8601 · UTC) · level · event · logger가 비어 있지
    않은 str · ping_handled의 logger == tests.obsapp · stdlib 줄(404의 django.request WARNING)도 같은 JSON sink에 같은
    모양으로 온다(configure_logging 가정 D2 — stdlib logging도 JSON)."""
    assert obs_client.get("/obs/ping", headers={REQUEST_ID_HEADER: "req-shape-1"}).status_code == 200
    assert obs_client.get("/obs/leak").status_code == 200
    assert obs_client.get("/obs/missing").status_code == 404
    records = log_lines()
    assert records
    for index, record in enumerate(records):
        where = (index, record.get("event"))
        ts = record.get("ts")
        assert isinstance(ts, str), where
        parsed = datetime.fromisoformat(ts)
        assert parsed.tzinfo is not None, where
        assert parsed.utcoffset() == timedelta(0), where
        for key in ("level", "event", "logger"):
            value = record.get(key)
            assert isinstance(value, str) and value != "", (*where, key)
    assert _one(records, "ping_handled").get("logger") == "tests.obsapp"
    stdlib_lines = [record for record in records if record.get("logger") == "django.request"]
    assert stdlib_lines, "stdlib logging(django.request) 줄이 JSON sink에 없다"
    assert stdlib_lines[0]["level"].lower() == "warning"


def test_obs_20_request_headers_mapping_masked(obs_client: Client, log_lines: LogLines) -> None:
    """obs-20 — 뷰가 실제 request.headers(Django HttpHeaders = CaseInsensitiveMapping · dict 아님)와 dict(request.headers)를
    로그에 실어도 authorization · cookie · x-authentik-signature는 두 매핑에서 지워지고 Accept는 남는다 · 표식 MARK-H/I/J가
    출력 어디에도 없다. dict만 재귀하는 processor는 Mapping을 건너뛰고 JSON 렌더러의 repr 폴백이 값을 그대로 찍는다(리뷰
    r1 B-2) — 마스킹은 collections.abc.Mapping 전체에 적용되고 결과는 JSON 객체(dict)여야 한다."""
    headers = {
        "Authorization": f"Bearer {HEADER_MARKS[0]}",
        "Cookie": f"sid={HEADER_MARKS[1]}",
        "X-Authentik-Signature": f"sha256={HEADER_MARKS[2]}",
        "Accept": "application/json",
    }
    assert obs_client.get("/obs/leak-headers", headers=headers).status_code == 200
    probe = _one(log_lines(), "leak_headers_probe")
    for field in ("headers", "mapping"):
        value = probe.get(field)
        assert isinstance(value, dict), field
        lowered = {str(key).lower() for key in value}
        assert lowered.isdisjoint(SENSITIVE_HEADERS), (field, sorted(lowered & SENSITIVE_HEADERS))
        assert value.get("Accept") == "application/json", field
    leaked = [mark for mark in HEADER_MARKS if mark in log_lines.raw]
    assert leaked == []


def test_obs_21_request_id_validated(obs_client: Client, log_lines: LogLines) -> None:
    """obs-21 — 상류 X-Request-ID가 형식 `^[A-Za-z0-9._:-]{1,128}$` 밖(129자 · 공백·특수문자 · 비ASCII)이면 그대로 쓰지 않고
    생성한다: 요청 로그 3줄의 request_id는 UUID · 보낸 값 아님 · 응답 헤더 == 생성값 · 출력 어디에도 보낸 값 없음(로그 증폭 ·
    임의 문자열 적재 방지 — 계약 머리 2026-11-02 보정). 형식 안의 128자 값은 그대로 쓴다."""
    bad_values = ("x" * 129, "bad id!", "aéb")
    for bad in bad_values:
        response = obs_client.get("/obs/ping", headers={REQUEST_ID_HEADER: bad})
        assert response.status_code == 200
        ids = {line.get("request_id") for line in _request_lines(log_lines())}
        assert len(ids) == 1, bad
        (request_id,) = ids
        assert isinstance(request_id, str) and request_id != bad, bad
        uuid.UUID(request_id)
        assert response[REQUEST_ID_HEADER] == request_id, bad
    echoed = [value for value in bad_values if value in log_lines.raw]
    assert echoed == [], "로그 출력에 형식 밖 X-Request-ID 값이 있다"
    good = ("Ab9._:-" * 19)[:128]
    response = obs_client.get("/obs/ping", headers={REQUEST_ID_HEADER: good})
    assert response.status_code == 200
    assert {line.get("request_id") for line in _request_lines(log_lines())} == {good}
    assert response[REQUEST_ID_HEADER] == good


# --- 트레이스(OTel)------------------------------------------------------------------------------------------


def test_obs_8_sampler(otel: OTel, monkeypatch: pytest.MonkeyPatch) -> None:
    """obs-8 — 샘플러 = env OTEL_TRACES_SAMPLER=parentbased_traceidratio · OTEL_TRACES_SAMPLER_ARG=0.1 →
    ParentBased(TraceIdRatioBased(0.1)). 값이 env에서 오는지(0.1을 박아 넣지 않았는지) ARG 0.25로 한 번 더 본다."""
    provider, _ = otel
    assert provider.sampler.get_description() == ParentBased(TraceIdRatioBased(0.1)).get_description()
    monkeypatch.setenv("OTEL_TRACES_SAMPLER_ARG", "0.25")
    other = configure_otel(span_exporter=InMemorySpanExporter())
    try:
        assert other.sampler.get_description() == ParentBased(TraceIdRatioBased(0.25)).get_description()
    finally:
        other.shutdown()


def test_obs_9_server_span(otel: OTel, obs_client: Client) -> None:
    """obs-9 — sampled traceparent → SERVER span 1개: trace id 이어받음 · parent = 상류 span id · 속성 tenant_id ·
    sub_hash(hex 16자 이상 · sub와 다름) · 상태 코드 200 · 두 번째 요청 뒤 2개."""
    _, exporter = otel
    trace_id, parent_id = _new_trace()
    headers = {"traceparent": _traceparent(trace_id, parent_id), "X-Test-Tenant": TENANT_ID, "X-Test-Sub": SUB}
    assert obs_client.get("/obs/ping", headers=headers).status_code == 200
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    span = spans[0]
    assert span.kind == SpanKind.SERVER
    assert format(span.context.trace_id, "032x") == trace_id
    assert span.parent is not None
    assert format(span.parent.span_id, "016x") == parent_id
    attributes = dict(span.attributes or {})
    assert attributes.get("tenant_id") == TENANT_ID
    sub_hash = attributes.get("sub_hash")
    assert isinstance(sub_hash, str)
    assert HEX_HASH.fullmatch(sub_hash)
    assert sub_hash != SUB
    assert attributes.get("http.status_code", attributes.get("http.response.status_code")) == 200
    assert obs_client.get("/obs/ping", headers=headers).status_code == 200
    assert len(exporter.get_finished_spans()) == 2


def test_obs_10_not_sampled(otel: OTel, obs_client: Client) -> None:
    """obs-10 — 상류가 샘플링하지 않은 traceparent(플래그 00) → span 0(ParentBased)."""
    _, exporter = otel
    headers = {"traceparent": _traceparent(*_new_trace(), sampled=False)}
    assert obs_client.get("/obs/ping", headers=headers).status_code == 200
    assert len(exporter.get_finished_spans()) == 0


@pytest.mark.django_db(transaction=True)
@pytest.mark.usefixtures("auth_settings")
def test_obs_11_health_not_traced(otel: OTel, obs_client: Client) -> None:
    """obs-11 — sampled traceparent여도 헬스 3종은 span 0(트레이스 제외) · /obs/ready-check는 span 1(제외 정규식은 앵커 —
    `ready` 부분 일치로 빠지지 않는다)."""
    _, exporter = otel
    headers = {"traceparent": _traceparent(*_new_trace())}
    statuses = {path: _safe_get(obs_client, path, headers=headers).status_code for path in HEALTH_PATHS}
    assert statuses == dict.fromkeys(HEALTH_PATHS, 200)
    assert len(exporter.get_finished_spans()) == 0
    assert obs_client.get("/obs/ready-check", headers=headers).status_code == 200
    assert len(exporter.get_finished_spans()) == 1


def test_obs_12_trace_ids_in_logs(otel: OTel, obs_client: Client, log_lines: LogLines) -> None:
    """obs-12 — sampled 요청의 요청 로그 3줄에 trace_id(이어받은 trace id) · span_id(SERVER span의 id · hex 16자) ·
    트레이스 제외 경로(/healthz) 요청의 request_finished에는 trace_id · span_id 키가 없다."""
    _, exporter = otel
    trace_id, parent_id = _new_trace()
    headers = {"traceparent": _traceparent(trace_id, parent_id)}
    assert obs_client.get("/obs/ping", headers=headers).status_code == 200
    lines = _request_lines(log_lines())
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    server_span_id = format(spans[0].context.span_id, "016x")
    for line in lines:
        event = line["event"]
        assert line.get("trace_id") == trace_id, event
        span_id = line.get("span_id")
        assert isinstance(span_id, str), event
        assert SPAN_ID.fullmatch(span_id), event
        assert span_id == server_span_id, event
    assert obs_client.get("/healthz", headers=headers).status_code == 200
    finished = _one(log_lines(), "request_finished")
    assert "trace_id" not in finished
    assert "span_id" not in finished


def test_obs_19_span_attributes_no_secrets(otel: OTel, obs_client: Client) -> None:
    """obs-19 — sampled 요청에 Authorization · Cookie · X-Authentik-Signature 헤더(표식 MARK-T/S/X) · 쿼리스트링(QS-MARK) ·
    X-Test-Sub를 실어도 내보낸 span의 이름 · 속성 · 이벤트 · 링크 어디에도 그 값과 원문 sub가 없다 · URL 속성(http.url ·
    http.target · url.full · url.query · url.path)에 `?`가 없고 url.query는 없다(계약 §관측 트레이스 — 속성은 tenant_id ·
    sub_hash만 추가 · URL 쿼리 제거 · 요청 헤더 캡처 금지). 0.66b2 기본은 http.url에 쿼리까지 넣고 redact는 AWS/GCS 서명
    파라미터 4개만 가린다 — 구현(response_hook)이 고쳐 써야 한다."""
    _, exporter = otel
    headers = {
        "traceparent": _traceparent(*_new_trace()),
        "X-Test-Sub": SUB,
        "Authorization": f"Bearer {TRACE_MARKS[0]}",
        "Cookie": f"sid={TRACE_MARKS[1]}",
        "X-Authentik-Signature": f"sha256={TRACE_MARKS[2]}",
    }
    assert obs_client.get(f"/obs/ping?access_token={QS_MARK}&x=1", headers=headers).status_code == 200
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    text = _span_text(spans[0])
    leaked = [needle for needle in (*TRACE_MARKS, QS_MARK, SUB) if needle in text]
    assert leaked == [], "span에 요청 헤더 값 · 쿼리스트링 · 원문 sub가 있다"
    attributes = dict(spans[0].attributes or {})
    url_attributes = {key: str(value) for key, value in attributes.items() if key in URL_ATTRIBUTES}
    with_query = sorted(key for key, value in url_attributes.items() if "?" in value)
    assert with_query == []
    assert "url.query" not in attributes


# --- 헬스(/healthz · /ready · /health) -------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
@pytest.mark.usefixtures("auth_settings")
def test_obs_13_healthz(obs_client: Client, dragonfly: DragonflyInfo, settings: SettingsWrapper) -> None:
    """obs-13 — /healthz 200 {status: ok, version, git_sha} · DB 쿼리 0 · Dragonfly 새 연결 0(프로세스만).

    살아 있는 reader URL(auth_settings)에서 재므로 조회하되 오류를 삼키는 구현도 연결 수(total_connections_received)
    차이로 잡힌다. CaptureQueriesContext는 들어갈 때 default 연결을 미리 연다(ensure_connection) — 연결 자체는 쿼리로
    세지 않는다.
    """
    _connect_default_db()
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        before = connections_received(admin)
        with CaptureQueriesContext(connections["default"]) as queries:
            response = _safe_get(obs_client, "/healthz")
        opened = connections_received(admin) - before
    finally:
        admin.close()
    assert response.status_code == 200
    expected = {"status": "ok", "version": settings.APP_VERSION, "git_sha": settings.APP_GIT_SHA}
    assert json.loads(response.content) == expected
    assert len(queries) == 0
    assert opened == 0, "/healthz가 Dragonfly에 연결했다"


@pytest.mark.django_db(transaction=True)
@pytest.mark.usefixtures("auth_settings")
def test_obs_14_ready(obs_client: Client, dragonfly: DragonflyInfo) -> None:
    """obs-14 — DB 정상 → /ready 200 · Dragonfly 새 연결 0(readiness는 DB만 본다 · 연결 수 차이 — obs-13과 같은 방식)."""
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        before = connections_received(admin)
        response = _safe_get(obs_client, "/ready")
        opened = connections_received(admin) - before
    finally:
        admin.close()
    assert response.status_code == 200
    assert opened == 0, "/ready가 Dragonfly에 연결했다"


@pytest.mark.django_db(transaction=True)
@pytest.mark.usefixtures("auth_settings", "kafka_settings")
def test_obs_15_db_down(obs_client: Client, log_lines: LogLines) -> None:
    """obs-15 — DB 다운: /ready 503 not_ready · /healthz 200 · /health 200(degraded · checks.db fail) · 각 경과 < 3 s ·
    응답·로그에 app role 비밀번호 없음 → 설정을 되돌리면 /ready 200.

    DB 다운은 default 별칭 연결 설정(settings.DATABASES["default"]와 같은 dict)을 닫힌 127.0.0.1 포트로 바꿔 흉내 낸다
    (OPTIONS connect_timeout 1 — psycopg가 2 s로 올린다). HOST도 127.0.0.1로 둔다: `localhost`는 ::1 시도가 먼저라
    (Docker Desktop 게시 포트는 IPv4만) 판정이 두 배가 된다(실측 4.03 s). Dragonfly(auth_settings reader)와
    Kafka(kafka_settings)는 살아 있게 둔다 — /health의 경과가 DB 판정에만 걸리게.
    """
    with _db_down() as password:
        ready, ready_s = _timed_get(obs_client, "/ready")
        healthz, healthz_s = _timed_get(obs_client, "/healthz")
        health, health_s = _timed_get(obs_client, "/health")
    for response in (ready, healthz, health):
        _assert_absent("응답", _response_text(response), password)
    _assert_absent("로그", _log_text(log_lines), password)
    assert_problem(ready, 503, "not_ready")
    assert healthz.status_code == 200
    assert health.status_code == 200
    status, checks = _health_body(health)
    assert status == "degraded"
    assert checks["db"] == "fail"
    elapsed = {"/ready": round(ready_s, 2), "/healthz": round(healthz_s, 2), "/health": round(health_s, 2)}
    slow = [path for path, seconds in elapsed.items() if seconds >= DOWN_LIMIT_S]
    assert slow == [], f"경과(s) {elapsed}"
    assert _safe_get(obs_client, "/ready").status_code == 200


@pytest.mark.django_db(transaction=True)
def test_obs_16_dependencies_down(
    make_obs_client: Callable[[], Client], settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """obs-16 — Dragonfly·Kafka 다운(연결을 받자마자 끊고 수락 수를 세는 127.0.0.1 리스너 2개): /ready 200 · 경과 < 0.5 s ·
    /healthz 200 · 경과 < 0.5 s · 그동안 두 리스너 수락 0(readiness·liveness는 어느 의존에도 다이얼하지 않는다 — 시간·플랫폼
    무관 증거 · 리뷰 r1 B-5 · A-4) · /health 200 · degraded(db ok · dragonfly fail · kafka_producer fail) · 경과 < 3 s · 두
    리스너 수락 ≥ 1(상세 헬스는 의존을 실제로 본다) · 응답·로그에 Dragonfly 비밀번호·URL 없음."""
    password = Secret(secrets.token_urlsafe(16))
    with _counting_listener() as dragonfly_sink, _counting_listener() as kafka_sink:
        url = Secret(f"redis://test-pod:{password}@{dragonfly_sink.address}/0")
        settings.DRAGONFLY_URL = url
        settings.KAFKA_BOOTSTRAP_SERVERS = kafka_sink.address
        client = make_obs_client()
        ready, ready_s = _timed_get(client, "/ready")
        healthz, healthz_s = _timed_get(client, "/healthz")
        quiet = (dragonfly_sink.count, kafka_sink.count)
        health, health_s = _timed_get(client, "/health")
        dialed = (dragonfly_sink.count, kafka_sink.count)
    for response in (ready, healthz, health):
        _assert_absent("응답", _response_text(response), password, url)
    _assert_absent("로그", _log_text(log_lines), password, url)
    assert ready.status_code == 200
    assert ready_s < READY_LIMIT_S, f"/ready 경과 {ready_s:.3f} s"
    assert healthz.status_code == 200
    assert healthz_s < READY_LIMIT_S, f"/healthz 경과 {healthz_s:.3f} s"
    assert quiet == (0, 0), f"/ready·/healthz가 의존에 다이얼했다(Dragonfly · Kafka 수락 수 {quiet})"
    assert health.status_code == 200
    assert health_s < DOWN_LIMIT_S, f"/health 경과 {health_s:.3f} s"
    status, checks = _health_body(health)
    assert status == "degraded"
    assert (checks["db"], checks["dragonfly"], checks["kafka_producer"]) == ("ok", "fail", "fail")
    assert dialed[0] >= 1 and dialed[1] >= 1, f"/health가 의존에 다이얼하지 않았다(수락 수 {dialed})"


@pytest.mark.django_db(transaction=True)
@pytest.mark.usefixtures("auth_settings", "kafka_settings")
def test_obs_17_health_all_ok(obs_client: Client, settings: SettingsWrapper) -> None:
    """obs-17 — 의존이 모두 정상(Dragonfly reader · 시험 Kafka) → /health 200 · status ok · 세 항목 ok · latency_ms 숫자
    ≥ 0 · version · git_sha == 설정값."""
    response = _safe_get(obs_client, "/health")
    assert response.status_code == 200
    status, checks = _health_body(response)
    assert status == "ok"
    assert checks == dict.fromkeys(CHECK_NAMES, "ok")
    body: dict[str, Any] = json.loads(response.content)
    assert (body.get("version"), body.get("git_sha")) == (settings.APP_VERSION, settings.APP_GIT_SHA)
    for name in sorted(CHECK_NAMES):
        latency = body["checks"][name].get("latency_ms")
        assert isinstance(latency, int | float), name
        assert not isinstance(latency, bool), name
        assert latency >= 0, name


@pytest.mark.django_db(transaction=True)
def test_obs_18_all_dependencies_down(
    make_obs_client: Callable[[], Client], settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """obs-18 — DB·Dragonfly·Kafka 전부 다운(닫힌 127.0.0.1 포트) → /health 200 · degraded · 세 항목 fail · 경과 < 3 s(계약
    §타임아웃: BFF pod fetch 3 s 안에 답한다 — psycopg 하한 2 s + Dragonfly 0.2 s + Kafka 1 s를 순차로 더하면 3.2 s라 의존
    검사를 병렬로 돌리는 구현만 통과한다 · 리뷰 r1 A-3/B-9) · 응답·로그에 DB·Dragonfly 비밀번호 없음."""
    password = Secret(secrets.token_urlsafe(16))
    url = Secret(f"redis://test-pod:{password}@127.0.0.1:{_closed_port()}/0")
    settings.DRAGONFLY_URL = url
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{_closed_port()}"
    client = make_obs_client()
    with _db_down() as db_password:
        health, health_s = _timed_get(client, "/health")
    _assert_absent("응답", _response_text(health), password, url, db_password)
    _assert_absent("로그", _log_text(log_lines), password, url, db_password)
    assert health.status_code == 200
    assert health_s < DOWN_LIMIT_S, f"/health 경과 {health_s:.3f} s"
    status, checks = _health_body(health)
    assert status == "degraded"
    assert checks == dict.fromkeys(CHECK_NAMES, "fail")
