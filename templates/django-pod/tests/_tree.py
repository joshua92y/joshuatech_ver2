"""생성 트리 검사 함수(T065 gen-1 · gen-2 · gen-3 · gen-18) — 생성물 파일 · pyproject · env.example · copier 설정.

정본: contracts/pod-template.md §생성 트리 · §기본 테스트 6 · rules/django-pod.md §Template and structure · §Tests.
검사 함수는 list[str](위반)을 돌려준다 — 빈 목록 = 통과. 첫 위반에서 멈추지 않고 전부 모은다. 값(비밀일 수 있는
것)은 위반 문구에 찍지 않는다.
"""

from __future__ import annotations

import os
import re
import shlex
import tomllib
from pathlib import Path
from typing import Any

import yaml

from tests._layout import POD_NAME, POD_SNAKE

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
