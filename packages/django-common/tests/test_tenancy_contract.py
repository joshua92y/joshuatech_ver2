"""django_common.tenancy · django_common.problem 계약 시험(T068 · D11 · r2 · r3 · r4 · r5) — T060 test_tenancy.py가
고정하지 않은 결정을 가른다.

설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T068」(D2–D10 · tc-1..19) · 「### T068 r2」(F1–F12 ·
tc-20..29) · 「### T068 r3」(G1–G7 · tc-30) · 「### T068 r3 결과 · r4 결정」(H1–H6 · tc-31 · tc-14 · tc-24 개정) ·
「### T068 r4 결과 · r5 결정」(I1–I5 · tc-31 확장 · tc-24 I3 · I4 · tc-30 문구 I5) 절. 계약: contracts/pod-template.md
§테이블 등급(「T068 r4」 · 「T068 r5」 표식 포함) · §런타임 계약 「DB 연결」 · §공개 API(T068 보정 2026-11-04 · T068 r2 · r3) ·
contracts/identity-admin-api.md §오류 슬러그.

- 미들웨어(D3 · D4 · D5 · D6): 403 tenant_required problem+json(tc-1) · 면제 경로 = DB 무접촉(tc-2) · 면제 목록을 요청마다
  읽음 + 라이브러리 기본 헬스 3(tc-3) · path_info 정확 일치(tc-4) · 설정 형식 · 메시지에 값 없음(tc-5) · tenant_id 타입(tc-6) ·
  뷰 예외 롤백 / 예외 없이 돌려준 500 커밋 / 200 커밋(tc-7..9) · durable = 요청 트랜잭션이 가장 바깥(tc-10) · 면제 경로 뷰
  예외는 원래 타입 그대로(tc-27).
- 컨텍스트 도우미(D8 · F6 · F9): set_tenant_context · current_tenant_id(tc-11) · 범위 도우미 tenant_context(tc-23) · using
  별칭 한정(tc-25).
- rls_policies(D9): 이름 검증 · reversible · 0002 되돌리기와 다시 적용(tc-12).
- check_rls(D10 · F1–F5 · F7 · F8 · G1–G4 · H1–H4 · I1–I5): B 테이블 RLS 켜짐(tc-13) · tenant_isolation 밖의 정책 =
  PERMISSIVE · RESTRICTIVE 모두 위반(tc-14 · H2) · 뷰 · 구체화 뷰 · 이름만 같은 뷰(tc-15) · 정책 모양 · 대상 PUBLIC · 식
  정본(고정 search_path 포함) · 정본 정책의 pg_depend · 정본 없는 PG 주 버전(tc-16) · 명령 · 함수 · 상수 · 위반 전부 보고 ·
  다른 스키마의 같은 이름 · ASCII 성공 줄(tc-17) · 모델 검사(tc-20) · owner가 만든 확장(tc-21) · SECURITY DEFINER 함수 ·
  재작성 규칙(tc-22) · --require-rls-role = session_user 멤버십(SET ROLE 포함) · 스캔 범위 관계 소유(H4 — 단독 신호 사례
  I3) · 판정 SQL 원문(H3)(tc-24) · 분할 표(tc-26) · 다른 세션의 TEMP 표(tc-28) · Django 스키마 유일성(기대 집합은
  카탈로그에서 · tc-29) · 정책 의존(사유 = 표 · 열 밖의 사용자 객체 · initdb 후반 객체 — I5) · 스캔 search_path 고정(tc-30 —
  암시적 형변환 · NULLIF 안의 연산자 · 도메인 연산자 · 적대적 search_path · 바깥 atomic 안 복원) · 상속 · 파티션 링크의 양쪽
  등급(tc-31 — A 표의 비-A 부모 H1 · relkind p 자식 I2 · A 분할 표의 허용 목록 · 프레임워크 이름 파티션 I1 · 한 트리의 두
  방향은 각자 한 줄).
- 검사 범위의 경계(계약 r4): check_rls는 RLS의 카탈로그 모양(관계 등급 · 정책 모양과 식 · 상속) · 소유자 권한으로 도는 객체 ·
  런타임 role을 본다. 데이터 흐름(트리거 · 애플리케이션 코드가 A 행을 B 표로 옮기기)은 시험하지 않는다 — 마이그레이션 ·
  코드 리뷰 몫이다.
- 모델(D2): makemigrations --check = 손으로 쓴 0001과 같음(tc-18). problem_response(D5): tc-19.

DB 별칭 · 시드 · DDL 토글은 T060과 같다: default = app role(NOBYPASSRLS · 런타임) · owner = owner role(BYPASSRLS · 시드 ·
DDL). 다른 연결은 커밋된 것만 보인다 → 시드와 DDL은 owner 연결의 autocommit으로 하고 토글은 try/finally로 되돌린다(스키마는
세션 내내 공유된다). owner 연결로만 보는 판정(tc-29)은 owner의 atomic 안에서 DDL을 하고 롤백한다. owner 세션 상태(SET
search_path · SET ROLE — tc-24 · tc-30)는 다음 시험으로 새지 않게 finally에서 RESET한다(시험 Client는 연결을 닫지 않는다).
tc-24가 app에 준 public CREATE 권한도 finally에서 REVOKE한다(DROP이 실패해도 돈다 — 중첩 try · I4). 예약 이름(허용 목록 ·
프레임워크 이름 — tenant_membership · django_session)으로 public에 표를 만드는 사례(tc-31)는 teardown이 이름으로 지우므로
만들기 전에(try 앞) 그 이름의 관계가 없음을 단언한다(뒤 과제가 이 시험 DB에 더한 같은 이름의 표를 지우지 않게 · I4).
urlconf · MIDDLEWARE · 면제 설정은 pytest-django settings 픽스처로 시험 안에서만 바꾼다(tenancy_settings). pytest는 한 번에
하나만 돌린다(같은 이미지 태그 · 컨테이너 경합).
"""

from __future__ import annotations

import io
import json
import re
import uuid
from typing import TYPE_CHECKING

import pytest
from django.apps import apps
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import connections, migrations, models, transaction
from django.db.migrations.state import ProjectState
from django.db.transaction import TransactionManagementError
from django.test import Client
from django.test.utils import CaptureQueriesContext, isolate_apps

from django_common import tenancy
from django_common.problem import problem_response
from django_common.tenancy import (
    FRAMEWORK_TABLES,
    GLOBAL_TABLE_ALLOWLIST,
    GlobalModel,
    TenantContextMiddleware,
    TenantModel,
    check_rls,
    current_tenant_id,
    rls_policies,
    set_tenant_context,
)
from tests._problem import assert_problem, problem_type
from tests._tenant import set_tenant
from tests.tenancyapp.views import IntentionalViewError
from tests.testapp.models import GlobalThing, Widget

if TYPE_CHECKING:
    from pytest_django import DjangoDbBlocker
    from pytest_django.fixtures import Settings

    from tests.conftest import PgInfo

pytestmark = pytest.mark.django_db(transaction=True, databases=["default", "owner"])

TENANT_A = uuid.UUID("00000000-0000-4000-8000-00000000000a")
TENANT_B = uuid.UUID("00000000-0000-4000-8000-00000000000b")

TENANCY_URLCONF = "tests.tenancyapp.urls"
HEADER_TENANT_MIDDLEWARE = "tests.testapp.middleware.HeaderTenantMiddleware"
RAW_TENANT_MIDDLEWARE = "tests.tenancyapp.middleware.RawTenantMiddleware"
TENANCY_MIDDLEWARE = "django_common.tenancy.TenantContextMiddleware"
HEALTH_PATHS = ("/healthz", "/ready", "/health")
# data-model §7 정책 식 — tc-16이 모양만 바꾼 tenant_isolation을 같은 식으로 다시 만든다.
POLICY_EXPR = "tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid"
# PG 18이 POLICY_EXPR를 저장한 뒤 pg_get_expr로 되살린 정본(계약 §테이블 등급 ③ — r1 vd-probe 실측 · tc-16이 다시 잰다).
CANONICAL_PG18 = "(tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)"
# 성공 줄은 ASCII 하이픈이다(cp949 콘솔에 리디렉트해도 인코딩된다 — F8).
SUCCESS_LINE = re.compile(r"check_rls: OK - A 등급 (\d+) · B 등급 (\d+) · 프레임워크 (\d+)\n")
# check_rls 스캔 조건(G3 b) — search_path를 pg_catalog로 고정한다(is_local · 트랜잭션 롤백으로 되돌린다).
PIN_SEARCH_PATH = "SELECT pg_catalog.set_config('search_path', 'pg_catalog', true)"
# 정책 의존 검사(G3 a · 문구 I5 — 표 · 열 밖의 객체 = 사용자 객체와 initdb 후반 객체)와 연결 role 단언(G4 · H4 — 판정은
# boolean 하나라 한 줄에 두 조건을 함께 적는다)의 위반 사유 조각.
DEPENDENCY_REASON = "표 · 열 밖의 객체(사용자 객체 · initdb 후반 객체 - 연산자 · 함수 · 타입 · 콜레이션 · 형변환)에 의존한다(pg_depend)"
ROLE_REASON = "superuser · BYPASSRLS role이거나 그 멤버다"
OWNER_REASON = "또는 스캔 범위 관계의 소유자(그 멤버)다 - 소유자는 NO FORCE · DROP POLICY로 RLS를 끌 수 있다"
# A 표의 정책은 tenant_isolation 하나뿐이다(H2) · 상속 · 파티션 링크의 양쪽 등급이 같아야 한다 — A 표(r · p)의 부모는 A 등급
# (H1 · 그 A 표 이름으로 한 줄) · A 표의 자식도 A 등급(I1 · B · 프레임워크로 판정된 그 자식 이름으로 한 줄) — 위반 사유 조각.
OTHER_POLICY_REASON = "A 등급 표의 정책은 tenant_isolation 하나뿐이다"
PARENT_REASON = "부모를 거친 질의에는 부모의 RLS만 적용되어 이 표의 행이 RLS 없이 읽힌다"
CHILD_REASON = "이 관계를 직접 읽는 질의에는 이 관계의 RLS만 적용되어"
# 연결 role 단언 SQL 원문(H3 — tc-24가 tenancy._RLS_ROLE_SQL과 글자 그대로 비교한다): 한 문장 · 한 boolean · 이름은 전부
# pg_catalog로 한정 · 바인딩과 % 없음. 앞 EXISTS = session_user가 superuser · BYPASSRLS role이거나 그 멤버(G4) · 뒤 EXISTS =
# 스캔 범위(_RELATIONS_SQL과 같은 FROM · WHERE) 관계의 relowner이거나 그 멤버(H4). NOBYPASSRLS session_user가 BYPASSRLS role의
# 멤버인 양성 사례는 superuser 없이 만들 수 없어 시험 DB로 가르지 못한다 — `r.rolname = session_user` · 'SET' 같은 변이는 이
# 원문 비교가 잡는다(멤버십 양성 실측은 T072/T075 라이브 · build-notes r4 H3).
RLS_ROLE_SQL = """
SELECT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles AS r
  WHERE (r.rolsuper OR r.rolbypassrls) AND pg_catalog.pg_has_role(session_user, r.oid, 'MEMBER')
) OR EXISTS (
SELECT 1
FROM pg_catalog.pg_class AS c
JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
WHERE c.relkind IN ('r', 'p', 'v', 'm', 'f')
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT pg_catalog.starts_with(n.nspname::pg_catalog.text, 'pg_toast')
  AND NOT pg_catalog.starts_with(n.nspname::pg_catalog.text, 'pg_temp_')
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_depend AS d
    JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
    JOIN pg_catalog.pg_roles AS ext_owner ON ext_owner.oid = e.extowner
    WHERE d.classid = 'pg_catalog.pg_class'::pg_catalog.regclass
      AND d.objid = c.oid
      AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
      AND d.deptype = 'e'
      AND ext_owner.rolsuper
  )
  AND pg_catalog.pg_has_role(session_user, c.relowner, 'MEMBER')
)
"""
# tc-30 실측 deparse(PG 18.6) — 연산자 인자의 암시적 형변환은 보이고(ruleutils가 연산자 인자를 showimplicit로 찍는다), pg_catalog로
# 고정한 search_path에서는 public의 사용자 연산자가 스키마를 붙여 찍힌다.
IMPLICIT_CAST_DEPARSE = "((tenant_id)::uuid = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)"
DOMAIN_OPERATOR_DEPARSE = (
    "(tenant_id OPERATOR(public.=) (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)"
)


@pytest.fixture
def tenancy_settings(settings: Settings) -> Settings:
    """ROOT_URLCONF = tests.tenancyapp.urls · MIDDLEWARE = HeaderTenant(T060) → TenantContextMiddleware(테스트 뒤 복원).

    Client는 첫 요청 때 미들웨어를 적재하고 그 인스턴스를 계속 쓴다 — MIDDLEWARE를 바꾼 뒤에는 새 Client를 만든다.
    면제 설정 TENANT_CONTEXT_EXEMPT_PATHS는 tests/settings.py 값(헬스 3)에서 시작한다.
    """
    settings.ROOT_URLCONF = TENANCY_URLCONF
    settings.MIDDLEWARE = [HEADER_TENANT_MIDDLEWARE, TENANCY_MIDDLEWARE]
    return settings


def _seed_widgets() -> None:
    """owner(BYPASSRLS)로 tenant A 2행 · tenant B 3행을 만든다(autocommit → 다른 연결에서 보인다)."""
    for name in ("a1", "a2"):
        Widget.objects.using("owner").create(tenant_id=TENANT_A, name=name)
    for name in ("b1", "b2", "b3"):
        Widget.objects.using("owner").create(tenant_id=TENANT_B, name=name)


def _owner_ddl(statement: str) -> None:
    """owner 연결에서 DDL을 실행한다(autocommit — 곧바로 커밋되어 check_rls의 연결에서 보인다)."""
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement)


def _apply_rls(table: str) -> None:
    """rls_policies(table) 정방향 연산을 owner 연결의 schema editor로 적용한다(마이그레이션과 같은 SQL)."""
    state = ProjectState()
    with connections["owner"].schema_editor() as editor:
        for operation in rls_policies(table):
            operation.database_forwards("testapp", editor, state, state)


def _restore_widget_rls() -> None:
    """widget의 RLS를 rls_policies("widget") 정방향 그대로 되돌린다(정책을 먼저 IF EXISTS로 지우고 ENABLE · FORCE · 정책)."""
    _owner_ddl("DROP POLICY IF EXISTS tenant_isolation ON widget")
    _apply_rls("widget")


def _assert_absent(*names: str) -> None:
    """예약 이름(허용 목록 · 프레임워크 이름)으로 public에 표를 만들기 전에 그 이름의 관계가 public에 없음을 단언한다(I4).

    그 사례의 teardown은 이름으로 지운다(DROP TABLE IF EXISTS) — 만들기가 이름 충돌로 실패하면 이미 있던 표(뒤 과제가 이 시험
    DB에 더한 같은 이름의 표 등)를 지우게 된다. 그래서 try 앞에서 부른다(단언이 실패하면 teardown이 돌지 않는다).
    """
    with connections["owner"].cursor() as cursor:
        cursor.execute(
            "SELECT c.relname FROM pg_catalog.pg_class AS c"
            " JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace"
            " WHERE n.nspname = 'public' AND c.relname = ANY(%s)",
            [list(names)],
        )
        assert cursor.fetchall() == []


def _raw_guc() -> str | None:
    """default 연결의 GUC 원문 current_setting('app.tenant_id', true) — 미정의 세션은 NULL, 한 번 설정된 세션은 ''."""
    with connections["default"].cursor() as cursor:
        cursor.execute("SELECT current_setting('app.tenant_id', true)")
        (value,) = cursor.fetchone()
    return value


def _tables(violations: list[str]) -> set[str]:
    """위반 문장들의 이름 집합(문장 = `<이름>: <사유>` — 이름은 테이블 · 함수 이름이다)."""
    return {line.split(": ", 1)[0] for line in violations}


def _violation_tables(using: str = "default") -> set[str]:
    """check_rls(using=…) 위반 문장들의 이름 집합."""
    return _tables(check_rls(using=using))


def _assert_reasons(violations: list[str], table: str, reasons: tuple[str, ...]) -> None:
    """위반이 table 하나뿐이고 사유가 정확히 reasons다(사유 하나당 한 줄 · 조각마다 정확히 한 줄)."""
    assert _tables(violations) == {table}
    assert len(violations) == len(reasons)
    for reason in reasons:
        assert sum(reason in line for line in violations) == 1


def _search_path(using: str = "owner") -> str:
    """그 별칭 세션의 지금 search_path(SHOW)."""
    with connections[using].cursor() as cursor:
        cursor.execute("SHOW search_path")
        (value,) = cursor.fetchone()
    return value


def _policy_deparse(table: str, *, pinned: bool, using: str = "default") -> tuple[str, str]:
    """public.<table>의 tenant_isolation USING · WITH CHECK deparse(pg_get_expr). pinned면 check_rls 스캔처럼 search_path를
    pg_catalog로 고정한 트랜잭션에서 읽는다 — 어느 쪽이든 트랜잭션은 롤백한다(고정이 세션에 남지 않는다)."""
    with transaction.atomic(using=using):
        with connections[using].cursor() as cursor:
            if pinned:
                cursor.execute(PIN_SEARCH_PATH)
            cursor.execute(
                "SELECT pg_catalog.pg_get_expr(p.polqual, p.polrelid),"
                " pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid) FROM pg_catalog.pg_policy AS p"
                " WHERE p.polrelid = %s::pg_catalog.regclass AND p.polname = 'tenant_isolation'",
                [f"public.{table}"],
            )
            (row,) = cursor.fetchall()
        transaction.set_rollback(True, using=using)
    return (row[0], row[1])


class _Boom(Exception):
    """tc-23 — tenant_context 블록 안에서 일부러 내는 예외."""


def test_tc_1_missing_tenant_is_problem_403(tenancy_settings: Settings) -> None:
    """tc-1(D3-2 · D5) — 면제 밖 경로에 tenant_id가 없으면 RFC 9457 403 tenant_required(본문 = type · title · status만).

    미들웨어는 problem_response를 돌려준다 — PermissionDenied를 올리면 handler403이 forbidden(기본 HTML)으로 바꾼다(M21).
    """
    response = Client().get("/context")
    body = assert_problem(response, 403, "tenant_required")
    assert body == {"type": problem_type("tenant_required"), "title": "Forbidden", "status": 403}


def test_tc_2_exempt_path_touches_no_db(
    tenancy_settings: Settings, django_db_blocker: DjangoDbBlocker
) -> None:
    """tc-2(D3-1 · 사실 ⑤) — 면제 경로는 atomic · 쿼리 0이다: DB 접근을 막아도(pytest-django block) 200 · 뷰 안의
    in_atomic_block 거짓 · CaptureQueriesContext 쿼리 0. tenant_id가 있어도(뷰가 UUID 타입을 비춘다) 면제 판정이 먼저다.

    양성 대조: 면제 밖(/context · 테넌트 A)에서는 같은 꼴의 관찰이 in_atomic_block 참 · GUC = str(A)다 — 관찰이 공허하지 않다.
    M10(면제 경로에서도 atomic): Atomic.__enter__의 ensure_connection이 막혀 실패한다(T066 api-1 · api-4 · /healthz 외부 조회 0).
    """
    client = Client()
    control = client.get("/context", HTTP_X_TEST_TENANT=str(TENANT_A))
    assert control.status_code == 200
    assert control.json() == {"in_atomic_block": True, "guc": str(TENANT_A)}
    with CaptureQueriesContext(connections["default"]) as captured, django_db_blocker.block():
        responses = [client.get("/healthz"), client.get("/healthz", HTTP_X_TEST_TENANT=str(TENANT_A))]
    assert [response.status_code for response in responses] == [200, 200]
    assert [response.json() for response in responses] == [
        {"in_atomic_block": False, "tenant_id_type": "NoneType"},
        {"in_atomic_block": False, "tenant_id_type": "UUID"},
    ]
    assert len(captured) == 0


def test_tc_3_exempt_paths_read_per_request(tenancy_settings: Settings) -> None:
    """tc-3(D4 · 규칙 §Settings) — TENANT_CONTEXT_EXEMPT_PATHS는 요청마다 django.conf.settings에서 읽는다(같은 Client = 같은
    미들웨어 인스턴스): 실행 중 바꾼 값이 다음 요청에 적용되고, 설정을 지우면 라이브러리 기본(헬스 3)이 적용된다.

    M7(import 시점 · __init__ 캐시)이면 바꾼 값이 무시된다. 기본값이 헬스 3이 아니면 마지막 단계가 깨진다.
    """
    client = Client()
    assert_problem(client.get("/custom-exempt"), 403, "tenant_required")
    tenancy_settings.TENANT_CONTEXT_EXEMPT_PATHS = ["/custom-exempt"]
    assert client.get("/custom-exempt").status_code == 200
    assert_problem(client.get("/healthz"), 403, "tenant_required")
    del tenancy_settings.TENANT_CONTEXT_EXEMPT_PATHS
    assert [client.get(path).status_code for path in HEALTH_PATHS] == [200, 200, 200]
    assert_problem(client.get("/custom-exempt"), 403, "tenant_required")


def test_tc_4_exempt_match_is_exact_on_path_info(tenancy_settings: Settings) -> None:
    """tc-4(D4) — 면제 판정은 request.path_info 정확 일치다(auth 면제와 같은 규칙).

    끝 슬래시 · 접두 · 대소문자가 다르면 면제가 아니다 → URL 해석 전 403(M5 startswith라면 면제 → 404). SCRIPT_NAME 접두로
    request.path가 달라져도 path_info가 같으면 면제다(M6 request.path라면 403).
    """
    client = Client()
    for path in ("/healthz/", "/healthzz", "/healthz/x", "/HEALTHZ"):
        assert_problem(client.get(path), 403, "tenant_required")
    response = client.get("/healthz", SCRIPT_NAME="/prefix")
    assert (response.wsgi_request.path, response.wsgi_request.path_info) == ("/prefix/healthz", "/healthz")
    assert response.status_code == 200


@pytest.mark.parametrize(
    "value",
    ["/healthz", b"/healthz", ("/healthz", 1), None, {"/healthz": True}],
    ids=["str", "bytes", "non-str-member", "none", "dict"],
)
def test_tc_5_exempt_setting_type_is_checked(tenancy_settings: Settings, value: object) -> None:
    """tc-5(D4 · F9 f) — 설정 값은 str만 담은 tuple · list · set · frozenset이어야 한다. 아니면 요청 때 ImproperlyConfigured다.
    str 하나는 `in`이 부분 문자열 검사가 되어 `/`까지 면제될 수 있다(M8 — 여기서는 /healthz가 면제로 통과).

    메시지는 설정 이름만 싣고 값은 싣지 않는다(규칙 §Settings — 기동 실패 메시지에 값 금지): 이름이 있고, 값의 repr과 값 안의
    경로 글자(healthz)가 없다.
    """
    tenancy_settings.TENANT_CONTEXT_EXEMPT_PATHS = value
    with pytest.raises(ImproperlyConfigured) as raised:
        Client().get("/healthz")
    message = str(raised.value)
    assert "TENANT_CONTEXT_EXEMPT_PATHS" in message
    assert "healthz" not in message
    assert repr(value) not in message


@pytest.mark.parametrize(
    "value",
    [("/healthz",), ["/healthz"], {"/healthz"}, frozenset({"/healthz"})],
    ids=["tuple", "list", "set", "frozenset"],
)
def test_tc_5_exempt_setting_accepts_str_collections(tenancy_settings: Settings, value: object) -> None:
    """tc-5(D4) 양성 — str만 담은 tuple · list · set · frozenset은 받아들인다(/healthz 면제 · 200)."""
    tenancy_settings.TENANT_CONTEXT_EXEMPT_PATHS = value
    assert Client().get("/healthz").status_code == 200


def test_tc_6_non_uuid_tenant_id_is_rejected(tenancy_settings: Settings) -> None:
    """tc-6(D3-2 · F9 e) — request.tenant_id가 uuid.UUID가 아니면(여기서는 UUID 글자의 str) fail-closed 403 tenant_required.

    양성 대조: 같은 원시 미들웨어 · 같은 헤더로 면제 경로를 부르면 뷰가 tenant_id 타입 str을 비춘다 — 대역이 정말 str을 둔다
    (403이 「속성 없음」 때문이 아니다). M9(isinstance 대신 truthy)라면 str이 통과한다. 운영에서 UUID가 아닌 클레임은 T070이
    401 invalid_token으로 먼저 끊는다.
    """
    tenancy_settings.MIDDLEWARE = [RAW_TENANT_MIDDLEWARE, TENANCY_MIDDLEWARE]
    client = Client()
    probe = client.get("/healthz", HTTP_X_TEST_RAW_TENANT=str(TENANT_A))
    assert probe.json() == {"in_atomic_block": False, "tenant_id_type": "str"}
    response = client.get("/context", HTTP_X_TEST_RAW_TENANT=str(TENANT_A))
    assert_problem(response, 403, "tenant_required")


def test_tc_7_view_exception_rolls_back(tenancy_settings: Settings) -> None:
    """tc-7(D6) — 뷰가 A 등급 행을 쓴 뒤 예외를 내면 500이고 쓴 행은 롤백된다(owner로 센 행 0).

    Django는 뷰 예외를 미들웨어 안쪽에서 500 응답으로 바꾼다(convert_exception_to_response) → 미들웨어의 atomic이 그대로
    커밋하지 않게 process_exception이 롤백을 표시한다(M2). 예외 종류(IntentionalViewError)로 쓰기 뒤의 예외임을 확인한다.
    """
    response = Client(raise_request_exception=False).get(
        "/widgets/write-raise", HTTP_X_TEST_TENANT=str(TENANT_A)
    )
    assert response.status_code == 500
    assert response.exc_info is not None
    assert response.exc_info[0] is IntentionalViewError
    assert Widget.objects.using("owner").count() == 0


def test_tc_8_returned_500_without_exception_commits(tenancy_settings: Settings) -> None:
    """tc-8(D6) — 뷰가 쓴 뒤 예외 없이 500 응답을 돌려주면 커밋한다(행 1) — ATOMIC_REQUESTS와 같은 뜻(문서화된 결정 ·
    Ninja HttpError처럼 뷰 안에서 응답이 된 오류도 이 경로다)."""
    response = Client().get("/widgets/write-500", HTTP_X_TEST_TENANT=str(TENANT_A))
    assert response.status_code == 500
    assert list(Widget.objects.using("owner").values_list("tenant_id", flat=True)) == [TENANT_A]


def test_tc_9_ok_response_commits(tenancy_settings: Settings) -> None:
    """tc-9(D6) 대조 — 뷰가 쓰고 200을 돌려주면 커밋한다(행 1 · 요청의 테넌트)."""
    response = Client().get("/widgets/write-ok", HTTP_X_TEST_TENANT=str(TENANT_A))
    assert response.status_code == 200
    assert list(Widget.objects.using("owner").values_list("tenant_id", flat=True)) == [TENANT_A]


def test_tc_10_middleware_transaction_is_outermost(tenancy_settings: Settings) -> None:
    """tc-10(D3 · D6) — 미들웨어의 atomic은 durable이다: 다른 atomic 안에서 부르면 RuntimeError(요청 트랜잭션이 가장 바깥임을
    강제 · M1). transaction=True 시험이라 바깥 블록은 TestCase 블록이 아니다(Django는 그 경우만 durable 중첩을 허용한다).
    미들웨어는 sync 전용이다(sync_capable 참 · async_capable 거짓).
    """
    assert (TenantContextMiddleware.sync_capable, TenantContextMiddleware.async_capable) == (True, False)
    client = Client()
    with transaction.atomic(using="default"):
        with pytest.raises(RuntimeError, match="durable"):
            client.get("/context", HTTP_X_TEST_TENANT=str(TENANT_A))


def test_tc_11_context_helpers() -> None:
    """tc-11(D8) — set_tenant_context / current_tenant_id.

    - atomic 밖 set_tenant_context → TransactionManagementError(트랜잭션 밖의 set_config(…, true)는 조용히 무효다 · M22).
    - 새 세션(GUC 미정의 = NULL) → current_tenant_id() None.
    - atomic 안: set_tenant_context(A) → current_tenant_id() == A · A 등급 2행 / T060 헬퍼 set_tenant(B)로 쓴 값도 읽는다(같은
      GUC) / set_tenant_context(None) → None · A 등급 0행(GUC '' → 정책의 NULLIF · M3).
    - 트랜잭션이 끝난 같은 연결: GUC 원문 '' → current_tenant_id() None('' 경로).
    - str 인자 → TypeError · GUC가 UUID가 아니면 current_tenant_id() → ValueError.
    """
    _seed_widgets()
    connection = connections["default"]
    with pytest.raises(TransactionManagementError):
        set_tenant_context(TENANT_A)
    connection.close()  # 다음 쿼리가 새 세션을 연다 → app.tenant_id 미정의(NULL)
    assert _raw_guc() is None
    assert current_tenant_id() is None
    with transaction.atomic(using="default"):
        set_tenant_context(TENANT_A)
        assert current_tenant_id() == TENANT_A
        assert Widget.objects.count() == 2
        set_tenant("default", TENANT_B)
        assert current_tenant_id() == TENANT_B
        set_tenant_context(None)
        assert current_tenant_id() is None
        assert Widget.objects.count() == 0
    assert _raw_guc() == ""
    assert current_tenant_id() is None
    with transaction.atomic(using="default"):
        with pytest.raises(TypeError):
            set_tenant_context(str(TENANT_A))  # type: ignore[arg-type]
        with connection.cursor() as cursor:
            cursor.execute("SELECT set_config('app.tenant_id', %s, true)", ["not-a-uuid"])
        with pytest.raises(ValueError):
            current_tenant_id()


def test_tc_12_rls_policies_contract() -> None:
    """tc-12(D9) — rls_policies(table).

    - 이름: [a-z_][a-z0-9_]* · 63자 이하가 아니면 ValueError(마이그레이션 import 때 실패) — 63자는 통과.
    - 반환: 매번 새 목록 · RunSQL 3개 · 전부 reversible(M18 — reverse_sql이 없으면 0001로 되돌릴 수 없다).
    - owner로 migrate testapp 0001 → 0002 되돌리기(DROP POLICY IF EXISTS → NO FORCE → DISABLE) → app role이 컨텍스트 없이
      두 테넌트 행을 모두 본다 → migrate testapp → 복원(check_rls 통과 · 0행).
    - 정책이 이미 지워진 상태(드리프트)에서도 되돌리기가 된다(DROP POLICY IF EXISTS).
    finally: 0002 적용 + widget RLS를 rls_policies 정방향으로 다시 맞춘다.
    """
    for bad in ("Widget", "bad-name", 'we"ird', "", "1abc", "public.widget", "widget\n", "a" * 64):
        with pytest.raises(ValueError):
            rls_policies(bad)
    assert len(rls_policies("a" * 63)) == 3
    operations = rls_policies("widget")
    assert rls_policies("widget") is not operations
    assert [type(operation) for operation in operations] == [migrations.RunSQL] * 3
    assert all(operation.reversible for operation in operations)
    _seed_widgets()
    try:
        call_command("migrate", "testapp", "0001", database="owner", verbosity=0)
        assert Widget.objects.count() == 5
        assert "widget" in _violation_tables()
        call_command("migrate", "testapp", database="owner", verbosity=0)
        assert check_rls() == []
        assert Widget.objects.count() == 0
        _owner_ddl("DROP POLICY tenant_isolation ON widget")
        call_command("migrate", "testapp", "0001", database="owner", verbosity=0)
        call_command("migrate", "testapp", database="owner", verbosity=0)
        assert check_rls() == []
    finally:
        call_command("migrate", "testapp", database="owner", verbosity=0)
        _restore_widget_rls()


def test_tc_13_grade_b_table_with_rls_fails() -> None:
    """tc-13(D10 ②) — B 등급(허용 목록) 테이블은 RLS가 꺼져 있어야 한다: tenant에 RLS를 켜면 check_rls가 tenant만 위반으로
    보고하고 명령은 CommandError다(M13). 실측: RLS를 켠 B 테이블은 정책이 없어 app role이 0행을 본다(릴레이 · 웹훅이 0행).
    """
    GlobalThing.objects.using("owner").create(tenant_id=TENANT_A, label="a")
    GlobalThing.objects.using("owner").create(tenant_id=TENANT_B, label="b")
    _owner_ddl("ALTER TABLE tenant ENABLE ROW LEVEL SECURITY")
    try:
        assert GlobalThing.objects.count() == 0
        assert _violation_tables() == {"tenant"}
        with pytest.raises(CommandError, match="tenant: "):
            call_command("check_rls", stdout=io.StringIO(), stderr=io.StringIO())
    finally:
        _owner_ddl("ALTER TABLE tenant DISABLE ROW LEVEL SECURITY")
    assert GlobalThing.objects.count() == 2


def test_tc_14_any_other_policy_fails() -> None:
    """tc-14(D10 ③ · H2 · B3-4) — A 등급 표의 정책은 tenant_isolation 하나뿐이어야 한다: 다른 정책은 PERMISSIVE든 RESTRICTIVE든
    위반 한 줄이고, 그 줄에 다른 정책 이름을 정렬해 싣는다(이름 widget · M14 · P3).

    - RESTRICTIVE(extra_restrictive): r3까지는 격리를 좁히기만 한다고 보아 허용했다 → r4 위반(r3 구현 · P3이면 통과).
      RESTRICTIVE 식은 tenant_isolation보다 먼저 모든 행에 평가될 수 있다 — PG 18.6 실측(build-notes r4 VD): 순차 스캔 계획의
      Filter가 RESTRICTIVE 식을 앞에 두어, `(name)::integer > 0`이 컨텍스트 A인 app role의 질의에서 B 행 값을 담은 형변환
      오류를 낸다.
    - PERMISSIVE(extra_open): 실측 — OR로 합쳐져 컨텍스트 없는 app role이 5행 전부를 본다.
    - 둘 다 있으면 한 줄에 두 이름이다.
    finally에서 두 정책을 지운 뒤 통과.
    """
    _seed_widgets()
    try:
        _owner_ddl("CREATE POLICY extra_restrictive ON widget AS RESTRICTIVE FOR ALL USING (true)")
        violations = check_rls()
        _assert_reasons(violations, "widget", (OTHER_POLICY_REASON,))
        assert "정책이 있다(extra_restrictive)" in violations[0]
        _owner_ddl("CREATE POLICY extra_open ON widget FOR SELECT USING (true)")
        assert Widget.objects.count() == 5
        violations = check_rls()
        _assert_reasons(violations, "widget", (OTHER_POLICY_REASON,))
        assert "정책이 있다(extra_open, extra_restrictive)" in violations[0]
        _owner_ddl("DROP POLICY extra_restrictive ON widget")
        violations = check_rls()
        _assert_reasons(violations, "widget", (OTHER_POLICY_REASON,))
        assert "정책이 있다(extra_open)" in violations[0]
        violations[0].encode("cp949")
    finally:
        _owner_ddl("DROP POLICY IF EXISTS extra_open ON widget")
        _owner_ddl("DROP POLICY IF EXISTS extra_restrictive ON widget")
    assert check_rls() == []


@pytest.mark.parametrize(
    ("create_sql", "drop_sql"),
    [
        ("CREATE VIEW leak AS SELECT * FROM widget", "DROP VIEW IF EXISTS leak"),
        ("CREATE MATERIALIZED VIEW leak AS SELECT * FROM widget", "DROP MATERIALIZED VIEW IF EXISTS leak"),
    ],
    ids=["view", "materialized-view"],
)
def test_tc_15_view_is_a_violation(create_sql: str, drop_sql: str) -> None:
    """tc-15(D10 ③ · 사실 ⑪) — 범위 안의 뷰 · 구체화 뷰는 A 등급 표가 아니므로 위반(M15 · 이름 leak). 실측: owner가 만든 뷰는
    소유자 권한(BYPASSRLS)으로 기저 테이블을 읽어 컨텍스트 없는 app role에게 5행 전부를 보여 준다(구체화 뷰는 스냅샷이라
    RLS를 걸 수 없다).
    """
    _seed_widgets()
    _owner_ddl(create_sql)
    try:
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT count(*) FROM leak")
            assert cursor.fetchone() == (5,)
        assert _violation_tables() == {"leak"}
    finally:
        _owner_ddl(drop_sql)


@pytest.mark.parametrize(
    ("setup_sql", "teardown_sql", "name"),
    [
        (
            ["CREATE VIEW django_session AS SELECT * FROM widget"],
            ["DROP VIEW IF EXISTS django_session"],
            "django_session",
        ),
        (
            ["CREATE SCHEMA tc15", "CREATE VIEW tc15.django_session AS SELECT * FROM widget"],
            ["DROP SCHEMA IF EXISTS tc15 CASCADE"],
            "django_session",
        ),
        (
            ["CREATE VIEW session_revocation_log AS SELECT 1 AS id"],
            ["DROP VIEW IF EXISTS session_revocation_log"],
            "session_revocation_log",
        ),
    ],
    ids=["framework-name-view", "framework-name-view-other-schema", "grade-b-name-view"],
)
def test_tc_15_lookalike_views_are_grade_a(setup_sql: list[str], teardown_sql: list[str], name: str) -> None:
    """tc-15(F3 · A-5 · A-6 b · B-3) — 프레임워크 면제는 Django 스키마(django_migrations가 있는 스키마)의 표(r)만, B 등급은
    그 스키마의 표(r · p)만이다. 이름만 같은 뷰는 A 등급으로 판정되어 「표가 아니다」 위반이다: public의 django_session 뷰
    (contrib.sessions가 없는 pod) · 다른 스키마의 django_session 뷰 · B 이름 뷰(session_revocation_log — Django 스키마).

    B 이름은 outbox 대신 session_revocation_log를 쓴다: T069가 django_common에 outbox 표를 만들면 public에 같은 이름의 뷰를
    만들 수 없다(이 시험 DB의 INSTALLED_APPS에 django_common이 있다).
    """
    try:
        for statement in setup_sql:
            _owner_ddl(statement)
        violations = check_rls()
    finally:
        for statement in teardown_sql:
            _owner_ddl(statement)
    assert _tables(violations) == {name}
    assert all("relkind v" in line for line in violations)
    assert check_rls() == []


@pytest.mark.parametrize(
    ("policy_sql", "reasons"),
    [
        (
            f"CREATE POLICY tenant_isolation ON widget FOR SELECT USING ({POLICY_EXPR})",
            ("FOR ALL이 아니다", "WITH CHECK가 없다"),
        ),
        (f"CREATE POLICY tenant_isolation ON widget FOR ALL USING ({POLICY_EXPR})", ("WITH CHECK가 없다",)),
        (
            "CREATE POLICY tenant_isolation ON widget AS RESTRICTIVE FOR ALL"
            f" USING ({POLICY_EXPR}) WITH CHECK ({POLICY_EXPR})",
            ("PERMISSIVE가 아니다",),
        ),
        (f"CREATE POLICY tenant_isolation ON widget FOR ALL WITH CHECK ({POLICY_EXPR})", ("USING이 없다",)),
        (
            f"CREATE POLICY tenant_isolation ON widget FOR UPDATE USING ({POLICY_EXPR}) WITH CHECK ({POLICY_EXPR})",
            ("FOR ALL이 아니다",),
        ),
        (
            "CREATE POLICY tenant_isolation ON widget USING (true) WITH CHECK (true)",
            ("USING 식이 정본과 다르다", "WITH CHECK 식이 정본과 다르다"),
        ),
        (
            "CREATE POLICY tenant_isolation ON widget"
            " USING (tenant_id = current_setting('app.tenant_id', true)::uuid)"
            " WITH CHECK (tenant_id = current_setting('app.tenant_id', true)::uuid)",
            ("USING 식이 정본과 다르다", "WITH CHECK 식이 정본과 다르다"),
        ),
        (
            f"CREATE POLICY tenant_isolation ON widget USING (true) WITH CHECK ({POLICY_EXPR})",
            ("USING 식이 정본과 다르다",),
        ),
        (
            f"CREATE POLICY tenant_isolation ON widget USING ({POLICY_EXPR}) WITH CHECK (true)",
            ("WITH CHECK 식이 정본과 다르다",),
        ),
        (
            f"CREATE POLICY tenant_isolation ON widget TO <ROLE> USING ({POLICY_EXPR}) WITH CHECK ({POLICY_EXPR})",
            ("대상이 PUBLIC이 아니다",),
        ),
    ],
    ids=[
        "for-select",
        "no-with-check",
        "restrictive",
        "no-using",
        "for-update",
        "using-true",
        "no-nullif",
        "using-true-only",
        "check-true-only",
        "to-role",
    ],
)
def test_tc_16_policy_shape_is_checked(pg: PgInfo, policy_sql: str, reasons: tuple[str, ...]) -> None:
    """tc-16(D10 ③ · F1 · F2) — tenant_isolation은 FOR ALL(polcmd '*') · PERMISSIVE · 대상 PUBLIC · USING과 WITH CHECK
    둘 다 · 두 식이 정본과 정확히 같아야 한다. 모양마다 widget 위반이고 사유가 정확히 `reasons`다(사유 하나당 한 줄 — 검사
    하나만 지우는 변이 M16a–d도 사유 수로 잡힌다):

    - for-select · for-update: polcmd만이 근거인 모양은 for-update다(UPDATE만 USING과 WITH CHECK를 둘 다 가질 수 있다 · A-1).
    - using-true · no-nullif · using-true-only · check-true-only: 이름만 같은 정책(A-2 · B-1) — 식 비교만이 근거다.
    - to-role: TO <owner role>(픽스처의 role 이름) — polroles만이 근거다.
    finally 복원 뒤 통과.
    """
    _owner_ddl("DROP POLICY tenant_isolation ON widget")
    try:
        _owner_ddl(policy_sql.replace("<ROLE>", pg.owner_user))
        violations = check_rls()
    finally:
        _restore_widget_rls()
    assert _tables(violations) == {"widget"}
    assert len(violations) == len(reasons)
    for reason in reasons:
        assert sum(reason in line for line in violations) == 1
    assert check_rls() == []


def test_tc_16_canonical_expression_is_what_rls_policies_creates() -> None:
    """tc-16(F1 · G3) — rls_policies가 만든 widget 정책(0002)의 실측 deparse(pg_get_expr)가 정본 상수와 같다: USING = WITH CHECK =
    CANONICAL_PG18 = tenancy._CANONICAL_POLICY_EXPR[주 버전] · polcmd '*' · PERMISSIVE · polroles [0](PUBLIC). app role과
    owner가 같은 값을 읽는다(카탈로그 · 권한 무관) — 세션 search_path 그대로든 check_rls 스캔처럼 pg_catalog로 고정했든 같다(G3 b).
    정본 정책의 pg_depend 행은 pg_class(표 deptype 'a' · 열 tenant_id deptype 'n')뿐이다 — 정책 의존 검사(G3 a)가 정본을
    잡지 않는 근거(정본 식이 쓰는 연산자 · 함수 · 타입 · 콜레이션은 전부 initdb 부트스트랩 객체(OID < 12000)라 pinned — 행이
    없다 · initdb 후반 객체(OS 콜레이션 · 시스템 뷰 · information_schema · plpgsql)와 사용자 객체는 행을 남긴다 · build-notes G3 a
    정정). PG 주 버전이 바뀌어 deparse나 의존 행이 달라지면 이 시험이 먼저 깨진다.
    """
    query = (
        "SELECT pg_catalog.current_setting('server_version_num')::integer / 10000, p.polcmd, p.polpermissive,"
        " p.polroles, pg_catalog.pg_get_expr(p.polqual, p.polrelid),"
        " pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid)"
        " FROM pg_catalog.pg_policy AS p"
        " WHERE p.polrelid = 'public.widget'::pg_catalog.regclass AND p.polname = 'tenant_isolation'"
    )
    observed = {}
    for alias in ("default", "owner"):
        with connections[alias].cursor() as cursor:
            cursor.execute(query)
            observed[alias] = cursor.fetchall()
    assert observed["default"] == observed["owner"]
    [(major, command, permissive, roles, using_expr, check_expr)] = observed["default"]
    assert (major, command, permissive, roles) == (18, "*", True, [0])
    assert using_expr == CANONICAL_PG18
    assert check_expr == CANONICAL_PG18
    assert tenancy._CANONICAL_POLICY_EXPR[major] == CANONICAL_PG18
    for alias in ("default", "owner"):
        for pinned in (False, True):
            assert _policy_deparse("widget", pinned=pinned, using=alias) == (CANONICAL_PG18, CANONICAL_PG18)
    with connections["default"].cursor() as cursor:
        cursor.execute(
            "SELECT d.refclassid::pg_catalog.regclass::pg_catalog.text,"
            " CASE WHEN d.refobjsubid = 0 THEN NULL ELSE a.attname::pg_catalog.text END, d.deptype"
            " FROM pg_catalog.pg_depend AS d JOIN pg_catalog.pg_policy AS p ON p.oid = d.objid"
            " LEFT JOIN pg_catalog.pg_attribute AS a ON a.attrelid = d.refobjid AND a.attnum = d.refobjsubid"
            " WHERE d.classid = 'pg_catalog.pg_policy'::pg_catalog.regclass"
            " AND p.polrelid = 'public.widget'::pg_catalog.regclass AND p.polname = 'tenant_isolation'"
        )
        dependencies = set(cursor.fetchall())
    assert dependencies == {("pg_class", None, "a"), ("pg_class", "tenant_id", "n")}


def test_tc_16_unknown_pg_major_fails_closed(monkeypatch: pytest.MonkeyPatch) -> None:
    """tc-16(F1) — 정본이 정의되지 않은 PG 주 버전이면 식을 판정할 수 없으므로 A 등급 표(정책이 있는)마다 위반이다
    (fail-closed — 정본 추가는 계약 개정). 함수가 쓰는 주 버전(tenancy._server_major)을 19로 바꿔 끼운다. 대조: 18로
    바꿔 끼우면 통과한다(바꿔 끼우기 자체가 판정을 깨지 않는다).
    """
    monkeypatch.setattr(tenancy, "_server_major", lambda cursor: 18)
    assert check_rls() == []
    monkeypatch.setattr(tenancy, "_server_major", lambda cursor: 19)
    violations = check_rls()
    assert _tables(violations) == {"widget"}
    assert [("정본 정책 식이 없다" in line, "19" in line) for line in violations] == [(True, True)]


def test_tc_17_command_and_function_contract() -> None:
    """tc-17(D10 · F3 · F8 · G2) — 함수 · 명령 · 상수.

    - 상수: FRAMEWORK_TABLES = 정확한 이름 10 · GLOBAL_TABLE_ALLOWLIST = B 4(둘 다 frozenset — pod가 넓힐 수 없다) · 프레임워크
      이름을 쓸 수 있는 contrib 앱 = auth · contenttypes · sessions · admin(계약 ⑤ — 시험 settings에는 contenttypes만 있어
      모델 검사 시험만으로는 auth · sessions · admin을 빼는 변이가 살아남는다 · N5).
    - 깨끗한 DB: 함수 check_rls()가 app role(default) · owner 모두 [](using · --database가 쿼리를 그 별칭으로 보낸다 — 다른
      별칭 쿼리 0) · 명령 `--database owner`가 성공 한 줄 `check_rls: OK - A 등급 N · B 등급 M · 프레임워크 K`(ASCII 하이픈 ·
      cp949로 인코딩된다)를 stdout에 쓴다(시험 DB: A = widget · 프레임워크 = django_migrations · django_content_type · B는
      tenant와 뒤 과제의 outbox).
    - 위반이 여럿이면 함수는 전부를 돌려주고 명령은 전부를 담은 CommandError를 낸다(메시지도 cp949로 인코딩된다): rogue ·
      widget NO FORCE · 프레임워크처럼 보이는 이름 django_extra(정확한 이름만 면제 — 접두 규칙 없음) · public 밖 스키마의 표
      tc17.stray(시스템 스키마 밖 전부) · 다른 스키마의 프레임워크 이름 표 tc17.django_session과 B 이름 표 tc17.outbox(RLS
      없음 — 면제 · B는 Django 스키마의 표만 · F3).
    """
    assert isinstance(FRAMEWORK_TABLES, frozenset)
    assert FRAMEWORK_TABLES == {
        "django_migrations",
        "django_content_type",
        "django_session",
        "django_admin_log",
        "auth_permission",
        "auth_group",
        "auth_group_permissions",
        "auth_user",
        "auth_user_groups",
        "auth_user_user_permissions",
    }
    assert isinstance(GLOBAL_TABLE_ALLOWLIST, frozenset)
    assert GLOBAL_TABLE_ALLOWLIST == {"tenant", "tenant_membership", "outbox", "session_revocation_log"}
    assert tenancy._CONTRIB_APP_LABELS == frozenset({"auth", "contenttypes", "sessions", "admin"})
    assert check_rls() == []
    # 두 별칭은 같은 물리 DB라 결과만으로는 별칭 선택을 가를 수 없다 → 쿼리가 실제로 어느 연결로 갔는지 센다.
    with (
        CaptureQueriesContext(connections["owner"]) as on_owner,
        CaptureQueriesContext(connections["default"]) as on_default,
    ):
        assert check_rls(using="owner") == []
    assert (len(on_owner) > 0, len(on_default)) == (True, 0)
    stdout = io.StringIO()
    with (
        CaptureQueriesContext(connections["owner"]) as on_owner,
        CaptureQueriesContext(connections["default"]) as on_default,
    ):
        call_command("check_rls", "--database", "owner", stdout=stdout, stderr=io.StringIO())
    assert (len(on_owner) > 0, len(on_default)) == (True, 0)
    match = SUCCESS_LINE.fullmatch(stdout.getvalue())
    assert match is not None
    stdout.getvalue().encode("cp949")
    grade_a, grade_b, framework = (int(group) for group in match.groups())
    assert (grade_a, framework) == (1, 2)
    assert grade_b >= 1
    expected = {"rogue", "django_extra", "stray", "widget", "django_session", "outbox"}
    try:
        # 준비 DDL도 try 안에 둔다 — 중간에 실패해도 finally(IF EXISTS)가 이미 만든 것을 지운다(뒤 테스트로 새지 않게).
        _owner_ddl("CREATE TABLE rogue (id integer)")
        _owner_ddl("CREATE TABLE django_extra (id integer)")
        _owner_ddl("CREATE SCHEMA tc17")
        _owner_ddl("CREATE TABLE tc17.stray (id integer)")
        _owner_ddl("CREATE TABLE tc17.django_session (id integer)")
        _owner_ddl("CREATE TABLE tc17.outbox (id integer)")
        _owner_ddl("ALTER TABLE widget NO FORCE ROW LEVEL SECURITY")
        assert _violation_tables() == expected
        with pytest.raises(CommandError) as raised:
            call_command("check_rls", stdout=io.StringIO(), stderr=io.StringIO())
        message = str(raised.value)
        for table in sorted(expected):
            assert f"{table}: " in message
        message.encode("cp949")
    finally:
        _owner_ddl("DROP TABLE IF EXISTS rogue")
        _owner_ddl("DROP TABLE IF EXISTS django_extra")
        _owner_ddl("DROP SCHEMA IF EXISTS tc17 CASCADE")
        _owner_ddl("ALTER TABLE widget FORCE ROW LEVEL SECURITY")


def test_tc_18_tenant_model_matches_initial_migration() -> None:
    """tc-18(D2 · 사실 ②) — TenantModel 모양(id UUID PK default uuid4 · tenant_id UUIDField · 인덱스 (tenant_id, id) 이름
    `%(class)s_tenant_id_idx`) = 손으로 쓴 testapp 0001: `makemigrations testapp --check --dry-run` 변경 없음(M19 — 자동
    인덱스 이름이면 RenameIndex가 나온다).
    """
    stdout = io.StringIO()
    try:
        call_command("makemigrations", "testapp", "--check", "--dry-run", stdout=stdout, stderr=io.StringIO())
    except SystemExit as exc:
        pytest.fail(f"makemigrations --check가 변경을 찾았다(exit {exc.code}): {stdout.getvalue()}")
    assert "No changes detected in app 'testapp'" in stdout.getvalue()


def test_tc_19_problem_response_shape() -> None:
    """tc-19(D5) — problem_response(slug, status, *, title=None, detail=None).

    Content-Type application/problem+json · type = https://joshuatech.dev/problems/<slug의 _를 -> · title = 주어진 값 또는
    HTTPStatus 문구 · status · detail은 주어질 때만. 슬러그가 [a-z][a-z0-9_]* 꼴이 아니면 ValueError.
    """
    response = problem_response("tenant_required", 403)
    assert response.status_code == 403
    assert response["Content-Type"] == "application/problem+json"
    assert json.loads(response.content) == {
        "type": "https://joshuatech.dev/problems/tenant-required",
        "title": "Forbidden",
        "status": 403,
    }
    response = problem_response("not_ready", 503, title="준비되지 않음", detail="db")
    body = assert_problem(response, 503, "not_ready")
    assert body == {"type": problem_type("not_ready"), "title": "준비되지 않음", "status": 503, "detail": "db"}
    for bad in ("Tenant_required", "tenant-required", "", "_tenant", "1tenant", "tenant required", "tenant\n"):
        with pytest.raises(ValueError):
            problem_response(bad, 400)


def test_tc_20_model_grade_check(monkeypatch: pytest.MonkeyPatch) -> None:
    """tc-20(D10 ⑤ · F3 · F4) — 정적 모델 검사(카탈로그에 테이블이 없어도 잡힌다 · 관리되지 않는 모델은 검사 밖).

    - TenantModel: db_table이 B 허용 목록 · 프레임워크 이름이면(ShadowOutbox · ShadowAuthUser) 위반 · 카탈로그에 A 등급
      표(r · p)로 없으면(NopeTenant — nope_tbl) 위반.
    - GlobalModel: db_table이 허용 목록 밖이면 위반(StrayGlobal).
    - 허용 목록 이름을 쓰는 관리 모델은 GlobalModel 하위여야 한다(일반 Model PlainMembership — tenant_membership).
    - 프레임워크 이름은 Django contrib 앱(auth · contenttypes · sessions · admin)만 쓴다: 비-contrib 모델 FakeSession
      (django_session)과 자동 M2M 중간 모델(FakeHub.peers의 db_table auth_user_groups — get_models(include_auto_created=True)
      로만 보인다)은 위반. contenttypes의 ContentType(django_content_type)은 통과한다(마지막 check_rls() == []).
    격리된 앱 레지스트리에 모델을 만들고 전역 레지스트리의 get_models 결과에만 덧붙인다(다른 시험 · makemigrations에 영향
    없음). 자동 M2M 모델은 실제 레지스트리처럼 include_auto_created=True일 때만 덧붙인다.
    """
    with isolate_apps("tests.testapp"):

        class ShadowOutbox(TenantModel):
            class Meta(TenantModel.Meta):
                app_label = "testapp"
                db_table = "outbox"

        class ShadowAuthUser(TenantModel):
            class Meta(TenantModel.Meta):
                app_label = "testapp"
                db_table = "auth_user"

        class NopeTenant(TenantModel):
            class Meta(TenantModel.Meta):
                app_label = "testapp"
                db_table = "nope_tbl"

        class StrayGlobal(GlobalModel):
            class Meta(GlobalModel.Meta):
                app_label = "testapp"
                db_table = "stray_global"

        class UnmanagedGlobal(GlobalModel):
            class Meta(GlobalModel.Meta):
                app_label = "testapp"
                db_table = "unmanaged_global"
                managed = False

        class PlainMembership(models.Model):
            class Meta:
                app_label = "testapp"
                db_table = "tenant_membership"

        class FakeSession(models.Model):
            class Meta:
                app_label = "testapp"
                db_table = "django_session"

        class FakeHub(models.Model):
            peers = models.ManyToManyField("self", db_table="auth_user_groups")

            class Meta:
                app_label = "testapp"
                db_table = "fake_hub"

    extra = [
        ShadowOutbox,
        ShadowAuthUser,
        NopeTenant,
        StrayGlobal,
        UnmanagedGlobal,
        PlainMembership,
        FakeSession,
        FakeHub,
    ]
    auto_created = [FakeHub._meta.get_field("peers").remote_field.through]
    real_get_models = apps.get_models

    def get_models(include_auto_created: bool = False, include_swapped: bool = False) -> list[type[models.Model]]:
        found = [*real_get_models(include_auto_created, include_swapped), *extra]
        return [*found, *auto_created] if include_auto_created else found

    with monkeypatch.context() as patch:
        # 인스턴스 __dict__에 덮어 둔다 — 되돌릴 때 키를 지워 전역 레지스트리에 흔적이 남지 않는다(setattr는 바운드 메서드를 남긴다).
        patch.setitem(vars(apps), "get_models", get_models)
        tables = _violation_tables()
    assert "get_models" not in vars(apps)
    assert tables == {
        "outbox",
        "auth_user",
        "nope_tbl",
        "stray_global",
        "tenant_membership",
        "django_session",
        "auth_user_groups",
    }
    assert check_rls() == []


def test_tc_21_owner_created_extension_cannot_hide_objects(pg: PgInfo) -> None:
    """tc-21(F4 · F5 · B-2) — 확장 멤버 제외는 superuser가 소유한 확장의 멤버만이다.

    owner role(비-superuser · DB 소유자)이 trusted 확장 pg_trgm을 만들면 그 확장의 소유자가 owner role이다(실측 — 카탈로그
    pg_extension.extowner · pg_roles.rolsuper 거짓). 그 확장에 RLS 없는 표 ext_member와 SECURITY DEFINER 함수 ext_fn을 멤버로
    넣어도(ALTER EXTENSION … ADD) 둘 다 위반이다. r1의 「superuser가 없어 못 쟀다」를 대체한다.
    """
    attached_table = attached_function = False
    try:
        _owner_ddl("CREATE EXTENSION pg_trgm")
        _owner_ddl("CREATE TABLE ext_member (id integer)")
        _owner_ddl("ALTER EXTENSION pg_trgm ADD TABLE ext_member")
        attached_table = True
        _owner_ddl(
            "CREATE FUNCTION ext_fn() RETURNS bigint LANGUAGE sql SECURITY DEFINER AS 'SELECT count(*) FROM widget'"
        )
        _owner_ddl("ALTER EXTENSION pg_trgm ADD FUNCTION ext_fn()")
        attached_function = True
        with connections["default"].cursor() as cursor:
            cursor.execute(
                "SELECT r.rolname, r.rolsuper, ("
                "SELECT count(*) FROM pg_catalog.pg_depend AS d"
                " WHERE d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass AND d.refobjid = e.oid"
                " AND d.deptype = 'e'"
                " AND d.objid IN ('ext_member'::pg_catalog.regclass, 'ext_fn()'::pg_catalog.regprocedure))"
                " FROM pg_catalog.pg_extension AS e JOIN pg_catalog.pg_roles AS r ON r.oid = e.extowner"
                " WHERE e.extname = 'pg_trgm'"
            )
            assert cursor.fetchall() == [(pg.owner_user, False, 2)]
        assert _violation_tables() == {"ext_member", "ext_fn"}
    finally:
        if attached_function:
            _owner_ddl("ALTER EXTENSION pg_trgm DROP FUNCTION ext_fn()")
        _owner_ddl("DROP FUNCTION IF EXISTS ext_fn()")
        if attached_table:
            _owner_ddl("ALTER EXTENSION pg_trgm DROP TABLE ext_member")
        _owner_ddl("DROP TABLE IF EXISTS ext_member")
        _owner_ddl("DROP EXTENSION IF EXISTS pg_trgm")
    assert check_rls() == []


def test_tc_22_security_definer_function_and_rewrite_rule() -> None:
    """tc-22(F5 · B-4) — 소유자 권한으로 도는 객체는 뷰와 같은 우회다.

    - SECURITY DEFINER 함수(비시스템 스키마) → 위반(함수 이름 leak_fn). 실측: 컨텍스트 없는 app role이 부르면 소유자
      (BYPASSRLS) 권한으로 widget 5행을 센다 — 같은 본문의 SECURITY INVOKER 함수 ok_fn은 0행이고 위반이 아니다.
    - 표의 재작성 규칙(CREATE RULE · 뷰의 _RETURN은 뷰 판정으로) → 위반(표 이름 widget · 규칙 이름 r_log).
    """
    _seed_widgets()
    try:
        _owner_ddl("CREATE FUNCTION ok_fn() RETURNS bigint LANGUAGE sql AS 'SELECT count(*) FROM widget'")
        _owner_ddl(
            "CREATE FUNCTION leak_fn() RETURNS bigint LANGUAGE sql SECURITY DEFINER AS 'SELECT count(*) FROM widget'"
        )
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT ok_fn(), leak_fn()")
            assert cursor.fetchone() == (0, 5)
        violations = check_rls()
        assert _tables(violations) == {"leak_fn"}
        assert all("SECURITY DEFINER" in line for line in violations)
        _owner_ddl("DROP FUNCTION leak_fn()")
        _owner_ddl("CREATE RULE r_log AS ON INSERT TO widget DO ALSO NOTHING")
        violations = check_rls()
        assert _tables(violations) == {"widget"}
        assert len(violations) == 1
        assert "r_log" in violations[0]
    finally:
        _owner_ddl("DROP RULE IF EXISTS r_log ON widget")
        _owner_ddl("DROP FUNCTION IF EXISTS leak_fn()")
        _owner_ddl("DROP FUNCTION IF EXISTS ok_fn()")
    assert check_rls() == []


def test_tc_23_tenant_context_scopes_and_restores() -> None:
    """tc-23(F6 · B-5) — 범위 도우미 tenant_context(tenant_id | None, *, using=…).

    - 실측(왜 필요한가): set_config(…, true)는 savepoint RELEASE로 되돌아가지 않는다 — 안쪽 atomic에서 B로 바꾸면 블록을
      나온 뒤에도 B다.
    - 바깥 atomic 밖 → TransactionManagementError(요청 밖 작업은 atomic을 직접 연다).
    - 컨텍스트 A인 트랜잭션: with tenant_context(B) 안은 B(B 행 3) · 나온 뒤 A(A 행 2).
    - 안에서 예외 → 예외는 그대로 전파되고 나온 뒤 A다. 되돌림은 savepoint 롤백이 한다(안에서 쓴 B 행도 함께 사라진다).
    - None → 안은 None(0행) · 나온 뒤 A. 안에서 set_rollback(True) → 예외 없이 나오고 A(savepoint 롤백이 되돌린다).
    - 중첩 → 안쪽에서 나오면 바깥 범위의 값.
    """
    _seed_widgets()
    tenant_context = tenancy.tenant_context
    with pytest.raises(TransactionManagementError):
        with tenant_context(TENANT_B):
            pass
    with transaction.atomic(using="default"):
        set_tenant_context(TENANT_A)
        with transaction.atomic(using="default"):
            set_tenant_context(TENANT_B)
        assert current_tenant_id() == TENANT_B
        set_tenant_context(TENANT_A)
        with tenant_context(TENANT_B):
            assert (current_tenant_id(), Widget.objects.count()) == (TENANT_B, 3)
        assert (current_tenant_id(), Widget.objects.count()) == (TENANT_A, 2)
        with pytest.raises(_Boom):
            with tenant_context(TENANT_B):
                Widget.objects.create(tenant_id=TENANT_B, name="tc23")
                raise _Boom
        assert current_tenant_id() == TENANT_A
        with tenant_context(TENANT_B):
            assert Widget.objects.count() == 3
        with tenant_context(None):
            assert (current_tenant_id(), Widget.objects.count()) == (None, 0)
        assert current_tenant_id() == TENANT_A
        with tenant_context(TENANT_B):
            transaction.set_rollback(True, using="default")
        assert current_tenant_id() == TENANT_A
        with tenant_context(TENANT_B):
            with tenant_context(None):
                assert current_tenant_id() is None
            assert current_tenant_id() == TENANT_B
        assert current_tenant_id() == TENANT_A


def test_tc_24_require_rls_role(pg: PgInfo) -> None:
    """tc-24(F7 · B-7 · G4 · B2-2 · H3 · H4 · A3-3 · A3-4 · B3-2 · I3 · I4) — check_rls(require_rls_role=True) · 명령
    --require-rls-role: 연결의 session_user가 superuser · BYPASSRLS role이거나 그 멤버면, 또는 스캔 범위 관계의 소유자(그
    멤버)면 위반 한 줄(`session_user: …` · 판정은 boolean 하나 · role 이름은 싣지 않는다).

    - default(app role · NOBYPASSRLS · 아무것도 소유하지 않음) + 플래그 → 통과 · owner(BYPASSRLS · 표 소유자) + 플래그 →
      위반 한 줄 · owner 무플래그 → 통과(CI의 owner 실행) · 명령 경로 · cp949.
    - owner 연결 + SET ROLE <app role>(Django OPTIONS["assume_role"]이 접속 직후 하는 것 — conftest가 app role을 owner에게
      GRANT한다) → current_user = app · session_user = owner → 플래그면 위반(옛 current_user 판정은 이 경우를 통과시켰다 ·
      N4). finally에서 RESET ROLE(뒤 시험 · teardown flush가 owner로 돈다).
    - app이 스캔 범위 관계를 소유(H4 — 마이그레이션이 app 자격으로 돈 오설정 · 실측: 소유자인 app은 그 표의 RLS를 끄고 켤 수
      있다) · 소유가 유일한 신호인 사례(I3 · R4-3 c): owner가 public의 CREATE를 app에 주고 표 tc24_owned(tenant_id uuid,
      id integer)를 만들어 rls_policies를 적용한 뒤 소유자를 app으로 넘긴다(owner는 conftest GRANT로 app의 멤버라 넘길 수
      있다) → 플래그 없는 check_rls() == [](A 등급 판정은 모두 통과한다) · app + 플래그 → role 줄 하나뿐(OWNER_REASON ·
      r3 구현 · P4 · Q4면 0줄 — 원문 단언보다 앞선 행동 단언이 잡는다). finally: DROP TABLE(owner는 app의 멤버라 지울 수
      있다)이 실패해도 REVOKE CREATE가 돈다(중첩 try · I4).
    - 판정 SQL = RLS_ROLE_SQL 원문(H3 · 마지막 단언 — NOBYPASSRLS session_user가 BYPASSRLS role의 멤버인 양성 사례는 superuser
      없이 만들 수 없어 `r.rolname = session_user` · 'SET' 변이(P5 · P6)를 원문 비교로 잡는다 · 「BYPASSRLS이면서 아무것도
      소유하지 않는 login role」로 앞 EXISTS를 행동으로 가르는 사례도 superuser가 필요해 T072/T075 라이브 VD로 넘긴다 —
      build-notes r5 「받아들이는 잔여」).
    """
    assert check_rls(require_rls_role=True) == []
    stdout = io.StringIO()
    call_command("check_rls", "--require-rls-role", stdout=stdout, stderr=io.StringIO())
    assert SUCCESS_LINE.fullmatch(stdout.getvalue()) is not None
    assert check_rls(using="owner") == []
    violations = check_rls(using="owner", require_rls_role=True)
    assert len(violations) == 1
    assert violations[0].startswith("session_user: ")
    assert ROLE_REASON in violations[0]
    assert pg.owner_user not in violations[0]
    with pytest.raises(CommandError) as raised:
        call_command(
            "check_rls", "--database", "owner", "--require-rls-role", stdout=io.StringIO(), stderr=io.StringIO()
        )
    message = str(raised.value)
    assert "session_user: " in message
    assert ROLE_REASON in message
    assert pg.owner_user not in message
    message.encode("cp949")
    try:
        _owner_ddl(f"SET ROLE {pg.app_user}")
        with connections["owner"].cursor() as cursor:
            cursor.execute("SELECT current_user, session_user")
            assert cursor.fetchone() == (pg.app_user, pg.owner_user)
        assumed = check_rls(using="owner", require_rls_role=True)
    finally:
        _owner_ddl("RESET ROLE")
    assert len(assumed) == 1
    assert assumed[0].startswith("session_user: ")
    assert ROLE_REASON in assumed[0]
    assert pg.owner_user not in assumed[0]
    assert pg.app_user not in assumed[0]
    try:
        _owner_ddl(f"GRANT CREATE ON SCHEMA public TO {pg.app_user}")
        _owner_ddl("CREATE TABLE tc24_owned (tenant_id uuid, id integer)")
        _apply_rls("tc24_owned")
        _owner_ddl(f"ALTER TABLE tc24_owned OWNER TO {pg.app_user}")
        with connections["default"].cursor() as cursor:
            cursor.execute(
                "SELECT c.relowner::pg_catalog.regrole::pg_catalog.text FROM pg_catalog.pg_class AS c"
                " WHERE c.oid = 'public.tc24_owned'::pg_catalog.regclass"
            )
            assert cursor.fetchone() == (pg.app_user,)
        unflagged = check_rls()
        owned = check_rls(require_rls_role=True)
    finally:
        try:
            _owner_ddl("DROP TABLE IF EXISTS tc24_owned")
        finally:
            _owner_ddl(f"REVOKE CREATE ON SCHEMA public FROM {pg.app_user}")
    assert unflagged == []
    assert len(owned) == 1
    [role_line] = owned
    assert role_line.startswith("session_user: ")
    assert OWNER_REASON in role_line
    assert ROLE_REASON in role_line
    assert pg.app_user not in role_line
    assert pg.owner_user not in role_line
    role_line.encode("cp949")
    assert check_rls(require_rls_role=True) == []
    assert tenancy._RLS_ROLE_SQL == RLS_ROLE_SQL


def test_tc_25_helpers_act_on_their_alias_only() -> None:
    """tc-25(F9 a · F6) — set_tenant_context · current_tenant_id · tenant_context의 using=은 그 별칭의 연결에만 작용한다(두 별칭은
    다른 세션이다): owner 트랜잭션에 A를 두어도 default는 None · default에 B를 두어도 owner는 A · tenant_context(None,
    using="owner")는 owner만 비우고 나올 때 owner의 A로 되돌린다.
    """
    with transaction.atomic(using="owner"):
        set_tenant_context(TENANT_A, using="owner")
        assert (current_tenant_id(using="owner"), current_tenant_id()) == (TENANT_A, None)
        with transaction.atomic(using="default"):
            set_tenant_context(TENANT_B)
            assert (current_tenant_id(using="owner"), current_tenant_id()) == (TENANT_A, TENANT_B)
            with tenancy.tenant_context(None, using="owner"):
                assert (current_tenant_id(using="owner"), current_tenant_id()) == (None, TENANT_B)
            assert (current_tenant_id(using="owner"), current_tenant_id()) == (TENANT_A, TENANT_B)


def test_tc_26_partitioned_table_and_its_partition() -> None:
    """tc-26(F9 c · A-6 c) — 분할 표(relkind p)와 파티션(relkind r · relispartition)은 각자 판정한다.

    RLS가 없으면 부모 · 파티션 둘 다 위반이다. 부모에만 rls_policies를 걸면 부모는 통과하고 파티션은 여전히 위반이다 —
    실측: 컨텍스트 없는 app role이 부모로 읽으면 0행이지만 파티션을 직접 읽으면 두 테넌트 행이 다 보인다(부모의 정책은
    파티션 직접 질의에 걸리지 않는다). 파티션에도 걸면 통과하고 직접 질의도 0행이다. 파티션의 부모 ptest는 A 등급이라 상속 ·
    파티션 부모 판정(H1 · tc-31)에는 걸리지 않는다(위반 집합이 그대로다).
    """

    def app_counts() -> tuple[int, int]:
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT (SELECT count(*) FROM ptest), (SELECT count(*) FROM ptest_1)")
            return cursor.fetchone()

    try:
        _owner_ddl("CREATE TABLE ptest (tenant_id uuid, id integer) PARTITION BY RANGE (id)")
        _owner_ddl("CREATE TABLE ptest_1 PARTITION OF ptest FOR VALUES FROM (0) TO (100)")
        with connections["owner"].cursor() as cursor:
            cursor.execute("INSERT INTO ptest VALUES (%s, 1), (%s, 2)", [TENANT_A, TENANT_B])
        assert _violation_tables() == {"ptest", "ptest_1"}
        _apply_rls("ptest")
        assert _violation_tables() == {"ptest_1"}
        assert app_counts() == (0, 2)
        _apply_rls("ptest_1")
        assert check_rls() == []
        assert app_counts() == (0, 0)
    finally:
        _owner_ddl("DROP TABLE IF EXISTS ptest_1, ptest")


def test_tc_27_exempt_view_exception_keeps_its_type(tenancy_settings: Settings) -> None:
    """tc-27(F9 d · A-6 d) — 면제 경로 뷰가 예외를 내면 500이고 예외 타입은 원래 그대로다(IntentionalViewError).

    process_exception은 이 미들웨어의 atomic이 열려 있을 때만 롤백을 표시한다 — 그 게이트가 없으면 atomic 밖의
    set_rollback이 TransactionManagementError를 내어 원래 예외를 덮는다(raise_request_exception으로 본다).
    """
    tenancy_settings.TENANT_CONTEXT_EXEMPT_PATHS = ["/exempt-raise"]
    with pytest.raises(IntentionalViewError):
        Client().get("/exempt-raise")
    response = Client(raise_request_exception=False).get("/exempt-raise")
    assert response.status_code == 500
    assert response.exc_info is not None
    assert response.exc_info[0] is IntentionalViewError


def test_tc_28_other_session_temp_table_is_ignored() -> None:
    """tc-28(F9 g) — owner 세션의 TEMP 표는 pg_temp_N 스키마에 있고 app role도 카탈로그에서 보지만 default의 check_rls는
    무시한다(시스템 스키마 pg_temp_* 제외 — 세션이 끝나면 사라지는 표다)."""
    try:
        _owner_ddl("CREATE TEMP TABLE tc28_tmp (id integer)")
        with connections["default"].cursor() as cursor:
            cursor.execute(
                "SELECT n.nspname FROM pg_catalog.pg_class AS c"
                " JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace WHERE c.relname = 'tc28_tmp'"
            )
            (schema,) = cursor.fetchone()
        assert schema.startswith("pg_temp_")
        assert check_rls() == []
    finally:
        _owner_ddl("DROP TABLE IF EXISTS pg_temp.tc28_tmp")


def test_tc_29_django_schema_must_be_unique() -> None:
    """tc-29(F3) — 「Django 스키마」 = django_migrations 표(r)가 있는 스키마 하나. 없거나 둘 이상이면 위반 한 줄
    (`django_migrations: …` · 스키마 수)을 내고 면제 · B 인정 없이 전부 A로 판정한다.

    owner의 atomic 안에서 DDL을 하고 owner로 판정한 뒤 롤백한다(커밋하지 않는다 — 카탈로그 판정은 role과 무관하다). 모호하면
    면제 · B가 사라져 public의 프레임워크 · B 이름 표(RLS 없음)가 전부 A 위반이 된다 — 그 이름 집합 present는 시나리오 전에
    카탈로그에서 읽는다(G1 — 뒤 과제가 이 시험 DB에 B 표를 더해도(T069 public.outbox) 기대가 따라간다 · 지금은
    django_content_type · tenant가 있어야 한다 — 공허 방지):
    - 둘: tc29.django_migrations를 더하면 → 위반 이름 = django_migrations(줄 + 두 표) · present. widget(A · RLS)은 통과.
    - 없음: public.django_migrations 이름을 바꾸면 → 위반 이름 = django_migrations(줄) · tc29_migrations · present.
    """
    with connections["owner"].cursor() as cursor:
        cursor.execute(
            "SELECT c.relname FROM pg_catalog.pg_class AS c"
            " JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace"
            " WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p') AND c.relname = ANY(%s)",
            [sorted(FRAMEWORK_TABLES | GLOBAL_TABLE_ALLOWLIST)],
        )
        present = {name for (name,) in cursor.fetchall()} - {"django_migrations"}
    assert {"django_content_type", "tenant"} <= present

    def scan_in_rolled_back_owner_transaction(*statements: str) -> list[str]:
        with transaction.atomic(using="owner"):
            for statement in statements:
                _owner_ddl(statement)
            violations = check_rls(using="owner")
            transaction.set_rollback(True, using="owner")
        return violations

    def schema_lines(violations: list[str]) -> list[str]:
        return [line for line in violations if line.startswith("django_migrations: ") and "Django 스키마" in line]

    violations = scan_in_rolled_back_owner_transaction(
        "CREATE SCHEMA tc29", "CREATE TABLE tc29.django_migrations (id integer)"
    )
    [line] = schema_lines(violations)
    assert "2개" in line
    assert _tables(violations) == {"django_migrations", *present}
    violations = scan_in_rolled_back_owner_transaction("ALTER TABLE django_migrations RENAME TO tc29_migrations")
    [line] = schema_lines(violations)
    assert "0개" in line
    assert _tables(violations) == {"django_migrations", "tc29_migrations", *present}
    assert check_rls(using="owner") == []
    assert check_rls() == []


def test_tc_30_implicit_cast_policy_depends_on_user_function() -> None:
    """tc-30(G3 a · B2-1) — 열 타입이 owner의 enum(tc30_tid)이고 enum → uuid 암시적 형변환(CREATE CAST … WITH FUNCTION
    tc30_cast … AS IMPLICIT — 비-superuser가 만든다)이 있으면, rls_policies와 같은 원문의 정책이 그 형변환 함수를 거친다
    (tc30_cast(tenant_id) = 컨텍스트 — 함수가 GUC 값을 돌려주므로 컨텍스트가 있으면 테넌트와 무관하게 모든 행이 보인다).

    실측(PG 18.6): 연산자 인자의 암시적 형변환은 deparse에 보인다(ruleutils가 연산자 인자를 showimplicit로 찍는다 —
    IMPLICIT_CAST_DEPARSE · 세션 search_path · pg_catalog 고정 모두) → 식 비교가 USING · WITH CHECK 두 줄로 먼저 잡고, 정책
    의존 검사가 형변환 함수(pg_proc)로 한 줄을 더한다(사유 3줄 — N1이면 2줄). 의존 검사 단독 판별은 다음 시험(NULLIF)이 맡는다.
    """
    try:
        _owner_ddl("CREATE TYPE tc30_tid AS ENUM ('x')")
        _owner_ddl(
            "CREATE FUNCTION tc30_cast(tc30_tid) RETURNS uuid LANGUAGE sql IMMUTABLE"
            " AS $$SELECT NULLIF(pg_catalog.current_setting('app.tenant_id', true), '')::uuid$$"
        )
        _owner_ddl("CREATE CAST (tc30_tid AS uuid) WITH FUNCTION tc30_cast(tc30_tid) AS IMPLICIT")
        _owner_ddl("CREATE TABLE tc30_cast_t (id integer, tenant_id tc30_tid)")
        _apply_rls("tc30_cast_t")
        for pinned in (False, True):
            assert _policy_deparse("tc30_cast_t", pinned=pinned) == (IMPLICIT_CAST_DEPARSE, IMPLICIT_CAST_DEPARSE)
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS tc30_cast_t")
        _owner_ddl("DROP CAST IF EXISTS (tc30_tid AS uuid)")
        _owner_ddl("DROP FUNCTION IF EXISTS tc30_cast(tc30_tid)")
        _owner_ddl("DROP TYPE IF EXISTS tc30_tid")
    _assert_reasons(
        violations, "tc30_cast_t", ("USING 식이 정본과 다르다", "WITH CHECK 식이 정본과 다르다", DEPENDENCY_REASON)
    )
    assert check_rls() == []


def test_tc_30_nullif_operator_dependency_is_the_only_signal() -> None:
    """tc-30(G3 a 단독 판별 — 숨은 형변환의 대체 재현) — NULLIF 안의 `=`은 deparse에 찍히지 않는다(NULLIF(a, b)만 찍힌다).

    owner가 public.=(text, text)(tc30_texteq — 늘 참)를 만들고 search_path = public, pg_catalog인 자기 세션에서
    rls_policies("tc30_nullif_t")를 적용하면 정책의 NULLIF가 그 연산자를 쓴다(정확히 맞는 연산자를 public에서 먼저 찾는다 — 뜻이
    바뀐다: NULLIF가 늘 NULL). deparse는 세션 search_path · pg_catalog 고정 모두 정본과 같다(글자 비교 · 스캔 고정으로는 못
    잡는다) → 위반 사유는 정책 의존(pg_operator) 한 줄뿐이다(N1이면 통과 — r2 구현도 통과시켰다).
    """
    try:
        _owner_ddl("CREATE FUNCTION tc30_texteq(text, text) RETURNS boolean LANGUAGE sql IMMUTABLE AS 'SELECT true'")
        _owner_ddl("CREATE OPERATOR public.= (LEFTARG = text, RIGHTARG = text, FUNCTION = tc30_texteq)")
        _owner_ddl("CREATE TABLE tc30_nullif_t (id integer, tenant_id uuid)")
        _owner_ddl("SET search_path = public, pg_catalog")
        try:
            _apply_rls("tc30_nullif_t")
        finally:
            _owner_ddl("RESET search_path")
        for pinned in (False, True):
            assert _policy_deparse("tc30_nullif_t", pinned=pinned) == (CANONICAL_PG18, CANONICAL_PG18)
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS tc30_nullif_t")
        _owner_ddl("DROP OPERATOR IF EXISTS public.= (text, text)")
        _owner_ddl("DROP FUNCTION IF EXISTS tc30_texteq(text, text)")
    _assert_reasons(violations, "tc30_nullif_t", (DEPENDENCY_REASON,))
    assert "(pg_depend)" in violations[0]
    violations[0].encode("cp949")
    assert check_rls() == []


def test_tc_30_domain_operator_policy_is_a_violation() -> None:
    """tc-30(G3 a · b · B2-1 재현 R1) — tenant_id가 uuid 위 도메인(tc30_dom)이고 owner가 public.=(tc30_dom, uuid)(tc30_eq — 늘
    참)를 두면, rls_policies와 같은 원문의 정책이 그 연산자를 고른다(pg_catalog에 정확히 맞는 연산자가 없다 · search_path를
    바꾸지 않아도 된다) — 컨텍스트 없는 app role에게도 모든 행이 보인다(r2 구현은 통과시켰다 · VD).

    세션 search_path의 deparse는 정본과 같고(public.=이 보여 비한정으로 찍힌다), pg_catalog로 고정하면 DOMAIN_OPERATOR_DEPARSE
    (`OPERATOR(public.=)`)다 → 위반 사유 3줄: USING · WITH CHECK 식(고정 search_path · N2면 빠진다) + 정책 의존(N1이면 빠진다).
    """
    try:
        _owner_ddl("CREATE DOMAIN tc30_dom AS uuid")
        _owner_ddl("CREATE FUNCTION tc30_eq(tc30_dom, uuid) RETURNS boolean LANGUAGE sql IMMUTABLE AS 'SELECT true'")
        _owner_ddl("CREATE OPERATOR public.= (LEFTARG = tc30_dom, RIGHTARG = uuid, FUNCTION = tc30_eq)")
        _owner_ddl("CREATE TABLE tc30_dom_t (id integer, tenant_id tc30_dom)")
        _apply_rls("tc30_dom_t")
        assert _policy_deparse("tc30_dom_t", pinned=False) == (CANONICAL_PG18, CANONICAL_PG18)
        assert _policy_deparse("tc30_dom_t", pinned=True) == (DOMAIN_OPERATOR_DEPARSE, DOMAIN_OPERATOR_DEPARSE)
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS tc30_dom_t")
        _owner_ddl("DROP OPERATOR IF EXISTS public.= (tc30_dom, uuid)")
        _owner_ddl("DROP FUNCTION IF EXISTS tc30_eq(tc30_dom, uuid)")
        _owner_ddl("DROP DOMAIN IF EXISTS tc30_dom")
    _assert_reasons(
        violations, "tc30_dom_t", ("USING 식이 정본과 다르다", "WITH CHECK 식이 정본과 다르다", DEPENDENCY_REASON)
    )
    assert check_rls() == []


def test_tc_30_hostile_search_path_cannot_subvert_scan() -> None:
    """tc-30(G3 b 단독 판별 · B2-1 a) — check_rls는 search_path를 pg_catalog로 고정한 트랜잭션에서 스캔하고 롤백으로 되돌린다.

    기준 위반(tc30_rogue — RLS 없는 표 · 3줄)을 둔 뒤, owner 세션의 search_path를 public, pg_catalog로 두고 스캔 SQL의 비한정
    `<>`(name, name — NOT IN · rulename <> '_RETURN')를 가리는 public.<>(tc30_ne — 늘 거짓)를 만든다. 대조: 그 세션에서 비한정
    NOT IN이 실제로 가려진다('public' NOT IN (…)이 거짓). 그래도 check_rls(using="owner")는 기준과 같고, 호출 뒤 세션
    search_path는 public, pg_catalog 그대로다(고정은 is_local · 롤백). 고정을 빼면(N2) 관계가 0개로 보인다(실측 — 「Django
    스키마 0개」 · 「widget 표 없음」 위반으로 바뀐다). finally: RESET search_path · 연산자 · 함수 · 표.
    """
    try:
        _owner_ddl("CREATE TABLE tc30_rogue (id integer)")
        baseline = check_rls(using="owner")
        assert _tables(baseline) == {"tc30_rogue"}
        assert len(baseline) == 3
        _owner_ddl("SET search_path = public, pg_catalog")
        _owner_ddl("CREATE FUNCTION tc30_ne(name, name) RETURNS boolean LANGUAGE sql IMMUTABLE AS 'SELECT false'")
        _owner_ddl("CREATE OPERATOR public.<> (LEFTARG = name, RIGHTARG = name, FUNCTION = tc30_ne)")
        with connections["owner"].cursor() as cursor:
            cursor.execute("SELECT 'public'::name NOT IN ('pg_catalog', 'information_schema')")
            assert cursor.fetchone() == (False,)
        assert check_rls(using="owner") == baseline
        assert _search_path("owner") == "public, pg_catalog"
    finally:
        _owner_ddl("RESET search_path")
        _owner_ddl("DROP OPERATOR IF EXISTS public.<> (name, name)")
        _owner_ddl("DROP FUNCTION IF EXISTS tc30_ne(name, name)")
        _owner_ddl("DROP TABLE IF EXISTS tc30_rogue")
    assert check_rls(using="owner") == []


def test_tc_30_scan_inside_outer_atomic_restores_search_path() -> None:
    """tc-30(G3 b — set_rollback) — 바깥 atomic 안에서 부르면 스캔은 savepoint 안에서 돌고, savepoint 롤백이 search_path 고정을
    되돌린다(RELEASE면 is_local 값이 바깥 트랜잭션 끝까지 남는다 — VD-6과 같은 원리 · N3이면 호출 뒤 pg_catalog). 바깥
    트랜잭션은 그대로 쓸 수 있다: 스캔 전에 둔 지역 GUC가 남고 롤백 표시가 서지 않는다.
    """
    with transaction.atomic(using="owner"):
        with connections["owner"].cursor() as cursor:
            cursor.execute("SELECT pg_catalog.set_config('app.tc30_probe', 'kept', true)")
        before = _search_path("owner")
        assert before != "pg_catalog"
        assert check_rls(using="owner") == []
        assert _search_path("owner") == before
        assert transaction.get_rollback(using="owner") is False
        with connections["owner"].cursor() as cursor:
            cursor.execute("SELECT pg_catalog.current_setting('app.tc30_probe', true)")
            assert cursor.fetchone() == ("kept",)
        transaction.set_rollback(True, using="owner")


def test_tc_31_grade_a_child_of_non_grade_a_parent_fails() -> None:
    """tc-31(H1 · B3-1) — 상속 · 파티션 링크(pg_inherits)의 양쪽 등급이 같아야 한다(계약 ③ · T068 r4 · r5). 이 시험은 부모 쪽이다:
    A 등급 표(r · p)의 부모는 A 등급이어야 한다. 반대 방향(A 표의 B · 프레임워크 자식 — I1) · relkind p 자식(I2) · 한 트리의
    두 방향(각자 한 줄)은 아래 tc-31 시험들이 맡는다(build-notes 「### T068 r4 결과 · r5 결정」).

    owner가 B 표 tenant의 상속 자식 tc31_child를 만들고(CREATE TABLE … () INHERITS (tenant) — 열 id · tenant_id · label을
    물려받는다) rls_policies("tc31_child")의 RunSQL.sql을 그대로 적용하면, 자식은 A 등급 판정(ENABLE · FORCE · 정본 정책 ·
    의존)을 모두 통과한다. 실측: 컨텍스트 없는 app role이 자식을 직접 읽으면 0행이지만, 부모 tenant로 읽으면 자식 행이 보인다
    (부모를 거친 질의에는 부모의 RLS만 적용된다 — tenant는 B라 RLS가 없다). → 위반은 tc31_child 한 줄(부모 사유 · 부모 이름
    public.tenant)뿐이다(r3 구현 · P1이면 통과). 부모가 A인 파티션(tc-26)은 그대로 통과한다. 스캔 밖 관계(시스템 스키마 ·
    superuser 소유 확장의 멤버)는 owner 자격으로 부모로 둘 수 없어 시험하지 않는다(PG 18.6 실측 — information_schema ·
    pg_catalog 표는 「must be owner」 · 임시 표 부모는 거부 · pg_ 접두 스키마 이름은 예약 · 시험 DB의 superuser 소유 확장은
    관계가 없는 plpgsql뿐 — 「스캔 밖 부모도 위반」은 fail-closed 쪽 결정이라 변이 P2는 살아남는다). finally에서 DROP TABLE.
    """
    try:
        _owner_ddl("CREATE TABLE tc31_child () INHERITS (tenant)")
        _apply_rls("tc31_child")
        with connections["owner"].cursor() as cursor:
            cursor.execute(
                "INSERT INTO tc31_child (id, tenant_id, label) VALUES (%s, %s, 'child-b')", [uuid.uuid4(), TENANT_B]
            )
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT count(*) FROM tc31_child")
            assert cursor.fetchone() == (0,)
            cursor.execute("SELECT label FROM tenant WHERE tableoid = 'public.tc31_child'::pg_catalog.regclass")
            assert cursor.fetchall() == [("child-b",)]
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS tc31_child")
    _assert_reasons(violations, "tc31_child", (PARENT_REASON,))
    assert "부모(public.tenant)" in violations[0]
    violations[0].encode("cp949")
    assert check_rls() == []


@pytest.mark.parametrize(
    ("setup_sql", "teardown_sql", "reserved", "child", "parent", "relkind"),
    [
        (
            ["CREATE TABLE tc31_fw_child (tenant_id uuid) INHERITS (django_content_type)"],
            ["DROP TABLE IF EXISTS tc31_fw_child"],
            [],
            "tc31_fw_child",
            "public.django_content_type",
            "r",
        ),
        (
            [
                "CREATE TABLE tenant_membership (tenant_id uuid, id integer) PARTITION BY RANGE (id)",
                "CREATE TABLE tc31_part PARTITION OF tenant_membership FOR VALUES FROM (0) TO (100)",
            ],
            ["DROP TABLE IF EXISTS tc31_part, tenant_membership"],
            ["tenant_membership"],
            "tc31_part",
            "public.tenant_membership",
            "r",
        ),
        (
            [
                "CREATE TABLE tenant_membership (tenant_id uuid, id integer) PARTITION BY RANGE (id)",
                "CREATE TABLE tc31_sub PARTITION OF tenant_membership FOR VALUES FROM (0) TO (100)"
                " PARTITION BY RANGE (id)",
            ],
            ["DROP TABLE IF EXISTS tc31_sub, tenant_membership"],
            ["tenant_membership"],
            "tc31_sub",
            "public.tenant_membership",
            "p",
        ),
    ],
    ids=["framework-parent", "grade-b-partitioned-parent", "partitioned-child-of-grade-b-parent"],
)
def test_tc_31_framework_parent_and_grade_b_partition_fail(
    setup_sql: list[str], teardown_sql: list[str], reserved: list[str], child: str, parent: str, relkind: str
) -> None:
    """tc-31(H1 · I2 · R4-3 b) — 부모 판정은 B만이 아니고 relkind r 자식만도 아니다: 프레임워크 표(django_content_type —
    Django 스키마의 FRAMEWORK_TABLES)의 상속 자식 · B 분할 표(허용 목록 이름 tenant_membership · relkind p · RLS 없음)의
    파티션(relkind r) · 같은 B 분할 표의 파티션이 다시 A 분할 표인 것(tc31_sub — PARTITION OF … PARTITION BY · relkind p · I2)
    모두, rls_policies를 적용해 다른 A 등급 판정을 모두 통과해도 위반 한 줄(부모 사유 · 부모 이름 · 그 relkind)이다. 파티션도
    pg_inherits에 있다(PARTITION OF). 부모 자신은 각각 프레임워크 면제 · B로 통과한다(위반 이름은 자식 하나 · 자식이 A라 반대
    방향 I1은 걸리지 않는다). 예약 이름(tenant_membership)은 만들기 전에 없음을 단언한다(I4). finally에서 지운다. Q3(부모
    판정을 relkind r 자식에만)이면 tc31_sub 사례가 통과한다.
    """
    _assert_absent(*reserved)
    try:
        for statement in setup_sql:
            _owner_ddl(statement)
        _apply_rls(child)
        violations = check_rls()
    finally:
        for statement in teardown_sql:
            _owner_ddl(statement)
    _assert_reasons(violations, child, (PARENT_REASON,))
    assert f"부모({parent})" in violations[0]
    assert violations[0].endswith(f"(스키마 public · relkind {relkind})")
    assert check_rls() == []


@pytest.mark.parametrize(
    ("partition", "label"),
    [("tenant_membership", "B 등급"), ("django_session", "프레임워크 면제")],
    ids=["grade-b-name-partition", "framework-name-partition"],
)
def test_tc_31_non_grade_a_partition_of_grade_a_parent_fails(partition: str, label: str) -> None:
    """tc-31(I1 · R4-1) — 링크의 반대 방향: A 등급 표의 상속 · 파티션 자식도 A 등급이어야 한다.

    A 분할 표 tc31_ap(rls_policies)의 파티션에 허용 목록 이름(tenant_membership)이나 프레임워크 이름(django_session)을 쓰면,
    그 파티션은 Django 스키마의 표(relkind r)라 B · 프레임워크로 판정되어 RLS가 없어도 제 판정을 통과한다(B = RLS 꺼짐 ·
    프레임워크 = 검사 없음). 실측(PG 18.6): owner로 부모에 두 테넌트 행을 쓰면 파티션 라우팅으로 그 파티션에 저장되고,
    컨텍스트 없는 app role이 부모로 읽으면 0행이지만 파티션을 직접 읽으면 2행이다(자식을 직접 읽는 질의에는 자식의 RLS만
    적용된다 — r4 구현은 이 상태에서 check_rls() == [] · build-notes r5 VD). → 위반은 그 파티션 한 줄(A 부모 사유 · 부모 이름
    public.tc31_ap · 판정된 등급)뿐이다(r4 구현 · Q1(자식 쪽 검사 제거)이면 두 사례 모두 0줄 · Q2(자식 쪽을 B만)면
    framework-name-partition이 0줄). 예약 이름이라 만들기 전에 없음을 단언한다(I4). finally에서 지운다.
    """
    _assert_absent(partition)
    try:
        _owner_ddl("CREATE TABLE tc31_ap (tenant_id uuid, id integer) PARTITION BY RANGE (id)")
        _apply_rls("tc31_ap")
        _owner_ddl(f"CREATE TABLE {partition} PARTITION OF tc31_ap FOR VALUES FROM (0) TO (100)")
        with connections["owner"].cursor() as cursor:
            cursor.execute("INSERT INTO tc31_ap VALUES (%s, 1), (%s, 2)", [TENANT_A, TENANT_B])
        with connections["default"].cursor() as cursor:
            cursor.execute(f"SELECT (SELECT count(*) FROM tc31_ap), (SELECT count(*) FROM {partition})")
            assert cursor.fetchone() == (0, 2)
        violations = check_rls()
    finally:
        _owner_ddl(f"DROP TABLE IF EXISTS {partition}, tc31_ap")
    _assert_reasons(violations, partition, (CHILD_REASON,))
    assert f"부모(public.tc31_ap)가 A 등급인데 이 관계는 A 등급이 아니다({label})" in violations[0]
    assert violations[0].endswith("(스키마 public · relkind r)")
    violations[0].encode("cp949")
    assert check_rls() == []


def test_tc_31_plain_inheritance_child_of_grade_a_parent_fails() -> None:
    """tc-31(I1 · r5 리뷰 R5-1) — 일반 상속(INHERITS) 자식도 같은 등급 규칙을 받는다: A 등급 표 widget의 자식에 허용 목록
    이름(tenant_membership)을 쓰면 B로 판정되지만 A 부모의 자식이라 위반 한 줄이다. 파티션과 달리 부모로 쓴 행은 자식에
    저장되지 않는다(실측 VD-I1b) — 사유는 두 경우 모두 맞는 꼴(CHILD_REASON)이다. 「I1을 파티션 링크에만」 변이를 가른다.
    예약 이름이라 만들기 전에 없음을 단언한다(I4). finally에서 지운다.
    """
    _assert_absent("tenant_membership")
    try:
        _owner_ddl("CREATE TABLE tenant_membership () INHERITS (widget)")
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS tenant_membership")
    _assert_reasons(violations, "tenant_membership", (CHILD_REASON,))
    assert "부모(public.widget)가 A 등급인데 이 관계는 A 등급이 아니다(B 등급)" in violations[0]
    assert violations[0].endswith("(스키마 public · relkind r)")
    violations[0].encode("cp949")
    assert check_rls() == []


def test_tc_31_both_directions_in_one_tree_are_separate_lines() -> None:
    """tc-31(I1 · I2 · H1) — 한 상속 트리에 두 방향이 다 있으면 각자의 관계에 한 줄씩이다(링크 하나가 두 판정에 함께 걸리지는
    않는다 — 자식이 A면 부모 쪽(H1), 부모가 A면 자식 쪽(I1)만 본다).

    B 분할 표 tenant_membership(허용 목록 · relkind p · RLS 없음) → A 분할 표 파티션 tc31_sub(relkind p · rls_policies) →
    프레임워크 이름 파티션 django_session(relkind r). tc31_sub = A 표의 비-A 부모(H1 · 부모 public.tenant_membership ·
    relkind p) · django_session = A 표의 비-A 자식(I1 · 부모 public.tc31_sub · 프레임워크 면제). 실측(PG 18.6): owner로 B
    뿌리에 두 테넌트 행을 쓰면 django_session에 저장되고, 컨텍스트 없는 app role이 B 뿌리 · 프레임워크 잎으로 읽으면 2행 · A
    가운데로 읽으면 0행이다(r4 구현은 tc31_sub 한 줄뿐 · build-notes r5 VD). 위반 순서는 이름 순(django_session → tc31_sub)이다.
    예약 이름 둘은 만들기 전에 없음을 단언한다(I4). finally에서 지운다.
    """
    _assert_absent("tenant_membership", "django_session")
    try:
        _owner_ddl("CREATE TABLE tenant_membership (tenant_id uuid, id integer) PARTITION BY RANGE (id)")
        _owner_ddl(
            "CREATE TABLE tc31_sub PARTITION OF tenant_membership FOR VALUES FROM (0) TO (100) PARTITION BY RANGE (id)"
        )
        _apply_rls("tc31_sub")
        _owner_ddl("CREATE TABLE django_session PARTITION OF tc31_sub FOR VALUES FROM (0) TO (50)")
        with connections["owner"].cursor() as cursor:
            cursor.execute("INSERT INTO tenant_membership VALUES (%s, 1), (%s, 2)", [TENANT_A, TENANT_B])
        with connections["default"].cursor() as cursor:
            cursor.execute(
                "SELECT (SELECT count(*) FROM tenant_membership), (SELECT count(*) FROM tc31_sub),"
                " (SELECT count(*) FROM django_session)"
            )
            assert cursor.fetchone() == (2, 0, 2)
        violations = check_rls()
    finally:
        _owner_ddl("DROP TABLE IF EXISTS django_session, tc31_sub, tenant_membership")
    assert [line.split(": ", 1)[0] for line in violations] == ["django_session", "tc31_sub"]
    leaf_line, sub_line = violations
    assert CHILD_REASON in leaf_line
    assert PARENT_REASON not in leaf_line
    assert "부모(public.tc31_sub)가 A 등급인데 이 관계는 A 등급이 아니다(프레임워크 면제)" in leaf_line
    assert leaf_line.endswith("(스키마 public · relkind r)")
    assert PARENT_REASON in sub_line
    assert CHILD_REASON not in sub_line
    assert "부모(public.tenant_membership)" in sub_line
    assert sub_line.endswith("(스키마 public · relkind p)")
    assert check_rls() == []
