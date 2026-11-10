"""outbox_purge 관리 명령(T069 r2 · J10) — dead outbox 행 purge를 Celery 없이 부르는 길(계약 events.md §outbox 릴레이 「purge」).

`python manage.py outbox_purge`(인자 없음): django_common.outbox.purge_dead()(dead_at이 DB now() − 30 d보다 이른 행을 신호 없는
직접 DELETE 한 문장으로 삭제 · DB 시계 · default 별칭 = app role · r3 K7)를 부르고 stdout에 한 줄 `outbox_purge: N`(ASCII — 지운 행
수)을 낸다. Celery가 없는 pod(has_celery=false)는 템플릿이 이 명령을 일 1회 CronJob으로 부르고(T072), Celery가 있는 pod는 템플릿
작업 `<pod_snake>.tasks.purge_dead_outbox`가 같은 함수를 감싼다. 인자를 주면 CommandError다(경계 30 d는 계약 값 — 바꾸지 않는다).
"""

from __future__ import annotations

from typing import Any

from django.core.management.base import BaseCommand

from django_common.outbox import purge_dead


class Command(BaseCommand):
    help = "dead_at + 30 d가 지난 dead outbox 행을 지운다(purge_dead · DB 시계) — 인자 없음 · stdout 한 줄 outbox_purge: N."

    def handle(self, *args: Any, **options: Any) -> None:
        self.stdout.write(f"outbox_purge: {purge_dead()}")
