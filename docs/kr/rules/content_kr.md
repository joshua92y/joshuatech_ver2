> 번역본(편의용). 정본은 영어 원본 `.claude/rules/content.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "content/**"
```

# Rules for `content/`

`content/study/*.mdx`는 사이트가 소비하는(SP-1부터) 공개 학습 노트다. 계약:

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

- 파일명 = `<NNN-slug>.mdx` (ASCII kebab-case). 기능당 노트 하나; 같은 기능에 대한 두 번째 노트는 사람에게 먼저 물어본 뒤에만 `-2` 접미사를 붙인다.
- 본문 섹션은 이 순서대로 둔다: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. 각 섹션은 비어 있으면 안 된다.
- 세션에 없었던 독자를 위해 작성한다: 개념이 무엇인지, 왜 여기서 중요했는지, 무엇을 기각했고 왜인지 서술한다.
- 비밀 값, 토큰, 내부 호스트명, 개인 정보는 절대 포함하지 않는다.
