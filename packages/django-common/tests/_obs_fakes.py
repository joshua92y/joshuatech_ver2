"""T071 계약 시험 도우미(T071 소유 · tests/test_observability_contract.py가 쓴다).

- CaptureTransport: 네트워크 없이 Sentry envelope를 가로채는 Transport 하위 클래스(capture_envelope 하나만 구현 — flush ·
  kill은 기본 no-op). events()는 event 항목의 payload(직렬화된 dict)만, item_types()는 envelope 항목 유형 전부를 준다.
  envelope_headers()는 envelope 머리(trace = dynamic sampling context가 실리는 자리), serialized()는 envelope 직렬화 바이트 전부를
  준다(T071 r2 Y3 — 머리 · 항목 어디에도 값이 없다는 단언용).
- HeaderRecorder: 127.0.0.1 임시 포트의 HTTP 서버 — 받은 요청마다 헤더 이름(소문자)을 기록한다(나가는 http.client 요청에
  sentry-trace · baggage가 붙는지 본다).
- CountingListener: 127.0.0.1 임시 포트에서 연결을 받자마자 닫고 수락 수를 센다(의존에 「다이얼했는가」를 시간 · 플랫폼과
  무관하게 본다 — test_observability.py _counting_listener와 같은 방식 · T063 산출물은 고치지 않으므로 따로 둔다).
- blackhole(): listen만 하고 accept하지 않는 소켓의 포트(커널이 연결을 받아 두고 아무것도 보내지 않는다 — 연결은 성립하고
  응답이 없다 · OS와 무관하게 시간 초과까지 기다리게 한다).
- closed_port(): 연결을 받지 않는 127.0.0.1 포트.
- call_wsgi(environ): 실제 django WSGIHandler()(environ, start_response) 경로로 요청 하나를 처리한다 — Sentry가 패치한
  WSGIHandler.__call__(요청 헤더 · 쿼리 · env를 이벤트에 싣는 층)을 거친다. django.test.Client는 그 층을 거치지 않아 헤더
  시험이 공허하다(research sentry F19).

비밀이 아니다: 서버는 127.0.0.1에만 묶고 바깥 이름을 조회하지 않는다. Django를 모듈 수준에서 import하지 않는다.
"""

from __future__ import annotations

import contextlib
import socket
import threading
from collections.abc import Iterator
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from sentry_sdk.envelope import Envelope
from sentry_sdk.transport import Transport

LOOPBACK = "127.0.0.1"


class CaptureTransport(Transport):
    """Sentry envelope를 목록에 쌓는 Transport — 전송 · 네트워크 0(시험 이음매 configure_sentry(transport=))."""

    def __init__(self) -> None:
        super().__init__()
        self._lock = threading.Lock()
        self._envelopes: list[Envelope] = []

    def capture_envelope(self, envelope: Envelope) -> None:
        with self._lock:
            self._envelopes.append(envelope)

    def _snapshot(self) -> list[Envelope]:
        with self._lock:
            return list(self._envelopes)

    def events(self) -> list[dict[str, Any]]:
        """지금까지 받은 오류 이벤트(event 항목 payload — before_send를 거친 직렬화 dict)."""
        found: list[dict[str, Any]] = []
        for envelope in self._snapshot():
            event = envelope.get_event()
            if event is not None:
                found.append(event)
        return found

    def item_types(self) -> list[str]:
        """지금까지 받은 envelope 항목 유형 전부(event · session · sessions · client_report …)."""
        return [str(item.type) for envelope in self._snapshot() for item in envelope.items]

    def envelope_headers(self) -> list[dict[str, Any]]:
        """지금까지 받은 envelope 머리(사본 — event_id · sent_at · 있으면 trace(dynamic sampling context))."""
        return [dict(envelope.headers) for envelope in self._snapshot()]

    def serialized(self) -> list[bytes]:
        """지금까지 받은 envelope 직렬화 바이트(머리 · 항목 머리 · payload 전부)."""
        return [envelope.serialize() for envelope in self._snapshot()]


class HeaderRecorder:
    """127.0.0.1 임시 포트의 HTTP 서버(데몬 스레드) — GET마다 헤더 이름(소문자 · 정렬)을 requests에 쌓고 200 빈 본문을 준다."""

    def __init__(self) -> None:
        self.requests: list[list[str]] = []
        self._lock = threading.Lock()
        recorder = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:  # 메서드 이름은 BaseHTTPRequestHandler 규약(do_<METHOD>)이다
                with recorder._lock:
                    recorder.requests.append(sorted(name.lower() for name in self.headers))
                self.send_response(HTTPStatus.OK)
                self.send_header("Content-Length", "0")
                self.end_headers()

            def log_message(self, format: str, *args: Any) -> None:  # 인자 이름 format은 부모 시그니처 그대로다
                """요청 로그를 끈다(기본 구현은 요청마다 stderr에 한 줄을 쓴다)."""

        self._server = ThreadingHTTPServer((LOOPBACK, 0), Handler)
        self._thread = threading.Thread(
            target=self._server.serve_forever, kwargs={"poll_interval": 0.05}, name="obs-header-recorder", daemon=True
        )
        self._thread.start()

    @property
    def url(self) -> str:
        return f"http://{LOOPBACK}:{self._server.server_address[1]}/probe"

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)


class CountingListener:
    """127.0.0.1 임시 포트 — 연결을 받자마자 닫고 수락 수를 센다(데몬 스레드 · 닫으면 멈춘다)."""

    def __init__(self) -> None:
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.bind((LOOPBACK, 0))
        self._socket.listen(16)
        self._socket.settimeout(0.1)
        self.port: int = self._socket.getsockname()[1]
        self._lock = threading.Lock()
        self._count = 0
        self._stopped = threading.Event()
        self._thread = threading.Thread(target=self._serve, name="obs-counting-listener", daemon=True)
        self._thread.start()

    @property
    def address(self) -> str:
        return f"{LOOPBACK}:{self.port}"

    @property
    def count(self) -> int:
        with self._lock:
            return self._count

    def _serve(self) -> None:
        while not self._stopped.is_set():
            try:
                connection, _ = self._socket.accept()
            except TimeoutError:
                continue
            except OSError:
                return
            with self._lock:
                self._count += 1
            connection.close()

    def close(self) -> None:
        self._stopped.set()
        self._thread.join(timeout=2)
        self._socket.close()


@contextlib.contextmanager
def blackhole(backlog: int = 16) -> Iterator[int]:
    """응답 없는 소켓의 포트(listen만 · accept 없음) — 나가면 닫는다(기다리던 클라이언트는 그때 끊긴다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sink:
        sink.bind((LOOPBACK, 0))
        sink.listen(backlog)
        yield sink.getsockname()[1]


def closed_port() -> int:
    """연결을 받지 않는 127.0.0.1 포트 — bind로 번호만 받고 닫는다."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind((LOOPBACK, 0))
        port: int = probe.getsockname()[1]
    return port


@dataclass(frozen=True)
class WsgiResult:
    """WSGI 응답 — 상태 코드 · 헤더(이름 소문자) · 본문."""

    status: int
    headers: dict[str, str]
    body: bytes


def call_wsgi(environ: dict[str, Any]) -> WsgiResult:
    """django WSGIHandler()로 environ 하나를 처리한다(미들웨어는 지금 settings.MIDDLEWARE로 새로 적재 · 응답을 끝까지 읽고
    close()한다 — request_finished 신호까지)."""
    from django.core.handlers.wsgi import WSGIHandler

    started: list[tuple[str, list[tuple[str, str]]]] = []

    def start_response(status: str, headers: list[tuple[str, str]], exc_info: Any = None) -> Any:
        started.append((status, headers))
        return lambda data: None

    handler = WSGIHandler()
    iterable = handler(environ, start_response)
    try:
        body = b"".join(iterable)
    finally:
        close = getattr(iterable, "close", None)
        if close is not None:
            close()
    status_line, headers = started[-1]
    return WsgiResult(
        status=int(status_line.split(" ", 1)[0]),
        headers={name.lower(): value for name, value in headers},
        body=body,
    )
