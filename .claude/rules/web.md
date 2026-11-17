---
paths:
  - "apps/web/**"
  - "packages/content/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/web_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `apps/web/` and `packages/content/`

Contract of record: `specs/003-platform-foundation/contracts/bff-api.md`. On conflict, the contract prevails; amend it before changing behavior here.

## OpenNext lean

- `apps/web` is Next.js deployed to Cloudflare Workers via OpenNext. The BFF Route Handlers under `/api/*` are the only server code; pages render without server-only dependencies.
- Server bundle (`.open-next/worker.js` family) gzip ≤ 2.5 MiB. Allowed server deps: `jose`, standard Web Crypto, `ulid`. Banned from the server bundle: `@sentry/nextjs` server side, `next-intl` runtime, any ORM, `better-auth`. Sentry is browser-only (`maskAllText: true`, `tracesSampleRate 0.1`, no server SDK).
- Keep `serverExternalPackages: ['jose']` in `next.config`, with the rationale as a comment next to the setting so it is not "cleaned up": OpenNext's workerd guidance puts packages with workerd conditional exports there; the setting only makes Next's server bundler skip `jose`, while OpenNext's esbuild step still inlines it into the Worker bundle — "Workers have no node_modules, so external fails at runtime" does not apply to this combination. NEVER remove it.
- The `e2e/hello.spec.ts` prefetch guard stays: ≤ 10 `Next-Router-Prefetch: 1` requests within 30 s of load (prevents prefetch storms from burning the Free quota).

## BFF contract

- Exactly 7 routes, fixed: `/api/auth/login`, `/api/auth/callback`, `/api/auth/logout`, `/api/auth/refresh`, `/api/session`, `/api/health`, `/api/proxy/[pod]/[...path]`. NEVER add, remove, or rename a BFF route without amending `contracts/bff-api.md` first. There is no `/api/session/check` route — revocation is checked inside `/api/session` via the upstream `/session/check`.
- `/api/proxy/<pod>/<path>` routes through a static map only (SP-1: `identity-admin` → `IDENTITY_M2M_URL`, allowed paths `/tenants/me`, `/session/check`; a map entry is a path plus a method, and both SP-1 paths are GET). NEVER assemble an upstream host from the `<pod>` segment. Unmapped pod, non-allowlisted path, or unmapped method → 404 `not_found` with no upstream call (the pod's 405 is `text/html`, which the relay rule would turn into 503). Allowlist matching is exact: a raw path that contains an encoded separator or dot (`%2F`, `%5C`, `%2E`, any case), or a decoded path that differs from an allowlisted constant in any way (prefix, trailing slash, empty or dot segment, case, `;` parameters), is 404; the upstream URL is the static-map base URL plus the matched constant — never the client path string, never `new URL(clientPath, base)`. Through the proxy, `/session/check` drops the client query and is rebuilt from the session (`sub`, `iat`, and `sid` only when the claim exists), bound to that same match: the upstream path is Access-only and does not bind the caller, so a relayed query would let any signed-in user ask about another user's revocation.
- The proxy relays the upstream status, body, and `content-type` only for a pod-made response: a 2xx whose media type is `application/json` or a 4xx whose media type is `application/problem+json`. Any other upstream response — 3xx, 5xx, another content type (edge 530, Traefik, or Access pages), or a 4xx that is not problem+json — becomes 503 `upstream_unavailable` (BFF problem+json, cookie kept). Never relay `set-cookie`, `location`, `cf-*`, or any other upstream header (Access may attach an app-scoped `CF_Authorization` cookie to a service-token response — in a browser it would let the user call the m2m host directly); proxy responses carry `x-content-type-options: nosniff`. No BFF route copies a downstream (pod or Authentik) response header — the proxy's `content-type` is the only exception. `/api/health` returns only its BFF-built body and answers 503 unless the upstream returns a 200 JSON. Downstream requests carry only the headers the contract lists (never the client's `cookie`, `cf-access-token`, or `authorization`), and a client query reaches upstream only as the `/session/check` rebuild (`/tenants/me` drops it).
- Proxy path variants are judged at the handler: the raw-path check reads the pathname of `request.url` (not the decoded catch-all params); a framework redirect to the canonical path before the handler (Next.js trailing- or duplicate-slash 308) is acceptable when no upstream call happens and its `Location` is a same-origin path (defined in the `return_to` rule below); a form the URL parser or the edge folds before the handler (dot segments `..`/`%2e%2e`, merged `//`) reaches it as the canonical request and is acceptable when the response matches the canonical one and no client query reaches upstream; the static map is looked up by own keys only (`Map` or `Object.hasOwn` — `constructor`, `__proto__` → 404); `IDENTITY_M2M_URL` is an origin with no path or trailing slash.
- `return_to` (returnTo) and a framework-redirect `Location` must be a same-origin path: after percent-decoding it starts with `/` but not `//`, contains no `\`, space, C0 control (tab, CR, LF), or DEL, and resolving it with the WHATWG URL parser against the request origin yields that same origin — a prefix-only check passes `/\evil.com` and `/<TAB>/evil.com`, which the parser turns into another origin. Absolute and scheme-relative URLs, and anything else that fails this rule in `return_to`, → 400 `invalid_return_to`. Re-validate with the same rule on callback before redirecting.
- Errors are RFC 9457 `application/problem+json` with `request_id`; every response carries `x-request-id`, propagated downstream together with `traceparent`. A pod 4xx body relayed by the proxy follows the pod contract (its slugs and fields, no `request_id`), while the `x-request-id` header is the BFF's.
- Never put `access_token`, `code`, or `state` in URL paths or query strings of outgoing calls; token exchange and revocation checks use headers/body.
- Upstream fetches (pod and Authentik) use a 3 s `AbortController` timeout with no retry; timeout → 503 `upstream_unavailable`.
- The revocation check inside `/api/session` treats only a 200 whose body has a boolean `active` as a verdict; anything else (4xx, 5xx, timeout, malformed body, missing `active`) → 503 `upstream_unavailable`, cookie kept.
- Downstream calls that carry a credential (service token, exchanged token, client secret, refresh token) never follow redirects (`redirect: 'manual'`): every Authentik token-endpoint call (callback code exchange, refresh, token exchange), Authentik revoke, the revocation check, `/api/health`, `/sessions/revoke`, and the proxy. The default `follow` resends custom headers to the `Location` host, and 307/308 also resend the method and body. An upstream 3xx is handled like a timeout (503 `upstream_unavailable`); in refresh, `/api/session`, and the proxy (including their internal refresh and exchange) it is never treated as expiry or revocation (401, cookie deletion), and logout follows its own failure branch below.
- Once the session and CSRF checks pass, logout deletes `jt_session` and `jt_csrf` whatever the downstream outcome (the user's intent — shared devices) and attempts the Authentik refresh revoke even when `/sessions/revoke` fails; when either revoke fails (timeout, 3xx, non-2xx) it answers 503 `upstream_unavailable` with the cookies already deleted. A callback whose code exchange times out or gets a 3xx or 5xx answers 503 `upstream_unavailable` without setting a session cookie.

## Cookies and caching invariants

- MUST NOT set `Set-Cookie` on any `app/[lang]` response. Cookies (`jt_session`, `jt_csrf`, PKCE temp cookies) are set only by `/api/auth/*` handlers. `jt_csrf` carries the same `Max-Age` as `jt_session` and is set wherever `jt_session` is (callback, refresh), so a browser restart never leaves a session that cannot pass the CSRF check on logout or refresh. Language and theme are expressed by URL path and `prefers-color-scheme`, never by cookie.
- `wrangler.jsonc` `assets.run_worker_first` lists only paths the Worker must see first (`/api/*`). NEVER put page paths (`/ko`, `/en`, `/ja`, or any other page route) in it — that turns asset-servable requests into billed Worker invocations.
- Workers Caching `[cache]` stays disabled: keep the default explicitly and never enable it (it makes asset requests billable).
- Access tokens never go into cookies; they live only in the isolate memory exchange cache (≤ 5 min).

## Logging and masking

- Logs are one-line JSON: `ts`, `level`, `request_id`, `route`, `status`, `upstream`, `upstream_ms`, `exchange_result`, `trace_id`.
- NEVER log the values of `Authorization`, `Cookie` (`jt_session`/`jt_csrf`), or `CF-Access-*` headers, nor `code`/`state` query values — not in logs, not in problem `detail`, not in Sentry events. Response-side credentials are banned the same way: no `Set-Cookie` value (the BFF's own `jt_session`/`jt_csrf` or an upstream one), no `CF_Authorization` value, and no upstream response headers. Strip the query string from any logged URL. `sub` appears only hashed.
- Secrets live in Workers Secrets (`wrangler secret put`) only; non-secret config in wrangler `vars`. prod and preview Workers never share secrets or upstreams.

## i18n

- Locales are `ko`, `en`, `ja`, expressed only in the URL path (`app/[lang]`). No runtime i18n library; translations are static dictionaries resolved at build/render time. `packages/content` holds the locale content the site consumes.
- Adding a locale = new `[lang]` value + dictionaries + static assets. No locale cookie and no `Accept-Language` redirect logic on page routes.

## Design tokens

- Three layers: primitive (raw values) → semantic (purpose-named, theme-aware) → component (per-component slots). Components reference semantic or component tokens only; NEVER raw color/size literals in component code.
- Theme switching remaps the semantic layer only; primitives and component wiring stay unchanged.

## CI

- `pnpm install --frozen-lockfile --ignore-scripts`; `engines.node >= 24`; Renovate `automerge: false`.
- Preview deploys (`wrangler deploy --env preview`) only for same-repo PRs opened by the operator; fork and bot PRs get no preview.
