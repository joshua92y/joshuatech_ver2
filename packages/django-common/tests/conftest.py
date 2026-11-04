"""django-common 시험 공용 픽스처(T060).

- `pg`(세션): testcontainers로 TLS 전용 PostgreSQL 18.6(tests/docker/pg-tls)을 띄우고 owner role
  (`test_owner` · BYPASSRLS · 마이그레이션·시드 전용)과 app role(`test_app` · NOBYPASSRLS · 런타임)을 만든다.
  superuser 자격은 이 픽스처 안에서만 쓴다. 비밀번호 3개는 세션마다 무작위로 만들고 출력하지 않는다.
  접속 정보는 환경변수 JT_TEST_PG_*로 이 프로세스 안에만 둔다(파일 0) — 세션이 끝나면 지운다.
- `django_db_modify_db_settings` · `django_db_setup`(pytest-django 재정의): 시험 DB를 따로 만들지 않고
  컨테이너의 jt_test에 owner 별칭으로 migrate만 한다. 컨테이너가 세션과 함께 사라지므로 teardown은 없다.
- `kafka`(세션 · T061): testcontainers로 KRaft 단일 노드 Kafka(cp-kafka 8.0.0 · PLAINTEXT · 자격 없음)를 띄우고
  bootstrap 주소 `host:port`를 준다(환경변수 JT_TEST_KAFKA_BOOTSTRAP에도 둔다 — 세션이 끝나면 지운다).
  `kafka_settings`(세션 · autouse 아님)는 그 주소를 Django 설정 KAFKA_BOOTSTRAP_SERVERS에 채운다 — 실 Kafka로
  릴레이하는 테스트(tests/test_outbox.py out-6)만 요청한다.
- `dragonfly`(세션 · T062): testcontainers로 Dragonfly v1.40.1(digest 핀)을 띄우고 default 사용자로 `ACL SETUSER`
  4개(admin · identity-admin = writer · test-pod = reader `%R~revoked:*` · noperm-pod)를 만든 뒤 default를 끈다.
  비밀번호 4개는 세션마다 무작위로 만들고 출력하지 않는다 · 환경변수 없음(자격이 든 URL은 DragonflyInfo의 repr 제외
  필드에만 두고, 값도 tests/_secret.Secret — repr 가림 — 이다).
- `jwks_server`(세션 · T062): 127.0.0.1 임시 포트의 로컬 JWKS 서버 — Authentik JWKS
  (`/application/o/identity-admin/jwks/`)와 Cloudflare Access certs(`/cdn-cgi/access/certs`)를 서빙하고 경로별 GET
  수를 센다. 서명 키 두 개는 세션마다 만든다.
- `dragonfly_clean`(함수 · T062): admin으로 FLUSHALL — 거부 목록 키가 테스트 사이에 새지 않게 한다.
- `auth_settings`(세션 · autouse 아님 · T062): Django 설정의 auth 빈 값(AUTHENTIK_JWKS_URL · ACCESS_TEAM_DOMAIN ·
  DRAGONFLY_URL = reader · AUTHENTIK_WEBHOOK_SECRET = 세션 랜덤)을 채운다 — tests/test_auth.py만 요청한다.
- `make_client` · `auth_client`(함수 · T062): MIDDLEWARE를 django_common.auth.JwtAuthMiddleware 하나로, ROOT_URLCONF를
  tests.authapp.urls로 덮고(pytest-django settings) 시험 Client를 만든다(make_client는 새 Client를 만드는 함수).
- `log_sink`(세션 · T063): StringIO에 configure_logging(stream=sink)을 세션에 한 번 건다(T071 · 전역 설정이라 정리 없음).
  `log_lines`(함수)는 sink를 비우고 읽기 객체 LogLines를 준다 — 부를 때마다 새 줄을 JSON 객체 목록으로 돌려주고 원문은
  `raw`에 쌓는다(한 줄 = 한 JSON 객체가 아니면 AssertionError).
- `obs_settings` · `otel` · `make_obs_client` · `obs_client`(함수 · T063): MIDDLEWARE를 RequestIdMiddleware + 시험 상류
  미들웨어 2개로, ROOT_URLCONF를 tests.obsapp.urls로 덮는다. otel은 샘플러 env 2개를 두고
  configure_otel(span_exporter=InMemorySpanExporter())로 DjangoInstrumentor를 건다(teardown: uninstrument · shutdown).

Django를 모듈 수준에서 import하지 않는다 — tests/test_fixtures_pg.py는 `-p no:django`로 `pg`만 쓴다.
tests/test_fixtures_kafka.py도 `-p no:django`로 `kafka`만 쓴다.
tests/test_fixtures_dragonfly.py도 `-p no:django`로 `dragonfly`만 쓴다(T062).
tests/test_fixtures_jwks.py도 `-p no:django`로 `jwks_server`만 쓴다(T062).
"""

from __future__ import annotations

import io
import json
import os
import secrets
import sys
import threading
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import TYPE_CHECKING, Any, Literal

import psycopg
import pytest
import redis
from psycopg import sql

# Windows Docker Desktop은 게시 포트를 IPv4(0.0.0.0)에만 열고 `localhost`는 ::1이 먼저 풀린다 → psycopg(connect_timeout 없으면
# 주소당 130 s) · librdkafka(시도당 약 2 s) · redis-py(0.2 s 예산)가 ::1에서 멈춘다(T062·T063 실측). testcontainers가 돌려주는
# 호스트(get_container_host_ip · Kafka advertised listener 포함)를 127.0.0.1로 고정한다 — testcontainers.core.config가 import
# 시점에 이 env를 읽으므로 그 import보다 앞에 둔다(T063 r1 A-1/B-6 · 운영자가 env를 직접 주면 그 값이 우선).
if sys.platform == "win32":
    os.environ.setdefault("TESTCONTAINERS_HOST_OVERRIDE", "127.0.0.1")

# testcontainers.postgres는 4.15에서 DeprecationWarning(stacklevel=2 → 이 모듈로 귀속)을 낸다 → 새 위치를 쓴다.
# testcontainers.kafka도 같다(T061) → community 위치를 쓴다.
from testcontainers.community.kafka import KafkaContainer
from testcontainers.community.postgres import PostgresContainer
from testcontainers.community.redis import RedisContainer
from testcontainers.core.image import DockerImage

from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    CERTS_PATH,
    JWKS_PATH,
    make_rsa_key,
    to_jwk,
)
from tests._secret import Secret

if TYPE_CHECKING:
    from cryptography.hazmat.primitives.asymmetric import rsa
    from django.test import Client
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
    from pytest_django import DjangoDbBlocker
    from pytest_django.fixtures import SettingsWrapper

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
        # owner가 SET ROLE test_app으로 Django assume_role 경로를 재현한다(tc-24 · T068 r3) — app은 owner의 멤버가 아니다.
        sql.SQL("GRANT {} TO {}").format(app, owner),
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


# --- T061: Kafka(KRaft) 시험 컨테이너 ---------------------------------------------------------------------------

# testcontainers KafkaContainer.with_kraft()가 이미지 태그에서 버전을 파싱한다(7.0.0 이상인지 판정) → digest 핀
# (`@sha256:…`)을 쓸 수 없어 태그로 고정한다. 대조용 인덱스 digest(2026-11-02 pull 실측 RepoDigests와 일치):
# sha256:9cdc8119cb39c45f0efa6da8e2220058020c7433e3ba3a3ce11a8006a18cb336
KAFKA_IMAGE = "confluentinc/cp-kafka:8.0.0"
KAFKA_START_TIMEOUT_S = 120
KAFKA_ENV_KEY = "JT_TEST_KAFKA_BOOTSTRAP"


@pytest.fixture(scope="session")
def kafka() -> Iterator[str]:
    """KRaft 단일 노드 Kafka(PLAINTEXT · 자격 없음 · 세션 1회)의 bootstrap 주소 `host:port`.

    기동 실패 예외는 그대로 올린다(비밀이 없다). stop()은 컨테이너와 익명 볼륨(이미지 VOLUME 2개)을 함께 지운다.
    """
    container = KafkaContainer(KAFKA_IMAGE).with_kraft()
    try:
        container.start(timeout=KAFKA_START_TIMEOUT_S)
        bootstrap = container.get_bootstrap_server()
        os.environ[KAFKA_ENV_KEY] = bootstrap
        yield bootstrap
    finally:
        os.environ.pop(KAFKA_ENV_KEY, None)
        container.stop()


@pytest.fixture(scope="session")
def kafka_settings(kafka: str) -> Iterator[None]:
    """Django 설정 KAFKA_BOOTSTRAP_SERVERS를 시험 브로커 주소로 채운다(세션 · autouse 아님).

    실 Kafka로 릴레이하는 테스트(tests/test_outbox.py out-6)만 요청한다 — 나머지는 fake 프로듀서라 브로커가 필요
    없다. 세션이 끝나면 원래 값으로 되돌린다.
    """
    from django.conf import settings

    previous = settings.KAFKA_BOOTSTRAP_SERVERS
    settings.KAFKA_BOOTSTRAP_SERVERS = kafka
    try:
        yield
    finally:
        settings.KAFKA_BOOTSTRAP_SERVERS = previous


# --- T062: Dragonfly(거부 목록) 시험 컨테이너 -------------------------------------------------------------------

# 태그 v1.40.1과 같은 OCI 인덱스 digest로 고정한다(2026-11-02 로컬 RepoDigests 실측). 이미지 entrypoint.sh가 `-`로
# 시작하는 첫 인자 앞에 `dragonfly --logtostderr`를 붙인다. 스레드 수 × 256 MiB 메모리 검사에 걸려 종료하지 않도록
# 스레드 2 · maxmemory 512 MiB로 둔다(작은 호스트에서도 기동한다).
DRAGONFLY_IMAGE = (
    "ghcr.io/dragonflydb/dragonfly@sha256:ebf3c6c213e82fb51b4521660cca13f06f3421dc5b1ed14f2f474c50b5e29986"
)
DRAGONFLY_COMMAND = "--proactor_threads=2 --maxmemory=512mb"
DRAGONFLY_PORT = 6379
# 런타임 ACL SETUSER 규칙 — contracts/denylist.md §ACL 표 그대로다(운영은 aclfile 적재 · VD-4 옵션 A · 시험은 같은
# 규칙을 기동 뒤에 건다). `<pod>` 자리는 test-pod다. noperm-pod는 `revoked:*` 패턴이 없어 거부 목록 조회가 NOPERM이다
# (auth-19의 실패 모드). 사용자마다 `on >비밀번호`를 앞에 붙인다.
DRAGONFLY_USERS: dict[str, tuple[str, ...]] = {
    "admin": ("~*", "+@all"),
    "identity-admin": ("~revoked:*", "~identity-admin:*", "+@all"),
    "test-pod": ("%R~revoked:*", "~test-pod:*", "+@all"),
    "noperm-pod": ("~noperm-pod:*", "+@all"),
}


@dataclass(frozen=True)
class DragonflyInfo:
    """Dragonfly 접속 정보. 자격이 든 URL 4개는 repr에서 빼고, 값 자체도 Secret(repr 가림)이다 — 이 URL을 인자로
    받은 프레임(시험 헬퍼 · 구현 · redis-py)이 실패해도 출력에 남지 않게.

    admin = 전 키(시험 정리 FLUSHALL) · writer = identity-admin(거부 목록 쓰기) · reader = test-pod(거부 목록 읽기
    전용 · auth 설정 DRAGONFLY_URL) · noperm = noperm-pod(`revoked:*` 패턴 없음).
    """

    host: str
    port: int
    admin_url: Secret = field(repr=False)
    writer_url: Secret = field(repr=False)
    reader_url: Secret = field(repr=False)
    noperm_url: Secret = field(repr=False)


def _redis_url(user: str, password: str, host: str, port: int) -> Secret:
    """`redis://<user>:<password>@<host>:<port>/0`(token_urlsafe 비밀번호는 URL 인코딩이 필요 없다 · Secret)."""
    return Secret(f"redis://{user}:{password}@{host}:{port}/0")


def _ipv4_loopback(host: str) -> str:
    """testcontainers가 준 `localhost`를 `127.0.0.1`로 바꾼다(그 밖의 호스트는 그대로).

    실측(2026-11-02 · Windows Docker Desktop): 게시 포트는 0.0.0.0에만 열리고 `localhost`는 `::1`이 먼저 풀린다 →
    `::1` 연결이 RST 없이 0.21 s 시간 초과한 뒤에야 127.0.0.1로 넘어간다. 거부 목록 클라이언트의 연결 시간 초과가
    0.2 s라(계약 §조회 규약 3) 새 연결마다 예산을 다 쓰게 되므로 IPv4 리터럴로 고정한다.
    """
    return "127.0.0.1" if host == "localhost" else host


@pytest.fixture(scope="session")
def dragonfly() -> Iterator[DragonflyInfo]:
    """Dragonfly 컨테이너 + ACL 사용자 4개(세션 1회). 마지막에 default 사용자를 끈다(자격 없는 접속 = 인증 오류).

    RedisContainer의 ping 대기(PingWaitStrategy)를 그대로 쓴다 — 그 시점의 default는 아직 nopass다. ACL은 그
    default 연결 하나로 건다(`default off` 뒤에도 기존 연결은 유지된다). stop()은 컨테이너와 익명 볼륨(이미지 VOLUME
    /data)을 함께 지운다.
    """
    passwords = {user: Secret(secrets.token_urlsafe(24)) for user in DRAGONFLY_USERS}
    container = RedisContainer(image=DRAGONFLY_IMAGE, port=DRAGONFLY_PORT).with_command(DRAGONFLY_COMMAND)
    try:
        container.start()
        host = _ipv4_loopback(container.get_container_host_ip())
        port = int(container.get_exposed_port(DRAGONFLY_PORT))
        bootstrap = container.get_client()
        try:
            for user, rules in DRAGONFLY_USERS.items():
                secret_rule = Secret(f">{passwords[user]}")  # redis-py 프레임 인자로 흘러가도 repr이 가려진다
                bootstrap.execute_command("ACL", "SETUSER", user, "on", secret_rule, *rules)
            bootstrap.execute_command("ACL", "SETUSER", "default", "off")
        except Exception as exc:
            # 어떤 오류 메시지든 규칙 토큰(비밀번호 포함)을 되풀이할 수 있다 → 가린 사본으로 바꾸고 연쇄를 끊는다.
            message = f"Dragonfly ACL 준비 실패: {type(exc).__name__}: {exc}"
            raise RuntimeError(_redacted(message, *passwords.values())) from None
        finally:
            bootstrap.close()
        yield DragonflyInfo(
            host=host,
            port=port,
            admin_url=_redis_url("admin", passwords["admin"], host, port),
            writer_url=_redis_url("identity-admin", passwords["identity-admin"], host, port),
            reader_url=_redis_url("test-pod", passwords["test-pod"], host, port),
            noperm_url=_redis_url("noperm-pod", passwords["noperm-pod"], host, port),
        )
    finally:
        container.stop()


# --- T062: 로컬 JWKS 서버(Authentik JWKS · Cloudflare Access certs) ---------------------------------------------


@dataclass(frozen=True)
class JwksInfo:
    """로컬 JWKS 서버 정보. 서명 키(세션 생성 RSA 2048)는 repr에서 뺀다.

    base_url = `http://127.0.0.1:<port>`(Access 팀 도메인 자리 · Access iss) · jwks_url = Authentik JWKS(운영 svc DNS
    자리) · certs_url = Access certs · hits = 경로별 GET 수(캐시 단언용 — 서버 스레드가 잠금 아래 올린다).
    """

    base_url: str
    jwks_url: str
    certs_url: str
    authentik_key: rsa.RSAPrivateKey = field(repr=False)
    access_key: rsa.RSAPrivateKey = field(repr=False)
    hits: dict[str, int]


def _jwks_handler(
    documents: dict[str, bytes], hits: dict[str, int], lock: threading.Lock
) -> type[BaseHTTPRequestHandler]:
    """경로 → JSON 문서를 주는 GET 처리기(그 밖의 경로는 404). 모든 GET을 경로별로 센다."""

    class JwksHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # 메서드 이름은 BaseHTTPRequestHandler 규약(do_<METHOD>)이다
            with lock:
                hits[self.path] = hits.get(self.path, 0) + 1
            body = documents.get(self.path)
            if body is None:
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format: str, *args: Any) -> None:  # 인자 이름 format은 부모 시그니처 그대로다
            """요청 로그를 끈다(기본 구현은 요청마다 stderr에 한 줄을 쓴다)."""

    return JwksHandler


@pytest.fixture(scope="session")
def jwks_server() -> Iterator[JwksInfo]:
    """로컬 JWKS 서버(세션 1회): Authentik JWKS(kid authentik-test-1) · Access certs(kid access-test-1 · `{"keys": [...]}`).

    127.0.0.1 임시 포트에서 ThreadingHTTPServer를 데몬 스레드 하나로 돌린다. 서명 키 두 개는 세션마다 만든다(저장소에
    키 자료 0). 세션이 끝나면 shutdown() · server_close()로 닫는다.
    """
    authentik_key, access_key = make_rsa_key(), make_rsa_key()
    documents = {
        JWKS_PATH: json.dumps({"keys": [to_jwk(authentik_key.public_key(), AUTHENTIK_KID)]}).encode(),
        CERTS_PATH: json.dumps({"keys": [to_jwk(access_key.public_key(), ACCESS_KID)]}).encode(),
    }
    hits = dict.fromkeys(documents, 0)
    server = ThreadingHTTPServer(("127.0.0.1", 0), _jwks_handler(documents, hits, threading.Lock()))
    thread = threading.Thread(target=server.serve_forever, name="jwks-server", daemon=True)
    thread.start()
    base_url = f"http://127.0.0.1:{server.server_address[1]}"
    try:
        yield JwksInfo(
            base_url=base_url,
            jwks_url=base_url + JWKS_PATH,
            certs_url=base_url + CERTS_PATH,
            authentik_key=authentik_key,
            access_key=access_key,
            hits=hits,
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


# --- T062: auth 설정 · 시험 Client ------------------------------------------------------------------------------

# T070 공개 이름 — 설정 문자열로만 단다(tests/test_auth.py가 같은 객체인지 확인한다).
AUTH_MIDDLEWARE = "django_common.auth.JwtAuthMiddleware"
AUTH_URLCONF = "tests.authapp.urls"


@pytest.fixture
def dragonfly_clean(dragonfly: DragonflyInfo) -> Iterator[None]:
    """테스트마다 Dragonfly를 비운다(admin FLUSHALL) — 거부 목록 키가 테스트 사이에 새지 않게 한다."""
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        admin.flushall()
    finally:
        admin.close()
    yield


@pytest.fixture(scope="session")
def auth_settings(jwks_server: JwksInfo, dragonfly: DragonflyInfo) -> Iterator[None]:
    """tests/settings.py T062 절의 빈 값을 세션 값으로 채운다(세션 · autouse 아님 — tests/test_auth.py만 요청한다).

    AUTHENTIK_JWKS_URL = 로컬 JWKS URL · ACCESS_TEAM_DOMAIN = 로컬 서버 base URL(스킴 포함) · DRAGONFLY_URL = reader
    (test-pod) URL · AUTHENTIK_WEBHOOK_SECRET = 세션 랜덤(출력하지 않는다). 세션이 끝나면 원래 값으로 되돌린다.
    비밀 두 값(reader URL · 웹훅 비밀)은 Secret이다 — 구현이 인자로 받은 프레임에서 실패해도 repr이 가려진다.
    """
    from django.conf import settings

    values = {
        "AUTHENTIK_JWKS_URL": jwks_server.jwks_url,
        "ACCESS_TEAM_DOMAIN": jwks_server.base_url,
        "DRAGONFLY_URL": dragonfly.reader_url,
        "AUTHENTIK_WEBHOOK_SECRET": Secret(secrets.token_urlsafe(32)),
    }
    previous = {name: getattr(settings, name) for name in values}
    for name, value in values.items():
        setattr(settings, name, value)
    try:
        yield
    finally:
        for name, value in previous.items():
            setattr(settings, name, value)


@pytest.fixture
def make_client(settings: SettingsWrapper) -> Callable[[], Client]:
    """JwtAuthMiddleware 하나만 단 시험 Client를 만드는 함수(함수 스코프).

    pytest-django settings로 MIDDLEWARE · ROOT_URLCONF를 덮는다(테스트가 끝나면 되돌린다 · setting_changed가 URL
    캐시를 비운다). Client는 첫 요청 때 미들웨어를 적재하고 그 인스턴스를 계속 쓴다 — 테스트가 설정(DRAGONFLY_URL ·
    AUTH_ACTOR_SUB)을 바꾼 뒤에는 이 함수로 새 Client를 만든다.
    """
    from django.test import Client

    settings.MIDDLEWARE = [AUTH_MIDDLEWARE]
    settings.ROOT_URLCONF = AUTH_URLCONF
    return Client


@pytest.fixture
def auth_client(make_client: Callable[[], Client]) -> Client:
    """make_client()로 만든 시험 Client 하나(설정을 바꾸지 않는 테스트용)."""
    return make_client()


# --- T063: 관측(구조 로그 · OTel) · 헬스 ----------------------------------------------------------------------------

# T071 공개 이름 — 미들웨어는 설정 문자열로만 단다(D2). RequestIdMiddleware가 가장 바깥이라 request_finished를 남길 때는
# 안쪽 시험 미들웨어가 둔 request.tenant_id(T060 HeaderTenantMiddleware · 헤더 X-Test-Tenant)와 request.auth_claims
# (tests.obsapp HeaderClaimsMiddleware · 헤더 X-Test-Sub)가 이미 있다.
OBS_MIDDLEWARE = (
    "django_common.observability.RequestIdMiddleware",
    "tests.testapp.middleware.HeaderTenantMiddleware",
    "tests.obsapp.middleware.HeaderClaimsMiddleware",
)
OBS_URLCONF = "tests.obsapp.urls"
# 계약(contracts/pod-template.md §런타임 계약 트레이스 행)의 샘플러 env — SDK TracerProvider()가 생성 시점에 읽는다.
OTEL_SAMPLER_ENV = {"OTEL_TRACES_SAMPLER": "parentbased_traceidratio", "OTEL_TRACES_SAMPLER_ARG": "0.1"}


@pytest.fixture(scope="session")
def log_sink() -> Iterator[io.StringIO]:
    """구조 로그 sink(세션) — StringIO에 configure_logging(stream=sink)을 세션에 한 번 건다(T071 가정 D2).

    structlog과 stdlib logging이 모두 이 sink에 JSON 한 줄씩 쓴다. 전역 설정이라 세션 끝 정리는 없다(뒤 모듈의 로그도
    이 sink에 쌓인다 — 읽는 쪽은 log_lines가 테스트마다 비운다).
    """
    from django_common.observability import configure_logging

    sink = io.StringIO()
    configure_logging(stream=sink)
    yield sink


class LogLines:
    """log_sink 읽기 객체 — 부를 때마다 지난 호출 뒤에 쓰인 새 줄을 JSON 객체(dict) 목록으로 돌려준다.

    한 줄 = 한 JSON 객체여야 한다: 빈 줄 · JSON이 아닌 줄 · 객체가 아닌 JSON · 줄바꿈 없이 끝난 출력은 AssertionError다.
    실패 메시지에는 줄 번호와 길이만 싣는다(로그 원문을 출력하지 않는다). 읽은 원문은 raw에 쌓는다 — "출력 어디에도 X가
    없다" 단언용(테스트는 `needle in raw`를 따로 계산해 bool만 단언한다 — 원문이 실패 출력에 실리지 않게).
    """

    def __init__(self, sink: io.StringIO) -> None:
        self._sink = sink
        self.raw = ""

    def __call__(self) -> list[dict[str, Any]]:
        text = self._sink.getvalue()
        self._sink.seek(0)
        self._sink.truncate()
        self.raw += text
        if text and not text.endswith("\n"):
            raise AssertionError("로그 출력이 줄바꿈으로 끝나지 않는다(한 줄 = 한 JSON 객체)")
        records: list[dict[str, Any]] = []
        # splitlines()가 아니라 "\n"으로 자른다 — ensure_ascii=False 렌더러가 문자열 안에 그대로 둔 U+2028 등을 줄 끝으로
        # 오인하지 않게.
        for number, line in enumerate(text.split("\n")[:-1], start=1):
            try:
                record = json.loads(line)
            except ValueError:
                raise AssertionError(f"로그 {number}번째 줄이 JSON이 아니다(길이 {len(line)})") from None
            if not isinstance(record, dict):
                raise AssertionError(f"로그 {number}번째 줄이 JSON 객체가 아니다({type(record).__name__})")
            records.append(record)
        return records


@pytest.fixture
def log_lines(log_sink: io.StringIO) -> LogLines:
    """sink를 비우고(seek(0) · truncate()) LogLines를 준다(함수 스코프) — 이 테스트가 만든 줄만 읽힌다.

    세션 픽스처(컨테이너 기동 등)는 함수 픽스처보다 먼저 서므로 그 로그는 여기서 지워진다.
    """
    log_sink.seek(0)
    log_sink.truncate()
    return LogLines(log_sink)


@pytest.fixture
def obs_settings(settings: SettingsWrapper) -> SettingsWrapper:
    """MIDDLEWARE · ROOT_URLCONF를 관측 시험용으로 덮는다(pytest-django settings — 테스트가 끝나면 되돌린다).

    MIDDLEWARE는 테스트마다 새 list다 — DjangoInstrumentor.instrument()는 현재 MIDDLEWARE list에 OTel 미들웨어를 제자리
    삽입(insert)하고 uninstrument()는 제자리 제거(remove)한다(0.66b2 소스) → tests/settings.py의 list를 건드리지 않게.
    """
    settings.MIDDLEWARE = list(OBS_MIDDLEWARE)
    settings.ROOT_URLCONF = OBS_URLCONF
    return settings


@pytest.fixture
def otel(
    obs_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> Iterator[tuple[TracerProvider, InMemorySpanExporter]]:
    """OTel 계측(함수) — 샘플러 env 2개를 두고 configure_otel(span_exporter=InMemorySpanExporter())을 부른다(T071 가정 D2).

    obs_settings 뒤에 선다(인자 의존): instrument()가 이 테스트의 MIDDLEWARE list 맨 앞에 OTel 미들웨어를 넣고, teardown의
    uninstrument()가 settings 복원보다 먼저 그 항목을 뺀다. 시험 Client는 첫 요청 때 미들웨어를 적재하므로
    (django.test.client.ClientHandler — _middleware_chain이 None이면 load_middleware) 첫 요청 전에만 계측되면 된다 —
    읽는 사람이 헷갈리지 않게 OTel이 필요한 테스트는 이 픽스처를 Client 픽스처보다 앞 인자로 둔다.
    teardown: DjangoInstrumentor().uninstrument() → provider.shutdown().
    """
    from opentelemetry.instrumentation.django import DjangoInstrumentor
    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

    from django_common.observability import configure_otel

    for name, value in OTEL_SAMPLER_ENV.items():
        monkeypatch.setenv(name, value)
    exporter = InMemorySpanExporter()
    provider = configure_otel(span_exporter=exporter)
    try:
        yield provider, exporter
    finally:
        DjangoInstrumentor().uninstrument()
        provider.shutdown()


@pytest.fixture
def make_obs_client(obs_settings: SettingsWrapper) -> Callable[[], Client]:
    """관측 시험 Client를 만드는 함수(함수 스코프 · obs_settings 뒤).

    Client는 첫 요청 때 미들웨어를 적재하고 그 인스턴스를 계속 쓴다 — 테스트가 설정(DRAGONFLY_URL ·
    KAFKA_BOOTSTRAP_SERVERS)을 바꾼 뒤에는 이 함수로 새 Client를 만든다(헬스 구현은 설정을 요청 시점에 읽는다 · D2).
    """
    from django.test import Client

    return Client


@pytest.fixture
def obs_client(make_obs_client: Callable[[], Client]) -> Client:
    """make_obs_client()로 만든 관측 시험 Client 하나(설정을 바꾸지 않는 테스트용)."""
    return make_obs_client()
