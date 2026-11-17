"""startup_check 관리 명령(T072 D7) — web Deployment initContainer `startup-check`가 돈다(`python manage.py startup_check`).

`startup_check [--database default] [--wait 60]`:
1. DB 접속을 재시도한다(1 → 2 → 4 … s · 마감 --wait 초 · netpol 적용 경합) — 재시도하는 것은 접속 실패(OperationalError)뿐이고
   그 밖의 예외는 곧바로 실패다. 재시도 줄은 stdout `startup_check: db_connect_retry <예외 클래스> attempt=<n>`.
2. django_common.tenancy.check_rls(using=…, require_rls_role=True) — 표 등급 · RLS 정본 + 연결 role이 RLS를 비켜 갈 수 없음(런타임에
   owner 자격이 들어간 사고를 막는다).
성공은 stdout 한 줄 `startup_check: OK`. 최종 실패(재시도 소진 · 위반 · 그 밖의 예외)는 stderr 한 줄 `startup_check: FAIL <예외 클래스
이름>`(위반이면 `startup_check: FAIL check_rls <이름들>`) + 종료 코드 1이다 — 트레이스백 · 예외 메시지는 내지 않는다(libpq 오류
문구가 접속 문자열 조각을 실을 수 있다). 출력이 한 줄로 정해져 있어 시스템 검사는 돌리지 않는다(시험 · manage.py check가 본다).
같은 <pod>-env 자격을 web이 한 번 증명하므로 celery · CronJob · migrate에는 이 단계를 두지 않는다.
"""

from __future__ import annotations

import sys
import time
from typing import Any

from django.core.management.base import BaseCommand, CommandParser
from django.db import DEFAULT_DB_ALIAS, OperationalError, connections

PREFIX = "startup_check:"
DEFAULT_WAIT_SECONDS = 60
MAX_WAIT_SECONDS = 600
FIRST_DELAY_SECONDS = 1.0


def _wait_seconds(value: str) -> int:
    seconds = int(value)
    if not 0 <= seconds <= MAX_WAIT_SECONDS:
        raise ValueError
    return seconds


class Command(BaseCommand):
    help = "DB 접속을 재시도한 뒤 check_rls --require-rls-role을 돈다 — 성공 stdout 한 줄 · 실패 stderr 한 줄 + 종료 코드 1."
    requires_system_checks: list[str] = []

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument("--database", default=DEFAULT_DB_ALIAS, choices=tuple(connections), help="DB 별칭(기본 default).")
        parser.add_argument(
            "--wait",
            type=_wait_seconds,
            default=DEFAULT_WAIT_SECONDS,
            help=f"접속 재시도 마감(초 · 0–{MAX_WAIT_SECONDS} · 기본 {DEFAULT_WAIT_SECONDS}).",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        alias: str = options["database"]
        failure: str | None = None
        try:
            failure = self._connect(alias, options["wait"])
            if failure is None:
                failure = self._check(alias)
        except Exception as error:  # noqa: BLE001 — 어떤 예외든 클래스 이름 한 줄로 끝낸다(메시지 · 트레이스백 없음)
            failure = type(error).__name__
        finally:
            connections[alias].close()
        if failure is not None:
            self.stderr.write(f"{PREFIX} FAIL {failure}", style_func=_plain)
            sys.exit(1)
        self.stdout.write(f"{PREFIX} OK", style_func=_plain)

    def _connect(self, alias: str, wait: int) -> str | None:
        """접속될 때까지 재시도한다 — 성공 None · 마감을 넘기면 마지막 예외 클래스 이름."""
        connection = connections[alias]
        deadline = time.monotonic() + wait
        delay = FIRST_DELAY_SECONDS
        attempt = 0
        while True:
            attempt += 1
            try:
                connection.ensure_connection()
                return None
            except OperationalError as error:
                name = type(error).__name__
            connection.close()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return name
            self.stdout.write(f"{PREFIX} db_connect_retry {name} attempt={attempt}", style_func=_plain)
            self.stdout.flush()
            time.sleep(min(delay, remaining))
            delay *= 2

    def _check(self, alias: str) -> str | None:
        from django_common.tenancy import check_rls

        violations = check_rls(using=alias, require_rls_role=True)
        if not violations:
            return None
        names = sorted({violation.split(":", 1)[0].strip() for violation in violations})
        return f"check_rls {','.join(names)}"


def _plain(text: str) -> str:
    return text
