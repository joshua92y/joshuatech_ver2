"""identity-admin Celery 작업 · beat_init 수신자(T073 설계 D14 · D15 · D16 · D17 — pod 소유 새 파일).

정본: contracts/identity-admin-api.md §주기 작업 · contracts/denylist.md §쓰기 규약 · 설계 D14(재적용 · beat_init · purge) · D15
(배선) · D16(위임 작업 옵션) · D26 「상수 이름」.

배선: autodiscover는 `identity_admin.tasks`만 import한다 — 템플릿 소유 `tasks.py`의 한 줄(`from identity_admin import jobs as
_jobs` — 손 수정 ⑤)이 이 모듈을 싣는다. beat 항목은 `identity_admin/celery.py`(손 수정 ④)에 있다. 요청 경로(web)는 이 모듈을
import하지 않는다 — 위임은 `revocation.py`가 이름으로 보낸다(그래서 beat_init 수신자가 web 프로세스에 실리지 않는다).

import 시 DB · 네트워크 0이다 — 구현 모듈(`denylist_writer` · `authentik` · `outbound` · `revocation` · 모델)은 작업 본체 · 수신자
안에서 가져온다(migrate 프로필은 이 모듈을 싣지 않는다 · T066 api-33은 DB 마크가 없다). 머리 import는 celery · structlog(와 표준
라이브러리)뿐이다.

작업의 실패 틀(작업 넷이 같은 수준 — 컨트롤러 결정 · 조각 ⑤-b P5): 원 예외를 Celery에 넘기지 않는다(Celery 실패 · 재시도 줄은
예외 repr과 트레이스백을 찍는다 — DB 예외 문구는 접속 정보를, INSERT 실패 DETAIL은 행 값(원문 sub · event pk)을 싣는다). 예상 밖
예외는 클래스 이름만 실은 WARNING 뒤 문구 없는 예외(ReapplyFailed · PurgeFailed · DelegationFailed · ReconcileFailed)를 except 블록
밖에서 `from None`으로 올린다(상태 FAILURE · 재시도 없음). 일시 오류의 재시도 신호 AuthentikTransient도 인자 없이 같은 자리에서
올린다. 설계가 「WARNING 뒤 끝낸다」고 적은 갈래는 정상 종료(반환 = 건수)다.

작업(이름 = `identity_admin.tasks.<이름>` · 반환은 None이나 건수(정수 · 정수만 든 dict) — Celery 성공 줄이 반환값을 찍으므로
sub · URL · 토큰이 든 값을 돌려주지 않는다)
- reconcile_denylist(30 s · beat 항목 options expires 30): `denylist_writer.reapply()`의 다섯 건수를 dict로 반환한다 — 이 성공
  줄이 재적용 생존 신호다(5분 무소식 = 경보 · T098). 예외는 WARNING `denylist.reapply_failed phase=tick error=<클래스>`를 남기고
  `ReapplyFailed()`(문구 없음 · 연쇄 없음)로 다시 올린다 — 성공 줄이 찍히지 않고, redis-py · psycopg 예외 문구(호스트 · 포트 ·
  키 = sub)가 Celery 실패 로그에 실리지 않는다.
- purge_session_revocation_log(일 1회 03:27 UTC): `denylist_writer.purge_log()` — 지운 행 수(정수). 예외는 WARNING
  `session_revocation_log.purge_failed error=<클래스>`를 남기고 `PurgeFailed()`(문구 없음 · 연쇄 없음)로 다시 올린다 — DB 예외
  문구(호스트 · IP · 포트 · role 이름)가 Celery 실패 줄에 실리지 않는다(설계 D25 · 재적용 작업과 같은 틀 · T073 수정 라운드 ⑤-a
  H4 · 조각 ⑤-b의 두 작업도 이 틀을 따른다).
- revoke_authentik_sessions(sub, nbf)(beat 밖 — 사용자 단위 폐기의 커밋 뒤 콜백이 이름으로 보낸다 · 옵션은 D16: 일시 오류만
  5 → 10 → 20 s 3회 · acks_late · `retry_kwargs={"argsrepr": "(<redacted>)"}` — 재시도로 다시 발행되는 메시지도 인자 표시를
  가린다: Celery 5.6.3은 재발행 때 argsrepr을 물려주지 않고 saferepr(args)로 다시 만든다 · 값은 발행 쪽 `revocation._delegate`의
  argsrepr과 글자 그대로 같다): 설계 D16 본체 순서 그대로 — ① 쓰기 플래그가 거짓이면 INFO `authentik.revoke_skipped
  reason=writes_disabled` · 자격이 자리값이면 WARNING `authentik.calls_disabled reason=placeholder_credential`(호출 0) ② 위임 창
  `nbf + revocation.DELEGATION_WINDOW_S`(발행 쪽 expires와 한 상수)를 지났으면 WARNING `authentik.revoke_expired`(호출 0 · nbf가
  정수가 아니면 `authentik.revoke_failed error=invalid_request`) ③ sub의 문자 규칙(`revocation.valid_identifier` — find_user 앞 ·
  로그의 sub_hash도 sub가 이 규칙을 지날 때만 만든다: 빈 sub · lone surrogate sub에서 sub_hash가 올리는 예외가 실패 틀 밖으로
  가지 않게 — 그런 sub는 `revoke_failed error=invalid_request`로 끝난다) →
  `authentik.find_user`의 결과가 정확히 1 · pk 정수 · username 비지 않은 str(0이면 WARNING `authentik.revoke_user_missing` · 꼴
  밖이면 `authentik.revoke_failed error=malformed`) ④ `authentik.list_sessions`(10쪽 상한 · user == pk만 — 포트가 거른다) ⑤ 세션마다
  `authentik.delete_session`(204 deleted · 404 gone · UUID 꼴 아님 skipped — 갈라 센다) ⑥ INFO
  `authentik.revoke_done`(deleted · gone · skipped · truncated · sub_hash) · 반환 = deleted(정수). HTTP 실패는 WARNING
  `authentik.revoke_failed`(status = 코드 · 또는 error = 종류 + 그때까지의 deleted · gone · skipped)를 남긴 뒤 일시 오류(429 ·
  5xx · 연결 · 시간 초과 · 마감 — `.transient`)면 인자 없는 AuthentikTransient로 재시도하고 그 밖(401 · 403 · 그 밖 4xx · 일시
  아닌 종류)이면 끝낸다. 한 시도 전체 마감은 `outbound.Deadline(DELEGATION_DEADLINE_S)`(시도마다 새로 · 메서드마다 넘긴다).
  로그는 sub_hash만 싣는다.
- reconcile_authentik_sessions()(일 1회 03:37 UTC): 설계 D17 알고리즘 순서 그대로 — ① 자격이 자리값이면 호출 0(WARNING
  `authentik.calls_disabled`) ② `authentik.logout_event_pages`(50쪽 상한)를 쪽마다 받아 처리한 뒤 다음 쪽을 받는다(정렬에 기대어
  일찍 멈추지 않는다 · 상한 쪽이 잘렸으면 WARNING `authentik.reconcile_truncated`) ③ 이벤트마다 다시 확인 — action이 정확히
  `logout` · created가 tz 있는 ISO 8601이고 `now − RECONCILE_WINDOW ≤ created ≤ now + RECONCILE_FUTURE_S`(워커 시계) · user.pk가
  정수(bool 제외 · 2**63 미만) · 이벤트 pk가 str이고 정규형(`revocation.normalize_event_pk`)이 문자 규칙을 지킨다 — 하나라도 아니면
  그 이벤트만 건너뛴다 ④ `revocation.event_already_recorded`(사용자 조회 앞) ⑤ `authentik.get_user`로 uuid(= sub · 실행 안 pk 캐시 ·
  404 = 건너뜀 · 응답의 pk가 요청한 pk와 같고 uuid가 UUID 꼴 · 문자 규칙이어야 한다) ⑥ `revocation.membership_tenant`(없으면
  건너뜀) ⑦ `revocation.record_revocation(reason authentik_webhook · sid None · event_pk 정규형 · nbf = ⌊created⌋ + 1 · source
  reconcile · 위임 없음)` ⑧ INFO `authentik.reconcile_done`(seen · recorded · skipped · pages) · 반환 {seen, recorded,
  skipped}. 건너뜀은 둘로 가른다(수정 라운드 J2 — 「조용한 0건」): 대상 아님(action이 logout이 아닌 str · 창 밖 · 이미 기록됨 · 사용자 조회
  404 · 멤버십 없음 · Replayed — 세지 않는다)과 꼴 어긋남(action이 str이 아님(키 없음 포함) · action이 logout인데 created를 읽을 수
  없음(str 아님 · ISO 8601 아님 · tz 없음) · 창 안 logout인데 user.pk가 정수 pk 꼴이 아님(user 없음 · {} · None · 문자열 숫자 ·
  bool) · 창 안 logout인데 이벤트 pk가 str이 아니거나 정규형이 문자 규칙 밖 · 사용자 조회 200인데 응답의 uuid가 UUID 꼴 · 문자
  규칙이 아니거나 응답의 pk가 요청한 pk와 다름 — 센다 · 같은 사용자의 이벤트는 캐시로 판정째 센다). 둘 다 반환의 skipped에 든다.
  끝의 줄은 차례대로 truncated → 사용자 조회를 한 pk 전부가 404면 WARNING `authentik.reconcile_skipped reason=user_lookup
  count=<pk 수>` → 꼴 어긋남이 1건 이상이면 WARNING `authentik.reconcile_skipped reason=malformed count=<이벤트 수>`(값 — pk · sub ·
  created 원문 — 없음) → done이다. 실패는 첫 번째에서 멈춘다(재시도 없음 · 앞서 기록한 행은 남는다): 401 · 403(이벤트 · 사용자
  조회) → WARNING `authentik.reconcile_forbidden status=<코드>` · 그 밖의 HTTP 실패(일시 오류 · 그 밖 4xx · 일시 아닌 종류) → WARNING
  `authentik.reconcile_failed`(status 또는 error) — 둘 다 정상 종료(반환 = 그때까지의 건수) · 실패 · 권한 없음으로 끝난 실행은
  `reconcile_skipped`(두 reason 모두)와 `reconcile_done`을 남기지 않는다(done은 완주의 표식이다). 쓰기 플래그
  (AUTHENTIK_WRITES_ENABLED)는 보지 않는다(읽기다 — 설계 D18). 전체 마감은 `outbound.Deadline(RECONCILE_DEADLINE_S)`이고 HTTP 호출
  앞과 응답 본문을 읽는 사이(outbound)에 더해 이벤트 하나를 처리하기 앞에서도 본다 — 지났으면 그 자리에서 HTTP 호출의 마감 초과와
  같은 갈래(WARNING `authentik.reconcile_failed error=deadline` · 정상 종료 · 그 이벤트는 seen에 세지 않는다 · 남은 이벤트는 다음
  날)로 끝난다(한 쪽 — 최대 100건 — 의 DB · 커밋 뒤 쓰기가 마감 밖으로 새지 않게).

beat_init 수신자: sender로 거르지 않는다(T066 api-32는 sender=None을 보내고 실제 beat는 Service 인스턴스를 보낸다). 같은
`reapply()`를 같은 프로세스에서 동기로 1회 부른다(브로커 경유 아님 — 하한 · 신선도 키도 같이 쓴다). 성공이면 INFO
`denylist.reapplied phase=beat_init`(다섯 건수) · 예외면 WARNING `denylist.reapply_failed phase=beat_init error=<클래스>`만 남기고
beat 기동은 계속된다(예외를 올리지 않는다).

상수(D26 「상수 이름」 — 쓰는 자리에서 모듈 속성으로 읽는다 · 시험이 「마감 0 s」 같은 조건을 만들 때 덮는다): 위임 한 시도 전체
마감 DELEGATION_DEADLINE_S 20 · 대조 한 실행 전체 마감 RECONCILE_DEADLINE_S 120 · 대조 창 RECONCILE_WINDOW 72 h · 대조 창의 위쪽
끝 RECONCILE_FUTURE_S 300.
"""

from __future__ import annotations

import time
from datetime import UTC, datetime, timedelta
from typing import TYPE_CHECKING, Any

import structlog
from celery.signals import beat_init

from identity_admin.celery import app

if TYPE_CHECKING:
    from types import ModuleType

__all__ = [
    "DELEGATION_DEADLINE_S",
    "DELEGATION_TASK",
    "PURGE_LOG_TASK",
    "RECONCILE_AUTHENTIK_TASK",
    "RECONCILE_DEADLINE_S",
    "RECONCILE_DENYLIST_TASK",
    "RECONCILE_FUTURE_S",
    "RECONCILE_WINDOW",
    "AuthentikTransient",
    "DelegationFailed",
    "PurgeFailed",
    "ReapplyFailed",
    "ReconcileFailed",
    "purge_session_revocation_log",
    "reconcile_authentik_sessions",
    "reconcile_denylist",
    "revoke_authentik_sessions",
]

DELEGATION_DEADLINE_S = 20  # 위임 한 시도 전체 마감(단조 시계 · outbound.Deadline — 설계 D16)
RECONCILE_DEADLINE_S = 120  # 대조 한 실행 전체 마감(설계 D17)
RECONCILE_WINDOW = timedelta(hours=72)  # 대조가 읽는 logout 이벤트 창(설계 D17)
# 대조 창의 위쪽 끝 = 워커 시각 + 300 s(웹훅 시각 창 +300 s와 같은 여유) — 이 끝으로 nbf = ⌊created⌋ + 1 ≤ now + 301이 구성상
# 성립한다(이 경로의 유일한 미래 nbf 방어 · 관문에 source == "reconcile" 비교를 다시 넣지 않는다 — 설계 D17 3 · 7단계 · W14 · Z3).
RECONCILE_FUTURE_S = 300
RECORDED, SKIPPED = "recorded", "skipped"  # 대조 반환의 건수 이름(seen과 함께)
MALFORMED = "malformed"  # 대조에서 꼴이 어긋나 건너뛴 이벤트(반환에서는 skipped에 든다 · reconcile_skipped의 reason)
_FORBIDDEN_STATUSES = frozenset({401, 403})  # 대조의 권한 없음 갈래(reconcile_forbidden — 설계 D17 「권한이 없을 때」)
_MISSING = object()  # 대조의 사용자 조회 캐시에서 404(지워진 사용자 · view_user 없음)
_MALFORMED_USER = object()  # 대조의 사용자 조회 캐시에서 200인데 꼴이 어긋난 응답(uuid 꼴 밖 · pk가 요청과 다름)
# 위임 메시지의 인자 표시 — 발행 쪽 `revocation._delegate`의 argsrepr과 글자 그대로 같다(재시도 재발행도 가린다 — ia-11 옆 시험)
_REDACTED_ARGSREPR = "(<redacted>)"
_EPOCH = datetime(1970, 1, 1, tzinfo=UTC)
_SECOND = timedelta(seconds=1)

# 이름(글자 그대로 — 위임 enqueue는 `revocation.DELEGATION_TASK`로 이름을 보낸다: 둘이 같은지는 ia-11 옆 시험이 본다)
RECONCILE_DENYLIST_TASK = "identity_admin.tasks.reconcile_denylist"
PURGE_LOG_TASK = "identity_admin.tasks.purge_session_revocation_log"
DELEGATION_TASK = "identity_admin.tasks.revoke_authentik_sessions"
RECONCILE_AUTHENTIK_TASK = "identity_admin.tasks.reconcile_authentik_sessions"

log = structlog.get_logger(__name__)


class ReapplyFailed(Exception):
    """재적용 tick 실패(문구 없음 — 원 예외의 문구는 호스트 · 포트 · 키를 싣는다 · 클래스 이름은 WARNING 줄에 남긴다)."""


class PurgeFailed(Exception):
    """로그 purge 실패(문구 없음 — 원 예외의 문구는 DB 호스트 · IP · 포트 · role 이름을 싣는다 · 클래스 이름은 WARNING 줄에
    남긴다)."""


class AuthentikTransient(Exception):
    """Authentik 일시 오류(429 · 5xx · 시간 초과 · 연결 · 마감 초과) — 위임 작업의 autoretry 대상(설계 D16 · 인자 없이 올린다)."""


@app.task(name=RECONCILE_DENYLIST_TASK)
def reconcile_denylist() -> dict[str, int]:
    """30 s 무조건 재적용(설계 D14) — 다섯 건수 dict(Celery 성공 줄 = 생존 신호). 실패는 ReapplyFailed(문구 · 연쇄 없음)."""
    from identity_admin import denylist_writer

    failure: str | None = None
    try:
        result = denylist_writer.reapply()
    except Exception as exc:  # noqa: BLE001 — 어떤 실패든 클래스 이름만 남긴다(문구 = 호스트 · 포트 · sub)
        failure = type(exc).__name__
    if failure is not None:
        log.warning("denylist.reapply_failed", phase="tick", error=failure)
        raise ReapplyFailed() from None
    return {name: int(value) for name, value in result._asdict().items()}


@app.task(name=PURGE_LOG_TASK)
def purge_session_revocation_log() -> int:
    """폐기 로그 purge(일 1회 — 설계 D14) · 지운 행 수. 실패는 PurgeFailed(문구 · 연쇄 없음 — 설계 D25)."""
    from identity_admin import denylist_writer

    failure: str | None = None
    deleted = 0
    try:
        deleted = denylist_writer.purge_log()
    except Exception as exc:  # noqa: BLE001 — 어떤 실패든 클래스 이름만 남긴다(문구 = DB 호스트 · IP · 포트 · role)
        failure = type(exc).__name__
    if failure is not None:
        log.warning("session_revocation_log.purge_failed", error=failure)
        raise PurgeFailed() from None
    return deleted


class DelegationFailed(Exception):
    """위임 본체의 예상 밖 실패(문구 없음 — HTTP 오류 형이 아닌 예외의 문구는 호스트 · 원문 sub를 실을 수 있다 · 클래스 이름은
    WARNING 줄에 남긴다 · AuthentikTransient가 아니므로 재시도되지 않는다)."""


class ReconcileFailed(Exception):
    """대조의 예상 밖 실패(문구 없음 — DB 예외 문구는 접속 정보(호스트 · 포트 · role)와 INSERT 실패 DETAIL의 행 값(원문 sub ·
    event pk)을 싣는다 · 클래스 이름은 WARNING 줄에 남긴다)."""


def _placeholder_credential() -> bool:
    """Authentik 자격이 자리값인가(설계 D18 — 호출 때의 설정 · enqueue 쪽 `revocation._delegate`와 같은 판정)."""
    from django.conf import settings

    from identity_admin import conf

    return conf.PLACEHOLDER_MARK in str(settings.AUTHENTIK_API_TOKEN)


def _upstream_fields(outbound: ModuleType, error: Exception) -> dict[str, object]:
    """outbound 오류의 로그 필드 — UpstreamStatus는 status(코드) · UpstreamUnavailable은 error(종류) · 예외 문구 · repr은 싣지
    않는다(조각 ⑤-b P4)."""
    if isinstance(error, outbound.UpstreamStatus):
        return {"status": error.status}
    return {"error": str(getattr(error, "kind", type(error).__name__))}


def _filled_str(value: object) -> bool:
    return isinstance(value, str) and value != ""


@app.task(
    name=DELEGATION_TASK,
    autoretry_for=(AuthentikTransient,),
    retry_backoff=5,
    retry_backoff_max=300,
    retry_jitter=False,
    max_retries=3,
    acks_late=True,
    reject_on_worker_lost=True,
    ignore_result=True,
    # 재시도 재발행도 인자 표시를 가린다 — Celery 5.6.3은 재발행 때 argsrepr을 물려주지 않고 saferepr(args)로 다시 만든다(autoretry가
    # task.retry(exc=…, **retry_kwargs)로 넘긴다 · Celery가 이 사전에 countdown을 써넣는다)
    retry_kwargs={"argsrepr": _REDACTED_ARGSREPR},
)
def revoke_authentik_sessions(sub: str, nbf: int) -> int:
    """Authentik 세션 삭제 위임(설계 D16 본체 1-6단계 — 모듈 독스트링) · 반환 = deleted(204로 지운 세션 수 · 정수)."""
    from django.conf import settings
    from django_common.observability import sub_hash

    from identity_admin import authentik, outbound, revocation

    # sub_hash는 sub가 문자 규칙을 지날 때만 — 빈 str은 ValueError · lone surrogate는 repr에 원문 sub를 싣는 UnicodeEncodeError를
    # 올린다(실패 틀 밖에서 Celery 실패 줄로 가지 않게 · 그런 sub는 아래 3 앞 검사가 invalid_request로 끝낸다)
    hashed: dict[str, object] = {"sub_hash": sub_hash(sub)} if revocation.valid_identifier(sub) else {}
    if not settings.AUTHENTIK_WRITES_ENABLED:  # 1 — 쓰기 플래그 → 자리값 자격(enqueue 쪽과 같은 차례)
        log.info("authentik.revoke_skipped", reason="writes_disabled", **hashed)
        return 0
    if _placeholder_credential():
        log.warning("authentik.calls_disabled", reason="placeholder_credential")
        return 0
    if not isinstance(nbf, int) or isinstance(nbf, bool):
        log.warning("authentik.revoke_failed", error=outbound.INVALID_REQUEST, **hashed)
        return 0
    if time.time() > nbf + revocation.DELEGATION_WINDOW_S:  # 2 — 위임 창(발행 쪽 expires와 한 상수)
        log.warning("authentik.revoke_expired", **hashed)
        return 0
    if not revocation.valid_identifier(sub):  # 3 앞 — find_user는 꼴이 아닌 인자에 「사용자 없음」과 같은 []를 준다
        log.warning("authentik.revoke_failed", error=outbound.INVALID_REQUEST, **hashed)
        return 0

    deadline = outbound.Deadline(DELEGATION_DEADLINE_S)  # 한 시도 전체 마감(실행마다 새로 · 모듈 속성으로 읽는다)
    counts = {authentik.DELETED: 0, authentik.GONE: 0, authentik.SKIPPED: 0}
    outcome = "done"
    truncated = False
    failure: Exception | None = None
    unexpected: str | None = None
    try:
        found = authentik.find_user(sub, deadline=deadline)  # 3 — uuid가 같은 결과(포트가 정확 일치로 거른다)
        user = found[0] if len(found) == 1 else None
        if not found:
            outcome = "missing"
        elif user is None or not authentik.valid_pk(user.get("pk")) or not _filled_str(user.get("username")):
            outcome = "malformed"
        else:
            listing = authentik.list_sessions(user["pk"], user["username"], deadline=deadline)  # 4 — user == pk만
            truncated = listing.truncated
            for session in listing.items:  # 5 — 단건 DELETE(204 deleted · 404 gone · UUID 꼴 아님 skipped)
                counts[authentik.delete_session(session.get("uuid"), deadline=deadline)] += 1
    except outbound.UpstreamError as exc:
        failure = exc
    except Exception as exc:  # noqa: BLE001 — 예상 밖 예외는 클래스 이름만 남긴다(문구 = 호스트 · 원문 sub)
        unexpected = type(exc).__name__
    if unexpected is not None:
        log.warning("authentik.revoke_failed", error=unexpected, **hashed, **counts)
        raise DelegationFailed() from None
    if failure is not None:
        log.warning("authentik.revoke_failed", **_upstream_fields(outbound, failure), **hashed, **counts)
        if failure.transient:  # 429 · 5xx · 연결 · 시간 초과 · 마감 — 재시도(인자 없음: 재시도 줄이 예외 repr을 찍는다)
            raise AuthentikTransient() from None
        return counts[authentik.DELETED]  # 401 · 403 · 그 밖 4xx · 일시 아닌 종류 — 끝낸다
    if outcome == "missing":
        log.warning("authentik.revoke_user_missing", **hashed)
        return 0
    if outcome == "malformed":
        log.warning("authentik.revoke_failed", error=outbound.MALFORMED, **hashed)
        return 0
    log.info("authentik.revoke_done", truncated=truncated, **hashed, **counts)  # 6
    return counts[authentik.DELETED]


def _event_time(value: object) -> datetime | None:
    """이벤트 created → tz 있는 시각(ISO 8601 — DRF `…Z` · `+00:00` · 소수 초) · 읽히지 않거나 tz가 없으면 None."""
    if not isinstance(value, str):
        return None
    try:
        moment = datetime.fromisoformat(value)
    except ValueError:
        return None
    return moment if moment.utcoffset() is not None else None


def _recheck(event: dict[str, Any], authentik: ModuleType, revocation: ModuleType) -> tuple[str, int, int] | str:
    """설계 D17 3단계 — 받은 이벤트를 클라이언트 쪽에서 다시 확인한다. 반환 = (정규형 event pk, nbf = ⌊created⌋ + 1, 사용자 pk)
    · 아니면 건너뜀의 갈래(그 이벤트만 건너뛴다): SKIPPED = 대상 아님(action이 logout이 아닌 str · 창 밖 — 세지 않는다) ·
    MALFORMED = 꼴 어긋남(action이 str이 아님 · logout인데 created를 못 읽음 · 창 안 logout의 user.pk · 이벤트 pk가 꼴 밖 — 센다)."""
    action = event.get("action")
    if not isinstance(action, str):  # 키 없음 포함
        return MALFORMED
    if action != "logout":
        return SKIPPED
    moment = _event_time(event.get("created"))
    if moment is None:  # str 아님 · ISO 8601 아님 · tz 없음
        return MALFORMED
    now = time.time()  # 워커 시계
    if not now - RECONCILE_WINDOW.total_seconds() <= moment.timestamp() <= now + RECONCILE_FUTURE_S:
        return SKIPPED
    user = event.get("user")
    user_pk = user.get("pk") if isinstance(user, dict) else None
    if not authentik.valid_pk(user_pk):  # user 없음 · {} · None · 문자열 숫자 · bool
        return MALFORMED
    raw_pk = event.get("pk")
    if not isinstance(raw_pk, str):
        return MALFORMED
    event_pk = revocation.normalize_event_pk(raw_pk)
    if not revocation.valid_identifier(event_pk):
        return MALFORMED
    nbf: int = (moment - _EPOCH) // _SECOND + 1  # ⌊created⌋ + 1(정수 연산 — 부동소수 내림 오차 없음)
    return event_pk, nbf, user_pk


def _user_sub(user: dict[str, Any] | None, user_pk: int, authentik: ModuleType, revocation: ModuleType) -> object:
    """사용자 단건 응답 → 캐시 값: 404면 _MISSING · 응답의 pk가 요청한 pk가 아니거나(다른 사용자의 uuid로 기록하지 않는다) uuid가
    UUID 꼴 · 문자 규칙이 아니면 _MALFORMED_USER · 아니면 uuid(= sub)."""
    if user is None:
        return _MISSING
    answered = user.get("pk")
    if not authentik.valid_pk(answered) or answered != user_pk:
        return _MALFORMED_USER
    sub = user.get("uuid")
    if not authentik.valid_uuid(sub) or not revocation.valid_identifier(sub):
        return _MALFORMED_USER
    return sub


def _backfill_one(
    event: dict[str, Any],
    uuids: dict[int, object],
    deadline: Any,
    modules: tuple[ModuleType, ModuleType],
) -> str:
    """이벤트 하나(설계 D17 3-7단계) → RECORDED · SKIPPED(대상 아님) · MALFORMED(꼴 어긋남). HTTP · DB 실패는 호출자에게
    올린다(uuids = 실행 안 pk → 캐시 값 — uuid · 404는 _MISSING · 꼴 어긋난 응답은 _MALFORMED_USER: 같은 사용자의 이벤트는
    판정째 캐시된다)."""
    authentik, revocation = modules
    checked = _recheck(event, authentik, revocation)
    if isinstance(checked, str):
        return checked
    event_pk, nbf, user_pk = checked
    if revocation.event_already_recorded(event_pk):  # 4 — 사용자 조회 앞
        return SKIPPED
    if user_pk not in uuids:  # 5 — pk → uuid(Event.user에는 uuid가 없다) · 실행 안 캐시
        uuids[user_pk] = _user_sub(authentik.get_user(user_pk, deadline=deadline), user_pk, authentik, revocation)
    sub = uuids[user_pk]
    if sub is _MISSING:
        return SKIPPED
    if sub is _MALFORMED_USER or not isinstance(sub, str):
        return MALFORMED
    tenant = revocation.membership_tenant(sub)  # 6 — 없으면 건너뜀 · 여럿이면 가장 작은 tenant_id + WARNING
    if tenant is None:
        return SKIPPED
    recorded = revocation.record_revocation(  # 7 — 웹훅과 같은 기록 경로(위임 없음 · nbf 상한 비교 없음 — 3단계가 막는다)
        tenant_id=tenant,
        sub=sub,
        sid=None,
        reason="authentik_webhook",
        nbf=nbf,
        source="reconcile",
        event_pk=event_pk,
        delegate=False,
    )
    return RECORDED if isinstance(recorded, revocation.Recorded) else SKIPPED


@app.task(name=RECONCILE_AUTHENTIK_TASK)
def reconcile_authentik_sessions() -> dict[str, int]:
    """Authentik logout 이벤트 대조(일 1회 — 설계 D17 1-8단계 · 모듈 독스트링) · 반환 = {seen, recorded, skipped}(정수만)."""
    from identity_admin import authentik, outbound, revocation

    counts = {"seen": 0, RECORDED: 0, SKIPPED: 0}
    if _placeholder_credential():  # 1
        log.warning("authentik.calls_disabled", reason="placeholder_credential")
        return counts
    deadline = outbound.Deadline(RECONCILE_DEADLINE_S)  # 한 번 실행의 전체 마감(실행마다 새로 · 모듈 속성으로 읽는다)
    uuids: dict[int, object] = {}
    pages = 0
    malformed = 0  # 꼴 어긋남으로 건너뛴 이벤트 수(반환에서는 skipped에 든다)
    truncated = False
    failure: Exception | None = None
    unexpected: str | None = None
    listings = authentik.logout_event_pages(deadline=deadline)  # 제너레이터 — 만들기만 해서는 요청이 나가지 않는다
    try:
        for listing in listings:  # 2 — 받은 쪽을 처리한 뒤 다음 쪽을 받는다(앞 쪽에서 기록한 행은 뒤 쪽의 실패에도 남는다)
            pages, truncated = listing.pages, listing.truncated
            for event in listing.items:  # 정렬에 기대어 일찍 멈추지 않는다
                if deadline.remaining() <= 0:  # 이벤트 하나 앞에서도 마감을 본다 — HTTP 호출의 마감 초과와 같은 갈래로 간다
                    raise outbound.UpstreamUnavailable(outbound.DEADLINE)  # (그 이벤트는 세지 않는다 · 남은 것은 다음 날)
                counts["seen"] += 1
                outcome = _backfill_one(event, uuids, deadline, (authentik, revocation))
                if outcome == MALFORMED:  # 반환에서는 skipped에 든다(키는 seen · recorded · skipped 셋)
                    malformed += 1
                    outcome = SKIPPED
                counts[outcome] += 1
    except outbound.UpstreamError as exc:
        failure = exc
    except Exception as exc:  # noqa: BLE001 — 예상 밖 예외(DB 오류 등)는 클래스 이름만 남긴다(문구 = 접속 정보 · 행 값)
        unexpected = type(exc).__name__
    if unexpected is not None:
        log.warning("authentik.reconcile_failed", error=unexpected, pages=pages, **counts)
        raise ReconcileFailed() from None
    if failure is not None:  # 첫 실패에서 멈춘다 — 재시도 없음(다음 날 다시 · 창 72 h)
        if isinstance(failure, outbound.UpstreamStatus) and failure.status in _FORBIDDEN_STATUSES:
            log.warning("authentik.reconcile_forbidden", status=failure.status, pages=pages, **counts)
        else:
            log.warning("authentik.reconcile_failed", **_upstream_fields(outbound, failure), pages=pages, **counts)
        return counts
    if truncated:
        log.warning("authentik.reconcile_truncated", pages=pages)
    missing = sum(1 for value in uuids.values() if value is _MISSING)
    if uuids and missing == len(uuids):  # 사용자 조회를 한 pk 전부가 404 — 권한 없음이 조용한 0건으로 끝나지 않게
        log.warning("authentik.reconcile_skipped", reason="user_lookup", count=missing)
    if malformed:  # 꼴 어긋남(완주한 실행에서만) — 응답 꼴이 바뀐 대조가 「전부 이미 기록됐다」와 같은 줄로 끝나지 않게
        log.warning("authentik.reconcile_skipped", reason=MALFORMED, count=malformed)
    log.info("authentik.reconcile_done", pages=pages, **counts)  # 8
    return counts


@beat_init.connect
def _reapply_on_beat_init(sender: Any = None, **kwargs: Any) -> None:
    """beat 기동 시 동기 재적용 1회(설계 D14) — sender로 거르지 않는다 · 실패는 로그만 남기고 beat 기동을 막지 않는다."""
    from identity_admin import denylist_writer

    failure: str | None = None
    result = None
    try:
        result = denylist_writer.reapply()
    except Exception as exc:  # noqa: BLE001 — 어떤 실패든 클래스 이름만 남기고 beat는 계속 뜬다
        failure = type(exc).__name__
    if failure is not None or result is None:
        log.warning("denylist.reapply_failed", phase="beat_init", error=failure)
        return
    log.info("denylist.reapplied", phase="beat_init", **result._asdict())
