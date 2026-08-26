# Feature Specification: Claude Code 기반 셋팅 (SP-0)

**Feature Branch**: `001-claude-setup`
**Created**: 2026-08-26
**Status**: Draft
**Input**: User description: "개발 포트폴리오 사이트 v2 — 최대한 확장성 있고 대규모로 기획, 공부(학습) 개념 포함, Claude 셋팅부터 시작"

> 이 문서는 superpowers `brainstorming` 스킬로 도출한 설계 스펙이다. Spec Kit 설치 전에 작성되었으므로
> Spec Kit `spec-template.md`의 필수 절(User Scenarios & Testing / Requirements / Success Criteria)을 따르되,
> 브레인스토밍 산출인 `## Design` 절을 뒤에 덧붙인다. 002번 feature부터는 `/speckit-specify`가 생성한다.
> 조사 근거: [research/2026-08-26-research-summary.md](research/2026-08-26-research-summary.md)

---

## 배경과 결정 요약

**프로젝트**: `joshuatech_ver2` — `d:\code\joshuatech`(v1: Django Admin + FastAPI + Next.js + Worker, OCI)의 전면 재설계.
v1은 사용자 본인의 성숙도 분석(2026-08-25)에서 "기술 계층으로 쪼갠 분산 모놀리스(L2)"로 판정되었다.

**목표**: 개발 포트폴리오 사이트를 SaaS급 운영 규율(A)로 시작하되 멀티테넌트(B)를 염두에 둔 경계로 설계하고,
L5 수준 MSA를 지향하며, 학습 과정을 사이트 콘텐츠로 발행(learning in public)한다.
이 spec은 그 첫 서브 프로젝트 **SP-0: Claude Code 기반 셋팅**만 다룬다.

브레인스토밍에서 확정된 결정:

| # | 결정 | 선택 | 근거 |
|---|------|------|------|
| D1 | 컨벤션 기반 | egenauto 컨벤션 상속 대신 **처음부터 새 설계** | superpowers 통합·학습/자동화 내장·도메인 확장성 |
| D2 | 학습 형태 | **사이트 콘텐츠로 발행**(learning in public) | 학습 노트가 `content/study/*.mdx`로 남아 SP-1 사이트가 소비 |
| D3 | 스택 | **SP-0은 스택 중립**, SP-1에서 결정 | 도메인 슬롯만 남기고 스택 결정에 막히지 않음 |
| D4 | 규모 | 플랫폼·운영 중심, **SaaS급 운영(A)로 시작 + 멀티테넌트(B) 염두 설계** | 결제·요금제는 로드맵만 |
| D5 | 접근 | **superpowers 중심 + 약점 보완**(속도 우선) | E2E Tester·거버넌스 훅·최소 권한만 추가 |
| D6 | 문서 정책 | **GitHub Spec Kit 기반**(모드 A: 척추=Spec Kit, 실행=superpowers) | 2026 커뮤니티 합의 "Spec Kit이 WHAT, superpowers가 HOW" |
| D7 | 사후 모델 | **Flow-Forward + `archive` 확장** | `specs/NNN-slug/` 불변 이력 + `.specify/memory/` 통합본 |
| D8 | superpowers 버전 | **`superpowers-dev` 5.1.0 단독**(official 6.3.0 비활성화) | 중복 활성화 해소; Spec 링크·E2E 요구는 CLAUDE.md 규칙으로 보완 |
| D9 | 언어 | **에이전트 파일 영어, 나머지 한국어, 에이전트 파일 한국어 미러 `docs/kr/*_kr.md`** | `.claude/rules/`·`.claude/agents/` 안의 모든 .md는 자동 로드되므로 미러는 그 밖에 둔다 |
| D10 | Tester | **테스트 코드 작성 가능(Edit/Write), 테스트 경로만 허용** | 에이전트 훅으로 경로 가드 강제 |
| D11 | 훅 | **훅은 트리거·게이트만, 판단은 경계별 서브에이전트 리뷰** | approval-review / finish 스킬이 서브에이전트를 병렬 디스패치 |
| D12 | 활성 feature 해석 | **env → 브랜치명↔디렉터리 → feature.json 순, 실패·불일치 시 fail-closed** | 외부 리뷰(2026-08-26) 반영 — feature.json은 gitignored·체크아웃별이라 worktree에 없음 |
| D13 | 생성 스킬 통제 | **`settings.json` `skillOverrides`로 명시 호출 전용화**(SKILL.md 무수정) | Spec Kit 업그레이드 내구성 |
| D14 | 확장 범위 | **5종 모두 SP-0**(git·agent-context·selftest·archive·adrkit) — 외부 리뷰의 축소안 불채택 | 사용자 결정; 서드파티 2종은 아카이브 URL 검토 후 설치 |
| D15 | 승인 훅 | **넓은 키워드 유지** — 명시 명령 전환 불채택 | 사용자 결정; 훅은 지시 주입만 하므로 오탐 비용 낮음 |
| D16 | 원격·CI·병렬 에이전트 | **GitHub 원격은 SP-0, 최소 CI·Orca 병렬 규칙은 SP-1 이후** | 사용자 결정 |

---

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 표준 feature 사이클 완주 (Priority: P1)

개발자(1인)가 새 기능을 `/speckit-specify`로 시작해 spec → plan → tasks → 승인 → 구현 → 수렴 → E2E → 마감 → 통합 → archive까지
한 번의 흐름으로 끝내고, 모든 산출물이 `specs/NNN-slug/`에 남는다.

**Why this priority**: 모든 후속 SP가 이 사이클 위에서 진행된다. 이것이 동작하지 않으면 셋팅은 무의미하다.

**Independent Test**: `002-smoke`(예: `specs/README.md` 인덱스 재생성 스크립트 같은 1~2 task짜리 작업)로 전체 흐름을 1회 실주행하고 산출물 존재를 확인한다.

**Acceptance Scenarios**:

1. **Given** Spec Kit·확장·프로젝트 레이어가 설치된 저장소, **When** `/speckit-specify "..."`를 실행, **Then** `specs/002-smoke/spec.md`가 템플릿 형식으로 생성되고 git 확장이 `002-smoke` 브랜치를 만들며 `.specify/feature.json`이 이를 가리킨다.
2. **Given** spec, **When** `/speckit-plan` → `/speckit-tasks`, **Then** `plan.md`(Constitution Check 통과)·`tasks.md`(`T001 [P] [US1]` 형식, 테스트 task 포함)가 생성되고 CLAUDE.md의 SPECKIT 블록이 plan 경로를 가리킨다.
3. **Given** 승인된 tasks, **When** superpowers `subagent-driven-development`로 실행, **Then** task마다 implementer→spec-reviewer→quality-reviewer가 돌고 커밋되며 `tasks.md`의 해당 항목이 `[X]`가 된다.
4. **Given** 구현 완료, **When** `/speckit-converge`, **Then** 갭이 없으면 "✅ Converged", 있으면 `## Phase N: Convergence` task가 추가된다.
5. **Given** 수렴 완료, **When** Tester 디스패치 → `/finish` → `finishing-a-development-branch` → 머지 → `/speckit-archive`, **Then** `reviews/*-finish.md`(Approved)·`report.md`·`content/study/002-smoke.mdx`·`CHANGELOG.md` Unreleased 항목이 존재하고 `.specify/memory/spec.md`에 통합된다.

---

### User Story 2 - 승인 전 경계별 리뷰 (Priority: P1)

개발자가 "승인"이라고 말하면 시스템이 승인 처리 전에 보안·테넌트/데이터 경계·운영성·최신 트렌드·spec 정합성 리뷰를 **각각 별도 서브에이전트**로 병렬 수행하고 종합 결과를 보여준다.

**Why this priority**: SaaS급/L5 지향의 품질 게이트. 사용자가 명시적으로 "경계별 서브에이전트 리뷰" 방식을 요구했다.

**Independent Test**: 승인 키워드가 포함된 프롬프트를 훅에 흘려 지시가 주입되는지, `/approval-review` 실행 시 `reviews/YYYY-MM-DD-approval.md`가 경계 5개 절과 종합 판정으로 생성되는지 확인.

**Acceptance Scenarios**:

1. **Given** 활성 feature와 plan/tasks, **When** 사용자가 "승인해줘"라고 입력, **Then** `approval-review` 훅이 `/approval-review` 실행 지시를 systemMessage로 주입한다.
2. **Given** `/approval-review` 실행, **When** 경계별 서브에이전트 5개가 병렬로 끝남, **Then** `reviews/YYYY-MM-DD-approval.md`에 경계별 표(항목/상태/비고)와 종합 의견(승인 권고 / 수정 후 승인 / 재설계)이 기록되고 사용자에게 확정을 묻는다.
3. **Given** 사용자 확정, **When** 승인 처리, **Then** `spec.md`의 `**Status**`가 `Approved`로 바뀐다.
4. **Given** 승인 키워드가 없는 일반 프롬프트, **When** 훅 실행, **Then** 아무것도 주입하지 않는다(exit 0, 출력 없음).

---

### User Story 3 - 마감 게이트 (Priority: P1)

마감 산출물(finish 리뷰 Approved, `report.md`, 학습 노트)이 없으면 `finishing-a-development-branch`가 차단되고, `/finish`를 실행하라는 안내를 받는다.

**Why this priority**: "update_log 없이는 완료가 아니다"라는 기존 거버넌스를 결정적으로 강제하는 유일한 지점.

**Independent Test**: 산출물이 없는 상태에서 finishing 스킬 호출을 시뮬레이션한 JSON을 훅에 넣어 deny가 나오고, 산출물을 만든 뒤 allow가 나오는지 확인.

**Acceptance Scenarios**:

1. **Given** `.specify/feature.json`이 `specs/002-smoke`를 가리키고 `reviews/*-finish.md`가 없음, **When** `Skill(superpowers:finishing-a-development-branch)` 호출, **Then** 훅이 `permissionDecision: deny`와 "`/finish`를 먼저 실행" 메시지를 반환한다.
2. **Given** `/finish`가 완료되어 `reviews/YYYY-MM-DD-finish.md`에 `Status: Approved`, `report.md`, `content/study/002-smoke.mdx`가 존재, **When** 같은 호출, **Then** 통과한다.
3. **Given** `.specify/feature.json`이 없지만 현재 브랜치가 `002-smoke`, **When** 같은 호출, **Then** 브랜치명으로 `specs/002-smoke/`를 해석해 같은 검사를 수행한다.
4. **Given** env·브랜치·feature.json 어느 것으로도 feature를 해석할 수 없거나, 브랜치명과 feature.json이 서로 다른 디렉터리를 가리킴, **When** 같은 호출, **Then** `permissionDecision: deny`와 사유(해석 실패 또는 불일치)를 반환한다(fail-closed).

---

### User Story 4 - Tester의 테스트 코드 작성과 경로 가드 (Priority: P2)

Tester 에이전트는 User Story별 E2E를 실제 사용자 관점으로 실행하고, 필요한 테스트 코드는 작성할 수 있지만 프로덕션 코드는 수정할 수 없다.

**Why this priority**: 사용자가 Tester에 Edit/Write를 허용하되 테스트 파일로 한정하도록 요구했다.

**Independent Test**: tester 컨텍스트에서 `tests/e2e/x.test.ts` 쓰기는 allow, `src/app.ts` 쓰기는 deny가 나오는지 훅 입력으로 확인.

**Acceptance Scenarios**:

1. **Given** Tester가 디스패치됨, **When** `tests/**`, `e2e/**`, `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**` 경로에 Edit/Write, **Then** 허용된다.
2. **Given** 같은 상황, **When** 그 외 경로에 Edit/Write, **Then** deny되고 사유가 표시된다.
3. **Given** E2E 실행 환경이 없음, **When** Tester가 시나리오를 실행하려 함, **Then** FAIL이 아니라 SKIP과 사유를 보고한다.
4. **Given** FAIL 보고, **When** 컨트롤러가 처리, **Then** 해당 task를 SDD 루프(또는 Tier 2의 `bug` 확장)로 되돌린다.

---

### User Story 5 - 학습 노트 초안 생성 (Priority: P2)

`/finish`가 해당 feature의 spec/plan/report/리뷰를 바탕으로 학습 노트 초안을 콘텐츠 계약(frontmatter)에 맞게 `content/study/NNN-slug.mdx`로 생성한다.

**Why this priority**: learning in public 파이프라인의 출발점. 사이트(SP-1)가 이 계약을 그대로 소비한다.

**Independent Test**: 생성된 파일의 frontmatter가 계약 필드를 모두 갖고 `draft: true`인지, 본문이 필수 절(문제/배운 개념/선택과 대안/결과·검증/다음 학습)을 갖는지 확인.

**Acceptance Scenarios**:

1. **Given** report.md가 있음, **When** `/finish` 2단계 실행, **Then** `content/study/NNN-slug.mdx`가 frontmatter(`title, description, pubDate, tags, series, seriesOrder, draft: true, change, sources`)와 5개 절을 갖고 생성된다.
2. **Given** 같은 slug의 노트가 이미 존재, **When** 재실행, **Then** 덮어쓰지 않고 사용자에게 갱신 여부를 묻는다.

---

### User Story 6 - 한국어 미러 동기화 (Priority: P3)

프로젝트가 작성한 영어 에이전트 파일(CLAUDE.md, AGENTS.md, constitution, rules, agents, 프로젝트 스킬)이 바뀌면 `docs/kr/*_kr.md` 미러가 갱신된다.

**Why this priority**: 사용자가 한국어 번역본을 요구했지만, 자동 로드 디렉터리 안에 두면 토큰 낭비·중복 로드가 생기므로 미러 + 동기화로 해결.

**Independent Test**: `/finish`의 동기화 단계가 변경된 영어 파일 목록을 찾아 대응 `_kr` 파일을 갱신하는지, 미러 커버리지 100%인지 확인.

**Acceptance Scenarios**:

1. **Given** 영어 원본 변경, **When** `/finish` 동기화 단계, **Then** 변경된 파일의 `_kr` 미러만 갱신된다.
2. **Given** Spec Kit이 생성한 `speckit-*` 스킬이나 플러그인 파일, **When** 동기화, **Then** 번역 대상에서 제외된다.

---

### User Story 7 - 머지 후 통합본 갱신 (Priority: P3)

feature가 main에 머지되면 `/speckit-archive`가 `.specify/memory/{spec,plan,changelog}.md`에 해당 feature의 내용을 통합해 "현재 진실"을 유지한다.

**Why this priority**: Flow-Forward의 약점(현재 진실 부재)을 사용자가 선택한 archive 확장으로 보완.

**Independent Test**: 002-smoke 머지 후 archive 실행 → `.specify/memory/spec.md`에 smoke 요구사항이 반영되는지 확인.

**Acceptance Scenarios**:

1. **Given** 머지된 feature, **When** `/speckit-archive`, **Then** 통합본이 갱신되고 `specs/002-smoke/`는 그대로 남으며 `specs/README.md` 상태가 ✅로 바뀐다.

---

### Edge Cases

- 활성 feature 해석은 `SPECIFY_FEATURE_DIRECTORY` env → 현재 브랜치명↔`specs/NNN-slug` 매핑 → `.specify/feature.json` 순서다. finish-gate는 셋 다 실패하거나 서로 불일치하면 deny(fail-closed), approval-review·finish 스킬은 사용자에게 활성 feature를 묻는다. feature.json은 gitignored·체크아웃별 편의 상태일 뿐 정본이 아니다(정본 = git 브랜치 + `specs/<feature>/`).
- 훅 스크립트 자체가 오류로 죽으면 exit 0(fail-open)으로 작업을 막지 않는다. 게이트 불충족만 deny.
- `specify upgrade`가 `.claude/skills/speckit-*`를 덮어써도 명시 호출 전용화는 `settings.json`의 `skillOverrides`에 있으므로 유지된다. 업그레이드 후에는 `/speckit-selftest`와 `docs/runbooks/spec-kit-upgrade.md`의 재검증 목록을 수행한다.
- 두 superpowers 플러그인이 다시 동시에 켜지면 SessionStart 훅이 이중 주입된다 → CLAUDE.md의 전제조건 절에 명시.
- PowerShell 실행 정책이 스크립트를 막으면 훅 명령에 `-ExecutionPolicy Bypass`를 명시한다.
- 브랜치명과 활성 feature 디렉터리가 어긋나면 `speckit-git-validate`로 검출한다(Spec Kit은 브랜치가 아니라 feature.json을 기준으로 삼는다).
- 서브에이전트에 spec/plan 전체를 투입하면 18k+ 토큰이 소모된다 → task 슬라이스만 전달(CLAUDE.md 규칙).

## Requirements *(mandatory)*

### Functional Requirements

**설치·기반**
- **FR-001**: 저장소는 git으로 초기화되고 기본 브랜치는 `main`이며 `.gitattributes`(`* text=auto eol=lf`)를 둔다. GitHub 원격(private)을 `gh repo create`로 만들고 `main`과 feature 브랜치를 push한다. 작업은 `NNN-slug` 브랜치(또는 `.worktrees/NNN-slug`)에서만 한다.
- **FR-002**: Spec Kit은 `specify init --here --integration claude --script ps`로 설치하고, 번들 확장 `git`·`agent-context`·`selftest`와 커뮤니티 확장 `archive`·`adrkit`을 설치한다(커뮤니티 확장은 아카이브 URL 검토 후 `--from`).
- **FR-003**: `git` 확장 설정은 `branch_numbering: sequential`, 기본 템플릿 `{number}-{slug}`, `auto_commit.default: false`, `commit_style: conventional`이다.
- **FR-004**: 사용자 레벨 `~/.claude/settings.json`에서 `superpowers@claude-plugins-official`를 비활성화하고 `superpowers@superpowers-dev`(5.1.0)만 유지한다.
- **FR-005**: Spec Kit이 생성한 `speckit-*` 스킬은 `.claude/settings.json`의 `skillOverrides`(`"user-invocable-only"`)로 명시 호출만 허용한다. 생성된 SKILL.md는 수정하지 않는다(업그레이드 내구성).

**문서·경로**
- **FR-006**: `CLAUDE.md`는 200줄 이하, 첫 줄에 `@AGENTS.md`를 import하며, Spec Kit `agent-context` 확장의 `<!-- SPECKIT START/END -->` 관리 블록을 포함한다.
- **FR-007**: superpowers `brainstorming`의 spec 저장 경로는 활성 feature의 `specs/NNN-slug/spec.md`로 오버라이드하고, 이때 `create-new-feature.ps1 -ShortName <slug> -Json`으로 번호를 확보한 뒤 Spec Kit `spec-template.md` 형식으로 작성한다.
- **FR-008**: superpowers `writing-plans`는 이 저장소에서 사용하지 않는다(`tasks.md`가 유일한 실행 계획). 예외는 `001-claude-setup`(Spec Kit 설치 전 부트스트랩)뿐이다.
- **FR-009**: 각 feature 디렉터리는 Spec Kit 산출물 외에 `reviews/YYYY-MM-DD-{approval,finish}.md`와 `report.md`(Summary / Changes Made / Validation / Next)를 가진다.
- **FR-010**: `specs/README.md`는 번호·제목·Status·우선순위 표이며 각 `spec.md`의 `**Status**` 헤더에서 재생성 가능해야 한다. 완료된 feature 디렉터리는 이동하지 않는다.
- **FR-011**: `docs/decisions/NNNN-<title>.md`는 MADR 4.0 minimal 형식이며 `0000-use-madr.md`와 `0001-adopt-spec-kit-with-superpowers.md`로 시작한다. 번호는 재사용하지 않고 수정 대신 supersede한다.
- **FR-012**: `CHANGELOG.md`는 Keep a Changelog 1.1.0 형식(`Unreleased` 절, ISO 날짜)이다.
- **FR-013**: 에이전트 파일(`CLAUDE.md`, `AGENTS.md`, `.specify/memory/constitution.md`, `.claude/rules/*`, `.claude/agents/*`, 프로젝트 스킬)은 영어로 작성하고, 한국어 미러를 `docs/kr/`에 같은 상대 구조 + `_kr` 접미로 둔다. spec/plan/report/학습 노트/대화/주석은 한국어, 식별자·slug는 영어다. 각 에이전트 파일 상단에 "Canonical language: English / Korean mirror: docs/kr (convenience only) / On conflict, English prevails / Sync: /finish (best-effort)" 선언을 둔다. 미러 갱신은 마감을 막지 않으며 `translation-pending` 상태를 허용한다.

**constitution**
- **FR-014**: constitution은 최소 6개 원칙을 갖는다 — Spec-First, Test-First(NON-NEGOTIABLE), Tenant Boundary(모든 데이터 소유·격리 경계를 spec에 명시), Observability-Ready(로그·메트릭·롤백 경로를 plan에 명시), Simplicity(YAGNI), Learning-in-Public(feature마다 학습 노트). Governance 절에 개정 규칙(SemVer)을 둔다.
- **FR-015**: `.specify/templates/overrides/tasks-template.md`는 테스트 task를 필수로 만들고 User Story마다 E2E task를 포함시킨다.

**에이전트·스킬·훅**
- **FR-016**: `.claude/agents/tester.md`는 tools `Read, Grep, Glob, Bash, Edit, Write`를 가지며, frontmatter `hooks`로 `PreToolUse(Edit|Write)`에 `tester-write-guard.ps1`을 걸어 테스트 경로 외 쓰기를 deny한다. spec의 User Story별 PASS/FAIL/SKIP과 재현 절차를 보고한다.
- **FR-017**: `.claude/skills/approval-review/`는 `boundaries/*.md`(security, tenant-data, operability, trends, spec-consistency)마다 서브에이전트 1개를 병렬 디스패치하고, spec-consistency 경계는 `/speckit-analyze` 결과와 checklist 상태를 사용한다. 결과는 `reviews/YYYY-MM-DD-approval.md`에 기록하고 사용자 확정 후 `spec.md` Status를 `Approved`로 바꾼다.
- **FR-018**: `.claude/skills/finish/`는 순서대로 ① `report.md` 생성 ② `content/study/NNN-slug.mdx` 초안 생성 ③ `CHANGELOG.md` Unreleased 갱신 ④ 필요 시 `/speckit-adrkit-draft` 안내 ⑤ `docs/kr` 미러 동기화(best-effort, 미완료 시 `translation-pending` 표시, 마감 비차단) ⑥ `boundaries/*.md`(report-vs-diff, e2e-evidence, study-contract, decisions)별 서브에이전트 병렬 리뷰 → `reviews/YYYY-MM-DD-finish.md`(`Status: Approved | Issues`)를 수행한다. Issues면 수정 후 ⑥을 재실행한다.
- **FR-019**: 훅은 세 개다. `approval-review.ps1`(UserPromptSubmit: 승인 키워드 `승인|approve|approved|LGTM|진행해` 감지 시 `/approval-review` 실행 지시를 `systemMessage`로 출력), `finish-gate.ps1`(PreToolUse matcher `Skill`: `tool_input.skill`이 `finishing-a-development-branch`를 포함하면 활성 feature를 D12 순서(env → 브랜치명 → feature.json)로 해석하고, 해석 실패·불일치 또는 `reviews/*-finish.md`의 `Status: Approved`·`report.md`·`content/study/<basename>*.mdx` 중 하나라도 없으면 `permissionDecision: deny`), `tester-write-guard.ps1`(PreToolUse Edit|Write: 경로 화이트리스트 외 deny). 모두 스크립트 오류 시 exit 0.
- **FR-020**: `.claude/settings.json`은 `permissions.deny`에 `Bash(rm -rf *)`, `Bash(git reset --hard*)`, `Bash(git push --force*)`, `Bash(git push -f*)`, `Bash(git clean -fd*)`, `Bash(docker system prune*)`를 두고 훅 2종(approval-review, finish-gate)을 등록한다. 훅 명령은 `powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/<name>.ps1`이다.
- **FR-021**: `.claude/rules/`는 `specs.md`(paths: `specs/**`), `docs.md`(paths: `docs/**`), `content.md`(paths: `content/**`) 세 파일이며 각각 해당 경로의 형식·계약만 담는다.

**콘텐츠 계약**
- **FR-022**: `content/study/*.mdx` frontmatter는 `title`(string), `description`(string), `pubDate`(ISO date), `updatedDate?`, `tags`(string[]), `series?`(string), `seriesOrder?`(int), `draft`(bool, 생성 시 true), `change`(string, `NNN-slug`), `sources`({title, url|path}[])를 가진다. 파일명은 ASCII kebab-case(`NNN-slug.mdx`)다.
- **FR-023**: 학습 노트 본문은 `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습` 5개 절을 가진다.

**도구 경계(CLAUDE.md 규칙)**
- **FR-024**: CLAUDE.md는 다음을 명시한다 — Spec Kit 명령은 명시 호출만; `speckit-implement` 대신 superpowers SDD 사용; SDD·Tester·리뷰 서브에이전트에는 task 슬라이스와 관련 절만 전달; 활성 feature는 env → 브랜치명 → `.specify/feature.json` 순으로 해석하며 정본은 git 브랜치 + `specs/<feature>/`; 승인 전 구현 금지; 마감은 `/finish` → finishing → 머지 → `/speckit-archive` 순서.

- **FR-025**: `docs/runbooks/spec-kit-upgrade.md`에 커스터마이즈 레지스터(파일별 원본 Spec Kit 버전·원본 경로·변경 이유·재검증 명령)와 `specify upgrade` 절차를 둔다. AGENTS.md는 활성 Spec Kit integration이 `claude` 하나임과, 다른 에이전트(Codex 등)는 AGENTS.md·constitution·`specs/`만 읽는다는 것을 명시한다.

### Key Entities

- **Feature**: `specs/NNN-slug/` 디렉터리. Spec Kit 산출물(spec/plan/tasks/research/data-model/quickstart/contracts/checklists) + 프로젝트 산출물(reviews/, report.md). 상태는 `spec.md` `**Status**` 헤더(Draft → Approved → Done).
- **Review**: `reviews/YYYY-MM-DD-{approval|finish}.md`. 경계(boundary)별 절 + 종합 판정. 경계 정의는 스킬의 `boundaries/*.md`.
- **Report**: `report.md`. Summary / Changes Made / Validation / Next 4절.
- **StudyNote**: `content/study/NNN-slug.mdx`. FR-022 계약. 사이트(SP-1)가 소비.
- **Decision**: `docs/decisions/NNNN-*.md`. MADR 4.0 minimal. adrkit이 plan 검토에 사용.
- **Constitution**: `.specify/memory/constitution.md`. 원칙·게이트·거버넌스. plan의 Constitution Check가 참조.
- **ActiveFeaturePointer**: `.specify/feature.json` (gitignored, 체크아웃별 편의 상태). 훅·스킬은 `SPECIFY_FEATURE_DIRECTORY` env → 브랜치명 → 이 파일 순으로 대상 feature를 해석한다. 정본은 git 브랜치와 `specs/<feature>/`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `/speckit-selftest`가 통과하고 `.claude/skills/speckit-*` 10개 + 확장 스킬이 모두 `settings.json` `skillOverrides`로 명시 호출 전용이다(생성 파일 무수정).
- **SC-002**: 훅 3종이 샘플 stdin JSON으로 단위 검증된다 — approval 키워드 → systemMessage 출력, 비키워드 → 무출력; finish-gate 산출물 없음 → deny / 있음 → 통과 / feature.json 없음 + 브랜치 `NNN-slug` → 브랜치로 해석 / 해석 불가·불일치 → deny; tester-write-guard `tests/e2e/a.test.ts` → allow, `src/a.ts` → deny.
- **SC-003**: `002-smoke`가 US1의 시나리오 1~5를 모두 통과하고, `specs/002-smoke/`에 spec·plan·tasks·reviews(approval, finish)·report가, `content/study/002-smoke.mdx`와 `CHANGELOG.md` Unreleased 항목이 존재하며 `.specify/memory/spec.md`에 통합된다.
- **SC-004**: `CLAUDE.md`가 200줄 이하이고, `/hooks`·`/agents`·`/skills`에 훅 2종·tester·프로젝트 스킬 2종이 등록되어 보인다.
- **SC-005**: `docs/kr/`가 프로젝트 작성 에이전트 파일 전부(CLAUDE, AGENTS, constitution, rules 3, tester, 스킬 2)에 대해 `_kr` 미러를 갖는다(커버리지 100%).
- **SC-006**: `docs/decisions/0000`, `0001`이 MADR 형식이고 `specs/README.md`가 001·002를 올바른 상태로 나열한다.
- **SC-007**: 사용자 레벨 설정에서 superpowers 플러그인이 하나만 활성화되어 세션 시작 시 using-superpowers 주입이 1회만 발생한다.
- **SC-008**: `docs/runbooks/spec-kit-upgrade.md`가 커스터마이즈 파일마다 원본 Spec Kit 버전·원본 경로·변경 이유·재검증 명령을 기록하고 업그레이드 절차를 담는다.
- **SC-009**: GitHub 원격에 `main`과 `001-claude-setup`이 push되어 있다.

## Assumptions

- 1인 개발(팀 인수인계 형식 없음). 개발기는 Windows 11 + PowerShell 7, Git Bash 보조. 훅은 PowerShell 단일 스크립트다(Linux 개발기가 생기면 `.sh` 변형을 추가한다).
- `uv`(또는 pipx)로 `specify` CLI를 설치할 수 있다. CLI는 init·upgrade·확장 관리에만 필요하고 일상 명령은 `.specify/scripts/powershell/*`만 쓴다.
- `gh` CLI가 인증되어 있어 private 원격 저장소를 만들 수 있다. 없으면 원격 생성은 사용자가 수동으로 하고 push만 수행한다.
- superpowers 5.1.0의 SDD는 task당 리뷰어 2명(spec, quality)이며 재리뷰 루프를 갖는다. 5.1.0에는 plan 헤더 `Spec:`과 `Global Constraints`가 없으므로 E2E·테넌트 경계 요구는 CLAUDE.md 규칙 + tasks 템플릿 override로 전달한다.
- 커뮤니티 확장(`archive`, `adrkit`)은 discovery-only 카탈로그이므로 설치 전 아카이브 URL을 검토한다. 설치 실패 시 해당 기능은 수동 절차(README 문서화)로 대체하고 SP-0 완료를 막지 않는다.
- SP-0은 스택 중립이다. 코드 도메인 규칙·에이전트·스킬은 SP-1(스택 결정) 이후 같은 명명 패턴으로 추가한다.
- 이 문서의 `/speckit-archive`, `/speckit-selftest`, `/speckit-adrkit-*`는 확장 명령의 **예상** 이름이다. 실제 슬래시 이름은 설치 후 `.claude/skills/speckit-*/` 목록으로 확정하고 CLAUDE.md에 그 이름을 쓴다.

---

## Design

### 1. 아키텍처 — 역할 분담

```
Spec Kit (WHAT)                          superpowers 5.1.0 (HOW)                 프로젝트 레이어 (게이트·학습)
────────────────────────────────         ──────────────────────────────         ─────────────────────────────
constitution / specify / clarify         brainstorming (아키텍처급 착수)          tester 에이전트 (E2E, 테스트 코드)
plan (Constitution Check) / checklist    subagent-driven-development (실행)      approval-review 스킬 (경계별 리뷰)
tasks (실행 계획) / analyze / converge   test-driven-development                finish 스킬 (report·study·리뷰)
git / agent-context / selftest 확장      requesting/receiving-code-review        훅 3종 (트리거·게이트·가드)
archive / adrkit 확장                    finishing-a-development-branch          rules 3 · settings · docs/kr
                                         using-git-worktrees / systematic-debugging
```

우선순위: CLAUDE.md > superpowers 스킬 > 기본 프롬프트(플러그인이 명시). constitution은 온디맨드(명령이 읽음), CLAUDE.md는 상시 — 중복하지 않고 링크한다.

### 2. 디렉터리 구조 (SP-0 완료 시점)

범례: `[SK]` Spec Kit init · `[EXT]` 확장 설치 · `[P]` 프로젝트 작성 · `[RT]` 런타임 생성 · `[GI]` gitignore

```
joshuatech_ver2/
├── AGENTS.md  CLAUDE.md  CHANGELOG.md  README.md  .gitignore  .gitattributes   [P]
├── .specify/
│   ├── memory/constitution.md [SK→P]  · spec.md plan.md changelog.md [RT, archive]
│   ├── templates/*-template.md [SK]  · templates/overrides/tasks-template.md [P]
│   ├── scripts/powershell/*.ps1 [SK]
│   ├── extensions/{git,agent-context,selftest,archive,adrkit}/ [EXT] · extensions.yml [EXT]
│   ├── workflows/speckit/workflow.yml [SK]
│   ├── integrations/ · integration.json · init-options.json [SK]
│   └── feature.json [RT][GI]
├── .claude/
│   ├── settings.json [P] · settings.local.json [RT][GI]
│   ├── skills/speckit-*/ [SK,EXT] · skills/{approval-review,finish}/{SKILL.md,boundaries/} [P]
│   ├── agents/tester.md [P]
│   ├── rules/{specs,docs,content}.md [P]
│   └── hooks/{approval-review,finish-gate,tester-write-guard}.ps1 [P]
├── specs/README.md [P] · specs/001-claude-setup/{spec.md,plan.md,research/,reviews/,report.md} [P]
│   └── specs/NNN-slug/{spec,plan,tasks,research,data-model,quickstart}.md contracts/ checklists/ [SK] + reviews/ report.md [P]
├── docs/README.md · docs/decisions/{0000,0001}-*.md · docs/kr/** · docs/runbooks/spec-kit-upgrade.md [P]
├── content/study/NNN-slug.mdx [P/RT]
└── .worktrees/ .superpowers/ [RT][GI]
```

### 3. 워크플로우 — 전체 킷 배치

핵심 명령: `constitution`(제정·개정) · `specify`(일반 착수) · `clarify`(≤5문항) · `plan` · `checklist` · `tasks`(유일한 실행 계획) · `analyze`(approval 경계로 사용) · `implement`(**미사용**, SDD가 대체) · `converge`(구현 후 갭) · `taskstoissues`(원격 생기면).
번들 확장: `git`(SP-0) · `agent-context`(SP-0) · `selftest`(SP-0) · `assess`(Tier 2, 아이디어 가치 판단) · `bug`(Tier 2, spec 없는 버그 경로).
커뮤니티: `archive`(SP-0) · `adrkit`(SP-0) · `reconcile`/`security-review`/`review`/`pr-bridge`/`changelog`(Tier 2) · `agent-assign`(SP-1 이후) · 브릿지/worktree/tdd/branch-convention(미채택 — superpowers와 CLAUDE.md 규칙이 담당).
프리셋 `lean`/`constitution-sync` 미채택. 워크플로우 엔진 오버레이는 Tier 2.

```
[가치 판단]  (선택) /speckit-assess-* → go
[착수]       아키텍처급: brainstorming → create-new-feature.ps1 → spec.md(템플릿 형식)
             일반 기능: /speckit-specify → (git 확장: NNN-slug 브랜치) → /speckit-clarify
[계획]       /speckit-plan (Constitution Check · adrkit check · agent-context 갱신) → /speckit-checklist → /speckit-tasks
[승인]       "승인" → approval-review 훅 → /approval-review (경계 5개 병렬) → reviews/*-approval.md → 확정 → Status: Approved
[구현]       superpowers SDD가 tasks.md 실행 — implementer(TDD) → spec-reviewer → quality-reviewer → 커밋, tasks.md [X]
[수렴]       /speckit-converge → 갭 task → 재실행 → ✅ Converged
[E2E]        Tester → User Story별 PASS/FAIL/SKIP → FAIL은 SDD 루프 또는 bug 확장
[마감]       /finish → report.md · study 초안 · CHANGELOG · adrkit draft(필요 시) · _kr 동기화 · finish 리뷰(경계 4개)
[통합]       finishing-a-development-branch ← finish-gate → 머지 → /speckit-archive
```

### 4. 컴포넌트 명세

**CLAUDE.md (EN, <200줄)** — `@AGENTS.md` · 전제조건(플러그인 단독, uv) · 도구 경계 규칙(FR-024) · 경로 오버라이드(FR-007, FR-008) · 워크플로우 요약 · 훅·스킬·에이전트 목록 · 언어 규칙(FR-013) · `docs/README.md` 링크 · SPECKIT 관리 블록.

**AGENTS.md (EN)** — 프로젝트 개요, 현재 스택(SP-0: 없음), 명령어(Spec Kit·훅 테스트), 디렉터리 맵, 커밋 규칙(Conventional Commits, 한국어 설명 허용), 브랜치 규칙, 활성 integration(claude)과 타 에이전트의 읽기 범위.

**constitution (EN)** — FR-014의 6원칙 + Governance(SemVer, 개정은 `/speckit-constitution`).

**tasks-template override** — `### Tests for User Story N` 절을 필수로, 각 스토리 마지막에 `- [ ] T### [USn] E2E: <시나리오> (tester)` task를 포함.

**rules** — `specs.md`: Status 헤더 값·reviews/report 형식·서브에이전트 슬라이스 규칙·README 재생성 규칙. `docs.md`: MADR 형식·번호 규칙·kr 미러 규칙. `content.md`: FR-022/023 계약.

**tester.md** — 역할·제약(프로덕션 코드 금지, mock 최소)·절차(User Story → 시나리오 → 실행 → 관찰 → 보고)·보고 형식(시나리오별 PASS/FAIL/SKIP, 재현 절차, 심각도) · frontmatter `hooks`로 경로 가드.

**approval-review 스킬** — 입력: 활성 feature. 절차: `.specify/feature.json` 읽기 → `boundaries/*.md`마다 Agent 병렬 디스패치(각 프롬프트 = 경계 체크리스트 + spec/plan/tasks 관련 절만) → 결과 표 취합 → `reviews/YYYY-MM-DD-approval.md` 작성 → 사용자 확정 질문 → Status 갱신. 경계 파일 형식: `# <경계>` / `## 목적` / `## 체크리스트` / `## 출력 형식`.

**finish 스킬** — FR-018 순서. report.md 형식: `# Report NNN-slug` / `## Summary` / `## Changes Made` / `## Validation` / `## Next`. finish 리뷰 파일: 경계별 절 + `Status: Approved | Issues`.

**훅 I/O 계약**
- 입력: stdin JSON(`hook_event_name`, `prompt`/`tool_name`/`tool_input`, `cwd`).
- `approval-review.ps1`: 키워드 매칭 시 `{"systemMessage": "..."}` 출력, 아니면 무출력. exit 0.
- `finish-gate.ps1`: `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"..."}}` 또는 무출력(allow). exit 0. 활성 feature 해석은 env → 브랜치명 → feature.json, 실패·불일치 시 deny. `permissionDecisionReason`은 모델에도 전달된다.
- 참고: 프로젝트 훅은 서브에이전트의 도구 호출에도 발화하며 입력에 `agent_type`이 포함되므로 tester 가드를 settings 훅으로 두는 것도 가능하다. 응집도 때문에 에이전트 frontmatter 훅을 유지한다.
- `tester-write-guard.ps1`: 위와 같은 deny 계약. 화이트리스트 glob: `tests/**`, `e2e/**`, `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`.

**settings.json** — FR-020. `additionalDirectories`는 없음(SP-0).

### 5. 데이터 흐름

- 활성 feature: `create-new-feature.ps1`/`speckit-specify` → `.specify/feature.json`(편의) + 브랜치 `NNN-slug`(정본). 훅·스킬은 env → 브랜치명 → feature.json 순으로 해석한다.
- 승인: 사용자 프롬프트 → 훅(systemMessage) → 컨트롤러가 `/approval-review` → 서브에이전트 N개(읽기 전용) → 리뷰 파일 → 사용자 확정 → spec Status.
- 마감: `/finish` → report/study/CHANGELOG/kr 생성 → 서브에이전트 리뷰 → finish 리뷰 파일 → finishing 스킬 호출 시 게이트가 파일을 검사.
- 학습: report + spec + reviews → study 초안(draft) → SP-1 사이트가 `content/study`를 콘텐츠 컬렉션으로 읽어 발행(draft=false 전환은 사람이).

### 6. 에러 처리

- 훅: 스크립트 예외·JSON 파싱 실패 → exit 0, 무출력(fail-open). 게이트 불충족만 deny + 사유.
- Tester: 환경 부재 → SKIP + 사유. FAIL → 컨트롤러가 SDD 루프 복귀(3회 넘으면 systematic-debugging).
- converge: 갭이 `unrequested`(요청 밖 구현)면 제거 task 또는 spec 개정을 사용자에게 묻는다.
- 확장 설치 실패: 기능을 수동 절차로 대체하고 `report.md` Validation에 기록.
- Spec Kit 업그레이드 후: `docs/runbooks/spec-kit-upgrade.md` 절차(`/speckit-selftest` + 레지스터의 재검증 명령). `skillOverrides`는 settings에 있어 영향 없음.

### 7. 테스트·검증 전략

- 단위: 훅 3종 × 시나리오(SC-002)를 PowerShell에서 stdin JSON으로 실행해 stdout 검증.
- 통합: Claude Code에서 `/hooks`, `/agents`, `/skills` 등록 확인, `/speckit-selftest`.
- E2E: `002-smoke` 전 흐름 실주행(SC-003). 스모크 작업은 `specs/README.md` 인덱스 재생성 스크립트처럼 코드가 거의 없는 작업으로 고른다.
- 문서: CLAUDE.md 줄 수, kr 미러 커버리지, MADR 형식 검사.

### 8. 확장 경로 (SP-1 이후)

- 스택 결정 시: `.claude/rules/<domain>.md`(paths), `.claude/agents/<domain>-builder.md`(skills 프리로드), `boundaries/<domain>.md`, `apps/<app>/CLAUDE.md`, `settings.json` allow 목록.
- 서비스 증가 시: `agent-assign` 확장, `.specify/workflows/overlays/`(헤드리스 사이클), `security-review`/`review` 확장, 프로젝트 로컬 플러그인화(`.claude-plugin/`).
- 운영 시작 시: `docs/runbooks/`, `pr-bridge`, `changelog`, `taskstoissues`, 3단 브랜치 승격(develop/release/main).
- 병렬 에이전트(Orca 등) 도입 시(SP-1 이후): `docs/runbooks/parallel-agents.md`(worktree별 scope, 에이전트 프롬프트 템플릿, 승인 후 spec/plan/tasks read-only), Orca worktree 경로와 `.worktrees/` 정합 확인, Codex 등 비-Claude 에이전트는 훅이 없으므로 AGENTS.md + CI로 통제.
- 최소 CI(SP-1 이후): `.github/workflows/ci.yml`(훅 단위 테스트·마크다운 린트·CLAUDE.md 200줄 검사), main 보호 규칙.
- `.specify/memory/product.md`·`architecture.md`(SP-1 산출물): 스택·경계 결정 후 현재 시스템의 지속 지식으로 승격.

### 9. 서브 프로젝트 분해 (로드맵)

| SP | 내용 | 진입 |
|----|------|------|
| SP-0 | Claude Code 기반 셋팅 (이 spec) | 부트스트랩 예외 |
| SP-1 | 아키텍처·스택 결정(Cloudflare 네이티브 / Python MSA / 하이브리드), 도메인 규칙·에이전트 | assess → brainstorming → specify |
| SP-2 | 사이트 코어(포트폴리오·블로그·study 콘텐츠 컬렉션) | specify |
| SP-3 | 플랫폼·운영(인증·테넌트 경계·관측·CI/CD 승격·런북) | specify |
| SP-4+ | 인터랙티브 서비스(AI 챗봇 등), 멀티테넌트(B) 전환 | assess |

### 10. 리스크

| 리스크 | 대응 |
|---|---|
| Spec Kit 명령 프롬프트가 크다(7~22KB/회) | 명시 호출만, clarify/checklist는 필요할 때만 |
| superpowers가 constitution을 무시 | CLAUDE.md에 원칙 포인터 + approval 경계에 spec-consistency(analyze) 포함 |
| 훅은 프롬프트 준수에 의존(approval) | finish-gate·write-guard는 결정적(파일·경로 검사) |
| 확장이 서드파티(archive, adrkit) | 아카이브 URL 검토 후 설치, 실패 시 수동 절차 |
| 5.1.0 SDD 리뷰어 2명으로 느림 | 작은 동형 task는 하나로 묶어 tasks.md 작성 |
