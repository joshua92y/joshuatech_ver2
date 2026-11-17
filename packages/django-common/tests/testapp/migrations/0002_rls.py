"""Widget(A 등급) RLS 전용 마이그레이션(T060).

규칙(django-pod §Migrations): RLS 정책 변경은 스키마·데이터 변경과 섞지 않고 전용 마이그레이션에 둔다.
가정: rls_policies(table)은 Operation의 시퀀스(list/tuple)를 돌려준다 — ENABLE · FORCE ROW LEVEL SECURITY ·
정책 tenant_isolation(USING + WITH CHECK) + 각 reverse.
"""

from django.db import migrations

from django_common.tenancy import rls_policies


class Migration(migrations.Migration):
    dependencies = [("testapp", "0001_initial")]

    operations = [*rls_policies("widget")]
