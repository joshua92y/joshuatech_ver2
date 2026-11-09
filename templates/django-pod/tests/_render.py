"""렌더 검사 함수(T065 · T072) — kustomize build deploy/base 출력(문서 목록)에 계약을 단언한다.

정본: specs/003-platform-foundation/contracts/pod-template.md §런타임 계약 · §기본 테스트 6 ·
design/t072-design.md D20(deploy/base 모양) · D21(하네스 단언).
- 검사 함수는 전부 list[str]을 돌려준다 — 위반 설명 "<kind>/<name> <컨테이너>: <무엇이 어떻게>". 빈 목록 = 통과.
  함수 안에서 assert를 쓰지 않는다(위반을 모아 돌려준다). 실제 렌더(test_generate.py gen-8..17 · T072 gen)와 합성 골든 ·
  변이(test_render_helpers.py)가 같은 함수를 쓴다.
- 워크로드 식별(identify_workloads)은 가능한 만큼 식별하고(best effort) 어긋남을 위반으로 모은다. 식별 위반은
  check_identification(gen-8)만 보고하고, 나머지 검사는 식별된 워크로드로 판정한다 — 변이 하나가 맡은 검사 하나에서만
  드러나게. 식별되지 않은 워크로드는 그 검사의 "검사 대상 없음" 위반이 된다(조용히 통과하지 않는다).
- 모드(T072): 모든 검사와 identify_workloads · run_checks는 키워드 인자 has_celery를 받는다. 기본값 True는 T065 동작
  그대로다. has_celery=False(copier has_celery=false 생성의 렌더)면 워크로드가 web Deployment 1(web + relay) ·
  migrate Job 1 · CronJob 1(dead outbox purge)이고 celery Deployment가 없다 — CronJob 컨테이너도 security_context ·
  env_split · db_tls · strategy_resources · configmap · env_hygiene · images · runtime_wiring이 함께 판정한다. 기본 모드는
  CronJob을 식별하지 않는다(있으면 check_cronjob의 위반이다).
"""

from __future__ import annotations

import copy
import re
import string
from collections.abc import Callable, Iterable
from dataclasses import dataclass, replace
from decimal import Decimal
from pathlib import Path
from typing import Any

import yaml

POD = "sample-pod"
POD_SNAKE = POD.replace("-", "_")
ENV_SECRET = f"{POD}-env"
MIGRATE_SECRET = f"{POD}-migrate"
CONFIG_MAP = f"{POD}-config"
CRONJOB_NAME = f"{POD}-outbox-purge"
IMAGE = f"ghcr.io/joshua92y/{POD}"
PG_CA_SECRET = "pg-main-ca"
PG_CA_DIR = "/etc/pg"
PG_CA_FILE = "/etc/pg/ca.crt"
PG_CA_KEY = "ca.crt"
DB_URL_KEYS = {ENV_SECRET: "DATABASE_URL", MIGRATE_SECRET: "DATABASE_OWNER_URL"}
DB_TLS_PARTS = ("sslmode=verify-full", "sslrootcert=/etc/pg/ca.crt")
OWNER_URL_KEY = "DATABASE_OWNER_URL"
KAFKA_CA_SECRET = "jt-kafka-cluster-ca-cert"
KAFKA_CA_DIR = "/etc/kafka"

WEB_PORT = 8000
WEB_METRICS_PORT = 9100
RELAY_METRICS_PORT = 9464
WEB_PROBES = {"livenessProbe": "/healthz", "readinessProbe": "/ready", "startupProbe": "/ready"}
STARTUP_FAILURE_THRESHOLD = 30
STARTUP_PERIOD_SECONDS = 5
HEALTH_PATH = "/health"
PROBE_KINDS = ("livenessProbe", "readinessProbe", "startupProbe")

# pod 생애(gen-19 · D20 · X29): relay 한 패스 최악 ≈ 80 s(계약 relay 프로브 행) · kubelet 프로브 기본 timeout 1 s ·
# 엔드포인트 제거와 SIGTERM의 경합(BFF는 재시도 없이 3 s)
GRACE_SECONDS_MIN = 90
PROBE_TIMEOUT_MIN = 3
PROBE_TIMEOUT_DEFAULT = 1
PRE_STOP_SLEEP_MIN = 5
POD_IP_ENV = "POD_IP"
POD_IP_FIELD = "status.podIP"
POD_NAMESPACE_ENV = "POD_NAMESPACE"
POD_NAMESPACE_FIELD = "metadata.namespace"

# settings 프로필 · 필수 설정 이름(gen-36 · D5 · X7 · T072 r2 E1). 런타임 필수 = D5 runtime 필수(존재) — 이미지 ENV가 주는
# APP_VERSION · APP_GIT_SHA는 뺀다. migrate 프로필은 DATABASE_OWNER_URL만 필수이고 런타임 키를 정의하지 않는다(X7 — owner
# 비밀의 범위를 넓히지 않는다).
SETTINGS_PROFILE_ENV = "JT_SETTINGS_PROFILE"
MIGRATE_PROFILE = "migrate"
RUNTIME_REQUIRED_ENV = frozenset(
    {
        "SECRET_KEY",
        "DATABASE_URL",
        "DRAGONFLY_URL",
        "KAFKA_BOOTSTRAP",
        "KAFKA_USERNAME",
        "KAFKA_PASSWORD",
        "AUTHENTIK_ISSUER",
        "AUTHENTIK_JWKS_URL",
        "AUTHENTIK_AUDIENCE",
        "ACCESS_TEAM_DOMAIN",
        "ACCESS_AUD_M2M",
        "ACCESS_AUD_ADMIN",
        "ACCESS_EXPECTED_CN",
        "ALLOWED_HOSTS",
        "ADMIN_HOST",
        "ENV",
        POD_NAMESPACE_ENV,
    }
)
MIGRATE_REQUIRED_ENV = frozenset({"DATABASE_OWNER_URL", SETTINGS_PROFILE_ENV})
RUNTIME_ONLY_ENV_NAMES = frozenset({"DATABASE_URL", "DRAGONFLY_URL", "SECRET_KEY"})
RUNTIME_ONLY_ENV_PREFIXES = ("KAFKA_", "AUTHENTIK_")

MAX_SURGE = 1
MAX_UNAVAILABLE = 0
AFFINITY_KEY = "role"
AFFINITY_OPERATOR = "In"
AFFINITY_VALUE = "platform"
# 역할 = web · relay · celery(Deployment 컨테이너 전부) · migrate(Job 첫 실행 컨테이너) · outbox-purge(CronJob 컨테이너 전부)
MEMORY_REQUESTS = {"web": "256Mi", "relay": "96Mi", "celery": "192Mi", "migrate": "256Mi", "outbox-purge": "256Mi"}
MEMORY_LIMITS = {"web": "512Mi", "relay": "192Mi", "celery": "512Mi", "migrate": "512Mi", "outbox-purge": "512Mi"}
INIT_CONTAINER = "startup-check"
INIT_COMMAND = ("python", "manage.py", "startup_check")
INIT_MEMORY_REQUEST = "128Mi"
INIT_MEMORY_LIMIT = "256Mi"
# 프로세스 명령(T072 ③ r2 M6 — 정본 한 곳: README 「프로세스」 표 · D11 · D14). Dockerfile CMD 정적 검사(tests/_tree.py — gen-33) ·
# 이미지 기동 스모크(tests/conftest.py — gen-34, 읽기 전용 루트) · 렌더 runtime_wiring(deploy/base web · relay · celery 명령 — gen-36)이
# 같은 객체를 쓴다 — 시험한 명령과 배포하는 명령이 어긋나지 않게. celery는 Linux 꼴(--beat — Windows Celery CLI는 거부한다 · D14).
WEB_COMMAND = (
    "gunicorn",
    "--config",
    f"python:{POD_SNAKE}.gunicorn_conf",
    "--no-control-socket",
    f"{POD_SNAKE}.wsgi:application",
)
RELAY_COMMAND = ("python", "manage.py", "outbox_relay")
CELERY_COMMAND = (
    "celery",
    "--app",
    POD_SNAKE,
    "worker",
    "--pool",
    "solo",
    "--beat",
    "--schedule",
    "/tmp/celerybeat-schedule",
    "--without-gossip",
    "--without-mingle",
    "--without-heartbeat",
    "--loglevel",
    "INFO",
)

# securityContext(gen-9) — 이미지 USER 10001:10001과 같은 숫자(kubelet은 이름 USER로 runAsNonRoot를 판정하지 못한다)
RUN_AS_ID = 10001
RUN_AS_FIELDS = ("runAsUser", "runAsGroup")

HOOK_ANNOTATION = "argocd.argoproj.io/hook"
HOOK_VALUE = "PreSync"
HOOK_DELETE_POLICY_ANNOTATION = "argocd.argoproj.io/hook-delete-policy"
HOOK_DELETE_POLICY = "BeforeHookCreation"
SYNC_WAVE_ANNOTATION = "argocd.argoproj.io/sync-wave"
RELOADER_ANNOTATION = "reloader.stakater.com/auto"
SCRAPE_ANNOTATION = "k8s.grafana.com/scrape"

CONFIGMAP_KEYS = frozenset({"ACCESS_AUD_M2M", "ACCESS_AUD_ADMIN", "ACCESS_EXPECTED_CN", "ADMIN_HOST", "ALLOWED_HOSTS"})
INGRESS_PATHS = frozenset({"/api", "/health", "/session", "/sessions", "/tenants"})
INGRESS_FORBIDDEN_PREFIXES = ("/healthz", "/ready", "/webhooks")
# Ingress(gen-17 확장 · D20 · G4 · ㉓): Traefik 선례(gitops bootstrap/argocd/ingress.yaml) — entrypoints websecure 필수 ·
# router.tls "true" · spec.tls 없음. /health만 Exact(Traefik 접두가 /healthz를 열면 T076의 404 단언이 깨진다).
INGRESS_CLASS = "traefik"
INGRESS_ANNOTATIONS = {
    "traefik.ingress.kubernetes.io/router.entrypoints": "websecure",
    "traefik.ingress.kubernetes.io/router.tls": "true",
}
INGRESS_HOST = "PLACEHOLDER.joshuatech.dev"
INGRESS_EXACT_PATHS = frozenset({"/health"})
INGRESS_BACKEND_PORT = "http"
# Service(D20 service.yaml · 계약 「Service 80 → 8000」 · T072 r2 E6): 포트 http 80 → web 컨테이너 8000(targetPort 이름 http)
SERVICE_PORT = 80

# ExternalSecret(gen-21) — gitops validate 3.0 · 3.1 · 3.7의 거울 + 계약 공통 규칙. base = dev 값(prod overlay가 바꾼다).
ESO_API_VERSION = "external-secrets.io/v1"
SECRET_STORE_KIND = "ClusterSecretStore"
SECRET_STORE_NAME = "vault-dev"
REFRESH_INTERVAL_SECONDS = Decimal(300)
REFRESH_POLICY = "Periodic"
CREATION_POLICY = "Owner"
TEMPLATE_ENGINE_VERSION = "v2"
TEMPLATE_MERGE_POLICY = "Replace"
# data[] 순번 고정(D20 표 — overlay 인덱스 패치의 인터페이스: prod overlay는 replace마다 op: test /spec/data/N/secretKey를
# 둔다) — (secretKey, remoteRef.key, remoteRef.property). 뒤에 덧붙인 항목은 허용한다(pod가 자기 비밀을 더한다 — T073).
ENV_SECRET_DATA = (
    ("db_username", f"dev/db/dev_{POD_SNAKE}/app", "username"),
    ("db_password", f"dev/db/dev_{POD_SNAKE}/app", "password"),
    ("kafka_password", f"dev/kafka/{POD}", "password"),
    ("dragonfly_url", f"dev/dragonfly/{POD}", "url"),
    ("authentik_issuer", f"dev/authentik/{POD}", "issuer"),
    ("authentik_jwks_url", f"dev/authentik/{POD}", "jwks_url"),
    ("sentry_dsn", f"dev/sentry/{POD}", "dsn"),
    ("secret_key", f"dev/django/{POD}", "secret_key"),
)
MIGRATE_SECRET_DATA = (
    ("db_username", f"dev/db/dev_{POD_SNAKE}/owner", "username"),
    ("db_password", f"dev/db/dev_{POD_SNAKE}/owner", "password"),
)

# env 위생(gen-20 · T071 S4/L3 · X18 · 계약 §기본 테스트 6) — 대소문자 무시(ASCII). 이름 목록 + 접두 PG(libpq env 전부 —
# PGOPTIONS가 app role의 statement_timeout을 덮는다) + 접미 _PROXY(계약 *_PROXY). PROMETHEUS_MULTIPROC_DIR는 web도
# 단일 프로세스라 어디에도 두지 않는다(D11). 검증된 설정을 대신하는 env(T072 ② r2 H10 · B-2): Celery broker · result URL 넷은
# app.conf(= DRAGONFLY_URL)보다 먼저 읽혀 conf 검증 · 공개 도메인 거부 · 마스킹 목록을 비켜 가고, GUNICORN_CMD_ARGS는 gunicorn_conf를
# 덮는다 — 이 다섯은 생성 pod의 기동 단언(startup.run)도 거부한다(X18의 「런타임 거부 없음」과 다른 부류).
MULTIPROC_ENV = "PROMETHEUS_MULTIPROC_DIR"
OVERRIDING_ENV_NAMES = (
    "CELERY_BROKER_URL",
    "CELERY_BROKER_READ_URL",
    "CELERY_BROKER_WRITE_URL",
    "CELERY_RESULT_BACKEND",
    "GUNICORN_CMD_ARGS",
)
FORBIDDEN_ENV_NAMES = frozenset(
    {
        "NETRC",
        "SSLKEYLOGFILE",
        "HTTP_PROXY",
        "HTTPS_PROXY",
        "ALL_PROXY",
        "CLIENT_CERT_FILE",
        "CLIENT_KEY_FILE",
        "SSL_CERT_FILE",
        "SSL_CERT_DIR",
        "REQUESTS_CA_BUNDLE",
        "CURL_CA_BUNDLE",
        "SENTRY_PRINT_ENVELOPES",
        "PYTHONOPTIMIZE",
        "PYTHONINSPECT",
        "PYTHONSTARTUP",
        "PYTHONPATH",
        MULTIPROC_ENV,
        *OVERRIDING_ENV_NAMES,
    }
)
FORBIDDEN_ENV_PREFIXES = ("PG",)
FORBIDDEN_ENV_SUFFIXES = ("_PROXY",)

# CronJob(gen-24 · D15): 일 1회 purge · 겹침 금지
CRON_CONCURRENCY_POLICY = "Forbid"
CRON_TIME_ZONES = frozenset({"Etc/UTC", "UTC"})
PURGE_COMMAND = ("python", "manage.py", "outbox_purge")

WORKLOAD_KINDS = frozenset({"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "Job", "CronJob"})

# PSA restricted가 컨테이너에 다시 더하도록 허용하는 유일한 capability(계약: "PSA restricted 통과")
PSA_ALLOWED_ADD = frozenset({"NET_BIND_SERVICE"})

_REVOKE_RE = re.compile(r"REVOKE\s+CONNECT\s+ON\s+DATABASE\s+\S+\s+FROM\s+PUBLIC", re.IGNORECASE)
_GRANT_RE = re.compile(r"GRANT\s+CONNECT\s+ON\s+DATABASE\s+\S+\s+TO\s+\S", re.IGNORECASE)
_MIGRATE_RE = re.compile(r"\bmigrate\b")
_DIGITS_RE = re.compile(r"[0-9]+")
_QUANTITY_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)?")
_QUANTITY_FACTORS: dict[str | None, int] = {
    None: 1,
    "Ki": 1024,
    "Mi": 1024**2,
    "Gi": 1024**3,
    "Ti": 1024**4,
    "Pi": 1024**5,
    "Ei": 1024**6,
    "k": 10**3,
    "M": 10**6,
    "G": 10**9,
    "T": 10**12,
    "P": 10**15,
    "E": 10**18,
}
_DURATION_RE = re.compile(r"(?:[0-9]+(?:\.[0-9]+)?(?:h|m|s|ms|us|ns))+")
_DURATION_PART_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)(h|ms|m|s|us|ns)")
_DURATION_FACTORS = {
    "h": Decimal(3600),
    "m": Decimal(60),
    "s": Decimal(1),
    "ms": Decimal("0.001"),
    "us": Decimal("0.000001"),
    "ns": Decimal("0.000000001"),
}
_REMOTE_KEY_RE = re.compile(r"dev/[a-z0-9_./-]+")
_WORKERS_KEY_RE = re.compile(r"(dev|prod)/(access|web)/")
# ESO v2(Go 템플릿) 동작 {{ … }} 안의 필드 참조 .x — 문자열 리터럴을 지운 뒤 찾는다(.a.b의 b · 숫자 1.5는 참조가 아니다)
_TEMPLATE_ACTION_RE = re.compile(r"\{\{(.*?)\}\}", re.DOTALL)
_TEMPLATE_STRING_RE = re.compile(r'"(?:[^"\\]|\\.)*"|`[^`]*`')
_TEMPLATE_FIELD_RE = re.compile(r"(?<![A-Za-z0-9_)\]])\.([A-Za-z_][A-Za-z0-9_]*)")
_WAVE_RE = re.compile(r"[+-]?[0-9]+")
_CRON_SCHEDULE_RE = re.compile(r"([0-9]{1,2}) ([0-9]{1,2}) \* \* \*")
_ASCII_UPPER = str.maketrans(string.ascii_lowercase, string.ascii_uppercase)

Doc = dict[str, Any]


# ---------- 읽기 도우미(모양이 다르면 빈 값 — 위반은 검사 함수가 만든다) ----------


def load_docs(text: str) -> list[Doc]:
    """YAML 다중 문서 → 매핑 목록(빈 문서는 뺀다). 매핑이 아닌 문서는 ValueError."""
    docs: list[Doc] = []
    for index, document in enumerate(yaml.safe_load_all(text)):
        if document is None:
            continue
        if not isinstance(document, dict):
            raise ValueError(f"문서 {index}가 매핑이 아니다({type(document).__name__})")
        docs.append(document)
    return docs


def _dict(value: Any) -> dict[str, Any]:
    return value if isinstance(value, dict) else {}


def _list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def _int(value: Any) -> int | None:
    """정수만(bool · 숫자 문자열은 아니다 — 매니페스트의 정수 필드)."""
    return value if isinstance(value, int) and not isinstance(value, bool) else None


def _name(document: Doc) -> str:
    name = _dict(document.get("metadata")).get("name")
    return name if isinstance(name, str) else "?"


def _ref(document: Doc) -> str:
    return f"{document.get('kind')}/{_name(document)}"


def _where(document: Doc, container: dict[str, Any]) -> str:
    return f"{_ref(document)} {container.get('name', '?')}"


def _of_kind(docs: list[Doc], kind: str) -> list[Doc]:
    return [document for document in docs if document.get("kind") == kind]


def _annotations(document: Doc) -> dict[str, Any]:
    return _dict(_dict(document.get("metadata")).get("annotations"))


def _pod_template(document: Doc) -> dict[str, Any]:
    """pod 템플릿 — CronJob은 spec.jobTemplate.spec.template, 그 밖의 워크로드는 spec.template."""
    spec = _dict(document.get("spec"))
    if document.get("kind") == "CronJob":
        spec = _dict(_dict(spec.get("jobTemplate")).get("spec"))
    return _dict(spec.get("template"))


def _pod_spec(document: Doc) -> dict[str, Any]:
    return _dict(_pod_template(document).get("spec"))


def _containers(spec: dict[str, Any]) -> list[dict[str, Any]]:
    return [item for item in _list(spec.get("containers")) if isinstance(item, dict)]


def _init_containers(spec: dict[str, Any]) -> list[dict[str, Any]]:
    return [item for item in _list(spec.get("initContainers")) if isinstance(item, dict)]


def _all_containers(spec: dict[str, Any]) -> list[dict[str, Any]]:
    return _init_containers(spec) + _containers(spec)


def _first_executing(spec: dict[str, Any]) -> dict[str, Any] | None:
    executing = _all_containers(spec)
    return executing[0] if executing else None


def _command(container: dict[str, Any]) -> list[str]:
    """command + args — 이미지에 ENTRYPOINT가 없어(D18) 둘을 이은 것이 실제 실행 명령이다. 이 전제는 gen-33 이미지 판정에 묶였다
    (tests/_tree.py check_image_config — Config.Entrypoint 없음 · Config.Cmd == WEB_COMMAND · T072 마지막 라운드 N4): 이미지에
    ENTRYPOINT가 생기거나 CMD가 셸 꼴로 바뀌면 gen-33이 실패한다."""
    return [str(item) for item in _list(container.get("command")) + _list(container.get("args"))]


def _container_ports(container: dict[str, Any]) -> list[int]:
    ports: list[int] = []
    for item in _list(container.get("ports")):
        port = _dict(item).get("containerPort")
        if isinstance(port, int) and not isinstance(port, bool):
            ports.append(port)
    return ports


def resolve_port(container: dict[str, Any], port: Any) -> int | None:
    """프로브 포트(정수 또는 이름) → 컨테이너 포트 번호. 이름은 그 컨테이너의 ports[].name으로 푼다."""
    if isinstance(port, bool):
        return None
    if isinstance(port, int):
        return port
    if isinstance(port, str):
        for item in _list(container.get("ports")):
            entry = _dict(item)
            number = entry.get("containerPort")
            if entry.get("name") == port and isinstance(number, int) and not isinstance(number, bool):
                return number
    return None


def int_or_digits(value: Any) -> int | None:
    """정수 또는 숫자 문자열("1" · "0")을 정수로. 백분율 등 그 밖의 값은 None."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, str) and _DIGITS_RE.fullmatch(value.strip()):
        return int(value.strip())
    return None


def memory_bytes(value: Any) -> Decimal | None:
    """Kubernetes 메모리 수량 → 바이트(256Mi · 268435456 · 0.25Gi가 같다). 읽지 못하면 None."""
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return Decimal(value)
    if not isinstance(value, str):
        return None
    match = _QUANTITY_RE.fullmatch(value.strip())
    if match is None:
        return None
    return Decimal(match.group(1)) * _QUANTITY_FACTORS[match.group(2)]


def duration_seconds(value: Any) -> Decimal | None:
    """Go 기간 문자열(ESO refreshInterval) → 초(5m · 300s · 5m0s가 같다). 읽지 못하면 None."""
    if not isinstance(value, str) or _DURATION_RE.fullmatch(value) is None:
        return None
    total = Decimal(0)
    for number, unit in _DURATION_PART_RE.findall(value):
        total += Decimal(number) * _DURATION_FACTORS[unit]
    return total


def _sync_wave(document: Doc) -> int | None:
    """Argo sync-wave(어노테이션이 없으면 0). 정수로 읽지 못하면 None."""
    raw = _annotations(document).get(SYNC_WAVE_ANNOTATION)
    if raw is None:
        return 0
    if isinstance(raw, str) and _WAVE_RE.fullmatch(raw):
        return int(raw)
    return None


def _secret_refs(container: dict[str, Any]) -> set[str]:
    """컨테이너가 참조하는 시크릿 이름 = envFrom[].secretRef.name ∪ env[].valueFrom.secretKeyRef.name."""
    refs: set[str] = set()
    for item in _list(container.get("envFrom")):
        name = _dict(_dict(item).get("secretRef")).get("name")
        if isinstance(name, str):
            refs.add(name)
    for item in _list(container.get("env")):
        name = _dict(_dict(_dict(item).get("valueFrom")).get("secretKeyRef")).get("name")
        if isinstance(name, str):
            refs.add(name)
    return refs


def _configmap_refs(container: dict[str, Any]) -> set[str]:
    """컨테이너가 참조하는 ConfigMap 이름 = envFrom[].configMapRef.name ∪ env[].valueFrom.configMapKeyRef.name."""
    refs: set[str] = set()
    for item in _list(container.get("envFrom")):
        entry = _dict(item)
        if "configMapRef" in entry:
            refs.add(str(_dict(entry.get("configMapRef")).get("name")))
    for item in _list(container.get("env")):
        value_from = _dict(_dict(item).get("valueFrom"))
        if "configMapKeyRef" in value_from:
            refs.add(str(_dict(value_from.get("configMapKeyRef")).get("name")))
    return refs


def _volume_secret_names(volume: dict[str, Any]) -> set[str]:
    """볼륨이 담는 시크릿 이름(secret.secretName · projected.sources[].secret.name)."""
    names: set[str] = set()
    secret_name = _dict(volume.get("secret")).get("secretName")
    if isinstance(secret_name, str):
        names.add(secret_name)
    for source in _list(_dict(volume.get("projected")).get("sources")):
        name = _dict(_dict(source).get("secret")).get("name")
        if isinstance(name, str):
            names.add(name)
    return names


def _volume_configmap_names(volume: dict[str, Any]) -> set[str]:
    """볼륨이 담는 ConfigMap 이름(configMap.name · projected.sources[].configMap.name)."""
    names: set[str] = set()
    if "configMap" in volume:
        names.add(str(_dict(volume.get("configMap")).get("name")))
    for source in _list(_dict(volume.get("projected")).get("sources")):
        entry = _dict(source)
        if "configMap" in entry:
            names.add(str(_dict(entry.get("configMap")).get("name")))
    return names


def _string_values_for_key(node: Any, key: str) -> list[str]:
    """문서 어디에서든 매핑 키 key의 문자열 값을 모은다(ESO spec.target.template.data 등)."""
    found: list[str] = []
    if isinstance(node, dict):
        for item_key, item_value in node.items():
            if item_key == key and isinstance(item_value, str):
                found.append(item_value)
            found.extend(_string_values_for_key(item_value, key))
    elif isinstance(node, list):
        for item in node:
            found.extend(_string_values_for_key(item, key))
    return found


def _has_key(node: Any, key: str) -> bool:
    if isinstance(node, dict):
        return key in node or any(_has_key(value, key) for value in node.values())
    if isinstance(node, list):
        return any(_has_key(item, key) for item in node)
    return False


def _normalize_path(path: Any) -> str | None:
    if not isinstance(path, str):
        return None
    path = path.split("?", 1)[0]
    return path.rstrip("/") or "/"


def _field_ref_paths(container: dict[str, Any], name: str) -> list[Any]:
    """env[]에서 이름이 name인 항목마다 valueFrom.fieldRef.fieldPath(리터럴 value면 None)."""
    return [
        _dict(_dict(_dict(item).get("valueFrom")).get("fieldRef")).get("fieldPath")
        for item in _list(container.get("env"))
        if _dict(item).get("name") == name
    ]


def _env_key(name: str) -> str:
    """env 이름 비교 꼴 — ASCII 대문자(유니코드 접기는 쓰지 않는다)."""
    return name.translate(_ASCII_UPPER)


def _forbidden_env(name: str) -> bool:
    key = _env_key(name)
    return key in FORBIDDEN_ENV_NAMES or key.startswith(FORBIDDEN_ENV_PREFIXES) or key.endswith(FORBIDDEN_ENV_SUFFIXES)


def _value_problem(value: str) -> str | None:
    """ConfigMap · ES 템플릿 값의 보이지 않는 글자(블록 스칼라 |의 끝 줄바꿈 등 — BAN-02 · HO-10)."""
    if len((value + "x").splitlines()) > 1:
        return "줄바꿈"
    if "\t" in value:
        return "탭"
    if value != value.strip():
        return "앞뒤 공백"
    return None


# ---------- ExternalSecret · env 원천 ----------


def _es_target_name(document: Doc) -> str:
    """ES가 만드는 Secret 이름 — spec.target.name, 없으면 ES 이름(ESO 기본값)."""
    name = _dict(_dict(document.get("spec")).get("target")).get("name")
    return name if isinstance(name, str) else _name(document)


def _external_secret_keys(document: Doc) -> set[str]:
    """ES가 만드는 Secret의 키 — template.data 키(템플릿이 없거나 mergePolicy Merge면 data[].secretKey도).
    dataFrom의 키는 렌더로 알 수 없어 범위 밖이다(check_external_secrets가 dataFrom 자체를 금지한다)."""
    spec = _dict(document.get("spec"))
    secret_keys = {
        key for key in (_dict(item).get("secretKey") for item in _list(spec.get("data"))) if isinstance(key, str)
    }
    template = _dict(spec.get("target")).get("template")
    if not isinstance(template, dict):
        return secret_keys
    keys = {key for key in _dict(template.get("data")) if isinstance(key, str)}
    if template.get("mergePolicy") == "Merge":
        keys |= secret_keys
    return keys


@dataclass(frozen=True)
class _EnvSources:
    """렌더 안의 env 원천 — ConfigMap 이름 → data 키 · Secret 이름(ES target · Secret 문서) → 키."""

    configmaps: dict[str, set[str]]
    secrets: dict[str, set[str]]


def _env_sources(docs: list[Doc]) -> _EnvSources:
    configmaps: dict[str, set[str]] = {}
    for document in _of_kind(docs, "ConfigMap"):
        configmaps.setdefault(_name(document), set()).update(
            key for key in _dict(document.get("data")) if isinstance(key, str)
        )
    secrets: dict[str, set[str]] = {}
    for document in _of_kind(docs, "ExternalSecret"):
        secrets.setdefault(_es_target_name(document), set()).update(_external_secret_keys(document))
    for document in _of_kind(docs, "Secret"):
        keys = set(_dict(document.get("data"))) | set(_dict(document.get("stringData")))
        secrets.setdefault(_name(document), set()).update(key for key in keys if isinstance(key, str))
    return _EnvSources(configmaps, secrets)


def _effective_env(
    container: dict[str, Any],
    sources: _EnvSources,
    *,
    configmaps: bool = True,
    skip_secrets: frozenset[str] = frozenset(),
) -> tuple[set[str], list[str]]:
    """컨테이너의 실효 env 이름 = env[].name ∪ (envFrom[].prefix + 참조한 ConfigMap · Secret의 키) + 렌더 밖 참조 문제.
    configmaps=False면 ConfigMap 참조를, skip_secrets의 Secret 참조를 세지 않는다(다른 검사가 그 참조 자체를 판정할 때)."""
    names = {name for name in (_dict(item).get("name") for item in _list(container.get("env"))) if isinstance(name, str)}
    problems: list[str] = []
    for item in _list(container.get("envFrom")):
        entry = _dict(item)
        prefix = entry.get("prefix")
        prefix = prefix if isinstance(prefix, str) else ""
        for ref_key, kind, index in (("configMapRef", "ConfigMap", sources.configmaps), ("secretRef", "Secret", sources.secrets)):
            if ref_key not in entry or (ref_key == "configMapRef" and not configmaps):
                continue
            ref_name = _dict(entry.get(ref_key)).get("name")
            if ref_key == "secretRef" and ref_name in skip_secrets:
                continue
            keys = index.get(ref_name) if isinstance(ref_name, str) else None
            if keys is None:
                problems.append(f"envFrom {ref_key} {ref_name!r} — 렌더 밖 {kind}(키를 알 수 없어 env 위생을 판정할 수 없다)")
            else:
                names.update(prefix + key for key in keys)
    return names, problems


def _template_refs(value: str) -> set[str]:
    """ESO v2 템플릿 값의 필드 참조 이름({{ .db_username | trimSuffix "_app" }} → db_username)."""
    refs: set[str] = set()
    for action in _TEMPLATE_ACTION_RE.findall(value):
        refs.update(_TEMPLATE_FIELD_RE.findall(_TEMPLATE_STRING_RE.sub('""', action)))
    return refs


def _complete_configmaps(docs: list[Doc]) -> set[str]:
    """키 5(CONFIGMAP_KEYS)를 모두 가진 ConfigMap 이름 — check_configmap(gen-16)이 요구하는 것."""
    return {
        _name(document)
        for document in _of_kind(docs, "ConfigMap")
        if CONFIGMAP_KEYS <= set(_dict(document.get("data")).keys())
    }


def _es_has_string_key(docs: list[Doc], es_name: str, key: str) -> bool:
    """ExternalSecret es_name(metadata.name)에 문자열 값을 가진 매핑 키 key가 있는가 — check_db_tls와 같은 판정."""
    return any(_string_values_for_key(document, key) for document in _of_kind(docs, "ExternalSecret") if _name(document) == es_name)


def _runtime_only_env(name: str) -> bool:
    """migrate 프로필에 두지 않는 런타임 전용 이름(ASCII 대소문자 무시 — owner 비밀의 범위 · X7)."""
    key = _env_key(name)
    return key in RUNTIME_ONLY_ENV_NAMES or key.startswith(RUNTIME_ONLY_ENV_PREFIXES)


# ---------- 워크로드 식별 ----------


@dataclass(frozen=True)
class Workloads:
    """식별된 워크로드 — web Deployment(web + relay 컨테이너) · celery Deployment · migrate Job ·
    CronJob(has_celery=False 모드에서만)."""

    web_deploy: Doc
    web: dict[str, Any]
    relay: dict[str, Any] | None
    celery_deploy: Doc | None
    job: Doc | None
    cronjob: Doc | None = None
    has_celery: bool = True

    def pod_docs(self) -> list[Doc]:
        documents = (self.web_deploy, self.celery_deploy, self.job, self.cronjob)
        return [document for document in documents if document is not None]

    def missing(self, *, relay: bool = True, celery: bool = True, job: bool = True, cronjob: bool = True) -> list[str]:
        """검사가 요구하는 부분 중 식별되지 않은 것 — 검사 함수가 "검사 대상 없음" 위반으로 쓴다. celery는 기본 모드,
        cronjob은 has_celery=False 모드에서만 요구된다."""
        problems: list[str] = []
        if relay and self.relay is None:
            problems.append(f"relay 컨테이너 식별 안 됨(web pod에 containerPort {RELAY_METRICS_PORT} 없음) — 검사 대상 없음")
        if celery and self.has_celery and self.celery_deploy is None:
            problems.append("celery Deployment 식별 안 됨 — 검사 대상 없음")
        if job and self.job is None:
            problems.append("migrate Job 식별 안 됨 — 검사 대상 없음")
        if cronjob and not self.has_celery and self.cronjob is None:
            problems.append("CronJob 식별 안 됨(has_celery=false) — 검사 대상 없음")
        return problems


@dataclass(frozen=True)
class Identification:
    workloads: Workloads | None  # None = web Deployment조차 찾지 못함
    violations: list[str]


def identify_workloads(docs: list[Doc], *, has_celery: bool = True) -> Identification:
    """web = containerPort 8000 컨테이너를 가진 Deployment · relay = 그 pod의 containerPort 9464 컨테이너 ·
    celery = 나머지 Deployment · migrate = Job(Argo PreSync hook). 그 밖에 Service · ConfigMap · Ingress ≥ 1 ·
    ExternalSecret <pod>-env · <pod>-migrate가 있어야 한다.
    has_celery=False(T072 변형): Deployment는 web 하나(celery Deployment 없음)이고 CronJob이 정확히 1이다(모양은
    check_cronjob이 본다). 기본 모드는 CronJob을 식별하지 않는다."""
    violations: list[str] = []
    deployments = _of_kind(docs, "Deployment")
    expected_deployments = 2 if has_celery else 1
    if len(deployments) != expected_deployments:
        names = [_name(document) for document in deployments]
        if has_celery:
            violations.append(f"Deployment {len(deployments)}개(기대 2: web+relay · celery) — {names}")
        else:
            violations.append(f"Deployment {len(deployments)}개(기대 1: web+relay — has_celery=false라 celery 없음) — {names}")

    def has_web_port(document: Doc) -> bool:
        return any(WEB_PORT in _container_ports(item) for item in _containers(_pod_spec(document)))

    def port_summary(documents: list[Doc]) -> list[tuple[str, list[tuple[Any, list[int]]]]]:
        """있던 것을 보여 주는 요약 — [(Deployment 이름, [(컨테이너 이름, [containerPort…])…])…](r1 A-4)."""
        return [
            (_name(document), [(item.get("name"), sorted(_container_ports(item))) for item in _containers(_pod_spec(document))])
            for document in documents
        ]

    web_candidates = [document for document in deployments if has_web_port(document)]
    workloads: Workloads | None = None
    if not web_candidates:
        violations.append(
            f"web Deployment 없음(containerPort {WEB_PORT}인 컨테이너를 가진 Deployment가 없다) — 있는 것: {port_summary(deployments)}"
        )
    else:
        web_deploy = web_candidates[0]
        if len(web_candidates) > 1:
            names = [_name(document) for document in web_candidates]
            violations.append(f"web 후보 Deployment {len(web_candidates)}개 {names} — 첫 것({_name(web_deploy)})을 web으로 본다")
        pod_containers = _containers(_pod_spec(web_deploy))
        web_containers = [item for item in pod_containers if WEB_PORT in _container_ports(item)]
        if len(web_containers) > 1:
            violations.append(f"{_ref(web_deploy)}: containerPort {WEB_PORT} 컨테이너가 {len(web_containers)}개(기대 1)")
        web = web_containers[0]
        relays = [item for item in pod_containers if item is not web and RELAY_METRICS_PORT in _container_ports(item)]
        if not relays:
            violations.append(
                f"{_ref(web_deploy)}: relay 컨테이너 없음(containerPort {RELAY_METRICS_PORT}인 컨테이너가 없다) — "
                f"있는 것: {port_summary([web_deploy])[0][1]}"
            )
        elif len(relays) > 1:
            violations.append(f"{_ref(web_deploy)}: containerPort {RELAY_METRICS_PORT} 컨테이너가 {len(relays)}개(기대 1)")
        others = [document for document in deployments if not any(document is item for item in web_candidates)]
        celery_deploy: Doc | None = None
        if has_celery:
            if not others:
                violations.append("celery Deployment 없음(web 외의 Deployment가 없다)")
            elif len(others) > 1:
                names = [_name(document) for document in others]
                violations.append(f"celery 후보 Deployment {len(others)}개 {names} — 첫 것을 celery로 본다")
            celery_deploy = others[0] if others else None
        elif others:
            names = [_name(document) for document in others]
            violations.append(f"has_celery=false인데 web 외 Deployment {names}가 있다(celery Deployment가 없어야 한다)")
        workloads = Workloads(
            web_deploy=web_deploy,
            web=web,
            relay=relays[0] if relays else None,
            celery_deploy=celery_deploy,
            job=None,
            has_celery=has_celery,
        )

    jobs = _of_kind(docs, "Job")
    if len(jobs) != 1:
        violations.append(f"Job {len(jobs)}개(기대 1: migrate) — {[_name(document) for document in jobs]}")
    job = jobs[0] if jobs else None
    if job is not None:
        hook = _annotations(job).get(HOOK_ANNOTATION)
        if hook != HOOK_VALUE:
            violations.append(f"{_ref(job)}: 어노테이션 {HOOK_ANNOTATION} = {hook!r}(기대 {HOOK_VALUE!r})")
    cronjob: Doc | None = None
    if not has_celery:
        cronjobs = _of_kind(docs, "CronJob")
        if len(cronjobs) != 1:
            names = [_name(document) for document in cronjobs]
            violations.append(f"CronJob {len(cronjobs)}개(기대 1: dead outbox purge — has_celery=false) — {names}")
        cronjob = cronjobs[0] if cronjobs else None
    if workloads is not None:
        workloads = replace(workloads, job=job, cronjob=cronjob)

    for kind in ("Service", "ConfigMap", "Ingress"):
        if not _of_kind(docs, kind):
            violations.append(f"{kind} 없음(기대 ≥ 1)")
    secret_names = {_name(document) for document in _of_kind(docs, "ExternalSecret")}
    missing = sorted({ENV_SECRET, MIGRATE_SECRET} - secret_names)
    if missing:
        violations.append(f"ExternalSecret 없음: {missing}(있는 것: {sorted(secret_names)})")
    return Identification(workloads, violations)


def _identified(docs: list[Doc], has_celery: bool) -> tuple[Workloads | None, list[str]]:
    workloads = identify_workloads(docs, has_celery=has_celery).workloads
    if workloads is None:
        return None, ["워크로드를 식별하지 못해 검사할 수 없다 — check_identification(gen-8)의 위반을 먼저 본다"]
    return workloads, []


def _role_targets(workloads: Workloads) -> list[tuple[str, Doc, dict[str, Any]]]:
    """메모리 역할별 컨테이너 — web · relay · celery(컨테이너 전부) · migrate(Job 첫 실행 컨테이너) ·
    outbox-purge(CronJob 컨테이너 전부)."""
    targets: list[tuple[str, Doc, dict[str, Any]]] = [("web", workloads.web_deploy, workloads.web)]
    if workloads.relay is not None:
        targets.append(("relay", workloads.web_deploy, workloads.relay))
    if workloads.celery_deploy is not None:
        celery_containers = _containers(_pod_spec(workloads.celery_deploy))
        targets.extend(("celery", workloads.celery_deploy, item) for item in celery_containers)
    if workloads.job is not None:
        first = _first_executing(_pod_spec(workloads.job))
        if first is not None:
            targets.append(("migrate", workloads.job, first))
    if workloads.cronjob is not None:
        cron_containers = _containers(_pod_spec(workloads.cronjob))
        targets.extend(("outbox-purge", workloads.cronjob, item) for item in cron_containers)
    return targets


def check_identification(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-8 — 워크로드 · 부속 객체 식별(has_celery=False면 변형 워크로드 집합)."""
    return identify_workloads(docs, has_celery=has_celery).violations


# ---------- 검사 ----------


def check_security_context(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-9 — 워크로드(web · celery · migrate · 변형의 CronJob)의 pod: automountServiceAccountToken false ·
    runAsNonRoot · runAsUser · runAsGroup 10001(정수 — T072) · seccomp RuntimeDefault. 모든 컨테이너(initContainers 포함):
    allowPrivilegeEscalation false · capabilities.drop [ALL] · readOnlyRootFilesystem true + /tmp emptyDir 마운트.
    컨테이너 단위 덮어쓰기(runAsNonRoot false · seccomp 다른 값 · NET_BIND_SERVICE 밖의 capabilities.add · runAsUser ·
    runAsGroup이 있으면 10001이 아닌 값)도 위반이다(계약 "PSA restricted 통과")."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(relay=False))
    for document in workloads.pod_docs():
        spec = _pod_spec(document)
        where = _ref(document)
        automount = spec.get("automountServiceAccountToken")
        if automount is not False:
            violations.append(f"{where}: automountServiceAccountToken = {automount!r}(기대 False)")
        pod_security = _dict(spec.get("securityContext"))
        if pod_security.get("runAsNonRoot") is not True:
            violations.append(f"{where}: securityContext.runAsNonRoot = {pod_security.get('runAsNonRoot')!r}(기대 True)")
        for field in RUN_AS_FIELDS:
            if _int(pod_security.get(field)) != RUN_AS_ID:
                violations.append(
                    f"{where}: securityContext.{field} = {pod_security.get(field)!r}(기대 정수 {RUN_AS_ID} — 이미지 USER 10001:10001)"
                )
        seccomp = _dict(pod_security.get("seccompProfile")).get("type")
        if seccomp != "RuntimeDefault":
            violations.append(f"{where}: securityContext.seccompProfile.type = {seccomp!r}(기대 'RuntimeDefault')")
        volumes = {_dict(item).get("name"): _dict(item) for item in _list(spec.get("volumes"))}
        for container in _all_containers(spec):
            at = _where(document, container)
            security = _dict(container.get("securityContext"))
            escalation = security.get("allowPrivilegeEscalation")
            if escalation is not False:
                violations.append(f"{at}: allowPrivilegeEscalation = {escalation!r}(기대 False)")
            capabilities = _dict(security.get("capabilities"))
            if capabilities.get("drop") != ["ALL"]:
                violations.append(f"{at}: capabilities.drop = {capabilities.get('drop')!r}(기대 ['ALL'])")
            added = [item for item in _list(capabilities.get("add")) if item not in PSA_ALLOWED_ADD]
            if added:
                violations.append(f"{at}: capabilities.add = {added!r}(PSA restricted는 NET_BIND_SERVICE만 허용)")
            if security.get("readOnlyRootFilesystem") is not True:
                violations.append(f"{at}: readOnlyRootFilesystem = {security.get('readOnlyRootFilesystem')!r}(기대 True)")
            if security.get("runAsNonRoot") is False:
                violations.append(f"{at}: 컨테이너 securityContext.runAsNonRoot = False(pod 값을 덮어쓴다)")
            for field in RUN_AS_FIELDS:
                if field in security and _int(security.get(field)) != RUN_AS_ID:
                    violations.append(f"{at}: 컨테이너 securityContext.{field} = {security.get(field)!r}(있으면 정수 {RUN_AS_ID})")
            if "seccompProfile" in security:
                container_seccomp = _dict(security.get("seccompProfile")).get("type")
                if container_seccomp != "RuntimeDefault":
                    violations.append(f"{at}: 컨테이너 seccompProfile.type = {container_seccomp!r}(기대 'RuntimeDefault')")
            mounts = [_dict(item) for item in _list(container.get("volumeMounts"))]
            tmp_mounts = [mount for mount in mounts if mount.get("mountPath") == "/tmp"]
            if not tmp_mounts:
                violations.append(f"{at}: /tmp 마운트 없음(readOnlyRootFilesystem에는 /tmp emptyDir가 필요)")
            for mount in tmp_mounts:
                volume = volumes.get(mount.get("name"))
                if volume is None:
                    violations.append(f"{at}: /tmp 마운트의 볼륨 {mount.get('name')!r}가 pod volumes에 없다")
                elif not isinstance(volume.get("emptyDir"), dict):
                    violations.append(f"{at}: /tmp 볼륨 {mount.get('name')!r}가 emptyDir가 아니다")
    return violations


def check_env_split(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-10 — 런타임(web · relay · celery · 변형의 CronJob)은 <pod>-env만, migrate Job은 <pod>-migrate만 참조한다(owner
    자격은 Job만). 런타임 pod의 볼륨으로도 <pod>-migrate가 들어오지 않고, ExternalSecret <pod>-env에 DATABASE_OWNER_URL이
    없다(rules/django-pod.md §Settings: DATABASE_OWNER_URL은 migrate Job env에만 있다)."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing())
    required: list[tuple[Doc, dict[str, Any]]] = [(workloads.web_deploy, workloads.web)]
    if workloads.relay is not None:
        required.append((workloads.web_deploy, workloads.relay))
    for document in (workloads.celery_deploy, workloads.cronjob):
        if document is not None:
            required.extend((document, item) for item in _containers(_pod_spec(document)))
    for document, container in required:
        refs = _secret_refs(container)
        if ENV_SECRET not in refs:
            violations.append(f"{_where(document, container)}: 시크릿 {ENV_SECRET} 참조 없음(참조: {sorted(refs)})")
    runtime_pods = [
        document for document in (workloads.web_deploy, workloads.celery_deploy, workloads.cronjob) if document is not None
    ]
    for document in runtime_pods:
        spec = _pod_spec(document)
        for container in _all_containers(spec):
            if MIGRATE_SECRET in _secret_refs(container):
                violations.append(f"{_where(document, container)}: 런타임 컨테이너가 {MIGRATE_SECRET}(owner 자격)을 참조한다")
        for item in _list(spec.get("volumes")):
            volume = _dict(item)
            if MIGRATE_SECRET in _volume_secret_names(volume):
                violations.append(f"{_ref(document)}: 볼륨 {volume.get('name')!r}가 {MIGRATE_SECRET}(owner 자격)을 담는다")
    if workloads.job is not None:
        for container in _all_containers(_pod_spec(workloads.job)):
            refs = _secret_refs(container)
            at = _where(workloads.job, container)
            if MIGRATE_SECRET not in refs:
                violations.append(f"{at}: 시크릿 {MIGRATE_SECRET} 참조 없음(참조: {sorted(refs)})")
            if ENV_SECRET in refs:
                violations.append(f"{at}: migrate Job이 런타임 시크릿 {ENV_SECRET}을 참조한다")
    for secret in _of_kind(docs, "ExternalSecret"):
        if _name(secret) != ENV_SECRET:
            continue
        # 매핑 키(spec.target.template.data) 또는 spec.data[].secretKey 값(템플릿 없는 꼴 — r1 A-5). spec.dataFrom[].extract는
        # 키를 알 수 없어 범위 밖이다.
        if _has_key(secret, OWNER_URL_KEY) or OWNER_URL_KEY in _string_values_for_key(secret, "secretKey"):
            violations.append(f"{_ref(secret)}: {OWNER_URL_KEY}가 런타임 시크릿에 있다(migrate 전용 — template.data 키 또는 spec.data[].secretKey)")
    return violations


def _mounts_ca(container: dict[str, Any], ca_volumes: set[str]) -> bool:
    for item in _list(container.get("volumeMounts")):
        mount = _dict(item)
        if mount.get("name") not in ca_volumes:
            continue
        path = _normalize_path(mount.get("mountPath"))
        sub_path = mount.get("subPath")
        if path == PG_CA_DIR and not sub_path:
            return True
        if path == PG_CA_FILE and sub_path == PG_CA_KEY:
            return True
    return False


def check_db_tls(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-11 — ExternalSecret <pod>-env의 DATABASE_URL · <pod>-migrate의 DATABASE_OWNER_URL 값에
    sslmode=verify-full과 sslrootcert=/etc/pg/ca.crt. 워크로드 모두 secretName pg-main-ca 볼륨이 있고 web pod의
    initContainers(startup-check — T072) · web · relay와 celery · migrate · 변형의 CronJob 컨테이너가 그것을 /etc/pg(디렉터리)
    또는 /etc/pg/ca.crt(subPath ca.crt)로 마운트한다."""
    violations: list[str] = []
    secrets = {_name(document): document for document in _of_kind(docs, "ExternalSecret")}
    for secret_name, url_key in DB_URL_KEYS.items():
        secret = secrets.get(secret_name)
        if secret is None:
            violations.append(f"ExternalSecret/{secret_name} 없음 — {url_key} TLS 검사 대상 없음")
            continue
        values = _string_values_for_key(secret, url_key)
        if not values:
            violations.append(f"ExternalSecret/{secret_name}: {url_key} 키가 없다")
        for value in values:
            missing = [part for part in DB_TLS_PARTS if part not in value]
            if missing:
                violations.append(f"ExternalSecret/{secret_name}: {url_key} 값에 {missing} 없음")
    workloads, missing_workloads = _identified(docs, has_celery)
    if workloads is None:
        return violations + missing_workloads
    violations.extend(workloads.missing())
    for document in workloads.pod_docs():
        spec = _pod_spec(document)
        ca_volumes = {
            _dict(item).get("name")
            for item in _list(spec.get("volumes"))
            if _dict(_dict(item).get("secret")).get("secretName") == PG_CA_SECRET
        }
        if not ca_volumes:
            violations.append(f"{_ref(document)}: secretName {PG_CA_SECRET} 볼륨 없음")
        if document is workloads.web_deploy:
            targets = _init_containers(spec) + [item for item in (workloads.web, workloads.relay) if item is not None]
        else:
            targets = _all_containers(spec)
        for container in targets:
            if not _mounts_ca(container, ca_volumes):
                violations.append(
                    f"{_where(document, container)}: {PG_CA_SECRET} 볼륨을 {PG_CA_DIR} 또는 {PG_CA_FILE}"
                    f"(subPath {PG_CA_KEY})로 마운트하지 않는다"
                )
    return violations


def check_probes(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-12 — web: liveness GET /healthz · readiness GET /ready · startupProbe GET /ready(failureThreshold 30 ×
    periodSeconds 5), 포트는 web HTTP 8000. relay: liveness TCP 9464, readiness · startupProbe 없음. 워크로드의 어떤
    컨테이너의 어떤 프로브도 /health를 쓰지 않는다. timeoutSeconds 하한은 check_pod_lifecycle(gen-19) 몫이다."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(celery=False, job=False, cronjob=False))
    web_at = _where(workloads.web_deploy, workloads.web)
    for probe_name, expected_path in WEB_PROBES.items():
        probe = workloads.web.get(probe_name)
        if not isinstance(probe, dict):
            violations.append(f"{web_at}: {probe_name} 없음(기대 GET {expected_path})")
            continue
        http_get = _dict(probe.get("httpGet"))
        if http_get.get("path") != expected_path:
            violations.append(f"{web_at}: {probe_name}.httpGet.path = {http_get.get('path')!r}(기대 {expected_path!r})")
        port = resolve_port(workloads.web, http_get.get("port"))
        if port != WEB_PORT:
            violations.append(f"{web_at}: {probe_name}.httpGet.port → {port!r}(기대 {WEB_PORT})")
    startup = _dict(workloads.web.get("startupProbe"))
    if startup:
        startup_expected = (("failureThreshold", STARTUP_FAILURE_THRESHOLD), ("periodSeconds", STARTUP_PERIOD_SECONDS))
        for field, expected in startup_expected:
            if startup.get(field) != expected:
                violations.append(f"{web_at}: startupProbe.{field} = {startup.get(field)!r}(기대 {expected})")
    if workloads.relay is not None:
        relay_at = _where(workloads.web_deploy, workloads.relay)
        liveness = workloads.relay.get("livenessProbe")
        if not isinstance(liveness, dict):
            violations.append(f"{relay_at}: livenessProbe 없음(기대 TCP {RELAY_METRICS_PORT})")
        elif not isinstance(liveness.get("tcpSocket"), dict):
            kinds = sorted(key for key in ("httpGet", "exec", "grpc") if key in liveness)
            violations.append(f"{relay_at}: livenessProbe가 tcpSocket이 아니다({kinds}) — 기대 TCP {RELAY_METRICS_PORT}")
        else:
            port = resolve_port(workloads.relay, liveness["tcpSocket"].get("port"))
            if port != RELAY_METRICS_PORT:
                violations.append(f"{relay_at}: livenessProbe.tcpSocket.port → {port!r}(기대 {RELAY_METRICS_PORT})")
        for probe_name in ("readinessProbe", "startupProbe"):
            if workloads.relay.get(probe_name) is not None:
                violations.append(f"{relay_at}: {probe_name}가 있다(relay는 liveness TCP만)")
    for document in workloads.pod_docs():
        for container in _all_containers(_pod_spec(document)):
            for probe_name in PROBE_KINDS:
                path = _dict(_dict(container.get(probe_name)).get("httpGet")).get("path")
                if _normalize_path(path) == HEALTH_PATH:
                    violations.append(f"{_where(document, container)}: {probe_name}가 {HEALTH_PATH}를 쓴다(어떤 프로브에도 금지)")
    return violations


def check_strategy_resources(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-13 — Deployment(기본 2 · 변형 1): RollingUpdate maxSurge 1 · maxUnavailable 0 · 노드 A 선호 affinity(preferred
    role In platform). requests.memory: web 256Mi · relay 96Mi · celery 192Mi · migrate(Job 첫 실행 컨테이너) 256Mi ·
    변형의 CronJob 컨테이너 256Mi. 워크로드의 모든 컨테이너에 resources.limits.cpu 없음. memory limits ·
    initContainer 자원은 check_runtime_wiring(gen-36) 몫이다."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing())
    deployments = [document for document in (workloads.web_deploy, workloads.celery_deploy) if document is not None]
    for document in deployments:
        where = _ref(document)
        strategy = _dict(_dict(document.get("spec")).get("strategy"))
        if strategy.get("type") != "RollingUpdate":
            violations.append(f"{where}: strategy.type = {strategy.get('type')!r}(기대 'RollingUpdate')")
        rolling = _dict(strategy.get("rollingUpdate"))
        for field, expected in (("maxSurge", MAX_SURGE), ("maxUnavailable", MAX_UNAVAILABLE)):
            if int_or_digits(rolling.get(field)) != expected:
                violations.append(f"{where}: rollingUpdate.{field} = {rolling.get(field)!r}(기대 {expected})")
        preferred = _list(_dict(_dict(_pod_spec(document).get("affinity")).get("nodeAffinity")).get(
            "preferredDuringSchedulingIgnoredDuringExecution"
        ))
        expressions = [
            _dict(expression)
            for term in preferred
            for expression in _list(_dict(_dict(term).get("preference")).get("matchExpressions"))
        ]
        if not any(
            expression.get("key") == AFFINITY_KEY
            and expression.get("operator") == AFFINITY_OPERATOR
            and AFFINITY_VALUE in _list(expression.get("values"))
            for expression in expressions
        ):
            violations.append(
                f"{where}: 노드 A 선호 affinity 없음(preferredDuringSchedulingIgnoredDuringExecution에 "
                f"{AFFINITY_KEY} {AFFINITY_OPERATOR} [{AFFINITY_VALUE}])"
            )
    if workloads.job is not None and _first_executing(_pod_spec(workloads.job)) is None:
        violations.append(f"{_ref(workloads.job)}: 컨테이너가 없다")
    for role, document, container in _role_targets(workloads):
        expected = MEMORY_REQUESTS[role]
        actual = _dict(_dict(container.get("resources")).get("requests")).get("memory")
        if memory_bytes(actual) != memory_bytes(expected):
            violations.append(f"{_where(document, container)}: requests.memory = {actual!r}(기대 {expected!r} — {role})")
    for document in workloads.pod_docs():
        for container in _all_containers(_pod_spec(document)):
            limits = _dict(_dict(container.get("resources")).get("limits"))
            if "cpu" in limits:
                violations.append(f"{_where(document, container)}: limits.cpu = {limits['cpu']!r}(CPU limit 금지)")
    return violations


def check_migrate_sql(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-14 — migrate Job의 첫 실행 컨테이너(initContainers[0] 또는 containers[0])의 command + args에
    REVOKE CONNECT ON DATABASE … FROM PUBLIC · GRANT CONNECT ON DATABASE … TO …가 있고, REVOKE가 migrate보다 앞이다
    (대소문자 무시 · 공백 정규화)."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    if workloads.job is None:
        return ["migrate Job 식별 안 됨 — 검사 대상 없음"]
    first = _first_executing(_pod_spec(workloads.job))
    if first is None:
        return [f"{_ref(workloads.job)}: 컨테이너가 없다"]
    at = _where(workloads.job, first)
    parts = [str(item) for item in _list(first.get("command")) + _list(first.get("args"))]
    text = " ".join(" ".join(parts).split())
    revoke = _REVOKE_RE.search(text)
    grant = _GRANT_RE.search(text)
    migrate = _MIGRATE_RE.search(text)
    if revoke is None:
        violations.append(f"{at}: 첫 단계에 REVOKE CONNECT ON DATABASE … FROM PUBLIC이 없다")
    if grant is None:
        violations.append(f"{at}: 첫 단계에 GRANT CONNECT ON DATABASE … TO …가 없다")
    if migrate is None:
        violations.append(f"{at}: 첫 단계에 migrate가 없다")
    if revoke is not None and migrate is not None and not revoke.start() < migrate.start():
        violations.append(f"{at}: REVOKE CONNECT가 migrate보다 뒤에 있다(CONNECT 경계 SQL이 먼저여야 한다)")
    return violations


def check_annotations(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-15 — Deployment(기본 2 · 변형 1)의 reloader.stakater.com/auto: "true" · web pod 템플릿의
    k8s.grafana.com/scrape: "true" · relay 컨테이너 포트 9464."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(job=False, cronjob=False))
    for document in (workloads.web_deploy, workloads.celery_deploy):
        if document is None:
            continue
        value = _annotations(document).get(RELOADER_ANNOTATION)
        if value != "true":
            violations.append(f"{_ref(document)}: 어노테이션 {RELOADER_ANNOTATION} = {value!r}(기대 'true')")
    template = _dict(_dict(workloads.web_deploy.get("spec")).get("template"))
    scrape = _dict(_dict(template.get("metadata")).get("annotations")).get(SCRAPE_ANNOTATION)
    if scrape != "true":
        violations.append(f"{_ref(workloads.web_deploy)}: pod 템플릿 어노테이션 {SCRAPE_ANNOTATION} = {scrape!r}(기대 'true')")
    if workloads.relay is not None and RELAY_METRICS_PORT not in _container_ports(workloads.relay):
        violations.append(f"{_where(workloads.web_deploy, workloads.relay)}: containerPort {RELAY_METRICS_PORT} 없음")
    return violations


def check_configmap(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-16 — data 키가 ACCESS_AUD_M2M · ACCESS_AUD_ADMIN · ACCESS_EXPECTED_CN · ADMIN_HOST · ALLOWED_HOSTS를 모두
    가진 ConfigMap이 있고, web과 celery(변형이면 CronJob) 컨테이너가 그것을 envFrom[].configMapRef.name으로 참조한다."""
    violations: list[str] = []
    complete = [
        document
        for document in _of_kind(docs, "ConfigMap")
        if CONFIGMAP_KEYS <= set(_dict(document.get("data")).keys())
    ]
    if not complete:
        partial = {
            _name(document): sorted(CONFIGMAP_KEYS - set(_dict(document.get("data")).keys()))
            for document in _of_kind(docs, "ConfigMap")
        }
        violations.append(f"키 {sorted(CONFIGMAP_KEYS)}를 모두 가진 ConfigMap 없음(ConfigMap별 빠진 키: {partial})")
    names = {_name(document) for document in complete}
    workloads, missing_workloads = _identified(docs, has_celery)
    if workloads is None:
        return violations + missing_workloads
    violations.extend(workloads.missing(relay=False, job=False))
    targets: list[tuple[Doc, dict[str, Any]]] = [(workloads.web_deploy, workloads.web)]
    for document in (workloads.celery_deploy, workloads.cronjob):
        if document is not None:
            targets.extend((document, item) for item in _containers(_pod_spec(document)))
    for document, container in targets:
        refs = {
            _dict(_dict(item).get("configMapRef")).get("name")
            for item in _list(container.get("envFrom"))
        }
        if not refs & names:
            at = _where(document, container)
            violations.append(f"{at}: envFrom configMapRef가 키 5 ConfigMap {sorted(names)}을 참조하지 않는다")
    return violations


def _service_binding(service: Doc, workloads: Workloads | None) -> list[str]:
    """Ingress backend가 가리키는 Service의 결속(T072 r2 E6 · D20 service.yaml) — 이름 http인 포트 하나: port 80 · targetPort가
    web 컨테이너의 8000으로 풀린다(이름 http 또는 숫자) · selector가 비지 않고 web pod 템플릿 라벨에 포함되며 다른 식별
    워크로드(celery · migrate Job · CronJob)의 pod 라벨에는 포함되지 않는다(8000이 없는 pod로 요청이 가지 않게). web을
    식별하지 못하면 targetPort · selector는 판정하지 않는다(identification 몫)."""
    violations: list[str] = []
    where = _ref(service)
    spec = _dict(service.get("spec"))
    http_ports = [_dict(item) for item in _list(spec.get("ports")) if _dict(item).get("name") == INGRESS_BACKEND_PORT]
    if len(http_ports) != 1:
        violations.append(f"{where}: 이름 {INGRESS_BACKEND_PORT!r}인 포트 {len(http_ports)}개(기대 1 — Ingress backend 포트 이름)")
    else:
        port = http_ports[0]
        if _int(port.get("port")) != SERVICE_PORT:
            violations.append(f"{where}: 포트 {INGRESS_BACKEND_PORT!r}의 port = {port.get('port')!r}(기대 {SERVICE_PORT})")
        if workloads is not None:
            target = port.get("targetPort")
            resolved = resolve_port(workloads.web, target)
            if resolved != WEB_PORT:
                violations.append(
                    f"{where}: 포트 {INGRESS_BACKEND_PORT!r}의 targetPort = {target!r} → web 컨테이너 포트 {resolved!r}"
                    f"(기대 {WEB_PORT} — 이름 {INGRESS_BACKEND_PORT!r})"
                )
    if workloads is None:
        return violations
    selector = _dict(spec.get("selector"))

    def selects(document: Doc) -> bool:
        labels = _dict(_dict(_pod_template(document).get("metadata")).get("labels"))
        return bool(selector) and all(labels.get(key) == value for key, value in selector.items())

    if not selects(workloads.web_deploy):
        violations.append(f"{where}: selector = {selector!r}가 web pod 템플릿 라벨에 포함되지 않는다(비지 않아야 한다)")
    for other in (workloads.celery_deploy, workloads.job, workloads.cronjob):
        if other is not None and selects(other):
            violations.append(f"{where}: selector = {selector!r}가 {_ref(other)} pod도 고른다(web pod만 — component)")
    return violations


def check_ingress(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-17 — 전 Ingress의 경로 합집합 = {/api, /health, /session, /sessions, /tenants} · /healthz · /ready ·
    /webhooks로 시작하는 경로 없음. T072 확장: Ingress마다 ingressClassName traefik · 어노테이션
    router.entrypoints websecure · router.tls "true" · spec.tls 없음 · 규칙 host = PLACEHOLDER.joshuatech.dev(overlay가
    /spec/rules/0/host를 바꾼다) · 허용 5경로의 pathType(/health Exact · 나머지 Prefix) · 모든 경로의 backend 포트 이름 http.
    T072 r2(E6 · A-6): 모든 경로의 backend service.name = 렌더의 Service 이름 · 그 Service의 결속(_service_binding — 포트
    http 80 → web 8000 · selector). 렌더에 Service가 하나도 없으면 결속은 판정하지 않는다(identification 몫)."""
    ingresses = _of_kind(docs, "Ingress")
    if not ingresses:
        return ["Ingress 없음 — 경로 검사 대상 없음"]
    violations: list[str] = []
    paths: set[str] = set()
    services = {_name(document): document for document in _of_kind(docs, "Service")}
    bound: set[str] = set()
    for document in ingresses:
        where = _ref(document)
        spec = _dict(document.get("spec"))
        if spec.get("ingressClassName") != INGRESS_CLASS:
            violations.append(f"{where}: ingressClassName = {spec.get('ingressClassName')!r}(기대 {INGRESS_CLASS!r})")
        notes = _annotations(document)
        for key, expected in INGRESS_ANNOTATIONS.items():
            if notes.get(key) != expected:
                violations.append(f"{where}: 어노테이션 {key} = {notes.get(key)!r}(기대 {expected!r})")
        if "tls" in spec:
            violations.append(f"{where}: spec.tls가 있다(인증서는 Traefik TLSStore 와일드카드가 SNI로 고른다 — 생략)")
        for index, rule in enumerate(_list(spec.get("rules"))):
            host = _dict(rule).get("host")
            if host != INGRESS_HOST:
                violations.append(f"{where}: rules[{index}].host = {host!r}(기대 {INGRESS_HOST!r})")
            for item in _list(_dict(_dict(rule).get("http")).get("paths")):
                entry = _dict(item)
                path = entry.get("path")
                if isinstance(path, str):
                    paths.add(path)
                if path in INGRESS_PATHS:
                    expected_type = "Exact" if path in INGRESS_EXACT_PATHS else "Prefix"
                    if entry.get("pathType") != expected_type:
                        violations.append(f"{where}: 경로 {path!r} pathType = {entry.get('pathType')!r}(기대 {expected_type!r})")
                backend = _dict(_dict(entry.get("backend")).get("service"))
                port = _dict(backend.get("port"))
                if port.get("name") != INGRESS_BACKEND_PORT:
                    violations.append(f"{where}: 경로 {path!r} backend 포트 = {port!r}(기대 이름 {INGRESS_BACKEND_PORT!r})")
                service_name = backend.get("name")
                if services and service_name not in services:
                    violations.append(
                        f"{where}: 경로 {path!r} backend service.name = {service_name!r}(렌더의 Service {sorted(services)}가 아니다)"
                    )
                elif isinstance(service_name, str) and service_name in services:
                    bound.add(service_name)
    if bound:
        workloads = identify_workloads(docs, has_celery=has_celery).workloads
        for service_name in sorted(bound):
            violations.extend(_service_binding(services[service_name], workloads))
    if paths != INGRESS_PATHS:
        violations.append(
            f"Ingress 경로 집합 = {sorted(paths)}(기대 {sorted(INGRESS_PATHS)}) — 빠짐 {sorted(INGRESS_PATHS - paths)} · "
            f"남음 {sorted(paths - INGRESS_PATHS)}"
        )
    for path in sorted(paths):
        if path.startswith(INGRESS_FORBIDDEN_PREFIXES):
            violations.append(f"Ingress 경로 {path!r}는 노출 금지(/healthz · /ready · /webhooks)")
    return violations


def check_pod_lifecycle(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-19(T072 · 계약 §기본 테스트 6 · D8 · X29) — web Deployment pod terminationGracePeriodSeconds ≥ 90(relay 한
    패스 최악 ≈ 80 s) · web 컨테이너에 있는 프로브(liveness · readiness · startup)의 timeoutSeconds ≥ 3(없으면 kubelet 기본
    1 s — 프로브가 있고 없음 · 경로는 check_probes 몫) · env POD_IP = fieldRef status.podIP(kubelet 프로브 Host가 pod IP다) ·
    lifecycle.preStop.sleep.seconds ≥ 5(엔드포인트 제거와 SIGTERM의 경합)."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    spec = _pod_spec(workloads.web_deploy)
    grace = spec.get("terminationGracePeriodSeconds")
    grace_value = _int(grace)
    if grace_value is None or grace_value < GRACE_SECONDS_MIN:
        violations.append(
            f"{_ref(workloads.web_deploy)}: terminationGracePeriodSeconds = {grace!r}(기대 ≥ {GRACE_SECONDS_MIN} — 없으면 30)"
        )
    web_at = _where(workloads.web_deploy, workloads.web)
    for probe_name in PROBE_KINDS:
        probe = workloads.web.get(probe_name)
        if not isinstance(probe, dict):
            continue
        timeout = probe.get("timeoutSeconds", PROBE_TIMEOUT_DEFAULT)
        timeout_value = _int(timeout)
        if timeout_value is None or timeout_value < PROBE_TIMEOUT_MIN:
            violations.append(
                f"{web_at}: {probe_name}.timeoutSeconds = {probe.get('timeoutSeconds')!r}(기대 ≥ {PROBE_TIMEOUT_MIN} — "
                f"없으면 {PROBE_TIMEOUT_DEFAULT})"
            )
    pod_ip = _field_ref_paths(workloads.web, POD_IP_ENV)
    if pod_ip != [POD_IP_FIELD]:
        violations.append(f"{web_at}: env {POD_IP_ENV} fieldRef = {pod_ip!r}(기대 [{POD_IP_FIELD!r}] 하나)")
    sleep = _dict(_dict(_dict(workloads.web.get("lifecycle")).get("preStop")).get("sleep")).get("seconds")
    sleep_value = _int(sleep)
    if sleep_value is None or sleep_value < PRE_STOP_SLEEP_MIN:
        violations.append(f"{web_at}: lifecycle.preStop.sleep.seconds = {sleep!r}(기대 ≥ {PRE_STOP_SLEEP_MIN})")
    return violations


def check_env_hygiene(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-20(T072 · T071 S4/L3 · X18 · 계약 §기본 테스트 6) — 워크로드의 컨테이너마다 실효 env 이름(env[].name ∪
    envFrom[].prefix + 참조한 ConfigMap 키 · Secret 키 — ES는 template.data 키, 템플릿이 없거나 Merge면 secretKey)에 금지
    이름이 없다(ASCII 대소문자 무시): NETRC · SSLKEYLOGFILE · *_PROXY · CLIENT_CERT_FILE · CLIENT_KEY_FILE · SSL_CERT_FILE ·
    SSL_CERT_DIR · REQUESTS_CA_BUNDLE · CURL_CA_BUNDLE · SENTRY_PRINT_ENVELOPES · PYTHONOPTIMIZE · PYTHONINSPECT ·
    PYTHONSTARTUP · PYTHONPATH · PROMETHEUS_MULTIPROC_DIR · PG로 시작하는 이름 전부 · 검증된 설정을 대신하는 env(T072 ② r2
    H10 — CELERY_BROKER_URL · CELERY_BROKER_READ_URL · CELERY_BROKER_WRITE_URL · CELERY_RESULT_BACKEND ·
    GUNICORN_CMD_ARGS — 이 다섯만은 생성 pod 기동 단언도 거부한다). 렌더 밖 ConfigMap · Secret을 가리키는
    envFrom은 위반(키를 알 수 없다). PROMETHEUS_MULTIPROC_DIR는 모든 ConfigMap 키 · <pod>-env 키에도 없다(참조 여부 무관 —
    어떤 컨테이너도 참조하지 않는 ConfigMap도 본다: render-156 · 158). <pod>-env 키 루프는 env_split 아래에서는 실효 env 규칙과
    겹친다(해 없음 — env_split이 모든 런타임 컨테이너에 <pod>-env 참조를 강제하므로 그 키는 이미 실효 env에 있다).
    런타임 거부는 두지 않는다 — 렌더 · 이미지 단언 + gitops lint가 방어선이다(T071 · 검증된 설정을 대신하는 env 다섯만 예외)."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(relay=False))
    sources = _env_sources(docs)
    for document in workloads.pod_docs():
        for container in _all_containers(_pod_spec(document)):
            at = _where(document, container)
            names, problems = _effective_env(container, sources)
            violations.extend(f"{at}: {problem}" for problem in problems)
            forbidden = sorted(name for name in names if _forbidden_env(name))
            if forbidden:
                violations.append(f"{at}: 금지 env 이름 {forbidden}(실효 env — env · envFrom prefix + ConfigMap · Secret 키)")
    for document in _of_kind(docs, "ConfigMap"):
        keys = sorted(key for key in _dict(document.get("data")) if isinstance(key, str) and _env_key(key) == MULTIPROC_ENV)
        if keys:
            violations.append(f"{_ref(document)}: data 키 {keys} — {MULTIPROC_ENV} 금지(relay 지표 초기화 실패 · envFrom 공유)")
    for document in _of_kind(docs, "ExternalSecret"):
        if _name(document) != ENV_SECRET:
            continue
        keys = sorted(key for key in _external_secret_keys(document) if _env_key(key) == MULTIPROC_ENV)
        if keys:
            violations.append(f"{_ref(document)}: Secret 키 {keys} — {MULTIPROC_ENV} 금지(<pod>-env는 relay도 받는다)")
    return violations


def check_external_secrets(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-21(T072 · gitops validate 3.0 · 3.1 · 3.7의 거울 + 계약 공통 규칙) — 모든 ExternalSecret: apiVersion
    external-secrets.io/v1 · secretStoreRef ClusterSecretStore vault-dev · data[].remoteRef.key = dev/[a-z0-9_./-]+(base =
    dev 값 · Workers 전용 (dev|prod)/(access|web)/ 금지) · property 있음 · sourceRef 없음 · refreshInterval 5m ·
    refreshPolicy Periodic · target.name = 이름 · creationPolicy Owner · template.engineVersion v2 · mergePolicy 없음 또는
    Replace · dataFrom · templateFrom 없음.
    T072 r2(E2 · A-2): data[] ≥ 1 · template.data 값의 {{ .x }} 참조 ⊆ data[].secretKey · 순번(D20 표 — overlay 인덱스 패치의
    인터페이스): <pod>-env data[0..7] = (secretKey, key, property) 표 그대로 · <pod>-migrate data[0, 1] = owner username ·
    password. 표 뒤에 덧붙인 항목은 허용한다."""
    secrets = _of_kind(docs, "ExternalSecret")
    if not secrets:
        return ["ExternalSecret 없음 — 검사 대상 없음"]
    violations: list[str] = []
    for document in secrets:
        where = _ref(document)
        if document.get("apiVersion") != ESO_API_VERSION:
            violations.append(f"{where}: apiVersion = {document.get('apiVersion')!r}(기대 {ESO_API_VERSION!r})")
        spec = _dict(document.get("spec"))
        store = _dict(spec.get("secretStoreRef"))
        if store.get("kind") != SECRET_STORE_KIND:
            violations.append(f"{where}: secretStoreRef.kind = {store.get('kind')!r}(기대 {SECRET_STORE_KIND!r})")
        if store.get("name") != SECRET_STORE_NAME:
            violations.append(f"{where}: secretStoreRef.name = {store.get('name')!r}(기대 {SECRET_STORE_NAME!r} — base = dev)")
        if duration_seconds(spec.get("refreshInterval")) != REFRESH_INTERVAL_SECONDS:
            violations.append(f"{where}: refreshInterval = {spec.get('refreshInterval')!r}(기대 5m)")
        if spec.get("refreshPolicy") != REFRESH_POLICY:
            violations.append(f"{where}: refreshPolicy = {spec.get('refreshPolicy')!r}(기대 {REFRESH_POLICY!r})")
        if spec.get("dataFrom"):
            violations.append(f"{where}: dataFrom이 있다(키를 data[]로만 연다 — 경로 lint 우회 금지)")
        target = _dict(spec.get("target"))
        if target.get("name") != _name(document):
            violations.append(f"{where}: target.name = {target.get('name')!r}(기대 ES 이름 {_name(document)!r})")
        if target.get("creationPolicy") != CREATION_POLICY:
            violations.append(f"{where}: target.creationPolicy = {target.get('creationPolicy')!r}(기대 {CREATION_POLICY!r})")
        template = target.get("template")
        if not isinstance(template, dict):
            violations.append(f"{where}: target.template 없음(engineVersion {TEMPLATE_ENGINE_VERSION} 템플릿으로 값을 조립한다)")
        else:
            if template.get("engineVersion") != TEMPLATE_ENGINE_VERSION:
                violations.append(
                    f"{where}: template.engineVersion = {template.get('engineVersion')!r}(기대 {TEMPLATE_ENGINE_VERSION!r})"
                )
            if template.get("mergePolicy", TEMPLATE_MERGE_POLICY) != TEMPLATE_MERGE_POLICY:
                violations.append(
                    f"{where}: template.mergePolicy = {template.get('mergePolicy')!r}(기대 없음 또는 {TEMPLATE_MERGE_POLICY!r})"
                )
            if template.get("templateFrom"):
                violations.append(f"{where}: template.templateFrom이 있다(template.data만)")
        data = _list(spec.get("data"))
        if not data:
            violations.append(f"{where}: data[]가 비었다(키는 data[]로만 연다 — 빈 Secret 또는 템플릿 오류)")
        secret_keys = {key for key in (_dict(item).get("secretKey") for item in data) if isinstance(key, str)}
        if isinstance(template, dict):
            for key, value in _dict(template.get("data")).items():
                unknown = sorted(_template_refs(value) - secret_keys) if isinstance(value, str) else []
                if unknown:
                    violations.append(f"{where}: template.data[{key!r}]가 data[]에 없는 키 {unknown}를 참조한다")
        expected_order = {ENV_SECRET: ENV_SECRET_DATA, MIGRATE_SECRET: MIGRATE_SECRET_DATA}.get(_name(document))
        if expected_order is not None:
            if len(data) < len(expected_order):
                violations.append(f"{where}: data[] {len(data)}개(기대 ≥ {len(expected_order)} — 순번 고정 표 · D20)")
            for index, expected in enumerate(expected_order[: len(data)]):
                entry = _dict(data[index])
                remote = _dict(entry.get("remoteRef"))
                actual = (entry.get("secretKey"), remote.get("key"), remote.get("property"))
                if actual != expected:
                    violations.append(
                        f"{where} data[{index}]: (secretKey, key, property) = {actual}(기대 {expected} — 순번 고정 · overlay 인덱스 패치 · D20)"
                    )
        for index, item in enumerate(data):
            entry = _dict(item)
            remote = _dict(entry.get("remoteRef"))
            key = remote.get("key")
            at = f"{where} data[{index}]"
            if not isinstance(key, str) or _REMOTE_KEY_RE.fullmatch(key) is None:
                violations.append(f"{at}: remoteRef.key = {key!r}(기대 dev/[a-z0-9_./-]+ — base = dev 값)")
            elif _WORKERS_KEY_RE.match(key):
                violations.append(f"{at}: remoteRef.key = {key!r}는 Workers 전용 경로((dev|prod)/(access|web)/ — pod 반입 금지)")
            prop = remote.get("property")
            if not isinstance(prop, str) or not prop:
                violations.append(f"{at}: remoteRef.property = {prop!r}(기대 비지 않은 문자열)")
            if "sourceRef" in entry:
                violations.append(f"{at}: sourceRef가 있다(항목별 store 우회 금지)")
    return violations


def check_hook_order(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-22(T072 · D20 · ㉑ · G5) — 첫 배포 순서: <pod>-migrate ES = Argo PreSync hook · hook-delete-policy
    BeforeHookCreation · sync-wave < migrate Job의 sync-wave(없으면 0) / migrate Job의 컨테이너(initContainers 포함)와 볼륨은
    ConfigMap을 참조하지 않는다(Sync 단계 리소스라 PreSync 때 없다) / <pod>-env ES와 모든 ConfigMap은 hook이 아니고
    sync-wave < 0(Deployment보다 먼저). Secret 참조 분리는 check_env_split, Job hook 어노테이션은 identification 몫이다."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(relay=False, celery=False, cronjob=False))
    secrets = {_name(document): document for document in _of_kind(docs, "ExternalSecret")}
    migrate_secret = secrets.get(MIGRATE_SECRET)
    if migrate_secret is None:
        violations.append(f"ExternalSecret/{MIGRATE_SECRET} 없음 — hook 순서 검사 대상 없음")
    else:
        where = _ref(migrate_secret)
        notes = _annotations(migrate_secret)
        if notes.get(HOOK_ANNOTATION) != HOOK_VALUE:
            violations.append(f"{where}: 어노테이션 {HOOK_ANNOTATION} = {notes.get(HOOK_ANNOTATION)!r}(기대 {HOOK_VALUE!r})")
        policy = notes.get(HOOK_DELETE_POLICY_ANNOTATION)
        policies = {item.strip() for item in policy.split(",")} if isinstance(policy, str) else set()
        if policies != {HOOK_DELETE_POLICY}:
            violations.append(
                f"{where}: 어노테이션 {HOOK_DELETE_POLICY_ANNOTATION} = {policy!r}(기대 {HOOK_DELETE_POLICY!r})"
            )
        secret_wave = _sync_wave(migrate_secret)
        if secret_wave is None:
            violations.append(f"{where}: sync-wave {notes.get(SYNC_WAVE_ANNOTATION)!r}를 정수로 읽지 못한다")
        if workloads.job is not None:
            job_wave = _sync_wave(workloads.job)
            if job_wave is None:
                raw = _annotations(workloads.job).get(SYNC_WAVE_ANNOTATION)
                violations.append(f"{_ref(workloads.job)}: sync-wave {raw!r}를 정수로 읽지 못한다")
            elif secret_wave is not None and not secret_wave < job_wave:
                violations.append(
                    f"{where}: sync-wave {secret_wave}가 {_ref(workloads.job)}의 {job_wave}보다 앞이 아니다(Secret이 먼저 생겨야 한다)"
                )
    if workloads.job is not None:
        spec = _pod_spec(workloads.job)
        for container in _all_containers(spec):
            refs = _configmap_refs(container)
            if refs:
                violations.append(f"{_where(workloads.job, container)}: ConfigMap {sorted(refs)} 참조(PreSync Job은 ConfigMap 없이 돈다)")
        for item in _list(spec.get("volumes")):
            volume = _dict(item)
            names = _volume_configmap_names(volume)
            if names:
                violations.append(f"{_ref(workloads.job)}: 볼륨 {volume.get('name')!r}가 ConfigMap {sorted(names)}을 담는다")
    sync_phase = _of_kind(docs, "ConfigMap")
    env_secret = secrets.get(ENV_SECRET)
    if env_secret is None:
        violations.append(f"ExternalSecret/{ENV_SECRET} 없음 — hook 순서 검사 대상 없음")
    else:
        sync_phase = [env_secret, *sync_phase]
    for document in sync_phase:
        where = _ref(document)
        notes = _annotations(document)
        if HOOK_ANNOTATION in notes:
            violations.append(f"{where}: hook 어노테이션 {notes.get(HOOK_ANNOTATION)!r}가 있다(일반 리소스여야 한다)")
        wave = _sync_wave(document)
        if wave is None or wave >= 0:
            violations.append(f"{where}: sync-wave = {notes.get(SYNC_WAVE_ANNOTATION)!r}(기대 < 0 — Deployment보다 먼저)")
    return violations


def check_images(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-23(T072 · D20 · ⑳) — 모든 워크로드 문서(Deployment · Job · CronJob 등)의 모든 컨테이너(initContainers 포함)
    image가 정확히 ghcr.io/joshua92y/<pod>다(태그 · digest 없음 — overlay images가 이름까지 같은 항목으로 정한다).
    어떤 렌더 문서에도 metadata.namespace가 없다(base kustomization의 namespace가 렌더에 남기는 흔적). base
    kustomization.yaml의 images · namespace · commonLabels 키 자체는 렌더로 볼 수 없어 트리 쪽 정적 검사가 본다."""
    violations: list[str] = []
    workloads = [document for document in docs if document.get("kind") in WORKLOAD_KINDS]
    if not workloads:
        violations.append("워크로드 문서 없음 — 이미지 검사 대상 없음")
    for document in workloads:
        for container in _all_containers(_pod_spec(document)):
            image = container.get("image")
            if image != IMAGE:
                violations.append(f"{_where(document, container)}: image = {image!r}(기대 {IMAGE!r} — 태그 · digest는 overlay가 정한다)")
    for document in docs:
        namespace = _dict(document.get("metadata")).get("namespace")
        if namespace is not None:
            violations.append(f"{_ref(document)}: metadata.namespace = {namespace!r}(base에는 namespace가 없다 — overlay가 정한다)")
    return violations


def check_cronjob(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-24(T072 · D15 · 계약 §기본 테스트 6) — 기본 모드(has_celery=True): CronJob이 없다(dead outbox purge는 celery beat가
    맡는다). 변형 모드: 식별된 CronJob이 이름 <pod>-outbox-purge · schedule 일 1회(<분> <시> * * *) · concurrencyPolicy
    Forbid · timeZone은 있으면 Etc/UTC 또는 UTC · suspend 없음 또는 false(T072 r2 E6) · 실행 컨테이너 정확히 하나 · 그
    command + args = python manage.py outbox_purge. CronJob 개수는 identification(gen-8) 몫이다."""
    if has_celery:
        return [
            f"{_ref(document)}: 기본 렌더(has_celery=true)에 CronJob이 있다 — dead outbox purge는 celery beat가 맡는다"
            for document in _of_kind(docs, "CronJob")
        ]
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    cronjob = workloads.cronjob
    if cronjob is None:
        return ["CronJob 식별 안 됨(has_celery=false) — 검사 대상 없음"]
    where = _ref(cronjob)
    if _name(cronjob) != CRONJOB_NAME:
        violations.append(f"{where}: 이름 = {_name(cronjob)!r}(기대 {CRONJOB_NAME!r})")
    spec = _dict(cronjob.get("spec"))
    schedule = spec.get("schedule")
    match = _CRON_SCHEDULE_RE.fullmatch(schedule) if isinstance(schedule, str) else None
    if match is None or int(match.group(1)) > 59 or int(match.group(2)) > 23:
        violations.append(f"{where}: schedule = {schedule!r}(기대 일 1회 '<분> <시> * * *')")
    if spec.get("concurrencyPolicy") != CRON_CONCURRENCY_POLICY:
        violations.append(f"{where}: concurrencyPolicy = {spec.get('concurrencyPolicy')!r}(기대 {CRON_CONCURRENCY_POLICY!r})")
    if "timeZone" in spec and spec.get("timeZone") not in CRON_TIME_ZONES:
        violations.append(f"{where}: timeZone = {spec.get('timeZone')!r}(있으면 {sorted(CRON_TIME_ZONES)})")
    if spec.get("suspend", False) is not False:
        violations.append(f"{where}: suspend = {spec.get('suspend')!r}(기대 없음 또는 false — 일 1회 purge가 조용히 멈춘다)")
    executing = _all_containers(_pod_spec(cronjob))
    if len(executing) != 1:
        violations.append(f"{where}: 실행 컨테이너 {len(executing)}개 {[item.get('name') for item in executing]}(기대 1)")
    for container in executing:
        command = _command(container)
        if command != list(PURGE_COMMAND):
            violations.append(f"{_where(cronjob, container)}: command + args = {command}(기대 {list(PURGE_COMMAND)})")
    return violations


def _mounts_dir(container: dict[str, Any], volumes: set[Any], path: str) -> bool:
    """volumes 가운데 하나를 path 디렉터리로(subPath 없이 · readOnly) 마운트하는가."""
    for item in _list(container.get("volumeMounts")):
        mount = _dict(item)
        if (
            mount.get("name") in volumes
            and _normalize_path(mount.get("mountPath")) == path
            and not mount.get("subPath")
            and mount.get("readOnly") is True
        ):
            return True
    return False


@dataclass(frozen=True)
class _RuntimeContainer:
    """런타임 프로필 컨테이너 하나(web pod · celery · CronJob — initContainers 포함) — 다른 검사가 이미 판정하는 참조
    표시: configmap_owned = check_configmap(gen-16)이 ConfigMap 참조를 보는 컨테이너(web · celery · CronJob), env_owned =
    check_env_split(gen-10)이 <pod>-env 참조를 보는 컨테이너(web · relay · celery · CronJob)."""

    document: Doc
    container: dict[str, Any]
    configmap_owned: bool
    env_owned: bool


def _runtime_containers(workloads: Workloads) -> list[_RuntimeContainer]:
    found: list[_RuntimeContainer] = []
    for document in (workloads.web_deploy, workloads.celery_deploy, workloads.cronjob):
        if document is None:
            continue
        spec = _pod_spec(document)
        found.extend(_RuntimeContainer(document, item, False, False) for item in _init_containers(spec))
        for item in _containers(spec):
            if document is workloads.web_deploy:
                found.append(_RuntimeContainer(document, item, item is workloads.web, item is workloads.web or item is workloads.relay))
            else:
                found.append(_RuntimeContainer(document, item, True, True))
    return found


def _env_from_refs(container: dict[str, Any], ref_key: str) -> set[Any]:
    """envFrom[]에서 ref_key(configMapRef · secretRef)로 참조한 이름(prefix와 무관)."""
    entries = [_dict(item) for item in _list(container.get("envFrom"))]
    return {_dict(entry.get(ref_key)).get("name") for entry in entries if ref_key in entry}


def _runtime_env_names(container: dict[str, Any], sources: _EnvSources) -> set[str]:
    """런타임 컨테이너의 실효 env 이름(envFrom prefix 포함 — _effective_env) ∪ 정본 원천(ConfigMap <pod>-config · Secret
    <pod>-env) 가운데 컨테이너가 envFrom으로 참조하지 않는 원천의 키(T072 r3 F1 · r2 A-1). 참조가 빠진 원천은 참조 규칙
    (configmap · env_split · 이 검사의 envFrom 규칙)이 보므로 필수 이름 규칙은 그 원천의 내용으로 채운다. envFrom으로 참조한
    원천은 _effective_env가 prefix까지 계산한 이름만 센다 — prefix X_는 ENV를 X_ENV로 바꿔 필수 이름이 빠진다."""
    names, _ = _effective_env(container, sources)
    if CONFIG_MAP not in _env_from_refs(container, "configMapRef"):
        names |= sources.configmaps.get(CONFIG_MAP, set())
    if ENV_SECRET not in _env_from_refs(container, "secretRef"):
        names |= sources.secrets.get(ENV_SECRET, set())
    return names


def _migrate_env_names(container: dict[str, Any], sources: _EnvSources) -> set[str]:
    """migrate 컨테이너의 실효 env 이름 — env[] ∪ envFrom Secret 키(prefix 포함) ∪ 정본 <pod>-migrate 키(컨테이너가 envFrom으로
    참조하지 않을 때만 — T072 r3 F1: 참조하면 prefix가 붙은 이름만 센다). ConfigMap 참조(check_hook_order 몫)와 <pod>-env
    참조(check_env_split 몫)는 세지 않는다 — 그 참조 자체가 이미 위반이다."""
    names, _ = _effective_env(container, sources, configmaps=False, skip_secrets=frozenset({ENV_SECRET}))
    if MIGRATE_SECRET not in _env_from_refs(container, "secretRef"):
        names |= sources.secrets.get(MIGRATE_SECRET, set())
    return names


def _runtime_wiring_env(docs: list[Doc], workloads: Workloads) -> list[str]:
    """runtime_wiring의 env 배선(T072 r2 E1 · A-1 · D5 · X7) — 아래 「다른 검사가 판정하는 것」은 겹쳐 보고하지 않는다.
    - 런타임 컨테이너 envFrom: ConfigMap <pod>-config · secretRef <pod>-env가 있다. configmap_owned 컨테이너의 ConfigMap 참조는
      check_configmap이 통과할 때(키 5 ConfigMap을 참조할 때)만, env_owned 컨테이너의 secretRef는 <pod>-env 참조가 다른 꼴
      (secretKeyRef)로 있을 때만 본다 — 참조가 아예 없으면 그 검사들이 보고한다.
    - 런타임 컨테이너의 실효 env(envFrom으로 참조하지 않은 정본 원천의 키 포함 · 참조한 원천은 prefix가 붙은 이름 — T072 r3
      F1 · _runtime_env_names) ⊇ RUNTIME_REQUIRED_ENV. 미룸: POD_NAMESPACE(위 fieldRef 규칙) · 키 5(키 5 ConfigMap이 없으면
      check_configmap) · DATABASE_URL(<pod>-env ES에 그 키가 없으면 check_db_tls). JT_SETTINGS_PROFILE이 없다(정확한 이름 —
      런타임 프로필).
    - migrate Job 컨테이너: env에 JT_SETTINGS_PROFILE이 리터럴 value 'migrate'로 정확히 하나 · 실효 env(_migrate_env_names) ⊇
      MIGRATE_REQUIRED_ENV(미룸: JT_SETTINGS_PROFILE = 위 리터럴 규칙 · DATABASE_OWNER_URL = <pod>-migrate ES에 그 키가 없으면
      check_db_tls) · 런타임 전용 이름(DATABASE_URL · DRAGONFLY_URL · SECRET_KEY · KAFKA_* · AUTHENTIK_* — ASCII 대소문자
      무시)이 하나도 없다(X7)."""
    violations: list[str] = []
    sources = _env_sources(docs)
    complete = _complete_configmaps(docs)
    deferred_runtime = {POD_NAMESPACE_ENV}
    if not complete:
        deferred_runtime |= CONFIGMAP_KEYS
    if not _es_has_string_key(docs, ENV_SECRET, "DATABASE_URL"):
        deferred_runtime.add("DATABASE_URL")
    for runtime in _runtime_containers(workloads):
        container = runtime.container
        at = _where(runtime.document, container)
        config_refs = _env_from_refs(container, "configMapRef")
        secret_refs = _env_from_refs(container, "secretRef")
        if CONFIG_MAP not in config_refs and (not runtime.configmap_owned or config_refs & complete):
            violations.append(f"{at}: envFrom configMapRef {CONFIG_MAP} 없음(참조: {sorted(map(str, config_refs))})")
        if ENV_SECRET not in secret_refs and (not runtime.env_owned or ENV_SECRET in _secret_refs(container)):
            violations.append(f"{at}: envFrom secretRef {ENV_SECRET} 없음(참조: {sorted(map(str, secret_refs))})")
        names = _runtime_env_names(container, sources)
        missing = sorted(RUNTIME_REQUIRED_ENV - names - deferred_runtime)
        if missing:
            violations.append(f"{at}: 런타임 필수 설정 이름 {missing} 없음(실효 env — env · {CONFIG_MAP} · {ENV_SECRET} · D5)")
        if SETTINGS_PROFILE_ENV in names:
            violations.append(f"{at}: {SETTINGS_PROFILE_ENV}가 있다(런타임 프로필 — migrate Job만 둔다)")
    if workloads.job is None:
        return violations
    deferred_migrate = {SETTINGS_PROFILE_ENV}
    if not _es_has_string_key(docs, MIGRATE_SECRET, "DATABASE_OWNER_URL"):
        deferred_migrate.add("DATABASE_OWNER_URL")
    for container in _all_containers(_pod_spec(workloads.job)):
        at = _where(workloads.job, container)
        profiles = [_dict(item) for item in _list(container.get("env")) if _dict(item).get("name") == SETTINGS_PROFILE_ENV]
        literal = len(profiles) == 1 and profiles[0].get("value") == MIGRATE_PROFILE and "valueFrom" not in profiles[0]
        if not literal:
            violations.append(
                f"{at}: env {SETTINGS_PROFILE_ENV} = {profiles!r}(기대 리터럴 value {MIGRATE_PROFILE!r} 정확히 하나 — migrate 프로필)"
            )
        names = _migrate_env_names(container, sources)
        missing = sorted(MIGRATE_REQUIRED_ENV - names - deferred_migrate)
        if missing:
            violations.append(f"{at}: migrate 필수 설정 이름 {missing} 없음(실효 env — env · {MIGRATE_SECRET})")
        runtime_only = sorted(name for name in names if _runtime_only_env(name))
        if runtime_only:
            violations.append(f"{at}: 런타임 전용 이름 {runtime_only}이 있다(<pod>-migrate에 런타임 키를 더하지 않는다 — X7)")
    return violations


def check_runtime_wiring(docs: list[Doc], *, has_celery: bool = True) -> list[str]:
    """gen-36(T072 · X2 · X8 · C10) — 계약 행은 있는데 다른 검사가 보지 않던 배선:
    web pod initContainers = startup-check 하나 · command + args = python manage.py startup_check / web · relay가 secret
    jt-kafka-cluster-ca-cert 볼륨을 /etc/kafka에 readOnly로 마운트 / web containerPort 9100 / memory limits: web 512Mi ·
    relay 192Mi · celery 512Mi · migrate 512Mi · CronJob 512Mi · init requests 128Mi · limits 256Mi / 런타임 컨테이너 전부
    (web pod · celery · CronJob — initContainers 포함)에 env POD_NAMESPACE = fieldRef metadata.namespace · migrate Job
    컨테이너의 실효 env에는 POD_NAMESPACE가 없다 / ConfigMap data 값과 ES template.data 값에 줄바꿈 · 탭 · 앞뒤 공백이
    없다(블록 스칼라 |의 끝 줄바꿈).
    T072 r2(E1 · A-1): env 배선 셋 — 런타임 컨테이너 전부의 envFrom ConfigMap <pod>-config + secretRef <pod>-env · 런타임 필수
    설정 이름 · migrate 프로필(JT_SETTINGS_PROFILE 리터럴 · DATABASE_OWNER_URL · 런타임 전용 이름 없음) — _runtime_wiring_env.
    T072 ③ r2(M6 · 조각 ③ 리뷰 A-6): 명령 결속 — web 컨테이너는 command · args가 없거나(이미지 CMD) command + args가 정확히
    WEB_COMMAND(이미지 CMD 토큰 — --no-control-socket 포함) · relay command + args = RELAY_COMMAND · celery Deployment 컨테이너
    command + args = CELERY_COMMAND(D14 — --schedule /tmp/…). gen-33 Dockerfile CMD 정적 검사 · gen-34 스모크와 같은 상수다.
    다른 검사가 맡은 것(relay 9464 · initContainers의 pg-ca · /tmp · securityContext · requests · <pod>-migrate 참조 금지 ·
    키 5 ConfigMap 참조 · <pod>-env 참조 유무 · Job의 ConfigMap 참조 · CronJob 명령)은 다시 보지 않는다."""
    workloads, violations = _identified(docs, has_celery)
    if workloads is None:
        return violations
    violations.extend(workloads.missing())
    web_deploy = workloads.web_deploy
    web_spec = _pod_spec(web_deploy)
    inits = _init_containers(web_spec)
    init_names = [item.get("name") for item in inits]
    if init_names != [INIT_CONTAINER]:
        violations.append(f"{_ref(web_deploy)}: initContainers = {init_names}(기대 [{INIT_CONTAINER!r}] — 기동 check_rls)")
    for init in inits:
        if init.get("name") != INIT_CONTAINER:
            continue
        command = _command(init)
        if command != list(INIT_COMMAND):
            violations.append(f"{_where(web_deploy, init)}: command + args = {command}(기대 {list(INIT_COMMAND)})")
    web_command = _command(workloads.web)
    if web_command and web_command != list(WEB_COMMAND):
        violations.append(
            f"{_where(web_deploy, workloads.web)}: command + args = {web_command}(기대 없음(이미지 CMD) 또는 {list(WEB_COMMAND)} — "
            "gen-33 · gen-34가 시험한 명령 · README 「프로세스」)"
        )
    relay_command = _command(workloads.relay) if workloads.relay is not None else None
    if workloads.relay is not None and relay_command != list(RELAY_COMMAND):
        violations.append(
            f"{_where(web_deploy, workloads.relay)}: command + args = {relay_command}(기대 {list(RELAY_COMMAND)} — gen-34 스모크)"
        )
    if workloads.celery_deploy is not None:
        for container in _containers(_pod_spec(workloads.celery_deploy)):
            celery_command = _command(container)
            if celery_command != list(CELERY_COMMAND):
                violations.append(
                    f"{_where(workloads.celery_deploy, container)}: command + args = {celery_command}(기대 {list(CELERY_COMMAND)}"
                    " — D14 · gen-34 스모크)"
                )
    kafka_volumes = {
        _dict(item).get("name")
        for item in _list(web_spec.get("volumes"))
        if _dict(_dict(item).get("secret")).get("secretName") == KAFKA_CA_SECRET
    }
    if not kafka_volumes:
        violations.append(f"{_ref(web_deploy)}: secretName {KAFKA_CA_SECRET} 볼륨 없음(Kafka CA — web · relay)")
    for container in (workloads.web, workloads.relay):
        if container is not None and not _mounts_dir(container, kafka_volumes, KAFKA_CA_DIR):
            violations.append(
                f"{_where(web_deploy, container)}: {KAFKA_CA_SECRET} 볼륨을 {KAFKA_CA_DIR}에 readOnly로(subPath 없이) 마운트하지 않는다"
            )
    if WEB_METRICS_PORT not in _container_ports(workloads.web):
        violations.append(f"{_where(web_deploy, workloads.web)}: containerPort {WEB_METRICS_PORT} 없음(web 지표)")
    for role, document, container in _role_targets(workloads):
        expected = MEMORY_LIMITS[role]
        actual = _dict(_dict(container.get("resources")).get("limits")).get("memory")
        if memory_bytes(actual) != memory_bytes(expected):
            violations.append(f"{_where(document, container)}: limits.memory = {actual!r}(기대 {expected!r} — {role})")
    for init in inits:
        resources = _dict(init.get("resources"))
        for field, expected in (("requests", INIT_MEMORY_REQUEST), ("limits", INIT_MEMORY_LIMIT)):
            actual = _dict(resources.get(field)).get("memory")
            if memory_bytes(actual) != memory_bytes(expected):
                violations.append(f"{_where(web_deploy, init)}: {field}.memory = {actual!r}(기대 {expected!r} — initContainer)")
    for document in (web_deploy, workloads.celery_deploy, workloads.cronjob):
        if document is None:
            continue
        for container in _all_containers(_pod_spec(document)):
            paths = _field_ref_paths(container, POD_NAMESPACE_ENV)
            if paths != [POD_NAMESPACE_FIELD]:
                violations.append(
                    f"{_where(document, container)}: env {POD_NAMESPACE_ENV} fieldRef = {paths!r}(기대 [{POD_NAMESPACE_FIELD!r}] 하나)"
                )
    if workloads.job is not None:
        sources = _env_sources(docs)
        for container in _all_containers(_pod_spec(workloads.job)):
            names, _ = _effective_env(container, sources)
            if POD_NAMESPACE_ENV in names:
                violations.append(f"{_where(workloads.job, container)}: env {POD_NAMESPACE_ENV}가 있다(migrate 프로필 — 런타임 전용)")
    violations.extend(_runtime_wiring_env(docs, workloads))
    for document in _of_kind(docs, "ConfigMap"):
        for key, value in _dict(document.get("data")).items():
            problem = _value_problem(value) if isinstance(value, str) else None
            if problem is not None:
                violations.append(f"{_ref(document)}: data[{key!r}] 값에 {problem}")
    for document in _of_kind(docs, "ExternalSecret"):
        template = _dict(_dict(_dict(document.get("spec")).get("target")).get("template"))
        for key, value in _dict(template.get("data")).items():
            problem = _value_problem(value) if isinstance(value, str) else None
            if problem is not None:
                violations.append(f"{_ref(document)}: template.data[{key!r}] 값에 {problem}")
    return violations


CHECKS: dict[str, Callable[..., list[str]]] = {
    "identification": check_identification,
    "security_context": check_security_context,
    "env_split": check_env_split,
    "db_tls": check_db_tls,
    "probes": check_probes,
    "strategy_resources": check_strategy_resources,
    "migrate_sql": check_migrate_sql,
    "annotations": check_annotations,
    "configmap": check_configmap,
    "ingress": check_ingress,
    "pod_lifecycle": check_pod_lifecycle,
    "env_hygiene": check_env_hygiene,
    "external_secrets": check_external_secrets,
    "hook_order": check_hook_order,
    "images": check_images,
    "cronjob": check_cronjob,
    "runtime_wiring": check_runtime_wiring,
}


def run_checks(docs: list[Doc], *, has_celery: bool = True) -> dict[str, list[str]]:
    """CHECKS 전부를 같은 모드로 — {검사 이름: 위반 목록}."""
    return {name: check(docs, has_celery=has_celery) for name, check in CHECKS.items()}


# ==================== T072 마지막 라운드 N2(1) · N3 — 렌더 ≅ 골든(본보기) ====================
# 골든(fixtures/golden-render.yaml · golden-cronjob.yaml)은 템플릿 deploy/base 렌더의 본보기다(조각 ④ 리뷰 A-1 · A-2: 계약 검사(CHECKS)는
# D20 값 상당수 — Job 상한 · trimSuffix · ConfigMap dev 값 · 프로브 주기 · migrate 스크립트의 재시도 성질 — 을 보지 않아 그 변이가 생존했다).
# 본보기가 아닌 곳은 하나(relay의 pg-ca 마운트: 골든은 subPath 꼴 — render-26 · 27 변이의 대상 · 템플릿은 /etc/pg 디렉터리)이고, 그 하나를
# 템플릿 꼴로 바꾼 본보기(golden_exemplar)와 실제 렌더를 구조로 견준다(golden_differences — gen-38 · 문서 순서 무관). migrate Job 스크립트는
# 따로 바이트까지 견준다(migrate_script_differences — gen-14 · gen-31): 가짜 psycopg 시험(test_render_helpers.py)이 골든 스크립트를 실제로
# 돌리므로 그 시험이 템플릿 스크립트에도 걸린다. 이 검사는 CHECKS가 아니다(골든과의 거리라 계약 변이마다 걸린다 — 교차 판정 밖). D20 값을
# 바꾸려면 골든을 같은 변경에서 고친다(E7 「골든이 본보기」와 같은 원칙).

FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
GOLDEN_RENDER_FILE = FIXTURES_DIR / "golden-render.yaml"
GOLDEN_CRONJOB_FILE = FIXTURES_DIR / "golden-cronjob.yaml"
DEFAULT_RENDER = "default"
# 렌더 이름(기본 · 하네스 변형 tests/_layout.py VARIANTS) → (골든 파일, 본보기에서 뺄 ConfigMap 키)
GOLDEN_FOR_RENDER: dict[str, tuple[Path, tuple[str, ...]]] = {
    DEFAULT_RENDER: (GOLDEN_RENDER_FILE, ()),
    "no-celery": (GOLDEN_CRONJOB_FILE, ()),
    "no-admin": (GOLDEN_CRONJOB_FILE, ("FORCE_SCRIPT_NAME",)),
}
RELAY_CONTAINER = "relay"
MIGRATE_CONTAINER = "migrate"
# 골든의 「본보기 아님」 꼴(relay pg-ca subPath)과 그 자리의 템플릿 꼴(D20 — 모든 컨테이너가 /etc/pg 디렉터리)
GOLDEN_RELAY_PG_CA_MOUNT: dict[str, Any] = {"name": "pg-ca", "mountPath": PG_CA_FILE, "subPath": PG_CA_KEY, "readOnly": True}
EXEMPLAR_RELAY_PG_CA_MOUNT: dict[str, Any] = {"name": "pg-ca", "mountPath": PG_CA_DIR, "readOnly": True}
_VALUE_PREVIEW = 120


def golden_exemplar(golden: list[Doc]) -> tuple[list[Doc], list[str]]:
    """골든 문서들의 깊은 복사 + 예외 하나(Deployment relay 컨테이너의 pg-ca subPath 마운트 → 템플릿 꼴 /etc/pg 디렉터리) → (본보기, 문제).
    그 꼴의 마운트가 정확히 하나가 아니면 문제다 — 예외가 조용히 넓어지거나(둘 이상) 공허해지지(없음) 않게."""
    exemplar = copy.deepcopy(golden)
    found: list[tuple[list[Any], int]] = []
    for document in _of_kind(exemplar, "Deployment"):
        for container in _containers(_pod_spec(document)):
            if container.get("name") != RELAY_CONTAINER:
                continue
            mounts = _list(container.get("volumeMounts"))
            found.extend((mounts, index) for index, mount in enumerate(mounts) if mount == GOLDEN_RELAY_PG_CA_MOUNT)
    if len(found) != 1:
        return exemplar, [
            f"골든의 relay pg-ca subPath 마운트(본보기 아님 — 예외 하나 · {GOLDEN_RELAY_PG_CA_MOUNT})가 {len(found)}개다(기대 1)"
        ]
    mounts, index = found[0]
    mounts[index] = dict(EXEMPLAR_RELAY_PG_CA_MOUNT)
    return exemplar, []


def drop_configmap_keys(docs: list[Doc], keys: Iterable[str]) -> tuple[list[Doc], list[str]]:
    """ConfigMap <pod>-config의 data에서 keys를 뺀 깊은 복사 → (문서들, 문제 — 그 ConfigMap이 정확히 하나가 아니거나 키가 없으면)."""
    result = copy.deepcopy(docs)
    wanted = list(keys)
    if not wanted:
        return result, []
    configmaps = [document for document in _of_kind(result, "ConfigMap") if _name(document) == CONFIG_MAP]
    if len(configmaps) != 1:
        return result, [f"ConfigMap {CONFIG_MAP}이 {len(configmaps)}개다(기대 1 — 키 {wanted}를 뺄 수 없다)"]
    data = _dict(configmaps[0].get("data"))
    missing = [key for key in wanted if key not in data]
    for key in wanted:
        data.pop(key, None)
    return result, [f"ConfigMap {CONFIG_MAP}에 뺄 키 {missing}가 없다"] if missing else []


def golden_for(render: str) -> tuple[list[Doc], list[str]]:
    """렌더 이름(default · no-celery · no-admin)의 본보기 → (문서들, 문제) — default = golden-render.yaml · no-celery = golden-cronjob.yaml ·
    no-admin = golden-cronjob.yaml − ConfigMap FORCE_SCRIPT_NAME. 셋 다 relay pg-ca 마운트 예외 하나를 템플릿 꼴로 바꾼다."""
    if render not in GOLDEN_FOR_RENDER:
        return [], [f"렌더 이름 {render!r}의 골든이 없다(기대 {sorted(GOLDEN_FOR_RENDER)})"]
    path, dropped = GOLDEN_FOR_RENDER[render]
    exemplar, problems = golden_exemplar(load_docs(path.read_text(encoding="utf-8")))
    exemplar, more = drop_configmap_keys(exemplar, dropped)
    return exemplar, problems + more


def _preview(value: Any) -> str:
    text = repr(value)
    return text if len(text) <= _VALUE_PREVIEW else text[:_VALUE_PREVIEW] + "…"


def _first_line_difference(left: str, right: str) -> str:
    """두 여러 줄 문자열의 첫 차이 줄 — '줄 N: 렌더 … · 골든 …'(줄 수가 다르면 그것도)."""
    left_lines, right_lines = left.split("\n"), right.split("\n")
    for number, (one, other) in enumerate(zip(left_lines, right_lines), start=1):
        if one != other:
            return f"첫 차이 줄 {number}: 렌더 {_preview(one)} · 골든 {_preview(other)}"
    return f"줄 수 렌더 {len(left_lines)} · 골든 {len(right_lines)}(앞 줄은 같다)"


def _item_label(rendered: Any, golden: Any, index: int) -> str:
    """목록 원소의 경로 조각 — 두 쪽이 같은 name을 가진 매핑이면 [이름], 아니면 [자리]."""
    names = [item.get("name") if isinstance(item, dict) else None for item in (rendered, golden)]
    return f"[{names[0]}]" if isinstance(names[0], str) and names[0] == names[1] else f"[{index}]"


def _structure_differences(path: str, rendered: Any, golden: Any, out: list[str]) -> None:
    if isinstance(rendered, dict) and isinstance(golden, dict):
        for key in sorted(set(rendered) | set(golden), key=str):
            child = f"{path}.{key}" if path else str(key)
            if key not in golden:
                out.append(f"{child}: 렌더에만 있다({_preview(rendered[key])})")
            elif key not in rendered:
                out.append(f"{child}: 골든에만 있다({_preview(golden[key])})")
            else:
                _structure_differences(child, rendered[key], golden[key], out)
        return
    if isinstance(rendered, list) and isinstance(golden, list):
        for index, (one, other) in enumerate(zip(rendered, golden)):
            _structure_differences(path + _item_label(one, other, index), one, other, out)
        for index in range(len(golden), len(rendered)):
            out.append(f"{path}[{index}]: 렌더에만 있다({_preview(rendered[index])})")
        for index in range(len(rendered), len(golden)):
            out.append(f"{path}[{index}]: 골든에만 있다({_preview(golden[index])})")
        return
    if type(rendered) is type(golden) and rendered == golden:
        return
    if isinstance(rendered, str) and isinstance(golden, str) and ("\n" in rendered or "\n" in golden):
        out.append(f"{path}: 여러 줄 문자열이 다르다 — {_first_line_difference(rendered, golden)}")
        return
    out.append(f"{path}: 렌더 {_preview(rendered)} · 골든 {_preview(golden)}")


def golden_differences(rendered: list[Doc], exemplar: list[Doc]) -> list[str]:
    """렌더 ≅ 본보기(T072 마지막 라운드 N3 — gen-38) — 문서를 (kind, metadata.name)으로 짝짓고(순서 무관) 구조를 견준다: 짝이 없는 문서 ·
    한쪽에만 있는 키 · 값(타입 포함 — 1과 "1"은 다르다)이 다른 곳을 경로별로 한 줄씩. 목록은 자리대로 견준다(같은 name을 가진 원소는 경로에
    [이름]). 같은 (kind, 이름)이 한쪽에 둘 이상이면 그것도 차이다."""
    def index(docs: list[Doc]) -> dict[str, list[Doc]]:
        grouped: dict[str, list[Doc]] = {}
        for document in docs:
            grouped.setdefault(_ref(document), []).append(document)
        return grouped

    left, right = index(rendered), index(exemplar)
    out: list[str] = []
    for ref in sorted(set(left) | set(right)):
        ones, others = left.get(ref, []), right.get(ref, [])
        if len(ones) != 1 or len(others) != 1:
            out.append(f"{ref}: 문서 수 렌더 {len(ones)} · 골든 {len(others)}(기대 1 · 1)")
            continue
        found: list[str] = []
        _structure_differences("", ones[0], others[0], found)
        out.extend(f"{ref} {item}" for item in found)
    return out


def migrate_script(docs: list[Doc]) -> str | None:
    """Job의 migrate 컨테이너 command가 ["python", "-c", <스크립트>]이면 그 스크립트(Job · 컨테이너가 정확히 하나일 때만) — 아니면 None."""
    jobs = _of_kind(docs, "Job")
    if len(jobs) != 1:
        return None
    containers = [item for item in _containers(_pod_spec(jobs[0])) if item.get("name") == MIGRATE_CONTAINER]
    if len(containers) != 1:
        return None
    command = _list(containers[0].get("command"))
    if len(command) != 3 or command[:2] != ["python", "-c"] or not isinstance(command[2], str) or _list(containers[0].get("args")):
        return None
    return command[2]


def migrate_script_differences(rendered: list[Doc], golden: list[Doc]) -> list[str]:
    """렌더한 migrate Job 스크립트(command[2]) = 골든 스크립트(UTF-8 바이트까지 — T072 마지막 라운드 N2(1) · 조각 ④ 리뷰 A-1: 재시도 대상 ·
    마감 범위 · 재시도 줄 stdout · 종료 코드 전달 · 기본 마감 같은 성질은 가짜 psycopg 시험이 골든에서 굳힌다 — 이 결속으로 템플릿에도 걸린다)."""
    ours, theirs = migrate_script(rendered), migrate_script(golden)
    if ours is None:
        return [f"렌더에서 migrate 스크립트(Job · 컨테이너 {MIGRATE_CONTAINER} · command = python -c <스크립트> · args 없음)를 찾지 못했다"]
    if theirs is None:
        return [f"골든에서 migrate 스크립트(Job · 컨테이너 {MIGRATE_CONTAINER} · command = python -c <스크립트>)를 찾지 못했다"]
    if ours.encode("utf-8") == theirs.encode("utf-8"):
        return []
    return [f"migrate 스크립트가 골든(본보기 · E7)과 다르다 — {_first_line_difference(ours, theirs)}(골든 · 가짜 psycopg 시험을 같은 변경에서 고친다)"]
