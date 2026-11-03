"""시험 auth 뷰(T062 · D5 · D6).

- 헬스 3종은 "ok"만 돌려준다 — 미들웨어 면제 경로라 헤더 없이 닿아야 한다.
- protected는 미들웨어가 둔 요청 속성(T070 가정 D4: auth_claims · access_claims · tenant_id)을 그대로 비춘다.
- 웹훅은 라이브러리 헬퍼 verify_authentik_webhook(T070 가정 D5)으로 서명을 검증하고, 멱등 저장소 대역 SEEN_PKS로
  첫 수신 202 · 재전송 200(no-op)을 보여 준다. 운영의 멱등 저장(pod DB)과 뷰 수준 통합 단언은 T066의 몫이다.
- access_only(auth-32 · T066)는 Access 전용 경로에서 미들웨어가 둔 속성을 비춘다 — common_name과 auth_claims ·
  tenant_id 속성의 유무(Access 단계만 거치므로 둘 다 없어야 한다).
"""

import uuid

from django.conf import settings
from django.http import HttpRequest, HttpResponse, HttpResponseBase, JsonResponse
from django.views.decorators.http import require_POST

from django_common.auth import WebhookSignatureInvalid, verify_authentik_webhook

# 처리한 웹훅 pk(멱등 키) — tests/test_auth.py의 autouse 픽스처가 테스트마다 비운다.
SEEN_PKS: set[str] = set()


def healthz(request: HttpRequest) -> HttpResponse:
    return HttpResponse("ok")


def ready(request: HttpRequest) -> HttpResponse:
    return HttpResponse("ok")


def health(request: HttpRequest) -> HttpResponse:
    return HttpResponse("ok")


def protected(request: HttpRequest) -> JsonResponse:
    """sub(Bearer) · tenant_id(문자열 · 속성이 없으면 "None") · tenant_id가 uuid.UUID인지 · common_name(Access).

    tenant_id_is_uuid: T068 TenantContextMiddleware는 request.tenant_id를 uuid.UUID로 받는다(T060 HeaderTenantMiddleware
    와 같은 자리) — 문자열만 비추면 str과 UUID를 구별하지 못한다.
    """
    tenant_id = getattr(request, "tenant_id", None)
    return JsonResponse(
        {
            "sub": request.auth_claims["sub"],
            "tenant_id": str(tenant_id),
            "tenant_id_is_uuid": isinstance(tenant_id, uuid.UUID),
            "common_name": request.access_claims.get("common_name"),
        }
    )


@require_POST
def authentik_webhook(request: HttpRequest) -> HttpResponseBase:
    """서명 실패 → 헬퍼 예외의 RFC 9457 응답(401) · 처음 보는 pk → 202 · 이미 본 pk → 200 no-op."""
    try:
        event = verify_authentik_webhook(
            request.body,
            request.headers.get("X-Authentik-Signature"),
            secret=settings.AUTHENTIK_WEBHOOK_SECRET,
        )
    except WebhookSignatureInvalid as exc:
        return exc.to_response()
    if event.pk in SEEN_PKS:
        return JsonResponse({"status": "duplicate"}, status=200)
    SEEN_PKS.add(event.pk)
    return JsonResponse({"status": "accepted", "pk": event.pk}, status=202)


def access_only(request: HttpRequest) -> JsonResponse:
    """Access 전용 경로(auth-32) — common_name(Access) · auth_claims 속성 유무 · tenant_id 속성 유무."""
    return JsonResponse(
        {
            "common_name": request.access_claims.get("common_name"),
            "has_auth_claims": hasattr(request, "auth_claims"),
            "has_tenant_id": hasattr(request, "tenant_id"),
        }
    )
