"""시험 auth URL(T062 · D6). 요청 경로는 `/healthz` · `/protected` 꼴이다(면제 목록은 정확 일치로 비교한다)."""

from django.urls import path

from tests.authapp import views

urlpatterns = [
    path("healthz", views.healthz),
    path("ready", views.ready),
    path("health", views.health),
    path("protected", views.protected),
    path("webhooks/authentik", views.authentik_webhook),
]
