"""T073 ia 계약 시험 — identity-admin 엔드포인트 · 세션 하한 · 판정(설계 D1 · D26 — 묶음은 조각마다 이 파일에 더한다).

조각 ③-a 묶음(읽기와 판정):
- ia-1(D8 1단계 · U8 a): `/session/check` 질의의 문자 · 길이 규칙(`sub` · `sid` = 출력 가능 ASCII `!`-`~` 1-255자) — 빈 값 ·
  256자 · 공백 · NUL · 끝 줄바꿈 · 비ASCII는 400 validation_error이고, DRAGONFLY_URL이 닫힌 포트여도 400이다(조회 앞에서
  판정 — 같은 닫힌 포트에서 바른 질의는 503이라는 양성 대조가 먼저다). 경계 값(255자 · `!` · `~`)은 200이다.
- ia-2(D8 2단계 · 3단계): 요청 3회의 Dragonfly 연결 증가 ≤ 2(모듈 수준 `Denylist` 하나 + 쓰기 클라이언트 캐시 — 요청마다
  새로 만들면 6이다). 재는 값이 실제 연결을 센다는 양성 대조(새 클라이언트 하나 = +1)를 먼저 둔다.
- ia-21(D11): 고아 멤버십 — 같은 멤버십으로 Tenant 행이 있을 때 200 → 그 행을 지운 뒤 404 not_found.
- ia-25(D9 — 한계 고정): `revoked:sid:x`를 둔 채 `sid` 클레임이 없는 Bearer로 `/tenants/me` → 200(pod 미들웨어는 `sid`가
  없으면 그 키를 보지 않는다) · 같은 키에서 `sid` 클레임이 x인 Bearer는 401 session_revoked(키가 살아 있다는 대조).
- ia-29(D29 판정 표): 하한만 있고 > iat → `{"active": false}`(nbf 키 없음) · = iat → active · < iat → active · 하한 > iat이고
  `revoked:sub` ≤ iat → `{"active": false, "nbf": <revoked:sub 값>}` · 하한 값이 정수가 아님 → 503 denylist_unavailable.
- ia-30(D8 · D29 불변식 6): (a) 첫 조회(거부 목록)가 실패하면 하한 조회를 하지 않는다 — `session_floor.read_floor`를 가로채
  센다(같은 가로채기로 정상 요청의 1회를 먼저 단언한다) · 503 · 경과 1 s 미만 (b) 거부 목록 조회는 되고 하한 조회만 실패 →
  503 + WARNING `session_floor.lookup_failed`(그 줄에 sub · URL · 비밀번호 없음) · 경과 1 s 미만. 하한 클라이언트는
  `denylist_writer.client`를 덮어 닫힌 포트 · 블랙홀 · 쿼리가 든 URL의 클라이언트를 진짜 `client()`로 만들게 한다(0.2 s 명시와
  쿼리 거부를 그 자리에서 지난다).
- ia-36(D29): HTTP 나이 경계(now - 30 d - 5 → inactive · now - 30 d + 60 → active) · 순수 함수 `is_active`의 초 단위 경계
  (now - iat = 2,592,000 → active · 2,592,001 → inactive) · `SESSION_ABSOLUTE_LIFETIME is REVOCATION_LOG_RETENTION`
  (30일).
- ia-37(D29): HTTP 미래 iat(now + 120 → `{"active": false}` + WARNING `session_check.iat_in_future` — 그 줄에 iat 값 · sub
  없음 · now + 30 → active · 경고 0) · 순수 함수 경계(now + 60 → active · now + 61 → inactive).

조각 ③-a 리뷰 반영(R1-R8 · 조각 ③-b1 첫 단계): `/session/check`의 200 · 503에 `Cache-Control: no-store`(ia-29 · 30) · 판정
순서 사례(ia-36 · 37 HTTP — `revoked:sub` ≤ iat를 둔 나이 초과 · 미래 iat는 nbf가 실린 inactive · 닫힌 포트면 503) · 순수
함수의 고정 now · 응답 Literal과 모델 상수(ia-21 옆 정적 노드 — Docker 없이 돈다) · 쓰기 클라이언트 생성 인자(ia-30 (b) 옆) ·
하한 값의 정규 꼴(ia-29) · `/tenants/me`의 NUL sub → 404(ia-21 옆).

조각 ③-b1 묶음(revoke · 기록 공통 · 쓰기 · 지표 — 설계 §5 「사례 단위 가름」: 웹훅 · 관리 명령을 지나는 사례는 조각 ③-b2가 같은
번호 · 같은 파일에 더한다):
- ia-4(D9 · D12 · D25): 거부되는 revoke(판정 순서 · 조합 · 본문 · 토큰 값의 문자 규칙)는 로그 · outbox · 키 · 지표 0(짝: 정상
  사례 넷) · 롤백된 기록은 콜백이 버려져 흔적 0(짝: 같은 호출의 커밋).
- ia-5(D12): 멤버십 둘 → 관리자 호출 202 · tenant = 작은 쪽 · WARNING `identity.multiple_memberships`(웹훅 경로는 ③-b2).
- ia-17(D22): outbox data가 이벤트 스키마를 만족한다(logout · logout_all · admin — authentik_webhook은 ③-b2) + 검사기 자기검사.
- ia-19(D25 · D13): revoke 경로 · SET 실패 경로의 로그 위생 · `apply_user`가 블랙홀에서 1 s 안에 `unreachable`.
- ia-27(D29): 사용자 단위(본인 all_devices · 관리자) → 하한 = nbf · TTL = ⌊expires_at + 30 d − DB now⌋ ± 5(웹훅은 ③-b2).
- ia-28(D29 · E13): sid 폐기는 사용자 단위 하한을 만들지 않는다(세션 단위 하한만 — UD-7a 보정 · 아래 절) · 사용자 단위 쓰기의
  최댓값 조회는 sid 행을 보지 않는다.
- ia-31(D29 불변식 3): 역순 커밋에도 하한 · `revoked:sub` = 큰 nbf(과거 nbf 웹훅 사례는 ③-b2).

조각 ③-b2 묶음(웹훅 · 관리 명령 — 위 묶음에 사례를 더한 것: ia-5 · 17 · 19 · 27 · 31의 웹훅 사례):
- ia-3(D10 1단계 · U8 b): 면제 경로의 Host 판정 — Host를 부르는 미들웨어를 없앤 채 ALLOWED_HOSTS 밖 Host → 서명과 무관하게 400
  invalid_host(짝: svc 호스트 → 401 · 202).
- ia-6(D10 4단계): 웹훅 업무 필드의 문자 규칙 · nbf 음수 → 400 · 쓰기 0(짝: 과거 nbf → 202).
- ia-7(D12 4단계): 사전 확인을 늘 거짓으로 덮은 재전송 → INSERT 경합 갈래가 200 · 행 1 · DETAIL 없음.
- ia-8(D10 · D16): 202 본문 키 셋 · 200 `{}` · 위임 0 · 무시하는 action은 본문을 보지 않는다 · pk 정규화 · nbf 누락 경고.
- ia-34 · 35(D29): 백필 꼴 웹훅은 하한만 쓴다(set_failed 0) · 재전송은 키를 다시 쓰지 않는다.
- ia-39(D12 · D10): (a) 웹훅의 nbf 상한 낮춤(⌊created⌋ + 1 · 10^18 포함) · (b) 관리 명령만 DB 시계 + 301 s와 견준다 · (c) HTTP
  경로는 DB 시계를 보지 않는다.
- ia-26(관리 명령)은 tests/test_identity_commands.py에 있다.

조각 ③-b1 리뷰 반영(조각 ③-b2 첫 단계 · S1-S10 가운데 이 파일 몫): S1 커밋 뒤 콜백의 단계 격리 · 값 없는 등록(ia-19 옆) ·
S3 · S4 기록 공통 관문 · 쓰기 갈래의 직접 호출(ia-4 · ia-28 옆) · S6 assert 식 밖으로 묶기 · S7 응답 id = 로그 revocation_id ·
S8 RevocationWriteError의 꼴(ia-7 옆) · S10 블랙홀 측정 구간(ia-19).

조각 ③-b2 리뷰 반영(F1-F10 가운데 이 파일 몫 — 계약 §웹훅 서명 규약 · §관측 T073 보정 2026-11-13): F1 과거로 어긋난 nbf의
WARNING `webhook.nbf_stale`(ia-39 (a) · ia-34) · F2 본문 `"nbf": null`은 없는 것(ia-8) · F3 세 경고는 본문 꼴 판정에서 남는다 —
재전송 · 멤버십 없음에서도(ia-8) · F4 없을 때의 값은 낮추지 않는다(ia-39 (a) — created = 지금 - 120) · F5 서명 검증 뒤 400의
사유 줄 `webhook.rejected`(ia-6) · F9 (다) 명령 관문 거부 사유 `nbf_future`(ia-39 (b)).

UD-7a(ㄴ) 조각 ⑤(t086-design.md D15 · §7 N-4 · N-16 — `revoked:sid` 값 = 폐기 시각 nbf · 세션 단위 하한
`identity-admin:sid-floor:{sid}` T-c · 하한 값 정규 꼴 판독):
- 바뀐 사례: ia-25(한계 고정의 sid 값을 시각으로) · ia-28 (a)(sid 폐기 → `revoked:sid` + 세션 단위 하한 · 사용자 단위 하한 ·
  `revoked:sub` 0) · ia-28 옆 ②(만료된 sid 행 → 세션 단위 하한 = nbf · 결과 ok · set_skipped 0줄) · ia-30 (a)(가로채기가 새
  서명 `read_floor(sub, sid)` → 튜플을 따른다 · 뷰가 sid를 넘긴다) · 「쓰기 0」 도우미 `_written`이 세션 단위 하한도 센다.
- ia-42(W35): 이 기기 폐기(nbf n) 뒤 같은 sid · iat = n − 5 → inactive · n · n + 3 → active.
- ia-43(E13): `revoked:sid`가 없어도 세션 단위 하한만으로 iat < n inactive · ≥ n active(대조: 하한도 지우면 active).
- ia-44: 세션 단위 하한 값이 정규 꼴 밖(`-5` · `x` · 20자리) → 503 · sid 질의 없는 요청은 그 키를 보지 않는다 · 첫 조회(거부 목록 —
  `revoked:sid` 값 `x`)가 실패하면 하한 조회 0.

`/session/check` 판정 시험(ia-1 · 2 · 29 · 30 · 36 · 37 · 44)은 DB 마크를 달지 않는다 — 뷰나 미들웨어가 DB에 닿으면 pytest-django가
막아 실패한다(계약 「DB 접근 없음」). 구현 모듈(`identity_admin.session_floor` · `denylist_writer`)은 시험 함수 안에서
가져오고(`impl`) 이음매는 돌려받은 모듈 속성을 monkeypatch로 덮는다(설계 D26 「이음매」). 단언 꼴: 응답 · 결과를 지역 변수에
묶은 뒤 단언한다 — 자격 헤더 · 토큰 · 비밀 · URL을 assert 식 안의 호출 인자로 두지 않는다(build-notes R0-2 · 규칙 §Tests).
"""

from __future__ import annotations

import functools
import io
import json
import math
import secrets
import time
import typing
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING, Any
from urllib.parse import urlencode, urlsplit

import pytest
import redis
from django.core.management import CommandError, call_command, get_commands
from django.test import Client, override_settings
from prometheus_client import REGISTRY

from tests._ia_support import (
    CHECK_PATH,
    DB,
    DENYLIST_TTL_S,
    OWNER_ALIAS,
    REVOKE_PATH,
    SIGNATURE_HEADER,
    SVC_HOST,
    TENANT_A,
    TENANT_B,
    TENANTS_ME,
    WEBHOOK_PATH,
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
    sid_floor_key,
    sid_key,
    signed_webhook,
    sub_key,
    timed,
)
from tests._identity_fakes import blackhole, closed_port
from tests._jwt import sign_webhook, webhook_body
from tests._problem import assert_problem
from tests._secret import Secret

if TYPE_CHECKING:
    from collections.abc import Callable

    from django.http import HttpResponse
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import DragonflyInfo, JwksInfo, LogLines

pytestmark = pytest.mark.usefixtures("ia73_env")

POD_USER = "identity-admin"  # conftest pod 사용자 이름(운영 ACL 규칙 — 설계 D24)
IDENTIFIER_MAX = 255  # sub · sid 최대 길이(설계 D8 1단계 · 계약 §엔드포인트)
LIFETIME_S = 30 * 24 * 3600  # 세션 절대 수명 2,592,000 s(설계 D29 — 시험의 독립 기대값)
FUTURE_TOLERANCE_S = 60  # 미래 iat 허용(설계 D29 FUTURE_IAT_TOLERANCE_S — 시험의 독립 기대값)
FLOOR_TTL_S = 3600  # 시험이 직접 두는 하한 키의 TTL(판정에는 쓰이지 않는다)
VERDICT_LIMIT_S = 1.0  # ia-30 경과 상한(설계 D29 — 0.2 s 판정 + 여유 · redis-py 기본값이면 5 s 이상)
HANG_LIMIT_S = 5.0  # 멈춤을 유한한 실패로 바꾸는 상한(성능 요구가 아니다)
PROBLEM_CONTENT_TYPE = "application/problem+json"
WARNING_FLOOR = "session_floor.lookup_failed"
WARNING_FUTURE = "session_check.iat_in_future"
NO_STORE = "no-store"  # `/session/check` 응답의 Cache-Control(계약 `/session/check` 행 · R1)
FIXED_NOW = 1_000_000_000  # 순수 함수 시험의 now — 실제 시계와 먼 고정 값(now를 무시하고 시계를 읽는 구현을 가른다 · R3)
# --- 조각 ③-b1(revoke · 기록 · 쓰기 · 지표) ---
METRIC = "session_revocations_total"  # 계약 §관측 메트릭(커밋 뒤에만 +1)
METRIC_REASONS = ("logout", "logout_all", "admin", "authentik_webhook")
ADMIN_GROUP = "platform-admin"
RECORDED = "session_revocation.recorded"
MULTIPLE = "identity.multiple_memberships"
SET_FAILED = "denylist.set_failed"
SET_SKIPPED = "denylist.set_skipped"
FLOOR_TTL_TOLERANCE_S = 5  # 하한 TTL 비교 여유(DB 시계 기준 · 초 내림 · 요청 왕복 — api-30과 같은 재는 법)
WRITE_TTL_FLOOR_S = 320  # revoked:* TTL 하한 비교(요청 왕복 여유 — 상한은 DENYLIST_TTL_S 330)
VALIDATION = (400, "validation-error")
# --- 조각 ③-b2(웹훅 · 관리 명령) ---
FOREIGN_HOST = "evil.example"  # ALLOWED_HOSTS 밖 Host(ia-3)
COMMON_MIDDLEWARE = "django.middleware.common.CommonMiddleware"  # 모든 요청에 get_host()를 부르는 템플릿 미들웨어(ia-3이 뺀다)
WRONG_SIGNATURE = "sha256=" + "0" * 64  # 꼴은 맞고 값이 틀린 서명
NBF_MISSING = "webhook.nbf_missing"
NBF_CLAMPED = "webhook.nbf_clamped"
CALLBACK_FAILED = "session_revocation.callback_failed"
REVOKE_COMMAND = "revoke_sessions"
DB_CLOCK_LAG_S = 400  # ia-39 — 덮은 DB 시계가 지금보다 늦은 초(명령 관문 nbf ≤ DB now + 301을 어기게 한다)
# --- 조각 ③-b2 리뷰 반영(F1-F5) ---
NBF_STALE = "webhook.nbf_stale"
REJECTED = "webhook.rejected"
REJECTED_FIELDS = ("level", "reason", "sub_hash", "error")  # 계약 §관측의 webhook.rejected 필드(+ 수준)
STALE_S = 300  # nbf_stale 문턱 = 웹훅 시각 창의 폭(계약 §웹훅 서명 규약 — 시험의 독립 기대값)
OLD_CREATED_S = 120  # F4 — 창 안이되 ⌊created⌋ + 1이 수신 시각 + 1과 확실히 갈리는 created 지연
RECEIVED = "receive+1"  # nbf 없는 본문의 기대 값 표식 — [⌊t0⌋ + 1, ⌊t1⌋ + 1](t0 · t1 = 요청 전후 시각) 안이면 이 값으로 본다
SCHEMA_PATH = (
    Path(__file__).resolve().parents[3] / "packages" / "events" / "schemas" / "identity-admin.session.revoked.json"
)


# --- 도우미 --------------------------------------------------------------------------------------------------------------


def _check_path(sub: str, iat: int, sid: str | None = None) -> str:
    params = {"sub": sub, "iat": str(iat)}
    if sid is not None:
        params["sid"] = sid
    return f"{CHECK_PATH}?{urlencode(params)}"


def _outcome(response: HttpResponse) -> tuple[int, Any]:
    """(상태, 본문 요약) — problem+json이면 type의 끝 슬러그, JSON이면 본문, 그 밖이면 Content-Type(비교 · 실패 출력용)."""
    content_type = response.get("Content-Type", "")
    if content_type.startswith(PROBLEM_CONTENT_TYPE):
        problem_type = str(json.loads(response.content).get("type", ""))
        return response.status_code, problem_type.rsplit("/", 1)[-1]
    if content_type.startswith("application/json"):
        return response.status_code, json.loads(response.content)
    return response.status_code, content_type


def _pod_like_url(port: int) -> tuple[Secret, Secret]:
    """pod 사용자 꼴의 Dragonfly URL(127.0.0.1:port · 랜덤 비밀번호)과 그 비밀번호 — 둘 다 Secret."""
    password = Secret(secrets.token_urlsafe(16))
    return Secret(f"redis://{POD_USER}:{password}@127.0.0.1:{port}/0"), password


def _connections(client: redis.Redis) -> int:
    """Dragonfly INFO stats의 total_connections_received(이 서버가 받은 연결 누계)."""
    stats: dict[str, Any] = client.info("stats")
    return int(stats["total_connections_received"])


def _leaks(text: str, needles: dict[str, str]) -> list[str]:
    """text에 들어 있는 needle의 이름만(값은 실패 출력에 싣지 않는다)."""
    haystack = Secret(text)
    return sorted(name for name, needle in needles.items() if needle and Secret(needle) in haystack)


def _response_text(response: HttpResponse) -> str:
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    return f"{response.content.decode('utf-8', errors='replace')}\n{headers}"


def _client_for(real_client: Callable[[], redis.Redis], url: str) -> Callable[[], redis.Redis]:
    """`denylist_writer.client`를 덮는 함수 — 진짜 `client()`를 DRAGONFLY_URL = url 아래에서 불러 그 URL의 클라이언트를 준다
    (생성 인자 · 쿼리 거부는 구현 그대로 · 거부 목록 조회는 원래 설정을 쓴다 — 그 조회가 끝난 뒤 하한 조회 때만 불린다)."""

    def make() -> redis.Redis:
        with override_settings(DRAGONFLY_URL=url):
            return real_client()

    return make


def _record() -> Any:
    """키가 하나도 없는 거부 목록 조회 결과(django_common.auth.DenylistRecord — UD-7a 보정: sid_nbf) — 순수 함수 판정용."""
    from django_common.auth import DenylistRecord

    return DenylistRecord(sub_nbf=None, sid_nbf=None)


def _metric_values() -> dict[str, float]:
    """session_revocations_total{reason}의 지금 값(아직 없으면 0 — 전후 차이로 단언한다)."""
    return {reason: REGISTRY.get_sample_value(METRIC, {"reason": reason}) or 0.0 for reason in METRIC_REASONS}


def _metric_delta(before: dict[str, float]) -> dict[str, float]:
    """before 뒤에 바뀐 reason만 {reason: 증가분}."""
    after = _metric_values()
    return {reason: after[reason] - before[reason] for reason in METRIC_REASONS if after[reason] != before[reason]}


def _written(admin: redis.Redis) -> tuple[int, int, list[str]]:
    """(폐기 로그 행 수, outbox 행 수, 거부 목록 · 세션 하한 · 세션 단위 하한 키) — 「쓰기 0」 단언용(app role 연결로 센다 ·
    세션 단위 하한은 UD-7a(ㄴ) T-c)."""
    logs = model("session_revocation_log").objects.count()
    events = model("outbox").objects.count()
    keys = scan_keys(admin, "revoked:*") + scan_keys(admin, floor_key("*")) + scan_keys(admin, sid_floor_key("*"))
    return logs, events, keys


def _user_headers(
    jwks: JwksInfo, sub: str, *, tenant: str = TENANT_A, sid: str | None = "sid-1", groups: Any = None
) -> dict[str, str]:
    """사용자 Bearer + 유효 Access 헤더(m2m 호스트)."""
    return auth_headers(jwks, bearer=bearer_token(jwks, sub, tenant, sid=sid, groups=groups))


def _revoke(client: Client, headers: dict[str, str], body: Any) -> HttpResponse:
    """`POST /sessions/revoke` 한 번(JSON 본문)."""
    return send(client, "post", REVOKE_PATH, headers, body)


def _floor_ttl_expected(nbf: int) -> int:
    """하한 키의 기대 TTL = ⌊nbf + 330 + 30 d − DB now⌋(설계 D13 · D29 — DB 시계 기준)."""
    return math.floor(nbf + DENYLIST_TTL_S + LIFETIME_S - db_now().timestamp())


def _sid_floor_ttl_expected(nbf: int) -> int:
    """요청 경로가 쓴 세션 단위 하한의 기대 TTL = ⌊nbf + 330 + 30 d − 프로세스 시각⌋(t086-design.md D15-4 — DB를 읽지 않는
    쓰기라 프로세스 시계다 · 재적용은 DB 시계)."""
    return math.floor(nbf + DENYLIST_TTL_S + LIFETIME_S - time.time())


def _call_record(
    sub: str, *, nbf: int, sid: str | None = None, reason: str = "logout_all", delegate: bool = False
) -> Any:
    """`revocation.record_revocation`을 바깥 트랜잭션 없이 직접 부른다(그 atomic이 가장 바깥 — 돌아오기 전에 커밋 뒤 콜백이
    끝난다 · source revoke · 테넌트 A)."""
    revocation = impl("revocation")
    return revocation.record_revocation(
        tenant_id=uuid.UUID(TENANT_A), sub=sub, sid=sid, reason=reason, nbf=nbf, source="revoke", delegate=delegate
    )


def _spy_send_task(monkeypatch: pytest.MonkeyPatch) -> list[dict[str, Any]]:
    """`identity_admin.celery.app.send_task`를 덮어 호출을 기록한다(위임 enqueue 이음매 — 설계 D26 · 커밋 뒤 콜백이 호출 때마다
    앱을 가져와 속성으로 부른다)."""
    app = impl("celery").app
    calls: list[dict[str, Any]] = []

    def fake_send_task(name: str, args: Any = None, kwargs: Any = None, **options: Any) -> None:
        calls.append({"name": name, "args": args, "kwargs": kwargs, "options": options})

    monkeypatch.setattr(app, "send_task", fake_send_task)
    return calls


def _hook_secret() -> str:
    """ia73_env가 둔 웹훅 HMAC 비밀(Secret — repr 가림)."""
    from django.conf import settings

    secret: str = settings.AUTHENTIK_WEBHOOK_SECRET
    return secret


def _hook(client: Client, **overrides: Any) -> tuple[dict[str, Any], bytes, HttpResponse]:
    """서명된 웹훅 한 번(svc 호스트 · application/json · 서명 헤더) → (본문 dict, 본문 바이트, 응답). overrides는
    tests._jwt.webhook_body 덮기(sub · action · nbf · created · pk — 값이 None이면 그 키를 뺀다)."""
    data, body, signature = signed_webhook(_hook_secret(), **overrides)
    return data, body, post_webhook(client, body, signature)


def _replay(client: Client, body: bytes) -> HttpResponse:
    """같은 바이트 · 같은 서명의 웹훅 재전송."""
    return post_webhook(client, body, sign_webhook(body, _hook_secret()))


def _hook_data(client: Client, data: dict[str, Any]) -> tuple[bytes, HttpResponse]:
    """주어진 본문 dict를 그대로 직렬화 · 서명해 보낸다(값이 None인 키도 JSON null로 남는다 — `_hook`은 그 키를 뺀다)."""
    body = json.dumps(data).encode()
    return body, post_webhook(client, body, sign_webhook(body, _hook_secret()))


def _rejected_view(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """기록의 `webhook.rejected` 줄 — 계약 필드(level · reason · sub_hash · error) 가운데 그 줄에 있는 키만(없는 키는 빠진다 —
    sub 갈래의 「sub_hash 키 없음」을 dict 비교가 본다)."""
    return [{key: line[key] for key in REJECTED_FIELDS if key in line} for line in log_events(records, REJECTED)]


def _escaped_leaks(records: list[dict[str, Any]], needles: dict[str, str]) -> list[str]:
    """기록의 JSON 텍스트에 needle(JSON 이스케이프 꼴 — NUL · 줄바꿈도 기록과 같은 꼴로 견준다)이 든 이름만."""
    return _leaks(json.dumps(records), {name: json.dumps(value)[1:-1] for name, value in needles.items()})


def _nbf_view(value: Any, expected: Any, t0: float, t1: float) -> Any:
    """기대가 RECEIVED이고 value가 [⌊t0⌋ + 1, ⌊t1⌋ + 1] 안의 정수면 RECEIVED(아니면 value 그대로 — 실패 출력에 값이 보인다)."""
    received = isinstance(value, int) and math.floor(t0) + 1 <= value <= math.floor(t1) + 1
    return RECEIVED if expected == RECEIVED and received else value


def _row_nbf(sub: str) -> list[int]:
    """그 sub의 로그 행 nbf(epoch 초 · 행 순서 무관 — 정렬)."""
    found = model("session_revocation_log").objects.filter(sub=sub)
    return sorted(int(row.nbf.timestamp()) for row in found)


# --- ia-1 · 2(D8) -----------------------------------------------------------------------------------------------------


def test_ia_1_check_query_rules_before_lookup(jwks_server: JwksInfo, settings: SettingsWrapper) -> None:
    """ia-1 — sub · sid 각각에 빈 값 · 256자 · 공백 · NUL · 끝 줄바꿈 · 비ASCII → 400 validation_error(정상 Dragonfly에서도 ·
    닫힌 포트에서도) / 양성 대조: 경계 값(sub 255자 · `!~` · sid 255자) → 200 · 닫힌 포트에서 바른 질의 → 503(그 포트가 조회를
    실제로 막는다 — 그래서 닫힌 포트의 400은 조회 앞에서 판정했다는 뜻이다)."""
    client = Client()
    headers = auth_headers(jwks_server)
    iat = str(int(time.time()))
    valid = {
        "sub-255": {"sub": "s" * IDENTIFIER_MAX, "iat": iat},
        "sub-edges": {"sub": "!~", "iat": iat},
        "sid-255": {"sub": "check-sub", "iat": iat, "sid": "d" * IDENTIFIER_MAX},
    }
    defects = {
        "empty": "",
        "256": "x" * (IDENTIFIER_MAX + 1),
        "space": "a b",
        "nul": f"a{chr(0)}b",
        "trailing-newline": f"ab{chr(10)}",
        "non-ascii": f"caf{chr(0xE9)}",
    }
    invalid: dict[str, dict[str, str]] = {}
    for name, value in defects.items():
        invalid[f"sub-{name}"] = {"sub": value, "iat": iat}
        invalid[f"sid-{name}"] = {"sub": "check-sub", "iat": iat, "sid": value}

    def ask(params: dict[str, str]) -> tuple[int, Any]:
        return _outcome(send(client, "get", f"{CHECK_PATH}?{urlencode(params)}", headers))

    accepted = {case: ask(params) for case, params in valid.items()}
    refused_live = {case: ask(params) for case, params in invalid.items()}
    url, _ = _pod_like_url(closed_port())
    settings.DRAGONFLY_URL = url
    closed_control = ask({"sub": "check-sub", "iat": iat})
    refused_closed = {case: ask(params) for case, params in invalid.items()}

    wrong_accepted = {case: got for case, got in accepted.items() if got != (200, {"active": True})}
    assert wrong_accepted == {}
    assert closed_control == (503, "denylist-unavailable")
    expected = (400, "validation-error")
    wrong_live = {case: got for case, got in refused_live.items() if got != expected}
    assert wrong_live == {}
    wrong_closed = {case: got for case, got in refused_closed.items() if got != expected}
    assert wrong_closed == {}


def test_ia_2_check_reuses_dragonfly_clients(
    jwks_server: JwksInfo, dragonfly: DragonflyInfo, ia73_df_admin: redis.Redis
) -> None:
    """ia-2 — `/session/check` 3회 → Dragonfly 연결 증가 ≤ 2(거부 목록 `Denylist` 하나 + 쓰기 클라이언트 하나 — 요청마다 새로
    만들면 요청당 2) / 양성 대조: 같은 측정에서 새 클라이언트 하나의 PING = 연결 +1(누계가 실제 연결을 센다)."""
    client = Client()
    headers = auth_headers(jwks_server)
    path = _check_path("reuse-sub", int(time.time()))
    start = _connections(ia73_df_admin)
    probe = redis.Redis.from_url(dragonfly.pod_url)
    try:
        probe.ping()
    finally:
        probe.close()
    after_probe = _connections(ia73_df_admin)
    outcomes = [_outcome(send(client, "get", path, headers)) for _ in range(3)]
    after_requests = _connections(ia73_df_admin)

    assert outcomes == [(200, {"active": True})] * 3
    assert after_probe - start == 1
    opened = after_requests - after_probe
    assert opened <= 2, f"요청 3회가 연 연결 {opened}"


# --- ia-3(D10 1단계 · U8 b — 웹훅의 Host 판정) --------------------------------------------------------------------------


@DB
def test_ia_3_webhook_checks_host_before_signature(settings: SettingsWrapper, ia73_df_admin: redis.Redis) -> None:
    """ia-3(U8 b — 설계 D10 1단계 · 규칙 §Auth 「면제 경로에서는 뷰가 HMAC 앞에 get_host()를 부른다」): 미들웨어 가운데 Host를
    부르는 층(CommonMiddleware · ADMIN_HOST가 있을 때의 AdminHostMiddleware)을 없앤 채(MIDDLEWARE에서 CommonMiddleware를 빼고
    ADMIN_HOST="") ALLOWED_HOSTS 밖 Host로 웹훅 → 서명이 맞든 틀리든 400 invalid_host(401이 아니다) · 쓰기 0 / 짝: 같은 본문 ·
    서명을 svc 호스트로 → 틀린 서명 401 webhook_signature_invalid · 맞는 서명 202."""
    sub = "ia3-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    settings.MIDDLEWARE = [name for name in settings.MIDDLEWARE if name != COMMON_MIDDLEWARE]
    settings.ADMIN_HOST = ""
    client = Client()
    _, body, signature = signed_webhook(_hook_secret(), sub=sub, nbf=int(time.time()) - 2)

    def post(host: str, value: str) -> tuple[int, Any]:
        return _outcome(send(client, "post", WEBHOOK_PATH, {"host": host, SIGNATURE_HEADER: value}, body))

    foreign = {"signed": post(FOREIGN_HOST, signature), "wrong-signature": post(FOREIGN_HOST, WRONG_SIGNATURE)}
    foreign_written = _written(ia73_df_admin)
    svc_wrong = post(SVC_HOST, WRONG_SIGNATURE)
    svc_signed_status = post(SVC_HOST, signature)[0]
    invalid_host = (400, "invalid-host")

    assert foreign == {"signed": invalid_host, "wrong-signature": invalid_host}
    assert foreign_written == (0, 0, [])
    assert (svc_wrong, svc_signed_status) == ((401, "webhook-signature-invalid"), 202)


# --- ia-4 · 5(D9 · D12 — `/sessions/revoke` 판정 순서 · 조합 · 문자 규칙 · 롤백 · 다중 멤버십) ----------------------------


@DB
def test_ia_4_revoke_refusals_write_nothing(jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-4 — 거부되는 요청은 아무것도 쓰지 않는다(4xx 판정은 모두 쓰기 앞 · 설계 D9): 판정 순서(본문 검증 400 → 403 → 조합
    400 → tenant · sid 400) · 조합(본인 logout ↔ all_devices false · logout_all ↔ true · admin은 다른 sub 지정 관리자만) ·
    본문 `sub` · `sid`의 256자 · NUL · 공백 · 토큰에서 온 `sid` · `sub`의 문자 규칙 위반(JSON 문자열은 NUL도 담는다) → 400 ·
    403이고 로그 0 · outbox 0 · 키(revoked:* · 하한) 0 · 지표 0.

    짝(설계 D26 「부정 사례의 짝」 — 같은 준비물에서 한 가지만 바꾼 정상 사례): 토큰 sid가 바른 본인 logout · 본문 sid 255자 ·
    관리자 reason admin · 본인 logout_all → 모두 202이고 행 4 · 지표 logout +2 · logout_all +1 · admin +1. 본인 logout_all은
    그 사용자의 토큰을 거부하게 만드므로 마지막이다(같은 sid 토큰도 쓰지 않는다 — sid 폐기가 그 토큰을 거부한다)."""
    caller, member, admin_sub = "ia4-caller", "ia4-member", "ia4-admin"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=member, role="member")
    client = Client()
    nul = chr(0)
    plain = _user_headers(jwks_server, caller, sid="ia4-sid")
    admin = _user_headers(jwks_server, admin_sub, sid="ia4-admin-sid", groups=[ADMIN_GROUP])
    refusals: dict[str, tuple[dict[str, str], dict[str, Any], tuple[int, str]]] = {
        # 판정 순서
        "body-before-403": (plain, {"sub": "x" * 256, "all_devices": True, "reason": "admin"}, VALIDATION),
        "403-before-combination": (plain, {"sub": member, "all_devices": True, "reason": "logout"}, (403, "forbidden")),
        "403-before-membership": (
            plain,
            {"sub": "ia4-ghost", "all_devices": True, "reason": "admin"},
            (403, "forbidden"),
        ),
        # 조합
        "self-logout-all-devices": (plain, {"all_devices": True, "reason": "logout"}, VALIDATION),
        "self-logout_all-single": (plain, {"all_devices": False, "reason": "logout_all"}, VALIDATION),
        "self-admin-reason": (plain, {"all_devices": True, "reason": "admin"}, VALIDATION),
        "self-named-admin-reason": (plain, {"sub": caller, "all_devices": True, "reason": "admin"}, VALIDATION),
        "admin-other-logout_all": (admin, {"sub": member, "all_devices": True, "reason": "logout_all"}, VALIDATION),
        # 본문 문자 규칙
        "body-sub-256": (admin, {"sub": "x" * 256, "all_devices": True, "reason": "admin"}, VALIDATION),
        "body-sub-nul": (admin, {"sub": f"ia4{nul}member", "all_devices": True, "reason": "admin"}, VALIDATION),
        "body-sid-256": (plain, {"all_devices": False, "reason": "logout", "sid": "d" * 256}, VALIDATION),
        "body-sid-nul": (plain, {"all_devices": False, "reason": "logout", "sid": f"d{nul}d"}, VALIDATION),
        "body-sid-space": (plain, {"all_devices": False, "reason": "logout", "sid": "d d"}, VALIDATION),
        # 토큰에서 온 값의 문자 규칙(스키마를 지나지 않는 입력)
        "token-sid-nul": (
            _user_headers(jwks_server, caller, sid=f"ia4{nul}sid"),
            {"all_devices": False, "reason": "logout"},
            VALIDATION,
        ),
        "token-sid-256": (
            _user_headers(jwks_server, caller, sid="s" * 256),
            {"all_devices": False, "reason": "logout"},
            VALIDATION,
        ),
        "token-sid-space": (
            _user_headers(jwks_server, caller, sid="ia4 sid"),
            {"all_devices": False, "reason": "logout"},
            VALIDATION,
        ),
        "token-sid-trailing-newline": (  # Python `$`는 끝 줄바꿈 앞에서도 맞는다 — 문자 규칙은 fullmatch여야 한다
            _user_headers(jwks_server, caller, sid=f"ia4-sid{chr(10)}"),
            {"all_devices": False, "reason": "logout"},
            VALIDATION,
        ),
        "token-sub-nul": (
            _user_headers(jwks_server, f"ia4{nul}caller"),
            {"all_devices": True, "reason": "logout_all"},
            VALIDATION,
        ),
        "token-sub-256": (
            _user_headers(jwks_server, "c" * 256),
            {"all_devices": True, "reason": "logout_all"},
            VALIDATION,
        ),
    }
    before = _metric_values()
    refused = {case: _outcome(_revoke(client, headers, body)) for case, (headers, body, _) in refusals.items()}
    after_refusals = (_written(ia73_df_admin), _metric_delta(before))
    accepted = {
        "self-logout-token-sid": _revoke(
            client, _user_headers(jwks_server, caller, sid="ia4-p1"), {"all_devices": False, "reason": "logout"}
        ).status_code,
        "self-logout-body-sid-255": _revoke(
            client,
            _user_headers(jwks_server, caller, sid="ia4-p2"),
            {"all_devices": False, "reason": "logout", "sid": "d" * 255},
        ).status_code,
        "admin-other": _revoke(client, admin, {"sub": member, "all_devices": True, "reason": "admin"}).status_code,
        "self-logout_all": _revoke(
            client, _user_headers(jwks_server, caller, sid="ia4-p3"), {"all_devices": True, "reason": "logout_all"}
        ).status_code,
    }
    logs, events, _ = _written(ia73_df_admin)
    accepted_delta = _metric_delta(before)
    not_accepted = {case: status for case, status in accepted.items() if status != 202}

    wrong = {case: got for case, got in refused.items() if got != refusals[case][2]}
    assert wrong == {}
    assert after_refusals == ((0, 0, []), {})
    assert not_accepted == {}
    assert (logs, events) == (4, 4)
    assert accepted_delta == {"logout": 2.0, "logout_all": 1.0, "admin": 1.0}


@DB
def test_ia_4_rollback_leaves_no_trace(ia73_df_admin: redis.Redis, log_lines: LogLines) -> None:
    """ia-4(지표 0 — 설계 D12 「롤백이면 콜백이 버려진다」 · D25 「커밋 뒤에만 +1」): 바깥 atomic 안에서
    `record_revocation`을 부른 뒤 그 트랜잭션을 롤백하면 로그 행 0 · outbox 0 · 키 0 · 지표 0 · `session_revocation.recorded`
    0 / 짝: 같은 호출을 롤백 없이 → 행 1 · outbox 1 · `revoked:sub` + 하한 키 · 지표 logout_all +1 · 그 줄 1."""
    from django.db import transaction

    sub = "ia4-rollback-sub"
    nbf = int(time.time()) + 1
    before = _metric_values()
    log_lines()
    with transaction.atomic():
        discarded = _call_record(sub, nbf=nbf)
        transaction.set_rollback(True)
    rolled_back = (_written(ia73_df_admin), _metric_delta(before), len(log_events(log_lines(), RECORDED)))
    committed = _call_record(sub, nbf=nbf)
    kept = (_written(ia73_df_admin), _metric_delta(before), len(log_events(log_lines(), RECORDED)))
    kinds = (type(discarded).__name__, type(committed).__name__)

    assert kinds == ("Recorded", "Recorded")
    assert rolled_back == ((0, 0, []), {}, 0)
    assert kept == ((1, 1, [sub_key(sub), floor_key(sub)]), {"logout_all": 1.0}, 1)


def _ia5_admin(jwks: JwksInfo, target: str) -> HttpResponse:
    """ia-5 관리자 호출(platform-admin · 테넌트 A 토큰 · 다른 sub 사용자 단위)."""
    headers = _user_headers(jwks, "ia5-admin", groups=[ADMIN_GROUP])
    return _revoke(Client(), headers, {"sub": target, "all_devices": True, "reason": "admin"})


def _ia5_webhook(jwks: JwksInfo, target: str) -> HttpResponse:
    """ia-5 웹훅 경로(서명된 logout 웹훅 · 본문 nbf = 지금 - 2 — 조각 ③-b2)."""
    _, _, response = _hook(Client(), sub=target, nbf=int(time.time()) - 2)
    return response


# ia-5 경로 표 — 같은 준비물(멤버십 둘)에 같은 단언을 건다(관리자 호출 — ③-b1 · 서명된 logout 웹훅 — ③-b2).
IA5_PATHS: dict[str, Callable[[JwksInfo, str], HttpResponse]] = {"admin": _ia5_admin, "webhook": _ia5_webhook}


@DB
@pytest.mark.parametrize("path", sorted(IA5_PATHS))
def test_ia_5_multiple_memberships_pick_smallest_tenant(path: str, jwks_server: JwksInfo, log_lines: LogLines) -> None:
    """ia-5 — 같은 sub의 멤버십이 둘(테넌트 B를 먼저 · A를 나중에 넣는다 — 넣은 순서가 답이 되지 않게)이면 202(409 아님) ·
    로그 행과 outbox의 tenant_id = 둘 가운데 작은 쪽 · WARNING `identity.multiple_memberships` 한 줄(count 2 · sub_hash =
    그 sub의 해시 · 그 요청의 로그 줄 전부에 원문 sub 없음)."""
    from django_common.observability import sub_hash

    target = f"ia5-{path}-target"
    insert_row("tenant_membership", tenant_id=TENANT_B, sub=target, role="member")
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=target, role="member")
    smallest = str(min(uuid.UUID(TENANT_A), uuid.UUID(TENANT_B)))
    log_lines()
    status = IA5_PATHS[path](jwks_server, target).status_code
    records = log_lines()
    log_tenants = [str(row.tenant_id) for row in model("session_revocation_log").objects.all()]
    event_tenants = [str(row.partition_key) for row in model("outbox").objects.all()]
    warned = log_events(records, MULTIPLE)
    fields = [(line.get("level"), line.get("count"), line.get("sub_hash")) for line in warned]
    expected_hash = sub_hash(target)
    leaks = _leaks(json.dumps(records), {"sub": target})

    assert status == 202
    assert (log_tenants, event_tenants) == ([smallest], [smallest])
    assert fields == [("warning", 2, expected_hash)]
    assert leaks == []


# --- ia-6 · 7 · 8(D10 · D12 — POST /webhooks/authentik) ---------------------------------------------------------------


@DB
def test_ia_6_webhook_field_rules(
    monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-6(D10 4단계 · 〔Y21〕): 서명 · 시각이 맞는 logout 웹훅의 업무 필드 — nbf 음수 → 400 · sub에 NUL · 공백 · 끝 줄바꿈 ·
    256자 → 400 · pk 256자 · NUL이 든 pk → 400(400은 모두 validation_error · 로그 0 · outbox 0 · 키 0). 공백 · 끝 줄바꿈 · 256자
    sub에는 멤버십을 둔다 — 멤버십이 없어 나는 400(api-23)과 가르게(문자 규칙이 없는 구현은 그 sub로 202를 낸다 · NUL은 PG text에
    둘 수 없어 조회가 500이 된다) / 짝: 같은 준비물에서 과거 nbf(지금 - 3600) → 202 · 그 sub의 로그 행 1(nbf = 본문 값).

    400의 사유 줄(F5 — 계약 §웹훅 서명 규약 · §관측): 400 요청마다 `webhook.rejected`가 정확히 한 줄 — action 없음 · 정수 →
    WARNING action / sub의 NUL · 공백 · 끝 줄바꿈 · 256자 → WARNING sub(sub_hash 키 없음 — 규칙을 어긴 값은 해시하지 않는다) /
    pk 256자 · NUL → WARNING pk + sub_hash / 음수 nbf → WARNING nbf + sub_hash / 멤버십 없는 sub → INFO membership + sub_hash /
    관문 거부(`revocation.record_revocation`을 RevocationRejected("nbf")를 던지게 덮는다) → WARNING gate + sub_hash + error nbf.
    401(틀린 서명) · 200(무시하는 action) · 202(짝) 요청에는 0줄. 모든 요청의 로그 줄에 원문 sub · pk가 없다(JSON 이스케이프
    꼴로 견준다 — NUL · 줄바꿈 값도 기록과 같은 꼴로 찾는다).

    3b2V-1(조각 ④ 첫 단계): nbf false · 빈 문자열 → 400 WARNING nbf(거짓 값은 「없음」이 아니다) · sub 정수 + pk 256자 → 400
    WARNING sub(sub_hash 키 없음 — sub 검사가 pk 검사보다 앞이다 · 500이 아니다) · 받아들인 본문의 재전송 → 200 · 0줄."""
    from django_common.observability import sub_hash

    revocation = impl("revocation")
    impl("identity_api")  # 뷰 모듈을 덮기 전에 적재한다(③-a 교훈)
    sub, stranger = "ia6-sub", "ia6-stranger"
    weird = {"space": "ia6 sub", "trailing-newline": f"ia6-sub{chr(10)}", "256": "s" * 256}
    for member in (sub, *weird.values()):
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=member, role="member")
    client = Client()
    now = int(time.time())
    hashed = sub_hash(sub)
    warn = {"level": "warning"}
    refusals: dict[str, tuple[dict[str, Any], dict[str, Any]]] = {
        "action-missing": ({"sub": sub, "action": None}, {**warn, "reason": "action"}),
        "action-integer": ({"sub": sub, "action": 5}, {**warn, "reason": "action"}),
        "nbf-negative": ({"sub": sub, "nbf": -1}, {**warn, "reason": "nbf", "sub_hash": hashed}),
        # 3b2V-1 ① — 거짓 값(false · 빈 문자열)은 「없음」이 아니다(없음은 키 없음과 JSON null뿐 — 그 밖의 정수 아닌 값은 400)
        "nbf-false": ({"sub": sub, "nbf": False}, {**warn, "reason": "nbf", "sub_hash": hashed}),
        "nbf-empty-string": ({"sub": sub, "nbf": ""}, {**warn, "reason": "nbf", "sub_hash": hashed}),
        "sub-nul": ({"sub": f"ia6{chr(0)}sub"}, {**warn, "reason": "sub"}),
        **{f"sub-{case}": ({"sub": value}, {**warn, "reason": "sub"}) for case, value in weird.items()},
        # 3b2V-1 ③ — sub와 pk가 둘 다 나쁘면 sub 갈래다(pk 검사가 sub 앞이면 정수 sub에 sub_hash를 불러 500이 된다)
        "sub-integer-pk-256": ({"sub": 5, "pk": "p" * 256}, {**warn, "reason": "sub"}),
        "pk-256": ({"sub": sub, "pk": "p" * 256}, {**warn, "reason": "pk", "sub_hash": hashed}),
        "pk-nul": ({"sub": sub, "pk": f"pk{chr(0)}x"}, {**warn, "reason": "pk", "sub_hash": hashed}),
        "membership": ({"sub": stranger}, {"level": "info", "reason": "membership", "sub_hash": sub_hash(stranger)}),
    }
    every_record: list[dict[str, Any]] = []
    needles: dict[str, str] = {}

    def sent(case: str, data: dict[str, Any]) -> list[dict[str, Any]]:
        records = log_lines()
        every_record.extend(records)
        needles.update({f"{field}-{case}": data[field] for field in ("sub", "pk") if isinstance(data.get(field), str)})
        return records

    log_lines()
    refused: dict[str, tuple[Any, list[dict[str, Any]]]] = {}
    for case, (overrides, _) in refusals.items():
        data, _, response = _hook(client, **overrides)
        refused[case] = (_outcome(response), _rejected_view(sent(case, data)))

    def reject_at_gate(**_: Any) -> Any:
        raise revocation.RevocationRejected("nbf")

    with monkeypatch.context() as patch:
        patch.setattr(revocation, "record_revocation", reject_at_gate)
        data, _, response = _hook(client, sub=sub, nbf=now - 2)
        refused["gate"] = (_outcome(response), _rejected_view(sent("gate", data)))
    written = _written(ia73_df_admin)
    data, body, _ = signed_webhook(_hook_secret(), sub=sub, nbf=now - 2)
    unsigned = post_webhook(client, body, WRONG_SIGNATURE).status_code
    quiet = {"wrong-signature": (unsigned, len(_rejected_view(sent("wrong-signature", data))))}
    data, _, response = _hook(client, sub=sub, action="login")
    quiet["ignored-action"] = (response.status_code, len(_rejected_view(sent("ignored-action", data))))
    past_nbf = now - 3600
    data, accepted_body, response = _hook(client, sub=sub, nbf=past_nbf)
    quiet["accepted"] = (response.status_code, len(_rejected_view(sent("accepted", data))))
    # 3b2V-1 ④ — 받아들인 본문의 재전송(200)은 400이 아니다 — 사유 줄이 없다
    replayed = _replay(client, accepted_body).status_code
    quiet["accepted-replay"] = (replayed, len(_rejected_view(sent("accepted-replay", data))))
    expected = {case: (VALIDATION, [line]) for case, (_, line) in refusals.items()}
    expected["gate"] = (VALIDATION, [{**warn, "reason": "gate", "sub_hash": hashed, "error": "nbf"}])
    leaks = _escaped_leaks(every_record, needles)

    assert refused == expected
    assert written == (0, 0, [])
    assert quiet == {
        "wrong-signature": (401, 0),
        "ignored-action": (200, 0),
        "accepted": (202, 0),
        "accepted-replay": (200, 0),
    }
    assert _row_nbf(sub) == [past_nbf]
    assert leaks == []


@DB
def test_ia_7_webhook_insert_race_is_replay(
    monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-7(D12 4단계 · 〔Y10〕): `revocation.event_already_recorded`를 늘 거짓으로 덮고(호출을 센다) 같은 웹훅을 두 번 → 첫째
    202 · 둘째 200 `{}`(INSERT 경합 갈래 — IntegrityError `srl_event_pk_uniq` → Replayed · 500 아님) · 로그 행 1 · outbox 1 ·
    둘째 응답과 두 요청의 로그 줄에 DETAIL(`DETAIL` · `duplicate key` · pk 값)이 없다 · 덮은 함수가 요청마다 두 번(뷰의 사전
    확인 · 기록 공통의 사전 확인) 불렸다 — 두 호출 지점이 모듈 속성으로 부른다(한쪽이 이름을 묶어 진짜 함수를 부르면 사전 확인이
    200을 내 경합 갈래를 지나지 않는다)."""
    revocation = impl("revocation")
    impl("identity_api")  # 뷰 모듈을 덮기 전에 적재한다(③-a 교훈 — import 때 이름을 묶는 구현이 덮은 함수를 묶지 않게)
    calls: list[str] = []

    def never_recorded(event_pk: str) -> bool:
        calls.append(event_pk)
        return False

    monkeypatch.setattr(revocation, "event_already_recorded", never_recorded)
    sub = "ia7-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    client = Client()
    log_lines()
    data, body, first = _hook(client, sub=sub, nbf=int(time.time()) - 2)
    first_calls = len(calls)
    second = _replay(client, body)
    records = log_lines()
    outcomes = (first.status_code, _outcome(second))
    per_request = (first_calls, len(calls) - first_calls)
    written = _written(ia73_df_admin)[:2]
    needles = {"detail": "DETAIL", "duplicate": "duplicate key", "pk": str(data["pk"])}
    leaks = _leaks(json.dumps(records) + _response_text(second), needles)

    assert outcomes == (202, (200, {}))
    assert per_request == (2, 2)
    assert written == (1, 1)
    assert leaks == []


@DB
def test_ia_8_webhook_responses_and_no_delegation(
    jwks_server: JwksInfo, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-8(D10 · D16 · 〔Y12 · Y17 · E7〕) — 쓰기 켬 · send_task 가로채기: 먼저 같은 가로채기로 본인 전체 로그아웃 → 1회(이음매가
    닿는다) / 웹훅 202 본문 키 = 정확히 {id, nbf, expires_at} · 같은 바이트 재전송 200 본문 `{}` / 무시하는 action(login)은 sub가
    정수 · nbf가 문자열이어도 200 `{}`(본문의 다른 필드를 보지 않는다) / hex 32자(대문자) pk와 같은 UUID의 대시 꼴 pk → 한
    행(둘째 200 · 저장된 event_pk = 대시 소문자) / nbf 없는 본문 → 202 + WARNING `webhook.nbf_missing` 한 줄(sub_hash · 원문 sub
    없음) / 끝에 위임 호출 수가 처음 그대로(웹훅은 위임하지 않는다 — 출처가 Authentik이다).

    F3(경고의 자리 — 본문 꼴 판정에서 남는다): nbf 없는 같은 본문(같은 pk)의 재전송 → 200 `{}`이고 그 요청에도 `webhook.nbf_missing`
    한 줄 · 멤버십 없는 sub + nbf 없음 → 400이고 `webhook.nbf_missing` 한 줄. F2: 본문에 `"nbf": null`을 그대로 실어 서명 → 202 ·
    `webhook.nbf_missing` 한 줄 · 응답 nbf ∈ [⌊t0⌋ + 1, ⌊t1⌋ + 1](없는 것으로 읽는다 — 400이 아니다).

    3b2V-1(조각 ④ 첫 단계): nbf 0 → 202 · 응답 nbf 0 · `webhook.nbf_missing` 0줄(거짓 값을 「없음」으로 읽지 않는다) / 과거
    nbf(지금 - 3600 · 문턱 밖) 본문 → 202이고 `webhook.nbf_stale` 한 줄 · 같은 바이트 재전송 → 200 `{}`이고 그 요청에도 한 줄
    (멤버십 조회 앞의 본문 꼴 판정에서 남는다)."""
    from django_common.observability import sub_hash

    for member in ("ia8-hook", "ia8-pk", "ia8-missing", "ia8-null", "5", "ia8-zero", "ia8-stale"):
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=member, role="member")
    calls = _spy_send_task(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    client = Client()
    control = _revoke(client, _user_headers(jwks_server, "ia8-self"), {"all_devices": True, "reason": "logout_all"})
    control_calls = len(calls)
    _, body, recorded = _hook(client, sub="ia8-hook", nbf=int(time.time()) - 2)
    recorded_keys = sorted(json.loads(recorded.content)) if recorded.status_code == 202 else None
    replayed = _outcome(_replay(client, body))
    ignored = _outcome(_hook(client, action="login", sub=5, nbf="x")[2])
    ignored_rows = model("session_revocation_log").objects.filter(sub="5").count()
    event = uuid.uuid4()
    hex_form = _hook(client, sub="ia8-pk", pk=event.hex.upper(), nbf=int(time.time()) - 2)[2].status_code
    dashed_form = _outcome(_hook(client, sub="ia8-pk", pk=str(event), nbf=int(time.time()) - 2)[2])
    stored_pks = list(model("session_revocation_log").objects.filter(sub="ia8-pk").values_list("event_pk", flat=True))
    log_lines()
    _, missing_body, missing_response = _hook(client, sub="ia8-missing", nbf=None)
    missing_records = log_lines()
    missing_replay = _outcome(_replay(client, missing_body))
    replay_records = log_lines()
    stranger = _outcome(_hook(client, sub="ia8-stranger", nbf=None)[2])
    stranger_records = log_lines()
    t0 = time.time()
    null_response = _hook_data(client, {**webhook_body(sub="ia8-null"), "nbf": None})[1]
    t1 = time.time()
    null_records = log_lines()
    null_nbf = json.loads(null_response.content).get("nbf") if null_response.status_code == 202 else None
    missing = {
        "missing": (missing_response.status_code, missing_records),
        "replay": (missing_replay, replay_records),
        "stranger": (stranger, stranger_records),
        "null": ((null_response.status_code, _nbf_view(null_nbf, RECEIVED, t0, t1)), null_records),
    }
    warned = {
        case: (status, [(line.get("level"), line.get("sub_hash")) for line in log_events(records, NBF_MISSING)])
        for case, (status, records) in missing.items()
    }
    # 3b2V-1 ① — nbf 0은 값이다(「없음」이 아니다): 202 · 응답 nbf 0 · nbf_missing 0줄
    zero_response = _hook(client, sub="ia8-zero", nbf=0)[2]
    zero_records = log_lines()
    zero_nbf = json.loads(zero_response.content).get("nbf") if zero_response.status_code == 202 else None
    zero = (zero_response.status_code, zero_nbf, len(log_events(zero_records, NBF_MISSING)))
    # 3b2V-1 ⑤ — 과거 nbf(문턱 밖) 본문과 그 재전송: 요청마다 nbf_stale 한 줄(경고는 본문 꼴 판정에서 남는다 — 재전송 200에서도)
    _, stale_body, stale_first = _hook(client, sub="ia8-stale", nbf=int(time.time()) - 3600)
    stale_first_records = log_lines()
    stale_replay = _outcome(_replay(client, stale_body))
    stale_replay_records = log_lines()
    stale = {
        "first": (stale_first.status_code, stale_first_records),
        "replay": (stale_replay, stale_replay_records),
    }
    stale_warned = {
        case: (status, [(line.get("level"), line.get("sub_hash")) for line in log_events(records, NBF_STALE)])
        for case, (status, records) in stale.items()
    }
    every_record = (
        missing_records + replay_records + stranger_records + null_records + stale_first_records + stale_replay_records
    )
    named = ("missing", "stranger", "null", "stale")
    leaks = _leaks(json.dumps(every_record), {name: f"ia8-{name}" for name in named})
    hashed = {name: sub_hash(f"ia8-{name}") for name in named}

    assert (control.status_code, control_calls) == (202, 1)
    assert (recorded.status_code, recorded_keys) == (202, ["expires_at", "id", "nbf"])
    assert (replayed, ignored, ignored_rows) == ((200, {}), (200, {}), 0)
    assert (hex_form, dashed_form, stored_pks) == (202, (200, {}), [str(event)])
    assert warned == {
        "missing": (202, [("warning", hashed["missing"])]),
        "replay": ((200, {}), [("warning", hashed["missing"])]),
        "stranger": (VALIDATION, [("warning", hashed["stranger"])]),
        "null": ((202, RECEIVED), [("warning", hashed["null"])]),
    }
    assert zero == (202, 0, 0)
    assert stale_warned == {
        "first": (202, [("warning", hashed["stale"])]),
        "replay": ((200, {}), [("warning", hashed["stale"])]),
    }
    assert leaks == []
    assert len(calls) == control_calls


# --- ia-7 옆(S8 — 기록 공통의 무결성 오류) ----------------------------------------------------------------------------------


@DB
def test_ia_7_write_error_carries_no_message_or_chain(ia73_df_admin: redis.Redis) -> None:
    """ia-7 옆(S8 — 설계 D12 4단계 · 계약 §오류 슬러그 「DB 무결성 오류」): `record_revocation(reason=<모델 REVOCATION_REASONS 밖
    값>)` → RevocationWriteError · `str(exc)` 빈 값 · `__cause__` · `__context__` 둘 다 None(연쇄된 IntegrityError의 DETAIL —
    행 값 — 이 트레이스백 · Sentry로 가지 않는다) · 로그 행 0 · outbox 0 · 키 0 · 지표 변화 0 / 짝: 같은 인자에 바른 reason →
    Recorded."""
    revocation = impl("revocation")
    nbf = int(time.time()) + 1
    before = _metric_values()
    with pytest.raises(revocation.RevocationWriteError) as caught:
        _call_record("s8-sub", nbf=nbf, reason="not-a-reason")
    error = caught.value
    shape = (str(error), error.__cause__, error.__context__)
    written, delta = _written(ia73_df_admin), _metric_delta(before)
    pair = _call_record("s8-sub", nbf=nbf, reason="logout_all")

    assert shape == ("", None, None)
    assert (written, delta) == ((0, 0, []), {})
    assert type(pair).__name__ == "Recorded"


# --- ia-17(D22 — outbox data의 스키마 대조) --------------------------------------------------------------------------------

# 검사기가 아는 스키마 키: 메타(검증하지 않는다 · `x-*`도) + 검증 키워드 다섯과 그 구조 키. 그 밖의 키워드를 만나면 실패한다 —
# 스키마가 넓어질 때(pattern · maxLength 등) 시험이 그 키워드를 조용히 건너뛰어 공허해지지 않게(설계 D22 · 새 의존 0).
SCHEMA_ANNOTATIONS = frozenset({"$schema", "$id", "$comment", "title", "description", "examples"})
SCHEMA_KEYWORDS = frozenset({"type", "properties", "required", "minLength", "minimum", "enum"})


class UnknownSchemaKeywordError(ValueError):
    """검사기가 모르는 스키마 키워드 · type 이름(이름만 싣는다)."""


def _json_type(value: Any, name: str) -> bool:
    checks: dict[str, Callable[[Any], bool]] = {
        "string": lambda v: isinstance(v, str),
        "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
        "number": lambda v: isinstance(v, int | float) and not isinstance(v, bool),
        "boolean": lambda v: isinstance(v, bool),
        "null": lambda v: v is None,
        "object": lambda v: isinstance(v, dict),
        "array": lambda v: isinstance(v, list),
    }
    if name not in checks:
        raise UnknownSchemaKeywordError(f"type {name}")
    return checks[name](value)


def _schema_violations(schema: dict[str, Any], value: Any, where: str = "data") -> list[str]:
    """value가 schema를 어기는 자리 목록(type · minLength · minimum · enum · required · properties만 안다)."""
    known = SCHEMA_ANNOTATIONS | SCHEMA_KEYWORDS
    unknown = sorted(key for key in schema if key not in known and not key.startswith("x-"))
    if unknown:
        raise UnknownSchemaKeywordError(f"{where}: {unknown}")
    if "type" in schema:
        names = [schema["type"]] if isinstance(schema["type"], str) else list(schema["type"])
        if not any(_json_type(value, name) for name in names):
            return [f"{where}: type"]
    problems: list[str] = []
    if "enum" in schema and value not in schema["enum"]:
        problems.append(f"{where}: enum")
    if "minLength" in schema and isinstance(value, str) and len(value) < schema["minLength"]:
        problems.append(f"{where}: minLength")
    number = isinstance(value, int | float) and not isinstance(value, bool)
    if "minimum" in schema and number and value < schema["minimum"]:
        problems.append(f"{where}: minimum")
    if isinstance(value, dict):
        problems += [f"{where}.{name}: required" for name in schema.get("required", []) if name not in value]
        for name, child in schema.get("properties", {}).items():
            if name in value:
                problems += _schema_violations(child, value[name], f"{where}.{name}")
    return problems


def test_ia_17_schema_checker_self_test() -> None:
    """ia-17(검사기 자기검사 — 부정 사례의 짝): 실제 스키마로 바른 data → 위반 0 / reason 오타 · nbf 음수 · nbf bool · nbf
    문자열 · sub 빈 값 · sid 빈 값 · sid 정수 · reason 없음 → 각각 위반 ≥ 1 / 모르는 키워드(pattern)가 든 스키마 → 검사 실패."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    good = {"sub": "s", "sid": None, "nbf": 0, "reason": "logout"}
    bad = {
        "reason-typo": {**good, "reason": "logot"},
        "nbf-negative": {**good, "nbf": -1},
        "nbf-bool": {**good, "nbf": True},
        "nbf-string": {**good, "nbf": "1"},
        "sub-empty": {**good, "sub": ""},
        "sid-empty": {**good, "sid": ""},
        "sid-int": {**good, "sid": 1},
        "no-reason": {key: value for key, value in good.items() if key != "reason"},
    }
    clean = _schema_violations(schema, good)
    missed = sorted(case for case, data in bad.items() if not _schema_violations(schema, data))
    with pytest.raises(UnknownSchemaKeywordError):
        _schema_violations({"type": "string", "pattern": "^x$"}, "x")

    assert clean == []
    assert missed == []


# ia-17 생산자 표 — reason마다 outbox 1행을 만드는 요청(같은 Client · revoke 셋은 ③-b1 · authentik_webhook은 ③-b2).
@DB
def test_ia_17_revoked_event_data_matches_schema(jwks_server: JwksInfo) -> None:
    """ia-17 — 생산하는 reason마다(logout · logout_all · admin · authentik_webhook) outbox data가
    `packages/events/schemas/identity-admin.session.revoked.json`을 만족하고 키가 정확히 넷(sub · sid · nbf · reason)이다."""
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    insert_row("tenant_membership", tenant_id=TENANT_A, sub="ia17-member", role="member")
    insert_row("tenant_membership", tenant_id=TENANT_A, sub="ia17-hook", role="member")
    client = Client()
    producers: dict[str, Callable[[], HttpResponse]] = {
        "logout": lambda: _revoke(
            client, _user_headers(jwks_server, "ia17-self", sid="ia17-sid"), {"all_devices": False, "reason": "logout"}
        ),
        "logout_all": lambda: _revoke(
            client,
            _user_headers(jwks_server, "ia17-all", sid="ia17-all-sid"),
            {"all_devices": True, "reason": "logout_all"},
        ),
        "admin": lambda: _revoke(
            client,
            _user_headers(jwks_server, "ia17-admin", groups=[ADMIN_GROUP]),
            {"sub": "ia17-member", "all_devices": True, "reason": "admin"},
        ),
        "authentik_webhook": lambda: _hook(client, sub="ia17-hook", nbf=int(time.time()) - 2)[2],
    }
    statuses = {reason: produce().status_code for reason, produce in producers.items()}
    payloads = [row.payload for row in model("outbox").objects.all()]
    datas = [(payload if isinstance(payload, dict) else json.loads(payload))["data"] for payload in payloads]
    by_reason = {data.get("reason"): data for data in datas}
    produced, expected_reasons = sorted(by_reason, key=str), sorted(producers)
    four_keys = ["nbf", "reason", "sid", "sub"]
    key_sets = {reason: sorted(data) for reason, data in by_reason.items() if sorted(data) != four_keys}
    violations = {reason: found for reason, data in by_reason.items() if (found := _schema_violations(schema, data))}
    not_accepted = {reason: status for reason, status in statuses.items() if status != 202}
    data_count, producer_count = len(datas), len(producers)  # S6 — 생산자 표는 자격을 만드는 호출의 표다(assert 식 밖에서 센다)

    assert not_accepted == {}
    assert (data_count, produced) == (producer_count, expected_reasons)
    assert key_sets == {}
    assert violations == {}


# --- ia-19(D25 · D13 — 로그 위생 · 쓰기 시간 상한) --------------------------------------------------------------------------


@DB
def test_ia_19_revoke_path_logs_carry_no_raw_values(
    jwks_server: JwksInfo, dragonfly: DragonflyInfo, log_lines: LogLines
) -> None:
    """ia-19(revoke 경로) — 본인 logout(sid) · 관리자 호출 · 본인 logout_all의 로그 줄 전부에 원문 sub · sid · Dragonfly
    호스트:포트 · 비밀번호 · `redis://`가 없다 / 짝(그 줄들이 있다는 양성): `session_revocation.recorded` 세 줄(INFO · reason ·
    scope · source · tenant_id · revocation_id · sub_hash 32 hex) · 그 줄들의 `revocation_id` 집합 = 세 응답의 `id` 집합(S7).
    웹훅 경로는 아래 별도 노드(조각 ③-b2)다."""
    caller, target = "ia19-caller", "ia19-target"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=target, role="member")
    client = Client()
    log_lines()
    responses = [
        _revoke(
            client, _user_headers(jwks_server, caller, sid="ia19-sid-a"), {"all_devices": False, "reason": "logout"}
        ),
        _revoke(
            client,
            _user_headers(jwks_server, "ia19-admin", sid="ia19-admin-sid", groups=[ADMIN_GROUP]),
            {"sub": target, "all_devices": True, "reason": "admin"},
        ),
        _revoke(
            client, _user_headers(jwks_server, caller, sid="ia19-sid-b"), {"all_devices": True, "reason": "logout_all"}
        ),
    ]
    records = log_lines()
    statuses = [response.status_code for response in responses]
    response_ids = sorted(str(json.loads(response.content).get("id")) for response in responses)
    recorded = log_events(records, RECORDED)
    shapes = sorted(
        (line.get("level"), line.get("reason"), line.get("scope"), line.get("source"), line.get("tenant_id"))
        for line in recorded
    )
    hashes = [len(value) == 32 if isinstance(value := line.get("sub_hash"), str) else False for line in recorded]
    ids = [isinstance(value := line.get("revocation_id"), str) and len(value) == 36 for line in recorded]
    logged_ids = sorted(str(line.get("revocation_id")) for line in recorded)
    parts = urlsplit(dragonfly.pod_url)
    needles = {
        "caller": caller,
        "target": target,
        "sid-a": "ia19-sid-a",
        "sid-b": "ia19-sid-b",
        "host-port": f"{parts.hostname}:{parts.port}",
        "password": Secret(parts.password or ""),
        "scheme": "redis://",
    }
    leaks = _leaks(json.dumps(records), needles)

    assert statuses == [202, 202, 202]
    assert shapes == sorted(
        [
            ("info", "logout", "session", "revoke", TENANT_A),
            ("info", "admin", "user", "admin", TENANT_A),
            ("info", "logout_all", "user", "revoke", TENANT_A),
        ]
    )
    assert (hashes, ids) == ([True] * 3, [True] * 3)
    assert logged_ids == response_ids
    assert leaks == []


@DB
def test_ia_19_webhook_path_logs_carry_no_raw_values(dragonfly: DragonflyInfo, log_lines: LogLines) -> None:
    """ia-19(웹훅 경로 — 조각 ③-b2): 서명된 logout 웹훅 셋(본문 nbf 있음 · nbf 없음 → nbf_missing · nbf가 ⌊created⌋ + 1을
    넘음 → nbf_clamped · 셋 다 본문 sid가 있다)의 로그 줄 전부에 원문 sub · 본문 sid · 웹훅 비밀 · 서명 · Dragonfly 호스트:포트 ·
    비밀번호 · `redis://`가 없다 / 짝: `session_revocation.recorded` 세 줄(INFO · reason authentik_webhook · scope user · source
    webhook · tenant A · revocation_id 집합 = 응답 id 집합) · 경고 두 줄(webhook.nbf_missing · webhook.nbf_clamped — WARNING ·
    sub_hash 32자)."""
    subs = {"plain": "ia19-hook-plain", "missing": "ia19-hook-missing", "clamped": "ia19-hook-clamped"}
    for member in subs.values():
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=member, role="member")
    client = Client()
    now = int(time.time())
    nbfs = {"plain": now - 2, "missing": None, "clamped": now + 86400}
    log_lines()
    sent = {case: _hook(client, sub=subs[case], sid=f"{subs[case]}-sid", nbf=nbfs[case]) for case in subs}
    records = log_lines()
    statuses = {case: response.status_code for case, (_, _, response) in sent.items()}
    response_ids = sorted(str(json.loads(response.content).get("id")) for _, _, response in sent.values())
    recorded = log_events(records, RECORDED)
    shapes = [
        (line.get("level"), line.get("reason"), line.get("scope"), line.get("source"), line.get("tenant_id"))
        for line in recorded
    ]
    logged_ids = sorted(str(line.get("revocation_id")) for line in recorded)
    warnings = sorted(
        (line.get("event"), line.get("level"), len(str(line.get("sub_hash"))))
        for line in log_events(records, NBF_MISSING) + log_events(records, NBF_CLAMPED)
    )
    parts = urlsplit(dragonfly.pod_url)
    needles: dict[str, str] = {
        "host-port": f"{parts.hostname}:{parts.port}",
        "password": Secret(parts.password or ""),
        "scheme": "redis://",
        "secret": _hook_secret(),
    }
    for case, (data, body, _) in sent.items():
        needles[f"sub-{case}"] = subs[case]
        needles[f"sid-{case}"] = str(data.get("sid"))
        needles[f"signature-{case}"] = Secret(sign_webhook(body, _hook_secret()))
    leaks = _leaks(json.dumps(records), needles)

    assert statuses == dict.fromkeys(subs, 202)
    assert shapes == [("info", "authentik_webhook", "user", "webhook", TENANT_A)] * 3
    assert logged_ids == response_ids
    assert warnings == [(NBF_CLAMPED, "warning", 32), (NBF_MISSING, "warning", 32)]
    assert leaks == []


@DB
def test_ia_19_set_failure_logs_carry_no_raw_values(settings: SettingsWrapper, log_lines: LogLines) -> None:
    """ia-19(SET 실패 경로) — DRAGONFLY_URL이 닫힌 포트(pod 모양 URL · 랜덤 비밀번호)면 커밋 뒤 쓰기(사용자 단위 · sid)가
    둘 다 `unreachable`이고 WARNING `denylist.set_failed`(stage connect · error = 예외 클래스 이름) 두 줄 · 로그 줄 전부에 원문
    sub · sid · 호스트:포트 · 비밀번호 · `redis://` · 예외 문구(`connecting`)가 없다 / 짝: 같은 호출을 실제 Dragonfly로 → `ok` 둘."""
    sub, sid = "ia19-fail-sub", "ia19-fail-sid"
    nbf = int(time.time()) + 1

    def both() -> tuple[str, str]:
        user_scope = _call_record(sub, nbf=nbf).after.denylist
        session_scope = _call_record(sub, nbf=nbf, sid=sid, reason="logout").after.denylist
        return user_scope, session_scope

    live = both()
    url, password = _pod_like_url(closed_port())
    settings.DRAGONFLY_URL = url
    log_lines()
    down = both()
    records = log_lines()
    failed = log_events(records, SET_FAILED)
    shapes = [
        (line.get("level"), line.get("stage"), isinstance(error := line.get("error"), str) and error.isidentifier())
        for line in failed
    ]
    recorded = len(log_events(records, RECORDED))
    parts = urlsplit(url)
    needles = {
        "sub": sub,
        "sid": sid,
        "host-port": f"{parts.hostname}:{parts.port}",
        "password": password,
        "scheme": "redis://",
        "exception-text": "connecting",
    }
    leaks = _leaks(json.dumps(records), needles)

    assert live == ("ok", "ok")
    assert down == ("unreachable", "unreachable")
    assert shapes == [("warning", "connect", True)] * 2
    assert recorded == 2
    assert leaks == []


@DB
def test_ia_19_apply_user_blackhole_unreachable_within_1s(
    settings: SettingsWrapper, ia73_df_admin: redis.Redis
) -> None:
    """ia-19(쓰기 시간 상한 — 설계 D13 변이 「0.2 s 명시 삭제」) — 활성 사용자 단위 행을 둔 채 `denylist_writer.apply_user`를
    직접 부른다: 실제 Dragonfly → `ok`(두 키가 생긴다) / DRAGONFLY_URL이 블랙홀 포트 → 1 s 안에 `unreachable`(0.2 s 명시를
    지우면 redis-py 기본값으로 5 s 상한에서 멈춘다 · 닫힌 포트는 Linux에서 즉시 RST라 가르지 못해 쓰지 않는다).

    재는 구간(S10): `timed`가 돌리는 함수가 같은 스레드 안에서 DB 워밍업 쿼리 1회(새 스레드의 새 연결 · TLS 접속을 측정 밖으로
    뺀다) 뒤 `apply_user`만 `time.perf_counter()`로 잰다 — 단언은 그 경과이고 `timed`의 상한은 멈춤 방어다."""
    from django.db import connection

    writer = impl("denylist_writer")
    sub = "ia19-hole-sub"
    insert_log_row(sub, nbf=datetime.fromtimestamp(int(time.time()) + 1, UTC))

    def measured() -> tuple[str, float]:
        with connection.cursor() as cursor:  # 워밍업 — 이 스레드의 새 DB 연결(TLS)을 측정 구간 밖에서 연다
            cursor.execute("SELECT 1")
        start = time.perf_counter()
        result = writer.apply_user(sub)
        return result, time.perf_counter() - start

    (live, _), _ = timed(measured, HANG_LIMIT_S)
    keys = scan_keys(ia73_df_admin, f"*{sub}")
    with blackhole() as port:
        url, _ = _pod_like_url(port)
        settings.DRAGONFLY_URL = url
        (down, write_elapsed), _ = timed(measured, HANG_LIMIT_S)

    assert (live, keys) == ("ok", sorted([floor_key(sub), sub_key(sub)]))
    assert down == "unreachable"
    assert write_elapsed < VERDICT_LIMIT_S, f"쓰기 {write_elapsed:.3f} s"


class _RaisingWarningLog:
    """`revocation.log` 대역(S1) — warning은 던지고(실패 로그 호출 자신이 실패하는 꼴) info는 원래 로거로 넘긴다."""

    def __init__(self, inner: Any) -> None:
        self._inner = inner

    def warning(self, *args: Any, **kwargs: Any) -> None:
        raise RuntimeError("log sink down")

    def info(self, *args: Any, **kwargs: Any) -> Any:
        return self._inner.info(*args, **kwargs)


@DB
def test_ia_19_commit_callback_steps_are_isolated(
    settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-19 옆(S1 — 설계 D12 6단계 「단계마다 자기 try/except」): 커밋 뒤 쓰기(`denylist_writer.apply_user`)가 예상 밖
    예외(문구 = 자격이 든 URL 꼴의 심은 값)를 던져도 `record_revocation`은 예외 없이 Recorded이고 뒤 단계가 돈다(쓰기 켬 ·
    자격이 자리값 아님 · send_task 가로채기): after = (failed, enqueued) · 가로챈 호출 1회 · 지표 그 reason +1 ·
    `session_revocation.recorded` 한 줄 · WARNING `session_revocation.callback_failed` 한 줄(step denylist · error
    RuntimeError) · 그 호출의 로그 줄 전부에 원문 sub · 심은 문구 · `Error calling`(Django robust 로그) 없음.
    실패 로그 호출 자신이 던져도(`revocation.log.warning`) 같다 — callback_failed 줄만 없고 뒤 단계(지표 · 로그 · 위임)는 돈다."""
    revocation = impl("revocation")
    writer = impl("denylist_writer")
    planted = Secret(f"redis://{POD_USER}:{secrets.token_urlsafe(16)}@planted.invalid:6379/0")

    def broken_apply_user(sub: str) -> str:
        raise RuntimeError(planted)

    calls = _spy_send_task(monkeypatch)
    settings.AUTHENTIK_WRITES_ENABLED = True
    monkeypatch.setattr(writer, "apply_user", broken_apply_user)
    nbf = int(time.time()) + 1
    outcomes: dict[str, Any] = {}
    leaked: dict[str, list[str]] = {}
    for case in ("step-raises", "log-raises-too"):
        if case == "log-raises-too":
            monkeypatch.setattr(revocation, "log", _RaisingWarningLog(revocation.log))
        sub = f"ia19-{case}-sub"
        before, call_start = _metric_values(), len(calls)
        log_lines()
        recorded = _call_record(sub, nbf=nbf, delegate=True)
        records = log_lines()
        failed_steps = [
            (line.get("level"), line.get("step"), line.get("error"))
            for line in log_events(records, CALLBACK_FAILED)
        ]
        outcomes[case] = (
            type(recorded).__name__,
            (recorded.after.denylist, recorded.after.delegate),
            len(calls) - call_start,
            _metric_delta(before),
            len(log_events(records, RECORDED)),
            failed_steps,
        )
        leaked[case] = _leaks(json.dumps(records), {"sub": sub, "planted": planted, "robust-log": "Error calling"})

    assert outcomes == {
        "step-raises": (
            "Recorded",
            ("failed", "enqueued"),
            1,
            {"logout_all": 1.0},
            1,
            [("warning", "denylist", "RuntimeError")],
        ),
        "log-raises-too": ("Recorded", ("failed", "enqueued"), 1, {"logout_all": 1.0}, 1, []),
    }
    assert leaked == {"step-raises": [], "log-raises-too": []}


@DB
def test_ia_19_commit_callback_registered_without_values() -> None:
    """ia-19 옆(S1 — 등록 꼴): 시험이 연 atomic 안에서 `record_revocation`을 부른 뒤 블록을 나가기 전에
    `connection.run_on_commit`의 마지막 항목(`(savepoint ids, func, robust)` — Django 6.1 base.py `on_commit`)을 읽는다 →
    robust 참 · `functools.partial`이 아니다 · `repr(func)`에 원문 sub · sid가 없다(Django robust 로그는 `__qualname__`이 없는
    콜백의 repr을 `%s`로 찍는다 — partial의 repr은 키워드 인자 값을 싣는다)."""
    from django.db import connection, transaction

    sub, sid = "ia19-shape-sub", "ia19-shape-sid"
    with transaction.atomic():
        recorded = _call_record(sub, nbf=int(time.time()) + 1, sid=sid, reason="logout")
        registered = list(connection.run_on_commit)
    _, func, robust = registered[-1]
    shape = (type(recorded).__name__, robust, isinstance(func, functools.partial))
    leaks = _leaks(repr(func), {"sub": sub, "sid": sid})

    assert shape == ("Recorded", True, False)
    assert leaks == []


# --- ia-21(D11) · ia-25(D9) -------------------------------------------------------------------------------------------


@DB
def test_ia_21_tenants_me_orphan_membership(jwks_server: JwksInfo) -> None:
    """ia-21 — 멤버십(S, A, member) + Tenant A → 200 `{tenant, role}` / 같은 준비물에서 Tenant 행만 지운 뒤(고아 멤버십) → 404
    not_found(멤버십 행은 그대로다)."""
    sub = "orphan-sub"
    insert_row("tenant", id=TENANT_A, slug="tenant-a", display_name="Tenant A", status="active")
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    client = Client()
    headers = auth_headers(jwks_server, bearer=bearer_token(jwks_server, sub, TENANT_A))
    present = _outcome(send(client, "get", TENANTS_ME, headers))
    deleted, _ = model("tenant").objects.using(OWNER_ALIAS).filter(pk=TENANT_A).delete()
    orphan = send(client, "get", TENANTS_ME, headers)
    memberships = model("tenant_membership").objects.using(OWNER_ALIAS).filter(sub=sub).count()

    tenant = {"id": TENANT_A, "slug": "tenant-a", "display_name": "Tenant A", "status": "active"}
    assert present == (200, {"tenant": tenant, "role": "member"})
    assert (deleted, memberships) == (1, 1)
    assert_problem(orphan, 404, "not_found")


@DB
def test_ia_21_tenants_me_unprintable_sub_is_404(jwks_server: JwksInfo) -> None:
    """ia-21 옆(R8 — 설계 D11 · D9의 문자 규칙) — 서명된 Bearer의 `sub`에 NUL이 있으면 `/tenants/me`는 조회 앞에서 404
    not_found다(그런 sub의 멤버십은 어느 경로로도 생길 수 없다 · psycopg DataError → 500이 아니다) / 짝: 같은 준비물에서 sub만
    출력 가능 ASCII로 바꾼 토큰(멤버십 있음) → 200."""
    sub = "printable-sub"
    insert_row("tenant", id=TENANT_A, slug="tenant-a", display_name="Tenant A", status="active")
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    client = Client()
    good = auth_headers(jwks_server, bearer=bearer_token(jwks_server, sub, TENANT_A))
    bad = auth_headers(jwks_server, bearer=bearer_token(jwks_server, f"printable{chr(0)}sub", TENANT_A))
    present = _outcome(send(client, "get", TENANTS_ME, good))
    refused = send(client, "get", TENANTS_ME, bad)

    assert present[0] == 200
    assert_problem(refused, 404, "not_found")


class TestIa21StaticSchema:
    """Docker 없이 도는 정적 노드(R4) — 모듈 pytestmark의 `ia73_env`를 이 클래스 안에서만 빈 픽스처로 가린다(pytest는 가장
    가까운 정의를 쓴다 — 설정 덮기 · Dragonfly · 가짜 서버가 필요 없다)."""

    @pytest.fixture
    def ia73_env(self) -> None:
        """빈 픽스처 — 이 클래스의 노드는 시험 환경을 쓰지 않는다."""

    def test_ia_21_response_literals_match_model_constants(self) -> None:
        """`/tenants/me` 응답 스키마의 Literal 둘(`TenantOut.status` · `TenantMeOut.role`)이 모델 상수(`TENANT_STATUSES` ·
        `MEMBERSHIP_ROLES`)와 같다 — 한쪽만 바뀌면 `/tenants/me`가 응답 검증에서 500이다(SP-2가 `admin` 역할을 더할 때)."""
        api = impl("identity_api")
        models = impl("models")
        status_values = typing.get_args(api.TenantOut.model_fields["status"].annotation)
        role_values = typing.get_args(api.TenantMeOut.model_fields["role"].annotation)
        expected = (tuple(models.TENANT_STATUSES), tuple(models.MEMBERSHIP_ROLES))

        assert (status_values, role_values) == expected


@DB
def test_ia_25_sid_key_unseen_without_sid_claim(jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-25(한계 고정 — 설계 D9 「pod 경계의 한계」) — `revoked:sid:x`(값 = 지금 + 60 — UD-7a 보정: 값은 폐기 시각이다 · 이전
    값 1)가 있어도 `sid` 클레임이 없는 Bearer(BFF 교환 토큰 꼴)로 `/tenants/me` → 200 / 대조: 같은 키 · 같은 사용자에서 `sid`
    클레임이 x인 Bearer(iat = 지금 — 값보다 작다) → 401 session_revoked(키는 살아 있다)."""
    sub = "sid-limit-sub"
    insert_row("tenant", id=TENANT_A, slug="tenant-a", display_name="Tenant A", status="active")
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="owner")
    ia73_df_admin.set(sid_key("x"), int(time.time()) + 60, ex=FLOOR_TTL_S)
    client = Client()
    without_sid = auth_headers(jwks_server, bearer=bearer_token(jwks_server, sub, TENANT_A, sid=None))
    with_sid = auth_headers(jwks_server, bearer=bearer_token(jwks_server, sub, TENANT_A, sid="x"))
    unseen = _outcome(send(client, "get", TENANTS_ME, without_sid))
    revoked = send(client, "get", TENANTS_ME, with_sid)

    tenant = {"id": TENANT_A, "slug": "tenant-a", "display_name": "Tenant A", "status": "active"}
    assert unseen == (200, {"tenant": tenant, "role": "owner"})
    assert_problem(revoked, 401, "session_revoked")


# --- ia-27 · 28(D29 세션 하한 쓰기 · D13) ------------------------------------------------------------------------------


def _ia27_all_devices(client: Client, jwks: JwksInfo, sub: str) -> HttpResponse:
    """본인 전체 로그아웃(all_devices true · logout_all)."""
    return _revoke(client, _user_headers(jwks, sub, sid=f"{sub}-sid"), {"all_devices": True, "reason": "logout_all"})


def _ia27_admin(client: Client, jwks: JwksInfo, sub: str) -> HttpResponse:
    """관리자 호출(다른 sub · 사용자 단위 · 대상의 멤버십은 시험이 먼저 둔다)."""
    headers = _user_headers(jwks, "ia27-admin", sid="ia27-admin-sid", groups=[ADMIN_GROUP])
    return _revoke(client, headers, {"sub": sub, "all_devices": True, "reason": "admin"})


def _ia27_webhook(client: Client, jwks: JwksInfo, sub: str) -> HttpResponse:
    """서명된 logout 웹훅(본문 nbf = 지금 - 2 · 항상 사용자 단위 — 조각 ③-b2)."""
    _, _, response = _hook(client, sub=sub, nbf=int(time.time()) - 2)
    return response


# ia-27 사용자 단위 경로 표 — 같은 단언(하한 값 = nbf · TTL = ⌊expires_at + 30 d − DB now⌋ ± 5) · 사용자 단위 3경로가 다 찬다.
IA27_PATHS: dict[str, Callable[[Client, JwksInfo, str], HttpResponse]] = {
    "all-devices": _ia27_all_devices,
    "admin": _ia27_admin,
    "webhook": _ia27_webhook,
}


@DB
@pytest.mark.parametrize("path", sorted(IA27_PATHS))
def test_ia_27_user_scope_writes_floor(path: str, jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-27 — 사용자 단위 폐기(본인 all_devices · 관리자 호출 · 웹훅) → 세션 하한 키 `identity-admin:session-floor:{sub}`
    = 응답 nbf · TTL = ⌊nbf + 330 + 30 d − DB now⌋ ± 5(DB 시계 — api-30과 같은 재는 법 · 2,592,000을 넘는 EX를 Dragonfly가
    받고 TTL로 돌려준다 — VD-T073-12) · `revoked:sub` = 같은 nbf(TTL은 330 이하)."""
    sub = f"ia27-{path}-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    response = IA27_PATHS[path](Client(), jwks_server, sub)
    status = response.status_code
    nbf = json.loads(response.content).get("nbf") if status == 202 else None
    values = (read_int(ia73_df_admin, floor_key(sub)), read_int(ia73_df_admin, sub_key(sub)))
    floor_ttl = read_ttl(ia73_df_admin, floor_key(sub))
    sub_ttl = read_ttl(ia73_df_admin, sub_key(sub))
    expected_ttl = _floor_ttl_expected(nbf) if isinstance(nbf, int) else None
    drift = None if expected_ttl is None else abs(floor_ttl - expected_ttl)

    assert status == 202
    assert values == (nbf, nbf)
    assert drift is not None and drift <= FLOOR_TTL_TOLERANCE_S, f"하한 TTL {floor_ttl} · 기대 {expected_ttl}"
    assert WRITE_TTL_FLOOR_S <= sub_ttl <= DENYLIST_TTL_S, f"revoked:sub TTL {sub_ttl}"


@DB
def test_ia_28_session_scope_writes_sid_floor_only(jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-28 — (a) `sid` 폐기(본인 logout · all_devices false) → 키는 정확히 둘 — `revoked:sid:{sid}` = 응답 nbf와 세션 단위
    하한 `identity-admin:sid-floor:{sid}` = 응답 nbf(UD-7a(ㄴ) T-c — 이전 문구 「sid 행은 하한을 만들지 않는다」). 사용자 단위
    하한 `session-floor:{sub}` · `revoked:sub` 없음 / (b) 같은 sub에 더 큰 nbf의 `sid` 행(지금 + 50)이 있는 채 사용자 단위 폐기 →
    하한 · `revoked:sub` = 사용자 단위 행의 nbf(응답 nbf — sid 행의 더 큰 nbf가 아니다 · 최댓값 조회의 `sid IS NULL`)."""
    client = Client()
    single = "ia28-single-sub"
    single_response = _revoke(
        client, _user_headers(jwks_server, single, sid="ia28-sid"), {"all_devices": False, "reason": "logout"}
    )
    single_status = single_response.status_code
    single_nbf = json.loads(single_response.content).get("nbf") if single_status == 202 else None
    single_keys = scan_keys(ia73_df_admin, "*")
    single_values = (read_int(ia73_df_admin, sid_key("ia28-sid")), read_int(ia73_df_admin, sid_floor_key("ia28-sid")))
    mixed = "ia28-mixed-sub"
    bigger = int(time.time()) + 50
    insert_log_row(mixed, nbf=datetime.fromtimestamp(bigger, UTC), sid="ia28-old-sid", reason="logout")
    response = _ia27_all_devices(client, jwks_server, mixed)
    mixed_status = response.status_code
    nbf = json.loads(response.content).get("nbf") if mixed_status == 202 else None
    mixed_values = (read_int(ia73_df_admin, floor_key(mixed)), read_int(ia73_df_admin, sub_key(mixed)))

    assert (single_status, single_keys) == (202, sorted([sid_floor_key("ia28-sid"), sid_key("ia28-sid")]))
    assert single_values == (single_nbf, single_nbf)
    assert mixed_status == 202
    assert isinstance(nbf, int) and nbf < bigger
    assert mixed_values == (nbf, nbf)


@DB
def test_ia_28_direct_write_branches(
    settings: SettingsWrapper, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-28 옆(S4 1-3 — 설계 D13 「TTL이 1 미만인 키는 보내지 않는다」 · `skipped` 반환 · 직접 호출):
    ① 과거 nbf(지금 - 3600) 사용자 단위(웹훅 경로의 reason · source · event_pk) → after.denylist ok · `revoked:sub` 없음 · 하한 =
    그 nbf · 하한 TTL = ⌊nbf + 330 + 30 d - DB now⌋ ± 5(약 30 d - 3270 s) · 그 호출의 `denylist.set_failed` 0줄
    ② 만료된 sid 행(nbf = 지금 - 400) → ok(UD-7a 보정 — 이전 skipped: 두 키 가운데 하나라도 보냈으면 ok이고 세션 단위 하한은
    30 d를 산다) · 그 sid의 `revoked:sid` 없음(TTL < 1) · 세션 단위 하한 = 그 nbf · TTL = ⌊nbf + 330 + 30 d - 프로세스 시각⌋ ± 5 ·
    `denylist.set_skipped` 0줄 · set_failed 0줄
    ③ 보존 창 밖 사용자 단위(nbf = 지금 - 31 d)를 DRAGONFLY_URL이 닫힌 포트인 채 → skipped(Dragonfly에 닿았다면 unreachable) ·
    set_failed 0줄."""
    revocation = impl("revocation")
    now = int(time.time())
    past_sub, expired_sid, old_sub = "s4-past-sub", "s4-expired-sid", "s4-old-sub"
    past_nbf = now - 3600

    def call(**fields: Any) -> tuple[Any, list[dict[str, Any]]]:
        log_lines()
        recorded = revocation.record_revocation(tenant_id=uuid.UUID(TENANT_A), **fields)
        return recorded, log_lines()

    past, past_records = call(
        sub=past_sub,
        sid=None,
        reason="authentik_webhook",
        nbf=past_nbf,
        source="webhook",
        event_pk=str(uuid.uuid4()),
    )
    past_keys = (read_int(ia73_df_admin, sub_key(past_sub)), read_int(ia73_df_admin, floor_key(past_sub)))
    past_drift = abs(read_ttl(ia73_df_admin, floor_key(past_sub)) - _floor_ttl_expected(past_nbf))
    expired, expired_records = call(
        sub="s4-sid-owner", sid=expired_sid, reason="logout", nbf=now - 400, source="revoke"
    )
    expired_keys = scan_keys(ia73_df_admin, sid_key(expired_sid))
    expired_floor = read_int(ia73_df_admin, sid_floor_key(expired_sid))
    expired_drift = abs(read_ttl(ia73_df_admin, sid_floor_key(expired_sid)) - _sid_floor_ttl_expected(now - 400))
    url, _ = _pod_like_url(closed_port())
    settings.DRAGONFLY_URL = url
    old, old_records = call(sub=old_sub, sid=None, reason="logout_all", nbf=now - LIFETIME_S - 86400, source="revoke")
    results = (past.after.denylist, expired.after.denylist, old.after.denylist)
    set_failed = [len(log_events(records, SET_FAILED)) for records in (past_records, expired_records, old_records)]
    skipped_lines = [(line.get("level"), line.get("event")) for line in log_events(expired_records, SET_SKIPPED)]

    assert results == ("ok", "ok", "skipped")
    assert past_keys == (None, past_nbf)
    assert past_drift <= FLOOR_TTL_TOLERANCE_S, f"하한 TTL 차이 {past_drift}"
    assert expired_keys == []
    assert expired_floor == now - 400
    assert expired_drift <= FLOOR_TTL_TOLERANCE_S, f"세션 단위 하한 TTL 차이 {expired_drift}"
    assert skipped_lines == []
    assert set_failed == [0, 0, 0]


@DB
def test_ia_28_lookup_failure_writes_nothing(
    monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-28 옆(S4 4 — 설계 D13 「실패」 1단계): 사용자 단위 행과 두 키(표식 값)를 둔 채 `session_floor.REVOCATION_LOG_RETENTION`을
    간격이 아닌 값(문자열)으로 덮고 `denylist_writer.apply_user`를 직접 부른다 → failed · WARNING `denylist.set_failed`(stage
    lookup · error = 예외 클래스 이름) 한 줄 · 두 키의 값이 그대로(쓰기 0 — 자기 행 값으로 대신 쓰지 않는다) · 그 줄에 원문 sub
    없음 / 짝: 덮기 전 같은 준비물 → ok · 두 키 = 행의 nbf."""
    writer = impl("denylist_writer")
    floor_module = impl("session_floor")
    sub = "s4-lookup-sub"
    nbf = int(time.time()) + 1
    insert_log_row(sub, nbf=datetime.fromtimestamp(nbf, UTC))
    marks = {sub_key(sub): 111, floor_key(sub): 222}

    def plant_marks() -> None:
        for key, value in marks.items():
            ia73_df_admin.set(key, value, ex=FLOOR_TTL_S)

    plant_marks()
    live = writer.apply_user(sub)
    live_values = {key: read_int(ia73_df_admin, key) for key in marks}
    plant_marks()
    monkeypatch.setattr(floor_module, "REVOCATION_LOG_RETENTION", "not-an-interval")
    log_lines()
    failed = writer.apply_user(sub)
    records = log_lines()
    kept_values = {key: read_int(ia73_df_admin, key) for key in marks}
    lines = log_events(records, SET_FAILED)
    shapes = [
        (line.get("level"), line.get("stage"), isinstance(error := line.get("error"), str) and error.isidentifier())
        for line in lines
    ]
    leaks = _leaks(json.dumps(lines), {"sub": sub})

    assert (live, live_values) == ("ok", dict.fromkeys(marks, nbf))
    assert failed == "failed"
    assert shapes == [("warning", "lookup", True)]
    assert kept_values == marks
    assert leaks == []


@DB
def test_ia_4_record_gate_rejects_before_writing(ia73_df_admin: redis.Redis) -> None:
    """ia-4 옆(S4 5 · S3 — 설계 D12 2단계 관문 · 심층 방어): `record_revocation` 직접 호출 — sub에 NUL · sid 256자 ·
    event_pk에 공백 · nbf -1 · nbf True · nbf 1.5 → 각각 RevocationRejected(code sub · sid · event_pk · nbf · nbf · nbf ·
    `str(exc)`가 code뿐) / nbf = 10^18(표현 가능 상한 `NBF_MAX` 밖 — source webhook · revoke · reconcile) →
    RevocationRejected(code nbf — 500으로 터지지 않는다) / 그 뒤 로그 행 0 · outbox 0 · 키 0. 짝: 같은 인자의 바른 값(nbf =
    지금 + 1 · source 셋) → Recorded."""
    revocation = impl("revocation")
    now = int(time.time())
    base: dict[str, Any] = {
        "tenant_id": uuid.UUID(TENANT_A),
        "sub": "s4-gate-sub",
        "sid": None,
        "reason": "logout_all",
        "nbf": now + 1,
        "source": "revoke",
        "event_pk": None,
    }

    def hook(source: str) -> dict[str, Any]:
        return {"source": source, "reason": "authentik_webhook", "event_pk": str(uuid.uuid4())}

    cases: dict[str, tuple[dict[str, Any], str]] = {
        "sub-nul": ({"sub": f"s4{chr(0)}gate"}, "sub"),
        "sid-256": ({"sid": "d" * 256, "reason": "logout"}, "sid"),
        "event_pk-space": ({**hook("webhook"), "event_pk": "pk with space"}, "event_pk"),
        "nbf-negative": ({"nbf": -1}, "nbf"),
        "nbf-bool": ({"nbf": True}, "nbf"),
        "nbf-float": ({"nbf": 1.5}, "nbf"),
        "nbf-max-webhook": ({**hook("webhook"), "nbf": 10**18}, "nbf"),
        "nbf-max-revoke": ({"nbf": 10**18}, "nbf"),
        "nbf-max-reconcile": ({**hook("reconcile"), "nbf": 10**18}, "nbf"),
    }
    observed: dict[str, tuple[str, str]] = {}
    for case, (overrides, _) in cases.items():
        outcome: tuple[str, str]
        try:
            revocation.record_revocation(**{**base, **overrides})
        except revocation.RevocationRejected as exc:
            outcome = (exc.code, str(exc))
        except Exception as exc:  # noqa: BLE001 — 거부가 아닌 예외(500이 될 것)는 클래스 이름으로 접는다(값 · 트레이스백 없음)
            outcome = (type(exc).__name__, "")
        else:
            outcome = ("recorded", "")
        observed[case] = outcome
    written = _written(ia73_df_admin)
    pairs = {
        "revoke": revocation.record_revocation(**base),
        "webhook": revocation.record_revocation(**{**base, **hook("webhook"), "sub": "s4-gate-hook"}),
        "reconcile": revocation.record_revocation(**{**base, **hook("reconcile"), "sub": "s4-gate-backfill"}),
    }
    pair_kinds = {source: type(result).__name__ for source, result in pairs.items()}

    assert observed == {case: (code, code) for case, (_, code) in cases.items()}
    assert written == (0, 0, [])
    assert pair_kinds == dict.fromkeys(pairs, "Recorded")


# --- ia-29 · 30(D29 판정 · 조회 실패) -------------------------------------------------------------------------------------


def test_ia_29_floor_verdict_table(jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-29 — 키를 admin으로 직접 두고 판정 표를 본다(같은 Client · 사례마다 두 키를 지우고 다시 둔다): 하한 iat + 1 →
    `{"active": false}`(nbf 키 없음) · 하한 = iat → active · 하한 iat - 1 → active · 하한 iat + 100 + `revoked:sub` iat - 5 →
    `{"active": false, "nbf": iat - 5}` · 하한 값이 정수가 아님(`not-a-number` · `12.5`) → 503 denylist_unavailable.

    하한 값의 정규 꼴(R7 — 쓰는 쪽은 `str(nbf)`만 쓴다): ASCII 숫자 1-19자만 판정에 쓴다 — 음수 `-5` · 앞뒤 공백 ` 12 ` ·
    `+7` · `1_000` · 빈 값 · 20자리는 「정수가 아닌 값」과 같은 503이다(음수를 받으면 「하한 없음」처럼 조용히 통과한다) /
    양성: `0` → active · 19자리(10^18) → inactive(판정까지 간다).
    응답 캐시 금지(R1 — 계약 `/session/check` 행): 200(active · inactive)과 503 모두 `Cache-Control: no-store`."""
    sub, iat = "floor-sub", int(time.time())
    client = Client()
    headers = auth_headers(jwks_server)
    path = _check_path(sub, iat)
    unavailable = (503, "denylist-unavailable")
    cases: dict[str, tuple[dict[str, Any], tuple[int, Any]]] = {
        "floor-above": ({floor_key(sub): iat + 1}, (200, {"active": False})),
        "floor-equal": ({floor_key(sub): iat}, (200, {"active": True})),
        "floor-below": ({floor_key(sub): iat - 1}, (200, {"active": True})),
        "floor-above-sub-below": (
            {floor_key(sub): iat + 100, sub_key(sub): iat - 5},
            (200, {"active": False, "nbf": iat - 5}),
        ),
        "floor-not-integer": ({floor_key(sub): "not-a-number"}, unavailable),
        "floor-decimal": ({floor_key(sub): "12.5"}, unavailable),
        "floor-negative": ({floor_key(sub): "-5"}, unavailable),
        "floor-padded": ({floor_key(sub): " 12 "}, unavailable),
        "floor-plus": ({floor_key(sub): "+7"}, unavailable),
        "floor-underscore": ({floor_key(sub): "1_000"}, unavailable),
        "floor-empty": ({floor_key(sub): ""}, unavailable),
        "floor-20-digits": ({floor_key(sub): "1" + "0" * 19}, unavailable),
        "floor-zero": ({floor_key(sub): "0"}, (200, {"active": True})),
        "floor-19-digits": ({floor_key(sub): "1" + "0" * 18}, (200, {"active": False})),
    }
    outcomes: dict[str, tuple[int, Any]] = {}
    caching: dict[str, str | None] = {}
    for case, (keys, _) in cases.items():
        ia73_df_admin.delete(floor_key(sub), sub_key(sub))
        for key, value in keys.items():
            ia73_df_admin.set(key, value, ex=FLOOR_TTL_S)
        response = send(client, "get", path, headers)
        outcomes[case] = _outcome(response)
        caching[case] = response.get("Cache-Control")

    wrong = {case: got for case, got in outcomes.items() if got != cases[case][1]}
    assert wrong == {}
    cacheable = {case: value for case, value in caching.items() if value != NO_STORE}
    assert cacheable == {}


def test_ia_30_a_first_lookup_failure_skips_floor(
    jwks_server: JwksInfo, settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ia-30 (a) — `session_floor.read_floor`를 가로채 센다(가로채기는 새 서명 `read_floor(sub, sid=None)` → (하한, 세션 단위
    하한) 튜플을 따른다 — UD-7a(ㄴ) · 이음매는 그대로 모듈 속성): 정상 요청(sid 질의 있음) → 200 · 1회 · 인자 (sub, sid)(뷰가 sid를
    넘긴다 — 가로채기가 호출 지점에 닿는다) / DRAGONFLY_URL = 블랙홀 포트 → 503 denylist_unavailable · 하한 조회 0회(첫 조회가
    실패하면 둘째를 하지 않는다) · 경과 1 s 미만. 뷰 모듈을 덮기 전에 먼저 적재한다 — import 때 `read_floor`를 이름으로 묶는
    구현(이음매 규칙 위반)이 덮은 함수를 묶어 정상 요청의 1회 단언을 공허하게 지나지 않게(노드 단독 실행에서는 첫 요청이 urlconf를
    처음 적재한다). 두 응답(200 · 거부 목록 조회 실패의 503) 모두 `Cache-Control: no-store`(R1)."""
    impl("identity_api")
    floor_module = impl("session_floor")
    original = floor_module.read_floor
    calls: list[tuple[str, str | None]] = []

    def counting(sub: str, sid: str | None = None) -> Any:
        calls.append((sub, sid))
        return original(sub, sid)

    monkeypatch.setattr(floor_module, "read_floor", counting)
    client = Client()
    headers = auth_headers(jwks_server)
    path = _check_path("first-fail-sub", int(time.time()), "first-fail-sid")
    normal_response = send(client, "get", path, headers)
    normal = _outcome(normal_response)
    normal_calls = list(calls)
    with blackhole() as port:
        url, _ = _pod_like_url(port)
        settings.DRAGONFLY_URL = url
        response, elapsed = timed(lambda: client.get(path, headers=headers), HANG_LIMIT_S)
    down_calls = len(calls) - len(normal_calls)
    caching = (normal_response.get("Cache-Control"), response.get("Cache-Control"))

    assert (normal, normal_calls) == ((200, {"active": True}), [("first-fail-sub", "first-fail-sid")])
    assert_problem(response, 503, "denylist_unavailable")
    assert down_calls == 0
    assert elapsed < VERDICT_LIMIT_S, f"판정 {elapsed:.3f} s"
    assert caching == (NO_STORE, NO_STORE)


def test_ia_30_b_floor_lookup_failure_is_503(
    jwks_server: JwksInfo,
    dragonfly: DragonflyInfo,
    monkeypatch: pytest.MonkeyPatch,
    log_lines: LogLines,
) -> None:
    """ia-30 (b) — 거부 목록 조회는 되고 하한 조회만 실패한다(`denylist_writer.client`를 덮어 진짜 `client()`가 닫힌 포트 ·
    블랙홀 · 쿼리가 든 URL의 클라이언트를 만들게 한다): 각각 503 denylist_unavailable · 경과 1 s 미만 · WARNING
    `session_floor.lookup_failed` 한 줄(error = 예외 클래스 이름) · 그 요청의 로그 줄 전부와 응답에 sub · 호스트:포트 ·
    비밀번호 없음 · 503 응답에 `Cache-Control: no-store`(R1) / 양성 대조: 덮기 전 같은 Client · 같은 질의 → 200."""
    writer = impl("denylist_writer")
    real_client = writer.client
    sub = "floor-down-sub"
    client = Client()
    headers = auth_headers(jwks_server)
    path = _check_path(sub, int(time.time()))
    normal = _outcome(send(client, "get", path, headers))
    pod_password = Secret(urlsplit(dragonfly.pod_url).password or "")
    with blackhole() as hole:
        closed_url, closed_password = _pod_like_url(closed_port())
        hole_url, hole_password = _pod_like_url(hole)
        targets = {
            "closed-port": (closed_url, closed_password),
            "blackhole": (hole_url, hole_password),
            "url-query": (Secret(f"{dragonfly.pod_url}?socket_timeout=5"), pod_password),
        }
        observed: dict[str, tuple[HttpResponse, float, list[dict[str, Any]]]] = {}
        for case, (url, _) in targets.items():
            monkeypatch.setattr(writer, "client", _client_for(real_client, url))
            log_lines()
            response, elapsed = timed(lambda: client.get(path, headers=headers), HANG_LIMIT_S)
            observed[case] = (response, elapsed, log_lines())

    assert normal == (200, {"active": True})
    verdicts = {case: _outcome(response) for case, (response, _, _) in observed.items()}
    wrong = {case: got for case, got in verdicts.items() if got != (503, "denylist-unavailable")}
    seen, expected_cases = sorted(verdicts), sorted(targets)
    assert (seen, wrong) == (expected_cases, {})
    slow = {case: round(elapsed, 3) for case, (_, elapsed, _) in observed.items() if elapsed >= VERDICT_LIMIT_S}
    assert slow == {}
    cacheable = {
        case: value
        for case, (response, _, _) in observed.items()
        if (value := response.get("Cache-Control")) != NO_STORE
    }
    assert cacheable == {}
    for case, (response, _, records) in observed.items():
        warned = log_events(records, WARNING_FLOOR)
        count = len(warned)
        assert count == 1, f"{case}: {WARNING_FLOOR} 줄 수 {count}"
        line = warned[0]
        level, error = line.get("level"), line.get("error")
        shape = (level, isinstance(error, str) and error.isidentifier())
        assert shape == ("warning", True), case
        url, password = targets[case]
        parts = urlsplit(url)
        host_port = f"{parts.hostname}:{parts.port}"
        needles = {"sub": sub, "host-port": host_port, "password": password, "scheme": "redis://"}
        line_leaks = _leaks(json.dumps(records), needles)
        response_leaks = _leaks(_response_text(response), needles)
        assert (line_leaks, response_leaks) == ([], []), case


def test_ia_30_b_writer_client_construction_args() -> None:
    """ia-30 (b) 옆(R5 — 설계 D13 「클라이언트」 · 규칙 §Auth): 쓰기 클라이언트의 생성 인자를 정적으로 본다(연결 0 · OS 무관) —
    `socket_timeout` · `socket_connect_timeout` 0.2 · 재시도 0회. `socket_connect_timeout`만 빠지면 연결 상한이 redis-py 기본
    5 s이고 `retry`를 빼면 `from_url` 경로에서는 동작이 같아 보여(기본 0회) 동작 시험으로는 Linux에서 갈리지 않는다."""
    writer = impl("denylist_writer")
    client = writer.client()
    kwargs = client.get_connection_kwargs()
    retry = client.get_retry()
    timeouts = (kwargs.get("socket_timeout"), kwargs.get("socket_connect_timeout"))
    retries = None if retry is None else retry.get_retries()

    assert (timeouts, retries) == ((0.2, 0.2), 0)


# --- ia-31(D29 불변식 3 · D13 — 하한 · revoked:sub는 최댓값) ---------------------------------------------------------------


@DB
def test_ia_31_reverse_commit_keeps_largest_nbf(ia73_df_admin: redis.Redis) -> None:
    """ia-31(역순 커밋) — 같은 sub의 사용자 단위 행 둘을 큰 nbf(지금 + 60)부터 커밋하고 작은 nbf(지금 + 1)를 뒤에 커밋해도
    `revoked:sub` · 하한 값 = 큰 nbf(커밋 뒤 최댓값 조회 — 자기 행 값으로 덮지 않는다) · `revoked:sub` TTL ≤ 330(큰 행의 남은
    수명 약 390 s를 `min(330, …)`이 자른다) · 하한 TTL = 큰 행 기준 ± 5. 과거 nbf 웹훅 사례는 조각 ③-b2가 이 묶음에 더한다."""
    sub = "ia31-sub"
    now = int(time.time())
    bigger, smaller = now + 60, now + 1
    first = _call_record(sub, nbf=bigger)
    after_first = read_int(ia73_df_admin, sub_key(sub))
    second = _call_record(sub, nbf=smaller)
    values = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))
    sub_ttl = read_ttl(ia73_df_admin, sub_key(sub))
    floor_drift = abs(read_ttl(ia73_df_admin, floor_key(sub)) - _floor_ttl_expected(bigger))
    results = (first.after.denylist, second.after.denylist)

    assert (results, after_first) == (("ok", "ok"), bigger)
    assert values == (bigger, bigger)
    assert WRITE_TTL_FLOOR_S <= sub_ttl <= DENYLIST_TTL_S, f"revoked:sub TTL {sub_ttl}"
    assert floor_drift <= FLOOR_TTL_TOLERANCE_S, f"하한 TTL 차이 {floor_drift}"


@DB
def test_ia_31_past_nbf_webhook_keeps_largest(ia73_df_admin: redis.Redis) -> None:
    """ia-31(과거 nbf 웹훅 — 조각 ③-b2): 큰 nbf(지금 + 60)의 사용자 단위 행이 있는 sub에 과거 nbf(지금 - 3600) 웹훅 → 202 · 하한과
    `revoked:sub` 값 = 큰 nbf 그대로(커밋 뒤 최댓값 조회 — 자기 행 값으로 하한을 낮추지 않는다) / 짝: 웹훅 앞에 두 키 = 큰 nbf ·
    웹훅 행은 기록됐다(그 sub의 행 nbf 둘)."""
    sub = "ia31-hook-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    now = int(time.time())
    bigger, past = now + 60, now - 3600
    _call_record(sub, nbf=bigger)
    before = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))
    status = _hook(Client(), sub=sub, nbf=past)[2].status_code
    after = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))

    assert before == (bigger, bigger)
    assert (status, _row_nbf(sub)) == (202, sorted([past, bigger]))
    assert after == (bigger, bigger)


# --- ia-34 · 35(D29 — 백필 꼴 웹훅 · 재전송) -------------------------------------------------------------------------------


@DB
def test_ia_34_backfill_shape_webhook_writes_floor_only(ia73_df_admin: redis.Redis, log_lines: LogLines) -> None:
    """ia-34(D29 · D13): 백필 꼴 웹훅(본문 nbf = 지금 - 3600) → 202 · `revoked:sub` 없음(남은 수명이 1 s 미만 — 보내지 않는다) ·
    하한 = 그 nbf · 하한 TTL = ⌊nbf + 330 + 30 d - DB now⌋ ± 5(약 30 d - 3270 s — 요청 경로의 보존 창은 `expires_at + 30 d`다) ·
    그 요청의 `denylist.set_failed` 0줄(S4 6 — TTL 1 미만 가드를 지운 구현은 키 결과가 같고 이 줄만 다르다 · T098 경보 기준) ·
    그 요청의 WARNING `webhook.nbf_stale` 한 줄(F1 — 본문 nbf가 ⌊created⌋ + 1 - 300보다 작다 · sub_hash · 값은 그대로 기록)."""
    from django_common.observability import sub_hash

    sub = "ia34-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    nbf = int(time.time()) - 3600
    log_lines()
    status = _hook(Client(), sub=sub, nbf=nbf)[2].status_code
    records = log_lines()
    keys = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))
    drift = abs(read_ttl(ia73_df_admin, floor_key(sub)) - _floor_ttl_expected(nbf))
    set_failed = len(log_events(records, SET_FAILED))
    stale = [(line.get("level"), line.get("sub_hash")) for line in log_events(records, NBF_STALE)]
    expected_hash = sub_hash(sub)

    assert (status, keys) == (202, (None, nbf))
    assert drift <= FLOOR_TTL_TOLERANCE_S, f"하한 TTL 차이 {drift}"
    assert set_failed == 0
    assert stale == [("warning", expected_hash)]


@DB
def test_ia_35_webhook_replay_rewrites_no_keys(ia73_df_admin: redis.Redis) -> None:
    """ia-35(D10 · D29): 웹훅 → 202 · 두 키(`revoked:sub` · 하한) = 본문 nbf(짝) → admin이 두 키를 표식 값으로 덮는다 → 같은 바이트
    재전송 → 200 `{}` · 두 키가 표식 값 그대로(재전송은 어떤 키도 다시 쓰지 않는다 — 하한 키 포함)."""
    sub = "ia35-sub"
    insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
    client = Client()
    nbf = int(time.time()) - 2
    _, body, first = _hook(client, sub=sub, nbf=nbf)
    written = (read_int(ia73_df_admin, sub_key(sub)), read_int(ia73_df_admin, floor_key(sub)))
    marks = {sub_key(sub): 111, floor_key(sub): 222}
    for key, value in marks.items():
        ia73_df_admin.set(key, value, ex=FLOOR_TTL_S)
    replayed = _outcome(_replay(client, body))
    kept = {key: read_int(ia73_df_admin, key) for key in marks}

    assert (first.status_code, written) == (202, (nbf, nbf))
    assert replayed == (200, {})
    assert kept == marks


# --- ia-36 · 37(D29 나이 · 미래 iat) -------------------------------------------------------------------------------------


def test_ia_36_check_age_boundary(
    jwks_server: JwksInfo, settings: SettingsWrapper, ia73_df_admin: redis.Redis
) -> None:
    """ia-36(HTTP) — iat = now - 30 d - 5 → `{"active": false}` · iat = now - 30 d + 60 → `{"active": true}`(키 없음).

    판정 순서(R2 — 설계 D8 「③ · ④를 조회 뒤에 두는 까닭」): `revoked:sub`를 그 iat 이하 값(iat - 5)으로 둔 채 같은 나이 초과
    iat → `{"active": false, "nbf": iat - 5}`(응답 nbf는 판정 원인과 무관하다) / DRAGONFLY_URL이 닫힌 포트면 같은 iat →
    503 denylist_unavailable(조회 실패가 나이 판정보다 앞이다). 나이 조건을 조회 앞에서 판정해 곧바로 `{"active": false}`를
    돌려주는 구현은 둘 다에서 갈린다."""
    sub, now = "age-sub", int(time.time())
    client = Client()
    headers = auth_headers(jwks_server)
    older_iat = now - LIFETIME_S - 5
    outcomes = {
        "older": _outcome(send(client, "get", _check_path(sub, older_iat), headers)),
        "younger": _outcome(send(client, "get", _check_path(sub, now - LIFETIME_S + 60), headers)),
    }
    ia73_df_admin.set(sub_key(sub), older_iat - 5, ex=FLOOR_TTL_S)
    with_sub_key = _outcome(send(client, "get", _check_path(sub, older_iat), headers))
    url, _ = _pod_like_url(closed_port())
    settings.DRAGONFLY_URL = url
    lookup_down = _outcome(send(client, "get", _check_path(sub, older_iat), headers))

    assert outcomes == {"older": (200, {"active": False}), "younger": (200, {"active": True})}
    assert with_sub_key == (200, {"active": False, "nbf": older_iat - 5})
    assert lookup_down == (503, "denylist-unavailable")


def test_ia_36_is_active_age_boundary_and_constant() -> None:
    """ia-36(순수 함수 · 상수) — `is_active`(키 없음 · 하한 없음): now - iat = 2,591,999 · 2,592,000 → active · 2,592,001 →
    inactive / `SESSION_ABSOLUTE_LIFETIME is REVOCATION_LOG_RETENTION`이고 값이 30일(purge · 재적용이 같은 상수를 쓰는지는
    ia-33). now는 실제 시계와 먼 고정 값이다(R3 — now 인자를 무시하고 시계를 읽는 구현을 가른다)."""
    floor_module = impl("session_floor")
    record = _record()
    now = FIXED_NOW
    ages = (LIFETIME_S - 1, LIFETIME_S, LIFETIME_S + 1)
    verdicts = {age: floor_module.is_active(record=record, floor=None, iat=now - age, now=now) for age in ages}
    same_object = floor_module.SESSION_ABSOLUTE_LIFETIME is floor_module.REVOCATION_LOG_RETENTION
    retention = floor_module.REVOCATION_LOG_RETENTION

    assert verdicts == {LIFETIME_S - 1: True, LIFETIME_S: True, LIFETIME_S + 1: False}
    assert (same_object, retention) == (True, timedelta(days=30))


def test_ia_37_check_future_iat(
    jwks_server: JwksInfo, settings: SettingsWrapper, ia73_df_admin: redis.Redis, log_lines: LogLines
) -> None:
    """ia-37(HTTP) — iat = now + 120 → `{"active": false}` + WARNING `session_check.iat_in_future` 한 줄(그 요청의 로그 줄
    전부에 iat 값 · sub 없음) / iat = now + 30 → `{"active": true}` · 그 경고 0.

    판정 순서(R2 — 설계 D8): `revoked:sub`를 그 iat 이하 값(now)으로 둔 채 같은 미래 iat → `{"active": false, "nbf": now}`
    (응답 nbf는 판정 원인과 무관하다) / DRAGONFLY_URL이 닫힌 포트면 같은 iat → 503 denylist_unavailable이고 그 요청의
    `session_check.iat_in_future` 경고 0(503이 미래 판정보다 앞이다)."""
    sub, now = "future-sub", int(time.time())
    client = Client()
    headers = auth_headers(jwks_server)
    future_iat = now + 120
    log_lines()
    future = _outcome(send(client, "get", _check_path(sub, future_iat), headers))
    future_records = log_lines()
    near = _outcome(send(client, "get", _check_path(sub, now + 30), headers))
    near_records = log_lines()
    ia73_df_admin.set(sub_key(sub), now, ex=FLOOR_TTL_S)
    with_sub_key = _outcome(send(client, "get", _check_path(sub, future_iat), headers))
    url, _ = _pod_like_url(closed_port())
    settings.DRAGONFLY_URL = url
    log_lines()
    lookup_down = _outcome(send(client, "get", _check_path(sub, future_iat), headers))
    down_records = log_lines()

    assert (future, near) == ((200, {"active": False}), (200, {"active": True}))
    warned = log_events(future_records, WARNING_FUTURE)
    count = len(warned)
    assert count == 1, f"{WARNING_FUTURE} 줄 수 {count}"
    level = warned[0].get("level")
    assert level == "warning"
    future_leaks = _leaks(json.dumps(future_records), {"iat": str(future_iat), "sub": sub})
    assert future_leaks == []
    near_warned = log_events(near_records, WARNING_FUTURE)
    assert near_warned == []
    assert with_sub_key == (200, {"active": False, "nbf": now})
    assert lookup_down == (503, "denylist-unavailable")
    down_warned = log_events(down_records, WARNING_FUTURE)
    assert down_warned == []


def test_ia_37_is_active_future_boundary() -> None:
    """ia-37(순수 함수) — `is_active`(키 없음 · 하한 없음): iat = now + 60 → active · now + 61 → inactive. now는 실제
    시계와 먼 고정 값이다(R3)."""
    floor_module = impl("session_floor")
    record = _record()
    now = FIXED_NOW
    leads = (FUTURE_TOLERANCE_S, FUTURE_TOLERANCE_S + 1)
    verdicts = {lead: floor_module.is_active(record=record, floor=None, iat=now + lead, now=now) for lead in leads}
    assert verdicts == {FUTURE_TOLERANCE_S: True, FUTURE_TOLERANCE_S + 1: False}


# --- ia-39(D12 2단계 · D10 4단계 — nbf 상한은 경로별이다) ---------------------------------------------------------------------


@DB
def test_ia_39_a_webhook_clamps_nbf_to_created(ia73_df_admin: redis.Redis, log_lines: LogLines) -> None:
    """ia-39 (a)(〔Z8〕 · S3): 시험이 정한 `created`로 서명한 웹훅 — 본문 nbf = ⌊created⌋ + 2 · ⌊created⌋ + 86400 · 10^18 → 셋 다
    202이고 응답 · 로그 행 · 세션 하한의 nbf = ⌊created⌋ + 1 · 사례마다 WARNING `webhook.nbf_clamped` 한 줄(그 줄에 원문 sub
    없음 · 10^18은 정수 비교로 관문 앞에서 낮춘다 — 500도 400도 아니다) / 짝: 본문 nbf = ⌊created⌋ + 1 → 202 · 본문 값 그대로 ·
    경고 0. `created`를 시험이 정하므로 판정이 시계에 기대지 않는다.

    F1(과거로 어긋난 nbf — 계약 §웹훅 서명 규약): 본문 nbf = ⌊created⌋ + 1 - 300(경계) → 202 · 값 그대로 · `webhook.nbf_stale` 0줄 /
    ⌊created⌋ + 1 - 301 → 202 · 응답 · 로그 행 · 하한의 nbf가 본문 값 그대로(올려 기록하지 않는다) · `webhook.nbf_stale` 한 줄
    (WARNING · sub_hash · 원문 sub 없음) / ⌊created⌋ - 2(T066 본문의 꼴) · 위의 사례 넷 · nbf 없는 본문 → 0줄. F4(없을 때의 값은
    낮추지 않는다): created = 지금 - 120 · nbf 없음 → 202 · 응답 nbf ∈ [⌊t0⌋ + 1, ⌊t1⌋ + 1](⌊created⌋ + 1이 아니다) ·
    `webhook.nbf_missing` 한 줄 · clamped · stale 0줄. 사례마다 그 요청의 세 경고 수를 (missing, clamped, stale)로 견준다.
    3b2V-1 ②: created = 지금 - 120 기준의 경계 둘 — ⌊created⌋ + 1 - 300 → stale 0줄 · - 301 → 한 줄(문턱이 수신 시각이 아니라
    created 기준임을 결정적으로 가른다)."""
    from django_common.observability import sub_hash

    created_at = datetime.now(UTC)
    old_created = created_at - timedelta(seconds=OLD_CREATED_S)
    ceiling = math.floor(created_at.timestamp()) + 1
    old_ceiling = math.floor(old_created.timestamp()) + 1  # 3b2V-1 ② — 문턱이 created 기준임을 수신 시각과 120 s 떨어진 곳에서 본다
    # case → (created, 본문 nbf(None = 키 없음), 기대 nbf(RECEIVED = 수신 시각 + 1), 기대 경고 수 (missing, clamped, stale))
    cases: dict[str, tuple[datetime, int | None, int | str, tuple[int, int, int]]] = {
        "plus-2": (created_at, ceiling + 1, ceiling, (0, 1, 0)),
        "plus-day": (created_at, ceiling + 86399, ceiling, (0, 1, 0)),
        "huge": (created_at, 10**18, ceiling, (0, 1, 0)),
        "at-ceiling": (created_at, ceiling, ceiling, (0, 0, 0)),
        "t066-shape": (created_at, ceiling - 3, ceiling - 3, (0, 0, 0)),
        "stale-edge": (created_at, ceiling - STALE_S, ceiling - STALE_S, (0, 0, 0)),
        "stale": (created_at, ceiling - STALE_S - 1, ceiling - STALE_S - 1, (0, 0, 1)),
        "missing": (created_at, None, RECEIVED, (1, 0, 0)),
        "missing-old-created": (old_created, None, RECEIVED, (1, 0, 0)),
        "stale-edge-old-created": (old_created, old_ceiling - STALE_S, old_ceiling - STALE_S, (0, 0, 0)),
        "stale-old-created": (old_created, old_ceiling - STALE_S - 1, old_ceiling - STALE_S - 1, (0, 0, 1)),
    }
    stale_cases = ("stale", "stale-old-created")
    client = Client()
    observed: dict[str, tuple[int, Any, list[Any], Any, tuple[int, int, int]]] = {}
    stale_lines: dict[str, list[tuple[Any, Any]]] = {}
    leaked: dict[str, list[str]] = {}
    for case, (created, body_nbf, expected_nbf, _) in cases.items():
        sub = f"ia39a-{case}"
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=sub, role="member")
        log_lines()
        t0 = time.time()
        _, _, response = _hook(client, sub=sub, nbf=body_nbf, created=created.isoformat())
        t1 = time.time()
        records = log_lines()
        answered = json.loads(response.content).get("nbf") if response.status_code == 202 else None
        warned = (NBF_MISSING, NBF_CLAMPED, NBF_STALE)
        missing, clamped, stale = (log_events(records, event) for event in warned)
        observed[case] = (
            response.status_code,
            _nbf_view(answered, expected_nbf, t0, t1),
            [_nbf_view(value, expected_nbf, t0, t1) for value in _row_nbf(sub)],
            _nbf_view(read_int(ia73_df_admin, floor_key(sub)), expected_nbf, t0, t1),
            (len(missing), len(clamped), len(stale)),
        )
        stale_lines[case] = [(line.get("level"), line.get("sub_hash")) for line in stale]
        leaked[case] = _leaks(json.dumps(records), {"sub": sub})
    expected = {
        case: (202, expected_nbf, [expected_nbf], expected_nbf, counts)
        for case, (_, _, expected_nbf, counts) in cases.items()
    }
    expected_stale = {case: [("warning", sub_hash(f"ia39a-{case}"))] if case in stale_cases else [] for case in cases}

    assert observed == expected
    assert stale_lines == expected_stale
    assert leaked == dict.fromkeys(cases, [])


@DB
def test_ia_39_bc_db_clock_only_on_command(
    jwks_server: JwksInfo, monkeypatch: pytest.MonkeyPatch, ia73_df_admin: redis.Redis
) -> None:
    """ia-39 (b) · (c)(〔W14〕 · D26 「이음매」): `revocation.db_now_epoch`를 지금 - 400을 돌려주게 덮고 호출을 센다 —
    (b) `revoke_sessions --sub`(멤버십 있음 · 명령이 있음을 먼저 단언) → CommandError(문구에 거부 사유 `(nbf_future)` — F9 (다)) ·
    로그 행 0 · 호출 1회 이상(가로채기가 명령 관문에 닿는다 — (c)의 양성 대조) / (c) 같은 덮기 아래 `/sessions/revoke`(본인 전체
    로그아웃)와 웹훅 → 둘 다 202 · 호출 0(HTTP 경로는 DB 시계와 견주지 않는다)."""
    revocation = impl("revocation")
    impl("identity_api")  # 뷰 모듈을 덮기 전에 적재한다(③-a 교훈)
    calls: list[int] = []

    def lagging_db_clock() -> int:
        lagged = int(time.time()) - DB_CLOCK_LAG_S
        calls.append(lagged)
        return lagged

    monkeypatch.setattr(revocation, "db_now_epoch", lagging_db_clock)
    for member in ("ia39b-sub", "ia39c-hook"):
        insert_row("tenant_membership", tenant_id=TENANT_A, sub=member, role="member")
    command_present = REVOKE_COMMAND in get_commands()
    refused: str | None = None
    names_reason: bool | None = None
    try:
        call_command(REVOKE_COMMAND, "--sub", "ia39b-sub", stdout=io.StringIO())
    except CommandError as exc:
        refused = type(exc).__name__
        # 괄호 꼴로 찾는다 — 문구의 안내 문장에도 낱말 nbf_future가 있어 맨 낱말로는 관문 code를 가르지 못한다.
        names_reason = "(nbf_future)" in str(exc)
    command_rows = model("session_revocation_log").objects.count()
    command_calls = len(calls)
    client = Client()
    revoke_status = _revoke(
        client, _user_headers(jwks_server, "ia39c-self"), {"all_devices": True, "reason": "logout_all"}
    ).status_code
    hook_status = _hook(client, sub="ia39c-hook", nbf=int(time.time()) - 2)[2].status_code
    http_calls = len(calls) - command_calls

    assert command_present is True
    assert (refused, names_reason, command_rows) == ("CommandError", True, 0)
    assert command_calls >= 1, f"db_now_epoch 호출 {command_calls}"
    assert (revoke_status, hook_status, http_calls) == (202, 202, 0)


# --- ia-42 · 43 · 44(UD-7a(ㄴ) — t086-design.md D15 · 세션 단위 폐기 시각 · 세션 단위 하한) ---------------------------------------


def _device_logout(client: Client, jwks: JwksInfo, sub: str, sid: str) -> int:
    """본인 이 기기 로그아웃(all_devices false · logout · 토큰 sid) 한 번 — 202여야 하고 응답 nbf를 준다(아니면 유한한 실패)."""
    response = _revoke(client, _user_headers(jwks, sub, sid=sid), {"all_devices": False, "reason": "logout"})
    if response.status_code != 202:
        pytest.fail(f"이 기기 로그아웃이 202가 아니다: {response.status_code}", pytrace=False)
    nbf = json.loads(response.content).get("nbf")
    if not isinstance(nbf, int) or isinstance(nbf, bool):
        pytest.fail(f"응답 nbf가 정수가 아니다: {type(nbf).__name__}", pytrace=False)
    return nbf


@DB
def test_ia_42_same_sid_session_after_device_logout_is_active(jwks_server: JwksInfo) -> None:
    """ia-42(UD-7a(ㄴ) — W35 · D15-6) — 이 기기 로그아웃(sid S · 응답 nbf n) 뒤 `/session/check?sub&iat&sid=S`: iat = n − 5 →
    `{"active": false}`(로그아웃 전에 시작한 그 세션) · iat = n → `{"active": true}`(값 = iat는 통과) · iat = n + 3 →
    `{"active": true}`(로그아웃 뒤 같은 Authentik 세션 — 같은 sid — 로 다시 로그인해 시작한 BFF 세션). 존재 판정(이전 값 1)은
    330 s 동안 셋 다 inactive였다(W35 — t073-design.md:2532). 응답에 nbf 키가 없다(revoked:sub가 없다)."""
    sub, sid = "ia42-sub", "ia42-sid"
    client = Client()
    n = _device_logout(client, jwks_server, sub, sid)
    headers = auth_headers(jwks_server)
    outcomes = {
        offset: _outcome(send(client, "get", _check_path(sub, n + offset, sid), headers)) for offset in (-5, 0, 3)
    }

    assert outcomes == {-5: (200, {"active": False}), 0: (200, {"active": True}), 3: (200, {"active": True})}


@DB
def test_ia_43_sid_floor_alone_keeps_device_logout_final(jwks_server: JwksInfo, ia73_df_admin: redis.Redis) -> None:
    """ia-43(UD-7a(ㄴ) — E13 · T-c) — 이 기기 로그아웃(sid S · nbf n) 뒤 `revoked:sid:S`를 지운다(330 s가 지난 꼴 — RFC 7009가
    실패해 refresh가 살아 있는 복사 쿠키): 세션 단위 하한 `identity-admin:sid-floor:S`만으로 iat = n − 5 → `{"active": false}` ·
    iat = n → `{"active": true}`(하한 = iat는 통과) / 대조: 하한 키까지 지우면 iat = n − 5 → `{"active": true}`(앞의 inactive가 하한
    키에서 왔다)."""
    sub, sid = "ia43-sub", "ia43-sid"
    client = Client()
    n = _device_logout(client, jwks_server, sub, sid)
    headers = auth_headers(jwks_server)
    ia73_df_admin.delete(sid_key(sid))
    floor_only = {
        offset: _outcome(send(client, "get", _check_path(sub, n + offset, sid), headers)) for offset in (-5, 0)
    }
    ia73_df_admin.delete(sid_floor_key(sid))
    without_floor = _outcome(send(client, "get", _check_path(sub, n - 5, sid), headers))

    assert floor_only == {-5: (200, {"active": False}), 0: (200, {"active": True})}
    assert without_floor == (200, {"active": True})


def test_ia_44_sid_floor_value_canonical_or_503(
    jwks_server: JwksInfo, ia73_df_admin: redis.Redis, monkeypatch: pytest.MonkeyPatch, log_lines: LogLines
) -> None:
    """ia-44(UD-7a(ㄴ) — D15-2 「값 판독」) — 세션 단위 하한 값은 정규 꼴(ASCII 숫자 1-19자)만 판정에 쓴다: `-5` · `x` · 20자리 →
    503 denylist_unavailable(int()로 읽으면 음수가 「하한 없음」처럼 통과한다) · 사례마다 WARNING `session_floor.lookup_failed`
    한 줄 · `Cache-Control: no-store` / sid 질의가 없는 요청은 그 키를 보지 않는다(값이 `-5`여도 200 active) / 양성: 정규 꼴 값
    iat + 1 → `{"active": false}` / 첫 조회 실패면 하한 조회 0: `revoked:sid:S` 값이 정규 꼴이 아니면(`x`) 거부 목록 조회가
    503이고 `session_floor.read_floor` 호출 0회(가로채기는 인자를 그대로 넘긴다 — 서명과 무관하게 센다)."""
    sub, sid, iat = "ia44-sub", "ia44-sid", int(time.time())
    client = Client()
    headers = auth_headers(jwks_server)
    with_sid, without_sid = _check_path(sub, iat, sid), _check_path(sub, iat)
    unavailable = (503, "denylist-unavailable")
    cases = {"negative": "-5", "word": "x", "20-digits": "1" + "0" * 19}
    outcomes: dict[str, tuple[int, Any]] = {}
    caching: dict[str, str | None] = {}
    warned: dict[str, int] = {}
    for case, value in cases.items():
        ia73_df_admin.set(sid_floor_key(sid), value, ex=FLOOR_TTL_S)
        log_lines()
        response = send(client, "get", with_sid, headers)
        warned[case] = len(log_events(log_lines(), WARNING_FLOOR))
        outcomes[case] = _outcome(response)
        caching[case] = response.get("Cache-Control")
    ia73_df_admin.set(sid_floor_key(sid), "-5", ex=FLOOR_TTL_S)
    sidless = _outcome(send(client, "get", without_sid, headers))
    ia73_df_admin.set(sid_floor_key(sid), iat + 1, ex=FLOOR_TTL_S)
    canonical = _outcome(send(client, "get", with_sid, headers))
    impl("identity_api")
    floor_module = impl("session_floor")
    original = floor_module.read_floor
    calls: list[tuple[Any, ...]] = []

    def counting(*args: Any, **kwargs: Any) -> Any:
        calls.append(args)
        return original(*args, **kwargs)

    monkeypatch.setattr(floor_module, "read_floor", counting)
    ia73_df_admin.delete(sid_floor_key(sid))
    ia73_df_admin.set(sid_key(sid), "x", ex=FLOOR_TTL_S)
    first_failed = _outcome(send(client, "get", with_sid, headers))
    floor_calls = len(calls)

    assert outcomes == dict.fromkeys(cases, unavailable)
    assert warned == dict.fromkeys(cases, 1)
    assert caching == dict.fromkeys(cases, NO_STORE)
    assert sidless == (200, {"active": True})
    assert canonical == (200, {"active": False})
    assert (first_failed, floor_calls) == (unavailable, 0)
