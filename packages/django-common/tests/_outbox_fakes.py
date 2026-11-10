"""T069 시험 공용 도우미 — tests/test_outbox_contract.py · tests/test_event_patterns.py만 쓴다(T061 test_outbox.py는 자기 것).

- 상수: 시험 토픽 · 테넌트 · 표본 data(T061과 같은 값 — 설정 OUTBOX_SOURCE "identity-admin" · OUTBOX_TOPIC_PREFIX "dev.").
- `seed(count, tenant)`: 컨텍스트 없는 경로(tenant_id 인자)로 count행을 한 트랜잭션에 쓴다.
- `owner_execute` · `owner_rows`: owner 연결(autocommit)로 시각 조작 · 검증 읽기.
- `ScriptedProducer`: confluent-kafka Producer 대역(produce · flush · poll · purge). T061 FakeProducer보다 엄격하다 —
  produce는 토픽만 위치 인자로 받고 value · key · headers · on_delivery는 키워드로만 받는다(설계 D4 「키워드만」: 실
  Producer의 다섯째 위치 인자는 callback이라 위치 호출은 대역과 실물에서 뜻이 갈린다). 메시지마다의 결과는 `decide(sent)`가
  정한다: None = 성공 DR · `Fail(사유)` = 실패 DR(`code` · `fatal` = 치명 오류 표시 — T069 r2 J5) · 예외 인스턴스 = produce가
  곧바로 던진다 · `HOLD` = DR 없이 큐에 남는다(flush가 남은 수를 돌려주고, purge 뒤의 flush가 `_PURGE_QUEUE` DR을 준다 —
  `purge_reports=False`면 purge 뒤에도 DR이 없다). 실 librdkafka처럼 DR은 produce가 아니라 flush · poll 안에서 준다(T061
  대역은 produce 안에서 준다 — 릴레이는 둘 다 견뎌야 한다). `on_flush` · `on_poll`은 flush · poll이 DR을 준 뒤 같은 스레드에서
  부르는 훅이다(T069 r4 L9). 시험은 이 훅에서 build_producer가 단 error_cb를 비치명 오류 이벤트로 부르거나, 실물 꼴의 치명 예외를
  올린다 — confluent-kafka 2.16.1은 치명 오류를 error_cb로 넘기지 않고 flush · poll에서 KafkaException(fatal)으로 올리며, 같은
  호출에서 DR 콜백이 뒤따르면 그 예외를 원인으로 한 SystemError가 된다(실측). 훅이 올린 예외는 그 flush · poll 밖으로 나간다(큐에
  남은 메시지는 그대로 — purge가 비운다). `raising(…)`은 부를 때마다 차례로 예외를 올리는 훅을 만든다. 호출은 잠금 아래 기록한다.

Django를 쓰는 함수는 호출 시점에 import한다(모듈 import는 시험 모듈과 같은 시점 — pytest-django가 django.setup() 뒤에 수집).
"""

from __future__ import annotations

import json
import threading
import uuid
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Final

from confluent_kafka import KafkaError, Message
from django.db import connections, transaction

from tests._kafka import decode_headers

if TYPE_CHECKING:
    from django_common.outbox import OutboxEvent

TENANT_A = uuid.UUID("00000000-0000-4000-8000-00000000000a")
TENANT_B = uuid.UUID("00000000-0000-4000-8000-00000000000b")
TOPIC = "identity-admin.session.revoked"  # 논리 토픽 = 봉투 type = 행 topic
SOURCE = "identity-admin"  # settings.OUTBOX_SOURCE
KAFKA_TOPIC = "dev.identity-admin.session.revoked"  # settings.OUTBOX_TOPIC_PREFIX + 논리 토픽
DLQ_TOPIC = "dev.identity-admin.dlq"  # 접두 + source + ".dlq"
SUBJECT = "user:9f2c-test"
DATA: Final[dict[str, Any]] = {"sub": "9f2c-test", "sid": None, "nbf": 1756696867, "reason": "logout_all"}
MAX_ATTEMPTS = 10  # settings.OUTBOX_MAX_ATTEMPTS
CONTENT_TYPE = "application/cloudevents+json"
MAIN_HEADERS = ("ce_type", "ce_source", "ce_id", "content-type")  # 설계 D4 순서
DLQ_HEADERS = (*MAIN_HEADERS, "error")


def seed(count: int, tenant: uuid.UUID = TENANT_A, *, subject: str = SUBJECT) -> list[OutboxEvent]:
    """컨텍스트 없는 경로(tenant_id 인자)로 count행을 한 트랜잭션에 쓴다(publish = 시험 대상 구현)."""
    from django_common.outbox import publish

    with transaction.atomic():
        return [publish(TOPIC, subject, dict(DATA), tenant_id=tenant) for _ in range(count)]


def owner_execute(statement: str, params: Sequence[object] = ()) -> None:
    """owner 연결에서 문을 실행한다(autocommit — 곧바로 커밋되어 default 연결에서 보인다)."""
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement, list(params))


def owner_scalar(statement: str, params: Sequence[object] = ()) -> Any:
    """owner 연결에서 값 하나를 읽는다."""
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement, list(params))
        (value,) = cursor.fetchone()
    return value


def owner_rows() -> dict[str, OutboxEvent]:
    """owner로 읽은 outbox 행 id → 행."""
    from django_common.outbox import OutboxEvent

    return {row.pk: row for row in OutboxEvent.objects.using("owner").all()}


@dataclass(frozen=True)
class Fail:
    """실패 DR — KafkaError(code, reason, fatal=fatal)."""

    reason: str
    code: int = KafkaError._MSG_TIMED_OUT
    fatal: bool = False


HOLD: Final = object()  # DR 없이 큐에 남는다(flush가 남은 수에 센다)

type Outcome = Fail | BaseException | object | None
type DeliveryCallback = Callable[[KafkaError | None, Message], None]


@dataclass(frozen=True)
class Sent:
    """produce 한 번(곧바로 예외를 던진 호출도 기록한다 — raised)."""

    topic: str
    key: object
    value: object
    headers: object
    raised: bool = False

    def header_names(self) -> list[str]:
        assert isinstance(self.headers, list), f"헤더가 (이름, bytes) 목록이 아니다: {type(self.headers).__name__}"
        return [name for name, _ in self.headers]

    def header_map(self) -> dict[str, str | None]:
        """이름별 UTF-8 문자열(같은 이름이 두 번이면 실패 — tests/_kafka.decode_headers)."""
        assert isinstance(self.headers, list)
        for name, value in self.headers:
            assert isinstance(name, str) and isinstance(value, bytes), f"헤더 {name!r} 값이 bytes가 아니다"
        return decode_headers(self.headers)

    def envelope(self) -> dict[str, Any]:
        assert isinstance(self.value, bytes), f"{self.topic}: value가 bytes가 아니다"
        return json.loads(self.value)

    def row_id(self) -> str | None:
        return self.header_map().get("ce_id")


@dataclass
class ScriptedProducer:
    """confluent-kafka Producer 대역 — 결과는 decide(sent)가 정한다(모듈 독스트링)."""

    decide: Callable[[Sent], Outcome] = lambda _sent: None
    on_produce: Callable[[Sent], None] | None = None
    on_flush: Callable[[], None] | None = None
    on_poll: Callable[[], None] | None = None
    purge_reports: bool = True
    calls: list[Sent] = field(default_factory=list)
    flush_calls: list[float] = field(default_factory=list)
    poll_calls: list[float] = field(default_factory=list)
    purge_calls: list[tuple[bool, bool]] = field(default_factory=list)
    _lock: threading.Lock = field(default_factory=threading.Lock)
    _ready: list[tuple[DeliveryCallback, KafkaError | None, Message]] = field(default_factory=list)
    _held: list[tuple[DeliveryCallback, Message]] = field(default_factory=list)

    def produce(
        self,
        topic: str,
        *,
        value: object = None,
        key: object = None,
        headers: object = None,
        on_delivery: DeliveryCallback | None = None,
    ) -> None:
        if on_delivery is None:
            raise TypeError("ScriptedProducer.produce: on_delivery 키워드가 없다 — 릴레이는 행마다 결과를 받아야 한다")
        sent = Sent(topic=topic, key=key, value=value, headers=headers)
        if self.on_produce is not None:
            self.on_produce(sent)
        outcome = self.decide(sent)
        if isinstance(outcome, BaseException):
            with self._lock:
                self.calls.append(Sent(topic=topic, key=key, value=value, headers=headers, raised=True))
            raise outcome
        with self._lock:
            self.calls.append(sent)
        message_headers = list(headers) if isinstance(headers, list) else None
        if outcome is HOLD:
            message = Message(topic=topic, key=key, value=value, headers=message_headers)
            with self._lock:
                self._held.append((on_delivery, message))
            return
        error = KafkaError(outcome.code, outcome.reason, fatal=outcome.fatal) if isinstance(outcome, Fail) else None
        message = Message(topic=topic, key=key, value=value, headers=message_headers, error=error)
        with self._lock:
            self._ready.append((on_delivery, error, message))

    def _serve(self) -> int:
        """준비된 DR을 이 호출 스레드에서 부른다(실 librdkafka처럼 flush · poll 안)."""
        with self._lock:
            ready, self._ready = self._ready, []
        for callback, error, message in ready:
            callback(error, message)
        return len(ready)

    def flush(self, timeout: float = -1) -> int:
        with self._lock:
            self.flush_calls.append(timeout)
        self._serve()
        if self.on_flush is not None:
            self.on_flush()
        with self._lock:
            return len(self._held)

    def poll(self, timeout: float = 0) -> int:
        with self._lock:
            self.poll_calls.append(timeout)
        served = self._serve()
        if self.on_poll is not None:
            self.on_poll()
        return served

    def purge(self, in_queue: bool = True, in_flight: bool = True, blocking: bool = True) -> None:
        with self._lock:
            self.purge_calls.append((in_queue, in_flight))
            held, self._held = self._held, []
            if self.purge_reports:
                for callback, message in held:
                    error = KafkaError(KafkaError._PURGE_QUEUE)
                    self._ready.append((callback, error, message))

    @property
    def sent(self) -> list[Sent]:
        """곧바로 예외를 던지지 않은 produce 호출."""
        with self._lock:
            return [call for call in self.calls if not call.raised]


def fail_topics(*topics: str, reason: str = "injected delivery failure") -> Callable[[Sent], Outcome]:
    """주어진 토픽은 실패 DR, 나머지는 성공."""
    return lambda sent: Fail(reason) if sent.topic in topics else None


def raising(*errors: BaseException | None) -> Callable[[], None]:
    """on_flush · on_poll 훅: n번째 호출에 errors[n]을 올린다(None이면 그냥 돌아간다 · 다 쓴 뒤에는 늘 그냥 돌아간다)."""
    pending = list(errors)

    def hook() -> None:
        if pending:
            error = pending.pop(0)
            if error is not None:
                raise error

    return hook
