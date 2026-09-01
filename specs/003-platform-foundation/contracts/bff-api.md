# Contract: BFF (apps/web Route Handlers)

Workers에서 실행되는 유일한 서버 코드. 브라우저는 BFF만 호출하고, BFF가 Authentik 토큰 교환과 pod 호출을 맡는다(청사진의 "게이트웨이"). 모든 응답은 `x-request-id`(BFF 생성, `traceparent`와 함께 하류 전파)를 갖고, 오류는 RFC 9457 `application/problem+json`이다.

## Worker · 환경

| Worker | 배포 | 호스트 | Authentik provider | 상류 pod(`IDENTITY_M2M_URL`) | Access 서비스 토큰 | `SESSION_ENCRYPTION_KEY` |
|---|---|---|---|---|---|---|
| prod Worker | main의 `deploy` job만(`wrangler deploy`). job은 GitHub Environment `production`(deployment branch = main만, 승인자 없음, 환경 시크릿에 prod `CLOUDFLARE_API_TOKEN`) | `joshuatech.dev`, `www.` | `web-bff` | `https://identity-m2m-prod.joshuatech.dev` | `web-bff-prod` | 자체 값 |
| `joshuatech-web-preview`(wrangler env `preview`) | PR마다 `wrangler deploy --env preview` — **운영자(`joshua92y`)가 연 같은 repo PR만**, fork PR·봇 PR은 프리뷰를 만들지 않는다 | `preview.joshuatech.dev`(커스텀 도메인, Access GitHub IdP) | `web-bff-dev`(redirect `https://preview.joshuatech.dev/api/auth/callback`) | `https://identity-m2m-dev.joshuatech.dev` | `web-bff-dev` | 자체 값(prod와 다름) |
| 로컬 `next dev`(SC-002 dev 체인) | — | `localhost:3000` | `web-bff-dev`(redirect `http://localhost:3000/api/auth/callback`) | `https://identity-m2m-dev.joshuatech.dev` | `web-bff-dev` | 로컬 `.dev.vars` |

- Workers Secrets(`wrangler secret put`, Worker마다 따로): `SESSION_ENCRYPTION_KEY`, `WEB_BFF_CLIENT_SECRET`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`. 원천은 Vault `kv/{env}/web/session`·`kv/{env}/authentik/web-bff`·`kv/{env}/access/web-bff`이며 **Workers Secrets에만** 복사한다(ESO 밖, 어떤 pod에도 배포하지 않음).
- 비밀이 아닌 설정은 wrangler `vars`(`IDENTITY_M2M_URL` 등). prod Worker와 preview Worker는 서로의 시크릿·상류를 공유하지 않는다.
- CI: `pnpm install --frozen-lockfile --ignore-scripts`, Renovate `automerge: false`, Node 24(`engines.node >=24`).

## 세션 쿠키

| 이름 | 내용 | 속성 |
|---|---|---|
| `jt_session` | AES-256-GCM으로 암호화한 `{refresh_token, sub, sid?, tenant_id, issued_at}` (키 = Workers Secret `SESSION_ENCRYPTION_KEY`, 32바이트, 버전 접두 `v1.`) | `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=2592000`(30일) |
| `jt_csrf` | 랜덤 128비트 | `Secure; SameSite=Lax; Path=/` — 상태 변경 요청은 `x-csrf-token` 헤더와 일치해야 함 |

access 토큰은 쿠키에 넣지 않는다. BFF isolate 메모리 캐시 `Map<sub+aud, {token, exp}>`(최대 5분)에서 재사용하고, 없으면 refresh → exchange. `tenant_id`는 UUID.

## 엔드포인트

| 메서드·경로 | 인증 | 동작 | 응답 |
|---|---|---|---|
| `GET /api/auth/login?return_to=/ko/…` | 없음 | PKCE `code_verifier`·`state`를 임시 쿠키(5분)에 저장하고 Authentik `/application/o/authorize/`로 302. **`return_to`(returnTo)는 `/`로 시작하고 `//`로 시작하지 않는 상대 경로만** 허용 — 절대 URL·스킴 상대 URL은 400 `invalid_return_to` | 302 / 400 |
| `GET /api/auth/callback?code&state` | 없음 | `state` 검증 → 토큰 엔드포인트(client_secret은 Workers Secret) → `jt_session` 설정 → 임시 쿠키의 `return_to`(같은 규칙 재검증)로 302 | 302 / 400 `invalid_state` |
| `POST /api/auth/logout` | 세션 + CSRF | body `{ all_devices?: boolean }`. identity-admin `POST /sessions/revoke` 호출(교환 토큰 + 서비스 토큰) → Authentik refresh revoke → 쿠키 삭제 | 204 |
| `POST /api/auth/refresh` | 세션 + CSRF | `jt_session`의 refresh 토큰으로 Authentik 토큰 재발급(회전 refresh — 새 refresh를 쿠키에 다시 넣는다) 후 isolate 교환 캐시를 비운다. refresh가 만료·폐기됐으면 쿠키 삭제 + 401 | 204 / 401 `session_revoked` / 503 `upstream_unavailable` |
| `GET /api/session` | 세션 | `/session/check` 결과가 active면 `{ sub, tenant_id, email, name, exp }` | 200 / 401 `session_revoked` / 503 `upstream_unavailable` |
| `GET /api/health` | 없음 | identity-admin `GET /health`(상세, 항상 200)를 Access 서비스 토큰으로 호출해 중계. 응답에 `upstream_ms` 포함. 3 s 안에 응답 없으면 503 | 200 `{ status: "ok", upstream: "identity-admin", upstream_ms, checks }` / 503 `upstream_unavailable` |
| `ALL /api/proxy/<pod>/<path>` | 세션 + CSRF(비-GET) | **정적 맵**으로만 라우팅한다(`<pod>`를 호스트로 조립하지 않음). SP-1 맵: `identity-admin` → `IDENTITY_M2M_URL`, 허용 경로 `/tenants/me`·`/session/check`. 맵에 없는 pod·허용 목록 밖 경로는 404 `not_found`(상류 호출 없음). 허용된 요청은 교환 토큰 + 서비스 토큰으로 호출하고 응답을 그대로 중계 | 상류 상태 / 404 |

**이 7개가 BFF 라우트의 전부다**(`/api/auth/{login,callback,logout,refresh}` · `/api/session` · `/api/health` · `/api/proxy/[pod]/[...path]`). spec FR-027과 T092의 목록은 이 표와 글자 그대로 같아야 한다 — `/api/session/check` 같은 별도 라우트는 없다(폐기 확인은 `/api/session` 안에서 상류 `/session/check`를 부른다).

## 하류 호출 규약

- 헤더: `Authorization: Bearer <exchanged access>`, `CF-Access-Client-Id`, `CF-Access-Client-Secret`, `x-request-id`, `traceparent`, `x-forwarded-user-sub`(정보용, 신뢰하지 않음).
- 토큰 교환(RFC 8693, Authentik 2026.8 OSS) — **기본은 impersonation**: `POST https://auth.joshuatech.dev/application/o/token/` `grant_type=urn:ietf:params:oauth:grant-type:token-exchange`, `subject_token`=사용자 access(web-bff), `subject_token_type=urn:ietf:params:oauth:token-type:access_token`, `audience=<pod>`, `client_id/secret`=web-bff. **`actor_token`은 보내지 않는다**(OSS에는 authentik `Actor`를 만드는 지원 경로가 없어 client-credentials 토큰을 actor로 쓰면 `invalid_grant`). 호출자 식별은 **Access 서비스 토큰의 `common_name`**(`web-bff-<env>`)이 맡는다 — contracts/identity-admin-api.md §호출자 식별. 실패(400/403) → BFF 401 `exchange_denied`.
  - **VD-1(검증 후 결정)**: T081 착수 시 OSS에서 `Actor` 생성이 되면 `actor_token`(BFF client-credentials)을 붙인 delegation으로 바꾸고 pod는 `AUTH_ACTOR_SUB`로 `act.sub`를 검증한다(옵션 A). 안 되면 위 impersonation 그대로(옵션 B). BFF 코드는 `actor_token` 파라미터를 붙일지 여부만 달라진다.
- 폐기 확인: `GET <IDENTITY_M2M_URL>/session/check?sub=<sub>&iat=<iat>&sid=<sid>` → `{ active: boolean }`. 결과를 **2 s** 캐시. `active=false`면 쿠키 삭제 + 401 `session_revoked`. 상류 503(`denylist-unavailable`) → BFF 503 `upstream_unavailable`(fail-closed; 쿠키는 유지).
- `access_token`·`code`·`state`를 URL 경로·쿼리에 싣지 않는다(교환·폐기 확인은 헤더/본문).

## 타임아웃 · 재시도

| 구간 | 값 | 비고 |
|---|---|---|
| BFF → pod fetch(`/session/check`·`/health`·`/sessions/revoke`·proxy) | **3 s**, `AbortController` | 재시도 없음(멱등성 불명). 초과 → 503 `upstream_unavailable` |
| BFF → Authentik(토큰·교환·revoke) | 3 s, `AbortController` | 재시도 없음 |
| `/session/check` 결과 캐시 | 2 s | isolate 메모리 |
| 교환 토큰 캐시 | ≤ 5 분(`exp` 이하) | isolate 메모리 |
| pod 측(참고) | Dragonfly `socket_timeout` 0.2 s · PG `statement_timeout 15s` · Kafka `delivery.timeout.ms` 30000 · pod → Authentik 5 s × 3회 지수 백오프(Celery, 최대 5분) | contracts/pod-template.md |

## Cloudflare 존 설정 · Workers 한도

- **`run_worker_first`**: `wrangler.jsonc`의 `assets.run_worker_first`에는 `/api/*`처럼 Worker가 반드시 먼저 봐야 하는 경로만 넣는다. **`/ko`·`/en`·`/ja` 같은 페이지 경로는 넣지 않는다** — 넣으면 정적 자산으로 서빙될 수 있는 요청까지 Worker 호출로 계상된다.
- **Workers Caching(`[cache]`) 비활성 유지**: 활성화하면 자산 요청까지 과금 대상이 된다. 기본값(비활성)을 명시적으로 유지한다.
- **Free 한도 초과 시(VD-8, 관찰만)**: 기본 가정은 "Worker를 거치는 요청이 429/1027을 받는다"이고, 자산 요청(`.open-next/assets`)은 무제한이라 영향이 없다. 의도적으로 초과시키지 않으며, 실제로 발생하면 그때의 fail 모드를 `report.md`에 기록한다. 감시는 Cloudflare Notifications "Workers usage" + 주간 GraphQL 검사(T097·T101). 완화책은 VD-2 실측 결과에 따른다.
- **`app/[lang]` 응답에 `Set-Cookie`를 넣지 않는다**(위생 규칙). 언어·테마 선택은 URL 경로와 `prefers-color-scheme`으로 표현하고, 쿠키는 `/api/auth/*`에서만 설정한다. T087이 `/ko` 응답에 `Set-Cookie`가 없음을 단언한다.

### VD-2 (검증 후 결정) — 존 Cache Rule이 Worker 응답을 edge에서 서빙하는가

- **기본 가정(문서 기본값)**: Workers는 캐시보다 **먼저** 실행되고 커스텀 도메인 Worker는 그 존의 오리진이 아니므로, 존 Cache Rule("Cache Everything, edge TTL 600")은 페이지 HTML에 효과가 없다 → **Cache Rule을 두지 않는다**.
- **옵션 A**: 실측에서 `cf-cache-status: HIT`가 나오고 대시보드의 Workers 요청 수가 늘지 않으면 Cache Rule을 유지한다.
- **옵션 B**: 효과가 없으면 삭제하고, 대신 **프리렌더 HTML을 `.open-next/assets`의 정적 자산(`/ko`·`/en`·`/ja`)으로 내보내는 방식**을 시험한다(자산 요청은 무제한). RSC 프리페치 부작용은 `e2e/hello.spec.ts`의 prefetch 가드로 판정한다.
- **실측(사용자 동석)**: T093 배포 직후 `curl -I https://joshuatech.dev/ko` 10회 → `cf-cache-status` 분포 + 대시보드 Workers 요청 수 비교. 자산화 시험도 같은 task에서.

### VD-3 (검증 후 결정) — Free Rate Limiting 표현식에 host 조건을 쓸 수 있는가

- **기본 가정(문서 기본값)**: Free 플랜의 Rate Limiting 규칙은 1개, 기간 10 s, 특성 IP, 표현식 필드는 Path·Verified Bot만 → 표현식은 **경로만** `/api/auth/*` + `/if/flow/*`, action `block`.
- **옵션 A**: 대시보드·API가 host 필드를 받으면 `joshuatech.dev/api/*`로 범위를 넓힌다.
- **옵션 B**: 받지 않으면 경로만 유지한다.
- **실측(사용자 동석)**: T011 apply 시 대시보드·API 오류로 확정.
- 어느 쪽이든 자동화 호출(T095·T087·T079)은 **호출 간격 ≥ 200 ms**를 지켜 스스로 규칙에 걸리지 않게 한다.

## 오류 형식

```json
{ "type": "https://joshuatech.dev/problems/session-revoked", "title": "Session revoked", "status": 401, "detail": "...", "instance": "/api/session", "request_id": "..." }
```

`type` 슬러그: `invalid_state`, `invalid_return_to`, `session_revoked`, `exchange_denied`, `upstream_unavailable`, `csrf_mismatch`, `not_found`.

## 로그 · 마스킹

- wrangler.jsonc `observability: { enabled: true, head_sampling_rate: 1 }`(Workers Logs, Free 200k 이벤트/일).
- 로그는 `console.log(JSON.stringify(...))` 한 줄: `ts`, `level`, `request_id`, `route`, `status`, `upstream`, `upstream_ms`, `exchange_result`(캐시 적중 / 교환 성공 / 거부 / 오류), `trace_id`. 교환 실패율은 이 로그 기반 지표.
- **마스킹(금지 값)**: `Authorization`, `Cookie`(`jt_session`·`jt_csrf`), `CF-Access-*`(`CF-Access-Client-Id`·`CF-Access-Client-Secret`·`Cf-Access-Jwt-Assertion`) 헤더 값과 `code`·`state` 쿼리 값은 로그·오류 `detail`·Sentry 이벤트 어디에도 남기지 않는다. URL을 남길 때는 쿼리스트링을 제거한다. `sub`는 해시로만.
- 클라이언트 Sentry(`@sentry/nextjs` 브라우저 측만): replay `maskAllText: true`, `tracesSampleRate 0.1`. 서버 SDK 없음.

## 번들 예산

서버 번들(`.open-next/worker.js` 계열) gzip ≤ 2.5 MiB. 허용 의존성: `jose`(JWT/JWE 프리미티브 — FR-027의 "인증 라이브러리" 금지에서 제외), 표준 Web Crypto, `ulid`. 금지: `@sentry/nextjs` 서버 측, `next-intl` 런타임, ORM, `better-auth`. `e2e/hello.spec.ts`는 로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10을 가드한다(prefetch 폭주 → Free 한도 소진 방지).

- **`next.config` `serverExternalPackages: ['jose']`는 유지한다.** OpenNext의 workerd 가이드가 `jose`처럼 workerd 조건부 export를 가진 패키지를 여기에 넣도록 명시하고 있고, 이 설정은 Next의 서버 번들러만 건너뛰게 할 뿐 **OpenNext의 esbuild 단계가 `jose`를 Worker 번들에 그대로 포함**한다("Workers에는 node_modules가 없어 external은 실행 실패"는 이 조합에서 성립하지 않는다). 설정 옆에 이 근거를 주석으로 남겨 다시 제거되지 않게 한다.
