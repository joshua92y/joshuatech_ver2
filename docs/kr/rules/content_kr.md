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

## `content/tmp/` — learning-log staging (never published)

`content/tmp/<NNN>-t<NNN>/<YYYY-MM-DD>.md`는 task별 학습 로그를 담으며, `/finish`가 나중에 이를 기능의 노트로 증류한다. 사이트는 `content/tmp/**`를 절대 로드하지 않는다.

- task마다 디렉터리 하나(`003-t044` = 기능 003의 task T044; 소문자 ASCII). 작업일마다 파일 하나이므로 여러 날에 걸친 task는 파일이 여러 개다. frontmatter 없는 일반 Markdown이며 첫 줄은 `# <NNN-slug> T<NNN> — <one-line title> (<YYYY-MM-DD>)`.
- 컨트롤러는 task 체크박스를 찍을 때, 그리고 여러 날에 걸친 task에서는 세션이 끝날 때마다 그날의 항목을 덧붙인다. 항목의 섹션은 노트와 같은 순서다: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`, 이어서 `## 사고·오류`(문제가 있었을 때만)와 `## 출처`(커밋 해시, PR 번호, 런북 앵커, `specs/<feature>/design/` 파일).
- 노트와 같은 게시 기준을 적용한다: 비밀 값, 토큰, 내부 호스트명·IP 주소, 리소스 식별자, 개인 정보는 절대 포함하지 않는다. 이 저장소는 공개이므로 모든 항목을 이미 게시된 글처럼 쓴다.
- 수명주기: `/finish`는 `content/tmp/<NNN>-*/`를 소재로 읽는다. finish 리뷰의 Study contract 경계가 ✅가 된 뒤, 소모된 디렉터리는 노트와 같은 커밋에서 삭제한다(git 이력에는 남는다). `content/tmp/`가 비어 있으면 전부 증류된 것이다.
