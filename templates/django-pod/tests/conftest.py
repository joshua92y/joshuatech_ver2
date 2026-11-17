"""T065 · T072 하네스 세션 픽스처 — 미니 저장소에 sample-pod를 생성하고 단계(동기화 · 생성물 pytest · arm64 빌드 ·
렌더 · kubeconform)를 세션에 한 번씩만 돈다. T072(design/t072-design.md D21)가 변형 두 벌(variant_generated ·
variant_rendered · variant_kubeconform)과 이미지 기동 스모크(image_smoke)를 더했다.

- 단계가 실패하면 그 픽스처를 쓰는 뒤 테스트는 ERROR가 된다. 실패는 세션 동안 캐시되어 같은 명령을 다시 돌리지 않는다.
- 앞 단계의 산출물이 없으면(예: 생성물에 pyproject.toml이 없다) 명령을 돌리지 않고 실패한다 — uv가 상위 디렉터리의
  다른 프로젝트(JT_SAMPLE_POD_ROOT가 저장소 안이면 저장소 루트 워크스페이스)를 잡아 엉뚱한 환경을 동기화하지 않게.
- 삭제 규율: 하네스가 지우는 것은 자기가 만든 임시 디렉터리(tmp_path_factory)와 표식 파일이 있는 JT_SAMPLE_POD_ROOT의
  내용뿐이다(tests/_layout.py prepare_sample_root). JT_SAMPLE_POD_ROOT는 세션 뒤에도 남긴다. 컨테이너는 하네스가 이름
  (jt-smoke-…)과 레이블(jt.harness=t072-smoke · jt.session · jt.created)을 붙인 것만 지우고, docker rm -f -v 뒤 사라졌는지
  확인한다(tests/_proc.py cleanup_container). 이전 세션이 남긴 것은 이미지 빌드 앞(image — Dockerfile 확인 · docker 찾기 뒤,
  buildx build 앞 · T072 r3 F6)에 같은 레이블 + 이름으로만 찾아, 다른 세션이면서 30분보다 오래됐거나 jt.created가 없거나 읽을
  수 없는 것만 지운다(F5). 그보다 젊은 다른 세션 컨테이너는 지우지 않고 gen-34 문제로 싣는다.
- 하네스 동시 실행 금지(T072 r3 F5): 이미지 태그(IMAGE_TAG)가 고정이라 한 세션이 끝에 지우는 이미지가 다른 세션의 이미지이고,
  남은 스모크 컨테이너 쓸기를 세션끼리 나눠 쓴다 — 한 번에 한 하네스 세션만 돌린다.
- 단계 기록(T072 r2 E13): 단계 픽스처는 <미니 저장소 루트>/harness-stages.log에 시작 · 끝을 한 줄씩(ASCII) 남기고 실패
  메시지 머리에 '[단계 <이름>]'을 싣는다(tests/_proc.py harness_stage). 시간 예산 env JT_HARNESS_BUDGET_SECONDS는 run()이
  쓴다.
- 변형(T072 · 계약 머리 「렌더 · 검사 전용 생성」): copier copy --skip-tasks --defaults로 <root>/variants/<이름>/apps/
  sample-pod에 만든다 — 형제 django-common이 없는 렌더 · 검사 전용 배치라 그 트리에서 uv lock · uv sync를 돌리지 않는다.
- 이미지 기동 스모크(T072 gen-34 · D21 · X22): docker run --network none --read-only --tmpfs /tmp(+ capability 전부 버림 ·
  no-new-privileges) · 이미지 USER 그대로 · env는 D5 runtime 필수 설정을 채운 시험 자리값(ENV=test · 닫힌 포트
  127.0.0.1 URL · 비밀은 실행 때 secrets.token_urlsafe · POD_IP=127.0.0.1 · POD_NAMESPACE 없음 — 클러스터 교차 규칙이
  ENV=test를 거부한다 · PLACEHOLDER- 없음 — 게이트 2 · APP_VERSION · APP_GIT_SHA는 이미지 ENV에서 온다). 비밀 값은 명령
  인자에 싣지 않고 docker CLI 자식 env로 넘긴다(-e <이름>). 대기 상한 180 s(x86 Windows의 QEMU arm64 에뮬레이션). 기록은
  비밀을 가린 뒤 자르고(tests/_tree.py SmokeLog — E8), 누출 판정은 원문 + HTTP 탐침 본문(출력하지 않는다 — E9)으로 한다.
- 이미지 빌드(T072 ③ r2): --build-arg APP_GIT_SHA(세션마다 새 난수 40 hex) · APP_VERSION으로 빌드하고(M4), 빌드 직전에 심은 감시
  파일 목록과 준 build-arg를 config.stash[IMAGE_BUILD_RECORD]에 싣는다 — gen-33이 라벨 · ENV와 심은 목록을 대조한다(M2(b)). 스모크
  명령은 tests/_render.py 상수다(M6 — 렌더 runtime_wiring이 deploy/base 명령을 같은 상수에 묶는다).
"""

from __future__ import annotations

import os
import secrets
import shutil
import time
from collections.abc import Callable, Iterator, Mapping
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

import pytest
import yaml

from tests._layout import (
    IMAGE_TAG,
    POD_NAME,
    POD_SNAKE,
    SAMPLE_ROOT_ENV,
    VARIANTS,
    SampleRootError,
    Variant,
    VariantTree,
    copier_copy_argv,
    copy_django_common,
    layout_problems,
    prepare_sample_root,
    variant_destination,
)
from tests._proc import (
    DOCKER_CALL_TIMEOUT,
    GLOB_PROBE_SCRIPT,
    HTTP_PROBE_SCRIPT,
    IMAGE_VENV_SENTINEL,
    POD_PYTEST_ENV,
    KubeconformRun,
    PodSuite,
    ProcResult,
    Rendered,
    SmokeRun,
    SmokeSweep,
    cleanup_container,
    container_state,
    docker_run_argv,
    fail_with,
    harness_stage,
    metric_samples,
    parse_kubeconform_summary,
    parse_probe_line,
    read_junit,
    require_tool,
    run,
    smoke_container_name,
    smoke_sweep_stage,
    stage_note,
    wait_until,
)
from tests._render import CELERY_COMMAND, INIT_COMMAND, PURGE_COMMAND, RELAY_COMMAND, load_docs
from tests._tree import (
    SmokeLog,
    check_container_logs,
    check_log_write_errors,
    check_purge_failure,
    check_startup_failure,
)

COPIER_TIMEOUT = 300
SYNC_TIMEOUT = 900
POD_PYTEST_TIMEOUT = 1800
BUILD_TIMEOUT = 2400
IMAGE_RM_TIMEOUT = 120
KUSTOMIZE_TIMEOUT = 120
KUBECONFORM_TIMEOUT = 600


@pytest.fixture(scope="session")
def mini_repo(tmp_path_factory: pytest.TempPathFactory) -> Iterator[Path]:
    """미니 저장소 <root> — <root>/packages/django-common(저장소 복사본) + 이후 생성될 <root>/apps/sample-pod."""
    problems = layout_problems()
    if problems:
        pytest.fail("저장소 배치가 하네스의 가정과 다르다:\n" + "\n".join(problems), pytrace=False)
    raw = os.environ.get(SAMPLE_ROOT_ENV, "").strip()
    if raw:
        refusal: str | None = None
        try:
            root = prepare_sample_root(raw)
        except SampleRootError as exc:
            refusal = str(exc)  # 예외 처리 블록 밖에서 실패시킨다(연쇄 예외로 같은 문구가 두 번 찍히지 않게)
        if refusal is not None:
            pytest.fail(refusal, pytrace=False)
        with harness_stage(root, "prepare"):
            copy_django_common(root)
        yield root  # 보존 — 세션 뒤에도 지우지 않는다
        return
    root = tmp_path_factory.mktemp("jt-sample-pod")
    try:
        with harness_stage(root, "prepare"):
            copy_django_common(root)
        yield root
    finally:
        shutil.rmtree(root, ignore_errors=True)


@pytest.fixture(scope="session")
def generated(mini_repo: Path) -> Path:
    """계약의 생성 명령으로 <root>/apps/sample-pod를 만든다 — exit 0이면 pod 경로."""
    pod = mini_repo / "apps" / POD_NAME
    with harness_stage(mini_repo, "generate") as stage:
        result = run(copier_copy_argv(POD_NAME, pod), cwd=mini_repo, timeout=COPIER_TIMEOUT)
        if not result.ok:
            fail_with(result, f"{stage} copier copy --trust --defaults --data pod_name=sample-pod 실패")
        if not pod.is_dir():
            pytest.fail(f"{stage} copier가 exit 0인데 생성 디렉터리가 없다: {pod}", pytrace=False)
    return pod


@pytest.fixture(scope="session")
def synced(generated: Path, mini_repo: Path) -> ProcResult:
    with harness_stage(mini_repo, "uv-sync") as stage:
        if not (generated / "pyproject.toml").is_file():
            pytest.fail(
                f"{stage} 생성물에 pyproject.toml이 없다 — uv sync --locked를 돌리지 않는다"
                "(uv가 상위 디렉터리의 다른 프로젝트를 잡지 않게)",
                pytrace=False,
            )
        uv = require_tool("uv")
        result = run([uv, "sync", "--locked"], cwd=generated, timeout=SYNC_TIMEOUT)
        if not result.ok:
            fail_with(result, f"{stage} 생성물에서 uv sync --locked 실패")
    return result


@pytest.fixture(scope="session")
def pod_pytest(
    generated: Path, synced: ProcResult, mini_repo: Path, tmp_path_factory: pytest.TempPathFactory
) -> PodSuite:
    """생성물 pytest 한 번(junit 집계) — 실패해도 픽스처는 실패하지 않는다(판정은 gen-5)."""
    with harness_stage(mini_repo, "pod-pytest"):
        uv = require_tool("uv")
        junit = tmp_path_factory.mktemp("pod-junit") / "pod-pytest.xml"
        # --locked: 생성물 uv.lock이 어긋나면 재잠금 대신 실패(r1 A-8) · --tb=short: 생성물 addopts에 기대지 않는 방어선(r1 B-1
        # — 긴 트레이스백은 psycopg 접속 문자열을 찍는다) · --show-capture=no(T072 D4 · X18): 실패 보고의 캡처 칸이 생성물 기동
        # 시험이 심은 비밀 · 감시 값을 찍지 않게(생성물 addopts에도 있지만 기대지 않는다) · POD_PYTEST_ENV(T072 r2 E10): 셸의
        # PYTEST_ADDOPTS · PYTHONOPTIMIZE 따위를 물려받지 않는다
        result = run(
            [
                uv,
                "run",
                "--locked",
                "pytest",
                "-q",
                "-p",
                "no:cacheprovider",
                "--tb=short",
                "--show-capture=no",
                f"--junit-xml={junit}",
            ],
            cwd=generated,
            timeout=POD_PYTEST_TIMEOUT,
            env=POD_PYTEST_ENV,
        )
        counts, problem = read_junit(junit)
    return PodSuite(result, counts, problem)


# 이미지 빌드 앞 쓸기의 결과(T072 r3 F6) — image가 넣고 image_smoke가 꺼낸다
SMOKE_SWEEP = pytest.StashKey[SmokeSweep]()

# ---------- 이미지 빌드 감시 파일(T072 조각 ③ 지시 5 · ③ r2 M1 · M2(b)) ----------
# image가 빌드 직전 생성 pod에 빈 감시 파일을 심고 빌드가 끝나면(성공 · 실패 · 시간 초과 · 예외) 지운다 — Dockerfile.dockerignore의
# 허용 목록과 재제외(**/.env* · **/*.pem · **/*.key · **/*.crt — X27 · ③ r2 M1)가 공허하지 않게: 하나라도 이미지에 들어오면 gen-33
# 탐침이 잡는다(sensitive_files · 최상위 허용 목록 · venv_sentinel — tests/_tree.py check_image_probe). 최상위 jt-harness.local은 어떤
# 재제외 꼴에도 맞지 않는다 — dockerignore가 pod 디렉터리 전체를 다시 넣는 거부 목록으로 돌아가면 이미지 최상위에 나타난다. 패키지 안
# 감시 파일(<pod_snake>/.env.jt-harness · jt-harness.crt)은 패키지를 다시 넣은 뒤의 재제외를 본다. 재제외 줄 자체는 생성
# dockerignore 정적 검사(check_dockerignore_text)가 플랫폼과 무관하게 본다(Linux에서는 uv가 합쳐진 .venv를 다시 만들어 .venv 감시
# 파일이 공허하다). 심은 목록은 config.stash[IMAGE_BUILD_RECORD]로 gen-33이 대조한다(심기가 빠지면 빨강 · ③ r2 M2(b)). 빌드 뒤 남은
# 감시 파일이 있으면 image가 실패한다(다음 단계 · 다음 세션이 그 파일을 생성물의 일부로 읽지 않게). 대문자 감시 파일
# <pod_snake>/JT-HARNESS-CASE.PEM(T072 마지막 라운드 N6 · ③ r2 리뷰 B-1 — 접미 계열)과 <pod_snake>/JT-HARNESS-NAME.ENV(T072 마감 라운드 Z3 ·
# 마지막 리뷰 B-1 — 이름 꼴 계열 *.env · .netrc · id_*)는 재제외가 대소문자를 가리면 이미지에 들어간다(탐침은 소문자 형으로 판정한다) — 이름을
# 다른 감시 파일과 대소문자만 다르지 않게 둔다(대소문자를 가리지 않는 파일 시스템(NTFS)에서 JT-HARNESS.PEM은 jt-harness.pem과 같은 파일이라
# 대문자 이름이 생기지 않는다).
BUILD_SENTINEL_FILES = (
    ".env.jt-harness",
    f"{POD_SNAKE}/jt-harness.pem",
    f"{POD_SNAKE}/jt-harness.key",
    "jt-harness.local",
    f"{POD_SNAKE}/.env.jt-harness",
    f"{POD_SNAKE}/jt-harness.crt",
    f"{POD_SNAKE}/JT-HARNESS-CASE.PEM",
    f"{POD_SNAKE}/JT-HARNESS-NAME.ENV",
)
VENV_SENTINEL = f".venv/{IMAGE_VENV_SENTINEL}"
# image 빌드의 build-arg(T072 ③ r2 M4 — gen-33이 라벨 revision · Config.Env가 이 값인지 본다)
HARNESS_APP_VERSION = "0.0.0+harness"


def image_build_args() -> dict[str, str]:
    """image 빌드의 --build-arg — APP_GIT_SHA = 부를 때마다 새 난수 소문자 hex 40자(기동 단언의 꼴 7–64 · 리터럴 기본값 0000000과 겹치지
    않는다) · APP_VERSION = HARNESS_APP_VERSION. 비밀이 아니다(명령 인자 · 판정 출력에 실린다)."""
    return {"APP_VERSION": HARNESS_APP_VERSION, "APP_GIT_SHA": secrets.token_hex(20)}


@dataclass(frozen=True)
class ImageBuildRecord:
    """image 픽스처가 빌드에 쓴 것(T072 ③ r2 M2(b) · M4) — 실제로 심은 감시 파일(pod 기준 POSIX 상대 경로) · 준 build-arg."""

    planted: tuple[str, ...]
    build_args: Mapping[str, str]


# image가 넣고 gen-33이 꺼낸다(없으면 gen-33이 빨강 — 심기 · build-arg가 빠진 빌드)
IMAGE_BUILD_RECORD = pytest.StashKey[ImageBuildRecord]()


@dataclass(frozen=True)
class PlantedSentinels:
    """plant_build_sentinels의 결과 — 심은 파일(pod 기준 POSIX 상대 경로) · .venv를 심기가 만들었는가(그러면 디렉터리째 지운다)."""

    pod: Path
    files: tuple[str, ...]
    created_venv: bool


def remove_build_sentinels(sentinels: PlantedSentinels) -> list[str]:
    """심은 감시 파일을 지우고(.venv를 심기가 만들었으면 디렉터리째) 남은 것(pod 기준 상대 경로)을 돌려준다 — 빈 목록 = 정리
    확인. 예외를 던지지 않는다(지우기 실패는 남은 것으로 보고한다)."""
    pod = sentinels.pod
    for relative in sentinels.files:
        try:
            (pod / relative).unlink(missing_ok=True)
        except OSError:
            pass  # 아래 확인이 남은 것으로 보고한다
    venv = pod / ".venv"
    if sentinels.created_venv:
        shutil.rmtree(venv, ignore_errors=True)
    leftovers = [relative for relative in sentinels.files if os.path.lexists(pod / relative)]
    if sentinels.created_venv and os.path.lexists(venv):
        leftovers.append(".venv/")
    return leftovers


def plant_build_sentinels(pod: Path) -> PlantedSentinels:
    """BUILD_SENTINEL_FILES와 VENV_SENTINEL을 빈 파일로 심는다(.venv가 없으면 만든다). 심다가 실패하면 심은 것을 지우고
    pytest.fail(파일 이름 · 예외 클래스만)."""
    venv = pod / ".venv"
    created_venv = False
    planted: list[str] = []
    current = ".venv/"
    problem: str | None = None
    try:
        if not os.path.lexists(venv):
            venv.mkdir()
            created_venv = True
        for current in (*BUILD_SENTINEL_FILES, VENV_SENTINEL):
            (pod / current).write_bytes(b"")
            planted.append(current)
    except OSError as exc:
        problem = f"이미지 빌드 감시 파일 {current}을(를) 심지 못했다({type(exc).__name__})"
    sentinels = PlantedSentinels(pod, tuple(planted), created_venv)
    if problem is not None:
        leftovers = remove_build_sentinels(sentinels)
        pytest.fail(problem + (f" — 지우지 못한 감시 파일: {leftovers}" if leftovers else ""), pytrace=False)
    return sentinels


def build_with_sentinels(
    pod: Path, build: Callable[[], ProcResult], *, record: Callable[[tuple[str, ...]], Any] | None = None
) -> ProcResult:
    """감시 파일을 심고 build()를 돌린 뒤 지운다(finally — 성공 · 실패 · 시간 초과(returncode None) · 예외 모두). 남은 감시
    파일이 있으면 빌드 결과 판정보다 먼저 pytest.fail. 빌드 결과(ok 여부)의 판정은 호출자 몫이다. record(T072 ③ r2 M2(b))는 빌드 전에
    실제로 심은 감시 파일(pod 기준 상대 경로)을 받는다 — image가 stash에 싣고 gen-33이 대조한다."""
    sentinels = plant_build_sentinels(pod)
    if record is not None:
        record(sentinels.files)
    try:
        result = build()
    finally:
        leftovers = remove_build_sentinels(sentinels)
    if leftovers:
        pytest.fail(
            f"이미지 빌드 뒤 감시 파일이 남았다(지우기 실패): {leftovers} — 손으로 지운 뒤 다시 돌린다(빌드 exit {result.returncode})",
            pytrace=False,
        )
    return result


@pytest.fixture(scope="session")
def image(request: pytest.FixtureRequest, generated: Path, mini_repo: Path) -> Iterator[ProcResult]:
    """linux/arm64 이미지 빌드(컨텍스트 = 미니 저장소 루트 · -f apps/sample-pod/Dockerfile). 빌드 앞에 이전 세션이 남긴 스모크
    컨테이너를 쓴다(T072 r3 F6 · r2 B-2 — Dockerfile 확인 · docker 찾기 뒤라 빈 템플릿에서는 docker를 부르지 않고, 빌드가
    실패하는 세션 · 이미지 시험만 고른 실행에서도 돈다. 결과는 config.stash[SMOKE_SWEEP] → image_smoke). 빌드 직전 생성 pod에
    감시 파일(BUILD_SENTINEL_FILES · VENV_SENTINEL — T072 조각 ③ 지시 5 · ③ r2 M1)을 심고 빌드가 끝나면 지운다(build_with_sentinels —
    남으면 실패). --build-arg APP_GIT_SHA(세션마다 새 난수) · APP_VERSION으로 빌드한다(T072 ③ r2 M4). 심은 목록과 준 build-arg는
    config.stash[IMAGE_BUILD_RECORD] → gen-33(③ r2 M2(b) · M4). 세션 끝에 이미지를 지운다."""
    dockerfile = generated / "Dockerfile"
    docker: str | None = None
    try:
        with harness_stage(mini_repo, "image-build") as stage:
            if not dockerfile.is_file():
                pytest.fail(f"{stage} 생성물에 Dockerfile이 없다 — arm64 빌드를 돌리지 않는다", pytrace=False)
            docker = require_tool("docker")
            request.config.stash[SMOKE_SWEEP] = smoke_sweep_stage(docker, mini_repo)
            build_args = image_build_args()
            argv = [
                docker,
                "buildx",
                "build",
                "--platform",
                "linux/arm64",
                "--progress",
                "plain",
                "--load",
                *(part for name, value in build_args.items() for part in ("--build-arg", f"{name}={value}")),
                "-f",
                str(dockerfile),
                "-t",
                IMAGE_TAG,
                str(mini_repo),
            ]
            # 감시 파일(T072 조각 ③ 지시 5)은 빌드 직전에 심고 빌드가 끝나면 지운다 — 남으면 여기서 실패한다
            planted: list[str] = []
            result = build_with_sentinels(
                generated, lambda: run(argv, cwd=mini_repo, timeout=BUILD_TIMEOUT), record=planted.extend
            )
            request.config.stash[IMAGE_BUILD_RECORD] = ImageBuildRecord(tuple(planted), build_args)
            if not result.ok:
                fail_with(result, f"{stage} docker buildx build --platform linux/arm64 실패(컨텍스트 = 미니 저장소 루트)")
        yield result
    finally:
        if docker is not None:  # 실패는 무시한다(정리 — 세션 시간 예산 밖)
            run([docker, "image", "rm", "-f", IMAGE_TAG], cwd=mini_repo, timeout=IMAGE_RM_TIMEOUT, use_budget=False)


def kustomize_build(pod: Path, label: str, stage: str) -> Rendered:
    """<pod>/deploy/base를 kustomize build해 문서 목록으로 — 기본 생성물(rendered)과 변형(variant_rendered)이 같이 쓴다.
    stage = 실패 메시지 머리의 단계 이름표."""
    base = pod / "deploy" / "base"
    if not base.is_dir():
        pytest.fail(f"{stage} {label}에 deploy/base가 없다 — kustomize build를 돌리지 않는다", pytrace=False)
    kustomize = require_tool("kustomize")
    result = run([kustomize, "build", str(base)], cwd=pod, timeout=KUSTOMIZE_TIMEOUT)
    if not result.ok:
        fail_with(result, f"{stage} {label} kustomize build deploy/base 실패")
    problem: str | None = None
    try:
        docs = load_docs(result.stdout)
    except (yaml.YAMLError, ValueError) as exc:
        problem = f"{stage} {label} kustomize build 출력을 YAML 문서 목록으로 읽지 못했다: {exc}"
    if problem is not None:
        pytest.fail(problem, pytrace=False)
    return Rendered(result, result.stdout, docs)


def kubeconform_run(rendered: Rendered, pod: Path, stage: str) -> KubeconformRun:
    """CI scripts/ci/kubeconform-deploy.sh와 같은 플래그(-strict -ignore-missing-schemas -summary -kubernetes-version)."""
    kubeconform = require_tool("kubeconform")
    argv = [
        kubeconform,
        "-strict",
        "-ignore-missing-schemas",
        "-summary",
        "-kubernetes-version",
        os.environ.get("KUBECONFORM_K8S_VERSION") or "master",
    ]
    cache = os.environ.get("KUBECONFORM_CACHE")
    if cache:
        Path(cache).mkdir(parents=True, exist_ok=True)
        argv += ["-cache", cache]
    result = run(argv, cwd=pod, timeout=KUBECONFORM_TIMEOUT, input_text=rendered.text)
    summary = parse_kubeconform_summary(result.stdout + "\n" + result.stderr)
    if summary is None:
        fail_with(result, f"{stage} kubeconform 요약 줄(Summary: …)을 읽지 못했다")
    return KubeconformRun(result, summary)


@pytest.fixture(scope="session")
def rendered(generated: Path, mini_repo: Path) -> Rendered:
    with harness_stage(mini_repo, "render") as stage:
        return kustomize_build(generated, "생성물", stage)


@pytest.fixture(scope="session")
def kubeconform_result(rendered: Rendered, generated: Path, mini_repo: Path) -> KubeconformRun:
    with harness_stage(mini_repo, "kubeconform") as stage:
        return kubeconform_run(rendered, generated, stage)


# ---------- T072 변형 두 벌(D21 · X3 · X10) ----------


@pytest.fixture(scope="session", params=VARIANTS, ids=[variant.name for variant in VARIANTS])
def variant_generated(request: pytest.FixtureRequest, mini_repo: Path) -> VariantTree:
    """변형 하나를 copier copy --skip-tasks --defaults --data pod_name=sample-pod --data …로 <root>/variants/<이름>/apps/
    sample-pod에 만든다(렌더 · 검사 전용 — --trust · uv lock 없음). 이 픽스처를 쓰는 테스트는 변형마다 한 번씩 돈다."""
    variant: Variant = request.param
    destination = variant_destination(mini_repo, variant)
    with harness_stage(mini_repo, f"variant-generate[{variant.name}]") as stage:
        argv = copier_copy_argv(POD_NAME, destination, extra_data=variant.data, skip_tasks=True)
        result = run(argv, cwd=mini_repo, timeout=COPIER_TIMEOUT)
        if not result.ok:
            fail_with(result, f"{stage} 변형 {variant.name} 생성 실패(copier copy --skip-tasks --defaults …)")
        if not destination.is_dir():
            pytest.fail(f"{stage} copier가 exit 0인데 변형 {variant.name} 생성 디렉터리가 없다: {destination}", pytrace=False)
    return VariantTree(variant, destination)


@pytest.fixture(scope="session")
def variant_rendered(variant_generated: VariantTree, mini_repo: Path) -> Rendered:
    name = variant_generated.variant.name
    with harness_stage(mini_repo, f"variant-render[{name}]") as stage:
        return kustomize_build(variant_generated.path, f"변형 {name}", stage)


@pytest.fixture(scope="session")
def variant_kubeconform(variant_rendered: Rendered, variant_generated: VariantTree, mini_repo: Path) -> KubeconformRun:
    """gen-7과 같은 플래그로 변형 렌더를 검증한다."""
    with harness_stage(mini_repo, f"variant-kubeconform[{variant_generated.variant.name}]") as stage:
        return kubeconform_run(variant_rendered, variant_generated.path, stage)


# ---------- T072 이미지 기동 스모크(gen-34 · D21 · X22) ----------

SMOKE_KINDS = ("web", "relay", "celery", "commands")
SMOKE_WAIT_SECONDS = 180  # 대기 상한 — x86 Windows의 QEMU arm64 에뮬레이션 기동(D21 · X22)
SMOKE_ALIVE_SECONDS = 15  # relay · celery: 준비를 본 뒤 더 살아 있어야 하는 시간(D21의 N초)
SMOKE_POLL_SECONDS = 3
SMOKE_EXEC_TIMEOUT = 120
SMOKE_COMMAND_TIMEOUT = SMOKE_WAIT_SECONDS + 60  # 전경 docker run --rm 명령 하나(기동 포함)
# --network none 컨테이너의 127.0.0.1에서는 pod 자신의 8000 · 9100 · 9464만 열린다 — 아래 포트는 닫혀 있다
SMOKE_PORTS = {"postgres": 15432, "dragonfly": 16379, "kafka": 19092, "jwks": 18080, "access": 18443}

HEALTHZ_URL = "http://127.0.0.1:8000/healthz"
WEB_METRICS_URL = "http://127.0.0.1:9100/metrics"
RELAY_METRICS_URL = "http://127.0.0.1:9464/metrics"
WEB_METRIC = "http_requests_total"
CELERY_SCHEDULE_GLOB = "/tmp/celerybeat-schedule*"
# 명령 상수는 한 곳(tests/_render.py — T072 ③ r2 M6): RELAY_COMMAND · CELERY_COMMAND(D14 워커 명령 · <pod_snake> = sample_pod) ·
# INIT_COMMAND · PURGE_COMMAND를 그대로 쓴다 — 렌더 runtime_wiring · cronjob이 deploy/base 명령을 같은 상수에 묶는다(web은 이미지 CMD
# = _render.WEB_COMMAND — gen-33 정적 검사). 위 import가 이 모듈의 이름으로도 내보낸다(conftest.RELAY_COMMAND 따위).
STARTUP_COMMAND = (*INIT_COMMAND, "--wait", "1")


@dataclass(frozen=True)
class SmokeEnv:
    args: tuple[str, ...]  # docker run -e 인자(비밀은 이름만 — 값은 child)
    child: dict[str, str]  # docker CLI 자식 env에 넣는 비밀 값
    planted: dict[str, str]  # 출력에서 찾을 심은 비밀 값(설명 → 값)


def smoke_env() -> SmokeEnv:
    """D5 runtime 필수 설정을 채운 시험 자리값 — 실행마다 새 난수 비밀. APP_VERSION · APP_GIT_SHA는 넣지 않는다(이미지
    ENV가 준다 — 없으면 기동 실패로 드러난다)."""
    db_password = secrets.token_urlsafe(48)
    dragonfly_password = secrets.token_urlsafe(48)
    hidden = {
        "SECRET_KEY": secrets.token_urlsafe(48),
        "KAFKA_PASSWORD": secrets.token_urlsafe(48),
        "DATABASE_URL": (
            f"postgresql://{POD_SNAKE}_app:{db_password}@127.0.0.1:{SMOKE_PORTS['postgres']}/{POD_SNAKE}?sslmode=require"
        ),
        "DRAGONFLY_URL": f"redis://{POD_NAME}:{dragonfly_password}@127.0.0.1:{SMOKE_PORTS['dragonfly']}/0",
    }
    plain = {
        "ENV": "test",
        "ALLOWED_HOSTS": f"{POD_NAME}.smoke.svc",
        "POD_IP": "127.0.0.1",
        "KAFKA_BOOTSTRAP": f"127.0.0.1:{SMOKE_PORTS['kafka']}",
        "KAFKA_USERNAME": POD_NAME,
        "AUTHENTIK_ISSUER": f"https://auth.joshuatech.dev/application/o/{POD_NAME}/",
        "AUTHENTIK_JWKS_URL": f"http://127.0.0.1:{SMOKE_PORTS['jwks']}/application/o/{POD_NAME}/jwks/",
        "AUTHENTIK_AUDIENCE": POD_NAME,
        "ACCESS_TEAM_DOMAIN": f"http://127.0.0.1:{SMOKE_PORTS['access']}",
        "ACCESS_AUD_M2M": "smoke-access-audience",
        "ACCESS_AUD_ADMIN": "",
        "ACCESS_EXPECTED_CN": "smoke-expected-common-name",
        "ADMIN_HOST": "",
        "OTEL_EXPORTER_OTLP_ENDPOINT": "",
        "OTEL_TRACES_SAMPLER": "parentbased_traceidratio",
        "OTEL_TRACES_SAMPLER_ARG": "0.1",
    }
    args: list[str] = []
    for name, value in plain.items():
        args += ["-e", f"{name}={value}"]
    for name in hidden:
        args += ["-e", name]
    planted = {
        "SECRET_KEY": hidden["SECRET_KEY"],
        "KAFKA_PASSWORD": hidden["KAFKA_PASSWORD"],
        "DATABASE_URL 비밀번호": db_password,
        "DRAGONFLY_URL 비밀번호": dragonfly_password,
    }
    return SmokeEnv(tuple(args), hidden, planted)


def probe_in_container(
    docker: str, name: str, script: str, args: list[str], *, cwd: Path, timeout: float = SMOKE_EXEC_TIMEOUT
) -> Any:
    """docker exec -i <name> python - <args> — 탐침 스크립트의 JT-PROBE 줄(없으면 None). timeout = 대기의 남은 시간(E13)."""
    result = run(
        [docker, "exec", "-i", name, "python", "-", *args],
        cwd=cwd,
        timeout=min(timeout, SMOKE_EXEC_TIMEOUT),
        input_text=script,
    )
    return parse_probe_line(result.stdout)


def http_probe(
    docker: str,
    name: str,
    url: str,
    *,
    cwd: Path,
    log: SmokeLog,
    prefix: str | None = None,
    timeout: float = SMOKE_EXEC_TIMEOUT,
) -> dict[str, Any]:
    """HTTP 탐침 결과(status · error · lines). 응답 본문(body · 상한 1 MB)은 떼어 log의 누출 판정용 원문에만 넣는다 —
    기록 · 실패 메시지에 찍지 않는다(T072 r2 E9 · r1 B-3: /metrics 본문도 누출 판정 범위)."""
    facts = probe_in_container(docker, name, HTTP_PROBE_SCRIPT, [url, *([prefix] if prefix else [])], cwd=cwd, timeout=timeout)
    if not isinstance(facts, dict):
        return {"status": None, "error": "JT-PROBE 줄 없음", "lines": []}
    body = facts.pop("body", "")
    if isinstance(body, str) and body:
        log.add_raw(body)
    return facts


def still_running(docker: str, name: str, *, cwd: Path, why: str) -> str | None:
    status, code = container_state(docker, name, cwd=cwd)
    if status != "running":
        return f"{why} 컨테이너가 살아 있지 않다(상태 {status!r} · 종료 코드 {code!r})"
    return None


def container_logs(docker: str, name: str, *, cwd: Path) -> ProcResult:
    """docker logs 결과 그대로 — 실패 · 시간 초과는 호출자가 check_container_logs로 판정한다(E9)."""
    return run([docker, "logs", name], cwd=cwd, timeout=DOCKER_CALL_TIMEOUT)


def run_detached(
    docker: str, kind: str, command: tuple[str, ...], observe: Callable[[str, SmokeLog], None], *, cwd: Path
) -> SmokeRun:
    """-d --name jt-smoke-<kind>-… 로 띄우고 observe(이름, 기록)를 돌린 뒤 finally에서 로그를 모으고(try) 지운다(finally —
    로그 수집이 끊겨도 지우기는 돈다 · E11): docker rm -f -v + 정리 확인, docker run이 시간 초과였으면 몇 초 뒤 한 번 더.
    docker logs가 실패하면 문제 한 줄(E9). 로그의 쓰기 오류 · 비밀 누출은 모든 상주 스모크가 함께 본다."""
    env = smoke_env()
    log = SmokeLog(kind, env.planted)
    name = smoke_container_name(kind)
    run_timed_out = False
    logs_result: ProcResult | None = None
    cleanups: list[str] = []
    try:
        argv = docker_run_argv(docker, IMAGE_TAG, name, detach=True, env_args=env.args, command=command)
        started = log.record(run(argv, cwd=cwd, timeout=DOCKER_CALL_TIMEOUT, env=env.child), f"docker run -d({kind})")
        run_timed_out = started.returncode is None
        if started.ok:
            observe(name, log)
        else:
            log.problems.append(f"docker run -d 실패(exit {started.returncode})")
    finally:
        try:
            logs_result = container_logs(docker, name, cwd=cwd)
        finally:
            cleanups = cleanup_container(docker, name, cwd=cwd, run_timed_out=run_timed_out)
    logs = logs_result.stdout + "\n" + logs_result.stderr
    log.notes.append(f"docker logs: exit {logs_result.returncode} · {logs_result.seconds:.1f} s")
    log.problems.extend(check_container_logs(logs_result))
    log.problems.extend(check_log_write_errors(logs))
    return log.finish(logs, cleanups)


def smoke_web(docker: str, cwd: Path) -> SmokeRun:
    """① web — 이미지 CMD(gunicorn … --no-control-socket) 기동 · /healthz 200(Host 127.0.0.1 = POD_IP) · 그 뒤 :9100/metrics에
    http_requests_total 표본."""

    def observe(name: str, log: SmokeLog) -> None:
        last: dict[str, Any] = {}

        def healthy(timeout: float) -> bool:
            last.update(http_probe(docker, name, HEALTHZ_URL, cwd=cwd, log=log, timeout=timeout))
            return last.get("status") == 200

        problem = wait_until(
            docker, name, cwd=cwd, ready=healthy, what="/healthz 200", wait_seconds=SMOKE_WAIT_SECONDS, poll_seconds=SMOKE_POLL_SECONDS
        )
        log.notes.append(f"/healthz 마지막 탐침: {last}")
        if problem is not None:
            log.problems.append(problem)
            return
        metrics = http_probe(docker, name, WEB_METRICS_URL, cwd=cwd, log=log, prefix=WEB_METRIC)
        samples = metric_samples("\n".join(metrics.get("lines") or []), WEB_METRIC)
        log.notes.append(f":9100/metrics 탐침: status {metrics.get('status')!r} · error {metrics.get('error')!r} · 표본 {samples}")
        if metrics.get("status") != 200:
            log.problems.append(f":9100/metrics 응답 {metrics.get('status')!r}(기대 200 — gunicorn post_worker_init 지표 서버)")
        elif not samples:
            log.problems.append(f":9100/metrics에 {WEB_METRIC} 표본 없음(/healthz 요청이 세어져야 한다 — D11)")
        problem = still_running(docker, name, cwd=cwd, why="지표 확인 뒤")
        if problem is not None:
            log.problems.append(problem)

    return run_detached(docker, "web", (), observe, cwd=cwd)


def smoke_relay(docker: str, cwd: Path) -> SmokeRun:
    """② relay — python manage.py outbox_relay가 :9464/metrics를 열고 N초 뒤에도 살아 있으며 다시 응답한다(Kafka · DB가
    닫힌 포트라 로그 + 백오프로 버틴다 — 루프 안에서 끝나지 않는다)."""

    def observe(name: str, log: SmokeLog) -> None:
        last: dict[str, Any] = {}

        def serving(timeout: float) -> bool:
            last.update(http_probe(docker, name, RELAY_METRICS_URL, cwd=cwd, log=log, timeout=timeout))
            return last.get("status") == 200

        problem = wait_until(
            docker,
            name,
            cwd=cwd,
            ready=serving,
            what=":9464/metrics 200",
            wait_seconds=SMOKE_WAIT_SECONDS,
            poll_seconds=SMOKE_POLL_SECONDS,
        )
        log.notes.append(f":9464/metrics 첫 탐침: {last}")
        if problem is not None:
            log.problems.append(problem)
            return
        time.sleep(SMOKE_ALIVE_SECONDS)
        problem = still_running(docker, name, cwd=cwd, why=f"{SMOKE_ALIVE_SECONDS} s 뒤")
        if problem is not None:
            log.problems.append(problem)
            return
        again = http_probe(docker, name, RELAY_METRICS_URL, cwd=cwd, log=log)
        log.notes.append(f"{SMOKE_ALIVE_SECONDS} s 뒤 :9464/metrics 탐침: {again}")
        if again.get("status") != 200:
            log.problems.append(f"{SMOKE_ALIVE_SECONDS} s 뒤 :9464/metrics 응답 {again.get('status')!r}(기대 200)")

    return run_detached(docker, "relay", RELAY_COMMAND, observe, cwd=cwd)


def smoke_celery(docker: str, cwd: Path) -> SmokeRun:
    """③ celery — D14 워커 명령이 /tmp/celerybeat-schedule*을 만들고(beat 일정 파일) N초 뒤에도 살아 있다(브로커가 닫힌
    포트라 재시도 단계에 머문다). 일정 파일 단언은 VD-T072-16 — 조각 ③에서 실측해 바꿀 수 있다."""

    def observe(name: str, log: SmokeLog) -> None:
        last: list[Any] = []

        def scheduled(timeout: float) -> bool:
            found = probe_in_container(docker, name, GLOB_PROBE_SCRIPT, [CELERY_SCHEDULE_GLOB], cwd=cwd, timeout=timeout)
            last[:] = found if isinstance(found, list) else []
            return bool(last)

        problem = wait_until(
            docker,
            name,
            cwd=cwd,
            ready=scheduled,
            what=f"{CELERY_SCHEDULE_GLOB} 생성",
            wait_seconds=SMOKE_WAIT_SECONDS,
            poll_seconds=SMOKE_POLL_SECONDS,
        )
        log.notes.append(f"beat 일정 파일: {last}")
        if problem is not None:
            log.problems.append(problem)
            return
        time.sleep(SMOKE_ALIVE_SECONDS)
        problem = still_running(docker, name, cwd=cwd, why=f"{SMOKE_ALIVE_SECONDS} s 뒤")
        if problem is not None:
            log.problems.append(problem)

    return run_detached(docker, "celery", CELERY_COMMAND, observe, cwd=cwd)


def smoke_commands(docker: str, cwd: Path) -> SmokeRun:
    """④ 명령 — startup_check --wait 1: 종료 1 · stderr 한 줄 'startup_check: FAIL <…OperationalError>' · 트레이스백 없음
    (check_startup_failure) / outbox_purge: 0 · None이 아닌 종료 · stderr에 OperationalError 예외 줄 · Unknown command ·
    ImproperlyConfigured · ImportError · ModuleNotFoundError 줄 없음(check_purge_failure — T072 r2 E3). outbox_purge는
    django-common 명령 그대로라(D13 · D1) 트레이스백은 허용한다 — X25 출력 규칙은 템플릿 코드에만 건다(D21 ④ 개정). 둘 다
    출력에 심은 비밀 값(전체 · 16자 이상 부분)이 없다."""
    env = smoke_env()
    log = SmokeLog("commands", env.planted)
    startup_name, purge_name = smoke_container_name("startup"), smoke_container_name("purge")
    timed_out = {startup_name: False, purge_name: False}
    cleanups: list[str] = []
    try:
        startup = log.record(
            run(
                docker_run_argv(docker, IMAGE_TAG, startup_name, env_args=env.args, command=STARTUP_COMMAND),
                cwd=cwd,
                timeout=SMOKE_COMMAND_TIMEOUT,
                env=env.child,
            ),
            "startup_check --wait 1(DB 없음)",
        )
        timed_out[startup_name] = startup.returncode is None
        log.problems.extend(
            f"startup_check: {item}" for item in check_startup_failure(startup.returncode, startup.stdout, startup.stderr)
        )
        purge = log.record(
            run(
                docker_run_argv(docker, IMAGE_TAG, purge_name, env_args=env.args, command=PURGE_COMMAND),
                cwd=cwd,
                timeout=SMOKE_COMMAND_TIMEOUT,
                env=env.child,
            ),
            "outbox_purge(DB 없음)",
        )
        timed_out[purge_name] = purge.returncode is None
        log.problems.extend(f"outbox_purge: {item}" for item in check_purge_failure(purge))
    finally:
        try:
            cleanups.extend(cleanup_container(docker, startup_name, cwd=cwd, run_timed_out=timed_out[startup_name]))
        finally:
            cleanups.extend(cleanup_container(docker, purge_name, cwd=cwd, run_timed_out=timed_out[purge_name]))
    return log.finish("", cleanups)


SMOKES: dict[str, Callable[[str, Path], SmokeRun]] = {
    "web": smoke_web,
    "relay": smoke_relay,
    "celery": smoke_celery,
    "commands": smoke_commands,
}


# image가 빌드 앞 쓸기 결과를 넣지 않았는데 image가 성공했다면 하네스 결함이다 — 조용히 넘어가지 않고 gen-34 문제로 싣는다
SMOKE_SWEEP_MISSING = SmokeSweep((), ("이미지 빌드 앞 쓸기 결과가 없다(image 픽스처가 config.stash에 넣었어야 한다 — 하네스 결함)",))


@pytest.fixture(scope="session", params=SMOKE_KINDS)
def image_smoke(request: pytest.FixtureRequest, image: ProcResult, mini_repo: Path) -> SmokeRun:
    """이미지 기동 스모크 한 가지(web · relay · celery · commands — D21 gen-34 넷). 컨테이너는 픽스처 안에서 띄우고 지운다
    (정리 확인 포함) — 판정 위반은 SmokeRun.problems에 모으고 gen-34가 판정한다(스모크 실패로 픽스처가 실패하지 않는다).
    이미지 빌드 앞 쓸기(image가 config.stash[SMOKE_SWEEP]에 넣은 SmokeSweep — T072 r3 F6)의 지운 이름은 transcript에, 문제
    줄(젊은 다른 세션 알림 · 정리 실패 · docker ps 실패)은 problems에 함께 싣는다."""
    docker = require_tool("docker")
    kind: str = request.param
    sweep = request.config.stash.get(SMOKE_SWEEP, SMOKE_SWEEP_MISSING)
    with harness_stage(mini_repo, f"image-smoke[{kind}]"):
        result = SMOKES[kind](docker, mini_repo)
    stage_note(mini_repo, f"image-smoke[{kind}] problems={len(result.problems)}")
    swept = f"이전 세션 스모크 컨테이너 정리: {list(sweep.removed) or '없음'}\n"
    return replace(result, problems=(*sweep.problems, *result.problems), transcript=swept + result.transcript)
