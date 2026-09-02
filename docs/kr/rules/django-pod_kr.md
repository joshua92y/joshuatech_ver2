> 번역본(편의용). 정본은 영어 원본 `.claude/rules/django-pod.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "apps/*/**"
  - "packages/django-common/**"
  - "templates/django-pod/**"
```

# Rules for Django pods (`apps/<pod>/`, `packages/django-common/`, `templates/django-pod/`)

범위: `apps/web`을 제외한(그쪽은 `web.md`가 관장) 모든 `apps/<pod>` 디렉터리. 기록 계약: `specs/003-platform-foundation/contracts/pod-template.md`(+ outbox는 `contracts/events.md`). 충돌 시 계약이 우선한다; 계약을 먼저 개정한다.

## Template and structure

- pod는 `copier copy templates/django-pod apps/<pod>`로 생성한다; 생성된 pod는 수정 없이 자기 테스트를 통과해야 하고 `packages/django-common`에 의존한다(공통 코드를 pod로 복사하지 않는다).
- 템플릿 변경은 생성 결과를 그린 상태로 유지해야 한다; 템플릿 변경을 커밋하기 전에 생성된 pod의 테스트 스위트를 실행한다.

## Table grades (TenantModel / GlobalModel)

- 등급 A(테넌트 범위): `TenantModel`을 상속 — `tenant_id` UUID NOT NULL, 인덱스 `(tenant_id, id)`, `rls_policies(<table>)` 마이그레이션 헬퍼를 통한 `ENABLE` + `FORCE ROW LEVEL SECURITY` + `tenant_isolation` 정책. 행(row)은 요청 트랜잭션의 `app.tenant_id` 컨텍스트를 통해서만 도달 가능하다; 컨텍스트 없음 → 0행.
- 등급 B(pod 전역): `GlobalModel`을 상속. 허용 목록만: `tenant`, `tenant_membership`, `outbox`, `session_revocation_log`. B등급 테이블 추가는 `contracts/pod-template.md`와 이 규칙을 먼저 개정해야 한다.
- `check_rls`(CI + 기동 시)는 통과해야 한다: 모든 A등급 테이블에 FORCE RLS + 정책이 있고, RLS 없는 모든 테이블은 B 허용 목록에 있다.
- 역할(role): owner 역할은 `bypassrls`를 가지며 마이그레이션/시드 전용이다 — 런타임에는 절대 쓰지 않는다; app 역할은 `NOBYPASSRLS`다. DB와 역할 이름은 환경별로 분리한다(dev는 `dev_` 접두); 역할을 환경 간에 절대 공유하지 않는다.

## Outbox and events

- 발행은 `transaction.atomic()` 안에서 `django_common.outbox.publish(topic, subject, data, *, tenant_id=None)`로만 한다. 테넌트 컨텍스트도 없고 `tenant_id` 인자도 없으면 → `OutboxUsageError`; 컨텍스트 없는 경로(webhook, admin revoke, 기동 잡)는 반드시 `tenant_id`를 명시적으로 전달한다.
- 릴레이는 app 역할로 실행되고 `dead_at IS NULL`만 선택한다(`FOR UPDATE SKIP LOCKED`); `attempts >= 10` → 엔벨로프를 `<pod>.dlq`로 발행하고 `dead_at`을 설정한다; dead 행은 `dead_at + 30 d`에 purge된다(Celery beat, 템플릿의 유일한 기본 beat 잡).

## Auth

- 요청 인증 체인: Bearer JWT(svc DNS를 통한 JWKS; `iss` 공개 URL, `aud`, `exp`, `nbf` 검증) + `Cf-Access-Jwt-Assertion`(`aud`가 {M2M, ADMIN}에 속하고 `common_name == ACCESS_EXPECTED_CN`) + 거부 목록(`revoked:sub:{sub}`, `revoked:sid:{sid}`). 거부 목록 조회 실패 = 503 `denylist-unavailable`, fail-closed(0.2초 타임아웃).
- `AUTH_ACTOR_SUB` 설정됨 → `act.sub`를 추가 검증; 미설정(빈 값) = impersonation 모드, `act` 검사 없음. 빈 문자열은 `AUTH_ACTOR_SUB`와 dev `ADMIN_HOST`의 유효한(VALID) 값이다 — 필수 설정 검사는 존재 여부를 단언하지, 비어 있지 않음을 단언하지 않는다.
- 예외: 헬스 엔드포인트 3개만. webhook 경로는 명시적으로 나열하며 대신 HMAC + 타임스탬프 ±5분 + 멱등성 키를 쓴다.
- admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 마운트한다; dev의 `ADMIN_HOST`는 빈 값 → admin이 아예 없다.

## Settings

- pydantic-settings → Django settings; 필수 값 누락은 기동 시 `ImproperlyConfigured`를 던진다. 시크릿은 env(ESO `<pod>-env`)에서만 온다; 비밀이 아닌 값(`ACCESS_AUD_*`, `ACCESS_EXPECTED_CN`, `AUTH_ACTOR_SUB`, `ADMIN_HOST`, `ALLOWED_HOSTS`, `IDENTITY_M2M_URL`)은 ConfigMap에서 온다. 메일은 `MAILERS`로만(`EMAIL_*` 금지).
- `DATABASE_OWNER_URL`은 migrate Job의 env(`<pod>-migrate`)에만 존재한다; 런타임 env에는 절대 나타나지 않는다.

## Tests (mandatory, constitution II)

- 모든 pod는 6개 기본 테스트 영역을 탑재하고 그린으로 유지한다: 헬스 3종(`/healthz`, `/ready` DB만, `/health` 항상 200), 테넌트 RLS(A: 교차 테넌트 0행, 컨텍스트 없음 0행, owner 전부; B: app 역할이 전부 읽음), outbox(사용 오류, 릴레이, DLQ, purge), 인증 미들웨어(토큰/Access/거부 목록/actor 매트릭스), 로깅(필드 존재, `authorization`/`cookie`/`x-authentik-signature` 부재), 마이그레이션 + OpenAPI 스냅샷. 절대 삭제하거나 건너뛰지 않는다.
- pytest는 `-W error::DeprecationWarning`으로 실행한다; `filterwarnings` 항목은 자기 모듈로만 범위를 한정한다.

## Migrations

- 마이그레이션은 Argo PreSync migrate Job(owner 역할)만 실행한다; 앱은 절대 마이그레이션하지 않는다. Job의 첫 단계는 `manage.py migrate` 전에 멱등한 CONNECT 경계 SQL(`REVOKE CONNECT ... FROM PUBLIC; GRANT CONNECT ...`)이다.
- 2단계(two-phase) 규칙: 컬럼 삭제, NOT NULL 추가, 타입 변경은 반드시 두 릴리스에 걸쳐 expand → contract로 나눈다.
- RLS 정책 변경은 전용 마이그레이션으로만 간다 — 스키마나 데이터 변경과 절대 섞지 않는다.
- CI 게이트: `makemigrations --check` + `django-migration-linter`가 통과해야 한다(린터가 파괴적 연산을 잡는다).

## Dragonfly

- 자기 소유 키는 전부 `<pod>:` 접두를 쓴다 — Celery `broker_transport_options.global_keyprefix`와 캐시 `KEY_PREFIX`. Dragonfly 사용자 = pod 이름; 거부 목록 키는 ACL `%R~revoked:*`로 읽기 전용이다. `socket_timeout` 0.2초.

## OpenAPI snapshot refresh

- 스냅샷은 의도적으로만 바뀐다: 의도한 API 변경이나 django-ninja 마이너 범프 후에 스위트를 실행하고, 스냅샷 diff를 라우트별로 검토한 뒤, 원인이 된 변경과 같은 커밋에 갱신된 스냅샷을 커밋한다. 빌드를 그린으로 만들려고 맹목적으로 재생성하지 않는다.

## Logging

- structlog JSON을 stdout으로, `ts level logger event request_id tenant_id sub_hash trace_id span_id` 필드로. 프로세서는 `authorization`, `cookie`, `x-authentik-signature`와 로깅되는 URL의 쿼리 스트링을 제거한다.
