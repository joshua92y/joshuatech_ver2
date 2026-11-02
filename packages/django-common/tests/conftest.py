"""django-common 시험 공용 픽스처(T060).

- `pg`(세션): testcontainers로 TLS 전용 PostgreSQL 18.6(tests/docker/pg-tls)을 띄우고 owner role
  (`test_owner` · BYPASSRLS · 마이그레이션·시드 전용)과 app role(`test_app` · NOBYPASSRLS · 런타임)을 만든다.
  superuser 자격은 이 픽스처 안에서만 쓴다. 비밀번호 3개는 세션마다 무작위로 만들고 출력하지 않는다.
  접속 정보는 환경변수 JT_TEST_PG_*로 이 프로세스 안에만 둔다(파일 0) — 세션이 끝나면 지운다.
- `django_db_modify_db_settings` · `django_db_setup`(pytest-django 재정의): 시험 DB를 따로 만들지 않고
  컨테이너의 jt_test에 owner 별칭으로 migrate만 한다. 컨테이너가 세션과 함께 사라지므로 teardown은 없다.

Django를 모듈 수준에서 import하지 않는다 — tests/test_fixtures_pg.py는 `-p no:django`로 `pg`만 쓴다.
"""

from __future__ import annotations

import os
import secrets
from collections.abc import Iterator
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING, Any, Literal

import psycopg
import pytest
from psycopg import sql

# testcontainers.postgres는 4.15에서 DeprecationWarning(stacklevel=2 → 이 모듈로 귀속)을 낸다 → 새 위치를 쓴다.
from testcontainers.community.postgres import PostgresContainer
from testcontainers.core.image import DockerImage

if TYPE_CHECKING:
    from pytest_django import DjangoDbBlocker

PG_TLS_CONTEXT = Path(__file__).resolve().parent / "docker" / "pg-tls"
PG_TLS_TAG = "jt-django-common-pg-tls:18.6"
PG_SUPERUSER = "postgres"
PG_DB = "jt_test"
OWNER_ROLE = "test_owner"
APP_ROLE = "test_app"
CONNECT_TIMEOUT_S = 10
ENV_KEYS = (
    "JT_TEST_PG_HOST",
    "JT_TEST_PG_PORT",
    "JT_TEST_PG_DB",
    "JT_TEST_PG_OWNER_USER",
    "JT_TEST_PG_OWNER_PASSWORD",
    "JT_TEST_PG_APP_USER",
    "JT_TEST_PG_APP_PASSWORD",
)


@dataclass(frozen=True)
class PgInfo:
    """컨테이너 접속 정보. 비밀번호는 repr에서 뺀다(실패 출력에 남지 않게)."""

    host: str
    port: int
    dbname: str
    owner_user: str
    app_user: str
    owner_password: str = field(repr=False)
    app_password: str = field(repr=False)

    def connect(
        self, role: Literal["owner", "app"], *, sslmode: str = "require"
    ) -> psycopg.Connection[Any]:
        """role로 jt_test에 접속한다(기본 sslmode=require)."""
        user, password = {
            "owner": (self.owner_user, self.owner_password),
            "app": (self.app_user, self.app_password),
        }[role]
        return psycopg.connect(
            host=self.host,
            port=self.port,
            dbname=self.dbname,
            user=user,
            password=password,
            sslmode=sslmode,
            connect_timeout=CONNECT_TIMEOUT_S,
        )

    def env(self) -> dict[str, str]:
        """ENV_KEYS 순서의 환경변수 이름 → 값(D3)."""
        values = (
            self.host,
            str(self.port),
            self.dbname,
            self.owner_user,
            self.owner_password,
            self.app_user,
            self.app_password,
        )
        return dict(zip(ENV_KEYS, values, strict=True))


def _redacted(text: str, *values: str) -> str:
    for value in values:
        text = text.replace(value, "***")
    return text


def _bootstrap_roles(info: PgInfo, superuser_password: str) -> None:
    """superuser로 owner/app role과 권한을 만든다(D3).

    CREATE ROLE … PASSWORD는 유틸리티 문이라 서버 쪽 바인드 파라미터를 받지 않는다 → psycopg.sql.Literal로
    클라이언트에서 묶는다.
    """
    owner, app, db = sql.Identifier(OWNER_ROLE), sql.Identifier(APP_ROLE), sql.Identifier(PG_DB)
    statements = (
        sql.SQL("CREATE ROLE {} LOGIN BYPASSRLS PASSWORD {}").format(
            owner, sql.Literal(info.owner_password)
        ),
        sql.SQL("CREATE ROLE {} LOGIN NOBYPASSRLS PASSWORD {}").format(
            app, sql.Literal(info.app_password)
        ),
        sql.SQL("ALTER DATABASE {} OWNER TO {}").format(db, owner),
        sql.SQL("GRANT CONNECT ON DATABASE {} TO {}, {}").format(db, owner, app),
        sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(app),
        sql.SQL(
            "ALTER DEFAULT PRIVILEGES FOR ROLE {} IN SCHEMA public"
            " GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {}"
        ).format(owner, app),
        sql.SQL(
            "ALTER DEFAULT PRIVILEGES FOR ROLE {} IN SCHEMA public"
            " GRANT USAGE, SELECT ON SEQUENCES TO {}"
        ).format(owner, app),
    )
    with psycopg.connect(
        host=info.host,
        port=info.port,
        dbname=PG_DB,
        user=PG_SUPERUSER,
        password=superuser_password,
        sslmode="require",
        connect_timeout=CONNECT_TIMEOUT_S,
        autocommit=True,
    ) as conn:
        for statement in statements:
            conn.execute(statement)


@pytest.fixture(scope="session")
def pg() -> Iterator[PgInfo]:
    """TLS 전용 PostgreSQL 18.6 컨테이너 + owner/app role(세션 1회 · 이미지 빌드도 세션 1회)."""
    superuser_password = secrets.token_urlsafe(24)
    with DockerImage(path=PG_TLS_CONTEXT, tag=PG_TLS_TAG):
        container = PostgresContainer(
            image=PG_TLS_TAG, username=PG_SUPERUSER, password=superuser_password, dbname=PG_DB
        )
        try:
            try:
                container.start()
            except Exception as exc:
                # 대기 전략(ExecWaitStrategy)의 시간 초과 메시지는 PGPASSWORD가 든 명령 전체를 싣는다
                # → 비밀번호를 가린 사본으로 바꾸고 원래 예외 연쇄는 끊는다(from None).
                message = f"PostgreSQL 시험 컨테이너 기동 실패: {type(exc).__name__}: {exc}"
                raise RuntimeError(_redacted(message, superuser_password)) from None
            info = PgInfo(
                host=container.get_container_host_ip(),
                port=int(container.get_exposed_port(5432)),
                dbname=PG_DB,
                owner_user=OWNER_ROLE,
                app_user=APP_ROLE,
                owner_password=secrets.token_urlsafe(24),
                app_password=secrets.token_urlsafe(24),
            )
            _bootstrap_roles(info, superuser_password)
            os.environ.update(info.env())
            yield info
        finally:
            for key in ENV_KEYS:
                os.environ.pop(key, None)
            container.stop()


@pytest.fixture(scope="session")
def django_db_modify_db_settings(pg: PgInfo) -> None:
    """pytest-django 재정의: 컨테이너 접속 정보를 settings.DATABASES에 채운다(default = app · owner = owner)."""
    from django.conf import settings

    common = {"HOST": pg.host, "PORT": str(pg.port), "NAME": pg.dbname}
    settings.DATABASES["default"].update(common, USER=pg.app_user, PASSWORD=pg.app_password)
    settings.DATABASES["owner"].update(common, USER=pg.owner_user, PASSWORD=pg.owner_password)


@pytest.fixture(scope="session")
def django_db_setup(
    django_db_modify_db_settings: None, django_db_blocker: DjangoDbBlocker
) -> None:
    """pytest-django 재정의: 시험 DB(test_*)를 만들지 않고 jt_test에 owner 별칭으로 migrate만 한다(D4).

    owner role이 테이블을 소유하고(기본 권한으로 app role에 SELECT·INSERT·UPDATE·DELETE), 런타임 별칭
    default는 app role이다. 컨테이너가 세션과 함께 사라지므로 teardown은 없다.
    """
    from django.core.management import call_command

    with django_db_blocker.unblock():
        call_command("migrate", database="owner", verbosity=0)
