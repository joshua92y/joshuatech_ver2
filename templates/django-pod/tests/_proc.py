"""하위 프로세스 실행 · 도구 해석 · 도구 출력 해석(T065 하네스).

- 모든 호출은 인자 목록 · shell=False · 명시 cwd · timeout · UTF-8 캡처(errors=replace)로 한다. 입력이 없으면 stdin은
  DEVNULL이다(자식이 질문을 기다리며 멈추지 않게).
- 도구가 없으면 skip이 아니라 pytest.fail이다 — 도구 부재는 test_fixtures_tools.py의 tool-N이 먼저 드러낸다.
- 자식 env = os.environ 복사에서 VIRTUAL_ENV를 지우고 PYTHONIOENCODING=utf-8을 넣는다. uv run은 하네스 venv를
  VIRTUAL_ENV로 넘기는데, 그대로 다른 프로젝트(생성물)에 uv를 돌리면 "VIRTUAL_ENV … does not match the project
  environment" 경고가 난다.
- 실패 메시지 = 명령 요약 · cwd · exit · 소요 시간 · stdout/stderr 꼬리(각 4000자). 비밀을 찍는 명령은 없다(생성물
  pytest는 자기 addopts의 --tb=short로 돈다).
- 자식 env 덧붙이기(T072): run(..., env={이름: 값 | None})은 위 자식 env 위에 값을 덮고 None이면 지운다. 비밀 값은 명령
  인자가 아니라 이 env로 넘긴다(docker run -e <이름> — 실패 메시지의 명령 요약에 값이 찍히지 않게). 실패 출력 · env를 싣는 탐침
  자식(T072 ③ r2 — gen-35 · gen-37)은 env=allowlist_env(…)로 허용 목록 이름만 물려받는다(누출 탐침 위생).
- docker 도우미(T072 gen-33 · 34): 컨테이너는 이름(jt-smoke-…)과 레이블(jt.harness=t072-smoke · jt.session=<세션> ·
  jt.created=<유닉스 초>)을 붙여 띄우고 끝에 docker rm -f -v + 사라짐 확인을 한다(remove_container · cleanup_container).
  하네스가 이름 · 레이블을 붙이지 않은 컨테이너는 건드리지 않는다. 이전 세션이 남긴 컨테이너는 같은 레이블 + 이름 접두로만
  찾아, 다른 세션이면서 30분보다 오래됐거나 jt.created가 없거나 읽을 수 없는 것만 지운다 — 젊은 다른 세션 컨테이너는 동시에
  도는 하네스의 것일 수 있어 지우지 않고 문제로 알린다(sweep_stale_smoke_containers · T072 r3 F5 · 하네스 동시 실행 금지).
- 시간 상한(T072 r2 E12 · r1 B-6): run()은 Popen으로 띄우고, 시간 초과면 프로세스 트리를 끝낸다(Windows taskkill /T /F ·
  POSIX start_new_session + killpg) — 그 뒤 KILL_COMMUNICATE_SECONDS 안에 출력을 거두고, 그래도 막히면 출력 없이 끝낸다.
  한계: Windows에서 자식이 먼저 끝나고 손자만 파이프를 쥐면 taskkill /T가 손자를 찾지 못한다(부모 PID가 끊긴다) — 그때도
  run()은 KILL_COMMUNICATE_SECONDS 뒤 돌아오지만 손자는 남을 수 있다. 같은 이유로 Ctrl+C(KeyboardInterrupt)를 받으면 트리를
  끝낸 뒤 예외를 다시 올린다.
- 시간 예산(T072 r2 E13 · r1 B-7): env JT_HARNESS_BUDGET_SECONDS(양의 초 · 없으면 예산 없음 — CI 값은 조각 ④가 정한다)가
  있으면 run()은 min(timeout, 세션 남은 예산)을 쓰고, 예산이 없으면 실행하지 않고 실패를 돌려준다. 정리 호출(rm -f · 사라짐
  확인)은 use_budget=False로 예산 밖에서 자기 시간 상한의 총합(REMOVE_TOTAL_SECONDS)을 쓴다 — 시간 초과로 끝난 호출의 트리
  종료 · 출력 수거 시간은 그 밖이다(실제 최악은 remove_container 독스트링 · T072 r3 F4). 단계 픽스처는 harness_stage로 시작 ·
  끝을 <미니 저장소 루트>/harness-stages.log(ASCII 한 줄씩)에 남기고 실패 메시지에 단계 이름을 싣는다.
"""

from __future__ import annotations

import json
import os
import re
import secrets
import shlex
import shutil
import signal
import subprocess
import time
import uuid
import xml.etree.ElementTree as ET
from collections.abc import Callable, Iterator, Mapping, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, NoReturn

import pytest

TAIL_CHARS = 4000
# 시간 초과 뒤 트리를 끝내고 출력을 거두는 상한 · taskkill 자체의 상한(E12)
KILL_COMMUNICATE_SECONDS = 10
TREE_KILL_TIMEOUT = 30
# 세션 시간 예산(E13) — 시작 시각은 이 모듈을 처음 적재한 때(= pytest 수집)다
BUDGET_ENV = "JT_HARNESS_BUDGET_SECONDS"
HARNESS_STARTED = time.monotonic()
_BUDGET_RE = re.compile(r"[0-9]+(?:\.[0-9]+)?")
# 생성물 pytest를 도는 호출(pod_pytest · gen-5 · gen-32 수집)이 물려받지 않을 env(E10 · r1 B-4) — PYTEST_ADDOPTS는 명령줄
# 앞에 붙어 -l · -o junit_logging=all · -k로 --tb=short · --show-capture=no 방어선과 skip 0 판정을 비켜 가고, PYTHONOPTIMIZE는
# 단언 재작성 밖 도우미의 assert를 지운다(규칙 §Tests). DJANGO_SETTINGS_MODULE · DJANGO_CONFIGURATION(T072 ② r2 H9 · B-1)은
# pytest-django가 ini보다 앞에 읽는다 — 셸 값이 시험 래퍼(tests.settings)를 비켜 가지 않게(생성물 addopts --ds와 conftest 가드에도
# 기대지 않는 방어선).
POD_PYTEST_ENV: dict[str, str | None] = dict.fromkeys(
    (
        "PYTEST_ADDOPTS",
        "PYTEST_PLUGINS",
        "PYTHONOPTIMIZE",
        "PYTHONINSPECT",
        "PYTHONSTARTUP",
        "PYTHONPATH",
        "DJANGO_SETTINGS_MODULE",
        "DJANGO_CONFIGURATION",
    )
)


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


def child_env(extra: Mapping[str, str | None] | None = None) -> dict[str, str]:
    """os.environ 복사 − VIRTUAL_ENV + PYTHONIOENCODING=utf-8, 그 위에 extra(값 None = 지운다)."""
    env = dict(os.environ)
    env.pop("VIRTUAL_ENV", None)
    env["PYTHONIOENCODING"] = "utf-8"
    for key, value in (extra or {}).items():
        if value is None:
            env.pop(key, None)
        else:
            env[key] = value
    return env


# 허용 목록 env(T072 ③ r2 — 누출 탐침 위생 · 조각 ② r3 교훈: 출력을 기록하는 탐침에 실제 process env 전체를 물려주자 세션 토큰이 로그에
# 실렸다). 실패 출력 · env를 싣는 탐침 자식(gen-35 docker compose config · gen-37 앱 라벨 탐침)에는 OS · 도구 실행에 필요한 이름만 남긴다 —
# 토큰 · 셸 비밀 · 그 탐침의 판정을 바꾸는 이름(COMPOSE_* · JT_DEV_*_PORT · POSTGRES_PASSWORD · DJANGO_* · PYTHONPATH)은 가지 않는다.
# 이름은 대문자로 견준다(Windows env는 대소문자를 가리지 않는다). PYTHONIOENCODING은 child_env가 utf-8로 덮는다.
ALLOWED_CHILD_ENV = frozenset(
    {
        "PATH",
        "PATHEXT",
        "SYSTEMROOT",
        "SYSTEMDRIVE",
        "WINDIR",
        "COMSPEC",
        "TEMP",
        "TMP",
        "TMPDIR",
        "HOME",
        "USERPROFILE",
        "HOMEDRIVE",
        "HOMEPATH",
        "APPDATA",
        "LOCALAPPDATA",
        "PROGRAMDATA",
        "PROGRAMFILES",
        "PROGRAMFILES(X86)",
        "PROGRAMW6432",
        "COMMONPROGRAMFILES",
        "COMMONPROGRAMFILES(X86)",
        "COMMONPROGRAMW6432",
        "ALLUSERSPROFILE",
        "PUBLIC",
        "USERNAME",
        "USER",
        "LOGNAME",
        "LANG",
        "LC_ALL",
        "LC_CTYPE",
        "TZ",
        "NUMBER_OF_PROCESSORS",
        "PROCESSOR_ARCHITECTURE",
        "OS",
        "XDG_RUNTIME_DIR",
        "XDG_CONFIG_HOME",
        "XDG_CACHE_HOME",
        "XDG_DATA_HOME",
        "DOCKER_HOST",
        "DOCKER_CONTEXT",
        "DOCKER_CONFIG",
        "DOCKER_CERT_PATH",
        "DOCKER_TLS_VERIFY",
        "PYTHONIOENCODING",
    }
)


def allowlist_env(extra: Mapping[str, str] | None = None) -> dict[str, str | None]:
    """run(env=…)에 넘길 덮어쓰기 — 지금 process env에서 ALLOWED_CHILD_ENV 밖의 이름을 전부 지우고(None) extra(고정 · 심은 가짜 값)를
    더한다."""
    overlay: dict[str, str | None] = {name: None for name in os.environ if name.upper() not in ALLOWED_CHILD_ENV}
    overlay.update(extra or {})
    return overlay


def _as_text(value: str | bytes | None) -> str:
    if value is None:
        return ""
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return value


def _budget_seconds() -> float | None:
    """env JT_HARNESS_BUDGET_SECONDS → 양의 초(없거나 빈 값이면 None). 다른 값은 설정 오류로 pytest.fail."""
    raw = os.environ.get(BUDGET_ENV, "").strip()
    if not raw:
        return None
    if _BUDGET_RE.fullmatch(raw) is None or float(raw) <= 0:
        pytest.fail(f"{BUDGET_ENV}={raw!r}: 양의 초 수(예: 3000)가 아니다 — 하네스 시간 예산 설정 오류", pytrace=False)
    return float(raw)


def budget_timeout(timeout: float) -> float:
    """호출의 실제 상한 = min(timeout, 세션 남은 예산). 예산 env가 없으면 timeout 그대로. 0 이하 = 예산 소진."""
    budget = _budget_seconds()
    if budget is None:
        return timeout
    return min(timeout, budget - (time.monotonic() - HARNESS_STARTED))


def _kill_tree(process: subprocess.Popen[str]) -> str:
    """시간 초과 · 인터럽트 때 자식과 그 자손을 끝낸다 — Windows taskkill /T /F(부모 PID 사슬) · POSIX killpg(새 세션의
    프로세스 그룹). 실패해도 예외를 던지지 않고 메모를 돌려준다(마지막으로 자식 자신을 kill)."""
    note = ""
    if os.name == "nt":
        try:
            killed = subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(process.pid)],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=TREE_KILL_TIMEOUT,
                check=False,
            )
            if killed.returncode != 0:
                note = f"taskkill exit {killed.returncode}"
        except (OSError, subprocess.TimeoutExpired) as exc:
            note = f"taskkill 실패: {type(exc).__name__}"
    else:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError) as exc:
            note = f"killpg 실패: {type(exc).__name__}"
    try:
        process.kill()
    except OSError:
        pass
    return note


def run(
    argv: Sequence[str | os.PathLike[str]],
    *,
    cwd: str | os.PathLike[str],
    timeout: float,
    input_text: str | None = None,
    env: Mapping[str, str | None] | None = None,
    use_budget: bool = True,
) -> ProcResult:
    """argv를 shell 없이 실행한다. 실패해도 예외를 던지지 않고 ProcResult로 돌려준다(판정은 호출자 몫).
    env = 자식 env에 덮을 값(None = 지운다 — child_env). use_budget=False = 세션 시간 예산 밖(정리 호출 — 자기 상한).
    시간 초과(E12): 프로세스 트리를 끝내고 KILL_COMMUNICATE_SECONDS 안에 출력을 거둔다 — 최악 소요 ≈ 상한 +
    TREE_KILL_TIMEOUT + KILL_COMMUNICATE_SECONDS. 그 안에 파이프가 닫히지 않으면(손자가 쥐고 있다) 출력 없이 끝낸다."""
    args = tuple(str(part) for part in argv)
    limit = budget_timeout(timeout) if use_budget else timeout
    started = time.monotonic()
    if limit <= 0:
        return ProcResult(args, str(cwd), None, "", f"[하네스] 시간 예산({BUDGET_ENV}) 소진 — 실행하지 않았다", 0.0)
    why = f"{limit:.0f} s — 세션 시간 예산({BUDGET_ENV})의 남은 시간" if limit < timeout else f"{timeout} s"
    kwargs: dict[str, Any] = {
        "cwd": str(cwd),
        "env": child_env(env),
        "stdin": subprocess.DEVNULL if input_text is None else subprocess.PIPE,
        "stdout": subprocess.PIPE,
        "stderr": subprocess.PIPE,
        "text": True,
        "encoding": "utf-8",
        "errors": "replace",
        "shell": False,
    }
    if os.name != "nt":
        kwargs["start_new_session"] = True  # killpg로 손자까지 끝낸다(Windows는 taskkill /T가 부모 PID 사슬을 따른다)
    try:
        process = subprocess.Popen(list(args), **kwargs)
    except OSError as exc:
        return ProcResult(args, str(cwd), None, "", f"[하네스] 실행 실패: {exc!r}", time.monotonic() - started)
    try:
        stdout, stderr = process.communicate(input=input_text, timeout=limit)
    except subprocess.TimeoutExpired:
        note = _kill_tree(process)
        try:
            stdout, stderr = process.communicate(timeout=KILL_COMMUNICATE_SECONDS)
            tail_note = f"\n[하네스] 시간 초과({why}) — 프로세스 트리를 끝냈다"
        except subprocess.TimeoutExpired:
            stdout, stderr = "", ""
            tail_note = (
                f"\n[하네스] 시간 초과({why}) — 프로세스 트리를 끝낸 뒤 {KILL_COMMUNICATE_SECONDS} s 안에 출력 파이프가 닫히지 "
                "않았다(손자 프로세스가 쥐고 있다) — 출력 없이 끝낸다"
            )
        if note:
            tail_note += f" ({note})"
        return ProcResult(args, str(cwd), None, _as_text(stdout), _as_text(stderr) + tail_note, time.monotonic() - started)
    except BaseException:
        _kill_tree(process)  # KeyboardInterrupt 등 — 자손을 남기지 않고 다시 올린다
        raise
    return ProcResult(args, str(cwd), process.returncode, stdout or "", stderr or "", time.monotonic() - started)


STAGE_LOG_NAME = "harness-stages.log"


def _utc_stamp() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def _stage_line(root: Path, text: str) -> None:
    """<root>/harness-stages.log에 한 줄(UTF-8 파일 · ASCII 내용 · LF). 기록 실패는 하네스를 멈추지 않는다."""
    line = f"{_utc_stamp()} {text}".encode("ascii", "replace").decode("ascii")
    try:
        with (root / STAGE_LOG_NAME).open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(line + "\n")
    except OSError:
        pass


def stage_note(root: Path, text: str) -> None:
    """단계 기록에 메모 한 줄(예: 이전 세션 컨테이너 정리 — 이름은 ASCII)."""
    _stage_line(root, f"note {text}")


@contextmanager
def harness_stage(root: Path, name: str) -> Iterator[str]:
    """단계 픽스처의 시작 · 끝을 기록한다(E13 · r1 B-7) — start <name> / end <name> ok|fail|interrupted|error <초>s. 값 =
    실패 메시지 머리에 붙일 이름표 '[단계 <name>]'(-q 출력만으로도 어느 단계에서 멈췄는지 남게)."""
    _stage_line(root, f"start {name}")
    started = time.monotonic()
    outcome = "error"
    try:
        yield f"[단계 {name}]"
        outcome = "ok"
    except pytest.fail.Exception:
        outcome = "fail"
        raise
    except (KeyboardInterrupt, SystemExit):
        outcome = "interrupted"
        raise
    finally:
        _stage_line(root, f"end {name} {outcome} {time.monotonic() - started:.1f}s")


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


# 하네스 탐침 스크립트(변형 settings · 이미지 · 컨테이너 안 HTTP)는 결과를 이 표식 + JSON 한 줄로 stdout에 낸다 — 같은
# stdout에 섞이는 구조 로그(configure_logging의 JSON 줄)와 가르려고.
PROBE_MARKER = "JT-PROBE "


def parse_probe_line(text: str) -> Any:
    """stdout의 마지막 표식 줄(JT-PROBE <JSON>) → JSON 값. 표식 줄이 없거나 JSON이 깨졌으면 None."""
    for line in reversed(text.splitlines()):
        if line.startswith(PROBE_MARKER):
            try:
                return json.loads(line[len(PROBE_MARKER) :])
            except json.JSONDecodeError:
                return None
    return None


def _probe_script(body: str) -> str:
    return body.replace("@MARKER@", PROBE_MARKER)


# 컨테이너 · 기본 pod venv 안에서 python -(표준 입력)으로 도는 탐침 스크립트(T072) — 명령 인자로 넘기지 않아 Windows 인자
# 따옴표 규칙과 무관하다. 각 스크립트는 결과를 JT-PROBE 줄 하나로 낸다(판정은 tests/_tree.py check_* · 호출자).

# 인자: URL [지표 접두] — HTTP 상태(HTTPError면 그 코드) · 예외 클래스 이름 · 접두로 시작하는 본문 줄 · body = 응답 본문
# (상한 1 MB · 오류 응답 포함 — T072 r2 E9: 호출자는 body를 누출 판정용 원문에만 넣고 출력하지 않는다)
HTTP_PROBE_SCRIPT = _probe_script(
    """\
import json
import sys
import urllib.error
import urllib.request

url = sys.argv[1]
prefix = sys.argv[2] if len(sys.argv) > 2 else ""
result = {"status": None, "error": None, "lines": [], "body": ""}
try:
    with urllib.request.urlopen(url, timeout=10) as response:
        result["status"] = response.status
        body = response.read(1000000).decode("utf-8", "replace")
        result["body"] = body
        if prefix:
            result["lines"] = [line for line in body.splitlines() if line.startswith(prefix)]
except urllib.error.HTTPError as exc:
    result["status"] = exc.code
    try:
        result["body"] = exc.read(1000000).decode("utf-8", "replace")
    except Exception as read_error:
        result["error"] = type(read_error).__name__
except Exception as exc:
    result["error"] = type(exc).__name__
print("@MARKER@" + json.dumps(result))
"""
)

# 인자: glob 꼴 — 맞는 경로 목록(정렬)
GLOB_PROBE_SCRIPT = _probe_script(
    """\
import glob
import json
import sys

print("@MARKER@" + json.dumps(sorted(glob.glob(sys.argv[1]))))
"""
)

# 이미지 빌드 감시 파일 이름(T072 조각 ③ 지시 5) — conftest.py image 픽스처가 빌드 직전 생성 pod의 .venv/ 안에 심고 빌드 뒤 지운다.
# 이미지의 /src/apps/<pod>/.venv에 있으면 빌드 컨텍스트의 .venv가 들어온 것이다(dockerignore **/.venv 재제외 실패 — D18).
IMAGE_VENV_SENTINEL = "jt-harness-sentinel"
# 이미지 탐침의 비밀 후보 이름(T072 ③ r2 M1 · 마지막 라운드 N6 · 마감 라운드 Z3): 이름의 소문자 형이 이 머리로 시작하거나 · 이 접미로
# 끝나거나 · 이 이름 그대로면 비밀 후보다 — dockerignore 재제외(tests/_tree.py DOCKERIGNORE_REEXCLUDE — 비밀 후보 꼴 열하나 모두 대소문자 무관
# 꼴 · 마감 라운드 Z3이 이름 꼴 다섯을 더했다)와 같은 집합이다(*.crt · *.p12 · *.pfx — 인증서 · PKCS#12 묶음은 개인 키를 품을 수 있다 ·
# id_* — SSH 개인 키 · *.env · .netrc — 자격 파일). 소문자로 견준다(③ r2 리뷰 B-1: CASE.PEM · .KEY · .Crt · .Env.prod가 대소문자를 가리는
# 옛 판정을 비켜 이미지에 실렸다 · 마지막 리뷰 B-1: 거르기가 이름 꼴의 대문자 변형 ID_RSA · LOCAL.ENV · .NETRC를 놓쳤다 — 값은 소문자 형 그대로다).
IMAGE_SENSITIVE_PREFIXES = (".env", "id_rsa", "id_ed25519", "id_ecdsa")
IMAGE_SENSITIVE_SUFFIXES = (".pem", ".key", ".crt", ".p12", ".pfx", ".env")
IMAGE_SENSITIVE_NAMES = (".netrc",)


def image_sensitive_name(name: str) -> bool:
    """파일 이름 하나가 이미지 탐침의 비밀 후보인가 — IMAGE_PROBE_SCRIPT 안의 판정과 같은 식(소문자 형 · 머리 · 접미 · 이름)."""
    lowered = name.lower()
    return (
        lowered.startswith(IMAGE_SENSITIVE_PREFIXES)
        or lowered.endswith(IMAGE_SENSITIVE_SUFFIXES)
        or lowered in IMAGE_SENSITIVE_NAMES
    )

# 이미지 venv에 없어야 하는 dev 전용 배포(T072 ③ r2 M3 · 계약 Dockerfile 행 uv sync --no-dev) — gen-2가 생성물 dependency-groups.dev에
# 요구하는 이름(tests/_tree.py DEV_REQUIREMENTS)과 같다
IMAGE_DEV_DISTRIBUTIONS = ("django-migration-linter", "pytest", "pytest-django", "testcontainers")

# 인자: pod 루트(/src/apps/<pod>) — gen-33 이미지 탐침(D18 · X27): uid · gid · 홈 netrc · Python 판 · django_common 위치 ·
# django-ninja 판 · /src/packages 유무 · pod 루트 아래(.venv 제외) 비밀 후보 이름(소문자 형 — IMAGE_SENSITIVE_PREFIXES · SUFFIXES · NAMES ·
# image_sensitive_name과 같은 식 · 마지막 라운드 N6) · pod 루트 최상위 항목
# 이름(정렬 — 읽지 못하면 null) · .venv 안 빌드 감시 파일 유무(T072 조각 ③ 지시 5) · venv에 설치된 dev 전용 배포(정렬 — T072 ③ r2 M3)
# — 판정은 tests/_tree.py check_image_probe
IMAGE_PROBE_SCRIPT = _probe_script(
    """\
import importlib.metadata
import json
import os
import sys
from pathlib import Path

pod_root = Path(sys.argv[1])
home = os.path.expanduser("~")
home = None if home == "~" else Path(home)
facts = {
    "uid": os.getuid() if hasattr(os, "getuid") else None,
    "gid": os.getgid() if hasattr(os, "getgid") else None,
    "home": None if home is None else str(home),
    "netrc": [name for name in (".netrc", "_netrc") if home is not None and (home / name).exists()],
    "python": list(sys.version_info[:3]),
    "prefix": sys.prefix,
    "django_common_file": None,
    "django_common_error": None,
    "ninja_version": None,
    "src_packages_exists": os.path.exists("/src/packages"),
    "sensitive_files": [],
    "pod_entries": None,
    "venv_sentinel": os.path.lexists(pod_root / ".venv" / "@VENV_SENTINEL@"),
}
try:
    import django_common

    facts["django_common_file"] = django_common.__file__
except Exception as exc:
    facts["django_common_error"] = type(exc).__name__
try:
    facts["ninja_version"] = importlib.metadata.version("django-ninja")
except importlib.metadata.PackageNotFoundError:
    pass
try:
    facts["pod_entries"] = sorted(entry.name for entry in os.scandir(pod_root))
except OSError:
    pass
sensitive = []
for current, dirnames, filenames in os.walk(pod_root):
    if Path(current) == pod_root:
        dirnames[:] = [name for name in dirnames if name != ".venv"]
    for name in filenames:
        lowered = name.lower()
        if lowered.startswith(@SENSITIVE_PREFIXES@) or lowered.endswith(@SENSITIVE_SUFFIXES@) or lowered in @SENSITIVE_NAMES@:
            sensitive.append((Path(current) / name).relative_to(pod_root).as_posix())
facts["sensitive_files"] = sorted(sensitive)
dev = []
for name in @DEV_DISTRIBUTIONS@:
    try:
        importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        continue
    dev.append(name)
facts["dev_distributions"] = sorted(dev)
print("@MARKER@" + json.dumps(facts))
"""
).replace("@VENV_SENTINEL@", IMAGE_VENV_SENTINEL).replace("@SENSITIVE_PREFIXES@", repr(IMAGE_SENSITIVE_PREFIXES)).replace(
    "@SENSITIVE_SUFFIXES@", repr(IMAGE_SENSITIVE_SUFFIXES)
).replace("@SENSITIVE_NAMES@", repr(IMAGE_SENSITIVE_NAMES)).replace("@DEV_DISTRIBUTIONS@", repr(IMAGE_DEV_DISTRIBUTIONS))

# 인자 없음 · cwd = 변형 트리 · DJANGO_SETTINGS_MODULE = tests.settings — gen-32 변형 settings 탐침(X10): django.setup() +
# ROOT_URLCONF(있으면 ADMIN_URLCONF도) import 뒤 celery import 여부 · INSTALLED_APPS · MIDDLEWARE · TEMPLATES 수 ·
# ADMIN_URLCONF 유무
SETTINGS_PROBE_SCRIPT = _probe_script(
    """\
import importlib
import json
import sys

import django

django.setup()
from django.conf import settings

importlib.import_module(settings.ROOT_URLCONF)
if getattr(settings, "ADMIN_URLCONF", None):
    importlib.import_module(settings.ADMIN_URLCONF)
facts = {
    "celery_imported": "celery" in sys.modules,
    "installed_apps": [str(app) for app in settings.INSTALLED_APPS],
    "middleware": [str(item) for item in settings.MIDDLEWARE],
    "templates": len(settings.TEMPLATES),
    "has_admin_urlconf": hasattr(settings, "ADMIN_URLCONF"),
}
print("@MARKER@" + json.dumps(facts))
"""
)

# 인자 없음 · cwd = 생성 pod · DJANGO_SETTINGS_MODULE = tests.settings — gen-37 앱 라벨 탐침(T072 ③ r2 M11): django.setup() 뒤
# get_app_configs()의 라벨(순서 그대로 — 판정은 tests/_tree.py check_reserved_pod_names)
APP_LABELS_PROBE_SCRIPT = _probe_script(
    """\
import json

import django

django.setup()
from django.apps import apps

print("@MARKER@" + json.dumps([config.label for config in apps.get_app_configs()]))
"""
)


def metric_samples(text: str, name: str) -> list[str]:
    """Prometheus 텍스트 노출에서 지표 name의 표본 줄(# HELP · # TYPE 주석 제외 · 이름이 정확히 같은 것 —
    name{…} 또는 name 값)."""
    return [line for line in text.splitlines() if line.startswith((f"{name}{{", f"{name} "))]


def parse_container_state(text: str) -> tuple[str | None, int | None]:
    """docker container inspect --format CONTAINER_STATE_FORMAT 출력 → (State.Status, State.ExitCode). 못 읽으면 (None, None)."""
    parts = text.split()
    if len(parts) != 2 or not parts[1].lstrip("-").isdigit():
        return None, None
    return parts[0], int(parts[1])


# ---------- docker 컨테이너 도우미(T072 gen-33 · gen-34) ----------

IMAGE_PLATFORM = "linux/arm64"
CONTAINER_STATE_FORMAT = "{{.State.Status}} {{.State.ExitCode}}"
DOCKER_CALL_TIMEOUT = 120
SMOKE_CONTAINER_PREFIX = "jt-smoke-"
# 레이블(E11 · r1 B-5 · r3 F5): 하네스 컨테이너 표시 + 이 세션(프로세스)의 uuid + 만든 시각(유닉스 초) — 다음 세션이 남은
# 것을 찾아 오래된 것만 지운다
HARNESS_LABEL_KEY = "jt.harness"
SESSION_LABEL_KEY = "jt.session"
CREATED_LABEL_KEY = "jt.created"
SMOKE_HARNESS_LABEL = "t072-smoke"
HARNESS_SESSION = uuid.uuid4().hex
# 쓸기 문턱(r3 F5 · r2 B-1): 이보다 오래된 다른 세션 컨테이너만 지운다 — 스모크 컨테이너 하나의 최악 수명(docker run · 대기
# 180 s · 탐침 · 로그 · 정리 상한과 시간 초과 오버헤드의 합 ≈ 20분)보다 넉넉히. 그보다 젊으면 동시에 도는 다른 세션의 살아 있는
# 컨테이너일 수 있다.
SMOKE_STALE_AFTER_SECONDS = 30 * 60
# 정리(E11 · E13): rm -f -v 뒤 사라짐 확인의 시간 상한 총합(시간 초과 호출의 트리 종료 · 수거 몫은 그 밖 — remove_container) ·
# docker run 시간 초과 뒤 늦게 생긴 컨테이너를 다시 지우기 전 대기
REMOVE_TOTAL_SECONDS = 60
REMOVE_POLL_SECONDS = 1
LATE_REMOVE_DELAY_SECONDS = 5
# 대기(wait_until)가 각 호출에 주는 상한의 하한(남은 시간이 이보다 짧아도 호출 하나는 이만큼 기다릴 수 있다)
WAIT_CALL_FLOOR_SECONDS = 1


def smoke_container_name(kind: str) -> str:
    """하네스가 띄우는 컨테이너 이름 jt-smoke-<kind>-<난수 8 hex> — 정리(remove_container)는 이 이름만 지운다."""
    return f"{SMOKE_CONTAINER_PREFIX}{kind}-{secrets.token_hex(4)}"


def docker_run_argv(
    docker: str,
    image: str,
    name: str,
    *,
    command: Sequence[str] = (),
    detach: bool = False,
    interactive: bool = False,
    entrypoint: str | None = None,
    env_args: Sequence[str] = (),
) -> list[str]:
    """이미지 탐침 · 기동 스모크의 docker run 인자(D21 gen-33 · 34) — 이름(정리용) · 레이블 jt.harness=t072-smoke ·
    jt.session=<세션> · jt.created=<지금 유닉스 초>(남은 컨테이너 쓸기용 — E11 · r3 F5) · arm64 · --network none · --read-only ·
    --tmpfs /tmp · capability 전부 버림 · no-new-privileges(운영 securityContext와 같은 쪽). 이미지 USER를 그대로 쓴다(--user
    없음). detach면 -d(로그를 남기려고 --rm 없이 — 정리는 cleanup_container), 아니면 --rm."""
    argv = [
        docker,
        "run",
        "--name",
        name,
        "--label",
        f"{HARNESS_LABEL_KEY}={SMOKE_HARNESS_LABEL}",
        "--label",
        f"{SESSION_LABEL_KEY}={HARNESS_SESSION}",
        "--label",
        f"{CREATED_LABEL_KEY}={int(time.time())}",
        "--platform",
        IMAGE_PLATFORM,
        "--network",
        "none",
        "--read-only",
        "--tmpfs",
        "/tmp",
        "--cap-drop",
        "ALL",
        "--security-opt",
        "no-new-privileges",
        "-d" if detach else "--rm",
    ]
    if interactive:
        argv.append("-i")
    if entrypoint is not None:
        argv += ["--entrypoint", entrypoint]
    argv += list(env_args)
    argv.append(image)
    argv += list(command)
    return argv


def container_state(
    docker: str, name: str, *, cwd: str | os.PathLike[str], timeout: float = DOCKER_CALL_TIMEOUT
) -> tuple[str | None, int | None]:
    """컨테이너의 (상태, 종료 코드) — 없거나 못 읽으면 (None, None)."""
    result = run([docker, "container", "inspect", "--format", CONTAINER_STATE_FORMAT, name], cwd=cwd, timeout=timeout)
    if not result.ok:
        return None, None
    return parse_container_state(result.stdout)


def remove_container(
    docker: str, name: str, *, cwd: str | os.PathLike[str], total_seconds: float = REMOVE_TOTAL_SECONDS
) -> str | None:
    """docker rm -f -v <name>(익명 볼륨까지) 뒤 그 컨테이너가 사라졌는지 확인한다 — 사라졌으면 None, 아니면 문제 한 줄(정리
    확인). --rm 컨테이너가 이미 지워졌으면 rm -f가 실패해도 괜찮다(확인만 본다). 세션 시간 예산 밖이다(use_budget=False).
    시간(E13 · T072 r3 F4 · r2 A-4): 호출마다 남은 시간(하한 WAIT_CALL_FLOOR_SECONDS)을 상한으로 넘기므로 호출들이 시간 상한
    안에서 쓰는 시간은 모두 합쳐 total_seconds + WAIT_CALL_FLOOR_SECONDS 안이다. 시간 초과로 끝난 호출은 run()이 그 뒤 트리
    종료(Windows taskkill — 상한 TREE_KILL_TIMEOUT)와 출력 수거(KILL_COMMUNICATE_SECONDS)를 더 쓰고, 그런 호출은 많아야
    둘(rm · 마지막 inspect)이다 — 실제 최악 ≈ total_seconds + WAIT_CALL_FLOOR_SECONDS + 2 × (TREE_KILL_TIMEOUT +
    KILL_COMMUNICATE_SECONDS), 기본값으로 Windows ≈ 141 s · POSIX ≈ 81 s(POSIX는 killpg라 taskkill 몫이 없다)."""
    deadline = time.monotonic() + total_seconds

    def remaining() -> float:
        return max(deadline - time.monotonic(), WAIT_CALL_FLOOR_SECONDS)

    run([docker, "rm", "-f", "-v", name], cwd=cwd, timeout=min(DOCKER_CALL_TIMEOUT, remaining()), use_budget=False)
    last = ""
    while True:
        probe = run(
            [docker, "container", "inspect", "--format", "{{.Id}}", name],
            cwd=cwd,
            timeout=min(DOCKER_CALL_TIMEOUT, remaining()),
            use_budget=False,
        )
        if probe.returncode not in (0, None) and "no such" in (probe.stdout + probe.stderr).lower():
            return None
        last = (probe.stderr or probe.stdout).strip()[-300:]
        if time.monotonic() + REMOVE_POLL_SECONDS >= deadline:
            break
        time.sleep(REMOVE_POLL_SECONDS)
    return f"컨테이너 {name}가 docker rm -f -v 뒤에도 남아 있다(정리 확인 실패 · {total_seconds:g} s — 마지막 inspect: {last!r})"


def cleanup_container(docker: str, name: str, *, cwd: str | os.PathLike[str], run_timed_out: bool) -> list[str]:
    """remove_container + docker run이 시간 초과로 끝났으면 LATE_REMOVE_DELAY_SECONDS 뒤 한 번 더(E11 · r1 B-5 — CLI가 죽은
    뒤 데몬이 컨테이너를 만들면 첫 확인은 'No such'를 보고 지나간다). 문제 줄 목록(빈 목록 = 정리 확인).
    시간(T072 r3 F4): remove_container 한 번의 실제 최악(기본값 Windows ≈ 141 s · POSIX ≈ 81 s — 시간 상한 합 + 시간 초과
    호출마다 트리 종료 · 출력 수거)에, run_timed_out이면 LATE_REMOVE_DELAY_SECONDS와 같은 최악이 한 번 더 붙는다 — Windows
    ≈ 287 s · POSIX ≈ 167 s."""
    problems = [problem for problem in (remove_container(docker, name, cwd=cwd),) if problem]
    if run_timed_out:
        time.sleep(LATE_REMOVE_DELAY_SECONDS)
        late = remove_container(docker, name, cwd=cwd)
        if late:
            problems.append(late)
    return problems


# docker ps 줄 = id · 이름 · jt.session · jt.created를 탭으로 가른 4열(r3 F5 — 빈 레이블도 빈 칸으로 자리를 지킨다: 공백
# 가르기는 빈 jt.session 뒤의 jt.created를 세션으로 읽는다)
SMOKE_PS_FORMAT = "\t".join(
    ("{{.ID}}", "{{.Names}}", '{{.Label "' + SESSION_LABEL_KEY + '"}}', '{{.Label "' + CREATED_LABEL_KEY + '"}}')
)
_CONTAINER_ID_RE = re.compile(r"[0-9a-f]+")
_CREATED_RE = re.compile(r"[0-9]{1,15}")


def _foreign_smoke_rows(text: str, session: str, now: float) -> list[tuple[str, str, int | None]]:
    """docker ps -a --filter label=jt.harness=t072-smoke --format SMOKE_PS_FORMAT 출력 → 다른 세션(jt.session이 현재 세션과
    다르거나 빈 값)의 하네스 스모크 행 (id, 이름, 나이 초 — jt.created가 없거나 읽을 수 없으면 None · 미래 시각이면 음수).
    현재 세션 행 · 이름이 jt-smoke-로 시작하지 않는 행 · 열이 2–4개가 아니거나 id가 16진 소문자가 아닌 행(읽지 못하는 줄)은
    내지 않는다 — 건드리지 않는다(레이블 + 이름 둘 다 · id가 '-'로 시작해 docker 옵션으로 읽히는 일도 없다)."""
    rows: list[tuple[str, str, int | None]] = []
    for line in text.splitlines():
        parts = [part.strip() for part in line.split("\t")]
        if not 2 <= len(parts) <= 4:
            continue
        container_id, name, row_session, created = (*parts, "", "")[:4]
        if _CONTAINER_ID_RE.fullmatch(container_id) is None or not name.startswith(SMOKE_CONTAINER_PREFIX):
            continue
        if row_session == session:
            continue
        age = int(now) - int(created) if _CREATED_RE.fullmatch(created) else None
        rows.append((container_id, name, age))
    return rows


def stale_smoke_containers(text: str, session: str, *, now: float | None = None) -> list[tuple[str, str]]:
    """지울 (id, 이름) — 다른 세션 행 가운데 jt.created가 없거나 읽을 수 없거나 SMOKE_STALE_AFTER_SECONDS보다 오래된 것(T072
    r3 F5 · r2 B-1). now = 지금(유닉스 초 — 없으면 time.time())."""
    moment = time.time() if now is None else now
    return [
        (container_id, name)
        for container_id, name, age in _foreign_smoke_rows(text, session, moment)
        if age is None or age > SMOKE_STALE_AFTER_SECONDS
    ]


def young_smoke_containers(text: str, session: str, *, now: float | None = None) -> list[tuple[str, int]]:
    """지우지 않을 젊은 다른 세션 (이름, 나이 초) — jt.created가 SMOKE_STALE_AFTER_SECONDS 이내(미래 시각 포함)인 행: 동시에
    도는 다른 하네스 세션의 살아 있는 컨테이너일 수 있다(r3 F5 · r2 B-1)."""
    moment = time.time() if now is None else now
    return [
        (name, age)
        for _, name, age in _foreign_smoke_rows(text, session, moment)
        if age is not None and age <= SMOKE_STALE_AFTER_SECONDS
    ]


def sweep_stale_smoke_containers(
    docker: str, *, cwd: str | os.PathLike[str], now: float | None = None
) -> tuple[list[str], list[str]]:
    """이전 세션이 남긴 하네스 스모크 컨테이너(레이블 jt.harness=t072-smoke + 이름 jt-smoke-)를 지운다 → (지운 이름, 문제 줄).
    지우는 것은 다른 세션이면서 SMOKE_STALE_AFTER_SECONDS(30분)보다 오래됐거나 jt.created가 없거나 읽을 수 없는 것뿐이고,
    목록의 id로 지운다(remove_container). 그보다 젊은 다른 세션 컨테이너는 지우지 않고 문제 한 줄 「다른 하네스 세션이 실행 중일
    수 있다 — <이름>」을 싣는다(T072 r3 F5 · r2 B-1 — 하네스 동시 실행 금지). 이 레이블이 없는 컨테이너는 목록에 오지 않는다
    (--filter) — 남의 컨테이너는 절대 건드리지 않는다. docker ps가 실패하면 아무것도 지우지 않는다(빈 목록, 문제 한 줄)."""
    moment = time.time() if now is None else now
    listed = run(
        [docker, "ps", "-a", "--filter", f"label={HARNESS_LABEL_KEY}={SMOKE_HARNESS_LABEL}", "--format", SMOKE_PS_FORMAT],
        cwd=cwd,
        timeout=DOCKER_CALL_TIMEOUT,
        use_budget=False,
    )
    if not listed.ok:
        return [], [f"docker ps(남은 스모크 컨테이너 찾기) 실패 — exit {listed.returncode}"]
    removed: list[str] = []
    problems = [
        f"다른 하네스 세션이 실행 중일 수 있다 — {name}(만든 지 {age} s · 쓸기 문턱 {SMOKE_STALE_AFTER_SECONDS} s보다 젊어 지우지"
        " 않았다 — 하네스 동시 실행 금지)"
        for name, age in young_smoke_containers(listed.stdout, HARNESS_SESSION, now=moment)
    ]
    for container_id, name in stale_smoke_containers(listed.stdout, HARNESS_SESSION, now=moment):
        problem = remove_container(docker, container_id, cwd=cwd)
        if problem is None:
            removed.append(name)
        else:
            problems.append(f"이전 세션 컨테이너 {name}: {problem}")
    return removed, problems


def smoke_sweep_stage(docker: str, root: Path) -> SmokeSweep:
    """남은 스모크 컨테이너 쓸기를 단계 smoke-sweep으로 돌린다(T072 r3 F6 — conftest image가 Dockerfile 확인 · docker 찾기
    뒤, buildx build 앞에 부른다) — 단계 기록에 지운 이름(ASCII)과 문제 수를 남기고 SmokeSweep을 돌려준다."""
    with harness_stage(root, "smoke-sweep"):
        removed, problems = sweep_stale_smoke_containers(docker, cwd=root)
    stage_note(root, "smoke-sweep removed " + (" ".join(removed) if removed else "none"))
    stage_note(root, f"smoke-sweep problems={len(problems)}")
    return SmokeSweep(tuple(removed), tuple(problems))


def wait_until(
    docker: str,
    name: str,
    *,
    cwd: str | os.PathLike[str],
    ready: Callable[[float], bool],
    what: str,
    wait_seconds: float,
    poll_seconds: float,
) -> str | None:
    """ready(상한)가 참이 될 때까지 기다린다 — 문제 한 줄 또는 None. 컨테이너가 먼저 끝나면 멈춘다. 각 호출(docker
    inspect · ready 안의 docker exec)에는 남은 시간(하한 WAIT_CALL_FLOOR_SECONDS)을 상한으로 넘긴다(E13 · r1 B-7).
    시간(T072 r3 F4): 호출들이 시간 상한 안에서 쓰는 시간은 모두 합쳐 wait_seconds + 2 × WAIT_CALL_FLOOR_SECONDS 안이다(마지막
    반복의 두 호출이 하한을 받는 경우). 시간 초과로 끝난 호출은 그 뒤 트리 종료(Windows taskkill — 상한 TREE_KILL_TIMEOUT)와
    출력 수거(KILL_COMMUNICATE_SECONDS)를 더 쓰는데, 마감을 넘겨 붙는 것은 마지막 반복의 한 번뿐이다(inspect가 시간 초과면
    상태를 못 읽어 대기가 끝나고, 마감 전에 시간 초과로 끝난 호출 — 예: SMOKE_EXEC_TIMEOUT에 잘린 docker exec — 의 몫은 마감
    전에 끝나야 다음 반복으로 넘어간다) — 실제 최악 ≈ wait_seconds + 2 × WAIT_CALL_FLOOR_SECONDS + TREE_KILL_TIMEOUT +
    KILL_COMMUNICATE_SECONDS(스모크 대기 180 s면 Windows ≈ 222 s · POSIX ≈ 192 s — POSIX는 taskkill 몫이 없다)."""
    deadline = time.monotonic() + wait_seconds

    def remaining() -> float:
        return max(deadline - time.monotonic(), WAIT_CALL_FLOOR_SECONDS)

    while True:
        status, code = container_state(docker, name, cwd=cwd, timeout=remaining())
        if status != "running":
            return f"{what} 전에 컨테이너가 끝났다(상태 {status!r} · 종료 코드 {code!r})"
        if ready(remaining()):
            return None
        if time.monotonic() >= deadline:
            return f"{what}을(를) {wait_seconds:g} s 안에 보지 못했다"
        time.sleep(min(poll_seconds, max(deadline - time.monotonic(), 0)))


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


@dataclass(frozen=True)
class SmokeRun:
    """이미지 기동 스모크 한 가지(web · relay · celery · commands)의 결과 — 컨테이너는 이미 지웠다. problems = 판정
    위반(빈 튜플 = 통과) · transcript = 단계 요약 + 로그 꼬리(심은 비밀 값은 <이름>으로 가린다)."""

    kind: str
    problems: tuple[str, ...]
    transcript: str


@dataclass(frozen=True)
class SmokeSweep:
    """이미지 빌드 앞 쓸기 한 번의 결과(smoke_sweep_stage — T072 r3 F6: conftest image가 만들어 config.stash로 image_smoke에
    넘긴다) — 지운 이름 · 문제 줄(젊은 다른 세션 알림 · 정리 실패 · docker ps 실패)."""

    removed: tuple[str, ...]
    problems: tuple[str, ...]
