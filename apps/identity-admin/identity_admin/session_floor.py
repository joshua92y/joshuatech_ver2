"""세션 하한 · 절대 수명(T073 설계 D29 — pod 소유 새 파일) — 상수 · 하한 조회(read_floor) · 판정(is_active).

정본: data-model.md §3(키 `identity-admin:session-floor:{sub}` · `identity-admin:sid-floor:{sid}` · 보존) · contracts/denylist.md
§키 스키마 · §조회 규약 7 · contracts/identity-admin-api.md §엔드포인트 `/session/check` · 설계 D29 「상수」 · 「판정식」 · D8 3 ·
4단계 · t086-design.md D15(UD-7a(ㄴ) — 세션 단위 하한 T-c · 값 판독).

- REVOCATION_LOG_RETENTION: 로그 purge 경계(D14) · 세션 하한 수명(D13 · D14 SQL 매개변수) · `/session/check`의 세션 절대 수명이
  함께 쓰는 상수 하나다 — env 설정으로 열지 않는다(셋이 따로 움직이면 조용히 열린다). SQL에는 `interval '30 days'` 리터럴을
  쓰지 않고 이 값을 매개변수로 넘긴다(psycopg가 timedelta를 interval로 옮긴다). 쓰는 쪽은 호출할 때 모듈 속성으로 읽는다
  (`session_floor.REVOCATION_LOG_RETENTION` — `from … import`로 묶지 않는다: 시험이 이 값을 덮어 본다).
- SESSION_ABSOLUTE_LIFETIME: 같은 객체의 별칭이다(뜻을 드러내는 이름일 뿐 값을 따로 두지 않는다 — 하한 수명 ≥ 세션 최대
  나이라는 불변식이 늘 성립한다).
- FUTURE_IAT_TOLERANCE_S: pod 시계보다 이만큼 넘게 앞선 세션 시작 시각(`iat`)은 inactive다.
- FLOOR_KEY_PREFIX: 세션 하한 키 접두(자기 접두 `identity-admin:` 아래 — `revoked:` 아래가 아니다 · Celery 키와는 하위 이름
  `session-floor:`로 가른다).
- SID_FLOOR_KEY_PREFIX: 세션 단위 하한 키 접두(UD-7a(ㄴ) T-c — 같은 자기 접두 아래 하위 이름 `sid-floor:` · ACL · aclfile 변경
  없음). 값 = 그 sid 행 가운데 가장 큰 nbf · 수명 = 그 행 expires_at + 30 d(쓰기는 denylist_writer.apply_sid · reapply).

함수
- read_floor(sub, sid=None) -> (하한, 세션 단위 하한): 쓰기 클라이언트(`denylist_writer.client()` — 0.2 s · 재시도 0 · 호출마다
  모듈 속성으로 얻는다)로 파이프라인 1회(`transaction=False`) — `GET identity-admin:session-floor:{sub}` + sid가 있으면 `GET
  identity-admin:sid-floor:{sid}`(왕복 하나 · UD-7a(ㄴ)). 키마다 없으면 None, 있으면 정수다(sid를 묻지 않았으면 둘째는 None).
  조회가 실패하거나 두 값 가운데 하나라도 정규 꼴이 아니면 WARNING `session_floor.lookup_failed error=<예외 클래스 이름>`을
  남기고 `DenylistUnavailable`을 올린다 — 실패를 값으로 돌려주지 않는다(fail-closed · DB로 메우지 않는다 · 두 키 같은 규칙 ·
  같은 실패). 정규 꼴 = ASCII 숫자 1-19자(`FLOOR_VALUE_PATTERN` fullmatch — 쓰는 쪽은 `str(nbf)`(0 이상 정수)만 쓴다). 그 밖
  (음수 · 앞뒤 공백 · `+7` · `1_000` · 빈 값 · 20자리 이상)은 손상이라 「정수가 아닌 값」과 같은 실패다(`int()`로 읽으면 음수가
  「하한 없음」처럼 조용히 통과한다 — 열림). 로그 · 예외에 sub · sid · URL · 예외 문구를 싣지 않는다.
  `denylist_writer`는 이 모듈의 상수를 쓰므로 그 모듈을 머리가 아니라 이 함수 안에서 가져온다(순환 import를 만들지 않는다).
- is_active(*, record, floor, sid_floor=None, iat, now): 순수 함수 — 아래 다섯이 모두 아닐 때만 참이다. ① `record.revokes(iat)`
  (revoked:sub 값 > iat 또는 revoked:sid 값 > iat — UD-7a 보정: 이전 「revoked:sid 존재」) ② 하한이 있고 하한 > iat ③ 세션 단위
  하한이 있고 > iat(①–③ 모두 같으면 active) ④ now - iat > 세션 절대 수명(초 — 호출 때 상수에서 계산한다) ⑤ iat > now +
  FUTURE_IAT_TOLERANCE_S. `iat`은 BFF 세션 시작 시각(쿠키 issued_at)이고 `now`는 pod 시계다. `sid_floor` 기본값 None — sid를
  묻지 않은 판정(순수 함수 시험)이 그대로 부른다.
"""

from __future__ import annotations

import re
from datetime import timedelta
from typing import TYPE_CHECKING

import structlog
from django_common.auth import DenylistUnavailable

if TYPE_CHECKING:
    from django_common.auth import DenylistRecord

__all__ = [
    "FLOOR_KEY_PREFIX",
    "FLOOR_VALUE_PATTERN",
    "FUTURE_IAT_TOLERANCE_S",
    "REVOCATION_LOG_RETENTION",
    "SESSION_ABSOLUTE_LIFETIME",
    "SID_FLOOR_KEY_PREFIX",
    "is_active",
    "read_floor",
]

REVOCATION_LOG_RETENTION = timedelta(days=30)
SESSION_ABSOLUTE_LIFETIME = REVOCATION_LOG_RETENTION
FUTURE_IAT_TOLERANCE_S = 60
FLOOR_KEY_PREFIX = "identity-admin:session-floor:"
SID_FLOOR_KEY_PREFIX = "identity-admin:sid-floor:"  # 세션 단위 하한(UD-7a(ㄴ) T-c — t086-design.md D15)
# 하한 값의 정규 꼴 — ASCII 숫자 1-19자(fullmatch · 클라이언트는 bytes를 준다 · decode_responses 끔). `\d`는 쓰지 않는다(bytes
# 패턴에서도 뜻은 같지만 str 패턴에서는 비ASCII 숫자까지 맞는다 — 한 가지 꼴로 둔다).
FLOOR_VALUE_PATTERN = re.compile(rb"[0-9]{1,19}")

log = structlog.get_logger(__name__)


class FloorValueMalformed(ValueError):
    """하한 키 값이 정규 꼴(ASCII 숫자 1-19자)이 아니다 — 값은 싣지 않는다(로그에는 이 클래스 이름만 남는다)."""


def _floor_value(raw: object) -> int | None:
    """하한 키 값 하나(GET 결과)의 판독 — 키가 없으면 None · 정규 꼴이면 정수 · 그 밖은 FloorValueMalformed(값 없음)."""
    if raw is None:
        return None
    if not isinstance(raw, bytes) or FLOOR_VALUE_PATTERN.fullmatch(raw) is None:
        raise FloorValueMalformed()
    return int(raw)


def read_floor(sub: str, sid: str | None = None) -> tuple[int | None, int | None]:
    """세션 하한 `identity-admin:session-floor:{sub}`과 (sid가 있으면) 세션 단위 하한 `identity-admin:sid-floor:{sid}`의 값
    (정수 · 키가 없거나 묻지 않았으면 None)을 파이프라인 1회로 — 실패 · 정규 꼴이 아닌 값(어느 키든)은 DenylistUnavailable."""
    from identity_admin import denylist_writer  # 순환 import 방지(denylist_writer가 이 모듈의 상수를 쓴다)

    failure: str | None = None
    floors: tuple[int | None, int | None] = (None, None)
    try:
        with denylist_writer.client().pipeline(transaction=False) as pipe:
            pipe.get(f"{FLOOR_KEY_PREFIX}{sub}")
            if sid is not None:
                pipe.get(f"{SID_FLOOR_KEY_PREFIX}{sid}")
            values = pipe.execute()
        floors = (_floor_value(values[0]), None if sid is None else _floor_value(values[1]))
    except Exception as exc:  # noqa: BLE001 — 어떤 조회 실패든 503 fail-closed(예외 문구는 키 = sub · sid · URL을 실을 수 있다)
        failure = type(exc).__name__
    if failure is not None:
        log.warning("session_floor.lookup_failed", error=failure)
        raise DenylistUnavailable() from None
    return floors


def is_active(
    *, record: DenylistRecord, floor: int | None, sid_floor: int | None = None, iat: int, now: int
) -> bool:
    """`/session/check` 판정(설계 D29 「판정식」 · UD-7a(ㄴ)) — 거부 목록 · 세션 하한 · 세션 단위 하한 · 절대 수명 · 미래 iat
    다섯이 모두 아닐 때만 참."""
    lifetime_s = int(SESSION_ABSOLUTE_LIFETIME.total_seconds())  # 2,592,000 — 초 단위 값을 따로 두지 않는다
    return (
        not record.revokes(iat)
        and not (floor is not None and floor > iat)
        and not (sid_floor is not None and sid_floor > iat)
        and not (now - iat > lifetime_s)
        and not (iat > now + FUTURE_IAT_TOLERANCE_S)
    )
