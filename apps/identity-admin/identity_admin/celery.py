"""identity-admin Celery 앱(T072 D14) — 워커 + 내장 beat 한 프로세스(컨테이너 하나):

    celery --app identity_admin worker --pool solo --beat --schedule /tmp/celerybeat-schedule --without-gossip --without-mingle --without-heartbeat --loglevel INFO

- 브로커 URL은 import 시점이 아니라 PodConfig.ready()의 runtime 분기가 configure_broker(settings.DRAGONFLY_URL)로 둔다 —
  migrate 프로필은 이 모듈을 import하지 않는다. 새 자격 URL 설정 이름을 만들지 않는다(마스킹 목록 그대로).
- Dragonfly pod 사용자는 채널 권한이 없다(resetchannels ~revoked:* ~identity-admin:* +@all — identity-admin(T073) 설계 D24 ·
  contracts/denylist.md §ACL) → 원격 제어 · gossip · mingle · heartbeat(팬아웃 pub/sub)를 끈다. 모든 키는 identity-admin:
  접두(global_keyprefix).
- transport socket_timeout 5 · socket_connect_timeout 2 — BRPOP 1 s 대기보다 크다(0.2 s는 거부 목록 클라이언트 전용).
- 결과 백엔드 없음 · task_always_eager 끔 · 루트 로거를 건드리지 않는다(setup_logging 수신기 + worker_hijack_root_logger False —
  로깅은 configure_logging이 소유한다). 배너 같은 원문 stdout 줄은 Django 밖이라 예외다(수집은 T098).
- 템플릿 기본 beat 작업은 outbox dead purge 하나(일 1회 03:17 UTC — has_celery=false pod의 CronJob과 같은 시각). 롤링 중 beat가
  둘일 수 있다 — 작업은 멱등이다.
"""

from __future__ import annotations

import os
from datetime import timedelta  # identity-admin(T073) — beat 항목 reconcile-denylist의 30 s(설계 D15 · D3 ④)
from typing import Any

from celery import Celery
from celery.schedules import crontab
from celery.signals import setup_logging

# Celery의 Django fixup(django.setup())은 앱을 만들 때 이 env를 본다 — 이미지 ENV와 같은 값이 기본이다.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "identity_admin.settings")

PURGE_TASK = "identity_admin.tasks.purge_dead_outbox"
KEY_PREFIX = "identity-admin:"

CELERY_CONFIG: dict[str, Any] = {
    "broker_transport_options": {
        "global_keyprefix": KEY_PREFIX,
        "socket_timeout": 5,
        "socket_connect_timeout": 2,
    },
    "broker_connection_retry_on_startup": True,
    "worker_enable_remote_control": False,
    "worker_hijack_root_logger": False,
    "task_ignore_result": True,
    "task_always_eager": False,
    "timezone": "UTC",
    "beat_schedule": {
        "purge-dead-outbox": {"task": PURGE_TASK, "schedule": crontab(minute=17, hour=3)},
        # identity-admin(T073) — 설계 D15 · D3 ④: 30 s 무조건 재적용(밀린 tick은 쌓지 않고 버린다 — expires 30) · 폐기 로그
        # purge 03:27 UTC · Authentik logout 이벤트 대조 03:37 UTC(작업은 identity_admin/jobs.py — tasks.py가 싣는다)
        "reconcile-denylist": {
            "task": "identity_admin.tasks.reconcile_denylist",
            "schedule": timedelta(seconds=30),
            "options": {"expires": 30},
        },
        "purge-session-revocation-log": {
            "task": "identity_admin.tasks.purge_session_revocation_log",
            "schedule": crontab(minute=27, hour=3),
        },
        "reconcile-authentik-sessions": {
            "task": "identity_admin.tasks.reconcile_authentik_sessions",
            "schedule": crontab(minute=37, hour=3),
        },
        # identity-admin(T073) 끝
    },
}

app = Celery("identity_admin")
app.conf.update(CELERY_CONFIG)
app.autodiscover_tasks(["identity_admin"])


@setup_logging.connect
def _keep_root_logging(**kwargs: Any) -> None:
    """수신기가 있으면 Celery가 로깅을 다시 설정하지 않는다 — configure_logging(PodConfig.ready)의 루트 핸들러를 그대로 둔다."""


def configure_broker(url: str) -> None:
    """브로커 URL = DRAGONFLY_URL(PodConfig.ready()의 runtime 분기만 부른다)."""
    app.conf.broker_url = url
