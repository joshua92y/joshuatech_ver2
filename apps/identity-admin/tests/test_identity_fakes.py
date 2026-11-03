"""가짜 Authentik · 가짜 OpenFGA · 공개 DNS 가드 · 닫힌 포트 · 블랙홀 포트 자기검사(T066 · D5 — fake-1..26).

tests/_identity_fakes.py가 tests/test_api.py의 판정을 떠받치므로 가짜 자체의 동작을 먼저 고정한다: 인증 실패 모양 ·
조회 필터 · add_user 멱등 · PATCH 통째 교체 · 요청 기록 · 모르는 경로 404(그룹 생성 없음) · OpenFGA 중복 쓰기 원자 거부 ·
`on_duplicate: "ignore"` · owner ⊂ member · 실패 주입 1회 · 형식 오류 400 · DNS 가드의 차단·기록·복원 · 닫힌 포트 /
r2(fake-22..25): 블랙홀 포트(연결은 되고 응답은 없다) · 그룹 목록 질의(모르는 키는 무시 · 미끼 is_superuser) · Authentik
본문 Content-Type 415(OpenFGA는 받아 준다) / r3(fake-26): DNS 가드의 gethostbyname 계열(gethostbyname ·
gethostbyname_ex · gethostbyaddr)도 차단·기록·복원 · fake-18이 예외 경로에서 넷 모두 복원을 본다(r4).

Django 없이 돈다(`-p no:django` — 표준 라이브러리 urllib만 · 프록시 없는 opener). 서버는 테스트마다 새로 띄우고 닫는다
(tests/test_api.py의 세션 서버와 별개).
"""

from __future__ import annotations

import json
import socket
import urllib.error
import urllib.request
import uuid
from collections.abc import Iterator
from typing import Any

import pytest

from tests._identity_fakes import (
    FakeAuthentik,
    FakeOpenFga,
    blackhole,
    closed_port,
    is_public_name,
    public_dns_guard,
)

GROUPS = "/api/v3/core/groups/"
USERS = "/api/v3/core/users/"
TENANT = "00000000-0000-4000-8000-0000000000aa"
GROUP_NAME = f"tenant:{TENANT}"
OWNER_UUID = "11111111-1111-4111-8111-111111111111"
MEMBER_UUID = "22222222-2222-4222-8222-222222222222"
OWNER = ("user:owner-1", "owner", f"tenant:{TENANT}")
MEMBER = ("user:member-1", "member", f"tenant:{TENANT}")
FORM_TYPE = "application/x-www-form-urlencoded"  # urllib이 data가 있고 Content-Type이 없을 때 붙이는 기본 타입
# 프록시 없는 opener — Windows는 레지스트리 프록시 설정을 urllib 기본 opener가 읽는다(127.0.0.1 요청이 프록시로 새지 않게).
_OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def _call(
    method: str,
    url: str,
    *,
    token: str | None = None,
    body: Any = None,
    content_type: str = "application/json",
) -> tuple[int, Any]:
    """HTTP 요청 한 번 → (상태, JSON 본문 또는 None). body가 bytes면 그대로 보낸다(형식 오류 시험용) · 본문이 있으면
    Content-Type = content_type(기본 application/json — 다른 타입은 Content-Type 시험용)."""
    data = None if body is None else body if isinstance(body, bytes) else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, method=method)
    if token is not None:
        request.add_header("Authorization", f"Bearer {token}")
    if data is not None:
        request.add_header("Content-Type", content_type)
    try:
        with _OPENER.open(request, timeout=5) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
    return status, json.loads(raw) if raw else None


@pytest.fixture
def authentik() -> Iterator[FakeAuthentik]:
    """그룹 1(소속 없음) · 사용자 2(101 · 102)를 둔 가짜 Authentik(테스트마다 새로 띄운다)."""
    server = FakeAuthentik()
    server.reset(
        groups=[{"name": GROUP_NAME, "users": []}],
        users=[
            {"pk": 101, "uuid": OWNER_UUID, "username": "owner", "attributes": {"existing": "keep"}},
            {"pk": 102, "uuid": MEMBER_UUID, "username": "member"},
        ],
    )
    try:
        yield server
    finally:
        server.close()


@pytest.fixture
def openfga() -> Iterator[FakeOpenFga]:
    """빈 가짜 OpenFGA(테스트마다 새로 띄운다)."""
    server = FakeOpenFga()
    try:
        yield server
    finally:
        server.close()


def _group_pk(authentik: FakeAuthentik) -> str:
    status, body = _call("GET", f"{authentik.base_url}{GROUPS}?name={GROUP_NAME}", token=authentik.token)
    assert status == 200
    pk: str = body["results"][0]["pk"]
    return pk


def _fga(openfga: FakeOpenFga, action: str, body: Any, *, token: str | None = None) -> tuple[int, Any]:
    url = f"{openfga.base_url}/stores/{openfga.store_id}/{action}"
    return _call("POST", url, token=openfga.key if token is None else token, body=body)


def _writes(*keys: tuple[str, str, str], on_duplicate: str | None = None) -> dict[str, Any]:
    writes: dict[str, Any] = {"tuple_keys": [{"user": u, "relation": r, "object": o} for u, r, o in keys]}
    if on_duplicate is not None:
        writes["on_duplicate"] = on_duplicate
    return {"writes": writes}


# --- 가짜 Authentik ---------------------------------------------------------------------------------------------------


def test_fake_1_authentik_requires_bearer(authentik: FakeAuthentik) -> None:
    """fake-1 — Authorization이 정확히 `Bearer <token>`이 아니면 403 `{"detail": …}`(없음 · 다른 토큰 · Token 스킴) ·
    맞으면 200."""
    url = f"{authentik.base_url}{GROUPS}"
    for case, token in (("missing", None), ("other-token", "not-the-token")):
        status, body = _call("GET", url, token=token)
        assert status == 403, case
        assert isinstance(body.get("detail"), str), case
    request = urllib.request.Request(url, method="GET")
    request.add_header("Authorization", f"Token {authentik.token}")
    with pytest.raises(urllib.error.HTTPError) as excinfo:
        _OPENER.open(request, timeout=5)
    assert excinfo.value.code == 403
    excinfo.value.close()
    assert _call("GET", url, token=authentik.token)[0] == 200


def test_fake_2_authentik_group_lookup(authentik: FakeAuthentik) -> None:
    """fake-2 — `?name=` 정확 일치: 있는 이름 → count 1 · pk(uuid 문자열) · users [] / 없는 이름 → count 0 / 필터 없음 → 전부."""
    status, body = _call("GET", f"{authentik.base_url}{GROUPS}?name={GROUP_NAME}", token=authentik.token)
    assert status == 200
    assert body["pagination"]["count"] == 1
    (group,) = body["results"]
    assert (group["name"], group["users"]) == (GROUP_NAME, [])
    uuid.UUID(group["pk"])
    status, body = _call("GET", f"{authentik.base_url}{GROUPS}?name=tenant:other", token=authentik.token)
    assert (status, body["pagination"]["count"], body["results"]) == (200, 0, [])
    status, body = _call("GET", f"{authentik.base_url}{GROUPS}", token=authentik.token)
    assert (status, body["pagination"]["count"]) == (200, 1)


def test_fake_3_authentik_add_user_idempotent(authentik: FakeAuthentik) -> None:
    """fake-3 — add_user 두 번 → 204 · 204 · 소속 {101} 하나 · 사용자 표현의 groups에 그룹 pk."""
    pk = _group_pk(authentik)
    url = f"{authentik.base_url}{GROUPS}{pk}/add_user/"
    assert _call("POST", url, token=authentik.token, body={"pk": 101}) == (204, None)
    assert _call("POST", url, token=authentik.token, body={"pk": 101}) == (204, None)
    assert authentik.group_users(GROUP_NAME) == {101}
    assert authentik.user(101)["groups"] == [pk]


def test_fake_4_authentik_add_user_errors(authentik: FakeAuthentik) -> None:
    """fake-4 — 없는 그룹 · 없는 사용자 → 404 / 본문 pk 형식 오류(문자 · 누락 · bool · JSON 아님) → 400 / 상태 불변."""
    pk = _group_pk(authentik)
    token = authentik.token
    unknown_group = f"{authentik.base_url}{GROUPS}{uuid.uuid4()}/add_user/"
    assert _call("POST", unknown_group, token=token, body={"pk": 101})[0] == 404
    url = f"{authentik.base_url}{GROUPS}{pk}/add_user/"
    assert _call("POST", url, token=token, body={"pk": 999})[0] == 404
    for case, body in (("letters", {"pk": "x"}), ("missing", {}), ("bool", {"pk": True}), ("not-json", b"{not json")):
        assert _call("POST", url, token=token, body=body)[0] == 400, case
    assert authentik.group_users(GROUP_NAME) == set()


def test_fake_5_authentik_user_lookup(authentik: FakeAuthentik) -> None:
    """fake-5 — `?uuid=` → 그 사용자 하나(pk · uuid · attributes) / 없는 uuid → count 0 / 단건 GET 200 · 없는 pk 404."""
    status, body = _call("GET", f"{authentik.base_url}{USERS}?uuid={OWNER_UUID}", token=authentik.token)
    assert (status, body["pagination"]["count"]) == (200, 1)
    (user,) = body["results"]
    assert (user["pk"], user["uuid"], user["attributes"]) == (101, OWNER_UUID, {"existing": "keep"})
    status, body = _call("GET", f"{authentik.base_url}{USERS}?uuid={uuid.uuid4()}", token=authentik.token)
    assert (status, body["results"]) == (200, [])
    status, body = _call("GET", f"{authentik.base_url}{USERS}102/", token=authentik.token)
    assert (status, body["uuid"]) == (200, MEMBER_UUID)
    assert _call("GET", f"{authentik.base_url}{USERS}999/", token=authentik.token)[0] == 404


def test_fake_6_authentik_patch_replaces_attributes(authentik: FakeAuthentik) -> None:
    """fake-6 — PATCH `{"attributes": {...}}`는 attributes를 통째로 바꾼다(이전 키 사라짐) · attributes 밖 필드 · 사전이 아닌
    attributes → 400(상태 불변)."""
    url = f"{authentik.base_url}{USERS}101/"
    status, body = _call("PATCH", url, token=authentik.token, body={"attributes": {"tenant_id": TENANT}})
    assert (status, body["attributes"]) == (200, {"tenant_id": TENANT})
    assert authentik.user(101)["attributes"] == {"tenant_id": TENANT}
    for case, payload in (("other-field", {"username": "x"}), ("not-a-dict", {"attributes": ["x"]})):
        assert _call("PATCH", url, token=authentik.token, body=payload)[0] == 400, case
    assert authentik.user(101)["attributes"] == {"tenant_id": TENANT}
    assert authentik.user(101)["username"] == "owner"


def test_fake_7_authentik_request_log(authentik: FakeAuthentik) -> None:
    """fake-7 — 요청 기록: 메서드 · 경로(쿼리 제외) · 쿼리 dict · 인증 여부 · 본문 / mutations()는 변경 메서드만."""
    pk = _group_pk(authentik)
    _call("GET", f"{authentik.base_url}{USERS}?uuid={OWNER_UUID}")
    _call("POST", f"{authentik.base_url}{GROUPS}{pk}/add_user/", token=authentik.token, body={"pk": 102})
    _call("PATCH", f"{authentik.base_url}{USERS}102/", token=authentik.token, body={"attributes": {}})
    log = [(r.method, r.path, r.query, r.authorized) for r in authentik.requests]
    assert log == [
        ("GET", GROUPS, {"name": [GROUP_NAME]}, True),
        ("GET", USERS, {"uuid": [OWNER_UUID]}, False),
        ("POST", f"{GROUPS}{pk}/add_user/", {}, True),
        ("PATCH", f"{USERS}102/", {}, True),
    ]
    assert [(r.method, r.body) for r in authentik.mutations()] == [("POST", {"pk": 102}), ("PATCH", {"attributes": {}})]
    authentik.reset()
    assert authentik.requests == []


def test_fake_8_authentik_unknown_routes(authentik: FakeAuthentik) -> None:
    """fake-8 — 그룹 생성(`POST /api/v3/core/groups/`) · 끝 슬래시 없는 경로 · 사용자 DELETE → 404 · 그룹은 만들어지지
    않는다(기록에는 남는다)."""
    token = authentik.token
    assert _call("POST", f"{authentik.base_url}{GROUPS}", token=token, body={"name": "tenant:new"})[0] == 404
    assert _call("GET", f"{authentik.base_url}/api/v3/core/groups", token=token)[0] == 404
    assert _call("DELETE", f"{authentik.base_url}{USERS}101/", token=token)[0] == 404
    assert authentik.group_names() == {GROUP_NAME}
    assert [r.method for r in authentik.mutations()] == ["POST", "DELETE"]


# --- 가짜 OpenFGA -----------------------------------------------------------------------------------------------------


def test_fake_9_openfga_requires_preshared_key(openfga: FakeOpenFga) -> None:
    """fake-9 — Authorization 없음 · 다른 키 → 401 `{"code": "unauthenticated"}` · 맞는 키 → 200."""
    url = f"{openfga.base_url}/stores/{openfga.store_id}/read"
    for case, token in (("missing", None), ("other-key", "not-the-key")):
        status, body = _call("POST", url, token=token, body={"tuple_key": {}})
        assert (status, body["code"]) == (401, "unauthenticated"), case
    assert _fga(openfga, "read", {"tuple_key": {}})[0] == 200


def test_fake_10_openfga_write_read(openfga: FakeOpenFga) -> None:
    """fake-10 — write 2 → 200 `{}` · tuples 2 / read: object 일치 2 · user+relation 일치 1 · 타입 접두(`tenant:`) 2 ·
    결과 모양(key · timestamp · continuation_token)."""
    assert _fga(openfga, "write", _writes(OWNER, MEMBER)) == (200, {})
    assert openfga.tuples == {OWNER, MEMBER}
    status, body = _fga(openfga, "read", {"tuple_key": {"object": OWNER[2]}})
    assert (status, len(body["tuples"]), body["continuation_token"]) == (200, 2, "")
    status, body = _fga(openfga, "read", {"tuple_key": {"user": OWNER[0], "relation": "owner", "object": OWNER[2]}})
    (row,) = body["tuples"]
    assert row["key"] == {"user": OWNER[0], "relation": "owner", "object": OWNER[2]}
    assert isinstance(row["timestamp"], str) and row["timestamp"]
    status, body = _fga(openfga, "read", {"tuple_key": {"object": "tenant:"}})
    assert len(body["tuples"]) == 2


def test_fake_11_openfga_duplicate_rejected_atomically(openfga: FakeOpenFga) -> None:
    """fake-11 — 이미 있는 튜플이 섞인 쓰기([OWNER, MEMBER] · OWNER가 이미 있음) → 400 write_failed_due_to_invalid_input ·
    메시지 "already exists" · MEMBER도 쓰이지 않는다(요청 단위 원자성)."""
    assert _fga(openfga, "write", _writes(OWNER))[0] == 200
    status, body = _fga(openfga, "write", _writes(OWNER, MEMBER))
    assert (status, body["code"]) == (400, "write_failed_due_to_invalid_input")
    assert "already exists" in body["message"]
    assert openfga.tuples == {OWNER}


def test_fake_12_openfga_on_duplicate_ignore(openfga: FakeOpenFga) -> None:
    """fake-12 — `on_duplicate: "ignore"`면 이미 있는 튜플을 건너뛰고 새 튜플만 쓴다(200)."""
    assert _fga(openfga, "write", _writes(OWNER))[0] == 200
    assert _fga(openfga, "write", _writes(OWNER, MEMBER, on_duplicate="ignore")) == (200, {})
    assert openfga.tuples == {OWNER, MEMBER}


def test_fake_13_openfga_check_owner_implies_member(openfga: FakeOpenFga) -> None:
    """fake-13 — check: owner 튜플만 있어도 member check는 true(owner ⊂ member — data-model §10) · 다른 사용자 · 다른
    object는 false."""
    openfga.reset(tuples=[OWNER])
    user, _, obj = OWNER
    cases = (
        ((user, "owner", obj), True),
        ((user, "member", obj), True),
        (("user:other", "member", obj), False),
        ((user, "owner", "tenant:other"), False),
    )
    for (u, r, o), allowed in cases:
        status, body = _fga(openfga, "check", {"tuple_key": {"user": u, "relation": r, "object": o}})
        assert (status, body["allowed"]) == (200, allowed), (u, r, o)


def test_fake_14_openfga_fail_next_write_once(openfga: FakeOpenFga) -> None:
    """fake-14 — fail_next_write = (400, 본문) → 다음 쓰기 하나가 그 응답(쓰지 않음) · 그다음 쓰기는 성공."""
    injected = {"code": "validation_error", "message": "invalid tuple"}
    openfga.fail_next_write = (400, injected)
    assert _fga(openfga, "write", _writes(OWNER)) == (400, injected)
    assert openfga.tuples == set()
    assert openfga.fail_next_write is None
    assert _fga(openfga, "write", _writes(OWNER)) == (200, {})


def test_fake_15_openfga_other_store(openfga: FakeOpenFga) -> None:
    """fake-15 — 다른 store id → 404 store_id_not_found · 모르는 동작 → 404."""
    status, body = _call("POST", f"{openfga.base_url}/stores/01OTHER/read", token=openfga.key, body={"tuple_key": {}})
    assert (status, body["code"]) == (404, "store_id_not_found")
    status, _ = _call("POST", f"{openfga.base_url}/stores/{openfga.store_id}/expand", token=openfga.key, body={})
    assert status == 404


def test_fake_16_openfga_malformed_write(openfga: FakeOpenFga) -> None:
    """fake-16 — 형식 오류 쓰기는 400이고 아무것도 쓰지 않는다: writes 없음 · tuple_keys 빈 목록 · 빈 문자열 필드 · 사전이
    아닌 키 · on_duplicate 값 밖 · deletes · 한 요청 안 중복 · JSON 아님."""
    cases: dict[str, Any] = {
        "no-writes": {},
        "empty-keys": {"writes": {"tuple_keys": []}},
        "empty-field": {"writes": {"tuple_keys": [{"user": "", "relation": "owner", "object": OWNER[2]}]}},
        "not-a-dict": {"writes": {"tuple_keys": ["user:x owner tenant:y"]}},
        "bad-on-duplicate": _writes(OWNER, on_duplicate="replace"),
        "deletes": {**_writes(OWNER), "deletes": {"tuple_keys": [{"user": "u", "relation": "r", "object": "o"}]}},
        "duplicate-in-request": _writes(OWNER, OWNER),
        "not-json": b"[not json",
    }
    for case, body in cases.items():
        status, _ = _fga(openfga, "write", body)
        assert status == 400, case
    assert openfga.tuples == set()


# --- 공개 DNS 가드 · 닫힌 포트 · 서버 종료 --------------------------------------------------------------------------------------


def test_fake_17_dns_guard_blocks_public_names(authentik: FakeAuthentik) -> None:
    """fake-17 — 가드 안: 공개 이름(하위 · 대문자 끝 점 · 도메인 자체 · bytes)은 socket.gaierror + 기록(정규화된 이름) ·
    urllib 요청도 막힌다 · 127.0.0.1(가짜 서버 요청 포함)은 통과 · 나오면 원래 함수로 돌아온다."""
    original = socket.getaddrinfo
    with public_dns_guard() as attempts:
        assert socket.getaddrinfo is not original
        for host in ("auth.joshuatech.dev", "AUTH.JOSHUATECH.DEV.", "joshuatech.dev", b"fga.joshuatech.dev"):
            with pytest.raises(socket.gaierror):
                socket.getaddrinfo(host, 443)
        with pytest.raises(urllib.error.URLError):
            _OPENER.open("http://auth.joshuatech.dev/application/o/identity-admin/jwks/", timeout=5)
        assert socket.getaddrinfo("127.0.0.1", 80)
        assert _call("GET", f"{authentik.base_url}{GROUPS}", token=authentik.token)[0] == 200
    assert attempts == [
        "auth.joshuatech.dev",
        "auth.joshuatech.dev",
        "joshuatech.dev",
        "fga.joshuatech.dev",
        "auth.joshuatech.dev",
    ]
    assert socket.getaddrinfo is original


def test_fake_18_dns_guard_restores_after_error() -> None:
    """fake-18 — 블록 안에서 예외가 나도 socket 이름 조회 함수 넷(getaddrinfo · gethostbyname · gethostbyname_ex ·
    gethostbyaddr)이 들어올 때의 함수로 돌아온다(이름은 구현 상수와 따로 쓴다 — fake-26과 같은 꼴 · 이름 조회는 일어나지
    않는다)."""
    names = ("getaddrinfo", "gethostbyname", "gethostbyname_ex", "gethostbyaddr")
    originals = {name: getattr(socket, name) for name in names}
    with pytest.raises(RuntimeError), public_dns_guard():
        raise RuntimeError("boom")
    assert [name for name in names if getattr(socket, name) is not originals[name]] == []


def test_fake_19_public_name_boundary() -> None:
    """fake-19 — 공개 이름 판정은 레이블 경계다: 도메인 자체 · 하위 · 대소문자 · 끝 점은 참 / 접미 문자열만 같은 이름 ·
    공개 도메인을 앞에 둔 다른 도메인 · 무관한 이름 · 빈 값 · None은 거짓."""
    public = ("joshuatech.dev", "a.b.joshuatech.dev", "JoshuaTech.Dev.", b"auth.joshuatech.dev")
    private = ("notjoshuatech.dev", "joshuatech.dev.evil.com", "evil.example.com", "127.0.0.1", "", None)
    assert [host for host in public if not is_public_name(host)] == []
    assert [host for host in private if is_public_name(host)] == []


def test_fake_20_closed_port_refuses() -> None:
    """fake-20 — closed_port()의 포트로 연결하면 실패한다(RST 또는 시간 초과 — 둘 다 OSError)."""
    with pytest.raises(OSError):
        socket.create_connection(("127.0.0.1", closed_port()), timeout=1.0).close()


def test_fake_21_close_stops_server() -> None:
    """fake-21 — close() 뒤 서버 스레드가 끝나고 포트가 연결을 받지 않는다 · close()를 두 번 불러도 된다."""
    for server in (FakeAuthentik(), FakeOpenFga()):
        port = server.port
        server.close()
        server.close()
        assert server.thread_alive is False
        with pytest.raises(OSError):
            socket.create_connection(("127.0.0.1", port), timeout=1.0).close()


def test_fake_22_blackhole_never_answers() -> None:
    """fake-22 — blackhole(): 연결은 성립한다(커널 backlog가 핸드셰이크를 끝낸다) · 받는 쪽이 아무것도 보내지 않아 recv가
    시간 초과로 끝난다(데이터 없음 · 닫히지도 않는다) · 블록을 나온 뒤에는 그 포트로 연결할 수 없다(RST 또는 시간 초과 —
    둘 다 OSError)."""
    with blackhole() as port:
        with socket.create_connection(("127.0.0.1", port), timeout=1.0) as client:
            client.settimeout(0.3)
            with pytest.raises(TimeoutError):
                client.recv(1)
    with pytest.raises(OSError):
        socket.create_connection(("127.0.0.1", port), timeout=1.0).close()


# --- 가짜 충실도 보강(r2 — 그룹 목록 질의 · Content-Type) -------------------------------------------------------------------


def test_fake_23_authentik_group_list_query(authentik: FakeAuthentik) -> None:
    """fake-23 — 그룹 목록 GET: `name` 없음 · 가짜가 모르는 질의 키(`search=`)는 거르지 않은 전부를 넣은 순서로 준다(실제
    Authentik의 django-filter처럼 모르는 키를 무시한다 — 미끼가 필터 누락을 드러낸다) · `name` → 그 하나 / 그룹 항목의
    is_superuser = reset 값(기본 False)."""
    authentik.reset(
        groups=[
            {"name": "authentik Admins", "users": [], "is_superuser": True},
            {"name": "platform-admin", "users": []},
            {"name": GROUP_NAME, "users": []},
        ]
    )
    everything = [("authentik Admins", True), ("platform-admin", False), (GROUP_NAME, False)]
    for case, query in (("no-query", ""), ("unknown-key", f"?search={GROUP_NAME}")):
        status, body = _call("GET", f"{authentik.base_url}{GROUPS}{query}", token=authentik.token)
        listed = [(group["name"], group["is_superuser"]) for group in body["results"]]
        assert (status, listed) == (200, everything), case
    status, body = _call("GET", f"{authentik.base_url}{GROUPS}?name={GROUP_NAME}", token=authentik.token)
    assert (status, [group["name"] for group in body["results"]]) == (200, [GROUP_NAME])


def test_fake_24_authentik_rejects_non_json_body(authentik: FakeAuthentik) -> None:
    """fake-24 — Authentik: 본문이 있는 PATCH의 Content-Type이 application/json이 아니면(urllib 기본 form 타입) 415
    `{"detail": …}` · attributes 불변 · 요청은 기록된다 / 매개변수가 붙은 `application/json; charset=utf-8`은 받는다."""
    url = f"{authentik.base_url}{USERS}101/"
    body = {"attributes": {"tenant_id": TENANT}}
    status, payload = _call("PATCH", url, token=authentik.token, body=body, content_type=FORM_TYPE)
    assert (status, isinstance(payload.get("detail"), str)) == (415, True)
    assert authentik.user(101)["attributes"] == {"existing": "keep"}
    assert [(r.method, r.path) for r in authentik.mutations()] == [("PATCH", f"{USERS}101/")]
    json_with_charset = "application/json; charset=utf-8"
    assert _call("PATCH", url, token=authentik.token, body=body, content_type=json_with_charset)[0] == 200
    assert authentik.user(101)["attributes"] == {"tenant_id": TENANT}


def test_fake_25_openfga_accepts_any_content_type(openfga: FakeOpenFga) -> None:
    """fake-25 — OpenFGA는 Content-Type을 보지 않는다(grpc-gateway는 모르는 타입에 기본 JSON 마샬러를 쓴다 · VD-T066-2 —
    실제보다 엄격하게 만들어 정상 구현을 떨어뜨리지 않는다): form 타입 write → 200 · 튜플이 쓰인다."""
    url = f"{openfga.base_url}/stores/{openfga.store_id}/write"
    status, _ = _call("POST", url, token=openfga.key, body=_writes(OWNER), content_type=FORM_TYPE)
    assert status == 200
    assert openfga.tuples == {OWNER}


# --- DNS 가드 보강(r3 — gethostbyname 계열) ------------------------------------------------------------------------------


def test_fake_26_dns_guard_blocks_gethostbyname_family() -> None:
    """fake-26 — 가드는 socket.getaddrinfo 말고도 gethostbyname · gethostbyname_ex · gethostbyaddr를 감싼다(getaddrinfo
    속성을 거치지 않는 이름 조회 함수): 가드 안 — 네 함수가 모두 감싸져 있다 · 공개 이름(하위 · 대문자 끝 점 · 도메인
    자체)은 각각 socket.gaierror + 기록 3(정규화된 이름) · IP 리터럴 127.0.0.1은 통과(gethostbyname → "127.0.0.1") /
    나오면 네 함수가 들어올 때의 함수와 같다(is). 실제 이름 조회는 일어나지 않는다 — 공개 이름은 가드가 먼저 막고 통과
    대조는 IP 리터럴만 쓴다(감싸기를 먼저 확인하므로 감싸지 않는 가드에서도 공개 이름을 조회하기 전에 실패한다)."""
    names = ("getaddrinfo", "gethostbyname", "gethostbyname_ex", "gethostbyaddr")
    originals = {name: getattr(socket, name) for name in names}
    with public_dns_guard() as attempts:
        assert [name for name in names if getattr(socket, name) is originals[name]] == []
        blocked = (
            (socket.gethostbyname, "auth.joshuatech.dev"),
            (socket.gethostbyname_ex, "AUTH.JOSHUATECH.DEV."),
            (socket.gethostbyaddr, "joshuatech.dev"),
        )
        for resolve, host in blocked:
            with pytest.raises(socket.gaierror):
                resolve(host)
        assert socket.gethostbyname("127.0.0.1") == "127.0.0.1"
    assert attempts == ["auth.joshuatech.dev", "auth.joshuatech.dev", "joshuatech.dev"]
    assert [name for name in names if getattr(socket, name) is not originals[name]] == []
