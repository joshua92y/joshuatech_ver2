"""check_rls 관리 명령(T068 · D10 · r2 · r3 · r4 · r5) — django_common.tenancy.check_rls의 CLI.

CI(owner — `--database <별칭>`)와 기동(app role — 기본 default · `--require-rls-role`)에서 돈다. 위반이 있으면 전부를 담은
CommandError(CLI 종료 코드 1), 없으면 stdout에 한 줄 `check_rls: OK - A 등급 N · B 등급 M · 프레임워크 K`(ASCII 하이픈 —
cp949 콘솔에 리디렉트해도 인코딩된다). `--require-rls-role`은 연결의 session_user가 superuser · BYPASSRLS role이거나 그
멤버면, 또는 스캔 범위 관계의 소유자이거나 그 멤버면(r4 H4 — 소유자는 NO FORCE · DROP POLICY로 RLS를 끌 수 있다) 위반으로
본다(기동 검사 — 런타임에 owner 자격이 들어간 사고 · SET ROLE · assume_role · app 자격으로 돈 마이그레이션 포함 · CI의 owner
실행에는 붙이지 않는다). 판정 규칙(r4: A 표의 정책은 tenant_isolation 하나 · r4 · r5: 상속 · 파티션 링크의 양쪽 등급이
같다 — A 표의 부모도, A 표의 상속 자식 · 파티션도 A)과 스캔 조건(search_path 고정 · 롤백) · 검사 범위의 경계는
django_common.tenancy 모듈 독스트링과 _scan_rls — 명령도 같은 함수 경로(_scan_rls)를 쓴다. 명령은 INSTALLED_APPS의
django_common에서 발견된다(pod settings에 django_common이 있어야 한다).
"""

from __future__ import annotations

from typing import Any

from django.core.management.base import BaseCommand, CommandError, CommandParser
from django.db import DEFAULT_DB_ALIAS, connections

from django_common.tenancy import _scan_rls


class Command(BaseCommand):
    help = (
        "테이블 등급 검사: A 등급(ENABLE + FORCE RLS + 정본 식 · 표 · 열에만 의존하는 정책 tenant_isolation 하나 · 상속 · "
        "파티션 부모와 자식도 A) · B 등급(허용 목록 · RLS 없음) · 프레임워크 면제 · 소유자 권한 객체(SECURITY DEFINER 함수 · "
        "재작성 규칙)를 카탈로그와 모델로 판정한다."
    )

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--database",
            default=DEFAULT_DB_ALIAS,
            choices=tuple(connections),
            help="검사할 DB 별칭(기본 default).",
        )
        parser.add_argument(
            "--require-rls-role",
            action="store_true",
            help=(
                "연결의 session_user가 superuser · BYPASSRLS role이거나 그 멤버면, 또는 스캔 범위 관계의 소유자이거나 그 "
                "멤버면 위반으로 본다(기동 검사 · SET ROLE · assume_role 포함 · CI의 owner 실행에는 붙이지 않는다)."
            ),
        )

    def handle(self, *args: Any, **options: Any) -> None:
        scan = _scan_rls(options["database"], require_rls_role=options["require_rls_role"])
        if scan.violations:
            lines = "\n".join(f"  {violation}" for violation in scan.violations)
            raise CommandError(f"check_rls: 위반 {len(scan.violations)}건\n{lines}")
        self.stdout.write(
            f"check_rls: OK - A 등급 {scan.grade_a} · B 등급 {scan.grade_b} · 프레임워크 {scan.framework}"
        )
