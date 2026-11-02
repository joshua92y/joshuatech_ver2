"""T065 생성물 검사 gen-1..18 — copier 생성 → uv sync --locked → 생성물 pytest → arm64 빌드 → kustomize · kubeconform ·
렌더 단언. 정본: specs/003-platform-foundation/contracts/pod-template.md §기본 테스트 6 · tasks.md T065.

지금은 빨강이다: 템플릿(template/)이 비어 있어 생성물에 .gitkeep만 있다 → gen-1 · 2 · 3 · 18 FAIL, 단계 픽스처(synced ·
image · rendered)가 앞 단계 산출물 없음으로 실패해 gen-4..17 ERROR. 템플릿 구현(T072)이 이 스위트를 초록으로 만든다.
테스트 이름에 tool · render 낱말을 쓰지 않는다(-k "tool or render"로 인프라 초록만 고를 때 섞이지 않게).

T072 가정 — 계약에 없지만 이 하네스가 고정한 것(바꾸려면 계약 · build-notes 「T065」 설계를 먼저 개정한다):
 ① 워크로드 식별 = containerPort 8000 컨테이너를 가진 Deployment가 web, 그 pod의 containerPort 9464 컨테이너가 relay,
    나머지 Deployment가 celery(정확히 2개), Job은 정확히 1개(tests/_render.py identify_workloads).
 ② migrate Job의 첫 실행 컨테이너(initContainers[0] 있으면 그것, 없으면 containers[0])의 command+args 리터럴에
    REVOKE/GRANT SQL과 `migrate` 낱말이 함께 있어야 한다 — SQL만 하는 initContainer 분리 · 스크립트 파일로 빼기는 불통과.
 ③ ExternalSecret의 DB URL은 매핑 키 DATABASE_URL(<pod>-env) · DATABASE_OWNER_URL(<pod>-migrate)의 문자열 값
    (spec.target.template.data 조립)이어야 한다.
 ④ .copier-answers.yml이 생성되어야 하고(template/에 {{ _copier_conf.answers_file }}.jinja) _src_path 키가 있다.
 ⑤ tool.uv.sources.django-common = { path = "../../packages/django-common", editable = true } 정확 꼴.
 ⑥ Docker 이미지 Config.User가 ""/root/0(그룹을 붙인 0:0 · root:root 포함)이 아니어야 한다.
 ⑦ 미니 저장소 배치 — django-common은 pyproject.toml · src/만 복사한다(생성물이 packages/events 스키마를 읽으면 깨진다).
 ⑧ Job의 모든 컨테이너(init 포함)가 <pod>-migrate를 참조하고 pg-main-ca를 마운트한다.
 ⑨ celery Deployment의 모든 컨테이너가 192Mi(worker+beat는 한 Deployment).
 ⑩ ConfigMap 참조는 web · celery만 단언한다 — relay · migrate도 Django settings(ALLOWED_HOSTS · ADMIN_HOST 필수)를
    적재하므로 필요하면 넣어라(골든은 넣었다). Ingress pathType · 프로브 timeout/period 수치 · 메트릭 portNumber 어노테이션은
    단언하지 않는다.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from tests._layout import IMAGE_TAG, TEMPLATE_DIR
from tests._proc import (
    IMAGE_INSPECT_FORMAT,
    KubeconformRun,
    PodSuite,
    ProcResult,
    Rendered,
    describe,
    fail_with,
    is_root_user,
    parse_image_inspect,
    require_tool,
    run,
    tail,
)
from tests._render import (
    check_annotations,
    check_configmap,
    check_db_tls,
    check_env_split,
    check_identification,
    check_ingress,
    check_migrate_sql,
    check_probes,
    check_security_context,
    check_strategy_resources,
)
from tests._tree import (
    ANSWERS_FILE,
    POD_TEST_FILES,
    check_copier_settings,
    check_env_example,
    check_generated_files,
    check_migrations_test,
    check_pyproject,
)

MIN_POD_TESTS = 8  # 내장 6종 + makemigrations --check + migration linter
COLLECT_TIMEOUT = 300
INSPECT_TIMEOUT = 120


def expect_no_violations(title: str, violations: list[str], extra: str = "") -> None:
    if violations:
        message = f"{title} — 위반 {len(violations)}건:\n" + "\n".join(f"- {item}" for item in violations)
        pytest.fail(message + (f"\n{extra}" if extra else ""), pytrace=False)


def read_generated(pod: Path, relative: str) -> str:
    path = pod / relative
    if not path.is_file():
        pytest.fail(f"생성물에 {relative}이(가) 없다 — 템플릿(template/)이 만들어야 한다", pytrace=False)
    return path.read_text(encoding="utf-8")


# ---------- 생성물 자체 ----------


def test_gen_1_generated_files(generated: Path) -> None:
    """copier 생성 성공(픽스처) · .copier-answers.yml(pod_name) · 계약 §생성 트리 파일 · .jinja 잔재 없음."""
    expect_no_violations("생성 트리(계약 §생성 트리)", check_generated_files(generated))


def test_gen_2_pyproject_pins_and_pytest_policy(generated: Path) -> None:
    """django-ninja==1.7.0 정확 핀 · django/psycopg/celery/django-common(path 소스) · dev 의존 · 경고 범위 · --tb=short."""
    expect_no_violations("생성물 pyproject.toml", check_pyproject(read_generated(generated, "pyproject.toml")))


def test_gen_3_env_example_keys_only(generated: Path) -> None:
    expect_no_violations("생성물 env.example", check_env_example(read_generated(generated, "env.example")))


def test_gen_4_uv_sync_locked(synced: ProcResult, generated: Path) -> None:
    assert synced.ok
    assert (generated / ".venv").is_dir(), "uv sync --locked가 exit 0인데 생성물에 .venv가 없다"


def test_gen_5_pod_suite_all_passed(pod_pytest: PodSuite, generated: Path) -> None:
    """생성물 pytest: 실패 0 · 오류 0 · skip 0 · 테스트 ≥ 8 · exit 0, 수집 목록에 내장 테스트 7파일,
    test_migrations.py에 makemigrations와 migration linter."""
    problems: list[str] = []
    counts = pod_pytest.counts
    if counts is None:
        problems.append(f"생성물 pytest의 junit을 읽지 못했다: {pod_pytest.junit_problem}")
    else:
        if counts.failures:
            problems.append(f"실패 {counts.failures}")
        if counts.errors:
            problems.append(f"오류 {counts.errors}")
        if counts.skipped:
            problems.append(f"skip {counts.skipped}(내장 테스트를 건너뛰지 않는다 — skip 0)")
        if counts.tests < MIN_POD_TESTS:
            problems.append(f"테스트 {counts.tests}개(기대 ≥ {MIN_POD_TESTS})")
    if not pod_pytest.proc.ok:
        problems.append(f"생성물 pytest exit {pod_pytest.proc.returncode}(기대 0)")
    uv = require_tool("uv")
    # --locked: 잠금이 어긋나면 조용히 다시 잠그지 않고 실패한다(r1 A-8) · --tb=short: 생성물 addopts에 기대지 않는다(r1 B-1)
    collected = run(
        [uv, "run", "--locked", "pytest", "--collect-only", "-q", "-p", "no:cacheprovider", "--tb=short"],
        cwd=generated,
        timeout=COLLECT_TIMEOUT,
    )
    if not collected.ok:
        problems.append(f"생성물 pytest --collect-only exit {collected.returncode}")
    for relative in POD_TEST_FILES:
        if Path(relative).name not in collected.stdout:
            problems.append(f"수집 목록에 {relative} 없음")
    migrations = generated / "tests" / "test_migrations.py"
    if migrations.is_file():
        problems.extend(check_migrations_test(migrations.read_text(encoding="utf-8")))
    else:
        problems.append("tests/test_migrations.py 없음")
    output = f"--- 생성물 pytest 출력 꼬리 ---\n{tail(pod_pytest.proc.stdout)}\n{tail(pod_pytest.proc.stderr)}"
    expect_no_violations("생성물 pytest", problems, output)


def test_gen_6_image_arm64_non_root(image: ProcResult) -> None:
    docker = require_tool("docker")
    result = run(
        [docker, "image", "inspect", IMAGE_TAG, "--format", IMAGE_INSPECT_FORMAT],
        cwd=TEMPLATE_DIR,
        timeout=INSPECT_TIMEOUT,
    )
    if not result.ok:
        fail_with(result, f"docker image inspect {IMAGE_TAG} 실패")
    facts = parse_image_inspect(result.stdout)
    if facts is None:
        fail_with(result, "docker image inspect 출력을 읽지 못했다")
    problems: list[str] = []
    if facts.architecture != "arm64":
        problems.append(f"아키텍처 {facts.architecture!r}(기대 'arm64')")
    if facts.os != "linux":
        problems.append(f"OS {facts.os!r}(기대 'linux')")
    if is_root_user(facts.user):
        problems.append(f"USER {facts.user!r}(비-root여야 한다)")
    expect_no_violations("이미지", problems)


def test_gen_7_kubeconform_valid(kubeconform_result: KubeconformRun) -> None:
    summary = kubeconform_result.summary
    problems: list[str] = []
    if not kubeconform_result.proc.ok:
        problems.append(f"kubeconform exit {kubeconform_result.proc.returncode}(기대 0)")
    if summary.invalid:
        problems.append(f"Invalid {summary.invalid}")
    if summary.errors:
        problems.append(f"Errors {summary.errors}")
    if summary.valid < 1:
        problems.append(f"Valid {summary.valid}(검증된 객체 0 — 전부 스키마 없음으로 건너뜀이면 통과가 아니다)")
    expect_no_violations("kubeconform(deploy/base 렌더)", problems, describe(kubeconform_result.proc, "kubeconform 출력"))


# ---------- 렌더 단언(tests/_render.py) ----------


def test_gen_8_workloads_identified(rendered: Rendered) -> None:
    expect_no_violations("워크로드 식별", check_identification(rendered.docs))


def test_gen_9_security_context(rendered: Rendered) -> None:
    expect_no_violations("securityContext", check_security_context(rendered.docs))


def test_gen_10_secret_split(rendered: Rendered) -> None:
    expect_no_violations("시크릿 분리(<pod>-env · <pod>-migrate)", check_env_split(rendered.docs))


def test_gen_11_db_tls_and_ca_mount(rendered: Rendered) -> None:
    expect_no_violations("DB TLS · pg-main-ca 마운트", check_db_tls(rendered.docs))


def test_gen_12_probes(rendered: Rendered) -> None:
    expect_no_violations("프로브", check_probes(rendered.docs))


def test_gen_13_strategy_requests_affinity(rendered: Rendered) -> None:
    expect_no_violations("배포 전략 · requests · CPU limit · affinity", check_strategy_resources(rendered.docs))


def test_gen_14_migrate_connect_boundary_sql(rendered: Rendered) -> None:
    expect_no_violations("migrate Job CONNECT 경계 SQL", check_migrate_sql(rendered.docs))


def test_gen_15_annotations(rendered: Rendered) -> None:
    expect_no_violations("어노테이션", check_annotations(rendered.docs))


def test_gen_16_configmap_keys_and_refs(rendered: Rendered) -> None:
    expect_no_violations("ConfigMap", check_configmap(rendered.docs))


def test_gen_17_ingress_paths(rendered: Rendered) -> None:
    expect_no_violations("Ingress 경로", check_ingress(rendered.docs))


# ---------- 템플릿 설정 · 답변 ----------


def test_gen_18_answers_and_copier_settings(generated: Path) -> None:
    """.copier-answers.yml의 _src_path · 템플릿 copier.yml의 _min_copier_version ≥ 9.17(튜플 비교) · _tasks의 uv lock."""
    answers = generated / ANSWERS_FILE
    answers_text = answers.read_text(encoding="utf-8") if answers.is_file() else None
    copier_text = (TEMPLATE_DIR / "copier.yml").read_text(encoding="utf-8")
    expect_no_violations(".copier-answers.yml · copier.yml", check_copier_settings(answers_text, copier_text))
