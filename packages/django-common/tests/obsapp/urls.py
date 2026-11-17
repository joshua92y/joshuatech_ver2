"""시험 관측·헬스 URL(T063 · D4).

헬스 3종(/healthz · /ready · /health)은 django_common.health.health_router(T071 · ninja Router)를 Ninja API에 붙여
루트에 건다 — 요청 경로가 운영(contracts/identity-admin-api.md §엔드포인트)과 같다. 나머지는 로그·트레이스 단언용
평범한 뷰다. /obs/ready-check는 ping과 같은 뷰다 — OTel 제외 정규식이 앵커 없이 `ready`에 부분 일치하면 이 경로까지
트레이스에서 빠진다(obs-11이 잡는다).

Ninja 1.7의 api.urls는 (패턴 목록, "ninja", 네임스페이스)다. 루트("")에 걸어도 Ninja 패턴(헬스 3종 · openapi.json ·
docs · API 루트)에 맞지 않는 경로는 아래 obs/* 패턴으로 넘어간다.
"""

from django.urls import path
from ninja import NinjaAPI

from django_common.health import health_router
from tests.obsapp import views

api = NinjaAPI(urls_namespace="obs")
api.add_router("", health_router)

urlpatterns = [
    path("", api.urls),
    path("obs/ping", views.ping),
    path("obs/leak", views.leak),
    path("obs/leak-headers", views.leak_headers),
    path("obs/ready-check", views.ping),
]
