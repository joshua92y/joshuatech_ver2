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
├── platform/<component>/           # policies cert-manager traefik vault external-secrets cnpg cnpg-databases kafka dragonfly authentik openfga monitoring cloudflared reloader
│   ├── kustomization.yaml          # helmCharts(values 인라인) 또는 순수 매니페스트
│   └── …                           # traefik/ 은 Middleware·TLSOption·TLSStore만 — Traefik 자체 설정(HelmChartConfig)의 정본은 노드 A `server/manifests/traefik-config.yaml`
├── apps/<pod>/
│   ├── base/{deployment,service,ingress,configmap,externalsecret-env,externalsecret-migrate,migrate-job,kustomization}.yaml   # Ingress host = PLACEHOLDER.joshuatech.dev
│   └── overlays/{dev,prod}/kustomization.yaml   # namespace, images[].digest, Ingress host JSON6902, replicas, admin Ingress(prod)
├── secrets/<ns>/                   # 플랫폼 네임스페이스별 ExternalSecret(`platform/` 경로만, store `vault-platform`)
└── .github/workflows/{validate,promote}.yml
```

## 네임스페이스

- 전체 목록(14개)과 PSA 레벨·NetworkPolicy 허용 매트릭스의 정본은 **contracts/network-policy.md**다: `kube-system` · `argocd` · `vault` · `external-secrets` · `cert-manager` · `cnpg-system` · `data` · `identity` · `jt-dev` · `jt-prod` · `monitoring` · `system-upgrade` · `cloudflared` · `reloader`. `observability`라는 이름은 쓰지 않는다.
- `platform/policies/`는 이 네임스페이스를 **전부** 선언한다(Namespace + PSA 라벨 + 정책 3종 `default-deny`·`allow-dns`·`deny-imds`; `kube-system`은 `deny-imds`만) + ResourceQuota/LimitRange(`jt-dev`·`jt-prod`) + SA `agent-view`(`kube-system`) RBAC. validate.yml이 `platform/policies`의 Namespace 목록 = 계약 표임을 lint한다.
- `platform/reloader/`: Stakater Reloader v1.4.x. Secret 변경 시 롤아웃은 Deployment 어노테이션 `reloader.stakater.com/auto: "true"`.

## Application 규약

| 항목 | 규칙 |
|---|---|
| 이름 | `platform-<component>` · `<pod>-<env>` |
| project | 플랫폼 → `platform`, 앱 → `dev`·`prod` |
| sync-wave | `-1` CRD·namespaces·policies → `0` cert-manager·external-secrets → `1` vault → `2` cnpg-operator·strimzi-operator → `3` pg-main·cnpg-databases·dragonfly·kafka → `4` authentik·openfga → `5` monitoring·cloudflared·reloader·traefik(Middleware·TLSOption·TLSStore) → 앱 `10` |
| syncPolicy | 플랫폼: `automated: { prune: false, selfHeal: true }`, syncOptions `ServerSideApply=true`, `CreateNamespace=true`, `Prune=confirm`, `Delete=confirm`, `SkipDryRunOnMissingResource=true`. dev 앱: prune·selfHeal true. prod 앱: automated이되 변경은 PR로만 |
| AppProject | `platform`: sourceRepos [gitops, 차트 저장소], destinations = 플랫폼 네임스페이스(network-policy.md 표), clusterResourceWhitelist(CRD·Namespace·ClusterRole…). `dev`/`prod`: 자기 네임스페이스만, cluster 리소스 금지, **`namespaceResourceBlacklist`: NetworkPolicy · ResourceQuota · LimitRange · Role · RoleBinding · ServiceAccount**(정책 객체는 `platform/policies/`만 쓴다). `default`: sourceRepos·destinations 비움 |
| 삭제 보호 | `Cluster pg-main` · `Kafka jt-kafka` · `KafkaNodePool` · Vault/Dragonfly PVC · 모든 오퍼레이터 CRD(CNPG·Strimzi·cert-manager·ESO)에 `argocd.argoproj.io/sync-options: Delete=false,Prune=false` |
| 워크로드 강화 | 템플릿 pod·cloudflared·dragonfly Deployment: `automountServiceAccountToken: false` + securityContext(`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, `readOnlyRootFilesystem: true` + `/tmp` emptyDir) |

## 이미지 · 승격

- `apps/<pod>/overlays/<env>/kustomization.yaml`의 `images:` 항목은 `newName: ghcr.io/joshua92y/<pod>`, `digest: sha256:…`만(태그 금지). validate.yml이 `newTag` 존재 시 실패.
- `platform/` 이미지(cloudflared·dragonfly·helm values의 `image:`)는 태그에 `@sha256:…`을 병기한다. validate.yml이 digest 없는 `image:` 줄을 **경고**한다(Renovate `pinDigests`가 못 미치는 곳은 수동).
- dev bump: 모노레포 `publish-pod.yml`이 GitHub App 토큰으로 브랜치 **`bump/dev-<pod>-<sha7>`** 을 만들고 `overlays/dev` digest를 바꾼 PR(메시지 `chore(<pod>): dev → <short-digest>`)을 열어 `gh pr merge --auto --squash`를 건다 — required check `validate` 통과 뒤 자동 머지. main 직접 push 없음.
- prod 승격: `promote.yml`(workflow_dispatch, 입력 `pod`)이 dev digest를 읽어 **`gh attestation verify oci://ghcr.io/joshua92y/<pod>@<digest> --owner joshua92y`** 를 먼저 실행(실패 시 중단)한 뒤 `overlays/prod`를 바꾼 PR 생성(제목 `promote(<pod>): <short-digest>`) + `gh pr merge --auto --squash` → `validate` 통과 → 머지 → Argo sync. 롤백 = 해당 커밋 `git revert` PR.
- ruleset(main): PR 필수 · required check `validate` · 0 approvals · **`bypass_actors: []`**(GitHub App 포함 누구도 bypass 없음).

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

| ClusterSecretStore | `conditions.namespaces` | `auth.kubernetes.serviceAccountRef`(ns `external-secrets`) | Vault role(같은 이름) · 정책 |
|---|---|---|---|
| `vault-platform` | 플랫폼 ns 목록(network-policy.md 표에서 `jt-dev`·`jt-prod` 제외) | `eso-platform` | `kv/data/platform/*`·`kv/metadata/platform/*` read |
| `vault-dev` | `jt-dev` | `eso-dev` | `kv/data/dev/*`·`kv/metadata/dev/*` read |
| `vault-prod` | `jt-prod` | `eso-prod` | `kv/data/prod/*`·`kv/metadata/prod/*` read |

- 경로 형식은 `data-model.md` §8. validate.yml 검사: `remoteRef.key` 정규식 `^(platform|dev|prod)/[a-z0-9_./-]+$` + **scope 일치** — `apps/*/overlays/dev`의 ExternalSecret은 `dev/`만, `overlays/prod`는 `prod/`만, `secrets/`는 `platform/`만 + `secretStoreRef.name`이 overlay와 일치(`vault-dev`/`vault-prod`/`vault-platform`).
- `refreshInterval: 5m`(전 ExternalSecret 공통).
- pod마다 ExternalSecret 2개: **`<pod>-env`**(app DB · kafka · dragonfly · authentik · sentry — Deployment·celery `envFrom`) / **`<pod>-migrate`**(owner DB만 — PreSync migrate Job 전용). Deployment `envFrom`에 `-migrate`가 있으면 validate 실패(T064).
- 비밀이 아닌 값(`ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ADMIN_HOST`·`ALLOWED_HOSTS`·`IDENTITY_M2M_URL` 류)은 ConfigMap.
- CA 미러: `pg-main-ca`(CNPG CA)와 `jt-kafka-cluster-ca-cert`(Strimzi CA)는 ESO **kubernetes provider** store로 `identity`·`jt-dev`·`jt-prod`에 복제(값은 Vault를 거치지 않음).
- 미결(R10 후속): `data`·`identity` ns가 소비하는 env 스코프 경로(`kv/{env}/db/*` → CNPG managed roles, `kv/{env}/kafka/*` → KafkaUser, `kv/{env}/dragonfly/acl` → Dragonfly, `kv/{env}/authentik/identity-admin.webhook_secret` → Authentik)는 `vault-platform` 정책(`platform/*`) 범위 밖이다. 결정표가 이 경로의 store/role을 정하지 않았으므로 T044·T045 착수 전에 확정한다.

## validate.yml (required check `validate`)

1. `kustomize build`(모든 overlay·platform) → `kubeconform -strict -ignore-missing-schemas`(CRD 스키마는 datreeio 카탈로그).
2. `helm template`(helmCharts 사용 컴포넌트).
3. 시크릿·경계 검사: `gitleaks`, `ExternalSecret.remoteRef.key` 정규식 + scope↔overlay 일치 + `secretStoreRef.name` 일치, `images[].newTag` 금지, `platform/**` `image:` digest 부재 경고, Deployment `envFrom`에 `-migrate` 금지.
4. `platform/policies` Namespace 목록 = contracts/network-policy.md 표(14개), ns마다 정책 3종 존재.
5. 렌더링 diff 코멘트: `kustomize build` 결과를 main과 PR에서 비교해 PR 코멘트로 남긴다(Argo CD 접근 불필요; `argocd app diff`는 쓰지 않음).

## 변경 권한

- 사람은 PR로만 main에 쓴다(ruleset). GitHub App(`jt-ci`)도 PR + auto-merge로만 쓴다 — bypass 주체 없음.
- `platform/`·`clusters/` 변경은 approval-review의 `k8s-security` 경계 대상(모노레포 spec에서 링크). 비가역 변경 파일(오퍼레이터 버전·`metadataVersion`·PG major·Authentik 차트) PR 템플릿에는 스냅샷 3종(Vault raft·CNPG 백업·K3s SQLite) 확인 체크박스가 있다.
