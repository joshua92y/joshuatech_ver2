"""시험 URL(T060 · D5)."""

from django.urls import path

from tests.testapp import views

urlpatterns = [
    path("widgets/count", views.widget_count),
    path("widgets/stream", views.widget_stream),
    path("healthz", views.healthz),
]
