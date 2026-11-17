"""시험 auth URL(T062 · D6). 요청 경로는 `/healthz` · `/protected` 꼴이다(면제 목록은 정확 일치로 비교한다)."""

from django.urls import path

from tests.authapp import views

urlpatterns = [
    path("healthz", views.healthz),
    path("ready", views.ready),
    path("health", views.health),
    path("protected", views.protected),
    path("webhooks/authentik", views.authentik_webhook),
    # auth-32(T066 · T070 가정 AUTH_ACCESS_ONLY_PATHS) — 시험이 settings로 `/access-only`를 Access 전용 경로로 둔다.
    path("access-only", views.access_only),
]
