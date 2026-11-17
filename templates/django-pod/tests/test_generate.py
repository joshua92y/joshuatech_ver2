"""T065 · T072 생성물 검사 gen-1..38 — copier 생성 → uv sync --locked → 생성물 pytest → arm64 빌드 → kustomize · kubeconform ·
렌더 단언(T065 gen-1..18)에 T072 추가분(gen-19..38 — design/t072-design.md D21): 렌더 검사 7종 · T072 생성 트리 · pytest 위생 ·
outbox_purge 표식 · copier validator · 변형 두 벌(no-celery · no-admin — 트리 · kubeconform · 렌더 · Python) · 이미지 구성 ·
탐침 · 기동 스모크 넷 · compose config(③ r2 M5 — 내용 판정 · 마지막 라운드 N5 — 모든 프로필) · copier 예약 이름(gen-37 — ③ r2 M11 ·
N7 — 실제 생성 트리 최상위 이름도) · 렌더 ≅ 골든(gen-38 — 마지막 라운드 N3: 기본 · 변형 두 벌 · 예외 = relay pg-ca 마운트 꼴 하나) ·
migrate Job 스크립트 = 골든 스크립트(gen-14 · gen-31 본문 — N2(1)). 정본:
specs/003-platform-foundation/contracts/pod-template.md §기본 테스트 6(「T072가 더한 단언」 포함) · design/t072-design.md D21 ·
tasks.md T065 · T072.

지금은 빨강이다(T072 조각 ① 끝 — 템플릿(template/)이 비어 있어 생성물에 .gitkeep만 있다):
- FAIL: gen-1 · 2 · 3 · 18(T065) · gen-25 · 26 · 27 · 35(생성물에 파일이 없다) · gen-28 거부 사례 12(validator가 없어 copier가
  exit 0) · gen-28 받아들임 사례 3(T072 r2 E4 — 생성물에 .copier-answers.yml이 없다: 템플릿이 있어야 참인 단언) · gen-29 두
  벌(--skip-tasks 변형 생성은 빈 템플릿에서도 성공하므로 ERROR가 아니라 트리 단언 FAIL — X5).
- ERROR(단계 픽스처가 앞 단계 산출물 없음으로 실패): gen-4..17(T065 — synced · image · rendered) · gen-19..24 · 36(rendered) ·
  gen-30 · 31 두 벌씩(variant_rendered — 변형에 deploy/base 없음) · gen-32 두 벌(synced — 기본 pod venv) · gen-33 ·
  gen-34 넷(image — Dockerfile 없음).
- PASS: 없다.
템플릿 구현(T072 조각 ②–④)이 이 스위트를 초록으로 만든다. 조각별 선택은 노드 ID로 한다(-k gen_1은 gen_10..19까지 잡는다 — X5).
테스트 이름 · 매개변수 id에 tool · render · check 낱말을 쓰지 않는다(대소문자 무시 — rendered · startup_check도 안 된다). -k
"tool or render or check"로 인프라 초록만 고를 때 섞이지 않게.

T072 가정 — 계약에 없지만 이 하네스가 고정한 것(바꾸려면 계약 §기본 테스트 6 + design/t072-design.md를 먼저 개정한다 · X11):
 ① 워크로드 식별 = containerPort 8000 컨테이너를 가진 Deployment가 web, 그 pod의 containerPort 9464 컨테이너가 relay,
    나머지 Deployment가 celery(정확히 2개), Job은 정확히 1개(tests/_render.py identify_workloads). T072 변형 모드
    (has_celery=false 렌더 — gen-31): Deployment 정확히 1(web+relay) · celery 없음 · Job 1 · CronJob 정확히 1. 기본 규칙은
    그대로다.
 ② migrate Job의 첫 실행 컨테이너(initContainers[0] 있으면 그것, 없으면 containers[0])의 command+args 리터럴에
    REVOKE/GRANT SQL과 `migrate` 낱말이 함께 있어야 한다 — SQL만 하는 initContainer 분리 · 스크립트 파일로 빼기는 불통과.
 ③ ExternalSecret의 DB URL은 매핑 키 DATABASE_URL(<pod>-env) · DATABASE_OWNER_URL(<pod>-migrate)의 문자열 값
    (spec.target.template.data 조립)이어야 한다.
 ④ .copier-answers.yml이 생성되어야 하고(template/에 {{ _copier_conf.answers_file }}.jinja) _src_path 키가 있다.
 ⑤ tool.uv.sources.django-common = { path = "../../packages/django-common", editable = true } 정확 꼴.
 ⑥ Docker 이미지 Config.User가 ""/root/0(그룹을 붙인 0:0 · root:root 포함)이 아니어야 한다(gen-6). T072 강화: 이미지
    Config.User가 정확히 숫자 10001:10001(gen-33)이고 렌더의 pod securityContext.runAsUser · runAsGroup이 정수 10001 ·
    컨테이너 값이 있으면 그것도 10001(gen-9).
 ⑦ 미니 저장소 배치 — django-common은 pyproject.toml · src/만 복사한다(생성물이 packages/events 스키마를 읽으면 깨진다).
 ⑧ Job의 모든 컨테이너(init 포함)가 <pod>-migrate를 참조하고 pg-main-ca를 마운트한다. T072: Job의 컨테이너와 볼륨은
    ConfigMap을 참조하지 않는다(첫 배포의 PreSync에는 Sync 단계 ConfigMap이 아직 없다 — gen-22).
 ⑨ celery Deployment의 모든 컨테이너가 192Mi(worker+beat는 한 Deployment).
 ⑩ ConfigMap 참조는 런타임 컨테이너 전부(web · relay · celery · init · 변형이면 CronJob — envFrom ConfigMap <pod>-config +
    secretRef <pod>-env · gen-16 · gen-36) · migrate Job은 금지다(⑧ · gen-22 — T072 r2 E1로 개정). Ingress pathType(/health
    Exact · 나머지 Prefix — gen-17)과 web 프로브 timeoutSeconds ≥ 3(gen-19)은 이제 단언한다. 프로브 period 수치(startupProbe
    30 × 5 밖)와 메트릭 portNumber 어노테이션은 계속 단언하지 않는다(T098).
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest
import yaml

from tests._layout import IMAGE_TAG, POD_NAME, POD_SNAKE, TEMPLATE_DIR, VariantTree, copier_copy_argv, venv_python
from tests._proc import (
    APP_LABELS_PROBE_SCRIPT,
    IMAGE_INSPECT_FORMAT,
    IMAGE_PROBE_SCRIPT,
    POD_PYTEST_ENV,
    SETTINGS_PROBE_SCRIPT,
    KubeconformRun,
    PodSuite,
    ProcResult,
    Rendered,
    SmokeRun,
    allowlist_env,
    cleanup_container,
    describe,
    docker_run_argv,
    fail_with,
    is_root_user,
    parse_image_inspect,
    parse_probe_line,
    require_tool,
    run,
    smoke_container_name,
    tail,
)
from tests._render import (
    DEFAULT_RENDER,
    check_annotations,
    check_configmap,
    check_cronjob,
    check_db_tls,
    check_env_hygiene,
    check_env_split,
    check_external_secrets,
    check_hook_order,
    check_identification,
    check_images,
    check_ingress,
    check_migrate_sql,
    check_pod_lifecycle,
    check_probes,
    check_runtime_wiring,
    check_security_context,
    check_strategy_resources,
    golden_differences,
    golden_for,
    migrate_script_differences,
    run_checks,
)
from tests._tree import (
    ANSWERS_FILE,
    COMPOSE_FILE,
    COMPOSE_PROFILE_PROBE_TEXT,
    DOCKERIGNORE_FILE,
    POD_TEST_FILES,
    WRAPPER_SETTINGS,
    check_base_kustomization,
    check_compose_config,
    check_compose_profile_probe,
    check_copier_settings,
    check_dockerfile_text,
    check_dockerignore_text,
    check_env_example,
    check_generated_files,
    check_generated_files_t072,
    check_image_build_args,
    check_image_config,
    check_image_probe,
    check_migrations_test,
    check_outbox_test,
    check_planted_sentinels,
    check_pyproject,
    check_pytest_hygiene,
    check_recorded_answers,
    check_render_only_tree,
    check_reserved_pod_names,
    check_validator_rejection,
    check_variant_settings,
    compose_config_argv,
    copier_reserved_names,
    generated_top_level_names,
    template_top_level_names,
)
from tests.conftest import BUILD_SENTINEL_FILES, IMAGE_BUILD_RECORD, VENV_SENTINEL

MIN_POD_TESTS = 8  # 내장 6종 + makemigrations --check + migration linter
COLLECT_TIMEOUT = 300
INSPECT_TIMEOUT = 120
VALIDATOR_TIMEOUT = 300
VARIANT_PYTHON_TIMEOUT = 300
IMAGE_PROBE_TIMEOUT = 240  # 이미지 탐침 컨테이너 하나(x86 Windows의 QEMU arm64 기동 포함)
COMPOSE_TIMEOUT = 120


def expect_no_violations(title: str, violations: list[str], extra: str = "") -> None:
    if violations:
        message = f"{title} — 위반 {len(violations)}건:\n" + "\n".join(f"- {item}" for item in violations)
        pytest.fail(message + (f"\n{extra}" if extra else ""), pytrace=False)


def read_generated(pod: Path, relative: str) -> str:
    path = pod / relative
    if not path.is_file():
        pytest.fail(f"생성물에 {relative}이(가) 없다 — 템플릿(template/)이 만들어야 한다", pytrace=False)
    return path.read_text(encoding="utf-8")


def json_or_none(text: str) -> Any:
    """도구 출력 JSON — 읽지 못하면 None(판정 함수가 「읽지 못했다」로 보고한다)."""
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def kubeconform_problems(result: KubeconformRun) -> list[str]:
    """kubeconform 판정(gen-7 · gen-30): exit 0 · Invalid 0 · Errors 0 · Valid ≥ 1."""
    summary = result.summary
    problems: list[str] = []
    if not result.proc.ok:
        problems.append(f"kubeconform exit {result.proc.returncode}(기대 0)")
    if summary.invalid:
        problems.append(f"Invalid {summary.invalid}")
    if summary.errors:
        problems.append(f"Errors {summary.errors}")
    if summary.valid < 1:
        problems.append(f"Valid {summary.valid}(검증된 객체 0 — 전부 스키마 없음으로 건너뜀이면 통과가 아니다)")
    return problems


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
    # --locked: 잠금이 어긋나면 조용히 다시 잠그지 않고 실패한다(r1 A-8) · --tb=short: 생성물 addopts에 기대지 않는다(r1 B-1) ·
    # POD_PYTEST_ENV(T072 r2 E10): PYTEST_ADDOPTS의 -k · --deselect가 수집 목록 · skip 0 판정을 비켜 가지 않게
    collected = run(
        [uv, "run", "--locked", "pytest", "--collect-only", "-q", "-p", "no:cacheprovider", "--tb=short"],
        cwd=generated,
        timeout=COLLECT_TIMEOUT,
        env=POD_PYTEST_ENV,
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
    expect_no_violations(
        "kubeconform(deploy/base 렌더)",
        kubeconform_problems(kubeconform_result),
        describe(kubeconform_result.proc, "kubeconform 출력"),
    )


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
    """CONNECT 경계 SQL(REVOKE · GRANT가 migrate 앞) + 렌더한 migrate Job 스크립트 = 골든(golden-render.yaml) 스크립트 — UTF-8 바이트까지(T072
    마지막 라운드 N2(1) · 조각 ④ 리뷰 A-1: 재시도 대상 · 마감 · 재시도 줄 · 종료 코드 전달 · 기본 마감 · URL · 경계 실패 처리는 가짜 psycopg
    시험(test_render_helpers.py)이 골든에서 굳힌다 — 이 결속으로 템플릿 스크립트에도 걸린다)."""
    exemplar, problems = golden_for(DEFAULT_RENDER)
    problems += check_migrate_sql(rendered.docs)
    problems += migrate_script_differences(rendered.docs, exemplar)
    expect_no_violations("migrate Job CONNECT 경계 SQL · 스크립트 = 골든", problems)


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


# ==================== T072 추가(design/t072-design.md D21 · 계약 §기본 테스트 6 「T072가 더한 단언」) ====================

# ---------- T072 렌더 단언(기본 렌더 — tests/_render.py 새 검사) ----------


def test_gen_19_pod_lifecycle(rendered: Rendered) -> None:
    """web pod grace ≥ 90 · web 프로브 timeoutSeconds ≥ 3 · env POD_IP(fieldRef status.podIP) · preStop sleep ≥ 5(D8 · X29)."""
    expect_no_violations("pod 생애(grace · 프로브 timeout · POD_IP · preStop)", check_pod_lifecycle(rendered.docs))


def test_gen_20_env_hygiene(rendered: Rendered) -> None:
    """컨테이너마다 실효 env 이름(env · envFrom prefix + ConfigMap 키 · ES 키)에 금지 이름 0 · 렌더 밖 envFrom 0(X18)."""
    expect_no_violations("env 위생", check_env_hygiene(rendered.docs))


def test_gen_21_external_secrets(rendered: Rendered) -> None:
    """ExternalSecret v1 · vault-dev · dev/ 키 · property · 5m · Periodic · Owner · v2 · Replace · dataFrom/templateFrom 없음 ·
    data[] ≥ 1 · 템플릿 {{ .x }} 참조 ⊆ secretKey · 순번(<pod>-env 표 8행 · <pod>-migrate 0 · 1 — D20 · T072 r2 E2)."""
    expect_no_violations("ExternalSecret", check_external_secrets(rendered.docs))


def test_gen_22_hook_order(rendered: Rendered) -> None:
    """<pod>-migrate ES = PreSync · BeforeHookCreation · wave < Job wave · Job ConfigMap 참조 0 · -env ES · ConfigMap wave < 0."""
    expect_no_violations("Argo hook · sync-wave 순서", check_hook_order(rendered.docs))


def test_gen_23_images_and_base_kustomization(rendered: Rendered, generated: Path) -> None:
    """모든 컨테이너 image = ghcr.io/joshua92y/sample-pod(태그 · digest 없음) · 렌더에 metadata.namespace 없음 + base
    kustomization.yaml에 images · namespace · commonLabels 키 없음(렌더로 볼 수 없는 정적 부분 — D20)."""
    problems = check_images(rendered.docs)
    problems += check_base_kustomization(read_generated(generated, "deploy/base/kustomization.yaml"))
    expect_no_violations("이미지 이름 · base kustomization", problems)


def test_gen_24_cronjob_absent_by_default(rendered: Rendered) -> None:
    """기본 렌더(has_celery=true)에는 CronJob이 없다 — dead outbox purge는 celery beat가 맡는다(D15 · 변형은 gen-31)."""
    expect_no_violations("CronJob(기본 렌더)", check_cronjob(rendered.docs))


def test_gen_38_manifests_match_golden_fixtures(rendered: Rendered) -> None:
    """렌더 ≅ 골든(T072 마지막 라운드 N3 · 조각 ④ 리뷰 A-2): 기본 렌더(kustomize build deploy/base)가 fixtures/golden-render.yaml과 구조로
    같다 — 문서는 (kind, 이름)으로 짝짓고(순서 무관) 값 · 타입 · 키 · 목록 자리까지(tests/_render.py golden_differences). 예외는 하나 — 골든
    relay의 pg-ca subPath 꼴(본보기 아님 · render-26 · 27 변이 대상)을 템플릿 꼴(/etc/pg 디렉터리)로 바꾼 본보기와 견준다(golden_exemplar).
    CHECKS가 보지 않는 D20 값(Job 상한 · trimSuffix · ConfigMap dev 값 · 프로브 주기 · migrate 스크립트)을 바꾸려면 골든을 같은 변경에서
    고친다. 차이는 경로별 목록으로 낸다."""
    exemplar, problems = golden_for(DEFAULT_RENDER)
    problems += golden_differences(rendered.docs, exemplar)
    expect_no_violations("렌더 ≅ 골든(golden-render.yaml · 예외 = relay pg-ca 마운트 꼴)", problems)


def test_gen_38_variant_manifests_match_golden_fixtures(variant_rendered: Rendered, variant_generated: VariantTree) -> None:
    """변형 렌더 ≅ 골든(N3): no-celery = fixtures/golden-cronjob.yaml · no-admin = golden-cronjob.yaml − ConfigMap FORCE_SCRIPT_NAME(has_admin
    false) — 기본과 같은 구조 비교 · 같은 예외 하나."""
    variant = variant_generated.variant
    exemplar, problems = golden_for(variant.name)
    problems += golden_differences(variant_rendered.docs, exemplar)
    expect_no_violations(f"변형 {variant.name} 렌더 ≅ 골든", problems)


def test_gen_36_runtime_wiring(rendered: Rendered) -> None:
    """init startup-check · web · relay Kafka CA 마운트 · web 9100 · memory limits · 런타임 POD_NAMESPACE(Job 없음) ·
    ConfigMap · ES 템플릿 값에 줄바꿈 · 앞뒤 공백 없음(X2 · X8) · 런타임 컨테이너 전부의 envFrom ConfigMap <pod>-config +
    <pod>-env · 런타임 필수 설정 이름 · migrate Job JT_SETTINGS_PROFILE=migrate(리터럴) · migrate에 런타임 키 없음(T072 r2 E1 ·
    X7) · 명령 결속(T072 ③ r2 M6 — web은 command · args 없음 또는 정확히 이미지 CMD 토큰 · relay · celery 명령 = gen-34가 읽기 전용
    루트에서 시험한 _render 상수)."""
    expect_no_violations("런타임 배선", check_runtime_wiring(rendered.docs))


# ---------- T072 생성 트리 · 설정(gen-25..28) ----------


def test_gen_25_t072_tree(generated: Path) -> None:
    """T072 추가 파일(기본 플래그 has_celery · has_admin · consumes_events 없음) · 쓰지 않는 파일 이름 · .gitkeep 0(D2 · D3)."""
    expect_no_violations("T072 생성 트리", check_generated_files_t072(generated))


def test_gen_26_pytest_hygiene(generated: Path) -> None:
    """addopts --tb=short · --show-capture=no · 넓히는 옵션 0 · log_cli · log_file · junit_logging 없음 ·
    DJANGO_SETTINGS_MODULE = tests.settings(D4 · D5)."""
    expect_no_violations("생성물 pytest 위생", check_pytest_hygiene(read_generated(generated, "pyproject.toml")))


def test_gen_27_outbox_purge_marker(generated: Path) -> None:
    """생성물 tests/test_outbox.py가 call_command("outbox_purge")를 돈다(계약:108 넷 ④ · D17)."""
    expect_no_violations("outbox_purge 시험 표식", check_outbox_test(read_generated(generated, "tests/test_outbox.py")))


YAML_QUESTIONS = frozenset({"owns_events", "consumes_events"})


@dataclass(frozen=True)
class ValidatorCase:
    """gen-28 사례 — question이 None이면 받아들여야 한다(종료 0), 아니면 그 질문의 validator가 거부해야 한다."""

    id: str
    pod_name: str
    extra: tuple[str, ...] = ()
    question: str | None = None
    yaml_item_contains: str = ""  # YAML 질문 입력의 사전 조건 — 파싱한 항목에 이 글자가 있어야 시험이 뜻을 갖는다


VALIDATOR_CASES = (
    ValidatorCase("pod-name-uppercase", "Bad_Name", question="pod_name"),
    ValidatorCase("pod-name-dev", "dev", question="pod_name"),
    ValidatorCase("pod-name-dev-prefix", "dev-x", question="pod_name"),
    ValidatorCase("pod-name-40-chars", "a" * 40, question="pod_name"),
    ValidatorCase("pod-name-trailing-newline", "sample-pod\n", question="pod_name"),
    # T072 ② r2 H4(A-4): 예약 이름 — pod_snake가 템플릿 내부 이름 · Python 하드 키워드 · 표준 라이브러리 모듈 · 생성 잠금
    # 배포의 최상위 import 이름이면 생성(경로 충돌) · 기동(앱 라벨 중복 · import 가림 · SyntaxError)이 깨진다
    ValidatorCase("pod-name-reserved-tests", "tests", question="pod_name"),
    ValidatorCase("pod-name-reserved-core", "core", question="pod_name"),
    ValidatorCase("pod-name-reserved-keyword-class", "class", question="pod_name"),
    ValidatorCase("pod-name-reserved-stdlib-logging", "logging", question="pod_name"),
    ValidatorCase("pod-name-reserved-package-django", "django", question="pod_name"),
    ValidatorCase("pod-name-reserved-snake-django-common", "django-common", question="pod_name"),
    # T072 ② r3 J2(A-1 · B-2 · A-2): 템플릿 INSTALLED_APPS의 앱 라벨(contrib — has_admin과 무관하게 예약: 기동이 앱 라벨 중복으로
    # 실패한다) · 생성 트리 최상위 이름(조각 ③ · ④의 deploy/ · compose/와 pod 패키지 디렉터리가 합쳐진다 · 대소문자를 가리지 않는
    # 파일 시스템에서는 Dockerfile과 dockerfile/이 부딪혀 생성이 실패한다)
    ValidatorCase("pod-name-reserved-django-label-auth", "auth", question="pod_name"),
    ValidatorCase("pod-name-reserved-django-label-messages", "messages", question="pod_name"),
    ValidatorCase("pod-name-reserved-tree-deploy", "deploy", question="pod_name"),
    ValidatorCase("pod-name-reserved-tree-compose", "compose", question="pod_name"),
    ValidatorCase("pod-name-reserved-tree-dockerfile", "dockerfile", question="pod_name"),
    ValidatorCase("pod-snake-override", POD_NAME, ("pod_snake=wrong",), question="pod_snake"),
    ValidatorCase("owns-events-one-part", POD_NAME, ("owns_events=[bad]",), question="owns_events"),
    ValidatorCase(
        "consumes-events-quote",
        POD_NAME,
        ("""consumes_events=['other-pod.thing."created']""",),
        question="consumes_events",
        yaml_item_contains='"',
    ),
    ValidatorCase("consumes-events-two-parts", POD_NAME, ("consumes_events=[other-pod.thing]",), question="consumes_events"),
    ValidatorCase(
        "consumes-events-dev-prefix", POD_NAME, ("consumes_events=[dev.other-pod.thing.created]",), question="consumes_events"
    ),
    ValidatorCase("description-two-lines", POD_NAME, ("description=first line\nsecond line",), question="description"),
    ValidatorCase("description-121-chars", POD_NAME, ("description=" + "d" * 121,), question="description"),
    ValidatorCase("accept-sample-pod", POD_NAME),
    ValidatorCase("accept-39-chars", "a" * 39),
    ValidatorCase(
        "accept-variant-events",
        POD_NAME,
        ("owns_events=[thing.created]", "consumes_events=[other-pod.thing.created]", "description=Sample pod"),
    ),
)


def injected_answers(case: ValidatorCase) -> dict[str, object]:
    """받아들임 사례가 주입한 값 — .copier-answers.yml에 그대로 기록돼야 한다(목록 질문은 copier처럼 yaml.safe_load로 읽은 값)."""
    expected: dict[str, object] = {"pod_name": case.pod_name}
    for item in case.extra:
        key, _, value = item.partition("=")
        expected[key] = yaml.safe_load(value) if key in YAML_QUESTIONS else value
    return expected


@pytest.mark.parametrize("case", VALIDATOR_CASES, ids=[case.id for case in VALIDATOR_CASES])
def test_gen_28_copier_validators(case: ValidatorCase, tmp_path: Path) -> None:
    """D2 validator — 거부 사례: copier copy --defaults --skip-tasks --pretend --data …(하네스 venv의 copier · 대상은 임시
    경로)가 0이 아닌 종료 · stderr 마지막 줄에 'invalid <질문>:'(tests/_tree.py check_validator_rejection). copier 9.19.1은
    --data 값의 validator 실패를 ValueError 트레이스백으로 낸다 — 「트레이스백 없음」은 단언하지 않고, 트레이스백 끝 예외가 그
    질문의 validator 문구인지를 본다. 받아들임 사례(T072 r2 E4 · r1 A-4): --pretend 대신 임시 경로에 --skip-tasks로 실제로
    생성하고(종료 0) .copier-answers.yml이 주입 값(pod_name · owns_events · consumes_events · description)을 그대로 기록하는지
    본다(check_recorded_answers — 템플릿이 있어야 참이다: 빈 템플릿에서는 답변 파일이 없어 빨강)."""
    for item in case.extra:
        key, _, value = item.partition("=")
        if key in YAML_QUESTIONS:
            parsed = yaml.safe_load(value)  # copier도 yaml.safe_load로 읽는다 — 거부가 YAML 오류가 아니라 validator에서 나와야 한다
            assert isinstance(parsed, list) and all(isinstance(entry, str) for entry in parsed), f"시험 입력 {item!r}"
            assert all(case.yaml_item_contains in entry for entry in parsed), f"시험 입력 {item!r}"
    destination = tmp_path / "apps" / POD_NAME
    if case.question is None:
        argv = copier_copy_argv(case.pod_name, destination, extra_data=case.extra, skip_tasks=True)
        result = run(argv, cwd=tmp_path, timeout=VALIDATOR_TIMEOUT)
        if not result.ok:
            fail_with(result, f"정상 값({case.id})을 copier가 받아들이지 않았다(--skip-tasks 생성)")
        answers = destination / ANSWERS_FILE
        expect_no_violations(
            f"받아들임 사례 답변 기록({case.id})",
            check_recorded_answers(answers.read_text(encoding="utf-8") if answers.is_file() else None, injected_answers(case)),
        )
        return
    argv = copier_copy_argv(case.pod_name, destination, extra_data=case.extra, skip_tasks=True, pretend=True)
    result = run(argv, cwd=tmp_path, timeout=VALIDATOR_TIMEOUT)
    expect_no_violations(
        f"copier validator 거부({case.question} — {case.id})",
        check_validator_rejection(result.returncode, result.stderr, case.question),
        describe(result, "copier 출력"),
    )


# ---------- T072 변형 두 벌(no-celery · no-admin — 렌더 · 검사 전용 생성 · gen-29..32) ----------


def injected_event_problems(tree: VariantTree) -> list[str]:
    """주입한 owns_events · consumes_events가 events/__init__.py · events/consumers.py에 JSON 문자열(tojson — D2)로 있는가
    (D13). 파일이 없으면 check_generated_files_t072가 보고한다."""
    problems: list[str] = []
    targets = (
        (f"{POD_SNAKE}/events/__init__.py", tree.variant.owns_events),
        (f"{POD_SNAKE}/events/consumers.py", tree.variant.consumes_events),
    )
    for relative, values in targets:
        path = tree.path / relative
        if not values or not path.is_file():
            continue
        text = path.read_text(encoding="utf-8")
        problems.extend(
            f"{relative}에 주입 값 {json.dumps(value)} 없음(tojson — D2 · D13)" for value in values if json.dumps(value) not in text
        )
    return problems


def test_gen_29_variant_tree(variant_generated: VariantTree) -> None:
    """변형 생성(copier --skip-tasks — 픽스처) · T065 트리(uv.lock 제외) · uv.lock · .venv 없음(렌더 전용) · T072 트리(변형
    플래그대로) · 주입한 owns/consumes 값(D13)."""
    variant = variant_generated.variant
    problems = check_render_only_tree(variant_generated.path)
    problems += check_generated_files_t072(
        variant_generated.path, has_celery=variant.has_celery, has_admin=variant.has_admin, consumes=variant.consumes
    )
    problems += injected_event_problems(variant_generated)
    expect_no_violations(f"변형 {variant.name} 생성 트리", problems)


def test_gen_30_variant_kubeconform(variant_kubeconform: KubeconformRun, variant_generated: VariantTree) -> None:
    expect_no_violations(
        f"kubeconform(변형 {variant_generated.variant.name} deploy/base 렌더)",
        kubeconform_problems(variant_kubeconform),
        describe(variant_kubeconform.proc, "kubeconform 출력"),
    )


def test_gen_31_variant_manifest_assertions(variant_rendered: Rendered, variant_generated: VariantTree) -> None:
    """변형 렌더에 CHECKS 전부(has_celery=False 모드 — Deployment 1 · Job 1 · CronJob 1) + base kustomization 정적 키 + migrate Job 스크립트 =
    변형 골든(golden-cronjob.yaml) 스크립트 — UTF-8 바이트까지(T072 마지막 라운드 N2(1) · gen-14와 같은 결속)."""
    variant = variant_generated.variant
    results = run_checks(variant_rendered.docs, has_celery=variant.has_celery)
    problems = [f"[{name}] {item}" for name, items in results.items() for item in items]
    problems += check_base_kustomization(read_generated(variant_generated.path, "deploy/base/kustomization.yaml"))
    exemplar, golden_problems = golden_for(variant.name)
    problems += golden_problems
    problems += [f"[migrate 스크립트] {item}" for item in migrate_script_differences(variant_rendered.docs, exemplar)]
    expect_no_violations(f"변형 {variant.name} 렌더 단언", problems)


def test_gen_32_variant_python_imports(variant_generated: VariantTree, generated: Path, synced: ProcResult) -> None:
    """기본 pod venv(의존 상위 집합)의 python으로 변형 트리마다 manage.py check(DJANGO_SETTINGS_MODULE=tests.settings — 시험
    래퍼가 설정 env를 채운다) · settings 탐침(django.setup() + urlconf import 뒤 celery 미import · admin 구성 — tests/_tree.py
    check_variant_settings) · pytest --collect-only(내장 시험 7파일). 변형 트리에서는 uv를 돌리지 않는다."""
    variant = variant_generated.variant
    tree = variant_generated.path
    python = venv_python(generated)
    if not python.is_file():
        pytest.fail(f"기본 pod venv의 python이 없다: {python}", pytrace=False)
    settings_env: dict[str, str | None] = {"DJANGO_SETTINGS_MODULE": WRAPPER_SETTINGS, "PYTHONPATH": None}
    problems: list[str] = []
    outputs: list[str] = []
    managed = run([python, "manage.py", "check"], cwd=tree, timeout=VARIANT_PYTHON_TIMEOUT, env=settings_env)
    outputs.append(describe(managed, "manage.py check"))
    if not managed.ok:
        problems.append(f"manage.py check exit {managed.returncode}(기대 0)")
    probe = run(
        [python, "-"], cwd=tree, timeout=VARIANT_PYTHON_TIMEOUT, input_text=SETTINGS_PROBE_SCRIPT, env=settings_env
    )
    outputs.append(describe(probe, "settings 탐침"))
    facts = parse_probe_line(probe.stdout)
    if facts is None:
        problems.append(f"settings 탐침 결과(JT-PROBE 줄)를 읽지 못했다(exit {probe.returncode})")
    else:
        problems += check_variant_settings(facts, has_admin=variant.has_admin)
    collected = run(
        [python, "-m", "pytest", "--collect-only", "-q", "-p", "no:cacheprovider", "--tb=short", "--show-capture=no"],
        cwd=tree,
        timeout=COLLECT_TIMEOUT,
        env={**POD_PYTEST_ENV, "DJANGO_SETTINGS_MODULE": None},
    )
    outputs.append(describe(collected, "pytest --collect-only"))
    if not collected.ok:
        problems.append(f"pytest --collect-only exit {collected.returncode}(기대 0)")
    for relative in POD_TEST_FILES:
        if Path(relative).name not in collected.stdout:
            problems.append(f"수집 목록에 {relative} 없음")
    expect_no_violations(f"변형 {variant.name} Python(기본 pod venv)", problems, "\n".join(outputs))


# ---------- T072 이미지(gen-33 · gen-34) ----------


def test_gen_33_image_config_and_probe(
    image: ProcResult, generated: Path, mini_repo: Path, request: pytest.FixtureRequest
) -> None:
    """docker image inspect → Config.User 10001:10001 · 금지 env 0 · 라벨 revision · Config.Cmd == 이미지 CMD 상수(exec 꼴) · Config.Entrypoint
    없음(check_image_config — 마지막 라운드 N4: 셸 꼴 CMD는 PID 1이 sh라 SIGTERM이 gunicorn에 닿지 않는다) · 라벨 revision == Config.Env
    APP_GIT_SHA == image가 준 build-arg · APP_VERSION == 준 값(check_image_build_args — T072 ③ r2 M4) · image가 실제로 심은 빌드 감시
    파일 == BUILD_SENTINEL_FILES ∪ VENV_SENTINEL(check_planted_sentinels — ③ r2 M2(b)) + 생성 Dockerfile → FROM digest 핀 · USER
    10001:10001 · CMD = 이미지 CMD 상수(--no-control-socket — ③ r2 M6) · ENV 금지 이름 0 · RUN uv sync --locked · --no-dev ·
    --no-editable(따옴표 셸 꼴 포함 — check_dockerfile_text · ③ r2 M3) + 생성 Dockerfile.dockerignore → 첫 패턴 '*' · pod 안까지
    허용 목록 여섯 · 재제외 열여섯(check_dockerignore_text — ③ r2 M1 · M2(a) · 마지막 라운드 N6: 대소문자 무관 꼴 · 비밀 이름 꼴 · 마감 라운드
    Z3: 이름 꼴도 대소문자 무관 — 감시 파일 JT-HARNESS-NAME.ENV) +
    탐침(docker run --rm --network none --read-only --tmpfs /tmp --entrypoint python — uid/gid · netrc · Python 판 · django_common
    비-editable · django-ninja 1.7.0 · /src/packages 없음 · 비밀 후보 이름 0(소문자 형 — .env* · *.pem · *.key · *.crt · *.p12 · *.pfx ·
    *.env · .netrc · id_rsa* · id_ed25519* · id_ecdsa* · N6) · 최상위 허용 목록 · 감시 파일(대문자 이름 포함) · dev 전용 배포 0 —
    check_image_probe · D18 · X27)."""
    docker = require_tool("docker")
    inspected = run([docker, "image", "inspect", IMAGE_TAG], cwd=TEMPLATE_DIR, timeout=INSPECT_TIMEOUT)
    if not inspected.ok:
        fail_with(inspected, f"docker image inspect {IMAGE_TAG} 실패")
    try:
        config = json.loads(inspected.stdout)
    except json.JSONDecodeError:
        config = None
    record = request.config.stash.get(IMAGE_BUILD_RECORD, None)
    problems = check_image_config(config)
    problems += check_image_build_args(config, None if record is None else record.build_args)
    problems += check_planted_sentinels(None if record is None else record.planted, (*BUILD_SENTINEL_FILES, VENV_SENTINEL))
    problems += check_dockerfile_text(read_generated(generated, "Dockerfile"))
    problems += check_dockerignore_text(read_generated(generated, DOCKERIGNORE_FILE))
    name = smoke_container_name("probe")
    argv = docker_run_argv(docker, IMAGE_TAG, name, interactive=True, entrypoint="python", command=("-", f"/src/apps/{POD_NAME}"))
    timed_out = False
    try:
        probe = run(argv, cwd=mini_repo, timeout=IMAGE_PROBE_TIMEOUT, input_text=IMAGE_PROBE_SCRIPT)
        timed_out = probe.returncode is None
    finally:
        problems += cleanup_container(docker, name, cwd=mini_repo, run_timed_out=timed_out)
    facts = parse_probe_line(probe.stdout)
    if facts is None:
        problems.append(f"이미지 탐침 결과(JT-PROBE 줄)를 읽지 못했다(exit {probe.returncode})")
    else:
        problems += check_image_probe(facts)
    expect_no_violations("이미지 구성 · 탐침", problems, describe(probe, "이미지 탐침(docker run --entrypoint python)"))


def test_gen_34_image_startup_smoke(image_smoke: SmokeRun) -> None:
    """이미지 기동 스모크 넷(conftest.py image_smoke — D21 · X22 · X25): ① web — gunicorn 기동 · /healthz 200 · 그 뒤 :9100/metrics에
    http_requests_total 표본 ② relay — outbox_relay가 N초 뒤 살아 있고 :9464/metrics가 응답 ③ celery — D14 명령이 N초 동안
    살아 있고 /tmp/celerybeat-schedule*을 만든다(이 단언은 VD-T072-16 — 조각 ③에서 실측해 바꿀 수 있다) ④ commands —
    startup_check --wait 1 = 종료 1 · stderr 한 줄 'startup_check: FAIL <…OperationalError>' · 트레이스백 없음 / outbox_purge =
    0이 아닌 종료 · stderr에 OperationalError 예외 줄 · Unknown command · ImproperlyConfigured · ImportError ·
    ModuleNotFoundError 줄 없음(트레이스백 허용 — django-common 명령 · T072 r2 E3). 모든 스모크: 로그에 'Read-only file
    system' · PermissionError 0(상주 셋) · docker logs 성공(E9) · 출력 · HTTP 탐침 본문에 심은 비밀 값(전체 · 16자 이상 부분)
    0 · 컨테이너 정리 확인(rm -f -v · 레이블) · 이미지 빌드 앞 쓸기에 문제가 없다(T072 r3 F5 · F6 — 30분보다 오래됐거나
    jt.created가 없는 이전 세션 것은 지우고, 젊은 다른 세션 컨테이너는 「다른 하네스 세션이 실행 중일 수 있다」로 알린다)."""
    expect_no_violations(f"이미지 기동 스모크({image_smoke.kind})", list(image_smoke.problems), image_smoke.transcript)


# ---------- T072 compose(gen-35) ----------


def test_gen_35_compose_config(generated: Path, tmp_path: Path) -> None:
    """생성물에서 docker compose -f compose.dev.yml --profile "*" config --format json이 종료 0(D19)이고, 정규화한 설정 — 모든 프로필
    포함(T072 마지막 라운드 N5 · compose_config_argv: 프로필로 묶은 도구 서비스도 판정한다) — 이 계약 C4를 만족한다(T072 ③ r2 M5 ·
    check_compose_config): published 포트 전부 host_ip 127.0.0.1 · build가 아닌 image 전부 @sha256: · dragonfly command에
    --aclfile=<마운트 경로> · --primary_port_http_enabled=false(운영 Deployment와 같다) · 그 aclfile 볼륨 read_only · postgres build
    context = tests/docker/pg-tls. 자식 env는 허용 목록만(allowlist_env — 셸의 JT_DEV_*_PORT · COMPOSE_* · POSTGRES_PASSWORD가 없을 때의
    기본값으로 판정하고, 실패 출력에 셸의 비밀이 실리지 않게). 먼저 프로필 펼침 탐침(T072 마감 라운드 Z2 · 마지막 리뷰 A-2): 임시
    디렉터리에 프로필 서비스 하나만 든 compose.dev.yml(COMPOSE_PROFILE_PROBE_TEXT)을 쓰고 같은 argv · 허용 목록 env로 config를 돌려 그
    서비스가 출력에 있는지 본다(check_compose_profile_probe) — 생성물에는 프로필 서비스가 없어, '*'를 펼치지 않는 Compose에서도 아래
    판정이 공허하게 초록이 되지 않게."""
    if not (generated / COMPOSE_FILE).is_file():
        pytest.fail(f"생성물에 {COMPOSE_FILE}이 없다 — docker compose config를 돌리지 않는다", pytrace=False)
    docker = require_tool("docker")
    argv = compose_config_argv(docker)
    (tmp_path / COMPOSE_FILE).write_text(COMPOSE_PROFILE_PROBE_TEXT, encoding="utf-8", newline="\n")
    probe = run(argv, cwd=tmp_path, timeout=COMPOSE_TIMEOUT, env=allowlist_env())
    if not probe.ok:
        fail_with(probe, f'프로필 펼침 탐침 docker {" ".join(argv[1:])} 실패 — 이 Compose는 --profile "*"를 받지 못한다')
    probe_problems = check_compose_profile_probe(json_or_none(probe.stdout))
    result = run(argv, cwd=generated, timeout=COMPOSE_TIMEOUT, env=allowlist_env())
    if not result.ok:
        fail_with(result, f"docker {' '.join(argv[1:])} 실패")
    expect_no_violations(
        f"{COMPOSE_FILE}(docker compose --profile '*' config --format json — 모든 프로필)",
        probe_problems + check_compose_config(json_or_none(result.stdout), generated),
        describe(probe, "프로필 펼침 탐침(docker compose --profile '*' config — 프로필 서비스 하나만 든 임시 파일)") if probe_problems else "",
    )


# ---------- T072 copier 예약 이름(gen-37 · ③ r2 M11) ----------


def test_gen_37_reserved_pod_names_cover_template(generated: Path, synced: ProcResult) -> None:
    """copier.yml 예약 이름(pod_name validator)이 템플릿이 정하는 두 묶음을 덮는다(T072 ③ r2 M11 · ② r3 A-3): 생성물의 앱 라벨(기본
    pod venv · DJANGO_SETTINGS_MODULE=tests.settings · get_app_configs() — pod 자신 제외) ∪ 생성 트리 최상위 이름(하네스 상수 —
    REQUIRED_FILES ∪ T072_FILES ∪ 조건부 파일의 점 없는 첫 조각의 소문자 형 — ∪ 실제 생성 트리 최상위의 점 없는 snake 꼴 이름(pod 패키지 ·
    .venv · __pycache__ 제외 — generated_top_level_names · 마지막 라운드 N7: 상수를 고치지 않은 새 최상위 항목도 잡는다) — 지금은 둘 다
    dockerfile · tests · deploy · compose). 잠금 배포의 import 이름 묶음은 생성 날짜의 uv lock 결과라 보지 않는다(copier.yml 「Extract
    again」 규칙). 탐침 자식 env는 허용 목록만(allowlist_env)."""
    python = venv_python(generated)
    if not python.is_file():
        pytest.fail(f"기본 pod venv의 python이 없다: {python}", pytrace=False)
    probe = run(
        [python, "-"],
        cwd=generated,
        timeout=VARIANT_PYTHON_TIMEOUT,
        input_text=APP_LABELS_PROBE_SCRIPT,
        env=allowlist_env({"DJANGO_SETTINGS_MODULE": WRAPPER_SETTINGS}),
    )
    labels = parse_probe_line(probe.stdout)
    problems: list[str] = []
    if not (isinstance(labels, list) and all(isinstance(label, str) for label in labels)):
        problems.append(f"앱 라벨 탐침 결과(JT-PROBE 줄)를 읽지 못했다(exit {probe.returncode})")
        labels = []
    reserved = copier_reserved_names((TEMPLATE_DIR / "copier.yml").read_text(encoding="utf-8"))
    tree_names = template_top_level_names() | generated_top_level_names(generated)
    problems += check_reserved_pod_names(reserved, labels, tree_names)
    expect_no_violations("copier.yml 예약 이름(앱 라벨 · 생성 트리 최상위 이름)", problems, describe(probe, "앱 라벨 탐침"))
