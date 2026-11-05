"""OutboxEvent 모델(T069 · D2) — 각 pod DB의 `outbox` 테이블(B 등급 · data-model §4 · 계약 events.md §outbox 릴레이).

- B 등급(GlobalModel · 허용 목록 `outbox` · RLS 없음): 릴레이(app role · 컨텍스트 없음)가 모든 테넌트의 행을 읽는다.
- 필드: id = ULID 26자 PK(= 봉투 id · publish가 정한다 — 기본값은 직접 만든 행용) · topic = 논리 토픽(env 접두 없음 · 접두를 붙여
  249자 이하 — Kafka 토픽 이름 상한) · partition_key = 봉투 tenantid(소문자 UUID 36자 · Kafka key) · payload = CloudEvents 1.0
  봉투 전체(jsonb) · created_at = DB 시계(`db_default=Now()` = STATEMENT_TIMESTAMP() — 지표 나이 · purge와 같은 시계 · INSERT
  RETURNING으로 인스턴스에 채워진다) · attempts(0 이상 — PositiveIntegerField의 CHECK) · last_error(앞 1000자 · 릴레이) ·
  dead_at(DLQ 발행 시각 · NULL = pending).
- 인덱스(이름 30자 이하 — models.E034): outbox_pending_idx = (id) WHERE dead_at IS NULL(릴레이 `ORDER BY id LIMIT` · 지표) ·
  outbox_dead_at_idx = (dead_at) WHERE dead_at IS NOT NULL(purge).
- 마이그레이션은 django_common 앱의 0001(CreateModel 하나 · RLS 연산 · RunSQL · GRANT 없음 — 권한은 owner의 기본 권한).

앱 로딩 때 등록되도록 django_common/models.py가 이 클래스를 import한다(Django는 `<앱>.models`만 import한다). 기본 repr은
id만 싣는다(payload는 개인 정보 후보 — 로그에 싣지 않는다).
"""

from __future__ import annotations

from django.db import models
from django.db.models.functions import Now

from django_common.outbox._ulid import new_ulid
from django_common.tenancy import GlobalModel

__all__ = ["OutboxEvent"]


class OutboxEvent(GlobalModel):
    """outbox 행 하나 = 아직 Kafka로 나가지 않았거나(pending) DLQ로 간(dead) 이벤트 하나 — 규칙은 모듈 독스트링."""

    id = models.CharField(primary_key=True, max_length=26, default=new_ulid, editable=False)
    topic = models.CharField(max_length=249)
    partition_key = models.CharField(max_length=36)
    payload = models.JSONField()
    created_at = models.DateTimeField(db_default=Now())
    attempts = models.PositiveIntegerField(default=0)
    last_error = models.TextField(null=True, blank=True)
    dead_at = models.DateTimeField(null=True, blank=True)

    class Meta(GlobalModel.Meta):
        app_label = "django_common"
        db_table = "outbox"
        indexes = [
            models.Index(fields=["id"], name="outbox_pending_idx", condition=models.Q(dead_at__isnull=True)),
            models.Index(fields=["dead_at"], name="outbox_dead_at_idx", condition=models.Q(dead_at__isnull=False)),
        ]
