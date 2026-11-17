"""시험 인프라 검증(T060) — Django 없이 `pytest tests/test_fixtures_pg.py -p no:django`로 돈다.

testcontainers PostgreSQL 18(TLS 전용 이미지 tests/docker/pg-tls)과 owner/app role이 계약대로 서는지를
먼저 고정한다. tests/test_tenancy.py(RLS · 미들웨어 · check_rls)는 이 인프라 위에서 돈다.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import psycopg
import pytest

if TYPE_CHECKING:
    from tests.conftest import PgInfo


def test_infra_1_version_ssl(pg: PgInfo) -> None:
    """infra-1 — sslmode=require 접속: PostgreSQL 18 · 서버 ssl=on · 이 세션이 실제로 TLS 위에 있다."""
    with pg.connect("app") as conn:
        version = conn.execute("SELECT version()").fetchone()[0]
        ssl_setting = conn.execute("SHOW ssl").fetchone()[0]
        session_ssl = conn.execute(
            "SELECT ssl FROM pg_stat_ssl WHERE pid = pg_backend_pid()"
        ).fetchone()[0]
    assert version.startswith("PostgreSQL 18.")
    assert ssl_setting == "on"
    assert session_ssl is True


def test_infra_2_plain_rejected(pg: PgInfo) -> None:
    """infra-2 — 평문(sslmode=disable) 접속은 pg_hba의 hostnossl reject에서 거부된다.

    메시지까지 맞춘다 — 포트가 틀려 연결 자체가 안 되는 경우(같은 OperationalError)를 통과로 세지 않기 위해서다.
    """
    with pytest.raises(psycopg.OperationalError, match=r"pg_hba\.conf rejects connection.*no encryption"):
        pg.connect("app", sslmode="disable").close()


def test_infra_3_roles(pg: PgInfo) -> None:
    """infra-3 — owner = BYPASSRLS · 비-superuser · 로그인 가능 / app = NOBYPASSRLS · 비-superuser · 로그인 가능."""
    with pg.connect("app") as conn:
        rows = conn.execute(
            "SELECT rolname, rolbypassrls, rolsuper, rolcanlogin FROM pg_roles"
            " WHERE rolname = ANY(%s) ORDER BY rolname",
            [["test_owner", "test_app"]],
        ).fetchall()
    assert rows == [
        ("test_app", False, False, True),
        ("test_owner", True, False, True),
    ]
