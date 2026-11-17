"""ULID 생성(T069 · D10) — outbox 행 id = CloudEvents id(계약 events.md §봉투 · data-model §4).

꼴: 48비트 ms 시각(time.time_ns() // 1_000_000) + 80비트 난수(secrets.randbits(80))를 `(ms << 80) | 난수`로 붙여 Crockford
base32 대문자 26자로 쓴다(알파벳 0123456789ABCDEFGHJKMNPQRSTVWXYZ — 정규식 클래스 [0-9A-HJKMNP-TV-Z]와 같다). 130비트 자리에
128비트를 쓰므로 첫 글자는 0–7이다(_envelope.json id pattern). 고정 길이 대문자라 사전순 = 수치순이다.

프로세스 안 단조(잠금): 같은 ms이거나 시계가 뒤로 가면 직전 ms를 그대로 쓰고 난수부를 +1 한다 — 넘치면 ms + 1(새 난수).
그래서 한 프로세스가 낸 id는 스레드가 여럿이어도 겹치지 않고 낸 순서대로 커진다(한 요청에서 같은 ms에 낸 두 이벤트의
`ORDER BY id`가 발행 순서와 같다). 프로세스 사이의 순서는 보장하지 않는다(릴레이 순서는 최선 노력 — 설계 D9).
의존성 없음(ULID 라이브러리 · uuid7 없음 — 사실 ⑨).
"""

from __future__ import annotations

import secrets
import threading
import time

__all__ = ["new_ulid"]

_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_LENGTH = 26
_RANDOM_BITS = 80
_RANDOM_LIMIT = 1 << _RANDOM_BITS

_lock = threading.Lock()
_last_ms = -1
_last_random = 0


def _encode(value: int) -> str:
    chars = []
    for _ in range(_LENGTH):
        chars.append(_ALPHABET[value & 0x1F])
        value >>= 5
    return "".join(reversed(chars))


def new_ulid() -> str:
    """새 ULID(Crockford 대문자 26자 · 프로세스 안 단조 증가)."""
    global _last_ms, _last_random
    with _lock:
        now_ms = time.time_ns() // 1_000_000
        if now_ms > _last_ms:
            ms, random_part = now_ms, secrets.randbits(_RANDOM_BITS)
        else:
            ms, random_part = _last_ms, _last_random + 1
            if random_part >= _RANDOM_LIMIT:
                ms, random_part = _last_ms + 1, secrets.randbits(_RANDOM_BITS)
        _last_ms, _last_random = ms, random_part
    return _encode((ms << _RANDOM_BITS) | random_part)
