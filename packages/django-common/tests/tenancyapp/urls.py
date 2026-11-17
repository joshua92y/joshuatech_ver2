"""시험 tenancy URL(T068 · D11 · r2). 요청 경로는 `/healthz` 꼴이다(면제 목록은 path_info 정확 일치로 비교한다).

tc-4의 `/healthz/` · `/healthzz` 같은 경로는 일부러 두지 않는다 — 면제로 잘못 통과하면 URL 해석에서 404가 되어 403과 갈린다.
`/exempt-raise`는 tc-27이 면제 목록에 넣고 부른다(기본 면제 목록에는 없다).
"""

from django.urls import path

from tests.tenancyapp import views

urlpatterns = [
    path("healthz", views.exempt_probe),
    path("ready", views.exempt_probe),
    path("health", views.exempt_probe),
    path("custom-exempt", views.exempt_probe),
    path("exempt-raise", views.exempt_raise),
    path("context", views.context_probe),
    path("widgets/write-ok", views.widget_write_ok),
    path("widgets/write-500", views.widget_write_500),
    path("widgets/write-raise", views.widget_write_raise),
]
