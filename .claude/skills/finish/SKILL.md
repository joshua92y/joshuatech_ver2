---
name: finish
description: "Close the active feature: write report.md, draft the learning note, update CHANGELOG, sync Korean mirrors, and run parallel per-boundary finish reviews so the finish-gate hook lets finishing-a-development-branch proceed. Use when implementation, converge, and E2E are done, or when the finish gate denies finishing."
---
> Canonical language: English. Korean mirror: docs/kr/skills/finish_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# finish

Run after `/speckit-converge` reports Converged and the tester reported PASS (or documented SKIPs). Produces the artifacts the `finish-gate` hook checks: `report.md`, `content/study/<feature>.mdx`, and the newest `reviews/YYYY-MM-DD-finish.md` whose line 2 is exactly `Status: Approved`.

## 0. Resolve the feature and preconditions
Resolve the feature as in approval-review (env → branch → feature.json; ask if unresolved or inconsistent). Confirm `tasks.md` has no unchecked `- [ ]` task lines (checklists excluded). If some remain, stop and list them.

## 1. `report.md`
Write `specs/<feature>/report.md`:

```markdown
# Report <NNN-slug>
## Summary
<what was built and why — 3 to 6 lines>
## Changes Made
<one line per file from `git diff --stat $(git merge-base main HEAD)...HEAD`>
## Validation
<test commands and results; converge result; tester report summary (PASS/FAIL/SKIP counts); anything not run and why>
## Next
<follow-ups, deferred items, risks>
```

## 2. Learning note draft
Write `content/study/<NNN-slug>.mdx` following `.claude/rules/content.md`: full frontmatter with `draft: true`, `change: "<NNN-slug>"`, `sources` listing spec, plan, report, and any decisions touched; the five sections `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. Sources of substance: the spec's decision table, plan Complexity Tracking, approval review findings, the report. If a note already exists, ask before creating a `-2` file.

## 3. CHANGELOG
Under `## [Unreleased]` in `CHANGELOG.md` add one bullet per user-visible change in the right category (Added/Changed/Fixed/Removed), each linking `specs/<NNN-slug>/`.

## 4. Decisions
If the feature made a durable decision (framework, boundary, data ownership, protocol, convention), draft `docs/decisions/NNNN-<title>.md` (MADR minimal, `status: proposed`) — with the adrkit draft command if installed, otherwise by hand — and link it from the report. Otherwise write "no durable decision" in the report's Summary.

## 5. Korean mirrors (best-effort, never blocking)
For each agent file changed in this feature (`CLAUDE.md`, `AGENTS.md`, `.specify/memory/constitution.md`, `.claude/rules/*`, `.claude/agents/*`, `.claude/skills/*/SKILL.md`), update its `docs/kr/` mirror. If context or time is short, prepend `> translation-pending (YYYY-MM-DD)` to the stale mirror instead and mention it in the report.

## 6. Finish review — one subagent per boundary, in parallel
Boundaries in `boundaries/`: `report-vs-diff.md`, `e2e-evidence.md`, `study-contract.md`, `decisions.md`. Dispatch one `general-purpose` subagent each with the boundary file plus exactly the inputs it names. Write `specs/<feature>/reviews/YYYY-MM-DD-finish.md`:

```markdown
# Finish review — <NNN-slug> (YYYY-MM-DD)
Status: Approved | Issues

## Report vs diff
…
## E2E evidence
…
## Study contract
…
## Decisions
…

## Issues
1. … (empty section when Approved)
```
Line 2 must be exactly `Status: Approved` or `Status: Issues` (the finish-gate hook reads the newest `*-finish.md` and its first Status line). `Status: Approved` only when every boundary reports ✅. On Issues: fix them (report, note, changelog, tests), then rerun step 6 until Approved.

## 7. Hand off
Regenerate `specs/README.md` (Status stays Approved until archive). Commit `docs(<NNN-slug>): report·학습 노트·finish 리뷰`. Tell the user: "finish complete — run superpowers:finishing-a-development-branch from the feature branch (the gate resolves the feature from the branch name); after the merge run the archive skill" and name the archive skill exactly as listed under `.claude/skills/speckit-archive*`.
