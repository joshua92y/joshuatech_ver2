# Contract: identity-admin API (SP-1 범위)

Django 6.1 + Ninja 1.7(`ninja==1.7.0` 정확 핀, 회귀 시 1.6.2 폴백). 오류는 RFC 9457. 응답 헤더에 `x-request-id`를 되돌린다. 저장 규칙은 data-model §1–3(테이블 등급 B), 거부 목록 키는 contracts/denylist.md.

## 호스트 · Ingress 경로 · Access AUD

| 호스트 | Ingress 경로(허용 목록, PathPrefix) | Access 앱 → AUD | 용도 |
|---|---|---|---|
| `identity-m2m-prod.joshuatech.dev` · `identity-m2m-dev.joshuatech.dev` | `/api` · `/health` · `/healthz` · `/ready` · `/session` · `/sessions` · `/tenants` · `/webhooks` | Service Auth 앱(`web-bff-<env>` 토큰) → `ACCESS_AUD_M2M` | BFF 호출. 그 외 경로(`/admin/` 포함)는 Ingress에 없어 404 |
| `admin.joshuatech.dev`(PathPrefix `/identity-admin`, prod만) | `/identity-admin/admin/…`(`FORCE_SCRIPT_NAME=/identity-admin`) | GitHub IdP 앱 `admin` + Authentik forward-auth → `ACCESS_AUD_ADMIN` | Django admin |
| `identity-admin.jt-prod.svc` · `identity-admin.jt-dev.svc`(클러스터 내부) | `/webhooks/authentik`, 프로브 3종 | Access 없음(svc DNS, FR-046) | Authentik 웹훅, kubelet 프로브 |

- `ADMIN_HOST`(settings 필수값): admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 장착한다. m2m 호스트로 `/admin/` 요청 → 404(T065).
- `ALLOWED_HOSTS`(필수값): svc DNS(`identity-admin.<ns>.svc`) · m2m 호스트 · admin 호스트.
- `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`은 ConfigMap 값(비밀 아님). Access 서비스 토큰 secret(`kv/{env}/access/web-bff`)은 Workers Secrets에만 있고 이 pod에는 없다.
- 외부 요청은 Cloudflare Access + Traefik(AOP mTLS)을 지나 도착한다. identity-admin이 Authentik을 부를 때는 svc DNS(`identity` ns 9000)만 쓴다(공개 호스트 금지). 예외: OIDC issuer/JWKS URL은 `https://auth.joshuatech.dev/…`(FR-046 예외 2).

## 인증 계층 (django-common 미들웨어)

1. `Cf-Access-Jwt-Assertion` 검증(팀 도메인 `joshua-tech.cloudflareaccess.com`의 `/cdn-cgi/access/certs`, `aud ∈ {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN}`) — 없거나 실패 403 `access_required`. 면제: 헬스 3종, `/webhooks/authentik`(svc DNS 경로, HMAC이 대신함).
2. `Authorization: Bearer` JWT 검증: JWKS(`kv/{env}/authentik/identity-admin.jwks_url`, 1시간 캐시), `iss`·`aud=identity-admin`·`exp`·`nbf`. 실패 401 `invalid_token`.
3. 호출자 식별: BFF가 RFC 8693 delegation으로 교환한 토큰이므로 **`act.sub == web-bff`** 여야 한다(없거나 다르면 401 `invalid_token`). Access 서비스 토큰은 네트워크 게이트일 뿐 식별에 쓰지 않는다.
4. Dragonfly 거부 목록: `revoked:sub:{sub}`의 `nbf > iat` 또는 `revoked:sid:{sid}` 존재 → 401 `session_revoked`. 조회 실패(타임아웃 0.2 s 포함) → **503 `denylist_unavailable`(fail-closed)**, 헬스 경로만 면제.
5. `tenant_id` 클레임(UUID) → 요청 트랜잭션 안 `SELECT set_config('app.tenant_id', %s, true)`. 없으면 403 `tenant_required`. 등급 B 테이블은 이 컨텍스트와 무관하게 app role로 읽는다.

서비스 간 호출(BFF → `/session/check`, Authentik 웹훅)은 2–5 대신 표의 규칙을 따른다.

## 엔드포인트

| 메서드·경로 | 인증 | 동작 | 응답 |
|---|---|---|---|
| `GET /healthz` | 없음 | liveness: 프로세스만(외부 의존 조회 없음) | 200 `{ status: "ok", version, git_sha }` |
| `GET /ready` | 없음 | readiness: **DB만**(`SELECT 1`, app role). Dragonfly·Kafka는 보지 않는다(outbox·fail-closed가 그 장애를 흡수하므로 pod를 내리지 않음) | 200 / 503 `not_ready` |
| `GET /health` | 없음(Access 뒤; svc DNS는 면제) | 상세: `{ status, checks: { db, dragonfly, kafka_producer } }` 항목마다 `ok`·`fail` + 지연 ms. **항상 200** | 200 |
| `GET /session/check?sub&iat&sid` | Access 서비스 토큰(BFF, `ACCESS_AUD_M2M`) | 거부 목록 조회만. DB 접근 없음. Dragonfly 실패 → 503 `denylist_unavailable` | 200 `{ active: boolean, nbf?: number }` / 503 |
| `POST /sessions/revoke` | Bearer(사용자 본인, `aud=identity-admin`, `act.sub=web-bff`) 또는 관리자(`platform-admin` 그룹) | body `{ sub?: string, sid?: string, all_devices: boolean, reason: "logout"\|"logout_all"\|"admin" }`. 본인은 `sub` 생략(토큰의 sub). 트랜잭션(app role, 등급 B 테이블): `session_revocation_log` INSERT(`expires_at = nbf + 330 s`) + outbox INSERT → 커밋 후 Dragonfly `SET revoked:sub:{sub} <nbf> EX 330`(또는 `revoked:sid`) → Authentik revoke API(서비스 계정 `identity-admin` 토큰, svc DNS; 실패해도 거부 목록은 유효, Celery 5 s × 3회 지수 백오프 최대 5분) | 202 `{ id, nbf, expires_at }` |
| `POST /webhooks/authentik` | `X-Authentik-Signature`(HMAC, 비밀 `kv/{env}/authentik/identity-admin.webhook_secret`) + 본문 `created` 시각이 서버 시각 ±5분 | Bearer·Access **면제 목록**에 명시된 유일한 업무 경로(svc DNS로만 도달). Authentik notification webhook — `logout`·세션 삭제 이벤트를 `/sessions/revoke`와 같은 트랜잭션으로 처리(reason `authentik_webhook`). 멱등: 이벤트 `pk` 저장, 재전송은 200 no-op. 서명 없음/틀림/시각 밖 → 401 `webhook_signature_invalid` | 202 / 200 / 401 / 400 |
| `GET /tenants/me` | Bearer | app role로 **등급 B 테이블**(`tenant`, `tenant_membership`)만 읽는다 — RLS가 없으므로 토큰의 `sub`·`tenant_id`로 명시 필터. SP-1 가정: 사용자당 테넌트 1 | 200 `{ tenant: { id, slug, display_name, status }, role }` |

## 이벤트(발행)

| 토픽 | 트리거 | data |
|---|---|---|
| `identity-admin.session.revoked` | `/sessions/revoke`, 웹훅 | `{ sub, sid?, nbf, reason }` |
| `identity-admin.user.registered` | Authentik 웹훅 `user_write`(신규) — SP-2 | `{ sub, email_hash, tenant_id, role }` |
| `identity-admin.tenant.created` | SP-2 | `{ tenant_id, slug }` |

## 주기 작업 (Celery beat, identity-admin 전용)

| 작업 | 주기 | 내용 |
|---|---|---|
| 거부 목록 대조 | 30 s | `EXISTS denylist:epoch` = 0이면 `session_revocation_log(expires_at > now())`를 Dragonfly에 재적용하고 `denylist:epoch`를 다시 SET(contracts/denylist.md). 기동 시에도 1회 |
| `reconcile_authentik_sessions` | 일 1회 | Authentik 활성 세션 API(서비스 계정 토큰)와 대조해 유실 웹훅을 보정 |
| `session_revocation_log` purge | 일 1회 | `expires_at + 30 d < now()` 행 삭제 |
| Authentik revoke 재시도 | 이벤트 | 5 s × 3회 지수 백오프(최대 5분) |

## 오류 슬러그

`access_required`, `invalid_token`, `session_revoked`, `denylist_unavailable`(503), `tenant_required`, `forbidden`, `validation_error`, `webhook_signature_invalid`, `not_ready`.

## 타임아웃 · 재시도

| 구간 | 값 |
|---|---|
| Dragonfly `socket_timeout` | 0.2 s, fail-closed 503 |
| PG app role | `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| Kafka producer | `delivery.timeout.ms` 30000 |
| identity-admin → Authentik(revoke·세션 API) | 5 s × 3회 지수 백오프(최대 5분, Celery) |
| BFF 측(참고) | pod fetch 3 s(AbortController), `/session/check` 캐시 2 s |

## 관측

- 로그(structlog JSON): `request_id`, `tenant_id`, `sub_hash`, `route`, `status`, `duration_ms`, `trace_id`. processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거하고 쿼리스트링을 남기지 않는다.
- 메트릭: web `http_requests_total{route,status}`, `session_revocations_total{reason}`, `denylist_lookup_seconds`; relay 컨테이너(9464, `k8s.grafana.com/scrape`) `outbox_pending`, `outbox_oldest_pending_seconds`(알림 `OutboxOldestPending` > 60 s), `outbox_dead_total`.
- 트레이스: OTLP → Alloy(`monitoring`), 상류 `traceparent` 이어받음, `OTEL_TRACES_SAMPLER=parentbased_traceidratio` 0.1.
- Sentry: errors only, `send_default_pii=False`, `before_send`로 `Authorization`·`Cookie`·`CF-Access-*` 제거.
