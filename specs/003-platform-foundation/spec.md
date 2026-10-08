# Feature Specification: 플랫폼 기반 (SP-1)

**Feature Branch**: `003-platform-foundation`

**Created**: 2026-08-31

**Status**: Approved (2026-09-02)

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
| D12 | 인그레스 | egenauto 패턴: 번들 Traefik 공개 443 + cert-manager DNS-01 와일드카드 + Cloudflare proxied Full(strict), NSG로 Cloudflare IP 한정(80 미개방) + Authenticated Origin Pulls | 터널 전용 · 제한 없는 공개 |
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

**Independent Test**: `docs/decisions/0002-*.md` ~ `0010-*.md`가 MADR minimal 형식 검사(run-all)를 통과하고, `.specify/memory/product.md`·`architecture.md`가 존재하며, spec §8 ADR 표와 `docs/README.md`의 링크가 전부 유효한지 확인한다(`.claude/rules/*.md` 5개의 경로 스코프 로드 동작은 US9·SC-008에서 검증한다).

**Acceptance Scenarios**:

1. **Given** 이 spec의 D1–D20이 승인됨, **When** ADR 0002–0010을 작성하면, **Then** 각 ADR은 `status: accepted`, `date`, `decision-makers`, Context / Considered Options / Decision Outcome / Consequences 절을 갖고 기각 대안을 최소 2개 적으며, `docs/README.md`와 이 spec에서 링크된다.
2. **Given** ADR이 존재함, **When** `.specify/memory/product.md`(제품 목표·도메인·pod 목록·로드맵)와 `architecture.md`(토폴로지·경계·계약·운영 원칙)를 작성하면, **Then** 두 문서는 이 spec의 Design 절과 모순이 없고, `/speckit-archive-run`이 덮어쓰지 않는 파일(agent context 블록 밖)로 남는다.
3. **Given** ADR·memory가 존재함, **When** spec §8 ADR 표와 `docs/README.md`를 대조하면, **Then** 링크가 전부 유효하고 각 ADR의 결정 문구가 D1–D20과 일치한다. (rules·agents·boundary의 동작 검증은 US9)

---

### User Story 2 - 클러스터·GitOps·인그레스·시크릿 기반 (Priority: P1)

운영자는 OCI 인스턴스 2대 위에 K3s 2노드 클러스터가 서고, Argo CD가 `platform-gitops` 저장소를 정본으로 플랫폼을 동기화하며, 공개 트래픽은 Cloudflare를 반드시 거쳐 Traefik에 닿고, 시크릿은 Vault에서만 나오기를 원한다.

**Why this priority**: 다른 모든 스토리의 전제다. 이 스토리 없이는 데이터·신원·웹 왕복을 검증할 곳이 없다.

**Independent Test**: `kubectl get nodes`가 2 Ready, Argo CD root app이 Synced/Healthy, `https://argo.joshuatech.dev`가 Cloudflare Access 로그인 뒤에만 열리고 오리진 IP 직접 호출은 mTLS로 거부되며, `ExternalSecret` 1개가 Vault 값으로 `Secret`을 만든다.

**Acceptance Scenarios**:

1. **Given** OpenTofu가 VCN·보안 리스트·인스턴스 재이미지·버킷·KMS 키를 적용함, **When** 노드 A에 K3s server(`--secrets-encryption`, `role=platform`)·노드 B에 agent(`role=data`)를 부트스트랩하면, **Then** `kubectl get nodes`가 2 Ready를 보이고 노드 B는 인바운드 공개 포트가 없으며 노드 A는 NSG로 443만 Cloudflare IP 대역에 연다(80·22 닫힘).
2. **Given** 클러스터가 준비됨, **When** `bootstrap/root-app.yaml` 하나를 수동 apply하면, **Then** Argo CD가 AppProject 3개(platform·dev·prod)와 단일 sync-wave 표의 순서(CRD·namespaces·policies → cert-manager·ESO → Vault → CNPG operator → pg-main·Dragonfly·Kafka → Authentik·OpenFGA → Alloy·cloudflared·Reloader·Traefik 설정; 컴포넌트→wave 매핑 정본은 contracts/gitops-repo.md의 표 1개 — FR-010)로 플랫폼 Application 전부를 Healthy로 만들고 `default` 프로젝트는 소스·대상이 비어 있다.
3. **Given** cert-manager ClusterIssuer(LE, Cloudflare DNS-01)와 Traefik이 동작함, **When** `argo.joshuatech.dev`를 브라우저로 열면, **Then** Cloudflare Access(GitHub IdP) 로그인을 통과해야 UI가 보이고(후반의 Authentik OIDC 로그인 단계는 US4로 이월 — US2 E2E는 임시 admin으로 검증), 오리진 공인 IP로 직접 `curl`하면 Authenticated Origin Pulls 때문에 TLS 핸드셰이크가 거부된다.
4. **Given** Vault가 Raft 스토리지로 노드 A에서 실행되고 OCI KMS로 자동 unseal됨, **When** 노드 A를 재부팅하면, **Then** Vault가 사람 개입 없이 unsealed 상태로 돌아오고, ESO의 `ClusterSecretStore` 5개(FR-049)가 5분 안에 Ready가 되며 그다음 refresh(`refreshInterval` 5m)에서 `ExternalSecret`이 `SecretSynced`로 돌아온다.
5. **Given** 두 저장소가 public임, **When** CI가 실행되면, **Then** gitleaks가 required check로 두 저장소 모두 0건이고, gitops 저장소의 어떤 매니페스트에도 시크릿 값이 없다(ExternalSecret 참조만).

---

### User Story 3 - 데이터·이벤트 플랫폼 (Priority: P1)

운영자는 pod마다 독점하는 Postgres database와 role, 백업이 자동으로 Object Storage로 가는 CNPG 클러스터, Strimzi로 선언된 Kafka 토픽·사용자, 인증이 걸린 Dragonfly를 갖기를 원한다.

**Why this priority**: 청사진 불변식 "쓰기·마이그레이션 독점"과 "outbox 발행"이 여기서 물리적으로 강제된다. SP-2 pod는 이 계약 위에서만 만들어진다.

**Independent Test**: `identity_admin`·`dev_identity_admin`·`authentik`·`openfga` database와 DatabaseRole 6개(pod role 4개 `identity_admin_{owner,app}`·`dev_identity_admin_{owner,app}` + 공유 owner 2개 `authentik_owner`·`openfga_owner`)가 생성되고, 실접속 단언은 dev 방향만 — `dev_identity_admin_app`으로 `identity_admin`·`authentik` DB에 접속하면 거부되고 prod role 방향은 카탈로그 `SELECT has_database_privilege('identity_admin_app', '<db>', 'CONNECT')` = false(`<db>` = `dev_identity_admin`·`authentik`)로 검증하며, `KafkaTopic` 생성 후 produce/consume 왕복이 성공하고, barman-cloud 베이스 백업 1회가 `jt-backup` 버킷에 나타난다.

**Acceptance Scenarios**:

1. **Given** CNPG operator와 `pg-main`(instances=1, PG 18, 노드 B)이 Healthy, **When** gitops의 database/role 선언을 sync하면, **Then** SP-1 database 4개(`identity_admin`·`dev_identity_admin`·`authentik`·`openfga`)와 pod DB role 4개(`identity_admin_owner`·`identity_admin_app`·`dev_identity_admin_owner`·`dev_identity_admin_app`; owner는 `bypassrls: true`로 마이그레이션·시드 전용, app은 비소유·`NOBYPASSRLS`)가 생기고, 각 database의 migrate Job 첫 단계가 멱등 SQL(`REVOKE CONNECT ON DATABASE <db> FROM PUBLIC; GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner`)로 CONNECT를 제한하며(SP-1에는 다른 pod가 없으므로 대체 검증 — 실접속 단언은 dev 방향만: `dev_identity_admin_app`으로 `identity_admin`·`authentik` DB에 접속하면 `permission denied`이고, prod role 방향은 카탈로그 `SELECT has_database_privilege('identity_admin_app', '<db>', 'CONNECT')` = false(`<db>` = `dev_identity_admin`·`authentik`)로 검증한다 — 검증 Job은 dev 자격만 갖는다), 앱 세션은 `pg_stat_ssl`에서 ssl=true다.
2. **Given** `ScheduledBackup`이 선언됨, **When** 첫 스케줄이 실행되면, **Then** `jt-backup` 버킷에 베이스 백업과 WAL 아카이브가 생기고 `kubectl get backup`이 completed를 보인다.
3. **Given** Strimzi 오퍼레이터와 `KafkaNodePool`(KRaft combined 1노드, 노드 A)이 Ready, **When** `KafkaTopic identity-admin.session.revoked`와 `KafkaUser identity-admin`(SCRAM-SHA-512, 자기 토픽 write·구독 read ACL)을 sync하면, **Then** 그 사용자로 produce/consume 왕복이 5초 내 성공하고, 다른 pod의 사용자로 write하면 거부된다.
4. **Given** Dragonfly dev·prod 인스턴스가 `data` 네임스페이스에 있음, **When** 비밀번호 없이 접속하면, **Then** 거부되고, aclfile의 ACL 사용자(`admin`·`identity-admin`·템플릿 pod `<pod>`; dev에는 검사 계정 `sample-pod` 추가 — prod aclfile 미포함)로만 접속되며 dev 검사 계정 `sample-pod`로 `DEL revoked:sub:x`를 시도하면 NOPERM(거부 목록은 `%R~revoked:*` 읽기 전용)이고, `maxmemory` 768 MB와 5분 스냅샷 PVC가 설정되어 있다. aclfile이 `%R~` 키 패턴을 그대로 로드하는지는 VD-4 실측 결과에 따른다(기본 가정 = 로드됨; 로드 오류면 entrypoint `ACL SETUSER` 래퍼로 같은 권한을 만들되 이 단언은 그대로다).
5. **Given** dev 환경, **When** dev용 database·토픽·Dragonfly를 확인하면, **Then** database는 `dev_` 접두, DB role은 `dev_<pod_snake>_{owner,app}` 접두, 토픽은 `dev.` 접두, Dragonfly는 dev 인스턴스로 분리되어 prod 자원을 공유하지 않는다. SP-1에는 다른 pod가 없으므로 대체 검증으로 `dev_identity_admin_app`이 `identity_admin` DB에 접속하면 CONNECT가 거부되고(역방향 prod role은 AC1의 `has_database_privilege` 카탈로그 검증), dev `KafkaUser`로 prod 토픽에 write하면 거부되는 것을 확인한다.

---

### User Story 4 - 신원·인가 (Priority: P1)

방문자는 `auth.joshuatech.dev`에서 GitHub·Google·이메일로 로그인하고, 운영자는 그 로그인이 pod별 audience 토큰으로 교환되며, OpenFGA와 Cloudflare Access가 함께 경계를 이루기를 원한다.

**Why this priority**: 청사진의 핵심 불변식("발급자는 Authentik 하나", "자기 iss·aud만 검증")이 여기서 검증된다. 세션 정본과 즉시 폐기(D7)도 이 스토리의 일부다.

**Independent Test**: E2E 로컬 사용자 `e2e@joshuatech.dev` 로그인 성공(소셜 로그인은 AC1의 운영자 수동 검증) → `web-bff` 토큰 → `identity-admin` audience로 교환 → identity-admin이 자기 JWKS로 검증해 200. 로그아웃 후 1초 뒤 같은 access 토큰으로 호출하면 401.

**Acceptance Scenarios**:

1. **Given** Authentik이 `identity` 네임스페이스에서 Healthy이고 소셜(GitHub·Google)·이메일/비밀번호·MFA 단계가 구성됨, **When** 운영자가 브라우저로 `auth.joshuatech.dev`에서 GitHub로 1회 수동 로그인하면(스크린샷을 tester 보고에 첨부; GitHub 테스트 계정은 만들지 않음), **Then** 로그인이 성공하고 사용자 Sessions 화면에 세션이 보인다. tester는 Authentik 로컬 사용자 `e2e@joshuatech.dev`(비밀번호·TOTP 시드는 Vault `kv/platform/authentik/e2e`)로 같은 흐름을 자동 검증한다.
2. **Given** Application/Provider `web-bff`(confidential, token exchange grant)와 `identity-admin`(자기 issuer·JWKS, Federated Providers에 `web-bff`·`web-bff-dev` 허용)이 있음, **When** BFF가 RFC 8693 교환을 요청하면, **Then** `aud=identity-admin`·`tenant_id`(uuid) 클레임을 가진 5분 TTL access 토큰이 돌아오고, `portfolio-core` audience로는(SP-1에서 미허용) 거부된다. 호출자 식별 방식은 VD-1 실측 결과에 따른다 — 기본 가정은 impersonation 교환 + Access 서비스 토큰 `common_name`으로 호출자를 식별하는 모드(pod `AUTH_ACTOR_SUB` 미설정, `act` 클레임 미요구)이고, OSS에서 Actor 생성이 가능하다고 실측되면 delegation 모드(BFF가 자기 client-credentials 토큰을 `actor_token`으로 제시 → `act.sub` = prod `web-bff` / dev `web-bff-dev`)로 전환한다.
3. **Given** 사용자가 로그인 상태, **When** BFF의 `/api/auth/logout`을 호출하면, **Then** identity-admin이 Authentik refresh 토큰을 revoke하고 `SessionRevocationLog`(DB 정본)에 기록한 뒤 Dragonfly에 `revoked:sub:{sub}`(nbf epoch, TTL 330 s)를 쓰며 Kafka `identity-admin.session.revoked`를 발행하고, 1초 뒤 같은 access 토큰으로 identity-admin을 호출하면 401이다.
4. **Given** Authentik 관리자가 사용자 세션을 삭제함, **When** Authentik 웹훅(logout 이벤트)이 identity-admin에 도착하면, **Then** 3번과 같은 거부 목록 기록이 일어난다.
5. **Given** OpenFGA가 `identity` 네임스페이스에서 `pg-main`의 `openfga` DB로 동작함, **When** 초기 모델(`tenant#member`, object `tenant:<uuid>`)을 store에 쓰고 check API를 호출하면, **Then** 튜플 유무에 따라 allowed true/false가 돌아오고, 다른 테넌트 object에 대한 check는 false다.
6. **Given** `admin.joshuatech.dev`(Django admin)와 `identity-m2m-prod.joshuatech.dev`가 Cloudflare Access 뒤에 있음, **When** Access 헤더 없이 호출하면, **Then** Cloudflare가 403을 돌려주고, BFF의 서비스 토큰(Service Auth 정책)으로 호출하면 통과한다.

---

### User Story 5 - 웹 hello와 BFF 왕복 (Priority: P1)

방문자는 `joshuatech.dev`에서 ko·en·ja 페이지를 보고, 운영자는 `_next/static/*`가 Workers 정적 자산으로 무료로 나가며 프리렌더 페이지 GET과 BFF Route Handler가 Worker의 CPU 예산 안에서 실행되어 identity-admin까지 왕복하기를 원한다.

**Why this priority**: 웹 트랙(D4)의 성립 조건인 "서버 번들 예산"과 "페이지 GET의 Worker CPU 예산(프리렌더 HTML도 Worker를 거친다 — plan A1)"을 실측하는 유일한 방법이다. 콘텐츠 로더(D19)의 첫 실전 사용이기도 하다.

**Independent Test**: `https://joshuatech.dev/ko`·`/en`·`/ja`가 200이고 `content/study`의 학습 노트 목록(001·002)을 보여준다. `/api/health`가 identity-admin `/health`를 Access 서비스 토큰으로 호출해 200을 중계한다. CI의 bundle-budget이 gzip ≤ 2.5 MiB를 보고하고, Workers 대시보드에서 페이지 GET의 CPU p95 ≤ 10 ms를 확인한다.

**Acceptance Scenarios**:

1. **Given** `apps/web`(Next.js 16.3 + `@opennextjs/cloudflare`)이 `generateStaticParams`로 `[lang]` 페이지를 전부 프리렌더함, **When** main에 머지되어 `wrangler deploy`되면, **Then** `joshuatech.dev/{ko,en,ja}`가 200이고, 페이지 GET은 Worker의 캐시 가로채기(정적 자산 `cdn-cgi/_next_cache`)로 응답하되 CPU p95 ≤ 10 ms·Error 1102 0건이며, `_next/static/*`는 정적 자산 요청(무료)으로 집계된다. (OpenNext는 프리렌더 HTML도 Worker를 거친다 — plan A1)
2. **Given** `packages/content`가 `content/study/*.mdx`를 zod 스키마로 검증함, **When** hello 페이지를 빌드하면, **Then** 001·002 학습 노트의 제목·날짜·태그가 목록에 나오고, `draft: true`인 노트는 프로덕션 빌드에서 제외되며, 스키마에 맞지 않는 frontmatter(예: `pubDate` 누락)는 빌드를 실패시킨다.
3. **Given** BFF Route Handler `/api/health`가 있음, **When** 호출하면, **Then** BFF는 Access 서비스 토큰 헤더로 `identity-m2m-prod.joshuatech.dev/health`를 호출해 200을 중계하고 응답에 `x-request-id`를 남기며, 왕복 p95를 report에 기록한다.
4. **Given** PR이 열림, **When** `ci.yml`이 OpenNext 빌드를 하면, **Then** `scripts/bundle-budget.mjs`가 서버 번들 gzip 크기를 출력하고 2.5 MiB 초과 시 실패한다. 또한 `deploy-web.yml`이 운영자가 연 같은 repo PR에 한해 별도 Worker `joshuatech-web-preview`에 `wrangler deploy --env preview`로 배포해 `preview.joshuatech.dev`(Access GitHub IdP) URL을 PR 코멘트에 남긴다(fork PR은 프리뷰 미생성; prod Worker는 main `deploy`만).
5. **Given** i18n 라우트, **When** `/ja`에 번역이 없는 노트를 열면, **Then** ko 본문을 보여주고 "번역 없음" 표시를 붙인다.

---

### User Story 6 - Django pod 템플릿과 공통 라이브러리 (Priority: P1)

pod 구현자(SP-2의 서브에이전트)는 copier 템플릿 한 번으로 테넌트 격리·outbox·인증·관측·테스트가 갖춰진 pod를 만들고, 첫 커밋부터 테스트가 통과하기를 원한다.

**Why this priority**: SP-2 pod 4개가 같은 규율을 갖는 유일한 방법이다. 헌법 II(테스트 우선)·III(격리 키)·IV(관측)를 코드로 강제한다.

**Independent Test**: `copier copy templates/django-pod apps/sample-pod`로 생성한 pod가 `compose.dev.yml`에서 `pytest`를 통과한다 — RLS 0행(테넌트 범위 테이블), 등급 B 전역 테이블·owner bypass 케이스, outbox → Kafka 발행(테넌트 A·B 행 모두), 인증 미들웨어(JWKS + 거부 목록, 조회 실패 503), 헬스 3종(`/healthz`·`/ready`·`/health`), JSON 로그 필드, 생성물 securityContext·`automountServiceAccountToken: false` 단언.

**Acceptance Scenarios**:

1. **Given** `templates/django-pod`(Django 6.1 + Ninja 1.7, Python 3.13, uv, arm64 Dockerfile)와 `packages/django-common`이 있음, **When** 템플릿으로 pod를 생성하면, **Then** 생성물은 수정 없이 `uv sync` → `pytest`가 통과하고 Docker 이미지가 arm64로 빌드된다.
2. **Given** 템플릿의 테넌트 범위 모델(`TenantModel`, `tenant_id NOT NULL`)에 RLS 마이그레이션 헬퍼(FORCE RLS)가 적용됨, **When** app role로 tenant A의 트랜잭션(`SET LOCAL app.tenant_id`) 안에서 테넌트 범위 테이블에서 tenant B의 행을 조회하면, **Then** 0행이고, `SET LOCAL` 없이 조회하면 정책이 기본 거부해 0행이다. pod 전역(등급 B) 테이블(`outbox` 등)은 RLS 없이 app role이 전 테넌트 행을 읽고, owner role은 `bypassrls`로 마이그레이션·시드를 수행한다.
3. **Given** outbox 모델과 릴레이 command가 있음, **When** 도메인 쓰기와 outbox 삽입이 한 트랜잭션에서 커밋되면, **Then** 릴레이가 5초 내 CloudEvents JSON을 토픽에 발행하고(테넌트 A·B 행 모두, `tenantid`·파티션 키 = 각 행의 tenant uuid) 행을 삭제하며, 발행 실패 시 `attempts`를 올리고 행을 남기고, `max_attempts` 10 초과 시 `<pod>.dlq`로 보내며 `dead_at`을 기록한다.
4. **Given** 인증 미들웨어가 있음, **When** 유효한 JWT로 호출하되 Dragonfly에 `revoked:sub:{sub}`가 있으면, **Then** 401이고, iss·aud가 다르면 401이며, `AUTH_ACTOR_SUB`가 설정된 배포에서는 `act.sub`가 그 값과 다르면 401이고(미설정 = impersonation 모드로 `act`를 요구하지 않는다 — VD-1), Dragonfly 조회가 실패(0.2 s 타임아웃)하면 비헬스 경로는 503(fail-closed)이며, 유효하면 `tenant_id`가 요청 컨텍스트와 로그에 실린다.
5. **Given** structlog·OTel 설정이 있음, **When** 요청을 처리하면, **Then** JSON 로그에 `request_id`·`tenant_id`·`trace_id`가 있고 OTLP 트레이스가 Alloy로 전송된다.
6. **Given** `apps/identity-admin`이 이 템플릿으로 생성됨, **When** gitops `apps/identity-admin/overlays/{dev,prod}`를 sync하면, **Then** `identity-m2m-dev.`·`identity-m2m-prod.joshuatech.dev/health`가 200이고 ExternalSecret 2개(`identity-admin-env`·`identity-admin-migrate`)로 DB·Kafka·Dragonfly·Authentik 비밀이 주입되며 런타임 컨테이너 env에는 owner 자격이 없다.

---

### User Story 7 - 관측과 RAM 실측 (Priority: P2)

운영자는 노드·pod 메트릭과 로그가 Grafana Cloud에 도착하고, 노드별 실제 RAM 사용량이 보고되어 SP-3(ES·Kibana)의 자리가 남는지 알기를 원한다.

**Why this priority**: 헌법 IV의 이행이며, 설계의 RAM 추정(노드 A ≈ 8.3 GB, B ≈ 7.5 GB)을 확정하는 유일한 근거다. P1 스토리 뒤에 와야 측정 대상이 있다.

**Independent Test**: Grafana Cloud에서 `kube_node_status_allocatable_memory_bytes`와 identity-admin 로그가 조회되고, `report.md`에 노드별 10분 평균 RAM 표(3회)가 있으며 노드 A ≤ 9 GiB, 노드 B ≤ 8 GiB이다.

**Acceptance Scenarios**:

1. **Given** Alloy와 kube-state-metrics가 `monitoring` 네임스페이스에 있음, **When** Grafana Cloud를 열면, **Then** 대시보드 3개(노드 RAM 예산·pod 오류율·outbox/Kafka: outbox pending·oldest age + 브로커 under-replicated)가 데이터를 보이고, FR-040의 알림 규칙 13개(`NodeMemoryHigh`·`ArgoAppOutOfSync`·`ArgoAppUnhealthy`·`CnpgBackupStale`·`PlatformBackupStale`·`PvcUsageHigh`·`VaultSealed`·`CertExpiringSoon`·`QuotaNearLimit`·`NodeDiskLow`·`OutboxOldestPending`·`UpgradeJobFailed`·`MetricsAbsent`, 각각 `runbook_url` 포함; 표현식·임계·지속시간의 정의 정본은 plan §Observability 표)가 등록되어 있다. Grafana Cloud Free의 k8s-monitoring 차트 버전과 Viewer 서비스 계정의 사용자 수 소모 여부는 VD-7 실측 결과에 따른다(기본 가정 = 차트 4.5.0 핀, 서비스 계정은 사용자 3석을 소모하지 않음).
2. **Given** 플랫폼 전부(ES 제외)와 identity-admin dev·prod가 떠 있음, **When** `kubectl top nodes`를 10분 간격 3회 기록하면(출력 Mi → GiB 환산), **Then** 노드 A ≤ 9 GiB, 노드 B ≤ 8 GiB이고, 초과 시 report에 완화안(Argo core 전환·Alloy 축소·dev quota 축소·Redpanda 검토)을 적는다.
3. **Given** Sentry 프로젝트(identity-admin·web)가 있음, **When** identity-admin에서 의도적 예외를 발생시키면, **Then** Sentry에 이벤트가 `request_id` 태그와 함께 도착한다.
4. **Given** OCI Budgets, **When** 월 예산 35 SGD와 알림 규칙 4개(ACTUAL 10%·50%·100%, FORECAST 100%, FR-043)를 만들면, **Then** Cost Analysis에서 월 Compute 비용이 3 SGD 이하임을 report에 기록한다.

---

### User Story 8 - v1 정리와 도메인 전환 (Priority: P2)

운영자는 v1 인프라(OCI VM 2대·Render·Fly·Pages)를 정리하되 인스턴스는 재이미지로 유지하고, `joshuatech.dev`가 v2 Workers를 가리키기를 원한다.

**Why this priority**: 같은 인스턴스를 v2가 써야 하므로 US2보다 먼저 시작되지만, 사용자 결정(백업 없음)으로 작업량이 작아 P2다.

**Independent Test**: v1 저장소 워크플로 4개가 `workflow_dispatch`만 갖고, OCI 인스턴스 OCID 2개가 그대로이며 OS가 Ubuntu 24.04로 바뀌었고, `joshuatech.dev` apex가 Workers 응답을 준다. Render·Fly 서비스가 없다.

**Acceptance Scenarios**:

1. **Given** v1 저장소 `joshua92y/joshtech`의 워크플로 4개가 브랜치 필터 없이 prod에 push함, **When** 재이미지 전에 각 워크플로를 `on: workflow_dispatch`만 남기도록 바꾸면, **Then** 이후 어떤 push도 v1 VM에 배포하지 않는다.
2. **Given** 인스턴스 `joshtech_api_1st`·`joshtech_cache`(각 2 OCPU/13 GB), **When** OpenTofu가 부트 볼륨 교체(재이미지)를 적용하면, **Then** 두 인스턴스의 OCID·shape·메모리가 그대로이고 Ubuntu 24.04로 부팅하며, terminate는 일어나지 않는다.
3. **Given** Cloudflare Pages 프로젝트 `joshtech-frontend`가 apex를 소유함, **When** 커스텀 도메인을 해제하고 Workers 커스텀 도메인을 만들면, **Then** `joshuatech.dev`가 5분 내 v2 hello를 서빙하고, v1 전용 레코드 `api.`·`mainapi.`는 제거되며, `admin.`·`traefik.`은 v1 오리진에서 v2 노드 A(reserved IP)로 교체되고, `cdn.`은 R2 공개 버킷으로 유지된다.
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

- **노드 A 장애**: 컨트롤 플레인·Kafka·Authentik·Vault가 함께 내려간다. 정적 사이트는 Workers에서 계속 서빙되고 BFF는 503을 반환하며, 노드 B의 Postgres는 살아 있다. 복구는 재부팅 → Vault 자동 unseal → Argo 재동기화(런북 `incident-response`; cloudflared 터널까지 죽어 kubectl·SSH 경로가 없으면 `break-glass`). 단일 서버 K3s의 수용된 장애 도메인이며 report에 명시한다.
- **노드 B 장애**: CNPG 단일 인스턴스라 모든 pod가 NotReady(`/ready`는 DB만 본다)가 되고 Authentik·OpenFGA도 DB를 잃어 로그인·교환이 불가하다. 정적 사이트는 계속 서빙된다. 복구 = 재부팅 → PVC에서 CNPG 재기동; PVC 손실 → `restore-drill` PITR(`archive_timeout 300`으로 RPO ≤ 5분). 런북 `incident-response`.
- **Vault 자동 unseal 실패(OCI KMS 일시 장애)**: Vault는 KMS가 돌아올 때까지 sealed로 대기한다 — recovery key(3/2)는 generate-root·rekey 용도이지 unseal 수단이 아니다. ESO는 마지막 Secret을 유지해 기존 pod는 계속 돌고, 창 동안 pod 재시작을 금지하며, `VaultSealed` 알림이 간다. **KMS 키 삭제** = Raft 스냅샷 + 동일 키 없이는 복구 불능이므로 키에 `prevent_destroy`와 삭제 유예 30일을 두고, 스냅샷은 매일 `jt-backup-platform/vault/`에 둔다(FR-047, 런북 `vault-unseal`).
- **Dragonfly 거부 목록 유실**: 정상 종료·재시작에서는 종료 시 스냅샷(`terminationGracePeriodSeconds` 확보)과 5분 주기 스냅샷 PVC로 목록이 복원되므로 창이 없다. 유실 창은 **비정상 종료**(OOM·SIGKILL·스냅샷 저장 실패)에만 생기며, 그때 마지막 스냅샷 이후 기록이 비어 최대 access TTL(5분) 동안 폐기 전 토큰이 통과할 수 있다. identity-admin의 30 s Celery beat가 센티널 키 확인 없이 **무조건** `SessionRevocationLog(expires_at > now())`를 `SET … EX <remaining>`으로 재적용하고(멱등), 기동 시에도 같은 재적용을 하므로 실제 창은 최대 30 s로 좁혀진다(DB 재생; Kafka 재생 아님). `denylist:epoch` 센티널 키는 쓰지 않는다.
- **Authentik 웹훅 유실**: identity-admin이 받지 못한 세션 삭제는 access TTL 뒤에야 반영된다. 웹훅 재시도(Authentik 알림 전송 재시도)와 Celery beat `reconcile_authentik_sessions`(일 1회, 활성 세션 목록 API 대조)로 보정한다.
- **토큰 교환 거부**: Federated Providers에 호출자가 없거나 정책 바인딩 실패 시 BFF는 401을 반환하고 재로그인을 유도하며, 교환 실패율은 BFF JSON 로그(`exchange_result`)로 집계한다.
- **cert-manager 발급 실패·LE 레이트 리밋**: 와일드카드는 kube-system에 1장만 발급해 Traefik `TLSStore default`로 쓰므로 SAN 조합당 주 5회 제한은 그 1장에만 걸린다. `Certificate`를 삭제·재생성하지 않고, 실패 시 staging issuer로 진단하며, 만료는 `CertExpiringSoon`(< 21d) 알림으로 감지한다.
- **OpenNext 서버 번들 초과**: bundle-budget이 실패하면 의존성을 서버 번들에서 제거한다. 구조적 초과면 ADR 0004의 탈출구(Workers Paid $5)를 사용자 승인으로 발동한다.
- **Next 16.3 RSC prefetch 폭주(OpenNext #1334)**: cache interception 안의 버그로 라우터 prefetch가 무한 반복되면 Workers Free 100k/일이 즉시 소진된다. `e2e/hello.spec.ts`가 "로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10"을 가드하고, 재현 시 폴백은 16.3.4 유지 + `enableCacheInterception: false` 임시(수정 PR #1348 포함 패치 뒤 재활성, CPU p95는 두 구성 모두 실측)다. 보안 패치 라인 밖(16.2.x)으로의 다운그레이드는 금지한다(ADR 0004).
- **Workers Free 일 한도(100k 요청·10 ms CPU) 초과**: 페이지 GET도 Worker를 경유하므로(plan A1) 한도를 넘으면 **Worker 경유 요청이 429/1027로 실패**한다(정적 자산 요청은 한도 밖·무제한). 완화책은 VD-2 실측 결과에 따른다 — 기본 가정은 "Worker가 캐시보다 먼저 실행되어 Cache Rule이 효과 없음 → 미생성"이고, 실측(T093)에서 임시 Cache Rule(호스트 `joshuatech.dev`, 경로 `^/(ko|en|ja)(/|$)`, `jt_session` 쿠키 없음 → Cache Everything edge TTL 600)을 1회 apply해 `cf-cache-status: HIT`와 Workers 요청 수 불변이 확인되면 유지하며, 아니면 제거하고 프리렌더 HTML을 `.open-next/assets`(`/ko`·`/en`·`/ja`)로 자산화하는 방안을 같은 task에서 시험한다(RSC 프리페치 부작용은 E2E로 판정). `/api/auth/*`·`/if/flow/*`는 Rate Limiting rule(IP당 10초 60회 → 10초 차단; 표현식에 host 조건을 넣을 수 있는지는 VD-3)이 막는다. 알림 = Cloudflare Notifications "Workers usage" + `tests/platform` 주간 GraphQL 사용량 검사. 커스텀 도메인의 실제 초과 동작(1027 vs fail-open)은 VD-8로 관찰만 하고 의도적으로 초과시키지 않는다. 초과가 반복되면 Paid 검토.
- **Image Transformations 월 5,000 변환 초과**: 오류가 반환되므로 커스텀 loader가 원본 URL로 폴백한다. 사용량은 `tests/platform` 주간 GraphQL 검사로 감지한다.
- **ESO 동기화 실패(경로 오타·정책 누락·scope 불일치)**: Secret이 만들어지지 않아 pod가 시작되지 않는다. Argo Health가 Degraded를 보이고 `ArgoAppUnhealthy` 알림이 간다. 시크릿 경로는 gitops validate.yml이 정규식과 overlay↔scope 일치(`overlays/dev`는 `dev/`만, `overlays/prod`는 `prod/`만, `secrets/`는 `platform/`만, `secretStoreRef.name`이 overlay와 일치)로 검사한다.
- **dev 네임스페이스 quota 소진**: 새 pod가 Pending. 템플릿이 requests를 명시하고 LimitRange가 `defaultRequest.cpu`와 memory `default 512Mi`만 채우므로(CPU `default`·`max`는 두지 않아 "CPU limit 없음" 원칙이 유지된다) quota 계산이 예측 가능하고, `QuotaNearLimit`(90%) 알림으로 감지한다.
- **Kafka 디스크 포화**: 보존 7일·파티션 3으로 상한을 두고, `PvcUsageHigh`(80%) 알림. outbox가 원천이므로 유실은 지연으로만 나타나며 `OutboxOldestPending`(> 60 s)이 지연을 알린다.
- **Argo sync-wave 교착**: CRD가 늦게 생겨 Application이 Unknown이면 `SkipDryRunOnMissingResource`와 wave 순서로 해결하고, 실패 시 root app만 재동기화한다.
- **K3s 업그레이드로 Traefik 차트 변경**: HelmChartConfig(노드 A `server/manifests/traefik-config.yaml`)를 최소화하고 system-upgrade-controller 창(window)에서만 업그레이드하며, 업그레이드 직전 `platform-backup.sh --pre-upgrade`가 스냅샷을 남긴다(FR-048).
- **PAYG 무료분 초과 과금 증가**: 예산 35 SGD·알림 규칙 4개(FR-043)와 월 1회 Cost Analysis. 13 GB → 12 GB 축소는 재부팅 1회로 가능하다.
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

- **FR-004**: OpenTofu로 OCI(VCN·퍼블릭 서브넷·보안 리스트·인스턴스 2대 재이미지·Object Storage 버킷 3개 `jt-tfstate`·`jt-backup`·`jt-backup-platform`(전부 `NoPublicAccess`)·IAM 사용자 `svc-tfstate`(`jt-tfstate`만)·`svc-s3-backup`(`jt-backup`만)·동적 그룹 `jt-node-a`·KMS 키)와 Cloudflare(DNS 레코드·Access 앱/정책·Authenticated Origin Pulls·R2·Workers 커스텀 도메인 2개 `joshuatech.dev`·`preview.joshuatech.dev` — `www.joshuatech.dev`는 커스텀 도메인이 아니라 apex로의 301 redirect rule — ·Rate Limiting/WAF)를 선언해야 하며, 상태는 `jt-tfstate` S3 호환 백엔드에 두고 저장소에는 커밋하지 않는다.
- **FR-005**: 네트워크 보안 그룹(NSG)은 노드 A 443만 Cloudflare IPv4 대역에 열고(IPv6 미사용)(80은 열지 않음 — Always Use HTTPS는 edge에서, LE는 DNS-01) 22를 닫으며, 노드 B는 인바운드 공개 규칙이 없어야 한다. 클러스터 내부 규칙(K3s 6443·10250·51820/udp — 오버레이가 `flannel-backend: wireguard-native`이므로 VXLAN 8472가 아니라 WireGuard 포트다 — ·Postgres·Kafka)은 NSG 자기참조로만 연다.
- **FR-006**: 인스턴스 `joshtech_api_1st`·`joshtech_cache`는 재이미지(부트 볼륨 교체)로 재사용해야 하며 terminate해서는 안 된다. OpenTofu에 `prevent_destroy`를 둔다.
- **FR-007**: K3s v1.36.x를 노드 A server(`--secrets-encryption`, SQLite, 라벨 `role=platform`)·노드 B agent(`role=data`)로 설치하고, 번들 Traefik ServiceLB를 노드 A에만 바인드하며, local-path-provisioner를 사용해야 한다. kubectl 접근은 cloudflared 터널 + Access를 통해서만 한다.
- **FR-008**: StatefulSet(Kafka → A, CNPG·Dragonfly → B)은 `nodeSelector`로 고정하고, 앱 Deployment는 노드 A 선호 affinity를 가지며, CPU limit은 두지 않는다(템플릿 `deploy/base`와 Application에 명시). 노드 간 오버레이는 K3s `flannel-backend: wireguard-native`로 암호화한다.

**GitOps·인그레스·시크릿**

- **FR-009**: public 저장소 `platform-gitops`를 만들고 `bootstrap/`(Argo CD·root-app)·`clusters/oci-k3s/`(projects·app-of-apps)·`platform/*`·`apps/<pod>/{base,overlays/dev,overlays/prod}`·`secrets/`(ExternalSecret만)·`.github/workflows/{validate,promote}.yml` 구조를 가져야 한다.
- **FR-010**: Argo CD는 AppProject `platform`·`dev`·`prod`를 두고 `default`의 sourceRepos·destinations를 비우며, `dev`·`prod`에는 `namespaceResourceBlacklist`(NetworkPolicy·ResourceQuota·LimitRange·Role·RoleBinding·ServiceAccount)를 둔다. 플랫폼 Application은 **단일 sync-wave 표**(컴포넌트→wave 매핑 정본은 contracts/gitops-repo.md의 표 1개; 순서 = CRD·namespaces·policies → cert-manager·ESO → Vault → CNPG operator → pg-main·Dragonfly·Kafka → Authentik·OpenFGA → Alloy·cloudflared·Reloader·Traefik 설정이고, 디렉터리 목록에 `argocd`·`system-upgrade`·`cert-manager-issuers`·`cnpg-cluster`·`kafka-topics`를 포함한다)를 지키고 `ServerSideApply=true`, platform은 `Prune=confirm`·`Delete=confirm`이어야 한다. 상태 저장 CR(`Cluster pg-main`·`Kafka jt-kafka`·`KafkaNodePool`·Vault/Dragonfly PVC)과 모든 오퍼레이터 CRD에는 `argocd.argoproj.io/sync-options: Delete=false,Prune=false`를 단다. Argo CD 설치 `install.yaml`은 커밋 SHA(`?ref=<commit sha>`)로 핀하고 `platform/` 이미지는 `@sha256` digest를 병기한다(validate 경고). Traefik 정본은 노드 A `server/manifests/traefik-config.yaml`(HelmChartConfig)이고 `platform/traefik/`에는 Middleware·TLSOption·TLSStore만 둔다. Reloader는 차트 2.2.16(appVersion v1.4.21)으로 핀해 `platform/reloader/`에 선언하며, 감시 범위는 VD-9 실측 결과에 따른다(기본 가정 = scoped 모드 `watchGlobally: false` + 네임스페이스 목록으로 ClusterRole 없이 동작; 실패 시 `watchGlobally: true` + `namespaceSelector`로 되돌리고 ClusterRole이 남는 트레이드오프를 report에 기록).
- **FR-011**: cert-manager ClusterIssuer(LE staging·prod, Cloudflare DNS-01, 토큰은 ESO 경유)로 `joshuatech.dev` + `*.joshuatech.dev` 와일드카드를 **kube-system에 1장만** 발급해 Traefik `TLSStore default`의 기본 인증서로 쓰고(리허설·CI는 staging 발급자만, LE 동일 SAN 5회/7일 한도 보호), Traefik은 표준 `Ingress`(ingressClassName traefik, `router.tls: true`, base `PLACEHOLDER` 호스트 + overlay JSON6902 패치, `spec.tls` 생략)로 라우팅하며 HelmChartConfig(노드 A `server/manifests/traefik-config.yaml`, FR-010)로 JSON 액세스 로그(`accesslog.fields.headers.defaultMode drop`, 수집은 4xx/5xx만)·OTLP 트레이싱(`tracing.sampleRate 0.1`)·`forwardedHeaders.trustedIPs` = Cloudflare CIDR을 켜야 한다.
- **FR-012**: Cloudflare SSL은 Full(strict), Authenticated Origin Pulls를 존에 켜고 Traefik이 Cloudflare 오리진 CA를 클라이언트 인증서로 요구해야 한다. 오리진 IP 직접 호출은 실패해야 한다.
- **FR-013**: HashiCorp Vault를 `vault` 네임스페이스에 Raft 1 replica(노드 A PVC)로 설치하고 OCI KMS 키로 자동 unseal하며, Kubernetes auth method로 ESO를 인증해야 한다. Vault UI는 `vault.joshuatech.dev`에서 Access + Authentik OIDC 뒤에 둔다.
- **FR-014**: 모든 런타임 시크릿(DB·Kafka SCRAM·Authentik·OAuth client·Cloudflare 토큰·Access 서비스 토큰·R2·Sentry·Grafana Cloud)은 Vault `kv/{env}/{component}/…` 경로에서 ESO `ExternalSecret`으로만 주입되어야 한다(클러스터 밖 소비자인 Workers Secrets — BFF client secret·Access 서비스 토큰 secret·`SESSION_ENCRYPTION_KEY` — 는 Vault에서 `wrangler secret put`으로만 배포하고 pod에는 주지 않는다). ESO `refreshInterval`은 5m. 두 저장소는 gitleaks를 required check로 두고 0건이어야 한다.
- **FR-015**: 관리 접근(SSH·kubectl·Vault init)은 cloudflared 터널(2 replica, 노드별 anti-affinity, ns `cloudflared`) + Access(GitHub IdP)로만 하며, 공개 SSH 포트는 없어야 한다. 에이전트·tester는 SA `agent-view`(ClusterRole `view` 집계 + `agent-view-extra`)의 단기 토큰 kubeconfig만 받고(FR-044), **SP-1 CI에는 클러스터·OCI 자격을 주지 않는다**. admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만 둔다. 노드 SSH 키 `jt-ops`는 FIDO2 하드웨어 키이거나 passphrase + `ssh-add -c`(사용 시 확인 프롬프트)여야 하고, 세션 종료 시 `cloudflared access logout`을 실행하며 Access `ssh` 앱의 `session_duration`은 1h다. 터널까지 불가한 사고는 런북 `break-glass`(OpenTofu 변수로 운영자 IP 22 임시 개방 + 자동 제거, Argo admin 재활성, Vault `generate-root`)로 다룬다.

**데이터·이벤트**

- **FR-016**: CNPG operator(ns `cnpg-system`)와 클러스터 `pg-main`(instances=1, PostgreSQL 18 standard 이미지, 노드 B, PVC 40 Gi, `shared_buffers` 512 MB, 확장 pgvector — pg_bigm은 자체 확장 이미지가 필요해 SP-3 검색 feature로 이월)을 선언하고, SP-1 database 4개(`identity_admin`·`dev_identity_admin`·`authentik`·`openfga`; 나머지 pod DB는 각 pod feature가 추가)와 pod database마다 owner role·app role을, 공유 database에는 owner role만 gitops에서 선언해야 한다. role 이름은 database 이름을 따르고(`<db>_owner`·`<db>_app`), dev는 `dev_<pod_snake>_{owner,app}` 접두 규칙을 쓴다 — SP-1 DatabaseRole은 **6개**로, pod DB role 4개는 `identity_admin_owner`·`identity_admin_app`·`dev_identity_admin_owner`·`dev_identity_admin_app`이며, 공유 컴포넌트 `authentik`·`openfga`는 env 접두 없이 **owner만**(`authentik_owner`·`openfga_owner`, app role 없음)이다. owner role은 `bypassrls: true`(마이그레이션·시드 전용), app role은 테이블 비소유·`NOBYPASSRLS`이며 다른 database에 접근할 수 없어야 한다 — PG role은 클러스터 전역이고 CONNECT 제한은 CNPG CRD 밖이므로, pod database는 각 database의 migrate Job 첫 단계에서 멱등 SQL(`REVOKE CONNECT ON DATABASE <db> FROM PUBLIC; GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner`)로, migrate Job이 없는 공유 database(`authentik`·`openfga`)는 `platform/cnpg-databases/`의 PostSync SQL Job(자격 `kv/platform/db/{authentik,openfga}/owner`, store `vault-platform`, 멱등 `REVOKE CONNECT … FROM PUBLIC; GRANT CONNECT … TO <db>_owner`)으로 강제한다.
- **FR-017**: dev 환경은 `dev_` 접두 database와 `dev_<pod_snake>_{owner,app}` role을 쓰고, database 비밀번호는 Vault(pod DB는 `kv/{env}/db/<db>/{owner,app}`, 공유 컴포넌트는 `kv/platform/db/{authentik,openfga}/owner`) → ESO → CNPG `managed.roles.passwordSecret` 단방향으로 흐른다. pod는 `DATABASE_URL … ?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`로 접속하며, CA는 ESO kubernetes provider store `k8s-data-ca`(`remoteNamespace: data`)가 `pg-main-ca`·`jt-kafka-cluster-ca-cert`의 **`ca.crt` 키만**(`remoteRef.property: ca.crt`) `identity`·`jt-dev`·`jt-prod`에 미러한다 — 미러된 Secret에 `ca.key`가 있어서는 안 된다. pod의 ExternalSecret은 2개 — `<pod>-env`(app·kafka·dragonfly·authentik·OpenFGA store id·preshared key·sentry)와 `<pod>-migrate`(owner만, migrate Job 전용) — 이며 런타임 컨테이너 env에 owner 자격이 없어야 한다. PG app role은 `statement_timeout 15s`·`idle_in_transaction_session_timeout 30s`.
- **FR-018**: barman-cloud 플러그인으로 `jt-backup`(S3 호환, IAM 사용자 `svc-s3-backup`만, versioning, `NoPublicAccess`)에 매일 베이스 백업(`ScheduledBackup 0 0 17 * * *` = 02:00 KST) + 연속 WAL 아카이브(`archive_timeout 300`, 보존 30일)를 선언하고 첫 백업이 성공해야 한다. PITR은 클러스터 전체(재해 복구 전용)이며 단일 DB 복구는 side Cluster PITR → `pg_dump` → 복원이다(런북 `restore-drill`).
- **FR-019**: Strimzi 오퍼레이터와 `KafkaNodePool`(KRaft combined 1노드, 노드 A, 브로커 `-Xmx1g`, local-path PV)을 선언하고, `KafkaTopic`(파티션 3, 보존 7일)·`KafkaUser`(SCRAM-SHA-512, pod별, 자기 토픽 write·구독 토픽 read ACL)를 gitops에서 관리해야 한다. 토픽 이름은 `<pod>.<entity>.<event>`(prod)·`dev.<pod>.<entity>.<event>`(dev)이고, pod마다 `<pod>.dlq`(outbox `max_attempts` 초과분)를 둔다. 파티션 키는 `tenantid`(tenant uuid). 프로듀서 `delivery.timeout.ms`는 30000.
- **FR-020**: Dragonfly를 `data` 네임스페이스에 dev·prod 인스턴스로 두고 `--maxmemory=768mb`, PVC + 5분 스냅샷, `terminationGracePeriodSeconds` 명시(정상 종료 시 스냅샷 완료 보장)여야 한다. 인증은 ACL 파일(`--aclfile /etc/dragonfly/users.acl`, Secret ← ESO `kv/{env}/dragonfly/acl`; 사용자별 비밀번호 경로 `kv/{env}/dragonfly/<user>`)로 사용자마다 한다: `admin`(+@all), `identity-admin`(`~revoked:* ~identity-admin:* +@all`), 템플릿 pod `<pod>`(`%R~revoked:* ~<pod>:* +@all` — 거부 목록은 읽기 전용). dev aclfile에는 dev 전용 검사 계정 `sample-pod`(`%R~revoked:* ~sample-pod:* +@all`, 템플릿 `<pod>`와 동일 권한)를 추가하고 prod aclfile에는 넣지 않는다. aclfile이 `%R~` 키 패턴을 그대로 로드하는지는 VD-4 실측 결과에 따른다(기본 가정 = 로드됨 → aclfile에 그대로 기재; 로드 오류면 entrypoint `ACL SETUSER` 래퍼로 같은 권한을 만든다). 클라이언트 `socket_timeout`은 0.2 s.
- **FR-021**: `packages/events`에 CloudEvents 1.0 JSON Schema(2020-12)를 토픽별로 두고(`specversion·id(ULID)·source·type·time·subject·tenantid(tenant uuid)·data`), CI가 하위 호환(필드 삭제·타입 변경 금지)을 검사해야 한다. SP-1에서 최소 6개 토픽 스키마를 정의한다: `identity-admin.user.registered`·`identity-admin.tenant.created`·`identity-admin.session.revoked`·`portfolio-core.note.published`·`engagement.comment.created`·`media.object.ready`.

**신원·인가·세션**

- **FR-022**: Authentik을 `identity` 네임스페이스에 설치(server + worker, DB는 `pg-main`의 `authentik`, `AUTHENTIK_POSTGRESQL__SSLMODE=verify-full`·`AUTHENTIK_POSTGRESQL__SSLROOTCERT` 개별 env)하고 소셜(GitHub·Google; OAuth client 자격은 `kv/platform/authentik/sources/{github,google}`)·이메일/비밀번호·MFA(TOTP·passkey) 흐름을 구성해야 한다(enrollment 흐름은 없음 — SP-2). Application/Provider: `web-bff`(confidential, token exchange grant, redirect는 `https://joshuatech.dev/api/auth/callback`만)와 `web-bff-dev`(redirect `http://localhost:3000/api/auth/callback`·`https://preview.joshuatech.dev/api/auth/callback`, 대상 `identity-m2m-dev`), pod별 provider(자기 issuer·JWKS), 관리 앱(`argocd`·`vault`·Django admin forward-auth; `grafana`는 SP-2). Scope mapping `tenant_id`(uuid)의 원천은 `user.attributes.tenant_id`이며 그룹 `tenant:<uuid>`는 RBAC 용도다. 교환 토폴로지(Federated Providers)는 SP-1에서 `web-bff`·`web-bff-dev` → `identity-admin`만 허용하고 RFC 8693 교환을 쓴다 — 호출자 식별 방식은 VD-1 실측 결과에 따르며 provider 구성은 두 모드를 모두 지원해야 한다: 기본 가정 = impersonation 교환 + Access 서비스 토큰 `common_name`으로 호출자 식별(pod `AUTH_ACTOR_SUB` 미설정), 대안 = delegation(BFF가 자기 client-credentials 토큰을 `actor_token`으로 제시하고 pod가 `act.sub`를 `AUTH_ACTOR_SUB`와 대조). 두 모드 어느 쪽이든 Access 서비스 토큰은 네트워크 게이트로 유지한다. 흐름 스테이지 배치: identification 스테이지 `show_matched_user false`, password 스테이지 `failed_attempts_before_cancel 5`, Reputation 정책은 스테이지 바인딩으로 건다. 서비스 계정 `identity-admin`(권한: 사용자 read, `authentik_core.delete_authenticatedsession`, 토큰 revoke)의 토큰은 `kv/{env}/authentik/identity-admin`에, 웹훅 비밀은 pod별로 분리해 `kv/{env}/authentik/webhooks/<pod>`에 두며, 관리자 그룹 `platform-admin`은 WebAuthn 필수다. E2E 로컬 사용자 `e2e@joshuatech.dev`는 blueprint로 만들고 그 비밀번호·TOTP 시드는 `kv/platform/authentik/e2e`에 둔다.
- **FR-023**: 세션 정본은 Authentik이며, BFF는 암호화된 refresh 토큰을 HttpOnly·Secure·SameSite=Lax 쿠키(`jt_session`)로 보관하고 access 토큰(5분 TTL)을 isolate 캐시한다. BFF는 요청 처리 전 identity-admin `/session/check`(2초 캐시)로 폐기 여부를 확인한다. 남용 방지: Cloudflare Rate Limiting rule 1개(기본 표현식 = 경로 `/api/auth/*` + `/if/flow/*`, IP당 10초 60회 → 10초 차단; Free 플랜 표현식에 host 조건을 넣어 `joshuatech.dev/api/*`로 넓힐 수 있는지는 VD-3 실측 결과에 따른다)·WAF Cloudflare Free Managed Ruleset. Cache Rule은 **기본 = 미생성**이다(Worker가 캐시보다 먼저 실행되어 효과 없음 가정 — VD-2): 실측(T093)은 임시 Cache Rule(호스트 `joshuatech.dev`, 경로 `^/(ko|en|ja)(/|$)`, `jt_session` 쿠키 없음 → Cache Everything edge TTL 600)을 1회 apply해 `cf-cache-status: HIT`면 유지하고 아니면 제거한다. 캐시 위생을 위해 `app/[lang]` 프리렌더 응답에는 `Set-Cookie`를 두지 않는다. Authentik은 Reputation 정책(-5) + `failed_attempts_before_cancel 5` + `show_matched_user false`, enrollment 흐름 없음(SP-2).
- **FR-024**: 로그아웃·관리자 폐기·Authentik 세션 삭제(웹훅)는 identity-admin이 처리해 Authentik 토큰 revoke, `SessionRevocationLog`(DB 정본) 기록, Dragonfly 파생 캐시 기록(`revoked:sub:{sub}` = nbf epoch, TTL 330 s; `revoked:sid:{sid}` = 1, TTL 330 s), Kafka `identity-admin.session.revoked` 발행을 수행해야 한다. 30 s Celery beat는 센티널 키를 보지 않고 **무조건** `SessionRevocationLog(expires_at > now())`를 `SET … EX <remaining>`으로 재적용하며(멱등), 기동 시에도 같은 재적용을 한다 — `denylist:epoch` 센티널은 쓰지 않는다. Authentik revoke·reconcile 쓰기 호출은 **prod에서만** 실행한다 — dev는 설정 플래그로 비활성(로그만)이며, dev 로그아웃 검증은 denylist 401·로컬 세션 삭제까지로 한다. 키 계약은 contracts/denylist.md. 모든 pod의 인증 미들웨어는 JWT 검증 뒤 Dragonfly를 1회 조회해 거부해야 하고, 조회 실패(`socket_timeout` 0.2 s)는 비헬스 경로 503(RFC 9457 `type: …/denylist-unavailable`)으로 fail-closed한다.
- **FR-025**: OpenFGA를 `identity` 네임스페이스에 설치(DB `openfga`)하고, 모노레포 `packages/authz/model.fga`의 초기 모델(type `tenant`, 관계 `owner`·`member`이며 `owner`는 `member`에 포함된다 — `define member: [user] or owner`, object `tenant:<uuid>`)과 env별 store를 선언해야 한다. preshared key는 서버측 공유 컴포넌트 경로 `kv/platform/openfga/preshared`에 두고, pod에 주입하는 env 사본은 overlay↔scope 규칙 때문에 `kv/{env}/openfga/preshared`(store id 포함)로 `<pod>-env`에 넣는다. 튜플 쓰기는 관계를 정의하는 pod만 한다(SP-1에서는 identity-admin의 `tenant#owner`·`tenant#member` — 멤버십 정본 `TenantMembership`의 파생).
- **FR-026**: Cloudflare Access 정책: `<alias>-m2m-prod.*`·`<alias>-m2m-dev.*`는 Service Auth(BFF 서비스 토큰)만, `admin.`·`argo.`·`vault.`·`kibana.`(SP-3에서 생성)·Traefik 대시보드·`preview.`(PR 프리뷰 Worker)·Authentik 관리 UI(Access 앱 `auth-admin` = `auth.joshuatech.dev/if/admin/*`**만**)는 GitHub IdP 로그인 필수여야 한다. `/api/v3`는 flow executor와 user UI가 쓰므로 공개로 두고(`/application/o/*`·`/if/flow/*`·`/if/user/*`·`/.well-known/*`도 공개), 대신 보상 통제를 둔다: 관리자 그룹 `platform-admin` WebAuthn 필수·Authentik 서비스 계정 권한 한정(FR-022)·Reputation 정책·Rate Limiting(FR-023). 관리 API 접두만 선별 보호하는 방안은 SP-2에서 검토한다. 모든 Access 정책은 `session_duration`을 명시한다(`ssh` 앱은 1h). 서비스 토큰은 Vault(`kv/{env}/access/web-bff`)에 보관하되 secret은 Workers Secrets에만 배포하고, pod에는 AUD 2종 `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`(ConfigMap, 비밀 아님)만 준다. 1년 만료·회전은 런북 `secret-rotation`.

**웹·콘텐츠**

- **FR-027**: `apps/web`은 Next.js 16.3 App Router + `@opennextjs/cloudflare`로 빌드하며 모든 페이지를 `app/[lang]`(ko 기본·en·ja, 모든 로케일이 접두 경로 `/ko`·`/en`·`/ja`를 가지며 `/`는 `Accept-Language`에 맞는 로케일로 302, 없으면 `/ko`) 아래 `generateStaticParams`로 프리렌더하고, 서버 번들에는 BFF Route Handler(`GET /api/auth/login`·`GET /api/auth/callback`·`POST /api/auth/logout`·`POST /api/auth/refresh`, `GET /api/session`(identity-admin `/session/check` 프록시), `GET /api/health`, `/api/proxy/<pod>/<path>`)만 포함해야 한다. 프록시는 정적 맵(SP-1: `identity-admin` → `IDENTITY_M2M_URL`, 허용 경로 `/tenants/me`·`/session/check`)에 있는 대상만 중계하고 그 외는 404이며, 로그인 `returnTo`는 `/`로 시작하고 `//`로 시작하지 않는 상대 경로만 받는다. BFF → pod fetch는 3 s(AbortController) 타임아웃이고, 상류 타임아웃·연결 실패는 503 `upstream_unavailable`(RFC 9457)로 응답한다. wrangler 설정은 `run_worker_first`에 페이지 경로(`/ko`·`/en`·`/ja` 등)를 넣지 않고 `[cache]`는 비활성으로 유지한다(자산 요청 유료화 방지). `serverExternalPackages: ['jose']`는 OpenNext가 요구하므로 유지하고 그 근거를 설정 파일 주석에 남긴다. BFF 로그는 wrangler `observability`(enabled, `head_sampling_rate 1`) JSON(`request_id`·`upstream_ms`·`exchange_result`)이며 `Authorization`·`Cookie`·`CF-Access-*`·`code`·`state` 값은 기록하지 않는다. Sentry 서버 SDK·i18n 런타임·인증 라이브러리는 서버 번들에 넣지 않는다(JWT/JWE 프리미티브 `jose`는 허용).
- **FR-028**: `scripts/bundle-budget.mjs`가 서버 번들 gzip 크기를 측정해 2.5 MiB 초과 시 CI를 실패시켜야 하며, ADR 0004는 초과 시 탈출구(Workers Paid)를 명시한다.
- **FR-029**: `packages/content`는 `content/{study,blog,projects}`를 빌드 시 읽어 zod 스키마(`.claude/rules/content.md` 계약: title·description·pubDate·updatedDate·tags·series·seriesOrder·draft·change·sources)로 검증하고, 다국어 접미사(`<slug>.mdx`·`<slug>.en.mdx`·`<slug>.ja.mdx`)·draft 필터·1회 스캔 캐시·remark/rehype(헤딩 앵커·목차·읽기 시간·코드 하이라이트)를 제공해야 한다. 스키마 위반은 빌드 실패다.
- **FR-030**: 이미지는 저장소 자산은 빌드 시 변형, 업로드 자산은 R2 원본 + `next/image` 커스텀 loader가 `cdn.joshuatech.dev/cdn-cgi/image/…`(Cloudflare Image Transformations)를 쓰며 변환 오류 시 원본으로 폴백해야 한다.
- **FR-031**: 디자인 시스템은 라이브러리 없이 소스로 소유한다. SP-1은 토큰 3계층(primitive → semantic → component)의 뼈대와 hello 페이지에 필요한 컴포넌트만 만들고, Material Design 어휘·slot 반응형 레이아웃은 SP-2에서 확장한다. Once UI 소스는 복사하지 않는다.
- **FR-032**: `deploy-web.yml`은 PR 프리뷰를 별도 Worker `joshuatech-web-preview`(wrangler env `preview`, 커스텀 도메인 `preview.joshuatech.dev`, Access GitHub IdP, dev 시크릿 `web-bff-dev`·`identity-m2m-dev`·자체 `SESSION_ENCRYPTION_KEY`)에 `wrangler deploy --env preview`로 올리되, 프리뷰 job은 **운영자가 작성한 같은 repo PR에서만** 실행한다(`pull_request.user.login == joshua92y`; fork PR·타인 PR은 프리뷰 미생성). 프리뷰용 Cloudflare 토큰은 계정 단위 토큰이므로 IP 제한을 걸고 회전 매트릭스(런북 `secret-rotation`)에 등재한다. prod Worker는 main의 `deploy`만이며, 그 job은 GitHub Environment `production`(deployment branch = main만, 승인자 없음, 환경 시크릿 = prod `CLOUDFLARE_API_TOKEN`(Workers Scripts Edit, TTL·IP 제한)·`JT_CI_APP_PRIVATE_KEY`·`SENTRY_AUTH_TOKEN`)에 묶는다. public repo Free 플랜에서 Environment 보호 규칙이 기대대로 동작하는지는 VD-5 실측 결과에 따른다.

**pod 템플릿·공통 라이브러리**

- **FR-033**: `templates/django-pod`(copier)는 Django 6.1 + Django Ninja 1.7, Python 3.13, uv(`uv.lock`), 멀티스테이지 arm64 Dockerfile(비루트), Celery(Dragonfly 브로커)·beat, pydantic-settings(필수값 누락 시 부팅 실패, `env.example`은 키만; `DATABASE_URL`·`ALLOWED_HOSTS`·`ADMIN_HOST` 필수), 헬스 3종(`/healthz` liveness = 프로세스만, `/ready` readiness = DB만, `/health` 상세 = db·dragonfly·kafka_producer 상태 JSON, 항상 200), `compose.dev.yml`, gitops용 kustomize base(Deployment web+relay·migrate Job·Service·Ingress PLACEHOLDER·ExternalSecret 2개 `<pod>-env`/`<pod>-migrate`; liveness `/healthz`·readiness `/ready`·startupProbe(마이그레이션 직후 첫 DB 연결 대기, `failureThreshold 30` × `periodSeconds 5`), 전략 RollingUpdate maxSurge 1/maxUnavailable 0, requests 명시 web 256Mi·relay 96Mi·migrate 256Mi·celery 192Mi, CPU limit 없음, 노드 A 선호 affinity, `automountServiceAccountToken: false`, securityContext `runAsNonRoot`·`allowPrivilegeEscalation: false`·`capabilities.drop [ALL]`·`seccompProfile RuntimeDefault`·`readOnlyRootFilesystem: true` + `/tmp` emptyDir, `reloader.stakater.com/auto: "true"`, `pg-main-ca` 마운트, relay 컨테이너 `prometheus_client` 9464 + `k8s.grafana.com/scrape` + liveness = TCP 9464), 내장 테스트를 생성해야 한다.
- **FR-034**: `packages/django-common`은 다음을 제공해야 한다. (a) 테이블 등급 — **A 테넌트 범위**(`TenantModel` 상속, `tenant_id`(uuid) NOT NULL + `ENABLE/FORCE ROW LEVEL SECURITY` + 정책)와 **B pod 전역**(`GlobalModel`, RLS 미적용, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`); owner role은 `bypassrls: true`(마이그레이션·시드 전용), app role은 NOBYPASSRLS; 릴레이·웹훅·기동 재적용·`/tenants/me`는 app role로 B 등급 테이블만 읽는다; `check_rls` 헬퍼는 A 등급이 FORCE RLS인지와 B 등급이 허용 목록에 있는지 검사한다. (b) tenant 미들웨어(토큰 `tenant_id` → 요청 트랜잭션 안 `SET LOCAL app.tenant_id`). (c) outbox 모델 + 발행 헬퍼 `publish(topic, subject, data, *, tenant_id=None)`(인자가 없으면 요청 컨텍스트의 `tenant_id`를 쓰고, 컨텍스트도 인자도 없으면 `OutboxUsageError`를 던진다)·릴레이 command(`SELECT … WHERE dead_at IS NULL … FOR UPDATE SKIP LOCKED`, idempotent producer, 성공 시 삭제·실패 시 attempts, `max_attempts` 10 → `<pod>.dlq` 발행 + `dead_at` 기록, dead 행은 `dead_at + 30일` 뒤 purge; 지표 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`을 9464에 노출). (d) CloudEvents producer(Kafka `delivery.timeout.ms` 30000). (e) 인증 미들웨어(JWKS iss·aud·exp + 선택적 actor 검증 — `AUTH_ACTOR_SUB`가 설정된 배포에서만 `act.sub`를 그 값과 대조하고, 미설정이면 impersonation 모드로 `act`를 요구하지 않는다(VD-1) — + Dragonfly 거부 목록 1회 조회(`socket_timeout` 0.2 s, 실패 시 비헬스 경로 503 fail-closed) + Access JWT AUD 2종 `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`; 면제 = 헬스 3종·`/webhooks/authentik`(HMAC + 타임스탬프 ±5분 + 이벤트 pk 멱등)). (f) structlog JSON(`request_id`·`tenant_id`·`trace_id`; processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거)·OTel SDK(`OTEL_TRACES_SAMPLER=parentbased_traceidratio` 0.1)·Sentry 초기화(`send_default_pii=False`, `before_send`로 `Authorization`·`Cookie`·`CF-Access-*` 헤더 제거). (g) Authentik 호출 재시도(5 s × 3회 지수 백오프, 최대 5분, Celery).
- **FR-035**: 템플릿 내장 테스트는 RLS 0행(A 등급)·owner bypass·B 등급 전역 테이블 케이스, outbox 발행(테넌트 A·B 행 모두, DLQ 전이), 인증 미들웨어(폐기·iss·aud·선택적 `act.sub`(`AUTH_ACTOR_SUB` 설정/미설정 두 경우)·Dragonfly 실패 503·admin AUD; 웹훅 서명 케이스는 pod 고유라 FR-036으로 옮긴다), 헬스 3종, 로그 필드·마스킹, OpenAPI 스냅샷, `makemigrations --check` + `django-migration-linter`, 생성물 매니페스트 단언(securityContext·`automountServiceAccountToken: false`·Deployment envFrom에 `-migrate` 없음)을 포함하며 testcontainers(Postgres·Kafka)로 실행되어야 한다.
- **FR-036**: `apps/identity-admin`은 이 템플릿으로 생성해 헬스 3종(`/healthz`·`/ready`·`/health`), `POST /sessions/revoke`, `GET /session/check`, `GET /tenants/me`(app role, B 등급 테이블만), Authentik 웹훅 수신(`/webhooks/authentik`: HMAC + 타임스탬프 ±5분 + 이벤트 pk 멱등, JWT/Access 검증 면제; 테스트 케이스 = 서명 없음/틀림 401·재전송 200 no-op), `identity-admin.session.revoked` 발행, Celery beat 3종(거부 목록 무조건 재적용 30 s·`reconcile_authentik_sessions` 일 1회·`SessionRevocationLog` purge 일 1회), `seed_tenant --tenant-id <uuid>` command(SP-1 테넌트 UUID는 **고정 1개**로 dev·prod·blueprint·FGA가 모두 같은 값을 쓰며 재실행이 멱등이고, `TenantMembership` 2건 = 운영자 `owner` + `e2e@joshuatech.dev` `member`, Authentik `user.attributes.tenant_id`·그룹, FGA 튜플을 함께 쓴다)를 구현하고 gitops `apps/identity-admin/overlays/{dev,prod}`로 배포되어야 한다. 웹훅과 관리자 revoke의 `tenant_id`는 `TenantMembership`에서 `sub`로 조회하며, 없으면 400이다. m2m Ingress 경로는 `/api`·`/health`·`/session`·`/sessions`·`/tenants`만이다(`/healthz`·`/ready`는 kubelet 전용이라 외부에 노출하지 않고, `/webhooks/authentik`은 클러스터 안 Authentik이 svc DNS로만 호출한다). Django admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 장착한다(`ALLOWED_HOSTS` 필수값 = svc DNS·m2m 호스트·admin 호스트; dev overlay의 `ADMIN_HOST`는 **빈 값** = admin 비활성이며, 빈 값으로도 기동해야 한다). Access AUD 2종 `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`은 ConfigMap(비밀 아님). Authentik 호출은 서비스 계정 `identity-admin` 토큰으로 svc DNS(`http://authentik-server.identity.svc:9000`)를 쓴다. 테넌트 오케스트레이션·Blueprints 적용은 SP-2다.

**CI/CD·환경·운영**

- **FR-037**: 모노레포 워크플로: `ci.yml`(PR·main: lint·test·build·gitleaks·bundle-budget·events 호환성·kubeconform; 의존성 설치는 `pnpm install --frozen-lockfile --ignore-scripts`·`uv sync --locked`), `publish-pod.yml`(main, `paths` 필터, `ubuntu-24.04-arm` 네이티브 빌드, GHCR digest push, artifact attestation, GitHub App이 gitops에 브랜치 `bump/dev-<pod>-<sha7>` + PR을 만들고 `gh pr merge --auto --squash`로 required check `validate` 통과 뒤 자동 머지 — 직접 push 없음; 저장소 설정 "Allow auto-merge" 활성이 전제이고 public repo Free에서의 실제 동작은 VD-5 실측 결과에 따른다(불가로 판정되면 dev bump PR도 운영자 수동 머지로 대체)), `deploy-web.yml`(FR-032). 액션은 SHA 핀, `permissions` 최소, PAT 없음, Renovate `automerge: false`.
- **FR-038**: gitops 워크플로: `validate.yml`(kustomize build·helm template·kubeconform·시크릿 경로/scope 정규식(overlay↔`dev/`·`prod/`·`platform/` 일치)·`platform/policies` 네임스페이스 목록 = contracts/network-policy.md 표·`platform/` 이미지 digest 부재 경고·`jt-ci[bot]`이 연 PR은 `apps/*/overlays/dev/kustomization.yaml`의 `images[].digest` 줄만 바꿨는지 검사·렌더링 diff(`kustomize build` main vs PR) 코멘트(Argo 접근 불필요), required check), `promote.yml`(workflow_dispatch: dev digest → `gh attestation verify` 통과 뒤 prod PR, 실패 시 중단; 브랜치 + PR 생성까지만 하고 **prod 승격 PR은 사람이 머지한다** — auto-merge를 쓰지 않아야 D16의 prod 게이트가 남는다). ruleset은 main에 PR 필수·required check `validate`·0 approvals·`bypass_actors: []`(GitHub App도 bypass 없음).
- **FR-039**: 네임스페이스 `jt-dev`·`jt-prod`는 ResourceQuota(dev requests 2 Gi/limits 4 Gi/pods 20, prod 3 Gi/6 Gi/30)와 LimitRange(`defaultRequest.cpu` + memory `default 512Mi`만 두고 CPU `default`·`max`는 두지 않는다 — FR-008의 "CPU limit 없음"을 LimitRange가 무효화하지 않아야 한다)를 가지며(템플릿은 requests를 명시 — FR-033), PSA `restricted`를 강제한다(전 네임스페이스의 PSA 레벨·허용 매트릭스·정책 세트는 contracts/network-policy.md이며, PSA 레벨 변경은 상향·하향 모두 k8s-security 경계 리뷰 대상이다). dev Application은 auto-sync + selfHeal이고, gitops main은 dev·prod 모두 PR 머지로만 바뀐다(dev digest bump는 GitHub App의 브랜치 `bump/dev-<pod>-<sha7>` + PR + `gh pr merge --auto --squash`(VD-5), prod는 `promote.yml`이 만든 PR을 사람이 머지).
- **FR-040**: Alloy(+kube-state-metrics·node-exporter, 네임스페이스 `monitoring`)가 노드·pod 메트릭·컨테이너 로그·OTLP 트레이스를 Grafana Cloud로 보내야 한다. scrape 선언: cnpg·ESO·cert-manager·Vault(`telemetry` + `unauthenticated_metrics_access`)·Argo·Traefik·outbox relay(9464; 지표 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`)·`platform-backup` textfile(node-exporter textfile 디렉터리 `/var/lib/node_exporter/textfile_collector`, hostPath). 대시보드 3개(노드 RAM 예산·pod 오류율·outbox/Kafka: outbox pending·oldest age + 브로커 under-replicated; 컨슈머 lag은 SP-2 kafkaExporter)와 알림 규칙 13개(전부 `runbook_url` = `docs/runbooks/incident-response.md#<slug>`)를 선언한다 — 이름은 `NodeMemoryHigh`·`ArgoAppOutOfSync`·`ArgoAppUnhealthy`·`CnpgBackupStale`·`PlatformBackupStale`·`PvcUsageHigh`·`VaultSealed`·`CertExpiringSoon`·`QuotaNearLimit`·`NodeDiskLow`·`OutboxOldestPending`·`UpgradeJobFailed`·`MetricsAbsent`이고, 표현식·임계·지속시간의 **정의 정본은 plan §Observability 표 한 곳**이다(spec·tasks는 이름과 참조만 둔다). 13번째 `MetricsAbsent`는 지표가 사라져 다른 알림이 조용히 통과하는 것을 막는 `absent()` 6종(`outbox_oldest_pending_seconds`·`platform_backup_last_success_timestamp`·`vault_core_unsealed`·`cnpg_collector_last_available_backup_timestamp`·`certmanager_certificate_expiration_timestamp_seconds`·`argocd_app_info`), 각 30m이다. Grafana Cloud Free의 k8s-monitoring 차트 버전과 Viewer 서비스 계정이 사용자 3석을 소모하는지는 VD-7 실측 결과에 따른다(기본 가정 = 차트 4.5.0 핀, 서비스 계정은 사용자 수 미소모). 볼륨 가드: Alloy는 kafka·argo INFO 이하 drop, Traefik 액세스 로그는 4xx/5xx만, 트레이스 샘플링 0.1(Traefik `tracing.sampleRate`, pod `parentbased_traceidratio`), Vault audit(`file_path=stdout`)은 Loki로. 임계 근거: E2E(T096)가 단언하는 `grafanacloud_instance_active_series < 8000`과 최근 30일 로그+트레이스 수집량 < 40 GB는 Grafana Cloud Free 한도(활성 시리즈 10k·로그/트레이스 각 50 GB/월)의 80% 가드다. BFF(Workers) 로그는 FR-027. Sentry 프로젝트는 identity-admin·web(클라이언트만, replay `maskAllText`).
- **FR-041**: `docs/runbooks/`에 8종을 작성해야 한다: bootstrap(클러스터·root app·Vault init, K3s 번들 복원·복호화)·restore-drill(CNPG; PITR = 클러스터 전체·재해 복구 전용, 단일 DB 복구 = side Cluster PITR → `pg_dump` → 복원)·vault-unseal(KMS 일시 장애 대기, Raft 스냅샷 복원 — 동일 KMS 키 필요, 워크스테이션 CLI 사용: Vault 이미지에 `openssl`/`ps` 없음)·rollback(gitops revert·wrangler rollback·K3s 롤백 절차 = `INSTALL_K3S_VERSION` 핀 재설치 → `systemctl stop k3s` → 복호화한 번들에서 `server/db/state.db`(잔재 `-wal`·`-shm` 파일 제거)·`server/token`·`server/cred/`·`server/tls/` 복원 → `systemctl start k3s` → 노드 B 재조인. **SQLite 구성에서 `k3s server --cluster-reset`은 실행 금지**(embedded etcd 전용 명령이라 실행하면 etcd로 비가역 전환된다) — 이 금지 문구를 런북에 명시한다. 비가역 변경 표 포함)·ram-budget·incident-response(알림 → 런북 표, 노드 A/B 장애, LE·Kafka 디스크·Dragonfly)·break-glass(OpenTofu 변수로 22 임시 개방, Argo admin 재활성, Vault `generate-root`)·secret-rotation(access-token-rotation 대체; 시크릿 → Vault 경로 → 소비자 → 재적재 → 주기 매트릭스 + 캘린더).
- **FR-042**: v1 정리: v1 저장소 워크플로 4개를 `workflow_dispatch` 전용으로 바꾸는 시점에 v1 GitHub Secrets 전부를 삭제하고 Cloudflare v1 API 토큰·R2 토큰을 revoke하며, 재이미지 후 `host-prep.sh`가 `authorized_keys`를 운영자가 새로 만든 키 `jt-ops`로 교체한다(구 키 0; Phase 말미에는 잔여 확인만). `jt-ops`는 FIDO2(`ed25519-sk`) 또는 passphrase + `ssh-add -c`(사용마다 확인)로만 쓰고, 세션이 끝나면 `cloudflared access logout`을 실행하며(Access 앱 `ssh`의 `session_duration`은 1 h), v1 SSH 개인키는 새 키로의 전환을 확인한 뒤 파기한다. Pages 프로젝트에서 apex를 해제해 Workers 커스텀 도메인으로 옮기며, Render·Fly 잔재를 삭제하고, v1 전용 DNS 레코드 `api.`·`mainapi.`를 제거하며, v2가 재사용하는 `admin.`·`traefik.` 레코드는 OpenTofu import 후 노드 A로 교체한다. 백업·데이터 임포트는 하지 않는다(사용자 결정).
- **FR-043**: OCI Budgets에 월 예산 35 SGD(테넌시 루트)와 알림 규칙 4개(ACTUAL 10%·50%·100%, FORECAST 100%, 운영자 이메일)를 만들고, report에 월 Compute 비용(usage-api)과 노드별 RAM 실측 표를 기록해야 한다. 첫 청구서에서 A1 무료분이 1,500/9,000으로 판명되면(월 ≈ $30) D17을 재결정한다.
- **FR-044**: 모든 User Story는 tester 에이전트가 실행하는 E2E 시나리오 task를 가지며(헌법 II), 클러스터 검증은 cloudflared 터널(클라이언트는 **2026.5.1로 핀**, Access 앱 `k8s`에 tester 서비스 토큰 `tester-k8s`의 Service Auth 정책)을 통한 kubectl·argocd CLI로 하되 자격은 SA `agent-view`(ns `kube-system`) = ClusterRole `view` 집계 + ClusterRole `agent-view-extra`(전부 `get`·`list`·`watch`, **Secret 제외**: core `nodes`, `apiextensions.k8s.io customresourcedefinitions`, `argoproj.io applications`·`appprojects`, `postgresql.cnpg.io clusters`·`backups`·`scheduledbackups`·`databases`·`databaseroles`, `kafka.strimzi.io` 전체, `external-secrets.io` 전체) + Role `pods/portforward`(ns `vault`·`data`·`identity`)의 단기 토큰(`kubectl create token agent-view -n kube-system --duration=8h`) kubeconfig만 쓴다(admin kubeconfig `k3s.yaml`은 운영자 비밀번호 관리자에만; Secret get·exec 권한은 없고, Vault seal 상태는 `kubectl port-forward svc/vault 8200` + `GET /v1/sys/seal-status`로 본다). `psql`·`kcat`·`redis-cli`·`fga`처럼 **자격증명이 필요한 검사는 tester가 직접 실행하지 않는다** — gitops `platform/policies/tests/`의 Job 3종(`data-assert`·`kafka-assert`·`authz-assert`, **전부 ns `jt-dev`** — dev 자격은 `vault-dev` store에서만 나온다(계약 contracts/gitops-repo.md가 정본); **dev scope ExternalSecret만** `envFrom`, prod 자격 0)이 실행하고 tester는 `kubectl logs job/…`만 읽는다. m2m 호스트의 Service Auth 통과는 Access 서비스 토큰 `tester-m2m`(dev·prod m2m 앱의 Service Auth include)으로 하며, `tester-k8s`·`tester-m2m` 두 토큰은 `kv/platform/access/{tester-k8s,tester-m2m}`에 보관하고 회전 매트릭스(런북 `secret-rotation`)에 등재한다. 클라우드·SaaS 읽기 자격은 OCI 사용자 `svc-verify`(그룹 `jt-verify`: `jt-backup`·`jt-backup-platform`에 inspect/read objects + `read usage-reports`·`budgets`·`instance-family`, `manage` 권한 0, 접속은 `oci session authenticate` 세션 토큰 1 h) · Grafana Cloud Viewer 서비스 계정 토큰 · Sentry 읽기 전용 토큰 · Cloudflare `Analytics:Read` 토큰이며, 이 넷은 quickstart 사전 조건으로 운영자가 준비한다. `argocd --sso` 로그인 확인과 Authentik 관리 API 확인은 **운영자 수동 + 스크린샷**이다(비대화형 자동화 없음). 브라우저 검증은 Playwright로 Authentik 로컬 사용자 `e2e@joshuatech.dev`를 써서 수행하고, 그 비밀번호·TOTP 시드는 Vault role `e2e-reader`(bound `kube-system/agent-view`, 정책 = `kv/data/platform/authentik/e2e` read, `token_ttl` 1h)로 경로 `kv/platform/authentik/e2e`에서만 읽으며, storageState는 `e2e/.auth/`(gitignore, 실행 후 삭제)에 두고 trace는 `mask`한다. 소셜 로그인(US4 AC1)은 운영자가 브라우저로 1회 수동 검증하고 스크린샷을 tester 보고에 첨부한다. **SP-1의 CI(GitHub Actions)에는 클러스터·OCI 자격이 없다** — 클러스터 검사는 운영자·tester 세션에서만 실행한다. 운영자 개인 계정 자격은 어떤 환경변수·파일에도 넣지 않는다. 자격 정본은 contracts/hostnames-and-access.md.

**Phase 0 조사로 추가된 요구사항 (2026-09-01, plan Research-Driven Adjustments)**

- **FR-045**: NetworkPolicy 정본은 contracts/network-policy.md(네임스페이스 표 14개·PSA 레벨·허용 매트릭스)이며, 정책 세트는 5종이다: `default-deny`(ingress+egress, `kube-system` 제외 13 ns) · `allow-dns`(같은 13 ns) · `allow-same-namespace`(`argocd`·`data`·`cnpg-system`·`external-secrets`·`cert-manager`·`monitoring`·`identity` 7개) · `allow-kube-api`(egress → 노드 A private IP/32 6443; `argocd`·`vault`·`external-secrets`·`cert-manager`·`cnpg-system`·`data`·`monitoring`·`system-upgrade`·`reloader`·`cloudflared` 10개) · `allow-apiserver-webhook`(ingress ← 노드 A private IP/32; `cert-manager` 10250·`external-secrets` 10250·`cnpg-system` 9443·`vault` 8200(port-forward 도착 경로)). 인스턴스 프린시펄 보호 — `deny-imds`(egress `ipBlock 0.0.0.0/0 except [169.254.169.254/32]`)는 **`kube-system` 전용**이다(K3s 번들 컴포넌트라 default-deny를 걸지 않으므로 이 형태가 유효하다). NetworkPolicy는 allow-only 모델이므로 default-deny가 있는 나머지 13 ns에서는 별도의 `deny-*` 정책이 아무것도 막지 못한다 — 그 13 ns의 IMDS 차단은 **외부 egress 규칙마다** `ipBlock 0.0.0.0/0 except [169.254.169.254/32, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]` + `ports` 명시로 표현한다. IMDS(169.254.169.254/32:80)에 닿는 유일한 예외는 `vault` 네임스페이스 전용 `allow-imds`이고, KMS 443도 Vault pod만 나간다. `kube-system`은 `platform/policies/`의 선언 목록에 포함하되 라벨만 SSA로 패치한다. PSA 레벨 변경은 상향·하향 모두 k8s-security 경계 리뷰 대상이며, helm 차트(Vault·Authentik·OpenFGA·Reloader) values에는 securityContext 4항목(`runAsNonRoot`·`allowPrivilegeEscalation: false`·`capabilities.drop [ALL]`·`seccompProfile RuntimeDefault`)을 명시한다. 매트릭스의 포트는 차트 기본값 기준이며 values ↔ 정책 포트 일치는 gitops validate가 lint한다. 두 인스턴스의 IMDS v1을 비활성화해야 한다. 동적 그룹 `jt-node-a`는 노드 A OCID만 포함하며(노드 B는 동적 그룹에 없음) 정책은 `use keys where target.key.id = <키>`와 `jt-backup-platform` 쓰기(`OBJECT_CREATE`·`OBJECT_INSPECT`)만 허용한다.
- **FR-046**: 클러스터 내부 구성요소는 공개 호스트명(`*.joshuatech.dev`)으로 자기 자신이나 다른 내부 서비스를 호출해서는 안 되며(mTLS 강제로 실패), Service DNS(`<svc>.<ns>.svc`)를 써야 한다. 예외 1: 외부 경유가 불가피한 BFF → pod. 예외 2: **Argo CD·Vault의 OIDC discovery**(`auth.joshuatech.dev`의 `/.well-known/openid-configuration`, Cloudflare proxied, Access 없음) — 두 컴포넌트는 discovery 문서의 `issuer`와 자기 설정값이 문자열로 일치해야 하므로 공개 호스트명을 쓴다. pod의 JWKS 조회는 예외가 아니다 — `jwks_url`은 svc DNS(`http://authentik-server.identity.svc:9000/application/o/<pod>/jwks/`)를 쓰고 토큰의 `iss`만 공개 URL로 검증한다.
- **FR-047**: 플랫폼 백업 — 노드 A의 `platform-backup.sh`(systemd `platform-backup.timer`, 매일 02:30 KST)가 (a) K3s 번들 = SQLite 온라인 스냅샷(`.backup`) + `server/token` + `server/cred/` + `server/tls/`(복원 시 서버 인증서·SA 서명 키를 함께 되돌려야 노드 B가 재조인한다), (b) Vault Raft 스냅샷(`kubectl create token vault-backup -n vault` → `vault write auth/kubernetes/login role=vault-backup` → `vault operator raft snapshot save`; Vault 정책 `vault-backup` = `sys/storage/raft/snapshot` read)을 각각 `age -r <운영자 age 공개키>`로 암호화(`.tar.age`)한 뒤, 노드 A 인스턴스 프린시펄(동적 그룹 `jt-node-a`, `OBJECT_CREATE`·`OBJECT_INSPECT`만)로 `oci os object put --auth instance_principal`을 써 버킷 `jt-backup-platform`(`NoPublicAccess`, versioning, lifecycle = 현재 버전 30일 + `previous-object-versions` DELETE 60일)의 `k3s/`·`vault/` 접두에 올려야 한다. versioning 버킷에서는 삭제가 delete marker만 남기므로 이전 버전 만료 규칙이 없으면 스토리지가 계속 늘어난다 — 이 규칙에 `OBJECT_VERSION_DELETE` IAM 정책이 필요한지는 VD-6 실측 결과에 따른다(기본 가정 = 정책 추가 필요; 규칙 존재 자체는 apply 단언으로 확인하고 실제 만료는 첫 만료 시점에 관찰해 report에 기록한다). 보존은 K3s 7일·Vault 30일. age 개인키는 운영자 오프라인(recovery key와 같은 곳)에 두고 노드에는 공개키만 둔다. 평문 sqlite 오브젝트는 0이어야 하고, 성공 시 textfile 지표 `platform_backup_last_success_timestamp{component="k3s"|"vault"}`를 node-exporter textfile 디렉터리(`/var/lib/node_exporter/textfile_collector`, hostPath)에 갱신하며(알림 `PlatformBackupStale`), **무결성 검증**으로 최신 `.age` 2개를 복호화해 K3s는 `PRAGMA integrity_check`가 `ok`인지, Vault는 `vault operator raft snapshot inspect`가 스냅샷을 읽어내는지 확인하고 결과를 report에 남긴다. 복원 절차(복호화 포함)는 런북 `bootstrap`(K3s)·`vault-unseal`(Vault, 동일 KMS 키 필요)에 둔다. `--pre-upgrade`로 호출하면 system-upgrade-controller가 업그레이드 직전 같은 백업을 수행한다(FR-048).
- **FR-048**: 업그레이드 창 — system-upgrade-controller(ns `system-upgrade`) Plan(server·agent, 일요일 03:00–05:00 KST, 채널 v1.36)으로 K3s 패치를 자동화하되, Plan `prepare` 컨테이너가 `chroot /host /usr/local/bin/platform-backup.sh --pre-upgrade`를 먼저 실행하고, CNPG `ScheduledBackup`은 `0 0 17 * * *`(02:00 KST)로 창과 겹치지 않게 하며, 같은 창(일요일 03:00–05:00 KST)에 Grafana mute timing을 둔다. 업그레이드 Job 실패는 알림 `UpgradeJobFailed`로, 지표 자체가 사라져 알림이 조용히 통과하는 것은 `MetricsAbsent`의 `absent()` 6종(각 30m)으로 잡는다(둘 다 FR-040의 규칙 13에 포함; 정의 정본은 plan §Observability 표). K3s 롤백은 FR-041 `rollback` 런북의 절차(핀 재설치 → `systemctl stop k3s` → 번들에서 `server/db/state.db`·`server/token`·`server/cred/`·`server/tls/` 복원 → start → 노드 B 재조인, `--cluster-reset` 금지)를 따르며 계획 다운타임을 명시하고, `rollback`에는 비가역 변경 표(CNPG/Strimzi 오퍼레이터 다운그레이드·`metadataVersion`·PG major·Authentik 스키마·Django contract 단계 → 복구 경로·RPO/RTO)를 두며, 해당 파일을 바꾸는 PR은 템플릿 체크박스로 스냅샷 3종 확인을 요구한다. K3s 업그레이드로 번들 Traefik 차트가 바뀔 때 HelmChartConfig 값 스키마를 릴리스 노트로 확인하는 절차를 런북에 둔다. Argo CD·플랫폼 차트 업그레이드는 Renovate PR(`automerge: false`) + 유지보수 창에서만 머지한다.
- **FR-049**: Vault 접근 통제 — Kubernetes auth role마다 `audiences: [vault]`와 bound ServiceAccount/namespace를 지정하고 `token_ttl=1h`·`token_max_ttl=4h`(기본 32일 금지)를 두며, 소비자별 정책은 경로 read만으로 최소화하고 **미사용 role `identity-admin`은 삭제한다**. ESO의 Vault role은 **4개**(role 이름 = 인증에 쓰는 SA 이름, 전부 ns `external-secrets`): `eso-platform`(`kv/data/platform/*`·`kv/metadata/platform/*` read) · `eso-dev`(`kv/data/dev/*`·`kv/metadata/dev/*`) · `eso-prod`(`kv/data/prod/*`·`kv/metadata/prod/*`) · `eso-data`(**열거 경로만**, env 와일드카드 금지 — `kv/data/{dev,prod}/db/*`·`kv/data/{dev,prod}/kafka/*`·`kv/data/{dev,prod}/dragonfly/*`·`kv/data/{dev,prod}/openfga/*`·`kv/data/{dev,prod}/authentik/webhooks/*` + 같은 `kv/metadata/…` read). `ClusterSecretStore`는 **5개**(apiVersion `external-secrets.io/v1`, `auth.kubernetes.serviceAccountRef`에 `namespace` 필수): `vault-platform`(`conditions.namespaces` = `jt-dev`·`jt-prod`를 뺀 플랫폼 ns 12개, `kube-system` 포함 / SA `eso-platform`) · `vault-dev`(`jt-dev` / `eso-dev`) · `vault-prod`(`jt-prod` / `eso-prod`) · `vault-data`(`data`·`identity` / `eso-data`) · `k8s-data-ca`(**kubernetes provider** — Vault를 거치지 않는 CA 미러, `remoteNamespace: data`, SA `eso-ca-reader`, Role(ns `data`) `secrets get/list/watch` `resourceNames [pg-main-ca, jt-kafka-cluster-ca-cert]` + `selfsubjectrulesreviews create`, `conditions.namespaces` = `identity`·`jt-dev`·`jt-prod`; ExternalSecret은 `remoteRef.property: ca.crt`만 쓰고 `dataFrom`을 쓰지 않는다 — CNPG `<cluster>-ca`에는 `ca.key`가 함께 들어 있어 미러된 Secret에 그것이 있으면 실패다). `data`·`identity`에는 `vault-platform`과 `vault-data`가 둘 다 걸린다(환경 무관 공유 비밀은 `platform/` 접두, env 스코프 비밀은 위 열거 접두). 어느 store도 `kv/{env}/*` 전체를 열지 않는다. validate는 `overlays/dev`의 ExternalSecret이 `dev/`만 + `secretStoreRef.name: vault-dev`, `overlays/prod`가 `prod/`만 + `vault-prod`, `secrets/`가 `platform/`만 + `vault-platform`을 참조하는지, `platform/{cnpg-databases,kafka-topics,dragonfly,authentik,openfga}/**`가 `vault-data`(열거 접두 안) 또는 `vault-platform`(`platform/` 접두)만 쓰는지, `k8s-data-ca` 참조가 `remoteRef.key ∈ {pg-main-ca, jt-kafka-cluster-ca-cert}` + `property: ca.crt`뿐인지 검사한다. 백업 role `vault-backup`(정책 `sys/storage/raft/snapshot` read; 수동 확인 `kubectl create token vault-backup -n vault --audience vault --duration=10m`)과 tester용 `e2e-reader`(FR-044)도 같은 audience·TTL 규칙을 따른다. 경로·store 정본은 contracts/gitops-repo.md. 부트스트랩 후 root 토큰을 폐기하고 recovery key(3/2 — generate-root·rekey 용도, unseal 수단이 아님)는 오프라인 보관한다. audit device(`file`, `file_path=stdout`)를 켜 Loki로 보낸다. Vault 내부 설정(auth·policy·role·OIDC)은 OpenTofu `hashicorp/vault` provider로 코드화한다.

### Key Entities

헌법 III에 따라 데이터 소유 엔티티마다 소유자와 격리 키를 적는다(SP-1 엔티티 **14개** — plan Constitution Check III와 같은 수). SP-1은 단일 테넌트(`joshuatech`)를 시드하지만 모든 계약은 `tenant_id`(UUID)를 가진다. DB 테이블은 등급 A(테넌트 범위, `TenantModel` + FORCE RLS)와 등급 B(pod 전역, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log` — FR-034)로 나뉜다.

- **Tenant**: 소유 identity-admin(DB `identity_admin`, 등급 B 테이블 `tenant`). 식별자는 UUID(`tenant_id`, 격리 키 자기 자신); slug는 `Tenant.slug` 컬럼에만 둔다. SP-1은 `joshuatech` 1건 시드. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`·OpenFGA object `tenant:<uuid>`는 identity-admin이 갱신하는 파생이다(SP-1은 `seed_tenant`가 셋 다 씀).
- **TenantMembership**: 소유 identity-admin(등급 B 테이블 `tenant_membership`). 키 `sub` + `tenant_id`. 테넌트 멤버십의 정본이며 Authentik 그룹·attribute·FGA 튜플은 여기서 파생된다. SP-1 가정: 사용자당 테넌트 1(다테넌트 선택은 SP-2). Authentik `sub`는 참조만.
- **SessionRevocationLog**: 소유 identity-admin(등급 B 테이블 `session_revocation_log`). `sub` 단위 pod 전역이며 폐기의 DB 정본(기동·30 s beat 재적용의 원천). 보존 `expires_at` + 30일 뒤 purge(Celery beat 일 1회).
- **SessionRevocation**: 소유 identity-admin. **정본은 DB 로그 `SessionRevocationLog`이고 Dragonfly는 그 파생 캐시**다 — `revoked:sub:{sub}` = nbf epoch(TTL 330 s), `revoked:sid:{sid}` = 1(TTL 330 s). 센티널 키 `denylist:epoch`는 **쓰지 않는다**(폐지 — 30 s beat가 조건 없이 재적용한다). 사용자 단위 레코드이지만 `tenant_id`는 `TenantMembership`에서 `sub`로 조회해 DB 로그에 남기고 CloudEvents 봉투(`tenantid`)에도 싣는다. 이벤트 `identity-admin.session.revoked`. 키 계약은 contracts/denylist.md.
- **OutboxEvent**: 소유 각 pod(자기 DB의 등급 B 테이블 `outbox`; 릴레이는 app role로 전 테넌트 행을 읽는다). 격리 키 `tenant_id`(UUID; Kafka 파티션 키 `tenantid`). 필드 id(ULID)·topic·key·payload(CloudEvents)·created_at·attempts·dead_at(`max_attempts` 10 초과 시 `<pod>.dlq`).
- **EventSchema**: 소유 모노레포 `packages/events`(전역, 테넌트 무관). 토픽별 JSON Schema와 버전.
- **KafkaTopic / KafkaUser**: 소유 platform-gitops(전역 플랫폼 자원). 토픽은 pod 접두로 소유 pod가 정해지고, dev는 `dev.` 접두로 분리.
- **Database / Role**: 소유 platform-gitops(CNPG 선언). pod당 database 1개 + owner role(`bypassrls: true`, 마이그레이션·시드 전용)/app role(NOBYPASSRLS). SP-1은 `identity_admin`·`dev_identity_admin`·`authentik`·`openfga` 4개, 나머지는 각 pod feature가 추가. dev는 `dev_` 접두. 테넌트 격리는 database 안의 RLS(등급 A 테이블).
- **SecretPath**: 소유 운영자(Vault `kv/{env}/{component}/…`). 전역·env 분리(ESO scope `platform`·`dev`·`prod`). 저장소에는 경로만. Workers 전용 경로(`kv/{env}/access/web-bff` 등)는 Workers Secrets로만 배포.
- **AuthentikObject**(Application·Provider·Scope mapping·Federated Providers·Brand): 소유 identity(Blueprints 파일은 gitops `platform/authentik/blueprints/`). 테넌트별 Brand는 SP-4.
- **FgaModel / FgaStore**: 소유 identity(모델 파일은 모노레포 `packages/authz/model.fga`), store는 env별. 튜플 소유는 관계를 정의하는 pod.
- **ContentItem**(학습 노트·글·프로젝트): 소유 git(`content/**`, 전역 — 소유자 테넌트의 콘텐츠). frontmatter 계약은 `rules/content.md`. DB 메타·반응은 SP-2 portfolio-core가 slug로 연결하며 그때 `tenant_id`를 붙인다.
- **ADR**: 소유 `docs/decisions/`(전역 문서). 번호 재사용 금지, 상태 accepted/superseded.
- **RamReport**: 소유 `specs/003-platform-foundation/report.md`. 노드별 10분 평균 3회, 구성요소별 requests/실측.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 노드 2개 Ready, root app 하나의 수동 apply 뒤 30분 안에 플랫폼 Application 전부(ES 제외)가 Synced/Healthy(US2 E2E가 root app apply 시각과 전부 Healthy 시각을 기록).
- **SC-002**: 브라우저 E2E — E2E 로컬 사용자 로그인(소셜 로그인은 US4 AC1 운영자 수동) → BFF 세션 → `/api/health` → identity-admin 200이 dev·prod 양쪽에서 통과한다. dev 체인 = 로컬 `next dev`(`web-bff-dev` provider, `localhost:3000` redirect) → `identity-m2m-dev`; prod 체인 = `joshuatech.dev` Worker → `identity-m2m-prod`. BFF → pod 왕복 p95 ≤ 300 ms(Cloudflare 서울 엣지 ↔ 춘천, report에 실측값 기록).
- **SC-003**: 로그아웃(또는 Authentik 세션 삭제) 뒤 2초 안에 같은 access 토큰으로의 호출이 401.
- **SC-004**: 템플릿으로 생성한 pod의 내장 테스트 100% 통과, RLS 0행 테스트와 outbox → Kafka 발행(5초 내) 포함; tester가 재현.
- **SC-005**: 부하 없는 정상 상태 10분 평균으로 노드 A ≤ 9 GiB, 노드 B ≤ 8 GiB 사용(3회 측정, report 표). 측정 조건: 플랫폼 전부(ES 제외) + identity-admin dev·prod 기동, 배포·백업 잡 없음, `kubectl top nodes` 10분 평균 × 3회(출력 단위가 Mi이므로 GiB로 환산해 기록), 노드별 `kube_pod_container_resource_requests` 합계 열 병기.
- **SC-006**: 두 저장소 gitleaks 0건, gitops 매니페스트에 시크릿 값 0개(ExternalSecret 참조만).
- **SC-007**: 웹 서버 번들 gzip ≤ 2.5 MiB; `joshuatech.dev/{ko,en,ja}` GET의 Worker CPU p95 ≤ 10 ms(Error 1102 0건)이고 일 Worker 요청 수를 report에 기록(Free 한도 100k/일 대비); `_next/static/*`는 정적 자산 요청(무료)으로 집계; 학습 노트 2편이 목록에 표시. 프리렌더 HTML을 정적 자산으로 복사해 Worker를 우회하는 실험은 선택 task(효과·RSC 강등 부작용을 E2E로 판정).
- **SC-008**: ADR 9개가 run-all MADR 검사를 통과하고 `docs/README.md`·spec에서 링크됨; `.claude/rules` 5개가 경로 스코프로 로드됨; `/approval-review` 경계 6개.
- **SC-009**: 8월 이후 첫 청구월의 OCI Compute 비용 ≤ 3 SGD, 예산 35 SGD·알림 규칙 4개(ACTUAL 10%·50%·100%, FORECAST 100%) 등록.
- **SC-010**: dev 자동 digest bump → Argo sync ≤ 5분; `promote.yml` PR 머지 → prod sync ≤ 5분; `git revert` 롤백 ≤ 5분(각 1회 실연).
- **SC-011**: CNPG 베이스 백업 1회 + WAL 아카이브가 `jt-backup`에, `.age` K3s·Vault 스냅샷이 `jt-backup-platform`에 존재하고 `restore-drill` 런북이 작성됨(PITR = 클러스터 전체·재해 복구 전용, 단일 DB 복구 절차 포함; 실연은 SP-3 — report에 수용 위험으로 명시).
- **SC-012**: v1: 워크플로 4개 `workflow_dispatch` 전용, 인스턴스 OCID 2개 불변, `joshuatech.dev` → Workers, Render·Fly 0개.

## Assumptions

- OCI 테넌시는 PAYG(2026-08-28 CLI 확인: `plan-type PAYG`, `UPGRADED`, SGD)이며 유료 테넌시의 A1 무료분은 가격표 기준 월 3,000 OCPU-h / 18,000 GB-h로 가정한다(Oracle 문서는 계정 유형별 무료분을 명시하지 않음). 첫 청구서로 재확인하고, 어긋나면 D17을 재검토한다.
- 인스턴스 2대(각 2 OCPU/13 GB, 2025-05 생성)는 재이미지 후에도 같은 shape로 유지된다. 춘천 리전은 Always Free A1 불가 리전이므로 Always Free 축소 시나리오는 고려하지 않는다.
- `joshuatech.dev` 존은 Cloudflare Free 플랜에 활성 상태이고, Workers Free·Zero Trust Free(50석)·R2 Free·Image Transformations Free(월 5,000 변환) 한도는 2026-08-27 조사값이다. 한도 변경 시 ADR 0004·0006에 기록한다.
- Authentik 2026.8 OSS는 RFC 8693 token exchange를 제공하고 delegation(`actor_token` → `act` 클레임)도 Enterprise 표시 없이 문서화되어 있다. 다만 `actor_token`은 authentik `Actor`를 가리켜야 하는데 OSS에는 `Actor`를 만드는 지원 경로가 없다(운영 경로는 Enterprise `Agent`). 따라서 **SP-1의 기본 가정은 impersonation 교환 + Cloudflare Access 서비스 토큰의 `common_name`(ConfigMap `ACCESS_EXPECTED_CN`)으로 호출자를 식별하는 모드**다. pod의 `AUTH_ACTOR_SUB`는 **선택값**이며 설정된 배포에서만 `act.sub`를 그 값과 대조한다(미설정 = impersonation, `act` 미요구). `audience`를 지정하지 않고 교환하면 발급 토큰의 `azp`로도 호출자를 판별할 수 있으나 `audience` 지정과 양립하지 않으므로 대안으로만 기록한다. delegation 채택 여부는 **T081 착수 시 실측으로 결정한다(VD-1)**. Access 서비스 토큰은 어느 모드에서도 네트워크 게이트로 유지하며, 두 경로와 Enterprise 조건부 경로(`Agent`는 parent user에 묶이므로 전 사용자 대행에는 parentless `Actor`가 필요)는 ADR 0006에 기록한다.
- Strimzi는 KRaft combined 단일 노드 `KafkaNodePool`을 지원하고, 오퍼레이터 + Entity Operator RAM은 0.6 GiB 안팎으로 추정한다(plan A14: Cluster Operator 384Mi + Entity Operator 256Mi; 실측 US7).
- 개발기는 Windows 11 + WSL(OpenNext는 Windows 완전 지원 비보장). 서브에이전트·tester는 cloudflared 터널(클라이언트 2026.5.1 핀)로 클러스터에 접근하되, 자격은 SA `agent-view`(ns `kube-system`; ClusterRole `view` 집계 + ClusterRole `agent-view-extra` + Role `pods/portforward`(`vault`·`data`·`identity`))의 단기 토큰(`kubectl create token agent-view -n kube-system --duration=8h`) kubeconfig만이다(Secret get·exec 없음). `psql`·`kcat`·`redis-cli`·`fga`처럼 자격증명이 필요한 검사는 gitops `platform/policies/tests/`의 Job 3종이 대신 실행하고 tester는 로그만 읽는다. OCI 읽기는 사용자 `svc-verify`(그룹 `jt-verify`, `oci session authenticate` 1 h)만 쓰며 **SP-1의 CI(GitHub Actions)에는 클러스터·OCI 자격이 없다**. admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만 있고, Vault seal 상태는 `kubectl port-forward svc/vault 8200` + `GET /v1/sys/seal-status`로 본다. 상세는 FR-044·contracts/hostnames-and-access.md.
- SP-1 기간 외부 사용자는 없다. E2E 신원은 Authentik 로컬 사용자 `e2e@joshuatech.dev`(비밀번호·TOTP 시드는 Vault `kv/platform/authentik/e2e` 한 경로에만 있고, blueprint는 store `vault-platform`으로, tester는 Vault role `e2e-reader`로 같은 경로를 읽는다)이고 GitHub 테스트 계정은 만들지 않는다 — 소셜 로그인(US4 AC1)은 운영자가 브라우저로 1회 수동 검증하고 스크린샷을 tester 보고에 첨부한다. 운영자 개인 계정 자격은 어떤 환경변수·파일에도 넣지 않는다.
- SP-1은 사용자당 테넌트 1개를 가정한다. 멤버십 정본은 identity-admin `TenantMembership`이고 Authentik 그룹·`user.attributes.tenant_id`·FGA 튜플은 identity-admin이 갱신하는 파생이다(SP-1은 `seed_tenant`가 셋 다 씀). 테넌트 식별자는 어디서나 UUID(Authentik 그룹 `tenant:<uuid>`, claim `tenant_id`, FGA object `tenant:<uuid>`, Kafka 파티션 키 `tenantid`); slug는 `Tenant.slug` 컬럼에만.
- 사용자/테넌트 삭제·내보내기는 SP-2(identity-admin 테넌트 오케스트레이션)다. 보존: `SessionRevocationLog`는 `expires_at` + 30일 뒤 purge(일 1회), Authentik events 90일, Grafana Cloud 14일, Sentry 30일.
- Grafana Cloud Free·Sentry Free 계정은 운영자가 만들고 토큰을 Vault에 넣는다. GitHub App(gitops 커밋용)과 GHCR public 이미지도 운영자 권한으로 만든다.
- v1 데이터는 백업·임포트하지 않는다(사용자 결정 2026-08-28). v1 저장소 자체는 보존한다.
- 학습 노트 001·002는 이미 `rules/content.md` 계약을 따르므로 hello 페이지의 콘텐츠 로더 검증 입력으로 쓸 수 있다.
- 외부 계정(2026-09-01 사용자 확인, 비밀 아님): Cloudflare Zero Trust 팀 `joshua-tech`(팀 도메인 `joshua-tech.cloudflareaccess.com`, Free) · Grafana Cloud 스택 `https://joshuatech.grafana.net/`(조직 `joshuatech`, 관리자·contact point 이메일 joshua92y@gmail.com) · Sentry 조직 slug `joshtech`(팀 `joshtech`). 호스트명 규약은 contracts/hostnames-and-access.md: pod API `<alias>-m2m-<env>.joshuatech.dev`, 관리자 UI `admin.joshuatech.dev/<pod>/`.
- ES/ECK·Kibana(D11)는 SP-3에서 구현하지만 **노드 B** 예산에 자리(≈ 3 GiB)를 남긴다(노드 A에는 SP-3 자리를 잡지 않는다 — plan A14).
- **검증 후 결정(VD — 외부 플랫폼 서비스)**: 아래 9건은 벤더 쪽 동작이라 이 문서에서 "된다/안 된다"를 단정하지 않는다. 각 항목은 기본 가정으로 설계해 두고, 지정한 task에 착수할 때 **사용자 동석 실측**으로 확정하며 결과를 tasks 체크박스 옆 한 줄과 `report.md`에 기록한다. 승인은 이 항목들을 기다리지 않는다.
  - **VD-1** Authentik 2026.8 OSS의 delegation 사용 가능 여부 — 기본: impersonation 교환 + Access `common_name`(`AUTH_ACTOR_SUB` 미설정) · 대안: OSS에서 `Actor` 생성에 성공하면 delegation + `act.sub` 검증 — 결정 task **T081**
  - **VD-2** Cloudflare Cache Rule이 Worker(커스텀 도메인) 응답을 edge에서 서빙하는지 — 기본: 효과 없음(규칙 미생성) · 실측: 임시 Cache Rule 1회 apply → `curl -I /ko` 10회 → `cf-cache-status: HIT` + Workers 요청 수 불변이면 유지(A), 아니면 제거하고 프리렌더 HTML 자산화를 같은 task에서 시험(B) — **T093**
  - **VD-3** Cloudflare Free Rate Limiting 표현식에 host 조건을 넣을 수 있는지 — 기본: 경로만(`/api/auth/*`·`/if/flow/*`) · 대안: 가능하면 `joshuatech.dev/api/*`로 확대 — **T011**
  - **VD-4** Dragonfly v1.40.1 `--aclfile`이 `%R~revoked:*` 키 패턴을 로드하는지 — 기본: 로드됨 · 대안: 로드 오류면 entrypoint `ACL SETUSER` 래퍼(권한 결과는 동일) — **T057**
  - **VD-5** GitHub public repo Free에서 `gh pr merge --auto`와 Environment `production` 보호 규칙이 동작하는지 — 기본: 둘 다 동작("Allow auto-merge" 활성 전제) · 대안: dev bump PR도 운영자 수동 머지 — **T003·T074**
  - **VD-6** OCI lifecycle `previous-object-versions` 삭제에 `OBJECT_VERSION_DELETE` 정책이 필요한지 — 기본: 필요 · 대안: 규칙만으로 삭제 — **T010**(apply 후 첫 만료 관찰)
  - **VD-7** Grafana Cloud Free의 k8s-monitoring 차트 버전과 Viewer 서비스 계정의 사용자 석 소모 — 기본: 차트 4.5.0 핀, 서비스 계정은 3석을 소모하지 않음 — **T096·T098**
  - **VD-8** Workers Free 일 한도 초과 시 커스텀 도메인의 fail 모드(1027 vs fail-open) — 기본: 1027, **관찰만**(의도적으로 초과시키지 않는다) — 발생 시 `report.md`
  - **VD-9** Stakater Reloader scoped 모드(`watchGlobally: false` + ns 목록)가 ClusterRole 없이 동작하는지 — 기본: scoped 인스턴스 1개 · 대안: `watchGlobally: true` + `namespaceSelector`(ClusterRole 잔존, 트레이드오프 기록) — **T046**

## Design

### 1. 토폴로지와 노드 배치

```
브라우저 ─HTTPS─▶ Cloudflare(DNS·proxied·Access·WAF)
                    ├─ 정적 자산(무료) ─▶ Workers: Next.js OpenNext lean(프리렌더 + BFF Route Handlers)
                    └─ 443(NSG: Cloudflare IP만, AOP mTLS) ─▶ 노드 A Traefik ─▶ Ingress(host) ─▶ pod / Authentik / Argo UI
BFF ─(토큰 교환 후, Access 서비스 토큰)─▶ <alias>-m2m-<env>.joshuatech.dev

노드 A role=platform (2 OCPU/13 GB): K3s server·Traefik·cert-manager·Argo CD·Vault+ESO·Strimzi Kafka·Authentik·OpenFGA·Alloy(monitoring)·cloudflared·Reloader·system-upgrade-controller·앱 pod+워커(dev·prod, affinity 선호)  ≈ 8.6 GiB(plan A14 재계산, 예산 9 GiB)
노드 B role=data     (2 OCPU/13 GB): K3s agent·CNPG pg-main·Dragonfly(dev·prod)·cloudflared·cert-manager·CNPG 오퍼레이터(+ 앱 pod 스필오버) ≈ 3.6 GiB(예산 8 GiB)
SP-3 자리: Elasticsearch·Kibana·ECK ≈ 3 GiB — 전부 노드 B(합계 ≈ 6.6 GiB ≤ 8 GiB), 노드 A에는 SP-3 자리를 잡지 않는다
백업: platform-backup.timer(노드 A, K3s SQLite + Vault Raft → age → jt-backup-platform) · CNPG barman-cloud → jt-backup
```

배치 원칙: StatefulSet은 `nodeSelector` 고정(Kafka → A: Postgres fsync/WAL과 디스크 I/O 분리), 앱 Deployment는 A 선호, CPU limit 없음, 노드 간 오버레이 `flannel-backend: wireguard-native`. 네임스페이스(14): `kube-system`(traefik·coredns·metrics-server)·`argocd`·`vault`·`external-secrets`·`cert-manager`·`cnpg-system`·`data`(pg-main·kafka·dragonfly)·`identity`(authentik·openfga)·`jt-dev`·`jt-prod`·`monitoring`(alloy)·`system-upgrade`·`cloudflared`·`reloader` — `observability`라는 이름은 쓰지 않는다. PSA: `restricted` = argocd·vault·external-secrets·identity·jt-dev·jt-prod·cloudflared·reloader, `baseline` = cert-manager·cnpg-system·data, `privileged`(사유 기재) = kube-system·monitoring·system-upgrade. AppProject: `platform`·`dev`·`prod`. NetworkPolicy: contracts/network-policy.md의 허용 매트릭스 + 정책 5종 — `default-deny`·`allow-dns`(kube-system 제외 13 ns) · `allow-same-namespace`(7 ns) · `allow-kube-api`(10 ns) · `allow-apiserver-webhook`(4 ns). `deny-imds`는 `kube-system` 전용, `allow-imds`는 `vault` 전용이고, 나머지 ns의 IMDS 차단은 외부 egress 규칙마다 `except`+`ports`로 표현한다(FR-045).

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
├── platform/{cert-manager,traefik(Middleware·TLSOption·TLSStore만),vault,external-secrets,cnpg,kafka(Strimzi),dragonfly,authentik(blueprints),openfga,monitoring,cloudflared,reloader,system-upgrade,policies(ns·PSA 라벨·정책 5종·agent-view SA/RBAC·tests/(data-assert·kafka-assert·authz-assert Job))}/
├── apps/<pod>/{base,overlays/dev,overlays/prod}/
├── secrets/                      # ExternalSecret만
└── .github/workflows/{validate,promote}.yml
```

### 3. 웹·BFF·인증 흐름

1. 브라우저 → BFF `/api/auth/login` → Authentik Authorization Code + PKCE(`web-bff`, confidential).
2. 콜백에서 토큰 수신(aud=web-bff, `tenant_id`) → 암호화 refresh 쿠키(HttpOnly·Secure·SameSite=Lax) 설정, access는 isolate 캐시(5분).
3. API 호출 시 BFF는 identity-admin `/session/check`(2초 캐시)로 폐기 확인 → RFC 8693 교환(audience = 대상 pod; 기본은 impersonation, delegation `actor_token` 사용 여부는 VD-1) → 정적 맵의 `<alias>-m2m-<env>.joshuatech.dev` 호출(3 s 타임아웃) + `CF-Access-Client-Id/Secret`.
4. Cloudflare Access(Service Auth) → AOP mTLS → Traefik Ingress(허용 경로만) → pod: JWKS(svc DNS)로 iss·aud·exp 검증 + Access JWT `common_name` = `ACCESS_EXPECTED_CN` 확인(+ `AUTH_ACTOR_SUB`가 설정된 배포에서만 `act.sub` 대조 — VD-1) → Dragonfly 거부 목록 조회(0.2 s, 실패 시 503) → `tenant_id` → `SET LOCAL` → RLS(등급 A 테이블).
5. 폐기: 로그아웃/관리자 폐기/Authentik 웹훅 → identity-admin → Authentik revoke + `SessionRevocationLog` + Dragonfly `revoked:sub:{sub}`·`revoked:sid:{sid}` + Kafka `identity-admin.session.revoked`.

호스트: `joshuatech.dev`(웹) · `preview.`(PR 프리뷰 Worker, Access GitHub IdP) · `auth.`(Authentik; `/if/admin`·`/api/v3`는 Access 앱 `auth-admin`) · `<alias>-m2m-prod.` / `<alias>-m2m-dev.` · `admin.`(경로 `/<pod>/`) · `argo.` `vault.` `kibana.`(SP-3) · `cdn.`(R2). 전부 proxied, Full(strict).

### 4. pod 템플릿·데이터·이벤트

- 템플릿 기본값: Python 3.13 · uv · Django 6.1 + Ninja 1.7 · Celery(Dragonfly) · pydantic-settings · structlog/OTel/Sentry · 헬스 3종(`/healthz`·`/ready`·`/health`) · testcontainers · Dockerfile(uv 빌드 → slim 런타임, arm64, 비루트) · kustomize base(securityContext 전체·`automountServiceAccountToken: false`·requests 명시·Reloader 어노테이션·ExternalSecret `-env`/`-migrate`).
- 테이블 등급: A 테넌트 범위(`TenantModel`, FORCE RLS) / B pod 전역(`GlobalModel`: `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`). owner role `bypassrls`(마이그레이션·시드), app role NOBYPASSRLS.
- 인증 미들웨어 순서: Bearer JWT → JWKS(svc DNS; iss·aud·exp + `AUTH_ACTOR_SUB` 설정 시에만 `act.sub`) → Dragonfly 거부 목록(실패 시 503) → Access AUD(m2m/admin) + `common_name` = `ACCESS_EXPECTED_CN` → `tenant_id` → 트랜잭션 + `SET LOCAL`.
- CNPG `pg-main`: DB per pod + owner/app role, dev `dev_` 접두, `sslmode=verify-full`, barman-cloud → `jt-backup`(매일 02:00 KST, `archive_timeout 300`).
- Kafka(Strimzi): `KafkaNodePool` KRaft 1노드, `KafkaTopic`/`KafkaUser` CRD, 토픽 `<pod>.<entity>.<event>`, 파티션 3, 보존 7일, 파티션 키 `tenantid`(uuid), DLQ `<pod>.dlq`(outbox `max_attempts` 10).
- CloudEvents 예: `{"specversion":"1.0","id":"01J…","source":"identity-admin","type":"identity-admin.session.revoked","time":"…","subject":"<sub>","tenantid":"<tenant uuid>","data":{"sub":"…","nbf":"…","reason":"logout"}}`.

### 5. CI/CD·환경·시크릿·관측

- 모노레포: `ci.yml`(PR·main, `--ignore-scripts`·`--locked`) · `publish-pod.yml`(main → arm64 빌드 → digest → attestation → gitops dev bump = 브랜치 `bump/dev-<pod>-<sha7>` + PR + `gh pr merge --auto --squash`) · `deploy-web.yml`(PR 프리뷰 Worker `joshuatech-web-preview` / main deploy, Environment `production`). gitops: `validate.yml`(required, 렌더링 diff 코멘트) · `promote.yml`(attestation verify → prod PR). ruleset `bypass_actors: []`. 롤백 = revert / `wrangler rollback`. Renovate(`automerge: false`)·SHA 핀·최소 permissions·PAT 없음.
- 환경: dev + prod 상시, 앱 pod만 복제, 플랫폼 공유(Authentik 별도 앱 `web-bff-dev`, `dev.` 토픽, `dev_` DB, Dragonfly dev, Vault `kv/dev` + ESO `vault-dev` store, OpenFGA store 2).
- 시크릿: Vault Raft(노드 A, 일 1회 스냅샷 → `jt-backup-platform`) + OCI KMS auto-unseal(키 `prevent_destroy`·삭제 유예 30일) + K8s auth(role `eso-platform`/`eso-dev`/`eso-prod`/`eso-data`/`vault-backup`/`e2e-reader`, 전부 audience `vault`·`token_ttl` 1h/`max` 4h) + ESO(`ClusterSecretStore` 5개 = `vault-platform`·`vault-dev`·`vault-prod`·`vault-data`·`k8s-data-ca`, `refreshInterval 5m`) + Reloader 재적재 + audit → Loki. 부트스트랩: OpenTofu(KMS·버킷) → Vault init(root 토큰 1회용·revoke, recovery 3/2) → 운영자가 초기 값 `vault kv put`(터널) → 이후 ESO. Workers 시크릿은 `wrangler secret put`. OpenTofu 상태는 `jt-tfstate`.
- 관측: Alloy(`monitoring`) → Grafana Cloud(메트릭·Loki·Tempo; 로그 필터·트레이스 샘플링 0.1), Sentry(Django·web 클라이언트, PII 마스킹), Workers observability(BFF JSON 로그), `traceparent`·`x-request-id` 전파, 대시보드 3·알림 규칙 13(`runbook_url`).

### 6. 검증과 tasks 단계

① 문서(ADR·memory·rules·agents) → ② OpenTofu(OCI·Cloudflare) + v1 워크플로 비활성·재이미지 → ③ K3s·Argo·gitops·cert-manager/Traefik/AOP → ④ Vault·ESO → ⑤ CNPG·Strimzi·Dragonfly → ⑥ Authentik·OpenFGA·Access → ⑦ Alloy·Sentry·예산 알림 → ⑧ packages·템플릿·identity-admin → ⑨ 웹 hello·BFF·도메인 전환 → ⑩ RAM 보고·런북·report. 단계마다 tester E2E task 1개(헌법 II). 테스트 위치: `tests/`(하네스·kubeconform), `apps/*/tests/`, `packages/*/tests/`, `e2e/`(Playwright).

### 7. 리스크

| 리스크 | 징후 | 완화 |
|---|---|---|
| 노드 RAM 초과 | US7 실측 > 목표, OOMKill | Argo core 전환 · Alloy 축소 · dev quota 축소 · Redpanda 검토(ADR 0008 트리거) |
| PAYG 과금 확대 | 월 Compute > 3 SGD | 예산 알림 · 13 → 12 GB · 유료 자원 생성 금지 |
| OpenNext 번들 초과 | bundle-budget 실패 | 의존성 제거 → Workers Paid(ADR 0004, 사용자 승인) |
| Authentik OSS 교환 제약 | 교환 실패·`act` 미발급 | 기본은 impersonation 교환 + Access 서비스 토큰 `common_name`(`ACCESS_EXPECTED_CN`) 식별, `AUTH_ACTOR_SUB`는 선택값. delegation 채택 여부는 **VD-1 실측 결과에 따름**(T081) — 코드는 어느 쪽이든 같다 |
| Kafka 단일 노드 손실 | 디스크 장애 | outbox가 원천, 보존 7일, 멱등 소비 |
| Vault unseal 실패 | sealed(`VaultSealed`) | KMS 복귀 대기(recovery 3/2는 unseal 수단 아님), ESO 마지막 Secret 유지, pod 재시작 금지; KMS 키 `prevent_destroy` + 일 1회 Raft 스냅샷 |
| 우회 직접 호출 | 오리진 IP 노출 | 보안 리스트 + AOP + pod의 Access JWT 검증 |
| Traefik v3 차트 breaking | 업그레이드 후 라우팅 실패 | HelmChartConfig 최소, 업그레이드 창 |
| 1인 운영 부담 | 패치 지연 | Renovate · 알림 규칙 13개(`runbook_url`) · 런북 8종 · Reloader |

### 8. ADR 목록

| ADR | 귀속 결정(D#) | 결정 | 기각 대안 |
|---|---|---|---|
| [0002 deployment-principles](../../docs/decisions/0002-deployment-principles.md) | D2 · D15 · D16 · 부록 D10(Dragonfly 유지 — v1 계승, 신규 아님) | 불변 digest · Git 정본 · pull CD · CI 무자격증명 · PR 검증/main 발행(bypass 없음) · rollback=revert · expand→contract | SSH push · :latest · 수동 배포 |
| [0003 runtime-track](../../docs/decisions/0003-runtime-track.md) | D3 · D12 · D17 · 부록 D14(관측: Grafana Cloud Free + Alloy, Sentry SaaS Free) | 웹 Workers + API OCI K3s 2노드(A platform / B data) + Argo CD | Cloudflare-native · compose-pull · 전부 K3s |
| [0004 web-framework](../../docs/decisions/0004-web-framework.md) | D4 · D19(콘텐츠 정본 = git MDX, `packages/content` 로더, R2 + Image Transformations) | Next.js 16.3 + OpenNext lean, 프리렌더 + BFF, 번들 예산, $5 탈출구, 보안 패치 라인 밖 다운그레이드 금지 | Astro · SvelteKit · 정적 export + Hono |
| [0005 backend-framework-policy](../../docs/decisions/0005-backend-framework-policy.md) | D5 · D18 | Django 6.1 + Ninja 1.7 기본, FastAPI는 수치 트리거 예외 | FastAPI 단일 · Hono · Python Workers |
| [0006 identity-and-authz](../../docs/decisions/0006-identity-and-authz.md) | D6 · D7 | Authentik 단일 IdP · provider별 aud · RFC 8693 교환(기본 impersonation + Access `common_name` 식별, `act.sub` 검증은 `AUTH_ACTOR_SUB` 설정 시에만 — delegation 채택은 VD-1) · BFF 게이트웨이 · 세션 정본 Authentik + refresh 쿠키 · 즉시 폐기 이벤트 + 거부 목록(DB 정본·Dragonfly 캐시) · OpenFGA 교차 컨텍스트 · Access 이중 | Better Auth · Clerk · 자체 세션 서비스 · introspection · 인클러스터 게이트웨이 |
| [0007 data-ownership-and-tenancy](../../docs/decisions/0007-data-ownership-and-tenancy.md) | D8 | CNPG 1 클러스터 · DB per pod · role 격리 · tenant_id + FORCE RLS + SET LOCAL · 테이블 등급 A/B · 멤버십 정본 TenantMembership | Neon · Supabase · D1 · 스키마 분리 · 앱 계층만 |
| [0008 event-backbone](../../docs/decisions/0008-event-backbone.md) | D9 | Kafka KRaft(Strimzi) · 폴링 outbox 릴레이 · CloudEvents JSON + JSON Schema | Dragonfly Streams · Redpanda · Debezium · Avro |
| [0009 search](../../docs/decisions/0009-search.md) | D11 | ES 1노드 + Kibana + Nori · ECK · FastAPI search pod(SP-3) | Postgres FTS · Pagefind · OpenSearch |
| [0010 secrets](../../docs/decisions/0010-secrets.md) | D13 | HashiCorp Vault Raft + OCI KMS auto-unseal + ESO | Sealed Secrets · SOPS+age · OpenBao |

ADR 없이 spec에만 남는 결정: D1(v1 종료 — 사용자 결정, US8·FR-042)·D20(SP-1 범위 — 이 spec). D10·D14·D19의 부록 귀속은 approval 시정(R25)에 따른다.
