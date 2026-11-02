"""렌더 검사 함수 자체의 검사 render-1..N(T065) — 지금 초록이어야 한다.

- render-1: 계약을 그대로 만족하는 합성 렌더(fixtures/golden-render.yaml) → 식별 성공 + 검사 10 전부 위반 0.
- render-2..N: 골든을 깊은 복사해 변이 하나를 넣는다 → 그 변이를 맡은 검사만 위반 ≥ 1, 나머지 검사는 위반 0
  (교차 오탐 방지). 변이 표 MUTATIONS = (id · 변이 함수 · 맡은 검사 이름).
- 골든에 kubeconform을 돌리지 않는다(스키마를 내려받는 네트워크 단계 — 실제 렌더에서 gen-7의 몫).
"""

from __future__ import annotations

import copy
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest

from tests._render import CHECKS, identify_workloads, load_docs

GOLDEN = Path(__file__).resolve().parent / "fixtures" / "golden-render.yaml"

Docs = list[dict[str, Any]]


@pytest.fixture(scope="module")
def golden() -> Docs:
    return load_docs(GOLDEN.read_text(encoding="utf-8"))


def run_checks(docs: Docs) -> dict[str, list[str]]:
    return {name: check(docs) for name, check in CHECKS.items()}


# ---------- 골든 안을 찾는 도우미 — 못 찾으면 예외(변이가 조용히 아무것도 안 바꾸는 일이 없게) ----------


def doc(docs: Docs, kind: str, name: str) -> dict[str, Any]:
    found = [d for d in docs if d.get("kind") == kind and d.get("metadata", {}).get("name") == name]
    if len(found) != 1:
        raise LookupError(f"골든에 {kind}/{name}가 {len(found)}개다")
    return found[0]


def pod_spec(document: dict[str, Any]) -> dict[str, Any]:
    return document["spec"]["template"]["spec"]


def container(document: dict[str, Any], name: str) -> dict[str, Any]:
    for item in pod_spec(document)["containers"]:
        if item["name"] == name:
            return item
    raise LookupError(f"골든 {document['kind']}/{document['metadata']['name']}에 컨테이너 {name}가 없다")


def web_deploy(docs: Docs) -> dict[str, Any]:
    return doc(docs, "Deployment", "sample-pod")


def celery_deploy(docs: Docs) -> dict[str, Any]:
    return doc(docs, "Deployment", "sample-pod-celery")


def job(docs: Docs) -> dict[str, Any]:
    return doc(docs, "Job", "sample-pod-migrate")


def web(docs: Docs) -> dict[str, Any]:
    return container(web_deploy(docs), "web")


def relay(docs: Docs) -> dict[str, Any]:
    return container(web_deploy(docs), "relay")


def celery(docs: Docs) -> dict[str, Any]:
    return container(celery_deploy(docs), "celery")


def migrate(docs: Docs) -> dict[str, Any]:
    return container(job(docs), "migrate")


def external_secret(docs: Docs, name: str) -> dict[str, Any]:
    return doc(docs, "ExternalSecret", name)


def without(items: list[dict[str, Any]], predicate: Callable[[dict[str, Any]], bool]) -> list[dict[str, Any]]:
    kept = [item for item in items if not predicate(item)]
    if len(kept) == len(items):
        raise LookupError("지울 항목이 골든에 없다")
    return kept


def ingress_paths(docs: Docs) -> list[dict[str, Any]]:
    return doc(docs, "Ingress", "sample-pod")["spec"]["rules"][0]["http"]["paths"]


def ingress_path(path: str) -> dict[str, Any]:
    return {
        "path": path,
        "pathType": "Prefix",
        "backend": {"service": {"name": "sample-pod", "port": {"name": "http"}}},
    }


# ---------- 변이 ----------

MIGRATE_SCRIPT_REORDERED = (
    "import os, subprocess, sys\n"
    "import psycopg\n"
    'code = subprocess.call([sys.executable, "manage.py", "migrate", "--noinput"])\n'
    'with psycopg.connect(os.environ["DATABASE_OWNER_URL"], autocommit=True) as conn:\n'
    '    conn.execute("REVOKE CONNECT ON DATABASE sample_pod FROM PUBLIC")\n'
    '    conn.execute("GRANT CONNECT ON DATABASE sample_pod TO sample_pod_app, sample_pod_owner")\n'
    "sys.exit(code)\n"
)


def drop_script_lines(docs: Docs, marker: str) -> None:
    command = migrate(docs)["command"]
    lines = command[2].splitlines()
    kept = [line for line in lines if marker not in line]
    if len(kept) == len(lines):
        raise LookupError(f"migrate 스크립트에 {marker!r} 줄이 없다")
    command[2] = "\n".join(kept) + "\n"


def m_pod_seccomp_removed(docs: Docs) -> None:
    del pod_spec(web_deploy(docs))["securityContext"]["seccompProfile"]


def m_pod_run_as_non_root_false(docs: Docs) -> None:
    pod_spec(celery_deploy(docs))["securityContext"]["runAsNonRoot"] = False


def m_automount_true(docs: Docs) -> None:
    pod_spec(job(docs))["automountServiceAccountToken"] = True


def m_web_read_only_root_false(docs: Docs) -> None:
    web(docs)["securityContext"]["readOnlyRootFilesystem"] = False


def m_celery_privilege_escalation_true(docs: Docs) -> None:
    celery(docs)["securityContext"]["allowPrivilegeEscalation"] = True


def m_web_tmp_volume_missing(docs: Docs) -> None:
    volumes = pod_spec(web_deploy(docs))["volumes"]
    volumes[:] = without(volumes, lambda v: v["name"] == "tmp")


def m_relay_tmp_mount_removed(docs: Docs) -> None:
    relay(docs)["volumeMounts"] = without(relay(docs)["volumeMounts"], lambda m: m["mountPath"] == "/tmp")


def m_job_tmp_volume_not_empty_dir(docs: Docs) -> None:
    volumes = pod_spec(job(docs))["volumes"]
    volumes[:] = without(volumes, lambda v: v["name"] == "tmp") + [{"name": "tmp", "configMap": {"name": "x"}}]


def m_drop_net_raw_instead_of_all(docs: Docs) -> None:
    migrate(docs)["securityContext"]["capabilities"]["drop"] = ["NET_RAW"]


def m_container_run_as_non_root_override(docs: Docs) -> None:
    celery(docs)["securityContext"]["runAsNonRoot"] = False


def m_container_seccomp_unconfined(docs: Docs) -> None:
    migrate(docs)["securityContext"]["seccompProfile"] = {"type": "Unconfined"}


def m_capabilities_add_sys_admin(docs: Docs) -> None:
    relay(docs)["securityContext"]["capabilities"]["add"] = ["SYS_ADMIN"]


def m_web_env_from_migrate_secret(docs: Docs) -> None:
    web(docs)["envFrom"].append({"secretRef": {"name": "sample-pod-migrate"}})


def m_job_env_from_env_secret(docs: Docs) -> None:
    migrate(docs)["envFrom"].append({"secretRef": {"name": "sample-pod-env"}})


def m_celery_env_secret_missing(docs: Docs) -> None:
    celery(docs)["envFrom"] = without(celery(docs)["envFrom"], lambda e: "secretRef" in e)


def m_job_migrate_secret_missing(docs: Docs) -> None:
    migrate(docs)["envFrom"] = without(migrate(docs)["envFrom"], lambda e: "secretRef" in e)


def m_relay_secret_key_ref_migrate(docs: Docs) -> None:
    relay(docs)["env"] = [
        {
            "name": "DATABASE_OWNER_URL",
            "valueFrom": {"secretKeyRef": {"name": "sample-pod-migrate", "key": "DATABASE_OWNER_URL"}},
        }
    ]


def m_web_pod_migrate_secret_volume(docs: Docs) -> None:
    pod_spec(web_deploy(docs))["volumes"].append({"name": "owner", "secret": {"secretName": "sample-pod-migrate"}})


def m_env_secret_owner_url_via_secret_key(docs: Docs) -> None:
    """템플릿 없는 꼴 — spec.data[].secretKey로 DATABASE_OWNER_URL이 런타임 Secret에 들어온다(r1 A-5)."""
    external_secret(docs, "sample-pod-env")["spec"]["data"].append(
        {"secretKey": "DATABASE_OWNER_URL", "remoteRef": {"key": "placeholder/sample-pod/db-owner", "property": "url"}}
    )


def m_env_secret_carries_owner_url(docs: Docs) -> None:
    data = external_secret(docs, "sample-pod-env")["spec"]["target"]["template"]["data"]
    data["DATABASE_OWNER_URL"] = data["DATABASE_URL"]


def m_sslmode_require(docs: Docs) -> None:
    data = external_secret(docs, "sample-pod-env")["spec"]["target"]["template"]["data"]
    data["DATABASE_URL"] = data["DATABASE_URL"].replace("sslmode=verify-full", "sslmode=require")


def m_owner_url_without_rootcert(docs: Docs) -> None:
    data = external_secret(docs, "sample-pod-migrate")["spec"]["target"]["template"]["data"]
    data["DATABASE_OWNER_URL"] = data["DATABASE_OWNER_URL"].replace("&sslrootcert=/etc/pg/ca.crt", "")


def m_env_secret_url_key_renamed(docs: Docs) -> None:
    data = external_secret(docs, "sample-pod-env")["spec"]["target"]["template"]["data"]
    data["DB_URL"] = data.pop("DATABASE_URL")


def m_relay_ca_file_path_without_sub_path(docs: Docs) -> None:
    for mount in relay(docs)["volumeMounts"]:
        if mount["name"] == "pg-ca":
            del mount["subPath"]


def m_web_ca_mount_removed(docs: Docs) -> None:
    web(docs)["volumeMounts"] = without(web(docs)["volumeMounts"], lambda m: m["name"] == "pg-ca")


def m_relay_ca_sub_path_wrong(docs: Docs) -> None:
    for mount in relay(docs)["volumeMounts"]:
        if mount["name"] == "pg-ca":
            mount["subPath"] = "tls.crt"


def m_job_ca_volume_other_secret(docs: Docs) -> None:
    for volume in pod_spec(job(docs))["volumes"]:
        if volume["name"] == "pg-ca":
            volume["secret"]["secretName"] = "pg-main-ca-copy"


def m_web_liveness_health(docs: Docs) -> None:
    web(docs)["livenessProbe"]["httpGet"]["path"] = "/health"


def m_startup_failure_threshold_10(docs: Docs) -> None:
    web(docs)["startupProbe"]["failureThreshold"] = 10


def m_startup_period_seconds_10(docs: Docs) -> None:
    web(docs)["startupProbe"]["periodSeconds"] = 10


def m_web_readiness_missing(docs: Docs) -> None:
    del web(docs)["readinessProbe"]


def m_web_liveness_metrics_port(docs: Docs) -> None:
    web(docs)["livenessProbe"]["httpGet"]["port"] = 9100


def m_relay_readiness_added(docs: Docs) -> None:
    relay(docs)["readinessProbe"] = {"tcpSocket": {"port": "metrics"}}


def m_relay_liveness_missing(docs: Docs) -> None:
    del relay(docs)["livenessProbe"]


def m_relay_startup_added(docs: Docs) -> None:
    relay(docs)["startupProbe"] = {"tcpSocket": {"port": 9464}}


def m_relay_liveness_http(docs: Docs) -> None:
    relay(docs)["livenessProbe"] = {"httpGet": {"path": "/metrics", "port": "metrics"}}


def m_relay_liveness_wrong_port(docs: Docs) -> None:
    relay(docs)["livenessProbe"]["tcpSocket"]["port"] = 9100


def m_celery_probe_on_health(docs: Docs) -> None:
    celery(docs)["livenessProbe"] = {"httpGet": {"path": "/health", "port": 8000}}


def m_web_cpu_limit(docs: Docs) -> None:
    web(docs)["resources"]["limits"]["cpu"] = "500m"


def m_max_unavailable_1(docs: Docs) -> None:
    web_deploy(docs)["spec"]["strategy"]["rollingUpdate"]["maxUnavailable"] = 1


def m_max_surge_2(docs: Docs) -> None:
    celery_deploy(docs)["spec"]["strategy"]["rollingUpdate"]["maxSurge"] = 2


def m_strategy_recreate(docs: Docs) -> None:
    celery_deploy(docs)["spec"]["strategy"] = {"type": "Recreate"}


def m_affinity_removed(docs: Docs) -> None:
    del pod_spec(web_deploy(docs))["affinity"]


def m_affinity_other_role(docs: Docs) -> None:
    node_affinity = pod_spec(celery_deploy(docs))["affinity"]["nodeAffinity"]
    preferred = node_affinity["preferredDuringSchedulingIgnoredDuringExecution"]
    preferred[0]["preference"]["matchExpressions"][0]["values"] = ["worker"]


def m_web_memory_512(docs: Docs) -> None:
    web(docs)["resources"]["requests"]["memory"] = "512Mi"


def m_celery_memory_256(docs: Docs) -> None:
    celery(docs)["resources"]["requests"]["memory"] = "256Mi"


def m_relay_memory_128(docs: Docs) -> None:
    relay(docs)["resources"]["requests"]["memory"] = "128Mi"


def m_migrate_memory_missing(docs: Docs) -> None:
    del migrate(docs)["resources"]["requests"]["memory"]


def m_revoke_removed(docs: Docs) -> None:
    drop_script_lines(docs, "REVOKE CONNECT")


def m_grant_removed(docs: Docs) -> None:
    drop_script_lines(docs, "GRANT CONNECT")


def m_migrate_step_missing(docs: Docs) -> None:
    drop_script_lines(docs, '"migrate"')


def m_revoke_after_migrate(docs: Docs) -> None:
    migrate(docs)["command"][2] = MIGRATE_SCRIPT_REORDERED


def m_init_container_without_sql_first(docs: Docs) -> None:
    waiter = copy.deepcopy(migrate(docs))
    waiter["name"] = "wait"
    waiter["command"] = ["python", "-c", "print('wait')"]
    pod_spec(job(docs))["initContainers"] = [waiter]


def m_celery_reloader_removed(docs: Docs) -> None:
    del celery_deploy(docs)["metadata"]["annotations"]["reloader.stakater.com/auto"]


def m_web_reloader_false(docs: Docs) -> None:
    web_deploy(docs)["metadata"]["annotations"]["reloader.stakater.com/auto"] = "false"


def m_scrape_removed(docs: Docs) -> None:
    del web_deploy(docs)["spec"]["template"]["metadata"]["annotations"]["k8s.grafana.com/scrape"]


def m_configmap_admin_host_removed(docs: Docs) -> None:
    del doc(docs, "ConfigMap", "sample-pod-config")["data"]["ADMIN_HOST"]


def m_celery_configmap_ref_removed(docs: Docs) -> None:
    celery(docs)["envFrom"] = without(celery(docs)["envFrom"], lambda e: "configMapRef" in e)


def m_web_configmap_ref_removed(docs: Docs) -> None:
    web(docs)["envFrom"] = without(web(docs)["envFrom"], lambda e: "configMapRef" in e)


def m_ingress_healthz_added(docs: Docs) -> None:
    ingress_paths(docs).append(ingress_path("/healthz"))


def m_ingress_tenants_removed(docs: Docs) -> None:
    paths = ingress_paths(docs)
    paths[:] = without(paths, lambda p: p["path"] == "/tenants")


def m_ingress_webhooks_added(docs: Docs) -> None:
    ingress_paths(docs).append(ingress_path("/webhooks/authentik"))


def m_ingress_ready_added(docs: Docs) -> None:
    ingress_paths(docs).append(ingress_path("/ready"))


def m_third_deployment(docs: Docs) -> None:
    duplicate = copy.deepcopy(web_deploy(docs))
    duplicate["metadata"]["name"] = "sample-pod-copy"
    docs.append(duplicate)


def m_job_hook_removed(docs: Docs) -> None:
    del job(docs)["metadata"]["annotations"]["argocd.argoproj.io/hook"]


def m_job_hook_sync(docs: Docs) -> None:
    job(docs)["metadata"]["annotations"]["argocd.argoproj.io/hook"] = "Sync"


def m_second_job(docs: Docs) -> None:
    duplicate = copy.deepcopy(job(docs))
    duplicate["metadata"]["name"] = "sample-pod-other"
    docs.append(duplicate)


def m_service_removed(docs: Docs) -> None:
    docs[:] = without(docs, lambda d: d.get("kind") == "Service")


@dataclass(frozen=True)
class Mutation:
    id: str
    apply: Callable[[Docs], None]
    owner: str


_TABLE: list[tuple[str, Callable[[Docs], None], str]] = [
    ("pod-seccomp-removed", m_pod_seccomp_removed, "security_context"),
    ("pod-run-as-non-root-false", m_pod_run_as_non_root_false, "security_context"),
    ("automount-token-true", m_automount_true, "security_context"),
    ("web-read-only-root-false", m_web_read_only_root_false, "security_context"),
    ("celery-privilege-escalation-true", m_celery_privilege_escalation_true, "security_context"),
    ("relay-tmp-mount-removed", m_relay_tmp_mount_removed, "security_context"),
    ("web-tmp-volume-missing", m_web_tmp_volume_missing, "security_context"),
    ("job-tmp-volume-not-empty-dir", m_job_tmp_volume_not_empty_dir, "security_context"),
    ("drop-net-raw-instead-of-all", m_drop_net_raw_instead_of_all, "security_context"),
    ("container-run-as-non-root-override", m_container_run_as_non_root_override, "security_context"),
    ("container-seccomp-unconfined", m_container_seccomp_unconfined, "security_context"),
    ("capabilities-add-sys-admin", m_capabilities_add_sys_admin, "security_context"),
    ("web-env-from-migrate-secret", m_web_env_from_migrate_secret, "env_split"),
    ("job-env-from-env-secret", m_job_env_from_env_secret, "env_split"),
    ("celery-env-secret-missing", m_celery_env_secret_missing, "env_split"),
    ("job-migrate-secret-missing", m_job_migrate_secret_missing, "env_split"),
    ("relay-secret-key-ref-migrate", m_relay_secret_key_ref_migrate, "env_split"),
    ("web-pod-migrate-secret-volume", m_web_pod_migrate_secret_volume, "env_split"),
    ("env-secret-carries-owner-url", m_env_secret_carries_owner_url, "env_split"),
    ("env-secret-owner-url-via-secret-key", m_env_secret_owner_url_via_secret_key, "env_split"),
    ("sslmode-require", m_sslmode_require, "db_tls"),
    ("owner-url-without-rootcert", m_owner_url_without_rootcert, "db_tls"),
    ("env-secret-url-key-renamed", m_env_secret_url_key_renamed, "db_tls"),
    ("web-ca-mount-removed", m_web_ca_mount_removed, "db_tls"),
    ("relay-ca-sub-path-wrong", m_relay_ca_sub_path_wrong, "db_tls"),
    ("relay-ca-file-path-without-sub-path", m_relay_ca_file_path_without_sub_path, "db_tls"),
    ("job-ca-volume-other-secret", m_job_ca_volume_other_secret, "db_tls"),
    ("web-liveness-health", m_web_liveness_health, "probes"),
    ("startup-failure-threshold-10", m_startup_failure_threshold_10, "probes"),
    ("startup-period-seconds-10", m_startup_period_seconds_10, "probes"),
    ("web-readiness-missing", m_web_readiness_missing, "probes"),
    ("web-liveness-metrics-port", m_web_liveness_metrics_port, "probes"),
    ("relay-readiness-added", m_relay_readiness_added, "probes"),
    ("relay-liveness-missing", m_relay_liveness_missing, "probes"),
    ("relay-startup-added", m_relay_startup_added, "probes"),
    ("relay-liveness-http", m_relay_liveness_http, "probes"),
    ("relay-liveness-wrong-port", m_relay_liveness_wrong_port, "probes"),
    ("celery-probe-on-health", m_celery_probe_on_health, "probes"),
    ("web-cpu-limit", m_web_cpu_limit, "strategy_resources"),
    ("max-unavailable-1", m_max_unavailable_1, "strategy_resources"),
    ("max-surge-2", m_max_surge_2, "strategy_resources"),
    ("strategy-recreate", m_strategy_recreate, "strategy_resources"),
    ("affinity-removed", m_affinity_removed, "strategy_resources"),
    ("affinity-other-role", m_affinity_other_role, "strategy_resources"),
    ("web-memory-512mi", m_web_memory_512, "strategy_resources"),
    ("celery-memory-256mi", m_celery_memory_256, "strategy_resources"),
    ("relay-memory-128mi", m_relay_memory_128, "strategy_resources"),
    ("migrate-memory-missing", m_migrate_memory_missing, "strategy_resources"),
    ("revoke-removed", m_revoke_removed, "migrate_sql"),
    ("grant-removed", m_grant_removed, "migrate_sql"),
    ("migrate-step-missing", m_migrate_step_missing, "migrate_sql"),
    ("revoke-after-migrate", m_revoke_after_migrate, "migrate_sql"),
    ("init-container-without-sql-first", m_init_container_without_sql_first, "migrate_sql"),
    ("celery-reloader-removed", m_celery_reloader_removed, "annotations"),
    ("web-reloader-false", m_web_reloader_false, "annotations"),
    ("scrape-annotation-removed", m_scrape_removed, "annotations"),
    ("configmap-admin-host-removed", m_configmap_admin_host_removed, "configmap"),
    ("celery-configmap-ref-removed", m_celery_configmap_ref_removed, "configmap"),
    ("web-configmap-ref-removed", m_web_configmap_ref_removed, "configmap"),
    ("ingress-healthz-added", m_ingress_healthz_added, "ingress"),
    ("ingress-tenants-removed", m_ingress_tenants_removed, "ingress"),
    ("ingress-webhooks-added", m_ingress_webhooks_added, "ingress"),
    ("ingress-ready-added", m_ingress_ready_added, "ingress"),
    ("third-deployment", m_third_deployment, "identification"),
    ("job-hook-removed", m_job_hook_removed, "identification"),
    ("job-hook-sync", m_job_hook_sync, "identification"),
    ("second-job", m_second_job, "identification"),
    ("service-removed", m_service_removed, "identification"),
]

MUTATIONS = [
    Mutation(f"render-{index:02d}-{slug}", apply, owner) for index, (slug, apply, owner) in enumerate(_TABLE, start=2)
]


def test_render_1_golden_passes_every_check(golden: Docs) -> None:
    identification = identify_workloads(golden)
    assert identification.workloads is not None, identification.violations
    assert identification.violations == []
    results = run_checks(golden)
    assert results == {name: [] for name in CHECKS}, results


@pytest.mark.parametrize("mutation", MUTATIONS, ids=[mutation.id for mutation in MUTATIONS])
def test_render_mutation_caught_only_by_owner(golden: Docs, mutation: Mutation) -> None:
    docs = copy.deepcopy(golden)
    mutation.apply(docs)
    results = run_checks(docs)
    assert results[mutation.owner], f"{mutation.id}: 맡은 검사 {mutation.owner}가 변이를 잡지 못했다"
    cross = {name: found for name, found in results.items() if name != mutation.owner and found}
    assert not cross, f"{mutation.id}: 교차 오탐 — {cross}"


def test_render_mutation_table_covers_every_check() -> None:
    ids = [mutation.id for mutation in MUTATIONS]
    assert len(ids) == len(set(ids)), "변이 id가 겹친다"
    assert len(MUTATIONS) >= 20
    owners = {mutation.owner for mutation in MUTATIONS}
    assert owners == set(CHECKS), f"변이가 없는 검사: {set(CHECKS) - owners} · 없는 검사 이름: {owners - set(CHECKS)}"


def test_render_equivalent_spellings_accepted(golden: Docs) -> None:
    """정규화 확인 — 같은 뜻의 다른 표기(메모리 수량 · 문자열 정수 · 숫자 포트)는 위반이 아니다."""
    docs = copy.deepcopy(golden)
    web(docs)["resources"]["requests"]["memory"] = "268435456"
    relay(docs)["resources"]["requests"]["memory"] = "0.09375Gi"
    web_deploy(docs)["spec"]["strategy"]["rollingUpdate"] = {"maxSurge": "1", "maxUnavailable": "0"}
    web(docs)["livenessProbe"]["httpGet"]["port"] = 8000
    relay(docs)["livenessProbe"]["tcpSocket"]["port"] = 9464
    results = run_checks(docs)
    assert results == {name: [] for name in CHECKS}, results
