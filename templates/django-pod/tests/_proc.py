"""하위 프로세스 실행 · 도구 해석 · 도구 출력 해석(T065 하네스).

- 모든 호출은 인자 목록 · shell=False · 명시 cwd · timeout · UTF-8 캡처(errors=replace)로 한다. 입력이 없으면 stdin은
  DEVNULL이다(자식이 질문을 기다리며 멈추지 않게).
- 도구가 없으면 skip이 아니라 pytest.fail이다 — 도구 부재는 test_fixtures_tools.py의 tool-N이 먼저 드러낸다.
- 자식 env = os.environ 복사에서 VIRTUAL_ENV를 지우고 PYTHONIOENCODING=utf-8을 넣는다. uv run은 하네스 venv를
  VIRTUAL_ENV로 넘기는데, 그대로 다른 프로젝트(생성물)에 uv를 돌리면 "VIRTUAL_ENV … does not match the project
  environment" 경고가 난다.
- 실패 메시지 = 명령 요약 · cwd · exit · 소요 시간 · stdout/stderr 꼬리(각 4000자). 비밀을 찍는 명령은 없다(생성물
  pytest는 자기 addopts의 --tb=short로 돈다).
"""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, NoReturn

import pytest

TAIL_CHARS = 4000


@dataclass(frozen=True)
class ProcResult:
    """하위 프로세스 한 번의 결과. returncode None = 시간 초과 또는 실행 자체 실패."""

    argv: tuple[str, ...]
    cwd: str
    returncode: int | None
    stdout: str
    stderr: str
    seconds: float

    @property
    def ok(self) -> bool:
        return self.returncode == 0


# ---------- 도구 해석 ----------


def find_uv() -> str | None:
    return os.environ.get("UV") or shutil.which("uv")


def find_docker() -> str | None:
    return shutil.which("docker")


def find_kustomize() -> str | None:
    return os.environ.get("JT_KUSTOMIZE") or shutil.which("kustomize")


def find_kubeconform() -> str | None:
    return os.environ.get("JT_KUBECONFORM") or shutil.which("kubeconform")


_FINDERS: dict[str, tuple[Callable[[], str | None], str]] = {
    "uv": (find_uv, "환경 변수 UV 또는 PATH의 uv"),
    "docker": (find_docker, "PATH의 docker"),
    "kustomize": (find_kustomize, "환경 변수 JT_KUSTOMIZE 또는 PATH의 kustomize"),
    "kubeconform": (find_kubeconform, "환경 변수 JT_KUBECONFORM 또는 PATH의 kubeconform"),
}


def require_tool(name: str) -> str:
    """도구의 실행 파일 경로. 없으면 pytest.fail(skip 금지 — 도구 없이는 판정할 수 없다)."""
    finder, where = _FINDERS[name]
    path = finder()
    if not path:
        pytest.fail(
            f"도구 {name}를 찾지 못했다({where}) — skip하지 않는다: 하네스는 이 도구 없이 판정할 수 없다",
            pytrace=False,
        )
    return path


# ---------- 실행 ----------


def child_env() -> dict[str, str]:
    env = dict(os.environ)
    env.pop("VIRTUAL_ENV", None)
    env["PYTHONIOENCODING"] = "utf-8"
    return env


def _as_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def run(
    argv: Sequence[str | os.PathLike[str]],
    *,
    cwd: str | os.PathLike[str],
    timeout: float,
    input_text: str | None = None,
) -> ProcResult:
    """argv를 shell 없이 실행한다. 실패해도 예외를 던지지 않고 ProcResult로 돌려준다(판정은 호출자 몫)."""
    args = tuple(str(part) for part in argv)
    kwargs: dict[str, Any] = {
        "cwd": str(cwd),
        "env": child_env(),
        "capture_output": True,
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "timeout": timeout,
        "shell": False,
        "check": False,
    }
    if input_text is None:
        kwargs["stdin"] = subprocess.DEVNULL
    else:
        kwargs["input"] = input_text
    started = time.monotonic()
    try:
        completed = subprocess.run(list(args), **kwargs)
    except subprocess.TimeoutExpired as exc:
        return ProcResult(
            args,
            str(cwd),
            None,
            _as_text(exc.stdout),
            _as_text(exc.stderr) + f"\n[하네스] 시간 초과({timeout} s) — 프로세스를 끝냈다",
            time.monotonic() - started,
        )
    except OSError as exc:
        return ProcResult(args, str(cwd), None, "", f"[하네스] 실행 실패: {exc!r}", time.monotonic() - started)
    return ProcResult(
        args,
        str(cwd),
        completed.returncode,
        completed.stdout or "",
        completed.stderr or "",
        time.monotonic() - started,
    )


def tail(text: str, limit: int = TAIL_CHARS) -> str:
    if len(text) <= limit:
        return text
    return f"…(앞 {len(text) - limit}자 생략)\n" + text[-limit:]


def describe(result: ProcResult, why: str) -> str:
    code = "없음(시간 초과 또는 실행 실패)" if result.returncode is None else str(result.returncode)
    return (
        f"{why}\n"
        f"명령: {shlex.join(result.argv)}\n"
        f"cwd: {result.cwd}\n"
        f"exit: {code} · {result.seconds:.1f} s\n"
        f"--- stdout 꼬리 ---\n{tail(result.stdout)}\n"
        f"--- stderr 꼬리 ---\n{tail(result.stderr)}"
    )


def fail_with(result: ProcResult, why: str) -> NoReturn:
    pytest.fail(describe(result, why), pytrace=False)


# ---------- 도구 출력 해석 ----------

_VERSION_RE = re.compile(r"(\d+)\.(\d+)(?:\.(\d+))?")


def parse_version(text: str) -> tuple[int, ...] | None:
    """출력에서 처음 나오는 x.y[.z]를 정수 튜플로(예: "uv 0.12.6 (…)" → (0, 12, 6) · "v5.8.1" → (5, 8, 1))."""
    match = _VERSION_RE.search(text)
    if match is None:
        return None
    return tuple(int(group) for group in match.groups() if group is not None)


def buildx_platforms(text: str) -> set[str]:
    """docker buildx inspect 출력의 Platforms 줄들 → 플랫폼 집합(명시 설정 표시 * 는 뗀다)."""
    platforms: set[str] = set()
    for line in text.splitlines():
        key, sep, value = line.partition(":")
        if sep and key.strip() == "Platforms":
            for item in value.split(","):
                item = item.strip().rstrip("*")
                if item:
                    platforms.add(item)
    return platforms


@dataclass(frozen=True)
class JunitCounts:
    tests: int
    failures: int
    errors: int
    skipped: int


def junit_counts(root: ET.Element) -> tuple[JunitCounts | None, str | None]:
    """pytest junit XML(testsuites > testsuite 또는 testsuite 단독)의 합계. 읽지 못하면 (None, 이유)."""
    if root.tag == "testsuite":
        suites = [root]
    elif root.tag == "testsuites":
        suites = root.findall("testsuite")
    else:
        suites = []
    if not suites:
        return None, f"testsuite 요소가 없다(루트 {root.tag!r})"
    totals = dict.fromkeys(("tests", "failures", "errors", "skipped"), 0)
    for suite in suites:
        for key in totals:
            raw = suite.get(key, "0")
            try:
                totals[key] += int(raw)
            except ValueError:
                return None, f"testsuite {key}={raw!r}를 정수로 읽지 못했다"
    return JunitCounts(**totals), None


def read_junit(path: Path) -> tuple[JunitCounts | None, str | None]:
    if not path.is_file():
        return None, f"junit 파일이 없다: {path}"
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        return None, f"junit 파싱 실패: {exc}"
    return junit_counts(root)


_KUBECONFORM_SUMMARY_RE = re.compile(
    r"Summary: (\d+) resources? found .* Valid: (\d+), Invalid: (\d+), Errors: (\d+), Skipped: (\d+)"
)


@dataclass(frozen=True)
class KubeconformSummary:
    resources: int
    valid: int
    invalid: int
    errors: int
    skipped: int


def parse_kubeconform_summary(text: str) -> KubeconformSummary | None:
    """kubeconform -summary의 마지막 요약 줄. 0.8 형식: "Summary: N resource(s) found parsing stdin - Valid: …"."""
    matches = _KUBECONFORM_SUMMARY_RE.findall(text)
    if not matches:
        return None
    resources, valid, invalid, errors, skipped = (int(value) for value in matches[-1])
    return KubeconformSummary(resources, valid, invalid, errors, skipped)


IMAGE_INSPECT_FORMAT = "{{.Architecture}} {{.Os}} {{.Config.User}}"
ROOT_USERS = frozenset({"", "root", "0"})


@dataclass(frozen=True)
class ImageFacts:
    architecture: str
    os: str
    user: str


def parse_image_inspect(text: str) -> ImageFacts | None:
    """docker image inspect --format IMAGE_INSPECT_FORMAT 출력 → (아키텍처, OS, USER). USER가 비면 ""."""
    lines = text.strip().splitlines()
    if not lines:
        return None
    parts = lines[0].split(" ", 2)
    if len(parts) < 2:
        return None
    user = parts[2].strip() if len(parts) > 2 else ""
    return ImageFacts(parts[0], parts[1], user)


def is_root_user(user: str) -> bool:
    """Dockerfile USER 값이 root인가 — 빈 값(기본 root) · root · 0, 그룹을 붙인 꼴(0:0 · root:root)도 root다."""
    return user.strip().split(":", 1)[0] in ROOT_USERS


# ---------- 단계 픽스처의 결과(conftest.py가 만든다) ----------


@dataclass(frozen=True)
class PodSuite:
    """생성물 pytest 한 번 — 실패해도 픽스처는 실패하지 않고 gen-5가 판정한다."""

    proc: ProcResult
    counts: JunitCounts | None
    junit_problem: str | None


@dataclass(frozen=True)
class Rendered:
    """kustomize build deploy/base 출력 — 원문과 문서 목록(빈 문서 제외)."""

    proc: ProcResult
    text: str
    docs: list[dict[str, Any]]


@dataclass(frozen=True)
class KubeconformRun:
    proc: ProcResult
    summary: KubeconformSummary
