"""django_common.outbox — 트랜잭셔널 outbox(T069 · 계약 events.md §발행 API · §outbox 릴레이 · data-model §4).

설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T069」(사실 ①–⑫ · C1–C5 · D1–D16). 공개 이름(계약 pod-template
§django-common 공개 API):
- OutboxEvent(models — B 등급 테이블 outbox) · OutboxUsageError · publish(publisher — 요청 트랜잭션 안 INSERT · 네트워크 0).
- RelayResult · relay_once(relay — 한 패스 · 명령 outbox_relay가 루프로 부른다). 하위 모듈 relay는 ProducerFatalError(.result ·
  .error_name — 치명 오류가 난 패스를 반영 · 커밋한 뒤 relay_once가 올린다)와 build_producer를 담고, 이 패키지 최상위에는
  재노출하지 않는다(`from django_common.outbox.relay import …` · T069 r4).
- purge_dead · requeue_dead(maintenance — 템플릿 Celery 작업 · 명령 outbox_purge · outbox_requeue가 감싼다).
하위 모듈 metrics(refresh_metrics · 지표 3종)는 재노출하지 않는다 — 릴레이 경로(relay_once · 명령)만 함수 안에서 import한다
(web 프로세스 레지스트리에 0값 outbox 지표가 생기지 않게). confluent_kafka도 relay 함수 안에서만 import한다.

이 패키지는 모델 모듈을 담으므로 앱 레지스트리가 준비된 뒤(django.setup())에 import한다 — django_common/__init__.py에서
import하지 않는다(AppRegistryNotReady). 모델 등록은 django_common/models.py가 맡는다.
"""

from django_common.outbox.maintenance import purge_dead, requeue_dead
from django_common.outbox.models import OutboxEvent
from django_common.outbox.publisher import OutboxUsageError, publish
from django_common.outbox.relay import RelayResult, relay_once

__all__ = [
    "OutboxEvent",
    "OutboxUsageError",
    "RelayResult",
    "publish",
    "purge_dead",
    "relay_once",
    "requeue_dead",
]
