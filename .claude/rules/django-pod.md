---
paths:
  - "apps/*/pyproject.toml"
  - "apps/*/*.py"
  - "apps/*/**/*.py"
  - "apps/*/Dockerfile"
  - "packages/django-common/**"
  - "templates/django-pod/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/django-pod_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for Django pods (`apps/<pod>/`, `packages/django-common/`, `templates/django-pod/`)

Scope: Django pod file shapes (`*.py`, `pyproject.toml`, `Dockerfile`) under `apps/*`, plus `packages/django-common/` and `templates/django-pod/`. `apps/web` is a JS tree and matches none of these globs, so this rule never loads there (`web.md` governs it). Contract of record: `specs/003-platform-foundation/contracts/pod-template.md` (+ `contracts/events.md` for outbox). On conflict, the contracts prevail; amend them first.

## Template and structure

- Pods are generated with `copier copy templates/django-pod apps/<pod>`; the generated pod must pass its tests unmodified and depends on `packages/django-common` (never copy common code into a pod).
- Template changes must keep the generated output green; run the generated pod's suite before committing a template change.

## Table grades (TenantModel / GlobalModel)

- Grade A (tenant-scoped): inherit `TenantModel` — `tenant_id` UUID NOT NULL, index `(tenant_id, id)`, `ENABLE` + `FORCE ROW LEVEL SECURITY` + `tenant_isolation` policy via the `rls_policies(<table>)` migration helper. Rows are reachable only through the request transaction's `app.tenant_id` context; no context → 0 rows.
- Grade B (pod-global): inherit `GlobalModel`. Allowlist only: `tenant`, `tenant_membership`, `outbox`, `session_revocation_log`. Adding a B-grade table requires amending `contracts/pod-template.md` and this rule FIRST.
- `check_rls` (CI + startup) must pass: every A-grade table has FORCE RLS + policy; every RLS-less table is on the B allowlist.
- Roles: owner role has `bypassrls` and is used by migrations/seed only — NEVER at runtime; app role is `NOBYPASSRLS`. DB and role names are env-separated (`dev_` prefix in dev); never share a role across envs.

## Outbox and events

- Publish only via `django_common.outbox.publish(topic, subject, data, *, tenant_id=None)`, inside `transaction.atomic()`. No tenant context AND no `tenant_id` argument → `OutboxUsageError`; contextless paths (webhooks, admin revoke, startup jobs) MUST pass `tenant_id` explicitly.
- Relay runs as the app role, selects `dead_at IS NULL` only (`FOR UPDATE SKIP LOCKED`); `attempts >= 10` → publish envelope to `<pod>.dlq` and set `dead_at`; dead rows purge at `dead_at + 30 d` (Celery beat, the template's only default beat job).

## Auth

- Request auth chain: Bearer JWT (JWKS via svc DNS; verify `iss` public URL, `aud`, `exp`, `nbf`) + `Cf-Access-Jwt-Assertion` (`aud` in {M2M, ADMIN} AND `common_name == ACCESS_EXPECTED_CN`) + denylist (`revoked:sub:{sub}`, `revoked:sid:{sid}`). Denylist lookup failure = 503 `denylist-unavailable`, fail-closed (0.2 s timeout).
- `AUTH_ACTOR_SUB` set → additionally verify `act.sub`; unset (empty) = impersonation mode, no `act` check. Empty string is a VALID value for `AUTH_ACTOR_SUB` and dev `ADMIN_HOST` — required-setting checks assert presence, not non-emptiness.
- Exempt: the three health endpoints only. Webhook paths are explicitly listed and use HMAC + timestamp ±5 min + idempotency key instead.
- Admin urlconf mounts only when `request.get_host() == ADMIN_HOST`; dev `ADMIN_HOST` is empty → no admin at all.

## Settings

- pydantic-settings → Django settings; missing required values raise `ImproperlyConfigured` at startup. Secrets come from env (ESO `<pod>-env`) only; non-secret values (`ACCESS_AUD_*`, `ACCESS_EXPECTED_CN`, `AUTH_ACTOR_SUB`, `ADMIN_HOST`, `ALLOWED_HOSTS`, `IDENTITY_M2M_URL`) from ConfigMap. Mail via `MAILERS` only (no `EMAIL_*`).
- `DATABASE_OWNER_URL` exists only in the migrate Job's env (`<pod>-migrate`); it never appears in runtime env.

## Tests (mandatory, constitution II)

- Every pod ships and keeps green the six baseline test areas: health trio (`/healthz`, `/ready` DB-only, `/health` always-200), tenant RLS (A: cross-tenant 0 rows, no-context 0 rows, owner all; B: app role reads all), outbox (usage errors, relay, DLQ, purge), auth middleware (token/Access/denylist/actor matrix), logging (fields present, `authorization`/`cookie`/`x-authentik-signature` absent), migrations + OpenAPI snapshot. NEVER delete or skip them.
- pytest runs `-W error::DeprecationWarning`; `filterwarnings` entries are scoped to your own modules only.

## Migrations

- Only the Argo PreSync migrate Job (owner role) runs migrations; the app never migrates. The Job's first step is the idempotent CONNECT-boundary SQL (`REVOKE CONNECT ... FROM PUBLIC; GRANT CONNECT ...`) before `manage.py migrate`.
- Two-phase rule: column drops, adding NOT NULL, and type changes MUST be split expand → contract across two releases.
- RLS policy changes go in their own dedicated migration — never mixed with schema or data changes.
- CI gate: `makemigrations --check` + `django-migration-linter` must pass (linter flags destructive operations).

## Dragonfly

- All self-owned keys use the `<pod>:` prefix — Celery `broker_transport_options.global_keyprefix` and cache `KEY_PREFIX`. Dragonfly user = pod name; denylist keys are read-only via ACL `%R~revoked:*`. `socket_timeout` 0.2 s.

## OpenAPI snapshot refresh

- The snapshot changes only deliberately: after an intentional API change or a django-ninja minor bump, run the suite, review the snapshot diff route-by-route, and commit the updated snapshot in the same commit as the change that caused it. Never regenerate blindly to make the build green.

## Logging

- structlog JSON to stdout with `ts level logger event request_id tenant_id sub_hash trace_id span_id`. The processor strips `authorization`, `cookie`, `x-authentik-signature`, and query strings from logged URLs.
