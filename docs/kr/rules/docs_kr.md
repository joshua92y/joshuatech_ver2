> 번역본(편의용). 정본은 영어 원본 `.claude/rules/docs.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "docs/**"
```

# `docs/` 규칙

- `docs/README.md`는 문서 색인이다; 새 문서는 모두 여기에 추가한다.
- `docs/decisions/NNNN-<kebab-title>.md`는 MADR 4.0 minimal 형식을 따른다:
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
  번호는 절대 재사용하지 않는다. 결정이 바뀌면 이전 결정을 대체하는 새 ADR을 만든다; 이전 본문은 `status`를 제외하고는 절대 수정하지 않는다.
- `docs/kr/`는 에이전트 파일을 미러링한다: 동일한 상대 경로에 `_kr`을 붙인다 (`docs/kr/CLAUDE_kr.md`, `docs/kr/AGENTS_kr.md`, `docs/kr/constitution_kr.md`, `docs/kr/agents/tester_kr.md`, `docs/kr/skills/<skill>_kr.md`, `docs/kr/rules/<rule>_kr.md`). 미러본은 제목, 표, 코드, 식별자를 동일하게 유지하고 산문만 번역한다. 번역본은 절대 `.claude/rules/`나 `.claude/agents/` 안에 두지 않는다 (그 안의 모든 파일은 자동으로 로드된다). 오래된 미러본에는 첫 줄에 `> translation-pending (YYYY-MM-DD)` 표시를 남긴다; 오래됨이 finish를 막지는 않는다.
- `docs/runbooks/`는 운영 절차를 담는다. `docs/runbooks/spec-kit-upgrade.md`는 커스터마이징 등록부도 함께 관리한다: 커스터마이징된 Spec Kit 파일마다 한 행(원본 버전, 원본 경로, 이유, 재검증 명령).
- 산문은 한국어로; 파일명은 ASCII kebab-case로.
