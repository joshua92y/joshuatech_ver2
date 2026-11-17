"""시험 전용 원시 상류 미들웨어(T068 · tc-6) — 헤더 X-Test-Raw-Tenant의 값을 변환 없이(str 그대로) request.tenant_id에 둔다.

운영의 JwtAuthMiddleware(T070)는 request.tenant_id에 uuid.UUID만 둔다(T060 HeaderTenantMiddleware도 uuid.UUID로 바꾼다).
이 대역은 계약 밖 타입(UUID 글자의 str)이 들어왔을 때 TenantContextMiddleware가 fail-closed(403 tenant_required)인지
보려고 일부러 변환하지 않는다. 헤더가 없으면 속성을 두지 않는다.
"""

from collections.abc import Callable

from django.http import HttpRequest, HttpResponseBase


class RawTenantMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        raw = request.headers.get("X-Test-Raw-Tenant")
        if raw is not None:
            request.tenant_id = raw
        return self.get_response(request)
