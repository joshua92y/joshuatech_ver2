"""dead 행 purge · 재처리(T069 · D8 · r3 K7 · 계약 events.md §outbox 릴레이 「구현 규칙」 purge · 재처리).

- purge_dead(*, older_than=timedelta(days=30)) -> int: dead_at < DB now() − older_than인 행을 지우고 삭제 수를 돌려준다(DB 시계 —
  Now() = STATEMENT_TIMESTAMP() · default 별칭 = app role · dead_at NULL(pending)은 대상 밖). older_than이 0 이하면 ValueError.
  신호 없는 직접 DELETE 한 문장이다(K7 — QuerySet._raw_delete: Django Collector를 거치지 않아 지울 행을 먼저 읽지 않고
  pre_delete · post_delete를 보내지 않는다. Collector는 sender 없는 삭제 수신기가 pod에 하나라도 있으면 30일 넘은 dead 행 전부를
  payload째 메모리로 올려 json.loads한다 — 리뷰 r2 B2-3). Celery가 없는 라이브러리 함수다 — 템플릿 Celery 작업
  `<pod_snake>.tasks.purge_dead_outbox`가 일 1회 감싸고, Celery가 없는 pod(has_celery=false)는 명령 outbox_purge를 CronJob으로
  부른다(T072 · r2 J10). outbox가 무한히 자라지 않게 하는 유일한 경로이고, 30일은 수동 재처리 여유다.
- requeue_dead(ids=None) -> int: dead 행(dead_at IS NOT NULL — ids가 있으면 그 안만)의 dead_at · attempts · last_error를 비운다
  (pending 행은 건드리지 않는다). attempts를 남기면 다음 패스가 곧바로 DLQ로 다시 보내 DLQ에 중복이 생긴다. 명령
  outbox_requeue(`--id <ULID>`… | `--all`)가 감싼다 — 메인만 실패한 부분 장애로 dead가 된 행을 복구 뒤 되돌린다.
"""

from __future__ import annotations

from collections.abc import Collection
from datetime import timedelta

from django.db import DEFAULT_DB_ALIAS
from django.db.models.functions import Now

from django_common.outbox.models import OutboxEvent

__all__ = ["purge_dead", "requeue_dead"]

_RETENTION = timedelta(days=30)


def purge_dead(*, older_than: timedelta = _RETENTION) -> int:
    """dead_at이 DB now() − older_than보다 이른 행을 신호 없는 DELETE 한 문장으로 지운다(삭제 수)."""
    if older_than <= timedelta(0):
        raise ValueError("purge_dead: older_than은 0보다 커야 한다")
    rows = OutboxEvent.objects.using(DEFAULT_DB_ALIAS).filter(dead_at__lt=Now() - older_than)
    deleted: int = rows._raw_delete(DEFAULT_DB_ALIAS)
    return deleted


def requeue_dead(ids: Collection[str] | None = None) -> int:
    """dead 행을 pending으로 되돌린다(dead_at · attempts · last_error 비움 · 되돌린 수) — ids가 None이면 dead 행 전부."""
    if isinstance(ids, str):
        raise TypeError("requeue_dead: ids는 행 id의 모음이다(str 하나가 아니다)")
    rows = OutboxEvent.objects.using(DEFAULT_DB_ALIAS).filter(dead_at__isnull=False)
    if ids is not None:
        rows = rows.filter(pk__in=list(ids))
    return rows.update(dead_at=None, attempts=0, last_error=None)
