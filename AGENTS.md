> Canonical language: English. Korean mirror: docs/kr/AGENTS_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# AGENTS.md — JoshuaTech v2

## Project
Developer portfolio platform rebuilt from scratch (v1: `d:\code\joshuatech`). Operated with SaaS-grade discipline and multi-tenant-ready boundaries; publishes its own learning notes (learning in public). **Current state (SP-1 / feature 003): the platform foundation is in progress; application, package, template, infrastructure, and E2E trees now exist, and the stack is recorded in ADR 0002–0010.**

## Active agent integration
Spec Kit integrations: `claude` (skills under `.claude/skills/speckit-*`) and `codex` (skills under `.agents/skills/speckit-*`); `claude` remains the default integration. Codex reads this file, `.specify/memory/constitution.md`, and `specs/<feature>/`. It does not automatically inherit `.claude/settings.json`, hooks, rules, or agents: the adapter below explicitly reuses shared Markdown bodies and supplies Codex-native wiring while leaving Claude behavior intact. Other agents (Gemini, …) follow the workflow manually. No agent may edit an approved `spec.md`, `plan.md`, or `tasks.md`.

## Adapter boundaries
- Preserve the existing Claude configuration. `.claude/settings.json`, `.claude/hooks/`, Claude skill overrides, and the Claude plugin setup remain authoritative for Claude Code; the Codex adapter supplements them rather than replacing or rewriting them.
- `.agents/skills/` contains Codex-discoverable skills. `.codex/hooks.json` and `.codex/hooks/` contain Codex hook wiring and handlers; `.codex/agents/*.toml` contains Codex subagent adapters; `.codex/rules/*.rules` contains command-execution policy only.
- For `.claude/agents/*.md`, the Markdown body below the frontmatter is the shared canonical role contract for Claude and Codex. Its YAML frontmatter (`tools`, `skills`, and `hooks`) is Claude-only. Keep `.codex/agents/*.toml` semantically synchronized with that body without copying Claude-only YAML behavior blindly.
- Codex hooks and agents use Codex-native tool names and payloads. Approval context may fail open, but when dispatched, the destructive-command policy, finish-readiness gates, and tester write guard MUST fail closed: malformed or ambiguous protected input, an unresolved/outside-repository path, or a non-test write target is denied.
- The tester's hard write guard covers `apply_patch` targets only. The tester MUST NOT use shell commands or other tools to write files; if the agent-local hook is inactive or untrusted, it performs read-only verification and reports the missing guard. The finish `Stop` hook gates only the `$finish` readiness marker and does not intercept a direct merge or push, which remains forbidden outside the documented branch-finishing workflow.
- `.codex/rules/*.rules` provides direct-argv defense in depth; the synchronous global `PreToolUse` `^Bash$` handler is wired to inspect compound commands, option placement, executable paths, and supported shell wrappers. Neither mechanism loads prose instructions or replaces the path router below. New or changed hooks remain inactive until reviewed and trusted with `/hooks`.
- Windows limitation verified on 2026-09-09: native `command_execution` did not dispatch `PreToolUse` in either Codex CLI 0.153.0 or an ephemeral 0.153.4 run, even with hook trust bypassed. Therefore the command-policy handler's green contract tests and `/hooks` trust are not a hard Windows shell boundary. Keep sandboxing and approvals enabled, rely on `.codex/rules` only for its exact direct prefixes, and never use nested-shell or destructive-command forms. Re-run a non-mutating runtime dispatch smoke test after a Codex update before removing this limitation.

## Codex skill argument binding
For a Codex skill containing `$ARGUMENTS`, derive its value from the triggering user message: find the active `$speckit-*` invocation and bind the exact remainder after the skill name, preserving quotes and flags exactly. If there is no remainder, bind an empty string. The literal token is never input and MUST NOT be forwarded to a script or child skill.

Nested Spec Kit hooks follow the same binding rule: explicit child arguments win; otherwise the child inherits the parent workflow's bound arguments. In particular, a `before_specify` call from `$speckit-specify` to `$speckit-git-feature` inherits the feature description and flags from the parent workflow when the hook supplies none.

When `.specify/extensions.yml` names a dotted command such as `speckit.foo`, replace dots with hyphens and map it to `$speckit-foo` (generally `$speckit-<name>`). Read the corresponding `.agents/skills/speckit-foo/SKILL.md` completely and execute it in the same turn. Merely displaying an invocation is not execution. `/{command}`, a bare `EXECUTE_COMMAND:` placeholder, and `/skill:` are legacy renderer forms and MUST NOT be executed.

## Path-scoped rule routing
Codex does not interpret the `paths:` YAML in `.claude/rules/*.md`. Codex MUST, before editing a path, read every matching rule file below completely and apply all of them. For a test file, also read every rule matching the production path or contract that the test exercises, even when the test path itself does not match a listed glob.

| Canonical rule | Matching paths |
|---|---|
| `.claude/rules/content.md` | `content/**` |
| `.claude/rules/django-pod.md` | `apps/*/pyproject.toml`, `apps/*/*.py`, `apps/*/**/*.py`, `apps/*/Dockerfile`, `packages/django-common/**`, `templates/django-pod/**` |
| `.claude/rules/docs.md` | `docs/**` |
| `.claude/rules/events.md` | `packages/events/**` |
| `.claude/rules/fastapi-pod.md` | `templates/fastapi-pod/**`, `packages/fastapi-common/**` |
| `.claude/rules/infra.md` | `infra/**`, `scripts/**` |
| `.claude/rules/specs.md` | `specs/**` |
| `.claude/rules/web.md` | `apps/web/**`, `packages/content/**` |

## Commands
| Purpose | Command |
|---|---|
| Allocate a feature directory (brainstorming path) | `pwsh .specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` |
| Feature paths / prerequisites | `pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json` |
| Claude hook unit tests | `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1` |
| Codex hook unit tests | `pwsh -NoProfile -File tests/hooks/run-codex-hook-tests.ps1` |
| Codex destructive-command handler contract | `pwsh -NoProfile -File tests/hooks/run-codex-command-policy-tests.ps1` |
| Codex adapter parity | `pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1` |
| All repository checks | `pwsh -NoProfile -File tests/run-all.ps1` |
| Regenerate `specs/README.md` | `pwsh -NoProfile -File scripts/update-specs-index.ps1` — if run-all `scripts`/`specs-index-fresh` fails: run it, then commit `specs/README.md`; on `error: <dir>/spec.md: …`: fix that spec header and rerun |
| Spec Kit CLI (init / upgrade / extensions) | `specify` from `~/.local/bin` (install via `uv`); procedure in `docs/runbooks/spec-kit-upgrade.md` |

## Layout
```
.specify/        Spec Kit runtime: memory/constitution.md, templates/ (+overrides/), scripts/powershell/, extensions/, feature.json (local only)
.agents/         Codex repository skills (Spec Kit + project gates)
.claude/         Claude layer: settings.json, skills/, agents/tester.md, rules/, hooks/
.codex/          Codex adapter: hooks.json, hooks/, agents/*.toml, rules/*.rules (command policy only)
apps/            application code: web (Next.js) + one directory per Django pod
packages/        shared JS/Py packages: events (schemas), django-common, content
templates/       copier pod templates (django-pod)
infra/           OpenTofu modules (oci, cloudflare, vault, grafana) + bootstrap scripts
e2e/             cross-app end-to-end tests
specs/           one immutable directory per feature (NNN-slug) + README.md index
docs/            README.md index, decisions/ (MADR), runbooks/, kr/ (Korean mirrors)
content/study/   learning notes (.mdx) consumed by the site
content/tmp/     per-task learning logs (staging for notes; never published, deleted once distilled)
tests/           hook tests and repository checks
```

## Conventions
- Branch = feature directory name (`NNN-slug`), created by the Spec Kit git extension; `main` is integration only; worktrees under `.worktrees/`.
- Commits: Conventional Commits, Korean description allowed (`feat(scope): 설명`); one commit per task; never force-push or rewrite shared history.
- Files: UTF-8, LF, ASCII kebab-case names. Korean prose in specs, docs, and notes; English in agent files and code identifiers.
- Tests first (constitution II). Test files live under `tests/`, `e2e/`, `__tests__/`, or are named `*.test.*` / `*.spec.*`.
- Secrets never enter the repository.
- Learning logs: when a task closes (and at the end of each session of a multi-day task), append the day's entry to `content/tmp/<NNN>-t<NNN>/<YYYY-MM-DD>.md` per `.claude/rules/content.md`; task-level design documents are preserved under `specs/<feature>/design/`.

## Workflow (short form)
specify → clarify → plan → checklist → tasks → approval-review → build (TDD, subagent-driven) → converge → E2E (tester) → finish → finishing branch → merge → archive. Details: `CLAUDE.md` and the constitution.

Spec Kit owns WHAT: the constitution, feature specifications, plans, tasks, analysis, convergence, and archive. The active agent workflow owns HOW: TDD, scoped subagents, review, verification, worktrees, and branch finishing. Project-owned approval, E2E, finish, command-policy, and write-scope gates enforce the boundary where the runtime dispatches them; the documented Windows shell limitation applies. Do not use `$speckit-implement`; execute approved `tasks.md` through the TDD/subagent workflow. Do not use `superpowers:writing-plans`; `tasks.md` is the sole implementation plan. Approved `spec.md`, `plan.md`, and `tasks.md` remain immutable inputs.
