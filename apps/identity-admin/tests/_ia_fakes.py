"""T073 시험용 가짜 외부 서버 둘(조각 ① · 설계 D26 · 〔W27〕) — 자기검사 tests/test_ia_fakes.py.

① FakeAuthentikExt: T066 tests/_identity_fakes.FakeAuthentik의 하위 클래스(`_route` 재정의 — 응답은 기반 핸들러대로 JSON
  본문 한 번 · 인증(Bearer 403) · 미디어 타입(415) · 요청 기록은 기반 그대로). 모드를 켜지 않으면 그룹 · 사용자 표면은 T066
  가짜와 같다(자기검사 iaf-1). 더한 표면(설계 §2 ⑭ · D16 · D17 · D20 — 구현이 읽는 필드만 싣는다):
  - 세션 목록 `GET /api/v3/core/authenticated_sessions/` — 필터 `user__username`(세션 user pk의 username) · `page` ·
    `page_size` 쪽 매김(`pagination.next` 0 = 끝 · 끝 뒤 쪽 404 `Invalid page.` — DRF 쪽 매김) · 항목은 넣은 그대로(기본 꼴
    `{"uuid", "user"}` — uuid가 UUID 꼴이 아닌 항목도 넣으면 그대로 실린다).
  - 세션 단건 `DELETE …/authenticated_sessions/<uuid>/` — 있으면 204(지운 uuid를 deleted_sessions에 남긴다) · 없거나 경로
    성분이 UUID 꼴이 아니면 404(실제 Authentik의 UUID 조회처럼). 단건 GET은 없다(404).
  - 사용자 단건 `GET /api/v3/core/users/<pk>/` — 기반 그대로(대조가 pk → uuid를 얻는다 · 없는 pk 404).
  - 이벤트 목록 `GET /api/v3/events/events/` — `actions`(여러 값 · 정확 일치) · `action`(부분 일치 · 대소문자 무시) ·
    `ordering`(`created` · `-created` — 기본과 그 밖의 값은 `-created` · 정렬 키는 `created`를 파싱한 시각이고 읽히지 않는
    값은 한쪽에 모은다) · 쪽 매김 · 항목은 넣은 그대로(pk 꼴 · 「user 없는」 꼴 그대로 — make_event 독스트링).
  - 모드: ignore_filters(목록 넷의 필터 키를 무시하고 거르지 않은 전부 — 미끼) · ignore_ordering(이벤트를 넣은 순서로 —
    정렬 뒤섞기) · endless_next(세션 · 이벤트 목록의 next가 천장 ENDLESS_PAGE_CEILING까지 늘 page + 1 · 데이터 뒤 쪽은 빈
    results · 천장을 넘긴 쪽은 200 · 빈 results · next 0으로 끝내고 ceiling_hits로 센다 — 쪽 상한이 없는 구현은 매달리지 않고
    천장 뒤에 스스로 끝나며 시험의 요청 수(10 · 50) · `ceiling_hits == 0` 단언에서 빨강이 된다).
  - 경로별 주입: inject(route, *replies)(다음 요청들의 응답 차례 — 정수 = 그 상태 + `{"detail": …}` · (상태, 본문) 그대로 ·
    None = 그 차례는 주입 없이 정상 처리) · forbid(*routes)(늘 403 `{"detail": FORBIDDEN_DETAIL}`) · inflate(route,
    min_bytes)(200 JSON 객체 응답에 PADDING_KEY 하나를 더해 min_bytes보다 크게). 주입 · 403은 인증을 지난 요청에만 걸린다
    (인증 실패는 기반의 403이 먼저다).
  - 관찰: requests · mutations()(기반) · requests_to(route) · sessions · events · deleted_sessions · ceiling_hits · errors
    (요청 처리 오류 이름 — 이 인스턴스 서버의 handle_error를 덮어 stderr에 쓰지 않는다).
② RawHttpServer: BaseHTTPRequestHandler를 직접 쓰는 원시 HTTP 서버 — 응답을 RawReply로 스크립트한다(상태 · 헤더 · 본문 조각
  바이트 · 조각 사이 지연 · 상태 줄 앞 지연 · Content-Length 유무). 차례대로 한 번씩 쓰고 다 쓰면 기본 응답(200 `{}`).
  받은 요청은 원문 요청 줄 · 메서드 · 경로 · 질의 · 헤더(순서 그대로 · 자격 헤더 값은 Secret) · 본문 바이트로 남긴다 · 서버가
  거절한 요청(do_*가 없는 메서드 · 깨진 요청 줄)은 rejected에 (상태, 요청 줄)로 남기고 count는 둘을 합한다.
  ia-22(D20)의 302 + Location(둘째 서버의 요청 수) · JSON이 아닌 200 · 느린 조각 · 1 MiB 초과 본문을 맡는다(T066 기반 핸들러는
  JSON 본문 한 번과 고정 헤더만 낸다 — 검토 C-6). 응답을 쓰다 클라이언트가 끊으면(마감에서 끊는 구현) 오류 이름만 errors에
  남기고 stderr에 쓰지 않는다(errors는 보조다 — 클래스 독스트링).
③ TcpRelay(조각 ⑤-a 수정 라운드 H2): 127.0.0.1 임시 포트의 TCP 중계 — 받은 연결마다 상류(host, port)로 붙어 양쪽 바이트를
  그대로 넘긴다. freeze()는 그때까지 맺어진 연결을 더 중계하지 않되 소켓을 닫지 않는다(FIN · RST가 가지 않는다 — 클라이언트에는
  살아 보이는 죽은 연결: FIN이 닿지 않은 끊김의 꼴) · 그 뒤에 새로 맺는 연결은 정상 중계한다. 쓰는 법: `with TcpRelay(host,
  port) as relay:` → 클라이언트를 `127.0.0.1:relay.port`로 향하게 하고 → `relay.freeze()`. 관찰: accepted(받은 연결 수) ·
  frozen(얼린 연결 수) · thread_alive. close()(컨텍스트를 나올 때 · 두 번 불러도 된다)는 얼린 연결까지 모든 소켓을 닫고 중계
  스레드를 join한다(유한).

①②는 127.0.0.1 임시 포트의 ThreadingHTTPServer(데몬 요청 스레드)를 데몬 스레드 하나로 돌리고 close()가 shutdown() ·
server_close() · 스레드 join으로 닫는다(T066 _JsonServer의 꼴) · ③은 selectors 루프 하나를 데몬 스레드로 돌린다. 표준 라이브러리
+ T066 tests/_identity_fakes · tests._secret만 쓴다 — Django를 import하지 않는다(자기검사는 DB · Dragonfly · Django 설정 없이
돈다).
"""

from __future__ import annotations

import copy
import json
import math
import re
import selectors
import socket
import sys
import threading
import time
import uuid
from collections import deque
from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from datetime import UTC, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlsplit

from tests._identity_fakes import AUTHENTIK_API, FakeAuthentik, Reply
from tests._secret import Secret

SESSIONS_PATH = f"{AUTHENTIK_API}/authenticated_sessions/"
EVENTS_PATH = "/api/v3/events/events/"
# 경로 이름 → 경로 꼴(끝 슬래시 포함 정확 일치). 주입 · 403 · 부풀리기 · requests_to가 이 이름을 쓴다.
_ROUTE_PATTERNS: dict[str, re.Pattern[str]] = {
    "groups": re.compile(re.escape(f"{AUTHENTIK_API}/groups/")),
    "add_user": re.compile(rf"{re.escape(AUTHENTIK_API)}/groups/[^/]+/add_user/"),
    "users": re.compile(re.escape(f"{AUTHENTIK_API}/users/")),
    "user_detail": re.compile(rf"{re.escape(AUTHENTIK_API)}/users/[0-9]+/"),
    "sessions": re.compile(re.escape(SESSIONS_PATH)),
    "session_detail": re.compile(rf"{re.escape(SESSIONS_PATH)}(?P<uuid>[^/]+)/"),
    "events": re.compile(re.escape(EVENTS_PATH)),
}
ROUTES = frozenset(_ROUTE_PATTERNS)
# Authentik REST_FRAMEWORK PAGE_SIZE(설계에 없는 값 — 가짜의 기본값 · 구현은 page_size=100을 명시한다 — D16 · D17).
DEFAULT_PAGE_SIZE = 100
INVALID_PAGE_DETAIL = "Invalid page."  # DRF PageNumberPagination이 범위 밖 · 꼴이 아닌 page에 내는 404 문구
FORBIDDEN_DETAIL = "You do not have permission to perform this action."  # DRF PermissionDenied 기본 문구
PADDING_KEY = "_fake_padding"  # inflate가 더하는 키(가짜 전용 — 구현은 읽지 않는다)
# endless_next의 천장 — 이 쪽을 넘긴 요청은 next 0으로 끝난다(세션 쪽 상한 10 · 이벤트 쪽 상한 50보다 충분히 크다 —
# 쪽 상한이 없는 구현이 매달리지 않고 요청 수 단언에서 빨강이 되게).
ENDLESS_PAGE_CEILING = 200
_FILTER_KEYS = {"groups": ("name",), "users": ("uuid",)}  # ignore_filters가 기반 목록에서 지우는 질의 키


def route_of(path: str) -> str | None:
    """요청 경로(질의 제외) → 경로 이름(ROUTES 가운데 하나) · 모르는 경로는 None."""
    for name, pattern in _ROUTE_PATTERNS.items():
        if pattern.fullmatch(path):
            return name
    return None


def _check_route(route: str) -> None:
    if route not in ROUTES:
        raise ValueError(f"모르는 경로 이름: {route!r}(가능: {sorted(ROUTES)})")


def make_session(user_pk: Any, session_uuid: Any = None) -> dict[str, Any]:
    """세션 목록 항목 `{"uuid", "user"}`(uuid 기본 = 새 uuid4 문자열 · user = Authentik 사용자 pk)."""
    return {"uuid": str(uuid.uuid4()) if session_uuid is None else session_uuid, "user": user_pk}


def _drf_datetime(value: datetime) -> str:
    """DRF DateTimeField 꼴 — aware 값은 UTC로 바꾼 뒤 isoformat()의 끝 `+00:00`을 `Z`로(소수 초는 그대로) · naive 값은
    isoformat() 그대로(오프셋을 지어내지 않는다)."""
    if value.utcoffset() is None:
        return value.isoformat()
    return value.astimezone(UTC).isoformat().removesuffix("+00:00") + "Z"


def make_event(user_pk: Any, created: datetime | str, *, action: str = "logout", pk: Any = None) -> dict[str, Any]:
    """이벤트 목록 항목 `{"pk", "action", "created", "user"}` — pk 기본 = 새 uuid4 문자열 · user = `{"pk": user_pk}` ·
    user_pk가 None이면 `"user": {}`.

    created: datetime이면 DRF 꼴(aware → UTC `…Z` — 예 `2026-11-12T12:00:00Z` · `…12:00:00.500000Z` · naive → isoformat()
    그대로) · 문자열이면 그대로.
    두 기본 꼴(DRF `DateTimeField`의 `Z` · 사용자 없는 이벤트의 `"user": {}` — Authentik `Event.user`는 `JSONField(default=dict)`)
    의 근거는 소스 기억이고 실측은 T081(VD-T081-1 · 2)이다. 키가 없는 꼴 · `None` 꼴은 시험이 돌려받은 dict에서 직접 만든다
    (`del event["user"]` · `event["user"] = None`) — ia-13의 「user 없는 이벤트」 미끼는 세 꼴(`{}` · 키 없음 · `None`)을
    모두 넣는다.
    """
    return {
        "pk": str(uuid.uuid4()) if pk is None else pk,
        "action": action,
        "created": _drf_datetime(created) if isinstance(created, datetime) else created,
        "user": {} if user_pk is None else {"pk": user_pk},
    }


def _last(query: Mapping[str, list[str]], key: str) -> str | None:
    """질의 값(같은 키가 여럿이면 마지막 — Django QueryDict.get처럼)."""
    values = query.get(key)
    return values[-1] if values else None


def _positive_int(value: str | None) -> int | None:
    return int(value) if value is not None and value.isdigit() and int(value) > 0 else None


def _as_uuid(value: Any) -> uuid.UUID | None:
    try:
        return uuid.UUID(str(value))
    except ValueError:
        return None


def _created_key(event: Mapping[str, Any]) -> tuple[int, Any]:
    """이벤트 정렬 키 — `created`가 datetime.fromisoformat으로 읽히는 문자열이면 `(1, 그 시각)`(aware가 아니면 UTC로 본다 ·
    3.11+는 `Z`도 읽는다), 읽히지 않는 값(꼴이 아닌 문자열 · 키 없음 · 문자열이 아닌 값)은 `(0, str(값))` — 두 무리가 섞여도
    비교 오류가 나지 않고 읽히지 않는 값은 한쪽에 모인다."""
    value = event.get("created")
    if isinstance(value, str):
        try:
            moment = datetime.fromisoformat(value)
        except ValueError:
            pass
        else:
            return 1, moment if moment.utcoffset() is not None else moment.replace(tzinfo=UTC)
    return 0, str(value)


class FakeAuthentikExt(FakeAuthentik):
    """T066 FakeAuthentik + 세션 · 이벤트 표면 · 모드 · 경로별 주입(모듈 독스트링 ①)."""

    def __init__(self) -> None:
        # 기반 __init__이 서버 스레드를 띄우므로 이 클래스의 상태를 먼저 둔다.
        self._sessions: list[dict[str, Any]] = []
        self._events: list[dict[str, Any]] = []
        self._deleted: list[str] = []
        self._ignore_filters = False
        self._ignore_ordering = False
        self._endless_next = False
        self._injected: dict[str, deque[Reply | None]] = {}
        self._forbidden: set[str] = set()
        self._inflated: dict[str, int] = {}
        self._ceiling_hits = 0
        self._errors: list[str] = []
        super().__init__()
        # 요청 처리 오류(응답을 쓰다 클라이언트가 끊은 것 등)를 stderr 트레이스백 대신 이름으로 남긴다 — 이 인스턴스의 서버만
        # 덮는다(T066 기반 · tests/_identity_fakes.py는 그대로 · 원시 서버 _QuietServer.handle_error와 같은 뜻).
        self._server.handle_error = self._note_error  # type: ignore[method-assign]

    def reset(
        self,
        *,
        groups: Iterable[Mapping[str, Any]] = (),
        users: Iterable[Mapping[str, Any]] = (),
        sessions: Iterable[Mapping[str, Any]] = (),
        events: Iterable[Mapping[str, Any]] = (),
    ) -> None:
        """기반 reset(그룹 · 사용자 · 요청 기록) + 세션 · 이벤트를 바꾸고 지운 기록 · 모드 · 주입 · 403 · 부풀리기 ·
        ceiling_hits · errors를 비운다.

        sessions · events: 항목 사전(사본으로 넣는다 — 응답에 그대로 실린다 · make_session · make_event).
        """
        super().reset(groups=groups, users=users)
        with self._lock:
            self._sessions = [copy.deepcopy(dict(session)) for session in sessions]
            self._events = [copy.deepcopy(dict(event)) for event in events]
            self._deleted = []
            self._ignore_filters = self._ignore_ordering = self._endless_next = False
            self._injected = {}
            self._forbidden = set()
            self._inflated = {}
            self._ceiling_hits = 0
            self._errors = []

    # --- 모드 · 주입 -----------------------------------------------------------------------------------------------------

    @property
    def ignore_filters(self) -> bool:
        with self._lock:
            return self._ignore_filters

    @ignore_filters.setter
    def ignore_filters(self, value: bool) -> None:
        with self._lock:
            self._ignore_filters = bool(value)

    @property
    def ignore_ordering(self) -> bool:
        with self._lock:
            return self._ignore_ordering

    @ignore_ordering.setter
    def ignore_ordering(self, value: bool) -> None:
        with self._lock:
            self._ignore_ordering = bool(value)

    @property
    def endless_next(self) -> bool:
        with self._lock:
            return self._endless_next

    @endless_next.setter
    def endless_next(self, value: bool) -> None:
        with self._lock:
            self._endless_next = bool(value)

    def inject(self, route: str, *replies: int | Reply | None) -> None:
        """route의 다음 요청들이 차례로 받을 응답을 뒤에 붙인다 — 정수 = 그 상태 + `{"detail": "fake injected <상태>"}`(204는
        본문 없음) · (상태, 본문) = 그대로 · None = 그 차례의 요청은 주입 없이 정상 처리(403 forbid · 부풀리기는 평소대로
        걸린다 — 예 `inject("events", None, 503)` = 첫 요청 정상 · 둘째 요청 503). 다 쓰면 정상 응답이다."""
        _check_route(route)
        queued: list[Reply | None] = []
        for reply in replies:
            if reply is None:
                queued.append(None)
            elif isinstance(reply, int):
                status = HTTPStatus(reply)
                detail = None if status == HTTPStatus.NO_CONTENT else {"detail": f"fake injected {reply}"}
                queued.append((status, detail))
            else:
                queued.append((HTTPStatus(reply[0]), reply[1]))
        with self._lock:
            self._injected.setdefault(route, deque()).extend(queued)

    def forbid(self, *routes: str) -> None:
        """routes는 (주입이 비어 있을 때) 늘 403 `{"detail": FORBIDDEN_DETAIL}`이다 — 권한 없는 서비스 계정."""
        for route in routes:
            _check_route(route)
        with self._lock:
            self._forbidden.update(routes)

    def inflate(self, route: str, min_bytes: int) -> None:
        """route의 200 JSON 객체 응답에 PADDING_KEY(`"x" * min_bytes`)를 더해 본문을 min_bytes보다 크게 한다."""
        _check_route(route)
        with self._lock:
            self._inflated[route] = int(min_bytes)

    # --- 관찰 -----------------------------------------------------------------------------------------------------------

    @property
    def sessions(self) -> list[dict[str, Any]]:
        """남은 세션 항목(사본 · 넣은 순서)."""
        with self._lock:
            return copy.deepcopy(self._sessions)

    @property
    def events(self) -> list[dict[str, Any]]:
        """이벤트 항목(사본 · 넣은 순서)."""
        with self._lock:
            return copy.deepcopy(self._events)

    @property
    def deleted_sessions(self) -> list[str]:
        """204로 지운 세션의 uuid(경로 성분 그대로 · 차례대로)."""
        with self._lock:
            return list(self._deleted)

    @property
    def ceiling_hits(self) -> int:
        """endless_next에서 천장(ENDLESS_PAGE_CEILING)을 넘긴 쪽을 요청한 수(reset이 0으로)."""
        with self._lock:
            return self._ceiling_hits

    @property
    def errors(self) -> list[str]:
        """요청 처리 중 난 오류의 예외 클래스 이름(응답을 쓰다 클라이언트가 끊은 것 등 · 차례대로 · 사본 · reset이 비운다) —
        stderr에는 쓰지 않는다. 끊김이 오류가 되는지는 타이밍이라 끊김 판정의 보조로만 쓴다."""
        with self._lock:
            return list(self._errors)

    def requests_to(self, route: str) -> list[Any]:
        """route 경로가 받은 요청 기록만(기반 FakeRequest · 받은 차례)."""
        _check_route(route)
        return [request for request in self.requests if route_of(request.path) == route]

    def _note_error(self, request: Any, client_address: Any) -> None:
        """이 인스턴스 서버의 handle_error(socketserver가 except 블록 안에서 부른다) — 이름만 남긴다."""
        kind = sys.exc_info()[0]
        with self._lock:
            self._errors.append(kind.__name__ if kind is not None else "unknown")

    # --- 처리 -----------------------------------------------------------------------------------------------------------

    def _route(self, method: str, path: str, query: dict[str, list[str]], body: Any, parsed: bool) -> Reply:
        """주입 → 403 → 새 표면 · 기반 표면 → 부풀리기(기반 _handle이 잠금 아래에서 부른다 · 주입의 None 자리는 403부터 평소대로)."""
        route = route_of(path)
        if route is not None:
            queued = self._injected.get(route)
            injected = queued.popleft() if queued else None
            if injected is not None:
                return injected
            if route in self._forbidden:
                return HTTPStatus.FORBIDDEN, {"detail": FORBIDDEN_DETAIL}
        status, payload = self._dispatch(route, method, path, query, body, parsed)
        padding = self._inflated.get(route) if route is not None else None
        if padding is not None and status == HTTPStatus.OK and isinstance(payload, dict):
            payload = {**payload, PADDING_KEY: "x" * padding}
        return status, payload

    def _dispatch(
        self, route: str | None, method: str, path: str, query: dict[str, list[str]], body: Any, parsed: bool
    ) -> Reply:
        if route == "sessions" and method == "GET":
            return self._list_sessions(query)
        if route == "session_detail" and method == "DELETE":
            return self._delete_session(path)
        if route == "events" and method == "GET":
            return self._list_events(query)
        if self._ignore_filters and method == "GET" and route in _FILTER_KEYS:
            query = {key: values for key, values in query.items() if key not in _FILTER_KEYS[route]}
        return super()._route(method, path, query, body, parsed)

    def _paginate(self, items: list[dict[str, Any]], query: Mapping[str, list[str]]) -> Reply:
        """Authentik 목록 응답(T066 _page와 같은 키) — page는 1부터 · 끝 뒤 · 꼴이 아닌 page는 404.

        endless_next: page ≤ ENDLESS_PAGE_CEILING이면 next = page + 1 · total_pages = max(데이터 쪽 수, page + 1)(데이터 뒤 쪽은
        빈 results · 404가 아니다) · page > ENDLESS_PAGE_CEILING이면 200 · 빈 results · next 0 · total_pages = page로 끝내고
        ceiling_hits를 하나 센다(쪽 상한이 없는 구현이 매달리지 않고 스스로 끝난다).
        """
        raw_page = _last(query, "page")
        page = 1 if raw_page is None else _positive_int(raw_page)
        size = _positive_int(_last(query, "page_size")) or DEFAULT_PAGE_SIZE
        count = len(items)
        total = max(1, math.ceil(count / size))
        if page is None or (page > total and not self._endless_next):
            return HTTPStatus.NOT_FOUND, {"detail": INVALID_PAGE_DETAIL}
        beyond = self._endless_next and page > ENDLESS_PAGE_CEILING
        if beyond:
            self._ceiling_hits += 1
        results = [] if beyond else [copy.deepcopy(item) for item in items[(page - 1) * size : page * size]]
        more = not beyond and (self._endless_next or page < total)
        if beyond:
            total_pages = page
        else:
            total_pages = max(total, page + 1) if self._endless_next else total
        pagination = {
            "next": page + 1 if more else 0,
            "previous": page - 1 if page > 1 else 0,
            "count": count,
            "current": page,
            "total_pages": total_pages,
            "start_index": (page - 1) * size + 1 if results else 0,
            "end_index": (page - 1) * size + len(results) if results else 0,
        }
        return HTTPStatus.OK, {"pagination": pagination, "results": results}

    def _list_sessions(self, query: dict[str, list[str]]) -> Reply:
        sessions = self._sessions
        username = None if self._ignore_filters else _last(query, "user__username")
        if username is not None:
            sessions = [session for session in sessions if self._username_of(session.get("user")) == username]
        return self._paginate(sessions, query)

    def _username_of(self, user_pk: Any) -> str | None:
        user = self._users.get(user_pk) if isinstance(user_pk, int) and not isinstance(user_pk, bool) else None
        return None if user is None else str(user["username"])

    def _delete_session(self, path: str) -> Reply:
        match = _ROUTE_PATTERNS["session_detail"].fullmatch(path)
        segment = match["uuid"] if match else ""
        wanted = _as_uuid(segment)
        if wanted is not None:
            for index, session in enumerate(self._sessions):
                if _as_uuid(session.get("uuid")) == wanted:
                    del self._sessions[index]
                    self._deleted.append(segment)
                    return HTTPStatus.NO_CONTENT, None
        return HTTPStatus.NOT_FOUND, {"detail": "Not found."}

    def _list_events(self, query: dict[str, list[str]]) -> Reply:
        events = list(self._events)
        if not self._ignore_filters:
            actions = query.get("actions")
            if actions is not None:
                events = [event for event in events if event.get("action") in actions]
            action = _last(query, "action")
            if action is not None:
                events = [event for event in events if action.lower() in str(event.get("action", "")).lower()]
        if not self._ignore_ordering:
            terms = [term.strip() for term in (_last(query, "ordering") or "").split(",")]
            ascending = next((term == "created" for term in terms if term in ("created", "-created")), False)
            events.sort(key=_created_key, reverse=not ascending)
        return self._paginate(events, query)


# --- 원시 HTTP 서버 -------------------------------------------------------------------------------------------------------

JSON_HEADERS: tuple[tuple[str, str], ...] = (("Content-Type", "application/json"),)
# 받은 요청 기록에서 값을 Secret으로 감싸는 헤더(소문자) — repr이 실패 출력에 값을 싣지 않게.
_SENSITIVE_HEADERS = frozenset({"authorization", "proxy-authorization", "cookie"})


@dataclass(frozen=True)
class RawReply:
    """원시 서버의 응답 하나 — 상태 · 헤더(순서대로) · 본문 조각(바이트 · 차례대로 보낸다) · 조각 사이 지연(초) · 상태 줄 앞
    지연(초) · Content-Length(참이면 조각 전체 길이로 단다 · 거짓이면 연결 종료가 본문 끝)."""

    status: int = 200
    headers: tuple[tuple[str, str], ...] = JSON_HEADERS
    chunks: tuple[bytes, ...] = (b"{}",)
    delay_s: float = 0.0
    head_delay_s: float = 0.0
    content_length: bool = True

    @classmethod
    def json(cls, value: Any, *, status: int = 200) -> RawReply:
        """JSON 본문 한 번(`json.dumps(value)`)."""
        return cls(status=status, chunks=(json.dumps(value).encode(),))

    @classmethod
    def redirect(cls, location: str, *, status: int = 302) -> RawReply:
        """리디렉션 — `Location: <location>` · 빈 본문."""
        return cls(status=status, headers=(("Location", location),), chunks=())

    @classmethod
    def text(
        cls, body: bytes, *, content_type: str = "text/html; charset=utf-8", status: int = 200
    ) -> RawReply:
        """JSON이 아닌 본문(기본 text/html)."""
        return cls(status=status, headers=(("Content-Type", content_type),), chunks=(body,))

    @classmethod
    def slow(
        cls,
        body: bytes,
        *,
        pieces: int,
        delay_s: float,
        head_delay_s: float = 0.0,
        headers: tuple[tuple[str, str], ...] = JSON_HEADERS,
    ) -> RawReply:
        """body를 pieces개 조각으로 나눠 조각 사이에 delay_s씩 쉬며 보낸다(Content-Length = 전체 길이)."""
        size = max(1, math.ceil(len(body) / pieces))
        chunks = tuple(body[start : start + size] for start in range(0, len(body), size)) or (b"",)
        return cls(headers=headers, chunks=chunks, delay_s=delay_s, head_delay_s=head_delay_s)

    @classmethod
    def large(cls, size: int) -> RawReply:
        """정확히 size바이트인 JSON 본문(문자열 하나 `"xxx…"` · size ≥ 2)."""
        return cls(chunks=(b'"' + b"x" * (size - 2) + b'"',))


@dataclass(frozen=True)
class RawRequest:
    """원시 서버가 받은 요청 하나 — 원문 요청 줄(CRLF 제외 · latin-1) · 메서드 · 경로 · 질의(parse_qs) · 헤더(받은 순서 ·
    자격 헤더 값은 Secret) · 본문 바이트. 헤더 · 본문은 repr에서 뺀다."""

    request_line: str
    method: str
    path: str
    query: dict[str, list[str]]
    headers: tuple[tuple[str, str], ...] = field(repr=False)
    body: bytes = field(repr=False)

    def header(self, name: str) -> str | None:
        """name 헤더의 첫 값(대소문자 무시) · 없으면 None."""
        wanted = name.lower()
        return next((value for key, value in self.headers if key.lower() == wanted), None)


class _QuietServer(ThreadingHTTPServer):
    """요청 처리 중 예외를 stderr 트레이스백 대신 이름으로 남기는 ThreadingHTTPServer."""

    daemon_threads = True
    block_on_close = False  # close()가 느린 응답을 쓰는 요청 스레드를 기다리지 않는다(데몬 스레드)

    def __init__(self, owner: RawHttpServer) -> None:
        self.owner = owner
        super().__init__(("127.0.0.1", 0), _raw_handler(owner))

    def handle_error(self, request: Any, client_address: Any) -> None:
        self.owner._note_error(sys.exc_info()[0])


def _raw_handler(owner: RawHttpServer) -> type[BaseHTTPRequestHandler]:
    class RawHandler(BaseHTTPRequestHandler):
        def _serve(self) -> None:
            try:
                try:
                    length = int(self.headers.get("Content-Length") or 0)
                except ValueError:
                    length = 0
                body = self.rfile.read(length) if length > 0 else b""
                parts = urlsplit(self.path)
                headers = tuple(
                    (name, Secret(value) if name.lower() in _SENSITIVE_HEADERS else value)
                    for name, value in self.headers.items()
                )
                reply = owner._record(
                    RawRequest(
                        self.requestline,
                        self.command,
                        parts.path,
                        parse_qs(parts.query, keep_blank_values=True),
                        headers,
                        body,
                    )
                )
                self._reply(reply)
            finally:
                owner._note_finished()

        def _reply(self, reply: RawReply) -> None:
            try:
                if reply.head_delay_s:
                    time.sleep(reply.head_delay_s)
                self.send_response(reply.status)
                for name, value in reply.headers:
                    self.send_header(name, value)
                if reply.content_length:
                    self.send_header("Content-Length", str(sum(len(chunk) for chunk in reply.chunks)))
                self.end_headers()
                for index, chunk in enumerate(reply.chunks):
                    if index and reply.delay_s:
                        time.sleep(reply.delay_s)
                    self.wfile.write(chunk)
                    self.wfile.flush()
            except OSError as exc:  # 클라이언트가 끊었다(마감에서 끊는 구현) — 이름만 남긴다
                owner._note_error(type(exc))
                self.close_connection = True

        # 메서드 이름은 BaseHTTPRequestHandler 규약(do_<METHOD>)이다.
        do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _serve

        def send_error(self, code: int, message: str | None = None, explain: str | None = None) -> None:
            """서버가 _serve에 닿기 전에 거절한 요청(do_*가 없는 메서드 501 · 깨진 요청 줄 400 · 너무 긴 요청 줄 414 등)을
            (상태, 요청 줄 앞 200자)로 남긴 뒤 부모 구현으로 응답한다 — 헤더 값은 싣지 않는다."""
            owner._note_rejected(int(code), getattr(self, "requestline", "")[:200])
            super().send_error(code, message, explain)

        def log_message(self, format: str, *args: Any) -> None:  # 인자 이름 format은 부모 시그니처 그대로다
            """요청 로그를 끈다(기본 구현은 요청마다 stderr에 한 줄을 쓴다)."""

    return RawHandler


class RawHttpServer:
    """127.0.0.1 임시 포트의 원시 HTTP 서버(모듈 독스트링 ②) — script()로 응답 차례를 붙이고 다 쓰면 default를 낸다.

    받은 요청: requests = _serve가 처리한 요청(GET · POST · PATCH · PUT · DELETE) · rejected = 서버가 _serve에 닿기 전에 거절한
    요청(do_*가 없는 HEAD · OPTIONS · CONNECT · TRACE 501 · 깨진 요청 줄 400 등 — (상태, 요청 줄)) · count = 둘을 합한 받은
    요청 전부(「받은 요청 0」 단언은 count로 한다 — CONNECT · HEAD · 깨진 줄에도 눈이 멀지 않게).
    errors는 응답을 쓰다 클라이언트가 끊었을 때 찬다 — 끊긴 뒤 둘째 쓰기에서야 오류가 나므로 남은 조각 수에 따라 0일 수 있다.
    끊김 판정은 클라이언트 쪽 예외와 경과 시간으로 하고 errors는 보조다.
    """

    def __init__(self, default: RawReply | None = None) -> None:
        self._lock = threading.Lock()
        self._queue: deque[RawReply] = deque()
        self._default = default or RawReply()
        self._requests: list[RawRequest] = []
        self._rejected: list[tuple[int, str]] = []
        self._errors: list[str] = []
        self._finished = 0
        self._server = _QuietServer(self)
        self._thread = threading.Thread(
            target=self._server.serve_forever, kwargs={"poll_interval": 0.05}, name="raw-http", daemon=True
        )
        self._thread.start()
        self.base_url = f"http://127.0.0.1:{self.port}"
        self._closed = False

    @property
    def port(self) -> int:
        port: int = self._server.server_address[1]
        return port

    @property
    def thread_alive(self) -> bool:
        return self._thread.is_alive()

    def script(self, *replies: RawReply) -> None:
        """응답 차례 뒤에 replies를 붙인다(요청마다 하나씩 앞에서 꺼낸다)."""
        with self._lock:
            self._queue.extend(replies)

    @property
    def requests(self) -> list[RawRequest]:
        """_serve가 처리한 요청 기록(사본 · 받은 차례 — 서버가 거절한 요청은 rejected에)."""
        with self._lock:
            return list(self._requests)

    @property
    def rejected(self) -> list[tuple[int, str]]:
        """서버가 _serve에 닿기 전에 거절한 요청 — (상태, 요청 줄 앞 200자)(사본 · 받은 차례 · 헤더 값은 싣지 않는다)."""
        with self._lock:
            return list(self._rejected)

    @property
    def count(self) -> int:
        """받은 요청 전부의 수(requests의 수 + rejected의 수)."""
        with self._lock:
            return len(self._requests) + len(self._rejected)

    @property
    def errors(self) -> list[str]:
        """요청 처리 중 난 오류의 예외 클래스 이름(응답을 쓰다 클라이언트가 끊은 것 등 · 차례대로 · 보조 — 클래스 독스트링)."""
        with self._lock:
            return list(self._errors)

    @property
    def finished(self) -> int:
        """_serve가 처리를 마친 요청 수(응답을 다 썼거나 쓰다 끊긴 것 · rejected는 세지 않는다)."""
        with self._lock:
            return self._finished

    def close(self) -> None:
        """서버를 닫는다(shutdown → server_close → 스레드 join · 두 번 불러도 된다 · 느린 응답 스레드는 기다리지 않는다)."""
        if self._closed:
            return
        self._closed = True
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)

    def _record(self, request: RawRequest) -> RawReply:
        with self._lock:
            self._requests.append(request)
            return self._queue.popleft() if self._queue else self._default

    def _note_rejected(self, status: int, request_line: str) -> None:
        with self._lock:
            self._rejected.append((status, request_line))

    def _note_error(self, kind: type[BaseException] | None) -> None:
        with self._lock:
            self._errors.append(kind.__name__ if kind is not None else "unknown")

    def _note_finished(self) -> None:
        with self._lock:
            self._finished += 1


# --- TCP 중계 -----------------------------------------------------------------------------------------------------------

RELAY_TIMEOUT_S = 5.0  # 상류 연결 · 넘기기(sendall) · freeze 확인 · close join의 상한(시험은 늘 유한하게 끝난다)
_RELAY_POLL_S = 0.05  # selectors 대기 — freeze 요청 · 멈춤 신호를 이 간격 안에 받는다


class TcpRelay:
    """127.0.0.1 임시 포트의 TCP 중계(모듈 독스트링 ③) — 받은 연결마다 상류로 붙어 양쪽 바이트를 그대로 넘긴다.

    소켓은 모두 중계 스레드 하나(selectors 루프)가 다룬다 — freeze()는 요청을 넣고 그 스레드가 처리했다는 확인을 기다린다(셀렉터를
    다른 스레드에서 고치지 않는다). 한쪽이 닫히거나 오류가 나면 그 쌍의 양쪽을 닫는다(반쯤 닫기는 흉내 내지 않는다).
    """

    def __init__(self, upstream_host: str, upstream_port: int) -> None:
        self._upstream = (upstream_host, int(upstream_port))
        self._lock = threading.Lock()
        self._accepted = 0
        self._frozen_count = 0
        self._freeze_requests: list[threading.Event] = []
        self._closed = False
        self._released = False
        self._stop = threading.Event()
        self._listener = socket.create_server(("127.0.0.1", 0))
        self._selector = selectors.DefaultSelector()
        self._selector.register(self._listener, selectors.EVENT_READ)
        self._pairs: list[tuple[socket.socket, socket.socket]] = []  # (클라이언트 쪽, 상류 쪽) — 중계 중
        self._peers: dict[socket.socket, socket.socket] = {}
        self._frozen: list[socket.socket] = []  # 얼린 소켓(닫지 않고 쥐고만 있다 — close()가 닫는다)
        self._thread = threading.Thread(target=self._run, name="tcp-relay", daemon=True)
        self._thread.start()

    def __enter__(self) -> TcpRelay:
        return self

    def __exit__(self, *exc_info: object) -> None:
        self.close()

    @property
    def port(self) -> int:
        port: int = self._listener.getsockname()[1]
        return port

    @property
    def accepted(self) -> int:
        """받아서 상류로 붙인 연결 수(누적)."""
        with self._lock:
            return self._accepted

    @property
    def frozen(self) -> int:
        """freeze()로 얼린 연결 수(누적 · 클라이언트 연결 단위)."""
        with self._lock:
            return self._frozen_count

    @property
    def thread_alive(self) -> bool:
        return self._thread.is_alive()

    def freeze(self) -> None:
        """지금 맺어진 연결을 모두 얼린다 — 더 읽지도 넘기지도 않고 소켓은 닫지 않는다. 새 연결은 그 뒤에도 중계된다. 중계
        스레드가 RELAY_TIMEOUT_S 안에 처리하지 않으면 RuntimeError(닫힌 중계도 RuntimeError)."""
        done = threading.Event()
        with self._lock:
            if self._closed:
                raise RuntimeError("닫힌 TcpRelay는 freeze할 수 없다")
            self._freeze_requests.append(done)
        if not done.wait(RELAY_TIMEOUT_S):
            raise RuntimeError(f"중계 스레드가 {RELAY_TIMEOUT_S:g} s 안에 freeze를 처리하지 않았다")

    def close(self) -> None:
        """중계를 멈추고 얼린 연결까지 모든 소켓을 닫는다(스레드 join — 두 번 불러도 된다)."""
        with self._lock:
            if self._closed:
                return
            self._closed = True
        self._stop.set()
        self._thread.join(timeout=RELAY_TIMEOUT_S)
        self._release()  # 스레드가 이미 풀었으면 아무것도 하지 않는다(멱등)

    # --- 중계 스레드 ------------------------------------------------------------------------------------------------------

    def _run(self) -> None:
        try:
            while not self._stop.is_set():
                self._apply_freeze()
                for key, _ in self._selector.select(timeout=_RELAY_POLL_S):
                    sock = key.fileobj
                    if sock is self._listener:
                        self._accept()
                    elif isinstance(sock, socket.socket):
                        self._pump(sock)
        except OSError:  # 셀렉터 · 리스너 오류 — 루프를 끝내고 정리한다(시험 쪽은 연결 실패로 알아챈다)
            pass
        finally:
            self._release()

    def _accept(self) -> None:
        try:
            client, _ = self._listener.accept()
        except OSError:
            return
        try:
            upstream = socket.create_connection(self._upstream, timeout=RELAY_TIMEOUT_S)
        except OSError:
            client.close()
            return
        for sock in (client, upstream):
            sock.settimeout(RELAY_TIMEOUT_S)  # 셀렉터가 읽을 것이 있다고 한 뒤에만 recv한다 — sendall의 상한이다
        self._pairs.append((client, upstream))
        self._peers[client], self._peers[upstream] = upstream, client
        self._selector.register(client, selectors.EVENT_READ)
        self._selector.register(upstream, selectors.EVENT_READ)
        with self._lock:
            self._accepted += 1

    def _pump(self, sock: socket.socket) -> None:
        peer = self._peers.get(sock)
        if peer is None:
            return
        try:
            data = sock.recv(65536)
            if data:
                peer.sendall(data)
                return
        except OSError:
            pass
        self._drop(sock, peer)

    def _drop(self, sock: socket.socket, peer: socket.socket) -> None:
        """한 쌍을 닫는다(한쪽이 닫혔거나 오류)."""
        for item in (sock, peer):
            self._peers.pop(item, None)
            try:
                self._selector.unregister(item)
            except (KeyError, ValueError):
                pass
            item.close()
        self._pairs = [pair for pair in self._pairs if sock not in pair]

    def _apply_freeze(self) -> None:
        with self._lock:
            requests, self._freeze_requests = self._freeze_requests, []
        if not requests:
            return
        for client, upstream in self._pairs:
            for item in (client, upstream):
                self._peers.pop(item, None)
                self._selector.unregister(item)
                self._frozen.append(item)
        with self._lock:
            self._frozen_count += len(self._pairs)
        self._pairs = []
        for done in requests:
            done.set()

    def _release(self) -> None:
        """모든 소켓(리스너 · 중계 중 · 얼린 것)과 셀렉터를 닫는다 — 한 번만(중계 스레드의 끝과 close()가 둘 다 부른다)."""
        with self._lock:
            if self._released:
                return
            self._released = True
        sockets = [self._listener, *(item for pair in self._pairs for item in pair), *self._frozen]
        for item in sockets:
            try:
                item.close()
            except OSError:
                pass
        self._selector.close()
