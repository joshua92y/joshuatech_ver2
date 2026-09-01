# Contract: BFF (apps/web Route Handlers)

Workers에서 실행되는 유일한 서버 코드. 브라우저는 BFF만 호출하고, BFF가 Authentik 토큰 교환과 pod 호출을 맡는다(청사진의 "게이트웨이"). 모든 응답은 `x-request-id`(BFF 생성, `traceparent`와 함께 하류 전파)를 갖고, 오류는 RFC 9457 `application/problem+json`이다.

## 세션 쿠키

| 이름 | 내용 | 속성 |
|---|---|---|
| `jt_session` | AES-256-GCM으로 암호화한 `{refresh_token, sub, sid?, tenant_id, issued_at}` (키 = Workers Secret `SESSION_ENCRYPTION_KEY`, 32바이트, 버전 접두 `v1.`) | `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=2592000`(30일) |
| `jt_csrf` | 랜덤 128비트 | `Secure; SameSite=Lax; Path=/` — 상태 변경 요청은 `x-csrf-token` 헤더와 일치해야 함 |

access 토큰은 쿠키에 넣지 않는다. BFF isolate 메모리 캐시 `Map<sub+aud, {token, exp}>`(최대 5분)에서 재사용하고, 없으면 refresh → exchange.

## 엔드포인트

| 메서드·경로 | 인증 | 동작 | 응답 |
|---|---|---|---|
| `GET /api/auth/login?return_to=/ko/…` | 없음 | PKCE `code_verifier`·`state`를 임시 쿠키(5분)에 저장하고 Authentik `/application/o/authorize/`로 302. `return_to`는 같은 오리진 경로만 허용 | 302 |
| `GET /api/auth/callback?code&state` | 없음 | `state` 검증 → 토큰 엔드포인트(client_secret은 Workers Secret) → `jt_session` 설정 → `return_to`로 302 | 302 / 400 `invalid_state` |
| `POST /api/auth/logout` | 세션 + CSRF | body `{ all_devices?: boolean }`. identity-admin `POST /sessions/revoke` 호출(BFF 서비스 토큰) → Authentik refresh revoke → 쿠키 삭제 | 204 |
| `GET /api/session` | 세션 | `/session/check` 결과가 active면 `{ sub, tenant_id, email, name, exp }` | 200 / 401 `session_revoked` |
| `GET /api/health` | 없음 | identity-admin `/health`를 Access 서비스 토큰으로 호출해 중계. 응답에 `upstream_ms` 포함 | 200 `{ status: "ok", upstream: "identity-admin", upstream_ms }` / 503 |
| `ALL /api/proxy/<pod>/<path>` | 세션 + CSRF(비-GET) | SP-2용 골격. `<pod>`는 허용 목록(`identity-admin`만 SP-1). 교환된 토큰 + 서비스 토큰으로 `https://<pod>-api.joshuatech.dev/<path>` 호출, 응답 그대로 중계 | 상류 상태 |

## 하류 호출 규약

- 헤더: `Authorization: Bearer <exchanged access>`, `CF-Access-Client-Id`, `CF-Access-Client-Secret`, `x-request-id`, `traceparent`, `x-forwarded-user-sub`(정보용, 신뢰하지 않음).
- 토큰 교환: `POST https://auth.joshuatech.dev/application/o/token/` `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`, `subject_token`=web-bff access, `audience=<pod>`, `client_id/secret`=web-bff. 실패(400/403) → BFF 401 `exchange_denied`.
- 폐기 확인: `GET https://identity-admin-api.joshuatech.dev/session/check?sub=<sub>&iat=<iat>&sid=<sid>` → `{ active: boolean }`. 결과를 2초 캐시. `active=false`면 쿠키 삭제 + 401 `session_revoked`.
- 타임아웃: 교환 3 s, pod 호출 10 s. 재시도 없음(멱등성 불명).

## 오류 형식

```json
{ "type": "https://joshuatech.dev/problems/session-revoked", "title": "Session revoked", "status": 401, "detail": "...", "instance": "/api/session", "request_id": "..." }
```

`type` 슬러그: `invalid_state`, `session_revoked`, `exchange_denied`, `upstream_unavailable`, `csrf_mismatch`.

## 번들 예산

서버 번들(`.open-next/worker.js` 계열) gzip ≤ 2.5 MiB. 허용 의존성: `jose`(JWT/JWE), 표준 Web Crypto, `ulid`. 금지: `@sentry/nextjs` 서버 측, `next-intl` 런타임, ORM, `better-auth`.
