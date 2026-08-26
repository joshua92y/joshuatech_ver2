---
paths:
  - "docs/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/docs_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `docs/`

- `docs/README.md` is the documentation index; add every new document to it.
- `docs/decisions/NNNN-<kebab-title>.md` follow MADR 4.0 minimal:
  ```markdown
  ---
  status: proposed | accepted | deprecated | superseded by ADR-NNNN
  date: YYYY-MM-DD
  decision-makers: joshua
  ---
  # <Title>
  ## Context and Problem Statement
  ## Considered Options
  ## Decision Outcome
  ### Consequences
  ```
  Numbers are never reused. A changed decision is a new ADR that supersedes the old one; the old body is never edited except its `status`.
- `docs/kr/` mirrors agent files: same relative path plus `_kr` (`docs/kr/CLAUDE_kr.md`, `docs/kr/AGENTS_kr.md`, `docs/kr/constitution_kr.md`, `docs/kr/agents/tester_kr.md`, `docs/kr/skills/<skill>_kr.md`, `docs/kr/rules/<rule>_kr.md`). Mirrors keep headings, tables, code, and identifiers identical and translate prose only. Never place translations inside `.claude/rules/` or `.claude/agents/` (every file there auto-loads). A stale mirror gets a first-line `> translation-pending (YYYY-MM-DD)` note; staleness never blocks a finish.
- `docs/runbooks/` hold operational procedures. `docs/runbooks/spec-kit-upgrade.md` also keeps the customization register: one row per customized Spec Kit file (origin version, origin path, reason, re-verify command).
- Prose in Korean; file names ASCII kebab-case.
