"""Authentik 관리 API 포트(T073 설계 D20 — pod 소유 새 파일) — 세션 삭제 위임(D16) · 일 1회 대조(D17) · seed_tenant(D19)가 부르는
메서드 여덟.

정본: 설계 D20 「authentik.py」 · D16 3-5단계 · D17 2 · 5단계 · D19 3 · 5 · 6단계 · D26(상수 이름) · 사실 ⑭(쪽 매김 · 모르는 질의
키는 오류 없이 전체 목록) · contracts/identity-admin-api.md §타임아웃 · 재시도.

- 호출은 outbound.request_json 하나로 한다(5 s · 1 MiB · 리디렉션 · 프록시 없음 · 오류 위생 — 그 모듈 독스트링). base = 호출 때의
  `settings.AUTHENTIK_API_URL`(끝 `/` 뗌) + `/api/v3/…/`(끝 슬래시 — Authentik은 끝 슬래시 경로만 받는다). token 기본 = 호출 때의
  `settings.AUTHENTIK_API_TOKEN` · `token=`을 주면 그 값(seed의 `--authentik-token-stdin` — 그 실행의 모든 호출이 그 토큰을 쓴다).
  모든 메서드는 선택 인자 `deadline`(outbound.Deadline — 호출자의 전체 마감)을 각 호출에 그대로 넘긴다.
- 실패는 outbound의 UpstreamStatus · UpstreamUnavailable이 그대로 올라온다(재시도 · 로그 없음 — 재시도와 이벤트 이름은 호출자의
  것이다 · 설계 D16 · D17 · D25). 자리값 자격(D18)과 쓰기 플래그(AUTHENTIK_WRITES_ENABLED)는 보지 않는다 — 부를지 정하는 것은
  호출자 몫이다.
- 경로 성분은 꼴을 본 뒤 조립한다(설계 D20 「URL 조립」 — 응답에서 온 값도 같다): 사용자 pk = 1 이상 2**63 미만 정수(bool 제외 —
  상한은 outbound.build_url의 int 성분 상한과 같다: 넘는 값도 「꼴 아님」이라 invalid_request가 아니라 아래 반환이다 · add_user가
  본문에 싣는 pk도 같다) · 그룹 pk와 세션 uuid = UUID 8-4-4-4-12 꼴 문자열(valid_pk · valid_uuid). 꼴이 아니면 부르지 않는다
  (반환은 메서드마다 아래). 질의는 outbound.build_url의 urlencode다.
- 필터가 무시되면(사실 ⑭) 미끼를 고르지 않게 클라이언트 쪽에서 다시 거른다: find_group은 name 정확 일치 · find_user는 uuid 정확
  일치 · list_sessions는 응답의 user가 그 pk(정수 — bool · 문자열 제외)인 세션만(남의 세션을 지우지 않는다 · 〔조사 E2〕).
- 쪽 매김 목록(세션 · 이벤트)은 쪽 번호를 1부터 직접 세고(`page_size=100&page=<n>`) 상한에서 멈춘다 — SESSION_PAGE_LIMIT 10 ·
  EVENT_PAGE_LIMIT 50(쓰는 자리에서 모듈 속성으로 읽는다: 시험이 덮는다 · 설계 D26). 응답의 `pagination.next`는 「더 있는가」(0이
  아닌가)로만 쓰고 그 값을 URL로 따라가지 않는다. 상한 쪽의 next가 0이 아니면 truncated 참이다. 2쪽 이후의 404(쪽 사이에 목록이
  줄었다 — DRF가 범위 밖 쪽에 내는 응답)는 목록의 끝이다(truncated 거짓). 1쪽의 404는 UpstreamStatus(404)로 올라온다(조용히 끝나지
  않는다 — 설계 D17). 한 쪽의 results가 PAGE_SIZE를 넘으면 malformed다(요청한 쪽 크기를 어긴 상류 — 누적 메모리의 값싼 상한).
  - list_sessions는 쪽을 다 모은 뒤 돌려준다(지우기 전에 다 모아야 쪽이 밀리지 않는다) — 중간 쪽이 실패하면 예외가 그대로
    올라오고 앞 쪽의 항목은 버려진다(그 자리에서 멈춘다 · 뒤 쪽 호출 0 · 일시 오류면 호출자의 재시도가 목록을 다시 읽는다).
  - logout_event_pages는 쪽마다 내주는 제너레이터다 — 실패는 그 쪽 요청에서(next() 자리에서) 올라오고 앞 쪽은 이미 호출자가 받았다
    (설계 D17 「이미 기록한 행은 남는다」 — 정렬이 `-created`라 필요한 것은 앞 쪽에 있다 · contracts/identity-admin-api.md
    §타임아웃 「대조는 이벤트 목록을 쪽 단위로 처리한다」).
- 응답 꼴이 계약 밖이면 UpstreamUnavailable("malformed"): 목록 본문이 dict가 아님 · results가 list가 아님 · 쪽 매김 목록의
  pagination.next가 0 이상 정수(bool 제외)가 아님 · 쪽 매김 목록의 한 쪽 results가 PAGE_SIZE 초과 · 단건 본문이 dict가 아님.
  results 안의 dict가 아닌 항목은 버린다.
- 인자 방어(호출 0): find_group · find_user의 인자는 비지 않은 str이어야 한다(아니면 [] — `?uuid=None`을 보내 그 필드가 없는
  항목을 None == None으로 고르지 않는다) · patch_attributes의 attributes는 Mapping이어야 한다(아니면 False — dict()가 두 글자
  문자열의 목록을 사전으로 읽는다). 질의 값이 인코딩되지 않으면(lone surrogate) outbound.build_url의 invalid_request다.

메서드(반환)
- find_group(name) → list[dict]: `GET /api/v3/core/groups/?name=<name>` 첫 쪽에서 name이 정확히 같은 그룹(D19 3 — 「정확히 1」은
  호출자가 본다) · name이 비지 않은 str이 아니면 [](호출 0).
- find_user(uuid) → list[dict]: `GET /api/v3/core/users/?uuid=<uuid>` 첫 쪽에서 uuid가 정확히 같은 사용자(D16 3 · D19 5 — pk 정수 ·
  username 꼴은 호출자가 본다) · uuid가 비지 않은 str이 아니면 [](호출 0).
- get_user(pk) → dict | None: `GET /api/v3/core/users/<pk>/` — 404면 None · pk 꼴이 아니면 None(호출 0)(D17 5).
- add_user(group_pk, user_pk) → bool: `POST /api/v3/core/groups/<group_pk>/add_user/` 본문 `{"pk": user_pk}` — 2xx면
  True · 꼴이 아니면 False(호출 0 — 호출자가 실패로 다룬다)(D19 6).
- patch_attributes(pk, attributes) → bool: `PATCH /api/v3/core/users/<pk>/` 본문 `{"attributes": <사전 전체>}` — Authentik은
  attributes를 통째로 바꾼다(기존 키를 지키려면 호출자가 읽은 사전 전체를 준다) · 2xx면 True · pk 꼴이 아니거나 attributes가
  Mapping이 아니면 False(호출 0)(D19 6).
- list_sessions(user_pk, username) → Listing: `GET /api/v3/core/authenticated_sessions/?user__username=<username>&
  page_size=100&page=<n>` — items = 응답 user == user_pk인 세션(받은 차례 · 모든 쪽) · pages = 실제로 받은 쪽 수 · user_pk 꼴이
  아니거나 username이 빈 문자열 · str이 아니면 Listing([], 0, False)(호출 0)(D16 4).
- delete_session(uuid) → "deleted" | "gone" | "skipped": `DELETE /api/v3/core/authenticated_sessions/<uuid>/` — 2xx(204)
  = deleted · 404 = gone(남의 세션 · 삭제 권한 없음도 404다 — 사실 ⑭ · 둘을 한 수로 세지 않는다 · D16 5 · 〔W30〕) · uuid 꼴이
  아니면 skipped(호출 0) · 그 밖의 상태는 UpstreamStatus.
- logout_event_pages() → Iterator[Listing]: `GET /api/v3/events/events/?actions=logout&ordering=-created&page_size=100&
  page=<n>`를 쪽마다 하나씩 — Listing(items = 그 쪽의 이벤트 전부(받은 차례 · 거르지 않는다 — action · created · user · pk의
  재확인은 호출자 몫이다 · D17 3) · pages = 그 쪽 번호 · truncated = 상한 쪽인데 next가 0이 아니다). 제너레이터라 첫 next()에서
  첫 요청이 나간다(마감 0 s면 첫 next()가 deadline · 요청 0).
Listing(items, pages, truncated) — list_sessions는 목록 전체(pages = 실제로 받은 쪽 수) · logout_event_pages는 한 쪽(pages = 그
쪽 번호)이다.

import 시점에 객체 · 연결 · 설정 읽기가 없다. 로그를 내지 않는다(설계 D25).
"""

from __future__ import annotations

import re
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass
from http import HTTPStatus
from typing import Any

from django.conf import settings

from identity_admin import outbound

__all__ = [
    "DELETED",
    "EVENT_PAGE_LIMIT",
    "GONE",
    "PAGE_SIZE",
    "SESSION_PAGE_LIMIT",
    "SKIPPED",
    "Listing",
    "add_user",
    "delete_session",
    "find_group",
    "find_user",
    "get_user",
    "list_sessions",
    "logout_event_pages",
    "patch_attributes",
    "valid_pk",
    "valid_uuid",
]

SESSION_PAGE_LIMIT = 10  # 세션 목록 쪽 상한(설계 D16 4 · D26 — 쓰는 자리에서 모듈 속성으로 읽는다)
EVENT_PAGE_LIMIT = 50  # logout 이벤트 쪽 상한(설계 D17 2 · D26)
PAGE_SIZE = 100  # 목록 질의의 page_size(설계 D16 4 · D17 2)
DELETED, GONE, SKIPPED = "deleted", "gone", "skipped"  # delete_session의 반환
_UUID_RE = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
_PK_LIMIT = 2**63  # 사용자 pk는 이 값 미만(outbound.build_url의 int 경로 성분 상한과 같다 — 조각 ⑤-b V1)


@dataclass(frozen=True)
class Listing:
    """쪽 매김 목록의 반환 — items(받은 차례) · pages · truncated(상한 쪽에서도 next가 0이 아니었다). list_sessions는 목록 전체
    (pages = 실제로 받은 쪽 수) · logout_event_pages는 한 쪽(pages = 그 쪽 번호)이다."""

    items: list[dict[str, Any]]
    pages: int
    truncated: bool


def valid_pk(value: object) -> bool:
    """Authentik 정수 pk(1 이상 2**63 미만 · bool 제외)인가 — 경로 성분 · 세션 user 비교에 쓴다. 상한은 outbound.build_url이
    받는 int 경로 성분의 상한과 같다(넘는 값은 「꼴 아님」 — 호출 0 · invalid_request로 올라오지 않는다)."""
    return isinstance(value, int) and not isinstance(value, bool) and 1 <= value < _PK_LIMIT


def valid_uuid(value: object) -> bool:
    """UUID 8-4-4-4-12 꼴 문자열(대소문자 무관)인가 — 그룹 pk · 세션 uuid 경로 성분."""
    return isinstance(value, str) and _UUID_RE.fullmatch(value) is not None


def _url(*segments: object, query: Mapping[str, str | int] | None = None) -> str:
    """호출 때의 AUTHENTIK_API_URL + `/api/v3/<segments>/`(+ 질의) — 성분 글자는 outbound.build_url이 다시 본다."""
    return outbound.build_url(settings.AUTHENTIK_API_URL, ("api", "v3", *segments), query=query)


def _call(
    method: str, url: str, *, token: str | None, deadline: outbound.Deadline | None, body: Any = None
) -> Any:
    """outbound.request_json 한 번 — token이 None이면 호출 때의 설정 토큰."""
    bearer = settings.AUTHENTIK_API_TOKEN if token is None else token
    return outbound.request_json(method, url, token=bearer, body=body, deadline=deadline)


def _results(payload: Any, *, limit: int | None = None) -> list[dict[str, Any]]:
    """목록 응답의 results(dict 항목만) — 본문이 dict가 아니거나 results가 list가 아니거나 limit(쪽 매김 목록의 PAGE_SIZE)을
    넘으면 malformed."""
    if not isinstance(payload, dict) or not isinstance(payload.get("results"), list):
        raise outbound.UpstreamUnavailable(outbound.MALFORMED) from None
    if limit is not None and len(payload["results"]) > limit:
        raise outbound.UpstreamUnavailable(outbound.MALFORMED) from None
    return [item for item in payload["results"] if isinstance(item, dict)]


def _has_next(payload: dict[str, Any]) -> bool:
    """쪽 매김 목록에 다음 쪽이 있는가 — pagination.next가 0 이상 정수(bool 제외)가 아니면 malformed · 값은 URL로 쓰지 않는다."""
    pagination = payload.get("pagination")
    following = pagination.get("next") if isinstance(pagination, dict) else None
    if not isinstance(following, int) or isinstance(following, bool) or following < 0:
        raise outbound.UpstreamUnavailable(outbound.MALFORMED) from None
    return following != 0


def _page(
    segments: tuple[str, ...],
    query: Mapping[str, str],
    page: int,
    *,
    token: str | None,
    deadline: outbound.Deadline | None,
) -> tuple[list[dict[str, Any]], bool] | None:
    """쪽 매김 목록의 한 쪽(page_size 100 · page = 직접 센 쪽 번호) → (dict 항목, 다음 쪽이 있는가) · 2쪽 이후의 404는 None(목록의
    끝 — 쪽 사이에 목록이 줄었다). 1쪽의 404와 그 밖의 실패는 그대로 올라온다."""
    url = _url(*segments, query={**query, "page_size": PAGE_SIZE, "page": page})
    ended = False
    payload: Any = None
    try:
        payload = _call("GET", url, token=token, deadline=deadline)
    except outbound.UpstreamStatus as exc:
        if page == 1 or exc.status != HTTPStatus.NOT_FOUND:
            raise
        ended = True
    if ended:
        return None
    results = _results(payload, limit=PAGE_SIZE)
    return results, _has_next(payload)


def _collect(
    segments: tuple[str, ...],
    query: Mapping[str, str],
    limit: int,
    keep: Callable[[dict[str, Any]], bool],
    *,
    token: str | None,
    deadline: outbound.Deadline | None,
) -> Listing:
    """쪽을 1부터 limit쪽까지 다 모은다 — next가 0이거나 2쪽 이후가 404면 멈추고(truncated 거짓), limit쪽에서도 남아 있으면
    truncated. pages = 실제로 받은 쪽 수."""
    items: list[dict[str, Any]] = []
    for page in range(1, limit + 1):
        fetched = _page(segments, query, page, token=token, deadline=deadline)
        if fetched is None:
            return Listing(items, page - 1, False)
        results, more = fetched
        items.extend(item for item in results if keep(item))
        if not more:
            return Listing(items, page, False)
    return Listing(items, limit, True)


def find_group(
    name: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> list[dict[str, Any]]:
    """이름이 정확히 name인 그룹(첫 쪽) · name이 비지 않은 str이 아니면 [](호출 0) — 모듈 독스트링 「메서드」."""
    if not isinstance(name, str) or not name:
        return []
    payload = _call("GET", _url("core", "groups", query={"name": name}), token=token, deadline=deadline)
    return [item for item in _results(payload) if item.get("name") == name]


def find_user(
    uuid: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> list[dict[str, Any]]:
    """uuid가 정확히 같은 사용자(첫 쪽) · uuid가 비지 않은 str이 아니면 [](호출 0) — 모듈 독스트링 「메서드」."""
    if not isinstance(uuid, str) or not uuid:
        return []
    payload = _call("GET", _url("core", "users", query={"uuid": uuid}), token=token, deadline=deadline)
    return [item for item in _results(payload) if item.get("uuid") == uuid]


def get_user(
    pk: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> dict[str, Any] | None:
    """사용자 단건 — 404 · pk 꼴이 아니면(호출 0) None."""
    if not valid_pk(pk):
        return None
    missing = False
    payload: Any = None
    try:
        payload = _call("GET", _url("core", "users", pk), token=token, deadline=deadline)
    except outbound.UpstreamStatus as exc:
        if exc.status != HTTPStatus.NOT_FOUND:
            raise
        missing = True
    if missing:
        return None
    if not isinstance(payload, dict):
        raise outbound.UpstreamUnavailable(outbound.MALFORMED) from None
    return payload


def add_user(
    group_pk: object, user_pk: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> bool:
    """그룹 소속 추가 — 2xx면 True · 그룹 pk(UUID) · 사용자 pk(정수) 꼴이 아니면 False(호출 0)."""
    if not valid_uuid(group_pk) or not valid_pk(user_pk):
        return False
    _call("POST", _url("core", "groups", group_pk, "add_user"), token=token, deadline=deadline, body={"pk": user_pk})
    return True


def patch_attributes(
    pk: object,
    attributes: object,
    *,
    deadline: outbound.Deadline | None = None,
    token: str | None = None,
) -> bool:
    """사용자 attributes 통째 교체(PATCH) — 2xx면 True · pk 꼴이 아니거나 attributes가 Mapping이 아니면 False(호출 0)."""
    if not valid_pk(pk) or not isinstance(attributes, Mapping):
        return False
    body = {"attributes": dict(attributes)}
    _call("PATCH", _url("core", "users", pk), token=token, deadline=deadline, body=body)
    return True


def list_sessions(
    user_pk: object, username: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> Listing:
    """user_pk의 인증 세션(username 필터 + 응답 user == user_pk 재확인 · 쪽 상한 SESSION_PAGE_LIMIT)."""
    if not valid_pk(user_pk) or not isinstance(username, str) or not username:
        return Listing([], 0, False)

    def owned(item: dict[str, Any]) -> bool:
        user = item.get("user")
        return valid_pk(user) and user == user_pk

    query = {"user__username": username}
    return _collect(
        ("core", "authenticated_sessions"), query, SESSION_PAGE_LIMIT, owned, token=token, deadline=deadline
    )


def delete_session(
    uuid: object, *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> str:
    """세션 단건 삭제 — 2xx = DELETED · 404 = GONE · uuid 꼴이 아니면 SKIPPED(호출 0) · 그 밖은 UpstreamStatus."""
    if not valid_uuid(uuid):
        return SKIPPED
    gone = False
    try:
        _call("DELETE", _url("core", "authenticated_sessions", uuid), token=token, deadline=deadline)
    except outbound.UpstreamStatus as exc:
        if exc.status != HTTPStatus.NOT_FOUND:
            raise
        gone = True
    return GONE if gone else DELETED


def logout_event_pages(
    *, deadline: outbound.Deadline | None = None, token: str | None = None
) -> Iterator[Listing]:
    """logout 이벤트를 쪽마다 내준다(최신 먼저 · 쪽 상한 EVENT_PAGE_LIMIT · 거르지 않는다 — 재확인은 호출자) — Listing(그 쪽의
    이벤트 · 그 쪽 번호 · 상한 쪽인데 next ≠ 0). 실패는 그 쪽의 next()에서 올라온다(앞 쪽은 이미 내줬다) · 2쪽 이후의 404는 끝."""
    query = {"actions": "logout", "ordering": "-created"}
    limit = EVENT_PAGE_LIMIT
    for page in range(1, limit + 1):
        fetched = _page(("events", "events"), query, page, token=token, deadline=deadline)
        if fetched is None:
            return
        results, more = fetched
        yield Listing(results, page, more and page == limit)
        if not more:
            return
