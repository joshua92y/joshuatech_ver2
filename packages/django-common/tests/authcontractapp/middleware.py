"""속성 탐침 미들웨어(T070 계약 시험) — MIDDLEWARE에서 JwtAuthMiddleware 바깥(앞)에 둔다.

- 요청 헤더 SPOOF_HEADER(UUID 문자열)가 있으면 안쪽을 부르기 전에 가짜 인증 속성 셋(access_claims · auth_claims ·
  tenant_id)을 미리 둔다 — 인증을 거치지 않은 값이 뷰 · TenantContextMiddleware에 닿는지 보는 대역이다.
- 안쪽이 돌아온 뒤 요청에 남은 인증 속성의 이름만 ATTRS_HEADER(쉼표 구분 · 정해진 순서)로 비춘다 — 값은 싣지 않는다.
"""

import uuid
from collections.abc import Callable

from django.http import HttpRequest, HttpResponseBase

SPOOF_HEADER = "X-Test-Spoof-Tenant"
ATTRS_HEADER = "X-Test-Auth-Attrs"
AUTH_ATTRIBUTES = ("access_claims", "auth_claims", "tenant_id")
SPOOFED_SUB = "spoofed-sub"
SPOOFED_COMMON_NAME = "spoofed.access"


class AttributeProbeMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        spoof = request.headers.get(SPOOF_HEADER)
        if spoof:
            request.access_claims = {"common_name": SPOOFED_COMMON_NAME}
            request.auth_claims = {"sub": SPOOFED_SUB}
            request.tenant_id = uuid.UUID(spoof)
        response = self.get_response(request)
        response[ATTRS_HEADER] = ",".join(name for name in AUTH_ATTRIBUTES if hasattr(request, name))
        return response
