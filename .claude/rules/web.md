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
- `/api/proxy/<pod>/<path>` routes through a static map only (SP-1: `identity-admin` → `IDENTITY_M2M_URL`, allowed paths `/tenants/me`, `/session/check`). NEVER assemble an upstream host from the `<pod>` segment. Unmapped pod or non-allowlisted path → 404 `not_found` with no upstream call.
- `return_to` (returnTo): accept only relative paths that start with `/` and not `//`; absolute and scheme-relative URLs → 400 `invalid_return_to`. Re-validate with the same rule on callback before redirecting.
- Errors are RFC 9457 `application/problem+json` with `request_id`; every response carries `x-request-id`, propagated downstream together with `traceparent`.
- Never put `access_token`, `code`, or `state` in URL paths or query strings of outgoing calls; token exchange and revocation checks use headers/body.
- Upstream fetches (pod and Authentik) use a 3 s `AbortController` timeout with no retry; timeout → 503 `upstream_unavailable`.

## Cookies and caching invariants

- MUST NOT set `Set-Cookie` on any `app/[lang]` response. Cookies (`jt_session`, `jt_csrf`, PKCE temp cookies) are set only by `/api/auth/*` handlers. Language and theme are expressed by URL path and `prefers-color-scheme`, never by cookie.
- `wrangler.jsonc` `assets.run_worker_first` lists only paths the Worker must see first (`/api/*`). NEVER put page paths (`/ko`, `/en`, `/ja`, or any other page route) in it — that turns asset-servable requests into billed Worker invocations.
- Workers Caching `[cache]` stays disabled: keep the default explicitly and never enable it (it makes asset requests billable).
- Access tokens never go into cookies; they live only in the isolate memory exchange cache (≤ 5 min).

## Logging and masking

- Logs are one-line JSON: `ts`, `level`, `request_id`, `route`, `status`, `upstream`, `upstream_ms`, `exchange_result`, `trace_id`.
- NEVER log the values of `Authorization`, `Cookie` (`jt_session`/`jt_csrf`), or `CF-Access-*` headers, nor `code`/`state` query values — not in logs, not in problem `detail`, not in Sentry events. Strip the query string from any logged URL. `sub` appears only hashed.
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
