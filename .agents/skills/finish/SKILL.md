---
name: finish
description: Close an implemented feature by producing its report, learning note, changelog entry, and parallel finish-review evidence.
---

# Finish

Produce the repository-owned finish artifacts and prove that the active feature is ready for branch integration.

## Safety invariants

- Never modify an Approved or Done `spec.md`, `plan.md`, or `tasks.md`.
- Do not claim readiness unless convergence is clean, every task is checked, and E2E evidence has no unresolved failure.
- Review agents are read-only and receive only the inputs named by their boundary rubric.

## 0. Resolve and verify the feature

Resolve the active feature from `SPECIFY_FEATURE_DIRECTORY`, the current feature branch and its matching `specs/<branch>/` directory, with `.specify/feature.json` used as a consistency check. Ask for the feature directory and stop when no authoritative source resolves or sources disagree.

Every candidate from the environment, branch, or `.specify/feature.json` must canonicalize to an immediate child of `<git-root>/specs/`, have a basename matching `^\d{3,}-[a-z0-9-]+$`, and traverse no existing reparse point or link. Reject any outside, nested, invalidly named, or linked candidate before comparing sources or reading feature artifacts.

Require `spec.md`, `plan.md`, and `tasks.md`, and require the spec Status to be Approved. Stop and list any unchecked task lines in `tasks.md`; checklist files are not task lines.

Resolve `$speckit-converge` directly to `.agents/skills/speckit-converge/SKILL.md`, read that file completely, and execute its full workflow as a nested step in this same turn. Explicit-only Spec Kit skills are not guaranteed to appear in the implicit skill catalog, so do not depend on catalog listing. Bind no child arguments unless the triggering user message explicitly supplied them; a literal `$ARGUMENTS` token in a managed skill is a placeholder, never user input. Apply the repository's stronger immutability rule while nesting it: inspect and report convergence, but do not append to an Approved `tasks.md`. If convergence finds remaining work, stop and report that the work must move to an authorized follow-up feature. Continue only after the nested workflow reports Converged without changing approved artifacts.

Locate the tester's E2E report in the current conversation or feature reviews. Require PASS for every user story, allowing only a documented SKIP with its exact environmental reason. Stop on an unresolved FAIL or missing story evidence.

## 1. Write the report

Compute the merge base with `main`, then inspect the complete diff stat and commit list from that base through `HEAD`. Write `specs/<feature>/report.md`:

```markdown
# Report <feature>
## Summary
<what was built and why; 3–6 lines>
## Changes Made
<one line per changed file>
## Validation
<commands and results; convergence result; tester PASS/FAIL/SKIP counts; anything not run and why>
## Next
<follow-ups, deferred items, and risks>
```

Do not claim tests or changes that the evidence does not show.

## 2. Draft the learning note

Explicitly read `.claude/rules/content.md`; Codex does not inherit that path rule automatically. Write `content/study/<feature>.mdx` with its required frontmatter, `draft: true`, `change: "<feature>"`, sources for the spec, plan, report, and relevant decisions, followed by the five required Korean sections in order. Draw substantive material from the spec decision table, plan Complexity Tracking, approval findings, the report, and the per-task learning logs under `content/tmp/<NNN>-*/` (see the `content/tmp/` section of `.claude/rules/content.md`). After the Study contract boundary of the finish review is ✅, delete the consumed `content/tmp/<NNN>-*/` directories in the same commit as the note. If a note already exists, use `request_user_input` when available to ask before creating a numbered second note; otherwise ask in the normal response and stop.

## 3. Update the changelog

Under `## [Unreleased]` in `CHANGELOG.md`, add one linked bullet per user-visible change under the appropriate Added, Changed, Fixed, or Removed category. Link each bullet to the feature directory.

## 4. Record durable decisions

If the feature introduced a durable framework, boundary, ownership, protocol, or convention decision, draft the next MADR document under `docs/decisions/` with `status: proposed` and link it from the report. Use an installed ADR drafting tool when available; otherwise write the repository's minimal MADR format directly. If there was no durable decision, state that in the report Summary.

## 5. Synchronize Korean mirrors

Best-effort, update the existing `docs/kr/` mirror for each changed agent file, including `AGENTS.md`, `CLAUDE.md`, the constitution, project rules, Claude agent or skill files, Codex agent files, and repository Codex skills. If time or context prevents a translation, prepend `> translation-pending (YYYY-MM-DD)` to the stale mirror and record it in the report. Mirror staleness never blocks finishing.

## 6. Run finish reviews

Use the four rubrics in `boundaries/`: `report-vs-diff.md`, `e2e-evidence.md`, `study-contract.md`, and `decisions.md`. Prepare one prompt per rubric with exactly the inputs it names. Include the full rubric and tell the reviewer to make no file changes and return only the required format.

Call `spawn_agent` once per reviewer with `fork_turns: "none"` and a unique lowercase snake-case task name. Start all four reviewers before making any wait call. Then use `wait_agent` until all four results return. If a reviewer fails, retry that boundary once with a fresh unique task name; if it still fails, stop rather than inventing approval.

Write `specs/<feature>/reviews/YYYY-MM-DD-finish.md`:

```markdown
# Finish review — <feature> (YYYY-MM-DD)
Status: Approved | Issues

## Report vs diff
...
## E2E evidence
...
## Study contract
...
## Decisions
...

## Issues
```

Line 2 must be exactly `Status: Approved` or `Status: Issues`. Use Approved only when every boundary returns `✅`. On Issues, fix mutable finish artifacts, tests, or implementation as authorized, then rerun all four reviews. If a correction would require changing an approved spec, plan, or tasks file, stop and require a follow-up feature instead.

## 7. Finalize and hand off

Regenerate `specs/README.md` without changing the feature Status, and commit `docs(<feature>): report·학습 노트·finish 리뷰`. Recheck that the newest finish review is Approved and that the report and learning note are non-empty.

Only after every condition succeeds, include this exact marker on its own line in the final response:

```text
<!-- CODEX_FINISH_READY -->
```

Tell the user that branch integration may proceed. After the merge, hand off exactly to `$speckit-archive-run specs/<feature>` so project memory and the feature index can be finalized.
