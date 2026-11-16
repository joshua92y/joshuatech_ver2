"""거부 목록 · 세션 하한의 쓰기(T073 설계 D13 — pod 소유 새 파일) — 쓰기 클라이언트와 커밋 뒤 쓰기 둘.

정본: contracts/denylist.md §조회 규약 3 · 6 · 7 · §쓰기 규약 · §키 스키마 · contracts/identity-admin-api.md §타임아웃 · 설계 D13 ·
D29 「쓰기」 · D8 3단계.

- client(): `Redis.from_url(settings.DRAGONFLY_URL, socket_timeout=0.2, socket_connect_timeout=0.2,
  retry=Retry(NoBackoff(), 0))` — 0.2 s와 재시도 0을 명시한다(redis-py 어느 생성 경로의 기본값에도 기대지 않는다). URL별로
  캐시하고(잠금 아래 · 지연 생성 — 만들 때 연결하지 않는다) 설정은 호출할 때 읽는다. URL에 쿼리가 있으면 클라이언트를 만들지
  않고 DragonflyUrlHasQuery를 올린다 — redis-py는 URL 쿼리를 키워드 인자보다 우선해 0.2 s · 재시도 0을 덮어쓴다(dl:24와 같은
  이유). 예외 문구에 URL을 싣지 않는다.
- 쓰는 곳: `/session/check`의 하한 조회(session_floor.read_floor) · 커밋 뒤 쓰기(apply_user · apply_sid — 폐기 기록의 커밋 뒤
  콜백이 부른다). 이 모듈 안에서도 클라이언트는 호출마다 `client()`로 얻는다(모듈 전역 조회 — 시험이 덮는 이음매다).
  django_common의 비공개 거부 목록 클라이언트는 쓰지 않는다(설계 D13).

커밋 뒤 쓰기(반환 = 네 문자열 `ok` · `skipped` · `failed` · `unreachable` 가운데 하나 — 실패도 예외가 아니라 값이다)
- apply_user(sub): 커밋 뒤 SQL 1회(app role · 한 문장 = DB 시계 하나)로 그 sub의 보존 창 안 사용자 단위 행(`sid IS NULL`)
  가운데 nbf가 가장 큰 행을 읽는다 — 자기 행 값이 아니다(늦게 끝난 요청 · 과거 nbf 웹훅 · 백필이 더 큰 값을 덮어 낮추지 않게).
  30일은 리터럴이 아니라 `session_floor.REVOCATION_LOG_RETENTION`(호출 때 모듈 속성으로 읽는다)을 매개변수로 넘긴다. 그 행으로
  `SET revoked:sub:{sub} <nbf> EX min(330, ⌊expires_at − 프로세스 시각⌋)`과 `SET identity-admin:session-floor:{sub} <nbf> EX
  ⌊expires_at + 30 d − DB now⌋`를 파이프라인 1회(`transaction=False` · `execute(raise_on_error=False)`)로 보낸다. TTL이 1
  미만인 키는 보내지 않는다(`EX 0`은 오류다). 둘 다 빠지거나 행이 없으면 Dragonfly에 닿지 않고 INFO `denylist.set_skipped`.
- apply_sid(sid, expires_at): `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − 프로세스 시각⌋)` — 자기 행 값으로 쓰고 DB를
  읽지 않는다. 하한을 만들지 않는다(설계 E13 — 값이 상수 1이라 덮어써도 약해지지 않는다).
- 실패(응답은 그대로 — 30 s 재적용이 되살린다 · Celery 재시도 없음): SQL 실패 → WARNING `denylist.set_failed stage=lookup`
  (`failed` · 아무것도 쓰지 않는다 — 자기 행 값으로 대신 쓰면 더 큰 기존 값을 낮출 수 있다) · 연결 · 시간 초과 → stage=connect
  (`unreachable` — 폐기 기록의 위임 단계가 enqueue를 건너뛰는 판정) · 그 밖의 클라이언트 · 연결 단계 예외(쿼리가 든 URL 등) →
  stage=connect(`failed`) · 명령 단위 오류(NOPERM 등 — 결과 목록의 예외 객체) → stage=command(`failed`). 로그 필드는 예외
  클래스 이름뿐이다(문구는 호스트 · 포트 · 키 = sub를 싣는다).
- `revoked:*` TTL은 프로세스 시계로 잰다(nbf를 프로세스 시계로 정하므로 DB 컨테이너와 시험 프로세스의 시계가 어긋나도 TTL이
  흔들리지 않는다 · 설계 D13 「TTL의 시계」) · 하한 TTL은 DB 시계다(30일 규모 · 재적용과 같은 식).

무조건 재적용 · 로그 purge(설계 D14 · D29 — 작업 `reconcile_denylist` · `beat_init` 수신자 · `purge_session_revocation_log`가 부른다)
- reapply() -> ReapplyResult(rows, keys, floors, skipped, failed): 캐시 상태를 묻지 않고(EXISTS 0 · 센티널 `denylist:epoch` 0)
  로그에서 다시 SET한다. 첫 SQL(한 문장 = DB 시계 하나)이 `expires_at > now()` 행을 `ORDER BY nbf, expires_at`으로 읽고 행 → 키
  (`sid` NULL → `revoked:sub:{sub}` = nbf · 아니면 `revoked:sid:{sid}` = 1 · TTL = ⌊expires_at − now()⌋)로 바꾼다 — 같은 키가 여럿이면
  마지막 행(nbf 최대 · expires 최대)만 남긴다. 둘째 SQL이 보존 창(`expires_at + 30 d > now()`) 안 사용자 단위 행을 sub별
  `DISTINCT ON`으로 묶어 nbf가 가장 큰 행 하나씩 읽고 세션 하한 키(= 그 nbf · TTL = ⌊expires_at + 30 d − now()⌋)로 바꾼다. 30일은
  리터럴이 아니라 `session_floor.REVOCATION_LOG_RETENTION`(호출 때 모듈 속성으로 읽는다)을 매개변수로 넘긴다. TTL이 1 미만인 키는
  보내지 않는다(skipped — `EX 0`은 오류다). SET은 1000개 단위 파이프라인(`transaction=False` · `execute(raise_on_error=False)`)이고
  마지막 명령은 늘 신선도 키 `identity-admin:denylist:reapplied-at` = 워커의 epoch 초 `EX 300`이다(행이 0이어도 보낸다 — 「최근
  300 s 안에 재적용이 두 SQL을 끝내고 Dragonfly까지 닿았다」). 명령 단위 오류(결과 목록의 예외 객체 — NOPERM 등)는 `failed`로 세고
  WARNING `denylist.reapply_failed failed=<n> error=<첫 클래스>`를 남긴다(phase 없음 — 예외 갈래와 다른 꼴). SQL 실패 · 연결 · 시간
  초과는 예외로 올린다(반환하지 않는다 — 부르는 쪽이 클래스 이름만 남기고 문구를 버린다). 실행마다 두 SQL 뒤 · 첫 묶음 앞에서
  쓰기 클라이언트의 유휴 풀 연결을 버린다(`connection_pool.disconnect(inuse_connections=False)` — 소켓만 닫고 연결 객체는 풀에
  둔다 · 다음 파이프라인이 새로 붙는다): FIN이 닿지 않은 끊김(노드 사망 · 분할) 뒤 풀은 살아 보이는 죽은 연결을 그대로 내주고
  재시도 0이라 그 tick이 실패해 유실 창이 30초 늘기 때문이다. 재시도가 아니다(`Retry(NoBackoff(), 0)`과 0.2 s는 그대로 — tick마다
  새 연결 · 핸드셰이크 왕복 몇 번 · 분당 2회). 묶음 사이에는 버리지 않는다(같은 실행의 둘째 묶음은 방금 쓴 연결을 다시 쓴다).
  reapply()는 워커와 beat만 부른다 — 요청 경로(apply_user · apply_sid · session_floor.read_floor)의 연결 재사용은 그대로다
  (contracts/denylist.md §쓰기 규약 「30 s 무조건 재적용」 · T073 수정 라운드 ⑤-a H2).
- purge_log() -> int: `expires_at < now() − 30 d`(계약 식 `expires_at + 30 d < now()`와 같은 뜻의 인덱스 친화 식 · DB 시계 · 같은
  상수를 호출 때 모듈 속성으로 읽는다) 행을 지운다 — 지운 행 수. 이 경계가 하한 수명의 경계와 같은 식 · 같은 상수다(하한이 사는
  동안 그 행은 DB에 있다 — 설계 D29 불변식 2).
"""

from __future__ import annotations

import math
import threading
import time
from typing import TYPE_CHECKING, NamedTuple
from urllib.parse import urlsplit

import structlog
from django.conf import settings
from django.db import connection
from redis import Redis
from redis.backoff import NoBackoff
from redis.exceptions import ConnectionError as RedisConnectionError
from redis.exceptions import TimeoutError as RedisTimeoutError
from redis.retry import Retry

from identity_admin import session_floor

if TYPE_CHECKING:
    from datetime import datetime

__all__ = [
    "CLIENT_TIMEOUT_S",
    "DENYLIST_TTL_S",
    "FAILED",
    "FRESHNESS_KEY",
    "FRESHNESS_TTL_S",
    "OK",
    "REAPPLY_BATCH",
    "SKIPPED",
    "UNREACHABLE",
    "DragonflyUrlHasQuery",
    "ReapplyResult",
    "apply_sid",
    "apply_user",
    "client",
    "purge_log",
    "reapply",
]

CLIENT_TIMEOUT_S = 0.2  # 소켓 동작마다의 상한(조회 · 쓰기 · 연결) — contracts/denylist.md §조회 규약 3
DENYLIST_TTL_S = 330  # revoked:* TTL 상한(access 토큰 TTL 300 s + 30 s — contracts/denylist.md §키 스키마)
OK, SKIPPED, FAILED, UNREACHABLE = "ok", "skipped", "failed", "unreachable"
# 연결 · 시간 초과 — 브로커가 같은 Dragonfly라 enqueue도 실패한다(위임 건너뛰기 판정 · 설계 D12 ④). redis-py는 소켓 오류를
# ConnectionError · TimeoutError로 감싼다(인증 실패 AuthenticationError도 ConnectionError 하위다) — OSError는 방어로 둔다.
_UNREACHABLE_ERRORS: tuple[type[BaseException], ...] = (RedisConnectionError, RedisTimeoutError, OSError)

# 커밋 뒤 최댓값 조회(설계 D13 1단계 — 문장 그대로 · 30일은 매개변수). 결과 = (nbf epoch, expires_at epoch, 하한 TTL 초).
_USER_FLOOR_SQL = """
SELECT extract(epoch FROM nbf)::bigint,
       extract(epoch FROM expires_at)::bigint,
       floor(extract(epoch FROM expires_at + %(retention)s - statement_timestamp()))::bigint
FROM session_revocation_log
WHERE sub = %(sub)s AND sid IS NULL AND expires_at > statement_timestamp() - %(retention)s
ORDER BY nbf DESC, expires_at DESC LIMIT 1
"""

FRESHNESS_KEY = "identity-admin:denylist:reapplied-at"  # 재적용 생존 신호(contracts/denylist.md §키 스키마 · 판정에 쓰지 않는다)
FRESHNESS_TTL_S = 300  # 가장 긴 작업 마감 120 s(일 1회 대조) + tick 30 s + 여유 · T098 「성공 줄 5분 무소식」과 같은 문턱(설계 D14)
REAPPLY_BATCH = 1000  # 파이프라인 한 번에 보내는 SET 수(신선도 키는 마지막 묶음의 마지막 명령)

# 재적용 첫 SQL(설계 D14 — 문장 그대로). 결과 = (sub, sid, nbf epoch, 남은 TTL 초).
_REAPPLY_DENYLIST_SQL = """
SELECT sub, sid, extract(epoch FROM nbf)::bigint, floor(extract(epoch FROM expires_at - statement_timestamp()))::bigint
FROM session_revocation_log WHERE expires_at > statement_timestamp() ORDER BY nbf, expires_at
"""

# 재적용 둘째 SQL — 세션 하한(설계 D14 · D29 — 문장 그대로 · 30일은 매개변수). 결과 = (sub, nbf epoch, 하한 TTL 초).
_REAPPLY_FLOOR_SQL = """
SELECT DISTINCT ON (sub) sub, extract(epoch FROM nbf)::bigint,
       floor(extract(epoch FROM expires_at + %(retention)s - statement_timestamp()))::bigint
FROM session_revocation_log
WHERE sid IS NULL AND expires_at > statement_timestamp() - %(retention)s
ORDER BY sub, nbf DESC, expires_at DESC
"""

_clients: dict[str, Redis] = {}
_lock = threading.Lock()
log = structlog.get_logger(__name__)


class ReapplyResult(NamedTuple):
    """재적용 1회의 건수(모두 정수 — 설계 D14 「반환 계약」): rows = 첫 SQL이 읽은 활성 행 수 · keys = 보낸 `revoked:*` SET 수(같은
    키를 묶은 뒤) · floors = 보낸 세션 하한 SET 수 · skipped = TTL < 1로 건너뛴 키 수(둘 합) · failed = 결과가 오류였던 명령 수
    (신선도 키 포함)."""

    rows: int
    keys: int
    floors: int
    skipped: int
    failed: int


class DragonflyUrlHasQuery(ValueError):
    """DRAGONFLY_URL에 쿼리가 있다 — 클라이언트를 만들지 않는다(쿼리가 0.2 s · 재시도 0을 덮어쓴다 · 문구에 URL 없음)."""

    def __init__(self) -> None:
        super().__init__("DRAGONFLY_URL에 쿼리가 있어 쓰기 클라이언트를 만들지 않는다")


def client() -> Redis:
    """settings.DRAGONFLY_URL의 쓰기 클라이언트(URL별 캐시 · 0.2 s · 재시도 0) — 쿼리가 든 URL은 DragonflyUrlHasQuery."""
    url = settings.DRAGONFLY_URL
    if urlsplit(url).query:
        raise DragonflyUrlHasQuery()
    with _lock:
        cached = _clients.get(url)
        if cached is None:
            cached = Redis.from_url(
                url,
                socket_timeout=CLIENT_TIMEOUT_S,
                socket_connect_timeout=CLIENT_TIMEOUT_S,
                retry=Retry(NoBackoff(), 0),
            )
            _clients[url] = cached
        return cached


def _remaining(expires_epoch: float) -> int:
    """`revoked:*`의 TTL = min(330, ⌊expires_at − 프로세스 시각⌋)."""
    return min(DENYLIST_TTL_S, math.floor(expires_epoch - time.time()))


def _send(commands: list[tuple[str, str, int]]) -> str:
    """(키, 값, TTL) 목록을 파이프라인 1회로 SET한다 — 결과 문자열(ok · failed · unreachable)."""
    failure: tuple[str, str] | None = None
    results: list[object] = []
    try:
        pipe = client().pipeline(transaction=False)
        for key, value, ttl in commands:
            pipe.set(key, value, ex=ttl)
        results = pipe.execute(raise_on_error=False)
    except _UNREACHABLE_ERRORS as exc:
        failure = (UNREACHABLE, type(exc).__name__)
    except Exception as exc:  # noqa: BLE001 — 그 밖의 클라이언트 · 연결 단계 예외(쿼리가 든 URL 등)도 값으로 돌려준다
        failure = (FAILED, type(exc).__name__)
    if failure is not None:
        log.warning("denylist.set_failed", error=failure[1], stage="connect")
        return failure[0]
    errors = [result for result in results if isinstance(result, Exception)]
    if errors:
        log.warning("denylist.set_failed", error=type(errors[0]).__name__, stage="command")
        return FAILED
    return OK


def apply_user(sub: str) -> str:
    """사용자 단위 폐기의 커밋 뒤 쓰기 — 그 sub의 최댓값 행으로 `revoked:sub`와 세션 하한 키를 한 파이프라인으로 SET한다."""
    row: tuple[int, int, int] | None = None
    lookup_error: str | None = None
    try:
        with connection.cursor() as cursor:
            cursor.execute(_USER_FLOOR_SQL, {"sub": sub, "retention": session_floor.REVOCATION_LOG_RETENTION})
            row = cursor.fetchone()
    except Exception as exc:  # noqa: BLE001 — 조회 실패는 값으로(문구 = 행 값 · 접속 정보를 싣지 않는다)
        lookup_error = type(exc).__name__
    if lookup_error is not None:
        log.warning("denylist.set_failed", error=lookup_error, stage="lookup")
        return FAILED
    commands: list[tuple[str, str, int]] = []
    if row is not None:
        nbf, expires_epoch, floor_ttl = row
        sub_ttl = _remaining(expires_epoch)
        if sub_ttl >= 1:
            commands.append((f"revoked:sub:{sub}", str(nbf), sub_ttl))
        if floor_ttl >= 1:
            commands.append((f"{session_floor.FLOOR_KEY_PREFIX}{sub}", str(nbf), floor_ttl))
    if not commands:
        log.info("denylist.set_skipped")
        return SKIPPED
    return _send(commands)


def apply_sid(sid: str, expires_at: datetime) -> str:
    """세션 단위 폐기의 커밋 뒤 쓰기 — `revoked:sid:{sid}` = 1(자기 행 값 · DB를 읽지 않는다 · 하한 없음)."""
    ttl = _remaining(expires_at.timestamp())
    if ttl < 1:
        log.info("denylist.set_skipped")
        return SKIPPED
    return _send([(f"revoked:sid:{sid}", "1", ttl)])


def reapply() -> ReapplyResult:
    """무조건 재적용 1회(설계 D14) — 로그 → `revoked:*` · 세션 하한 키 · 신선도 키를 조건 없이 다시 SET한다. SQL 실패 · 연결 ·
    시간 초과는 예외로 올린다(그 문구는 호스트 · 포트 · 키 = sub를 싣는다 — 부르는 쪽이 클래스 이름만 남긴다). 첫 묶음 앞에서
    유휴 풀 연결을 버린다(재시도 아님 — 모듈 독스트링)."""
    with connection.cursor() as cursor:
        cursor.execute(_REAPPLY_DENYLIST_SQL)
        denylist_rows = cursor.fetchall()
        cursor.execute(_REAPPLY_FLOOR_SQL, {"retention": session_floor.REVOCATION_LOG_RETENTION})
        floor_rows = cursor.fetchall()
    latest: dict[str, tuple[str, int]] = {}
    for sub, sid, nbf, ttl in denylist_rows:  # ORDER BY nbf, expires_at — 같은 키는 마지막 행(nbf 최대 · expires 최대)이 남는다
        if sid is None:
            latest[f"revoked:sub:{sub}"] = (str(nbf), ttl)
        else:
            latest[f"revoked:sid:{sid}"] = ("1", ttl)
    commands: list[tuple[str, str, int]] = []
    skipped = 0
    for key, (value, ttl) in latest.items():
        if ttl < 1:
            skipped += 1
            continue
        commands.append((key, value, ttl))
    keys = len(commands)
    for sub, nbf, ttl in floor_rows:
        if ttl < 1:
            skipped += 1
            continue
        commands.append((f"{session_floor.FLOOR_KEY_PREFIX}{sub}", str(nbf), ttl))
    floors = len(commands) - keys
    commands.append((FRESHNESS_KEY, str(int(time.time())), FRESHNESS_TTL_S))  # 행이 0이어도 보낸다 — 마지막 명령
    failed = 0
    first_error: str | None = None
    # 첫 묶음 앞에서 유휴 연결만 버린다(FIN 없는 끊김 뒤 살아 보이는 죽은 연결 — 재시도가 아니다 · 모듈 독스트링)
    client().connection_pool.disconnect(inuse_connections=False)
    for start in range(0, len(commands), REAPPLY_BATCH):
        pipe = client().pipeline(transaction=False)
        for key, value, ttl in commands[start : start + REAPPLY_BATCH]:
            pipe.set(key, value, ex=ttl)
        for result in pipe.execute(raise_on_error=False):
            if isinstance(result, Exception):
                failed += 1
                first_error = first_error or type(result).__name__
    if failed:
        log.warning("denylist.reapply_failed", failed=failed, error=first_error)
    return ReapplyResult(rows=len(denylist_rows), keys=keys, floors=floors, skipped=skipped, failed=failed)


def purge_log() -> int:
    """폐기 로그 purge(설계 D14 · D29) — `expires_at < DB now() − 30 d` 행을 지우고 지운 행 수를 준다(상수는 호출 때 모듈
    속성으로 읽는다 — 하한 수명 경계와 같은 상수)."""
    from django.db.models.functions import Now

    from identity_admin.models import SessionRevocationLog

    deleted, _ = SessionRevocationLog.objects.filter(
        expires_at__lt=Now() - session_floor.REVOCATION_LOG_RETENTION
    ).delete()
    return deleted
