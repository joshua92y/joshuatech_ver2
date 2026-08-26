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
