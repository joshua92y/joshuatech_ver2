# CI/CD 정책 외부 자문 검토 (2026-08-26)

**상태**: 참고 자료(채택 안 됨). **SP-1**(런타임·스택 결정)과 **SP-3**(플랫폼·운영, CI/CD 승격) 설계의 입력.
**원문**: [2026-08-26-cicd-policy-external.md](2026-08-26-cicd-policy-external.md) — 외부 AI 자문으로 받은 "OCI + K3s + GHCR + Argo CD" GitOps 정책.
**검토 방법**: Claude Code 워크플로 15 에이전트 — 관점별 리뷰어 7(Argo CD 정확성 · GitHub Actions/공급망 · 시크릿/보안 · 1인·무료티어 적정성 · 운영 완결성 · 프로젝트 적합성 · 2025-26 최신 동향) → 관점별 반박 검증자 7(모든 지적을 1차 출처로 반박 시도) → 누락 비평 1. 지적 74건 + 비평 추가 6건, 기각 0건(확정 59 · 부분 확정 15). [spec.md](../spec.md), v1 워크플로(`d:\code\joshuatech\.github\workflows\*`), `infra/oci/*`를 함께 투입.
**유효기간 주의**: 아래 수치(OCI 한도, GitHub 플랜 조건, Argo CD/K3s 버전)는 **2026-08-26 기준**. SP-1 착수 시 §9 출처로 재확인한다.

---

## 0. 결론

원칙 계층(불변 아티팩트 · Git 정본 · pull 기반 CD · CI 무자격증명 · PR 검증/main 발행 · rollback=revert · expand→contract)은 **정확하고 v1 대비 큰 개선**이다. 그러나 원문은 ① SP-1에서 아직 결정하지 않은 K3s 스택을 전제하고, ② 더 이상 존재하지 않는 OCI 용량(4 OCPU/24 GB)을 가정하며, ③ 제시한 prod 승인 게이트(GitHub Environment)가 pull 기반 흐름에서는 아무것도 막지 않는다.

**처분**: 원칙만 지금 ADR(`docs/decisions/0002-*`)로 채택하고, K3s 세부는 SP-1 결과와 테넌시 확인 후 SP-3 feature의 조건부 부록으로 옮긴다. v1 compose 파이프라인의 스택 중립 강화(§7.3 Step 1–2)는 SP-1 전에 해도 된다.

---

## 1. 채택할 원칙 (스택 중립 — ADR 0002 후보)

| 원칙 | 왜 맞는가 (검증) |
|---|---|
| **pull 기반 CD, CI는 런타임 자격증명(kubeconfig·SSH) 미보유** | v1은 Actions에 SSH 키 + heredoc으로 `.env`에 R2/Postmark 시크릿 기록. 토큰 유출 피해가 "prod VM root" → "staging 이미지 태그 변경"으로 축소. 엔진(Argo CD/Flux/compose-pull)과 무관하게 유효 |
| **PR = 검증만, main merge = 유일한 발행 이벤트** | v1은 경로만 맞으면 어느 브랜치 push든 `:latest`로 prod 배포. Cloudflare 레인(PR=`versions upload`, main=`deploy`)에도 1:1 대응 |
| **`latest` 금지, 불변 sha 태그 + digest** | GHCR에는 태그 불변성 기능이 없다(community #181783 미해결) → `sha-*`도 관례상 불변일 뿐. digest 고정이 유일한 보호이며 attestation 검증의 전제. Kustomize `images[].digest` 지원 |
| **rollback = 선언 상태 revert** | 취향이 아니라 제약: Argo CD "auto-sync 활성 앱에는 rollback 수행 불가". Git revert가 유일한 경로 |
| **expand → migrate → contract, "앱 롤백 ≠ DB 롤백"** | `maxUnavailable: 0` 롤링 중 구/신 Pod가 같은 스키마를 본다 |
| **시크릿 원문 Git 금지, 참조(`secretKeyRef`)만** | Argo CD 공식 secret-management 가이드와 일치. Sealed Secrets/ESO가 그대로 끼워진다 |
| **CI-writes-Git 승격 (Image Updater 대신)** | Image Updater는 1.3.0(2026-08)에도 "non-critical 환경에서 테스트" 권고. 공식 ci_automation 가이드와 동일 패턴 |
| prune/selfHeal 기본값 서술, 자동 롤백 유보 | 3.5에서도 그대로 유효. Argo Rollouts는 1 replica 포트폴리오에 과함 |

---

## 2. 채택 불가 사유 — 구조적 문제 3

### S1. 스택 결정(SP-1)을 문서가 선점한다
- 첫 문장부터 트리(`apps/web` Next.js가 루트 `Dockerfile` 하나로 GHCR)까지 모든 워크로드를 K3s 컨테이너로 가정. v1은 이미 **하이브리드**(Next.js → Cloudflare Pages + R2, API/worker → OCI compose).
- Cloudflare는 Pages 문서에 "새 프로젝트는 Workers로 시작하라"고 명시. Workers Builds(Free 3,000분/월, 동시 1, 20분 제한)가 PR 프리뷰 URL·PR 코멘트·체크런을 무료 제공(Durable Object Worker는 프리뷰 URL 없음).
- 원문에는 Cloudflare 배포 레인이 없고, kustomize 예시에는 `my-api`만 있으며 web은 어디에도 배포되지 않는다.
- Cloudflare 레인의 한계: wrangler용 OIDC가 아직 없다(workers-sdk #11434 미해결) → 이 레인에선 "CI 무자격증명"이 성립하지 않고 Worker 단위 스코프 API 토큰(GitHub secret, 주기 회전)이 필요. 점진 배포(%)·Workers Logs는 **Workers 전용**(Pages 없음); 롤백·프리뷰는 둘 다 가능.
- → **3계층 분리(§7.1)**. L1 원칙은 지금, L3(K3s/Argo CD)는 SP-1이 API를 K3s에 두기로 할 때만 활성.

### S2. 용량 전제가 무너졌다 (가장 시급)
- [Oracle Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)(2026-08-26 확인): Ampere A1 = **월 1,500 OCPU-h + 9,000 GB-h = 2 OCPU / 12 GB**. 2026-06-15에 4/24에서 절반으로 감소(InfoQ 2026-07). 한도 초과 Always Free 인스턴스는 비활성화 후 30일 뒤 삭제. **PAYG 전환 계정은 4/24 유지**라는 보고가 있으나 비공식. 7일간 CPU·네트워크·메모리 모두 <20%면 유휴 회수.
- K3s 서버 최소 사양만 2코어/2 GB. v1 VM 2대(FastAPI VM + Dragonfly/worker VM `10.0.10.193`)가 이미 이 예산을 쓴다.
- 원문의 dev+prod 두 벌 + Argo CD 전체 설치(7 워크로드) + cert-manager + Traefik + (표에만 있는) staging은 12 GB에 들어가지 않는다.
- → **Step 0: 테넌시 실제 할당(Always Free vs PAYG) 확인, 기존 인스턴스 절대 종료 금지**(한도 위로 재생성 불가 가능).

### S3. prod 승인 게이트가 실제로 존재하지 않는다
- Environment 보호 규칙은 **그 environment를 참조하는 Actions job**만 멈춘다. 이 설계에서 prod 배포는 GitOps repo merge → Argo CD pull이라 그런 job이 없다.
- [GitHub 문서](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments): Free 플랜은 **public repo에서만** environment/ruleset/branch protection 사용 가능(private는 Pro $4/월). **PR 작성자는 자기 PR을 승인할 수 없다** → 1인은 required approvals ≥ 1을 영원히 못 채움. Environment self-review는 기본 허용("Prevent self-review" 옵션이 별도).
- 실제 게이트는 하나: **`platform-gitops` `main`의 ruleset** — PR 필수 · required approvals 0 · required status checks(`kustomize build` + `kubeconform` + diff 코멘트) · force-push 차단. 사람의 승인 = 렌더된 diff를 읽고 누르는 merge.
- **연결 규칙(누락 비평)**: 이 ruleset은 CI의 staging bump 직접 push도 막는다 → **CI용 GitHub App만 bypass actor**("Always allow")로 등록, 사람 계정은 bypass 없음. 보조 가드: bot 커밋이 `apps/*/overlays/prod/**`를 건드리면 실패하는 status check. fine-grained PAT은 사람(admin)으로 bypass하므로 부적합 — **GitHub App 선택의 결정적 이유**.
- 이 모두가 **repo public**을 요구한다(시크릿은 정책상 Git에 없음 → learning-in-public과 정합).

---

## 3. 검증된 환경 제약 (2026-08-26, 1차 출처)

### 3.1 OCI
- Always Free A1: 2 OCPU / 12 GB(§S2). Block volume 200 GB(+백업 5), Object Storage 20 GB(S3 호환 endpoint `https://<ns>.compat.objectstorage.<region>.oraclecloud.com`, path-style), Autonomous DB 2개(1 OCPU/20 GB, Oracle 방언), MySQL HeatWave 1노드.
- OCI Vault: 소프트웨어 보호 마스터 키 무료, Always Free 시크릿 150개·버전 40개(virtual private vault는 유료). Instance principal로 노드 신원 인증 가능(169.254.169.254).
- Velero에 OCI 볼륨 스냅샷 플러그인 없음(파일시스템 백업만).

### 3.2 GitHub (개인 계정 Free 기준)
- public에서만: environments, rulesets/branch protection, secret scanning + push protection, CodeQL 기본 설정, **artifact attestations**(Free/Pro/Team 모두 public 한정, private는 Enterprise Cloud), arm64 러너 무료·무제한(`ubuntu-24.04-arm`, 4 vCPU). Pro($4/월)는 ruleset/environment만 풀고 CodeQL·secret scanning·attestation은 못 푼다.
- private Free: Actions 2,000분/월, Packages 500 MB 저장 + **1 GB/월 전송**(Actions 아티팩트와 공유; `GITHUB_TOKEN` 다운로드만 예외). 결제수단 없으면 쿼터 소진 시 **차단** → K3s 노드의 private 이미지 pull이 imagePullSecret 오류처럼 실패. public 패키지는 무제한 무료.
- GHCR: 태그 불변성 없음, 보존 정책 없음(삭제 후 30일 복구). private pull은 **classic PAT만**(fine-grained PAT은 ghcr 인증 불가).
- `GITHUB_TOKEN`은 자기 repo 한정 → 교차 repo 쓰기는 GitHub App/PAT. `GITHUB_TOKEN`이 만든 이벤트는 워크플로를 트리거하지 않는다(App/PAT는 트리거함 — GitOps repo validate가 돌아야 하므로 바람직).
- 2025-08: Actions 정책 "full-length commit SHA 핀 강제" 체크박스(repo 수준 가능). 2025-10: Immutable releases GA. 2026-01: arm64 러너 private repo 지원(2 vCPU, 분당 $0.005). 2026-01-01: 호스티드 러너 가격 인하. Merge queue는 개인 계정 불가.
- 2025-03 `tj-actions/changed-files` 사고(CVE-2025-30066, 23,000+ repo): 태그 핀의 위험 실례.

### 3.3 Argo CD / K3s / Kubernetes
- **Argo CD 3.5.1**(2026-08-12) 현재. 분기별 minor, **최근 3개만 지원**(3.3/3.4/3.5) → 약 9개월마다 업그레이드 필요.
  - 3.0: 리소스 추적 기본 annotation, `logs, get` RBAC 명시 필요, `update/*`·`delete/*` 세분 RBAC, `argocd_app_sync_status` 등 메트릭 제거(→ `argocd_app_info` 라벨).
  - 3.1: `spec.syncPolicy.automated.enabled`(null=켜짐, false=설정 유지형 일시정지), Server-Side Diff stable(옵트인).
  - 3.3: **self-managed 설치는 `ServerSideApply=true` 필수**(ApplicationSet CRD가 client-side annotation 한도 초과), PreDelete 훅.
  - 3.5: Helm 4.2.1, GnuPG 검증 deprecated → AppProject `sourceIntegrity`, Source Hydrator **beta**, sync-with-impersonation beta.
  - 동작: Git/OCI/Helm 폴링 **3분**(webhook으로 즉시). 자동 sync는 commit SHA+파라미터 조합당 1회(실패 시 컨트롤러 기본 5회 재시도 후 재시도 없음). auto-sync 켜진 앱은 UI/CLI rollback 불가. selfHeal은 `automated` 하위 필드. `Prune=confirm`/`Delete=confirm`/`Prune=false`/`Delete=false` 리소스 주석, `PruneLast`, `allowEmpty`. 훅은 commit 트리거 sync마다 실행(selfHeal 드리프트 복구는 훅 미실행). `core-install`에는 API 서버·UI·dex·**Notifications 컨트롤러**가 없다. application-controller는 모든 설치 변형에서 `*/*/*` ClusterRole(= cluster-admin). `default` AppProject는 모든 repo·목적지·kind 허용.
  - Image Updater 1.3.0(2026-08-13): CRD 기반, "under active development". Source Hydrator: beta, push용 별도 자격증명 필요.
- **K3s**: 최신 v1.36.3+k3s1(2026-08-04), 1.33.13/1.34.10 유지선. Traefik **v3** 번들(v1.33.0+, 현재 v3.7.8; 대시보드·API 기본 off; 커스터마이즈는 `HelmChartConfig`, 제거는 `--disable=traefik`). 기본 datastore **SQLite**(백업 = `/var/lib/rancher/k3s/server/db/` + `token`); `etcd-snapshot`/`--etcd-s3`는 embedded etcd(`--cluster-init`)에서만. `--secrets-encryption` 기본 **off**(나중에 켜면 재시작 + reencrypt; provider `secretbox` 가능). 내장 NetworkPolicy 컨트롤러(kube-router) 있음, 정책 자체는 없음. local-path-provisioner PVC = 노드 디스크. system-upgrade-controller로 자동 업그레이드(Plan `version` 핀, `cordon`, window).
- **Kubernetes 1.36** 현재(N-2 지원). Deployment `progressDeadlineSeconds` 기본 600, `minReadySeconds` 기본 0, 자동 롤백 없음. `replicas: 1` + PDB `minAvailable: 1`이면 drain 영구 차단. preStop `sleep` action 1.30+ 기본.
- 무료 관측: Grafana Cloud Free = 10k active series, 로그 50 GB, 트레이스 50 GB, 14일 보존, 3 사용자. Argo CD Notifications 서비스: Slack·Telegram·Email·GitHub·Webhook·Grafana·Alertmanager·Teams·Google Chat·Pushover(Discord는 Webhook으로).
- Flux 2.9.4(2026-08): 이미지 자동화 GA(2.7), OCI 아티팩트 GA(2.6), Helm v4(2.8), SOPS 복호화 내장. Sealed Secrets v0.39.1(2026-08-20).

### 3.4 Cloudflare
- Pages 문서: "Workers를 주 플랫폼으로, 새 프로젝트는 Workers로 시작". Workers Builds Free 3,000분/월·동시 1·20분 제한, 비-프로덕션 브랜치 = `wrangler versions upload`(프리뷰 URL + PR 코멘트 + 체크런), 프로덕션 = `wrangler deploy`. 점진 배포 = `versions upload` → `versions deploy` %(Workers 전용). `wrangler rollback`: 최근 100버전, 대상 버전의 KV/R2/Queue 바인딩이 사라졌거나 Durable Object 클래스 lifecycle 변경 시 차단; KV/R2/D1 상태는 버전 관리 안 됨. Pages도 프로덕션 배포 롤백 가능.
- Tunnel(cloudflared): 인바운드 포트 0(아웃바운드 7844), Kubernetes 배포는 Deployment + `TUNNEL_TOKEN` Secret, 2 replica는 HA용. Cloudflare Access로 호스트명 게이팅. 원격 SSH/TCP는 클라이언트 측 `cloudflared access tcp`/WARP/브라우저 터미널로 가능(순수 소켓은 아님). 프록시(orange-cloud) 레코드 TTL Auto=300s — origin 전환은 Cloudflare 측 설정 변경.
- Neon Free: 프로젝트당 0.5 GB·100 CU-h/월, 5분 비활성 시 scale-to-zero(첫 요청 cold start), autoscale 2 CU 상한. Supabase Free: 활동 부족 시 프로젝트 일시정지.

### 3.5 월 비용 원장 (원문에 없음)

| 항목 | 무료 범위 | 구속 조건 |
|---|---|---|
| OCI Always Free A1 | 2 OCPU / 12 GB, 200 GB 블록, 20 GB 오브젝트 | PAYG 전환 시 4/24 유지 여부 확인 |
| GitHub Free | public: Actions·Packages 무제한, ruleset·attestation·CodeQL·arm64 | private: 2,000분, 500 MB/1 GB 패키지 — **결제수단 없으면 차단** |
| GitHub Pro | — | $4/월, private ruleset/environment만 추가 |
| Cloudflare Free | DNS, Tunnel, Access, Workers Builds 3,000분, R2 10 GB | 계정 종속(이미 DNS·Pages·R2 사용 중) |
| Grafana Cloud Free | 10k series, 50 GB 로그, 14일 | 10k 초과 시 VictoriaMetrics 자체 운영 |
| Neon Free | 0.5 GB, 100 CU-h | cold start, 2 CU |

→ 원장이 강제하는 결정: **이미지와 두 repo 모두 public**. GHCR 전송 쿼터·imagePullSecret·PAT 회전·쿼터 소진 장애가 함께 사라진다.

---

## 4. 원문 오류·정밀도 표

| 원문 주장 | 실제 | 수정 |
|---|---|---|
| prod "Auto-sync 켬 또는 수동 / Self-heal 켬", platform "수동 또는 Sync Window / Self-heal 켬" | `selfHeal`은 `automated` 하위 필드 — 수동이면 self-heal 불가. Argo CD가 표현 못 하는 조합 | 표를 실제 3상태로: ① `automated: {enabled: true, prune, selfHeal: true}`(staging·prod) ② `enabled: false`(사고 시 일시정지, 설정 유지) ③ `automated` 없음 + deny-by-default Sync Window `manualSync: true`(platform). "수동"은 드리프트를 **보고만** 한다고 명시 |
| "급하면 `kubectl scale/edit` 가능(임시 조치)" + prod selfHeal 켬 | selfHeal이 수초(기본 5s, 현재 지수 백오프) 내 되돌림 → 응급 변경이 성립하지 않음. root app이 self-heal이면 CLI로 건 일시정지도 되돌려짐 | 런북 R1: `automated.enabled: false`(커밋 또는 root app이 child spec을 self-heal하지 않게) → 변경 → GitOps PR → 재활성, 시간 제한 |
| CI 필수 권한 "GitOps repo contents: write" | `GITHUB_TOKEN`은 자기 repo 한정. 교차 repo 자격증명 종류 미명시(v1은 classic PAT) | GitHub App `joshuatech-ci-bot`(platform-gitops만, Contents RW) + `actions/create-github-app-token`(`repositories`, `permission-contents: write`, 1시간 만료, 봇 author) |
| "cluster-admin을 모든 Application에 부여하지 않기" | Application엔 RBAC 없음. controller가 `*/*/*` ClusterRole. 통제 수단은 **AppProject** + `default` 무력화 + `argocd-rbac-cm`(`policy.default: role:readonly`, GitHub SSO에 org 없으면 `''` + 명시 `g, <login>, role:admin`) | `clusters/oci-k3s/projects/{platform,staging,prod}.yaml`. platform: sourceRepos=platform-gitops, 목적지=argocd/sealed-secrets/cloudflared/kube-system, `clusterResourceWhitelist` CRD·ClusterRole; staging/prod: 네임스페이스 1개, `clusterResourceWhitelist: []`, `namespaceResourceBlacklist` ResourceQuota/LimitRange/NetworkPolicy/Role/RoleBinding. root app 프로젝트는 `argocd` ns에 Application 허용. impersonation(3.5 beta)은 미채택 |
| "prod `prune: false`로 시작" | Git에서 리소스 제거 시 **영구 OutOfSync** → 드리프트 신호를 무시하는 습관(컨트롤러 로그 "need to prune extra resources only but automated prune is disabled"). 3.x는 리소스 단위 보호 제공 | prod `prune: true` + `PruneLast=true` + PVC·Namespace·CRD·Certificate·미생성 Secret에 `Prune=false`/`Delete=false`(데모용 `Prune=confirm`). platform 프로젝트만 prune off. `allowEmpty: false` |
| Argo CD 2.7 문서 인용, 예시 `syncOptions: [CreateNamespace=true]` | 현재 3.5.1. self-managed `bootstrap/argocd`는 3.3+ `ServerSideApply=true` 없으면 CRD apply 실패 | 모든 앱에 `syncOptions: [ServerSideApply=true, CreateNamespace=true]`, `ServerSideDiff=true`, remote base 버전 핀, 인용 `/en/stable/` |
| "provenance/SBOM 후속 권장" | `docker/build-push-action`(v7.3.0)이 이미 provenance 생성(public=max, private=min; GHCR에 `unknown/unknown` 행). `actions/attest-build-provenance`(v4.2.2)는 3줄로 SLSA Build L2 — **public repo 한정** | Tier 0 지금: `provenance: mode=max`, `sbom: true`(또는 명시적으로 끄기). Tier 1(public): `id-token: write, attestations: write, packages: write`, `subject-name`(태그 없이)+`subject-digest`, `push-to-registry: true`; promote PR 체크에서 `gh attestation verify oci://ghcr.io/joshuatech/<app>@sha256:… --owner joshuatech`. private 대안 cosign keyless(공개 Rekor). Tier 2 Kyverno verifyImages(~200 MiB+) 명시적 미채택 |
| "권장 `newTag: sha-…`, 더 강함 digest" | kustomize `images[].digest` 지원, `newName`=`name`은 중복 | staging도 CI가 `outputs.digest`를 `digest:`로 기록, `sha-*`·semver는 사람용 라벨 |
| "배포 실패 감지 → revert" | 감지 메커니즘 없음. 나쁜 이미지도 sync는 "성공"(Application Degraded, 옛 Pod가 계속 서비스), K8s 자동 롤백 없음, auto-sync 상태선 UI rollback 비활성. core-install엔 Notifications 컨트롤러 없음 | Notifications `on-sync-failed`/`on-health-degraded`/`on-deployed`(1채널, Telegram이 최저 마찰; Discord는 Webhook), `spec.syncPolicy.retry`, `progressDeadlineSeconds: 300`, 런북 R2 = `git revert` |
| 마이그레이션 Job "자동 sync마다 재실행되지 않도록 훅·이름·멱등성 설계" | 훅은 **commit 트리거 sync마다** 실행(이미지 안 바뀐 prod 설정 변경 포함; selfHeal 복구는 제외) → 멱등성은 필수. 설계는 전무 | `apps/api/base/migrate-job.yaml`: `generateName: api-migrate-`, `hook: PreSync`, `hook-delete-policy: BeforeHookCreation`(실패 로그 보존), `sync-wave: "-1"`, `backoffLimit: 0`, `restartPolicy: Never`, `activeDeadlineSeconds: 600`, **앱과 같은 이미지 참조**(kustomize가 함께 치환), `alembic upgrade head`. PreSync 실패 = sync 중단·옛 Deployment 유지(앱 롤백 무료) but 스키마 부분 변경 가능(DB 롤백 별도). contract는 별도 PR(`migration:contract` 라벨 + 백업 참조) |
| "Argo CD가 즉시 반영" | 기본 3분 폴링. 터널 뒤 UI면 GitHub webhook 미도달 | A) `timeout.reconciliation: 60s` + "merge 후 최대 N분" 명시(첫 달) B) `/api/webhook` 경로만 Access 예외 + `argocd-secret` `webhook.github.secret` |
| 롤링 업데이트: `maxSurge 1`/probe 3종만 | `replicas: 1`이면 surge가 요청량 2배 → 노드 여유 필요. `minReadySeconds` 없으면 2초 뒤 죽는 Pod도 성공. preStop 없으면 SIGTERM 후 잠깐 502. **readiness가 DB 다운에 실패하면 전 Pod 동시 이탈 = 하드 장애** | `minReadySeconds: 10`, `progressDeadlineSeconds: 300`, `terminationGracePeriodSeconds: 30`, `preStop: sleep 5`, requests 2배 수용. `/livez` 프로세스만, `/readyz` 앱 초기화(외부 의존성 제외), `/healthz` 모니터링용. PDB는 replicas ≥ 2부터. "maxSurge 1 = 무중단 배포이지 노드 장애 내성 아님" 명시 |
| 표의 `staging` 행 | 트리(`overlays/{dev,prod}`)에도, 초기 정책에도, 용량에도 없음 | 삭제 또는 `staging`으로 통일(§7.1) |
| 인용 8개 | 문장은 모두 뒷받침됨. 단 2개는 `release-2.7`, 1개는 AWS EKS 관리형 페이지(자체 호스팅 정책의 근거로 부적합), GitHub publish 예시는 현재 `attestations: write, id-token: write` 포함 | `/en/latest/` 또는 `/en/release-3.5/`, `core_concepts/`로 교체 |

---

## 5. 누락 항목 (영역별)

### 5.1 CI 파이프라인
- **`platforms:` 없음** → Ampere 노드에서 첫 배포 `exec format error`. 옵션: ① arm64 단일, `ubuntu-24.04-arm` 네이티브(Windows x64 개발기는 로컬 compose에서 amd64 별도 빌드) ② 두 네이티브 job + `docker buildx imagetools create`(Docker "distributed builds", `distribute: true` 재사용 워크플로) ③ v1 QEMU(3–10배 느림). public이면 ②, private이면 ①.
- 교차 repo push **경쟁**: `concurrency: {group: gitops-staging-<app>, cancel-in-progress: false}` + `git pull --rebase && git push` 최대 3회(또는 매 시도 새 clone에 `kustomize edit set image`). Merge queue는 개인 계정 불가.
- 모노레포 불일치: 2앱·루트 `Dockerfile` 1개·kustomize엔 `my-api`만·이름 3종(`my-service`/`apps/my-service`/`my-api`). → 앱별 Dockerfile·패키지명(`joshuatech-api`), 컨테이너가 둘이면 `paths` 필터(dorny/paths-filter) + `strategy.matrix.app`, 규칙 "이미지를 만들지 않은 merge는 GitOps repo를 건드리지 않는다". 현재 권고: web은 Lane W, 컨테이너 트랙은 `apps/api`만.
- 워크플로 자체 공급망: 모든 `uses:` 40자 SHA + `# vX.Y.Z` 주석, repo 설정 "SHA 핀 강제", `dependabot.yml`(`github-actions` 주간 + pip/uv, pnpm, docker), 기본 토큰 read-only(`permissions: {}` 상단 + job별), Immutable releases, `appleboy/*` 제거.
- "dependency·secret scan" 도구 미명시: public → secret scanning+push protection, CodeQL 기본(JS/TS+Python), Dependabot; private → `gitleaks-action`(개인 무료), `trivy-action`은 push 후 **digest로 스캔**(`load: true` 빌드엔 attestation이 안 붙음; CRITICAL만 exit 1, `ignore-unfixed`).
- **prod 승격 PR 생성 주체 없음** → `platform-gitops/.github/workflows/promote.yml`(`workflow_dispatch`): staging overlay의 digest를 읽어 `kustomize edit set image ghcr.io/…@sha256:…`로 prod overlay 갱신 → PR 생성(본문에 source commit 링크 + `kustomize build` diff). Kargo는 SP-4 이후.
- **두 repo 간 변경 순서 규칙 없음**(누락 비평): 새 env var/Secret 참조/Service가 필요한 기능은 코드 merge → CI staging bump → Argo sync → ConfigMap 없이 CrashLoop(`maxUnavailable: 0`이라 알림 없으면 안 보임). → config expand/contract: ① 용량을 더하는 manifest(ConfigMap 키, Secret 키, probe 경로)는 **GitOps에 먼저** merge(staging·prod 모두) ② 코드는 한 릴리스 동안 새 config를 선택적(기본값)으로 취급 ③ 제거(contract)는 코드가 prod에 간 뒤 별도 PR ④ promote PR 템플릿에 "필요한 manifest 변경 merge됨? (링크)" ⑤ CI bump 커밋 메시지에 source SHA + PR URL(학습 노트가 두 이력을 잇도록).
- GitHub Environment는 Lane W(`deploy-web.yml`)에서만 실제 job을 게이팅한다(public 전제).

### 5.2 이미지·레지스트리
- **GHCR 보존 정책 없음** → 무한 증가 or 순진한 정리가 롤백 이미지 삭제. 주간 `ghcr-cleanup.yml`(`packages: write`): `dataaxiom/ghcr-cleanup-action`(attestation referrer·multi-arch child 인식) 또는 `snok/container-retention-policy`(v3.1.0+ child 보호), `keep-n-tagged: 30`, `delete-untagged`, `older-than: 30d`, prod/staging이 참조하는 digest 보호(배포엔 안 쓰는 `prod-current` 마커 태그). `actions/delete-package-versions`는 multi-arch 미인식.
- 롤백 런북에 "이전 이미지가 GHCR에 아직 있는가" 체크. 노드 이미지 GC는 kubelet 기본(85/80%, `--kubelet-arg`로 조정) — 부트 볼륨 크기를 용량표에.
- private 이미지 pull 자격증명은 classic PAT(`read:packages`)뿐 — CI push 토큰(`GITHUB_TOKEN`)과 분리, ESO `dockerconfigjson` 템플릿 또는 `/etc/rancher/k3s/registries.yaml`(노드마다, 평문). → **이미지 public**이 기본, private은 예외 레시피로만.

### 5.3 시크릿·보안
- "Secret Manager 또는 K3s Secret"은 결정이 아님. 수동 `K3s Secret`은 원문 자신의 `kubectl` 금지와 모순. 옵션표:

| 옵션 | 값 위치 | 부트스트랩 시크릿 | Argo CD 복잡도 | 비고 |
|---|---|---|---|---|
| **Sealed Secrets** | Git(암호화) | 없음(봉인 키 오프라인 백업 = step 0) | 없음 | 컨트롤러 1개 ~50 MiB, 외부 의존 0 → **지금** |
| ESO + OCI Vault(instance principal) | OCI Vault | 없음(노드 신원) | 없음(CRD) | 취업 시장 표준, 169.254.169.254 NetworkPolicy 필요, Argo CD가 repo 자격증명을 먼저 필요(public repo면 해소) → **SP-4** |
| SOPS + age(KSOPS) | Git(암호화) | repo-server에 age 키 | 높음(init container·alpha plugin·ARM 이미지) | Flux 선택 시에만 |
| ESO + Bitwarden/Doppler/Infisical | SaaS | 서비스 토큰(닭-달걀) | 없음 | 벤더 추가, 무료 한도 빠듯 |
| argocd-vault-plugin | Vault | repo-server | CMP | 업스트림이 만류(Redis 평문 캐시) |

- Argo CD repo 자격증명: **public repo면 불필요**(부트스트랩 순환 해소). private이면 GitHub App `joshuatech-argocd`(Contents Read) — installation ID는 자동 탐색 — 또는 읽기 전용 deploy key. PAT 금지.
- 부트스트랩 순서 명문화: infra(K3s config, security list) → Sealed Secrets(봉인 키 복원) → Argo CD(`kubectl apply --server-side --force-conflicts`) → `root-app.yaml`(유일한 수동 apply) → AppProjects → apps.
- **Argo CD UI 노출 정책 없음**(v1 `traefik.joshuatech.dev` `api.insecure: true` 재현 위험): `argocd-initial-admin-secret` 삭제, SSO 후 `admin.enabled: "false"`, UI는 cloudflared → Cloudflare Access(본인 이메일/GitHub 신원) → `argocd-server`(`server.insecure: true`는 터널 TLS 종단 때문임을 명시), dex GitHub 커넥터는 org 없으면 아무 GitHub 계정이나 로그인 가능 → `policy.default: ''` + 명시 admin, 또는 Access만으로 차단.
- K3s 기본 hardening(infra/ 몫이지만 정책이 요구해야 함): `--secrets-encryption`(secretbox) day-one, VCN security list 22만 Tailscale/본인 IP(터널이면 6443/80/443 닫음), `--tls-san` 사설 호스트명, kubeconfig는 노드에만(필요 시 Tailscale로 가져와 비밀번호 관리자에; repo/CI 절대 금지 — 원문의 "상시 저장 금지"를 지킬 수 있는 규칙으로 교체), PSA `restricted`(앱 ns)/`baseline`(플랫폼 ns; hostPath·hostNetwork 차단 = `/run/k3s/containerd/containerd.sock` 구멍 봉쇄), API 감사 로그.
- staging/prod 동일 클러스터인데 **NetworkPolicy 없음**: `policies/`에 앱 ns default-deny ingress+egress, ingress는 cloudflared/traefik ns에서만, egress는 kube-dns + 자기 DB/Redis + 0.0.0.0/0 except 10.0.0.0/8·169.254.169.254/32; prod는 staging 라벨 ingress 거부; ESO를 쓴다면 external-secrets ns만 메타데이터 endpoint 허용; cloudflared ns에 앱 ns egress 허용.
- **v1 폐기 목록**(§7.5) 부재 → 습관으로 이월 위험.

### 5.4 엣지·네트워크
- K3s 번들 Traefik v3와 `bootstrap/traefik` **2중 설치 충돌** → `bootstrap/traefik/helmchartconfig.yaml`(`HelmChartConfig`, 대시보드 off) 또는 `--disable=traefik` 중 하나만.
- cert-manager DNS-01(공개 IP 80/443, DNS 편집 토큰이 클러스터 상주) vs **cloudflared tunnel**(인바운드 0, Access 게이팅, cert-manager 불필요, Ingress 객체 대신 Service 직결 가능, Traefik은 경로 라우팅용으로 유지) → 터널. 필요 시 zone 한정 토큰(`Zone:Read + DNS:Edit`, joshuatech.dev만)으로 in-tunnel TLS 추가.
- Ingress health: 터널이면 `status.loadBalancer` 없음 → Argo CD Ingress health 무관.

### 5.5 상태·백업·DR
- Postgres/Redis 위치 미정. 옵션: Neon Free(무운영, PR/staging 브랜치, 0.5 GB·cold start) / CloudNativePG 단일 인스턴스(arm64 이미지 있음, barman → OCI 버킷 PITR, ~0.5–1 GB RAM, DR이 진짜 일이 됨) / OCI ADB(Oracle 방언, Alembic·멀티테넌트와 충돌) → **Neon SP-2/3, CNPG는 SP-4 학습 노트**. Redis는 지속성 없는 Valkey/Dragonfly 1개(캐시 의미), 내구 큐는 Postgres.
- StorageClass 정책(local-path만), PVC `argocd.argoproj.io/sync-options: Prune=false,Delete=false`.
- "GitOps repo = 복구원"은 시크릿·TLS·DB 데이터·K3s datastore엔 거짓. 3계층: DB 백업 → 시크릿 키(봉인 키) 백업 → datastore(**B** `cluster-init: true` + `etcd-snapshot-schedule-cron` + `--etcd-s3*` → OCI S3 호환 버킷, 복구 `k3s server --cluster-reset --cluster-reset-restore-path=`; 또는 A SQLite `db/`+`token` 야간 tar → rclone). 분기별 복구 드릴 = 학습 노트. 진실된 문장: "복구원 = platform-gitops + 봉인 키 + 최신 datastore 스냅샷 + DB 백업".
- **v1 데이터 컷오버 런북**(누락 비평): 상태 저장소 인벤토리(DB 위치, R2 버킷, Dragonfly 키) → 저장소별 재사용/이전(R2 재사용, Dragonfly 캐시로 취급, DB는 pg_dump/restore 또는 논리 복제) → 쓰기 동결 → 최종 dump → 복원 → 행 수 검증 → Cloudflare origin/터널 전환 → 롤백 = 동결 창 내 origin 되돌림 → v1 VM 7일 보존. `git revert`로 되돌릴 수 없는 유일한 단계.

### 5.6 운영·관측·플랫폼
- 관측 최소: Notifications(위) + Grafana Cloud Free + Alloy(k8s-monitoring 차트) — 클러스터 내 RAM 거의 0. 대안 VictoriaMetrics 단일(~300–500 MB). **kube-prometheus-stack 설치 금지**. Argo Rollouts는 replica 2+·실트래픽 이후(SP-4).
- K3s 업그레이드: `bootstrap/system-upgrade/`, Plan `version` 핀(채널 아님), `cordon: true`, 단일 노드는 `drain` 없음(drain은 컨트롤러까지 축출), 감시 가능한 window, OS는 unattended-upgrades. replicas=1인 동안 PDB 금지, HPA 범위 밖 명시, requests 필수·memory limit·CPU limit 없음.
- 런북 부재(constitution Observability-Ready 위반): R1 응급 변경(일시정지→변경→PR→재활성, 시간 제한) · R2 이미지 롤백(revert, 예상 복구 시간, GHCR 잔존 확인) · R3 클러스터 복구 · R4 DB 복구/마이그레이션 취소 · R5 시크릿 회전. plan 템플릿에 "런북 갱신" 필수 항목.
- 환경 모델·테스트 위치: 원문 `dev`는 merge 후 상시 환경인데 spec은 E2E(tester)를 merge 전에 요구. → `dev`는 feature 브랜치 용어로 남기고 merge 후 환경은 **`staging`**(향후 develop/release/main 3단 승격과도 정합). 테스트 3단: PR = unit + contract + E2E(ephemeral: web은 프리뷰 URL, API는 러너의 `docker compose` 또는 k3d) / main = staging 자동 배포 + tester 스모크 / promote PR = prod. constitution Test-First 절에 E2E 위치 명시.
- 롤백은 레이어별: `docs/runbooks/rollback.md` 매트릭스 — web `wrangler rollback <id>`(전제: DO lifecycle 미변경, 바인딩 존재) / API promote PR revert(전제: 스키마 하위 호환) / DB forward-fix만(contract는 expand와 다른 PR) / Cloudflare 바인딩·설정은 코드와 별도 PR. 모든 SP-3 plan 수용 기준에 "staging에서 롤백 리허설".
- 멀티테넌트는 배포 레이아웃에 넣지 않음(테넌트 격리는 앱 계층: tenant_id·claims·rate limit). 지금 유지할 훅은 "환경당 ns 1 + AppProject 1"뿐. 테넌트별 overlay/ApplicationSet/vcluster는 SP-4 이후.
- 분리 repo vs `deploy/` 경로: 분리 유지(CI 토큰이 소스 repo 쓰기 권한을 갖지 않음, CI 루프 없음, bootstrap 동거). 학습 노트 템플릿에 "Deploy record"(promote PR URL + digest) 필수 절을 `/finish` 게이트로 강제. 모노레포로 접을 땐 `paths-ignore: ['deploy/**']`.

---

## 6. SP-1 / SP-3 결정 항목 (트레이드오프 + 추천)

| # | 결정 | 옵션 (장점 / 단점) | 추천 | 시점 |
|---|---|---|---|---|
| D0 | OCI 테넌시 | Always Free 2/12 유지(0원 / 빠듯) · PAYG 전환(4/24 유지 보고 / 비공식, 과금 위험) · 유료 노드 4/24(여유 / ≈$50/월) | **먼저 확인**, 인스턴스 종료 금지 | 지금 |
| D1 | 런타임 트랙 | A Cloudflare-native(무운영 / K8s 학습 0) · **B1** web CF + API K3s·Argo(학습·SaaS 규율 / 최대 YAML·RAM) · **B2** web CF + API compose-pull(운영비 1/5 / 드리프트 감지·롤링 없음) · C 전부 K3s(기각: 무료 CDN 포기) | B, **B2 → B1** 순서(관측이 생겨 정당화될 때) | SP-1 |
| D2 | repo 공개 | **public**(ruleset·attestation·CodeQL·arm64 무료, LiP / 호스트명 노출) · Pro $4 private(ruleset만) · Free private(게이트 없음) | public | SP-1 |
| D3 | 환경 모델 | prod-only + PR 체크(최저비 / 리허설 불가) · **`staging` ns `replicas: 0` 기본**(리허설 가능 / 관리 1개 더) · dev+prod 상시(12 GB 불가) | staging scaled-to-zero + ResourceQuota | SP-3 |
| D4 | CD 엔진 | **Argo CD non-HA trimmed**(dex·applicationset off, notifications on, requests 명시, UI=터널+Access; ~0.5–0.7 GiB 추정) · Argo core(최소 / UI·알림 없음) · Flux 2.9(SOPS 내장, 이미지 자동화 GA, ~0.2–0.3 GiB / UI 없음) | Argo trimmed(UI가 학습 자산); RAM 압박 실측 시 Flux | SP-3 |
| D5 | 시크릿 | **Sealed Secrets** · ESO+OCI Vault · SOPS/KSOPS | Sealed 지금, ESO SP-4(ADR에 후계로 기록) | SP-3 |
| D6 | 엣지 | **cloudflared tunnel + Access** · Traefik + cert-manager DNS-01 공개 IP | tunnel | SP-3 |
| D7 | Postgres | **Neon Free** · CNPG · OCI ADB | Neon SP-2/3, CNPG SP-4 | SP-1/2 |
| D8 | 승격 자동화 | **CI-writes-Git + promote.yml** · Image Updater 1.3 · Source Hydrator(3.5 beta) · Flux image automation | CI-writes-Git; Hydrator는 Helm 템플릿 앱 생기면 재검토 | SP-3 |
| D9 | web CI 엔진 | Workers Builds(YAML 0, 프리뷰 무료 / OIDC 없음, Actions 밖) · **Actions + `wrangler-action`**(한 트리, 한 정책 / 프리뷰 코멘트 자작) · 둘 다 | Actions; 분 소진 시 Builds 병행 | SP-1/2 |
| D10 | 이미지 아키텍처 | arm64 단일 네이티브 · **multi-arch 두 네이티브 job**(public이면 무료) · QEMU | public이면 multi-arch, private이면 arm64 단일 | SP-3 |

---

## 7. 권고 구조

### 7.1 3계층 + 두 레인
- **L1 배포 원칙**(스택 중립, `docs/decisions/0002-deployment-principles.md`, 지금): §1 표 전체 + "CI는 런타임 자격증명을 갖지 않는다(단 Cloudflare 레인은 OIDC 부재로 스코프 토큰)".
- **L2 컨테이너 공급망**(컨테이너를 쓸 때): GHCR public, digest, `platforms`, provenance/attestation Tier 0–1, 보존 정책, SHA 핀, 스캔.
- **L3 GitOps/Argo CD 레인**(SP-1이 API를 K3s에 두면): 원문의 Argo CD·Kustomize·AppProject·롤링·마이그레이션 절을 §4·§5로 수정한 것.
- **Lane W (Cloudflare Workers/Pages)**: PR = `wrangler versions upload`(프리뷰, tester E2E 대상) · main = `wrangler deploy` 또는 `versions upload` + `versions deploy` %(prod) · rollback = `wrangler rollback`(바인딩·DO 변경은 별도 PR) · 최소권한 = Worker 단위 "Workers Scripts: Edit" 토큰, environment secret, 주기 회전. web/API 버전 skew 규칙: API는 한 릴리스 동안 하위 호환(expand/contract는 API 계약에도 적용).
- 후속 ADR: `0003-runtime-track`(SP-1) · `0004-cd-engine-and-promotion`(SP-3, 0003 조건부) · `0005-gitops-repo-layout`(SP-3). 0000/0001은 spec FR-011이 예약.

### 7.2 디렉터리 트리

```
joshuatech_ver2/
├── apps/
│   ├── web/                       # Next.js → Lane W (Workers/Pages), wrangler.jsonc 여기
│   └── api/                       # FastAPI + uv, apps/api/Dockerfile (linux/arm64)
├── specs/                         # Spec Kit (기존)
├── docs/
│   ├── decisions/0002~0005-*.md   # §7.1 ADR
│   └── runbooks/
│       ├── deploy-and-promote.md  # 이 정책의 운영 절반
│       ├── rollback.md            # 레이어별 매트릭스: web / API / DB / CF 바인딩
│       ├── incident-pause-autosync.md
│       ├── restore-drill.md
│       └── v1-data-cutover.md
├── infra/
│   ├── oci/                       # OpenTofu (VM/VCN/security list), compose (이행 Step 1–2)
│   ├── cloudflare/                # DNS/R2/Tunnel/Access as code
│   └── k3s/                       # config.yaml(--secrets-encryption, cluster-init, disable), bootstrap 스크립트 (L3)
└── .github/workflows/
    ├── ci.yml                     # PR: lint/test/build/E2E(ephemeral), push·배포 없음
    ├── publish-api.yml            # main: arm64 native build → digest push → attest → GitOps staging bump (GitHub App, concurrency)
    ├── deploy-web.yml             # PR: versions upload(프리뷰) / main: wrangler deploy (environment 게이팅은 여기서만 유효)
    └── ghcr-cleanup.yml           # 주간 보존 (keep-n 30, prod-current 태그 보호)
```

```
platform-gitops/                   # public
├── bootstrap/
│   ├── argocd/                    # kustomize remote base v3.5.x + patches (dex/applicationset off, requests), syncOptions: [ServerSideApply=true]
│   ├── sealed-secrets/
│   ├── cloudflared/               # 2 replicas, tunnel token = SealedSecret
│   ├── traefik/helmchartconfig.yaml   # K3s 번들 Traefik v3 값 오버라이드 (대시보드 off) — 2중 설치 금지
│   └── system-upgrade/            # K3s Plan, version 핀, cordon only, window
├── clusters/oci-k3s/              # 클러스터 1개, 네임스페이스로 분리 (원문 oci-k3s-prod 개명)
│   ├── root-app.yaml              # 유일한 수동 kubectl apply; Delete=confirm
│   └── projects/{platform,staging,prod}.yaml   # AppProject; default 무력화(sourceRepos: [], destinations: [])
├── apps/api/
│   ├── base/{deployment,service,migrate-job,networkpolicy,kustomization}.yaml
│   └── overlays/{staging,prod}/kustomization.yaml   # images[].digest; staging replicas: 0 기본
├── policies/                      # default-deny NetworkPolicy, PSA 라벨, ResourceQuota, 169.254.169.254 차단
├── README.md                      # → docs/runbooks/deploy-and-promote.md 링크
└── .github/workflows/
    ├── validate.yml               # kustomize build + kubeconform + diff 코멘트 (required status check); bot의 prod 변경 차단
    └── promote.yml                # workflow_dispatch: staging digest → prod PR 생성 (attestation verify 포함)
```

### 7.3 v1 → v2 이행 (사이트 유지, 단계별 되돌림 가능, 각 단계가 학습 노트)
0. 테넌시 할당 확인 · **인스턴스 종료 금지** · 데이터 인벤토리(DB 위치, R2, Dragonfly).
1. **compose 그대로**(SP-1 무관, 지금 가능): PR/main 분리 · `GITHUB_TOKEN`(`packages: write`, classic PAT 폐기) · `docker/metadata-action` `type=sha` + digest · 액션 SHA 핀 + Dependabot · Traefik `api.insecure` off · `log.level` INFO · compose가 digest 참조.
2. **SSH push → pull**: systemd timer 또는 Komodo가 GitOps repo의 digest 고정 compose를 pull → `docker compose up -d`. Actions에서 SSH 키·`.env` heredoc 제거, 시크릿은 VM에서 sops+age로 복호. 이 시점에 원문 보안 블록 4개 중 "Argo CD만 apply"를 뺀 3개 충족.
3. (SP-1이 K3s면) 같은 VM에 single-node K3s 병행(다른 포트) → Argo CD prod overlay → 터널 전환 → compose 1주 보존 후 제거.
4. 데이터 컷오버 런북 실행(§5.5) → Dragonfly/worker가 클러스터에 들어간 뒤 2번째 VM 정리.

### 7.4 지연 목록(트리거 명시)과 운영 부담 추정
| 항목 | 처분 | 트리거 |
|---|---|---|
| Renovate/Dependabot | **먼저** | 1인 운영을 지속 가능하게 하는 전제 |
| attestation(SLSA L2) | SP-3 | repo public 되는 순간(30분 작업) |
| 전체 SBOM 소비·Kyverno verifyImages | 보류 | 정책 엔진이 서명을 소비할 때(Kyverno ~200 MiB+) |
| Argo Rollouts/자동 롤백 | SP-4 이후 | replica 2+ & 실트래픽 |
| 상시 staging/dev | 없음 | 이 쿼터에선 영원히 없음 |
| ESO + OCI Vault | SP-4 | 멀티테넌트 격리 설계 |
| CNPG | SP-4 | 테넌트 격리 또는 Neon 한도(0.5 GB/2 CU) |
| Sync Windows | 컷오버 시 | 무료, platform 프로젝트 |
| 정책 엔진(`policies/` Kyverno/OPA) | 보류 | 지금은 NetworkPolicy·PSA·kustomize base로 충분 |
| Source Hydrator / Kargo | 재검토 | Helm 템플릿 앱 / 다단계 승격 필요 시 |

운영 부담(추정치): **B2** compose-pull ≈ 1–2 h/월 · **B1** single-node K3s + Argo CD ≈ 4–8 h/월(K3s 패치 월 1 + minor ~4개월, Argo CD 분기, 운영자 Renovate, 백업 점검, 드릴 1회) + 구축 20–40 h.

### 7.5 v1 → v2 보안 폐기 목록
| v1 | v2 | 강제 수단 |
|---|---|---|
| Actions의 SSH 키(`appleboy/*`) | 없음(pull 기반) | 워크플로에서 삭제 |
| `.env` heredoc에 시크릿 | SealedSecret / `secretKeyRef` | 정책 + 스캔 |
| classic PAT `GHCR_TOKEN` | `GITHUB_TOKEN` `packages: write` | 워크플로 |
| Traefik `api.insecure: true` 공개 대시보드 | 대시보드 off; 필요 시 Access/port-forward만 | HelmChartConfig |
| `log.level: DEBUG` | INFO + access log stdout | 설정 |
| `docker.sock` 마운트 | 금지(containerd.sock hostPath 포함) | PSA baseline/restricted |
| `:latest` | digest | kustomize `digest:` + validate |
| `@v4` 태그 핀 | 40자 SHA + Dependabot | repo 정책 "SHA 핀 강제" |
| `restart: always` | Deployment + probe 3종 + `minReadySeconds` | base manifest |
| push 시마다 prod 배포 | PR 검증 / main 발행 / PR 승격 | ruleset |

---

## 8. SP-1 설계 시 사용법

- **트랙별 생존 절**: A Cloudflare-native → L1 + Lane W만(§4·§5의 K3s 절 전부 무효, 시크릿은 `wrangler secret`/Secrets Store, Access). B1 하이브리드 → 전부. B2 하이브리드 → L1 + L2 + Lane W + §7.3 Step 1–2(Argo CD·AppProject·훅 절은 보류).
- **SP-1이 답해야 하는 질문**(§6 D0–D2·D7·D9, 순서대로): 테넌시 할당 → repo 공개 → 런타임 트랙 → web 호스팅(Pages vs Workers static assets: 점진 배포·Logs는 Workers만) → DB.
- **SP-3 plan 수용 기준에 넣을 것**: 런북 갱신, staging 롤백 리허설, E2E 위치, config expand/contract 준수, "Deploy record" 학습 노트 절.
- **재확인 항목**(수치 만료 가능): OCI Always Free 한도·PAYG 정책, GitHub 플랜별 기능표, Argo CD 지원 minor, K3s 번들 Traefik 버전, Workers Builds 한도, wrangler OIDC 지원 여부.

---

## 9. 출처 (1차, 2026-08-26 확인)

- OCI: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm · https://docs.oracle.com/iaas/Content/FreeTier/resourceref.htm · https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/ · https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm
- GitHub: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments · https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets · https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews · https://docs.github.com/en/get-started/learning-about-github/githubs-plans · https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry · https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-packages/about-billing-for-github-packages · https://docs.github.com/en/actions/concepts/security/github_token · https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations · https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax · https://github.com/actions/create-github-app-token · https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/ · https://github.blog/changelog/2025-10-28-immutable-releases-are-now-generally-available/ · https://github.blog/changelog/2026-01-29-arm64-standard-runners-are-now-available-in-private-repositories/
- Argo CD: https://argo-cd.readthedocs.io/en/latest/user-guide/auto_sync/ · https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/ · https://argo-cd.readthedocs.io/en/latest/user-guide/sync-waves/ · https://argo-cd.readthedocs.io/en/latest/user-guide/projects/ · https://argo-cd.readthedocs.io/en/stable/user-guide/ci_automation/ · https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/security/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/secret-management/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/ · https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/overview/ · https://argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/2.14-3.0/ · https://argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/3.2-3.3/ · https://argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/3.4-3.5/ · https://argo-cd.readthedocs.io/en/latest/user-guide/source-hydrator/ · https://argocd-image-updater.readthedocs.io/en/stable/ · https://github.com/argoproj/argo-cd/releases
- K3s/Kubernetes: https://docs.k3s.io/installation/requirements · https://docs.k3s.io/networking/networking-services · https://docs.k3s.io/security/secrets-encryption · https://docs.k3s.io/security/hardening-guide · https://docs.k3s.io/datastore/backup-restore · https://docs.k3s.io/cli/etcd-snapshot · https://docs.k3s.io/upgrades/automated · https://docs.k3s.io/release-notes/v1.36.X · https://kubernetes.io/docs/concepts/workloads/controllers/deployment/ · https://kubernetes.io/docs/tasks/run-application/configure-pdb/ · https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/images/
- Cloudflare: https://developers.cloudflare.com/pages/ · https://developers.cloudflare.com/workers/ci-cd/builds/limits-and-pricing/ · https://developers.cloudflare.com/workers/ci-cd/builds/git-integration/github-integration/ · https://developers.cloudflare.com/workers/configuration/versions-and-deployments/gradual-deployments/ · https://developers.cloudflare.com/workers/configuration/versions-and-deployments/rollbacks/ · https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/kubernetes/ · https://developers.cloudflare.com/dns/manage-dns-records/reference/ttl/
- 기타: https://external-secrets.io/latest/provider/oracle-vault/ · https://github.com/bitnami-labs/sealed-secrets · https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/ · https://docs.docker.com/build/ci/github-actions/attestations/ · https://github.com/actions/attest-build-provenance · https://github.com/dataaxiom/ghcr-cleanup-action · https://github.com/snok/container-retention-policy · https://fluxcd.io/blog/2025/09/flux-v2.7.0/ · https://neon.com/docs/introduction/plans · https://grafana.com/pricing/ · https://endoflife.date/argo-cd · https://endoflife.date/kubernetes · https://komo.do/docs/intro
