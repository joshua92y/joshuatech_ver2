"""outbox_requeue 관리 명령(T069 · D8) — dead outbox 행을 pending으로 되돌리는 수동 재처리(계약 「재처리는 dead_at을 비우는 수동
command」).

`python manage.py outbox_requeue --id <ULID> [--id <ULID> …]` 또는 `--all`(둘 중 하나만 — 둘 다 · 둘 다 없음은 CommandError).
--id는 ULID 꼴(봉투 id pattern — Crockford 대문자 26자 · 끝 줄바꿈 거부)이어야 한다. dead 행(dead_at IS NOT NULL)의 dead_at ·
attempts · last_error를 비운다(django_common.outbox.requeue_dead — attempts를 남기면 다음 패스가 곧바로 DLQ로 다시 보낸다 ·
pending 행은 그대로). stdout에 한 줄 `outbox_requeue: N`(ASCII — 되돌린 행 수)을 낸다. 메인 토픽만 실패한 부분 장애로 dead가 된
행을 복구 뒤 되돌리는 데 쓴다(D9).
"""

from __future__ import annotations

import argparse
from typing import Any

from django.core.management.base import BaseCommand, CommandError, CommandParser

from django_common.outbox import requeue_dead
from django_common.outbox.publisher import ENVELOPE_PATTERNS


def _ulid(text: str) -> str:
    if ENVELOPE_PATTERNS["id"].search(text) is None:
        raise argparse.ArgumentTypeError("ULID 꼴(Crockford 대문자 26자)이 아니다")
    return text


class Command(BaseCommand):
    help = "dead outbox 행을 pending으로 되돌린다(dead_at · attempts · last_error 비움) — --id <ULID>(반복) 또는 --all."

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument(
            "--id", dest="ids", action="append", type=_ulid, metavar="ULID", help="되돌릴 dead 행 id(반복 가능)."
        )
        parser.add_argument("--all", action="store_true", help="dead 행 전부를 되돌린다.")

    def handle(self, *args: Any, **options: Any) -> None:
        ids: list[str] | None = options["ids"]
        everything: bool = options["all"]
        if bool(ids) == everything:
            raise CommandError("--id <ULID>…와 --all 가운데 하나만 준다")
        count = requeue_dead(None if everything else ids)
        self.stdout.write(f"outbox_requeue: {count}")
