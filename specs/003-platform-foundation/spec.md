# Feature Specification: 플랫폼 기반 (SP-1)

**Feature Branch**: `003-platform-foundation`

**Created**: 2026-08-31

**Status**: Draft

**Input**: User description: "SP-1 platform foundation: architecture ADRs, OCI K3s two-node platform skeleton (GitOps, ingress, secrets, data, events, identity), Workers web hello, Django pod template"

> 이 spec은 superpowers brainstorming(2026-08-27 ~ 31, 라운드 9회)의 결과다. 설계서 원문은 [research/2026-08-28-design.html](research/2026-08-28-design.html)(아티팩트 사본), 결정 로그는 [research/2026-08-28-brainstorm-decisions.md](research/2026-08-28-brainstorm-decisions.md), 트레이드오프·1차 출처는 [research/2026-08-27-decisions-and-tradeoffs.md](research/2026-08-27-decisions-and-tradeoffs.md)에 있다. 이 문서가 정본이고 설계서는 참고다.

## 배경과 결정 요약

SP-0(001·002)은 도구·관례만 만들었고 애플리케이션 스택은 비워 두었다. SP-1은 스택과 경계를 결정해 문서로 고정하고, 그 결정이 실제로 돌아가는 최소 뼈대를 세워 SP-2(사이트 코어 pod)가 바로 기능을 만들 수 있게 한다. 참고 청사진은 사용자의 "커머스 SaaS 9-Pod 청사진"(기본 Django·FastAPI는 ADR 예외·pod별 DB 독점·Authentik 단일 IdP·OpenFGA·outbox 이벤트)이며, 인그레스·환경 패턴은 사용자의 egenauto K3s 배포(2026-06)를 따른다.

| # | 결정 | 채택 | 기각 |
|---|---|---|---|
| D1 | v1 사이트 | 백업·임포트 없이 종료(VM은 재이미지, 인스턴스 유지) | 유지·병행 |
| D2 | 저장소 공개 | public 2개(모노레포·platform-gitops) | private |
| D3 | 런타임 트랙 | 웹 Cloudflare Workers + API OCI K3s 2노드 + Argo CD | Cloudflare-native · compose-pull · 전부 K3s |
| D4 | 웹 호스팅·프레임워크 | Workers static assets + Next.js 16.3 + OpenNext lean(프리렌더 + BFF만, 번들 예산) | Pages · Astro · SvelteKit · 정적 export + Hono |
| D5 | 백엔드 정책 | 기본 Django 6.1 + Ninja 1.7, FastAPI는 수치 트리거 ADR 예외(search·notification·assistant) | FastAPI 단일 · Hono · Python Workers |
| D6 | 신원·인가 | Authentik 단일 IdP(소셜 GitHub·Google + 이메일/비밀번호 + MFA), provider별 audience, RFC 8693 교환, BFF = 게이트웨이, OpenFGA는 교차 컨텍스트, Cloudflare Access 이중 | Better Auth · Clerk · 자체 JWT · 인클러스터 게이트웨이 |
| D7 | 세션 | 정본 = Authentik(서버측) + BFF refresh 쿠키(egenauto authx 동형), 즉시 폐기 = 폐기 이벤트 + Dragonfly 거부 목록 | identity-admin 자체 세션 서비스 · 요청마다 introspection · TTL 축소만 |
| D8 | 데이터 | CNPG 클러스터 1개 + pod별 database/role, tenant_id + FORCE RLS + SET LOCAL 이중 격리, barman-cloud → OCI Object Storage | Neon · Supabase · D1 · 스키마 분리 · 앱 계층만 |
| D9 | 이벤트 | Kafka KRaft(Strimzi 오퍼레이터), 앱 내 폴링 outbox 릴레이, CloudEvents JSON + 모노레포 JSON Schema | Postgres outbox + Dragonfly Streams · Redpanda · Debezium · Avro |
| D10 | 캐시·큐 | Dragonfly 유지(dev·prod 인스턴스, 인증 필수) | Valkey · Postgres 큐 |
| D11 | 검색(SP-3 구현) | Elasticsearch 1노드 + Kibana + Nori, ECK, FastAPI search pod | Postgres FTS · Pagefind · OpenSearch |
| D12 | 인그레스 | egenauto 패턴: 번들 Traefik 공개 80/443 + cert-manager DNS-01 와일드카드 + Cloudflare proxied Full(strict), 보안 리스트 Cloudflare IP 한정 + Authenticated Origin Pulls | 터널 전용 · 제한 없는 공개 |
| D13 | 시크릿 | HashiCorp Vault(Raft) + OCI KMS auto-unseal + ESO, gitops에는 참조만 | Sealed Secrets · SOPS+age · OpenBao |
| D14 | 관측 | Grafana Cloud Free + Alloy, Sentry SaaS Free | 자체 ES 로그 · GlitchTip |
| D15 | 환경 | dev + prod 상시(앱 pod만 복제, 플랫폼 공유), ResourceQuota + LimitRange | prod + staging scale-0 |
| D16 | 승격 | platform-gitops 별도 repo, dev 자동 digest bump, prod PR(ruleset) | 모노레포 내 gitops · Image Updater |
| D17 | 인프라·상태 | OCI 인스턴스 2대(2 OCPU/13 GB, PAYG 테넌시 확인, 월 ≈ $1–2 감수), OpenTofu 상태 = OCI Object Storage | 12 GB 축소 · 증량 · 로컬 상태 |
| D18 | pod 목록 | SP-2 identity-admin·portfolio-core·media·engagement / SP-3 notification·insights·search / SP-4 assistant | 단일 pod · 청사진 그대로 9 |
| D19 | 콘텐츠 | 학습 노트·글·프로젝트 모두 git MDX 정본, DB는 메타·반응만, `packages/content` 자체 로더, ko 기본 + en·ja 접미사 파일, 이미지 = R2 원본 + Cloudflare Image Transformations | Velite · DB 저자 · Cloudflare Images 유료 |
| D20 | SP-1 범위 | 문서 + 뼈대(플랫폼 전부, ES 제외) + 웹 hello + Django pod 템플릿 | 문서만 · 분할 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 아키텍처 결정의 문서화 (Priority: P1)

운영자(joshua)는 SP-1의 결정이 ADR·프로젝트 메모리·에이전트 규칙으로 고정되어, 다음 feature의 plan이 "무엇을 왜 골랐는지"를 다시 논의하지 않고 참조만 하기를 원한다.

**Why this priority**: 결정이 문서로 남지 않으면 뼈대 코드가 곧 유일한 근거가 되고, SP-2 이후의 모든 approval-review가 같은 질문을 반복한다. 헌법 V(새 프레임워크는 ADR 필요)의 직접 이행이다.

**Independent Test**: `docs/decisions/0002-*.md` ~ `0010-*.md`가 MADR minimal 형식 검사(run-all)를 통과하고, `.specify/memory/product.md`·`architecture.md`가 존재하며, `.claude/rules/*.md` 5개가 `paths:` frontmatter로 해당 경로 편집 시에만 로드되는지 확인한다.

**Acceptance Scenarios**:

1. **Given** 이 spec의 D1–D20이 승인됨, **When** ADR 0002–0010을 작성하면, **Then** 각 ADR은 `status: accepted`, `date`, `decision-makers`, Context / Considered Options / Decision Outcome / Consequences 절을 갖고 기각 대안을 최소 2개 적으며, `docs/README.md`와 이 spec에서 링크된다.
2. **Given** ADR이 존재함, **When** `.specify/memory/product.md`(제품 목표·도메인·pod 목록·로드맵)와 `architecture.md`(토폴로지·경계·계약·운영 원칙)를 작성하면, **Then** 두 문서는 이 spec의 Design 절과 모순이 없고, `/speckit-archive-run`이 덮어쓰지 않는 파일(agent context 블록 밖)로 남는다.
3. **Given** `.claude/rules/{web,django-pod,fastapi-pod,infra,events}.md`와 `.claude/agents/{web,api,infra}-builder.md`, `.claude/skills/approval-review/boundaries/k8s-security.md`가 추가됨, **When** `apps/web/` 아래 파일을 편집하면, **Then** `rules/web.md`만 로드되고 `django-pod.md`는 로드되지 않으며, `/approval-review`는 경계 6개를 디스패치하고, `docs/kr/` 미러가 run-all 미러 검사를 통과한다.

---

### User Story 2 - 클러스터·GitOps·인그레스·시크릿 기반 (Priority: P1)

운영자는 OCI 인스턴스 2대 위에 K3s 2노드 클러스터가 서고, Argo CD가 `platform-gitops` 저장소를 정본으로 플랫폼을 동기화하며, 공개 트래픽은 Cloudflare를 반드시 거쳐 Traefik에 닿고, 시크릿은 Vault에서만 나오기를 원한다.

**Why this priority**: 다른 모든 스토리의 전제다. 이 스토리 없이는 데이터·신원·웹 왕복을 검증할 곳이 없다.

**Independent Test**: `kubectl get nodes`가 2 Ready, Argo CD root app이 Synced/Healthy, `https://argo.joshuatech.dev`가 Cloudflare Access 로그인 뒤에만 열리고 오리진 IP 직접 호출은 mTLS로 거부되며, `ExternalSecret` 1개가 Vault 값으로 `Secret`을 만든다.

**Acceptance Scenarios**:

1. **Given** OpenTofu가 VCN·보안 리스트·인스턴스 재이미지·버킷·KMS 키를 적용함, **When** 노드 A에 K3s server(`--secrets-encryption`, `role=platform`)·노드 B에 agent(`role=data`)를 부트스트랩하면, **Then** `kubectl get nodes`가 2 Ready를 보이고 노드 B는 인바운드 공개 포트가 없으며 노드 A의 80/443은 Cloudflare IP 대역에서만 열린다.
2. **Given** 클러스터가 준비됨, **When** `bootstrap/root-app.yaml` 하나를 수동 apply하면, **Then** Argo CD가 AppProject 3개(platform·dev·prod)와 sync-wave 순서(CRD → cert-manager·ESO → Vault → CNPG → data → identity → observability)로 플랫폼 Application 전부를 Healthy로 만들고 `default` 프로젝트는 소스·대상이 비어 있다.
3. **Given** cert-manager ClusterIssuer(LE, Cloudflare DNS-01)와 Traefik이 동작함, **When** `argo.joshuatech.dev`를 브라우저로 열면, **Then** Cloudflare Access(GitHub IdP) 로그인 → Authentik OIDC 로그인 순으로 통과해야 UI가 보이고, 오리진 공인 IP로 직접 `curl`하면 Authenticated Origin Pulls 때문에 TLS 핸드셰이크가 거부된다.
4. **Given** Vault가 Raft 스토리지로 노드 A에서 실행되고 OCI KMS로 자동 unseal됨, **When** 노드 A를 재부팅하면, **Then** Vault가 사람 개입 없이 unsealed 상태로 돌아오고, ESO의 `ClusterSecretStore`가 Ready이며 `ExternalSecret` → `Secret` 동기화가 1분 내 재개된다.
5. **Given** 두 저장소가 public임, **When** CI가 실행되면, **Then** gitleaks가 required check로 두 저장소 모두 0건이고, gitops 저장소의 어떤 매니페스트에도 시크릿 값이 없다(ExternalSecret 참조만).

---

### User Story 3 - 데이터·이벤트 플랫폼 (Priority: P1)

운영자는 pod마다 독점하는 Postgres database와 role, 백업이 자동으로 Object Storage로 가는 CNPG 클러스터, Strimzi로 선언된 Kafka 토픽·사용자, 인증이 걸린 Dragonfly를 갖기를 원한다.

**Why this priority**: 청사진 불변식 "쓰기·마이그레이션 독점"과 "outbox 발행"이 여기서 물리적으로 강제된다. SP-2 pod는 이 계약 위에서만 만들어진다.

**Independent Test**: `identity_admin`·`authentik`·`openfga` database가 생성되고, `identity_admin` app role로 `authentik` DB에 접속하면 거부되며, `KafkaTopic` 생성 후 produce/consume 왕복이 성공하고, barman-cloud 베이스 백업 1회가 `jt-backup` 버킷에 나타난다.

**Acceptance Scenarios**:

1. **Given** CNPG operator와 `pg-main`(instances=1, PG 18, 노드 B)이 Healthy, **When** gitops의 database/role 선언을 sync하면, **Then** pod별 database와 owner role(마이그레이션)·app role(비소유, `BYPASSRLS` 없음)이 생기고, 다른 pod의 app role로 접속하면 `permission denied`다.
2. **Given** `ScheduledBackup`이 선언됨, **When** 첫 스케줄이 실행되면, **Then** `jt-backup` 버킷에 베이스 백업과 WAL 아카이브가 생기고 `kubectl get backup`이 completed를 보인다.
3. **Given** Strimzi 오퍼레이터와 `KafkaNodePool`(KRaft combined 1노드, 노드 A)이 Ready, **When** `KafkaTopic identity-admin.session.revoked`와 `KafkaUser identity-admin`(SCRAM-SHA-512, 자기 토픽 write·구독 read ACL)을 sync하면, **Then** 그 사용자로 produce/consume 왕복이 5초 내 성공하고, 다른 pod의 사용자로 write하면 거부된다.
4. **Given** Dragonfly dev·prod 인스턴스가 `data` 네임스페이스에 있음, **When** 비밀번호 없이 접속하면, **Then** 거부되고, `maxmemory` 768 MB와 5분 스냅샷 PVC가 설정되어 있다.
5. **Given** dev 환경, **When** dev용 database·토픽·Dragonfly를 확인하면, **Then** database는 `dev_` 접두, 토픽은 `dev.` 접두, Dragonfly는 dev 인스턴스로 분리되어 prod 자원을 공유하지 않는다.

---

### User Story 4 - 신원·인가 (Priority: P1)

방문자는 `auth.joshuatech.dev`에서 GitHub·Google·이메일로 로그인하고, 운영자는 그 로그인이 pod별 audience 토큰으로 교환되며, OpenFGA와 Cloudflare Access가 함께 경계를 이루기를 원한다.

**Why this priority**: 청사진의 핵심 불변식("발급자는 Authentik 하나", "자기 iss·aud만 검증")이 여기서 검증된다. 세션 정본과 즉시 폐기(D7)도 이 스토리의 일부다.

**Independent Test**: GitHub 소셜 로그인 성공 → `web-bff` 토큰 → `identity-admin` audience로 교환 → identity-admin이 자기 JWKS로 검증해 200. 로그아웃 후 1초 뒤 같은 access 토큰으로 호출하면 401.

**Acceptance Scenarios**:

1. **Given** Authentik이 `identity` 네임스페이스에서 Healthy이고 소셜(GitHub·Google)·이메일/비밀번호·MFA 단계가 구성됨, **When** 브라우저로 `auth.joshuatech.dev`에서 GitHub로 로그인하면, **Then** 로그인이 성공하고 사용자 Sessions 화면에 세션이 보인다.
2. **Given** Application/Provider `web-bff`(confidential, token exchange grant)와 `identity-admin`(자기 issuer·JWKS, Federated Providers에 `web-bff` 허용)이 있음, **When** BFF가 RFC 8693 교환을 요청하면, **Then** `aud=identity-admin`·`tenant_id` 클레임을 가진 5분 TTL access 토큰이 돌아오고, `portfolio-core` audience로는(SP-1에서 미허용) 거부된다.
3. **Given** 사용자가 로그인 상태, **When** BFF의 `/api/auth/logout`을 호출하면, **Then** identity-admin이 Authentik refresh 토큰을 revoke하고 Dragonfly에 `revoked:{sub}`(not-before)를 기록하며 Kafka `identity-admin.session.revoked`를 발행하고, 1초 뒤 같은 access 토큰으로 identity-admin을 호출하면 401이다.
4. **Given** Authentik 관리자가 사용자 세션을 삭제함, **When** Authentik 웹훅(logout 이벤트)이 identity-admin에 도착하면, **Then** 3번과 같은 거부 목록 기록이 일어난다.
5. **Given** OpenFGA가 `identity` 네임스페이스에서 `pg-main`의 `openfga` DB로 동작함, **When** 초기 모델(`tenant#member`)을 store에 쓰고 check API를 호출하면, **Then** 튜플 유무에 따라 allowed true/false가 돌아온다.
6. **Given** `admin-identity-admin.joshuatech.dev`(Django admin)와 `identity-admin-api.joshuatech.dev`가 Cloudflare Access 뒤에 있음, **When** Access 헤더 없이 호출하면, **Then** Cloudflare가 403을 돌려주고, BFF의 서비스 토큰(Service Auth 정책)으로 호출하면 통과한다.

---

### User Story 5 - 웹 hello와 BFF 왕복 (Priority: P1)

방문자는 `joshuatech.dev`에서 ko·en·ja 페이지를 보고, 운영자는 그 페이지가 Workers 정적 자산으로 무료로 나가며 BFF Route Handler만 Worker에서 실행되어 identity-admin까지 왕복하기를 원한다.

**Why this priority**: 웹 트랙(D4)의 성립 조건인 "서버 번들 예산"과 "프리렌더 페이지는 Worker를 거치지 않음"을 실측하는 유일한 방법이다. 콘텐츠 로더(D19)의 첫 실전 사용이기도 하다.

**Independent Test**: `https://joshuatech.dev/ko`·`/en`·`/ja`가 200이고 `content/study`의 학습 노트 목록(001·002)을 보여준다. `/api/health`가 identity-admin `/health`를 Access 서비스 토큰으로 호출해 200을 중계한다. CI의 bundle-budget이 gzip ≤ 2.5 MiB를 보고한다.

**Acceptance Scenarios**:

1. **Given** `apps/web`(Next.js 16.3 + `@opennextjs/cloudflare`)이 `generateStaticParams`로 `[lang]` 페이지를 전부 프리렌더함, **When** main에 머지되어 `wrangler deploy`되면, **Then** `joshuatech.dev/{ko,en,ja}`가 200이고, Workers 대시보드에서 해당 GET이 정적 자산 요청으로 집계되며 Worker 호출 수에 포함되지 않는다.
2. **Given** `packages/content`가 `content/study/*.mdx`를 zod 스키마로 검증함, **When** hello 페이지를 빌드하면, **Then** 001·002 학습 노트의 제목·날짜·태그가 목록에 나오고, `draft: true`인 노트는 프로덕션 빌드에서 제외되며, 스키마에 맞지 않는 frontmatter(예: `pubDate` 누락)는 빌드를 실패시킨다.
3. **Given** BFF Route Handler `/api/health`가 있음, **When** 호출하면, **Then** BFF는 Access 서비스 토큰 헤더로 `identity-admin-api.joshuatech.dev/health`를 호출해 200을 중계하고 응답에 `x-request-id`를 남기며, 왕복 p95를 report에 기록한다.
4. **Given** PR이 열림, **When** `ci.yml`이 OpenNext 빌드를 하면, **Then** `scripts/bundle-budget.mjs`가 서버 번들 gzip 크기를 출력하고 2.5 MiB 초과 시 실패한다. 또한 `deploy-web.yml`이 `wrangler versions upload --preview-alias pr-<n>`으로 프리뷰 URL을 PR 코멘트에 남긴다.
5. **Given** i18n 라우트, **When** `/ja`에 번역이 없는 노트를 열면, **Then** ko 본문을 보여주고 "번역 없음" 표시를 붙인다.

---

### User Story 6 - Django pod 템플릿과 공통 라이브러리 (Priority: P1)

pod 구현자(SP-2의 서브에이전트)는 copier 템플릿 한 번으로 테넌트 격리·outbox·인증·관측·테스트가 갖춰진 pod를 만들고, 첫 커밋부터 테스트가 통과하기를 원한다.

**Why this priority**: SP-2 pod 4개가 같은 규율을 갖는 유일한 방법이다. 헌법 II(테스트 우선)·III(격리 키)·IV(관측)를 코드로 강제한다.

**Independent Test**: `copier copy templates/django-pod apps/sample-pod`로 생성한 pod가 `compose.dev.yml`에서 `pytest`를 통과한다 — RLS 0행, outbox → Kafka 발행, 인증 미들웨어(JWKS + 거부 목록), `/health`·`/ready`, JSON 로그 필드.

**Acceptance Scenarios**:

1. **Given** `templates/django-pod`(Django 6.1 + Ninja 1.7, Python 3.13, uv, arm64 Dockerfile)와 `packages/django-common`이 있음, **When** 템플릿으로 pod를 생성하면, **Then** 생성물은 수정 없이 `uv sync` → `pytest`가 통과하고 Docker 이미지가 arm64로 빌드된다.
2. **Given** 템플릿 모델에 `tenant_id NOT NULL`과 RLS 마이그레이션 헬퍼가 적용됨, **When** app role로 tenant A의 트랜잭션(`SET LOCAL app.tenant_id`) 안에서 tenant B의 행을 조회하면, **Then** 0행이고, `SET LOCAL` 없이 조회하면 정책이 기본 거부해 0행이다.
3. **Given** outbox 모델과 릴레이 command가 있음, **When** 도메인 쓰기와 outbox 삽입이 한 트랜잭션에서 커밋되면, **Then** 릴레이가 5초 내 CloudEvents JSON을 토픽에 발행하고 행을 삭제하며, 발행 실패 시 `attempts`를 올리고 행을 남긴다.
4. **Given** 인증 미들웨어가 있음, **When** 유효한 JWT로 호출하되 Dragonfly에 `revoked:{sub}`가 있으면, **Then** 401이고, iss·aud가 다르면 401이며, 유효하면 `tenant_id`가 요청 컨텍스트와 로그에 실린다.
5. **Given** structlog·OTel 설정이 있음, **When** 요청을 처리하면, **Then** JSON 로그에 `request_id`·`tenant_id`·`trace_id`가 있고 OTLP 트레이스가 Alloy로 전송된다.
6. **Given** `apps/identity-admin`이 이 템플릿으로 생성됨, **When** gitops `apps/identity-admin/overlays/{dev,prod}`를 sync하면, **Then** `identity-admin-apidev.`·`identity-admin-api.joshuatech.dev/health`가 200이고 ExternalSecret으로 DB·Kafka·Authentik 비밀이 주입된다.

---

### User Story 7 - 관측과 RAM 실측 (Priority: P2)

운영자는 노드·pod 메트릭과 로그가 Grafana Cloud에 도착하고, 노드별 실제 RAM 사용량이 보고되어 SP-3(ES·Kibana)의 자리가 남는지 알기를 원한다.

**Why this priority**: 헌법 IV의 이행이며, 설계의 RAM 추정(노드 A ≈ 8.3 GB, B ≈ 7.5 GB)을 확정하는 유일한 근거다. P1 스토리 뒤에 와야 측정 대상이 있다.

**Independent Test**: Grafana Cloud에서 `kube_node_status_allocatable_memory_bytes`와 identity-admin 로그가 조회되고, `report.md`에 노드별 10분 평균 RAM 표(3회)가 있으며 노드 A ≤ 9 GB, 노드 B ≤ 8 GB이다.

**Acceptance Scenarios**:

1. **Given** Alloy와 kube-state-metrics가 `observability` 네임스페이스에 있음, **When** Grafana Cloud를 열면, **Then** 노드 RAM 예산·pod 오류율·Kafka lag 대시보드 3개가 데이터를 보이고, 알림 2개(노드 RAM > 9.5 GB, Argo OutOfSync 30분)가 등록되어 있다.
2. **Given** 플랫폼 전부(ES 제외)와 identity-admin dev·prod가 떠 있음, **When** `kubectl top nodes`를 10분 간격 3회 기록하면, **Then** 노드 A ≤ 9 GB, 노드 B ≤ 8 GB이고, 초과 시 report에 완화안(Argo core 전환·Alloy 축소·dev quota 축소·Redpanda 검토)을 적는다.
3. **Given** Sentry 프로젝트(identity-admin·web)가 있음, **When** identity-admin에서 의도적 예외를 발생시키면, **Then** Sentry에 이벤트가 `request_id` 태그와 함께 도착한다.
4. **Given** OCI Budgets, **When** 월 예산 알림 $1·$5(Actual + Forecast)를 만들면, **Then** Cost Analysis에서 월 Compute 비용이 3 SGD 이하임을 report에 기록한다.

---

### User Story 8 - v1 정리와 도메인 전환 (Priority: P2)

운영자는 v1 인프라(OCI VM 2대·Render·Fly·Pages)를 정리하되 인스턴스는 재이미지로 유지하고, `joshuatech.dev`가 v2 Workers를 가리키기를 원한다.

**Why this priority**: 같은 인스턴스를 v2가 써야 하므로 US2보다 먼저 시작되지만, 사용자 결정(백업 없음)으로 작업량이 작아 P2다.

**Independent Test**: v1 저장소 워크플로 4개가 `workflow_dispatch`만 갖고, OCI 인스턴스 OCID 2개가 그대로이며 OS가 Ubuntu 24.04로 바뀌었고, `joshuatech.dev` apex가 Workers 응답을 준다. Render·Fly 서비스가 없다.

**Acceptance Scenarios**:

1. **Given** v1 저장소 `joshua92y/joshtech`의 워크플로 4개가 브랜치 필터 없이 prod에 push함, **When** 재이미지 전에 각 워크플로를 `on: workflow_dispatch`만 남기도록 바꾸면, **Then** 이후 어떤 push도 v1 VM에 배포하지 않는다.
2. **Given** 인스턴스 `joshtech_api_1st`·`joshtech_cache`(각 2 OCPU/13 GB), **When** OpenTofu가 부트 볼륨 교체(재이미지)를 적용하면, **Then** 두 인스턴스의 OCID·shape·메모리가 그대로이고 Ubuntu 24.04로 부팅하며, terminate는 일어나지 않는다.
3. **Given** Cloudflare Pages 프로젝트 `joshtech-frontend`가 apex를 소유함, **When** 커스텀 도메인을 해제하고 Workers 커스텀 도메인을 만들면, **Then** `joshuatech.dev`가 5분 내 v2 hello를 서빙하고 `api.`·`admin.`·`mainapi.`·`traefik.` 레코드는 제거되며 `cdn.`은 R2 공개 버킷으로 유지된다.
4. **Given** Render(Django Admin·Postgres)·Fly 잔재, **When** 삭제하면, **Then** 사용자 결정대로 백업·임포트 없이 종료되고 report에 삭제 시각과 대상이 기록된다.

---

### User Story 9 - 에이전트 계층 (Priority: P2)

컨트롤러(Claude)는 SP-2부터 pod·웹·인프라 작업을 맡길 때 경로별 규칙과 전용 빌더 에이전트, K8s 보안 경계 리뷰를 갖기를 원한다.

**Why this priority**: 헌법 워크플로우 3단계(approval-review)와 4단계(subagent-driven-development)가 스택 특화 규칙 없이는 일반론에 머문다.

**Independent Test**: `/approval-review`가 `k8s-security` 경계를 포함해 6개를 디스패치하고, `agents/api-builder.md`가 `django-pod` 규칙과 `test-driven-development` 스킬을 프리로드하며, run-all 미러 검사가 통과한다.

**Acceptance Scenarios**:

1. **Given** `.claude/rules/{web,django-pod,fastapi-pod,infra,events}.md`가 `paths:`를 가짐, **When** 각 경로의 파일을 편집하면, **Then** 해당 규칙만 로드된다(001의 `specs`·`docs`·`content` 규칙과 같은 방식).
2. **Given** `.claude/agents/{web,api,infra}-builder.md`가 있음, **When** 서브에이전트로 디스패치하면, **Then** 각 에이전트는 자기 규칙과 필요한 superpowers 스킬을 프리로드하고 tester-write-guard와 충돌하지 않는다.
3. **Given** `boundaries/k8s-security.md`가 추가됨, **When** `/approval-review`를 실행하면, **Then** 리뷰 파일에 `## K8s security` 절(NetworkPolicy·PSA·시크릿 경로·Access 정책·이미지 digest 검사)이 생긴다.

---

### Edge Cases

- **노드 A 장애**: 컨트롤 플레인·Kafka·Authentik·Vault가 함께 내려간다. 정적 사이트는 Workers에서 계속 서빙되고 BFF는 503을 반환하며, 노드 B의 Postgres는 살아 있다. 복구는 재부팅 → Vault 자동 unseal → Argo 재동기화. 단일 서버 K3s의 수용된 장애 도메인이며 report에 명시한다.
- **Vault 자동 unseal 실패(OCI KMS 장애)**: Vault sealed → ESO는 마지막 Secret을 유지해 기존 pod는 계속 돌고, 새 pod만 시크릿을 못 받는다. 런북의 recovery 키(3/5, 오프라인 보관)로 수동 unseal.
- **Dragonfly 재시작으로 거부 목록 유실**: 최대 access TTL(5분) 동안 폐기 전 토큰이 통과할 수 있다. 5분 스냅샷 PVC로 창을 줄이고, identity-admin은 재시작 시 최근 5분의 `session.revoked` 이벤트를 Kafka에서 재적용한다.
- **Authentik 웹훅 유실**: identity-admin이 받지 못한 세션 삭제는 access TTL 뒤에야 반영된다. 웹훅 재시도(Authentik 알림 전송 재시도)와 일별 대조(활성 세션 목록 API)로 보정한다.
- **토큰 교환 거부**: Federated Providers에 호출자가 없거나 정책 바인딩 실패 시 BFF는 401을 반환하고 재로그인을 유도하며, 교환 실패율을 메트릭으로 남긴다.
- **cert-manager 발급 실패·LE 레이트 리밋**: 네임스페이스마다 와일드카드 1장을 발급하므로 SAN 조합당 주 5회 제한에 주의한다. `Certificate`를 삭제·재생성하지 않고, 실패 시 staging issuer로 진단한다.
- **OpenNext 서버 번들 초과**: bundle-budget이 실패하면 의존성을 서버 번들에서 제거한다. 구조적 초과면 ADR 0004의 탈출구(Workers Paid $5)를 사용자 승인으로 발동한다.
- **Workers Free 일 한도(100k 요청·10 ms CPU) 초과**: BFF만 영향(429·CPU 초과 오류). 정적 페이지는 무관. 알림 후 Paid 검토.
- **Image Transformations 월 5,000 변환 초과**: 오류가 반환되므로 커스텀 loader가 원본 URL로 폴백한다.
- **ESO 동기화 실패(경로 오타·정책 누락)**: Secret이 만들어지지 않아 pod가 시작되지 않는다. Argo Health가 Degraded를 보이고 알림이 간다. 시크릿 경로는 gitops validate.yml에서 정규식 검사한다.
- **dev 네임스페이스 quota 소진**: 새 pod가 Pending. LimitRange 기본값으로 requests가 채워지므로 quota 계산이 예측 가능하고, 알림으로 감지한다.
- **Kafka 디스크 포화**: 보존 7일·파티션 3으로 상한을 두고, PVC 사용률 80% 알림. outbox가 원천이므로 유실은 지연으로만 나타난다.
- **Argo sync-wave 교착**: CRD가 늦게 생겨 Application이 Unknown이면 `SkipDryRunOnMissingResource`와 wave 순서로 해결하고, 실패 시 root app만 재동기화한다.
- **K3s 업그레이드로 Traefik 차트 변경**: HelmChartConfig를 최소화하고 system-upgrade-controller 창(window)에서만 업그레이드한다.
- **PAYG 무료분 초과 과금 증가**: 예산 알림($1·$5)과 월 1회 Cost Analysis. 13 GB → 12 GB 축소는 재부팅 1회로 가능하다.
- **v1 재이미지 중 인스턴스 종료 사고**: OpenTofu plan에서 `destroy`가 나오면 apply를 중단한다(재이미지는 부트 볼륨 교체여야 한다). 인스턴스 보호(`preserve_boot_volume`, lifecycle `prevent_destroy`)를 켠다.
- **도메인 전환 공백**: Pages 커스텀 도메인 해제와 Workers 도메인 생성 사이 수 분의 공백은 수용하고 낮은 트래픽 시간에 수행한다.
- **콘텐츠 스키마 위반**: frontmatter 오류는 빌드 실패로 드러나야 하며, 경고로 넘기지 않는다.

## Requirements *(mandatory)*

### Functional Requirements

**문서·에이전트 계층**

- **FR-001**: ADR 0002(배포 원칙)·0003(런타임 트랙)·0004(웹)·0005(백엔드 프레임워크 정책)·0006(신원·인가·세션)·0007(데이터 소유·테넌시)·0008(이벤트)·0009(검색)·0010(시크릿)을 MADR minimal(`status: accepted`, `date`, `decision-makers`, Context / Considered Options / Decision Outcome / Consequences)로 작성하고 `docs/README.md`·이 spec에서 링크해야 한다.
- **FR-002**: `.specify/memory/product.md`와 `architecture.md`를 작성해야 하며, 두 문서는 `<!-- SPECKIT START/END -->` 블록과 archive 통합본(`spec.md`·`plan.md`·`changelog.md`)과 별개의 파일로 유지된다.
- **FR-003**: `.claude/rules/{web,django-pod,fastapi-pod,infra,events}.md`(각 `paths:` 스코프), `.claude/agents/{web,api,infra}-builder.md`, `.claude/skills/approval-review/boundaries/k8s-security.md`와 `docs/kr/` 미러를 추가해야 하고, `/approval-review`는 경계 6개를 디스패치해야 한다.

**인프라·클러스터**

- **FR-004**: OpenTofu로 OCI(VCN·퍼블릭 서브넷·보안 리스트·인스턴스 2대 재이미지·Object Storage `jt-backup`/`jt-tfstate`·KMS 키)와 Cloudflare(DNS 레코드·Access 앱/정책·Authenticated Origin Pulls·R2·Workers 커스텀 도메인)를 선언해야 하며, 상태는 `jt-tfstate` S3 호환 백엔드에 두고 저장소에는 커밋하지 않는다.
- **FR-005**: 네트워크 보안 그룹(NSG)은 노드 A 443만 Cloudflare IPv4/IPv6 대역에 열고(80은 열지 않음 — Always Use HTTPS는 edge에서, LE는 DNS-01) 22를 닫으며, 노드 B는 인바운드 공개 규칙이 없어야 한다. 클러스터 내부 규칙(K3s 6443·10250·8472/udp·Postgres·Kafka)은 NSG 자기참조로만 연다.
- **FR-006**: 인스턴스 `joshtech_api_1st`·`joshtech_cache`는 재이미지(부트 볼륨 교체)로 재사용해야 하며 terminate해서는 안 된다. OpenTofu에 `prevent_destroy`를 둔다.
- **FR-007**: K3s v1.36.x를 노드 A server(`--secrets-encryption`, SQLite, 라벨 `role=platform`)·노드 B agent(`role=data`)로 설치하고, 번들 Traefik ServiceLB를 노드 A에만 바인드하며, local-path-provisioner를 사용해야 한다. kubectl 접근은 cloudflared 터널 + Access를 통해서만 한다.
- **FR-008**: StatefulSet(Kafka → A, CNPG·Dragonfly → B)은 `nodeSelector`로 고정하고, 앱 Deployment는 노드 A 선호 affinity를 가지며, CPU limit은 두지 않는다.

**GitOps·인그레스·시크릿**

- **FR-009**: public 저장소 `platform-gitops`를 만들고 `bootstrap/`(Argo CD·root-app)·`clusters/oci-k3s/`(projects·app-of-apps)·`platform/*`·`apps/<pod>/{base,overlays/dev,overlays/prod}`·`secrets/`(ExternalSecret만)·`.github/workflows/{validate,promote}.yml` 구조를 가져야 한다.
- **FR-010**: Argo CD는 AppProject `platform`·`dev`·`prod`를 두고 `default`의 sourceRepos·destinations를 비우며, 플랫폼 Application은 sync-wave(CRD·namespaces → cert-manager·ESO → Vault → CNPG operator → pg-main·Dragonfly·Kafka → Authentik·OpenFGA → Alloy·cloudflared·Traefik 설정)를 지키고 `ServerSideApply=true`, platform은 `Prune=confirm`·`Delete=confirm`이어야 한다.
- **FR-011**: cert-manager ClusterIssuer(LE staging·prod, Cloudflare DNS-01, 토큰은 ESO 경유)로 `joshuatech.dev` + `*.joshuatech.dev` 와일드카드를 **kube-system에 1장만** 발급해 Traefik `TLSStore default`의 기본 인증서로 쓰고(리허설·CI는 staging 발급자만, LE 동일 SAN 5회/7일 한도 보호), Traefik은 표준 `Ingress`(ingressClassName traefik, `router.tls: true`, base `PLACEHOLDER` 호스트 + overlay JSON6902 패치, `spec.tls` 생략)로 라우팅하며 HelmChartConfig로 JSON 액세스 로그·OTLP 트레이싱을 켜야 한다.
- **FR-012**: Cloudflare SSL은 Full(strict), Authenticated Origin Pulls를 존에 켜고 Traefik이 Cloudflare 오리진 CA를 클라이언트 인증서로 요구해야 한다. 오리진 IP 직접 호출은 실패해야 한다.
- **FR-013**: HashiCorp Vault를 `vault` 네임스페이스에 Raft 1 replica(노드 A PVC)로 설치하고 OCI KMS 키로 자동 unseal하며, Kubernetes auth method로 ESO를 인증해야 한다. Vault UI는 `vault.joshuatech.dev`에서 Access + Authentik OIDC 뒤에 둔다.
- **FR-014**: 모든 런타임 시크릿(DB·Kafka SCRAM·Authentik·OAuth client·Cloudflare 토큰·Access 서비스 토큰·R2·Sentry·Grafana Cloud)은 Vault `kv/{env}/{component}/…` 경로에서 ESO `ExternalSecret`으로만 주입되어야 한다. 두 저장소는 gitleaks를 required check로 두고 0건이어야 한다.
- **FR-015**: 관리 접근(SSH·kubectl·Vault init)은 cloudflared 터널(2 replica, 노드별 anti-affinity) + Access(GitHub IdP)로만 하며, 공개 SSH 포트는 없어야 한다.

**데이터·이벤트**

- **FR-016**: CNPG operator와 클러스터 `pg-main`(instances=1, PostgreSQL 18 standard 이미지, 노드 B, PVC 40 Gi, `shared_buffers` 512 MB, 확장 pgvector — pg_bigm은 자체 확장 이미지가 필요해 SP-3 검색 feature로 이월)을 선언하고, pod별 database(`identity_admin`·`portfolio_core`·`media`·`engagement`·`notification`·`insights`·`search`·`assistant`·`authentik`·`openfga`)와 owner role·app role을 gitops에서 선언해야 한다. app role은 테이블 비소유·`BYPASSRLS` 없음이며 다른 pod DB에 접근할 수 없어야 한다.
- **FR-017**: dev 환경은 `dev_` 접두 database를 쓰고, database 비밀번호는 Vault → ESO → CNPG `managed.roles.passwordSecret` 단방향으로 흐른다.
- **FR-018**: barman-cloud 플러그인으로 `jt-backup`(S3 호환)에 주 1회 베이스 백업 + 연속 WAL 아카이브(보존 30일)를 선언하고 첫 백업이 성공해야 한다.
- **FR-019**: Strimzi 오퍼레이터와 `KafkaNodePool`(KRaft combined 1노드, 노드 A, 브로커 `-Xmx1g`, local-path PV)을 선언하고, `KafkaTopic`(파티션 3, 보존 7일)·`KafkaUser`(SCRAM-SHA-512, pod별, 자기 토픽 write·구독 토픽 read ACL)를 gitops에서 관리해야 한다. 토픽 이름은 `<pod>.<entity>.<event>`(prod)·`dev.<pod>.<entity>.<event>`(dev)이다.
- **FR-020**: Dragonfly를 `data` 네임스페이스에 dev·prod 인스턴스로 두고 인증 필수, `--maxmemory=768mb`, PVC + 5분 스냅샷이어야 한다.
- **FR-021**: `packages/events`에 CloudEvents 1.0 JSON Schema(2020-12)를 토픽별로 두고(`specversion·id(ULID)·source·type·time·subject·tenantid·data`), CI가 하위 호환(필드 삭제·타입 변경 금지)을 검사해야 한다. SP-1에서 최소 6개 토픽 스키마를 정의한다: `identity-admin.user.registered`·`identity-admin.tenant.created`·`identity-admin.session.revoked`·`portfolio-core.note.published`·`engagement.comment.created`·`media.object.ready`.

**신원·인가·세션**

- **FR-022**: Authentik을 `identity` 네임스페이스에 설치(server + worker, DB는 `pg-main`의 `authentik`)하고 소셜(GitHub·Google)·이메일/비밀번호·MFA(TOTP·passkey) 흐름을 구성해야 한다. Application/Provider: `web-bff`(confidential, token exchange grant), pod별 provider(자기 issuer·JWKS), 관리 앱(`argocd`·`vault`·`grafana`·Django admin forward-auth). Scope mapping `tenant_id`. 교환 토폴로지(Federated Providers)는 SP-1에서 `web-bff → identity-admin`만 허용한다.
- **FR-023**: 세션 정본은 Authentik이며, BFF는 암호화된 refresh 토큰을 HttpOnly·Secure·SameSite=Lax 쿠키로 보관하고 access 토큰(5분 TTL)을 isolate 캐시한다. BFF는 요청 처리 전 identity-admin `/session/check`(2초 캐시)로 폐기 여부를 확인한다.
- **FR-024**: 로그아웃·관리자 폐기·Authentik 세션 삭제(웹훅)는 identity-admin이 처리해 Authentik 토큰 revoke, Dragonfly `revoked:{sub}`(not-before, TTL = access TTL) 기록, Kafka `identity-admin.session.revoked` 발행을 수행해야 한다. 모든 pod의 인증 미들웨어는 JWT 검증 뒤 Dragonfly를 1회 조회해 거부해야 한다.
- **FR-025**: OpenFGA를 `identity` 네임스페이스에 설치(DB `openfga`)하고 초기 모델(`tenant#member`)과 env별 store를 선언해야 한다. 튜플 쓰기는 관계를 정의하는 pod만 한다(SP-1에서는 identity-admin의 `tenant#member`).
- **FR-026**: Cloudflare Access 정책: `<pod>-api.*`·`<pod>-apidev.*`는 Service Auth(BFF 서비스 토큰)만, `admin-*`·`argo.`·`vault.`·`kibana.`·Traefik 대시보드는 GitHub IdP 로그인 필수여야 한다. 서비스 토큰은 Vault에 보관하고 1년 만료·회전 런북을 둔다.

**웹·콘텐츠**

- **FR-027**: `apps/web`은 Next.js 16.3 App Router + `@opennextjs/cloudflare`로 빌드하며 모든 페이지를 `app/[lang]`(ko 기본·en·ja) 아래 `generateStaticParams`로 프리렌더하고, 서버 번들에는 BFF Route Handler(`/api/auth/{login,callback,logout,refresh}`, `/api/health`, `/api/session/check` 프록시)만 포함해야 한다. Sentry 서버 SDK·i18n 런타임·인증 라이브러리는 서버 번들에 넣지 않는다.
- **FR-028**: `scripts/bundle-budget.mjs`가 서버 번들 gzip 크기를 측정해 2.5 MiB 초과 시 CI를 실패시켜야 하며, ADR 0004는 초과 시 탈출구(Workers Paid)를 명시한다.
- **FR-029**: `packages/content`는 `content/{study,blog,projects}`를 빌드 시 읽어 zod 스키마(`.claude/rules/content.md` 계약: title·description·pubDate·updatedDate·tags·series·seriesOrder·draft·change·sources)로 검증하고, 다국어 접미사(`<slug>.mdx`·`<slug>.en.mdx`·`<slug>.ja.mdx`)·draft 필터·1회 스캔 캐시·remark/rehype(헤딩 앵커·목차·읽기 시간·코드 하이라이트)를 제공해야 한다. 스키마 위반은 빌드 실패다.
- **FR-030**: 이미지는 저장소 자산은 빌드 시 변형, 업로드 자산은 R2 원본 + `next/image` 커스텀 loader가 `cdn.joshuatech.dev/cdn-cgi/image/…`(Cloudflare Image Transformations)를 쓰며 변환 오류 시 원본으로 폴백해야 한다.
- **FR-031**: 디자인 시스템은 라이브러리 없이 소스로 소유한다. SP-1은 토큰 3계층(primitive → semantic → component)의 뼈대와 hello 페이지에 필요한 컴포넌트만 만들고, Material Design 어휘·slot 반응형 레이아웃은 SP-2에서 확장한다. Once UI 소스는 복사하지 않는다.
- **FR-032**: `deploy-web.yml`은 PR에서 `wrangler versions upload --preview-alias pr-<n>`, main에서 `wrangler deploy`를 계정 소유 API 토큰(Workers Scripts Edit, TTL·IP 제한)으로 수행해야 한다.

**pod 템플릿·공통 라이브러리**

- **FR-033**: `templates/django-pod`(copier)는 Django 6.1 + Django Ninja 1.7, Python 3.13, uv(`uv.lock`), 멀티스테이지 arm64 Dockerfile(비루트), Celery(Dragonfly 브로커)·beat, pydantic-settings(필수값 누락 시 부팅 실패, `env.example`은 키만), `/health`·`/ready`, `compose.dev.yml`, gitops용 kustomize base(Deployment·Service·Ingress PLACEHOLDER·ExternalSecret), 내장 테스트를 생성해야 한다.
- **FR-034**: `packages/django-common`은 tenant 미들웨어(토큰 `tenant_id` → 요청 트랜잭션 안 `SET LOCAL app.tenant_id`), RLS 마이그레이션 헬퍼(`ENABLE/FORCE ROW LEVEL SECURITY` + 정책), outbox 모델·릴레이 command(`SELECT … FOR UPDATE SKIP LOCKED`, idempotent producer, 성공 시 삭제·실패 시 attempts), CloudEvents producer, 인증 미들웨어(JWKS + 거부 목록 + Access JWT), structlog JSON(`request_id`·`tenant_id`·`trace_id`)·OTel SDK·Sentry 초기화를 제공해야 한다.
- **FR-035**: 템플릿 내장 테스트는 RLS 0행, outbox 발행, 인증 미들웨어(폐기·iss·aud), health/ready, 로그 필드, OpenAPI 스냅샷을 포함하며 testcontainers(Postgres·Kafka)로 실행되어야 한다.
- **FR-036**: `apps/identity-admin`은 이 템플릿으로 생성해 `/health`·`/ready`, `POST /sessions/revoke`, `GET /session/check`, Authentik 웹훅 수신, `identity-admin.session.revoked` 발행을 구현하고 gitops `apps/identity-admin/overlays/{dev,prod}`로 배포되어야 한다. 테넌트 오케스트레이션·Blueprints 적용은 SP-2다.

**CI/CD·환경·운영**

- **FR-037**: 모노레포 워크플로: `ci.yml`(PR·main: lint·test·build·gitleaks·bundle-budget·events 호환성·kubeconform), `publish-pod.yml`(main, `paths` 필터, `ubuntu-24.04-arm` 네이티브 빌드, GHCR digest push, artifact attestation, GitHub App으로 gitops `overlays/dev` digest 커밋), `deploy-web.yml`. 액션은 SHA 핀, `permissions` 최소, PAT 없음, Renovate 설정.
- **FR-038**: gitops 워크플로: `validate.yml`(kustomize build·helm template·kubeconform·시크릿 경로 정규식·`argocd app diff` 코멘트, required check), `promote.yml`(workflow_dispatch: dev digest → prod PR). ruleset은 main에 PR 필수·required check·0 approvals·CI App만 bypass.
- **FR-039**: 네임스페이스 `jt-dev`·`jt-prod`는 ResourceQuota(dev requests 2 Gi/limits 4 Gi/pods 20, prod 3 Gi/6 Gi/30)와 LimitRange(default 500m/512 Mi)를 가지며, dev는 auto-sync + selfHeal, prod는 PR 머지로만 변경된다.
- **FR-040**: Alloy(+kube-state-metrics)가 노드·pod 메트릭·컨테이너 로그·OTLP 트레이스를 Grafana Cloud로 보내고, 대시보드 3개(노드 RAM 예산·pod 오류율·Kafka lag)와 알림 2개(노드 RAM > 9.5 GB, Argo OutOfSync 30분)를 선언해야 한다. Sentry 프로젝트는 identity-admin·web(클라이언트만).
- **FR-041**: `docs/runbooks/`에 bootstrap(클러스터·root app·Vault init)·vault-unseal·rollback(gitops revert·wrangler rollback)·restore-drill(CNPG)·ram-budget·access-token-rotation을 작성해야 한다.
- **FR-042**: v1 정리: v1 저장소 워크플로 4개를 `workflow_dispatch` 전용으로 바꾸고, Pages 프로젝트에서 apex를 해제해 Workers 커스텀 도메인으로 옮기며, Render·Fly 잔재를 삭제하고, `api.`·`admin.`·`mainapi.`·`traefik.` DNS 레코드를 제거한다. 백업·데이터 임포트는 하지 않는다(사용자 결정).
- **FR-043**: OCI Budgets에 월 $1·$5 알림(Actual + Forecast)을 만들고 report에 월 Compute 비용과 노드별 RAM 실측 표를 기록해야 한다.
- **FR-044**: 모든 User Story는 tester 에이전트가 실행하는 E2E 시나리오 task를 가지며(헌법 II), 클러스터 검증은 cloudflared 터널을 통한 kubectl·argocd CLI로, 브라우저 검증은 Playwright로 수행한다.

### Key Entities

헌법 III에 따라 데이터 소유 엔티티마다 소유자와 격리 키를 적는다. SP-1은 단일 테넌트(`joshuatech`)를 시드하지만 모든 계약은 `tenant_id`를 가진다.

- **Tenant**: 소유 identity-admin(DB `identity_admin`). 격리 키 `tenant_id`(자기 자신). SP-1은 `joshuatech` 1건 시드. Authentik 그룹 `tenant:<id>`·OpenFGA `tenant#member`와 매핑.
- **SessionRevocation**: 소유 identity-admin. 저장 Dragonfly(`revoked:{sub}` not-before, `revoked:{sid}`), TTL = access TTL. 사용자 단위이므로 `tenant_id`는 이벤트 페이로드에만 실린다. 이벤트 `identity-admin.session.revoked`.
- **OutboxEvent**: 소유 각 pod(자기 DB의 `outbox` 테이블). 격리 키 `tenant_id`(Kafka 파티션 키). 필드 id(ULID)·topic·key·payload(CloudEvents)·created_at·attempts.
- **EventSchema**: 소유 모노레포 `packages/events`(전역, 테넌트 무관). 토픽별 JSON Schema와 버전.
- **KafkaTopic / KafkaUser**: 소유 platform-gitops(전역 플랫폼 자원). 토픽은 pod 접두로 소유 pod가 정해지고, dev는 `dev.` 접두로 분리.
- **Database / Role**: 소유 platform-gitops(CNPG 선언). pod당 database 1개 + owner/app role. dev는 `dev_` 접두. 테넌트 격리는 database 안의 RLS.
- **SecretPath**: 소유 운영자(Vault `kv/{env}/{component}/…`). 전역·env 분리. 저장소에는 경로만.
- **AuthentikObject**(Application·Provider·Scope mapping·Federated Providers·Brand): 소유 identity(Blueprints 파일은 gitops `platform/authentik/blueprints/`). 테넌트별 Brand는 SP-4.
- **FgaModel / FgaStore**: 소유 identity(모델 파일은 모노레포 `packages/authz/model.fga`), store는 env별. 튜플 소유는 관계를 정의하는 pod.
- **ContentItem**(학습 노트·글·프로젝트): 소유 git(`content/**`, 전역 — 소유자 테넌트의 콘텐츠). frontmatter 계약은 `rules/content.md`. DB 메타·반응은 SP-2 portfolio-core가 slug로 연결하며 그때 `tenant_id`를 붙인다.
- **ADR**: 소유 `docs/decisions/`(전역 문서). 번호 재사용 금지, 상태 accepted/superseded.
- **RamReport**: 소유 `specs/003-platform-foundation/report.md`. 노드별 10분 평균 3회, 구성요소별 requests/실측.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 노드 2개 Ready, root app 하나의 수동 apply 뒤 30분 안에 플랫폼 Application 전부(ES 제외)가 Synced/Healthy.
- **SC-002**: 브라우저 E2E — GitHub 소셜 로그인 → BFF 세션 → `/api/health` → identity-admin 200이 dev·prod 양쪽에서 통과하고, BFF → pod 왕복 p95 ≤ 300 ms(Cloudflare 서울 엣지 ↔ 춘천, report에 실측값 기록).
- **SC-003**: 로그아웃(또는 Authentik 세션 삭제) 뒤 2초 안에 같은 access 토큰으로의 호출이 401.
- **SC-004**: 템플릿으로 생성한 pod의 내장 테스트 100% 통과, RLS 0행 테스트와 outbox → Kafka 발행(5초 내) 포함; tester가 재현.
- **SC-005**: 부하 없는 정상 상태 10분 평균으로 노드 A ≤ 9 GB, 노드 B ≤ 8 GB 사용(3회 측정, report 표).
- **SC-006**: 두 저장소 gitleaks 0건, gitops 매니페스트에 시크릿 값 0개(ExternalSecret 참조만).
- **SC-007**: 웹 서버 번들 gzip ≤ 2.5 MiB, `joshuatech.dev/{ko,en,ja}` GET이 Workers 대시보드에서 정적 자산 요청으로 집계(Worker 호출 0), 학습 노트 2편이 목록에 표시.
- **SC-008**: ADR 9개가 run-all MADR 검사를 통과하고 `docs/README.md`·spec에서 링크됨; `.claude/rules` 5개가 경로 스코프로 로드됨; `/approval-review` 경계 6개.
- **SC-009**: 8월 이후 첫 청구월의 OCI Compute 비용 ≤ 3 SGD, 예산 알림 2개 등록.
- **SC-010**: dev 자동 digest bump → Argo sync ≤ 5분; `promote.yml` PR 머지 → prod sync ≤ 5분; `git revert` 롤백 ≤ 5분(각 1회 실연).
- **SC-011**: CNPG 베이스 백업 1회 + WAL 아카이브가 `jt-backup`에 존재하고 `restore-drill` 런북이 작성됨(실연은 SP-3).
- **SC-012**: v1: 워크플로 4개 `workflow_dispatch` 전용, 인스턴스 OCID 2개 불변, `joshuatech.dev` → Workers, Render·Fly 0개.

## Assumptions

- OCI 테넌시는 PAYG(2026-08-28 CLI 확인: `plan-type PAYG`, `UPGRADED`, SGD)이며 유료 테넌시의 A1 무료분은 가격표 기준 월 3,000 OCPU-h / 18,000 GB-h로 가정한다(Oracle 문서는 계정 유형별 무료분을 명시하지 않음). 첫 청구서로 재확인하고, 어긋나면 D17을 재검토한다.
- 인스턴스 2대(각 2 OCPU/13 GB, 2025-05 생성)는 재이미지 후에도 같은 shape로 유지된다. 춘천 리전은 Always Free A1 불가 리전이므로 Always Free 축소 시나리오는 고려하지 않는다.
- `joshuatech.dev` 존은 Cloudflare Free 플랜에 활성 상태이고, Workers Free·Zero Trust Free(50석)·R2 Free·Image Transformations Free(월 5,000 변환) 한도는 2026-08-27 조사값이다. 한도 변경 시 ADR 0004·0006에 기록한다.
- Authentik 2026.8 OSS는 RFC 8693 token exchange를 제공하며, `act` 클레임(위임)은 Enterprise 전용이므로 호출자 식별은 impersonation 교환 + Access 서비스 토큰 ID로 한다.
- Strimzi는 KRaft combined 단일 노드 `KafkaNodePool`을 지원하고, 오퍼레이터 + Entity Operator RAM은 0.5–0.8 GB로 추정한다(실측 US7).
- 개발기는 Windows 11 + WSL(OpenNext는 Windows 완전 지원 비보장). 서브에이전트·tester는 cloudflared 터널로 클러스터에 접근한다.
- SP-1 기간 외부 사용자는 없고, 로그인 테스트 계정은 운영자 본인의 GitHub·Google 계정이다.
- Grafana Cloud Free·Sentry Free 계정은 운영자가 만들고 토큰을 Vault에 넣는다. GitHub App(gitops 커밋용)과 GHCR public 이미지도 운영자 권한으로 만든다.
- v1 데이터는 백업·임포트하지 않는다(사용자 결정 2026-08-28). v1 저장소 자체는 보존한다.
- 학습 노트 001·002는 이미 `rules/content.md` 계약을 따르므로 hello 페이지의 콘텐츠 로더 검증 입력으로 쓸 수 있다.
- ES/ECK·Kibana(D11)는 SP-3에서 구현하지만 노드 RAM 예산에 자리(A 1 GB, B 2 GB)를 남긴다.

## Design

### 1. 토폴로지와 노드 배치

```
브라우저 ─HTTPS─▶ Cloudflare(DNS·proxied·Access·WAF)
                    ├─ 정적 자산(무료) ─▶ Workers: Next.js OpenNext lean(프리렌더 + BFF Route Handlers)
                    └─ 80/443(Cloudflare IP만, AOP mTLS) ─▶ 노드 A Traefik ─▶ Ingress(host) ─▶ pod / Authentik / Argo UI
BFF ─(토큰 교환 후, Access 서비스 토큰)─▶ <pod>-api.joshuatech.dev

노드 A role=platform (2 OCPU/13 GB): K3s server·Traefik·cert-manager·Argo CD·Vault+ESO·Strimzi Kafka·Authentik·OpenFGA·Alloy·cloudflared  ≈ 8.3 GB
노드 B role=data     (2 OCPU/13 GB): K3s agent·CNPG pg-main·Dragonfly(dev·prod)·앱 pod+워커(dev·prod)·cloudflared          ≈ 7.5 GB
SP-3 자리: Kibana·ECK(A ≈ 1 GB), Elasticsearch(B ≈ 2 GB)
```

배치 원칙: StatefulSet은 `nodeSelector` 고정(Kafka → A: Postgres fsync/WAL과 디스크 I/O 분리), 앱 Deployment는 A 선호, CPU limit 없음. 네임스페이스: `kube-system`·`cert-manager`·`argocd`·`vault`·`external-secrets`·`data`·`identity`·`observability`·`jt-dev`·`jt-prod`. AppProject: `platform`·`dev`·`prod`. NetworkPolicy: `data`·`identity`는 `jt-*`·플랫폼 네임스페이스에서만 접근.

### 2. 저장소 구조

```
joshuatech_ver2/
├── apps/
│   ├── web/                      # Next.js 16.3 + OpenNext lean: app/[lang], app/api(BFF), src/design, src/lib/gateway.ts, scripts/bundle-budget.mjs
│   ├── identity-admin/           # Django pod (SP-1: health·session revoke·webhook; SP-2: 테넌트·Blueprints)
│   ├── portfolio-core/ · media/ · engagement/           # SP-2
│   └── notification/ · insights/ · search/ · assistant/ # SP-3·SP-4 (예약)
├── packages/
│   ├── content/                  # MDX 로더(zod·다국어·캐시·remark/rehype), CI notes-sync 재사용
│   ├── events/                   # CloudEvents JSON Schema + 호환성 검사
│   ├── authz/                    # OpenFGA 모델 파일
│   ├── django-common/            # tenant·RLS·outbox·auth·observability
│   └── fastapi-common/           # SP-3
├── templates/django-pod/ · fastapi-pod/(SP-3)
├── content/{study,blog,projects,assets}/
├── infra/{oci,cloudflare,bootstrap}/        # OpenTofu(상태: jt-tfstate) · k3s 설치·root app·Vault init 런북
├── docs/{decisions/0002–0010,runbooks,kr}/
├── specs/003-platform-foundation/
├── .claude/{rules,agents,skills/approval-review/boundaries/k8s-security.md}
└── .github/workflows/{ci,publish-pod,deploy-web}.yml (+ notes-sync SP-2)

platform-gitops/ (public)
├── bootstrap/{argocd,root-app.yaml}
├── clusters/oci-k3s/{projects,apps}/
├── platform/{cert-manager,traefik,vault,external-secrets,cnpg,kafka(Strimzi),dragonfly,authentik(blueprints),openfga,observability,cloudflared,policies}/
├── apps/<pod>/{base,overlays/dev,overlays/prod}/
├── secrets/                      # ExternalSecret만
└── .github/workflows/{validate,promote}.yml
```

### 3. 웹·BFF·인증 흐름

1. 브라우저 → BFF `/api/auth/login` → Authentik Authorization Code + PKCE(`web-bff`, confidential).
2. 콜백에서 토큰 수신(aud=web-bff, `tenant_id`) → 암호화 refresh 쿠키(HttpOnly·Secure·SameSite=Lax) 설정, access는 isolate 캐시(5분).
3. API 호출 시 BFF는 identity-admin `/session/check`(2초 캐시)로 폐기 확인 → RFC 8693 교환(audience = 대상 pod) → `<pod>-api.joshuatech.dev` 호출 + `CF-Access-Client-Id/Secret`.
4. Cloudflare Access(Service Auth) → AOP mTLS → Traefik Ingress → pod: JWKS로 iss·aud·exp 검증 → Dragonfly 거부 목록 조회 → `tenant_id` → `SET LOCAL` → RLS.
5. 폐기: 로그아웃/관리자 폐기/Authentik 웹훅 → identity-admin → Authentik revoke + Dragonfly `revoked:{sub}` + Kafka `identity-admin.session.revoked`.

호스트: `joshuatech.dev`(웹) · `auth.`(Authentik) · `<pod>-api.` / `<pod>-apidev.` · `admin-<pod>.` · `argo.` `vault.` `kibana.`(SP-3) · `cdn.`(R2). 전부 proxied, Full(strict).

### 4. pod 템플릿·데이터·이벤트

- 템플릿 기본값: Python 3.13 · uv · Django 6.1 + Ninja 1.7 · Celery(Dragonfly) · pydantic-settings · structlog/OTel/Sentry · `/health`·`/ready` · testcontainers · Dockerfile(uv 빌드 → slim 런타임, arm64, 비루트) · kustomize base.
- 인증 미들웨어 순서: Bearer JWT → JWKS(iss·aud·exp) → Dragonfly 거부 목록 → `tenant_id` → 트랜잭션 + `SET LOCAL`.
- CNPG `pg-main`: DB per pod + owner/app role, dev `dev_` 접두, barman-cloud → `jt-backup`.
- Kafka(Strimzi): `KafkaNodePool` KRaft 1노드, `KafkaTopic`/`KafkaUser` CRD, 토픽 `<pod>.<entity>.<event>`, 파티션 3, 보존 7일, 파티션 키 `tenant_id`, DLQ `<pod>.dlq`.
- CloudEvents 예: `{"specversion":"1.0","id":"01J…","source":"identity-admin","type":"identity-admin.session.revoked","time":"…","subject":"<sub>","tenantid":"joshuatech","data":{"sub":"…","nbf":"…","reason":"logout"}}`.

### 5. CI/CD·환경·시크릿·관측

- 모노레포: `ci.yml`(PR·main) · `publish-pod.yml`(main → arm64 빌드 → digest → attestation → gitops dev bump) · `deploy-web.yml`(PR 프리뷰 / main deploy). gitops: `validate.yml`(required) · `promote.yml`(prod PR). 롤백 = revert / `wrangler rollback`. Renovate·SHA 핀·최소 permissions·PAT 없음.
- 환경: dev + prod 상시, 앱 pod만 복제, 플랫폼 공유(Authentik 별도 앱, `dev.` 토픽, `dev_` DB, Dragonfly dev, Vault `kv/dev`, OpenFGA store 2).
- 시크릿: Vault Raft(노드 A) + OCI KMS auto-unseal + K8s auth + ESO. 부트스트랩: OpenTofu(KMS·버킷) → Vault init(root 토큰 1회용·revoke) → 운영자가 초기 값 `vault kv put`(터널) → 이후 ESO. OpenTofu 상태는 `jt-tfstate`.
- 관측: Alloy → Grafana Cloud(메트릭·Loki·Tempo), Sentry(Django·web 클라이언트), `traceparent`·`x-request-id` 전파, 대시보드 3·알림 2.

### 6. 검증과 tasks 단계

① 문서(ADR·memory·rules·agents) → ② OpenTofu(OCI·Cloudflare) + v1 워크플로 비활성·재이미지 → ③ K3s·Argo·gitops·cert-manager/Traefik/AOP → ④ Vault·ESO → ⑤ CNPG·Strimzi·Dragonfly → ⑥ Authentik·OpenFGA·Access → ⑦ Alloy·Sentry·예산 알림 → ⑧ packages·템플릿·identity-admin → ⑨ 웹 hello·BFF·도메인 전환 → ⑩ RAM 보고·런북·report. 단계마다 tester E2E task 1개(헌법 II). 테스트 위치: `tests/`(하네스·kubeconform), `apps/*/tests/`, `packages/*/tests/`, `e2e/`(Playwright).

### 7. 리스크

| 리스크 | 징후 | 완화 |
|---|---|---|
| 노드 RAM 초과 | US7 실측 > 목표, OOMKill | Argo core 전환 · Alloy 축소 · dev quota 축소 · Redpanda 검토(ADR 0008 트리거) |
| PAYG 과금 확대 | 월 Compute > 3 SGD | 예산 알림 · 13 → 12 GB · 유료 자원 생성 금지 |
| OpenNext 번들 초과 | bundle-budget 실패 | 의존성 제거 → Workers Paid(ADR 0004, 사용자 승인) |
| Authentik OSS 교환 제약 | `act` 없음 | impersonation 교환 + Access 서비스 토큰 ID |
| Kafka 단일 노드 손실 | 디스크 장애 | outbox가 원천, 보존 7일, 멱등 소비 |
| Vault unseal 실패 | sealed | recovery 키 3/5 오프라인, ESO 마지막 Secret 유지 |
| 우회 직접 호출 | 오리진 IP 노출 | 보안 리스트 + AOP + pod의 Access JWT 검증 |
| Traefik v3 차트 breaking | 업그레이드 후 라우팅 실패 | HelmChartConfig 최소, 업그레이드 창 |
| 1인 운영 부담 | 패치 지연 | Renovate · 알림 2개 · 런북 6개 |

### 8. ADR 목록

| ADR | 결정 | 기각 대안 |
|---|---|---|
| 0002 deployment-principles | 불변 digest · Git 정본 · pull CD · CI 무자격증명 · PR 검증/main 발행 · rollback=revert · expand→contract | SSH push · :latest · 수동 배포 |
| 0003 runtime-track | 웹 Workers + API OCI K3s 2노드(A platform / B data) + Argo CD | Cloudflare-native · compose-pull · 전부 K3s |
| 0004 web-framework | Next.js 16.3 + OpenNext lean, 프리렌더 + BFF, 번들 예산, $5 탈출구 | Astro · SvelteKit · 정적 export + Hono |
| 0005 backend-framework-policy | Django 6.1 + Ninja 1.7 기본, FastAPI는 수치 트리거 예외 | FastAPI 단일 · Hono · Python Workers |
| 0006 identity-and-authz | Authentik 단일 IdP · provider별 aud · RFC 8693 · BFF 게이트웨이 · 세션 정본 Authentik + refresh 쿠키 · 즉시 폐기 이벤트 + 거부 목록 · OpenFGA 교차 컨텍스트 · Access 이중 | Better Auth · Clerk · 자체 세션 서비스 · introspection · 인클러스터 게이트웨이 |
| 0007 data-ownership-and-tenancy | CNPG 1 클러스터 · DB per pod · role 격리 · tenant_id + FORCE RLS + SET LOCAL | Neon · Supabase · D1 · 스키마 분리 · 앱 계층만 |
| 0008 event-backbone | Kafka KRaft(Strimzi) · 폴링 outbox 릴레이 · CloudEvents JSON + JSON Schema | Dragonfly Streams · Redpanda · Debezium · Avro |
| 0009 search | ES 1노드 + Kibana + Nori · ECK · FastAPI search pod(SP-3) | Postgres FTS · Pagefind · OpenSearch |
| 0010 secrets | HashiCorp Vault Raft + OCI KMS auto-unseal + ESO | Sealed Secrets · SOPS+age · OpenBao |
