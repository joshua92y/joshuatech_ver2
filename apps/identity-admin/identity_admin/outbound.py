"""외부 HTTP 클라이언트(T073 설계 D20 — pod 소유 새 파일) — 클러스터 안 Authentik · OpenFGA 관리 API에 JSON 요청 한 번.

정본: contracts/identity-admin-api.md §타임아웃 · 재시도(identity-admin → Authentik 행) · 설계 D20 · D16 · D17 · D19 · 사실 ㉙.
표준 라이브러리만 쓴다(urllib · http.client — requests · httpx를 들이지 않는다 · 설계 D20 「기각」).

request_json(method, url, *, token, body=None, deadline=None) -> Any
- opener: 호출마다 OpenerDirector를 직접 짓는다 — HTTP 핸들러(URL 스킴이 https면 HTTPS 핸들러도)와 오류 처리기
  (HTTPDefaultErrorHandler · HTTPErrorProcessor)만 단다. build_opener가 기본으로 다는 프록시 · 리디렉션 · file · ftp · data 핸들러가
  없다: 프록시 env를 무시하고(서비스 계정 토큰이 프록시로 가지 않는다) 3xx는 오류다(urllib 기본 리디렉션은 302 뒤 다른 호스트로
  Authorization을 다시 보낸다 — 조각 ① 실측). HTTPS 핸들러는 만들 때마다 기본 SSL 컨텍스트를 새로 지어(시스템 CA 적재 — 평문
  호출 시간의 거의 전부다 · 리뷰 실측 약 12 ms) https URL에서만 짓는다. 두 핸들러는 debuglevel=0이다(전역
  `http.client.HTTPConnection.debuglevel`이 켜져도 Authorization이 든 요청 헤더를 stdout에 찍지 않는다).
- 스킴: 호출마다 http · https만 받는다(그 밖은 호출 0 · UpstreamUnavailable("scheme") — 설정은 실행 중에 바뀔 수 있어 기동 검사만으로는
  모자란다).
- 헤더: `Authorization: Bearer <token>` · `Accept: application/json` · `User-Agent: identity-admin/<APP_VERSION>`(호출 때의
  설정) · 본문이 있으면 `Content-Type: application/json`(본문 = json.dumps). 토큰은 공백 없는 출력 가능 ASCII(`!`-`~`)만 받는다 —
  `token=` 인자(seed의 stdin 토큰 · 시험)는 기동 게이트를 지나지 않는다. http.client는 CR · LF가 든 헤더 값을 ValueError 문구에
  통째로 싣고, latin-1 글자와 「LF + 공백」(줄 접기)은 그대로 보낸다.
- 요청 준비 단계(헤더 조립 · 본문 직렬화 · URL · 메서드 · 연결 인자)의 ValueError(UnicodeEncodeError 포함) · OverflowError ·
  http.client.InvalidURL과 본문 직렬화의 TypeError(json.dumps — 문구에 형 이름이 실린다) · RecursionError(재귀 한도를 넘게 깊이
  중첩된 본문 — 응답 쪽 json.loads와 같은 접기)는 종류만 담은 UpstreamUnavailable("invalid_request")로 접는다(문구에 헤더 값 ·
  URL이 실린다 — 사실 ㉙). 호스트 없는 URL(`http:/x` · `http://` — urllib이 reason이 문자열인 URLError('no host given')를 낸다)과
  붙인 핸들러 가운데 그 URL을 맡는 것이 없어 opener.open()이 None을 준 URL(urlsplit은 http로 읽고 urllib Request는 모르는 스킴으로
  읽는다 — 예: 스킴 글자 사이의 탭)도 invalid_request다(다시 해도 같은 입력이다 · 조각 ⑤-b V2).
- 시간: 소켓 동작마다 5 s(DEFAULT_TIMEOUT_S). deadline(Deadline — 단조 시계)을 주면 호출 앞에서 남은 시간을 보고(0 이하면 호출 0 ·
  UpstreamUnavailable("deadline")) 소켓 타임아웃을 min(5, 남은 시간)으로 두며, 응답 본문을 64 KiB씩(read1 — 한 번에 시스템 호출
  하나) 읽는 사이에도 본다. 마감은 이 두 자리(호출 앞 · 응답 본문을 읽는 사이)에서만 본다. 이름 조회에는 타임아웃이 걸리지
  않는다(리졸버 설정이 상한 — 느리면 그만큼 마감을 넘기고, 그 호출의 요청은 마감이 지난 뒤에도 나간다 · 조각 ④ 검증 실측) · 해석된
  주소마다의 연결과 상태 줄 · 헤더(100-continue · chunk 틀 포함) 단계에는 소켓 동작마다의 타임아웃만 걸린다 — 바이트를 조금씩
  흘리는 상대에서는 한 호출이 마감을 넘길 수 있다(멈춘 상대는 그 타임아웃에 끊기고, 마감이 지난 뒤의 호출은 보내지 않는다 —
  contracts/identity-admin-api.md §타임아웃 「identity-admin → Authentik」 행). 본문 단계에서 마감을 넘는 폭은 소켓 동작 하나(≤ 그
  타임아웃)까지다. 소켓 시간
  초과의 종류: 마감을 받았고 소켓 타임아웃이 남은 시간으로 줄어 있었거나(timeout < DEFAULT_TIMEOUT_S) 시간 초과가 난 때 마감이 이미
  지났으면 deadline이고, 아니면 timeout이다.
- 크기: 응답 본문이 1 MiB(MAX_RESPONSE_BYTES)를 넘으면 읽기를 멈추고 UpstreamUnavailable("too_large")(다시 해도 같다).
- 반환: 디코드한 JSON 값(빈 본문 — 204 등 — 은 None). 2xx가 아니면 UpstreamStatus(status)(3xx 포함 · 본문을 읽지 않는다). JSON이
  아니면 UpstreamUnavailable("malformed"). 본문이 Content-Length에 못 미쳐 끊기면(일부 · 0바이트 뒤 FIN) UpstreamUnavailable
  ("connection")이다 — read1은 남은 길이가 있어도 EOF에서 빈 바이트를 줄 뿐 IncompleteRead를 내지 않아 response.length(남은
  바이트 수 · chunked와 길이 없는 응답은 None · 다 읽었거나 204면 0)로 가른다. 길이 없는 응답(연결 종료가 본문 끝)의 끊김은
  가를 수 없어 JSON이 깨지면 malformed다.
- 오류 형: UpstreamError ⊃ UpstreamStatus(status) · UpstreamUnavailable(kind). args · str · repr에는 상태 코드나 종류만 담는다(URL ·
  질의(사용자 uuid) · 토큰 · 본문 없음). 예외는 except 블록 밖에서 `raise … from None`으로 올린다(__cause__ · __context__ None ·
  __suppress_context__ 참 — Celery 실패 로그와 Django robust 로그는 연쇄 예외까지 찍는다 · 설계 D20 「연쇄 끊기」).
  `.transient`: UpstreamStatus는 429 · 5xx일 때 참 · UpstreamUnavailable은 connection · timeout · deadline일 때 참(scheme ·
  invalid_request · too_large · malformed는 거짓 — 다시 해도 같다). 401 · 403은 재시도하지 않는다(설계 D20). 프로토콜 오류(깨진
  상태 줄 · 헤더 상한 초과 · 깨진 chunk 틀 — http.client가 IncompleteRead로 바꿔 올린다)와 TLS 검증 실패도 connection(일시)이다 —
  다시 해도 같을 수 있지만 재시도 횟수가 유한하다(호출자의 표).

build_url(base, segments, *, query=None, trailing_slash=True) -> str
- 경로 = base(끝 `/` 뗌) + `/`로 이은 성분 + 끝 슬래시. segments는 성분의 시퀀스다 — str · bytes · bytearray 자체는 거부한다(튜플
  쉼표가 빠진 `("ab")`가 글자 단위 경로가 된다). 성분은 str이면 `[A-Za-z0-9_-]{1,64}`(UUID · ULID · 정수 문자열 · 경로 이름 —
  `.` · `/` · `%` · `?` · `#` · 공백 없음) · int면 0 이상 2**63 미만(bool 제외)만 받는다 — 아니면 호출 전에 UpstreamUnavailable
  ("invalid_request")(값을 싣지 않는다). 응답에서 온 값(세션 uuid · 사용자 pk · 그룹 pk)과 설정에서 온 값(OPENFGA_STORE_ID)도 같다
  — 의미 꼴(UUID · 정수)은 호출자가 먼저 본다(authentik.py). 질의는 urlencode로 만든다(문자열 이어 붙이기 금지 — http.client는 제어
  문자 · 공백이 든 경로를 InvalidURL로 거부하면서 원문을 문구에 싣는다 · `&` · `#` · `%`는 값을 깨뜨린다). urlencode의 ValueError
  (lone surrogate가 든 값의 UnicodeEncodeError — repr · args에 값 원문이 실린다 · 자릿수 상한을 넘는 int)도 invalid_request다.

import 시점에 객체 · 연결 · 설정 읽기가 없다(설정 AUTHENTIK_* · APP_VERSION은 호출 때 읽는다). 로그를 내지 않는다(이벤트 이름은
호출자 — 작업 · 명령 — 의 것이다 · 설계 D25).
"""

from __future__ import annotations

import http.client
import json
import re
import time
import urllib.error
import urllib.request
from collections.abc import Mapping, Sequence
from typing import Any
from urllib.parse import urlencode, urlsplit

from django.conf import settings

__all__ = [
    "CONNECTION",
    "DEADLINE",
    "DEFAULT_TIMEOUT_S",
    "INVALID_REQUEST",
    "MALFORMED",
    "MAX_RESPONSE_BYTES",
    "READ_CHUNK_BYTES",
    "SCHEME",
    "TIMEOUT",
    "TOO_LARGE",
    "TRANSIENT_KINDS",
    "Deadline",
    "UpstreamError",
    "UpstreamStatus",
    "UpstreamUnavailable",
    "build_url",
    "request_json",
]

DEFAULT_TIMEOUT_S = 5.0  # 소켓 동작마다(연결 · 쓰기 · 읽기) — 계약 §타임아웃 「호출마다 5 s」
MAX_RESPONSE_BYTES = 1024 * 1024  # 응답 본문 상한 1 MiB(넘으면 too_large)
READ_CHUNK_BYTES = 64 * 1024  # 한 번에 읽는 최대 바이트(읽는 사이마다 마감을 본다)
SCHEMES = frozenset({"http", "https"})
JSON_MEDIA_TYPE = "application/json"
USER_AGENT_PRODUCT = "identity-admin"
# UpstreamUnavailable 종류(값 · 문구에 실리는 것은 이 이름뿐이다)
CONNECTION, TIMEOUT, DEADLINE = "connection", "timeout", "deadline"
SCHEME, INVALID_REQUEST, TOO_LARGE, MALFORMED = "scheme", "invalid_request", "too_large", "malformed"
TRANSIENT_KINDS = frozenset({CONNECTION, TIMEOUT, DEADLINE})
_SEGMENT_RE = re.compile(r"[A-Za-z0-9_-]{1,64}")  # 경로 성분(fullmatch — 설계 D20 OPENFGA_STORE_ID 꼴과 같다)
_INT_SEGMENT_LIMIT = 2**63  # int 경로 성분은 이 값 미만만 받는다(자릿수 상한 · 응답의 pk가 이를 넘을 일은 없다)
_TOKEN_RE = re.compile(r"[!-~]+")  # Bearer 토큰(fullmatch — 공백 없는 출력 가능 ASCII · conf의 비밀 글자 규칙과 같다)


class UpstreamError(Exception):
    """외부 API 호출 실패의 공통 형 — `.transient`(다시 하면 될 수 있는가)만 공통이다. 문구 · args에 값이 없다."""

    transient: bool = False


class UpstreamStatus(UpstreamError):
    """2xx가 아닌 응답(3xx 포함) — args = (status,) · transient = 429 · 5xx."""

    def __init__(self, status: int) -> None:
        super().__init__(status)
        self.status = status
        self.transient = status == 429 or 500 <= status <= 599


class UpstreamUnavailable(UpstreamError):
    """응답 상태를 얻지 못했거나 쓸 수 없는 응답 — args = (kind,) · transient = kind ∈ TRANSIENT_KINDS."""

    def __init__(self, kind: str) -> None:
        super().__init__(kind)
        self.kind = kind
        self.transient = kind in TRANSIENT_KINDS


class Deadline:
    """단조 시계 마감 — 만든 때부터 seconds초 뒤(한 작업의 전체 마감 · 호출마다 넘긴다). 0 이하면 이미 지났다."""

    __slots__ = ("_end",)

    def __init__(self, seconds: float) -> None:
        self._end = time.monotonic() + seconds

    def remaining(self) -> float:
        """남은 초(지났으면 0 이하)."""
        return self._end - time.monotonic()


def _segment(value: object) -> str | None:
    """경로 성분 하나 → 경로에 넣을 문자열 · 꼴이 아니면 None(bool은 int여도 거부한다)."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return str(value) if 0 <= value < _INT_SEGMENT_LIMIT else None
    if isinstance(value, str) and _SEGMENT_RE.fullmatch(value) is not None:
        return value
    return None


def build_url(
    base: str,
    segments: Sequence[object],
    *,
    query: Mapping[str, str | int] | None = None,
    trailing_slash: bool = True,
) -> str:
    """base + 경로 성분 + (질의) — 모듈 독스트링 「build_url」. segments가 str · bytes · bytearray이거나 꼴이 아닌 성분이 하나라도
    있거나 질의가 인코딩되지 않으면 UpstreamUnavailable("invalid_request")(호출 0 · 값을 싣지 않는다 · 연쇄 없음)."""
    if isinstance(segments, (str, bytes, bytearray)):
        raise UpstreamUnavailable(INVALID_REQUEST) from None
    parts = [_segment(segment) for segment in segments]
    if any(part is None for part in parts):
        raise UpstreamUnavailable(INVALID_REQUEST) from None
    suffix: str | None = ""
    if query:
        try:
            suffix = "?" + urlencode(query)
        except ValueError:  # lone surrogate(UnicodeEncodeError — repr · args에 값 원문) · 자릿수 상한을 넘는 int
            suffix = None
    if suffix is None:
        raise UpstreamUnavailable(INVALID_REQUEST) from None
    path = "/".join(part for part in parts if part is not None)
    url = f"{base.rstrip('/')}/{path}" if path else base.rstrip("/")
    if trailing_slash:
        url += "/"
    return url + suffix


def _opener(https: bool) -> urllib.request.OpenerDirector:
    """HTTP 핸들러(https면 HTTPS 핸들러도 — 만들 때마다 기본 SSL 컨텍스트를 짓는다)와 오류 처리기만 단 opener(프록시 · 리디렉션 ·
    file · ftp · data 없음 · 기본 User-Agent 없음 · 두 핸들러 debuglevel 0 — 전역 debuglevel이 켜져도 헤더를 찍지 않는다)."""
    opener = urllib.request.OpenerDirector()
    opener.addheaders = []
    handlers: list[urllib.request.BaseHandler] = [urllib.request.HTTPHandler(debuglevel=0)]
    if https:
        handlers.append(urllib.request.HTTPSHandler(debuglevel=0))
    handlers += [urllib.request.HTTPDefaultErrorHandler(), urllib.request.HTTPErrorProcessor()]
    for handler in handlers:
        opener.add_handler(handler)
    return opener


def _request(method: str, url: str, token: str, body: Any) -> urllib.request.Request:
    """요청 조립(헤더 · 본문). 토큰 꼴이 아니거나 본문이 직렬화되지 않으면 ValueError — 값 · 형 이름을 싣지 않는다(접는 자리는
    request_json의 요청 준비 단계)."""
    if not isinstance(token, str) or _TOKEN_RE.fullmatch(token) is None:
        raise ValueError("token")
    version = getattr(settings, "APP_VERSION", None) or "unknown"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": JSON_MEDIA_TYPE,
        "User-Agent": f"{USER_AGENT_PRODUCT}/{version}",
    }
    data: bytes | None = None
    if body is not None:
        serialized: str | None = None
        try:
            serialized = json.dumps(body)
        except (TypeError, ValueError, RecursionError):  # JSON 기본형이 아님(TypeError — 문구에 형 이름) · 순환 참조 · 너무 깊음
            serialized = None
        if serialized is None:
            raise ValueError("body") from None
        data = serialized.encode()
        headers["Content-Type"] = JSON_MEDIA_TYPE
    return urllib.request.Request(url, data=data, headers=headers, method=method)


def _scheme_kind(url: str) -> str | None:
    """url의 스킴 판정 — http · https면 None · 파싱되지 않으면 invalid_request · 그 밖의 스킴이면 scheme."""
    try:
        scheme = urlsplit(url).scheme.lower()
    except ValueError:
        return INVALID_REQUEST
    return None if scheme in SCHEMES else SCHEME


def _timeout_kind(deadline: Deadline | None, timeout: float) -> str:
    """소켓 시간 초과의 종류 — 마감을 받았고 소켓 타임아웃이 남은 시간으로 줄어 있었거나(timeout < DEFAULT_TIMEOUT_S) 마감이 이미
    지났으면 deadline · 아니면 timeout(줄인 타임아웃의 시간 초과를 「remaining() <= 0」으로만 가르면 대기 단위의 경계에서 뒤집힌다)."""
    if deadline is not None and (timeout < DEFAULT_TIMEOUT_S or deadline.remaining() <= 0):
        return DEADLINE
    return TIMEOUT


def _read_body(response: http.client.HTTPResponse, deadline: Deadline | None) -> tuple[bytes, str | None]:
    """응답 본문을 64 KiB씩 읽는다 → (본문, None) · 마감 지남 · 1 MiB 초과 · Content-Length에 못 미친 끊김이면 (b"", 종류).
    소켓 예외는 호출자가 접는다."""
    chunks: list[bytes] = []
    total = 0
    while True:
        if deadline is not None and deadline.remaining() <= 0:
            return b"", DEADLINE
        piece = response.read1(READ_CHUNK_BYTES)
        if not piece:
            left = response.length  # 남은 Content-Length — chunked · 길이 없는 응답은 None · 다 읽었거나 204면 0
            if left is not None and left > 0:  # read1은 남은 길이가 있어도 EOF에서 b""를 준다(IncompleteRead 없음)
                return b"", CONNECTION
            return b"".join(chunks), None
        total += len(piece)
        if total > MAX_RESPONSE_BYTES:
            return b"", TOO_LARGE
        chunks.append(piece)


def request_json(
    method: str, url: str, *, token: str, body: Any = None, deadline: Deadline | None = None
) -> Any:
    """JSON 요청 한 번(모듈 독스트링 「request_json」) — 디코드한 JSON 값 · 빈 본문은 None. 실패는 UpstreamStatus ·
    UpstreamUnavailable(`raise … from None` · 문구에 값 없음)."""
    refused = _scheme_kind(url)
    if refused is not None:
        raise UpstreamUnavailable(refused) from None
    remaining = None if deadline is None else deadline.remaining()
    if remaining is not None and remaining <= 0:
        raise UpstreamUnavailable(DEADLINE) from None
    timeout = DEFAULT_TIMEOUT_S if remaining is None else min(DEFAULT_TIMEOUT_S, remaining)
    https = urlsplit(url).scheme.lower() == "https"

    failure: UpstreamError | None = None
    response: http.client.HTTPResponse | None = None
    try:
        response = _opener(https).open(_request(method, url, token, body), timeout=timeout)
    except urllib.error.HTTPError as exc:  # 2xx가 아닌 응답(HTTPErrorProcessor → HTTPDefaultErrorHandler) — 본문을 읽지 않는다
        failure = UpstreamStatus(exc.code)
        exc.close()
    except (ValueError, OverflowError, http.client.InvalidURL):  # 요청 준비 단계(헤더 값 · 본문 · URL · 메서드 · 연결 인자)
        failure = UpstreamUnavailable(INVALID_REQUEST)
    except TimeoutError:  # 상태 줄을 기다리다(getresponse)
        failure = UpstreamUnavailable(_timeout_kind(deadline, timeout))
    except urllib.error.URLError as exc:  # 연결 · 보내기 단계(urllib이 OSError를 감싼다) · 호스트 없는 URL(reason이 문자열)
        if isinstance(exc.reason, TimeoutError):
            failure = UpstreamUnavailable(_timeout_kind(deadline, timeout))
        elif isinstance(exc.reason, BaseException):
            failure = UpstreamUnavailable(CONNECTION)
        else:  # 'no host given' 등 — 다시 해도 같은 입력이다
            failure = UpstreamUnavailable(INVALID_REQUEST)
    except (OSError, http.client.HTTPException):  # 끊긴 연결 · 깨진 상태 줄 · 헤더 상한 초과 등(프로토콜 오류도 일시로 본다)
        failure = UpstreamUnavailable(CONNECTION)
    if failure is not None or response is None:
        # response None = 붙인 핸들러 가운데 그 URL을 맡는 것이 없다(urlsplit은 http로 읽고 urllib Request는 모르는 스킴으로 읽는
        # URL — 예: 스킴 글자 사이의 탭) — 다시 해도 같은 입력이다(호스트 없는 URL과 같은 부류 · 조각 ⑤-b V2)
        raise (failure or UpstreamUnavailable(INVALID_REQUEST)) from None

    raw = b""
    try:
        raw, cut = _read_body(response, deadline)
        if cut is not None:
            failure = UpstreamUnavailable(cut)
    except TimeoutError:
        failure = UpstreamUnavailable(_timeout_kind(deadline, timeout))
    except ValueError:  # 방어 — 깨진 chunk 틀은 http.client가 IncompleteRead(HTTPException)로 바꿔 올려 아래 가지(connection)다
        failure = UpstreamUnavailable(MALFORMED)
    except (OSError, http.client.HTTPException):  # 끊긴 연결 · 깨진 chunk 틀(IncompleteRead) · 트레일러 상한 초과
        failure = UpstreamUnavailable(CONNECTION)
    finally:
        response.close()
    if failure is not None:
        raise failure from None

    if not raw:
        return None
    try:
        return json.loads(raw)
    except (ValueError, RecursionError):  # JSON이 아님 · 깨진 UTF-8 · 깊게 중첩된 값
        failure = UpstreamUnavailable(MALFORMED)
    raise failure from None
