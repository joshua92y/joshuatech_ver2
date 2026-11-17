"""publish — outbox INSERT(T069 · D3 · r2 J1 · J2 · J9 · r3 K10 · 계약 events.md §발행 API 「입력 검사와 순서」 · 규칙
django-pod.md §Outbox and events).

publish(topic, subject, data, *, tenant_id=None) -> OutboxEvent는 호출자 트랜잭션 안에 행 하나를 INSERT한다(네트워크 I/O 0 ·
Kafka에 닿지 않는다 — 릴레이가 보낸다). 설정은 호출 시점에 읽는다. 아래 순서로 검사하고, 어기면 INSERT 전에 OutboxUsageError다
(메시지는 규칙 이름만 — 값 · data를 싣지 않는다 · `from None`이라 트레이스백이 원인 예외의 값을 싣지 않는다):

1. default 연결이 transaction.atomic() 안이다(웹훅 · 관리 명령처럼 요청 트랜잭션이 없는 경로는 뷰가 atomic을 직접 연다).
2. topic이 str이고 봉투 type pattern(논리 토픽 — 점으로 나뉜 kebab 토큰 셋 이상)에 맞고, 첫 점 앞이 OUTBOX_SOURCE(자기 pod — env
   접두가 붙은 토픽 · 다른 pod의 토픽 · 이름만 같은 다른 pod는 거부)이며, OUTBOX_TOPIC_PREFIX + topic이 249자 이하다.
3. subject가 봉투 subject pattern(`<종류>:<id>` — id 부분에 제어 문자 없음)에 맞는다.
4. data가 dict다(라이브러리는 키를 더하거나 바꾸지 않는다).
5. 테넌트: tenant_id가 uuid.UUID면 그대로, str이면 uuid.UUID(s)로 파싱해 정규화한다(대문자 · 중괄호 · urn:uuid: · 하이픈 없는 꼴 →
   소문자 8-4-4-4-12). 그 밖의 타입 · 파싱 실패는 거부. 컨텍스트는 tenancy.current_tenant_id()로 읽는다(GUC 파손 = ValueError →
   거부 · fail-closed). 둘 다 있고 다르면(UUID 값 비교) 거부, 둘 다 없으면 거부.
6. data가 jsonb에 그대로 저장 · 왕복되는 꼴이다(J1 — 한 번의 반복 순회 · 재귀 없음 · _check_data):
   - 값은 dict(키는 str만) · list · str · int(bool 포함) · float · None만이다(tuple · datetime · UUID · Decimal · bytes · set 등은
     거부 — json.dumps가 tuple을 list로, int 키를 "1"로 조용히 바꾼다).
   - 깊이는 MAX_DATA_DEPTH(64) 이하다(data 자신이 깊이 1 · dict · list마다 1 — 플랫폼의 C 재귀 한도와 무관하고, 순환 참조도 여기서
     끝난다).
   - str 키 · 값에 NUL(U+0000)이 없다(jsonb가 받지 않는다 — INSERT의 22P05).
   - float는 유한하고 float.__repr__에 지수(`e`)가 없다(PG numeric은 지수를 펼쳐 쓴다 — 1e300 → 301자리 · 1e-300 → 소수 300자리 ·
     1e16 이상은 다시 읽으면 int).
   - 같은 순회가 PG jsonb 텍스트 바이트의 하한(str = 글자 수 + 따옴표 · 키 = 글자 수 + 4(따옴표 · `: `) · int = bit_length로 센
     자릿수 하한 · float = repr 길이 · bool · None = 4 · 컨테이너 = 괄호 2 + 구분자 `, ` × (원소 수 − 1))을 세고, 하한이
     MAX_EVENT_BYTES를 넘으면 곧바로 ⑦로 거부한다 — 같은 객체를 여러 번 가리키는 data(공유 참조)가 펼쳐지며 순회 · 직렬화가
     커지기 전에 멈춘다(받는 data의 집합은 그대로다 — 하한이 넘으면 ⑦의 정확한 값도 넘는다).
   - 일시 메모리(K10): 컨테이너를 만나면 괄호와 구분자를 하한에 먼저 더해 비교하고, 자식은 한꺼번에 스택에 넣지 않고 컨테이너
     마다의 반복자에서 차례로 꺼낸다 — 스택은 깊이(≤ 64)만큼의 반복자뿐이라, 넓은 컨테이너(정수 2,000,000개 list 등)를 거부할
     때 그 폭에 비례하는 메모리를 잡지 않는다(r2는 자식을 다 쌓은 뒤에야 하한을 봐 정점 약 129 MB — 리뷰 r2 B2-6).
   위반은 「JSON」이다. 직렬화(아래 jsonb_text)의 TypeError · ValueError(4300자리를 넘는 int · 짝 없는 서로게이트의 UTF-8 실패 등)
   · RecursionError도 「JSON」이다(보조). 하한이 상한을 먼저 넘으면 뒤에 있는 ⑥ 위반을 보기 전에 「크기」로 거부할 수 있다(받는
   data의 집합은 같고 메시지만 다르다 — 계약 ⑦).
7. 크기 = 릴레이가 보낼 바이트(J2): 봉투 {specversion "1.0", id = new_ulid(), source, type = topic, time = UTC ms `Z`, subject,
   tenantid, datacontenttype "application/json", data}의 jsonb_text 길이(PG jsonb 텍스트와 같은 꼴 — 쉼표 · 콜론 뒤 공백 ·
   ensure_ascii=False · UTF-8)가 MAX_EVENT_BYTES(900,000 — 브로커 message.max.bytes 1,000,000에 헤더 여유) 이하다(메인 · DLQ 둘
   다 영원히 실패하는 메시지를 막는다). ⑥의 float 규칙이 있어야 이 측정이 PG의 payload::text 길이와 같다(키 순서는 PG가 바꾸지만
   길이는 같다 — 시험 oc-21).
8. OutboxEvent(id, topic, partition_key = str(tenant), payload = 봉투)를 default 연결에 만든다.

봉투는 SDK 없이 dict로 만든다(plan의 「cloudevents 2.2」는 Python SDK 판 번호 — 쓰지 않는다). pod 이미지는 packages/events를 담지
않으므로 꼴 검사는 ENVELOPE_PATTERNS 상수다 — _envelope.json의 pattern 문자열과 같은지는 시험(oc-20)이 지킨다. pattern은 Python
re.search 의미로 쓴다(jsonschema와 같다 — 끝 고정이 `$` 뒤 줄바꿈 부정 앞보기라 끝 줄바꿈이 통과하지 않는다).

설정(django.conf.settings · 호출 시점): OUTBOX_SOURCE(pod 이름 — 봉투 source pattern이 아니면 ImproperlyConfigured) ·
OUTBOX_TOPIC_PREFIX(""(prod) 또는 "dev."(dev)만 — 아니면 ImproperlyConfigured). 오류는 설정 이름만 싣는다.
"""

from __future__ import annotations

import json
import math
import re
import uuid
from collections.abc import Iterator, Mapping
from datetime import UTC, datetime
from typing import Any

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.db import DEFAULT_DB_ALIAS, connections

from django_common.outbox._ulid import new_ulid
from django_common.outbox.models import OutboxEvent
from django_common.tenancy import current_tenant_id

__all__ = [
    "ENVELOPE_PATTERNS",
    "MAX_DATA_DEPTH",
    "MAX_EVENT_BYTES",
    "MAX_TOPIC_LENGTH",
    "OutboxUsageError",
    "jsonb_text",
    "outbox_source",
    "publish",
    "topic_prefix",
]

# 봉투 pattern(_envelope.json의 문자열 그대로 · Python re.search 의미). tenantid · id는 이 모듈이 만드는 값의 꼴이다(str(UUID) ·
# new_ulid는 늘 맞는다) — id 꼴은 명령 outbox_requeue의 --id 검사가 쓴다.
ENVELOPE_PATTERNS: Mapping[str, re.Pattern[str]] = {
    "id": re.compile(r"^[0-7][0-9A-HJKMNP-TV-Z]{25}$(?!\n)"),
    "source": re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*$(?!\n)"),
    "type": re.compile(r"^[a-z][a-z0-9]*(-[a-z0-9]+)*(\.[a-z][a-z0-9]*(-[a-z0-9]+)*){2,}$(?!\n)"),
    "subject": re.compile(r"^[a-z][a-z0-9-]*:[^\x00-\x1f\x7f-\x9f]+$(?!\n)"),
    "tenantid": re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$(?!\n)"),
}
MAX_EVENT_BYTES = 900_000
MAX_DATA_DEPTH = 64
MAX_TOPIC_LENGTH = 249  # Kafka 토픽 이름 상한(env 접두 포함)
_SOURCE_SETTING = "OUTBOX_SOURCE"
_PREFIX_SETTING = "OUTBOX_TOPIC_PREFIX"
_PREFIXES = ("", "dev.")
_NUL = chr(0)
_DONE = object()  # 자식 반복자가 끝났다는 표시(next의 기본값)
_JSON_RULE = (
    "publish: data는 jsonb에 그대로 저장·왕복되는 꼴이어야 한다(dict(str 키) · list · str · int · float · bool · None · 깊이 "
    f"{MAX_DATA_DEPTH} 이하 · NUL 없음 · 유한하고 지수 꼴이 아닌 float · 직렬화 가능)"
)
_SIZE_RULE = f"publish: 릴레이가 보낼 봉투(PG jsonb 텍스트 꼴 UTF-8)가 {MAX_EVENT_BYTES}바이트를 넘는다"


class OutboxUsageError(Exception):
    """publish 사용 규칙 위반(계약 §발행 API) — 메시지는 규칙 이름만 싣는다(값 · data 없음)."""


def outbox_source() -> str:
    """설정 OUTBOX_SOURCE(pod 이름 · 봉투 source · ce_source · DLQ 이름의 재료)를 지금 읽는다."""
    value = getattr(settings, _SOURCE_SETTING, None)
    if not isinstance(value, str) or ENVELOPE_PATTERNS["source"].search(value) is None:
        raise ImproperlyConfigured(f"{_SOURCE_SETTING}는 pod 이름(봉투 source 꼴 — kebab-case)이어야 한다")
    return value


def topic_prefix() -> str:
    """설정 OUTBOX_TOPIC_PREFIX(Kafka 토픽 · DLQ 앞의 env 접두 — prod "" · dev "dev.")를 지금 읽는다."""
    value = getattr(settings, _PREFIX_SETTING, None)
    if not isinstance(value, str) or value not in _PREFIXES:
        raise ImproperlyConfigured(f'{_PREFIX_SETTING}는 ""(prod) 또는 "dev."(dev)이어야 한다')
    return value


def jsonb_text(value: object) -> bytes:
    """value를 PG jsonb 텍스트(payload::text)와 같은 꼴의 UTF-8로(쉼표 · 콜론 뒤 공백 · ensure_ascii=False · allow_nan=False)."""
    return json.dumps(value, ensure_ascii=False, separators=(", ", ": "), allow_nan=False).encode("utf-8")


def _digits_floor(value: int) -> int:
    """|value|의 십진 자릿수 하한(bit_length로 센다 — 문자열로 바꾸지 않는다 · log10(2) > 0.3)."""
    return max(1, (abs(value).bit_length() - 1) * 3 // 10 + 1)


def _check_data(data: dict[str, Any]) -> None:
    """⑥ jsonb 왕복 꼴(한 번의 반복 순회) + ⑦의 바이트 하한(넘으면 곧바로 ⑦) — 규칙은 모듈 독스트링.

    스택 원소 = (자식 반복자 · 자식 깊이 · dict 여부) — 컨테이너마다 하나라 스택 길이는 깊이(≤ MAX_DATA_DEPTH)를 넘지 않는다."""
    floor = 0
    stack: list[tuple[Iterator[Any], int, bool]] = []
    value: object = data
    depth = 1
    while True:
        if isinstance(value, str):
            if _NUL in value:
                raise OutboxUsageError(_JSON_RULE) from None
            floor += len(value) + 2
        elif isinstance(value, dict | list):
            if depth > MAX_DATA_DEPTH:
                raise OutboxUsageError(_JSON_RULE) from None
            floor += 2 + 2 * max(len(value) - 1, 0)  # 아래 하한 비교가 자식을 하나도 꺼내기 전에 돈다
            if isinstance(value, dict):
                stack.append((iter(value.items()), depth + 1, True))
            else:
                stack.append((iter(value), depth + 1, False))
        elif value is None or isinstance(value, bool):
            floor += 4
        elif isinstance(value, int):
            floor += _digits_floor(value)
        elif isinstance(value, float):
            text = float.__repr__(value)
            if not math.isfinite(value) or "e" in text:
                raise OutboxUsageError(_JSON_RULE) from None
            floor += len(text)
        else:
            raise OutboxUsageError(_JSON_RULE) from None
        if floor > MAX_EVENT_BYTES:
            raise OutboxUsageError(_SIZE_RULE) from None
        while stack:
            children, depth, is_dict = stack[-1]
            entry = next(children, _DONE)
            if entry is not _DONE:
                break
            stack.pop()
        else:
            return
        if is_dict:
            key, value = entry
            if not isinstance(key, str) or _NUL in key:
                raise OutboxUsageError(_JSON_RULE) from None
            floor += len(key) + 4
        else:
            value = entry


def _utc_time() -> str:
    """지금 UTC를 RFC 3339 ms `Z` 꼴로(isoformat의 +00:00을 Z로 — 계약 예시 2026-09-01T03:21:07.123Z)."""
    return datetime.now(UTC).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _resolve_tenant(tenant_id: object) -> uuid.UUID:
    """⑤ 테넌트 확정 — 인자(정규화) · 컨텍스트(current_tenant_id) · 충돌 · 없음."""
    argument: uuid.UUID | None
    if tenant_id is None:
        argument = None
    elif isinstance(tenant_id, uuid.UUID):
        argument = tenant_id
    elif isinstance(tenant_id, str):
        try:
            argument = uuid.UUID(tenant_id)
        except (ValueError, AttributeError, TypeError):
            raise OutboxUsageError("publish: tenant_id가 UUID로 파싱되지 않는다(slug 금지)") from None
    else:
        raise OutboxUsageError("publish: tenant_id는 uuid.UUID 또는 UUID 문자열이어야 한다") from None
    try:
        context = current_tenant_id(using=DEFAULT_DB_ALIAS)
    except ValueError:
        raise OutboxUsageError("publish: 테넌트 컨텍스트(GUC app.tenant_id)가 UUID 꼴이 아니다") from None
    if argument is not None and context is not None and argument != context:
        raise OutboxUsageError("publish: tenant_id 인자가 요청의 테넌트 컨텍스트와 다르다") from None
    tenant = argument if argument is not None else context
    if tenant is None:
        raise OutboxUsageError("publish: 테넌트 컨텍스트도 tenant_id 인자도 없다") from None
    return tenant


def publish(topic: str, subject: str, data: dict[str, Any], *, tenant_id: uuid.UUID | str | None = None) -> OutboxEvent:
    """이벤트 하나를 outbox에 쓴다(호출자 트랜잭션 · 네트워크 0) — 검사 순서와 규칙은 모듈 독스트링."""
    if not connections[DEFAULT_DB_ALIAS].in_atomic_block:
        raise OutboxUsageError("publish: transaction.atomic() 안에서만 부를 수 있다") from None
    source = outbox_source()
    prefix = topic_prefix()
    if (
        not isinstance(topic, str)
        or ENVELOPE_PATTERNS["type"].search(topic) is None
        or topic.split(".", 1)[0] != source
        or len(prefix + topic) > MAX_TOPIC_LENGTH
    ):
        raise OutboxUsageError(
            f"publish: 토픽은 자기 pod의 논리 토픽(<{_SOURCE_SETTING}>.<entity>.<event> · env 접두 없음 · 접두 포함"
            f" {MAX_TOPIC_LENGTH}자 이하)이어야 한다"
        ) from None
    if not isinstance(subject, str) or ENVELOPE_PATTERNS["subject"].search(subject) is None:
        raise OutboxUsageError("publish: subject는 <종류>:<id> 꼴(id 부분에 제어 문자 없음)이어야 한다") from None
    if not isinstance(data, dict):
        raise OutboxUsageError("publish: data는 dict여야 한다") from None
    tenant = _resolve_tenant(tenant_id)
    _check_data(data)
    event_id = new_ulid()
    envelope = {
        "specversion": "1.0",
        "id": event_id,
        "source": source,
        "type": topic,
        "time": _utc_time(),
        "subject": subject,
        "tenantid": str(tenant),
        "datacontenttype": "application/json",
        "data": data,
    }
    try:
        size = len(jsonb_text(envelope))
    except (TypeError, ValueError, RecursionError):
        raise OutboxUsageError(_JSON_RULE) from None
    if size > MAX_EVENT_BYTES:
        raise OutboxUsageError(_SIZE_RULE) from None
    return OutboxEvent.objects.using(DEFAULT_DB_ALIAS).create(
        id=event_id, topic=topic, partition_key=str(tenant), payload=envelope
    )
