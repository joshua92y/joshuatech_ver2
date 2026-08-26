# Boundary: Spec consistency

## Purpose
Ensure spec, plan, tasks, checklists, and constitution agree with each other.

## Checklist
- Every FR and User Story is covered by at least one task; every task traces back to a requirement.
- No `[NEEDS CLARIFICATION]` remains; no contradictions between spec and plan.
- Plan's Constitution Check passed, or violations are justified in Complexity Tracking.
- Every user story phase has test tasks written first plus one E2E task for the tester (constitution II).
- `/speckit-analyze` findings triaged: CRITICAL must be fixed before approval; HIGH listed.
- Unchecked checklist items counted and judged blocking or not.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` listing analyze CRITICAL/HIGH items and uncovered requirements.
