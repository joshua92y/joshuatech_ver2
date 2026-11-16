"""T073 가짜 둘 자기검사(조각 ① · 설계 D26 · 〔W27〕 — iaf-1..24).

tests/_ia_fakes.py가 뒤 조각 ia 시험(ia-12 · 13 · 22 · 41)의 판정을 떠받치므로 가짜 자체의 동작을 먼저 고정한다.
① FakeAuthentikExt(T066 FakeAuthentik 하위 클래스): 모드를 켜지 않으면 T066 가짜와 같은 응답 · 상태 · 요청 기록(iaf-1) ·
  세션 목록(`user__username` · 쪽 매김 · 끝 뒤 쪽 404) · 단건 DELETE(204 · 404 · 대시 없는 hex 32자 경로 성분) · UUID 꼴이
  아닌 세션 uuid · 이벤트 목록(`actions` · `action` · `ordering` — 정렬 키는 파싱한 시각 · 항목은 넣은 그대로 · 「user 없는」
  세 꼴) · make_event의 DRF 꼴(`…Z` · `"user": {}`) · 필터 무시 · 정렬 무시 · 끝나지 않는 next(total_pages · 천장
  ENDLESS_PAGE_CEILING · ceiling_hits) · 경로별 상태 주입(None = 그 차례는 정상 처리) · 권한 없음(403 — 주입이 먼저) ·
  큰 JSON · reset · 경로 분류 · close · 응답을 읽지 않고 끊는 클라이언트(stderr 0 · errors — iaf-22).
② RawHttpServer: 스크립트한 응답(상태 · 헤더 · 본문 바이트 · 조각 사이 지연 · 상태 줄 앞 지연) · 받은 요청의 원문 줄 · 헤더 ·
  본문 기록 · 302 + Location(둘째 서버가 받은 요청 수) · JSON이 아닌 200 · 1 MiB 초과 본문 · 중간에 끊긴 클라이언트 · close ·
  서버가 _serve 앞에서 거절한 요청(do_* 없는 메서드 501 · 깨진 요청 줄 400 — count · rejected — iaf-23).
③ TcpRelay(조각 ⑤-a 수정 라운드 H2): 상류 = 로컬 에코 서버 — 중계된다 · freeze() 뒤 옛 연결은 응답이 없고 끊기지도 않았다
  (recv가 짧은 타임아웃으로 끝난다 — FIN · RST를 받지 않았다) · 새 연결은 중계된다 · close() 뒤 얼린 연결도 닫히고 스레드가
  끝나며 포트가 닫혀 있다(iaf-24).

DB · Dragonfly · Django 설정에 기대지 않는다(Docker 없이 돈다 — 표준 라이브러리 urllib · http.client만 · 프록시 없는 opener).
서버는 시험마다 새로 띄우고 닫는다. 지연은 작게 둔다(이 파일 전체가 수 초 안에 끝난다). 응답은 지역 변수에 묶은 뒤 단언한다 —
토큰은 assert 식 안에 두지 않는다(build-notes R0-2).
"""

from __future__ import annotations

import builtins
import http.client
import json
import secrets
import socket
import socketserver
import threading
import time
import urllib.error
import urllib.request
import uuid
from collections.abc import Callable, Iterator
from contextlib import ExitStack, contextmanager
from datetime import UTC, datetime, timedelta, timezone
from typing import Any
from urllib.parse import quote, urlencode

import pytest

from tests._ia_fakes import (
    DEFAULT_PAGE_SIZE,
    ENDLESS_PAGE_CEILING,
    EVENTS_PATH,
    FORBIDDEN_DETAIL,
    INVALID_PAGE_DETAIL,
    ROUTES,
    SESSIONS_PATH,
    FakeAuthentikExt,
    RawHttpServer,
    RawReply,
    TcpRelay,
    make_event,
    make_session,
    route_of,
)
from tests._identity_fakes import FakeAuthentik
from tests._secret import Secret

GROUPS = "/api/v3/core/groups/"
USERS = "/api/v3/core/users/"
JSON_TYPE = "application/json"
FORM_TYPE = "application/x-www-form-urlencoded"
OWNER_UUID = "11111111-1111-4111-8111-111111111111"
MEMBER_UUID = "22222222-2222-4222-8222-222222222222"
GROUP_PK = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
DECOY_GROUP_PK = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
GROUP_NAME = "tenant:0192e4c1-7a00-7000-8000-00000000c0de"
S1 = "5e551011-0000-4000-8000-000000000001"
S2 = "5e551011-0000-4000-8000-000000000002"
S3 = "5e551011-0000-4000-8000-000000000003"
MIB = 1024 * 1024
NOW = datetime(2026, 11, 12, 12, 0, tzinfo=UTC)
SEED_USERS = (
    {"pk": 101, "uuid": OWNER_UUID, "username": "owner", "attributes": {"existing": "keep"}},
    {"pk": 102, "uuid": MEMBER_UUID, "username": "member"},
)
SEED_GROUPS = (
    {"pk": DECOY_GROUP_PK, "name": "authentik Admins", "users": [101], "is_superuser": True},
    {"pk": GROUP_PK, "name": GROUP_NAME, "users": []},
)
# 프록시 없는 opener — Windows는 레지스트리 프록시 설정을 urllib 기본 opener가 읽는다(127.0.0.1 요청이 프록시로 새지 않게).
_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _raw_call(
    method: str, url: str, *, token: str | None = None, body: Any = None, content_type: str = JSON_TYPE
) -> tuple[int, bytes]:
    """HTTP 요청 한 번 → (상태, 본문 바이트). body가 bytes면 그대로 보낸다 · 본문이 있으면 Content-Type = content_type."""
    data = None if body is None else body if isinstance(body, bytes) else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method)
    if token is not None:
        request.add_header("Authorization", Secret(f"Bearer {token}"))
    if data is not None:
        request.add_header("Content-Type", content_type)
    try:
        with _OPENER.open(request, timeout=5) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
        error.close()
    return status, raw


def _call(
    method: str, url: str, *, token: str | None = None, body: Any = None, content_type: str = JSON_TYPE
) -> tuple[int, Any]:
    """_raw_call + JSON 디코드(빈 본문은 None)."""
    status, raw = _raw_call(method, url, token=token, body=body, content_type=content_type)
    return status, json.loads(raw) if raw else None


@pytest.fixture
def ext() -> Iterator[FakeAuthentikExt]:
    """사용자 2(101 owner · 102 member) · 그룹 2(미끼 superuser 그룹 · 테넌트 그룹)를 둔 확장 가짜(시험마다 새로 띄운다)."""
    server = FakeAuthentikExt()
    server.reset(groups=SEED_GROUPS, users=SEED_USERS)
    try:
        yield server
    finally:
        server.close()


@pytest.fixture
def raw() -> Iterator[RawHttpServer]:
    server = RawHttpServer()
    try:
        yield server
    finally:
        server.close()


def _get(fake: FakeAuthentikExt, path: str, **query: Any) -> tuple[int, Any]:
    """fake의 path에 GET(질의는 urlencode · 값이 list면 같은 키를 되풀이한다)."""
    suffix = f"?{urlencode(query, doseq=True)}" if query else ""
    return _call("GET", f"{fake.base_url}{path}{suffix}", token=fake.token)


def _uuids(body: Any) -> list[Any]:
    return [item.get("uuid") for item in body["results"]]


def _pagination(body: Any) -> tuple[Any, ...]:
    """(next, previous, count, current, total_pages, start_index, end_index)."""
    page = body["pagination"]
    keys = ("next", "previous", "count", "current", "total_pages", "start_index", "end_index")
    return tuple(page[key] for key in keys)


# --- ① 확장 가짜 Authentik --------------------------------------------------------------------------------------------


def _t066_sequence(fake: FakeAuthentik) -> list[tuple[int, Any]]:
    """T066 가짜의 표면(그룹 · 사용자 · add_user · PATCH · 415 · 403 · 모르는 경로 404)을 차례로 부른 결과."""
    base, token = fake.base_url, fake.token
    add_user = f"{base}{GROUPS}{GROUP_PK}/add_user/"
    calls: list[tuple[str, str, str | None, Any, str]] = [
        ("GET", f"{base}{GROUPS}", token, None, JSON_TYPE),
        ("GET", f"{base}{GROUPS}?name={quote(GROUP_NAME)}", token, None, JSON_TYPE),
        ("GET", f"{base}{GROUPS}?search=x", token, None, JSON_TYPE),
        ("GET", f"{base}{USERS}?uuid={OWNER_UUID}", token, None, JSON_TYPE),
        ("GET", f"{base}{USERS}", token, None, JSON_TYPE),
        ("GET", f"{base}{USERS}101/", token, None, JSON_TYPE),
        ("GET", f"{base}{USERS}999/", token, None, JSON_TYPE),
        ("POST", add_user, token, {"pk": 102}, JSON_TYPE),
        ("POST", add_user, token, {"pk": "x"}, JSON_TYPE),
        ("PATCH", f"{base}{USERS}102/", token, {"attributes": {"tenant_id": "t"}}, JSON_TYPE),
        ("PATCH", f"{base}{USERS}102/", token, {"username": "x"}, JSON_TYPE),
        ("PATCH", f"{base}{USERS}101/", token, {"attributes": {}}, FORM_TYPE),
        ("POST", f"{base}{GROUPS}", token, {"name": "tenant:new"}, JSON_TYPE),
        ("DELETE", f"{base}{USERS}101/", token, None, JSON_TYPE),
        ("GET", f"{base}/api/v3/core/groups", token, None, JSON_TYPE),
        ("GET", f"{base}{GROUPS}", None, None, JSON_TYPE),
        ("GET", f"{base}{GROUPS}", "not-the-token", None, JSON_TYPE),
    ]
    return [_call(method, url, token=tok, body=body, content_type=ctype) for method, url, tok, body, ctype in calls]


def test_iaf_1_default_matches_t066_fake() -> None:
    """iaf-1 — 모드를 켜지 않은 확장 가짜는 T066 FakeAuthentik과 같다: 같은 시드 · 같은 호출 차례에서 응답(상태 · 본문) ·
    요청 기록(메서드 · 경로 · 쿼리 · 인증 여부 · 본문) · mutations() · 남은 상태(그룹 소속 · 사용자 표현)가 같다."""
    observed: list[tuple[Any, ...]] = []
    for factory in (FakeAuthentik, FakeAuthentikExt):
        fake = factory()
        try:
            fake.reset(groups=SEED_GROUPS, users=SEED_USERS)
            replies = _t066_sequence(fake)
            log = [(r.method, r.path, r.query, r.authorized, r.body) for r in fake.requests]
            changed = [(r.method, r.path) for r in fake.mutations()]
            state = (fake.group_users(GROUP_NAME), fake.user(101), fake.user(102), fake.group_names())
        finally:
            fake.close()
        observed.append((replies, log, changed, state))
    base, extended = observed
    statuses = [status for status, _ in base[0]]
    assert statuses == [200, 200, 200, 200, 200, 200, 404, 204, 400, 200, 400, 415, 404, 404, 404, 403, 403]
    assert extended == base


def test_iaf_2_sessions_list_filter_and_pages(ext: FakeAuthentikExt) -> None:
    """iaf-2 — 세션 목록 `GET /api/v3/core/authenticated_sessions/`: `user__username` 필터(사용자 username) · `page` ·
    `page_size` 쪽 매김(next 0 = 끝) · 항목 꼴 `{uuid, user}`(넣은 그대로) · 필터 없음 → 전부 · 모르는 username → 빈 첫 쪽 ·
    page_size 꼴이 아니면 기본값 · 끝 뒤 쪽 · 0 · 숫자가 아닌 page → 404 `Invalid page.`(DRF 쪽 매김)."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1), make_session(102, S2), make_session(101, S3)])
    status, first = _get(ext, SESSIONS_PATH, user__username="owner", page_size=1, page=1)
    assert (status, first["results"]) == (200, [{"uuid": S1, "user": 101}])
    assert _pagination(first) == (2, 0, 2, 1, 2, 1, 1)
    status, second = _get(ext, SESSIONS_PATH, user__username="owner", page_size=1, page=2)
    assert (status, _uuids(second), _pagination(second)) == (200, [S3], (0, 1, 2, 2, 2, 2, 2))
    status, everything = _get(ext, SESSIONS_PATH)
    assert (status, _uuids(everything), everything["pagination"]["next"]) == (200, [S1, S2, S3], 0)
    status, nobody = _get(ext, SESSIONS_PATH, user__username="nobody")
    assert (status, nobody["results"], _pagination(nobody)) == (200, [], (0, 0, 0, 1, 1, 0, 0))
    status, defaulted = _get(ext, SESSIONS_PATH, page_size="many")
    assert (status, len(defaulted["results"]), DEFAULT_PAGE_SIZE >= 3) == (200, 3, True)
    for case, page in (("beyond", 3), ("zero", 0), ("letters", "x")):
        status, body = _get(ext, SESSIONS_PATH, user__username="owner", page_size=1, page=page)
        assert (status, body) == (404, {"detail": INVALID_PAGE_DETAIL}), case


def test_iaf_3_ignore_filters_mode(ext: FakeAuthentikExt) -> None:
    """iaf-3 — 필터 무시 미끼 모드(ignore_filters): 세션 `user__username` · 그룹 `name` · 사용자 `uuid` · 이벤트
    `actions`/`action`을 무시하고 거르지 않은 전부를 준다(남의 세션 · 미끼 그룹 · 다른 사용자 · login 이벤트 — 이벤트 정렬은
    그대로 `-created`). 끄면 다시 거른다."""
    login = make_event(101, NOW - timedelta(hours=1), action="login")
    logout = make_event(102, NOW - timedelta(hours=2))
    ext.reset(
        groups=SEED_GROUPS,
        users=SEED_USERS,
        sessions=[make_session(101, S1), make_session(102, S2)],
        events=[login, logout],
    )
    ext.ignore_filters = True
    _, sessions = _get(ext, SESSIONS_PATH, user__username="owner")
    _, groups = _get(ext, GROUPS, name=GROUP_NAME)
    _, users = _get(ext, USERS, uuid=OWNER_UUID)
    _, events = _get(ext, EVENTS_PATH, actions="logout", action="logout")
    observed = (
        _uuids(sessions),
        [group["name"] for group in groups["results"]],
        [user["pk"] for user in users["results"]],
        [event["action"] for event in events["results"]],
    )
    assert observed == ([S1, S2], ["authentik Admins", GROUP_NAME], [101, 102], ["login", "logout"])
    ext.ignore_filters = False
    _, sessions = _get(ext, SESSIONS_PATH, user__username="owner")
    _, events = _get(ext, EVENTS_PATH, actions="logout")
    assert (_uuids(sessions), [event["action"] for event in events["results"]]) == ([S1], ["logout"])


def test_iaf_4_endless_next_mode(ext: FakeAuthentikExt) -> None:
    """iaf-4 — 끝나지 않는 next 모드(endless_next): 천장(ENDLESS_PAGE_CEILING) 안에서는 세션 · 이벤트 목록의
    `pagination.next`가 늘 page + 1이고 total_pages = max(데이터 쪽 수, page + 1)이다(데이터 뒤 쪽은 빈 results · 404가
    아니다) — 쪽 상한(세션 10 · 이벤트 50)이 없는 구현은 천장까지 간다. 천장을 넘긴 쪽은 200 · 빈 results · next 0 ·
    total_pages = page로 끝나고 ceiling_hits가 그 요청 수를 센다(천장 안에서는 0 · reset이 0으로) — 상한 없는 구현은 매달리지
    않고 요청 수 단언에서 빨강이 된다."""
    sessions = [make_session(101, S1), make_session(101, S2), make_session(101, S3)]
    ext.reset(users=SEED_USERS, sessions=sessions, events=[make_event(101, NOW)])
    ext.endless_next = True
    status, first = _get(ext, SESSIONS_PATH, user__username="owner", page_size=1, page=1)
    assert (status, _uuids(first), _pagination(first)) == (200, [S1], (2, 0, 3, 1, 3, 1, 1))
    status, far = _get(ext, SESSIONS_PATH, user__username="owner", page_size=1, page=50)
    assert (status, far["results"], _pagination(far)) == (200, [], (51, 49, 3, 50, 51, 0, 0))
    status, events = _get(ext, EVENTS_PATH, actions="logout", page_size=100, page=7)
    assert (status, events["results"], _pagination(events)) == (200, [], (8, 6, 1, 7, 8, 0, 0))
    ceiling = ENDLESS_PAGE_CEILING
    status, last = _get(ext, SESSIONS_PATH, page_size=1, page=ceiling)
    observed = (status, last["results"], _pagination(last), ext.ceiling_hits)
    assert observed == (200, [], (ceiling + 1, ceiling - 1, 3, ceiling, ceiling + 1, 0, 0), 0)
    status, beyond = _get(ext, SESSIONS_PATH, page_size=1, page=ceiling + 1)
    observed = (status, beyond["results"], _pagination(beyond), ext.ceiling_hits)
    assert observed == (200, [], (0, ceiling, 3, ceiling + 1, ceiling + 1, 0, 0), 1)
    status, events_beyond = _get(ext, EVENTS_PATH, page=ceiling + 5)
    observed = (status, events_beyond["results"], _pagination(events_beyond), ext.ceiling_hits)
    assert observed == (200, [], (0, ceiling + 4, 1, ceiling + 5, ceiling + 5, 0, 0), 2)
    ext.reset(users=SEED_USERS)
    assert ext.ceiling_hits == 0


def test_iaf_5_session_delete(ext: FakeAuthentikExt) -> None:
    """iaf-5 — 세션 단건 `DELETE …/authenticated_sessions/<uuid>/`: 있는 세션 → 204(본문 없음 · 목록에서 사라진다 ·
    deleted_sessions에 경로 성분 그대로 남는다 — 대시 없는 hex 32자 경로 성분도 같은 세션이다(UUID 값으로 맞춘다)) · 같은 것
    다시 · 없는 uuid · UUID 꼴이 아닌 경로 성분 → 404 · 단건 GET은 없다(404) / UUID 꼴이 아닌 세션 uuid(문자열 · 정수)도
    목록에 넣은 그대로 실린다 · 요청은 모두 기록된다."""
    odd = [{"uuid": "../users/101", "user": 101}, {"uuid": 7, "user": 101}]
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1), make_session(102, S2), make_session(101, S3), *odd])
    url = f"{ext.base_url}{SESSIONS_PATH}"
    missing = str(uuid.uuid4())
    s3_hex = uuid.UUID(S3).hex
    replies = [
        _call("DELETE", f"{url}{S1}/", token=ext.token),
        _call("DELETE", f"{url}{S1}/", token=ext.token),
        _call("DELETE", f"{url}{missing}/", token=ext.token),
        _call("DELETE", f"{url}not-a-uuid/", token=ext.token),
        _call("GET", f"{url}{S2}/", token=ext.token),
        _call("DELETE", f"{url}{s3_hex}/", token=ext.token),
    ]
    assert [status for status, _ in replies] == [204, 404, 404, 404, 404, 204]
    assert (replies[0][1], replies[5][1]) == (None, None)
    _, listed = _get(ext, SESSIONS_PATH)
    assert listed["results"] == [{"uuid": S2, "user": 102}, *odd]
    assert ext.deleted_sessions == [S1, s3_hex]
    assert [session.get("uuid") for session in ext.sessions] == [S2, "../users/101", 7]
    deletes = [(request.method, request.path) for request in ext.mutations()]
    segments = [S1, S1, missing, "not-a-uuid", s3_hex]
    assert deletes == [("DELETE", f"{SESSIONS_PATH}{segment}/") for segment in segments]


def _event_seed() -> list[dict[str, Any]]:
    """이벤트 일곱 — pk 꼴(uuid 문자열 · hex 32자 · 정수) · 「user 없는」 세 꼴(`{}` — make_event(None) · 키 없음 · None) ·
    login 하나 · created가 서로 다르다(make_event의 DRF 꼴 `…Z`)."""
    no_user_key = make_event(None, NOW - timedelta(hours=5), pk="0f0f0f0f-0000-4000-8000-000000000006")
    del no_user_key["user"]
    null_user = make_event(None, NOW - timedelta(hours=6), pk="0f0f0f0f-0000-4000-8000-000000000007")
    null_user["user"] = None
    return [
        make_event(101, NOW - timedelta(hours=73), pk="0f0f0f0f-0000-4000-8000-000000000001"),
        make_event(102, NOW - timedelta(hours=1), pk="0f0f0f0f000040008000000000000002"),
        make_event(101, NOW - timedelta(hours=2), action="login", pk="0f0f0f0f-0000-4000-8000-000000000003"),
        make_event(101, NOW - timedelta(hours=3), pk=12345),
        make_event(None, NOW - timedelta(hours=4), pk="0f0f0f0f-0000-4000-8000-000000000005"),
        no_user_key,
        null_user,
    ]


def test_iaf_6_events_list(ext: FakeAuthentikExt) -> None:
    """iaf-6 — 이벤트 목록 `GET /api/v3/events/events/`: `actions`(여러 값 · 정확 일치) · `action`(부분 일치 · 대소문자 무시) ·
    `ordering`(`-created` 기본 · `created` · 그 밖의 값은 기본) · 모르는 키 무시 · 쪽 매김 · 항목은 넣은 그대로(pk 꼴 ·
    「user 없는」 세 꼴 `{}` · 키 없음 · None 그대로 · 필드를 더하지 않는다) / make_event의 꼴(DRF — aware datetime은 UTC로
    바꿔 `…Z` · 소수 초 그대로 · naive는 isoformat 그대로 · 문자열 그대로 · user_pk None → `"user": {}`) / 정렬 키는 파싱한
    시각이다(`Z` 접미에 소수 초가 있고 없는 값과 오프셋 없는 naive 값이 섞여도 시각 순 — naive는 UTC로 본다 · 문자열 비교로는
    틀리는 배치) · 읽히지 않는 created(꼴이 아닌 문자열 · 키 없음)는 한쪽에 모인다(비교 오류 없음)."""
    seed = _event_seed()
    ext.reset(users=SEED_USERS, events=seed)
    newest_first = [seed[1], seed[2], seed[3], seed[4], seed[5], seed[6], seed[0]]
    logout_newest_first = [seed[1], seed[3], seed[4], seed[5], seed[6], seed[0]]
    cases: list[tuple[str, dict[str, Any], list[dict[str, Any]]]] = [
        ("actions", {"actions": "logout", "ordering": "-created", "page_size": 100, "page": 1}, logout_newest_first),
        ("ascending", {"actions": "logout", "ordering": "created"}, logout_newest_first[::-1]),
        ("default-order", {}, newest_first),
        ("bad-ordering", {"ordering": "pk"}, newest_first),
        ("actions-multi", {"actions": ["logout", "login"]}, newest_first),
        ("action-substring", {"action": "LOG"}, newest_first),
        ("action-out", {"action": "out"}, logout_newest_first),
        ("unknown-key", {"foo": "1"}, newest_first),
    ]
    for case, query, expected in cases:
        status, body = _get(ext, EVENTS_PATH, **query)
        assert (status, body["results"]) == (200, expected), case
    status, paged = _get(ext, EVENTS_PATH, actions="logout", page_size=2, page=3)
    assert (status, paged["results"], _pagination(paged)) == (200, logout_newest_first[4:], (0, 2, 6, 3, 3, 5, 6))
    _, plain = _get(ext, EVENTS_PATH)
    user_forms = [event.get("user", "absent") for event in plain["results"][3:6]]
    assert user_forms == [{}, "absent", None]
    kst = timezone(timedelta(hours=9))
    rendered = (
        seed[1]["created"],
        make_event(101, NOW + timedelta(microseconds=500_000))["created"],
        make_event(101, datetime(2026, 11, 12, 21, 0, tzinfo=kst))["created"],
        make_event(101, datetime(2026, 11, 12, 12, 0))["created"],
        make_event(101, "2026-11-12T12:00:00+00:00")["created"],
        seed[4]["user"],
    )
    assert rendered == (
        "2026-11-12T11:00:00Z",
        "2026-11-12T12:00:00.500000Z",
        "2026-11-12T12:00:00Z",
        "2026-11-12T12:00:00",
        "2026-11-12T12:00:00+00:00",
        {},
    )
    # z3은 오프셋 없는(naive) ISO 문자열이다 — 정렬 키는 그것을 UTC로 본다(1V-2: aware와 섞여도 비교 오류 없이 시각 순 · 지역
    # 시간대로 읽는 구현이면 이 호스트(KST)에서 9시간 어긋난다).
    stamps = (
        "2026-11-12T12:00:00Z",
        "2026-11-12T12:00:00.500000Z",
        "2026-11-12T11:59:59.900000Z",
        "2026-11-12T12:00:00.250000",
    )
    mixed = [make_event(101, stamp, pk=f"z{index}") for index, stamp in enumerate(stamps)]
    unreadable = [make_event(101, "not-a-time", pk="u1"), {"pk": "u2", "action": "logout", "user": {"pk": 101}}]
    ext.reset(users=SEED_USERS, events=[*mixed, *unreadable])
    orders = []
    for ordering in ("-created", "created"):
        status, body = _get(ext, EVENTS_PATH, ordering=ordering)
        orders.append((status, [event["pk"] for event in body["results"]] if status == 200 else body))
    assert orders == [
        (200, ["z1", "z3", "z0", "z2", "u1", "u2"]),
        (200, ["u2", "u1", "z2", "z0", "z3", "z1"]),
    ]


def test_iaf_7_events_ignore_ordering_mode(ext: FakeAuthentikExt) -> None:
    """iaf-7 — 정렬 뒤섞기(ignore_ordering): `ordering`을 무시하고 넣은 순서(시험이 정한 뒤섞인 순서 — 창 밖 이벤트가 먼저)로
    준다 · 필터는 그대로 / 필터 무시와 함께 켜면 login도 넣은 순서로 섞인다."""
    seed = _event_seed()
    ext.reset(events=seed)
    ext.ignore_ordering = True
    _, ordered = _get(ext, EVENTS_PATH, actions="logout", ordering="-created")
    assert ordered["results"] == [seed[0], seed[1], seed[3], seed[4], seed[5], seed[6]]
    ext.ignore_filters = True
    _, everything = _get(ext, EVENTS_PATH, actions="logout", ordering="-created")
    assert everything["results"] == seed


def test_iaf_8_status_injection_per_route(ext: FakeAuthentikExt) -> None:
    """iaf-8 — 경로별 상태 순서 주입 inject(route, *replies): 그 경로의 다음 요청들이 차례로 그 응답이다(정수 = 그 상태 +
    `{"detail": …}` · (상태, 본문) = 그대로 · 204 = 본문 없음 · None = 그 차례는 주입 없이 정상 처리) · 다 쓰면 정상 · 다른
    경로는 영향 없음 · 주입된 DELETE는 지우지 않는다 / `inject("events", None, 503)` = 첫 요청 정상(200 · 쪽 매김 본문) ·
    둘째 503 · 셋째 정상."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)])
    ext.inject("sessions", 503, 503)
    ext.inject("user_detail", (502, {"detail": "bad gateway"}))
    ext.inject("session_detail", 404)
    users_status, _ = _get(ext, USERS)
    sessions = [_get(ext, SESSIONS_PATH)[0] for _ in range(3)]
    detail = _get(ext, f"{USERS}101/")
    detail_again = _get(ext, f"{USERS}101/")
    url = f"{ext.base_url}{SESSIONS_PATH}{S1}/"
    deletes = [_call("DELETE", url, token=ext.token)[0] for _ in range(2)]
    observed = (users_status, sessions, detail, detail_again[0], deletes, ext.deleted_sessions)
    assert observed == (200, [503, 503, 200], (502, {"detail": "bad gateway"}), 200, [404, 204], [S1])
    ext.inject("events", 429, (204, None))
    first_status, first_body = _get(ext, EVENTS_PATH)
    second = _get(ext, EVENTS_PATH)
    assert (first_status, isinstance(first_body.get("detail"), str), second) == (429, True, (204, None))
    event = make_event(101, NOW)
    ext.reset(users=SEED_USERS, events=[event])
    ext.inject("events", None, 503)
    replies = [_get(ext, EVENTS_PATH) for _ in range(3)]
    statuses = [status for status, _ in replies]
    assert statuses == [200, 503, 200]
    passed, normal = replies[0][1], replies[2][1]
    assert (passed["results"], _pagination(passed), normal["results"]) == ([event], (0, 0, 1, 1, 1, 1, 1), [event])


def test_iaf_9_forbidden_routes(ext: FakeAuthentikExt) -> None:
    """iaf-9 — 권한 없음 forbid(*routes): 그 경로는 늘 403 `{"detail": <DRF 문구>}`(되풀이해도) · 다른 경로는 정상 ·
    reset이 푼다 / 같은 경로에 forbid와 inject를 함께 걸면 주입이 먼저 쓰이고 다 쓰면 403이다 · 주입의 None 자리(정상 처리)도
    403을 받는다."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)], events=[make_event(101, NOW)])
    ext.forbid("events", "user_detail")
    replies = [_get(ext, EVENTS_PATH), _get(ext, EVENTS_PATH), _get(ext, f"{USERS}101/")]
    sessions_status, _ = _get(ext, SESSIONS_PATH)
    forbidden = (403, {"detail": FORBIDDEN_DETAIL})
    assert (replies, sessions_status) == ([forbidden, forbidden, forbidden], 200)
    ext.reset(users=SEED_USERS)
    status, _ = _get(ext, f"{USERS}101/")
    assert status == 200
    ext.forbid("sessions")
    ext.inject("sessions", 503, 502)
    order = [_get(ext, SESSIONS_PATH)[0] for _ in range(3)]
    assert order == [503, 502, 403]
    ext.inject("sessions", None)
    passed_status, _ = _get(ext, SESSIONS_PATH)
    assert passed_status == 403


def test_iaf_10_inflated_json(ext: FakeAuthentikExt) -> None:
    """iaf-10 — 큰 JSON inflate(route, min_bytes): 그 경로의 200 JSON 객체 응답이 min_bytes보다 크다(덧붙인 키 하나 —
    PADDING) · 여전히 JSON이고 원래 필드는 그대로 · 200이 아닌 응답과 다른 경로는 부풀리지 않는다 · 주입의 None 자리(정상
    처리)도 부풀린다."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)])
    ext.inflate("sessions", MIB)
    status, raw_body = _raw_call("GET", f"{ext.base_url}{SESSIONS_PATH}", token=ext.token)
    body = json.loads(raw_body)
    assert (status, len(raw_body) > MIB, _uuids(body), body["pagination"]["count"]) == (200, True, [S1], 1)
    missing_status, missing = _raw_call("GET", f"{ext.base_url}{SESSIONS_PATH}?page=9", token=ext.token)
    users_status, users = _raw_call("GET", f"{ext.base_url}{USERS}", token=ext.token)
    assert (missing_status, len(missing) < 1024, users_status, len(users) < 4096) == (404, True, 200, True)
    # 1V-2: 주입의 None 자리(그 차례는 정상 처리)도 부풀린다 — 다음 차례의 503이 그 자리가 실제로 쓰였음을 보인다.
    ext.inject("sessions", None, 503)
    passed_status, passed = _raw_call("GET", f"{ext.base_url}{SESSIONS_PATH}", token=ext.token)
    after_status, _ = _raw_call("GET", f"{ext.base_url}{SESSIONS_PATH}", token=ext.token)
    assert (passed_status, len(passed) > MIB, after_status) == (200, True, 503)


def test_iaf_11_reset_clears_modes(ext: FakeAuthentikExt) -> None:
    """iaf-11 — reset: 세션 · 이벤트 · 지운 기록 · 요청 기록 · 모드(필터 무시 · 정렬 무시 · 끝없는 next) · 주입 · 권한 없음 ·
    부풀리기를 모두 비운다."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)], events=[make_event(101, NOW)])
    ext.ignore_filters = ext.ignore_ordering = ext.endless_next = True
    ext.inject("sessions", 503)
    ext.forbid("events")
    ext.inflate("users", MIB)
    _call("DELETE", f"{ext.base_url}{SESSIONS_PATH}{S1}/", token=ext.token)
    ext.reset(users=SEED_USERS)
    modes = (ext.ignore_filters, ext.ignore_ordering, ext.endless_next)
    state = (ext.sessions, ext.events, ext.deleted_sessions, ext.requests)
    assert (modes, state) == ((False, False, False), ([], [], [], []))
    sessions_status, sessions = _get(ext, SESSIONS_PATH)
    events_status, _ = _get(ext, EVENTS_PATH)
    users_status, users_raw = _raw_call("GET", f"{ext.base_url}{USERS}", token=ext.token)
    observed = (sessions_status, sessions["pagination"]["next"], events_status, users_status, len(users_raw) < 4096)
    assert observed == (200, 0, 200, 200, True)


def test_iaf_12_routes_and_requests_to(ext: FakeAuthentikExt) -> None:
    """iaf-12 — 경로 분류 route_of(path)(끝 슬래시 포함 정확 일치 · 모르는 경로 None) · requests_to(route)는 그 경로의 요청
    기록만 · 모르는 경로 이름의 inject · forbid · inflate · requests_to는 ValueError(시험의 오타를 조용히 넘기지 않는다)."""
    mapping = {
        GROUPS: "groups",
        f"{GROUPS}{GROUP_PK}/add_user/": "add_user",
        USERS: "users",
        f"{USERS}101/": "user_detail",
        SESSIONS_PATH: "sessions",
        f"{SESSIONS_PATH}{S1}/": "session_detail",
        EVENTS_PATH: "events",
        "/api/v3/core/groups": None,
        "/api/v3/events/events": None,
        f"{USERS}abc/": None,
    }
    assert {path: route_of(path) for path in mapping} == mapping
    assert ROUTES == frozenset(route for route in mapping.values() if route is not None)
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)])
    _get(ext, SESSIONS_PATH, page=1)
    _get(ext, f"{USERS}101/")
    _get(ext, SESSIONS_PATH, page=2)
    pages = [request.query.get("page") for request in ext.requests_to("sessions")]
    assert (pages, len(ext.requests_to("user_detail")), ext.requests_to("events")) == ([["1"], ["2"]], 1, [])
    for action in (
        lambda: ext.inject("session", 503),
        lambda: ext.forbid("event"),
        lambda: ext.inflate("user", 10),
        lambda: ext.requests_to("group"),
    ):
        with pytest.raises(ValueError):
            action()


def test_iaf_13_ext_requires_bearer_on_new_routes(ext: FakeAuthentikExt) -> None:
    """iaf-13 — 새 경로도 T066 가짜의 인증을 지난다: 토큰 없음 · 다른 토큰 → 403(주입 · 상태 무변화) · 요청은 기록된다."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)])
    ext.inject("sessions", 503)
    url = f"{ext.base_url}{SESSIONS_PATH}"
    replies = [
        _call("GET", url)[0],
        _call("DELETE", f"{url}{S1}/", token="not-the-token")[0],
        _call("GET", f"{ext.base_url}{EVENTS_PATH}")[0],
    ]
    authorized = [request.authorized for request in ext.requests]
    assert (replies, authorized, ext.deleted_sessions) == ([403, 403, 403], [False, False, False], [])
    status, _ = _get(ext, SESSIONS_PATH)
    assert status == 503


# --- ② 원시 HTTP 서버 ---------------------------------------------------------------------------------------------------


def _connection(server: RawHttpServer, timeout: float = 5.0) -> http.client.HTTPConnection:
    return http.client.HTTPConnection("127.0.0.1", server.port, timeout=timeout)


def test_iaf_14_raw_records_request(raw: RawHttpServer) -> None:
    """iaf-14 — 원시 서버: 스크립트한 응답(상태 · 헤더 · 본문 바이트 그대로) / 받은 요청 기록 — 원문 요청 줄(질의 인코딩 그대로) ·
    메서드 · 경로 · 질의(parse_qs — `&` · `#` · `%` · 공백 값이 원문과 같다) · 헤더(순서 · 대소문자 무시 조회) · 본문 바이트 ·
    Authorization 값은 repr이 가려진다."""
    token = Secret(secrets.token_urlsafe(24))
    raw.script(RawReply(status=201, headers=(("Content-Type", JSON_TYPE), ("X-Fake", "1")), chunks=(b'{"ok": true}',)))
    original = "a&b #c %d e"
    target = f"/api/v3/core/users/?{urlencode({'uuid': original})}"
    connection = _connection(raw)
    try:
        connection.request(
            "POST",
            target,
            body=b'{"k": 1}',
            headers={"Authorization": Secret(f"Bearer {token}"), "Content-Type": JSON_TYPE, "User-Agent": "ia/1"},
        )
        response = connection.getresponse()
        reply = (response.status, response.getheader("X-Fake"), response.getheader("Content-Length"), response.read())
    finally:
        connection.close()
    assert reply == (201, "1", "12", b'{"ok": true}')
    (request,) = raw.requests
    observed = (request.method, request.path, request.query, request.request_line, request.body)
    assert observed == ("POST", "/api/v3/core/users/", {"uuid": [original]}, f"POST {target} HTTP/1.1", b'{"k": 1}')
    sent_authorization = request.header("authorization") == f"Bearer {token}"
    leaked = token in repr(request) or token in repr(request.headers)
    looked_up = (request.header("USER-AGENT"), request.header("x-missing"))
    assert (sent_authorization, leaked, looked_up) == (True, False, ("ia/1", None))
    names = [name.lower() for name, _ in request.headers]
    assert names == ["host", "accept-encoding", "content-length", "authorization", "content-type", "user-agent"]
    assert raw.count == 1


def test_iaf_15_raw_redirect_to_second_server() -> None:
    """iaf-15 — 302 + Location(둘째 서버로): 리디렉션을 따르지 않는 클라이언트는 302와 Location을 받고 둘째 서버가 받은 요청은
    0이다 / 리디렉션을 따르는 클라이언트(urllib 기본 opener)는 둘째 서버로 가고 둘째 서버가 그 요청을 센다(경로 · 수)."""
    with ExitStack() as stack:  # 둘째 서버를 만들다 실패해도 첫째가 닫힌다
        target = RawHttpServer()
        stack.callback(target.close)
        origin = RawHttpServer()
        stack.callback(origin.close)
        location = f"{target.base_url}/landing"
        origin.script(RawReply.redirect(location), RawReply.redirect(location))
        connection = _connection(origin)
        try:
            connection.request("GET", "/start")
            response = connection.getresponse()
            first = (response.status, response.getheader("Location"), response.read())
        finally:
            connection.close()
        assert (first[0], first[1], target.count) == (302, location, 0)
        with _OPENER.open(f"{origin.base_url}/start", timeout=5) as followed:
            second = (followed.status, followed.read())
        assert (second, target.count, [request.path for request in target.requests]) == ((200, b"{}"), 1, ["/landing"])
        assert origin.count == 2


def test_iaf_16_raw_non_json_and_no_length(raw: RawHttpServer) -> None:
    """iaf-16 — JSON이 아닌 200(text/html 바이트 그대로) · Content-Length 없는 응답(연결 종료까지가 본문)."""
    raw.script(
        RawReply.text(b"<html>not json</html>"),
        RawReply(chunks=(b'{"a": ', b"1}"), content_length=False),
    )
    observed: list[tuple[Any, ...]] = []
    for _ in range(2):
        connection = _connection(raw)
        try:
            connection.request("GET", "/x")
            response = connection.getresponse()
            headers = (response.getheader("Content-Type"), response.getheader("Content-Length"))
            observed.append((response.status, *headers, response.read()))
        finally:
            connection.close()
    assert observed == [
        (200, "text/html; charset=utf-8", "21", b"<html>not json</html>"),
        (200, JSON_TYPE, None, b'{"a": 1}'),
    ]


def test_iaf_17_raw_slow_chunks(raw: RawHttpServer) -> None:
    """iaf-17 — 느린 응답: 상태 줄 앞 지연(head_delay_s) · 조각 사이 지연(delay_s) — 헤더는 앞 지연 뒤에 오고 본문 전체는
    (조각 수 − 1) × 지연 뒤에 끝난다 · 받은 본문은 조각을 이은 것과 같다(Content-Length = 전체 길이)."""
    body = b'{"results": [' + b",".join(b"1" for _ in range(40)) + b"]}"
    raw.script(RawReply.slow(body, pieces=4, delay_s=0.15, head_delay_s=0.2))
    connection = _connection(raw)
    try:
        start = time.perf_counter()
        connection.request("GET", "/slow")
        response = connection.getresponse()
        head_s = time.perf_counter() - start
        length = response.getheader("Content-Length")
        received = response.read()
        total_s = time.perf_counter() - start
    finally:
        connection.close()
    assert (received, length) == (body, str(len(body)))
    assert (head_s >= 0.18, total_s >= 0.18 + 3 * 0.15 - 0.05, total_s < 3.0) == (True, True, True)


def test_iaf_18_raw_large_body(raw: RawHttpServer) -> None:
    """iaf-18 — 1 MiB를 넘는 본문(RawReply.large — JSON 문자열 하나 · 바이트 수 정확) · Content-Length가 그 길이다."""
    raw.script(RawReply.large(MIB + 1))
    connection = _connection(raw)
    try:
        connection.request("GET", "/big")
        response = connection.getresponse()
        length, received = response.getheader("Content-Length"), response.read()
    finally:
        connection.close()
    decoded = json.loads(received)
    assert (len(received), length, isinstance(decoded, str)) == (MIB + 1, str(MIB + 1), True)


def test_iaf_19_raw_queue_then_default() -> None:
    """iaf-19 — 스크립트는 차례대로 한 번씩 쓰이고(FIFO · 여러 번 script하면 뒤에 붙는다), 다 쓰면 기본 응답이다(생성자
    default · 없으면 200 `{}`)."""
    servers = (RawHttpServer(), RawHttpServer(default=RawReply.json({"d": 1}, status=404)))
    try:
        observed: list[list[tuple[int, bytes]]] = []
        for server in servers:
            server.script(RawReply.json({"n": 1}))
            server.script(RawReply.json({"n": 2}, status=500))
            replies = []
            for _ in range(3):
                replies.append(_raw_call("GET", f"{server.base_url}/q"))
            observed.append(replies)
        assert observed == [
            [(200, b'{"n": 1}'), (500, b'{"n": 2}'), (200, b"{}")],
            [(200, b'{"n": 1}'), (500, b'{"n": 2}'), (404, b'{"d": 1}')],
        ]
    finally:
        for server in servers:
            server.close()


def test_iaf_20_raw_client_disconnect(raw: RawHttpServer, capsys: pytest.CaptureFixture[str]) -> None:
    """iaf-20 — 느린 본문을 받다가 클라이언트가 끊어도(마감에서 끊는 구현의 꼴) 서버는 그 요청의 쓰기 오류를 errors에 이름으로
    남기고 stderr에 아무것도 쓰지 않으며 다음 요청을 정상으로 받는다."""
    raw.script(RawReply.slow(b"x" * 4000, pieces=20, delay_s=0.05))
    connection = _connection(raw)
    response: http.client.HTTPResponse | None = None  # getresponse()가 실패해도 finally가 원 오류를 가리지 않게
    try:
        connection.request("GET", "/slow")
        response = connection.getresponse()
        response.read(10)
    finally:
        connection.close()
        if response is not None:
            response.close()
    deadline = time.monotonic() + 3.0
    while raw.finished < 1 and time.monotonic() < deadline:
        time.sleep(0.02)
    after_status, after_body = _raw_call("GET", f"{raw.base_url}/next")
    captured = capsys.readouterr()
    observed = (raw.finished >= 1, len(raw.errors), (after_status, after_body), captured.err)
    assert observed == (True, 1, (200, b"{}"), "")
    kind = getattr(builtins, raw.errors[0], None)
    assert isinstance(kind, type) and issubclass(kind, OSError), raw.errors


def test_iaf_21_close_stops_servers() -> None:
    """iaf-21 — close() 뒤 서버 스레드가 끝나고 포트가 연결을 받지 않는다 · 두 번 불러도 된다(확장 가짜 · 원시 서버)."""
    factories: tuple[Callable[[], FakeAuthentikExt | RawHttpServer], ...] = (FakeAuthentikExt, RawHttpServer)
    for factory in factories:
        server = factory()  # 서버는 차례로 하나씩 만든다 — 단언이 실패해도 만든 서버는 finally가 닫는다
        try:
            port = server.port
            server.close()
            server.close()
            alive = server.thread_alive
        finally:
            server.close()
        assert alive is False
        with pytest.raises(OSError):
            socket.create_connection(("127.0.0.1", port), timeout=1.0).close()


def test_iaf_22_ext_client_abort_is_quiet(ext: FakeAuthentikExt, capsys: pytest.CaptureFixture[str]) -> None:
    """iaf-22 — 확장 가짜: 요청을 보내고 응답을 읽지 않은 채 바로 끊기를 되풀이해도(마감 · 크기 상한에서 끊는 구현의 꼴)
    stderr에 아무것도 쓰지 않는다 · 그 뒤의 정상 요청은 200이다 · errors에 남은 이름은 모두 OSError 하위 클래스다(0개여도
    된다 — 끊김이 쓰기 오류가 되는지는 타이밍이다). 요청 스레드가 응답 쓰기를 마치도록 기록 수를 기다린 뒤 고정 지연 한 번
    (0.3 s)을 두고 stderr를 읽는다 / errors가 한 개 이상 찬 뒤 reset()이 errors를 비운다."""
    ext.reset(users=SEED_USERS, sessions=[make_session(101, S1)])
    rounds = 20
    request = (
        f"GET {SESSIONS_PATH} HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer {ext.token}\r\n"
        "Connection: close\r\n\r\n"
    ).encode()

    def abort_rounds() -> None:
        """요청을 보내고 응답을 읽지 않은 채 끊기를 rounds번 한 뒤 기록 수가 찰 때까지 기다린다(고정 지연 0.3 s 포함)."""
        expected = len(ext.requests) + rounds
        for _ in range(rounds):
            client = socket.create_connection(("127.0.0.1", ext.port), timeout=5)
            try:
                client.sendall(request)
            finally:
                client.close()
        deadline = time.monotonic() + 3.0
        while len(ext.requests) < expected and time.monotonic() < deadline:
            time.sleep(0.02)
        time.sleep(0.3)

    abort_rounds()
    recorded = len(ext.requests)
    status, _ = _get(ext, SESSIONS_PATH)
    captured = capsys.readouterr()
    assert (recorded, captured.err, status) == (rounds, "", 200)
    names = ext.errors
    kinds = [getattr(builtins, name, None) for name in names]
    assert all(isinstance(kind, type) and issubclass(kind, OSError) for kind in kinds), names
    # 1V-2: reset()이 errors를 비운다(세션 범위 가짜의 시험 간 격리) — 비우기 전에 errors가 한 개 이상이어야 사례가 공허하지
    # 않다(끊김이 쓰기 오류가 되는지는 타이밍이라 비어 있으면 끊기를 더 되풀이한다 · 실측 20회에 17-20개).
    extra = 0
    while not ext.errors and extra < 5:
        abort_rounds()
        extra += 1
    before_reset = len(ext.errors)
    ext.reset(users=SEED_USERS)
    after_reset = ext.errors
    assert (before_reset >= 1, after_reset) == (True, [])


def test_iaf_23_raw_counts_rejected_requests(raw: RawHttpServer) -> None:
    """iaf-23 — 원시 서버가 _serve에 닿기 전에 거절한 요청도 받은 요청으로 센다: do_*가 없는 메서드(HEAD → 501) · 깨진 요청
    줄(소켓으로 직접 쓴 바이트 → 400)은 count를 늘리고 rejected에 (상태, 요청 줄)로 남는다 · requests는 비어 있다(「받은 요청
    0」 단언은 count로 한다) / 그 뒤 정상 GET은 평소대로 requests에 기록된다 / 200자를 넘는 요청 줄은 rejected에 앞 200자만
    남는다."""
    connection = _connection(raw)
    try:
        connection.request("HEAD", "/probe")
        response = connection.getresponse()
        head_status = response.status
        response.read()
    finally:
        connection.close()
    broken_line = "\x16\x03\x01 not an http request line"
    client = socket.create_connection(("127.0.0.1", raw.port), timeout=5)
    try:
        client.sendall(broken_line.encode("latin-1") + b"\r\n\r\n")
        received = b""
        while chunk := client.recv(65536):
            received += chunk
    finally:
        client.close()
    assert (head_status, b"400" in received, raw.count) == (501, True, 2)
    assert (raw.rejected, raw.requests) == ([(501, "HEAD /probe HTTP/1.1"), (400, broken_line)], [])
    status, body = _raw_call("GET", f"{raw.base_url}/after")
    paths = [request.path for request in raw.requests]
    assert (status, body, raw.count, len(raw.rejected), paths) == (200, b"{}", 3, 2, ["/after"])
    # 1V-2: rejected의 요청 줄은 앞 200자만 남긴다(헤더 값은 늘 싣지 않는다 · 긴 줄을 통째로 쌓지 않는다).
    long_target = "/" + "a" * 300
    connection = _connection(raw)
    try:
        connection.request("HEAD", long_target)
        response = connection.getresponse()
        long_status = response.status
        response.read()
    finally:
        connection.close()
    last_status, last_line = raw.rejected[-1]
    expected_line = f"HEAD {long_target} HTTP/1.1"[:200]
    observed = (long_status, last_status, len(last_line), last_line == expected_line, raw.count)
    assert observed == (501, 501, 200, True, 4)


# --- ③ TCP 중계 ---------------------------------------------------------------------------------------------------------


class _EchoServer(socketserver.ThreadingTCPServer):
    """받은 바이트를 그대로 돌려주는 127.0.0.1 서버(연결마다 데몬 스레드 · 닫을 때 요청 스레드를 기다리지 않는다)."""

    daemon_threads = True
    block_on_close = False


class _EchoHandler(socketserver.BaseRequestHandler):
    def handle(self) -> None:
        try:
            while data := self.request.recv(65536):
                self.request.sendall(data)
        except OSError:  # 중계가 닫으며 끊었다(RST) — 조용히 끝낸다
            return


@contextmanager
def _echo_server() -> Iterator[int]:
    """에코 서버를 띄우고 포트를 준다 — 블록을 나오면 shutdown · server_close · 스레드 join."""
    server = _EchoServer(("127.0.0.1", 0), _EchoHandler)
    thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.05}, name="echo", daemon=True)
    thread.start()
    try:
        yield int(server.server_address[1])
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)


def _recv_exact(sock: socket.socket, size: int) -> bytes:
    """size바이트를 받을 때까지 읽는다(소켓 타임아웃 5 s · 상대가 먼저 닫으면 받은 데까지)."""
    sock.settimeout(5.0)
    received = b""
    while len(received) < size:
        chunk = sock.recv(size - len(received))
        if not chunk:
            break
        received += chunk
    return received


def _recv_outcome(sock: socket.socket, timeout_s: float) -> str:
    """recv 한 번의 결과 — "data" · "eof"(FIN을 받았다) · "reset"(RST) · "timeout"(timeout_s 동안 아무것도 오지 않았다)."""
    sock.settimeout(timeout_s)
    try:
        data = sock.recv(65536)
    except TimeoutError:
        return "timeout"
    except (ConnectionResetError, ConnectionAbortedError):
        return "reset"
    return "data" if data else "eof"


def test_iaf_24_tcp_relay_freeze_keeps_dead_connections_open() -> None:
    """iaf-24(조각 ⑤-a 수정 라운드 H2) — TcpRelay(상류 = 로컬 에코 서버): ① 연결이 중계된다(보낸 바이트가 그대로 돌아온다) ②
    freeze() 뒤 그때까지 맺어진 연결은 더 중계되지 않지만 끊기지도 않았다 — 보낸 바이트에 응답이 없고 recv가 짧은 타임아웃
    (0.3 s)으로 끝난다(FIN이면 eof · RST면 reset이다 — 클라이언트에는 살아 보이는 죽은 연결) ③ freeze() 뒤 새로 맺은 연결은
    정상 중계된다 · accepted 2 · frozen 1 ④ close() 뒤(두 번 불러도 된다) 얼린 연결도 닫혀 옛 클라이언트가 eof나 reset을 받고 ·
    중계 스레드가 끝나며 · 포트가 연결을 받지 않는다."""
    with ExitStack() as stack:  # 중간에 실패해도 에코 서버 · 중계 · 클라이언트 소켓이 닫힌다
        upstream = stack.enter_context(_echo_server())
        relay = TcpRelay("127.0.0.1", upstream)
        stack.callback(relay.close)
        port = relay.port
        old = stack.enter_context(socket.create_connection(("127.0.0.1", port), timeout=5))
        old.sendall(b"ping")
        relayed = _recv_exact(old, 4)
        relay.freeze()
        old.sendall(b"lost")
        frozen = _recv_outcome(old, 0.3)
        new = stack.enter_context(socket.create_connection(("127.0.0.1", port), timeout=5))
        new.sendall(b"pong")
        fresh = _recv_exact(new, 4)
        counts = (relay.accepted, relay.frozen)
        relay.close()
        relay.close()
        after_close = (_recv_outcome(old, 2.0), relay.thread_alive)
    assert (relayed, frozen, fresh, counts) == (b"ping", "timeout", b"pong", (2, 1))
    assert after_close in {("eof", False), ("reset", False)}, after_close
    with pytest.raises(OSError):
        socket.create_connection(("127.0.0.1", port), timeout=1.0).close()
