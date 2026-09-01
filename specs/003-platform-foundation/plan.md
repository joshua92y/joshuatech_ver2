# Implementation Plan: 플랫폼 기반 (SP-1)

**Branch**: `003-platform-foundation` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-platform-foundation/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

아키텍처 결정 20개(spec D1–D20)를 ADR 9개·프로젝트 메모리·에이전트 규칙으로 고정하고, OCI A1 인스턴스 2대 위에 K3s 2노드 플랫폼(Argo CD + platform-gitops, Traefik/cert-manager/AOP, Vault + OCI KMS + ESO, CNPG, Strimzi Kafka, Dragonfly, Authentik + OpenFGA, Alloy → Grafana Cloud)을 세우며, Workers의 Next.js hello가 BFF를 거쳐 identity-admin `/health`까지 왕복하고, Django pod 템플릿이 RLS·outbox·인증·관측 테스트를 통과하는 상태를 만든다. 기술 접근: 인프라는 OpenTofu(OCI·Cloudflare) + Argo CD app-of-apps로 전부 선언하고, 앱 코드는 copier 템플릿 + `packages/django-common`으로 규율을 강제하며, 검증은 tester E2E(kubectl·argocd·Playwright·pytest)와 노드 RAM 실측으로 한다. 세부 근거는 [research.md](research.md), 엔티티는 [data-model.md](data-model.md), 인터페이스는 [contracts/](contracts/), 검증 절차는 [quickstart.md](quickstart.md). Approval 리뷰(2026-09-01) 시정 값·이름의 단일 기준은 [research/2026-09-01-approval-remediation.md](research/2026-09-01-approval-remediation.md)(R1–R25)이며, plan에 미친 조정은 아래 A2·A6·A7·A14와 A19–A28에 있다.

## Technical Context

**Language/Version**: Python 3.13(pod·공통 라이브러리·템플릿), TypeScript 5.x / Node 24(Active LTS — 루트 `package.json` `engines.node ">=24"`, `.node-version` 24, CI `setup-node` 24; web·packages/content·packages/events), HCL(OpenTofu), YAML(kustomize·Helm values·Blueprints), PowerShell 7.6(저장소 검사 스크립트)

**Primary Dependencies** (2026-09-01 research.md 확정, approval 리뷰 trends 항목 반영): K3s v1.36.4+k3s1(번들 Traefik 3.7.8 / 차트 40.1.4, local-path v0.0.37, system-upgrade-controller v0.20.1, `flannel-backend: wireguard-native`) · Argo CD v3.5.2(install.yaml kustomize `?ref=<commit sha>`, dex·applicationset 제거) · cert-manager v1.21.1 · HashiCorp Vault 2.0.4(BSL, helm 0.34.1) + External Secrets Operator v2.10.0(ClusterSecretStore 3개 `vault-platform`·`vault-dev`·`vault-prod`) · Stakater Reloader v1.4.x · CloudNativePG 1.30.0(helm 0.29.0) + plugin-barman-cloud v0.14.0(helm 0.7.1) + PG 이미지 `postgresql:18.6-…-standard-trixie`(pgvector 내장) · Strimzi 1.2.0(Kafka 4.3.1, KRaft) · Dragonfly(`--aclfile`, 사용자별 ACL) · Authentik 2026.8.0(helm 2026.8.0, Redis 불필요, RFC 8693 delegation) · OpenFGA v1.19.0(helm 0.3.13) · Grafana k8s-monitoring 4.5.1(Alloy v1.19.2; 착수 시 `helm search repo grafana/k8s-monitoring --versions`로 4.5.1 배포 여부 확인, 없으면 4.5.0) · Next.js 16.3.4 + @opennextjs/cloudflare 1.20.5 + wrangler 4.127.1 + wrangler-action v4.0.0 · Django 6.1(6.1.1 예정) + Django Ninja 1.7.0(`ninja==1.7.0` 정확 핀, 회귀 시 1.6.2 폴백) + psycopg 3.3.5 + Celery 5.6.3 + confluent-kafka 2.15.0 + cloudevents 2.2.0 + PyJWT 2.13.0 + structlog/django-structlog + OTel 1.44.0/0.65b0 + sentry-sdk 2.68.1 + django-health-check 4.5.1 + pytest-django 4.14 + testcontainers 4.15 · copier 9.17.2 · uv 0.12.8(이미지 `uv:0.12.8-python3.13-trixie-slim`) · OpenTofu 1.12.6 + oracle/oci `~> 8.29.0` + cloudflare/cloudflare `~> 5.24.0` + hashicorp/vault `~> 5.11.0` + grafana `~> 4.45.0`(`.terraform.lock.hcl` 커밋, Access 정책 `session_duration` 명시) · age(백업 번들 암호화) · cloudflared 2026.8.3 · GitHub Actions(ubuntu-24.04-arm, checkout v7, build-push v7, metadata v6, attest v4, create-github-app-token v3, gitleaks-action v3) · Renovate(hosted, config:best-practices, `automerge: false`)

**Storage**: PostgreSQL 18(CNPG `pg-main`, DB per pod — SP-1은 `identity_admin`·`dev_identity_admin`·`authentik`·`openfga` 4개, local-path PVC 노드 B, pod 연결은 `sslmode=verify-full` + `pg-main-ca` 미러) · Dragonfly(세션 거부 목록·Celery 브로커·캐시, PVC 노드 B, ACL 사용자 `admin`·`identity-admin`·`<pod>`) · Kafka(KRaft, local-path PVC 노드 A, 보존 7일) · Vault Raft(PVC 노드 A, 일 1회 스냅샷 → `jt-backup-platform`) · OCI Object Storage 버킷 3개 — `jt-tfstate`(OpenTofu state, IAM 사용자 `svc-tfstate`만) · `jt-backup`(CNPG barman 백업·WAL, IAM 사용자 `svc-s3-backup`만, versioning) · `jt-backup-platform`(K3s SQLite 번들 + Vault Raft 스냅샷, `age` 암호화 `.tar.age`, 노드 A 인스턴스 프린시펄(동적 그룹 `jt-node-a`)이 `OBJECT_CREATE`·`OBJECT_INSPECT`만, versioning, lifecycle 30일) — 셋 다 `NoPublicAccess` · R2(공개 자산 `cdn.`) · git(콘텐츠·ADR·gitops 정본)

**Testing**: pytest + pytest-django + testcontainers(Postgres·Kafka·Dragonfly) — pod·템플릿·django-common; vitest — packages/content·events·web 단위; Playwright — 브라우저 E2E(로컬 사용자 `e2e@joshuatech.dev` 로그인·BFF 왕복; storageState `e2e/.auth/` gitignore·실행 후 삭제, trace `mask`); kubeconform·kustomize build — gitops validate; `tests/run-all.ps1` — ADR·미러·인덱스 검사; `tests/platform/` — 클러스터 단언(PowerShell); tester 에이전트 — US별 E2E(kubectl·argocd·oci CLI·curl·Playwright; 클러스터 자격은 SA `agent-view` 단기 토큰 kubeconfig만)

**Target Platform**: OCI VM.Standard.A1.Flex(arm64, Ubuntu 24.04) × 2 위 K3s; Cloudflare Workers(Free) 2개 — prod Worker(main `deploy`만, GitHub Environment `production`: deployment branch = main, 승인자 없음, 환경 시크릿에 prod `CLOUDFLARE_API_TOKEN`) + `joshuatech-web-preview`(wrangler env `preview`, 커스텀 도메인 `preview.joshuatech.dev`, Access GitHub IdP, dev 시크릿 `web-bff-dev`·`identity-m2m-dev`·자체 `SESSION_ENCRYPTION_KEY`; 같은 repo PR만 `wrangler deploy --env preview`, fork PR은 미생성) + static assets; 개발기 Windows 11 + WSL; CI ubuntu-24.04-arm(public repo)

**Project Type**: 모노레포(web + Django pod + packages + templates + infra) + 별도 GitOps 저장소; 플랫폼 부트스트랩 feature(애플리케이션 기능은 SP-2)

**Performance Goals**: BFF → pod 왕복 p95 ≤ 300 ms(SC-002); 폐기 반영 ≤ 2 s(SC-003); dev bump → sync ≤ 5분, 승격·롤백 ≤ 5분(SC-010); root app apply → 플랫폼 Healthy ≤ 30분(SC-001); outbox 발행 ≤ 5 s(SC-004)

**Constraints**: 노드 A ≤ 9 GB · B ≤ 8 GB 사용 RAM(SC-005); Workers Free(요청 100k/일, CPU 10 ms, 서버 번들 gzip ≤ 2.5 MiB — SC-007); OCI 월 Compute ≤ 3 SGD(SC-009; Budgets 35 SGD·알림 규칙 4); 시크릿 저장소 0건(SC-006); 인스턴스 terminate 금지(FR-006); 공개 SSH 없음(FR-015); Authentik OSS 2026.8(RFC 8693 delegation 채택 — BFF가 자기 client-credentials 토큰을 `actor_token`으로 제시, pod는 `act.sub == web-bff` 검증, Access 서비스 토큰은 네트워크 게이트로 유지); 에이전트·tester·CI의 클러스터 자격은 SA `agent-view`(ClusterRole `view` 집계 + `applications.argoproj.io` get/list + Role(`vault` ns) `pods/portforward`) 단기 토큰만, admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만

**Scale/Scope**: 단일 테넌트 시드(사용자당 테넌트 1, 식별자는 어디서나 UUID), 외부 사용자 0(SP-1), pod 1개(identity-admin) + 템플릿, 플랫폼 컴포넌트 12개(+Reloader), 네임스페이스 14, ADR 9, 저장소 2, 호스트 ≈ 13, gitops Application ≈ 15, Workers 2

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 판정 | 근거 |
|---|---|---|
| I. Spec-First | ✅ | spec.md(Draft, 사용자 검토 완료 2026-08-31)가 이 plan의 유일한 입력. 결정 D1–D20은 spec에 있고 plan은 근거·절차만 더한다. 003 디렉터리는 불변; SP-2 이후 변경은 새 feature |
| II. Test-First | ✅ | FR-035·044: 템플릿 내장 테스트 6종, US마다 tester E2E task. tasks 단계마다 "테스트 먼저 실패 확인 → 구현" 순서를 tasks-template(MANDATORY)가 강제. 인프라 단계도 검증 task(quickstart 명령)를 구현 task 앞에 둔다 |
| III. Tenant Boundary | ✅ | Key Entities 15개 전부 소유자·격리 키 명시(data-model.md; `TenantMembership`·`SessionRevocationLog` 추가, `SessionRevocation`은 Dragonfly 파생 캐시). pod 간 FK 없음, DB per pod + role 격리(FR-016), 이벤트로만 교차(contracts/events.md), 테이블 등급 A(테넌트 범위: `TenantModel`, `tenant_id` + FORCE RLS) / B(pod 전역, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`; app role NOBYPASSRLS, owner `bypassrls: true`는 마이그레이션·시드 전용)(FR-034); Dragonfly는 ACL로 pod별 키 공간 분리(contracts/denylist.md) |
| IV. Observability-Ready | ✅ | 구조화 로그 `request_id`·`tenant_id`·`trace_id`(FR-034), 메트릭·대시보드 3·알림 규칙 11(FR-040, 각 `runbook_url`), 롤백 경로 = gitops revert / wrangler rollback / CNPG PITR(클러스터 전체) + 단일 DB 복구 / K3s `--cluster-reset` + 스냅샷 / Vault raft restore / tofu prevent_destroy(quickstart 롤백 표) |
| V. Simplicity | ⚠️ 정당화 | 새 프레임워크·컴포넌트가 많다(K3s·Argo CD·Vault·CNPG·Strimzi·Authentik·OpenFGA·Alloy·Next.js·Django·Ninja·copier). 각각 ADR 0002–0010에 대안·기각 사유가 있고, 아래 Complexity Tracking에 "더 단순한 대안을 기각한 이유"를 적는다 |
| VI. Learning-in-Public | ✅ | `/finish`가 `content/study/003-platform-foundation.mdx`를 만든다. 단계별 학습 소재(RAM 실측·AOP·outbox·거부 목록)를 report에 모은다 |
| 플랫폼 제약 | ✅ | 시크릿은 Vault·ESO·Workers Secret에만(FR-014; ESO는 scope별 ClusterSecretStore 3개); 파괴적 작업(v1 워크플로 비활성·재이미지·Render/Fly 삭제·DNS 제거)은 spec D1·FR-042로 사용자 승인됨, tasks에서 실행 전 재확인 |

**Post-design re-check(Phase 1 후)**: data-model·contracts가 III·IV를 구체화했고 새 위반 없음. Approval 리뷰(2026-09-01) 시정(R1–R25)을 반영해도 새 위반 없음; Complexity Tracking에 Reloader 1행을 추가했다.

## Project Structure

### Documentation (this feature)

```text
specs/003-platform-foundation/
├── plan.md              # 이 문서
├── research.md          # Phase 0: R1–R14 결정·버전·설정·함정
├── research/            # 브레인스토밍 산출물(트레이드오프·결정 로그·조사 원문·설계서) + 2026-09-01-approval-remediation.md(리뷰 시정 결정표 R1–R25)
├── data-model.md        # Phase 1: 엔티티 15개(소유자·격리 키·필드·상태)
├── quickstart.md        # Phase 1: US별 검증 명령·기대값·롤백 표
├── contracts/           # Phase 1: bff-api · identity-admin-api · events · gitops-repo · pod-template · hostnames-and-access · network-policy · denylist
├── checklists/requirements.md
├── reviews/             # YYYY-MM-DD-approval.md(리뷰어 원문·종합 의견·사용자 결정)
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
apps/
├── web/                          # Next.js 16.3 + OpenNext lean (app/[lang], app/api BFF, src/design, src/lib/gateway.ts, scripts/bundle-budget.mjs, open-next.config.ts, wrangler.jsonc(env preview), e2e/ — e2e/.auth/는 gitignore·실행 후 삭제)
└── identity-admin/               # 템플릿으로 생성한 Django pod (healthz·ready·health·session revoke·check·webhook)
packages/
├── content/                      # MDX 로더(zod·다국어·캐시·remark/rehype) + tests
├── events/                       # schemas/*.json · scripts/check-compat.mjs + tests
├── authz/                        # model.fga
└── django-common/                # tenancy(TenantModel·GlobalModel·check_rls) · outbox · auth(Denylist) · observability · health + tests
templates/
└── django-pod/                   # copier 템플릿(copier.yml, {{pod_snake}}/…, tests/, deploy/base/ — requests web 256Mi·relay 96Mi·migrate 256Mi·celery 192Mi, 프로브 3종, reloader 어노테이션)
content/{study,blog,projects,assets}/
infra/
├── oci/                          # OpenTofu: vcn · nsg · instances(import + 재이미지) · buckets(jt-tfstate·jt-backup·jt-backup-platform) · kms(prevent_destroy, 삭제 유예 30일) · iam(svc-tfstate·svc-s3-backup·동적 그룹 jt-node-a) · budgets  (backend s3 = jt-tfstate)
├── cloudflare/                   # OpenTofu: dns · access apps/policies/service tokens(auth-admin·preview 포함) · aop · r2 · workers domain(apex·preview) · tunnel
└── bootstrap/                    # k3s-server.sh · k3s-agent.sh · host-prep.sh · root-app.sh · vault-init.md · platform-backup.sh + platform-backup.timer
docs/
├── decisions/0002-…0010-*.md
├── runbooks/{bootstrap,restore-drill,vault-unseal,rollback,ram-budget,incident-response,break-glass,secret-rotation}.md
└── kr/                           # 미러
.claude/
├── rules/{web,django-pod,fastapi-pod,infra,events}.md
├── agents/{web,api,infra}-builder.md
└── skills/approval-review/boundaries/k8s-security.md
.github/workflows/{ci,publish-pod,deploy-web}.yml · renovate.json · .node-version
tests/                            # 저장소 검사(run-all: ADR·미러·인덱스·kubeconform), platform/(클러스터 단언), fixtures/generated/(gitignore — copier 샘플 pod), e2e/(Playwright)

platform-gitops/ (별도 public 저장소)
├── bootstrap/{argocd,root-app.yaml}
├── clusters/oci-k3s/{projects,apps}/
├── platform/{cert-manager,traefik,vault,external-secrets,cnpg,kafka,dragonfly,authentik,openfga,observability,cloudflared,reloader,system-upgrade,policies}/
│   ├── policies/                 # 네임스페이스 14개(PSA 라벨) + 정책 3종 default-deny·allow-dns·deny-imds(kube-system은 deny-imds만) + SA agent-view RBAC + jt-* ResourceQuota/LimitRange — 정본은 contracts/network-policy.md
│   ├── reloader/                 # Stakater Reloader v1.4.x(ns reloader): `reloader.stakater.com/auto: "true"` 워크로드 재적재
│   ├── system-upgrade/           # system-upgrade-controller + Plan k3s-server·k3s-agent(prepare = platform-backup.sh --pre-upgrade)
│   └── monitoring/               # k8s-monitoring(ns monitoring)
├── apps/identity-admin/{base,overlays/dev,overlays/prod}/
├── secrets/                      # platform/ 접두 ExternalSecret만(store vault-platform)
└── .github/workflows/{validate,promote}.yml · PR 템플릿(비가역 변경 시 스냅샷 3종 체크박스)
```

**Structure Decision**: 모노레포 + 별도 gitops 저장소(D16). 모노레포는 pnpm workspace(web·packages/content·events) + uv workspace(django-common·pod·템플릿)로 두 언어를 나눈다. 테스트는 각 패키지 옆(`tests/`)에 두고 저장소 검사는 루트 `tests/`. 헌법 III의 "서비스 경계 = 소유 데이터"를 디렉터리(apps/<pod>)와 DB(pod별 database)에 1:1로 맞춘다.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| K3s + Argo CD(2노드, GitOps) — ADR 0003 | SaaS급 규율(선언·drift 복원·PR 승격)과 이력서 가치가 프로젝트 목표. 사용자가 compose-pull(B2)을 기각 | compose-pull은 드리프트 복원·네임스페이스 격리·quota가 없어 SP-3 이후 pod 8개에서 수동 운영이 됨 |
| Strimzi Kafka(단일 노드) — ADR 0008 | 청사진 불변식 "outbox → 이벤트"의 버스. insights·search·notification이 소비자 | Postgres outbox + Dragonfly Streams는 RAM은 적지만 Kafka 소비자 시맨틱(그룹·오프셋·보존)이 없고, 사용자가 Kafka 학습을 명시 요구 |
| Authentik + OpenFGA — ADR 0006 | 단일 IdP·audience별 토큰·교차 컨텍스트 인가를 처음부터 연습(청사진) | Better Auth/자체 JWT는 pod별 audience·교환·MFA·소셜을 직접 구현해야 하고, OpenFGA 없이는 SP-2 media↔engagement 관계를 앱 조인으로 풀게 됨 |
| HashiCorp Vault + ESO — ADR 0010 | public 저장소 2개에서 시크릿 0건, 회전·감사 | Sealed Secrets는 회전·감사·동적 시크릿이 없고 클러스터 키 백업이 단일 장애점; 사용자가 Vault 운영 경험을 요구 |
| Elasticsearch/ECK(자리만) — ADR 0009 | 한국어 형태소 검색(Nori)·Kibana 학습 | Postgres FTS는 한국어 토큰화가 약함. SP-1은 RAM 자리만 남기고 구현하지 않음 |
| Django pod 템플릿 + django-common | pod 4→8개가 같은 규율(RLS·outbox·인증·관측)을 갖게 하는 유일한 방법 | pod마다 복사·붙여넣기는 첫 편차에서 헌법 III·IV 위반이 생김 |
| OpenNext(Next.js on Workers) — ADR 0004 | 사용자 결정(취업 시장·v1 재사용). 프리렌더 + BFF만으로 Free 안에 맞춤 | Astro가 더 단순하지만 사용자가 기각; 정적 export는 BFF Route Handler 불가 |
| Stakater Reloader(`platform/reloader/`, ~50 MiB) — approval 리뷰 operability F15 | ESO가 Secret을 갱신해도 env로 주입받는 Django·Authentik·OpenFGA pod는 구 값을 유지하므로 회전 뒤 재적재 수단이 필요 | ExternalSecret `template.metadata` 버전 라벨 + Deployment checksum 어노테이션은 워크로드마다 패치를 반복해야 하고 Helm 차트(Authentik·OpenFGA)에는 적용이 어려움 |

## Implementation Approach

tasks.md는 다음 10단계로 나눈다(spec Design §6). 각 단계는 "검증 task(quickstart 명령이 실패함을 확인) → 구현 task → tester E2E task" 순서다. 단계 간 의존은 아래 화살표.

```
① 문서(ADR 0002–0010, memory, rules, agents, boundary, kr 미러)        ── 의존 없음, 병렬 가능
② 인프라: OpenTofu OCI(import·재이미지·NSG·버킷 3·KMS prevent_destroy·IAM 사용자 2 + 동적 그룹 jt-node-a·Budgets) + Cloudflare(DNS·Access(auth-admin·preview 포함)·AOP·R2·Workers 도메인 2·터널) + v1 워크플로 비활성·v1 시크릿/토큰 폐기
③ 클러스터: K3s server/agent 부트스트랩(host-prep.sh: authorized_keys = jt-ops) → Argo CD bootstrap → platform-gitops(projects·root app·policies: ns 14·PSA·정책 3종·agent-view) → cert-manager·Traefik TLSOption·AOP → cloudflared 터널 → system-upgrade-controller·Reloader → platform-backup.timer
④ 시크릿: Vault(Raft·ocikms seal·init·K8s auth·audit stdout·role vault-backup) → ESO ClusterSecretStore 3개(platform/dev/prod) → 초기 kv 값 투입
⑤ 데이터·이벤트: CNPG operator·pg-main·databases(4)/roles·barman-cloud 백업(02:00 KST) → Strimzi·KafkaNodePool·topics/users → Dragonfly dev/prod(ACL)
⑥ 신원: Authentik(Helm·Blueprints: 소셜·MFA·web-bff·identity-admin provider·delegation·e2e 사용자·웹훅) → OpenFGA(store·model) → Access 앱/정책/서비스 토큰
⑦ 관측: Alloy(k8s-monitoring, ns monitoring) → Grafana Cloud 대시보드 3·알림 규칙 11(+ mute timing) → Sentry 프로젝트 → OCI Budgets
⑧ 코드: packages/events(스키마·호환 검사) → packages/django-common(tenancy·outbox·auth·observability, 테스트) → templates/django-pod(copier, 내장 테스트) → apps/identity-admin(생성·API·웹훅·배포 base) → CI publish-pod → gitops apps/identity-admin dev/prod
⑨ 웹: packages/content(zod·다국어·테스트) → apps/web(hello·[lang]·BFF·gateway·bundle-budget·e2e) → deploy-web(preview Worker / prod Environment) → Workers 커스텀 도메인(Pages 해제) → v1 DNS 레코드 제거·Render/Fly 삭제
⑩ 마감: RAM 실측 3회·비용·왕복 p95 → report 표, 런북 8종, promote/rollback 실연(SC-010)
```

- 병렬: ①은 전 단계와 독립. ⑧의 packages·템플릿·identity-admin 로컬 테스트는 ③–⑥ 없이 testcontainers로 가능하므로 ②–⑥과 병렬. ⑨의 packages/content·web 로컬 빌드도 병렬. 클러스터 배포·E2E만 순서 의존.
- 서브에이전트 분배: `infra-builder`(②–⑦, gitops), `api-builder`(⑧), `web-builder`(⑨), 컨트롤러(①·⑩). 각 서브에이전트에는 task 줄과 관련 contracts/quickstart 절만 준다. 클러스터 자격은 `agent-view` 토큰 kubeconfig만.
- 커밋: task당 1커밋(Conventional Commits, 한국어 설명). gitops 저장소도 같은 규칙. 시크릿·상태 파일·`e2e/.auth/`·`tests/fixtures/generated/`는 `.gitignore`.

## Observability & Rollback

- **관측**: 모든 pod가 structlog JSON(`request_id`·`tenant_id`·`trace_id`; processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거)과 OTLP 트레이스(`OTEL_TRACES_SAMPLER=parentbased_traceidratio` 0.1)를 Alloy로 보내고, Alloy가 Grafana Cloud(메트릭·Loki·Tempo)로 전달한다(Alloy 필터: kafka·argo INFO 이하 drop, Traefik 액세스 로그는 4xx/5xx만). relay 컨테이너는 `prometheus_client` 9464 + `k8s.grafana.com/scrape`로 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`을 노출하고, scrape 선언은 cnpg·eso·cert-manager·vault·relay 9464를 포함한다. Traefik 액세스 로그 JSON(`accesslog.fields.headers.defaultMode drop`)·OTLP(`tracing.sampleRate 0.1`). Vault `audit enable file file_path=stdout`(Alloy → Loki). BFF는 `x-request-id`를 생성해 응답과 하류에 남기고, wrangler `observability.enabled true, head_sampling_rate 1`로 JSON 로그(`request_id`·`upstream_ms`·`exchange_result`)를 남기며 `Authorization`·`Cookie`·`CF-Access-*`·`code`·`state` 값은 기록하지 않는다. Sentry는 Django(identity-admin)와 web 클라이언트. 헬스 엔드포인트 3개: `/healthz`(liveness, 프로세스만) · `/ready`(readiness, DB만) · `/health`(상세: db·dragonfly·kafka_producer 상태 JSON, 항상 200).
- **헬스 지표·알림 규칙 11개**(FR-040; 전부 `runbook_url` = `docs/runbooks/incident-response.md#<slug>`, 업그레이드 창 일요일 03:00–05:00 KST에는 Grafana mute timing):

  | 지표 | 알림 규칙 | 조건 |
  |---|---|---|
  | 노드 RAM(A ≤ 9 GB · B ≤ 8 GB) | `NodeMemoryHigh` | `node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes > 9.5*2^30`(노드 A) / `> 8.5*2^30`(노드 B), 10m |
  | Argo Synced 비율 | `ArgoAppOutOfSync` | 15m |
  | Argo Healthy 비율 | `ArgoAppUnhealthy` | `argocd_app_info{health_status=~"Degraded\|Missing\|Unknown"}` 15m |
  | CNPG 백업 나이 | `CnpgBackupStale` | `time() - cnpg_collector_last_available_backup_timestamp > 26*3600` |
  | 플랫폼 백업(K3s·Vault) 나이 | `PlatformBackupStale` | textfile `platform_backup_last_success_timestamp` > 26h |
  | PVC 사용률 | `PvcUsageHigh` | `kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.8` |
  | Vault seal 상태 | `VaultSealed` | `vault_core_unsealed == 0` 5m |
  | 인증서 만료 | `CertExpiringSoon` | < 21d |
  | ResourceQuota 소진 | `QuotaNearLimit` | used/hard > 0.9 |
  | 노드 디스크 | `NodeDiskLow` | avail/size < 0.15 |
  | outbox 지연 | `OutboxOldestPending` | `outbox_oldest_pending_seconds > 60` |

  알림 없는 대시보드 지표: BFF 왕복 p95, 폐기 반영 시간, ESO `externalsecret_status_condition`, `outbox_pending`·`outbox_dead_total`, Kafka 브로커 under-replicated(컨슈머 lag은 SP-2 kafkaExporter).
- **백업**: 노드 A의 `platform-backup.sh`(`platform-backup.timer` 매일 02:30 KST)가 K3s 번들(`sqlite .backup` + `server/token` + `server/cred/`)과 Vault Raft 스냅샷(`kubectl create token vault-backup -n vault` → `vault write auth/kubernetes/login role=vault-backup` → `vault operator raft snapshot save`; Vault 정책 `vault-backup` = `sys/storage/raft/snapshot` read)을 각각 `age -r <운영자 age 공개키>`로 암호화(`.tar.age`)해 `jt-backup-platform/k3s/`·`jt-backup-platform/vault/`에 `oci os object put --auth instance_principal`로 올린다(보존 K3s 7일·Vault 30일; 성공 시각은 textfile `platform_backup_last_success_timestamp`). age 개인키는 운영자 오프라인(recovery key와 같은 곳). CNPG `ScheduledBackup 0 0 17 * * *`(02:00 KST, 매일) + `archive_timeout 300`(RPO ≤ 5분). SUC Plan의 `prepare` 컨테이너가 `chroot /host /usr/local/bin/platform-backup.sh --pre-upgrade`를 먼저 실행한 뒤 업그레이드한다.
- **롤백**: 앱 = gitops `git revert` PR → sync; 웹 = `wrangler rollback`(prod Worker); 플랫폼 = gitops revert(`Delete=confirm`); K3s 업그레이드 = `INSTALL_K3S_VERSION` 핀 재설치 → `k3s server --cluster-reset` + SQLite 복원(SUC `prepare`가 만든 `--pre-upgrade` 스냅샷) — 단일 서버라 계획 다운타임을 report에 명시; K3s 데이터스토어 복구 = `jt-backup-platform/k3s/`의 `.tar.age`를 운영자 age 개인키로 복호화(`age -d -i <개인키>`)한 뒤 SQLite·`server/token`·`server/cred/` 복원; Vault = `jt-backup-platform/vault/` 스냅샷 복호화 → `vault operator raft snapshot restore -force`(같은 KMS 키 필수 — 키는 `prevent_destroy` + 삭제 유예 30일; KMS 일시 장애는 sealed 대기, ESO는 마지막 Secret 유지, pod 재시작 금지, `VaultSealed` 알림); DB = CNPG PITR은 `pg-main` 클러스터 전체(재해 복구 전용), 단일 DB 복구는 side Cluster PITR → `pg_dump` → 복원(런북 restore-drill), pod 단위 롤백은 가역 마이그레이션 + gitops revert; 인프라 = `tofu plan` destroy 0 확인(`prevent_destroy`); 도메인 = DNS 레코드 복원. 비가역 변경 표(CNPG/Strimzi 오퍼레이터 다운그레이드·Kafka `metadataVersion`·PG major·Authentik 스키마·Django contract 단계 → 복구 경로·RPO/RTO)는 `docs/runbooks/rollback.md`에 두고, 해당 파일을 바꾸는 PR은 gitops PR 템플릿 체크박스로 스냅샷 3종(Vault raft·CNPG·K3s SQLite) 확인을 요구한다. 상세는 quickstart 롤백 표.
- **런북 8종**(FR-041): bootstrap · restore-drill · vault-unseal · rollback · ram-budget · incident-response(알림 → 런북 표, 노드 A/B 장애, LE·Kafka 디스크·Dragonfly) · break-glass(OpenTofu 변수로 22 임시 개방, Argo admin 재활성, Vault `generate-root`) · secret-rotation(access-token-rotation 대체, 매트릭스 + 캘린더). 부트스트랩·백업 스크립트는 멱등(rules/infra).

## Research-Driven Adjustments (Phase 0 반영)

조사(research.md)에서 spec의 가정과 다르게 확인된 사실과 그 처리. spec 본문은 아래 "spec 수정" 항목만 고쳤고 나머지는 구현 세부다. A19 이후는 approval 리뷰(reviews/2026-09-01-approval.md)에서 확인된 사실이며, 처리는 research/2026-09-01-approval-remediation.md(R1–R25)의 값만 따른다.

| # | 사실 (출처) | 영향 | 처리 |
|---|---|---|---|
| A1 | OpenNext는 프리렌더 HTML을 정적 자산에 넣지 않고 Worker가 cache interception으로 응답한다 → 페이지 GET도 Worker 호출·CPU를 소비(cloudflare-docs #24616). "Worker 미호출"은 빌드 후 HTML을 assets에 복사하는 실험 옵션뿐이며 RSC 요청이 MPA로 강등되는 부작용이 있다 (R8) | spec SC-007·US5 AC1의 "Worker 호출 없이 정적 자산으로 응답" | **사용자 결정(2026-09-01): 수용** — 페이지 GET이 Worker를 거치는 것을 인정(정적 파일 `_next/static`은 무료), SC-007·US5 AC1을 "번들 예산 + 페이지 GET CPU p95 ≤ 10 ms·Error 1102 0건·일 요청 수 기록"으로 수정(spec 반영). HTML 복사 실험은 선택 task |
| A2 | Next 16.3 + cache interception에서 RSC prefetch 무한 루프 이슈(#1334 open, 수정 PR #1348 미머지·@opennextjs/cloudflare 1.20.5 미포함). 16.2.12에는 이 버그가 없지만 GHSA-p293-qw3h-jr36(CVSS 9.0, Windows 호스트 RCE)·GHSA-2xp9-vwfh-vxw4(CVSS 9.5)는 15.5.24·16.3.3에만 패치되어 16.2.x 핀은 미패치 Critical RCE 라인이다 (R8; approval 리뷰 trends 1) | 웹 hello 안정성; 폭주 시 Workers Free 100k/일 즉시 소진 | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 폴백 = 16.3.4 유지 + `enableCacheInterception: false` 임시(수정 PR #1348 포함 패치 출시 뒤 재활성) + CPU p95(SC-007)를 두 구성 모두 실측; `e2e/hello.spec.ts`에 "로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10" 가드; ADR 0004에 "보안 패치 라인 밖 다운그레이드 금지" |
| A3 | 와일드카드 인증서는 kube-system에 1장 + Traefik `TLSStore default`로 두는 것이 LE 레이트 리밋(동일 SAN 5/7일)과 Argo prune 재발급 위험을 피한다 (R3) | spec FR-011 "앱 네임스페이스마다 1장" | **spec 수정**: 1장 + TLSStore default, Ingress는 `router.tls: true`만. staging issuer로 리허설, prod 발급 1회 |
| A4 | 80 포트는 열 필요가 없다(LE는 DNS-01, Cloudflare Always Use HTTPS가 edge에서 리다이렉트). 보안 리스트 대신 NSG(VNIC 단위, 규칙 120)를 권장 (R3·R11) | spec FR-005 "80/443" | **spec 수정**: 443만, NSG로 구현. 클러스터 내부 규칙(6443·8472/udp·10250)은 NSG 자기참조 |
| A5 | pg_bigm은 PGDG apt에 없고 CNPG 확장 이미지도 없어 자체 image-volume 빌드가 필요(K8s 1.36 ImageVolume GA) (R5) | spec FR-016 확장 목록 | **spec 수정**: pg_bigm은 SP-3(검색)로 이월, SP-1은 pgvector(standard 이미지 내장)만 |
| A6 | 유료 테넌시 A1 무료분이 3,000/18,000인지 1,500/9,000인지 Oracle 문서·지원 답변이 상충. 후자면 월 ≈ $30, 전자면 ≈ $2. 8월 MTD Compute 1.18 SGD(2026-08-31)는 전자를 지지 (R14) | Assumptions·SC-009 | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 예산 정본은 FR-043: Budgets 35 SGD + 알림 규칙 4(ACTUAL 10/50/100% · FORECAST 100%). 종전 "$1·$5 알림 유지"와 "50/80/100%" 문구는 삭제 — ACTUAL 10%(3.5 SGD)가 $1·$5 알림 의도를 대체한다. US7 AC4·SC-009·Edge Case도 "35 SGD, 규칙 4"로 통일(spec 반영). 첫 청구서로 확정, $30이면 D17 재결정 |
| A7 | 부트 볼륨 교체(UpdateInstance sourceDetails)는 provider 5.38+에서 in-place 지원. 같은 Linux 배포판만 허용, `user_data`·`ssh_authorized_keys` 불변 → cloud-init 부트스트랩 불가, 구 볼륨 보존 시 스토리지 일시 2배 (R11·R14) | FR-006 절차; approval 리뷰 security F3(v1 SSH 키·시크릿이 재이미지 후에도 유효) | joshtech_cache로 먼저 리허설. K3s 설치는 cloudflared SSH + 스크립트. 재이미지 전 `oci compute instance get`으로 현재 OS(Ubuntu 버전) 확인. 검증 후 구 부트 볼륨 삭제. **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `ssh_authorized_keys`가 불변이므로 T014 `host-prep.sh`가 `~ubuntu/.ssh/authorized_keys`를 운영자가 새로 만든 키 `jt-ops`로 교체(T102 "구 키 0" 단언); v1 GitHub Secrets 전부 삭제 + Cloudflare v1 API 토큰·R2 토큰 revoke는 T012(워크플로 비활성과 같은 시점)로 앞당기고 T104는 잔여 확인만 |
| A8 | ephemeral 퍼블릭 IP는 reserved로 변환 불가(삭제 후 재생성 → 주소 1회 변경) (R14) | DNS | 재이미지 전 reserved IP로 교체(주소 변경 1회), DNS는 OpenTofu가 갱신. v1 DNS는 어차피 제거 |
| A9 | 인스턴스 프린시펄은 노드 신원 → 노드 A의 모든 pod가 IMDS(169.254.169.254)에 닿으면 KMS 권한을 얻는다 (R14) | 보안 | NetworkPolicy `deny-imds`를 전 네임스페이스(kube-system 포함)에 두고 `vault` ns만 169.254.169.254:80 egress 허용(contracts/network-policy.md) + IMDS v1 비활성화; 동적 그룹 `jt-node-a`는 노드 A OCID만(KMS `use keys` + `jt-backup-platform` 쓰기). k8s-security 경계 항목에 추가 |
| A10 | Authentik 2025.10+는 Redis를 완전히 제거(PostgreSQL 기반) (R7) | 배치 | Dragonfly를 Authentik에 연결하지 않음. Authentik은 CNPG `authentik` DB + `verify-full`(CA 마운트, `AUTHENTIK_POSTGRESQL__SSLMODE`·`__SSLROOTCERT` 개별 env) |
| A11 | Argo CD에 ServerSideApply 전역 기본값이 없고, Server-Side Diff를 함께 켜지 않으면 ESO Merge 필드로 영구 OutOfSync (R2) | gitops 규약 | validate.yml에 "syncOptions에 ServerSideApply=true 없는 Application 실패" lint, `controller.diff.server.side: "true"`, `Application` 헬스 Lua |
| A12 | cloudflared 2026.6+에서 `access tcp/ssh`가 서비스 토큰을 무시하는 회귀(#1673 open) (R12) | tester·CI 비대화형 접근 | 관리 접근은 브라우저 인증(GitHub IdP)으로; 비대화형이 필요하면 클라이언트만 2026.5.1 고정 후 검증 |
| A13 | Traefik `TLSOption default`에 `RequireAndVerifyClientCert`를 걸면 클러스터 내부에서 공개 호스트명으로 자기 호출하는 경로(Authentik discovery 등)가 끊긴다 (R3) | 내부 호출 규약 | 내부 호출은 Service DNS(`authentik-server.identity.svc`)로, 공개 호스트명은 Cloudflare 경유만(FR-046 예외 2: OIDC issuer/JWKS `auth.joshuatech.dev`는 Cloudflare proxied·Access 없음). 전환 순서 AOP on → `VerifyClientCertIfGiven` → `Require…` |
| A14 | Kafka 스택(브로커 2Gi + Entity Operator 768Mi + Cluster Operator 384Mi) ≈ 3 GiB (R6). approval 리뷰 operability F19: 종전 합계 7.8 GB는 앱 네임스페이스·Reloader·system-upgrade-controller를 빼고 계산했고, LimitRange 기본 512 Mi로는 identity-admin pod 하나가 dev quota를 소진한다 | 노드 A·B 예산(SC-005), FR-039 quota | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 템플릿 deploy/base에 requests 명시(web 256Mi·relay 96Mi·migrate 256Mi·celery 192Mi) 후 재계산. 노드 A: K3s 1.5 + Traefik 0.2 + Argo 0.6 + Vault/ESO 0.5 + Kafka 3.0 + Authentik 1.2 + OpenFGA 0.2 + Alloy 0.5 + cloudflared 0.1 + Reloader 0.05(≈ 50 MiB) + system-upgrade-controller 0.03(≈ 30 MiB) + 앱 ns dev+prod(각 web 256 + relay 96 + celery 192 = 544 MiB, 합 1,088 MiB ≈ 1.06 GB; migrate Job 256Mi는 PreSync 일시라 정상 상태 제외) ≈ **8.9 GB ≤ 9 GB**(여유 ≈ 0.1 GB — 앱 Deployment는 노드 A 선호 affinity(FR-008)라 압박 시 B로 흘러가고, 초과 시 완화안은 US7 AC2). 노드 B: K3s agent ≈ 0.5(가정, 실측으로 교정) + CNPG pg-main 2.0(requests = limits) + Dragonfly dev/prod 0.5(256Mi × 2) + cloudflared 0.1 ≈ **3.1 GB ≤ 8 GB**(alloy-logs daemonset 분은 Alloy 0.5에 포함; SP-3 Elasticsearch 자리 ≈ 2 GB는 별도). 3회 실측 표(report)로 확정 |
| A15 | Django 미들웨어가 직접 `transaction.atomic()`을 열고 `SELECT set_config('app.tenant_id', %s, true)`를 실행해야 한다(ATOMIC_REQUESTS는 view만 감쌈, `SET LOCAL`은 bind 파라미터 불가, psycopg pool은 세션 GUC 누출) (R9) | django-common 설계 | contracts/pod-template.md 갱신. StreamingHttpResponse에서 DB 접근 금지 규칙 추가 |
| A16 | OCI KMS 키는 SOFTWARE 보호 모드가 무료·무제한, HSM은 키 버전 20개까지 무료 (R4·R14) | Vault seal 키 | `protection_mode = SOFTWARE`, AES-256, 자동 회전 off(마스터 키 래핑 용도라 충분), `prevent_destroy` + 삭제 유예 30일(A20) |
| A17 | Zero Trust Free 온보딩은 결제수단 입력 필수(청구 없음); 서비스 토큰 secret은 tfstate에 평문 (R12) | 준비·상태 보안 | 온보딩은 사용자 수동 1회. tfstate 버킷 `jt-tfstate`는 NoPublicAccess + versioning, IAM 사용자 `svc-tfstate`만 접근(A19), 상태용 Customer Secret Key는 CLI로 별도 생성 |
| A18 | GitHub: Node 20 액션 2026-09-23 제거, build-push가 public repo에서 provenance를 자동 부착해 인덱스 digest가 됨, GHCR 첫 push는 private (R13) | CI | 액션 v7/v7/v6/v4/v3, `provenance: false`, 패키지 Public 전환 1회, `create-storage-record: false`(개인 계정) |
| A19 | approval 리뷰 security F1·k8s F1·F8: K3s 번들(`server/cred/` = cluster-admin 인증서·CA 키, `server/token` = 조인 토큰)이 평문으로 `jt-backup`에 올라가고, 같은 IAM 키가 `jt-tfstate`까지 관리하며 CNPG 사이드카 Secret에도 들어간다 | FR-047·T010·T036·Storage | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 버킷 3개로 분리(`jt-tfstate` = `svc-tfstate`만 · `jt-backup` = `svc-s3-backup`만 · `jt-backup-platform` = 노드 A 인스턴스 프린시펄 `OBJECT_CREATE`·`OBJECT_INSPECT`만, versioning, lifecycle 30일; 전부 NoPublicAccess); 번들은 `age -r <운영자 age 공개키>`로 암호화(`.tar.age`)한 뒤 `platform-backup.sh`(`platform-backup.timer` 매일 02:30 KST)가 `oci os object put --auth instance_principal`로 `jt-backup-platform/k3s/`에 업로드; age 개인키는 운영자 오프라인; 동적 그룹 `jt-node-a`는 노드 A OCID만; 보존 K3s 7일·Vault 30일 |
| A20 | approval 리뷰 operability F8·F9·k8s F7: Vault Raft(무작위 생성 시크릿 전부의 정본)가 백업 항목에 없고, auto-unseal 구성에서 recovery 키는 unseal 수단이 아니다(`generate-root`·rekey용); 키 수도 3/5·3/2로 불일치 | FR-047·FR-049·Edge Cases·Technical Context Storage | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `platform-backup.sh`가 `kubectl create token vault-backup -n vault` → `vault write auth/kubernetes/login role=vault-backup` → `vault operator raft snapshot save` → age → `jt-backup-platform/vault/` 일 1회(Vault 정책 `vault-backup` = `sys/storage/raft/snapshot` read); Edge Case를 "KMS 일시 장애 = sealed 대기(ESO는 마지막 Secret 유지, pod 재시작 금지, `VaultSealed` 알림); KMS 키 삭제 = 스냅샷 + 동일 키 없이는 복구 불능 → 키 `prevent_destroy` + 삭제 유예 30일"로 교체; recovery 3/2 통일; 런북은 워크스테이션 CLI(Vault 이미지에 `openssl`·`ps` 없음) |
| A21 | approval 리뷰 k8s F2·F14: default-deny NetworkPolicy가 선언뿐이고 허용 매트릭스·PSA 레벨·네임스페이스 전체 목록이 없으며 `observability`/`monitoring` 이름이 갈린다 | FR-039·FR-045·US7 AC1·Project Structure | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `contracts/network-policy.md` 신규: 네임스페이스 14개(`kube-system`·`argocd`·`vault`·`external-secrets`·`cert-manager`·`cnpg-system`·`data`·`identity`·`jt-dev`·`jt-prod`·`monitoring`·`system-upgrade`·`cloudflared`·`reloader`) + PSA 레벨(`restricted` = argocd·vault·external-secrets·identity·jt-dev·jt-prod·cloudflared·reloader; `baseline` = cert-manager·cnpg-system·data; `privileged` = kube-system·monitoring·system-upgrade, 사유 기재) + 허용 매트릭스(출발 → 도착:포트); 정책 3종 `default-deny`(ingress+egress)·`allow-dns`·`deny-imds`를 kube-system 제외 전 ns에, kube-system은 `deny-imds`만; `observability`라는 이름은 쓰지 않음(→ `monitoring`); SA `agent-view` RBAC도 `platform/policies/` |
| A22 | approval 리뷰 tenant-data F-1·F-2: FORCE RLS 아래에서 릴레이·웹훅·기동 재적용 경로가 테넌트 컨텍스트 없이 0행을 읽고, `TenantMembership`·`SessionRevocationLog`가 spec Key Entities에 없어 plan의 개수와 어긋난다 | FR-034·Key Entities·Constitution Check III | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 테이블 등급 **A 테넌트 범위**(`TenantModel` 상속, `tenant_id` + FORCE RLS) / **B pod 전역**(RLS 미적용, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`); owner role `bypassrls: true`(마이그레이션·시드 전용), app role NOBYPASSRLS; 릴레이·웹훅·기동 재적용·`/tenants/me`는 app role로 B 등급만 읽음; `check_rls`는 A 등급 FORCE RLS + B 등급 허용 목록 검사; Key Entities 15개(`TenantMembership` 소유 identity-admin·키 `sub`+`tenant_id`·B 등급, `SessionRevocationLog` 소유 identity-admin·`sub` 단위·DB 정본·`expires_at`+30일 purge; `SessionRevocation`은 Dragonfly 파생 캐시) |
| A23 | approval 리뷰 operability F10·F12: `/ready`가 Kafka·Dragonfly까지 포함해 outbox 내성을 무효화하고, 홉별 타임아웃·재시도 값과 Dragonfly 실패 정책이 없다 | FR-024·FR-033·contracts(bff-api·pod-template·identity-admin-api) | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 헬스 3개 `/healthz`(liveness, 프로세스만) · `/ready`(readiness, DB만) · `/health`(상세 JSON, 항상 200); 타임아웃·재시도 표(BFF→pod fetch 3 s AbortController · pod→Authentik 5 s × 3회 지수 백오프, 최대 5분, Celery · Kafka `delivery.timeout.ms` 30000 · Dragonfly `socket_timeout` 0.2 s · PG app role `statement_timeout 15s`·`idle_in_transaction_session_timeout 30s` · ESO `refreshInterval 5m` · `/session/check` BFF 캐시 2 s); Dragonfly 조회 실패 = 비헬스 경로 503(RFC 9457 `type: …/denylist-unavailable`, fail-closed); deploy/base에 liveness `/healthz`·readiness `/ready`·startupProbe(마이그레이션 대기), RollingUpdate maxSurge 1/maxUnavailable 0 |
| A24 | approval 리뷰 security F4·k8s F3: ESO ClusterSecretStore·Vault role이 하나라 `jt-dev`의 ExternalSecret이 `prod/` 경로를 읽을 수 있다(dev는 auto-sync) | FR-049·contracts/gitops-repo | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `ClusterSecretStore` 3개 `vault-platform`(conditions.namespaces = 플랫폼 ns 목록)·`vault-dev`(jt-dev)·`vault-prod`(jt-prod), 각각 `auth.kubernetes.serviceAccountRef` = SA `eso-platform`/`eso-dev`/`eso-prod`(ns `external-secrets`); Vault role 3개(같은 이름, 정책 `kv/data/<scope>/*`·`kv/metadata/<scope>/*` read); validate가 `overlays/dev` = `dev/`만·`overlays/prod` = `prod/`만·`secrets/` = `platform/`만 + `secretStoreRef.name` ↔ overlay 일치를 검사 |
| A25 | approval 리뷰 security F11·tenant-data F-3·k8s F9: Dragonfly가 env당 비밀번호 하나라 모든 pod가 `revoked:*`를 쓸 수 있고, 거부 목록 키 계약이 코드(`Denylist`)에만 있으며 키 이름이 spec·tasks에서 다르다 | FR-020·FR-024·data-model SessionRevocation | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `--aclfile /etc/dragonfly/users.acl`(Secret, ESO `kv/{env}/dragonfly/acl`); 사용자 `admin`(+@all)·`identity-admin`(`~revoked:* ~identity-admin:* +@all`)·템플릿 pod `<pod>`(`~revoked:* +@read ~<pod>:* +@all`); Vault 경로 `kv/{env}/dragonfly/<user>`; `contracts/denylist.md` 신규 — `revoked:sub:{sub}` = nbf epoch(TTL 330 s), `revoked:sid:{sid}` = 1(TTL 330 s), `denylist:epoch` = identity-admin 기동 시각(TTL 없음; 30 s beat가 없으면 `SessionRevocationLog` 재적용) |
| A26 | approval 리뷰 security F5·k8s F15: PR 프리뷰가 prod Worker 시크릿을 상속하고 prod 배포 job에 환경 보호가 없다 | FR-032·FR-037·Technical Context Target Platform | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — 별도 Worker `joshuatech-web-preview`(wrangler env `preview`, 커스텀 도메인 `preview.joshuatech.dev`, Access GitHub IdP, dev 시크릿 `web-bff-dev`·`identity-m2m-dev`·자체 `SESSION_ENCRYPTION_KEY`), PR마다 `wrangler deploy --env preview`(같은 repo PR만, fork PR은 미생성); prod Worker는 main `deploy`만, job은 GitHub Environment `production`(deployment branch = main만, 승인자 없음, 환경 시크릿에 prod `CLOUDFLARE_API_TOKEN`); `pnpm install --frozen-lockfile --ignore-scripts`, `uv sync --locked`, Renovate `automerge: false` |
| A27 | approval 리뷰 security F12: GitHub App이 gitops ruleset의 bypass 주체라 CI 자격 유출 = main 직접 push | FR-038·FR-039·contracts/gitops-repo | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — `bypass_actors: []`; dev digest bump = App이 브랜치 `bump/dev-<pod>-<sha7>` + PR + `gh pr merge --auto --squash`(required check `validate` 통과 뒤 자동 머지); `promote.yml`도 동일. `argocd app diff` 코멘트는 "렌더링 diff(`kustomize build` main vs PR) 코멘트"로(Argo 접근 불필요) |
| A28 | approval 리뷰 trends 2: Authentik 2026.8 OSS에 RFC 8693 delegation(`actor_token` → `act.sub`)이 있어 "`act` 클레임은 Enterprise 전용" 가정이 틀렸다. 같은 리뷰 trends 3–6: provider `~> x.y` 제약이 breaking minor를 허용, Node 22는 Maintenance, `ninja` 1.7.0은 출시 2일 경과 | Assumptions·FR-022·ADR 0006·contracts/identity-admin-api·Technical Context | **사용자 결정(2026-09-01): 수정 후 재검토 → 반영** — delegation 채택: BFF가 자기 client-credentials 토큰을 `actor_token`으로 제시, pod는 `act.sub == web-bff` 검증(Access 서비스 토큰은 네트워크 게이트로 유지), ADR 0006 반영; Technical Context에 provider `~> 8.29.0`·`~> 5.24.0`·`~> 5.11.0`·`~> 4.45.0` + `.terraform.lock.hcl` 커밋 + Access 정책 `session_duration` 명시, Node 24, `ninja==1.7.0` + 1.6.2 폴백, k8s-monitoring 4.5.1 확인(없으면 4.5.0), Django 6.1은 `MAILERS`만 + `-W error::DeprecationWarning` |

## Phase 0 / Phase 1 Outputs

- Phase 0: [research.md](research.md) — R1 K3s · R2 Argo CD · R3 인그레스/AOP · R4 Vault/ESO · R5 CNPG/barman · R6 Strimzi · R7 Authentik/OpenFGA · R8 OpenNext · R9 Django 템플릿 · R10 관측 · R11 OpenTofu OCI · R12 Cloudflare provider · R13 GitHub CI · R14 OCI 운영. 각 항목은 Decision / Rationale / Alternatives / 설정 스니펫 / 함정.
- Phase 1: [data-model.md](data-model.md)(엔티티 15개), [contracts/](contracts/) 8개(bff-api · identity-admin-api · events · gitops-repo · pod-template · hostnames-and-access · network-policy · denylist), [quickstart.md](quickstart.md).
- Approval 리뷰 시정(2026-09-01): [reviews/2026-09-01-approval.md](reviews/2026-09-01-approval.md) → [research/2026-09-01-approval-remediation.md](research/2026-09-01-approval-remediation.md)(R1–R25, 값·이름의 단일 기준) → spec·plan·tasks·contracts·data-model·quickstart 반영 후 `/approval-review` 재실행.
- Phase 2(`/speckit-tasks`): 10단계 × (검증 → 구현 → E2E) task, `tests/`·`e2e/` 경로, 서브에이전트 라벨.
