"""T070 계약 시험 URL. 요청 경로는 `/healthz` · `/protected` 꼴이다(면제 · Access 전용 목록은 정확 일치로 비교한다)."""

from django.urls import path

from tests.authcontractapp import views

urlpatterns = [
    path("healthz", views.plain),
    path("open", views.plain),
    path("protected", views.echo),
    path("access-only", views.echo),
]

# 호스트 거부(DisallowedHost)는 미들웨어 밖으로 올라가 요청 urlconf의 handler400이 응답을 만든다(Django 6.1
# response_for_exception — 시험 Client는 SuspiciousOperation을 다시 올리지 않는다).
handler400 = views.bad_request
