"""시험 관측 뷰(T063 · D4).

- ping: structlog 로거(이름 tests.obsapp)로 ping_handled 한 줄(note="hello")을 남기고 {"ok": true}를 돌려준다 —
  요청 로그 3줄(request_started · ping_handled · request_finished)의 가운데 줄이다.
- leak: 마스킹 대상 키(authorization · cookie · x-authentik-signature)를 최상위 · headers 매핑 · 중첩 매핑에 표식 값
  MARK-A…MARK-G(실제 비밀이 아니다)로 싣고, 지워지면 안 되는 이웃 값(headers의 Accept · safe)을 같이 싣는다.
  최상위 키는 파이썬 키워드 인자라 `x_authentik_signature`(밑줄)다 — 마스킹은 대소문자와 `_`/`-`를 가리지 않는다(D2).
- leak_headers: 실제 request.headers(Django HttpHeaders — dict가 아닌 Mapping)를 그대로(mapping=)와 dict로(headers=) 싣는다 —
  현실의 누출 경로(`log.info("req", headers=request.headers)`)다(리뷰 r1 B-2 · obs-20).
"""

import structlog
from django.http import HttpRequest, JsonResponse

log = structlog.get_logger("tests.obsapp")


def ping(request: HttpRequest) -> JsonResponse:
    log.info("ping_handled", note="hello")
    return JsonResponse({"ok": True})


def leak(request: HttpRequest) -> JsonResponse:
    log.info(
        "leak_probe",
        authorization="Bearer MARK-A",
        cookie="sid=MARK-B",
        x_authentik_signature="sha256=MARK-C",
        headers={
            "Authorization": "MARK-D",
            "Cookie": "MARK-E",
            "X-Authentik-Signature": "MARK-F",
            "Accept": "*/*",
        },
        nested={"inner": {"cookie": "MARK-G"}},
        safe="keep-me",
    )
    return JsonResponse({"ok": True})


def leak_headers(request: HttpRequest) -> JsonResponse:
    log.info("leak_headers_probe", headers=dict(request.headers), mapping=request.headers)
    return JsonResponse({"ok": True})
