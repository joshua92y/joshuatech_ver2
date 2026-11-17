"""시험 앱 설정(T060)."""

from django.apps import AppConfig


class TestappConfig(AppConfig):
    name = "tests.testapp"
    label = "testapp"
