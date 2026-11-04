"""T065 하네스 세션 픽스처 — 미니 저장소에 sample-pod를 생성하고 단계(동기화 · 생성물 pytest · arm64 빌드 · 렌더 ·
kubeconform)를 세션에 한 번씩만 돈다.

- 단계가 실패하면 그 픽스처를 쓰는 뒤 테스트는 ERROR가 된다. 실패는 세션 동안 캐시되어 같은 명령을 다시 돌리지 않는다.
- 앞 단계의 산출물이 없으면(예: 생성물에 pyproject.toml이 없다) 명령을 돌리지 않고 실패한다 — uv가 상위 디렉터리의
  다른 프로젝트(JT_SAMPLE_POD_ROOT가 저장소 안이면 저장소 루트 워크스페이스)를 잡아 엉뚱한 환경을 동기화하지 않게.
- 삭제 규율: 하네스가 지우는 것은 자기가 만든 임시 디렉터리(tmp_path_factory)와 표식 파일이 있는 JT_SAMPLE_POD_ROOT의
  내용뿐이다(tests/_layout.py prepare_sample_root). JT_SAMPLE_POD_ROOT는 세션 뒤에도 남긴다.
"""

from __future__ import annotations

import os
import shutil
from collections.abc import Iterator
from pathlib import Path

import pytest
import yaml

from tests._layout import (
    IMAGE_TAG,
    POD_NAME,
    SAMPLE_ROOT_ENV,
    SampleRootError,
    copier_copy_argv,
    copy_django_common,
    layout_problems,
    prepare_sample_root,
)
from tests._proc import (
    KubeconformRun,
    PodSuite,
    ProcResult,
    Rendered,
    fail_with,
    parse_kubeconform_summary,
    read_junit,
    require_tool,
    run,
)
from tests._render import load_docs

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
        copy_django_common(root)
        yield root  # 보존 — 세션 뒤에도 지우지 않는다
        return
    root = tmp_path_factory.mktemp("jt-sample-pod")
    try:
        copy_django_common(root)
        yield root
    finally:
        shutil.rmtree(root, ignore_errors=True)


@pytest.fixture(scope="session")
def generated(mini_repo: Path) -> Path:
    """계약의 생성 명령으로 <root>/apps/sample-pod를 만든다 — exit 0이면 pod 경로."""
    pod = mini_repo / "apps" / POD_NAME
    result = run(copier_copy_argv(POD_NAME, pod), cwd=mini_repo, timeout=COPIER_TIMEOUT)
    if not result.ok:
        fail_with(result, "copier copy --trust --defaults --data pod_name=sample-pod 실패")
    if not pod.is_dir():
        pytest.fail(f"copier가 exit 0인데 생성 디렉터리가 없다: {pod}", pytrace=False)
    return pod


@pytest.fixture(scope="session")
def synced(generated: Path) -> ProcResult:
    if not (generated / "pyproject.toml").is_file():
        pytest.fail(
            "생성물에 pyproject.toml이 없다 — uv sync --locked를 돌리지 않는다"
            "(uv가 상위 디렉터리의 다른 프로젝트를 잡지 않게)",
            pytrace=False,
        )
    uv = require_tool("uv")
    result = run([uv, "sync", "--locked"], cwd=generated, timeout=SYNC_TIMEOUT)
    if not result.ok:
        fail_with(result, "생성물에서 uv sync --locked 실패")
    return result


@pytest.fixture(scope="session")
def pod_pytest(generated: Path, synced: ProcResult, tmp_path_factory: pytest.TempPathFactory) -> PodSuite:
    """생성물 pytest 한 번(junit 집계) — 실패해도 픽스처는 실패하지 않는다(판정은 gen-5)."""
    uv = require_tool("uv")
    junit = tmp_path_factory.mktemp("pod-junit") / "pod-pytest.xml"
    # --locked: 생성물 uv.lock이 어긋나면 재잠금 대신 실패(r1 A-8) · --tb=short: 생성물 addopts에 기대지 않는 방어선(r1 B-1 —
    # 긴 트레이스백은 psycopg 접속 문자열을 찍는다)
    result = run(
        [uv, "run", "--locked", "pytest", "-q", "-p", "no:cacheprovider", "--tb=short", f"--junit-xml={junit}"],
        cwd=generated,
        timeout=POD_PYTEST_TIMEOUT,
    )
    counts, problem = read_junit(junit)
    return PodSuite(result, counts, problem)


@pytest.fixture(scope="session")
def image(generated: Path, mini_repo: Path) -> Iterator[ProcResult]:
    """linux/arm64 이미지 빌드(컨텍스트 = 미니 저장소 루트 · -f apps/sample-pod/Dockerfile). 세션 끝에 이미지를 지운다."""
    dockerfile = generated / "Dockerfile"
    if not dockerfile.is_file():
        pytest.fail("생성물에 Dockerfile이 없다 — arm64 빌드를 돌리지 않는다", pytrace=False)
    docker = require_tool("docker")
    try:
        result = run(
            [
                docker,
                "buildx",
                "build",
                "--platform",
                "linux/arm64",
                "--progress",
                "plain",
                "--load",
                "-f",
                str(dockerfile),
                "-t",
                IMAGE_TAG,
                str(mini_repo),
            ],
            cwd=mini_repo,
            timeout=BUILD_TIMEOUT,
        )
        if not result.ok:
            fail_with(result, "docker buildx build --platform linux/arm64 실패(컨텍스트 = 미니 저장소 루트)")
        yield result
    finally:
        run([docker, "image", "rm", "-f", IMAGE_TAG], cwd=mini_repo, timeout=IMAGE_RM_TIMEOUT)  # 실패는 무시한다


@pytest.fixture(scope="session")
def rendered(generated: Path) -> Rendered:
    base = generated / "deploy" / "base"
    if not base.is_dir():
        pytest.fail("생성물에 deploy/base가 없다 — kustomize build를 돌리지 않는다", pytrace=False)
    kustomize = require_tool("kustomize")
    result = run([kustomize, "build", str(base)], cwd=generated, timeout=KUSTOMIZE_TIMEOUT)
    if not result.ok:
        fail_with(result, "kustomize build deploy/base 실패")
    problem: str | None = None
    try:
        docs = load_docs(result.stdout)
    except (yaml.YAMLError, ValueError) as exc:
        problem = f"kustomize build 출력을 YAML 문서 목록으로 읽지 못했다: {exc}"
    if problem is not None:
        pytest.fail(problem, pytrace=False)
    return Rendered(result, result.stdout, docs)


@pytest.fixture(scope="session")
def kubeconform_result(rendered: Rendered, generated: Path) -> KubeconformRun:
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
    result = run(argv, cwd=generated, timeout=KUBECONFORM_TIMEOUT, input_text=rendered.text)
    summary = parse_kubeconform_summary(result.stdout + "\n" + result.stderr)
    if summary is None:
        fail_with(result, "kubeconform 요약 줄(Summary: …)을 읽지 못했다")
    return KubeconformRun(result, summary)
