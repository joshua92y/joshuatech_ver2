> Canonical language: English. Korean mirror: docs/kr/CLAUDE_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

@AGENTS.md

# CLAUDE.md — how Claude works in this repository

## Prerequisites
- Exactly one superpowers plugin is enabled at user level: `superpowers@superpowers-dev` (5.1.0). Keep `superpowers@claude-plugins-official` disabled (it double-injects the SessionStart hook).
- The Spec Kit CLI (`specify`, installed with `uv`, in `~/.local/bin`) is needed only for init, upgrade, and extension management; daily commands use `.specify/scripts/powershell/*.ps1`.
- Hooks run as `pwsh -NoProfile -ExecutionPolicy Bypass -File …`; PowerShell 7 must be on PATH.

## Tool boundaries
- **Spec Kit owns WHAT**: constitution, `specs/NNN-slug/{spec,plan,tasks,research,…}`, analyze, converge, archive. `speckit-*` skills are user-invocable only (settings `skillOverrides`); invoke them explicitly, never guess at them.
- **superpowers owns HOW**: brainstorming (architecture-level intake only), test-driven-development, subagent-driven-development, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, systematic-debugging, verification-before-completion.
- **This repository owns the gates**: the `tester` agent, `/approval-review`, `/finish`, and the hooks in `.claude/hooks/`.
- Do NOT use `speckit-implement`; superpowers subagent-driven-development executes `tasks.md`.
- Do NOT use superpowers `writing-plans`; `tasks.md` is the only implementation plan (the sole exception was `specs/001-claude-setup/plan.md`).
- When brainstorming is used, the design is saved as `specs/NNN-slug/spec.md` in Spec Kit spec-template format: run `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` to allocate the directory, fill that `spec.md`, then continue with `/speckit-plan`.
- Give subagents task slices and the relevant sections only — never whole spec or plan files.
- Read `.specify/memory/constitution.md` before planning and `docs/decisions/` before any architectural change.

## Lifecycle
1. Intake: `/speckit-specify "<description>"` (the git extension creates branch `NNN-slug`) → `/speckit-clarify` when ambiguous. Architecture-level work: superpowers brainstorming → spec.md as above.
2. Plan: `/speckit-plan` → `/speckit-checklist` → `/speckit-tasks`.
3. Approval: when the user approves, run `/approval-review` first; set `**Status**: Approved` only after the user confirms.
4. Build: superpowers subagent-driven-development over `tasks.md` (TDD, per-task review, one commit per task, tick `[X]`).
5. Converge: `/speckit-converge` until it reports Converged.
6. Verify: dispatch the `tester` agent with the feature directory, the spec's User Scenarios section, and the test command.
7. Finish: `/finish`, then `superpowers:finishing-a-development-branch` from the feature branch (the finish-gate hook denies it until the finish artifacts exist).
8. After merge: `/speckit-archive-run specs/<NNN-slug>` so `.specify/memory/` reflects the merged feature; set the spec Status to Done and regenerate `specs/README.md`.

## Active feature resolution
`SPECIFY_FEATURE_DIRECTORY` → current branch `NNN-slug` ↔ `specs/<branch>/` → `.specify/feature.json` (consistency check only; it never resolves a feature by itself). Sources must agree; if none resolves, ask. `feature.json` is a per-checkout convenience, not the record; the record is the git branch plus `specs/<feature>/`.

## Project-owned hooks, skills, agents
| Item | Location | Role |
|---|---|---|
| approval-review hook | `.claude/hooks/approval-review.ps1` (UserPromptSubmit) | approval keyword → instructs to run `/approval-review` first |
| finish-gate hook | `.claude/hooks/finish-gate.ps1` (PreToolUse, Skill) | denies finishing until the newest finish review is Approved and `report.md` + study note exist |
| tester-write-guard | `.claude/hooks/tester-write-guard.ps1` (tester PreToolUse) | the tester may write test paths inside the repo only |
| `/approval-review` | `.claude/skills/approval-review/` | five boundary subagents → `reviews/*-approval.md` |
| `/finish` | `.claude/skills/finish/` | report, study note, CHANGELOG, mirrors, four boundary subagents → `reviews/*-finish.md` |
| `tester` | `.claude/agents/tester.md` | E2E per user story, PASS/FAIL/SKIP report |
| rules | `.claude/rules/{specs,docs,content}.md` | path-scoped formats and contracts |

The gates check artifact existence and path shape, not provenance; a manual `git merge`/`gh pr merge` bypasses them — do not merge outside `finishing-a-development-branch`. Hook tests: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1`. All checks: `pwsh -NoProfile -File tests/run-all.ps1`.

## Language
Agent files (this file, `AGENTS.md`, the constitution, rules, agents, project skills) are English with mirrors in `docs/kr/`. Conversation, specs, plans, reports, learning notes, and comments are Korean. Identifiers, slugs, and file names are English/ASCII.

## Documentation index
`docs/README.md`.

<!-- SPECKIT START -->
<!-- SPECKIT END -->
