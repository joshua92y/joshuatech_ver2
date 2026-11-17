"""시험 앱 모델(T060 · D5). A 등급 공통 필드(id · tenant_id · 인덱스 (tenant_id, id))는 T068의 TenantModel이 준다.

- Widget(TenantModel) = A 등급(테넌트 범위 · RLS) 대역 — 테이블 widget.
- GlobalThing(GlobalModel) = B 등급 대역 — 테이블 이름을 허용 목록의 `tenant`로 둔다(check_rls 통과 대상).

Meta는 추상 부모의 Meta를 상속한다 — Django에서 자식이 Meta를 새로 쓰면 부모 Meta의 indexes 등을 잃는다.
"""

import uuid

from django.db import models

from django_common.tenancy import GlobalModel, TenantModel


class Widget(TenantModel):
    name = models.CharField(max_length=50)

    class Meta(TenantModel.Meta):
        db_table = "widget"


class GlobalThing(GlobalModel):
    # B 등급 추상 모델의 PK 정책은 계약에 없다(outbox는 ULID 등) → 대역 모델이 PK를 스스로 고정한다.
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant_id = models.UUIDField()
    label = models.CharField(max_length=50)

    class Meta(GlobalModel.Meta):
        db_table = "tenant"
