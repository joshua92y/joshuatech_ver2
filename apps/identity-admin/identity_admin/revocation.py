"""폐기 기록 공통 관문(T073 설계 D12 — pod 소유 새 파일) — 폐기를 기록하는 모든 경로의 단일 관문과 그 커밋 뒤 콜백.

정본: contracts/identity-admin-api.md §엔드포인트 revoke · 웹훅 · §관리 명령 · §관측 · §오류 슬러그(DB 무결성) ·
contracts/denylist.md §쓰기 규약 · contracts/events.md §발행 API · data-model.md §3 · 설계 D12 · D13 · D16 · D18 · D22 · D25.

record_revocation(*, tenant_id, sub, sid, reason, nbf, source, event_pk=None, delegate=False) -> Recorded | Replayed
  부르는 곳: `/sessions/revoke`(source revoke · admin) · 웹훅(webhook) · 일 1회 대조(reconcile) · 관리 명령(command). 모델에 직접
  INSERT하는 경로를 두지 않는다(하한 · 이벤트 · 로그가 한 행에서 나온다). 차례(설계 D12 1-6 — 순서 그대로):
  0. 전제 검사(트랜잭션 · 쓰기 앞 — ValueError · 문구에 값 없음): `source`가 다섯 값 가운데 하나 · `delegate`면 `sid`가 None
     (위임은 사용자 단위 행에만 붙는다 — 설계 D16 「위임 조건」 · 호출자는 모두 저장소 안이고 시험이 잡는다).
  1. `transaction.atomic()` 안에서 처리한다(revoke는 미들웨어 durable 아래 savepoint · 웹훅 · 대조 · 명령은 가장 바깥).
  2. 관문(쓰기 앞 — 위반은 `RevocationRejected(code)` · 메시지 · 값 없음): sub · sid(있으면) · event_pk(있으면)가 출력 가능
     ASCII 1-255자(`valid_identifier`) · nbf가 0 이상 `NBF_MAX` 이하 정수(bool 제외 · 모든 source — 표현 가능 상한: 큰 정수가
     datetime 변환 · `+ 330 s`에서 OverflowError · OSError(500)로 터지지 않게 · 시계를 보지 않는 정수 비교) · 정책 상한은
     `source == "command"`일 때만 `nbf ≤ db_now_epoch() + 301`(DB 시계 — 정수끼리 · datetime 변환 앞). HTTP 경로는 DB 시계와
     견주지 않는다(설계 W14).
  3. event_pk(정규형)가 이미 기록돼 있으면(`event_already_recorded`) Replayed.
  4. 중첩 atomic 안에서 INSERT — IntegrityError의 제약 이름이 `srl_event_pk_uniq`면 Replayed, 그 밖은
     `RevocationWriteError()`(메시지 없음 · 연쇄 예외 없음 — DETAIL의 행 값이 로그 · Sentry에 실리지 않게).
  5. `tenant_context(tenant_id)` 안에서 `publish_owned("session.revoked", "user:<sub>", {sub, sid, nbf, reason},
     tenant_id=tenant_id)`(data 키 정확히 넷 · 교차 테넌트 · 컨텍스트 없는 경로 모두 같은 꼴).
  6. 커밋 뒤 콜백 하나를 `on_commit(…, robust=True)`로 등록한다 — 값을 담지 않은 지역 함수다(Django robust 실패 로그는 콜백의
     `__qualname__`을 찍고 없으면 객체 repr을 찍는다 · `functools.partial`의 repr은 키워드 인자 값 — 원문 sub · sid — 을 싣는다).
     롤백이면 버려진다(키 · 지표 · 로그 · 위임 0).
  Recorded(id, nbf, expires_at, after) · Replayed(). expires_at = nbf + 330 s(Python에서 만든다 · aware UTC).

membership_tenant(sub) -> uuid.UUID | None: 웹훅 · 관리 명령의 tenant 결정(설계 D12 「다중 멤버십」 · D10 6단계 · D30 2단계) —
0건이면 None · 여럿이면 `tenant_id`가 가장 작은 행(결정적) + WARNING `identity.multiple_memberships`(count · sub_hash). 키가 sub
단위라 폐기 효과는 같다(400으로 막으면 웹훅이 재시도 끝에 폐기를 놓친다). `/sessions/revoke` 관리자 갈래도 이 함수를 부른다(같은
규칙이 이 한 곳에만 있다).

커밋 뒤 콜백 `_after`(단계마다 자기 try/except — 예외 클래스 이름만 남긴다 · Django robust 로그는 예외 문구를 싣는다 · 실패
로그 호출 자신이 던져도 뒤 단계가 돈다)
  ① 거부 목록 · 하한 쓰기(`denylist_writer.apply_user` · `apply_sid`) → after.denylist = ok · skipped · failed · unreachable
  ② 지표 `session_revocations_total{reason}` +1(커밋 뒤에만)
  ③ INFO `session_revocation.recorded`(reason · scope user|session · source · tenant_id · sub_hash · revocation_id)
  ④ delegate면 Authentik 세션 삭제 위임(설계 D16 「위임 조건」 순서 — 쓰기 플래그 → 자리값 자격 → ①의 결과 → enqueue) →
     after.delegate = off · skipped · enqueued · failed(delegate가 거짓이면 None으로 남는다). Celery 앱은 이 단계 안에서
     가져온다(`from identity_admin.celery import app` — 모듈 머리 import 금지: urlconf → identity_api → revocation 사슬은
     migrate 프로필에서도 import되고 템플릿 시험 둘이 그 프로필에서 celery 미import를 고정한다 · 설계 D3 (나) · W22).
  단계의 예상 밖 예외는 WARNING `session_revocation.callback_failed step=<denylist|metric|log|delegate> error=<클래스>`다.

이음매(설계 D26 — 이 모듈 안에서도 모듈 전역 이름으로 부른다: 시험이 모듈 속성을 덮으면 호출 지점이 그것을 본다 · 웹훅 뷰와
관리 명령도 `revocation.<이름>`으로 부른다): `event_already_recorded` · `db_now_epoch` · `denylist_writer.client`(쓰기 모듈 안) ·
`session_floor.REVOCATION_LOG_RETENTION` · `identity_admin.celery.app.send_task`.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta

import structlog
from django.conf import settings
from django.db import IntegrityError, connection, transaction
from django_common.observability import sub_hash
from django_common.tenancy import tenant_context

from identity_admin import conf, denylist_writer, events, identity_metrics
from identity_admin.models import SessionRevocationLog, TenantMembership

__all__ = [
    "DELEGATION_TASK",
    "DELEGATION_WINDOW_S",
    "EVENT_PK_CONSTRAINT",
    "IDENTIFIER_RE",
    "NBF_COMMAND_LEEWAY_S",
    "NBF_MAX",
    "SOURCES",
    "After",
    "Recorded",
    "Replayed",
    "RevocationRejected",
    "RevocationWriteError",
    "db_now_epoch",
    "event_already_recorded",
    "membership_tenant",
    "normalize_event_pk",
    "record_revocation",
    "valid_identifier",
]

IDENTIFIER_RE = re.compile(r"[!-~]{1,255}")  # fullmatch로 쓴다(Python `$`는 끝 줄바꿈 앞에서도 맞는다)
EVENT_PK_CONSTRAINT = "srl_event_pk_uniq"  # 경합 판정에 이름을 쓴다(data-model §3 · 설계 D4)
NBF_COMMAND_LEEWAY_S = 301  # 관리 명령의 nbf 상한 = DB now + 301 s(웹훅 시각 창 +300 s 끝의 매핑 nbf와 같은 여유 · 설계 E6)
# nbf의 표현 가능 상한(epoch 초 · 모든 source) — datetime 변환과 `+ 330 s` · `+ 300 s`(위임 창)가 넘치지 않는 값(약 2286년).
# 정책 상한(관리 명령의 DB 시계 + 301 s)이 아니라, 큰 정수가 거부(400 · CommandError) 대신 500으로 터지지 않게 하는 방어다.
NBF_MAX = 10**10
REVOCATION_TTL = timedelta(seconds=denylist_writer.DENYLIST_TTL_S)  # expires_at = nbf + 330 s
DELEGATION_WINDOW_S = 300  # 위임 창 = nbf + 300 s(메시지 expires — 묵은 위임 · 스냅숏에서 되살아난 메시지를 워커가 버린다)
DELEGATION_TASK = "identity_admin.tasks.revoke_authentik_sessions"  # 이름으로 보낸다(작업 본체는 jobs.py · 설계 D16)
SOURCES = frozenset({"revoke", "admin", "webhook", "reconcile", "command"})
# hex 32자 · 8-4-4-4-12(대소문자 무관) — UUID로 읽히는 event pk의 꼴(그 밖의 값은 정규화하지 않는다 · 설계 D12 〔Y17〕).
_UUID_SHAPE = re.compile(r"[0-9A-Fa-f]{32}|[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")

log = structlog.get_logger(__name__)


class RevocationRejected(ValueError):
    """관문 위반 — code만 싣는다(`sub` · `sid` · `event_pk` · `nbf` · `nbf_future`). 메시지 · 값 없음."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class RevocationWriteError(Exception):
    """event_pk 경합이 아닌 무결성 오류 — 메시지 없는 500(DETAIL의 행 값을 싣지 않는다)."""


@dataclass
class After:
    """커밋 뒤 콜백이 채우는 결과 칸(설계 D12 〔W21〕) — 읽는 쪽은 관리 명령(가장 바깥 atomic이라 돌아오기 전에 찬다)."""

    denylist: str | None = None
    delegate: str | None = None


@dataclass(frozen=True)
class Recorded:
    """기록됨 — 로그 행 id · nbf(epoch 초) · expires_at(aware UTC) · after(커밋 뒤 결과 칸)."""

    id: uuid.UUID
    nbf: int
    expires_at: datetime
    after: After = field(compare=False)


@dataclass(frozen=True)
class Replayed:
    """재전송 — 같은 event_pk가 이미 기록돼 있다(행 · 이벤트 · 키 · 지표 변화 0)."""


def valid_identifier(value: object) -> bool:
    """value가 출력 가능 ASCII(`!`-`~`) 1-255자인 str인가(sub · sid · event_pk의 문자 규칙)."""
    return isinstance(value, str) and IDENTIFIER_RE.fullmatch(value) is not None


def normalize_event_pk(value: str) -> str:
    """event pk의 정규형 — UUID로 읽히는 값(hex 32자 · 8-4-4-4-12)은 대시 소문자, 그 밖의 값은 그대로."""
    if _UUID_SHAPE.fullmatch(value) is None:
        return value
    return str(uuid.UUID(value))


def event_already_recorded(event_pk: str) -> bool:
    """정규형 event_pk의 로그 행이 이미 있는가(재전송 사전 확인 · 시험이 덮는 이음매 — ia-7)."""
    return SessionRevocationLog.objects.filter(event_pk=normalize_event_pk(event_pk)).exists()


def membership_tenant(sub: str) -> uuid.UUID | None:
    """sub의 TenantMembership으로 정한 tenant_id — 0건 None · 여럿이면 가장 작은 tenant_id + WARNING(모듈 독스트링). 호출자는
    sub의 문자 규칙을 먼저 본다(NUL이 든 값의 조회는 psycopg DataError다)."""
    tenants = list(TenantMembership.objects.filter(sub=sub).order_by("tenant_id").values_list("tenant_id", flat=True))
    if not tenants:
        return None
    if len(tenants) > 1:
        log.warning("identity.multiple_memberships", count=len(tenants), sub_hash=sub_hash(sub))
    tenant: uuid.UUID = tenants[0]
    return tenant


def db_now_epoch() -> int:
    """DB 시계의 epoch 초(내림) — 관리 명령의 nbf 상한 비교에만 쓴다(시험이 덮는 이음매 — ia-39)."""
    with connection.cursor() as cursor:
        cursor.execute("SELECT floor(extract(epoch FROM statement_timestamp()))::bigint")
        (now,) = cursor.fetchone()
    return int(now)


def _check_gate(*, sub: object, sid: object, event_pk: object, nbf: object, source: str) -> None:
    """관문(설계 D12 2단계) — 위반은 RevocationRejected(code)."""
    if not valid_identifier(sub):
        raise RevocationRejected("sub")
    if sid is not None and not valid_identifier(sid):
        raise RevocationRejected("sid")
    if event_pk is not None and not valid_identifier(event_pk):
        raise RevocationRejected("event_pk")
    if not isinstance(nbf, int) or isinstance(nbf, bool) or nbf < 0:
        raise RevocationRejected("nbf")
    if nbf > NBF_MAX:  # 표현 가능 상한(정수 비교 · 시계를 보지 않는다 · 모든 source)
        raise RevocationRejected("nbf")
    if source == "command" and nbf > db_now_epoch() + NBF_COMMAND_LEEWAY_S:
        raise RevocationRejected("nbf_future")


def record_revocation(
    *,
    tenant_id: uuid.UUID,
    sub: str,
    sid: str | None,
    reason: str,
    nbf: int,
    source: str,
    event_pk: str | None = None,
    delegate: bool = False,
) -> Recorded | Replayed:
    """폐기 하나를 기록한다(로그 행 + outbox 이벤트 → 커밋 뒤 거부 목록 · 하한 쓰기 · 지표 · 로그 · 위임) — 모듈 독스트링."""
    if source not in SOURCES:
        raise ValueError("source는 revoke · admin · webhook · reconcile · command 가운데 하나다")
    if delegate and sid is not None:  # 위임은 사용자 단위 행에만 붙는다(설계 D16) — 조용히 무시하지 않는다
        raise ValueError("delegate는 사용자 단위(sid 없음) 기록에만 쓴다")
    with transaction.atomic():  # 1
        _check_gate(sub=sub, sid=sid, event_pk=event_pk, nbf=nbf, source=source)  # 2
        stored_pk = None if event_pk is None else normalize_event_pk(event_pk)
        if stored_pk is not None and event_already_recorded(stored_pk):  # 3
            return Replayed()
        nbf_at = datetime.fromtimestamp(nbf, UTC)
        expires_at = nbf_at + REVOCATION_TTL
        row: SessionRevocationLog | None = None
        constraint: str | None = None
        try:
            with transaction.atomic():  # 4 — 중첩 atomic(경합이면 이 savepoint만 롤백된다)
                row = SessionRevocationLog.objects.create(
                    tenant_id=tenant_id,
                    sub=sub,
                    sid=sid,
                    reason=reason,
                    nbf=nbf_at,
                    expires_at=expires_at,
                    event_pk=stored_pk,
                )
        except IntegrityError as exc:
            diag = getattr(exc.__cause__, "diag", None)
            constraint = getattr(diag, "constraint_name", None) or ""
        if row is None:  # except 블록 밖에서 정한다 — 원 IntegrityError가 연쇄 예외로 남지 않게
            if constraint == EVENT_PK_CONSTRAINT:
                return Replayed()
            raise RevocationWriteError() from None
        with tenant_context(tenant_id):  # 5
            events.publish_owned(
                "session.revoked",
                f"user:{sub}",
                {"sub": sub, "sid": sid, "nbf": nbf, "reason": reason},
                tenant_id=tenant_id,
            )
        after = After()
        revocation_id = row.pk

        def _run() -> None:  # 6 — 값 없는 지역 함수(robust 실패 로그는 `record_revocation.<locals>._run`만 찍는다)
            _after(
                tenant_id=tenant_id,
                sub=sub,
                sid=sid,
                reason=reason,
                nbf=nbf,
                expires_at=expires_at,
                source=source,
                revocation_id=revocation_id,
                delegate=delegate,
                after=after,
            )

        transaction.on_commit(_run, robust=True)
    return Recorded(id=row.pk, nbf=nbf, expires_at=expires_at, after=after)


def _callback_failed(step: str, exc: Exception) -> None:
    """단계 실패 로그(예외 클래스 이름만) — 로그 호출 자신이 던져도 삼킨다(뒤 단계가 돌아야 한다 · 콜백 밖으로 새면 Django robust
    로그가 예외 문구와 연쇄된 원 예외를 싣는다)."""
    try:
        log.warning("session_revocation.callback_failed", step=step, error=type(exc).__name__)
    except Exception:  # noqa: BLE001, S110 — 실패 로그의 실패는 알릴 길이 없다(stdlib 처리기도 같은 sink다)
        pass


def _after(
    *,
    tenant_id: uuid.UUID,
    sub: str,
    sid: str | None,
    reason: str,
    nbf: int,
    expires_at: datetime,
    source: str,
    revocation_id: uuid.UUID,
    delegate: bool,
    after: After,
) -> None:
    """커밋 뒤 콜백(설계 D12 6단계 ①-④) — 단계마다 자기 try/except가 예외 클래스 이름만 남긴다."""
    try:  # ①
        after.denylist = denylist_writer.apply_user(sub) if sid is None else denylist_writer.apply_sid(sid, expires_at)
    except Exception as exc:  # noqa: BLE001 — 쓰기 함수는 값으로 돌려준다 · 예상 밖 예외만 여기에 온다
        after.denylist = denylist_writer.FAILED
        _callback_failed("denylist", exc)
    try:  # ②
        identity_metrics.session_revocations_total().labels(reason=reason).inc()
    except Exception as exc:  # noqa: BLE001
        _callback_failed("metric", exc)
    try:  # ③
        log.info(
            "session_revocation.recorded",
            reason=reason,
            scope="user" if sid is None else "session",
            source=source,
            tenant_id=str(tenant_id),
            sub_hash=sub_hash(sub),
            revocation_id=str(revocation_id),
        )
    except Exception as exc:  # noqa: BLE001
        _callback_failed("log", exc)
    if delegate:  # ④
        try:
            after.delegate = _delegate(sub=sub, nbf=nbf, denylist_result=after.denylist)
        except Exception as exc:  # noqa: BLE001
            after.delegate = "failed"
            _callback_failed("delegate", exc)


def _delegate(*, sub: str, nbf: int, denylist_result: str | None) -> str:
    """Authentik 세션 삭제 위임(설계 D16 「위임 조건」 · 「enqueue 꼴」) — 결과 off · skipped · enqueued · failed."""
    if not settings.AUTHENTIK_WRITES_ENABLED:
        log.info("authentik.revoke_skipped", reason="writes_disabled", sub_hash=sub_hash(sub))
        return "off"
    if conf.PLACEHOLDER_MARK in str(settings.AUTHENTIK_API_TOKEN):
        log.warning("authentik.calls_disabled", reason="placeholder_credential")
        return "skipped"
    if denylist_result == denylist_writer.UNREACHABLE:
        # 브로커가 거부 목록과 같은 Dragonfly라 enqueue도 같은 시간을 쓰고 실패한다(설계 D12 ④ · 〔Y18〕).
        log.info("authentik.revoke_skipped", reason="denylist_unreachable", sub_hash=sub_hash(sub))
        return "skipped"
    from identity_admin.celery import app  # 위임 단계 안에서만 — 모듈 머리 import 금지(migrate 프로필 · 설계 D3 (나))

    failure: str | None = None
    try:
        app.send_task(
            DELEGATION_TASK,
            args=(sub, nbf),
            expires=datetime.fromtimestamp(nbf + DELEGATION_WINDOW_S, UTC),
            retry_policy={"max_retries": 0},
            argsrepr="(<redacted>)",
        )
    except Exception as exc:  # noqa: BLE001 — 브로커 · 직렬화 실패(문구는 브로커 URL을 실을 수 있다 — 클래스 이름만)
        failure = type(exc).__name__
    if failure is not None:
        log.warning("authentik.revoke_enqueue_failed", error=failure, sub_hash=sub_hash(sub))
        return "failed"
    log.info("authentik.revoke_enqueued", sub_hash=sub_hash(sub))
    return "enqueued"
