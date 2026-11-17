"""시험 전용 tenancy urlconf · 뷰 · 원시 미들웨어(T068 · D11) — 모델 없음 · INSTALLED_APPS에 넣지 않는다.

tests/test_tenancy_contract.py의 tenancy_settings 픽스처가 ROOT_URLCONF를 tests.tenancyapp.urls로, MIDDLEWARE를 T060
HeaderTenantMiddleware(tc-6은 이 패키지의 RawTenantMiddleware) + django_common.tenancy.TenantContextMiddleware로 덮는다
(pytest-django settings — 테스트가 끝나면 되돌린다). tests/testapp은 T060 산출물이라 바꾸지 않는다.
"""
