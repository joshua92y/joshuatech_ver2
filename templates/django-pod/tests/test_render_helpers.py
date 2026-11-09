"""렌더 검사 함수 자체의 검사 render-1..N(T065 · T072) — 지금 초록이어야 한다.

- render-1: 계약을 그대로 만족하는 합성 렌더(fixtures/golden-render.yaml) → 식별 성공 + CHECKS 전부 위반 0.
- render-2..N: 골든을 깊은 복사해 변이 하나를 넣는다 → 그 변이를 맡은 검사만 위반 ≥ 1, 나머지 검사는 위반 0
  (교차 오탐 방지). 변이 표 MUTATIONS = (id · 변이 함수 · 맡은 검사 이름). render-02..69는 T065, render-70부터는 T072
  (설계 design/t072-design.md D21 — 새 검사마다 ≥ 2 · 확장마다 ≥ 1).
- has_celery=false 변형(T072): fixtures/golden-cronjob.yaml(골든 − celery Deployment + CronJob)을 has_celery=False로 돌려
  위반 0, _CRON_TABLE의 변이마다 맡은 검사만 위반. 두 골든을 서로의 모드로 돌리면 identification이 실패한다.
- T072 r2(리뷰 r1 반영): render-156부터 · cron-22부터 표 끝에 덧붙였다(E5 격리 · E1 runtime_wiring env 배선 · E2 ES 항목 ·
  E6 Service 결속 · CronJob suspend). 골든 migrate Job 스크립트는 본보기라(E7) 가짜 psycopg로 실제로 돌려 꼴을 굳힌다.
- T072 r3(리뷰 r2 반영): render-177 · 178(F1) — 정본 원천을 envFrom으로 참조한 컨테이너는 prefix가 붙은 실효 이름만 필수
  이름으로 센다(relay <pod>-config · migrate <pod>-migrate에 prefix X_).
- T072 ③ r2(M6 · 조각 ③ 리뷰 A-6): render-184..186 — runtime_wiring이 deploy 명령을 시험한 명령에 묶는다(web = 이미지 CMD 또는 그
  토큰 · relay · celery = _render 상수) + 같은 뜻 표기 받아들임.
- T072 마지막 라운드(N1 · N2(1) · N3): 골든 migrate 스크립트의 접속 루프 밖 실패 처리 · 경계 SQL 재시도(가짜 psycopg에 errors 모듈과 연결마다
  경계 SQL 계획 · 자식 env는 허용 목록) · 렌더 ≅ 골든 판정(golden_differences — gen-38) · migrate 스크립트 바이트 결속(migrate_script_differences
  — gen-14 · gen-31)의 골든 · 변이. 이 판정은 CHECKS가 아니다(골든과의 거리 — 교차 판정 밖).
- 골든에 kubeconform을 돌리지 않는다(스키마를 내려받는 네트워크 단계 — 실제 렌더에서 gen-7 · gen-30의 몫).
"""

from __future__ import annotations

import copy
import sys
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest

from tests import _render
from tests._layout import VARIANTS
from tests._proc import ProcResult, allowlist_env, run
from tests._render import CHECKS, identify_workloads, load_docs, run_checks

GOLDEN = Path(__file__).resolve().parent / "fixtures" / "golden-render.yaml"
GOLDEN_CRON = Path(__file__).resolve().parent / "fixtures" / "golden-cronjob.yaml"

IMAGE = "ghcr.io/joshua92y/sample-pod"
ENV_ES = "sample-pod-env"
MIGRATE_ES = "sample-pod-migrate"
CRONJOB = "sample-pod-outbox-purge"
WAVE = "argocd.argoproj.io/sync-wave"
HOOK = "argocd.argoproj.io/hook"
HOOK_DELETE_POLICY = "argocd.argoproj.io/hook-delete-policy"
ENTRYPOINTS = "traefik.ingress.kubernetes.io/router.entrypoints"
ROUTER_TLS = "traefik.ingress.kubernetes.io/router.tls"

Docs = list[dict[str, Any]]


@pytest.fixture(scope="module")
def golden() -> Docs:
    return load_docs(GOLDEN.read_text(encoding="utf-8"))


@pytest.fixture(scope="module")
def cron_golden() -> Docs:
    return load_docs(GOLDEN_CRON.read_text(encoding="utf-8"))


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


# ---------- T072 도우미 — 같은 규칙(못 찾으면 예외) ----------


def named(items: list[dict[str, Any]], name: str, what: str) -> dict[str, Any]:
    found = [item for item in items if item.get("name") == name]
    if len(found) != 1:
        raise LookupError(f"골든에 {what} {name}가 {len(found)}개다")
    return found[0]


def init(docs: Docs) -> dict[str, Any]:
    """web pod의 initContainer startup-check."""
    return named(pod_spec(web_deploy(docs))["initContainers"], "startup-check", "initContainer")


def configmap(docs: Docs) -> dict[str, Any]:
    return doc(docs, "ConfigMap", "sample-pod-config")


def ingress(docs: Docs) -> dict[str, Any]:
    return doc(docs, "Ingress", "sample-pod")


def ingress_entry(docs: Docs, path: str) -> dict[str, Any]:
    found = [item for item in ingress_paths(docs) if item["path"] == path]
    if len(found) != 1:
        raise LookupError(f"골든 Ingress에 경로 {path}가 {len(found)}개다")
    return found[0]


def annotations(document: dict[str, Any]) -> dict[str, Any]:
    return document["metadata"]["annotations"]


def env_entry(item: dict[str, Any], name: str) -> dict[str, Any]:
    return named(item["env"], name, f"컨테이너 {item['name']}의 env")


def mount_named(item: dict[str, Any], name: str) -> dict[str, Any]:
    return named(item["volumeMounts"], name, f"컨테이너 {item['name']}의 volumeMount")


def volume_named(spec: dict[str, Any], name: str) -> dict[str, Any]:
    return named(spec["volumes"], name, "volume")


def es_spec(docs: Docs, name: str) -> dict[str, Any]:
    return external_secret(docs, name)["spec"]


def es_template_data(docs: Docs, name: str) -> dict[str, Any]:
    return es_spec(docs, name)["target"]["template"]["data"]


def cron_job(docs: Docs) -> dict[str, Any]:
    return doc(docs, "CronJob", CRONJOB)


def cron_pod_spec(document: dict[str, Any]) -> dict[str, Any]:
    return document["spec"]["jobTemplate"]["spec"]["template"]["spec"]


def purge(docs: Docs) -> dict[str, Any]:
    """변형 골든 CronJob의 컨테이너 outbox-purge."""
    return named(cron_pod_spec(cron_job(docs))["containers"], "outbox-purge", "CronJob 컨테이너")


def golden_document(path: Path, kind: str, name: str) -> dict[str, Any]:
    """다른 골든 파일의 문서 하나(깊은 복사) — 변이가 문서를 통째로 더할 때 쓴다."""
    return copy.deepcopy(doc(load_docs(path.read_text(encoding="utf-8")), kind, name))


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
    """T072: configMap 볼륨이던 것을 PVC로 바꿨다 — Job의 ConfigMap 참조는 hook_order가 따로 잡으므로(설계 X1) 이 변이는
    "/tmp가 emptyDir가 아님"만 어긴다."""
    volumes = pod_spec(job(docs))["volumes"]
    volumes[:] = without(volumes, lambda v: v["name"] == "tmp") + [{"name": "tmp", "persistentVolumeClaim": {"claimName": "x"}}]


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
    """T072: env 목록을 바꿔 끼우던 것을 덧붙이기로 바꿨다 — 골든 relay env의 POD_NAMESPACE(runtime_wiring)를 지우지 않고
    secretKeyRef로 <pod>-migrate를 참조하는 것만 어긴다."""
    relay(docs)["env"].append(
        {
            "name": "DATABASE_OWNER_URL",
            "valueFrom": {"secretKeyRef": {"name": "sample-pod-migrate", "key": "DATABASE_OWNER_URL"}},
        }
    )


def m_web_pod_migrate_secret_volume(docs: Docs) -> None:
    pod_spec(web_deploy(docs))["volumes"].append({"name": "owner", "secret": {"secretName": "sample-pod-migrate"}})


def m_env_secret_owner_url_via_secret_key(docs: Docs) -> None:
    """템플릿 없는 꼴 — spec.data[].secretKey로 DATABASE_OWNER_URL이 런타임 Secret에 들어온다(r1 A-5).
    T072: 원격 키를 dev 값으로 바꿨다(자리값 키는 external_secrets가 따로 잡는다 — 설계 X1)."""
    external_secret(docs, "sample-pod-env")["spec"]["data"].append(
        {"secretKey": "DATABASE_OWNER_URL", "remoteRef": {"key": "dev/db/dev_sample_pod/owner", "property": "url"}}
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


# ---------- T072 변이(render-70부터) — 검사마다 맡은 규칙 하나만 어긴다 ----------

# pod_lifecycle(gen-19)


def m_web_grace_30(docs: Docs) -> None:
    pod_spec(web_deploy(docs))["terminationGracePeriodSeconds"] = 30


def m_web_grace_removed(docs: Docs) -> None:
    del pod_spec(web_deploy(docs))["terminationGracePeriodSeconds"]


def m_web_readiness_timeout_1(docs: Docs) -> None:
    web(docs)["readinessProbe"]["timeoutSeconds"] = 1


def m_web_startup_timeout_missing(docs: Docs) -> None:
    """timeoutSeconds가 없으면 kubelet 기본 1 s다."""
    del web(docs)["startupProbe"]["timeoutSeconds"]


def m_web_liveness_timeout_1(docs: Docs) -> None:
    web(docs)["livenessProbe"]["timeoutSeconds"] = 1


def m_web_pod_ip_removed(docs: Docs) -> None:
    web(docs)["env"] = without(web(docs)["env"], lambda e: e["name"] == "POD_IP")


def m_web_pod_ip_host_ip(docs: Docs) -> None:
    env_entry(web(docs), "POD_IP")["valueFrom"]["fieldRef"]["fieldPath"] = "status.hostIP"


def m_web_pre_stop_removed(docs: Docs) -> None:
    del web(docs)["lifecycle"]


def m_web_pre_stop_sleep_1(docs: Docs) -> None:
    web(docs)["lifecycle"]["preStop"]["sleep"]["seconds"] = 1


# env_hygiene(gen-20)


def m_relay_env_prometheus_multiproc(docs: Docs) -> None:
    relay(docs)["env"].append({"name": "PROMETHEUS_MULTIPROC_DIR", "value": "/tmp/prometheus"})


def m_configmap_prometheus_multiproc(docs: Docs) -> None:
    configmap(docs)["data"]["PROMETHEUS_MULTIPROC_DIR"] = "/tmp/prometheus"


def m_env_secret_template_prometheus_multiproc(docs: Docs) -> None:
    es_template_data(docs, ENV_ES)["PROMETHEUS_MULTIPROC_DIR"] = "/tmp/prometheus"


def m_web_env_netrc(docs: Docs) -> None:
    web(docs)["env"].append({"name": "NETRC", "value": "/tmp/netrc"})


def m_celery_env_https_proxy_lowercase(docs: Docs) -> None:
    celery(docs)["env"].append({"name": "https_proxy", "value": "http://proxy.invalid"})


def m_init_env_sslkeylogfile(docs: Docs) -> None:
    init(docs)["env"].append({"name": "SSLKEYLOGFILE", "value": "/tmp/tls.log"})


def m_configmap_requests_ca_bundle(docs: Docs) -> None:
    configmap(docs)["data"]["REQUESTS_CA_BUNDLE"] = "/etc/pg/ca.crt"


def m_job_env_client_key_file(docs: Docs) -> None:
    migrate(docs)["env"].append({"name": "CLIENT_KEY_FILE", "value": "/tmp/client.key"})


def m_web_env_from_https_prefix_proxy_key(docs: Docs) -> None:
    """prefix + ConfigMap 키로 만든 이름(HTTPS_ + PROXY) — 실효 env 이름 계산을 본다."""
    configmap(docs)["data"]["PROXY"] = "http://proxy.invalid"
    web(docs)["envFrom"].append({"prefix": "HTTPS_", "configMapRef": {"name": "sample-pod-config"}})


def m_relay_env_from_out_of_render_configmap(docs: Docs) -> None:
    relay(docs)["envFrom"].append({"configMapRef": {"name": "sample-pod-extra"}})


def m_celery_env_from_out_of_render_secret(docs: Docs) -> None:
    celery(docs)["envFrom"].append({"secretRef": {"name": "sample-pod-extra"}})


def m_relay_env_pgoptions(docs: Docs) -> None:
    relay(docs)["env"].append({"name": "PGOPTIONS", "value": "-c statement_timeout=0"})


def m_web_env_ssl_cert_dir(docs: Docs) -> None:
    web(docs)["env"].append({"name": "SSL_CERT_DIR", "value": "/etc/ssl/certs"})


def m_configmap_sentry_print_envelopes(docs: Docs) -> None:
    configmap(docs)["data"]["SENTRY_PRINT_ENVELOPES"] = "true"


def m_celery_env_pythonpath(docs: Docs) -> None:
    celery(docs)["env"].append({"name": "PYTHONPATH", "value": "/tmp"})


# external_secrets(gen-21)


def m_env_secret_placeholder_store(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["secretStoreRef"]["name"] = "placeholder-store"


def m_migrate_secret_key_placeholder(docs: Docs) -> None:
    es_spec(docs, MIGRATE_ES)["data"][0]["remoteRef"]["key"] = "placeholder/sample-pod/db-owner"


def m_env_secret_api_version_v1beta1(docs: Docs) -> None:
    external_secret(docs, ENV_ES)["apiVersion"] = "external-secrets.io/v1beta1"


def m_env_secret_data_from_extract(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["dataFrom"] = [{"extract": {"key": "dev/db/dev_sample_pod/app"}}]


def m_env_secret_template_from(docs: Docs) -> None:
    template = es_spec(docs, ENV_ES)["target"]["template"]
    template["templateFrom"] = [{"configMap": {"name": "sample-pod-config", "items": [{"key": "ENV"}]}}]


def m_env_secret_merge_policy_merge(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["target"]["template"]["mergePolicy"] = "Merge"


def m_migrate_secret_refresh_1h(docs: Docs) -> None:
    es_spec(docs, MIGRATE_ES)["refreshInterval"] = "1h"


def m_env_secret_refresh_policy_removed(docs: Docs) -> None:
    del es_spec(docs, ENV_ES)["refreshPolicy"]


def m_migrate_secret_creation_policy_orphan(docs: Docs) -> None:
    es_spec(docs, MIGRATE_ES)["target"]["creationPolicy"] = "Orphan"


def m_env_secret_workers_path(docs: Docs) -> None:
    """Workers 전용 경로((dev|prod)/(access|web)/) — 정규식은 통과하지만 pod 반입 금지(gitops 3.7)."""
    es_spec(docs, ENV_ES)["data"][2]["remoteRef"]["key"] = "dev/access/sample-pod"


def m_env_secret_property_missing(docs: Docs) -> None:
    del es_spec(docs, ENV_ES)["data"][0]["remoteRef"]["property"]


def m_migrate_secret_engine_version_v1(docs: Docs) -> None:
    es_spec(docs, MIGRATE_ES)["target"]["template"]["engineVersion"] = "v1"


def m_env_secret_store_kind_namespaced(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["secretStoreRef"]["kind"] = "SecretStore"


def m_env_secret_data_source_ref(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["data"][0]["sourceRef"] = {"storeRef": {"kind": "ClusterSecretStore", "name": "vault-prod"}}


# hook_order(gen-22)


def m_migrate_secret_hook_removed(docs: Docs) -> None:
    del annotations(external_secret(docs, MIGRATE_ES))[HOOK]


def m_migrate_secret_wave_0(docs: Docs) -> None:
    annotations(external_secret(docs, MIGRATE_ES))[WAVE] = "0"


def m_migrate_secret_delete_policy_removed(docs: Docs) -> None:
    del annotations(external_secret(docs, MIGRATE_ES))[HOOK_DELETE_POLICY]


def m_job_configmap_ref(docs: Docs) -> None:
    migrate(docs)["envFrom"].append({"configMapRef": {"name": "sample-pod-config"}})


def m_job_configmap_volume(docs: Docs) -> None:
    pod_spec(job(docs))["volumes"].append({"name": "config", "configMap": {"name": "sample-pod-config"}})


def m_env_secret_hook_added(docs: Docs) -> None:
    annotations(external_secret(docs, ENV_ES))[HOOK] = "PreSync"


def m_configmap_wave_removed(docs: Docs) -> None:
    del annotations(configmap(docs))[WAVE]


def m_job_wave_before_migrate_secret(docs: Docs) -> None:
    annotations(job(docs))[WAVE] = "-2"


# images(gen-23)


def m_web_image_tag(docs: Docs) -> None:
    web(docs)["image"] = IMAGE + ":latest"


def m_relay_image_digest(docs: Docs) -> None:
    relay(docs)["image"] = IMAGE + "@sha256:" + "0" * 64


def m_celery_image_other_name(docs: Docs) -> None:
    celery(docs)["image"] = "ghcr.io/joshua92y/other-pod"


def m_init_image_tag(docs: Docs) -> None:
    init(docs)["image"] = IMAGE + ":placeholder"


def m_migrate_image_other_registry(docs: Docs) -> None:
    migrate(docs)["image"] = "docker.io/joshua92y/sample-pod"


def m_namespace_set(docs: Docs) -> None:
    """base에 namespace를 두면 렌더 문서마다 metadata.namespace가 붙는다(kustomization namespace의 렌더 쪽 흔적)."""
    configmap(docs)["metadata"]["namespace"] = "jt-dev"


# cronjob(gen-24) — 기본 렌더(has_celery=true)에는 CronJob이 없어야 한다


def m_default_render_cronjob(docs: Docs) -> None:
    docs.append(golden_document(GOLDEN_CRON, "CronJob", CRONJOB))


def m_default_render_cronjob_other_name(docs: Docs) -> None:
    extra = golden_document(GOLDEN_CRON, "CronJob", CRONJOB)
    extra["metadata"]["name"] = "sample-pod-report"
    docs.append(extra)


# runtime_wiring(gen-36)


def m_init_removed(docs: Docs) -> None:
    del pod_spec(web_deploy(docs))["initContainers"]


def m_init_command_other(docs: Docs) -> None:
    init(docs)["command"] = ["python", "manage.py", "check"]


def m_init_env_secret_removed(docs: Docs) -> None:
    init(docs)["envFrom"] = without(init(docs)["envFrom"], lambda e: "secretRef" in e)


def m_init_configmap_ref_removed(docs: Docs) -> None:
    init(docs)["envFrom"] = without(init(docs)["envFrom"], lambda e: "configMapRef" in e)


def m_web_kafka_ca_mount_removed(docs: Docs) -> None:
    web(docs)["volumeMounts"] = without(web(docs)["volumeMounts"], lambda m: m["name"] == "kafka-ca")


def m_relay_kafka_ca_mount_path_other(docs: Docs) -> None:
    mount_named(relay(docs), "kafka-ca")["mountPath"] = "/etc/kafka-ca"


def m_relay_kafka_ca_writable(docs: Docs) -> None:
    mount_named(relay(docs), "kafka-ca")["readOnly"] = False


def m_kafka_ca_secret_name_typo(docs: Docs) -> None:
    volume_named(pod_spec(web_deploy(docs)), "kafka-ca")["secret"]["secretName"] = "jt-kafka-cluster-ca-crt"


def m_web_metrics_port_removed(docs: Docs) -> None:
    web(docs)["ports"] = without(web(docs)["ports"], lambda p: p["containerPort"] == 9100)


def m_web_memory_limit_1gi(docs: Docs) -> None:
    web(docs)["resources"]["limits"]["memory"] = "1Gi"


def m_celery_memory_limit_384(docs: Docs) -> None:
    celery(docs)["resources"]["limits"]["memory"] = "384Mi"


def m_migrate_memory_limit_1gi(docs: Docs) -> None:
    migrate(docs)["resources"]["limits"]["memory"] = "1Gi"


def m_init_limits_removed(docs: Docs) -> None:
    del init(docs)["resources"]["limits"]


def m_init_memory_request_256(docs: Docs) -> None:
    init(docs)["resources"]["requests"]["memory"] = "256Mi"


def m_relay_pod_namespace_removed(docs: Docs) -> None:
    relay(docs)["env"] = without(relay(docs)["env"], lambda e: e["name"] == "POD_NAMESPACE")


def m_celery_pod_namespace_field_path_name(docs: Docs) -> None:
    env_entry(celery(docs), "POD_NAMESPACE")["valueFrom"]["fieldRef"]["fieldPath"] = "metadata.name"


def m_job_pod_namespace_added(docs: Docs) -> None:
    migrate(docs)["env"].append({"name": "POD_NAMESPACE", "valueFrom": {"fieldRef": {"fieldPath": "metadata.namespace"}}})


def m_configmap_value_trailing_newline(docs: Docs) -> None:
    """블록 스칼라 |의 끝 줄바꿈 꼴."""
    configmap(docs)["data"]["ALLOWED_HOSTS"] += "\n"


def m_env_secret_template_value_leading_space(docs: Docs) -> None:
    data = es_template_data(docs, ENV_ES)
    data["KAFKA_PASSWORD"] = " " + data["KAFKA_PASSWORD"]


# security_context(gen-9) 확장 — runAsUser · runAsGroup 10001(정수)


def m_web_pod_run_as_user_removed(docs: Docs) -> None:
    del pod_spec(web_deploy(docs))["securityContext"]["runAsUser"]


def m_job_pod_run_as_group_0(docs: Docs) -> None:
    pod_spec(job(docs))["securityContext"]["runAsGroup"] = 0


def m_celery_container_run_as_user_0(docs: Docs) -> None:
    celery(docs)["securityContext"]["runAsUser"] = 0


def m_relay_container_run_as_group_string(docs: Docs) -> None:
    """숫자 문자열은 정수가 아니다."""
    relay(docs)["securityContext"]["runAsGroup"] = "10001"


# ingress(gen-17) 확장


def m_ingress_class_nginx(docs: Docs) -> None:
    ingress(docs)["spec"]["ingressClassName"] = "nginx"


def m_ingress_entrypoints_removed(docs: Docs) -> None:
    del annotations(ingress(docs))[ENTRYPOINTS]


def m_ingress_router_tls_false(docs: Docs) -> None:
    annotations(ingress(docs))[ROUTER_TLS] = "false"


def m_ingress_spec_tls_added(docs: Docs) -> None:
    ingress(docs)["spec"]["tls"] = [{"hosts": ["PLACEHOLDER.joshuatech.dev"]}]


def m_ingress_host_invalid(docs: Docs) -> None:
    ingress(docs)["spec"]["rules"][0]["host"] = "sample-pod.placeholder.invalid"


def m_ingress_health_prefix(docs: Docs) -> None:
    ingress_entry(docs, "/health")["pathType"] = "Prefix"


def m_ingress_session_exact(docs: Docs) -> None:
    ingress_entry(docs, "/session")["pathType"] = "Exact"


def m_ingress_backend_port_number(docs: Docs) -> None:
    ingress_entry(docs, "/api")["backend"]["service"]["port"] = {"number": 80}


# db_tls(gen-11) 확장 — web pod initContainer도 pg-main-ca를 마운트한다


def m_init_pg_ca_mount_removed(docs: Docs) -> None:
    init(docs)["volumeMounts"] = without(init(docs)["volumeMounts"], lambda m: m["name"] == "pg-ca")


# ---------- T072 r2 변이(render-156부터 — 리뷰 r1 반영 E5 · E1 · E2 · E6) ----------

# env_hygiene · external_secrets 격리(E5 — 그 규칙만 걸리는 변이)


def unreferenced_configmap(key: str) -> dict[str, Any]:
    """어떤 컨테이너도 참조하지 않는 ConfigMap(sync-wave -1) — env_hygiene의 「모든 ConfigMap 키」 규칙만 걸리게 한다
    (참조하는 ConfigMap에 넣으면 실효 env 규칙이 먼저 잡는다)."""
    return {
        "apiVersion": "v1",
        "kind": "ConfigMap",
        "metadata": {
            "name": "sample-pod-unused",
            "labels": {"app.kubernetes.io/name": "sample-pod"},
            "annotations": {WAVE: "-1"},
        },
        "data": {key: "/tmp/prometheus"},
    }


def m_unreferenced_configmap_prometheus_multiproc(docs: Docs) -> None:
    docs.append(unreferenced_configmap("PROMETHEUS_MULTIPROC_DIR"))


def m_env_secret_target_name_removed(docs: Docs) -> None:
    """target.name이 없으면 ESO는 ES 이름을 쓴다 — 만들어지는 Secret은 같고 external_secrets의 target.name 규칙만 어긴다."""
    del es_spec(docs, ENV_ES)["target"]["name"]


def m_unreferenced_configmap_prometheus_multiproc_lowercase(docs: Docs) -> None:
    """키 비교는 ASCII 대소문자 무시다."""
    docs.append(unreferenced_configmap("prometheus_multiproc_dir"))


# runtime_wiring(E1 · A-1 · X7) — migrate 프로필 · 런타임 envFrom · 런타임 필수 설정 이름

RUNTIME_CONFIGMAP_KEYS = ("ENV", "KAFKA_BOOTSTRAP", "KAFKA_USERNAME", "ACCESS_TEAM_DOMAIN", "AUTHENTIK_AUDIENCE")
RUNTIME_SECRET_TEMPLATE_KEYS = ("SECRET_KEY", "KAFKA_PASSWORD", "DRAGONFLY_URL")


def m_migrate_settings_profile_removed(docs: Docs) -> None:
    """A-1 ① — Job이 runtime 프로필로 떠 DATABASE_OWNER_URL을 거부하고 DATABASE_URL 없음으로 죽는다."""
    migrate(docs)["env"] = without(migrate(docs)["env"], lambda e: e["name"] == "JT_SETTINGS_PROFILE")


def m_relay_configmap_ref_removed(docs: Docs) -> None:
    """A-1 ② — relay가 ALLOWED_HOSTS · ENV 없이 settings를 적재한다(configmap 검사는 relay를 보지 않는다)."""
    relay(docs)["envFrom"] = without(relay(docs)["envFrom"], lambda e: "configMapRef" in e)


def m_configmap_runtime_keys_removed(docs: Docs) -> None:
    """A-1 ③ — 키 5(configmap 검사의 몫) 밖의 런타임 필수 ConfigMap 키."""
    data = configmap(docs)["data"]
    for key in RUNTIME_CONFIGMAP_KEYS:
        del data[key]


def m_env_secret_runtime_keys_removed(docs: Docs) -> None:
    """A-1 ④ — <pod>-env 템플릿에서 런타임 비밀 키를 뺀다(data[] 항목은 그대로 — 참조 규칙은 지킨다)."""
    data = es_template_data(docs, ENV_ES)
    for key in RUNTIME_SECRET_TEMPLATE_KEYS:
        del data[key]


def m_migrate_secret_runtime_key_added(docs: Docs) -> None:
    """X7 — <pod>-migrate에 런타임 키(KAFKA_PASSWORD)를 더해 owner 비밀의 범위를 넓힌다(data[] 항목 + 템플릿 키 — ES
    규칙 · 순번 data[0,1]은 지킨다)."""
    spec = es_spec(docs, MIGRATE_ES)
    spec["data"].append({"secretKey": "kafka_password", "remoteRef": {"key": "dev/kafka/sample-pod", "property": "password"}})
    spec["target"]["template"]["data"]["KAFKA_PASSWORD"] = "{{ .kafka_password }}"


def m_migrate_settings_profile_runtime(docs: Docs) -> None:
    env_entry(migrate(docs), "JT_SETTINGS_PROFILE")["value"] = "runtime"


def m_configmap_settings_profile_key(docs: Docs) -> None:
    """런타임 컨테이너 전부의 실효 env에 JT_SETTINGS_PROFILE이 생긴다(프로필은 migrate Job만)."""
    configmap(docs)["data"]["JT_SETTINGS_PROFILE"] = "runtime"


def m_web_env_secret_key_ref_only(docs: Docs) -> None:
    """<pod>-env를 envFrom 대신 secretKeyRef로만 — env_split(참조 있음)은 통과하고 envFrom 규칙만 어긴다."""
    web(docs)["envFrom"] = without(web(docs)["envFrom"], lambda e: "secretRef" in e)
    web(docs)["env"].append({"name": "DATABASE_URL", "valueFrom": {"secretKeyRef": {"name": ENV_ES, "key": "DATABASE_URL"}}})


def m_celery_other_complete_configmap(docs: Docs) -> None:
    """키 5를 모두 가진 다른 ConfigMap을 celery가 참조 — configmap(완전한 ConfigMap 참조)은 통과하고 <pod>-config 이름
    규칙만 어긴다."""
    other = copy.deepcopy(configmap(docs))
    other["metadata"]["name"] = "sample-pod-config-copy"
    docs.append(other)
    for item in celery(docs)["envFrom"]:
        if "configMapRef" in item:
            item["configMapRef"]["name"] = "sample-pod-config-copy"


# external_secrets(E2 · A-2) — data[] 개수 · 템플릿 참조 · 순번(D20 표)


def m_env_secret_data_empty(docs: Docs) -> None:
    es_spec(docs, ENV_ES)["data"] = []


def m_env_secret_data_order_swapped(docs: Docs) -> None:
    data = es_spec(docs, ENV_ES)["data"]
    data[0], data[7] = data[7], data[0]


def m_env_secret_template_ref_typo(docs: Docs) -> None:
    es_template_data(docs, ENV_ES)["KAFKA_PASSWORD"] = "{{ .kafka_pasword }}"


def m_migrate_secret_data_order_swapped(docs: Docs) -> None:
    data = es_spec(docs, MIGRATE_ES)["data"]
    data[0], data[1] = data[1], data[0]


# ingress(E6 · A-6) — backend가 가리키는 Service와의 결속


def service(docs: Docs) -> dict[str, Any]:
    return doc(docs, "Service", "sample-pod")


def service_http_port(docs: Docs) -> dict[str, Any]:
    return named(service(docs)["spec"]["ports"], "http", "Service 포트")


def m_service_port_name_other(docs: Docs) -> None:
    service_http_port(docs)["name"] = "web"


def m_service_target_port_metrics(docs: Docs) -> None:
    service_http_port(docs)["targetPort"] = "metrics"


def m_service_selector_component_api(docs: Docs) -> None:
    service(docs)["spec"]["selector"]["app.kubernetes.io/component"] = "api"


def m_ingress_backend_service_other(docs: Docs) -> None:
    """/api가 503이 된다(없는 Service)."""
    ingress_entry(docs, "/api")["backend"]["service"]["name"] = "other"


def m_service_selector_matches_celery(docs: Docs) -> None:
    """component를 빼면 selector가 celery · migrate pod도 고른다(8000이 없는 pod로 요청이 간다)."""
    del service(docs)["spec"]["selector"]["app.kubernetes.io/component"]


# runtime_wiring(T072 r3 F1 · r2 A-1) — envFrom prefix는 정본 원천 키의 이름을 바꾼다(실효 env = prefix + 키). 참조 이름은
# 그대로라 참조 규칙은 지나가고, 필수 이름 규칙이 원천 내용 대신 실효 env를 볼 때만 잡힌다.


def env_from_entry(item: dict[str, Any], ref_key: str, name: str) -> dict[str, Any]:
    found = [entry for entry in item["envFrom"] if entry.get(ref_key, {}).get("name") == name]
    if len(found) != 1:
        raise LookupError(f"골든 컨테이너 {item['name']}에 envFrom {ref_key} {name}가 {len(found)}개다")
    return found[0]


def m_relay_configmap_env_from_prefix(docs: Docs) -> None:
    """relay가 <pod>-config를 prefix X_로 받는다 — ENV · ALLOWED_HOSTS 따위가 X_ENV · X_ALLOWED_HOSTS가 되어 settings가 죽는다."""
    env_from_entry(relay(docs), "configMapRef", "sample-pod-config")["prefix"] = "X_"


def m_migrate_secret_env_from_prefix(docs: Docs) -> None:
    """migrate가 <pod>-migrate를 prefix X_로 받는다 — DATABASE_OWNER_URL이 X_DATABASE_OWNER_URL이 되어 migrate 프로필이 죽는다
    (migrate 필수 이름 분기가 잡는다)."""
    env_from_entry(migrate(docs), "secretRef", MIGRATE_ES)["prefix"] = "X_"


# env_hygiene(T072 ② r2 H10 · B-2) — 검증된 설정을 대신하는 env: Celery broker · result URL(app.conf = DRAGONFLY_URL보다 먼저 읽는다) ·
# GUNICORN_CMD_ARGS(gunicorn_conf를 덮는다). 생성 pod의 기동 단언(startup.run)도 거부한다 — 여기는 매니페스트 쪽 방어선이다.


def m_celery_env_celery_broker_url(docs: Docs) -> None:
    celery(docs)["env"].append({"name": "CELERY_BROKER_URL", "value": "redis://cache.invalid:6379/0"})


def m_relay_env_celery_broker_read_url_lowercase(docs: Docs) -> None:
    relay(docs)["env"].append({"name": "celery_broker_read_url", "value": "redis://cache.invalid:6379/0"})


def m_configmap_celery_broker_write_url(docs: Docs) -> None:
    configmap(docs)["data"]["CELERY_BROKER_WRITE_URL"] = "redis://cache.invalid:6379/0"


def m_init_env_celery_result_backend(docs: Docs) -> None:
    init(docs)["env"].append({"name": "CELERY_RESULT_BACKEND", "value": "redis://cache.invalid:6379/1"})


def m_web_env_gunicorn_cmd_args(docs: Docs) -> None:
    web(docs)["env"].append({"name": "GUNICORN_CMD_ARGS", "value": "--workers 4 --preload"})


# runtime_wiring(T072 ③ r2 M6 · 조각 ③ 리뷰 A-6) — deploy 명령 결속: web은 command · args 없음(이미지 CMD) 또는 정확히 이미지 CMD
# 토큰 · relay = python manage.py outbox_relay · celery = D14 명령(Linux --beat 꼴). gen-34 스모크 · gen-33 Dockerfile CMD 정적 검사와
# 같은 상수(_render.WEB_COMMAND · RELAY_COMMAND · CELERY_COMMAND)다 — 읽기 전용 루트에서 시험한 명령과 deploy 명령이 어긋나면 잡는다.


def m_relay_command_typo(docs: Docs) -> None:
    relay(docs)["command"] = ["python", "manage.py", "outbox_rely"]


def m_celery_schedule_removed(docs: Docs) -> None:
    """--schedule /tmp/…이 없으면 beat가 일정 파일을 WORKDIR에 쓰려 해 readOnlyRootFilesystem에서 실패한다(③ 리뷰 A-6)."""
    command = celery(docs)["command"]
    index = command.index("--schedule")
    del command[index : index + 2]


def m_web_command_without_no_control_socket(docs: Docs) -> None:
    web(docs)["command"] = ["gunicorn", "--config", "python:sample_pod.gunicorn_conf", "sample_pod.wsgi:application"]


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
    # ---- T072(render-70부터 — 이 아래에만 덧붙인다: 위 행의 순번 = 기존 시험 ID) ----
    ("web-grace-30", m_web_grace_30, "pod_lifecycle"),
    ("web-grace-removed", m_web_grace_removed, "pod_lifecycle"),
    ("web-readiness-timeout-1", m_web_readiness_timeout_1, "pod_lifecycle"),
    ("web-startup-timeout-missing", m_web_startup_timeout_missing, "pod_lifecycle"),
    ("web-liveness-timeout-1", m_web_liveness_timeout_1, "pod_lifecycle"),
    ("web-pod-ip-removed", m_web_pod_ip_removed, "pod_lifecycle"),
    ("web-pod-ip-host-ip", m_web_pod_ip_host_ip, "pod_lifecycle"),
    ("web-pre-stop-removed", m_web_pre_stop_removed, "pod_lifecycle"),
    ("web-pre-stop-sleep-1s", m_web_pre_stop_sleep_1, "pod_lifecycle"),
    ("relay-env-prometheus-multiproc", m_relay_env_prometheus_multiproc, "env_hygiene"),
    ("configmap-prometheus-multiproc", m_configmap_prometheus_multiproc, "env_hygiene"),
    ("env-secret-template-prometheus-multiproc", m_env_secret_template_prometheus_multiproc, "env_hygiene"),
    ("web-env-netrc", m_web_env_netrc, "env_hygiene"),
    ("celery-env-https-proxy-lowercase", m_celery_env_https_proxy_lowercase, "env_hygiene"),
    ("init-env-sslkeylogfile", m_init_env_sslkeylogfile, "env_hygiene"),
    ("configmap-requests-ca-bundle", m_configmap_requests_ca_bundle, "env_hygiene"),
    ("job-env-client-key-file", m_job_env_client_key_file, "env_hygiene"),
    ("web-env-from-https-prefix-proxy-key", m_web_env_from_https_prefix_proxy_key, "env_hygiene"),
    ("relay-env-from-out-of-render-configmap", m_relay_env_from_out_of_render_configmap, "env_hygiene"),
    ("celery-env-from-out-of-render-secret", m_celery_env_from_out_of_render_secret, "env_hygiene"),
    ("relay-env-pgoptions", m_relay_env_pgoptions, "env_hygiene"),
    ("web-env-ssl-cert-dir", m_web_env_ssl_cert_dir, "env_hygiene"),
    ("configmap-sentry-print-envelopes", m_configmap_sentry_print_envelopes, "env_hygiene"),
    ("celery-env-pythonpath", m_celery_env_pythonpath, "env_hygiene"),
    ("env-secret-placeholder-store", m_env_secret_placeholder_store, "external_secrets"),
    ("migrate-secret-key-placeholder", m_migrate_secret_key_placeholder, "external_secrets"),
    ("env-secret-api-version-v1beta1", m_env_secret_api_version_v1beta1, "external_secrets"),
    ("env-secret-data-from-extract", m_env_secret_data_from_extract, "external_secrets"),
    ("env-secret-template-from", m_env_secret_template_from, "external_secrets"),
    ("env-secret-merge-policy-merge", m_env_secret_merge_policy_merge, "external_secrets"),
    ("migrate-secret-refresh-1h", m_migrate_secret_refresh_1h, "external_secrets"),
    ("env-secret-refresh-policy-removed", m_env_secret_refresh_policy_removed, "external_secrets"),
    ("migrate-secret-creation-policy-orphan", m_migrate_secret_creation_policy_orphan, "external_secrets"),
    ("env-secret-workers-path", m_env_secret_workers_path, "external_secrets"),
    ("env-secret-property-missing", m_env_secret_property_missing, "external_secrets"),
    ("migrate-secret-engine-version-v1", m_migrate_secret_engine_version_v1, "external_secrets"),
    ("env-secret-store-kind-namespaced", m_env_secret_store_kind_namespaced, "external_secrets"),
    ("env-secret-data-source-ref", m_env_secret_data_source_ref, "external_secrets"),
    ("migrate-secret-hook-removed", m_migrate_secret_hook_removed, "hook_order"),
    ("migrate-secret-wave-0", m_migrate_secret_wave_0, "hook_order"),
    ("migrate-secret-delete-policy-removed", m_migrate_secret_delete_policy_removed, "hook_order"),
    ("job-configmap-ref", m_job_configmap_ref, "hook_order"),
    ("job-configmap-volume", m_job_configmap_volume, "hook_order"),
    ("env-secret-hook-added", m_env_secret_hook_added, "hook_order"),
    ("configmap-wave-removed", m_configmap_wave_removed, "hook_order"),
    ("job-wave-before-migrate-secret", m_job_wave_before_migrate_secret, "hook_order"),
    ("web-image-tag", m_web_image_tag, "images"),
    ("relay-image-digest", m_relay_image_digest, "images"),
    ("celery-image-other-name", m_celery_image_other_name, "images"),
    ("init-image-tag", m_init_image_tag, "images"),
    ("migrate-image-other-registry", m_migrate_image_other_registry, "images"),
    ("namespace-set", m_namespace_set, "images"),
    ("default-render-cronjob", m_default_render_cronjob, "cronjob"),
    ("default-render-cronjob-other-name", m_default_render_cronjob_other_name, "cronjob"),
    ("init-removed", m_init_removed, "runtime_wiring"),
    ("init-command-other", m_init_command_other, "runtime_wiring"),
    ("init-env-secret-removed", m_init_env_secret_removed, "runtime_wiring"),
    ("init-configmap-ref-removed", m_init_configmap_ref_removed, "runtime_wiring"),
    ("web-kafka-ca-mount-removed", m_web_kafka_ca_mount_removed, "runtime_wiring"),
    ("relay-kafka-ca-mount-path-other", m_relay_kafka_ca_mount_path_other, "runtime_wiring"),
    ("relay-kafka-ca-writable", m_relay_kafka_ca_writable, "runtime_wiring"),
    ("kafka-ca-secret-name-typo", m_kafka_ca_secret_name_typo, "runtime_wiring"),
    ("web-metrics-port-removed", m_web_metrics_port_removed, "runtime_wiring"),
    ("web-memory-limit-1gi", m_web_memory_limit_1gi, "runtime_wiring"),
    ("celery-memory-limit-384mi", m_celery_memory_limit_384, "runtime_wiring"),
    ("migrate-memory-limit-1gi", m_migrate_memory_limit_1gi, "runtime_wiring"),
    ("init-limits-removed", m_init_limits_removed, "runtime_wiring"),
    ("init-memory-request-256mi", m_init_memory_request_256, "runtime_wiring"),
    ("relay-pod-namespace-removed", m_relay_pod_namespace_removed, "runtime_wiring"),
    ("celery-pod-namespace-field-path-name", m_celery_pod_namespace_field_path_name, "runtime_wiring"),
    ("job-pod-namespace-added", m_job_pod_namespace_added, "runtime_wiring"),
    ("configmap-value-trailing-newline", m_configmap_value_trailing_newline, "runtime_wiring"),
    ("env-secret-template-value-leading-space", m_env_secret_template_value_leading_space, "runtime_wiring"),
    ("web-pod-run-as-user-removed", m_web_pod_run_as_user_removed, "security_context"),
    ("job-pod-run-as-group-0", m_job_pod_run_as_group_0, "security_context"),
    ("celery-container-run-as-user-0", m_celery_container_run_as_user_0, "security_context"),
    ("relay-container-run-as-group-string", m_relay_container_run_as_group_string, "security_context"),
    ("ingress-class-nginx", m_ingress_class_nginx, "ingress"),
    ("ingress-entrypoints-removed", m_ingress_entrypoints_removed, "ingress"),
    ("ingress-router-tls-false", m_ingress_router_tls_false, "ingress"),
    ("ingress-spec-tls-added", m_ingress_spec_tls_added, "ingress"),
    ("ingress-host-invalid", m_ingress_host_invalid, "ingress"),
    ("ingress-health-prefix", m_ingress_health_prefix, "ingress"),
    ("ingress-session-exact", m_ingress_session_exact, "ingress"),
    ("ingress-backend-port-number", m_ingress_backend_port_number, "ingress"),
    ("init-pg-ca-mount-removed", m_init_pg_ca_mount_removed, "db_tls"),
    # ---- T072 r2(render-156부터 — 리뷰 r1 반영. 위 행의 순번 = 기존 시험 ID) ----
    ("unreferenced-configmap-prometheus-multiproc", m_unreferenced_configmap_prometheus_multiproc, "env_hygiene"),
    ("env-secret-target-name-removed", m_env_secret_target_name_removed, "external_secrets"),
    (
        "unreferenced-configmap-prometheus-multiproc-lowercase",
        m_unreferenced_configmap_prometheus_multiproc_lowercase,
        "env_hygiene",
    ),
    ("migrate-settings-profile-removed", m_migrate_settings_profile_removed, "runtime_wiring"),
    ("relay-configmap-ref-removed", m_relay_configmap_ref_removed, "runtime_wiring"),
    ("configmap-runtime-keys-removed", m_configmap_runtime_keys_removed, "runtime_wiring"),
    ("env-secret-runtime-keys-removed", m_env_secret_runtime_keys_removed, "runtime_wiring"),
    ("migrate-secret-runtime-key-added", m_migrate_secret_runtime_key_added, "runtime_wiring"),
    ("migrate-settings-profile-runtime", m_migrate_settings_profile_runtime, "runtime_wiring"),
    ("configmap-settings-profile-key", m_configmap_settings_profile_key, "runtime_wiring"),
    ("web-env-secret-key-ref-only", m_web_env_secret_key_ref_only, "runtime_wiring"),
    ("celery-other-complete-configmap", m_celery_other_complete_configmap, "runtime_wiring"),
    ("env-secret-data-empty", m_env_secret_data_empty, "external_secrets"),
    ("env-secret-data-order-swapped", m_env_secret_data_order_swapped, "external_secrets"),
    ("env-secret-template-ref-typo", m_env_secret_template_ref_typo, "external_secrets"),
    ("migrate-secret-data-order-swapped", m_migrate_secret_data_order_swapped, "external_secrets"),
    ("service-port-name-other", m_service_port_name_other, "ingress"),
    ("service-target-port-metrics", m_service_target_port_metrics, "ingress"),
    ("service-selector-component-api", m_service_selector_component_api, "ingress"),
    ("ingress-backend-service-other", m_ingress_backend_service_other, "ingress"),
    ("service-selector-matches-celery", m_service_selector_matches_celery, "ingress"),
    # ---- T072 r3(render-177부터 — 리뷰 r2 반영. 위 행의 순번 = 기존 시험 ID) ----
    ("relay-configmap-env-from-prefix", m_relay_configmap_env_from_prefix, "runtime_wiring"),
    ("migrate-secret-env-from-prefix", m_migrate_secret_env_from_prefix, "runtime_wiring"),
    # ---- T072 ② r2(render-179부터 — 조각 ② 리뷰 H10 · B-2. 위 행의 순번 = 기존 시험 ID) ----
    ("celery-env-celery-broker-url", m_celery_env_celery_broker_url, "env_hygiene"),
    ("relay-env-celery-broker-read-url-lowercase", m_relay_env_celery_broker_read_url_lowercase, "env_hygiene"),
    ("configmap-celery-broker-write-url", m_configmap_celery_broker_write_url, "env_hygiene"),
    ("init-env-celery-result-backend", m_init_env_celery_result_backend, "env_hygiene"),
    ("web-env-gunicorn-cmd-args", m_web_env_gunicorn_cmd_args, "env_hygiene"),
    # ---- T072 ③ r2(render-184부터 — 조각 ③ 리뷰 A-6 · M6. 위 행의 순번 = 기존 시험 ID) ----
    ("relay-command-typo", m_relay_command_typo, "runtime_wiring"),
    ("celery-schedule-removed", m_celery_schedule_removed, "runtime_wiring"),
    ("web-command-without-no-control-socket", m_web_command_without_no_control_socket, "runtime_wiring"),
]

MUTATIONS = [
    Mutation(f"render-{index:02d}-{slug}", apply, owner) for index, (slug, apply, owner) in enumerate(_TABLE, start=2)
]


# ---------- has_celery=false 변형 변이(T072 · fixtures/golden-cronjob.yaml · 검사는 has_celery=False) ----------


def m_cron_schedule_hourly(docs: Docs) -> None:
    cron_job(docs)["spec"]["schedule"] = "17 * * * *"


def m_cron_concurrency_allow(docs: Docs) -> None:
    cron_job(docs)["spec"]["concurrencyPolicy"] = "Allow"


def m_cron_command_relay(docs: Docs) -> None:
    purge(docs)["command"] = ["python", "manage.py", "outbox_relay"]


def m_cron_name_other(docs: Docs) -> None:
    cron_job(docs)["metadata"]["name"] = "sample-pod-purge"


def m_cron_time_zone_local(docs: Docs) -> None:
    cron_job(docs)["spec"]["timeZone"] = "Asia/Seoul"


def m_cron_second_container(docs: Docs) -> None:
    extra = copy.deepcopy(purge(docs))
    extra["name"] = "outbox-purge-copy"
    cron_pod_spec(cron_job(docs))["containers"].append(extra)


def m_cron_second_cronjob(docs: Docs) -> None:
    extra = copy.deepcopy(cron_job(docs))
    extra["metadata"]["name"] = f"{CRONJOB}-copy"
    docs.append(extra)


def m_cron_celery_deployment_added(docs: Docs) -> None:
    docs.append(golden_document(GOLDEN, "Deployment", "sample-pod-celery"))


def m_cron_env_secret_ref_removed(docs: Docs) -> None:
    purge(docs)["envFrom"] = without(purge(docs)["envFrom"], lambda e: "secretRef" in e)


def m_cron_migrate_secret_ref(docs: Docs) -> None:
    purge(docs)["envFrom"].append({"secretRef": {"name": "sample-pod-migrate"}})


def m_cron_configmap_ref_removed(docs: Docs) -> None:
    purge(docs)["envFrom"] = without(purge(docs)["envFrom"], lambda e: "configMapRef" in e)


def m_cron_pg_ca_mount_removed(docs: Docs) -> None:
    purge(docs)["volumeMounts"] = without(purge(docs)["volumeMounts"], lambda m: m["name"] == "pg-ca")


def m_cron_automount_true(docs: Docs) -> None:
    cron_pod_spec(cron_job(docs))["automountServiceAccountToken"] = True


def m_cron_read_only_root_false(docs: Docs) -> None:
    purge(docs)["securityContext"]["readOnlyRootFilesystem"] = False


def m_cron_pod_run_as_user_0(docs: Docs) -> None:
    cron_pod_spec(cron_job(docs))["securityContext"]["runAsUser"] = 0


def m_cron_memory_request_128(docs: Docs) -> None:
    purge(docs)["resources"]["requests"]["memory"] = "128Mi"


def m_cron_cpu_limit(docs: Docs) -> None:
    purge(docs)["resources"]["limits"]["cpu"] = "500m"


def m_cron_image_tag(docs: Docs) -> None:
    purge(docs)["image"] = IMAGE + ":latest"


def m_cron_pod_namespace_removed(docs: Docs) -> None:
    purge(docs)["env"] = without(purge(docs)["env"], lambda e: e["name"] == "POD_NAMESPACE")


def m_cron_memory_limit_1gi(docs: Docs) -> None:
    purge(docs)["resources"]["limits"]["memory"] = "1Gi"


def m_cron_env_pgsslmode(docs: Docs) -> None:
    purge(docs)["env"].append({"name": "PGSSLMODE", "value": "disable"})


def m_cron_suspend_true(docs: Docs) -> None:
    """E6 — 일 1회 purge가 조용히 멈춘다."""
    cron_job(docs)["spec"]["suspend"] = True


def m_cron_settings_profile(docs: Docs) -> None:
    """E1 — CronJob(runtime 프로필)에 migrate 프로필."""
    purge(docs)["env"].append({"name": "JT_SETTINGS_PROFILE", "value": "migrate"})


_CRON_TABLE: list[tuple[str, Callable[[Docs], None], str]] = [
    ("schedule-hourly", m_cron_schedule_hourly, "cronjob"),
    ("concurrency-allow", m_cron_concurrency_allow, "cronjob"),
    ("command-relay", m_cron_command_relay, "cronjob"),
    ("name-other", m_cron_name_other, "cronjob"),
    ("time-zone-local", m_cron_time_zone_local, "cronjob"),
    ("second-container", m_cron_second_container, "cronjob"),
    # CronJob 개수(정확히 1)와 celery Deployment 부재는 변형 모드 워크로드 식별의 몫이다(기본 모드의 Deployment · Job 개수와 같은 자리)
    ("second-cronjob", m_cron_second_cronjob, "identification"),
    ("celery-deployment-added", m_cron_celery_deployment_added, "identification"),
    ("env-secret-ref-removed", m_cron_env_secret_ref_removed, "env_split"),
    ("migrate-secret-ref", m_cron_migrate_secret_ref, "env_split"),
    ("configmap-ref-removed", m_cron_configmap_ref_removed, "configmap"),
    ("pg-ca-mount-removed", m_cron_pg_ca_mount_removed, "db_tls"),
    ("automount-token-true", m_cron_automount_true, "security_context"),
    ("read-only-root-false", m_cron_read_only_root_false, "security_context"),
    ("pod-run-as-user-0", m_cron_pod_run_as_user_0, "security_context"),
    ("memory-request-128mi", m_cron_memory_request_128, "strategy_resources"),
    ("cpu-limit", m_cron_cpu_limit, "strategy_resources"),
    ("image-tag", m_cron_image_tag, "images"),
    ("pod-namespace-removed", m_cron_pod_namespace_removed, "runtime_wiring"),
    ("memory-limit-1gi", m_cron_memory_limit_1gi, "runtime_wiring"),
    ("env-pgsslmode", m_cron_env_pgsslmode, "env_hygiene"),
    # ---- T072 r2(cron-22부터) ----
    ("suspend-true", m_cron_suspend_true, "cronjob"),
    ("settings-profile-migrate", m_cron_settings_profile, "runtime_wiring"),
]

CRON_MUTATIONS = [
    Mutation(f"cron-{index:02d}-{slug}", apply, owner) for index, (slug, apply, owner) in enumerate(_CRON_TABLE, start=1)
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


# ---------- T072 — 변이 표의 최소 구성 · 정규화 · has_celery=false 변형 ----------

T072_FIRST_INDEX = 70
NEW_CHECKS = ("pod_lifecycle", "env_hygiene", "external_secrets", "hook_order", "images", "cronjob", "runtime_wiring")
EXTENDED_CHECKS = ("security_context", "ingress", "db_tls")


def test_render_t072_mutation_table_minimums() -> None:
    """T065 행(render-02..69)은 그대로이고, T072 행은 표 끝에만 붙는다 — 새 검사마다 ≥ 2 · 확장마다 ≥ 1(D21)."""
    assert MUTATIONS[T072_FIRST_INDEX - 3].id == "render-69-service-removed"
    t072 = MUTATIONS[T072_FIRST_INDEX - 2 :]
    assert t072[0].id.startswith(f"render-{T072_FIRST_INDEX}-")
    assert set(NEW_CHECKS) <= set(CHECKS), f"CHECKS에 없는 새 검사: {set(NEW_CHECKS) - set(CHECKS)}"
    counts = {name: sum(1 for mutation in t072 if mutation.owner == name) for name in CHECKS}
    assert all(counts[name] >= 2 for name in NEW_CHECKS), counts
    assert all(counts[name] >= 1 for name in EXTENDED_CHECKS), counts


def test_render_t072_equivalent_spellings_accepted(golden: Docs) -> None:
    """T072 정규화 확인 — 기간 표기(5m = 300s = 5m0s) · 메모리 limits 수량 · 마운트 경로 끝 슬래시 · fieldRef apiVersion ·
    command/args 나눔 · sync-wave 생략(= 0) · 하한 위의 값(grace · timeout · preStop)은 위반이 아니다."""
    docs = copy.deepcopy(golden)
    es_spec(docs, ENV_ES)["refreshInterval"] = "300s"
    es_spec(docs, MIGRATE_ES)["refreshInterval"] = "5m0s"
    web(docs)["resources"]["limits"]["memory"] = "0.5Gi"
    relay(docs)["resources"]["limits"]["memory"] = "201326592"
    init(docs)["resources"]["requests"]["memory"] = "134217728"
    mount_named(web(docs), "kafka-ca")["mountPath"] = "/etc/kafka/"
    env_entry(web(docs), "POD_IP")["valueFrom"]["fieldRef"]["apiVersion"] = "v1"
    env_entry(celery(docs), "POD_NAMESPACE")["valueFrom"]["fieldRef"]["apiVersion"] = "v1"
    init(docs)["command"] = ["python"]
    init(docs)["args"] = ["manage.py", "startup_check"]
    del annotations(job(docs))[WAVE]
    pod_spec(web_deploy(docs))["terminationGracePeriodSeconds"] = 120
    web(docs)["readinessProbe"]["timeoutSeconds"] = 5
    web(docs)["lifecycle"]["preStop"]["sleep"]["seconds"] = 10
    results = run_checks(docs)
    assert results == {name: [] for name in CHECKS}, results


WEB_IMAGE_CMD = ["gunicorn", "--config", "python:sample_pod.gunicorn_conf", "--no-control-socket", "sample_pod.wsgi:application"]


def set_web_command(command: list[str] | None, args: list[str] | None) -> Callable[[Docs], None]:
    def apply(docs: Docs) -> None:
        if command is not None:
            web(docs)["command"] = command
        if args is not None:
            web(docs)["args"] = args

    return apply


def split_relay_command(docs: Docs) -> None:
    relay(docs)["command"] = ["python"]
    relay(docs)["args"] = ["manage.py", "outbox_relay"]


PROCESS_COMMAND_SPELLINGS: list[tuple[str, Callable[[Docs], None]]] = [
    ("web-explicit-image-cmd", set_web_command(list(WEB_IMAGE_CMD), None)),
    ("web-command-args-split", set_web_command(WEB_IMAGE_CMD[:1], WEB_IMAGE_CMD[1:])),
    ("web-args-only", set_web_command(None, list(WEB_IMAGE_CMD))),
    ("web-empty-command", set_web_command([], None)),
    ("relay-command-args-split", split_relay_command),
]


@pytest.mark.parametrize(("name", "apply"), PROCESS_COMMAND_SPELLINGS, ids=[name for name, _ in PROCESS_COMMAND_SPELLINGS])
def test_render_process_commands_equivalent_spellings_accepted(golden: Docs, name: str, apply: Callable[[Docs], None]) -> None:
    """deploy 명령 결속(③ r2 M6)의 같은 뜻 — web에 이미지 CMD 토큰 그대로(command · command/args 나눔 · args만 — 이미지에 ENTRYPOINT가
    없다) · 빈 command(= 이미지 CMD) · relay command/args 나눔은 위반이 아니다."""
    docs = copy.deepcopy(golden)
    apply(docs)
    results = run_checks(docs)
    assert results == {check: [] for check in CHECKS}, (name, results)


def test_render_cron_golden_passes_every_check(cron_golden: Docs) -> None:
    identification = identify_workloads(cron_golden, has_celery=False)
    assert identification.workloads is not None, identification.violations
    assert identification.violations == []
    assert identification.workloads.cronjob is not None
    assert identification.workloads.celery_deploy is None
    results = run_checks(cron_golden, has_celery=False)
    assert results == {name: [] for name in CHECKS}, results


def test_render_cron_golden_is_golden_without_celery_plus_cronjob(golden: Docs, cron_golden: Docs) -> None:
    """두 골든의 관계 — 변형 골든 = 기본 골든 − celery Deployment + CronJob 하나(한쪽만 고치면 실패한다)."""

    def is_celery(document: dict[str, Any]) -> bool:
        return document.get("kind") == "Deployment" and document["metadata"]["name"] == "sample-pod-celery"

    cronjobs = [document for document in cron_golden if document.get("kind") == "CronJob"]
    assert [document["metadata"]["name"] for document in cronjobs] == [CRONJOB]
    rest = [document for document in cron_golden if document.get("kind") != "CronJob"]
    assert rest == [document for document in golden if not is_celery(document)]


def test_render_cron_identification_fails_across_modes(golden: Docs, cron_golden: Docs) -> None:
    """기본 골든을 변형 모드로 · 변형 골든을 기본 모드로 돌리면 워크로드 식별이 실패한다(모드가 실제로 갈린다)."""
    assert run_checks(golden, has_celery=False)["identification"]
    assert run_checks(cron_golden)["identification"]


@pytest.mark.parametrize("mutation", CRON_MUTATIONS, ids=[mutation.id for mutation in CRON_MUTATIONS])
def test_render_cron_mutation_caught_only_by_owner(cron_golden: Docs, mutation: Mutation) -> None:
    docs = copy.deepcopy(cron_golden)
    mutation.apply(docs)
    results = run_checks(docs, has_celery=False)
    assert results[mutation.owner], f"{mutation.id}: 맡은 검사 {mutation.owner}가 변이를 잡지 못했다"
    cross = {name: found for name, found in results.items() if name != mutation.owner and found}
    assert not cross, f"{mutation.id}: 교차 오탐 — {cross}"


def test_render_cron_mutation_table_covers_checks() -> None:
    ids = [mutation.id for mutation in CRON_MUTATIONS]
    assert len(ids) == len(set(ids)), "변이 id가 겹친다"
    owners = [mutation.owner for mutation in CRON_MUTATIONS]
    assert set(owners) <= set(CHECKS), f"없는 검사 이름: {set(owners) - set(CHECKS)}"
    assert owners.count("cronjob") >= 1, "cronjob 검사를 맡은 변형 변이가 없다"


# ---------- T072 r2 — migrate Job 스크립트 본보기(E7 · D20 단계 1–4 · D17) ----------
# 골든의 스크립트는 템플릿 deploy/base(조각 ④)가 그대로 쓰는 본보기다(마지막 라운드 N2(1): gen-14 · gen-31이 렌더 스크립트 = 골든 스크립트를
# 바이트까지 단언한다 — 그래서 이 시험이 템플릿 스크립트에도 걸린다). 하네스 venv에는 psycopg가 없으므로 가짜 psycopg(connect 계획 · 연결마다
# 경계 SQL 계획 · 실행한 SQL 기록)와 가짜 manage.py(하위 migrate 종료 코드)로 스크립트를 실제로 돌려 꼴을 굳힌다 — 접속 재시도는
# psycopg.OperationalError만 · 마감 env JT_DB_CONNECT_WAIT_SECONDS(정수 1–600 · 기본 120) · 재시도 줄 stdout · 최종 실패 stderr 한 줄
# (트레이스백 · 메시지 없음 — X25) · 하위 migrate 종료 코드 전달(X4). 마지막 라운드 N1(조각 ④ 리뷰 B-1): 접속 루프 밖도 같은 규칙 —
# DATABASE_OWNER_URL 읽기 · 해석 실패 = stderr 한 줄 db_url_invalid <클래스>(urlsplit의 ValueError는 netloc 전체를 싣는다) · CONNECT 경계
# SQL은 같은 마감 안에서 OperationalError · UndefinedObject(첫 배포의 app role 지연 — 런북 bootstrap.md T054 실측)를 재시도(stdout
# db_boundary_retry <클래스> attempt=<n> — 시도 번호는 접속과 함께 센다) · 마감 · 그 밖의 예외 = stderr 한 줄 db_boundary_failed <클래스>.

FAKE_PSYCOPG = '''\
import os

from psycopg import errors
from psycopg.errors import Error, OperationalError, ProgrammingError

_PLAN = os.environ.get("FAKE_PG_PLAN", "ok").split(",")
_SQL_PLAN = os.environ.get("FAKE_PG_SQL_PLAN", "ok").split(",")
_calls = 0
_sessions = 0
# 연결의 경계 SQL 계획 → (실패하는 문장 머리, 예외 클래스) — ok는 둘 다 성공한다
_SQL_FAILURES = {
    "undefined": ("GRANT", errors.UndefinedObject),
    "operational": ("REVOKE", OperationalError),
    "privilege": ("REVOKE", errors.InsufficientPrivilege),
}


def _log(line):
    with open(os.environ["FAKE_PG_LOG"], "a", encoding="utf-8") as handle:
        print(line, file=handle)


class _Connection:
    def __init__(self, sql_step):
        self.sql_step = sql_step

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        _log("close")
        return False

    def execute(self, query):
        text = str(query)
        _log(text)
        failure = _SQL_FAILURES.get(self.sql_step)
        if failure is not None and text.startswith(failure[0]):
            _log("raise " + failure[1].__name__)
            raise failure[1]("statement failed: planted-message")


def connect(conninfo, **kwargs):
    global _calls, _sessions
    step = _PLAN[min(_calls, len(_PLAN) - 1)]
    _calls += 1
    _log("connect " + step)
    if step == "operational":
        raise OperationalError("connection failed: planted-message")
    if step == "other":
        raise ValueError("invalid dsn: planted-message")
    sql_step = _SQL_PLAN[min(_sessions, len(_SQL_PLAN) - 1)]
    _sessions += 1
    return _Connection(sql_step)
'''

FAKE_PSYCOPG_ERRORS = '''\
class Error(Exception):
    pass


class OperationalError(Error):
    pass


class ProgrammingError(Error):
    pass


class UndefinedObject(ProgrammingError):
    pass


class InsufficientPrivilege(ProgrammingError):
    pass
'''

FAKE_PSYCOPG_SQL = '''\
class Identifier:
    def __init__(self, *names):
        self.names = names

    def __str__(self):
        return ".".join('"' + name.replace('"', '""') + '"' for name in self.names)


class SQL:
    def __init__(self, text):
        self.text = text

    def format(self, *args):
        return SQL(self.text.format(*(str(arg) for arg in args)))

    def __str__(self):
        return self.text
'''

FAKE_MANAGE = '''\
import os
import sys

with open(os.environ["FAKE_PG_LOG"], "a", encoding="utf-8") as handle:
    print("manage.py " + " ".join(sys.argv[1:]), file=handle)
sys.exit(int(os.environ.get("FAKE_MIGRATE_EXIT", "0")))
'''

GOLDEN_SQL_LOG = [
    'REVOKE CONNECT ON DATABASE "dev_sample_pod" FROM PUBLIC',
    'GRANT CONNECT ON DATABASE "dev_sample_pod" TO "dev_sample_pod_app", "dev_sample_pod_owner"',
    "close",
    "manage.py migrate --noinput",
]
GOLDEN_OWNER_URL = "postgresql://owner@127.0.0.1:1/dev_sample_pod?sslmode=require"
# 경계 SQL 한 번(성공 · 실패) — 마지막 라운드 N1 시험의 기대 기록 조각
BOUNDARY_OK = GOLDEN_SQL_LOG[:3]
BOUNDARY_UNDEFINED = [*GOLDEN_SQL_LOG[:2], "raise UndefinedObject", "close"]


def run_golden_migrate_script(
    docs: Docs,
    tmp_path: Path,
    *,
    plan: str,
    wait: str | None,
    migrate_exit: int = 0,
    sql_plan: str = "ok",
    owner_url: str | None = GOLDEN_OWNER_URL,
) -> tuple[ProcResult, list[str]]:
    """골든 migrate 컨테이너의 python -c 스크립트를 가짜 psycopg · 가짜 manage.py로 돌린다 → (결과, 가짜 기록 줄). plan = 접속 계획
    (ok · operational · other — 접속마다 하나) · sql_plan = 성공한 연결마다 경계 SQL 계획(ok · undefined · operational · privilege) ·
    owner_url None = DATABASE_OWNER_URL 없음 · wait None = 마감 env 없음. 자식 env는 허용 목록 + 이 값들뿐이다(누출 탐침 위생)."""
    command = migrate(docs)["command"]
    assert command[:2] == ["python", "-c"], command[:2]
    fakes = tmp_path / "fakes"
    (fakes / "psycopg").mkdir(parents=True)
    (fakes / "psycopg" / "__init__.py").write_text(FAKE_PSYCOPG, encoding="utf-8")
    (fakes / "psycopg" / "errors.py").write_text(FAKE_PSYCOPG_ERRORS, encoding="utf-8")
    (fakes / "psycopg" / "sql.py").write_text(FAKE_PSYCOPG_SQL, encoding="utf-8")
    pod = tmp_path / "pod"
    pod.mkdir()
    (pod / "manage.py").write_text(FAKE_MANAGE, encoding="utf-8")
    log = tmp_path / "fake-pg.log"
    values = {
        "PYTHONPATH": str(fakes),
        "DATABASE_OWNER_URL": owner_url,
        "FAKE_PG_PLAN": plan,
        "FAKE_PG_SQL_PLAN": sql_plan,
        "FAKE_PG_LOG": str(log),
        "FAKE_MIGRATE_EXIT": str(migrate_exit),
        "JT_DB_CONNECT_WAIT_SECONDS": wait,
    }
    env = allowlist_env({name: value for name, value in values.items() if value is not None})
    result = run([sys.executable, "-c", command[2]], cwd=pod, timeout=30, env=env)
    lines = log.read_text(encoding="utf-8").splitlines() if log.exists() else []
    return result, lines


def test_render_golden_migrate_script_retries_operational_error_and_returns_migrate_exit(
    golden: Docs, tmp_path: Path
) -> None:
    """접속 재시도 줄은 stdout 한 줄(예외 클래스 이름 · 시도 번호) · REVOKE → GRANT(Identifier) → 하위 migrate의 종료 코드가
    스크립트 종료 코드다(X4)."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="operational,ok", wait="5", migrate_exit=3)
    assert result.returncode == 3, (result.stdout, result.stderr)
    assert result.stdout.splitlines() == ["db_connect_retry OperationalError attempt=1"]
    assert result.stderr == ""
    assert log == ["connect operational", "connect ok", *GOLDEN_SQL_LOG]


def test_render_golden_migrate_script_final_failure_is_one_stderr_line(golden: Docs, tmp_path: Path) -> None:
    """닫힌 포트 + 마감 1 s(D17 (b)) → 종료 1 · stderr 한 줄 'db_connect_failed OperationalError' · 메시지 · 트레이스백 없음."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="operational", wait="1")
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.stderr.splitlines() == ["db_connect_failed OperationalError"]
    assert result.stdout == ""
    assert "planted-message" not in result.stdout + result.stderr
    assert log == ["connect operational"]


def test_render_golden_migrate_script_other_errors_fail_without_retry(golden: Docs, tmp_path: Path) -> None:
    """OperationalError가 아닌 예외는 재시도하지 않는다(기본 마감 120 s를 기다리지 않는다) — 같은 한 줄로 끝난다."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="other", wait="120")
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.seconds < 20
    assert result.stderr.splitlines() == ["db_connect_failed ValueError"]
    assert result.stdout == ""
    assert "planted-message" not in result.stdout + result.stderr
    assert log == ["connect other"]


@pytest.mark.parametrize(
    "wait", ["0", "601", "abc", "1.5", " 5", "+5", "1_0"], ids=["zero", "over-600", "word", "decimal", "space", "plus", "underscore"]
)
def test_render_golden_migrate_script_rejects_bad_wait(golden: Docs, tmp_path: Path, wait: str) -> None:
    """마감 env가 정수 1–600(ASCII 숫자)이 아니면 접속 전에 stderr 한 줄 'db_connect_wait_invalid' + 종료 1."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait=wait)
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.stderr.splitlines() == ["db_connect_wait_invalid"]
    assert result.stdout == ""
    assert log == []


@pytest.mark.parametrize("wait", [None, "1", "600"], ids=["default-120", "min-1", "max-600"])
def test_render_golden_migrate_script_accepts_wait_bounds(golden: Docs, tmp_path: Path, wait: str | None) -> None:
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait=wait)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert (result.stdout, result.stderr) == ("", "")
    assert log == ["connect ok", *GOLDEN_SQL_LOG]


# ---------- T072 마지막 라운드 N1(조각 ④ 리뷰 B-1) — 접속 루프 밖의 실패 처리 · 경계 SQL 재시도 ----------
# URL 해석 실패 사례: netloc의 비ASCII 글자가 NFKC로 '/'가 되면 Python 3.13 urlsplit이 netloc 전체(비밀번호 포함)를 실은 ValueError를 낸다 ·
# IPv6 괄호가 닫히지 않으면 ValueError · DATABASE_OWNER_URL이 없으면 KeyError. 심은 비밀번호는 어디에도 찍히지 않아야 한다.
URL_PLANTED = "planted-pass"
URL_CASES = {
    "missing": (None, "KeyError"),
    "netloc-nfkc": (f"postgresql://owner:{URL_PLANTED}{chr(0xFF0F)}word@127.0.0.1:1/dev_sample_pod", "ValueError"),
    "ipv6-unclosed": (f"postgresql://owner:{URL_PLANTED}@[::1/dev_sample_pod", "ValueError"),
}


@pytest.mark.parametrize("case", list(URL_CASES), ids=list(URL_CASES))
def test_render_golden_migrate_script_url_failure_is_one_stderr_line(golden: Docs, tmp_path: Path, case: str) -> None:
    """DATABASE_OWNER_URL 읽기 · 해석 실패 → 접속 전에 종료 1 · stderr 정확히 한 줄 'db_url_invalid <클래스>' · stdout 없음 · 예외
    메시지 · netloc · 심은 비밀번호 없음(N1 — Python urlsplit의 ValueError는 netloc 전체를 싣는다)."""
    owner_url, error = URL_CASES[case]
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait="5", owner_url=owner_url)
    output = result.stdout + result.stderr
    leaked = URL_PLANTED in output or "netloc" in output or "Traceback" in output
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.stderr.splitlines() == [f"db_url_invalid {error}"]
    assert result.stdout == ""
    assert not leaked
    assert log == []


def test_render_golden_migrate_script_boundary_retries_undefined_object_then_migrates(golden: Docs, tmp_path: Path) -> None:
    """첫 배포의 app role 지연(N1): 경계 SQL의 GRANT가 UndefinedObject → 같은 마감 안에서 다시 접속해 재시도(stdout 한 줄
    'db_boundary_retry UndefinedObject attempt=1') → 다음 시도 성공 → 하위 migrate의 종료 코드가 스크립트 종료 코드다."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait="5", sql_plan="undefined,ok", migrate_exit=3)
    assert result.returncode == 3, (result.stdout, result.stderr)
    assert result.stdout.splitlines() == ["db_boundary_retry UndefinedObject attempt=1"]
    assert result.stderr == ""
    assert log == ["connect ok", *BOUNDARY_UNDEFINED, "connect ok", *GOLDEN_SQL_LOG]


def test_render_golden_migrate_script_boundary_retries_operational_error(golden: Docs, tmp_path: Path) -> None:
    """경계 SQL 중 연결이 끊김(OperationalError) → 재시도(stdout 'db_boundary_retry OperationalError attempt=1') → 성공 · 종료 0."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait="5", sql_plan="operational,ok")
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout.splitlines() == ["db_boundary_retry OperationalError attempt=1"]
    assert result.stderr == ""
    revoke = GOLDEN_SQL_LOG[0]
    assert log == ["connect ok", revoke, "raise OperationalError", "close", "connect ok", *GOLDEN_SQL_LOG]


def test_render_golden_migrate_script_attempts_count_connect_and_boundary(golden: Docs, tmp_path: Path) -> None:
    """시도 번호는 접속과 경계를 함께 센다 — 접속 실패(attempt=1) → 경계 UndefinedObject(attempt=2) → 성공. 재시도 줄은 단계 이름으로
    갈린다(db_connect_retry · db_boundary_retry)."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="operational,ok", wait="10", sql_plan="undefined,ok")
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout.splitlines() == [
        "db_connect_retry OperationalError attempt=1",
        "db_boundary_retry UndefinedObject attempt=2",
    ]
    assert result.stderr == ""
    assert log == ["connect operational", "connect ok", *BOUNDARY_UNDEFINED, "connect ok", *GOLDEN_SQL_LOG]


def test_render_golden_migrate_script_boundary_deadline_is_one_stderr_line(golden: Docs, tmp_path: Path) -> None:
    """app role이 마감 안에 생기지 않음(UndefinedObject가 계속) + 마감 2 s → 재시도 줄 하나 뒤 종료 1 · stderr 정확히 한 줄
    'db_boundary_failed UndefinedObject' · 하위 migrate를 돌리지 않는다 · 메시지 없음."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait="2", sql_plan="undefined")
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.stdout.splitlines() == ["db_boundary_retry UndefinedObject attempt=1"]
    assert result.stderr.splitlines() == ["db_boundary_failed UndefinedObject"]
    assert "planted-message" not in result.stdout + result.stderr
    assert log == ["connect ok", *BOUNDARY_UNDEFINED, "connect ok", *BOUNDARY_UNDEFINED]


def test_render_golden_migrate_script_boundary_other_errors_fail_without_retry(golden: Docs, tmp_path: Path) -> None:
    """경계 SQL의 그 밖의 예외(권한 없음 — InsufficientPrivilege)는 재시도하지 않는다(기본 마감 120 s를 기다리지 않는다) → 종료 1 ·
    stderr 정확히 한 줄 'db_boundary_failed InsufficientPrivilege' · stdout 없음 · 하위 migrate 없음 · 메시지 없음."""
    result, log = run_golden_migrate_script(golden, tmp_path, plan="ok", wait=None, sql_plan="privilege")
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert result.seconds < 20
    assert result.stderr.splitlines() == ["db_boundary_failed InsufficientPrivilege"]
    assert result.stdout == ""
    assert "planted-message" not in result.stdout + result.stderr
    revoke = GOLDEN_SQL_LOG[0]
    assert log == ["connect ok", revoke, "raise InsufficientPrivilege", "close"]


# ---------- T072 마지막 라운드 N2(1) · N3 — 렌더 ≅ 골든(본보기) 판정 자체(tests/_render.py) ----------
# gen-38(golden_differences)과 gen-14 · gen-31(migrate_script_differences)이 쓰는 판정 — 골든에서 차이 0 · 변이마다 그 자리의 차이 줄.
# 변이 목록은 조각 ④ 리뷰 A-1 · A-2가 CHECKS를 모두 통과한다고 보인 값(Job 상한 · trimSuffix · ConfigMap dev 값 · 프로브 주기 · migrate
# 스크립트 성질)이다. 이 판정은 CHECKS가 아니다(골든과의 거리라 계약 변이 표의 교차 판정 밖).


def exemplar_docs() -> Docs:
    docs, problems = _render.golden_for(_render.DEFAULT_RENDER)
    assert problems == [], problems
    return docs


def test_render_golden_exemplar_has_exactly_one_exception(golden: Docs) -> None:
    """본보기 = 골든 + 예외 하나(relay pg-ca subPath 꼴 → /etc/pg 디렉터리) — 골든과 본보기의 차이는 그 마운트 자리뿐이다."""
    exemplar, problems = _render.golden_exemplar(golden)
    assert problems == []
    found = _render.golden_differences(golden, exemplar)
    prefix = "Deployment/sample-pod spec.template.spec.containers[relay].volumeMounts[pg-ca]."
    assert found and all(item.startswith(prefix) for item in found), found


def test_render_golden_exemplar_exception_is_closed(golden: Docs) -> None:
    """예외는 정확히 하나여야 한다 — 이미 바꾼 본보기(그 꼴 0개)나 그 꼴이 둘인 골든은 문제로 드러난다(예외가 조용히 사라지거나 넓어지지
    않게)."""
    exemplar, _ = _render.golden_exemplar(golden)
    assert _render.golden_exemplar(exemplar)[1]
    doubled = copy.deepcopy(golden)
    relay(doubled)["volumeMounts"].append(dict(_render.GOLDEN_RELAY_PG_CA_MOUNT))
    assert _render.golden_exemplar(doubled)[1]


def test_render_golden_differences_clean_and_order_free() -> None:
    """본보기와 같은 문서들은 차이 0 — 문서 순서를 뒤집어도 0(kustomize 출력 순서는 골든 순서와 다르다)."""
    exemplar = exemplar_docs()
    assert _render.golden_differences(copy.deepcopy(exemplar), exemplar) == []
    assert _render.golden_differences(list(reversed(copy.deepcopy(exemplar))), exemplar) == []


def golden_for_render_names() -> set[str]:
    return {_render.DEFAULT_RENDER, *(variant.name for variant in VARIANTS)}


def test_render_golden_for_covers_default_and_variants() -> None:
    """렌더 이름(기본 · 하네스 변형) → 골든: default = golden-render · no-celery = golden-cronjob · no-admin = golden-cronjob − ConfigMap
    FORCE_SCRIPT_NAME. 변형 이름이 하네스 VARIANTS와 같다(한쪽만 바뀌면 gen-38이 그 변형의 골든을 찾지 못한다)."""
    assert set(_render.GOLDEN_FOR_RENDER) == golden_for_render_names()
    keys: dict[str, set[str]] = {}
    for name in sorted(golden_for_render_names()):
        docs, problems = _render.golden_for(name)
        assert problems == [], (name, problems)
        keys[name] = set(doc(docs, "ConfigMap", "sample-pod-config")["data"])
    assert keys["default"] == keys["no-celery"] == keys["no-admin"] | {"FORCE_SCRIPT_NAME"}
    assert "FORCE_SCRIPT_NAME" not in keys["no-admin"]
    assert _render.golden_for("bogus")[1]
    assert _render.drop_configmap_keys(exemplar_docs(), ("NO_SUCH_KEY",))[1]


def script_change(old: str, new: str) -> Callable[[Docs], None]:
    def mutate(docs: Docs) -> None:
        command = migrate(docs)["command"]
        if command[2].count(old) != 1:
            raise LookupError(f"골든 migrate 스크립트에 {old!r}가 정확히 한 번 있지 않다")
        command[2] = command[2].replace(old, new)

    return mutate


def configmap_value(key: str, value: str) -> Callable[[Docs], None]:
    def mutate(docs: Docs) -> None:
        data = configmap(docs)["data"]
        if key not in data:
            raise LookupError(f"골든 ConfigMap에 {key}가 없다")
        data[key] = value

    return mutate


def template_value(es_name: str, key: str, old: str, new: str) -> Callable[[Docs], None]:
    def mutate(docs: Docs) -> None:
        data = es_template_data(docs, es_name)
        if data[key].count(old) != 1:
            raise LookupError(f"골든 {es_name} template.data[{key}]에 {old!r}가 정확히 한 번 있지 않다")
        data[key] = data[key].replace(old, new)

    return mutate


def drop_document(kind: str, name: str) -> Callable[[Docs], None]:
    def mutate(docs: Docs) -> None:
        docs.remove(doc(docs, kind, name))

    return mutate


def relay_pg_ca_sub_path_form(docs: Docs) -> None:
    """렌더 쪽 relay pg-ca 마운트를 골든의 「본보기 아님」 꼴(subPath)로 — 예외는 골든 → 본보기 바꾸기에만 있고 비교에는 없다."""
    mounts = relay(docs)["volumeMounts"]
    mounts[mounts.index(mount_named(relay(docs), "pg-ca"))] = dict(_render.GOLDEN_RELAY_PG_CA_MOUNT)


# 조각 ④ 리뷰 A-1 · A-2 변이 m1 · m2 · m3 · m4 · m10(지금 스크립트 꼴로 옮김) + N1 성질 + 바이트 차이
MIGRATE_SCRIPT_MUTATIONS: list[tuple[str, Callable[[Docs], None]]] = [
    ("connect-retry-widened", script_change("retry = isinstance(exc, psycopg.OperationalError)", "retry = True")),
    ("wait-range-dropped", script_change("if not 1 <= wait <= 600:", "if wait < 0:")),
    ("retry-line-to-stderr", script_change('"attempt=%d" % attempt, flush=True)', '"attempt=%d" % attempt, file=sys.stderr, flush=True)')),
    (
        "constant-exit-1",
        script_change(
            'sys.exit(subprocess.call([sys.executable, "manage.py", "migrate", "--noinput"]))',
            'subprocess.call([sys.executable, "manage.py", "migrate", "--noinput"]); sys.exit(1)',
        ),
    ),
    ("default-wait-invalid", script_change('"JT_DB_CONNECT_WAIT_SECONDS", "120")', '"JT_DB_CONNECT_WAIT_SECONDS", "0")')),
    ("boundary-retry-narrowed", script_change("(psycopg.OperationalError, errors.UndefinedObject)", "psycopg.OperationalError")),
    ("url-failure-prints-message", script_change('print("db_url_invalid", type(exc).__name__, file=sys.stderr)', 'print("db_url_invalid", exc, file=sys.stderr)')),
    ("trailing-space-only", script_change("delay = min(delay * 2, 10)", "delay = min(delay * 2, 10) ")),
]


@pytest.mark.parametrize(("name", "mutate"), MIGRATE_SCRIPT_MUTATIONS, ids=[name for name, _ in MIGRATE_SCRIPT_MUTATIONS])
def test_render_migrate_script_differences_mutation_caught(golden: Docs, name: str, mutate: Callable[[Docs], None]) -> None:
    """렌더 스크립트 = 골든 스크립트(바이트까지 — N2(1)): 변이 하나마다 차이 한 줄(첫 차이 줄 번호와 두 줄) — 가짜 psycopg 시험이 골든에서
    굳힌 성질이 템플릿에도 걸린다."""
    docs = copy.deepcopy(golden)
    mutate(docs)
    found = _render.migrate_script_differences(docs, golden)
    assert len(found) == 1 and "첫 차이 줄" in found[0], (name, found)


def test_render_migrate_script_differences_golden_and_shapes(golden: Docs, cron_golden: Docs) -> None:
    """골든 = 골든(차이 0) · 변형 골든의 스크립트 = 기본 골든 스크립트 · command/args로 나누거나(python -c <스크립트> 꼴이 아님) Job이 없으면
    스크립트를 찾지 못한다는 한 줄."""
    assert _render.migrate_script_differences(golden, golden) == []
    assert _render.migrate_script_differences(cron_golden, golden) == []
    split = copy.deepcopy(golden)
    command = migrate(split)["command"]
    migrate(split)["command"], migrate(split)["args"] = command[:2], command[2:]
    found = _render.migrate_script_differences(split, golden)
    assert len(found) == 1 and "찾지 못했다" in found[0], found
    without_job = [document for document in copy.deepcopy(golden) if document.get("kind") != "Job"]
    assert len(_render.migrate_script_differences(without_job, golden)) == 1


# 조각 ④ 리뷰 A-2 실측 변이(메모리 변이 × CHECKS 17 = 위반 0) + 문서 짝 · 타입 · 예외 꼴
GOLDEN_DIFF_MUTATIONS: list[tuple[str, Callable[[Docs], None], str]] = [
    ("job-active-deadline-removed", lambda d: job(d)["spec"].pop("activeDeadlineSeconds"), "Job/sample-pod-migrate spec.activeDeadlineSeconds"),
    ("job-backoff-limit-6", lambda d: job(d)["spec"].update(backoffLimit=6), "Job/sample-pod-migrate spec.backoffLimit"),
    ("job-ttl-removed", lambda d: job(d)["spec"].pop("ttlSecondsAfterFinished"), "Job/sample-pod-migrate spec.ttlSecondsAfterFinished"),
    ("job-hook-delete-policy-removed", lambda d: annotations(job(d)).pop(HOOK_DELETE_POLICY), f"metadata.annotations.{HOOK_DELETE_POLICY}"),
    ("job-restart-policy-on-failure", lambda d: pod_spec(job(d)).update(restartPolicy="OnFailure"), "spec.template.spec.restartPolicy"),
    ("web-readiness-period-60", lambda d: web(d)["readinessProbe"].update(periodSeconds=60), "containers[web].readinessProbe.periodSeconds"),
    ("web-liveness-period-1", lambda d: web(d)["livenessProbe"].update(periodSeconds=1), "containers[web].livenessProbe.periodSeconds"),
    ("web-replicas-0", lambda d: web_deploy(d)["spec"].update(replicas=0), "Deployment/sample-pod spec.replicas"),
    ("relay-liveness-timeout-removed", lambda d: relay(d)["livenessProbe"].pop("timeoutSeconds"), "containers[relay].livenessProbe.timeoutSeconds"),
    ("configmap-kafka-username-prod-form", configmap_value("KAFKA_USERNAME", "sample-pod"), "ConfigMap/sample-pod-config data.KAFKA_USERNAME"),
    ("configmap-sampler-arg-1-5", configmap_value("OTEL_TRACES_SAMPLER_ARG", "1.5"), "data.OTEL_TRACES_SAMPLER_ARG"),
    ("configmap-audience-web-bff", configmap_value("AUTHENTIK_AUDIENCE", "web-bff"), "data.AUTHENTIK_AUDIENCE"),
    ("configmap-bootstrap-port-9092", configmap_value("KAFKA_BOOTSTRAP", "jt-kafka-kafka-bootstrap.data.svc:9092"), "data.KAFKA_BOOTSTRAP"),
    ("configmap-team-domain-typo", configmap_value("ACCESS_TEAM_DOMAIN", "joshuatech.cloudflareaccess.com"), "data.ACCESS_TEAM_DOMAIN"),
    ("configmap-allowed-hosts-prod-namespace", configmap_value("ALLOWED_HOSTS", "sample-pod.jt-prod.svc"), "data.ALLOWED_HOSTS"),
    (
        "env-secret-trim-suffix-owner",
        template_value(ENV_ES, "DATABASE_URL", 'trimSuffix "_app"', 'trimSuffix "_owner"'),
        "ExternalSecret/sample-pod-env spec.target.template.data.DATABASE_URL",
    ),
    (
        "migrate-secret-trim-suffix-app",
        template_value(MIGRATE_ES, "DATABASE_OWNER_URL", 'trimSuffix "_owner"', 'trimSuffix "_app"'),
        "ExternalSecret/sample-pod-migrate spec.target.template.data.DATABASE_OWNER_URL",
    ),
    (
        "migrate-script-boundary-retry-narrowed",
        script_change("(psycopg.OperationalError, errors.UndefinedObject)", "psycopg.OperationalError"),
        "containers[migrate].command[2]: 여러 줄 문자열이 다르다 — 첫 차이 줄",
    ),
    ("probe-period-as-string", lambda d: web(d)["readinessProbe"].update(periodSeconds="5"), "readinessProbe.periodSeconds: 렌더 '5' · 골든 5"),
    ("relay-pg-ca-sub-path-form-in-render", relay_pg_ca_sub_path_form, "containers[relay].volumeMounts[pg-ca]."),
    ("extra-document", lambda d: d.append(unreferenced_configmap("EXTRA")), "ConfigMap/sample-pod-unused: 문서 수 렌더 1 · 골든 0"),
    ("missing-document", drop_document("Service", "sample-pod"), "Service/sample-pod: 문서 수 렌더 0 · 골든 1"),
    ("duplicated-document", lambda d: d.append(copy.deepcopy(service(d))), "Service/sample-pod: 문서 수 렌더 2 · 골든 1"),
]


@pytest.mark.parametrize(
    ("name", "mutate", "where"), GOLDEN_DIFF_MUTATIONS, ids=[name for name, _, _ in GOLDEN_DIFF_MUTATIONS]
)
def test_render_golden_differences_mutation_reported(name: str, mutate: Callable[[Docs], None], where: str) -> None:
    """렌더 ≅ 본보기(N3 — gen-38): 변이 하나마다 그 자리를 이름한 차이 줄(경로별 목록) — 조각 ④ 리뷰 A-2가 CHECKS 17을 모두 통과한다고 보인
    D20 값 변이도 잡는다."""
    exemplar = exemplar_docs()
    docs = copy.deepcopy(exemplar)
    mutate(docs)
    found = _render.golden_differences(docs, exemplar)
    assert found and any(where in item for item in found), (name, found)
