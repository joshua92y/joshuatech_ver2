"""시험 앱 초기 스키마(T060 · 손으로 씀).

T060 때는 django_common.tenancy가 없어(test-first) makemigrations로 만들 수 없었다 → 추상 모델이 줄 필드를 가정해
적었다. Django 마이그레이션 상태는 추상 부모를 bases로 두지 않고 상속 필드를 펼쳐 적는다.

T068 확인: 가정이 실제 TenantModel/GlobalModel과 같아 고칠 것이 없었다 — tests/test_tenancy_contract.py tc-18
(`makemigrations testapp --check --dry-run` 변경 없음)이 고정한다.
- TenantModel = id UUID PK(default uuid4) · tenant_id UUID NOT NULL(단독 인덱스 없음) · 인덱스 (tenant_id, id) 이름
  widget_tenant_id_idx(추상 Meta의 이름 규칙 `%(class)s_tenant_id_idx`).
- GlobalThing은 PK를 모델에서 직접 고정했다(tests/testapp/models.py).
"""

import uuid

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name="Widget",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4, editable=False, primary_key=True, serialize=False
                    ),
                ),
                ("tenant_id", models.UUIDField()),
                ("name", models.CharField(max_length=50)),
            ],
            options={
                "db_table": "widget",
                "indexes": [models.Index(fields=["tenant_id", "id"], name="widget_tenant_id_idx")],
            },
        ),
        migrations.CreateModel(
            name="GlobalThing",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4, editable=False, primary_key=True, serialize=False
                    ),
                ),
                ("tenant_id", models.UUIDField()),
                ("label", models.CharField(max_length=50)),
            ],
            options={
                "db_table": "tenant",
            },
        ),
    ]
