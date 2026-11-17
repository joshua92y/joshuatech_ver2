"""시험 공용 테넌트 컨텍스트 헬퍼(T061 · D6/D13) — T060 test_tenancy._set_tenant를 별칭 인자로 일반화했다.

tests/test_tenancy.py는 자기 _set_tenant를 그대로 쓴다(T060 산출물 — 바꾸지 않는다). 새 테스트는 이 헬퍼를 쓴다.
"""

from __future__ import annotations

import uuid

from django.db import connections


def set_tenant(alias: str, tenant: uuid.UUID) -> None:
    """별칭 alias의 현재 트랜잭션에 테넌트 컨텍스트를 둔다 — 미들웨어와 같은 문(is_local = true).

    transaction.atomic(using=alias) 안에서만 뜻이 있다: autocommit이면 문이 끝나는 즉시 사라지므로 실패로 막는다.
    """
    connection = connections[alias]
    if not connection.in_atomic_block:
        raise RuntimeError(f"set_tenant({alias!r})는 transaction.atomic(using={alias!r}) 안에서 불러야 한다")
    with connection.cursor() as cursor:
        cursor.execute("SELECT set_config('app.tenant_id', %s, true)", [str(tenant)])
