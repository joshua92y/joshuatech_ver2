"""시험 인프라 검증(T061) — Django 없이 `pytest tests/test_fixtures_kafka.py -p no:django`로 돈다.

testcontainers Kafka(KRaft 단일 노드 · cp-kafka 8.0.0 · PLAINTEXT)가 Windows Docker Desktop의 호스트 광고 리스너로
confluent-kafka 클라이언트와 통하는지(VD-1)를 먼저 고정한다. 소비 헬퍼(tests/_kafka.py)는 tests/test_outbox.py
out-6과 같은 순서 — 먼저 구독 → 첫 produce가 토픽을 자동 생성 → 수신 — 로 검증한다.
"""

from __future__ import annotations

from confluent_kafka import KafkaError, Message, Producer

from tests._kafka import drain, headers_dict, subscribed

SMOKE_TOPIC = "tc-smoke"
# 구독한 consumer가 그룹에 들어가 "토픽 없음" 메타데이터를 먼저 받을 만큼 기다린 뒤 produce한다 — out-6에서
# 릴레이의 첫 produce가 구독보다 늦게 토픽을 만드는 최악 순서를 고정한다.
IDLE_BEFORE_PRODUCE_S = 3
RECEIVE_TIMEOUT_S = 20


def test_infra_k_1_roundtrip(kafka: str) -> None:
    """infra-k-1 — 구독 → produce(value b"ping" · 헤더 h=v) → 20 s 안에 1건 수신 · value와 헤더가 그대로 왕복한다.

    토픽 tc-smoke는 미리 만들지 않는다(브로커 기본 auto.create.topics.enable — out-6의 dev.… 토픽도 같다).
    """
    delivery_errors: list[KafkaError | None] = []

    def on_delivery(error: KafkaError | None, _message: Message) -> None:
        delivery_errors.append(error)

    producer = Producer({"bootstrap.servers": kafka})
    with subscribed(kafka, SMOKE_TOPIC) as consumer:
        assert drain(consumer, 1, timeout_s=IDLE_BEFORE_PRODUCE_S) == []
        producer.produce(SMOKE_TOPIC, value=b"ping", headers=[("h", b"v")], on_delivery=on_delivery)
        assert producer.flush(RECEIVE_TIMEOUT_S) == 0
        messages = drain(consumer, 1, timeout_s=RECEIVE_TIMEOUT_S)
    assert delivery_errors == [None]
    assert len(messages) == 1
    assert messages[0].value() == b"ping"
    assert headers_dict(messages[0]) == {"h": "v"}
