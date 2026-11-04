"""django_common.tenancy — 테이블 등급(A · B) · 요청 테넌트 컨텍스트 · RLS 마이그레이션 헬퍼 · check_rls(T068 · r2–r5).

계약: contracts/pod-template.md §테이블 등급 · §런타임 계약 「DB 연결」 · §django-common 공개 API(T068 보정 2026-11-04 ·
T068 r2 · r3 · r4 · r5) · data-model.md §7(정책 SQL) · 규칙 .claude/rules/django-pod.md §Table grades · §Auth · §Settings ·
§Migrations · ADR 0007. 설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T068」(D2–D15) ·
「### T068 r2」(F1–F12) · 「### T068 r3」(G1–G7) · 「### T068 r3 결과 · r4 결정」(H1–H6) · 「### T068 r4 결과 · r5 결정」
(I1–I5) 절.

테이블 등급
- A 등급(테넌트 범위) = TenantModel 상속: `id` UUID v4 PK · `tenant_id` UUID NOT NULL(값 참조 — FK 아님) · 인덱스
  `(tenant_id, id)` 이름 `<클래스 이름 소문자>_tenant_id_idx`. 전용 마이그레이션에 `rls_policies(<db_table>)`를 둔다 →
  ENABLE + FORCE ROW LEVEL SECURITY + 정책 tenant_isolation. 행 거르기는 RLS만 맡는다(매니저 · save() 무개입 — 컨텍스트가
  없으면 0행).
  - A 등급 클래스 이름은 16자 이하다(인덱스 이름 30자 제한 models.E034 — migrate CLI의 시스템 검사에서야 드러난다). 넘으면
    자식이 같은 필드의 인덱스를 짧은 이름으로 직접 둔다.
  - Meta는 `class Meta(TenantModel.Meta)`로 상속한다(새로 쓴 `class Meta:`는 부모의 indexes를 잃는다). 인덱스를 더하는
    자식은 `indexes = [*TenantModel.Meta.indexes, …]`로 쓴다(새 Meta.indexes는 부모 것을 대체한다).
  - A 등급 M2M은 명시 `through`(TenantModel 상속)만 쓴다 — 자동 중간 테이블은 RLS가 없어 check_rls가 실패시킨다.
  - 정책은 손으로 쓰지 않는다 — check_rls가 식을 정본(rls_policies가 만드는 꼴)과 글자 그대로 비교하고, 정책이 표 · 열 밖의
    객체(사용자 객체 · initdb 후반 객체 — 연산자 · 함수 · 타입 · 콜레이션 · 형변환)에 의존하는지 pg_depend로 본다(문구 T068 r5
    I5). rls_policies는 search_path를 바꾸지 않은 세션에서 적용한다(public이 pg_catalog보다 앞이면 public의 연산자가 정책에
    들어갈 수 있다 — 의존 검사가 실패시킨다).
  - A 등급 표에는 tenant_isolation 밖의 정책을 두지 않는다 — PERMISSIVE는 OR로 합쳐져 격리를 넓히고, RESTRICTIVE 식은
    tenant_isolation보다 먼저 모든 행에 평가될 수 있어 형변환 오류 · 부작용으로 다른 테넌트 값이 샌다(T068 r4 H2).
  - A 등급 관계가 낀 상속 · 파티션 링크는 양쪽이 모두 A 등급이어야 한다(T068 r5): A 등급 표를 B · 프레임워크 표의 상속 자식 ·
    파티션으로 두지 않는다 — 부모를 거친 질의에는 부모의 RLS만 적용되어 자식 행이 RLS 없이 읽힌다(r4 H1). 거꾸로 A 등급 표의
    상속 자식 · 파티션에 허용 목록 · 프레임워크 이름을 쓰지 않는다 — 그 자식은 B · 프레임워크로 판정되어 RLS가 없고, 자식을
    직접 읽는 질의에서 RLS 없이 읽힌다(파티션이면 부모로 쓴 A 행도 라우팅되어 그 자식에 저장된다 · r5 I1). B · 프레임워크끼리의
    링크는 양쪽 다 RLS가 없어 판정하지 않고, 스캔 밖 자식(다른 세션의 TEMP 상속 자식 · superuser 소유 확장의 멤버)도
    판정하지 않는다(r5 리뷰 R5-2).
- B 등급(pod 전역) = GlobalModel 상속(필드 없는 표식 — PK는 모델이 정한다): `db_table`이 GLOBAL_TABLE_ALLOWLIST(4) 안이어야
  하고 RLS를 걸지 않는다. 허용 목록 이름은 GlobalModel만, 프레임워크 이름(FRAMEWORK_TABLES)은 Django contrib 앱만 쓴다.
  허용 목록 · FRAMEWORK_TABLES를 넓히는 설정은 없다 — 계약과 규칙 개정이 먼저다.

TenantContextMiddleware(sync 전용 · MIDDLEWARE에서 JwtAuthMiddleware 바로 뒤)
1. `request.path_info`가 설정 TENANT_CONTEXT_EXEMPT_PATHS(라이브러리 기본 헬스 3 · 요청마다 읽음 · 정확 일치 — 끝 슬래시 ·
   접두 불인정)에 있으면 아무것도 하지 않는다: atomic · 쿼리 · 경고 0(헬스는 DB에 닿지 않는다). Bearer가 없는 경로(웹훅 ·
   Access 전용 경로)는 pod가 이 목록에 넣는다.
2. `request.tenant_id`가 uuid.UUID가 아니면(없음 · None · str 포함) 403 tenant_required(problem+json) — fail-closed.
3. 아니면 `transaction.atomic(durable=True)`를 열고 `SELECT set_config('app.tenant_id', %s, true)`(값 = str(uuid) — UUID
   객체는 클라이언트 쪽 바인딩에서 `::uuid` 리터럴이 되어 함수 해석이 실패한다) 뒤 뷰를 부른다.
   - durable = 요청 트랜잭션이 가장 바깥이다. 요청 코드에서 durable atomic을 쓰지 않는다(이 미들웨어 아래에서는 항상 실패).
   - 롤백 뜻은 ATOMIC_REQUESTS와 같다: 뷰 예외는 process_exception이 롤백으로 표시한다(Django는 뷰 예외를 미들웨어 안쪽에서
     응답으로 바꾸므로 그대로 두면 커밋된다). 예외 없이 돌려준 4xx · 5xx 응답(Ninja HttpError 포함)은 커밋한다. 이 미들웨어보다
     안쪽에서 process_exception으로 응답을 돌려주는 미들웨어를 두면 롤백 표시가 빠진다 — 두지 않는다.
   - Ninja는 뷰 안에서 예외를 응답으로 바꾼다(api.on_exception — DEBUG=True의 기본 Exception 처리기 · pod가 둔 catch-all
     처리기) → 그 응답에는 process_exception이 불리지 않아 쓰기가 커밋된다. Ninja에 catch-all `Exception` 처리기를 두지
     않는다(500 internal_error는 Django handler500이 만든다). 꼭 두면 그 처리기에서 `transaction.set_rollback(True)`를 부른다.
     HttpError · ValidationError는 쓰기보다 먼저 올린다(쓴 뒤에 올리면 커밋된다).
   - 요청 트랜잭션 안에서 외부 호출(Authentik 등)을 오래 기다리지 않는다 — app role의
     idle_in_transaction_session_timeout 30 s가 세션을 끊는다.
4. 응답이 StreamingHttpResponse(FileResponse 포함)면 RuntimeWarning을 낸다 — 본문은 트랜잭션이 끝난 뒤 컨텍스트 없이
   만들어진다(A 등급 0행 · 쓰기는 자동 커밋) → 스트리밍 본문에서 DB에 접근하지 않는다(경고만 · 차단 장치 없음).
ATOMIC_REQUESTS(뷰만 감싼다) · SET LOCAL(bind 불가) · 세션 GUC(풀 · 영속 연결에서 다음 요청으로 샌다)는 쓰지 않는다.

컨텍스트 도우미(GUC SQL을 직접 쓰지 않고 이것들을 쓴다 — T069 publish · T073 관리자 교차 테넌트)
- set_tenant_context(tenant_id | None): atomic 안에서만(밖이면 TransactionManagementError — 트랜잭션 밖의
  set_config(…, true)는 조용히 무효다) · None = 같은 트랜잭션 안에서 컨텍스트를 비운다. 바꾼 값은 최상위 트랜잭션이 끝날
  때까지 남는다(savepoint RELEASE로는 되돌아가지 않는다).
- current_tenant_id(): GUC의 NULL(세션에서 미정의)과 ''(지역 설정이 끝난 세션)를 모두 None으로 읽는다.
- tenant_context(tenant_id | None): 범위 도우미 — 블록 안에서만 바꾸고 나갈 때 이전 컨텍스트로 되돌린다. 교차 테넌트 작업
  (T073 관리자 revoke의 publish 등)은 set_tenant_context를 직접 부르지 않고 이것으로 감싼다(직접 바꾸면 요청의 남은 코드가
  다른 테넌트로 돈다).

check_rls
함수 check_rls(*, using=…, require_rls_role=False) → 위반 문장 목록(각 문장은 `<이름>: <사유>` — 이름은 테이블 · 함수
이름이고, Django 스키마 판정은 django_migrations, 연결 role 단언은 session_user) + 같은 이름의 관리 명령(`--database` ·
`--require-rls-role` · 위반 전부를 담은 CommandError · 성공 줄 `check_rls: OK - A 등급 N · B 등급 M · 프레임워크 K`). 판정은
_scan_rls 독스트링. 검사 범위의 경계(계약 T068 r4): RLS의 카탈로그 모양(관계 등급 · 정책 모양과 식 · 상속) · 소유자 권한으로
도는 객체(뷰 · SECURITY DEFINER · 재작성 규칙) · 런타임 role을 본다 — 데이터 흐름(트리거 · 애플리케이션 코드가 A 행을 B 표로
옮기기 등)은 보지 않는다(마이그레이션 · 코드 리뷰 몫). 카탈로그 SELECT만 하는 트랜잭션 하나(바깥 atomic 안이면 savepoint)에서
search_path를 pg_catalog로 고정하고 돌린 뒤 롤백한다(DB · 세션 수준 search_path에 둔 사용자 연산자가 스캔 SQL과 deparse를
가리지 못하게 — 호출 뒤 세션 상태는 그대로다). 권한에 기대는 판정을 쓰지 않는다(app role 기동 · owner CI가 같은 결과 —
카탈로그를 읽지 못하면 조용히 통과하지 않고 DB 오류로 실패한다). 위반 문장 · 경고 · 명령 출력의 고정 문구는 cp949로
인코딩되는 글자만 쓴다(Windows 콘솔 리디렉트 — 성공 줄의 하이픈도 ASCII).

import 시점에는 DB도 설정 값도 건드리지 않는다(django.setup()이 DB에 닿으면 안 된다) — 설정은 요청 · 호출 때 읽는다.
"""

from __future__ import annotations

import contextlib
import re
import uuid
import warnings
from collections.abc import Callable, Collection, Iterator
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Literal

from django.apps import apps
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import DEFAULT_DB_ALIAS, connections, migrations, models, transaction
from django.db.transaction import TransactionManagementError
from django.http import HttpRequest, HttpResponseBase, StreamingHttpResponse

from django_common.problem import problem_response

if TYPE_CHECKING:
    from django.db.backends.utils import CursorWrapper

__all__ = [
    "FRAMEWORK_TABLES",
    "GLOBAL_TABLE_ALLOWLIST",
    "GlobalModel",
    "TenantContextMiddleware",
    "TenantModel",
    "check_rls",
    "current_tenant_id",
    "rls_policies",
    "set_tenant_context",
    "tenant_context",
]

# Django 프레임워크 테이블 — 등급 분류 밖(테넌트 데이터 없음). 정확한 이름 10개 · 접두 규칙 없음 · pod가 넓힐 수 없다.
FRAMEWORK_TABLES: frozenset[str] = frozenset(
    {
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
)
# B 등급(pod 전역 · RLS 미적용) 허용 목록 — 추가는 contracts/pod-template.md와 규칙 개정이 먼저다.
GLOBAL_TABLE_ALLOWLIST: frozenset[str] = frozenset(
    {"tenant", "tenant_membership", "outbox", "session_revocation_log"}
)

_EXEMPT_SETTING = "TENANT_CONTEXT_EXEMPT_PATHS"
_DEFAULT_EXEMPT_PATHS = ("/healthz", "/ready", "/health")
# 「이 미들웨어의 atomic이 열려 있다」 요청 표식(process_exception이 롤백을 표시할지 가른다).
_ATOMIC_MARK = "_django_common_tenant_atomic"
_POLICY_NAME = "tenant_isolation"
# data-model §7 — NULLIF: 같은 세션에서 지역 설정이 끝나면 GUC가 ''로 남는다(''::uuid는 22P02).
_POLICY_EXPR = "tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid"
# 정책 식의 정본 = PG가 _POLICY_EXPR를 저장한 뒤 pg_get_expr(…, polrelid)로 되살린 꼴(PG 주 버전별 — deparse는 주 버전마다
# 달라질 수 있다). check_rls는 tenant_isolation의 USING과 WITH CHECK가 둘 다 이 값과 글자 그대로 같아야 통과시키고, 정본이 없는
# 주 버전이면 실패시킨다(fail-closed). 정본 추가는 계약 §테이블 등급 ③ 개정이 먼저다 — tc-16이 rls_policies가 만든 정책의
# 실측 deparse와 대조한다.
_CANONICAL_POLICY_EXPR: dict[int, str] = {
    18: "(tenant_id = (NULLIF(current_setting('app.tenant_id'::text, true), ''::text))::uuid)",
}
# pg_policy.polroles = {0} = PUBLIC.
_PUBLIC_ROLES = (0,)
# 「Django 스키마」 = 이 표(r)가 있는 스키마(정확히 하나) — 프레임워크 면제 · B 등급은 그 스키마의 표만 인정한다.
_DJANGO_MIGRATIONS = "django_migrations"
# 프레임워크 이름(FRAMEWORK_TABLES)을 db_table로 쓸 수 있는 앱(Django contrib).
_CONTRIB_APP_LABELS = frozenset({"auth", "contenttypes", "sessions", "admin"})
# fullmatch로 쓴다 — `$`는 끝 줄바꿈 앞에서도 맞는다. 63 = PG 식별자 최대 길이.
_TABLE_NAME = re.compile(r"[a-z_][a-z0-9_]*")
_MAX_IDENTIFIER_LENGTH = 63
_STREAMING_WARNING = (
    "TenantContextMiddleware: StreamingHttpResponse 본문은 요청 트랜잭션이 끝난 뒤 테넌트 컨텍스트 없이 만들어진다"
    " - 본문 생성기에서 DB에 접근하지 않는다(A 등급은 0행 · 쓰기는 자동 커밋)"
)


class TenantModel(models.Model):
    """A 등급(테넌트 범위) 추상 모델 — id UUID v4 PK · tenant_id UUID · 인덱스 (tenant_id, id). 규칙은 모듈 독스트링."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    tenant_id = models.UUIDField()

    class Meta:
        abstract = True
        indexes = [models.Index(fields=["tenant_id", "id"], name="%(class)s_tenant_id_idx")]


class GlobalModel(models.Model):
    """B 등급(pod 전역) 추상 표식 — 필드 · PK를 더하지 않는다. db_table은 GLOBAL_TABLE_ALLOWLIST 안이어야 한다."""

    class Meta:
        abstract = True


def set_tenant_context(tenant_id: uuid.UUID | None, *, using: str = DEFAULT_DB_ALIAS) -> None:
    """현재 트랜잭션의 테넌트 컨텍스트(GUC app.tenant_id · is_local)를 tenant_id로 둔다 — None이면 비운다('')."""
    connection = connections[using]
    if not connection.in_atomic_block:
        raise TransactionManagementError(
            "set_tenant_context는 transaction.atomic() 안에서만 부를 수 있다"
            "(트랜잭션 밖의 set_config(…, true)는 효과가 없다)"
        )
    if tenant_id is None:
        value = ""
    elif isinstance(tenant_id, uuid.UUID):
        value = str(tenant_id)
    else:
        raise TypeError(f"tenant_id는 uuid.UUID 또는 None이어야 한다(받은 타입 {type(tenant_id).__name__})")
    with connection.cursor() as cursor:
        cursor.execute("SELECT set_config('app.tenant_id', %s, true)", [value])


def current_tenant_id(*, using: str = DEFAULT_DB_ALIAS) -> uuid.UUID | None:
    """현재 세션 · 트랜잭션의 테넌트 컨텍스트 — GUC가 NULL이거나 ''이면 None. UUID로 읽히지 않으면 ValueError(버그)."""
    with connections[using].cursor() as cursor:
        cursor.execute("SELECT NULLIF(current_setting('app.tenant_id', true), '')")
        (raw,) = cursor.fetchone()
    if raw is None:
        return None
    try:
        return uuid.UUID(raw)
    except ValueError:
        raise ValueError(f"GUC app.tenant_id 값이 UUID 형식이 아니다(길이 {len(raw)})") from None


@contextlib.contextmanager
def tenant_context(tenant_id: uuid.UUID | None, *, using: str = DEFAULT_DB_ALIAS) -> Iterator[None]:
    """범위 도우미 — 블록 안에서만 테넌트 컨텍스트를 tenant_id(None = 비움)로 두고, 나갈 때 이전 컨텍스트로 되돌린다.

    교차 테넌트 작업(T073 관리자 revoke의 `publish(..., tenant_id=대상)` 등)은 이것으로 감싼다 — set_config(…, true)는
    최상위 트랜잭션이 끝날 때까지 남고 savepoint RELEASE로는 되돌아가지 않으므로, set_tenant_context를 직접 부르면 요청의
    남은 코드가 다른 테넌트로 돈다.

    - 바깥 atomic 안에서만 쓴다(밖이면 TransactionManagementError — 요청 밖 작업은 바깥 atomic을 직접 연다. 밖에서도 받아
      주면 안쪽 atomic이 가장 바깥이 되어 블록 끝에서 커밋된다).
    - 이전 값(current_tenant_id)을 읽고 transaction.atomic(using)(savepoint) 안에서 바꾼 뒤 블록을 돈다.
    - 정상 종료: set_tenant_context(이전 값)로 되돌린다. 예외: savepoint 롤백이 GUC와 블록 안의 쓰기를 함께 되돌린다(예외는
      그대로 전파). 블록 안에서 transaction.set_rollback(True)를 했으면 되돌림 쿼리 없이 savepoint 롤백에 맡긴다(롤백 표시가
      선 트랜잭션에서는 쿼리를 낼 수 없다).
    """
    connection = connections[using]
    if not connection.in_atomic_block:
        raise TransactionManagementError(
            "tenant_context는 transaction.atomic() 안에서만 쓸 수 있다(요청 밖 작업은 바깥 atomic을 직접 연다)"
        )
    previous = current_tenant_id(using=using)
    with transaction.atomic(using=using):
        set_tenant_context(tenant_id, using=using)
        yield
        if not transaction.get_rollback(using=using):
            set_tenant_context(previous, using=using)


def _exempt_paths() -> Collection[str]:
    """설정 TENANT_CONTEXT_EXEMPT_PATHS를 지금 읽는다(없으면 라이브러리 기본 헬스 3) — str만 담은 tuple · list · set · frozenset.

    str 하나를 받으면 `in`이 부분 문자열 검사가 되어 `/`까지 면제될 수 있다 → ImproperlyConfigured(설정 이름만 싣는다).
    """
    value = getattr(settings, _EXEMPT_SETTING, _DEFAULT_EXEMPT_PATHS)
    if not isinstance(value, (tuple, list, set, frozenset)) or not all(isinstance(path, str) for path in value):
        raise ImproperlyConfigured(
            f"{_EXEMPT_SETTING}는 str만 담은 tuple · list · set · frozenset이어야 한다"
        )
    return value


class TenantContextMiddleware:
    """요청 트랜잭션에 테넌트 컨텍스트를 둔다(sync 전용) — 동작 전부는 모듈 독스트링 「TenantContextMiddleware」."""

    sync_capable = True
    async_capable = False

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        if request.path_info in _exempt_paths():
            return self.get_response(request)
        tenant_id = getattr(request, "tenant_id", None)
        if not isinstance(tenant_id, uuid.UUID):
            return problem_response("tenant_required", 403)
        with transaction.atomic(using=DEFAULT_DB_ALIAS, durable=True):
            setattr(request, _ATOMIC_MARK, True)
            try:
                set_tenant_context(tenant_id, using=DEFAULT_DB_ALIAS)
                response = self.get_response(request)
            finally:
                vars(request).pop(_ATOMIC_MARK, None)
        if isinstance(response, StreamingHttpResponse):
            warnings.warn(_STREAMING_WARNING, RuntimeWarning, stacklevel=2)
        return response

    def process_exception(self, request: HttpRequest, exception: Exception) -> None:
        """뷰 예외 → 이 미들웨어의 atomic이 열려 있을 때만 롤백을 표시한다(응답은 만들지 않는다 — None)."""
        if getattr(request, _ATOMIC_MARK, False):
            transaction.set_rollback(True, using=DEFAULT_DB_ALIAS)
        return None


def rls_policies(table: str) -> list[migrations.RunSQL]:
    """A 등급 테이블의 RLS 연산 셋(전용 마이그레이션의 operations에 펼친다 — `[*rls_policies("<db_table>")]`).

    ENABLE ↔ DISABLE · FORCE ↔ NO FORCE · CREATE POLICY tenant_isolation(PERMISSIVE · FOR ALL · TO PUBLIC · USING과 WITH
    CHECK = data-model §7 식) ↔ DROP POLICY IF EXISTS. 상태 무관 RunSQL이라 빈 ProjectState로도 다시 적용할 수 있고, 되돌리기는
    Migration.unapply가 역순(정책 → FORCE → ENABLE)으로 돈다. 매번 새 목록을 돌려준다. 이름이 `[a-z_][a-z0-9_]*` · 63자 이하가
    아니면 ValueError(마이그레이션 import 때 실패) — 그 꼴이라 큰따옴표 인용이 안전하다.
    """
    if (
        not isinstance(table, str)
        or len(table) > _MAX_IDENTIFIER_LENGTH
        or _TABLE_NAME.fullmatch(table) is None
    ):
        raise ValueError(f"rls_policies: 테이블 이름은 [a-z_][a-z0-9_]* 꼴 · 63자 이하여야 한다({table!r})")
    quoted = f'"{table}"'
    return [
        migrations.RunSQL(
            sql=f"ALTER TABLE {quoted} ENABLE ROW LEVEL SECURITY",
            reverse_sql=f"ALTER TABLE {quoted} DISABLE ROW LEVEL SECURITY",
        ),
        migrations.RunSQL(
            sql=f"ALTER TABLE {quoted} FORCE ROW LEVEL SECURITY",
            reverse_sql=f"ALTER TABLE {quoted} NO FORCE ROW LEVEL SECURITY",
        ),
        migrations.RunSQL(
            sql=(
                f"CREATE POLICY {_POLICY_NAME} ON {quoted} AS PERMISSIVE FOR ALL TO PUBLIC"
                f" USING ({_POLICY_EXPR}) WITH CHECK ({_POLICY_EXPR})"
            ),
            reverse_sql=f"DROP POLICY IF EXISTS {_POLICY_NAME} ON {quoted}",
        ),
    ]


# 스캔 범위의 관계(FROM · WHERE 조각 — 별칭 c = pg_class · n = pg_namespace): 시스템 스키마(pg_catalog · information_schema ·
# pg_toast* · pg_temp_*) 밖 모든 스키마의 관계(표 r · 분할 표 p · 뷰 v · 구체화 뷰 m · 외부 테이블 f). 확장 멤버(pg_depend
# deptype 'e')는 그 확장의 소유자가 superuser일 때만 뺀다 — CNPG Database.extensions(superuser 설치)의 멤버는 빠지고, owner
# role이 만든 trusted 확장(PG 13+ · 소유자 = 만든 role)에 넣은 표는 빠지지 않는다. 파티션 자식은 r(relispartition)이라 자기
# 판정을 받는다(파티션을 직접 질의하면 그 파티션의 RLS만 적용된다 — 부모 쪽 판정은 _INHERITS_SQL). 카탈로그 이름 · 함수는
# pg_catalog로 한정하고, 비한정 연산자(IN · NOT IN · = · <>)는 스캔이 고정한 search_path(pg_catalog 하나 —
# _PIN_SEARCH_PATH_SQL)로 해석된다. pg_roles는 공개 뷰라 app role도 읽는다. 관계 판정(_RELATIONS_SQL)과 관계 소유 판정
# (_RLS_ROLE_SQL · T068 r4 H4)이 이 범위를 함께 쓴다.
_SCAN_RELATIONS = """FROM pg_catalog.pg_class AS c
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
  )"""
_RELATIONS_SQL = f"""
SELECT c.oid, n.nspname, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity
{_SCAN_RELATIONS}
ORDER BY n.nspname, c.relname
"""
# 정책 — 식은 pg_get_expr(…, polrelid)의 deparse 원문(_CANONICAL_POLICY_EXPR와 비교 · 고정된 search_path에서 pg_catalog 밖의
# 연산자 · 함수는 스키마를 붙여 찍힌다) · polroles는 oid 배열({0} = PUBLIC) · oid는 의존 검사(_POLICY_DEPENDENCIES_SQL)의 열쇠.
_POLICIES_SQL = """
SELECT p.oid, p.polrelid, p.polname, p.polcmd, p.polpermissive, p.polroles,
       pg_catalog.pg_get_expr(p.polqual, p.polrelid), pg_catalog.pg_get_expr(p.polwithcheck, p.polrelid)
FROM pg_catalog.pg_policy AS p
ORDER BY p.polrelid, p.polname
"""
# 표 · 열(pg_class) 밖의 객체에 의존하는 정책(T068 r3 G3 a · 문구 r4 H5) — deparse 글자 비교가 못 보는 의미 우회(NULLIF 안의
# 연산자처럼 deparse에 찍히지 않는 객체 · 고정 전 세션에서 비한정으로 보이던 사용자 객체)를 잡는다. 연산자 인자의 암시적
# 형변환은 deparse에 찍혀 글자 비교도 잡고, 형변환 함수는 이 의존 검사도 잡는다(PG 18.6 실측). initdb 부트스트랩 객체
# (OID < 12000 — 정본 식이 쓰는 연산자 · 함수 · 타입 · 콜레이션은 전부 여기)는 pinned라 pg_depend 행이 없고(PG 15+),
# rls_policies가 만든 정책은 표(deptype 'a')와 열 tenant_id(deptype 'n')에만 의존한다(PG 18.6 실측). initdb 후반 객체(OS
# 콜레이션 · 시스템 뷰 · information_schema · plpgsql)와 사용자 정의 연산자 · 함수 · 타입 · 콜레이션은 행을 남겨 위반이다.
# 카탈로그만 읽는다(role 무관).
_POLICY_DEPENDENCIES_SQL = """
SELECT DISTINCT d.objid
FROM pg_catalog.pg_depend AS d
WHERE d.classid = 'pg_catalog.pg_policy'::pg_catalog.regclass
  AND d.refclassid <> 'pg_catalog.pg_class'::pg_catalog.regclass
ORDER BY d.objid
"""
# 상속 · 파티션 링크(T068 r4 H1 · r5 I1) — 부모를 거친 질의에는 부모의 RLS만, 자식을 직접 읽는 질의에는 자식의 RLS만
# 적용된다(PG 문서 5.11). 그래서 A 등급 관계가 낀 링크는 양쪽이 모두 A여야 한다: A 등급 표(r · p)의 부모가 A가 아니면(B ·
# 프레임워크 · 스캔 밖 — 시스템 스키마 · superuser 소유 확장의 멤버 · fail-closed) 그 A 표에, A 등급 관계의 자식이 B · 프레임워크면
# 그 자식에 위반 한 줄이다(B · 프레임워크끼리의 링크 · 스캔 밖 자식은 판정하지 않는다 — r5 리뷰 R5-2). 부모 이름은 regclass
# 출력이다(고정된 search_path에서는 pg_catalog 밖 관계에 스키마가 붙는다). 분할 인덱스의 행(자식 · 부모 = 인덱스)도 섞여 오지만
# 양쪽 다 스캔한 관계가 아니라 어느 판정에도 쓰이지 않는다.
_INHERITS_SQL = """
SELECT i.inhrelid, i.inhparent, i.inhparent::pg_catalog.regclass::pg_catalog.text
FROM pg_catalog.pg_inherits AS i
ORDER BY i.inhrelid, i.inhseqno
"""
# 재작성 규칙 — 뷰 · 구체화 뷰의 _RETURN(SELECT 규칙 = 뷰 정의 · 뷰 판정이 맡는다)은 뺀다. 스캔한 관계의 것만 판정한다.
_RULES_SQL = """
SELECT r.ev_class, r.rulename
FROM pg_catalog.pg_rewrite AS r
WHERE r.rulename <> '_RETURN'
ORDER BY r.ev_class, r.rulename
"""
# 시스템 스키마 밖의 SECURITY DEFINER 함수(프로시저 · 트리거 함수 포함) — 확장 멤버 제외 규칙은 _RELATIONS_SQL과 같다.
_SECURITY_DEFINER_SQL = """
SELECT n.nspname, p.proname
FROM pg_catalog.pg_proc AS p
JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
WHERE p.prosecdef
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND NOT pg_catalog.starts_with(n.nspname::pg_catalog.text, 'pg_toast')
  AND NOT pg_catalog.starts_with(n.nspname::pg_catalog.text, 'pg_temp_')
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_depend AS d
    JOIN pg_catalog.pg_extension AS e ON e.oid = d.refobjid
    JOIN pg_catalog.pg_roles AS ext_owner ON ext_owner.oid = e.extowner
    WHERE d.classid = 'pg_catalog.pg_proc'::pg_catalog.regclass
      AND d.objid = p.oid
      AND d.refclassid = 'pg_catalog.pg_extension'::pg_catalog.regclass
      AND d.deptype = 'e'
      AND ext_owner.rolsuper
  )
ORDER BY n.nspname, p.proname
"""
_SERVER_VERSION_SQL = "SELECT pg_catalog.current_setting('server_version_num')"
# 스캔의 첫 문장(T068 r3 G3 b) — 이 트랜잭션 동안만(is_local) search_path를 pg_catalog 하나로 둔다. _scan_rls가 끝에 롤백한다.
_PIN_SEARCH_PATH_SQL = "SELECT pg_catalog.set_config('search_path', 'pg_catalog', true)"
# 연결 role 단언(--require-rls-role · 기동 검사) — 한 문장 · 한 boolean · 바인딩과 % 없음.
# - 앞 EXISTS(T068 r3 G4): session_user가 RLS를 비켜 가는 role(superuser · BYPASSRLS)이거나 그 멤버인가. current_user만 보면
#   Django OPTIONS["assume_role"](접속 직후 SET ROLE)과 SET ROLE이 가능한 멤버십을 놓친다 — current_user는 session_user이거나
#   session_user가 SET ROLE할 수 있는 role이므로 이 판정이 current_user도 덮는다. MEMBER = 직간접 멤버십(자기 자신 포함 ·
#   superuser는 모든 role의 멤버 · INHERIT · SET 옵션과 무관) · BYPASSRLS 속성은 상속되지 않지만 SET ROLE은 된다.
# - 뒤 EXISTS(T068 r4 H4): session_user가 스캔 범위(_SCAN_RELATIONS) 관계의 소유자(relowner)이거나 그 멤버인가 — 소유자는
#   FORCE와 무관하게 NO FORCE · DISABLE · DROP POLICY로 RLS를 끌 수 있다(마이그레이션이 app 자격으로 돈 오설정 · 정상 배치의
#   app role은 아무것도 소유하지 않는다).
_RLS_ROLE_SQL = f"""
SELECT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles AS r
  WHERE (r.rolsuper OR r.rolbypassrls) AND pg_catalog.pg_has_role(session_user, r.oid, 'MEMBER')
) OR EXISTS (
SELECT 1
{_SCAN_RELATIONS}
  AND pg_catalog.pg_has_role(session_user, c.relowner, 'MEMBER')
)
"""
_TABLE_KINDS = frozenset({"r", "p"})
_RELKIND_LABELS = {"r": "표", "p": "분할 표", "v": "뷰", "m": "구체화 뷰", "f": "외부 테이블"}
# 관계 등급 — ① 프레임워크 면제 · ② B · ③ A(_relation_grade).
_Grade = Literal["framework", "b", "a"]


@dataclass(frozen=True)
class _Policy:
    oid: int
    name: str
    command: str
    permissive: bool
    roles: tuple[int, ...]
    using: str | None
    check: str | None


@dataclass
class _RlsScan:
    """check_rls 판정 결과 — 위반 문장 목록과 등급별 관계 수(관리 명령의 성공 한 줄)."""

    violations: list[str] = field(default_factory=list)
    grade_a: int = 0
    grade_b: int = 0
    framework: int = 0


def _server_major(cursor: CursorWrapper) -> int:
    """연결된 서버의 PG 주 버전(server_version_num // 10000 — 예: 180006 → 18)."""
    cursor.execute(_SERVER_VERSION_SQL)
    (raw,) = cursor.fetchone()
    return int(raw) // 10000


def _isolation_problems(
    policy: _Policy, canonical: str | None, pg_major: int, foreign_dependents: Collection[int]
) -> list[str]:
    """정책 tenant_isolation의 모양(FOR ALL · PERMISSIVE · 대상 PUBLIC · USING과 WITH CHECK) · 식(정본과 글자 그대로 같음) ·
    의존(표 · 열 밖의 객체 없음 — foreign_dependents = _POLICY_DEPENDENCIES_SQL의 정책 oid) — 검사 하나가 사유 한 줄이다. 정본이
    없는 PG 주 버전이면 식을 판정할 수 없으므로 위반이다(fail-closed). 의존 검사는 정본 유무와 무관하게 돈다."""
    problems: list[str] = []
    if policy.command != "*":
        problems.append(f"정책 {_POLICY_NAME}이 FOR ALL이 아니다(polcmd {policy.command})")
    if not policy.permissive:
        problems.append(f"정책 {_POLICY_NAME}이 PERMISSIVE가 아니다")
    if policy.roles != _PUBLIC_ROLES:
        problems.append(f"정책 {_POLICY_NAME}의 대상이 PUBLIC이 아니다(polroles)")
    if policy.using is None:
        problems.append(f"정책 {_POLICY_NAME}에 USING이 없다")
    if policy.check is None:
        problems.append(f"정책 {_POLICY_NAME}에 WITH CHECK가 없다")
    if canonical is None:
        problems.append(
            f"PG 주 버전 {pg_major}의 정본 정책 식이 없다 - 식을 판정할 수 없어 실패시킨다"
            "(fail-closed · 정본 추가는 계약 개정)"
        )
    else:
        for clause, expression in (("USING", policy.using), ("WITH CHECK", policy.check)):
            if expression is not None and expression != canonical:
                problems.append(f"정책 {_POLICY_NAME}의 {clause} 식이 정본과 다르다 - rls_policies(<표 이름>)로 만든다")
    if policy.oid in foreign_dependents:
        # 문구(T068 r5 I5): 의존 검사는 사용자 객체만이 아니라 initdb 후반 객체(OS 콜레이션 · 시스템 뷰 · information_schema ·
        # plpgsql)도 잡는다 — pinned(initdb 부트스트랩)가 아닌 객체는 pg_depend 행을 남긴다(_POLICY_DEPENDENCIES_SQL 주석).
        problems.append(
            f"정책 {_POLICY_NAME}의 식이 표 · 열 밖의 객체(사용자 객체 · initdb 후반 객체 - 연산자 · 함수 · 타입 · 콜레이션 ·"
            " 형변환)에 의존한다(pg_depend) - rls_policies(<표 이름>)로 만든다"
        )
    return problems


def _grade_a_problems(
    relkind: str,
    rls_enabled: bool,
    rls_forced: bool,
    policies: list[_Policy],
    canonical: str | None,
    pg_major: int,
    foreign_dependents: Collection[int],
    non_a_parents: Collection[str],
) -> list[str]:
    """A 등급 관계 판정 — 표(r · p)가 아니면 그 한 줄뿐이다. 표면 RLS 두 플래그 · 정책 tenant_isolation(_isolation_problems) ·
    다른 정책 없음(T068 r4 H2 — PERMISSIVE든 RESTRICTIVE든 · 이름 목록 한 줄) · 상속 · 파티션 부모가 전부 A 등급(H1 —
    non_a_parents = A 등급이 아닌 부모의 이름 · 한 줄 · 표 r와 분할 표 p 모두 — 파티션이 다시 분할 표인 경우 포함 · r5 I2)을
    본다. 검사 하나가 사유 한 줄이다. 반대 방향(A 관계의 B · 프레임워크 자식)은 그 자식의 판정이다(_non_a_child_problems)."""
    if relkind not in _TABLE_KINDS:
        return [
            f"A 등급 관계가 표가 아니다({_RELKIND_LABELS[relkind]}) - 뷰 · 구체화 뷰 · 외부 테이블은 RLS로 행을 거르지"
            " 못한다(뷰는 소유자 권한으로 기저 테이블을 읽어 RLS를 우회한다)"
        ]
    problems: list[str] = []
    if not rls_enabled:
        problems.append("ROW LEVEL SECURITY가 꺼져 있다(relrowsecurity)")
    if not rls_forced:
        problems.append("FORCE ROW LEVEL SECURITY가 꺼져 있다(relforcerowsecurity)")
    isolation = next((policy for policy in policies if policy.name == _POLICY_NAME), None)
    if isolation is None:
        problems.append(f"정책 {_POLICY_NAME}이 없다")
    else:
        problems.extend(_isolation_problems(isolation, canonical, pg_major, foreign_dependents))
    others = sorted(policy.name for policy in policies if policy.name != _POLICY_NAME)
    if others:
        problems.append(
            f"{_POLICY_NAME} 밖의 정책이 있다({', '.join(others)}) - A 등급 표의 정책은 {_POLICY_NAME} 하나뿐이다"
            f"(PERMISSIVE는 OR로 합쳐져 격리를 넓히고, RESTRICTIVE 식은 {_POLICY_NAME}보다 먼저 모든 행에 평가될 수 있어"
            " 형변환 오류 · 부작용으로 다른 테넌트 값이 샌다)"
        )
    if non_a_parents:
        problems.append(
            f"상속 · 파티션 부모({', '.join(sorted(non_a_parents))})가 A 등급이 아니다(B · 프레임워크 · 스캔 밖 관계) -"
            " 부모를 거친 질의에는 부모의 RLS만 적용되어 이 표의 행이 RLS 없이 읽힌다"
        )
    return problems


def _relation_grade(name: str, relkind: str, in_django_schema: bool) -> _Grade:
    """관계 등급(_scan_rls ①–③) — Django 스키마의 FRAMEWORK_TABLES 표(r) = 'framework' · Django 스키마의 허용 목록 표(r · p)
    = 'b' · 그 밖 전부 = 'a'(이름이 같아도 다른 스키마 · 다른 relkind면 A)."""
    if name in FRAMEWORK_TABLES and in_django_schema and relkind == "r":
        return "framework"
    if name in GLOBAL_TABLE_ALLOWLIST and in_django_schema and relkind in _TABLE_KINDS:
        return "b"
    return "a"


def _grade_b_problems(rls_enabled: bool) -> list[str]:
    """B 등급(Django 스키마의 허용 목록 이름 표 r · p)은 RLS가 꺼져 있어야 한다."""
    if rls_enabled:
        return [
            "B 등급(허용 목록) 테이블에 ROW LEVEL SECURITY가 켜져 있다 - B 등급은 RLS를 걸지 않는다"
            "(릴레이 · 웹훅 · 기동 재적용이 0행을 본다)"
        ]
    return []


def _non_a_child_problems(grade: _Grade, grade_a_parents: Collection[str]) -> list[str]:
    """B · 프레임워크로 판정된 관계가 A 등급 관계의 상속 · 파티션 자식이면 위반 한 줄(T068 r5 I1 — 링크의 양쪽 등급이 같아야
    한다 · grade_a_parents = A 등급 부모의 이름 · 여럿이면 정렬해 한 줄).

    자식을 직접 읽는 질의에는 자식의 RLS만 적용된다 — B · 프레임워크 판정은 RLS를 요구하지 않으므로(B = RLS 꺼짐 · 프레임워크
    = 검사 없음) A 부모를 거쳐 보이는 이 관계의 행이 직접 읽으면 RLS 없이 읽힌다. 파티션이면 부모로 쓴 A 행도 라우팅되어 이
    관계에 저장된다(PG 18.6 실측 — 컨텍스트 없는 app role이 부모로 0행 · 파티션 직접 2행). 일반 상속(INHERITS) 자식에는 부모로
    쓴 행이 저장되지 않는다(자식에 직접 쓴 행만 있다 — 실측 VD-I1b). 사유 문구는 두 경우 모두 맞는 꼴이다(r5 리뷰 R5-1).
    """
    if not grade_a_parents:
        return []
    label = "B 등급" if grade == "b" else "프레임워크 면제"
    return [
        f"상속 · 파티션 부모({', '.join(sorted(grade_a_parents))})가 A 등급인데 이 관계는 A 등급이 아니다({label}) -"
        " 이 관계를 직접 읽는 질의에는 이 관계의 RLS만 적용되어 A 부모를 거쳐 보이는 행이 RLS 없이 읽힌다"
        "(파티션이면 부모로 쓴 A 행도 이 관계에 저장된다)"
    ]


def _model_problems(grade_a_tables: Collection[str]) -> list[str]:
    """정적 모델 검사(카탈로그 쪽 입력은 스캔에서 A 등급 표(r · p)로 판정된 이름뿐). 관리되는 구체 모델만 본다(자동 M2M 중간
    모델 포함 · 프록시 · 관리되지 않는 모델은 검사 밖).

    - TenantModel: db_table이 B 허용 목록 · 프레임워크 이름이면 위반, 아니면 카탈로그에 A 등급 표로 있어야 한다.
    - GlobalModel: db_table이 B 허용 목록 안이어야 한다.
    - B 허용 목록 이름을 쓰는 모델은 GlobalModel 하위여야 한다.
    - 프레임워크 이름(FRAMEWORK_TABLES)은 Django contrib 앱(auth · contenttypes · sessions · admin)의 모델만 쓴다.
    """
    problems: list[str] = []
    for model in apps.get_models(include_auto_created=True):
        meta = model._meta
        if not meta.managed or meta.proxy:
            continue
        table = meta.db_table
        if issubclass(model, TenantModel):
            if table in GLOBAL_TABLE_ALLOWLIST or table in FRAMEWORK_TABLES:
                problems.append(
                    f"{table}: A 등급 TenantModel {meta.label}의 테이블 이름이 B 허용 목록 · 프레임워크 면제 목록에 있다"
                )
            elif table not in grade_a_tables:
                problems.append(
                    f"{table}: A 등급 TenantModel {meta.label}의 테이블이 카탈로그에 A 등급 표(r · p)로 없다"
                    "(마이그레이션 · db_table 확인)"
                )
        if issubclass(model, GlobalModel) and table not in GLOBAL_TABLE_ALLOWLIST:
            problems.append(f"{table}: B 등급 GlobalModel {meta.label}의 테이블 이름이 허용 목록(GLOBAL_TABLE_ALLOWLIST) 밖이다")
        if table in GLOBAL_TABLE_ALLOWLIST and not issubclass(model, GlobalModel):
            problems.append(f"{table}: 허용 목록 이름을 쓰는 모델 {meta.label}이 GlobalModel 하위가 아니다")
        if table in FRAMEWORK_TABLES and meta.app_label not in _CONTRIB_APP_LABELS:
            problems.append(
                f"{table}: 프레임워크 이름을 쓰는 모델 {meta.label}이 Django contrib 앱"
                "(auth · contenttypes · sessions · admin) 밖이다"
            )
    return sorted(problems)


def _scan_rls(using: str, *, require_rls_role: bool = False) -> _RlsScan:
    """카탈로그와 모델을 판정한다(check_rls와 관리 명령이 쓴다).

    범위: 시스템 스키마 밖 모든 스키마의 관계(r · p · v · m · f — _SCAN_RELATIONS)와 SECURITY DEFINER 함수 — superuser가
    소유한 확장의 멤버만 뺀다(owner role이 만든 trusted 확장에 넣어 빼돌리지 못하게). 「Django 스키마」 = django_migrations
    표(r)가 있는 스키마(정확히 하나 — 없거나 둘 이상이면 위반 한 줄을 내고 면제 · B를 인정하지 않는다 = 전부 A).
    ① FRAMEWORK_TABLES(정확한 이름) → Django 스키마의 표(r)일 때만 면제.
    ② GLOBAL_TABLE_ALLOWLIST → Django 스키마의 표(r · p)일 때만 B이고, RLS가 꺼져 있어야 한다.
    ③ 그 밖의 모든 관계(①②의 이름이라도 다른 스키마 · 다른 relkind면 여기) = A → 표(r · p)여야 하고(뷰 · 구체화 뷰 · 외부
       테이블은 위반) relrowsecurity · relforcerowsecurity 둘 다 · 정책 tenant_isolation이 FOR ALL(polcmd '*') · PERMISSIVE ·
       대상 PUBLIC · USING과 WITH CHECK 둘 다 있고 둘 다 정본 식(_CANONICAL_POLICY_EXPR[PG 주 버전] — 없으면 위반)과
       글자 그대로 같으며 표 · 열 밖의 객체에 의존하지 않는다(pg_depend — _POLICY_DEPENDENCIES_SQL). tenant_isolation 밖의
       정책은 PERMISSIVE든 RESTRICTIVE든 위반이다(T068 r4 H2 — PERMISSIVE는 OR로 격리를 넓히고, RESTRICTIVE 식은
       tenant_isolation보다 먼저 모든 행에 평가될 수 있다).
       상속 · 파티션 링크(_INHERITS_SQL)는 양쪽 등급이 같아야 한다(T068 r5 · build-notes 「### T068 r4 결과 · r5 결정」):
       A 관계(표 r · 분할 표 p — 파티션이 다시 분할 표인 경우 포함 · I2)의 부모가 ③으로 판정된 관계가 아니면(B · 프레임워크 ·
       스캔 밖 — r4 H1 · 부모를 거친 질의에는 부모의 RLS만 적용된다) 그 A 관계에, A 관계의 자식이 ①②로 판정되면(I1 — 부모로
       쓴 A 행이 파티션 라우팅으로 그 자식에 저장되고, 자식을 직접 읽는 질의에는 자식의 RLS만 적용된다) 그 자식에 위반 한
       줄이다(부모가 여럿이면 이름을 정렬해 한 줄). 링크 하나는 두 판정 가운데 하나에만 걸린다(자식이 A면 부모 쪽 · 부모가 A면
       자식 쪽) — 한 트리에 둘 다 있으면 각자의 관계에 한 줄씩이다. 스캔 밖 자식(다른 세션의 TEMP 상속 자식 — 그 행은 다른
       세션이 읽지 못한다 · tc-28 · superuser 소유 확장의 멤버)은 판정하지 않는다.
    ④ 스캔한 관계의 재작성 규칙(_RETURN 밖)과 SECURITY DEFINER 함수 → 위반(소유자 권한으로 실행되어 RLS를 비켜 간다).
    ⑤ 모델 검사(_model_problems).
    require_rls_role이면 연결 role 단언(_RLS_ROLE_SQL — session_user가 superuser · BYPASSRLS role이거나 그 멤버면, 또는 스캔
    범위 관계의 소유자이거나 그 멤버면(H4) 위반 한 줄 — SET ROLE · assume_role 포함 · 기동 검사 · role 이름은 싣지 않는다)을
    더한다.
    위반 문장 순서: role → Django 스키마 → 관계(스키마 · 이름 순 · 규칙 포함) → 함수 → 모델.
    검사 범위의 경계(계약 T068 r4 · build-notes 「### T068 r3 결과 · r4 결정」): RLS의 카탈로그 모양 · 소유자 권한으로 도는
    객체 · 런타임 role만 본다 — 데이터 흐름(트리거 · 애플리케이션 코드가 A 행을 B 표로 옮기기 등)은 보지 않는다.

    쿼리는 전부 transaction.atomic(using) 하나 안에서 돈다(T068 r3 G3 b): 첫 문장이 search_path를 pg_catalog로 고정하고
    (_PIN_SEARCH_PATH_SQL · is_local), 블록 끝의 set_rollback(True)이 되돌린다 — 바깥 atomic 안이면 savepoint 롤백이다(RELEASE면
    고정 값이 바깥 트랜잭션 끝까지 남는다). 예외 경로도 블록 탈출로 롤백된다. 그래서 DB · 세션 수준 search_path(public을
    pg_catalog 앞에 둔 경우 등)의 사용자 연산자가 스캔 SQL의 비한정 연산자와 deparse의 이름 해석을 가리지 못하고, 호출 뒤 세션
    상태(search_path · 바깥 트랜잭션)는 그대로다.
    """
    with transaction.atomic(using=using):
        with connections[using].cursor() as cursor:
            cursor.execute(_PIN_SEARCH_PATH_SQL)
            pg_major = _server_major(cursor)
            cursor.execute(_RELATIONS_SQL)
            relations = cursor.fetchall()
            cursor.execute(_POLICIES_SQL)
            policy_rows = cursor.fetchall()
            cursor.execute(_POLICY_DEPENDENCIES_SQL)
            foreign_dependents = frozenset(objid for (objid,) in cursor.fetchall())
            cursor.execute(_INHERITS_SQL)
            inherit_rows = cursor.fetchall()
            cursor.execute(_RULES_SQL)
            rule_rows = cursor.fetchall()
            cursor.execute(_SECURITY_DEFINER_SQL)
            definer_rows = cursor.fetchall()
            role_bypasses_rls = False
            if require_rls_role:
                cursor.execute(_RLS_ROLE_SQL)
                row = cursor.fetchone()
                role_bypasses_rls = row is None or bool(row[0])
        # 읽기만 했다 — 롤백으로 search_path 고정을 되돌린다(바깥 atomic 안이면 savepoint 롤백 · RELEASE면 값이 남는다).
        transaction.set_rollback(True, using=using)
    policies: dict[int, list[_Policy]] = {}
    for oid, relid, name, command, permissive, roles, using_expr, check_expr in policy_rows:
        policy = _Policy(oid, name, command, permissive, tuple(roles), using_expr, check_expr)
        policies.setdefault(relid, []).append(policy)
    rules: dict[int, list[str]] = {}
    for relid, rule_name in rule_rows:
        rules.setdefault(relid, []).append(rule_name)
    canonical = _CANONICAL_POLICY_EXPR.get(pg_major)
    scan = _RlsScan()
    if role_bypasses_rls:
        scan.violations.append(
            "session_user: 연결 role(session_user)이 superuser · BYPASSRLS role이거나 그 멤버다(SET ROLE · assume_role로"
            " RLS를 비켜 갈 수 있다), 또는 스캔 범위 관계의 소유자(그 멤버)다 - 소유자는 NO FORCE · DROP POLICY로 RLS를 끌 수"
            " 있다(런타임은 아무것도 소유하지 않는 NOBYPASSRLS app role로만 붙는다 · --require-rls-role)"
        )
    django_schemas = sorted(
        {schema for _, schema, name, relkind, _, _ in relations if name == _DJANGO_MIGRATIONS and relkind == "r"}
    )
    django_schema = django_schemas[0] if len(django_schemas) == 1 else None
    if len(django_schemas) != 1:
        scan.violations.append(
            f"{_DJANGO_MIGRATIONS}: Django 스키마를 정할 수 없다(django_migrations 표가 있는 스키마"
            f" {len(django_schemas)}개) - 프레임워크 면제 · B 등급을 인정하지 않고 전부 A 등급으로 판정한다"
        )
    # 등급을 먼저 다 정한다 — 상속 · 파티션 링크 판정(H1 · I1)이 양쪽의 등급을 본다(부모가 자식보다 뒤에 정렬될 수 있다 · 스캔
    # 밖 관계는 등급이 없다 = A 아님).
    grades = {
        oid: _relation_grade(name, relkind, schema == django_schema) for oid, schema, name, relkind, _, _ in relations
    }
    # 링크마다 한쪽만 본다: 부모가 A가 아니면 자식 쪽 부모 목록(H1 — 자식이 A일 때 그 A 관계의 판정이 쓴다), 부모가 A이고 자식이
    # B · 프레임워크면 그 자식의 A 부모 목록(I1). 스캔 밖 자식(등급 없음)은 어느 쪽에도 쓰이지 않는다.
    non_a_parents: dict[int, list[str]] = {}
    grade_a_parents: dict[int, list[str]] = {}
    for child, parent, parent_name in inherit_rows:
        if grades.get(parent) != "a":
            non_a_parents.setdefault(child, []).append(parent_name)
        elif grades.get(child) in ("b", "framework"):
            grade_a_parents.setdefault(child, []).append(parent_name)
    grade_a_tables: set[str] = set()
    for oid, schema, name, relkind, rls_enabled, rls_forced in relations:
        grade = grades[oid]
        problems: list[str]
        if grade == "framework":
            scan.framework += 1
            problems = _non_a_child_problems(grade, grade_a_parents.get(oid, []))
        elif grade == "b":
            scan.grade_b += 1
            problems = [*_grade_b_problems(rls_enabled), *_non_a_child_problems(grade, grade_a_parents.get(oid, []))]
        else:
            scan.grade_a += 1
            if relkind in _TABLE_KINDS:
                grade_a_tables.add(name)
            problems = _grade_a_problems(
                relkind,
                rls_enabled,
                rls_forced,
                policies.get(oid, []),
                canonical,
                pg_major,
                foreign_dependents,
                non_a_parents.get(oid, []),
            )
        problems.extend(
            f"재작성 규칙이 있다({rule_name}) - 규칙 동작은 표 소유자 권한으로 실행되어 RLS를 비켜 간다"
            for rule_name in rules.get(oid, [])
        )
        where = f"(스키마 {schema} · relkind {relkind})"
        scan.violations.extend(f"{name}: {problem} {where}" for problem in problems)
    scan.violations.extend(
        f"{name}: SECURITY DEFINER 함수다 - 소유자 권한으로 실행되어 RLS를 비켜 간다 (스키마 {schema} · 함수)"
        for schema, name in definer_rows
    )
    scan.violations.extend(_model_problems(grade_a_tables))
    return scan


def check_rls(*, using: str = DEFAULT_DB_ALIAS, require_rls_role: bool = False) -> list[str]:
    """테이블 등급 검사(CI · 기동) — 위반 문장 목록(없으면 []). 각 문장은 `<이름>: <사유>`로 시작한다. 판정 · 스캔 조건(search_path
    고정 · 롤백) · 검사 범위의 경계는 _scan_rls 독스트링.

    require_rls_role=True(기동 검사 — app role)면 연결의 session_user가 superuser · BYPASSRLS role이거나 그 멤버일 때, 또는 스캔
    범위 관계의 소유자이거나 그 멤버일 때(T068 r4 H4 — 소유자는 NO FORCE · DROP POLICY로 RLS를 끌 수 있다) 위반 한 줄
    (`session_user: …`)을 더한다(런타임에 owner 자격이 들어간 사고 — SET ROLE · Django OPTIONS["assume_role"]로 current_user만
    app role인 경우 · 마이그레이션이 app 자격으로 돈 오설정 포함). CI의 owner 실행에는 켜지 않는다.
    """
    return _scan_rls(using, require_rls_role=require_rls_role).violations
