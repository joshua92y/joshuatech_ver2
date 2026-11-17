"""identity-admin 루트 urlconf(T072 D9) — Ninja API 하나(/healthz · /ready · /health · /api/openapi.json)와 RFC 9457 처리기.

admin은 이 urlconf에 없다 — AdminHostMiddleware가 ADMIN_HOST 요청만 ADMIN_URLCONF(identity_admin.urls_admin)로 보낸다(m2m 호스트의
/admin/은 404).
"""

from django.urls import path

from identity_admin.api import api

urlpatterns = [path("", api.urls)]

handler400 = "identity_admin.errors.bad_request"
handler403 = "identity_admin.errors.permission_denied"
handler404 = "identity_admin.errors.page_not_found"
handler500 = "identity_admin.errors.server_error"
