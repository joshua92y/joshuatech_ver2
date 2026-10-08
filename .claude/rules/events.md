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

- Names: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. Pod names are kebab-case; entity and event are singular lowercase. DLQ is `<pod>.dlq`.
- 3 partitions; partition key = `tenantid` (UUID string), so per-tenant ordering is preserved. Retention 7 days — a consumer that falls further behind recovers by re-indexing/re-projecting from the owning pod's DB, never by extending retention.
- Write access: only the owning pod publishes to its `<pod>.` topic prefix. NEVER publish on another pod's behalf.

## Schemas

- Every published topic has a schema under `packages/events/schemas/`; adding a topic without its schema is incomplete work.
- Consumers validate `data` against the `packages/events` schema; validation failure goes to the DLQ, not to a lenient parse.

## Compatibility rules (CI-enforced)

- Allowed changes: adding an OPTIONAL field; adding an enum value (consumers MUST ignore unknown enum values).
- Forbidden: removing or renaming a field, changing a field's type, adding a `required` field, removing an enum value.
- A breaking change means a NEW topic (`...v2`) with a dual-publish period on both topics; never mutate the existing schema incompatibly.
- CI runs `packages/events/scripts/check-compat.mjs`, comparing PR schemas field-by-field against `main`; a violation fails the build. Never weaken or bypass this check to land a schema change.

## Consumer rules

- Consumer group names: `<pod>-<purpose>` (e.g. `notification-note-published`).
- Commit offsets only AFTER the processing transaction commits.
- 3 processing failures → move the original envelope (+ `error` header) to the DLQ; DLQ reprocessing is a manual command only.
- SP-1 alerting covers outbox pending/oldest-age and broker under-replication only; consumer-group lag metrics arrive in SP-2 — do not add ad-hoc lag alerting here.
