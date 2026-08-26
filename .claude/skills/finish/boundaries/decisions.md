# Boundary: Decisions

## Purpose
Durable decisions are recorded and unrequested changes are justified.

## Inputs
`report.md`; `plan.md` Complexity Tracking; `docs/decisions/` listing; `tasks.md` convergence phases; `.specify/memory/constitution.md`.

## Checklist
- If the feature introduced a framework, boundary, data ownership, protocol, or convention, an ADR exists (status proposed/accepted) and the report links it.
- Constitution amendments, if any, went through the constitution command and bumped the version.
- Converge `unrequested` items were removed or justified in the report.
- Nothing in the change contradicts an accepted ADR.

## Output format
`Verdict: ✅ | ❌` then a bullet list (missing ADR, contradiction, unjustified change).
