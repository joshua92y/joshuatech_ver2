"""생성 트리 검사 함수(_tree.py)와 도구 출력 해석(_proc.py) 자체의 검사(T065 · T072) — 지금 초록이어야 한다.

gen-1 · 2 · 3 · 18과 gen-5 · 6 · 7의 판정 논리는 실제 생성물(T072 뒤)에서만 초록이 된다. 그 전에 판정 논리 자체가
맞는지 보려고, 계약을 그대로 만족하는 합성 입력(골든)에서 위반 0 · 변이 하나마다 위반 ≥ 1을 확인한다(렌더 검사의
test_render_helpers.py와 같은 방식). 입력은 전부 이 파일 안의 문자열이다 — 저장소에 가짜 pyproject.toml을 두지 않는다
(Renovate 등이 의존성 파일로 읽지 않게).

T072 추가분(design/t072-design.md D21 — 파일 끝 절): gen-25..36이 쓰는 _tree.py 새 도우미(T072 트리 · 렌더 전용 트리 ·
pytest 위생 · outbox_purge 표식 · base kustomization · Dockerfile · 이미지 구성 · 이미지 탐침 · 변형 settings · 기동 실패 ·
로그 쓰기 오류 · 비밀 누출 · copier validator 거부)와 _layout.py(copier 선택 인자 · 변형 정의) · _proc.py(자식 env ·
탐침 줄 · 지표 표본 · docker run 인자 · 컨테이너 상태)의 골든 · 변이. 실제 생성물 · 이미지가 없어도 판정 논리를 먼저 굳힌다.

T072 r2(리뷰 r1 반영 — 파일 끝 절): outbox_purge 실패 사유 · 기동 실패 클래스(E3) · 받아들임 답변 기록(E4) · 비밀 가리기와
부분 누출 · 스모크 기록(E8) · docker logs 실패 · HTTP 탐침 본문(E9) · 생성물 pytest env(E10) · 레이블 · 남은 컨테이너 쓸기 ·
rm -f -v(E11) · 프로세스 트리 종료(E12) · 시간 예산 · 단계 기록 · 대기 상한(E13). docker가 필요한 도우미는 가짜 docker
스크립트(sys.executable + cwd의 스크립트 이름)로 돌린다 — 컨테이너를 띄우지 않는다.

T072 r3(리뷰 r2 반영): outbox_purge 규칙 격리(F3 — E3 절) · 남은 스모크 컨테이너 쓸기의 나이 문턱 · 행 판정 · docker ps 인자 ·
id로만 지우기 · ps 실패 · 이미지 빌드 앞 단계 기록(F2 · F5 · F6 — 파일 끝 절). E11 절의 기존 시험 둘은 F5에 맞춰 본문만 고쳤다
(docker run 레이블 셋째 jt.created · ps 줄은 탭 4열 — 시험 ID와 기대 행은 그대로).

T072 조각 ③ 지시 5(파일 끝 절): 이미지 /src/apps/<pod> 최상위 허용 목록 · 빌드 감시 파일(.venv 안 · 탐침 venv_sentinel)과 그 심기 ·
지우기(conftest.py build_with_sentinels — 이 파일은 tests.conftest를 import한다) · RUN uv sync의 --locked · --no-editable. 골든
GOLDEN_IMAGE_PROBE에 탐침의 새 키 둘(pod_entries · venv_sentinel)을 더했다(기존 시험 ID 그대로).

T072 조각 ③ r2(리뷰 r1 반영 M1–M11 — 파일 끝 절): 생성 Dockerfile.dockerignore 정적 검사(M1 · M2a) · 심은 감시 파일 기록(M2b) ·
RUN uv sync --no-dev와 따옴표 셸 꼴 · 이미지 dev 전용 배포(M3) · build-arg 배선(M4) · compose config 내용(M5) · 명령 상수 한 곳(M6) ·
copier 예약 이름(M11) · 허용 목록 env. 기존 시험 셋은 본문만 고쳤다(시험 ID 그대로): 감시 파일 이름 대조(새 감시 파일 셋 · 「잡는 판정」
규칙) · 심고 지우기(감시 파일 수) · GOLDEN_IMAGE_PROBE에 dev_distributions 키. 기존 매개변수 목록(UV_SYNC_MUTATIONS · uv sync 받아들임 ·
DOCKERFILE_MUTATIONS)은 끝에만 덧붙였다.

T072 마지막 라운드(조각 ③ r3 · ④ r2 — N4 · N5 · N6 · N7 · N14): 이미지 Config.Cmd = 이미지 CMD 상수 · Entrypoint 없음(N4 — GOLDEN_IMAGE_CONFIG에
Cmd · Entrypoint · 변이 셋은 기존 매개변수 끝에) · gen-35 argv의 --profile "*"와 프로필 서비스 판정(N5) · dockerignore 재제외의 대소문자 무관 꼴
과 비밀 이름 꼴 · 탐침의 소문자 판정 · 대문자 감시 파일(N6 — DOCKERIGNORE_REEXCLUDE_LINES는 기존 키(= 시험 ID)의 값만 바꾸고 키를 더했다 ·
감시 파일 이름 대조 · 재제외 짝 시험은 본문만) · 실제 생성 트리 최상위 이름(N7) · pid_alive의 UTF-8 모드(N14 — tasklist를 바이트로 읽는다).

T072 마감 라운드(마지막 리뷰 A-2 · B-1 — Z2 · Z3): gen-35 프로필 펼침 탐침 파일의 꼴과 그 판정(check_compose_profile_probe — 골든 · 변이 ·
실제 Compose 실측은 gen-35 본문) · dockerignore 이름 꼴 다섯의 대소문자 무관 꼴(DOCKERIGNORE_REEXCLUDE_LINES는 기존 키의 값만 바꿨다 ·
DOCKERIGNORE_MUTATIONS · 탐침 이름 표는 끝에 덧붙였다 · 비밀 후보 꼴 열하나 전부의 대소문자 무관 판정 bare_letters와 그 자기검사) · 이름 꼴
대문자 감시 파일 JT-HARNESS-NAME.ENV(감시 파일 이름 대조 · 탐침 스크립트 대문자 이름 · 재제외 짝 시험은 본문만).
"""

from __future__ import annotations

import fnmatch
import json
import os
import re
import secrets
import socket
import stat
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
from collections.abc import Callable
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import pytest
import yaml

from tests import _proc, _render, _tree, conftest
from tests._layout import (
    MARKER_NAME,
    REPO_ROOT,
    TEMPLATE_DIR,
    VARIANTS,
    SampleRootError,
    copier_copy_argv,
    prepare_sample_root,
    resolve_sample_root,
    variant_destination,
    venv_python,
)
from tests._proc import (
    GLOB_PROBE_SCRIPT,
    HTTP_PROBE_SCRIPT,
    IMAGE_PROBE_SCRIPT,
    PROBE_MARKER,
    SETTINGS_PROBE_SCRIPT,
    buildx_platforms,
    child_env,
    docker_run_argv,
    is_root_user,
    junit_counts,
    metric_samples,
    parse_container_state,
    parse_image_inspect,
    parse_kubeconform_summary,
    parse_probe_line,
    parse_version,
    run,
    smoke_container_name,
)
from tests._tree import (
    ENV_KEYS,
    FORBIDDEN_ENV_NAMES,
    FORBIDDEN_FILE_NAMES,
    REQUIRED_DIRS,
    REQUIRED_FILES,
    T072_ADMIN_FILES,
    T072_CELERY_FILES,
    T072_CONSUMER_FILES,
    T072_CRONJOB_FILES,
    T072_FILE_PATTERNS,
    T072_FILES,
    check_base_kustomization,
    check_copier_settings,
    check_dockerfile_text,
    check_env_example,
    check_generated_files,
    check_generated_files_t072,
    check_image_config,
    check_image_probe,
    check_log_write_errors,
    check_migrations_test,
    check_outbox_test,
    check_pyproject,
    check_pytest_hygiene,
    check_render_only_tree,
    check_secret_leaks,
    check_startup_failure,
    check_validator_rejection,
    check_variant_settings,
    forbidden_env_name,
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


# ==================== T072(design/t072-design.md D21 · 계약 §기본 테스트 6) ====================

# ---------- gen-25 · gen-29 T072 생성 트리 ----------

FLAG_SETS: dict[str, dict[str, bool]] = {
    "default": {"has_celery": True, "has_admin": True, "consumes": False},
    "no-celery": {"has_celery": False, "has_admin": True, "consumes": True},
    "no-admin": {"has_celery": False, "has_admin": False, "consumes": False},
}
RLS_MIGRATIONS = ("tests/rlsapp/migrations/0001_initial.py", "tests/rlsapp/migrations/0002_rls.py")


def t072_expected_files(*, has_celery: bool, has_admin: bool, consumes: bool) -> list[str]:
    files = [*T072_FILES, *(T072_CELERY_FILES if has_celery else T072_CRONJOB_FILES)]
    if has_admin:
        files.extend(T072_ADMIN_FILES)
    if consumes:
        files.extend(T072_CONSUMER_FILES)
    return files


def write_empty(pod: Path, relative: str) -> None:
    path = pod / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("", encoding="utf-8")


def make_t072_tree(root: Path, *, has_celery: bool, has_admin: bool, consumes: bool) -> Path:
    pod = root / "apps" / "sample-pod"
    for relative in [*t072_expected_files(has_celery=has_celery, has_admin=has_admin, consumes=consumes), *RLS_MIGRATIONS]:
        write_empty(pod, relative)
    return pod


def unlink(relative: str) -> Callable[[Path], None]:
    return lambda pod: (pod / relative).unlink()


def touch(relative: str) -> Callable[[Path], None]:
    return lambda pod: write_empty(pod, relative)


def test_t072_rls_migration_names_match_patterns() -> None:
    for pattern in T072_FILE_PATTERNS:
        assert any(fnmatch.fnmatch(name, pattern) for name in RLS_MIGRATIONS), pattern


@pytest.mark.parametrize("flags", list(FLAG_SETS), ids=list(FLAG_SETS))
def test_check_generated_files_t072_golden(tmp_path: Path, flags: str) -> None:
    pod = make_t072_tree(tmp_path, **FLAG_SETS[flags])
    write_empty(pod, ".venv/share/.gitkeep")  # .venv · 캐시 디렉터리 안은 보지 않는다
    write_empty(pod, "sample_pod/__pycache__/test_api.py")
    assert check_generated_files_t072(pod, **FLAG_SETS[flags]) == []


T072_TREE_MUTATIONS: list[tuple[str, str, Callable[[Path], None]]] = [
    ("settings-wrapper-missing", "default", unlink("tests/settings.py")),
    ("dockerignore-missing", "default", unlink("Dockerfile.dockerignore")),
    ("dragonfly-acl-missing", "default", unlink("compose/dragonfly-dev.acl")),
    ("pg-tls-script-missing", "default", unlink("tests/docker/pg-tls/00-tls-only.sh")),
    ("grants-migration-missing", "default", unlink("sample_pod/core/migrations/0001_app_role_grants.py")),
    ("startup-command-missing", "default", unlink("sample_pod/management/commands/startup_check.py")),
    ("openapi-snapshot-missing", "default", unlink("tests/snapshots/openapi.json")),
    ("ingress-missing", "default", unlink("deploy/base/ingress.yaml")),
    ("rls-migration-missing", "default", unlink("tests/rlsapp/migrations/0002_rls.py")),
    ("tasks-missing-with-celery", "default", unlink("sample_pod/tasks.py")),
    ("celery-deployment-missing", "default", unlink("deploy/base/deployment-celery.yaml")),
    ("cronjob-in-default", "default", touch("deploy/base/cronjob-outbox-purge.yaml")),
    ("probe-admin-urls-missing", "default", unlink("tests/probe_admin_urls.py")),
    ("consumers-without-consumes", "default", touch("sample_pod/events/consumers.py")),
    ("celery-module-in-no-celery", "no-celery", touch("sample_pod/celery.py")),
    ("celery-deployment-in-no-celery", "no-celery", touch("deploy/base/deployment-celery.yaml")),
    ("cronjob-missing-in-no-celery", "no-celery", unlink("deploy/base/cronjob-outbox-purge.yaml")),
    ("consumers-missing", "no-celery", unlink("sample_pod/events/consumers.py")),
    ("urls-admin-in-no-admin", "no-admin", touch("sample_pod/urls_admin.py")),
    ("probe-admin-urls-in-no-admin", "no-admin", touch("tests/probe_admin_urls.py")),
    ("gitkeep-root", "default", touch(".gitkeep")),
    ("gitkeep-nested", "no-admin", touch("deploy/base/.gitkeep")),
    ("test-api-name", "default", touch("tests/test_api.py")),
    ("identity-fakes-name", "no-celery", touch("tests/_identity_fakes.py")),
    ("identity-fakes-test-name", "default", touch("sample_pod/test_identity_fakes.py")),
]


@pytest.mark.parametrize(
    ("name", "flags", "mutate"), T072_TREE_MUTATIONS, ids=[name for name, _, _ in T072_TREE_MUTATIONS]
)
def test_check_generated_files_t072_mutation_caught(
    tmp_path: Path, name: str, flags: str, mutate: Callable[[Path], None]
) -> None:
    pod = make_t072_tree(tmp_path, **FLAG_SETS[flags])
    mutate(pod)
    assert check_generated_files_t072(pod, **FLAG_SETS[flags]), f"{name}: 위반을 잡지 못했다"


def test_check_generated_files_t072_empty_tree(tmp_path: Path) -> None:
    pod = tmp_path / "apps" / "sample-pod"
    pod.mkdir(parents=True)
    (pod / ".gitkeep").write_text("", encoding="utf-8")
    found = check_generated_files_t072(pod)
    expected = len(t072_expected_files(**FLAG_SETS["default"])) + len(T072_FILE_PATTERNS) + 1  # + .gitkeep
    assert len(found) == expected, found


def test_forbidden_file_names_are_t066_names() -> None:
    assert FORBIDDEN_FILE_NAMES == frozenset({"test_api.py", "_identity_fakes.py", "test_identity_fakes.py"})


def make_render_only_tree(root: Path) -> Path:
    pod = make_tree(root)
    (pod / "uv.lock").unlink()
    return pod


def test_check_render_only_tree_golden(tmp_path: Path) -> None:
    pod = make_render_only_tree(tmp_path)
    write_empty(pod, "sample_pod/__pycache__/x.cpython-313.pyc")  # import가 남긴 캐시는 괜찮다
    assert check_render_only_tree(pod) == []


RENDER_ONLY_MUTATIONS: list[tuple[str, Callable[[Path], None]]] = [
    ("uv-lock-present", touch("uv.lock")),
    ("venv-present", lambda pod: (pod / ".venv").mkdir()),
    ("settings-missing", unlink("sample_pod/settings.py")),
    ("kustomization-missing", unlink("deploy/base/kustomization.yaml")),
    ("answers-missing", unlink(".copier-answers.yml")),
    ("answers-other-pod", lambda pod: (pod / ".copier-answers.yml").write_text("pod_name: other-pod\n", encoding="utf-8")),
    ("jinja-leftover", touch("sample_pod/urls.py.jinja")),
    ("core-dir-missing", lambda pod: (pod / "sample_pod" / "core").rmdir()),
]


@pytest.mark.parametrize(("name", "mutate"), RENDER_ONLY_MUTATIONS, ids=[name for name, _ in RENDER_ONLY_MUTATIONS])
def test_check_render_only_tree_mutation_caught(tmp_path: Path, name: str, mutate: Callable[[Path], None]) -> None:
    pod = make_render_only_tree(tmp_path)
    mutate(pod)
    assert check_render_only_tree(pod), f"{name}: 위반을 잡지 못했다"


# ---------- gen-26 pytest 위생 ----------

GOLDEN_PYPROJECT_T072 = """\
[project]
name = "sample-pod"
version = "0.0.0"
description = ""
requires-python = ">=3.13,<3.14"
dependencies = [
    "django>=6.1.3,<6.2",
    "django-ninja==1.7.0",
    "psycopg[binary]>=3.3,!=3.3.7,<4",
    "celery[redis]>=5.6.3,<5.7",
    "django-common",
    "pydantic-settings>=2.16,<3",
    "gunicorn>=26.2,<27",
    "prometheus-client>=0.23,<1",
]

[dependency-groups]
dev = [
    "pytest>=9,<10",
    "pytest-django>=4.14,<5",
    "testcontainers[postgres]>=4.15,<5",
    "django-migration-linter>=6,<7",
    "pyyaml>=6,<7",
]

[tool.uv]
package = false

[tool.uv.sources]
django-common = { path = "../../packages/django-common", editable = true }

[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "tests.settings"
testpaths = ["tests"]
pythonpath = ["."]
addopts = ["--tb=short", "--show-capture=no", "--ds=tests.settings"]
filterwarnings = ["error::DeprecationWarning:sample_pod", "error::DeprecationWarning:tests"]
"""

# T072 ② r2 H9(B-1): --ds=tests.settings — pytest-django는 옵션 > env > ini 순이라 ini만 두면 셸 env DJANGO_SETTINGS_MODULE이
# 시험 래퍼를 비켜 간다. 넓히는 옵션이 아니라 래퍼를 고정하는 옵션이다(검사가 요구한다).
T072_ADDOPTS = 'addopts = ["--tb=short", "--show-capture=no", "--ds=tests.settings"]'
SETTINGS_LINE = 'DJANGO_SETTINGS_MODULE = "tests.settings"'


def widen(*extra: str) -> Callable[[str], str]:
    """골든 addopts 뒤에 옵션을 덧붙인다."""
    items = ", ".join(json.dumps(item) for item in ("--tb=short", "--show-capture=no", "--ds=tests.settings", *extra))
    return swap(T072_ADDOPTS, f"addopts = [{items}]")


def test_check_pytest_hygiene_golden_also_passes_gen_2() -> None:
    assert check_pytest_hygiene(GOLDEN_PYPROJECT_T072) == []
    assert check_pyproject(GOLDEN_PYPROJECT_T072) == []  # 실제 생성물은 gen-2와 gen-26을 함께 통과해야 한다


HYGIENE_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("show-capture-missing", swap(T072_ADDOPTS, 'addopts = ["--tb=short", "--ds=tests.settings"]')),
    ("show-capture-all", swap(T072_ADDOPTS, 'addopts = ["--tb=short", "--show-capture=all", "--ds=tests.settings"]')),
    (
        "show-capture-separate-value",
        swap(T072_ADDOPTS, 'addopts = ["--tb=short", "--show-capture", "stdout", "--ds=tests.settings"]'),
    ),
    ("show-capture-later-override", widen("--show-capture=log")),
    ("tb-missing", swap(T072_ADDOPTS, 'addopts = ["--show-capture=no", "--ds=tests.settings"]')),
    ("tb-long", swap(T072_ADDOPTS, 'addopts = ["--tb=long", "--show-capture=no", "--ds=tests.settings"]')),
    ("tb-auto-separate-value", widen("--tb", "auto")),
    ("showlocals-short", widen("-l")),
    ("showlocals-cluster", widen("-vl")),
    ("showlocals-long", widen("--showlocals")),
    ("full-trace", widen("--full-trace")),
    ("override-ini-separate", widen("-o", "addopts=")),
    ("override-ini-attached", widen("-oaddopts=")),
    ("override-ini-long", widen("--override-ini=addopts=")),
    ("log-cli-level-option", widen("--log-cli-level=INFO")),
    ("log-file-option", widen("--log-file", "pytest.log")),
    ("args-from-file", widen("@more-args.txt")),
    ("addopts-string-widened", swap(T072_ADDOPTS, 'addopts = "--tb=short --show-capture=no --ds=tests.settings -l"')),
    ("log-cli-ini", lambda t: t + "log_cli = true\n"),
    ("log-file-ini", lambda t: t + 'log_file = "pytest.log"\n'),
    ("junit-logging-all", lambda t: t + 'junit_logging = "all"\n'),
    ("settings-module-pod", swap(SETTINGS_LINE, 'DJANGO_SETTINGS_MODULE = "sample_pod.settings"')),
    ("settings-module-missing", swap(SETTINGS_LINE + "\n", "")),
    ("native-pytest-table", lambda t: t + '\n[tool.pytest]\naddopts = ["-l"]\n'),
    ("not-toml", lambda t: t + "\n[tool.pytest\n"),
    # ---- T072 ② r2 H9(B-1) — 시험 래퍼 고정 옵션 --ds(옵션 > env > ini · 마지막 값이 이긴다 · 빈 값은 env로 넘어간다) ----
    ("ds-missing", swap(T072_ADDOPTS, 'addopts = ["--tb=short", "--show-capture=no"]')),
    (
        "ds-pod-settings",
        swap(T072_ADDOPTS, 'addopts = ["--tb=short", "--show-capture=no", "--ds=sample_pod.settings"]'),
    ),
    ("ds-later-override", widen("--ds", "sample_pod.settings")),
    ("ds-empty-later", widen("--ds=")),
]


@pytest.mark.parametrize(("name", "mutate"), HYGIENE_MUTATIONS, ids=[name for name, _ in HYGIENE_MUTATIONS])
def test_check_pytest_hygiene_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert check_pytest_hygiene(mutate(GOLDEN_PYPROJECT_T072)), f"{name}: 위반을 잡지 못했다"


@pytest.mark.parametrize(
    "variant",
    [
        swap(T072_ADDOPTS, 'addopts = "--tb=short --show-capture=no --ds=tests.settings"')(GOLDEN_PYPROJECT_T072),
        swap(
            T072_ADDOPTS,
            'addopts = ["--tb", "short", "--show-capture", "no", "--ds", "tests.settings", "-p", "no:cacheprovider",'
            ' "-ra"]',
        )(GOLDEN_PYPROJECT_T072),
        GOLDEN_PYPROJECT_T072 + 'junit_logging = "no"\n',
        swap(T072_ADDOPTS, 'addopts = ["-q", "--tb=short", "--show-capture=no", "--ds=tests.settings"]')(
            GOLDEN_PYPROJECT_T072
        ),
    ],
    ids=["addopts-string", "separate-values", "junit-logging-no", "quiet-flag"],
)
def test_check_pytest_hygiene_equivalent_spellings_accepted(variant: str) -> None:
    assert check_pytest_hygiene(variant) == []


# ---------- gen-27 outbox_purge 표식(D17) ----------

GOLDEN_OUTBOX_TEST = (
    "from django.core.management import call_command\n\n\n"
    "def test_outbox_purge_command(capsys):\n"
    '    call_command("outbox_purge")\n'
    '    assert capsys.readouterr().out.startswith("outbox_purge: ")\n'
)
PURGE_CALL = 'call_command("outbox_purge")'


@pytest.mark.parametrize(
    "text",
    [
        GOLDEN_OUTBOX_TEST,
        replace_once(GOLDEN_OUTBOX_TEST, PURGE_CALL, "call_command('outbox_purge')"),
        replace_once(GOLDEN_OUTBOX_TEST, PURGE_CALL, 'call_command(\n        "outbox_purge",\n    )'),
    ],
    ids=["golden", "single-quotes", "multi-line-call"],
)
def test_check_outbox_test_accepted(text: str) -> None:
    assert check_outbox_test(text) == []


@pytest.mark.parametrize(
    "text",
    [
        replace_once(GOLDEN_OUTBOX_TEST, PURGE_CALL, 'call_command("outbox_relay", iterations=1)'),
        replace_once(GOLDEN_OUTBOX_TEST, PURGE_CALL, "# " + PURGE_CALL + "\n    pass"),
        replace_once(GOLDEN_OUTBOX_TEST, PURGE_CALL, 'call_command("outbox_requeue")'),
    ],
    ids=["missing", "commented-out", "other-command"],
)
def test_check_outbox_test_mutation_caught(text: str) -> None:
    assert check_outbox_test(text)


# ---------- gen-23 base kustomization(정적 — 렌더로 볼 수 없는 키) ----------

GOLDEN_BASE_KUSTOMIZATION = (
    "apiVersion: kustomize.config.k8s.io/v1beta1\nkind: Kustomization\nresources:\n"
    "  - configmap.yaml\n  - externalsecret-env.yaml\n  - externalsecret-migrate.yaml\n  - migrate-job.yaml\n"
    "  - deployment.yaml\n  - deployment-celery.yaml\n  - service.yaml\n  - ingress.yaml\n"
)


def test_check_base_kustomization_golden() -> None:
    assert check_base_kustomization(GOLDEN_BASE_KUSTOMIZATION) == []


@pytest.mark.parametrize(
    "text",
    [
        GOLDEN_BASE_KUSTOMIZATION + "images:\n  - name: ghcr.io/joshua92y/sample-pod\n    newTag: latest\n",
        GOLDEN_BASE_KUSTOMIZATION + "namespace: jt-dev\n",
        GOLDEN_BASE_KUSTOMIZATION + "commonLabels:\n  app.kubernetes.io/part-of: joshuatech\n",
        "- just\n- a list\n",
        "resources: [\n",
    ],
    ids=["images", "namespace", "common-labels", "not-mapping", "not-yaml"],
)
def test_check_base_kustomization_mutation_caught(text: str) -> None:
    assert check_base_kustomization(text)


# ---------- gen-33 Dockerfile 정적 검사(D18) ----------

BUILDER_DIGEST = "sha256:" + "a" * 64
RUNTIME_DIGEST = "sha256:" + "b" * 64
BUILDER_FROM = f"FROM ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim@{BUILDER_DIGEST} AS builder"
RUNTIME_FROM = f"FROM python:3.13-slim-trixie@{RUNTIME_DIGEST}"
GOLDEN_CMD = 'CMD ["gunicorn", "--config", "python:sample_pod.gunicorn_conf", "--no-control-socket", "sample_pod.wsgi:application"]'
GOLDEN_DOCKERFILE = "\n".join(
    [
        BUILDER_FROM,
        "ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never",
        "WORKDIR /src/apps/sample-pod",
        "COPY packages/django-common/pyproject.toml /src/packages/django-common/pyproject.toml",
        "COPY packages/django-common/src /src/packages/django-common/src",
        "COPY apps/sample-pod/pyproject.toml apps/sample-pod/uv.lock ./",
        "RUN uv sync --locked --no-install-project --no-dev --no-editable",
        "COPY apps/sample-pod/ ./",
        "RUN uv sync --locked --no-dev --no-editable",
        RUNTIME_FROM,
        "ARG APP_VERSION=0.0.0+local",
        "ARG APP_GIT_SHA=0000000",
        "LABEL org.opencontainers.image.revision=$APP_GIT_SHA",
        "RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid 10001 --no-create-home "
        "--home-dir /nonexistent --shell /usr/sbin/nologin app",
        "WORKDIR /src/apps/sample-pod",
        "COPY --from=builder /src/apps/sample-pod /src/apps/sample-pod",
        "ENV PATH=/src/apps/sample-pod/.venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 "
        "DJANGO_SETTINGS_MODULE=sample_pod.settings APP_VERSION=$APP_VERSION APP_GIT_SHA=$APP_GIT_SHA",
        "USER 10001:10001",
        "EXPOSE 8000 9100 9464",
        GOLDEN_CMD,
        "",
    ]
)
RUNTIME_USER = "USER 10001:10001"


def test_check_dockerfile_text_golden() -> None:
    assert check_dockerfile_text(GOLDEN_DOCKERFILE) == []


@pytest.mark.parametrize(
    "text",
    [
        "# syntax=docker/dockerfile:1@" + "sha256:" + "d" * 64 + "\n" + GOLDEN_DOCKERFILE,
        "# 빌드 단계 — 주석 줄은 무시한다\n" + GOLDEN_DOCKERFILE,
        replace_once(GOLDEN_DOCKERFILE, RUNTIME_FROM, f"FROM --platform=linux/arm64 python:3.13-slim-trixie@{RUNTIME_DIGEST} AS runtime"),
        replace_once(GOLDEN_DOCKERFILE, GOLDEN_CMD, "CMD gunicorn --config python:sample_pod.gunicorn_conf --no-control-socket sample_pod.wsgi:application"),
        replace_once(GOLDEN_DOCKERFILE, "ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy", "ENV UV_COMPILE_BYTECODE=1 \\\n    UV_LINK_MODE=copy"),
        GOLDEN_DOCKERFILE + "FROM builder AS debug\nUSER 10001:10001\n" + GOLDEN_CMD + "\n",
        replace_once(GOLDEN_DOCKERFILE, "COPY --from=builder", "COPY --from=0"),
    ],
    ids=["pinned-syntax", "leading-comment", "platform-flag-and-alias", "shell-form-cmd", "env-continuation", "stage-reference", "copy-from-index"],
)
def test_check_dockerfile_text_equivalent_spellings_accepted(text: str) -> None:
    assert check_dockerfile_text(text) == []


DOCKERFILE_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("builder-tag-only", swap(BUILDER_FROM, "FROM ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim AS builder")),
    ("runtime-tag-only", swap(RUNTIME_FROM, "FROM python:3.13-slim-trixie")),
    ("runtime-short-digest", swap(RUNTIME_FROM, "FROM python:3.13-slim-trixie@sha256:abc")),
    ("runtime-variable-image", swap(RUNTIME_FROM, "FROM ${BASE_IMAGE}")),
    ("unpinned-syntax", lambda t: "# syntax=docker/dockerfile:1\n" + t),
    ("copy-from-external-unpinned", swap("COPY --from=builder", "COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/uv\nCOPY --from=builder")),
    ("user-name", swap(RUNTIME_USER, "USER app")),
    ("user-without-group", swap(RUNTIME_USER, "USER 10001")),
    ("user-missing", swap(RUNTIME_USER + "\n", "")),
    ("user-only-in-builder", lambda t: replace_once(replace_once(t, RUNTIME_USER + "\n", ""), "WORKDIR /src/apps/sample-pod\nCOPY packages", "WORKDIR /src/apps/sample-pod\nUSER 10001:10001\nCOPY packages")),
    ("user-reset-to-root", swap(RUNTIME_USER, RUNTIME_USER + "\nUSER root")),
    ("cmd-without-flag", swap(GOLDEN_CMD, 'CMD ["gunicorn", "--config", "python:sample_pod.gunicorn_conf", "sample_pod.wsgi:application"]')),
    ("cmd-missing", swap(GOLDEN_CMD + "\n", "")),
    ("env-ssl-cert-file", lambda t: t + "ENV SSL_CERT_FILE=/etc/ssl/custom.pem\n"),
    ("env-pgoptions-quoted", lambda t: t + 'ENV PGOPTIONS="-c statement_timeout=0"\n'),
    ("env-lowercase-proxy-continuation", lambda t: t + "ENV LANG=C.UTF-8 \\\n    http_proxy=http://proxy.internal:3128\n"),
    ("env-legacy-form-netrc", lambda t: t + "ENV NETRC /tmp/netrc\n"),
    ("env-multiproc-in-builder", swap("ENV UV_COMPILE_BYTECODE=1", "ENV PROMETHEUS_MULTIPROC_DIR=/tmp/prom UV_COMPILE_BYTECODE=1")),
    ("env-unreadable", lambda t: t + 'ENV BROKEN="unterminated\n'),
    ("no-from", lambda t: "\n".join(line for line in t.splitlines() if not line.startswith("FROM"))),
    # T072 ③ r2 M6: CMD는 정확히 이미지 CMD 토큰(_render.WEB_COMMAND — deploy/base web 명령 · README 「프로세스」와 같은 상수)
    ("cmd-other-app", swap(GOLDEN_CMD, GOLDEN_CMD.replace("sample_pod.wsgi:application", "other_pod.wsgi:application"))),
    ("cmd-extra-workers", swap(GOLDEN_CMD, GOLDEN_CMD.replace('"--no-control-socket", ', '"--no-control-socket", "--workers", "4", '))),
]


@pytest.mark.parametrize(("name", "mutate"), DOCKERFILE_MUTATIONS, ids=[name for name, _ in DOCKERFILE_MUTATIONS])
def test_check_dockerfile_text_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert check_dockerfile_text(mutate(GOLDEN_DOCKERFILE)), f"{name}: 위반을 잡지 못했다"


# ---------- gen-33 이미지 구성(docker image inspect) ----------

GOLDEN_IMAGE_CONFIG: dict[str, Any] = {
    "Architecture": "arm64",
    "Os": "linux",
    "Config": {
        "User": "10001:10001",
        "Env": [
            "PATH=/src/apps/sample-pod/.venv/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
            "LANG=C.UTF-8",
            "PYTHON_VERSION=3.13.18",
            "PYTHONDONTWRITEBYTECODE=1",
            "PYTHONUNBUFFERED=1",
            "DJANGO_SETTINGS_MODULE=sample_pod.settings",
            "APP_VERSION=0.0.0+local",
            "APP_GIT_SHA=0000000",
        ],
        "Labels": {"org.opencontainers.image.revision": "0000000"},
        # T072 마지막 라운드 N4(③ r2 리뷰 A-1): exec 꼴 CMD = 이미지 CMD 상수 · ENTRYPOINT 없음(docker inspect는 null로 싣는다)
        "Cmd": list(_render.WEB_COMMAND),
        "Entrypoint": None,
    },
}


def image_config(**config: Any) -> list[dict[str, Any]]:
    data = json.loads(json.dumps(GOLDEN_IMAGE_CONFIG))
    for key, value in config.items():
        if value is None:
            data["Config"].pop(key, None)
        else:
            data["Config"][key] = value
    return [data]


def with_env(entry: str) -> list[str]:
    return [*GOLDEN_IMAGE_CONFIG["Config"]["Env"], entry]


def test_check_image_config_golden() -> None:
    assert check_image_config(image_config()) == []
    assert check_image_config(GOLDEN_IMAGE_CONFIG) == []  # 목록 없이 객체 하나도 받는다
    # ENTRYPOINT 없음의 같은 뜻(N4): null · 빈 목록 · 키 없음
    assert check_image_config(image_config(Entrypoint=[])) == []
    assert check_image_config(image_config(Entrypoint=None)) == []


@pytest.mark.parametrize(
    "inspect",
    [
        image_config(User="app"),
        image_config(User="10001"),
        image_config(User=""),
        image_config(User=None),
        image_config(Env=with_env("SSL_CERT_DIR=/etc/ssl/extra")),
        image_config(Env=with_env("pgpassword=x")),
        image_config(Env=with_env("ALL_PROXY=socks5://proxy.internal:1080")),
        image_config(Env=with_env("PROMETHEUS_MULTIPROC_DIR=/tmp/prom")),
        image_config(Env=["PATH=/usr/bin", 7]),
        image_config(Labels={}),
        image_config(Labels={"org.opencontainers.image.revision": ""}),
        image_config(Labels=None),
        [GOLDEN_IMAGE_CONFIG, GOLDEN_IMAGE_CONFIG],
        "not json object",
        # T072 마지막 라운드 N4(③ r2 리뷰 A-1 실측): 셸 꼴 CMD는 PID 1이 sh라 SIGTERM이 gunicorn에 닿지 않는다(15.5 s 뒤 SIGKILL) ·
        # ENTRYPOINT가 있으면 deploy/base command + args가 실제 실행 명령이 아니다
        image_config(Cmd=["/bin/sh", "-c", " ".join(_render.WEB_COMMAND)]),
        image_config(Entrypoint=["/bin/sh", "-c"]),
        image_config(Cmd=None),
    ],
    ids=[
        "user-name",
        "user-without-group",
        "user-empty",
        "user-missing",
        "env-ssl-cert-dir",
        "env-libpq-lowercase",
        "env-all-proxy",
        "env-multiproc",
        "env-not-string",
        "revision-label-missing",
        "revision-label-empty",
        "labels-missing",
        "two-images",
        "not-mapping",
        "cmd-shell-form",
        "entrypoint-set",
        "cmd-missing",
    ],
)
def test_check_image_config_mutation_caught(inspect: Any) -> None:
    assert check_image_config(inspect)


@pytest.mark.parametrize(
    ("inspect", "word"),
    [
        (image_config(Cmd=["/bin/sh", "-c", " ".join(_render.WEB_COMMAND)]), "Config.Cmd"),
        (image_config(Entrypoint=["/bin/sh", "-c"]), "Config.Entrypoint"),
        (image_config(Entrypoint=["tini", "--"]), "Config.Entrypoint"),
        (image_config(Cmd=[*_render.WEB_COMMAND, "--workers", "4"]), "Config.Cmd"),
    ],
    ids=["shell-form-cmd", "entrypoint-shell", "entrypoint-init", "cmd-extra-args"],
)
def test_check_image_config_exec_form_cmd_without_entrypoint(inspect: Any, word: str) -> None:
    """이미지 CMD 꼴 결속(T072 마지막 라운드 N4) — Config.Cmd == WEB_COMMAND(exec 꼴) · Config.Entrypoint 없음(null 또는 []). 정적 검사의
    같은 뜻 [shell-form-cmd](Dockerfile 글 판정)는 그대로 두고 빌드 산출물(docker image inspect)에서 잡는다 — 위반은 그 필드 하나만 이름한다."""
    found = check_image_config(inspect)
    assert len(found) == 1 and word in found[0], found


def test_check_image_config_never_prints_env_values() -> None:
    planted = "planted-value-" + "x" * 20
    found = check_image_config(image_config(Env=with_env(f"SSLKEYLOGFILE={planted}")))
    assert found and all(planted not in item for item in found)


def test_forbidden_env_list_is_shared_with_render_hygiene() -> None:
    assert FORBIDDEN_ENV_NAMES is _render.FORBIDDEN_ENV_NAMES  # 하나의 상수(①a env_hygiene과 같은 목록)
    for name in FORBIDDEN_ENV_NAMES:
        assert forbidden_env_name(name) and forbidden_env_name(name.lower()), name
    for name in ("PGOPTIONS", "PGSSLMODE", "https_proxy", "NO_PROXY", "requests_ca_bundle"):
        assert forbidden_env_name(name), name
    for name in ("PATH", "LANG", "PYTHONDONTWRITEBYTECODE", "PYTHONUNBUFFERED", "DJANGO_SETTINGS_MODULE", "APP_GIT_SHA", "UV_LINK_MODE"):
        assert not forbidden_env_name(name), name


# ---------- gen-33 이미지 탐침(JSON 한 줄) ----------

GOLDEN_IMAGE_PROBE: dict[str, Any] = {
    "uid": 10001,
    "gid": 10001,
    "home": "/nonexistent",
    "netrc": [],
    "python": [3, 13, 18],
    "prefix": "/src/apps/sample-pod/.venv",
    "django_common_file": "/src/apps/sample-pod/.venv/lib/python3.13/site-packages/django_common/__init__.py",
    "django_common_error": None,
    "ninja_version": "1.7.0",
    "src_packages_exists": False,
    "sensitive_files": [],
    # T072 조각 ③ 지시 5: /src/apps/<pod> 최상위 항목(정렬) · 빌드 감시 파일 .venv/jt-harness-sentinel 유무
    "pod_entries": [".venv", "manage.py", "pyproject.toml", "sample_pod", "uv.lock"],
    "venv_sentinel": False,
    # T072 ③ r2 M3: 이미지 venv에 있는 dev 전용 배포(uv sync --no-dev — 없어야 한다)
    "dev_distributions": [],
}


def image_probe(**changes: Any) -> dict[str, Any]:
    return {**GOLDEN_IMAGE_PROBE, **changes}


def test_check_image_probe_golden() -> None:
    assert check_image_probe(GOLDEN_IMAGE_PROBE) == []
    assert check_image_probe(image_probe(python=[3, 13, 2])) == []  # 하한 그 값


@pytest.mark.parametrize(
    "facts",
    [
        image_probe(uid=0),
        image_probe(gid=0),
        image_probe(netrc=[".netrc"]),
        image_probe(python=[3, 13, 1]),
        image_probe(python=[3, 12, 9]),
        image_probe(python="3.13.18"),
        image_probe(django_common_file="/src/packages/django-common/src/django_common/__init__.py"),
        image_probe(django_common_file="/usr/local/lib/python3.13/site-packages/django_common/__init__.py"),
        image_probe(django_common_file=None, django_common_error="ModuleNotFoundError"),
        image_probe(ninja_version="1.6.2"),
        image_probe(ninja_version=None),
        image_probe(src_packages_exists=True),
        image_probe(sensitive_files=[".env"]),
        image_probe(sensitive_files=["sample_pod/dev.key", "certs/local.pem"]),
        ["not", "a", "mapping"],
    ],
    ids=[
        "uid-root",
        "gid-root",
        "netrc-present",
        "python-3-13-1",
        "python-3-12",
        "python-not-list",
        "django-common-editable",
        "django-common-outside-venv",
        "django-common-missing",
        "ninja-other",
        "ninja-missing",
        "src-packages-present",
        "dotenv-present",
        "keys-present",
        "not-mapping",
    ],
)
def test_check_image_probe_mutation_caught(facts: Any) -> None:
    assert check_image_probe(facts)


# ---------- gen-32 변형 settings 탐침(JSON 한 줄) ----------

ADMIN_MIDDLEWARE = [
    "django_common.observability.RequestIdMiddleware",
    "sample_pod.middleware.HttpMetricsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.middleware.common.CommonMiddleware",
    "sample_pod.middleware.AdminHostMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "django_common.auth.JwtAuthMiddleware",
    "django_common.tenancy.TenantContextMiddleware",
]
ADMIN_ONLY_MIDDLEWARE = {
    "sample_pod.middleware.AdminHostMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
}
POD_APPS = ["sample_pod", "sample_pod.core", "django_common", "tests.rlsapp", "django_migration_linter"]
CONTRIB_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
]
GOLDEN_SETTINGS_ADMIN: dict[str, Any] = {
    "celery_imported": False,
    "installed_apps": [*CONTRIB_APPS, *POD_APPS],
    "middleware": ADMIN_MIDDLEWARE,
    "templates": 1,
    "has_admin_urlconf": True,
}
GOLDEN_SETTINGS_NO_ADMIN: dict[str, Any] = {
    "celery_imported": False,
    "installed_apps": POD_APPS,
    "middleware": [item for item in ADMIN_MIDDLEWARE if item not in ADMIN_ONLY_MIDDLEWARE],
    "templates": 0,
    "has_admin_urlconf": False,
}


def test_check_variant_settings_golden() -> None:
    assert check_variant_settings(GOLDEN_SETTINGS_ADMIN, has_admin=True) == []
    assert check_variant_settings(GOLDEN_SETTINGS_NO_ADMIN, has_admin=False) == []


def without(items: list[str], removed: str) -> list[str]:
    return [item for item in items if item != removed]


VARIANT_SETTINGS_MUTATIONS: list[tuple[str, bool, dict[str, Any]]] = [
    ("admin-celery-imported", True, {**GOLDEN_SETTINGS_ADMIN, "celery_imported": True}),
    ("admin-app-missing", True, {**GOLDEN_SETTINGS_ADMIN, "installed_apps": without(GOLDEN_SETTINGS_ADMIN["installed_apps"], "django.contrib.admin")}),
    ("admin-session-middleware-missing", True, {**GOLDEN_SETTINGS_ADMIN, "middleware": without(ADMIN_MIDDLEWARE, "django.contrib.sessions.middleware.SessionMiddleware")}),
    ("admin-templates-missing", True, {**GOLDEN_SETTINGS_ADMIN, "templates": 0}),
    ("admin-urlconf-missing", True, {**GOLDEN_SETTINGS_ADMIN, "has_admin_urlconf": False}),
    ("no-admin-celery-imported", False, {**GOLDEN_SETTINGS_NO_ADMIN, "celery_imported": True}),
    ("no-admin-contrib-app", False, {**GOLDEN_SETTINGS_NO_ADMIN, "installed_apps": ["django.contrib.contenttypes", *POD_APPS]}),
    ("no-admin-session-middleware", False, {**GOLDEN_SETTINGS_NO_ADMIN, "middleware": ADMIN_MIDDLEWARE}),
    ("no-admin-auth-middleware", False, {**GOLDEN_SETTINGS_NO_ADMIN, "middleware": [*GOLDEN_SETTINGS_NO_ADMIN["middleware"], "django.contrib.auth.middleware.AuthenticationMiddleware"]}),
    ("no-admin-templates", False, {**GOLDEN_SETTINGS_NO_ADMIN, "templates": 1}),
    ("no-admin-urlconf", False, {**GOLDEN_SETTINGS_NO_ADMIN, "has_admin_urlconf": True}),
    ("apps-not-list", False, {**GOLDEN_SETTINGS_NO_ADMIN, "installed_apps": "sample_pod"}),
    ("not-mapping", True, ["celery_imported", False]),  # type: ignore[dict-item]
]


@pytest.mark.parametrize(
    ("name", "has_admin", "facts"), VARIANT_SETTINGS_MUTATIONS, ids=[name for name, _, _ in VARIANT_SETTINGS_MUTATIONS]
)
def test_check_variant_settings_mutation_caught(name: str, has_admin: bool, facts: Any) -> None:
    assert check_variant_settings(facts, has_admin=has_admin), f"{name}: 위반을 잡지 못했다"


# ---------- gen-34 ④ 기동 실패 출력 · 로그 쓰기 오류 · 비밀 누출 ----------

STARTUP_STDOUT = '{"ts": "2026-11-07T00:00:00Z", "level": "warning", "logger": "x", "event": "db_connect_retry", "error": "OperationalError"}\n'
STARTUP_STDERR = "startup_check: FAIL OperationalError\n"


def test_check_startup_failure_golden() -> None:
    assert check_startup_failure(1, STARTUP_STDOUT, STARTUP_STDERR) == []
    assert check_startup_failure(1, "", "startup_check: FAIL psycopg.OperationalError\n") == []
    assert check_startup_failure(1, "", "startup_check: FAIL django.db.utils.OperationalError\n") == []


@pytest.mark.parametrize(
    ("returncode", "stdout", "stderr"),
    [
        (0, STARTUP_STDOUT, STARTUP_STDERR),
        (2, STARTUP_STDOUT, STARTUP_STDERR),
        (None, STARTUP_STDOUT, STARTUP_STDERR),
        (1, STARTUP_STDOUT, ""),
        (1, STARTUP_STDOUT, STARTUP_STDERR + "startup_check: FAIL OperationalError\n"),
        (1, STARTUP_STDOUT, "startup_check: FAIL OperationalError: connection to server failed\n"),
        (1, STARTUP_STDOUT, "startup_check: ERROR OperationalError\n"),
        (1, STARTUP_STDOUT, "Traceback (most recent call last):\n  File \"x.py\", line 1\nOperationalError: boom\n"),
        (1, "Traceback (most recent call last):\n", STARTUP_STDERR),
        (1, STARTUP_STDOUT, "startup_check: FAIL ImportError\n"),
        (1, STARTUP_STDOUT, "startup_check: FAIL django.core.exceptions.ImproperlyConfigured\n"),
        (1, STARTUP_STDOUT, "startup_check: FAIL OperationalErrorWrapper\n"),
    ],
    ids=[
        "exit-0",
        "exit-2",
        "timeout",
        "stderr-empty",
        "stderr-two-lines",
        "message-appended",
        "wrong-prefix",
        "traceback-stderr",
        "traceback-stdout",
        "other-class-import-error",
        "other-class-improperly-configured",
        "other-class-suffix",
    ],
)
def test_check_startup_failure_mutation_caught(returncode: int | None, stdout: str, stderr: str) -> None:
    assert check_startup_failure(returncode, stdout, stderr)


def test_check_log_write_errors() -> None:
    assert check_log_write_errors('{"event": "relay_started"}\n[INFO] Booting worker\n') == []
    assert check_log_write_errors("OSError: [Errno 30] Read-only file system: '/src/apps/sample-pod/x'\n")
    assert check_log_write_errors("PermissionError: [Errno 13] Permission denied: '/var/run/x'\n")


def test_check_secret_leaks_names_only() -> None:
    planted = {"SECRET_KEY": "k" * 64, "DATABASE_URL 비밀번호": "p" * 43}
    assert check_secret_leaks("clean output\n", planted) == []
    found = check_secret_leaks("boom " + "p" * 43 + "\n", planted)
    assert len(found) == 1 and "DATABASE_URL" in found[0] and "p" * 43 not in found[0]
    assert check_secret_leaks("anything", {"EMPTY": ""}) == []  # 빈 값은 찾지 않는다(모든 글에 들어 있다)


# ---------- gen-28 copier validator 거부(copier 9.19.1 실측 꼴) ----------

COPIER_TRACEBACK = (
    "Traceback (most recent call last):\n"
    '  File "<frozen runpy>", line 203, in _run_module_as_main\n'
    '  File ".venv/Lib/site-packages/copier/_main.py", line 655, in _ask\n'
    "    question.validate_answer(answer)\n"
    '  File ".venv/Lib/site-packages/copier/_user_data.py", line 472, in validate_answer\n'
    "    raise ValueError(\n"
)
REJECTION_LINE = "ValueError: Validation error for question 'pod_name': invalid pod_name: must be kebab-case (a-z, 0-9, -)"


def test_check_validator_rejection_golden() -> None:
    assert check_validator_rejection(1, COPIER_TRACEBACK + REJECTION_LINE + "\n", "pod_name") == []
    # 나중 copier가 ValueError를 깔끔한 한 줄로 낼 때도 같은 판정
    assert check_validator_rejection(1, "Validation error for question 'pod_name': invalid pod_name: bad\n", "pod_name") == []


@pytest.mark.parametrize(
    ("returncode", "stderr", "question"),
    [
        (0, "", "pod_name"),
        (None, COPIER_TRACEBACK + REJECTION_LINE + "\n", "pod_name"),
        (1, COPIER_TRACEBACK + "jinja2.exceptions.UndefinedError: 'pod_snake' is undefined\n", "pod_name"),
        (1, "invalid pod_name: early line\n" + COPIER_TRACEBACK + "TypeError: boom\n", "pod_name"),
        (1, COPIER_TRACEBACK + REJECTION_LINE + "\n", "pod_snake"),
        (1, COPIER_TRACEBACK + "ValueError: Validation error for question 'pod_name': must be kebab-case\n", "pod_name"),
        (1, COPIER_TRACEBACK + "ValueError: Validation error for question 'pod_name': invalid pod_name: 케밥 꼴이어야 한다\n", "pod_name"),
    ],
    ids=["accepted", "timeout", "other-exception", "marker-not-last", "other-question", "prefix-missing", "non-ascii-message"],
)
def test_check_validator_rejection_mutation_caught(returncode: int | None, stderr: str, question: str) -> None:
    assert check_validator_rejection(returncode, stderr, question)


# ---------- _layout.py — copier 선택 인자 · 변형 정의 · venv ----------


def test_copier_copy_argv_default_is_unchanged(tmp_path: Path) -> None:
    destination = tmp_path / "apps" / "sample-pod"
    assert copier_copy_argv("sample-pod", destination) == [
        sys.executable,
        "-m",
        "copier",
        "copy",
        "--trust",
        "--defaults",
        "--quiet",
        "--data",
        "pod_name=sample-pod",
        str(TEMPLATE_DIR),
        str(destination),
    ]


def test_copier_copy_argv_render_only_options(tmp_path: Path) -> None:
    destination = tmp_path / "variants" / "no-admin" / "apps" / "sample-pod"
    argv = copier_copy_argv(
        "sample-pod", destination, extra_data=("has_celery=false", "has_admin=false"), skip_tasks=True, pretend=True
    )
    assert "--trust" not in argv
    assert argv[:5] == [sys.executable, "-m", "copier", "copy", "--skip-tasks"]
    assert {"--defaults", "--quiet", "--pretend"} <= set(argv)
    assert [argv[index + 1] for index, item in enumerate(argv) if item == "--data"] == [
        "pod_name=sample-pod",
        "has_celery=false",
        "has_admin=false",
    ]
    assert argv[-2:] == [str(TEMPLATE_DIR), str(destination)]
    assert "--pretend" not in copier_copy_argv("sample-pod", destination, skip_tasks=True)


def test_variants_match_design_d21() -> None:
    by_name = {variant.name: variant for variant in VARIANTS}
    assert list(by_name) == ["no-celery", "no-admin"]
    no_celery, no_admin = by_name["no-celery"], by_name["no-admin"]
    assert no_celery.data == (
        "has_celery=false",
        "owns_events=[thing.created]",
        "consumes_events=[other-pod.thing.created]",
    )
    assert (no_celery.has_celery, no_celery.has_admin, no_celery.consumes) == (False, True, True)
    assert no_admin.data == ("has_celery=false", "has_admin=false")
    assert (no_admin.has_celery, no_admin.has_admin, no_admin.consumes) == (False, False, False)
    for variant in VARIANTS:
        data = dict(item.split("=", 1) for item in variant.data)
        assert tuple(yaml.safe_load(data.get("owns_events", "[]"))) == variant.owns_events
        assert tuple(yaml.safe_load(data.get("consumes_events", "[]"))) == variant.consumes_events
        assert ("has_celery=false" in variant.data) is (not variant.has_celery)
        assert ("has_admin=false" in variant.data) is (not variant.has_admin)


def test_variant_destination_is_render_only_layout(tmp_path: Path) -> None:
    variant = VARIANTS[0]
    assert variant_destination(tmp_path, variant) == tmp_path / "variants" / variant.name / "apps" / "sample-pod"


def test_venv_python_path(tmp_path: Path) -> None:
    expected = ("Scripts", "python.exe") if os.name == "nt" else ("bin", "python")
    assert venv_python(tmp_path) == tmp_path.joinpath(".venv", *expected)


# ---------- _proc.py — 자식 env · 탐침 줄 · 지표 표본 · docker 인자 · 컨테이너 상태 ----------


def test_child_env_overrides_and_removals(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("VIRTUAL_ENV", "C:/elsewhere/.venv")
    monkeypatch.setenv("JT_T072_REMOVE_ME", "1")
    env = child_env({"JT_T072_SET_ME": "set", "JT_T072_REMOVE_ME": None})
    assert "VIRTUAL_ENV" not in env
    assert env["PYTHONIOENCODING"] == "utf-8"
    assert env["JT_T072_SET_ME"] == "set"
    assert "JT_T072_REMOVE_ME" not in env
    assert "JT_T072_SET_ME" not in child_env()
    assert child_env()["JT_T072_REMOVE_ME"] == "1"


def test_run_passes_extra_env_to_child(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    script = "import os; print(os.environ.get('JT_T072_PROBE', 'missing'), os.environ.get('JT_T072_GONE', 'gone'))"
    monkeypatch.setenv("JT_T072_GONE", "present")
    result = run(
        [sys.executable, "-c", script], cwd=tmp_path, timeout=60, env={"JT_T072_PROBE": "seen", "JT_T072_GONE": None}
    )
    assert result.ok, result.stderr
    assert result.stdout.split() == ["seen", "gone"]


def test_parse_probe_line_takes_last_marker() -> None:
    text = (
        '{"event": "log line before"}\n'
        + PROBE_MARKER
        + json.dumps({"first": True})
        + "\nnoise\n"
        + PROBE_MARKER
        + json.dumps({"uid": 10001})
        + "\n"
    )
    assert parse_probe_line(text) == {"uid": 10001}
    assert parse_probe_line("no marker here\n") is None
    assert parse_probe_line(PROBE_MARKER + "{broken\n") is None


def test_metric_samples_exact_name() -> None:
    text = (
        "# HELP http_requests_total HTTP 요청 수\n"
        "# TYPE http_requests_total counter\n"
        'http_requests_total{route="healthz",status="200"} 1.0\n'
        'http_requests_created{route="healthz",status="200"} 1.7e+09\n'
        "http_requests_total_other 3.0\n"
        "http_requests_total 2.0\n"
    )
    assert metric_samples(text, "http_requests_total") == [
        'http_requests_total{route="healthz",status="200"} 1.0',
        "http_requests_total 2.0",
    ]
    assert metric_samples("# HELP http_requests_total x\n# TYPE http_requests_total counter\n", "http_requests_total") == []


def test_docker_run_argv_shapes() -> None:
    detached = docker_run_argv("docker", "jt-sample-pod:t065", "jt-smoke-web-x", detach=True, env_args=("-e", "ENV=test"))
    assert detached[:4] == ["docker", "run", "--name", "jt-smoke-web-x"]
    for flags in (["--network", "none"], ["--read-only"], ["--tmpfs", "/tmp"], ["--platform", "linux/arm64"]):
        assert any(detached[index : index + len(flags)] == flags for index in range(len(detached))), flags
    assert "-d" in detached and "--rm" not in detached and "--user" not in detached
    assert detached[-1] == "jt-sample-pod:t065"
    assert detached.index("ENV=test") < detached.index("jt-sample-pod:t065")
    probe = docker_run_argv(
        "docker", "jt-sample-pod:t065", "jt-smoke-probe-x", interactive=True, entrypoint="python", command=("-", "/src")
    )
    assert "--rm" in probe and "-i" in probe and "-d" not in probe
    assert probe[probe.index("--entrypoint") + 1] == "python"
    assert probe[-3:] == ["jt-sample-pod:t065", "-", "/src"]


def test_parse_container_state() -> None:
    assert parse_container_state("running 0\n") == ("running", 0)
    assert parse_container_state("exited 1\n") == ("exited", 1)
    assert parse_container_state("") == (None, None)
    assert parse_container_state("garbage") == (None, None)


def test_smoke_container_name_is_prefixed_and_unique() -> None:
    first, second = smoke_container_name("web"), smoke_container_name("web")
    assert first.startswith("jt-smoke-web-") and len(first) == len("jt-smoke-web-") + 8
    assert first != second


# ---------- 탐침 스크립트(컨테이너 · 기본 pod venv 안에서 python -로 돈다) — 호스트 python으로 먼저 굳힌다 ----------


def run_probe(script: str, args: list[str], cwd: Path, env: dict[str, str | None] | None = None) -> Any:
    result = run([sys.executable, "-", *args], cwd=cwd, timeout=60, input_text=script, env=env)
    assert result.ok, result.stderr
    return parse_probe_line(result.stdout)


@pytest.mark.parametrize(
    "script",
    [HTTP_PROBE_SCRIPT, GLOB_PROBE_SCRIPT, IMAGE_PROBE_SCRIPT, SETTINGS_PROBE_SCRIPT],
    ids=["http", "glob", "image", "settings"],
)
def test_probe_scripts_compile_and_print_marker(script: str) -> None:
    compile(script, "<probe>", "exec")
    assert f'print("{PROBE_MARKER}" + json.dumps(' in script


class _MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 — http.server 이름
        if self.path == "/metrics":
            body = '# HELP http_requests_total x\n# TYPE http_requests_total counter\nhttp_requests_total{route="healthz"} 1.0\nother 2\n'
            self.send_response(200)
        else:
            body = "missing"
            self.send_response(404)
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A002 — 서버 로그를 시험 출력에 찍지 않는다
        return


def test_http_probe_script_reports_status_and_filtered_lines(tmp_path: Path) -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _MetricsHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = f"http://127.0.0.1:{server.server_address[1]}"
        metrics = run_probe(HTTP_PROBE_SCRIPT, [f"{base}/metrics", "http_requests_total"], tmp_path)
        missing = run_probe(HTTP_PROBE_SCRIPT, [f"{base}/nope"], tmp_path)
    finally:
        server.shutdown()
        server.server_close()
    assert metrics["status"] == 200 and metrics["error"] is None
    assert metric_samples("\n".join(metrics["lines"]), "http_requests_total") == ['http_requests_total{route="healthz"} 1.0']
    assert missing["status"] == 404
    closed = socket.socket()
    closed.bind(("127.0.0.1", 0))
    port = closed.getsockname()[1]
    closed.close()
    refused = run_probe(HTTP_PROBE_SCRIPT, [f"http://127.0.0.1:{port}/healthz"], tmp_path)
    assert refused["status"] is None and refused["error"]


def test_glob_probe_script_lists_matches(tmp_path: Path) -> None:
    (tmp_path / "celerybeat-schedule.db").write_text("", encoding="utf-8")
    (tmp_path / "other").write_text("", encoding="utf-8")
    assert run_probe(GLOB_PROBE_SCRIPT, [str(tmp_path / "celerybeat-schedule*")], tmp_path) == [
        str(tmp_path / "celerybeat-schedule.db")
    ]
    assert run_probe(GLOB_PROBE_SCRIPT, [str(tmp_path / "absent*")], tmp_path) == []


def test_image_probe_script_facts_shape(tmp_path: Path) -> None:
    pod = tmp_path / "pod"
    for relative in (".env", "certs/local.pem", "keys/dev.key", "sample_pod/settings.py", ".venv/lib/certifi/cacert.pem"):
        write_empty(pod, relative)
    facts = run_probe(IMAGE_PROBE_SCRIPT, [str(pod)], tmp_path)
    assert set(facts) == set(GOLDEN_IMAGE_PROBE)  # 판정 함수(check_image_probe)가 읽는 키와 같다
    assert facts["sensitive_files"] == [".env", "certs/local.pem", "keys/dev.key"]  # .venv 안(PyPI 패키지)은 보지 않는다
    assert facts["python"] == list(sys.version_info[:3])
    assert facts["django_common_file"] is None and facts["django_common_error"] == "ModuleNotFoundError"
    assert facts["ninja_version"] is None  # 하네스 venv에는 django-ninja가 없다


FAKE_DJANGO_INIT = "def setup():\n    pass\n"
FAKE_DJANGO_CONF = """\
class _Settings:
    ROOT_URLCONF = "fake_urls"
    ADMIN_URLCONF = "fake_admin_urls"
    INSTALLED_APPS = {apps!r}
    MIDDLEWARE = {middleware!r}
    TEMPLATES = [{{"BACKEND": "django.template.backends.django.DjangoTemplates"}}]


settings = _Settings()
"""


def test_settings_probe_script_feeds_check_variant_settings(tmp_path: Path) -> None:
    write_empty(tmp_path, "fake_urls.py")
    (tmp_path / "fake_admin_urls.py").write_text("import celery\n", encoding="utf-8")
    (tmp_path / "celery.py").write_text("", encoding="utf-8")  # 관리자 urlconf가 celery를 import하면 잡혀야 한다
    (tmp_path / "django").mkdir()
    (tmp_path / "django" / "__init__.py").write_text(FAKE_DJANGO_INIT, encoding="utf-8")
    conf = FAKE_DJANGO_CONF.format(apps=GOLDEN_SETTINGS_ADMIN["installed_apps"], middleware=ADMIN_MIDDLEWARE)
    (tmp_path / "django" / "conf.py").write_text(conf, encoding="utf-8")
    facts = run_probe(SETTINGS_PROBE_SCRIPT, [], tmp_path, env={"PYTHONPATH": None})
    assert set(facts) == set(GOLDEN_SETTINGS_ADMIN)
    assert facts["celery_imported"] is True
    assert check_variant_settings(facts, has_admin=True) == [
        check_variant_settings({**GOLDEN_SETTINGS_ADMIN, "celery_imported": True}, has_admin=True)[0]
    ]
    (tmp_path / "fake_admin_urls.py").write_text("", encoding="utf-8")
    assert check_variant_settings(run_probe(SETTINGS_PROBE_SCRIPT, [], tmp_path, env={"PYTHONPATH": None}), has_admin=True) == []


# ==================== T072 r2(리뷰 r1 반영 E3 · E4 · E8–E13) ====================
# 새 이름은 모듈 속성(_proc.X · _tree.X)으로 부른다 — 하나가 빠져도 그 시험만 실패한다.


def proc_result(returncode: int | None, stdout: str = "", stderr: str = "") -> Any:
    return _proc.ProcResult(argv=("docker", "run"), cwd=".", returncode=returncode, stdout=stdout, stderr=stderr, seconds=0.0)


# ---------- E3 gen-34 ④ outbox_purge 실패 사유(DB 없음 = OperationalError) ----------

PURGE_TRACEBACK = (
    "Traceback (most recent call last):\n"
    '  File "/src/apps/sample-pod/.venv/lib/python3.13/site-packages/psycopg/connection.py", line 130, in connect\n'
    "    raise last_ex.with_traceback(None)\n"
    'psycopg.OperationalError: connection failed: connection to server at "127.0.0.1", port 15432 failed: Connection refused\n'
    "\tIs the server running on that host and accepting TCP/IP connections?\n"
    "\n"
    "The above exception was the direct cause of the following exception:\n"
    "\n"
    "Traceback (most recent call last):\n"
    '  File "/src/apps/sample-pod/manage.py", line 9, in <module>\n'
    "    execute_from_command_line(sys.argv)\n"
    'django.db.utils.OperationalError: connection failed: connection to server at "127.0.0.1", port 15432 failed: Connection refused\n'
    "\tIs the server running on that host and accepting TCP/IP connections?\n"
)


def test_check_purge_failure_golden() -> None:
    assert _tree.check_purge_failure(proc_result(1, "", PURGE_TRACEBACK)) == []
    # 마지막 줄로 고정하지 않는다 — psycopg 접속 오류 문구가 여러 줄이고, 예외 줄은 모듈 경로가 붙은 꼴이다
    assert _tree.check_purge_failure(proc_result(1, "", "OperationalError: connection failed\n\tmore detail\n")) == []


@pytest.mark.parametrize(
    "result",
    [
        proc_result(1, "", "Unknown command: 'outbox_purge'\nType 'manage.py help' for usage.\n"),
        proc_result(1, "", "Traceback (most recent call last):\n  File \"manage.py\", line 9\nImportError: cannot import name 'purge_dead'\n"),
        proc_result(1, "", "Traceback (most recent call last):\nModuleNotFoundError: No module named 'psycopg'\n"),
        proc_result(0, "outbox_purge: 0\n", ""),
        proc_result(1, "", "Traceback (most recent call last):\ndjango.core.exceptions.ImproperlyConfigured: 설정 오류: SECRET_KEY\n"),
        proc_result(1, "", "Traceback (most recent call last):\nRuntimeError: boom\n"),
        proc_result(None, "", PURGE_TRACEBACK + "\n[하네스] 시간 초과(240 s) — 프로세스 트리를 끝냈다"),
        proc_result(1, "", PURGE_TRACEBACK + "ModuleNotFoundError: No module named 'sample_pod'\n"),
    ],
    ids=[
        "unknown-command",
        "import-error",
        "module-not-found",
        "exit-0",
        "other-class-improperly-configured",
        "other-class-runtime-error",
        "timeout",
        "operational-plus-import-failure",
    ],
)
def test_check_purge_failure_mutation_caught(result: Any) -> None:
    assert _tree.check_purge_failure(result)


# r3 F3(r2 A-3): 정상 실패 꼴(PURGE_TRACEBACK — OperationalError 줄이 있다 · 종료 1)에 줄 하나씩 더한 사례 — 각각 그 규칙
# 하나만 걸린다(「예외 줄 없음」 규칙이 먼저 잡아 다른 규칙의 빈칸을 가리지 않게 · 규칙을 끈 사본에서 그 사례가 실패한다).
PURGE_RULE_CASES = [
    ("unknown-command-line", "Unknown command: 'outbox_purge'\n", "'Unknown command'"),
    ("improperly-configured-line", "django.core.exceptions.ImproperlyConfigured: 설정 오류: SECRET_KEY\n", "['ImproperlyConfigured']"),
    ("import-error-line", "ImportError: cannot import name 'purge_dead' from 'django_common.outbox'\n", "['ImportError']"),
]


@pytest.mark.parametrize(
    ("extra", "marker"), [(extra, marker) for _, extra, marker in PURGE_RULE_CASES], ids=[case for case, _, _ in PURGE_RULE_CASES]
)
def test_check_purge_failure_isolates_each_rule(extra: str, marker: str) -> None:
    found = _tree.check_purge_failure(proc_result(1, "", PURGE_TRACEBACK + extra))
    assert len(found) == 1 and marker in found[0], found


# ---------- E4 gen-28 받아들임 사례 — .copier-answers.yml이 주입 값을 그대로 기록한다 ----------

RECORDED_ANSWERS = (
    "# Changes here will be overwritten by Copier\n"
    "_src_path: /repo/templates/django-pod\n"
    "consumes_events:\n- other-pod.thing.created\n"
    "description: Sample pod\n"
    "has_admin: true\n"
    "has_celery: true\n"
    "owns_events:\n- thing.created\n"
    "pod_name: sample-pod\n"
)
RECORDED_EXPECTED = {
    "pod_name": "sample-pod",
    "owns_events": ["thing.created"],
    "consumes_events": ["other-pod.thing.created"],
    "description": "Sample pod",
}


def test_check_recorded_answers_golden() -> None:
    assert _tree.check_recorded_answers(RECORDED_ANSWERS, RECORDED_EXPECTED) == []
    assert _tree.check_recorded_answers(RECORDED_ANSWERS, {"pod_name": "sample-pod"}) == []


@pytest.mark.parametrize(
    "answers",
    [
        None,
        "pod_name: [unclosed\n",
        "- a list\n",
        RECORDED_ANSWERS.replace("description: Sample pod\n", ""),
        RECORDED_ANSWERS.replace("pod_name: sample-pod", "pod_name: other-pod"),
        RECORDED_ANSWERS.replace("owns_events:\n- thing.created\n", "owns_events: thing.created\n"),
        RECORDED_ANSWERS.replace("consumes_events:\n- other-pod.thing.created\n", "consumes_events: []\n"),
    ],
    ids=["file-missing", "not-yaml", "not-mapping", "key-missing", "pod-name-other", "list-as-string", "list-empty"],
)
def test_check_recorded_answers_mutation_caught(answers: str | None) -> None:
    assert _tree.check_recorded_answers(answers, RECORDED_EXPECTED)


# ---------- E8 · E9 비밀 가리기는 자르기 앞 · 부분 누출 · 원문 전용 텍스트 ----------

SECRET = secrets.token_urlsafe(48)  # 64자 — 스모크가 심는 비밀과 같은 꼴(실행마다 새 값 · 저장소에 값을 두지 않는다 — X33)


def secret_windows(value: str, width: int) -> list[str]:
    return [value[start : start + width] for start in range(len(value) - width + 1)]


def test_check_secret_leaks_finds_partial_windows() -> None:
    planted = {"SECRET_KEY": SECRET}
    assert len(SECRET) == 64
    assert _tree.SECRET_WINDOW == 16
    for leaked in (SECRET[:20], SECRET[32:], SECRET[:32], SECRET[10:26], SECRET):
        found = check_secret_leaks("log: " + leaked + " end\n", planted)
        assert len(found) == 1 and "SECRET_KEY" in found[0] and leaked not in found[0], leaked
    assert check_secret_leaks("log: " + SECRET[:15] + " end\n", planted) == []  # 16자 미만 조각은 우연 일치와 구별할 수 없다
    assert check_secret_leaks("anything", {"SHORT": "abc12"}) == []
    assert check_secret_leaks("x abc12 y", {"SHORT": "abc12"})  # 16자보다 짧은 값은 값 전체로 찾는다


def test_mask_secrets_masks_full_values_and_partial_windows() -> None:
    planted = {"SECRET_KEY": SECRET, "DATABASE_URL 비밀번호": "p" * 43}
    text = f"a {SECRET} b {SECRET[:20]} c {SECRET[40:]} d {'p' * 43} e {SECRET[:15]}"
    masked = _tree.mask_secrets(text, planted)
    assert masked.startswith("a <SECRET_KEY> b <SECRET_KEY> c <SECRET_KEY> d <DATABASE_URL 비밀번호> e ")
    assert not any(window in masked for window in secret_windows(SECRET, 16))
    assert _tree.mask_secrets("clean", planted) == "clean"


def smoke_log(planted: dict[str, str]) -> Any:
    return _tree.SmokeLog("web", planted)


def test_smoke_log_masks_before_tail_boundary() -> None:
    """경계 걸침 회귀(r1 B-2): 4000자 자르기가 비밀 가운데를 지나도 꼬리 조각이 남지 않는다 — 가리기가 자르기 앞이다."""
    planted = {"SECRET_KEY": SECRET}
    padding = _proc.TAIL_CHARS - 30  # 원문 길이 = 10 + 64 + padding → 자르기 시작점이 비밀 안(34자 뒤)에 온다
    leaky = "x" * 10 + SECRET + "y" * padding
    assert 10 < len(leaky) - _proc.TAIL_CHARS < 10 + len(SECRET)
    log = smoke_log(planted)
    log.record(proc_result(1, leaky, leaky), "docker run -d(web)")
    run_result = log.finish(leaky, [None])
    assert any("SECRET_KEY" in problem for problem in run_result.problems)  # 누출 판정은 원문으로
    assert not any(window in run_result.transcript for window in secret_windows(SECRET, 8))
    assert "<SECRET_KEY>" in run_result.transcript


def test_smoke_log_partial_leak_reported_and_masked() -> None:
    """부분 누출 회귀(r1 B-2): 값 앞 20자만 나와도 문제로 보고하고, 기록에는 그 조각도 가린다."""
    planted = {"KAFKA_PASSWORD": SECRET}
    log = smoke_log(planted)
    log.record(proc_result(1, "dsn fragment " + SECRET[:20] + "\n", ""), "outbox_purge(DB 없음)")
    run_result = log.finish("tail " + SECRET[44:] + "\n", [None])
    assert [problem for problem in run_result.problems if "KAFKA_PASSWORD" in problem]
    assert SECRET[:20] not in run_result.transcript and SECRET[44:] not in run_result.transcript


def test_smoke_log_raw_only_text_is_judged_but_not_printed() -> None:
    """E9: HTTP 탐침 본문은 누출 판정용 원문에만 넣는다(기록에 찍지 않는다)."""
    planted = {"SECRET_KEY": SECRET}
    log = smoke_log(planted)
    log.add_raw("<html>debug page " + SECRET + " and a long body marker-0001</html>")
    run_result = log.finish("", [None])
    assert [problem for problem in run_result.problems if "SECRET_KEY" in problem]
    assert "marker-0001" not in run_result.transcript and "<SECRET_KEY>" not in run_result.transcript


def test_check_container_logs() -> None:
    """E9: docker logs가 실패하거나 시간 초과면 로그 단언(쓰기 오류 · 누출)을 판정할 수 없다 — 문제 한 줄."""
    assert _tree.check_container_logs(proc_result(0, "log line\n", "")) == []
    for result in (proc_result(1, "", "Error response from daemon: configured logging driver does not support reading\n"), proc_result(None)):
        found = _tree.check_container_logs(result)
        assert len(found) == 1 and "docker logs 실패" in found[0] and "판정할 수 없다" in found[0]


def test_http_probe_script_returns_body_separately(tmp_path: Path) -> None:
    """E9: HTTP 탐침은 응답 본문(상한 1 MB)을 body 키로 따로 돌려준다 — 오류 응답(404)의 본문도."""
    server = ThreadingHTTPServer(("127.0.0.1", 0), _MetricsHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        base = f"http://127.0.0.1:{server.server_address[1]}"
        metrics = run_probe(HTTP_PROBE_SCRIPT, [f"{base}/metrics", "http_requests_total"], tmp_path)
        missing = run_probe(HTTP_PROBE_SCRIPT, [f"{base}/nope"], tmp_path)
    finally:
        server.shutdown()
        server.server_close()
    assert "other 2" in metrics["body"] and metrics["body"].startswith("# HELP http_requests_total")
    assert missing["status"] == 404 and missing["body"] == "missing"
    assert "body = response.read(1000000)" in HTTP_PROBE_SCRIPT


# ---------- E10 생성물 pytest의 env 상속 ----------

POD_PYTEST_REMOVED = (
    "PYTEST_ADDOPTS",
    "PYTEST_PLUGINS",
    "PYTHONOPTIMIZE",
    "PYTHONINSPECT",
    "PYTHONSTARTUP",
    "PYTHONPATH",
    # T072 ② r2 H9(B-1): pytest-django가 ini보다 앞에 읽는 설정 env — 셸 값이 시험 래퍼를 비켜 가지 않게
    "DJANGO_SETTINGS_MODULE",
    "DJANGO_CONFIGURATION",
)


def test_pod_pytest_env_removes_inherited_options(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    assert _proc.POD_PYTEST_ENV == dict.fromkeys(POD_PYTEST_REMOVED)
    for name in POD_PYTEST_REMOVED:
        monkeypatch.setenv(name, "-l" if name == "PYTEST_ADDOPTS" else "x")
    script = f"import os; print(sorted(name for name in {POD_PYTEST_REMOVED!r} if name in os.environ))"
    result = run([sys.executable, "-c", script], cwd=tmp_path, timeout=60, env=_proc.POD_PYTEST_ENV)
    assert result.ok, result.stderr
    assert result.stdout.strip() == "[]"


# ---------- E11 스모크 컨테이너 레이블 · 남은 컨테이너 쓸기 · rm -f -v ----------


def test_docker_run_argv_labels_harness_and_session() -> None:
    before = int(time.time())
    argv = docker_run_argv("docker", "jt-sample-pod:t065", "jt-smoke-web-x", detach=True)
    after = int(time.time())
    labels = [argv[index + 1] for index, item in enumerate(argv) if item == "--label"]
    assert labels[:2] == [f"jt.harness={_proc.SMOKE_HARNESS_LABEL}", f"jt.session={_proc.HARNESS_SESSION}"]
    # r3 F5: 셋째 레이블 = 만든 시각(유닉스 초) — 쓸기가 30분보다 오래된 다른 세션 컨테이너만 지운다
    key, _, created = labels[2].partition("=") if len(labels) == 3 else ("", "", "")
    assert key == "jt.created" and created.isascii() and created.isdigit() and before <= int(created) <= after, labels
    assert _proc.SMOKE_HARNESS_LABEL == "t072-smoke"
    assert len(_proc.HARNESS_SESSION) == 32 and all(char in "0123456789abcdef" for char in _proc.HARNESS_SESSION)
    assert max(index for index, item in enumerate(argv) if item == "--label") < argv.index("jt-sample-pod:t065")


def ps_row(container_id: str, name: str, session: str, created: str) -> str:
    """docker ps --format SMOKE_PS_FORMAT의 한 줄(r3 F5 — 탭으로 가른 4열: id · 이름 · jt.session · jt.created, 빈 레이블은 빈 칸)."""
    return "\t".join((container_id, name, session, created)) + "\n"


def test_stale_smoke_containers_takes_other_sessions_only() -> None:
    current = _proc.HARNESS_SESSION
    text = (
        ps_row("aaa111", "jt-smoke-web-0a1b2c3d", current, "")
        + ps_row("bbb222", "jt-smoke-relay-11111111", "f" * 32, "")
        + ps_row("ccc333", "jt-smoke-celery-22222222", "", "")
        + ps_row("ddd444", "someone-elses-container", "e" * 32, "")
        + "garbage\n"
    )
    assert _proc.stale_smoke_containers(text, current) == [("bbb222", "jt-smoke-relay-11111111"), ("ccc333", "jt-smoke-celery-22222222")]


FAKE_DOCKER_RM = """\
import os
import sys

with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "calls.log"), "a", encoding="utf-8") as handle:
    print("rm " + " ".join(sys.argv[1:]), file=handle)
"""

FAKE_DOCKER_CONTAINER = """\
import os
import sys

state = os.environ.get("FAKE_CONTAINER_STATE", "gone")
if state == "gone":
    print("Error: No such container: " + sys.argv[-1], file=sys.stderr)
    sys.exit(1)
print("running 0")
"""


# r3 F2(r2 A-2): ps — 인자를 ps-argv.json에 남기고 calls.log에 'ps' 한 줄 · FAKE_PS_EXIT가 0이 아니면 그 종료 코드로 실패 ·
# 아니면 ps.out(고정 목록)을 그대로 낸다(데몬의 --filter는 흉내 내지 않는다 — 하네스 쪽 인자와 행 판정을 본다)
FAKE_DOCKER_PS = """\
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "calls.log"), "a", encoding="utf-8") as handle:
    print("ps", file=handle)
with open(os.path.join(here, "ps-argv.json"), "w", encoding="utf-8") as handle:
    json.dump(sys.argv[1:], handle)
code = int(os.environ.get("FAKE_PS_EXIT", "0"))
if code:
    print("Cannot connect to the Docker daemon", file=sys.stderr)
    sys.exit(code)
with open(os.path.join(here, "ps.out"), encoding="utf-8") as handle:
    sys.stdout.write(handle.read())
"""


def fake_docker(tmp_path: Path) -> Path:
    """docker = sys.executable, cwd = 이 디렉터리 — [python, 'rm', …]가 가짜 스크립트 rm을 돈다(컨테이너를 띄우지 않는다)."""
    (tmp_path / "rm").write_text(FAKE_DOCKER_RM, encoding="utf-8")
    (tmp_path / "container").write_text(FAKE_DOCKER_CONTAINER, encoding="utf-8")
    (tmp_path / "ps").write_text(FAKE_DOCKER_PS, encoding="utf-8")
    return tmp_path


def test_remove_container_uses_rm_force_volumes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "gone")
    assert _proc.remove_container(sys.executable, "jt-smoke-web-0a1b2c3d", cwd=where) is None
    assert (where / "calls.log").read_text(encoding="utf-8").splitlines() == ["rm -f -v jt-smoke-web-0a1b2c3d"]


def test_remove_container_total_time_is_capped(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """E13: 남아 있는 컨테이너의 정리 확인은 총합 상한 안에서 끝난다(기본 REMOVE_TOTAL_SECONDS = 60)."""
    assert _proc.REMOVE_TOTAL_SECONDS == 60
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "running")
    started = time.monotonic()
    problem = _proc.remove_container(sys.executable, "jt-smoke-web-0a1b2c3d", cwd=where, total_seconds=3)
    assert problem is not None and "jt-smoke-web-0a1b2c3d" in problem
    assert time.monotonic() - started < 15


def test_cleanup_container_removes_again_after_run_timeout(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """E11: docker run이 시간 초과로 끝났으면 몇 초 뒤 rm -f와 확인을 한 번 더 한다(데몬이 늦게 만든 컨테이너)."""
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "gone")
    monkeypatch.setattr(_proc, "LATE_REMOVE_DELAY_SECONDS", 0.1)
    assert _proc.cleanup_container(sys.executable, "jt-smoke-web-0a1b2c3d", cwd=where, run_timed_out=False) == []
    assert _proc.cleanup_container(sys.executable, "jt-smoke-web-0a1b2c3d", cwd=where, run_timed_out=True) == []
    assert (where / "calls.log").read_text(encoding="utf-8").splitlines() == ["rm -f -v jt-smoke-web-0a1b2c3d"] * 3


# ---------- E12 Windows 시간 상한 — 시간 초과 때 프로세스 트리를 끝낸다 ----------

TREE_CHILD = """\
import subprocess
import sys
import time

grandchild = subprocess.Popen(
    [sys.executable, "-c", "import os, sys, time; open(sys.argv[1], 'w').write(str(os.getpid())); time.sleep(40)", sys.argv[1]],
    stdout=sys.stdout,
    stderr=sys.stderr,
)
print("child-started", flush=True)
time.sleep(40)
"""


def pid_alive(pid: int) -> bool:
    if os.name == "nt":
        # 바이트로 받아 푼다(T072 마지막 라운드 N14): tasklist는 로캘 코드 페이지(한국어 Windows = cp949)로 답하는데, text=True는
        # UTF-8 모드(PYTHONUTF8=1 · -X utf8)에서 그 출력을 UTF-8로 엄격하게 풀어 UnicodeDecodeError로 깬다. 찾는 것은 ASCII PID뿐이다.
        listed = subprocess.run(
            ["tasklist", "/FI", f"PID eq {pid}", "/NH", "/FO", "CSV"], capture_output=True, timeout=30, check=False
        )
        return f'"{pid}"' in listed.stdout.decode("ascii", errors="replace")
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    status = Path(f"/proc/{pid}/status")  # 거두지 않은 좀비(State: Z)는 끝난 것이다 — PID 1이 거두지 않는 환경 대비
    return not (status.is_file() and "\nState:\tZ" in status.read_text(encoding="utf-8", errors="replace"))


def test_run_kills_process_tree_on_timeout(tmp_path: Path) -> None:
    """손자 프로세스가 출력 파이프를 쥐어도 시간 상한 + 짧은 수거 상한 안에 끝나고, 손자도 끝난다(Windows taskkill /T ·
    POSIX killpg)."""
    pid_file = tmp_path / "grandchild.pid"
    result = run([sys.executable, "-c", TREE_CHILD, str(pid_file)], cwd=tmp_path, timeout=3)
    assert result.returncode is None
    assert result.seconds < 3 + _proc.KILL_COMMUNICATE_SECONDS + 5, result.seconds
    assert "child-started" in result.stdout
    assert "시간 초과" in result.stderr
    pid = int(pid_file.read_text(encoding="utf-8"))
    deadline = time.monotonic() + 10
    while pid_alive(pid) and time.monotonic() < deadline:
        time.sleep(0.2)
    assert not pid_alive(pid), f"손자 {pid}가 살아 있다"


# T072 마지막 라운드 N14(조각 ④ 빌더 걱정 4): pid_alive를 UTF-8 모드(PYTHONUTF8=1 · -X utf8) 자식에서 부른다 — 살아 있는 PID(자기
# 자신)와 끝난 PID(기다린 자식). 한국어 Windows의 tasklist는 로캘(cp949) 글로 답한다(끝난 PID = 「정보: … 없습니다」).
PID_ALIVE_UTF8_PROBE = """\
import os
import subprocess
import sys

from tests.test_check_helpers import pid_alive

child = subprocess.Popen([sys.executable, "-c", "pass"])
child.wait()
print(pid_alive(os.getpid()), pid_alive(child.pid))
"""


def test_pid_alive_reads_tasklist_output_in_utf8_mode() -> None:
    """pid_alive가 UTF-8 모드에서도 tasklist의 로캘 출력을 읽는다(T072 마지막 라운드 N14 — text=True로 읽으면 UTF-8 모드가 cp949
    출력을 UnicodeDecodeError로 깬다: 바이트로 받아 errors=replace로 푼다). POSIX는 os.kill 경로라 같은 기대가 그대로 참이다. 자식 env는
    허용 목록 + PYTHONUTF8=1(셸 env를 물려주지 않는다)."""
    result = run(
        [sys.executable, "-X", "utf8", "-c", PID_ALIVE_UTF8_PROBE],
        cwd=TEMPLATE_DIR,
        timeout=120,
        env=_proc.allowlist_env({"PYTHONUTF8": "1"}),
    )
    ok, tail, verdicts = result.ok, result.stderr[-1500:], result.stdout.split()
    assert ok, tail
    assert verdicts == ["True", "False"], verdicts


# ---------- E13 시간 예산 · 단계 기록 · 대기 상한 ----------


def test_run_uses_remaining_budget(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JT_HARNESS_BUDGET_SECONDS", "100")
    monkeypatch.setattr(_proc, "HARNESS_STARTED", time.monotonic() - 97)
    result = run([sys.executable, "-c", "import time; time.sleep(30)"], cwd=tmp_path, timeout=60)
    assert result.returncode is None and result.seconds < 15
    assert "예산" in result.stderr


def test_run_refuses_when_budget_exhausted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JT_HARNESS_BUDGET_SECONDS", "100")
    monkeypatch.setattr(_proc, "HARNESS_STARTED", time.monotonic() - 200)
    marker = tmp_path / "started.txt"
    result = run([sys.executable, "-c", f"open({str(marker)!r}, 'w').close()"], cwd=tmp_path, timeout=60)
    assert result.returncode is None and "예산" in result.stderr
    assert not marker.exists()
    cleanup = run([sys.executable, "-c", f"open({str(marker)!r}, 'w').close()"], cwd=tmp_path, timeout=60, use_budget=False)
    assert cleanup.ok and marker.exists()  # 정리 호출은 예산 밖이다(자기 상한)


def test_run_without_budget_env_keeps_timeout(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("JT_HARNESS_BUDGET_SECONDS", raising=False)
    monkeypatch.setattr(_proc, "HARNESS_STARTED", time.monotonic() - 10**6)
    assert _proc.budget_timeout(60) == 60
    assert run([sys.executable, "-c", "print('ok')"], cwd=tmp_path, timeout=60).ok


@pytest.mark.parametrize("raw", ["0", "-5", "abc", "1e3", "60s"], ids=["zero", "negative", "word", "exponent", "unit"])
def test_budget_env_must_be_positive_seconds(monkeypatch: pytest.MonkeyPatch, raw: str) -> None:
    monkeypatch.setenv("JT_HARNESS_BUDGET_SECONDS", raw)
    with pytest.raises(pytest.fail.Exception):
        _proc.budget_timeout(60)


def test_harness_stage_writes_ascii_lines_and_labels(tmp_path: Path) -> None:
    with _proc.harness_stage(tmp_path, "render") as label:
        assert "render" in label
    with pytest.raises(pytest.fail.Exception):
        with _proc.harness_stage(tmp_path, "uv-sync"):
            pytest.fail("stage failure", pytrace=False)
    with pytest.raises(KeyboardInterrupt):
        with _proc.harness_stage(tmp_path, "image-build"):
            raise KeyboardInterrupt
    _proc.stage_note(tmp_path, "sweep removed jt-smoke-web-0a1b2c3d")
    raw = (tmp_path / _proc.STAGE_LOG_NAME).read_bytes()
    assert raw.isascii() and b"\r" not in raw
    words = [line.split()[1:4] for line in raw.decode("ascii").splitlines()]
    assert words[0] == ["start", "render"] and words[1][:3] == ["end", "render", "ok"]
    assert words[2] == ["start", "uv-sync"] and words[3][:3] == ["end", "uv-sync", "fail"]
    assert words[4] == ["start", "image-build"] and words[5][:3] == ["end", "image-build", "interrupted"]
    assert words[6] == ["note", "sweep", "removed"]
    assert all(line.split()[0].endswith("Z") for line in raw.decode("ascii").splitlines())


def test_harness_stage_label_goes_into_failure_messages(tmp_path: Path) -> None:
    with pytest.raises(pytest.fail.Exception, match=r"\[단계 kubeconform\]"):
        with _proc.harness_stage(tmp_path, "kubeconform") as label:
            _proc.fail_with(proc_result(1, "", "boom"), f"{label} kubeconform 실패")


def test_wait_until_passes_remaining_time_to_each_call(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """E13: 대기는 남은 시간을 각 호출(docker exec · inspect)의 상한으로 넘긴다 — 총 시간이 대기 상한 + 한 번의 호출 하한
    안이다."""
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "running")
    seen: list[float] = []

    def ready(timeout: float) -> bool:
        seen.append(timeout)
        return False

    started = time.monotonic()
    problem = _proc.wait_until(
        sys.executable, "jt-smoke-web-0a1b2c3d", cwd=where, ready=ready, what="/healthz 200", wait_seconds=2, poll_seconds=0.2
    )
    elapsed = time.monotonic() - started
    assert problem is not None and "2 s" in problem
    assert seen and all(timeout <= 2 for timeout in seen) and seen == sorted(seen, reverse=True)
    assert elapsed < 2 + 2 * _proc.WAIT_CALL_FLOOR_SECONDS + 5


# ==================== T072 r3(리뷰 r2 반영 F2 · F5 · F6 — F3은 E3 절) ====================
# 남은 스모크 컨테이너 쓸기: 다른 세션이면서 30분보다 오래됐거나 jt.created가 없거나 읽을 수 없는 것만 지운다(F5) · 지우기는
# 목록의 id로만 · 현재 세션 · 이름 접두 없는 행은 건드리지 않는다(F2) · 이미지 빌드 앞 단계 기록(F6). 「지금」은 고정 값으로
# 넘긴다(now) — 경계가 시계에 흔들리지 않게.

NOW = 1_800_000_000
OTHER_SESSION = "f" * 32


def created_ago(seconds: int) -> str:
    """jt.created 값 — NOW보다 seconds초 앞(음수면 미래)."""
    return str(NOW - seconds)


def test_smoke_sweep_age_threshold_boundary() -> None:
    """나이 경계 골든 — 정확히 30분(1800 s)은 젊다(지우지 않고 알린다) · 1801 s는 오래됐다(지운다)."""
    assert _proc.SMOKE_STALE_AFTER_SECONDS == 30 * 60
    text = ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, created_ago(1800)) + ps_row(
        "bbb222", "jt-smoke-relay-22222222", OTHER_SESSION, created_ago(1801)
    )
    assert _proc.stale_smoke_containers(text, _proc.HARNESS_SESSION, now=NOW) == [("bbb222", "jt-smoke-relay-22222222")]
    assert _proc.young_smoke_containers(text, _proc.HARNESS_SESSION, now=NOW) == [("jt-smoke-web-11111111", 1800)]


SWEEP_ROW_CASES: list[tuple[str, str, list[tuple[str, str]], list[tuple[str, int]]]] = [
    # (사례 · ps 한 줄 · 지울 (id, 이름) · 지우지 않고 알릴 (이름, 나이 s))
    (
        "young-other-session-kept",
        ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, created_ago(60)),
        [],
        [("jt-smoke-web-11111111", 60)],
    ),
    (
        "past-threshold-removed",
        ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, created_ago(1801)),
        [("aaa111", "jt-smoke-web-11111111")],
        [],
    ),
    ("created-missing-removed", ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, ""), [("aaa111", "jt-smoke-web-11111111")], []),
    (
        "created-unreadable-removed",
        ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, "yesterday"),
        [("aaa111", "jt-smoke-web-11111111")],
        [],
    ),
    ("created-negative-removed", ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, "-5"), [("aaa111", "jt-smoke-web-11111111")], []),
    (
        "created-fraction-removed",
        ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, "1799999000.5"),
        [("aaa111", "jt-smoke-web-11111111")],
        [],
    ),
    (
        "created-future-kept",
        ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, created_ago(-120)),
        [],
        [("jt-smoke-web-11111111", -120)],
    ),
    (
        "empty-session-old-removed",
        ps_row("aaa111", "jt-smoke-web-11111111", "", created_ago(4000)),
        [("aaa111", "jt-smoke-web-11111111")],
        [],
    ),
    ("current-session-old-kept", ps_row("aaa111", "jt-smoke-web-11111111", _proc.HARNESS_SESSION, created_ago(10**6)), [], []),
    ("current-session-created-missing-kept", ps_row("aaa111", "jt-smoke-web-11111111", _proc.HARNESS_SESSION, ""), [], []),
    ("name-without-prefix-ignored", ps_row("aaa111", "someone-elses-container", OTHER_SESSION, created_ago(10**6)), [], []),
    ("id-not-hex-ignored", ps_row("-f", "jt-smoke-web-11111111", OTHER_SESSION, ""), [], []),
    ("extra-column-ignored", ps_row("aaa111", "jt-smoke-web-11111111", OTHER_SESSION, "")[:-1] + "\textra\n", [], []),
    ("space-separated-ignored", f"aaa111 jt-smoke-web-11111111 {OTHER_SESSION}\n", [], []),
]


@pytest.mark.parametrize(
    ("row", "stale", "young"),
    [(row, stale, young) for _, row, stale, young in SWEEP_ROW_CASES],
    ids=[case for case, _, _, _ in SWEEP_ROW_CASES],
)
def test_smoke_sweep_row_verdicts(row: str, stale: list[tuple[str, str]], young: list[tuple[str, int]]) -> None:
    """변이 — 젊은 다른 세션 → 안 지움 + 알림 · 문턱 넘음 → 지움 · jt.created 없음 · 읽을 수 없음 → 지움 · 현재 세션 → 안 지움 ·
    접두 없는 이름 · 16진이 아닌 id · 열 수가 다른 줄 → 건드리지 않음."""
    assert _proc.stale_smoke_containers(row, _proc.HARNESS_SESSION, now=NOW) == stale
    assert _proc.young_smoke_containers(row, _proc.HARNESS_SESSION, now=NOW) == young


def test_smoke_ps_format_is_tab_separated_with_both_labels() -> None:
    assert _proc.SMOKE_PS_FORMAT.split("\t") == ["{{.ID}}", "{{.Names}}", '{{.Label "jt.session"}}', '{{.Label "jt.created"}}']


def ps_calls(where: Path) -> tuple[list[str], list[str]]:
    """가짜 docker의 (ps 인자, rm 호출 줄)."""
    argv = json.loads((where / "ps-argv.json").read_text(encoding="utf-8")) if (where / "ps-argv.json").exists() else []
    calls = (where / "calls.log").read_text(encoding="utf-8").splitlines() if (where / "calls.log").exists() else []
    return argv, [line for line in calls if line.startswith("rm ")]


def test_sweep_removes_only_stale_rows_by_id(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """F2: ps는 하네스 레이블로 거른다(--filter label=jt.harness=t072-smoke) · rm은 지울 행의 id에만 간다 · 현재 세션 행 ·
    접두 없는 이름 · 젊은 다른 세션 행에는 가지 않는다 · 젊은 행은 문제 한 줄(F5)."""
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "gone")
    monkeypatch.delenv("FAKE_PS_EXIT", raising=False)
    (where / "ps.out").write_text(
        ps_row("aaa111", "jt-smoke-web-11111111", _proc.HARNESS_SESSION, created_ago(10**6))
        + ps_row("bbb222", "jt-smoke-relay-22222222", OTHER_SESSION, created_ago(1801))
        + ps_row("ccc333", "jt-smoke-celery-33333333", OTHER_SESSION, "")
        + ps_row("ddd444", "jt-smoke-startup-44444444", OTHER_SESSION, created_ago(60))
        + ps_row("eee555", "someone-elses-container", OTHER_SESSION, created_ago(10**6))
        + ps_row("fff666", "jt-smoke-purge-66666666", "", "not-a-time"),
        encoding="utf-8",
    )
    removed, problems = _proc.sweep_stale_smoke_containers(sys.executable, cwd=where, now=NOW)
    argv, rm_calls = ps_calls(where)
    assert argv[0] == "-a" and argv[argv.index("--filter") + 1] == "label=jt.harness=t072-smoke", argv
    assert argv[argv.index("--format") + 1] == _proc.SMOKE_PS_FORMAT  # 탭 · 따옴표가 명령줄을 그대로 지나간다
    assert rm_calls == ["rm -f -v bbb222", "rm -f -v ccc333", "rm -f -v fff666"]
    assert removed == ["jt-smoke-relay-22222222", "jt-smoke-celery-33333333", "jt-smoke-purge-66666666"]
    assert len(problems) == 1 and problems[0].startswith("다른 하네스 세션이 실행 중일 수 있다 — jt-smoke-startup-44444444"), problems


def test_sweep_ps_failure_removes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """F2: docker ps가 실패하면 아무것도 지우지 않고 (빈 목록, 문제 한 줄)."""
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_PS_EXIT", "1")
    (where / "ps.out").write_text(ps_row("bbb222", "jt-smoke-relay-22222222", OTHER_SESSION, ""), encoding="utf-8")
    removed, problems = _proc.sweep_stale_smoke_containers(sys.executable, cwd=where, now=NOW)
    assert removed == [] and len(problems) == 1 and "docker ps" in problems[0] and "exit 1" in problems[0], problems
    assert ps_calls(where)[1] == []


def test_smoke_sweep_stage_records_stage_and_result(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """F6: 이미지 빌드 앞 쓸기(conftest image가 부른다) — 단계 smoke-sweep의 시작 · 끝과 지운 이름 · 문제 수를 단계 기록에
    남기고 SmokeSweep(지운 이름 · 문제 줄)을 돌려준다(image_smoke가 config.stash로 받아 싣는다)."""
    where = fake_docker(tmp_path)
    monkeypatch.setenv("FAKE_CONTAINER_STATE", "gone")
    monkeypatch.delenv("FAKE_PS_EXIT", raising=False)
    now = int(time.time())
    (where / "ps.out").write_text(
        ps_row("bbb222", "jt-smoke-relay-22222222", OTHER_SESSION, str(now - 4000))
        + ps_row("ddd444", "jt-smoke-web-44444444", OTHER_SESSION, str(now - 10)),
        encoding="utf-8",
    )
    sweep = _proc.smoke_sweep_stage(sys.executable, where)
    assert isinstance(sweep, _proc.SmokeSweep)
    assert sweep.removed == ("jt-smoke-relay-22222222",)
    assert len(sweep.problems) == 1 and "jt-smoke-web-44444444" in sweep.problems[0]
    raw = (where / _proc.STAGE_LOG_NAME).read_bytes()
    assert raw.isascii()
    words = [line.split()[1:] for line in raw.decode("ascii").splitlines()]
    assert words[0] == ["start", "smoke-sweep"] and words[1][:3] == ["end", "smoke-sweep", "ok"]
    assert words[2] == ["note", "smoke-sweep", "removed", "jt-smoke-relay-22222222"]
    assert words[3] == ["note", "smoke-sweep", "problems=1"]


# ---------- T072 조각 ③ 지시 5 — 이미지 최상위 허용 목록 · 빌드 감시 파일 · RUN uv sync 플래그 ----------
# dockerignore가 빠지거나 거부 목록으로 돌아가도 gen-33 · 34의 다른 단언은 초록일 수 있다(실측 ③ · ③ r2): Windows는 호스트 .venv가
# 이미지 .venv에 합쳐진 채 유지되고(두 번째 uv sync가 venv를 다시 만들지 않는다) web이 뜬다 · Linux는 uv가 「non-existent Python
# interpreter」로 합쳐진 venv를 지우고 다시 만든다 — 그래서 Linux에서는 .venv 감시 파일만으로는 공허하고, 생성 dockerignore 정적 검사
# (_tree.check_dockerignore_text — 파일 끝 ③ r2 절)가 플랫폼과 무관하게 막는다. 이미지 탐침은 /src/apps/<pod> 최상위 항목(허용 목록)과
# 빌드 감시 파일(.venv/jt-harness-sentinel)을 싣고, image 픽스처가 빌드 직전 생성 pod에 감시 파일(.env* · *.pem · *.key · *.crt · 최상위
# jt-harness.local · .venv 안)을 심었다가 빌드가 끝나면 지운다(conftest.py build_with_sentinels — 심은 목록은 gen-33이 대조한다 · ③ r2
# M2(b)). Dockerfile 정적 검사는 uv sync를 부르는 모든 RUN에 --locked · --no-dev · --no-editable을 요구한다(③ r2 M3).

IMAGE_TOP_LEVEL = [".venv", "manage.py", "pyproject.toml", "sample_pod", "uv.lock"]
# 빌드 감시 파일 이름(지시 5 문면) — _proc.IMAGE_VENV_SENTINEL과 같아야 한다
VENV_SENTINEL_NAME = "jt-harness-sentinel"


def test_image_pod_entries_constant_matches_design() -> None:
    assert frozenset(IMAGE_TOP_LEVEL) == _tree.IMAGE_POD_ENTRIES
    assert sorted(IMAGE_TOP_LEVEL) == GOLDEN_IMAGE_PROBE["pod_entries"]


def test_check_image_probe_top_level_order_free() -> None:
    assert check_image_probe(image_probe(pod_entries=list(reversed(IMAGE_TOP_LEVEL)))) == []


@pytest.mark.parametrize(
    ("facts", "word"),
    [
        (image_probe(pod_entries=[name for name in IMAGE_TOP_LEVEL if name != "uv.lock"]), "uv.lock"),
        (image_probe(pod_entries=[name for name in IMAGE_TOP_LEVEL if name != "sample_pod"]), "sample_pod"),
        (image_probe(pod_entries=[name for name in IMAGE_TOP_LEVEL if name != ".venv"]), ".venv"),
        (image_probe(pod_entries=[*IMAGE_TOP_LEVEL, "tests"]), "tests"),
        (image_probe(pod_entries=[*IMAGE_TOP_LEVEL, "README.md", "env.example"]), "README.md"),
        (image_probe(pod_entries=[*IMAGE_TOP_LEVEL, ".env.jt-harness"]), ".env.jt-harness"),
        (image_probe(pod_entries=[*IMAGE_TOP_LEVEL, "deploy", "compose", "compose.dev.yml"]), "compose.dev.yml"),
        (image_probe(pod_entries=None), "최상위"),
        (image_probe(pod_entries=[".venv", 7]), "최상위"),
        (image_probe(pod_entries="sample_pod"), "최상위"),
        (image_probe(venv_sentinel=True), VENV_SENTINEL_NAME),
        (image_probe(venv_sentinel=None), VENV_SENTINEL_NAME),
        (image_probe(venv_sentinel="false"), VENV_SENTINEL_NAME),
    ],
    ids=[
        "entry-missing-lock",
        "entry-missing-package",
        "entry-missing-venv",
        "entry-extra-tests",
        "entry-extra-docs",
        "entry-extra-harness-dotenv",
        "entry-extra-compose",
        "entries-unreadable",
        "entries-not-strings",
        "entries-not-list",
        "venv-sentinel-present",
        "venv-sentinel-unreadable",
        "venv-sentinel-not-bool",
    ],
)
def test_check_image_probe_top_level_and_venv_sentinel_caught(facts: dict[str, Any], word: str) -> None:
    found = check_image_probe(facts)
    assert found and any(word in item for item in found), found


def test_image_probe_script_reports_top_level_and_venv_sentinel(tmp_path: Path) -> None:
    pod = tmp_path / "pod"
    for relative in ("manage.py", "uv.lock", "sample_pod/__init__.py", ".venv/pyvenv.cfg", "tests/test_x.py"):
        write_empty(pod, relative)
    clean = run_probe(IMAGE_PROBE_SCRIPT, [str(pod)], tmp_path)
    assert clean["pod_entries"] == [".venv", "manage.py", "sample_pod", "tests", "uv.lock"]  # 정렬 · 이름만
    assert clean["venv_sentinel"] is False
    write_empty(pod, f".venv/{_proc.IMAGE_VENV_SENTINEL}")
    planted = run_probe(IMAGE_PROBE_SCRIPT, [str(pod)], tmp_path)
    assert planted["venv_sentinel"] is True
    absent = run_probe(IMAGE_PROBE_SCRIPT, [str(tmp_path / "absent")], tmp_path)
    assert absent["pod_entries"] is None and absent["venv_sentinel"] is False


UV_SYNC_FIRST = "RUN uv sync --locked --no-install-project --no-dev --no-editable"
UV_SYNC_SECOND = "RUN uv sync --locked --no-dev --no-editable"


@pytest.mark.parametrize(
    "text",
    [
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, 'RUN ["uv", "sync", "--locked", "--no-dev", "--no-editable"]'),
        replace_once(
            GOLDEN_DOCKERFILE,
            UV_SYNC_SECOND,
            "RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev --no-editable",
        ),
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, "RUN uv sync --locked \\\n    --no-dev --no-editable"),
        replace_once(
            GOLDEN_DOCKERFILE, UV_SYNC_SECOND, "RUN uv sync --locked --no-dev --no-editable && python -m compileall -q sample_pod"
        ),
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, 'RUN ["/bin/sh", "-c", "uv sync --locked --no-dev --no-editable"]'),
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, "RUN /usr/local/bin/uv sync --no-dev --locked --no-editable"),
        # T072 ③ r2 M3: 따옴표 셸 꼴(셸 꼴 RUN의 sh -c "…" · bash -lc '…' · 옵션 인자가 낀 -c)
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, 'RUN sh -c "uv sync --locked --no-dev --no-editable"'),
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, "RUN bash -lc 'uv sync --locked --no-dev --no-editable'"),
        replace_once(GOLDEN_DOCKERFILE, UV_SYNC_SECOND, "RUN bash -o pipefail -c 'echo go && uv sync --locked --no-dev --no-editable'"),
    ],
    ids=[
        "exec-form",
        "cache-mount",
        "continuation",
        "chained-other-command",
        "sh-c-exec-form",
        "absolute-uv-path",
        "sh-c-quoted",
        "bash-lc-quoted",
        "bash-o-pipefail-c-quoted",
    ],
)
def test_check_dockerfile_text_uv_sync_spellings_accepted(text: str) -> None:
    assert check_dockerfile_text(text) == []


UV_SYNC_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("first-without-locked", swap(UV_SYNC_FIRST, "RUN uv sync --no-install-project --no-dev --no-editable")),
    ("second-without-locked", swap(UV_SYNC_SECOND, "RUN uv sync --no-dev --no-editable")),
    ("first-without-no-editable", swap(UV_SYNC_FIRST, "RUN uv sync --locked --no-install-project --no-dev")),
    ("second-without-no-editable", swap(UV_SYNC_SECOND, "RUN uv sync --locked --no-dev")),
    ("frozen-instead-of-locked", swap(UV_SYNC_SECOND, "RUN uv sync --frozen --no-dev --no-editable")),
    ("exec-form-without-locked", swap(UV_SYNC_SECOND, 'RUN ["uv", "sync", "--no-dev", "--no-editable"]')),
    ("sh-c-without-no-editable", swap(UV_SYNC_SECOND, 'RUN ["/bin/sh", "-c", "uv sync --locked --no-dev"]')),
    ("flag-in-other-segment", swap(UV_SYNC_SECOND, "RUN echo --locked && uv sync --no-dev --no-editable")),
    ("chained-second-sync-without-flags", swap(UV_SYNC_SECOND, "RUN uv sync --locked --no-dev --no-editable && uv sync --no-dev")),
    ("continuation-without-locked", swap(UV_SYNC_SECOND, "RUN uv sync \\\n    --no-dev --no-editable")),
    # T072 ③ r2 M3: --no-dev(계약 Dockerfile 행 · D18 — 없으면 pytest · testcontainers가 공개 이미지에 들어간다) · 따옴표 셸 꼴
    ("first-without-no-dev", swap(UV_SYNC_FIRST, "RUN uv sync --locked --no-install-project --no-editable")),
    ("second-without-no-dev", swap(UV_SYNC_SECOND, "RUN uv sync --locked --no-editable")),
    ("sh-c-quoted-without-no-dev", swap(UV_SYNC_SECOND, 'RUN sh -c "uv sync --locked --no-editable"')),
    ("bash-lc-quoted-without-locked", swap(UV_SYNC_SECOND, "RUN bash -lc 'uv sync --no-dev --no-editable'")),
    ("bin-sh-c-quoted-chained-without-no-editable", swap(UV_SYNC_SECOND, "RUN /bin/sh -c 'echo go && uv sync --locked --no-dev'")),
]


@pytest.mark.parametrize(("name", "mutate"), UV_SYNC_MUTATIONS, ids=[name for name, _ in UV_SYNC_MUTATIONS])
def test_check_dockerfile_text_uv_sync_flags_caught(name: str, mutate: Callable[[str], str]) -> None:
    found = check_dockerfile_text(mutate(GOLDEN_DOCKERFILE))
    assert found and all("uv sync" in item for item in found), (name, found)


def fake_build_result(returncode: int | None = 0) -> _proc.ProcResult:
    return _proc.ProcResult(("docker", "buildx", "build"), ".", returncode, "", "", 0.0)


def make_sentinel_pod(root: Path, *, venv: bool) -> Path:
    pod = root / "apps" / "sample-pod"
    write_empty(pod, "sample_pod/__init__.py")
    if venv:
        write_empty(pod, ".venv/pyvenv.cfg")
    return pod


def sentinel_paths(pod: Path) -> list[Path]:
    return [pod / relative for relative in (*conftest.BUILD_SENTINEL_FILES, conftest.VENV_SENTINEL)]


def test_build_sentinel_names_match_probe_and_check() -> None:
    """심는 감시 파일은 탐침 · 판정이 잡는 이름이다 — 이름이 비밀 후보(image_sensitive_name — 소문자 형의 .env* · *.pem · *.key · *.crt ·
    … · ③ r2 M1이 .crt · .p12 · .pfx를 · 마지막 라운드 N6이 대소문자 무관과 비밀 이름 꼴을 더했다)이거나, 최상위 파일이면 허용 목록 밖이다
    (.env.jt-harness · jt-harness.local — jt-harness.local은 어떤 재제외 꼴에도 맞지 않아 dockerignore가 pod 디렉터리 전체를 다시 넣는 거부
    목록으로 돌아가면 이미지 최상위에 나타난다 · ③ r2 M1) · .venv/<IMAGE_VENV_SENTINEL>(venv_sentinel). 패키지 안 감시 파일(sample_pod/
    .env.jt-harness · jt-harness.crt · JT-HARNESS-CASE.PEM · JT-HARNESS-NAME.ENV)은 패키지 디렉터리를 다시 넣은 뒤의 재제외(**/.[eE][nN][vV]* ·
    **/*.[cC][rR][tT] · 대소문자 무관 **/*.[pP][eE][mM] · 마감 라운드 Z3의 이름 꼴 **/*.[eE][nN][vV])가 공허하지 않게 한다 — 대문자 감시 파일의
    이름은 소문자 감시 파일과 대소문자만 다르지 않다(NTFS에서 같은 파일이 된다)."""
    assert conftest.BUILD_SENTINEL_FILES == (
        ".env.jt-harness",
        "sample_pod/jt-harness.pem",
        "sample_pod/jt-harness.key",
        "jt-harness.local",
        "sample_pod/.env.jt-harness",
        "sample_pod/jt-harness.crt",
        "sample_pod/JT-HARNESS-CASE.PEM",
        "sample_pod/JT-HARNESS-NAME.ENV",
    )
    lowered = [relative.lower() for relative in conftest.BUILD_SENTINEL_FILES]
    assert len(set(lowered)) == len(lowered), "대소문자만 다른 감시 파일이 있다(대소문자를 가리지 않는 파일 시스템에서 한 파일이 된다)"
    assert any(relative != relative.lower() for relative in conftest.BUILD_SENTINEL_FILES), "대문자 감시 파일이 없다(N6)"
    assert VENV_SENTINEL_NAME == _proc.IMAGE_VENV_SENTINEL
    assert f".venv/{_proc.IMAGE_VENV_SENTINEL}" == conftest.VENV_SENTINEL
    for relative in conftest.BUILD_SENTINEL_FILES:
        parts = relative.split("/")
        name = parts[-1]
        sensitive = _proc.image_sensitive_name(name)
        outside_top_level = len(parts) == 1 and name not in _tree.IMAGE_POD_ENTRIES
        assert sensitive or outside_top_level, relative
    assert not any(fnmatch.fnmatch("jt-harness.local", pattern.removeprefix("**/")) for pattern in _tree.DOCKERIGNORE_REEXCLUDE)
    assert ".env.jt-harness" not in _tree.IMAGE_POD_ENTRIES
    assert _proc.IMAGE_VENV_SENTINEL in IMAGE_PROBE_SCRIPT


def test_build_sentinels_planted_then_removed_keeping_existing_venv(tmp_path: Path) -> None:
    pod = make_sentinel_pod(tmp_path, venv=True)
    seen: list[bool] = []

    def build() -> _proc.ProcResult:
        seen.extend(path.is_file() and path.stat().st_size == 0 for path in sentinel_paths(pod))
        return fake_build_result()

    result = conftest.build_with_sentinels(pod, build)
    assert result.ok and seen == [True] * len(sentinel_paths(pod))  # 감시 파일 전부(③ r2 M1 · N6 · 마감 라운드 Z3 — 8 + .venv 안 1)
    assert not any(os.path.lexists(path) for path in sentinel_paths(pod))
    assert (pod / ".venv" / "pyvenv.cfg").is_file()  # 원래 있던 .venv는 그대로 — 감시 파일만 지운다


def test_build_sentinels_created_venv_removed_whole(tmp_path: Path) -> None:
    pod = make_sentinel_pod(tmp_path, venv=False)

    def build() -> _proc.ProcResult:
        assert (pod / conftest.VENV_SENTINEL).is_file()
        return fake_build_result()

    conftest.build_with_sentinels(pod, build)
    assert not (pod / ".venv").exists()  # 심기가 만든 .venv는 디렉터리째 지운다


@pytest.mark.parametrize("returncode", [1, None], ids=["build-failed", "build-timed-out"])
def test_build_sentinels_removed_after_failed_build(tmp_path: Path, returncode: int | None) -> None:
    pod = make_sentinel_pod(tmp_path, venv=False)
    result = conftest.build_with_sentinels(pod, lambda: fake_build_result(returncode))
    assert result.returncode == returncode  # 빌드 판정은 호출자 몫(image 픽스처 fail_with)
    assert not any(os.path.lexists(path) for path in sentinel_paths(pod))
    assert not (pod / ".venv").exists()


def test_build_sentinels_removed_when_build_raises(tmp_path: Path) -> None:
    pod = make_sentinel_pod(tmp_path, venv=True)

    def build() -> _proc.ProcResult:
        raise KeyboardInterrupt

    with pytest.raises(KeyboardInterrupt):
        conftest.build_with_sentinels(pod, build)
    assert not any(os.path.lexists(path) for path in sentinel_paths(pod))


def test_build_sentinels_leftover_fails(tmp_path: Path) -> None:
    pod = make_sentinel_pod(tmp_path, venv=True)

    def build() -> _proc.ProcResult:
        planted = pod / ".env.jt-harness"
        planted.unlink()
        write_empty(planted, "inside")  # 감시 파일 자리에 비지 않은 디렉터리 — 지우기(unlink)가 실패한다
        return fake_build_result()

    with pytest.raises(pytest.fail.Exception, match=r"\.env\.jt-harness"):
        conftest.build_with_sentinels(pod, build)


def test_build_sentinels_planting_failure_cleans_up(tmp_path: Path) -> None:
    pod = tmp_path / "apps" / "sample-pod"
    pod.mkdir(parents=True)  # sample_pod/ 없음 — sample_pod/jt-harness.pem을 심지 못한다

    def build() -> _proc.ProcResult:
        pytest.fail("심기가 실패했는데 빌드를 불렀다")

    with pytest.raises(pytest.fail.Exception, match=r"jt-harness\.pem"):
        conftest.build_with_sentinels(pod, build)
    assert not (pod / ".env.jt-harness").exists() and not (pod / ".venv").exists()


# ==================== T072 조각 ③ r2(리뷰 r1 반영 M1–M11) ====================
# 새 이름은 모듈 속성(_proc.X · _tree.X · _render.X · conftest.X)으로 부른다 — 하나가 빠져도 그 시험만 실패한다.

# ---------- M1 · M2(a) 생성 Dockerfile.dockerignore 정적 검사(D18 · X27) ----------
# 정본 꼴(sample-pod로 렌더): 첫 패턴 '*' → pod 안까지 허용 목록 '!' 여섯(그 순서) → 재제외 열여섯(마지막 라운드 N6 — 대소문자 무관 꼴 ·
# 비밀 이름 꼴 포함). 판정은 Docker(moby patternmatcher
# ignorefile)와 같은 규칙으로 읽는다 — 0열 '#'만 주석 · 앞뒤 공백 다듬기 · '!' 뒤 공백 · 경로 정리 · 앞 '/' 떼기 · 첫 줄 BOM.

DOCKERIGNORE_ALLOW_LINES = [
    "!apps/sample-pod/sample_pod",
    "!apps/sample-pod/manage.py",
    "!apps/sample-pod/pyproject.toml",
    "!apps/sample-pod/uv.lock",
    "!packages/django-common/pyproject.toml",
    "!packages/django-common/src",
]
# T072 마지막 라운드 N6(③ r2 리뷰 B-1): 접미 다섯과 .env*는 대소문자 무관 꼴(키 = 기존 시험 ID 그대로 · 값만 바뀐다) + 흔한 비밀 이름 꼴 다섯.
# T072 마감 라운드 Z3(마지막 리뷰 B-1 — ID_RSA · LOCAL.ENV · .NETRC가 이미지에 실렸다): 이름 꼴 다섯도 대소문자 무관 꼴(키 그대로 · 값만 바뀐다)
DOCKERIGNORE_REEXCLUDE_LINES = {
    "pycache": "**/__pycache__",
    "pyc": "**/*.py[co]",
    "pytest-cache": "**/.pytest_cache",
    "venv": "**/.venv",
    "dotenv": "**/.[eE][nN][vV]*",
    "env-suffix": "**/*.[eE][nN][vV]",
    "pem": "**/*.[pP][eE][mM]",
    "key": "**/*.[kK][eE][yY]",
    "crt": "**/*.[cC][rR][tT]",
    "p12": "**/*.[pP]12",
    "pfx": "**/*.[pP][fF][xX]",
    "netrc": "**/.[nN][eE][tT][rR][cC]",
    "id-rsa": "**/[iI][dD]_[rR][sS][aA]*",
    "id-ed25519": "**/[iI][dD]_[eE][dD]25519*",
    "id-ecdsa": "**/[iI][dD]_[eE][cC][dD][sS][aA]*",
    "git": "**/.git*",
}
GOLDEN_DOCKERIGNORE = "\n".join(
    [
        "# sample-pod 이미지 빌드 컨텍스트 거르기 — 허용 목록(이 줄은 주석)",
        "*",
        *DOCKERIGNORE_ALLOW_LINES,
        *DOCKERIGNORE_REEXCLUDE_LINES.values(),
        "",
    ]
)
# 조각 ③ 끝의 꼴 — pod 디렉터리 전체를 다시 넣는 거부 목록(③ 리뷰 B-1: 작업 트리의 IDE 설정 · *.env · 키가 이미지에 실렸다)
OLD_DOCKERIGNORE = "\n".join(
    [
        "*",
        "!apps/sample-pod",
        "!packages/django-common/pyproject.toml",
        "!packages/django-common/src",
        "**/.venv",
        "**/__pycache__",
        "**/*.py[co]",
        "**/.pytest_cache",
        "apps/sample-pod/tests",
        "apps/sample-pod/deploy",
        "apps/sample-pod/compose.dev.yml",
        "apps/sample-pod/compose/",
        "apps/sample-pod/env.example",
        "apps/sample-pod/README.md",
        "apps/sample-pod/Dockerfile*",
        "apps/sample-pod/.copier-answers.yml",
        "**/.env*",
        "**/*.pem",
        "**/*.key",
        "**/.git*",
        "",
    ]
)


def drop_line(text: str, line: str) -> str:
    lines = text.split("\n")
    if lines.count(line) != 1:
        raise LookupError(f"골든에 {line!r} 줄이 정확히 한 번 있지 않다")
    lines.remove(line)
    return "\n".join(lines)


def insert_after(anchor: str, new: str) -> Callable[[str], str]:
    def mutate(text: str) -> str:
        lines = text.split("\n")
        if lines.count(anchor) != 1:
            raise LookupError(f"골든에 {anchor!r} 줄이 정확히 한 번 있지 않다")
        lines.insert(lines.index(anchor) + 1, new)
        return "\n".join(lines)

    return mutate


def move_after(line: str, anchor: str) -> Callable[[str], str]:
    return lambda text: insert_after(anchor, line)(drop_line(text, line))


def test_dockerignore_constants_match_design() -> None:
    """허용 목록 · 재제외 상수 = 설계 D18 〔③ r2 M1〕 문면(순서 포함)."""
    assert list(_tree.DOCKERIGNORE_ALLOW) == [line.removeprefix("!") for line in DOCKERIGNORE_ALLOW_LINES]
    assert list(_tree.DOCKERIGNORE_REEXCLUDE) == list(DOCKERIGNORE_REEXCLUDE_LINES.values())


def test_check_dockerignore_text_golden() -> None:
    assert _tree.check_dockerignore_text(GOLDEN_DOCKERIGNORE) == []


DOCKERIGNORE_SPELLINGS: list[tuple[str, Callable[[str], str]]] = [
    ("comments-and-blank-lines", lambda t: t.replace("\n!", "\n\n# 허용 목록\n!", 1).replace("**/.git*", "# 끝\n\n**/.git*")),
    ("leading-slash", swap("!apps/sample-pod/manage.py", "!/apps/sample-pod/manage.py")),
    ("trailing-slash-dir", swap("!apps/sample-pod/sample_pod\n", "!apps/sample-pod/sample_pod/\n")),
    ("space-after-bang", swap("!apps/sample-pod/uv.lock", "! apps/sample-pod/uv.lock")),
    ("dot-segment", swap("!packages/django-common/src", "!packages/django-common/./src")),
    ("surrounding-spaces", swap("**/*.[pP][eE][mM]", "   **/*.[pP][eE][mM]   ")),
    ("crlf", lambda t: t.replace("\n", "\r\n")),
    ("utf8-bom", lambda t: chr(0xFEFF) + t),
    ("extra-exclusion", lambda t: t + "**/*.log\n"),
]


@pytest.mark.parametrize(("name", "mutate"), DOCKERIGNORE_SPELLINGS, ids=[name for name, _ in DOCKERIGNORE_SPELLINGS])
def test_check_dockerignore_text_equivalent_spellings_accepted(name: str, mutate: Callable[[str], str]) -> None:
    assert _tree.check_dockerignore_text(mutate(GOLDEN_DOCKERIGNORE)) == [], name


@pytest.mark.parametrize("line", list(DOCKERIGNORE_REEXCLUDE_LINES.values()), ids=list(DOCKERIGNORE_REEXCLUDE_LINES))
def test_check_dockerignore_text_reexclusion_removed_caught(line: str) -> None:
    """재제외 줄 하나를 지우면 그 줄을 이름으로 단 위반 하나(③ r2 M2(a) — 감시 파일 · 플랫폼 · uv 동작과 무관하게 잡는다)."""
    found = _tree.check_dockerignore_text(drop_line(GOLDEN_DOCKERIGNORE, line))
    assert len(found) == 1 and line in found[0], found


DOCKERIGNORE_MUTATIONS: list[tuple[str, Callable[[str], str]]] = [
    ("star-removed", lambda t: drop_line(t, "*")),
    ("star-after-allow", move_after("*", "!apps/sample-pod/sample_pod")),
    ("old-deny-list-form", lambda _t: OLD_DOCKERIGNORE),
    ("allow-whole-pod-dir", swap("!apps/sample-pod/sample_pod\n", "!apps/sample-pod\n")),
    ("allow-extra-pod-dir", insert_after("!packages/django-common/src", "!apps/sample-pod")),
    ("allow-extra-tests", insert_after("!packages/django-common/src", "!apps/sample-pod/tests")),
    ("allow-order-swapped", move_after("!apps/sample-pod/sample_pod", "!apps/sample-pod/manage.py")),
    ("allow-uv-lock-removed", lambda t: drop_line(t, "!apps/sample-pod/uv.lock")),
    ("reexclude-before-allow", move_after("**/.[eE][nN][vV]*", "*")),
    ("allow-after-reexclude", lambda t: t + "!apps/sample-pod/sample_pod/settings.py\n"),
    ("indented-hash-is-a-pattern", lambda t: "  # 0열이 아닌 '#'는 Docker에서 패턴이다\n" + t),
    ("empty", lambda _t: ""),
    ("comments-only", lambda _t: "# 주석뿐\n"),
    # T072 마지막 라운드 N6: 대소문자를 가리는 꼴로 되돌림(CASE.PEM · .Env.prod가 이미지에 실린다 — ③ r2 리뷰 B-1)
    ("pem-case-sensitive", swap("**/*.[pP][eE][mM]", "**/*.pem")),
    ("dotenv-case-sensitive", swap("**/.[eE][nN][vV]*", "**/.env*")),
    # T072 마감 라운드 Z3: 이름 꼴 다섯을 대소문자를 가리는 꼴로 되돌림(LOCAL.ENV · .NETRC · ID_RSA · ID_ED25519 · Id_Ecdsa가 이미지에 실린다 —
    # 마지막 리뷰 B-1)
    ("env-suffix-case-sensitive", swap("**/*.[eE][nN][vV]", "**/*.env")),
    ("netrc-case-sensitive", swap("**/.[nN][eE][tT][rR][cC]", "**/.netrc")),
    ("id-rsa-case-sensitive", swap("**/[iI][dD]_[rR][sS][aA]*", "**/id_rsa*")),
    ("id-ed25519-case-sensitive", swap("**/[iI][dD]_[eE][dD]25519*", "**/id_ed25519*")),
    ("id-ecdsa-case-sensitive", swap("**/[iI][dD]_[eE][cC][dD][sS][aA]*", "**/id_ecdsa*")),
]


@pytest.mark.parametrize(("name", "mutate"), DOCKERIGNORE_MUTATIONS, ids=[name for name, _ in DOCKERIGNORE_MUTATIONS])
def test_check_dockerignore_text_mutation_caught(name: str, mutate: Callable[[str], str]) -> None:
    assert _tree.check_dockerignore_text(mutate(GOLDEN_DOCKERIGNORE)), f"{name}: 위반을 잡지 못했다"


# 재제외 가운데 비밀 후보가 아닌 것(캐시 · venv · git) — 나머지는 탐침의 비밀 후보 판정과 짝이다
NON_SECRET_REEXCLUDE = frozenset({"**/__pycache__", "**/*.py[co]", "**/.pytest_cache", "**/.venv", "**/.git*"})
_CASE_CLASS_RE = re.compile(r"\[([a-z])([A-Z])\]")


def fold_case_classes(pattern: str) -> str:
    """[pP] 꼴 문자 집합(소문자 · 같은 글자의 대문자)을 소문자 하나로 접는다 — 다른 문자 집합은 그대로 둔다."""
    return _CASE_CLASS_RE.sub(lambda match: match.group(1) if match.group(2) == match.group(1).upper() else match.group(0), pattern)


def bare_letters(pattern: str) -> str:
    """[pP] 꼴 문자 집합(같은 글자의 소문자 · 대문자)을 지운 나머지의 ASCII 글자 — 빈 글이면 대소문자를 가리지 않는 꼴이다(마감 라운드 Z3)."""
    stripped = _CASE_CLASS_RE.sub(lambda match: "" if match.group(2) == match.group(1).upper() else match.group(0), pattern)
    return "".join(re.findall(r"[A-Za-z]", stripped))


def test_image_sensitive_suffixes_match_reexclusions() -> None:
    """탐침의 비밀 후보(머리 · 접미 · 이름 — 소문자 형) = dockerignore 재제외의 비밀 후보 꼴(③ r2 M1 · 마지막 라운드 N6 · 마감 라운드 Z3 — 한쪽만
    늘면 거르기와 판정이 어긋난다): **/<머리>* · **/*<접미> · **/<이름>을 [xX] 문자 집합을 접은 꼴로 견준다. 비밀 후보 꼴 열하나는 모두 대소문자
    무관 꼴(글자마다 [xX] 문자 집합 · 숫자 · 기호는 그대로)이어야 한다 — 탐침이 이름의 소문자 형으로 판정하므로 거르기도 대소문자를 가리지 않아야
    둘이 같은 집합이다(③ r2 리뷰 B-1 — CASE.PEM · .Env.prod · 마지막 리뷰 B-1 — ID_RSA · LOCAL.ENV · .NETRC)."""
    prefixes: set[str] = set()
    suffixes: set[str] = set()
    names: set[str] = set()
    secret_patterns = [pattern for pattern in _tree.DOCKERIGNORE_REEXCLUDE if pattern not in NON_SECRET_REEXCLUDE]
    for pattern in secret_patterns:
        body = fold_case_classes(pattern.removeprefix("**/"))
        if body.startswith("*"):
            suffixes.add(body[1:])
        elif body.endswith("*"):
            prefixes.add(body[:-1])
        else:
            names.add(body)
    assert prefixes == set(_proc.IMAGE_SENSITIVE_PREFIXES) == {".env", "id_rsa", "id_ed25519", "id_ecdsa"}
    assert suffixes == set(_proc.IMAGE_SENSITIVE_SUFFIXES) == {".pem", ".key", ".crt", ".p12", ".pfx", ".env"}
    assert names == set(_proc.IMAGE_SENSITIVE_NAMES) == {".netrc"}
    assert sorted(fold_case_classes(pattern) for pattern in secret_patterns) == sorted(
        [
            "**/.env*",
            "**/*.env",
            "**/*.pem",
            "**/*.key",
            "**/*.crt",
            "**/*.p12",
            "**/*.pfx",
            "**/.netrc",
            "**/id_rsa*",
            "**/id_ed25519*",
            "**/id_ecdsa*",
        ]
    )
    case_sensitive = {pattern: bare_letters(pattern.removeprefix("**/")) for pattern in secret_patterns}
    assert {pattern: letters for pattern, letters in case_sensitive.items() if letters} == {}


@pytest.mark.parametrize(
    ("name", "sensitive"),
    [
        ("CASE.PEM", True),
        ("case2.KEY", True),
        ("case3.Crt", True),
        (".Env.prod", True),
        ("CLIENT.P12", True),
        ("bundle.PfX", True),
        ("local.env", True),
        ("LOCAL.ENV", True),
        (".netrc", True),
        ("id_rsa", True),
        ("id_ed25519.pub", True),
        ("id_ecdsa", True),
        ("views.py", False),
        ("monkey", False),
        ("environment.py", False),
        ("netrc.py", False),
        ("ssh_id_rsa_notes.txt", False),
        # 마감 라운드 Z3(마지막 리뷰 B-1 실측 — 이미지에 실렸던 이름 꼴의 대문자 변형)
        ("ID_RSA", True),
        (".NETRC", True),
        ("ID_ED25519", True),
        ("Id_Ecdsa", True),
    ],
)
def test_image_sensitive_name_is_case_insensitive(name: str, sensitive: bool) -> None:
    """탐침 판정(image_sensitive_name = IMAGE_PROBE_SCRIPT 안의 식)은 이름의 소문자 형으로 견준다(마지막 라운드 N6)."""
    assert _proc.image_sensitive_name(name) is sensitive


@pytest.mark.parametrize(
    ("pattern", "letters"),
    [
        ("[iI][dD]_[rR][sS][aA]*", ""),
        ("*.[pP]12", ""),
        (".[nN][eE][tT][rR][cC]", ""),
        ("id_rsa*", "idrsa"),
        ("*.env", "env"),
        ("[iI][dD]_rsa*", "rsa"),
        ("[iI][dD]_[rR][sS][aB]*", "aB"),
    ],
    ids=["case-free", "digits", "name", "lowercase-prefix", "lowercase-suffix", "half-classes", "mismatched-class"],
)
def test_bare_letters_reports_case_sensitive_letters(pattern: str, letters: str) -> None:
    """대소문자 무관 판정(bare_letters — 마감 라운드 Z3)이 공허하지 않다: 같은 글자의 [xX] 문자 집합만 지우고 남은 맨 글자를 돌려준다(짝이 맞지
    않는 문자 집합 [aB]는 대소문자 무관이 아니다)."""
    assert bare_letters(pattern) == letters


def test_image_probe_script_reports_case_variants_and_key_names(tmp_path: Path) -> None:
    """탐침 스크립트가 대소문자 변형(CASE.PEM · .Env.prod)과 흔한 비밀 이름(*.env · .netrc · id_*)과 그 대문자 변형(LOCAL.ENV · .NETRC ·
    ID_RSA · ID_ED25519 · Id_Ecdsa — 마감 라운드 Z3 · 마지막 리뷰 B-1)을 싣는다 — 판정이 image_sensitive_name과 같다(③ r2 리뷰 B-1 실측의
    남은 것 · 마지막 라운드 N6). 대문자 변형은 소문자 이름과 다른 디렉터리에 둔다(대소문자를 가리지 않는 파일 시스템에서 한 파일이 되지 않게)."""
    pod = tmp_path / "pod"
    planted = (
        "sample_pod/CASE.PEM",
        "sample_pod/case2.KEY",
        "case3.Crt",
        "sample_pod/.Env.prod",
        "local.env",
        ".netrc",
        "id_rsa",
        "sample_pod/id_ed25519.pub",
        "id_ecdsa",
        "sample_pod/views.py",
        "sample_pod/monkey",
        "sample_pod/LOCAL.ENV",
        "sample_pod/.NETRC",
        "sample_pod/ID_RSA",
        "keys/ID_ED25519",
        "keys/Id_Ecdsa",
    )
    for relative in planted:
        write_empty(pod, relative)
    facts = run_probe(IMAGE_PROBE_SCRIPT, [str(pod)], tmp_path)
    expected = sorted(relative for relative in planted if _proc.image_sensitive_name(relative.rsplit("/", 1)[-1]))
    assert facts["sensitive_files"] == expected
    assert len(expected) == len(planted) - 2


def test_image_probe_script_reports_certificate_files(tmp_path: Path) -> None:
    pod = tmp_path / "pod"
    for relative in ("sample_pod/jt-harness.crt", "certs/client.p12", "client.pfx", "sample_pod/views.py", "sample_pod/.env.jt-harness"):
        write_empty(pod, relative)
    facts = run_probe(IMAGE_PROBE_SCRIPT, [str(pod)], tmp_path)
    assert facts["sensitive_files"] == ["certs/client.p12", "client.pfx", "sample_pod/.env.jt-harness", "sample_pod/jt-harness.crt"]


# ---------- M2(b) 심은 감시 파일 기록(image 픽스처 → gen-33) ----------


def expected_planted() -> tuple[str, ...]:
    return (*conftest.BUILD_SENTINEL_FILES, conftest.VENV_SENTINEL)


def test_check_planted_sentinels_golden() -> None:
    expected = expected_planted()
    assert _tree.check_planted_sentinels(expected, expected) == []
    assert _tree.check_planted_sentinels(list(reversed(expected)), expected) == []  # 순서 무관 · 목록도 받는다


PLANTED_MUTATIONS: list[tuple[str, Callable[[tuple[str, ...]], Any], str]] = [
    ("record-missing", lambda _expected: None, "기록"),
    ("nothing-planted", lambda _expected: (), "jt-harness.local"),
    ("venv-sentinel-skipped", lambda expected: expected[:-1], "jt-harness-sentinel"),
    ("top-level-local-skipped", lambda expected: tuple(item for item in expected if item != "jt-harness.local"), "jt-harness.local"),
    ("extra-planted", lambda expected: (*expected, "sample_pod/extra.txt"), "extra.txt"),
    ("duplicate", lambda expected: (*expected, expected[0]), "중복"),
    ("not-a-list", lambda _expected: "jt-harness.local", "읽지"),
]


@pytest.mark.parametrize(("name", "change", "word"), PLANTED_MUTATIONS, ids=[name for name, _, _ in PLANTED_MUTATIONS])
def test_check_planted_sentinels_mutation_caught(name: str, change: Callable[[tuple[str, ...]], Any], word: str) -> None:
    expected = expected_planted()
    found = _tree.check_planted_sentinels(change(expected), expected)
    assert found and any(word in item for item in found), (name, found)


def test_build_sentinels_records_planted_files(tmp_path: Path) -> None:
    """build_with_sentinels(record=…)가 실제로 심은 감시 파일(pod 기준 상대 경로)을 빌드 전에 넘긴다 — image 픽스처가 이 목록을
    stash에 싣고 gen-33이 대조한다(③ r2 M2(b))."""
    pod = make_sentinel_pod(tmp_path, venv=False)
    recorded: list[str] = []
    seen: list[bool] = []

    def build() -> _proc.ProcResult:
        seen.append(tuple(recorded) == expected_planted())  # 기록은 빌드 앞이다
        return fake_build_result()

    conftest.build_with_sentinels(pod, build, record=recorded.extend)
    assert tuple(recorded) == expected_planted() and seen == [True]
    assert not any(os.path.lexists(path) for path in sentinel_paths(pod))


# ---------- M3 이미지 dev 전용 배포(uv sync --no-dev) ----------


def test_image_dev_distribution_names_match_dev_group() -> None:
    """탐침이 찾는 dev 전용 배포 = gen-2가 생성물 dependency-groups.dev에 요구하는 이름(같은 목록 — ③ r2 M3)."""
    assert tuple(_proc.IMAGE_DEV_DISTRIBUTIONS) == _tree.DEV_REQUIREMENTS


@pytest.mark.parametrize(
    ("dev", "word"),
    [
        (["pytest"], "pytest"),
        (["django-migration-linter", "testcontainers"], "testcontainers"),
        (None, "읽지"),
        ("pytest", "읽지"),
        ([7], "읽지"),
    ],
    ids=["pytest-present", "linter-and-testcontainers-present", "unreadable", "not-list", "not-strings"],
)
def test_check_image_probe_dev_distributions_caught(dev: Any, word: str) -> None:
    found = check_image_probe(image_probe(dev_distributions=dev))
    assert found and any(word in item for item in found), found


def test_image_probe_script_reports_dev_distributions(tmp_path: Path) -> None:
    """하네스 venv(pytest가 있다)에서 돌리면 dev_distributions에 pytest가 실린다 — 정렬 · 목록 안의 이름만."""
    facts = run_probe(IMAGE_PROBE_SCRIPT, [str(tmp_path / "pod")], tmp_path)
    dev = facts["dev_distributions"]
    assert "pytest" in dev and dev == sorted(dev) and set(dev) <= set(_proc.IMAGE_DEV_DISTRIBUTIONS), dev


# ---------- M4 build-arg 배선(--build-arg APP_GIT_SHA · APP_VERSION → 라벨 revision · Config.Env) ----------

GIVEN_BUILD_ARGS = {"APP_VERSION": "0.0.0+harness", "APP_GIT_SHA": "0123456789abcdef0123456789abcdef01234567"}


def built_env(**values: str | None) -> list[str]:
    """GOLDEN_IMAGE_CONFIG Env에서 APP_* 값을 준 build-arg로 바꾼 목록 — values로 다시 바꾼다(None = 그 항목을 지운다)."""
    wanted = {**GIVEN_BUILD_ARGS, **values}
    env = [entry for entry in GOLDEN_IMAGE_CONFIG["Config"]["Env"] if entry.split("=", 1)[0] not in GIVEN_BUILD_ARGS]
    return [*env, *(f"{name}={value}" for name, value in wanted.items() if value is not None)]


def built_image(**config: Any) -> list[dict[str, Any]]:
    """하네스 빌드(--build-arg = GIVEN_BUILD_ARGS)의 docker image inspect 꼴 — config 키를 바꾼 사본(None = 지운다)."""
    data = json.loads(json.dumps(GOLDEN_IMAGE_CONFIG))
    data["Config"]["Env"] = built_env()
    data["Config"]["Labels"] = {"org.opencontainers.image.revision": GIVEN_BUILD_ARGS["APP_GIT_SHA"]}
    for key, value in config.items():
        if value is None:
            data["Config"].pop(key, None)
        else:
            data["Config"][key] = value
    return [data]


def test_check_image_build_args_golden() -> None:
    assert _tree.check_image_build_args(built_image(), GIVEN_BUILD_ARGS) == []
    assert _tree.check_image_build_args(built_image()[0], GIVEN_BUILD_ARGS) == []  # 목록 없이 객체 하나도 받는다


BUILD_ARG_MUTATIONS: list[tuple[str, Any, Any]] = [
    # ARG 삭제 + LABEL · ENV 리터럴(③ 리뷰 A-2 변이) — 라벨이 준 값이 아니다
    ("label-literal-default", built_image(Labels={"org.opencontainers.image.revision": "0000000"}), GIVEN_BUILD_ARGS),
    ("env-sha-literal-default", built_image(Env=built_env(APP_GIT_SHA="0000000")), GIVEN_BUILD_ARGS),
    ("env-version-default", built_image(Env=built_env(APP_VERSION="0.0.0+local")), GIVEN_BUILD_ARGS),
    ("env-sha-missing", built_image(Env=built_env(APP_GIT_SHA=None)), GIVEN_BUILD_ARGS),
    ("env-version-missing", built_image(Env=built_env(APP_VERSION=None)), GIVEN_BUILD_ARGS),
    ("env-sha-twice", built_image(Env=[*built_env(), "APP_GIT_SHA=" + GIVEN_BUILD_ARGS["APP_GIT_SHA"]]), GIVEN_BUILD_ARGS),
    ("labels-missing", built_image(Labels=None), GIVEN_BUILD_ARGS),
    ("record-missing", built_image(), None),
    ("two-images", built_image() + built_image(), GIVEN_BUILD_ARGS),
    ("not-mapping", "not json object", GIVEN_BUILD_ARGS),
]


@pytest.mark.parametrize(("name", "inspect", "given"), BUILD_ARG_MUTATIONS, ids=[name for name, _, _ in BUILD_ARG_MUTATIONS])
def test_check_image_build_args_mutation_caught(name: str, inspect: Any, given: Any) -> None:
    assert _tree.check_image_build_args(inspect, given), f"{name}: 위반을 잡지 못했다"


def test_image_build_args_shape() -> None:
    """image 픽스처의 build-arg(③ r2 M4) — APP_GIT_SHA는 부를 때마다 새 소문자 hex 40자(기동 단언의 꼴 7–64) · APP_VERSION은 하네스 판."""
    first, second = conftest.image_build_args(), conftest.image_build_args()
    assert set(first) == {"APP_VERSION", "APP_GIT_SHA"} and first["APP_VERSION"] == "0.0.0+harness"
    sha = first["APP_GIT_SHA"]
    assert len(sha) == 40 and set(sha) <= set("0123456789abcdef") and sha != second["APP_GIT_SHA"]


# ---------- M5 compose config 내용(docker compose -f compose.dev.yml config --format json — gen-35) ----------

COMPOSE_PROJECT = os.path.abspath(os.path.join("compose-golden", "apps", "sample-pod"))
COMPOSE_DRAGONFLY_IMAGE = "ghcr.io/dragonflydb/dragonfly:v1.40.1@sha256:" + "e" * 64
COMPOSE_KAFKA_IMAGE = "apache/kafka:4.3.1@sha256:" + "f" * 64
COMPOSE_ACL = "/etc/dragonfly/users.acl"
HTTP_OFF = "--primary_port_http_enabled=false"


def compose_port(target: int) -> dict[str, Any]:
    return {"mode": "ingress", "host_ip": "127.0.0.1", "target": target, "published": str(target), "protocol": "tcp"}


def golden_compose() -> dict[str, Any]:
    """docker compose config --format json의 꼴 — 조각 ③ 생성물 실측(build context는 절대 경로) + ③ r2 M5의 HTTP 끔. 부를 때마다
    새 사본이다."""
    return {
        "name": "sample-pod-dev",
        "networks": {"default": {"name": "sample-pod-dev_default", "ipam": {}}},
        "services": {
            "postgres": {
                "command": None,
                "entrypoint": None,
                "environment": {"POSTGRES_PASSWORD": ""},
                "build": {"context": os.path.join(COMPOSE_PROJECT, "tests", "docker", "pg-tls"), "dockerfile": "Dockerfile"},
                "ports": [compose_port(5432)],
            },
            "dragonfly": {
                "command": ["--proactor_threads=2", "--maxmemory=512mb", f"--aclfile={COMPOSE_ACL}", HTTP_OFF],
                "entrypoint": None,
                "image": COMPOSE_DRAGONFLY_IMAGE,
                "volumes": [
                    {
                        "type": "bind",
                        "source": os.path.join(COMPOSE_PROJECT, "compose", "dragonfly-dev.acl"),
                        "target": COMPOSE_ACL,
                        "read_only": True,
                        "bind": {},
                    }
                ],
                "ports": [compose_port(6379)],
            },
            "kafka": {"command": None, "entrypoint": None, "image": COMPOSE_KAFKA_IMAGE, "ports": [compose_port(9092)]},
        },
    }


def compose_service(config: dict[str, Any], name: str) -> dict[str, Any]:
    return config["services"][name]


def replace_dragonfly_token(old: str, *new: str) -> Callable[[dict[str, Any]], None]:
    def mutate(config: dict[str, Any]) -> None:
        command = compose_service(config, "dragonfly")["command"]
        if command.count(old) != 1:
            raise LookupError(f"골든 dragonfly command에 {old!r}가 정확히 한 번 있지 않다")
        index = command.index(old)
        command[index : index + 1] = list(new)

    return mutate


def test_check_compose_config_golden() -> None:
    assert _tree.check_compose_config(golden_compose(), COMPOSE_PROJECT) == []


COMPOSE_SPELLINGS: list[tuple[str, Callable[[dict[str, Any]], Any]]] = [
    ("http-flag-no-prefix", replace_dragonfly_token(HTTP_OFF, "--noprimary_port_http_enabled")),
    ("http-flag-zero", replace_dragonfly_token(HTTP_OFF, "--primary_port_http_enabled=0")),
    ("http-flag-uppercase-false", replace_dragonfly_token(HTTP_OFF, "--primary_port_http_enabled=FALSE")),
    ("aclfile-separate-value", replace_dragonfly_token(f"--aclfile={COMPOSE_ACL}", "--aclfile", COMPOSE_ACL)),
    ("service-without-ports", lambda c: compose_service(c, "kafka").pop("ports")),
    ("extra-build-service", lambda c: c["services"].update(tool={"build": {"context": os.path.join(COMPOSE_PROJECT, "tool")}})),
]


@pytest.mark.parametrize(("name", "mutate"), COMPOSE_SPELLINGS, ids=[name for name, _ in COMPOSE_SPELLINGS])
def test_check_compose_config_equivalent_spellings_accepted(name: str, mutate: Callable[[dict[str, Any]], Any]) -> None:
    config = golden_compose()
    mutate(config)
    assert _tree.check_compose_config(config, COMPOSE_PROJECT) == [], name


COMPOSE_MUTATIONS: list[tuple[str, Callable[[dict[str, Any]], Any]]] = [
    ("dragonfly-port-all-interfaces", lambda c: compose_service(c, "dragonfly")["ports"][0].update(host_ip="0.0.0.0")),
    ("kafka-port-host-ip-missing", lambda c: compose_service(c, "kafka")["ports"][0].pop("host_ip")),
    ("postgres-port-ipv6-any", lambda c: compose_service(c, "postgres")["ports"][0].update(host_ip="::")),
    ("dragonfly-network-mode-host", lambda c: compose_service(c, "dragonfly").update(network_mode="host")),
    ("dragonfly-image-tag-only", lambda c: compose_service(c, "dragonfly").update(image="ghcr.io/dragonflydb/dragonfly:v1.40.1")),
    ("kafka-image-short-digest", lambda c: compose_service(c, "kafka").update(image="apache/kafka:4.3.1@sha256:abc")),
    ("aclfile-removed", replace_dragonfly_token(f"--aclfile={COMPOSE_ACL}")),
    ("aclfile-unmounted-path", replace_dragonfly_token(f"--aclfile={COMPOSE_ACL}", "--aclfile=/tmp/users.acl")),
    ("http-flag-removed", replace_dragonfly_token(HTTP_OFF)),
    ("http-flag-true", replace_dragonfly_token(HTTP_OFF, "--primary_port_http_enabled=true")),
    ("http-flag-later-bare", lambda c: compose_service(c, "dragonfly")["command"].append("--primary_port_http_enabled")),
    ("acl-volume-writable", lambda c: compose_service(c, "dragonfly")["volumes"][0].update(read_only=False)),
    ("acl-volume-read-only-missing", lambda c: compose_service(c, "dragonfly")["volumes"][0].pop("read_only")),
    ("acl-volume-other-target", lambda c: compose_service(c, "dragonfly")["volumes"][0].update(target="/etc/dragonfly/other.acl")),
    (
        "postgres-build-other-context",
        lambda c: compose_service(c, "postgres")["build"].update(context=os.path.join(COMPOSE_PROJECT, "docker", "pg")),
    ),
    (
        "postgres-image-instead-of-build",
        lambda c: (compose_service(c, "postgres").pop("build"), compose_service(c, "postgres").update(image="postgres:18.6-alpine")),
    ),
    ("dragonfly-missing", lambda c: c["services"].pop("dragonfly")),
    ("postgres-missing", lambda c: c["services"].pop("postgres")),
]


@pytest.mark.parametrize(("name", "mutate"), COMPOSE_MUTATIONS, ids=[name for name, _ in COMPOSE_MUTATIONS])
def test_check_compose_config_mutation_caught(name: str, mutate: Callable[[dict[str, Any]], Any]) -> None:
    config = golden_compose()
    mutate(config)
    assert _tree.check_compose_config(config, COMPOSE_PROJECT), f"{name}: 위반을 잡지 못했다"


@pytest.mark.parametrize(
    "config",
    ["not json object", [], {"name": "sample-pod-dev"}, {"services": []}],
    ids=["not-mapping", "list", "services-missing", "services-not-mapping"],
)
def test_check_compose_config_unreadable(config: Any) -> None:
    assert _tree.check_compose_config(config, COMPOSE_PROJECT)


# ---------- T072 마지막 라운드 N5(③ r2 리뷰 A-2): gen-35는 모든 프로필을 펼친 설정을 판정한다 ----------
# 프로필로 묶은 서비스(도구 서비스 — pgadmin 따위)는 기본 `docker compose config`에서 빠진다(리뷰 실측 · Compose v5.6.0) — 허용 목록 env가
# COMPOSE_PROFILES를 지우므로 gen-35는 늘 비활성 프로필을 숨긴 설정만 봤다. argv는 도우미 하나(tests/_tree.py compose_config_argv)다.


def test_compose_config_argv_expands_every_profile() -> None:
    """gen-35 argv = docker compose -f compose.dev.yml --profile "*" config --format json — 셸 없이 넘기므로 "*"는 글자 그대로
    Compose에 닿는다(모든 프로필)."""
    assert _tree.compose_config_argv("docker") == [
        "docker",
        "compose",
        "-f",
        "compose.dev.yml",
        "--profile",
        "*",
        "config",
        "--format",
        "json",
    ]


def profile_service(config: dict[str, Any]) -> None:
    """골든에 프로필 서비스 하나(도구 · 0.0.0.0 포트 · 태그만 이미지) — --profile "*" 출력의 꼴(profiles 키가 남는다)."""
    config["services"]["pgadmin"] = {
        "profiles": ["tools"],
        "command": None,
        "entrypoint": None,
        "image": "dpage/pgadmin4:latest",
        "ports": [{"mode": "ingress", "host_ip": "0.0.0.0", "target": 80, "published": "5050", "protocol": "tcp"}],
    }


def test_check_compose_config_judges_profile_services() -> None:
    """모든 프로필을 펼친 설정의 프로필 서비스도 같은 규칙으로 판정한다 — 0.0.0.0 포트 · 태그만 이미지 = 그 서비스의 위반 둘."""
    config = golden_compose()
    profile_service(config)
    found = _tree.check_compose_config(config, COMPOSE_PROJECT)
    assert len(found) == 2 and all(item.startswith("pgadmin: ") for item in found), found


# ---------- T072 마감 라운드 Z2(마지막 리뷰 A-2): gen-35의 프로필 펼침 탐침 ----------
# 생성 compose.dev.yml에는 프로필 서비스가 없어 '*'는 펼칠 것이 없다 — '*'를 모르는 Compose(→ '*'를 프로필 이름 하나로 받는다)에서도 gen-35가
# 초록이었다. gen-35는 프로필 서비스 하나만 든 탐침 파일(_tree.COMPOSE_PROFILE_PROBE_TEXT)을 같은 argv(compose_config_argv · 허용 목록 env)로
# 펼치고 그 서비스가 출력에 있는지 본다(_tree.check_compose_profile_probe). 아래는 탐침 파일의 꼴과 판정의 골든 · 변이다 — 실제 Compose
# 실측은 gen-35 본문이다.
PROFILE_NOT_EXPANDED = '이 Compose는 --profile "*"를 펼치지 않는다 — gen-35가 프로필 서비스를 보지 못한다'


def test_compose_profile_probe_text_is_one_profiled_service() -> None:
    """탐침 파일 = 프로필 COMPOSE_PROFILE_PROBE_PROFILE로만 켜지는 서비스 하나(image · profiles뿐 — build · 포트 · 볼륨 없음 · config는
    이미지를 받지 않는다) + 고정 프로젝트 이름(임시 디렉터리 이름에 기대지 않는다)."""
    probe = yaml.safe_load(_tree.COMPOSE_PROFILE_PROBE_TEXT)
    assert list(probe) == ["name", "services"]
    assert list(probe["services"]) == [_tree.COMPOSE_PROFILE_PROBE_SERVICE]
    service = probe["services"][_tree.COMPOSE_PROFILE_PROBE_SERVICE]
    assert sorted(service) == ["image", "profiles"]
    assert service["profiles"] == [_tree.COMPOSE_PROFILE_PROBE_PROFILE]


def profile_probe_output(*services: str) -> dict[str, Any]:
    """탐침 파일의 docker compose … config --format json 꼴(Compose v5.6.0 실측 — 켜진 서비스만 services에 남는다 · 프로필 밖이면
    services는 빈 매핑)."""
    return {
        "name": "jt-compose-profile-probe",
        "services": {
            name: {"profiles": [_tree.COMPOSE_PROFILE_PROBE_PROFILE], "image": "jt-compose-profile-probe:none"} for name in services
        },
    }


def test_check_compose_profile_probe_golden() -> None:
    assert _tree.check_compose_profile_probe(profile_probe_output(_tree.COMPOSE_PROFILE_PROBE_SERVICE)) == []


# 입력은 호출 때 만든다(모듈 속성이 하나 빠져도 그 시험만 실패한다 — 이 파일의 규칙)
PROFILE_PROBE_MUTATIONS: list[tuple[str, Callable[[], Any], str]] = [
    ("services-empty", lambda: profile_probe_output(), PROFILE_NOT_EXPANDED),  # --profile <다른 이름>의 실측 꼴
    ("services-missing", lambda: {"name": "jt-compose-profile-probe"}, PROFILE_NOT_EXPANDED),
    ("other-service-only", lambda: profile_probe_output("jt-other-service"), PROFILE_NOT_EXPANDED),
    ("not-an-object", lambda: None, "읽지"),
    ("services-not-mapping", lambda: {"services": [_tree.COMPOSE_PROFILE_PROBE_SERVICE]}, "읽지"),
]


@pytest.mark.parametrize(("name", "make", "word"), PROFILE_PROBE_MUTATIONS, ids=[name for name, _, _ in PROFILE_PROBE_MUTATIONS])
def test_check_compose_profile_probe_mutation_caught(name: str, make: Callable[[], Any], word: str) -> None:
    """탐침 서비스가 출력에 없으면(펼치지 않은 Compose) 결정 Z2의 문구로 위반 하나 · 출력을 읽지 못하면 위반 하나(목록 services에 이름이
    있어도 펼친 것으로 보지 않는다)."""
    found = _tree.check_compose_profile_probe(make())
    assert len(found) == 1 and word in found[0], (name, found)


# ---------- M6 프로세스 명령 상수 한 곳(_render) ----------


def test_process_commands_have_one_source() -> None:
    """명령 상수는 한 곳(_render — ③ r2 M6): 이미지 기동 스모크(conftest)와 gen-33 Dockerfile CMD 정적 검사(_tree)가 같은 객체를 쓰고,
    렌더 runtime_wiring이 deploy/base 명령을 같은 상수에 묶는다(README 「프로세스」 표 · D11 · D14)."""
    assert _render.WEB_COMMAND == (
        "gunicorn",
        "--config",
        "python:sample_pod.gunicorn_conf",
        "--no-control-socket",
        "sample_pod.wsgi:application",
    )
    assert _render.RELAY_COMMAND == ("python", "manage.py", "outbox_relay")
    assert _render.CELERY_COMMAND == (
        "celery",
        "--app",
        "sample_pod",
        "worker",
        "--pool",
        "solo",
        "--beat",
        "--schedule",
        "/tmp/celerybeat-schedule",
        "--without-gossip",
        "--without-mingle",
        "--without-heartbeat",
        "--loglevel",
        "INFO",
    )
    assert conftest.RELAY_COMMAND is _render.RELAY_COMMAND
    assert conftest.CELERY_COMMAND is _render.CELERY_COMMAND
    assert conftest.PURGE_COMMAND is _render.PURGE_COMMAND
    assert conftest.STARTUP_COMMAND == (*_render.INIT_COMMAND, "--wait", "1")
    assert _tree.WEB_COMMAND is _render.WEB_COMMAND
    assert _tree._command_tokens(GOLDEN_CMD.removeprefix("CMD ")) == list(_render.WEB_COMMAND)


# ---------- M11 copier 예약 이름(템플릿이 정하는 두 묶음 — 앱 라벨 · 생성 트리 최상위 이름) ----------

COPIER_TEXT = (TEMPLATE_DIR / "copier.yml").read_text(encoding="utf-8")
# 생성 기본 pod의 앱 라벨(tests.settings · get_app_configs() — copier.yml 주석의 목록 · 조각 ② r3 실측). 판정은 pod 자신을 뺀다.
POD_APP_LABELS = [
    "admin",
    "auth",
    "contenttypes",
    "sessions",
    "messages",
    "staticfiles",
    "sample_pod",
    "core",
    "django_common",
    "rlsapp",
    "django_migration_linter",
]


def test_copier_reserved_names_parsed() -> None:
    names = _tree.copier_reserved_names(COPIER_TEXT)
    assert names is not None and len(names) >= 300
    assert {"auth", "messages", "core", "rlsapp", "deploy", "compose", "dockerfile", "tests", "class", "logging"} <= names
    assert _tree.copier_reserved_names("pod_name:\n  type: str\n") is None  # validator 없음
    assert _tree.copier_reserved_names("pod_name: [unclosed\n") is None  # YAML 아님


def test_template_top_level_names() -> None:
    """생성 트리 최상위 이름 가운데 pod 패키지 디렉터리와 부딪힐 수 있는 것(③ r2 M11) — 점 없는 첫 경로 조각의 소문자 형(Dockerfile →
    dockerfile — 대소문자를 가리지 않는 파일 시스템) · pod 패키지(sample_pod) 제외. 조각 ④ 이후 최상위 이름이 늘면 이 기대와 copier.yml
    예약 목록을 함께 고친다."""
    assert _tree.template_top_level_names() == frozenset({"compose", "deploy", "dockerfile", "tests"})


def test_check_reserved_pod_names_golden() -> None:
    reserved = _tree.copier_reserved_names(COPIER_TEXT)
    assert _tree.check_reserved_pod_names(reserved, POD_APP_LABELS, _tree.template_top_level_names()) == []


@pytest.mark.parametrize("removed", ["auth", "deploy"], ids=["auth-removed", "deploy-removed"])
def test_check_reserved_pod_names_mutation_caught(removed: str) -> None:
    reserved = _tree.copier_reserved_names(replace_once(COPIER_TEXT, f"'{removed}', ", ""))
    assert reserved is not None and removed not in reserved
    found = _tree.check_reserved_pod_names(reserved, POD_APP_LABELS, _tree.template_top_level_names())
    assert found and any(removed in item for item in found), found


def test_check_reserved_pod_names_unreadable_list() -> None:
    assert _tree.check_reserved_pod_names(None, POD_APP_LABELS, _tree.template_top_level_names())


# T072 마지막 라운드 N7(③ r2 리뷰 B-3): gen-37의 최상위 이름 = 하네스 상수(template_top_level_names) ∪ 실제 생성 트리 최상위의 점 없는
# snake 꼴 이름(pod 패키지 · .venv · __pycache__ 제외 — generated_top_level_names). 상수만으로는 템플릿에 새 최상위 디렉터리를 더하고 상수를
# 고치지 않으면 gen-37 · gen-1 · gen-25 · gen-29가 모두 초록이었다.
GENERATED_TOP_LEVEL_FILES = (
    "Dockerfile",
    "Dockerfile.dockerignore",
    "README.md",
    "compose.dev.yml",
    "env.example",
    "manage.py",
    "pyproject.toml",
    "uv.lock",
    ".copier-answers.yml",
    "sample_pod/__init__.py",
    "tests/__init__.py",
    "deploy/base/kustomization.yaml",
    "compose/dragonfly-dev.acl",
    ".venv/pyvenv.cfg",
    "__pycache__/x.cpython-313.pyc",
    ".pytest_cache/README.md",
)


def make_generated_top_level(root: Path) -> Path:
    pod = root / "apps" / "sample-pod"
    for relative in GENERATED_TOP_LEVEL_FILES:
        write_empty(pod, relative)
    return pod


def test_generated_top_level_names_golden(tmp_path: Path) -> None:
    """생성 트리 꼴(조각 ④ 끝 실측 최상위) → 점 없는 snake 꼴 이름 = 상수와 같은 {compose, deploy, dockerfile, tests}(Dockerfile은 소문자
    형 · pod 패키지 · .venv · __pycache__ · .pytest_cache · 점 든 파일 제외) · 예약 목록이 둘의 합집합을 덮는다."""
    pod = make_generated_top_level(tmp_path)
    names = _tree.generated_top_level_names(pod)
    assert names == frozenset({"compose", "deploy", "dockerfile", "tests"}) == _tree.template_top_level_names()
    reserved = _tree.copier_reserved_names(COPIER_TEXT)
    assert _tree.check_reserved_pod_names(reserved, POD_APP_LABELS, _tree.template_top_level_names() | names) == []


@pytest.mark.parametrize("extra", ["scripts/", "Makefile", "docs/"], ids=["top-level-dir-scripts", "top-level-file-makefile", "top-level-dir-docs"])
def test_generated_top_level_names_new_entry_caught(tmp_path: Path, extra: str) -> None:
    """사본 트리에 최상위 항목 하나(상수에 없다) → 그 이름이 생성 트리 최상위 이름에 실리고 copier.yml 예약 목록에 없어 위반 하나 —
    상수(template_top_level_names)를 고치지 않아도 잡는다."""
    pod = make_generated_top_level(tmp_path)
    if extra.endswith("/"):
        (pod / extra.rstrip("/")).mkdir()
    else:
        write_empty(pod, extra)
    name = extra.rstrip("/").lower()
    names = _tree.generated_top_level_names(pod)
    reserved = _tree.copier_reserved_names(COPIER_TEXT)
    found = _tree.check_reserved_pod_names(reserved, POD_APP_LABELS, _tree.template_top_level_names() | names)
    assert name in names and name not in _tree.template_top_level_names()
    assert len(found) == 1 and f"'{name}'" in found[0], found


FAKE_DJANGO_APPS = """\
class _Config:
    def __init__(self, label):
        self.label = label


class _Apps:
    def get_app_configs(self):
        return [_Config(label) for label in {labels!r}]


apps = _Apps()
"""


def test_app_labels_probe_script_prints_labels(tmp_path: Path) -> None:
    (tmp_path / "django").mkdir()
    (tmp_path / "django" / "__init__.py").write_text(FAKE_DJANGO_INIT, encoding="utf-8")
    (tmp_path / "django" / "apps.py").write_text(FAKE_DJANGO_APPS.format(labels=POD_APP_LABELS), encoding="utf-8")
    assert run_probe(_proc.APP_LABELS_PROBE_SCRIPT, [], tmp_path, env=_proc.allowlist_env()) == POD_APP_LABELS


# ---------- 허용 목록 env(누출 탐침 위생 — 조각 ② r3 교훈 · gen-35 · gen-37) ----------


def test_allowlist_env_keeps_only_allowed_names(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    """셸의 다른 이름(세션 토큰 · 판정을 바꾸는 COMPOSE_* · JT_DEV_*)은 자식에 가지 않는다 — 허용 목록 이름 · 덧붙인 값 ·
    PYTHONIOENCODING=utf-8만 남는다."""
    planted = {
        "JT_FAKE_SESSION_TOKEN": "fake-" + secrets.token_hex(8),
        "COMPOSE_PROFILES": "jt-fake",
        "JT_DEV_POSTGRES_PORT": "0.0.0.0:5432",
    }
    for name, value in planted.items():
        monkeypatch.setenv(name, value)
    overlay = _proc.allowlist_env({"DJANGO_SETTINGS_MODULE": "tests.settings"})
    env = child_env(overlay)
    names = {name.upper() for name in env}
    assert not names & set(planted)
    assert names <= _proc.ALLOWED_CHILD_ENV | {"DJANGO_SETTINGS_MODULE"}
    assert env["DJANGO_SETTINGS_MODULE"] == "tests.settings" and env["PYTHONIOENCODING"] == "utf-8" and "PATH" in names
    script = "import os, sys; sys.stdout.write(','.join(sorted(n for n in os.environ if n.upper().startswith(('JT_', 'COMPOSE_')))))"
    seen = run([sys.executable, "-c", script], cwd=tmp_path, timeout=60, env=overlay)
    assert seen.ok and seen.stdout == ""
