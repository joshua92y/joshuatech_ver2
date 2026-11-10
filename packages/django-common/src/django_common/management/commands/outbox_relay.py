"""outbox_relay 관리 명령(T069 · D7 · D9 · r2 J4–J7 · r3 K9 · K11 · r4 L6 · L7 · r5 M1 · M3 · 계약 events.md §outbox 릴레이
「구현 규칙」) — relay 컨테이너의 프로세스.

`python manage.py outbox_relay`(인자 없음 — 기본값 = 계약 값): --batch-size 100 · --poll-interval 0.5 s(0은 시험용이다 — 빈 패스의
대기가 0이 된다) · --max-backoff 300 s · --metrics-port 9464(0 = 지표 서버를 열지 않는다 — 시험) · --iterations 0(= 무한 — 시험 ·
운영 점검). 어긋난 인자는 CommandError다(배치 1 이상 · 폴링 · 상한은 0 이상의 유한수이고 상한 ≥ 폴링 · 포트 0–65535 · 반복 0
이상 — 템플릿은 인자 없이 부른다).

끝나는 경로(계약 「수명 주기」 · T069 r3 · r4 정정): relay는 web과 같은 pod의 컨테이너라 relay의 재시작 반복(CrashLoop)은 pod
Ready를 떨어뜨려 web까지 Service에서 뺀다 → 루프 안 오류로는 끝나지 않는다(J6). 오류로 끝나는 경로는 루프 전의 실패뿐이다 — 설정
import · system checks · 인자 오류(CommandError) · 지표 모듈 초기화(예: 없는 디렉터리를 가리키는 PROMETHEUS_MULTIPROC_DIR — relay
env에 두지 않는다) · 9464를 열 수 없을 때(CommandError). 정상 종료는 SIGTERM · SIGINT뿐이다(이번 패스를 마치고).
① 지표 모듈 import(등록) + prometheus_client.start_http_server(포트) — 열 수 없으면 CommandError로 끝난다(루프 전 실패의 하나 ·
   liveness TCP 9464).
② refresh_metrics()(실패 = 로그).
③ 루프 한 번(= 반복 하나): django.db.close_old_connections()(관리 명령은 요청 신호가 없어 직접 부른다) → 프로듀서가 없으면
   relay.build_producer()(설정 검증 · CA · error_cb) → 그 프로듀서의 poll(0)(아래 「패스 전 poll」) → relay.relay_once(producer=…,
   batch_size=…) → 대기 next_wait → refresh(아래 J7). 다음은 전부 로그(아래 「로그」) + 백오프(진전 없음과 같다)이고 다음 반복을
   돈다: 프로듀서 생성 실패 · ImproperlyConfigured(설정 오류 — 고치면 Reloader 롤아웃이 다시 띄운다 · 그동안 쌓이는 행은
   OutboxOldestPending이 알린다) · DB OperationalError · InterfaceError(+ close_old_connections) ·
   relay.ProducerFatalError(J5 · L6 — 그 패스는 이미 커밋됐다 · 프로듀서를 버리고 다음 반복에 새로 만든다) · poll의 치명 꼴
   예외(아래) · 그 밖의 Exception.
패스 전 poll(L7 · 리뷰 r3 B3-3): confluent는 error_cb와 치명 오류를 flush · poll 안에서만 낸다. 그래서 반복마다 relay_once 전에
poll(0)을 부른다 — 비치명 오류 이벤트(error_cb의 kafka_error 줄)가 다음 비지 않은 패스에 몰리지 않고 시간에 따라 흩어지며, 유휴 중
난 치명 오류도 곧바로 드러난다. poll이 치명 꼴 예외(relay 모듈 독스트링 9 — 치명 KafkaException · 그것을 원인으로 한
SystemError)를 올리면 행에 닿기 전에 그 프로듀서를 버린다 — 로그 `outbox_relay.producer_fatal <poll 예외 클래스> kafka_error=<원인
이름> published=0 failed=0 dead=0` · 그 반복은 오류(백오프)로 세고 다음 반복에 새로 만든다. 그 밖의 poll 예외는 일반 오류
경로다(프로듀서를 버리지 않는다). 원인이 그대로면(ACL 누락 등) 재생성 간격은 대기와 함께 는다 — 유휴 중에도 그렇다: 새 프로듀서의
첫 poll은 통과하고(치명은 연결 뒤 비동기로 선다) 그 첫 패스는 빈 패스인데, 아래 「대기 next_wait」의 M1 예외가 그 빈 패스에서
대기를 되돌리지 않는다. 그래서 대기가 1, 1, 2, 2, 4, 4 … 300 s로 자라고 재생성 간격이 약 1.5 · 3 · 6 · 12 … s로 늘며, 상한에 닿은
뒤(약 1022 s)에는 약 600 s(유지 300 + 치명 백오프 300)마다 다시 만든다(행이 있으면 그 패스가 치명으로 끝나 유지 없이 1 · 2 · 4 …
300 s로 는다 · T069 r5). 가정: 치명이 새 프로듀서 생성 뒤 유지된 대기(처음 1 s) 안에 선다(번들 librdkafka mock에서 약 0.52 s ·
리뷰 r5) — 더 늦으면(생성 → 치명 시간 L > 1 s) 빈 패스가 그 전에 대기를 되돌려 재생성 주기가 약 (1 s + L)에 머문다(T075 VD가
잰다). 대가(리뷰 r5 A5-1 · B5-1): 원인을 고친 뒤에도 유휴 relay는 진행 중인 유지 대기와 치명 백오프를 마저 채운 뒤에야 새
프로듀서를 만든다(유지 대기 중인 프로듀서는 고치기 전에 만든 것이라 이미 치명이다) — 그사이 들어온 행은 최대 약 2 ×
--max-backoff(≈ 600 s) 늦고, 장애 내내 pending 행이 있었다면 치명 백오프 한 번(≤ 300 s)이다. 유휴 치명 동안에는 refresh도
대기마다라 새 행의 나이가 최대 한 대기 늦게 보인다. 바로 되돌리려면 pod 재시작(T114).
대기 next_wait(J4 · K9 · M1): 진전 없음(published 0 · failed > 0)이거나 오류면 max(직전 대기, 폴링 간격, MIN_BACKOFF_S 0.5 s) × 2,
상한 --max-backoff — 전면 장애는 1 · 2 · 4 … 256 s로 는다(flush 대기가 패스마다 더해진다 — 계약 「시간」). 하한 0.5 s(계약 폴링
기본값)는 --poll-interval이 0이어도 그대로라 루프 안 지속 오류가 바쁜 루프 · 로그 폭주가 되지 않는다(리뷰 r2 B2-5 — --max-backoff
0은 상한이라 여전히 0: 시험). 패스가 잘렸으면(RelayResult.truncated — 행 수 LIMIT · 바이트 예산) 0 — 밀린 행을 바로 비운다(SC-004
5 s). 그 밖(진전 · 빈 패스 · dead만)은 폴링 간격 — 진전이 있으면 백오프를 되돌린다. 예외(M1 · T069 r5): 치명으로 프로듀서를
버리면(poll 치명 · ProducerFatalError 둘 다) 루프가 표시를 세우고, 그 뒤 결과를 돌려준 첫 패스(보통 다시 만든 프로듀서의 첫
패스)가 빈 패스(published · failed · dead 모두 0)면 대기를 직전 값 그대로 둔다(next_wait(…, after_fatal_rebuild=True)) — 빈 패스는
produce · flush가 없어 새 프로듀서가 쓸 만한지 보여 주지 않는다. 그 첫 패스의 다른 결과(진전 · 진전 없음 · 잘림 · dead만)는 평소
규칙이다. 표시는 결과를 돌려준 첫 패스에서 지운다 — 결과 없이 오류로 끝난 반복(생성 실패 · 비치명 poll 예외 · DB 오류 등)에서는
남는다(그래서 치명 뒤 DB 장애가 이어지면 회복 뒤 첫 빈 패스도 대기를 한 번 더 유지한다 · 드문 경로 · 리뷰 r5 B5-2 수용). 규칙은
next_wait가 정하고 루프는 표시만 관리한다. 진전 없음이 잘림보다 먼저다(장애 중 바쁜 루프가 없다). 백오프는 행이 아니라 루프의
것이다.
refresh(J7): refresh_metrics()는 따로 감싼다(실패 = 로그 · DB 오류면 연결 정리 · 대기 규칙에 섞지 않는다). 패스마다 부르되, 잘린
패스가 연달아 도는 동안(truncated — 대기 0)은 직전 refresh에서 REFRESH_MIN_INTERVAL_S(1 s)가 지나야 다시 부른다 — 매 패스
pending 전체 스캔이 배출을 늦추지 않게.

SIGTERM · SIGINT 처리기는 플래그만 세운다 — 이번 패스를 마치고 끝낸다. 대기는 0.1 s 조각으로 플래그를 본다. 끝에서 이전 처리기를
되돌리고(call_command 시험이 같은 프로세스) 지표 서버를 닫는다. 처리기는 주 스레드에서만 단다(signal 모듈 제약).

로그(K11): logger "django_common.outbox" — 이벤트 이름 + 개수 · 예외 클래스 이름 + 값 없는 진단 필드만 싣는다(payload · 설정 · 오류
본문 · 인자 · 지역변수 없음 — last_error는 DB에 있다). 진단 필드는 하나다: KafkaException이면 `kafka_error=<KafkaError.name()>`(예:
_SSL · _INVALID_ARG) · ProducerFatalError면 그 치명 오류의 이름(같은 필드) · DB 오류(django.db.Error)면 원인 psycopg 예외의
`sqlstate=<SQLSTATE>`(원인에 SQLSTATE가 없으면 — 연결 단계 오류 등 — 생략) · SystemError면 그 __cause__(없으면 __context__ —
relay._fatal_exception_name과 같은 기준)가 KafkaException일 때 그 KafkaError 이름(같은 필드 — confluent가 DR 콜백 앞에서 올린
예외의 원인 보존 · 치명 여부와 무관 · L6 · M3) · 그 밖이면 가장 안쪽 트레이스백 프레임 `at=<파일 이름>:<줄>:<함수>` — 그 밖의
예외는 암묵 __context__가 KafkaException이어도 위치를 싣는다(`except KafkaException` 처리 중 난 버그의 위치를 잃지 않게 · M3).
꼴이 맞지 않는 값은 싣지 않는다(fail-closed). 줄: outbox_relay.start · pass · error · db_error · refresh_error · producer_fatal ·
stop + 프로듀서 error_cb의 outbox_relay.kafka_error name=…(relay 모듈 · 비치명 오류 이벤트의 이름만 · L6). 생성 단계 실패(CA ·
값 꼴 · 양립)의 재현은 pod 안에서 relay.build_producer()를 부르는 것이다(client_config()만으로는 재현하지 못한다). 템플릿은 pod
앱에 같은 이름의 재노출 파일을 둔다(T072). 운영 relay DB 설정은 CONN_MAX_AGE > 0 + CONN_HEALTH_CHECKS(인계).
"""

from __future__ import annotations

import argparse
import logging
import math
import os
import re
import signal
import threading
import time
import traceback
from types import FrameType, ModuleType
from typing import Any

from django import db
from django.core.management.base import BaseCommand, CommandError, CommandParser

from django_common.outbox import relay
from django_common.outbox.relay import RelayResult

logger = logging.getLogger("django_common.outbox")

_SLICE_S = 0.1
_SIGNALS = (signal.SIGTERM, signal.SIGINT)
REFRESH_MIN_INTERVAL_S = 1.0
MIN_BACKOFF_S = 0.5  # 오류 · 진전 없음 백오프의 하한(계약 폴링 기본값 — --poll-interval 0이어도 · K9)
_KAFKA_NAME = re.compile(r"_?[A-Z][A-Z0-9_]*")  # KafkaError.name()의 꼴(librdkafka 오류 이름)
_SQLSTATE = re.compile(r"[0-9A-Z]{5}")


def next_wait(
    result: RelayResult | None,
    *,
    poll_interval: float,
    max_backoff: float,
    previous: float,
    after_fatal_rebuild: bool = False,
) -> float:
    """다음 대기(초) — result None = 오류(진전 없음과 같다). 규칙은 모듈 독스트링(K9 — 백오프 하한 MIN_BACKOFF_S · M1 —
    after_fatal_rebuild = 치명으로 버린 뒤 결과를 돌려준 첫 패스: 빈 패스면 직전 대기를 그대로 돌려준다)."""
    if result is None or (result.published == 0 and result.failed > 0):
        return min(max(previous, poll_interval, MIN_BACKOFF_S) * 2, max_backoff)
    if result.truncated:
        return 0.0
    if after_fatal_rebuild and (result.published, result.failed, result.dead) == (0, 0, 0):
        return previous
    return poll_interval


def _field(name: str, value: object, shape: re.Pattern[str]) -> str:
    """`name=value` — value가 꼴(shape)에 맞는 str일 때만(아니면 빈 문자열 · fail-closed)."""
    return f"{name}={value}" if isinstance(value, str) and shape.fullmatch(value) else ""


def _diagnostics(exc: BaseException) -> str:
    """루프 로그의 값 없는 진단 필드 하나(K11 — 모듈 독스트링 「로그」) · 없으면 빈 문자열. 메시지 · 인자 · 지역변수는 보지 않는다."""
    from confluent_kafka import KafkaError, KafkaException

    if isinstance(exc, relay.ProducerFatalError):
        return _field("kafka_error", exc.error_name, _KAFKA_NAME)
    if isinstance(exc, KafkaException):
        error = exc.args[0] if exc.args else None
        if isinstance(error, KafkaError):
            return _field("kafka_error", error.name(), _KAFKA_NAME)
    elif isinstance(exc, db.Error):
        return _field("sqlstate", getattr(exc.__cause__, "sqlstate", None), _SQLSTATE)
    elif isinstance(exc, SystemError):  # 원인 보존은 SystemError에만(M3 — 그 밖의 예외는 암묵 __context__가 있어도 at=)
        cause = exc.__cause__ if exc.__cause__ is not None else exc.__context__  # relay._fatal_exception_name과 같은 기준
        if isinstance(cause, KafkaException) and cause.args and isinstance(cause.args[0], KafkaError):
            return _field("kafka_error", cause.args[0].name(), _KAFKA_NAME)
    innermost: tuple[str, int, str] | None = None
    for frame, lineno in traceback.walk_tb(exc.__traceback__):
        innermost = (frame.f_code.co_filename, lineno, frame.f_code.co_name)
    if innermost is None:
        return ""
    filename, lineno, function = innermost
    return f"at={os.path.basename(filename)}:{lineno}:{function}"


def _described(exc: BaseException) -> str:
    """예외 클래스 이름 + 진단 필드(있으면) — 루프 로그 한 줄의 몸통."""
    detail = _diagnostics(exc)
    return f"{type(exc).__name__} {detail}" if detail else type(exc).__name__


class _PollFatal(Exception):
    """패스 전 poll이 올린 치명 꼴 예외(.error)를 루프로 나르는 내부 신호(L7 — 메시지 없음)."""

    def __init__(self, error: BaseException) -> None:
        super().__init__()
        self.error = error


def _poll(producer: Any) -> None:
    """패스 전 poll(0)(L7 — 모듈 독스트링 「패스 전 poll」): 치명 꼴 예외(relay._fatal_exception_name)면 _PollFatal로 올린다(루프가
    행에 닿기 전에 프로듀서를 버린다) · 그 밖의 예외는 그대로 올린다(일반 오류 경로)."""
    try:
        producer.poll(0)
    except Exception as exc:
        if relay._fatal_exception_name(exc) is None:
            raise
        raise _PollFatal(exc) from exc


def _positive_int(text: str) -> int:
    value = int(text)
    if value < 1:
        raise argparse.ArgumentTypeError("1 이상의 정수여야 한다")
    return value


def _non_negative_int(text: str) -> int:
    value = int(text)
    if value < 0:
        raise argparse.ArgumentTypeError("0 이상의 정수여야 한다")
    return value


def _non_negative_seconds(text: str) -> float:
    value = float(text)
    if not math.isfinite(value) or value < 0:
        raise argparse.ArgumentTypeError("0 이상의 유한한 초여야 한다")
    return value


def _port(text: str) -> int:
    value = int(text)
    if not 0 <= value <= 65535:
        raise argparse.ArgumentTypeError("0–65535여야 한다(0 = 지표 서버를 열지 않는다)")
    return value


class _Stop:
    """신호 처리기가 세우는 플래그(잠금 없음 — 처리기는 주 스레드에서 돈다)."""

    def __init__(self) -> None:
        self.requested = False

    def handler(self, _signum: int, _frame: FrameType | None) -> None:
        self.requested = True


def _install_handlers(stop: _Stop) -> dict[int, Any]:
    if threading.current_thread() is not threading.main_thread():
        return {}
    return {signum: signal.signal(signum, stop.handler) for signum in _SIGNALS}


def _restore_handlers(previous: dict[int, Any]) -> None:
    for signum, handler in previous.items():
        if handler is not None:  # None = 파이썬 밖에서 단 처리기(되돌릴 수 없다)
            signal.signal(signum, handler)


def _sleep(seconds: float, stop: _Stop) -> None:
    deadline = time.monotonic() + seconds
    while not stop.requested:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return
        time.sleep(min(_SLICE_S, remaining))


def _refresh(metrics: ModuleType) -> float:
    """refresh_metrics() — 실패는 로그만(DB 오류면 연결 정리). 돌려주는 값 = 부른 시각(monotonic)."""
    try:
        metrics.refresh_metrics()
    except Exception as exc:
        logger.warning("outbox_relay.refresh_error %s", _described(exc))
        if isinstance(exc, (db.OperationalError, db.InterfaceError)):
            db.close_old_connections()
    return time.monotonic()


class Command(BaseCommand):
    help = (
        "outbox 릴레이(relay 컨테이너): dead_at IS NULL 행을 FOR UPDATE SKIP LOCKED로 골라 Kafka로 보내고(실패는 attempts · "
        "OUTBOX_MAX_ATTEMPTS에서 DLQ) 지표를 prometheus_client HTTP 포트로 노출한다. 루프 안 오류로 끝나지 않는다(로그 + 백오프). "
        "정상 종료는 SIGTERM · SIGINT뿐이고, 오류로 끝나는 것은 기동 전 실패와 지표 포트를 열 수 없을 때뿐이다. 인자 없는 "
        "기본값이 계약 값이다."
    )

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument("--batch-size", type=_positive_int, default=100, help="한 패스에서 고를 행 수(기본 100).")
        parser.add_argument(
            "--poll-interval",
            type=_non_negative_seconds,
            default=0.5,
            help="패스 사이 기본 대기 초(기본 0.5 · 0은 시험용 — 오류 · 진전 없음 백오프는 0이어도 0.5 s 하한에서 자란다).",
        )
        parser.add_argument(
            "--max-backoff", type=_non_negative_seconds, default=300.0, help="진전 없는 패스의 대기 상한 초(기본 300)."
        )
        parser.add_argument(
            "--metrics-port", type=_port, default=9464, help="지표 HTTP 포트(기본 9464 · 0 = 열지 않는다)."
        )
        parser.add_argument("--iterations", type=_non_negative_int, default=0, help="반복 수(기본 0 = 무한).")

    def handle(self, *args: Any, **options: Any) -> None:
        batch_size: int = options["batch_size"]
        poll_interval: float = options["poll_interval"]
        max_backoff: float = options["max_backoff"]
        metrics_port: int = options["metrics_port"]
        iterations: int = options["iterations"]
        if max_backoff < poll_interval:
            raise CommandError("--max-backoff는 --poll-interval 이상이어야 한다")

        import prometheus_client

        from django_common.outbox import metrics

        server = None
        if metrics_port:
            try:
                server, _thread = prometheus_client.start_http_server(metrics_port)
            except OSError as exc:
                raise CommandError(
                    f"지표 포트를 열 수 없다(--metrics-port {metrics_port} · {type(exc).__name__})"
                ) from None
        stop = _Stop()
        previous_handlers = _install_handlers(stop)
        passes = 0
        try:
            logger.info(
                "outbox_relay.start batch_size=%d poll_interval=%s max_backoff=%s metrics_port=%d iterations=%d",
                batch_size,
                poll_interval,
                max_backoff,
                metrics_port,
                iterations,
            )
            refreshed_at = _refresh(metrics)
            producer: Any = None
            after_fatal_rebuild = False  # 치명으로 버린 뒤 결과를 돌려준 첫 패스까지 선다(M1 — 「대기 next_wait」)
            wait = poll_interval
            while not stop.requested:
                passes += 1
                db.close_old_connections()
                result: RelayResult | None = None
                try:
                    if producer is None:
                        producer = relay.build_producer()
                    _poll(producer)
                    result = relay.relay_once(producer=producer, batch_size=batch_size)
                except _PollFatal as exc:
                    producer = None  # 행에 닿기 전에 버린다(L7) — 이 반복은 오류(백오프)로 센다
                    after_fatal_rebuild = True
                    logger.warning("outbox_relay.producer_fatal %s published=0 failed=0 dead=0", _described(exc.error))
                except relay.ProducerFatalError as exc:
                    producer = None
                    after_fatal_rebuild = True
                    logger.warning(
                        "outbox_relay.producer_fatal %s published=%d failed=%d dead=%d",
                        _described(exc),
                        exc.result.published,
                        exc.result.failed,
                        exc.result.dead,
                    )
                except (db.OperationalError, db.InterfaceError) as exc:
                    logger.warning("outbox_relay.db_error %s", _described(exc))
                    db.close_old_connections()
                except Exception as exc:
                    logger.warning("outbox_relay.error %s", _described(exc))
                else:
                    if result.published or result.failed or result.dead:
                        logger.info(
                            "outbox_relay.pass published=%d failed=%d dead=%d",
                            result.published,
                            result.failed,
                            result.dead,
                        )
                wait = next_wait(
                    result,
                    poll_interval=poll_interval,
                    max_backoff=max_backoff,
                    previous=wait,
                    after_fatal_rebuild=after_fatal_rebuild,
                )
                if result is not None:
                    after_fatal_rebuild = False  # 결과를 돌려준 첫 패스에서 지운다(오류로 끝난 반복에서는 남는다 · M1)
                back_to_back = result is not None and result.truncated
                if not back_to_back or time.monotonic() - refreshed_at >= REFRESH_MIN_INTERVAL_S:
                    refreshed_at = _refresh(metrics)
                if iterations and passes >= iterations:
                    break
                _sleep(wait, stop)
        finally:
            _restore_handlers(previous_handlers)
            if server is not None:
                server.shutdown()
                server.server_close()
            logger.info("outbox_relay.stop passes=%d", passes)
