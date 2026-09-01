# Contract: Django pod 템플릿 (`templates/django-pod`, copier)

`copier copy templates/django-pod apps/<pod>`로 생성되는 pod의 계약. 생성물은 수정 없이 테스트를 통과하고, `packages/django-common`에 의존한다.

## copier 질문 (`copier.yml`)

| 변수 | 예 | 규칙 |
|---|---|---|
| `pod_name` | `identity-admin` | kebab-case, 토픽 접두·이미지 이름·호스트 접두 |
| `pod_snake` | `identity_admin` | 자동 파생, Django 프로젝트·DB 이름 |
| `description` | 한 줄 | README·OpenAPI title |
| `owns_events` | `["session.revoked"]` | 발행 토픽 entity.event 목록 → `events/` 스텁·KafkaTopic 예시 생성 |
| `consumes_events` | `[]` | 소비 토픽 목록 → consumer 스텁 |
| `has_celery` | true | Celery 워커·beat 매니페스트 생성 여부 |
| `has_admin` | true | Django admin 활성 + `admin.joshuatech.dev` 호스트의 `PathPrefix(/<pod>)` Ingress(`FORCE_SCRIPT_NAME=/<pod>`) |

## 생성 트리

```
apps/<pod>/
├── pyproject.toml · uv.lock             # django, django-ninja, psycopg[binary], celery[redis], django-common(workspace), pytest…
├── Dockerfile                           # uv 빌드 스테이지 → python:3.13-slim 런타임, linux/arm64, USER app
├── compose.dev.yml                      # postgres:18, dragonfly, kafka(kraft) — 로컬 개발
├── env.example                          # 키만: DATABASE_URL, DATABASE_OWNER_URL, DRAGONFLY_URL, KAFKA_BOOTSTRAP, KAFKA_USERNAME, KAFKA_PASSWORD, AUTHENTIK_ISSUER, AUTHENTIK_JWKS_URL, AUTHENTIK_AUDIENCE, ACCESS_TEAM_DOMAIN, ACCESS_AUD, SENTRY_DSN, OTEL_EXPORTER_OTLP_ENDPOINT, ENV
├── manage.py
├── <pod_snake>/
│   ├── settings.py                      # pydantic-settings → django settings; 필수값 누락 시 ImproperlyConfigured
│   ├── urls.py · api.py                 # Ninja API(/health /ready 포함), OpenAPI /api/openapi.json
│   ├── core/                            # 도메인 앱 스텁(models.py에 TenantModel 상속 예)
│   ├── events/                          # outbox 발행 헬퍼 + 스키마 참조, consumers.py(선택)
│   └── management/commands/outbox_relay.py (django-common 재노출)
├── tests/
│   ├── conftest.py                      # testcontainers postgres·kafka·dragonfly fixture, owner/app role 생성
│   ├── test_health.py                   # /health 200, /ready 검사 3종
│   ├── test_tenant_rls.py               # 다른 tenant_id 0행, SET LOCAL 없으면 0행, owner role은 전체
│   ├── test_outbox.py                   # 같은 트랜잭션 INSERT → 릴레이 → Kafka consume, 실패 attempts
│   ├── test_auth_middleware.py          # JWKS 검증, iss/aud 불일치, 거부 목록, Access JWT
│   ├── test_logging.py                  # request_id·tenant_id·trace_id 필드
│   └── test_openapi_snapshot.py         # OpenAPI 스냅샷
└── deploy/base/                         # gitops로 복사되는 kustomize base(Deployment·Service·Ingress PLACEHOLDER·ExternalSecret·ServiceMonitor)
```

## 런타임 계약

| 항목 | 규칙 |
|---|---|
| 포트 | 8000(HTTP). Service 80 → 8000 |
| 프로브 | readiness `GET /ready`(5 s 주기), liveness `GET /health`(20 s) |
| DB 연결 | 앱은 `DATABASE_URL`(app role), 마이그레이션 Job은 `DATABASE_OWNER_URL`(owner role, 같은 alias `default`에 자격증명만 다름). `TenantContextMiddleware`가 직접 `transaction.atomic()`을 열고 그 안에서 `SELECT set_config('app.tenant_id', %s, true)`를 실행한 뒤 뷰를 호출한다(`ATOMIC_REQUESTS`는 뷰만 감싸므로 쓰지 않음; `SET LOCAL`은 bind 파라미터 불가; psycopg pool 사용 시 세션 GUC 금지). `StreamingHttpResponse`는 트랜잭션 밖에서 본문을 만들므로 DB 접근 금지 |
| 모델 | 도메인 모델은 `TenantModel`(추상: `tenant_id` UUID NOT NULL, 인덱스 `(tenant_id, id)`) 상속. 마이그레이션 헬퍼 `rls_policies(<table>)`가 ENABLE/FORCE/정책 SQL 생성 |
| 이벤트 | `publish(topic, subject, data)`는 `transaction.atomic()` 안에서만 호출 가능(밖이면 `OutboxUsageError`) |
| 인증 | `Authorization` Bearer(JWKS) + `Cf-Access-Jwt-Assertion` + 거부 목록. 헬스 엔드포인트는 Bearer 면제 |
| 로그 | structlog JSON stdout, 필드 `ts level logger event request_id tenant_id sub_hash trace_id span_id` |
| 메트릭 | `/metrics`(prometheus_client, 내부 포트 9100) — Alloy가 pod annotation으로 스크레이프 |
| 설정 | 12-factor, `ENV` ∈ dev·prod·test. 비밀은 env(ESO Secret)에서만 |
| 이미지 | `ghcr.io/joshua92y/<pod>@sha256:…`, 라벨 `org.opencontainers.image.revision` = git sha |
| 마이그레이션 | Argo PreSync hook Job(`manage.py migrate`, owner role). 앱은 마이그레이션을 실행하지 않는다 |

## 기본 테스트가 검증하는 것 (헌법 II)

1. RLS: tenant A 컨텍스트에서 tenant B 행 0, 컨텍스트 없음 0, owner role 전체.
2. outbox: INSERT + 커밋 → 릴레이 1회 → Kafka에서 CloudEvents 봉투 수신·스키마 통과 → 행 삭제; 프로듀서 실패 주입 → `attempts` 1·행 유지.
3. 인증: 유효 토큰 200 / 만료 401 / aud 불일치 401 / `revoked:sub` nbf > iat 401 / Access JWT 없음 403.
4. 헬스: `/health` 200; DB 다운 시 `/ready` 503.
5. 로그·OpenAPI: 필드 존재, 스냅샷 일치.

## django-common 공개 API (요약)

`django_common.tenancy`(`TenantModel`, `TenantMiddleware`, `rls_policies`), `django_common.outbox`(`OutboxEvent`, `publish`, `relay`), `django_common.auth`(`JwtAuthMiddleware`, `AccessJwtValidator`, `Denylist`), `django_common.observability`(`configure_logging`, `configure_otel`, `configure_sentry`, `RequestIdMiddleware`), `django_common.health`(`health_router`).
