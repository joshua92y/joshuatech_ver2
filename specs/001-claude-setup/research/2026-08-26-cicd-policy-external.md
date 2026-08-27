# 외부 자문 원문: GitOps 기반 CI/CD 정책 (2026-08-26)

> **성격**: 외부 AI 자문에서 받아 온 정책 제안 원문. 채택 문서가 아니라 **참고 자료**이며, 검토 결과와 SP-1/SP-3 입력은
> [2026-08-26-cicd-policy-review.md](2026-08-26-cicd-policy-review.md)에 있다.
> **전제**: 원문은 "OCI + K3s + GHCR + Argo CD" 스택을 가정한다. 이 프로젝트의 스택은 SP-1에서 결정된다(spec D3).
> **원문 인용 주의**: 본문 링크 중 `release-2.7` Argo CD 문서와 AWS EKS 페이지는 검토에서 교체 권고됨(현재 Argo CD 3.5). 원문은 수정 없이 보존한다.

---


네. 이 정책의 핵심은 **CI는 "검증하고 이미지와 배포 선언을 만든다", CD는 "Git에 승인된 배포 선언을 K3s에 지속적으로 맞춘다"**로 책임을 분리하는 것입니다. 프로젝트 repo의 push가 서버를 직접 조작하지 않고, GitOps repo의 commit만이 실제 배포를 변경할 수 있게 만듭니다. Argo CD는 그 Git 선언과 클러스터의 실제 상태를 비교·동기화합니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/latest/user-guide/auto_sync/)

## 전체 책임 분리

```text
프로젝트 repo                 GitOps repo                     K3s cluster
─────────────                 ──────────                     ───────────
소스 코드                     원하는 배포 상태                실제 실행 상태
Dockerfile                    Kustomize / Helm values        Deployment / Pod
테스트·빌드                   image digest 또는 SHA tag       Service / Ingress
GitHub Actions CI             PR·승인·배포 이력              Argo CD reconcile
```

| 계층 | 정본(Source of Truth) | 책임 | 직접 하면 안 되는 일 |
|---|---|---|---|
| 애플리케이션 | 프로젝트 repo | 코드, 테스트, Dockerfile, 이미지 build | `kubectl apply`로 운영 cluster를 직접 변경 |
| 배포 선언 | GitOps repo | image version, replica, resource, env 설정, Helm/Kustomize | 코드 수정 없이 registry의 `latest`만 교체 |
| 실행 상태 | K3s | 선언된 Pod/Service/Ingress 실행 | 사람이 `kubectl edit`로 영구 상태 변경 |
| 동기화 | Argo CD | GitOps repo 상태를 K3s에 반영·drift 탐지 | 애플리케이션 source code를 build |

GitOps에서 **GitOps repo의 manifest가 운영 환경의 유일한 원하는 상태**입니다. 사람이 급하게 `kubectl scale`, `kubectl edit`를 실행할 수는 있지만, 원칙적으로 그 변경은 임시 조치이며 반드시 GitOps repo에 반영하거나 되돌려야 합니다. `selfHeal`을 켜면 Argo CD가 Git과 다른 live cluster 변경을 Git 선언으로 되돌릴 수 있습니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/release-2.7/user-guide/auto_sync/)

## 저장소 정책

처음에는 source repo와 GitOps repo를 분리하는 구성이 좋습니다.

```text
github.com/joshuatech/my-service          # 프로젝트 repo
github.com/joshuatech/platform-gitops     # GitOps repo
```

### 프로젝트 repo

```text
my-service/
├── apps/
│   ├── web/                     # Next.js + pnpm
│   └── api/                     # FastAPI + uv
├── Dockerfile
├── compose.yaml                 # 선택: 로컬 개발용
├── .github/workflows/
│   ├── ci.yml                   # lint/test/build
│   └── publish-image.yml        # GHCR push + GitOps update
├── specs/                       # Spec Kit feature 산출물
└── infra/                       # OpenTofu/Ansible 등 기반 인프라
```

이 repo는 **이미지까지 생산**합니다. `main`에 merge된 commit은 검증된 컨테이너 이미지로 GHCR에 push되지만, 그 자체가 곧 production 배포를 뜻하지는 않습니다. GitHub Actions에서 GHCR publish에는 일반적으로 `contents: read`, `packages: write` 권한이 필요합니다. [docs.github](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)

### GitOps repo

```text
platform-gitops/
├── bootstrap/
│   ├── argocd/
│   ├── cert-manager/
│   └── traefik/
├── clusters/
│   └── oci-k3s-prod/
│       ├── root-app.yaml
│       └── projects/
├── apps/
│   └── my-service/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   ├── ingress.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml
│           └── prod/
│               └── kustomization.yaml
└── policies/
```

이 repo는 **"현재 어떤 버전이 어느 환경에서 돌아야 하는가"**만 관리합니다. image tag/digest, replicas, resource limit, ingress hostname, 환경별 ConfigMap 참조 등은 여기에 두되, `.env`, DB 비밀번호, Cloudflare API token 같은 secret 원문은 커밋하지 않습니다.

## 이미지 불변성 정책

이미지는 `latest`가 아니라 **불변 SHA tag 또는 image digest**로 배포합니다.

```text
권장: ghcr.io/joshuatech/my-api:sha-a1b2c3d4
더 강함: ghcr.io/joshuatech/my-api@sha256:4d...
비권장: ghcr.io/joshuatech/my-api:latest
```

`latest`는 같은 이름이 다른 이미지를 계속 가리키는 mutable tag라 배포 재현·rollback·감사가 어렵습니다. 반면 source commit SHA 또는 content digest를 GitOps commit에 적으면 "어떤 코드 → 어떤 이미지 → 어떤 배포"인지 추적할 수 있습니다. GitHub Container Registry는 `ghcr.io`에서 tag 기반 OCI/Docker image 저장과 관리를 지원합니다. [docs.github](https://docs.github.com/actions/guides/publishing-docker-images)

가장 권장하는 정책은 다음입니다.

```text
개발 환경(dev)  → sha tag 자동 승격 가능
운영 환경(prod) → SHA tag 또는 digest 변경 PR을 사람 승인 후 승격
```

## CI 정책

프로젝트 repo의 PR과 `main` merge를 구분합니다.

### PR 단계: 배포하지 않음

```text
Pull Request
  ├─ pnpm install --frozen-lockfile
  ├─ pnpm lint / test / build
  ├─ uv sync --frozen
  ├─ ruff / pytest / type check
  ├─ Docker build 검증
  ├─ dependency·secret scan
  └─ 필요 시 이미지 build만 하고 push/배포는 하지 않음
```

PR은 **코드 품질과 컨테이너 build 가능 여부를 검증**하는 단계입니다. production registry에 mutable image를 올리거나 GitOps manifest를 갱신하지 않는 것이 안전합니다.

### main merge: 이미지 생산

```text
main merge
  ├─ 전체 테스트 재실행
  ├─ Docker image build
  ├─ GHCR push
  │    ├─ sha-<short-sha>
  │    └─ sha256 digest 확보
  ├─ image metadata / SBOM / provenance 생성 (후속 권장)
  └─ GitOps repo의 dev image reference 갱신
```

CI는 GitOps repo의 `dev` overlay만 자동으로 수정합니다.

```yaml
# apps/my-service/overlays/dev/kustomization.yaml
images:
  - name: ghcr.io/joshuatech/my-api
    newName: ghcr.io/joshuatech/my-api
    newTag: sha-a1b2c3d4
```

Argo CD 공식 CI automation 모델도 CI pipeline이 config repo의 image 값을 변경하고 Git에 push한 뒤, Argo CD가 그 변경을 적용하는 방식을 안내합니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/)

## 환경별 배포 정책

### dev: 자동 배포

```text
프로젝트 repo main merge
  → GHCR에 sha image push
  → CI가 GitOps repo dev tag 변경 commit
  → Argo CD auto-sync
  → K3s rolling update
```

dev는 빠른 피드백이 목적이므로, 테스트가 모두 통과하면 자동 배포할 수 있습니다.

```yaml
# Argo CD Application: dev
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- `automated`: Git commit의 선언 변경을 자동 반영합니다.
- `selfHeal: true`: 운영자가 `kubectl edit`·`kubectl scale`로 바꾼 live 상태를 Git 선언으로 복구합니다.
- `prune: true`: Git에서 제거된 리소스를 cluster에서도 제거합니다. Argo CD는 기본적으로 Git에서 사라진 리소스를 자동 삭제하지 않으므로, 이 옵션은 의도적으로 켜야 합니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/latest/user-guide/auto_sync/)

단, dev의 `prune: true`는 namespace 전체를 한 Application이 독점하고, resource 이름 충돌·공유 리소스가 없을 때만 켜세요.

### prod: 승인 기반 배포

production은 source repo push가 곧바로 배포되면 안 됩니다.

```text
dev에서 검증된 image
  → GitOps repo에서 prod image 변경 PR 생성
  → manifest diff / image digest / migration / rollback 검토
  → PR 승인·merge
  → Argo CD prod sync
  → K3s rolling update
```

GitHub Environment의 `production`에는 required reviewer, 특정 branch/tag만 허용, environment secret 접근 제한을 걸 수 있습니다. Environment에 연결된 job은 보호 규칙을 통과해야 실행되며, 환경 secret도 승인 전에는 사용할 수 없습니다. [docs.github](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments)

1인 운영이라도 prod GitOps PR은 최소한 다음을 확인하고 merge하세요.

- image가 dev에서 정상 동작했는가
- DB migration이 있는가
- rollback 가능한가
- environment variable/secret reference 변경이 있는가
- ingress·DNS·resource limit·replica 변경이 있는가
- K3s capacity와 dependency가 충분한가

## Argo CD 정책

Argo CD는 **pull 기반 배포자**입니다. GitHub Actions가 VPN 내부 K3s API에 접근할 필요가 없고, K3s 안의 Argo CD가 Git repo를 읽어 원하는 상태를 반영합니다.

```text
GitHub Actions → GHCR push + GitOps commit
                                      │
                                      ▼
K3s 내부 Argo CD → GitOps repo pull → K3s API apply
                                      │
                                      ▼
Deployment controller → 새 ReplicaSet 생성
                                      │
                                      ▼
K3s kubelet/containerd → GHCR image pull → 새 Pod 실행
```

따라서 **Argo CD는 image를 pull하지 않고 manifest를 apply**하며, 실제 image pull은 노드의 kubelet/containerd가 새 Pod를 시작하면서 수행합니다. Argo CD는 Git에서 정의한 desired state와 Kubernetes live state를 비교하고 sync합니다. [docs.aws.amazon](https://docs.aws.amazon.com/eks/latest/userguide/argocd.md)

### 권장 sync 옵션

| 환경 | Auto-sync | Self-heal | Prune | 이유 |
|---|---:|---:|---:|---|
| dev | 켬 | 켬 | 켬 | 빠른 반복, Git을 절대 정본으로 사용 |
| staging | 켬 | 켬 | 조건부 | prod 전 검증 환경 |
| prod | 켬 또는 수동 | 켬 | 초기에는 끔 또는 제한적 | 사고 방지와 배포 이력 검토 우선 |
| platform/infra | 수동 또는 Sync Window | 켬 | 매우 신중 | cert-manager, ingress, CRD 삭제는 영향 범위가 큼 |

prod에서도 auto-sync 자체는 안전할 수 있습니다. **사람이 GitOps PR을 승인한 뒤 merge하는 순간을 승인 지점**으로 두면, Argo CD가 즉시 반영하는 것은 오히려 예측 가능하고 감사하기 쉽습니다.

하지만 `prune: true`는 별도 판단입니다. Git에서 Deployment나 CRD를 실수로 지웠을 때 실제 리소스도 삭제될 수 있으므로, 초기 production에서는 `prune: false`로 시작하거나 중요 resource에 삭제 보호 정책을 둔 뒤 운영 경험이 쌓이면 켜는 편이 안전합니다. Argo CD는 기본적으로 안전장치로 자동 prune을 하지 않습니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/release-2.7/user-guide/auto_sync/)

## 롤링 업데이트 정책

Deployment는 새 image가 선언되면 Kubernetes rolling update로 교체합니다.

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0
      maxSurge: 1
```

의미는 다음과 같습니다.

- `maxUnavailable: 0`: 기존 정상 Pod 수를 줄이지 않고 새 Pod가 준비될 때까지 기다립니다.
- `maxSurge: 1`: 교체 중 새 Pod를 하나 더 띄울 수 있습니다.
- `readinessProbe`: 새 Pod가 실제 요청을 처리할 준비가 된 뒤에만 Service endpoint에 넣습니다.
- `livenessProbe`: 비정상 프로세스를 재시작합니다.
- `startupProbe`: 느린 초기화 중 liveness 실패로 재시작되는 일을 줄입니다.

FastAPI/Django API에는 `/healthz`와 `/readyz`를 분리하고, DB·Redis 등 필수 dependency가 준비되지 않았으면 `/readyz`가 실패하도록 설계하는 편이 좋습니다.

## 실패와 rollback 정책

GitOps에서 rollback은 "서버에서 이전 컨테이너를 찾아 재시작"하는 작업이 아닙니다. **GitOps repo의 image reference를 직전 정상 SHA/digest로 되돌리는 새 commit 또는 revert**입니다.

```text
배포 실패 감지
  → GitOps repo에서 prod manifest commit revert
  → Argo CD가 이전 image reference 확인
  → K3s가 이전 정상 image로 rolling update
```

이 방식의 장점은 rollback도 배포와 똑같이 Git 이력·PR·감사 로그에 남는다는 점입니다. Argo CD auto-sync는 Git 변경을 적용하는 기능이지, 실패한 애플리케이션을 자동으로 이전 버전으로 되돌리는 일반적인 rollback 기능은 아니므로, 자동 rollback은 별도 health metric과 배포 분석 도구를 설계한 뒤 도입하세요. Argo CD는 같은 commit SHA와 parameter 조합에 대해 기본적으로 한 번 sync를 시도하며, self-heal 설정 시에는 live drift 복구를 재시도할 수 있습니다. [argo-cd.readthedocs](https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/)

## DB migration 정책

DB migration은 앱 image rollout과 달리 특히 보수적으로 관리해야 합니다.

```text
안전한 순서:
1. 이전 앱과 새 앱 모두 호환되는 DB 변경을 먼저 적용
2. 새 앱 배포
3. 충분한 관찰 기간 후, 이전 컬럼·인덱스·코드를 제거
```

- migration은 **expand → migrate → contract** 방식으로 설계합니다.
- `DROP COLUMN`, 대규모 index 변경, non-null 제약 추가는 별도 승인 대상으로 둡니다.
- migration 실패 시 앱을 이전 이미지로 되돌려도 schema가 이미 변경됐을 수 있으므로, "앱 rollback 가능"과 "DB rollback 가능"을 분리해 평가합니다.
- migration Job을 GitOps에 포함할 수 있지만, 자동 sync마다 재실행되지 않도록 Argo CD hook, job name, idempotency를 명확히 설계해야 합니다.

## Secret 정책

GitOps repo에는 secret 평문을 넣지 않습니다.

| 비밀 종류 | 권장 위치 | GitOps에는 |
|---|---|---|
| GHCR pull credential | K3s Secret 또는 ExternalSecret | `imagePullSecrets` 참조만 |
| Cloudflare API token | Secret Manager 또는 K3s Secret | Secret 이름 참조만 |
| DB URL/password | Secret Manager 또는 K3s Secret | `secretKeyRef`만 |
| GitOps repo deploy key/token | Argo CD repository credential | repo URL만 |
| 프로젝트 CI의 GitOps write token | GitHub Actions Secret | workflow에서만 사용 |

GHCR가 private image라면 K3s namespace에 `imagePullSecret`을 만들고 Deployment가 이를 참조해야 합니다. GitHub Packages의 repository 연결 package는 repository 권한을 상속할 수 있지만, cluster가 image를 pull하려면 해당 registry 접근 권한을 별도로 구성해야 합니다. [docs.github](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

## 권한 최소화 정책

### 프로젝트 repo CI

```text
필수:
- contents: read
- packages: write                  # GHCR image push
- GitOps repo contents: write      # dev manifest update

불필요:
- K3s kubeconfig
- kubectl 권한
- OCI root credential
- Cloudflare 전체 API token
```

프로젝트 repo의 CI가 K3s credential을 갖지 않게 해야, CI token이 탈취되더라도 cluster를 직접 조작할 수 없습니다.

### Argo CD

```text
필수:
- GitOps repo read
- K3s API에서 관리 namespace의 필요한 권한

제한:
- cluster-admin을 모든 Application에 부여하지 않기
- app별 namespace/project 분리
- production AppProject는 허용 repo·namespace·kind 제한
```

### 운영자

```text
원칙:
- 직접 kubectl 변경은 장애 대응용 임시 조치
- 정상화 전 반드시 GitOps manifest 수정 또는 revert
- production credential은 개인 로컬에 상시 저장하지 않기
```

## 실제 초기 정책

지금의 OCI + K3s + GHCR 환경에서는 아래처럼 시작하는 것이 과하지 않고 안전합니다.

```text
개발:
- main merge → test → image sha tag push
- CI → GitOps dev tag 자동 갱신
- Argo CD dev auto-sync + self-heal
- prune은 앱 namespace 단위에서만 사용

운영:
- dev 배포 성공 후 GitOps prod PR 생성
- image SHA/digest, migration, resource 변경 검토
- PR merge → Argo CD prod sync
- self-heal on
- prune off로 시작
- rollback = GitOps manifest revert

보안:
- CI는 cluster credential 미보유
- Argo CD만 cluster apply 권한 보유
- secret 원문은 Git repo에 금지
- latest tag 금지, immutable SHA/digest만 허용
```

이 정책의 가장 중요한 원칙은 하나입니다.

> **배포란 "서버에 명령을 보내는 일"이 아니라, GitOps repo에서 검토된 원하는 상태를 변경하는 일이다.** Argo CD는 그 선언을 지속적으로 K3s에 맞추고, GitHub Environment와 PR 보호 규칙은 production 변경 전에 승인·branch 제한·secret 접근 통제를 제공할 수 있습니다. [docs.github](https://docs.github.com/en/actions/concepts/workflows-and-actions/deployment-environments)
