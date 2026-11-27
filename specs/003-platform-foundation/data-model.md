# Data Model: 플랫폼 기반 (SP-1)

spec Key Entities의 상세. 헌법 III에 따라 엔티티마다 **소유자**(쓰기·마이그레이션 독점)와 **격리 키**를 적는다. SP-1은 단일 테넌트 `joshuatech`를 시드하지만 모든 계약은 `tenant_id`(UUID)를 가진다. 저장 위치는 넷이다: pod Postgres DB(CNPG `pg-main`), Dragonfly(휘발·TTL, 파생 캐시), git(모노레포·platform-gitops), 외부 시스템(Authentik·OpenFGA·Vault).

pod DB 테이블은 두 등급이다(contracts/pod-template.md §테이블 등급): **A 테넌트 범위**(`TenantModel`, `tenant_id` + FORCE RLS) / **B pod 전역**(RLS 미적용, 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`). 테넌트 식별자는 어디서나 UUID — Authentik 그룹 `tenant:<uuid>`, claim `tenant_id`, FGA object `tenant:<uuid>`, Kafka 파티션 키 `tenantid`. slug는 `Tenant.slug` 컬럼에만 있다.

**엔티티 수는 14개**다: 아래 §1–§13 중 §3만 두 항목(`SessionRevocationLog` = DB 정본, `SessionRevocation` = Dragonfly 파생 캐시)을 담고 나머지 12개 절이 1개씩이다. spec Key Entities·plan Constitution Check III의 "14개"는 이 셈을 가리킨다. 세션 하한 키 둘(사용자 단위 · 세션 단위 — UD-7a 보정 2026-11-24)은 §3 `SessionRevocation`(파생 캐시)의 키 두 줄이라 엔티티 수는 그대로다(T073 보정 2026-11-12).

## 1. Tenant — 소유 identity-admin (DB `identity_admin`, 등급 B)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. 값을 주지 않으면 DB가 만든다(`uuidv7()` — Django 6.1 `UUID7()` `db_default` · PostgreSQL 18 · T073 보정 2026-11-12). `tenant_id` = 자기 자신. **SP-1은 이 값을 고정 상수 1개로 못박는다** — `seed_tenant --tenant-id <uuid>`가 dev·prod·Authentik blueprint·FGA 튜플에 **같은 UUID**를 쓴다(멱등: 이미 있으면 갱신만). 환경마다 다른 UUID가 생기면 claim·그룹·FGA object가 어긋난다. SP-1 고정 테넌트 UUID = `01a1cec4-ecef-77fe-839d-5af5a01a211f`(UUID v7 · 한 번 정하면 바꾸지 않는다 — T081 그룹 이름 `tenant:<uuid>` · T083 `seed_tenant` 인자 · T085 단언이 이 줄의 값을 읽는다 · 코드에는 넣지 않는다 · T073 보정 2026-11-12) |
| `slug` | text | unique, `^[a-z0-9][a-z0-9-]{1,30}$`, 불변. 표시·URL 용도만 — 다른 시스템의 식별자로 쓰지 않는다 |
| `display_name` | text | 1–80자 |
| `status` | enum `active` · `suspended` | 기본 `active` |
| `created_at` · `updated_at` | timestamptz | DB 기본값(`db_default=Now()` — 문장 시작 시각). SP-1에는 Tenant를 갱신하는 경로가 없어 `updated_at`은 생성 시각 그대로다(갱신 경로는 SP-2 · T073 보정 2026-11-12) |

- 멤버십 정본은 §2 `TenantMembership`. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`·OpenFGA `tenant:<uuid>#member`는 **identity-admin이 갱신하는 파생**이다(SP-1은 `seed_tenant` command가 셋 다 쓴다; SP-2부터 이벤트/API 경유). 모든 pod의 `tenant_id` 컬럼이 이 `id`를 참조(FK 없음 — pod 간 FK 금지, 값 참조만).
- **역할 분담**: Authentik **blueprint는 그룹 `tenant:<uuid>`의 껍데기만** 만든다. 사용자 소속(group membership)과 `user.attributes.tenant_id`는 **`seed_tenant`만** 쓴다 — blueprint와 command가 같은 필드를 서로 덮어쓰지 않게 하기 위해서다.
- 상태 전이: `active → suspended → active`. `suspended`면 identity-admin이 해당 테넌트 사용자 세션을 전부 폐기한다(SP-2).
- 시드: `seed_tenant --tenant-id <고정 uuid> --owner-sub <sub> --member-sub <sub>`(slug `joshuatech` · display_name 기본 `JoshuaTech` · `sub` 두 개는 인자로 받는다 — Authentik 사용자 조회로 유추하지 않는다 · T066 보정 2026-11-03) → Tenant + TenantMembership 2건(`owner` · `member`) + Authentik 그룹 `tenant:<uuid>` 소속·`user.attributes.tenant_id`(사용자별 PATCH) + FGA 튜플 `user:<sub> owner|member tenant:<uuid>`. 여러 번 실행해도 결과가 같다(T066이 멱등성을 단언): DB 행 수·id 불변, 파생 쓰기는 "이미 같은 상태면 쓰지 않음"으로 처리하고 실패하지 않는다. Authentik·FGA 호출은 설정의 base URL(**svc DNS 기본값** `http://authentik-server.identity.svc:9000` · `http://openfga.identity.svc:8080`)로만 간다. **파생 쓰기 규칙(T066 보정 2026-11-03 · API 모양은 VD-T066-1·2 — T081·T082·T083 실측)**:
  - 순서는 DB(정본) → 파생(쓰기의 순서다 — 그룹 이름 조회(읽기)는 DB 앞에 온다 · 아래 · T073 보정 2026-11-12). 파생이 실패하면 명령이 실패(`CommandError` · 0이 아닌 종료)하고 DB 행은 남는다 — 다시 실행하면 멱등하게 마저 쓴다.
  - Authentik: 그룹 `tenant:<uuid>`는 **blueprint가 이미 만들어 두었어야 한다** — 이름으로 조회(`GET /api/v3/core/groups/?name=`)해 없으면 실패하고 **만들지 않는다**(그룹 껍데기는 blueprint의 몫). 사용자는 `sub` = Authentik 사용자 UUID(provider `sub_mode` = `user_uuid` — §9)로 조회(`GET /api/v3/core/users/?uuid=<sub>`)하고 없으면 실패(그룹·사용자 조회는 읽기라 `AUTHENTIK_WRITES_ENABLED`와 무관하게 늘 한다 — 쓰기를 끈 dev 시드도 그룹·사용자가 없으면 실패 · T066 r1 보정). 소속은 `POST /api/v3/core/groups/<그룹 pk>/add_user/` `{ "pk": <사용자 pk> }`, attribute는 기존 `attributes`를 읽어 **`tenant_id` 키만 더한 사전 전체**를 `PATCH /api/v3/core/users/<pk>/`로 보낸다(PATCH는 `attributes`를 통째로 바꾼다 — 다른 키를 지우지 않게). `AUTHENTIK_WRITES_ENABLED=false`(dev)면 Authentik 쓰기(소속·PATCH)를 하지 않고 로그만 남긴다(Authentik은 dev·prod가 한 인스턴스라 prod 시드가 이미 쓴다 · dev 토큰은 read 전용).
  - OpenFGA(env마다 store가 다르다 — dev도 쓴다): `POST /stores/<store_id>/write` `{ "writes": { "tuple_keys": [...] } }` + `Authorization: Bearer <preshared>`. 이미 있는 튜플은 미리 읽어 건너뛰거나(`POST /stores/<id>/read`) `on_duplicate: "ignore"`를 쓰거나, 중복 쓰기 400 `write_failed_due_to_invalid_input`(메시지 "already exists")만 성공으로 본다 — **그 밖의 400·5xx는 실패**(삼키지 않는다). 마지막 방식은 **튜플마다 따로 쓸 때만** 성립한다 — 한 요청의 일괄 쓰기는 원자적이라 튜플 하나가 중복이면 나머지도 쓰이지 않으므로, 일괄 쓰기의 중복 400을 성공으로 보면 빠진 튜플을 놓친다(T066 r1 보정 · VD-T066-2).
  - slug `joshuatech`가 다른 id로 이미 있으면 실패(새 행을 만들지 않는다). 명령 출력(stdout·stderr)에 토큰·키 값이 나오지 않는다.
  - **세부(T073 보정 2026-11-12)**: `--tenant-id`는 UUID v7이어야 하고 소문자 정규형으로 쓴다. `--owner-sub` · `--member-sub`는 Authentik 사용자 uuid의 소문자 정규형(8-4-4-4-12 · `user_uuid` sub 모드 — §9)이고 서로 달라야 한다(어기면 `CommandError` · T073 보정 2026-11-16 — 이전 문구 「출력 가능 ASCII 1–255자」: 대문자 · 숫자 pk · username은 사용자 조회에서 반드시 실패하는데 그 판정이 DB 커밋 뒤라 남은 멤버십 행을 명령이 지우지 못한다 · 폐기 경로의 `sub` 문자 규칙은 그대로다). 순서는 ① 그룹 `tenant:<uuid>` 이름 조회(읽기 — 없으면 DB를 쓰지 않고 실패한다) ② DB(한 트랜잭션) ③ 사용자 조회 ④ Authentik 쓰기 ⑤ OpenFGA 쓰기다. DB 단계: Tenant가 그 id로 이미 있으면 slug가 `joshuatech`이어야 하고 기존 `display_name` · `status`는 건드리지 않는다. 멤버십이 이미 있는데 role이 인자와 다르면 `CommandError`다(바꾸지 않는다 — SP-1에는 역할 변경 경로가 없고, role을 내리면 OpenFGA에 옛 관계가 남는다 · 위 「이미 있으면 갱신만」은 행을 다시 만들지 않는다는 뜻이다). Authentik: 소속은 사용자 `groups`에 그룹 pk가 없을 때만 더하고 attribute는 `tenant_id`가 없을 때만 쓴다. 다른 `tenant_id`가 이미 있으면 쓰기 플래그와 무관하게 `CommandError`다(사용자를 조용히 다른 테넌트로 옮기지 않는다). 쓰기를 끈 실행도 소속 · attribute를 비교해 어긋난 항목 수를 출력한다. OpenFGA는 `on_duplicate: "ignore"` 일괄 쓰기 한 번이다. 성공 출력은 `seed_tenant:`로 시작하는 줄 하나 `seed_tenant: OK env=<env> tenant=<uuid> memberships=created:<n>/unchanged:<n> authentik=written|unchanged|skipped(drift=<n>) fga=ok`이고 `sub` · 토큰 · URL을 싣지 않는다(`env`는 그 프로세스의 `ENV` 설정 — `revoke_sessions`와 같은 까닭 · prod 시드는 `written`(첫 실행) · `unchanged`(재실행)여야 하고 prod의 `skipped`는 쓰기 플래그가 참이 아니라는 뜻이다 · T073 보정 2026-11-16 — 이전 꼴에는 `env=`가 없었다). 자격이 자리값(`PLACEHOLDER-` 포함)이면 `CommandError`다. DB를 쓰기 전에 끝나는 갈래가 넷 더 있다(T073 보정 2026-11-16): `OPENFGA_STORE_ID`가 꼴(`[A-Za-z0-9_-]{1,64}`)이 아니다 · 찾은 그룹의 `is_superuser`가 거짓이 아니다(키 없음 포함) · `--authentik-token-stdin`인데 표준 입력이 터미널이다(토큰이 화면에 찍힌다 — 파이프로 넣는다) · 그 프로세스에 `ENV` 설정이 없다(migrate 프로필 등 — 출력 줄의 `env`를 채울 수 없다 · `revoke_sessions`와 같다). 인자(`sub` · role 순서 · 테넌트)가 틀려 남은 행과 파생은 명령이 지우지 않는다 — 운영자 런북(T114)으로 지운다(재실행이 마저 쓰는 것은 일시 오류로 멈춘 실행뿐이다). 일시 오류는 Authentik · OpenFGA 호출 모두 429 · 5xx · 연결 · 시간 초과 · 마감만 일시다(`contracts/identity-admin-api.md` §타임아웃 · 재시도의 Authentik 정의를 OpenFGA 시드 호출에도 쓴다 — 그 밖(4xx · 3xx · 응답 꼴 오류 · 사용자를 찾지 못함 · 여럿 · attribute 충돌 등)은 다시 돌아도 같은 자리에서 멈추고, 실패 문구의 끝이 둘을 가른다 · DB를 쓰기 전의 실패는 일시 여부와 무관하게 「DB는 쓰지 않았다」로 끝난다(① 그룹 조회 단계 — 호출 실패 · 찾지 못함 · 여럿 · pk 꼴 · superuser 그룹 · ① 앞의 거부(인자 · stdin 토큰 · 자리값 · store id 꼴 · 바깥 트랜잭션 · `ENV` 없음)는 이 꼬리 없이 끝나고 아무것도 쓰지 않는다) · T073 보정 2026-11-16). 실행은 운영자 `kubectl exec`(web 컨테이너 · runtime 프로필 · app role — B 등급 테이블과 런타임 설정이 필요하다 · Job을 두지 않는다)이고 prod를 먼저 돈다(Authentik attribute는 prod 시드만 쓴다). 선택 인자 `--authentik-token-stdin`은 Authentik 호출에 설정의 장기 토큰 대신 표준 입력 한 줄의 토큰을 쓴다(prod 시드를 운영자 만료 토큰으로 돌릴 때 — 서비스 계정 권한의 확정은 T081 전 사용자 결정). `platform-admin` 그룹은 건드리지 않는다.
- 등급 B: RLS 없음. 사용자/테넌트 삭제·내보내기는 SP-2.

## 2. TenantMembership — 소유 identity-admin (등급 B, 멤버십 정본)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. 값을 주지 않으면 DB가 만든다(`uuidv7()` — Django 6.1 `UUID7()` `db_default` · PostgreSQL 18 · T073 보정 2026-11-12). |
| `tenant_id` | UUID | NOT NULL, `Tenant.id` 값 참조 |
| `sub` | text | Authentik `sub`(불변 식별자, 참조만). **`(sub, tenant_id)` unique** |
| `role` | enum `owner` · `member`(`admin` 값은 **SP-2 예약** — SP-1 enum에 넣지 않는다) | **SP-1은 2건**: `owner`(운영자 계정) + `member`(E2E 로컬 사용자 `e2e@joshuatech.dev`). E2E 사용자에게 멤버십이 없으면 `/tenants/me`가 404가 되어 T085가 성립하지 않는다 |
| `created_at` | timestamptz | DB 기본값(`db_default=Now()` · T073 보정 2026-11-12) |

- 이 테이블이 **정본**이다. Authentik 그룹 `tenant:<uuid>`·`user.attributes.tenant_id`(ScopeMapping `tenant_id`의 원천)·OpenFGA 튜플 `user:<sub> member tenant:<uuid>`는 identity-admin이 이 테이블을 기준으로 갱신하는 파생(요청 안에서 DB와 외부 시스템을 동시에 쓰지 않는다 — SP-1 `seed_tenant`, SP-2 outbox 소비자).
- SP-1 가정: **사용자당 테넌트 1**(claim `tenant_id` 단일값). 다테넌트 선택은 SP-2.
- 등급 B: RLS 없음 — `/tenants/me`는 app role로 토큰의 `sub`·`tenant_id`를 명시 필터한다.
- **테넌트 컨텍스트가 없는 경로의 `tenant_id` 원천이 이 테이블이다.** Authentik 웹훅(`/webhooks/authentik`)과 관리자 revoke는 요청에 테넌트 컨텍스트가 없으므로 본문·본문 토큰의 `sub`로 여기를 조회해 `tenant_id`를 얻고(없으면 **400**), 그 값을 `publish(..., tenant_id=…)`에 명시적으로 넘긴다(contracts/events.md·identity-admin-api.md). (다중 멤버십 · 관리 명령 `revoke_sessions`의 규칙은 contracts/identity-admin-api.md · T073 보정 2026-11-12)

## 3. SessionRevocationLog(정본, DB) · SessionRevocation(Dragonfly 파생 캐시) — 소유 identity-admin

DB 테이블 `session_revocation_log`(등급 B, `sub` 단위):

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | UUID v7 | PK. 값을 주지 않으면 DB가 만든다(`uuidv7()` — Django 6.1 `UUID7()` `db_default` · PostgreSQL 18 · T073 보정 2026-11-12). |
| `tenant_id` | UUID | NOT NULL(사용자의 테넌트; 사용자당 테넌트 1) · `Tenant.id` 값 참조(FK 없음 — §1 · T066 r1 보정) |
| `sub` | text | NOT NULL |
| `sid` | text | nullable — **NULL = 사용자 단위 폐기**(`revoked:sub:{sub}`), 값 = 세션 단위 폐기(`revoked:sid:{sid}` + 세션 단위 하한 — UD-7a 보정 2026-11-24) · 아래 "한 행 = 한 키" |
| `reason` | enum `logout` · `logout_all` · `admin` · `authentik_webhook` · `tenant_suspended` | |
| `nbf` | timestamptz | 거부 기준 시각(정수 초 — 처리 시각 epoch 초 내림 + 1, 웹훅 본문 `nbf`가 있으면 그 값 · contracts/identity-admin-api.md). 일 1회 대조 보정은 이벤트 `created` 내림 + 1이다. 미래 값은 경로마다 쓰기 전에 막는다 — 웹훅 본문 `nbf`가 이벤트 `created` 내림 + 1을 넘으면 그 값으로 낮춰 기록하고(거부하지 않는다 — contracts/identity-admin-api.md), 관리 명령 `revoke_sessions`는 `nbf > DB now() + 301 s`면 기록하지 않는다(`CommandError`). `/sessions/revoke`의 `nbf`는 서버가 정한다(T073 보정 2026-11-12) |
| `expires_at` | timestamptz | `nbf` + 330 s(access TTL 300 s + 30 s) |
| `event_pk` | text | nullable · **unique** — Authentik 이벤트 `pk`(멱등 키 · 재전송은 이 제약으로 200 no-op · UUID로 읽히면 대시 소문자 정규형으로 저장한다). 웹훅 행과 일 1회 대조 보정 행만 값이 있다(T066 보정 2026-11-03 · T073 보정 2026-11-12) |
| `created_at` | timestamptz | DB 기본값(`db_default=Now()` · T073 보정 2026-11-12) |

Dragonfly 키(파생 캐시, contracts/denylist.md가 정본):

| 키 | 값 | TTL |
|---|---|---|
| `revoked:sub:{sub}` | epoch 초 `nbf` — `iat < nbf`인 토큰 거부(전체 기기·관리자·테넌트 정지) | 330 s |
| `revoked:sid:{sid}` | epoch 초 `nbf` — `iat < nbf`인 그 세션 토큰 거부(단일 기기 · UD-7a 보정 2026-11-24 — 이전 값 `1`) | 330 s |
| `identity-admin:session-floor:{sub}` | 그 `sub`의 사용자 단위 행 가운데 가장 큰 `nbf`(epoch 초) — 세션 시작 시각 < 값인 BFF 세션은 inactive(`/session/check`만 읽는다 · T073 보정 2026-11-12) | 그 행 `expires_at + 30 d`까지 |
| `identity-admin:sid-floor:{sid}` | 그 `sid` 행 가운데 가장 큰 `nbf`(epoch 초) — 세션 시작 시각 < 값이고 `sid`가 같은 BFF 세션은 inactive(`/session/check`만 읽는다 · UD-7a 보정 2026-11-24) | 그 행 `expires_at + 30 d`까지 |
| `identity-admin:denylist:reapplied-at` | 마지막 재적용 시각(epoch 초) — 재적용 생존 신호(T073 보정 2026-11-12) | 300 s |

- 값 꼴(UD-7a 보정 2026-11-24): `revoked:sub` · `revoked:sid` · 두 하한의 값은 epoch 초를 쓴 ASCII 숫자 1–19자(정규 꼴)이고, 꼴 밖의 값은 조회 실패(503)다 — 판독의 정본은 contracts/denylist.md §조회 규약 2(두 하한은 §조회 규약 7).
- **센티널 키 `denylist:epoch`는 없다(폐지).**
- **한 행 = 한 키(T066 보정 2026-11-03)**: `sid`가 NULL인 행은 `revoked:sub:{sub}` = `nbf`(epoch 초), `sid`가 있는 행은 `revoked:sid:{sid}` = `nbf`와 세션 단위 하한 키(UD-7a 보정 2026-11-24). `/sessions/revoke` `all_devices: true`·관리자 폐기·**Authentik 웹훅**은 `sid` NULL 행(웹훅 본문의 `sid`는 쓰지 않는다 — 이벤트 문맥이 토큰 `sid` 클레임과 같다는 보장이 없어 사용자 단위로 fail-safe), 단일 기기 로그아웃(`all_devices: false`)만 `sid` 행이다. 재적용은 이 규칙으로 키를 다시 만든다(행만 보고 키가 정해진다). 사용자 단위 행(`sid` NULL)은 그 밖에 세션 하한 키 `identity-admin:session-floor:{sub}`를 만든다 — 값은 같은 `sub`의 사용자 단위 행 가운데 가장 큰 `nbf`다(contracts/denylist.md §키 스키마). `revoked:*`는 그대로 한 행 = 한 키다. 일 1회 대조 보정 행과 관리 명령 `revoke_sessions`의 행도 같은 규칙이다(T073 보정 2026-11-12).
- 쓰기: 기록(INSERT)과 같은 트랜잭션에 outbox `identity-admin.session.revoked`(data `sid`는 행의 `sid` — 사용자 단위면 `null`); 커밋 후 Dragonfly SET(`revoked:*` TTL = `min(330, 남은 초)` · 하한 키 TTL = 그 행 `expires_at + 30 d`까지 · 1 미만이면 쓰지 않는다 · `sid` 행은 자기 행 값으로 `revoked:sid`와 세션 단위 하한 키를 함께 쓴다(UD-7a 보정 2026-11-24) · 사용자 단위 행은 그 `sub`의 최댓값 행을 읽어 `revoked:sub`와 세션 하한 키를 함께 쓴다 — contracts/denylist.md §쓰기 규약 · T073 보정 2026-11-12). 등급 B이므로 app role이 컨텍스트 없이 쓴다.
- 재적용: 기동 시 1회(Celery `beat_init` — contracts/identity-admin-api.md §주기 작업) + Celery beat 30 s마다 `expires_at > now()` 행을 **조건 없이 전부** 다시 SET한다(멱등, 남은 TTL = `expires_at - now()` 초 내림 — TTL을 330 s로 되돌리지 않는다). 캐시 상태를 묻지 않는다(이미 있는 키도 덮어쓴다). Kafka 재생은 쓰지 않는다. 같은 키의 행이 여럿이면 `nbf`가 가장 큰 행을 쓰고 TTL 1초 미만은 건너뛴다. 같은 실행이 `sid` NULL이고 `expires_at + 30 d > now()`인 행으로 세션 하한 키를 되살리고 신선도 키를 쓴다(T073 보정 2026-11-12). 같은 실행이 `sid`가 있고 `expires_at + 30 d > now()`인 행으로 세션 단위 하한 키를 되살린다 · `revoked:sid` 값은 행의 `nbf`(UD-7a 보정 2026-11-24).
- 유실 창: Dragonfly가 정상 종료하면 스냅샷으로 키가 살아남고, **비정상 종료**(OOM·SIGKILL·저장 실패)일 때만 공백이 생기고 그 길이의 상한은 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속이다(contracts/denylist.md). 세션 하한도 같은 창이다 — 재적용이 돌아오면 다음 확인에서 다시 inactive가 된다(contracts/denylist.md · T073 보정 2026-11-12).
- 보존: `expires_at + 30 d` 지난 행을 일 1회 purge(구현 식 `expires_at < now() − 30 d`). 이 30일이 세션 하한 수명이자 `/session/check`의 세션 절대 수명이다(상수 하나 — T073 보정 2026-11-12).
- 상태: `recorded`(캐시 키 존재) → `expired`(`revoked:*` TTL 만료 — 사용자 단위 행은 사용자 단위 하한, `sid` 행은 세션 단위 하한 키만 남는다 · UD-7a 보정 2026-11-24) → purge(하한도 끝난다 · T073 보정 2026-11-12).
- 제약 · 인덱스(T073 보정 2026-11-12): unique `srl_event_pk_uniq`(`event_pk`) · check `srl_reason_valid` · 인덱스 `srl_expires_at_idx`(`expires_at` — 재적용 · purge) · 부분 인덱스 `srl_user_floor_idx` = `(sub, nbf DESC) WHERE sid IS NULL`(세션 하한의 `sub`별 최댓값). 마이그레이션은 pod 앱 `identity_admin`의 `0001_initial` 하나다(§1–§3의 세 표 · RLS 연산 없음 — B 등급).

## 4. OutboxEvent — 소유 각 pod (자기 DB `outbox`, 등급 B)

| 필드 | 타입 | 규칙 |
|---|---|---|
| `id` | ULID(text 26) | PK = CloudEvents `id`(프로세스 안 단조 증가 · T069) |
| `topic` | text | `<pod>.<entity>.<event>` (env 접두는 릴레이가 붙임 · 접두를 붙여 249자 이하 · T069) |
| `partition_key` | text | = 봉투 `tenantid` 값(테넌트 UUID 정규형 36자) |
| `payload` | jsonb | CloudEvents 1.0 envelope 전체 |
| `created_at` | timestamptz | DB 기본값 `statement_timestamp()`(Django `db_default=Now()` — 지표 나이 · purge와 같은 시계 · T069) |
| `attempts` | int | 기본 0 · 0 이상 |
| `last_error` | text | nullable |
| `dead_at` | timestamptz | nullable — 그 env의 DLQ(prod `<pod>.dlq` · dev `dev.<pod>.dlq`) 발행 시각 |

- 상태: `pending`(행 존재, `dead_at IS NULL`) → `published`(행 삭제) / `dead`(`attempts ≥ max_attempts 10` → 원본 봉투를 그 env의 DLQ(prod `<pod>.dlq` · dev `dev.<pod>.dlq` — `topic` 행의 env 접두 규칙 · §6 · 2026-10-16 T056 정정)로 발행 + `dead_at`, 행 유지·수동 재처리) → **purge**(`dead_at + 30 d < now()`인 행을 일 1회 삭제 — outbox가 무한히 자라지 않게 하는 유일한 경로).
- 릴레이: relay 컨테이너가 **app role**로 `SELECT … WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100`(+ 크기 상한 `octet_length(payload::text) <= 900000` — 넘는 손 행은 집지 않는다 · contracts/events.md · T069 r3) → idempotent producer(key = `partition_key`, `delivery.timeout.ms` 30000) → 성공 시 DELETE. **dead 행은 다시 집지 않는다**(재발행 폭주 방지). 같은 트랜잭션에서 도메인 쓰기와 함께 INSERT되는 것만 유효하다(관문은 `publish()`다 — `transaction.atomic()` 밖 호출은 `OutboxUsageError`이고, 모델에 직접 쓰는 것은 규칙으로 금지한다 · T069 r3 정정).
- 쓰기 API: `publish(topic, subject, data, *, tenant_id=None)` — 생략하면 요청 테넌트 컨텍스트에서 읽고, **컨텍스트도 인자도 없으면 `OutboxUsageError`**. 확정된 값이 `partition_key`이자 봉투의 `tenantid`가 된다(contracts/events.md).
- 등급 B: RLS 미적용 — 릴레이가 모든 테넌트의 행을 읽는다. 지표 `outbox_pending`(`dead_at IS NULL`만)·`outbox_oldest_pending_seconds`·`outbox_dead_total`(relay 9464).
- 인덱스(T069): `outbox_pending_idx` = `(id) WHERE dead_at IS NULL`(릴레이 `ORDER BY id LIMIT` · 지표) · `outbox_dead_at_idx` = `(dead_at) WHERE dead_at IS NOT NULL`(purge). 마이그레이션은 `django_common` 앱의 `0001`(CreateModel 하나 · RLS 연산 없음).

## 5. EventSchema — 소유 모노레포 `packages/events` (전역)

- 파일 `packages/events/schemas/<topic>.json` (JSON Schema 2020-12). `$id` = `https://joshuatech.dev/events/<topic>/v1`, `x-version` semver.
- envelope 공통(`packages/events/schemas/_envelope.json`): `specversion`(const "1.0") · `id`(ULID) · `source`(pod 이름) · `type`(= topic) · `time`(RFC 3339) · `subject`(entity id) · `tenantid`(UUID) · `datacontenttype`(application/json) · `data`(토픽별 스키마).
- 호환 규칙(CI): 기존 필드 삭제·타입 변경·required 추가·제거·enum 값 삭제·스키마 파일 삭제 금지, 선택 필드·enum 값 추가만 허용(상세 contracts/events.md §호환성 규칙). 스키마는 `additionalProperties: false`를 두지 않는다(소비자는 미지 속성 무시 — T064). 위반은 새 토픽(`…v2`)으로.
- 필드 형식 · 필수의 정본은 스키마 파일이고, 표는 contracts/events.md 「필드 형식 · 필수」(T067 확정 2026-11-03)다. CI 게이트는 기준(main) 쪽 검사기로 돈다(같은 문서 §호환성 규칙).
- SP-1 정의 토픽 6개: `identity-admin.user.registered`, `identity-admin.tenant.created`, `identity-admin.session.revoked`, `portfolio-core.note.published`, `engagement.comment.created`, `media.object.ready`. 상세는 `contracts/events.md`.

## 6. KafkaTopic / KafkaUser — 소유 platform-gitops (플랫폼 자원)

| 항목 | 규칙 |
|---|---|
| 토픽 이름 | prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`, DLQ `<pod>.dlq` / `dev.<pod>.dlq` |
| 파티션 | 3 (파티션 키 = 봉투 `tenantid`, DB 필드 `partition_key`) |
| 보존 | `retention.ms` 7일, `cleanup.policy` delete |
| 복제 | 1 (단일 노드), `min.insync.replicas` 1 |
| 사용자 | `<pod>`(prod) · `dev-<pod>`(dev), SCRAM-SHA-512. 비밀번호 원천은 Vault `kv/{env}/kafka/<pod>` → ESO → `KafkaUser.spec.authentication.password.valueFrom.secretKeyRef`(kafka ns) + 앱 ns에도 같은 경로의 ExternalSecret; 클러스터 CA(`jt-kafka-cluster-ca-cert`)는 ESO kubernetes provider로 앱 ns에 미러 |
| ACL | 자기 토픽 접두(prod `<pod>.` · dev `dev.<pod>.` — DLQ `<pod>.dlq`·`dev.<pod>.dlq` 포함 · `patternType: prefix`) `Read`·`Write`·`Describe`, 구독 토픽 `Read`·`Describe`(literal — 구독이 생기는 pod feature가 행을 더한다), 그룹 접두 prod `<pod>-` · dev `dev-<pod>-`(prefix) `Read`. cluster·transactionalId ACL은 두지 않는다(Kafka KIP-679 — 토픽 `Write`가 있으면 idempotent producer의 `InitProducerId`가 허용된다 · 트랜잭션은 쓰지 않는다). 자기 접두의 `Read`는 dev·prod 대칭으로 둔다(검사 Job 왕복 · DLQ 점검 — 자기가 낸 이벤트를 읽는 권한이라 새 데이터 노출이 아니다). 2026-10-16 T056 결정 D3로 정정(이전 문구: 「자기 토픽 `Write`·`Describe`, 구독 토픽 `Read`·`Describe`, 그룹 `<pod>-*` `Read`, DLQ `Write`」 — env별 그룹 접두가 없었다) |

- 그룹 접두의 구분자 `-`는 pod 이름에도 쓰인다 — **어떤 두 pod 이름도 한쪽이 다른 쪽 + `-`로 시작하지 않는다**(예: `identity-admin`이 있으면 `identity-admin-x`도 `identity`도 금지 — 접두 일치는 짧은 쪽 그룹 ACL `<pod>-`가 긴 쪽 pod의 그룹까지 덮어 가입·오프셋 열람이 가능해진다 · T056 리뷰 K2 · r3 B2). **pod 이름은 `dev`가 아니고 `dev-`로 시작하지 않는다** — env 접두와 겹치면 prod ACL 접두(`<pod>.` · `<pod>-`)가 dev 토픽·그룹 전체(또는 다른 pod의 dev 그룹)를 덮는다(T056 리뷰 r2 K6). 이 두 규칙 아래에서만 토픽 접두(`.`로 끝남)가 교차를 막는다. `dev` · `dev-` 금지는 copier `pod_name` 검증기(T072 — 케밥 · 39자 이하 · `dev` · `dev-` 금지 · 예약 이름 거부 — 2026-11-09)가 생성 때 막는다. 접두 겹침(한 pod 이름이 다른 이름 + `-`로 시작)을 막는 장치는 아직 없다(validate KafkaUser 규칙 — 후속 후보 · T072 보정 2026-11-07).

## 7. Database / Role — 소유 platform-gitops (CNPG 선언, `platform/cnpg-databases/`)

| 항목 | 규칙 |
|---|---|
| database (SP-1) | **`identity_admin` · `dev_identity_admin` · `authentik` · `openfga`** — 4개. 나머지 pod DB(`portfolio_core`·`media`·`engagement`·`notification`·`insights`·`search`·`assistant`와 그 `dev_` 접두)는 각 pod feature가 추가한다(YAGNI) |
| role 이름 규칙 | **PG role은 클러스터 전역**이므로 env마다 role을 나눈다: prod `<pod_snake>_owner`·`<pod_snake>_app`, dev **`dev_<pod_snake>_owner`·`dev_<pod_snake>_app`**. SP-1의 `DatabaseRole`은 **4개**: `identity_admin_owner`·`identity_admin_app`·`dev_identity_admin_owner`·`dev_identity_admin_app`. 공유 컴포넌트 `authentik`·`openfga`는 pod가 아니라서 **env 접두가 없다**(role 이름 그대로) |
| owner role | 테이블 소유, 마이그레이션 전용(B 등급 표만 쓰는 시드 명령 `seed_tenant`는 runtime 프로필 · app role로 돈다 — §1 · T073 보정 2026-11-12 — 이전 문구 「마이그레이션·시드 전용」), `NOSUPERUSER NOCREATEDB NOCREATEROLE` + **`bypassrls: true`**(FORCE RLS를 우회하므로 owner 정책이 필요 없다). 런타임 pod에는 자격이 없다(`<pod>-migrate` ExternalSecret만) |
| app role | `LOGIN NOBYPASSRLS`, 테이블 비소유, `GRANT SELECT/INSERT/UPDATE/DELETE`만. `ALTER ROLE … SET statement_timeout = '15s'`, `idle_in_transaction_session_timeout = '30s'`. A 등급 테이블은 FORCE RLS 적용 대상, B 등급은 컨텍스트 없이 접근. **세션 기본값의 적용 주체(2026-10-14 T054)**: CNPG `DatabaseRole` CRD(1.30)에는 role 수준 GUC 필드가 없다 → `platform/cnpg-databases/`의 PostSync Job이 **app role 자신의 자격으로** `ALTER ROLE CURRENT_USER SET …`(멱등 — 일반 role은 자기 세션 기본값을 바꿀 수 있다, superuser 불필요)을 **전체 sync마다**(PostSync hook — selfHeal의 부분 sync · 리소스 선택 Sync · Apply-only에서는 hook이 돌지 않는다, Argo CD v3.5.2 동작) 실행한다. 수동 대체 절차는 런북 `bootstrap.md` §4 |
| 접근 경계 | role은 자기 database에만 `CONNECT`. **CNPG `Database` CRD로는 표현할 수 없으므로** 각 database의 **migrate Job 첫 단계**에서 멱등 SQL로 강제한다: `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC; GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner;`(contracts/pod-template.md §마이그레이션). 이 SQL이 없으면 `dev_identity_admin_app`이 prod `identity_admin` DB에 붙을 수 있다 — T050이 그 거부를 단언한다. **SP-1 보강(2026-10-14 T054)**: migrate Job은 US6(T072·T075)에야 생기므로, 그 전까지의 창(dev→prod DB 접속 가능)을 닫고 T059(US3 E2E)의 교차 DB 거부 증거를 가능하게 하려고 `platform/cnpg-databases/`의 PostSync Job이 **pod DB에도 같은 멱등 SQL을 각 pod owner 자격으로 먼저 실행**한다(자격 격리 — 별도 initContainer). migrate Job 첫 단계는 그대로 두며 둘은 이중 멱등이다. 남는 경계 공백: 새 LOGIN role이 `postgres`·`platform`(initdb DB)·`template1`에 PUBLIC CONNECT로 붙을 수 있다 — owner가 superuser·`platform_owner`라 이 Job으로는 회수하지 않는다(T097/T116에서 결정) |
| TLS | 클라이언트는 `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`. CA Secret `pg-main-ca`는 ESO **kubernetes provider store `k8s-data-ca`** 로 `identity`·`jt-dev`·`jt-prod`에 미러하되 **`ca.crt` 속성만** 복사한다(T050: `pg_stat_ssl` 세션 ssl=true 단언, T031: 미러 Secret에 `ca.key` 부재). **`ca.key`를 함께 미러하면**(CNPG의 `<cluster>-ca` Secret에는 들어 있다) 그 키로 **서버 인증서를 위조해 `verify-full`을 무력화**하거나 **`streaming_replica` 클라이언트 인증서를 위조해 복제 스트림에 붙을 수 있다** — 기본 `pg_hba`가 임의 role의 cert 인증을 허용해서가 아니라(기본은 `host all all all scram-sha-256`이고 cert 행은 `streaming_replica`·pooler로 고정), CA 키 자체가 그 두 인증서를 만들 수 있기 때문이다. Authentik은 `AUTHENTIK_POSTGRESQL__SSLMODE=verify-full`·`AUTHENTIK_POSTGRESQL__SSLROOTCERT`(개별 env, `CONN_OPTIONS` 금지) |
| 비밀 | pod DB: Vault `kv/{env}/db/<role 접두>/{owner,app}` → ESO(`vault-data`로 CNPG `DatabaseRole.spec.passwordSecret` — Secret `pg-main-<role 하이픈>`, type `kubernetes.io/basic-auth`, 라벨 `cnpg.io/reload: "true"`, 키 `username`·`password`; `vault-{env}`로 pod env). 공유 컴포넌트 DB: **`kv/platform/db/{authentik,openfga}/owner`**(`vault-platform`). (spec FR-017의 `managed.roles.passwordSecret` 표기는 research CNPG-D5에서 1.30 `DatabaseRole` CRD로 바뀌었다 — 2026-10-14 T054 정정) |
| 백업 | barman-cloud → 버킷 `jt-backup`(IAM 사용자 `svc-s3-backup`만, versioning), `ScheduledBackup 0 0 17 * * *`(02:00 KST 매일), `archive_timeout 300`. PITR은 클러스터 전체(재해 복구 전용); 단일 DB 복구 = side Cluster PITR → `pg_dump` → 복원(런북) |
| 확장 | `pgvector`(standard 이미지 내장, assistant 대비) — database별 `CREATE EXTENSION`은 owner role. `pg_bigm`은 자체 확장 이미지가 필요해 SP-3로 이월. SP-1(T054): `Database` `identity_admin` **과 `dev_identity_admin`** 에 `extensions: [{name: vector, ensure: present}]`(CNPG가 선언적으로 설치 — 과제 문면은 `identity_admin`만 적었으나 env 패리티: dev 마이그레이션이 prod보다 먼저 돌므로 dev에 없으면 dev가 먼저 깨진다) · 공유 DB는 확장 없음 |

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
| `kv/platform/openfga/preshared` | `key` | `vault-platform` | OpenFGA 서버 `authn.preshared`(`identity` ns). 서버가 호출자를 검증하는 들어오는 쪽 키다(키 하나가 dev · prod store를 다 연다 — ADR 0006) — 플레이스홀더나 고정 값을 두지 않는다. 생성 규칙 · 서버 기동 앞 게이트 · env 사본과의 방향(platform 값이 먼저)은 T082가 정한다(build-notes 「T070 결과」 인계 · T070 r6 마감) |
| `kv/platform/oci/s3` | `access_key`, `secret_key`(IAM 사용자 `svc-s3-backup`, 버킷 `jt-backup`만) | `vault-platform` | CNPG barman-cloud |
| `kv/platform/vault-backup` | **없음** | — | Vault Raft 스냅샷은 kv 비밀 없이 수행한다: K8s auth role `vault-backup`(정책 `sys/storage/raft/snapshot` read, SA `vault-backup` ns `vault`) + 노드 A 인스턴스 프린시펄(동적 그룹 `jt-node-a`)이 `jt-backup-platform/vault/`에 업로드(`platform-backup.sh`, age 암호화). K3s 번들도 같은 버킷 `k3s/` |
| `kv/{env}/db/<role 접두>/owner` | `username`, `password`, `url` | `vault-data`(CNPG managed role) · `vault-{env}`(**`<pod>-migrate`**, migrate Job만) | `<role 접두>` = prod `identity_admin` / dev `dev_identity_admin` |
| `kv/{env}/db/<role 접두>/app` | `username`, `password`, `url`(`sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` 포함) | `vault-data` · `vault-{env}`(**`<pod>-env`**) | 같음 |
| `kv/{env}/kafka/<pod>` | `password` | `vault-data`(KafkaUser, `data` ns) · `vault-{env}`(`<pod>-env`) | |
| `kv/{env}/authentik/<pod>` | `client_id`, `client_secret`, `jwks_url`(**svc DNS**), `issuer`(공개 URL) | `vault-{env}` | `<pod>-env` |
| `kv/{env}/authentik/identity-admin` | 위 4개 + `api_token`(주체: prod = 서비스 계정 `identity-admin` · dev = `identity-admin-ro` — 권한은 §9 「서비스 계정 권한」 표 · 「토큰 revoke」 권한은 없다 · T073 보정 2026-11-12) | `vault-{env}` | identity-admin `-env`. **`webhook_secret`은 여기 두지 않는다**(아래 행). US6 기동(T075) 전에 운영자 블록이 T044 sentinel(`PLACEHOLDER-T044-SENTINEL` — docs/runbooks/vault-unseal.md §US6 플레이스홀더 8경로)을 덮어쓴다 — `jwks_url` · `issuer`는 계약 값이다(contracts/identity-admin-api.md §호스트 · US4에서도 그대로 · `check_settings()`가 본다 — sentinel `jwks_url`이면 기동에서 멈춘다). US4(T081 · T082)에서야 실값이 생기는 나가는 쪽 자격 — `client_id` · `client_secret`(identity-admin 설정 없음 — pod env에 매핑하지 않는다 · T073 보정 2026-11-12) · `api_token` · `kv/{env}/openfga/{store_id,preshared}`(T066 기동 검사 = 있고 비밀은 비지 않음 · `preshared`를 platform 값으로 바꾸는 것은 T082 — docs/runbooks/vault-unseal.md §US6 · T075 보정 2026-11-17 · 이전 문구 「`preshared`는 T044 런북의 US6 교체 규칙도 함께」) — 은 US6 동안 이렇게 둔다(T075 보정 2026-11-17 — 이전 문구 「T075가 T044 게이트 1 · 2와 함께 정한다」): `api_token` · `kv/{env}/openfga/{store_id,preshared}`는 T044 sentinel 그대로 두고 두 overlay ConfigMap `JT_PLACEHOLDER_EXEMPT=AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY`로 면제한다. `client_id` · `client_secret`도 sentinel 그대로다(매핑하지 않는다). `jwks_url` · `issuer`는 `vault kv patch "-cas=<n>"`로 계약 값을 넣는다(비밀 아님 — key=value 인자 허용 · 나머지 키 보존). 게이트 1은 키 단위다(docs/runbooks/vault-unseal.md §US6 · T075 블록 O-3 — `design/t075-blocks/`는 T075 조각 ④에서 생긴다). sentinel을 알아볼 수 없는 다른 고정 값으로 바꿔 게이트를 통과시키지 않는다(T070 r6 — r5 문장 정정). `jwks_url` · `issuer`의 쓴 뒤 판정 = 계약 문자열과 글자 그대로 같다. frozen T043 · T075 · T081 · T083의 「`kv/{env}/authentik/*` 플레이스홀더 → US4 교체 · 투입」과 다른 점이다(`jwks_url` · `issuer` · 웹훅 비밀 — report.md 편차 · T070 r6 마감). 게이트 2에서 면제할 수 있는 이름은 `AUTHENTIK_API_TOKEN` · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY` 셋뿐이다(contracts/identity-admin-api.md §identity-admin 전용 설정 · T073 보정 2026-11-12) |
| `kv/{env}/authentik/webhooks/<pod>` | `secret`(HMAC 공유 비밀) | `vault-data`(Authentik NotificationTransport) · `vault-{env}`(`<pod>-env`) | pod·env마다 분리해 하나가 새도 나머지가 안전하다. **US6 플레이스홀더를 두지 않는다** — 들어오는 쪽 검증 키다(`/webhooks/authentik`은 Access · Bearer 면제 · HMAC만 지킨다). 알려진 값이면 pod 포트에 닿는 클러스터 안 호출자가 서명한다(빈 HMAC 키와 같은 부류 · contracts/identity-admin-api.md). T075가 identity-admin을 켜기 전에 운영자가 CSPRNG 32바이트 이상 실값으로 T044 sentinel을 덮어쓰고, US4에서 바꾸지 않는다(T081 NotificationTransport가 같은 경로를 읽는다). 쓴 뒤 판정 = sentinel 아님 · 길이 · 되읽기 해시 · dev 해시 ≠ prod 해시(값은 화면 · 파일 · argv · 클립보드에 내지 않는다 · T070 r6). (T075 보정 2026-11-17 — 이전 문구 「판정 블록과 쓰기 블록의 분리 · `-cas` · JSON stdin · 인코딩 단위는 T075 운영자 블록이 정한다(build-notes 「T070 결과」 인계)」) 값 = CSPRNG 32바이트 → base64url(패딩 없음 · 43자 · `[A-Za-z0-9_-]`). **HMAC 키 = 그 43자 문자열의 ASCII 바이트**다 — base64url을 디코드하지 않고 끝 줄바꿈도 없다(django-common `auth.py` `hmac.new(secret.encode(), …)`). T081 NotificationTransport도 같은 문자열을 디코드 없이 키로 쓴다. 쓰기 = T075 블록 W-2(`vault kv put "-cas=<n>" <path> -` · JSON stdin) · 판정 = O-3(다른 블록 — 두 블록은 T075 조각 ④에서 생긴다). T081 · T083은 이 경로를 읽어 판정만 하고 쓰지 않는다(frozen 문면과의 편차 — report.md · T070 r6 마감). (T075 보정 2026-11-20 — 시드 기록 · 값 · 해시 0) identity-admin: dev `secret` 덮어씀 v2(2026-11-19 · W-2) · prod 덮어씀 v2(2026-11-20) · 게이트 O-3 dev `gate=PASS 21/21` · prod `gate=PASS 23/23`(`PASS webhooks secret: dev 해시 ≠ prod 해시` 포함 — docs/runbooks/bootstrap.md §4 T075 기록 칸 A) |
| `kv/{env}/authentik/web-bff` | `client_id`, `client_secret`(prod = `web-bff`, dev = `web-bff-dev` provider) | ESO 밖 | BFF — Workers Secrets에만(`wrangler secret put`) |
| `kv/{env}/access/web-bff` | `client_id`, `client_secret`(Access 서비스 토큰 `web-bff-<env>`) | ESO 밖 | BFF — **Workers Secrets에만**. pod에는 배포하지 않는다. `kv/{env}/access/<pod>` 경로는 없다 — pod가 필요한 값은 ConfigMap `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ACCESS_EXPECTED_CN`(비밀 아님) |
| `kv/platform/access/tester-m2m` · `kv/platform/access/tester-k8s` | `client_id`, `client_secret`(tester Access 서비스 토큰 — dev·prod m2m 앱 / `k8s` 앱 include) | ESO 밖 — `eso-platform` 정책의 `kv/{data,metadata}/platform/access/*` deny로 강제한다(T076 · infra/vault/policies.tf) | tester — `tester-m2m`은 Vault role `e2e-reader`로 T076 O-8 블록 안에서만 받는다(값은 그 블록 프로세스의 메모리에만 — 출력 · 파일 · argv · 보고 0). `tester-k8s`는 `e2e-reader` 정책 밖이다. 시드: `tester-m2m` = T076 운영자 블록 W-7(`-cas=0` · JSON stdin) · `tester-k8s` = 그대로 이연(T077). 회전 매트릭스 T084, contracts/hostnames-and-access.md §에이전트 자격. (T076 보정 2026-11-20 · UD-15 — 이전 문구 「ESO 밖」 · 「tester — 실행 시 env로만 받고 파일에 저장하지 않는다」) |
| `kv/{env}/dragonfly/acl` | `users.acl`(파일 전문) | `vault-data` | Dragonfly Deployment(`data` ns, `--aclfile /etc/dragonfly/users.acl`) |
| `kv/{env}/dragonfly/<user>` — `admin` · `identity-admin` · `<pod>` | `password`, `url` | `admin` = **—(운영자 직접, ESO 소비자 없음)** · `vault-{env}`(`<pod>-env`) | `DRAGONFLY_URL`; `admin`은 운영자 런북 전용 |
| `kv/{env}/sentry/<pod>` | `dsn` | `vault-{env}` | `<pod>-env`. US6 = env마다 빈 `dsn`(`{"dsn": ""}` — T075 시드 · 빈 값 = Sentry 끔 · 경로가 없으면 `<pod>-env`가 SecretSyncedError) · 실값은 T100(T075 보정 2026-11-17) |
| `kv/{env}/django/<pod>` | `secret_key` | `vault-{env}` | `<pod>-env` `SECRET_KEY`(Django 서명 · 로그 `sub_hash` 키). 경로는 T072가 정하고(템플릿 base ES `data[7]`) 시드 · 판정은 T075다. 시드 규칙: CSPRNG로 50자 이상 · dev와 prod는 다른 값 · 값을 화면 · argv에 내지 않는다(기동 검사가 W009 기준 — 50자 이상 · 서로 다른 글자 5 이상 · `django-insecure-` 접두 아님 — 을 어기면 실패한다). 회전하면 `sub_hash`가 바뀌고 admin 세션이 무효가 된다. `eso-dev` · `eso-prod` 정책이 `kv/data/{env}/*` 전체라 정책 변경은 없다(infra/vault/policies.tf · T072 보정 2026-11-07). (T075 보정 2026-11-20 — 시드 기록 · 값 · 해시 0) identity-admin: dev `secret_key` 생성 v1(2026-11-19 · W-2) · prod 생성 v1(2026-11-20) · 게이트 O-3 dev `gate=PASS 21/21`(`secret_key` W009 PASS) · prod `gate=PASS 23/23`(`PASS django secret_key: dev 해시 ≠ prod 해시` 포함 — docs/runbooks/bootstrap.md §4 T075 기록 칸 A) |
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
| User | `e2e@joshuatech.dev`(로컬 사용자, TOTP; 비밀은 **`kv/platform/authentik/e2e`**), 서비스 계정 `identity-admin`(prod; 권한은 표 아래 「서비스 계정 권한」 — 「토큰 revoke」 권한은 없다: Authentik에서 비슈퍼유저는 남의 OIDC 토큰을 지울 수 없다(소스 판독 — 실측 T081 · VD-T081-2) · T073 보정 2026-11-12) + **dev 전용 서비스 계정 `identity-admin-ro`**(권한은 표 아래 「서비스 계정 권한」 · 지금 계약은 사용자 **read만** — Authentik API 토큰은 계정 권한을 그대로 가지므로 토큰 단위 축소가 아니라 별도 계정으로 분리한다). 토큰 → `kv/{env}/authentik/identity-admin.api_token`(prod 주체 = `identity-admin`, **dev 주체 = `identity-admin-ro`**). dev의 Authentik 쓰기 호출(세션 삭제 위임 · 시드 쓰기)은 설정 플래그로 비활성이다(시도하지 않고 로그만 — contracts/identity-admin-api.md §identity-admin 전용 설정). 일 1회 대조는 읽기라 플래그와 무관하고 권한이 없으면 로그 한 줄 뒤 끝난다(응답 꼴에 따라 경고 한 줄이거나 `seen` 0 — contracts/identity-admin-api.md §주기 작업 · T073 보정 2026-11-12) | 운영자 개인 계정은 blueprint에 없다 |
| Application + Provider(OAuth2) | `web-bff`(confidential, PKCE, **token exchange grant — SP-1은 impersonation**, redirect **`https://joshuatech.dev/api/auth/callback`만**, access 300 s, refresh 30 d 회전), `web-bff-dev`(같은 설정, redirect `http://localhost:3000/api/auth/callback` · `https://preview.joshuatech.dev/api/auth/callback`), `identity-admin`(자기 signing key·JWKS, Federated Providers = [`web-bff`, `web-bff-dev`]; **`act` 클레임은 VD-1이 옵션 A로 확정될 때만** 발급된다 — OSS에는 `Actor` 생성 경로가 없어 기본은 impersonation), `argocd`·`vault`(OIDC, 그룹 클레임). `grafana` provider는 SP-2. **`web-bff`·`web-bff-dev`·`identity-admin`의 Subject mode는 `user_uuid`로 맞춘다**(T066 보정 2026-11-03 — `sub` = Authentik 사용자 UUID: BFF 토큰과 교환 토큰의 `sub`가 같아야 `/session/check`·거부 목록이 맞물리고, `seed_tenant`가 `GET /api/v3/core/users/?uuid=<sub>`로 사용자를 찾는다 · 기본값 hashed user id는 역조회가 안 된다 · VD-T066-1: T081 blueprint 적용 뒤 두 토큰의 `sub`와 조회 결과를 실측). `web-bff` · `web-bff-dev`의 scope에는 `openid`와 `offline_access`가 있어야 한다(ID 토큰 `iat` = BFF 세션 시작 시각 · refresh 토큰 발급의 전제). 세션 폐기의 최종성은 refresh 수명에 기대지 않는다 — `/session/check`의 세션 하한과 세션 절대 수명 30일이 맡는다(contracts/denylist.md · T073 보정 2026-11-12) | 각 provider의 `issuer` = `https://auth.joshuatech.dev/application/o/<slug>/`(공개 호스트). **JWKS는 pod가 svc DNS로 읽는다**(`http://authentik-server.identity.svc:9000/application/o/<slug>/jwks/`); FR-046 예외 2(공개 호스트 사용)는 Argo CD·Vault OIDC discovery로 한정 |
| ScopeMapping | `tenant_id`(UUID) — **원천은 `user.attributes.tenant_id`**(identity-admin이 갱신하는 파생). 그룹 `tenant:<uuid>`는 RBAC·정책 바인딩 용도이고 클레임 원천이 아니다 | attribute가 있으면 모든 access/ID 토큰에 포함 — **없으면 키를 뺀다**(JSON null은 pod가 401 `invalid_token`으로 거부한다 · T081 식 · VD로 실측 · T070 r2 보정) |
| NotificationTransport + Rule | webhook(generic) **2개**: prod → `http://identity-admin.jt-prod.svc/webhooks/authentik`, dev → `http://identity-admin.jt-dev.svc/webhooks/authentik`(둘 다 svc DNS, 공개 호스트 금지). 이벤트는 `logout`만(T073 보정 2026-11-12 — 이전 문구 「`logout`·`login`·`model_deleted(session)`」: Authentik은 세션 삭제 이벤트를 만들지 않고 `login`은 토큰 교환마다 생긴다 · 소스 판독 — 실측 T081 · VD-T081-1). 매핑 본문은 JSON 기본형만 쓴다(문자열 · 정수 · bool · null · dict): `pk` = `str(event.pk)`(대시 꼴) · `created` = `event.created.isoformat()` · **`nbf` = `floor(created) + 1`(필수 — 빠지면 수신 시각이 30일 세션 하한 값이 된다)** · `sub` = 이벤트 사용자 UUID · `action`. 같은 이벤트를 여러 번 보내지 않게 수신자를 이벤트 사용자 하나로 둔다(또는 `send_once`). 세션 결속이 깨져 생긴 logout 이벤트를 거를지는 T081이 정한다(기본 = 거르지 않는다 — 일 1회 대조도 같은 기준을 쓴다) | 서명 헤더 `X-Authentik-Signature: sha256=<hex>` = HMAC-SHA256(비밀 **`kv/{env}/authentik/webhooks/identity-admin`**, 본문 JSON 정규형) — body·headers 두 매핑이 같은 event dict에서 계산한다(헤더 매핑은 전송 본문을 받지 못한다 · 규약·VD-T062-1은 contracts/identity-admin-api.md §웹훅 서명 규약 · 2026-11-02 보정). NetworkPolicy에 `identity → jt-dev:8000` 행이 있어야 dev 웹훅이 도달한다 |
| Outpost(proxy) | Django admin forward-auth(`admin.` 호스트) | SP-1은 identity-admin admin만(prod). dev는 `ADMIN_HOST`가 빈 값이라 admin 표면이 없다 |
| Access(Cloudflare, 참고) | `auth.joshuatech.dev/if/admin/*`만 Access 앱 `auth-admin`(GitHub IdP) 뒤; `/application/o/*`·`/if/flow/*`·`/if/user/*`·`/.well-known/*`·**`/api/v3/*`** 는 공개(로그인 SPA가 브라우저에서 `/api/v3`를 부른다) | 보상 통제·SP-2 검토 항목은 contracts/hostnames-and-access.md |

**서비스 계정 권한(T073 보정 2026-11-12 — 권한마다 쓰는 작업. 어느 계정 · 토큰에 줄지의 확정은 T081 전 사용자 결정)**

| 권한 | 쓰는 작업 | 없을 때 | 토큰이 새면 |
|---|---|---|---|
| `authentik_core.view_user` | 세션 삭제 위임(sub → 사용자) · 일 1회 대조(이벤트 사용자 pk → uuid) · `seed_tenant` 사용자 조회 | 401 · 403 · 404(또는 빈 결과 — T081 실측) → 위임은 로그 뒤 끝나고 대조는 contracts/identity-admin-api.md §주기 작업의 갈래(401 · 403 = 경고 뒤 끝 · 404 = 그 이벤트를 건너뜀)를 따르며 시드는 `CommandError` | 전 사용자의 이메일 · attributes 열람 |
| `authentik_core.view_authenticatedsession` | 세션 삭제 위임(세션 목록) | 목록이 오류 없이 빈다 → 삭제 0건(조용한 실패 — T081 실측) | 전 사용자의 세션 IP · UA 열람 |
| `authentik_core.delete_authenticatedsession` | 세션 삭제 위임(단건 DELETE) | 403 · 404 → 로그 | 운영자를 포함한 임의 사용자 강제 로그아웃 |
| `authentik_events.view_event` | 일 1회 대조(logout 이벤트 72시간 창) | 401 · 403(또는 오류 없는 빈 목록 — T081 실측) → `authentik.reconcile_forbidden` 한 줄 뒤 끝난다(빈 목록이면 경고 없이 `seen` 0으로 끝난다 · 어느 쪽이든 유실 웹훅은 기록되지 않는다) | 감사 이벤트 전체 열람(로그인 IP · UA · 사용자명 · 관리자 행위 — dev · prod가 한 인스턴스라 env를 가르지 않는다) |
| `authentik_core.view_group` | `seed_tenant` 그룹 조회 | 그룹 0건 → `CommandError` | 그룹 구성 열람 |
| `authentik_core.add_user_to_group` · `authentik_core.change_user` | `seed_tenant` 쓰기(prod만 — 소속 · `attributes.tenant_id`) | 403 → `CommandError` | 임의 사용자의 그룹 소속 · attributes 변경 · 비활성화(권한 상승 경로) |

앞의 셋은 런타임(세션 삭제 위임)에 필요하다. `view_event`를 줄지, 시드 쓰기 권한을 pod 장기 토큰에 둘지 운영자 만료 토큰(`seed_tenant --authentik-token-stdin`)에만 둘지는 T081 전에 정한다.

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
    define member: [user] or owner
```

- **정본은 spec FR-025의 2관계**(`owner`·`member`)다. `admin` 관계는 **SP-2 예약** — SP-1의 `model.fga`에 넣지 않는다(도입 시 `define admin: [user] or owner` / `define member: [user] or admin`으로 확장).
- 관계는 **포함 관계**다: `owner ⊂ member` — `owner`인 사용자는 `member` check도 true다. `/tenants/me`·FGA `check`가 이 정의에 기댄다.
- store `jt-dev`, `jt-prod`(ID는 Vault `kv/{env}/openfga/store_id`, 서버 인증은 `kv/{env}/openfga/preshared`; 둘 다 identity-admin `<pod>-env`). object id는 `tenant:<uuid>`. 튜플 `user:<sub> member tenant:<uuid>`는 §2 `TenantMembership`의 파생이며 identity-admin만 쓴다(SP-1 `seed_tenant`). SP-2 이후 `room#member`·`media#viewer` 같은 교차 관계가 추가되면 모델 파일 PR + CODEOWNERS.
- 검증: **T078**(`tests/platform/identity.tests.ps1`) — 다른 테넌트 object에 대한 `check` → false. 자격이 필요한 `fga` 호출은 `platform/policies/tests/`의 Job `authz-assert`가 실행하고 tester는 로그만 읽는다(contracts/hostnames-and-access.md).

## 11. ContentItem — 소유 git (`content/{study,blog,projects}`, 전역)

frontmatter(`rules/content.md` 계약, zod로 코드화):

| 필드 | 타입 | 규칙 |
|---|---|---|
| `title` · `description` | string | 필수 · 비어 있거나 공백만이면 안 된다(T090 보정 2026-11-27) |
| `pubDate` | date — 'YYYY-MM-DD' 문자열(YAML 1.2 core · Date 아님 — T086 정정 노트 2 · T090 보정 2026-11-27) | 필수, `updatedDate` ≥ `pubDate` |
| `updatedDate` | date — 'YYYY-MM-DD' 문자열(`pubDate`와 같은 꼴 — T090 보정 2026-11-27) | 선택, 있으면 ≥ `pubDate` |
| `tags` | string[] | 필수(빈 배열 허용) · 원소는 비어 있거나 공백만이면 안 된다(T090 보정 2026-11-27) |
| `series` · `seriesOrder` | string · 양의 정수 | 선택, 같이 존재 · `series`는 비어 있거나 공백만이면 안 되고 `seriesOrder` ≥ 1(T090 보정 2026-11-27) |
| `draft` | boolean | 필수; PROD 빌드에서 `true`는 제외 |
| `change` | string | 필수(study) · 선택(blog · projects — 변형은 ko 파일과 같은 값이거나 둘 다 없다 · T090 보정 2026-11-27 · 〔90-3〕 잠정), `^\d{3}-[a-z0-9-]+$` |
| `sources` | `{title, path?, url?}[]` | 필수(빈 배열 허용), 항목마다 `path` · `url` 가운데 정확히 하나 — `path` = 저장소 상대 경로 `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$`(`.` · `..` 세그먼트가 없다) · `url` = http/https(T086 보정 2026-11-24 · N-13) · 항목 `title`은 비어 있거나 공백만이면 안 된다 · `url` host는 도메인 이름 꼴(꼴 검사 — 내부 이름은 통과하므로 저자가 뺀다 · `rules/content.md` · T090 보정 2026-11-27) |

파생 필드(로더가 계산): `slug`(파일명), `lang`(접미사 `.en`·`.ja` → `en`·`ja`, 없으면 `ko`), `collection`, `readingTime`, `headings[]`, `translations[]`(같은 slug의 다른 lang). 규칙: 같은 slug의 언어 변형은 `pubDate`·`change`가 같아야 하고, `ko` 파일이 없으면 오류. `html`(본문 HTML — 원시 HTML 0 · Shiki 하이라이트 · 각주 라벨 · 되돌림 라벨 lang별) · `headings[]` = 목차(depth 2 · 3 · 각주 라벨 제외) · `translations[]`는 그 호출에서 draft를 거른 뒤 남은 같은 slug의 다른 lang(정렬) · ko 파일이 걸러지면 그 slug 전체 제외(T090 보정 2026-11-27).

오류(T090 보정 2026-11-27 — 공개 CI 로그에 나가는 계약): 로더는 위반을 모아 `ContentValidationError` 하나로 던진다. issue = `{file, field, code, line?}`. `field`가 프런트매터 키 경로이면 `code` ∈ `missing` · `type` · `empty` · `format` · `range` · `unknown-key` · `series-pair` · `date-order` · `source-kind` · `variant-mismatch` · `invalid`이고, `field`가 `file`이면 `name` · `encoding` · `ko-missing` · `not-regular`, `frontmatter`이면 `fence` · `yaml`, `body`이면 `raw-html` · `esm` · `expression` · `unsafe-url`(`line` 필수)이다. issue · message에 값은 싣지 않는다(파일 이름 · 모르는 키 이름은 싣는다). 정본 = `packages/content/tests/loader.test.ts` 머리 · `packages/content/src/{schema,mdx,loader}.ts`의 code 형.

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
SessionRevocationLog(DB, 정본) ──기동 1회 + 30 s 무조건 재적용──▶ SessionRevocation(Dragonfly 캐시 revoked:sub·revoked:sid ◀──조회── 모든 pod · identity-admin:session-floor · identity-admin:sid-floor ◀──조회── identity-admin /session/check)
SessionRevocationLog ──outbox──▶ identity-admin.session.revoked ──▶ insights(SP-3)
OutboxEvent(pod DB, 등급 B) ──릴레이(app role, dead_at IS NULL)──▶ KafkaTopic ──▶ 소비자 pod / <pod>.dlq(dev: dev.<pod>.dlq) ──dead_at+30d──▶ purge
SecretPath(Vault) ──ESO(vault-platform·vault-dev·vault-prod·vault-data)──▶ Secret ──▶ CNPG roles · pod env(<pod>-env / <pod>-migrate) · cloudflared · Alloy · Dragonfly ACL · Authentik 웹훅
CNPG/Strimzi CA Secret(data ns) ──ESO(k8s-data-ca, ca.crt만)──▶ identity · jt-dev · jt-prod
SecretPath(Vault) ──운영자 복사(ESO 밖)──▶ Workers Secrets(web-bff·access/web-bff·web/session); Vault role e2e-reader ──▶ tester(kv/platform/authentik/e2e · kv/platform/access/tester-m2m — 후자는 O-8 블록 안에서만)   [T076 보정 2026-11-20 · UD-15]
AuthentikObject(Provider) ──JWKS(svc DNS)──▶ pod 인증 미들웨어 · BFF(호출자 식별은 Access common_name)
ContentItem(git) ──packages/content──▶ web 빌드 · (SP-2) notes-sync ──▶ portfolio-core 메타
```
