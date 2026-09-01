# Contract: platform-gitops 저장소

클러스터가 바라보는 유일한 정본. public. 시크릿 값은 없고 `ExternalSecret`만 있다. Argo CD root app이 이 저장소의 `clusters/oci-k3s/`를 읽는다.

## 디렉터리

```
platform-gitops/
├── bootstrap/
│   ├── argocd/                     # kustomization: remote base(install.yaml, `?ref=<commit sha>`로 핀 — 태그 금지) + patches(dex·applicationset 비활성, requests, ServerSideApply)
│   └── root-app.yaml               # Application "root" → clusters/oci-k3s/apps (유일한 수동 apply)
├── clusters/oci-k3s/
│   ├── projects/{platform,dev,prod}.yaml   # AppProject
│   └── apps/                       # Application 1개/컴포넌트 (app-of-apps)
├── platform/<component>/           # 18개: argocd policies cert-manager cert-manager-issuers traefik vault external-secrets
│   │                               #        cnpg cnpg-cluster cnpg-databases kafka kafka-topics dragonfly
│   │                               #        authentik openfga monitoring cloudflared reloader system-upgrade
│   ├── kustomization.yaml          # helmCharts(values 인라인) 또는 순수 매니페스트
│   └── …                           # traefik/ 은 Middleware·TLSOption·TLSStore만 — Traefik 자체 설정(HelmChartConfig)의 정본은 노드 A `server/manifests/traefik-config.yaml`
│                                   # argocd/ 는 Argo CD 자기 관리 Application(bootstrap/argocd/ 를 소스로), system-upgrade/ 는 SUC + Plan
├── apps/<pod>/
│   ├── base/{deployment,service,ingress,configmap,externalsecret-env,externalsecret-migrate,migrate-job,kustomization}.yaml   # Ingress host = PLACEHOLDER.joshuatech.dev
│   └── overlays/{dev,prod}/kustomization.yaml   # namespace, images[].digest, Ingress host JSON6902, replicas, admin Ingress(prod)
├── secrets/<ns>/                   # 플랫폼 네임스페이스별 ExternalSecret(`platform/` 경로만, store `vault-platform`)
└── .github/workflows/{validate,promote}.yml
```

## 네임스페이스

- 전체 목록(14개)과 PSA 레벨·NetworkPolicy 허용 매트릭스의 정본은 **contracts/network-policy.md**다: `kube-system` · `argocd` · `vault` · `external-secrets` · `cert-manager` · `cnpg-system` · `data` · `identity` · `jt-dev` · `jt-prod` · `monitoring` · `system-upgrade` · `cloudflared` · `reloader`. `observability`라는 이름은 쓰지 않는다.
- `platform/policies/`는 이 네임스페이스를 **전부** 선언한다: `kube-system`은 K3s가 만든 ns라 PSA 라벨만 SSA 패치 + `deny-imds`, 나머지 13개는 Namespace + PSA 라벨 + 공통 정책 세트 5종(`default-deny`·`allow-dns`·`allow-same-namespace`·`allow-kube-api`·`allow-apiserver-webhook`, ns마다 해당하는 것) + 매트릭스 행별 allow 규칙 + `allow-imds`(`vault`만). ResourceQuota/LimitRange(`jt-dev`·`jt-prod`, LimitRange는 `defaultRequest.cpu` + memory `default`만 — `default.cpu`·`max.cpu` 금지) + SA `agent-view`·ClusterRole `agent-view-extra`(`kube-system`) RBAC도 여기 있다. validate.yml이 `platform/policies`의 Namespace 목록 = 계약 표(14개)임을 lint한다.
- `platform/reloader/`: Stakater Reloader **차트 2.2.16**(appVersion v1.4.21) — minor 부동 핀(`v1.4.x`)을 쓰지 않는다. Secret 변경 시 롤아웃은 Deployment 어노테이션 `reloader.stakater.com/auto: "true"`.
  - **VD-9(검증 후 결정)**: 기본 가정은 **scoped 모드**(`watchGlobally: false` + 감시 ns 목록)로 ClusterRole 없이 인스턴스 1개. 옵션 A = scoped 모드가 동작하면 그대로, 옵션 B = `watchGlobally: true` + `namespaceSelector`(ClusterRole이 남는 트레이드오프를 `report.md`에 기록). T046 배포 시 ExternalSecret 값을 바꿔 롤아웃 1회 + Argo Synced 유지를 확인하고 확정한다.

## Application 규약

| 항목 | 규칙 |
|---|---|
| 이름 | `platform-<component>` · `<pod>-<env>` |
| project | 플랫폼 → `platform`, 앱 → `dev`·`prod` |
| sync-wave | 아래 **§sync-wave 단일 표**가 정본(`-20` … `60`, 앱 `100`). 다른 곳에 wave 번호를 중복 기재하지 않는다 |
| syncPolicy | 플랫폼: `automated: { prune: false, selfHeal: true }`, syncOptions `ServerSideApply=true`, `CreateNamespace=true`, `Prune=confirm`, `Delete=confirm`, `SkipDryRunOnMissingResource=true`. dev 앱: prune·selfHeal true. prod 앱: automated이되 변경은 PR로만 |
| AppProject | `platform`: sourceRepos [gitops, 차트 저장소], destinations = 플랫폼 네임스페이스(network-policy.md 표), clusterResourceWhitelist(CRD·Namespace·ClusterRole…). `dev`/`prod`: 자기 네임스페이스만, cluster 리소스 금지, **`namespaceResourceBlacklist`: NetworkPolicy · ResourceQuota · LimitRange · Role · RoleBinding · ServiceAccount**(정책 객체는 `platform/policies/`만 쓴다). `default`: sourceRepos·destinations 비움 |
| 삭제 보호 | `Cluster pg-main` · `Kafka jt-kafka` · `KafkaNodePool` · Vault/Dragonfly PVC · 모든 오퍼레이터 CRD(CNPG·Strimzi·cert-manager·ESO)에 `argocd.argoproj.io/sync-options: Delete=false,Prune=false` |
| 워크로드 강화 | 템플릿 pod·cloudflared·dragonfly Deployment: `automountServiceAccountToken: false` + securityContext(`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, `readOnlyRootFilesystem: true` + `/tmp` emptyDir). helm 차트 컴포넌트(Vault·Authentik·OpenFGA·Reloader)는 values에 securityContext 4항목(`runAsNonRoot`·`allowPrivilegeEscalation`·`capabilities.drop`·`seccompProfile`)을 명시한다 |

## sync-wave 단일 표

FR-010의 순서를 이 표 하나로만 표현한다. Argo CD는 wave N의 리소스가 Healthy가 된 뒤 N+1로 넘어가므로, 오퍼레이터와 그 오퍼레이터가 조정하는 CR은 다른 wave에 둔다.

| wave | 디렉터리(Application) | FR-010 단계 |
|---|---|---|
| `-20` | `argocd` | Argo CD 자기 관리(bootstrap을 인수) |
| `-10` | `policies` | CRD·namespaces·policies |
| `0` | `cert-manager` · `external-secrets` | cert-manager·ESO(둘 다 CRD 제공) |
| `10` | `vault` | Vault(시크릿 원천) |
| `20` | `cert-manager-issuers` · `cnpg` · `system-upgrade` | ClusterIssuer·와일드카드 인증서(ExternalSecret 소비) · CNPG operator + barman-cloud plugin · SUC |
| `30` | `cnpg-cluster` · `kafka` · `dragonfly` | pg-main · Strimzi operator + `Kafka`/`KafkaNodePool` · Dragonfly |
| `40` | `cnpg-databases` · `kafka-topics` | `Database`·`DatabaseRole` · `KafkaTopic`·`KafkaUser` · CA 미러 ExternalSecret |
| `50` | `authentik` · `openfga` | 신원 |
| `60` | `monitoring` · `cloudflared` · `reloader` · `traefik` | Alloy · 터널 · Reloader · Traefik Middleware/TLSOption/TLSStore |
| `100` | `<pod>-dev` · `<pod>-prod`(`apps/<pod>/overlays/<env>`) | 앱 |

- CRD를 늦게 만드는 컴포넌트에는 `SkipDryRunOnMissingResource=true`를 함께 둔다(예: `cert-manager-issuers`, alloy-operator CR).
- T041은 이 표를 그대로 Application 어노테이션(`argocd.argoproj.io/sync-wave`)으로 옮긴다. 표에 없는 디렉터리를 만들면 validate가 실패한다.

## 이미지 · 승격

- `apps/<pod>/overlays/<env>/kustomization.yaml`의 `images:` 항목은 `newName: ghcr.io/joshua92y/<pod>`, `digest: sha256:…`만(태그 금지). validate.yml이 `newTag` 존재 시 실패.
- `platform/` 이미지(cloudflared·dragonfly·helm values의 `image:`)는 태그에 `@sha256:…`을 병기한다. validate.yml이 digest 없는 `image:` 줄을 **경고**한다(Renovate `pinDigests`가 못 미치는 곳은 수동).
- **dev bump(자동 머지)**: 모노레포 `publish-pod.yml`이 GitHub App 토큰으로 브랜치 **`bump/dev-<pod>-<sha7>`** 을 만들고 `overlays/dev` digest를 바꾼 PR(메시지 `chore(<pod>): dev → <short-digest>`)을 열어 `gh pr merge --auto --squash`를 건다 — required check `validate` 통과 뒤 자동 머지. main 직접 push 없음.
  - **VD-5(검증 후 결정)**: 기본 가정은 "public repo Free에서 `gh pr merge --auto`와 Environment `production`이 동작한다"(저장소 설정 **Allow auto-merge 활성** 필요, T003 수동 목록). 옵션 A = 동작하면 위 자동 머지 경로, 옵션 B = 동작하지 않으면 dev bump도 **사람 머지**로 내린다. T003·T074의 첫 PR에서 실측해 확정하고 결과를 `report.md`에 남긴다. 어느 쪽이든 아래 `jt-ci[bot]` 경로 lint는 유지한다.
- **prod 승격(사람 머지)**: `promote.yml`(workflow_dispatch, 입력 `pod`)이 dev digest를 읽어 **`gh attestation verify oci://ghcr.io/joshua92y/<pod>@<digest> --owner joshua92y`** 를 먼저 실행(실패 시 중단)한 뒤 `overlays/prod`를 바꾼 PR을 **연다(제목 `promote(<pod>): <short-digest>`)**. **auto-merge를 걸지 않는다** — 운영자가 렌더링 diff 코멘트를 확인하고 직접 머지한다(FR-038·T047과 동일 규칙). 머지 → Argo sync. 롤백 = 해당 커밋 `git revert` PR.
- ruleset(main): PR 필수 · required check `validate` · 0 approvals · **`bypass_actors: []`**(GitHub App 포함 누구도 bypass 없음).
- **`jt-ci[bot]` 경로 lint**(validate.yml): PR 작성자가 `jt-ci[bot]`이면 변경 파일은 `apps/*/overlays/dev/kustomization.yaml` 뿐이어야 하고, 그 안에서도 `images[].digest` 줄만 바뀌어야 한다. 다른 파일·다른 줄이 바뀌면 실패 — App 토큰이 탈취돼도 dev digest 외에는 못 바꾼다.

## ExternalSecret 규약

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: identity-admin-env, namespace: jt-prod }
spec:
  refreshInterval: 5m
  secretStoreRef: { kind: ClusterSecretStore, name: vault-prod }
  target: { name: identity-admin-env, creationPolicy: Owner }
  data:
    - secretKey: DATABASE_URL
      remoteRef: { key: prod/db/identity_admin/app, property: url }
```

### ClusterSecretStore 5개

| store | provider | `conditions.namespaces` | 인증 주체(SA, ns `external-secrets`) | 접근 범위 |
|---|---|---|---|---|
| `vault-platform` | vault(kv v2) | 플랫폼 ns 12개(network-policy.md 표에서 `jt-dev`·`jt-prod` 제외 — `kube-system` 포함) | `eso-platform` | Vault role `eso-platform`: `kv/data/platform/*` · `kv/metadata/platform/*` read |
| `vault-dev` | vault | `jt-dev` | `eso-dev` | role `eso-dev`: `kv/data/dev/*` · `kv/metadata/dev/*` read |
| `vault-prod` | vault | `jt-prod` | `eso-prod` | role `eso-prod`: `kv/data/prod/*` · `kv/metadata/prod/*` read |
| `vault-data` | vault | `data` · `identity` | `eso-data` | role `eso-data`: **열거 경로만**(env 와일드카드 금지) — `kv/data/{dev,prod}/db/*` · `kv/data/{dev,prod}/kafka/*` · `kv/data/{dev,prod}/dragonfly/*` · `kv/data/{dev,prod}/openfga/*` · `kv/data/{dev,prod}/authentik/webhooks/*` + 같은 `kv/metadata/…` read |
| `k8s-data-ca` | **kubernetes** | `identity` · `jt-dev` · `jt-prod` | `eso-ca-reader` | `remoteNamespace: data`. Role(ns `data`): `secrets` `get/list/watch` `resourceNames: [pg-main-ca, jt-kafka-cluster-ca-cert]` + `selfsubjectrulesreviews` `create`(ESO 권한 자가 점검) |

`data`·`identity` 네임스페이스에는 `vault-platform`과 `vault-data`가 **둘 다** 걸린다: 환경 무관 공유 비밀은 `vault-platform`(`platform/` 접두), env 스코프 비밀은 `vault-data`(위 열거 접두)로 읽는다. 어느 쪽도 `kv/{env}/*` 전체를 열지 않는다.

### 이름·인증 규약

- Vault role 이름 = 인증에 쓰는 **SA 이름과 같다**(`eso-platform`·`eso-dev`·`eso-prod`·`eso-data`). store 이름은 `vault-<scope>` 또는 `k8s-data-ca`.
- `apiVersion: external-secrets.io/v1`(v1beta1 금지). `auth.kubernetes.serviceAccountRef`에는 **`namespace: external-secrets`를 반드시 적는다**(생략하면 ExternalSecret의 ns에서 SA를 찾아 실패).
- Vault Kubernetes auth role은 전부 `audiences: [vault]`(ESO 쪽 `auth.kubernetes.serviceAccountRef.audiences`도 같은 값) + **`token_ttl=1h` · `token_max_ttl=4h`**(기본 32일 금지). 수동 확인은 `kubectl create token vault-backup -n vault --audience vault --duration=10m`.
- Vault role `identity-admin`은 **만들지 않는다**(삭제). pod는 Vault를 직접 읽지 않고 ESO가 만든 Secret만 본다.

### 공유 컴포넌트 비밀 = `kv/platform/…`

Authentik·OpenFGA는 pod가 아니라 환경 공유 컴포넌트이므로 env 접두를 쓰지 않는다.

| 경로 | 읽는 쪽(store) |
|---|---|
| `kv/platform/db/authentik/owner` · `kv/platform/db/openfga/owner` | `platform/cnpg-databases/`의 CNPG `DatabaseRole` passwordSecret · Authentik/OpenFGA Deployment (`vault-platform`) |
| `kv/platform/authentik/sources/github` · `kv/platform/authentik/sources/google` | Authentik 소셜 로그인 소스 blueprint (`vault-platform`) |
| `kv/platform/authentik/e2e` | Authentik 로컬 사용자 `e2e@joshuatech.dev`의 비밀번호·TOTP 시드. blueprint가 `vault-platform`으로, tester는 Vault role `e2e-reader`(bound `kube-system/agent-view`, ttl 1h)로 **같은 경로**를 읽는다 |
| `kv/platform/openfga/preshared` | OpenFGA 서버 `authn.preshared` (`vault-platform`, `identity` ns) |

- 호출자 쪽 사본: identity-admin은 `kv/{env}/openfga/{store_id,preshared}`를 `<pod>-env`로 읽는다(`vault-{env}`). `preshared` 값은 `kv/platform/openfga/preshared`와 같아야 하며 회전 시 둘을 함께 바꾼다(런북 `secret-rotation.md`).
- 웹훅 비밀은 pod·env마다 분리한다: **`kv/{env}/authentik/webhooks/<pod>`**(키 `secret`). Authentik NotificationTransport가 `vault-data`로, pod가 `<pod>-env`(`vault-{env}`)로 같은 값을 읽는다. `kv/{env}/authentik/identity-admin`에는 더 이상 `webhook_secret`을 두지 않는다.

### 공통 규칙

- 경로 형식·키·소비자 전체 목록은 `data-model.md` §8.
- `refreshInterval: 5m`(전 ExternalSecret 공통).
- pod마다 ExternalSecret 2개: **`<pod>-env`**(app DB · kafka · dragonfly · authentik · openfga · sentry — Deployment·celery `envFrom`) / **`<pod>-migrate`**(owner DB만 — PreSync migrate Job 전용). Deployment `envFrom`에 `-migrate`가 있으면 validate 실패(T033).
- 비밀이 아닌 값(`ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ADMIN_HOST`·`ALLOWED_HOSTS`·`IDENTITY_M2M_URL` 류)은 ConfigMap.
- **CA 미러**(`k8s-data-ca`): `pg-main-ca`(CNPG CA)와 `jt-kafka-cluster-ca-cert`(Strimzi CA)를 `identity`·`jt-dev`·`jt-prod`에 복제한다(값은 Vault를 거치지 않는다). CNPG의 `<cluster>-ca` Secret에는 **`ca.key`가 함께 들어 있으므로** ExternalSecret은 `remoteRef.property: ca.crt`만 쓰고 `dataFrom`(전체 복사)을 쓰지 않는다. 미러된 Secret에 `ca.key`가 있으면 T031 FAIL — CA 개인키가 앱 ns에 있으면 서버 인증서와 `streaming_replica` 인증서를 위조할 수 있어 `sslmode=verify-full`이 무력화된다.

### validate.yml ExternalSecret 검사 (T033)

1. `remoteRef.key` 정규식 `^(platform|dev|prod)/[a-z0-9_./-]+$` (`k8s-data-ca` 미러 제외).
2. **scope ↔ 위치 일치**: `apps/*/overlays/dev/**` → `dev/`만 + `secretStoreRef.name: vault-dev`; `overlays/prod/**` → `prod/`만 + `vault-prod`; `secrets/**` → `platform/`만 + `vault-platform`.
3. **`platform/{cnpg-databases,kafka-topics,dragonfly,authentik,openfga}/**`** 의 ExternalSecret은 store가 `vault-data`(위 열거 접두 목록 안의 경로만) 또는 `vault-platform`(`platform/` 접두만)이어야 한다. 다른 store·열거 밖 접두는 실패.
4. **`k8s-data-ca`** 를 참조하는 ExternalSecret은 `remoteRef.key ∈ {pg-main-ca, jt-kafka-cluster-ca-cert}` + `remoteRef.property: ca.crt` 뿐이다(`dataFrom` 금지).
5. Deployment·CronJob `envFrom`에 `-migrate` Secret 참조 금지.
6. `automountServiceAccountToken: false` lint 범위 = `apps/**` · `platform/cloudflared` · `platform/dragonfly`(그 밖의 helm 차트 컴포넌트는 자체 SA가 필요하므로 제외).

## validate.yml (required check `validate`)

1. `kustomize build`(모든 overlay·platform) → `kubeconform -strict -ignore-missing-schemas`(CRD 스키마는 datreeio 카탈로그).
2. `helm template`(helmCharts 사용 컴포넌트).
3. 시크릿·경계 검사: `gitleaks`, 위 **§validate.yml ExternalSecret 검사** 6항목, `images[].newTag` 금지, `platform/**` `image:` digest 부재 경고.
4. 정책 검사: `platform/policies` Namespace 목록 = contracts/network-policy.md 표(14개); ns마다 해당 공통 정책 세트 존재; 모든 egress `ipBlock` 규칙에 `ports` + `except` 4개(IMDS·RFC 1918 3종); helm values의 포트 ↔ 정책 포트 일치; LimitRange에 `default.cpu`·`max.cpu` 없음.
5. 작성자 검사: PR 작성자가 `jt-ci[bot]`이면 변경 파일 = `apps/*/overlays/dev/kustomization.yaml`, 변경 줄 = `images[].digest`뿐.
6. sync-wave 검사: 모든 Application의 `argocd.argoproj.io/sync-wave` 값이 **§sync-wave 단일 표**와 일치하고, 표에 없는 `platform/<component>/` 디렉터리가 없다.
7. 렌더링 diff 코멘트: `kustomize build` 결과를 main과 PR에서 비교해 PR 코멘트로 남긴다(Argo CD 접근 불필요; `argocd app diff`는 쓰지 않음).

## 변경 권한

- 사람은 PR로만 main에 쓴다(ruleset). GitHub App(`jt-ci`)도 PR로만 쓴다 — bypass 주체 없음. App이 auto-merge를 거는 것은 **dev digest bump PR뿐**이고(VD-5), prod 승격 PR은 사람이 머지한다.
- `platform/`·`clusters/` 변경은 approval-review의 `k8s-security` 경계 대상(모노레포 spec에서 링크). 비가역 변경 파일(오퍼레이터 버전·`metadataVersion`·PG major·Authentik 차트) PR 템플릿에는 스냅샷 3종(Vault raft·CNPG 백업·K3s SQLite) 확인 체크박스가 있다.
