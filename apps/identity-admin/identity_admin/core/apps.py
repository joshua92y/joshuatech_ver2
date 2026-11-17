"""identity-admin 도메인 앱 core(T072 D3 · D12) — 마이그레이션 0001_app_role_grants(app role GRANT)를 담는다."""

from django.apps import AppConfig


class CoreConfig(AppConfig):
    name = "identity_admin.core"
    label = "core"
    verbose_name = "identity-admin core"
