"""시험 공용 Kafka 소비 헬퍼(T072 D16 — django-common tests/_kafka.py와 같은 API). Django를 import하지 않는다.

시험 브로커는 PLAINTEXT · 자격 없음(conftest kafka).
- `subscribed(bootstrap, topic)`: 새 consumer group(무작위 이름)으로 topic을 구독한 Consumer를 주고, 블록이 끝나면 닫는다.
  `auto.offset.reset=earliest`라 구독 전에 쓰인 메시지도 읽는다 · 오프셋은 커밋하지 않는다.
- `drain(consumer, n, timeout_s)`: n건을 받거나 timeout_s가 지날 때까지 poll한다. 모자라면 받은 만큼 돌려준다(건수 단언은 시험이
  한다).
- `headers_dict(message)` · `decode_headers(pairs)`: 헤더 → 이름별 UTF-8 문자열. 같은 이름이 두 번 오면 실패한다.

"먼저 구독 → 릴레이 → 수신" 순서면 구독 시점에 토픽이 아직 없다(첫 produce가 자동 생성) — 구독 뒤 poll은
UNKNOWN_TOPIC_OR_PART를 돌려주고, 첫 produce가 토픽을 만든 뒤 약 2 s 안에 배정 · 수신된다(django-common 실측).
"""

from __future__ import annotations

import secrets
import time
from collections.abc import Iterable, Iterator
from contextlib import contextmanager

from confluent_kafka import Consumer, KafkaError, Message

POLL_INTERVAL_S = 0.5
# 구독한 토픽이 아직 없을 때 poll이 돌려주는 오류 이벤트 — 그 밖의 오류는 기다리지 않고 실패로 올린다.
_WAITING_FOR_TOPIC = frozenset({KafkaError.UNKNOWN_TOPIC_OR_PART, KafkaError._UNKNOWN_TOPIC})


@contextmanager
def subscribed(bootstrap: str, topic: str) -> Iterator[Consumer]:
    """새 consumer group으로 topic을 구독한 Consumer(earliest · 자동 커밋 없음). 블록이 끝나면 닫는다."""
    consumer = Consumer(
        {
            "bootstrap.servers": bootstrap,
            "group.id": f"jt-test-{secrets.token_hex(4)}",
            "auto.offset.reset": "earliest",
            "enable.auto.commit": False,
        }
    )
    try:
        consumer.subscribe([topic])
        yield consumer
    finally:
        consumer.close()


def drain(consumer: Consumer, n: int, timeout_s: float) -> list[Message]:
    """n건을 받거나 timeout_s가 지날 때까지 poll한다(모자라면 받은 만큼 돌려준다)."""
    messages: list[Message] = []
    deadline = time.monotonic() + timeout_s
    while len(messages) < n:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        message = consumer.poll(min(POLL_INTERVAL_S, remaining))
        if message is None:
            continue
        error = message.error()
        if error is None:
            messages.append(message)
        elif error.code() not in _WAITING_FOR_TOPIC:
            raise AssertionError(f"Kafka 소비 오류: {error}")
    return messages


def decode_headers(pairs: Iterable[tuple[str, bytes | None]] | None) -> dict[str, str | None]:
    """(이름, 값 bytes) 목록 → 이름별 UTF-8 문자열(값 없음은 None). 같은 이름이 두 번 오면 실패한다."""
    result: dict[str, str | None] = {}
    for name, value in pairs or ():
        if name in result:
            raise AssertionError(f"헤더 {name!r}가 두 번 있다")
        result[name] = None if value is None else value.decode("utf-8")
    return result


def headers_dict(message: Message) -> dict[str, str | None]:
    """소비한 메시지의 헤더 → 이름별 UTF-8 문자열."""
    return decode_headers(message.headers())
