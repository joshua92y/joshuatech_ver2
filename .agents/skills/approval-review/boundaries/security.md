# Boundary: Security

## Purpose
Find security weaknesses in the design before code exists.

## Checklist
- Authentication and authorization: who may call what; default deny; admin surfaces protected.
- Input validation and injection (SQL/NoSQL/command/template); upload handling; size limits.
- Secrets: none in repo, config, or logs; rotation path stated.
- Data exposure: PII in logs, error bodies, or URLs; verbose error messages.
- Transport and storage: TLS; encryption at rest for sensitive fields; token lifetimes.
- Supply chain: each new dependency, extension, or tool is justified and pinned.
- Abuse: rate limits, enumeration, replay, CSRF/SSRF where relevant.

## Output format
`| 항목 | 상태 | 비고 |` — one row per checklist line, 상태 ∈ ✅/⚠️/❌/—.
`### Findings` — for each ⚠️/❌: severity (high/medium/low), what, where (spec/plan/tasks section), concrete fix.
