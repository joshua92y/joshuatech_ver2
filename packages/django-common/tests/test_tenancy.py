"""django_common.tenancy 계약 테스트(T060 · test-first — 짝 구현 T068이 초록으로 만든다).

계약: contracts/pod-template.md §테이블 등급 · §기본 테스트 1(헌법 II), plan A15, ADR 0007.
- A 등급(TenantModel · ENABLE + FORCE ROW LEVEL SECURITY + 정책 tenant_isolation): 컨텍스트 없음 0행 ·
  다른 테넌트 0행 · owner role(BYPASSRLS) 전체.
- B 등급(GlobalModel · 허용 목록 tenant/tenant_membership/outbox/session_revocation_log): app role이 컨텍스트
  없이 전체를 읽는다.
- check_rls: FORCE 없는 A 등급 · ENABLE 없는(DISABLE) A 등급 · 정책 없는 A 등급 · 허용 목록 밖의 RLS 없는 테이블
  → CommandError(테이블 이름 포함). Django 프레임워크 테이블(계약 FRAMEWORK_TABLES)은 면제.
- TenantContextMiddleware: request.tenant_id → transaction.atomic() 안에서
  set_config('app.tenant_id', …, true) → 뷰. 없으면 403(헬스 3종 면제). StreamingHttpResponse는 RuntimeWarning.

DB 별칭: default = app role(NOBYPASSRLS · 런타임) · owner = owner role(BYPASSRLS · 시드 · DDL 토글).
다른 연결의 데이터·DDL은 커밋된 것만 보인다 → 시드와 토글은 owner 연결의 autocommit으로 하고,
토글은 try/finally로 되돌린다(스키마는 세션 내내 공유된다).
"""

from __future__ import annotations

import io
import uuid

import pytest
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import DatabaseError, connections, models, transaction
from django.db.migrations.state import ProjectState
from django.test import Client

from django_common.tenancy import rls_policies
from tests.testapp.models import GlobalThing, Widget

pytestmark = pytest.mark.django_db(transaction=True, databases=["default", "owner"])

TENANT_A = uuid.UUID("00000000-0000-4000-8000-00000000000a")
TENANT_B = uuid.UUID("00000000-0000-4000-8000-00000000000b")


def _seed_widgets() -> None:
    """owner(BYPASSRLS)로 tenant A 2행 · tenant B 3행을 만든다(autocommit → 다른 연결에서 보인다)."""
    for name in ("a1", "a2"):
        Widget.objects.using("owner").create(tenant_id=TENANT_A, name=name)
    for name in ("b1", "b2", "b3"):
        Widget.objects.using("owner").create(tenant_id=TENANT_B, name=name)


def _set_tenant(tenant: uuid.UUID) -> None:
    """현재 default 트랜잭션에 테넌트 컨텍스트를 둔다 — 미들웨어와 같은 문(is_local = true)."""
    with connections["default"].cursor() as cursor:
        cursor.execute("SELECT set_config('app.tenant_id', %s, true)", [str(tenant)])


def _owner_ddl(statement: str) -> None:
    """owner 연결에서 DDL을 실행한다(autocommit — 곧바로 커밋되어 check_rls의 연결에서 보인다)."""
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement)


def _reapply_rls_policies(table: str) -> None:
    """rls_policies(table)의 forward 연산을 owner 연결의 schema editor로 다시 적용한다(chk-3 복원)."""
    state = ProjectState()
    with connections["owner"].schema_editor() as editor:
        for operation in rls_policies(table):
            operation.database_forwards("testapp", editor, state, state)


def _check_rls() -> None:
    call_command("check_rls", stdout=io.StringIO(), stderr=io.StringIO())


def test_rls_0_model_shape() -> None:
    """rls-0 — TenantModel이 tenant_id(UUID · NOT NULL)와 인덱스 (tenant_id, id)를 준다."""
    field = Widget._meta.get_field("tenant_id")
    assert isinstance(field, models.UUIDField)
    assert field.null is False
    assert any(list(index.fields) == ["tenant_id", "id"] for index in Widget._meta.indexes)


def test_rls_1_tenant_a_context_sees_only_a() -> None:
    """rls-1 — tenant A 컨텍스트(app role)에서는 A 행 2개만 보이고 tenant B 행은 0이다."""
    _seed_widgets()
    with transaction.atomic(using="default"):
        _set_tenant(TENANT_A)
        assert Widget.objects.count() == 2
        assert Widget.objects.filter(tenant_id=TENANT_B).count() == 0
        assert set(Widget.objects.values_list("tenant_id", flat=True)) == {TENANT_A}


def test_rls_2_no_context_zero_rows() -> None:
    """rls-2 — 테넌트 컨텍스트가 없으면 app role은 0행이다(fail-closed)."""
    _seed_widgets()
    assert Widget.objects.count() == 0


def test_rls_3_owner_bypassrls_sees_all() -> None:
    """rls-3 — owner role(BYPASSRLS)은 FORCE RLS 아래에서도 컨텍스트 없이 전체(5행)를 본다."""
    _seed_widgets()
    assert Widget.objects.using("owner").count() == 5


def test_rls_4_with_check_blocks_cross_tenant_insert() -> None:
    """rls-4 — tenant A 컨텍스트에서 tenant B 행을 쓰면 정책의 WITH CHECK가 막는다(행은 남지 않는다)."""
    with pytest.raises(DatabaseError, match="row-level security"):
        with transaction.atomic(using="default"):
            _set_tenant(TENANT_A)
            Widget(tenant_id=TENANT_B, name="cross").save(using="default")
    assert Widget.objects.using("owner").count() == 0


def test_rls_5_global_model_app_reads_all_without_context() -> None:
    """rls-5 — B 등급(GlobalModel · 허용 목록 이름 tenant)은 RLS가 없어 app role이 컨텍스트 없이 전체를 읽는다."""
    GlobalThing.objects.using("owner").create(tenant_id=TENANT_A, label="a")
    GlobalThing.objects.using("owner").create(tenant_id=TENANT_B, label="b")
    assert GlobalThing.objects.count() == 2


def test_chk_1_check_rls_passes() -> None:
    """chk-1 — 마이그레이션 직후 스키마는 check_rls를 통과한다.

    widget = FORCE RLS + 정책 tenant_isolation, tenant = B 등급 허용 목록. Django 프레임워크 테이블(django_migrations ·
    contenttypes의 django_content_type — RLS 없음 · 허용 목록 밖)이 있어도 통과해야 한다: 계약 §테이블 등급의
    면제 목록 FRAMEWORK_TABLES(정확한 이름 10개 · django_common.tenancy 상수 · pod가 넓힐 수 없다)에 있기 때문이다.
    """
    _check_rls()


def test_chk_2_check_rls_fails_without_force() -> None:
    """chk-2 — A 등급 테이블에서 FORCE를 빼면(ENABLE만 남김) check_rls가 그 테이블 이름과 함께 실패한다."""
    _owner_ddl("ALTER TABLE widget NO FORCE ROW LEVEL SECURITY")
    try:
        with pytest.raises(CommandError, match="widget"):
            _check_rls()
    finally:
        _owner_ddl("ALTER TABLE widget FORCE ROW LEVEL SECURITY")


def test_chk_3_check_rls_fails_without_policy() -> None:
    """chk-3 — A 등급 테이블의 정책 tenant_isolation을 지우면 check_rls가 그 테이블 이름과 함께 실패한다.

    복원은 rls_policies("widget")의 forward 연산을 다시 적용한다(ENABLE · FORCE는 멱등, 정책은 지웠으니 새로
    만들어진다). 0002를 되돌리는 방법(migrate testapp 0001)은 reverse의 DROP POLICY가 이미 지운 정책에서
    실패할 수 있어 쓰지 않는다.
    """
    _owner_ddl("DROP POLICY tenant_isolation ON widget")
    try:
        with pytest.raises(CommandError, match="widget"):
            _check_rls()
    finally:
        _reapply_rls_policies("widget")


def test_chk_4_check_rls_fails_on_unlisted_table() -> None:
    """chk-4 — 허용 목록 밖의 테이블이 RLS 없이 있으면 check_rls가 그 테이블 이름과 함께 실패한다."""
    _owner_ddl("CREATE TABLE rogue (id integer)")
    try:
        with pytest.raises(CommandError, match="rogue"):
            _check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS rogue")


def test_chk_5_check_rls_fails_when_rls_disabled() -> None:
    """chk-5 — A 등급 테이블의 RLS를 DISABLE하면(FORCE 플래그는 남아도) check_rls가 그 테이블 이름과 함께 실패한다.

    pg_class.relrowsecurity와 relforcerowsecurity는 독립 플래그이고 RLS가 DISABLE이면 정책이 전부 무시된다 —
    check_rls는 둘 다 읽어야 한다(FORCE 플래그만으로는 부족 · 리뷰 r1 A-1).
    """
    _owner_ddl("ALTER TABLE widget DISABLE ROW LEVEL SECURITY")
    try:
        with pytest.raises(CommandError, match="widget"):
            _check_rls()
    finally:
        _owner_ddl("ALTER TABLE widget ENABLE ROW LEVEL SECURITY")


def test_mw_1_header_tenant_scopes_rows() -> None:
    """mw-1 — request.tenant_id(A)가 있으면 미들웨어가 요청 트랜잭션에 A 컨텍스트를 둔다 → A 행만 보인다."""
    _seed_widgets()
    response = Client().get("/widgets/count", HTTP_X_TEST_TENANT=str(TENANT_A))
    assert response.status_code == 200
    assert response.json() == {"count": 2, "tenant_ids": [str(TENANT_A)]}


def test_mw_2_missing_tenant_403() -> None:
    """mw-2 — request.tenant_id가 없고 면제 경로도 아니면 403이다(뷰에 닿지 않는다)."""
    response = Client().get("/widgets/count")
    assert response.status_code == 403


def test_mw_3_exempt_healthz() -> None:
    """mw-3 — 헬스 경로(settings.TENANT_CONTEXT_EXEMPT_PATHS)는 테넌트 없이 200이다."""
    response = Client().get("/healthz")
    assert response.status_code == 200
    assert response.content == b"ok"


def test_mw_4_set_config_is_local_no_leak() -> None:
    """mw-4 — set_config(…, true)는 요청 트랜잭션이 끝나면 사라진다: 같은 DB 세션의 다음 요청·쿼리로 새지 않는다.

    같은 세션에서 GUC가 한 번 설정된 뒤에는 current_setting(…, true)가 NULL이 아니라 ''를 돌려준다 —
    정책이 ''를 uuid로 캐스트하다 오류를 내지 않고 0행이어야 한다(NULLIF 등).
    """
    _seed_widgets()
    client = Client()
    conn = connections["default"]
    with conn.cursor() as cursor:
        cursor.execute("SELECT pg_backend_pid()")
        (pid_before,) = cursor.fetchone()
    assert client.get("/widgets/count", HTTP_X_TEST_TENANT=str(TENANT_A)).status_code == 200
    with conn.cursor() as cursor:
        cursor.execute("SELECT pg_backend_pid(), current_setting('app.tenant_id', true)")
        pid_after, leaked = cursor.fetchone()
    assert pid_after == pid_before  # 같은 세션이어야 누출 검사가 뜻이 있다
    assert leaked in (None, "")
    assert client.get("/widgets/count").status_code == 403
    assert Widget.objects.count() == 0


def test_mw_5_streaming_response_warns() -> None:
    """mw-5 — StreamingHttpResponse는 본문이 트랜잭션 밖에서 만들어지므로 미들웨어가 RuntimeWarning을 낸다."""
    with pytest.warns(RuntimeWarning, match="StreamingHttpResponse"):
        response = Client().get("/widgets/stream", HTTP_X_TEST_TENANT=str(TENANT_A))
    assert response.status_code == 200
    assert b"".join(response.streaming_content) == b"x"
