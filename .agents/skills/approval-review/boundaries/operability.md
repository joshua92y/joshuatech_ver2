# Boundary: Operability

## Purpose
Enforce constitution IV (Observability-Ready) and SaaS-grade operations.

## Checklist
- Logs are structured, carry a correlation id, and contain no secrets; health metrics and alert conditions are named.
- Rollback path documented; feature flag or reversible deploy where applicable.
- Failure modes, timeouts, retries, idempotency addressed.
- Runbook need identified (does this feature require a `docs/runbooks/` entry?).
- Cost and limits: quotas, free-tier constraints, rate limits.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` as in the security boundary.
