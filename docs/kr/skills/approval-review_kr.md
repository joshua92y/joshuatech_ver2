> 번역본(편의용). 정본은 영어 원본 `.claude/skills/approval-review/SKILL.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
---
name: approval-review
description: "Run parallel per-boundary subagent reviews (security, tenant-data, operability, trends, spec-consistency) before a feature's spec/plan/tasks is marked Approved. Use when the user approves a feature, says 승인/approve/LGTM, or asks for a pre-approval review."
---
```

# approval-review

구현 전 게이트(gate). `specs/<feature>/reviews/YYYY-MM-DD-approval.md`를 생성하며, 사람이 확인한 뒤에만 spec의 Status를 Approved로 설정한다.

## 1. Resolve the active feature
순서: `$env:SPECIFY_FEATURE_DIRECTORY` → 현재 git 브랜치 `NNN-slug`와 `specs/<branch>/` → `.specify/feature.json`의 `feature_directory`. 어느 것도 확인되지 않거나 서로 다르면 사용자에게 어떤 기능을 검토할지 묻는다. `spec.md`, `plan.md`, `tasks.md`, 존재한다면 `checklists/*.md`를 읽는다. `plan.md`나 `tasks.md`가 없으면 중단하고 어떤 Spec Kit 명령을 실행해야 하는지 사용자에게 알린다.

## 2. Gather machine inputs
- `/speckit-analyze`를 (읽기 전용으로) 실행하고 그 보고서를 spec-consistency 리뷰어를 위해 보관한다.
- `checklists/*.md`의 미체크 `- [ ]` 항목 수를 센다.

## 3. Dispatch one reviewer per boundary — in parallel, in one message
`boundaries/` 안의 각 파일(`security.md`, `tenant-data.md`, `operability.md`, `trends.md`, `spec-consistency.md`)마다 `general-purpose` 서브에이전트를 하나씩 파견한다. 프롬프트:

```
You are the <boundary> reviewer for feature <NNN-slug>. Read-only: do not edit any file.
<full contents of boundaries/<boundary>.md>

Inputs (excerpts only, pasted below):
- spec.md: User Scenarios & Testing, Requirements, Key Entities
- plan.md: Summary, Technical Context, Constitution Check, Project Structure, Complexity Tracking
- tasks.md: phase headings and task lines
- (spec-consistency only) the /speckit-analyze report and the unchecked checklist count
- constitution: .specify/memory/constitution.md Core Principles

Return ONLY the output format defined in the boundary file.
```
`trends` 리뷰어는 WebSearch를 사용할 수 있고 반드시 URL을 인용해야 한다; 나머지 네 명은 아무것도 가져오면(fetch) 안 된다.

## 4. Write the review file
`specs/<feature>/reviews/YYYY-MM-DD-approval.md`:

```markdown
# Approval review — <NNN-slug> (YYYY-MM-DD)
Inputs: spec.md (Status: Draft), plan.md, tasks.md, checklists: <n> unchecked, /speckit-analyze: <finding count>

## Security
| 항목 | 상태 | 비고 |
|---|---|---|
### Findings

## Tenant & data boundary
…
## Operability
…
## Trends
| 기술 | 현재 plan | 최신 동향 | 제안 | 출처 |
|---|---|---|---|---|
### Findings

## Spec consistency
…

## 종합 의견
**판정**: 승인 권고 | 수정 후 승인 권고 | 재설계 권고
- 근거 (1–3 lines)
- 수정 필요 항목 (numbered, if any)

## 사용자 결정
- [ ] 승인 (YYYY-MM-DD)
```
상태 셀 값: ✅ 충족 · ⚠️ 보완 · ❌ 위반 · — 해당 없음.

## 5. Ask the human
`종합 의견`과 수정 목록을 보여준 다음, AskUserQuestion으로 승인 / 수정 후 재검토 / 재설계 선택지를 제시한다.
- 승인: 오늘 날짜로 체크박스를 표시하고, `spec.md`에 `**Status**: Approved (YYYY-MM-DD)`를 설정하고, `specs/README.md`를 재생성하고, `docs(<NNN-slug>): approval 리뷰 및 Status Approved`로 커밋한다.
- 수정 후 재검토: 수정 사항을 Spec Kit 작업(`/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`)으로 나열한 뒤, 이 스킬을 다시 실행한다.
- 재설계: 중단한다; 다음 단계는 사용자가 결정한다.

## Never
- 5단계에서 사람의 명시적 답변 없이 Approved로 설정하지 말 것.
- 리뷰어 프롬프트에 spec/plan/tasks 파일 전체를 붙여넣지 말 것; 발췌만 사용할 것(경계 파일 자체는 루브릭이므로 전문을 포함한다).
- 이 스킬에서 구현을 시작하지 말 것.

## Boundaries (요약)

### Security — 보안
목적: 코드가 존재하기 전에 설계 단계에서 보안 취약점을 찾는다.
- 인증과 인가: 누가 무엇을 호출할 수 있는지, 기본 거부(default deny), 관리자 화면 보호.
- 입력 검증과 인젝션(SQL/NoSQL/명령/템플릿) 대응; 업로드 처리; 크기 제한.
- 시크릿: 저장소·설정·로그 어디에도 없어야 하며 교체(rotation) 경로가 명시되어야 함.
- 데이터 노출: 로그·에러 본문·URL 안의 PII, 지나치게 상세한 에러 메시지.
- 전송과 저장: TLS, 민감 필드의 저장 시 암호화, 토큰 수명.
- 공급망: 새로 추가하는 의존성·확장·도구는 각각 정당화되고 버전이 고정되어야 함.
- 남용: 속도 제한, 열거(enumeration) 공격, 재전송(replay), 해당하는 경우 CSRF/SSRF.

### Tenant & data — 테넌트와 데이터 경계
목적: 단일 테넌트만 서비스하는 기능이라도 헌법 III(테넌트 경계)과 데이터 소유권을 지킨다.
- 모든 Key Entity는 소유자와 격리 키(테넌트 id 등)를 명시하거나, 전역(global)인 이유를 명시한다.
- 서비스 간 테이블 공유나 암묵적 조인 금지; 경계를 넘는 읽기는 명시적 계약(API, 이벤트)을 통해서만 이루어진다.
- 마이그레이션은 하위 호환성을 지키고, 되돌릴 수 있으며, 단일 서비스가 소유해야 한다.
- 데이터 생애주기: 보존, 삭제, 내보내기, 백업이 다루어지거나 명시적으로 범위 밖으로 표시된다.
- 어디에도 단일 테넌트를 하드코딩하지 않는다; 데이터가 존재하는 곳마다 격리(isolation) 테스트 케이스가 포함된다.

### Operability — 운영성
목적: 헌법 IV(관측 가능성 준비)와 SaaS급 운영을 지킨다.
- 로그는 구조화되어 있고 상관관계 id(correlation id)를 가지며 시크릿을 포함하지 않는다; 헬스 지표와 알림 조건이 명시된다.
- 롤백 경로가 문서화되어 있다; 해당하는 경우 기능 플래그나 되돌릴 수 있는 배포 방식을 사용한다.
- 실패 모드, 타임아웃, 재시도, 멱등성(idempotency)이 다루어진다.
- 런북 필요 여부를 식별한다(이 기능이 `docs/runbooks/` 항목을 필요로 하는가?).
- 비용과 한도: 쿼터, 무료 등급 제약, 속도 제한.

### Trends — 최신 동향
목적: 선택한 라이브러리, 도구, 패턴을 현재의 관행과 비교해 확인한다. WebSearch 사용이 허용되며 반드시 URL을 인용해야 한다.
- 지정한 각 의존성·도구의 최신 안정 버전과 지원 종료(deprecation) 여부.
- plan의 접근 방식 대비 권장 패턴; 알려진 함정(pitfall).
- 복잡도가 더 낮은 단순한 대안(헌법 V).
- 선택한 버전에 영향을 미치는 보안 권고(advisory).

### Spec consistency — 스펙 일관성
목적: spec, plan, tasks, checklists, constitution이 서로 일치하는지 확인한다.
- 모든 FR과 User Story는 최소 하나의 태스크로 커버되며, 모든 태스크는 요구사항으로 거슬러 추적된다.
- `[NEEDS CLARIFICATION]`이 남아 있지 않다; spec과 plan 사이에 모순이 없다.
- plan의 Constitution Check가 통과했거나, 위반 사항이 Complexity Tracking에서 정당화된다.
- 모든 user story phase에 먼저 작성되는 테스트 태스크와 tester를 위한 E2E 태스크 하나가 있다(헌법 II).
- `/speckit-analyze` 결과가 분류(triage)된다: CRITICAL은 승인 전 반드시 수정하고, HIGH는 목록화한다.
- 미체크 체크리스트 항목 수를 세고 차단(blocking) 여부인지 판단한다.
