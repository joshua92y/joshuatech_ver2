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

- Pods are generated with `copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>` (`--trust` is required by the template's `_tasks: uv lock`); the generated pod must pass its tests unmodified and depends on `packages/django-common` (never copy common code into a pod).
- A generated pod is a standalone uv project — its own `uv.lock` (written by copier `_tasks: uv lock`), never a member of the root workspace (root `pyproject.toml` excludes `apps/*` and `templates/*`). It depends on `django-common` through a `tool.uv.sources` **path** source `../../packages/django-common` (editable), so the only supported layout is `<root>/apps/<pod>` next to `<root>/packages/django-common`; never generate a pod into another depth (such as `tests/fixtures/generated/<pod>`) — the source would not resolve.
- Images build from the repository-root context: `docker buildx build --platform linux/arm64 -f apps/<pod>/Dockerfile .` (the Dockerfile copies `packages/django-common` as well, keeping the `../../packages/django-common` layout inside the image); `publish-pod.yml` uses `context: .` + `file: apps/<pod>/Dockerfile`.
- The in-monorepo template path is not a git repository root, so copier reads the working tree and records no `_commit`; `copier update` is unsupported in SP-1 — regenerate and diff instead.
- Template harness (`templates/django-pod/tests/`, its own `pyproject.toml`/`uv.lock`, not a workspace member): it generates a sample pod into a temporary mini-repository (`<tmp>/apps/sample-pod` + a copy of `packages/django-common`), then runs `uv sync --locked`, the generated suite, the arm64 build, `kustomize build` + `kubeconform`, and the render assertions of `contracts/pod-template.md` §기본 테스트 6. Run it with `uv run --directory templates/django-pod --locked pytest -q` (Docker, `kustomize`, `kubeconform` on PATH); `JT_SAMPLE_POD_ROOT=<dir>` keeps the generated tree (a relative path is resolved against the repository root, because `uv run --directory` changes the cwd; the repository root, its parents, and anything under the template directory are refused), and the harness deletes only a directory it created itself (marker file `.jt-sample-pod-root`).
- Template changes must keep the generated output green; run the generated pod's suite (the harness above) before committing a template change.

## Table grades (TenantModel / GlobalModel)

- Grade A (tenant-scoped): inherit `TenantModel` — `tenant_id` UUID NOT NULL, index `(tenant_id, id)`, `ENABLE` + `FORCE ROW LEVEL SECURITY` + `tenant_isolation` policy via the `rls_policies(<table>)` migration helper. Rows are reachable only through the request transaction's `app.tenant_id` context; no context → 0 rows.
- Grade B (pod-global): inherit `GlobalModel`. Allowlist only: `tenant`, `tenant_membership`, `outbox`, `session_revocation_log`. Adding a B-grade table requires amending `contracts/pod-template.md` and this rule FIRST.
- `check_rls` (CI + startup) must pass: every A-grade table has ENABLE + FORCE RLS + policy (both `relrowsecurity` and `relforcerowsecurity`); every RLS-less table (catalog scan, not only Django models) is on the B allowlist or in `FRAMEWORK_TABLES` — the exact-name list of Django framework tables (`django_migrations`, `django_content_type`, `django_session`, `django_admin_log`, `auth_permission`, `auth_group`, `auth_group_permissions`, `auth_user`, `auth_user_groups`, `auth_user_user_permissions`) fixed as a constant in `django_common.tenancy`. Pods cannot widen it and no prefix rule applies; a contrib table outside the list requires amending `contracts/pod-template.md` and this rule FIRST.
- Roles: owner role has `bypassrls` and is used by migrations/seed only — NEVER at runtime; app role is `NOBYPASSRLS`. DB and role names are env-separated (`dev_` prefix in dev); never share a role across envs.

## Outbox and events

- Publish only via `django_common.outbox.publish(topic, subject, data, *, tenant_id=None)`, inside `transaction.atomic()`. No tenant context AND no `tenant_id` argument → `OutboxUsageError`; contextless paths (webhooks, admin revoke, startup jobs) MUST pass `tenant_id` explicitly. `tenant_id` must parse as a UUID (never a slug) and must not contradict the request's tenant context — both raise `OutboxUsageError`.
- Relay runs as the app role, selects `dead_at IS NULL` only (`FOR UPDATE SKIP LOCKED`); `attempts >= 10` → publish envelope to the env DLQ (prod `<pod>.dlq` · dev `dev.<pod>.dlq` — the relay prefixes the env; `contracts/events.md` §토픽 규약 is the source of truth) and set `dead_at`; dead rows purge at `dead_at + 30 d` (Celery beat, the template's only default beat job).

## Auth

- Request auth chain: Bearer JWT (JWKS via svc DNS; verify `iss` public URL, `aud`, `exp`, `nbf`) + `Cf-Access-Jwt-Assertion` (`aud` in {M2M, ADMIN} AND `common_name == ACCESS_EXPECTED_CN` — the service token's Client ID `<32 hex>.access`, not its name) + denylist (`revoked:sub:{sub}`, `revoked:sid:{sid}`). Denylist lookup failure = 503 `denylist-unavailable`, fail-closed (0.2 s timeout). The denylist client passes `retry=Retry(NoBackoff(), 0)` and a 0.2 s connect timeout explicitly, whatever the construction path (redis-py's `Redis(...)` constructor defaults to 10 exponential retries, `from_url` to 0 — rely on neither), so the verdict lands within the 0.2 s timeout; retries belong to the caller. Bearer verification requires `exp`, `iat`, `sub`, `aud`, `iss` (`options={"require": [...]}` — PyJWT otherwise accepts a token without `exp`); a `tenant_id` claim that is not a UUID is 401 `invalid_token`.
- `AUTH_ACTOR_SUB` set → additionally verify `act.sub`; unset (empty) = impersonation mode, no `act` check. Empty string is a VALID value for `AUTH_ACTOR_SUB` and dev `ADMIN_HOST` — required-setting checks assert presence, not non-emptiness.
- Exempt (exact path match, never a prefix): the three health endpoints plus the explicitly listed webhook paths. Webhook paths use HMAC instead: `X-Authentik-Signature: sha256=<hex>` = HMAC-SHA256(shared secret, canonical JSON of the body — `json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)`), body `pk` + `created` (ISO 8601 with tz) within ±5 min, `pk` as the idempotency key; every failure is 401 `webhook_signature_invalid` (`contracts/identity-admin-api.md` §웹훅 서명 규약).
- Access-only paths (`AUTH_ACCESS_ONLY_PATHS`, exact match, library default empty; identity-admin sets `("/session/check",)`): only the `Cf-Access-Jwt-Assertion` step runs — no Bearer verification, no actor check, no middleware denylist lookup; the request carries `access_claims` only (no `auth_claims`, no `tenant_id`). Paths that carry no Bearer (webhooks, access-only paths) must also be in `TENANT_CONTEXT_EXEMPT_PATHS`.
- Admin urlconf mounts only when `request.get_host() == ADMIN_HOST` (exact equality — never substring or containment, so an empty value matches no host); dev `ADMIN_HOST` is empty → no admin at all.
- Hosts outside `ALLOWED_HOSTS` get 400 before authentication on business paths (a credential-less request is 400, not 403). Kubelet HTTP probes send the pod IP as `Host` by default — the template must make probes pass (probe `httpHeaders` Host or the downward-API `POD_IP` added to `ALLOWED_HOSTS`).

## Settings

- pydantic-settings → Django settings; missing required values raise `ImproperlyConfigured` at startup. Secrets come from env (ESO `<pod>-env`) only; non-secret values (`ACCESS_AUD_*`, `ACCESS_EXPECTED_CN`, `AUTH_ACTOR_SUB`, `ADMIN_HOST`, `ALLOWED_HOSTS`, `IDENTITY_M2M_URL`) from ConfigMap. Mail via `MAILERS` only (no `EMAIL_*`).
- `DATABASE_OWNER_URL` exists only in the migrate Job's env (`<pod>-migrate`); it never appears in runtime env.
- In-cluster service URLs the pod calls (`AUTHENTIK_JWKS_URL`; identity-admin also `AUTHENTIK_API_URL`, `OPENFGA_API_URL`) must not point at the public domain `joshuatech.dev` or its subdomains — startup raises `ImproperlyConfigured` (pods never call public hosts, FR-046). Read settings at call time (`django.conf.settings`), never as import-time constants.

## Errors

- Every error response is RFC 9457 `application/problem+json` (`type` = `https://joshuatech.dev/problems/<slug with _ → ->`, `title`, `status`, optional `detail` that never carries tokens, secrets, or credentialed URLs). Request validation failures (missing query, wrong type, enum miss, non-JSON body) are 400 `validation_error` — never Ninja's default 422 `{detail}`.

## Tests (mandatory, constitution II)

- Every pod ships and keeps green the six baseline test areas: health trio (`/healthz`, `/ready` DB-only, `/health` always-200), tenant RLS (A: cross-tenant 0 rows, no-context 0 rows, owner all; B: app role reads all), outbox (usage errors, relay, DLQ, purge), auth middleware (token/Access/denylist/actor matrix), logging (fields present, `authorization`/`cookie`/`x-authentik-signature` absent), migrations + OpenAPI snapshot. NEVER delete or skip them.
- DeprecationWarning is promoted to an error only for your own modules — `filterwarnings = ["error::DeprecationWarning:<own module>", …]` in `pyproject.toml`; never a global `-W error` (a dependency's warning must not kill the suite).
- pytest runs with `--tb=short` (`addopts` in `pyproject.toml`): long tracebacks print call arguments with their current values, and psycopg's `Connection.connect` rebinds `conninfo` with the password, so a failed DB connection would print credentials. Use `--tb=long` only locally and never share that output.

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

- structlog JSON to stdout with `ts level logger event request_id tenant_id sub_hash trace_id span_id`. The processor strips `authorization`, `cookie`, `x-authentik-signature`, and query strings from logged URLs. Masking recurses into every `collections.abc.Mapping` (Django `request.headers` included), not only `dict`. An upstream `X-Request-ID` is trusted only when it matches `^[A-Za-z0-9._:-]{1,128}$`; otherwise a uuid4 is generated (`DJANGO_STRUCTLOG_TRUST_UPSTREAM_REQUEST_ID = True` in pod settings — the library default drops upstream ids).
- Spans add only `tenant_id` and `sub_hash`, strip query strings from URL attributes, and never capture request headers. Health: `/healthz` touches no dependency, `/ready` is `SELECT 1` only (no django-health-check table — it would break the RLS allowlist), and `/health` runs its dependency checks in parallel so the whole response stays under 3 s (the BFF fetch timeout) even when every dependency is down.
