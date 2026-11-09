"""시험 전용 앱 설정(T072 D12)."""

from django.apps import AppConfig


class RlsappConfig(AppConfig):
    name = "tests.rlsapp"
    label = "rlsapp"
