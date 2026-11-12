"""RlsWidget 초기 스키마(T072 D12) — TenantModel이 주는 필드(id UUID PK · tenant_id UUID · 인덱스 (tenant_id, id))를 펼쳐 적은
makemigrations 꼴이다(시험 test_migrations의 makemigrations --check가 변경 없음을 고정한다)."""

import uuid

from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies: list[tuple[str, str]] = []

    operations = [
        migrations.CreateModel(
            name="RlsWidget",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("tenant_id", models.UUIDField()),
                ("name", models.CharField(max_length=50)),
            ],
            options={
                "db_table": "rls_widget",
                "indexes": [models.Index(fields=["tenant_id", "id"], name="rlswidget_tenant_id_idx")],
            },
        ),
    ]
