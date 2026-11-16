"""T073 ia 작업 시험 — 위임 · 재적용 · 대조(설계 D1 · D26 — 묶음은 조각마다 이 파일에 더한다).

조각 ③-b1 묶음(위임 enqueue — 작업 본체는 조각 ⑤-b):
- ia-11(D16 · D12 6단계 ④ · D18): 커밋 뒤 콜백의 Authentik 세션 삭제 위임 조건과 enqueue 꼴. 이음매는
  `identity_admin.celery.app.send_task`(돌려받은 앱 객체의 속성을 덮어 센다 — 콜백이 호출 때마다 앱을 가져와 속성으로 부른다).
  「0회」 사례보다 먼저 같은 가로채기로 「사용자 단위 + 쓰기 켬 → 1회」를 단언한다(설계 D26 「이음매」).
  - 1회: 사용자 단위(본인 all_devices · 관리자 호출) + 쓰기 켬 + 자격이 자리값 아님 → 이름이 글자 그대로
    `identity_admin.tasks.revoke_authentik_sessions` · args (sub, nbf) · expires = nbf + 300의 UTC 시각 · retry_policy
    `{"max_retries": 0}` · argsrepr에 sub 없음 + INFO `authentik.revoke_enqueued`(sub_hash).
  - 0회: 쓰기 끔(INFO `authentik.revoke_skipped reason=writes_disabled`) · 자리값 자격(WARNING `authentik.calls_disabled
    reason=placeholder_credential`) · sid 단위 · 커밋 뒤 SET이 `unreachable`(DRAGONFLY_URL 닫힌 포트 — `record_revocation`을 직접
    부른다 · INFO `authentik.revoke_skipped reason=denylist_unreachable`) · 서명된 logout 웹훅(조각 ③-b2 — 출처가 Authentik).
  - enqueue 실패 → WARNING `authentik.revoke_enqueue_failed`(error = 예외 클래스 이름 · 예외 문구 없음) · 행은 커밋된 그대로.
  - `Recorded.after`: denylist · delegate 두 칸(위임하지 않는 호출은 delegate None).

조각 ③-b1 리뷰 반영(조각 ③-b2 첫 단계): S2 — `record_revocation(sid=<값>, delegate=True)`는 ValueError(위임은 사용자 단위
행에만) · S5 — enqueue 옵션의 키 집합 · 판정 순서(쓰기 플래그 → 자리값 자격 → 커밋 뒤 SET 결과).

조각 ⑤-a 묶음(무조건 재적용 · 로그 purge · beat 배선 · beat_init — 설계 D14 · D15 · D29 · D26). 작업은 T066처럼
`app.loader.import_default_modules()` 뒤 `app.tasks["identity_admin.tasks.<이름>"]`로 찾고 `apply()`로 같은 프로세스에서 돈다
(eager 끔 · 브로커 없음). 시각 경계 · TTL 기대값은 DB 시계(`db_now`)로 잰다 · TTL 여유 ± 5.
- ia-9(D14 첫 SQL): 같은 sub 활성 행 둘을 nbf 역순으로 넣는다 → `revoked:sub` = 큰 nbf · TTL은 그 행 기준 / 같은 sid 둘 → 키 하나.
- ia-10(D14 TTL < 1): 만료 0.4 s 전 sid 행 → 그 키 없음 · 오류 0 · 반환 skipped 1 · 다른 키는 그대로. 조회 시점에 행이 (0, 1)초
  창 밖이었으면(반환 rows로 판정) 행을 새로 넣고 다시 한다(최대 5회 — 창을 놓친 실행이 공허하게 통과하지 않게).
- ia-10 옆(수정 라운드 H6 — 하한 쪽 TTL < 1): 하한 창 끝 0.4 s 안의 사용자 단위 행(expires_at = DB now − 30 d + 0.4 s) → 그 sub의
  하한 키 없음 · skipped 1 · failed 0 · floors 1(대조용 행의 몫) · 창 판정은 `skipped + failed == 1`(최대 5회).
- ia-32(D29 재적용의 하한): 창 경계(expires_at = DB now − 30 d ± 1 h 가운데 안쪽만) · sid 행 제외 · sub별 최댓값 · TTL ± 5 · 두 번
  돌려도 TTL이 늘지 않는다 · FLUSHALL 뒤 복원.
- ia-33(D29 불변식 2): api-34와 같은 세 행 — purge 대상 ⇔ 하한 대상 아님 / 이음매 `session_floor.REVOCATION_LOG_RETENTION`을
  다른 값으로 덮으면 purge 경계와 재적용의 하한 창이 함께 움직인다(SQL · purge에 30일 리터럴이 남아 있으면 깨진다).
- ia-33 옆(수정 라운드 H4 — purge 실패 위생): 짝 = 그대로 SUCCESS · 정수 / 이음매 `denylist_writer.purge_log`가 DB 접속 실패 꼴
  문구(호스트 · IP · role)의 예외를 던지면 → FAILURE · PurgeFailed(문구 · 연쇄 없음) · WARNING `session_revocation_log.purge_failed`
  (error = 클래스 이름) 한 줄 · 로그 · 트레이스백에 심은 값 0.
- ia-38(D14 신선도 키 · 반환 계약): 행 0 → 신선도 키(값 = 작업 시각 · TTL ∈ [290, 300]) · 다섯 건수 0 · `revoked:*` 0 / 행을 넣고
  → 반환 dict의 키가 정확히 다섯(정수) · 값 = 실제 키 수 / 닫힌 포트 → 작업 실패(성공 아님 · ReapplyFailed 문구 없음 · 연쇄 없음 —
  `__cause__` · `__context__` 둘 다 None: 수정 라운드 H3) · WARNING `denylist.reapply_failed phase=tick` · 로그 · 트레이스백에 호스트 ·
  포트 · 비밀번호 없음(짝: 같은 준비물의 실제 Dragonfly → 성공) / beat 항목 `reconcile-denylist`의 options == {"expires": 30}(D15).
- ia-38 옆(수정 라운드 H1 — 명령 단위 실패): 이음매 `session_floor.FLOOR_KEY_PREFIX`를 pod 사용자 ACL 밖 접두로 덮으면 실제
  Dragonfly가 그 명령에만 NOPERM → 작업 SUCCESS · failed 1 · WARNING `denylist.reapply_failed`(failed 1 ·
  error NoPermissionError · phase 없음) 한 줄 · 다른 명령은 적용 / 신선도 키도 ACL 밖으로 덮으면 failed 2(신선도 키 포함).
- ia-38 옆(수정 라운드 H2 — 유휴 연결 버리기): TcpRelay를 거친 pod 사용자 · 첫 재적용 → apply_user(워커의 다른 작업이 남기는
  유휴 연결) → freeze()(FIN 없는 죽은 연결) · admin FLUSHALL → 둘째 재적용도 SUCCESS · failed 0 · 세 키 복귀 · 실패 줄 0.
- ia-38 옆(수정 라운드 H3 — 연쇄 없음의 OS 무관 판별): 이음매 `denylist_writer.reapply`가 호스트 · 포트 · 비밀번호 · sub 꼴을 심은
  예외를 던지면 → 작업 FAILURE · ReapplyFailed(문구 "" · 연쇄 없음) · WARNING(phase tick) / 같은 덮기 아래 beat_init → 수신자
  예외 0 · WARNING(phase beat_init) · 로그 · 트레이스백에 심은 값 0(짝: 덮기 전 SUCCESS).
- ia-38 옆(수정 라운드 H7 — 묶음 경계): 이음매 `denylist_writer.REAPPLY_BATCH` 2 · 명령 다섯 → 그대로 SUCCESS · 다섯 키 / 기록하는
  대리(이음매 `denylist_writer.client`) → pipeline 매번 transaction 거짓 · execute 매번 raise_on_error 거짓 · 묶음 [2, 2, 1] ·
  마지막 명령 = 신선도 키 / 둘째 묶음에서 끊김 → FAILURE · 신선도 키 없음 · 첫 묶음의 `revoked:*` 둘 · 하한 0 · 문구 0.
- ia-40(D26 실제 worker + beat — 템플릿 실제 워커 시험의 도우미를 tests.test_outbox에서 이름으로 가져온다): pod 사용자로 띄운 뒤
  beat_init 재적용이 세 키를 만든다 · `denylist.reapplied phase=beat_init floors ≥ 1 failed 0` · tick이 실제로 돈다(신선도 값 전진
  또는 성공 줄 — 뺄 수 없는 단언 · 75 s 안: tick 둘 + 15 s — 수정 라운드 H5) · admin FLUSHALL 뒤 75 s 안에 세 키 복귀
  (VD-T073-15 (a)) · NOPERM 0 · 로그에 비밀번호 · 원문 sub 0 · 멈춤 신호 뒤 상한 안에 스스로 끝났다(POSIX는 종료 코드 0 · 남은
  프로세스 0 — 템플릿 실제 워커 시험과 같은 멈춤 단언) · 작업 실패 0(Celery 실패 줄 · `denylist.reapply_failed` — 위임 · 대조의
  자리 표시 본체가 없어진 조각 ⑤-b부터 단언한다).
- ia-11 옆(D15 · D16 등록): 위임 enqueue 이름 `revocation.DELEGATION_TASK`가 app.tasks에 글자 그대로 있다 · 그 작업의 옵션 · 상수 셋.

조각 ⑤-a 수정 라운드 검증 반영(조각 ⑤-b 첫 단계 W1 · W2): 유휴 연결 버리기의 세 성질 — 중계가 받은 연결 수 (1, 2) · 기록 대리가
풀 disconnect와 pipeline 생성을 한 줄로 남긴다(첫 항목 disconnect(inuse_connections=False) · 한 번뿐) / 심은 문구 사례는 결과
예외의 문구 · 로그의 error 필드를 단언 앞에서 불리언으로 접는다.

조각 ⑤-b 묶음(위임 본체 · 대조 — 설계 D16 · D17 · D18 · D25 · P5 실패 틀). 작업은 `_task(<이름>).apply(...)`로 같은 프로세스에서
돈다(eager — 위임의 재시도도 그 자리에서 돈다 · 결과는 .state · .result로 본다). 가짜는 확장 가짜 Authentik(ia73_authentik)이다.
- ia-12(D16 — 브로커 · DB 없음): 대상 세션만 지운다(필터 무시 미끼 · 남의 세션은 남는다 · 반환 = deleted 정수) · DELETE 404 =
  gone(deleted와 갈라 센다) · UUID 꼴이 아닌 세션 uuid → DELETE 0 · skipped · 503 두 번 뒤 성공(재시도 줄은 인자 없는
  AuthentikTransient()) · 403이면 그 자리에서 끝(재시도 없음) · 창(nbf + 300 s) 지남 → 호출 0 · 쓰기 끔 · 자리값 → 호출 0 · 마감
  0 s → 호출 0 · 재시도가 다 쓰인 뒤 FAILURE(AuthentikTransient) · 끝나지 않는 next → 세션 목록 정확히 10쪽 · 사용자 조회 꼴
  (없음 · pk bool · username 빈 값 · 같은 uuid 둘 · sub 문자 규칙) · 예상 밖 예외 → DelegationFailed(문구 · 연쇄 없음).
- ia-13(D17 — DB): 누락 logout → 행 · outbox · nbf = ⌊created⌋ + 1 · event_pk 정규형 · 세션 하한만 남는다 / 이미 있는 pk → 사용자
  조회 0 / 멤버십 없음 → 건너뜀 / 필터 무시 · 정렬 뒤섞기 미끼(login · 73 h 전 · user 없는 세 꼴 · 정수 pk) / 창 위쪽 끝(+ 600 s ·
  + 1 h → 행 · outbox · 키 0 · + 290 s → 기록) / 둘째 쪽 · 50쪽 상한 · reconcile_truncated / 자리값 · 이벤트 조회 403 · 404 · 둘째 쪽
  503 · 마감 0 s / 사용자 조회 캐시 · 전부 404 → reconcile_skipped reason=user_lookup · 하나만 404 · 403 → 뒤 호출 0 / hex 32자 pk ↔
  대시 꼴 웹훅 행 / 예상 밖 예외 → ReconcileFailed(앞서 기록한 행은 남는다).
- ia-11 옆(P1 — 3b1B-9): 하위 프로세스 `manage.py revoke_sessions`의 실제 발행 → 시험 Dragonfly(pod 사용자) → 실제 워커 → 가짜
  Authentik DELETE(대상 세션만) · 워커 로그의 revoke_done · 원문 sub · 비밀 0 · NOPERM 0 · 멈춤(POSIX는 종료 코드 0 · 남은 프로세스 0).

조각 ⑤-b 수정 라운드(리뷰 5bA · 5bB — J1–J8):
- J1: 재시도 줄은 「 retry: 」 뒤 꼬리만 본다(`Retry in 5s: AuthentikTransient()` · `Retry in 10s: …` — 작업 id는 「503」이 든 강제 id).
- J2(ia-13): 대조의 건너뜀을 「대상 아님」(action이 logout이 아닌 str · 창 밖 · 이미 기록됨 · 사용자 404 · 멤버십 없음 · Replayed —
  세지 않는다)과 「꼴 어긋남」(action이 str이 아님 · logout인데 created를 못 읽음 · 창 안 logout의 user.pk · 이벤트 pk 꼴 밖 · 사용자
  응답의 uuid 꼴 밖 · 응답 pk ≠ 요청 pk — 센다)으로 가른다 → 완주한 실행 끝에 WARNING `authentik.reconcile_skipped reason=malformed
  count=<이벤트 수>`(실패 갈래 0줄) · 정상 실행에는 그 줄이 없다.
- J3(ia-12): 빈 sub · lone surrogate sub · nbf str · float → 실패 틀 안의 `invalid_request`(sub_hash는 sub가 문자 규칙을 지날 때만).
- J4(ia-11 옆 · ia-12 옆): 재시도 재발행의 argsrepr 가림 — 등록 옵션 `retry_kwargs` · 워커 꼴 요청의 재발행을 send_task 이음매에서 본다.
- J5(ia-12 · ia-13): `outbound.request_json`을 감싸 모든 호출의 deadline이 한 객체임을 본다.
- J6(ia-13): 이벤트 하나 앞의 마감 확인 — 이음매 `outbound.Deadline`을 깃발 가짜로 덮는다.
- J7: `…Z` 소수 초 없는 created · 재확인 미끼 넷(tz 없음 · 정수 created · user.pk `"301"` · `True`) · 실패 갈래 로그의 URL 부재.
- J8: 단언 꼴(지역 변수) · P1의 POSIX 멈춤 단언 · 머리 독스트링 정정.

DB에 닿는 시험의 마크는 `_ia_support.DB`다. 구현 모듈은 시험 함수 안에서 `impl`로 가져온다. 단언 꼴: 결과를 지역 변수에 묶은
뒤 단언한다(자격 · 토큰 · 비밀 · URL을 assert 식 안의 호출 인자로 두지 않는다 — build-notes R0-2 · 규칙 §Tests).
"""

from __future__ import annotations

import json
import math
import secrets
import subprocess
import sys
import time
import uuid
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, Any
from urllib.parse import urlsplit

import pytest
from django.test import Client
from redis.exceptions import ConnectionError as RedisConnectionError

from tests._boot import assert_absent, url_password
from tests._ia_fakes import TcpRelay, make_event, make_session
from tests._ia_support import (
    DB,
    FRESHNESS_KEY,
    REVOKE_PATH,
    TENANT_A,
    auth_headers,
    bearer_token,
    db_now,
    floor_key,
    impl,
    insert_log_row,
    insert_row,
    log_events,
    model,
    post_webhook,
    read_int,
    read_ttl,
    scan_keys,
    send,
    sid_key,
    signed_webhook,
    sub_key,
    timed,
)
from tests._identity_fakes import closed_port
from tests._secret import Secret

# 템플릿 실제 워커 시험의 도우미(이름으로 가져온다 — 시험 함수는 가져오지 않는다: 두 번 수집된다 · 재생성으로 이름이 바뀌면 수집에서
# 시끄럽게 깨진다 — 설계 D26 · §9)
from tests.test_outbox import (
    NOPERM_MARKERS,
    POD_ROOT,
    WINDOWS,
    _celery_commands,
    _child_env,
    _start,
    _stop,
    _tails,
    _wait_for,
)

if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path

    import redis
    from django.http import HttpResponse
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, JwksInfo, LogLines, PgInfo
    from tests.test_outbox import CeleryProcess, Stopped

pytestmark = pytest.mark.usefixtures("ia73_env")

TASK_REVOKE = "identity_admin.tasks.revoke_authentik_sessions"  # 이름으로 보낸다(작업 본체는 조각 ⑤-b · 설계 D16)
DELEGATION_WINDOW_S = 300  # 위임 창 = nbf + 300 s(메시지 expires)
REDACTED_ARGSREPR = "(<redacted>)"  # 위임 메시지의 인자 표시(발행 쪽 · 재시도 재발행 쪽 모두 — 설계 D16 「enqueue 꼴」)
PLACEHOLDER_TOKEN = "PLACEHOLDER-SET-BY-OPERATOR"  # 자리값 자격(conf.PLACEHOLDER_MARK를 담는다 · 숫자 없음)
ADMIN_GROUP = "platform-admin"
ENQUEUED = "authentik.revoke_enqueued"
SKIPPED = "authentik.revoke_skipped"
DISABLED = "authentik.calls_disabled"
ENQUEUE_FAILED = "authentik.revoke_enqueue_failed"


class BrokerDownError(Exception):
    """시험이 심는 enqueue 실패(문구에 자격 URL 모양을 심어 로그에 실리지 않는지 본다)."""


def _spy(monkeypatch: pytest.MonkeyPatch, *, fail_with: Exception | None = None) -> list[dict[str, Any]]:
    """`identity_admin.celery.app.send_task`를 덮어 호출을 기록한다(fail_with이 있으면 기록한 뒤 그 예외를 던진다)."""
    app = impl("celery").app
    calls: list[dict[str, Any]] = []

    def fake_send_task(name: str, args: Any = None, kwargs: Any = None, **options: Any) -> None:
        calls.append({"name": name, "args": args, "kwargs": kwargs, "options": options})
        if fail_with is not None:
            raise fail_with

    monkeypatch.setattr(app, "send_task", fake_send_task)
    return calls


def _headers(jwks: JwksInfo, sub: str, *, sid: str | None = "sid-1", groups: Any = None) -> dict[str, str]:
    return auth_headers(jwks, bearer=bearer_token(jwks, sub, TENANT_A, sid=sid, groups=groups))


def _revoke(client: Client, headers: dict[str, str], body: dict[str, Any]) -> HttpResponse:
    return send(client, "post", REVOKE_PATH, headers, body)


def _nbf(response: HttpResponse) -> int | None:
    return json.loads(response.content).get("nbf") if response.status_code == 202 else None


def _call_record(sub: str, *, nbf: int, delegate: bool) -> Any:
    """`revocation.record_revocation`을 바깥 트랜잭션 없이 직접 부른다(사용자 단위 · 테넌트 A · source revoke)."""
    return impl("revocation").record_revocation(
        tenant_id=uuid.UUID(TENANT_A),
        sub=sub,
        sid=None,
        reason="logout_all",
        nbf=nbf,
        source="revoke",
        delegate=delegate,
    )


def _pod_like_closed_url() -> Secret:
    return Secret(f"redis://identity-admin:{secrets.token_urlsafe(16)}@127.0.0.1:{closed_port()}/0")


# --- ia-11(D16 — 위임 enqueue 조건과 꼴) ---------------------------------------------------------------------------


@DB
def test_ia_11_enqueue_conditions_over_http(
    jwks_server: JwksInfo, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-11(HTTP) — 같은 가로채기로 먼저 1회: 본인 all_devices + 쓰기 켬 → send_task 1회(이름 · args · expires · retry_policy ·
    argsrepr · 옵션 키 정확히 셋) + INFO `authentik.revoke_enqueued`(sub_hash · 원문 sub 없음) · 관리자 호출(사용자 단위) + 쓰기
    켬 → 1회 / 0회: 쓰기 끔 · 자리값 자격 · 쓰기 끔 + 자리값(쓰기 끔 줄 하나뿐) · 서명된 logout 웹훅(쓰기 켬 · 사용자 단위 —
    조각 ③-b2) · sid 단위(쓰기 켬). 사례마다 다른 sub(앞 사례의 폐기가 뒤 토큰을 거부하지 않게)."""
    from django_common.observability import sub_hash

    for member in ("ia11-target", "ia11-webhook"):
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=member, role="member")
    calls = _spy(monkeypatch)
    client = Client()

    def revoke_with(body: dict[str, Any]) -> Callable[[str], int]:
        return lambda case_sub: _revoke(client, _headers(jwks_server, case_sub), body).status_code

    def signed_logout_webhook(case_sub: str) -> int:
        _, body, signature = signed_webhook(settings.AUTHENTIK_WEBHOOK_SECRET, sub=case_sub, nbf=int(time.time()) - 2)
        return post_webhook(client, body, signature).status_code

    settings.AUTHENTIK_WRITES_ENABLED = True
    log_lines()
    first = _revoke(client, _headers(jwks_server, "ia11-self"), {"all_devices": True, "reason": "logout_all"})
    first_records = log_lines()
    first_calls = list(calls)
    admin = _revoke(
        client,
        _headers(jwks_server, "ia11-admin", groups=[ADMIN_GROUP]),
        {"sub": "ia11-target", "all_devices": True, "reason": "admin"},
    )
    admin_calls = calls[len(first_calls) :]
    all_devices = revoke_with({"all_devices": True, "reason": "logout_all"})
    # 0회 사례(설정 덮기, 요청) — 요청은 사례 sub(`ia11-<사례>`)로 보낸다.
    zero_cases: dict[str, tuple[dict[str, Any], Callable[[str], int]]] = {
        "writes-off": ({"AUTHENTIK_WRITES_ENABLED": False}, all_devices),
        "placeholder-token": ({"AUTHENTIK_API_TOKEN": PLACEHOLDER_TOKEN}, all_devices),
        # S5 2 — 판정 순서는 쓰기 플래그 → 자리값 자격(dev의 US6 기간 구성이 이 조합이다 · calls_disabled 경보가 울지 않는다)
        "writes-off-placeholder-token": (
            {"AUTHENTIK_WRITES_ENABLED": False, "AUTHENTIK_API_TOKEN": PLACEHOLDER_TOKEN},
            all_devices,
        ),
        # 웹훅은 위임하지 않는다(출처가 Authentik이다 · 설계 D16 「위임 조건」 — 조각 ③-b2)
        "webhook": ({}, signed_logout_webhook),
        # sid 단위는 마지막이다 — 기본 sid(sid-1)의 revoked:sid 키가 생겨 뒤의 기본 sid Bearer 사례가 401이 된다.
        "sid-scope": ({}, revoke_with({"all_devices": False, "reason": "logout"})),
    }
    token = settings.AUTHENTIK_API_TOKEN
    zero_outcomes: dict[str, tuple[int, int, list[tuple[Any, Any]]]] = {}
    for case, (overrides, request) in zero_cases.items():
        settings.AUTHENTIK_WRITES_ENABLED = True
        settings.AUTHENTIK_API_TOKEN = token
        for name, value in overrides.items():
            setattr(settings, name, value)
        before = len(calls)
        log_lines()
        status = request(f"ia11-{case}")
        events = [
            (line.get("event"), line.get("reason"))
            for line in log_lines()
            if str(line.get("event", "")).startswith("authentik.")
        ]
        zero_outcomes[case] = (status, len(calls) - before, events)

    (call,) = first_calls if len(first_calls) == 1 else (None,)
    nbf = _nbf(first)
    options = {} if call is None else call["options"]
    option_keys = sorted(options)  # S5 1 — 옵션을 더한 구현(예: 설계 D16의 4 s 경로 retry=False)이 지나지 않게
    shape = None if call is None else (call["name"], tuple(call["args"] or ()), call["kwargs"])
    expires = options.get("expires")
    argsrepr = str(options.get("argsrepr"))
    enqueued = log_events(first_records, ENQUEUED)
    enqueued_fields = [(line.get("level"), line.get("sub_hash")) for line in enqueued]
    raw_sub_logged = "ia11-self" in json.dumps(first_records)
    admin_shape = [(c["name"], tuple(c["args"] or ())) for c in admin_calls]
    admin_expected = (202, [(TASK_REVOKE, ("ia11-target", _nbf(admin)))])

    assert (first.status_code, len(first_calls)) == (202, 1)
    assert shape == (TASK_REVOKE, ("ia11-self", nbf), None)
    assert option_keys == ["argsrepr", "expires", "retry_policy"]
    assert isinstance(nbf, int) and expires == datetime.fromtimestamp(nbf + DELEGATION_WINDOW_S, UTC)
    assert options.get("retry_policy") == {"max_retries": 0}
    assert ("ia11-self" in argsrepr, argsrepr) == (False, REDACTED_ARGSREPR)
    assert enqueued_fields == [("info", sub_hash("ia11-self"))]
    assert raw_sub_logged is False
    assert (admin.status_code, admin_shape) == admin_expected
    assert zero_outcomes == {
        "writes-off": (202, 0, [(SKIPPED, "writes_disabled")]),
        "placeholder-token": (202, 0, [(DISABLED, "placeholder_credential")]),
        "writes-off-placeholder-token": (202, 0, [(SKIPPED, "writes_disabled")]),
        "webhook": (202, 0, []),
        "sid-scope": (202, 0, []),
    }


@DB
def test_ia_11_unreachable_denylist_skips_enqueue(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-11(직접 호출 — 설계 D12 ④ · 〔Y18〕) — 쓰기 켬 · 같은 가로채기: 실제 Dragonfly → `after` = (ok, enqueued) · 1회 /
    DRAGONFLY_URL 닫힌 포트(커밋 뒤 SET이 `unreachable`) → `after` = (unreachable, skipped) · 0회 · INFO
    `authentik.revoke_skipped reason=denylist_unreachable` 한 줄 / 위임하지 않는 호출(delegate 거짓) → `after.delegate` None.
    S5 3(판정 순서 — 자리값 자격이 `unreachable` 판정보다 앞이다): 쓰기 켬 + 자리값 자격 + 닫힌 포트 → `after` = (unreachable,
    skipped) · 0회 · WARNING `authentik.calls_disabled` 한 줄 · `authentik.revoke_skipped` 0줄."""
    calls = _spy(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    nbf = int(time.time()) + 1
    live = _call_record("ia11-live-sub", nbf=nbf, delegate=True)
    live_calls = len(calls)
    plain = _call_record("ia11-plain-sub", nbf=nbf, delegate=False)
    settings.DRAGONFLY_URL = _pod_like_closed_url()
    log_lines()
    down = _call_record("ia11-down-sub", nbf=nbf, delegate=True)
    records = log_lines()
    skipped = [(line.get("level"), line.get("reason")) for line in log_events(records, SKIPPED)]
    settings.AUTHENTIK_API_TOKEN = PLACEHOLDER_TOKEN
    placeholder = _call_record("ia11-placeholder-down-sub", nbf=nbf, delegate=True)
    placeholder_records = log_lines()
    placeholder_lines = {
        "disabled": [(line.get("level"), line.get("reason")) for line in log_events(placeholder_records, DISABLED)],
        "skipped": log_events(placeholder_records, SKIPPED),
    }
    after = {
        "live": (live.after.denylist, live.after.delegate),
        "plain": (plain.after.denylist, plain.after.delegate),
        "down": (down.after.denylist, down.after.delegate),
        "placeholder-down": (placeholder.after.denylist, placeholder.after.delegate),
    }
    rows = model("session_revocation_log").objects.count()

    assert live_calls == 1
    assert len(calls) == 1
    assert after == {
        "live": ("ok", "enqueued"),
        "plain": ("ok", None),
        "down": ("unreachable", "skipped"),
        "placeholder-down": ("unreachable", "skipped"),
    }
    assert skipped == [("info", "denylist_unreachable")]
    assert placeholder_lines == {"disabled": [("warning", "placeholder_credential")], "skipped": []}
    assert rows == 4


@DB
def test_ia_11_delegate_requires_user_scope(settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-11 옆(S2 — 설계 D16 「위임 조건」: 위임은 사용자 단위 행에만 붙는다): 쓰기 켬 · 같은 가로채기 아래
    `record_revocation(sid=<값>, delegate=True)` → ValueError(문구에 값 없음) · 로그 행 0 · outbox 0 · 호출 0 / 짝: 같은 인자에
    sid=None → Recorded · 호출 1회."""
    revocation = impl("revocation")
    calls = _spy(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    sid = "ia11-s2-sid"
    args: dict[str, Any] = {
        "tenant_id": uuid.UUID(TENANT_A),
        "sub": "ia11-s2-sub",
        "reason": "logout",
        "nbf": int(time.time()) + 1,
        "source": "revoke",
        "delegate": True,
    }
    refused: tuple[str, bool] | None = None
    try:
        revocation.record_revocation(sid=sid, **args)
    except ValueError as exc:
        refused = (type(exc).__name__, sid in str(exc))
    written = (model("session_revocation_log").objects.count(), model("outbox").objects.count(), len(calls))
    pair = revocation.record_revocation(sid=None, **args)

    assert refused == ("ValueError", False)
    assert written == (0, 0, 0)
    assert (type(pair).__name__, len(calls)) == ("Recorded", 1)


@DB
def test_ia_11_enqueue_failure_is_logged_and_committed(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-11(enqueue 실패 — 설계 D16 「실패하면 WARNING authentik.revoke_enqueue_failed error=<클래스>만」) — send_task가
    예외를 던지면 `after.delegate` = failed · WARNING 한 줄(error = 예외 클래스 이름 · 로그 줄 전부에 예외 문구 · 원문 sub 없음) ·
    행은 커밋된 그대로(1) · 거부 목록 쓰기는 ok(짝: ia-11 직접 호출의 enqueued)."""
    planted = Secret(f"redis://identity-admin:{secrets.token_urlsafe(16)}@broker.invalid:6379/0")
    calls = _spy(monkeypatch, fail_with=BrokerDownError(planted))
    settings.AUTHENTIK_WRITES_ENABLED = True
    log_lines()
    recorded = _call_record("ia11-fail-sub", nbf=int(time.time()) + 1, delegate=True)
    records = log_lines()
    failed = [(line.get("level"), line.get("error")) for line in log_events(records, ENQUEUE_FAILED)]
    text = json.dumps(records)
    leaked = (Secret(planted) in Secret(text), "ia11-fail-sub" in text)
    rows = model("session_revocation_log").objects.count()

    assert len(calls) == 1
    assert (recorded.after.denylist, recorded.after.delegate) == ("ok", "failed")
    assert failed == [("warning", "BrokerDownError")]
    assert leaked == (False, False)
    assert rows == 1


# --- 조각 ⑤-a: 재적용 · purge · beat(D14 · D15 · D29) ----------------------------------------------------------------------

TASK_RECONCILE = "identity_admin.tasks.reconcile_denylist"
TASK_PURGE_LOG = "identity_admin.tasks.purge_session_revocation_log"
TASK_RECONCILE_AUTHENTIK = "identity_admin.tasks.reconcile_authentik_sessions"
RESULT_KEYS = ("rows", "keys", "floors", "skipped", "failed")  # 반환 계약(설계 D14 · 계약 §주기 작업)
REVOCATION_TTL = timedelta(seconds=330)  # expires_at = nbf + 330 s(contracts/denylist.md §키 스키마)
RETENTION = timedelta(days=30)  # 로그 보존 · 하한 수명(session_floor.REVOCATION_LOG_RETENTION의 계약 값)
TTL_TOLERANCE_S = 5  # TTL 비교 여유(초 내림 · 작업 왕복 — T066 api-30과 같다)
FRESHNESS_TTL_S = 300  # 신선도 키 수명(contracts/denylist.md §키 스키마)
FRESHNESS_TTL_MIN_S = 290  # 신선도 키 TTL 하한(작업 직후에 읽는다 — 120 s 같은 수명은 걸린다)
IA10_ATTEMPTS = 5  # (0, 1)초 창을 놓쳤을 때 다시 하는 상한(설계 D14 ia-10)
IA10_LEAD_S = 0.4  # 만료까지 남긴 시간(ia-10)


def _at(epoch: float) -> datetime:
    return datetime.fromtimestamp(epoch, UTC)


def _epoch_floor(value: datetime) -> int:
    return math.floor(value.timestamp())


def _remaining(expires_at: datetime, now: datetime) -> int:
    """⌊expires_at − now⌋ 초(DB 시계 기준 기대 TTL)."""
    return math.floor((expires_at - now).total_seconds())


def _celery_app() -> Any:
    """identity_admin.celery.app + worker · beat처럼 기본 모듈 적재(autodiscover — T066 `_celery_app`과 같은 꼴 · 그 모듈에서
    가져오지 않는다)."""
    app = impl("celery").app
    app.loader.import_default_modules()
    return app


def _task(name: str) -> Any:
    """등록된 작업(없으면 유한한 실패 — 「등록되지 않았다」)."""
    task = _celery_app().tasks.get(name)
    if task is None:
        pytest.fail(f"Celery 작업 {name}이 등록되지 않았다", pytrace=False)
    return task


def _run(name: str) -> Any:
    """작업을 같은 프로세스에서 1회(apply) — 성공이어야 하고 반환값을 준다(실패는 예외 종류만 싣는다)."""
    result = _task(name).apply()
    if not result.successful():
        pytest.fail(f"{name} 실패: {type(result.result).__name__}", pytrace=False)
    return result.result


def _reconcile() -> dict[str, Any]:
    """reconcile_denylist 1회 — 반환 dict(아니면 유한한 실패)."""
    outcome = _run(TASK_RECONCILE)
    if not isinstance(outcome, dict):
        pytest.fail(f"reconcile_denylist 반환이 dict가 아니다: {type(outcome).__name__}", pytrace=False)
    return outcome


def _floor_state(client: redis.Redis, subs: tuple[str, ...]) -> dict[str, int | None]:
    """sub별 세션 하한 값(없으면 None)."""
    return {sub: read_int(client, floor_key(sub)) for sub in subs}


def _floor_ttls(client: redis.Redis, subs: tuple[str, ...]) -> dict[str, int]:
    return {sub: read_ttl(client, floor_key(sub)) for sub in subs}


def _drifts(actual: dict[str, int], expected: dict[str, int]) -> dict[str, int]:
    """키별 |실제 TTL − 기대 TTL|."""
    return {name: abs(actual.get(name, -2) - value) for name, value in expected.items()}


@DB
def test_ia_9_reapply_last_row_wins(ia73_df_admin: redis.Redis) -> None:
    """ia-9(D14 첫 SQL `ORDER BY nbf, expires_at` · 같은 키는 마지막 행) — 같은 sub의 활성 사용자 단위 행 둘을 nbf 역순으로 넣는다
    (큰 nbf = 지금 − 10 먼저 · 작은 nbf = 지금 − 200 뒤) → `revoked:sub` 값 = 큰 nbf · TTL = 그 행의 ⌊expires_at − DB now⌋ ± 5 /
    같은 sid의 행 둘(역순 — 지금 − 20 · 지금 − 250) → `revoked:sid` 키 하나 · TTL은 큰 nbf 행 기준 · `revoked:*` 키 정확히 둘 ·
    반환 rows 4 · keys 2 · floors 1(sid 행은 하한이 없다)."""
    base = _epoch_floor(db_now())
    big_user = insert_log_row("ia9-sub", nbf=_at(base - 10))
    insert_log_row("ia9-sub", nbf=_at(base - 200))
    big_sid = insert_log_row("ia9-sid-sub", nbf=_at(base - 20), sid="ia9-sid", reason="logout")
    insert_log_row("ia9-sid-sub", nbf=_at(base - 250), sid="ia9-sid", reason="logout")
    _celery_app()  # 첫 적재 비용이 now와 작업 사이에 들지 않게(T066 api-30과 같다)
    now = db_now()
    result = _reconcile()
    keys = scan_keys(ia73_df_admin, "revoked:*")
    values = (read_int(ia73_df_admin, sub_key("ia9-sub")), ia73_df_admin.get(sid_key("ia9-sid")))
    ttls = {"sub": read_ttl(ia73_df_admin, sub_key("ia9-sub")), "sid": read_ttl(ia73_df_admin, sid_key("ia9-sid"))}
    expected_ttls = {"sub": _remaining(big_user.expires_at, now), "sid": _remaining(big_sid.expires_at, now)}
    counts = {name: result.get(name) for name in ("rows", "keys", "floors")}

    assert keys == [sid_key("ia9-sid"), sub_key("ia9-sub")]
    assert values == (base - 10, b"1")
    drifts = _drifts(ttls, expected_ttls)
    assert all(drift <= TTL_TOLERANCE_S for drift in drifts.values()), f"TTL {ttls} · 기대 {expected_ttls}"
    assert counts == {"rows": 4, "keys": 2, "floors": 1}


@DB
def test_ia_10_reapply_skips_ttl_below_one(ia73_df_admin: redis.Redis) -> None:
    """ia-10(D14 「TTL < 1 건너뜀」 — `EX 0`은 오류다) — 만료 0.4 s 전 sid 행 → 그 키 없음 · 오류 0(failed 0 · 작업 성공) · 반환
    skipped 1 · 다른 활성 행의 키(revoked:sub)는 그대로 있다. 조회 시점에 그 행이 (0, 1)초 창 안이었는지는 반환 rows로 가른다(2 =
    다른 행 + 그 행이 활성으로 읽혔다 · 1 = 이미 만료돼 창을 놓쳤다) — 놓쳤으면 새 sid로 행을 다시 넣고 다시 한다(최대 5회)."""
    base = _epoch_floor(db_now())
    insert_log_row("ia10-other", nbf=_at(base - 10))
    _celery_app()
    attempts: list[dict[str, Any]] = []
    hit: tuple[dict[str, Any], int] | None = None
    for attempt in range(IA10_ATTEMPTS):
        sid = f"ia10-sid-{attempt}"
        expires = db_now() + timedelta(seconds=IA10_LEAD_S)
        insert_log_row("ia10-sub", nbf=expires - REVOCATION_TTL, sid=sid, reason="logout", expires_at=expires)
        result = _reconcile()
        attempts.append(result)
        if result.get("rows") == 2:
            hit = (result, ia73_df_admin.exists(sid_key(sid)))
            break
    other = read_int(ia73_df_admin, sub_key("ia10-other"))

    assert hit is not None, f"{IA10_ATTEMPTS}회 모두 (0, 1)초 창을 놓쳤다(rows {[a.get('rows') for a in attempts]})"
    result, present = hit
    assert (result.get("skipped"), result.get("failed"), present) == (1, 0, 0)
    assert other == base - 10


@DB
def test_ia_10_reapply_skips_floor_ttl_below_one(ia73_df_admin: redis.Redis) -> None:
    """ia-10 옆(수정 라운드 H6 — D14 「두 SQL 모두 TTL < 1 건너뜀」의 하한 쪽) — 다른 sub의 활성 사용자 단위 행(대조용 — keys 1 ·
    floors 1)을 먼저 넣고, 사용자 단위 행 하나를 expires_at = DB now − 30 d + 0.4 s(nbf = expires_at − 330 s)로 넣은 뒤 재적용한다.
    그 행은 첫 SQL의 활성 행이 아니고(만료된 지 30일) 둘째 SQL 창의 끝 0.4 s 안이다 — 하한 TTL = ⌊(0, 1)⌋ = 0. 창 판정: 반환
    `skipped + failed == 1`이면 조회 시점에 창 안이었다(가드가 있으면 skipped 1 · 없으면 `EX 0` 오류로 failed 1 · 창을 놓쳤으면 둘 다
    0) — 놓쳤으면 새 sub로 행을 다시 넣고 다시 한다(최대 5회). 단언: keys 1 · floors 1(대조용 행의 몫뿐) · skipped 1 · failed 0 ·
    그 sub의 하한 키 없음 · 대조용 행의 `revoked:sub`와 하한 키는 있다."""
    base = _epoch_floor(db_now())
    insert_log_row("ia10f-other", nbf=_at(base - 10))
    _celery_app()
    attempts: list[dict[str, Any]] = []
    hit: tuple[dict[str, Any], str] | None = None
    for attempt in range(IA10_ATTEMPTS):
        sub = f"ia10f-sub-{attempt}"
        expires = db_now() - RETENTION + timedelta(seconds=IA10_LEAD_S)
        insert_log_row(sub, nbf=expires - REVOCATION_TTL, expires_at=expires)
        result = _reconcile()
        attempts.append(result)
        if result.get("skipped", 0) + result.get("failed", 0) == 1:
            hit = (result, sub)
            break
    other = (read_int(ia73_df_admin, sub_key("ia10f-other")), read_int(ia73_df_admin, floor_key("ia10f-other")))

    windows = [(a.get("skipped"), a.get("failed")) for a in attempts]
    assert hit is not None, f"{IA10_ATTEMPTS}회 모두 (0, 1)초 창을 놓쳤다((skipped, failed) {windows})"
    result, sub = hit
    present = ia73_df_admin.exists(floor_key(sub))
    counts = tuple(result.get(name) for name in ("keys", "floors", "skipped", "failed"))
    assert (counts, present) == ((1, 1, 1, 0), 0)
    assert other == (base - 10, base - 10)


@DB
def test_ia_32_reapply_restores_session_floors(ia73_df_admin: redis.Redis) -> None:
    """ia-32(D29 재적용의 하한 · 불변식 3) — 창 경계: expires_at = DB now − 30 d + 1 h(안쪽 → 하한 · TTL ≈ 3600) · − 30 d − 1 h
    (바깥 → 없음) / sub별 최댓값: 사용자 단위 행 둘(지금 − 2 h · 지금 − 100 → 하한 = 지금 − 100)과 같은 sub의 더 큰 nbf sid 행
    (지금 − 10 — 하한에 들지 않는다) / sid 행만 있는 sub → 없음 / TTL = ⌊그 행 expires_at + 30 d − DB now⌋ ± 5 / 두 번 돌려도
    (사이 1.2 s) 값은 같고 TTL이 늘지 않는다 / admin FLUSHALL 뒤 한 번 더 → 같은 값으로 복원 · 반환 floors 2."""
    base = _epoch_floor(db_now())
    hour = timedelta(hours=1)
    inside_expires = _at(base) - RETENTION + hour
    inside = insert_log_row("ia32-inside", nbf=inside_expires - REVOCATION_TTL, expires_at=inside_expires)
    outside_expires = _at(base) - RETENTION - hour
    insert_log_row("ia32-outside", nbf=outside_expires - REVOCATION_TTL, expires_at=outside_expires)
    insert_log_row("ia32-max", nbf=_at(base - 7200))
    top = insert_log_row("ia32-max", nbf=_at(base - 100))
    insert_log_row("ia32-max", nbf=_at(base - 10), sid="ia32-max-sid", reason="logout")
    insert_log_row("ia32-sidonly", nbf=_at(base - 20), sid="ia32-only-sid", reason="logout")
    subs = ("ia32-inside", "ia32-outside", "ia32-max", "ia32-sidonly")
    expected = {
        "ia32-inside": _epoch_floor(inside.nbf),
        "ia32-outside": None,
        "ia32-max": base - 100,
        "ia32-sidonly": None,
    }
    _celery_app()
    now = db_now()
    first = _reconcile()
    first_values, first_ttls = _floor_state(ia73_df_admin, subs), _floor_ttls(ia73_df_admin, subs)
    expected_ttls = {
        "ia32-inside": _remaining(inside.expires_at + RETENTION, now),
        "ia32-max": _remaining(top.expires_at + RETENTION, now),
    }
    time.sleep(1.2)
    _reconcile()
    second_values, second_ttls = _floor_state(ia73_df_admin, subs), _floor_ttls(ia73_df_admin, subs)
    ia73_df_admin.flushall()
    _reconcile()
    restored = _floor_state(ia73_df_admin, subs)

    assert first_values == expected
    assert first.get("floors") == 2
    drifts = _drifts(first_ttls, expected_ttls)
    assert all(drift <= TTL_TOLERANCE_S for drift in drifts.values()), f"하한 TTL {first_ttls} · 기대 {expected_ttls}"
    assert second_values == expected
    grew = [sub for sub in expected_ttls if second_ttls[sub] > first_ttls[sub]]
    assert grew == [], f"두 번째 재적용이 TTL을 늘렸다: {grew}"
    assert restored == expected


def _purge_log() -> int:
    """purge_session_revocation_log 1회 — 반환(지운 행 수 · 정수가 아니면 유한한 실패)."""
    outcome = _run(TASK_PURGE_LOG)
    if not isinstance(outcome, int) or isinstance(outcome, bool):
        pytest.fail(f"purge 반환이 정수가 아니다: {type(outcome).__name__}", pytrace=False)
    return outcome


def _log_subs() -> set[str]:
    return set(model("session_revocation_log").objects.values_list("sub", flat=True))


@DB
def test_ia_33_purge_target_is_never_a_floor_target(ia73_df_admin: redis.Redis) -> None:
    """ia-33(D29 불변식 2 — purge 경계 = 하한 수명 경계) — api-34와 같은 세 행(expires_at = DB now − 30 d − 1 h · − 30 d + 1 h ·
    + 100 s · 셋 다 사용자 단위): purge 앞의 재적용 → 하한은 뒤 둘에만 / purge → 1행(첫째) 삭제 · 남은 sub = 뒤 둘 / FLUSHALL 뒤
    재적용 → 하한은 여전히 뒤 둘에만(지워진 행의 sub는 하한이 없고 남은 두 행의 sub는 있다 — purge 대상 ⇔ 하한 대상 아님)."""
    base = _at(_epoch_floor(db_now()))
    hour = timedelta(hours=1)
    insert_log_row("ia33-old", nbf=base - RETENTION - hour - REVOCATION_TTL)
    insert_log_row("ia33-recent", nbf=base - RETENTION + hour - REVOCATION_TTL)
    insert_log_row("ia33-active", nbf=base + timedelta(seconds=100) - REVOCATION_TTL)
    subs = ("ia33-old", "ia33-recent", "ia33-active")
    _reconcile()
    before = {sub for sub, value in _floor_state(ia73_df_admin, subs).items() if value is not None}
    purged = _purge_log()
    remaining = _log_subs()
    ia73_df_admin.flushall()
    _reconcile()
    after = {sub for sub, value in _floor_state(ia73_df_admin, subs).items() if value is not None}

    assert before == {"ia33-recent", "ia33-active"}
    assert (purged, remaining) == (1, {"ia33-recent", "ia33-active"})
    assert after == remaining
    assert ({"ia33-old"} & after, {"ia33-old"} | after) == (set(), set(subs))


@DB
def test_ia_33_retention_constant_moves_purge_and_floor_window(
    ia73_df_admin: redis.Redis, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ia-33(D29 「상수 하나」 · 이음매 `session_floor.REVOCATION_LOG_RETENTION`) — 이음매를 10일로 덮는다. 세 사용자 단위 행
    (expires_at = DB now − 10 d − 1 h · − 20 d · − 10 d + 1 h): 재적용 → 하한은 셋째에만(− 20 d는 30일 창이면 하한 대상 — SQL에
    30일 리터럴이 남아 있으면 깨진다) · 반환 floors 1 · skipped 0(창이 10일로 움직였다 — 창에만 30일 리터럴이 남아 앞 둘을 읽고
    TTL < 1로 건너뛰는 구현도 잡는다) · 셋째 TTL = ⌊expires_at + 10 d − DB now⌋ ± 5 / purge → 2행 삭제 · 남은 sub = 셋째(purge에
    30일 리터럴이 남아 있으면 − 20 d 행이 남는다)."""
    short = timedelta(days=10)
    base = _at(_epoch_floor(db_now()))
    hour = timedelta(hours=1)
    insert_log_row("ia33b-gone", nbf=base - short - hour - REVOCATION_TTL, expires_at=base - short - hour)
    insert_log_row("ia33b-mid", nbf=base - timedelta(days=20) - REVOCATION_TTL, expires_at=base - timedelta(days=20))
    kept = insert_log_row("ia33b-kept", nbf=base - short + hour - REVOCATION_TTL, expires_at=base - short + hour)
    subs = ("ia33b-gone", "ia33b-mid", "ia33b-kept")
    monkeypatch.setattr(impl("session_floor"), "REVOCATION_LOG_RETENTION", short)
    _celery_app()
    now = db_now()
    reapplied = _reconcile()
    floors = {sub for sub, value in _floor_state(ia73_df_admin, subs).items() if value is not None}
    kept_drift = abs(read_ttl(ia73_df_admin, floor_key("ia33b-kept")) - _remaining(kept.expires_at + short, now))
    purged = _purge_log()
    remaining = _log_subs()

    assert floors == {"ia33b-kept"}
    assert (reapplied.get("floors"), reapplied.get("skipped")) == (1, 0)
    assert kept_drift <= TTL_TOLERANCE_S
    assert (purged, remaining) == (2, {"ia33b-kept"})


class PlantedPurgeError(Exception):
    """시험이 심는 purge 실패(DB 접속 실패 꼴 문구 — 호스트 · IP · role 이름이 로그 · 트레이스백에 실리지 않는지 본다)."""


def _chain(error: Any) -> tuple[str, str]:
    """예외의 (`__cause__`, `__context__`) 클래스 이름 — 연쇄가 없으면 ("NoneType", "NoneType")."""
    return type(getattr(error, "__cause__", None)).__name__, type(getattr(error, "__context__", None)).__name__


@DB
def test_ia_33_purge_failure_fails_without_message(monkeypatch: pytest.MonkeyPatch, log_lines: LogLines) -> None:
    """ia-33 옆(수정 라운드 H4 — 설계 D25 「예외 문구를 싣지 않는다」를 purge 작업도 같은 수준으로) — 짝: 그대로 → SUCCESS ·
    반환 정수 / 이음매 `denylist_writer.purge_log`가 DB 접속 실패 꼴 문구(호스트 · IP · role 이름을 심는다)의 예외를 던지면 →
    상태 FAILURE · 결과 예외 PurgeFailed(문구 "" · `__cause__` · `__context__` 둘 다 None) · WARNING
    `session_revocation_log.purge_failed` 한 줄(error = 심은 예외의 클래스 이름) · 로그 줄 전부와 결과 트레이스백에 심은 값 0."""
    task = _task(TASK_PURGE_LOG)
    pair = task.apply()
    pair_shape = (pair.state, type(pair.result).__name__)
    planted = {
        "host": f"pg-planted-{secrets.token_hex(4)}.internal",
        "ip": f"10.{secrets.randbelow(200) + 20}.{secrets.randbelow(250) + 1}.{secrets.randbelow(250) + 1}",
        "role": f"ia_planted_role_{secrets.token_hex(3)}",
    }
    message = (
        f'connection failed: connection to server at "{planted["host"]}" ({planted["ip"]}), port 5432 failed: '
        f'FATAL:  password authentication failed for user "{planted["role"]}"'
    )

    def broken_purge() -> int:
        raise PlantedPurgeError(message)

    monkeypatch.setattr(impl("denylist_writer"), "purge_log", broken_purge)
    log_lines()
    down = task.apply()
    records = log_lines()
    outcome = down.result
    chain = _chain(outcome)
    message_empty = str(outcome) == ""  # 조각 ⑤-b W2 — 감싸기가 빠지는 회귀 때 심은 문구가 실패 출력에 실리지 않게 접는다
    failed_lines = [
        (line.get("level"), line.get("error") == "PlantedPurgeError")
        for line in log_events(records, "session_revocation_log.purge_failed")
    ]
    text = json.dumps(records) + str(down.traceback or "")
    leaked = {name: Secret(value) in Secret(text) for name, value in planted.items()}

    assert pair_shape == ("SUCCESS", "int")
    assert (down.state, type(outcome).__name__, message_empty) == ("FAILURE", "PurgeFailed", True)
    assert chain == ("NoneType", "NoneType")
    assert failed_lines == [("warning", True)]
    assert leaked == {"host": False, "ip": False, "role": False}


@DB
def test_ia_38_freshness_key_and_result_contract(ia73_df_admin: redis.Redis) -> None:
    """ia-38(D14 신선도 키 · 반환 계약) — 행 0에서 재적용 → 반환 = 다섯 건수 전부 0 · `revoked:*` 키 0 · 신선도 키
    `identity-admin:denylist:reapplied-at` 값 = 작업 시각(epoch 초 · 앞뒤로 잰 [t0, t1]) · TTL ∈ [290, 300] / 행 셋(활성 사용자 단위
    · 활성 sid · 창 안이지만 만료된 사용자 단위)을 넣고 재적용 → 반환 dict의 키가 정확히 다섯이고 값이 정수(bool 아님) · keys =
    `revoked:*` 실제 키 수(2) · floors = 하한 실제 키 수(2) · rows 2 · skipped 0 · failed 0."""
    t0 = int(time.time())
    empty = _reconcile()
    t1 = int(time.time())
    fresh = read_int(ia73_df_admin, FRESHNESS_KEY)
    fresh_ttl = read_ttl(ia73_df_admin, FRESHNESS_KEY)
    revoked_empty = scan_keys(ia73_df_admin, "revoked:*")
    base = _epoch_floor(db_now())
    insert_log_row("ia38-user", nbf=_at(base - 10))
    insert_log_row("ia38-sid-sub", nbf=_at(base - 10), sid="ia38-sid", reason="logout")
    insert_log_row("ia38-past", nbf=_at(base - 7200))
    filled = _reconcile()
    shape = (sorted(filled), {name: type(value).__name__ for name, value in filled.items()})
    actual = {
        "rows": 2,
        "keys": len(scan_keys(ia73_df_admin, "revoked:*")),
        "floors": len(scan_keys(ia73_df_admin, "identity-admin:session-floor:*")),
        "skipped": 0,
        "failed": 0,
    }

    assert empty == dict.fromkeys(RESULT_KEYS, 0)
    assert revoked_empty == []
    assert fresh is not None and t0 <= fresh <= t1, f"신선도 값 {fresh} · 작업 앞뒤 [{t0}, {t1}]"
    assert FRESHNESS_TTL_MIN_S <= fresh_ttl <= FRESHNESS_TTL_S, f"신선도 키 TTL {fresh_ttl}"
    assert shape == (sorted(RESULT_KEYS), dict.fromkeys(RESULT_KEYS, "int"))
    assert (actual["keys"], actual["floors"]) == (2, 2)
    assert filled == actual


@DB
def test_ia_38_reapply_failure_fails_the_task(settings: SettingsWrapper, log_lines: LogLines) -> None:
    """ia-38(D14 「예외는 ReapplyFailed() from None」) — 짝: 같은 준비물(활성 행 하나)에 실제 Dragonfly(pod 사용자) → 작업 성공 /
    DRAGONFLY_URL을 닫힌 포트(심은 비밀번호)로 → 작업 실패(상태 FAILURE · 성공 아님) · 결과 예외 = ReapplyFailed(문구 없음 ·
    `__cause__` · `__context__` 둘 다 None — 수정 라운드 H3: 닫힌 포트의 예외 문구가 OS마다 달라(Windows는 호스트 · 포트 없는
    TimeoutError) 아래 문구 단언만으로는 연쇄 끊김이 Linux에서만 판별된다) · WARNING `denylist.reapply_failed` 한 줄(phase tick ·
    error = 예외 클래스 이름) · 로그 줄 전부와 결과 트레이스백에 호스트 · 포트 · 비밀번호가 없다(redis-py · psycopg 예외 문구가
    Celery 실패 로그에 실리지 않는다)."""
    base = _epoch_floor(db_now())
    insert_log_row("ia38-fail-sub", nbf=_at(base - 10))
    task = _task(TASK_RECONCILE)
    live = task.apply()
    live_state = live.state
    password = secrets.token_urlsafe(16)
    port = closed_port()
    settings.DRAGONFLY_URL = Secret(f"redis://identity-admin:{password}@127.0.0.1:{port}/0")
    log_lines()
    down = task.apply()
    records = log_lines()
    outcome = down.result
    chain = _chain(outcome)
    failed_lines = [
        (line.get("level"), line.get("phase"), line.get("error"))
        for line in log_events(records, "denylist.reapply_failed")
    ]
    text = json.dumps(records) + str(down.traceback or "")
    leaked = {"host": "127.0.0.1" in text, "port": f":{port}" in text, "password": Secret(password) in Secret(text)}

    assert live_state == "SUCCESS"
    assert (down.state, type(outcome).__name__, str(outcome)) == ("FAILURE", "ReapplyFailed", "")
    assert chain == ("NoneType", "NoneType")
    assert len(failed_lines) == 1, f"denylist.reapply_failed 줄 수 {len(failed_lines)}"
    level, phase, error = failed_lines[0]
    assert (level, phase) == ("warning", "tick")
    assert isinstance(error, str) and error.isidentifier(), "error 필드가 예외 클래스 이름이 아니다"
    assert leaked == {"host": False, "port": False, "password": False}


@DB
def test_ia_38_beat_init_failure_keeps_beat_running(settings: SettingsWrapper, log_lines: LogLines) -> None:
    """ia-38(D14 beat_init 갈래 — 재적용 실패 경로의 위생) — 짝: 실제 Dragonfly(pod 사용자)에서 beat_init.send(sender=None) →
    수신자 예외 0 · INFO `denylist.reapplied`(phase beat_init) 한 줄 / DRAGONFLY_URL을 닫힌 포트(심은 비밀번호)로 → 수신자 예외 0
    (beat 기동이 계속된다 — Celery Signal.send가 수신자 예외를 담아 로그로 찍지 않게 수신자가 삼킨다) · WARNING
    `denylist.reapply_failed`(phase beat_init · error = 예외 클래스 이름) 한 줄 · `denylist.reapplied` 0줄 · 로그 줄 전부에 호스트 ·
    포트 · 비밀번호가 없다."""
    from celery.signals import beat_init

    base = _epoch_floor(db_now())
    insert_log_row("ia38-boot-sub", nbf=_at(base - 10))
    _celery_app()
    log_lines()
    live = beat_init.send(sender=None)
    live_records = log_lines()
    password = secrets.token_urlsafe(16)
    port = closed_port()
    settings.DRAGONFLY_URL = Secret(f"redis://identity-admin:{password}@127.0.0.1:{port}/0")
    down = beat_init.send(sender=None)
    records = log_lines()
    raised = {
        "live": [type(result).__name__ for _, result in live if isinstance(result, BaseException)],
        "down": [type(result).__name__ for _, result in down if isinstance(result, BaseException)],
    }
    live_lines = [line.get("phase") for line in log_events(live_records, "denylist.reapplied")]
    failed_lines = [
        (line.get("level"), line.get("phase"), line.get("error"))
        for line in log_events(records, "denylist.reapply_failed")
    ]
    reapplied_after = log_events(records, "denylist.reapplied")
    text = json.dumps(records)
    leaked = {"host": "127.0.0.1" in text, "port": f":{port}" in text, "password": Secret(password) in Secret(text)}

    assert raised == {"live": [], "down": []}
    assert live_lines == ["beat_init"]
    assert len(failed_lines) == 1, f"denylist.reapply_failed 줄 수 {len(failed_lines)}"
    level, phase, error = failed_lines[0]
    assert (level, phase) == ("warning", "beat_init")
    assert isinstance(error, str) and error.isidentifier(), "error 필드가 예외 클래스 이름이 아니다"
    assert reapplied_after == []
    assert leaked == {"host": False, "port": False, "password": False}


OUTSIDE_ACL = "ia38-outside-acl"  # pod 사용자 ACL(`~revoked:* ~identity-admin:*`) 밖의 접두 — 그 명령에만 NOPERM(VD-T073-7)
REAPPLY_FAILED = "denylist.reapply_failed"


def _state_and_counts(result: Any) -> tuple[str, dict[str, Any] | None]:
    """apply() 결과의 (상태, 반환 dict — dict가 아니면 None)."""
    return result.state, result.result if isinstance(result.result, dict) else None


@DB
def test_ia_38_command_errors_are_counted_and_logged(
    ia73_df_admin: redis.Redis, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-38 옆(수정 라운드 H1 — D14 「명령 단위 오류는 failed로 세고 WARNING」 · 운영 ACL이 어긋났을 때 재적용 쪽의 유일한 신호) —
    pod 사용자 · 활성 사용자 단위 행 하나(명령 셋: `revoked:sub` · 하한 · 신선도 키).
    1. 짝: 그대로 재적용 → SUCCESS · failed 0 · 하한 키 있음.
    2. 이음매 `session_floor.FLOOR_KEY_PREFIX`를 ACL 밖 접두로 덮고 admin FLUSHALL → 재적용: `ACL SETUSER` 없이 실제 Dragonfly가 그
       명령에만 NOPERM(결과 목록의 NoPermissionError 객체) → SUCCESS · 반환 rows 1 · keys 1 · floors 1 · skipped 0 · failed 1 ·
       WARNING `denylist.reapply_failed` 정확히 한 줄(failed 1 · error NoPermissionError · phase 키 없음 — 명령 단위 갈래) ·
       `revoked:sub`와 신선도 키는 있다(다른 명령은 적용된다) · admin으로 ACL 밖 키 0 · 로그 줄 전부에 원문 sub 없음.
    3. 신선도 키(이음매 `denylist_writer.FRESHNESS_KEY`)도 ACL 밖으로 덮고 admin FLUSHALL → 재적용 → SUCCESS · failed 2(신선도 키
       포함 — D14 반환 계약) · 진짜 신선도 키와 ACL 밖 키 둘 다 없음."""
    sub = "ia38-noperm-sub"
    insert_log_row(sub, nbf=_at(_epoch_floor(db_now()) - 10))
    task = _task(TASK_RECONCILE)
    pair_state, pair_counts = _state_and_counts(task.apply())
    pair = (pair_state, (pair_counts or {}).get("failed"), ia73_df_admin.exists(floor_key(sub)))

    monkeypatch.setattr(impl("session_floor"), "FLOOR_KEY_PREFIX", f"{OUTSIDE_ACL}:floor:")
    ia73_df_admin.flushall()
    log_lines()
    floor_state, floor_counts = _state_and_counts(task.apply())
    records = log_lines()
    warnings = [
        (line.get("level"), line.get("failed"), line.get("error"), "phase" in line)
        for line in log_events(records, REAPPLY_FAILED)
    ]
    applied = (
        ia73_df_admin.exists(sub_key(sub)),
        ia73_df_admin.exists(FRESHNESS_KEY),
        scan_keys(ia73_df_admin, f"{OUTSIDE_ACL}:*"),
    )
    raw_sub_logged = sub in json.dumps(records)

    monkeypatch.setattr(impl("denylist_writer"), "FRESHNESS_KEY", f"{OUTSIDE_ACL}:reapplied-at")
    ia73_df_admin.flushall()
    both_state, both_counts = _state_and_counts(task.apply())
    after_both = (ia73_df_admin.exists(FRESHNESS_KEY), scan_keys(ia73_df_admin, f"{OUTSIDE_ACL}:*"))

    assert pair == ("SUCCESS", 0, 1)
    assert (floor_state, floor_counts) == ("SUCCESS", {"rows": 1, "keys": 1, "floors": 1, "skipped": 0, "failed": 1})
    assert warnings == [("warning", 1, "NoPermissionError", False)]
    assert applied == (1, 1, [])
    assert raw_sub_logged is False
    assert (both_state, (both_counts or {}).get("failed")) == ("SUCCESS", 2)
    assert after_both == (0, [])


@DB
def test_ia_38_reapply_discards_idle_connections_first(
    dragonfly: DragonflyInfo, ia73_df_admin: redis.Redis, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-38 옆(수정 라운드 H2 — contracts/denylist.md §쓰기 규약 「재적용은 실행마다 첫 묶음 앞에서 유휴 연결을 버린다 — 재시도가
    아니다」) — pod 사용자(이름 · 비밀번호 그대로)의 DRAGONFLY_URL을 TcpRelay(상류 = 시험 Dragonfly)로 향하게 한다 · 활성 사용자
    단위 행 하나.
    1. 첫 재적용 → SUCCESS.
    2. 워커의 다른 작업이 남기는 유휴 연결을 흉내 낸다: `denylist_writer.apply_user(sub)` → "ok"(조각 ⑤-b의 대조 백필이 워커에서 이
       경로로 쓴다 — 풀에 중계를 지나는 유휴 연결이 남는다 · 실행 끝에 버리는 구현은 이 연결을 못 버린다).
    3. freeze()(그 연결은 클라이언트에 살아 보이는 죽은 연결 — FIN이 닿지 않은 끊김) · 얼린 연결 ≥ 1(공허하지 않다) → admin
       FLUSHALL(admin은 중계를 거치지 않는다) → 둘째 재적용.
    4. 둘째도 SUCCESS · failed 0 · 세 키(`revoked:sub` · 하한 · 신선도)가 돌아왔다 · 2단계 뒤부터의 로그에 `denylist.reapply_failed`
       0줄.
    5. 중계가 받은 연결 수(조각 ⑤-b W1 — 5aV-3: 버리기의 세 성질 가운데 「실행당 한 번」 · 「요청 경로는 그대로」): (freeze 앞,
       둘째 재적용 뒤) = (1, 2) — 첫 재적용이 1개를 맺고 apply_user(요청 경로)는 그 연결을 다시 쓰며 둘째 재적용이 정확히 1개를
       새로 맺는다(요청 경로에서도 버리는 구현은 (2, 3))."""
    sub = "ia38-relay-sub"
    insert_log_row(sub, nbf=_at(_epoch_floor(db_now()) - 10))
    task = _task(TASK_RECONCILE)
    writer = impl("denylist_writer")
    keys = (sub_key(sub), floor_key(sub), FRESHNESS_KEY)
    user = urlsplit(dragonfly.pod_url).username
    password = url_password(dragonfly.pod_url) or ""
    with TcpRelay(dragonfly.host, dragonfly.port) as relay:
        settings.DRAGONFLY_URL = Secret(f"redis://{user}:{password}@127.0.0.1:{relay.port}/0")
        relay_client = writer.client()  # 지연 생성 — 만들 때 연결하지 않는다(끝에 풀을 비운다)
        try:
            first_state = task.apply().state
            log_lines()
            warmed = writer.apply_user(sub)
            accepted_before = relay.accepted
            relay.freeze()
            frozen = relay.frozen
            ia73_df_admin.flushall()
            second_state, second_counts = _state_and_counts(task.apply())
            records = log_lines()
            accepted_after = relay.accepted
        finally:
            relay_client.connection_pool.disconnect()
    failed_lines = [(line.get("phase"), line.get("error")) for line in log_events(records, REAPPLY_FAILED)]
    present = [key for key in keys if ia73_df_admin.exists(key)]

    assert (first_state, warmed) == ("SUCCESS", "ok")
    assert frozen >= 1, "freeze가 얼린 연결이 없다 - 풀에 유휴 연결이 없어 사례가 공허하다"
    assert (second_state, (second_counts or {}).get("failed"), failed_lines) == ("SUCCESS", 0, [])
    assert (accepted_before, accepted_after) == (1, 2)
    assert present == list(keys)


class PlantedReapplyError(Exception):
    """시험이 심는 재적용 실패(문구에 호스트 · 포트 · 비밀번호 · sub 꼴을 심는다 — 로그 · 트레이스백에 실리지 않는지 본다)."""


@DB
def test_ia_38_reapply_failure_hygiene_on_any_os(monkeypatch: pytest.MonkeyPatch, log_lines: LogLines) -> None:
    """ia-38 옆(수정 라운드 H3 — 「연쇄 없음 · 문구 없음」의 OS 무관 판별) — 짝: 덮기 전의 같은 준비물(활성 행 하나) → SUCCESS /
    이음매 `denylist_writer.reapply`가 호스트 · 포트 · 비밀번호 · sub 꼴의 값을 문구에 심은 예외를 던지면:
    - 작업: 상태 FAILURE · ReapplyFailed · 문구 "" · `__cause__` · `__context__` 둘 다 None · WARNING `denylist.reapply_failed`
      (phase tick · error = 심은 예외의 클래스 이름) 한 줄 · 로그 줄 전부와 결과 트레이스백에 심은 값 0.
    - 같은 덮기 아래 beat_init.send(sender=None): 수신자 예외 0 · WARNING(phase beat_init · error 같은 이름) 한 줄 · 로그 줄 전부에
      심은 값 0."""
    from celery.signals import beat_init

    insert_log_row("ia38-hygiene-sub", nbf=_at(_epoch_floor(db_now()) - 10))
    task = _task(TASK_RECONCILE)
    pair_state = task.apply().state
    planted = {
        "host": f"df-planted-{secrets.token_hex(4)}.internal",
        "port": f":{secrets.randbelow(20000) + 40000}",
        "password": Secret(secrets.token_urlsafe(16)),
        "sub": f"ia38-planted-sub-{secrets.token_hex(4)}",
    }
    message = (
        f"Error 111 connecting to {planted['host']}{planted['port']}. AUTH identity-admin {planted['password']} "
        f"failed while writing revoked:sub:{planted['sub']}"
    )

    def broken_reapply() -> Any:
        raise PlantedReapplyError(message)

    monkeypatch.setattr(impl("denylist_writer"), "reapply", broken_reapply)
    log_lines()
    down = task.apply()
    task_records = log_lines()
    outcome = down.result
    chain = _chain(outcome)
    message_empty = str(outcome) == ""  # 조각 ⑤-b W2 — 감싸기가 빠지는 회귀 때 심은 문구(가짜 비밀번호 포함)를 싣지 않게 접는다
    planted_error = "PlantedReapplyError"
    task_lines = [
        (line.get("level"), line.get("phase"), line.get("error") == planted_error)
        for line in log_events(task_records, REAPPLY_FAILED)
    ]
    task_text = json.dumps(task_records) + str(down.traceback or "")
    boot = beat_init.send(sender=None)
    boot_records = log_lines()
    raised = [type(result).__name__ for _, result in boot if isinstance(result, BaseException)]
    boot_lines = [
        (line.get("level"), line.get("phase"), line.get("error") == planted_error)
        for line in log_events(boot_records, REAPPLY_FAILED)
    ]
    boot_text = json.dumps(boot_records)
    task_secret, boot_secret = Secret(task_text), Secret(boot_text)
    leaked = {name: (Secret(value) in task_secret, Secret(value) in boot_secret) for name, value in planted.items()}
    clean = dict.fromkeys(planted, (False, False))  # 기대값 — 심은 값을 담은 dict를 assert 식의 호출 인자로 두지 않는다

    assert pair_state == "SUCCESS"
    assert (down.state, type(outcome).__name__, message_empty) == ("FAILURE", "ReapplyFailed", True)
    assert chain == ("NoneType", "NoneType")
    assert task_lines == [("warning", "tick", True)]
    assert raised == []
    assert boot_lines == [("warning", "beat_init", True)]
    assert leaked == clean


class _PipelineRecorder:
    """실제 파이프라인을 감싸 set 키를 기록하고 execute 인자를 소유자(_ClientRecorder)에 남긴다(모르는 속성은 실제 파이프라인)."""

    def __init__(self, owner: _ClientRecorder, real: Any) -> None:
        self._owner = owner
        self._real = real
        self._keys: list[str] = []

    def __getattr__(self, name: str) -> Any:
        return getattr(self._real, name)

    def set(self, name: Any, value: Any, *args: Any, **kwargs: Any) -> _PipelineRecorder:
        self._keys.append(name if isinstance(name, str) else bytes(name).decode())
        self._real.set(name, value, *args, **kwargs)
        return self

    def execute(self, raise_on_error: bool = True) -> list[Any]:
        owner = self._owner
        owner.raise_on_error.append(raise_on_error)
        owner.batches.append(list(self._keys))
        if owner.fail_at is not None and len(owner.batches) == owner.fail_at:
            self._real.reset()  # 보내지 않는다 — 끊김 흉내
            raise RedisConnectionError(owner.message)
        results: list[Any] = self._real.execute(raise_on_error=raise_on_error)
        return results


class _PoolRecorder:
    """실제 연결 풀을 감싸 disconnect 호출을 실효 인자(기본값까지 — redis-py `disconnect(inuse_connections=True)`)로 소유자의
    events에 남긴다(조각 ⑤-b W1). 실제 풀의 disconnect는 그대로 부른다(동작을 바꾸지 않는다) · 모르는 속성은 실제 풀."""

    def __init__(self, owner: _ClientRecorder, real: Any) -> None:
        self._owner = owner
        self._real = real

    def __getattr__(self, name: str) -> Any:
        return getattr(self._real, name)

    def disconnect(self, inuse_connections: bool = True) -> None:
        self._owner.events.append(("disconnect", inuse_connections))
        self._real.disconnect(inuse_connections=inuse_connections)


class _ClientRecorder:
    """이음매 `denylist_writer.client`의 대리 — 실제 pod 클라이언트를 감싸 pipeline의 transaction 값 · 묶음별 set 키 · execute의
    raise_on_error 값을 기록한다. 풀의 disconnect와 pipeline 생성은 한 줄의 기록 events에 차례대로 남는다(("disconnect",
    inuse_connections 실효값) · ("pipeline", transaction) — 조각 ⑤-b W1). fail_at = n이면 n번째 execute에서 보내지 않고 redis
    ConnectionError(message)를 던진다. 그 밖의 모르는 속성은 실제 클라이언트로 넘긴다(유휴 연결 버리기가 실제 풀에 그대로 닿는다)."""

    def __init__(self, real: Any, *, fail_at: int | None = None, message: str = "") -> None:
        self._real = real
        self.fail_at = fail_at
        self.message = message
        self.transactions: list[bool] = []
        self.raise_on_error: list[bool] = []
        self.batches: list[list[str]] = []
        self.events: list[tuple[str, bool]] = []

    def __getattr__(self, name: str) -> Any:
        return getattr(self._real, name)

    @property
    def connection_pool(self) -> _PoolRecorder:
        return _PoolRecorder(self, self._real.connection_pool)

    def pipeline(self, transaction: bool = True, shard_hint: Any = None) -> _PipelineRecorder:
        self.transactions.append(transaction)
        self.events.append(("pipeline", transaction))
        return _PipelineRecorder(self, self._real.pipeline(transaction=transaction, shard_hint=shard_hint))


@DB
def test_ia_38_reapply_batches_end_with_freshness_key(
    ia73_df_admin: redis.Redis, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-38 옆(수정 라운드 H7 — D14 「1000개 단위 파이프라인 · 마지막 명령은 늘 신선도 키」의 묶음 경계) — 이음매
    `denylist_writer.REAPPLY_BATCH`를 2로 · 활성 사용자 단위 행 둘(서로 다른 sub) → 명령 다섯(`revoked:sub` 둘 · 하한 둘 · 신선도 키)
    → 묶음 [2, 2, 1].
    (i) 그대로: admin FLUSHALL → SUCCESS · 네 키와 신선도 키가 다 있다 · keys 2 · floors 2 · failed 0.
    (ii) 기록하는 대리(이음매 `denylist_writer.client` — 실제 pod 클라이언트를 감싼다): SUCCESS · pipeline은 매번 transaction 거짓 ·
         execute는 매번 raise_on_error 거짓 · execute별 명령 수 [2, 2, 1] · 마지막 묶음의 마지막 명령이 신선도 키 · 풀 disconnect와
         pipeline 생성을 한 줄로 기록한 차례의 첫 항목이 disconnect(inuse_connections=False)이고 disconnect는 그 한 번뿐이다(조각 ⑤-b
         W1 — 묶음마다 버리거나 쓰는 중인 연결까지 끊는 구현이 지나지 않게).
    (iii) 같은 대리가 둘째 execute에서 보내지 않고 redis ConnectionError(심은 문구)를 던진다: admin FLUSHALL → FAILURE
          (ReapplyFailed) · 신선도 키 없음(거짓 생존 신호가 없다) · 첫 묶음의 `revoked:*` 둘은 있다 · 하한 0 · WARNING
          `denylist.reapply_failed`(phase tick · error ConnectionError) · 로그 줄 전부와 트레이스백에 심은 문구 없음."""
    writer = impl("denylist_writer")
    monkeypatch.setattr(writer, "REAPPLY_BATCH", 2)
    subs = ("ia38-batch-a", "ia38-batch-b")
    base = _epoch_floor(db_now())
    for offset, sub in enumerate(subs):
        insert_log_row(sub, nbf=_at(base - 10 - offset))
    task = _task(TASK_RECONCILE)
    keys = [*(sub_key(sub) for sub in subs), *(floor_key(sub) for sub in subs), FRESHNESS_KEY]

    ia73_df_admin.flushall()
    plain_state, plain_counts = _state_and_counts(task.apply())
    plain_present = [key for key in keys if ia73_df_admin.exists(key)]

    real = writer.client()
    recorder = _ClientRecorder(real)
    monkeypatch.setattr(writer, "client", lambda: recorder)
    ia73_df_admin.flushall()
    recorded_state = task.apply().state
    recorded = {
        "state": recorded_state,
        "transactions": recorder.transactions,
        "raise_on_error": recorder.raise_on_error,
        "sizes": [len(batch) for batch in recorder.batches],
        "last": recorder.batches[-1][-1] if recorder.batches and recorder.batches[-1] else None,
        "events": recorder.events,
    }

    planted = {"host": f"df-planted-{secrets.token_hex(4)}.internal", "port": f":{secrets.randbelow(20000) + 40000}"}
    message = f"Error 104 while writing to {planted['host']}{planted['port']}. Connection reset by peer."
    failing = _ClientRecorder(real, fail_at=2, message=message)
    monkeypatch.setattr(writer, "client", lambda: failing)
    ia73_df_admin.flushall()
    log_lines()
    broken = task.apply()
    records = log_lines()
    broken_shape = (broken.state, type(broken.result).__name__)
    after_break = {
        "freshness": ia73_df_admin.exists(FRESHNESS_KEY),
        "revoked": scan_keys(ia73_df_admin, "revoked:*"),
        "floors": scan_keys(ia73_df_admin, "identity-admin:session-floor:*"),
    }
    failed_lines = [(line.get("phase"), line.get("error")) for line in log_events(records, REAPPLY_FAILED)]
    text = json.dumps(records) + str(broken.traceback or "")
    leaked = {name: Secret(value) in Secret(text) for name, value in planted.items()}

    assert (plain_state, plain_present) == ("SUCCESS", keys)
    assert {name: (plain_counts or {}).get(name) for name in ("keys", "floors", "failed")} == {
        "keys": 2,
        "floors": 2,
        "failed": 0,
    }
    assert recorded == {
        "state": "SUCCESS",
        "transactions": [False, False, False],
        "raise_on_error": [False, False, False],
        "sizes": [2, 2, 1],
        "last": FRESHNESS_KEY,
        # 조각 ⑤-b W1(5aV-3) — 버리기는 실행당 한 번 · 첫 파이프라인 앞 · 유휴 연결만(inuse_connections 거짓 — 기본값은 참)
        "events": [("disconnect", False), ("pipeline", False), ("pipeline", False), ("pipeline", False)],
    }
    assert broken_shape == ("FAILURE", "ReapplyFailed")
    assert after_break == {"freshness": 0, "revoked": sorted(sub_key(sub) for sub in subs), "floors": []}
    assert failed_lines == [("tick", "ConnectionError")]
    assert leaked == {"host": False, "port": False}


def test_ia_38_beat_entry_expires_stale_ticks() -> None:
    """ia-38(D15) — beat 항목 가운데 작업이 reconcile_denylist인 것이 정확히 하나이고 그 options == {"expires": 30}(밀린 tick을 쌓아
    두었다가 연달아 돌리지 않고 버린다 · T066 api-33은 task · schedule만 본다)."""
    app = _celery_app()
    options = [entry.get("options") for entry in app.conf.beat_schedule.values() if entry.get("task") == TASK_RECONCILE]

    assert options == [{"expires": 30}]


def test_ia_11_delegation_task_registered_under_enqueue_name() -> None:
    """ia-11 옆(조각 ⑤-a — 설계 D15 · D16 · 조각 ③-b1 인계): 위임 enqueue가 이름으로 보내는 `revocation.DELEGATION_TASK`가
    worker · beat처럼 기본 모듈을 적재한 뒤 app.tasks에 글자 그대로 있다(등록 이름과 enqueue 이름이 어긋나면 위임이 조용히 버려진다) ·
    그 작업의 옵션 = D16(autoretry_for = (jobs.AuthentikTransient,) · retry_backoff 5 · retry_backoff_max 300 ·
    retry_jitter 거짓 · max_retries 3 · acks_late · reject_on_worker_lost · ignore_result) · 대조 작업도 등록 · 상수 셋
    (D26 「상수 이름」) — 위임 마감 20 s · 대조 마감 120 s · 대조 창 72 h. 수정 라운드 J4(5bA-5 · 5bB-3): 재시도로 다시 발행되는
    메시지도 인자 표시를 가린다 — `task.retry_kwargs`의 `argsrepr`이 발행 쪽(`revocation._delegate`) 값과 글자 그대로 같다(Celery가
    그 사전에 `countdown`을 써넣으므로 키 하나만 본다)."""
    app = _celery_app()
    name = impl("revocation").DELEGATION_TASK
    task = app.tasks.get(name)
    jobs = impl("jobs")
    options = None
    retry_argsrepr = (getattr(task, "retry_kwargs", None) or {}).get("argsrepr")
    if task is not None:
        options = {
            "autoretry_for": tuple(task.autoretry_for),
            "retry_backoff": task.retry_backoff,
            "retry_backoff_max": task.retry_backoff_max,
            "retry_jitter": task.retry_jitter,
            "max_retries": task.max_retries,
            "acks_late": task.acks_late,
            "reject_on_worker_lost": task.reject_on_worker_lost,
            "ignore_result": task.ignore_result,
        }
    constants = (jobs.DELEGATION_DEADLINE_S, jobs.RECONCILE_DEADLINE_S, jobs.RECONCILE_WINDOW)

    assert name == "identity_admin.tasks.revoke_authentik_sessions"
    assert task is not None, f"위임 작업 {name}이 등록되지 않았다"
    assert options == {
        "autoretry_for": (jobs.AuthentikTransient,),
        "retry_backoff": 5,
        "retry_backoff_max": 300,
        "retry_jitter": False,
        "max_retries": 3,
        "acks_late": True,
        "reject_on_worker_lost": True,
        "ignore_result": True,
    }
    assert retry_argsrepr == REDACTED_ARGSREPR
    assert TASK_RECONCILE_AUTHENTIK in app.tasks
    assert constants == (20, 120, timedelta(hours=72))


# --- 조각 ⑤-b: ia-12(D16 — Authentik 세션 삭제 위임 본체) -----------------------------------------------------------------

REVOKE_DONE = "authentik.revoke_done"
REVOKE_FAILED = "authentik.revoke_failed"
REVOKE_EXPIRED = "authentik.revoke_expired"
REVOKE_USER_MISSING = "authentik.revoke_user_missing"
IA12_SUB = "1a120000-0000-4000-8000-000000000201"  # 위임 대상 사용자 uuid(= sub)
IA12_OTHER_SUB = "1a120000-0000-4000-8000-000000000202"
IA12_PK, IA12_OTHER_PK = 201, 202
IA12_USERS = (
    # 미끼가 정답보다 앞(필터가 무시되면 첫 결과를 쓰는 구현은 남의 사용자를 고른다)
    {"pk": IA12_OTHER_PK, "uuid": IA12_OTHER_SUB, "username": "ia12-other"},
    {"pk": IA12_PK, "uuid": IA12_SUB, "username": "ia12-target"},
)
IA12_TIME_LIMIT_S = 60.0  # 쪽 상한 사례를 유한한 실패로 바꾸는 상한(성능 요구가 아니다 — 가짜의 천장이 먼저 끝낸다)
SESSION_PAGES = 10  # 설계 D16 4 · D26 authentik.SESSION_PAGE_LIMIT(시험의 독립 기대값)
DELEGATION_RETRIES = 3  # 설계 D16 max_retries(시도 4회)
# 작업 id에 「503」이 든 강제 id(수정 라운드 J1 · 5bA-1) — 재시도 줄(`Task <이름>[<id>] retry: <예외>`)의 단언이 id와 겹치면 늘 깨진다
IA12_FORCED_TASK_ID = "00000503-0000-4000-8000-000000000000"
RETRY_MARK = " retry: "  # Celery 재시도 줄에서 예외 꼬리 앞의 표식(celery.app.trace LOG_RETRY)


def _delegate(sub: str = IA12_SUB, nbf: int | None = None) -> Any:
    """위임 작업 1회(eager apply — 재시도도 그 자리에서 돈다 · 결과는 .state · .result로 본다)."""
    return _task(TASK_REVOKE).apply(args=(sub, int(time.time()) if nbf is None else nbf))


def _revoke_lines(records: list[dict[str, Any]], event: str) -> list[tuple[Any, ...]]:
    """위임 로그 줄의 (level, deleted, gone, skipped, truncated, status, error, reason) — 값이 없는 칸은 None."""
    fields = ("level", "deleted", "gone", "skipped", "truncated", "status", "error", "reason")
    return [tuple(line.get(name) for name in fields) for line in log_events(records, event)]


def _sessions_left(fake: Any) -> list[Any]:
    return [session.get("uuid") for session in fake.sessions]


def _ia12_seed(fake: Any, sessions: list[dict[str, Any]], settings: SettingsWrapper) -> None:
    """확장 가짜(대상 · 미끼 사용자 + sessions) · 쓰기 켬 · 자격은 가짜 토큰(자리값 아님)."""
    fake.reset(users=IA12_USERS, sessions=sessions)
    settings.AUTHENTIK_WRITES_ENABLED = True


def test_ia_12_deletes_only_the_target_sessions(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 3-6단계) — 필터를 지키는 가짜: 대상 세션 둘만 지우고 남의 세션은 남는다 · 반환 = deleted(정수 · bool 아님) 2 ·
    INFO `authentik.revoke_done`(deleted 2 · gone 0 · skipped 0 · truncated 거짓 · sub_hash) · 사용자 조회는 `?uuid=<sub>` ·
    세션 목록은 `?user__username=<그 사용자 username>` / 필터 무시 미끼(가짜가 질의를 무시하고 전부 준다 — 미끼 사용자가 앞 ·
    남의 세션 · user가 bool · 문자열인 세션): 지운 것은 대상 세션뿐이다(〔조사 E2〕 — 남의 세션을 지우지 않는다) · 로그 줄 전부에
    원문 sub 없음."""
    from django_common.observability import sub_hash

    mine = [make_session(IA12_PK) for _ in range(2)]
    theirs = make_session(IA12_OTHER_PK)
    _ia12_seed(ia73_authentik, [theirs, *mine], settings)
    log_lines()
    plain = _delegate()
    plain_records = log_lines()
    plain_view = (plain.state, type(plain.result).__name__, plain.result)
    plain_deleted = ia73_authentik.deleted_sessions
    plain_left = _sessions_left(ia73_authentik)
    queries = (
        [request.query for request in ia73_authentik.requests_to("users")],
        [request.query.get("user__username") for request in ia73_authentik.requests_to("sessions")],
    )
    hashes = [line.get("sub_hash") for line in log_events(plain_records, REVOKE_DONE)]
    done = _revoke_lines(plain_records, REVOKE_DONE)

    decoy_mine = [make_session(IA12_PK) for _ in range(2)]
    decoys = [make_session(IA12_OTHER_PK), make_session(True), make_session(str(IA12_PK))]
    _ia12_seed(ia73_authentik, [decoys[0], decoy_mine[0], decoys[1], decoy_mine[1], decoys[2]], settings)
    ia73_authentik.ignore_filters = True
    decoyed = _delegate()
    decoy_records = log_lines()
    decoy_view = (decoyed.state, decoyed.result, ia73_authentik.deleted_sessions, _sessions_left(ia73_authentik))
    raw_sub_logged = IA12_SUB in json.dumps(plain_records + decoy_records)

    assert plain_view == ("SUCCESS", "int", 2)
    assert (plain_deleted, plain_left) == ([session["uuid"] for session in mine], [theirs["uuid"]])
    assert queries == ([{"uuid": [IA12_SUB]}], [["ia12-target"]])
    assert done == [("info", 2, 0, 0, False, None, None, None)]
    assert hashes == [sub_hash(IA12_SUB)]
    assert decoy_view == (
        "SUCCESS",
        2,
        [session["uuid"] for session in decoy_mine],
        [session["uuid"] for session in decoys],
    )
    assert raw_sub_logged is False


def test_ia_12_gone_session_counts_apart_from_deleted(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 5단계 · 〔W30〕) — 짝: 대상 세션 하나 → deleted 1 · gone 0 / 같은 준비물에서 그 세션의 DELETE가 404(남의 세션 ·
    삭제 권한 없음 · 이미 없음도 404다 — 사실 ⑭) → 실패가 아니다(SUCCESS · 재시도 0 — DELETE 요청 1) · 반환 0 ·
    `authentik.revoke_done`의 deleted 0 · gone 1(둘을 한 수로 세면 삭제 권한이 빠진 채로도 「지웠다」로 보인다)."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    log_lines()
    pair = _delegate()
    pair_lines = _revoke_lines(log_lines(), REVOKE_DONE)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    ia73_authentik.inject("session_detail", 404)
    gone = _delegate()
    gone_lines = _revoke_lines(log_lines(), REVOKE_DONE)
    deletes = len(ia73_authentik.requests_to("session_detail"))

    assert (pair.state, pair.result, pair_lines) == ("SUCCESS", 1, [("info", 1, 0, 0, False, None, None, None)])
    assert (gone.state, gone.result, deletes) == ("SUCCESS", 0, 1)
    assert gone_lines == [("info", 0, 1, 0, False, None, None, None)]


def test_ia_12_non_uuid_session_is_skipped(ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines) -> None:
    """ia-12(D16 5단계 · D20 「경로 성분」) — 짝: UUID 꼴 세션 하나 → DELETE 1 / 대상 세션의 uuid가 UUID 꼴이 아니다(`not-a-uuid` ·
    hex 32자) → DELETE 0 · SUCCESS · 반환 0 · `authentik.revoke_done`의 skipped 2(조각 ④ 인계 — 건너뛴 세션이 deleted 0 · gone 0에
    묻히지 않는다)."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    log_lines()
    pair = _delegate()
    pair_deletes = len(ia73_authentik.requests_to("session_detail"))
    log_lines()
    odd = [make_session(IA12_PK, "not-a-uuid"), make_session(IA12_PK, uuid.uuid4().hex)]
    _ia12_seed(ia73_authentik, odd, settings)
    skipped = _delegate()
    skipped_lines = _revoke_lines(log_lines(), REVOKE_DONE)
    skipped_deletes = len(ia73_authentik.requests_to("session_detail"))

    assert (pair.state, pair.result, pair_deletes) == ("SUCCESS", 1, 1)
    assert (skipped.state, skipped.result, skipped_deletes) == ("SUCCESS", 0, 0)
    assert skipped_lines == [("info", 0, 0, 2, False, None, None, None)]


def test_ia_12_transient_errors_retry_then_succeed(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 「429 · 5xx · 시간 초과 · 연결 · 마감 초과만 재시도」) — 사용자 조회가 503 두 번 뒤 200(eager apply는 바로 재시도
    한다 — 〔조사 E21〕) → SUCCESS · 반환 1 · 사용자 조회 3회 · 시도마다의 WARNING `authentik.revoke_failed status=503` 둘 · Celery
    재시도 줄(`Task <이름>[<id>] retry: <예외>`) 둘의 「 retry: 」 뒤 꼬리 = `Retry in 5s: AuthentikTransient()` ·
    `Retry in 10s: AuthentikTransient()`(인자 없음 — 원 예외 문구 · 상태 코드를 싣지 않는다: 재시도 줄은 예외 repr을 찍는다 · 대기
    5 → 10 s도 함께 고정된다). 작업 id는 「503」이 든 강제 id다(수정 라운드 J1 · 5bA-1 — 꼬리만 보므로 id의 hex와 겹치지 않는다) ·
    로그 줄 전부에 원문 sub · 가짜 Authentik의 기준 URL 없음(J7)."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    ia73_authentik.inject("users", 503, 503)
    log_lines()
    retried = _task(TASK_REVOKE).apply(args=(IA12_SUB, int(time.time())), task_id=IA12_FORCED_TASK_ID)
    records = log_lines()
    failed = _revoke_lines(records, REVOKE_FAILED)
    events = [str(line.get("event", "")) for line in records]
    retry_tails = [event.split(RETRY_MARK, 1)[1] for event in events if RETRY_MARK in event]
    lookups = len(ia73_authentik.requests_to("users"))
    text = json.dumps(records)
    raw_sub_logged = IA12_SUB in text
    url_logged = ia73_authentik.base_url in text

    assert (retried.state, retried.result, lookups) == ("SUCCESS", 1, 3)
    assert failed == [("warning", 0, 0, 0, None, 503, None, None)] * 2
    assert retry_tails == ["Retry in 5s: AuthentikTransient()", "Retry in 10s: AuthentikTransient()"]
    assert raw_sub_logged is False
    assert url_logged is False


def test_ia_12_retry_republish_masks_argsrepr(
    ia73_authentik: Any, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-12 옆(수정 라운드 J4 · 5bA-5 · 5bB-3 — 재시도로 다시 발행되는 메시지의 인자 표시 · 브로커 없음): 워커가 받은 메시지의
    요청 꼴(eager 아님 · called_directly 거짓 · 머리 그대로 — argsrepr `(<redacted>)` · expires · retries 0 · 이름 없는 교환기의
    `celery` 큐)을 작업에 밀어 넣고 자동 재시도 래퍼(`task.run`)를 한 번 부른다. 사용자 조회가 503이면 autoretry가
    `task.retry(exc=…, **retry_kwargs)` → 서명의 apply_async로 다시 발행하는데, 그 발행을 ia-11의 이음매(`identity_admin.celery.app
    .send_task` 가로채기)에서 받는다 → 호출 1회 · 이름 그대로 · args = (원문 sub, nbf)(메시지 본문 — 짝: 원문은 여기에 실린다) ·
    옵션의 argsrepr = `(<redacted>)` · 옵션 repr 어디에도 원문 sub 없음 · countdown 5 · retries 1(설계 D16 첫 대기) · 래퍼는
    Retry를 올린다 · 그 시도의 WARNING `authentik.revoke_failed status=503` 한 줄. Celery 5.6.3은 재발행 때 argsrepr을 물려주지
    않고(Context.as_execution_options) 빈 칸이면 `saferepr(args)`로 다시 만든다(celery.app.amqp as_task_v2) — 등록 옵션
    retry_kwargs가 없으면 이 옵션에 argsrepr이 없다."""
    task = _task(TASK_REVOKE)
    calls = _spy(monkeypatch)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    ia73_authentik.inject("users", 503)
    nbf = int(time.time())
    task.push_request(
        id=str(uuid.uuid4()),
        task=TASK_REVOKE,
        args=[IA12_SUB, nbf],
        kwargs={},
        argsrepr=REDACTED_ARGSREPR,
        kwargsrepr="{}",
        expires=datetime.fromtimestamp(nbf + DELEGATION_WINDOW_S, UTC).isoformat(),
        retries=0,
        called_directly=False,
        is_eager=False,
        delivery_info={"exchange": "", "routing_key": "celery", "priority": None, "redelivered": False},
        hostname="ia12-worker@localhost",
    )
    log_lines()
    raised: str | None = None
    try:
        task.run(IA12_SUB, nbf)
    except Exception as exc:  # noqa: BLE001 — 형 이름만 남긴다(재시도 신호 Retry가 기대값이다)
        raised = type(exc).__name__
    finally:
        task.pop_request()
    records = log_lines()
    call = calls[0] if len(calls) == 1 else None
    options: dict[str, Any] = {} if call is None else call["options"]
    shape = None if call is None else (call["name"], tuple(call["args"] or ()))
    argsrepr = options.get("argsrepr")
    sub_in_options = IA12_SUB in repr(options)
    timing = (options.get("countdown"), options.get("retries"))
    failed = _revoke_lines(records, REVOKE_FAILED)

    assert (raised, len(calls)) == ("Retry", 1)
    assert shape == (TASK_REVOKE, (IA12_SUB, nbf))
    assert argsrepr == REDACTED_ARGSREPR
    assert sub_in_options is False
    assert timing == (5, 1)
    assert failed == [("warning", 0, 0, 0, None, 503, None, None)]


def test_ia_12_forbidden_stops_without_retry(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 「401 · 403 · 그 밖 4xx는 WARNING authentik.revoke_failed status=<코드> 뒤 끝낸다」) — 사용자 조회 403 → 정상
    종료(SUCCESS · 반환 0 · 재시도 없음 — 사용자 조회 1회) · WARNING 한 줄(status 403) · 세션 목록 0 / 대상 세션 둘의 첫 DELETE가
    403 → 그 자리에서 끝(DELETE 1회 · 둘째 세션은 남는다) · WARNING(status 403 · deleted 0) / 짝: 같은 준비물에 403 없음 → 둘 다
    지운다 · 두 실패 갈래의 로그 줄 전부에 가짜 Authentik의 기준 URL이 없다(수정 라운드 J7 · 5bA-3)."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK), make_session(IA12_PK)], settings)
    pair = _delegate()
    pair_view = (pair.state, pair.result)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    ia73_authentik.forbid("users")
    log_lines()
    lookup = _delegate()
    lookup_records = log_lines()
    lookup_lines = _revoke_lines(lookup_records, REVOKE_FAILED)
    lookup_view = (
        lookup.state,
        lookup.result,
        len(ia73_authentik.requests_to("users")),
        len(ia73_authentik.requests_to("sessions")),
    )
    second = make_session(IA12_PK)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK), second], settings)
    ia73_authentik.forbid("session_detail")
    delete = _delegate()
    delete_records = log_lines()
    delete_lines = _revoke_lines(delete_records, REVOKE_FAILED)
    delete_view = (delete.state, delete.result, len(ia73_authentik.requests_to("session_detail")))
    left = _sessions_left(ia73_authentik)
    url_logged = ia73_authentik.base_url in json.dumps(lookup_records + delete_records)

    assert pair_view == ("SUCCESS", 2)
    assert lookup_view == ("SUCCESS", 0, 1, 0)
    assert lookup_lines == [("warning", 0, 0, 0, None, 403, None, None)]
    assert delete_view == ("SUCCESS", 0, 1)
    assert delete_lines == [("warning", 0, 0, 0, None, 403, None, None)]
    assert second["uuid"] in left
    assert url_logged is False


def test_ia_12_expired_window_makes_no_call(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 2단계 — 위임 창 = nbf + 300 s · 작업 안 검사는 `revocation.DELEGATION_WINDOW_S`) — 짝: nbf = 지금 → 호출 있음 ·
    지운다 / nbf = 지금 − 300 − 60(창을 지난 위임 — 큐에 묵은 메시지 · 스냅숏에서 되살아난 메시지) → 호출 0 · SUCCESS · 반환 0 ·
    WARNING `authentik.revoke_expired`(sub_hash · 원문 sub 없음) 한 줄."""
    from django_common.observability import sub_hash

    window = impl("revocation").DELEGATION_WINDOW_S
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    pair = _delegate()
    pair_view = (pair.state, pair.result, len(ia73_authentik.requests) > 0)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    log_lines()
    stale = _delegate(nbf=int(time.time()) - window - 60)
    records = log_lines()
    expired = [(line.get("level"), line.get("sub_hash")) for line in log_events(records, REVOKE_EXPIRED)]
    stale_view = (stale.state, stale.result, len(ia73_authentik.requests))
    raw_sub_logged = IA12_SUB in json.dumps(records)

    assert window == DELEGATION_WINDOW_S
    assert pair_view == ("SUCCESS", 1, True)
    assert stale_view == ("SUCCESS", 0, 0)
    assert expired == [("warning", sub_hash(IA12_SUB))]
    assert raw_sub_logged is False


def test_ia_12_writes_off_or_placeholder_makes_no_call(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 1단계 · D18 — 작업 본체의 방어: enqueue 뒤 플래그 · 자격이 바뀌었을 수 있다) — 짝: 쓰기 켬 + 가짜 토큰 → 호출 있음
    / 쓰기 끔 → 호출 0 · INFO `authentik.revoke_skipped reason=writes_disabled` / 자리값 자격 → 호출 0 · WARNING
    `authentik.calls_disabled reason=placeholder_credential` / 쓰기 끔 + 자리값 → 쓰기 끔 줄 하나뿐(판정 순서 = enqueue와 같다) ·
    모두 SUCCESS · 반환 0."""
    token = settings.AUTHENTIK_API_TOKEN
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    pair = _delegate()
    pair_view = (pair.state, pair.result, len(ia73_authentik.requests) > 0)
    cases: dict[str, dict[str, Any]] = {
        "writes-off": {"AUTHENTIK_WRITES_ENABLED": False},
        "placeholder": {"AUTHENTIK_API_TOKEN": PLACEHOLDER_TOKEN},
        "writes-off-placeholder": {"AUTHENTIK_WRITES_ENABLED": False, "AUTHENTIK_API_TOKEN": PLACEHOLDER_TOKEN},
    }
    outcomes: dict[str, tuple[Any, ...]] = {}
    for case, overrides in cases.items():
        _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
        settings.AUTHENTIK_API_TOKEN = token
        for name, value in overrides.items():
            setattr(settings, name, value)
        log_lines()
        result = _delegate()
        lines = [
            (line.get("event"), line.get("level"), line.get("reason"))
            for line in log_lines()
            if str(line.get("event", "")).startswith("authentik.")
        ]
        outcomes[case] = (result.state, result.result, len(ia73_authentik.requests), lines)

    assert pair_view == ("SUCCESS", 1, True)
    assert outcomes == {
        "writes-off": ("SUCCESS", 0, 0, [(SKIPPED, "info", "writes_disabled")]),
        "placeholder": ("SUCCESS", 0, 0, [(DISABLED, "warning", "placeholder_credential")]),
        "writes-off-placeholder": ("SUCCESS", 0, 0, [(SKIPPED, "info", "writes_disabled")]),
    }


def test_ia_12_zero_deadline_is_transient_without_calls(
    ia73_authentik: Any, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-12(D16 「한 시도 전체 마감 = jobs.DELEGATION_DEADLINE_S」 · D20) — 짝: 기본 마감 → SUCCESS · 호출 있음 / 이음매
    `jobs.DELEGATION_DEADLINE_S`를 0으로 덮는다 → 시도마다 첫 호출 앞에서 마감(일시 오류) → 재시도가 다 쓰인 뒤 FAILURE · 결과 예외
    AuthentikTransient(문구 "" · 연쇄 없음) · 호출 0 · 시도마다 WARNING `authentik.revoke_failed error=deadline`(시도 4회)."""
    jobs = impl("jobs")
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    pair = _delegate()
    pair_view = (pair.state, pair.result, len(ia73_authentik.requests) > 0)
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    monkeypatch.setattr(jobs, "DELEGATION_DEADLINE_S", 0)
    log_lines()
    lapsed = _delegate()
    failed = _revoke_lines(log_lines(), REVOKE_FAILED)
    outcome = lapsed.result
    message_empty = str(outcome) == ""
    lapsed_view = (lapsed.state, type(outcome).__name__, message_empty, _chain(outcome), len(ia73_authentik.requests))

    assert pair_view == ("SUCCESS", 1, True)
    assert lapsed_view == ("FAILURE", "AuthentikTransient", True, ("NoneType", "NoneType"), 0)
    assert failed == [("warning", 0, 0, 0, None, None, "deadline", None)] * (DELEGATION_RETRIES + 1)


def test_ia_12_endless_next_stops_at_ten_pages(
    ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines
) -> None:
    """ia-12(D16 4단계 — 세션 목록 쪽 상한 10 · `authentik.SESSION_PAGE_LIMIT`) — `pagination.next`가 끝나지 않는 가짜 → 세션 목록
    요청 정확히 10 · 천장 도달 0(쪽 상한이 없는 구현은 가짜의 천장에서 스스로 끝나 요청 수에서 빨강이다 — 시간이 아니라 요청 수로
    본다) · SUCCESS · 첫 쪽의 대상 세션은 지운다(반환 1) · `authentik.revoke_done truncated` 참."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    ia73_authentik.endless_next = True
    log_lines()
    result, _ = timed(_delegate, IA12_TIME_LIMIT_S)
    done = _revoke_lines(log_lines(), REVOKE_DONE)
    view = (
        result.state,
        result.result,
        len(ia73_authentik.requests_to("sessions")),
        ia73_authentik.ceiling_hits,
    )

    assert view == ("SUCCESS", 1, SESSION_PAGES, 0)
    assert done == [("info", 1, 0, 0, True, None, None, None)]


def test_ia_12_user_lookup_shapes(ia73_authentik: Any, settings: SettingsWrapper, log_lines: LogLines) -> None:
    """ia-12(D16 3단계 — uuid가 같은 결과 정확히 1 · pk 정수(bool 제외) · username 비지 않은 str) — 짝: 정상 → 세션 목록 1회 /
    사용자 없음 → WARNING `authentik.revoke_user_missing` · 세션 목록 0 / 응답의 pk가 bool · username이 빈 문자열 · 같은 uuid가 둘 →
    WARNING `authentik.revoke_failed error=malformed` · 세션 목록 0 / sub가 문자 규칙(출력 가능 ASCII 1-255자) 밖 → 호출 0 ·
    WARNING `authentik.revoke_failed error=invalid_request`(사용자 조회 앞에서 본다 — find_user는 꼴이 아닌 인자에 「사용자 없음」과
    같은 []를 준다) · 모두 SUCCESS · 반환 0(재시도 없음).
    수정 라운드 J3(5bA-2 · 5bB-2 — `sub_hash`를 실패 틀 안으로): 빈 sub(표의 None = 기본 sub와 구별된다) · lone surrogate가 든 sub
    (`sub_hash`가 UnicodeEncodeError를 올리고 그 repr이 원문 sub를 싣던 입력) · nbf가 str · float → 모두 SUCCESS · 반환 0 · 요청 0 ·
    WARNING `authentik.revoke_failed error=invalid_request` · 결과 · 트레이스백 · 로그 줄 전부에 심은 값 0(짝: 위의 정상 sub · nbf는
    요청이 나간다)."""

    def users_body(*users: dict[str, Any]) -> tuple[int, dict[str, Any]]:
        return 200, {"pagination": {"next": 0}, "results": list(users)}

    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    pair = _delegate()
    pair_view = (pair.state, pair.result, len(ia73_authentik.requests_to("sessions")))
    planted = f"ia12-planted-{secrets.token_hex(4)}"  # lone surrogate sub의 ASCII 앞부분(심은 값 — 어디에도 실리지 않아야 한다)
    now = int(time.time())
    # 사례 → (sub(None = 기본 sub), nbf(None = 지금), 사용자 조회 주입 본문(None = 주입 없음))
    shaped: dict[str, tuple[str | None, Any, Any]] = {
        "missing": (None, None, users_body()),
        "pk-bool": (None, None, users_body({"pk": True, "uuid": IA12_SUB, "username": "ia12-target"})),
        "username-empty": (None, None, users_body({"pk": IA12_PK, "uuid": IA12_SUB, "username": ""})),
        "duplicate": (
            None,
            None,
            users_body(
                {"pk": IA12_PK, "uuid": IA12_SUB, "username": "ia12-target"},
                {"pk": IA12_OTHER_PK, "uuid": IA12_SUB, "username": "ia12-other"},
            ),
        ),
        "sub-space": ("ia12 bad sub", None, None),
        "sub-empty": ("", None, None),
        "sub-surrogate": (planted + chr(0xD800), None, None),
        "nbf-str": (None, str(now), None),
        "nbf-float": (None, float(now), None),
    }
    outcomes: dict[str, tuple[Any, ...]] = {}
    leaked: dict[str, bool] = {}
    for case, (case_sub, case_nbf, body) in shaped.items():
        _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
        if body is not None:
            ia73_authentik.inject("users", body)
        log_lines()
        result = _task(TASK_REVOKE).apply(
            args=(IA12_SUB if case_sub is None else case_sub, int(time.time()) if case_nbf is None else case_nbf)
        )
        records = log_lines()
        lines = [
            (line.get("event"), line.get("level"), line.get("error"))
            for line in records
            if str(line.get("event", "")).startswith("authentik.")
        ]
        outcome = result.result
        state = result.state
        leaked[case] = planted in json.dumps(records) + repr(outcome) + str(result.traceback or "")
        outcomes[case] = (
            state,
            outcome if isinstance(outcome, int) else type(outcome).__name__,
            len(ia73_authentik.requests_to("users")),
            len(ia73_authentik.requests_to("sessions")),
            lines,
        )
    invalid_request = ("SUCCESS", 0, 0, 0, [(REVOKE_FAILED, "warning", "invalid_request")])

    assert pair_view == ("SUCCESS", 1, 1)
    assert outcomes == {
        "missing": ("SUCCESS", 0, 1, 0, [(REVOKE_USER_MISSING, "warning", None)]),
        "pk-bool": ("SUCCESS", 0, 1, 0, [(REVOKE_FAILED, "warning", "malformed")]),
        "username-empty": ("SUCCESS", 0, 1, 0, [(REVOKE_FAILED, "warning", "malformed")]),
        "duplicate": ("SUCCESS", 0, 1, 0, [(REVOKE_FAILED, "warning", "malformed")]),
        "sub-space": invalid_request,
        "sub-empty": invalid_request,
        "sub-surrogate": invalid_request,
        "nbf-str": invalid_request,
        "nbf-float": invalid_request,
    }
    assert leaked == dict.fromkeys(shaped, False)


def _record_deadlines(monkeypatch: pytest.MonkeyPatch) -> list[Any]:
    """이음매 `outbound.request_json`(모듈 속성 — `authentik._call`이 그렇게 부른다)을 실제 함수를 그대로 부르는 감싸기로 덮어
    호출마다의 `deadline` 인자를 기록한다(동작은 바꾸지 않는다 · 대상 모듈을 먼저 적재한 뒤 덮는다)."""
    outbound = impl("outbound")
    impl("authentik")
    real_request = outbound.request_json
    deadlines: list[Any] = []

    def recording_request(*args: Any, **kwargs: Any) -> Any:
        deadlines.append(kwargs.get("deadline"))
        return real_request(*args, **kwargs)

    monkeypatch.setattr(outbound, "request_json", recording_request)
    return deadlines


def _deadline_view(deadlines: list[Any]) -> tuple[int, bool, int, set[str]]:
    """(호출 수, 모두 None 아님, 서로 다른 객체 수, 형 이름 집합)."""
    return (
        len(deadlines),
        all(deadline is not None for deadline in deadlines),
        len({id(deadline) for deadline in deadlines}),
        {type(deadline).__name__ for deadline in deadlines},
    )


def test_ia_12_one_deadline_reaches_every_call(
    ia73_authentik: Any, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ia-12(수정 라운드 J5 · 5bB-4 — 한 시도 전체 마감이 호출마다 전달된다 · 구현은 맞다: 고정 사례): `outbound.request_json`을
    감싸 `deadline` 인자를 기록한다. 필터를 무시하는 가짜에 남의 세션 100개 + 대상 세션 둘(첫 쪽 · 둘째 쪽에 하나씩) → SUCCESS ·
    반환 2 · 세션 목록 2쪽 · DELETE 2 · 호출 5(사용자 조회 1 · 세션 목록 2 · DELETE 2)의 deadline이 모두 None이 아니고 한
    객체(outbound.Deadline — 마감 0 s 사례는 첫 호출만 본다: `list_sessions` · `delete_session`에서 deadline이 빠지면 여기서
    빨강이다)."""
    mine = [make_session(IA12_PK), make_session(IA12_PK)]
    theirs = [make_session(IA12_OTHER_PK) for _ in range(100)]
    _ia12_seed(ia73_authentik, [mine[0], *theirs, mine[1]], settings)
    ia73_authentik.ignore_filters = True
    deadlines = _record_deadlines(monkeypatch)
    result = _delegate()
    view = (
        result.state,
        result.result,
        len(ia73_authentik.requests_to("sessions")),
        ia73_authentik.deleted_sessions,
    )
    passed = _deadline_view(deadlines)

    assert view == ("SUCCESS", 2, 2, [session["uuid"] for session in mine])
    assert passed == (5, True, 1, {"Deadline"})


class PlantedDelegationError(Exception):
    """시험이 심는 위임 본체의 예상 밖 예외(문구에 호스트 · sub 꼴 값을 심는다 — 로그 · 트레이스백에 실리지 않는지 본다)."""


def test_ia_12_unexpected_error_fails_without_message(
    ia73_authentik: Any, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-12(조각 ⑤-b P5 — 작업의 실패 틀) — 짝: 덮기 전의 같은 준비물 → SUCCESS / 이음매 `authentik.find_user`가 호스트 · sub 꼴의
    값을 문구에 심은 예외(HTTP 오류 형이 아니다)를 던지면 → 상태 FAILURE · 결과 예외 `jobs.DelegationFailed`(문구 "" · 연쇄 없음 —
    `__cause__` · `__context__` 둘 다 None) · 재시도 없음(find_user 1회) · WARNING `authentik.revoke_failed` 한 줄(error = 심은
    예외의 클래스 이름) · 로그 줄 전부와 결과 트레이스백에 심은 값 0."""
    _ia12_seed(ia73_authentik, [make_session(IA12_PK)], settings)
    pair_state = _delegate().state
    planted = {
        "host": f"authentik-planted-{secrets.token_hex(4)}.internal",
        "sub": str(uuid.uuid4()),
    }
    calls: list[int] = []

    def broken_find_user(*args: Any, **kwargs: Any) -> Any:
        calls.append(1)
        raise PlantedDelegationError(f"lookup of {planted['sub']} at http://{planted['host']}:9000 failed")

    monkeypatch.setattr(impl("authentik"), "find_user", broken_find_user)
    log_lines()
    down = _delegate()
    records = log_lines()
    outcome = down.result
    message_empty = str(outcome) == ""
    chain = _chain(outcome)
    failed_lines = [
        (line.get("level"), line.get("error") == "PlantedDelegationError")
        for line in log_events(records, REVOKE_FAILED)
    ]
    text = json.dumps(records) + str(down.traceback or "")
    leaked = {name: Secret(value) in Secret(text) for name, value in planted.items()}
    clean = dict.fromkeys(planted, False)

    assert pair_state == "SUCCESS"
    assert (down.state, type(outcome).__name__, message_empty, len(calls)) == ("FAILURE", "DelegationFailed", True, 1)
    assert chain == ("NoneType", "NoneType")
    assert failed_lines == [("warning", True)]
    assert leaked == clean


# --- 조각 ⑤-b: ia-13(D17 — 일 1회 logout 이벤트 대조) ----------------------------------------------------------------------

RECONCILE_DONE = "authentik.reconcile_done"
RECONCILE_FAILED = "authentik.reconcile_failed"
RECONCILE_FORBIDDEN = "authentik.reconcile_forbidden"
RECONCILE_TRUNCATED = "authentik.reconcile_truncated"
RECONCILE_SKIPPED = "authentik.reconcile_skipped"
RECONCILE_KEYS = ("seen", "recorded", "skipped")  # 반환 계약(설계 D17 8단계)
EVENT_PAGES = 50  # 설계 D17 2 · D26 authentik.EVENT_PAGE_LIMIT(시험의 독립 기대값)
WINDOW_S = 72 * 3600  # 설계 D17 창(jobs.RECONCILE_WINDOW)
WEBHOOK_REASON = "authentik_webhook"
# 사용자 넷(A · B · C는 테넌트 A 멤버십 · N은 멤버십 없음) — uuid가 sub다.
IA13_A = {"pk": 301, "uuid": "1a130000-0000-4000-8000-000000000301", "username": "ia13-a"}
IA13_B = {"pk": 302, "uuid": "1a130000-0000-4000-8000-000000000302", "username": "ia13-b"}
IA13_C = {"pk": 303, "uuid": "1a130000-0000-4000-8000-000000000303", "username": "ia13-c"}
IA13_N = {"pk": 304, "uuid": "1a130000-0000-4000-8000-000000000304", "username": "ia13-n"}
IA13_MISSING_PKS = (305, 306)  # 가짜에 없는 사용자(사용자 조회 404)


def _reconcile_run() -> Any:
    """대조 작업 1회(eager apply · 결과는 .state · .result로 본다 — 실패 사례에서 예외를 다시 던지지 않는다)."""
    return _task(TASK_RECONCILE_AUTHENTIK).apply()


def _ia13_seed(fake: Any, events: list[dict[str, Any]], *, members: tuple[dict[str, Any], ...] = ()) -> None:
    """확장 가짜(사용자 넷 + events) · members의 TenantMembership(테넌트 A)."""
    fake.reset(users=(IA13_A, IA13_B, IA13_C, IA13_N), events=events)
    for user in members:
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=user["uuid"], role="member")


def _at_offset(offset_s: float) -> datetime:
    """지금(시험 프로세스 = 워커 시계 time.time()) + offset_s의 aware UTC 시각(소수 초 그대로)."""
    return datetime.fromtimestamp(time.time() + offset_s, UTC)


def _iso_plus(moment: datetime) -> str:
    """`+00:00` 꼴 ISO 8601(초 단위 — DRF `…Z` 꼴과 섞어 넣는다)."""
    return moment.replace(microsecond=0).isoformat()


def _backfill_nbf(moment: datetime) -> int:
    """설계 D17 7단계의 기대값 — ⌊created⌋ + 1."""
    return math.floor(moment.timestamp()) + 1


def _log_rows() -> dict[str | None, tuple[Any, ...]]:
    """session_revocation_log 행 — event_pk → (sub, nbf epoch, reason, sid, tenant_id 문자열)."""
    fields = ("event_pk", "sub", "nbf", "reason", "sid", "tenant_id")
    found = model("session_revocation_log").objects.values_list(*fields)
    return {pk: (sub, _epoch_floor(nbf), reason, sid, str(tenant)) for pk, sub, nbf, reason, sid, tenant in found}


def _outbox_count() -> int:
    count: int = model("outbox").objects.count()
    return count


def _reconcile_lines(records: list[dict[str, Any]], event: str) -> list[tuple[Any, ...]]:
    """대조 로그 줄의 (level, seen, recorded, skipped, pages, status, error, reason, count) — 값이 없는 칸은 None."""
    fields = ("level", "seen", "recorded", "skipped", "pages", "status", "error", "reason", "count")
    return [tuple(line.get(name) for name in fields) for line in log_events(records, event)]


def _authentik_events(records: list[dict[str, Any]]) -> list[str]:
    return [str(line.get("event")) for line in records if str(line.get("event", "")).startswith("authentik.")]


def _user_lookups(fake: Any) -> list[str]:
    return [request.path for request in fake.requests_to("user_detail")]


def _counts(seen: int, recorded: int, skipped: int) -> dict[str, int]:
    return {"seen": seen, "recorded": recorded, "skipped": skipped}


@DB
def test_ia_13_backfills_missing_logout(ia73_authentik: Any, ia73_df_admin: redis.Redis, log_lines: LogLines) -> None:
    """ia-13(D17 3-8단계 · 백필 행의 효과) — 쓰기 플래그 거짓(ia73_env 기본 — 대조는 읽기라 플래그와 무관하다 · D18) · logout 넷:
    A의 셋(created = DRF `…Z` 소수 초 꼴 · `+00:00` 꼴 · DRF `…Z` 소수 초 없는 꼴(수정 라운드 J7 · 5bA-3) · 한 pk는 대문자 UUID) ·
    멤버십 없는 N의 하나.
    1차 → 행 3(event_pk = 정규형 · nbf = ⌊created⌋ + 1 · reason authentik_webhook · sid 없음 · 테넌트 A) · outbox 3 · 반환
    {seen 4, recorded 3, skipped 1}(N은 멤버십 없음으로 건너뜀) · INFO `authentik.reconcile_done`(seen 4 · recorded 3 · skipped 1 ·
    pages 1) · `session_revocation.recorded source=reconcile` 셋 · A의 사용자 조회는 1회(캐시) · 세션 하한 키 = 가장 큰 nbf ·
    `revoked:sub`는 TTL이 지나 없다(이벤트 시각이 nbf다).
    2차(같은 이벤트) → 무변화(행 3 · outbox 3) · 반환 {seen 4, recorded 0, skipped 4} · 이미 있는 pk는 사용자 조회 앞에서 건너뛴다
    (A의 사용자 조회 0 — 2차의 사용자 조회는 N 하나뿐) · 로그 줄 전부에 원문 sub 없음. 멤버십 없음 · 이미 기록됨은 정상 건너뜀이라
    두 실행 모두 `authentik.reconcile_skipped` 0줄(수정 라운드 J2 — 꼴 어긋남만 센다)."""
    # 첫 시각의 소수 초는 고정한다(조각 ⑥ X2 · 5bV-3): time.time()에서 온 마이크로초가 0이면 DRF 꼴의 소수 초가 빠져
    # created_shapes의 첫 칸이 어긋난다(약 100만분의 1). 기대 nbf는 이 값에서 계산하므로 그대로 맞는다.
    first_at = _at_offset(-3600.5).replace(microsecond=500_000)
    second_at, other_at = _at_offset(-1800.0), _at_offset(-600.0)
    third_at = _at_offset(-2700).replace(microsecond=0)  # DRF `…Z` 소수 초 없는 꼴
    upper_pk = str(uuid.uuid4()).upper()
    first = make_event(IA13_A["pk"], first_at, pk=upper_pk)
    second = make_event(IA13_A["pk"], _iso_plus(second_at))
    third = make_event(IA13_A["pk"], third_at)
    other = make_event(IA13_N["pk"], other_at)
    created_shapes = [event["created"][-1] + str("." in event["created"]) for event in (first, second, third)]
    _ia13_seed(ia73_authentik, [first, second, third, other], members=(IA13_A,))
    log_lines()
    run1 = _reconcile_run()
    records1 = log_lines()
    rows1 = _log_rows()
    outbox1 = _outbox_count()
    lookups1 = _user_lookups(ia73_authentik)
    recorded_sources = [line.get("source") for line in log_events(records1, "session_revocation.recorded")]
    floor_value = read_int(ia73_df_admin, floor_key(IA13_A["uuid"]))
    sub_key_present = ia73_df_admin.exists(sub_key(IA13_A["uuid"]))
    log_lines()
    ia73_authentik.reset(users=(IA13_A, IA13_B, IA13_C, IA13_N), events=[first, second, third, other])
    run2 = _reconcile_run()
    records2 = log_lines()
    second_nbf = _backfill_nbf(datetime.fromisoformat(_iso_plus(second_at)))
    expected_rows = {
        upper_pk.lower(): (IA13_A["uuid"], _backfill_nbf(first_at), WEBHOOK_REASON, None, TENANT_A),
        second["pk"]: (IA13_A["uuid"], second_nbf, WEBHOOK_REASON, None, TENANT_A),
        third["pk"]: (IA13_A["uuid"], _backfill_nbf(third_at), WEBHOOK_REASON, None, TENANT_A),
    }
    raw_sub_logged = any(user["uuid"] in json.dumps(records1 + records2) for user in (IA13_A, IA13_N))
    done1 = _reconcile_lines(records1, RECONCILE_DONE)
    skipped_lines = (_reconcile_lines(records1, RECONCILE_SKIPPED), _reconcile_lines(records2, RECONCILE_SKIPPED))
    after2 = (_log_rows(), _outbox_count(), _user_lookups(ia73_authentik))

    assert created_shapes == ["ZTrue", "0False", "ZFalse"]  # …Z 소수 초 · +00:00 · …Z 소수 초 없음
    assert (run1.state, run1.result) == ("SUCCESS", _counts(4, 3, 1))
    assert (rows1, outbox1) == (expected_rows, 3)
    assert done1 == [("info", 4, 3, 1, 1, None, None, None, None)]
    assert recorded_sources == ["reconcile", "reconcile", "reconcile"]
    assert sorted(lookups1) == [f"/api/v3/core/users/{IA13_A['pk']}/", f"/api/v3/core/users/{IA13_N['pk']}/"]
    assert (floor_value, sub_key_present) == (second_nbf, 0)
    assert (run2.state, run2.result) == ("SUCCESS", _counts(4, 0, 4))
    assert after2 == (expected_rows, 3, [f"/api/v3/core/users/{IA13_N['pk']}/"])
    assert skipped_lines == ([], [])
    assert raw_sub_logged is False


@DB
def test_ia_13_rechecks_every_event_under_ignored_filters(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(D17 3단계 · 〔Y17〕 — 필터 무시 미끼 · 정렬 뒤섞기): 가짜가 질의(actions · ordering)를 무시하고 넣은 차례 그대로 준다 —
    맨 앞이 창 밖(73 h 전) logout · 그다음 login · user 없는 이벤트 세 꼴(`"user": {}` · 키 없음 · `"user": None`) · pk가 정수인
    logout · action 키가 없는 이벤트 · tz 없는 `created`(지금 − 24 h의 UTC 벽시계 — 어느 시간대로 읽어도 창 안이다) · 정수
    `created` · `user.pk` `"301"` · `user.pk` `True`(수정 라운드 J7 · 5bB-6) · 창 안 logout 둘(A · B — `+00:00` 꼴 · `…Z` 소수 초
    꼴). 결과: SUCCESS(예외로 실행 전체가 끝나지 않는다 — tz 검사가 빠지면 aware − naive의 TypeError로 FAILURE) · 행은 창 안 logout
    둘뿐(정렬에 기대어 창 밖 이벤트에서 멈추지 않는다) · 반환 {seen 17, recorded 2, skipped 15}.
    수정 라운드 J2(5bB-1): 꼴 어긋남 열(user 없는 셋 · 정수 pk · action 없음 · tz 없음 · 정수 created · `"301"` · `True` · 아래
    `"a b"`)만 세어 끝에 WARNING `authentik.reconcile_skipped`(reason malformed · count 10) 한 줄 → `reconcile_done`(창 밖 logout ·
    login은 대상 아님이라 세지 않는다).
    조각 ⑥ X1(5bV-1 — 셈의 경계): 창 안 logout의 이벤트 pk `"a b"`(str인데 문자 규칙 밖 — 센다 · 행 0 · 검사가 빠지면 관문의
    RevocationRejected로 실행 전체가 FAILURE가 되고 같은 실행의 정상 둘도 남지 않는다) · 창 밖(73 h 전) logout의 `user.pk`
    `"301"`과 `"user": {}`(세지 않는다 — 창 밖은 꼴을 보지 않는다: user.pk 검사가 창 검사 앞으로 가면 센다) · `action="login"`에
    `created="not-a-date"`(세지 않는다 — created 검사가 action 검사 앞으로 가면 센다)."""
    stale = make_event(IA13_A["pk"], _at_offset(-(WINDOW_S + 3600)))
    stale_str_user_pk = make_event(str(IA13_A["pk"]), _at_offset(-(WINDOW_S + 3600 + 10)))
    stale_no_user = make_event(None, _at_offset(-(WINDOW_S + 3600 + 20)))
    login_bad_created = make_event(IA13_A["pk"], "not-a-date", action="login")
    spaced_pk = make_event(IA13_A["pk"], _at_offset(-180), pk="a b")
    login = make_event(IA13_A["pk"], _at_offset(-60), action="login")
    no_user_empty = make_event(None, _at_offset(-100))
    no_user_missing = make_event(IA13_A["pk"], _at_offset(-110))
    del no_user_missing["user"]
    no_user_none = make_event(IA13_A["pk"], _at_offset(-120))
    no_user_none["user"] = None
    int_pk = make_event(IA13_A["pk"], _at_offset(-130), pk=12345)
    no_action = make_event(IA13_A["pk"], _at_offset(-140))
    del no_action["action"]
    naive_created = make_event(IA13_A["pk"], _at_offset(-86400).replace(tzinfo=None))
    int_created = make_event(IA13_A["pk"], _at_offset(-150))
    int_created["created"] = int(time.time()) - 150
    str_user_pk = make_event(str(IA13_A["pk"]), _at_offset(-160))
    bool_user_pk = make_event(True, _at_offset(-170))
    ok_a_at, ok_b_at = _at_offset(-7200), _at_offset(-300.25)
    ok_a = make_event(IA13_A["pk"], _iso_plus(ok_a_at))
    ok_b = make_event(IA13_B["pk"], ok_b_at)
    malformed = [no_user_empty, no_user_missing, no_user_none, int_pk, no_action, naive_created, int_created]
    malformed += [str_user_pk, bool_user_pk, spaced_pk]
    not_counted = [stale, login, stale_str_user_pk, stale_no_user, login_bad_created]  # 대상 아님(창 밖 · logout 아님)
    events = [*not_counted, *malformed, ok_a, ok_b]
    _ia13_seed(ia73_authentik, events, members=(IA13_A, IA13_B))
    ia73_authentik.ignore_filters = True
    ia73_authentik.ignore_ordering = True
    log_lines()
    run = _reconcile_run()
    records = log_lines()
    ok_a_nbf = _backfill_nbf(datetime.fromisoformat(ok_a["created"]))
    expected_rows = {
        ok_a["pk"]: (IA13_A["uuid"], ok_a_nbf, WEBHOOK_REASON, None, TENANT_A),
        ok_b["pk"]: (IA13_B["uuid"], _backfill_nbf(ok_b_at), WEBHOOK_REASON, None, TENANT_A),
    }
    after = (_log_rows(), _outbox_count())
    done = _reconcile_lines(records, RECONCILE_DONE)
    skipped = _reconcile_lines(records, RECONCILE_SKIPPED)
    order = _authentik_events(records)
    naive_offset = datetime.fromisoformat(naive_created["created"]).utcoffset()  # 미끼가 정말 tz 없는 꼴인가

    assert (len(events), len(malformed), naive_offset) == (17, 10, None)
    assert (run.state, run.result) == ("SUCCESS", _counts(17, 2, 15))
    assert after == (expected_rows, 2)
    assert done == [("info", 17, 2, 15, 1, None, None, None, None)]
    assert skipped == [("warning", None, None, None, None, None, None, "malformed", 10)]
    assert order == [RECONCILE_SKIPPED, RECONCILE_DONE]


@DB
def test_ia_13_future_events_are_not_recorded(
    ia73_authentik: Any, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-13(D17 3단계 창 위쪽 끝 · 〔Z3〕 — 이 경로에서 미래 nbf를 막는 유일한 방어 · 설계 D29 불변식 5): C의 logout이 created = 지금
    + 600 s · + 1 h → 행 0 · outbox 0 · C의 키(`revoked:sub` · 세션 하한) 0 / 경계 B의 logout created = 지금 + 290 s → 기록(nbf =
    ⌊created⌋ + 1 · 처리 지연 1 s에 뒤집히는 「+ 301 s」 같은 값은 쓰지 않는다) · 반환 {seen 3, recorded 1, skipped 2} · 창 밖은 정상
    건너뜀이라 `authentik.reconcile_skipped` 0줄(수정 라운드 J2 — 꼴 어긋남만 센다)."""
    edge_at = _at_offset(290)
    edge = make_event(IA13_B["pk"], edge_at)
    events = [make_event(IA13_C["pk"], _at_offset(600)), make_event(IA13_C["pk"], _at_offset(3600)), edge]
    _ia13_seed(ia73_authentik, events, members=(IA13_B, IA13_C))
    log_lines()
    run = _reconcile_run()
    records = log_lines()
    c_keys = [key for key in (sub_key(IA13_C["uuid"]), floor_key(IA13_C["uuid"])) if ia73_df_admin.exists(key)]
    expected_rows = {edge["pk"]: (IA13_B["uuid"], _backfill_nbf(edge_at), WEBHOOK_REASON, None, TENANT_A)}
    floor_b = read_int(ia73_df_admin, floor_key(IA13_B["uuid"]))
    skipped = _reconcile_lines(records, RECONCILE_SKIPPED)

    assert (run.state, run.result) == ("SUCCESS", _counts(3, 1, 2))
    assert (_log_rows(), _outbox_count(), c_keys) == (expected_rows, 1, [])
    assert floor_b == _backfill_nbf(edge_at)
    assert skipped == []


@DB
def test_ia_13_second_page_and_page_ceiling(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(D17 2단계 — 쪽 단위 · 상한 50 · `authentik.EVENT_PAGE_LIMIT`): 정렬을 뒤섞은 가짜에서 첫 쪽 100개가 창 밖이고 둘째 쪽의
    누락 logout → 기록(이벤트 목록 요청 2 · 반환 {seen 101, recorded 1, skipped 100} · done pages 2) / `pagination.next`가 끝나지
    않는 가짜(이벤트 0개) → 이벤트 목록 요청 정확히 50 · 천장 도달 0(시간이 아니라 요청 수로 본다) · WARNING
    `authentik.reconcile_truncated`(pages 50) 한 줄 · done pages 50 · SUCCESS."""
    old = [make_event(IA13_A["pk"], _at_offset(-(WINDOW_S + 7200 + index))) for index in range(100)]
    late_at = _at_offset(-900)
    late = make_event(IA13_A["pk"], late_at)
    _ia13_seed(ia73_authentik, [*old, late], members=(IA13_A,))
    ia73_authentik.ignore_ordering = True
    log_lines()
    paged = _reconcile_run()
    paged_records = log_lines()
    paged_view = (paged.state, paged.result, len(ia73_authentik.requests_to("events")), set(_log_rows()))
    ia73_authentik.reset(users=(IA13_A,), events=[])
    ia73_authentik.endless_next = True
    endless, _ = timed(_reconcile_run, IA12_TIME_LIMIT_S)
    endless_records = log_lines()
    endless_view = (
        endless.state,
        endless.result,
        len(ia73_authentik.requests_to("events")),
        ia73_authentik.ceiling_hits,
    )

    assert paged_view == ("SUCCESS", _counts(101, 1, 100), 2, {late["pk"]})
    assert _reconcile_lines(paged_records, RECONCILE_DONE) == [("info", 101, 1, 100, 2, None, None, None, None)]
    assert endless_view == ("SUCCESS", _counts(0, 0, 0), EVENT_PAGES, 0)
    assert [line[:1] + line[4:5] for line in _reconcile_lines(endless_records, RECONCILE_TRUNCATED)] == [
        ("warning", EVENT_PAGES)
    ]
    assert _reconcile_lines(endless_records, RECONCILE_DONE) == [("info", 0, 0, 0, EVENT_PAGES, None, None, None, None)]


@DB
def test_ia_13_listing_failures_and_disabled_credential(
    ia73_authentik: Any, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-13(D17 「실패」 · 「권한이 없을 때」 · D18) — 사례마다 새 이벤트 · 끝은 모두 정상 종료(SUCCESS · 반환 = 그때까지의 건수 ·
    재시도 없음 — 다음 날 다시).
    - 짝: 정상 → 호출 있음 · 기록 1.
    - 자리값 자격 → 호출 0 · WARNING `authentik.calls_disabled reason=placeholder_credential` · 반환 0 셋.
    - 이벤트 조회 403 → 행 변화 0 · WARNING `authentik.reconcile_forbidden status=403` · done 줄 없음.
    - 이벤트 조회 404 → 행 변화 0 · WARNING `authentik.reconcile_failed status=404`(조용히 끝나지 않는다 — 〔Z13〕).
    - 둘째 쪽 503(이벤트 250개 — 첫 쪽에 창 안 logout 하나) → 첫 쪽에서 기록한 행은 남는다 · 그 자리에서 멈춤(이벤트 목록 요청 2 —
      셋째 쪽 0) · WARNING `authentik.reconcile_failed status=503` · 반환 {seen 100, recorded 1, skipped 99}.
    - 마감 0 s(이음매 `jobs.RECONCILE_DEADLINE_S` = 0) → 호출 0 · WARNING `authentik.reconcile_failed error=deadline`.
    - 실패 갈래(짝 밖의 사례 전부)의 로그 줄에 가짜 Authentik의 기준 URL이 없다(수정 라운드 J7 · 5bA-3)."""
    failure_records: list[dict[str, Any]] = []

    def fresh_logout() -> list[dict[str, Any]]:
        return [make_event(IA13_A["pk"], _at_offset(-60))]

    def run_case() -> tuple[Any, ...]:
        before = len(_log_rows())
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        failure_records.extend(records)
        lines = [
            (line.get("event"), line.get("level"), line.get("status"), line.get("error"), line.get("reason"))
            for line in records
            if line.get("event") in (RECONCILE_FAILED, RECONCILE_FORBIDDEN, DISABLED, RECONCILE_DONE)
        ]
        return result.state, result.result, len(ia73_authentik.requests), len(_log_rows()) - before, lines

    token = settings.AUTHENTIK_API_TOKEN
    _ia13_seed(ia73_authentik, fresh_logout(), members=(IA13_A,))
    outcomes: dict[str, tuple[Any, ...]] = {"pair": run_case()}
    failure_records.clear()  # 짝(정상 실행)의 줄은 뺀다 — 아래는 실패 · 자리값 갈래의 줄만
    ia73_authentik.reset(users=(IA13_A,), events=fresh_logout())
    settings.AUTHENTIK_API_TOKEN = PLACEHOLDER_TOKEN
    outcomes["placeholder"] = run_case()
    settings.AUTHENTIK_API_TOKEN = token
    ia73_authentik.reset(users=(IA13_A,), events=fresh_logout())
    ia73_authentik.forbid("events")
    outcomes["events-403"] = run_case()
    ia73_authentik.reset(users=(IA13_A,), events=fresh_logout())
    ia73_authentik.inject("events", 404)
    outcomes["events-404"] = run_case()
    old = [make_event(IA13_A["pk"], _at_offset(-(WINDOW_S + 7200 + index))) for index in range(249)]
    ia73_authentik.reset(users=(IA13_A,), events=[*fresh_logout(), *old])
    ia73_authentik.inject("events", None, 503)
    outcomes["page2-503"] = run_case()
    page2_requests = len(ia73_authentik.requests_to("events"))
    ia73_authentik.reset(users=(IA13_A,), events=fresh_logout())
    monkeypatch.setattr(impl("jobs"), "RECONCILE_DEADLINE_S", 0)
    outcomes["deadline-0"] = run_case()
    zero = _counts(0, 0, 0)
    url_logged = ia73_authentik.base_url in json.dumps(failure_records)
    failure_lines = len(failure_records)

    assert outcomes == {
        "pair": ("SUCCESS", _counts(1, 1, 0), 2, 1, [(RECONCILE_DONE, "info", None, None, None)]),
        "placeholder": ("SUCCESS", zero, 0, 0, [(DISABLED, "warning", None, None, "placeholder_credential")]),
        "events-403": ("SUCCESS", zero, 1, 0, [(RECONCILE_FORBIDDEN, "warning", 403, None, None)]),
        "events-404": ("SUCCESS", zero, 1, 0, [(RECONCILE_FAILED, "warning", 404, None, None)]),
        "page2-503": ("SUCCESS", _counts(100, 1, 99), 3, 1, [(RECONCILE_FAILED, "warning", 503, None, None)]),
        "deadline-0": ("SUCCESS", zero, 0, 0, [(RECONCILE_FAILED, "warning", None, "deadline", None)]),
    }
    assert page2_requests == 2
    assert (failure_lines > 0, url_logged) == (True, False)


@DB
def test_ia_13_user_lookups_cache_and_permissions(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(D17 5단계 · 「권한이 없을 때」 · 〔W2〕) — 같은 사용자(A)의 logout 둘 → 사용자 조회 1회(실행 안 pk → uuid 캐시) · 행 2 /
    두 사용자 모두 사용자 조회 404(가짜에 없는 pk 둘) → 행 0 · 끝에 WARNING `authentik.reconcile_skipped reason=user_lookup`
    (count 2) 한 줄 · done 줄은 있다 / 둘 가운데 하나만 404 → 그 줄 없음(A는 기록된다) / 사용자 조회 403(`view_user` 없음) →
    WARNING `authentik.reconcile_forbidden status=403` · 뒤 사용자 조회 0(사용자 조회 1회 · 행 0)."""
    missing_a, missing_b = IA13_MISSING_PKS

    def run_case(events: list[dict[str, Any]]) -> tuple[Any, ...]:
        before = len(_log_rows())
        ia73_authentik.reset(users=(IA13_A, IA13_B), events=events)
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        return (
            result.state,
            len(_user_lookups(ia73_authentik)),
            len(_log_rows()) - before,
            _reconcile_lines(records, RECONCILE_SKIPPED),
            _authentik_events(records),
        )

    _ia13_seed(ia73_authentik, [], members=(IA13_A, IA13_B))
    cached = run_case([make_event(IA13_A["pk"], _at_offset(-60)), make_event(IA13_A["pk"], _at_offset(-120))])
    all_missing = run_case([make_event(missing_a, _at_offset(-60)), make_event(missing_b, _at_offset(-120))])
    one_missing = run_case([make_event(missing_a, _at_offset(-60)), make_event(IA13_A["pk"], _at_offset(-120))])
    rows_before = len(_log_rows())
    forbidden_events = [make_event(IA13_A["pk"], _at_offset(-60)), make_event(IA13_B["pk"], _at_offset(-120))]
    ia73_authentik.reset(users=(IA13_A, IA13_B), events=forbidden_events)
    ia73_authentik.forbid("user_detail")
    log_lines()
    forbidden = _reconcile_run()
    forbidden_records = log_lines()
    forbidden_view = (
        forbidden.state,
        len(_user_lookups(ia73_authentik)),
        len(_log_rows()) - rows_before,
        [line[:1] + line[5:6] for line in _reconcile_lines(forbidden_records, RECONCILE_FORBIDDEN)],
        _authentik_events(forbidden_records),
    )

    assert cached == ("SUCCESS", 1, 2, [], [RECONCILE_DONE])
    assert all_missing == (
        "SUCCESS",
        2,
        0,
        [("warning", None, None, None, None, None, None, "user_lookup", 2)],
        [RECONCILE_SKIPPED, RECONCILE_DONE],
    )
    assert one_missing == ("SUCCESS", 2, 1, [], [RECONCILE_DONE])
    assert forbidden_view == ("SUCCESS", 1, 0, [("warning", 403)], [RECONCILE_FORBIDDEN])


@DB
def test_ia_13_hex_pk_matches_dashed_webhook_row(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(D12 「event_pk 정규형」 · 〔Y17〕) — 웹훅이 대시 꼴로 기록한 행(event_pk = UUID 대시 소문자)이 있을 때 같은 UUID의 hex
    32자(대문자) pk logout → 한 행(무변화 · 사용자 조회 0 · 반환 {seen 1, recorded 0, skipped 1}) / 짝: 다른 UUID의 hex 32자 pk →
    기록되고 event_pk는 대시 소문자 정규형이다(사용자 조회 1)."""
    shared = uuid.uuid4()
    insert_log_row(IA13_A["uuid"], nbf=_at(time.time() - 7200), reason=WEBHOOK_REASON, event_pk=str(shared))
    _ia13_seed(ia73_authentik, [make_event(IA13_A["pk"], _at_offset(-7200), pk=shared.hex.upper())], members=(IA13_A,))
    replay = _reconcile_run()
    replay_view = (replay.state, replay.result, len(_user_lookups(ia73_authentik)), set(_log_rows()))
    fresh = uuid.uuid4()
    ia73_authentik.reset(users=(IA13_A,), events=[make_event(IA13_A["pk"], _at_offset(-3600), pk=fresh.hex.upper())])
    pair = _reconcile_run()
    pair_view = (pair.state, pair.result, len(_user_lookups(ia73_authentik)), set(_log_rows()))

    assert replay_view == ("SUCCESS", _counts(1, 0, 1), 0, {str(shared)})
    assert pair_view == ("SUCCESS", _counts(1, 1, 0), 1, {str(shared), str(fresh)})


MALFORMED_LINE_KEYS = ["count", "event", "level", "logger", "reason", "ts"]  # reconcile_skipped 줄의 키(값을 싣지 않는다)


def _malformed_lines(records: list[dict[str, Any]]) -> list[tuple[Any, Any, list[str]]]:
    """`authentik.reconcile_skipped reason=malformed` 줄의 (level, count, 키 목록)."""
    return [
        (line.get("level"), line.get("count"), sorted(line))
        for line in log_events(records, RECONCILE_SKIPPED)
        if line.get("reason") == "malformed"
    ]


@DB
def test_ia_13_malformed_events_are_counted_and_warned(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(수정 라운드 J2 · 5bB-1 — 「조용한 0건」을 드러낸다: 판이 올라 응답 꼴이 바뀌어 대조가 아무것도 읽지 못하는 실행이
    「웹훅이 다 받아 전부 이미 기록됐다」와 같은 INFO 한 줄로 끝나지 않게) — 창 안 logout의 `user.pk`가 문자열 숫자인 꼴로 본다.
    1. 짝: 정상 꼴 A 하나 + 문자열 pk 둘 → A만 기록(행 1) · 반환 {seen 3, recorded 1, skipped 2} · 끝에 WARNING
       `authentik.reconcile_skipped`(reason malformed · count 2 — 키는 reason · count뿐: pk · sub · created 원문을 싣지 않는다) 한 줄
       → `reconcile_done`.
    2. 창 안 logout 셋 전부가 문자열 pk → 행 0 · 반환 {seen 3, recorded 0, skipped 3} · 같은 WARNING(count 3) → done(남는다).
    3. 실패 갈래(완주한 실행에서만 센다): 짝 — 문자열 pk logout 하나 + 창 밖 149(첫 쪽 100 · 둘째 쪽 50) → WARNING(count 1) · done /
       같은 이벤트에 둘째 쪽 503 → `authentik.reconcile_failed` 한 줄뿐(`reconcile_skipped` 0줄 · done 0줄) · 반환 {seen 100,
       recorded 0, skipped 100}."""
    a_pk = IA13_A["pk"]

    def run_case(events: list[dict[str, Any]], *replies: int | None) -> tuple[Any, ...]:
        before = len(_log_rows())
        ia73_authentik.reset(users=(IA13_A, IA13_B), events=events)
        if replies:
            ia73_authentik.inject("events", *replies)
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        return (
            result.state,
            result.result,
            len(_log_rows()) - before,
            _malformed_lines(records),
            _authentik_events(records),
        )

    def string_pk(offset_s: float) -> dict[str, Any]:
        return make_event(str(a_pk), _at_offset(offset_s))

    _ia13_seed(ia73_authentik, [], members=(IA13_A,))
    mixed = run_case([make_event(a_pk, _at_offset(-60)), string_pk(-120), string_pk(-180)])
    all_bad = run_case([string_pk(-60), string_pk(-120), string_pk(-180)])
    stale = [make_event(a_pk, _at_offset(-(WINDOW_S + 7200 + index))) for index in range(149)]
    paged = run_case([string_pk(-60), *stale])
    paged_503 = run_case([string_pk(-60), *stale], None, 503)
    warned = [RECONCILE_SKIPPED, RECONCILE_DONE]

    assert mixed == ("SUCCESS", _counts(3, 1, 2), 1, [("warning", 2, MALFORMED_LINE_KEYS)], warned)
    assert all_bad == ("SUCCESS", _counts(3, 0, 3), 0, [("warning", 3, MALFORMED_LINE_KEYS)], warned)
    assert paged == ("SUCCESS", _counts(150, 0, 150), 0, [("warning", 1, MALFORMED_LINE_KEYS)], warned)
    assert paged_503 == ("SUCCESS", _counts(100, 0, 100), 0, [], [RECONCILE_FAILED])


@DB
def test_ia_13_malformed_user_responses_are_counted(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(수정 라운드 J2 · 5bB-1 · 5bB-6 — 사용자 응답의 꼴): 사용자 조회(`GET …/users/<pk>/`)가 200인데
    1. 짝: 정상 응답 → A의 logout 기록(행 1) · `reconcile_skipped` 0줄 · done.
    2. 응답에 `uuid`가 없다(A의 logout 둘) → 행 0 · 사용자 조회 1회(꼴 어긋남 판정도 실행 안 캐시에 든다 — 둘째 이벤트가 다시
       조회해 정상 응답으로 기록되지 않는다) · WARNING `authentik.reconcile_skipped`(reason malformed · count 2) 한 줄 → done.
    3. 응답의 `pk`가 요청과 다르다(A의 pk 요청에 B의 사용자 객체 — B도 멤버다) → 행 0(다른 사용자의 uuid로 폐기가 기록되지 않는다)
       · 같은 WARNING(count 1) → done.
    4. 조각 ⑥ X1(5bV-1): 응답의 `uuid`가 UUID 꼴이 아니다(`"not-a-uuid"` · pk는 맞다) → 행 0 · 같은 WARNING(count 1) — uuid 꼴
       검사가 빠지면 멤버십 없음으로 가 경고 없이 건너뛴다.
    5. 조각 ⑥ X1(5bV-1): 응답의 `pk`가 요청한 정수와 같은 값의 실수(`301.0` — `301.0 == 301`)다 → 행 0 · 같은 WARNING(count 1) —
       `valid_pk` 검사가 빠지고 `answered != user_pk`만 남으면 A의 uuid로 기록된다."""
    a_pk = IA13_A["pk"]

    def run_case(events: list[dict[str, Any]], reply: tuple[int, Any] | None = None) -> tuple[Any, ...]:
        before = len(_log_rows())
        ia73_authentik.reset(users=(IA13_A, IA13_B), events=events)
        if reply is not None:
            ia73_authentik.inject("user_detail", reply)
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        return (
            result.state,
            result.result,
            len(_user_lookups(ia73_authentik)),
            len(_log_rows()) - before,
            _malformed_lines(records),
            _authentik_events(records),
        )

    _ia13_seed(ia73_authentik, [], members=(IA13_A, IA13_B))
    pair = run_case([make_event(a_pk, _at_offset(-60))])
    no_uuid = run_case(
        [make_event(a_pk, _at_offset(-60)), make_event(a_pk, _at_offset(-120))],
        (200, {"pk": a_pk, "username": IA13_A["username"]}),
    )
    other_user = run_case([make_event(a_pk, _at_offset(-60))], (200, dict(IA13_B)))
    bad_uuid = run_case([make_event(a_pk, _at_offset(-60))], (200, {**IA13_A, "uuid": "not-a-uuid"}))
    float_pk = run_case([make_event(a_pk, _at_offset(-60))], (200, {**IA13_A, "pk": float(a_pk)}))
    warned = [RECONCILE_SKIPPED, RECONCILE_DONE]
    one_malformed = ("SUCCESS", _counts(1, 0, 1), 1, 0, [("warning", 1, MALFORMED_LINE_KEYS)], warned)

    assert pair == ("SUCCESS", _counts(1, 1, 0), 1, 1, [], [RECONCILE_DONE])
    assert no_uuid == ("SUCCESS", _counts(2, 0, 2), 1, 0, [("warning", 2, MALFORMED_LINE_KEYS)], warned)
    assert other_user == one_malformed
    assert bad_uuid == one_malformed
    assert float_pk == one_malformed


def _reconcile_trail(records: list[dict[str, Any]]) -> list[tuple[str, Any]]:
    """대조가 남긴 authentik 로그 줄의 (event, reason) 차례 — 두 `reconcile_skipped`를 reason으로 가른다."""
    return [
        (str(line.get("event")), line.get("reason"))
        for line in records
        if str(line.get("event", "")).startswith("authentik.reconcile_")
    ]


@DB
def test_ia_13_malformed_warning_order_and_completion(ia73_authentik: Any, log_lines: LogLines) -> None:
    """ia-13(조각 ⑥ X1 · 5bV-1 — 끝의 두 경고의 차례와 완주 조건 · 모듈 독스트링 「끝의 줄은 차례대로」):
    1. 없는 pk의 logout(사용자 조회 404 — 조회한 pk 전부가 404) + 문자열 `user.pk` logout 한 실행 → 끝의 줄 차례가
       `reconcile_skipped`(user_lookup · count 1) → `reconcile_skipped`(malformed · count 1) → `reconcile_done` · 행 0 · 반환
       {seen 2, recorded 0, skipped 2}.
    2. 문자열 `user.pk` logout(첫 쪽) + 창 밖 149 · 둘째 쪽 403 → `reconcile_forbidden` 한 줄뿐(`reconcile_skipped` 0줄 · done 0줄 —
       권한 없음으로 끝난 실행은 완주가 아니다) · 반환 {seen 100, recorded 0, skipped 100}. 짝(같은 이벤트 · 둘째 쪽 정상 → 경고 +
       done)은 `test_ia_13_malformed_events_are_counted_and_warned`의 3번이다."""
    a_pk = IA13_A["pk"]
    missing_pk = IA13_MISSING_PKS[0]

    def run_case(events: list[dict[str, Any]], *replies: int | None) -> tuple[Any, ...]:
        before = len(_log_rows())
        ia73_authentik.reset(users=(IA13_A, IA13_B), events=events)
        if replies:
            ia73_authentik.inject("events", *replies)
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        counts = [(line.get("reason"), line.get("count")) for line in log_events(records, RECONCILE_SKIPPED)]
        return result.state, result.result, len(_log_rows()) - before, counts, _reconcile_trail(records)

    _ia13_seed(ia73_authentik, [], members=(IA13_A,))
    both = run_case([make_event(missing_pk, _at_offset(-60)), make_event(str(a_pk), _at_offset(-120))])
    stale = [make_event(a_pk, _at_offset(-(WINDOW_S + 7200 + index))) for index in range(149)]
    forbidden = run_case([make_event(str(a_pk), _at_offset(-60)), *stale], None, 403)
    both_trail = [
        (RECONCILE_SKIPPED, "user_lookup"),
        (RECONCILE_SKIPPED, "malformed"),
        (RECONCILE_DONE, None),
    ]

    assert both == ("SUCCESS", _counts(2, 0, 2), 0, [("user_lookup", 1), ("malformed", 1)], both_trail)
    assert forbidden == ("SUCCESS", _counts(100, 0, 100), 0, [], [(RECONCILE_FORBIDDEN, None)])


@DB
def test_ia_13_replayed_record_is_skipped_not_malformed(
    ia73_authentik: Any, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-13(조각 ⑥ X1 · 5bV-1 — Replayed는 세지 않는다): 짝 — A의 새 logout → 기록(행 1) · 반환 {seen 1, recorded 1, skipped 0} ·
    `reconcile_done`뿐 / 이음매 `revocation.record_revocation`을 `revocation.Replayed()`를 돌려주는 감싸기로 덮고(사전 확인과 기록
    사이의 경합 꼴) A의 새 logout → 행 0 · 반환 {seen 1, recorded 0, skipped 1} · `reconcile_skipped` 0줄(꼴 어긋남이 아니다) ·
    `reconcile_done`뿐."""
    revocation = impl("revocation")
    calls: list[int] = []

    def replayed(**kwargs: Any) -> Any:
        calls.append(1)
        return revocation.Replayed()

    def run_case() -> tuple[Any, ...]:
        before = len(_log_rows())
        ia73_authentik.reset(users=(IA13_A,), events=[make_event(IA13_A["pk"], _at_offset(-60))])
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        return result.state, result.result, len(_log_rows()) - before, _reconcile_trail(records)

    _ia13_seed(ia73_authentik, [], members=(IA13_A,))
    pair = run_case()
    monkeypatch.setattr(revocation, "record_revocation", replayed)
    covered = run_case()

    assert pair == ("SUCCESS", _counts(1, 1, 0), 1, [(RECONCILE_DONE, None)])
    assert covered == ("SUCCESS", _counts(1, 0, 1), 0, [(RECONCILE_DONE, None)])
    assert len(calls) == 1


@DB
def test_ia_13_one_deadline_reaches_every_call(ia73_authentik: Any, monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-13(수정 라운드 J5 · 5bB-4 — 한 실행 전체 마감이 호출마다 전달된다 · 구현은 맞다: 고정 사례): `outbound.request_json`을
    감싸 `deadline` 인자를 기록한다. 정렬을 뒤섞은 가짜에 A의 logout(첫 쪽 맨 앞) · 창 밖 100 · B의 logout(둘째 쪽 끝) → 이벤트 목록
    2쪽 + 사용자 조회 2(A · B) = 호출 4의 deadline이 모두 None이 아니고 한 객체(outbound.Deadline — `get_user`에서 deadline이 빠지면
    여기서 빨강이다) · 행 2 · 반환 {seen 102, recorded 2, skipped 100}."""
    stale = [make_event(IA13_A["pk"], _at_offset(-(WINDOW_S + 7200 + index))) for index in range(100)]
    first = make_event(IA13_A["pk"], _at_offset(-60))
    last = make_event(IA13_B["pk"], _at_offset(-120))
    _ia13_seed(ia73_authentik, [first, *stale, last], members=(IA13_A, IA13_B))
    ia73_authentik.ignore_ordering = True
    deadlines = _record_deadlines(monkeypatch)
    run = _reconcile_run()
    view = (
        run.state,
        run.result,
        len(ia73_authentik.requests_to("events")),
        len(_user_lookups(ia73_authentik)),
        set(_log_rows()),
    )
    passed = _deadline_view(deadlines)

    assert view == ("SUCCESS", _counts(102, 2, 100), 2, 2, {first["pk"], last["pk"]})
    assert passed == (4, True, 1, {"Deadline"})


@DB
def test_ia_13_deadline_is_checked_before_each_event(
    ia73_authentik: Any, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-13(수정 라운드 J6 · 5bB-5 — 대조의 마감을 이벤트 하나 앞에서도 본다 · 시간에 기대지 않는다): 이음매 `outbound.Deadline`
    (작업이 호출 때 모듈 속성으로 읽는다)을 진짜 Deadline을 감싸는 가짜(같은 표면 — 만들 때 초 · `remaining()`: outbound.request_json이
    쓰는 것)로 덮는다 — 깃발이 서면 `remaining()`이 음수다. 창 안 누락 logout 둘(A · 같은 쪽 · 사용자 조회는 캐시로 1회).
    1. 짝: 깃발을 세우지 않는다 → 둘 다 기록(행 2) · 반환 {seen 2, recorded 2, skipped 0} · done.
    2. 새 logout 둘 + 이음매 `revocation.record_revocation`을 감싸 첫 기록 뒤 깃발을 세운다 → 행 1 · 반환 {seen 1, recorded 1,
       skipped 0}(마감에서 멈춘 이벤트는 세지 않는다) · WARNING `authentik.reconcile_failed`(error deadline) 한 줄 · `reconcile_done`
       0줄 · 깃발 뒤의 HTTP 요청 0 · SUCCESS(HTTP 호출의 마감 초과와 같은 갈래 — 정상 종료 · 남은 이벤트는 다음 날)."""
    outbound = impl("outbound")
    revocation = impl("revocation")
    real_deadline = outbound.Deadline
    real_record = revocation.record_revocation
    state: dict[str, Any] = {"lapsed": False, "requests": None}

    class FlagDeadline:
        """outbound.Deadline과 같은 표면 — 깃발이 서면 remaining()이 음수(마감 지남) · 아니면 진짜 Deadline의 값."""

        __slots__ = ("_real",)

        def __init__(self, seconds: float) -> None:
            self._real = real_deadline(seconds)

        def remaining(self) -> float:
            return -1.0 if state["lapsed"] else self._real.remaining()

    def record_then_lapse(**kwargs: Any) -> Any:
        recorded = real_record(**kwargs)
        state["lapsed"] = True
        state["requests"] = len(ia73_authentik.requests)
        return recorded

    def run_case() -> tuple[Any, ...]:
        before = len(_log_rows())
        events = [make_event(IA13_A["pk"], _at_offset(-60)), make_event(IA13_A["pk"], _at_offset(-120))]
        ia73_authentik.reset(users=(IA13_A,), events=events)
        log_lines()
        result = _reconcile_run()
        records = log_lines()
        lines = [
            (line.get("event"), line.get("level"), line.get("status"), line.get("error"))
            for line in records
            if str(line.get("event", "")).startswith("authentik.reconcile_")
        ]
        return result.state, result.result, len(_log_rows()) - before, lines

    monkeypatch.setattr(outbound, "Deadline", FlagDeadline)
    _ia13_seed(ia73_authentik, [], members=(IA13_A,))
    pair = run_case()
    monkeypatch.setattr(revocation, "record_revocation", record_then_lapse)
    lapsed = run_case()
    after_flag = None if state["requests"] is None else len(ia73_authentik.requests) - state["requests"]

    assert pair == ("SUCCESS", _counts(2, 2, 0), 2, [(RECONCILE_DONE, "info", None, None)])
    assert lapsed == ("SUCCESS", _counts(1, 1, 0), 1, [(RECONCILE_FAILED, "warning", None, "deadline")])
    assert after_flag == 0


class PlantedReconcileError(Exception):
    """시험이 심는 대조의 예상 밖 예외(DB 오류 꼴 — 문구에 접속 정보 · 행 값(원문 sub · event pk)을 심는다)."""


@DB
def test_ia_13_unexpected_error_fails_without_message(
    ia73_authentik: Any, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-13(조각 ⑤-b P5 — 작업의 실패 틀) — 짝: 덮기 전의 같은 준비물(A · B의 logout) → SUCCESS · 행 2 / 새 logout 둘(A · B)에
    이음매 `revocation.record_revocation`이 첫 호출은 그대로 기록하고 둘째 호출에서 INSERT 실패 꼴 문구(호스트 · role · 원문 sub ·
    event pk — `Failing row contains (…)`)를 심은 예외를 던지면 → 상태 FAILURE · 결과 예외 `jobs.ReconcileFailed`(문구 "" · 연쇄
    없음) · WARNING `authentik.reconcile_failed` 한 줄(error = 심은 예외의 클래스 이름) · 그 전에 기록한 행은 남는다(행 3) · 로그
    줄 전부와 결과 트레이스백에 심은 값 0.
    조각 ⑥ X1(5bV-1 — 완주 조건): 망가진 실행의 맨 앞에 문자열 `user.pk` logout(꼴 어긋남 — 센다)을 둔다 → 예상 밖 예외로 끝난
    실행은 완주가 아니므로 `authentik.reconcile_skipped` 0줄(done도 0줄)."""
    revocation = impl("revocation")
    _ia13_seed(
        ia73_authentik,
        [make_event(IA13_A["pk"], _at_offset(-60)), make_event(IA13_B["pk"], _at_offset(-120))],
        members=(IA13_A, IA13_B),
    )
    pair = _reconcile_run()
    pair_view = (pair.state, len(_log_rows()))
    broken_events = [
        make_event(str(IA13_A["pk"]), _at_offset(-15)),  # 꼴 어긋남(기록 호출 앞에서 건너뛴다 — calls에 들지 않는다)
        make_event(IA13_A["pk"], _at_offset(-30)),
        make_event(IA13_B["pk"], _at_offset(-90)),
    ]
    planted = {
        "host": f"pg-planted-{secrets.token_hex(4)}.internal",
        "role": f"ia_planted_role_{secrets.token_hex(3)}",
        "sub": IA13_B["uuid"],
        "event_pk": broken_events[2]["pk"],
    }
    real_record = revocation.record_revocation
    calls: list[int] = []

    def flaky_record(**kwargs: Any) -> Any:
        calls.append(1)
        if len(calls) == 1:
            return real_record(**kwargs)
        raise PlantedReconcileError(
            f'connection to server at "{planted["host"]}" as "{planted["role"]}": INSERT failed DETAIL: Failing row '
            f'contains ({planted["sub"]}, {planted["event_pk"]})'
        )

    ia73_authentik.reset(users=(IA13_A, IA13_B), events=broken_events)
    monkeypatch.setattr(revocation, "record_revocation", flaky_record)
    log_lines()
    down = _reconcile_run()
    records = log_lines()
    outcome = down.result
    message_empty = str(outcome) == ""
    chain = _chain(outcome)
    failed_lines = [
        (line.get("level"), line.get("error") == "PlantedReconcileError")
        for line in log_events(records, RECONCILE_FAILED)
    ]
    trail = _reconcile_trail(records)
    text = json.dumps(records) + str(down.traceback or "")
    leaked = {name: Secret(value) in Secret(text) for name, value in planted.items()}
    clean = dict.fromkeys(planted, False)

    assert pair_view == ("SUCCESS", 2)
    assert (down.state, type(outcome).__name__, message_empty, len(calls)) == ("FAILURE", "ReconcileFailed", True, 2)
    assert chain == ("NoneType", "NoneType")
    assert failed_lines == [("warning", True)]
    assert trail == [(RECONCILE_FAILED, None)]  # 완주가 아니다 — reconcile_skipped(malformed) · done 0줄
    assert len(_log_rows()) == 3
    assert leaked == clean


# --- ia-40: 실제 worker + beat(D26 · VD-T073-5 · VD-T073-15 (a)) -------------------------------------------------------

IA40_BOOT_DEADLINE_S = 120  # worker · beat 기동 + beat_init 재적용이 세 키를 만들기까지(Windows 실측 약 5 s)
# 아래 둘은 tick 둘 + 15 s(수정 라운드 H5): 기준 시각 뒤 첫 tick은 + 29.97 s · 둘째는 + 59.97 s라 60 s 상한은 tick 한 번이 밀리거나
# 실패하면 동전 던지기였다. 「30 s tick이 실제로 돈다」는 뜻은 그대로다(주기 300 s 변이는 여전히 빨강 — 첫 tick이 + 300 s).
IA40_TICK_DEADLINE_S = 75  # beat_init 뒤 30 s tick이 실제로 도는지(beat → 브로커 → 워커) — 설계 D26
IA40_RECOVERY_DEADLINE_S = 75  # admin FLUSHALL 뒤 세 키 복귀(VD-T073-15 (a))
RECONCILE_SUCCESS = f"Task {TASK_RECONCILE}["
TASK_FAILURE_MARK = " raised unexpected: "  # Celery 실패 줄(`Task <이름>[<id>] raised unexpected: <예외 repr>`)


def _json_records(text: str) -> list[dict[str, Any]]:
    """로그의 JSON 객체 줄(Celery 배너 같은 원문 줄은 건너뛴다)."""
    records: list[dict[str, Any]] = []
    for line in text.splitlines():
        if not line.startswith("{"):
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        if isinstance(record, dict):
            records.append(record)
    return records


def _read_logs(processes: list[CeleryProcess]) -> dict[str, str]:
    return {process.name: process.log.read_text(encoding="utf-8", errors="replace") for process in processes}


def _reconcile_successes(processes: list[CeleryProcess]) -> int:
    """워커 로그의 reconcile_denylist 성공 줄 수(Celery 성공 줄 = 재적용 생존 신호)."""
    events = [str(record.get("event", "")) for text in _read_logs(processes).values() for record in _json_records(text)]
    return sum(1 for event in events if event.startswith(RECONCILE_SUCCESS) and " succeeded in " in event)


@DB
def test_ia_40_real_worker_and_beat_reapply(
    pg: PgInfo, dragonfly: DragonflyInfo, ia73_df_admin: redis.Redis, tmp_path: Path
) -> None:
    """ia-40(D26 · D14 · D24) — 활성 사용자 단위 로그 행 하나를 넣고 Dragonfly를 비운 뒤 실제 worker + beat(D14 명령 — Windows는 두
    프로세스 · POSIX는 내장 beat 하나: 템플릿 `_celery_commands`)를 pod 사용자(`dragonfly.pod_url` — 운영 identity-admin 규칙)와 시험
    DB app role로 띄운다.
    ① 기동: beat_init 재적용이 `revoked:sub:<sub>` = nbf · 세션 하한 = nbf · 신선도 키를 만든다(브로커 경유 아님) · 로그에
       `denylist.reapplied`(phase beat_init · floors ≥ 1 · failed 0 — pod 사용자는 명령 단위 실패 없이 키를 만든다: D24) 줄.
    ② tick(뺄 수 없는 단언 — FLUSHALL 앞): beat_init 뒤 75 s(tick 둘 + 15 s) 안에 신선도 키 값이 그때 읽은 값보다 커지거나 워커
       로그에 reconcile_denylist 성공 줄이 1회 이상 있다(30 s tick이 beat → 브로커 → 워커로 실제로 돈다).
    ③ 유실 뒤 복구(VD-T073-15 (a)): admin FLUSHALL(Celery 브로커 키도 지워진다) → 75 s 안에 세 키가 돌아온다.
    ④ 모든 로그에 NOPERM 0 · DB · Dragonfly 비밀번호 0 · 원문 sub 0 · 멈추기 전까지 프로세스가 살아 있었다 · 멈춤 신호 뒤 상한
       안에 스스로 끝났다(POSIX는 종료 코드 0 · 프로세스 그룹에 남은 프로세스 0 — 템플릿 실제 워커 시험과 같은 멈춤 단언).
    ⑤ 작업 실패 0(조각 ⑤-b — 위임 · 대조의 자리 표시 본체가 없어졌다): Celery 실패 줄(`… raised unexpected: …`) 0 ·
       `denylist.reapply_failed` 0(① 의 failed 0은 재적용 반환 칸이다 — 다른 값이다). 실행이 03:17 · 03:27 · 03:37 UTC를 걸치면 일 1회
       작업 셋이 발화한다 — 대조는 시험 env의 Authentik 자격(래퍼 난수 — 자리값 아님) · 닫힌 포트 URL로 `authentik.reconcile_failed
       error=connection` 뒤 정상 종료라 실패 줄이 없다(자리값이었다면 호출 0 · calls_disabled — 두 갈래 모두 실패 줄 0)."""
    sub = "ia40-real-sub"
    nbf = _epoch_floor(db_now())
    insert_log_row(sub, nbf=_at(nbf))
    ia73_df_admin.flushall()
    passwords = (str(pg.app_password), url_password(dragonfly.pod_url) or "")
    env = _child_env({"DATABASE_URL": str(pg.url("app")), "DRAGONFLY_URL": str(dragonfly.pod_url), "ENV": "test"})
    keys = (sub_key(sub), floor_key(sub), FRESHNESS_KEY)
    processes: list[CeleryProcess] = []
    stopped: list[Stopped] = []
    observed: dict[str, Any] = {"booted": False, "ticked": False, "recovered": None, "boot_s": None, "tick_s": None}

    def present() -> bool:
        return all(ia73_df_admin.exists(key) for key in keys)

    started = time.monotonic()
    try:
        for name, argv in _celery_commands(tmp_path / "celerybeat-schedule"):
            processes.append(_start(name, argv, env, tmp_path / f"{name}.log"))

        def all_alive() -> bool:
            return all(process.popen.poll() is None for process in processes)

        observed["booted"] = _wait_for(present, IA40_BOOT_DEADLINE_S, alive=all_alive)
        observed["boot_s"] = round(time.monotonic() - started, 1)
        boot_values = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))
        boot_fresh = read_int(ia73_df_admin, FRESHNESS_KEY)
        if observed["booted"] and boot_fresh is not None:
            boot_mark = time.monotonic()
            observed["ticked"] = _wait_for(
                lambda: (read_int(ia73_df_admin, FRESHNESS_KEY) or 0) > boot_fresh
                or _reconcile_successes(processes) >= 1,
                IA40_TICK_DEADLINE_S,
                alive=all_alive,
            )
            observed["tick_s"] = round(time.monotonic() - boot_mark, 1)
        if observed["ticked"]:
            ia73_df_admin.flushall()
            observed["recovered"] = _wait_for(present, IA40_RECOVERY_DEADLINE_S, alive=all_alive)
        alive_before_stop = [process.name for process in processes if process.popen.poll() is None]
    finally:
        stopped = [_stop(process) for process in processes]
    logs = _read_logs(processes)
    # 비밀번호 · 원문 sub 부재를 먼저 본다 — 뒤 단언의 실패 메시지(로그 꼬리)가 그 값을 싣기 전에(템플릿 시험과 같은 차례)
    for name, text in logs.items():
        assert_absent(f"{name} 로그", text, *passwords, sub)
    tails = _tails(logs, env, passwords)
    records = [record for text in logs.values() for record in _json_records(text)]
    reapplied = [
        (record.get("phase"), record.get("floors"), record.get("failed"))
        for record in records
        if record.get("event") == "denylist.reapplied"
    ]
    noperm = any(marker in text for text in logs.values() for marker in NOPERM_MARKERS)
    task_failures = sum(1 for record in records if TASK_FAILURE_MARK in str(record.get("event", "")))
    reapply_failures = sum(1 for record in records if record.get("event") == REAPPLY_FAILED)

    assert observed["booted"], f"beat_init 재적용이 {IA40_BOOT_DEADLINE_S} s 안에 세 키를 만들지 않았다\n{tails}"
    assert boot_values == (nbf, nbf)
    assert any(
        phase == "beat_init" and isinstance(floors, int) and floors >= 1 and failed == 0
        for phase, floors, failed in reapplied
    ), f"denylist.reapplied phase=beat_init floors>=1 failed=0 줄 없음 {reapplied}\n{tails}"
    assert observed["ticked"], f"beat_init 뒤 {IA40_TICK_DEADLINE_S} s 안에 tick 재적용이 돌지 않았다 {observed}\n{tails}"
    assert observed["recovered"], f"FLUSHALL 뒤 {IA40_RECOVERY_DEADLINE_S} s 안에 세 키가 돌아오지 않았다 {observed}\n{tails}"
    assert not noperm, f"Celery 로그에 NOPERM\n{tails}"
    failures = (task_failures, reapply_failures)
    assert failures == (0, 0), f"작업 실패 줄 · 재적용 실패 줄 {failures}\n{tails}"
    assert alive_before_stop == [process.name for process in processes]
    # 멈춤 단언(수정 라운드 H5) — 템플릿 실제 워커 시험(tests/test_outbox.py)이 같은 자리에서 보는 것과 같은 수준
    assert [(item.name, item.graceful) for item in stopped] == [(process.name, True) for process in processes]
    if not WINDOWS:
        assert [(item.name, item.returncode, item.leftover) for item in stopped] == [
            (process.name, 0, False) for process in processes
        ]


# --- 조각 ⑤-b P1(조각 ③-b1 리뷰 3b1B-9): 위임 메시지의 실제 발행 → 실제 브로커 → 실제 워커 → 가짜 Authentik DELETE -----------

P1_DELIVERY_DEADLINE_S = 120  # 명령이 끝난 뒤 워커가 대상 세션을 지우기까지(워커 기동 포함 — Windows 실측은 보고에 적는다)
P1_LOG_DEADLINE_S = 15  # DELETE 뒤 워커 로그에 revoke_done 줄이 쓰이기까지
P1_COMMAND_TIMEOUT_S = 120  # 관리 명령 하위 프로세스의 상한(유한한 실패)
P1_TARGET_PK, P1_OTHER_PK = 501, 502
COMMAND_PREFIX = "revoke_sessions: "


def _run_revoke_command(env: dict[str, str], sub: str) -> tuple[int | None, str]:
    """`manage.py revoke_sessions --sub <sub>`를 워커와 같은 env의 하위 프로세스로 1회(종료 코드 · stdout + stderr) — 상한을 넘기면
    (None, ""). 출력은 단언 앞에서 비밀 · 원문 sub 부재를 먼저 본다(호출자)."""
    argv = [sys.executable, "manage.py", "revoke_sessions", "--sub", sub]
    completed: subprocess.CompletedProcess[bytes] | None = None
    try:
        completed = subprocess.run(  # noqa: S603 — 인자 고정 · shell 없음 · 이 프로세스의 인터프리터
            argv, cwd=POD_ROOT, env=env, capture_output=True, timeout=P1_COMMAND_TIMEOUT_S, check=False
        )
    except subprocess.TimeoutExpired:
        completed = None  # 실패는 호출자가 낸다(명령 줄 · 부분 출력이 연쇄 예외로 실리지 않게)
    if completed is None:
        return None, ""
    return completed.returncode, (completed.stdout + completed.stderr).decode("utf-8", errors="replace")


@DB
def test_ia_11_real_publish_reaches_worker(
    pg: PgInfo, dragonfly: DragonflyInfo, ia73_authentik: Any, tmp_path: Path
) -> None:
    """ia-11 옆(조각 ⑤-b P1 — 3b1B-9: 위임 enqueue의 시험이 가로채기(send_task 덮기)와 실패가 정상인 닫힌 포트 브로커뿐이라 발행 쪽
    결함 — pod 사용자 ACL의 NOPERM · 키 접두 · Celery/kombu 판 올림에 따른 옵션 동작 변화 — 이 `revocation._delegate`의 except에
    `authentik.revoke_enqueue_failed` 한 줄로 접혀 조용하다) — 실제 사슬 하나:
    준비: 시험 Dragonfly를 pod 사용자 URL(`dragonfly.pod_url` — 운영 identity-admin 규칙)로 브로커 삼은 실제 워커(ia-40 · 템플릿
    `_celery_commands`의 worker — Windows는 beat 없이 · POSIX는 D14 명령 그대로) · 가짜 Authentik에 대상 사용자와 그 세션 하나 +
    남의 세션 하나 · 쓰기 플래그 켬 · 자격 = 가짜 토큰(자리값 아님) · 대상 sub의 멤버십(테넌트 A). 자식 env는 템플릿 `_child_env`다.
    발행: 워커와 같은 env의 하위 프로세스에서 `manage.py revoke_sessions --sub <sub>`(시험 프로세스의 Celery 앱 · 브로커를 건드리지
    않는다 — 뒤 시험은 여전히 닫힌 포트 브로커를 본다).
    단언: 명령 종료 0 · 출력 줄 `revoke_sessions: OK … denylist=ok delegate=enqueued` 하나 / 워커가 그 메시지를 받아 가짜 Authentik에
    대상 세션의 DELETE가 닿는다(상한 안에 deleted_sessions = [대상] · 남의 세션은 남는다) · 워커 로그에 `authentik.revoke_done`
    (deleted 1 · gone 0 · skipped 0 · truncated 거짓) 한 줄과 그 작업의 수신 줄 · 워커 로그와 명령 출력 어디에도 원문 sub ·
    비밀번호 · 토큰이 없다(수신 줄의 인자 표시는 `argsrepr` — 원문 sub를 싣지 않는다) · NOPERM 0 · 작업 실패 줄 0 · 멈추기 전까지
    워커가 살아 있었고 멈춤 신호 뒤 상한 안에 스스로 끝났다(POSIX는 종료 코드 0 · 남은 프로세스 0 — 수정 라운드 J8)."""
    sub, other_sub = str(uuid.uuid4()), str(uuid.uuid4())
    target, other = make_session(P1_TARGET_PK), make_session(P1_OTHER_PK)
    ia73_authentik.reset(
        users=(
            {"pk": P1_OTHER_PK, "uuid": other_sub, "username": "ia11-real-other"},
            {"pk": P1_TARGET_PK, "uuid": sub, "username": "ia11-real-target"},
        ),
        sessions=[other, target],
    )
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    token = str(ia73_authentik.token)
    passwords = (str(pg.app_password), url_password(dragonfly.pod_url) or "", token)
    env = _child_env(
        {
            "DATABASE_URL": str(pg.url("app")),
            "DRAGONFLY_URL": str(dragonfly.pod_url),
            "ENV": "test",
            "AUTHENTIK_WRITES_ENABLED": "true",
            "AUTHENTIK_API_URL": ia73_authentik.base_url,
            "AUTHENTIK_API_TOKEN": token,
        }
    )
    worker_argv = next(argv for name, argv in _celery_commands(tmp_path / "celerybeat-schedule") if name == "worker")
    processes: list[CeleryProcess] = []
    stopped: list[Stopped] = []
    observed: dict[str, Any] = {
        "code": None,
        "delivered": False,
        "logged": False,
        "command_s": None,
        "delivery_s": None,
    }
    output = ""
    started = time.monotonic()
    try:
        processes.append(_start("worker", worker_argv, env, tmp_path / "worker.log"))

        def alive() -> bool:
            return all(process.popen.poll() is None for process in processes)

        observed["code"], output = _run_revoke_command(env, sub)
        observed["command_s"] = round(time.monotonic() - started, 1)
        observed["delivered"] = _wait_for(
            lambda: target["uuid"] in ia73_authentik.deleted_sessions, P1_DELIVERY_DEADLINE_S, alive=alive
        )
        observed["delivery_s"] = round(time.monotonic() - started, 1)
        observed["logged"] = _wait_for(
            lambda: REVOKE_DONE in _read_logs(processes)["worker"], P1_LOG_DEADLINE_S, alive=alive
        )
        alive_before_stop = [process.name for process in processes if process.popen.poll() is None]
    finally:
        stopped = [_stop(process) for process in processes]
    logs = _read_logs(processes)
    # 비밀 · 원문 sub 부재를 먼저 본다 — 뒤 단언의 실패 메시지(로그 꼬리)가 그 값을 싣기 전에(ia-40 · 템플릿 시험과 같은 차례)
    assert_absent("revoke_sessions 출력", output, *passwords, sub)
    for name, text in logs.items():
        assert_absent(f"{name} 로그", text, *passwords, sub)
    tails = _tails({**logs, "command": output}, env, passwords)
    command_lines = [line for line in output.splitlines() if line.startswith(COMMAND_PREFIX)]
    command_view = [
        (line.split()[1], "denylist=ok" in line.split(), "delegate=enqueued" in line.split()) for line in command_lines
    ]
    records = [record for text in logs.values() for record in _json_records(text)]
    done = [
        (record.get("deleted"), record.get("gone"), record.get("skipped"), record.get("truncated"))
        for record in records
        if record.get("event") == REVOKE_DONE
    ]
    received = sum(
        1
        for record in records
        if str(record.get("event", "")).startswith(f"Task {TASK_REVOKE}[") and " received" in str(record.get("event"))
    )
    task_failures = sum(1 for record in records if TASK_FAILURE_MARK in str(record.get("event", "")))
    noperm = any(marker in text for text in (*logs.values(), output) for marker in NOPERM_MARKERS)
    left = _sessions_left(ia73_authentik)

    assert (observed["code"], command_view) == (0, [("OK", True, True)]), f"명령 {observed}\n{tails}"
    assert observed["delivered"], f"{P1_DELIVERY_DEADLINE_S} s 안에 대상 세션의 DELETE가 닿지 않았다 {observed}\n{tails}"
    assert (ia73_authentik.deleted_sessions, left) == ([target["uuid"]], [other["uuid"]])
    assert observed["logged"], f"워커 로그에 {REVOKE_DONE} 줄이 없다 {observed}\n{tails}"
    assert done == [(1, 0, 0, False)]
    assert received == 1, f"수신 줄 {received}\n{tails}"
    assert (noperm, task_failures) == (False, 0), f"NOPERM {noperm} · 작업 실패 줄 {task_failures}\n{tails}"
    assert alive_before_stop == ["worker"]
    assert [(item.name, item.graceful) for item in stopped] == [("worker", True)]
    # 멈춤 단언(수정 라운드 J8 · 5bA-6) — ia-40 · 템플릿 실제 워커 시험과 같은 수준(POSIX의 워커는 내장 beat 자식을 둔다)
    if not WINDOWS:
        assert [(item.name, item.returncode, item.leftover) for item in stopped] == [("worker", 0, False)]
