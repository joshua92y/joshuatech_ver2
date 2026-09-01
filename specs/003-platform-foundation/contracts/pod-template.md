# Contract: Django pod 템플릿 (`templates/django-pod`, copier)

`copier copy templates/django-pod apps/<pod>`로 생성되는 pod의 계약. 생성물은 수정 없이 테스트를 통과하고, `packages/django-common`에 의존한다. 거부 목록 키·ACL은 contracts/denylist.md, 네트워크 허용은 contracts/network-policy.md, Vault 경로는 data-model §8.

## copier 질문 (`copier.yml`)

| 변수 | 예 | 규칙 |
|---|---|---|
| `pod_name` | `identity-admin` | kebab-case, 토픽 접두·이미지 이름·호스트 접두·Dragonfly 사용자·키 접두 |
| `pod_snake` | `identity_admin` | 자동 파생, Django 프로젝트·DB 이름 |
| `description` | 한 줄 | README·OpenAPI title |
| `owns_events` | `["session.revoked"]` | 발행 토픽 entity.event 목록 → `events/` 스텁·KafkaTopic 예시 생성 |
| `consumes_events` | `[]` | 소비 토픽 목록 → consumer 스텁 |
| `has_celery` | true | Celery 워커·beat 매니페스트 생성 여부(브로커 = Dragonfly, 사용자 `<pod>`) |
| `has_admin` | true | Django admin 활성 + prod overlay에 `admin.joshuatech.dev` 호스트 `PathPrefix(/<pod>)` Ingress. settings `ADMIN_HOST`·`FORCE_SCRIPT_NAME=/<pod>`; admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 장착(m2m 호스트에서 `/admin/`은 404) |

## 생성 트리

```
apps/<pod>/
├── pyproject.toml · uv.lock             # django 6.1, django-ninja==1.7.0(회귀 시 1.6.2 폴백), psycopg[binary], celery[redis], django-common(workspace), django-migration-linter, pytest…
├── Dockerfile                           # uv 빌드 스테이지 → python:3.13-slim 런타임, linux/arm64, USER app
├── compose.dev.yml                      # postgres:18, dragonfly(aclfile), kafka(kraft) — 로컬 개발
├── env.example                          # 키만: DATABASE_URL, DRAGONFLY_URL, KAFKA_BOOTSTRAP, KAFKA_USERNAME, KAFKA_PASSWORD, AUTHENTIK_ISSUER, AUTHENTIK_JWKS_URL, AUTHENTIK_AUDIENCE, ACCESS_TEAM_DOMAIN, ACCESS_AUD_M2M, ACCESS_AUD_ADMIN, ADMIN_HOST, ALLOWED_HOSTS, SENTRY_DSN, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_TRACES_SAMPLER, OTEL_TRACES_SAMPLER_ARG, ENV
│                                        # DATABASE_OWNER_URL은 migrate Job(`<pod>-migrate`) 전용 — 런타임 env에 없다
├── manage.py
├── <pod_snake>/
│   ├── settings.py                      # pydantic-settings → django settings; 필수값(ALLOWED_HOSTS·ADMIN_HOST 포함) 누락 시 ImproperlyConfigured; 메일은 MAILERS만(EMAIL_* 금지)
│   ├── urls.py · api.py                 # Ninja API(/healthz /ready /health 포함), OpenAPI /api/openapi.json, admin urlconf는 ADMIN_HOST 조건부
│   ├── core/                            # 도메인 앱 스텁(models.py에 TenantModel(A 등급)·GlobalModel(B 등급) 상속 예)
│   ├── events/                          # outbox 발행 헬퍼 + 스키마 참조, consumers.py(선택)
│   └── management/commands/outbox_relay.py (django-common 재노출)
├── tests/
│   ├── conftest.py                      # testcontainers postgres(TLS, sslmode require 이상)·kafka·dragonfly(aclfile: identity-admin·<pod> 사용자) fixture, owner/app role 생성; pytest -W error::DeprecationWarning
│   ├── test_health.py                   # /healthz 200(의존 없음) · /ready DB만(DB 다운 503, Dragonfly·Kafka 다운 200) · /health 항상 200 + checks 3종
│   ├── test_tenant_rls.py               # A 등급: 다른 tenant_id 0행, 컨텍스트 없음 0행, owner(bypassrls) 전체; B 등급: app role이 컨텍스트 없이 전체
│   ├── test_outbox.py                   # 같은 트랜잭션 INSERT → 릴레이(app role) → Kafka consume; 실패 attempts; max_attempts 10 → <pod>.dlq + dead_at
│   ├── test_auth_middleware.py          # JWKS, iss/aud 불일치, act.sub != web-bff 401, 거부 목록, Access JWT(AUD 2종), Dragonfly 실패 503, 헬스 면제
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

- owner role(`<pod_snake>_owner`)은 `bypassrls: true` — 마이그레이션·시드 전용, 런타임 pod에는 자격이 없다. app role(`<pod_snake>_app`)은 `NOBYPASSRLS`.
- `check_rls` management command(CI·기동 검사): A 등급 테이블 전부가 FORCE RLS + 정책을 갖는지, RLS 없는 테이블이 전부 B 등급 허용 목록에 있는지 검사. 둘 중 하나라도 어긋나면 실패.
- 허용 목록 밖의 B 등급 테이블 추가는 이 계약(과 `rules/django-pod.md`) 개정이 먼저다.

## 런타임 계약

| 항목 | 규칙 |
|---|---|
| 포트 | web 8000(HTTP), Service 80 → 8000. 메트릭: web 9100, relay 9464 |
| 프로브 3종 | liveness `GET /healthz`(20 s, 프로세스만) · readiness `GET /ready`(5 s, **DB만**) · startupProbe `GET /ready`(PreSync migrate Job 완료·기동 재적용까지 대기). `/health`(상세, 항상 200)는 프로브에 쓰지 않는다 |
| 배포 전략 | `RollingUpdate` `maxSurge: 1` / `maxUnavailable: 0`. 노드 A 선호 affinity(`preferredDuringScheduling`), CPU limit 없음. `reloader.stakater.com/auto: "true"` |
| requests | web 256Mi · relay 96Mi · migrate Job 256Mi · celery 192Mi (memory) |
| securityContext | pod: `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`, `automountServiceAccountToken: false`. 컨테이너(web·relay·celery·migrate 전부): `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: true` + `/tmp` emptyDir. PSA `restricted` 통과 |
| DB 연결 | `DATABASE_URL=postgresql://<pod_snake>_app:…@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`(app role, `<pod>-env`). CA는 Secret `pg-main-ca`(ESO kubernetes provider로 `identity`·`jt-dev`·`jt-prod`에 미러)를 `/etc/pg/ca.crt`에 마운트. 마이그레이션 Job만 `DATABASE_OWNER_URL`(owner role, `<pod>-migrate`, 같은 alias `default`에 자격증명만 다름). `TenantContextMiddleware`가 직접 `transaction.atomic()`을 열고 그 안에서 `SELECT set_config('app.tenant_id', %s, true)`를 실행한 뒤 뷰를 호출한다(`ATOMIC_REQUESTS`는 뷰만 감싸므로 쓰지 않음; `SET LOCAL`은 bind 파라미터 불가; psycopg pool 사용 시 세션 GUC 금지). `StreamingHttpResponse`는 트랜잭션 밖에서 본문을 만들므로 DB 접근 금지. app role: `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| 모델 | A 등급 `TenantModel` / B 등급 `GlobalModel`(위 표). 마이그레이션 헬퍼 `rls_policies(<table>)`가 ENABLE/FORCE/정책 SQL(+reverse) 생성 |
| 이벤트 | `publish(topic, subject, data)`는 `transaction.atomic()` 안에서만 호출 가능(밖이면 `OutboxUsageError`). `tenantid` = UUID. 릴레이는 app role, `max_attempts 10` → `<pod>.dlq` + `dead_at` |
| 인증 | `Authorization` Bearer(JWKS + `iss`·`aud`·`exp`·`nbf` + **`act.sub == web-bff`**) + `Cf-Access-Jwt-Assertion`(`aud ∈ {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN}`, ConfigMap) + 거부 목록(`revoked:sub:{sub}`·`revoked:sid:{sid}`, **조회 실패 = 503 `denylist-unavailable` fail-closed**, 0.2 s). 면제: 헬스 3종. 웹훅 경로는 pod가 면제 목록에 명시하고 HMAC + 타임스탬프 ±5분 + 멱등 키로 대신한다 |
| Dragonfly | `DRAGONFLY_URL=redis://<pod>:…@dragonfly-<env>.data.svc:6379/0`(사용자 = pod 이름, ACL `~revoked:* +@read ~<pod>:* +@all`). 모든 자기 키는 `<pod>:` 접두(Celery `broker_transport_options.global_keyprefix`, 캐시 `KEY_PREFIX`). `socket_timeout` 0.2 s |
| Kafka | SASL_SSL SCRAM-SHA-512 사용자 `<pod>`/`dev-<pod>`, CA `jt-kafka-cluster-ca-cert` 미러 마운트, producer `delivery.timeout.ms` 30000 |
| 로그 | structlog JSON stdout, 필드 `ts level logger event request_id tenant_id sub_hash trace_id span_id`. processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거하고 URL 쿼리스트링을 남기지 않는다 |
| 메트릭 | web `/metrics`(prometheus_client 9100) · relay `/metrics`(9464) — pod annotation `k8s.grafana.com/scrape: "true"`로 Alloy가 스크레이프. relay: `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total` |
| 트레이스 · Sentry | OTLP → Alloy(`monitoring` 4317/4318), `OTEL_TRACES_SAMPLER=parentbased_traceidratio`·`OTEL_TRACES_SAMPLER_ARG=0.1`. Sentry errors only, `send_default_pii=False`, `before_send`로 `Authorization`·`Cookie`·`CF-Access-*` 제거, release = 이미지 digest |
| 설정 | 12-factor, `ENV` ∈ dev·prod·test. 비밀은 env(ESO `<pod>-env`)에서만, 비밀 아닌 값(`ACCESS_AUD_*`·`ADMIN_HOST`·`ALLOWED_HOSTS`)은 ConfigMap. `ALLOWED_HOSTS` = svc DNS(`<pod>.<ns>.svc`)·m2m 호스트·admin 호스트 |
| 이미지 | `ghcr.io/joshua92y/<pod>@sha256:…`, 라벨 `org.opencontainers.image.revision` = git sha |
| 마이그레이션 | Argo PreSync hook Job(`manage.py migrate`, owner role, `<pod>-migrate`만 참조). 앱은 마이그레이션을 실행하지 않는다. 2단계 규칙(`rules/django-pod.md`): 컬럼 삭제·NOT NULL 추가·타입 변경은 expand → contract 두 릴리스로 나눈다. CI: `makemigrations --check` + `django-migration-linter` |
| Celery(`has_celery`) | 워커·beat Deployment(requests 192Mi), 브로커 = 위 Dragonfly 사용자. pod 고유 beat 작업(identity-admin: 30 s 거부 목록 대조·`reconcile_authentik_sessions`·purge)은 해당 pod 계약에 적는다 |

## 타임아웃 · 재시도

| 구간 | 값 |
|---|---|
| BFF → pod fetch(참고) | 3 s(AbortController), 재시도 없음 |
| pod → Authentik | 5 s × 3회 지수 백오프(최대 5분, Celery) |
| Kafka producer `delivery.timeout.ms` | 30000 |
| Dragonfly `socket_timeout` | 0.2 s → 실패 시 503(fail-closed) |
| PG app role | `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| ESO `refreshInterval` | 5m |
| BFF `/session/check` 캐시(참고) | 2 s |

## 기본 테스트가 검증하는 것 (헌법 II)

1. RLS: A 등급 — tenant A 컨텍스트에서 tenant B 행 0, 컨텍스트 없음 0, owner role(bypassrls) 전체. B 등급 — app role이 컨텍스트 없이 전체를 읽음, 허용 목록 밖 테이블이 RLS 없이 있으면 `check_rls` 실패.
2. outbox: INSERT + 커밋 → 릴레이(app role) 1회 → Kafka에서 CloudEvents 봉투 수신·스키마 통과 → 행 삭제; 테넌트 A·B 행 모두 릴레이되고 `tenantid`·파티션 키 일치; 프로듀서 실패 주입 → `attempts` 1·행 유지; 10회 → `<pod>.dlq` + `dead_at`.
3. 인증: 유효 토큰 200 / 만료 401 / aud 불일치 401 / `act.sub` 불일치 401 / `revoked:sub` nbf > iat 401 / `revoked:sid` 401 / Access JWT 없음 403 / admin AUD 허용 / Dragonfly 다운 → 비헬스 503·헬스 200 / m2m 호스트 `/admin/` 404.
4. 헬스: `/healthz` 200; DB 다운 시 `/ready` 503, Dragonfly 다운 시 `/ready` 200; `/health`는 항상 200에 `checks` 반영.
5. 로그·OpenAPI·마이그레이션: 필드 존재·마스킹, 스냅샷 일치, `makemigrations --check` 통과.
6. 생성물 검사(T064): `automountServiceAccountToken: false`·securityContext·프로브 3종·RollingUpdate·requests 값, Deployment `envFrom`에 `-migrate` 없음, DB URL `sslmode=verify-full`.

## django-common 공개 API (요약)

`django_common.tenancy`(`TenantModel`, `GlobalModel`, `TenantContextMiddleware`, `rls_policies`, `check_rls`), `django_common.outbox`(`OutboxEvent`, `publish`, `relay`), `django_common.auth`(`JwtAuthMiddleware`, `AccessJwtValidator`, `Denylist`), `django_common.observability`(`configure_logging`, `configure_otel`, `configure_sentry`, `RequestIdMiddleware`), `django_common.health`(`health_router`: `/healthz`·`/ready`·`/health`).
