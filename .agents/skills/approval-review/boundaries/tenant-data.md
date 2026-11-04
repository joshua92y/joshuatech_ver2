# Boundary: Tenant & data

## Purpose
Enforce constitution III (Tenant Boundary) and data ownership, even for single-tenant features.

## Checklist
- Every Key Entity names its owner and isolation key (tenant id or equivalent), or states why it is global.
- No cross-service table sharing or implicit joins; cross-boundary reads go through explicit contracts.
- Migrations are backward compatible, reversible, and owned by one service.
- Data lifecycle: retention, deletion, export, backup are addressed or explicitly out of scope.
- Nothing hard-codes a single tenant; tests include an isolation case wherever data exists.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` as in the security boundary.
