"""인프라 초록 tool-1..6(T065) — 하네스가 판정에 쓰는 도구가 이 환경에서 동작하는지 본다. 지금 초록이어야 한다.

도구가 없으면 skip이 아니라 FAIL이다. 생성물 검사(test_generate.py)의 빨강이 도구 부재 때문인지 템플릿 때문인지를
여기서 먼저 가른다.
"""

from __future__ import annotations

import sys
from pathlib import Path

from tests._layout import TEMPLATE_DIR, copier_copy_argv, copy_django_common, layout_problems
from tests._proc import buildx_platforms, fail_with, parse_version, require_tool, run

MIN_COPIER = (9, 17)  # copier.yml _min_copier_version(계약 · T072)
MIN_UV = (0, 12)
MIN_KUSTOMIZE = (5,)
MIN_KUBECONFORM = (0, 6)
PROBE_POD = "probe-pod"


def test_tool_1_copier_module_and_version() -> None:
    import copier  # noqa: F401 — 가져오기 자체가 검사다(하네스 venv에 copier가 있다)

    res = run([sys.executable, "-m", "copier", "--version"], cwd=TEMPLATE_DIR, timeout=120)
    if not res.ok:
        fail_with(res, "python -m copier --version 실패")
    version = parse_version(res.stdout)
    assert version is not None, f"copier 버전을 읽지 못했다: {res.stdout!r}"
    assert version >= MIN_COPIER, f"copier {version} < {MIN_COPIER}"


def test_tool_2_uv_version() -> None:
    uv = require_tool("uv")
    res = run([uv, "--version"], cwd=TEMPLATE_DIR, timeout=60)
    if not res.ok:
        fail_with(res, "uv --version 실패")
    version = parse_version(res.stdout)
    assert version is not None, f"uv 버전을 읽지 못했다: {res.stdout!r}"
    assert version >= MIN_UV, f"uv {version} < {MIN_UV}"


def test_tool_3_buildx_linux_arm64() -> None:
    docker = require_tool("docker")
    res = run([docker, "buildx", "inspect", "--bootstrap"], cwd=TEMPLATE_DIR, timeout=300)
    if not res.ok:
        fail_with(res, "docker buildx inspect --bootstrap 실패")
    platforms = buildx_platforms(res.stdout)
    assert "linux/arm64" in platforms, f"현재 buildx 빌더의 Platforms에 linux/arm64가 없다: {sorted(platforms)}"


def test_tool_4_kustomize_version() -> None:
    kustomize = require_tool("kustomize")
    res = run([kustomize, "version"], cwd=TEMPLATE_DIR, timeout=60)
    if not res.ok:
        fail_with(res, "kustomize version 실패")
    version = parse_version(res.stdout)
    assert version is not None, f"kustomize 버전을 읽지 못했다: {res.stdout!r}"
    assert version >= MIN_KUSTOMIZE, f"kustomize {version} < {MIN_KUSTOMIZE}"


def test_tool_5_kubeconform_version() -> None:
    kubeconform = require_tool("kubeconform")
    res = run([kubeconform, "-v"], cwd=TEMPLATE_DIR, timeout=60)
    if not res.ok:
        fail_with(res, "kubeconform -v 실패")
    version = parse_version(res.stdout + res.stderr)
    assert version is not None, f"kubeconform 버전을 읽지 못했다: {res.stdout!r} {res.stderr!r}"
    assert version >= MIN_KUBECONFORM, f"kubeconform {version} < {MIN_KUBECONFORM}"


def test_tool_6_copier_copy_current_template(tmp_path: Path) -> None:
    """현재 템플릿으로도 생성 명령 자체는 성공한다 — 생성물 검사의 빨강이 copier 실패가 아님을 보인다.

    생성 위치 규칙(계약 머리)대로 <tmp>/apps/<pod> + <tmp>/packages/django-common 배치를 만든다 — 템플릿에
    _tasks: uv lock이 들어온 뒤(T072)에도 path 의존성 ../../packages/django-common이 풀려 이 검사가 그대로 성립한다.
    생성물은 tmp_path에 두고 끝낸다.
    """
    problems = layout_problems()
    assert not problems, "저장소 배치가 하네스의 가정과 다르다:\n" + "\n".join(problems)
    copy_django_common(tmp_path)
    destination = tmp_path / "apps" / PROBE_POD
    res = run(copier_copy_argv(PROBE_POD, destination), cwd=tmp_path, timeout=300)
    if not res.ok:
        fail_with(res, "현재 템플릿으로 copier copy --trust --defaults 실패")
    assert destination.is_dir(), f"copier가 exit 0인데 생성 디렉터리가 없다: {destination}"
