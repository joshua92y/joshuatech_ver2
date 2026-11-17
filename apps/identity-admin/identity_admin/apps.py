"""identity-admin 앱 설정(T072 D7) — ready()가 모든 프로세스(web · relay · celery · CronJob · migrate · 관리 명령 · 시험)의 기동 자리다."""

from __future__ import annotations

import logging

from django.apps import AppConfig


class PodConfig(AppConfig):
    name = "identity_admin"
    verbose_name = "identity-admin"

    def ready(self) -> None:
        """① configure_logging(JSON 한 줄 = 객체 하나 · LOGGING_CONFIG = None이라 Django 기본 로깅은 돌지 않는다) ② 경고를
        로깅으로 ③ startup.run()(기동 단언 — 네트워크 0) ④ runtime 프로필이면 Celery 브로커 = DRAGONFLY_URL(import도
        이 분기 안 — migrate 프로필은 celery를 import하지 않는다). web의 OTel · Sentry는 wsgi.py가 맡는다."""
        from django.conf import settings
        from django_common.observability import configure_logging

        from identity_admin import startup
        from identity_admin.conf import RUNTIME

        configure_logging()
        logging.captureWarnings(True)
        startup.run()
        if settings.SETTINGS_PROFILE == RUNTIME:
            from identity_admin.celery import configure_broker

            configure_broker(settings.DRAGONFLY_URL)
