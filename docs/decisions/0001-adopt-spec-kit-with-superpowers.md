---
status: accepted
date: 2026-08-26
decision-makers: joshua
---
# Adopt GitHub Spec Kit as the contract layer and superpowers as the execution layer

## Context and Problem Statement
AI 에이전트가 주도하는 저장소에서 "무엇을 만들지"(spec·plan·tasks)와 "어떻게 만들지"(TDD·리뷰·마감)를 담당할 도구를 정해야 한다. v1(`d:\code\joshuatech`)과 egenauto 저장소의 자체 컨벤션(Planner/Builder/Tester/Reviewer + plan/update_log)은 superpowers와 이중 구조였고, 학습·자동화·도메인 확장성이 부족했다.

## Considered Options
- A. superpowers 단독(brainstorming → writing-plans → SDD) + 얇은 프로젝트 레이어
- B. egenauto 컨벤션 상속 + 확장
- C. Spec Kit 단독(`/speckit-implement`로 실행)
- D. Spec Kit(WHAT) + superpowers(HOW) + 프로젝트 게이트

## Decision Outcome
D를 채택한다. Spec Kit(1.0.x)이 constitution·`specs/NNN-slug/`·analyze·converge·archive를 제공하고, superpowers 5.1.0이 SDD·TDD·코드 리뷰·finishing을 수행하며, 프로젝트는 tester 에이전트·approval-review/finish 스킬·결정적 훅으로 게이트를 강제한다. 완료된 feature 디렉터리는 불변 이력(Flow-Forward)이고, 머지 후 archive 확장이 `.specify/memory/`에 현재 상태를 통합한다. 활성 feature는 `SPECIFY_FEATURE_DIRECTORY` → 브랜치명 `NNN-slug` 순으로 해석하며 `.specify/feature.json`은 일치 검사에만 쓴다(정본 = git 브랜치 + `specs/<feature>/`). 근거: `specs/001-claude-setup/spec.md` 결정표 D1–D16과 `research/`.

### Consequences
- 좋음: 표준 산출물·업그레이드 경로·검증된 실행 루프를 동시에 얻는다; converge가 spec 준수를 기계적으로 점검한다.
- 나쁨: 두 도구의 경계 규칙(CLAUDE.md)을 유지해야 하고, Spec Kit 명령 프롬프트가 커서 명시 호출로 제한해야 한다; 커뮤니티 확장은 서드파티 신뢰 검토와 버전 호환 확인이 필요하다(adrkit은 버전 게이트로 보류).
