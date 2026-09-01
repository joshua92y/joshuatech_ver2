---

description: "Task list for 003-platform-foundation (joshuatech override: tests mandatory, E2E per story)"
---

# Tasks: 플랫폼 기반 (SP-1)

**Input**: Design documents from `/specs/003-platform-foundation/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests are MANDATORY (constitution II. Test-First). Every user story phase MUST contain (a) test tasks written and observed failing BEFORE implementation tasks and (b) exactly one E2E task per story, executed by the `tester` agent from the user's point of view. Do not omit these sections.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. 스토리 순서는 의존성 순(plan Implementation Approach ①–⑩)이며 우선순위(P1/P2)는 spec 그대로다: US1 문서 → US2 클러스터 → US3 데이터·이벤트 → US6 pod 템플릿(로컬 검증 가능, US4가 identity-admin을 필요로 함) → US4 신원 → US5 웹 → US7 관측·RAM → US8 v1 정리 → US9 에이전트 계층.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions
- 서브에이전트 배정 힌트: `infra-builder`(OpenTofu·gitops·K3s·플랫폼 컴포넌트), `api-builder`(packages·templates·identity-admin), `web-builder`(packages/content·apps/web), 컨트롤러(문서·사용자 수동 단계·E2E 디스패치). 각 서브에이전트에는 task 줄 + 해당 contracts/quickstart 절만 준다.

## Path Conventions

- 모노레포: `apps/web`, `apps/identity-admin`, `packages/{content,events,authz,django-common}`, `templates/django-pod`, `infra/{oci,cloudflare,vault,grafana,bootstrap}`, `docs/{decisions,runbooks,kr}`, `.claude/{rules,agents,skills}`, `.github/workflows`
- 별도 저장소 `platform-gitops`(public): `bootstrap/`, `clusters/oci-k3s/`, `platform/<component>/`, `apps/<pod>/{base,overlays/dev,overlays/prod}`, `secrets/`, `.github/workflows/`
- Test files MUST live under `tests/`, `e2e/`, `__tests__/` or be named `*.test.*` / `*.spec.*` (the tester agent may only write there): 저장소 검사 `tests/**/*.tests.ps1`, 플랫폼 검사 `tests/platform/*.tests.ps1`(KUBECONFIG 없으면 SKIP), Python `packages/*/tests/`·`apps/*/tests/`·`templates/django-pod/tests/`, TS `packages/content/tests/`·`apps/web/**/*.test.*`, 브라우저 `e2e/*.spec.ts`
- 사용자 수동 단계(계정 온보딩·결제수단·GitHub App 생성)는 task로 적되 컨트롤러가 사용자에게 요청하고 완료를 확인한다. 파괴적 단계(재이미지·Render/Fly 삭제·DNS 제거)는 실행 직전 사용자 재확인(헌법 플랫폼 제약).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 모노레포·gitops 저장소·도구 뼈대와 사용자 계정 준비

- [ ] T001 모노레포 워크스페이스 뼈대: 루트 `package.json`(node 22, pnpm 10)·`pnpm-workspace.yaml`(apps/web, packages/content, packages/events), 루트 `pyproject.toml`(uv workspace: packages/django-common, apps/identity-admin, templates/django-pod)·`uv.lock`, `.editorconfig`, `.gitignore`(tfstate·.venv·.open-next·.wrangler·env 파일), 빈 디렉터리 `apps/ packages/ templates/ infra/ e2e/` + README 스텁
- [ ] T002 [P] `renovate.json`(`config:best-practices`, argocd·kubernetes `managerFilePatterns`, `ghcr.io/joshua92y/**` 제외, pep621 uv lockFileMaintenance, helm values, github-actions SHA 핀) + `.github/workflows/ci.yml` 골격(`runs-on: ubuntu-24.04-arm`, job `gitleaks`(gitleaks-action v3, fetch-depth 0)·`lint`·`test` 자리, 모든 액션 SHA 핀 + 주석)
- [ ] T003 [P] platform-gitops 저장소 생성(`joshua92y/platform-gitops`, public) + contracts/gitops-repo.md 트리(빈 kustomization·README) + `.github/workflows/validate.yml` 골격 + ruleset JSON(`platform-gitops/.github/ruleset-main.json`: PR 필수·required check `validate`·0 approvals·bypass = GitHub App) — GitHub App `jt-ci`(contents·pull_requests write, metadata read) 생성·두 repo 설치·`JT_CI_APP_CLIENT_ID` vars·`JT_CI_APP_PRIVATE_KEY` secret 등록은 **사용자 수동**
- [ ] T004 [P] 저장소 검사 러너 확장: `tests/platform/run-platform-tests.ps1`(KUBECONFIG·ARGOCD_SERVER 없으면 SKIP 요약, 있으면 `tests/platform/*.tests.ps1` 실행) + `tests/run-all.ps1`에 `platform`(SKIP 허용)·`adr-madr` 체크 자리 추가(검사 본체는 US1 테스트에서 작성)
- [ ] T005 [P] 사용자 수동 준비 목록을 `docs/runbooks/bootstrap.md` §0으로 작성하고 완료를 확인: Cloudflare Zero Trust 온보딩(팀 이름 `joshuatech`, 결제수단 등록·청구 없음), Grafana Cloud Free 스택(ap 리전)·Access policy 토큰, Sentry Developer org + 프로젝트 2, OCI 서비스 사용자 `svc-tfstate`·`svc-s3-backup`의 Customer Secret Key(각 1), GitHub secret scanning + push protection 활성 — 값은 Vault 투입 전까지 비밀번호 관리자에만 둔다(저장소·채팅 금지)
- [ ] T006 [P] 인프라 test-first: `tests/infra/tofu.tests.ps1` — `tofu validate`(oci·cloudflare) 통과, `tofu plan -detailed-exitcode`에 destroy/replace 0, `tofu show -json`으로 NSG 노드 A ingress가 443/tcp × Cloudflare CIDR만·노드 B ingress 0·인스턴스 `prevent_destroy`·버킷 versioning·KMS `SOFTWARE`·IMDS v1 비활성 단언; `tests/platform/run-platform-tests.ps1`에서 `infra` 그룹으로 실행 — 지금은 FAIL 확인(구성 없음)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: OpenTofu 정본, 인스턴스 재이미지, 네트워크·버킷·KMS·IAM, Cloudflare 기본, v1 배포 차단 — 모든 스토리의 전제

**⚠️ CRITICAL**: No user story work can begin until this phase is complete (US1·US9 문서 작업만 예외적으로 병렬 가능)

- [ ] T007 `infra/oci` 백엔드 부트스트랩: `oci os bucket create --name jt-tfstate --versioning Enabled --public-access-type NoPublicAccess`, `backend "s3"`(endpoints.s3 compat URL, region ap-chuncheon-1, `skip_region_validation`·`skip_credentials_validation`·`skip_requesting_account_id`·`skip_metadata_api_check`·`skip_s3_checksum`·`use_path_style` = true, `use_lockfile` off), `AWS_REQUEST_CHECKSUM_CALCULATION=when_required` env, `tofu init -migrate-state` → `infra/oci/{versions.tf,backend.tf,providers.tf}` (required_version >= 1.12.6, oracle/oci ~> 8.29, cloudflare ~> 5.24)
- [ ] T008 `infra/oci` 기존 리소스 import: `import {}` 블록(인스턴스 2, VCN, 서브넷, IGW, 라우트 테이블, 보안 리스트) + `tofu plan -generate-config-out` 1회 → 정리된 `instances.tf`·`network.tf`, `lifecycle { prevent_destroy = true, ignore_changes = [metadata, defined_tags, create_vnic_details[0].hostname_label] }`, `plan` diff 0 확인 후 커밋(import 블록 유지)
- [ ] T009 `infra/oci/network.tf`: NSG `nsg-node-a-platform`(443/tcp ← `data.cloudflare_ip_ranges.ipv4_cidrs` for_each) + `nsg-cluster`(자기참조 all) + 서브넷 보안 리스트 egress-only, 인스턴스 `create_vnic_details.nsg_ids` 갱신; reserved 퍼블릭 IP 2개 생성·기존 ephemeral 교체(주소 변경을 `docs/runbooks/bootstrap.md`에 기록); IPv6 미사용 명시
- [ ] T010 [P] `infra/oci/{storage,kms,iam,budget}.tf`: 버킷 `jt-backup`(versioning) · IAM 그룹/정책(`svc-s3-backup` manage objects on jt-backup·jt-tfstate) · KMS Vault(DEFAULT) + AES-256 키(`protection_mode = SOFTWARE`, 회전 off) · 동적 그룹 `jt-k3s-nodes`(인스턴스 OCID 2) + 정책 `use keys … where target.key.id` · Budgets 35 SGD + alert 4(ACTUAL 10/50/100%, FORECAST 100%) · 인스턴스 `instance_options.are_legacy_imds_endpoints_disabled = true` — 출력: kms key_id·crypto/management endpoint·bucket namespace
- [ ] T011 [P] `infra/cloudflare`: provider 5.24 — `zone_settings.tf`(ssl strict, always_use_https on, min_tls 1.2, `tls_client_auth` on = global AOP), `access.tf`(GitHub IdP, 재사용 정책 `svc-auth-dev/prod`(non_identity + service_token)·`admin-github`(allow email + login_method), 앱 `argo`·`vault`·`traefik`·`admin`·`identity-m2m-prod`·`identity-m2m-dev`·`ssh`·`k8s`, 서비스 토큰 `web-bff-dev`·`web-bff-prod`, `service_auth_401_redirect`), `r2.tf`(버킷 `jt-public` apac + 커스텀 도메인 `cdn.joshuatech.dev`), `tunnel.tf`(remote-managed 터널 + config ingress `ssh://<A private IP>:22`·`ssh://<B private IP>:22`·`tcp://kubernetes.default.svc.cluster.local:443` + CNAME `ssh-a`·`ssh-b`·`k8s`), `dns.tf`(A 레코드 `auth`·`identity-m2m-prod`·`identity-m2m-dev`·`admin`·`argo`·`vault`·`traefik` → 노드 A reserved IP, proxied — 기존 v1 `admin`·`traefik` 레코드는 `import` 블록으로 가져와 값만 교체, `api`·`mainapi`는 US8까지 v1 오리진 유지) — 서비스 토큰·터널 토큰 출력은 sensitive, Vault 투입 전 로컬 보관
- [ ] T012 v1 배포 차단: `joshua92y/joshtech`의 워크플로 4개(`deploy-fastapi-ghcr`·`deploy-django-ghcr`·`deploy-dragonfly-worker`·`deploy-nextjs-ghcr`)를 `on: workflow_dispatch`만 남기도록 PR → 머지, Render 자동 배포 훅 비활성 — **사용자 재확인 후** 실행, 결과를 `docs/runbooks/bootstrap.md` §1에 기록
- [ ] T013 재이미지 리허설(노드 B `joshtech_cache`, **사용자 재확인 후**): `oci compute instance get`으로 현재 이미지 OS 확인(Ubuntu여야 함) → `instances.tf` `source_details.source_id` = `ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a`(Canonical-Ubuntu-24.04-aarch64-2026.07.17-0, 변수 고정), `boot_volume_size_in_gbs = 100`, `is_preserve_boot_volume_enabled = true`, `update_operation_constraint = "ALLOW_DOWNTIME"` → `tofu plan`에 destroy/replace 0·in-place update 1 확인 → apply → 임시 NSG 22 규칙(운영자 IP)으로 SSH → `lsb_release -a` 24.04 확인 → 구 부트 볼륨 삭제 → 임시 규칙 제거
- [ ] T014 노드 A `joshtech_api_1st` 재이미지(T013 절차 반복) + `infra/bootstrap/host-prep.sh`(두 노드: `/etc/iptables/rules.v4`의 REJECT 앞에 6443·8472/udp·10250·파드 CIDR 규칙 삽입 + `netfilter-persistent reload`, cgroup v2 확인, `sqlite3`·`rclone` 설치, unattended-upgrades security only, 시간대 Asia/Seoul) 실행·결과 기록
- [ ] T015 [P] 코드 뼈대(내용 없음): `packages/events/{package.json,schemas/,scripts/}`, `packages/authz/model.fga`(초기 모델), `packages/django-common/{pyproject.toml,src/django_common/__init__.py}`, `templates/django-pod/copier.yml`(질문 7개: pod_name·pod_snake·description·owns_events·consumes_events·has_celery·has_admin) + `template/` 빈 트리, `packages/content/{package.json,src/}` — 각 워크스페이스가 `pnpm -r build`/`uv sync`로 통과

**Checkpoint**: 인스턴스 2대 Ubuntu 24.04·reserved IP·NSG, OpenTofu 상태 원격, Cloudflare Access/터널/R2 선언, v1 배포 차단, 저장소 뼈대

---

## Phase 3: User Story 1 - 아키텍처 결정의 문서화 (Priority: P1) 🎯 MVP(문서)

**Goal**: ADR 0002–0010, `.specify/memory/{product,architecture}.md`, docs 색인이 MADR 검사를 통과하고 spec·plan에서 링크된다.

**Independent Test**: `pwsh -NoProfile -File tests/run-all.ps1`의 `adr-madr` 체크 PASS, `docs/README.md`에 9개 링크, memory 2 파일 존재.

### Tests for User Story 1 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T016 [P] [US1] `tests/decisions/madr.tests.ps1`: `docs/decisions/00{02..10}-*.md` 9개 존재, frontmatter `status: accepted`·`date`·`decision-makers`, 절 4개(Context and Problem Statement / Considered Options / Decision Outcome / Consequences), Considered Options ≥ 3, `docs/README.md` 링크 9 — `run-all` 체크 `adr-madr`로 연결, 지금은 FAIL 확인
- [ ] T017 [P] [US1] `tests/memory/memory-docs.tests.ps1`: `.specify/memory/product.md`(절: 목표·도메인·pod 목록·로드맵)·`architecture.md`(절: 토폴로지·경계·계약·운영 원칙) 존재·비어 있지 않음·`<!-- SPECKIT` 블록 밖 — FAIL 확인

### Implementation for User Story 1

- [ ] T018 [P] [US1] `docs/decisions/0002-deployment-principles.md` — L1 원칙 7(불변 digest·Git 정본·pull CD·CI 무자격증명(Cloudflare 예외 스코프 토큰)·PR 검증/main 발행·rollback=revert·expand→contract), 대안 SSH push·:latest·수동 배포
- [ ] T019 [P] [US1] `docs/decisions/0003-runtime-track.md` — 웹 Workers + API OCI K3s 2노드(A platform/B data) + Argo CD; 대안 Cloudflare-native·compose-pull·전부 K3s; RAM 예산·전환 트리거
- [ ] T020 [P] [US1] `docs/decisions/0004-web-framework.md` — Next.js 16.3 + OpenNext lean(프리렌더 + BFF, 번들 예산 2.5 MiB, 페이지 GET Worker 경유 수용, $5 탈출구, RSC prefetch 이슈 핀 규칙); 대안 Astro·SvelteKit·정적 export + Hono·vinext
- [ ] T021 [P] [US1] `docs/decisions/0005-backend-framework-policy.md` — Django 6.1 + Ninja 1.7 기본, FastAPI 예외 트리거(연결 수·fan-out·I/O 대기)와 all-async 약속, Celery/taskiq 규칙; 대안 FastAPI 단일·Hono·Python Workers
- [ ] T022 [P] [US1] `docs/decisions/0006-identity-and-authz.md` — Authentik 단일 IdP·provider별 aud·RFC 8693·BFF=게이트웨이·세션 정본 Authentik + refresh 쿠키·즉시 폐기(이벤트 + Dragonfly 거부 목록)·OpenFGA 교차 컨텍스트·Access 이중; 대안 Better Auth·Clerk·자체 세션 서비스·introspection
- [ ] T023 [P] [US1] `docs/decisions/0007-data-ownership-and-tenancy.md` — CNPG 1 클러스터·DB per pod·owner/app role·tenant_id + FORCE RLS + SET LOCAL·barman-cloud; 대안 Neon·Supabase·D1·스키마 분리·앱 계층만
- [ ] T024 [P] [US1] `docs/decisions/0008-event-backbone.md` — Kafka KRaft(Strimzi)·폴링 outbox 릴레이·CloudEvents JSON + JSON Schema·토픽 규약·Redpanda/Debezium 트리거; 대안 Dragonfly Streams·Redpanda·Debezium·Avro
- [ ] T025 [P] [US1] `docs/decisions/0009-search.md` — ES 1노드 + Kibana + Nori·ECK·FastAPI search pod(SP-3), pg_bigm 이월; 대안 Postgres FTS·Pagefind·OpenSearch
- [ ] T026 [P] [US1] `docs/decisions/0010-secrets.md` — HashiCorp Vault Raft + OCI KMS(SOFTWARE 키) auto-unseal + ESO·경로 규약·부트스트랩 순서·Shamir 비상 절차; 대안 Sealed Secrets·SOPS+age·OpenBao·클러스터 내 unseal
- [ ] T027 [P] [US1] `.specify/memory/product.md` — 제품 목표·도메인(포트폴리오·블로그·학습 노트·문의·미디어·사용자)·pod 8개와 단계·로드맵 SP-1~4·비기능 목표(무료 티어·SaaS 규율)
- [ ] T028 [P] [US1] `.specify/memory/architecture.md` — 토폴로지·노드 배치·네임스페이스·경계(pod/DB/이벤트)·계약(BFF·identity-admin·events·gitops·pod 템플릿·호스트)·운영 원칙(관측·롤백·시크릿) — spec Design + contracts 요약, 실측치는 US7 뒤 갱신
- [ ] T029 [US1] `docs/README.md` 색인에 ADR 0002–0010·런북 자리 추가, spec.md §8 ADR 표에 파일 링크, `CLAUDE.md` Active Technologies 절 갱신(+`docs/kr/CLAUDE_kr.md` 미러), `tests/run-all.ps1` `adr-madr` 체크 활성 → T016·T017 PASS

### E2E for User Story 1 (MANDATORY — executed by the tester agent)

- [ ] T030 [US1] E2E: US1 AC1–AC2 — `tests/run-all.ps1` ALL PASS, ADR 9개가 대안 ≥ 2·결과 절을 갖고 `docs/README.md`·spec에서 링크되며 memory 2 파일이 spec Design과 모순 없음(표본 3항목 대조) — evidence recorded in the tester report

**Checkpoint**: 결정이 문서로 고정됨 — 이후 스토리는 ADR을 참조만 한다

---

## Phase 4: User Story 2 - 클러스터·GitOps·인그레스·시크릿 기반 (Priority: P1)

**Goal**: K3s 2노드, Argo CD root app, platform-gitops, cert-manager 와일드카드 + Traefik + AOP, cloudflared 관리 터널, Vault + ESO가 동작하고 재부팅 후 자동 복구된다.

**Independent Test**: quickstart §US2 — 노드 2 Ready, root app Synced/Healthy, `argo.` Access 302, 오리진 IP 직접 TLS 실패, `vault status` Sealed false/ocikms, ExternalSecret SecretSynced, gitleaks 0.

### Tests for User Story 2 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T031 [P] [US2] `tests/platform/cluster.tests.ps1`: `kubectl get nodes` 2 Ready + 라벨 `role=platform/data`, `svccontroller.k3s.cattle.io/enablelb` A만; Argo `applications` 전부 Synced/Healthy(ES 제외 목록); `appproject default` sourceRepos·destinations 빈 배열; `kubectl -n vault exec vault-0 -- vault status` Sealed=false·Seal Type=ocikms; `externalsecret -A` 전부 SecretSynced — FAIL 확인(클러스터 없음)
- [ ] T032 [P] [US2] `tests/platform/ingress.tests.ps1`: `https://argo.joshuatech.dev` → 302 Access 로그인; `curl --resolve <A IP>` 직접 TLS 핸드셰이크 실패; `kube-system/wildcard-joshuatech-dev-tls` Secret 존재·만료 > 30일; Traefik pod가 노드 A; `traefik.` 대시보드 Access 뒤 — FAIL 확인
- [ ] T033 [P] [US2] platform-gitops `validate.yml` 검사 스크립트 `platform-gitops/tests/validate.sh`: 모든 `kustomization.yaml` `kustomize build` + `kubeconform -strict -ignore-missing-schemas`, Application마다 `ServerSideApply=true` 존재, `ExternalSecret.remoteRef.key` 정규식 `^(platform|dev|prod)/…`, `images[].newTag` 금지, gitleaks — 빈 트리에서 FAIL(lint 대상 없음 → 명시적 실패 케이스 fixture) 확인
- [ ] T034 [P] [US2] `tests/platform/reboot.tests.ps1`: 노드 A 재부팅 후 5분 내 Vault unsealed·ESO ClusterSecretStore Ready·Argo Healthy(수동 트리거 파라미터 `-AfterReboot`) — FAIL 확인

### Implementation for User Story 2

- [ ] T035 [US2] `infra/bootstrap/k3s-server.sh` + `/etc/rancher/k3s/config.yaml`(노드 A): `INSTALL_K3S_VERSION=v1.36.4+k3s1`, `secrets-encryption: true`·`secrets-encryption-provider: secretbox`, `node-label: [role=platform, svccontroller.k3s.cattle.io/enablelb=true]`, `tls-san: [<A private IP>, k8s.joshuatech.dev]`, `token`(짧은 형식, Vault 보관) — 실행 후 `kubectl get nodes` 1 Ready, kubeconfig 임시 SSH 취득
- [ ] T036 [US2] `infra/bootstrap/k3s-agent.sh`(노드 B): `K3S_URL=https://<A private IP>:6443`, `token-file`(보안 형식 `K10…::server:…`), `node-label: [role=data]` → 2 Ready; `infra/bootstrap/k3s-backup.{sh,timer}`(FR-047: sqlite3 `.backup` + token + cred → `jt-backup`/k3s/, 7일 보존) 설치
- [ ] T037 [US2] system-upgrade-controller v0.20.1 Application(`platform/system-upgrade/`, ns `system-upgrade`) + Plan `k3s-server`·`k3s-agent`(channel `https://update.k3s.io/v1-release/channels/v1.36`, window 일요일 03:00–05:00 Asia/Seoul, concurrency 1, cordon, agent는 server 완료 대기) + 업그레이드 뒤 Traefik HelmChartConfig 값 스키마 확인 절차를 `docs/runbooks/bootstrap.md` §6에 (FR-048)
- [ ] T038 [P] [US2] Traefik `HelmChartConfig` `infra/bootstrap/traefik-config.yaml` → 노드 A `/var/lib/rancher/k3s/server/manifests/`: chart 40.1.x 키로 `nodeSelector: {role: platform}`, `logs.general.format: json`·`logs.access.enabled/format: json`, `tracing.otlp.grpc`(→ `k8s-monitoring-alloy-metrics.monitoring.svc:4317`, insecure), `ports.web.http.redirections.entryPoint`, `ports.websecure.forwardedHeaders.trustedIPs: [10.42.0.0/16]`, `tlsOptions.default`(초기 `VerifyClientCertIfGiven`, `secretNames: [cloudflare-origin-pull-ca]`, minVersion TLS12, sniStrict), 대시보드 IngressRoute(`traefik.` 호스트)
- [ ] T039 [US2] cloudflared: `platform-gitops/platform/cloudflared/`(Deployment 2 replica `cloudflare/cloudflared:2026.8.3`, `TUNNEL_TOKEN` secretKeyRef, required anti-affinity hostname, `--no-autoupdate --metrics 0.0.0.0:2000`) — 최초는 수동 Secret, T045 후 ExternalSecret; 로컬 `~/.ssh/config` ProxyCommand + `cloudflared access tcp` kubeconfig(`tls-server-name: kubernetes`) 전환 → 임시 22 규칙 제거, 절차를 `docs/runbooks/bootstrap.md` §2에
- [ ] T040 [US2] Argo CD bootstrap `platform-gitops/bootstrap/argocd/kustomization.yaml`(remote `install.yaml` v3.5.2, `$patch: delete` dex 6·applicationset 8, requests/GOMEMLIMIT, `argocd-cmd-params-cm`: `server.insecure`·`controller.diff.server.side`·processors, `argocd-cm`: Application 헬스 Lua·`timeout.reconciliation 180s`·`resource.exclusions` 유지) → `kubectl apply --server-side --force-conflicts -k` → `bootstrap/root-app.yaml` 적용
- [ ] T041 [US2] `platform-gitops/clusters/oci-k3s/`: AppProject `platform`(sourceRepos gitops + 차트 저장소, cluster whitelist)·`dev`·`prod`(자기 ns만, cluster 리소스 금지) + `default` 봉인 + `apps/` app-of-apps(Application per component, sync-wave -20…40, syncOptions 표준, `Prune=confirm`·`Delete=confirm` 상태 저장 앱) + `platform/policies/`(네임스페이스 `argocd vault external-secrets data identity observability jt-dev jt-prod` + PSA 라벨, default-deny NetworkPolicy, **IMDS egress 차단(`vault` 제외)**, ResourceQuota/LimitRange jt-dev·jt-prod) + `platform/argocd/`(자기 관리 Application, wave -20)
- [ ] T042 [US2] cert-manager: `platform/cert-manager/`(Application helm OCI `oci://quay.io/jetstack/charts/cert-manager` v1.21.1, `crds.enabled`, `dns01RecursiveNameservers` 1.1.1.1/8.8.8.8 Only, SSA) + `platform/cert-manager-issuers/`(별도 Application, wave +1, `SkipDryRunOnMissingResource`): ClusterIssuer `letsencrypt-staging`·`letsencrypt-prod`(Cloudflare DNS-01, `apiTokenSecretRef` = ExternalSecret `cloudflare-dns-token`) + Certificate `wildcard-joshuatech-dev`(kube-system, `joshuatech.dev`+`*.joshuatech.dev`, ECDSA P-256, `renewBeforePercentage 33`, 먼저 staging으로 발급 검증 후 prod 1회) + Traefik `TLSStore default` → Secret `wildcard-joshuatech-dev-tls`
- [ ] T043 [US2] AOP 강제: `authenticated_origin_pull_ca.pem` → Secret `cloudflare-origin-pull-ca`(kube-system, `ca.crt`; 만료 2029-11-01 캘린더) → 존 `tls_client_auth` on(T011) 확인 → HelmChartConfig `clientAuthType: RequireAndVerifyClientCert` 전환 → Argo CD Ingress(`argo.`, websecure, grpc-web) + Access 앱 뒤 접근 확인, 오리진 IP 직접 TLS 실패 확인(T032 일부 PASS)
- [ ] T044 [US2] Vault: `platform/vault/`(Application helm 0.34.1: `server.ha.enabled`·`ha.replicas 1`·`raft`, `dataStorage` local-path 5Gi, `nodeSelector role=platform`, HCL seal `ocikms`{key_id, crypto_endpoint, management_endpoint} + `disable_mlock=true`, `ui=true`, injector/csi off, resources) + `NetworkPolicy` IMDS 허용(vault ns만) → `vault operator init -recovery-shares=3 -recovery-threshold=2`(**사용자 입회**, recovery key·root 토큰 오프라인 보관) → `infra/vault/`(OpenTofu hashicorp/vault: kv v2 mount `kv`, `auth/kubernetes` config·role `external-secrets`(audience `vault`)·role `identity-admin`, 정책 `eso-read`·`pod-identity-admin`, OIDC auth method는 US4 뒤) → root 토큰 revoke 절차 `docs/runbooks/vault-unseal.md`
- [ ] T045 [US2] ESO: `platform/external-secrets/`(Application helm 2.10.0, SSA, replicas 1, nodeSelector platform) + `ClusterSecretStore vault-kv`(kubernetes auth, serviceAccountRef external-secrets, audiences [vault]) → 초기 kv 값 투입(`kv/platform/cloudflare/dns-token`·`/tunnel`·`kv/platform/access/*`·`kv/platform/oci/s3`·`kv/platform/grafana-cloud`(값은 사용자 보관분)) → `secrets/` ExternalSecret(cert-manager 토큰·cloudflared 토큰)으로 수동 Secret 교체 → T031 SecretSynced 항목 PASS
- [ ] T046 [US2] `platform-gitops/.github/workflows/validate.yml` 완성(T033 스크립트 실행, required check `validate`) + ruleset 적용(`gh api -X POST repos/joshua92y/platform-gitops/rulesets --input .github/ruleset-main.json`) + `promote.yml` 골격(workflow_dispatch `app` 입력 → dev digest → prod PR) + 모노레포 `ci.yml`에 kubeconform(templates/django-pod/deploy) 추가
- [ ] T047 [US2] 재부팅 리허설: 노드 A `sudo reboot` → `tests/platform/reboot.tests.ps1 -AfterReboot` PASS(Vault 자동 unseal·ESO Ready·Argo Healthy) → `docs/runbooks/bootstrap.md` §3(전체 순서·시간·시크릿 취급) 확정

### E2E for User Story 2 (MANDATORY — executed by the tester agent)

- [ ] T048 [US2] E2E: US2 AC1–AC5 — `tests/platform/{cluster,ingress,reboot}.tests.ps1` PASS, gitops validate.yml PASS + 시크릿 값 0(gitleaks 두 repo), `tofu plan`(oci·cloudflare) diff 0, 브라우저로 `argo.joshuatech.dev` Access → 임시 admin 로그인 — evidence recorded in the tester report

**Checkpoint**: 플랫폼 기반 완성 — 데이터·신원·앱 배포가 GitOps로 가능

---

## Phase 5: User Story 3 - 데이터·이벤트 플랫폼 (Priority: P1)

**Goal**: CNPG `pg-main`(pod별 DB·role, barman-cloud 백업), Strimzi Kafka(SCRAM·ACL 토픽), Dragonfly dev/prod가 gitops로 선언되어 동작한다.

**Independent Test**: quickstart §US3 — databases 3+, 교차 DB 접속 거부, ScheduledBackup completed + 버킷 오브젝트, KafkaTopic produce/consume 5초 내, 다른 사용자 write 거부, Dragonfly NOAUTH.

### Tests for User Story 3 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T049 [P] [US3] `tests/platform/data.tests.ps1`: `cluster pg-main` healthy(instances 1, 노드 B); `databases` identity_admin·authentik·openfga·dev_identity_admin Ready; `psql -U identity_admin_app -d authentik` permission denied; `identity_admin_app`이 `rolbypassrls=false`·`rolsuper=false`; `backup` completed ≥ 1; `oci os object list --bucket-name jt-backup --prefix pg-main/` base 오브젝트 — FAIL 확인
- [ ] T050 [P] [US3] `tests/platform/kafka.tests.ps1`: `kafka jt-kafka` Ready, `kafkanodepool` 1, `kafkatopic identity-admin.session.revoked`·`dev.identity-admin.session.revoked` Ready(partitions 3), `kafkauser identity-admin`·`dev-identity-admin` Ready; kcat(SCRAM-SHA-512, cluster CA) produce→consume 5초 내; `dev-identity-admin`으로 prod 토픽 write 거부; `auto.create.topics.enable=false`; `dragonfly-prod` `redis-cli ping` → NOAUTH, `--maxmemory` 768mb — FAIL 확인

### Implementation for User Story 3

- [ ] T051 [US3] `platform/cnpg/`: operator Application(helm `cnpg/cloudnative-pg` 0.29.0, ns `cnpg-system`, `ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES`, SSA, CRD `Prune=false` 어노테이션) + plugin-barman-cloud Application(helm 0.7.1, cert-manager 재사용) + `ClusterImageCatalog` standard-trixie vendoring(18.6 digest 고정)
- [ ] T052 [US3] `platform/cnpg-cluster/`(wave 후순위): Cluster `pg-main`(instances 1, `imageCatalogRef` major 18, storage local-path 40Gi, requests=limits 1 CPU/2Gi, `shared_buffers 512MB`·`max_parallel_workers 2`·`max_connections 100`, `affinity.nodeSelector role=data`, `enableSuperuserAccess false`, plugins barman-cloud isWALArchiver) + `ObjectStore oci-backups`(endpointURL compat, `destinationPath s3://jt-backup/pg-main/`, s3Credentials ExternalSecret `oci-s3-backup`(ACCESS_KEY_ID/SECRET/REGION), wal zstd, data lz4, `retentionPolicy 30d`, sidecar env `AWS_*_CHECKSUM_*=when_required`) + `ScheduledBackup`(`0 0 18 * * *`, immediate) → 첫 백업 completed 확인
- [ ] T053 [US3] `platform/cnpg-databases/`: `DatabaseRole` `identity_admin_owner`/`identity_admin_app`(bypassrls·superuser·createdb·createrole false, `passwordSecret` = ExternalSecret `kv/{env}/db/identity_admin/{owner,app}` basic-auth + `cnpg.io/reload`), `authentik_owner`·`openfga_owner`, `Database` `identity_admin`(owner, extensions vector)·`authentik`·`openfga`·`dev_identity_admin`, `databaseReclaimPolicy retain`; Vault kv 값 생성(랜덤) 절차 `docs/runbooks/bootstrap.md` §4
- [ ] T054 [US3] `platform/kafka/`: Strimzi operator Application(helm OCI `quay.io/strimzi-helm/strimzi-kafka-operator` 1.2.0, ns `data`(설계 §1과 통일), watch 설치 ns) + `Kafka jt-kafka`(version 4.3.1, metadataVersion 4.3-IV0, listener `tls` 9093 scram-sha-512, authorization simple, config RF/ISR 1·`auto.create.topics.enable=false`, entityOperator requests 256Mi, metricsConfig strimziMetricsReporter) + `KafkaNodePool combined`(roles controller+broker, replicas 1, jbod local-path 20Gi `deleteClaim false`, jvm -Xms/-Xmx 1g, requests 1536Mi/limits 2Gi, affinity role=platform)
- [ ] T055 [US3] `platform/kafka-topics/`: `KafkaTopic` `identity-admin.session.revoked`·`dev.identity-admin.session.revoked`·`identity-admin.dlq`·`dev.identity-admin.dlq`(partitions 3, replicas 1, retention.ms 604800000) + `KafkaUser` `identity-admin`·`dev-identity-admin`(scram-sha-512, ACL: 접두 write/describe, 구독 read, 그룹 접두 read, DLQ write; 비밀번호는 Vault `kv/{env}/kafka/identity-admin` → ExternalSecret → `secretKeyRef`) + ESO kubernetes-provider `ClusterSecretStore`로 `jt-kafka-cluster-ca-cert` → `jt-dev`·`jt-prod` 미러
- [ ] T056 [P] [US3] `platform/dragonfly/`: Deployment `dragonfly-dev`·`dragonfly-prod`(`ghcr.io/dragonflydb/dragonfly:v1.40.1`, `--maxmemory=768mb --requirepass $(DRAGONFLY_PASSWORD) --dir /data --snapshot_cron "*/5 * * * *"`, PVC local-path 2Gi, Recreate, nodeSelector role=data, requests 256Mi/limits 900Mi) + Service + ExternalSecret `kv/{env}/dragonfly`
- [ ] T057 [US3] 복구 런북 `docs/runbooks/restore-drill.md`(bootstrap.recovery + externalClusters plugin, targetTime, 앱 Secret/Service 교체, PVC 보존) + `barman-cloud-backup-list` 확인 + T049·T050 PASS

### E2E for User Story 3 (MANDATORY — executed by the tester agent)

- [ ] T058 [US3] E2E: US3 AC1–AC5 — data·kafka 검사 PASS, 다른 pod app role로 교차 DB 접속 시 permission denied 증거, kcat 왕복 시간, 백업 오브젝트 목록, dev/prod 분리(접두·인스턴스) 확인 — evidence recorded in the tester report

**Checkpoint**: pod가 붙을 DB·토픽·브로커가 준비됨

---

## Phase 6: User Story 6 - Django pod 템플릿과 공통 라이브러리 (Priority: P1)

**Goal**: `templates/django-pod` + `packages/django-common`으로 생성한 pod가 수정 없이 RLS·outbox·인증·관측 테스트를 통과하고, `apps/identity-admin`이 그 템플릿으로 만들어져 dev/prod에 배포된다. (US4의 폐기 흐름이 identity-admin을 필요로 하므로 US4보다 먼저)

**Independent Test**: quickstart §US6 — `copier copy` → `uv sync` → `pytest` all passed(testcontainers), arm64 이미지 빌드; `identity-m2m-dev.joshuatech.dev/health` 200(Access 서비스 토큰).

### Tests for User Story 6 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T059 [P] [US6] `packages/django-common/tests/test_tenancy.py`: testcontainers Postgres 18(비-superuser app role 생성) — tenant A 컨텍스트에서 tenant B 행 0, 컨텍스트 없음 0(fail-closed), owner role 전체, `set_config` is_local(다음 요청 누출 없음), StreamingHttpResponse 경고 — FAIL 확인
- [ ] T060 [P] [US6] `packages/django-common/tests/test_outbox.py`: `transaction.atomic()` 밖 `publish()` → `OutboxUsageError`; 같은 트랜잭션 INSERT → 릴레이 1회 → testcontainers Kafka(KRaft)에서 CloudEvents structured 봉투 수신·`packages/events` 스키마 통과 → 행 삭제; 프로듀서 실패 주입 → `attempts` 1·행 유지·`last_error`; `select_for_update(skip_locked)` 동시성(transactional_db) — FAIL 확인
- [ ] T061 [P] [US6] `packages/django-common/tests/test_auth.py`: 로컬 JWKS 서버 fixture — 유효 200 / 만료 401 / aud 불일치 401 / iss 불일치 401 / `revoked:sub:{sub}` nbf > iat 401 / `revoked:sid` 401 / Access JWT 없음 403 / Access JWT common_name 식별 / 헬스 경로 면제 — FAIL 확인
- [ ] T062 [P] [US6] `packages/django-common/tests/test_observability.py`: JSON 로그에 `request_id`(헤더 전달·생성)·`tenant_id`·`trace_id`; OTel in-memory exporter에 span·attributes; `/healthz` 200·DB 다운 시 `/ready` 503 — FAIL 확인
- [ ] T063 [P] [US6] `packages/events/tests/check-compat.test.mjs`(vitest): 필드 추가 → PASS, 필드 삭제·타입 변경·required 추가 → FAIL 보고, envelope 필수 필드 검증 — FAIL 확인
- [ ] T064 [P] [US6] `templates/django-pod/tests/test_generate.py`: `copier copy --defaults --data pod_name=sample-pod` → `uv sync --locked` → 생성물 `pytest -q` all passed(내장 테스트 6종) → `docker buildx build --platform linux/arm64` 성공 → `kubeconform` deploy/base — FAIL 확인
- [ ] T065 [P] [US6] `apps/identity-admin/tests/test_api.py`: `/health` 200(version·git_sha), `/ready` checks 3종, `GET /session/check`(active/nbf), `POST /sessions/revoke`(202, 로그 행, outbox 행, Dragonfly 키 TTL), `POST /webhooks/authentik`(서명 검증·멱등), `GET /tenants/me`(RLS), OpenAPI 스냅샷 — FAIL 확인

### Implementation for User Story 6

- [ ] T066 [P] [US6] `packages/events`: `schemas/_envelope.json` + 6개 토픽 스키마(contracts/events.md 필드) + `scripts/check-compat.mjs`(main vs PR 필드 diff) + `package.json` scripts + `ci.yml` job `events-compat` → T063 PASS
- [ ] T067 [P] [US6] `packages/django-common/src/django_common/tenancy.py`: `TenantModel`(추상, `tenant_id` UUID NOT NULL, 인덱스), `TenantContextMiddleware`(`transaction.atomic()` + `SELECT set_config('app.tenant_id', %s, true)`, 토큰 없으면 403), `rls_policies(table)` RunSQL 헬퍼(ENABLE/FORCE/정책 USING+WITH CHECK, reverse), `check_rls` management command → T059 PASS
- [ ] T068 [P] [US6] `packages/django-common/src/django_common/outbox.py`: `OutboxEvent` 모델(ULID id·topic·partition_key·payload·attempts·last_error), `publish(topic, subject, data)`(atomic 밖 예외, CloudEvents 2.2 봉투, `tenantid` 확장), `relay_outbox` command(500 ms 폴링·배치 100·`select_for_update(skip_locked=True, of=('self',))`·confluent-kafka idempotent producer SASL_SSL SCRAM + cluster CA·성공 DELETE·실패 백오프·메트릭) → T060 PASS
- [ ] T069 [P] [US6] `packages/django-common/src/django_common/auth.py`: `JwtAuthMiddleware`(PyJWT `PyJWKClient` 1h 캐시, iss/aud/exp/nbf), `AccessJwtValidator`(Cloudflare certs, aud 태그, common_name), `Denylist`(redis-py, `revoked:sub`·`revoked:sid`), Ninja auth callable, 헬스 면제 → T061 PASS
- [ ] T070 [P] [US6] `packages/django-common/src/django_common/{observability,health}.py`: structlog + django-structlog `RequestMiddleware`(X-Request-ID), `configure_otel()`(DjangoInstrumentor, OTLP http `OTEL_EXPORTER_OTLP_ENDPOINT`, excluded urls healthz/ready, response_hook tenant/sub_hash), `configure_sentry()`(errors only, release=digest), `health_router`(`/healthz` 정적, `/ready` django-health-check DB·cache·kafka) → T062 PASS
- [ ] T071 [US6] `templates/django-pod` 완성: `copier.yml`(질문·`_tasks: uv lock`·`_min_copier_version 9.17`) + `template/{{pod_snake}}/`(settings pydantic-settings 필수값·urls·api Ninja·core 앱 TenantModel 예·events 헬퍼·management) + `pyproject.toml.jinja`(Django 6.1, ninja 1.7, psycopg[binary] 3.3, celery 5.6, django-common workspace, 테스트 의존) + `Dockerfile`(`ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim` → `python:3.13-slim-trixie`, `--locked --no-install-project --no-dev`, non-root, arm64) + `compose.dev.yml`(postgres:18, dragonfly, kafka kraft) + `env.example`(키만) + `tests/`(6종, conftest testcontainers) + `deploy/base/`(Deployment 2 컨테이너 web+relay, Service, Ingress PLACEHOLDER, ExternalSecret, PreSync migrate Job owner 자격증명, ServiceMonitor 어노테이션) → T064 PASS
- [ ] T072 [US6] `apps/identity-admin`: `copier copy templates/django-pod apps/identity-admin --data pod_name=identity-admin owns_events=[session.revoked,user.registered,tenant.created]` → 모델 `Tenant`·`TenantMembership`·`SessionRevocationLog`(data-model §1–3) + RLS 마이그레이션 + 시드 command `seed_tenant joshuatech` + API(contracts/identity-admin-api: `/session/check`·`/sessions/revoke`(로그+outbox 트랜잭션 → Dragonfly SET TTL → Authentik revoke 호출 Celery 재시도)·`/webhooks/authentik`(HMAC·멱등 pk)·`/tenants/me`) + 기동 시 거부 목록 재적용(`expires_at > now()`) + Authentik API 클라이언트(토큰 ESO) → T065 PASS
- [ ] T073 [US6] `.github/workflows/publish-pod.yml`: `paths: apps/<pod>/**, packages/django-common/**`, `ubuntu-24.04-arm`, setup-buildx v4·login v4(GITHUB_TOKEN)·metadata v6(`type=sha,format=long`)·build-push v7(`platforms linux/arm64`, `provenance: false`, cache gha) → `outputs.digest` → attest v4(`push-to-registry`, `create-storage-record: false`) → create-github-app-token v3(`repositories: platform-gitops`) → checkout gitops → `kustomize edit set image ghcr.io/joshua92y/identity-admin@sha256:…` in `apps/identity-admin/overlays/dev` → `git pull --rebase` 재시도 루프 push; GHCR 패키지 Public 전환(**사용자 1회**)
- [ ] T074 [US6] `platform-gitops/apps/identity-admin/{base,overlays/dev,overlays/prod}`: base(템플릿 deploy/base 복사) + overlays(namespace jt-dev/jt-prod, images digest, Ingress host JSON6902 `identity-m2m-dev.`/`identity-m2m-prod.` + admin Ingress `admin.joshuatech.dev` `PathPrefix(/identity-admin)`(prod, env `FORCE_SCRIPT_NAME=/identity-admin`), replicas 1, ExternalSecret `identity-admin-env` ← `kv/{env}/db/identity_admin/app`·`/owner`(migrate Job)·`kv/{env}/kafka/identity-admin`·`kv/{env}/dragonfly`·`kv/{env}/authentik/identity-admin`(US4 후 값)·`kv/{env}/access/identity-admin`·`kv/{env}/sentry/identity-admin`) + Argo Application `identity-admin-dev`(auto-sync)·`identity-admin-prod` → dev 배포 → `/health` 200 via Access 서비스 토큰(Authentik 값 전까지 JWT 경로는 미사용)

### E2E for User Story 6 (MANDATORY — executed by the tester agent)

- [ ] T075 [US6] E2E: US6 AC1–AC6 — 템플릿으로 `/tmp/sample-pod` 생성 → 테스트 6종 PASS(증거: pytest 출력) → arm64 빌드; `identity-m2m-dev.`·`identity-m2m-prod.joshuatech.dev/health` 200(서비스 토큰), 헤더 없이 403; ExternalSecret 주입 확인 — evidence recorded in the tester report

**Checkpoint**: pod 규율이 코드로 강제되고 identity-admin이 살아 있음

---

## Phase 7: User Story 4 - 신원·인가 (Priority: P1)

**Goal**: Authentik(소셜·이메일·MFA)에서 로그인한 사용자 토큰이 `identity-admin` audience로 교환되고, 로그아웃·관리자 폐기·Authentik 세션 삭제가 1초 내 거부 목록에 반영되며, OpenFGA check와 Access 정책이 동작한다.

**Independent Test**: quickstart §US4 — GitHub 로그인 → 교환 토큰(aud identity-admin, tenant_id, exp 300s) → `portfolio-core` 교환 거부 → 로그아웃 1초 뒤 401 → Authentik 세션 삭제 후 401 → OpenFGA allowed → admin 호스트 Access 403/서비스 토큰 통과.

### Tests for User Story 4 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T076 [P] [US4] `e2e/auth.spec.ts`(Playwright, 테스트 GitHub 계정 자격은 env): `auth.joshuatech.dev` → GitHub 소셜 → MFA 등록 흐름 → 사용자 설정 Sessions에 세션 1건 — FAIL 확인
- [ ] T077 [P] [US4] `tests/platform/identity.tests.ps1`: web-bff 토큰(테스트용 ROPC 불가 → Playwright가 저장한 토큰 파일 사용)으로 RFC 8693 교환 → `aud=identity-admin`·`tenant_id`·`exp-iat=300`; `audience=portfolio-core` → `invalid_target`; `fga query check user:<sub> member tenant:<id>` → allowed; `admin.` 헤더 없이 403; Argo `--sso` 로그인 — FAIL 확인
- [ ] T078 [P] [US4] `e2e/revocation.spec.ts`: 로그인 → access 토큰 확보 → `POST /api/auth/logout` → 1초 후 identity-admin `/tenants/me` 401 `session_revoked`; Authentik 관리 API로 세션 삭제 → 웹훅 → 2초 후 401; identity-admin 로그에 reason — FAIL 확인

### Implementation for User Story 4

- [ ] T079 [US4] `platform/authentik/`: Application(helm `authentik/authentik` 2026.8.0, `postgresql.enabled false`, `AUTHENTIK_POSTGRESQL__*` = CNPG `authentik` DB + `SSLMODE verify-full` + `pg-main-ca` Secret 마운트, `AUTHENTIK_SECRET_KEY`·bootstrap 값 ExternalSecret `kv/platform/authentik`, server/worker replicas 1 requests 512Mi, nodeSelector platform, Ingress `auth.joshuatech.dev`(공개), `blueprints.configMaps` 참조) — Redis/Dragonfly 연결 없음
- [ ] T080 [US4] Blueprints ConfigMaps `platform/authentik/blueprints/{core,providers,events}.yaml`: 흐름(identification → password → authenticator_validate TOTP·WebAuthn, enrollment 이메일 인증, recovery), 소스 `github`·`google`(client id/secret `!Env` ← ExternalSecret), 그룹 `tenant:joshuatech`·`platform-admin`, ScopeMapping `tenant_id`(user.attributes), CertificateKeyPair RSA 서명키, Provider `web-bff`(confidential, PKCE, redirect `https://joshuatech.dev/api/auth/callback`·`http://localhost:3000/api/auth/callback`, access 300s, refresh 30d 회전, token exchange grant), `identity-admin`(federated = web-bff, access 300s), `argocd`(public PKCE, redirects), `vault`(confidential), NotificationTransport webhook(`http://identity-admin.jt-prod.svc/webhooks/authentik`, 서명 헤더 `!Env`) + Rule(login·logout·model_deleted session), proxy Provider + embedded outpost(`admin.`) — Blueprint 적용 확인(`ak_blueprints` 로그)
- [ ] T081 [P] [US4] `platform/openfga/`: Application(helm `openfga/openfga` 0.3.13, replicaCount 1, `datastore.engine postgres` URI ExternalSecret(CNPG `openfga`), `authn.preshared` keys ExternalSecret, playground off, checkQueryCache on, log json, 마이그레이션 Job — Argo 훅 교착 시 PreSync Job으로 분리) + `infra/bootstrap/openfga-stores.sh`(`fga store create jt-dev`·`jt-prod` + `fga model write packages/authz/model.fga`, store id → Vault `kv/{env}/openfga`) + `ci.yml` `fga model validate/test`
- [ ] T082 [US4] identity-admin 신원 연결: Vault `kv/{env}/authentik/identity-admin`(client id·secret·jwks_url·issuer)·`kv/{env}/access/identity-admin`(AUD)·웹훅 서명 비밀·Authentik API 토큰 투입 → ExternalSecret 반영 → `revoke` 호출 실검증(Authentik `/api/v3/core/tokens/`·세션 삭제) → 시드 사용자(운영자)에 `tenant:joshuatech` 그룹·`platform-admin` → OpenFGA 튜플 `user:<sub> owner tenant:<id>` 쓰기(identity-admin outbox 소비자 스텁 또는 부트스트랩 command)
- [ ] T083 [US4] SSO 전환: Argo CD `argocd-cm oidc.config`(Authentik public PKCE, `requestedScopes`, RBAC `g, platform-admin, role:admin`) → 검증 후 `admin.enabled false`; Vault OIDC auth(`infra/vault`: discovery `/application/o/vault/`, role admin, external group `platform-admin`); Traefik 대시보드·`admin.joshuatech.dev/identity-admin/`은 Access + Authentik forward-auth(Middleware `authentik-forwardauth` jt-prod, `/outpost.goauthentik.io/` 라우팅, Django `FORCE_SCRIPT_NAME=/identity-admin`) → `docs/runbooks/access-token-rotation.md`(서비스 토큰·Access AUD·Authentik client secret 회전)

### E2E for User Story 4 (MANDATORY — executed by the tester agent)

- [ ] T084 [US4] E2E: US4 AC1–AC6 — Playwright 로그인·세션 화면, 교환 성공/거부, 폐기 3경로(로그아웃·관리자·Authentik 세션 삭제) 반영 시간 측정(≤ 2 s), OpenFGA check, Access 403/통과 — evidence recorded in the tester report

**Checkpoint**: 신원·인가·세션 폐기가 end-to-end로 동작

---

## Phase 8: User Story 5 - 웹 hello와 BFF 왕복 (Priority: P1)

**Goal**: `joshuatech.dev/{ko,en,ja}`가 Workers에서 프리렌더 페이지(학습 노트 목록)를 서빙하고, BFF Route Handler가 세션·토큰 교환·identity-admin 왕복을 수행하며, 서버 번들이 예산 안에 든다.

**Independent Test**: quickstart §US5 — 3개 로케일 200 + 노트 2편, `/api/health` 200(upstream identity-admin), bundle-budget ≤ 2.5 MiB, Workers 대시보드 CPU p95 ≤ 10 ms, `/ja` 폴백 표시.

### Tests for User Story 5 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T085 [P] [US5] `packages/content/tests/loader.test.ts`(vitest): 001·002 노트 로드(제목·날짜·태그·slug·lang ko), `pubDate` 누락 fixture → 오류, `<slug>.en.mdx` → lang en + translations 연결, ko 파일 없음 → 오류, `draft:true`는 PROD에서 제외, `updatedDate < pubDate` → 오류, remark 헤딩 앵커·읽기 시간 — FAIL 확인
- [ ] T086 [P] [US5] `e2e/hello.spec.ts`(Playwright, `BASE_URL`): `/ko`·`/en`·`/ja` 200 + `data-note-slug` ≥ 2, `/` → 302 `/ko`(Accept-Language ko), `/ja`에서 번역 없는 노트 "번역 없음" 배지, `/api/health` JSON `upstream: identity-admin`·`upstream_ms`, 응답 `x-request-id` — FAIL 확인
- [ ] T087 [P] [US5] `apps/web/scripts/bundle-budget.test.mjs`(vitest): dry-run outdir 픽스처의 gzip 합산 계산, 2,621,440 bytes 초과 시 exit 1, 이하 0 — FAIL 확인
- [ ] T088 [P] [US5] `apps/web/src/lib/gateway.test.ts`(vitest, fetch mock): PKCE 생성·state 검증, JWE 쿠키 암복호·버전 접두, 교환 캐시 TTL 5분, `/session/check` 2초 캐시·inactive → 쿠키 삭제·401 problem+json, 하류 헤더(Bearer·CF-Access-*·x-request-id·traceparent) — FAIL 확인

### Implementation for User Story 5

- [ ] T089 [P] [US5] `packages/content/src/{schema.ts,loader.ts,mdx.ts,index.ts}`: zod 스키마(rules/content.md), `glob` 스캔(`content/{study,blog,projects}`) + 다국어 접미사 그룹핑 + 검증 + `React.cache` 1회, remark(gfm·frontmatter·heading id·reading-time)/rehype(shiki) 파이프라인, `getCollection(name, {lang, includeDrafts})`, JSON Schema export(`pnpm --filter content schema`) → T085 PASS
- [ ] T090 [US5] `apps/web` 스캐폴드: Next.js 16.3.4 App Router, `app/[lang]/{layout,page}.tsx`(`generateStaticParams(['ko','en','ja'])`, `dynamicParams=false`, 사전 JSON `src/i18n/{ko,en,ja}.json`), `app/route.ts`(`/` → 302 로케일), hello 페이지(학습 노트 목록·프로젝트 소개·i18n 전환·번역 없음 배지), `src/design/tokens/{primitive,semantic,component}.css` + 최소 컴포넌트(Layout slot·Card·Badge·Nav — Material 어휘, 소스 소유), `next.config.ts`(`images.loader custom` + `src/lib/image-loader.ts` `/cdn-cgi/image/…` + 폴백, `serverExternalPackages: ['jose']`), `open-next.config.ts`(staticAssetsIncrementalCache + enableCacheInterception), `wrangler.jsonc`(assets `.open-next/assets` binding ASSETS, `run_worker_first: ["/api/*"]`, `compatibility_date 2026-08-04`, flags `nodejs_compat`·`global_fetch_strictly_public`, 바인딩 없음) — Next 16.3 prefetch 루프(#1334) 확인, 미해결 시 16.2.x 핀 + ADR 0004 부록
- [ ] T091 [US5] BFF: `app/api/auth/{login,callback,logout,refresh}/route.ts`·`app/api/health/route.ts`·`app/api/session/route.ts`·`app/api/proxy/[pod]/[...path]/route.ts`(`export const dynamic='force-dynamic'`) + `src/lib/gateway.ts`(contracts/bff-api: PKCE, `jose` JWE 쿠키 `jt_session`, CSRF 쿠키, isolate 캐시, RFC 8693 교환, Access 서비스 토큰 헤더, `/session/check` 캐시, RFC 9457 오류, request-id/traceparent) + Workers Secrets(`wrangler secret put SESSION_ENCRYPTION_KEY WEB_BFF_CLIENT_SECRET CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET`, 값은 Vault `kv/prod/web/*`에서 운영자가 복사) → T088 PASS
- [ ] T092 [US5] `apps/web/scripts/bundle-budget.mjs`(`opennextjs-cloudflare build` → `wrangler versions upload --dry-run --outdir` → gzip -9 합산 → 2.5 MiB 게이트, 결과 요약 출력) + `.github/workflows/deploy-web.yml`(x64 러너, pnpm, PR: `versions upload --preview-alias pr-<n>` + 코멘트, main: `deploy`; `CLOUDFLARE_API_TOKEN`(계정 소유 cfat_, Workers Scripts Edit)·`CLOUDFLARE_ACCOUNT_ID` secrets; fork PR 조건부) + `ci.yml` web jobs(eslint·tsc·vitest·bundle-budget·Playwright 로컬 `next start`) → T087 PASS
- [ ] T093 [US5] 도메인 전환(**사용자 재확인 후**, 저트래픽 시간): `infra/bootstrap/cutover-web.sh`(Pages 커스텀 도메인 삭제 → Pages CNAME 삭제 → `PUT /accounts/{a}/workers/domains` apex·www → `tofu import cloudflare_workers_custom_domain`) + `www` → apex 301(Cloudflare redirect rule, OpenTofu) + 전환 전 workers.dev 프리뷰로 E2E 사전 통과; 전환 시각·다운타임 기록

### E2E for User Story 5 (MANDATORY — executed by the tester agent)

- [ ] T094 [US5] E2E: US5 AC1–AC5 — `e2e/hello.spec.ts` PASS(prod 도메인), bundle-budget 출력값, Workers 대시보드 페이지 GET CPU p95·일 요청 수·Error 1102 0건 캡처, BFF→identity-admin 왕복 p95(`upstream_ms` 100회, SC-002 ≤ 300 ms) 기록, 스키마 위반 fixture로 빌드 실패 증거, PR 프리뷰 URL 코멘트 — evidence recorded in the tester report

**Checkpoint**: 공개 사이트가 v2로 응답하고 BFF가 플랫폼과 왕복

---

## Phase 9: User Story 7 - 관측과 RAM 실측 (Priority: P2)

**Goal**: Alloy → Grafana Cloud(메트릭·로그·트레이스), Sentry, 대시보드 3·알림 2, OCI 예산, 그리고 노드별 RAM 실측 보고.

**Independent Test**: quickstart §US7 — Grafana Cloud에서 노드 메트릭·identity-admin 로그 조회, 알림 2개 Normal, Sentry 이벤트 1건(request_id 태그), 노드 A ≤ 9 GB·B ≤ 8 GB(10분 평균 ×3), 월 Compute ≤ 3 SGD.

### Tests for User Story 7 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T095 [P] [US7] `tests/platform/observability.tests.ps1`: Grafana Cloud Prometheus API `kube_node_status_allocatable{resource="memory"}` 2 시리즈, Loki `{namespace="jt-prod",app="identity-admin"}` 최근 15분 로그 ≥ 1, Tempo 트레이스 검색(`service.name=identity-admin`) ≥ 1, alert rules `NodeMemoryAvailableLow`·`ArgoAppOutOfSync` 존재, `grafanacloud_instance_active_series` < 8000; Sentry API 최근 이벤트 1(`request_id` 태그) — FAIL 확인
- [ ] T096 [P] [US7] `tests/platform/ram-budget.tests.ps1`: `kubectl top nodes` 10분 간격 3회 → 노드 A ≤ 9 GiB·B ≤ 8 GiB, 상위 pod 5개 → `specs/003-platform-foundation/ram-report.md` 표 생성; `oci usage-api` 당월 Compute ≤ 3 SGD; `oci budgets` 예산 1·규칙 4 — FAIL 확인

### Implementation for User Story 7

- [ ] T097 [US7] `platform/observability/`: Application(helm `grafana/k8s-monitoring` 4.5.1, ns `monitoring`): `cluster.name oci-k3s`, destinations `prometheus`(remote_write)·`loki`·`otlp`(protocol http) with `secret.create false` ← ExternalSecret `grafana-cloud-credentials`(`kv/platform/grafana-cloud`), collectors `alloy-metrics`(presets small·statefulset·singleton, nodeSelector platform, applicationObservability OTLP 4317/4318)·`alloy-logs`(daemonset), `clusterMetrics` default allowlist, cAdvisor exclude network/fs, `scrapeInterval 60s`, annotationAutodiscovery includeMetrics(argocd_app_*, traefik_*), costMetrics/profiling off; alloy-operator CRD wave 분리 또는 SkipDryRun; Argo CD `controller.metrics` 어노테이션; identity-admin `OTEL_EXPORTER_OTLP_ENDPOINT` → `k8s-monitoring-alloy-metrics.monitoring.svc:4318`
- [ ] T098 [P] [US7] `infra/grafana/`(OpenTofu grafana provider 4.45, 스택 서비스 계정 토큰 ← Vault): 대시보드 3(노드 RAM 예산·pod 오류율·Kafka lag) JSON, `grafana_rule_group`(NodeMemoryAvailableLow `node_memory_MemAvailable_bytes/MemTotal < 0.10` 10m, ArgoAppOutOfSync `argocd_app_info{sync_status!="Synced"}==1` 30m, ArgoAppMissing absent 15m), contact point(이메일 + Discord webhook ← Vault) → 알림 정책
- [ ] T099 [P] [US7] Sentry: 프로젝트 `identity-admin`(DSN → `kv/{env}/sentry/identity-admin` → ExternalSecret)·`web`(클라이언트 전용 `instrumentation-client.ts`, `tracesSampleRate 0.1`, `enableLogs false`, replay onError; `withSentryConfig` 소스맵 업로드는 CI `SENTRY_AUTH_TOKEN`) — 서버 SDK 미포함으로 bundle-budget 영향 0 확인
- [ ] T100 [US7] RAM·비용 실측: 플랫폼 전부 + identity-admin dev/prod 기동 상태에서 T096 실행 3회 → `ram-report.md`(노드·pod 표·requests 대비) + 초과 시 완화 적용(Argo core·Alloy 축소·dev quota) → 재측정; `oci usage-api` 월 비용·`grafanacloud_instance_active_series` 기록; `docs/runbooks/ram-budget.md`(측정 방법·임계·완화 순서)

### E2E for User Story 7 (MANDATORY — executed by the tester agent)

- [ ] T101 [US7] E2E: US7 AC1–AC4 — observability·ram-budget 검사 PASS, Grafana 대시보드 3 스크린 대신 API 쿼리 결과, 의도적 예외 → Sentry 이벤트(request_id), 예산 규칙 4 — evidence recorded in the tester report

**Checkpoint**: 헌법 IV 충족, SC-005·SC-009 수치 확보

---

## Phase 10: User Story 8 - v1 정리와 도메인 전환 (Priority: P2)

**Goal**: v1 잔재(DNS 레코드·Pages 프로젝트·Render·Fly·구 부트 볼륨·시크릿)를 정리하고 인스턴스 OCID가 그대로임을 확인한다. (워크플로 비활성·재이미지·apex 전환은 Phase 2·US5에서 완료)

**Independent Test**: quickstart §US8 — 워크플로 4개 dispatch 전용, OCID 2개 불변·Ubuntu 24.04, apex → Workers, v1 레코드 없음, Render·Fly 없음.

### Tests for User Story 8 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T102 [P] [US8] `tests/platform/cutover.tests.ps1`: `gh api repos/joshua92y/joshtech/contents/.github/workflows/*` 각 파일 `on:`에 `workflow_dispatch`만; `oci compute instance list` OCID 2개 = 기록값·RUNNING; SSH `lsb_release` 24.04; `dig` `api`·`mainapi.joshuatech.dev` 빈 응답, `admin`·`traefik.joshuatech.dev`는 Cloudflare 프록시 IP(오리진 노드 A), `joshuatech.dev` Workers 헤더(`cf-ray` + BFF `x-request-id` on `/api/health`); 구 부트 볼륨 0개; Render/Fly는 사용자 확인 입력(`-RenderDeleted -FlyDeleted`) — FAIL 확인

### Implementation for User Story 8

- [ ] T103 [US8] `infra/cloudflare/dns.tf`에서 v1 레코드 `api`·`mainapi`·Pages CNAME 잔재 제거, `admin`·`traefik`은 T011에서 import 후 노드 A reserved IP로 교체된 상태 확인·apply(`cdn` 유지), Pages 프로젝트 `joshtech-frontend` 삭제(전환 3일 후) — **사용자 재확인 후**
- [ ] T104 [US8] Render(웹서비스 `portfolio-django-admin`·Postgres `my-db`)·Fly(`joshtech-api`) 삭제 — **사용자 재확인 후, 백업 없음(사용자 결정)** — 삭제 시각·대상을 `docs/runbooks/bootstrap.md` §5에 기록; v1 GitHub Secrets(`GHCR_TOKEN`·`OCI_SSH_PRIVATE_KEY`·R2·Postmark·`CF_API_TOKEN`) 폐기·회전, 하드코딩된 Sentry DSN 프로젝트 폐기
- [ ] T105 [P] [US8] 구 부트 볼륨 2개 삭제 확인·Object Storage 임시 자료 정리, `docs/runbooks/rollback.md`(앱 revert·wrangler rollback·플랫폼 revert·CNPG PITR·tofu prevent_destroy·DNS 복원, 각 시간 한계)

### E2E for User Story 8 (MANDATORY — executed by the tester agent)

- [ ] T106 [US8] E2E: US8 AC1–AC4 — cutover 검사 PASS(OCID 불변 증거·OS·DNS·워크플로), 삭제 기록 확인 — evidence recorded in the tester report

**Checkpoint**: v1 완전 정리, v2만 남음

---

## Phase 11: User Story 9 - 에이전트 계층 (Priority: P2)

**Goal**: 경로 스코프 규칙 5, 빌더 에이전트 3, approval-review `k8s-security` 경계, kr 미러가 갖춰져 SP-2 작업을 서브에이전트에 맡길 수 있다.

**Independent Test**: quickstart §US9 — 파일 존재·frontmatter, run-all 미러 검사 PASS, approval-review 스킬이 경계 6개를 나열.

### Tests for User Story 9 (MANDATORY — write first, verify they FAIL) ⚠️

- [ ] T107 [P] [US9] `tests/agents/agent-layer.tests.ps1`: `.claude/rules/{web,django-pod,fastapi-pod,infra,events}.md` frontmatter `paths:` 존재·경로 패턴 유효, `.claude/agents/{web,api,infra}-builder.md` frontmatter(name·description·tools·skills), `boundaries/k8s-security.md` 존재 + `approval-review/SKILL.md`가 6개 경계 나열, `docs/kr/` 미러 존재·헤더 — `run-all` 체크 `agent-layer` 연결, FAIL 확인

### Implementation for User Story 9

- [ ] T108 [P] [US9] `.claude/rules/web.md`(`apps/web/**`, `packages/content/**`: OpenNext lean 규칙·번들 예산·BFF 계약·i18n·디자인 토큰), `django-pod.md`(`apps/*/`·`packages/django-common/**`·`templates/django-pod/**`: TenantModel·outbox·인증·설정·테스트 6종), `fastapi-pod.md`(SP-3 대비: all-async·taskiq·같은 계약), `infra.md`(`infra/**`·gitops: OpenTofu plan destroy 0·NSG·digest·ExternalSecret·sync-wave), `events.md`(`packages/events/**`: CloudEvents·토픽 규약·호환 규칙)
- [ ] T109 [P] [US9] `.claude/agents/web-builder.md`(rules web + superpowers TDD, Playwright), `api-builder.md`(rules django-pod·events + TDD, testcontainers/WSL), `infra-builder.md`(rules infra + verification-before-completion, kubectl/tofu 읽기 위주, 파괴적 명령 금지 목록) — `tester-write-guard`와 충돌 없는 tools 설정
- [ ] T110 [P] [US9] `.claude/skills/approval-review/boundaries/k8s-security.md`(NetworkPolicy·PSA·IMDS·NSG/AOP/Access·ExternalSecret 경로·이미지 digest·RBAC/AppProject·Vault 정책 항목 + 출력 형식) + `SKILL.md` 경계 목록 6개·리뷰 파일 절 `## K8s security` 추가
- [ ] T111 [US9] 미러·문서: `docs/kr/rules/{web,django-pod,fastapi-pod,infra,events}_kr.md`, `docs/kr/agents/*_kr.md`, `docs/kr/skills/approval-review_kr.md` 갱신, `AGENTS.md` Layout(`apps/ packages/ templates/ infra/ e2e/`) + `docs/kr/AGENTS_kr.md`, `CLAUDE.md` Project Structure·Commands(pnpm·uv·tofu·platform tests) + kr → T107 PASS

### E2E for User Story 9 (MANDATORY — executed by the tester agent)

- [ ] T112 [US9] E2E: US9 AC1–AC3 — `tests/run-all.ps1` ALL PASS(agent-layer·미러), `apps/web` 파일 편집 세션에서 `rules/web.md`만 로드됨을 훅 로그로 확인, `/approval-review` SKILL.md 경계 6 — evidence recorded in the tester report

**Checkpoint**: SP-2 서브에이전트 작업 준비 완료

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: 런북·실연·보안 마무리, quickstart 전체 재검증, report 기초 자료

- [ ] T113 [P] `docs/runbooks/` 6종 완성 검토(bootstrap·vault-unseal·rollback·restore-drill·ram-budget·access-token-rotation) — 각 런북에 목적·전제·절차·검증·되돌리기 절, `docs/README.md` 색인
- [ ] T114 승격·롤백 실연(SC-010): identity-admin dev digest bump → sync 시간 측정, `promote.yml` → prod PR → 머지 → sync ≤ 5분, `git revert` PR → 롤백 ≤ 5분, `wrangler rollback` 1회 — 시간을 `report.md` 초안에 기록
- [ ] T115 [P] 보안 마무리: gitleaks 두 repo 0건 + GitHub secret scanning/push protection 활성 확인, 'Require actions to be pinned to SHA' 설정, Renovate 첫 PR(핀·digest) 처리, tfstate 버킷 접근 정책 재확인, Access 서비스 토큰 만료·회전일 캘린더
- [ ] T116 quickstart.md 전체 재실행(US1–US9 명령·기대값 대조) + `specs/003-platform-foundation/report.md` 초안(Summary·Changes Made·Validation: RAM 표·비용·왕복 p95·폐기 반영 시간·번들 크기·Next) — `/finish`가 완성
- [ ] T117 [P] `.specify/memory/architecture.md`·`product.md`에 실측치(RAM·비용·버전·호스트) 반영, `CLAUDE.md` Recent Changes/Known Issues(조사·구현에서 드러난 함정: Traefik 값 스키마·AOP 자기 호출·OpenNext Worker 경유·S3 compat 체크섬 등) + kr 미러
- [ ] T118 [P] 학습 노트 소재 정리 `specs/003-platform-foundation/research/2026-09-lessons.md`(단계별 실측·기각 대안·검증 방법) — `/finish`의 `content/study/003-platform-foundation.mdx` 입력

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존 없음. T003·T005는 사용자 수동 단계를 포함(컨트롤러가 요청·확인)
- **Foundational (Phase 2)**: Setup 완료 후. T007 → T008 → T009 → (T010 ∥ T011) → T012 → T013 → T014; T015는 T001 뒤 병렬. **모든 클러스터 스토리(US2–US8)를 차단**
- **US1 (Phase 3)**·**US9 (Phase 11)**: 문서 작업이라 Foundational과 병렬 가능(컨트롤러). US9는 US1의 ADR을 참조하므로 US1 뒤가 자연스러움
- **US2 (Phase 4)**: Foundational 뒤. T035 → T036 → (T038 ∥ T039) → T040 → T041 → T042 → T043 → T044 → T045 → T046 → T047; T037(system-upgrade-controller)은 T040(Argo CD) 뒤 아무 때나
- **US3 (Phase 5)**: US2 뒤(Argo·ESO·Vault 필요). T051 → T052 → T053, T054 → T055, T056 병렬
- **US6 (Phase 6)**: 로컬 부분(T059–T072)은 Foundational과 병렬 가능(testcontainers·WSL); 배포 부분(T073–T075)은 US2·US3 뒤
- **US4 (Phase 7)**: US3(CNPG DB)·US6(identity-admin 배포) 뒤
- **US5 (Phase 8)**: 로컬 부분(T085–T092)은 언제든; `/api/health` 왕복·도메인 전환(T093·T094)은 US4·US6 뒤
- **US7 (Phase 9)**: US2 뒤 설치 가능, RAM 실측(T100)은 US3·US4·US6 배포 뒤
- **US8 (Phase 10)**: US5 도메인 전환 뒤
- **Polish (Phase 12)**: 전 스토리 뒤

### User Story Dependencies

- US1 문서 → 참조만(코드 의존 없음)
- US2 → US3 → US6(배포) → US4 → US5(왕복) → US7(실측) → US8(정리)
- US9는 독립(문서·규칙), US1 뒤 권장

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- 인프라 스토리의 "테스트"는 `tests/platform/*.tests.ps1`(kubectl·oci·curl 단언)로, 구현 전 FAIL을 확인한다
- Models before services · Services before endpoints · Core implementation before integration
- E2E task runs last in the story and is executed by the tester agent, never by the implementer
- Story complete before moving to next priority

### Parallel Opportunities

- Phase 1: T002·T003·T004·T005 병렬. Phase 2: T010·T011·T015 병렬
- US1: T018–T028 전부 병렬(파일별). US9: T108–T110 병렬
- US2: T038·T039 병렬; US3: T054·T056 병렬; US6: T059–T065 테스트 병렬, T066–T070 라이브러리 병렬; US5: T085–T088 병렬, T089 ∥ T090
- 서브에이전트 병렬: `api-builder`(US6 로컬)·`web-builder`(US5 로컬)·`infra-builder`(US2–US3)가 Foundational 뒤 동시 진행 가능; 컨트롤러는 US1·US9

---

## Parallel Example: User Story 6

```bash
# 테스트 먼저(모두 FAIL 확인):
Task: "packages/django-common/tests/test_tenancy.py"
Task: "packages/django-common/tests/test_outbox.py"
Task: "packages/django-common/tests/test_auth.py"
Task: "packages/django-common/tests/test_observability.py"
Task: "packages/events/tests/check-compat.test.mjs"

# 구현 병렬(파일 분리):
Task: "django_common/tenancy.py"
Task: "django_common/outbox.py"
Task: "django_common/auth.py"
Task: "django_common/observability.py + health.py"
Task: "packages/events schemas + check-compat"
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Phase 1 Setup → Phase 2 Foundational(재이미지·네트워크·Cloudflare·OpenTofu)
2. US1 문서(병렬) + US2 클러스터·GitOps·인그레스·시크릿
3. **STOP and VALIDATE**: T048 E2E — 이 시점에 "GitOps로 관리되는 안전한 클러스터"가 독립 가치

### Incremental Delivery

1. US3 데이터·이벤트 → E2E → US6 템플릿·identity-admin → E2E → US4 신원 → E2E(폐기 ≤ 2 s)
2. US5 웹·도메인 전환 → E2E(공개 사이트가 v2)
3. US7 관측·RAM → US8 정리 → US9 에이전트 계층 → Polish → `/speckit-converge` → tester 전체 → `/finish`

### Parallel Team Strategy

- `infra-builder`: Phase 2 → US2 → US3 → US7 설치 → US8
- `api-builder`: US6 로컬(테스트·라이브러리·템플릿·identity-admin) → US6 배포 → US4 연결
- `web-builder`: US5 로컬(content·web·BFF·CI) → 도메인 전환
- 컨트롤러: US1·US9 문서, 사용자 수동 단계 조율, 파괴적 단계 재확인, tester 디스패치, task당 커밋

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group (모노레포·gitops 각각 Conventional Commits, 한국어 설명)
- Stop at any checkpoint to validate story independently
- 파괴적 단계(T012·T013·T014·T093·T103·T104)는 실행 직전 사용자 재확인; `tofu plan`에 destroy/replace가 있으면 apply 금지
- 시크릿 값은 Vault(및 Workers Secret)에만; task 설명·커밋·리포트에 값 금지(gitleaks required check)
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
