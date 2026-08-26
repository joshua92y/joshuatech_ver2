---
status: accepted
date: 2026-08-26
decision-makers: joshua
---
# Use Markdown Architectural Decision Records (MADR 4.0 minimal)

## Context and Problem Statement
기술 결정의 이유가 대화 로그에만 남으면 에이전트도 사람도 나중에 결정을 쉽게 뒤집는다. 결정을 남기는 고정 형식이 필요하다.

## Considered Options
- MADR 4.0 minimal, `docs/decisions/NNNN-title.md`
- Nygard 원형 ADR, `doc/adr/`
- 각 feature의 `spec.md`에만 결정 기록

## Decision Outcome
MADR 4.0 minimal을 `docs/decisions/`에 둔다. 번호는 재사용하지 않고, 바뀐 결정은 새 ADR이 이전 ADR을 supersede한다(이전 본문은 `status`만 바꾼다). 횡단 결정에만 쓴다 — feature 국소 결정은 `spec.md`·`research.md`의 Decision/Rationale/Alternatives로 충분하다. adrkit 확장(ADR 컨텍스트 주입·plan 검토)은 spec-kit 1.0.x 호환 버전이 나오면 도입한다.

### Consequences
- 좋음: 에이전트가 계획 전에 결정을 읽는다(CLAUDE.md 포인터); 학습 노트·사이트 콘텐츠의 원천이 된다.
- 나쁨: 결정마다 문서 한 편이 필요하다 — 횡단 결정으로 범위를 제한해 부담을 줄인다.
