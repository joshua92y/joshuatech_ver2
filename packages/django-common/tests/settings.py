"""django-common 시험 설정(T060 · D4).

접속 값은 환경변수(JT_TEST_PG_*)에서 읽는다. 설정을 import할 때는 아직 비어 있고, conftest의
django_db_modify_db_settings가 testcontainers 접속 정보로 채운다 — 파일에 자격을 남기지 않는다.
"""

import os

SECRET_KEY = "django-common-tests-only"  # 시험 전용 고정 문자열 — 비밀이 아니다
DEBUG = False
USE_TZ = True

# contenttypes는 프레임워크 테이블 django_content_type을 만든다 — chk-1이 FRAMEWORK_TABLES 면제(계약 §테이블 등급)를
# django_migrations 외 하나 더로 증명하기 위해서다(테스트 자체는 contenttypes를 쓰지 않는다).
INSTALLED_APPS = ["django.contrib.contenttypes", "django_common", "tests.testapp"]
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
MIDDLEWARE = [
    "tests.testapp.middleware.HeaderTenantMiddleware",
    "django_common.tenancy.TenantContextMiddleware",
]
ROOT_URLCONF = "tests.testapp.urls"
# D7 설계 가정 — 계약 §공개 API에 없는 이름 · T068이 확정한다(바꾸면 mw-3 docstring과 함께).
TENANT_CONTEXT_EXEMPT_PATHS = ("/healthz", "/ready", "/health")


def _database(user_env: str, password_env: str) -> dict[str, object]:
    return {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": os.environ.get("JT_TEST_PG_HOST", ""),
        "PORT": os.environ.get("JT_TEST_PG_PORT", ""),
        "NAME": os.environ.get("JT_TEST_PG_DB", ""),
        "USER": os.environ.get(user_env, ""),
        "PASSWORD": os.environ.get(password_env, ""),
        "OPTIONS": {"sslmode": "require"},
    }


DATABASES = {
    # 런타임 연결 = app role(NOBYPASSRLS).
    # TEST.MIRROR = "owner": 두 별칭은 같은 물리 DB다. TransactionTestCase는 테스트가 끝날 때 mirror가 아닌
    # 별칭마다 flush(TRUNCATE)를 하는데 app role에는 TRUNCATE 권한이 없다 → 비우기는 owner 별칭에서만 한다.
    # TEST.MIRROR를 읽는 곳은 둘뿐이다: TransactionTestCase._databases_names(include_mirrors=False → default를
    # flush에서 제외)와 setup_databases의 set_as_test_mirror(NAME만 복사 · 자격은 바꾸지 않는다) — 후자는 conftest가
    # django_db_setup을 재정의해 부르지 않는다. teardown 동작은 T068 첫 초록에서 실측한다(VD-6).
    "default": {
        **_database("JT_TEST_PG_APP_USER", "JT_TEST_PG_APP_PASSWORD"),
        "TEST": {"MIRROR": "owner"},
    },
    # 마이그레이션·시드·DDL 토글 전용 = owner role(BYPASSRLS).
    "owner": _database("JT_TEST_PG_OWNER_USER", "JT_TEST_PG_OWNER_PASSWORD"),
}
