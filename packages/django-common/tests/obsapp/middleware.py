"""시험 전용 상류 미들웨어(T063 · D4) — 운영의 인증 미들웨어(T070) 자리에서 request.auth_claims를 둔다.

헤더 X-Test-Sub가 있으면 request.auth_claims = {"sub": 값}을 두고, 없으면 속성을 두지 않는다(tests/testapp/middleware.py
HeaderTenantMiddleware와 같은 꼴). RequestIdMiddleware(T071)는 이 속성으로 request_finished의 sub_hash를, OTel
response_hook은 span 속성 sub_hash를 만든다(D2).
"""

from collections.abc import Callable

from django.http import HttpRequest, HttpResponseBase


class HeaderClaimsMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        sub = request.headers.get("X-Test-Sub")
        if sub:
            request.auth_claims = {"sub": sub}
        return self.get_response(request)
