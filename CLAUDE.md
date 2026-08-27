> Canonical language: English. Korean mirror: docs/kr/CLAUDE_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

@AGENTS.md

# CLAUDE.md — how Claude works in this repository

## Prerequisites
- Exactly one superpowers plugin is enabled at user level: `superpowers@superpowers-dev` (5.1.0). Keep `superpowers@claude-plugins-official` disabled (it double-injects the SessionStart hook).
- The Spec Kit CLI (`specify`, installed with `uv`, in `~/.local/bin`) is needed only for init, upgrade, and extension management; daily commands use `.specify/scripts/powershell/*.ps1`.
- Hooks run as `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.ps1"` (Git Bash is the hook shell on Windows); PowerShell 7 must be on PATH.

## Tool boundaries
- **Spec Kit owns WHAT**: constitution, `specs/NNN-slug/{spec,plan,tasks,research,…}`, analyze, converge, archive. `speckit-*` skills are listed name-only (settings `skillOverrides`: descriptions hidden so they never auto-trigger); invoke one only when the user asks or the lifecycle step below calls for it — never guess.
- **superpowers owns HOW**: brainstorming (architecture-level intake only), test-driven-development, subagent-driven-development, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, systematic-debugging, verification-before-completion.
- **This repository owns the gates**: the `tester` agent, `/approval-review`, `/finish`, and the hooks in `.claude/hooks/`.
- Do NOT use `speckit-implement`; superpowers subagent-driven-development executes `tasks.md`.
- Do NOT use superpowers `writing-plans`; `tasks.md` is the only implementation plan (the sole exception was `specs/001-claude-setup/plan.md`).
- When brainstorming is used, the design is saved as `specs/NNN-slug/spec.md` in Spec Kit spec-template format: run `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` to allocate the directory, fill that `spec.md`, then continue with `/speckit-plan`.
- Give subagents task slices and the relevant sections only — never whole spec or plan files.
- `/speckit-tasks`: the resolved template (`.specify/templates/overrides/tasks-template.md`) says tests are MANDATORY; that overrides the generated skill prompt's "tests optional" wording. Every user story phase gets test-first tasks plus one E2E task for the `tester`.
- Hooks resolve their scripts through `${CLAUDE_PROJECT_DIR}`, so they survive `cd`; still prefer `git -C` and absolute paths over `cd` so relative paths in commands stay valid.
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

## Active Technologies
- PowerShell 7.6.5 (`pwsh`) — hooks, tests, and repository scripts (`.claude/hooks/*.ps1`, `tests/**/*.ps1`, `scripts/*.ps1`)
- Spec Kit `specify` 1.0.2.dev0 (integration `claude`, script `ps`) with extensions git, agent-context, archive
- superpowers 5.1.0 (`superpowers@superpowers-dev`, the only enabled superpowers plugin)
- No application stack yet — decided in SP-1

## Project Structure
Layout table: `AGENTS.md` (imported above). Added since: `scripts/` (`update-specs-index.ps1`), `tests/scripts/` (its tests and fixtures), `specs/002-smoke/`.

## Commands
Commands table: `AGENTS.md`. Archive a merged feature: `/speckit-archive-run specs/<NNN-slug>`.

## Recent Changes
- specs/001-claude-setup: SP-0 tooling — Spec Kit + superpowers + repo gates (hooks/skills/tester/rules/tests), docs policy, smoke feature 002 merged

## Known Issues & Gotchas
### ⚠️ Two superpowers plugins enabled at once
**Issue:** `using-superpowers` was injected twice at SessionStart, and the two plugin versions competed for one namespace.
**Root Cause:** `superpowers@superpowers-dev` (5.1.0) and `superpowers@claude-plugins-official` (6.x) both register a SessionStart hook under the same plugin name.
**Prevention Rule:** Keep exactly one superpowers plugin enabled (`superpowers@superpowers-dev`); check `enabledPlugins` in `~/.claude/settings.json` after any plugin change.

### ⚠️ `skillOverrides: user-invocable-only` breaks skill chaining
**Issue:** `/speckit-specify` could not call `speckit-git-feature`, and the controller could not invoke any overridden skill.
**Root Cause:** `user-invocable-only` blocks every model-side `Skill` call, not just auto-triggering; only `name-only` hides the description while keeping calls possible.
**Prevention Rule:** Use `name-only` for skills that must stay explicit; never `user-invocable-only` on a skill that another skill or the controller calls.

### ⚠️ adrkit does not install on Spec Kit 1.0.x
**Issue:** `specify extension add adrkit` fails; the SP-0 ADRs were written by hand in MADR format.
**Root Cause:** adrkit 0.1.2 declares `spec-kit >=0.13,<0.16`, needs the separate npm `@adrkit/cli`, and reads its ADR path only from `ADRKIT_DIR`.
**Prevention Rule:** Check an extension's `spec-kit` range with `specify extension info <name>` before planning around it; adrkit stays Tier 2 until the gate lifts.

### ⚠️ `.specify/feature.json` disagreeing with the branch
**Issue:** The finish-gate denies `finishing-a-development-branch` when `feature.json` names a feature other than the current `NNN-slug` branch (typical right after a merge).
**Root Cause:** `feature.json` is a gitignored per-checkout file written by `create-new-feature.ps1`; branches switch, it does not.
**Prevention Rule:** Resolve the feature from `SPECIFY_FEATURE_DIRECTORY` or the branch and treat `feature.json` as a consistency check only; delete it after a merge.

### ⚠️ Hook tests that treat "no output" as allow
**Issue:** Six harness assertions passed while a hook crashed, because a crashed PreToolUse hook also prints nothing.
**Root Cause:** The assertions checked stdout only, not the exit code; the path guard likewise accepted `tests/../src` and repo-prefix collisions before normalization.
**Prevention Rule:** Every "allow" assertion requires exit code 0 and empty output; guards normalize with `GetFullPath` and require the `<root>/` prefix; gate logic fails closed, only input parsing fails open.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/002-smoke/plan.md
<!-- SPECKIT END -->
