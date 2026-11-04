"""시험 전용 auth urlconf(T062 · D6) — 모델 없음 · INSTALLED_APPS에 넣지 않는다.

conftest의 make_client가 ROOT_URLCONF를 tests.authapp.urls로, MIDDLEWARE를 django_common.auth.JwtAuthMiddleware
하나로 덮는다. 헬스 3종 · 보호 경로 · 웹훅 경로를 둔다(tests/testapp은 T060 산출물이라 바꾸지 않는다).
"""
