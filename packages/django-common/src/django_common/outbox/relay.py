"""relay_once — outbox 릴레이 한 패스(T069 · D4 · D6 · r2 J3 · J4 · J5 · r3 K5 · K7 · r4 L6 · 계약 events.md §outbox 릴레이
「구현 규칙」).

relay_once(*, producer=None, batch_size=100, batch_bytes=RELAY_BATCH_BYTES) -> RelayResult(published, failed, dead)
(이 패스에서 보낸 행 수 = 셋의 합 · 잘림 표시 truncated는 비교 밖 필드):
1. producer is None이면 build_producer()로 만들고 이 패스의 flush 뒤 버린다(close 없음). 주입된 프로듀서에는 produce · flush ·
   (남은 메시지가 있거나 flush가 치명 예외를 올렸을 때만) purge만 부른다. 프로듀서 유무는 `is None`으로 가른다(`producer or …`
   금지).
2. transaction.atomic(durable=True) 하나 — 다른 atomic 안에서 부르면 RuntimeError다(바깥이 롤백되면 이미 Kafka로 나간 행이
   되살아난다). 첫 문장은 SET LOCAL idle_in_transaction_session_timeout = '120s'(상수 · 바인드 없음 · 이 트랜잭션에만) —
   두 단계 flush(각 35 s + purge 뒤 5 s) 동안 app role의 30 s가 세션을 끊지 않게 한다.
3. 선택(J4 — 바이트 예산 · K5 — 크기 상한): ① dead_at IS NULL AND octet_length(payload::text) <= MAX_EVENT_BYTES(900,000 —
   publish ⑦과 같은 수 · 같은 측정이라 publish로 만든 행은 늘 안이다) ORDER BY id FOR UPDATE SKIP LOCKED LIMIT batch_size로 행을
   잠그며 id · topic · partition_key · attempts와 그 길이만 읽는다(payload는 읽지 않는다 · 잠긴 행은 기다리지 않고 건너뛴다 ·
   잠금은 커밋까지 쥔다 — 동시 릴레이 중복 0).
   - 상한을 넘는 행(owner가 손으로 넣은 행뿐이다)은 잠그지도 · 읽지도 · 보내지도 · 고치지도 않는다. attempts · last_error ·
     dead_at이 그대로고, 결과와 대기 규칙에도 들지 않는다(LIMIT 자리도 차지하지 않는다). 그 행은 pending으로 남아
     OutboxOldestPending이 알리고, 처리는 런북의 수동 확인 · 삭제다(T114). 그래서 손 행 하나가 머리를 막거나 relay를 OOM시키지
     못한다(리뷰 r2 A2-5 · B2-4).
   - 실패로 세지 않는 까닭: 홀로 남은 손 행이 진전 없음 백오프를 300 s로 키워 그 뒤 새 이벤트가 최대 5분 늦는다. dead로 두지
     않는 까닭: DLQ도 같은 값이라 실패하고(dead는 DLQ 사본이 있을 때만), outbox_dead_total에는 알림이 없어 30일 뒤 purge가 유일한
     사본을 조용히 지운다.
   - 한계: DB는 후보 행의 텍스트 길이를 패스마다 센다 — 거대 손 행이 있으면 그 변환 비용이 패스마다 든다(해법은 수동 삭제).
     또 상한 안 후보 행은 이 쿼리에서 길이를 두 번 센다(PG는 조건과 출력의 같은 식을 합치지 않는다 — DB 쪽 CPU만 · 계약 「한계」 ·
     L5 수용).
   ② 누적 바이트가 batch_bytes 안인 앞부분(최소 1행)만 payload::text를 읽어 보낸다. 고른 행은 모두 상한 안이므로 기본 예산
   (8 MiB)에서 한 행이 예산을 넘는 일은 없다 — 「예산보다 큰 행 하나는 혼자 간다」는 예산을 상한보다 작게 준 호출(시험)에서만
   생긴다. 나머지 잠긴 행은 손대지 않고 커밋 때 풀린다(attempts 그대로). 행 수 LIMIT을 채웠거나 예산에서 잘렸으면 truncated다
   (명령은 대기 0으로 다음 패스를 돈다). 900 KB 봉투 100행(약 90 MB × 사본 여럿)이 relay 메모리를 넘어 OOM 재시작을 반복하는
   것을 막는다.
4. 1단계 — 고른 행을 메인 토픽(OUTBOX_TOPIC_PREFIX + 행 topic)으로: key = partition_key(UTF-8) · value = 저장된 봉투의 PG jsonb
   텍스트(payload::text의 UTF-8 — J3: Python으로 해석 · 재직렬화하지 않는다 · id · time 재생성 없음 · 손으로 넣은 꼴 나쁜 행(5000
   자리 수 등)도 릴레이를 멈추지 못한다) · 헤더 ce_type(행 topic) · ce_source(OUTBOX_SOURCE) · ce_id(행 id) ·
   content-type(application/cloudevents+json) — 헤더는 행의 열과 설정에서 만든다. 호출은 키워드만(실 Producer의 다섯째 위치
   인자는 callback이다): produce(topic, value=…, key=…, headers=…, on_delivery=partial(기록, 행 id)). 기록 콜백은 이 패스의
   지역 dict에 err만 적는다(DB 쓰기 · 예외 없음 — 실 Producer는 flush를 부른 스레드에서, 대역은 produce 안에서 부른다 · DR의
   msg.headers()는 None이라 행 대응은 클로저로 맺는다). produce가 곧바로 낸 BufferError(큐 가득) · KafkaException
   (MSG_SIZE_TOO_LARGE 등)은 그 행의 실패, 그 밖의 예외는 올린다(버그 — 트랜잭션 롤백 · 명령은 로그 + 백오프).
5. flush(FLUSH_TIMEOUT_S)가 0보다 크면 purge(in_queue=True, in_flight=True) 뒤 flush(PURGE_FLUSH_TIMEOUT_S)로 purge DR을 받는다 —
   다음 패스로 지난 배치가 새지 않는다. flush가 치명 꼴 예외(9)를 올려도 같다 — 그 예외는 패스의 치명으로 접고, purge 뒤 flush의
   같은 꼴 예외도 삼킨다. 그 밖의 flush 예외는 올린다(버그 — 롤백 · 명령은 로그 + 백오프). 결과가 없는 행은 실패(「delivery 결과
   없음」)다. in-flight purge는 이미 기록됐을 수 있다(중복 — 소비자 (group, id) 멱등).
6. 2단계 — 1단계 실패 행 가운데 attempts + 1 ≥ OUTBOX_MAX_ATTEMPTS인 것을 같은 패스에서 DLQ(OUTBOX_TOPIC_PREFIX +
   OUTBOX_SOURCE + ".dlq")로: 같은 key · value · 헤더 넷 + ("error", 메인 오류 앞 LAST_ERROR_MAX자). flush · purge 규칙은 5와 같다.
   1단계에서 치명이 섰으면(9) 이 단계를 건너뛴다 — 같은 프로듀서로는 _FATAL 실패가 뻔하고, DLQ 오류가 last_error의 메인 오류를
   덮는다(그 행은 attempts + 1 · last_error = 메인 오류 · dead_at NULL — 다음 패스가 새 프로듀서로 메인부터 다시 시도한다).
7. 반영(같은 트랜잭션): 메인 성공 = 신호 없는 직접 DELETE(published — K7: QuerySet._raw_delete는 Django Collector를 거치지 않아
   지울 행을 먼저 읽지 않고 pre_delete · post_delete를 보내지 않는다. Collector는 sender 없는 삭제 수신기가 pod에 하나라도 있으면
   fast delete를 끄고 지울 행 전체(payload 포함)를 읽어 json.loads한다 — 손 행이면 ValueError로 패스가 롤백되고 재발송이 반복되며,
   수신기가 payload를 받는다 · 리뷰 r2 B2-3). 메인 실패 = attempts += 1 · last_error = str(err)의 앞 1000자 — DLQ까지 성공하면
   dead_at = Now()(dead), 아니면 행을 남긴다(failed · DLQ 실패면 last_error는 DLQ 오류). attempts ≥ 10인데 dead_at이 NULL인 행
   (앞선 DLQ 실패)도 다음 패스에서 메인부터 다시 시도한다 — 브로커 장애가 원인이면 복구 뒤 메인으로 간다.
8. 커밋 뒤 metrics.OUTBOX_DEAD_TOTAL.inc(dead)(지연 import — django_common.outbox를 import한 web 프로세스에 지표가 생기지 않게).
9. 치명 오류(J5 · L6 — T069 r4 정정 · confluent-kafka 2.16.1 실측): 치명 판정은 KafkaError.fatal() 또는 코드 _FATAL이다(치명
   오류가 난 인스턴스는 모든 produce를 거부한다). 출처는 셋이다 — produce 예외(fatal 표시 없이 코드 _FATAL) · flush 예외 · DR
   오류. confluent는 치명 오류를 error_cb로 넘기지 않고 flush · poll에서 KafkaException(fatal)으로 올린다. 같은 호출에서 DR 콜백이
   뒤따르면 CPython이 그 예외를 원인(__cause__ — 없으면 __context__)으로 한 SystemError로 바꾼다(실측 — 큐의 메시지는
   _PURGE_QUEUE DR로 온다. 그 예외가 걸린 채 불리는 첫 DR 콜백은 C 함수를 부르는 자리에서 끊길 수 있다 — 기록 콜백은 dict에
   적기만 해 실측에서 모든 행이 적혔다 · 그래도 DR이 없는 행은 5의 실패다). 이 두 꼴만 치명으로 접는다
   (_fatal_exception_name). 패스의 치명 이름은 flush 예외의 원인 이름이 앞선다(같은 패스 produce의 _FATAL보다 — 원인이
   보인다). 메인 · DLQ 어느 단계든 치명이면 그 패스를 위처럼 반영 · 커밋한 뒤 ProducerFatalError(.result = 이 패스의
   RelayResult · .error_name = 그 치명 이름)를 올린다 — 명령은 프로듀서를 버리고 다음 반복에 새로 만든다. 패스 사이(유휴 중)에
   난 치명 오류는 명령이 반복마다 패스 전에 부르는 poll(0)이 행에 닿기 전에 잡는다(명령 outbox_relay · L7).

시간 게이트 · 백오프는 없다(명령 outbox_relay 루프의 것 — 계약 「구현 규칙」 백오프 줄 · 명령 독스트링 「대기 next_wait」 · 리뷰
r5 A5-2). 순서는 최선 노력이다(실패 행 뒤의 행이 먼저 나간다 · 롤링 업데이트 동안 두 릴레이가 SKIP LOCKED로 나눈다).

설정(호출 시점): OUTBOX_SOURCE · OUTBOX_TOPIC_PREFIX(publisher가 검증) · OUTBOX_MAX_ATTEMPTS(1 이상의 int — bool 아님) ·
KAFKA_BOOTSTRAP_SERVERS · KAFKA_CLIENT_CONFIG(django_common.kafka.client_config가 검증). producer_config() =
client_config() + enable.idempotence True · delivery.timeout.ms 30000 · client.id 기본 OUTBOX_SOURCE — 고정값 키
(enable.idempotence · delivery.timeout.ms · 그 별칭 message.timeout.ms · librdkafka의 topic. 접두 표기 포함)를 설정이 두면
ImproperlyConfigured다. acks · retries · max.in.flight의 양립은 librdkafka가 생성 때 검사한다. build_producer() =
confluent_kafka.Producer(producer_config() + error_cb)이고 감싸개는 없다 — error_cb는 producer_config()의 결과에 넣지 않는다(결과
불변). 콜백은 비치명 오류 이벤트(_TRANSPORT · _ALL_BROKERS_DOWN 등)의 이름만 로그한다(logger django_common.outbox ·
`outbox_relay.kafka_error name=…` — 메시지 · fatal · retriable 없음 · L2 · L6). confluent-kafka는 사용자 error_cb가 없으면 이
이벤트를 버리므로 이 줄이 그 이벤트의 유일한 기록이다. 치명 오류와 retriable은 이 콜백에 실리지 않는다(2.16.1 실측 — 치명은 위
9의 flush · poll 예외로 온다 · retriable은 늘 False다). 콜백은 flush · poll 안에서만 불린다 — 명령이 반복마다 부르는 poll(0)이
유휴 중의 이벤트를 시간에 따라 흩어 로그한다(L7). librdkafka 자체 로그(FAIL · SSL · FATAL 줄 — 브로커 주소 · CA 경로)는 error_cb와
무관하게 stderr로 나가는 비JSON 줄이다(수집 형식은 T071). 설정 dict는 로그 · 예외 · repr에 싣지 않는다(sasl.password).
confluent_kafka는 함수 안에서 import한다(publish 경로가 불러오지 않는다).
"""

from __future__ import annotations

import functools
import logging
from collections.abc import Callable, Sequence
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, NamedTuple, Protocol

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import DEFAULT_DB_ALIAS, connections, transaction
from django.db.models import F, Func, IntegerField, TextField
from django.db.models.functions import Cast, Now

from django_common.kafka import client_config, property_name
from django_common.outbox.models import OutboxEvent
from django_common.outbox.publisher import MAX_EVENT_BYTES, outbox_source, topic_prefix

if TYPE_CHECKING:
    from confluent_kafka import Producer

__all__ = [
    "CONTENT_TYPE",
    "FLUSH_TIMEOUT_S",
    "LAST_ERROR_MAX",
    "NO_DELIVERY_RESULT",
    "PURGE_FLUSH_TIMEOUT_S",
    "RELAY_BATCH_BYTES",
    "ProducerFatalError",
    "RelayResult",
    "RelaySettings",
    "build_producer",
    "producer_config",
    "relay_once",
    "relay_settings",
]

logger = logging.getLogger("django_common.outbox")

FLUSH_TIMEOUT_S = 35  # delivery.timeout.ms 30 s + DR 지연(실측 0.01–0.71 s) 여유
PURGE_FLUSH_TIMEOUT_S = 5
LAST_ERROR_MAX = 1000
RELAY_BATCH_BYTES = 8 * 1024 * 1024  # 한 패스가 읽어 보내는 payload 텍스트 바이트 예산(최소 1행)
DELIVERY_TIMEOUT_MS = 30_000
NO_DELIVERY_RESULT = "delivery 결과 없음"
CONTENT_TYPE = "application/cloudevents+json"
IDLE_TIMEOUT_SQL = "SET LOCAL idle_in_transaction_session_timeout = '120s'"
_MAX_ATTEMPTS_SETTING = "OUTBOX_MAX_ATTEMPTS"
_FIXED_KEYS = ("enable.idempotence", "delivery.timeout.ms", "message.timeout.ms")


class _Producer(Protocol):
    """릴레이가 쓰는 confluent-kafka Producer의 부분(실 Producer · 시험 대역)."""

    def produce(
        self,
        topic: str,
        *,
        value: bytes,
        key: bytes,
        headers: list[tuple[str, bytes]],
        on_delivery: Callable[..., None],
    ) -> None: ...

    def flush(self, timeout: float) -> int: ...

    def purge(self, in_queue: bool = ..., in_flight: bool = ...) -> None: ...


@dataclass(frozen=True)
class RelayResult:
    """한 패스의 결과 — 보낸 행 수 = published + failed + dead. truncated(비교 밖)는 이 패스가 행 수 LIMIT을 채웠거나 바이트
    예산에서 잘렸는지다(명령의 대기 규칙이 쓴다 — 셋만 비교하는 T061 단언을 깨지 않는다)."""

    published: int
    failed: int
    dead: int
    truncated: bool = field(default=False, compare=False)


class ProducerFatalError(Exception):
    """프로듀서에 치명 오류가 났다 — 이 패스는 반영 · 커밋됐다(.result). .error_name은 그 패스의 치명 이름(KafkaError 이름 · 값
    없음 — flush 예외의 원인 이름이 앞선다 · 명령 로그의 진단 필드)이다. 그 프로듀서를 버리고 새로 만든다(메시지에 값 없음)."""

    def __init__(self, result: RelayResult, error_name: str | None = None) -> None:
        super().__init__("릴레이 프로듀서에 치명 오류가 났다 — 이 패스를 반영·커밋했다 · 프로듀서를 버리고 다시 만든다")
        self.result = result
        self.error_name = error_name


@dataclass(frozen=True)
class RelaySettings:
    """릴레이 설정(호출 시점에 읽고 검증한 값)."""

    source: str
    prefix: str
    max_attempts: int

    @property
    def dlq_topic(self) -> str:
        return f"{self.prefix}{self.source}.dlq"


class _Locked(NamedTuple):
    """① 잠근 행 — payload 없이 열과 PG 텍스트 길이만."""

    id: str
    topic: str
    partition_key: str
    attempts: int
    text_bytes: int


def relay_settings() -> RelaySettings:
    """OUTBOX_SOURCE · OUTBOX_TOPIC_PREFIX · OUTBOX_MAX_ATTEMPTS를 지금 읽어 검증한다(어기면 ImproperlyConfigured · 이름만)."""
    source = outbox_source()
    prefix = topic_prefix()
    max_attempts = getattr(settings, _MAX_ATTEMPTS_SETTING, None)
    if type(max_attempts) is not int or max_attempts < 1:
        raise ImproperlyConfigured(f"{_MAX_ATTEMPTS_SETTING}는 1 이상의 int여야 한다")
    return RelaySettings(source=source, prefix=prefix, max_attempts=max_attempts)


def producer_config() -> dict[str, Any]:
    """릴레이 프로듀서 설정 = client_config() + 고정값(모듈 독스트링 「설정」 · error_cb는 build_producer가 따로 단다)."""
    config = client_config()
    for key in config:
        if property_name(key) in _FIXED_KEYS:
            raise ImproperlyConfigured(f"KAFKA_CLIENT_CONFIG에 {key}를 둘 수 없다(라이브러리 고정값)")
    config["enable.idempotence"] = True
    config["delivery.timeout.ms"] = DELIVERY_TIMEOUT_MS
    config.setdefault("client.id", outbox_source())
    return config


def _is_fatal(error: object) -> bool:
    """치명 오류인가 — KafkaError.fatal()이거나 코드가 _FATAL이다(confluent는 produce 예외에 fatal 표시를 싣지 않을 수 있다)."""
    from confluent_kafka import KafkaError

    return isinstance(error, KafkaError) and (error.fatal() or error.code() == KafkaError._FATAL)


def _fatal_name(error: object) -> str | None:
    """치명 오류(_is_fatal)면 그 KafkaError 이름(값 없음), 아니면 None."""
    return str(error.name()) if _is_fatal(error) else None  # type: ignore[attr-defined]


def _fatal_exception_name(exc: BaseException) -> str | None:
    """flush · poll이 올린 예외가 치명 꼴이면 그 원인 KafkaError의 이름(값 없음), 아니면 None(모듈 독스트링 9 · L6 · L7 — 명령의
    패스 전 poll도 이 판정을 쓴다): args[0]이 치명(_is_fatal)인 KafkaException, 또는 __cause__(없으면 __context__)가 그런
    KafkaException인 SystemError. 그 밖의 예외(비치명 KafkaException · 원인이 다른 SystemError · 콜백 버그)는 None이다."""
    from confluent_kafka import KafkaException

    if isinstance(exc, SystemError):
        cause = exc.__cause__ if exc.__cause__ is not None else exc.__context__
        if not isinstance(cause, KafkaException):
            return None
        exc = cause
    if isinstance(exc, KafkaException) and exc.args:
        return _fatal_name(exc.args[0])
    return None


def _log_kafka_error(error: object) -> None:
    """confluent error_cb(flush · poll을 부른 스레드에서 돈다): 비치명 오류 이벤트의 이름만 로그한다(모듈 독스트링 「설정」 —
    메시지 · fatal · retriable 없음). 예외를 내지 않는다(콜백 예외는 flush · poll 밖으로 올라온다)."""
    from confluent_kafka import KafkaError

    name = str(error.name()) if isinstance(error, KafkaError) else type(error).__name__
    logger.warning("outbox_relay.kafka_error name=%s", name)


def build_producer() -> Producer:
    """confluent_kafka.Producer(producer_config() + error_cb) — 설정 오류는 생성에서 드러난다(키 오타 · 양립하지 않는 값 · CA ·
    모듈 독스트링 「설정」). 생성 단계 실패의 재현은 pod 안에서 이 함수를 부르는 것이다(client_config()만으로는 CA · 값 꼴 · 양립
    검사 실패를 재현하지 못한다). 감싸개는 없다(r3의 error_cb 치명 표시는 실물에서 닿지 않아 없앴다 — L6)."""
    from confluent_kafka import Producer

    return Producer({**producer_config(), "error_cb": _log_kafka_error})


def _headers(row: _Locked, source: str) -> list[tuple[str, bytes]]:
    return [
        ("ce_type", row.topic.encode("utf-8")),
        ("ce_source", source.encode("utf-8")),
        ("ce_id", row.id.encode("utf-8")),
        ("content-type", CONTENT_TYPE.encode("utf-8")),
    ]


type _Outgoing = tuple[_Locked, str, bytes, list[tuple[str, bytes]]]  # (행 · Kafka 토픽 · value · 헤더)


def _flush(producer: _Producer, timeout: float) -> tuple[int, str | None]:
    """producer.flush(timeout) → (남은 메시지 수, None). flush가 치명 꼴 예외(_fatal_exception_name)를 올리면 (0, 그 원인 이름) —
    그 패스의 치명으로 접는다(L6). 그 밖의 예외는 그대로 올린다(버그 — 트랜잭션 롤백 · 명령은 로그 + 백오프)."""
    try:
        return producer.flush(timeout), None
    except Exception as exc:
        name = _fatal_exception_name(exc)
        if name is None:
            raise
        return 0, name


def _deliver(producer: _Producer, messages: Sequence[_Outgoing]) -> tuple[dict[str, str], str | None]:
    """messages를 보내고 flush(남았거나 flush가 치명이면 purge + flush)한 뒤 (실패한 행 id → 오류 문자열 · 치명 이름 또는 None).

    치명은 produce 예외 · flush 예외(치명 꼴 — 그 원인 이름이 앞선다) · DR 오류에서 온다(모듈 독스트링 9)."""
    from confluent_kafka import KafkaException

    reports: dict[str, object] = {}

    def record(row_id: str, error: object, _message: object) -> None:
        reports[row_id] = error

    failures: dict[str, str] = {}
    fatal: str | None = None
    for row, topic, value, headers in messages:
        try:
            producer.produce(
                topic,
                value=value,
                key=row.partition_key.encode("utf-8"),
                headers=headers,
                on_delivery=functools.partial(record, row.id),
            )
        except BufferError as exc:
            failures[row.id] = str(exc)
        except KafkaException as exc:
            failures[row.id] = str(exc)
            fatal = fatal or _fatal_name(exc.args[0] if exc.args else None)
    remaining, flush_fatal = _flush(producer, FLUSH_TIMEOUT_S)
    if remaining > 0 or flush_fatal is not None:
        producer.purge(in_queue=True, in_flight=True)
        _remaining, purge_fatal = _flush(producer, PURGE_FLUSH_TIMEOUT_S)
        flush_fatal = flush_fatal or purge_fatal
    for row, _topic, _value, _headers_ in messages:
        if row.id in failures:
            continue
        if row.id not in reports:
            failures[row.id] = NO_DELIVERY_RESULT
        elif reports[row.id] is not None:
            failures[row.id] = str(reports[row.id])
            fatal = fatal or _fatal_name(reports[row.id])
    return failures, flush_fatal or fatal


def _leading_within(locked: Sequence[_Locked], budget: int) -> list[_Locked]:
    """누적 text_bytes가 budget 안인 앞부분(최소 1행 — 예산보다 큰 행 하나는 혼자 간다: 행은 크기 상한 안이라 예산을 상한보다
    작게 준 호출에서만 생긴다)."""
    chosen: list[_Locked] = []
    total = 0
    for row in locked:
        if chosen and total + row.text_bytes > budget:
            break
        chosen.append(row)
        total += row.text_bytes
    return chosen


def relay_once(
    *, producer: _Producer | None = None, batch_size: int = 100, batch_bytes: int = RELAY_BATCH_BYTES
) -> RelayResult:
    """outbox 한 패스 — 규칙은 모듈 독스트링(트랜잭션 밖에서만 부른다)."""
    config = relay_settings()
    if producer is None:
        producer = build_producer()
    outbox = OutboxEvent.objects.using(DEFAULT_DB_ALIAS)
    with transaction.atomic(using=DEFAULT_DB_ALIAS, durable=True):
        with connections[DEFAULT_DB_ALIAS].cursor() as cursor:
            cursor.execute(IDLE_TIMEOUT_SQL)
        payload_text = Cast("payload", output_field=TextField())
        locked = [
            _Locked(*columns)
            for columns in outbox.filter(dead_at__isnull=True)
            .annotate(text_bytes=Func(payload_text, function="OCTET_LENGTH", output_field=IntegerField()))
            .filter(text_bytes__lte=MAX_EVENT_BYTES)
            .order_by("id")
            .select_for_update(skip_locked=True)
            .values_list("id", "topic", "partition_key", "attempts", "text_bytes")[:batch_size]
        ]
        if not locked:
            return RelayResult(published=0, failed=0, dead=0)
        rows = _leading_within(locked, batch_bytes)
        truncated = len(locked) >= batch_size or len(rows) < len(locked)
        values = {
            row_id: text.encode("utf-8")
            for row_id, text in outbox.filter(pk__in=[row.id for row in rows])
            .annotate(text=payload_text)
            .values_list("id", "text")
        }
        main_messages = [(row, config.prefix + row.topic, values[row.id], _headers(row, config.source)) for row in rows]
        main_failures, fatal = _deliver(producer, main_messages)
        main_errors = {row_id: text[:LAST_ERROR_MAX] for row_id, text in main_failures.items()}
        to_dlq: list[_Locked] = []
        if fatal is None:  # 1단계에서 치명이 섰으면 DLQ 단계를 건너뛴다(모듈 독스트링 6 · L6)
            to_dlq = [row for row in rows if row.id in main_errors and row.attempts + 1 >= config.max_attempts]
        dlq_failures: dict[str, str] = {}
        if to_dlq:
            dlq_messages: list[_Outgoing] = []
            for row in to_dlq:
                headers = [*_headers(row, config.source), ("error", main_errors[row.id].encode("utf-8"))]
                dlq_messages.append((row, config.dlq_topic, values[row.id], headers))
            dlq_failures, dlq_fatal = _deliver(producer, dlq_messages)
            fatal = dlq_fatal  # 1단계는 치명이 아니었다(위 조건)
        dlq_ids = {row.id for row in to_dlq}
        published = [row.id for row in rows if row.id not in main_errors]
        if published:
            outbox.filter(pk__in=published)._raw_delete(DEFAULT_DB_ALIAS)
        failed = dead = 0
        for row in rows:
            if row.id not in main_errors:
                continue
            changes: dict[str, object] = {"attempts": F("attempts") + 1}
            if row.id in dlq_ids and row.id not in dlq_failures:
                changes.update(last_error=main_errors[row.id], dead_at=Now())
                dead += 1
            elif row.id in dlq_ids:
                changes["last_error"] = dlq_failures[row.id][:LAST_ERROR_MAX]
                failed += 1
            else:
                changes["last_error"] = main_errors[row.id]
                failed += 1
            outbox.filter(pk=row.id).update(**changes)
    if dead:
        from django_common.outbox import metrics

        metrics.OUTBOX_DEAD_TOTAL.inc(dead)
    result = RelayResult(published=len(published), failed=failed, dead=dead, truncated=truncated)
    if fatal is not None:
        raise ProducerFatalError(result, error_name=fatal)
    return result
