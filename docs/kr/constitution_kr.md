> 번역본(편의용). 정본은 영어 원본 `.specify/memory/constitution.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

# JoshuaTech v2 Constitution

## Core Principles

### I. Spec-First
오타 수준을 넘는 모든 변경은 코드 작성에 앞서 `specs/NNN-slug/` 아래의 기능(feature)으로 시작하며, `spec.md`(사용자 스토리, 기능 요구사항, 성공 기준)를 먼저 작성한다. 스펙은 계획(plan)과 작업(tasks)이 근거로 삼는 권위이며, 승인된 스펙과 모순되는 코드는 설계상의 결정이 아니라 결함이다. 기능 디렉터리는 불변의 이력이다: 의도된 동작의 변경은 새로운 기능 디렉터리로 이루어지며, 완료된 디렉터리를 조용히 수정하는 일은 결코 없다.

### II. Test-First (NON-NEGOTIABLE)
실패하는 테스트를 먼저 작성하지 않고는 프로덕션 코드를 작성하지 않는다. `tasks.md`의 모든 사용자 스토리 단계는 구현 작업 이전에 작성되어 실패가 확인된 테스트 작업을 반드시 포함해야 하며, 여기에 더해 `tester` 에이전트가 사용자 관점에서 실행하는 엔드투엔드 시나리오 하나를 포함해야 한다. 테스트를 선택 사항으로 만드는 템플릿 문구는 이 조항에 의해 무효화된다.

### III. Tenant Boundary
이 제품은 단일 테넌트만을 서비스하는 동안에도 멀티 테넌트 SaaS로 설계된다. 데이터를 소유하는 모든 엔티티는 스펙의 핵심 엔티티(Key Entities)에서 소유자와 격리 키를 명시해야 하며(전역 데이터라면 그 이유를 명시해야 하며), 모든 서비스 경계는 자신이 소유하는 데이터와 단지 참조만 하는 데이터를 명시해야 한다. 경계를 넘나드는 접근은 명시적 계약(API, 이벤트)을 통해서만 이루어지며, 공유 테이블이나 암묵적 조인은 사용하지 않는다.

### IV. Observability-Ready
모든 계획(plan)은 해당 기능이 프로덕션에서 어떻게 관측되는지 — 상관관계 ID(correlation id)를 포함한 구조화된 로그, 정상 여부를 나타내는 지표 — 그리고 롤백 경로를 명시해야 한다. 롤백 경로가 없는 기능은 출시할 준비가 되지 않은 것이다.

### V. Simplicity
스펙을 충족하는 가장 작은 것을 만든다(YAGNI). 새로운 프레임워크, 확장, 또는 추상화를 도입하려면 `plan.md`의 Complexity Tracking 또는 `docs/decisions/` 아래의 ADR에 문서화된 근거가 필요하다. 추가하기보다 삭제하기를 우선한다.

### VI. Learning-in-Public
완료된 모든 기능은 `content/study/NNN-slug.mdx`에 학습 노트를 산출한다(문제, 무엇을 배웠는지, 어떤 대안을 왜 기각했는지, 어떻게 검증했는지, 다음에 배울 것). 이 노트는 완료 게이트(finish gate)가 확인하는 1급 산출물이며, 사이트에 게시된다.

## Platform Constraints
- 스택은 SP-1 이전까지 미정이다; 이 헌법은 스택에 중립적이며 도구, 문서, 그리고 향후 작성될 코드에 동일하게 적용된다.
- 비밀 정보(secrets)는 저장소에 절대 포함되지 않는다; 설정 값은 환경 변수 또는 시크릿 매니저로부터 가져온다.
- 파괴적 작업(히스토리 재작성, 강제 푸시, 데이터 삭제, 인프라 해체)은 사람의 명시적 승인을 필요로 한다.

## Development Workflow & Quality Gates
1. 착수(Intake): `/speckit-specify`(아키텍처 수준 작업에는 superpowers brainstorming을 사용), 이후 모호한 부분이 있으면 `/speckit-clarify`.
2. 계획(Plan): `/speckit-plan`(Constitution Check 게이트) → `/speckit-checklist` → `/speckit-tasks`.
3. 승인(Approval): `/approval-review`는 경계별 검토(보안, 테넌트/데이터, 운영성, 트렌드, 스펙 일관성)를 수행하고 `reviews/*-approval.md`에 기록한다; 스펙의 Status는 사람이 확인한 뒤에만 Approved가 된다.
4. 빌드(Build): superpowers subagent-driven-development가 TDD와 작업별 리뷰를 적용하여 `tasks.md`를 실행한다; `/speckit-implement`는 사용하지 않는다.
5. 수렴(Converge): Converged 상태가 될 때까지 `/speckit-converge`를 반복한다.
6. 검증(Verify): `tester` 에이전트가 모든 사용자 스토리를 엔드투엔드로 실행한다.
7. 완료(Finish): `/finish`는 `report.md`, 학습 노트, CHANGELOG 항목, `reviews/*-finish.md`를 작성한다; 완료 게이트는 해당 리뷰가 Approved 상태가 될 때까지 `finishing-a-development-branch`를 차단한다.
8. 통합(Integrate): 병합한 뒤, 시스템의 현재 상태를 계속 읽을 수 있도록 해당 기능을 `.specify/memory/`에 보관(archive)한다.

## Governance
이 헌법은 이 저장소의 다른 모든 관행에 우선한다. 개정은 `/speckit-constitution`을 통해 이루어지며, 버전을 올리고(MAJOR: 원칙의 삭제 또는 호환되지 않는 재정의; MINOR: 원칙 또는 섹션 추가; PATCH: 문구 수정), Sync Impact Report를 기록한다. 모든 plan의 Constitution Check와 모든 approval/finish 리뷰는 준수 여부를 검증한다; 위반 사항은 Complexity Tracking에서 정당화되거나 거부된다. 에이전트 운영 메커니즘은 `CLAUDE.md`와 `AGENTS.md`에 있으며, 지속적인 결정 사항은 `docs/decisions/`에 있다.

**Version**: 1.0.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-08-26
