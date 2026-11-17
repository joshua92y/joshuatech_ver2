"""T073 ia 명령 시험 — identity-admin 관리 명령(설계 D1 「test_identity_commands.py」 · D26 — 묶음은 조각마다 이 파일에 더한다).

조각 ③-b2 묶음:
- ia-26(D30 · D12 · D16): `manage.py revoke_sessions --sub <sub>` — 사용자 단위 관리자 폐기(SP-1에서 관리자 폐기를 부를 유일한
  길). 시험마다 맨 앞에 `get_commands()`에 그 명령이 있음을 단언한다(명령이 없어도 `call_command`는 CommandError라 부정 사례가
  구현 전에 초록이 된다 — 설계 D26 「부정 사례의 짝」).
  - 정상(쓰기 켬 · send_task 가로채기 · 멤버십 = 테넌트 B): 로그 1행(tenant = 멤버십 값 · sid NULL · reason admin) · outbox 1 ·
    `revoked:sub` · 세션 하한 키 = nbf · 위임 1회(이름 · args) · stdout에 `revoke_sessions:`로 시작하는 줄이 정확히 하나이고 그
    줄이 `OK id=<행 id> nbf=<행 nbf> expires_at=<ISO 8601 UTC = nbf + 330 s> denylist=ok delegate=enqueued`이며 sub가 없다.
    부정 사례(같은 준비물에서 `--sub`만 바꾼다): 멤버십 없는 sub · NUL이 든 인자 · 256자 인자 → CommandError · 행 · 키 그대로 ·
    `revoke_sessions:` 줄 0.
  - 쓰기 끔 → 출력 `delegate=off`(위임 0 · 행과 키는 같다).
  - 쓰기 켬 + DRAGONFLY_URL 닫힌 포트 → 행 1 · 출력 `PARTIAL … denylist=unreachable delegate=skipped` · CommandError이고
    `returncode == 3`(종료 코드 3 — 2는 인자 사용법 오류의 코드다 · 설계 Z9).
  - `nbf` 상한 관문(DB 시계 + 301 s)은 ia-39 (b)가 본다(tests/test_identity_contract.py).

조각 ③-b2 리뷰 반영(F7-F9 — 계약 §관리 명령 T073 보정 2026-11-13):
- F7: 출력 줄의 `env=<ENV 설정 값>`(머리말 바로 뒤) — 값은 호출 시점의 설정이다(쓰기 끔 사례는 ENV를 dev로 덮는다 — import
  시점 상수로 읽는 구현은 test를 찍는다).
- F8: 시험이 연 `transaction.atomic()` 안에서 부르면 쓰기 전에 CommandError(returncode 1) · 출력 줄 0 · 블록을 나온 뒤에도 로그
  행 0(짝: 블록 밖 같은 인자 → OK).
- F9 (가): 부정 사례 · PARTIAL 사례 · F8 사례의 CommandError 문구에 `--sub` 값이 없다. (나) 커밋 뒤 결과 갈래 넷(이음매는 모듈
  속성 덮기): enqueue 예외 → `OK … denylist=ok delegate=failed` · 종료 0 / `apply_user`가 failed를 돌려줌 · 예외를 던짐 →
  `PARTIAL … denylist=failed` · returncode 3 / 커밋 뒤 콜백이 칸을 채우지 못함(`revocation._after`를 아무것도 하지 않는 함수로
  덮는다) → `PARTIAL … denylist=none delegate=none` · returncode 3 — 넷 다 로그 행 1.

조각 ④ 첫 단계(조각 ③-b2 검증 low 3b2V-1 · 3b2V-2):
- 3b2V-1 ⑥: 갈래 `apply_user`가 skipped를 돌려줌 → `OK … denylist=skipped` · 종료 0(skipped는 완료다).
- 3b2V-2: 설정에 ENV가 없으면 조회 · 쓰기 전에 CommandError(1) · 출력 줄 0 · 로그 행 0(짝: ENV를 되돌린 같은 인자 → OK).

조각 ⑦ 묶음(설계 D19 · D18 · D20 — `manage.py seed_tenant --tenant-id <uuid v7> --owner-sub <sub> --member-sub <sub>
[--authentik-token-stdin]`):
- ia-14(D19 1 · D18): stdin 토큰으로만 인증한다 — 쓰기 켬 · 소속 · attribute가 없는 상태(조회 셋 · 쓰기 넷이 나간다) · 설정 토큰은
  틀린 값 → 가짜 Authentik이 받은 요청 전부가 인증됨 · 출력(stdout · stderr · 프로세스 fd)에 토큰 없음. 짝 = 같은 준비물에서 stdin만
  뺀다(설정 토큰으로 그룹 조회 1회가 403 → CommandError(연쇄 없음) · DB 0). stdin 줄의 꼴(빈 줄 · 공백 · 비ASCII · 자리값 · 읽을 수
  없는 스트림) → 요청 0 · DB 0 · 자리값인 설정 토큰은 stdin을 주면 판정에서 빠진다(Authentik 쪽은 stdin 값으로 판정한다).
- ia-15(D19 1-3 · 5 · 6 · D18 · D20): 인자(owner == member · v4 · UUID 꼴 아님 · NUL · 256자) · 자리값 자격 셋 각각 → 요청 0 ·
  DB 0 / store id의 `/` · `?` · 공백 → OpenFGA 요청 0 / attribute 충돌(쓰기 켬 · 끔) → Authentik 쓰기 0 / 그룹 없음(오타 난 v7
  id) → DB 행 0 / 응답 꼴 위반(조각 ④ 인계 — 그룹 pk UUID 아님 · 그룹 둘 · 사용자 pk 문자열 · attributes 사전 아님 · groups 목록
  아님 · 사용자 둘) → Authentik 쓰기 0 · DB 행은 멈춘 단계대로 / `add_user` · `patch_attributes`의 False → CommandError / 바깥
  atomic 안 → 요청 0 · DB 0.
- ia-16(D19 4 · 6 · 7 · 8): 기존 멤버십 role 불일치 → DB 무변화 · OpenFGA 0(Tenant 행이 없던 실행도 함께 롤백) / 그 id의 Tenant가
  다른 slug → CommandError · 짝에서 기존 display_name · status 그대로 / 멤버십 생성의 IntegrityError → 값 없는 CommandError(연쇄
  없음 · 행 0) / 출력 셈(첫 실행 `created:2/unchanged:0 authentik=written` · 재실행 `created:0/unchanged:2 authentik=unchanged` ·
  sub 없음) · OpenFGA 쓰기 요청 꼴(POST 하나 · `on_duplicate: "ignore"`) / 쓰기 끔의 `skipped(drift=<n>)`(4 · 0 · 3 — 사용자 둘 ×
  항목 둘 · 추가 호출 없음).
- 조각 ⑦ 수정 라운드(리뷰 7A · 7B — data-model §1 「세부」 T073 보정 2026-11-16): ia-15 인자에 대문자 UUID · 숫자 · 64자 hex
  sub(sub = Authentik 사용자 uuid의 소문자 정규형) · store id 꼴 위반은 2단계에서 막는다(두 가짜 요청 0 · DB 행 0 — 그 정규식이
  7단계 outbound 성분 검사와 같다) · superuser 그룹(is_superuser 참 · 키 없음) → DB 앞 CommandError · 파생 실패 꼬리(일시 오류만
  「다시 실행하면 마저 쓴다」 · 그 밖은 「인자 · 상태를 고친 뒤 다시 실행한다」) / ia-14 터미널 stdin(isatty 참 — 읽기 앞 거부) ·
  isatty 없는 stdin은 터미널이 아니다 / ia-16 출력 줄의 `env=`(호출 시점 ENV 설정 · ENV가 없으면 조회 · 쓰기 전 CommandError) ·
  stdout 전체가 OK 줄 하나.
- 조각 ⑦ 2차 수정 라운드(검증 7V-1 · 7V-2 · 7V-3): ia-15 인자에 uuid 뒤 한 글자 · `user:` 접두 uuid sub(sub 꼴 검사의 앵커 — fullmatch) ·
  파생 실패 꼬리에 사용자 조회 429(일시) · owner 사용자 여럿(일시 아님) · OpenFGA 쓰기 500 · 429(일시) · 400(일시 아님) ·
  `_upstream`의 꼬리 고르기 단위 노드(Docker · DB 없음 — 오류 종류마다 파생 · DB 앞 꼬리와 연쇄 없음) / ia-16 출력 전체(stdout이
  OK 줄 하나 · stderr가 비었다).
- 조각 ⑦ 3차 수정 라운드(검증 7W-1): ia-15 호출 자리마다의 꼬리 쌍 — 그룹 조회(①) 500 · 400 → 「DB는 쓰지 않았다」 · 행 0 /
  owner 소속 쓰기(add_user) 500 · 404 · owner attribute PATCH 503 · 400(④ · 쓰기 켬) → 일시 오류(500 · 503)만 「다시 실행하면
  마저 쓴다」 · 그 밖(404 · 400)은 「인자 · 상태를 고친 뒤 다시 실행한다」 · 행 3 / 실패 실행의 마지막 Authentik 요청이 주입한
  경로 · 메서드다(그 자리에서 멈췄다) · 짝은 주입이 소비된 같은 준비물의 재실행.
- 시험마다 맨 앞에서 `get_commands()`에 seed_tenant가 있음을 단언한다(명령이 없어도 call_command는 CommandError다). 부정 사례마다
  같은 준비물에서 한 가지만 바꾼 정상 실행이 짝이다(설계 D26). 가짜는 `ia73_authentik`(그룹 · 사용자 표면은 T066 가짜와 같다) ·
  `ia73_openfga`(T066). 테넌트 · sub 값은 이 파일의 시험 값이다(SP-1 고정 테넌트 UUID가 아니다). 토큰은 Secret이고, 명령의 출력 ·
  예외 문구는 SeedRun의 repr 밖에 두어 불리언으로 접은 뒤 단언한다.

명령은 `django.core.management.call_command`로 부르고 stdout을 `io.StringIO`로 받는다(구조 로그는 conftest sink로 간다 — 같은
stdout에 섞이는 것은 실제 실행뿐이다). 실제 DB 시계로 관문을 지나므로 DB 컨테이너 시계가 시험 프로세스보다 300 s 넘게 늦으면
CommandError다(설계 §5 공통 환경 「컨테이너 시계」 — 전체 실행 앞에서 견준다). 구현 모듈은 시험 함수 안에서 가져온다(`impl`).
단언 꼴: 결과를 지역 변수에 묶은 뒤 단언한다(자격 · 토큰 · 비밀 · URL을 assert 식 안의 호출 인자로 두지 않는다).
"""

from __future__ import annotations

import io
import re
import secrets
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, Any

import pytest
from django.core.management import CommandError, call_command, get_commands

from tests._ia_fakes import route_of
from tests._ia_support import (
    DB,
    DENYLIST_TTL_S,
    TENANT_B,
    floor_key,
    impl,
    insert_row,
    model,
    read_int,
    scan_keys,
    sub_key,
)
from tests._identity_fakes import closed_port
from tests._secret import Secret

if TYPE_CHECKING:
    from collections.abc import Callable, Mapping

    import redis
    from pytest_django.fixtures import SettingsWrapper

    from tests._ia_fakes import FakeAuthentikExt
    from tests._identity_fakes import FakeOpenFga

pytestmark = pytest.mark.usefixtures("ia73_env")

COMMAND = "revoke_sessions"
PREFIX = "revoke_sessions:"
OUTPUT_LINE = re.compile(
    r"revoke_sessions: (?P<status>OK|PARTIAL) env=(?P<env>\S+) id=(?P<id>\S+) nbf=(?P<nbf>[0-9]+)"
    r" expires_at=(?P<expires_at>\S+) denylist=(?P<denylist>\S+) delegate=(?P<delegate>\S+)"
)
TASK_REVOKE = "identity_admin.tasks.revoke_authentik_sessions"
PARTIAL_EXIT = 3  # 행은 기록됐다 — 거부 목록 쓰기 실패(설계 D30 · Z9)
ERROR_EXIT = 1  # CommandError 기본 종료 코드(F8 — 바깥 트랜잭션 거부)


def _spy(monkeypatch: pytest.MonkeyPatch) -> list[dict[str, Any]]:
    """`identity_admin.celery.app.send_task`를 덮어 호출을 기록한다(위임 enqueue 이음매 — 설계 D26)."""
    app = impl("celery").app
    calls: list[dict[str, Any]] = []

    def fake_send_task(name: str, args: Any = None, kwargs: Any = None, **options: Any) -> None:
        calls.append({"name": name, "args": args, "kwargs": kwargs, "options": options})

    monkeypatch.setattr(app, "send_task", fake_send_task)
    return calls


def _run(sub: str) -> tuple[list[str], str, CommandError | None]:
    """`revoke_sessions --sub <sub>` 한 번 → (`revoke_sessions:` 줄들, stdout 전체, CommandError 또는 None)."""
    out = io.StringIO()
    error: CommandError | None = None
    try:
        call_command(COMMAND, "--sub", sub, stdout=out)
    except CommandError as exc:
        error = exc
    text = out.getvalue()
    return [line for line in text.splitlines() if line.startswith(PREFIX)], text, error


def _parsed(lines: list[str]) -> dict[str, str] | None:
    """출력 줄이 정확히 하나이고 계약 꼴이면 그 칸들(아니면 None)."""
    if len(lines) != 1:
        return None
    match = OUTPUT_LINE.fullmatch(lines[0])
    return None if match is None else match.groupdict()


def _expected_fields(
    sub: str, *, env: str, denylist: str, delegate: str, status: str = "OK"
) -> dict[str, str] | None:
    """그 sub의 로그 행에서 기대하는 출력 칸 — env(호출 시점 ENV 설정) · id · nbf · expires_at(= nbf + 330 s · ISO 8601 UTC).
    행이 정확히 하나가 아니면 None(출력 칸과 견주면 어긋난다)."""
    found = list(model("session_revocation_log").objects.filter(sub=sub))
    if len(found) != 1:
        return None
    row = found[0]
    nbf = int(row.nbf.timestamp())
    expires_at = datetime.fromtimestamp(nbf, UTC) + timedelta(seconds=DENYLIST_TTL_S)
    return {
        "status": status,
        "env": env,
        "id": str(row.id),
        "nbf": str(nbf),
        "expires_at": expires_at.isoformat().replace("+00:00", "Z"),
        "denylist": denylist,
        "delegate": delegate,
    }


def _row_shape(sub: str) -> list[tuple[str, str | None, str]]:
    """그 sub의 로그 행 (tenant_id, sid, reason) 목록."""
    found = model("session_revocation_log").objects.filter(sub=sub)
    return [(str(row.tenant_id), row.sid, row.reason) for row in found]


def _keys(admin: redis.Redis, sub: str) -> tuple[int | None, int | None]:
    """(revoked:sub 값, 세션 하한 값)."""
    return read_int(admin, sub_key(sub)), read_int(admin, floor_key(sub))


def _error_shape(error: CommandError | None, sub: str) -> tuple[str | None, int | None, bool | None]:
    """(예외 클래스 이름, returncode, 문구에 --sub 값이 있는가) — 예외가 없으면 셋 다 None."""
    if error is None:
        return None, None, None
    return type(error).__name__, error.returncode, sub in str(error)


def _raise_injected(*args: Any, **kwargs: Any) -> Any:
    """이음매가 던지는 예상 밖 예외(문구는 값 없는 고정 문자열)."""
    raise RuntimeError("ia26-injected")


def _enqueue_raises(monkeypatch: pytest.MonkeyPatch, settings: SettingsWrapper) -> None:
    """쓰기 켬 + `identity_admin.celery.app.send_task`가 예외를 던진다."""
    settings.AUTHENTIK_WRITES_ENABLED = True
    monkeypatch.setattr(impl("celery").app, "send_task", _raise_injected)


def _denylist_returns_failed(monkeypatch: pytest.MonkeyPatch, settings: SettingsWrapper) -> None:
    """`denylist_writer.apply_user`가 failed를 돌려준다(쓰기 끔 — 위임은 off)."""
    monkeypatch.setattr(impl("denylist_writer"), "apply_user", lambda sub: "failed")


def _denylist_returns_skipped(monkeypatch: pytest.MonkeyPatch, settings: SettingsWrapper) -> None:
    """`denylist_writer.apply_user`가 skipped를 돌려준다(TTL이 남은 키가 없어 쓰지 않음 — 쓰기 끔 · 위임 off) — 완료로 본다."""
    monkeypatch.setattr(impl("denylist_writer"), "apply_user", lambda sub: "skipped")


def _denylist_raises(monkeypatch: pytest.MonkeyPatch, settings: SettingsWrapper) -> None:
    """`denylist_writer.apply_user`가 예외를 던진다(커밋 뒤 콜백의 ① 단계가 failed로 채운다)."""
    monkeypatch.setattr(impl("denylist_writer"), "apply_user", _raise_injected)


def _after_unfilled(monkeypatch: pytest.MonkeyPatch, settings: SettingsWrapper) -> None:
    """`revocation._after`(커밋 뒤 콜백 본체)를 아무것도 하지 않는 함수로 덮는다 — 결과 칸 둘이 비어 있다."""
    monkeypatch.setattr(impl("revocation"), "_after", lambda **kwargs: None)


# F9 (나) 갈래 표 — case → (준비, (머리말, denylist, delegate, returncode — None이면 CommandError 없음)).
AFTER_BRANCHES: dict[str, tuple[Callable[..., None], tuple[str, str, str, int | None]]] = {
    "enqueue-raises": (_enqueue_raises, ("OK", "ok", "failed", None)),
    "denylist-returns-failed": (_denylist_returns_failed, ("PARTIAL", "failed", "off", PARTIAL_EXIT)),
    "denylist-returns-skipped": (_denylist_returns_skipped, ("OK", "skipped", "off", None)),  # 3b2V-1 ⑥
    "denylist-raises": (_denylist_raises, ("PARTIAL", "failed", "off", PARTIAL_EXIT)),
    "after-unfilled": (_after_unfilled, ("PARTIAL", "none", "none", PARTIAL_EXIT)),
}


@DB
def test_ia_26_revoke_sessions_records_user_scope(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis
) -> None:
    """ia-26(정상 + 부정 사례 — 모듈 독스트링): 쓰기 켬 · 가로채기 · 멤버십(테넌트 B) → OK 줄(env = 호출 시점 ENV 설정 · F7) ·
    행 · outbox · 키 · 위임 1회 / 같은 준비물에서 `--sub`만 바꾼 부정 사례(멤버십 없음 · NUL · 256자) → CommandError(문구에 그
    `--sub` 값 없음 · F9 (가)) · 쓰기 0 · 출력 줄 0."""
    command_present = COMMAND in get_commands()
    sub = "ia26-sub"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    calls = _spy(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    expected_env = settings.ENV
    lines, text, error = _run(sub)
    fields = _parsed(lines)
    expected = _expected_fields(sub, env=expected_env, denylist="ok", delegate="enqueued")
    printed_env = fields["env"] if fields is not None else None
    rows, events = _row_shape(sub), model("outbox").objects.count()
    keys = _keys(ia73_df_admin, sub)
    nbf = int(fields["nbf"]) if fields is not None else None
    delegated = [(call["name"], tuple(call["args"] or ())) for call in calls]
    raw_sub_printed = sub in text
    negatives = {"no-membership": "ia26-stranger", "nul": f"ia26{chr(0)}sub", "256": "s" * 256}
    refused: dict[str, tuple[str | None, int, bool | None]] = {}
    for case, value in negatives.items():
        negative_lines, _, negative_error = _run(value)
        kind, _, named = _error_shape(negative_error, value)
        refused[case] = (kind, len(negative_lines), named)
    after_negatives = (model("session_revocation_log").objects.count(), model("outbox").objects.count())
    stranger_keys = scan_keys(ia73_df_admin, "*ia26-stranger")

    assert command_present is True
    assert (error, fields) == (None, expected)
    assert printed_env == expected_env
    assert (rows, events) == ([(TENANT_B, None, "admin")], 1)
    assert keys == (nbf, nbf)
    assert (delegated, raw_sub_printed) == ([(TASK_REVOKE, (sub, nbf))], False)
    assert refused == dict.fromkeys(negatives, ("CommandError", 0, False))
    assert (after_negatives, stranger_keys) == ((1, 1), [])


@DB
def test_ia_26_writes_off_prints_delegate_off(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis
) -> None:
    """ia-26(쓰기 끔 — ia73_env 기본 · dev 꼴 — ENV도 dev로 덮는다): OK 줄의 `env=dev`(F7 — 호출 시점의 설정 값) · `delegate=off` ·
    위임 0 · 행과 키는 정상 사례와 같다(denylist=ok)."""
    command_present = COMMAND in get_commands()
    sub = "ia26-off-sub"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    calls = _spy(monkeypatch)
    settings.ENV = "dev"
    lines, _, error = _run(sub)
    fields = _parsed(lines)
    expected = _expected_fields(sub, env="dev", denylist="ok", delegate="off")
    nbf = int(fields["nbf"]) if fields is not None else None
    keys = _keys(ia73_df_admin, sub)

    assert command_present is True
    assert (error, fields) == (None, expected)
    assert (_row_shape(sub), keys, len(calls)) == ([(TENANT_B, None, "admin")], (nbf, nbf), 0)


@DB
def test_ia_26_closed_port_is_partial_exit_3(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis
) -> None:
    """ia-26(쓰기 실패 — 설계 D30 5단계 · Z9): 쓰기 켬 + DRAGONFLY_URL 닫힌 포트 → 행 1(기록은 커밋됐다) · 출력 `PARTIAL …
    denylist=unreachable delegate=skipped`(커밋 뒤 SET이 연결에서 실패하면 위임을 넣지 않는다) · CommandError이고 returncode 3 ·
    위임 0 · 키 0."""
    command_present = COMMAND in get_commands()
    sub = "ia26-partial-sub"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    calls = _spy(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    settings.DRAGONFLY_URL = Secret(f"redis://identity-admin:{secrets.token_urlsafe(16)}@127.0.0.1:{closed_port()}/0")
    expected_env = settings.ENV
    lines, _, error = _run(sub)
    fields = _parsed(lines)
    expected = _expected_fields(sub, env=expected_env, denylist="unreachable", delegate="skipped", status="PARTIAL")
    outcome = _error_shape(error, sub)
    keys = scan_keys(ia73_df_admin, f"*{sub}")

    assert command_present is True
    assert fields == expected
    assert outcome == ("CommandError", PARTIAL_EXIT, False)
    assert (_row_shape(sub), keys, len(calls)) == ([(TENANT_B, None, "admin")], [], 0)


@DB
def test_ia_26_refuses_inside_outer_atomic(ia73_df_admin: redis.Redis) -> None:
    """ia-26(F8 — 계약 §관리 명령 「바깥 트랜잭션 안에서는 돌지 않는다」): 시험이 연 `transaction.atomic()` 안에서 명령 →
    CommandError(returncode 1 · 문구에 `--sub` 값 없음) · 출력 줄 0. 예외는 블록 안에서 받는다 — 블록은 커밋되므로, 가드 없이 바깥
    savepoint에 쓴 구현은 블록을 나온 뒤 행 · 키가 남는다 → 블록을 나온 뒤 로그 행 0 · outbox 0 · 키 0 / 짝: 블록 밖 같은 인자 →
    OK · 행 1."""
    from django.db import transaction

    command_present = COMMAND in get_commands()
    sub = "ia26-atomic-sub"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    with transaction.atomic():
        inside_lines, _, inside_error = _run(sub)
    inside = (*_error_shape(inside_error, sub), len(inside_lines))
    after_block = (
        model("session_revocation_log").objects.count(),
        model("outbox").objects.count(),
        scan_keys(ia73_df_admin, f"*{sub}"),
    )
    lines, _, error = _run(sub)
    fields = _parsed(lines)
    status = fields["status"] if fields is not None else None

    assert command_present is True
    assert inside == ("CommandError", ERROR_EXIT, False, 0)
    assert after_block == (0, 0, [])
    assert (error, status, _row_shape(sub)) == (None, "OK", [(TENANT_B, None, "admin")])


def _run_any(sub: str) -> tuple[list[str], tuple[str | None, int | None, bool | None]]:
    """`revoke_sessions --sub <sub>` 한 번 → (`revoke_sessions:` 줄들, (예외 클래스 이름, returncode, 문구에 --sub 값이 있는가)) —
    CommandError 밖의 예외(구현 전 AttributeError 등)도 값으로 받는다(트레이스백 · 문구는 싣지 않는다)."""
    out = io.StringIO()
    error: Exception | None = None
    try:
        call_command(COMMAND, "--sub", sub, stdout=out)
    except Exception as exc:  # noqa: BLE001 — 예외 종류를 값으로 본다
        error = exc
    lines = [line for line in out.getvalue().splitlines() if line.startswith(PREFIX)]
    if error is None:
        return lines, (None, None, None)
    return lines, (type(error).__name__, getattr(error, "returncode", None), sub in str(error))


@DB
def test_ia_26_env_missing_refuses_before_writing(settings: SettingsWrapper, ia73_df_admin: redis.Redis) -> None:
    """ia-26(3b2V-2 — 조각 ④ 첫 단계): 설정에 ENV가 없는 프로필(migrate 등)에서 명령 → 조회 · 쓰기 전에 CommandError(returncode
    1 · 문구에 `--sub` 값 없음) · 출력 줄 0 · 로그 행 0 · outbox 0 · 키 0(「`revoke_sessions:` 줄이 없으면 기록되지 않았다」가 참으로
    남는다) / 짝: ENV를 되돌린 같은 인자 → OK · 행 1."""
    command_present = COMMAND in get_commands()
    sub = "ia26-no-env-sub"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    saved_env = settings.ENV
    del settings.ENV
    missing_lines, missing = _run_any(sub)
    after_missing = (
        model("session_revocation_log").objects.count(),
        model("outbox").objects.count(),
        scan_keys(ia73_df_admin, f"*{sub}"),
    )
    settings.ENV = saved_env
    lines, _, error = _run(sub)
    fields = _parsed(lines)
    printed = (fields["status"], fields["env"]) if fields is not None else None

    assert command_present is True
    assert (missing, len(missing_lines)) == (("CommandError", ERROR_EXIT, False), 0)
    assert after_missing == (0, 0, [])
    assert (error, printed, _row_shape(sub)) == (None, ("OK", saved_env), [(TENANT_B, None, "admin")])


@DB
@pytest.mark.parametrize("case", sorted(AFTER_BRANCHES))
def test_ia_26_after_branches(case: str, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-26(F9 (나) — 계약 §관리 명령 「delegate=failed는 종료 코드 0 그대로 · 채우지 못한 칸은 none · denylist=none도 PARTIAL」):
    갈래 표 AFTER_BRANCHES의 준비(모듈 속성 덮기) → 출력 칸(머리말 · env · id · nbf · expires_at · denylist · delegate) = 기대 ·
    CommandError 없음(enqueue 예외 · denylist=skipped — 3b2V-1 ⑥: skipped는 ok와 같이 완료다) 또는 returncode 3(그 밖 — 문구에
    `--sub` 값 없음) · 로그 행 1(행은 기록됐다)."""
    command_present = COMMAND in get_commands()
    sub = f"ia26-{case}"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=sub, role="member")
    prepare, (status, denylist, delegate, returncode) = AFTER_BRANCHES[case]
    prepare(monkeypatch, settings)
    expected_env = settings.ENV
    lines, _, error = _run(sub)
    fields = _parsed(lines)
    expected = _expected_fields(sub, env=expected_env, denylist=denylist, delegate=delegate, status=status)
    outcome = _error_shape(error, sub)
    expected_outcome = (None, None, None) if returncode is None else ("CommandError", returncode, False)

    assert command_present is True
    assert fields == expected
    assert outcome == expected_outcome
    assert _row_shape(sub) == [(TENANT_B, None, "admin")]


# --- 조각 ⑦: seed_tenant(ia-14 · 15 · 16 — 설계 D19 · D18 · D20) ---------------------------------------------------------

SEED = "seed_tenant"
SEED_PREFIX = "seed_tenant:"
SEED_LINE = re.compile(
    r"seed_tenant: OK env=(?P<env>\S+) tenant=(?P<tenant>\S+)"
    r" memberships=created:(?P<created>[0-9]+)/unchanged:(?P<unchanged>[0-9]+)"
    r" authentik=(?P<authentik>written|unchanged|skipped\(drift=[0-9]+\)) fga=ok"
)
NO_SEED_COMMAND = "seed_tenant 관리 명령이 없다"
# 이 파일의 시험 값(SP-1 고정 테넌트 UUID — data-model §1 — 가 아니다). v4는 같은 값에서 판 숫자만 4로 바꿨다.
SEED_TENANT = "019a0000-0000-7000-8000-0000000000a1"
SEED_TENANT_V4 = "019a0000-0000-4000-8000-0000000000a1"
TYPO_TENANT = "019a0000-0000-7000-8000-0000000000b2"  # 그룹이 없는 v7 id(오타 난 --tenant-id)
SEED_OWNER = "14000000-0000-4000-8000-0000000000a1"  # Authentik 사용자 uuid = sub(provider sub_mode user_uuid)
SEED_MEMBER = "14000000-0000-4000-8000-0000000000a2"
SEED_GROUP = f"tenant:{SEED_TENANT}"
SEED_GROUP_PK = "14000000-0000-4000-8000-0000000000f1"  # 그룹 pk를 고정하는 사례(그룹 조회 응답을 주입할 때)
SEED_SLUG = "joshuatech"
SEED_DISPLAY = "JoshuaTech"
OWNER_PK, MEMBER_PK = 201, 202
SEED_ARGS = {"--tenant-id": SEED_TENANT, "--owner-sub": SEED_OWNER, "--member-sub": SEED_MEMBER}
SEED_TUPLES = {
    (f"user:{SEED_OWNER}", "owner", f"tenant:{SEED_TENANT}"),
    (f"user:{SEED_MEMBER}", "member", f"tenant:{SEED_TENANT}"),
}
PLACEHOLDER = "PLACEHOLDER-"  # 자리값 표식(계약 문자열 — contracts/pod-template.md 게이트 2 · conf.PLACEHOLDER_MARK)
MUTATING = frozenset({"POST", "PATCH", "PUT", "DELETE"})
ERROR_EXIT_SEED = 1  # CommandError 기본 종료 코드


@dataclass(frozen=True)
class SeedRun:
    """seed_tenant 한 번의 결과 — fields(`seed_tenant:` 줄이 정확히 하나이고 계약 꼴이면 그 칸 · 아니면 None) · lines(그 접두 줄
    수) · out_lines(stdout 전체의 줄 수 — 시험의 stdout은 명령의 self.stdout뿐이다: 구조 로그는 conftest sink · 프로세스 stdout으로
    간다) · err_lines(stderr 전체의 줄 수 — 시험의 stderr도 명령의 self.stderr뿐이다: call_command가 넘긴 stderr를 BaseCommand.execute가
    감싸고 검사는 건너뛴다) · error(예외 클래스 이름 · 없으면 None) · returncode · chained(예외에 연쇄된 원 예외가 남았는가 —
    `__cause__` 또는 가리지 않은 `__context__`). 출력 전문과 예외 문구는 repr에 싣지 않는다(회귀 때 심은 값이 실패 출력에 찍히지
    않게 — 그 둘은 shows()로 불리언으로 접어 단언한다)."""

    fields: dict[str, str] | None
    lines: int
    out_lines: int
    err_lines: int
    error: str | None
    returncode: int | None
    chained: bool
    text: str = field(repr=False)
    message: str = field(repr=False)

    def shows(self, *values: str) -> bool:
        """출력(stdout · stderr) 또는 예외 문구에 values 가운데 하나라도(빈 값 제외) 있는가."""
        return any(value and (value in self.text or value in self.message) for value in values)


def _seed(args: Mapping[str, str] | None = None, *, stdin: object = None) -> SeedRun:
    """`seed_tenant` 한 번 — args는 SEED_ARGS에서 덮을 인자 · stdin(문자열이면 그 내용의 스트림 · 스트림이면 그대로)을 주면
    `--authentik-token-stdin` + `stdin=`(stealth 옵션). 예외는 종류 · returncode · 연쇄 여부 · 문구(repr 밖)로 받는다(트레이스백
    없음 · CommandError 밖의 예외 — 구현 전 · 회귀 — 도 값으로)."""
    argv: list[str] = []
    for name, value in {**SEED_ARGS, **(args or {})}.items():
        argv += [name, value]
    out, err = io.StringIO(), io.StringIO()
    options: dict[str, Any] = {"stdout": out, "stderr": err}
    if stdin is not None:
        argv.append("--authentik-token-stdin")
        options["stdin"] = io.StringIO(stdin) if isinstance(stdin, str) else stdin
    error: Exception | None = None
    try:
        call_command(SEED, *argv, **options)
    except Exception as exc:  # noqa: BLE001 — 예외 종류를 값으로 본다
        error = exc
    lines = [line for line in out.getvalue().splitlines() if line.startswith(SEED_PREFIX)]
    match = SEED_LINE.fullmatch(lines[0]) if len(lines) == 1 else None
    chained = error is not None and (
        error.__cause__ is not None or (error.__context__ is not None and not error.__suppress_context__)
    )
    return SeedRun(
        fields=None if match is None else match.groupdict(),
        lines=len(lines),
        out_lines=len(out.getvalue().splitlines()),
        err_lines=len(err.getvalue().splitlines()),
        error=None if error is None else type(error).__name__,
        returncode=getattr(error, "returncode", None),
        chained=chained,
        text=out.getvalue() + err.getvalue(),
        message="" if error is None else str(error),
    )


def _authentik_state(run: SeedRun) -> str | None:
    """출력 줄의 authentik 칸(줄이 꼴이 아니면 None)."""
    return None if run.fields is None else run.fields["authentik"]


def _memberships(run: SeedRun) -> tuple[str, str] | None:
    """출력 줄의 (created, unchanged)(줄이 꼴이 아니면 None)."""
    return None if run.fields is None else (run.fields["created"], run.fields["unchanged"])


def _seed_world(
    authentik: FakeAuthentikExt,
    *,
    groups: int = 1,
    group_pk: str | None = None,
    superuser: bool = False,
    member_of: tuple[int, ...] = (),
    attributes: Mapping[int, Mapping[str, Any]] | None = None,
    present: tuple[int, ...] = (OWNER_PK, MEMBER_PK),
) -> None:
    """가짜 Authentik 시드 전제(요청 기록도 비운다) — 그룹 tenant:<T> groups개(pk = 첫 그룹만 group_pk · 나머지는 새 uuid · 소속
    member_of · is_superuser = superuser) / 사용자 owner(pk 201 · uuid = SEED_OWNER) · member(pk 202 · uuid = SEED_MEMBER)
    가운데 pk가 present에 든 것만 · attributes(pk별 사전 — 기본 owner {"existing": "keep"} · member {})."""
    entries: list[dict[str, Any]] = []
    for index in range(groups):
        entry: dict[str, Any] = {"name": SEED_GROUP, "users": list(member_of), "is_superuser": superuser}
        if group_pk is not None and index == 0:
            entry["pk"] = group_pk
        entries.append(entry)
    values = {OWNER_PK: {"existing": "keep"}, MEMBER_PK: {}} if attributes is None else attributes
    users = [
        {"pk": OWNER_PK, "uuid": SEED_OWNER, "username": "ia-owner", "attributes": dict(values.get(OWNER_PK, {}))},
        {"pk": MEMBER_PK, "uuid": SEED_MEMBER, "username": "ia-member", "attributes": dict(values.get(MEMBER_PK, {}))},
    ]
    authentik.reset(groups=entries, users=[user for user in users if user["pk"] in present])


def _seed_rows() -> tuple[int, int]:
    """(tenant 행 수, tenant_membership 행 수) — app role(default) 연결."""
    return model("tenant").objects.count(), model("tenant_membership").objects.count()


def _seed_snapshot() -> tuple[frozenset[tuple[str, ...]], frozenset[tuple[str, ...]]]:
    """DB 정본 스냅숏 — (Tenant (id · slug · display_name · status) 집합, 멤버십 (id · tenant_id · sub · role) 집합)."""
    tenants = frozenset((str(t.pk), t.slug, t.display_name, t.status) for t in model("tenant").objects.all())
    memberships = frozenset(
        (str(m.pk), str(m.tenant_id), m.sub, m.role) for m in model("tenant_membership").objects.all()
    )
    return tenants, memberships


def _calls(authentik: FakeAuthentikExt, openfga: FakeOpenFga) -> tuple[int, int]:
    """(가짜 Authentik이 받은 요청 수, 가짜 OpenFGA가 받은 요청 수) — 기록은 _seed_world · ia73_env가 비운다."""
    return len(authentik.requests), len(openfga.requests)


def _routes(requests: list[Any]) -> list[tuple[str, str | None]]:
    """요청 기록 → (메서드, 경로 이름) 목록(받은 차례)."""
    return [(request.method, route_of(request.path)) for request in requests]


def _users_page(*users: Mapping[str, Any]) -> tuple[int, dict[str, Any]]:
    """사용자 목록 응답 한 쪽(주입용 — (200, 본문))."""
    return 200, {"pagination": {"next": 0}, "results": [dict(user) for user in users]}


def _inject_owner(authentik: FakeAuthentikExt, *owners: Mapping[str, Any]) -> None:
    """두 사용자 조회 모두에 같은 목록 쪽을 주입한다(조회 차례와 무관하게) — owner 항목들(기본 꼴에 각 사전의 칸을 덮는다) + 바른
    member 항목."""
    base = {"pk": OWNER_PK, "uuid": SEED_OWNER, "username": "ia-owner", "attributes": {}, "groups": []}
    member = {"pk": MEMBER_PK, "uuid": SEED_MEMBER, "username": "ia-member", "attributes": {}, "groups": []}
    page = _users_page(*({**base, **fields} for fields in owners), member)
    authentik.inject("users", page, page)


@DB
def test_ia_14_stdin_token_authenticates_every_authentik_call(
    settings: SettingsWrapper,
    ia73_authentik: FakeAuthentikExt,
    ia73_openfga: FakeOpenFga,
    capfd: pytest.CaptureFixture[str],
) -> None:
    """ia-14(설계 D19 1): 쓰기 켬 · 소속 · attribute가 없는 상태 · 설정 토큰은 틀린 값 → stdin(끝 CRLF)에 맞는 토큰 → OK
    `authentik=written` · 가짜 Authentik이 받은 요청(조회 셋 · add_user 둘 · PATCH 둘) 전부 인증됨 · 쓴 결과(소속 {201, 202} ·
    owner attributes 병합) · 출력(stdout · stderr · 프로세스 fd)과 예외 문구에 두 토큰 · preshared 키 없음 / 짝(같은 준비물에서
    stdin만 뺀다): 설정 토큰(틀린 값)의 그룹 조회 1회가 403 → CommandError · 인증된 요청 0 · DB 행 0(그룹 조회가 DB 앞)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    wrong = Secret(secrets.token_urlsafe(24))
    right = ia73_authentik.token
    key = ia73_openfga.key
    settings.AUTHENTIK_API_TOKEN = wrong
    _seed_world(ia73_authentik)
    refused = _seed()
    refused_calls = [
        (request.method, route_of(request.path), request.authorized) for request in ia73_authentik.requests
    ]
    refused_rows = _seed_rows()
    seen = len(ia73_authentik.requests)
    run = _seed(stdin=f"{right}\r\n")
    made = ia73_authentik.requests[seen:]
    unauthorized = [(request.method, request.path) for request in made if not request.authorized]
    writes = sorted(route for route in _routes(made) if route[0] in MUTATING)
    state = (
        ia73_authentik.group_users(SEED_GROUP),
        ia73_authentik.user(OWNER_PK)["attributes"],
        ia73_authentik.user(MEMBER_PK)["attributes"],
    )
    captured = capfd.readouterr()
    shown = (refused.shows(wrong, right, key), run.shows(wrong, right, key))
    fd_shown = any(value in captured.out or value in captured.err for value in (wrong, right, key))

    refused_shape = (refused.error, refused.returncode, refused.lines, refused.chained)
    assert refused_shape == ("CommandError", ERROR_EXIT_SEED, 0, False)
    assert (refused_calls, refused_rows) == ([("GET", "groups", False)], (0, 0))
    assert (run.error, _authentik_state(run), len(made) > 0, unauthorized) == (None, "written", True, [])
    assert writes == [("PATCH", "user_detail"), ("PATCH", "user_detail"), ("POST", "add_user"), ("POST", "add_user")]
    assert state == ({OWNER_PK, MEMBER_PK}, {"existing": "keep", "tenant_id": SEED_TENANT}, {"tenant_id": SEED_TENANT})
    assert (shown, fd_shown) == ((False, False), False)


class _TerminalStream(io.StringIO):
    """isatty()가 참인 문자열 스트림 — `kubectl exec -it`(PTY)의 표준 입력 꼴. 읽기(readline)를 부르면 read_attempted가 참이 된다
    (터미널 판정은 읽기 앞이다 — 실제 터미널에서 읽으면 친 토큰이 화면에 찍힌다)."""

    read_attempted = False

    def isatty(self) -> bool:
        return True

    def readline(self, size: int | None = -1, /) -> str:
        self.read_attempted = True
        return super().readline(size)


class _LineOnlyStream:
    """readline만 있는 표준 입력(isatty 속성 없음 — 터미널이 아닌 것으로 본다)."""

    def __init__(self, text: str) -> None:
        self._stream = io.StringIO(text)

    def readline(self) -> str:
        return self._stream.readline()


TOKEN_SLOT = "<right-token>"  # 표의 stdin 원문에서 가짜 Authentik의 맞는 토큰 자리(시험이 바꿔 넣는다)
# stdin의 꼴 위반(설계 D19 1 · D18 · data-model §1 「세부」 T073 보정 2026-11-16) — case → (stdin 원문 — None = 읽을 수 없는
# 스트림(닫힌 스트림), 스트림 클래스). terminal은 꼴이 맞는 토큰을 isatty()가 참인 스트림에 담는다(읽기 앞의 터미널 판정만이 막는다
# — 짝은 같은 값의 일반 StringIO다).
STDIN_REFUSED: dict[str, tuple[str | None, type[io.StringIO]]] = {
    "empty": ("", io.StringIO),
    "inner-space": ("ia14 token\n", io.StringIO),
    "non-ascii": (f"ia14-tok{chr(0xE9)}n\n", io.StringIO),
    "placeholder": (f"{PLACEHOLDER}ia14\n", io.StringIO),
    "unreadable": (None, io.StringIO),
    "terminal": (f"{TOKEN_SLOT}\n", _TerminalStream),
}


@DB
@pytest.mark.parametrize("case", sorted(STDIN_REFUSED))
def test_ia_14_stdin_token_refused_before_any_call(
    case: str, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-14(설계 D19 1 · D18): stdin 줄이 비었거나 공백 · 비ASCII가 섞였거나 자리값(PLACEHOLDER-)이거나 스트림을 읽을 수 없거나
    표준 입력이 터미널(isatty() 참 — 담긴 줄은 맞는 토큰)이면 CommandError(문구에 그 줄 없음 · 출력 줄 0) · 두 가짜의 요청 0 · DB
    행 0 · 터미널 스트림은 읽지 않았다 / 짝: 같은 준비물에서 stdin만 맞는 토큰(일반 StringIO) → OK · 요청 ≥ 1 · 행 3."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    raw, stream_class = STDIN_REFUSED[case]
    line = None if raw is None else raw.replace(TOKEN_SLOT, ia73_authentik.token)
    stream = stream_class(line or "")
    if line is None:
        stream.close()
    refused = _seed(stdin=stream)
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    echoed = refused.shows((line or "").strip())
    read_attempted = getattr(stream, "read_attempted", False)
    run = _seed(stdin=f"{ia73_authentik.token}\n")
    calls = _calls(ia73_authentik, ia73_openfga)

    assert (refused.error, refused.returncode, refused.lines, echoed) == ("CommandError", ERROR_EXIT_SEED, 0, False)
    assert (after, read_attempted) == (((0, 0), (0, 0)), False)
    assert (run.error, run.fields is not None, min(calls) > 0, _seed_rows()) == (None, True, True, (1, 2))


@DB
def test_ia_14_stdin_without_isatty_is_not_a_terminal(
    ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-14(data-model §1 「세부」 — 터미널 판정): isatty 속성이 없는 표준 입력 객체(readline만 — 맞는 토큰 한 줄)는 터미널이
    아닌 것으로 본다 → OK · 요청 ≥ 1 · 행 3(속성을 바로 부르는 구현은 AttributeError로 멈춘다)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    run = _seed(stdin=_LineOnlyStream(f"{ia73_authentik.token}\n"))
    calls = _calls(ia73_authentik, ia73_openfga)

    assert (run.error, run.fields is not None, min(calls) > 0, _seed_rows()) == (None, True, True, (1, 2))


@DB
def test_ia_14_stdin_token_replaces_placeholder_settings_token(
    settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-14(설계 D18 「--authentik-token-stdin을 주면 Authentik 쪽은 stdin 값으로 판정한다」): 설정 토큰이 자리값 → stdin 없이는
    CommandError · 요청 0 · 행 0 / 같은 준비물에서 stdin(맞는 토큰)만 더한다 → OK · Authentik 요청 전부 인증됨 · 행 3."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_API_TOKEN = Secret(f"{PLACEHOLDER}{secrets.token_hex(8)}")
    _seed_world(ia73_authentik)
    refused = _seed()
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    run = _seed(stdin=f"{ia73_authentik.token}\n")
    authorized = [request.authorized for request in ia73_authentik.requests]

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert after == ((0, 0), (0, 0))
    assert (run.error, run.fields is not None, _seed_rows()) == (None, True, (1, 2))
    assert (len(authorized) > 0, all(authorized)) == (True, True)


# 인자 위반(설계 D19 1 · data-model §1 「세부」 T073 보정 2026-11-16 — sub는 Authentik 사용자 uuid의 소문자 정규형) — case →
# SEED_ARGS에서 덮을 인자. 대문자 UUID · 숫자 pk(admin UI 주소의 사용자 번호) · 64자 hex(uid 해시 꼴)는 5단계 사용자 조회에서
# 반드시 실패하는 sub다 — 그 판정은 4단계 DB 커밋 뒤라 1단계에서 거부해야 행이 남지 않는다. uuid 뒤 한 글자(붙여 넣기 꼬리) ·
# `user:` 접두 uuid(OpenFGA 튜플 꼴을 붙여 넣은 실수)는 출력 가능 ASCII 1-255자(revocation.valid_identifier)를 지나고 uuid
# 정규형을 부분 문자열로 담는다 — sub 꼴 검사의 앵커(fullmatch)만이 막는다(match · search면 지나간다).
SEED_ARGS_REFUSED: dict[str, dict[str, str]] = {
    "owner-equals-member": {"--member-sub": SEED_OWNER},
    "tenant-v4": {"--tenant-id": SEED_TENANT_V4},
    "tenant-not-uuid": {"--tenant-id": "ia15-not-a-uuid"},
    "owner-nul": {"--owner-sub": f"ia15{chr(0)}owner"},
    "member-256": {"--member-sub": "m" * 256},
    "owner-uppercase-uuid": {"--owner-sub": SEED_OWNER.upper()},
    "member-numeric-pk": {"--member-sub": "5"},
    "owner-hex64": {"--owner-sub": "0123456789abcdef" * 4},
    "owner-uuid-suffix": {"--owner-sub": SEED_OWNER + "0"},
    "member-prefixed-uuid": {"--member-sub": "user:" + SEED_MEMBER},
}


@DB
@pytest.mark.parametrize("case", sorted(SEED_ARGS_REFUSED))
def test_ia_15_arguments_refused_before_any_call(
    case: str, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(설계 D19 1 · data-model §1 「세부」): owner == member · v4 tenant-id · UUID 꼴 아님 · sub에 NUL · 256자 sub · 대문자
    UUID sub · 숫자 sub · 64자 hex sub · uuid 뒤 한 글자 sub · `user:` 접두 uuid sub → CommandError(returncode 1 · 출력 줄 0 · 문구에
    sub · 인자 값 없음) · 두 가짜의 요청 0 · DB 행 0 / 짝(같은 준비물에서 그 인자만 되돌린다) → OK · 요청 ≥ 1 · 행 3."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    overrides = SEED_ARGS_REFUSED[case]
    refused = _seed(overrides)
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    named = refused.shows(SEED_OWNER, SEED_MEMBER, *overrides.values())
    run = _seed()
    calls = _calls(ia73_authentik, ia73_openfga)

    assert (refused.error, refused.returncode, refused.lines, named) == ("CommandError", ERROR_EXIT_SEED, 0, False)
    assert after == ((0, 0), (0, 0))
    assert (run.error, run.fields is not None, min(calls) > 0, _seed_rows()) == (None, True, True, (1, 2))


@DB
@pytest.mark.parametrize("name", ["AUTHENTIK_API_TOKEN", "OPENFGA_PRESHARED_KEY", "OPENFGA_STORE_ID"])
def test_ia_15_placeholder_credentials_refused_before_any_call(
    name: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(설계 D18 · D19 2): 자격 셋 각각 — 값에 `PLACEHOLDER-`가 들면(그 밖의 꼴은 맞는 값 — store id도 경로 성분 꼴이다)
    CommandError(출력 줄 0) · 두 가짜의 요청 0 · DB 행 0 / 짝: 같은 준비물에서 그 설정만 되돌린다 → OK · 요청 ≥ 1 · 행 3."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    original = getattr(settings, name)
    setattr(settings, name, Secret(f"{PLACEHOLDER}{secrets.token_hex(8)}"))
    refused = _seed()
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    setattr(settings, name, original)
    run = _seed()
    calls = _calls(ia73_authentik, ia73_openfga)

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert after == ((0, 0), (0, 0))
    assert (run.error, run.fields is not None, min(calls) > 0, _seed_rows()) == (None, True, True, (1, 2))


# store id의 경로 성분 꼴 위반(설계 D20 · W5) — case → OPENFGA_STORE_ID 값.
STORE_ID_REFUSED = {"slash": "01IA15/STORE", "question": "01IA15?STORE", "space": "01IA15 STORE"}


@DB
@pytest.mark.parametrize("case", sorted(STORE_ID_REFUSED))
def test_ia_15_store_id_shape_checked_before_the_call(
    case: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(설계 D20 · W5 — 꼴은 conf가 아니라 경로에 넣는 호출 시점에 본다 · data-model §1 「세부」 T073 보정 2026-11-16 —
    시드는 2단계(DB 앞)에서도 본다): OPENFGA_STORE_ID에 `/` · `?` · 공백 → OpenFGA 요청 0 · CommandError(출력 줄 0) · 두 가짜의
    요청 0(그룹 조회 포함) · DB 행 0 / 짝: 같은 준비물에서 store id만 되돌린다 → OK · OpenFGA 요청 1 · 튜플 둘."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    original = settings.OPENFGA_STORE_ID
    settings.OPENFGA_STORE_ID = STORE_ID_REFUSED[case]
    refused = _seed()
    refused_fga = len(ia73_openfga.requests)
    refused_after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    settings.OPENFGA_STORE_ID = original
    run = _seed()
    fga = (len(ia73_openfga.requests), ia73_openfga.tuples)

    assert (refused.error, refused.lines, refused_fga) == ("CommandError", 0, 0)
    assert refused_after == ((0, 0), (0, 0))
    assert (run.error, run.fields is not None, fga) == (None, True, (1, SEED_TUPLES))


def test_ia_15_store_id_form_matches_the_call_time_segment_check() -> None:
    """ia-15(data-model §1 「세부」 — 2단계 store id 꼴은 7단계 호출 시점 검사와 같은 꼴이다): seed가 쓰는 `openfga.STORE_ID_FORM`의
    정규식 · 플래그가 `outbound.build_url`의 str 성분 검사 정규식과 같다(둘이 어긋나면 2단계가 통과시킨 값을 7단계가 DB · 파생
    쓰기 뒤에 거부하거나, 7단계가 받을 값을 2단계가 막는다)."""
    form = impl("openfga").STORE_ID_FORM
    segment = impl("outbound")._SEGMENT_RE

    assert (form.pattern, form.flags) == (segment.pattern, segment.flags)


@DB
@pytest.mark.parametrize("writes", [True, False], ids=["writes-on", "writes-off"])
def test_ia_15_attribute_conflict_refused_without_writes(
    writes: bool, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(설계 D19 6): member의 attributes.tenant_id가 다른 테넌트 → 쓰기 켬 · 끔 둘 다 CommandError(출력 줄 0) · Authentik 쓰기
    0(소속 · attribute가 없는 owner도 쓰지 않는다 — 두 사용자를 다 본 뒤에 쓴다) · 그 값 그대로 · OpenFGA 요청 0 / 짝: 같은
    준비물에서 그 값만 이 테넌트로 → OK."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = writes
    _seed_world(ia73_authentik, attributes={OWNER_PK: {}, MEMBER_PK: {"tenant_id": TYPO_TENANT}})
    refused = _seed()
    refused_writes = len(ia73_authentik.mutations())
    refused_fga = len(ia73_openfga.requests)
    kept = ia73_authentik.user(MEMBER_PK)["attributes"]
    _seed_world(ia73_authentik, attributes={OWNER_PK: {}, MEMBER_PK: {"tenant_id": SEED_TENANT}})
    run = _seed()

    assert (refused.error, refused.lines, refused_writes, refused_fga) == ("CommandError", 0, 0, 0)
    assert kept == {"tenant_id": TYPO_TENANT}
    assert (run.error, run.fields is not None) == (None, True)


@DB
def test_ia_15_group_missing_writes_no_rows(ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga) -> None:
    """ia-15(설계 D19 3 · 〔Y19〕): 오타 난 v7 --tenant-id(그 그룹이 없다) → CommandError(출력 줄 0) · Tenant · 멤버십 행 0(그룹
    조회가 DB 앞이다) · Authentik 쓰기 0 · OpenFGA 요청 0 / 짝: 같은 준비물에서 --tenant-id만 바른 값 → OK · 행 3(오타 실행이 slug
    joshuatech 행을 남겼다면 slug 충돌로 막힌다)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    refused = _seed({"--tenant-id": TYPO_TENANT})
    after = (_seed_rows(), len(ia73_authentik.mutations()), len(ia73_openfga.requests))
    run = _seed()

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert after == ((0, 0), 0, 0)
    assert (run.error, run.fields is not None, _seed_rows()) == (None, True, (1, 2))


def _group_superuser(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik, group_pk=SEED_GROUP_PK, superuser=True)


def _group_superuser_missing(authentik: FakeAuthentikExt) -> None:
    """그룹은 그대로 두고(pk 고정 · is_superuser False) 그룹 조회 응답에서만 is_superuser 키를 뺀다(주입 — 가짜 상태는 그대로라
    판정이 없는 구현은 그 그룹에 소속을 쓰고 OK로 끝난다)."""
    _seed_world(authentik, group_pk=SEED_GROUP_PK)
    group = {"pk": SEED_GROUP_PK, "num_pk": 1001, "name": SEED_GROUP, "parent": None, "users": [], "attributes": {}}
    authentik.inject("groups", (200, {"pagination": {"next": 0}, "results": [group]}))


# superuser 그룹(data-model §1 「세부」 T073 보정 2026-11-16 — 찾은 그룹의 is_superuser가 거짓이 아니면 DB 앞에서 끝난다) — case →
# 준비(그룹 하나 · 사용자 둘 · 소속 · attribute 없음).
SUPERUSER_CASES: dict[str, Callable[[FakeAuthentikExt], None]] = {
    "superuser-true": _group_superuser,
    "superuser-missing": _group_superuser_missing,
}


@DB
@pytest.mark.parametrize("case", sorted(SUPERUSER_CASES))
def test_ia_15_superuser_group_refused_before_db(
    case: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(data-model §1 「세부」 · 리뷰 7B-6): 쓰기 켬 · 그룹 tenant:<T>가 superuser 그룹이거나(is_superuser 참) 조회 응답에
    is_superuser 키가 없다 → CommandError(출력 줄 0 · 연쇄 없음 · 문구에 테넌트 · 그룹 pk 없음) · Authentik 요청은 그룹 조회
    하나뿐(쓰기 0) · OpenFGA 요청 0 · DB 행 0 / 짝: 같은 준비물에서 is_superuser False(가짜 기본)인 그룹 → OK `authentik=written`
    · Authentik 쓰기 넷."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    SUPERUSER_CASES[case](ia73_authentik)
    refused = _seed()
    refused_after = (_routes(ia73_authentik.requests), len(ia73_openfga.requests), _seed_rows())
    named = refused.shows(SEED_TENANT, SEED_GROUP_PK)
    _seed_world(ia73_authentik, group_pk=SEED_GROUP_PK)
    run = _seed()
    run_writes = len(ia73_authentik.mutations())

    assert (refused.error, refused.lines, refused.chained, named) == ("CommandError", 0, False, False)
    assert refused_after == ([("GET", "groups")], 0, (0, 0))
    assert (run.error, _authentik_state(run), run_writes) == (None, "written", 4)


def _group_pk_not_uuid(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik, group_pk="ia15-group-pk")


def _group_duplicate(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik, groups=2)


def _user_pk_string(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    _inject_owner(authentik, {"pk": str(OWNER_PK)})


def _user_attributes_not_dict(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    _inject_owner(authentik, {"attributes": ["tenant_id"]})


def _user_groups_not_list(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    _inject_owner(authentik, {"groups": None})


def _user_duplicate(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    _inject_owner(authentik, {}, {"pk": OWNER_PK + 100})


# 응답 꼴 위반(조각 ④ 인계 · 설계 D19 3 · 5 — 설계 시험 줄 밖) — case → (쓰기 플래그, 준비, 부정 실행 뒤 DB 행). 그룹은 3단계(DB
# 앞) · 사용자는 5단계(DB 뒤)에서 멈춘다. 쓰기 끔 사례는 쓰기 메서드의 pk 꼴 거부(add_user · patch_attributes의 False)가 대신 막아
# 주지 못하는 자리다(쓰기 켬 사례는 그 거부가 두 번째 방어선이다).
MALFORMED_CASES: dict[str, tuple[bool, Callable[[FakeAuthentikExt], None], tuple[int, int]]] = {
    "group-pk-not-uuid": (True, _group_pk_not_uuid, (0, 0)),
    "group-duplicate": (True, _group_duplicate, (0, 0)),
    "user-pk-string": (True, _user_pk_string, (1, 2)),
    "user-pk-string-writes-off": (False, _user_pk_string, (1, 2)),
    "user-attributes-not-dict": (False, _user_attributes_not_dict, (1, 2)),
    "user-groups-not-list": (False, _user_groups_not_list, (1, 2)),
    "user-duplicate": (False, _user_duplicate, (1, 2)),
}


@DB
@pytest.mark.parametrize("case", sorted(MALFORMED_CASES))
def test_ia_15_malformed_authentik_response_refused(
    case: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(조각 ④ 인계 — 설계 시험 줄 밖): 소속 · attribute 없음 / 그룹 조회 응답의 pk가 UUID 꼴이 아님 · 이름이 같은 그룹 둘(쓰기
    켬) · 사용자 조회 응답의 owner pk가 문자열 "201"(쓰기 켬 · 끔) · attributes가 사전이 아님 · groups가 목록이 아님 · uuid가 같은
    사용자 둘(쓰기 끔) → CommandError(출력 줄 0) · Authentik 쓰기 0 · OpenFGA 요청 0 · DB 행은 멈춘 단계대로(그룹 = 0 · 사용자 =
    3) / 짝: 같은 준비물에서 응답만 바른 꼴 → OK(쓰기 켬이면 Authentik 쓰기 넷)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    writes, prepare, rows = MALFORMED_CASES[case]
    settings.AUTHENTIK_WRITES_ENABLED = writes
    prepare(ia73_authentik)
    refused = _seed()
    refused_after = (len(ia73_authentik.mutations()), len(ia73_openfga.requests), _seed_rows())
    _seed_world(ia73_authentik)
    run = _seed()
    run_writes = len(ia73_authentik.mutations())

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert refused_after == (0, 0, rows)
    assert (run.error, run.fields is not None, run_writes) == (None, True, 4 if writes else 0)


@DB
@pytest.mark.parametrize("method", ["add_user", "patch_attributes"])
def test_ia_15_write_method_refusal_is_command_error(
    method: str,
    settings: SettingsWrapper,
    monkeypatch: pytest.MonkeyPatch,
    ia73_authentik: FakeAuthentikExt,
    ia73_openfga: FakeOpenFga,
) -> None:
    """ia-15(조각 ④ 인계 — `authentik.add_user` · `patch_attributes`는 pk 꼴이 아니면 요청 없이 False를 돌려준다): 쓰기 켬 · 소속 ·
    attribute 없음 · 그 메서드를 False를 돌려주게 덮는다(모듈 속성 이음매) → CommandError(출력 줄 0 · 연쇄 없음) · 그 메서드의
    요청 0 · OpenFGA 요청 0 · DB 행 3(5단계 뒤) / 짝: 같은 준비물에서 덮기만 거둔다 → OK `authentik=written`."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    route = "add_user" if method == "add_user" else "user_detail"
    _seed_world(ia73_authentik)
    with monkeypatch.context() as patch:
        patch.setattr(impl("authentik"), method, lambda *args, **kwargs: False)
        refused = _seed()
    refused_after = (
        [verb for verb, name in _routes(ia73_authentik.requests) if name == route and verb in MUTATING],
        len(ia73_openfga.requests),
        _seed_rows(),
    )
    run = _seed()

    assert (refused.error, refused.lines, refused.chained) == ("CommandError", 0, False)
    assert refused_after == ([], 0, (1, 2))
    assert (run.error, _authentik_state(run)) == (None, "written")


# 파생 단계(5-7) 실패 문구의 꼬리(data-model §1 「세부」 T073 보정 2026-11-16 — 재실행이 마저 쓰는 것은 일시 오류로 멈춘 실행뿐이다)
# — 계약 문자열(값 없음).
RETRY_TAIL = " - DB 행은 남았다 · 다시 실행하면 마저 쓴다"
FIX_TAIL = " - DB 행은 남았다 · 인자 · 상태를 고친 뒤 다시 실행한다(틀린 인자로 남은 행 · 파생은 런북 T114로 지운다)"


def _users_lookup_500(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    authentik.inject("users", 500)


def _users_lookup_429(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    authentik.inject("users", 429)


def _users_lookup_400(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik)
    authentik.inject("users", 400)


def _member_missing(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik, present=(OWNER_PK,))


def _member_attribute_conflict(authentik: FakeAuthentikExt) -> None:
    _seed_world(authentik, attributes={OWNER_PK: {}, MEMBER_PK: {"tenant_id": TYPO_TENANT}})


# case → (준비, 일시 오류인가 — 계약대로 적는다: data-model §1 「세부」 「429 · 5xx · 연결 · 시간 초과 · 마감만 일시」). 첫 사용자
# 조회의 500 · 429는 일시 오류 · 400은 일시 아닌 HTTP 상태 · 사용자 없음 · uuid가 같은 owner 사용자 둘(_user_duplicate — 남은 주입
# 대기열은 짝의 _seed_world가 비운다) · attribute 충돌은 다시 돌아도 같은 자리에서 멈춘다.
DERIVED_FAILURES: dict[str, tuple[Callable[[FakeAuthentikExt], None], bool]] = {
    "user-lookup-500": (_users_lookup_500, True),
    "user-lookup-429": (_users_lookup_429, True),
    "user-lookup-400": (_users_lookup_400, False),
    "member-missing": (_member_missing, False),
    "owner-duplicate": (_user_duplicate, False),
    "member-attribute-conflict": (_member_attribute_conflict, False),
}


@DB
@pytest.mark.parametrize("case", sorted(DERIVED_FAILURES))
def test_ia_15_derived_failure_tail_by_transience(
    case: str, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(data-model §1 「세부」 · 리뷰 7B-2 · 검증 7V-2): 4단계 뒤(DB 행 3 커밋) 파생 단계가 멈춘다 → CommandError(returncode 1 ·
    출력 줄 0 · 연쇄 없음) · 문구 끝이 일시 오류(사용자 조회 500 · 429)면 「다시 실행하면 마저 쓴다」 · 그 밖(사용자 조회 400 · member
    없음 · uuid가 같은 owner 사용자 둘 · attribute 충돌)이면 「인자 · 상태를 고친 뒤 다시 실행한다(… 런북 T114 …)」(꼬리 글자만
    불리언으로 견준다 — 값이 없는 문구다) · OpenFGA 요청 0 · DB 행 3 / 짝: 같은 준비물에서 원인만 거둔다(_seed_world가 주입 대기열을
    비운다 · member 있음 · 충돌 없음) → 다시 실행 OK `created:0/unchanged:2`."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    prepare, transient = DERIVED_FAILURES[case]
    prepare(ia73_authentik)
    refused = _seed()
    tails = (refused.message.endswith(RETRY_TAIL), refused.message.endswith(FIX_TAIL))
    refused_after = (refused.lines, len(ia73_openfga.requests), _seed_rows())
    _seed_world(ia73_authentik)
    run = _seed()

    assert (refused.error, refused.returncode, refused.chained) == ("CommandError", ERROR_EXIT_SEED, False)
    assert tails == (transient, not transient)
    assert refused_after == (0, 0, (1, 2))
    assert (run.error, _memberships(run), _seed_rows()) == (None, ("0", "2"), (1, 2))


# 7단계 OpenFGA 쓰기 실패(검증 7V-2) — case → (가짜 OpenFGA가 다음 쓰기 한 번에 돌려줄 상태, 일시 오류인가 — 계약대로 적는다:
# data-model §1 「세부」 「429 · 5xx · 연결 · 시간 초과 · 마감만 일시」). 400은 모델 · 요청 꼴 같은 상태 문제다(다시 돌아도 같다).
OPENFGA_FAILURES: dict[str, tuple[int, bool]] = {
    "openfga-500": (500, True),
    "openfga-429": (429, True),
    "openfga-400": (400, False),
}


@DB
@pytest.mark.parametrize("case", sorted(OPENFGA_FAILURES))
def test_ia_15_openfga_failure_tail_by_transience(
    case: str, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(data-model §1 「세부」 · 검증 7V-2): 쓰기 끔(ia73_env 기본 — Authentik 쓰기 없음) · 7단계 OpenFGA 쓰기가 500 · 429 ·
    400으로 실패한다(가짜 `fail_next_write` — 다음 쓰기 한 번 · 쓰지 않는다) → CommandError(returncode 1 · 출력 줄 0 · 연쇄 없음) ·
    문구 끝이 일시 오류(500 · 429)면 「다시 실행하면 마저 쓴다」 · 그 밖(400)이면 「인자 · 상태를 고친 뒤 다시 실행한다(… 런북
    T114 …)」(꼬리 글자만 불리언으로 견준다) · DB 행 3(4단계 뒤) · OpenFGA 요청 1(주입이 그 쓰기에 쓰였다 · 튜플 0) / 짝: 같은
    준비물에서 주입을 거두고 다시 실행 → OK `created:0/unchanged:2` · OpenFGA 요청 2 · 튜플 둘."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    status, transient = OPENFGA_FAILURES[case]
    _seed_world(ia73_authentik)
    ia73_openfga.fail_next_write = (status, {"code": "ia15-injected", "message": f"fake injected {status}"})
    refused = _seed()
    tails = (refused.message.endswith(RETRY_TAIL), refused.message.endswith(FIX_TAIL))
    refused_after = (
        refused.lines,
        _seed_rows(),
        len(ia73_openfga.requests),
        ia73_openfga.fail_next_write is None,
        ia73_openfga.tuples,
    )
    ia73_openfga.fail_next_write = None
    run = _seed()
    fga = (len(ia73_openfga.requests), ia73_openfga.tuples)

    assert (refused.error, refused.returncode, refused.chained) == ("CommandError", ERROR_EXIT_SEED, False)
    assert tails == (transient, not transient)
    assert refused_after == (0, (1, 2), 1, True, set())
    assert (run.error, _memberships(run), _seed_rows(), fga) == (None, ("0", "2"), (1, 2), (2, SEED_TUPLES))


# 호출 자리마다의 꼬리 쌍(검증 7W-1 — `_upstream`에 넘기는 꼬리 쌍은 호출 자리가 고른다) — case → (가짜 Authentik 경로 이름
# (tests/_ia_fakes.py ROUTES), 그 경로의 다음 요청 하나에 주입할 상태, 쓰기 플래그, 멈춘 요청(메서드, 경로 이름 — 그 실행의
# 마지막 Authentik 요청), 기대 꼬리 이름, 실패 뒤 DB 행(tenant, tenant_membership), 짝의 출력 칸(created, unchanged,
# authentik)). 기대는 계약대로 적는다(data-model §1 「세부」 — 순서 ① 그룹 조회 ② DB ③ 사용자 조회 ④ Authentik 쓰기 ⑤ OpenFGA
# 쓰기 · 「일시 오류는 Authentik · OpenFGA 호출 모두 429 · 5xx · 연결 · 시간 초과 · 마감만 일시다」 · 「DB를 쓰기 전의 실패는 일시
# 여부와 무관하게 「DB는 쓰지 않았다」로 끝난다」). ①은 쓰기 플래그와 무관하게 나가는 읽기라 기본(꺼짐)으로 두고 ④는 쓰기 켬이다 —
# _seed_world 기본(소속 · attribute 없음)에서 owner의 add_user가 첫 소속 쓰기 · owner의 PATCH가 `/users/<pk>/`의 첫 요청이다
# (seed는 PATCH 앞에 그 경로를 GET하지 않는다 — authentik.get_user를 부르지 않는다). 짝은 주입이 소비된 같은 준비물에서 다시
# 실행한다: ①은 첫 실행(DB 앞에서 멈췄다 · 쓰기 끔이라 어긋남 4) · ④는 남은 DB 행 위의 재실행이다.
CALL_SITE_FAILURES: dict[
    str, tuple[str, int, bool, tuple[str, str], str, tuple[int, int], tuple[str, str, str]]
] = {
    "group-500": ("groups", 500, False, ("GET", "groups"), "NO_DB", (0, 0), ("2", "0", "skipped(drift=4)")),
    "group-400": ("groups", 400, False, ("GET", "groups"), "NO_DB", (0, 0), ("2", "0", "skipped(drift=4)")),
    "add-user-500": ("add_user", 500, True, ("POST", "add_user"), "RETRY", (1, 2), ("0", "2", "written")),
    "add-user-404": ("add_user", 404, True, ("POST", "add_user"), "FIX", (1, 2), ("0", "2", "written")),
    "patch-503": ("user_detail", 503, True, ("PATCH", "user_detail"), "RETRY", (1, 2), ("0", "2", "written")),
    "patch-400": ("user_detail", 400, True, ("PATCH", "user_detail"), "FIX", (1, 2), ("0", "2", "written")),
}


def _tail_name(message: str) -> str:
    """CommandError 문구 → 꼬리 이름(RETRY · FIX · NO_DB — 셋 다 아니면 other) — 문구는 돌려주지 않는다."""
    names = {RETRY_TAIL: "RETRY", FIX_TAIL: "FIX", NO_DB_TAIL: "NO_DB"}
    return next((label for tail, label in names.items() if message.endswith(tail)), "other")


@DB
@pytest.mark.parametrize("case", sorted(CALL_SITE_FAILURES))
def test_ia_15_call_site_tail_by_transience(
    case: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-15(data-model §1 「세부」 · 검증 7W-1 — `_upstream`의 꼬리 쌍은 호출 자리가 고른다): 소속 · attribute 없음 · 가짜
    Authentik의 한 경로(그 경로의 다음 요청 하나)에 HTTP 실패를 주입한다 — ① 그룹 조회 500 · 400(쓰기 끔) / ④ owner 소속 쓰기
    (add_user) 500 · 404 · owner attribute PATCH(user_detail) 503 · 400(쓰기 켬) → CommandError(returncode 1 · stdout ·
    stderr 줄 0 · 연쇄 없음) · 문구 끝이 ①은 일시 여부와 무관하게 「DB는 쓰지 않았다」 · ④는 일시 오류(500 · 503)면 「다시
    실행하면 마저 쓴다」 · 그 밖(404 · 400)이면 「인자 · 상태를 고친 뒤 다시 실행한다(… 런북 T114 …)」(꼬리 글자만 이름으로
    접는다) · DB 행 ①(0, 0) · ④(1, 2) · OpenFGA 요청 0 · 그 실행의 마지막 Authentik 요청이 주입한 경로 · 메서드(인증됨)이고 그
    경로의 요청은 하나다(그 자리에서 멈췄다 — 주입은 인증된 요청이 그 경로에서 하나씩 쓴다) / 짝: _seed_world 없이 같은
    준비물에서 다시 실행(남은 주입이 있었다면 그 경로의 첫 요청이 받아 멈춘다 — 주입 대기열이 비었다) → OK(①은 첫 실행
    `created:2/unchanged:0 authentik=skipped(drift=4)` · ④는 `created:0/unchanged:2 authentik=written`) · DB 행 3 · 튜플 둘 ·
    Authentik 결과(쓰기 켬 = 소속 둘 · attribute 병합 — 재실행이 마저 쓴다 · 쓰기 끔 = 그대로)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    route, status, writes, stop, tail, rows, rerun = CALL_SITE_FAILURES[case]
    settings.AUTHENTIK_WRITES_ENABLED = writes
    expected_env = settings.ENV
    _seed_world(ia73_authentik)
    ia73_authentik.inject(route, status)
    refused = _seed()
    made = ia73_authentik.requests
    last = made[-1] if made else None
    stopped = (
        None if last is None else (last.method, route_of(last.path), last.authorized),
        len(ia73_authentik.requests_to(route)),
    )
    refused_view = (refused.error, refused.returncode, refused.out_lines, refused.err_lines, refused.chained)
    refused_after = (_tail_name(refused.message), _seed_rows(), len(ia73_openfga.requests))
    run = _seed()  # 짝 — _seed_world 없이(주입 대기열을 비우지 않는다)
    state = (
        ia73_authentik.group_users(SEED_GROUP),
        ia73_authentik.user(OWNER_PK)["attributes"],
        ia73_authentik.user(MEMBER_PK)["attributes"],
    )
    run_view = (run.error, run.fields, _seed_rows(), ia73_openfga.tuples, state)
    created, unchanged, authentik_state = rerun
    expected_fields = {
        "env": expected_env,
        "tenant": SEED_TENANT,
        "created": created,
        "unchanged": unchanged,
        "authentik": authentik_state,
    }
    written = ({OWNER_PK, MEMBER_PK}, {"existing": "keep", "tenant_id": SEED_TENANT}, {"tenant_id": SEED_TENANT})
    expected_state = written if writes else (set(), {"existing": "keep"}, {})

    assert refused_view == ("CommandError", ERROR_EXIT_SEED, 0, 0, False)
    assert refused_after == (tail, rows, 0)
    assert stopped == ((*stop, True), 1)
    assert run_view == (None, expected_fields, (1, 2), SEED_TUPLES, expected_state)


# _upstream의 꼬리 고르기(검증 7V-2) — 사례 이름 → (outbound 오류 형 이름, 상태 코드 또는 outbound 종류 상수의 이름, 파생 꼬리
# 쌍(_DERIVED)에서 기대하는 꼬리 이름). 기대는 계약대로 적는다(data-model §1 「세부」 「429 · 5xx · 연결 · 시간 초과 · 마감만 일시」
# — outbound의 .transient · TRANSIENT_KINDS로 계산하지 않는다). DB 앞 꼬리 쌍(_BEFORE_DB)은 모두 「DB는 쓰지 않았다」다.
NO_DB_TAIL = " - DB는 쓰지 않았다"
UPSTREAM_FAILURES: dict[str, tuple[str, int | str, str]] = {
    "status-429": ("UpstreamStatus", 429, "RETRY"),
    "status-500": ("UpstreamStatus", 500, "RETRY"),
    "status-503": ("UpstreamStatus", 503, "RETRY"),
    "status-599": ("UpstreamStatus", 599, "RETRY"),
    "status-302": ("UpstreamStatus", 302, "FIX"),
    "status-400": ("UpstreamStatus", 400, "FIX"),
    "status-401": ("UpstreamStatus", 401, "FIX"),
    "status-404": ("UpstreamStatus", 404, "FIX"),
    "connection": ("UpstreamUnavailable", "CONNECTION", "RETRY"),
    "timeout": ("UpstreamUnavailable", "TIMEOUT", "RETRY"),
    "deadline": ("UpstreamUnavailable", "DEADLINE", "RETRY"),
    "malformed": ("UpstreamUnavailable", "MALFORMED", "FIX"),
    "too-large": ("UpstreamUnavailable", "TOO_LARGE", "FIX"),
    "invalid-request": ("UpstreamUnavailable", "INVALID_REQUEST", "FIX"),
    "scheme": ("UpstreamUnavailable", "SCHEME", "FIX"),
}


def _upstream_failure(outbound: Any, kind: str, value: int | str) -> Exception:
    """UPSTREAM_FAILURES 한 칸 → outbound 오류(상태 코드는 그대로 · 종류는 outbound 상수 이름으로 읽는다)."""
    if kind == "UpstreamStatus":
        return outbound.UpstreamStatus(int(value))
    return outbound.UpstreamUnavailable(getattr(outbound, str(value)))


def _upstream_tail(seed: Any, tails: tuple[str, str], failure: Exception) -> tuple[str, bool]:
    """`seed._upstream`에 failure를 올리는 호출을 넘긴다 → (CommandError 문구 꼬리의 이름 — RETRY · FIX · NO_DB · 그 밖은 other ·
    CommandError가 아니면 그 예외 클래스 이름 · 돌아오면 returned, 연쇄가 남았는가 — `__cause__`가 있거나 `__suppress_context__`가
    거짓). 문구 · 예외 객체는 돌려주지 않는다."""

    def call() -> None:
        raise failure

    error: Exception | None = None
    try:
        seed._upstream("ia15 호출", tails, call)
    except Exception as exc:  # noqa: BLE001 — 예외 종류를 값으로 본다
        error = exc
    if error is None:
        return "returned", False
    if not isinstance(error, CommandError):
        return type(error).__name__, False
    message = str(error)
    names = {RETRY_TAIL: "RETRY", FIX_TAIL: "FIX", NO_DB_TAIL: "NO_DB"}
    name = next((label for tail, label in names.items() if message.endswith(tail)), "other")
    return name, error.__cause__ is not None or not error.__suppress_context__


class TestIa15UpstreamTail:
    """Docker 없이 도는 단위 노드(검증 7V-2) — 모듈 pytestmark의 `ia73_env`를 이 클래스 안에서만 빈 픽스처로 가린다(pytest는 가장
    가까운 정의를 쓴다 — 설정 덮기 · Dragonfly · 가짜 서버 · DB가 필요 없다 · tests/test_identity_contract.py의
    TestIa21StaticSchema와 같은 꼴)."""

    @pytest.fixture
    def ia73_env(self) -> None:
        """빈 픽스처 — 이 클래스의 노드는 시험 환경을 쓰지 않는다."""

    def test_ia_15_upstream_tail_by_transience(self) -> None:
        """ia-15(data-model §1 「세부」 — 파생 꼬리는 일시 오류만 「다시 실행하면 마저 쓴다」): seed_tenant `_upstream`에
        UPSTREAM_FAILURES의 오류(UpstreamStatus 429 · 500 · 503 · 599 · 302 · 400 · 401 · 404 / UpstreamUnavailable
        connection · timeout · deadline · malformed · too_large · invalid_request · scheme — 종류는 outbound 상수)를 올리는 호출을
        꼬리 쌍 둘로 넘긴다 → `_DERIVED`는 429 · 5xx · 연결 · 시간 초과 · 마감만 RETRY · 나머지 FIX / `_BEFORE_DB`는 모두 「DB는
        쓰지 않았다」 / 모두 연쇄 없음(`__cause__` None · `__suppress_context__` 참) — 표 전체를 (사례, 꼬리 이름, 연쇄) 목록 하나로
        접어 기대 목록과 한 번에 견준다(문구 · 예외 객체는 assert 식 밖)."""
        seed = impl("management.commands.seed_tenant")
        outbound = impl("outbound")
        pairs = (("derived", seed._DERIVED), ("before-db", seed._BEFORE_DB))
        observed: list[tuple[str, str, bool]] = []
        expected: list[tuple[str, str, bool]] = []
        for case, (kind, value, derived_tail) in UPSTREAM_FAILURES.items():
            for pair_name, tails in pairs:
                failure = _upstream_failure(outbound, kind, value)
                observed.append((f"{pair_name}/{case}", *_upstream_tail(seed, tails, failure)))
                expected.append((f"{pair_name}/{case}", derived_tail if pair_name == "derived" else "NO_DB", False))

        assert observed == expected


@DB
def test_ia_15_refuses_inside_outer_atomic(ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga) -> None:
    """ia-15(바깥 트랜잭션 가드 — revoke_sessions와 같다): 시험이 연 transaction.atomic() 안에서 → CommandError(출력 줄 0) · 두
    가짜의 요청 0 · 블록을 나온 뒤(블록은 커밋된다) DB 행 0 — 가드가 없으면 DB(정본)의 커밋 전에 파생을 쓰고 행이 바깥 블록과 함께
    커밋된다 / 짝: 블록 밖 같은 인자 → OK · 행 3."""
    from django.db import transaction

    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    with transaction.atomic():
        refused = _seed()
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    run = _seed()

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert after == ((0, 0), (0, 0))
    assert (run.error, run.fields is not None, _seed_rows()) == (None, True, (1, 2))


@DB
@pytest.mark.parametrize("tenant_row", [True, False], ids=["tenant-present", "tenant-absent"])
def test_ia_16_role_mismatch_refused_without_db_writes(
    tenant_row: bool, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(설계 D19 4 · 〔Y19〕): 멤버십 (owner sub, role member)가 이미 있다(tenant-present: Tenant 행도 · tenant-absent: 없다 —
    그 실행이 Tenant를 만든 뒤 멤버십에서 멈춰도 atomic 하나가 함께 되돌린다) · 쓰기 켬 → CommandError(출력 줄 0) · DB 무변화(행 ·
    id · role) · OpenFGA 요청 0 · Authentik 쓰기 0 / 짝: 같은 준비물에서 --owner-sub ↔ --member-sub만 바꿔 role이 맞게 → OK ·
    `created:1/unchanged:1`."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_world(ia73_authentik)
    if tenant_row:
        insert_row("tenant", id=SEED_TENANT, slug=SEED_SLUG, display_name=SEED_DISPLAY)
    insert_row("tenant_membership", tenant_id=SEED_TENANT, sub=SEED_OWNER, role="member")
    before = _seed_snapshot()
    refused = _seed()
    after = _seed_snapshot()
    refused_writes = (len(ia73_openfga.requests), len(ia73_authentik.mutations()))
    run = _seed({"--owner-sub": SEED_MEMBER, "--member-sub": SEED_OWNER})

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert (after == before, refused_writes) == (True, (0, 0))
    assert (run.error, _memberships(run)) == (None, ("1", "1"))


@DB
def test_ia_16_existing_tenant_keeps_its_fields(
    settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(설계 D19 4): 그 --tenant-id의 Tenant가 다른 slug로 있다 → CommandError(출력 줄 0) · DB 무변화 · OpenFGA 요청 0 ·
    Authentik 쓰기 0 / 짝: 같은 준비물에서 그 행의 slug만 joshuatech로 → OK · 기존 display_name · status 그대로(시드는 갱신하지
    않는다 · `created:2/unchanged:0`)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_world(ia73_authentik)
    insert_row("tenant", id=SEED_TENANT, slug="ia16-other", display_name="Existing", status="suspended")
    before = _seed_snapshot()
    refused = _seed()
    refused_after = (_seed_snapshot() == before, len(ia73_openfga.requests), len(ia73_authentik.mutations()))
    model("tenant").objects.using("owner").filter(pk=SEED_TENANT).update(slug=SEED_SLUG)
    run = _seed()
    tenants = _seed_snapshot()[0]

    assert (refused.error, refused.lines) == ("CommandError", 0)
    assert refused_after == (True, 0, 0)
    assert (run.error, _memberships(run)) == (None, ("2", "0"))
    assert tenants == frozenset({(SEED_TENANT, SEED_SLUG, "Existing", "suspended")})


@DB
def test_ia_16_integrity_race_is_value_free(
    monkeypatch: pytest.MonkeyPatch, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(설계 D19 4 · 「slug 경합 IntegrityError는 메시지 없는 CommandError」): 멤버십 생성이 경합으로 IntegrityError(문구 ·
    DETAIL에 sub)를 낸다(member 생성만 — 모델 관리자의 create를 덮는다) → CommandError(문구에 sub 없음 · 연쇄 없음 · 출력 줄 0) ·
    atomic 하나가 Tenant · owner 멤버십까지 되돌린다(DB 행 0) · Authentik 쓰기 0 · OpenFGA 요청 0 / 짝: 같은 준비물에서 덮기만
    거둔다 → OK · 행 3."""
    from django.db import IntegrityError

    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    manager = model("tenant_membership").objects
    original = manager.create

    def racing_create(**fields: Any) -> Any:
        if fields.get("role") == "member":
            detail = f"Key (sub)=({fields['sub']})"
            raise IntegrityError(f"duplicate key violates tenant_membership_sub_tenant_uniq DETAIL: {detail}")
        return original(**fields)

    with monkeypatch.context() as patch:
        patch.setattr(manager, "create", racing_create)
        refused = _seed()
    refused_after = (_seed_rows(), len(ia73_authentik.mutations()), len(ia73_openfga.requests))
    named = refused.shows(SEED_OWNER, SEED_MEMBER)
    run = _seed()

    assert (refused.error, refused.lines, refused.chained, named) == ("CommandError", 0, False, False)
    assert refused_after == ((0, 0), 0, 0)
    assert (run.error, run.fields is not None, _seed_rows()) == (None, True, (1, 2))


@DB
def test_ia_16_output_counts_first_run_and_rerun(
    settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(설계 D19 7 · 8 · data-model §1 「세부」 T073 보정 2026-11-16 — `env=`): 쓰기 켬 · 소속 · attribute 없음 → 첫
    실행(--tenant-id 대문자 — 소문자 정규형으로 조회 · 기록 · 출력) `OK env=<ENV 설정> tenant=<소문자> memberships=created:2/
    unchanged:0 authentik=written fga=ok`(stdout 전체가 그 줄 하나 · stderr 빔 — 검증 7V-3 · sub 없음) · OpenFGA 요청 =
    `POST /stores/<store>/write` 하나 · 본문 {"writes": {"tuple_keys": [owner · member], "on_duplicate": "ignore"}} ·
    Tenant(id 소문자 · joshuatech · JoshuaTech · active) / 재실행(소문자) → `created:0/unchanged:2 authentik=unchanged` ·
    Authentik 쓰기 그대로 · 행 스냅숏 그대로 · 튜플 둘."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    settings.AUTHENTIK_WRITES_ENABLED = True
    store = settings.OPENFGA_STORE_ID
    expected_env = settings.ENV
    _seed_world(ia73_authentik)
    first = _seed({"--tenant-id": SEED_TENANT.upper()})
    first_fields = first.fields
    fga_requests = [(request.method, request.path, request.body) for request in ia73_openfga.requests]
    writes = len(ia73_authentik.mutations())
    snapshot = _seed_snapshot()
    rerun = _seed()
    rerun_fields = rerun.fields
    rerun_state = (len(ia73_authentik.mutations()), _seed_snapshot() == snapshot, ia73_openfga.tuples)
    subs_printed = (first.shows(SEED_OWNER, SEED_MEMBER), rerun.shows(SEED_OWNER, SEED_MEMBER))
    # 출력 전체(계약 범위 = 명령 출력 stdout · stderr): stdout이 OK 줄 하나(접두 없는 둘째 줄도 없다) · stderr가 비었다
    only_ok_line = ((first.out_lines, first.err_lines) == (1, 0), (rerun.out_lines, rerun.err_lines) == (1, 0))
    expected_body = {
        "writes": {
            "tuple_keys": [
                {"user": f"user:{SEED_OWNER}", "relation": "owner", "object": f"tenant:{SEED_TENANT}"},
                {"user": f"user:{SEED_MEMBER}", "relation": "member", "object": f"tenant:{SEED_TENANT}"},
            ],
            "on_duplicate": "ignore",
        }
    }
    printed = {"env": expected_env, "tenant": SEED_TENANT}  # 두 실행에 같은 칸
    first_expected = {**printed, "created": "2", "unchanged": "0", "authentik": "written"}
    rerun_expected = {**printed, "created": "0", "unchanged": "2", "authentik": "unchanged"}

    assert (first.error, first.lines, rerun.error, rerun.lines) == (None, 1, None, 1)
    assert first_fields == first_expected
    assert fga_requests == [("POST", f"/stores/{store}/write", expected_body)]
    assert (writes, snapshot[0]) == (4, frozenset({(SEED_TENANT, SEED_SLUG, SEED_DISPLAY, "active")}))
    assert rerun_fields == rerun_expected
    assert rerun_state == (4, True, SEED_TUPLES)
    assert (subs_printed, only_ok_line) == ((False, False), (True, True))


@DB
def test_ia_16_env_missing_refused_before_any_call(
    settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(출력 줄의 `env=` — revoke_sessions와 같은 설정 · 같은 판정 자리): 설정에 ENV가 없는 프로필(migrate 등)에서 명령 →
    조회 · 쓰기 전에 CommandError(returncode 1 · 출력 줄 0) · 두 가짜의 요청 0 · DB 행 0(DB · 파생을 다 쓴 뒤 출력 줄을 못 찍고
    끝나지 않는다) / 짝: ENV를 되돌린 같은 인자 → OK · `env=<ENV>` · 행 3."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    _seed_world(ia73_authentik)
    saved_env = settings.ENV
    del settings.ENV
    refused = _seed()
    after = (_calls(ia73_authentik, ia73_openfga), _seed_rows())
    settings.ENV = saved_env
    run = _seed()
    printed_env = None if run.fields is None else run.fields["env"]

    assert (refused.error, refused.returncode, refused.lines) == ("CommandError", ERROR_EXIT_SEED, 0)
    assert after == ((0, 0), (0, 0))
    assert (run.error, printed_env, _seed_rows()) == (None, saved_env, (1, 2))


# 쓰기 끔의 어긋남(설계 D19 6) — case → (그룹 소속 pk, attributes(pk별), 기대 drift).
DRIFT_CASES: dict[str, tuple[tuple[int, ...], dict[int, dict[str, str]], int]] = {
    "none-present": ((), {OWNER_PK: {"existing": "keep"}, MEMBER_PK: {}}, 4),
    "all-present": (
        (OWNER_PK, MEMBER_PK),
        {OWNER_PK: {"tenant_id": SEED_TENANT}, MEMBER_PK: {"tenant_id": SEED_TENANT}},
        0,
    ),
    "owner-membership-only": ((OWNER_PK,), {OWNER_PK: {}, MEMBER_PK: {}}, 3),
}


@DB
@pytest.mark.parametrize("case", sorted(DRIFT_CASES))
def test_ia_16_writes_off_reports_drift(
    case: str, settings: SettingsWrapper, ia73_authentik: FakeAuthentikExt, ia73_openfga: FakeOpenFga
) -> None:
    """ia-16(설계 D19 6 · 〔Y19〕): 쓰기 끔(dev — ENV 설정도 dev로 덮는다) → 쓰지 않고 어긋난 항목 수(사용자 둘 × 소속 · attribute
    = 0-4)를 `authentik=skipped(drift=<n>)`로 싣는다 — 아무것도 없음 4 · 다 있음 0 · owner 소속만 있음 3 · 출력의 `env=dev`(호출
    시점의 설정 — import 시점 상수로 읽는 구현은 test를 찍는다) · Authentik 요청은 조회 셋뿐(그룹 1 · 사용자 2 — 추가 호출 없음) ·
    OpenFGA는 쓴다(튜플 둘)."""
    assert SEED in get_commands(), NO_SEED_COMMAND
    assert settings.AUTHENTIK_WRITES_ENABLED is False
    settings.ENV = "dev"
    member_of, attributes, drift = DRIFT_CASES[case]
    _seed_world(ia73_authentik, member_of=member_of, attributes=attributes)
    run = _seed()
    printed_env = None if run.fields is None else run.fields["env"]
    routes = sorted(_routes(ia73_authentik.requests))
    tuples = ia73_openfga.tuples

    assert (run.error, _authentik_state(run), printed_env) == (None, f"skipped(drift={drift})", "dev")
    assert routes == [("GET", "groups"), ("GET", "users"), ("GET", "users")]
    assert tuples == SEED_TUPLES
