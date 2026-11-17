"""시험 관측 계약 뷰(T071 · D11).

- ping: structlog 로거(tests.obscontractapp)로 oc_ping 한 줄 → {"ok": true}.
- boom: 헤더 X-Oc-Sentinel 값을 지역 변수 marker에 쥔 채(Sentry 프레임 vars · 로그 예외 렌더 단언의 입력) INFO · stdlib
  WARNING 한 줄씩과 수동 브레드크럼(X-Oc-Breadcrumb 값)을 남기고 RuntimeError를 올린다(메시지에는 길이만).
- problem(kind): problem 필드 시험용 응답 — revoked(401 session_revoked · detail = X-Oc-Sentinel) · charset(503 not-ready ·
  Content-Type 매개변수 있음) · plain-json(application/json) · foreign(다른 출처의 type) · nested(경로 조각 둘) · type-int ·
  not-json · stream(StreamingHttpResponse — 본문을 읽지 않아야 한다) · limit · huge(본문 정확히 64 KiB · 64 KiB + 1바이트 —
  넘으면 읽지 않는다 · T071 r2 Y6).
- log_error: structlog ERROR · stdlib ERROR(exc_info)를 남기고 200 — 로그는 Sentry 이벤트가 되지 않는다(D7).
- dump: request.META · request.headers · request.COOKIES를 로그 필드로 통째로 넘긴다(호출자 규칙을 어긴 사고의 대역 — 마스킹이
  쿼리 · Referer · 쿠키 · OTel이 META에 둔 요청 속성을 지우는지 본다 · T071 r3 Z4 oc-56).
- unavailable: 예외 없는 503 not_ready.
- protected: 인증 계층 뒤의 평범한 200(auth 설정 오류 500 시험의 도착점 — 여기까지 오지 않는다).
- server_error · bad_request: urlconf handler500 · handler400(RFC 9457 · detail 없음).
"""

import json
import logging

import sentry_sdk
import structlog
from django.http import HttpRequest, HttpResponse, JsonResponse, StreamingHttpResponse

from django_common.problem import problem_response

log = structlog.get_logger("tests.obscontractapp")
std_log = logging.getLogger("tests.obscontractapp.std")

_PROBLEM_CONTENT_TYPE = "application/problem+json"
_PROBLEM_BASE = "https://joshuatech.dev/problems/"
_PROBLEM_READ_LIMIT = 64 * 1024  # 계약 「로그」 행 — problem 본문이 이보다 크면 읽지 않는다(T071 r2 Y6)


def ping(request: HttpRequest) -> JsonResponse:
    log.info("oc_ping")
    return JsonResponse({"ok": True})


def boom(request: HttpRequest) -> HttpResponse:
    marker = request.headers.get("X-Oc-Sentinel", "")
    log.info("oc_boom_before", note="info-line")
    std_log.warning("oc std warning before boom")
    sentry_sdk.add_breadcrumb(message=request.headers.get("X-Oc-Breadcrumb", ""), category="oc")
    raise RuntimeError(f"oc-boom marker-length={len(marker)}")


def problem(request: HttpRequest, kind: str) -> HttpResponse:
    if kind == "revoked":
        return problem_response("session_revoked", 401, detail=request.headers.get("X-Oc-Sentinel", ""))
    if kind == "charset":
        body = json.dumps({"type": _PROBLEM_BASE + "not-ready", "title": "Service Unavailable", "status": 503})
        return HttpResponse(body, status=503, content_type=_PROBLEM_CONTENT_TYPE + "; charset=utf-8")
    if kind == "plain-json":
        return JsonResponse({"type": _PROBLEM_BASE + "session-revoked"}, status=401)
    if kind == "foreign":
        body = json.dumps({"type": "https://example.com/problems/session-revoked", "status": 401})
        return HttpResponse(body, status=401, content_type=_PROBLEM_CONTENT_TYPE)
    if kind == "nested":
        body = json.dumps({"type": _PROBLEM_BASE + "session-revoked/extra", "status": 401})
        return HttpResponse(body, status=401, content_type=_PROBLEM_CONTENT_TYPE)
    if kind == "type-int":
        return HttpResponse(json.dumps({"type": 7, "status": 401}), status=401, content_type=_PROBLEM_CONTENT_TYPE)
    if kind == "not-json":
        return HttpResponse(b"{not json", status=401, content_type=_PROBLEM_CONTENT_TYPE)
    if kind == "stream":
        chunks = [b'{"type": "', (_PROBLEM_BASE + "session-revoked").encode(), b'", "status": 401}']
        return StreamingHttpResponse(iter(chunks), status=401, content_type=_PROBLEM_CONTENT_TYPE)
    if kind in ("limit", "huge"):
        size = _PROBLEM_READ_LIMIT + (1 if kind == "huge" else 0)
        bare = json.dumps({"type": _PROBLEM_BASE + "session-revoked", "status": 401, "detail": ""})
        body = json.dumps({"type": _PROBLEM_BASE + "session-revoked", "status": 401, "detail": "x" * (size - len(bare))})
        return HttpResponse(body, status=401, content_type=_PROBLEM_CONTENT_TYPE)
    return JsonResponse({"unknown": kind}, status=400)


def log_error(request: HttpRequest) -> JsonResponse:
    log.error("oc_error_line", note="structlog error")
    try:
        raise ValueError("oc-handled")
    except ValueError:
        std_log.error("oc std error with traceback", exc_info=True)
    return JsonResponse({"ok": True})


def unavailable(request: HttpRequest) -> HttpResponse:
    return problem_response("not_ready", 503)


def dump(request: HttpRequest) -> JsonResponse:
    log.info("oc_dump", meta=request.META, headers=request.headers, cookies=request.COOKIES)
    return JsonResponse({"ok": True})


def protected(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"ok": True})


def server_error(request: HttpRequest) -> HttpResponse:
    return problem_response("internal_error", 500)


def bad_request(request: HttpRequest, exception: Exception) -> HttpResponse:
    return problem_response("validation_error", 400)
