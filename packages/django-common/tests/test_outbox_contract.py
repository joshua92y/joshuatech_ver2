"""django_common.outbox · django_common.kafka 계약 시험(T069 소유 · D11 oc-1..20 · r2 J1–J10 oc-21..27 · r3 K5–K12 oc-28..30 ·
r4 L6–L9 oc-29a..e · r5 M1–M3 oc-29f · 29g · 15f) — T061 test_outbox.py가 고정하지 않은 결정을 가른다.

설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T069」(사실 ①–⑫ · 계약 보정 C1–C5 · 결정 D1–D16 · r2 결정
J1–J12 · r3 결정 K1–K13 · r4 결정 L1–L10 · r5 결정 M1–M9). 계약: contracts/events.md §발행 API · §outbox 릴레이(「T069 보정
2026-11-04」 · 「T069 r2」 · 「T069 r3」 · 「T069 r4」 · 「T069 r5」) · contracts/pod-template.md §django-common 공개 API ·
「이벤트」 · 「메트릭」 행 · data-model.md §4 · 규칙 .claude/rules/django-pod.md §Outbox and events.

- 설정 · 프로듀서(D6 · J8 · K8 · L6): client_config 규칙 · 금지 키와 그 다른 표기 · NUL 거부(키 · str 값 · bootstrap) · SASL_SSL
  TLS 두 키 양성 목록 · 메시지에 키 이름만(oc-1) · producer_config 강제 키 · 고정값 거부 · build_producer = error_cb를 단 실
  Producer(oc-2) · error_cb는 비치명 오류 이벤트의 이름만 로그한다(oc-29d).
- 치명 오류의 실물 꼴(L6 · L7 · L9 — confluent-kafka 2.16.1 실측): flush가 올린 치명 KafkaException(oc-29a) · 그것을 원인으로 한
  SystemError(oc-29b) → 그 패스 반영 · 커밋 · purge 뒤 DR · DLQ 단계 건너뜀 · ProducerFatalError(원인 이름) · 재생성. purge 뒤
  flush에서만 난 치명도 같다(oc-29g — M2). 그 밖의 flush 예외는 그대로 올린다(oc-29e). 명령의 패스 전 poll(0)이 유휴 중 치명을
  행에 닿기 전에 잡는다(oc-29c). 치명으로 버리고 다시 만든 프로듀서의 첫 패스가 빈 패스면 대기를 그대로 둔다 — 원인이 그대로면
  유휴 중에도 재생성 간격이 는다(oc-29f · oc-16 — M1).
- publish(D3 · J1 · J2 · J9 · K10): 토픽 · subject · data · jsonb 왕복 꼴(타입 · 깊이 64 · NUL · 지수 float · 순환) · 크기(PG jsonb
  텍스트 꼴) · 공유 참조 · 메시지에 값 없음 · 연쇄 없음(oc-3) · 측정 = PG octet_length(payload::text)(oc-21) · 테넌트 정규화 · GUC
  파손(oc-4) · Kafka 무접촉(oc-5) · 넓은 컨테이너 거부의 일시 메모리(oc-30 — K10).
- ULID(D10): 꼴 · 유일 · 단조(같은 ms · 시계 역행 · 넘침 · 동시 호출의 잠금 · 스레드)(oc-6).
- relay_once(D4 · J3–J5 · K5–K7 · K12): 메시지 모양 · value = payload::text · 키워드 호출 · ORDER BY id · LIMIT · prod 접두(oc-7)
  · flush 잔여 purge(oc-8 · 실 Producer oc-8b) · DLQ 실패 뒤 메인 우선(oc-9) · last_error 상한(oc-10) · produce 즉시 예외(oc-11) ·
  durable · SET LOCAL(oc-12) · 손으로 넣은 행도 PG 텍스트 그대로 · 신호 없는 직접 DELETE(oc-22 — K7) · 바이트 예산(oc-23) · 치명
  프로듀서(메인 단계 치명이면 DLQ 단계를 건너뛴다 · DLQ 단계의 치명 — oc-24 · K12 · L6) · 크기 상한을 넘는 손 행은 잠그지도 ·
  읽지도 · 보내지도 · 고치지도 않는다(oc-28 — K5).
- purge · 재처리(D8 · J10 · K7): purge_dead 경계 · DB 시계 · 신호 없는 DELETE 하나(oc-13) · requeue_dead · outbox_requeue(oc-14) ·
  outbox_purge(oc-27).
- 명령 outbox_relay(D7 · J5–J7 · K9 · K11 · K12 · L7 · M1 · M3): 발행 · 지표 갱신 · 기본값(oc-15a) · 순서(포트 → refresh →
  반복마다 close → 생성 → poll(0) → relay_once) · 설정 오류는 끝내지 않는다 · 포트를 열 수 없으면 CommandError로 끝난다(루프 전
  실패의 하나 · oc-15b) · 신호(oc-15c) · 루프 오류 = 로그(값 없는 진단 필드) + 백오프(oc-15d) · 진단 필드의 원인 보존은
  SystemError에만(oc-15f) · 인자(oc-15e) · 대기 규칙(첫 오류 대기 1 s = 하한 0.5 s × 2 · 치명 재생성 직후의 빈 패스는 대기
  유지 — oc-16 · 순수 함수) · 치명 프로듀서 재생성(oc-24 · oc-29a–c · 29f) · 프로듀서 생성 실패 재시도(oc-25) · refresh 분리 ·
  최소 간격 · refresh DB 오류 뒤 연결 정리(oc-26).
- 지표(D5): 지연 등록(oc-17 — 새 프로세스) · 나이가 스크레이프 시점에 자란다(oc-18).
- 모델 · 마이그레이션(D2): makemigrations --check · CreateModel 하나 · 인덱스 2 · RLS 없음 · DB 기본값(oc-19).
- 꼴 상수(사실 ⑫): 코드의 봉투 pattern 5 = packages/events/schemas/_envelope.json(oc-20 — 시험만 모노레포를 읽는다).

대역 프로듀서는 tests/_outbox_fakes.ScriptedProducer(키워드 전용 produce · DR은 flush · poll 안 · 훅 on_flush · on_poll)다. DB 별칭은
T061과 같다: default = app role(런타임 — publish · 릴레이 · purge · 지표) · owner = owner role(검증 읽기 · 시각 조작 · 손으로 넣는
행 · 잠금 탐침). 설정은 pytest-django settings 픽스처로 시험 안에서만 바꾼다(구현은 호출 시점에 읽는다). 비밀 · 값 자리에는 감시
문자열 SENTINEL을 넣고 오류 메시지 · 로그에 나오지 않음을 본다(이름에 비밀 낱말을 쓰지 않는다 — gitleaks generic-api-key가 시험
상수를 잡는다). 명령 시험은 대기 함수 `_sleep`을 기록기로 바꿔 대기 값(백오프)을 본다. pytest는 한 번에 하나만 돌린다.

빨간 상태(각 목록은 당시 시험 기준이다 — oc-29는 r4에서 29a–e로 갈음): T069 구현 전에는 모듈 머리의 django_common.kafka ·
django_common.outbox import가 ModuleNotFoundError다. r2 결정(J1–J10) 전 구현(r1)에서는 oc-1 · 2 · 3 · 7 · 15b · 15d · 16 · 21–27이
실패한다. r3 결정(K5–K12) 전 구현(r2)에서는 oc-1(K8) · 2(K6 감싸개) · 13 · 22(K7) · 15d · 25 · 26(K11 · K12) · 16(K9) · 24(K11 ·
K12) · 28(K5) · 29(K6) · 30(K10)이 실패한다(새 이름은 시험 안에서 모듈 속성으로 읽는다 — 수집은 된다). r4 결정(L6 · L7) 전
구현(r3)에서는 oc-2(감싸개 없음) · 15b(패스 전 poll) · 24(메인 단계 치명 뒤 DLQ 건너뜀) · 29a · 29b(flush 치명 예외) · 29c(poll
치명) · 29d(error_cb 줄의 필드)가 실패한다. oc-29e는 r3도 지키던 거동(그 밖의 flush 예외는 올린다)을 r4 감싸개가 깨지 않는지
고정한다. r5 결정(M1 · M3) 전 구현(r4)에서는 oc-16(next_wait의 after_fatal_rebuild 인자) · 29f(치명 재생성 직후 빈 패스의 대기
유지) · 15f(진단 원인 보존을 SystemError로 좁힘)가 실패한다. oc-29g(M2 — purge 뒤 flush에서만 난 치명)는 r4도 지키던 거동을
고정한다(판별력은 변이 L6-purge-fatal-dropped가 보인다).
"""

from __future__ import annotations

import contextlib
import errno
import importlib
import inspect
import io
import json
import logging
import os
import re
import signal
import socket
import subprocess
import sys
import threading
import time
import tracemalloc
from collections.abc import Callable, Iterator, Sequence
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from typing import TYPE_CHECKING, Any

import django.db
import psycopg
import pytest
from confluent_kafka import KafkaError, KafkaException, Producer
from django.core.exceptions import ImproperlyConfigured
from django.core.management import call_command
from django.core.management.base import CommandError
from django.db import InterfaceError, OperationalError, connections, migrations, transaction
from django.db.models.signals import post_delete, pre_delete
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from prometheus_client import REGISTRY

from django_common.kafka import client_config
from django_common.management.commands import outbox_relay as relay_command
from django_common.outbox import (
    OutboxEvent,
    OutboxUsageError,
    RelayResult,
    _ulid,
    metrics,
    publish,
    publisher,
    purge_dead,
    relay,
    relay_once,
    requeue_dead,
)
from tests._outbox_fakes import (
    CONTENT_TYPE,
    DATA,
    DLQ_HEADERS,
    DLQ_TOPIC,
    HOLD,
    KAFKA_TOPIC,
    MAIN_HEADERS,
    MAX_ATTEMPTS,
    SOURCE,
    SUBJECT,
    TENANT_A,
    TENANT_B,
    TOPIC,
    Fail,
    ScriptedProducer,
    fail_topics,
    owner_execute,
    owner_rows,
    owner_scalar,
    raising,
    seed,
)
from tests._tenant import set_tenant

if TYPE_CHECKING:
    from pytest_django.fixtures import SettingsWrapper

pytestmark = pytest.mark.django_db(transaction=True, databases=["default", "owner"])

SENTINEL = "oc-sentinel-7f3a9c1d"  # 감시 문자열(비밀번호 · 오류 본문 · data 값 자리) — 메시지 · 로그에 나오면 실패
BOOTSTRAP = "jt-kafka-kafka-bootstrap.data.svc:9093"
SASL: dict[str, str] = {
    "security.protocol": "SASL_SSL",
    "sasl.mechanism": "SCRAM-SHA-512",
    "sasl.username": "identity-admin",
    "sasl.password": SENTINEL,
    "ssl.ca.location": "/etc/kafka-ca/ca.crt",
}
VERIFY = "enable.ssl.certificate.verification"
ALGORITHM = "ssl.endpoint.identification.algorithm"
ULID_RE = re.compile(r"^[0-7][0-9A-HJKMNP-TV-Z]{25}$")
CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
LF, CR = chr(0x0A), chr(0x0D)
PACKAGE_ROOT = Path(__file__).resolve().parents[1]
ENVELOPE_SCHEMA = Path(__file__).resolve().parents[3] / "packages" / "events" / "schemas" / "_envelope.json"
NO_RESULT = "delivery 결과 없음"  # 설계 D4-5 — flush · purge 뒤에도 DR이 없는 행의 last_error
RELAY_LOGGER = "django_common.outbox"
MIB = 1024 * 1024
PEAK_LIMIT = 6_000_000  # tracemalloc 정점 상한(바이트) — 직렬화 · 읽기를 미리 하면 8 MB를 넘는다
QUIET_PEAK = 2_000_000  # K5 · K10의 정점 상한 — 거대 손 행 · 넓은 컨테이너의 크기와 무관해야 한다
NUL = chr(0)
# 행 payload 열을 그대로 읽는 SQL 조각(Django Collector의 SELECT) — 릴레이의 두 쿼리는 늘 `("outbox"."payload")::text`다(K7).
BARE_PAYLOAD = re.compile(r'"outbox"\."payload"(?!\)::text)')


def _without(config: dict[str, str], key: str) -> dict[str, str]:
    return {name: value for name, value in config.items() if name != key}


def _sample(name: str) -> float:
    value = REGISTRY.get_sample_value(name)
    assert value is not None, f"지표 {name}(레이블 없음)이 기본 REGISTRY에 없다"
    return value


def _closed_port() -> int:
    """지금 아무도 듣지 않는 127.0.0.1 포트(잡았다가 놓는다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        return int(probe.getsockname()[1])


def _ulid_ms(value: str) -> int:
    """ULID 앞 10자(50비트 · 위 2비트 0) → 48비트 ms."""
    number = 0
    for char in value[:10]:
        number = number * 32 + CROCKFORD.index(char)
    return number


def _envelope_bytes(subject: str, data: dict[str, Any]) -> int:
    """publish가 잴 봉투 바이트(J2 — PG jsonb 텍스트 꼴: 쉼표 · 콜론 뒤 공백 · ensure_ascii=False · UTF-8). 시험이 따로 계산한다
    (id · time은 같은 길이의 자리 값)."""
    envelope = {
        "specversion": "1.0",
        "id": "0" * 26,
        "source": SOURCE,
        "type": TOPIC,
        "time": "2026-01-01T00:00:00.000Z",
        "subject": subject,
        "tenantid": str(TENANT_A),
        "datacontenttype": "application/json",
        "data": data,
    }
    return len(json.dumps(envelope, ensure_ascii=False, separators=(", ", ": ")).encode("utf-8"))


def _publish_rejected(
    topic: object, subject: object, data: object, **kwargs: Any
) -> tuple[OutboxUsageError, list[str]]:
    """atomic 안 publish가 OutboxUsageError를 내는지 · 그 동안의 default 쿼리(SQL 목록)."""
    with transaction.atomic():
        with CaptureQueriesContext(connections["default"]) as queries, pytest.raises(OutboxUsageError) as info:
            publish(topic, subject, data, **kwargs)  # type: ignore[arg-type]
    return info.value, [query["sql"] for query in queries.captured_queries]


def _assert_clean(error: BaseException, label: str) -> None:
    """메시지에 입력 값(SENTINEL)이 없고 예외 연쇄가 없다(`from None` — 트레이스백이 원인 예외의 값을 싣지 않게 · J9)."""
    assert SENTINEL not in str(error), f"{label}: 메시지에 입력 값이 있다"
    assert error.__cause__ is None, f"{label}: __cause__가 있다"
    assert error.__suppress_context__, f"{label}: from None이 아니다"


def _drive(fake: ScriptedProducer, passes: int) -> list[RelayResult]:
    return [relay_once(producer=fake) for _ in range(passes)]


def _owner_all(statement: str, params: tuple[object, ...] = ()) -> list[tuple[Any, ...]]:
    with connections["owner"].cursor() as cursor:
        cursor.execute(statement, list(params))
        return list(cursor.fetchall())


def _owner_texts() -> dict[str, str]:
    """owner로 읽은 행 id → payload::text(PG jsonb 텍스트 — 릴레이 value의 기대값 · J3)."""
    return {row_id: text for row_id, text in _owner_all("SELECT id, payload::text FROM outbox")}


def _owner_ids() -> set[str]:
    """owner로 읽은 행 id(payload를 Python으로 해석하지 않는다 — 손으로 넣은 행이 있을 때)."""
    return {row_id for (row_id,) in _owner_all("SELECT id FROM outbox")}


def _hand_insert(row_id: str, payload_text: str) -> None:
    """owner가 publish를 거치지 않고 행 하나를 넣는다(J3 · J4 — 손으로 넣은 행 · 관문보다 큰 행)."""
    owner_execute(
        "INSERT INTO outbox (id, topic, partition_key, payload, attempts) VALUES (%s, %s, %s, %s::jsonb, 0)",
        [row_id, TOPIC, str(TENANT_A), payload_text],
    )


def _nested_dicts(depth: int) -> dict[str, Any]:
    """data 자신을 깊이 1로 센 dict 중첩 — 가장 안쪽 dict의 깊이가 depth다(J1 — 64까지 통과)."""
    data: dict[str, Any] = {"probe": SENTINEL}
    inner = data
    for _ in range(depth - 1):
        inner["n"] = {}
        inner = inner["n"]
    return data


def _nested_lists(count: int) -> list[Any]:
    """list count겹(가장 안쪽은 빈 list)."""
    value: list[Any] = []
    for _ in range(count - 1):
        value = [value]
    return value


def _record_waits(monkeypatch: pytest.MonkeyPatch) -> list[float]:
    """명령의 대기 함수를 기록기로 바꾼다(실제로 자지 않는다) — 대기 값 목록."""
    waits: list[float] = []
    monkeypatch.setattr(relay_command, "_sleep", lambda seconds, _stop: waits.append(seconds))
    return waits


def _peak(call: Callable[[], Any]) -> tuple[Any, int]:
    """call()의 결과와 그 동안의 tracemalloc 정점(바이트)."""
    tracemalloc.start()
    try:
        result = call()
        _current, peak = tracemalloc.get_traced_memory()
    finally:
        tracemalloc.stop()
    return result, peak


@contextlib.contextmanager
def _delete_receivers() -> Iterator[list[str]]:
    """sender 없는 pre_delete · post_delete 수신기를 단다(K7). Django Collector는 이런 수신기가 하나라도 있으면 fast delete를 끄고
    지울 행 전체(payload 포함)를 먼저 읽어 인스턴스로 만든 뒤 수신기를 부른다 — 신호 없는 직접 DELETE면 호출 0이다. 기록은 신호
    이름만(인스턴스 · payload를 쥐지 않는다)."""
    calls: list[str] = []

    def receiver(sender: object, **kwargs: object) -> None:
        calls.append("pre_delete" if kwargs.get("signal") is pre_delete else "post_delete")

    pre_delete.connect(receiver, weak=False, dispatch_uid="oc-k7-pre-delete")
    post_delete.connect(receiver, weak=False, dispatch_uid="oc-k7-post-delete")
    try:
        yield calls
    finally:
        pre_delete.disconnect(dispatch_uid="oc-k7-pre-delete")
        post_delete.disconnect(dispatch_uid="oc-k7-post-delete")


def _sql(queries: CaptureQueriesContext) -> list[str]:
    return [query["sql"] for query in queries.captured_queries]


def _hand_insert_sized(row_id: str, size: int) -> None:
    """owner가 octet_length(payload::text)가 정확히 size인 행을 넣는다(K5 — PG가 다시 쓴 텍스트의 길이를 PG로 잰다)."""

    def text(fill: int) -> str:
        return json.dumps({"id": row_id, "blob": "x" * fill})

    overhead = owner_scalar("SELECT octet_length(%s::jsonb::text)", [text(0)])
    _hand_insert(row_id, text(size - overhead))
    assert owner_scalar("SELECT octet_length(payload::text) FROM outbox WHERE id = %s", [row_id]) == size


def _row_locked(row_id: str) -> bool:
    """owner 연결에서 그 행을 FOR UPDATE NOWAIT로 잠가 본다(autocommit — 문이 끝나면 놓는다) — 다른 트랜잭션이 쥐고 있으면 참."""
    try:
        owner_execute("SELECT id FROM outbox WHERE id = %s FOR UPDATE NOWAIT", [row_id])
    except OperationalError:
        return True
    return False


def _relay_lines(caplog: pytest.LogCaptureFixture) -> list[str]:
    """릴레이 로거의 메시지 가운데 이벤트 줄(`outbox_relay.`로 시작)."""
    return [message for message in caplog.messages if message.startswith("outbox_relay.")]


class _OddCause(Exception):
    """sqlstate 자리에 SQLSTATE 꼴(5자 · 숫자 · 대문자)이 아닌 값을 가진 원인 예외 — 진단 필드가 꼴을 확인해 싣지 않는지 본다
    (K11 fail-closed · 값 자리는 감시 문자열)."""

    sqlstate = "x-" + SENTINEL


FATAL_NAME = "CLUSTER_AUTHORIZATION_FAILED"  # 치명 오류 원인의 KafkaError 이름(실측 탐침의 코드 — InitProducerId 거부와 같다)


def _fatal_error() -> KafkaException:
    """confluent가 flush · poll에서 올리는 치명 예외 꼴(L6 — KafkaError(…, fatal=True) · 본문 자리는 감시 문자열)."""
    reason = f"Broker: Cluster authorization failed {SENTINEL}"
    return KafkaException(KafkaError(KafkaError.CLUSTER_AUTHORIZATION_FAILED, reason, fatal=True))


def _system_error(*, cause: BaseException | None = None, context: BaseException | None = None) -> SystemError:
    """DR 콜백이 치명 예외가 걸린 채 불릴 때 CPython이 만드는 SystemError 꼴(L6) — 메시지는 실물 꼴이다(그 DR 콜백 함수의 이름 ·
    M7). 원인은 __cause__와 __context__ 가운데 준 것에만 둔다(두 갈래를 따로 본다 · 본문 자리는 감시 문자열)."""
    error = SystemError(f"<function record at 0x000001f2a3b4c5d0> returned a result with an exception set {SENTINEL}")
    if cause is not None:
        error.__cause__ = cause
    if context is not None:
        error.__context__ = context
    return error


def _fatal_produce_error() -> KafkaException:
    """치명 오류 뒤 produce가 곧바로 내는 예외 꼴(코드 _FATAL · fatal 표시 없음 — 실측)."""
    return KafkaException(KafkaError(KafkaError._FATAL, f"Fatal error {SENTINEL}"))


def _attempts_at_produce(sink: list[int]) -> Callable[[Any], None]:
    """on_produce 훅: 보내는 행의 그 순간 attempts(owner로 읽는다 — 커밋된 값)를 sink에 적는다."""
    return lambda sent: sink.append(owner_scalar("SELECT attempts FROM outbox WHERE id = %s", [sent.row_id()]))


def _relay_command(
    monkeypatch: pytest.MonkeyPatch,
    caplog: pytest.LogCaptureFixture,
    producers: Sequence[ScriptedProducer | Exception],
    iterations: int,
) -> tuple[list[ScriptedProducer | Exception], list[float]]:
    """build_producer를 producers를 차례로 돌려주는 대역으로 바꿔 명령을 돈다(포트 0 · 폴링 0.5 s · 대기 기록 · 예외 항목은 그
    차례의 생성이 올린다 — M1) — (만든 것 · 대기)."""
    built: list[ScriptedProducer | Exception] = []

    def build() -> ScriptedProducer:
        item = producers[len(built)]
        built.append(item)
        if isinstance(item, Exception):
            raise item
        return item

    monkeypatch.setattr(relay, "build_producer", build)
    waits = _record_waits(monkeypatch)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", str(iterations), "--metrics-port", "0", "--poll-interval", "0.5")
    return built, waits


# --- D6 · J8 설정 · 프로듀서 -----------------------------------------------------------------------------------------


def test_oc_1_client_config_rules(settings: SettingsWrapper) -> None:
    """oc-1 — client_config()(D6 · J8 · K8): 결과 = {"bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS, **KAFKA_CLIENT_CONFIG}.

    거부(각각 ImproperlyConfigured · 메시지에 설정 · 키 이름은 있고 값(SENTINEL)과 NUL은 없다 · 연쇄 없음): bootstrap 빔 · str 아님
    · NUL · 설정이 Mapping 아님 · str 아닌 키 · 키에 NUL(partitioner · bootstrap.servers · delivery.report.only.error — PLAINTEXT
    에도 · confluent는 C 문자열로 넘겨 NUL에서 자르므로 잘린 이름이 검사를 비켜 간다 · 메시지는 키 자체를 싣지 않는다) · str 값에
    NUL · security.protocol 없음 · 허용 밖 값(SSL · SASL_PLAINTEXT) · SASL_SSL에서 mechanism · username · password · ca 각각 빠짐
    (빈 값 포함) · mechanism이 SCRAM-SHA-512가 아님(복수형 키 포함) · 금지 키(bootstrap.servers · 그 별칭 metadata.broker.list ·
    transactional.id · delivery.report.only.error · partitioner · enable.gapless.guarantee — PLAINTEXT에도) · 같은 속성의 다른
    표기(librdkafka는 `topic.<속성>`을 토픽 속성으로 읽는다 · confluent의 default.topic.config는 안의 값이 최상위 값을 덮는다 —
    실측) · SASL_SSL에서 TLS 두 키의 양성 목록 밖 값(K8 — fail-closed · librdkafka의 왼쪽 공백 제거 · 대소문자 무시 해석을
    흉내 내지 않는다): enable.ssl.certificate.verification이 True · 정수 1 · "true" · "t"(대소문자 무시) · "1"이 아닌 값(거짓 꼴
    False · 0 · "false" · "f" · "0" · 앞 공백 " true" · "no" · "yes" · NUL 접미 · float 1.0 · None · 빈 값) ·
    ssl.endpoint.identification.algorithm이 "https"(대소문자 무시)가 아닌 값(none · 앞 공백 · 탭 · NUL 접미 · 빈 값 · None ·
    공백이 붙은 https). 통과: 명시 PLAINTEXT(대소문자 무시) · 소문자 sasl_ssl · 복수형 sasl.mechanisms · SASL_SSL에서 TLS 두 키
    없음 · 검증 켬(True · "true" · "TRUE" · "t" · "T" · 1 · "1") · algorithm "https" · "HTTPS" · PLAINTEXT의 TLS 키(TLS가 없다 —
    보지 않는다).
    """
    settings.KAFKA_BOOTSTRAP_SERVERS = BOOTSTRAP
    accepted: list[dict[str, object]] = [
        dict(SASL),
        {**_without(SASL, "sasl.mechanism"), "security.protocol": "sasl_ssl", "sasl.mechanisms": "SCRAM-SHA-512"},
        {"security.protocol": "PLAINTEXT"},
        {"security.protocol": "plaintext"},
        *({**SASL, VERIFY: value} for value in (True, "true", "TRUE", "t", "T", 1, "1")),
        {**SASL, ALGORITHM: "https"},
        {**SASL, ALGORITHM: "HTTPS"},
        {"security.protocol": "PLAINTEXT", VERIFY: False, ALGORITHM: "none"},
    ]
    for config in accepted:
        settings.KAFKA_CLIENT_CONFIG = config
        assert client_config() == {"bootstrap.servers": BOOTSTRAP, **config}, config

    not_mapping = f"security.protocol=SASL_SSL;sasl.password={SENTINEL}"
    plaintext_txn = {"security.protocol": "PLAINTEXT", "transactional.id": "x"}
    cases: list[tuple[str, object, object, str]] = [
        ("bootstrap 빔", "", SASL, "KAFKA_BOOTSTRAP_SERVERS"),
        ("bootstrap str 아님", ["a:9093"], SASL, "KAFKA_BOOTSTRAP_SERVERS"),
        ("bootstrap NUL", BOOTSTRAP + NUL + SENTINEL, SASL, "KAFKA_BOOTSTRAP_SERVERS"),
        ("설정 Mapping 아님", BOOTSTRAP, not_mapping, "KAFKA_CLIENT_CONFIG"),
        ("str 아닌 키", BOOTSTRAP, {**SASL, 7: "x"}, "KAFKA_CLIENT_CONFIG"),
        ("키 NUL partitioner", BOOTSTRAP, {**SASL, "partitioner" + NUL: SENTINEL}, "KAFKA_CLIENT_CONFIG"),
        (
            "키 NUL bootstrap.servers",
            BOOTSTRAP,
            {**SASL, "bootstrap.servers" + NUL + SENTINEL: "evil:9093"},
            "KAFKA_CLIENT_CONFIG",
        ),
        (
            "키 NUL delivery.report.only.error",
            BOOTSTRAP,
            {**SASL, "delivery.report.only.error" + NUL: True},
            "KAFKA_CLIENT_CONFIG",
        ),
        (
            "PLAINTEXT에도 키 NUL",
            BOOTSTRAP,
            {"security.protocol": "PLAINTEXT", "partitioner" + NUL: "random"},
            "KAFKA_CLIENT_CONFIG",
        ),
        ("값 NUL sasl.password", BOOTSTRAP, {**SASL, "sasl.password": SENTINEL + NUL + "x"}, "sasl.password"),
        (
            "값 NUL ssl.ca.location",
            BOOTSTRAP,
            {**SASL, "ssl.ca.location": "/etc/kafka-ca/ca.crt" + NUL + SENTINEL},
            "ssl.ca.location",
        ),
        ("security.protocol 없음", BOOTSTRAP, _without(SASL, "security.protocol"), "security.protocol"),
        ("security.protocol SSL", BOOTSTRAP, {**SASL, "security.protocol": "SSL"}, "security.protocol"),
        (
            "security.protocol SASL_PLAINTEXT",
            BOOTSTRAP,
            {**SASL, "security.protocol": "SASL_PLAINTEXT"},
            "security.protocol",
        ),
        ("sasl.mechanism 없음", BOOTSTRAP, _without(SASL, "sasl.mechanism"), "sasl.mechanism"),
        ("sasl.mechanism PLAIN", BOOTSTRAP, {**SASL, "sasl.mechanism": "PLAIN"}, "sasl.mechanism"),
        ("sasl.mechanism SCRAM-SHA-256", BOOTSTRAP, {**SASL, "sasl.mechanism": "SCRAM-SHA-256"}, "sasl.mechanism"),
        ("sasl.mechanism 소문자", BOOTSTRAP, {**SASL, "sasl.mechanism": "scram-sha-512"}, "sasl.mechanism"),
        (
            "sasl.mechanisms 복수형 PLAIN",
            BOOTSTRAP,
            {**_without(SASL, "sasl.mechanism"), "sasl.mechanisms": "PLAIN"},
            "sasl.mechanism",
        ),
        ("sasl.username 없음", BOOTSTRAP, _without(SASL, "sasl.username"), "sasl.username"),
        ("sasl.username 빔", BOOTSTRAP, {**SASL, "sasl.username": ""}, "sasl.username"),
        ("sasl.password 없음", BOOTSTRAP, _without(SASL, "sasl.password"), "sasl.password"),
        ("sasl.password 빔", BOOTSTRAP, {**SASL, "sasl.password": ""}, "sasl.password"),
        ("ssl.ca.location 없음", BOOTSTRAP, _without(SASL, "ssl.ca.location"), "ssl.ca.location"),
        ("ssl.ca.location 빔", BOOTSTRAP, {**SASL, "ssl.ca.location": ""}, "ssl.ca.location"),
        ("bootstrap.servers 키", BOOTSTRAP, {**SASL, "bootstrap.servers": "evil:9093"}, "bootstrap.servers"),
        ("transactional.id 키", BOOTSTRAP, {**SASL, "transactional.id": "relay"}, "transactional.id"),
        ("PLAINTEXT에도 금지 키", BOOTSTRAP, plaintext_txn, "transactional.id"),
        ("metadata.broker.list(별칭)", BOOTSTRAP, {**SASL, "metadata.broker.list": SENTINEL}, "metadata.broker.list"),
        (
            "delivery.report.only.error",
            BOOTSTRAP,
            {**SASL, "delivery.report.only.error": True},
            "delivery.report.only.error",
        ),
        ("partitioner", BOOTSTRAP, {**SASL, "partitioner": SENTINEL}, "partitioner"),
        ("enable.gapless.guarantee", BOOTSTRAP, {**SASL, "enable.gapless.guarantee": True}, "enable.gapless.guarantee"),
        (
            "PLAINTEXT에도 partitioner",
            BOOTSTRAP,
            {"security.protocol": "PLAINTEXT", "partitioner": "random"},
            "partitioner",
        ),
        ("topic. 접두 partitioner", BOOTSTRAP, {**SASL, "topic.partitioner": SENTINEL}, "topic.partitioner"),
        (
            "default.topic.config",
            BOOTSTRAP,
            {**SASL, "default.topic.config": {"bootstrap.servers": SENTINEL}},
            "default.topic.config",
        ),
        *(
            (f"SASL_SSL 검증 양성 목록 밖 {value!r}", BOOTSTRAP, {**SASL, VERIFY: value}, VERIFY)
            for value in (
                *(False, 0, "false", "False", "FALSE", "f", "F", "0"),
                *("false" + NUL + "x", " true", "no", "yes", 1.0, None, ""),
            )
        ),
        *(
            (f"SASL_SSL algorithm 양성 목록 밖 {value!r}", BOOTSTRAP, {**SASL, ALGORITHM: value}, ALGORITHM)
            for value in ("none", "NONE", "None", " none", "\tnone", "none" + NUL + "x", "", None, " https", "https ")
        ),
    ]
    for label, bootstrap, config, key in cases:
        settings.KAFKA_BOOTSTRAP_SERVERS = bootstrap
        settings.KAFKA_CLIENT_CONFIG = config
        with pytest.raises(ImproperlyConfigured) as info:
            client_config()
        message = str(info.value)
        assert key in message, f"{label}: 메시지에 이름 {key}가 없다"
        assert SENTINEL not in message, f"{label}: 메시지에 비밀 값이 있다"
        assert NUL not in message, f"{label}: 메시지에 NUL(키 · 값 조각)이 있다"
        assert info.value.__cause__ is None, label
        assert info.value.__suppress_context__ or info.value.__context__ is None, label


def test_oc_2_producer_config_and_real_producer(settings: SettingsWrapper) -> None:
    """oc-2 — producer_config()(D6) = client_config() + enable.idempotence True · delivery.timeout.ms 30000(int) ·
    client.id 기본 OUTBOX_SOURCE(설정이 주면 그 값) — error_cb는 producer_config에 들지 않는다(K6 — 결과 불변). 고정값 키
    (enable.idempotence · delivery.timeout.ms · message.timeout.ms — librdkafka의 topic. 접두 표기 포함 · J8)가 설정에 있으면
    ImproperlyConfigured(키 이름). build_producer()는 브로커 없이 만든 실 confluent_kafka.Producer(error_cb를 단 것 — 감싸개
    없음: error_cb의 치명 표시를 없앴다 · L6 — error_cb는 oc-29d)다 — 대조: 키 오타는 생성 실패(그래서 생성 단계가 설정을 실제로
    검사한다)."""
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{_closed_port()}"
    settings.KAFKA_CLIENT_CONFIG = {"security.protocol": "PLAINTEXT"}
    config = relay.producer_config()
    assert config == {
        "bootstrap.servers": settings.KAFKA_BOOTSTRAP_SERVERS,
        "security.protocol": "PLAINTEXT",
        "enable.idempotence": True,
        "delivery.timeout.ms": 30000,
        "client.id": SOURCE,
    }
    assert type(config["delivery.timeout.ms"]) is int
    settings.KAFKA_CLIENT_CONFIG = {"security.protocol": "PLAINTEXT", "client.id": "relay-custom"}
    assert relay.producer_config()["client.id"] == "relay-custom"
    fixed = (
        ("enable.idempotence", False),
        ("delivery.timeout.ms", 300000),
        ("message.timeout.ms", 300000),
        ("topic.message.timeout.ms", 300000),
        ("topic.delivery.timeout.ms", 300000),
    )
    for key, value in fixed:
        settings.KAFKA_CLIENT_CONFIG = {"security.protocol": "PLAINTEXT", key: value}
        with pytest.raises(ImproperlyConfigured) as info:
            relay.producer_config()
        assert key in str(info.value)
    settings.KAFKA_CLIENT_CONFIG = {"security.protocol": "PLAINTEXT"}
    producer = relay.build_producer()
    assert isinstance(producer, Producer), type(producer).__name__
    assert producer.flush(0) == 0
    with pytest.raises(KafkaException):
        Producer({**relay.producer_config(), "enable.idempotency": True})


# --- D3 · J1 · J2 · J9 publish -------------------------------------------------------------------------------------


def test_oc_3_publish_rejects_topic_subject_data_json_size(settings: SettingsWrapper) -> None:
    """oc-3 — publish 관문(D3 · J1 · J2 · J9 · 계약 §발행 API 「입력 검사와 순서」): 각각 OutboxUsageError · 행 0 · 메시지에 값
    없음(입력에 감시 문자열 SENTINEL을 심는다) · 연쇄 없음(`__cause__` None · `__suppress_context__`).

    토픽(② — 쿼리 0): 다른 pod · dev. 접두 · 대문자 · 두 성분 · 끝 줄바꿈 · 이름만 같은 다른 pod(`identity-admin-x`) · 접두 포함
    249자 초과(접두 포함 249자는 통과) · str 아님. subject(③ — 쿼리 0): 콜론 없음 · 제어 문자 · 끝 줄바꿈 · 종류 대문자 · str 아님.
    data(④ — 쿼리 0): dict 아님(list · str · tuple · None). jsonb 왕복 꼴(⑥ — 컨텍스트를 읽은 뒤 · INSERT 없음 · 2 s 안): 허용 밖
    타입(tuple · datetime · UUID · Decimal · bytes · set · 임의 객체) · str 아닌 키(int · None · bool · 중첩) · 깊이 65(data = 1 ·
    dict 사슬 · list 사슬 — 64는 통과) · NUL(값 · 키 · 중첩) · 지수 꼴 float(1e16 · 1e300 · -1e16 · 1e-05 · 1.5e-07) · NaN · ±inf ·
    순환 참조(dict · list — 깊이 상한으로 곧 끝난다) · 짝 없는 서로게이트(UTF-8로 쓸 수 없다) · 4300자리를 넘는 int(Python이
    직렬화하지 않는다). 통과 경계: 깊이 64(dict · list) · float 1e15 · -1e15 · 0.0001 · 0.0(repr에 지수 없음) · bool · None ·
    4000자리 int 200개(약 800 KB — 순회의 바이트 하한이 실제 길이를 넘지 않는다).
    크기(⑦): PG jsonb 텍스트 꼴(쉼표 · 콜론 뒤 공백 · ensure_ascii=False) UTF-8 바이트 900,000은 통과(PG octet_length도 900,000) ·
    900,001은 거부(한글 blob). 공유 참조로 부푼 data(같은 list를 23겹 — 펼치면 잎 2^23 · 같은 100 KB str 100번 · 같은 4000자리 int
    2000번)는 2 s 안에 · 큰 할당 없이 거부된다(순회가 바이트 하한을 세며 상한을 넘으면 곧바로 멈춘다). 설정: OUTBOX_SOURCE가 source
    꼴이 아니면 ImproperlyConfigured(이름만).
    """
    assert issubclass(OutboxUsageError, Exception)
    assert not issubclass(OutboxUsageError, (ValueError, TypeError))
    head = "identity-admin.session."
    topic_249 = head + "a" * (249 - len("dev.") - len(head))
    topic_250 = topic_249 + "a"
    assert (len("dev." + topic_249), len("dev." + topic_250)) == (249, 250)
    topic_cases: list[tuple[str, object]] = [
        ("다른 pod", "portfolio-core.note.published"),
        ("dev. 접두", "dev.identity-admin.session.revoked"),
        ("대문자", "identity-admin.Session.revoked"),
        ("두 성분", "identity-admin.session"),
        ("끝 줄바꿈", TOPIC + LF),
        ("이름만 같은 다른 pod", "identity-admin-x.session.revoked"),
        ("접두 포함 250자", topic_250),
        ("str 아님", TOPIC.encode()),
    ]
    subject_cases: list[tuple[str, object]] = [
        ("콜론 없음", "user9f2c-test"),
        ("제어 문자 CR", "user:9f2c" + CR + "test"),
        ("끝 줄바꿈", SUBJECT + LF),
        ("종류 대문자", "User:9f2c-test"),
        ("str 아님", None),
    ]
    for label, topic in topic_cases:
        error, queries = _publish_rejected(topic, SUBJECT, dict(DATA), tenant_id=TENANT_A)
        assert queries == [], f"토픽 {label}: 테넌트 확정(⑤) 전에 막아야 한다"
        if isinstance(topic, str):
            assert topic not in str(error), f"토픽 {label}: 메시지에 값이 있다"
        _assert_clean(error, f"토픽 {label}")
    for label, subject in subject_cases:
        error, queries = _publish_rejected(TOPIC, subject, dict(DATA), tenant_id=TENANT_A)
        assert queries == [], f"subject {label}"
        if isinstance(subject, str):
            assert subject not in str(error), f"subject {label}: 메시지에 값이 있다"
        _assert_clean(error, f"subject {label}")
    probe: dict[str, Any] = {**DATA, "probe": SENTINEL}
    data_cases: list[tuple[str, object]] = [
        ("list", [probe]),
        ("str", json.dumps(probe)),
        ("tuple", (SENTINEL,)),
        ("None", None),
    ]
    for label, data in data_cases:
        error, queries = _publish_rejected(TOPIC, SUBJECT, data, tenant_id=TENANT_A)
        assert queries == [], f"data {label}"
        _assert_clean(error, f"data {label}")

    cyclic: dict[str, Any] = {"probe": SENTINEL}
    cyclic["self"] = cyclic
    loop: list[Any] = [SENTINEL]
    loop.append(loop)
    json_cases: list[tuple[str, object]] = [
        ("tuple", {**probe, "pair": (1, 2)}),
        ("datetime", {**probe, "at": datetime.now(UTC)}),
        ("UUID", {**probe, "tenant": TENANT_A}),
        ("Decimal", {**probe, "amount": Decimal("1.50")}),
        ("bytes", {**probe, "raw": SENTINEL.encode()}),
        ("set", {**probe, "tags": {SENTINEL}}),
        ("임의 객체", {**probe, "object": object()}),
        ("int 키", {**probe, 1: SENTINEL}),
        ("None 키", {**probe, None: SENTINEL}),
        ("bool 키", {**probe, True: SENTINEL}),
        ("중첩 int 키", {**probe, "nested": [{"inner": {2: SENTINEL}}]}),
        ("깊이 65(dict)", _nested_dicts(65)),
        ("깊이 65(list)", {"probe": SENTINEL, "lists": _nested_lists(64)}),
        ("NUL 값", {**probe, "text": SENTINEL + chr(0)}),
        ("NUL 키", {**probe, "key" + chr(0): SENTINEL}),
        ("중첩 NUL", {**probe, "nested": [[{"text": chr(0) + SENTINEL}]]}),
        ("float 1e16", {**probe, "x": 1e16}),
        ("float 1e300", {**probe, "x": [1e300]}),
        ("float -1e16", {**probe, "x": -1e16}),
        ("float 1e-05", {**probe, "x": 0.00001}),
        ("float 1.5e-07", {**probe, "x": 1.5e-07}),
        ("NaN", {**probe, "x": float("nan")}),
        ("inf", {**probe, "x": float("inf")}),
        ("-inf", {**probe, "x": float("-inf")}),
        ("순환 dict", cyclic),
        ("순환 list", {**probe, "loop": loop}),
        ("짝 없는 서로게이트", {**probe, "text": SENTINEL + chr(0xD800)}),
        ("4301자리 int", {**probe, "x": 10**4300}),
    ]
    for label, data in json_cases:
        started = time.monotonic()
        error, queries = _publish_rejected(TOPIC, SUBJECT, data, tenant_id=TENANT_A)
        assert time.monotonic() - started < 2, f"JSON {label}: 거부가 늦다"
        assert not any("INSERT" in sql.upper() for sql in queries), f"JSON {label}: INSERT가 나갔다"
        _assert_clean(error, f"JSON {label}")

    boundary_data: dict[str, Any] = {"floats": [1e15, -1e15, 0.0001, 123.456, 0.0], "flags": [True, False, None]}
    big_ints = {"ints": [10**3999 + index for index in range(200)]}  # 약 800 KB — 자릿수 하한이 실제보다 크면 거부된다
    with transaction.atomic():
        passing = [
            publish(TOPIC, SUBJECT, _nested_dicts(64), tenant_id=TENANT_A),
            publish(TOPIC, SUBJECT, {"probe": SENTINEL, "lists": _nested_lists(63)}, tenant_id=TENANT_A),
            publish(TOPIC, SUBJECT, boundary_data, tenant_id=TENANT_A),
            publish(TOPIC, SUBJECT, big_ints, tenant_id=TENANT_A),
        ]
    stored = owner_rows()
    assert set(stored) == {event.pk for event in passing}, "통과 경계(깊이 64 · 지수 없는 float)가 거부됐다"
    assert stored[passing[0].pk].payload["data"] == _nested_dicts(64)
    assert stored[passing[2].pk].payload["data"] == boundary_data
    owner_execute("DELETE FROM outbox")

    dag: Any = 0
    for _ in range(23):
        dag = [dag, dag]  # 펼치면 잎 2^23개 — 같은 list를 가리키므로 메모리는 작다
    started = time.monotonic()
    error, queries = _publish_rejected(TOPIC, SUBJECT, {"probe": SENTINEL, "dag": dag}, tenant_id=TENANT_A)
    elapsed = time.monotonic() - started
    assert elapsed < 2, f"공유 참조로 부푼 data의 거부에 {elapsed:.1f} s"
    assert not any("INSERT" in sql.upper() for sql in queries)
    _assert_clean(error, "공유 참조 list")
    shared_text = "x" * 100_000 + SENTINEL
    shared_int = 10**3999
    shared_cases: list[tuple[str, dict[str, Any]]] = [
        ("같은 100 KB str 100번", {"probe": SENTINEL, "texts": [shared_text] * 100}),
        ("같은 4000자리 int 2000번", {"probe": SENTINEL, "ints": [shared_int] * 2000}),
    ]
    for label, data in shared_cases:
        (error, queries), peak = _peak(
            lambda data=data: _publish_rejected(TOPIC, SUBJECT, data, tenant_id=TENANT_A)  # type: ignore[misc]
        )
        assert peak < PEAK_LIMIT, f"{label}: 거부 전에 {peak}바이트를 잡았다(크기 하한보다 직렬화를 먼저 했다)"
        assert not any("INSERT" in sql.upper() for sql in queries), label
        _assert_clean(error, label)

    base = _envelope_bytes(SUBJECT, {"probe": SENTINEL, "blob": ""})
    room = 900_000 - base
    blob = "가" * (room // 3) + "x" * (room % 3)
    data_ok = {"probe": SENTINEL, "blob": blob}
    data_over = {"probe": SENTINEL, "blob": blob + "x"}
    assert (_envelope_bytes(SUBJECT, data_ok), _envelope_bytes(SUBJECT, data_over)) == (900_000, 900_001)
    assert publisher.MAX_EVENT_BYTES == 900_000
    assert publisher.MAX_DATA_DEPTH == 64
    error, queries = _publish_rejected(TOPIC, SUBJECT, data_over, tenant_id=TENANT_A)
    assert not any("INSERT" in sql.upper() for sql in queries)
    _assert_clean(error, "크기 900,001")
    with transaction.atomic():
        long_topic = publish(topic_249, SUBJECT, dict(DATA), tenant_id=TENANT_A)
        largest = publish(TOPIC, SUBJECT, data_ok, tenant_id=TENANT_A)
    rows = owner_rows()
    expected_rows = {long_topic.pk, largest.pk}
    assert set(rows) == expected_rows, "통과해야 하는 경계 2(접두 포함 249자 토픽 · 900,000바이트)만 남아야 한다"
    assert rows[long_topic.pk].topic == topic_249
    assert rows[largest.pk].payload["data"] == data_ok
    assert owner_scalar("SELECT octet_length(payload::text) FROM outbox WHERE id = %s", [largest.pk]) == 900_000

    settings.OUTBOX_SOURCE = "Identity_Admin"
    with transaction.atomic(), pytest.raises(ImproperlyConfigured) as info:
        publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_A)
    assert "OUTBOX_SOURCE" in str(info.value)
    assert "Identity_Admin" not in str(info.value)
    settings.OUTBOX_SOURCE = SOURCE
    settings.OUTBOX_TOPIC_PREFIX = "prod."
    with transaction.atomic(), pytest.raises(ImproperlyConfigured) as info:
        publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_A)
    assert "OUTBOX_TOPIC_PREFIX" in str(info.value)
    assert set(owner_rows()) == expected_rows


def test_oc_4_tenant_normalization_and_broken_guc() -> None:
    """oc-4 — 테넌트 확정(D3 ⑤): UUID로 파싱되는 꼴(대문자 · 중괄호 · urn:uuid: · 하이픈 없음)은 소문자 8-4-4-4-12로 저장되고,
    컨텍스트와는 UUID 값으로 비교한다(대문자 인자 + 같은 컨텍스트 = 충돌 아님). int · bytes · 앞 공백은 OutboxUsageError. atomic 안
    GUC가 UUID 꼴이 아니면(set_config 'not-a-uuid') 인자가 있든 없든 OutboxUsageError다(ValueError가 아니다 · 메시지에 값 없음)."""
    canonical = str(TENANT_A)
    forms = [canonical.upper(), "{" + canonical + "}", "urn:uuid:" + canonical, TENANT_A.hex]
    with transaction.atomic():
        events = [publish(TOPIC, SUBJECT, dict(DATA), tenant_id=form) for form in forms]
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        events.append(publish(TOPIC, SUBJECT, dict(DATA), tenant_id=canonical.upper()))
    rows = owner_rows()
    assert set(rows) == {event.pk for event in events}
    for row in rows.values():
        assert row.partition_key == canonical
        assert row.payload["tenantid"] == canonical
    for bad in (TENANT_A.int, canonical.encode(), " " + canonical, canonical + LF):
        _publish_rejected(TOPIC, SUBJECT, dict(DATA), tenant_id=bad)
    for kwargs in ({}, {"tenant_id": TENANT_A}):
        with transaction.atomic():
            with connections["default"].cursor() as cursor:
                cursor.execute("SELECT set_config('app.tenant_id', %s, true)", ["not-a-uuid"])
            with pytest.raises(OutboxUsageError) as info:
                publish(TOPIC, SUBJECT, dict(DATA), **kwargs)
        assert "not-a-uuid" not in str(info.value)
    assert len(owner_rows()) == len(events)


def test_oc_5_publish_never_touches_kafka(settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-5 — publish는 Kafka에 닿지 않는다(D3 · 네트워크 I/O 0): confluent_kafka.Producer와 build_producer를 막아 두고
    KAFKA_BOOTSTRAP_SERVERS = ''(client_config가 거부하는 값)여도 성공한다."""
    import confluent_kafka

    def forbidden(*_args: object, **_kwargs: object) -> None:
        raise AssertionError("publish가 Kafka 프로듀서를 만들었다")

    settings.KAFKA_BOOTSTRAP_SERVERS = ""
    monkeypatch.setattr(confluent_kafka, "Producer", forbidden)
    monkeypatch.setattr(relay, "build_producer", forbidden)
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        event = publish(TOPIC, SUBJECT, dict(DATA))
    assert set(owner_rows()) == {event.pk}


def test_oc_21_size_measure_equals_postgres_jsonb_text() -> None:
    """oc-21 — 크기 측정(J2) = 릴레이가 보낼 바이트: 여러 꼴의 data로 publish한 행마다 publisher.jsonb_text(봉투)의 길이 ==
    PG octet_length(payload::text)다 — 표본 · 중첩 · 빈 컨테이너 · 한글 · 이모지(4바이트) · 이스케이프(따옴표 · 역슬래시 · 제어 문자
    1–31 · DEL · U+2028/2029 · NBSP) · 이스케이프가 필요한 키(빈 키 포함) · float(0.1 · 100.0 · 1e15 · 0.0001 ·
    0.30000000000000004 · -2.5 · 0.0) · bool · null · 긴 목록 · 4000자리 int · 깊이 64. PG는 키 순서를 바꾸지만(길이 → 바이트 순)
    길이는 같다. jsonb_text는 PG 꼴(쉼표 · 콜론 뒤 공백 · 비ASCII 그대로)의 UTF-8이다."""
    shapes: dict[str, dict[str, Any]] = {
        "표본": dict(DATA),
        "중첩 · 빈 컨테이너": {"a": {"b": [1, 2, {"c": None}]}, "empty_list": [], "empty_dict": {}, "both": [[], [{}]]},
        "한글 · 이모지": {"title": "이벤트 스키마 호환성", "emoji": chr(0x1F600), "mixed": "a가" + chr(0x1F680) + "b"},
        "이스케이프": {
            "quote": 'say "hi"',
            "backslash": "a" + chr(0x5C) + "b",
            "controls": "".join(chr(code) for code in range(1, 32)),
            "del": "x" + chr(0x7F) + "y",
            "separators": "a" + chr(0x2028) + "b" + chr(0x2029) + "c",
            "nbsp": "a" + chr(0xA0) + "b",
        },
        "키 이스케이프": {'k"q': 1, "k" + chr(0x5C): 2, "키": 3, "t" + chr(9): 4, "": 5},
        "float": {"values": [0.1, 100.0, 1e15, 0.0001, 0.30000000000000004, -2.5, 123456.789, 0.0]},
        "bool · null": {"t": True, "f": False, "n": None},
        "긴 목록": {"xs": list(range(2000)), "ys": ["s"] * 500},
        "큰 int": {"big": 10**3999, "neg": -(10**20), "zero": 0},
        "깊이 64": _nested_dicts(64),
    }
    with transaction.atomic():
        events = {label: publish(TOPIC, SUBJECT, data, tenant_id=TENANT_A) for label, data in shapes.items()}
    octets = {row_id: size for row_id, size in _owner_all("SELECT id, octet_length(payload::text) FROM outbox")}
    for label, event in events.items():
        measured = len(publisher.jsonb_text(event.payload))
        assert measured == octets[event.pk], f"{label}: 측정 {measured} ≠ PG {octets[event.pk]}"
    assert publisher.jsonb_text({"a": [1, {}], "b": "가"}) == '{"a": [1, {}], "b": "가"}'.encode()


def test_oc_30_wide_containers_are_rejected_without_buffering_their_children() -> None:
    """oc-30 — data 검사의 일시 메모리(K10): 순회는 컨테이너를 만나면 괄호와 구분자(`, ` × (원소 수 − 1))를 바이트 하한에 먼저 더해
    상한(900,000)과 비교하고, 자식은 한꺼번에 스택에 넣지 않고 차례로 꺼낸다. 그래서 넓은 컨테이너를 거부할 때 tracemalloc 정점이
    QUIET_PEAK(2,000,000) 아래다(입력은 측정 전에 만든다 · 각각 OutboxUsageError · INSERT 없음 · 메시지에 값 없음 · 연쇄 없음):
    정수 2,000,000개 list(구분자만으로 하한이 넘는다) · 키 1,000,000개 dict(같다) · 같은 0을 400,000번 담은 list(괄호 + 구분자 하한
    약 800,000은 상한 안이라 자식을 차례로 보다가 하한이 넘는다 — 구분자를 세지 않거나 0의 자릿수 하한이 0이면 순회를 끝내고 약
    1.2 MB를 직렬화한 뒤에야 거부하고, 자식을 한꺼번에 쌓으면 그 목록만 수 MB다) · 키 300,000개 dict(하한 약 600,000 — 항목을 차례로
    보다가 넘는다 · 항목을 한꺼번에 쌓으면 수십 MB) · 폭 200,000 list를 50번 가리키는 공유 참조. 받는 data의 집합은 그대로다 —
    하한은 실제 길이의 하한이다(900,000 경계 · 4000자리 int 200개 통과는 oc-3이 본다)."""
    shared_row = list(range(200_000))
    cases: list[tuple[str, dict[str, Any]]] = [
        ("정수 2,000,000개 list", {"probe": SENTINEL, "xs": list(range(2_000_000))}),
        ("키 1,000,000개 dict", {"probe": SENTINEL, "map": {f"k{index}": index for index in range(1_000_000)}}),
        ("같은 0을 400,000번", {"probe": SENTINEL, "zeros": [0] * 400_000}),
        ("키 300,000개 dict", {"probe": SENTINEL, "map": {f"k{index}": 0 for index in range(300_000)}}),
        ("폭 200,000 list 공유 50번", {"probe": SENTINEL, "rows": [shared_row] * 50}),
    ]
    for label, data in cases:
        (error, queries), peak = _peak(
            lambda data=data: _publish_rejected(TOPIC, SUBJECT, data, tenant_id=TENANT_A)  # type: ignore[misc]
        )
        assert peak < QUIET_PEAK, f"{label}: 거부 전에 {peak}바이트를 잡았다(자식을 한꺼번에 쌓았거나 직렬화를 먼저 했다)"
        assert not any("INSERT" in sql.upper() for sql in queries), label
        _assert_clean(error, label)
    assert owner_rows() == {}


# --- D10 ULID ------------------------------------------------------------------------------------------------------


def test_oc_6_ulid_shape_unique_monotonic(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-6 — new_ulid()(D10): Crockford 대문자 26자 · 첫 글자 0–7 · 1만 개 유일 · 생성 순서 = 정렬 순서(같은 ms가 실제로 있다) ·
    시각부 ≈ 지금. 시계가 뒤로 가면 직전 ms를 쓰고 난수부 +1(그래도 커진다) · 난수부가 넘치면 ms + 1(짝수 · 홀수 ms). 동시 호출의
    잠금(결정적 경합 — ms 고정 · randbits가 GIL을 놓는다): 네 스레드의 같은 ms 호출이 서로 다르다. 스레드 4개 대량(스위치 간격
    1 µs): 전체 유일 · 스레드마다 단조."""
    ids = [_ulid.new_ulid() for _ in range(10_000)]
    assert all(ULID_RE.fullmatch(value) for value in ids)
    assert len(set(ids)) == len(ids)
    assert ids == sorted(ids)
    assert any(a[:10] == b[:10] for a, b in zip(ids, ids[1:], strict=False)), "같은 ms에 난 id가 없다(시험이 공허하다)"
    now_ms = time.time_ns() // 1_000_000
    assert abs(_ulid_ms(ids[-1]) - now_ms) < 5_000

    future_ms = now_ms + 2_000  # 앞선 호출들보다 확실히 뒤(상태가 이 시각에 머무는 것은 약 2 s뿐) — 이 시험이 시계를 쥔다
    with monkeypatch.context() as patch:
        patch.setattr(time, "time_ns", lambda: future_ms * 1_000_000)
        first = _ulid.new_ulid()
        patch.setattr(time, "time_ns", lambda: (future_ms - 5) * 1_000_000)  # 5 ms 역행
        second = _ulid.new_ulid()
    assert _ulid_ms(first) == future_ms
    assert second > first
    assert _ulid_ms(second) == future_ms

    for later_ms in (future_ms + 10, future_ms + 21):  # 짝수 · 홀수 ms 둘 다(넘침을 비트 OR로 흘리는 꼴은 한쪽에서만 맞는다)
        with monkeypatch.context() as patch:
            patch.setattr(time, "time_ns", lambda later_ms=later_ms: later_ms * 1_000_000)
            patch.setattr(_ulid.secrets, "randbits", lambda bits: (1 << bits) - 1)
            top = _ulid.new_ulid()
            overflow = _ulid.new_ulid()
        assert _ulid_ms(top) == later_ms
        assert top.endswith("Z" * 16)
        assert overflow > top
        assert _ulid_ms(overflow) == later_ms + 1

    # 결정적 경합: 스위치 간격만으로는 임계 구역 안의 교차가 드물다(잠금을 뺀 꼴이 대량 시험을 통과했다 — 변이 D10-2). ms를
    # 고정하고 randbits가 50 ms 동안 GIL을 놓게 하면, 잠금이 없을 때 네 스레드가 모두 「새 ms」 갈래에서 같은 (ms, 난수)를 낸다.
    # 잠금이 있으면 첫 스레드만 그 갈래이고 나머지는 같은 ms의 난수부 +1이다.
    contention_ms = future_ms + 100

    def yielding_randbits(bits: int) -> int:
        time.sleep(0.05)
        return 12345

    racers: list[str] = []
    racers_lock = threading.Lock()
    start = threading.Barrier(4)

    def racer() -> None:
        start.wait(timeout=30)
        value = _ulid.new_ulid()
        with racers_lock:
            racers.append(value)

    with monkeypatch.context() as patch:
        patch.setattr(time, "time_ns", lambda: contention_ms * 1_000_000)
        patch.setattr(_ulid.secrets, "randbits", yielding_randbits)
        racer_threads = [threading.Thread(target=racer, daemon=True) for _ in range(4)]
        for thread in racer_threads:
            thread.start()
        for thread in racer_threads:
            thread.join(timeout=30)
    assert len(racers) == 4
    assert len(set(racers)) == 4, "같은 ms의 동시 호출이 같은 ULID를 냈다(잠금 없음)"
    assert all(_ulid_ms(value) == contention_ms for value in racers)

    results: list[list[str]] = [[] for _ in range(4)]
    barrier = threading.Barrier(len(results))

    def worker(slot: int) -> None:
        barrier.wait(timeout=30)
        out = results[slot]
        for _ in range(20_000):
            out.append(_ulid.new_ulid())

    interval = sys.getswitchinterval()
    sys.setswitchinterval(1e-6)
    try:
        threads = [threading.Thread(target=worker, args=(slot,), daemon=True) for slot in range(len(results))]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=120)
    finally:
        sys.setswitchinterval(interval)
    assert not any(thread.is_alive() for thread in threads)
    merged = [value for out in results for value in out]
    assert len(merged) == 80_000
    assert len(set(merged)) == len(merged), "스레드 사이에 같은 ULID가 났다"
    for out in results:
        assert out == sorted(out)


# --- D4 · J3–J5 relay_once -----------------------------------------------------------------------------------------


def test_oc_7_message_shape_order_limit_and_prod_prefix(settings: SettingsWrapper) -> None:
    """oc-7 — 메시지 모양(D4 ④ · ⑥ · J3): Kafka 토픽 = 접두 + 행 topic · key = partition_key(UTF-8) · 헤더 이름 순서
    ce_type · ce_source · ce_id · content-type(중복 없음 · 값 bytes) · value = 저장된 봉투의 PG jsonb 텍스트(payload::text의
    UTF-8 — 한글 그대로 · 키 순서와 공백은 PG의 것) · flush 한 번(35 s) · purge 없음. ORDER BY id + LIMIT batch_size. DLQ 메시지:
    같은 key · value · 헤더 넷 + error(= 행 last_error). prod 접두 ""(설정을 호출 시점에 읽는다): 토픽 = 논리 토픽 · DLQ =
    `<source>.dlq` · OUTBOX_MAX_ATTEMPTS 1이면 첫 실패가 DLQ다."""
    with transaction.atomic():
        set_tenant("default", TENANT_A)
        event_a = publish(TOPIC, "user:9f2c-테스트", dict(DATA))
    with transaction.atomic():
        event_b = publish(TOPIC, SUBJECT, dict(DATA), tenant_id=TENANT_B)
    stored = owner_rows()
    texts = _owner_texts()
    fake = ScriptedProducer()
    assert relay_once(producer=fake) == RelayResult(published=2, failed=0, dead=0)
    assert [sent.row_id() for sent in fake.sent] == sorted([event_a.pk, event_b.pk])
    for sent in fake.sent:
        row = stored[sent.row_id() or ""]
        assert sent.topic == KAFKA_TOPIC
        assert sent.key == row.partition_key.encode()
        assert sent.header_names() == list(MAIN_HEADERS)
        headers = {"ce_type": TOPIC, "ce_source": SOURCE, "ce_id": row.pk, "content-type": CONTENT_TYPE}
        assert sent.header_map() == headers
        assert sent.value == texts[row.pk].encode("utf-8")
        assert sent.envelope() == row.payload
    assert "테스트".encode() in b"".join(sent.value for sent in fake.sent if isinstance(sent.value, bytes))
    assert fake.flush_calls == [relay.FLUSH_TIMEOUT_S]
    assert relay.FLUSH_TIMEOUT_S == 35
    assert fake.purge_calls == []
    assert owner_rows() == {}

    events = seed(5)
    fake = ScriptedProducer()
    assert relay_once(producer=fake, batch_size=2) == RelayResult(published=2, failed=0, dead=0)
    ordered = sorted(event.pk for event in events)
    assert [sent.row_id() for sent in fake.sent] == ordered[:2]
    assert set(owner_rows()) == set(ordered[2:])
    owner_execute("DELETE FROM outbox")

    (dead_event,) = seed(1, TENANT_B)
    dead_text = _owner_texts()[dead_event.pk]
    fake = ScriptedProducer(decide=fail_topics(KAFKA_TOPIC))
    results = _drive(fake, MAX_ATTEMPTS)
    assert results[-1] == RelayResult(published=0, failed=0, dead=1)
    row = owner_rows()[dead_event.pk]
    (dlq,) = [sent for sent in fake.sent if sent.topic == DLQ_TOPIC]
    assert dlq.key == str(TENANT_B).encode()
    assert dlq.header_names() == list(DLQ_HEADERS)
    assert dlq.header_map() == {
        "ce_type": TOPIC,
        "ce_source": SOURCE,
        "ce_id": row.pk,
        "content-type": CONTENT_TYPE,
        "error": row.last_error,
    }
    assert dlq.value == dead_text.encode("utf-8")
    assert fake.flush_calls[-2:] == [relay.FLUSH_TIMEOUT_S, relay.FLUSH_TIMEOUT_S]  # 마지막 패스 = 메인 + DLQ 두 단계
    owner_execute("DELETE FROM outbox")

    settings.OUTBOX_TOPIC_PREFIX = ""
    settings.OUTBOX_MAX_ATTEMPTS = 1
    seed(1)
    fake = ScriptedProducer(decide=fail_topics(TOPIC))
    assert relay_once(producer=fake) == RelayResult(published=0, failed=0, dead=1)
    assert [sent.topic for sent in fake.sent] == [TOPIC, f"{SOURCE}.dlq"]


def test_oc_8_flush_leftovers_are_purged_and_counted_as_failures() -> None:
    """oc-8 — flush 잔여(D4 ⑤): 대역 flush가 남은 수(> 0)를 돌려주면 purge(in_queue=True, in_flight=True) 뒤 flush(5)로
    _PURGE_QUEUE DR을 받고 그 행은 실패(attempts 1 · dead 아님)다. 같은 배치의 다른 행은 발행된다 · 멈추지 않는다 · 다음 패스에
    지난 배치가 새지 않는다. purge 뒤에도 DR이 없으면 그 행의 last_error는 「delivery 결과 없음」이다."""
    events = seed(2)
    held_id = min(event.pk for event in events)
    fake = ScriptedProducer(decide=lambda sent: HOLD if sent.row_id() == held_id else None)
    assert relay_once(producer=fake) == RelayResult(published=1, failed=1, dead=0)
    assert relay.PURGE_FLUSH_TIMEOUT_S == 5
    assert fake.flush_calls == [relay.FLUSH_TIMEOUT_S, relay.PURGE_FLUSH_TIMEOUT_S]
    assert fake.purge_calls == [(True, True)]
    row = owner_rows()[held_id]
    assert (row.attempts, row.dead_at) == (1, None)
    assert row.last_error is not None and "_PURGE_QUEUE" in row.last_error

    fake.decide = lambda _sent: None
    assert relay_once(producer=fake) == RelayResult(published=1, failed=0, dead=0)
    assert owner_rows() == {}

    (silent,) = seed(1)
    fake = ScriptedProducer(decide=lambda _sent: HOLD, purge_reports=False)
    assert relay_once(producer=fake) == RelayResult(published=0, failed=1, dead=0)
    row = owner_rows()[silent.pk]
    assert row.attempts == 1
    assert row.last_error == NO_RESULT


def test_oc_8b_real_producer_unreachable_broker_converges(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-8b — 실 Producer(build_producer — 멱등 · PLAINTEXT)가 닫힌 포트에 붙고 FLUSH_TIMEOUT_S를 1로 줄이면 relay_once()가
    10 s 안에 RelayResult(0, 1, 0)으로 끝난다(purge 경로 실측 — 큐에 남은 메시지를 purge하고 _PURGE_QUEUE DR을 받는다)."""
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{_closed_port()}"
    settings.KAFKA_CLIENT_CONFIG = {"security.protocol": "PLAINTEXT"}
    monkeypatch.setattr(relay, "FLUSH_TIMEOUT_S", 1)
    (event,) = seed(1)
    started = time.monotonic()
    result = relay_once()
    elapsed = time.monotonic() - started
    assert result == RelayResult(published=0, failed=1, dead=0)
    assert elapsed < 10, f"수렴에 {elapsed:.1f} s"
    row = owner_rows()[event.pk]
    assert row.attempts == 1
    assert row.last_error is not None and ("_PURGE" in row.last_error or row.last_error == NO_RESULT)


def test_oc_9_dlq_failure_keeps_row_and_next_pass_tries_main_first() -> None:
    """oc-9 — DLQ 실패(D4 ⑥ · ⑦): 메인 · DLQ 둘 다 실패하면 10번째 패스는 RelayResult(0, 1, 0) · attempts 10 · dead_at NULL ·
    last_error = DLQ 오류. 다음 패스는 메인부터 시도한다(또 실패하면 DLQ — attempts 11). 메인이 성공하면 삭제(DLQ 호출 없음),
    메인 실패 · DLQ 성공이면 dead다."""
    (first,) = seed(1)
    both_down = ScriptedProducer(
        decide=lambda sent: Fail("main down") if sent.topic == KAFKA_TOPIC else Fail("dlq down")
    )
    results = _drive(both_down, MAX_ATTEMPTS)
    assert results == [RelayResult(published=0, failed=1, dead=0)] * MAX_ATTEMPTS
    row = owner_rows()[first.pk]
    assert (row.attempts, row.dead_at) == (MAX_ATTEMPTS, None)
    assert row.last_error is not None and "dlq down" in row.last_error
    assert [sent.topic for sent in both_down.sent] == [KAFKA_TOPIC] * MAX_ATTEMPTS + [DLQ_TOPIC]
    assert relay_once(producer=both_down) == RelayResult(published=0, failed=1, dead=0)
    assert [sent.topic for sent in both_down.sent][-2:] == [KAFKA_TOPIC, DLQ_TOPIC]
    assert owner_rows()[first.pk].attempts == MAX_ATTEMPTS + 1

    recovered = ScriptedProducer()
    assert relay_once(producer=recovered) == RelayResult(published=1, failed=0, dead=0)
    assert [sent.topic for sent in recovered.sent] == [KAFKA_TOPIC]
    assert owner_rows() == {}

    (second,) = seed(1)
    _drive(both_down, MAX_ATTEMPTS)
    main_down = ScriptedProducer(decide=fail_topics(KAFKA_TOPIC))
    assert relay_once(producer=main_down) == RelayResult(published=0, failed=0, dead=1)
    assert [sent.topic for sent in main_down.sent] == [KAFKA_TOPIC, DLQ_TOPIC]
    row = owner_rows()[second.pk]
    assert row.attempts == MAX_ATTEMPTS + 1
    assert row.dead_at is not None


def test_oc_10_last_error_keeps_first_1000_chars() -> None:
    """oc-10 — last_error 상한(D4 ⑦): 5000자 오류 → str(err)의 앞 1000자(앞부분 보존 · 뒤 꼬리 없음). DLQ error 헤더도 같은
    1000자다."""
    reason = "HEAD-" + "y" * 4990 + "-TAIL"
    assert len(reason) == 5000
    (event,) = seed(1)
    fake = ScriptedProducer(decide=fail_topics(KAFKA_TOPIC, reason=reason))
    assert relay_once(producer=fake) == RelayResult(published=0, failed=1, dead=0)
    row = owner_rows()[event.pk]
    expected = str(KafkaError(KafkaError._MSG_TIMED_OUT, reason))[:1000]
    assert relay.LAST_ERROR_MAX == 1000
    assert row.last_error == expected
    assert "HEAD-" in expected and "-TAIL" not in expected
    _drive(fake, MAX_ATTEMPTS - 1)
    row = owner_rows()[event.pk]
    assert row.dead_at is not None
    (dlq,) = [sent for sent in fake.sent if sent.topic == DLQ_TOPIC]
    assert dlq.header_map()["error"] == row.last_error == expected


def test_oc_11_immediate_produce_exceptions() -> None:
    """oc-11 — produce 즉시 예외(D4 ④): BufferError · KafkaException인 행은 실패(attempts 1 · last_error = 예외 문자열)이고 같은
    배치의 다른 행은 발행된다. 그 밖의 예외는 relay_once 밖으로 올라가고 트랜잭션은 롤백된다(행 · attempts 그대로 — 명령은 로그 +
    백오프 · oc-15d)."""
    events = seed(4)
    ids = sorted(event.pk for event in events)
    queue_full = BufferError("Local: Queue full")
    too_large = KafkaException(
        KafkaError(KafkaError.MSG_SIZE_TOO_LARGE, "Unable to produce message: Broker: Message size too large")
    )
    outcomes: dict[str | None, BaseException] = {ids[0]: queue_full, ids[1]: too_large}
    fake = ScriptedProducer(decide=lambda sent: outcomes.get(sent.row_id()))
    assert relay_once(producer=fake) == RelayResult(published=2, failed=2, dead=0)
    rows = owner_rows()
    assert set(rows) == {ids[0], ids[1]}
    assert (rows[ids[0]].attempts, rows[ids[0]].last_error) == (1, str(queue_full))
    assert rows[ids[1]].attempts == 1
    assert rows[ids[1]].last_error is not None and "MSG_SIZE_TOO_LARGE" in rows[ids[1]].last_error

    crash = ScriptedProducer(decide=lambda _sent: RuntimeError("relay bug"))
    with pytest.raises(RuntimeError):
        relay_once(producer=crash)
    after = owner_rows()
    assert {pk: (row.attempts, row.last_error) for pk, row in after.items()} == {
        pk: (row.attempts, row.last_error) for pk, row in rows.items()
    }


def test_oc_12_durable_pass_and_set_local_idle_timeout() -> None:
    """oc-12 — 한 패스 = atomic(durable=True) 하나(D4 ②): produce 안에서 같은 연결의 SHOW idle_in_transaction_session_timeout이
    2min(SET LOCAL '120s' · 이 트랜잭션에만)이고, 끝난 뒤 세션 값은 원래대로다. 다른 atomic 안에서 부르면 RuntimeError다."""

    def show() -> str:
        with connections["default"].cursor() as cursor:
            cursor.execute("SHOW idle_in_transaction_session_timeout")
            (value,) = cursor.fetchone()
        return str(value)

    seed(1)
    before = show()
    assert before != "2min"
    seen: list[str] = []
    fake = ScriptedProducer(on_produce=lambda _sent: seen.append(show()))
    assert relay_once(producer=fake) == RelayResult(published=1, failed=0, dead=0)
    assert seen == ["2min"]
    assert show() == before
    seed(1)
    with transaction.atomic(), pytest.raises(RuntimeError):
        relay_once(producer=ScriptedProducer())
    assert len(owner_rows()) == 1


def test_oc_22_relay_sends_stored_jsonb_text_without_python_decoding() -> None:
    """oc-22 — 릴레이 value = payload::text(J3 — Python 해석 · 재직렬화 0): owner가 손으로 넣은 행(data에 5000자리 정수 — Python
    json.loads는 ValueError · numeric 1.50 · 2.0E+3)도 릴레이를 멈추지 못하고 PG 텍스트 바이트 그대로 나간다 · 같은 배치의 publish
    행도 발행된다. 헤더는 행의 열과 설정에서 만든다(ce_id = 행 id · ce_type = 행 topic).

    성공 삭제는 신호 없는 직접 DELETE다(K7): sender 없는 pre_delete · post_delete 수신기를 단 채로도 수신기 호출 0 · 행 payload
    열을 그대로 읽는 SELECT 0(Collector는 지울 행을 먼저 읽어 json.loads한다 — 손 행이면 ValueError로 패스가 롤백되고 재발송이
    반복된다) · 이 패스의 DELETE 문은 하나다."""
    (normal,) = seed(1)
    hand_id = _ulid.new_ulid()
    digits = "9" * 5000
    hand_text = (
        '{"specversion": "1.0", "id": "' + hand_id + '", "source": "' + SOURCE + '", "type": "' + TOPIC + '", '
        '"time": "2026-11-04T00:00:00.000Z", "subject": "user:hand", "tenantid": "' + str(TENANT_A) + '", '
        '"datacontenttype": "application/json", "data": {"big": ' + digits + ', "amount": 1.50, "exp": 2.0E+3}}'
    )
    _hand_insert(hand_id, hand_text)
    texts = _owner_texts()
    assert digits in texts[hand_id] and '"amount": 1.50' in texts[hand_id]
    fake = ScriptedProducer()
    with _delete_receivers() as signals, CaptureQueriesContext(connections["default"]) as queries:
        assert relay_once(producer=fake) == RelayResult(published=2, failed=0, dead=0)
    assert signals == [], "삭제 신호가 나갔다(Django Collector 경유)"
    statements = _sql(queries)
    assert not [sql for sql in statements if BARE_PAYLOAD.search(sql)], "지울 행의 payload 열을 읽었다"
    assert len([sql for sql in statements if sql.lstrip().upper().startswith("DELETE")]) == 1
    by_id = {sent.row_id(): sent for sent in fake.sent}
    assert set(by_id) == {normal.pk, hand_id}
    assert by_id[normal.pk].value == texts[normal.pk].encode("utf-8")
    assert by_id[hand_id].value == texts[hand_id].encode("utf-8")
    assert by_id[hand_id].header_map() == {
        "ce_type": TOPIC,
        "ce_source": SOURCE,
        "ce_id": hand_id,
        "content-type": CONTENT_TYPE,
    }
    with pytest.raises(ValueError):
        json.loads(by_id[hand_id].value)  # Python으로는 해석조차 못 한다(정수 문자열 4300자리 한도)
    assert _owner_ids() == set()


def test_oc_23_byte_budget_selects_leading_rows() -> None:
    """oc-23 — 바이트 예산(J4 · 계약 §outbox 릴레이 「선택」): 행마다 octet_length(payload::text)를 잠근 뒤 누적이 batch_bytes 안인
    앞부분(최소 1행)만 읽어 보낸다.

    400 KB 봉투 3행 + batch_bytes 1 MiB → 첫 패스 2행 · 둘째 1행. 첫 패스에서 잠갔지만 고르지 않은 셋째 행은 produce 0 · attempts ·
    last_error 그대로이고 어느 쿼리도 그 id를 쓰지 않는다. 경계: 누적 = 예산이면 들어가고 1 바이트 모자라면 빠진다. 예산보다 큰 행
    하나는 혼자 간다(예산을 크기 상한 900,000보다 작게 준 호출에서만 생긴다 — 상한을 넘는 행은 아예 잠기지 않는다 · oc-28). 큰 행
    10개(손으로 넣은 850,000바이트 — 상한 안)에서 고르지 않은 행의 payload는 읽지 않는다(tracemalloc 정점 < PEAK_LIMIT 6,000,000
    바이트 — 한 행을 읽으면 str · bytes 두 사본으로 약 1.7 MB, 열 행을 다 읽으면 약 17 MB). truncated(RelayResult의 비교 밖 필드)는
    잘린 패스(바이트 예산 · 행 수 LIMIT)에서 참이고 그 밖은 거짓 — RelayResult 비교는 셋만 본다(T061). 기본값
    relay.RELAY_BATCH_BYTES = 8 MiB(키워드 전용)."""
    assert relay.RELAY_BATCH_BYTES == 8 * MIB
    parameter = inspect.signature(relay_once).parameters["batch_bytes"]
    assert parameter.kind is inspect.Parameter.KEYWORD_ONLY
    assert parameter.default == relay.RELAY_BATCH_BYTES
    assert RelayResult(1, 0, 0, truncated=True) == RelayResult(1, 0, 0)

    def seed_large(count: int) -> list[str]:
        with transaction.atomic():
            events = [publish(TOPIC, SUBJECT, {"blob": "x" * 400_000}, tenant_id=TENANT_A) for _ in range(count)]
        return sorted(event.pk for event in events)

    ids = seed_large(3)
    sizes = {row_id: size for row_id, size in _owner_all("SELECT id, octet_length(payload::text) FROM outbox")}
    assert all(400_000 < sizes[row_id] < 401_000 for row_id in ids)
    fake = ScriptedProducer()
    with CaptureQueriesContext(connections["default"]) as queries:
        first = relay_once(producer=fake, batch_bytes=MIB)
    assert first == RelayResult(published=2, failed=0, dead=0)
    assert first.truncated is True
    assert [sent.row_id() for sent in fake.sent] == ids[:2]
    assert _owner_all("SELECT attempts, last_error FROM outbox WHERE id = %s", (ids[2],)) == [(0, None)]
    assert any(ids[0] in query["sql"] for query in queries.captured_queries), "쿼리 기록에 id가 없다(단언이 공허하다)"
    assert not any(ids[2] in query["sql"] for query in queries.captured_queries), "고르지 않은 행을 쿼리가 건드렸다"
    second = relay_once(producer=fake, batch_bytes=MIB)
    assert second == RelayResult(published=1, failed=0, dead=0)
    assert second.truncated is False
    assert [sent.row_id() for sent in fake.sent] == ids

    ids = seed_large(3)
    sizes = {row_id: size for row_id, size in _owner_all("SELECT id, octet_length(payload::text) FROM outbox")}
    fake = ScriptedProducer()
    short = relay_once(producer=fake, batch_bytes=sizes[ids[0]] + sizes[ids[1]] - 1)
    assert (short, short.truncated) == (RelayResult(published=1, failed=0, dead=0), True)
    exact = relay_once(producer=fake, batch_bytes=sizes[ids[1]] + sizes[ids[2]])
    assert (exact, exact.truncated) == (RelayResult(published=2, failed=0, dead=0), False)
    assert [sent.row_id() for sent in fake.sent] == ids

    ids = seed_large(2)
    fake = ScriptedProducer()
    alone = relay_once(producer=fake, batch_bytes=100_000)
    assert (alone, alone.truncated) == (RelayResult(published=1, failed=0, dead=0), True)
    last = relay_once(producer=fake, batch_bytes=100_000)
    assert (last, last.truncated) == (RelayResult(published=1, failed=0, dead=0), False)
    assert [sent.row_id() for sent in fake.sent] == ids

    seed(3)
    fake = ScriptedProducer()
    counted = relay_once(producer=fake, batch_size=2)
    assert (counted, counted.truncated) == (RelayResult(published=2, failed=0, dead=0), True)
    rest = relay_once(producer=fake, batch_size=2)
    assert (rest, rest.truncated) == (RelayResult(published=1, failed=0, dead=0), False)
    empty = relay_once(producer=fake, batch_size=2)
    assert (empty, empty.truncated) == (RelayResult(published=0, failed=0, dead=0), False)

    big_ids = []
    for _ in range(10):
        row_id = _ulid.new_ulid()
        _hand_insert_sized(row_id, 850_000)
        big_ids.append(row_id)
    fake = ScriptedProducer()
    big, peak = _peak(lambda: relay_once(producer=fake, batch_bytes=MIB))
    assert (big, big.truncated) == (RelayResult(published=1, failed=0, dead=0), True)
    assert [sent.row_id() for sent in fake.sent] == big_ids[:1]
    assert peak < PEAK_LIMIT, f"정점 {peak}바이트 — 고르지 않은 행의 payload까지 읽었다"


def test_oc_24_fatal_producer_commits_then_signals_rebuild(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-24 — 프로듀서 치명 오류(J5 · K12 · L6): produce가 곧바로 낸 KafkaException(KafkaError(_FATAL, fatal=True)) · DR 오류의
    fatal()(코드가 _FATAL이 아니어도) · 코드가 _FATAL인 DR 오류(fatal 표시가 없어도)면 relay_once는 그 패스를 평소대로 반영 ·
    커밋한 뒤 relay.ProducerFatalError(.result = 이 패스의 RelayResult · .error_name = 치명 오류의 KafkaError 이름 · 메시지에 값
    없음)를 올린다 — 같은 패스의 다른 행은 발행 · 삭제되고 치명 행은 attempts 1(오류 본문은 last_error에만)이다. 메인 단계에서
    치명이 서면 DLQ 단계를 건너뛴다(L6 — 같은 프로듀서로는 실패가 뻔하고 DLQ 오류가 메인 오류를 덮는다): 같은 패스에서 메인이
    비치명으로 실패한 attempts = MAX−1 행은 DLQ로 가지 않고 attempts MAX · dead_at NULL · last_error = 메인 오류다. 치명이 아닌
    실패는 올리지 않는다(oc-7..11). DLQ 단계의 치명(K12): attempts = MAX−1 행이 메인에서 실패하고 DLQ DR이 치명이면
    ProducerFatalError(.result = (0, 1, 0)) · attempts MAX · dead_at NULL · last_error = DLQ 오류다. 명령은 그 예외에서 로그(이벤트
    이름 · 클래스 · 값 없는 진단 필드 kafka_error=<이름> · 개수) + 백오프 뒤 프로듀서를 버리고 다음 반복에 build_producer()로 새로
    만든다 — 새 프로듀서가 보낼 때 행의 attempts는 이미 커밋돼 있다(커밋 뒤 재생성)."""

    def fatal_produce() -> KafkaException:
        return KafkaException(KafkaError(KafkaError._FATAL, f"producer fenced {SENTINEL}", fatal=True))

    authorization = KafkaError.CLUSTER_AUTHORIZATION_FAILED
    outcomes: list[tuple[str, Callable[[], object], str]] = [
        ("produce 예외", fatal_produce, "_FATAL"),
        (
            "DR fatal()",
            lambda: Fail(f"cluster auth {SENTINEL}", code=authorization, fatal=True),
            "CLUSTER_AUTHORIZATION_FAILED",
        ),
        ("DR 코드 _FATAL", lambda: Fail(f"fatal {SENTINEL}", code=KafkaError._FATAL), "_FATAL"),
    ]
    for label, outcome, name in outcomes:
        ids = sorted(event.pk for event in seed(4))
        owner_execute("UPDATE outbox SET attempts = %s WHERE id = %s", [MAX_ATTEMPTS - 1, ids[3]])

        def decide(
            sent: Any, target: str = ids[1], last: str = ids[3], outcome: Callable[[], object] = outcome
        ) -> object:
            if sent.row_id() == target:
                return outcome()
            if sent.row_id() == last and sent.topic == KAFKA_TOPIC:
                return Fail(f"main down {SENTINEL}")
            return None  # DLQ로 보냈다면 성공했을 것이다(건너뛰지 않은 꼴은 dead 1로 드러난다)

        fake = ScriptedProducer(decide=decide)
        with pytest.raises(relay.ProducerFatalError) as info:
            relay_once(producer=fake)
        assert info.value.result == RelayResult(published=2, failed=2, dead=0), label
        assert info.value.error_name == name, label
        assert SENTINEL not in str(info.value), label
        assert [sent.topic for sent in fake.calls] == [KAFKA_TOPIC] * 4, f"{label}: 메인 단계 치명 뒤 DLQ 단계를 돌았다"
        rows = owner_rows()
        assert set(rows) == {ids[1], ids[3]}, label
        assert rows[ids[1]].attempts == 1, label
        assert rows[ids[1]].last_error is not None and SENTINEL in rows[ids[1]].last_error, label
        assert (rows[ids[3]].attempts, rows[ids[3]].dead_at) == (MAX_ATTEMPTS, None), label
        assert rows[ids[3]].last_error is not None and "main down" in rows[ids[3]].last_error, label
        owner_execute("DELETE FROM outbox")

    def rebuild_run(
        first: ScriptedProducer, second: ScriptedProducer, iterations: int
    ) -> tuple[list[object], list[float]]:
        built: list[object] = []

        def build() -> ScriptedProducer:
            producer = (first, second)[len(built)]
            built.append(producer)
            return producer

        monkeypatch.setattr(relay, "build_producer", build)
        waits = _record_waits(monkeypatch)
        with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
            call_command(
                "outbox_relay", "--iterations", str(iterations), "--metrics-port", "0", "--poll-interval", "0.5"
            )
        return built, waits

    def attempts_seen(sink: list[int]) -> Callable[[Any], None]:
        return lambda sent: sink.append(owner_scalar("SELECT attempts FROM outbox WHERE id = %s", [sent.row_id()]))

    events = seed(2)
    seen_attempts: list[int] = []
    first = ScriptedProducer(decide=lambda _sent: fatal_produce())
    second = ScriptedProducer(on_produce=attempts_seen(seen_attempts))
    built, waits = rebuild_run(first, second, 3)
    assert built == [first, second]
    assert seen_attempts == [1, 1], "치명 패스의 attempts가 커밋되기 전에 새 프로듀서가 보냈다"
    assert sorted(sent.row_id() or "" for sent in second.sent) == sorted(event.pk for event in events)
    assert owner_rows() == {}
    assert waits == [1.0, 0.5]  # 치명 = 백오프 · 다음 패스는 진전
    assert "outbox_relay.producer_fatal ProducerFatalError kafka_error=_FATAL published=0 failed=2 dead=0" in (
        _relay_lines(caplog)
    )
    assert SENTINEL not in caplog.text

    def dlq_fatal(sent: Any) -> object:
        if sent.topic == KAFKA_TOPIC:
            return Fail("main down")
        return Fail(f"dlq denied {SENTINEL}", code=authorization, fatal=True)

    (last,) = seed(1)
    owner_execute("UPDATE outbox SET attempts = %s WHERE id = %s", [MAX_ATTEMPTS - 1, last.pk])
    fake = ScriptedProducer(decide=dlq_fatal)
    with pytest.raises(relay.ProducerFatalError) as info:
        relay_once(producer=fake)
    assert info.value.result == RelayResult(published=0, failed=1, dead=0)
    assert info.value.error_name == "CLUSTER_AUTHORIZATION_FAILED"
    assert [sent.topic for sent in fake.sent] == [KAFKA_TOPIC, DLQ_TOPIC]
    stored = owner_rows()[last.pk]
    assert (stored.attempts, stored.dead_at) == (MAX_ATTEMPTS, None)
    assert stored.last_error is not None and "dlq denied" in stored.last_error, "last_error는 DLQ 오류여야 한다"

    caplog.clear()
    seen_attempts = []
    first = ScriptedProducer(decide=dlq_fatal)
    second = ScriptedProducer(on_produce=attempts_seen(seen_attempts))
    built, waits = rebuild_run(first, second, 2)
    assert built == [first, second], "DLQ 단계의 치명 오류 뒤에 프로듀서를 다시 만들지 않았다"
    assert [sent.topic for sent in first.sent] == [KAFKA_TOPIC, DLQ_TOPIC]
    assert seen_attempts == [MAX_ATTEMPTS + 1]
    assert [sent.topic for sent in second.sent] == [KAFKA_TOPIC]  # dead_at NULL — 메인부터
    assert owner_rows() == {}
    assert waits == [1.0]
    assert (
        "outbox_relay.producer_fatal ProducerFatalError kafka_error=CLUSTER_AUTHORIZATION_FAILED"
        " published=0 failed=1 dead=0"
    ) in _relay_lines(caplog)
    assert SENTINEL not in caplog.text


def test_oc_28_rows_over_the_size_limit_are_never_locked_read_or_sent(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-28 — 크기 상한(K5 · 계약 §outbox 릴레이 「선택」): 잠금 쿼리 ①의 조건에 octet_length(payload::text) <= MAX_EVENT_BYTES
    (900,000 — publish ⑦과 같은 수 · 같은 측정)가 들어간다. 그래서 상한을 넘는 행(손으로 넣은 행뿐이다)은 잠그지도 · 읽지도 ·
    보내지도 · 고치지도 않는다.

    머리(가장 작은 id)에 손으로 넣은 900,001바이트 행 + publish 행 2 → 첫 패스에 publish 행 둘만 발행(RelayResult(2, 0, 0) · 잘림
    아님) · 패스 동안 손 행은 잠기지 않았다(owner의 FOR UPDATE NOWAIT가 성공한다) · 어느 쿼리도 손 행 id를 쓰지 않는다 · 잠금
    쿼리에 크기 조건이 있다 · 손 행은 attempts 0 · last_error · dead_at NULL 그대로. 손 행만 남은 패스는 RelayResult(0, 0, 0)이고
    (실패로 세지 않는다 · produce 0), 명령의 대기는 폴링 간격 그대로다(진전 없음 백오프로 자라지 않는다 — 그 뒤 새 이벤트가 늦지
    않는다). 그 행은 pending으로 남아 지표에 보인다(명령의 refresh 뒤 outbox_pending 1 · outbox_oldest_pending_seconds > 0 —
    OutboxOldestPending이 알리고 처리는 런북의 수동 확인 · 삭제다). 경계: 정확히 900,000바이트인 손 행은 PG 텍스트 그대로
    보낸다. 수 MB 손 행(2 MB · 12 MB)이 머리에 있어도 패스의 tracemalloc 정점은 QUIET_PEAK(2,000,000) 아래다(손 행 크기와 무관 —
    payload를 읽지 않는다)."""
    assert publisher.MAX_EVENT_BYTES == 900_000
    head = _ulid.new_ulid()
    _hand_insert_sized(head, 900_001)
    normal = sorted(event.pk for event in seed(2))
    assert head < normal[0]
    locked_during: list[bool] = []
    fake = ScriptedProducer(on_produce=lambda _sent: locked_during.append(_row_locked(head)))
    with CaptureQueriesContext(connections["default"]) as queries:
        first = relay_once(producer=fake)
    assert (first, first.truncated) == (RelayResult(published=2, failed=0, dead=0), False)
    assert [sent.row_id() for sent in fake.sent] == normal
    assert locked_during == [False, False], "크기 상한을 넘는 행을 잠갔다"
    statements = _sql(queries)
    assert not [sql for sql in statements if head in sql], "크기 상한을 넘는 행을 쿼리가 건드렸다"
    (lock_sql,) = [sql for sql in statements if "FOR UPDATE" in sql.upper()]
    assert 'OCTET_LENGTH(("outbox"."payload")::text) <= 900000' in lock_sql, lock_sql
    assert _owner_all("SELECT attempts, last_error, dead_at FROM outbox WHERE id = %s", (head,)) == [(0, None, None)]
    second = relay_once(producer=fake)
    assert (second, second.truncated) == (RelayResult(published=0, failed=0, dead=0), False)
    assert len(fake.calls) == 2

    monkeypatch.setattr(relay, "build_producer", ScriptedProducer)
    waits = _record_waits(monkeypatch)
    call_command("outbox_relay", "--iterations", "3", "--metrics-port", "0", "--poll-interval", "0.5")
    assert waits == [0.5, 0.5], "크기 상한을 넘는 행이 대기 규칙(백오프)에 섞였다"
    assert _owner_all("SELECT id, attempts, last_error, dead_at FROM outbox") == [(head, 0, None, None)]
    assert _sample("outbox_pending") == 1, "크기 상한을 넘는 손 행이 pending 지표에서 빠졌다(OutboxOldestPending이 못 본다)"
    assert _sample("outbox_oldest_pending_seconds") > 0
    owner_execute("DELETE FROM outbox")

    edge = _ulid.new_ulid()
    _hand_insert_sized(edge, 900_000)
    edge_text = _owner_texts()[edge]
    fake = ScriptedProducer()
    assert relay_once(producer=fake) == RelayResult(published=1, failed=0, dead=0)
    (sent,) = fake.sent
    assert sent.row_id() == edge
    assert sent.value == edge_text.encode("utf-8")
    assert _owner_ids() == set()

    for size in (2_000_000, 12_000_000):
        giant = _ulid.new_ulid()
        _hand_insert_sized(giant, size)
        (tail,) = seed(1)
        fake = ScriptedProducer()
        result, peak = _peak(lambda fake=fake: relay_once(producer=fake))  # type: ignore[misc]
        assert result == RelayResult(published=1, failed=0, dead=0), size
        assert [sent.row_id() for sent in fake.sent] == [tail.pk], size
        assert peak < QUIET_PEAK, f"손 행 {size}바이트: 정점 {peak}바이트 — 상한을 넘는 행의 payload를 읽었다"
        assert _owner_ids() == {giant}, size
        owner_execute("DELETE FROM outbox")


def test_oc_29a_flush_fatal_kafka_exception_commits_the_pass_then_rebuilds(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-29a — flush가 올린 치명 예외(L6 · L9 (a) — confluent-kafka 2.16.1은 치명 오류를 error_cb로 넘기지 않고 flush · poll에서
    KafkaException(KafkaError(…, fatal=True))으로 올린다): 대역 flush가 DR(큐의 메시지 _PURGE_QUEUE)을 준 뒤 그 예외를 올린다.
    relay_once는 그것을 패스의 치명으로 접는다 — purge(in_queue · in_flight) 뒤 flush(5)로 남은 DR을 받고(큐에 남았던 행 =
    _PURGE_QUEUE), 그 패스를 반영 · 커밋한 뒤 ProducerFatalError(.result = (0, 4, 0) · .error_name = 원인 이름
    CLUSTER_AUTHORIZATION_FAILED — 같은 패스 produce의 _FATAL보다 앞선다 · 메시지에 값 없음)를 올린다. 행은 모두 attempts + 1 ·
    last_error = 그 행의 DR 오류(또는 produce 예외)이고, 메인 단계에서 치명이 섰으므로 DLQ 단계가 없다 — attempts = MAX−1 행도
    DLQ로 가지 않고 attempts MAX · dead_at NULL · last_error = 메인 오류다. 명령은 그 예외에서 프로듀서를 버리고(로그
    `producer_fatal ProducerFatalError kafka_error=CLUSTER_AUTHORIZATION_FAILED …` · 백오프) 다음 반복에 새로 만든다 — 새
    프로듀서가 보낼 때 attempts는 이미 커밋돼 있다."""
    purged = Fail(f"Purged in queue {SENTINEL}", code=KafkaError._PURGE_QUEUE)
    ids = sorted(event.pk for event in seed(4))
    owner_execute("UPDATE outbox SET attempts = %s WHERE id = %s", [MAX_ATTEMPTS - 1, ids[3]])
    outcomes: dict[str | None, object] = {ids[0]: HOLD, ids[1]: purged, ids[2]: _fatal_produce_error(), ids[3]: purged}
    fake = ScriptedProducer(decide=lambda sent: outcomes[sent.row_id()], on_flush=raising(_fatal_error()))
    with pytest.raises(relay.ProducerFatalError) as info:
        relay_once(producer=fake)
    assert info.value.result == RelayResult(published=0, failed=4, dead=0)
    assert info.value.error_name == FATAL_NAME, "원인 이름이 아니다(produce의 _FATAL이 앞섰다)"
    assert SENTINEL not in str(info.value)
    assert fake.flush_calls == [relay.FLUSH_TIMEOUT_S, relay.PURGE_FLUSH_TIMEOUT_S]
    assert fake.purge_calls == [(True, True)]
    assert [sent.topic for sent in fake.calls] == [KAFKA_TOPIC] * 4, "메인 단계 치명 뒤 DLQ 단계를 돌았다"
    rows = owner_rows()
    assert {pk: (row.attempts, row.dead_at) for pk, row in rows.items()} == {
        ids[0]: (1, None),
        ids[1]: (1, None),
        ids[2]: (1, None),
        ids[3]: (MAX_ATTEMPTS, None),
    }
    errors = {pk: row.last_error or "" for pk, row in rows.items()}
    assert "_PURGE_QUEUE" in errors[ids[0]], "purge 뒤 flush가 준 DR이 기록되지 않았다"
    assert "_PURGE_QUEUE" in errors[ids[1]] and SENTINEL in errors[ids[1]]
    assert "_FATAL" in errors[ids[2]] and SENTINEL in errors[ids[2]]
    assert "_PURGE_QUEUE" in errors[ids[3]] and SENTINEL in errors[ids[3]], "last_error가 메인 오류가 아니다"
    owner_execute("DELETE FROM outbox")

    events = seed(2)
    seen: list[int] = []
    dying = ScriptedProducer(decide=lambda _sent: purged, on_flush=raising(_fatal_error()))
    fresh = ScriptedProducer(on_produce=_attempts_at_produce(seen))
    built, waits = _relay_command(monkeypatch, caplog, [dying, fresh], 2)
    assert built == [dying, fresh], "치명 패스 뒤 프로듀서를 다시 만들지 않았다"
    assert seen == [1, 1], "치명 패스의 attempts가 커밋되기 전에 새 프로듀서가 보냈다"
    assert sorted(sent.row_id() or "" for sent in fresh.sent) == sorted(event.pk for event in events)
    assert owner_rows() == {}
    assert waits == [1.0]
    line = f"outbox_relay.producer_fatal ProducerFatalError kafka_error={FATAL_NAME} published=0 failed=2 dead=0"
    assert line in _relay_lines(caplog)
    assert SENTINEL not in caplog.text


def test_oc_29b_flush_fatal_system_error_forms_are_fatal_too(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-29b — 치명 예외를 원인으로 한 SystemError(L6 · L9 (b) — flush가 치명 예외를 올리는 같은 호출에서 DR 콜백이 뒤따르면
    CPython이 그 예외를 원인으로 한 SystemError로 바꾼다 · 그 예외가 걸린 채 불리는 첫 DR 콜백은 C 함수를 부르는 자리에서 끊길
    수 있다 — 탐침에서 isinstance를 먼저 부른 콜백은 첫 DR을 적지 못했다): 원인은 __cause__, 없으면 __context__다. 첫 flush가
    __cause__ 꼴을 올리고 purge 뒤 flush가 __context__ 꼴을 올려도(purge 뒤 flush의 같은 꼴 예외는 삼킨다) 그 패스를 반영 ·
    커밋한 뒤 ProducerFatalError(.result = (0, 3, 0) · .error_name = CLUSTER_AUTHORIZATION_FAILED)를 올린다. purge 뒤에도 DR이
    오지 않은 행(대역: purge_reports=False)은 「delivery 결과 없음」 실패다 · DLQ 단계 없음(attempts = MAX−1 행 포함) · 명령은
    다음 반복에 프로듀서를 새로 만든다."""
    purged = Fail(f"Purged in queue {SENTINEL}", code=KafkaError._PURGE_QUEUE)
    ids = sorted(event.pk for event in seed(3))
    owner_execute("UPDATE outbox SET attempts = %s WHERE id = %s", [MAX_ATTEMPTS - 1, ids[2]])
    outcomes: dict[str | None, object] = {ids[0]: HOLD, ids[1]: purged, ids[2]: purged}
    fake = ScriptedProducer(
        decide=lambda sent: outcomes[sent.row_id()],
        on_flush=raising(_system_error(cause=_fatal_error()), _system_error(context=_fatal_error())),
        purge_reports=False,
    )
    with pytest.raises(relay.ProducerFatalError) as info:
        relay_once(producer=fake)
    assert info.value.result == RelayResult(published=0, failed=3, dead=0)
    assert info.value.error_name == FATAL_NAME
    assert SENTINEL not in str(info.value)
    assert fake.flush_calls == [relay.FLUSH_TIMEOUT_S, relay.PURGE_FLUSH_TIMEOUT_S]
    assert fake.purge_calls == [(True, True)]
    assert [sent.topic for sent in fake.calls] == [KAFKA_TOPIC] * 3, "메인 단계 치명 뒤 DLQ 단계를 돌았다"
    rows = owner_rows()
    assert {pk: (row.attempts, row.dead_at) for pk, row in rows.items()} == {
        ids[0]: (1, None),
        ids[1]: (1, None),
        ids[2]: (MAX_ATTEMPTS, None),
    }
    assert rows[ids[0]].last_error == NO_RESULT
    assert "_PURGE_QUEUE" in (rows[ids[1]].last_error or "")
    assert "_PURGE_QUEUE" in (rows[ids[2]].last_error or ""), "last_error가 메인 오류가 아니다"
    owner_execute("DELETE FROM outbox")

    events = seed(2)
    seen: list[int] = []
    dying = ScriptedProducer(decide=lambda _sent: purged, on_flush=raising(_system_error(cause=_fatal_error())))
    fresh = ScriptedProducer(on_produce=_attempts_at_produce(seen))
    built, waits = _relay_command(monkeypatch, caplog, [dying, fresh], 2)
    assert built == [dying, fresh], "SystemError 꼴 치명 뒤 프로듀서를 다시 만들지 않았다"
    assert seen == [1, 1]
    assert sorted(sent.row_id() or "" for sent in fresh.sent) == sorted(event.pk for event in events)
    assert owner_rows() == {}
    assert waits == [1.0]
    line = f"outbox_relay.producer_fatal ProducerFatalError kafka_error={FATAL_NAME} published=0 failed=2 dead=0"
    assert line in _relay_lines(caplog)
    assert SENTINEL not in caplog.text


def test_oc_29c_command_polls_before_each_pass_and_drops_a_producer_that_died_idle(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-29c — 패스 전 poll(L7 · L9 (c)): 명령은 반복마다 relay_once 전에 그 프로듀서의 poll(0)을 부른다. 유휴 중 난 치명 오류는
    다음 poll이 올린다(실측 — KafkaException(fatal) · 같은 호출에서 DR 콜백이 뒤따르면 SystemError 꼴). poll이 치명 꼴 예외
    (KafkaException · __cause__ 또는 __context__가 그것인 SystemError)를 올리면 행에 닿기 전에 그 프로듀서를 버린다 — 그 프로듀서로
    produce · flush 0 · 행 무변경(새 프로듀서가 보낼 때 attempts 0) · 로그 `outbox_relay.producer_fatal <poll 예외 클래스>
    kafka_error=CLUSTER_AUTHORIZATION_FAILED published=0 failed=0 dead=0`(원인 이름 보존 · 값 없음) · 그 반복은 오류 백오프(1.0) ·
    다음 반복에 새로 만든다. 그 밖의 poll 예외(비치명 KafkaException)는 일반 오류 경로다 — `outbox_relay.error KafkaException
    kafka_error=_TRANSPORT` · 백오프 · 프로듀서를 버리지 않는다(다음 반복이 같은 프로듀서로 보낸다)."""
    forms: list[tuple[BaseException, str]] = [
        (_fatal_error(), "KafkaException"),
        (_system_error(cause=_fatal_error()), "SystemError"),
        (_system_error(context=_fatal_error()), "SystemError"),
    ]
    for error, cls in forms:
        caplog.clear()
        events = seed(2)
        seen: list[int] = []
        dying = ScriptedProducer(decide=lambda _sent: _fatal_produce_error(), on_poll=raising(error))
        fresh = ScriptedProducer(on_produce=_attempts_at_produce(seen))
        built, waits = _relay_command(monkeypatch, caplog, [dying, fresh], 2)
        assert built == [dying, fresh], f"{cls}: poll 치명 뒤 프로듀서를 다시 만들지 않았다"
        assert dying.poll_calls == [0], cls
        assert (dying.calls, dying.flush_calls) == ([], []), f"{cls}: 치명 프로듀서로 행에 닿았다"
        assert seen == [0, 0], f"{cls}: 행이 바뀐 뒤에 새 프로듀서가 보냈다"
        assert sorted(sent.row_id() or "" for sent in fresh.sent) == sorted(event.pk for event in events)
        assert owner_rows() == {}
        assert waits == [1.0], f"{cls}: poll 치명 반복이 오류 백오프가 아니다"
        line = f"outbox_relay.producer_fatal {cls} kafka_error={FATAL_NAME} published=0 failed=0 dead=0"
        assert line in _relay_lines(caplog), cls
        assert SENTINEL not in caplog.text, cls

    caplog.clear()
    (event,) = seed(1)
    shaky = ScriptedProducer(
        on_poll=raising(KafkaException(KafkaError(KafkaError._TRANSPORT, f"Connect failed {SENTINEL}")))
    )
    built, waits = _relay_command(monkeypatch, caplog, [shaky], 2)
    assert built == [shaky], "비치명 poll 예외에 프로듀서를 버렸다"
    assert shaky.poll_calls == [0, 0]
    assert [sent.row_id() for sent in shaky.sent] == [event.pk]
    assert owner_rows() == {}
    assert waits == [1.0]
    lines = _relay_lines(caplog)
    assert "outbox_relay.error KafkaException kafka_error=_TRANSPORT" in lines
    assert not [line for line in lines if line.startswith("outbox_relay.producer_fatal")]
    assert SENTINEL not in caplog.text


def test_oc_29d_error_cb_logs_only_the_names_of_non_fatal_events(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-29d — error_cb(L6 · L7 · L9 (d)): build_producer()는 confluent 설정에 error_cb를 단다(producer_config()의 결과에는 없다 —
    결과 불변). confluent는 사용자 error_cb가 없으면 비치명 오류 이벤트(_TRANSPORT · _ALL_BROKERS_DOWN 등)를 버리므로 이 콜백 줄이
    그 이벤트의 유일한 기록이다 — 이름만 한 줄(`outbox_relay.kafka_error name=_TRANSPORT` — fatal · retriable 필드 · 메시지 ·
    SENTINEL 없음 · 실물의 retriable은 늘 False다). 대역 생성기(confluent_kafka.Producer 자리 — 받은 설정의 error_cb를 flush · poll
    훅에서 부른다)로 본다: relay_once의 flush 안에서 한 줄(그 패스는 정상), 명령의 패스 전 poll 안에서 유휴 반복마다 한 줄(다음
    비지 않은 패스에 몰리지 않는다) · 비치명이므로 프로듀서를 다시 만들지 않는다."""
    import confluent_kafka

    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{_closed_port()}"
    transport = KafkaError(KafkaError._TRANSPORT, f"Connect to ipv4#127.0.0.1:1 failed {SENTINEL}")
    configs: list[dict[str, Any]] = []

    def factory(config: dict[str, Any]) -> ScriptedProducer:
        configs.append(config)
        callback = config["error_cb"]
        return ScriptedProducer(on_flush=lambda: callback(transport), on_poll=lambda: callback(transport))

    monkeypatch.setattr(confluent_kafka, "Producer", factory)
    seed(1)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        assert relay_once() == RelayResult(published=1, failed=0, dead=0)
    assert _relay_lines(caplog) == ["outbox_relay.kafka_error name=_TRANSPORT"]
    assert {key: value for key, value in configs[0].items() if key != "error_cb"} == relay.producer_config()
    assert callable(configs[0]["error_cb"])
    assert owner_rows() == {}

    caplog.clear()
    waits = _record_waits(monkeypatch)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", "3", "--metrics-port", "0", "--poll-interval", "0.5")
    kafka_lines = [line for line in _relay_lines(caplog) if line.startswith("outbox_relay.kafka_error")]
    assert kafka_lines == ["outbox_relay.kafka_error name=_TRANSPORT"] * 3, "유휴 반복의 poll이 오류 이벤트를 내지 않았다"
    assert len(configs) == 2, "비치명 오류 이벤트에 프로듀서를 다시 만들었다"
    assert waits == [0.5, 0.5]
    assert SENTINEL not in caplog.text


def test_oc_29e_other_flush_exceptions_still_roll_the_pass_back() -> None:
    """oc-29e — 그 밖의 flush 예외는 그대로 올린다(L6): 비치명 KafkaException · 원인이 비치명 KafkaException인 SystemError · 원인이
    KafkaException이 아닌 SystemError · RuntimeError(콜백 버그 등)는 치명으로 접지 않는다 — relay_once 밖으로 나가고 그 패스는
    롤백된다(성공 DR을 받은 행도 지우지 않는다 · attempts 그대로 · purge 0 — 명령은 로그 + 백오프 · oc-15d)."""
    transport = f"Connect failed {SENTINEL}"
    for error in (
        KafkaException(KafkaError(KafkaError._TRANSPORT, transport)),
        _system_error(cause=KafkaException(KafkaError(KafkaError._TRANSPORT, transport))),
        _system_error(context=RuntimeError(f"callback bug {SENTINEL}")),
        RuntimeError(f"callback bug {SENTINEL}"),
    ):
        label = f"{type(error).__name__}({type(error.__cause__ or error.__context__).__name__})"
        ids = sorted(event.pk for event in seed(2))
        fake = ScriptedProducer(on_flush=raising(error))
        with pytest.raises(type(error)) as info:
            relay_once(producer=fake)
        assert info.value is error, label
        rows = owner_rows()
        assert set(rows) == set(ids), f"{label}: 패스가 롤백되지 않았다"
        assert all((row.attempts, row.last_error) == (0, None) for row in rows.values()), label
        assert fake.purge_calls == [], label
        owner_execute("DELETE FROM outbox")


def test_oc_29f_empty_first_pass_after_a_fatal_rebuild_keeps_the_wait(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-29f — 치명 재생성 직후의 빈 패스(M1 · 리뷰 r4 A4-1 = B4-1): 명령은 치명으로 프로듀서를 버릴 때(poll 치명 ·
    ProducerFatalError 둘 다) 표시를 세우고, 다시 만든 프로듀서로 도는 첫 패스가 결과를 돌려주면 그 표시를 지운다. 그 첫 패스가
    빈 패스(published · failed · dead 모두 0)면 대기를 직전 값 그대로 둔다(next_wait(…, after_fatal_rebuild=True) — oc-16) —
    치명은 연결 뒤 비동기로 서므로 빈 패스는 새 프로듀서가 쓸 만한지 보여 주지 않는다. 결과 없이 오류로 끝난 반복(생성 실패 ·
    비치명 poll 예외 · DB 오류)에서는 표시가 남는다(결과를 돌려준 첫 패스까지). 대기는 네 사례를 모두 돈 뒤 함께 본다.

    - 지속 치명(유휴 · ACL 누락 흉내): 행 없음 · 프로듀서 넷 모두 첫 poll은 통과하고 둘째 poll이 치명 → `--iterations 8`의 대기
      [0.5, 1.0, 1.0, 2.0, 2.0, 4.0, 4.0] · 생성 4 · producer_fatal 줄 4(r4는 빈 패스가 대기를 0.5로 되돌려 0.5 ↔ 1.0을 오갔다 —
      약 1.5 s마다 재생성).
    - 회복: 치명 하나 뒤 건강한 프로듀서 · 행 없음 · `--iterations 5` → [0.5, 1.0, 1.0, 0.5](유지된 대기를 한 번 더 채운 뒤 폴링
      간격 — 받아들인 대가).
    - ProducerFatalError 경로: 행 하나를 성공 DR로 보낸 뒤 flush가 치명을 올린다(.result = (1, 0, 0) — 그 행은 지워진다) → 다시
      만든 프로듀서의 첫 패스는 빈 패스 → `--iterations 4`의 대기 [1.0, 1.0, 0.5].
    - 오류로 끝난 반복은 표시를 남긴다: poll 치명 → 생성 실패(ImproperlyConfigured) → 새 프로듀서의 첫 poll이 비치명
      KafkaException(_TRANSPORT) → relay_once의 DB OperationalError → 빈 패스 → 빈 패스 = `--iterations 7`의 대기
      [1.0, 2.0, 4.0, 8.0, 8.0, 0.5] · 줄은 각 오류 갈래(producer_fatal · error · error · db_error)를 지난다."""
    observed: dict[str, list[float]] = {}

    def doomed() -> ScriptedProducer:
        return ScriptedProducer(on_poll=raising(None, _fatal_error()))  # 첫 poll은 통과 · 둘째 poll이 치명

    producers = [doomed() for _ in range(4)]
    built, observed["지속 치명"] = _relay_command(monkeypatch, caplog, producers, 8)
    assert built == producers
    fatal_line = f"outbox_relay.producer_fatal KafkaException kafka_error={FATAL_NAME} published=0 failed=0 dead=0"
    assert [line for line in _relay_lines(caplog) if line.startswith("outbox_relay.producer_fatal")] == [fatal_line] * 4
    assert all((producer.calls, producer.poll_calls) == ([], [0, 0]) for producer in producers)
    assert SENTINEL not in caplog.text

    caplog.clear()
    once, healthy = doomed(), ScriptedProducer()
    built, observed["회복"] = _relay_command(monkeypatch, caplog, [once, healthy], 5)
    assert built == [once, healthy]
    assert healthy.poll_calls == [0, 0, 0]

    caplog.clear()
    (event,) = seed(1)
    flushing, healthy = ScriptedProducer(on_flush=raising(_fatal_error())), ScriptedProducer()
    built, observed["ProducerFatalError"] = _relay_command(monkeypatch, caplog, [flushing, healthy], 4)
    assert built == [flushing, healthy]
    assert [sent.row_id() for sent in flushing.sent] == [event.pk]
    assert owner_rows() == {}, "치명 패스에서 성공 DR을 받은 행이 지워지지 않았다"
    assert healthy.calls == []
    line = f"outbox_relay.producer_fatal ProducerFatalError kafka_error={FATAL_NAME} published=1 failed=0 dead=0"
    assert line in _relay_lines(caplog)
    assert SENTINEL not in caplog.text

    caplog.clear()
    real_relay = relay.relay_once
    relay_calls: list[int] = []

    def db_error_once(**kwargs: Any) -> RelayResult:
        relay_calls.append(len(relay_calls))
        if len(relay_calls) == 1:
            raise OperationalError(f"server closed the connection {SENTINEL}")
        return real_relay(**kwargs)

    monkeypatch.setattr(relay, "relay_once", db_error_once)
    dying = ScriptedProducer(on_poll=raising(_fatal_error()))
    shaky = ScriptedProducer(
        on_poll=raising(KafkaException(KafkaError(KafkaError._TRANSPORT, f"Connect failed {SENTINEL}")))
    )
    plan: list[ScriptedProducer | Exception] = [dying, ImproperlyConfigured(f"KAFKA_CLIENT_CONFIG {SENTINEL}"), shaky]
    built, observed["오류 반복"] = _relay_command(monkeypatch, caplog, plan, 7)
    assert built == plan
    assert len(relay_calls) == 4
    assert shaky.poll_calls == [0] * 5
    events = [line.split(" ")[0] for line in _relay_lines(caplog)]
    assert events == [
        "outbox_relay.start",
        "outbox_relay.producer_fatal",
        "outbox_relay.error",
        "outbox_relay.error",
        "outbox_relay.db_error",
        "outbox_relay.stop",
    ], events
    assert SENTINEL not in caplog.text

    assert observed == {
        "지속 치명": [0.5, 1.0, 1.0, 2.0, 2.0, 4.0, 4.0],
        "회복": [0.5, 1.0, 1.0, 0.5],
        "ProducerFatalError": [1.0, 1.0, 0.5],
        "오류 반복": [1.0, 2.0, 4.0, 8.0, 8.0, 0.5],
    }, "치명 재생성 직후의 빈 패스가 대기를 되돌렸거나, 결과 없이 오류로 끝난 반복이 표시를 지웠다"


def test_oc_29g_fatal_only_in_the_flush_after_purge_is_still_fatal() -> None:
    """oc-29g — purge 뒤 flush에서만 난 치명(M2 · 리뷰 r4 B4-2): 첫 flush는 예외 없이 잔여 1(DR 없이 큐에 남은 행)을 돌려주고,
    purge 뒤 flush가 purge DR(_PURGE_QUEUE)을 준 뒤 치명 예외를 올린다. relay_once는 그 예외도 패스의 치명으로 접는다 — purge
    (in_queue · in_flight) 한 번 · flush(35) · flush(5) 뒤 그 패스를 반영 · 커밋하고 ProducerFatalError(.result = (0, 1, 0) ·
    .error_name = CLUSTER_AUTHORIZATION_FAILED · 메시지에 값 없음)를 올린다 · 잔여 행은 attempts 1 · last_error _PURGE_QUEUE ·
    dead_at NULL. 같은 패스에서 메인이 비치명으로 실패한 attempts = MAX−1 행을 함께 두면 DLQ 단계가 없다(메인 단계 치명 —
    .result = (0, 2, 0) · 그 행은 attempts MAX · dead_at NULL · last_error = 메인 오류). r4 구현도 지키는 거동이다 — 판별력은 변이
    L6-purge-fatal-dropped(`flush_fatal = flush_fatal or purge_fatal` 제거)가 보인다."""
    for extra in (False, True):
        label = f"MAX−1 행 {'있음' if extra else '없음'}"
        ids = sorted(event.pk for event in seed(2 if extra else 1))
        outcomes: dict[str | None, object] = {ids[0]: HOLD}
        if extra:
            owner_execute("UPDATE outbox SET attempts = %s WHERE id = %s", [MAX_ATTEMPTS - 1, ids[1]])
            outcomes[ids[1]] = Fail(f"main down {SENTINEL}")

        def decide(sent: Any, outcomes: dict[str | None, object] = outcomes) -> object:
            return outcomes[sent.row_id()] if sent.topic == KAFKA_TOPIC else None  # DLQ로 보냈다면 성공했을 것이다

        fake = ScriptedProducer(decide=decide, on_flush=raising(None, _fatal_error()))
        with pytest.raises(relay.ProducerFatalError) as info:
            relay_once(producer=fake)
        assert info.value.result == RelayResult(published=0, failed=len(ids), dead=0), label
        assert info.value.error_name == FATAL_NAME, label
        assert SENTINEL not in str(info.value), label
        assert fake.flush_calls == [relay.FLUSH_TIMEOUT_S, relay.PURGE_FLUSH_TIMEOUT_S], label
        assert fake.purge_calls == [(True, True)], label
        assert [sent.topic for sent in fake.calls] == [KAFKA_TOPIC] * len(ids), f"{label}: 메인 단계 치명 뒤 DLQ 단계를 돌았다"
        rows = owner_rows()
        expected = {ids[0]: (1, None)} | ({ids[1]: (MAX_ATTEMPTS, None)} if extra else {})
        assert {pk: (row.attempts, row.dead_at) for pk, row in rows.items()} == expected, label
        assert "_PURGE_QUEUE" in (rows[ids[0]].last_error or ""), f"{label}: purge 뒤 flush가 준 DR이 기록되지 않았다"
        if extra:
            assert "main down" in (rows[ids[1]].last_error or ""), "last_error가 메인 오류가 아니다"
        owner_execute("DELETE FROM outbox")


# --- D8 · J10 purge · 재처리 ------------------------------------------------------------------------------------------


def test_oc_13_purge_dead_boundary_uses_db_clock(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-13 — purge_dead()(D8 · K7): DB now() − 30 d − 1 h는 삭제 · − 30 d + 1 h는 유지 · dead_at NULL은 유지 · 반환 1. 판정은 DB
    시계다(Python 시계를 100일 뒤로 돌려도 결과가 같다) · default 별칭(owner 쿼리 0). 신호 없는 직접 DELETE다: sender 없는
    pre_delete · post_delete 수신기를 단 채로도 수신기 호출 0이고 default 쿼리는 DELETE 문 하나뿐이다(지울 행을 먼저 읽지 않는다 —
    Collector는 30일 넘은 dead 행 전부를 메모리로 올린다 · 경계는 DB 시계 STATEMENT_TIMESTAMP()). older_than을 주면 그 경계 · 0과
    음수는 ValueError."""
    old, recent, pending = seed(3)
    owner_execute("UPDATE outbox SET dead_at = now() - interval '30 days 1 hour' WHERE id = %s", [old.pk])
    owner_execute(
        "UPDATE outbox SET dead_at = now() - interval '30 days' + interval '1 hour' WHERE id = %s", [recent.pk]
    )
    real_now = timezone.now
    with monkeypatch.context() as patch:
        patch.setattr(timezone, "now", lambda: real_now() + timedelta(days=100))
        with (
            _delete_receivers() as signals,
            CaptureQueriesContext(connections["owner"]) as owner_queries,
            CaptureQueriesContext(connections["default"]) as app_queries,
        ):
            deleted = purge_dead()
    assert deleted == 1
    assert len(owner_queries) == 0
    assert signals == [], "삭제 신호가 나갔다(Django Collector 경유)"
    (statement,) = _sql(app_queries)  # 삭제 전 SELECT 0 — DELETE 하나뿐
    assert statement.lstrip().upper().startswith("DELETE"), statement[:80]
    assert "STATEMENT_TIMESTAMP()" in statement.upper()
    assert set(owner_rows()) == {recent.pk, pending.pk}
    for bad in (timedelta(0), timedelta(seconds=-1)):
        with pytest.raises(ValueError):
            purge_dead(older_than=bad)
    assert purge_dead(older_than=timedelta(days=29)) == 1
    assert set(owner_rows()) == {pending.pk}


def test_oc_14_requeue_dead_and_command() -> None:
    """oc-14 — requeue_dead(ids=None)(D8): dead 행만 dead_at · attempts · last_error를 비운다(pending 행은 그대로 · ids가 있으면 그
    안만 · str 하나는 TypeError). 되돌린 행은 다음 패스가 메인부터 다시 시도한다(attempts 0부터 — 곧바로 DLQ로 가지 않는다).
    명령 outbox_requeue: --id <ULID>(반복) 또는 --all 하나 · 잘못된 id · 인자 없음 · 둘 다 → CommandError · stdout 한 줄
    `outbox_requeue: N`."""
    dead_one, dead_two, pending = seed(3)
    owner_execute(
        "UPDATE outbox SET dead_at = now(), attempts = 10, last_error = 'x' WHERE id = ANY(%s)",
        [[dead_one.pk, dead_two.pk]],
    )
    owner_execute("UPDATE outbox SET attempts = 3, last_error = 'still pending' WHERE id = %s", [pending.pk])
    assert requeue_dead([dead_one.pk, pending.pk]) == 1
    rows = owner_rows()
    assert (rows[dead_one.pk].dead_at, rows[dead_one.pk].attempts, rows[dead_one.pk].last_error) == (None, 0, None)
    assert rows[dead_two.pk].dead_at is not None and rows[dead_two.pk].attempts == 10
    assert (rows[pending.pk].attempts, rows[pending.pk].last_error) == (3, "still pending")
    with pytest.raises(TypeError):
        requeue_dead(dead_two.pk)
    assert requeue_dead([]) == 0
    assert requeue_dead() == 1
    assert owner_rows()[dead_two.pk].dead_at is None
    assert owner_rows()[pending.pk].attempts == 3

    main_down = ScriptedProducer(decide=fail_topics(KAFKA_TOPIC))
    relay_once(producer=main_down)
    assert DLQ_TOPIC not in [sent.topic for sent in main_down.sent]
    owner_execute("DELETE FROM outbox")

    first, second = seed(2)
    owner_execute("UPDATE outbox SET dead_at = now(), attempts = 10, last_error = 'x'")
    stdout = io.StringIO()
    call_command("outbox_requeue", "--id", first.pk, stdout=stdout)
    assert stdout.getvalue() == "outbox_requeue: 1\n"
    assert owner_rows()[first.pk].dead_at is None
    assert owner_rows()[second.pk].dead_at is not None
    stdout = io.StringIO()
    call_command("outbox_requeue", "--all", stdout=stdout)
    assert stdout.getvalue() == "outbox_requeue: 1\n"
    stdout = io.StringIO()
    call_command("outbox_requeue", "--id", first.pk, "--id", second.pk, stdout=stdout)
    assert stdout.getvalue() == "outbox_requeue: 0\n"
    invalid = (
        (),
        ("--all", "--id", first.pk),
        ("--id", "not-a-ulid"),
        ("--id", first.pk.lower()),
        ("--id", first.pk + LF),
    )
    for args in invalid:
        with pytest.raises(CommandError):
            call_command("outbox_requeue", *args, stdout=io.StringIO())


def test_oc_27_outbox_purge_command() -> None:
    """oc-27 — 명령 outbox_purge(J10 · Celery가 없는 pod의 CronJob): 인자 없이 purge_dead()(30 d · DB 시계)를 부르고 stdout에 한 줄
    `outbox_purge: N`(ASCII)을 낸다. 인자(옵션 · 위치)를 주면 CommandError다."""
    old, recent, pending = seed(3)
    owner_execute("UPDATE outbox SET dead_at = now() - interval '30 days 1 hour' WHERE id = %s", [old.pk])
    owner_execute(
        "UPDATE outbox SET dead_at = now() - interval '30 days' + interval '1 hour' WHERE id = %s", [recent.pk]
    )
    stdout = io.StringIO()
    call_command("outbox_purge", stdout=stdout)
    assert stdout.getvalue() == "outbox_purge: 1\n"
    assert set(owner_rows()) == {recent.pk, pending.pk}
    stdout = io.StringIO()
    call_command("outbox_purge", stdout=stdout)
    assert stdout.getvalue() == "outbox_purge: 0\n"
    for args in (("--older-than", "1"), ("extra",)):
        with pytest.raises(CommandError):
            call_command("outbox_purge", *args, stdout=io.StringIO())
    assert set(owner_rows()) == {recent.pk, pending.pk}


# --- D7 · J5–J7 명령 outbox_relay ------------------------------------------------------------------------------------


class _FakeServer:
    """start_http_server 대역의 서버(명령이 끝에 닫는지 본다)."""

    def __init__(self) -> None:
        self.closed: list[str] = []

    def shutdown(self) -> None:
        self.closed.append("shutdown")

    def server_close(self) -> None:
        self.closed.append("server_close")


def test_oc_15a_command_relays_and_refreshes_metrics(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-15a — `outbox_relay --iterations 2 --metrics-port 0 --poll-interval 0`(대역 프로듀서 = build_producer 패치): 행 발행 ·
    outbox_pending 갱신(미리 둔 999 → 0) · 포트 0이면 start_http_server를 부르지 않는다. 인자 없는 기본값 = 계약 값(배치 100 ·
    폴링 0.5 s · 백오프 상한 300 s · 지표 9464 · 무한)."""
    import prometheus_client

    events = seed(3)
    producer = ScriptedProducer()
    monkeypatch.setattr(relay, "build_producer", lambda: producer)
    servers: list[int] = []
    monkeypatch.setattr(prometheus_client, "start_http_server", lambda port, *a, **k: servers.append(port))
    metrics.OUTBOX_PENDING.set(999)
    call_command("outbox_relay", "--iterations", "2", "--metrics-port", "0", "--poll-interval", "0")
    assert owner_rows() == {}
    assert sorted(sent.row_id() or "" for sent in producer.sent) == sorted(event.pk for event in events)
    assert _sample("outbox_pending") == 0
    assert servers == []
    defaults = relay_command.Command().create_parser("manage.py", "outbox_relay").parse_args([])
    parsed = (defaults.batch_size, defaults.poll_interval, defaults.max_backoff)
    assert parsed == (100, 0.5, 300.0)
    assert (defaults.metrics_port, defaults.iterations) == (9464, 0)


def test_oc_15b_command_order_port_first_and_settings_errors_do_not_end_it(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-15b — 순서(J6 · L7): ① start_http_server(포트) ② refresh_metrics ③ 루프(close_old_connections → 프로듀서가 없으면
    build_producer → 그 프로듀서의 poll(0) → relay_once → refresh_metrics)이고 끝나면 지표 서버를 닫는다. 설정 오류(Kafka 설정 —
    프로듀서 생성 실패 · OUTBOX_TOPIC_PREFIX · OUTBOX_MAX_ATTEMPTS — relay_once의 검증)는 포트를 연 뒤 반복마다 로그(예외 클래스 +
    값 없는 진단 필드 — K11 · 필드는 oc-15d · 25가 본다) + 백오프로 다시 시도한다 — 명령은 반복 수를 채우고 정상으로 끝나며 행은
    그대로다. 포트를 열 수 없으면 CommandError로 끝난다(루프 전 실패의 하나 — 프로듀서 생성 0 · 신호 처리기 그대로)."""
    import prometheus_client

    log: list[str] = []
    server = _FakeServer()

    def fake_server(port: int, *_args: object, **_kwargs: object) -> tuple[_FakeServer, None]:
        log.append(f"http:{port}")
        return server, None

    real_relay, real_refresh, real_close = relay.relay_once, metrics.refresh_metrics, django.db.close_old_connections
    real_build = relay.build_producer

    def traced_relay(**kwargs: Any) -> RelayResult:
        log.append("relay")
        return real_relay(**kwargs)

    def traced_refresh() -> None:
        log.append("refresh")
        real_refresh()

    def traced_close(**kwargs: Any) -> None:
        log.append("close")
        real_close(**kwargs)

    def traced_build() -> ScriptedProducer:
        log.append("build")
        return ScriptedProducer(on_poll=lambda: log.append("poll"))

    monkeypatch.setattr(prometheus_client, "start_http_server", fake_server)
    monkeypatch.setattr(relay, "relay_once", traced_relay)
    monkeypatch.setattr(metrics, "refresh_metrics", traced_refresh)
    monkeypatch.setattr(django.db, "close_old_connections", traced_close)
    monkeypatch.setattr(relay, "build_producer", traced_build)
    seed(1)
    call_command("outbox_relay", "--iterations", "2", "--metrics-port", "9464", "--poll-interval", "0")
    assert log == [
        "http:9464", "refresh", "close", "build", "poll", "relay", "refresh", "close", "poll", "relay", "refresh",
    ]
    assert server.closed == ["shutdown", "server_close"]
    assert owner_rows() == {}

    def real_traced_build() -> object:
        log.append("build")
        return real_build()  # 실 경로(설정 검증 · 브로커 없는 실 Producer 생성)

    monkeypatch.setattr(relay, "build_producer", real_traced_build)
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{_closed_port()}"
    (waiting,) = seed(1)
    bad_settings: list[tuple[str, object]] = [
        ("KAFKA_CLIENT_CONFIG", {}),
        ("OUTBOX_TOPIC_PREFIX", "prod."),
        ("OUTBOX_MAX_ATTEMPTS", 0),
        ("OUTBOX_MAX_ATTEMPTS", "10"),
        ("OUTBOX_MAX_ATTEMPTS", True),
    ]
    for name, value in bad_settings:
        log.clear()
        caplog.clear()
        server.closed.clear()
        original = getattr(settings, name)
        setattr(settings, name, value)
        try:
            with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
                call_command(
                    "outbox_relay", "--iterations", "3", "--metrics-port", "9464", "--poll-interval", "0",
                    "--max-backoff", "0",
                )
        finally:
            setattr(settings, name, original)
        assert log[0] == "http:9464", f"{name}: 포트보다 먼저 다른 일을 했다"
        assert caplog.text.count("ImproperlyConfigured") == 3, f"{name}: 반복마다 로그 한 줄이 아니다"
        assert server.closed == ["shutdown", "server_close"], name
        assert _owner_ids() == {waiting.pk}, name

    def busy_port(port: int, *_args: object, **_kwargs: object) -> None:
        log.append(f"http:{port}")
        raise OSError(errno.EADDRINUSE, "Address already in use")

    builds: list[int] = []
    monkeypatch.setattr(prometheus_client, "start_http_server", busy_port)
    monkeypatch.setattr(relay, "build_producer", lambda: builds.append(1) or ScriptedProducer())
    before = signal.getsignal(signal.SIGTERM)
    with pytest.raises(CommandError) as info:
        call_command("outbox_relay", "--iterations", "1", "--metrics-port", "9464", "--poll-interval", "0")
    assert "9464" in str(info.value)
    assert builds == []
    assert signal.getsignal(signal.SIGTERM) is before


def test_oc_15c_sigterm_finishes_the_pass_and_restores_handlers(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-15c — SIGTERM(D7): 처리기는 플래그만 세운다 — 그 신호가 온 패스는 마치고(행 발행) 다음 패스 없이 끝난다(--iterations 5
    중 1). 대기는 0.1 s 조각이라 30 s 폴링 대기 중 신호에도 곧 끝난다. 명령 동안 SIGTERM · SIGINT 처리기가 바뀌고, 끝나면 이전
    처리기(여기서는 시험의 감시 처리기)로 되돌아간다 — 감시 처리기는 한 번도 불리지 않는다."""
    hits: list[int] = []

    def sentinel(signum: int, _frame: object) -> None:
        hits.append(signum)

    original_term, original_int = signal.getsignal(signal.SIGTERM), signal.getsignal(signal.SIGINT)
    signal.signal(signal.SIGTERM, sentinel)
    try:
        (event,) = seed(1)
        seen: list[tuple[object, object]] = []
        real_relay = relay.relay_once

        def signalling_relay(**kwargs: Any) -> RelayResult:
            seen.append((signal.getsignal(signal.SIGTERM), signal.getsignal(signal.SIGINT)))
            if len(seen) == 1:
                signal.raise_signal(signal.SIGTERM)
            return real_relay(**kwargs)

        monkeypatch.setattr(relay, "relay_once", signalling_relay)
        monkeypatch.setattr(relay, "build_producer", ScriptedProducer)
        call_command("outbox_relay", "--iterations", "5", "--metrics-port", "0", "--poll-interval", "0")
        assert len(seen) == 1, "SIGTERM 뒤에 다음 패스를 돌았다"
        assert seen[0][0] is not sentinel and seen[0][1] is not original_int
        assert hits == []
        assert signal.getsignal(signal.SIGTERM) is sentinel
        assert signal.getsignal(signal.SIGINT) is original_int
        assert event.pk not in owner_rows()

        seen.clear()
        monkeypatch.setattr(relay, "relay_once", real_relay)
        timer = threading.Timer(0.3, signal.raise_signal, args=(signal.SIGTERM,))
        started = time.monotonic()
        timer.start()
        try:
            call_command("outbox_relay", "--iterations", "3", "--metrics-port", "0", "--poll-interval", "30")
        finally:
            timer.cancel()
        assert time.monotonic() - started < 5, "대기가 신호를 0.1 s 조각으로 보지 않는다"
        assert hits == []
        assert signal.getsignal(signal.SIGTERM) is sentinel
    finally:
        signal.signal(signal.SIGTERM, original_term)
        signal.signal(signal.SIGINT, original_int)


def test_oc_15d_loop_errors_log_and_back_off(monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture) -> None:
    """oc-15d — 루프의 오류는 명령을 끝내지 않는다(J6 · K11): DB OperationalError · InterfaceError(close_old_connections를 한 번
    더) · 그 밖의 예외(RuntimeError)는 로그 + 백오프(0.5 → 1 → 2 → 4 → 8 s) 뒤 다음 반복을 돈다 — 다섯 번째 반복이 행을 발행한다.
    로그는 이벤트 이름 · 예외 클래스와 값 없는 진단 필드뿐이다(본문 · 인자의 SENTINEL 없음): DB 오류는 원인 psycopg 예외의
    SQLSTATE(sqlstate=57P01 — 원인이 없거나 원인의 sqlstate가 SQLSTATE 꼴이 아니면 필드를 생략한다), 그 밖은 가장 안쪽 트레이스백
    프레임의 파일 이름 · 줄 · 함수(at=<파일>:<줄>:<함수>)."""
    real_relay = relay.relay_once
    calls: list[int] = []

    def flaky(**kwargs: Any) -> RelayResult:
        calls.append(len(calls))
        if len(calls) == 1:
            try:
                raise psycopg.errors.AdminShutdown(f"terminating connection {SENTINEL}")
            except psycopg.Error as cause:
                raise OperationalError(f"server closed the connection {SENTINEL}") from cause
        if len(calls) == 2:
            raise InterfaceError(f"connection already closed {SENTINEL}")
        if len(calls) == 3:
            raise RuntimeError(f"relay bug {SENTINEL}")
        if len(calls) == 4:
            raise OperationalError(f"odd cause {SENTINEL}") from _OddCause()
        return real_relay(**kwargs)

    closes: list[int] = []
    real_close = django.db.close_old_connections

    def counted_close(**kwargs: Any) -> None:
        closes.append(1)
        real_close(**kwargs)

    monkeypatch.setattr(relay, "relay_once", flaky)
    monkeypatch.setattr(relay, "build_producer", ScriptedProducer)
    monkeypatch.setattr(django.db, "close_old_connections", counted_close)
    waits = _record_waits(monkeypatch)
    (event,) = seed(1)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", "5", "--metrics-port", "0", "--poll-interval", "0.5")
    assert len(calls) == 5
    assert waits == [1.0, 2.0, 4.0, 8.0]
    assert event.pk not in owner_rows()
    lines = _relay_lines(caplog)
    assert "outbox_relay.db_error OperationalError sqlstate=57P01" in lines
    assert "outbox_relay.db_error InterfaceError" in lines  # 원인 없음 — SQLSTATE 생략
    assert "outbox_relay.db_error OperationalError" in lines  # 원인의 sqlstate가 SQLSTATE 꼴이 아님 — 생략
    (bug,) = [line for line in lines if line.startswith("outbox_relay.error ")]
    assert re.fullmatch(r"outbox_relay\.error RuntimeError at=test_outbox_contract\.py:\d+:flaky", bug), bug
    assert SENTINEL not in caplog.text
    assert len(closes) == 8  # 반복마다 1(5) + DB 오류 뒤 1(3)


def test_oc_15e_command_arguments_are_validated(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-15e — 인자 검사(D7): 배치 1 이상 · 폴링 · 백오프 상한은 0 이상의 유한수이고 상한 ≥ 폴링 · 포트 0–65535 · 반복 0 이상 —
    어기면 CommandError(프로듀서를 만들기 전 · 포트를 열기 전). 사례마다 반복 1 · 포트 0 · 폴링 0을 먼저 주고(argparse는 같은
    옵션의 마지막 값을 쓴다) 사례의 값으로 덮는다 — 검사가 빠진 꼴도 무한 루프 · 실제 포트 없이 한 패스 뒤 끝나 「CommandError
    없음」으로 드러난다(변이 D7-13이 무한 루프로 시험을 멈춘 뒤 고침)."""
    import prometheus_client

    built: list[int] = []
    servers: list[int] = []

    def build() -> ScriptedProducer:
        built.append(1)
        return ScriptedProducer()

    monkeypatch.setattr(relay, "build_producer", build)
    monkeypatch.setattr(prometheus_client, "start_http_server", lambda port, *a, **k: servers.append(port))
    safe = ("--iterations", "1", "--metrics-port", "0", "--poll-interval", "0")
    for args in (
        ("--batch-size", "0"),
        ("--poll-interval", "-1"),
        ("--poll-interval", "nan"),
        ("--poll-interval", "inf"),
        ("--max-backoff", "-1"),
        ("--metrics-port", "65536"),
        ("--metrics-port", "-1"),
        ("--iterations", "-1"),
        ("--poll-interval", "5", "--max-backoff", "1"),
    ):
        with pytest.raises(CommandError):
            call_command("outbox_relay", *safe, *args)
    assert built == []
    assert servers == []


def test_oc_15f_kafka_cause_is_kept_only_for_system_error(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-15f — 진단 필드의 원인 보존은 SystemError에만(M3 · 리뷰 r4 B4-3 · A4-2 ①): SystemError면 그 __cause__(없으면
    __context__)가 KafkaException일 때 kafka_error=<그 KafkaError 이름>이다 — 기준은 relay._fatal_exception_name과 같고 치명
    여부와는 무관하다(진단이다). 그 밖의 예외는 암묵 __context__가 KafkaException이어도 가장 안쪽 프레임 at=<파일>:<줄>:<함수>를
    싣는다 — `except KafkaException` 처리 중 난 버그의 위치를 잃지 않는다. 루프의 일반 오류 줄(outbox_relay.error)로 본다:
    ① KafkaException 처리 중 난 RuntimeError(암묵 __context__) → at= ② KafkaException 처리 중 `raise SystemError(…) from
    ValueError(…)`(__cause__ = ValueError · __context__ = KafkaException) → at=(원인은 cause) ③ __context__가 비치명
    KafkaException(_TRANSPORT)인 SystemError → kafka_error=_TRANSPORT. 오류 셋은 백오프(1 → 2 → 4 s)이고 값(SENTINEL)은 어느 줄에도
    없다. oc-29c의 SystemError 두 꼴(치명 원인)은 그대로 kafka_error=다."""
    real_relay = relay.relay_once
    calls: list[int] = []

    def transport() -> KafkaException:
        return KafkaException(KafkaError(KafkaError._TRANSPORT, f"Connect failed {SENTINEL}"))

    def buggy(**kwargs: Any) -> RelayResult:
        calls.append(len(calls))
        if len(calls) == 1:
            try:
                raise transport()
            except KafkaException:
                raise RuntimeError(f"handler bug {SENTINEL}")  # 암묵 __context__ = KafkaException
        if len(calls) == 2:
            try:
                raise transport()
            except KafkaException:
                raise SystemError(f"wrapped {SENTINEL}") from ValueError(f"other cause {SENTINEL}")
        if len(calls) == 3:
            raise _system_error(context=transport())
        return real_relay(**kwargs)

    monkeypatch.setattr(relay, "relay_once", buggy)
    monkeypatch.setattr(relay, "build_producer", ScriptedProducer)
    waits = _record_waits(monkeypatch)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", "4", "--metrics-port", "0", "--poll-interval", "0.5")
    assert len(calls) == 4
    errors = [line for line in _relay_lines(caplog) if line.startswith("outbox_relay.error ")]
    assert [re.sub(r"\.py:\d+:", ".py:<줄>:", line) for line in errors] == [
        "outbox_relay.error RuntimeError at=test_outbox_contract.py:<줄>:buggy",
        "outbox_relay.error SystemError at=test_outbox_contract.py:<줄>:buggy",
        "outbox_relay.error SystemError kafka_error=_TRANSPORT",
    ], errors
    assert waits == [1.0, 2.0, 4.0]
    assert SENTINEL not in caplog.text


def test_oc_16_next_wait_rules() -> None:
    """oc-16 — 대기 규칙(D7 · D9 · J4 · K9 · 순수 함수 next_wait): 진전 없음(published 0 · failed > 0 — 같은 패스에 dead가 있어도 ·
    잘렸어도) 또는 오류(None) → max(직전 대기, 폴링 간격, 하한 MIN_BACKOFF_S 0.5) × 2, 상한 max_backoff · 잘린 패스(truncated — 행
    수 LIMIT · 바이트 예산) → 0 · 그 밖(진전 · 빈 패스 · dead만) → 폴링 간격(백오프를 되돌린다). 잘림 표시가 정한다 — published가
    배치 수와 같아도 표시가 없으면 폴링 간격이다. 진전 없음이 잘림보다 먼저다(장애 중 바쁜 루프가 없다). 전면 장애의 처음 9번
    대기 합 = 511 s. 하한(K9): --poll-interval 0(시험용)이어도 오류 · 진전 없음은 1.0 → 2.0 …으로 자란다(바쁜 루프 · 로그 폭주가
    없다) · 빈 패스는 폴링 간격 그대로(0) · --max-backoff 0(시험)은 상한이라 여전히 0. 치명 재생성 직후(M1 — 키워드 인자
    after_fatal_rebuild: bool = False): True면 빈 패스(published · failed · dead 모두 0)만 직전 대기를 그대로 돌려주고(폴링 0이어도),
    그 밖은 평소 규칙이다 — 진전 → 폴링 간격 · 진전 없음과 오류 → 두 배 · 잘림 → 0 · dead만 → 폴링 간격. 기본값(False)의 단언은
    위와 같다(빈 패스 → 폴링 간격)."""
    next_wait = relay_command.next_wait
    assert relay_command.MIN_BACKOFF_S == 0.5
    zero = {"poll_interval": 0.0, "max_backoff": 300.0}
    assert next_wait(None, previous=0.0, **zero) == 1.0
    assert next_wait(RelayResult(0, 1, 0), previous=0.0, **zero) == 1.0
    assert next_wait(RelayResult(0, 1, 0), previous=1.0, **zero) == 2.0
    assert next_wait(None, previous=2.0, **zero) == 4.0
    assert next_wait(RelayResult(0, 0, 0), previous=4.0, **zero) == 0.0
    assert next_wait(RelayResult(3, 0, 0), previous=4.0, **zero) == 0.0
    assert next_wait(None, previous=0.0, poll_interval=0.0, max_backoff=0.0) == 0.0
    kwargs = {"poll_interval": 0.5, "max_backoff": 300.0}
    assert next_wait(RelayResult(100, 0, 0, truncated=True), previous=0.5, **kwargs) == 0
    assert next_wait(RelayResult(3, 0, 0, truncated=True), previous=64.0, **kwargs) == 0
    assert next_wait(RelayResult(5, 1, 0, truncated=True), previous=64.0, **kwargs) == 0
    assert next_wait(RelayResult(0, 0, 2, truncated=True), previous=64.0, **kwargs) == 0
    assert next_wait(RelayResult(100, 0, 0), previous=0.5, **kwargs) == 0.5
    assert next_wait(RelayResult(0, 3, 0, truncated=True), previous=0.5, **kwargs) == 1.0
    assert next_wait(RelayResult(99, 1, 0), previous=0.5, **kwargs) == 0.5
    assert next_wait(RelayResult(0, 3, 0), previous=0.5, **kwargs) == 1.0
    assert next_wait(RelayResult(0, 3, 0), previous=1.0, **kwargs) == 2.0
    assert next_wait(RelayResult(0, 3, 0), previous=0, **kwargs) == 1.0
    assert next_wait(RelayResult(0, 3, 0), previous=256, **kwargs) == 300.0
    assert next_wait(RelayResult(0, 3, 0), previous=300, **kwargs) == 300.0
    assert next_wait(RelayResult(0, 1, 1), previous=64.0, **kwargs) == 128.0
    assert next_wait(None, previous=2.0, **kwargs) == 4.0
    for progress in (RelayResult(5, 1, 0), RelayResult(0, 0, 0), RelayResult(0, 0, 1)):
        assert next_wait(progress, previous=64.0, **kwargs) == 0.5, progress
    waits: list[float] = []
    previous = 0.5
    for _ in range(9):
        previous = next_wait(RelayResult(0, 1, 0), previous=previous, **kwargs)
        waits.append(previous)
    assert waits == [1, 2, 4, 8, 16, 32, 64, 128, 256]
    assert sum(waits) == 511
    parameters = inspect.signature(next_wait).parameters
    assert "after_fatal_rebuild" in parameters, "next_wait에 after_fatal_rebuild 키워드 인자가 없다(M1)"
    parameter = parameters["after_fatal_rebuild"]
    assert (parameter.kind, parameter.default) == (inspect.Parameter.KEYWORD_ONLY, False)
    rebuilt = {**kwargs, "after_fatal_rebuild": True}
    assert next_wait(RelayResult(0, 0, 0), previous=4.0, **rebuilt) == 4.0
    assert next_wait(RelayResult(0, 0, 0), previous=300.0, **rebuilt) == 300.0
    assert next_wait(RelayResult(0, 0, 0), previous=4.0, **{**zero, "after_fatal_rebuild": True}) == 4.0
    assert next_wait(RelayResult(3, 0, 0), previous=4.0, **rebuilt) == 0.5
    assert next_wait(RelayResult(5, 1, 0), previous=4.0, **rebuilt) == 0.5
    assert next_wait(RelayResult(0, 3, 0), previous=4.0, **rebuilt) == 8.0
    assert next_wait(None, previous=4.0, **rebuilt) == 8.0
    assert next_wait(RelayResult(3, 0, 0, truncated=True), previous=4.0, **rebuilt) == 0
    assert next_wait(RelayResult(0, 0, 2), previous=4.0, **rebuilt) == 0.5
    assert next_wait(RelayResult(0, 0, 0), previous=4.0, after_fatal_rebuild=False, **kwargs) == 0.5


def test_oc_25_producer_build_failures_back_off_and_retry(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-25 — 프로듀서 생성 실패(J6 · K11): build_producer가 처음 두 번 실패(ImproperlyConfigured · KafkaException — 메시지에
    SENTINEL)하고 세 번째에 성공하면 그 반복에서 발행한다. 실패는 로그 + 백오프(0.5 → 1 → 2 s)이고 포트는 처음에 한 번 열렸다
    (생성보다 먼저). 로그는 이벤트 이름 · 예외 클래스와 값 없는 진단 필드뿐이다: KafkaException은 KafkaError 이름
    (kafka_error=_INVALID_ARG), 그 밖(ImproperlyConfigured)은 가장 안쪽 프레임(at=<파일>:<줄>:<함수>) — 본문의 SENTINEL 없음."""
    import prometheus_client

    order: list[str] = []
    producer = ScriptedProducer()

    def build() -> ScriptedProducer:
        order.append("build")
        attempt = order.count("build")
        if attempt == 1:
            raise ImproperlyConfigured(f"KAFKA_CLIENT_CONFIG {SENTINEL}")
        if attempt == 2:
            raise KafkaException(KafkaError(KafkaError._INVALID_ARG, f"Invalid value {SENTINEL}"))
        return producer

    def fake_server(port: int, *_args: object, **_kwargs: object) -> tuple[_FakeServer, None]:
        order.append(f"http:{port}")
        return _FakeServer(), None

    monkeypatch.setattr(relay, "build_producer", build)
    monkeypatch.setattr(prometheus_client, "start_http_server", fake_server)
    waits = _record_waits(monkeypatch)
    events = seed(2)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", "3", "--metrics-port", "9464", "--poll-interval", "0.5")
    assert order == ["http:9464", "build", "build", "build"]
    assert waits == [1.0, 2.0]
    assert sorted(sent.row_id() or "" for sent in producer.sent) == sorted(event.pk for event in events)
    assert owner_rows() == {}
    errors = [line for line in _relay_lines(caplog) if line.startswith("outbox_relay.error ")]
    assert len(errors) == 2, errors
    assert re.fullmatch(r"outbox_relay\.error ImproperlyConfigured at=test_outbox_contract\.py:\d+:build", errors[0])
    assert errors[1] == "outbox_relay.error KafkaException kafka_error=_INVALID_ARG"
    assert SENTINEL not in caplog.text


def test_oc_26_refresh_failure_does_not_back_off_and_is_throttled(
    monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-26 — refresh 분리(J7 · K11 · K12): relay 성공 + refresh_metrics 실패(OperationalError — 원인 psycopg QueryCanceled ·
    메시지에 SENTINEL)는 백오프가 아니다(다음 대기 = 폴링 간격 0.5 s) · 행은 발행된다 · 로그는 이벤트 이름 · 클래스 · SQLSTATE뿐
    (refresh_error OperationalError sqlstate=57014 — 본문 없음) · refresh의 DB 오류 뒤마다 close_old_connections를 부른다(반복 머리
    2 + refresh 오류 3 = 5). 잘린 패스가 연달아 도는 동안(대기 0) refresh는 최소 간격 REFRESH_MIN_INTERVAL_S(1 s)를 지킨다: 간격을
    1시간으로 두면 시작 1회 + 잘리지 않은 마지막 패스 뒤 1회, 0으로 두면 패스마다."""
    assert relay_command.REFRESH_MIN_INTERVAL_S == 1.0
    real_refresh = metrics.refresh_metrics
    attempts: list[int] = []

    def failing_refresh() -> None:
        attempts.append(1)
        try:
            raise psycopg.errors.QueryCanceled(f"canceling statement due to statement timeout {SENTINEL}")
        except psycopg.Error as cause:
            raise OperationalError(f"canceling statement due to statement timeout {SENTINEL}") from cause

    closes: list[int] = []
    real_close = django.db.close_old_connections

    def counted_close(**kwargs: Any) -> None:
        closes.append(1)
        real_close(**kwargs)

    monkeypatch.setattr(metrics, "refresh_metrics", failing_refresh)
    monkeypatch.setattr(relay, "build_producer", ScriptedProducer)
    monkeypatch.setattr(django.db, "close_old_connections", counted_close)
    waits = _record_waits(monkeypatch)
    (event,) = seed(1)
    with caplog.at_level(logging.DEBUG, logger=RELAY_LOGGER):
        call_command("outbox_relay", "--iterations", "2", "--metrics-port", "0", "--poll-interval", "0.5")
    assert waits == [0.5], "refresh 실패가 대기 규칙에 섞였다"
    assert event.pk not in owner_rows()
    assert len(attempts) == 3  # 시작 1 + 잘리지 않은 패스마다 1
    refresh_lines = [line for line in _relay_lines(caplog) if line.startswith("outbox_relay.refresh_error")]
    assert refresh_lines == ["outbox_relay.refresh_error OperationalError sqlstate=57014"] * 3
    assert SENTINEL not in caplog.text
    assert len(closes) == 5, "refresh의 DB 오류 뒤에 연결을 정리하지 않았다"
    monkeypatch.setattr(django.db, "close_old_connections", real_close)

    counted: list[int] = []

    def counting_refresh() -> None:
        counted.append(1)
        real_refresh()

    monkeypatch.setattr(metrics, "refresh_metrics", counting_refresh)
    for interval, expected in ((3600.0, 2), (0.0, 4)):
        counted.clear()
        waits.clear()
        seed(5)
        monkeypatch.setattr(relay_command, "REFRESH_MIN_INTERVAL_S", interval)
        call_command(
            "outbox_relay", "--iterations", "3", "--batch-size", "2", "--metrics-port", "0", "--poll-interval", "0.5"
        )
        assert waits == [0.0, 0.0], interval
        assert len(counted) == expected, f"최소 간격 {interval}: refresh {len(counted)}번"
        assert owner_rows() == {}


# --- D5 지표 ---------------------------------------------------------------------------------------------------------


def test_oc_17_metrics_module_is_imported_lazily() -> None:
    """oc-17 — 지연 등록(D5): 새 프로세스(-I 아님 · 시험 설정 · 같은 시험 DB)에서 django_common.outbox를 import하고 publish 경로를
    거쳐도(atomic 안 publish 뒤 롤백) 기본 REGISTRY에 outbox_pending이 없고 metrics 모듈도 confluent_kafka도 import되지 않는다
    (web 프로세스의 0값 outbox 지표가 MetricsAbsent를 가리지 않게 · publish 경로는 confluent를 불러오지 않는다 — D6). metrics를
    import한 뒤에는 있다. 자식 출력은 JSON 한 줄(불린 · 예외 클래스 이름)뿐이다(자격이 출력에 실리지 않게)."""
    script = (
        "import json, os, sys, uuid\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from django.db import transaction\n"
        "    from prometheus_client import REGISTRY\n"
        "    import django_common.outbox as outbox\n"
        "    with transaction.atomic():\n"
        "        outbox.publish('identity-admin.session.revoked', 'user:oc17', "
        "{'sub': 'oc17', 'sid': None, 'nbf': 1, 'reason': 'logout'}, tenant_id=uuid.UUID(int=17))\n"
        "        transaction.set_rollback(True)\n"
        "    result['metrics_module'] = 'django_common.outbox.metrics' in sys.modules\n"
        "    result['confluent'] = 'confluent_kafka' in sys.modules\n"
        "    result['pending_before'] = REGISTRY.get_sample_value('outbox_pending')\n"
        "    import django_common.outbox.metrics\n"
        "    result['pending_after'] = REGISTRY.get_sample_value('outbox_pending')\n"
        "except Exception as exc:\n"
        "    result['error'] = type(exc).__name__\n"
        "print(json.dumps(result))\n"
    )
    env = {key: value for key, value in os.environ.items() if key.upper() != "PROMETHEUS_MULTIPROC_DIR"}
    env["DJANGO_SETTINGS_MODULE"] = "tests.settings"
    completed = subprocess.run(  # noqa: S603 — 이 인터프리터 · 고정 스크립트
        [sys.executable, "-c", script],
        cwd=PACKAGE_ROOT,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    assert completed.returncode == 0, f"자식 프로세스 종료 코드 {completed.returncode}"
    result = json.loads(completed.stdout.strip().splitlines()[-1])
    assert result == {"metrics_module": False, "confluent": False, "pending_before": None, "pending_after": 0.0}


def test_oc_18_oldest_age_grows_at_scrape_time(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-18 — outbox_oldest_pending_seconds는 스크레이프 시점에 자란다(D5 set_function): pending 1행(created_at = DB now − 120 s)
    refresh 뒤 100 이상 · 1.1 s 뒤에는 refresh 없이 1 이상 커진다(루프가 멈춰도 알림이 울린다) · 행이 없으면 refresh 뒤 0. 나이는
    DB 시계다(refresh 동안 Python 시계를 100일 뒤로 돌려도 같다)."""
    (event,) = seed(1)
    owner_execute("UPDATE outbox SET created_at = now() - interval '120 seconds' WHERE id = %s", [event.pk])
    real_now = timezone.now
    with monkeypatch.context() as patch:
        patch.setattr(timezone, "now", lambda: real_now() + timedelta(days=100))
        metrics.refresh_metrics()
    first = _sample("outbox_oldest_pending_seconds")
    assert 100 <= first < 600
    assert _sample("outbox_pending") == 1
    time.sleep(1.1)
    second = _sample("outbox_oldest_pending_seconds")
    assert second - first >= 1.0
    owner_execute("DELETE FROM outbox")
    metrics.refresh_metrics()
    assert _sample("outbox_oldest_pending_seconds") == 0
    assert _sample("outbox_pending") == 0


# --- D2 모델 · 마이그레이션 · 사실 ⑫ 꼴 상수 --------------------------------------------------------------------------------


def test_oc_19_migration_is_one_create_model_without_rls() -> None:
    """oc-19 — 마이그레이션(D2): `makemigrations django_common --check --dry-run` 변경 없음 · 0001 = CreateModel 하나(db_table
    outbox · 인덱스 2 = outbox_pending_idx (id) WHERE dead_at IS NULL · outbox_dead_at_idx (dead_at) WHERE dead_at IS NOT
    NULL) · RunSQL · RunPython · RLS 없음. 카탈로그: 부분 인덱스 2 · RLS 꺼짐 · created_at 기본값 statement_timestamp() ·
    attempts ≥ 0 검사 · 길이(topic 249 · partition_key 36)."""
    stdout = io.StringIO()
    try:
        call_command("makemigrations", "django_common", "--check", "--dry-run", stdout=stdout, stderr=io.StringIO())
    except SystemExit as exc:
        pytest.fail(f"makemigrations django_common --check가 변경을 찾았다(exit {exc.code}): {stdout.getvalue()}")
    module = importlib.import_module("django_common.migrations.0001_initial")
    operations = module.Migration.operations
    assert len(operations) == 1
    (create,) = operations
    assert isinstance(create, migrations.CreateModel)
    assert create.name == "OutboxEvent"
    assert create.options["db_table"] == "outbox"
    indexes = {index.name: index for index in create.options["indexes"]}
    assert set(indexes) == {"outbox_pending_idx", "outbox_dead_at_idx"}
    assert indexes["outbox_pending_idx"].fields == ["id"]
    assert indexes["outbox_dead_at_idx"].fields == ["dead_at"]
    assert str(indexes["outbox_pending_idx"].condition) == "(AND: ('dead_at__isnull', True))"
    assert str(indexes["outbox_dead_at_idx"].condition) == "(AND: ('dead_at__isnull', False))"

    definitions = dict(
        _owner_all("SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'outbox'")
    )
    assert definitions["outbox_pending_idx"].endswith("(id) WHERE (dead_at IS NULL)")
    assert definitions["outbox_dead_at_idx"].endswith("(dead_at) WHERE (dead_at IS NOT NULL)")
    rls = owner_scalar(
        "SELECT relrowsecurity OR relforcerowsecurity FROM pg_class WHERE oid = 'public.outbox'::regclass"
    )
    assert rls is False
    created_default = owner_scalar(
        "SELECT column_default FROM information_schema.columns"
        " WHERE table_name = 'outbox' AND column_name = 'created_at'"
    )
    assert created_default == "statement_timestamp()"
    checks = [
        row[0]
        for row in _owner_all(
            "SELECT pg_get_constraintdef(oid) FROM pg_constraint"
            " WHERE conrelid = 'public.outbox'::regclass AND contype = 'c'"
        )
    ]
    assert any("attempts >= 0" in check for check in checks), checks
    lengths = dict(
        _owner_all(
            "SELECT column_name, character_maximum_length FROM information_schema.columns"
            " WHERE table_name = 'outbox' AND column_name IN ('id', 'topic', 'partition_key')"
        )
    )
    assert lengths == {"id": 26, "topic": 249, "partition_key": 36}
    assert OutboxEvent._meta.app_label == "django_common"


def test_oc_20_code_patterns_equal_envelope_schema() -> None:
    """oc-20 — 코드의 꼴 상수(사실 ⑫ — pod 이미지에는 packages/events가 없다)가 _envelope.json의 pattern 문자열과 같다: id ·
    source · type · subject · tenantid(봉투에서 pattern을 가진 속성 전부). 시험만 모노레포의 스키마를 읽는다."""
    schema = json.loads(ENVELOPE_SCHEMA.read_text(encoding="utf-8"))
    expected = {
        name: spec["pattern"]
        for name, spec in schema["properties"].items()
        if isinstance(spec, dict) and "pattern" in spec
    }
    assert set(expected) == {"id", "source", "type", "subject", "tenantid"}
    assert {name: pattern.pattern for name, pattern in publisher.ENVELOPE_PATTERNS.items()} == expected
