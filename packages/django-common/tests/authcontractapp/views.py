"""T070 계약 시험 뷰 — 인증 속성(access_claims · auth_claims · tenant_id)을 값 그대로 비추되 없으면 None으로 둔다."""

import uuid

from django.core.exceptions import DisallowedHost
from django.http import HttpRequest, HttpResponse, JsonResponse

from django_common.problem import problem_response


def plain(request: HttpRequest) -> HttpResponse:
    return HttpResponse("ok")


def echo(request: HttpRequest) -> JsonResponse:
    """sub(Bearer) · common_name(Access) · tenant_id(문자열 · 없으면 "None") · tenant_id가 uuid.UUID인지 · auth_claims의
    클레임 이름(정렬 · 없으면 None) · groups 클레임(없으면 None — auth_claims가 payload 전체인지 본다 · T070 r2)."""
    auth_claims = getattr(request, "auth_claims", None)
    access_claims = getattr(request, "access_claims", None)
    tenant_id = getattr(request, "tenant_id", None)
    return JsonResponse(
        {
            "sub": auth_claims.get("sub") if isinstance(auth_claims, dict) else None,
            "common_name": access_claims.get("common_name") if isinstance(access_claims, dict) else None,
            "tenant_id": str(tenant_id),
            "tenant_id_is_uuid": isinstance(tenant_id, uuid.UUID),
            "auth_claim_names": sorted(auth_claims) if isinstance(auth_claims, dict) else None,
            "groups": auth_claims.get("groups") if isinstance(auth_claims, dict) else None,
        }
    )


def bad_request(request: HttpRequest, exception: Exception) -> HttpResponse:
    """handler400 대역 — 호스트 거부는 400 invalid_host, 그 밖의 SuspiciousOperation · BadRequest는 400 validation_error."""
    slug = "invalid_host" if isinstance(exception, DisallowedHost) else "validation_error"
    return problem_response(slug, 400)
