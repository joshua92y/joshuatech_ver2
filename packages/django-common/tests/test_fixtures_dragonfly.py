"""시험 인프라 검증(T062) — Django 없이 `pytest tests/test_fixtures_dragonfly.py -p no:django`로 돈다.

testcontainers Dragonfly(v1.40.1 · digest 핀)와 런타임 `ACL SETUSER` 사용자들이 계약(contracts/denylist.md §ACL 표)
대로 서는지를 먼저 고정한다. tests/test_auth.py의 거부 목록 단언(auth-14..21)은 이 인프라 위에서 돈다.

- writer = `identity-admin`(`~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client` — 거부 목록 쓰기)
- reader = `test-pod`(`%R~revoked:* ~test-pod:* +@all -@admin -@dangerous -client` — 템플릿 `<pod>` 규칙 · 거부 목록 읽기 전용)
- noperm = `noperm-pod`(`~noperm-pod:* +@all -@admin -@dangerous -client` — `revoked:*` 패턴이 없어 조회가 NOPERM · auth-19의 실패
  모드)
- 세 pod 사용자의 꼬리 `-@admin -@dangerous -client`는 T075 UD-9(B2 — contracts/denylist.md §ACL)다. admin은 `~* +@all` 그대로다.
- default 사용자는 끈다(`ACL SETUSER default off`) → 자격 없는 접속은 인증 오류다.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest
import redis
from redis.backoff import NoBackoff
from redis.retry import Retry

if TYPE_CHECKING:
    from tests.conftest import DragonflyInfo


def test_infra_df_1_acl(dragonfly: DragonflyInfo) -> None:
    """infra-df-1 — writer SET · reader GET/EXISTS/파이프라인 OK · reader SET/DEL NOPERM · 자기 접두 OK · noperm NOPERM ·
    자격 없는 default 접속 거부.

    파이프라인은 MULTI/EXEC(redis-py 기본)와 비트랜잭션 둘 다 본다 — 거부 목록 조회(T070)가 어느 쪽을 쓰든 reader
    ACL이 막지 않아야 한다. 표본은 조회 꼴 그대로 GET 둘(revoked:sub · revoked:sid — UD-7a 보정: sid 값도 시각이라 읽는다 ·
    이전 꼴 GET + EXISTS). 자격 없는 클라이언트는 재시도를 끈다: AuthenticationError는 ConnectionError의 하위라
    redis-py 기본 재시도(지수 백오프 10회)가 판정을 수 초 늦출 수 있다.
    """
    writer = redis.Redis.from_url(dragonfly.writer_url)
    reader = redis.Redis.from_url(dragonfly.reader_url)
    noperm = redis.Redis.from_url(dragonfly.noperm_url)
    anonymous = redis.Redis(host=dragonfly.host, port=dragonfly.port, db=0, retry=Retry(NoBackoff(), 0))
    try:
        assert writer.set("revoked:sub:x", 1, ex=30) is True
        assert reader.get("revoked:sub:x") == b"1"
        assert reader.exists("revoked:sid:y") == 0
        for transaction in (True, False):
            pipe = reader.pipeline(transaction=transaction)
            pipe.get("revoked:sub:x")
            pipe.get("revoked:sid:y")
            assert pipe.execute() == [b"1", None], f"transaction={transaction}"
        with pytest.raises(redis.exceptions.NoPermissionError):
            reader.set("revoked:sub:x", 2)
        with pytest.raises(redis.exceptions.NoPermissionError):
            reader.delete("revoked:sub:x")
        assert reader.get("revoked:sub:x") == b"1"  # 거부된 쓰기는 값을 바꾸지 않았다
        assert reader.set("test-pod:k", 1) is True
        with pytest.raises(redis.exceptions.NoPermissionError):
            noperm.get("revoked:sub:x")
        with pytest.raises(redis.exceptions.AuthenticationError):
            anonymous.ping()
    finally:
        for client in (writer, reader, noperm, anonymous):
            client.close()
