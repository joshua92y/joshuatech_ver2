---
paths:
  - "specs/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/specs_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `specs/`

- One feature = one immutable directory `specs/NNN-slug/`, created by Spec Kit (`/speckit-specify`, or `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` when brainstorming writes the spec). Never rename, move, or delete a feature directory; a change of intent is a new feature.
- `spec.md` header `**Status**` values: `Draft` → `Approved (YYYY-MM-DD)` → `Done (YYYY-MM-DD)`. Only `/approval-review` (after the human confirms) sets Approved; after the merge and `/speckit-archive-run`, the controller sets Done by hand (the archive skill only rewrites `Draft` → `Completed`, which never applies to an Approved spec).
- Spec Kit files (`spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`, `checklists/`) keep the Spec Kit template headings. Project additions per feature:
  - `reviews/YYYY-MM-DD-approval.md` — one section per boundary, `## 종합 의견`, `## 사용자 결정`.
  - `reviews/YYYY-MM-DD-finish.md` — `Status: Approved | Issues` on line 2, one section per boundary, `## Issues`.
  - `report.md` — `# Report NNN-slug` / `## Summary` / `## Changes Made` / `## Validation` / `## Next`.
- `specs/README.md` is an index table (number, feature, Status, priority, links) regenerated from each `spec.md` header. Change the header, then regenerate; never edit only the table.
- After approval, `spec.md`, `plan.md`, and `tasks.md` are read-only inputs for implementers. Allowed edits: `tasks.md` checkboxes (`[X]`) and phases appended by `/speckit-converge`.
- When dispatching subagents, pass only the task line(s) and the relevant spec/plan sections — never the whole feature directory.
- Prose in Korean; identifiers, slugs, and file names in English/ASCII.
