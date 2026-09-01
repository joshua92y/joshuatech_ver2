# Data Model: 플랫폼 기반 (SP-1)

spec Key Entities의 상세. 헌법 III에 따라 엔티티마다 **소유자**(쓰기·마이그레이션 독점)와 **격리 키**를 적는다. SP-1은 단일 테넌트 `joshuatech`를 시드하지만 모든 계약은 `tenant_id`(UUID)를 가진다. 저장 위치는 넷이다: pod Postgres DB(CNPG `pg-main`), Dragonfly(휘발·TTL, 파생 캐시), git(모노레포·platform-gitops), 외부 시스템(Authentik·OpenFGA·Vault).

pod DB 테이블은 두 등급이다(contracts/pod-template.md §테이블 등급): **A 테넌트 범위**(`TenantModel`, `tenant_id` + FORCE RLS) / **B pod 전역**(RLS 미적용, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`). 테넌트 식별자는 어디서나 UUID — Authentik 그룹 `tenant:<uuid>`, claim `tenant_id`, FGA object `tenant:<uuid>`, Kafka 파티션 키 `tenantid`. slug는 `Tenant.slug` 컬럼에만 있다.

**엔티티 수는 14개**다: 아래 §1–§13 중 §3만 두 항목(`SessionRevocationLog` = DB 정본, `SessionRevocation` = Dragonfly 파생 캐시)을 담고 나머지 12개 절이 1개씩이다. spec Key Entities·plan Constitution Check III의 "14개"는 이 셈을 가리킨다.

## 1. Tenant — 소유 identity-admin (DB `identity_admin`, 등급 B)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. `tenant_id` = 자기 자신. **SP-1은 이 값을 고정 상수 1개로 못박는다** — `seed_tenant --tenant-id <uuid>`가 dev·prod·Authentik blueprint·FGA 튜플에 **같은 UUID**를 쓴다(멱등: 이미 있으면 갱신만). 환경마다 다른 UUID가 생기면 claim·그룹·FGA object가 어긋난다 |
| `slug` | text | unique, `^[a-z0-9][a-z0-9-]{1,30}$`, 불변. 표시·URL 용도만 — 다른 시스템의 식별자로 쓰지 않는다 |
| `display_name` | text | 1–80자 |
| `status` | enum `active` · `suspended` | 기본 `active` |
| `created_at` · `updated_at` | timestamptz | 서버 시각 |

- 멤버십 정본은 §2 `TenantMembership`. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`·OpenFGA `tenant:<uuid>#member`는 **identity-admin이 갱신하는 파생**이다(SP-1은 `seed_tenant` command가 셋 다 쓴다; SP-2부터 이벤트/API 경유). 모든 pod의 `tenant_id` 컬럼이 이 `id`를 참조(FK 없음 — pod 간 FK 금지, 값 참조만).
- **역할 분담**: Authentik **blueprint는 그룹 `tenant:<uuid>`의 껍데기만** 만든다. 사용자 소속(group membership)과 `user.attributes.tenant_id`는 **`seed_tenant`만** 쓴다 — blueprint와 command가 같은 필드를 서로 덮어쓰지 않게 하기 위해서다.
- 상태 전이: `active → suspended → active`. `suspended`면 identity-admin이 해당 테넌트 사용자 세션을 전부 폐기한다(SP-2).
- 시드: `seed_tenant --tenant-id <고정 uuid>`(slug `joshuatech`) → Tenant + TenantMembership 2건 + Authentik 그룹 소속·attribute + FGA 튜플. 여러 번 실행해도 결과가 같다(T066이 멱등성을 단언).
- 등급 B: RLS 없음. 사용자/테넌트 삭제·내보내기는 SP-2.

## 2. TenantMembership — 소유 identity-admin (등급 B, 멤버십 정본)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK |
| `tenant_id` | UUID | NOT NULL, `Tenant.id` 값 참조 |
| `sub` | text | Authentik `sub`(불변 식별자, 참조만). **`(sub, tenant_id)` unique** |
| `role` | enum `owner` · `admin` · `member` | **SP-1은 2건**: `owner`(운영자 계정) + `member`(E2E 로컬 사용자 `e2e@joshuatech.dev`). E2E 사용자에게 멤버십이 없으면 `/tenants/me`가 404가 되어 T085가 성립하지 않는다 |
| `created_at` | timestamptz | |

- 이 테이블이 **정본**이다. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`(ScopeMapping `tenant_id`의 원천)·OpenFGA 튜플 `user:<sub> member tenant:<uuid>`는 identity-admin이 이 테이블을 기준으로 갱신하는 파생(요청 안에서 DB와 외부 시스템을 동시에 쓰지 않는다 — SP-1 `seed_tenant`, SP-2 outbox 소비자).
- SP-1 가정: **사용자당 테넌트 1**(claim `tenant_id` 단일값). 다테넌트 선택은 SP-2.
- 등급 B: RLS 없음 — `/tenants/me`는 app role로 토큰의 `sub`·`tenant_id`를 명시 필터한다.
- **테넌트 컨텍스트가 없는 경로의 `tenant_id` 원천이 이 테이블이다.** Authentik 웹훅(`/webhooks/authentik`)과 관리자 revoke는 요청에 테넌트 컨텍스트가 없으므로 본문·본문 토큰의 `sub`로 여기를 조회해 `tenant_id`를 얻고(없으면 **400**), 그 값을 `publish(..., tenant_id=…)`에 명시적으로 넘긴다(contracts/events.md·identity-admin-api.md).

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

- **센티널 키 `denylist:epoch`는 없다(폐지).**
- 쓰기: 기록(INSERT)과 같은 트랜잭션에 outbox `identity-admin.session.revoked`; 커밋 후 Dragonfly SET. 등급 B이므로 app role이 컨텍스트 없이 쓴다.
- 재적용: 기동 시 1회 + Celery beat 30 s마다 `expires_at > now()` 행을 **조건 없이 전부** 다시 SET한다(멱등, 남은 TTL). 캐시 상태를 묻지 않는다. Kafka 재생은 쓰지 않는다.
- 유실 창: Dragonfly가 정상 종료하면 스냅샷으로 키가 살아남고, **비정상 종료**(OOM·SIGKILL·저장 실패)일 때만 최대 30 s 공백이 생긴다(contracts/denylist.md).
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

- 상태: `pending`(행 존재, `dead_at IS NULL`) → `published`(행 삭제) / `dead`(`attempts ≥ max_attempts 10` → 원본 봉투를 `<pod>.dlq`로 발행 + `dead_at`, 행 유지·수동 재처리) → **purge**(`dead_at + 30 d < now()`인 행을 일 1회 삭제 — outbox가 무한히 자라지 않게 하는 유일한 경로).
- 릴레이: relay 컨테이너가 **app role**로 `SELECT … WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100` → idempotent producer(key = `partition_key`, `delivery.timeout.ms` 30000) → 성공 시 DELETE. **dead 행은 다시 집지 않는다**(재발행 폭주 방지). 같은 트랜잭션에서 도메인 쓰기와 함께 INSERT되는 것만 유효하다(라이브러리가 `transaction.atomic()` 밖 INSERT를 `OutboxUsageError`로 거부).
- 쓰기 API: `publish(topic, subject, data, *, tenant_id=None)` — 생략하면 요청 테넌트 컨텍스트에서 읽고, **컨텍스트도 인자도 없으면 `OutboxUsageError`**. 확정된 값이 `partition_key`이자 봉투의 `tenantid`가 된다(contracts/events.md).
- 등급 B: RLS 미적용 — 릴레이가 모든 테넌트의 행을 읽는다. 지표 `outbox_pending`(`dead_at IS NULL`만)·`outbox_oldest_pending_seconds`·`outbox_dead_total`(relay 9464).

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
| role 이름 규칙 | **PG role은 클러스터 전역**이므로 env마다 role을 나눈다: prod `<pod_snake>_owner`·`<pod_snake>_app`, dev **`dev_<pod_snake>_owner`·`dev_<pod_snake>_app`**. SP-1의 `DatabaseRole`은 **4개**: `identity_admin_owner`·`identity_admin_app`·`dev_identity_admin_owner`·`dev_identity_admin_app`. 공유 컴포넌트 `authentik`·`openfga`는 pod가 아니라서 **env 접두가 없다**(role 이름 그대로) |
| owner role | 테이블 소유, 마이그레이션·시드 전용, `NOSUPERUSER NOCREATEDB NOCREATEROLE` + **`bypassrls: true`**(FORCE RLS를 우회하므로 owner 정책이 필요 없다). 런타임 pod에는 자격이 없다(`<pod>-migrate` ExternalSecret만) |
| app role | `LOGIN NOBYPASSRLS`, 테이블 비소유, `GRANT SELECT/INSERT/UPDATE/DELETE`만. `ALTER ROLE … SET statement_timeout = '15s'`, `idle_in_transaction_session_timeout = '30s'`. A 등급 테이블은 FORCE RLS 적용 대상, B 등급은 컨텍스트 없이 접근 |
| 접근 경계 | role은 자기 database에만 `CONNECT`. **CNPG `Database` CRD로는 표현할 수 없으므로** 각 database의 **migrate Job 첫 단계**에서 멱등 SQL로 강제한다: `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC; GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner;`(contracts/pod-template.md §마이그레이션). 이 SQL이 없으면 `dev_identity_admin_app`이 prod `identity_admin` DB에 붙을 수 있다 — T050이 그 거부를 단언한다 |
| TLS | 클라이언트는 `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`. CA Secret `pg-main-ca`는 ESO **kubernetes provider store `k8s-data-ca`** 로 `identity`·`jt-dev`·`jt-prod`에 미러하되 **`ca.crt` 속성만** 복사한다(T050: `pg_stat_ssl` 세션 ssl=true 단언, T031: 미러 Secret에 `ca.key` 부재). **`ca.key`를 함께 미러하면**(CNPG의 `<cluster>-ca` Secret에는 들어 있다) 그 키로 **서버 인증서를 위조해 `verify-full`을 무력화**하거나 **`streaming_replica` 클라이언트 인증서를 위조해 복제 스트림에 붙을 수 있다** — 기본 `pg_hba`가 임의 role의 cert 인증을 허용해서가 아니라(기본은 `host all all all scram-sha-256`이고 cert 행은 `streaming_replica`·pooler로 고정), CA 키 자체가 그 두 인증서를 만들 수 있기 때문이다. Authentik은 `AUTHENTIK_POSTGRESQL__SSLMODE=verify-full`·`AUTHENTIK_POSTGRESQL__SSLROOTCERT`(개별 env, `CONN_OPTIONS` 금지) |
| 비밀 | pod DB: Vault `kv/{env}/db/<role 접두>/{owner,app}` → ESO(`vault-data`로 CNPG `managed.roles[].passwordSecret`, `vault-{env}`로 pod env). 공유 컴포넌트 DB: **`kv/platform/db/{authentik,openfga}/owner`**(`vault-platform`) |
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

경로 규칙 `kv/{scope}/{component}/{name}`; scope ∈ `platform`(환경 무관) · `dev` · `prod`. ESO는 **5개 store**(`vault-platform`·`vault-dev`·`vault-prod`·`vault-data`·`k8s-data-ca`, contracts/gitops-repo.md §ExternalSecret 규약)로 읽는다. 같은 비밀을 두 네임스페이스가 쓰면 **store가 둘**이다(예: KafkaUser는 `data` ns에서 `vault-data`로, pod는 `jt-{env}`에서 `vault-{env}`로).

| 경로 | 키 | store | 소비자 |
|---|---|---|---|
| `kv/platform/cloudflare/dns-token` | `token` | `vault-platform` | cert-manager |
| `kv/platform/cloudflare/tunnel` | `token` | `vault-platform` | cloudflared |
| `kv/platform/grafana-cloud` | `metrics_url`, `logs_url`, `traces_url`, `token` | `vault-platform` | Alloy(`monitoring`) |
| `kv/platform/authentik` | `secret_key`, `bootstrap_password`, `bootstrap_token` | `vault-platform` | Authentik |
| `kv/platform/authentik/sources/github` · `kv/platform/authentik/sources/google` | `client_id`, `client_secret` | `vault-platform` | Authentik 소셜 로그인 소스 blueprint(env 무관, 앱 1개) |
| `kv/platform/authentik/e2e` | `password`, `totp_seed`(로컬 사용자 `e2e@joshuatech.dev`) | `vault-platform`(blueprint) · Vault role **`e2e-reader`**(tester) | Authentik blueprint가 사용자 생성에, tester(Playwright)가 로그인에 쓴다. tester는 실행 시 env로만 받고 파일에 저장하지 않는다; storageState는 `e2e/.auth/`(gitignore, 실행 후 삭제) |
| `kv/platform/db/authentik/owner` · `kv/platform/db/openfga/owner` | `username`, `password`, `url` | `vault-platform` | CNPG `DatabaseRole` passwordSecret(`data` ns) · Authentik/OpenFGA Deployment(`identity` ns) |
| `kv/platform/openfga/preshared` | `key` | `vault-platform` | OpenFGA 서버 `authn.preshared`(`identity` ns) |
| `kv/platform/oci/s3` | `access_key`, `secret_key`(IAM 사용자 `svc-s3-backup`, 버킷 `jt-backup`만) | `vault-platform` | CNPG barman-cloud |
| `kv/platform/vault-backup` | **없음** | — | Vault Raft 스냅샷은 kv 비밀 없이 수행한다: K8s auth role `vault-backup`(정책 `sys/storage/raft/snapshot` read, SA `vault-backup` ns `vault`) + 노드 A 인스턴스 프린시펄(동적 그룹 `jt-node-a`)이 `jt-backup-platform/vault/`에 업로드(`platform-backup.sh`, age 암호화). K3s 번들도 같은 버킷 `k3s/` |
| `kv/{env}/db/<role 접두>/owner` | `username`, `password`, `url` | `vault-data`(CNPG managed role) · `vault-{env}`(**`<pod>-migrate`**, migrate Job만) | `<role 접두>` = prod `identity_admin` / dev `dev_identity_admin` |
| `kv/{env}/db/<role 접두>/app` | `username`, `password`, `url`(`sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` 포함) | `vault-data` · `vault-{env}`(**`<pod>-env`**) | 같음 |
| `kv/{env}/kafka/<pod>` | `password` | `vault-data`(KafkaUser, `data` ns) · `vault-{env}`(`<pod>-env`) | |
| `kv/{env}/authentik/<pod>` | `client_id`, `client_secret`, `jwks_url`(**svc DNS**), `issuer`(공개 URL) | `vault-{env}` | `<pod>-env` |
| `kv/{env}/authentik/identity-admin` | 위 4개 + `api_token`(Authentik 서비스 계정 `identity-admin`: 사용자 read · `authentik_core.delete_authenticatedsession` · 토큰 revoke) | `vault-{env}` | identity-admin `-env`. **`webhook_secret`은 여기 두지 않는다**(아래 행) |
| `kv/{env}/authentik/webhooks/<pod>` | `secret`(HMAC 공유 비밀) | `vault-data`(Authentik NotificationTransport) · `vault-{env}`(`<pod>-env`) | pod·env마다 분리해 하나가 새도 나머지가 안전하다 |
| `kv/{env}/authentik/web-bff` | `client_id`, `client_secret`(prod = `web-bff`, dev = `web-bff-dev` provider) | ESO 밖 | BFF — Workers Secrets에만(`wrangler secret put`) |
| `kv/{env}/access/web-bff` | `client_id`, `client_secret`(Access 서비스 토큰 `web-bff-<env>`) | ESO 밖 | BFF — **Workers Secrets에만**. pod에는 배포하지 않는다. `kv/{env}/access/<pod>` 경로는 없다 — pod가 필요한 값은 ConfigMap `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ACCESS_EXPECTED_CN`(비밀 아님) |
| `kv/{env}/dragonfly/acl` | `users.acl`(파일 전문) | `vault-data` | Dragonfly Deployment(`data` ns, `--aclfile /etc/dragonfly/users.acl`) |
| `kv/{env}/dragonfly/<user>` — `admin` · `identity-admin` · `<pod>` | `password`, `url` | `vault-data`(`admin`) · `vault-{env}`(`<pod>-env`) | `DRAGONFLY_URL`; `admin`은 운영자 런북 전용 |
| `kv/{env}/sentry/<pod>` | `dsn` | `vault-{env}` | `<pod>-env` |
| `kv/{env}/web/session` | `encryption_key` | ESO 밖 | BFF `SESSION_ENCRYPTION_KEY`(Worker마다 별도: prod Worker = prod, preview Worker = dev) |
| `kv/{env}/openfga/store_id` · `kv/{env}/openfga/preshared` | `store_id` / `key` | `vault-{env}` | identity-admin `-env`. `preshared` 값은 `kv/platform/openfga/preshared`와 **같아야 하며** 회전 시 둘을 함께 바꾼다 |

- gitops에는 `ExternalSecret`(경로·키 매핑)만. 값은 Vault UI/CLI로만 넣는다. 회전은 Vault 값 교체 → ESO `refreshInterval`(**5m**) 내 반영 → Reloader(`reloader.stakater.com/auto: "true"`) 롤아웃. 회전 매트릭스·캘린더는 런북 `secret-rotation.md`.
- **`vault-data` role 정책은 열거 경로만** 연다: `kv/data/{dev,prod}/{db,kafka,dragonfly,openfga}/*` + `kv/data/{dev,prod}/authentik/webhooks/*`(+ 같은 `kv/metadata/…`). `data`·`identity` ns가 `kv/{env}/*` 전체를 볼 수 없다 — 새 경로가 필요하면 이 표와 Vault 정책을 함께 고친다(T044·T045).
- **CA 미러는 kv가 아니다**: `pg-main-ca`·`jt-kafka-cluster-ca-cert`는 store `k8s-data-ca`(kubernetes provider, `remoteNamespace: data`)로 복사하며 `remoteRef.property: ca.crt`만 쓴다(§7 TLS).

## 9. AuthentikObject — 소유 identity (Blueprints, gitops `platform/authentik/blueprints/`)

| 객체 | SP-1 인스턴스 | 핵심 속성 |
|---|---|---|
| Source | `github`, `google` | OAuth 소셜 로그인(비밀은 `kv/platform/authentik/sources/<name>`). 이메일/비밀번호는 내장 |
| Stage/Flow | authentication(identification → password → MFA validation), recovery. **enrollment 흐름 없음(SP-2)** | MFA: TOTP·WebAuthn(passkey). identification `show_matched_user false`, password `failed_attempts_before_cancel 5`, Reputation 정책(-5) |
| Group | `tenant:<uuid>`(SP-1: 고정 테넌트 UUID), `platform-admin`(WebAuthn 필수) | 정책 바인딩·RBAC 매핑. 그룹 이름에 slug를 쓰지 않는다. **blueprint는 그룹 껍데기만 만들고**, 사용자 소속과 `user.attributes.tenant_id`는 `seed_tenant`만 쓴다(§1) |
| User | `e2e@joshuatech.dev`(로컬 사용자, TOTP; 비밀은 **`kv/platform/authentik/e2e`**), 서비스 계정 `identity-admin`(권한: 사용자 read · `authentik_core.delete_authenticatedsession` · 토큰 revoke; 토큰 → `kv/{env}/authentik/identity-admin.api_token`). **dev용 서비스 계정 토큰은 읽기 전용**(dev에서 prod 세션을 건드릴 수 없게) | 운영자 개인 계정은 blueprint에 없다 |
| Application + Provider(OAuth2) | `web-bff`(confidential, PKCE, **token exchange grant — SP-1은 impersonation**, redirect **`https://joshuatech.dev/api/auth/callback`만**, access 300 s, refresh 30 d 회전), `web-bff-dev`(같은 설정, redirect `http://localhost:3000/api/auth/callback` · `https://preview.joshuatech.dev/api/auth/callback`), `identity-admin`(자기 signing key·JWKS, Federated Providers = [`web-bff`, `web-bff-dev`]; **`act` 클레임은 VD-1이 옵션 A로 확정될 때만** 발급된다 — OSS에는 `Actor` 생성 경로가 없어 기본은 impersonation), `argocd`·`vault`(OIDC, 그룹 클레임). `grafana` provider는 SP-2 | 각 provider의 `issuer` = `https://auth.joshuatech.dev/application/o/<slug>/`(공개 호스트). **JWKS는 pod가 svc DNS로 읽는다**(`http://authentik-server.identity.svc:9000/application/o/<slug>/jwks/`); FR-046 예외 2(공개 호스트 사용)는 Argo CD·Vault OIDC discovery로 한정 |
| ScopeMapping | `tenant_id`(UUID) — **원천은 `user.attributes.tenant_id`**(identity-admin이 갱신하는 파생). 그룹 `tenant:<uuid>`는 RBAC·정책 바인딩 용도이고 클레임 원천이 아니다 | 모든 access/ID 토큰에 포함 |
| NotificationTransport + Rule | webhook(generic) **2개**: prod → `http://identity-admin.jt-prod.svc/webhooks/authentik`, dev → `http://identity-admin.jt-dev.svc/webhooks/authentik`(둘 다 svc DNS, 공개 호스트 금지). 이벤트 `logout`·`login`·`model_deleted(session)`; 매핑 본문에 `pk`·`created` 포함 | 공유 비밀 헤더 `X-Authentik-Signature`, 값은 **`kv/{env}/authentik/webhooks/identity-admin`**. NetworkPolicy에 `identity → jt-dev:8000` 행이 있어야 dev 웹훅이 도달한다 |
| Outpost(proxy) | Django admin forward-auth(`admin.` 호스트) | SP-1은 identity-admin admin만(prod). dev는 `ADMIN_HOST`가 빈 값이라 admin 표면이 없다 |
| Access(Cloudflare, 참고) | `auth.joshuatech.dev/if/admin/*`만 Access 앱 `auth-admin`(GitHub IdP) 뒤; `/application/o/*`·`/if/flow/*`·`/if/user/*`·`/.well-known/*`·**`/api/v3/*`** 는 공개(로그인 SPA가 브라우저에서 `/api/v3`를 부른다) | 보상 통제·SP-2 검토 항목은 contracts/hostnames-and-access.md |

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

- 관계는 **포함 관계**다: `owner ⊂ admin ⊂ member` — `owner`인 사용자는 `member` check도 true다. `/tenants/me`·FGA `check`가 이 정의에 기댄다.
- store `jt-dev`, `jt-prod`(ID는 Vault `kv/{env}/openfga/store_id`, 서버 인증은 `kv/{env}/openfga/preshared`; 둘 다 identity-admin `<pod>-env`). object id는 `tenant:<uuid>`. 튜플 `user:<sub> member tenant:<uuid>`는 §2 `TenantMembership`의 파생이며 identity-admin만 쓴다(SP-1 `seed_tenant`). SP-2 이후 `room#member`·`media#viewer` 같은 교차 관계가 추가되면 모델 파일 PR + CODEOWNERS.
- 검증: **T078**(`tests/platform/identity.tests.ps1`) — 다른 테넌트 object에 대한 `check` → false. 자격이 필요한 `fga` 호출은 `platform/policies/tests/`의 Job `authz-assert`가 실행하고 tester는 로그만 읽는다(contracts/hostnames-and-access.md).

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
SessionRevocationLog(DB, 정본) ──기동 1회 + 30 s 무조건 재적용──▶ SessionRevocation(Dragonfly 캐시 revoked:sub·revoked:sid) ◀──조회── 모든 pod
SessionRevocationLog ──outbox──▶ identity-admin.session.revoked ──▶ insights(SP-3)
OutboxEvent(pod DB, 등급 B) ──릴레이(app role, dead_at IS NULL)──▶ KafkaTopic ──▶ 소비자 pod / <pod>.dlq ──dead_at+30d──▶ purge
SecretPath(Vault) ──ESO(vault-platform·vault-dev·vault-prod·vault-data)──▶ Secret ──▶ CNPG roles · pod env(<pod>-env / <pod>-migrate) · cloudflared · Alloy · Dragonfly ACL · Authentik 웹훅
CNPG/Strimzi CA Secret(data ns) ──ESO(k8s-data-ca, ca.crt만)──▶ identity · jt-dev · jt-prod
SecretPath(Vault) ──운영자 복사(ESO 밖)──▶ Workers Secrets(web-bff·access/web-bff·web/session); Vault role e2e-reader ──▶ tester(kv/platform/authentik/e2e)
AuthentikObject(Provider) ──JWKS(svc DNS)──▶ pod 인증 미들웨어 · BFF(호출자 식별은 Access common_name)
ContentItem(git) ──packages/content──▶ web 빌드 · (SP-2) notes-sync ──▶ portfolio-core 메타
```
