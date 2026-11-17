"""시험 관측 계약 URL(T071 · D11).

- 루트: django_common.health.health_router를 NinjaAPI(urls_namespace="oc")에 붙여 /healthz · /ready · /health(운영 경로와
  같다).
- /secured/: 모든 연산을 거부하는 auth를 건 NinjaAPI(urls_namespace="oc-secured")에 같은 health_router를 붙인다 — 헬스 3종은
  연산마다 auth=None이라 200이고, auth를 상속하는 /secured/guarded는 401이다(D6 · auth를 건 API에서도 헬스 200).
- oc/*: 로그 · 미들웨어 · Sentry 단언용 평범한 뷰(tests/obscontractapp/views.py).
- handler500 · handler400: RFC 9457(detail 없음).

Ninja 1.7의 api.urls는 (패턴 목록, "ninja", 네임스페이스)다. 루트("")에 건 API의 패턴(헬스 3종 · openapi.json · docs · API
루트)에 맞지 않는 경로는 아래 oc/* 패턴으로 넘어간다.
"""

from django.http import HttpRequest
from django.urls import path
from ninja import NinjaAPI

from django_common.health import health_router
from tests.obscontractapp import views


def _deny(request: HttpRequest) -> None:
    """Ninja auth callable — 언제나 None(인증 실패 · 401)."""
    return None


root_api = NinjaAPI(urls_namespace="oc")
root_api.add_router("", health_router)

secured_api = NinjaAPI(urls_namespace="oc-secured", auth=[_deny])
secured_api.add_router("", health_router)


@secured_api.get("/guarded")
def guarded(request: HttpRequest) -> dict[str, bool]:
    return {"guarded": True}


urlpatterns = [
    path("secured/", secured_api.urls),
    path("", root_api.urls),
    path("oc/ping", views.ping),
    path("oc/boom", views.boom),
    path("oc/problem/<str:kind>", views.problem),
    path("oc/log-error", views.log_error),
    path("oc/unavailable", views.unavailable),
    path("oc/protected", views.protected),
    path("oc/dump", views.dump),
]

handler500 = "tests.obscontractapp.views.server_error"
handler400 = "tests.obscontractapp.views.bad_request"
