"""packages/events 스키마 pattern의 Python 쪽 의미 시험(T069 · D12 — T067 r2 리뷰 A2-5 인계 「Python 쪽 pattern 시험 없음」).

T067은 pattern을 ajv(JS · u 플래그)와 Python re(jsonschema — re.search 의미)에서 같은 뜻으로만 쓰기로 했다(계약 events.md §봉투
「패턴 이식성」 · 규칙 .claude/rules/events.md §Schemas): ① 명시 문자 클래스만(역슬래시 d · w · s 금지 — Python은 유니코드 숫자 ·
글자까지 맞춘다) ② 클래스 밖의 맨 점 금지(Python의 점은 CR · U+2028/2029에도 맞는다) ③ 끝 고정 `$(?!` + 줄바꿈 + `)`(Python의 맨
`$`는 끝 줄바꿈 바로 앞에서도 맞는다). JS 쪽은 packages/events/tests/schemas.test.mjs sch-6 · sch-7 · sch-8이 지키고, 이 파일은
같은 사례(출처 줄 주석)를 Python jsonschema Draft202012Validator(format 검사 포함)에 같은 기대값으로 대조한다(두 엔진 대조
53/53의 Python 절반 — build-notes 「T067 결과」 인계).

- tp-1 꼴: 7개 파일의 모든 pattern이 Python re로 컴파일되고 ^로 시작해 끝 고정으로 끝나며 금지 꼴이 없다 · 스캐너 자체 확인.
- tp-2 · tp-3 봉투: sch-7 음성 · 양성 + T069 추가(앞뒤 공백 · 비ASCII 닮은꼴 · 끝 CR).
- tp-4 · tp-5 토픽 data: sch-6 중 pattern 필드의 음성 · 양성 + T069 추가.
- tp-6 대조: 위 규칙을 어긴 변형 pattern(맨 `$` · 맨 점 · 역슬래시 d)은 같은 값을 Python에서 통과시킨다 — 사례가 공허하지 않다.
- tp-7 알려진 차이: Python jsonschema 4.26은 date-time을 검사하지 않는다(rfc3339-validator 미설치 · 계약 events.md 「Python
  소비자」) — 봉투 time의 꼴은 publish 코드가 지킨다(T061 out-3 · 이 파일 tp-8).
- tp-8 DB: publish가 만든 봉투(SP-1 토픽 6 — 토픽마다 그 pod를 OUTBOX_SOURCE로)가 DB에서 읽은 그대로 봉투 · 토픽 스키마를
  통과한다(T061 out-6이 실 Kafka로 보는 것의 DB 쪽 짝).

T069 추가 사례(「T069」 표시)의 기대값은 명시 클래스의 정의에서 나온다 — 이 파일은 ajv를 돌리지 않는다. 제어 문자 · 줄바꿈 값은
chr()로 만든다(소스에 이스케이프를 두지 않는다). tp-1..7은 DB를 쓰지 않는다.
"""

from __future__ import annotations

import hashlib
import json
import re
from collections.abc import Iterator
from datetime import datetime, timedelta
from functools import cache
from pathlib import Path
from typing import TYPE_CHECKING, Any

import pytest
from jsonschema import Draft202012Validator

if TYPE_CHECKING:
    from pytest_django.fixtures import SettingsWrapper

SCHEMAS_DIR = Path(__file__).resolve().parents[3] / "packages" / "events" / "schemas"
END = r"$(?!\n)"
LOOKAHEAD = r"(?!\n)"
BACKSLASH = chr(0x5C)
LF, CR = chr(0x0A), chr(0x0D)
TENANT = "00000000-0000-4000-8000-00000000000a"
EMAIL_HASH = hashlib.sha256(b"user@example.com").hexdigest()
ULID_RE = re.compile(r"^[0-7][0-9A-HJKMNP-TV-Z]{25}$")
# publish가 쓰는 time의 꼴(D3 — UTC ms Z)
TIME_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[.][0-9]{3}Z$")
MEDIA = "media.object.ready"
NOTE = "portfolio-core.note.published"
URL = ("variants", 0, "url")  # media.object.ready의 첫 variant url 경로
# 역슬래시 d · w · s · b · p, 이름 붙은 그룹 · 뒤보기((?<) — sch-8과 같은 금지 꼴
FORBIDDEN = re.compile(r"\\[dDwWsSbBpP]|\(\?<|\(\?P")

# schemas.test.mjs :207-217(SAMPLE_ENVELOPE) · :220-273(SAMPLES)와 같은 표본
SAMPLE_ENVELOPE: dict[str, Any] = {
    "specversion": "1.0",
    "id": "01J8QK3Q9S8ZQ4V7H2M1X0N5AB",
    "source": "identity-admin",
    "type": "identity-admin.session.revoked",
    "time": "2026-09-01T03:21:07.123Z",
    "subject": "user:9f2c-test",
    "tenantid": TENANT,
    "datacontenttype": "application/json",
    "data": {"sub": "9f2c-test", "sid": None, "nbf": 1756696867, "reason": "logout_all"},
}
SAMPLES: dict[str, dict[str, Any]] = {
    "identity-admin.session.revoked": {
        "subject": "user:9f2c-test",
        "data": {"sub": "9f2c-test", "sid": None, "nbf": 1756696867, "reason": "logout_all"},
    },
    "identity-admin.user.registered": {
        "subject": "user:9f2c-test",
        "data": {
            "sub": "9f2c-test",
            "email_hash": EMAIL_HASH,
            "tenant_id": TENANT,
            "role": "owner",
            "registered_at": "2026-09-01T03:21:07.123Z",
        },
    },
    "identity-admin.tenant.created": {
        "subject": f"tenant:{TENANT}",
        "data": {"tenant_id": TENANT, "slug": "joshuatech", "display_name": "JoshuaTech"},
    },
    "portfolio-core.note.published": {
        "subject": "note:events-compat",
        "data": {
            "slug": "events-compat",
            "lang": "ko",
            "title": "이벤트 스키마 호환성 검사",
            "tags": ["events", "json-schema"],
            "published_at": "2026-11-03T09:00:00Z",
            "change": "003-platform-foundation",
        },
    },
    "engagement.comment.created": {
        "subject": "comment:c-01",
        "data": {
            "comment_id": "c-01",
            "target": "note:events-compat",
            "author_sub": "4b1d-test",
            "created_at": "2026-11-03T18:30:00+09:00",
            "body_excerpt": "기준 쪽 검사기 설명이 좋다.",
        },
    },
    "media.object.ready": {
        "subject": "media:m-01",
        "data": {
            "media_id": "m-01",
            "owner_sub": "9f2c-test",
            "kind": "image",
            "variants": [
                {"name": "thumb", "url": "https://media.joshuatech.dev/m-01/thumb.webp"},
                {"name": "original", "url": "https://media.joshuatech.dev/m-01/original.png"},
            ],
            "bytes": 48213,
        },
    },
}

# 봉투 음성 [필드, 값, 출처] — 기대: 그 필드 경로의 오류(sch-7 :781-806 · T069 추가)
ENVELOPE_NEGATIVE: list[tuple[str, str, str]] = [
    ("source", "Identity_Admin", "schemas.test.mjs:781"),
    ("source", "identity-admin-", "schemas.test.mjs:782"),
    ("subject", "9f2c", "schemas.test.mjs:783"),
    ("subject", "User:9f2c", "schemas.test.mjs:784"),
    ("type", "Identity-Admin.session.revoked", "schemas.test.mjs:785"),
    ("type", "a..b.c", "schemas.test.mjs:786"),
    ("type", "../evil", "schemas.test.mjs:787"),
    ("type", "identity-admin.session", "schemas.test.mjs:788"),
    ("type", "identity-admin.session.revoked.", "schemas.test.mjs:789"),
    ("type", "_envelope.x.y", "schemas.test.mjs:790"),
    ("tenantid", "00000000-0000-4000-8000-00000000000A", "schemas.test.mjs:791"),
    ("id", "01j8qk3q9s8zq4v7h2m1x0n5ab", "schemas.test.mjs:792"),
    ("id", "81J8QK3Q9S8ZQ4V7H2M1X0N5AB", "schemas.test.mjs:793"),
    ("id", "01J8QK3Q9S8ZQ4V7H2M1X0N5AB" + LF, "schemas.test.mjs:796"),
    ("source", "identity-admin" + LF, "schemas.test.mjs:797"),
    ("type", "identity-admin.session.revoked" + LF, "schemas.test.mjs:798"),
    ("subject", "user:9f2c-test" + LF, "schemas.test.mjs:799"),
    ("subject", "user:9f2c" + chr(0x0D) + "test", "schemas.test.mjs:801"),
    ("subject", "user:9f2c" + chr(0x09) + "test", "schemas.test.mjs:802"),
    ("subject", "user:9f2c" + chr(0x00) + "test", "schemas.test.mjs:803"),
    ("subject", "user:9f2c" + chr(0x7F), "schemas.test.mjs:804"),
    ("subject", "user:9f2c" + chr(0x85) + "test", "schemas.test.mjs:805"),
    ("subject", "user:", "schemas.test.mjs:806"),
    # T069 추가 — 앞뒤 공백 · 끝 CR · 비ASCII 닮은꼴(전각 · 아라비아 숫자 · 키릴 글자)
    ("type", " identity-admin.session.revoked", "T069 앞 공백"),
    ("type", "identity-admin.session.revoked ", "T069 끝 공백"),
    ("source", "identity-admin" + CR, "T069 끝 CR"),
    ("subject", " user:9f2c-test", "T069 앞 공백"),
    ("subject", "user:9f2c-test" + CR, "T069 끝 CR"),
    ("tenantid", TENANT + " ", "T069 끝 공백"),
    ("tenantid", chr(0x0660) + TENANT[1:], "T069 아라비아-인도 숫자 0(format uuid는 통과 — pattern이 막는다)"),
    ("id", "01J8QK3Q9S8ZQ4V7H2M1X0N5A" + chr(0xFF22), "T069 전각 B"),
    ("source", "identity-" + chr(0x0430) + "dmin", "T069 키릴 a"),
]
# 봉투 양성 [필드, 값, 출처] — sch-7 :814-815(pattern은 통과 — 그 type의 data 스키마 유무는 JS 검사기 몫) · :825-828 · T069 추가
ENVELOPE_POSITIVE: list[tuple[str, str, str]] = [
    ("type", "identity-admin.session.revoked.v2", "schemas.test.mjs:814"),
    ("type", "dev.identity-admin.session.revoked", "schemas.test.mjs:815"),
    ("subject", "user:a" + chr(0xA0) + "b", "schemas.test.mjs:825"),
    ("subject", "note:이벤트-호환성", "schemas.test.mjs:826"),
    ("subject", "user:" + chr(0x1F600), "schemas.test.mjs:827"),
    ("subject", "user:a" + chr(0x2028) + "b", "schemas.test.mjs:828"),
    ("subject", "user:9f2c test ", "T069 id 부분의 공백(제어 문자만 막는다)"),
]
# 토픽 data 음성 [토픽, 경로 조각(필드 · 배열 첨자), 값, 출처] — sch-6 중 pattern 필드 · T069 추가
DATA_NEGATIVE: list[tuple[str, tuple[str | int, ...], str, str]] = [
    ("identity-admin.user.registered", ("tenant_id",), TENANT.upper(), "schemas.test.mjs:674"),
    ("identity-admin.tenant.created", ("tenant_id",), f"urn:uuid:{TENANT}", "schemas.test.mjs:675"),
    ("identity-admin.user.registered", ("email_hash",), EMAIL_HASH.upper(), "schemas.test.mjs:680"),
    ("identity-admin.tenant.created", ("slug",), "-joshuatech", "schemas.test.mjs:684"),
    ("identity-admin.tenant.created", ("slug",), "JoshuaTech", "schemas.test.mjs:685"),
    ("portfolio-core.note.published", ("change",), "3-x", "schemas.test.mjs:690"),
    ("portfolio-core.note.published", ("slug",), "events--compat", "schemas.test.mjs:691"),
    ("portfolio-core.note.published", ("slug",), "Events-Compat", "schemas.test.mjs:692"),
    ("portfolio-core.note.published", ("slug",), "events-compat" + LF, "schemas.test.mjs:716"),
    ("portfolio-core.note.published", ("change",), "003-platform-foundation" + LF, "schemas.test.mjs:717"),
    ("identity-admin.user.registered", ("email_hash",), EMAIL_HASH + LF, "schemas.test.mjs:718"),
    ("identity-admin.tenant.created", ("slug",), "joshuatech" + LF, "schemas.test.mjs:719"),
    ("identity-admin.tenant.created", ("tenant_id",), TENANT + LF, "schemas.test.mjs:720"),
    ("engagement.comment.created", ("target",), "note:events-compat" + LF, "schemas.test.mjs:721"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x0D) + "b", "schemas.test.mjs:723"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x09) + "b", "schemas.test.mjs:724"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x00) + "b", "schemas.test.mjs:725"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x7F), "schemas.test.mjs:726"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x85) + "b", "schemas.test.mjs:727"),
    ("engagement.comment.created", ("target",), "note:", "schemas.test.mjs:728"),
    (MEDIA, URL, "http://media.joshuatech.dev/m-01/thumb.webp", "schemas.test.mjs:730"),
    (MEDIA, URL, "javascript:alert(1)", "schemas.test.mjs:731"),
    (MEDIA, URL, "file:///etc/passwd", "schemas.test.mjs:732"),
    (MEDIA, URL, "https://media.joshuatech.dev/m 01/thumb.webp", "schemas.test.mjs:733"),
    (MEDIA, URL, "https://media.joshuatech.dev/<script>", "schemas.test.mjs:734"),
    (MEDIA, URL, "https://media.joshuatech.dev/파일.png", "schemas.test.mjs:735"),
    (MEDIA, URL, "HTTPS://media.joshuatech.dev/m-01/thumb.webp", "schemas.test.mjs:736"),
    (MEDIA, URL, "https://media.joshuatech.dev/m-01/thumb.webp" + LF, "schemas.test.mjs:737"),
    # T069 추가
    ("identity-admin.tenant.created", ("slug",), " joshuatech", "T069 앞 공백"),
    ("identity-admin.tenant.created", ("slug",), "joshuatech ", "T069 끝 공백"),
    ("identity-admin.tenant.created", ("slug",), "joshuatech" + CR, "T069 끝 CR"),
    ("identity-admin.tenant.created", ("slug",), "joshuatech" + chr(0x2028), "T069 끝 U+2028"),
    ("identity-admin.tenant.created", ("slug",), "joshuat" + chr(0x0435) + chr(0x0441) + "h", "T069 키릴 e · s"),
    (NOTE, ("change",), chr(0x0660) * 2 + chr(0x0663) + "-platform-foundation", "T069 아라비아-인도 숫자"),
    (NOTE, ("change",), chr(0xFF10) * 2 + chr(0xFF13) + "-platform-foundation", "T069 전각 숫자"),
    ("identity-admin.user.registered", ("email_hash",), chr(0xFF10) + EMAIL_HASH[1:], "T069 전각 0"),
    (MEDIA, URL, " https://media.joshuatech.dev/m-01/thumb.webp", "T069 앞 공백"),
]
# 토픽 data 양성 [토픽, 경로 조각, 값, 출처] — sch-6 :762-769(경계값은 통과)
DATA_POSITIVE: list[tuple[str, tuple[str | int, ...], str, str]] = [
    ("engagement.comment.created", ("target",), "note:a" + chr(0xA0) + "b", "schemas.test.mjs:762"),
    ("engagement.comment.created", ("target",), "note:이벤트-호환성", "schemas.test.mjs:763"),
    ("engagement.comment.created", ("target",), "note:" + chr(0x1F600), "schemas.test.mjs:764"),
    ("engagement.comment.created", ("target",), "note:a" + chr(0x2028) + "b", "schemas.test.mjs:765"),
    (MEDIA, URL, "https://cdn.example.com/a/b.webp?x=1&y=2#f", "schemas.test.mjs:767"),
    (MEDIA, URL, "https://[::1]:8443/x", "schemas.test.mjs:768"),
    (MEDIA, URL, "https://example.com/%E2%82%AC'(x)*+,;=~@!$", "schemas.test.mjs:769"),
]


def _schema(name: str) -> dict[str, Any]:
    path = SCHEMAS_DIR / name
    if not path.is_file():
        pytest.fail(f"packages/events 스키마 없음 — T067 선행 ({name})")
    return json.loads(path.read_text(encoding="utf-8"))


@cache
def _validator(name: str) -> Draft202012Validator:
    """packages/events/schemas/<name>의 Draft 2020-12 검증기(format 검사 포함 — re.search 의미)."""
    schema = _schema(name)
    Draft202012Validator.check_schema(schema)
    return Draft202012Validator(schema, format_checker=Draft202012Validator.FORMAT_CHECKER)


def _error_paths(validator: Draft202012Validator, instance: object) -> set[str]:
    return {"#/" + "/".join(str(part) for part in error.absolute_path) for error in validator.iter_errors(instance)}


def _subschemas(node: dict[str, Any], pointer: str = "#") -> Iterator[tuple[str, dict[str, Any]]]:
    """스키마 노드와 그 아래 properties · items · additionalProperties(스키마) 노드(sch-8의 subschemas와 같은 범위)."""
    yield pointer, node
    for name, child in (node.get("properties") or {}).items():
        if isinstance(child, dict):
            yield from _subschemas(child, f"{pointer}/properties/{name}")
    for key in ("items", "additionalProperties"):
        child = node.get(key)
        if isinstance(child, dict):
            yield from _subschemas(child, f"{pointer}/{key}")


def _patterns() -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    for path in sorted(SCHEMAS_DIR.glob("*.json")):
        for pointer, node in _subschemas(_schema(path.name)):
            if isinstance(node.get("pattern"), str):
                found.append((f"{path.name} {pointer}", node["pattern"]))
    return found


def _unescaped_dots(pattern: str) -> list[int]:
    """문자 클래스 밖의 이스케이프되지 않은 점의 위치(schemas.test.mjs :845-861 unescapedDots를 옮겼다)."""
    found: list[int] = []
    in_class = False
    index = 0
    while index < len(pattern):
        char = pattern[index]
        if char == BACKSLASH:
            index += 1  # 다음 글자는 이스케이프된 글자다
        elif in_class:
            if char == "]":
                in_class = False
        elif char == "[":
            in_class = True
        elif char == ".":
            found.append(index)
        index += 1
    return found


def _with(data: Any, path: tuple[str | int, ...], value: object) -> Any:
    """data의 깊은 사본에서 path 자리를 value로 바꾼다."""
    copy = json.loads(json.dumps(data))
    target = copy
    for part in path[:-1]:
        target = target[part]
    target[path[-1]] = value
    return copy


def _envelope_pattern(field: str) -> str:
    return str(_schema("_envelope.json")["properties"][field]["pattern"])


# --- tp-1 꼴 -----------------------------------------------------------------------------------------------------------


def test_tp_1_every_pattern_is_portable_in_python() -> None:
    """tp-1 — 7개 파일의 모든 pattern(봉투 5 + 토픽 8 이상)이 Python re로 컴파일되고 ^로 시작해 끝 고정으로 끝나며(맨 `$` 끝
    없음) 금지 꼴(역슬래시 d · w · s · b · p · 뒤보기 · 이름 그룹)과 클래스 밖의 맨 점이 없다(sch-8 :871-888의 Python 짝 — JS의
    u 플래그 컴파일 대신 Python re 컴파일)."""
    assert len(sorted(SCHEMAS_DIR.glob("*.json"))) == 7
    patterns = _patterns()
    assert len(patterns) >= 13
    for where, pattern in patterns:
        re.compile(pattern)
        assert pattern.startswith("^"), where
        assert pattern.endswith(END), f"{where}: 끝은 $(?!줄바꿈)이어야 한다"
        assert FORBIDDEN.search(pattern) is None, f"{where}: 금지 꼴"
        assert _unescaped_dots(pattern) == [], f"{where}: 클래스 밖의 맨 점"


def test_tp_1b_dot_scanner_self_check() -> None:
    """tp-1b — 스캐너 자체 확인(sch-8 :864-869): 클래스 밖의 맨 점만 센다 · 이스케이프된 점 · 클래스 안의 점은 세지 않는다 ·
    이스케이프된 닫는 괄호는 클래스를 닫지 않는다."""
    assert _unescaped_dots("^a.b$") == [2]
    assert _unescaped_dots(r"^a\.b[.x]c$") == []
    assert _unescaped_dots(r"^[\].]x.$") == [7]
    assert _unescaped_dots(r"^[^\x00-\x1f]+$(?!\n)") == []


# --- tp-2 · tp-3 봉투 --------------------------------------------------------------------------------------------------


@pytest.mark.parametrize(("field", "value", "origin"), ENVELOPE_NEGATIVE)
def test_tp_2_envelope_negative(field: str, value: str, origin: str) -> None:
    """tp-2 — 봉투 음성(sch-7 :781-806 + T069 추가): 그 필드 경로의 오류가 있다(Python re.search 의미)."""
    envelope = {**json.loads(json.dumps(SAMPLE_ENVELOPE)), field: value}
    assert f"#/{field}" in _error_paths(_validator("_envelope.json"), envelope), origin


@pytest.mark.parametrize(("field", "value", "origin"), ENVELOPE_POSITIVE)
def test_tp_3_envelope_positive(field: str, value: str, origin: str) -> None:
    """tp-3 — 봉투 양성(sch-7 :814-815 · :825-828 + T069 추가): 오류가 없다."""
    envelope = {**json.loads(json.dumps(SAMPLE_ENVELOPE)), field: value}
    assert _error_paths(_validator("_envelope.json"), envelope) == set(), origin


# --- tp-4 · tp-5 토픽 data ---------------------------------------------------------------------------------------------


def test_tp_4_samples_pass_and_data_negatives_fail() -> None:
    """tp-4 — 토픽 표본 6(schemas.test.mjs SAMPLES)은 오류가 없고, 음성(sch-6 중 pattern 필드 + T069 추가)은 그 경로 하나에만
    오류가 있다(format uuid도 같은 경로 — 경로 집합으로 본다)."""
    envelope_validator = _validator("_envelope.json")
    for topic, sample in SAMPLES.items():
        envelope = {**SAMPLE_ENVELOPE, "type": topic, "subject": sample["subject"], "data": sample["data"]}
        assert _error_paths(envelope_validator, envelope) == set(), topic
        assert _error_paths(_validator(f"{topic}.json"), sample["data"]) == set(), topic
    for topic, path, value, origin in DATA_NEGATIVE:
        data = _with(SAMPLES[topic]["data"], path, value)
        expected = "#/" + "/".join(str(part) for part in path)
        assert _error_paths(_validator(f"{topic}.json"), data) == {expected}, origin


@pytest.mark.parametrize(("topic", "path", "value", "origin"), DATA_POSITIVE)
def test_tp_5_data_positive(topic: str, path: tuple[str | int, ...], value: str, origin: str) -> None:
    """tp-5 — 토픽 data 경계값(sch-6 :762-769)은 통과한다(제어 문자만 막는다 · https URL의 RFC 3986 글자)."""
    data = _with(SAMPLES[topic]["data"], path, value)
    assert _error_paths(_validator(f"{topic}.json"), data) == set(), origin


# --- tp-6 대조 · tp-7 알려진 차이 ----------------------------------------------------------------------------------------


def test_tp_6_rule_breaking_variants_would_pass_in_python() -> None:
    """tp-6 — 사례가 공허하지 않다: 규칙을 어긴 변형 pattern은 같은 값을 Python re.search에서 통과시킨다.

    ③ 끝을 맨 `$`로 둔 변형은 끝 줄바꿈 값(sch-6 :716-721 · sch-7 :796-799)을 통과시킨다 · ② subject의 id 부분을 맨 점으로 둔
    변형은 CR이 든 값(:801)을 통과시킨다 · ① change를 역슬래시 d로 둔 변형은 아라비아-인도 숫자(T069 추가)를 통과시킨다.
    실제 pattern은 셋 다 거부한다.
    """
    trailing = [(field, value) for field, value, _ in ENVELOPE_NEGATIVE if value.endswith(LF)]
    assert len(trailing) == 4
    for field, value in trailing:
        pattern = _envelope_pattern(field)
        bare = pattern.removesuffix(LOOKAHEAD)
        assert bare.endswith("$") and bare != pattern
        assert re.search(pattern, value) is None, field
        assert re.search(bare, value) is not None, f"{field}: 맨 $ 변형이 끝 줄바꿈을 막는다(사례가 공허하다)"
    data_trailing = [entry for entry in DATA_NEGATIVE if entry[2].endswith(LF)]
    assert len(data_trailing) == 7
    for topic, path, value, origin in data_trailing:
        node: dict[str, Any] = _schema(f"{topic}.json")
        for part in path:
            node = node["items"] if isinstance(part, int) else node["properties"][part]
        bare = node["pattern"].removesuffix(LOOKAHEAD)
        assert re.search(node["pattern"], value) is None, origin
        assert re.search(bare, value) is not None, origin

    subject = _envelope_pattern("subject")
    control_class = r"[^\x00-\x1f\x7f-\x9f]"
    assert control_class in subject
    dotted = subject.replace(control_class, ".")
    with_cr = "user:9f2c" + chr(0x0D) + "test"
    assert re.search(subject, with_cr) is None
    assert re.search(dotted, with_cr) is not None

    change = str(_schema("portfolio-core.note.published.json")["properties"]["change"]["pattern"])
    assert change.startswith("^[0-9]{3}-")
    digits = change.replace("[0-9]", BACKSLASH + "d", 1)
    arabic = chr(0x0660) * 2 + chr(0x0663) + "-platform-foundation"
    assert re.search(change, arabic) is None
    assert re.search(digits, arabic) is not None


def test_tp_7_python_does_not_check_date_time() -> None:
    """tp-7 — 알려진 차이(계약 events.md 「Python 소비자」): ajv는 시간대 없는 time을 거부하지만(sch-7 :794) Python jsonschema
    4.26은 date-time 형식을 검사하지 않아 통과시킨다(rfc3339-validator 미설치 — 사실 ⑪). 그래서 봉투 time의 꼴은 publish 코드가
    지킨다(tp-8 · T061 out-3). rfc3339-validator가 설치되면 이 시험이 뒤집힌다 — 그때 계약과 함께 고친다."""
    envelope = {**SAMPLE_ENVELOPE, "time": "2026-09-01T03:21:07"}
    assert _error_paths(_validator("_envelope.json"), envelope) == set()
    assert "date-time" not in Draft202012Validator.FORMAT_CHECKER.checkers


# --- tp-8 publish가 만든 봉투 --------------------------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True, databases=["default", "owner"])
def test_tp_8_published_envelopes_pass_both_schemas(settings: SettingsWrapper) -> None:
    """tp-8 — publish가 만든 봉투(SP-1 토픽 6 · 토픽마다 OUTBOX_SOURCE = 그 pod · tenant_id 인자)를 DB(owner)에서 읽은 그대로
    봉투 스키마와 토픽 data 스키마가 통과시키고, 봉투 time은 UTC ms Z 꼴 · id는 ULID 대문자 · tenantid는 소문자다."""
    from django.db import transaction

    from django_common.outbox import OutboxEvent, publish

    published = {}
    for topic, sample in SAMPLES.items():
        settings.OUTBOX_SOURCE = topic.split(".", 1)[0]
        with transaction.atomic():
            event = publish(topic, sample["subject"], sample["data"], tenant_id=TENANT.upper())
        published[event.pk] = topic
    rows = {row.pk: row for row in OutboxEvent.objects.using("owner").all()}
    assert set(rows) == set(published)
    envelope_validator = _validator("_envelope.json")
    for pk, topic in published.items():
        envelope = rows[pk].payload
        assert _error_paths(envelope_validator, envelope) == set(), topic
        assert _error_paths(_validator(f"{topic}.json"), envelope["data"]) == set(), topic
        assert (envelope["type"], envelope["source"], envelope["tenantid"]) == (topic, topic.split(".", 1)[0], TENANT)
        assert ULID_RE.fullmatch(envelope["id"]) and envelope["id"] == pk
        assert TIME_RE.fullmatch(envelope["time"]), envelope["time"]
        sent_at = datetime.fromisoformat(envelope["time"])
        assert sent_at.utcoffset() == timedelta(0)
