"""시험 전용 미들웨어(T071 · D11) — request.user 접근 탐지 · 단락 대역.

UserTrapMiddleware: 헤더 X-Oc-User-Trap이 있으면 request.user를 SimpleLazyObject로 둔다. 누가 그 객체의 속성을 읽으면(예:
django-structlog bind_user_id의 getattr(request.user, "pk") — AuthenticationMiddleware가 있는 pod에서는 세션 · 사용자 DB 조회가
된다) 평가 함수가 USER_TRAP_HITS에 경로를 쌓는다. `request.user is not None` 같은 동일성 비교는 평가하지 않는다.
RequestIdMiddleware(가장 바깥)는 request.user에 접근하지 않아야 한다(설계 D3) — 시험이 USER_TRAP_HITS를 비우고 단언한다.

ShortCircuitMiddleware: 헤더 X-Oc-Short-Circuit이 있으면 뷰 · URL 해석 앞에서 403 forbidden(RFC 9457)을 돌려준다 — 인증
미들웨어가 단락하는 요청의 대역이다(process_view가 없어 OTel 요청 속성의 http.target이 route로 바뀌지 않는다 · T071 r3 Z1 지표
시험 oc-59).
"""

from collections.abc import Callable

from django.http import HttpRequest, HttpResponseBase
from django.utils.functional import SimpleLazyObject

from django_common.problem import problem_response

USER_TRAP_HITS: list[str] = []


class _TrapUser:
    """평가된 뒤의 사용자 대역(pk 없음 — 평가 자체가 탐지 신호다)."""


class UserTrapMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        if request.headers.get("X-Oc-User-Trap"):
            path = request.path

            def evaluate() -> _TrapUser:
                USER_TRAP_HITS.append(path)
                return _TrapUser()

            request.user = SimpleLazyObject(evaluate)
        return self.get_response(request)


class ShortCircuitMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        if request.headers.get("X-Oc-Short-Circuit"):
            return problem_response("forbidden", 403)
        return self.get_response(request)
