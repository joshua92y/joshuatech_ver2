"""렌더 검사 함수(T065) — kustomize build deploy/base 출력(문서 목록)에 계약을 단언한다.

정본: specs/003-platform-foundation/contracts/pod-template.md §런타임 계약 · §기본 테스트 6.
- 검사 함수는 전부 list[str]을 돌려준다 — 위반 설명 "<kind>/<name> <컨테이너>: <무엇이 어떻게>". 빈 목록 = 통과.
  함수 안에서 assert를 쓰지 않는다(위반을 모아 돌려준다). 실제 렌더(test_generate.py gen-8..17)와 합성 골든 ·
  변이(test_render_helpers.py)가 같은 함수를 쓴다.
- 워크로드 식별(identify_workloads)은 가능한 만큼 식별하고(best effort) 어긋남을 위반으로 모은다. 식별 위반은
  check_identification(gen-8)만 보고하고, 나머지 검사는 식별된 워크로드로 판정한다 — 변이 하나가 맡은 검사 하나에서만
  드러나게. 식별되지 않은 워크로드는 그 검사의 "검사 대상 없음" 위반이 된다(조용히 통과하지 않는다).
"""

from __future__ import annotations

import re
from collections.abc import Callable
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

import yaml

POD = "sample-pod"
ENV_SECRET = f"{POD}-env"
MIGRATE_SECRET = f"{POD}-migrate"
PG_CA_SECRET = "pg-main-ca"
PG_CA_DIR = "/etc/pg"
PG_CA_FILE = "/etc/pg/ca.crt"
PG_CA_KEY = "ca.crt"
DB_URL_KEYS = {ENV_SECRET: "DATABASE_URL", MIGRATE_SECRET: "DATABASE_OWNER_URL"}
DB_TLS_PARTS = ("sslmode=verify-full", "sslrootcert=/etc/pg/ca.crt")
OWNER_URL_KEY = "DATABASE_OWNER_URL"

WEB_PORT = 8000
RELAY_METRICS_PORT = 9464
WEB_PROBES = {"livenessProbe": "/healthz", "readinessProbe": "/ready", "startupProbe": "/ready"}
STARTUP_FAILURE_THRESHOLD = 30
STARTUP_PERIOD_SECONDS = 5
HEALTH_PATH = "/health"
PROBE_KINDS = ("livenessProbe", "readinessProbe", "startupProbe")

MAX_SURGE = 1
MAX_UNAVAILABLE = 0
AFFINITY_KEY = "role"
AFFINITY_OPERATOR = "In"
AFFINITY_VALUE = "platform"
MEMORY_REQUESTS = {"web": "256Mi", "relay": "96Mi", "celery": "192Mi", "migrate": "256Mi"}

HOOK_ANNOTATION = "argocd.argoproj.io/hook"
HOOK_VALUE = "PreSync"
RELOADER_ANNOTATION = "reloader.stakater.com/auto"
SCRAPE_ANNOTATION = "k8s.grafana.com/scrape"

CONFIGMAP_KEYS = frozenset({"ACCESS_AUD_M2M", "ACCESS_AUD_ADMIN", "ACCESS_EXPECTED_CN", "ADMIN_HOST", "ALLOWED_HOSTS"})
INGRESS_PATHS = frozenset({"/api", "/health", "/session", "/sessions", "/tenants"})
INGRESS_FORBIDDEN_PREFIXES = ("/healthz", "/ready", "/webhooks")

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


def _name(document: Doc) -> str:
    name = _dict(document.get("metadata")).get("name")
    return name if isinstance(name, str) else "?"


def _ref(document: Doc) -> str:
    return f"{document.get('kind')}/{_name(document)}"


def _where(document: Doc, container: dict[str, Any]) -> str:
    return f"{_ref(document)} {container.get('name', '?')}"


def _of_kind(docs: list[Doc], kind: str) -> list[Doc]:
    return [document for document in docs if document.get("kind") == kind]


def _pod_spec(document: Doc) -> dict[str, Any]:
    return _dict(_dict(_dict(document.get("spec")).get("template")).get("spec"))


def _containers(spec: dict[str, Any]) -> list[dict[str, Any]]:
    return [item for item in _list(spec.get("containers")) if isinstance(item, dict)]


def _all_containers(spec: dict[str, Any]) -> list[dict[str, Any]]:
    init = [item for item in _list(spec.get("initContainers")) if isinstance(item, dict)]
    return init + _containers(spec)


def _first_executing(spec: dict[str, Any]) -> dict[str, Any] | None:
    executing = _all_containers(spec)
    return executing[0] if executing else None


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


# ---------- 워크로드 식별 ----------


@dataclass(frozen=True)
class Workloads:
    """식별된 워크로드 — web Deployment(web + relay 컨테이너) · celery Deployment · migrate Job."""

    web_deploy: Doc
    web: dict[str, Any]
    relay: dict[str, Any] | None
    celery_deploy: Doc | None
    job: Doc | None

    def pod_docs(self) -> list[Doc]:
        return [document for document in (self.web_deploy, self.celery_deploy, self.job) if document is not None]

    def missing(self, *, relay: bool = True, celery: bool = True, job: bool = True) -> list[str]:
        """검사가 요구하는 부분 중 식별되지 않은 것 — 검사 함수가 "검사 대상 없음" 위반으로 쓴다."""
        problems: list[str] = []
        if relay and self.relay is None:
            problems.append(f"relay 컨테이너 식별 안 됨(web pod에 containerPort {RELAY_METRICS_PORT} 없음) — 검사 대상 없음")
        if celery and self.celery_deploy is None:
            problems.append("celery Deployment 식별 안 됨 — 검사 대상 없음")
        if job and self.job is None:
            problems.append("migrate Job 식별 안 됨 — 검사 대상 없음")
        return problems


@dataclass(frozen=True)
class Identification:
    workloads: Workloads | None  # None = web Deployment조차 찾지 못함
    violations: list[str]


def identify_workloads(docs: list[Doc]) -> Identification:
    """web = containerPort 8000 컨테이너를 가진 Deployment · relay = 그 pod의 containerPort 9464 컨테이너 ·
    celery = 나머지 Deployment · migrate = Job(Argo PreSync hook). 그 밖에 Service · ConfigMap · Ingress ≥ 1 ·
    ExternalSecret <pod>-env · <pod>-migrate가 있어야 한다."""
    violations: list[str] = []
    deployments = _of_kind(docs, "Deployment")
    if len(deployments) != 2:
        names = [_name(document) for document in deployments]
        violations.append(f"Deployment {len(deployments)}개(기대 2: web+relay · celery) — {names}")

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
        if not others:
            violations.append("celery Deployment 없음(web 외의 Deployment가 없다)")
        elif len(others) > 1:
            names = [_name(document) for document in others]
            violations.append(f"celery 후보 Deployment {len(others)}개 {names} — 첫 것을 celery로 본다")
        workloads = Workloads(
            web_deploy=web_deploy,
            web=web,
            relay=relays[0] if relays else None,
            celery_deploy=others[0] if others else None,
            job=None,
        )

    jobs = _of_kind(docs, "Job")
    if len(jobs) != 1:
        violations.append(f"Job {len(jobs)}개(기대 1: migrate) — {[_name(document) for document in jobs]}")
    job = jobs[0] if jobs else None
    if job is not None:
        hook = _dict(_dict(job.get("metadata")).get("annotations")).get(HOOK_ANNOTATION)
        if hook != HOOK_VALUE:
            violations.append(f"{_ref(job)}: 어노테이션 {HOOK_ANNOTATION} = {hook!r}(기대 {HOOK_VALUE!r})")
    if workloads is not None:
        workloads = Workloads(workloads.web_deploy, workloads.web, workloads.relay, workloads.celery_deploy, job)

    for kind in ("Service", "ConfigMap", "Ingress"):
        if not _of_kind(docs, kind):
            violations.append(f"{kind} 없음(기대 ≥ 1)")
    secret_names = {_name(document) for document in _of_kind(docs, "ExternalSecret")}
    missing = sorted({ENV_SECRET, MIGRATE_SECRET} - secret_names)
    if missing:
        violations.append(f"ExternalSecret 없음: {missing}(있는 것: {sorted(secret_names)})")
    return Identification(workloads, violations)


def _identified(docs: list[Doc]) -> tuple[Workloads | None, list[str]]:
    workloads = identify_workloads(docs).workloads
    if workloads is None:
        return None, ["워크로드를 식별하지 못해 검사할 수 없다 — check_identification(gen-8)의 위반을 먼저 본다"]
    return workloads, []


def check_identification(docs: list[Doc]) -> list[str]:
    """gen-8 — 워크로드 · 부속 객체 식별."""
    return identify_workloads(docs).violations


# ---------- 검사 ----------


def check_security_context(docs: list[Doc]) -> list[str]:
    """gen-9 — 워크로드 3의 pod: automountServiceAccountToken false · runAsNonRoot · seccomp RuntimeDefault.
    모든 컨테이너(initContainers 포함): allowPrivilegeEscalation false · capabilities.drop [ALL] ·
    readOnlyRootFilesystem true + /tmp emptyDir 마운트. 컨테이너 단위 덮어쓰기(runAsNonRoot false · seccomp 다른
    값 · NET_BIND_SERVICE 밖의 capabilities.add)도 위반이다(계약 "PSA restricted 통과")."""
    workloads, violations = _identified(docs)
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


def check_env_split(docs: list[Doc]) -> list[str]:
    """gen-10 — 런타임(web · relay · celery)은 <pod>-env만, migrate Job은 <pod>-migrate만 참조한다(owner 자격은 Job만).
    런타임 pod의 볼륨으로도 <pod>-migrate가 들어오지 않고, ExternalSecret <pod>-env에 DATABASE_OWNER_URL이 없다
    (rules/django-pod.md §Settings: DATABASE_OWNER_URL은 migrate Job env에만 있다)."""
    workloads, violations = _identified(docs)
    if workloads is None:
        return violations
    violations.extend(workloads.missing())
    required: list[tuple[Doc, dict[str, Any]]] = [(workloads.web_deploy, workloads.web)]
    if workloads.relay is not None:
        required.append((workloads.web_deploy, workloads.relay))
    if workloads.celery_deploy is not None:
        required.extend((workloads.celery_deploy, item) for item in _containers(_pod_spec(workloads.celery_deploy)))
    for document, container in required:
        refs = _secret_refs(container)
        if ENV_SECRET not in refs:
            violations.append(f"{_where(document, container)}: 시크릿 {ENV_SECRET} 참조 없음(참조: {sorted(refs)})")
    runtime_pods = [document for document in (workloads.web_deploy, workloads.celery_deploy) if document is not None]
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


def check_db_tls(docs: list[Doc]) -> list[str]:
    """gen-11 — ExternalSecret <pod>-env의 DATABASE_URL · <pod>-migrate의 DATABASE_OWNER_URL 값에
    sslmode=verify-full과 sslrootcert=/etc/pg/ca.crt. 워크로드 3 모두 secretName pg-main-ca 볼륨이 있고 web · relay ·
    celery · migrate 컨테이너가 그것을 /etc/pg(디렉터리) 또는 /etc/pg/ca.crt(subPath ca.crt)로 마운트한다."""
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
    workloads, missing_workloads = _identified(docs)
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
            targets = [item for item in (workloads.web, workloads.relay) if item is not None]
        else:
            targets = _all_containers(spec)
        for container in targets:
            if not _mounts_ca(container, ca_volumes):
                violations.append(
                    f"{_where(document, container)}: {PG_CA_SECRET} 볼륨을 {PG_CA_DIR} 또는 {PG_CA_FILE}"
                    f"(subPath {PG_CA_KEY})로 마운트하지 않는다"
                )
    return violations


def check_probes(docs: list[Doc]) -> list[str]:
    """gen-12 — web: liveness GET /healthz · readiness GET /ready · startupProbe GET /ready(failureThreshold 30 ×
    periodSeconds 5), 포트는 web HTTP 8000. relay: liveness TCP 9464, readiness · startupProbe 없음. 워크로드 3의
    어떤 컨테이너의 어떤 프로브도 /health를 쓰지 않는다."""
    workloads, violations = _identified(docs)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(celery=False, job=False))
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


def check_strategy_resources(docs: list[Doc]) -> list[str]:
    """gen-13 — Deployment 2: RollingUpdate maxSurge 1 · maxUnavailable 0 · 노드 A 선호 affinity(preferred role In
    platform). requests.memory: web 256Mi · relay 96Mi · celery 192Mi · migrate(Job 첫 실행 컨테이너) 256Mi.
    워크로드 3의 모든 컨테이너에 resources.limits.cpu 없음."""
    workloads, violations = _identified(docs)
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
    targets: list[tuple[str, Doc, dict[str, Any]]] = [("web", workloads.web_deploy, workloads.web)]
    if workloads.relay is not None:
        targets.append(("relay", workloads.web_deploy, workloads.relay))
    if workloads.celery_deploy is not None:
        celery_containers = _containers(_pod_spec(workloads.celery_deploy))
        targets.extend(("celery", workloads.celery_deploy, item) for item in celery_containers)
    if workloads.job is not None:
        first = _first_executing(_pod_spec(workloads.job))
        if first is None:
            violations.append(f"{_ref(workloads.job)}: 컨테이너가 없다")
        else:
            targets.append(("migrate", workloads.job, first))
    for role, document, container in targets:
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


def check_migrate_sql(docs: list[Doc]) -> list[str]:
    """gen-14 — migrate Job의 첫 실행 컨테이너(initContainers[0] 또는 containers[0])의 command + args에
    REVOKE CONNECT ON DATABASE … FROM PUBLIC · GRANT CONNECT ON DATABASE … TO …가 있고, REVOKE가 migrate보다 앞이다
    (대소문자 무시 · 공백 정규화)."""
    workloads, violations = _identified(docs)
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


def check_annotations(docs: list[Doc]) -> list[str]:
    """gen-15 — Deployment 2의 reloader.stakater.com/auto: "true" · web pod 템플릿의 k8s.grafana.com/scrape: "true" ·
    relay 컨테이너 포트 9464."""
    workloads, violations = _identified(docs)
    if workloads is None:
        return violations
    violations.extend(workloads.missing(job=False))
    for document in (workloads.web_deploy, workloads.celery_deploy):
        if document is None:
            continue
        value = _dict(_dict(document.get("metadata")).get("annotations")).get(RELOADER_ANNOTATION)
        if value != "true":
            violations.append(f"{_ref(document)}: 어노테이션 {RELOADER_ANNOTATION} = {value!r}(기대 'true')")
    template = _dict(_dict(workloads.web_deploy.get("spec")).get("template"))
    scrape = _dict(_dict(template.get("metadata")).get("annotations")).get(SCRAPE_ANNOTATION)
    if scrape != "true":
        violations.append(f"{_ref(workloads.web_deploy)}: pod 템플릿 어노테이션 {SCRAPE_ANNOTATION} = {scrape!r}(기대 'true')")
    if workloads.relay is not None and RELAY_METRICS_PORT not in _container_ports(workloads.relay):
        violations.append(f"{_where(workloads.web_deploy, workloads.relay)}: containerPort {RELAY_METRICS_PORT} 없음")
    return violations


def check_configmap(docs: list[Doc]) -> list[str]:
    """gen-16 — data 키가 ACCESS_AUD_M2M · ACCESS_AUD_ADMIN · ACCESS_EXPECTED_CN · ADMIN_HOST · ALLOWED_HOSTS를 모두
    가진 ConfigMap이 있고, web과 celery 컨테이너가 그것을 envFrom[].configMapRef.name으로 참조한다."""
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
    workloads, missing_workloads = _identified(docs)
    if workloads is None:
        return violations + missing_workloads
    violations.extend(workloads.missing(relay=False, job=False))
    targets: list[tuple[Doc, dict[str, Any]]] = [(workloads.web_deploy, workloads.web)]
    if workloads.celery_deploy is not None:
        targets.extend((workloads.celery_deploy, item) for item in _containers(_pod_spec(workloads.celery_deploy)))
    for document, container in targets:
        refs = {
            _dict(_dict(item).get("configMapRef")).get("name")
            for item in _list(container.get("envFrom"))
        }
        if not refs & names:
            at = _where(document, container)
            violations.append(f"{at}: envFrom configMapRef가 키 5 ConfigMap {sorted(names)}을 참조하지 않는다")
    return violations


def check_ingress(docs: list[Doc]) -> list[str]:
    """gen-17 — 전 Ingress의 경로 합집합 = {/api, /health, /session, /sessions, /tenants} · /healthz · /ready ·
    /webhooks로 시작하는 경로 없음."""
    ingresses = _of_kind(docs, "Ingress")
    if not ingresses:
        return ["Ingress 없음 — 경로 검사 대상 없음"]
    violations: list[str] = []
    paths: set[str] = set()
    for document in ingresses:
        for rule in _list(_dict(document.get("spec")).get("rules")):
            for item in _list(_dict(_dict(rule).get("http")).get("paths")):
                path = _dict(item).get("path")
                if isinstance(path, str):
                    paths.add(path)
    if paths != INGRESS_PATHS:
        violations.append(
            f"Ingress 경로 집합 = {sorted(paths)}(기대 {sorted(INGRESS_PATHS)}) — 빠짐 {sorted(INGRESS_PATHS - paths)} · "
            f"남음 {sorted(paths - INGRESS_PATHS)}"
        )
    for path in sorted(paths):
        if path.startswith(INGRESS_FORBIDDEN_PREFIXES):
            violations.append(f"Ingress 경로 {path!r}는 노출 금지(/healthz · /ready · /webhooks)")
    return violations


CHECKS: dict[str, Callable[[list[Doc]], list[str]]] = {
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
}
