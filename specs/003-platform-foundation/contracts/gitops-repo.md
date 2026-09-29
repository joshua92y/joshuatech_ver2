# Contract: platform-gitops 저장소

클러스터가 바라보는 유일한 정본. public. 시크릿 값은 없고 `ExternalSecret`만 있다. Argo CD root app이 이 저장소의 `clusters/oci-k3s/`를 읽는다.

## 디렉터리

```
platform-gitops/
├── bootstrap/
│   ├── argocd/                     # kustomization: remote base(install.yaml, `?ref=<commit sha>`로 핀 — 태그 금지) + patches(dex·applicationset 비활성, requests, ServerSideApply)
│   │                               #   + ingress.yaml(Ingress `argo.joshuatech.dev` → argocd-server:http, websecure, grpc-web — T043; platform/argocd/ 는 자기 관리 Application 자리표시 유지)
│   └── root-app.yaml               # Application "root" → clusters/oci-k3s/apps (유일한 수동 apply)
├── clusters/oci-k3s/
│   ├── projects/{platform,dev,prod,tests}.yaml   # AppProject
│   └── apps/                       # Application 1개/컴포넌트 (app-of-apps)
├── platform/<component>/           # 21개: argocd policies cert-manager cert-manager-issuers traefik vault external-secrets secret-stores secrets
│   │                               #        cnpg cnpg-cluster cnpg-databases kafka kafka-topics dragonfly
│   │                               #        authentik openfga monitoring cloudflared reloader system-upgrade
│   ├── kustomization.yaml          # helmCharts(values 인라인) 또는 순수 매니페스트
│   └── …                           # traefik/ 은 Middleware·TLSOption·TLSStore만 — Traefik 자체 설정(HelmChartConfig)의 정본은 노드 A `server/manifests/traefik-config.yaml`
│                                   #   (노드 A `server/manifests/` 에는 `cloudflare-origin-pull-ca.yaml`(공개 AOP 루트 CA Secret `kube-system/cloudflare-origin-pull-ca` — T043)도 함께 둔다; 정본은 모노레포 `infra/bootstrap/`, 이 저장소에는 두지 않는다)
│                                   # argocd/ 는 Argo CD 자기 관리 Application(bootstrap/argocd/ 를 소스로), system-upgrade/ 는 SUC + Plan
│                                   # secret-stores/ 는 ClusterSecretStore 5개(ESO CRD·Vault 뒤 — T045), secrets/ 는 아래 `secrets/<ns>/` 를 base 로 묶어 클러스터에 적용하는 전용 컴포넌트(T045)
├── apps/<pod>/
│   ├── base/{deployment,service,ingress,configmap,externalsecret-env,externalsecret-migrate,migrate-job,kustomization}.yaml   # Ingress host = PLACEHOLDER.joshuatech.dev
│   └── overlays/{dev,prod}/kustomization.yaml   # namespace, images[].digest, Ingress host JSON6902, replicas, admin Ingress(prod)
├── secrets/<ns>/                   # 플랫폼 네임스페이스별 ExternalSecret(`platform/` 경로만, store `vault-platform`)
│                                   #   적용 주체 = `platform/secrets/`(kustomization 이 `../../secrets/<ns>` 를 base 로 포함) → Application `platform-secrets` **하나뿐**이다.
│                                   #   소비자 컴포넌트(cert-manager-issuers · cloudflared …)는 이 디렉터리를 base 로 포함하지 않는다(단일 소유 — 소비자 배포와 ExternalSecret 적용의 분리)
└── .github/workflows/{validate,promote}.yml
```

## 네임스페이스

- 전체 목록(14개)과 PSA 레벨·NetworkPolicy 허용 매트릭스의 정본은 **contracts/network-policy.md**다: `kube-system` · `argocd` · `vault` · `external-secrets` · `cert-manager` · `cnpg-system` · `data` · `identity` · `jt-dev` · `jt-prod` · `monitoring` · `system-upgrade` · `cloudflared` · `reloader`. `observability`라는 이름은 쓰지 않는다.
- `platform/policies/`는 이 네임스페이스를 **전부** 선언한다: `kube-system`은 K3s가 만든 ns라 PSA 라벨만 SSA 패치 + `deny-imds`, 나머지 13개는 Namespace + PSA 라벨 + 공통 정책 세트 5종(`default-deny`·`allow-dns`·`allow-same-namespace`·`allow-kube-api`·`allow-apiserver-webhook`, ns마다 해당하는 것) + 매트릭스 행별 allow 규칙 + `allow-imds`(`vault`만). ResourceQuota/LimitRange(`jt-dev`·`jt-prod`, LimitRange는 `defaultRequest.cpu` + memory `default`만 — `default.cpu`·`max.cpu` 금지) + SA `agent-view`·ClusterRole `agent-view-extra`(`kube-system`) RBAC도 여기 있다. validate.yml이 `platform/policies`의 Namespace 목록 = 계약 표(14개)임을 lint한다.
- `platform/reloader/`: Stakater Reloader **차트 2.2.16**(appVersion v1.4.21) — minor 부동 핀(`v1.4.x`)을 쓰지 않는다. Secret 변경 시 롤아웃은 Deployment 어노테이션 `reloader.stakater.com/auto: "true"`.
  - (T046) **scoped 모드**: `reloader.watchGlobally: false` + `reloader.namespaces` = **`identity` · `jt-dev` · `jt-prod`**(릴리스 ns `reloader`는 차트가 자동 포함). 렌더에 **ClusterRole·ClusterRoleBinding 0** — 감시 ns마다 Role + RoleBinding만. **`cloudflared`는 감시하지 않는다**(터널 커넥터는 수동 1개씩 교체가 안전장치 — T045 G4). 새 소비자 ns는 이 목록에 먼저 추가한다. `reloader.reloadStrategy: annotations`. 차트 기본값이 `watchGlobally: true`라 values 오타가 전역 모드로 되돌릴 수 있으므로(실측 2026-09-22: `watchGlobally` 한 키만 틀리면 차트 가드가 렌더를 **실패**시키고 — Argo에서는 `ComparisonError` —, 부모 키 `reloader:`를 틀려 두 설정이 **함께** 빠지면 렌더는 성공한 채 **조용히** 전역 모드 + ClusterRole이 된다), validate.yml이 렌더 결과를 검사한다(ClusterRole 0 · Deployment 인자 목록 정확 일치 · Role/RoleBinding ns 집합과 주체 · 이미지 컨테이너 1개 · kind 개수 — 항목의 정본은 §validate.yml 4의 `(T046)` 줄).
  - **VD-9(검증 후 결정)**: 기본 가정은 **scoped 모드**(`watchGlobally: false` + 감시 ns 목록)로 ClusterRole 없이 인스턴스 1개. 옵션 A = scoped 모드가 동작하면 그대로, 옵션 B = `watchGlobally: true` + `namespaceSelector`(ClusterRole이 남는 트레이드오프를 `report.md`에 기록). T046 배포 시 ExternalSecret 값을 바꿔 롤아웃 1회 + Argo Synced 유지를 확인하고 확정한다. → **실측 방법 확정(2026-09-22 사용자 결정)**: 그 시점에 `jt-dev`에 ExternalSecret·소비자가 없으므로, **Argo가 관리하는 시험 Deployment**(`jt-dev`, 어노테이션 `auto`) + **Argo 밖에서 운영자가 값을 바꾸는 Secret**으로 잰다 — 실제 소비자(Argo 관리 Deployment + ESO가 쓴 Secret)와 같은 구조다. 시험 대상은 판정 뒤 제거한다(설계 `design/t046-design.md` §3).

## Application 규약

| 항목 | 규칙 |
|---|---|
| 이름 | `platform-<component>` · `<pod>-<env>` |
| project | 플랫폼 → `platform`, 앱 → `dev`·`prod`, 검증 Job(`platform/policies/tests/`) → `tests` |
| sync-wave | 아래 **§sync-wave 단일 표**가 정본(`-20` … `60`, 앱 `100`). 다른 곳에 wave 번호를 중복 기재하지 않는다 |
| syncPolicy | 플랫폼: `automated: { prune: false, selfHeal: true }`, syncOptions `ServerSideApply=true`, `CreateNamespace=true`, `Prune=confirm`, `Delete=confirm`, `SkipDryRunOnMissingResource=true`. dev 앱: prune·selfHeal true. prod 앱: automated이되 변경은 PR로만 |
| AppProject | `platform`: sourceRepos [gitops, 차트 저장소], destinations = 플랫폼 네임스페이스(network-policy.md 표), clusterResourceWhitelist(CRD·Namespace·ClusterRole…). `dev`/`prod`: 자기 네임스페이스만, cluster 리소스 금지, **`namespaceResourceBlacklist`: NetworkPolicy · ResourceQuota · LimitRange · Role · RoleBinding · ServiceAccount**(정책 객체는 `platform/policies/`만 쓴다). **`tests`**: sourceRepos = [gitops]만, destination = `jt-dev`만, cluster 리소스 금지 — `platform/policies/tests/`의 검증 Job 3종 전용(destination을 Application 한정으로 좁힐 수 없어 `platform`에 `jt-dev`를 넣지 않는다). `default`: sourceRepos·destinations 비움 |
| 삭제 보호 | `Cluster pg-main` · `Kafka jt-kafka` · `KafkaNodePool` · Vault/Dragonfly PVC · 모든 오퍼레이터 CRD(CNPG·Strimzi·cert-manager·ESO)에 `argocd.argoproj.io/sync-options: Delete=false,Prune=false` |
| 워크로드 강화 | 템플릿 pod·cloudflared·dragonfly Deployment: `automountServiceAccountToken: false` + securityContext(`runAsNonRoot`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile: RuntimeDefault`, `readOnlyRootFilesystem: true` + `/tmp` emptyDir). helm 차트 컴포넌트(Vault·External Secrets·Authentik·OpenFGA·Reloader)는 values에 securityContext 4항목(`runAsNonRoot`·`allowPrivilegeEscalation`·`capabilities.drop`·`seccompProfile`)을 명시한다 |

## sync-wave 단일 표

FR-010의 순서를 이 표 하나로만 표현한다. Argo CD는 wave N의 리소스가 Healthy가 된 뒤 N+1로 넘어가므로, 오퍼레이터와 그 오퍼레이터가 조정하는 CR은 다른 wave에 둔다.

| wave | 디렉터리(Application) | FR-010 단계 |
|---|---|---|
| `-20` | `argocd` | Argo CD 자기 관리(bootstrap을 인수) |
| `-10` | `policies` | CRD·namespaces·policies |
| `0` | `cert-manager` · `external-secrets` | cert-manager·ESO(둘 다 CRD 제공) |
| `10` | `vault` | Vault(시크릿 원천) |
| `15` | `secret-stores` | `ClusterSecretStore` 5개 — ESO CRD(0)와 Vault(10) 뒤. Vault·ESO가 불가하면 이 Application이 Degraded가 된다(wave 0의 ESO Application은 Healthy 유지 — health 격리가 분리의 효과). **root는 이 wave에서 기다리지 않는다**: root sync는 이 Application CR을 처음 만드는 operation에서만 실패하고 retry부터 `ApplyOutOfSyncOnly`가 이미 만들어진 CR을 건너뛰어 다음 wave로 진행하며, root **health**만 Degraded로 남는다(Argo CD v3.5.2 소스 판독, 2026-09-18 T045 G2 리뷰 — 라이브 미실측). 콜드 부트스트랩의 실제 대기 지점은 wave 10(Vault init 전 Progressing)이고 시드 순서는 런북 절차로 보장한다 |
| `18` | `secrets` | `secrets/<ns>/`의 플랫폼 ExternalSecret(T045 현재 범위 = cert-manager DNS 토큰 · cloudflared 터널 토큰 2장). 소비자(`cert-manager-issuers` 20 · `cloudflared` 60)보다 앞. **CA 미러 ExternalSecret은 여기 두지 않는다** — 원본 CA가 생긴 뒤인 40번 행 소유 |
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
- **prod 승격(사람이 PR을 열고 사람이 머지)**: `promote.yml`(workflow_dispatch, 입력 `pod`)이 dev digest를 읽어 **`gh attestation verify oci://ghcr.io/joshua92y/<pod>@<digest> --owner joshua92y`** 를 먼저 실행(실패 시 중단)한 뒤 `overlays/prod`의 digest를 바꾼 **브랜치 `promote/prod-<pod>-<sha7>`만 만든다**(워크플로의 `GITHUB_TOKEN` — App 토큰을 쓰지 않는다). **PR은 운영자가 연다**(제목 `promote(<pod>): <short-digest>`) — 워크플로는 PR을 여는 명령과 비교 링크를 출력한다. **auto-merge를 걸지 않는다** — 운영자가 렌더링 diff 코멘트를 확인하고 직접 머지한다(FR-038). 머지 → Argo sync. 롤백 = 해당 커밋 `git revert` PR.
  - **워크플로가 PR을 열지 않는 이유(T047 결정 2026-09-29)**: ①App 토큰으로 열면 작성자가 봇이라 아래 경로 lint(봇은 `overlays/dev`만)에 걸려 required check를 통과할 수 없다. lint를 prod까지 넓히면, App은 자기 PR에 auto-merge를 걸 수 있고 승인 수가 0이므로 **토큰 탈취 시 prod digest가 사람 없이 머지**된다. ②`GITHUB_TOKEN`으로 연 PR은 워크플로를 일으키지 않아 required check가 보고되지 않는다. → 브랜치까지만 자동, PR 작성자는 사람.
  - 따라서 **gitops 저장소에는 App 자격(시크릿)을 두지 않는다.** App 토큰을 쓰는 곳은 모노레포 `publish-pod.yml`(dev bump)뿐이다.
- ruleset(main): PR 필수 · required check `validate` · 0 approvals · **`bypass_actors: []`**(GitHub App 포함 누구도 bypass 없음).
- **`jt-ci[bot]` 경로 lint**(validate.yml): PR 작성자가 `jt-ci[bot]`이면 변경 파일은 `apps/*/overlays/dev/kustomization.yaml` 뿐이어야 하고, 그 안에서도 `images[].digest` 줄만 바뀌어야 한다. 다른 파일·다른 줄이 바뀌면 실패 — App 토큰이 탈취돼도 dev digest 외에는 못 바꾼다.
  - **이 보증의 전제 셋(T047)** — 하나라도 빠지면 봇이 같은 PR에서 검사를 끌 수 있다(`pull_request` 이벤트는 PR 쪽의 워크플로 파일과 스크립트로 돈다): ①**App에 `workflows` 권한이 없다** — GitHub이 워크플로 파일을 바꾸는 push를 거부한다(App 설정 · 운영자 확인 · VD) ②**경로 lint는 base ref(main)의 `tests/validate.sh`로 돈다** — PR이 스크립트를 고쳐도 main의 규칙으로 판정한다(`--only-author`) ③변경 파일 목록과 diff는 **merge-base ↔ head**로 계산한다(base가 main 끝보다 뒤처져도 main 쪽 변경이 섞이지 않는다).
  - 봇 로그인 목록의 정본은 `tests/validate.sh`의 `VALIDATE_BOT_AUTHORS` 기본값이다. 워크플로는 이 변수를 설정하지 않는다(설정하면 PR 쪽에서 목록을 바꿀 수 있다). 이 문서의 `jt-ci[bot]`은 설계 이름이고, **실제로 설치된 App은 `joshuatech-gitapp-1`**(봇 로그인 `joshuatech-gitapp-1[bot]` · `Workflows` 권한 No access — 운영자 확인 2026-09-29)이다. 목록에는 둘 다 있다.

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
| `k8s-data-ca` | **kubernetes** | `identity` · `jt-dev` · `jt-prod` | `eso-ca-reader` | `remoteNamespace: data`. Role(ns `data`): `secrets` `get/list/watch` `resourceNames: [pg-main-ca, jt-kafka-cluster-ca-cert]` + `selfsubjectrulesreviews` `create`(ESO 권한 자가 점검) ※ |

※ 이 Role 문면에는 실효가 없는 규칙이 섞여 있다(T045 설계 확인): `list`·`watch`는 `resourceNames`와 함께 쓰면 이름 없는 목록 요청에 매칭되지 않고, `selfsubjectrulesreviews`는 클러스터 스코프 리소스라 ns Role로 부여되지 않는다(`system:basic-user`가 이미 허용한다). 실효 권한은 두 Secret의 `get`뿐이다. 문면은 유지하고 매니페스트에 무효 근거를 주석으로 남기며, 정리는 실측(T045 VD) 뒤 converge에서 한다.

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
- `refreshInterval: 5m`(전 ExternalSecret 공통). `refreshPolicy: Periodic`을 함께 명시한다(ESO 2.10.0 CRD 기본값과 같지만 의도를 코드에 남긴다).
- `target.creationPolicy` 기본은 위 예시의 `Owner`다. **예외 — 운영자가 수동으로 만든 기존 Secret을 인수하는 ExternalSecret은 `creationPolicy: Orphan` + `deletionPolicy: Retain`**(T045: `cert-manager/cloudflare-dns-token` · `cloudflared/cloudflared-tunnel`). `Owner`는 Secret에 controller ownerReference를 심어 ExternalSecret이 지워지면 Secret이 가비지 컬렉션되고, `Retain`은 그 GC를 막지 못한다 — 소비자 중단이 운영자 잠금(터널)이나 조용한 갱신 실패(DNS-01)로 이어지는 Secret에는 쓰지 않는다. `Retain`·`Orphan`은 **잘못된 값의 덮어쓰기는 막지 않는다** — 값 동일성은 시드·되읽기·인수 전후 비교로 지킨다. Secret이 지워졌을 때의 재생성은 ESO·Vault가 정상일 때 다음 성공한 갱신에서 일어난다.
- 인수형 ExternalSecret은 `target.template.metadata: {}`를 선언한다(선언이 없으면 ESO가 ExternalSecret의 라벨·어노테이션 — Argo CD tracking 포함 — 을 Secret으로 복사한다). ExternalSecret에 붙이는 `argocd.argoproj.io/sync-options: Delete=false,Prune=false`는 **Argo CD의 삭제·prune만** 막는다(kubectl 삭제·ESO 동작과 무관).
- 인수 해제 절차(플랫폼 Application은 `prune: false`라 파일 revert만으로는 해제되지 않는다): revert PR 머지 → Git 제거가 Argo에 반영됐는지 확인 → `kubectl delete externalsecret` → Secret 잔존·UID·값 확인. 정본은 런북 `bootstrap.md` §3 T045 절.
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
7. **Workers 전용 경로 금지**: `apps/**`의 ExternalSecret `remoteRef.key`가 `(dev|prod)/(access|web)/` 접두로 시작하면 실패 — `SESSION_ENCRYPTION_KEY`·Access 서비스 토큰 secret은 Workers Secrets 전용이라 pod에 배포하지 않는다(FR-014; `vault-{env}` 정책이 `kv/data/{env}/*` 전체를 읽으므로 scope 검사 ②만으로는 못 막는다).

## validate.yml (required check `validate`)

1. `kustomize build`(모든 overlay·platform) → `kubeconform -strict -ignore-missing-schemas`(CRD 스키마는 datreeio 카탈로그).
2. `helm template`(helmCharts 사용 컴포넌트).
3. 시크릿·경계 검사: `gitleaks`, 위 **§validate.yml ExternalSecret 검사** 7항목, `images[].newTag` 금지, `platform/**` `image:` digest 부재 경고.
4. 정책 검사: `platform/policies` Namespace 목록 = contracts/network-policy.md 표(14개); ns마다 해당 공통 정책 세트 존재; 모든 egress `ipBlock` 규칙에 `ports` + `except` 4개(IMDS·RFC 1918 3종); helm values의 포트 ↔ 정책 포트 일치; LimitRange에 `default.cpu`·`max.cpu` 없음.
   - (T045 G1p) `allow-apiserver-webhook` 4장의 출발 ipBlock cidr 집합·포트가 §정책 세트의 webhook 행과 정확 일치(원본 파일 + kustomize 렌더 둘 다 — 렌더에서만 넓어지거나 나타나거나 사라지는 경우 포함).
   - (T045 G2) `ClusterSecretStore`: `platform/secret-stores/`에만 · `metadata.namespace` 없음 · 이름·provider 집합 = **§ClusterSecretStore 5개 표** · vault store는 `serviceAccountRef.namespace`(referent auth 금지 — 생략하면 로그인 없이 Ready=True/Valid가 되는 가짜 PASS)·`audiences: [vault]`·마운트·서버·kv 경로·store↔SA/role 매핑 · kubernetes store는 `auth.serviceAccount` 하나(audiences 없음)·`remoteNamespace: data`·`server.url`·`caProvider.namespace` 명시 · `conditions.namespaces` 집합 = 표(원본 + 렌더).
   - (T046) `platform/reloader` 렌더: ClusterRole·ClusterRoleBinding **0** · Deployment `reloader`(ns `reloader`) 첫 컨테이너의 `args`가 **정확히** `[--log-level=info, --namespaces=<§네임스페이스 platform/reloader/ 목록 + reloader, 사전순 쉼표 목록>, --reload-strategy=annotations]`(순서 포함 · 그 밖의 인자 0 · 제어 문자 0). **집합 비교가 아니라 목록 정확 일치인 이유**(2026-09-28 검증 실측): 값 없는 플래그(`--log-format` 등)가 앞에 오면 pflag가 뒤의 `--namespaces=…`를 그 플래그의 **값으로 삼켜** 감시 목록이 비고 전역 모드가 되며, 같은 플래그를 두 번 주면 목록이 **합쳐진다**(StringSlice) — 인자를 하나씩 세는 검사는 둘 다 통과시킨다. · 렌더 전체의 `Role`·`RoleBinding` ns 집합 = 같은 목록 · 모든 `RoleBinding`은 `roleRef.kind: Role` + `subjects` = `[ServiceAccount reloader/reloader]` 정확 일치 · `reloader-role` 4장의 `rules`가 서로 같고 와일드카드(`*`) 없음 · 모든 `RoleBinding`의 `roleRef`가 가리키는 Role은 **같은 ns에 렌더**돼 있다 · Reloader 이미지(저장소 = `ghcr.io/stakater/reloader`) 컨테이너는 렌더 전체에서 **정확히 1개**(`reloader/reloader`의 `containers[0]`, `command` 없음) · 렌더의 kind별 개수 = 차트 12(ServiceAccount 1 · Deployment 1 · Role 5 · RoleBinding 5). (VD-9 시험 대상 `jt-dev/vd9-probe`가 있던 2026-09-28 하루 동안은 Deployment가 하나 더 있었다 — 판정 PASS 뒤 gitops #32에서 제거했고 그 검사(`REL-probe`)도 함께 지웠다.)
   - (T046) **Application은 source를 덮어쓰지 않는다**: `clusters/oci-k3s/apps/*.yaml`과 `bootstrap/root-app.yaml`의 모든 Application(파일 + kustomize 렌더에 나타나는 것 포함)은 `spec.source`의 키가 `{repoURL, targetRevision, path}`뿐이고(`kustomize`·`helm`·`directory`·`plugin` 금지), `spec.sources`(multi-source)를 쓰지 않으며, `repoURL` = 이 저장소 · `targetRevision: main`이다. 이유: `spec.source.kustomize.patches` 같은 Application 수준 오버라이드는 **Argo가 적용하는 렌더를 validate가 빌드한 렌더와 다르게** 만든다 — 렌더를 보는 모든 검사(ExternalSecret · 정책 · ClusterSecretStore · Reloader)가 한꺼번에 무력해진다. 같은 효과를 내는 다른 두 경로도 금지한다(2026-09-28 검증 RB-1 · Argo CD v3.5.2 소스 판독 — 라이브 미실측): source 경로 안의 **`.argocd-source.yaml` · `.argocd-source-<앱 이름>.yaml`**(Argo가 Application source 파라미터를 덮어쓰는 파일) · Application `spec.sourceHydrator` · Application 최상위 **`operation`**(`operation.sync.source`·`revision`·`manifests`로 한 번의 동기화 source를 바꾼다 — Git에 선언하는 필드가 아니다). **이 목록이 Argo의 모든 우회 경로를 덮는다고 주장하지 않는다.** 남은 사각은 아래 형식별 정책(T047)으로 닫는다. 새 차트 저장소를 source로 직접 쓰는 컴포넌트가 생기면 이 줄을 먼저 고친다.
   - (T047) **형식별 정책 — Argo가 읽을 수 있는 형식마다 "검사한다" 또는 "금지한다"를 정한다**(완료 범위는 이 표다 — 표 밖의 형식이 발견되면 표에 행을 더한다):

     | 형식 · 위치 | 정책 | 이유 |
     |---|---|---|
     | `*.yaml`·`*.yml`의 최상위 문서 | 검사한다(기존 7.1 · 2 · 7.4) | — |
     | kustomize 렌더에 나타나는 Application | 검사한다(7.4 — 렌더는 `List`를 풀어 낸다) | — |
     | **`kind: List`**(어느 apiVersion이든) — `--root` 트리의 모든 YAML | **금지** | 파일 단위 추출은 최상위 문서의 kind만 본다. Argo directory source와 kustomize는 List를 풀어 적용하므로 그 안의 Application·RBAC이 검사를 지나간다 |
     | **`*.json` · `*.jsonnet` · `*.libsonnet`** — Argo가 디렉터리째 읽는 경로(kustomization이 없는 Application `spec.source.path` — 오늘은 `clusters/oci-k3s/apps`) | **금지** | 파일 열거는 YAML뿐인데 Argo directory source는 셋 다 읽는다. 저장소 전체가 아니라 이 경로로 한정한다(`.github/ruleset-main.json` 같은 정상 파일이 있다) |
     | kustomization의 `resources`·`patches` 등이 가리키는 `*.json` | 검사한다(렌더에 나타난다) | 렌더 기반 검사가 본다 |
     | **`kind: ApplicationSet`** — 파일 + 렌더 | **금지** | template이 만드는 Application은 Git에 없어 검사할 수 없다. 쓰게 되면 계약을 먼저 고친다 |
     | kustomization이 없는 directory source 경로의 하위 디렉터리 | **금지**(파일은 그 경로 바로 아래에만) | `directory.recurse`는 7.4가 금지하므로 하위 디렉터리의 파일은 적용되지 않는 죽은 선언이다 |
   - (T047) **차트 저장소 허용 목록**: 모든 kustomization의 `helmCharts[].repo`는 아래 표의 값과 정확히 일치한다(이름·저장소 쌍). kustomize의 `helmCharts` 인플레이트는 AppProject `sourceRepos`의 통제 밖이라(T042·T044·T045·T046에서 `sourceRepos` 줄을 네 번 지웠다) **이 표가 차트 출처의 유일한 통제**다. 새 차트는 표에 행을 더하는 계약 변경으로 시작한다. `helmGlobals`·`helmChartInflationGenerator`(레거시 생성기)는 금지한다.

     | 차트 `name` | `repo` | 쓰는 곳 |
     |---|---|---|
     | `cert-manager` | `oci://quay.io/jetstack/charts` | `platform/cert-manager` |
     | `external-secrets` | `https://charts.external-secrets.io` | `platform/external-secrets` |
     | `reloader` | `https://stakater.github.io/stakater-charts` | `platform/reloader` |
     | `vault` | `https://helm.releases.hashicorp.com` | `platform/vault` |
   - (T047) **`helmCharts`를 쓰는 kustomization이 하나라도 있으면** `bootstrap/argocd`의 `argocd-cm` `kustomize.buildOptions`에 `--enable-helm`이 있어야 한다(없으면 Argo가 그 컴포넌트를 렌더하지 못한다).
   - (T047) **권한 경계 — 문자열이 아니라 규칙 구조로 본다**(전 kustomization 렌더를 합쳐서 · 2026-09-29 main `82dd85e` 실측값이 기준선):
     - **ServiceAccount 토큰 발급**: `apiGroups`에 `""` 또는 `*`, `verbs`에 `create` 또는 `*`, `resources`에 `serviceaccounts/token` · `serviceaccounts/*` · `*` · `*/*` 중 하나가 든 규칙을 가진 Role·ClusterRole은 **정확히 둘**이다 — ①ClusterRole `argocd-application-controller`(`*/*/*` — GitOps 컨트롤러의 고유 권한, 받아들인 위험) ②Role `external-secrets/eso-token-create`(`resourceNames` = `eso-platform`·`eso-dev`·`eso-prod`·`eso-data`·`eso-ca-reader` 정확히). 셋째가 생기거나 ②의 `resourceNames`가 달라지면 실패.
     - **렌더에 없는 ClusterRole을 가리키는 바인딩**(내장 역할 등 — validate가 규칙을 볼 수 없다)은 **정확히 둘**이다 — `agent-view-view` → `view` · `vault-server-binding` → `system:auth-delegator`. `cluster-admin`·`admin`·`edit`를 비롯해 그 밖의 이름은 실패.
     - **Reloader 주체**: `subjects`에 `ServiceAccount reloader/reloader`가 들었거나 그 계정을 포함하는 그룹(`system:serviceaccounts` · `system:serviceaccounts:reloader` · `system:authenticated` · `system:unauthenticated`)이 든 RoleBinding·ClusterRoleBinding은 `platform/reloader` 렌더의 **5장뿐**이다(다른 컴포넌트 렌더가 Reloader에게 Secret 읽기 권한을 주는 경로를 막는다). 위 네 그룹을 주체로 한 바인딩은 어느 렌더에도 없다.
     - `aggregationRule`을 가진 ClusterRole은 금지한다(오늘 0개 — 합쳐진 결과 규칙은 렌더에 없어 볼 수 없다). 반대 방향인 `rbac.authorization.k8s.io/aggregate-to-*` **라벨**을 가진 ClusterRole(오늘 12개 — cert-manager · external-secrets 차트가 내장 `view`·`edit`·`admin`을 넓힌다)은 허용한다: 그 규칙도 위 토큰 발급 판정의 대상이므로 내장 역할을 통해 토큰 발급이 새는 경로는 잡힌다.
     - **보지 않는 것**: 내장 역할이 라벨 집계로 얼마나 넓어졌는지(토큰 발급 외) · `escalate`·`bind`·`impersonate` 동사를 통한 권한 상승 · 차트가 런타임에 만드는 RBAC · 클러스터에 손으로 만든 객체.
   - (T045 G4) **배달자는 base를 묶기만 한다**: `platform/secrets/kustomization.yaml`의 최상위 키는 `{apiVersion, kind, resources}`뿐이고, `secrets/<ns>/kustomization.yaml`은 거기에 `namespace`까지만 허용한다(`patches`·`replacements`·`transformers`·`namePrefix`·`helmCharts` 등 변환 키 금지). 이유: scope ↔ 위치 검사(§ExternalSecret 검사 2)는 원본 위치로 판정하므로, 변환 키가 있으면 원본은 그대로인 채 **Argo가 실제로 적용하는 렌더에서만** store·`remoteRef`·`creationPolicy`가 바뀐다 — 그 렌더에 터널 자격(`cloudflared/cloudflared-tunnel`)이 있다. 같은 이유로 `platform/secrets` 렌더에도 `secrets/**` 위치 규칙(`platform/` 접두 + `vault-platform`)을 적용한다.
5. 작성자 검사: PR 작성자가 `jt-ci[bot]`이면 변경 파일 = `apps/*/overlays/dev/kustomization.yaml`, 변경 줄 = `images[].digest`뿐.
6. sync-wave 검사: 모든 Application의 `argocd.argoproj.io/sync-wave` 값이 **§sync-wave 단일 표**와 일치하고, 표에 없는 `platform/<component>/` 디렉터리가 없다.
7. 렌더링 diff 코멘트: `kustomize build` 결과를 main과 PR에서 비교해 PR 코멘트로 남긴다(Argo CD 접근 불필요; `argocd app diff`는 쓰지 않음).
   - (T047) **별도 job**(`render-diff`)이다 — required check가 아니다(코멘트 실패가 머지를 막지 않는다 · 판정은 `validate`가 한다). `pull-requests: write` 권한은 **이 job에만** 준다(`validate` job은 `contents: read` 그대로). 포크에서 온 PR은 토큰이 읽기 전용이라 코멘트를 달 수 없으므로 건너뛰고 같은 내용을 job 요약에 남긴다. `pull_request_target`은 쓰지 않는다.
   - 대상은 `--root` 트리의 모든 kustomization 디렉터리(`tests/`·`charts/` 제외)와 directory source 경로(`clusters/oci-k3s/apps`)의 파일이다. 코멘트는 PR마다 하나를 갱신한다(새로 쌓지 않는다). 길이 한도를 넘으면 컴포넌트별 요약(바뀐 객체의 kind/이름 · 줄 수)만 남기고 전문은 job 아티팩트로 올린다.
   - 승격 PR(§이미지·승격)에서 운영자가 확인하는 것이 이 코멘트다 — 코멘트가 없거나 실패했으면 머지하지 않는다(PR 템플릿의 확인 항목).

### validate.yml의 실행 구조 (T047)

- job `validate`(required): 도구 설치(yq · kustomize · kubeconform · gitleaks · **helm** — 버전 고정 + sha256 대조, arm64) → **경로 lint(base ref 스크립트 · `--only-author`)** → 전체 검사(`tests/validate.sh`, PR 쪽 스크립트) → gitleaks(히스토리). `VALIDATE_SKIP_TOOLS`는 CI에서 설정하지 않는다(SKIP만 남아도 exit 0이 된다).
- 자기검사(`tests/validate.tests.sh`)를 CI에서 언제 돌릴지는 러너 시간 실측 뒤 정한다(VD — T047 G2). 돌릴 때는 `CI=true`라 부분 실행이 거부되고 도구 누락이 실패다 — helm도 도구 게이트에 포함한다.
- job 이름 `validate`는 ruleset의 required check 이름이다 — 바꾸지 않는다.

## 변경 권한

- 사람은 PR로만 main에 쓴다(ruleset). GitHub App(`jt-ci`)도 PR로만 쓴다 — bypass 주체 없음. App이 auto-merge를 거는 것은 **dev digest bump PR뿐**이고(VD-5), prod 승격 PR은 사람이 머지한다.
- `platform/`·`clusters/` 변경은 approval-review의 `k8s-security` 경계 대상(모노레포 spec에서 링크). 비가역 변경 파일(오퍼레이터 버전·`metadataVersion`·PG major·Authentik 차트) PR 템플릿에는 스냅샷 3종(Vault raft·CNPG 백업·K3s SQLite) 확인 체크박스가 있다.
