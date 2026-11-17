"""django_common.health — 헬스 라우터 health_router(/healthz · /ready · /health)(T071).

계약(정본 — 규칙을 여기 되풀이하지 않는다): contracts/identity-admin-api.md 헬스 표 · 타임아웃 표 /health 행 · contracts/
pod-template.md 「프로브 3종」 행 · §django-common 공개 API · 규칙 .claude/rules/django-pod.md §Logging(헬스 문장). 설계 정본:
specs/003-platform-foundation/design/build-notes.md 「## T071」 D6 · 「T071 r1 결과 · r2 결정」 Y2(검사 칸마다 상한) · 「T071 r2
결과 · r3 결정」 Z3(스레드를 만들거나 시작하지 못할 때) · 「T071 r4 결과 · r5 결정」 P4(시작 실패의 자리 놓기). 칸 상한 · 칸 자리를
놓는 때 · 곧바로 fail은 타임아웃 표 /health 행을 본다.

구현 메모(계약 행이 말하지 않는 것):
- django-ninja 1.7.0 · 1.7.3 공통 기능만 쓴다 — 503은 problem_response(HttpResponse)를 그대로 돌려준다(Status · 튜플 반환 없음 ·
  VD-T071-1이 1.7.0 위에서 쟀다).
- 작업 스레드는 결과를 먼저 알리고(done) 그다음 자원(DB 연결 · Redis · AdminClient)을 정리한다 — 정리 시간이 판정을 늦추지 않게.
  latency_ms는 소수 한 자리다. 작업 스레드 이름은 `django-common-health-<칸>`이다.
- 칸 자리는 1회용 놓기(_Lease — 잠금으로 지킨다)로 정확히 한 번 놓는다: 작업 스레드의 finally와 시작 실패 경로가 둘 다 놓지
  않는다. 시작 실패 경로(Exception · BaseException)는 시작되지 않은 스레드(ident 없음)의 자리만 그 자리에서 놓는다 — 시작됐으면
  그 스레드의 finally가 놓는다(T071 r5 P4). Exception이면 None(곧바로 fail), BaseException이면 다시 올린다.
- DRAGONFLY_URL이 str이 아니거나 비었거나 해석할 수 없으면 시도 없이 fail이다.

import는 스레드 · 소켓을 만들지 않는다(칸 객체 · 세마포어와 Router 등록만).
"""

from __future__ import annotations

import threading
import time
from collections.abc import Callable
from typing import Any
from urllib.parse import urlsplit

from confluent_kafka.admin import AdminClient
from django.conf import settings
from django.db import connections
from django.http import HttpRequest, HttpResponse
from ninja import Router
from redis import Redis
from redis.backoff import NoBackoff
from redis.retry import Retry

from django_common.kafka import client_config
from django_common.problem import problem_response

__all__ = ["health_router"]

_DEADLINE_S = 2.5
_SLOT_LIMIT = 8
_DRAGONFLY_TIMEOUT_S = 0.2
_KAFKA_TIMEOUT_S = 1.0
_UNKNOWN = "unknown"
_THREAD_PREFIX = "django-common-health-"

Done = Callable[[bool], None]
Probe = Callable[[Done], None]

health_router = Router()


class _Slot:
    """검사 칸 하나 — 살아 있는 검사 스레드(마감을 넘겨 버려진 것 · 결과를 알린 뒤 정리 중인 것 포함)를 _SLOT_LIMIT까지만 받는다."""

    def __init__(self, name: str) -> None:
        self.name = name
        self._semaphore = threading.BoundedSemaphore(_SLOT_LIMIT)

    def acquire(self) -> bool:
        """자리 하나를 기다리지 않고 얻는다 — 칸이 차 있으면 False."""
        return self._semaphore.acquire(blocking=False)

    def release(self) -> None:
        self._semaphore.release()


# 칸 넷(D6 · T071 r2 Y2) — /ready의 DB와 /health의 세 항목을 따로 센다: /health의 부하 · 버려진 스레드가 readiness를, 한 의존의
# 정지가 다른 항목을 바꾸지 않는다. 결과는 호출 사이에 공유하거나 재사용하지 않는다.
_SLOTS = {name: _Slot(name) for name in ("ready", "db", "dragonfly", "kafka_producer")}


class _Outcome:
    """검사 하나의 결과 칸 — 작업 스레드가 done()으로 한 번만 채운다(뒤 호출은 무시)."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._event = threading.Event()
        self.ok = False
        self.finished_at = 0.0

    def done(self, ok: bool) -> None:
        with self._lock:
            if self._event.is_set():
                return
            self.ok = ok
            self.finished_at = time.perf_counter()
            self._event.set()

    def wait(self, timeout: float) -> bool:
        return self._event.wait(timeout)


class _Lease:
    """얻은 칸 자리 하나 — release()는 처음 한 번만 칸에 돌려준다(잠금으로 지킨다 · 뒤 호출은 아무것도 하지 않는다)."""

    def __init__(self, slot: _Slot) -> None:
        self._slot = slot
        self._lock = threading.Lock()
        self._held = True

    def release(self) -> None:
        with self._lock:
            if not self._held:
                return
            self._held = False
        self._slot.release()


def _start(slot: _Slot, probe: Probe) -> _Outcome | None:
    """칸 자리를 얻으면 새 데몬 스레드에서 probe를 돌린다(자리는 스레드가 끝날 때 놓는다) — 자리가 없으면 None. 결과 칸 · 스레드를
    만들거나 시작하다 Exception(종류와 무관)이 나면 None(곧바로 fail · 500 없음 · T071 r3 Z3), BaseException이면 다시 올린다. 어느
    쪽이든 칸 자리는 스레드가 시작되지 않았을 때(ident 없음)만 그 자리에서 놓고, 시작됐으면 그 스레드가 끝날 때 놓는다(T071 r5
    P4 — start()는 스레드를 띄운 뒤에도 예외를 낼 수 있다)."""
    if not slot.acquire():
        return None
    release = slot.release  # _Lease가 생기면 그 1회용 놓기로 바뀐다
    worker: threading.Thread | None = None
    try:
        lease = _Lease(slot)
        release = lease.release
        outcome = _Outcome()

        def run() -> None:
            try:
                probe(outcome.done)
            except Exception:  # noqa: BLE001 — 의존 예외는 모두 fail이다
                outcome.done(False)
            finally:
                outcome.done(False)
                lease.release()

        worker = threading.Thread(target=run, name=f"{_THREAD_PREFIX}{slot.name}", daemon=True)
        worker.start()
    except Exception:  # noqa: BLE001 — 스레드를 만들거나 시작하지 못하면 그 검사만 곧바로 fail이다(D6 — 500 금지)
        if worker is None or worker.ident is None:  # 시작되지 않았으면 여기서 놓는다(시작됐으면 그 finally가 놓는다 · r5 P4)
            release()
        return None
    except BaseException:
        if worker is None or worker.ident is None:  # 시작되지 않은 스레드의 자리만 놓는다(시작됐으면 그 finally가 놓는다)
            release()
        raise
    return outcome


def _milliseconds(seconds: float) -> float:
    return round(max(0.0, seconds) * 1000, 1)


def _run_checks(checks_to_run: dict[str, tuple[_Slot, Probe]]) -> dict[str, dict[str, Any]]:
    """검사를 병렬로 돌려 이름 → {status, latency_ms}(fail에도 걸린 시간 · 마감이면 마감 값) — 검사마다 자기 칸에서 센다."""
    started = time.perf_counter()
    deadline = started + _DEADLINE_S
    outcomes = {name: _start(slot, probe) for name, (slot, probe) in checks_to_run.items()}
    checks: dict[str, dict[str, Any]] = {}
    for name, outcome in outcomes.items():
        if outcome is None:
            checks[name] = {"status": "fail", "latency_ms": 0.0}
        elif outcome.wait(max(0.0, deadline - time.perf_counter())):
            checks[name] = {
                "status": "ok" if outcome.ok else "fail",
                "latency_ms": _milliseconds(outcome.finished_at - started),
            }
        else:
            checks[name] = {"status": "fail", "latency_ms": _milliseconds(deadline - started)}
    return checks


def _db_probe(done: Done) -> None:
    """default 별칭 — 이 스레드의 새 연결(설정은 호출 시점 dict) · SELECT 1 · 끝나면 이 스레드 연결을 닫는다."""
    try:
        connection = connections["default"]
        connection.ensure_connection()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception:  # noqa: BLE001 — 연결 · 쿼리 · 시험 차단 어떤 실패든 fail
        done(False)
    else:
        done(True)
    finally:
        connections.close_all()


def _url_has_query(url: str) -> bool:
    """URL 쿼리가 있는가 — redis-py는 URL 쿼리를 키워드 인자보다 우선한다(해석 실패도 쓸 수 없는 URL로 본다)."""
    try:
        return bool(urlsplit(url).query)
    except ValueError:
        return True


def _dragonfly_probe(done: Done) -> None:
    """DRAGONFLY_URL로 PING — 0.2 s(소켓 동작마다) · 재시도 0 · 쿼리가 있으면 시도 없이 fail."""
    url = getattr(settings, "DRAGONFLY_URL", None)
    if not isinstance(url, str) or not url or _url_has_query(url):
        done(False)
        return
    client: Redis | None = None
    try:
        client = Redis.from_url(
            url,
            socket_connect_timeout=_DRAGONFLY_TIMEOUT_S,
            socket_timeout=_DRAGONFLY_TIMEOUT_S,
            retry=Retry(NoBackoff(), 0),
        )
        client.ping()
    except Exception:  # noqa: BLE001 — 연결 · 인증 · 시간 초과 어떤 실패든 fail
        done(False)
    else:
        done(True)
    finally:
        if client is not None:
            try:
                client.close()
            except Exception:  # noqa: BLE001, S110 — 정리 실패는 판정과 무관하다
                pass


def _kafka_probe(done: Done) -> None:
    """client_config()(ImproperlyConfigured 포함 모든 예외 = fail) + log_level 0인 AdminClient로 list_topics(1.0 s)."""
    try:
        client = AdminClient({**client_config(), "log_level": 0})
        client.list_topics(timeout=_KAFKA_TIMEOUT_S)
    except Exception:  # noqa: BLE001 — 설정 · 연결 · 메타데이터 어떤 실패든 fail
        done(False)
    else:
        done(True)


def _setting_text(name: str) -> str:
    """버전 설정 값 — str이 아니거나 없으면 "unknown"(liveness는 설정 오류로 죽지 않는다 · 존재 검사는 T072 settings)."""
    value = getattr(settings, name, None)
    return value if isinstance(value, str) else _UNKNOWN


@health_router.get("/healthz", auth=None)
def healthz(request: HttpRequest) -> dict[str, str]:
    """liveness — 프로세스만(I/O 0)."""
    return {"status": "ok", "version": _setting_text("APP_VERSION"), "git_sha": _setting_text("APP_GIT_SHA")}


@health_router.get("/ready", auth=None)
def ready(request: HttpRequest) -> dict[str, str] | HttpResponse:
    """readiness — default 별칭 DB 검사 하나(/ready 칸) · 200 {"status": "ok"} 또는 503 not_ready(detail 없음)."""
    checks = _run_checks({"db": (_SLOTS["ready"], _db_probe)})
    if checks["db"]["status"] != "ok":
        return problem_response("not_ready", 503)
    return {"status": "ok"}


@health_router.get("/health", auth=None)
def health(request: HttpRequest) -> dict[str, Any]:
    """상세 — DB · Dragonfly · Kafka 병렬(항목마다 자기 칸) · 항상 200(ok | degraded)."""
    checks = _run_checks(
        {
            "db": (_SLOTS["db"], _db_probe),
            "dragonfly": (_SLOTS["dragonfly"], _dragonfly_probe),
            "kafka_producer": (_SLOTS["kafka_producer"], _kafka_probe),
        }
    )
    status = "ok" if all(item["status"] == "ok" for item in checks.values()) else "degraded"
    return {
        "status": status,
        "version": _setting_text("APP_VERSION"),
        "git_sha": _setting_text("APP_GIT_SHA"),
        "checks": checks,
    }
