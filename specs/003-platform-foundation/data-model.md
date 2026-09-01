# Data Model: 플랫폼 기반 (SP-1)

spec Key Entities의 상세. 헌법 III에 따라 엔티티마다 **소유자**(쓰기·마이그레이션 독점)와 **격리 키**를 적는다. SP-1은 단일 테넌트 `joshuatech`를 시드하지만 모든 계약은 `tenant_id`를 가진다. 저장 위치는 넷이다: pod Postgres DB(CNPG `pg-main`), Dragonfly(휘발·TTL), git(모노레포·platform-gitops), 외부 시스템(Authentik·OpenFGA·Vault).

## 1. Tenant — 소유 identity-admin (DB `identity_admin`)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. `tenant_id` = 자기 자신 |
| `slug` | text | unique, `^[a-z0-9][a-z0-9-]{1,30}$`, 불변 |
| `display_name` | text | 1–80자 |
| `status` | enum `active` · `suspended` | 기본 `active` |
| `created_at` · `updated_at` | timestamptz | 서버 시각 |

- 관계: Authentik 그룹 `tenant:<slug>`(멤버십 원천), OpenFGA `tenant:<id>#member`(교차 컨텍스트 조회용 투영), 모든 pod의 `tenant_id` 컬럼이 이 `id`를 참조(FK 없음 — pod 간 FK 금지, 값 참조만).
- 상태 전이: `active → suspended → active`. `suspended`면 identity-admin이 해당 테넌트 사용자 세션을 전부 폐기한다(SP-2).
- 시드: `joshuatech`(마이그레이션 데이터 또는 부트스트랩 command).

## 2. TenantMembership — 소유 identity-admin

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK |
| `tenant_id` | UUID | RLS 격리 키, NOT NULL |
| `user_sub` | text | Authentik `sub`(불변 식별자). `(tenant_id, user_sub)` unique |
| `role` | enum `owner` · `admin` · `member` | SP-1은 `owner` 1건 |
| `created_at` | timestamptz | |

- Authentik 사용자 이벤트(웹훅 → `identity-admin.user.registered`)로 갱신되는 투영. SP-1은 운영자 계정 1건만.
- OpenFGA 튜플 `user:<sub> member tenant:<id>`는 이 테이블의 outbox 소비자가 쓴다(요청 안에서 DB와 FGA를 동시에 쓰지 않는다).

## 3. SessionRevocation — 소유 identity-admin (Dragonfly + DB 로그)

Dragonfly 키(휘발, TTL = access TTL 300 s + 시계 오차 60 s):

| 키 | 값 | 의미 |
|---|---|---|
| `revoked:sub:{sub}` | epoch 초 `nbf` | 이 시각 이전에 발급된(`iat < nbf`) 토큰은 거부 — 전체 기기 로그아웃·관리자 폐기 |
| `revoked:sid:{sid}` | `1` | 특정 세션 토큰만 거부 — 단일 기기 로그아웃(Authentik 토큰에 `sid`가 있을 때) |

DB 테이블 `session_revocation_log`(감사·재적용용):

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK |
| `tenant_id` | UUID | NOT NULL(운영자 테넌트) |
| `sub` | text | NOT NULL |
| `sid` | text | nullable |
| `reason` | enum `logout` · `logout_all` · `admin` · `authentik_webhook` · `tenant_suspended` | |
| `nbf` | timestamptz | 거부 기준 시각 |
| `expires_at` | timestamptz | `nbf` + access TTL + 60 s |
| `created_at` | timestamptz | |

- 상태: `recorded`(Dragonfly 키 존재) → `expired`(TTL 만료, 로그만 남음). identity-admin은 기동 시 `expires_at > now()`인 로그를 Dragonfly에 재적용한다(Dragonfly 재시작 대비).
- 이벤트: 기록과 같은 트랜잭션에 outbox `identity-admin.session.revoked`.

## 4. OutboxEvent — 소유 각 pod (자기 DB `outbox_event`)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | ULID(text 26) | PK = CloudEvents `id` |
| `topic` | text | `<pod>.<entity>.<event>` (env 접두는 릴레이가 붙임) |
| `partition_key` | text | = `tenant_id` |
| `payload` | jsonb | CloudEvents 1.0 envelope 전체 |
| `created_at` | timestamptz | |
| `attempts` | int | 기본 0 |
| `last_error` | text | nullable |

- 상태: `pending`(행 존재) → `published`(행 삭제) / `failed`(`attempts ≥ 10` → 알림, 행 유지).
- 릴레이: `SELECT … FOR UPDATE SKIP LOCKED LIMIT 100 ORDER BY id` → idempotent producer(key = `partition_key`) → 성공 시 DELETE. 같은 트랜잭션에서 도메인 쓰기와 함께 INSERT되는 것만 유효하다(라이브러리가 `transaction.atomic()` 밖 INSERT를 거부).
- RLS: `tenant_id` 컬럼 대신 `partition_key`를 격리 키로 정책 적용(릴레이는 owner role로 전체 조회).

## 5. EventSchema — 소유 모노레포 `packages/events` (전역)

- 파일 `packages/events/schemas/<topic>.json` (JSON Schema 2020-12). `$id` = `https://joshuatech.dev/events/<topic>/v1`, `x-version` semver.
- envelope 공통(`packages/events/schemas/_envelope.json`): `specversion`(const "1.0") · `id`(ULID) · `source`(pod 이름) · `type`(= topic) · `time`(RFC 3339) · `subject`(entity id) · `tenantid`(UUID) · `datacontenttype`(application/json) · `data`(토픽별 스키마).
- 호환 규칙(CI): 기존 필드 삭제·타입 변경·required 추가 금지, 필드 추가만 허용. 위반은 새 토픽(`…v2`)으로.
- SP-1 정의 토픽 6개: `identity-admin.user.registered`, `identity-admin.tenant.created`, `identity-admin.session.revoked`, `portfolio-core.note.published`, `engagement.comment.created`, `media.object.ready`. 상세는 `contracts/events.md`.

## 6. KafkaTopic / KafkaUser — 소유 platform-gitops (플랫폼 자원)

| 항목 | 규칙 |
|---|---|
| 토픽 이름 | prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`, DLQ `<pod>.dlq` / `dev.<pod>.dlq` |
| 파티션 | 3 (파티션 키 `tenant_id`) |
| 보존 | `retention.ms` 7일, `cleanup.policy` delete |
| 복제 | 1 (단일 노드), `min.insync.replicas` 1 |
| 사용자 | `<pod>`(prod) · `dev-<pod>`(dev), SCRAM-SHA-512, 비밀은 Strimzi가 생성 → ESO가 아니라 Strimzi Secret을 pod가 직접 참조 |
| ACL | 자기 토픽 `Write`·`Describe`, 구독 토픽 `Read`·`Describe`, 그룹 `<pod>-*` `Read`, DLQ `Write` |

## 7. Database / Role — 소유 platform-gitops (CNPG 선언)

| 항목 | 규칙 |
|---|---|
| database | prod `<pod_snake>`(`identity_admin`, `portfolio_core`, `media`, `engagement`, `notification`, `insights`, `search`, `assistant`) + `authentik`, `openfga`; dev `dev_<pod_snake>` |
| owner role | `<pod_snake>_owner` — 테이블 소유, 마이그레이션 전용, `NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS` |
| app role | `<pod_snake>_app` — `LOGIN NOBYPASSRLS`, 테이블 비소유, `GRANT SELECT/INSERT/UPDATE/DELETE`만, `FORCE ROW LEVEL SECURITY` 적용 대상 |
| 접근 경계 | role은 자기 database에만 `CONNECT`. 다른 database `CONNECT` 권한 없음 |
| 비밀 | Vault `kv/{env}/db/<pod_snake>/{owner,app}` → ESO → CNPG `managed.roles[].passwordSecret` |
| 확장 | `pgvector`(assistant 대비), `pg_bigm`(검색 폴백) — database별 `CREATE EXTENSION`은 owner role |

RLS 정책 표준(django-common 헬퍼가 생성):

```sql
ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;
ALTER TABLE <t> FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON <t>
  USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
```

## 8. SecretPath — 소유 운영자 (Vault kv v2)

경로 규칙 `kv/{scope}/{component}/{name}`; scope ∈ `platform`(환경 무관) · `dev` · `prod`.

| 경로 | 키 | 소비자 |
|---|---|---|
| `kv/platform/cloudflare/dns-token` | `token` | cert-manager |
| `kv/platform/cloudflare/tunnel` | `token` | cloudflared |
| `kv/platform/grafana-cloud` | `metrics_url`, `logs_url`, `traces_url`, `token` | Alloy |
| `kv/platform/authentik` | `secret_key`, `bootstrap_password`, `bootstrap_token` | Authentik |
| `kv/platform/oci/s3` | `access_key`, `secret_key` | CNPG barman-cloud |
| `kv/{env}/db/<pod_snake>/owner` · `/app` | `username`, `password` | CNPG managed roles, pod |
| `kv/{env}/authentik/<pod>` | `client_id`, `client_secret`, `jwks_url`, `issuer` | pod, BFF(web-bff) |
| `kv/{env}/access/<pod>` | `client_id`, `client_secret` | BFF(서비스 토큰), pod(검증용 aud) |
| `kv/{env}/dragonfly` | `password` | pod, identity-admin |
| `kv/{env}/sentry/<pod>` | `dsn` | pod |
| `kv/{env}/web/session` | `encryption_key` | BFF(refresh 쿠키 암호화) — Workers Secret으로 `wrangler secret put`(ESO 밖) |

- gitops에는 `ExternalSecret`(경로·키 매핑)만. 값은 Vault UI/CLI로만 넣는다. 회전은 Vault 값 교체 → ESO `refreshInterval`(1h) 내 반영 → 롤아웃(Reloader 어노테이션 또는 Secret 해시).

## 9. AuthentikObject — 소유 identity (Blueprints, gitops `platform/authentik/blueprints/`)

| 객체 | SP-1 인스턴스 | 핵심 속성 |
|---|---|---|
| Source | `github`, `google` | OAuth 소셜 로그인. 이메일/비밀번호는 내장 |
| Stage/Flow | authentication(identification → password → MFA validation), enrollment(이메일 인증), recovery | MFA: TOTP·WebAuthn(passkey) |
| Group | `tenant:joshuatech`, `platform-admin` | 정책 바인딩·RBAC 매핑 |
| Application + Provider(OAuth2) | `web-bff`(confidential, PKCE, token exchange grant, redirect `https://joshuatech.dev/api/auth/callback`, access 300 s, refresh 30 d 회전), `identity-admin`(자기 signing key·JWKS, Federated Providers = [`web-bff`]), `argocd`·`vault`·`grafana`(OIDC, 그룹 클레임) | 각 provider의 `issuer` = `https://auth.joshuatech.dev/application/o/<slug>/` |
| ScopeMapping | `tenant_id`(사용자 attribute `tenant_id` 또는 그룹 `tenant:*`에서 파생) | 모든 access/ID 토큰에 포함 |
| NotificationTransport + Rule | webhook(generic) → `https://identity-admin-api.joshuatech.dev/webhooks/authentik`, 이벤트 `logout`·`login`·`model_deleted(session)` | 공유 비밀 헤더 |
| Outpost(proxy) | Django admin forward-auth(`admin-*` 호스트) | SP-1은 identity-admin admin만 |

- Blueprints는 YAML 파일로 ConfigMap 마운트, `authentik_blueprints` 라벨로 자동 적용. 비밀 값은 `!Env`로 ExternalSecret에서 주입.

## 10. FgaModel / FgaStore — 소유 identity (모델 파일 `packages/authz/model.fga`)

```
model
  schema 1.1
type user
type tenant
  relations
    define owner: [user]
    define admin: [user] or owner
    define member: [user] or admin
```

- store `jt-dev`, `jt-prod`(ID는 Vault `kv/{env}/openfga/store_id`). 튜플 쓰기 소유: `tenant#*`는 identity-admin. SP-2 이후 `room#member`·`media#viewer` 같은 교차 관계가 추가되면 모델 파일 PR + CODEOWNERS.

## 11. ContentItem — 소유 git (`content/{study,blog,projects}`, 전역)

frontmatter(`rules/content.md` 계약, zod로 코드화):

| 필드 | 타입 | 규칙 |
|---|---|---|
| `title` · `description` | string | 필수 |
| `pubDate` | date | 필수, `updatedDate` ≥ `pubDate` |
| `tags` | string[] | 필수(빈 배열 허용) |
| `series` · `seriesOrder` | string · int | 선택, 같이 존재 |
| `draft` | boolean | 필수; PROD 빌드에서 `true`는 제외 |
| `change` | string | 필수(study), `^\d{3}-[a-z0-9-]+$` |
| `sources` | `{title, path?, url?}[]` | 필수(빈 배열 허용), path 또는 url 중 하나 |

파생 필드(로더가 계산): `slug`(파일명), `lang`(접미사 `.en`·`.ja` → `en`·`ja`, 없으면 `ko`), `collection`, `readingTime`, `headings[]`, `translations[]`(같은 slug의 다른 lang). 규칙: 같은 slug의 언어 변형은 `pubDate`·`change`가 같아야 하고, `ko` 파일이 없으면 오류.

## 12. ADR — 소유 `docs/decisions/` (전역)

- 파일 `NNNN-<kebab>.md`, frontmatter `status`(proposed · accepted · superseded by NNNN) · `date` · `decision-makers`. 절: Context and Problem Statement / Considered Options / Decision Outcome / Consequences. 번호 재사용 금지. SP-1은 0002–0010, 전부 `accepted`(근거 = 이 spec).

## 13. RamReport — 소유 `specs/003-platform-foundation/report.md`

| 열 | 내용 |
|---|---|
| node | A · B |
| sample | 1 · 2 · 3 (10분 간격) |
| used_gb | `kubectl top nodes` memory |
| allocatable_gb | 13 |
| top_pods | 상위 5 pod와 실측 MiB |
| verdict | SC-005 판정(A ≤ 9, B ≤ 8) 및 완화안 |

## 엔티티 관계 요약

```
Tenant 1 ── n TenantMembership(user_sub)      [identity_admin DB]
Tenant.id ──값 참조──▶ 모든 pod 테이블.tenant_id (RLS 격리 키)
TenantMembership ──outbox──▶ identity-admin.user.registered ──▶ FgaStore 튜플(user member tenant)
SessionRevocation(Dragonfly) ◀── identity-admin ──outbox──▶ identity-admin.session.revoked ──▶ 모든 pod(재적용 선택)
OutboxEvent(pod DB) ──릴레이──▶ KafkaTopic ──▶ 소비자 pod
SecretPath(Vault) ──ESO──▶ Secret ──▶ CNPG roles · pod env · cloudflared · Alloy
AuthentikObject(Provider) ──JWKS──▶ pod 인증 미들웨어 · BFF
ContentItem(git) ──packages/content──▶ web 빌드 · (SP-2) notes-sync ──▶ portfolio-core 메타
```
