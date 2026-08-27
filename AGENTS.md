> Canonical language: English. Korean mirror: docs/kr/AGENTS_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# AGENTS.md — JoshuaTech v2

## Project
Developer portfolio platform rebuilt from scratch (v1: `d:\code\joshuatech`). Operated with SaaS-grade discipline and multi-tenant-ready boundaries; publishes its own learning notes (learning in public). **Current state (SP-0): tooling and conventions only — no application code. The stack is decided in SP-1.**

## Active agent integration
Spec Kit integration: `claude` only (skills under `.claude/skills/speckit-*`). Other agents (Codex, Gemini, …) read this file, `.specify/memory/constitution.md`, and `specs/<feature>/`. They do not get the Claude hooks, so they must follow the workflow manually and must never edit an approved `spec.md`, `plan.md`, or `tasks.md`.

## Commands
| Purpose | Command |
|---|---|
| Allocate a feature directory (brainstorming path) | `pwsh .specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` |
| Feature paths / prerequisites | `pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json` |
| Hook unit tests | `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1` |
| All repository checks | `pwsh -NoProfile -File tests/run-all.ps1` |
| Regenerate `specs/README.md` | `pwsh -NoProfile -File scripts/update-specs-index.ps1` — if run-all `scripts`/`specs-index-fresh` fails: run it, then commit `specs/README.md`; on `error: <dir>/spec.md: …`: fix that spec header and rerun |
| Spec Kit CLI (init / upgrade / extensions) | `specify` from `~/.local/bin` (install via `uv`); procedure in `docs/runbooks/spec-kit-upgrade.md` |

## Layout
```
.specify/        Spec Kit runtime: memory/constitution.md, templates/ (+overrides/), scripts/powershell/, extensions/, feature.json (local only)
.claude/         Claude layer: settings.json, skills/, agents/tester.md, rules/, hooks/
specs/           one immutable directory per feature (NNN-slug) + README.md index
docs/            README.md index, decisions/ (MADR), runbooks/, kr/ (Korean mirrors)
content/study/   learning notes (.mdx) consumed by the site
tests/           hook tests and repository checks
```

## Conventions
- Branch = feature directory name (`NNN-slug`), created by the Spec Kit git extension; `main` is integration only; worktrees under `.worktrees/`.
- Commits: Conventional Commits, Korean description allowed (`feat(scope): 설명`); one commit per task; never force-push or rewrite shared history.
- Files: UTF-8, LF, ASCII kebab-case names. Korean prose in specs, docs, and notes; English in agent files and code identifiers.
- Tests first (constitution II). Test files live under `tests/`, `e2e/`, `__tests__/`, or are named `*.test.*` / `*.spec.*`.
- Secrets never enter the repository.

## Workflow (short form)
specify → clarify → plan → checklist → tasks → approval-review → build (TDD, subagent-driven) → converge → E2E (tester) → finish → finishing branch → merge → archive. Details: `CLAUDE.md` and the constitution.
