"""시험 전용 상류 미들웨어(T060) — 운영의 인증 미들웨어 자리에서 request.tenant_id(UUID)를 둔다.

헤더 X-Test-Tenant가 있으면 uuid.UUID(값)을 request.tenant_id에 두고, 없으면 속성을 두지 않는다.
django_common.tenancy.TenantContextMiddleware는 이 속성만 보고 테넌트 컨텍스트를 연다(D7).
"""

import uuid
from collections.abc import Callable

from django.http import HttpRequest, HttpResponseBase


class HeaderTenantMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        raw = request.headers.get("X-Test-Tenant")
        if raw:
            request.tenant_id = uuid.UUID(raw)
        return self.get_response(request)
