"""identity-admin 시험용 가짜 외부 서버 · 가드(T066 · D5) — tests/test_api.py와 tests/test_identity_fakes.py가 같이 쓴다.

- FakeAuthentik: Authentik 관리 API(`/api/v3/core/…`)의 시드가 쓰는 표면만 흉내 낸다 — 그룹 이름 조회 · add_user · 사용자
  uuid 조회 · 단건 조회 · PATCH(attributes 통째 교체). 그룹을 만드는 엔드포인트는 없다(그룹 껍데기는 blueprint의 몫 —
  data-model §1). `Authorization`이 정확히 `Bearer <token>`이 아니면 403이다 · 본문이 있는 POST · PATCH · PUT은
  `application/json`만 받는다(그 밖은 415 · DRF JSONParser 꼴).
- FakeOpenFga: OpenFGA HTTP API의 write · read · check(store 하나 · preshared 키 Bearer). 중복 튜플 쓰기는 요청 전체를
  400 `write_failed_due_to_invalid_input`으로 거부하고 아무것도 쓰지 않는다(요청 단위 원자성) · `on_duplicate: "ignore"`면
  새 튜플만 쓴다 · check는 `owner ⊂ member`(data-model §10)를 따른다 · Content-Type은 보지 않는다.
- public_dns_guard(): socket 이름 조회 함수 넷(`getaddrinfo` · `gethostbyname` · `gethostbyname_ex` ·
  `gethostbyaddr`)을 감싸 공개 도메인(`joshuatech.dev` · 그 하위) 이름 조회를 기록하고 `socket.gaierror`로 막는다(pod는
  공개 호스트를 부르지 않는다 — FR-046). 나오면 넷 모두 원래 함수로 되돌린다.
- closed_port(): 연결을 받지 않는 127.0.0.1 포트 번호 · blackhole(): 연결은 받되(커널 backlog) 응답하지 않는 포트.

충실도(VD-T066-1·2 — T081 · T082 · T083 실측 전 가정 · build-notes 「T066」 D5): API 모양은 data-model §1 시드 파생 쓰기
규칙 그대로다. 실측이 어긋나면 이 파일과 data-model §1을 함께 고친다. 가짜는 모르는 경로 · 본문 필드를 거부한다(404 · 400)
— 계약 밖 호출이 시험에서 드러나게. 단 목록 GET의 질의 매개변수는 실제 Authentik(django-filter)처럼 모르는 키를 무시하고
거르지 않은 목록을 준다 — 가짜가 아는 질의 키는 계약 조회의 groups `name` · users `uuid`뿐이다(data-model §1 · `search` 같은
실제 Authentik의 다른 필터도 가짜에게는 모르는 키다). 시험은 정답보다 앞에 미끼(superuser 그룹 · 관리자 사용자)를 두므로
필터를 빠뜨리고 첫 결과를 쓰는 구현은 미끼를 고른다(tests/test_api.py `_seed_fakes`).

서버는 127.0.0.1 임시 포트의 ThreadingHTTPServer(데몬 요청 스레드)를 데몬 스레드 하나로 돌린다 · close()가 shutdown() ·
server_close() · 스레드 join으로 닫는다. 상태와 요청 기록은 잠금 아래 둔다(요청 스레드와 시험 스레드가 같이 읽는다).
Django를 import하지 않는다(표준 라이브러리 + tests._secret만 — tests/test_identity_fakes.py는 `-p no:django`로 돈다).
"""

from __future__ import annotations

import copy
import json
import re
import secrets
import socket
import threading
import uuid
from collections.abc import Callable, Iterable, Iterator, Mapping
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import parse_qs, urlsplit

from tests._secret import Secret

PUBLIC_SUFFIX = "joshuatech.dev"
# public_dns_guard가 감싸는 socket 이름 조회 함수(gethostbyname 계열은 getaddrinfo 속성을 거치지 않는다 — r3 K35).
GUARDED_RESOLVERS = ("getaddrinfo", "gethostbyname", "gethostbyname_ex", "gethostbyaddr")
MUTATING_METHODS = frozenset({"POST", "PATCH", "PUT", "DELETE"})
BODY_METHODS = frozenset({"POST", "PATCH", "PUT"})  # 본문을 파싱하는 메서드(Authentik Content-Type 검사 대상)
JSON_MEDIA_TYPE = "application/json"
AUTHENTIK_API = "/api/v3/core"
_ADD_USER = re.compile(r"/api/v3/core/groups/(?P<pk>[^/]+)/add_user/")
_USER_DETAIL = re.compile(r"/api/v3/core/users/(?P<pk>[0-9]+)/")
_FGA_ROUTE = re.compile(r"/stores/(?P<store>[^/]+)/(?P<action>write|read|check)")
_CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
_TUPLE_FIELDS = ("user", "relation", "object")

type Reply = tuple[int, Any]
type TupleKey = tuple[str, str, str]


@dataclass(frozen=True)
class FakeRequest:
    """가짜 서버가 받은 요청 하나 — 메서드 · 경로(쿼리 제외) · 쿼리(parse_qs) · 인증 여부 · 본문(JSON이면 값 · 아니면 None).

    인증 헤더 값은 기록하지 않는다(비밀).
    """

    method: str
    path: str
    query: dict[str, list[str]]
    authorized: bool
    body: Any = field(default=None)


def _parse_json(raw: bytes) -> tuple[Any, bool]:
    """본문 바이트 → (값, 성공 여부). 빈 본문은 (None, True)다."""
    if not raw:
        return None, True
    try:
        return json.loads(raw), True
    except ValueError:
        return None, False


def _make_handler(fake: _JsonServer) -> type[BaseHTTPRequestHandler]:
    """모든 메서드를 fake._handle로 넘기는 요청 처리기(응답은 JSON · 204는 본문 없음)."""

    class Handler(BaseHTTPRequestHandler):
        def _serve(self) -> None:
            parts = urlsplit(self.path)
            try:
                length = int(self.headers.get("Content-Length") or 0)
            except ValueError:
                length = -1
            raw = self.rfile.read(length) if length > 0 else b""
            if length < 0:
                status, payload = HTTPStatus.BAD_REQUEST, {"detail": "invalid Content-Length"}
            else:
                query = parse_qs(parts.query, keep_blank_values=True)
                status, payload = fake._handle(
                    self.command,
                    parts.path,
                    query,
                    self.headers.get("Authorization"),
                    raw,
                    self.headers.get("Content-Type"),
                )
            if status == HTTPStatus.NO_CONTENT:
                self.send_response(status)
                self.end_headers()
                return
            body = json.dumps(payload).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        # 메서드 이름은 BaseHTTPRequestHandler 규약(do_<METHOD>)이다.
        do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _serve

        def log_message(self, format: str, *args: Any) -> None:  # 인자 이름 format은 부모 시그니처 그대로다
            """요청 로그를 끈다(기본 구현은 요청마다 stderr에 한 줄을 쓴다)."""

    return Handler


class _JsonServer:
    """127.0.0.1 임시 포트의 ThreadingHTTPServer + 데몬 스레드 1 — 두 가짜 서버의 공통 뼈대(요청 기록 포함)."""

    def __init__(self, name: str) -> None:
        self._lock = threading.Lock()
        self._requests: list[FakeRequest] = []
        self._server = ThreadingHTTPServer(("127.0.0.1", 0), _make_handler(self))
        self._server.daemon_threads = True
        # poll_interval 0.05 s: shutdown()은 serve_forever 루프가 다음 poll에서 멈출 때까지 기다린다(기본 0.5 s).
        self._thread = threading.Thread(
            target=self._server.serve_forever, kwargs={"poll_interval": 0.05}, name=name, daemon=True
        )
        self._thread.start()
        self.base_url = f"http://127.0.0.1:{self._server.server_address[1]}"
        self._closed = False

    @property
    def port(self) -> int:
        port: int = self._server.server_address[1]
        return port

    @property
    def thread_alive(self) -> bool:
        return self._thread.is_alive()

    def close(self) -> None:
        """서버를 닫는다(shutdown → server_close → 스레드 join · 두 번 불러도 된다)."""
        if self._closed:
            return
        self._closed = True
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)

    @property
    def requests(self) -> list[FakeRequest]:
        """지금까지 받은 요청 기록(사본)."""
        with self._lock:
            return list(self._requests)

    def mutations(self) -> list[FakeRequest]:
        """변경 메서드(POST · PATCH · PUT · DELETE) 요청 기록만."""
        return [request for request in self.requests if request.method in MUTATING_METHODS]

    def _handle(
        self,
        method: str,
        path: str,
        query: dict[str, list[str]],
        authorization: str | None,
        raw: bytes,
        content_type: str | None = None,
    ) -> Reply:
        """요청 하나 — 기록(인증 · 미디어 타입과 무관하게) → 인증 → 미디어 타입 → 경로 처리."""
        body, parsed = _parse_json(raw)
        authorized = self._authorized(authorization)
        with self._lock:
            self._requests.append(FakeRequest(method, path, query, authorized, body if parsed else None))
            if not authorized:
                return self._unauthorized()
            refused = self._refuse_media(method, raw, content_type)
            if refused is not None:
                return refused
            try:
                return self._route(method, path, query, body, parsed)
            except Exception as exc:  # noqa: BLE001 — 가짜의 버그가 요청 스레드 트레이스백(stderr)으로 새지 않게 응답으로 바꾼다
                return HTTPStatus.INTERNAL_SERVER_ERROR, {"detail": f"fake internal error: {type(exc).__name__}"}

    def _authorized(self, authorization: str | None) -> bool:
        raise NotImplementedError

    def _unauthorized(self) -> Reply:
        raise NotImplementedError

    def _refuse_media(self, method: str, raw: bytes, content_type: str | None) -> Reply | None:
        """본문 미디어 타입 거부 응답(받으면 None) — 기본은 Content-Type을 보지 않는다(FakeOpenFga)."""
        return None

    def _route(self, method: str, path: str, query: dict[str, list[str]], body: Any, parsed: bool) -> Reply:
        raise NotImplementedError


# --- Authentik 관리 API -----------------------------------------------------------------------------------------------


def _page(results: list[dict[str, Any]]) -> dict[str, Any]:
    """Authentik 목록 응답 모양 `{"pagination": {...}, "results": [...]}`(한 쪽짜리)."""
    count = len(results)
    pagination = {
        "next": 0,
        "previous": 0,
        "count": count,
        "current": 1,
        "total_pages": 1,
        "start_index": 1 if count else 0,
        "end_index": count,
    }
    return {"pagination": pagination, "results": results}


def _as_user_pk(value: Any) -> int | None:
    """add_user 본문 pk — 정수(bool 제외) 또는 숫자만인 문자열(DRF IntegerField처럼)만 받는다."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and value.isdigit():
        return int(value)
    return None


class FakeAuthentik(_JsonServer):
    """가짜 Authentik 관리 API(seed_tenant가 쓰는 표면 — data-model §1 파생 쓰기 규칙).

    - `GET /api/v3/core/groups/?name=<이름>` → 이름이 정확히 같은 그룹 목록(`pk` uuid 문자열 · `name` · `is_superuser` ·
      `users` 정수 pk) · `name`이 없으면(모르는 질의 키만 있어도) 전부를 넣은 순서로.
    - `POST /api/v3/core/groups/<pk>/add_user/` 본문 `{"pk": <정수>}` → 204(이미 소속이어도 204) · 그룹·사용자 없으면 404 ·
      본문 형식 오류 400.
    - `GET /api/v3/core/users/?uuid=<uuid>` → uuid가 같은 사용자 목록(`uuid`가 없으면 전부) · `GET /api/v3/core/users/<pk>/`
      → 사용자 · 없으면 404.
    - `PATCH /api/v3/core/users/<pk>/` 본문 `{"attributes": {...}}` → attributes를 **통째로 바꾼다**(병합하지 않는다 — 기존
      키를 지키려면 호출자가 읽은 사전 전체를 보내야 한다) · attributes 밖의 필드는 400.
    - 본문이 있는 POST · PATCH · PUT의 미디어 타입(`;` 앞 · 소문자)이 `application/json`이 아니면 415
      `{"detail": 'Unsupported media type "<타입>" in request.'}`(요청은 기록 · 상태 불변 — DRF JSONParser 꼴 · urllib은
      Content-Type을 주지 않으면 form 타입을 붙인다 · VD-T066-1).
    - 그 밖의 경로(그룹 생성 `POST /api/v3/core/groups/` 포함 · 끝 슬래시 없는 경로)는 404.
    """

    def __init__(self) -> None:
        self.token = Secret(secrets.token_urlsafe(24))
        self._groups: dict[str, dict[str, Any]] = {}
        self._users: dict[int, dict[str, Any]] = {}
        super().__init__("fake-authentik")

    def reset(self, *, groups: Iterable[Mapping[str, Any]] = (), users: Iterable[Mapping[str, Any]] = ()) -> None:
        """상태를 바꾸고 요청 기록을 비운다.

        groups: `{"name": 이름, "users": [정수 pk…], "pk"?: uuid 문자열, "is_superuser"?: bool(기본 False)}` · users:
        `{"pk": 정수, "uuid": 문자열, "username"?: 문자열, "attributes"?: 사전}`.
        """
        with self._lock:
            self._groups = {}
            for index, group in enumerate(groups, start=1):
                pk = str(group.get("pk") or uuid.uuid4())
                self._groups[pk] = {
                    "pk": pk,
                    "num_pk": 1000 + index,
                    "name": str(group["name"]),
                    "is_superuser": bool(group.get("is_superuser", False)),
                    "users": {int(member) for member in group.get("users", ())},
                }
            self._users = {}
            for user in users:
                pk = int(user["pk"])
                self._users[pk] = {
                    "pk": pk,
                    "uuid": str(user["uuid"]),
                    "username": str(user.get("username", f"user-{pk}")),
                    "attributes": copy.deepcopy(dict(user.get("attributes", {}))),
                }
            self._requests.clear()

    def group_users(self, name: str) -> set[int]:
        """이름이 name인 그룹의 소속 사용자 pk 집합(그룹이 없으면 KeyError)."""
        with self._lock:
            for group in self._groups.values():
                if group["name"] == name:
                    return set(group["users"])
        raise KeyError(name)

    def group_names(self) -> set[str]:
        """지금 있는 그룹 이름 집합."""
        with self._lock:
            return {group["name"] for group in self._groups.values()}

    def user(self, pk: int) -> dict[str, Any]:
        """사용자 pk의 API 표현(사본 · 없으면 KeyError)."""
        with self._lock:
            return self._user_json(self._users[pk])

    def _authorized(self, authorization: str | None) -> bool:
        return authorization == f"Bearer {self.token}"

    def _unauthorized(self) -> Reply:
        return HTTPStatus.FORBIDDEN, {"detail": "Authentication credentials were not provided."}

    def _refuse_media(self, method: str, raw: bytes, content_type: str | None) -> Reply | None:
        """본문이 있는 POST · PATCH · PUT은 미디어 타입이 application/json일 때만 받는다(매개변수 무시 · 아니면 415)."""
        if method not in BODY_METHODS or not raw:
            return None
        media = (content_type or "").split(";", 1)[0].strip().lower()
        if media == JSON_MEDIA_TYPE:
            return None
        return HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {"detail": f'Unsupported media type "{media}" in request.'}

    def _group_json(self, group: dict[str, Any]) -> dict[str, Any]:
        return {
            "pk": group["pk"],
            "num_pk": group["num_pk"],
            "name": group["name"],
            "is_superuser": group["is_superuser"],
            "parent": None,
            "users": sorted(group["users"]),
            "attributes": {},
        }

    def _user_json(self, user: dict[str, Any]) -> dict[str, Any]:
        member_of = sorted(pk for pk, group in self._groups.items() if user["pk"] in group["users"])
        return {
            "pk": user["pk"],
            "uuid": user["uuid"],
            "username": user["username"],
            "name": user["username"],
            "is_active": True,
            "attributes": copy.deepcopy(user["attributes"]),
            "groups": member_of,
        }

    def _route(self, method: str, path: str, query: dict[str, list[str]], body: Any, parsed: bool) -> Reply:
        not_found: Reply = (HTTPStatus.NOT_FOUND, {"detail": "Not found."})
        if method == "GET" and path == f"{AUTHENTIK_API}/groups/":
            names = query.get("name")
            groups = [g for g in self._groups.values() if names is None or g["name"] == names[0]]
            return HTTPStatus.OK, _page([self._group_json(g) for g in groups])
        if method == "POST" and (match := _ADD_USER.fullmatch(path)):
            group = self._groups.get(match["pk"])
            if group is None:
                return not_found
            user_pk = _as_user_pk(body.get("pk")) if parsed and isinstance(body, dict) else None
            if user_pk is None:
                return HTTPStatus.BAD_REQUEST, {"pk": ["A valid integer is required."]}
            if user_pk not in self._users:
                return not_found
            group["users"].add(user_pk)
            return HTTPStatus.NO_CONTENT, None
        if method == "GET" and path == f"{AUTHENTIK_API}/users/":
            uuids = query.get("uuid")
            users = [u for u in self._users.values() if uuids is None or u["uuid"] == uuids[0]]
            return HTTPStatus.OK, _page([self._user_json(u) for u in users])
        if (match := _USER_DETAIL.fullmatch(path)) and method in {"GET", "PATCH"}:
            user = self._users.get(int(match["pk"]))
            if user is None:
                return not_found
            if method == "PATCH":
                if not parsed or not isinstance(body, dict) or set(body) - {"attributes"}:
                    return HTTPStatus.BAD_REQUEST, {"detail": "fake supports PATCH of attributes only"}
                if "attributes" in body:
                    if not isinstance(body["attributes"], dict):
                        return HTTPStatus.BAD_REQUEST, {"attributes": ["Value must be valid JSON object."]}
                    user["attributes"] = copy.deepcopy(body["attributes"])
            return HTTPStatus.OK, self._user_json(user)
        return not_found


# --- OpenFGA HTTP API -----------------------------------------------------------------------------------------------


def _fga_error(code: str, message: str) -> dict[str, str]:
    return {"code": code, "message": message}


def _tuple_key(value: Any) -> TupleKey | None:
    """튜플 키 사전 → (user, relation, object) — 세 값이 모두 비어 있지 않은 문자열이 아니면 None."""
    if not isinstance(value, dict):
        return None
    parts = [value.get(name) for name in _TUPLE_FIELDS]
    if not all(isinstance(part, str) and part for part in parts):
        return None
    return parts[0], parts[1], parts[2]


class FakeOpenFga(_JsonServer):
    """가짜 OpenFGA(store 하나 · `Authorization: Bearer <preshared 키>`).

    - 인증 실패 401 `{"code": "unauthenticated"}` · 다른 store 404 `{"code": "store_id_not_found"}` · 그 밖의 경로 404.
    - `POST /stores/<id>/write` 본문 `{"writes": {"tuple_keys": [...], "on_duplicate"?: "error"|"ignore"}}` → 200 `{}`.
      이미 있는 튜플이 하나라도 있으면(on_duplicate가 ignore가 아니면) 400 `write_failed_due_to_invalid_input`이고
      **아무것도 쓰지 않는다**(요청 단위 원자성). 형식 오류 · 한 요청 안 중복 · deletes는 400.
      `fail_next_write = (상태, 본문)`을 두면 다음 (형식이 맞는) 쓰기 한 번이 그 응답으로 실패한다(쓰지 않는다).
    - `POST /stores/<id>/read` 본문 `{"tuple_key": {...}}` → 준 필드가 같은 튜플(object가 `type:`로 끝나면 그 타입 전체).
    - `POST /stores/<id>/check` 본문 `{"tuple_key": {...}}` → `{"allowed": bool}` — member는 owner를 포함한다.
    - Content-Type은 보지 않는다 — OpenFGA HTTP API(grpc-gateway)는 모르는 Content-Type에 기본(와일드카드) JSON 마샬러를
      쓴다. 실제보다 엄격하게 만들어 정상 구현을 떨어뜨리지 않는다(VD-T066-2).
    """

    def __init__(self) -> None:
        self.store_id = "01" + "".join(secrets.choice(_CROCKFORD) for _ in range(24))
        self.key = Secret(secrets.token_urlsafe(24))
        self._tuples: dict[TupleKey, str] = {}
        self._fail_next_write: Reply | None = None
        super().__init__("fake-openfga")

    def reset(self, *, tuples: Iterable[TupleKey] = ()) -> None:
        """튜플을 바꾸고 요청 기록 · 실패 주입을 비운다."""
        stamp = _now_iso()
        with self._lock:
            self._tuples = {(str(u), str(r), str(o)): stamp for u, r, o in tuples}
            self._fail_next_write = None
            self._requests.clear()

    @property
    def tuples(self) -> set[TupleKey]:
        """지금 있는 튜플 집합(user, relation, object)."""
        with self._lock:
            return set(self._tuples)

    @property
    def fail_next_write(self) -> Reply | None:
        with self._lock:
            return self._fail_next_write

    @fail_next_write.setter
    def fail_next_write(self, reply: Reply | None) -> None:
        with self._lock:
            self._fail_next_write = reply

    def _authorized(self, authorization: str | None) -> bool:
        return authorization == f"Bearer {self.key}"

    def _unauthorized(self) -> Reply:
        return HTTPStatus.UNAUTHORIZED, _fga_error("unauthenticated", "unauthenticated")

    def _route(self, method: str, path: str, query: dict[str, list[str]], body: Any, parsed: bool) -> Reply:
        match = _FGA_ROUTE.fullmatch(path)
        if match is None or method != "POST":
            return HTTPStatus.NOT_FOUND, _fga_error("undefined_endpoint", "Not Found")
        if match["store"] != self.store_id:
            return HTTPStatus.NOT_FOUND, _fga_error("store_id_not_found", "store not found")
        if not parsed or not isinstance(body, dict):
            return HTTPStatus.BAD_REQUEST, _fga_error("validation_error", "invalid JSON body")
        if match["action"] == "write":
            return self._write(body)
        if match["action"] == "read":
            return self._read(body)
        return self._check(body)

    def _write(self, body: dict[str, Any]) -> Reply:
        invalid = HTTPStatus.BAD_REQUEST
        if body.get("deletes") not in (None, {}):
            return invalid, _fga_error("validation_error", "fake: deletes are not supported")
        writes = body.get("writes")
        keys = writes.get("tuple_keys") if isinstance(writes, dict) else None
        if not isinstance(keys, list) or not keys:
            return invalid, _fga_error("validation_error", "invalid WriteRequest.Writes: TupleKeys is required")
        on_duplicate = writes.get("on_duplicate", "error") if isinstance(writes, dict) else "error"
        if on_duplicate not in ("error", "ignore"):
            return invalid, _fga_error("validation_error", "invalid on_duplicate")
        parsed = [_tuple_key(key) for key in keys]
        if any(key is None for key in parsed):
            return invalid, _fga_error("validation_error", "invalid TupleKey: user, relation, object are required")
        wanted = [key for key in parsed if key is not None]
        if len(set(wanted)) != len(wanted):
            return invalid, _fga_error("cannot_allow_duplicate_tuples_in_one_request", "duplicate tuple in write")
        if self._fail_next_write is not None:
            reply, self._fail_next_write = self._fail_next_write, None
            return reply
        existing = [key for key in wanted if key in self._tuples]
        if existing and on_duplicate != "ignore":
            user, relation, obj = existing[0]
            message = (
                f"cannot write a tuple which already exists: user: '{user}', relation: '{relation}', object: '{obj}': "
                "tuple to be written already existed or the tuple to be deleted did not exist"
            )
            return invalid, _fga_error("write_failed_due_to_invalid_input", message)
        stamp = _now_iso()
        for key in wanted:
            self._tuples.setdefault(key, stamp)
        return HTTPStatus.OK, {}

    def _read(self, body: dict[str, Any]) -> Reply:
        wanted = body.get("tuple_key") or {}
        if not isinstance(wanted, dict):
            return HTTPStatus.BAD_REQUEST, _fga_error("validation_error", "invalid tuple_key")
        filters = {name: wanted[name] for name in _TUPLE_FIELDS if wanted.get(name)}
        if not all(isinstance(value, str) for value in filters.values()):
            return HTTPStatus.BAD_REQUEST, _fga_error("validation_error", "invalid tuple_key")
        found: list[dict[str, Any]] = []
        for (user, relation, obj), stamp in sorted(self._tuples.items()):
            if filters.get("user", user) != user or filters.get("relation", relation) != relation:
                continue
            target = filters.get("object")
            if target is not None and not (obj.startswith(target) if target.endswith(":") else obj == target):
                continue
            found.append({"key": {"user": user, "relation": relation, "object": obj}, "timestamp": stamp})
        return HTTPStatus.OK, {"tuples": found, "continuation_token": ""}

    def _check(self, body: dict[str, Any]) -> Reply:
        key = _tuple_key(body.get("tuple_key"))
        if key is None:
            return HTTPStatus.BAD_REQUEST, _fga_error("validation_error", "invalid CheckRequestTupleKey")
        user, relation, obj = key
        allowed = key in self._tuples or (relation == "member" and (user, "owner", obj) in self._tuples)
        return HTTPStatus.OK, {"allowed": allowed, "resolution": ""}


def _now_iso() -> str:
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


# --- 공개 DNS 가드 · 닫힌 포트 ----------------------------------------------------------------------------------------------


def _host_name(host: str | bytes | None) -> str | None:
    """getaddrinfo의 host 인자 → 비교용 이름(소문자 · 끝 점 제거). None이면 None."""
    if host is None:
        return None
    name = host.decode("ascii", errors="replace") if isinstance(host, bytes) else str(host)
    return name.strip().lower().rstrip(".")


def is_public_name(host: str | bytes | None, suffix: str = PUBLIC_SUFFIX) -> bool:
    """host가 suffix 자체이거나 그 하위 이름인가(대소문자 · 끝 점 무시 · 레이블 경계 — `notjoshuatech.dev`는 아니다)."""
    name = _host_name(host)
    base = suffix.strip().lower().strip(".")
    return bool(name) and (name == base or name.endswith("." + base))


@contextmanager
def public_dns_guard(suffix: str = PUBLIC_SUFFIX) -> Iterator[list[str]]:
    """socket 이름 조회 함수 넷(`getaddrinfo` · `gethostbyname` · `gethostbyname_ex` · `gethostbyaddr`)을 감싸 공개 도메인
    이름 조회를 기록하고 막는다(socket.gaierror) — 기록 목록을 준다.

    공개 이름이 아니면 원래 함수를 그대로 부른다(127.0.0.1 · localhost 등). 블록을 나오면(예외여도) 넷 모두 들어올 때의
    함수로 되돌린다. 프로세스 전역이다(모든 스레드의 이름 조회에 걸린다) — 같은 프로세스의 HTTP 클라이언트
    (urllib · requests · httpx · redis-py)가 모두 `socket.getaddrinfo`를 거치고, gethostbyname 계열은 getaddrinfo
    속성을 거치지 않고 C 수준에서 이름을 푸는 함수라 따로 감싼다. C 확장의 자체 이름 해석(libpq · librdkafka)은 보지
    못한다(시험의 DB · Kafka 주소는 127.0.0.1 리터럴이다). 프록시 경유 요청은 이름 조회가 프록시 이름으로 바뀌어 가드
    밖이다 — 시험이 프록시를 끈다(tests/test_api.py `dns_guard` 픽스처 · 기동 하위 프로세스는 그 env를 물려받는다).
    """
    attempts: list[str] = []
    lock = threading.Lock()
    originals: dict[str, Callable[..., Any]] = {name: getattr(socket, name) for name in GUARDED_RESOLVERS}

    def refuse_public(host: str | bytes | None) -> None:
        """host가 공개 이름이면 기록하고 socket.gaierror로 막는다(아니면 그냥 돌아간다)."""
        if is_public_name(host, suffix):
            name = _host_name(host) or ""
            with lock:
                attempts.append(name)
            raise socket.gaierror(socket.EAI_NONAME, f"시험 가드가 공개 호스트 이름 조회를 막았다: {name}")

    def getaddrinfo(
        host: str | bytes | None,
        port: str | bytes | int | None,
        family: int = 0,
        type: int = 0,  # noqa: A002 — socket.getaddrinfo 시그니처 그대로다
        proto: int = 0,
        flags: int = 0,
    ) -> list[Any]:
        refuse_public(host)
        result: list[Any] = originals["getaddrinfo"](host, port, family, type, proto, flags)
        return result

    def gethostbyname(hostname: str) -> str:
        refuse_public(hostname)
        address: str = originals["gethostbyname"](hostname)
        return address

    def gethostbyname_ex(hostname: str) -> tuple[str, list[str], list[str]]:
        refuse_public(hostname)
        found: tuple[str, list[str], list[str]] = originals["gethostbyname_ex"](hostname)
        return found

    def gethostbyaddr(ip_address: str) -> tuple[str, list[str], list[str]]:
        refuse_public(ip_address)
        found: tuple[str, list[str], list[str]] = originals["gethostbyaddr"](ip_address)
        return found

    wrappers: dict[str, Callable[..., Any]] = {
        "getaddrinfo": getaddrinfo,
        "gethostbyname": gethostbyname,
        "gethostbyname_ex": gethostbyname_ex,
        "gethostbyaddr": gethostbyaddr,
    }
    try:
        for name, wrapper in wrappers.items():
            setattr(socket, name, wrapper)
        yield attempts
    finally:
        for name, original in originals.items():
            setattr(socket, name, original)


def closed_port() -> int:
    """연결을 받지 않는 127.0.0.1 포트 — bind로 번호만 받고 닫는다(Windows는 RST 대신 연결 시간 초과로 끝난다)."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(("127.0.0.1", 0))
        port: int = probe.getsockname()[1]
    return port


@contextmanager
def blackhole(backlog: int = 64) -> Iterator[int]:
    """listen만 하고 accept하지 않는 127.0.0.1 임시 포트 — 포트 번호를 주고, 블록을 나오면 소켓을 닫는다.

    TCP 핸드셰이크는 커널 backlog에서 끝나므로(OS 무관) 클라이언트는 연결된 뒤 응답을 기다리다 자기 시간 초과로 끝난다
    (psycopg connect_timeout · redis-py socket_timeout · librdkafka 요청 시간 초과). 닫힌 포트(closed_port)는 Linux가 즉시
    RST로 거부해 의존 검사를 순차로 도는 /health도 3 s 안에 끝난다 — 닫힌 포트만으로는 병렬성을 가리지 못한다(api-52가
    이 함수를 쓴다 · api-3의 DB 다운은 닫힌 포트 그대로). backlog는 한 시험 안의 재연결 시도가 큐를 채우지 않을 만큼 둔다.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(backlog)
        port: int = listener.getsockname()[1]
        yield port
