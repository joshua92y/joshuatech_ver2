"""outbox 지표(T069 · D5 · 계약 events.md §outbox 릴레이 「관측」 · pod-template 「메트릭」 행) — 릴레이 경로에서만 import한다.

prometheus_client 기본 REGISTRY에 모듈 수준에서 한 번 등록한다(레이블 없음 · 0도 늘 노출 — 이름은 알림 · 대시보드 · T096이
쓴다 · 다시 등록하면 DuplicateTimeseries):
- outbox_pending(Gauge): dead_at IS NULL 행 수.
- outbox_oldest_pending_seconds(Gauge): 가장 오래된 pending의 나이(DB 시계 — refresh 때의 DB now() − min(created_at)). 스크레이프
  시점에 자란다: refresh는 기준점 anchor = monotonic() − 나이만 두고, 값은 set_function이 스크레이프 때 monotonic() − anchor로
  계산한다 — 루프가 멈출 때 pending 행이 있었다면 그 나이가 계속 커져 알림 OutboxOldestPending(> 60 s)이 울린다(relay liveness
  TCP 9464는 데몬 스레드라 루프 정지를 못 본다). 멈출 때 비어 있었다면 그 뒤 쌓인 행의 나이는 보이지 않는다(조건 없는 정지
  감지 = 하트비트 지표는 T096 결정 · 계약 「T069 r2 정정」). pending이 없으면 0.
- outbox_dead_total(Counter): 릴레이가 dead로 만든 행 수(relay_once가 커밋 뒤 올린다 · 표본 _total과 _created — 프로세스 전역
  env는 건드리지 않는다).

refresh_metrics()는 default 별칭(app role)에서 한 문장으로 count와 max(Now() − created_at)를 dead_at IS NULL에서 구한다(트랜잭션
밖에서 불러도 된다). 지연 import: django_common.outbox(publish 경로)를 import해도 이 모듈은 import되지 않는다 — web 프로세스
레지스트리에 0값 outbox 지표가 생기면 relay 부재 감시(MetricsAbsent)를 가린다. relay env에는 PROMETHEUS_MULTIPROC_DIR를 두지
않는다(값 저장이 mmap 파일로 바뀌고, 없는 디렉터리를 가리키면 이 모듈 import — 지표 등록 — 가 FileNotFoundError로 실패해 relay가
루프 전에 끝난다 → CrashLoop · web과 envFrom을 공유할 때 주의 · 계약 「T069 r3」).
"""

from __future__ import annotations

import time

from django.db import DEFAULT_DB_ALIAS
from django.db.models import Count, F, Max
from django.db.models.functions import Now
from prometheus_client import Counter, Gauge

from django_common.outbox.models import OutboxEvent

__all__ = ["OUTBOX_DEAD_TOTAL", "OUTBOX_OLDEST_PENDING_SECONDS", "OUTBOX_PENDING", "refresh_metrics"]

OUTBOX_PENDING = Gauge("outbox_pending", "outbox 대기 행 수(dead_at IS NULL)")
OUTBOX_OLDEST_PENDING_SECONDS = Gauge(
    "outbox_oldest_pending_seconds", "가장 오래된 outbox 대기 행의 나이(초 · DB 시계 · 스크레이프 시점까지 자란다)"
)
OUTBOX_DEAD_TOTAL = Counter("outbox_dead_total", "릴레이가 DLQ로 보내고 dead로 만든 outbox 행 수")

_anchor: float | None = None  # monotonic() − 나이(refresh 때) · pending이 없으면 None


def _oldest_pending_seconds() -> float:
    anchor = _anchor
    return 0.0 if anchor is None else time.monotonic() - anchor


OUTBOX_OLDEST_PENDING_SECONDS.set_function(_oldest_pending_seconds)


def refresh_metrics() -> None:
    """pending 수와 가장 오래된 pending의 나이를 DB에서 다시 읽는다(한 문장 · DB 시계)."""
    global _anchor
    stats = (
        OutboxEvent.objects.using(DEFAULT_DB_ALIAS)
        .filter(dead_at__isnull=True)
        .aggregate(pending=Count("pk"), age=Max(Now() - F("created_at")))
    )
    OUTBOX_PENDING.set(stats["pending"])
    age = stats["age"]
    _anchor = None if age is None else time.monotonic() - age.total_seconds()
