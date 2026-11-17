"""django_common.observability — 구조 로그 · 요청 로그 미들웨어 · 트레이스 · 오류 보고 · sub_hash(T071).

계약(정본 — 규칙을 여기 되풀이하지 않는다): contracts/pod-template.md §런타임 계약 「로그」 · 「트레이스 · Sentry」 행 ·
§django-common 공개 API · contracts/identity-admin-api.md §관측 · 규칙 .claude/rules/django-pod.md §Logging. 설계 정본:
specs/003-platform-foundation/design/build-notes.md 「## T071」 D2(configure_logging · mask_sensitive) · D3(RequestIdMiddleware) ·
D4(sub_hash) · D5(configure_otel) · D7(configure_sentry) · D8(공개 이름) · 「T071 r1 결과 · r2 결정」 Y1 · Y3 · Y4 · Y6 · 「T071 r2
결과 · r3 결정」 Z1(OTel env · 굳은 값 · 지표) · Z2(Sentry 헤더) · Z4(마스킹 목록) · 「T071 r3 결과 · r4 결정」 Q1(OTEL_PROPAGATORS
해석 규칙 = OTel) · Q3(굳은 값 확인의 판 올림 경로) · 「T071 r4 결과 · r5 결정」 P1(받는 propagator 이름은 OTel보다 좁다) ·
P2(Django 인증 폼 비밀번호 필드) · P3(camelCase 머리글자 경계) · P5(OTLP 헤더 env 거부) · 「T071 r5 결과 · r6 결정」 G1(OTLP 자격
통로 — mTLS 클라이언트 키 · 인증서 env 거부 · 엔드포인트 닫힌 꼴) · G2(camelCase 세 꼴 판정) · 「T071 r6 결과 · r7 결정」
S1(엔드포인트 스킴의 대소문자 무시는 ASCII로만) · 「T071 r7 결과 · r8 결정」 L2(sentry_sdk.init 실패 = 예외 클래스 이름만 실은
설정 오류 · 연쇄 예외 없음).

모든 공개 함수는 부를 때만 동작한다 — import는 로깅 · structlog · OTel · Sentry 설정과 스레드 · 소켓 · 지표 등록을 만들지 않는다
(OTel SDK · 계측 · 내보내기 · Sentry는 해당 configure_* 안에서 import한다). 호출 위치(AppConfig.ready · wsgi.py)는 T072가 정한다.
계약 행으로 옮겨진 동작(level ValueError · problem 64 KiB · 마스킹 목록 · 계측 미들웨어 삽입 확인 · 굳은 값 확인 · 빈 env ·
OTel import 전 env 검사 · 엔드포인트 닫힌 꼴 · Sentry 요청 키 · 헤더 허용 목록 · Dsn 꼴)은 위 계약 행을 본다.

구현 메모(계약 행이 말하지 않는 것):
- configure_logging은 dictConfig를 쓰지 않는다 — 루트에 표식 단 StreamHandler 하위 핸들러 하나를 두고 다시 부르면 그것만 바꾼다
  (다른 핸들러 · 다른 로거의 level · propagate · disabled는 건드리지 않는다). 쓰기 실패 고정 줄의 ts는 TimeStamper와 같은 꼴이고,
  현재 예외가 없으면 error는 "unknown"이다.
- mask_sensitive는 이벤트 dict 최상위의 exc_info만 그대로 넘긴다(format_exc_info가 렌더할 튜플 · 예외 객체를 list로 바꾸지
  않게). 마스킹 결과는 새 dict다. 깊이는 이벤트 dict = 0단 · 그 값의 컨테이너 = 1단으로 세고 17단째 컨테이너를
  "<truncated>"로 바꾼다. 판정 순서: 키 형(str · bytes · bytearray · memoryview — 기반 형 메서드로 읽어 하위 형의 재정의를 부르지
  않는다 · 풀 수 없는 memoryview는 판정 밖) → 원래 꼴 · camelCase 첫 경계 꼴 · 두 경계 꼴을 각각 정규화 → 정확한 이름 · 접두 ·
  접미. 판정은 어떤 키에도 예외를 내지 않는다. 쌍 판정은 첫 항목에 같은 판정을 쓰므로 bytearray · memoryview 첫 항목도 덮는다.
- RequestIdMiddleware는 django-structlog의 신호(bind_extra_request_metadata · bind_extra_request_finished_metadata ·
  update_failure_response)와 스트리밍 감싸기를 그대로 보낸다(pod 확장 지점). request_failed는 기반 클래스가 남긴다(format_request ·
  bind_user_id를 이 클래스가 바꾼다).
- configure_otel은 엔드포인트 env 둘의 꼴을 span_exporter와 무관하게 OTel import 전에 본다(_check_otel_env · T071 r6 G1) —
  엔드포인트를 고르는 것은 span_exporter가 없을 때뿐이다. 굳은 값 확인은 (a) 요청 속성 목록 · (b) 전역 propagator · (c) semconv
  모드 순서로 보고 어긋난 첫 env 이름을 싣는다.
- configure_sentry는 DSN 꼴을 init 전에 직접 본다 — 가로채는 Transport를 넘기면 SDK는 DSN을 해석하지 않는다.
"""

from __future__ import annotations

import datetime as _dt
import decimal
import json
import logging
import math
import os
import re
import sys
import time
import uuid
from collections.abc import Mapping
from typing import TYPE_CHECKING, Any, TextIO

import structlog
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.http import StreamingHttpResponse
from django.utils.crypto import salted_hmac
from django_structlog import signals as structlog_signals
from django_structlog.app_settings import app_settings as structlog_settings
from django_structlog.middlewares.request import RequestMiddleware
from django_structlog.middlewares.request import async_streaming_content_wrapper as _async_stream_wrapper
from django_structlog.middlewares.request import logger as _request_logger
from django_structlog.middlewares.request import sync_streaming_content_wrapper as _sync_stream_wrapper
from opentelemetry import trace

if TYPE_CHECKING:
    from django.http import HttpRequest, HttpResponseBase
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import SpanExporter
    from opentelemetry.sdk.trace.sampling import Sampler
    from sentry_sdk.transport import Transport

__all__ = [
    "RequestIdMiddleware",
    "configure_logging",
    "configure_otel",
    "configure_sentry",
    "mask_sensitive",
    "sub_hash",
]

logger = logging.getLogger("django_common.observability")

# --- 로그(D2) ---------------------------------------------------------------------------------------------------------

_HANDLER_MARK = "_django_common_observability_handler"
# 마스킹 이름 — 정규화 뒤 정확히 같은 이름 · 접두 · 접미(닫힌 목록 · 계약 「로그」 행 · T071 r2 Y4 · r3 Z4). 목록 기준은 이
# 스택(Django · gunicorn · OTel · librdkafka · BFF)이 실제로 두는 비밀 이름과 일반 비밀 낱말의 구분자 · camelCase · 접미 변형이다.
# `-key` · `-url` 일반 접미 · sid · 식별자(AWS_ACCESS_KEY_ID) · 인증서 PEM은 넓히지 않는다(partition-key · idempotency-key 같은
# 상관 값이 남는다). 자격을 담는 URL 설정을 새로 두는 과제는 그 이름을 여기 더한다(T072 인계).
_MASKED_NAMES = frozenset(
    {
        # 헤더
        "authorization",
        "proxy-authorization",
        "cookie",
        "set-cookie",
        "x-authentik-signature",
        "x-forwarded-user-sub",
        "x-csrftoken",
        "referer",
        "referrer",
        # 쿠키 · 폼
        "cf-authorization",
        "sessionid",
        "session-key",
        "csrftoken",
        "csrfmiddlewaretoken",
        # Django 인증 폼의 비밀번호 필드 — UserCreationForm · AdminPasswordChangeForm의 password1 · password2, SetPasswordForm ·
        # PasswordChangeForm의 new_password1 · new_password2(old_password는 -password 접미가 지운다 · T071 r5 P2)
        "password1",
        "password2",
        "new-password1",
        "new-password2",
        "jt-session",
        "jt-csrf",
        # META · WSGI environ
        "csrf-cookie",
        "query-string",
        "raw-uri",
        "request-uri",
        # 비밀 이름
        "password",
        "passwd",
        "passphrase",
        "pgpassword",
        "secret",
        "token",
        "api-key",
        "apikey",
        "private-key",
        "secret-key",
        "preshared-key",
        # 자격 URL 설정
        "database-url",
        "database-owner-url",
        "dragonfly-url",
        # 원문 주체(로그는 sub_hash만 싣는다)
        "sub",
    }
)
_MASKED_PREFIXES = (
    "cf-access-",
    # OTel이 request.META에 두는 항목 전부(요청 속성 dict — http.url · http.target에 쿼리 · span · 토큰)
    "opentelemetry-instrumentor-",
)
_MASKED_SUFFIXES = (
    "-password",
    "-passwd",
    "-passphrase",
    "-secret",
    "-token",
    "-api-key",
    "-apikey",
    "-access-key",
    "-private-key",
    "-secret-key",
    "-preshared-key",
    "-key-pem",
)
# 쿠키 접두(`__Host-` · `__Secure-`)의 정규화 꼴 — 앞의 하나만 뗀다.
_COOKIE_PREFIXES = ("--host-", "--secure-")
# camelCase 경계 — 첫 경계는 소문자 · 숫자 뒤 대문자 앞(accessToken → access-Token)이고, 두 경계는 거기에 머리글자 끝(대문자 뒤
# 「대문자 + 소문자」 앞 — APIToken → API-Token · AWSSecretKey → AWS-Secret-Key · T071 r5 P3)을 더한 것이다. 판정은 원래 꼴 · 첫
# 경계만 넣은 꼴 · 두 경계를 넣은 꼴의 세 꼴로 한다(T071 r6 G2 — 두 경계를 한 꼴에만 넣으면 myAPIkey가 my-AP-Ikey로 갈려 남는다).
_CAMEL_FIRST_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])")
_CAMEL_BOUNDARY = re.compile(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])")
_MAX_DEPTH = 16
_PASSTHROUGH_KEYS = frozenset({"exc_info"})
_TRUNCATED = "<truncated>"
_CYCLE = "<cycle>"


def _type_marker(value: object) -> str:
    """JSON으로 못 바꾸는 값 · 키 · 읽을 수 없는 컨테이너의 자리 표시(repr 금지 — 값이 실리지 않는다)."""
    return f"<{type(value).__name__}>"


def _key_text(key: object) -> str | None:
    """판정할 이름 — str은 그대로, bytes · bytearray · memoryview는 latin-1로 푼다(errors="replace") · 풀 수 없는 memoryview(해제됨
    등)와 그 밖의 키는 None(판정 밖)."""
    if isinstance(key, bytes):
        return bytes.decode(key, "latin-1", "replace")
    if isinstance(key, bytearray):
        return bytearray.decode(key, "latin-1", "replace")
    if isinstance(key, memoryview):
        try:
            raw = memoryview.tobytes(key)
        except Exception:  # noqa: BLE001 — 풀 수 없는 memoryview는 판정 밖이다(자리 표시로 남는다)
            return None
        return bytes.decode(raw, "latin-1", "replace")
    if isinstance(key, str):
        return key
    return None


def _normalized(text: str) -> str:
    """소문자 · `_` · `.` → `-` · 앞의 `http-` 하나 제거 · 그다음 쿠키 접두 `--host-` · `--secure-` 하나 제거."""
    name = str.lower(text).replace("_", "-").replace(".", "-").removeprefix("http-")
    for prefix in _COOKIE_PREFIXES:
        if name.startswith(prefix):
            return name[len(prefix) :]
    return name


def _masked_name(name: str) -> bool:
    return name in _MASKED_NAMES or name.startswith(_MASKED_PREFIXES) or name.endswith(_MASKED_SUFFIXES)


def _is_masked(key: object) -> bool:
    """마스킹 이름인가 — 원래 꼴 · camelCase 첫 경계에만 `-`를 넣은 꼴 · 두 경계에 `-`를 넣은 꼴을 각각 정규화해 하나라도 닫힌
    이름 · 접두 · 접미에 맞으면 True(T071 r6 G2)."""
    text = _key_text(key)
    if text is None:
        return False
    if _masked_name(_normalized(text)):
        return True
    if _masked_name(_normalized(_CAMEL_FIRST_BOUNDARY.sub("-", text))):
        return True
    return _masked_name(_normalized(_CAMEL_BOUNDARY.sub("-", text)))


def _is_masked_pair(value: object) -> bool:
    """첫 항목이 마스킹 이름인 길이 2 list · tuple(헤더 쌍 — WSGI 헤더 목록 · list(response.items()) 꼴)인가."""
    if not isinstance(value, (list, tuple)):
        return False
    try:
        return len(value) == 2 and _is_masked(value[0])
    except Exception:  # noqa: BLE001 — 읽을 수 없는 시퀀스는 쌍이 아니다(그 값은 재귀가 자리 표시로 바꾼다)
        return False


def _safe_key(key: object) -> object:
    """JSON 객체 키로 쓸 수 있는 값(str · int · float · bool · None)은 그대로, 아니면 `<타입 이름>`."""
    if key is None or isinstance(key, (str, int, float)):
        return key
    return _type_marker(key)


def _masked(value: object, depth: int, active: set[int]) -> object:
    if isinstance(value, Mapping):
        return _masked_mapping(value, depth, active)
    if isinstance(value, (list, tuple)):
        return _masked_sequence(value, depth, active)
    return value


def _masked_mapping(value: Mapping[Any, Any], depth: int, active: set[int]) -> object:
    if depth > _MAX_DEPTH:
        return _TRUNCATED
    marker = id(value)
    if marker in active:
        return _CYCLE
    active.add(marker)
    try:
        result: dict[Any, Any] = {}
        for key, item in list(value.items()):
            if _is_masked(key) or _is_masked_pair(item):
                continue
            result[_safe_key(key)] = _masked(item, depth + 1, active)
        return result
    except Exception:  # noqa: BLE001 — 어떤 값에도 예외를 내지 않는다(읽을 수 없는 Mapping은 자리 표시)
        return _type_marker(value)
    finally:
        active.discard(marker)


def _masked_sequence(value: list[Any] | tuple[Any, ...], depth: int, active: set[int]) -> object:
    if depth > _MAX_DEPTH:
        return _TRUNCATED
    marker = id(value)
    if marker in active:
        return _CYCLE
    active.add(marker)
    try:
        return [_masked(item, depth + 1, active) for item in list(value) if not _is_masked_pair(item)]
    except Exception:  # noqa: BLE001 — 어떤 값에도 예외를 내지 않는다
        return _type_marker(value)
    finally:
        active.discard(marker)


def mask_sensitive(logger: Any, method_name: str, event_dict: Mapping[Any, Any]) -> dict[Any, Any]:
    """structlog processor — 민감 키를 키째 지우고 Mapping · list · tuple을 재귀한다(계약 「로그」 행 · D2). 헤더 쌍은 시퀀스
    원소면 원소째, Mapping 값이면 키째 뺀다. 새 dict를 돌려준다."""
    active = {id(event_dict)}
    result: dict[Any, Any] = {}
    for key, value in list(event_dict.items()):
        if _is_masked(key):
            continue
        if key in _PASSTHROUGH_KEYS:
            result[key] = value
            continue
        if _is_masked_pair(value):
            continue
        result[_safe_key(key)] = _masked(value, 1, active)
    return result


def _json_default(value: object) -> object:
    """JSON 렌더 폴백(fail-closed · repr 금지): UUID · Decimal → str · 날짜 · 시각 → isoformat · 그 밖 → `<타입 이름>`."""
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, (_dt.datetime, _dt.date, _dt.time)):
        return value.isoformat()
    if isinstance(value, decimal.Decimal):
        return str(value)
    return _type_marker(value)


def _add_trace_ids(logger: Any, method_name: str, event_dict: dict[str, Any]) -> dict[str, Any]:
    """현재 span이 기록 중일 때만 trace_id(32 hex) · span_id(16 hex) — 내보낸 span과 1:1(비샘플 span id는 Tempo에 없다)."""
    span = trace.get_current_span()
    if span.is_recording():
        context = span.get_span_context()
        event_dict["trace_id"] = format(context.trace_id, "032x")
        event_dict["span_id"] = format(context.span_id, "016x")
    return event_dict


_EMIT_FAILED = "log_emit_failed"


class _JsonLineHandler(logging.StreamHandler):  # type: ignore[type-arg]
    """표식 루트 핸들러(D2 · T071 r2 Y4) — 쓰기 · 렌더가 실패하면 레코드 값 없이 고정 JSON 한 줄만 부를 때의 sys.stderr에 쓴다.

    표준 handleError는 「--- Logging error ---」 · 트레이스백 · `Message: %r` · `Arguments:`를 찍어 repr 금지를 우회한다(값이 실린다).
    그 쓰기도 실패하면 버린다(재귀 0 · logging.raiseExceptions와 무관).
    """

    def handleError(self, record: logging.LogRecord) -> None:
        try:
            error = sys.exc_info()[1]
            line = json.dumps(
                {
                    "ts": _dt.datetime.now(_dt.UTC).isoformat().replace("+00:00", "Z"),
                    "level": "error",
                    "logger": logger.name,
                    "event": _EMIT_FAILED,
                    "error": type(error).__name__ if error is not None else "unknown",
                }
            )
            stream = sys.stderr
            stream.write(line + "\n")
            stream.flush()
        except Exception:  # noqa: BLE001, S110 — 실패 신호 줄도 못 쓰면 버린다(값 출력 · 재귀 금지)
            return


def configure_logging(*, stream: TextIO | None = None, level: str = "INFO") -> None:
    """structlog → stdlib 한 경로 · 루트 핸들러 하나(표식) · 한 줄 = JSON 객체 하나(D2). 다시 부르면 자기 핸들러만 바꾼다."""
    if not isinstance(level, str) or level.upper() not in logging.getLevelNamesMapping():
        raise ValueError("configure_logging: level은 logging 수준 이름이어야 한다")
    shared: list[Any] = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.stdlib.add_logger_name,
        structlog.processors.TimeStamper(fmt="iso", utc=True, key="ts"),
        _add_trace_ids,
    ]
    structlog.configure(
        processors=[
            *shared,
            mask_sensitive,
            structlog.processors.format_exc_info,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=False,
    )
    formatter = structlog.stdlib.ProcessorFormatter(
        foreign_pre_chain=[*shared, structlog.processors.format_exc_info],
        processors=[
            structlog.stdlib.ProcessorFormatter.remove_processors_meta,
            mask_sensitive,
            structlog.processors.JSONRenderer(default=_json_default),
        ],
    )
    handler = _JsonLineHandler(stream if stream is not None else sys.stdout)
    setattr(handler, _HANDLER_MARK, True)
    handler.setFormatter(formatter)
    root = logging.getLogger()
    for existing in list(root.handlers):
        if getattr(existing, _HANDLER_MARK, False):
            existing.flush()
            root.removeHandler(existing)
            existing.close()
    root.addHandler(handler)
    root.setLevel(level.upper())


# --- sub_hash(D4) ---------------------------------------------------------------------------------------------------

_SUB_HASH_SALT = "django_common.observability.sub_hash"
_SUB_HASH_HEX = 32


def sub_hash(sub: str) -> str:
    """요청 주체 sub의 상관용 해시 — SECRET_KEY 파생 salted_hmac SHA-256 앞 32 hex(D4 · 로그와 span이 같이 쓴다)."""
    if not isinstance(sub, str):
        raise TypeError("sub_hash: sub은 str이어야 한다")
    if not sub:
        raise ValueError("sub_hash: sub은 비지 않은 str이어야 한다")
    return salted_hmac(_SUB_HASH_SALT, sub, algorithm="sha256").hexdigest()[:_SUB_HASH_HEX]


def _request_sub_hash(request: object) -> str | None:
    """request.auth_claims["sub"]가 비지 않은 str일 때만 sub_hash(인증 실패 · 면제 경로에는 속성이 없다)."""
    claims = getattr(request, "auth_claims", None)
    if not isinstance(claims, Mapping):
        return None
    try:
        sub = claims.get("sub")
    except Exception:  # noqa: BLE001 — 꼴이 이상한 Mapping은 sub 없음으로 본다
        return None
    if not isinstance(sub, str) or not sub:
        return None
    return sub_hash(sub)


def _request_tenant(request: object) -> str | None:
    tenant = getattr(request, "tenant_id", None)
    return str(tenant) if isinstance(tenant, uuid.UUID) else None


# --- 요청 로그 미들웨어(D3) -------------------------------------------------------------------------------------------

_REQUEST_ID_HEADER = "X-Request-ID"
_REQUEST_ID = re.compile(r"[A-Za-z0-9._:-]{1,128}")  # fullmatch로 쓴다 — `$`는 끝 줄바꿈 앞에서도 맞는다
_REQUEST_ID_ATTR = "_django_common_request_id"
_STARTED_ATTR = "_django_common_request_started"
_PROBLEM_CONTENT_TYPE = "application/problem+json"
_PROBLEM_TYPE = re.compile(r"https://joshuatech\.dev/problems/([a-z][a-z0-9-]*)")  # fullmatch
_PROBLEM_MAX_BYTES = 64 * 1024


def _request_id_for(request: HttpRequest) -> str:
    """상류 X-Request-ID가 계약 꼴이면 그대로, 아니면(없음 · 형식 밖) 새 uuid4(DJANGO_STRUCTLOG_TRUST_UPSTREAM_REQUEST_ID와 무관)."""
    upstream = request.headers.get(_REQUEST_ID_HEADER)
    if isinstance(upstream, str) and _REQUEST_ID.fullmatch(upstream):
        return upstream
    return str(uuid.uuid4())


def _problem_slug(response: HttpResponseBase) -> str | None:
    """problem+json 응답 본문 type의 슬러그(`https://joshuatech.dev/problems/<slug>`) — 스트리밍 · 다른 꼴 · 읽기 실패는 None."""
    if getattr(response, "streaming", False):
        return None
    content_type = response.get("Content-Type")
    if not isinstance(content_type, str):
        return None
    if content_type.split(";", 1)[0].strip().lower() != _PROBLEM_CONTENT_TYPE:
        return None
    try:
        content = response.content  # type: ignore[attr-defined]
        if len(content) > _PROBLEM_MAX_BYTES:
            return None
        body = json.loads(content)
    except (AttributeError, TypeError, ValueError, RecursionError):
        return None
    kind = body.get("type") if isinstance(body, dict) else None
    match = _PROBLEM_TYPE.fullmatch(kind) if isinstance(kind, str) else None
    return match.group(1) if match is not None else None


class RequestIdMiddleware(RequestMiddleware):
    """django-structlog RequestMiddleware 하위 — 요청 로그와 X-Request-ID(D3 · 계약 「로그」 행).

    request_started · request_finished · request_failed의 request는 `<METHOD> <request.path>`(쿼리 없음)다. ip · user_id를 묶지
    않는다(request.user에 접근하지 않는다). 응답 헤더 X-Request-ID는 성공 · 실패 두 갈래 모두 로그 값과 같다.
    """

    @staticmethod
    def format_request(request: HttpRequest) -> str:
        return f"{request.method} {request.path}"

    @staticmethod
    def bind_user_id(request: HttpRequest) -> None:
        """user_id를 묶지 않는다 — request.user 접근(AuthenticationMiddleware면 세션 · 사용자 DB 조회)을 만들지 않는다."""
        return None

    @classmethod
    def bind_ip(cls, request: HttpRequest) -> None:
        """ip를 묶지 않는다 — X-Forwarded-For 왼쪽 값은 클라이언트가 조작할 수 있고 개인정보다."""
        return None

    def prepare(self, request: HttpRequest) -> None:
        structlog.contextvars.clear_contextvars()
        request_id = _request_id_for(request)
        setattr(request, _REQUEST_ID_ATTR, request_id)
        setattr(request, _STARTED_ATTR, time.perf_counter())
        structlog.contextvars.bind_contextvars(request_id=request_id)
        log_kwargs: dict[str, Any] = {
            "request": self.format_request(request),
            "user_agent": request.META.get("HTTP_USER_AGENT"),
        }
        structlog_signals.bind_extra_request_metadata.send(
            sender=self.__class__, request=request, logger=_request_logger, log_kwargs=log_kwargs
        )
        _request_logger.log(structlog_settings.STATUS_START_LOG_LEVEL, "request_started", **log_kwargs)

    def handle_response(self, request: HttpRequest, response: HttpResponseBase) -> None:  # type: ignore[override]
        if not hasattr(request, "_raised_exception"):
            context = structlog.contextvars.get_merged_contextvars(_request_logger)
            log_kwargs = self._finished_fields(request, response)
            structlog_signals.bind_extra_request_finished_metadata.send(
                sender=self.__class__, request=request, logger=_request_logger, response=response, log_kwargs=log_kwargs
            )
            _request_logger.log(
                self._log_level_for_status_code(response.status_code), "request_finished", **log_kwargs
            )
            if isinstance(response, StreamingHttpResponse):
                streaming_content = response.streaming_content
                if response.is_async:
                    response.streaming_content = _async_stream_wrapper(streaming_content, context)  # type: ignore[arg-type]
                else:
                    response.streaming_content = _sync_stream_wrapper(streaming_content, context)  # type: ignore[arg-type]
        else:
            exception = request._raised_exception  # type: ignore[attr-defined]
            delattr(request, "_raised_exception")
            structlog_signals.update_failure_response.send(
                sender=self.__class__, request=request, response=response, logger=_request_logger, exception=exception
            )
        request_id = getattr(request, _REQUEST_ID_ATTR, None)
        if isinstance(request_id, str):
            response[_REQUEST_ID_HEADER] = request_id
        structlog.contextvars.clear_contextvars()

    def _finished_fields(self, request: HttpRequest, response: HttpResponseBase) -> dict[str, Any]:
        fields: dict[str, Any] = {"code": response.status_code, "request": self.format_request(request)}
        route = getattr(getattr(request, "resolver_match", None), "route", None)
        if isinstance(route, str):
            fields["route"] = route
        started = getattr(request, _STARTED_ATTR, None)
        if isinstance(started, float):
            fields["duration_ms"] = round((time.perf_counter() - started) * 1000, 1)
        tenant = _request_tenant(request)
        if tenant is not None:
            fields["tenant_id"] = tenant
        hashed = _request_sub_hash(request)
        if hashed is not None:
            fields["sub_hash"] = hashed
        slug = _problem_slug(response)
        if slug is not None:
            fields["problem"] = slug
        return fields


# --- 트레이스(D5) ---------------------------------------------------------------------------------------------------

_DEFAULT_EXCLUDED_URLS = r"^https?://[^/]+/healthz$,^https?://[^/]+/ready$,^https?://[^/]+/health$"
_DEFAULT_SAMPLE_RATIO = 0.1
_SAMPLERS = frozenset(
    {"always_on", "always_off", "parentbased_always_on", "parentbased_always_off", "traceidratio", "parentbased_traceidratio"}
)
_RATIO_SAMPLERS = frozenset({"traceidratio", "parentbased_traceidratio"})
_SAMPLER_ENV = "OTEL_TRACES_SAMPLER"
_SAMPLER_ARG_ENV = "OTEL_TRACES_SAMPLER_ARG"
_ENDPOINT_ENVS = ("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "OTEL_EXPORTER_OTLP_ENDPOINT")
_CAPTURE_HEADER_ENVS = (
    "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST",
    "OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE",
)
_TRACED_REQUEST_ATTRS_ENV = "OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS"
_SEMCONV_ENV = "OTEL_SEMCONV_STABILITY_OPT_IN"
_PROPAGATORS_ENV = "OTEL_PROPAGATORS"
# 받는 propagator 이름 — OTel이 받는 none · sentry(sentry-sdk가 등록)보다 일부러 좁다(T071 r5 P1).
_PROPAGATOR_NAMES = frozenset({"tracecontext", "baggage"})
_CAPTURE_ALL_METHODS_ENV = "OTEL_PYTHON_INSTRUMENTATION_HTTP_CAPTURE_ALL_METHODS"
# OTLP 헤더 env — 이 프로세스가 읽는 둘(span 내보내기 · TRACES가 비면 일반 값 · T071 r5 P5).
_OTLP_HEADER_ENVS = ("OTEL_EXPORTER_OTLP_HEADERS", "OTEL_EXPORTER_OTLP_TRACES_HEADERS")
# OTLP mTLS 클라이언트 키 · 인증서 env — 이 프로세스가 읽는 넷(span 내보내기 · TRACES가 비면 일반 값 · T071 r6 G1 — 키 env가 없으면
# OTel은 인증서 값만 requests cert로 넘기므로 키를 함께 담은 PEM 한 파일이 자격이 된다).
_OTLP_MTLS_ENVS = (
    "OTEL_EXPORTER_OTLP_CLIENT_KEY",
    "OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY",
    "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE",
    "OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE",
)
# OTLP 엔드포인트의 닫힌 꼴(fullmatch — T071 r6 G1): scheme://host[:port][/path] — scheme http · https(ASCII 대소문자 무시) · host ASCII
# 영문자 · 숫자 · `.` · `-` · port ASCII 십진 1–5자리(값 1–65535는 _otlp_endpoint_form이 본다) · path `/`로 시작하는 ASCII 영문자 ·
# 숫자 · `.` · `_` · `~` · `/` · `-`. 사용자 정보 · 쿼리 · 조각 · 퍼센트 인코딩 · 공백 · 역슬래시 · IPv6 리터럴은 꼴 밖이다(끝 줄바꿈도
# — fullmatch). 글자 부류는 ASCII로 적는다(\d · \w는 유니코드 숫자 · 글자를 받는다).
# 스킴은 (?ai:)로 ASCII 대소문자만 무시한다(T071 r7 S1) — `(?i)`만 쓰면 유니코드 대소문자 접기로 `ſ`(U+017F)를 `s`로 받는다.
_OTLP_ENDPOINT = re.compile(r"(?ai:https?)://[A-Za-z0-9.-]+(?::([0-9]{1,5}))?(?:/[A-Za-z0-9._~/-]*)?")
_URL_ATTRIBUTES = ("http.url", "http.target", "url.full")
_POD_NAME = re.compile(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*")  # fullmatch — 봉투 source 꼴(kebab-case)


def _pod_name() -> str:
    value = getattr(settings, "OUTBOX_SOURCE", None)
    if not isinstance(value, str) or _POD_NAME.fullmatch(value) is None:
        raise ImproperlyConfigured("OUTBOX_SOURCE는 pod 이름(kebab-case)이어야 한다") from None
    return value


def _otlp_endpoint_form(value: str) -> bool:
    """OTLP 엔드포인트 env 값이 닫힌 꼴인가 — _OTLP_ENDPOINT fullmatch이고 포트가 있으면 1–65535(T071 r6 G1)."""
    match = _OTLP_ENDPOINT.fullmatch(value)
    if match is None:
        return False
    port = match.group(1)
    return port is None or 1 <= int(port) <= 65535


def _check_otel_env() -> None:
    """거부 env 열일곱(D5 · T071 r2 Y1 · r3 Z1 · r5 P5 · r6 G1 — 기준은 계약 「트레이스 · Sentry」 행 · 엔드포인트 env 둘은 닫힌
    꼴 밖 값만) — 값은 메시지에 싣지 않는다. configure_otel은 OTel을 import하기 전에, span_exporter 인자와 무관하게 부른다(모르는
    propagator 이름이면 OTel import가 값을 실은 ValueError로 끝난다).

    OTEL_PROPAGATORS의 해석 규칙(쉼표 · str.strip · 대소문자 · 빈 토큰)은 OTel이 import 때 쓰는 해석(opentelemetry.propagate.
    _load_propagators)과 같고, 받는 이름은 더 좁다(T071 r4 Q1 · r5 P1 — OTel이 받는 none · sentry도 거부한다): 원문이 비면(없음 ·
    빈 값) 기본이다. 아니면 쉼표 토큰마다 앞뒤 공백(str.strip이 떼는 것 전부 — 탭 · 유니코드 공백 포함)을 떼고 대소문자 그대로
    tracecontext · baggage와 견준다 — 공백뿐인 값 · 빈 토큰 · 대소문자가 다른 토큰은 OTel import가 그 값을 실은 ValueError로
    끝내므로 여기서 먼저 거부한다. OTLP 헤더 env 둘은 원문이 비지 않으면(공백뿐인 값 포함) 거부한다(T071 r5 P5 — pod는 자격 없이
    클러스터 안 수집기로 보낸다 · 꼴이 틀린 쌍은 OTel이 원문을 WARNING 로그에 싣는다).

    mTLS 클라이언트 키 · 인증서 env 넷도 원문이 비지 않으면(공백뿐인 값 포함) 거부하고, 엔드포인트 env 둘은 비지 않으면 닫힌
    꼴(_otlp_endpoint_form)만 받는다 — 각 env를 따로 본다(TRACES가 있어도 일반 env가 꼴 밖이면 거부 · 빈 값은 없음과 같다 · T071
    r6 G1). 기준 다섯째 절은 「이 프로세스의 span 내보내기에 OTLP 자격을 싣는 env」(헤더 · mTLS 클라이언트 키 · 인증서 · 엔드포인트의
    사용자 정보 · 쿼리)다 — 자격은 수집기가 갖는다(requests는 URL 사용자 정보를 Basic 인증으로 보내고, OTel은 쓸 수 없는 엔드포인트
    URL · 실패한 내보내기의 URL과 쿼리 · 경로가 아닌 키 · 인증서 값을 그대로 로그에 싣는다)."""
    tokens = [token.strip().lower() for token in os.environ.get("OTEL_SEMCONV_STABILITY_OPT_IN", "").split(",")]
    if any(token == "http" or token.startswith("http/") for token in tokens):
        raise ImproperlyConfigured("OTEL_SEMCONV_STABILITY_OPT_IN에 http를 둘 수 없다(url.query 속성을 지울 수 없다)")
    for name in _CAPTURE_HEADER_ENVS:
        if os.environ.get(name, "").strip():
            raise ImproperlyConfigured(f"{name}를 둘 수 없다(요청 · 응답 헤더를 span 속성으로 싣는다)")
    if os.environ.get(_TRACED_REQUEST_ATTRS_ENV, "").strip():
        raise ImproperlyConfigured(f"{_TRACED_REQUEST_ATTRS_ENV}를 둘 수 없다(요청 객체 속성을 str()로 span 속성에 싣는다)")
    if "OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION" in os.environ:
        raise ImproperlyConfigured("OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION을 둘 수 없다(계측 미들웨어는 가장 바깥이어야 한다)")
    if os.environ.get("OTEL_PYTHON_DJANGO_INSTRUMENT", "").strip().lower() == "false":
        raise ImproperlyConfigured("OTEL_PYTHON_DJANGO_INSTRUMENT=false는 받지 않는다(계측이 조용히 꺼진다)")
    if os.environ.get("OTEL_SDK_DISABLED", "").strip().lower() == "true":
        raise ImproperlyConfigured(
            "OTEL_SDK_DISABLED=true는 받지 않는다(span 0이 기동 신호 없이 이어진다 — 샘플링을 끄려면 OTEL_TRACES_SAMPLER=always_off)"
        )
    propagators = os.environ.get(_PROPAGATORS_ENV, "")
    if propagators:
        names = [token.strip() for token in propagators.split(",")]
        if not set(names) <= _PROPAGATOR_NAMES or "tracecontext" not in names:
            raise ImproperlyConfigured(
                f"{_PROPAGATORS_ENV}는 tracecontext를 포함해 tracecontext · baggage만 둘 수 있다(상류 traceparent를 이어받는다)"
            )
    if os.environ.get(_CAPTURE_ALL_METHODS_ENV, ""):
        raise ImproperlyConfigured(f"{_CAPTURE_ALL_METHODS_ENV}를 둘 수 없다(클라이언트 메서드 원문을 span 이름 · 속성에 싣는다)")
    for name in _OTLP_HEADER_ENVS:
        if os.environ.get(name, ""):
            raise ImproperlyConfigured(f"{name}를 둘 수 없다(자격은 수집기가 갖는다)")
    for name in _OTLP_MTLS_ENVS:
        if os.environ.get(name, ""):
            raise ImproperlyConfigured(f"{name}를 둘 수 없다(mTLS 자격 — 자격은 수집기가 갖는다)") from None
    for name in _ENDPOINT_ENVS:
        value = os.environ.get(name, "")
        if value and not _otlp_endpoint_form(value):
            raise ImproperlyConfigured(
                f"{name}는 http(s)://host[:port][/path] 꼴이어야 한다(host · path는 ASCII · 포트 1–65535 — 사용자 정보 · 쿼리 · "
                "조각 · 퍼센트 인코딩 · 공백 · IPv6 리터럴 없이 · 자격은 수집기가 갖는다)"
            ) from None


def _traced_request_attrs_frozen() -> bool:
    """계측 미들웨어 클래스의 요청 속성 목록(import 때 env로 굳는다)에 공백 아닌 항목이 있는가 — list가 아니거나 모듈 · 속성이
    없어도(판 올림) True. 공백 항목만인 list(빈 list 포함)는 싣는 것이 없다(OTel은 공백 env를 [""]로 굳히고 getattr(request, "")는
    None이다)."""
    try:
        from opentelemetry.instrumentation.django.middleware.otel_middleware import _DjangoMiddleware
    except ImportError:
        return True
    value = getattr(_DjangoMiddleware, "_traced_request_attrs", None)
    if not isinstance(value, list):
        return True
    return not all(isinstance(item, str) and not str.strip(item) for item in value)


def _propagator_carries_traceparent() -> bool:
    """전역 propagator(import 때 OTEL_PROPAGATORS로 굳는다 · 공개 API)의 fields에 traceparent가 있는가 — 읽다 예외가 나면 False."""
    try:
        from opentelemetry import propagate

        return "traceparent" in propagate.get_global_textmap().fields
    except Exception:  # noqa: BLE001 — 확인할 수 없으면 거부한다(fail-closed)
        return False


def _semconv_mode_default() -> bool:
    """계측 미들웨어 클래스의 semconv HTTP 모드(instrument()가 프로세스에 한 번 굳는 상태를 옮겨 둔다)가 기본인가 — 모듈 · 속성 ·
    이름(_StabilityMode.DEFAULT) 가운데 하나라도 없으면(판 올림) 예외 없이 False(T071 r4 Q3)."""
    try:
        from opentelemetry.instrumentation._semconv import _StabilityMode
        from opentelemetry.instrumentation.django.middleware.otel_middleware import _DjangoMiddleware
    except ImportError:
        return False
    default = getattr(_StabilityMode, "DEFAULT", None)
    if default is None:
        return False
    return getattr(_DjangoMiddleware, "_sem_conv_opt_in_mode", None) is default


_FROZEN_MESSAGES = {
    _TRACED_REQUEST_ATTRS_ENV: "계측 미들웨어의 요청 속성 목록이 import 때 공백 아닌 항목으로 굳었거나 확인할 수 없다(판 올림)",
    _PROPAGATORS_ENV: "전역 propagator(import 때 굳는다)에 traceparent가 없거나 확인할 수 없다(상류 traceparent를 이어받지 못한다)",
    _SEMCONV_ENV: "계측의 semconv HTTP 모드(프로세스에 한 번 굳는다)가 기본이 아니거나 확인할 수 없다(url.query를 지울 수 없다)",
}


def _frozen_state_violation() -> str | None:
    """instrument() 뒤 import 때 굳은 OTel 상태 확인 (a) 요청 속성 목록 · (b) 전역 propagator · (c) semconv 모드 — 어긋난 첫 env
    이름(없으면 None)."""
    if _traced_request_attrs_frozen():
        return _TRACED_REQUEST_ATTRS_ENV
    if not _propagator_carries_traceparent():
        return _PROPAGATORS_ENV
    if not _semconv_mode_default():
        return _SEMCONV_ENV
    return None


def _otel_sampler() -> Sampler | None:
    """샘플러 env가 없거나 비면 계약 기본 ParentBased(TraceIdRatioBased(0.1)) · 있으면 검증만 하고 None(SDK가 env로 고른다)."""
    from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased

    name = os.environ.get(_SAMPLER_ENV, "")
    if not name:
        return ParentBased(TraceIdRatioBased(_DEFAULT_SAMPLE_RATIO))
    if name.lower() not in _SAMPLERS:
        raise ImproperlyConfigured(f"{_SAMPLER_ENV}는 OTel SDK 샘플러 이름이어야 한다")
    if name.lower() in _RATIO_SAMPLERS:
        raw = os.environ.get(_SAMPLER_ARG_ENV)
        try:
            ratio = float(raw) if raw is not None else math.nan
        except ValueError:
            ratio = math.nan
        if not 0.0 <= ratio <= 1.0:
            raise ImproperlyConfigured(f"{_SAMPLER_ARG_ENV}는 [0, 1] 범위의 수여야 한다(비율 샘플러)")
    return None


def _otlp_endpoint() -> str | None:
    """OTLP 엔드포인트 env 가운데 비지 않은 첫 값(빈 값 = 없음) — 꼴은 _check_otel_env가 이미 봤다(T071 r6 G1)."""
    for name in _ENDPOINT_ENVS:
        value = os.environ.get(name, "")
        if value:
            return value
    return None


def _otel_response_hook(span: Any, request: Any, response: Any) -> None:
    """기록 중 span에만 — URL 속성에서 쿼리를 떼고 tenant_id · sub_hash를 더한다(예외를 내지 않는다)."""
    try:
        if not span.is_recording():
            return
        attributes = getattr(span, "attributes", None) or {}
        for key in _URL_ATTRIBUTES:
            value = attributes.get(key)
            if isinstance(value, str) and "?" in value:
                span.set_attribute(key, value.split("?", 1)[0])
        tenant = _request_tenant(request)
        if tenant is not None:
            span.set_attribute("tenant_id", tenant)
        hashed = _request_sub_hash(request)
        if hashed is not None:
            span.set_attribute("sub_hash", hashed)
    except Exception:  # noqa: BLE001, S110 — 훅은 요청을 깨지 않는다(속성 하나를 못 다는 것이 500보다 낫다)
        return


def configure_otel(
    *, span_exporter: SpanExporter | None = None, excluded_urls: str | None = None
) -> TracerProvider:
    """DjangoInstrumentor 계측(D5) — 새 TracerProvider를 돌려준다. 설정 오류는 이름만 실은 ImproperlyConfigured. env 검사는 OTel
    import보다 먼저, span_exporter 인자와 무관하게 한다(T071 r3 Z1 · r6 G1 — 엔드포인트 꼴 포함)."""
    _check_otel_env()
    from opentelemetry.instrumentation.django import DjangoInstrumentor
    from opentelemetry.metrics import NoOpMeterProvider
    from opentelemetry.sdk.resources import SERVICE_NAME, SERVICE_VERSION, OTELResourceDetector, Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor, SimpleSpanProcessor

    sampler = _otel_sampler()
    endpoint = _otlp_endpoint() if span_exporter is None else None
    version = getattr(settings, "APP_VERSION", None)
    if not isinstance(version, str) or not version:
        raise ImproperlyConfigured("APP_VERSION은 비지 않은 str이어야 한다") from None
    resource = Resource.create({SERVICE_NAME: _pod_name(), SERVICE_VERSION: version}).merge(
        OTELResourceDetector().detect()
    )
    provider = TracerProvider(resource=resource, sampler=sampler)
    if span_exporter is not None:
        provider.add_span_processor(SimpleSpanProcessor(span_exporter))
    elif endpoint is not None:
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    else:
        logger.warning("otel_exporter_disabled")
    instrumentor = DjangoInstrumentor()
    if instrumentor.is_instrumented_by_opentelemetry:
        instrumentor.uninstrument()
    instrumentor.instrument(
        tracer_provider=provider,
        # Django 계측의 OTel 지표는 끈다(web 지표는 prometheus_client — 전역 MeterProvider가 생겨도 http.target 원문이 지표 라벨에
        # 실리지 않게 · T071 r3 Z1).
        meter_provider=NoOpMeterProvider(),
        response_hook=_otel_response_hook,
        excluded_urls=excluded_urls or _DEFAULT_EXCLUDED_URLS,
    )
    middleware = getattr(settings, "MIDDLEWARE", None) or ()
    inserted = (
        instrumentor.is_instrumented_by_opentelemetry and DjangoInstrumentor._opentelemetry_middleware in middleware
    )
    frozen = _frozen_state_violation() if inserted else None
    if not inserted or frozen is not None:
        if instrumentor.is_instrumented_by_opentelemetry:
            instrumentor.uninstrument()
        provider.shutdown()
        if frozen is None:
            raise ImproperlyConfigured("configure_otel: DjangoInstrumentor가 MIDDLEWARE에 계측 미들웨어를 넣지 못했다")
        raise ImproperlyConfigured(f"{frozen}: {_FROZEN_MESSAGES[frozen]}")
    if isinstance(trace.get_tracer_provider(), trace.ProxyTracerProvider):
        trace.set_tracer_provider(provider)
    return provider


# --- 오류 보고(D7) ----------------------------------------------------------------------------------------------------

_SENTRY_ENVS = frozenset({"dev", "prod", "test"})
_GIT_SHA = re.compile(r"[0-9a-f]{7,64}")  # fullmatch — git 커밋 해시(이미지 라벨 revision)
# x-request-id · traceparent는 넣지 않는다 — 검증된 값은 태그 request_id · trace_id와 contexts.trace(기록 중 span일 때만)가 싣고,
# 꼴 밖이라 버린 상류 값 · 비샘플 요청의 클라이언트 id는 이벤트에 남지 않는다(T071 r2 Y3 · r3 Z2).
_SENTRY_HEADER_ALLOWLIST = frozenset({"host", "user-agent", "accept", "content-type", "content-length"})
_SENTRY_REQUEST_KEYS = ("url", "method", "headers", "env")
_SENTRY_ENV_KEYS = ("SERVER_NAME", "SERVER_PORT")


def _git_sha() -> str:
    value = getattr(settings, "APP_GIT_SHA", None)
    if not isinstance(value, str) or _GIT_SHA.fullmatch(value) is None:
        raise ImproperlyConfigured("APP_GIT_SHA는 git 커밋 해시(소문자 hex 7–64자)여야 한다") from None
    return value


def _scrub_request(request: dict[str, Any]) -> dict[str, Any]:
    """요청 정보 — 허용 키(url · method · headers · env)만 · 헤더는 허용 목록(소문자 비교) · env는 SERVER_NAME · SERVER_PORT ·
    url은 `?` · `#` 앞까지."""
    scrubbed: dict[str, Any] = {key: request[key] for key in _SENTRY_REQUEST_KEYS if key in request}
    headers = scrubbed.get("headers")
    if isinstance(headers, Mapping):
        scrubbed["headers"] = {
            name: value
            for name, value in headers.items()
            if isinstance(name, str) and name.lower() in _SENTRY_HEADER_ALLOWLIST
        }
    else:
        scrubbed.pop("headers", None)
    env = scrubbed.get("env")
    if isinstance(env, Mapping):
        scrubbed["env"] = {key: env[key] for key in _SENTRY_ENV_KEYS if key in env}
    else:
        scrubbed.pop("env", None)
    url = scrubbed.get("url")
    if isinstance(url, str):
        scrubbed["url"] = url.split("?", 1)[0].split("#", 1)[0]
    else:
        scrubbed.pop("url", None)
    return scrubbed


def _drop_frame_vars(node: object, depth: int = 0) -> None:
    """이벤트 어디든 frames 목록의 프레임에서 vars를 지운다(심층 방어 — include_local_variables=False가 1차다)."""
    if depth > _MAX_DEPTH:
        return
    if isinstance(node, dict):
        frames = node.get("frames")
        if isinstance(frames, list):
            for frame in frames:
                if isinstance(frame, dict):
                    frame.pop("vars", None)
        for value in node.values():
            _drop_frame_vars(value, depth + 1)
    elif isinstance(node, list):
        for value in node:
            _drop_frame_vars(value, depth + 1)


def _scrub_trace_context(event: dict[str, Any]) -> None:
    """contexts.trace(T071 r2 Y3) — 클라이언트 sentry-trace · baggage가 정한 값을 남기지 않는다: 기록 중 OTel span이면 trace_id ·
    span_id를 그 값으로 바꾸고 parent_span_id를 지우며, 아니면 trace 문맥을 지운다. dynamic_sampling_context는 언제나 지운다(SDK는
    before_send 뒤 그것을 꺼내 envelope 머리 trace로 보낸다)."""
    contexts = event.get("contexts")
    if not isinstance(contexts, dict):
        return
    trace_context = contexts.get("trace")
    span = trace.get_current_span()
    if isinstance(trace_context, dict) and span.is_recording():
        trace_context.pop("dynamic_sampling_context", None)
        span_context = span.get_span_context()
        trace_context["trace_id"] = format(span_context.trace_id, "032x")
        trace_context["span_id"] = format(span_context.span_id, "016x")
        trace_context.pop("parent_span_id", None)
    else:
        contexts.pop("trace", None)


def _scrub_event(event: dict[str, Any]) -> dict[str, Any]:
    """직렬화된 이벤트 정리(D7 before_send) — 예외를 내면 SDK가 이벤트를 버린다(fail-closed)."""
    request = event.get("request")
    if isinstance(request, dict):
        event["request"] = _scrub_request(request)
    else:
        event.pop("request", None)
    event.pop("user", None)
    meta = event.get("_meta")
    if isinstance(meta, dict):
        meta.pop("request", None)
        meta.pop("user", None)
    _drop_frame_vars(event)
    _scrub_trace_context(event)
    scrubbed = mask_sensitive(None, "sentry", event)
    tags = scrubbed.get("tags")
    tags = dict(tags) if isinstance(tags, dict) else {}
    request_id = structlog.contextvars.get_contextvars().get("request_id")
    if isinstance(request_id, str):
        tags["request_id"] = request_id
    span = trace.get_current_span()
    if span.is_recording():
        tags["trace_id"] = format(span.get_span_context().trace_id, "032x")
    if tags:
        scrubbed["tags"] = tags
    return scrubbed


def _sentry_before_send(event: dict[str, Any], hint: dict[str, Any]) -> dict[str, Any] | None:
    return _scrub_event(event)


def configure_sentry(*, transport: Transport | None = None) -> bool:
    """오류 보고 — 예외 포착만(D7). SENTRY_DSN이 비었거나 없으면 init하지 않고 False · 초기화했으면 True. sentry_sdk.init이
    Exception을 내면 그 예외 클래스 이름만 실은 ImproperlyConfigured(연쇄 예외 없음 · BaseException은 그대로 올린다 — T071 r8 L2:
    sentry-sdk가 init 때 스스로 읽는 프록시 env의 사용자 정보가 꼴이 틀리면 urllib3 예외 메시지째 기동 traceback에 실린다)."""
    dsn = getattr(settings, "SENTRY_DSN", None)
    if dsn is None or dsn == "":
        return False
    if not isinstance(dsn, str):
        raise ImproperlyConfigured("SENTRY_DSN은 str이어야 한다(빈 값 = 끔)") from None
    environment = getattr(settings, "ENV", None)
    if not isinstance(environment, str) or environment not in _SENTRY_ENVS:
        raise ImproperlyConfigured("ENV는 dev · prod · test 가운데 하나여야 한다(SENTRY_DSN이 있을 때)") from None
    release = f"{_pod_name()}@{_git_sha()}"

    import sentry_sdk
    from sentry_sdk.integrations.django import DjangoIntegration
    from sentry_sdk.integrations.logging import LoggingIntegration
    from sentry_sdk.integrations.stdlib import StdlibIntegration
    from sentry_sdk.utils import Dsn

    try:
        Dsn(dsn)
    except ValueError:  # BadDsn은 ValueError 하위 형 — 메시지에 DSN 조각이 실린다
        raise ImproperlyConfigured("SENTRY_DSN이 Sentry DSN 꼴이 아니다") from None
    # init 실패는 예외 클래스 이름만 실은 설정 오류로 바꾼다(T071 r8 L2 · §Settings 「기동 실패는 이름만」) — sentry-sdk는 init 때
    # 프록시 env(HTTPS_PROXY · HTTP_PROXY — stdlib getproxies)를 스스로 읽고, 사용자 정보가 든 프록시 URL의 꼴이 틀리면 urllib3 예외가
    # 그 URL째 메시지에 실려 기동 traceback(stderr → Loki)에 남는다. 이름만 잡아 두고 except 블록 밖에서 올린다(안에서 올리면
    # __context__에 원 예외가 남는다). BaseException(KeyboardInterrupt 등)은 잡지 않는다.
    failure: str | None = None
    try:
        sentry_sdk.init(
            dsn=dsn,
            transport=transport,
            release=release,
            environment=environment,
            include_local_variables=False,
            max_request_body_size="never",
            max_breadcrumbs=0,
            trace_propagation_targets=[],
            auto_session_tracking=False,
            spotlight=False,
            debug=False,
            auto_enabling_integrations=False,
            integrations=[DjangoIntegration(), LoggingIntegration(level=None, event_level=None, sentry_logs_level=None)],
            disabled_integrations=[StdlibIntegration],
            before_send=_sentry_before_send,
        )
    except Exception as error:  # noqa: BLE001 — 어떤 init 실패든 이름만 실은 설정 오류로 바꾼다(아래 · 메시지는 버린다)
        failure = type(error).__name__
    if failure is not None:
        raise ImproperlyConfigured(
            f"sentry_sdk.init이 {failure}로 실패했다(예외 메시지는 싣지 않는다 — Sentry 설정과 sentry-sdk가 읽는 env(프록시 · "
            "인증서)를 확인한다)"
        ) from None
    return True
