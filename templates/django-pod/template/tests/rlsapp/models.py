"""시험 전용 A 등급 모델(T072 D12) — 실제로 도는 A 등급 표는 이것뿐이다(템플릿 core에는 실행되는 모델이 없다).

RlsWidget(TenantModel) — 표 rls_widget · id UUID v4 PK · tenant_id UUID NOT NULL · 인덱스 (tenant_id, id)
rlswidget_tenant_id_idx(TenantModel이 준다 · 클래스 이름 16자 이하). RLS는 전용 마이그레이션 0002_rls(rls_policies)가 건다.
B 등급 예는 django_common의 outbox가 대신한다.
"""

from django.db import models
from django_common.tenancy import TenantModel


class RlsWidget(TenantModel):
    name = models.CharField(max_length=50)

    class Meta(TenantModel.Meta):
        db_table = "rls_widget"
