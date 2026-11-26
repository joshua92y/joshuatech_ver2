"""identity-admin 업무 엔드포인트(T073 — pod 소유 새 파일) — Ninja Router 하나(identity_router)를 api.py가 루트에 단다.

정본: contracts/identity-admin-api.md §엔드포인트 · §인증 계층 구현 규약 · §오류 슬러그 · contracts/denylist.md §조회 규약 ·
data-model.md §1 · §2 · §3 · 설계 D8(`/session/check`) · D9(`/sessions/revoke`) · D11(`/tenants/me`) · D12(기록 공통) ·
D28(반환 규칙) · D29(세션 하한 · 절대 수명).

- 인증은 미들웨어가 URL 해석 전에 판정한다. `/session/check`는 Access 전용 경로(`request.access_claims`만 — Bearer · 미들웨어
  거부 목록 조회 · 테넌트 컨텍스트 없음)이고, `/sessions/revoke` · `/tenants/me`는 전체 체인(`request.auth_claims` ·
  `request.tenant_id` · 미들웨어 durable 요청 트랜잭션)이다.
- 뷰는 dict를 돌려준다(ninja 1.7.0 반환 규칙 — 선언 스키마의 하위 클래스 인스턴스 금지 · 200이 아닌 응답은 `Status` · 설계 D28).
  오류는 RFC 9457(`problem_response` · `DenylistUnavailable.to_response()` — HttpError(503)은 api.py 표 밖이라 500이 되므로 쓰지
  않는다).
- 이음매(설계 D26): `session_floor.read_floor` · `session_floor.is_active` · `revocation.record_revocation` ·
  `revocation.valid_identifier` · `revocation.event_already_recorded` · `revocation.membership_tenant`는 모듈 속성으로
  부른다(`from … import`로 묶지 않는다 — 시험이 덮은 속성을 호출 지점이 보아야 한다). Celery 앱 · 작업은 가져오지
  않는다(migrate 프로필의 celery 미import 불변식 — 위임 enqueue는 revocation의 커밋 뒤 콜백 안에서 앱을 가져온다).

`GET /session/check`(설계 D8 — 순서 고정)
1. 질의 검증(Query[CheckQuery] — `sub` · `sid`는 출력 가능 ASCII `!`-`~` 1-255자 · `iat`은 정수): 어기면 400 validation_error
   (조회 앞 — `Denylist.lookup`은 빈 값에 ValueError다).
2. 모듈 수준 `_DENYLIST`(하나 — 클라이언트를 URL별로 둔다) 로 거부 목록 조회: 실패(정규 꼴이 아닌 `revoked:*` 값 포함 —
   UD-7a 보정)면 503 denylist_unavailable이고 3단계를 하지 않는다(api-8의 0.5 s 상한).
3. 세션 하한 조회(`session_floor.read_floor(sub, sid)` — 쓰기 클라이언트 · 파이프라인 1회로 사용자 단위 하한 + sid가 있으면 세션
   단위 하한 · 0.2 s · 재시도 0 — UD-7a(ㄴ) T-c): 실패 · 어느 값이든 정규 꼴(ASCII 숫자 1-19자)이 아니면 503
   denylist_unavailable(fail-closed · DB로 메우지 않는다).
4. 판정(`session_floor.is_active` — 거부 목록 · 두 하한 · 나이 · 미래 iat · now = pod 시계 int(time.time())). iat가 now + 60 s를
   넘으면 WARNING `session_check.iat_in_future`(값 · sub 없음).
5. 응답 `{"active": …, "nbf": revoked:sub 값}` — nbf는 그 키가 있을 때만 실린다(exclude_none · 판정 원인과 무관 · revoked:sid ·
   두 하한 값은 싣지 않는다).
DB 접근은 0이다(Dragonfly 왕복 2회). 뷰가 만드는 응답(200 · 503)에는 `Cache-Control: no-store`를 단다(200은 Ninja가 넘긴 임시
응답 객체에 · 503은 직접 돌려주는 응답에 — 400은 템플릿 검증 처리기 몫이라 손대지 않는다).

`POST /sessions/revoke`(설계 D9 — 순서 고정 · 4xx 판정은 모두 쓰기 앞: 4xx 응답도 요청 트랜잭션이 커밋된다)
1. 본문 RevokeIn(`sub` · `sid` = 출력 가능 ASCII 1-255자 또는 없음 · `all_devices` StrictBool 필수 · `reason` Literal 3값 필수):
   어기면 400 validation_error.
2. 호출자 = 토큰 `sub` · 대상 = 본문 `sub` 또는 호출자 · 본인 = 대상 == 호출자 · 관리자 = `groups`가 list이고 원소 하나가 정확히
   `platform-admin`.
3. 본인도 관리자도 아니면 403 forbidden.
4. 조합: 본인은 (logout, false) · (logout_all, true)만 · 본인이 아니면 reason admin만 — 어기면 400.
5. 대상 sub의 문자 규칙(본인이면 토큰에서 온 값 — JSON 문자열은 NUL도 담는다) → tenant: 본인은 요청 테넌트 컨텍스트, 본인이
   아니면 `revocation.membership_tenant(대상)`(0건 None → 400 · 여럿이면 `tenant_id`가 가장 작은 행 + WARNING
   `identity.multiple_memberships` count · sub_hash — 웹훅 · 관리 명령과 같은 함수 하나).
6. sid: all_devices면 None(본문 sid 무시). 아니면 본문 sid → (본인일 때만) 토큰 sid · 없거나 문자 규칙 위반이면 400.
7. nbf = ⌊time.time()⌋ + 1 · 8. `revocation.record_revocation`(source revoke · admin · delegate = all_devices — 이 경로에는
   nbf 상한 비교가 없다) · 9. `Status(202, {id, nbf, expires_at})`. 요청 처리 중 Authentik 호출은 0이다(위임은 커밋 뒤 콜백의
   enqueue — 작업 본체는 워커).

`POST /webhooks/authentik`(설계 D10 — 순서 고정 · 면제 경로: 미들웨어는 Host · 자격을 보지 않고 요청 트랜잭션도 없다 —
`record_revocation`의 atomic이 가장 바깥이다). Ninja operation은 본문 파라미터 없이 선언한다(서명 검증 전에 Ninja가 본문을 파싱하면
400이 먼저 나간다 — T066 가정 ⑦).
1. `request.get_host()`를 먼저 부른다(밖 Host는 DisallowedHost → handler400 400 invalid_host — 서명보다 앞).
2. `verify_authentik_webhook(request.body, X-Authentik-Signature, secret=AUTHENTIK_WEBHOOK_SECRET)` — 실패는 401
   webhook_signature_invalid(`to_response()`).
3. action: 없거나 str가 아니면 400. `logout` · `session_deleted`가 아니면 200 `{}` — 본문의 다른 필드(sub · nbf · pk)를 보지 않는다.
4. sub → pk 차례로 출력 가능 ASCII 1-255자(`revocation.valid_identifier` — ORM 조회 앞) · nbf는 있으면 0 이상 정수(bool
   제외)여야 한다(어기면 400 · JSON null은 없는 것으로 읽는다). nbf가 `⌊created⌋ + 1`(created = 서명 검증이 읽은 본문 created)을
   넘으면 거부하지 않고 그 값으로 낮추고 WARNING `webhook.nbf_clamped`(정수끼리 견준다 — 큰 정수의 datetime 변환 앞). 그 이하이되
   `⌊created⌋ + 1 - WEBHOOK_NBF_STALE_S`보다 작으면 값은 그대로 두고 WARNING `webhook.nbf_stale`(열림 쪽 매핑 회귀의 신호). nbf가
   없으면 `⌊수신 시각⌋ + 1`과 WARNING `webhook.nbf_missing`(이 값에는 비교를 하지 않는다). 세 경고는 세 필드가 다 맞은 뒤 이
   단계에서 남긴다(기록되지 않는 재전송 · 멤버십 없음에서도 — `_webhook_nbf`).
5. pk 정규형(`revocation.normalize_event_pk` — UUID로 읽히는 값은 대시 소문자)이 이미 기록돼 있으면 200 `{}`(멤버십 조회 앞 —
   재전송은 늘 멱등이다 · 어떤 키도 다시 쓰지 않는다).
6. tenant = `revocation.membership_tenant(sub)` — 0건이면 400 · 여럿이면 가장 작은 tenant_id + WARNING.
7. `revocation.record_revocation(reason="authentik_webhook", sid=None, event_pk=pk, delegate=False, source="webhook")` —
   Replayed(INSERT 경합)면 200 `{}` · Recorded면 `Status(202, {id, nbf, expires_at})`. 관문의 거부(RevocationRejected)는 400
   validation_error(4단계가 같은 규칙을 먼저 거르는 심층 방어). DB 시계와 견주지 않는다(설계 W14). 본문 sid는 쓰지 않는다(항상
   사용자 단위). Authentik 세션 삭제 위임은 하지 않는다(출처가 Authentik이다).
서명 검증 뒤의 400(3 · 4 · 6 · 7단계)은 반환 직전에 값 없는 사유 한 줄 `webhook.rejected`(필드 `reason` = action · sub · pk ·
nbf · membership · gate)를 남긴다 — membership은 INFO(dev · prod가 한 Authentik을 써 모르는 sub의 400은 정상 소음이다), 나머지는
WARNING. `sub_hash`는 sub가 문자 규칙을 지난 갈래(pk · nbf · membership · gate)에만 싣고, gate는 `error` = 관문의 code를 더한다.
401 · 200 · 202에는 남기지 않는다(계약 §웹훅 서명 규약 · §관측).

`GET /tenants/me`(설계 D11): 토큰의 sub와 테넌트 컨텍스트(request.tenant_id) 둘 다 맞는 멤버십 → 그 tenant_id의 Tenant. 멤버십이
없거나 Tenant 행이 없으면(고아 멤버십) 404 not_found. 응답 `{tenant: {id, slug, display_name, status}, role}`.
"""

from __future__ import annotations

import math
import time
import uuid
from datetime import datetime
from typing import Any, Literal

import structlog
from django.conf import settings
from django.http import HttpRequest, HttpResponse
from django_common.auth import Denylist, DenylistUnavailable, WebhookSignatureInvalid, verify_authentik_webhook
from django_common.observability import sub_hash
from django_common.problem import problem_response
from ninja import Query, Router, Schema, Status
from pydantic import Field, StrictBool

from identity_admin import revocation, session_floor
from identity_admin.models import Tenant, TenantMembership

__all__ = [
    "CheckOut",
    "CheckQuery",
    "RevokeIn",
    "RevokeOut",
    "TenantMeOut",
    "WebhookNoopOut",
    "identity_router",
]

# 출력 가능 ASCII(공백 · 제어 문자 · 비ASCII 없음 · 1-255자 — 설계 D8 1단계). pydantic 기본 정규식 엔진(Rust regex)의 `$`는 입력
# 끝에서만 맞는다(Python re와 달리 끝 줄바꿈 앞에서 맞지 않는다 — ia-1의 `%0A` 사례가 지킨다).
IDENTIFIER_PATTERN = r"^[!-~]+$"
IDENTIFIER_MAX_LENGTH = 255
NO_STORE = "no-store"  # `/session/check` 응답(200 · 503)의 Cache-Control — 폐기 판정은 어느 층에서도 저장하지 않는다
ADMIN_GROUP = "platform-admin"  # 관리자 판정 — Bearer `groups`가 목록이고 원소 하나가 정확히 이 값(부분 일치 금지)
WEBHOOK_SIGNATURE_HEADER = "X-Authentik-Signature"  # contracts/identity-admin-api.md §웹훅 서명 규약
REVOKING_ACTIONS = frozenset({"logout", "session_deleted"})  # 폐기 action(둘 다 reason authentik_webhook) — 그 밖은 200 no-op
WEBHOOK_NBF_STALE_S = 300  # 웹훅 시각 창의 폭 — 본문 nbf가 ⌊created⌋ + 1 - 이 값보다 작으면 WARNING webhook.nbf_stale
WEBHOOK_REJECTED = "webhook.rejected"  # 서명 검증 뒤 400의 사유 줄(값 없음)

log = structlog.get_logger(__name__)
identity_router = Router()
_DENYLIST = Denylist()  # 모듈 수준 하나(생성은 연결하지 않는다 — 클라이언트는 인스턴스 안에 URL별로 둔다)


class CheckQuery(Schema):
    """`/session/check` 질의 — sub(필수) · iat(필수 정수 epoch 초 — BFF 세션 시작 시각) · sid(선택 · `sid=`는 400)."""

    sub: str = Field(min_length=1, max_length=IDENTIFIER_MAX_LENGTH, pattern=IDENTIFIER_PATTERN)
    iat: int
    sid: str | None = Field(default=None, min_length=1, max_length=IDENTIFIER_MAX_LENGTH, pattern=IDENTIFIER_PATTERN)


class CheckOut(Schema):
    """`/session/check` 응답 — nbf(revoked:sub 값)는 그 키가 있을 때만 싣는다(active여도 싣는다)."""

    active: bool
    nbf: int | None = None


class RevokeIn(Schema):
    """`/sessions/revoke` 본문 — sub · sid(선택 · 출력 가능 ASCII 1-255자) · all_devices(필수 boolean) · reason(필수)."""

    sub: str | None = Field(default=None, min_length=1, max_length=IDENTIFIER_MAX_LENGTH, pattern=IDENTIFIER_PATTERN)
    sid: str | None = Field(default=None, min_length=1, max_length=IDENTIFIER_MAX_LENGTH, pattern=IDENTIFIER_PATTERN)
    all_devices: StrictBool
    reason: Literal["logout", "logout_all", "admin"]


class RevokeOut(Schema):
    """`/sessions/revoke` · `/webhooks/authentik` 202 응답 — id(로그 행) · nbf(epoch 초) · expires_at(UTC = nbf + 330 s)."""

    id: uuid.UUID
    nbf: int
    expires_at: datetime


class WebhookNoopOut(Schema):
    """웹훅 200 응답 — 빈 객체(폐기 대상이 아닌 action · 재전송)."""


class TenantOut(Schema):
    id: uuid.UUID
    slug: str
    display_name: str
    # 값은 models.TENANT_STATUSES와 함께 고친다 — 한쪽만 바뀌면 `/tenants/me`가 응답 검증에서 500이다(ia-21 옆 정적 노드).
    status: Literal["active", "suspended"]


class TenantMeOut(Schema):
    """`/tenants/me` 응답."""

    tenant: TenantOut
    # 값은 models.MEMBERSHIP_ROLES와 함께 고친다 — 한쪽만 바뀌면 `/tenants/me`가 응답 검증에서 500이다(ia-21 옆 정적 노드).
    role: Literal["owner", "member"]


def _no_store(response: HttpResponse) -> HttpResponse:
    """폐기 판정 응답을 어느 층에서도 저장하지 않게 한다(계약 `/session/check` 행 — 200 · 503)."""
    response["Cache-Control"] = NO_STORE
    return response


@identity_router.get("/session/check", response={200: CheckOut}, exclude_none=True)
def session_check(
    request: HttpRequest, query: Query[CheckQuery], response: HttpResponse
) -> dict[str, Any] | HttpResponse:
    """세션 활성 판정(BFF · Access 전용) — 거부 목록 · 세션 하한 · 절대 수명 · 미래 iat."""
    # 세션 하한은 사용자 단위 + 세션 단위 둘이다(UD-7a(ㄴ) — 위 독스트링은 OpenAPI 설명이라 스냅샷과 함께만 바꾼다)
    try:
        record = _DENYLIST.lookup(query.sub, query.sid)
    except DenylistUnavailable as exc:
        return _no_store(exc.to_response())
    try:
        floor, sid_floor = session_floor.read_floor(query.sub, query.sid)
    except DenylistUnavailable as exc:
        return _no_store(exc.to_response())
    now = int(time.time())
    if query.iat > now + session_floor.FUTURE_IAT_TOLERANCE_S:
        log.warning("session_check.iat_in_future")
    active = session_floor.is_active(record=record, floor=floor, sid_floor=sid_floor, iat=query.iat, now=now)
    _no_store(response)  # Ninja가 넘긴 임시 응답 — 200 본문이 이 객체에 실린다(헤더가 그대로 남는다)
    return {"active": active, "nbf": record.sub_nbf}


@identity_router.post("/sessions/revoke", response={202: RevokeOut})
def sessions_revoke(request: HttpRequest, body: RevokeIn) -> Status[dict[str, Any]] | HttpResponse:
    """세션 폐기(본인 · platform-admin) — 202는 기록 커밋(거부 목록 쓰기 · Authentik 세션 삭제 위임은 커밋 뒤)."""
    claims: dict[str, Any] = request.auth_claims  # type: ignore[attr-defined]
    caller = claims["sub"]  # 2. 호출자 판정
    target = body.sub if body.sub is not None else caller
    is_self = target == caller
    groups = claims.get("groups")
    is_admin = isinstance(groups, list) and any(group == ADMIN_GROUP for group in groups)  # 원소 정확 일치만
    if not is_self and not is_admin:  # 3
        return problem_response("forbidden", 403)
    if is_self:  # 4. 조합(403 뒤 — api-16)
        combination_ok = (body.reason, body.all_devices) in {("logout", False), ("logout_all", True)}
    else:
        combination_ok = body.reason == "admin"
    if not combination_ok:
        return problem_response("validation_error", 400)
    if not revocation.valid_identifier(target):  # 쓰기에 들어가는 sub — 토큰에서 온 값(본인)도 같은 문자 규칙
        return problem_response("validation_error", 400)
    if is_self:  # 5. tenant 결정
        tenant_id: uuid.UUID = request.tenant_id  # type: ignore[attr-defined]
    else:
        member_tenant = revocation.membership_tenant(target)  # 웹훅 · 관리 명령과 같은 규칙(0건 None · 여럿이면 WARNING)
        if member_tenant is None:
            return problem_response("validation_error", 400)
        tenant_id = member_tenant
    sid: str | None = None  # 6. sid 결정 — all_devices면 본문 sid를 쓰지 않는다
    if not body.all_devices:
        sid = body.sid if body.sid is not None else (claims.get("sid") if is_self else None)
        if sid is None or not revocation.valid_identifier(sid):
            return problem_response("validation_error", 400)
    nbf = math.floor(time.time()) + 1  # 7. 처리 시각 내림 + 1(같은 초에 발급된 토큰도 nbf > iat)
    recorded = revocation.record_revocation(  # 8
        tenant_id=tenant_id,
        sub=target,
        sid=sid,
        reason=body.reason,
        nbf=nbf,
        source="revoke" if is_self else "admin",
        delegate=body.all_devices,
    )
    if not isinstance(recorded, revocation.Recorded):  # event_pk 없는 기록은 재전송이 될 수 없다(관문 밖의 결함)
        raise RuntimeError("revoke 기록이 Recorded가 아니다")
    return Status(202, {"id": recorded.id, "nbf": recorded.nbf, "expires_at": recorded.expires_at})  # 9


def _webhook_nbf(data: dict[str, Any], created: datetime, sub: str) -> int | None:
    """웹훅 본문의 nbf(설계 D10 4단계 · 계약 §웹훅 서명 규약) — 0 이상 정수가 아니면 None(400 · bool · 실수 · 문자열).
    - 없으면(키 없음 또는 JSON null) ⌊수신 시각⌋ + 1 · WARNING webhook.nbf_missing — 이 값에는 아래 비교를 하지 않는다.
    - ⌊created⌋ + 1을 넘으면 그 값으로 낮춘다 · WARNING webhook.nbf_clamped(거부하지 않는다 · 정수끼리 견준다).
    - ⌊created⌋ + 1 - WEBHOOK_NBF_STALE_S보다 작으면 본문 값 그대로 · WARNING webhook.nbf_stale(올려 기록하지 않는다 — 그 값보다
      뒤에 시작한 세션은 이 로그아웃으로 끊기지 않고 pk가 기록돼 일 1회 대조도 고치지 못한다: 열림 쪽 매핑 회귀의 신호).
    세 경고는 본문 꼴 판정(4단계)에서 남긴다 — 재전송(200)과 멤버십 없는 sub(400)처럼 기록되지 않는 요청에서도 남는다(매핑 회귀의
    신호는 기록 여부와 무관하다)."""
    nbf = data.get("nbf")
    if nbf is None:
        log.warning("webhook.nbf_missing", sub_hash=sub_hash(sub))
        return math.floor(time.time()) + 1
    if not isinstance(nbf, int) or isinstance(nbf, bool) or nbf < 0:
        return None
    ceiling = math.floor(created.timestamp()) + 1
    if nbf > ceiling:
        log.warning("webhook.nbf_clamped", sub_hash=sub_hash(sub))
        return ceiling
    if nbf < ceiling - WEBHOOK_NBF_STALE_S:
        log.warning("webhook.nbf_stale", sub_hash=sub_hash(sub))
    return nbf


def _webhook_rejected(reason: str, *, sub: str | None = None, error: str | None = None) -> HttpResponse:
    """서명 검증 뒤의 400 — 값 없는 사유 한 줄 `webhook.rejected` 뒤 validation_error(모듈 독스트링 「POST /webhooks/authentik」 끝
    문단). sub는 문자 규칙을 지난 값만 넘긴다(규칙을 어긴 값은 해시하지 않는다 · str이 아닌 값의 sub_hash는 예외다)."""
    fields: dict[str, str] = {"reason": reason}
    if sub is not None:
        fields["sub_hash"] = sub_hash(sub)
    if error is not None:
        fields["error"] = error
    if reason == "membership":
        log.info(WEBHOOK_REJECTED, **fields)
    else:
        log.warning(WEBHOOK_REJECTED, **fields)
    return problem_response("validation_error", 400)


@identity_router.post("/webhooks/authentik", response={200: WebhookNoopOut, 202: RevokeOut})
def authentik_webhook(request: HttpRequest) -> dict[str, Any] | Status[dict[str, Any]] | HttpResponse:
    """Authentik 로그아웃 웹훅(HMAC 서명 · 시각 창 · pk 멱등) — 사용자 단위 폐기로 기록한다(202 · 재전송과 무시는 200)."""
    request.get_host()  # 1 — 면제 경로라 미들웨어가 Host를 보지 않는다(서명 판정보다 앞)
    try:  # 2
        event = verify_authentik_webhook(
            request.body, request.headers.get(WEBHOOK_SIGNATURE_HEADER), secret=settings.AUTHENTIK_WEBHOOK_SECRET
        )
    except WebhookSignatureInvalid as exc:
        return exc.to_response()
    data = event.data
    action = data.get("action")  # 3
    if not isinstance(action, str):
        return _webhook_rejected("action")
    if action not in REVOKING_ACTIONS:
        return {}
    sub = data.get("sub")  # 4 — 꼴은 조회 앞에서 본다(정수 sub를 str()로 바꿔 찾지 않는다 · NUL은 psycopg DataError)
    if not revocation.valid_identifier(sub):
        return _webhook_rejected("sub")
    if not revocation.valid_identifier(event.pk):
        return _webhook_rejected("pk", sub=sub)
    nbf = _webhook_nbf(data, event.created, sub)
    if nbf is None:
        return _webhook_rejected("nbf", sub=sub)
    event_pk = revocation.normalize_event_pk(event.pk)
    if revocation.event_already_recorded(event_pk):  # 5
        return {}
    tenant_id = revocation.membership_tenant(sub)  # 6
    if tenant_id is None:
        return _webhook_rejected("membership", sub=sub)
    gate_code: str | None = None
    try:  # 7
        recorded = revocation.record_revocation(
            tenant_id=tenant_id,
            sub=sub,
            sid=None,
            reason="authentik_webhook",
            nbf=nbf,
            source="webhook",
            event_pk=event_pk,
            delegate=False,
        )
    except revocation.RevocationRejected as exc:
        gate_code = exc.code
    if gate_code is not None:  # except 블록 밖에서 낸다(관문 code만 싣는다)
        return _webhook_rejected("gate", sub=sub, error=gate_code)
    if not isinstance(recorded, revocation.Recorded):  # Replayed — INSERT 경합(srl_event_pk_uniq)
        return {}
    return Status(202, {"id": recorded.id, "nbf": recorded.nbf, "expires_at": recorded.expires_at})


@identity_router.get("/tenants/me", response={200: TenantMeOut})
def tenants_me(request: HttpRequest) -> dict[str, Any] | HttpResponse:
    """토큰 주체의 테넌트(B 등급 표 둘 · sub와 tenant_id로 명시 필터) — 없거나 고아 멤버십이면 404 not_found."""
    claims: dict[str, Any] = request.auth_claims  # type: ignore[attr-defined]
    tenant_id: uuid.UUID = request.tenant_id  # type: ignore[attr-defined]
    if not revocation.valid_identifier(claims["sub"]):
        # 그런 sub의 멤버십은 어느 경로로도 생길 수 없다(쓰기 경로가 같은 규칙을 지킨다) — 조회하면 NUL이 psycopg DataError(500)다.
        return problem_response("not_found", 404)
    membership = TenantMembership.objects.filter(sub=claims["sub"], tenant_id=tenant_id).first()
    tenant = None if membership is None else Tenant.objects.filter(pk=membership.tenant_id).first()
    if membership is None or tenant is None:
        return problem_response("not_found", 404)
    return {
        "tenant": {"id": tenant.id, "slug": tenant.slug, "display_name": tenant.display_name, "status": tenant.status},
        "role": membership.role,
    }
