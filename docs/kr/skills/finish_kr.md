> 번역본(편의용). 정본은 영어 원본 `.claude/skills/finish/SKILL.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
---
name: finish
description: "Close the active feature: write report.md, draft the learning note, update CHANGELOG, sync Korean mirrors, and run parallel per-boundary finish reviews so the finish-gate hook lets finishing-a-development-branch proceed. Use when implementation, converge, and E2E are done, or when the finish gate denies finishing."
---
```

# finish

`/speckit-converge`가 Converged를 보고하고 tester가 PASS(또는 사유가 기록된 SKIP)를 보고한 뒤에 실행합니다. `finish-gate` 훅이 확인하는 산출물을 생성합니다: `report.md`, `content/study/<feature>.mdx`, 그리고 2번째 줄이 정확히 `Status: Approved`인 가장 최신 `reviews/YYYY-MM-DD-finish.md`.

## 0. Resolve the feature and preconditions
approval-review와 동일한 방식으로 기능을 식별합니다(env → 브랜치 → feature.json 순; 식별 불가하거나 불일치하면 질문). `tasks.md`에 체크되지 않은 `- [ ]` 작업 줄이 없는지 확인합니다(체크리스트는 제외). 남아 있으면 중단하고 목록을 나열합니다.

## 1. `report.md`
`specs/<feature>/report.md`를 작성합니다:

```markdown
# Report <NNN-slug>
## Summary
<what was built and why — 3 to 6 lines>
## Changes Made
<one line per file from `git diff --stat $(git merge-base main HEAD)...HEAD`>
## Validation
<test commands and results; converge result; tester report summary (PASS/FAIL/SKIP counts); anything not run and why>
## Next
<follow-ups, deferred items, risks>
```

## 2. Learning note draft
`.claude/rules/content.md`를 따라 `content/study/<NNN-slug>.mdx`를 작성합니다: `draft: true`, `change: "<NNN-slug>"`, spec·plan·report·관련 decision을 나열하는 `sources`를 포함한 완전한 frontmatter; 그리고 5개 섹션 `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. 실질적인 출처: spec의 결정 표, plan의 Complexity Tracking, approval review의 findings, report. 노트가 이미 존재하면 `-2` 파일을 만들기 전에 먼저 확인을 구합니다.

## 3. CHANGELOG
`CHANGELOG.md`의 `## [Unreleased]` 아래, 사용자에게 보이는 변경마다 알맞은 카테고리(Added/Changed/Fixed/Removed)에 한 줄씩 추가하고 각 줄에 `specs/<NNN-slug>/`를 링크합니다.

## 4. Decisions
기능이 지속적인 결정(프레임워크, 경계, 데이터 소유권, 프로토콜, 컨벤션)을 내렸다면 `docs/decisions/NNNN-<title>.md`(MADR minimal, `status: proposed`)를 작성합니다 — adrkit draft 명령이 설치되어 있으면 그것을 사용하고, 아니면 수동으로 작성한 뒤 report에서 링크합니다. 그렇지 않으면 report의 Summary에 "no durable decision"이라고 적습니다.

## 5. Korean mirrors (best-effort, never blocking)
이 기능에서 변경된 각 에이전트 파일(`CLAUDE.md`, `AGENTS.md`, `.specify/memory/constitution.md`, `.claude/rules/*`, `.claude/agents/*`, `.claude/skills/*/SKILL.md`)마다 그 `docs/kr/` 미러를 갱신합니다. 컨텍스트나 시간이 부족하면 오래된 미러 앞에 `> translation-pending (YYYY-MM-DD)`를 붙이는 것으로 대신하고 report에 언급합니다.

## 6. Finish review — one subagent per boundary, in parallel
`boundaries/`의 경계: `report-vs-diff.md`, `e2e-evidence.md`, `study-contract.md`, `decisions.md`. 각 경계 파일과 그 파일이 명시한 입력만을 함께 넘겨 `general-purpose` 서브에이전트를 하나씩 배정합니다. `specs/<feature>/reviews/YYYY-MM-DD-finish.md`를 작성합니다:

```markdown
# Finish review — <NNN-slug> (YYYY-MM-DD)
Status: Approved | Issues

## Report vs diff
…
## E2E evidence
…
## Study contract
…
## Decisions
…

## Issues
1. … (empty section when Approved)
```
2번째 줄은 정확히 `Status: Approved` 또는 `Status: Issues`여야 합니다(finish-gate 훅이 가장 최신 `*-finish.md`와 그 첫 Status 줄을 읽습니다). 모든 경계가 ✅를 보고할 때만 `Status: Approved`입니다. Issues인 경우: 문제를 고치고(report, note, changelog, tests), Approved가 될 때까지 6단계를 다시 실행합니다.

## 7. Hand off
`specs/README.md`를 재생성합니다(archive 전까지 Status는 Approved로 유지). `docs(<NNN-slug>): report·학습 노트·finish 리뷰`로 커밋합니다. 사용자에게 알립니다: "finish complete — run superpowers:finishing-a-development-branch from the feature branch (the gate resolves the feature from the branch name); after the merge run the archive skill" 그리고 `.claude/skills/speckit-archive*` 아래에 나열된 archive 스킬의 정확한 이름을 알려줍니다.

## Boundaries (요약)
- **report-vs-diff**: `report.md`가 실제 변경 사항과 정확히 일치하는지 확인합니다. diff stat의 모든 파일이 Changes Made에 나열되어야 하고, 검증 주장(명령·결과)이 실제 실행 내용과 일치해야 하며, Next는 미완료 converge 항목과 지연된 작업을 모두 나열하고, 커밋은 Conventional Commits를 따라야 합니다.
- **e2e-evidence**: 모든 User Story가 엔드투엔드로 검증되고 그 증거가 존재하는지 확인합니다. 모든 스토리가 PASS이거나 사유가 명시된 SKIP이어야 하고(해결되지 않은 FAIL 없음), "Tests written"에 명시된 테스트 파일이 실제로 존재하고 통과해야 하며, 예외 경로도 검증되어야 합니다.
- **study-contract**: 학습 노트가 `.claude/rules/content.md`를 따르고 게시할 가치가 있는지 확인합니다. frontmatter의 모든 필수 필드가 유효해야 하고(`draft: true`, `change`가 기능 디렉터리 이름과 일치, `sources` 비어있지 않음), 5개 섹션이 순서대로 존재하고 비어있지 않아야 하며, 한국어 산문·ASCII 파일명·비밀정보 없음을 확인합니다.
- **decisions**: 지속적인 결정이 기록되고 요청되지 않은 변경이 정당화되었는지 확인합니다. 프레임워크·경계·데이터 소유권·프로토콜·컨벤션 도입 시 ADR이 존재하고 report에서 링크되어야 하며, 헌법 개정은 constitution 명령을 거쳐 버전이 올라가야 하고, converge의 `unrequested` 항목은 제거되거나 report에서 정당화되어야 하며, 승인된 ADR과 모순되는 내용이 없어야 합니다.
