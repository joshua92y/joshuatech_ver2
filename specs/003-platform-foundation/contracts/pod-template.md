# Contract: Django pod 템플릿 (`templates/django-pod`, copier)

`copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>`로 생성되는 pod의 계약(`--trust`는 `copier.yml`의 `_tasks: uv lock` 때문에 필수 — 2026-11-02 T065). 생성물은 수정 없이 테스트를 통과하고, `packages/django-common`에 의존한다. 거부 목록 키·ACL은 contracts/denylist.md, 네트워크 허용은 contracts/network-policy.md, Vault 경로는 data-model §8.

**생성 위치·버전 규칙(2026-11-02 T065 보정)**: pod 디렉터리는 저장소 루트 기준 `apps/<pod>`에 있고 `packages/django-common`은 두 단계 위의 형제다 — 템플릿은 이 상대 배치(`../../packages/django-common`) 하나만 가정하므로 다른 깊이(예: `tests/fixtures/generated/<pod>`)에 바로 생성하면 의존성이 풀리지 않는다(검사 하네스는 임시 미니 저장소 `<tmp>/apps/sample-pod` + `<tmp>/packages/django-common` 복사본으로 같은 배치를 재현한다 — 아래 §기본 테스트 6). 모노레포 안의 템플릿 경로는 git 저장소 루트가 아니므로 copier는 clone·태그 선택 없이 **작업 트리를 그대로** 읽고 `.copier-answers.yml`에 `_commit`을 남기지 않는다 → `copier update`는 SP-1에서 지원하지 않는다(재생성 뒤 diff로 갱신; 템플릿을 태그가 있는 독립 저장소로 내는 것은 후속 기능 — research DJANGO-D18의 "저장소 `pod-template`" 가정과의 편차, report.md 후보).

## copier 질문 (`copier.yml`)

| 변수 | 예 | 규칙 |
|---|---|---|
| `pod_name` | `identity-admin` | kebab-case, 토픽 접두·이미지 이름·호스트 접두·Dragonfly 사용자·키 접두 |
| `pod_snake` | `identity_admin` | 자동 파생, Django 프로젝트·DB 이름 |
| `description` | 한 줄 | README·OpenAPI title |
| `owns_events` | `["session.revoked"]` | 발행 토픽 entity.event 목록 → `events/` 스텁·KafkaTopic 예시 생성 |
| `consumes_events` | `[]` | 소비 토픽 목록 → consumer 스텁 |
| `has_celery` | true | Celery 워커·beat 매니페스트 생성 여부(브로커 = Dragonfly, 사용자 `<pod>`) |
| `has_admin` | true | Django admin 활성 + prod overlay에 `admin.joshuatech.dev` 호스트 `PathPrefix(/<pod>)` Ingress. settings `ADMIN_HOST`·`FORCE_SCRIPT_NAME=/<pod>`; admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 장착(m2m 호스트에서 `/admin/`은 404). **dev overlay의 `ADMIN_HOST`는 빈 값** — 빈 값이면 admin urlconf를 아예 장착하지 않고 dev에는 admin Ingress도 만들지 않는다(dev 관리자 표면 0) |

## 생성 트리

```
apps/<pod>/
├── pyproject.toml · uv.lock             # django 6.1, django-ninja==1.7.0(회귀 시 1.6.2 폴백), psycopg[binary], celery[redis], django-common(uv `tool.uv.sources` **path** `../../packages/django-common` · editable — pod는 루트 uv 워크스페이스의 멤버가 **아닌** 독립 프로젝트로 자기 `uv.lock`을 가진다: copier `_tasks: uv lock`이 이 디렉터리에 잠금을 만들고 CI·이미지는 `uv sync --locked`로 그 잠금을 쓴다; 루트 `pyproject.toml` `members`에서 pod를 빼고 `exclude = ["apps/*", "templates/*"]`로 명시 — T073 · 2026-11-02 T065), django-migration-linter, pytest…
├── Dockerfile                           # uv 빌드 스테이지 → python:3.13-slim 런타임, linux/arm64, USER app. **빌드 컨텍스트 = 저장소 루트**(`packages/django-common`을 함께 COPY해야 하므로): `docker buildx build --platform linux/arm64 -f apps/<pod>/Dockerfile -t <pod>:<tag> .` · `publish-pod.yml`은 `context: .` + `file: apps/<pod>/Dockerfile`; 이미지 안에서도 `/src/apps/<pod>` + `/src/packages/django-common`처럼 상대 경로 `../../packages/django-common`이 그대로 풀리는 배치를 유지한다(2026-11-02 T065)
├── compose.dev.yml                      # postgres:18, dragonfly(aclfile), kafka(kraft) — 로컬 개발
├── env.example                          # 키만: DATABASE_URL, DRAGONFLY_URL, KAFKA_BOOTSTRAP, KAFKA_USERNAME, KAFKA_PASSWORD, AUTHENTIK_ISSUER(공개 URL), AUTHENTIK_JWKS_URL(svc DNS), AUTHENTIK_AUDIENCE, ACCESS_TEAM_DOMAIN, ACCESS_AUD_M2M, ACCESS_AUD_ADMIN, ACCESS_EXPECTED_CN, AUTH_ACTOR_SUB(선택·기본 빈 값), ADMIN_HOST(dev 빈 값), ALLOWED_HOSTS, SENTRY_DSN, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_TRACES_SAMPLER, OTEL_TRACES_SAMPLER_ARG, ENV
│                                        # DATABASE_OWNER_URL은 migrate Job(`<pod>-migrate`) 전용 — 런타임 env에 없다
├── manage.py
├── <pod_snake>/
│   ├── settings.py                      # pydantic-settings → django settings; 필수값(ALLOWED_HOSTS·ADMIN_HOST 포함) 누락 시 ImproperlyConfigured; 메일은 MAILERS만(EMAIL_* 금지)
│   ├── urls.py · api.py                 # Ninja API(/healthz /ready /health 포함), OpenAPI /api/openapi.json, admin urlconf는 ADMIN_HOST 조건부
│   ├── core/                            # 도메인 앱 스텁(models.py에 TenantModel(A 등급)·GlobalModel(B 등급) 상속 예)
│   ├── events/                          # outbox 발행 헬퍼 + 스키마 참조, consumers.py(선택)
│   └── management/commands/outbox_relay.py (django-common 재노출)
├── tests/
│   ├── conftest.py                      # testcontainers postgres(TLS, sslmode require 이상)·kafka·dragonfly(aclfile: `identity-admin`·`<pod>`(`%R~revoked:*`) 사용자) fixture, owner/app role 생성; DeprecationWarning은 오류로 승격하되 pytest `filterwarnings = ["error::DeprecationWarning:<자기 모듈>", …]`처럼 **자기 모듈로 한정**(전역 `-W error` 금지 — 의존 라이브러리의 경고로 스위트가 죽지 않게 · 2026-11-02 T060 문면 정정)
│   ├── test_health.py                   # /healthz 200(의존 없음) · /ready DB만(DB 다운 503, Dragonfly·Kafka 다운 200) · /health 항상 200 + checks 3종
│   ├── test_tenant_rls.py               # A 등급: 다른 tenant_id 0행, 컨텍스트 없음 0행, owner(bypassrls) 전체; B 등급: app role이 컨텍스트 없이 전체
│   ├── test_outbox.py                   # atomic 밖 publish → OutboxUsageError; 컨텍스트·인자 둘 다 없음 → OutboxUsageError; tenant_id 인자 명시 경로; 같은 트랜잭션 INSERT → 릴레이(app role, dead_at IS NULL만) → Kafka consume; 실패 attempts; max_attempts 10 → <pod>.dlq + dead_at; dead_at + 30 d purge
│   ├── test_auth_middleware.py          # JWKS, iss/aud 불일치, Access JWT(AUD 2종)·common_name 식별, `AUTH_ACTOR_SUB` 설정 시 act.sub 불일치 401·미설정 시 act 없어도 통과, 거부 목록, Dragonfly 실패 503, 헬스 면제
│   ├── test_logging.py                  # request_id·tenant_id·trace_id 필드, authorization·cookie·x-authentik-signature 부재
│   ├── test_migrations.py               # makemigrations --check, django-migration-linter(파괴적 연산 검출)
│   └── test_openapi_snapshot.py         # OpenAPI 스냅샷(ninja minor bump 시 갱신 절차는 rules/django-pod.md)
└── deploy/base/                         # gitops로 복사되는 kustomize base: Deployment(web+relay)·celery Deployment(has_celery)·Service·Ingress PLACEHOLDER·ConfigMap·ExternalSecret 2(<pod>-env·<pod>-migrate)·PreSync migrate Job·kustomization
```

## 테이블 등급 (헌법 III · FR-034)

| 등급 | 모델 | RLS | 접근 |
|---|---|---|---|
| **A 테넌트 범위** | `TenantModel` 상속(`tenant_id` UUID NOT NULL, 인덱스 `(tenant_id, id)`) | `ENABLE` + `FORCE ROW LEVEL SECURITY` + 정책 `tenant_isolation`(`rls_policies(<table>)`) | 요청 트랜잭션의 `app.tenant_id` 컨텍스트로만. 컨텍스트 없으면 0행 |
| **B pod 전역** | `GlobalModel` 상속. 허용 목록: `tenant`, `tenant_membership`, `outbox`, `session_revocation_log` | 미적용 | app role이 컨텍스트 없이 읽고 쓴다: outbox 릴레이·Authentik 웹훅·기동 시 거부 목록 재적용·`/tenants/me` |

- owner role(prod `<pod_snake>_owner` / dev `dev_<pod_snake>_owner`)은 `bypassrls: true` — 마이그레이션·시드 전용, 런타임 pod에는 자격이 없다. app role(`<pod_snake>_app` / `dev_<pod_snake>_app`)은 `NOBYPASSRLS`.
- `check_rls` management command(CI·기동 검사): A 등급 테이블 전부가 ENABLE + FORCE RLS + 정책을 갖는지(`pg_class.relrowsecurity`·`relforcerowsecurity` 둘 다), RLS 없는 테이블이 전부 B 등급 허용 목록 또는 아래 프레임워크 면제 목록에 있는지 검사(모델이 아닌 테이블도 카탈로그에서 센다). 하나라도 어긋나면 테이블 이름을 담아 실패.
- **프레임워크 면제(2026-11-02 T060 리뷰 A-2/B-1)**: Django가 만드는 테이블은 등급 분류 대상이 아니다(테넌트 데이터 없음) — **정확한 이름 목록 10** `django_migrations` · `django_content_type` · `django_session` · `django_admin_log` · `auth_permission` · `auth_group` · `auth_group_permissions` · `auth_user` · `auth_user_groups` · `auth_user_user_permissions` = `django_common.tenancy.FRAMEWORK_TABLES` 상수로 고정한다. pod가 넓힐 수 없고 접두(`django_*`) 규칙은 쓰지 않는다. 목록 밖 contrib 앱 테이블이 필요하면 이 계약(과 `rules/django-pod.md`) 개정이 먼저다.
- 허용 목록 밖의 B 등급 테이블 추가는 이 계약(과 `rules/django-pod.md`) 개정이 먼저다.

## 런타임 계약

| 항목 | 규칙 |
|---|---|
| 포트 | web 8000(HTTP), Service 80 → 8000. 메트릭: web 9100, relay 9464 |
| 프로브 3종(web 컨테이너) | liveness `GET /healthz`(20 s, 프로세스만) · readiness `GET /ready`(5 s, **DB만**) · **startupProbe** `GET /ready` — 목적은 "**마이그레이션 직후 첫 DB 연결 대기**"다(PreSync migrate Job이 끝난 직후 커넥션·GUC 설정·거부 목록 기동 재적용이 완료될 때까지 liveness가 pod를 죽이지 않게 한다). **`failureThreshold: 30` × `periodSeconds: 5`(최대 150 s)**. `/health`(상세, 항상 200)는 어떤 프로브에도 쓰지 않는다. kubelet HTTP 프로브의 기본 `Host` 헤더는 **pod IP**(`<podIP>:8000`)라 `ALLOWED_HOSTS` 검증과 부딪힌다 — 템플릿이 해결한다(프로브 `httpHeaders`의 `Host` 또는 downward API `POD_IP`를 `ALLOWED_HOSTS`에 더하기 · 선택은 T072 · T066 보정 2026-11-03) |
| relay 컨테이너 프로브 | liveness = **TCP 9464**(메트릭 포트) — 릴레이는 HTTP 엔드포인트가 없으므로 포트 개방 여부로 살아 있음을 본다. readiness·startupProbe 없음 |
| 배포 전략 | `RollingUpdate` `maxSurge: 1` / `maxUnavailable: 0`. 노드 A 선호 affinity(`preferredDuringScheduling`), CPU limit 없음. `reloader.stakater.com/auto: "true"` |
| requests | web 256Mi · relay 96Mi · migrate Job 256Mi · celery 192Mi (memory) |
| securityContext | pod: `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`, `automountServiceAccountToken: false`. 컨테이너(web·relay·celery·migrate 전부): `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true` + `/tmp` emptyDir. PSA `restricted` 통과 |
| DB·role 이름 | database·role은 **env마다 분리**한다. prod = `<pod_snake>` / `<pod_snake>_owner` · `<pod_snake>_app`, dev = **`dev_<pod_snake>`** / **`dev_<pod_snake>_owner`** · **`dev_<pod_snake>_app`**. PG role은 클러스터 전역이라 하나의 role이 두 환경의 비밀번호를 가질 수 없고, 같은 role을 공유하면 dev pod가 prod DB에 붙을 수 있다(`jt-dev → data:5432`가 허용되므로 네트워크로는 막히지 않는다). 공유 컴포넌트 `authentik`·`openfga`는 pod가 아니므로 이 접두 규칙 밖이다(database·role 이름 그대로, env 분리 없음) |
| DB 연결 | `DATABASE_URL=postgresql://<role>:…@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`(app role, `<pod>-env`; dev overlay는 `dev_` 접두 role·DB). CA는 Secret `pg-main-ca`(ESO store `k8s-data-ca`로 `identity`·`jt-dev`·`jt-prod`에 미러, `ca.crt`만)를 `/etc/pg/ca.crt`에 마운트. 마이그레이션 Job만 `DATABASE_OWNER_URL`(owner role, `<pod>-migrate`, 같은 alias `default`에 자격증명만 다름). `TenantContextMiddleware`가 직접 `transaction.atomic()`을 열고 그 안에서 `SELECT set_config('app.tenant_id', %s, true)`를 실행한 뒤 뷰를 호출한다(`ATOMIC_REQUESTS`는 뷰만 감싸므로 쓰지 않음; `SET LOCAL`은 bind 파라미터 불가; psycopg pool 사용 시 세션 GUC 금지). `StreamingHttpResponse`는 트랜잭션 밖에서 본문을 만들므로 DB 접근 금지. app role: `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| 모델 | A 등급 `TenantModel` / B 등급 `GlobalModel`(위 표). 마이그레이션 헬퍼 `rls_policies(<table>)`가 ENABLE/FORCE/정책 SQL(+reverse) 생성 |
| 이벤트 | **`publish(topic, subject, data, *, tenant_id=None)`** — `transaction.atomic()` 안에서만 호출 가능하고, `tenant_id`를 생략하면 요청의 테넌트 컨텍스트에서 읽는다. **컨텍스트도 인자도 없으면 `OutboxUsageError`**(웹훅·관리자 경로는 반드시 인자를 넘긴다). `tenantid` = UUID. 릴레이는 app role, `dead_at IS NULL`만 선택, `max_attempts 10` → `<pod>.dlq` + `dead_at`, `dead_at + 30 d` purge(contracts/events.md) |
| 인증 | `Authorization` Bearer(JWKS(**svc DNS**) + `iss`(공개 URL)·`aud`·`exp`·`nbf`) + `Cf-Access-Jwt-Assertion`(`aud ∈ {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN}` + `common_name == ACCESS_EXPECTED_CN`, 전부 ConfigMap) + 거부 목록(`revoked:sub:{sub}`·`revoked:sid:{sid}`, **조회 실패 = 503 `denylist-unavailable` fail-closed**, 0.2 s). 호출자 식별의 기본은 Access `common_name`이고, **`AUTH_ACTOR_SUB`가 설정된 경우에만** Bearer의 `act.sub`를 추가로 검증한다(미설정 = impersonation 모드, contracts/identity-admin-api.md §호출자 식별·VD-1). 면제: 헬스 3종. 웹훅 경로는 pod가 면제 목록에 명시하고 HMAC + 타임스탬프 ±5분 + 멱등 키로 대신한다 |
| Dragonfly | `DRAGONFLY_URL=redis://<pod>:…@dragonfly-<env>.data.svc:6379/0`(사용자 = pod 이름, ACL **`%R~revoked:* ~<pod>:* +@all`** — 읽기 전용은 `%R~` 패턴으로만 표현한다, contracts/denylist.md). 모든 자기 키는 `<pod>:` 접두(Celery `broker_transport_options.global_keyprefix`, 캐시 `KEY_PREFIX`). `socket_timeout` 0.2 s |
| Kafka | SASL_SSL SCRAM-SHA-512 사용자 `<pod>`/`dev-<pod>`, CA `jt-kafka-cluster-ca-cert` 미러 마운트, producer `delivery.timeout.ms` 30000 |
| 로그 | structlog JSON stdout, 필드 `ts level logger event request_id tenant_id sub_hash trace_id span_id`. processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거하고 URL 쿼리스트링을 남기지 않는다 |
| 메트릭 | web `/metrics`(prometheus_client 9100) · relay `/metrics`(9464) — pod annotation `k8s.grafana.com/scrape: "true"`로 Alloy가 스크레이프. relay: `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total` |
| 트레이스 · Sentry | OTLP → Alloy(`monitoring` 4317/4318), `OTEL_TRACES_SAMPLER=parentbased_traceidratio`·`OTEL_TRACES_SAMPLER_ARG=0.1`. Sentry errors only, `send_default_pii=False`, `before_send`로 `Authorization`·`Cookie`·`CF-Access-*` 제거, release = 이미지 digest |
| 설정 | 12-factor, `ENV` ∈ dev·prod·test. 비밀은 env(ESO `<pod>-env`)에서만, 비밀 아닌 값(`ACCESS_AUD_*`·`ACCESS_EXPECTED_CN`·`AUTH_ACTOR_SUB`·`ADMIN_HOST`·`ALLOWED_HOSTS`·`IDENTITY_M2M_URL`)은 ConfigMap. `ALLOWED_HOSTS` = svc DNS(`<pod>.<ns>.svc`)·m2m 호스트·(prod만) admin 호스트. `AUTH_ACTOR_SUB`와 dev의 `ADMIN_HOST`는 **빈 값이 유효한 값**이다(각각 검사 생략·admin 비활성) — 필수값 검사에서 "존재"만 보고 "비어 있지 않음"을 요구하지 않는다. 클러스터 안 서비스 URL(`AUTHENTIK_JWKS_URL` 등 pod가 직접 부르는 URL)의 호스트가 공개 도메인 `joshuatech.dev`이거나 그 하위면 `ImproperlyConfigured`로 기동을 멈춘다(pod는 공개 호스트를 부르지 않는다 — FR-046 · T066 보정 2026-11-03) |
| 오류 | 응답 오류는 RFC 9457 `application/problem+json`(`type` = `https://joshuatech.dev/problems/<슬러그의 _를 ->` · `title` · `status` · 선택 `detail` — 토큰·비밀·자격 URL 금지). **요청 검증 실패**(쿼리 누락·타입 오류·enum 밖 값·JSON이 아닌 본문)는 400 `validation_error`로 바꾼다 — Ninja 기본 422 `{detail}`를 쓰지 않는다(T066 보정 2026-11-03). `ALLOWED_HOSTS` 밖 호스트는 업무 경로에서 인증보다 먼저 400 |
| 이미지 | `ghcr.io/joshua92y/<pod>@sha256:…`, 라벨 `org.opencontainers.image.revision` = git sha. 빌드 컨텍스트 = 저장소 루트 + `-f apps/<pod>/Dockerfile`(생성 트리의 Dockerfile 행), 런타임 USER 비-root, 아키텍처 arm64 |
| 마이그레이션 | Argo PreSync hook Job(owner role, `<pod>-migrate`만 참조). 앱은 마이그레이션을 실행하지 않는다. **Job의 첫 단계는 CONNECT 경계 SQL**(멱등, `manage.py migrate` 앞): `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC; GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner;` — CNPG `Database` CRD로는 표현할 수 없어 실행 주체를 여기로 고정한다(role은 클러스터 전역이므로 이 SQL이 없으면 어떤 role이든 붙을 수 있다). 그다음 `manage.py migrate`. 2단계 규칙(`rules/django-pod.md`): 컬럼 삭제·NOT NULL 추가·타입 변경은 expand → contract 두 릴리스로 나눈다. CI: `makemigrations --check` + `django-migration-linter` |
| Celery(`has_celery`) | 워커·beat Deployment(requests 192Mi), 브로커 = 위 Dragonfly 사용자. **템플릿 기본 beat 작업은 outbox dead purge 하나뿐**(일 1회, `dead_at + 30 d < now()` 행 삭제 — contracts/events.md; `session_revocation_log` purge는 identity-admin 소유 테이블이라 템플릿에 두지 않는다). pod 고유 beat 작업(identity-admin: 30 s 거부 목록 무조건 재적용·`reconcile_authentik_sessions`·`session_revocation_log` purge)은 해당 pod 계약에 적는다(T073) |

## 타임아웃 · 재시도

| 구간 | 값 |
|---|---|
| BFF → pod fetch(참고) | 3 s(AbortController), 재시도 없음 → 초과 시 BFF가 **503 `upstream_unavailable`** |
| pod → Authentik | 5 s × 3회 지수 백오프(최대 5분, Celery) |
| Kafka producer `delivery.timeout.ms` | 30000 |
| Dragonfly `socket_timeout` | 0.2 s → 실패 시 503(fail-closed) |
| PG app role | `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| ESO `refreshInterval` | 5m |
| BFF `/session/check` 캐시(참고) | 2 s |

## 기본 테스트가 검증하는 것 (헌법 II)

1. RLS: A 등급 — tenant A 컨텍스트에서 tenant B 행 0, 컨텍스트 없음 0, owner role(bypassrls) 전체. B 등급 — app role이 컨텍스트 없이 전체를 읽음, 허용 목록 밖 테이블이 RLS 없이 있으면 `check_rls` 실패.
2. outbox: `publish`를 `transaction.atomic()` 밖에서 부르면 `OutboxUsageError`, 테넌트 컨텍스트도 `tenant_id` 인자도 없으면 `OutboxUsageError`; INSERT + 커밋 → 릴레이(app role, `dead_at IS NULL`) 1회 → Kafka에서 CloudEvents 봉투 수신·스키마 통과 → 행 삭제; 테넌트 A·B 행 모두 릴레이되고 `tenantid`·파티션 키 일치; 프로듀서 실패 주입 → `attempts` 1·행 유지; 10회 → `<pod>.dlq` + `dead_at`; dead 행은 다시 집히지 않고 `dead_at + 30 d`에 purge.
3. 인증: 유효 토큰 200 / 만료 401 / aud 불일치 401 / Access JWT 없음 403 / `common_name` 불일치 403 / admin AUD 허용 / **`AUTH_ACTOR_SUB` 설정 시** `act.sub` 불일치 401·**미설정 시** `act` 없어도 200 / `revoked:sub` nbf > iat 401 / `revoked:sid` 401 / Dragonfly 다운 → 비헬스 503·헬스 200 / m2m 호스트 `/admin/` 404 / `ADMIN_HOST` 빈 값으로 기동 시 admin urlconf 부재.
4. 헬스: `/healthz` 200; DB 다운 시 `/ready` 503, Dragonfly 다운 시 `/ready` 200; `/health`는 항상 200에 `checks` 반영.
5. 로그·OpenAPI·마이그레이션: 필드 존재·마스킹, 스냅샷 일치, `makemigrations --check` 통과.
6. 생성물 검사(T065 하네스 `templates/django-pod/tests/` — 자기 `pyproject.toml`·`uv.lock`을 가진 독립 프로젝트, `uv run --directory templates/django-pod --locked pytest -q`, Docker·`kustomize`·`kubeconform`이 PATH에 있어야 한다; 생성 트리는 임시 미니 저장소에 만들고 `JT_SAMPLE_POD_ROOT=<dir>`로 보존할 수 있다(상대 경로는 **저장소 루트 기준** — `uv run --directory`가 cwd를 바꾸므로; 저장소 루트·그 상위·템플릿 디렉터리 아래는 거부) — 하네스는 자기가 만든 디렉터리(표식 파일 `.jt-sample-pod-root`)만 지운다):
   - 생성물 자체: `copier copy --trust --defaults --data pod_name=sample-pod` 성공 · `.copier-answers.yml`(`pod_name`) · 생성 트리 파일(위 표) · `pyproject.toml`의 `django-ninja==1.7.0` 정확 핀 · `django-migration-linter` dev 의존 · pytest `filterwarnings`가 `error::DeprecationWarning:<pod_snake>`로 한정(전역 `-W error` 없음) · `--tb=short` · `env.example` 키 20(값 없음 · `DATABASE_OWNER_URL` 없음) · 내장 테스트 7파일 · `uv sync --locked` 성공 · 생성물 `pytest` 전부 통과(실패 0 · 오류 0 · skip 0 · 6종 + `makemigrations --check` + migration linter) · `docker buildx build --platform linux/arm64`(컨텍스트 = 미니 저장소 루트) 성공 + 이미지 아키텍처 arm64 + USER 비-root.
   - 렌더(`kustomize build deploy/base` → `kubeconform -strict -ignore-missing-schemas` 통과 · 검증 객체 ≥ 1): Deployment web+relay · celery Deployment · migrate Job(Argo `PreSync` hook) 전부에 `automountServiceAccountToken: false` · pod `runAsNonRoot` · `seccompProfile RuntimeDefault` · 컨테이너 `allowPrivilegeEscalation false` · `capabilities.drop [ALL]` · `readOnlyRootFilesystem true` + `/tmp` emptyDir 마운트 / web 프로브 3종(liveness `/healthz` · readiness `/ready` · startupProbe `/ready` `failureThreshold 30` × `periodSeconds 5`) · relay liveness TCP 9464(readiness·startupProbe 없음) · `/health`는 어떤 프로브에도 없음 / RollingUpdate `maxSurge 1`/`maxUnavailable 0`(Deployment 2) · requests(web 256Mi · relay 96Mi · migrate 256Mi · celery 192Mi) · CPU limit 부재 · 노드 A 선호 affinity(`preferredDuringScheduling` `role=platform`, Deployment 2) / Deployment·celery `envFrom`에 `<pod>-migrate` 없음 · migrate Job은 `<pod>-migrate`만(`<pod>-env` 없음) / ExternalSecret 2(`<pod>-env`·`<pod>-migrate`)의 DB URL `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` · `pg-main-ca` → `/etc/pg/ca.crt` 마운트(web·relay·celery·migrate) / migrate Job 첫 단계 명령에 `REVOKE CONNECT ON DATABASE … FROM PUBLIC` + `GRANT CONNECT ON DATABASE` 멱등 SQL이 `migrate`보다 앞에 존재 / 어노테이션 `reloader.stakater.com/auto: "true"`(Deployment 2) · `k8s.grafana.com/scrape: "true"`(web pod 템플릿, relay 컨테이너 포트 9464) / ConfigMap 키 `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ACCESS_EXPECTED_CN`·`ADMIN_HOST`·`ALLOWED_HOSTS`(선택 `AUTH_ACTOR_SUB`) / Ingress PLACEHOLDER 경로 집합 = `/api`·`/health`·`/session`·`/sessions`·`/tenants`(`/healthz`·`/ready`·`/webhooks` 없음 · admin Ingress는 prod overlay라 base에 없음).

## django-common 공개 API (요약)

`django_common.tenancy`(`TenantModel`, `GlobalModel`, `TenantContextMiddleware`, `rls_policies`, `check_rls`), `django_common.outbox`(`OutboxEvent`, `publish`, `relay`), `django_common.auth`(`JwtAuthMiddleware`, `AccessJwtValidator`, `Denylist`), `django_common.observability`(`configure_logging`, `configure_otel`, `configure_sentry`, `RequestIdMiddleware`), `django_common.health`(`health_router`: `/healthz`·`/ready`·`/health`).
