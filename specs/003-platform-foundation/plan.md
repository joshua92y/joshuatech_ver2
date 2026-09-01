# Implementation Plan: 플랫폼 기반 (SP-1)

**Branch**: `003-platform-foundation` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-platform-foundation/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

아키텍처 결정 20개(spec D1–D20)를 ADR 9개·프로젝트 메모리·에이전트 규칙으로 고정하고, OCI A1 인스턴스 2대 위에 K3s 2노드 플랫폼(Argo CD + platform-gitops, Traefik/cert-manager/AOP, Vault + OCI KMS + ESO, CNPG, Strimzi Kafka, Dragonfly, Authentik + OpenFGA, Alloy → Grafana Cloud)을 세우며, Workers의 Next.js hello가 BFF를 거쳐 identity-admin `/health`까지 왕복하고, Django pod 템플릿이 RLS·outbox·인증·관측 테스트를 통과하는 상태를 만든다. 기술 접근: 인프라는 OpenTofu(OCI·Cloudflare) + Argo CD app-of-apps로 전부 선언하고, 앱 코드는 copier 템플릿 + `packages/django-common`으로 규율을 강제하며, 검증은 tester E2E(kubectl·argocd·Playwright·pytest)와 노드 RAM 실측으로 한다. 세부 근거는 [research.md](research.md), 엔티티는 [data-model.md](data-model.md), 인터페이스는 [contracts/](contracts/), 검증 절차는 [quickstart.md](quickstart.md).

## Technical Context

**Language/Version**: Python 3.13(pod·공통 라이브러리·템플릿), TypeScript 5.x / Node 22(web·packages/content·packages/events), HCL(OpenTofu), YAML(kustomize·Helm values·Blueprints), PowerShell 7.6(저장소 검사 스크립트)

**Primary Dependencies** (2026-09-01 research.md 확정): K3s v1.36.4+k3s1(번들 Traefik 3.7.8 / 차트 40.1.4, local-path v0.0.37, system-upgrade-controller v0.20.1) · Argo CD v3.5.2(install.yaml kustomize, dex·applicationset 제거) · cert-manager v1.21.1 · HashiCorp Vault 2.0.4(BSL, helm 0.34.1) + External Secrets Operator v2.10.0 · CloudNativePG 1.30.0(helm 0.29.0) + plugin-barman-cloud v0.14.0(helm 0.7.1) + PG 이미지 `postgresql:18.6-…-standard-trixie`(pgvector 내장) · Strimzi 1.2.0(Kafka 4.3.1, KRaft) · Dragonfly · Authentik 2026.8.0(helm 2026.8.0, Redis 불필요) · OpenFGA v1.19.0(helm 0.3.13) · Grafana k8s-monitoring 4.5.1(Alloy v1.19.2) · Next.js 16.3.4 + @opennextjs/cloudflare 1.20.5 + wrangler 4.127.1 + wrangler-action v4.0.0 · Django 6.1(6.1.1 예정) + Django Ninja 1.7.0 + psycopg 3.3.5 + Celery 5.6.3 + confluent-kafka 2.15.0 + cloudevents 2.2.0 + PyJWT 2.13.0 + structlog/django-structlog + OTel 1.44.0/0.65b0 + sentry-sdk 2.68.1 + django-health-check 4.5.1 + pytest-django 4.14 + testcontainers 4.15 · copier 9.17.2 · uv 0.12.8(이미지 `uv:0.12.8-python3.13-trixie-slim`) · OpenTofu 1.12.6 + oracle/oci ~> 8.29 + cloudflare/cloudflare ~> 5.24 + hashicorp/vault ~> 5.11 + grafana ~> 4.45 · cloudflared 2026.8.3 · GitHub Actions(ubuntu-24.04-arm, checkout v7, build-push v7, metadata v6, attest v4, create-github-app-token v3, gitleaks-action v3) · Renovate(hosted, config:best-practices)

**Storage**: PostgreSQL 18(CNPG `pg-main`, DB per pod, local-path PVC 노드 B) · Dragonfly(세션 거부 목록·Celery 브로커·캐시, PVC) · Kafka(KRaft, local-path PVC 노드 A, 보존 7일) · Vault Raft(PVC 노드 A) · OCI Object Storage(`jt-backup` 백업·WAL, `jt-tfstate` 상태) · R2(공개 자산 `cdn.`) · git(콘텐츠·ADR·gitops 정본)

**Testing**: pytest + pytest-django + testcontainers(Postgres·Kafka·Dragonfly) — pod·템플릿·django-common; vitest — packages/content·events·web 단위; Playwright — 브라우저 E2E(로그인·BFF 왕복); kubeconform·kustomize build — gitops validate; `tests/run-all.ps1` — ADR·미러·인덱스 검사; tester 에이전트 — US별 E2E(kubectl·argocd·oci CLI·curl·Playwright)

**Target Platform**: OCI VM.Standard.A1.Flex(arm64, Ubuntu 24.04) × 2 위 K3s; Cloudflare Workers(Free) + static assets; 개발기 Windows 11 + WSL; CI ubuntu-24.04-arm(public repo)

**Project Type**: 모노레포(web + Django pod + packages + templates + infra) + 별도 GitOps 저장소; 플랫폼 부트스트랩 feature(애플리케이션 기능은 SP-2)

**Performance Goals**: BFF → pod 왕복 p95 ≤ 300 ms(SC-002); 폐기 반영 ≤ 2 s(SC-003); dev bump → sync ≤ 5분, 승격·롤백 ≤ 5분(SC-010); root app apply → 플랫폼 Healthy ≤ 30분(SC-001); outbox 발행 ≤ 5 s(SC-004)

**Constraints**: 노드 A ≤ 9 GB · B ≤ 8 GB 사용 RAM(SC-005); Workers Free(요청 100k/일, CPU 10 ms, 서버 번들 gzip ≤ 2.5 MiB — SC-007); OCI 월 Compute ≤ 3 SGD(SC-009); 시크릿 저장소 0건(SC-006); 인스턴스 terminate 금지(FR-006); 공개 SSH 없음(FR-015); Authentik OSS(`act` 클레임 없음)

**Scale/Scope**: 단일 테넌트 시드, 외부 사용자 0(SP-1), pod 1개(identity-admin) + 템플릿, 플랫폼 컴포넌트 12개, ADR 9, 저장소 2, 호스트 ≈ 12, gitops Application ≈ 15

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 판정 | 근거 |
|---|---|---|
| I. Spec-First | ✅ | spec.md(Draft, 사용자 검토 완료 2026-08-31)가 이 plan의 유일한 입력. 결정 D1–D20은 spec에 있고 plan은 근거·절차만 더한다. 003 디렉터리는 불변; SP-2 이후 변경은 새 feature |
| II. Test-First | ✅ | FR-035·044: 템플릿 내장 테스트 6종, US마다 tester E2E task. tasks 단계마다 "테스트 먼저 실패 확인 → 구현" 순서를 tasks-template(MANDATORY)가 강제. 인프라 단계도 검증 task(quickstart 명령)를 구현 task 앞에 둔다 |
| III. Tenant Boundary | ✅ | Key Entities 13개 전부 소유자·격리 키 명시(data-model.md). pod 간 FK 없음, DB per pod + role 격리(FR-016), 이벤트로만 교차(contracts/events.md), 전 테이블 tenant_id + FORCE RLS(FR-034) |
| IV. Observability-Ready | ✅ | 구조화 로그 `request_id`·`tenant_id`·`trace_id`(FR-034), 메트릭·대시보드 3·알림 2(FR-040), 롤백 경로 = gitops revert / wrangler rollback / CNPG recovery / tofu prevent_destroy(quickstart 롤백 표) |
| V. Simplicity | ⚠️ 정당화 | 새 프레임워크·컴포넌트가 많다(K3s·Argo CD·Vault·CNPG·Strimzi·Authentik·OpenFGA·Alloy·Next.js·Django·Ninja·copier). 각각 ADR 0002–0010에 대안·기각 사유가 있고, 아래 Complexity Tracking에 "더 단순한 대안을 기각한 이유"를 적는다 |
| VI. Learning-in-Public | ✅ | `/finish`가 `content/study/003-platform-foundation.mdx`를 만든다. 단계별 학습 소재(RAM 실측·AOP·outbox·거부 목록)를 report에 모은다 |
| 플랫폼 제약 | ✅ | 시크릿은 Vault·ESO·Workers Secret에만(FR-014); 파괴적 작업(v1 워크플로 비활성·재이미지·Render/Fly 삭제·DNS 제거)은 spec D1·FR-042로 사용자 승인됨, tasks에서 실행 전 재확인 |

**Post-design re-check(Phase 1 후)**: data-model·contracts가 III·IV를 구체화했고 새 위반 없음. Complexity Tracking 항목은 그대로.

## Project Structure

### Documentation (this feature)

```text
specs/003-platform-foundation/
├── plan.md              # 이 문서
├── research.md          # Phase 0: R1–R14 결정·버전·설정·함정
├── data-model.md        # Phase 1: 엔티티 13개(소유자·격리 키·필드·상태)
├── quickstart.md        # Phase 1: US별 검증 명령·기대값·롤백 표
├── contracts/           # Phase 1: bff-api · identity-admin-api · events · gitops-repo · pod-template · hostnames-and-access
├── checklists/requirements.md
├── research/            # 브레인스토밍 산출물(트레이드오프·결정 로그·조사 원문·설계서)
└── tasks.md             # Phase 2 (/speckit-tasks)
```

### Source Code (repository root)

```text
apps/
├── web/                          # Next.js 16.3 + OpenNext lean (app/[lang], app/api BFF, src/design, src/lib/gateway.ts, scripts/bundle-budget.mjs, open-next.config.ts, wrangler.jsonc, e2e/)
└── identity-admin/               # 템플릿으로 생성한 Django pod (health·ready·session revoke·check·webhook)
packages/
├── content/                      # MDX 로더(zod·다국어·캐시·remark/rehype) + tests
├── events/                       # schemas/*.json · scripts/check-compat.mjs + tests
├── authz/                        # model.fga
└── django-common/                # tenancy · outbox · auth · observability · health + tests
templates/
└── django-pod/                   # copier 템플릿(copier.yml, {{pod_snake}}/…, tests/, deploy/base/)
content/{study,blog,projects,assets}/
infra/
├── oci/                          # OpenTofu: vcn · security lists · instances(import + 재이미지) · buckets · kms · iam · budgets  (backend s3 = jt-tfstate)
├── cloudflare/                   # OpenTofu: dns · access apps/policies/service tokens · aop · r2 · workers domain · tunnel
└── bootstrap/                    # k3s-server.sh · k3s-agent.sh · root-app.sh · vault-init.md
docs/
├── decisions/0002-…0010-*.md
├── runbooks/{bootstrap,vault-unseal,rollback,restore-drill,ram-budget,access-token-rotation}.md
└── kr/                           # 미러
.claude/
├── rules/{web,django-pod,fastapi-pod,infra,events}.md
├── agents/{web,api,infra}-builder.md
└── skills/approval-review/boundaries/k8s-security.md
.github/workflows/{ci,publish-pod,deploy-web}.yml · renovate.json
tests/                            # 저장소 검사(run-all: ADR·미러·인덱스·kubeconform), e2e/(Playwright)

platform-gitops/ (별도 public 저장소)
├── bootstrap/{argocd,root-app.yaml}
├── clusters/oci-k3s/{projects,apps}/
├── platform/{cert-manager,traefik,vault,external-secrets,cnpg,kafka,dragonfly,authentik,openfga,observability,cloudflared,policies}/
├── apps/identity-admin/{base,overlays/dev,overlays/prod}/
├── secrets/
└── .github/workflows/{validate,promote}.yml
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

## Implementation Approach

tasks.md는 다음 10단계로 나눈다(spec Design §6). 각 단계는 "검증 task(quickstart 명령이 실패함을 확인) → 구현 task → tester E2E task" 순서다. 단계 간 의존은 아래 화살표.

```
① 문서(ADR 0002–0010, memory, rules, agents, boundary, kr 미러)        ── 의존 없음, 병렬 가능
② 인프라: OpenTofu OCI(import·재이미지·보안 리스트·버킷·KMS·IAM·Budgets) + Cloudflare(DNS·Access·AOP·R2·터널) + v1 워크플로 비활성
③ 클러스터: K3s server/agent 부트스트랩 → Argo CD bootstrap → platform-gitops(projects·root app·policies) → cert-manager·Traefik TLSOption·AOP → cloudflared 터널
④ 시크릿: Vault(Raft·ocikms seal·init·K8s auth) → ESO ClusterSecretStore → 초기 kv 값 투입
⑤ 데이터·이벤트: CNPG operator·pg-main·databases/roles·barman-cloud 백업 → Strimzi·KafkaNodePool·topics/users → Dragonfly dev/prod
⑥ 신원: Authentik(Helm·Blueprints: 소셜·MFA·web-bff·identity-admin provider·webhook) → OpenFGA(store·model) → Access 앱/정책/서비스 토큰
⑦ 관측: Alloy(k8s-monitoring) → Grafana Cloud 대시보드 3·알림 2 → Sentry 프로젝트 → OCI Budgets
⑧ 코드: packages/events(스키마·호환 검사) → packages/django-common(tenancy·outbox·auth·observability, 테스트) → templates/django-pod(copier, 내장 테스트) → apps/identity-admin(생성·API·웹훅·배포 base) → CI publish-pod → gitops apps/identity-admin dev/prod
⑨ 웹: packages/content(zod·다국어·테스트) → apps/web(hello·[lang]·BFF·gateway·bundle-budget·e2e) → deploy-web → Workers 커스텀 도메인(Pages 해제) → v1 DNS 레코드 제거·Render/Fly 삭제
⑩ 마감: RAM 실측 3회·비용·왕복 p95 → report 표, 런북 6개, promote/rollback 실연(SC-010)
```

- 병렬: ①은 전 단계와 독립. ⑧의 packages·템플릿·identity-admin 로컬 테스트는 ③–⑥ 없이 testcontainers로 가능하므로 ②–⑥과 병렬. ⑨의 packages/content·web 로컬 빌드도 병렬. 클러스터 배포·E2E만 순서 의존.
- 서브에이전트 분배: `infra-builder`(②–⑦, gitops), `api-builder`(⑧), `web-builder`(⑨), 컨트롤러(①·⑩). 각 서브에이전트에는 task 줄과 관련 contracts/quickstart 절만 준다.
- 커밋: task당 1커밋(Conventional Commits, 한국어 설명). gitops 저장소도 같은 규칙. 시크릿·상태 파일은 `.gitignore`.

## Observability & Rollback

- **관측**: 모든 pod가 structlog JSON(`request_id`·`tenant_id`·`trace_id`)과 OTLP 트레이스를 Alloy로 보내고, Alloy가 Grafana Cloud(메트릭·Loki·Tempo)로 전달한다. Traefik 액세스 로그 JSON·OTLP. Argo CD `argocd_app_info`로 OutOfSync 알림, `kube_node_status_*`로 RAM 알림. BFF는 `x-request-id`를 생성해 응답과 하류에 남긴다. Sentry는 Django(identity-admin)와 web 클라이언트.
- **헬스 지표**: 노드 RAM(≤ 9/8 GB), Argo Synced/Healthy 비율, ESO SecretSynced, CNPG 백업 성공, Kafka lag, BFF 왕복 p95, 폐기 반영 시간, outbox pending.
- **롤백**: 앱 = gitops `git revert` PR → sync; 웹 = `wrangler rollback`; 플랫폼 = gitops revert(`Delete=confirm`); DB = CNPG recovery(barman-cloud PITR); 인프라 = `tofu plan` destroy 0 확인(`prevent_destroy`); 도메인 = DNS 레코드 복원. 상세는 quickstart 롤백 표와 `docs/runbooks/rollback.md`.

## Research-Driven Adjustments (Phase 0 반영)

조사(research.md)에서 spec의 가정과 다르게 확인된 사실과 그 처리. spec 본문은 아래 "spec 수정" 항목만 고쳤고 나머지는 구현 세부다.

| # | 사실 (출처) | 영향 | 처리 |
|---|---|---|---|
| A1 | OpenNext는 프리렌더 HTML을 정적 자산에 넣지 않고 Worker가 cache interception으로 응답한다 → 페이지 GET도 Worker 호출·CPU를 소비(cloudflare-docs #24616). "Worker 미호출"은 빌드 후 HTML을 assets에 복사하는 실험 옵션뿐이며 RSC 요청이 MPA로 강등되는 부작용이 있다 (R8) | spec SC-007·US5 AC1의 "Worker 호출 없이 정적 자산으로 응답" | **사용자 결정(2026-09-01): 수용** — 페이지 GET이 Worker를 거치는 것을 인정(정적 파일 `_next/static`은 무료), SC-007·US5 AC1을 "번들 예산 + 페이지 GET CPU p95 ≤ 10 ms·Error 1102 0건·일 요청 수 기록"으로 수정(spec 반영). HTML 복사 실험은 선택 task |
| A2 | Next 16.3 + cache interception에서 RSC prefetch 무한 루프 이슈(#1334 open, PR #1348) — 16.2.12에서는 없음 (R8) | 웹 hello 안정성 | 착수 시 릴리스 노트 확인, 미해결이면 `next` 16.2.x 핀(ADR 0004 부록에 기록) |
| A3 | 와일드카드 인증서는 kube-system에 1장 + Traefik `TLSStore default`로 두는 것이 LE 레이트 리밋(동일 SAN 5/7일)과 Argo prune 재발급 위험을 피한다 (R3) | spec FR-011 "앱 네임스페이스마다 1장" | **spec 수정**: 1장 + TLSStore default, Ingress는 `router.tls: true`만. staging issuer로 리허설, prod 발급 1회 |
| A4 | 80 포트는 열 필요가 없다(LE는 DNS-01, Cloudflare Always Use HTTPS가 edge에서 리다이렉트). 보안 리스트 대신 NSG(VNIC 단위, 규칙 120)를 권장 (R3·R11) | spec FR-005 "80/443" | **spec 수정**: 443만, NSG로 구현. 클러스터 내부 규칙(6443·8472/udp·10250)은 NSG 자기참조 |
| A5 | pg_bigm은 PGDG apt에 없고 CNPG 확장 이미지도 없어 자체 image-volume 빌드가 필요(K8s 1.36 ImageVolume GA) (R5) | spec FR-016 확장 목록 | **spec 수정**: pg_bigm은 SP-3(검색)로 이월, SP-1은 pgvector(standard 이미지 내장)만 |
| A6 | 유료 테넌시 A1 무료분이 3,000/18,000인지 1,500/9,000인지 Oracle 문서·지원 답변이 상충. 후자면 월 ≈ $30, 전자면 ≈ $2. 8월 MTD Compute 1.18 SGD(2026-08-31)는 전자를 지지 (R14) | Assumptions·SC-009 | Budgets 금액 35 SGD + 알림 ACTUAL 50/80/100%·FORECAST 100%로 상향(spec FR-043의 $1·$5 알림은 유지). 첫 청구서로 확정, $30이면 D17 재결정 |
| A7 | 부트 볼륨 교체(UpdateInstance sourceDetails)는 provider 5.38+에서 in-place 지원. 같은 Linux 배포판만 허용, `user_data`·`ssh_authorized_keys` 불변 → cloud-init 부트스트랩 불가, 구 볼륨 보존 시 스토리지 일시 2배 (R11·R14) | FR-006 절차 | joshtech_cache로 먼저 리허설. K3s 설치는 cloudflared SSH + 스크립트. 재이미지 전 `oci compute instance get`으로 현재 OS(Ubuntu 버전) 확인. 검증 후 구 부트 볼륨 삭제 |
| A8 | ephemeral 퍼블릭 IP는 reserved로 변환 불가(삭제 후 재생성 → 주소 1회 변경) (R14) | DNS | 재이미지 전 reserved IP로 교체(주소 변경 1회), DNS는 OpenTofu가 갱신. v1 DNS는 어차피 제거 |
| A9 | 인스턴스 프린시펄은 노드 신원 → 노드 A의 모든 pod가 IMDS(169.254.169.254)에 닿으면 KMS 권한을 얻는다 (R14) | 보안 | NetworkPolicy로 `vault` 네임스페이스 외 IMDS egress 차단 + IMDS v1 비활성화. k8s-security 경계 항목에 추가 |
| A10 | Authentik 2025.10+는 Redis를 완전히 제거(PostgreSQL 기반) (R7) | 배치 | Dragonfly를 Authentik에 연결하지 않음. Authentik은 CNPG `authentik` DB + `verify-full`(CA 마운트) |
| A11 | Argo CD에 ServerSideApply 전역 기본값이 없고, Server-Side Diff를 함께 켜지 않으면 ESO Merge 필드로 영구 OutOfSync (R2) | gitops 규약 | validate.yml에 "syncOptions에 ServerSideApply=true 없는 Application 실패" lint, `controller.diff.server.side: "true"`, `Application` 헬스 Lua |
| A12 | cloudflared 2026.6+에서 `access tcp/ssh`가 서비스 토큰을 무시하는 회귀(#1673 open) (R12) | tester·CI 비대화형 접근 | 관리 접근은 브라우저 인증(GitHub IdP)으로; 비대화형이 필요하면 클라이언트만 2026.5.1 고정 후 검증 |
| A13 | Traefik `TLSOption default`에 `RequireAndVerifyClientCert`를 걸면 클러스터 내부에서 공개 호스트명으로 자기 호출하는 경로(Authentik discovery 등)가 끊긴다 (R3) | 내부 호출 규약 | 내부 호출은 Service DNS(`authentik-server.identity.svc`)로, 공개 호스트명은 Cloudflare 경유만. 전환 순서 AOP on → `VerifyClientCertIfGiven` → `Require…` |
| A14 | Kafka 스택(브로커 2Gi + Entity Operator 768Mi + Cluster Operator 384Mi) ≈ 3 GiB (R6) | 노드 A 예산 | requests 합계: K3s 1.5 + Traefik 0.2 + Argo 0.6 + Vault/ESO 0.5 + Kafka 3.0 + Authentik 1.2 + OpenFGA 0.2 + Alloy 0.5 + cloudflared 0.1 ≈ 7.8 GB ≤ 9 GB(SC-005) |
| A15 | Django 미들웨어가 직접 `transaction.atomic()`을 열고 `SELECT set_config('app.tenant_id', %s, true)`를 실행해야 한다(ATOMIC_REQUESTS는 view만 감쌈, `SET LOCAL`은 bind 파라미터 불가, psycopg pool은 세션 GUC 누출) (R9) | django-common 설계 | contracts/pod-template.md 갱신. StreamingHttpResponse에서 DB 접근 금지 규칙 추가 |
| A16 | OCI KMS 키는 SOFTWARE 보호 모드가 무료·무제한, HSM은 키 버전 20개까지 무료 (R4·R14) | Vault seal 키 | `protection_mode = SOFTWARE`, AES-256, 자동 회전 off(마스터 키 래핑 용도라 충분) |
| A17 | Zero Trust Free 온보딩은 결제수단 입력 필수(청구 없음); 서비스 토큰 secret은 tfstate에 평문 (R12) | 준비·상태 보안 | 온보딩은 사용자 수동 1회. tfstate 버킷 NoPublicAccess + versioning, 상태용 Customer Secret Key는 CLI로 별도 생성 |
| A18 | GitHub: Node 20 액션 2026-09-23 제거, build-push가 public repo에서 provenance를 자동 부착해 인덱스 digest가 됨, GHCR 첫 push는 private (R13) | CI | 액션 v7/v7/v6/v4/v3, `provenance: false`, 패키지 Public 전환 1회, `create-storage-record: false`(개인 계정) |

## Phase 0 / Phase 1 Outputs

- Phase 0: [research.md](research.md) — R1 K3s · R2 Argo CD · R3 인그레스/AOP · R4 Vault/ESO · R5 CNPG/barman · R6 Strimzi · R7 Authentik/OpenFGA · R8 OpenNext · R9 Django 템플릿 · R10 관측 · R11 OpenTofu OCI · R12 Cloudflare provider · R13 GitHub CI · R14 OCI 운영. 각 항목은 Decision / Rationale / Alternatives / 설정 스니펫 / 함정.
- Phase 1: [data-model.md](data-model.md), [contracts/](contracts/) 6개, [quickstart.md](quickstart.md).
- Phase 2(`/speckit-tasks`): 10단계 × (검증 → 구현 → E2E) task, `tests/`·`e2e/` 경로, 서브에이전트 라벨.
