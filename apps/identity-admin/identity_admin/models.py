"""identity-admin 모델 셋(T073 설계 D4 — pod 소유 새 파일) — 셋 다 B 등급(GlobalModel · RLS 없음 · 허용 목록 이름).

정본: data-model.md §1 Tenant · §2 TenantMembership · §3 SessionRevocationLog(T073 보정 2026-11-12) · 규칙 django-pod.md
§Table grades(허용 목록 tenant · tenant_membership · outbox · session_revocation_log).

- PK `id`는 DB가 만든다(`db_default=UUID7()` — PostgreSQL 18 `uuidv7()`). 업무 필드만으로 `objects.create()`를 해도 pk가
  INSERT … RETURNING으로 채워진다(T066 가정 ③). 시계 · 난수 생성 코드가 앱에 없다 — `created_at` · `updated_at`도
  `db_default=Now()`(문장 시작 시각)다.
- `tenant_id`는 Tenant.id의 값 참조다(FK 아님 — pod 간 · 표 간 FK를 두지 않는다).
- `updated_at`은 db_default만 둔다 — SP-1에는 Tenant를 갱신하는 경로가 없다(갱신 경로는 SP-2가 Now()를 함께 쓴다).
- 제약 · 인덱스 이름은 계약 이름이다(설계 D4 표 · data-model §3 「제약 · 인덱스」): `srl_event_pk_uniq`는 웹훅 재전송 경합
  판정에 이름으로 쓴다(D12). `srl_user_floor_idx` = `(sub, nbf DESC) WHERE sid IS NULL`은 세션 하한의 sub별 최댓값(D29).
- admin 등록은 0이다(D28). 마이그레이션은 이 앱의 0001_initial 하나다(makemigrations 산출 그대로 — 손 SQL · rls_policies 0 ·
  dependencies 없음: core 0001과 엮이지 않는다 · D5).
"""

from __future__ import annotations

from django.db import models
from django.db.models.functions import UUID7, Now
from django_common.tenancy import GlobalModel

TENANT_STATUSES = ("active", "suspended")
MEMBERSHIP_ROLES = ("owner", "member")  # `admin`은 SP-2 예약 — SP-1 enum에 넣지 않는다(data-model §2)
REVOCATION_REASONS = ("logout", "logout_all", "admin", "authentik_webhook", "tenant_suspended")
TENANT_SLUG_PATTERN = r"^[a-z0-9][a-z0-9-]{1,30}$"


def _choices(values: tuple[str, ...]) -> list[tuple[str, str]]:
    return [(value, value) for value in values]


class Tenant(GlobalModel):
    """테넌트(data-model §1) — slug는 표시 · URL 용도이고 불변이다(다른 시스템의 식별자로 쓰지 않는다)."""

    id = models.UUIDField(primary_key=True, db_default=UUID7(), editable=False)
    slug = models.CharField(max_length=32)
    display_name = models.CharField(max_length=80)
    status = models.CharField(max_length=16, choices=_choices(TENANT_STATUSES), default="active")
    created_at = models.DateTimeField(db_default=Now())
    updated_at = models.DateTimeField(db_default=Now())

    class Meta(GlobalModel.Meta):
        db_table = "tenant"
        constraints = [
            models.UniqueConstraint(fields=["slug"], name="tenant_slug_uniq"),
            models.CheckConstraint(condition=models.Q(slug__regex=TENANT_SLUG_PATTERN), name="tenant_slug_format"),
            models.CheckConstraint(condition=~models.Q(display_name=""), name="tenant_display_name_nonempty"),
            models.CheckConstraint(condition=models.Q(status__in=TENANT_STATUSES), name="tenant_status_valid"),
        ]


class TenantMembership(GlobalModel):
    """멤버십 정본(data-model §2) — `(sub, tenant_id)` 유일 · SP-1은 사용자당 테넌트 1(claim tenant_id 단일값)."""

    id = models.UUIDField(primary_key=True, db_default=UUID7(), editable=False)
    tenant_id = models.UUIDField()
    sub = models.TextField()
    role = models.CharField(max_length=16, choices=_choices(MEMBERSHIP_ROLES))
    created_at = models.DateTimeField(db_default=Now())

    class Meta(GlobalModel.Meta):
        db_table = "tenant_membership"
        constraints = [
            models.UniqueConstraint(fields=["sub", "tenant_id"], name="tenant_membership_sub_tenant_uniq"),
            models.CheckConstraint(condition=models.Q(role__in=MEMBERSHIP_ROLES), name="tenant_membership_role_valid"),
        ]


class SessionRevocationLog(GlobalModel):
    """폐기의 DB 정본(data-model §3) — `sid` NULL = 사용자 단위 폐기 · 값 = 세션 단위 폐기(한 행 = 한 키). `nbf` ·
    `expires_at`(= nbf + 330 s)은 거부 목록 · 세션 하한의 원천이고, `event_pk`는 Authentik 이벤트 pk(멱등 키 · 웹훅 · 대조 행만)다."""

    id = models.UUIDField(primary_key=True, db_default=UUID7(), editable=False)
    tenant_id = models.UUIDField()
    sub = models.TextField()
    sid = models.TextField(null=True)
    reason = models.CharField(max_length=32, choices=_choices(REVOCATION_REASONS))
    nbf = models.DateTimeField()
    expires_at = models.DateTimeField()
    event_pk = models.TextField(null=True)
    created_at = models.DateTimeField(db_default=Now())

    class Meta(GlobalModel.Meta):
        db_table = "session_revocation_log"
        constraints = [
            models.UniqueConstraint(fields=["event_pk"], name="srl_event_pk_uniq"),
            models.CheckConstraint(condition=models.Q(reason__in=REVOCATION_REASONS), name="srl_reason_valid"),
        ]
        indexes = [
            models.Index(fields=["expires_at"], name="srl_expires_at_idx"),
            models.Index(fields=["sub", "-nbf"], name="srl_user_floor_idx", condition=models.Q(sid__isnull=True)),
        ]
