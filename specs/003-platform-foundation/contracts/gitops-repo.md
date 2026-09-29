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
  - (T047) 항목마다 **`name`과 `digest`(`sha256:` + 64자리 소문자 hex)가 있어야 하고**, 키는 `{name, newName, digest}` 밖에 없어야 한다. `digest`가 없는 항목은 이미지 고정이 풀린 것이다 — `newTag` 금지만으로는 "아무것도 고정하지 않은 항목"이 통과한다(T047 G1 리뷰: 봇이 digest 줄을 지우면 빌드는 성공하고 이미지는 고정 없는 이름이 된다 — 봇 쪽은 경로 lint의 제자리 교체 규칙이 막고, 사람 PR 쪽은 이 검사가 막는다).
- `platform/` 이미지(cloudflared·dragonfly·helm values의 `image:`)는 태그에 `@sha256:…`을 병기한다. validate.yml이 digest 없는 `image:` 줄을 **경고**한다(Renovate `pinDigests`가 못 미치는 곳은 수동).
- **dev bump(자동 머지)**: 모노레포 `publish-pod.yml`이 GitHub App 토큰으로 브랜치 **`bump/dev-<pod>-<sha7>`** 을 만들고 `overlays/dev` digest를 바꾼 PR(메시지 `chore(<pod>): dev → <short-digest>`)을 열어 `gh pr merge --auto --squash`를 건다 — required check `validate` 통과 뒤 자동 머지. main 직접 push 없음.
  - **VD-5(검증 후 결정)**: 기본 가정은 "public repo Free에서 `gh pr merge --auto`와 Environment `production`이 동작한다"(저장소 설정 **Allow auto-merge 활성** 필요, T003 수동 목록). 옵션 A = 동작하면 위 자동 머지 경로, 옵션 B = 동작하지 않으면 dev bump도 **사람 머지**로 내린다. T003·T074의 첫 PR에서 실측해 확정하고 결과를 `report.md`에 남긴다. 어느 쪽이든 아래 `jt-ci[bot]` 경로 lint는 유지한다.
- **prod 승격(사람이 PR을 열고 사람이 머지)**: `promote.yml`(workflow_dispatch, 입력 `pod`)이 dev digest를 읽어 **`gh attestation verify oci://ghcr.io/joshua92y/<pod>@<digest> --owner joshua92y`** 를 먼저 실행(실패 시 중단)한 뒤 `overlays/prod`의 digest를 바꾼 **브랜치 `promote/prod-<pod>-<sha7>`만 만든다**(워크플로의 `GITHUB_TOKEN` — App 토큰을 쓰지 않는다). **PR은 운영자가 연다**(제목 `promote(<pod>): <short-digest>`) — 워크플로는 PR을 여는 명령과 비교 링크를 출력한다. **auto-merge를 걸지 않는다** — 운영자가 렌더링 diff 코멘트를 확인하고 직접 머지한다(FR-038). 머지 → Argo sync. 롤백 = 해당 커밋 `git revert` PR.
  - **워크플로가 PR을 열지 않는 이유(T047 결정 2026-09-29)**: ①App 토큰으로 열면 작성자가 봇이라 아래 경로 lint(봇은 `overlays/dev`만)에 걸려 required check를 통과할 수 없다. lint를 prod까지 넓히면, App은 자기 PR에 auto-merge를 걸 수 있고 승인 수가 0이므로 **토큰 탈취 시 prod digest가 사람 없이 머지**된다. ②`GITHUB_TOKEN`으로는 PR을 열 수 없다 — 저장소 설정 "Allow GitHub Actions to create and approve pull requests"가 꺼져 있다(2026-09-29 조회 `can_approve_pull_request_reviews: false`). 켜더라도 그렇게 연 PR의 워크플로 실행은 **승인 대기** 상태로 만들어져, 쓰기 권한 사용자가 승인해야 검사가 돈다(GitHub 2026-06-11 변경 — 그 전에는 실행 자체가 만들어지지 않았다. 처음 이 항목을 쓸 때는 옛 동작을 근거로 적었다 — 2026-09-29 정정). → 브랜치까지만 자동, PR 작성자는 사람.
  - 따라서 **gitops 저장소에는 App 자격(시크릿)을 두지 않는다.** App 토큰을 쓰는 곳은 모노레포 `publish-pod.yml`(dev bump)뿐이다.
  - **이 형태는 임시다(사용자 확인 2026-09-29).** 목표는 FR-038의 문면 그대로 — **봇이 승격 PR을 만들고 검증은 전부 자동, 사람은 prod 승인과 예외 처리만** — 이다. 거기로 가려면 **봇이 통과시킬 수 없는 승인 관문**이 required check 안에 있어야 한다(후보: GitHub Environment의 필수 검토자 — PR이 prod 경로를 건드리면 검사 job이 운영자 승인을 기다린다). 공개 저장소 무료 플랜에서의 동작은 VD-5의 실측 대상이다. T047 G5에서 실측해 **동작하면 목표 형태로 구현하고 이 항목을 고치며, 동작하지 않으면 이 임시 형태를 유지하고 `report.md`에 FR-038 대비 편차로 기록**한다. 위 경로 lint · ruleset · 브랜치 쓰기 제한은 어느 형태에서도 그대로 필요하다.
- ruleset(main): PR 필수 · required check `validate`(strict — 브랜치가 최신이어야 머지 · 출처는 GitHub Actions로 고정 `integration_id: 15368`) · 0 approvals · **`bypass_actors: []`**(GitHub App 포함 누구도 bypass 없음) · **선형 이력 필수(`required_linear_history`)** · **머지 방식은 squash만**(`allowed_merge_methods: ["squash"]`).
  - 선형 이력과 squash 전용의 이유(T047 결정 2026-09-29): auto-merge의 방식은 거는 쪽이 고른다. main에 머지 커밋이 들어오면 이력이 교차할 수 있고, 교차한 이력에서는 merge-base가 둘 이상이 되어 경로 lint의 diff 기준이 흔들린다(아래 판정 규칙 ①이 스크립트 쪽에서 같은 것을 막는다 — 이중 방어). 2026-09-29까지의 머지 33건은 전부 squash였다.
  - 선언(`.github/ruleset-main.json`)을 PR로 고친 뒤 **운영자가 적용한다**(`gh api -X PUT repos/joshua92y/platform-gitops/rulesets/<id> --input .github/ruleset-main.json`) — 파일을 고치는 것만으로는 적용되지 않는다. 적용 뒤 원격 값과 파일을 대조한다.
- **`jt-ci[bot]` 경로 lint**(validate.yml): PR 작성자가 `jt-ci[bot]`이면 변경 파일은 `apps/*/overlays/dev/kustomization.yaml` 뿐이어야 하고, 그 안에서도 `images[].digest` 줄만 바뀌어야 한다. 다른 파일·다른 줄이 바뀌면 실패 — App 토큰이 탈취돼도 dev digest 외에는 못 바꾼다.
  - **이 보증의 전제 셋(T047)** — 하나라도 빠지면 봇이 같은 PR에서 검사를 끌 수 있다(`pull_request` 이벤트는 PR 쪽의 워크플로 파일과 스크립트로 돈다): ①**App에 `workflows` 권한이 없다** — GitHub이 워크플로 파일을 바꾸는 push를 거부한다(App 설정 · 운영자 확인 · VD) ②**경로 lint는 main 브랜치의 `tests/validate.sh`로 돈다** — PR이 스크립트를 고쳐도 main의 규칙으로 판정한다(`--only-author`). **"main"은 러너가 가져온 `origin/main`의 끝이다 — `pull_request.base.sha`가 아니다**(아래 ④) ③변경 파일 목록과 diff는 **merge-base ↔ head**로 계산한다(base가 main 끝보다 뒤처져도 main 쪽 변경이 섞이지 않는다) — 기준 커밋도 `origin/main`의 끝이다.
  - **④ PR의 base는 봇이 고른다(T047 G2 리뷰 2026-09-29 — 실험으로 재현)**: 봇은 `bump/**`에 임의 내용을 쓸 수 있으므로, 검사 스크립트를 무력화한 브랜치를 **base로** 잡은 PR을 열 수 있다. 워크플로가 `pull_request.base.sha`의 스크립트를 쓰면 그 PR에서는 봇의 스크립트가 "base 스크립트"로 돌아 통과하고, 성공한 check는 **head 커밋에 붙으므로** 같은 head를 main으로 향하게 하면(PR의 base를 바꾸거나 PR을 하나 더 연다) required check가 채워진다. 그래서 ⓐ워크플로는 **base가 main인 PR에서만** 돈다(`on.pull_request.branches: [main]`) ⓑ경로 lint는 PR의 base ref가 `main`이 아니면 실패하고, `pull_request.base.sha`가 `origin/main`의 조상(또는 같은 커밋)이 아니면 실패한다 ⓒ스크립트와 diff 기준은 `origin/main`의 끝에서 가져온다.
  - **⑤ required check는 출처를 고정한다**: ruleset의 required check `validate`에 `integration_id`(GitHub Actions = `15368`)를 준다 — 이름만 같으면 어떤 App의 check·status든 조건을 채우는 것을 막는다.
  - **경로 lint의 판정 규칙(T047 G1 리뷰 2026-09-29 — 실험으로 확인한 우회 경로를 닫는다)**: ①merge-base는 **정확히 하나**여야 한다(`git merge-base --all`이 둘 이상이면 실패 — 이력이 교차(criss-cross)하면 git이 그중 하나를 골라 주는데, 봇이 head를 "골라진 쪽 + digest 한 줄"로 만들면 diff는 깨끗하고 실제 머지 결과는 다른 파일을 바꾼다) ②변경은 **제자리 교체**뿐이다 — 삭제 줄(`-`) 하나 바로 뒤에 추가 줄(`+`) 하나가 오는 쌍만 허용하고, 쌍의 두 줄은 **64자리 hex 값 밖이 글자 단위로 같아야** 한다(digest 줄을 지우기만 하거나, 다른 images 항목으로 옮기거나, 끼워 넣거나, `    digest:`를 `  - digest:`로 바꿔 새 항목을 만드는 것은 줄 형식이 맞아도 실패 — dev bump 도구는 값만 바꾸고 들여쓰기·공백을 건드리지 않는다) ③hunk 안에서는 `---`·`+++`로 시작하는 줄도 **내용**으로 검사한다(내용이 `++ `로 시작하는 추가 줄은 diff에서 파일 머리줄과 같은 모양이 된다) ④diff는 저장소 내용이 출력 형식을 바꾸지 못하게 옵션을 고정한다(`--no-ext-diff` · `--no-textconv` · `--no-renames` · `--ignore-submodules=none` · `--no-color`).
  - **봇 판정은 로그인과 계정 ID 둘 다로 한다**: 로그인 비교는 대소문자를 가리지 않고, 계정 ID(`joshuatech-gitapp-1[bot]` = `323873425`)가 목록에 있으면 로그인이 무엇이든 봇이다. App 이름을 바꾸면 로그인(`<slug>[bot]`)은 바뀌지만 ID는 그대로다 — 로그인만 보면 이름을 바꾼 순간 봇 PR이 사람 PR로 취급돼 제한이 조용히 풀린다. 워크플로는 `pull_request.user.login`과 `pull_request.user.id`를 함께 넘긴다.
  - **봇 판정의 대상은 PR 작성자와 이벤트 발신자 둘 다다(T047 결정 2026-09-29)**: PR을 연 계정(`pull_request.user`)이 사람이어도, 그 이벤트를 일으킨 계정(`sender` — push한 쪽 · 다시 연 쪽)이 봇이면 봇 규칙을 적용한다. 이유: App은 저장소에 쓰기 권한이 있어 **사람이 연 PR의 브랜치에 커밋을 push하고 머지할 수 있다**(승인 수 0 · 머지 API와 auto-merge 둘 다). 작성자만 보면 그 PR은 사람 PR이라 제한 없이 통과한다. PR 이벤트에서 발신자 입력이 비면 실패한다(조용한 비활성 금지). 남는 빈틈 — PR이 열리기 **전에** 봇이 그 브랜치에 넣은 커밋 — 은 아래 브랜치 쓰기 제한이 막는다.
  - 봇 로그인 목록의 정본은 `tests/validate.sh`의 `VALIDATE_BOT_AUTHORS` 기본값이다(ID 목록은 `VALIDATE_BOT_IDS`).
- **ruleset(branches) — App이 쓸 수 있는 브랜치를 한정한다(T047 결정 2026-09-29)**: 대상은 main과 `bump/**`를 **뺀** 모든 브랜치, 규칙은 생성·갱신·삭제 제한, bypass는 저장소 관리자 역할뿐이다(선언 `.github/ruleset-branches.json`). 결과: App(과 워크플로의 `GITHUB_TOKEN`)은 `bump/**`만 만들고 고칠 수 있고, 사람이 작업하는 브랜치에는 push하지 못한다. main은 ruleset(main)이 따로 맡는다(이 ruleset에 main을 넣으면 봇의 dev bump 머지가 "갱신 제한"에 걸린다). 새 자동화가 브랜치를 만들어야 하면(승격 브랜치 · Renovate 등) 이 예외 목록에 패턴을 더하는 계약 변경으로 시작한다.
  - **실측 범위**: 관리자의 push가 통과하는 것과 브랜치별 적용 규칙은 적용 직후 확인한다. **App 토큰의 push가 실제로 거부되는 것**은 App 키가 필요하므로 T074(첫 dev bump) · T115(승격 실연)에서 증거를 남긴다 — 그때까지는 "설정으로 확인 · 거부는 미실측"이다. 워크플로는 이 변수를 설정하지 않는다(설정하면 PR 쪽에서 목록을 바꿀 수 있다). 이 문서의 `jt-ci[bot]`은 설계 이름이고, **실제로 설치된 App은 `joshuatech-gitapp-1`**(봇 로그인 `joshuatech-gitapp-1[bot]` · `Workflows` 권한 No access — 운영자 확인 2026-09-29)이다. 목록에는 둘 다 있다.

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
     | **목록 객체** — `kind: List`(어느 apiVersion이든)와 `<Kind>List`(이름이 `List`로 끝나고 최상위 `items`가 목록인 문서) — `--root` 트리의 모든 YAML | **금지** | 파일 단위 추출은 최상위 문서의 kind만 본다. Argo directory source와 kustomize는 List를 풀어 적용하므로 그 안의 Application·RBAC이 검사를 지나간다 |
     | **`*.json` · `*.jsonnet` · `*.libsonnet`** — Argo가 디렉터리째 읽는 경로(kustomization이 없는 Application `spec.source.path` — 오늘은 `clusters/oci-k3s/apps`) | **금지** | 파일 열거는 YAML뿐인데 Argo directory source는 셋 다 읽는다. 저장소 전체가 아니라 이 경로로 한정한다(`.github/ruleset-main.json` 같은 정상 파일이 있다) |
     | kustomization의 `resources`·`patches` 등이 가리키는 `*.json` | 검사한다(렌더에 나타난다) | 렌더 기반 검사가 본다 |
     | **`kind: ApplicationSet`** — 파일 + 렌더 | **금지** | template이 만드는 Application은 Git에 없어 검사할 수 없다. 쓰게 되면 계약을 먼저 고친다 |
     | kustomization이 없는 directory source 경로의 하위 디렉터리 | **금지**(파일은 그 경로 바로 아래에만) | `directory.recurse`는 7.4가 금지하므로 하위 디렉터리의 파일은 적용되지 않는 죽은 선언이다 |
     | directory source 경로의 YAML 문서의 kind | **`Application`(`argoproj.io/…`)뿐** — 그 밖의 kind 금지 | 이 경로의 파일은 Argo가 렌더 없이 그대로 적용한다. 렌더를 보는 검사(Reloader · 권한 경계 등)는 이 파일들을 보지 못하고, root Application의 프로젝트(`platform`)는 ClusterRole·ClusterRoleBinding과 목적지 ns의 모든 namespaced kind를 허용한다 — 여기에 둔 Role·바인딩은 검사를 지나 적용된다(2026-09-29 실측 — 문서 21개 전부 Application) |
   - (T047) **차트 저장소 허용 목록**: 모든 kustomization의 `helmCharts[].repo`는 아래 표의 값과 정확히 일치한다(이름·저장소 쌍). kustomize의 `helmCharts` 인플레이트는 AppProject `sourceRepos`의 통제 밖이라(T042·T044·T045·T046에서 `sourceRepos` 줄을 네 번 지웠다) **이 표가 차트 출처의 유일한 통제**다. 새 차트는 표에 행을 더하는 계약 변경으로 시작한다. 항목마다 `version`이 있어야 한다(없으면 그때의 최신을 받는다 — 값 자체는 표로 고정하지 않는다: 차트 올림은 계약 변경이 아니다). `repo`가 없는 항목(로컬 차트)과 `helmGlobals`·`helmChartInflationGenerator`(레거시 생성기)는 금지한다.

     | 차트 `name` | `repo` | 쓰는 곳 |
     |---|---|---|
     | `cert-manager` | `oci://quay.io/jetstack/charts` | `platform/cert-manager` |
     | `external-secrets` | `https://charts.external-secrets.io` | `platform/external-secrets` |
     | `reloader` | `https://stakater.github.io/stakater-charts` | `platform/reloader` |
     | `vault` | `https://helm.releases.hashicorp.com` | `platform/vault` |
   - (T047) **`charts/`라는 이름의 디렉터리는 helm 인플레이트 캐시 전용이다**: `helmCharts`를 쓰는 kustomization 디렉터리 **바로 아래**에만 있을 수 있다(거기는 `.gitignore` 대상인 빌드 산출물이다). 그 밖의 위치에 `charts` 디렉터리가 있으면 실패 — 파일 열거와 7.4의 파일 찾기는 경로에 `/charts/`가 든 곳을 통째로 건너뛰므로, 이름이 `charts`인 pod(`apps/charts/…`)나 컴포넌트는 모든 검사의 시야 밖으로 빠진다.
   - (T047) **`helmCharts`를 쓰는 kustomization이 하나라도 있으면** `bootstrap/argocd`의 `argocd-cm` `kustomize.buildOptions`에 `--enable-helm`이 있어야 한다(없으면 Argo가 그 컴포넌트를 렌더하지 못한다).
   - (T047) **권한 경계 — 문자열이 아니라 규칙 구조로 본다**(전 kustomization 렌더를 합쳐서 · 2026-09-29 main `82dd85e` 실측값이 기준선):
     - **ServiceAccount 토큰 발급**: `apiGroups`에 `""` 또는 `*`, `verbs`에 `create` 또는 `*`, `resources`에 `serviceaccounts/token` · `serviceaccounts/*` · `*` · `*/*` 중 하나가 든 규칙("토큰 발급 규칙")을 가진 Role·ClusterRole은 **정확히 둘**이다 — ①ClusterRole `argocd-application-controller`(`*/*/*` — GitOps 컨트롤러의 고유 권한, 받아들인 위험) ②Role `external-secrets/eso-token-create` — 토큰 발급 규칙이 **하나**이고 그 규칙은 `apiGroups: [""]` · `resources: [serviceaccounts/token]` · `verbs: [create]` · `resourceNames` = `eso-platform`·`eso-dev`·`eso-prod`·`eso-data`·`eso-ca-reader`(집합 정확 일치)다. 셋째가 생기거나 ②의 모양이 달라지면 실패. 같은 이름이 여러 렌더에 나타나면 **나타난 것마다** 판정한다(다른 컴포넌트가 같은 이름으로 넓은 규칙을 정의하는 경로).
     - **렌더에 없는 역할을 가리키는 바인딩**(내장 역할 등 — validate가 규칙을 볼 수 없다): `roleRef`가 ClusterRole이고 그 이름의 ClusterRole이 어느 렌더에도 없는 바인딩은 **정확히 둘**이다 — ClusterRoleBinding `agent-view-view` → `view` · ClusterRoleBinding `vault-server-binding` → `system:auth-delegator`. `cluster-admin`·`admin`·`edit`를 비롯해 그 밖의 이름은 실패. `roleRef`가 Role이면 **같은 ns의 그 Role이 렌더돼** 있어야 한다(2026-09-29 실측 — 어긋난 것 0). ClusterRoleBinding이 Role을 가리키는 것과 `roleRef.kind`가 둘 밖인 것도 실패.
     - **내장 역할의 이름으로 역할을 정의하지 않는다**: 렌더된 ClusterRole의 이름이 `cluster-admin` · `admin` · `edit` · `view`이거나 `system:`으로 시작하면 실패(오늘 0). 위 판정은 "그 이름이 렌더에 있는가"로 내장 역할을 가려내므로, 같은 이름의 ClusterRole을 함께 렌더하면 내장 역할에 거는 바인딩이 "렌더된 역할"로 읽힌다 — 그 경로를 닫는다.
     - **주체는 이름을 다 적은 ServiceAccount뿐이다**: 모든 바인딩의 `subjects` 항목은 `kind: ServiceAccount`이고 `name`·`namespace`가 비어 있지 않다(2026-09-29 실측 — 바인딩 40장의 주체 40개 전부). `User`·`Group` 주체는 실패 — 계정을 포함하는 그룹(`system:serviceaccounts` · `system:serviceaccounts:<ns>` · `system:authenticated` · `system:unauthenticated`)이나 계정의 사용자 이름 표기(`User` `system:serviceaccount:<ns>:<name>`)로 같은 권한을 주는 경로를 닫는다. `namespace`를 비운 ServiceAccount 주체도 실패(RoleBinding에서는 API 서버가 바인딩의 ns로 채워 읽는다 — 렌더의 글자만으로는 누구인지 드러나지 않는다). 사람·그룹 주체가 필요해지면(OIDC 관리자 등 — T084) 계약에 행을 더한다.
     - **Reloader 주체**: `subjects`에 `ServiceAccount reloader/reloader`가 든 RoleBinding·ClusterRoleBinding은 `platform/reloader` 렌더의 **5장뿐**이다(다른 컴포넌트 렌더가 Reloader에게 Secret 읽기 권한을 주는 경로를 막는다 — 그 5장의 모양은 위 (T046) 줄이 본다).
     - **역할 집계**: `aggregationRule`을 가진 ClusterRole은 금지한다(오늘 0개 — 합쳐진 결과 규칙은 렌더에 없어 볼 수 없다). 반대 방향인 `rbac.authorization.k8s.io/aggregate-to-*` **라벨**을 가진 ClusterRole은 **정확히 다섯**이다(라벨 수로는 12 — 차트가 내장 `view`·`edit`·`admin`을 넓힌다): `cert-manager-cluster-view` · `cert-manager-edit` · `cert-manager-view` · `external-secrets-edit` · `external-secrets-view`. 여섯째가 생기면 실패 — `agent-view-view`가 내장 `view`에 걸려 있으므로, 새 ClusterRole이 `aggregate-to-view` 라벨로 Secret 읽기를 더하면 에이전트의 읽기 전용 자격이 Secret을 읽게 된다. 이 다섯의 규칙도 위 토큰 발급 판정의 대상이다.
     - **완전성은 저장소 루트에서만 요구한다**: 위 "정확히 N"은 `--root`가 저장소 루트일 때의 기준이다. 부분 트리(픽스처)에서는 기준선 **밖의 것이 없는가**만 본다.
     - **보지 않는 것**: 기준선의 다섯 ClusterRole을 통해 내장 역할이 얼마나 넓어졌는지(토큰 발급 외 — 차트 올림으로 규칙이 바뀌는 것 포함) · **`secrets` 생성 권한으로 `kubernetes.io/service-account-token` 형식의 Secret을 만들어 토큰을 얻는 경로**(2026-09-29 실측 — 그 권한을 가진 규칙 8개: Argo CD · cert-manager · external-secrets 컨트롤러. Secret을 만드는 것이 본업이라 기준선으로 고정하지 않았다 — converge로 넘긴다) · `escalate`·`bind`·`impersonate` 동사를 통한 권한 상승(오늘 `argocd-application-controller`의 `*`뿐) · 차트가 런타임에 만드는 RBAC · 클러스터에 손으로 만든 객체. Argo가 적용하지 않는 렌더(pod의 `base` 등)도 합쳐서 본다 — 넓게 잡는 쪽이다.
   - (T045 G4) **배달자는 base를 묶기만 한다**: `platform/secrets/kustomization.yaml`의 최상위 키는 `{apiVersion, kind, resources}`뿐이고, `secrets/<ns>/kustomization.yaml`은 거기에 `namespace`까지만 허용한다(`patches`·`replacements`·`transformers`·`namePrefix`·`helmCharts` 등 변환 키 금지). 이유: scope ↔ 위치 검사(§ExternalSecret 검사 2)는 원본 위치로 판정하므로, 변환 키가 있으면 원본은 그대로인 채 **Argo가 실제로 적용하는 렌더에서만** store·`remoteRef`·`creationPolicy`가 바뀐다 — 그 렌더에 터널 자격(`cloudflared/cloudflared-tunnel`)이 있다. 같은 이유로 `platform/secrets` 렌더에도 `secrets/**` 위치 규칙(`platform/` 접두 + `vault-platform`)을 적용한다.
5. 작성자 검사: PR 작성자가 `jt-ci[bot]`이면 변경 파일 = `apps/*/overlays/dev/kustomization.yaml`, 변경 줄 = `images[].digest`뿐.
6. sync-wave 검사: 모든 Application의 `argocd.argoproj.io/sync-wave` 값이 **§sync-wave 단일 표**와 일치하고, 표에 없는 `platform/<component>/` 디렉터리가 없다.
7. 렌더링 diff 코멘트: `kustomize build` 결과를 main과 PR에서 비교해 PR 코멘트로 남긴다(Argo CD 접근 불필요; `argocd app diff`는 쓰지 않음).
   - (T047) **별도 job 둘**이다 — required check가 아니다(코멘트 실패가 머지를 막지 않는다 · 판정은 `validate`가 한다). **권한을 나눈다**: ①`render-diff` job은 PR의 내용을 렌더하고 비교해 코멘트 본문을 **파일로** 만든다(`contents: read`뿐 — 쓰기 권한이 없다) ②`render-comment` job은 그 파일을 받아 코멘트를 단다(`pull-requests: write` — **이 job은 저장소를 체크아웃하지 않고 PR의 내용을 처리하지 않는다**). 쓰기 토큰을 가진 job이 PR이 고른 내용을 렌더하지 않게 하려는 것이다. 둘 다 `validate`가 성공한 뒤에만 돈다(봇 PR은 경로 lint를 통과한 것만 렌더된다). 포크에서 온 PR은 토큰이 읽기 전용이라 코멘트를 달 수 없으므로 건너뛰고 같은 내용을 job 요약에 남긴다. `pull_request_target`은 쓰지 않는다.
   - 본문에는 PR이 고른 글자(렌더된 매니페스트)가 들어간다 — 코드 울타리는 내용 안의 어떤 울타리보다 길게 잡고, 크기 한도를 넘으면 요약으로 바꾸며, 코멘트 갱신은 **`github-actions[bot]`이 쓴, 표식이 있는 코멘트**만 대상으로 한다(다른 계정이 같은 표식을 넣은 코멘트를 덮어쓰지 않는다).
   - 대상은 `--root` 트리의 모든 kustomization 디렉터리(`tests/`·`charts/` 제외)와 directory source 경로(`clusters/oci-k3s/apps`)의 파일이다. 코멘트는 PR마다 하나를 갱신한다(새로 쌓지 않는다). 길이 한도를 넘으면 컴포넌트별 요약(바뀐 객체의 kind/이름 · 줄 수)만 남기고 전문은 job 아티팩트로 올린다.
   - 승격 PR(§이미지·승격)에서 운영자가 확인하는 것이 이 코멘트다 — 코멘트가 없거나 실패했으면 머지하지 않는다(PR 템플릿의 확인 항목).

### validate.yml의 실행 구조 (T047)

- job `validate`(required)의 스텝 순서: checkout → **경로 lint(base ref 스크립트 · `--only-author`)** → 자기검사 대상 판정 → 도구 설치(yq · kustomize · kubeconform · gitleaks · **helm** — 버전 고정 + sha256 대조, arm64 · 워크플로 안 인라인) → 전체 검사(`tests/validate.sh`, PR 쪽 스크립트) → 자기검사(조건부) → gitleaks(히스토리). **경로 lint와 판정은 PR 쪽 코드를 실행하기 전에 돈다** — App은 `.github/workflows/` 밖의 파일을 바꿀 수 있으므로, PR 쪽 코드를 실행한 뒤의 검사는 봇이 미리 환경을 바꿔 둘 수 있다. `VALIDATE_SKIP_TOOLS`는 CI에서 설정하지 않는다(SKIP만 남아도 exit 0이 된다).
- **자기검사(`tests/validate.tests.sh`)의 실행 시점(T047 결정 2026-09-29 — arm64 러너 실측: 전체 검사 35초 · 자기검사 122 케이스 184초 · job 전체 약 3분 48초)**: ①**main push에서는 항상** ②**PR에서는 `tests/` 또는 `.github/` 아래가 바뀐 경우에만**(merge-base ↔ head의 변경 경로로 판정). 그 밖의 PR은 전체 검사까지만 돈다(약 45초). 이유: 봇의 dev bump PR은 required check가 끝나야 자동 머지되므로 검사 시간이 그대로 배포 지연이다(SC-010 — dev bump → sync 5분 이내). 봇은 `tests/`를 고칠 수 없으므로(경로 lint) 봇 PR의 검사 스크립트는 main의 것과 같고, 그것은 main push에서 이미 검증됐다.
  - 판정은 워크플로 안의 인라인 스크립트가 **PR 쪽 코드를 실행하기 전에** 한다. 판정에 실패하면(merge-base를 못 구함 등) **돌리는 쪽**으로 넘어진다.
  - 돌릴 때는 `CI=true`라 부분 실행이 거부되고 도구 누락이 실패다 — helm도 도구 게이트에 포함한다.
  - 로컬에서는 전체 실행이 약 1시간 걸린다(Windows · Git Bash 실측) — 로컬은 영향 받는 케이스만 돌리고 전체 판정은 CI가 맡는다.
- job 이름 `validate`는 ruleset의 required check 이름이다 — 바꾸지 않는다.
- 트리거는 **main을 향한 PR**과 **main push**뿐이다(`pull_request.branches: [main]` · `push.branches: [main]`). 다른 브랜치를 base로 한 PR에서는 돌지 않는다(위 「이 보증의 전제」 ④).
- 동시 실행: PR은 같은 PR의 옛 실행을 취소하고, **main push 실행은 서로 취소하지 않는다**(커밋마다 끝까지 돈다) — "봇 PR의 검사 스크립트는 main push에서 이미 검증됐다"가 성립하려면 main의 실행이 취소되면 안 된다. main 실행의 실패는 머지를 막지 못한다(이미 머지된 뒤다) — 커밋의 상태 표시로 드러나고, 알림은 T098(관측)에서 다룬다.
- **포크에서 온 PR(T047 결정 2026-09-29)**: 워크플로 파일까지 PR 쪽 것으로 돈다(포크의 내용은 App 권한의 통제 밖이다). 승인 수가 0이고 봇은 통과한 어떤 PR이든 머지할 수 있으므로(머지 API는 작성자를 가리지 않는다), 외부 계정이 검사를 무력화한 포크 PR을 열고 탈취된 봇 토큰이 그것을 머지하는 경로가 있다. 저장소 설정 둘로 막는다(운영자가 적용):
  - ①**PR 생성은 협력자만**(`pull_request_creation_policy: collaborators_only`) — 이 저장소는 외부 기여를 받지 않는다. **App의 PR 생성이 이 설정에서도 되는지는 미실측**이다 — T074(첫 dev bump)에서 재고, 막히면 이 설정만 `all`로 되돌린다(②가 남는다).
  - ②**외부 기여자의 워크플로 실행은 항상 운영자 승인**(`approval_policy: all_external_contributors`) — "첫 기여자만"이면 한 번이라도 기여가 머지된 계정은 승인 없이 돈다. 운영자는 "Approve and run"을 머지 승인과 같은 무게로 다룬다 — 누르기 전에 그 PR이 `.github/`와 `tests/`를 바꾸는지 본다.

## 변경 권한

- 사람은 PR로만 main에 쓴다(ruleset). GitHub App(`jt-ci`)도 PR로만 쓴다 — bypass 주체 없음. App이 auto-merge를 거는 것은 **dev digest bump PR뿐**이고(VD-5), prod 승격 PR은 사람이 머지한다.
- `platform/`·`clusters/` 변경은 approval-review의 `k8s-security` 경계 대상(모노레포 spec에서 링크). 비가역 변경 파일(오퍼레이터 버전·`metadataVersion`·PG major·Authentik 차트) PR 템플릿에는 스냅샷 3종(Vault raft·CNPG 백업·K3s SQLite) 확인 체크박스가 있다.
