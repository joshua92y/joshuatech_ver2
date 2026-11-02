"""하네스의 경로 상수와 미니 저장소 배치(T065).

생성 위치 규칙(contracts/pod-template.md 머리): pod = <root>/apps/<pod>, django-common = 두 단계 위의 형제
<root>/packages/django-common — 템플릿의 path 의존성 ../../packages/django-common이 이 배치 하나만 가정한다. 하네스는
임시 미니 저장소에 같은 배치를 재현한다(django-common은 pyproject.toml과 src/만 복사 — tests · .venv · 캐시는 뺀다).
"""

from __future__ import annotations

import os
import shutil
import stat
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Any

TESTS_DIR = Path(__file__).resolve().parent
TEMPLATE_DIR = TESTS_DIR.parent  # templates/django-pod
REPO_ROOT = Path(__file__).resolve().parents[3]
DJANGO_COMMON_DIR = REPO_ROOT / "packages" / "django-common"

POD_NAME = "sample-pod"
POD_SNAKE = "sample_pod"
IMAGE_TAG = "jt-sample-pod:t065"  # gen-6 빌드 이미지 — 세션 끝에 지운다
SAMPLE_ROOT_ENV = "JT_SAMPLE_POD_ROOT"
MARKER_NAME = ".jt-sample-pod-root"
MARKER_TEXT = (
    "이 디렉터리는 T065 하네스(templates/django-pod/tests)가 만든 생성 트리(미니 저장소)다.\n"
    "하네스는 다음 실행 때 이 표식 파일을 뺀 내용을 지우고 다시 만든다.\n"
)


def layout_problems() -> list[str]:
    """저장소 배치가 하네스의 가정(이 파일 = <저장소>/templates/django-pod/tests/_layout.py)과 다르면 문제 목록."""
    problems: list[str] = []
    copier_yml = REPO_ROOT / "templates" / "django-pod" / "copier.yml"
    if not copier_yml.is_file():
        problems.append(f"저장소 루트로 본 {REPO_ROOT}에 templates/django-pod/copier.yml이 없다")
    if not (DJANGO_COMMON_DIR / "pyproject.toml").is_file():
        problems.append(f"{DJANGO_COMMON_DIR}/pyproject.toml이 없다")
    if not (DJANGO_COMMON_DIR / "src").is_dir():
        problems.append(f"{DJANGO_COMMON_DIR}/src가 없다")
    return problems


class SampleRootError(Exception):
    """JT_SAMPLE_POD_ROOT를 쓸 수 없다 — 이 예외가 날 때는 아무것도 지우지 않았다."""


def resolve_sample_root(raw: str) -> Path:
    """JT_SAMPLE_POD_ROOT 값 → 절대 경로. 상대 경로는 저장소 루트 기준이다(uv run --directory가 cwd를
    templates/django-pod로 바꾸므로 cwd 기준이면 quickstart의 tests/fixtures/generated가 하네스 tests/ 안을 가리킨다)."""
    candidate = Path(raw).expanduser()
    if not candidate.is_absolute():
        candidate = REPO_ROOT / candidate
    return candidate.resolve()


def _clear_readonly_and_retry(function: Callable[..., Any], path: str, _error: BaseException) -> None:
    os.chmod(path, stat.S_IWRITE)
    function(path)


def remove_entry(entry: Path) -> None:
    """표식 디렉터리 안의 항목 하나를 지운다. 링크(심볼릭 · junction)는 따라가지 않고 링크 자신만 지운다."""
    if entry.is_symlink() or entry.is_junction():
        try:
            entry.unlink()
        except OSError:
            os.rmdir(entry)
    elif entry.is_dir():
        shutil.rmtree(entry, onexc=_clear_readonly_and_retry)
    else:
        try:
            entry.unlink()
        except PermissionError:
            os.chmod(entry, stat.S_IWRITE)
            entry.unlink()


def prepare_sample_root(raw: str) -> Path:
    """JT_SAMPLE_POD_ROOT 디렉터리를 비워 쓸 수 있게 만들고 표식 파일을 둔다.

    - 없으면 만든다 · 비어 있으면 표식만 쓴다 · 표식이 있으면 표식을 뺀 내용을 지운다.
    - 표식 없이 내용이 있으면 SampleRootError — 하네스가 만든 디렉터리가 아니므로 지우지 않는다.
    - 저장소 루트와 그 상위, 템플릿 디렉터리(templates/django-pod)와 그 아래는 쓰지 않는다(템플릿 아래면 하네스
      tests/가 생성물의 테스트를 수집하고, copier가 템플릿 자신을 오염시킨다).
    """
    root = resolve_sample_root(raw)
    if root == REPO_ROOT or root in REPO_ROOT.parents:
        raise SampleRootError(f"{SAMPLE_ROOT_ENV}={raw!r} → {root}: 저장소 루트이거나 그 상위다 — 쓰지 않는다")
    if root == TEMPLATE_DIR or TEMPLATE_DIR in root.parents:
        raise SampleRootError(f"{SAMPLE_ROOT_ENV}={raw!r} → {root}: 템플릿 디렉터리 안이다 — 쓰지 않는다")
    if root.exists() and not root.is_dir():
        raise SampleRootError(f"{SAMPLE_ROOT_ENV}={raw!r} → {root}: 디렉터리가 아니다")
    marker = root / MARKER_NAME
    if root.exists():
        entries = sorted(root.iterdir())
        if entries and not marker.is_file():
            raise SampleRootError(
                f"{SAMPLE_ROOT_ENV}={raw!r} → {root}: 표식 파일 {MARKER_NAME} 없이 내용이 있다 — 하네스가 만든 "
                "디렉터리가 아니므로 지우지 않는다(빈 디렉터리나 새 경로를 준다)"
            )
        for entry in entries:
            if entry.name != MARKER_NAME:
                remove_entry(entry)
    else:
        root.mkdir(parents=True)
    marker.write_text(MARKER_TEXT, encoding="utf-8")
    return root


def copy_django_common(root: Path) -> Path:
    """<root>/packages/django-common에 저장소 django-common의 pyproject.toml과 src/를 복사한다."""
    destination = root / "packages" / "django-common"
    destination.mkdir(parents=True, exist_ok=False)
    shutil.copy2(DJANGO_COMMON_DIR / "pyproject.toml", destination / "pyproject.toml")
    shutil.copytree(
        DJANGO_COMMON_DIR / "src",
        destination / "src",
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc"),
    )
    return destination


def copier_copy_argv(pod_name: str, destination: Path) -> list[str]:
    """계약의 생성 명령(copier copy --trust --defaults --data pod_name=<pod>) — 하네스 venv의 copier로 돈다."""
    return [
        sys.executable,
        "-m",
        "copier",
        "copy",
        "--trust",
        "--defaults",
        "--quiet",
        "--data",
        f"pod_name={pod_name}",
        str(TEMPLATE_DIR),
        str(destination),
    ]
