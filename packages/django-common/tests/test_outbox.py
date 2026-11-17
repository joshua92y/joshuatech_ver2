"""django_common.outbox 계약 테스트(T061 · test-first — 짝 구현 T069가 초록으로 만든다 · 스키마는 T067).

계약: contracts/events.md §발행 API · §outbox 릴레이 · §봉투, data-model §4(OutboxEvent), rules/django-pod.md
§Outbox and events, rules/events.md §Envelope · §Topic conventions.
- publish(topic, subject, data, *, tenant_id=None) -> OutboxEvent: transaction.atomic() 밖 → OutboxUsageError ·
  테넌트 컨텍스트도 tenant_id 인자도 없음 → OutboxUsageError · UUID로 파싱되지 않는 tenant_id(slug) → OutboxUsageError ·
  컨텍스트와 인자가 둘 다 있고 다르면 OutboxUsageError(같으면 허용) · 확정 tenant_id = 봉투 tenantid = 행 partition_key.
- 릴레이(app role · 컨텍스트 없음 · outbox는 B 등급): dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 배치
  → CloudEvents structured 봉투(value) + 헤더 ce_type · ce_source · ce_id · content-type, key = tenantid → 성공 행
  삭제 · 실패 attempts += 1 · last_error · attempts ≥ 10 → DLQ(원본 봉투 + error 헤더) + dead_at(행 유지 · 다시 집지
  않음).
- 지표: outbox_pending(dead_at IS NULL만) · outbox_oldest_pending_seconds · outbox_dead_total.

T069 가정(계약에 없는 이름 — 설계 D3 · D4 · D5 · T069가 확정한다 · 바꾸면 이 파일과 tests/settings.py를 함께):
- 설정: OUTBOX_SOURCE(봉투 source) · OUTBOX_TOPIC_PREFIX("dev." — Kafka 토픽 = 접두 + 논리 토픽 · DLQ = 접두 +
  source + ".dlq") · OUTBOX_MAX_ATTEMPTS · KAFKA_BOOTSTRAP_SERVERS · KAFKA_CLIENT_CONFIG. 봉투 type과 행 topic은
  접두 없는 논리 토픽이다.
- relay_once(*, producer=None, batch_size=100) -> RelayResult(published · failed · dead): 한 배치만 · 시간 백오프
  게이트 없음(백오프는 outbox_relay 명령 루프) · producer=None이면 설정으로 confluent-kafka Producer를 만든다.
- 프로듀서: confluent-kafka Producer 모양(produce · flush · poll). 릴레이는 행마다 delivery 콜백(err, msg)으로 결과를
  받고 실패면 str(err)를 last_error에 둔다 — FakeProducer가 이 모양을 흉내 낸다.
- django_common.outbox.metrics: prometheus_client 기본 REGISTRY에 지표 3종(레이블 없음) · refresh_metrics() -> None.

빨간 상태: 지금은 django.setup()이 testapp 모델의 django_common.tenancy(T068)를 못 찾아 수집 전에 멈춘다. T068
뒤에는 이 모듈의 django_common.outbox import가 ModuleNotFoundError다 — 둘 다 "구현 없음"이 원인이다.

DB 별칭: default = app role(NOBYPASSRLS · 런타임 — publish와 릴레이가 쓴다) · owner = owner role(BYPASSRLS · 검증
읽기 · 시각 조작 UPDATE). 다른 연결은 커밋된 행만 본다.
"""

from __future__ import annotations

import inspect
import json
import re
import threading
import uuid
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from confluent_kafka import KafkaError, Message
from django.db import connections, models, transaction
from django.test.utils import CaptureQueriesContext
from jsonschema import Draft202012Validator
from prometheus_client import REGISTRY

from django_common.outbox import OutboxEvent, OutboxUsageError, RelayResult, publish, relay_once
from django_common.outbox.metrics import refresh_metrics
from django_common.tenancy import GlobalModel
from tests._kafka import decode_headers, drain, headers_dict, subscribed
from tests._tenant import set_tenant

pytestmark = pytest.mark.django_db(transaction=True, databases=["default", "owner"])

TENANT_A = uuid.UUID("00000000-0000-4000-8000-00000000000a")
TENANT_B = uuid.UUID("00000000-0000-4000-8000-00000000000b")

# 시험 토픽 = 실제 SP-1 토픽(D2 · 계약 §SP-1 스키마 표): subject user:<sub> · data sub(req) · sid(string|null) ·
# nbf(int epoch, req) · reason(enum, req).
TOPIC = "identity-admin.session.revoked"  # 논리 토픽 = 봉투 type = 행 topic
SOURCE = "identity-admin"  # settings.OUTBOX_SOURCE
KAFKA_TOPIC = "dev.identity-admin.session.revoked"  # settings.OUTBOX_TOPIC_PREFIX + 논리 토픽
DLQ_TOPIC = "dev.identity-admin.dlq"  # 접두 + source + ".dlq"(계약 §토픽 규약 dev DLQ)
SUBJECT = "user:9f2c-test"
DATA: dict[str, Any] = {"sub": "9f2c-test", "sid": None, "nbf": 1756696867, "reason": "logout_all"}
# out-6의 B 행 — 웹훅 경로 모양(sid 문자열 · reason authentik_webhook)으로 스키마의 string|null과 enum을 함께 본다.
SUBJECT_WEBHOOK = "user:4b1d-test"
DATA_WEBHOOK: dict[str, Any] = {
    "sub": "4b1d-test",
    "sid": "sid-4b1d",
    "nbf": 1756696868,
    "reason": "authentik_webhook",
}
MAX_ATTEMPTS = 10  # settings.OUTBOX_MAX_ATTEMPTS(계약 max_attempts 10)
CONTENT_TYPE = "application/cloudevents+json"
ULID_RE = re.compile(r"^[0-7][0-9A-HJKMNP-TV-Z]{25}$")  # Crockford base32 26자(48비트 시각이 앞)
TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$")  # RFC 3339 · 'T' 구분 · UTC 'Z'(D3)
SCHEMAS_DIR = Path(__file__).resolve().parents[3] / "packages" / "events" / "schemas"
INJECTED_ERROR = "injected delivery failure"
RECEIVE_TIMEOUT_S = 30
THREAD_TIMEOUT_S = 60
LOCK_WAIT_S = 10

type DeliveryCallback = Callable[[KafkaError | None, Message], None]
type HeaderInput = Sequence[tuple[str, str | bytes | None]] | Mapping[str, str | bytes | None] | None


def _as_bytes(value: str | bytes | None) -> bytes | None:
    return value.encode("utf-8") if isinstance(value, str) else value


@dataclass(frozen=True)
class ProducedCall:
    """FakeProducer가 받은 produce 한 번. key · value · 헤더 값은 bytes로 맞춘다(실 Producer도 str을 UTF-8로 보낸다)."""

    topic: str
    key: bytes | None
    value: bytes | None
    headers: tuple[tuple[str, bytes | None], ...]

    def header_map(self) -> dict[str, str | None]:
        return decode_headers(self.headers)

    def envelope(self) -> dict[str, Any]:
        assert self.value is not None, f"{self.topic}: value 없음"
        return json.loads(self.value)


class FakeProducer:
    """confluent-kafka Producer 대역(produce · flush · poll) — 브로커 없이 릴레이의 실패 · DLQ · 동시성 경로를 본다.

    produce 인자 순서는 실 Producer와 같다(topic, value, key, partition, on_delivery, timestamp, headers · callback은
    on_delivery의 별칭). delivery 콜백은 produce 안에서 동기로 부른다 — 실 Producer는 poll/flush 안에서 부르므로
    릴레이는 둘 다 견뎌야 한다. 콜백 인자는 실 librdkafka처럼 (err, msg)다: err는 confluent_kafka.KafkaError(성공이면
    None) · msg는 보낸 메시지를 담은 confluent_kafka.Message(라이브러리의 시험용 생성자 · 실패면 msg.error() == err).
    fail_topics의 토픽은 실패, 나머지는 성공한다. 호출은 스레드 안전하게 기록한다(out-11은 두 스레드가 같이 쓴다).
    """

    def __init__(self, *, fail_topics: frozenset[str] = frozenset()) -> None:
        self.fail_topics = fail_topics
        self._lock = threading.Lock()
        self._calls: list[ProducedCall] = []

    def produce(
        self,
        topic: str,
        value: str | bytes | None = None,
        key: str | bytes | None = None,
        partition: int = -1,
        on_delivery: DeliveryCallback | None = None,
        timestamp: int = 0,
        headers: HeaderInput = None,
        *,
        callback: DeliveryCallback | None = None,
    ) -> None:
        deliver = on_delivery or callback
        if deliver is None:
            raise TypeError("FakeProducer.produce: delivery 콜백이 없다 — 릴레이는 행마다 결과를 받아야 한다")
        pairs = headers.items() if isinstance(headers, Mapping) else (headers or ())
        call = ProducedCall(
            topic=topic,
            key=_as_bytes(key),
            value=_as_bytes(value),
            headers=tuple((name, _as_bytes(item)) for name, item in pairs),
        )
        with self._lock:
            self._calls.append(call)
        error = KafkaError(KafkaError._MSG_TIMED_OUT, INJECTED_ERROR) if topic in self.fail_topics else None
        message = Message(
            topic=topic, key=call.key, value=call.value, headers=list(call.headers), error=error
        )
        deliver(error, message)

    def flush(self, timeout: float = -1) -> int:
        return 0  # 콜백을 produce 안에서 이미 불렀다 — 큐에 남은 메시지 0

    def poll(self, timeout: float = 0) -> int:
        return 0

    @property
    def calls(self) -> list[ProducedCall]:
        with self._lock:
            return list(self._calls)


def _seed(count: int, tenant: uuid.UUID = TENANT_A) -> list[OutboxEvent]:
    """컨텍스트 없는 경로(웹훅·관리자 revoke처럼 tenant_id 인자)로 count행을 한 트랜잭션에 쓴다."""
    with transaction.atomic():
        return [publish(TOPIC, SUBJECT, dict(DATA), tenant_id=tenant) for _ in range(count)]


def _owner_execute(statement: str, params: list[object]) -> None:
    """owner 연결에서 문을 실행한다(autocommit — 곧바로 커밋되어 릴레이·지표의 default 연결에서 보인다)."""
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement, params)


def _owner_state() -> dict[str, tuple[int, datetime | None]]:
    """owner로 읽은 행 id → (attempts, dead_at)."""
    return {row.pk: (row.attempts, row.dead_at) for row in OutboxEvent.objects.using("owner").all()}


def _sample(name: str) -> float:
    """prometheus_client 기본 REGISTRY의 레이블 없는 표본 값(D5)."""
    value = REGISTRY.get_sample_value(name)
    assert value is not None, f"지표 {name}(레이블 없음)이 prometheus_client 기본 REGISTRY에 없다"
    return value


def _validator(file_name: str) -> Draft202012Validator:
    """packages/events/schemas/<file_name>의 Draft 2020-12 검증기(format 검사 포함 — tenantid uuid 등)."""
    path = SCHEMAS_DIR / file_name
    if not path.is_file():
        pytest.fail(f"packages/events 스키마 없음 — T067 선행 ({file_name})")
    schema = json.loads(path.read_text(encoding="utf-8"))
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=Draft202012Validator.FORMAT_CHECKER)


def _drive_to_dead() -> tuple[OutboxEvent, FakeProducer, list[RelayResult]]:
    """1행을 메인 토픽 실패 대역으로 MAX_ATTEMPTS번 릴레이해 dead로 만든다(out-8 · out-9 공용)."""
    (event,) = _seed(1)
    fake = FakeProducer(fail_topics=frozenset({KAFKA_TOPIC}))
    results = [relay_once(producer=fake) for _ in range(MAX_ATTEMPTS)]
    return event, fake, results


def test_out_1_publish_outside_atomic_raises() -> None:
    """out-1 — transaction.atomic() 밖(autocommit)에서 부르면 tenant_id를 넘겨도 OutboxUsageError · 행은 남지 않는다.

    tenant_id를 넘겨 out-2(컨텍스트·인자 없음)와 원인을 가른다 — 남는 원인은 autocommit뿐이다.
    """
    assert not connections["default"].in_atomic_block  # transaction=True 테스트 = autocommit
    with pytest.raises(OutboxUsageError):
        publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_A)
    assert OutboxEvent.objects.using("owner").count() == 0


def test_out_2_publish_without_context_and_arg_raises() -> None:
    """out-2 — atomic 안이어도 테넌트 컨텍스트도 tenant_id 인자도 없으면 OutboxUsageError · 행 0.

    tenantid 없는 봉투가 Kafka로 나가지 않게 막는 관문이다. "컨텍스트 없음"의 두 모양을 다 본다: 새 DB 세션
    (current_setting = NULL)과, 같은 세션에서 앞 트랜잭션이 컨텍스트를 두었다 끝난 뒤(GUC가 한 번 설정된 세션은
    NULL이 아니라 ''를 돌려준다 — T060 mw-4). ''를 테넌트로 읽거나 uuid로 캐스트하다 다른 오류를 내면 실패다.
    """
    connections["default"].close()  # 다음 쿼리가 새 세션을 연다 → app.tenant_id 미설정(NULL)
    with pytest.raises(OutboxUsageError), transaction.atomic():
        publish(TOPIC, SUBJECT, dict(DATA))
    with transaction.atomic():
        set_tenant("default", TENANT_A)  # 트랜잭션이 끝나면 지역 설정이 사라지고 같은 세션에 ''가 남는다
    with pytest.raises(OutboxUsageError), transaction.atomic():
        publish(TOPIC, SUBJECT, dict(DATA))
    assert OutboxEvent.objects.using("owner").count() == 0


def test_out_3_publish_with_context() -> None:
    """out-3 — atomic 안 · 테넌트 A 컨텍스트 · 인자 없음 → 호출자 트랜잭션에 행 1(커밋 전에는 다른 연결에 안 보인다).

    행: topic = 논리 토픽 · partition_key = str(A) · attempts 0 · last_error · dead_at 없음. payload = CloudEvents 1.0
    봉투: id = 행 ULID · source · type = 논리 토픽 · subject · tenantid = str(A) · datacontenttype · data 그대로 ·
    time = RFC 3339 UTC `Z`(계약 예시 `2026-09-01T03:21:07.123Z` 꼴 — 리뷰 r1 A-6).
    """
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        event = publish(TOPIC, SUBJECT, dict(DATA))
        assert OutboxEvent.objects.using("owner").count() == 0  # 아직 커밋 전 — 호출자 트랜잭션에 들어갔다
    assert isinstance(event, OutboxEvent)
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.topic == TOPIC
    assert row.partition_key == str(TENANT_A)
    assert row.attempts == 0
    assert row.last_error is None
    assert row.dead_at is None
    envelope = row.payload
    assert envelope["specversion"] == "1.0"
    assert ULID_RE.fullmatch(envelope["id"])
    assert envelope["id"] == row.pk
    assert envelope["source"] == SOURCE
    assert envelope["type"] == TOPIC
    assert envelope["subject"] == SUBJECT
    assert envelope["tenantid"] == str(TENANT_A)
    assert envelope["datacontenttype"] == "application/json"
    assert envelope["data"] == DATA
    assert TIME_RE.fullmatch(envelope["time"]), envelope["time"]
    sent_at = datetime.fromisoformat(envelope["time"])
    assert sent_at.utcoffset() == timedelta(0)


def test_out_4_publish_without_context_with_tenant_arg() -> None:
    """out-4 — 컨텍스트 없이 tenant_id=B(UUID)를 넘기면(웹훅·관리자 revoke 경로) 성공한다.

    그 값이 행 partition_key와 봉투 tenantid가 된다.
    """
    with transaction.atomic():
        event = publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_B)
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.partition_key == str(TENANT_B)
    assert row.payload["tenantid"] == str(TENANT_B)


def test_out_5_tenant_arg_accepts_str() -> None:
    """out-5 — tenant_id를 문자열(str(B))로 넘겨도 out-4와 같다(계약 시그니처 UUID | str)."""
    with transaction.atomic():
        event = publish(TOPIC, SUBJECT, dict(DATA), tenant_id=str(TENANT_B))
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.partition_key == str(TENANT_B)
    assert row.payload["tenantid"] == str(TENANT_B)


def test_out_15_tenant_arg_rejects_non_uuid() -> None:
    """out-15 — tenant_id가 UUID로 파싱되지 않는 문자열(slug 등)이면 OutboxUsageError · 행 0.

    계약 §발행 API(2026-11-02 보강): tenantid는 항상 테넌트 UUID(slug 금지) — 봉투 검증(T067 format uuid)보다 앞선
    관문이다(리뷰 r1 B-1/A-3 · 컨트롤러 결정 K1).
    """
    with pytest.raises(OutboxUsageError), transaction.atomic():
        publish(TOPIC, SUBJECT, dict(DATA), tenant_id="joshuatech")
    assert OutboxEvent.objects.using("owner").count() == 0


def test_out_16_context_and_arg_conflict_raises() -> None:
    """out-16 — 테넌트 컨텍스트 A와 tenant_id 인자가 둘 다 있을 때: 다르면(B) OutboxUsageError · 행 0, 같으면(A) 성공.

    계약 §발행 API(2026-11-02 보강 · 심층 방어): A 등급 도메인 트랜잭션 안에서 다른 테넌트로 레이블된 봉투가 커밋되는
    코드 실수를 라이브러리가 막는다(리뷰 r1 B-2 · 컨트롤러 결정 K2).
    """
    with pytest.raises(OutboxUsageError), transaction.atomic():
        set_tenant("default", TENANT_A)
        publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_B)
    assert OutboxEvent.objects.using("owner").count() == 0
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        event = publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_A)
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.partition_key == str(TENANT_A)


@pytest.mark.usefixtures("kafka_settings")
def test_out_6_relay_delivers_both_tenants_and_passes_schema(kafka: str) -> None:
    """out-6 — 테넌트 A(컨텍스트) 1행 + B(tenant_id 인자) 1행 → relay_once() 1회 → 실 Kafka(KRaft)에서 2건 · 행 삭제.

    릴레이는 app role(default 연결 · owner 연결 쿼리 0)로 테넌트 컨텍스트 없이 돈다. 메시지마다 value = 저장된 봉투
    그대로 · key = 그 행의 tenantid · 헤더 ce_type · ce_source · ce_id · content-type · tenantid는 행마다 제 테넌트의
    UUID. 구독을 먼저 연다(토픽은 릴레이의 첫 produce가 자동 생성 — tests/_kafka.py 실측 메모). 스키마 검증
    (_envelope.json = 봉투 · 토픽 스키마 = data)은 맨 끝에 둔다: T067 전에는 릴레이 단언을 다 본 뒤 실패한다.
    """
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        event_a = publish(TOPIC, SUBJECT, dict(DATA))
    with transaction.atomic():
        event_b = publish(TOPIC, SUBJECT_WEBHOOK, dict(DATA_WEBHOOK), tenant_id=TENANT_B)
    tenant_by_id = {event_a.pk: str(TENANT_A), event_b.pk: str(TENANT_B)}
    stored = {row.pk: row.payload for row in OutboxEvent.objects.using("owner").all()}
    assert set(stored) == set(tenant_by_id)

    with subscribed(kafka, KAFKA_TOPIC) as consumer:
        with (
            CaptureQueriesContext(connections["owner"]) as owner_queries,
            CaptureQueriesContext(connections["default"]) as app_queries,
        ):
            result = relay_once()
        messages = drain(consumer, 2, timeout_s=RECEIVE_TIMEOUT_S)

    assert result == RelayResult(published=2, failed=0, dead=0)
    assert len(owner_queries) == 0  # owner role(BYPASSRLS)은 런타임에 쓰지 않는다
    assert len(app_queries) > 0
    assert len(messages) == 2
    envelopes = []
    for message in messages:
        headers = headers_dict(message)
        row_id = headers.get("ce_id")
        assert row_id in tenant_by_id
        envelope = json.loads(message.value())
        assert envelope == stored[row_id]
        assert envelope["tenantid"] == tenant_by_id[row_id]
        assert message.key() == tenant_by_id[row_id].encode()
        assert headers.get("ce_type") == TOPIC
        assert headers.get("ce_source") == SOURCE
        assert headers.get("content-type") == CONTENT_TYPE
        envelopes.append(envelope)
    assert {envelope["tenantid"] for envelope in envelopes} == {str(TENANT_A), str(TENANT_B)}
    assert OutboxEvent.objects.using("owner").count() == 0

    envelope_schema = _validator("_envelope.json")
    data_schema = _validator(f"{TOPIC}.json")
    for envelope in envelopes:
        envelope_schema.validate(envelope)
        data_schema.validate(envelope["data"])


def test_out_7_producer_failure_keeps_row() -> None:
    """out-7 — 프로듀서 실패(메인 토픽 delivery 오류 주입) → RelayResult(0, 1, 0) · 행 유지 · attempts 1 · last_error에
    오류 문자열 · dead_at 없음. 릴레이는 env 접두를 붙인 Kafka 토픽에 tenantid key로 한 번 보냈다."""
    (event,) = _seed(1)
    fake = FakeProducer(fail_topics=frozenset({KAFKA_TOPIC}))
    assert relay_once(producer=fake) == RelayResult(published=0, failed=1, dead=0)
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.attempts == 1
    assert row.last_error is not None
    assert INJECTED_ERROR in row.last_error
    assert row.dead_at is None
    assert [(call.topic, call.key) for call in fake.calls] == [(KAFKA_TOPIC, str(TENANT_A).encode())]


def test_out_8_dead_letter_after_max_attempts() -> None:
    """out-8 — 메인 토픽이 계속 실패하면 MAX_ATTEMPTS(10)번째 릴레이에서 dead: DLQ dev.identity-admin.dlq로 원본 봉투
    1건(+ error 헤더 = 마지막 오류 · ce_* 헤더) · dead_at 기록(행 유지) · attempts 10 · outbox_dead_total +1.

    시간 백오프 게이트가 없으므로(D4) relay_once를 연달아 부를 때마다 그 행을 다시 시도한다.
    경계 해석: 과제 문면 "10 초과"(11번째)가 아니라 계약 "attempts ≥ max_attempts(10)"(10번째 실패에서 같은 relay_once
    안에 DLQ)을 따른다 — T069 문면 "도달 시"와 같다(리뷰 r1 A-1 · 지시문 §2 "어긋나면 계약을 따른다").
    """
    dead_before = _sample("outbox_dead_total")
    event, fake, results = _drive_to_dead()
    assert results[:-1] == [RelayResult(published=0, failed=1, dead=0)] * (MAX_ATTEMPTS - 1)
    assert results[-1].published == 0
    assert results[-1].dead == 1
    row = OutboxEvent.objects.using("owner").get()
    assert row.pk == event.pk
    assert row.attempts == MAX_ATTEMPTS
    assert row.dead_at is not None
    calls = fake.calls
    assert [call.topic for call in calls] == [KAFKA_TOPIC] * MAX_ATTEMPTS + [DLQ_TOPIC]
    dlq = calls[-1]
    assert dlq.envelope() == row.payload
    headers = dlq.header_map()
    assert INJECTED_ERROR in (headers.get("error") or "")
    assert headers.get("ce_id") == row.pk
    assert headers.get("ce_type") == TOPIC
    assert headers.get("ce_source") == SOURCE
    assert _sample("outbox_dead_total") == dead_before + 1


def test_out_9_dead_rows_not_repicked() -> None:
    """out-9 — dead 행은 다시 집지 않는다(dead_at IS NULL만 선택 · 재발행 폭주 방지).

    out-8과 같은 dead 행(attempts 10) + attempts 0인 채 dead_at만 찍힌 행 → 성공하는 새 대역으로 relay_once() →
    RelayResult(0, 0, 0) · produce 호출 0 · 두 행의 attempts · dead_at 그대로. 둘째 행은 선택 조건이 attempts가
    아니라 dead_at임을 가른다.
    """
    event, _, _ = _drive_to_dead()
    (manual,) = _seed(1, TENANT_B)
    _owner_execute("UPDATE outbox SET dead_at = now() WHERE id = %s", [manual.pk])
    before = _owner_state()
    assert set(before) == {event.pk, manual.pk}
    assert before[event.pk][0] == MAX_ATTEMPTS
    assert all(dead_at is not None for _, dead_at in before.values())
    fresh = FakeProducer()
    assert relay_once(producer=fresh) == RelayResult(published=0, failed=0, dead=0)
    assert fresh.calls == []
    assert _owner_state() == before


def test_out_10_metrics_pending_and_oldest() -> None:
    """out-10 — refresh_metrics(): outbox_pending은 dead_at IS NULL만 센다(pending 2 · dead 1 → 2) ·
    outbox_oldest_pending_seconds는 가장 오래된 pending의 나이(≈ 120 s)다 — 그보다 오래된 dead 행(3600 s)은 빠진다."""
    oldest, _newer, dead = _seed(3)
    _owner_execute(
        "UPDATE outbox SET dead_at = now(), created_at = now() - interval '3600 seconds' WHERE id = %s",
        [dead.pk],
    )
    _owner_execute(
        "UPDATE outbox SET created_at = now() - interval '120 seconds' WHERE id = %s", [oldest.pk]
    )
    refresh_metrics()
    assert _sample("outbox_pending") == 2
    assert 100 <= _sample("outbox_oldest_pending_seconds") < 600


def test_out_11_concurrent_relays_skip_locked() -> None:
    """out-11 — 두 릴레이가 동시에(Barrier) 같은 50행을 집으면 FOR UPDATE SKIP LOCKED로 나눠 갖는다: published 합 50 ·
    발행된 id 50개 · 중복 0 · 행 0. 스레드마다 자기 DB 연결을 쓰고 끝에 닫는다(transactional_db)."""
    seeded = {event.pk for event in _seed(50)}
    fake = FakeProducer()
    barrier = threading.Barrier(2)
    lock = threading.Lock()
    results: list[RelayResult] = []
    errors: list[Exception] = []

    def worker() -> None:
        try:
            barrier.wait(timeout=THREAD_TIMEOUT_S)
            result = relay_once(producer=fake, batch_size=100)
            with lock:
                results.append(result)
        except Exception as exc:  # 스레드 예외를 주 스레드의 단언으로 옮긴다
            with lock:
                errors.append(exc)
        finally:
            connections.close_all()

    threads = [threading.Thread(target=worker, daemon=True) for _ in range(2)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join(timeout=THREAD_TIMEOUT_S)
    assert not any(thread.is_alive() for thread in threads)
    assert errors == []
    assert len(results) == 2
    assert sum(result.published for result in results) == 50
    assert all(result.failed == 0 and result.dead == 0 for result in results)
    published_ids = [call.envelope()["id"] for call in fake.calls]
    assert len(published_ids) == 50
    assert set(published_ids) == seeded
    assert OutboxEvent.objects.using("owner").count() == 0


def test_out_12_outbox_is_grade_b() -> None:
    """out-12 — OutboxEvent는 B 등급(GlobalModel · 테이블 outbox · 허용 목록): app role(default)이 테넌트 컨텍스트
    없이 A·B 두 테넌트의 행을 모두 읽는다(릴레이가 모든 테넌트 행을 집는 전제)."""
    assert issubclass(OutboxEvent, GlobalModel)
    assert OutboxEvent._meta.db_table == "outbox"
    _seed(1, TENANT_A)
    _seed(1, TENANT_B)
    assert OutboxEvent.objects.count() == 2
    assert set(OutboxEvent.objects.values_list("partition_key", flat=True)) == {
        str(TENANT_A),
        str(TENANT_B),
    }


def test_out_13_model_shape() -> None:
    """out-13 — 필드 모양(data-model §4): id ULID(CharField 26 · PK) · topic · partition_key(문자열) · payload(JSON) ·
    created_at(DateTime) · attempts(정수 · 기본 0) · last_error(문자열 · null) · dead_at(DateTime · null)."""
    meta = OutboxEvent._meta
    id_field = meta.get_field("id")
    assert isinstance(id_field, models.CharField)
    assert id_field.max_length == 26
    assert id_field.primary_key is True
    for name in ("topic", "partition_key"):
        assert isinstance(meta.get_field(name), (models.CharField, models.TextField))
    assert isinstance(meta.get_field("payload"), models.JSONField)
    assert isinstance(meta.get_field("created_at"), models.DateTimeField)
    attempts = meta.get_field("attempts")
    assert isinstance(attempts, models.IntegerField)
    assert attempts.default == 0
    last_error = meta.get_field("last_error")
    assert isinstance(last_error, (models.CharField, models.TextField))
    assert last_error.null is True
    dead_at = meta.get_field("dead_at")
    assert isinstance(dead_at, models.DateTimeField)
    assert dead_at.null is True
    # 계약 §발행 API: tenant_id는 키워드 전용 선택 인자(기본 None) — 위치 인자로 넘기면 TypeError(리뷰 r1 A-2).
    param = inspect.signature(publish).parameters["tenant_id"]
    assert param.kind is inspect.Parameter.KEYWORD_ONLY
    assert param.default is None
    with pytest.raises(TypeError):
        publish(TOPIC, SUBJECT, dict(DATA), TENANT_A)  # type: ignore[misc]


def test_out_14_relay_skips_rows_locked_by_another_transaction() -> None:
    """out-14 — 다른 트랜잭션(다른 릴레이)이 FOR UPDATE로 쥔 행은 기다리지 않고 건너뛴다(SKIP LOCKED).

    out-11은 잠금이 아예 없으면(중복 발행) 잡지만, SKIP LOCKED 없는 FOR UPDATE(앞 트랜잭션을 기다렸다가 처리 — 결과가
    같다)는 가르지 못한다 → 5행 중 2행을 주 스레드의 app role 트랜잭션이 쥔 채 relay_once를 다른 스레드에서 돌리고
    LOCK_WAIT_S 안에 끝나는지 본다: RelayResult(3, 0, 0) · 잠긴 2행은 남는다. 잠금을 놓은 뒤 스레드를 마저 기다린다.
    """
    events = _seed(5)
    locked = {events[0].pk, events[1].pk}
    fake = FakeProducer()
    results: list[RelayResult] = []
    errors: list[Exception] = []

    def worker() -> None:
        try:
            results.append(relay_once(producer=fake))
        except Exception as exc:  # 스레드 예외를 주 스레드의 단언으로 옮긴다
            errors.append(exc)
        finally:
            connections.close_all()

    thread = threading.Thread(target=worker, daemon=True)
    with transaction.atomic():
        assert len(list(OutboxEvent.objects.select_for_update().filter(pk__in=locked))) == 2
        thread.start()
        thread.join(timeout=LOCK_WAIT_S)
        waited_on_lock = thread.is_alive()
    thread.join(timeout=THREAD_TIMEOUT_S)
    assert not thread.is_alive()
    assert not waited_on_lock, "relay_once가 잠긴 행을 기다렸다 — select_for_update(skip_locked=True)가 아니다"
    assert errors == []
    assert results == [RelayResult(published=3, failed=0, dead=0)]
    assert {call.envelope()["id"] for call in fake.calls} == {event.pk for event in events} - locked
    assert set(OutboxEvent.objects.using("owner").values_list("pk", flat=True)) == locked
