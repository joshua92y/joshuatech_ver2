---
paths:
  - "content/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/content_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `content/`

`content/study/*.mdx` are learning-in-public notes consumed by the site (SP-1 onward). Contract:

```yaml
---
title: "..."                        # required; Korean allowed
description: "..."                  # required; one sentence
pubDate: 2026-08-26                 # required; ISO date
updatedDate: 2026-08-27             # optional
tags: ["claude-code", "spec-kit"]   # required; may be empty
series: "sp-0-claude-setup"         # optional
seriesOrder: 1                      # optional integer
draft: true                         # required; generated notes start true, a human flips it to false
change: "001-claude-setup"          # required; the feature directory name
sources:                            # required; may be empty; path = repo path or url
  - { title: "spec", path: "specs/001-claude-setup/spec.md" }
---
```

- File name = `<NNN-slug>.mdx` (ASCII kebab-case). One note per feature; a second note for the same feature gets a `-2` suffix only after asking the human.
- Body sections, in this order: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. Each must be non-empty.
- Write for a reader who was not in the session: state the concept, why it mattered here, what was rejected and why.
- Never include secrets, tokens, internal hostnames, or personal data.

## `content/tmp/` — learning-log staging (never published)

`content/tmp/<NNN>-t<NNN>/<YYYY-MM-DD>.md` holds per-task learning logs that `/finish` later distills into the feature's note. The site never loads `content/tmp/**`.

- One directory per task (`003-t044` = feature 003, task T044; lowercase ASCII). One file per working day, so a multi-day task gets several files. Plain Markdown, no frontmatter; the first line is `# <NNN-slug> T<NNN> — <one-line title> (<YYYY-MM-DD>)`.
- The controller appends the day's entry when it ticks the task checkbox, and at the end of each session of a multi-day task. Entry sections mirror the note, in this order: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`, then `## 사고·오류` (only when something went wrong) and `## 출처` (commit hashes, PR numbers, runbook anchors, `specs/<feature>/design/` files).
- Same publication bar as notes: never include secrets, tokens, internal hostnames or IP addresses, resource identifiers, or personal data. This repository is public — write every entry as if it were already published.
- Lifecycle: `/finish` reads `content/tmp/<NNN>-*/` as a source of substance. After the finish review's Study contract boundary is ✅, the consumed directories are deleted in the same commit as the note; git history keeps them. An empty `content/tmp/` means everything has been distilled.
