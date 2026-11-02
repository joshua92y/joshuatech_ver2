"""시험 앱 초기 스키마(T060 · 손으로 씀).

django_common.tenancy가 아직 없어(test-first) makemigrations로 만들 수 없다 → 추상 모델이 줄 필드를 가정해
적었다. Django 마이그레이션 상태는 추상 부모를 bases로 두지 않고 상속 필드를 펼쳐 적는다.

가정(T068이 실제 TenantModel/GlobalModel에 맞춰 고친다 — `makemigrations --check testapp`가 변경 없음이어야 한다):
- TenantModel = id UUID PK(default uuid4) · tenant_id UUID NOT NULL(단독 인덱스 없음) · 인덱스 (tenant_id, id).
  인덱스 이름 widget_tenant_id_idx도 가정이다(추상 Meta의 이름 규칙에 맞춘다).
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
