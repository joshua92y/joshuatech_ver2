---
paths:
  - "templates/fastapi-pod/**"
  - "packages/fastapi-common/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/fastapi-pod_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for FastAPI pods (`templates/fastapi-pod/`, `packages/fastapi-common/`)

SP-3 preparation: these paths do not exist yet. The globs above are reserved for the future FastAPI pod template and its shared package (mirroring the Django layout `templates/django-pod/` + `packages/django-common/`). When the first FastAPI pod is scaffolded under `apps/<pod>`, add its path here and note the carve-out in `django-pod.md` — until then, `django-pod.md` governs every `apps/<pod>`.

## Same contracts as Django pods

A FastAPI pod is a drop-in peer of a Django pod. Everything a caller or operator can observe MUST be identical to `contracts/pod-template.md`:

- Table grades: A (tenant-scoped, `tenant_id` UUID NOT NULL, FORCE RLS + `tenant_isolation` policy) and B (pod-global allowlist). The `check_rls`-equivalent check runs in CI and at startup.
- Outbox semantics: `publish(topic, subject, data, *, tenant_id=None)` inside a DB transaction only; no tenant context AND no argument → usage error; relay selects `dead_at IS NULL`, `max_attempts 10` → `<pod>.dlq` + `dead_at`, purge at `dead_at + 30 d`. Envelopes are CloudEvents 1.0 with `tenantid` UUID (`contracts/events.md`).
- Auth chain: Bearer JWT (JWKS via svc DNS, `iss` public URL, `aud`/`exp`/`nbf`) + Access JWT (`aud` + `common_name`) + denylist fail-closed 503 (0.2 s); health endpoints exempt; webhooks use HMAC + timestamp ±5 min + idempotency key.
- Health trio: `/healthz` (process only), `/ready` (DB only), `/health` (detailed, always 200); same probe wiring as the Django template.
- Settings: 12-factor via pydantic-settings; secrets from env (ESO `<pod>-env`) only; non-secrets from ConfigMap; owner DB URL only in the migrate Job.
- Migrations: PreSync Job with owner role only (CONNECT-boundary SQL first); expand → contract two-phase rule; RLS policy changes in their own migration; a migration linter gate in CI.
- Logging: structured JSON with `request_id tenant_id sub_hash trace_id span_id`; mask `authorization`/`cookie`/`x-authentik-signature`; no query strings.
- Tests: the same six baseline areas as `django-pod.md` (health, tenant RLS, outbox, auth middleware, logging, migrations + OpenAPI snapshot), mandatory and never skipped.
- Dragonfly: user = pod name, all self keys prefixed `<pod>:`, `socket_timeout` 0.2 s, denylist read-only via `%R~revoked:*`.

## FastAPI-specific rules

- All-async: every endpoint is `async def`; DB access uses an async driver/session; NEVER call blocking I/O (sync DB, `requests`, `time.sleep`) inside the event loop — wrap unavoidable sync work in a threadpool explicitly.
- Background work uses taskiq (not Celery): broker = Dragonfly with the same `<pod>:` key prefix; scheduled jobs (e.g. outbox dead purge) move to the taskiq scheduler with the same cadence and semantics.
- The tenant context middleware opens the transaction and sets `app.tenant_id` via `set_config(..., true)` before the route runs, same as `TenantContextMiddleware`; streaming responses do not touch the DB outside that transaction.
- OpenAPI snapshot: same refresh procedure as `django-pod.md` — deliberate regeneration, diff review, committed with the causing change.
