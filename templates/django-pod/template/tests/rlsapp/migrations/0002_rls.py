"""RlsWidget(A 등급) RLS 전용 마이그레이션(T072 D12) — RLS 정책 변경은 스키마 · 데이터 변경과 섞지 않는다(규칙 §Migrations).

rls_policies(table) = ENABLE + FORCE ROW LEVEL SECURITY + 정책 tenant_isolation(USING + WITH CHECK) + 각 reverse.
"""

from django.db import migrations
from django_common.tenancy import rls_policies


class Migration(migrations.Migration):
    dependencies = [("rlsapp", "0001_initial")]

    operations = [*rls_policies("rls_widget")]
