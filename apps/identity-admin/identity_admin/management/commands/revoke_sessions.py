"""revoke_sessions 관리 명령(T073 설계 D30 — pod 소유 새 파일) — 운영자의 사용자 단위 관리자 폐기(계정 탈취 대응 · SP-1에서
관리자 폐기를 부를 유일한 길: `/sessions/revoke`의 관리자 갈래는 BFF 프록시 허용 경로 밖이다).

정본: contracts/identity-admin-api.md §관리 명령 · 설계 D30 · D12(기록 공통 · 다중 멤버십 · nbf 상한) · D16(위임 조건).

`python manage.py revoke_sessions --sub <sub>` — 운영자가 `kubectl -n jt-<env> exec deploy/identity-admin -c web -- python
manage.py revoke_sessions --sub <sub>`로 돈다(runtime 프로필 · app role). 사용자 단위만이다 — 단일 세션 폐기 인자는 두지
않는다(`sid` 폐기는 330 s 차단뿐이고 refresh 폐기가 따르지 않는다 · 설계 W13).
0. 바깥 트랜잭션 안(`connection.in_atomic_block`)이면 조회 · 쓰기 전에 CommandError(기본 종료 코드 1) — 바깥 atomic 안에서는 커밋
   뒤 쓰기가 그 블록 끝으로 밀려 결과 칸이 비고, PARTIAL의 「행은 기록됐다」가 바깥 블록의 롤백 뒤에는 거짓이 된다. 출력 줄의
   `ENV` 설정도 여기서(조회 · 쓰기 앞) 읽는다 — 없으면(migrate 프로필 등) 아무것도 쓰지 않고 CommandError(1)다(행을 기록한 뒤 출력
   줄 없이 끝나 「`revoke_sessions:` 줄이 없으면 기록되지 않았다」가 거짓이 되지 않게).
1. 인자: `--sub` 필수 · 출력 가능 ASCII(`!`-`~`) 1-255자(`revocation.valid_identifier` — 어기면 CommandError).
2. tenant_id = `--sub`의 TenantMembership(`revocation.membership_tenant` — 0건이면 CommandError · 여럿이면 가장 작은
   tenant_id + WARNING `identity.multiple_memberships`). 웹훅 · 관리자 호출과 같은 원천이다.
3. nbf = ⌊time.time()⌋ + 1.
4. `revocation.record_revocation(…, sid=None, reason="admin", source="command", delegate=True)` — 관문이 거부하면
   CommandError(이 경로만 nbf를 DB 시계 + 301 s와 견준다: JWT도 시각 창도 없는 경로라 시계가 틀린 곳에서 돈 명령이 30일
   하한을 미래 값으로 올리는 것을 막는다). 가장 바깥 atomic이라 돌아오기 전에 커밋 뒤 콜백(거부 목록 · 하한 쓰기 → 지표 →
   로그 → 위임)이 끝난다.
5. stdout에 `revoke_sessions:`로 시작하는 줄 하나: `revoke_sessions: OK env=<ENV 설정 값> id=<uuid> nbf=<int>
   expires_at=<ISO 8601 UTC> denylist=<값> delegate=<값>` — sub · 토큰 · URL을 싣지 않는다(같은 stdout에 구조 로그 JSON 줄이
   섞인다 — 읽는 쪽은 접두로 찾는다). `env`는 호출 시점의 `settings.ENV`다(dev · prod가 한 Authentik을 써 같은 sub가 두 env에
   멤버십을 가진다 — 다른 네임스페이스에서 돈 명령이 OK로만 보이지 않게). 두 값은 `Recorded.after`(denylist = ok · skipped ·
   failed · unreachable / delegate = enqueued · skipped · off · failed · 채워지지 않은 칸은 none)다. denylist가 ok · skipped가
   아니면 머리말이 PARTIAL이고 CommandError(returncode 3)로 끝난다 — 행은 기록됐다(2는 argparse 사용법 오류의 코드라 쓰지 않는다 ·
   설계 Z9 · 0단계가 있어 이 문장은 늘 참이다). `delegate=failed`는 종료 코드 0 그대로다(출력으로 드러난다).
CommandError 문구에는 값(sub · URL · 예외 문구)을 싣지 않는다(문구는 cp949로 쓸 수 있는 글자만 — Windows 콘솔).
"""

from __future__ import annotations

import math
import time
from datetime import UTC, datetime
from typing import Any

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError, CommandParser
from django.db import connection

from identity_admin import denylist_writer, revocation

PREFIX = "revoke_sessions:"
PARTIAL_EXIT = 3  # 행은 기록됐다 — 거부 목록 쓰기 실패(설계 D30 · Z9)
# 이 둘이면 OK · 그 밖(failed · unreachable · 채워지지 않음)은 PARTIAL
COMPLETE_DENYLIST = frozenset({denylist_writer.OK, denylist_writer.SKIPPED})
UNFILLED = "none"  # 커밋 뒤 콜백이 채우지 못한 칸


def _iso_utc(value: datetime) -> str:
    """aware datetime → ISO 8601 UTC(`Z` — API 응답 expires_at과 같은 꼴)."""
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _plain(text: str) -> str:
    return text


class Command(BaseCommand):
    help = "사용자 단위 관리자 폐기(--sub) - 로그 행 · 이벤트 → 거부 목록 · 세션 하한 → Authentik 세션 삭제 위임. 출력 한 줄."

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument("--sub", required=True, help="폐기할 사용자 sub(출력 가능 ASCII 1-255자).")

    def handle(self, *args: Any, **options: Any) -> None:
        if connection.in_atomic_block:  # 0 — 조회 · 쓰기 앞
            raise CommandError("바깥 트랜잭션 안에서는 돌 수 없다 - 커밋 뒤 쓰기의 결과를 읽을 수 없고 기록이 롤백될 수 있다")
        env = getattr(settings, "ENV", None)  # 0 — 호출 시점의 설정(비밀 아님) · 조회 · 쓰기 앞에서 읽는다
        if not env:
            raise CommandError("ENV 설정이 없다 - runtime 프로필(web 컨테이너)에서 돌린다")
        sub = options["sub"]
        if not revocation.valid_identifier(sub):  # 1
            raise CommandError("--sub는 출력 가능 ASCII(!-~) 1-255자여야 한다")
        tenant_id = revocation.membership_tenant(sub)  # 2
        if tenant_id is None:
            raise CommandError("--sub의 TenantMembership이 없다(tenant를 정할 수 없다)")
        nbf = math.floor(time.time()) + 1  # 3
        rejected: str | None = None
        try:  # 4
            recorded = revocation.record_revocation(
                tenant_id=tenant_id,
                sub=sub,
                sid=None,
                reason="admin",
                nbf=nbf,
                source="command",
                delegate=True,
            )
        except revocation.RevocationRejected as exc:
            rejected = exc.code
        if rejected is not None:
            raise CommandError(
                f"기록 관문이 거부했다({rejected}) - nbf_future면 이 프로세스 시계가 DB 시계보다 300 s 넘게 앞선다"
            )
        if not isinstance(recorded, revocation.Recorded):  # event_pk 없는 기록은 재전송이 될 수 없다
            raise CommandError("기록이 Recorded가 아니다")
        denylist = recorded.after.denylist or UNFILLED  # 5
        delegate = recorded.after.delegate or UNFILLED
        status = "OK" if denylist in COMPLETE_DENYLIST else "PARTIAL"
        self.stdout.write(
            f"{PREFIX} {status} env={env} id={recorded.id} nbf={recorded.nbf} "
            f"expires_at={_iso_utc(recorded.expires_at)} denylist={denylist} delegate={delegate}",
            style_func=_plain,
        )
        if status == "PARTIAL":
            raise CommandError(
                "행은 기록됐다 - 거부 목록 쓰기 실패 · 60 s 뒤 revoked:sub와 세션 하한 키가 생겼는지 확인한다",
                returncode=PARTIAL_EXIT,
            )
