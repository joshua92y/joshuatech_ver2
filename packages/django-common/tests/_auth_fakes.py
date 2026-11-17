"""T070 계약 시험 도우미(T070 소유 · tests/test_auth_contract.py가 쓴다) — Django를 모듈 수준에서 import하지 않는다.

- KeyServer: 127.0.0.1 임시 포트의 키 서버(ThreadingHTTPServer · 데몬 스레드). 경로마다 JWKS 문서와 모드를 두고 시험
  중에 모드를 바꾼다. 모드: ok(문서 그대로) · status-500(사유 문구 · 본문 = 감시 문자열) · not-json(본문 = 감시 문자열) ·
  non-object(JSON 배열) · empty-keys(`{"keys": []}`) · no-signing-keys(kid를 뺀 키만 — PyJWT가 쓸 수 있는 키지만 서명 키
  후보가 아니다). 경로별 GET 수를 센다(hits).
  경로마다 응답 전 지연을 둘 수 있다(set_delay · T070 r5 W3 — 느린 성공 fetch · GET 수는 기다리기 전에 센다 · 요청마다 처리
  스레드가 따로 기다린다).
- FirstByteServer: TCP 연결마다 첫 바이트만 기록하고 닫는 서버 — 키 fetch가 https로 갔는지(TLS ClientHello 첫 바이트
  0x16) 평문 http로 갔는지(`G`) 가른다. 인증서 없이 · 네트워크 없이 스킴 접두를 관찰한다.
- blackhole() · closed_port(): 응답 없는 소켓(listen만 · accept 없음 — 연결은 성립하고 응답이 없다) · 연결을 받지 않는 포트.
- ShiftedClock · install_shifted_clock(): PyJWT 키 캐시 시계(jwt.jwks_client · jwt.api_jwk · jwt.jwk_set_cache 모듈의
  `time` — 셋 다 time.monotonic()만 쓴다)와 구현의 키 fetch 백오프 시계(django_common.auth 모듈의 `time` — 시계로는
  time.monotonic()만 쓴다 · T070 r3 U4)를 앞으로 돌리는 대역. 1시간 lifespan · 30 s cooldown · 백오프 창(1–30 s)을 실제로
  기다리지 않고 가른다. 토큰 exp · nbf · iat 검증(PyJWT api_jwt — datetime.now)과 구현의 지표 시계(time.perf_counter —
  ShiftedClock이 진짜 time으로 넘긴다)는 그대로다.
- name_lookups(): socket 이름 조회(getaddrinfo · gethostbyname · gethostbyname_ex)를 감싸 IP 리터럴이 아닌 이름을 기록하고
  막는다(socket.gaierror — 조회 질의가 나가지 않는다). 시험 · 도우미 · 구현의 공개 DNS 조회 0을 단언하는 데 쓴다.
- install_lockless_parent() · install_plain_lock_parent()(T070 r4 V4): PyJWT 2.15.1 PyJWKClient에서 클라이언트 잠금
  (`_client_lock`)만 바꾼 부모 대역 — 잠금 없음(__init__ 뒤 속성 삭제 + 잠금만 뺀 같은 논리의 get_signing_key) · 재진입 불가
  threading.Lock(get_signing_key는 그대로). 구현의 백오프 잠금이 PyJWT 비공개 속성에 기대지 않는지 가른다. 만든 클라이언트를
  차례로 담은 목록을 돌려준다(시험이 바꾼 잠금이 정말 걸렸는지 본다).

비밀이 아니다: 감시 문자열 · 키 문서(공개 키)만 다룬다. 서버는 127.0.0.1에만 묶는다.
"""

from __future__ import annotations

import contextlib
import copy
import ipaddress
import json
import socket
import threading
import time
from collections.abc import Iterator
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from types import ModuleType
from typing import TYPE_CHECKING, Any

import jwt.api_jwk
import jwt.jwk_set_cache
import jwt.jwks_client

if TYPE_CHECKING:
    import pytest

LOOPBACK = "127.0.0.1"
KEY_SERVER_MODES = ("ok", "status-500", "not-json", "non-object", "empty-keys", "no-signing-keys")
# PyJWT 키 캐시 시계를 쓰는 모듈(2.15.1 소스 — 셋 다 `import time` 뒤 time.monotonic()만 부른다).
_PYJWT_CLOCK_MODULES: tuple[ModuleType, ...] = (jwt.jwks_client, jwt.api_jwk, jwt.jwk_set_cache)
# 구현의 백오프 시계(T070 r3 U4) — 이름 경로로 바꾼다(이 모듈은 Django를 모듈 수준에서 import하지 않는다 · monkeypatch가 그때
# import한다).
_AUTH_CLOCK_TARGET = "django_common.auth.time"
_LOOKUP_FUNCTIONS = ("getaddrinfo", "gethostbyname", "gethostbyname_ex")


class KeyServer:
    """경로 → JWKS 문서를 주는 로컬 키 서버 — 경로마다 모드를 시험 중에 바꾼다(KEY_SERVER_MODES).

    marker는 오류 응답(사유 문구 · 본문)에 심는 감시 문자열이다 — 구현이 라이브러리 예외 문자열을 응답 · 로그에 싣는지 본다.
    """

    def __init__(self, documents: dict[str, dict[str, Any]], marker: str) -> None:
        self._documents = {path: copy.deepcopy(document) for path, document in documents.items()}
        self._marker = marker
        self._lock = threading.Lock()
        self.modes: dict[str, str] = dict.fromkeys(documents, "ok")
        self.hits: dict[str, int] = dict.fromkeys(documents, 0)
        self.delays: dict[str, float] = dict.fromkeys(documents, 0.0)  # 경로별 응답 전 지연(초 · set_delay — T070 r5 W3)
        self._server = ThreadingHTTPServer((LOOPBACK, 0), self._handler())
        # poll_interval 0.05 s — shutdown()이 기본 0.5 s 주기를 기다리지 않게(시험마다 서버를 새로 띄운다).
        self._thread = threading.Thread(
            target=self._server.serve_forever, kwargs={"poll_interval": 0.05}, name="auth-key-server", daemon=True
        )
        self._thread.start()

    @property
    def base_url(self) -> str:
        return f"http://{LOOPBACK}:{self._server.server_address[1]}"

    def url(self, path: str) -> str:
        return self.base_url + path

    def set_mode(self, path: str, mode: str) -> None:
        if mode not in KEY_SERVER_MODES or path not in self._documents:
            raise ValueError("모르는 경로 또는 모드")
        with self._lock:
            self.modes[path] = mode

    def set_delay(self, path: str, seconds: float) -> None:
        """path 응답 전에 기다릴 시간(초 · 0이면 곧바로 답한다 — T070 r5 W3 느린 키 엔드포인트). 처리 스레드가 요청마다 따로
        기다린다(ThreadingHTTPServer) · GET 수(hits)는 기다리기 전에 센다 · 상한 5 s(처리 스레드는 데몬이라 close가 기다리지
        않는다 — 시험이 끝난 뒤 남을 수 있는 대기를 짧게 묶는다)."""
        if path not in self._documents or not 0 <= seconds <= 5:
            raise ValueError("모르는 경로 또는 지연")
        with self._lock:
            self.delays[path] = seconds

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)

    def _body(self, path: str) -> tuple[int, str, bytes]:
        """(상태 · 사유 문구 · 본문) — 지금 모드 그대로."""
        with self._lock:
            mode = self.modes[path]
        document = self._documents[path]
        if mode == "ok":
            return HTTPStatus.OK, "OK", json.dumps(document).encode()
        if mode == "status-500":
            return HTTPStatus.INTERNAL_SERVER_ERROR, self._marker, self._marker.encode()
        if mode == "not-json":
            return HTTPStatus.OK, "OK", self._marker.encode()
        if mode == "non-object":
            return HTTPStatus.OK, "OK", json.dumps([self._marker]).encode()
        if mode == "empty-keys":
            return HTTPStatus.OK, "OK", json.dumps({"keys": []}).encode()
        keys = [{name: value for name, value in key.items() if name != "kid"} for key in document["keys"]]
        return HTTPStatus.OK, "OK", json.dumps({"keys": keys}).encode()

    def _handler(self) -> type[BaseHTTPRequestHandler]:
        server = self

        class KeyHandler(BaseHTTPRequestHandler):
            def do_GET(self) -> None:  # 메서드 이름은 BaseHTTPRequestHandler 규약(do_<METHOD>)이다
                with server._lock:
                    server.hits[self.path] = server.hits.get(self.path, 0) + 1
                    delay = server.delays.get(self.path, 0.0)
                if self.path not in server._documents:
                    self.send_error(HTTPStatus.NOT_FOUND)
                    return
                if delay:
                    time.sleep(delay)  # 느린 키 엔드포인트(set_delay) — 이 요청의 처리 스레드만 기다린다
                status, reason, body = server._body(self.path)
                self.send_response(status, reason)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format: str, *args: Any) -> None:  # 인자 이름 format은 부모 시그니처 그대로다
                """요청 로그를 끈다(기본 구현은 요청마다 stderr에 한 줄을 쓴다)."""

        return KeyHandler


class FirstByteServer:
    """TCP 연결마다 첫 바이트만 기록하고 닫는 서버(127.0.0.1 임시 포트 · 데몬 스레드 하나).

    TLS 클라이언트의 첫 바이트는 레코드 유형 0x16(handshake)이고, 평문 HTTP GET은 `G`(0x47)다. 기록은 받은 순서대로
    first_bytes에 쌓인다(빈 연결은 -1).
    """

    def __init__(self) -> None:
        self._socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._socket.bind((LOOPBACK, 0))
        self._socket.listen(8)
        self._socket.settimeout(0.1)
        self.port: int = self._socket.getsockname()[1]
        self.first_bytes: list[int] = []
        self._stopped = threading.Event()
        self._thread = threading.Thread(target=self._serve, name="auth-first-byte", daemon=True)
        self._thread.start()

    def _serve(self) -> None:
        while not self._stopped.is_set():
            try:
                connection, _ = self._socket.accept()
            except TimeoutError:
                continue
            except OSError:
                return
            with connection:
                connection.settimeout(5)
                try:
                    data = connection.recv(1)
                except OSError:
                    data = b""
            self.first_bytes.append(data[0] if data else -1)

    def wait_for(self, count: int, timeout_s: float = 5.0) -> list[int]:
        """기록이 count개 쌓일 때까지(최대 timeout_s) 기다려 기록 사본을 돌려준다."""
        deadline = time.monotonic() + timeout_s
        while len(self.first_bytes) < count and time.monotonic() < deadline:
            time.sleep(0.02)
        return list(self.first_bytes)

    def close(self) -> None:
        self._stopped.set()
        self._socket.close()
        self._thread.join(timeout=5)


@contextlib.contextmanager
def blackhole() -> Iterator[int]:
    """응답 없는 소켓의 포트(listen만 · accept 없음 — 커널이 연결을 받아 두고 아무것도 보내지 않는다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sink:
        sink.bind((LOOPBACK, 0))
        sink.listen(1)
        yield sink.getsockname()[1]


def closed_port() -> int:
    """연결을 받지 않는 127.0.0.1 포트 — bind로 번호만 받고 닫는다."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind((LOOPBACK, 0))
        port: int = probe.getsockname()[1]
    return port


class ShiftedClock:
    """time 모듈 대역 — monotonic()만 offset만큼 앞선 값을 주고 나머지 이름은 진짜 time 모듈로 넘긴다."""

    def __init__(self) -> None:
        self.offset = 0.0

    def monotonic(self) -> float:
        return time.monotonic() + self.offset

    def advance(self, seconds: float) -> None:
        self.offset += seconds

    def __getattr__(self, name: str) -> Any:
        return getattr(time, name)


def install_shifted_clock(monkeypatch: pytest.MonkeyPatch) -> ShiftedClock:
    """PyJWT 키 캐시 시계 세 모듈과 django_common.auth(키 fetch 백오프 창 · T070 r3 U4)의 `time`을 ShiftedClock 하나로
    바꾼다(같은 시계로 함께 앞으로 간다 · monkeypatch가 시험 끝에 되돌린다)."""
    clock = ShiftedClock()
    for module in _PYJWT_CLOCK_MODULES:
        monkeypatch.setattr(module, "time", clock)
    monkeypatch.setattr(_AUTH_CLOCK_TARGET, clock)
    return clock


def _is_ip_literal(host: object) -> bool:
    if host is None:
        return True
    if isinstance(host, bytes):
        host = host.decode("ascii", errors="replace")
    if not isinstance(host, str):
        return False
    try:
        ipaddress.ip_address(host.strip("[]"))
    except ValueError:
        return False
    return True


@contextlib.contextmanager
def name_lookups(monkeypatch: pytest.MonkeyPatch) -> Iterator[list[str]]:
    """IP 리터럴이 아닌 이름의 조회를 기록하고 막는다(socket.gaierror). 프록시 env를 끈다 — 프록시 경유 요청은 이름 조회가
    프록시 이름으로 바뀌어 감시 밖이 된다(urllib은 env 프록시 사전이 비어 있지 않으면 Windows 레지스트리 프록시를 읽지
    않으므로 NO_PROXY = "*"를 둔다)."""
    for name in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy"):
        monkeypatch.delenv(name, raising=False)
    for name in ("NO_PROXY", "no_proxy"):
        monkeypatch.setenv(name, "*")
    attempts: list[str] = []

    def guarded(real: Any) -> Any:
        def lookup(host: object, *args: Any, **kwargs: Any) -> Any:
            if not _is_ip_literal(host):
                attempts.append(str(host))
                raise socket.gaierror(socket.EAI_NONAME, "시험 가드: 이름 조회 금지")
            return real(host, *args, **kwargs)

        return lookup

    for function in _LOOKUP_FUNCTIONS:
        monkeypatch.setattr(socket, function, guarded(getattr(socket, function)))
    yield attempts


def install_lockless_parent(monkeypatch: pytest.MonkeyPatch) -> list[jwt.jwks_client.PyJWKClient]:
    """클라이언트 잠금이 없는 PyJWKClient 부모 대역(T070 r4 V4) — __init__ 뒤 `_client_lock`을 지우고 get_signing_key를 잠금만
    뺀 같은 논리(_get_signing_key_without_lock)로 바꾼다. 만든 클라이언트를 차례로 담은 목록을 돌려준다(monkeypatch가 시험 끝에
    되돌린다)."""
    created: list[jwt.jwks_client.PyJWKClient] = []
    real_init = jwt.jwks_client.PyJWKClient.__init__

    def init_without_lock(self: jwt.jwks_client.PyJWKClient, *args: Any, **kwargs: Any) -> None:
        real_init(self, *args, **kwargs)
        vars(self).pop("_client_lock", None)
        created.append(self)

    monkeypatch.setattr(jwt.jwks_client.PyJWKClient, "__init__", init_without_lock)
    monkeypatch.setattr(jwt.jwks_client.PyJWKClient, "get_signing_key", _get_signing_key_without_lock)
    return created


def install_plain_lock_parent(monkeypatch: pytest.MonkeyPatch) -> list[jwt.jwks_client.PyJWKClient]:
    """클라이언트 잠금이 재진입 불가 threading.Lock인 PyJWKClient 부모 대역(T070 r4 V4) — __init__ 뒤 `_client_lock`을
    threading.Lock()으로 바꾼다. get_signing_key는 2.15.1 그대로라 그 잠금을 쥔 채 get_signing_keys → get_jwk_set →
    fetch_data를 부른다(fetch_data 안에서 같은 스레드가 그 잠금을 다시 쥐면 영원히 멈춘다). 만든 클라이언트 목록을 돌려준다."""
    created: list[jwt.jwks_client.PyJWKClient] = []
    real_init = jwt.jwks_client.PyJWKClient.__init__

    def init_with_plain_lock(self: jwt.jwks_client.PyJWKClient, *args: Any, **kwargs: Any) -> None:
        real_init(self, *args, **kwargs)
        self._client_lock = threading.Lock()
        created.append(self)

    monkeypatch.setattr(jwt.jwks_client.PyJWKClient, "__init__", init_with_plain_lock)
    return created


def _get_signing_key_without_lock(self: jwt.jwks_client.PyJWKClient, kid: str) -> jwt.api_jwk.PyJWK:
    """PyJWT 2.15.1 PyJWKClient.get_signing_key(jwks_client.py:263–298)에서 `with self._client_lock:`만 뺀 같은 논리 — 키
    집합(캐시 · fetch)에서 kid를 찾고, 없으면 cooldown 밖일 때만 한 번 다시 가져온다(시계는 PyJWT 모듈의 time 그대로)."""
    signing_keys = self.get_signing_keys()
    signing_key = self.match_kid(signing_keys, kid)
    if not signing_key:
        cooling_down = (
            self.jwk_set_cache is not None
            and self._last_successful_fetch is not None
            and jwt.jwks_client.time.monotonic() - self._last_successful_fetch < self.cooldown_duration
        )
        if not cooling_down:
            signing_keys = self.get_signing_keys(refresh=True)
            self._last_successful_fetch = jwt.jwks_client.time.monotonic()
            signing_key = self.match_kid(signing_keys, kid)
        if not signing_key:
            raise jwt.jwks_client.PyJWKClientError(f'Unable to find a signing key that matches: "{kid}"')
    return signing_key
