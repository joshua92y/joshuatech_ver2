# Data Model: 플랫폼 기반 (SP-1)

spec Key Entities의 상세. 헌법 III에 따라 엔티티마다 **소유자**(쓰기·마이그레이션 독점)와 **격리 키**를 적는다. SP-1은 단일 테넌트 `joshuatech`를 시드하지만 모든 계약은 `tenant_id`(UUID)를 가진다. 저장 위치는 넷이다: pod Postgres DB(CNPG `pg-main`), Dragonfly(휘발·TTL, 파생 캐시), git(모노레포·platform-gitops), 외부 시스템(Authentik·OpenFGA·Vault).

pod DB 테이블은 두 등급이다(contracts/pod-template.md §테이블 등급): **A 테넌트 범위**(`TenantModel`, `tenant_id` + FORCE RLS) / **B pod 전역**(RLS 미적용, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`). 테넌트 식별자는 어디서나 UUID — Authentik 그룹 `tenant:<uuid>`, claim `tenant_id`, FGA object `tenant:<uuid>`, Kafka 파티션 키 `tenantid`. slug는 `Tenant.slug` 컬럼에만 있다.

## 1. Tenant — 소유 identity-admin (DB `identity_admin`, 등급 B)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. `tenant_id` = 자기 자신 |
| `slug` | text | unique, `^[a-z0-9][a-z0-9-]{1,30}$`, 불변. 표시·URL 용도만 — 다른 시스템의 식별자로 쓰지 않는다 |
| `display_name` | text | 1–80자 |
| `status` | enum `active` · `suspended` | 기본 `active` |
| `created_at` · `updated_at` | timestamptz | 서버 시각 |

- 멤버십 정본은 §2 `TenantMembership`. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`·OpenFGA `tenant:<uuid>#member`는 **identity-admin이 갱신하는 파생**이다(SP-1은 `seed_tenant` command가 셋 다 쓴다; SP-2부터 이벤트/API 경유). 모든 pod의 `tenant_id` 컬럼이 이 `id`를 참조(FK 없음 — pod 간 FK 금지, 값 참조만).
- 상태 전이: `active → suspended → active`. `suspended`면 identity-admin이 해당 테넌트 사용자 세션을 전부 폐기한다(SP-2).
- 시드: `seed_tenant`(slug `joshuatech`) → Tenant + TenantMembership(owner) + Authentik 그룹/attribute + FGA 튜플.
- 등급 B: RLS 없음. 사용자/테넌트 삭제·내보내기는 SP-2.

## 2. TenantMembership — 소유 identity-admin (등급 B, 멤버십 정본)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK |
| `tenant_id` | UUID | NOT NULL, `Tenant.id` 값 참조 |
| `sub` | text | Authentik `sub`(불변 식별자, 참조만). **`(sub, tenant_id)` unique** |
| `role` | enum `owner` · `admin` · `member` | SP-1은 `owner` 1건 |
| `created_at` | timestamptz | |

- 이 테이블이 **정본**이다. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`(ScopeMapping `tenant_id`의 원천)·OpenFGA 튜플 `user:<sub> member tenant:<uuid>`는 identity-admin이 이 테이블을 기준으로 갱신하는 파생(요청 안에서 DB와 외부 시스템을 동시에 쓰지 않는다 — SP-1 `seed_tenant`, SP-2 outbox 소비자).
- SP-1 가정: **사용자당 테넌트 1**(claim `tenant_id` 단일값). 다테넌트 선택은 SP-2.
- 등급 B: RLS 없음 — `/tenants/me`는 app role로 토큰의 `sub`·`tenant_id`를 명시 필터한다.

## 3. SessionRevocationLog(정본, DB) · SessionRevocation(Dragonfly 파생 캐시) — 소유 identity-admin

DB 테이블 `session_revocation_log`(등급 B, `sub` 단위):

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK |
| `tenant_id` | UUID | NOT NULL(사용자의 테넌트; 사용자당 테넌트 1) |
| `sub` | text | NOT NULL |
| `sid` | text | nullable |
| `reason` | enum `logout` · `logout_all` · `admin` · `authentik_webhook` · `tenant_suspended` | |
| `nbf` | timestamptz | 거부 기준 시각 |
| `expires_at` | timestamptz | `nbf` + 330 s(access TTL 300 s + 30 s) |
| `created_at` | timestamptz | |

Dragonfly 키(파생 캐시, contracts/denylist.md가 정본):

| 키 | 값 | TTL |
|---|---|---|
| `revoked:sub:{sub}` | epoch 초 `nbf` — `iat < nbf`인 토큰 거부(전체 기기·관리자·테넌트 정지) | 330 s |
| `revoked:sid:{sid}` | `1` — 특정 세션만 거부(단일 기기) | 330 s |
| `denylist:epoch` | identity-admin 기동 시각. 없으면 캐시가 비워진 것 | 없음 |

- 쓰기: 기록(INSERT)과 같은 트랜잭션에 outbox `identity-admin.session.revoked`; 커밋 후 Dragonfly SET. 등급 B이므로 app role이 컨텍스트 없이 쓴다.
- 재적용: 기동 시 + Celery beat 30 s마다 `denylist:epoch` 부재 시 `expires_at > now()` 행을 Dragonfly에 재적용(Kafka 재생은 쓰지 않는다).
- 보존: `expires_at + 30 d` 지난 행을 일 1회 purge.
- 상태: `recorded`(캐시 키 존재) → `expired`(TTL 만료, 로그만 남음) → purge.

## 4. OutboxEvent — 소유 각 pod (자기 DB `outbox`, 등급 B)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | ULID(text 26) | PK = CloudEvents `id` |
| `topic` | text | `<pod>.<entity>.<event>` (env 접두는 릴레이가 붙임) |
| `partition_key` | text | = `tenant_id`(UUID) |
| `payload` | jsonb | CloudEvents 1.0 envelope 전체 |
| `created_at` | timestamptz | |
| `attempts` | int | 기본 0 |
| `last_error` | text | nullable |
| `dead_at` | timestamptz | nullable — `<pod>.dlq` 발행 시각 |

- 상태: `pending`(행 존재) → `published`(행 삭제) / `dead`(`attempts ≥ max_attempts 10` → 원본 봉투를 `<pod>.dlq`로 발행 + `dead_at`, 행 유지·수동 재처리).
- 릴레이: relay 컨테이너가 **app role**로 `SELECT … FOR UPDATE SKIP LOCKED LIMIT 100 ORDER BY id` → idempotent producer(key = `partition_key`, `delivery.timeout.ms` 30000) → 성공 시 DELETE. 같은 트랜잭션에서 도메인 쓰기와 함께 INSERT되는 것만 유효하다(라이브러리가 `transaction.atomic()` 밖 INSERT를 거부).
- 등급 B: RLS 미적용 — 릴레이가 모든 테넌트의 행을 읽는다. 지표 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`(relay 9464).

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
| 사용자 | `<pod>`(prod) · `dev-<pod>`(dev), SCRAM-SHA-512. 비밀번호 원천은 Vault `kv/{env}/kafka/<pod>` → ESO → `KafkaUser.spec.authentication.password.valueFrom.secretKeyRef`(kafka ns) + 앱 ns에도 같은 경로의 ExternalSecret; 클러스터 CA(`jt-kafka-cluster-ca-cert`)는 ESO kubernetes provider로 앱 ns에 미러 |
| ACL | 자기 토픽 `Write`·`Describe`, 구독 토픽 `Read`·`Describe`, 그룹 `<pod>-*` `Read`, DLQ `Write` |

## 7. Database / Role — 소유 platform-gitops (CNPG 선언, `platform/cnpg-databases/`)

| 항목 | 규칙 |
|---|---|
| database (SP-1) | **`identity_admin` · `dev_identity_admin` · `authentik` · `openfga`** — 4개. 나머지 pod DB(`portfolio_core`·`media`·`engagement`·`notification`·`insights`·`search`·`assistant`와 그 `dev_` 접두)는 각 pod feature가 추가한다(YAGNI) |
| owner role | `<pod_snake>_owner` — 테이블 소유, 마이그레이션·시드 전용, `NOSUPERUSER NOCREATEDB NOCREATEROLE` + **`bypassrls: true`**(FORCE RLS를 우회하므로 owner 정책이 필요 없다). 런타임 pod에는 자격이 없다(`<pod>-migrate` ExternalSecret만) |
| app role | `<pod_snake>_app` — `LOGIN NOBYPASSRLS`, 테이블 비소유, `GRANT SELECT/INSERT/UPDATE/DELETE`만. `ALTER ROLE … SET statement_timeout = '15s'`, `idle_in_transaction_session_timeout = '30s'`. A 등급 테이블은 FORCE RLS 적용 대상, B 등급은 컨텍스트 없이 접근 |
| 접근 경계 | role은 자기 database에만 `CONNECT`. 다른 database `CONNECT` 권한 없음 |
| TLS | 클라이언트는 `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`. CA Secret `pg-main-ca`는 ESO kubernetes provider로 `identity`·`jt-dev`·`jt-prod`에 미러(T049: `pg_stat_ssl` 세션 ssl=true 단언). Authentik은 `AUTHENTIK_POSTGRESQL__SSLMODE=verify-full`·`AUTHENTIK_POSTGRESQL__SSLROOTCERT`(개별 env, `CONN_OPTIONS` 금지) |
| 비밀 | Vault `kv/{env}/db/<pod_snake>/{owner,app}` → ESO → CNPG `managed.roles[].passwordSecret` |
| 백업 | barman-cloud → 버킷 `jt-backup`(IAM 사용자 `svc-s3-backup`만, versioning), `ScheduledBackup 0 0 17 * * *`(02:00 KST 매일), `archive_timeout 300`. PITR은 클러스터 전체(재해 복구 전용); 단일 DB 복구 = side Cluster PITR → `pg_dump` → 복원(런북) |
| 확장 | `pgvector`(standard 이미지 내장, assistant 대비) — database별 `CREATE EXTENSION`은 owner role. `pg_bigm`은 자체 확장 이미지가 필요해 SP-3로 이월 |

RLS 정책 표준(django-common 헬퍼가 등급별로 생성):

```sql
-- A 등급(TenantModel): rls_policies(<t>)
ALTER TABLE <t> ENABLE ROW LEVEL SECURITY;
ALTER TABLE <t> FORCE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON <t>
  USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
  WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid);
-- owner role은 BYPASSRLS이므로 owner 정책을 만들지 않는다.

-- B 등급(GlobalModel, 허용 목록 tenant · tenant_membership · outbox · session_revocation_log): RLS 없음.
-- check_rls: A 등급 전부 FORCE RLS + 정책 존재, RLS 없는 테이블은 전부 허용 목록 안 — 아니면 실패.
```

## 8. SecretPath — 소유 운영자 (Vault kv v2)

경로 규칙 `kv/{scope}/{component}/{name}`; scope ∈ `platform`(환경 무관) · `dev` · `prod`. ESO는 scope별 `ClusterSecretStore`(`vault-platform`·`vault-dev`·`vault-prod`, contracts/gitops-repo.md)로 읽는다.

| 경로 | 키 | store | 소비자 |
|---|---|---|---|
| `kv/platform/cloudflare/dns-token` | `token` | `vault-platform` | cert-manager |
| `kv/platform/cloudflare/tunnel` | `token` | `vault-platform` | cloudflared |
| `kv/platform/grafana-cloud` | `metrics_url`, `logs_url`, `traces_url`, `token` | `vault-platform` | Alloy(`monitoring`) |
| `kv/platform/authentik` | `secret_key`, `bootstrap_password`, `bootstrap_token` | `vault-platform` | Authentik |
| `kv/platform/oci/s3` | `access_key`, `secret_key`(IAM 사용자 `svc-s3-backup`, 버킷 `jt-backup`만) | `vault-platform` | CNPG barman-cloud |
| `kv/platform/vault-backup` | **없음** | — | Vault Raft 스냅샷은 kv 비밀 없이 수행한다: K8s auth role `vault-backup`(정책 `sys/storage/raft/snapshot` read, SA `vault-backup` ns `vault`) + 노드 A 인스턴스 프린시펄(동적 그룹 `jt-node-a`)이 `jt-backup-platform/vault/`에 업로드(`platform-backup.sh`, age 암호화). K3s 번들도 같은 버킷 `k3s/` |
| `kv/{env}/db/<pod_snake>/owner` | `username`, `password`, `url` | `vault-{env}` | CNPG managed role; **`<pod>-migrate`** ExternalSecret(migrate Job만) |
| `kv/{env}/db/<pod_snake>/app` | `username`, `password`, `url`(`sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` 포함) | `vault-{env}` | CNPG managed role; **`<pod>-env`** |
| `kv/{env}/kafka/<pod>` | `password` | `vault-{env}` | KafkaUser(`data` ns); `<pod>-env` |
| `kv/{env}/authentik/<pod>` | `client_id`, `client_secret`, `jwks_url`, `issuer` | `vault-{env}` | `<pod>-env` |
| `kv/{env}/authentik/identity-admin` | 위 4개 + `api_token`(Authentik 서비스 계정 `identity-admin`: 사용자 read · `authentik_core.delete_authenticatedsession` · 토큰 revoke) + `webhook_secret`(HMAC) | `vault-{env}` | identity-admin `-env`; Authentik 웹훅 transport |
| `kv/{env}/authentik/web-bff` | `client_id`, `client_secret`(prod = `web-bff`, dev = `web-bff-dev` provider) | ESO 밖 | BFF — Workers Secrets에만(`wrangler secret put`) |
| `kv/{env}/access/web-bff` | `client_id`, `client_secret`(Access 서비스 토큰 `web-bff-<env>`) | ESO 밖 | BFF — **Workers Secrets에만**. pod에는 배포하지 않는다. `kv/{env}/access/<pod>` 경로는 없다 — pod가 필요한 AUD는 ConfigMap `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`(비밀 아님) |
| `kv/{env}/dragonfly/acl` | `users.acl`(파일 전문) | `vault-{env}` | Dragonfly Deployment(`data` ns, `--aclfile /etc/dragonfly/users.acl`) |
| `kv/{env}/dragonfly/<user>` — `admin` · `identity-admin` · `<pod>` | `password`, `url` | `vault-{env}` | `<pod>-env`(`DRAGONFLY_URL`); `admin`은 운영자 런북 전용 |
| `kv/{env}/sentry/<pod>` | `dsn` | `vault-{env}` | `<pod>-env` |
| `kv/{env}/web/session` | `encryption_key` | ESO 밖 | BFF `SESSION_ENCRYPTION_KEY`(Worker마다 별도: prod Worker = prod, preview Worker = dev) |
| `kv/{env}/openfga/store_id` | `store_id` | `vault-{env}` | identity-admin `-env` |
| `kv/{env}/e2e` | `password`, `totp_seed`(Authentik 로컬 사용자 `e2e@joshuatech.dev`) | ESO 밖 | tester(Playwright) — 실행 시 env로만, 파일 저장 금지; storageState는 `e2e/.auth/`(gitignore, 실행 후 삭제) |

- gitops에는 `ExternalSecret`(경로·키 매핑)만. 값은 Vault UI/CLI로만 넣는다. 회전은 Vault 값 교체 → ESO `refreshInterval`(**5m**) 내 반영 → Reloader(`reloader.stakater.com/auto: "true"`) 롤아웃. 회전 매트릭스·캘린더는 런북 `secret-rotation.md`.
- 미결(R10 후속, contracts/gitops-repo.md 참조): `data`·`identity` ns가 소비하는 `kv/{env}/…` 경로(CNPG managed roles·KafkaUser·Dragonfly ACL·Authentik 웹훅 비밀)는 `vault-platform` 정책(`platform/*`) 밖이므로 store/role을 T044·T045 전에 확정한다.

## 9. AuthentikObject — 소유 identity (Blueprints, gitops `platform/authentik/blueprints/`)

| 객체 | SP-1 인스턴스 | 핵심 속성 |
|---|---|---|
| Source | `github`, `google` | OAuth 소셜 로그인. 이메일/비밀번호는 내장 |
| Stage/Flow | authentication(identification → password → MFA validation), recovery. **enrollment 흐름 없음(SP-2)** | MFA: TOTP·WebAuthn(passkey). identification `show_matched_user false`, password `failed_attempts_before_cancel 5`, Reputation 정책(-5) |
| Group | `tenant:<uuid>`(SP-1: `joshuatech` 테넌트의 UUID), `platform-admin`(WebAuthn 필수) | 정책 바인딩·RBAC 매핑. 그룹 이름에 slug를 쓰지 않는다 |
| User | `e2e@joshuatech.dev`(로컬 사용자, TOTP; 비밀은 `kv/{env}/e2e`), 서비스 계정 `identity-admin`(권한: 사용자 read · `authentik_core.delete_authenticatedsession` · 토큰 revoke; 토큰 → `kv/{env}/authentik/identity-admin.api_token`) | 운영자 개인 계정은 blueprint에 없다 |
| Application + Provider(OAuth2) | `web-bff`(confidential, PKCE, token exchange grant + RFC 8693 delegation, redirect **`https://joshuatech.dev/api/auth/callback`만**, access 300 s, refresh 30 d 회전), `web-bff-dev`(같은 설정, redirect `http://localhost:3000/api/auth/callback` · `https://preview.joshuatech.dev/api/auth/callback`), `identity-admin`(자기 signing key·JWKS, Federated Providers = [`web-bff`, `web-bff-dev`], `act` 클레임 발급), `argocd`·`vault`(OIDC, 그룹 클레임). `grafana` provider는 SP-2 | 각 provider의 `issuer` = `https://auth.joshuatech.dev/application/o/<slug>/`(공개 호스트, FR-046 예외 2) |
| ScopeMapping | `tenant_id`(UUID, `user.attributes.tenant_id` — identity-admin이 갱신하는 파생) | 모든 access/ID 토큰에 포함 |
| NotificationTransport + Rule | webhook(generic) → `http://identity-admin.jt-prod.svc/webhooks/authentik`(svc DNS, 공개 호스트 금지), 이벤트 `logout`·`login`·`model_deleted(session)`; 매핑 본문에 `pk`·`created` 포함 | 공유 비밀 헤더 `X-Authentik-Signature`(`webhook_secret`) |
| Outpost(proxy) | Django admin forward-auth(`admin.` 호스트) | SP-1은 identity-admin admin만 |
| Access(Cloudflare, 참고) | `auth.joshuatech.dev/if/admin`·`/api/v3`는 Access 앱 `auth-admin`(GitHub IdP) 뒤; `/application/o/*`·`/if/flow/*`·`/if/user/*`·`/.well-known/*`는 공개 | contracts/hostnames-and-access.md |

- Blueprints는 YAML 파일로 ConfigMap 마운트, `authentik_blueprints` 라벨로 자동 적용. 비밀 값은 `!Env`로 ExternalSecret에서 주입.
- 보존: Authentik events 90일(참고: Grafana 14일, Sentry 30일).

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

- store `jt-dev`, `jt-prod`(ID는 Vault `kv/{env}/openfga/store_id`). object id는 `tenant:<uuid>`. 튜플 `user:<sub> member tenant:<uuid>`는 §2 `TenantMembership`의 파생이며 identity-admin만 쓴다(SP-1 `seed_tenant`). SP-2 이후 `room#member`·`media#viewer` 같은 교차 관계가 추가되면 모델 파일 PR + CODEOWNERS. T077: 다른 테넌트 object에 대한 `check` → false.

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
Tenant 1 ── n TenantMembership(sub, tenant_id)   [identity_admin DB, 등급 B — 멤버십 정본]
Tenant.id ──값 참조──▶ 모든 pod A 등급 테이블.tenant_id (RLS 격리 키, UUID)
TenantMembership ──identity-admin이 갱신(SP-1 seed_tenant, SP-2 outbox)──▶ Authentik 그룹 tenant:<uuid>·attribute tenant_id · FgaStore 튜플(user member tenant:<uuid>)   [파생]
SessionRevocationLog(DB, 정본) ──기동·30 s 대조──▶ SessionRevocation(Dragonfly 캐시 revoked:sub·revoked:sid·denylist:epoch) ◀──조회── 모든 pod
SessionRevocationLog ──outbox──▶ identity-admin.session.revoked ──▶ insights(SP-3)
OutboxEvent(pod DB, 등급 B) ──릴레이(app role)──▶ KafkaTopic ──▶ 소비자 pod / <pod>.dlq
SecretPath(Vault) ──ESO(vault-platform·vault-dev·vault-prod)──▶ Secret ──▶ CNPG roles · pod env(<pod>-env / <pod>-migrate) · cloudflared · Alloy · Dragonfly ACL
SecretPath(Vault) ──운영자 복사(ESO 밖)──▶ Workers Secrets(web-bff·access/web-bff·web/session) · tester(e2e)
AuthentikObject(Provider) ──JWKS·act──▶ pod 인증 미들웨어 · BFF
ContentItem(git) ──packages/content──▶ web 빌드 · (SP-2) notes-sync ──▶ portfolio-core 메타
```
