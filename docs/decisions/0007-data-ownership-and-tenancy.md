---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0007: 데이터 소유·테넌시 — CNPG DB per pod·테이블 등급 A/B·FORCE RLS

<!-- 근거: spec D8·Key Entities(테이블 등급·Tenant·TenantMembership·Database/Role)·Assumptions(사용자당 테넌트 1)·§4(pod 템플릿·데이터)·§8 ADR 표, contracts/pod-template.md §테이블 등급·§런타임 계약(DB 연결·마이그레이션), data-model §1–3·§7(role·CONNECT 경계·RLS 정책 SQL·백업) -->

## Context and Problem Statement

pod 8개가 각자 데이터를 소유하되(헌법 III — 소유자·격리 키 명시), 노드 2대 RAM 예산 안에서 돌아야 한다. SP-1은 단일 테넌트(`joshuatech`)를 시드하지만 모든 계약은 multi-tenant-ready여야 하므로, 격리를 두 축으로 설계해야 한다: **pod 사이**(한 pod가 다른 pod의 DB에 붙지 못하게)와 **테넌트 사이**(쿼리 한 줄 실수가 교차 테넌트 유출이 되지 않게). 여기에 멤버십의 정본 위치(DB vs Authentik vs OpenFGA)와 재해 복구 방식을 함께 고정한다.

## Considered Options

- **CNPG 클러스터 1개 + pod별 database/role + tenant_id + FORCE RLS + SET LOCAL (채택)** — 단일 클러스터 RAM 예산 안에서 pod 격리(database·role)와 테넌트 격리(RLS)를 DB가 강제
- Neon — 서버리스 Postgres로 운영이 없지만 정본 데이터가 외부 SaaS에 놓이고 K3s·CNPG 운영 학습 목표와 어긋난다
- Supabase — 통합 스택이지만 RLS·인증 규율이 Supabase 방식에 종속되고 셀프호스트 무게가 CNPG보다 크다
- Cloudflare D1 — Workers와 결합이 좋지만 SQLite라 Django ORM·RLS·role 격리를 쓸 수 없다
- 스키마 분리(한 DB 안 스키마 per pod) — CONNECT 경계가 없어 pod 격리가 role 규율 하나에만 의존한다
- 앱 계층만(ORM 필터) — 쿼리 한 줄 실수 = 교차 테넌트 유출; DB가 아무것도 강제하지 않는다

## Decision Outcome

1. **CNPG `pg-main` 1개**(PG 18, 노드 B) + **pod별 database 독점**. pod 간 FK 금지 — 값 참조만. SP-1 database는 4개(`identity_admin`·`dev_identity_admin`·`authentik`·`openfga`)이고 나머지 pod DB는 각 pod feature가 추가한다(YAGNI).
2. **owner/app role 분리**: owner role은 `bypassrls: true`·마이그레이션·시드 전용(런타임 pod에 자격 없음 — `<pod>-migrate` ExternalSecret만), app role은 `LOGIN NOBYPASSRLS`·DML만(`statement_timeout 15s`). PG role은 클러스터 전역이므로 env마다 role·DB를 나눈다(dev는 `dev_` 접두). role의 CONNECT 경계는 CNPG `Database` CRD로 표현할 수 없어 **migrate Job 첫 단계의 멱등 SQL**(`REVOKE CONNECT … FROM PUBLIC; GRANT CONNECT … TO <db>_app, <db>_owner`)로 강제한다.
3. **테이블 등급 A/B**(FR-034): **A 테넌트 범위** = `TenantModel` 상속(`tenant_id` UUID NOT NULL) + `ENABLE`/`FORCE ROW LEVEL SECURITY` + `tenant_isolation` 정책 — 요청 트랜잭션 안 `SET LOCAL app.tenant_id`(`set_config(…, true)`) 컨텍스트로만 접근하고, 컨텍스트가 없으면 0행이다. **B pod 전역** = `GlobalModel`, RLS 미적용, **허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`만**(릴레이·웹훅·기동 재적용·`/tenants/me`가 app role로 읽는 경로). 허용 목록 추가는 계약 개정이 먼저고, `check_rls`가 두 등급의 위반(A에 FORCE RLS 누락, 목록 밖 RLS 없는 테이블)을 실패로 만든다.
4. **멤버십 정본 = identity-admin `TenantMembership`**(`(sub, tenant_id)` unique). Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`·OpenFGA 튜플은 identity-admin이 이 테이블 기준으로 갱신하는 **파생**이다(SP-1은 `seed_tenant`가 셋 다 쓴다). 테넌트 식별자는 어디서나 UUID이고 slug는 `Tenant.slug` 컬럼에만 둔다. 테넌트 컨텍스트가 없는 경로(Authentik 웹훅·관리자 revoke)의 `tenant_id`도 이 테이블을 `sub`로 조회해 얻는다(없으면 400).
5. **백업·복구 = barman-cloud** → OCI Object Storage `jt-backup`(매일 02:00 KST 베이스 백업 + WAL 아카이브, `archive_timeout 300`). **PITR은 클러스터 전체이며 재해 복구 전용**이다 — 단일 DB의 시점 복구는 side Cluster PITR → `pg_dump` → 복원 런북으로 우회한다.

### Consequences

- 좋음: pod 격리가 3겹(CONNECT 경계·role 권한·env 분리 role)이고 테넌트 격리를 DB가 강제하므로(FORCE RLS + owner만 bypass) 앱 코드 실수가 유출로 이어지지 않으며, RLS 예외가 등급 B 허용 목록으로 감사 가능하고, 단일 클러스터라 RAM 예산 안에서 pod 8개 DB를 수용한다. 멤버십 정본이 한 곳이라 Authentik·FGA 불일치는 재파생으로 수렴한다.
- 나쁨: 클러스터 1개 = 모든 pod가 같은 Postgres 장애 도메인을 공유하고(노드 B 장애 시 전 pod NotReady), PITR이 클러스터 전체라 단일 DB 복구는 우회 절차이며, 모든 요청이 트랜잭션 + `SET LOCAL` 규율(`TenantContextMiddleware`)을 지켜야 한다(`StreamingHttpResponse`는 DB 접근 금지).
- 위험 수용: SP-1의 복구는 백업 존재·런북까지고 restore-drill 실연은 SP-3다. 등급 B 테이블은 RLS가 없으므로 앱의 명시 필터(`/tenants/me`의 `sub`·`tenant_id`)가 유일한 경계다 — 허용 목록을 4개로 못박아 반경을 제한한다.
