# Contract: identity-admin API (SP-1 범위)

Django 6.1 + Ninja 1.7. 호스트 `identity-m2m-prod.joshuatech.dev`(prod) · `identity-m2m-dev.joshuatech.dev`(dev). 모든 요청은 Cloudflare Access(Service Auth)와 Traefik(AOP mTLS)을 통과한 뒤 도착한다. 오류는 RFC 9457. 응답 헤더에 `x-request-id`를 되돌린다.

## 인증 계층 (django-common 미들웨어)

1. `Cf-Access-Jwt-Assertion` 검증(Access 팀 JWKS, `aud` = 이 앱의 Access AUD) — 없으면 403 `access_required`.
2. `Authorization: Bearer` JWT 검증: JWKS(`kv/{env}/authentik/identity-admin.jwks_url`, 1시간 캐시), `iss`·`aud=identity-admin`·`exp`·`nbf`. 실패 401 `invalid_token`.
3. Dragonfly 거부 목록: `revoked:sub:{sub}`의 `nbf > iat` 또는 `revoked:sid:{sid}` 존재 → 401 `session_revoked`.
4. `tenant_id` 클레임 → 요청 트랜잭션 `SET LOCAL app.tenant_id`. 없으면 403 `tenant_required`.

서비스 간 호출(BFF → `/session/check`, Authentik 웹훅)은 2–4 대신 별도 규칙(아래).

## 엔드포인트

| 메서드·경로 | 인증 | 동작 | 응답 |
|---|---|---|---|
| `GET /health` | 없음(Access만) | 프로세스 살아 있음 | 200 `{ status: "ok", version, git_sha }` |
| `GET /ready` | 없음(Access만) | DB `SELECT 1`, Dragonfly `PING`, Kafka 메타데이터 | 200 / 503 `{ checks: { db, dragonfly, kafka } }` |
| `GET /session/check?sub&iat&sid` | Access 서비스 토큰(BFF) | 거부 목록 조회만. DB 접근 없음 | 200 `{ active: boolean, nbf?: number }` |
| `POST /sessions/revoke` | Bearer(사용자 본인, `aud=identity-admin`) 또는 관리자(`platform-admin` 그룹) | body `{ sub?: string, sid?: string, all_devices: boolean, reason: "logout"\|"logout_all"\|"admin" }`. 본인은 `sub` 생략(토큰의 sub). 트랜잭션: `session_revocation_log` INSERT + outbox INSERT → 커밋 후 Dragonfly SET(TTL) → Authentik revoke API 호출(실패해도 거부 목록은 유효, 재시도 Celery) | 202 `{ id, nbf, expires_at }` |
| `POST /webhooks/authentik` | 헤더 `X-Authentik-Signature`(공유 비밀 HMAC) | Authentik notification webhook. `logout`·세션 삭제 이벤트를 `/sessions/revoke`와 같은 트랜잭션으로 처리(reason `authentik_webhook`). 멱등: 이벤트 `pk` 저장 | 202 / 400 |
| `GET /tenants/me` | Bearer | 토큰의 `tenant_id`로 Tenant + 내 membership | 200 `{ tenant: { id, slug, display_name, status }, role }` |

## 이벤트(발행)

| 토픽 | 트리거 | data |
|---|---|---|
| `identity-admin.session.revoked` | `/sessions/revoke`, 웹훅 | `{ sub, sid?, nbf, reason }` |
| `identity-admin.user.registered` | Authentik 웹훅 `user_write`(신규) — SP-2 | `{ sub, email_hash, tenant_id, role }` |
| `identity-admin.tenant.created` | SP-2 | `{ tenant_id, slug }` |

## 오류 슬러그

`access_required`, `invalid_token`, `session_revoked`, `tenant_required`, `forbidden`, `validation_error`, `webhook_signature_invalid`, `not_ready`.

## 관측

- 로그(JSON): `request_id`, `tenant_id`, `sub`(해시), `route`, `status`, `duration_ms`, `trace_id`.
- 메트릭: `http_requests_total{route,status}`, `session_revocations_total{reason}`, `denylist_lookup_seconds`, `outbox_pending`(gauge), `outbox_publish_failures_total`.
- 트레이스: OTLP → Alloy, 상류 `traceparent` 이어받음.
