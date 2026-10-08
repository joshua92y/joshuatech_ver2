> 번역본(편의용). 정본은 영어 원본 `.claude/rules/web.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "apps/web/**"
  - "packages/content/**"
```

# Rules for `apps/web/` and `packages/content/`

기록 계약(contract of record): `specs/003-platform-foundation/contracts/bff-api.md`. 충돌 시 계약이 우선한다; 여기의 동작을 바꾸기 전에 계약을 먼저 개정한다.

## OpenNext lean

- `apps/web`은 OpenNext를 통해 Cloudflare Workers에 배포되는 Next.js다. `/api/*` 아래의 BFF Route Handler만이 유일한 서버 코드다; 페이지는 서버 전용 의존성 없이 렌더링된다.
- 서버 번들(`.open-next/worker.js` 계열)은 gzip ≤ 2.5 MiB. 허용되는 서버 의존성: `jose`, 표준 Web Crypto, `ulid`. 서버 번들에서 금지: `@sentry/nextjs` 서버 사이드, `next-intl` 런타임, 모든 ORM, `better-auth`. Sentry는 브라우저 전용(`maskAllText: true`, `tracesSampleRate 0.1`, 서버 SDK 없음).
- `next.config`의 `serverExternalPackages: ['jose']`를 유지하고, "정리"당하지 않도록 그 근거를 설정 바로 옆에 주석으로 남긴다: OpenNext의 workerd 지침은 workerd 조건부 export를 가진 패키지를 거기에 두라고 한다; 이 설정은 Next의 서버 번들러가 `jose`를 건너뛰게 할 뿐이고, OpenNext의 esbuild 단계는 여전히 그것을 Worker 번들에 인라인한다 — "Workers에는 node_modules가 없으니 external은 런타임에 실패한다"는 이 조합에는 적용되지 않는다. 절대 제거하지 않는다.
- `e2e/hello.spec.ts`의 prefetch 가드는 유지한다: 로드 후 30초 안에 `Next-Router-Prefetch: 1` 요청 ≤ 10개(prefetch 폭주가 Free 쿼터를 태우는 것을 막는다).

## BFF contract

- 정확히 7개 라우트로 고정: `/api/auth/login`, `/api/auth/callback`, `/api/auth/logout`, `/api/auth/refresh`, `/api/session`, `/api/health`, `/api/proxy/[pod]/[...path]`. `contracts/bff-api.md`를 먼저 개정하지 않고 BFF 라우트를 절대 추가·삭제·개명하지 않는다. `/api/session/check` 라우트는 없다 — 폐기(revocation) 확인은 `/api/session` 내부에서 업스트림 `/session/check`로 수행한다.
- `/api/proxy/<pod>/<path>`는 정적 맵으로만 라우팅한다(SP-1: `identity-admin` → `IDENTITY_M2M_URL`, 허용 경로 `/tenants/me`, `/session/check`). `<pod>` 세그먼트로 업스트림 호스트를 절대 조립하지 않는다. 맵에 없는 pod 또는 허용 목록 밖의 경로 → 업스트림 호출 없이 404 `not_found`.
- `return_to`(returnTo): `/`로 시작하고 `//`로 시작하지 않는 상대 경로만 허용한다; 절대 URL과 스킴 상대(scheme-relative) URL → 400 `invalid_return_to`. 콜백에서 리다이렉트 전에 같은 규칙으로 재검증한다.
- 에러는 `request_id`를 담은 RFC 9457 `application/problem+json`이다; 모든 응답은 `x-request-id`를 담고, `traceparent`와 함께 다운스트림으로 전파한다.
- 나가는 호출의 URL 경로나 쿼리 스트링에 `access_token`, `code`, `state`를 절대 넣지 않는다; 토큰 교환과 폐기 확인은 헤더/본문을 쓴다.
- 업스트림 fetch(pod와 Authentik)는 재시도 없는 3초 `AbortController` 타임아웃을 쓴다; 타임아웃 → 503 `upstream_unavailable`.

## Cookies and caching invariants

- 어떤 `app/[lang]` 응답에도 `Set-Cookie`를 설정해서는 안 된다. 쿠키(`jt_session`, `jt_csrf`, PKCE 임시 쿠키)는 `/api/auth/*` 핸들러만 설정한다. 언어와 테마는 URL 경로와 `prefers-color-scheme`로 표현하며, 쿠키로는 절대 표현하지 않는다.
- `wrangler.jsonc`의 `assets.run_worker_first`에는 Worker가 먼저 봐야 하는 경로(`/api/*`)만 나열한다. 페이지 경로(`/ko`, `/en`, `/ja`, 그 외 어떤 페이지 라우트도)를 절대 넣지 않는다 — 에셋으로 서빙 가능한 요청이 과금되는 Worker 호출로 바뀐다.
- Workers Caching `[cache]`는 비활성 상태를 유지한다: 기본값을 명시적으로 유지하고 절대 켜지 않는다(에셋 요청이 과금 대상이 된다).
- 액세스 토큰은 절대 쿠키에 넣지 않는다; isolate 메모리 교환 캐시(≤ 5분)에만 존재한다.

## Logging and masking

- 로그는 한 줄 JSON: `ts`, `level`, `request_id`, `route`, `status`, `upstream`, `upstream_ms`, `exchange_result`, `trace_id`.
- `Authorization`, `Cookie`(`jt_session`/`jt_csrf`), `CF-Access-*` 헤더 값과 `code`/`state` 쿼리 값을 절대 로깅하지 않는다 — 로그에도, problem `detail`에도, Sentry 이벤트에도. 로깅하는 모든 URL에서 쿼리 스트링을 제거한다. `sub`는 해시로만 나타난다.
- 시크릿은 Workers Secrets(`wrangler secret put`)에만 둔다; 비밀이 아닌 설정은 wrangler `vars`에 둔다. prod와 preview Worker는 시크릿이나 업스트림을 절대 공유하지 않는다.

## i18n

- 로케일은 `ko`, `en`, `ja`이며 URL 경로(`app/[lang]`)로만 표현한다. 런타임 i18n 라이브러리는 없다; 번역은 빌드/렌더 시점에 해석되는 정적 사전이다. `packages/content`가 사이트가 소비하는 로케일 콘텐츠를 보관한다.
- 로케일 추가 = 새 `[lang]` 값 + 사전 + 정적 에셋. 페이지 라우트에 로케일 쿠키와 `Accept-Language` 리다이렉트 로직은 없다.

## Design tokens

- 3계층: primitive(원시 값) → semantic(목적 이름, 테마 인지) → component(컴포넌트별 슬롯). 컴포넌트는 semantic 또는 component 토큰만 참조한다; 컴포넌트 코드에 원시 색상/크기 리터럴을 절대 쓰지 않는다.
- 테마 전환은 semantic 계층만 다시 매핑한다; primitive와 component 배선은 그대로 유지한다.

## CI

- `pnpm install --frozen-lockfile --ignore-scripts`; `engines.node >= 24`; Renovate `automerge: false`.
- 프리뷰 배포(`wrangler deploy --env preview`)는 운영자가 연 same-repo PR에만 한다; fork와 bot PR은 프리뷰를 받지 않는다.
