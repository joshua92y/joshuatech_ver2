<!--
SYNC IMPACT REPORT
Version change: (template) -> 1.0.0 (initial ratification, 2026-08-26)
Added principles: I. Spec-First; II. Test-First (NON-NEGOTIABLE); III. Tenant Boundary; IV. Observability-Ready; V. Simplicity; VI. Learning-in-Public
Added sections: Platform Constraints; Development Workflow & Quality Gates; Governance
Templates: .specify/templates/overrides/tasks-template.md enforces II (tests mandatory, E2E per story); plan/spec templates unchanged (Constitution Check reads this file at runtime)
Follow-ups: none
-->
> Canonical language: English. Korean mirror: docs/kr/constitution_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# JoshuaTech v2 Constitution

## Core Principles

### I. Spec-First
Every change larger than a typo starts as a feature under `specs/NNN-slug/` with a `spec.md` (user stories, functional requirements, success criteria) before any code. The spec is the authority the plan and tasks argue from; code that contradicts an approved spec is a defect, not a design decision. Feature directories are immutable history: a change of intended behavior is a new feature directory, never a silent edit of a completed one.

### II. Test-First (NON-NEGOTIABLE)
No production code without a failing test first. Every user story phase in `tasks.md` MUST contain test tasks that are written and observed failing before implementation tasks, plus one end-to-end scenario executed by the `tester` agent from the user's point of view. Any template wording that makes tests optional is overridden by this article.

### III. Tenant Boundary
The product is designed as a multi-tenant SaaS even while it serves a single tenant. Every data-owning entity MUST name its owner and its isolation key (or state why it is global) in the spec's Key Entities; every service boundary MUST state what data it owns and what it merely references. Cross-boundary access goes through explicit contracts (APIs, events), never shared tables or implicit joins.

### IV. Observability-Ready
Each plan MUST state how the feature is observed in production — structured logs with a correlation id, the metrics that indicate health — and its rollback path. A feature without a rollback path is not ready to ship.

### V. Simplicity
Build the smallest thing that satisfies the spec (YAGNI). New frameworks, extensions, or abstractions require a documented reason in `plan.md` Complexity Tracking or an ADR under `docs/decisions/`. Prefer deleting over adding.

### VI. Learning-in-Public
Every completed feature produces a learning note in `content/study/NNN-slug.mdx` (the problem, what was learned, which alternatives were rejected and why, how it was verified, what to learn next). The note is a first-class deliverable checked by the finish gate, and the site publishes it.

## Platform Constraints
- The stack is undecided until SP-1; this constitution is stack-neutral and applies to tooling, documents, and future code alike.
- Secrets never enter the repository; configuration comes from the environment or a secret manager.
- Destructive operations (history rewrites, force pushes, data deletion, infrastructure teardown) require explicit human approval.

## Development Workflow & Quality Gates
1. Intake: `/speckit-specify` (superpowers brainstorming for architecture-level work), then `/speckit-clarify` when ambiguous.
2. Plan: `/speckit-plan` (Constitution Check gate) → `/speckit-checklist` → `/speckit-tasks`.
3. Approval: `/approval-review` runs per-boundary reviews (security, tenant/data, operability, trends, spec consistency) and records `reviews/*-approval.md`; the spec Status becomes Approved only after the human confirms.
4. Build: superpowers subagent-driven-development executes `tasks.md` with TDD and per-task review; `/speckit-implement` is not used.
5. Converge: `/speckit-converge` until Converged.
6. Verify: the `tester` agent executes every user story end-to-end.
7. Finish: `/finish` writes `report.md`, the learning note, the CHANGELOG entry, and `reviews/*-finish.md`; the finish gate blocks `finishing-a-development-branch` until that review is Approved.
8. Integrate: merge, then archive the feature into `.specify/memory/` so the current state of the system stays readable.

## Governance
This constitution supersedes all other practices in this repository. Amendments go through `/speckit-constitution`, bump the version (MAJOR: principle removed or redefined incompatibly; MINOR: principle or section added; PATCH: wording), and record a Sync Impact Report. Every plan's Constitution Check and every approval/finish review verifies compliance; violations are justified in Complexity Tracking or rejected. Agent operating mechanics live in `CLAUDE.md` and `AGENTS.md`; durable decisions live in `docs/decisions/`.

**Version**: 1.0.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-08-26
