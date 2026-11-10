"""생성 트리 검사 함수(T065 gen-1 · gen-2 · gen-3 · gen-18) — 생성물 파일 · pyproject · env.example · copier 설정.

정본: contracts/pod-template.md §생성 트리 · §기본 테스트 6 · rules/django-pod.md §Template and structure · §Tests.
검사 함수는 list[str](위반)을 돌려준다 — 빈 목록 = 통과. 첫 위반에서 멈추지 않고 전부 모은다. 값(비밀일 수 있는
것)은 위반 문구에 찍지 않는다.

T072 추가(design/t072-design.md D21 · 계약 §기본 테스트 6 「T072가 더한 단언」 — 파일 끝 절): T065 상수 · 함수는 그대로
두고(X19) 새 도우미만 더한다 — T072 트리(gen-25 · 29) · 렌더 전용 트리(gen-29) · pytest 위생(gen-26) · outbox_purge
표식(gen-27) · base kustomization 정적 키(gen-23) · copier validator 거부 · 받아들임 답변 기록(gen-28) · 변형 settings
탐침(gen-32) · Dockerfile 정적 검사 · 이미지 구성 · 이미지 탐침(gen-33) · 기동 실패 출력 · outbox_purge 실패 사유 · docker
logs 실패 · 로그 쓰기 오류 · 비밀 누출 · 비밀 가리기 · 스모크 기록(SmokeLog — gen-34). 금지 env 이름은 렌더
env_hygiene(tests/_render.py)과 같은 상수를 쓴다.

T072 조각 ③ r2(리뷰 r1 반영 — 파일 끝 절 · design/t072-design.md 〔③ r2 …〕): 생성 Dockerfile.dockerignore 정적 검사(M1 · M2a) · 심은
감시 파일 기록(M2b) · build-arg 배선(M4) · compose config 내용(M5 — gen-35) · copier 예약 이름(M11 — gen-37). gen-33 기존 검사는
RUN uv sync에 --no-dev와 따옴표 셸 꼴(M3) · CMD = 이미지 CMD 상수(tests/_render.py WEB_COMMAND — M6) · 탐침의 *.crt · *.p12 · *.pfx와
dev 전용 배포(M1 · M3)를 더했다.
"""

from __future__ import annotations

import ast
import json
import os
import posixpath
import re
import shlex
import string
import tomllib
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass, replace
from pathlib import Path, PurePosixPath
from typing import Any

import yaml

from tests._layout import POD_NAME, POD_SNAKE
from tests._proc import IMAGE_VENV_SENTINEL, ProcResult, SmokeRun, describe, tail
from tests._render import FORBIDDEN_ENV_NAMES, FORBIDDEN_ENV_PREFIXES, FORBIDDEN_ENV_SUFFIXES, WEB_COMMAND

POD_TEST_FILES = (
    "tests/test_health.py",
    "tests/test_tenant_rls.py",
    "tests/test_outbox.py",
    "tests/test_auth_middleware.py",
    "tests/test_logging.py",
    "tests/test_migrations.py",
    "tests/test_openapi_snapshot.py",
)
REQUIRED_FILES = (
    "pyproject.toml",
    "uv.lock",
    "Dockerfile",
    "compose.dev.yml",
    "env.example",
    "manage.py",
    f"{POD_SNAKE}/settings.py",
    f"{POD_SNAKE}/urls.py",
    f"{POD_SNAKE}/api.py",
    f"{POD_SNAKE}/management/commands/outbox_relay.py",
    "tests/conftest.py",
    *POD_TEST_FILES,
    "deploy/base/kustomization.yaml",
)
REQUIRED_DIRS = (f"{POD_SNAKE}/core", f"{POD_SNAKE}/events")
ANSWERS_FILE = ".copier-answers.yml"
# .jinja 잔재를 찾을 때 내려가지 않는 디렉터리(설치물 · 캐시 — 템플릿이 만든 파일이 아니다)
SKIP_DIRS = frozenset({".venv", "__pycache__", ".pytest_cache", ".git", "node_modules", ".mypy_cache", ".ruff_cache"})

# 계약 §생성 트리 env.example 행의 키 20(값 없이 키만)
ENV_KEYS = frozenset(
    {
        "DATABASE_URL",
        "DRAGONFLY_URL",
        "KAFKA_BOOTSTRAP",
        "KAFKA_USERNAME",
        "KAFKA_PASSWORD",
        "AUTHENTIK_ISSUER",
        "AUTHENTIK_JWKS_URL",
        "AUTHENTIK_AUDIENCE",
        "ACCESS_TEAM_DOMAIN",
        "ACCESS_AUD_M2M",
        "ACCESS_AUD_ADMIN",
        "ACCESS_EXPECTED_CN",
        "AUTH_ACTOR_SUB",
        "ADMIN_HOST",
        "ALLOWED_HOSTS",
        "SENTRY_DSN",
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "OTEL_TRACES_SAMPLER",
        "OTEL_TRACES_SAMPLER_ARG",
        "ENV",
    }
)
_ENV_LINE_RE = re.compile(r"([A-Z][A-Z0-9_]*)=(.*)", re.DOTALL)
OWNER_URL_KEY = "DATABASE_OWNER_URL"
EMAIL_PREFIX = "EMAIL_"

NINJA_SPEC = "==1.7.0"
DJANGO_COMMON = "django-common"
DJANGO_COMMON_SOURCE = "../../packages/django-common"
DEV_REQUIREMENTS = ("django-migration-linter", "pytest", "pytest-django", "testcontainers")
DEPRECATION_CATEGORIES = frozenset({"DeprecationWarning", "builtins.DeprecationWarning"})
# 모듈 없이 error로 올리면 의존 라이브러리의 경고로도 스위트가 죽는 범주(전역 -W error와 같다)
GLOBAL_ERROR_CATEGORIES = frozenset({"", "Warning", "builtins.Warning"}) | DEPRECATION_CATEGORIES
MIN_COPIER_VERSION = (9, 17)

_REQUIREMENT_RE = re.compile(r"\s*([A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?)(.*)", re.DOTALL)
_DOTTED_VERSION_RE = re.compile(r"[0-9]+(?:\.[0-9]+)*")


def _dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _load_yaml(text: str) -> tuple[Any, str | None]:
    try:
        return yaml.safe_load(text), None
    except yaml.YAMLError as exc:
        return None, f"YAML 파싱 실패: {exc}"


def canonical_name(name: str) -> str:
    """PEP 503 정규화(대소문자 · 구분자 무시)."""
    return re.sub(r"[-_.]+", "-", name).lower()


def split_requirement(requirement: str) -> tuple[str, str] | None:
    """PEP 508 요구 문자열 → (정규화 이름, 이름 뒤 나머지에서 공백을 뺀 것). 예: "psycopg[binary]>=3.3,<4" →
    ("psycopg", "[binary]>=3.3,<4")."""
    match = _REQUIREMENT_RE.fullmatch(requirement)
    if match is None:
        return None
    return canonical_name(match.group(1)), re.sub(r"\s+", "", match.group(2))


def _requirements(value: Any) -> list[tuple[str, str, str]]:
    """의존성 목록 → (정규화 이름, 나머지, 원문). 문자열이 아닌 항목({include-group = …} 등)은 건너뛴다."""
    found: list[tuple[str, str, str]] = []
    for item in value if isinstance(value, list) else []:
        if isinstance(item, str):
            parsed = split_requirement(item)
            if parsed is not None:
                found.append((parsed[0], parsed[1], item))
    return found


def _lines(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, str):
        return [line.strip() for line in value.splitlines() if line.strip()]
    return []


def _arguments(value: Any) -> list[str]:
    """pytest addopts — TOML 목록이면 항목 그대로, 문자열이면 shlex 분리(pytest와 같다)."""
    if isinstance(value, list):
        return [str(item) for item in value]
    if isinstance(value, str):
        return shlex.split(value)
    return []


def _filter_parts(entry: str) -> tuple[str, str, str, str]:
    """pytest filterwarnings "action:message:category:module:lineno" → (action, message, category, module)."""
    parts = [part.strip() for part in entry.split(":")] + ["", "", "", ""]
    return parts[0], parts[1], parts[2], parts[3]


def _is_own_module_error(entry: str) -> bool:
    action, _message, category, module = _filter_parts(entry)
    return action == "error" and category in DEPRECATION_CATEGORIES and module == POD_SNAKE


def _last_traceback_style(arguments: list[str]) -> str | None:
    style: str | None = None
    for index, argument in enumerate(arguments):
        if argument.startswith("--tb="):
            style = argument.removeprefix("--tb=")
        elif argument == "--tb" and index + 1 < len(arguments):
            style = arguments[index + 1]
    return style


def parse_dotted_version(value: Any) -> tuple[int, ...] | None:
    """"9.17" · 9.17 → (9, 17). 튜플로 비교한다(문자열 비교면 "9.9" > "9.17"). 접미사가 붙은 값은 None."""
    if isinstance(value, bool) or value is None:
        return None
    text = str(value).strip()
    if not _DOTTED_VERSION_RE.fullmatch(text):
        return None
    return tuple(int(part) for part in text.split("."))


# ---------- gen-1 ----------


def _jinja_leftovers(pod: Path) -> list[str]:
    leftovers: list[str] = []
    for current, dirnames, filenames in os.walk(pod):
        dirnames[:] = sorted(name for name in dirnames if name not in SKIP_DIRS)
        for filename in sorted(filenames):
            if filename.endswith(".jinja"):
                leftovers.append((Path(current) / filename).relative_to(pod).as_posix())
    return leftovers


def check_generated_files(pod: Path) -> list[str]:
    """생성 트리(계약 §생성 트리)의 파일 · 디렉터리 · .copier-answers.yml(pod_name) · .jinja 잔재 없음."""
    violations: list[str] = []
    for relative in REQUIRED_FILES:
        if not (pod / relative).is_file():
            violations.append(f"파일 없음: {relative}")
    for relative in REQUIRED_DIRS:
        if not (pod / relative).is_dir():
            violations.append(f"디렉터리 없음: {relative}/")
    answers_path = pod / ANSWERS_FILE
    if not answers_path.is_file():
        violations.append(f"파일 없음: {ANSWERS_FILE}(템플릿에 답변 파일 템플릿이 있어야 한다)")
    else:
        answers, problem = _load_yaml(answers_path.read_text(encoding="utf-8"))
        if problem is not None:
            violations.append(f"{ANSWERS_FILE}: {problem}")
        elif _dict(answers).get("pod_name") != POD_NAME:
            violations.append(f"{ANSWERS_FILE}: pod_name = {_dict(answers).get('pod_name')!r}(기대 {POD_NAME!r})")
    for relative in _jinja_leftovers(pod):
        violations.append(f"렌더되지 않은 .jinja 파일: {relative}")
    return violations


# ---------- gen-2 ----------


def check_pyproject(text: str) -> list[str]:
    """생성물 pyproject.toml — 핀 · path 소스 · dev 의존 · pytest 경고 범위 · --tb=short · requires-python."""
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as exc:
        return [f"pyproject.toml 파싱 실패: {exc}"]
    violations: list[str] = []
    project = _dict(data.get("project"))
    dependencies = _requirements(project.get("dependencies"))

    ninja = [entry for entry in dependencies if entry[0] == "django-ninja"]
    if not ninja:
        violations.append(f"project.dependencies에 django-ninja 없음(기대 정확 핀 django-ninja{NINJA_SPEC})")
    for _name, rest, raw in ninja:
        if rest != NINJA_SPEC:
            violations.append(f"django-ninja 항목 {raw!r}(기대 정확 핀 django-ninja{NINJA_SPEC})")
    if not any(name == "django" and rest.startswith(">=6.1") for name, rest, _ in dependencies):
        violations.append("project.dependencies에 django>=6.1… 항목 없음")
    if not any(name == "psycopg" and rest.startswith("[") and "3.3" in rest for name, rest, _ in dependencies):
        violations.append("project.dependencies에 psycopg[…]…3.3… 항목 없음(extras와 3.3 하한)")
    if not any(name == "celery" and "5.6" in rest for name, rest, _ in dependencies):
        violations.append("project.dependencies에 celery…5.6… 항목 없음")
    if not any(name == DJANGO_COMMON for name, _, _ in dependencies):
        violations.append(f"project.dependencies에 {DJANGO_COMMON} 없음")

    tool = _dict(data.get("tool"))
    sources = _dict(_dict(tool.get("uv")).get("sources"))
    source = next((_dict(value) for key, value in sources.items() if canonical_name(key) == DJANGO_COMMON), None)
    if source is None:
        violations.append(f"tool.uv.sources에 {DJANGO_COMMON} 없음(기대 path {DJANGO_COMMON_SOURCE!r})")
    else:
        prefix = f"tool.uv.sources.{DJANGO_COMMON}"
        if source.get("path") != DJANGO_COMMON_SOURCE:
            violations.append(f"{prefix}.path = {source.get('path')!r}(기대 {DJANGO_COMMON_SOURCE!r})")
        if source.get("editable") is not True:
            violations.append(f"{prefix}.editable = {source.get('editable')!r}(계약: editable — 기대 True)")

    dev = {name for name, _, _ in _requirements(_dict(data.get("dependency-groups")).get("dev"))}
    for wanted in DEV_REQUIREMENTS:
        if wanted not in dev:
            violations.append(f"dependency-groups.dev에 {wanted} 없음")

    options = _dict(_dict(tool.get("pytest")).get("ini_options"))
    filters = _lines(options.get("filterwarnings"))
    if not any(_is_own_module_error(entry) for entry in filters):
        violations.append(f"filterwarnings에 error::DeprecationWarning:{POD_SNAKE}(자기 모듈 한정) 없음")
    for entry in filters:
        action, _message, category, module = _filter_parts(entry)
        if action == "error" and not module and category in GLOBAL_ERROR_CATEGORIES:
            violations.append(f"filterwarnings {entry!r}가 전역이다(모듈 없이 error — 의존 라이브러리 경고로 스위트가 죽는다)")
    arguments = _arguments(options.get("addopts"))
    for argument in arguments:
        if argument.startswith("-W") or argument.startswith("--pythonwarnings"):
            violations.append(f"addopts에 전역 경고 옵션 {argument!r}(금지 — filterwarnings를 자기 모듈로 한정한다)")
    if _last_traceback_style(arguments) != "short":
        violations.append("addopts의 traceback 스타일이 --tb=short가 아니다(긴 트레이스백은 접속 문자열 비밀번호를 찍는다)")

    requires = project.get("requires-python")
    if not (isinstance(requires, str) and requires.replace(" ", "").startswith(">=3.13")):
        violations.append(f"project.requires-python = {requires!r}(기대 '>=3.13…')")
    return violations


# ---------- gen-3 ----------


def check_env_example(text: str) -> list[str]:
    """env.example — 주석 · 빈 줄 밖의 모든 줄이 KEY=(키만) · 키 ⊇ 계약 20 · DATABASE_OWNER_URL · EMAIL_* 없음."""
    violations: list[str] = []
    keys: list[str] = []
    for number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = _ENV_LINE_RE.fullmatch(line)
        if match is None:
            key_part = line.split("=", 1)[0]
            violations.append(f"env.example {number}행이 'KEY='(키만) 꼴이 아니다: {key_part!r}=…")
            continue
        keys.append(match.group(1))
        if match.group(2):
            violations.append(f"env.example {number}행 {match.group(1)}에 값이 있다(키만 둔다 — 값은 찍지 않는다)")
    missing = sorted(ENV_KEYS - set(keys))
    if missing:
        violations.append(f"env.example에 계약 키 없음: {missing}")
    for key in keys:
        if key == OWNER_URL_KEY:
            violations.append(f"env.example에 {OWNER_URL_KEY}(migrate Job 전용)가 있다")
        if key.startswith(EMAIL_PREFIX):
            violations.append(f"env.example에 {key}(EMAIL_* 금지 — 메일은 MAILERS)가 있다")
    return violations


# ---------- gen-5(tests/test_migrations.py 본문) ----------

_MAKEMIGRATIONS_CHECK_RE = re.compile(r"makemigrations\b[^\n]*(--check|\bcheck\s*=\s*True)")
LINTER_MARKERS = ("lintmigrations", "django_migration_linter")


def check_migrations_test(text: str) -> list[str]:
    """생성물 tests/test_migrations.py — makemigrations는 같은 줄에 --check(또는 check=True)가 있어야 하고(--check 없는
    호출은 마이그레이션 파일을 만들고도 통과한다 — r1 A-3), django-migration-linter(lintmigrations 명령 또는
    django_migration_linter 모듈)를 부른다(문면 · 계약 §기본 테스트 5·6)."""
    violations: list[str] = []
    if "makemigrations" not in text:
        violations.append("tests/test_migrations.py에 makemigrations 없음(기대 makemigrations --check)")
    elif _MAKEMIGRATIONS_CHECK_RE.search(text) is None:
        violations.append("tests/test_migrations.py의 makemigrations 호출에 --check 없음(검사가 아니라 생성이 된다)")
    if not any(marker in text for marker in LINTER_MARKERS):
        violations.append("tests/test_migrations.py에 django-migration-linter(lintmigrations · django_migration_linter) 없음")
    return violations


# ---------- gen-18 ----------


def _is_uv_lock(task: Any) -> bool:
    if isinstance(task, dict):
        task = task.get("command")
    if isinstance(task, str):
        tokens = task.split()
    elif isinstance(task, list):
        tokens = [str(item) for item in task]
    else:
        return False
    return tokens[:2] == ["uv", "lock"]


def check_copier_settings(answers_text: str | None, copier_text: str) -> list[str]:
    """생성물 .copier-answers.yml의 _src_path · 템플릿 copier.yml의 _min_copier_version ≥ 9.17 · _tasks의 uv lock."""
    violations: list[str] = []
    if answers_text is None:
        violations.append(f"생성물에 {ANSWERS_FILE} 없음")
    else:
        answers, problem = _load_yaml(answers_text)
        if problem is not None:
            violations.append(f"{ANSWERS_FILE}: {problem}")
        elif "_src_path" not in _dict(answers):
            violations.append(f"{ANSWERS_FILE}에 _src_path 없음")
    config, problem = _load_yaml(copier_text)
    if problem is not None:
        return [*violations, f"copier.yml: {problem}"]
    if not isinstance(config, dict):
        return [*violations, "copier.yml이 매핑이 아니다"]
    if "_min_copier_version" not in config:
        violations.append("copier.yml에 _min_copier_version 없음(기대 ≥ 9.17)")
    else:
        version = parse_dotted_version(config["_min_copier_version"])
        if version is None:
            violations.append(f"copier.yml _min_copier_version = {config['_min_copier_version']!r}를 읽지 못했다")
        elif version < MIN_COPIER_VERSION:
            violations.append(f"copier.yml _min_copier_version = {version}(기대 ≥ {MIN_COPIER_VERSION})")
    tasks = config.get("_tasks")
    if tasks is None:
        violations.append("copier.yml에 _tasks 없음(기대 uv lock)")
    elif not any(_is_uv_lock(task) for task in (tasks if isinstance(tasks, list) else [tasks])):
        violations.append("copier.yml _tasks에 uv lock 없음")
    return violations


# ==================== T072(design/t072-design.md D21 · 계약 §기본 테스트 6 「T072가 더한 단언」) ====================

# ---------- gen-25 · gen-29 T072 생성 트리(D3 — T065 REQUIRED_FILES 밖의 추가분) ----------

T072_FILES = (
    "README.md",
    "Dockerfile.dockerignore",
    "compose/dragonfly-dev.acl",
    f"{POD_SNAKE}/__init__.py",
    f"{POD_SNAKE}/apps.py",
    f"{POD_SNAKE}/conf.py",
    f"{POD_SNAKE}/startup.py",
    f"{POD_SNAKE}/errors.py",
    f"{POD_SNAKE}/middleware.py",
    f"{POD_SNAKE}/metrics.py",
    f"{POD_SNAKE}/wsgi.py",
    f"{POD_SNAKE}/gunicorn_conf.py",
    f"{POD_SNAKE}/core/__init__.py",
    f"{POD_SNAKE}/core/apps.py",
    f"{POD_SNAKE}/core/models.py",
    f"{POD_SNAKE}/core/migrations/__init__.py",
    f"{POD_SNAKE}/core/migrations/0001_app_role_grants.py",
    f"{POD_SNAKE}/events/__init__.py",
    f"{POD_SNAKE}/events/README.md",
    f"{POD_SNAKE}/management/commands/startup_check.py",
    "tests/__init__.py",
    "tests/settings.py",
    "tests/_jwt.py",
    "tests/_problem.py",
    "tests/_secret.py",
    "tests/_kafka.py",
    "tests/_outbox_fakes.py",
    "tests/docker/pg-tls/Dockerfile",
    "tests/docker/pg-tls/00-tls-only.sh",
    "tests/rlsapp/__init__.py",
    "tests/rlsapp/models.py",
    "tests/rlsapp/migrations/__init__.py",
    "tests/probe_urls.py",
    "tests/snapshots/openapi.json",
    "deploy/base/configmap.yaml",
    "deploy/base/externalsecret-env.yaml",
    "deploy/base/externalsecret-migrate.yaml",
    "deploy/base/migrate-job.yaml",
    "deploy/base/deployment.yaml",
    "deploy/base/service.yaml",
    "deploy/base/ingress.yaml",
)
T072_CELERY_FILES = (f"{POD_SNAKE}/celery.py", f"{POD_SNAKE}/tasks.py", "deploy/base/deployment-celery.yaml")
T072_CRONJOB_FILES = ("deploy/base/cronjob-outbox-purge.yaml",)
T072_ADMIN_FILES = (f"{POD_SNAKE}/urls_admin.py", "tests/probe_admin_urls.py")
T072_CONSUMER_FILES = (f"{POD_SNAKE}/events/consumers.py",)
# 시험 전용 A 등급 앱의 마이그레이션 두 개(D3 「migrations 0001 · 0002_rls」 · D12) — 이름 뒤쪽은 템플릿이 정한다
T072_FILE_PATTERNS = ("tests/rlsapp/migrations/0001_*.py", "tests/rlsapp/migrations/0002_*.py")
# identity-admin(T066)이 이미 쓰는 시험 파일 이름 — 생성물이 쓰면 T073 생성이 덮어쓴다(test_api.py 가정 ⑧)
FORBIDDEN_FILE_NAMES = frozenset({"test_api.py", "_identity_fakes.py", "test_identity_fakes.py"})
GITKEEP = ".gitkeep"
LOCK_FILE = "uv.lock"
VENV_DIR = ".venv"


def _walk_files(root: Path) -> list[Path]:
    """root 아래 파일 전부(SKIP_DIRS — .venv · 캐시 — 안은 내려가지 않는다)."""
    found: list[Path] = []
    for current, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(name for name in dirnames if name not in SKIP_DIRS)
        found.extend(Path(current) / filename for filename in sorted(filenames))
    return found


def check_generated_files_t072(
    root: Path, *, has_celery: bool = True, has_admin: bool = True, consumes: bool = False
) -> list[str]:
    """T072 생성 트리(D3)의 추가 파일 — 조건 없는 파일 · 조건부 파일(플래그대로 있음/없음: celery.py · tasks.py ·
    deployment-celery.yaml = has_celery · cronjob-outbox-purge.yaml = has_celery=false · urls_admin.py ·
    probe_admin_urls.py = has_admin · events/consumers.py = consumes_events가 비지 않을 때) · tests/rlsapp 마이그레이션
    0001 · 0002 · 쓰지 않는 파일 이름(FORBIDDEN_FILE_NAMES) · .gitkeep 0. T065 REQUIRED_FILES는 gen-1(기본) ·
    check_render_only_tree(변형)가 본다."""
    violations: list[str] = []
    for relative in T072_FILES:
        if not (root / relative).is_file():
            violations.append(f"파일 없음: {relative}(T072 생성 트리 — D3)")
    conditional = (
        (T072_CELERY_FILES, has_celery, "has_celery=true"),
        (T072_CRONJOB_FILES, not has_celery, "has_celery=false"),
        (T072_ADMIN_FILES, has_admin, "has_admin=true"),
        (T072_CONSUMER_FILES, consumes, "consumes_events가 비지 않을 때"),
    )
    for files, wanted, when in conditional:
        for relative in files:
            if wanted and not (root / relative).is_file():
                violations.append(f"파일 없음: {relative}({when} 생성물에 있어야 한다)")
            elif not wanted and (root / relative).exists():
                violations.append(f"있으면 안 되는 파일: {relative}({when}에만 생긴다)")
    for pattern in T072_FILE_PATTERNS:
        if not any(path.is_file() for path in root.glob(pattern)):
            violations.append(f"파일 없음: {pattern}(tests/rlsapp 마이그레이션 — D3 · D12)")
    for path in _walk_files(root):
        relative = path.relative_to(root).as_posix()
        if path.name == GITKEEP:
            violations.append(f".gitkeep이 있다: {relative}(copier _exclude가 빼야 한다 — D2)")
        if path.name in FORBIDDEN_FILE_NAMES:
            violations.append(f"쓰지 않는 파일 이름: {relative}(identity-admin 시험 파일과 겹친다 — T066 가정 ⑧)")
    return violations


def _answers_problems(root: Path) -> list[str]:
    answers_path = root / ANSWERS_FILE
    if not answers_path.is_file():
        return [f"파일 없음: {ANSWERS_FILE}(템플릿에 답변 파일 템플릿이 있어야 한다)"]
    answers, problem = _load_yaml(answers_path.read_text(encoding="utf-8"))
    if problem is not None:
        return [f"{ANSWERS_FILE}: {problem}"]
    if _dict(answers).get("pod_name") != POD_NAME:
        return [f"{ANSWERS_FILE}: pod_name = {_dict(answers).get('pod_name')!r}(기대 {POD_NAME!r})"]
    return []


def check_render_only_tree(root: Path) -> list[str]:
    """렌더 · 검사 전용 생성(copier --skip-tasks · 형제 django-common 없음 — T072 변형 · 계약 머리)의 T065 트리:
    REQUIRED_FILES(uv.lock 제외) · REQUIRED_DIRS · .copier-answers.yml(pod_name) · .jinja 잔재 없음, 그리고 uv.lock ·
    .venv가 없다 — 그 트리에서는 uv lock · uv sync를 하지 않는다(rules/django-pod.md §Template)."""
    violations: list[str] = []
    for relative in REQUIRED_FILES:
        if relative != LOCK_FILE and not (root / relative).is_file():
            violations.append(f"파일 없음: {relative}")
    for relative in REQUIRED_DIRS:
        if not (root / relative).is_dir():
            violations.append(f"디렉터리 없음: {relative}/")
    violations.extend(_answers_problems(root))
    for relative in _jinja_leftovers(root):
        violations.append(f"렌더되지 않은 .jinja 파일: {relative}")
    if (root / LOCK_FILE).exists():
        violations.append(f"{LOCK_FILE}이 있다 — 렌더 전용 생성(--skip-tasks)인데 uv lock이 돌았다")
    if (root / VENV_DIR).exists():
        violations.append(f"{VENV_DIR}가 있다 — 렌더 전용 트리에서 uv sync가 돌았다(변형 Python은 기본 pod venv로만 돈다)")
    return violations


# ---------- gen-26 pytest 위생(D4 · rules/django-pod.md §Tests) ----------

WRAPPER_SETTINGS = "tests.settings"
# 값을 받는 pytest 짧은 옵션 — 뭉친 꼴(-ra · -pno:cacheprovider)에서 그 뒤 글자는 옵션이 아니라 값이다
_VALUE_SHORT_OPTIONS = frozenset("rkmpcW")
_WIDENING_LONG = ("--showlocals", "--full-trace")
_LOG_OPTIONS = ("--log-cli-level", "--log-file")
_CAPTURE_OFF = ("no", "tee-sys")


def _option_value(arguments: list[str], index: int, option: str) -> str | None:
    """--opt=값 또는 --opt 값 꼴에서 값. option이 아니면 None(값이 빠졌으면 빈 문자열)."""
    argument = arguments[index]
    if argument.startswith(option + "="):
        return argument.removeprefix(option + "=")
    if argument == option:
        return arguments[index + 1] if index + 1 < len(arguments) else ""
    return None


def check_pytest_hygiene(pyproject_text: str) -> list[str]:
    """생성물 pyproject.toml의 pytest 위생 — addopts에 --tb=short · --show-capture=no가 있고, 실패 출력을 넓히거나
    캡처를 끄는 옵션(-l · --showlocals · short가 아닌 --tb · --full-trace · no가 아닌 --show-capture · -o ·
    --override-ini · --log-cli-level · --log-file · -s · --capture=no|tee-sys · @파일 인자)이 없고, ini에 log_cli ·
    log_file · no가 아닌 junit_logging이 없고, DJANGO_SETTINGS_MODULE = tests.settings(시험 래퍼 — D5)다.
    T072 ② r2 H9(B-1): addopts에 --ds=tests.settings가 있고 다른 --ds 값(빈 값 포함 — 뒤의 값이 이기고, 빈 값이면
    pytest-django가 env로 넘어간다)이 없다 — pytest-django는 옵션 > env > ini 순이라 ini만으로는 셸 env
    DJANGO_SETTINGS_MODULE이 시험 래퍼를 비켜 간다(--ds는 넓히는 옵션이 아니라 래퍼를 고정한다).
    설정은 [tool.pytest.ini_options]에만 둔다(pytest 9의 [tool.pytest] 바로 아래 설정은 이 검사 · gen-2가 보지 못한다)."""
    try:
        data = tomllib.loads(pyproject_text)
    except tomllib.TOMLDecodeError as exc:
        return [f"pyproject.toml 파싱 실패: {exc}"]
    violations: list[str] = []
    pytest_table = _dict(_dict(data.get("tool")).get("pytest"))
    native = sorted(key for key in pytest_table if key != "ini_options")
    if native:
        violations.append(f"[tool.pytest] 바로 아래 설정 {native} — pytest 설정은 [tool.pytest.ini_options]에 둔다")
    options = _dict(pytest_table.get("ini_options"))
    arguments = _arguments(options.get("addopts"))
    tracebacks: list[str] = []
    captures: list[str] = []
    settings_modules: list[str] = []
    for index, argument in enumerate(arguments):
        traceback_style = _option_value(arguments, index, "--tb")
        show_capture = _option_value(arguments, index, "--show-capture")
        capture = _option_value(arguments, index, "--capture")
        settings_module = _option_value(arguments, index, "--ds")
        if traceback_style is not None:
            tracebacks.append(traceback_style)
        elif show_capture is not None:
            captures.append(show_capture)
        elif settings_module is not None:
            settings_modules.append(settings_module)
        elif capture is not None:
            if capture in _CAPTURE_OFF:
                violations.append(f"addopts --capture={capture} — 캡처를 끄면 시험 출력(심은 비밀 · 감시 값)이 그대로 찍힌다")
        elif argument in _WIDENING_LONG:
            violations.append(f"addopts {argument} — 실패 출력을 넓히는 옵션(지역 변수 · 전체 트레이스백)")
        elif argument == "--override-ini" or argument.startswith("--override-ini="):
            violations.append("addopts --override-ini — ini 설정을 덮는다(addopts 위생을 끌 수 있다)")
        elif any(argument == option or argument.startswith(option + "=") for option in _LOG_OPTIONS):
            violations.append(f"addopts {argument.split('=', 1)[0]} — 로그를 콘솔 · 파일로 내보낸다")
        elif argument.startswith("@"):
            violations.append(f"addopts {argument} — 파일에서 인자를 읽는다(위생을 판정할 수 없다)")
        elif argument.startswith("-") and not argument.startswith("--") and len(argument) > 1:
            for letter in argument[1:]:
                if letter == "l":
                    violations.append(f"addopts {argument} — -l(--showlocals)이 들어 있다")
                    break
                if letter == "o":
                    violations.append(f"addopts {argument} — -o(--override-ini)가 들어 있다")
                    break
                if letter == "s":
                    violations.append(f"addopts {argument} — -s(--capture=no)가 들어 있다")
                    break
                if letter in _VALUE_SHORT_OPTIONS:
                    break
    if not tracebacks:
        violations.append("addopts에 --tb=short 없음(긴 트레이스백은 접속 문자열 비밀번호를 찍는다)")
    violations.extend(f"addopts --tb={style!r} — short가 아닌 트레이스백 스타일" for style in tracebacks if style != "short")
    if not captures:
        violations.append("addopts에 --show-capture=no 없음(실패 보고의 캡처 칸이 심은 비밀 · 감시 값을 찍는다 — D4)")
    violations.extend(f"addopts --show-capture={value!r} — no가 아니다" for value in captures if value != "no")
    if not settings_modules:
        violations.append(
            f"addopts에 --ds={WRAPPER_SETTINGS} 없음(pytest-django는 옵션 > env > ini — 셸 env DJANGO_SETTINGS_MODULE이 시험 래퍼를"
            " 비켜 간다 · B-1)"
        )
    violations.extend(
        f"addopts --ds={value!r} — {WRAPPER_SETTINGS}가 아니다(시험 래퍼를 비켜 간다 · 빈 값이면 env로 넘어간다)"
        for value in settings_modules
        if value != WRAPPER_SETTINGS
    )
    for key in ("log_cli", "log_file"):
        if key in options:
            violations.append(f"ini {key}가 있다(로그를 콘솔 · 파일로 내보낸다)")
    if "junit_logging" in options and options["junit_logging"] != "no":
        violations.append(f"ini junit_logging = {options['junit_logging']!r}(no가 아니면 junit XML에 캡처 출력이 실린다)")
    if options.get("DJANGO_SETTINGS_MODULE") != WRAPPER_SETTINGS:
        violations.append(
            f"ini DJANGO_SETTINGS_MODULE = {options.get('DJANGO_SETTINGS_MODULE')!r}(기대 {WRAPPER_SETTINGS!r} — 시험 래퍼 · D5)"
        )
    return violations


# ---------- gen-27 outbox_purge 표식(D17 · 계약:108 넷 ④) ----------

_PURGE_CALL_RE = re.compile(r"""call_command\(\s*["']outbox_purge["']""")


def check_outbox_test(text: str) -> list[str]:
    """생성물 tests/test_outbox.py에 call_command("outbox_purge") 호출(주석 줄 제외). 내용의 질은 리뷰 몫이다(§9 위험)."""
    code = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))
    if _PURGE_CALL_RE.search(code) is None:
        return ['tests/test_outbox.py에 call_command("outbox_purge") 없음(주석 줄 제외 — 계약:108 넷 ④ · D17)']
    return []


# ---------- gen-23 base kustomization 정적 키(D20 · ⑳ — 렌더로 볼 수 없는 부분) ----------

BASE_KUSTOMIZATION_FORBIDDEN_KEYS = ("images", "namespace", "commonLabels")


def check_base_kustomization(text: str) -> list[str]:
    """생성물 deploy/base/kustomization.yaml에 images · namespace · commonLabels 키가 없다(overlay가 정한다 — 태그 없는
    images 항목이나 commonLabels는 렌더에 흔적이 남지 않아 tests/_render.py check_images가 볼 수 없다)."""
    data, problem = _load_yaml(text)
    if problem is not None:
        return [f"deploy/base/kustomization.yaml: {problem}"]
    if not isinstance(data, dict):
        return ["deploy/base/kustomization.yaml이 매핑이 아니다"]
    return [
        f"deploy/base/kustomization.yaml에 {key} 키가 있다(overlay가 정한다 — base에 두지 않는다 · D20)"
        for key in BASE_KUSTOMIZATION_FORBIDDEN_KEYS
        if key in data
    ]


# ---------- gen-28 copier validator 거부(D2 · 컨트롤러 결정 문구 「invalid <질문>: …」) ----------


def check_validator_rejection(returncode: int | None, stderr: str, question: str) -> list[str]:
    """copier copy --defaults --skip-tasks --pretend --data …가 question의 validator로 거부됐는가 — 0이 아닌 종료 +
    stderr의 마지막 줄(빈 줄 제외)에 'invalid <question>:'(ASCII). copier 9.19.1은 --data 값의 validator 실패를
    처리하지 않은 ValueError로 올려 트레이스백을 찍는다(_cli._handle_exceptions가 UserMessageError만 잡는다 — 실측
    2026-11-07). 그래서 「트레이스백 없음」 대신 「트레이스백이 있으면 그 끝 예외가 그 질문의 validator 문구」를 본다 —
    다른 예외(템플릿 렌더 실패 등)로 끝난 거부는 통과가 아니다."""
    violations: list[str] = []
    if returncode in (0, None):
        violations.append(f"copier 종료 코드 {returncode}(기대 0이 아님 — {question} validator가 거부해야 한다)")
    marker = f"invalid {question}:"
    lines = [line.strip() for line in stderr.splitlines() if line.strip()]
    last = lines[-1] if lines else ""
    if marker not in last:
        violations.append(f"stderr 마지막 줄에 {marker!r} 없음(그 질문의 validator 거부로 끝나야 한다 — 문구 앞머리)")
    elif not last.isascii():
        violations.append("validator 문구가 ASCII가 아니다(콘솔 인코딩과 무관한 영어 한 줄 — 컨트롤러 결정)")
    return violations


def check_recorded_answers(answers_text: str | None, expected: Mapping[str, Any]) -> list[str]:
    """gen-28 받아들임 사례(T072 r2 E4 · r1 A-4) — copier copy --skip-tasks로 만든 생성물의 .copier-answers.yml이 주입한
    값(pod_name · owns_events · consumes_events · description)을 그대로 기록한다(목록 질문은 YAML 목록). 템플릿에 답변 파일
    템플릿(D2 · 가정 ④)이 있어야 참이다 — 빈 템플릿에서는 빨강."""
    if answers_text is None:
        return [f"{ANSWERS_FILE} 없음(템플릿 답변 파일 {{{{ _copier_conf.answers_file }}}}.jinja — D2 · 가정 ④)"]
    answers, problem = _load_yaml(answers_text)
    if problem is not None:
        return [f"{ANSWERS_FILE}: {problem}"]
    if not isinstance(answers, dict):
        return [f"{ANSWERS_FILE}가 매핑이 아니다"]
    violations: list[str] = []
    for key, value in expected.items():
        if key not in answers:
            violations.append(f"{ANSWERS_FILE}에 {key} 없음(기대 {value!r} — 주입 값)")
        elif answers[key] != value:
            violations.append(f"{ANSWERS_FILE}: {key} = {answers[key]!r}(기대 {value!r} — 주입 값 그대로)")
    return violations


# ---------- gen-32 변형 settings 탐침(D3 · D6 · D10 · X10) ----------

ADMIN_APP = "django.contrib.admin"
CONTRIB_PREFIX = "django.contrib."
SESSION_MIDDLEWARE = "django.contrib.sessions.middleware.SessionMiddleware"
ADMIN_ONLY_MIDDLEWARE = (
    f"{POD_SNAKE}.middleware.AdminHostMiddleware",
    SESSION_MIDDLEWARE,
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
)


def check_variant_settings(facts: Any, *, has_admin: bool) -> list[str]:
    """변형 settings 탐침 JSON(celery_imported · installed_apps · middleware · templates · has_admin_urlconf) —
    django.setup() + urlconf import 뒤 celery 미import(기본 pod venv가 상위 집합이라 has_celery=false 코드의 celery
    import를 가리지 못하게) · has_admin: django.contrib.admin · SessionMiddleware · TEMPLATES ≥ 1 · ADMIN_URLCONF 있음 ·
    has_admin=false: django.contrib.* 앱 0 · AdminHost · Session · Auth · Message 미들웨어 0 · TEMPLATES 0 · ADMIN_URLCONF
    없음."""
    if not isinstance(facts, dict):
        return ["settings 탐침 결과가 JSON 객체가 아니다"]
    violations: list[str] = []
    if facts.get("celery_imported") is not False:
        violations.append(
            "django.setup() + urlconf import 뒤 sys.modules에 celery가 있다(has_celery=false 코드가 celery를 import한다 — X10)"
        )
    apps = facts.get("installed_apps")
    middleware = facts.get("middleware")
    if not (isinstance(apps, list) and isinstance(middleware, list)):
        return [*violations, "settings 탐침의 installed_apps · middleware가 목록이 아니다"]
    templates = facts.get("templates")
    admin_urlconf = facts.get("has_admin_urlconf")
    if has_admin:
        if ADMIN_APP not in apps:
            violations.append(f"INSTALLED_APPS에 {ADMIN_APP} 없음(has_admin)")
        if SESSION_MIDDLEWARE not in middleware:
            violations.append(f"MIDDLEWARE에 {SESSION_MIDDLEWARE} 없음(has_admin)")
        if not (isinstance(templates, int) and templates >= 1):
            violations.append(f"TEMPLATES {templates!r}개(has_admin — admin은 DjangoTemplates가 필요하다)")
        if admin_urlconf is not True:
            violations.append("ADMIN_URLCONF 설정 없음(has_admin — D6)")
    else:
        contrib = [app for app in apps if isinstance(app, str) and app.startswith(CONTRIB_PREFIX)]
        if contrib:
            violations.append(f"has_admin=false인데 INSTALLED_APPS에 {contrib}(contrib를 하나도 두지 않는다 — D3)")
        present = [item for item in ADMIN_ONLY_MIDDLEWARE if item in middleware]
        if present:
            violations.append(f"has_admin=false인데 MIDDLEWARE에 {present}(D10)")
        if templates != 0:
            violations.append(f"has_admin=false인데 TEMPLATES {templates!r}개(has_admin일 때만 둔다 — D6)")
        if admin_urlconf is not False:
            violations.append("has_admin=false인데 ADMIN_URLCONF 설정이 있다(D6)")
    return violations


# ---------- gen-33 Dockerfile 정적 검사 · 이미지 구성 · 이미지 탐침(D18 · X18 · X27) ----------

IMAGE_USER = "10001:10001"
IMAGE_UID = 10001
NO_CONTROL_SOCKET = "--no-control-socket"
REVISION_LABEL = "org.opencontainers.image.revision"
MIN_IMAGE_PYTHON = (3, 13, 2)
IMAGE_NINJA_VERSION = "1.7.0"
# 이미지 /src/apps/<pod> 최상위 허용 목록(T072 조각 ③ 지시 5) — 빌더가 만든 venv · pod 패키지 · 진입점 · 잠금 원본만. dockerignore가
# 빠지거나 거부 목록으로 돌아가도 기동 · 다른 단언은 초록일 수 있다(실측 ③ · ③ r2): Windows는 호스트 .venv가 이미지 .venv에 합쳐진 채
# 유지되고(두 번째 uv sync가 venv를 다시 만들지 않는다) web이 뜬다 · Linux는 uv가 「non-existent Python interpreter」로 합쳐진 venv를
# 지우고 다시 만든다(그래서 Linux에서는 .venv 감시 파일만으로는 공허하다 — 생성 dockerignore 정적 검사 check_dockerignore_text가 막는다).
# 시험 · deploy · compose · 문서 · 답변 파일 · .env* · 그 밖의 작업 트리 파일(감시 파일 jt-harness.local)이 들어오면 여기서 잡는다.
IMAGE_POD_ENTRIES = frozenset({VENV_DIR, POD_SNAKE, "manage.py", "pyproject.toml", LOCK_FILE})
# RUN uv sync마다 있어야 하는 플래그(D18 · 계약 Dockerfile 행 — 잠금 그대로 · dev 그룹 제외(T072 ③ r2 M3 — 없으면 pytest ·
# testcontainers가 공개 이미지에 들어간다) · django-common 비-editable 설치)
UV_SYNC_REQUIRED_FLAGS = ("--locked", "--no-dev", "--no-editable")
_DIGEST_RE = re.compile(r"@sha256:[0-9a-f]{64}$")
_DIRECTIVE_RE = re.compile(r"#\s*([A-Za-z][A-Za-z0-9_-]*)\s*=\s*(.*)")
_ASCII_UPPER = str.maketrans(string.ascii_lowercase, string.ascii_uppercase)


def forbidden_env_name(name: str) -> bool:
    """금지 env 이름인가(ASCII 대소문자 무시) — tests/_render.py env_hygiene과 같은 상수: 이름 목록 + 접두 PG +
    접미 _PROXY."""
    key = name.translate(_ASCII_UPPER)
    return key in FORBIDDEN_ENV_NAMES or key.startswith(FORBIDDEN_ENV_PREFIXES) or key.endswith(FORBIDDEN_ENV_SUFFIXES)


@dataclass(frozen=True)
class _Instruction:
    line: int
    keyword: str
    arguments: str


def _make_instruction(line: int, parts: list[str]) -> _Instruction:
    joined = " ".join(part.strip() for part in parts).strip()
    pieces = re.split(r"\s+", joined, maxsplit=1)
    return _Instruction(line, pieces[0].upper(), pieces[1] if len(pieces) > 1 else "")


def _dockerfile_instructions(text: str) -> tuple[list[_Instruction], dict[str, str]]:
    """Dockerfile → (명령 목록, 파서 지시자). 맨 앞 '# 키=값' 줄이 지시자이고, 줄 이음(\\ 또는 # escape=`)을 잇고 주석 ·
    빈 줄을 버린다(줄 이음 가운데의 주석 줄도 — Docker와 같다). heredoc(<<EOF)은 다루지 않는다(D18은 쓰지 않는다)."""
    lines = text.splitlines()
    directives: dict[str, str] = {}
    index = 0
    while index < len(lines):
        match = _DIRECTIVE_RE.fullmatch(lines[index].strip())
        if match is None:
            break
        directives[match.group(1).lower()] = match.group(2).strip()
        index += 1
    escape = directives.get("escape") if directives.get("escape") in ("\\", "`") else "\\"
    instructions: list[_Instruction] = []
    buffer: list[str] = []
    start = 0
    for number in range(index, len(lines)):
        stripped = lines[number].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not buffer:
            start = number + 1
        body = lines[number].rstrip()
        if body.endswith(escape):
            buffer.append(body[: -len(escape)])
            continue
        buffer.append(body)
        instructions.append(_make_instruction(start, buffer))
        buffer = []
    if buffer:
        instructions.append(_make_instruction(start, buffer))
    return instructions, directives


def _env_instruction_names(arguments: str) -> list[str] | None:
    """ENV 인자 → 이름들(ENV a=1 b=2 · 옛 꼴 ENV a 값…). 따옴표 짝이 맞지 않으면 None."""
    try:
        tokens = shlex.split(arguments)
    except ValueError:
        return None
    if not tokens:
        return []
    if "=" not in tokens[0]:
        return [tokens[0]]
    return [token.split("=", 1)[0] for token in tokens]


def _command_tokens(arguments: str) -> list[str]:
    """CMD 인자 → 토큰(exec 꼴 JSON 배열 또는 셸 꼴)."""
    text = arguments.strip()
    if text.startswith("["):
        try:
            value = json.loads(text)
        except json.JSONDecodeError:
            value = None
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            return value
    try:
        return shlex.split(text)
    except ValueError:
        return text.split()


def _pinned(reference: str) -> bool:
    return _DIGEST_RE.search(reference) is not None


_SHELL_PUNCTUATION = frozenset("();<>|&")
_UV_SYNC_TEXT_RE = re.compile(r"\buv\b.*\bsync\b", re.DOTALL)
# 따옴표로 묶인 셸 명령(sh -c "…" · bash -lc '…')을 다시 나눠 보는 깊이 상한(T072 ③ r2 M3)
_NESTED_SHELL_DEPTH = 4


def _run_segments(arguments: str) -> list[list[str]] | None:
    """RUN 인자 → 셸 명령 조각(토큰 목록)들. exec 꼴(JSON 배열)은 원소를 공백으로 이어 같은 규칙으로 읽는다(sh -c "…" 안의
    명령도 본다). 연산자(&& · || · ; · | · 괄호 · 재지정)에서 조각을 나눈다 — 따옴표 안의 연산자 글자는 나누지 않는다. 따옴표
    짝이 맞지 않으면 None."""
    text = arguments.strip()
    if text.startswith("["):
        try:
            value = json.loads(text)
        except json.JSONDecodeError:
            value = None
        if isinstance(value, list) and all(isinstance(item, str) for item in value):
            text = " ".join(value)
    lexer = shlex.shlex(text, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return None
    segments: list[list[str]] = [[]]
    for token in tokens:
        if token and set(token) <= _SHELL_PUNCTUATION:
            segments.append([])
        else:
            segments[-1].append(token)
    return [segment for segment in segments if segment]


def _command_segments(arguments: str, depth: int = 0) -> list[list[str]] | None:
    """RUN 인자 → 명령 조각들(_run_segments) + 조각 안의 공백을 품은 토큰(따옴표로 묶인 셸 명령 — sh -c "…" · bash -lc '…' · bash -o
    pipefail -c '…' 따위 — T072 ③ r2 M3: 따옴표 셸 꼴이 uv sync 규칙을 비켜 갔다)을 다시 나눈 조각들(깊이 _NESTED_SHELL_DEPTH까지).
    셸 · 옵션 모양을 따지지 않고 공백을 품은 토큰이면 다시 나눈다(실행되지 않는 따옴표 글도 uv sync로 보이면 판정한다 — 엄격한 쪽).
    어느 단계든 따옴표 짝이 맞지 않으면 None."""
    segments = _run_segments(arguments)
    if segments is None:
        return None
    found = list(segments)
    if depth >= _NESTED_SHELL_DEPTH:
        return found
    for segment in segments:
        for token in segment:
            if any(char.isspace() for char in token):
                nested = _command_segments(token, depth + 1)
                if nested is None:
                    return None
                found.extend(nested)
    return found


def _uv_sync_flag_problems(item: _Instruction) -> list[str]:
    """RUN이 uv sync를 부르면(한 조각 안에서 이름이 uv인 실행 토큰 뒤에 sync — 따옴표로 묶인 셸 명령 안 포함 · _command_segments) 그
    조각의 uv 뒤에 UV_SYNC_REQUIRED_FLAGS가 모두 있어야 한다(T072 조각 ③ 지시 5 · ③ r2 M3 — --frozen은 --locked가 아니다). 읽지 못한
    RUN은 uv · sync 낱말이 보일 때만 위반이다."""
    segments = _command_segments(item.arguments)
    if segments is None:
        if _UV_SYNC_TEXT_RE.search(item.arguments):
            return [f"{item.line}행 RUN을 읽지 못했다(따옴표 짝) — uv sync 플래그를 판정할 수 없다"]
        return []
    problems: list[str] = []
    for segment in segments:
        for index, token in enumerate(segment):
            if token.startswith("-") or token.rsplit("/", 1)[-1] not in ("uv", "uv.exe"):
                continue
            rest = segment[index + 1 :]
            if "sync" in rest:
                problems.extend(
                    f"{item.line}행 RUN uv sync에 {flag} 없음(잠금 그대로 · dev 그룹 제외 · django-common 비-editable 설치 — D18 · 계약"
                    " Dockerfile 행)"
                    for flag in UV_SYNC_REQUIRED_FLAGS
                    if flag not in rest
                )
            break
    return problems


def check_dockerfile_text(text: str) -> list[str]:
    """생성 Dockerfile(D18) — 모든 FROM이 @sha256:<64 hex> digest 고정(앞 단계 이름 · scratch는 예외) · 외부 이미지를
    COPY --from으로 가져오면 그것도 고정 · # syntax= 지시자가 있으면 그것도 고정 · 마지막 단계의 마지막 USER =
    10001:10001 · 마지막 단계의 마지막 CMD에 --no-control-socket이 있고 토큰이 정확히 WEB_COMMAND(tests/_render.py — deploy/base
    web 명령 · gen-34 스모크와 같은 상수 · T072 ③ r2 M6) · 모든 ENV 줄에 금지 env 이름 0(렌더 env_hygiene과 같은 목록 — X18) ·
    uv sync를 부르는 모든 RUN에 --locked · --no-dev · --no-editable(T072 조각 ③ 지시 5 · ③ r2 M3 — _uv_sync_flag_problems)."""
    instructions, directives = _dockerfile_instructions(text)
    violations: list[str] = []
    syntax = directives.get("syntax")
    if syntax is not None and not _pinned(syntax):
        violations.append(f"파서 지시자 # syntax={syntax} — 프런트엔드 이미지도 @sha256: digest로 고정한다")
    stages: set[str] = set()
    final_start: int | None = None
    for position, item in enumerate(instructions):
        if item.keyword == "FROM":
            final_start = position
            positional = [token for token in item.arguments.split() if not token.startswith("--")]
            image = positional[0] if positional else ""
            if image.lower() in stages or image.lower() == "scratch":
                pass
            elif "$" in image:
                violations.append(f"{item.line}행 FROM {image}: 변수 이미지 참조는 digest 고정을 판정할 수 없다")
            elif not _pinned(image):
                violations.append(f"{item.line}행 FROM {image or '(이미지 없음)'}: @sha256:<64 hex> digest 고정이 없다")
            if len(positional) >= 3 and positional[1].lower() == "as":
                stages.add(positional[2].lower())
        elif item.keyword == "COPY":
            for token in item.arguments.split():
                source = token.removeprefix("--from=") if token.startswith("--from=") else None
                if source is None or source.lower() in stages or source.isdigit():
                    continue
                if "$" in source or not _pinned(source):
                    violations.append(f"{item.line}행 COPY --from={source}: 외부 이미지는 @sha256: digest로 고정한다")
        elif item.keyword == "RUN":
            violations.extend(_uv_sync_flag_problems(item))
        elif item.keyword == "ENV":
            names = _env_instruction_names(item.arguments)
            if names is None:
                violations.append(f"{item.line}행 ENV를 읽지 못했다(따옴표 짝)")
                continue
            violations.extend(
                f"{item.line}행 ENV {name}: 금지 env 이름(렌더 env_hygiene과 같은 목록 — X18)"
                for name in names
                if forbidden_env_name(name)
            )
    if final_start is None:
        return [*violations, "FROM 없음"]
    final = instructions[final_start + 1 :]
    users = [item for item in final if item.keyword == "USER"]
    if not users:
        violations.append(f"마지막 단계에 USER 없음(기대 USER {IMAGE_USER})")
    elif users[-1].arguments.strip() != IMAGE_USER:
        violations.append(f"{users[-1].line}행 마지막 단계 USER {users[-1].arguments.strip()}(기대 {IMAGE_USER} — 숫자 UID:GID)")
    commands = [item for item in final if item.keyword == "CMD"]
    if not commands:
        violations.append(f"마지막 단계에 CMD 없음(기대 {list(WEB_COMMAND)})")
    else:
        tokens = _command_tokens(commands[-1].arguments)
        if NO_CONTROL_SOCKET not in tokens:
            violations.append(f"{commands[-1].line}행 CMD에 {NO_CONTROL_SOCKET} 없음(D11 · ⑱)")
        elif tokens != list(WEB_COMMAND):
            violations.append(
                f"{commands[-1].line}행 CMD {tokens}(기대 정확히 {list(WEB_COMMAND)} — deploy/base web 명령 · gen-34 스모크와 같은 상수 ·"
                " ③ r2 M6)"
            )
    return violations


def check_image_config(inspect: Any) -> list[str]:
    """docker image inspect JSON(목록 하나 또는 객체) — Config.User = 10001:10001 · Config.Env 이름에 금지 env 0(값은
    찍지 않는다) · 라벨 org.opencontainers.image.revision이 비지 않은 문자열 · Config.Cmd == WEB_COMMAND(exec 꼴 — 셸 꼴 CMD는 PID 1이
    sh라 SIGTERM이 gunicorn에 닿지 않는다: ③ r2 리뷰 A-1 실측 15.5 s 뒤 SIGKILL) · Config.Entrypoint 없음(null 또는 [] — deploy/base의
    command + args가 실제 실행 명령이라는 전제(tests/_render.py _command) · web은 command 없이 이미지 CMD로 돈다 — T072 마지막 라운드
    N4). Dockerfile 글의 같은 뜻 판정(check_dockerfile_text의 셸 꼴 CMD 받아들임)은 그대로 두고 빌드 산출물에서 잡는다."""
    if isinstance(inspect, list):
        if len(inspect) != 1:
            return [f"docker image inspect 결과 {len(inspect)}개(기대 1)"]
        inspect = inspect[0]
    if not isinstance(inspect, dict):
        return ["docker image inspect 결과가 JSON 객체가 아니다"]
    violations: list[str] = []
    config = _dict(inspect.get("Config"))
    user = config.get("User")
    if user != IMAGE_USER:
        violations.append(f"Config.User = {user!r}(기대 {IMAGE_USER!r} — 숫자 UID:GID · 렌더 runAsUser와 같다)")
    env = config.get("Env")
    if env is not None and not isinstance(env, list):
        violations.append("Config.Env가 목록이 아니다")
    for entry in env if isinstance(env, list) else []:
        if not isinstance(entry, str):
            violations.append("Config.Env에 문자열이 아닌 항목이 있다")
            continue
        name = entry.split("=", 1)[0]
        if forbidden_env_name(name):
            violations.append(f"Config.Env {name}: 금지 env 이름(값은 찍지 않는다 — X18)")
    revision = _dict(config.get("Labels")).get(REVISION_LABEL)
    if not (isinstance(revision, str) and revision):
        violations.append(f"라벨 {REVISION_LABEL} 없음 또는 빈 값(Dockerfile LABEL — APP_GIT_SHA)")
    command = config.get("Cmd")
    if command != list(WEB_COMMAND):
        violations.append(
            f"Config.Cmd = {command!r}(기대 정확히 {list(WEB_COMMAND)} — exec 꼴 CMD: 셸 꼴은 PID 1이 sh라 SIGTERM이 gunicorn에 닿지"
            " 않는다 · deploy/base web은 이미지 CMD로 돈다 · N4)"
        )
    entrypoint = config.get("Entrypoint")
    if entrypoint is not None and entrypoint != []:
        violations.append(
            f"Config.Entrypoint = {entrypoint!r}(기대 없음 — deploy/base의 command + args가 실제 실행 명령이라는 전제 · runtime_wiring의"
            " 명령 결속 · N4)"
        )
    return violations


def check_image_probe(facts: Any) -> list[str]:
    """이미지 탐침 JSON(docker run --entrypoint python … — test_generate.py IMAGE_PROBE_SCRIPT) — uid · gid 10001 ·
    홈에 .netrc · _netrc 없음 · Python ≥ 3.13.2 · django_common이 venv(sys.prefix)의 site-packages에 있다(비-editable) ·
    django-ninja 1.7.0 · /src/packages 없음 · /src/apps/<pod> 아래(.venv 제외 — PyPI 패키지의 cacert.pem 등은 빌드
    컨텍스트가 아니다) 비밀 후보 이름 0(X27 · T072 ③ r2 M1 · 마지막 라운드 N6 — 대소문자 무관: .env* · id_rsa* · id_ed25519* · id_ecdsa* ·
    *.pem · *.key · *.crt · *.p12 · *.pfx · *.env · .netrc — 탐침이 이름의 소문자 형으로 판정한다) · 최상위 허용 목록 · 빌드 감시 파일(조각 ③
    지시 5) · venv에 dev 전용 배포(pytest · pytest-django · testcontainers · django-migration-linter) 0(T072 ③ r2 M3 — uv sync --no-dev)."""
    if not isinstance(facts, dict):
        return ["이미지 탐침 결과가 JSON 객체가 아니다"]
    violations: list[str] = []
    for key in ("uid", "gid"):
        if facts.get(key) != IMAGE_UID:
            violations.append(f"탐침 {key} = {facts.get(key)!r}(기대 {IMAGE_UID} — 이미지 USER {IMAGE_USER})")
    netrc = facts.get("netrc")
    if netrc != []:
        violations.append(f"홈 {facts.get('home')!r}에 netrc 파일 {netrc!r}(기대 없음)")
    python = facts.get("python")
    numbers = isinstance(python, list) and len(python) == 3
    numbers = numbers and all(isinstance(part, int) and not isinstance(part, bool) for part in python)
    if not numbers:
        violations.append(f"탐침 python = {python!r}(읽지 못했다)")
    elif tuple(python) < MIN_IMAGE_PYTHON:
        violations.append(f"Python {'.'.join(str(part) for part in python)}(기대 ≥ 3.13.2)")
    module_file = facts.get("django_common_file")
    prefix = facts.get("prefix")
    if not (isinstance(module_file, str) and module_file and isinstance(prefix, str) and prefix):
        violations.append(f"django_common을 import하지 못했다({facts.get('django_common_error')!r})")
    else:
        module = PurePosixPath(module_file)
        if not (module.is_relative_to(PurePosixPath(prefix)) and "site-packages" in module.parts):
            violations.append(f"django_common = {module_file}(기대 venv {prefix}의 site-packages — 비-editable · D18)")
    if facts.get("ninja_version") != IMAGE_NINJA_VERSION:
        violations.append(f"django-ninja {facts.get('ninja_version')!r}(기대 {IMAGE_NINJA_VERSION})")
    if facts.get("src_packages_exists") is not False:
        violations.append("/src/packages가 있다(런타임에 django-common 원본이 필요 없어야 한다 — --no-editable)")
    sensitive = facts.get("sensitive_files")
    if sensitive != []:
        violations.append(
            f"/src/apps/<pod> 아래 비밀 후보 이름(대소문자 무관 .env* · *.pem · *.key · *.crt · *.p12 · *.pfx · *.env · .netrc · id_rsa* ·"
            f" id_ed25519* · id_ecdsa*): {sensitive!r}(dockerignore 재제외 — X27 · ③ r2 M1 · N6)"
        )
    violations.extend(_pod_entry_problems(facts.get("pod_entries")))
    sentinel = facts.get("venv_sentinel")
    if sentinel is True:
        violations.append(
            f"빌드 감시 파일 .venv/{IMAGE_VENV_SENTINEL}이 이미지에 있다 — 빌드 컨텍스트의 .venv가 들어왔다(dockerignore **/.venv"
            " 재제외 · D18)"
        )
    elif sentinel is not False:
        violations.append(f"빌드 감시 파일 .venv/{IMAGE_VENV_SENTINEL} 판정을 읽지 못했다({sentinel!r})")
    dev = facts.get("dev_distributions")
    if not (isinstance(dev, list) and all(isinstance(name, str) for name in dev)):
        violations.append(f"dev 전용 배포 판정을 읽지 못했다({dev!r})")
    elif dev:
        violations.append(f"이미지 venv에 dev 전용 배포 {dev}(uv sync --no-dev — 계약 Dockerfile 행 · D18 · ③ r2 M3)")
    return violations


def _pod_entry_problems(entries: Any) -> list[str]:
    """/src/apps/<pod> 최상위 항목 이름 = IMAGE_POD_ENTRIES(집합 비교 — 빠진 것 · 남는 것 둘 다 위반 · T072 조각 ③ 지시 5)."""
    expected = sorted(IMAGE_POD_ENTRIES)
    if not (isinstance(entries, list) and all(isinstance(name, str) for name in entries)):
        return [f"/src/apps/<pod> 최상위 항목을 읽지 못했다({entries!r} — 기대 {expected})"]
    violations: list[str] = []
    missing = sorted(IMAGE_POD_ENTRIES - set(entries))
    extra = sorted(set(entries) - IMAGE_POD_ENTRIES)
    if missing:
        violations.append(f"/src/apps/<pod> 최상위에 {missing}이(가) 없다(기대 {expected} — D18)")
    if extra:
        violations.append(
            f"/src/apps/<pod> 최상위에 허용 밖 항목 {extra}(기대 {expected} — Dockerfile.dockerignore 재제외 · D18 · X27)"
        )
    return violations


# ---------- gen-34 기동 스모크 판정(D7 · D21 · X22 · X25) ----------

STARTUP_FAILURE_RE = re.compile(r"startup_check: FAIL ([A-Za-z_][A-Za-z0-9_.]*)")
TRACEBACK_MARKER = "Traceback (most recent call last)"
WRITE_ERROR_MARKERS = ("Read-only file system", "PermissionError")
# DB 없음(닫힌 포트)의 실패 사유 — psycopg · django.db 둘 다 이 이름이다(T072 r2 E3 · r1 A-3 · B-1)
DB_FAILURE_CLASS = "OperationalError"
# 예외 줄(트레이스백 끝 · 연쇄 예외의 머리 — 0열에서 시작): 점으로 이은 모듈 경로 + 클래스 이름 + ':' 또는 줄 끝
_DB_FAILURE_LINE_RE = re.compile(r"(?:[A-Za-z_][A-Za-z0-9_]*\.)*OperationalError(?::|$)")
_WRONG_FAILURE_LINE_RE = re.compile(r"(?:[A-Za-z_][A-Za-z0-9_]*\.)*(ImproperlyConfigured|ImportError|ModuleNotFoundError)(?::|$)")
UNKNOWN_COMMAND_MARKER = "Unknown command"


def check_startup_failure(returncode: int | None, stdout: str, stderr: str) -> list[str]:
    """startup_check --wait 1(DB 없음)의 최종 실패 — 종료 코드 1 · stderr가 정확히 한 줄 'startup_check: FAIL <예외
    클래스 이름>'(메시지 · 값 없음) · 그 이름의 접미가 OperationalError(DB 접속 실패 — 드라이버 적재 실패 ImportError ·
    설정 오류 따위로 끝난 실패는 통과가 아니다 · T072 r2 E3) · stdout · stderr에 트레이스백 없음(D7 · X25)."""
    violations: list[str] = []
    if returncode != 1:
        violations.append(f"startup_check --wait 1 종료 코드 {returncode}(기대 1 — DB 없음)")
    lines = [line.strip() for line in stderr.splitlines() if line.strip()]
    match = STARTUP_FAILURE_RE.fullmatch(lines[0]) if len(lines) == 1 else None
    if len(lines) != 1:
        violations.append(f"stderr {len(lines)}줄(기대 한 줄 'startup_check: FAIL <예외 클래스 이름>')")
    elif match is None:
        violations.append("stderr 줄이 'startup_check: FAIL <예외 클래스 이름>' 꼴이 아니다(메시지 · 값을 싣지 않는다 — X25)")
    elif not match.group(1).endswith(DB_FAILURE_CLASS):
        violations.append(f"startup_check 실패 사유 {match.group(1)}(기대 접미 {DB_FAILURE_CLASS} — DB 없음으로 끝나야 한다)")
    if TRACEBACK_MARKER in stdout or TRACEBACK_MARKER in stderr:
        violations.append("출력에 트레이스백이 있다(최종 실패는 예외 클래스 이름 한 줄 — D7 · X25)")
    return violations


def check_purge_failure(result: ProcResult) -> list[str]:
    """outbox_purge(DB 없음)의 실패 사유(T072 r2 E3 · r1 A-3 · B-1) — 종료 코드가 0 · None(시간 초과)이 아니다 · stderr에
    OperationalError 예외 줄(0열 — 모듈 경로가 붙은 꼴 포함 · 마지막 줄로 고정하지 않는다: psycopg 접속 오류 문구가 여러
    줄이고 django.db가 psycopg 예외를 연쇄로 감싼다)이 있다 · Unknown command · ImproperlyConfigured · ImportError ·
    ModuleNotFoundError 줄이 없다(명령 · 설정 · 모듈 적재에서 끝난 실패는 통과가 아니다). 트레이스백은 허용한다 —
    outbox_purge는 django-common 명령 그대로이고(D13 · D1) X25 출력 규칙은 템플릿 코드에만 건다(D21 ④ 개정). 심은 비밀
    누출은 check_secret_leaks가 따로 본다."""
    violations: list[str] = []
    if result.returncode in (0, None):
        violations.append(f"outbox_purge 종료 코드 {result.returncode}(기대 0이 아님 — DB 없음 · None = 시간 초과 · 실행 실패)")
    lines = [line.rstrip() for line in result.stderr.splitlines()]
    if not any(_DB_FAILURE_LINE_RE.match(line) for line in lines):
        violations.append(f"stderr에 {DB_FAILURE_CLASS} 예외 줄이 없다(DB 접속 실패로 끝나야 한다)")
    wrong = sorted({match.group(1) for line in lines if (match := _WRONG_FAILURE_LINE_RE.match(line))})
    if wrong:
        violations.append(f"stderr에 {wrong} 예외 줄이 있다(명령 · 설정 · 모듈 적재에서 끝났다 — DB 단계까지 가지 못했다)")
    if any(line.lstrip().startswith(UNKNOWN_COMMAND_MARKER) for line in lines):
        violations.append(f"stderr에 {UNKNOWN_COMMAND_MARKER!r} — 관리 명령이 없다")
    return violations


def check_container_logs(result: ProcResult) -> list[str]:
    """docker logs 결과(T072 r2 E9 · r1 B-3) — 실패 · 시간 초과면 로그 단언(쓰기 오류 · 심은 비밀)을 판정할 수 없다(빈 글로
    통과하지 않게 문제 한 줄)."""
    if result.ok:
        return []
    code = "시간 초과 · 실행 실패" if result.returncode is None else f"exit {result.returncode}"
    return [f"docker logs 실패({code}) — 로그 단언을 판정할 수 없다"]


def check_log_write_errors(text: str) -> list[str]:
    """컨테이너 로그의 쓰기 오류 흔적(읽기 전용 루트 · 쓰기는 /tmp만) — 'Read-only file system' · 'PermissionError'."""
    return [
        f"로그에 {marker!r} {text.count(marker)}건(읽기 전용 루트에 쓰려 했다 — /tmp만 쓴다)"
        for marker in WRITE_ERROR_MARKERS
        if marker in text
    ]


# 부분 누출 창(T072 r2 E8 · r1 B-2): 값의 SECRET_WINDOW자 이상 연속 부분(앞 · 뒤 절반 포함)도 누출이다. 더 짧은 값은 값
# 전체로만 찾는다(짧은 조각은 우연 일치와 구별할 수 없다).
SECRET_WINDOW = 16


def _secret_spans(text: str, value: str) -> list[tuple[int, int]]:
    """text 안에서 value 전체 또는 value의 SECRET_WINDOW자 창이 나오는 구간들 — 길이 ≥ 창인 부분 문자열은 겹치는 창들의
    합집합이므로 창만 찾으면 된다."""
    if not value:
        return []
    width = min(SECRET_WINDOW, len(value))
    spans: list[tuple[int, int]] = []
    for start in range(len(value) - width + 1):
        window = value[start : start + width]
        position = text.find(window)
        while position != -1:
            spans.append((position, position + width))
            position = text.find(window, position + 1)
    return spans


def mask_secrets(text: str, planted: Mapping[str, str]) -> str:
    """심은 비밀 값(전체와 SECRET_WINDOW자 이상 부분)을 <이름>으로 가린다 — 자르기(tail) 전에 부른다(경계에 걸친 꼬리가 남지
    않게 · E8)."""
    for name, value in planted.items():
        spans = sorted(_secret_spans(text, value))
        if not spans:
            continue
        merged: list[list[int]] = []
        for start, end in spans:
            if merged and start <= merged[-1][1]:
                merged[-1][1] = max(merged[-1][1], end)
            else:
                merged.append([start, end])
        pieces: list[str] = []
        cursor = 0
        for start, end in merged:
            pieces.append(text[cursor:start])
            pieces.append(f"<{name}>")
            cursor = end
        pieces.append(text[cursor:])
        text = "".join(pieces)
    return text


def check_secret_leaks(text: str, planted: Mapping[str, str]) -> list[str]:
    """출력에 심은 비밀 값이 있는가 — 값 전체 또는 SECRET_WINDOW자 이상 연속 부분(E8 · r1 B-2: 잘린 DSN · 앞 N자 지문).
    위반 문구에는 이름만 싣는다(값은 찍지 않는다). 빈 값은 찾지 않는다."""
    violations: list[str] = []
    for name, value in planted.items():
        if not value or not _secret_spans(text, value):
            continue
        whole = "" if value in text else f"의 {SECRET_WINDOW}자 이상 부분"
        violations.append(f"출력에 심은 비밀 값({name}){whole}이 있다")
    return violations


class SmokeLog:
    """이미지 기동 스모크 한 가지의 문제 · 단계 기록(T072 gen-34). 출력은 심은 비밀(값 전체와 SECRET_WINDOW자 이상 부분)을
    <이름>으로 가린 뒤에 자른다(가리기가 자르기 앞 — E8 · r1 B-2). 누출 판정(check_secret_leaks)은 가리기 전 원문(raw_outputs)
    으로 한다. add_raw는 출력하지 않고 판정에만 쓰는 원문(HTTP 탐침 본문 — E9)."""

    def __init__(self, kind: str, planted: Mapping[str, str]) -> None:
        self.kind = kind
        self.planted = dict(planted)
        self.problems: list[str] = []
        self.notes: list[str] = []
        self.raw_outputs: list[str] = []

    def record(self, result: ProcResult, why: str) -> ProcResult:
        self.raw_outputs.append(result.stdout + "\n" + result.stderr)
        masked = replace(result, stdout=mask_secrets(result.stdout, self.planted), stderr=mask_secrets(result.stderr, self.planted))
        self.notes.append(describe(masked, why))
        return result

    def add_raw(self, text: str) -> None:
        self.raw_outputs.append(text)

    def finish(self, logs: str, cleanups: Sequence[str | None]) -> SmokeRun:
        self.raw_outputs.append(logs)
        self.problems.extend(check_secret_leaks("\n".join(self.raw_outputs), self.planted))
        self.problems.extend(item for item in cleanups if item)
        masked_logs = mask_secrets(logs, self.planted)
        if masked_logs.strip():
            self.notes.append("--- 컨테이너 로그 꼬리 ---\n" + tail(masked_logs))
        transcript = mask_secrets("\n".join(self.notes), self.planted)
        return SmokeRun(self.kind, tuple(self.problems), transcript)


# ==================== T072 조각 ③ r2(리뷰 r1 반영 — design/t072-design.md 〔③ r2 …〕) ====================

# ---------- M1 · M2(a) 생성 Dockerfile.dockerignore 정적 검사(gen-33) ----------

DOCKERIGNORE_FILE = "Dockerfile.dockerignore"
# pod 안까지 허용 목록(③ r2 M1 · D18 · X27) — 첫 패턴 '*' 뒤에 이 여섯만 그 순서로 다시 넣는다
DOCKERIGNORE_ALLOW = (
    f"apps/{POD_NAME}/{POD_SNAKE}",
    f"apps/{POD_NAME}/manage.py",
    f"apps/{POD_NAME}/pyproject.toml",
    f"apps/{POD_NAME}/{LOCK_FILE}",
    "packages/django-common/pyproject.toml",
    "packages/django-common/src",
)
# 다시 넣은 것 안에서 다시 뺀다(마지막 '!' 뒤 — 뒤 줄이 앞 줄을 이긴다): 캐시 · venv · 비밀 후보(*.crt · *.p12 · *.pfx 포함 — 탐침의
# tests/_proc.py IMAGE_SENSITIVE_PREFIXES · SUFFIXES · NAMES와 같은 집합). T072 마지막 라운드 N6(③ r2 리뷰 B-1 실측 — CASE.PEM · .KEY ·
# .Crt · .Env.prod · id_rsa · *.env · .netrc가 공개 이미지에 실렸다): 접미 다섯과 .env*는 대소문자 무관 꼴(문자 집합 — BuildKit은 Go
# filepath.Match 규칙이라 Windows 컨텍스트에서도 글자를 가린다) · 흔한 비밀 이름 꼴 *.env · .netrc · id_rsa* · id_ed25519* · id_ecdsa*.
# T072 마감 라운드 Z3(마지막 리뷰 B-1 실측 — ID_RSA · LOCAL.ENV · .NETRC · ID_ED25519 · Id_Ecdsa가 이미지에 실렸다): 이름 꼴 다섯도 대소문자
# 무관 꼴이다 — 비밀 후보 꼴 열하나가 모두 탐침(이름의 소문자 형으로 판정)과 같은 집합을 거른다.
DOCKERIGNORE_REEXCLUDE = (
    "**/__pycache__",
    "**/*.py[co]",
    "**/.pytest_cache",
    f"**/{VENV_DIR}",
    "**/.[eE][nN][vV]*",
    "**/*.[eE][nN][vV]",
    "**/*.[pP][eE][mM]",
    "**/*.[kK][eE][yY]",
    "**/*.[cC][rR][tT]",
    "**/*.[pP]12",
    "**/*.[pP][fF][xX]",
    "**/.[nN][eE][tT][rR][cC]",
    "**/[iI][dD]_[rR][sS][aA]*",
    "**/[iI][dD]_[eE][dD]25519*",
    "**/[iI][dD]_[eE][cC][dD][sS][aA]*",
    "**/.git*",
)
_UTF8_BOM = chr(0xFEFF)
# Go strings.TrimSpace가 다듬는 글자(unicode.IsSpace) — Python str.strip()과 달리 \x1c–\x1f는 다듬지 않는다
_GO_SPACE = "".join(
    chr(code) for code in (9, 10, 11, 12, 13, 32, 0x85, 0xA0, 0x1680, *range(0x2000, 0x200B), 0x2028, 0x2029, 0x202F, 0x205F, 0x3000)
)


def _clean_pattern(pattern: str) -> str:
    """Go filepath.Clean + ToSlash + 앞 '/' 떼기(Docker ignorefile)의 POSIX 꼴 — 겹 '/' · '.' · '..' · 끝 '/'를 정리한다."""
    cleaned = posixpath.normpath(re.sub(r"/{2,}", "/", pattern))
    if len(cleaned) > 1 and cleaned.startswith("/"):
        cleaned = cleaned[1:]
    return cleaned


def dockerignore_patterns(text: str) -> list[str]:
    """.dockerignore 글 → 패턴 목록 — Docker(moby/patternmatcher ignorefile.ReadAll)와 같은 규칙: 줄은 LF로 나누고 끝 CR을 뗀다 · 첫 줄의
    UTF-8 BOM을 뗀다 · 0열 '#'로 시작하는 줄만 주석이다(다듬기 전 — 공백 뒤의 '#'는 패턴이다) · 앞뒤 공백을 다듬고 빈 줄을 버린다 · '!'
    뒤 공백을 다듬는다 · 경로를 정리하고 앞 '/'를 뗀다. 반환은 '!'를 붙인 꼴 그대로다."""
    patterns: list[str] = []
    for index, raw in enumerate(text.split("\n")):
        line = raw[:-1] if raw.endswith("\r") else raw
        if index == 0:
            line = line.removeprefix(_UTF8_BOM)
        if line.startswith("#"):
            continue
        pattern = line.strip(_GO_SPACE)
        if not pattern:
            continue
        invert = pattern.startswith("!")
        if invert:
            pattern = pattern[1:].strip(_GO_SPACE)
        if pattern:
            pattern = _clean_pattern(pattern)
        patterns.append(("!" if invert else "") + pattern)
    return patterns


def check_dockerignore_text(text: str) -> list[str]:
    """생성 Dockerfile.dockerignore(T072 ③ r2 M1 · M2(a) · D18 · X27) — 결정적 정적 검사(플랫폼 · uv 동작 · 작업 트리와 무관 — Linux에서
    .venv 감시 파일이 공허해도 잡는다): Docker 규칙으로 읽은 패턴(dockerignore_patterns)의 첫째가 '*' · '!' 패턴이 정확히 DOCKERIGNORE_ALLOW
    여섯이고 그 순서다(다른 '!'가 하나라도 있으면 허용 목록이 넓어진다 — 조각 ③의 !apps/<pod>는 작업 트리의 무엇이든 다시 넣었다) ·
    DOCKERIGNORE_REEXCLUDE(열여섯 — 비밀 후보 꼴 열하나는 모두 대소문자 무관 꼴 · 비밀 이름 꼴 포함 · 마지막 라운드 N6 · 마감 라운드 Z3)가
    모두 마지막 '!' 뒤에 있다(앞에 있으면 뒤의 '!'가 다시 넣는다). 그 밖의 제외 줄은 허용한다(더 좁힐 뿐이다)."""
    patterns = dockerignore_patterns(text)
    if not patterns:
        return [f"{DOCKERIGNORE_FILE}에 패턴이 없다(기대 첫 패턴 '*' + 허용 목록 — X27 · ③ r2 M1)"]
    violations: list[str] = []
    if patterns[0] != "*":
        violations.append(f"{DOCKERIGNORE_FILE} 첫 패턴 {patterns[0]!r}(기대 '*' — 전부 빼고 허용 목록만 다시 넣는다 · X27)")
    allows = [pattern[1:] for pattern in patterns if pattern.startswith("!")]
    if allows != list(DOCKERIGNORE_ALLOW):
        violations.append(
            f"{DOCKERIGNORE_FILE} '!' 패턴 {allows}(기대 정확히 {list(DOCKERIGNORE_ALLOW)} 그 순서 — pod 안까지 허용 목록 · ③ r2 M1)"
        )
    last_allow = max((index for index, pattern in enumerate(patterns) if pattern.startswith("!")), default=0)
    after = patterns[last_allow + 1 :]
    missing = [pattern for pattern in DOCKERIGNORE_REEXCLUDE if pattern not in after]
    if missing:
        violations.append(
            f"{DOCKERIGNORE_FILE} 마지막 '!' 뒤에 재제외 {missing} 없음(캐시 · .venv · 비밀 후보 — 뒤 줄이 앞 줄을 이긴다 · X27 · ③ r2 M1)"
        )
    return violations


# ---------- M2(b) 심은 빌드 감시 파일 기록(conftest.py image → gen-33) ----------


def check_planted_sentinels(planted: Any, expected: Sequence[str]) -> list[str]:
    """image 픽스처가 실제로 심은 빌드 감시 파일(conftest.py build_with_sentinels(record=…) → config.stash — T072 ③ r2 M2(b)) =
    expected(BUILD_SENTINEL_FILES ∪ VENV_SENTINEL · 순서 무관). 심기가 빠지거나 줄면 gen-33의 감시 파일 판정(sensitive · 최상위 허용
    목록 · venv_sentinel)이 소리 없이 공허해진다 — 기록이 없거나 목록이 다르면 위반이다."""
    if planted is None:
        return ["빌드 감시 파일 심기 기록이 없다(image 픽스처가 build_with_sentinels(record=…)로 빌드하고 기록해야 한다 — ③ r2 M2(b))"]
    if not (isinstance(planted, (list, tuple)) and all(isinstance(item, str) for item in planted)):
        return [f"빌드 감시 파일 심기 기록을 읽지 못했다({planted!r} — 기대 pod 기준 상대 경로 목록)"]
    violations: list[str] = []
    duplicated = sorted({item for item in planted if planted.count(item) > 1})
    if duplicated:
        violations.append(f"빌드 감시 파일 심기 기록에 중복 {duplicated}")
    missing = sorted(set(expected) - set(planted))
    extra = sorted(set(planted) - set(expected))
    if missing or extra:
        violations.append(
            f"심은 빌드 감시 파일이 기대와 다르다 — 빠진 것 {missing} · 남는 것 {extra}(기대 {sorted(expected)} — 빠지면 그 감시 파일의"
            " 판정이 공허해진다)"
        )
    return violations


# ---------- M4 build-arg 배선(docker image inspect + image 픽스처가 준 값 → gen-33) ----------

APP_BUILD_ARGS = ("APP_VERSION", "APP_GIT_SHA")


def check_image_build_args(inspect: Any, given: Mapping[str, str] | None) -> list[str]:
    """docker image inspect JSON + image 픽스처가 준 --build-arg(T072 ③ r2 M4 · 계약 Dockerfile 행 「build-arg APP_VERSION · APP_GIT_SHA →
    ENV + 라벨 revision」 · T074 publish의 전제) — 라벨 org.opencontainers.image.revision == Config.Env APP_GIT_SHA == 준 APP_GIT_SHA ·
    Config.Env APP_VERSION == 준 APP_VERSION(Env 항목은 이름마다 정확히 하나). LABEL · ENV에 리터럴을 두면(ARG 배선이 끊기면) 준 값과
    달라 잡힌다. 값은 비밀이 아니다(하네스 난수 · 판 문자열) — 위반 문구에 싣는다."""
    if given is None:
        return ["build-arg 기록이 없다(image 픽스처가 --build-arg APP_GIT_SHA · APP_VERSION을 주고 기록해야 한다 — ③ r2 M4)"]
    if isinstance(inspect, list):
        if len(inspect) != 1:
            return [f"docker image inspect 결과 {len(inspect)}개(기대 1)"]
        inspect = inspect[0]
    if not isinstance(inspect, dict):
        return ["docker image inspect 결과가 JSON 객체가 아니다"]
    config = _dict(inspect.get("Config"))
    env = config.get("Env")
    entries = [entry for entry in env if isinstance(entry, str)] if isinstance(env, list) else []
    violations: list[str] = []
    for name in APP_BUILD_ARGS:
        values = [entry.split("=", 1)[1] for entry in entries if "=" in entry and entry.split("=", 1)[0] == name]
        if len(values) != 1:
            violations.append(f"Config.Env {name} 항목 {len(values)}개(기대 1 — Dockerfile ENV {name}=${name})")
        elif values[0] != given.get(name):
            violations.append(f"Config.Env {name} = {values[0]!r}(기대 준 build-arg {given.get(name)!r} — ARG → ENV 배선)")
    revision = _dict(config.get("Labels")).get(REVISION_LABEL)
    if revision != given.get("APP_GIT_SHA"):
        violations.append(
            f"라벨 {REVISION_LABEL} = {revision!r}(기대 준 build-arg APP_GIT_SHA {given.get('APP_GIT_SHA')!r} — ARG → LABEL 배선)"
        )
    return violations


# ---------- M5 compose config 내용(docker compose -f compose.dev.yml config --format json → gen-35) ----------

COMPOSE_LOOPBACK = "127.0.0.1"
COMPOSE_PG_CONTEXT = ("tests", "docker", "pg-tls")
_ACLFILE_FLAG = "--aclfile"
_HTTP_FLAG = "primary_port_http_enabled"
# abseil 불 플래그의 거짓 값(대소문자 무시 — Dragonfly는 abseil 플래그를 쓴다)
_ABSEIL_FALSE = frozenset({"false", "f", "no", "n", "0"})


def _aclfile_path(command: list[str]) -> str | None:
    """--aclfile=<경로> · --aclfile <경로>의 마지막 값(abseil — 뒤 값이 이긴다). 없으면 None."""
    found: str | None = None
    for index, token in enumerate(command):
        if token.startswith(f"{_ACLFILE_FLAG}="):
            found = token.split("=", 1)[1]
        elif token == _ACLFILE_FLAG and index + 1 < len(command):
            found = command[index + 1]
    return found


def _http_enabled(command: list[str]) -> bool:
    """Dragonfly 주 포트 HTTP가 켜지는가 — 기본 켜짐 · --primary_port_http_enabled[=값] · --noprimary_port_http_enabled 가운데 마지막이
    정한다(거짓 값이 아니면 켜짐 — 엄격한 쪽)."""
    enabled = True
    for token in command:
        if token == f"--no{_HTTP_FLAG}":
            enabled = False
        elif token == f"--{_HTTP_FLAG}":
            enabled = True
        elif token.startswith(f"--{_HTTP_FLAG}="):
            enabled = token.split("=", 1)[1].strip().lower() not in _ABSEIL_FALSE
    return enabled


def _same_path(left: str, right: str) -> bool:
    """같은 경로인가 — 링크 · 대소문자(Windows)를 푼 뒤 견준다(compose는 build context를 절대 경로로 싣는다)."""
    return os.path.normcase(os.path.realpath(left)) == os.path.normcase(os.path.realpath(right))


def _dragonfly_problems(dragonfly: dict[str, Any]) -> list[str]:
    command = dragonfly.get("command")
    tokens = [str(token) for token in command] if isinstance(command, list) else []
    violations: list[str] = []
    aclfile = _aclfile_path(tokens)
    if aclfile is None:
        violations.append(
            "dragonfly command에 --aclfile=<경로>가 없다(aclfile이 없으면 default 사용자가 nopass +@all — 루프백 bind만 경계가 된다 · C4)"
        )
    else:
        mounts = [
            volume
            for volume in dragonfly.get("volumes") or []
            if isinstance(volume, dict)
            and isinstance(volume.get("target"), str)
            and posixpath.normpath(volume["target"]) == posixpath.normpath(aclfile)
        ]
        if not mounts:
            violations.append(f"dragonfly --aclfile={aclfile}을 target으로 마운트한 볼륨이 없다(compose/dragonfly-dev.acl)")
        for volume in mounts:
            if volume.get("read_only") is not True:
                violations.append(
                    f"dragonfly aclfile 볼륨({aclfile}) read_only = {volume.get('read_only')!r}(기대 True — ACL SAVE · 덮어쓰기 금지)"
                )
    if _http_enabled(tokens):
        violations.append(
            "dragonfly 주 포트 HTTP가 켜져 있다(command에 --primary_port_http_enabled=false 없음 — 운영 Deployment와 같게 끈다: 인증 없는"
            " 상태 페이지 · /metrics · /profilez · ③ r2 M5)"
        )
    return violations


COMPOSE_FILE = "compose.dev.yml"


def compose_config_argv(docker: str) -> list[str]:
    """gen-35의 docker compose config 명령(T072 마지막 라운드 N5 · ③ r2 리뷰 A-2) — `--profile "*"`로 모든 프로필을 펼친다: 프로필로
    묶은 서비스(도구 서비스 등)는 기본 `config` 출력에서 빠지고, 허용 목록 env는 COMPOSE_PROFILES도 지우므로 프로필 없이는 그 서비스가
    판정 밖이었다. 셸 없이 넘기므로 "*"는 글자 그대로 Compose에 닿는다."""
    return [docker, "compose", "-f", COMPOSE_FILE, "--profile", "*", "config", "--format", "json"]


# gen-35 프로필 펼침 탐침(T072 마감 라운드 Z2 · 마지막 리뷰 A-2) — 생성 compose.dev.yml에는 프로필 서비스가 없어 '*'는 펼칠 것이 없다:
# '*'를 모르는 Compose(→ '*'를 프로필 이름 하나로 받는다)에서도 gen-35는 초록이었다. 그래서 gen-35가 임시 디렉터리에 이 파일(이름
# COMPOSE_FILE — 같은 argv)을 쓰고 compose_config_argv(허용 목록 env)로 config를 돌려 프로필로만 켜지는 탐침 서비스가 출력에 있는지 본다
# (check_compose_profile_probe). 이미지는 받지 않는 가짜 이름이다(config는 이미지를 받지 않는다) · 프로젝트 이름은 고정이다(임시 디렉터리
# 이름에 기대지 않는다).
COMPOSE_PROFILE_PROBE_SERVICE = "jt-probe-service"
COMPOSE_PROFILE_PROBE_PROFILE = "jt-probe"
COMPOSE_PROFILE_PROBE_TEXT = (
    "name: jt-compose-profile-probe\n"
    "services:\n"
    f"  {COMPOSE_PROFILE_PROBE_SERVICE}:\n"
    "    image: jt-compose-profile-probe:none\n"
    f"    profiles: [{COMPOSE_PROFILE_PROBE_PROFILE}]\n"
)


def check_compose_profile_probe(config: Any) -> list[str]:
    """프로필 펼침 탐침의 docker compose … config --format json(T072 마감 라운드 Z2 · 마지막 리뷰 A-2) — services 매핑에
    COMPOSE_PROFILE_PROBE_SERVICE가 있다(프로필 COMPOSE_PROFILE_PROBE_PROFILE로만 켜지는 서비스 — compose_config_argv의 --profile "*"가 모든
    프로필을 켰다). 없으면(빈 services · services 없음 — 프로필 밖 서비스는 출력에서 빠진다) 이 Compose는 '*'를 펼치지 않는다: gen-35가 프로필
    서비스를 보지 못하고 공허하게 초록이 된다. JSON 객체가 아니거나 services가 매핑이 아니면 읽지 못한 것이다."""
    if not isinstance(config, dict):
        return ["프로필 펼침 탐침의 docker compose config 결과를 읽지 못했다(JSON 객체가 아니다)"]
    services = config.get("services", {})
    if not isinstance(services, dict):
        return [f"프로필 펼침 탐침의 services를 읽지 못했다({type(services).__name__} — 기대 매핑)"]
    if COMPOSE_PROFILE_PROBE_SERVICE not in services:
        return [
            '이 Compose는 --profile "*"를 펼치지 않는다 — gen-35가 프로필 서비스를 보지 못한다(프로필'
            f" {COMPOSE_PROFILE_PROBE_PROFILE}만 든 탐침 서비스 {COMPOSE_PROFILE_PROBE_SERVICE}가 config 출력 services {sorted(services)}에 없다)"
        ]
    return []


def check_compose_config(config: Any, project_dir: str | os.PathLike[str]) -> list[str]:
    """docker compose -f compose.dev.yml --profile "*" config --format json(T072 ③ r2 M5 · 계약 C4 compose.dev.yml 행 · D19 · 모든 프로필
    포함 — compose_config_argv · 마지막 라운드 N5) — 허용 목록 env(셸의
    JT_DEV_*_PORT · POSTGRES_PASSWORD · COMPOSE_* 없음 — 기본값)로 정규화한 설정: 모든 서비스(모든 프로필 포함)의 published 포트 host_ip = 127.0.0.1 ·
    network_mode host 없음 · build가 아닌 image는 전부 @sha256:<64 hex> · dragonfly command의 --aclfile=<경로>(마지막 값)를 target으로
    마운트한 볼륨이 read_only · 주 포트 HTTP 끔(--primary_port_http_enabled=false — 운영 Deployment와 같다) · postgres build context =
    <project_dir>/tests/docker/pg-tls(TLS 전용 이미지)."""
    if not (isinstance(config, dict) and isinstance(config.get("services"), dict)):
        return ["docker compose config 결과를 읽지 못했다(JSON 객체 · services 매핑이 아니다)"]
    services: dict[str, Any] = config["services"]
    violations: list[str] = []
    for name, raw in services.items():
        service = _dict(raw)
        if service.get("network_mode") == "host":
            violations.append(f"{name}: network_mode host(호스트의 모든 인터페이스에 열린다 — 포트는 {COMPOSE_LOOPBACK}에만)")
        ports = service.get("ports", [])
        if not isinstance(ports, list):
            violations.append(f"{name}: ports를 읽지 못했다({ports!r})")
            ports = []
        for port in ports:
            entry = _dict(port)
            if entry.get("host_ip") != COMPOSE_LOOPBACK:
                violations.append(
                    f"{name}: published 포트 {entry.get('published')!r} → {entry.get('target')!r}의 host_ip {entry.get('host_ip')!r}(기대"
                    f" {COMPOSE_LOOPBACK!r} — 루프백에만 연다 · C4)"
                )
        if "build" not in service:
            image = service.get("image")
            if not (isinstance(image, str) and _pinned(image)):
                violations.append(f"{name}: image {image!r}(build가 아니면 @sha256:<64 hex> digest로 고정한다 · C4)")
    dragonfly = services.get("dragonfly")
    if isinstance(dragonfly, dict):
        violations.extend(_dragonfly_problems(dragonfly))
    else:
        violations.append("dragonfly 서비스가 없다(aclfile · 주 포트 HTTP를 판정할 수 없다)")
    postgres = services.get("postgres")
    if isinstance(postgres, dict):
        context = _dict(postgres.get("build")).get("context")
        expected = os.path.join(os.fspath(project_dir), *COMPOSE_PG_CONTEXT)
        if not (isinstance(context, str) and _same_path(context, expected)):
            violations.append(f"postgres build context {context!r}(기대 {expected!r} — tests/docker/pg-tls TLS 전용 이미지 · C4)")
    else:
        violations.append("postgres 서비스가 없다(tests/docker/pg-tls build를 판정할 수 없다)")
    return violations


# ---------- M11 copier 예약 이름(템플릿이 정하는 두 묶음 → gen-37) ----------

_RESERVED_LIST_RE = re.compile(r"\{%-?\s*set\s+reserved\s*=\s*\[(.*?)\]\s*-?%\}", re.DOTALL)


def copier_reserved_names(copier_text: str) -> frozenset[str] | None:
    """copier.yml pod_name validator의 {% set reserved = [ … ] %} 목록(문자열 리터럴 — T072 ③ r2 M11). 읽지 못하면 None."""
    config, problem = _load_yaml(copier_text)
    if problem is not None or not isinstance(config, dict):
        return None
    validator = _dict(config.get("pod_name")).get("validator")
    match = _RESERVED_LIST_RE.search(validator) if isinstance(validator, str) else None
    if match is None:
        return None
    try:
        names = ast.literal_eval("[" + match.group(1) + "]")
    except (ValueError, SyntaxError):
        return None
    if not (isinstance(names, list) and all(isinstance(name, str) for name in names)):
        return None
    return frozenset(names)


def template_top_level_names() -> frozenset[str]:
    """생성 트리의 최상위 이름 가운데 pod 패키지 디렉터리(<pod_snake>/)와 부딪히거나 합쳐질 수 있는 것(T072 ③ r2 M11 · ② r3 A-3) —
    REQUIRED_FILES ∪ REQUIRED_DIRS ∪ T072_FILES ∪ 조건부 파일(celery · CronJob · admin · consumer) ∪ T072_FILE_PATTERNS의 첫 경로 조각
    가운데 점이 없는 것(pod_snake는 점을 품을 수 없다)의 소문자 형(대소문자를 가리지 않는 파일 시스템에서 Dockerfile과 dockerfile/이
    부딪힌다) — pod 패키지 자신은 뺀다."""
    paths = (
        *REQUIRED_FILES,
        *REQUIRED_DIRS,
        *T072_FILES,
        *T072_CELERY_FILES,
        *T072_CRONJOB_FILES,
        *T072_ADMIN_FILES,
        *T072_CONSUMER_FILES,
        *T072_FILE_PATTERNS,
    )
    tops = {path.split("/", 1)[0] for path in paths}
    return frozenset(top.lower() for top in tops if "." not in top and top != POD_SNAKE)


# 생성 트리 최상위 이름의 snake 꼴(소문자 형 — 대소문자를 가리지 않는 파일 시스템에서 Dockerfile과 dockerfile/이 부딪힌다)
_TOP_LEVEL_NAME_RE = re.compile(r"[a-z][a-z0-9_]*")


def generated_top_level_names(pod: Path) -> frozenset[str]:
    """실제 생성 트리 최상위 항목(파일 · 디렉터리) 가운데 pod 패키지 디렉터리와 부딪히거나 합쳐질 수 있는 이름(T072 마지막 라운드 N7 · ③ r2
    리뷰 B-3) — 점 없는 이름의 소문자 형이 snake 꼴([a-z][a-z0-9_]*)인 것, pod 패키지(<pod_snake>) 제외. 점 든 이름(.venv · .copier-answers.yml
    · Dockerfile.dockerignore)과 __pycache__(밑줄 머리)는 빠진다. gen-37이 template_top_level_names(하네스 상수)와 합쳐 판정한다 — 템플릿에
    새 최상위 항목을 더하고 상수를 고치지 않아도 잡는다."""
    return frozenset(
        lowered
        for lowered in (entry.name.lower() for entry in pod.iterdir() if "." not in entry.name)
        if _TOP_LEVEL_NAME_RE.fullmatch(lowered) and lowered != POD_SNAKE
    )


def check_reserved_pod_names(reserved: frozenset[str] | None, app_labels: Iterable[str], tree_names: Iterable[str]) -> list[str]:
    """copier.yml 예약 이름이 템플릿이 정하는 두 묶음을 덮는가(T072 ③ r2 M11 · ② r3 A-3) — 생성물의 앱 라벨(pod 자신 = POD_SNAKE 제외 —
    같은 이름의 pod는 앱 라벨 중복으로 기동이 실패한다) ∪ 생성 트리 최상위 이름(template_top_level_names — 경로 충돌 · 디렉터리 합침).
    잠금 배포의 import 이름 묶음은 생성 날짜의 uv lock 결과라 보지 않는다(copier.yml 주석의 「Extract again」 규칙)."""
    if reserved is None:
        return ["copier.yml pod_name validator에서 예약 목록({% set reserved = [...] %})을 읽지 못했다"]
    violations: list[str] = []
    labels = sorted(set(app_labels) - {POD_SNAKE} - reserved)
    if labels:
        violations.append(
            f"앱 라벨 {labels}이(가) copier.yml 예약 목록에 없다 — 그 이름의 pod는 앱 라벨 중복으로 기동이 실패한다(목록에 더한다 ·"
            " 「Extract again」)"
        )
    names = sorted(set(tree_names) - reserved)
    if names:
        violations.append(
            f"생성 트리 최상위 이름 {names}이(가) copier.yml 예약 목록에 없다 — 그 이름의 pod 패키지 디렉터리가 부딪히거나 합쳐진다"
            "(목록에 더한다)"
        )
    return violations
