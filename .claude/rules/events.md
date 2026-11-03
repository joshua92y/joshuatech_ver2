---
paths:
  - "packages/events/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/events_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `packages/events/`

Contract of record: `specs/003-platform-foundation/contracts/events.md`. On conflict, the contract prevails; amend it first.

## Envelope (CloudEvents 1.0, JSON, structured mode)

- Every event is a CloudEvents 1.0 JSON envelope with `specversion`, `id`, `source`, `type`, `time`, `subject`, `tenantid`, `datacontenttype: application/json`, `data`.
- `id` = the outbox row id (ULID). Consumers store `(consumer_group, id)` for idempotent processing.
- Kafka headers: `ce_type`, `ce_source`, `ce_id`, `content-type: application/cloudevents+json` (structured mode — the envelope is the message value).
- `tenantid` is a CloudEvents extension attribute (lowercase alphanumeric name). Its value is ALWAYS the tenant UUID — never a slug. User-scoped events carry the user's tenant. An envelope without `tenantid` must never reach Kafka (`OutboxUsageError` upstream guards this).

## Topic conventions

- Names: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. Pod names are kebab-case; entity and event are singular lowercase. DLQ is prod `<pod>.dlq` · dev `dev.<pod>.dlq` (the relay prefixes the env; `contracts/events.md` §토픽 규약 is the source of truth).
- 3 partitions; partition key = `tenantid` (UUID string), so per-tenant ordering is preserved. Retention 7 days — a consumer that falls further behind recovers by re-indexing/re-projecting from the owning pod's DB, never by extending retention.
- Write access: only the owning pod publishes to its `<pod>.` topic prefix. NEVER publish on another pod's behalf.

## Schemas

- Every published topic has a schema under `packages/events/schemas/`; adding a topic without its schema is incomplete work.
- Consumers validate `data` against the `packages/events` schema; validation failure goes to the DLQ, not to a lenient parse.

## Compatibility rules (CI-enforced)

- Allowed changes: adding an OPTIONAL field; adding an enum value (consumers MUST ignore unknown enum values). Topic `data` schemas and `_envelope.json` therefore never set `additionalProperties: false` — consumers ignore unknown properties; a closed schema would send every event from a newer producer to the consumer's DLQ and would block CloudEvents extension attributes on the envelope.
- Forbidden: removing or renaming a field, changing a field's type (any change to the `type` set, including `string` → `["string", "null"]`), adding OR removing a `required` entry (a field that becomes optional breaks consumers that relied on it), removing an enum value, deleting a schema file. Metadata-only changes (`title`, `description`, `examples`, `x-version`, `$comment`) are not violations.
- A breaking change means a NEW topic (`...v2`) with a dual-publish period on both topics; never mutate the existing schema incompatibly.
- CI runs `packages/events/scripts/check-compat.mjs` (`--base <dir> --head <dir>`; exit 0 clean, 1 violations, 2 usage/IO error), comparing PR schemas field-by-field — nested objects and array `items` included, `_envelope.json` too — against `main`, reporting every violation with file, JSON-pointer path and kind. A violation fails the build. Never weaken or bypass this check to land a schema change.
- CI baseline and checker: a PR compares against the merge commit's first parent (after confirming the second parent is the PR head); a push compares against `before` (all zeros = empty baseline). The gate runs the **baseline commit's** `check-compat.mjs` and falls back to the change's own copy only when the baseline has none (bootstrap), so a PR cannot weaken the checker to land its own schema change; the checker's CLI path therefore imports only Node built-ins (ajv loads lazily inside `validateEvent`). Logic of record: `scripts/ci/events-compat.sh`. A PR that edits the workflow file itself runs its edited workflow — review blocks that (the limit of this trust model).
- Schemas use only the keys the checker compares or carries — structural `type`, `properties`, `required`, `items`, `enum`, `const`, `additionalProperties`; value constraints `format`, `pattern`, `minLength`, `maxLength`, `minimum`, `maximum`, `exclusiveMinimum`, `exclusiveMaximum`, `minItems`, `maxItems`, `uniqueItems`; metadata — and any other keyword (`$ref`, `allOf`, `prefixItems`, …) makes the checker exit 2. A changed `const` counts as `enum-removed`; value constraints are not machine-checked and must not change (a new `…v2` topic instead). Every property states its `type`.
- Adding an enum value ships consumer-first: consumers built with the new schema deploy before the producer emits the value, because an old schema's `enum` rejects it into the DLQ ("ignore unknown enum values" applies to business handling after validation).

## Consumer rules

- Consumer group names: `<pod>-<purpose>` (e.g. `notification-note-published`).
- Commit offsets only AFTER the processing transaction commits.
- 3 processing failures → move the original envelope (+ `error` header) to the DLQ; DLQ reprocessing is a manual command only.
- SP-1 alerting covers outbox pending/oldest-age and broker under-replication only; consumer-group lag metrics arrive in SP-2 — do not add ad-hoc lag alerting here.
