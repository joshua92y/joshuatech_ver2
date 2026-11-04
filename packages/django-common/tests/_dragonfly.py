"""Dragonfly 시험 관측 헬퍼(T063 · 리뷰 r1 결정) — tests/test_auth.py(auth-21)와 tests/test_observability.py가 같이 쓴다.

connections_received(admin) = `INFO stats`의 total_connections_received. 전후 차이가 "그 사이에 누가 Dragonfly에 새로
연결했는가"다 — 요청 안에서 연결 → 명령 → close한 연결도 센다. CLIENT LIST id 차집합은 그 연결을 놓친다("after"를 읽을
때 그 id는 이미 없다 — T063 참조 구현 변이 실측: /healthz · /ready가 PING하고 오류를 삼키는 구현이 id 차집합으로는
통과했다). Dragonfly v1.40.1 실측: 새 연결마다 +1 · 같은 admin 연결로 INFO를 거듭 불러도 0.

Django를 import하지 않는다(`-p no:django` 인프라 테스트에서도 쓸 수 있다).
"""

from __future__ import annotations

import redis


def connections_received(admin: redis.Redis) -> int:
    """Dragonfly가 지금까지 받은 연결 수(INFO stats total_connections_received)."""
    return int(admin.info("stats")["total_connections_received"])
