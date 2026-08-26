---
name: approval-review
description: "Run parallel per-boundary subagent reviews (security, tenant-data, operability, trends, spec-consistency) before a feature's spec/plan/tasks is marked Approved. Use when the user approves a feature, says 승인/approve/LGTM, or asks for a pre-approval review."
---
> Canonical language: English. Korean mirror: docs/kr/skills/approval-review_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# approval-review

Gate before implementation. Produces `specs/<feature>/reviews/YYYY-MM-DD-approval.md` and, only after the human confirms, sets the spec Status to Approved.

## 1. Resolve the active feature
In order: `$env:SPECIFY_FEATURE_DIRECTORY` → current git branch `NNN-slug` with `specs/<branch>/` → `.specify/feature.json` `feature_directory`. If none resolves or they disagree, ask the user which feature to review. Read `spec.md`, `plan.md`, `tasks.md`, and `checklists/*.md` if present. If `plan.md` or `tasks.md` is missing, stop and tell the user which Spec Kit command to run.

## 2. Gather machine inputs
- Run `/speckit-analyze` (read-only) and keep its report for the spec-consistency reviewer.
- Count unchecked `- [ ]` items in `checklists/*.md`.

## 3. Dispatch one reviewer per boundary — in parallel, in one message
For each file in `boundaries/` (`security.md`, `tenant-data.md`, `operability.md`, `trends.md`, `spec-consistency.md`) dispatch one `general-purpose` subagent. Prompt:

```
You are the <boundary> reviewer for feature <NNN-slug>. Read-only: do not edit any file.
<full contents of boundaries/<boundary>.md>

Inputs (excerpts only, pasted below):
- spec.md: User Scenarios & Testing, Requirements, Key Entities
- plan.md: Summary, Technical Context, Constitution Check, Project Structure, Complexity Tracking
- tasks.md: phase headings and task lines
- (spec-consistency only) the /speckit-analyze report and the unchecked checklist count
- constitution: .specify/memory/constitution.md Core Principles

Return ONLY the output format defined in the boundary file.
```
The `trends` reviewer may use WebSearch and must cite URLs; the other four must not fetch anything.

## 4. Write the review file
`specs/<feature>/reviews/YYYY-MM-DD-approval.md`:

```markdown
# Approval review — <NNN-slug> (YYYY-MM-DD)
Inputs: spec.md (Status: Draft), plan.md, tasks.md, checklists: <n> unchecked, /speckit-analyze: <finding count>

## Security
| 항목 | 상태 | 비고 |
|---|---|---|
### Findings

## Tenant & data boundary
…
## Operability
…
## Trends
| 기술 | 현재 plan | 최신 동향 | 제안 | 출처 |
|---|---|---|---|---|
### Findings

## Spec consistency
…

## 종합 의견
**판정**: 승인 권고 | 수정 후 승인 권고 | 재설계 권고
- 근거 (1–3 lines)
- 수정 필요 항목 (numbered, if any)

## 사용자 결정
- [ ] 승인 (YYYY-MM-DD)
```
Status cell values: ✅ 충족 · ⚠️ 보완 · ❌ 위반 · — 해당 없음.

## 5. Ask the human
Show `종합 의견` and the fix list, then use AskUserQuestion with options 승인 / 수정 후 재검토 / 재설계.
- 승인: tick the checkbox with today's date, set `**Status**: Approved (YYYY-MM-DD)` in `spec.md`, regenerate `specs/README.md`, commit `docs(<NNN-slug>): approval 리뷰 및 Status Approved`.
- 수정 후 재검토: list the edits as Spec Kit work (`/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`), then rerun this skill.
- 재설계: stop; the user decides the next step.

## Never
- Never set Approved without the human's explicit answer in step 5.
- Never paste whole files into reviewer prompts; excerpts only.
- Never start implementation from this skill.
