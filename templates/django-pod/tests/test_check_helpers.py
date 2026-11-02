"""생성 트리 검사 함수(_tree.py)와 도구 출력 해석(_proc.py) 자체의 검사(T065) — 지금 초록이어야 한다.

gen-1 · 2 · 3 · 18과 gen-5 · 6 · 7의 판정 논리는 실제 생성물(T072 뒤)에서만 초록이 된다. 그 전에 판정 논리 자체가
맞는지 보려고, 계약을 그대로 만족하는 합성 입력(골든)에서 위반 0 · 변이 하나마다 위반 ≥ 1을 확인한다(렌더 검사의
test_render_helpers.py와 같은 방식). 입력은 전부 이 파일 안의 문자열이다 — 저장소에 가짜 pyproject.toml을 두지 않는다
(Renovate 등이 의존성 파일로 읽지 않게).
"""

from __future__ import annotations

import os
import stat
import xml.etree.ElementTree as ET
from collections.abc import Callable
from pathlib import Path

import pytest

from tests._layout import (
    MARKER_NAME,
    REPO_ROOT,
    TEMPLATE_DIR,
    SampleRootError,
    prepare_sample_root,
    resolve_sample_root,
)
from tests._proc import (
    buildx_platforms,
    is_root_user,
    junit_counts,
    parse_image_inspect,
    parse_kubeconform_summary,
    parse_version,
)
from tests._tree import (
    ENV_KEYS,
    REQUIRED_DIRS,
    REQUIRED_FILES,
    check_copier_settings,
    check_env_example,
    check_generated_files,
    check_migrations_test,
    check_pyproject,
    parse_dotted_version,
)

GOLDEN_PYPROJECT = """\
[project]
name = "sample-pod"
version = "0.0.0"
description = ""
requires-python = ">=3.13,<3.14"
dependencies = [
    "django>=6.1,<6.2",
    "django-ninja==1.7.0",
    "psycopg[binary]>=3.3,<4",
    "celery[redis]>=5.6,<6",
    "django-common",
]

[dependency-groups]
dev = [
    "pytest>=9,<10",
    "pytest-django>=4.14,<5",
    "testcontainers[postgres,kafka,redis]>=4.15,<5",
    "django-migration-linter>=5.2,<6",
]

[tool.uv.sources]
django-common = { path = "../../packages/django-common", editable = true }

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "sample_pod.settings"
addopts = ["--tb=short"]
filterwarnings = ["error::DeprecationWarning:sample_pod", "error::DeprecationWarning:tests"]
"""

GOLDEN_ENV_EXAMPLE = "# 키만 둔다 — 값은 ESO(<pod>-env) · ConfigMap이 채운다\n\n" + "".join(
    f"{key}=\n" for key in sorted(ENV_KEYS)
)

GOLDEN_ANSWERS = (
    "# Changes here will be overwritten by Copier\n_src_path: /repo/templates/django-pod\npod_name: sample-pod\n"
)

GOLDEN_COPIER = '_min_copier_version: "9.17"\n_subdirectory: template\n_tasks:\n  - uv lock\npod_name:\n  type: str\n'


def replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise LookupError(f"골든에 {old!r}가 정확히 한 번 있지 않다")
    return text.replace(old, new)


# ---------- gen-2 pyproject ----------

ADDOPTS = 'addopts = ["--tb=short"]'
OWN_FILTER = '"error::DeprecationWarning:tests"'


def swap(old: str, new: str) -> Callable[[str], str]:
    return lambda text: replace_once(text, old, new)


PYPROJECT_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("ninja-other-pin", lambda t: replace_once(t, "django-ninja==1.7.0", "django-ninja==1.6.2")),
    ("ninja-range", lambda t: replace_once(t, "django-ninja==1.7.0", "django-ninja>=1.7")),
    ("ninja-missing", lambda t: replace_once(t, '    "django-ninja==1.7.0",\n', "")),
    ("django-old", lambda t: replace_once(t, "django>=6.1,<6.2", "django>=5.2,<6")),
    ("psycopg-without-extras", lambda t: replace_once(t, "psycopg[binary]>=3.3,<4", "psycopg>=3.3,<4")),
    ("psycopg-old", lambda t: replace_once(t, "psycopg[binary]>=3.3,<4", "psycopg[binary]>=3.2,<4")),
    ("celery-missing", lambda t: replace_once(t, '    "celery[redis]>=5.6,<6",\n', "")),
    ("django-common-missing", lambda t: replace_once(t, '    "django-common",\n', "")),
    ("source-wrong-depth", lambda t: replace_once(t, '"../../packages/django-common"', '"../packages/django-common"')),
    ("source-not-editable", lambda t: replace_once(t, "editable = true", "editable = false")),
    ("source-missing", swap("[tool.uv.sources]\ndjango-common = ", "[tool.uv.other]\ndjango-common = ")),
    ("linter-missing", lambda t: replace_once(t, '    "django-migration-linter>=5.2,<6",\n', "")),
    ("pytest-django-missing", lambda t: replace_once(t, '    "pytest-django>=4.14,<5",\n', "")),
    ("testcontainers-missing", lambda t: replace_once(t, '    "testcontainers[postgres,kafka,redis]>=4.15,<5",\n', "")),
    ("own-module-filter-missing", lambda t: replace_once(t, '"error::DeprecationWarning:sample_pod", ', "")),
    ("global-deprecation-error", swap(OWN_FILTER, '"error::DeprecationWarning"')),
    ("global-deprecation-error-empty-module", swap(OWN_FILTER, '"error::DeprecationWarning:"')),
    ("global-error", swap(OWN_FILTER, '"error"')),
    ("addopts-w-error", swap(ADDOPTS, 'addopts = ["--tb=short", "-W", "error"]')),
    ("addopts-string-w-error", swap(ADDOPTS, 'addopts = "-W error::DeprecationWarning --tb=short"')),
    ("addopts-pythonwarnings", swap(ADDOPTS, 'addopts = ["--tb=short", "--pythonwarnings=error"]')),
    ("tb-short-missing", swap(ADDOPTS, 'addopts = ["-ra"]')),
    ("tb-long", swap(ADDOPTS, 'addopts = ["--tb=long"]')),
    ("requires-python-312", swap('requires-python = ">=3.13,<3.14"', 'requires-python = ">=3.12"')),
    ("not-toml", lambda t: t + "\n[project\n"),
]


def test_check_pyproject_golden() -> None:
    assert check_pyproject(GOLDEN_PYPROJECT) == []


@pytest.mark.parametrize(
    ("name", "mutate"), PYPROJECT_MUTATIONS, ids=[name for name, _ in PYPROJECT_MUTATIONS]
)
def test_check_pyproject_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert check_pyproject(mutate(GOLDEN_PYPROJECT)), f"{name}: 위반을 잡지 못했다"


@pytest.mark.parametrize(
    "variant",
    [
        swap(ADDOPTS, 'addopts = "--tb=short -ra"')(GOLDEN_PYPROJECT),
        swap(ADDOPTS, 'addopts = ["--tb", "short", "-p", "no:cacheprovider"]')(GOLDEN_PYPROJECT),
        swap("django-ninja==1.7.0", "Django-Ninja == 1.7.0")(GOLDEN_PYPROJECT),
        swap(
            '"error::DeprecationWarning:sample_pod", ',
            '"ignore::UserWarning", "error::DeprecationWarning:sample_pod", ',
        )(GOLDEN_PYPROJECT),
    ],
    ids=["addopts-string", "tb-separate-arg", "name-normalized", "other-filter"],
)
def test_check_pyproject_equivalent_spellings_accepted(variant: str) -> None:
    assert check_pyproject(variant) == []


# ---------- gen-3 env.example ----------

ENV_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("value-present", lambda t: replace_once(t, "\nENV=\n", "\nENV=dev\n")),
    ("key-missing", lambda t: replace_once(t, "\nKAFKA_PASSWORD=\n", "\n")),
    ("owner-url-present", lambda t: t + "DATABASE_OWNER_URL=\n"),
    ("email-key-present", lambda t: t + "EMAIL_HOST=\n"),
    ("lowercase-key", lambda t: t + "debug=\n"),
    ("export-prefix", lambda t: t + "export EXTRA=\n"),
    ("inline-comment-value", lambda t: replace_once(t, "\nENV=\n", "\nENV= # dev | prod\n")),
]


def test_check_env_example_golden() -> None:
    assert len(ENV_KEYS) == 20
    assert check_env_example(GOLDEN_ENV_EXAMPLE) == []


@pytest.mark.parametrize(("name", "mutate"), ENV_MUTATIONS, ids=[name for name, _ in ENV_MUTATIONS])
def test_check_env_example_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert check_env_example(mutate(GOLDEN_ENV_EXAMPLE)), f"{name}: 위반을 잡지 못했다"


# ---------- gen-5 tests/test_migrations.py 본문(r1 A-3) ----------

GOLDEN_MIGRATIONS_TEST = (
    "from django.core.management import call_command\n\n\n"
    "def test_makemigrations_check():\n"
    '    call_command("makemigrations", "--check", "--dry-run")\n\n\n'
    "def test_migration_linter():\n"
    '    call_command("lintmigrations")\n'
)

MIGRATIONS_TEST_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("check-flag-missing", swap('"makemigrations", "--check", "--dry-run"', '"makemigrations", "--dry-run"')),
    ("check-flag-on-other-line", swap('"makemigrations", "--check", "--dry-run"', '"makemigrations",\n        "--dry-run"')),
    ("makemigrations-missing", swap('call_command("makemigrations", "--check", "--dry-run")', "pass")),
    ("linter-missing", swap('call_command("lintmigrations")', "pass")),
]


def test_check_migrations_test_golden() -> None:
    assert check_migrations_test(GOLDEN_MIGRATIONS_TEST) == []


@pytest.mark.parametrize(
    ("name", "mutate"), MIGRATIONS_TEST_MUTATIONS, ids=[name for name, _ in MIGRATIONS_TEST_MUTATIONS]
)
def test_check_migrations_test_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert check_migrations_test(mutate(GOLDEN_MIGRATIONS_TEST)), f"{name}: 위반을 잡지 못했다"


def test_check_migrations_test_accepts_keyword_and_module_spellings() -> None:
    variant = (
        "import django_migration_linter  # noqa: F401\n"
        "from django.core.management import call_command\n\n\n"
        "def test_makemigrations_check():\n"
        '    call_command("makemigrations", check=True, dry_run=True)\n'
    )
    assert check_migrations_test(variant) == []


# ---------- gen-18 copier 설정 · 답변 ----------


@pytest.mark.parametrize(
    "copier_text",
    [
        GOLDEN_COPIER,
        replace_once(GOLDEN_COPIER, "  - uv lock\n", "  - [uv, lock]\n"),
        replace_once(GOLDEN_COPIER, "  - uv lock\n", "  - command: uv lock --quiet\n"),
        replace_once(GOLDEN_COPIER, '"9.17"', '"9.19.1"'),
        replace_once(GOLDEN_COPIER, '"9.17"', '"10"'),
    ],
    ids=["golden", "argv-list", "command-mapping", "patch-version", "major-10"],
)
def test_check_copier_settings_accepted(copier_text: str) -> None:
    assert check_copier_settings(GOLDEN_ANSWERS, copier_text) == []


COPIER_MUTATIONS: list[tuple[str, str | None, str]] = [
    ("answers-missing", None, GOLDEN_COPIER),
    ("answers-without-src-path", "pod_name: sample-pod\n", GOLDEN_COPIER),
    ("min-version-missing", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, '_min_copier_version: "9.17"\n', "")),
    ("min-version-old", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, '"9.17"', '"9.16"')),
    ("min-version-string-trap", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, '"9.17"', '"9.9"')),
    ("min-version-unreadable", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, '"9.17"', '"latest"')),
    ("tasks-missing", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, "_tasks:\n  - uv lock\n", "")),
    ("tasks-other-command", GOLDEN_ANSWERS, replace_once(GOLDEN_COPIER, "  - uv lock\n", "  - uv sync\n")),
    ("copier-not-mapping", GOLDEN_ANSWERS, "- just\n- a list\n"),
]


@pytest.mark.parametrize(
    ("name", "answers", "copier_text"), COPIER_MUTATIONS, ids=[name for name, _, _ in COPIER_MUTATIONS]
)
def test_check_copier_settings_mutation_caught(name: str, answers: str | None, copier_text: str) -> None:
    assert check_copier_settings(answers, copier_text), f"{name}: 위반을 잡지 못했다"


def test_parse_dotted_version_is_numeric() -> None:
    assert parse_dotted_version("9.17") == (9, 17)
    assert parse_dotted_version(9.17) == (9, 17)
    assert parse_dotted_version("9.9") < (9, 17)  # 문자열 비교였다면 "9.9" > "9.17"
    assert parse_dotted_version("9.17.0a1") is None


# ---------- gen-1 생성 파일 ----------


def make_tree(root: Path) -> Path:
    pod = root / "apps" / "sample-pod"
    for relative in REQUIRED_FILES:
        path = pod / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("", encoding="utf-8")
    for relative in REQUIRED_DIRS:
        (pod / relative).mkdir(parents=True, exist_ok=True)
    (pod / ".copier-answers.yml").write_text(GOLDEN_ANSWERS, encoding="utf-8")
    return pod


def test_check_generated_files_golden(tmp_path: Path) -> None:
    pod = make_tree(tmp_path)
    (pod / ".venv" / "share").mkdir(parents=True)
    (pod / ".venv" / "share" / "vendored.html.jinja").write_text("", encoding="utf-8")  # .venv 안은 보지 않는다
    assert check_generated_files(pod) == []


def test_check_generated_files_reports_every_problem(tmp_path: Path) -> None:
    pod = make_tree(tmp_path)
    (pod / "pyproject.toml").unlink()
    (pod / "tests" / "test_outbox.py").unlink()
    (pod / "sample_pod" / "core").rmdir()
    (pod / "sample_pod" / "settings.py.jinja").write_text("", encoding="utf-8")
    (pod / ".copier-answers.yml").write_text("_src_path: x\npod_name: other-pod\n", encoding="utf-8")
    found = check_generated_files(pod)
    joined = "\n".join(found)
    for fragment in ("pyproject.toml", "tests/test_outbox.py", "sample_pod/core", "settings.py.jinja", "other-pod"):
        assert fragment in joined, f"{fragment} 위반이 빠졌다: {found}"


def test_check_generated_files_empty_tree(tmp_path: Path) -> None:
    pod = tmp_path / "apps" / "sample-pod"
    pod.mkdir(parents=True)
    (pod / ".gitkeep").write_text("", encoding="utf-8")
    found = check_generated_files(pod)
    assert len(found) == len(REQUIRED_FILES) + len(REQUIRED_DIRS) + 1  # + .copier-answers.yml 없음


# ---------- 도구 출력 해석 ----------


def test_parse_version_real_outputs() -> None:
    assert parse_version("__main__.py 9.19.1") == (9, 19, 1)
    assert parse_version("uv 0.12.6 (7938ca5d5 2026-08-25 x86_64-pc-windows-msvc)") == (0, 12, 6)
    assert parse_version("v5.8.1") == (5, 8, 1)
    assert parse_version("v0.8.0") == (0, 8, 0)
    assert parse_version("unknown") is None


def test_buildx_platforms_strips_markers() -> None:
    text = "Name: desktop-linux\nPlatforms:        linux/amd64*, linux/arm64, linux/arm/v7\nLabels:\n"
    assert buildx_platforms(text) == {"linux/amd64", "linux/arm64", "linux/arm/v7"}


def summary_fields(text: str) -> tuple[int, ...] | None:
    summary = parse_kubeconform_summary(text)
    if summary is None:
        return None
    return (summary.resources, summary.valid, summary.invalid, summary.errors, summary.skipped)


def test_parse_kubeconform_summary_real_lines() -> None:
    # 첫 줄 · 둘째 묶음은 kubeconform v0.8.0 실측 출력 그대로(빈 입력 · 스키마 없음)
    assert summary_fields(
        "Summary: 0 resource found parsing stdin - Valid: 0, Invalid: 0, Errors: 0, Skipped: 0\n"
    ) == (0, 0, 0, 0, 0)
    assert summary_fields(
        "stdin - ConfigMap x failed validation: could not find schema for ConfigMap\n"
        "Summary: 1 resource found parsing stdin - Valid: 0, Invalid: 0, Errors: 1, Skipped: 0\n"
    ) == (1, 0, 0, 1, 0)
    assert summary_fields(
        "Summary: 9 resources found parsing stdin - Valid: 6, Invalid: 1, Errors: 0, Skipped: 2\n"
    ) == (9, 6, 1, 0, 2)
    assert summary_fields(
        "Summary: 2 resources found in 2 files - Valid: 2, Invalid: 0, Errors: 0, Skipped: 0\n"
    ) == (2, 2, 0, 0, 0)
    assert summary_fields("no summary here\n") is None


JUNIT_TESTSUITES = (
    '<?xml version="1.0" encoding="utf-8"?><testsuites name="pytest tests">'
    '<testsuite name="pytest" errors="1" failures="2" skipped="3" tests="12" time="1.0">'
    '<testcase classname="tests.test_health" name="test_x" time="0.1"/></testsuite></testsuites>'
)


def test_junit_counts_testsuites_and_single_suite() -> None:
    counts, problem = junit_counts(ET.fromstring(JUNIT_TESTSUITES))
    assert problem is None
    assert counts is not None
    assert (counts.tests, counts.failures, counts.errors, counts.skipped) == (12, 2, 1, 3)
    single, problem = junit_counts(ET.fromstring('<testsuite tests="8" failures="0" errors="0" skipped="0"/>'))
    assert problem is None and single is not None and single.tests == 8
    missing, problem = junit_counts(ET.fromstring("<report/>"))
    assert missing is None and problem


def test_parse_image_inspect_and_root_user() -> None:
    facts = parse_image_inspect("arm64 linux app\n")
    assert facts is not None and (facts.architecture, facts.os, facts.user) == ("arm64", "linux", "app")
    empty_user = parse_image_inspect("arm64 linux \n")
    assert empty_user is not None and empty_user.user == ""
    assert parse_image_inspect("") is None
    for user in ("", "root", "0", "0:0", "root:root", " "):
        assert is_root_user(user), user
    for user in ("app", "1000", "1000:1000", "app:app"):
        assert not is_root_user(user), user


# ---------- JT_SAMPLE_POD_ROOT 삭제 규율(표식 파일이 있는 디렉터리만 비운다) ----------


def test_sample_root_relative_path_is_repo_relative() -> None:
    assert resolve_sample_root("tests/fixtures/generated") == (REPO_ROOT / "tests" / "fixtures" / "generated").resolve()


def test_sample_root_new_directory_gets_marker(tmp_path: Path) -> None:
    root = prepare_sample_root(str(tmp_path / "new" / "deep"))
    assert root.is_dir()
    assert sorted(path.name for path in root.iterdir()) == [MARKER_NAME]


def test_sample_root_empty_directory_gets_marker(tmp_path: Path) -> None:
    root = prepare_sample_root(str(tmp_path))
    assert sorted(path.name for path in root.iterdir()) == [MARKER_NAME]


def test_sample_root_with_marker_is_cleared(tmp_path: Path) -> None:
    (tmp_path / MARKER_NAME).write_text("x", encoding="utf-8")
    (tmp_path / "apps" / "sample-pod" / ".venv").mkdir(parents=True)
    locked = tmp_path / "apps" / "sample-pod" / ".venv" / "locked.txt"
    locked.write_text("x", encoding="utf-8")
    os.chmod(locked, stat.S_IREAD)  # 읽기 전용 파일도 지운다(Windows의 rmtree 실패 대비)
    (tmp_path / "loose.txt").write_text("x", encoding="utf-8")
    root = prepare_sample_root(str(tmp_path))
    assert sorted(path.name for path in root.iterdir()) == [MARKER_NAME]


def test_sample_root_without_marker_is_refused_and_untouched(tmp_path: Path) -> None:
    keep = tmp_path / "keep.txt"
    keep.write_text("x", encoding="utf-8")
    with pytest.raises(SampleRootError):
        prepare_sample_root(str(tmp_path))
    assert keep.is_file()
    assert not (tmp_path / MARKER_NAME).exists()


def test_sample_root_marker_must_be_a_file(tmp_path: Path) -> None:
    (tmp_path / MARKER_NAME).mkdir()
    (tmp_path / "keep.txt").write_text("x", encoding="utf-8")
    with pytest.raises(SampleRootError):
        prepare_sample_root(str(tmp_path))
    assert (tmp_path / "keep.txt").is_file()


def test_sample_root_not_a_directory(tmp_path: Path) -> None:
    target = tmp_path / "file.txt"
    target.write_text("x", encoding="utf-8")
    with pytest.raises(SampleRootError):
        prepare_sample_root(str(target))
    assert target.read_text(encoding="utf-8") == "x"


@pytest.mark.parametrize(
    "raw",
    [
        str(REPO_ROOT),
        str(REPO_ROOT.parent),
        str(TEMPLATE_DIR),
        "templates/django-pod/tests/fixtures/generated-t065-guard",
    ],
    ids=["repo-root", "repo-parent", "template-dir", "inside-template-relative"],
)
def test_sample_root_refuses_repo_and_template(raw: str) -> None:
    with pytest.raises(SampleRootError):
        prepare_sample_root(raw)
    assert not (TEMPLATE_DIR / "tests" / "fixtures" / "generated-t065-guard").exists()
