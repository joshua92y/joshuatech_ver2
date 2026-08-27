# Main Implementation Plan

> **Revision**: 2026-08-27 — specs/001-claude-setup 아카이브(첫 아카이브: 시드 생성 후 plan 내용 반영)

## Summary

`joshuatech_ver2` 저장소는 애플리케이션 코드 없이 에이전트 작업 뼈대만 갖춘 상태(SP-0)다. Spec Kit(계약·흐름: constitution, `specs/NNN-slug/`, `/speckit-*` 명령, git·agent-context·archive 확장)이 WHAT을, superpowers 5.1.0(brainstorming·TDD·subagent-driven-development·code review·finishing)이 HOW를 맡고, 저장소의 `.claude/` 레이어(결정적 훅 3종, 경계별 서브에이전트 리뷰 스킬 2종, E2E `tester` 에이전트, 경로 규칙 3종, `tests/run-all.ps1`)가 품질 게이트를 강제한다. 활성 feature는 `SPECIFY_FEATURE_DIRECTORY` env → 브랜치명 `NNN-slug` → `.specify/feature.json` 순으로 해석하며 해석 실패·불일치는 fail-closed다. 문서 정책(MADR ADR, 업그레이드 런북, 한국어 미러, 학습 노트 계약)과 CLAUDE.md/AGENTS.md를 정했고, 스모크 feature `002-smoke`(`scripts/update-specs-index.ps1`)로 전체 사이클을 실주행해 검증했다. [Source: specs/001-claude-setup/plan.md -> "**Goal:**"] [Source: specs/001-claude-setup/plan.md -> "**Architecture:**"] [Source: specs/001-claude-setup/report.md -> "## Summary"]

## Technical Context

**Language/Version**: PowerShell 7 (`pwsh`; 계획 시 실측 7.6.3, 002 마감 시 7.6.5 하한 기재 검토) — 훅·테스트·스크립트 전부 PowerShell 단일 스크립트; 그 외 산출물은 Markdown(에이전트 파일 영어, 나머지 한국어). 애플리케이션 언어는 SP-1에서 결정. [Source: specs/001-claude-setup/plan.md -> "**Tech Stack:**"] [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"] [Source: specs/001-claude-setup/report.md -> "## Next"] [Source: specs/001-claude-setup/spec.md -> "## Assumptions"]

**Primary Dependencies**: Spec Kit CLI `specify` 1.0.2.dev0(`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`; integration=claude, script=ps) + 확장 `git`·`agent-context`(번들) 및 `archive` 1.3.0(커뮤니티, stn1slv/spec-kit-archive); superpowers 플러그인 5.1.0(`superpowers@superpowers-dev` 단독 활성); Claude Code 훅·스킬·에이전트·rules·settings; git + `gh` 2.93; Python 3.14 + PyYAML(agent-context 확장 요구). [Source: specs/001-claude-setup/report.md -> "`specify check` (specify 1.0.2.dev0)"] [Source: specs/001-claude-setup/plan.md -> "Task 3: `uv`와 `specify` CLI 설치"] [Source: specs/001-claude-setup/plan.md -> "Task 4: `specify init` (Claude 통합, PowerShell 스크립트)"] [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"] [Source: specs/001-claude-setup/plan.md -> "Task 6: 커뮤니티 확장 `archive` (검토 후 설치)"] [Source: specs/001-claude-setup/plan.md -> "Task 2: 사용자 레벨 superpowers 플러그인 단일화"] [Source: specs/001-claude-setup/plan.md -> "**Tech Stack:**"]

**Storage**: git 저장소 파일만(데이터베이스 없음). 정본은 git 브랜치 + `specs/<feature>/`; `.specify/feature.json`은 gitignored·체크아웃별 편의 파일이며 정본이 아니다. [Source: specs/001-claude-setup/plan.md -> "**Tech Stack:**"] [Source: specs/001-claude-setup/spec.md -> "D12"] [Source: specs/001-claude-setup/plan.md -> "## Active feature resolution"]

**Testing**: `tests/run-all.ps1`(저장소 검사 11절 12 Check; 훅 하네스 23 케이스 포함, ≈37초) + `tests/hooks/run-hook-tests.ps1`(외부 프레임워크 없이 stdin JSON → stdout/exit code 검증) + `tests/scripts/update-specs-index.tests.ps1`(002 산출) + `tester` 에이전트의 User Story별 E2E(PASS/FAIL/SKIP). [Source: specs/001-claude-setup/report.md -> "### specs·tests"] [Source: specs/001-claude-setup/report.md -> "SC-002 PASS"] [Source: specs/001-claude-setup/plan.md -> "Task 10: 훅 단위 테스트 하네스 (RED)"] [Source: specs/001-claude-setup/spec.md -> "### 7. 테스트·검증 전략"]

**Target Platform**: Windows 11 개발기(1인), PowerShell 7이 PATH에 있어야 함(ExecutionPolicy RemoteSigned → 훅은 `pwsh -NoProfile -ExecutionPolicy Bypass -File …`), Git Bash 보조. 훅은 PowerShell 단일 스크립트(Linux 개발기가 생기면 `.sh` 변형 추가). [Source: specs/001-claude-setup/spec.md -> "## Assumptions"] [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"] [Source: specs/001-claude-setup/plan.md -> "## Prerequisites"]

**Project Type**: 개발자 도구·저장소 컨벤션(에이전트 워크플로우 뼈대). 애플리케이션 코드 없음, 스택 중립 — 스택은 SP-1에서 결정. [Source: specs/001-claude-setup/plan.md -> "**Tech Stack:**"] [Source: specs/001-claude-setup/spec.md -> "D3"]

**Performance Goals**: 애플리케이션 성능 목표 없음(SP-0). 운영 지표: `tests/run-all.ps1` ≈37초(하네스 자식 pwsh 21회); 훅 타임아웃 approval-review 10s · finish-gate 10s · tester-write-guard 5s. [Source: specs/001-claude-setup/report.md -> "## Next"] [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/plan.md -> "Task 15: `tester` 에이전트 + 한국어 미러"]

**Constraints**: CLAUDE.md ≤ 200줄; 에이전트 파일(CLAUDE.md, AGENTS.md, 헌법, rules, agents, 프로젝트 스킬)은 영어 + `docs/kr/*_kr.md` 미러, 대화·spec·plan·report·학습 노트는 한국어, 식별자·파일명은 영어/ASCII; secrets는 저장소에 넣지 않음; feature 디렉터리 `specs/NNN-slug/`는 불변(이동·삭제·이름 변경 금지); `speckit-*` 스킬은 명시 호출만(`skillOverrides: name-only`, SKILL.md 무수정); 파일은 UTF-8·LF·ASCII kebab-case; Conventional Commits(한국어 설명 허용), task당 커밋 1개, force-push·공유 이력 재작성 금지. [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"] [Source: specs/001-claude-setup/plan.md -> "## Language"] [Source: specs/001-claude-setup/plan.md -> "## Conventions"] [Source: specs/001-claude-setup/plan.md -> "Task 16: 경로 규칙 3종 + 한국어 미러"] [Source: specs/001-claude-setup/spec.md -> "D13"] [Source: specs/001-claude-setup/plan.md -> "## 작업 규칙"]

**Scale/Scope**: SP-0 부트스트랩, 1인 개발. feature 2개(001-claude-setup, 002-smoke); 001 브랜치 기준 136 files / +20,088 lines, 커밋 75개(002 fast-forward 머지분 22 files 포함). [Source: specs/001-claude-setup/spec.md -> "## Assumptions"] [Source: specs/001-claude-setup/report.md -> "## Changes Made"]

## Dependencies

| 구성 요소 | 버전 / 설치 | 역할 | 출처 |
|---|---|---|---|
| Spec Kit CLI `specify` | 1.0.2.dev0 — `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`(계획은 v1.0.1 고정 의도) | init·upgrade·확장 관리 전용; 일상 명령은 `.specify/scripts/powershell/*.ps1` | [Source: specs/001-claude-setup/report.md -> "`specify check` (specify 1.0.2.dev0)"] [Source: specs/001-claude-setup/plan.md -> "Task 3: `uv`와 `specify` CLI 설치"] [Source: specs/001-claude-setup/plan.md -> "## Prerequisites"] |
| Spec Kit 프로젝트 초기화 | `specify init --here --integration claude --script ps --non-interactive --force --ignore-agent-tools` → 핵심 스킬 10개(`speckit-{analyze,checklist,clarify,constitution,converge,implement,plan,specify,tasks,taskstoissues}`) | 계약 레이어 | [Source: specs/001-claude-setup/plan.md -> "Task 4: `specify init` (Claude 통합, PowerShell 스크립트)"] |
| `git` 확장 (번들) | 1.0.0; `commit_style: conventional`, `auto_commit.default: false` | `before_specify` 훅으로 브랜치 `NNN-slug` 생성; 스킬 `speckit-git-{commit,feature,initialize,remote,validate}` | [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"] [Source: specs/001-claude-setup/plan.md -> "## 커스터마이즈 레지스터"] |
| `agent-context` 확장 (번들) | 1.0.0; Python 3.14.2 + PyYAML 6.0.3 필요 | `after_plan` 훅으로 CLAUDE.md `<!-- SPECKIT START/END -->` 블록에 plan 경로 기록; 스킬 `speckit-agent-context-update` | [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"] [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"] |
| `archive` 확장 (커뮤니티) | 1.3.0, https://github.com/stn1slv/spec-kit-archive — 아카이브 URL 다운로드·위험 패턴 검토 후 설치 | 머지 후 `.specify/memory/{spec,plan,changelog}.md` 통합; 스킬 `speckit-archive-run` | [Source: specs/001-claude-setup/plan.md -> "Task 6: 커뮤니티 확장 `archive` (검토 후 설치)"] [Source: specs/001-claude-setup/spec.md -> "## Assumptions"] |
| superpowers 플러그인 | 5.1.0 `superpowers@superpowers-dev`(사용자 레벨 단독 활성; `superpowers@claude-plugins-official` 비활성) | 실행 레이어(brainstorming·TDD·SDD·code review·finishing·worktrees·systematic-debugging) | [Source: specs/001-claude-setup/plan.md -> "Task 2: 사용자 레벨 superpowers 플러그인 단일화"] [Source: specs/001-claude-setup/spec.md -> "D8"] |
| Claude Code | 프로젝트 `settings.json`·hooks·skills·agents·rules | 게이트 레이어 | [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] |
| PowerShell 7 (`pwsh`) | 7.6.x, PATH 등록 | 훅·테스트·스크립트 런타임 | [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"] |
| `uv` | `winget install --id=astral-sh.uv` | `specify` 설치 도구 | [Source: specs/001-claude-setup/plan.md -> "Task 3: `uv`와 `specify` CLI 설치"] |
| git + `gh` | `gh` 2.93.0(인증됨); 원격 `joshua92y/joshuatech_ver2`(private) | 브랜치·원격·push | [Source: specs/001-claude-setup/plan.md -> "**Tech Stack:**"] [Source: specs/001-claude-setup/plan.md -> "Task 1: `.gitattributes`와 GitHub 원격"] |

## Architecture

**역할 분담(3층)** — Spec Kit이 WHAT, superpowers가 HOW, 프로젝트 레이어가 게이트·학습을 맡는다. [Source: specs/001-claude-setup/spec.md -> "### 1. 아키텍처 — 역할 분담"] [Source: specs/001-claude-setup/plan.md -> "## Tool boundaries"]

```
Spec Kit (WHAT)                          superpowers 5.1.0 (HOW)                 프로젝트 레이어 (게이트·학습)
constitution / specify / clarify         brainstorming (아키텍처급 착수)          tester 에이전트 (E2E, 테스트 코드)
plan / checklist / tasks / analyze /     subagent-driven-development (실행)      approval-review 스킬 (경계 5 리뷰)
converge / archive                       test-driven-development                finish 스킬 (report·study·경계 4 리뷰)
git / agent-context / archive 확장       requesting/receiving-code-review        훅 3종 (트리거·게이트·가드)
                                         finishing-a-development-branch          rules 3 · settings · docs/kr
                                         using-git-worktrees / systematic-debugging
```

- 우선순위: CLAUDE.md > superpowers 스킬 > 기본 프롬프트. constitution은 온디맨드(명령이 읽음), CLAUDE.md는 상시 — 중복하지 않고 링크한다. [Source: specs/001-claude-setup/spec.md -> "### 1. 아키텍처 — 역할 분담"]
- `speckit-implement`는 쓰지 않는다(superpowers SDD가 `tasks.md`를 실행). superpowers `writing-plans`도 쓰지 않는다(`tasks.md`가 유일한 실행 계획; 유일한 예외는 `specs/001-claude-setup/plan.md`). brainstorming을 쓰면 설계는 `create-new-feature.ps1 -ShortName <slug> -Json`으로 할당한 `specs/NNN-slug/spec.md`에 spec-template 형식으로 저장한다. [Source: specs/001-claude-setup/plan.md -> "## Tool boundaries"]
- 서브에이전트에는 task 슬라이스와 관련 절만 전달한다 — spec/plan 전체 파일은 넘기지 않는다. [Source: specs/001-claude-setup/plan.md -> "## Tool boundaries"] [Source: specs/001-claude-setup/plan.md -> "## 작업 규칙"]
- 훅은 트리거·게이트만 담당하고 판단은 경계별 서브에이전트 리뷰가 한다(approval-review / finish 스킬이 병렬 디스패치). [Source: specs/001-claude-setup/spec.md -> "D11"]
- 활성 feature 해석: `SPECIFY_FEATURE_DIRECTORY` → 현재 브랜치 `NNN-slug` ↔ `specs/<branch>/` → `.specify/feature.json`(일치 검사용; 단독 해석 불허). 소스가 어긋나거나 어느 것도 해석되지 않으면 fail-closed(훅은 deny, 스킬은 질문). [Source: specs/001-claude-setup/spec.md -> "D12"] [Source: specs/001-claude-setup/plan.md -> "Task 12: `finish-gate.ps1` (PreToolUse · Skill)"]
- 사후 모델은 Flow-Forward + `archive` 확장: `specs/NNN-slug/`는 불변 이력, `.specify/memory/`는 통합본("현재 진실"). [Source: specs/001-claude-setup/spec.md -> "D7"]
- 데이터 흐름: 승인 = 사용자 프롬프트 → 훅(systemMessage) → `/approval-review` → 서브에이전트 5개(읽기 전용) → `reviews/*-approval.md` → 사용자 확정 → spec Status. 마감 = `/finish` → report/study/CHANGELOG/kr → 서브에이전트 4개 → `reviews/*-finish.md` → finishing 호출 시 게이트가 파일 검사. 학습 = report + spec + reviews → `content/study/NNN-slug.mdx`(draft) → SP-1 사이트가 콘텐츠 컬렉션으로 발행. [Source: specs/001-claude-setup/spec.md -> "### 5. 데이터 흐름"]

## Components

프로젝트가 작성한 모듈(생성 도구 산출물 제외). [Source: specs/001-claude-setup/report.md -> "## Changes Made"]

**훅 3종 (`.claude/hooks/`, PowerShell)**
- `approval-review.ps1` — UserPromptSubmit. 승인 키워드(넓은 집합, D15) 매칭 시 `{"systemMessage": "..."}`로 `/approval-review` 선행을 지시; 아니면 무출력. exit 0. [Source: specs/001-claude-setup/plan.md -> "Task 11: `approval-review.ps1` (UserPromptSubmit)"] [Source: specs/001-claude-setup/spec.md -> "**훅 I/O 계약**"]
- `finish-gate.ps1` — PreToolUse(matcher `Skill`). `superpowers:finishing-a-development-branch` 호출을 활성 feature에 `reviews/*-finish.md`(최신 파일의 첫 `Status:` 줄이 정확히 `Approved`, `(YYYY-MM-DD)` 허용), 비어 있지 않은 `report.md`, 비어 있지 않은 `content/study/<feature>*.mdx`가 모두 있을 때만 허용; 그 외 `permissionDecision: deny` + 사유(`Run /finish first`). 경로 정규화(`GetFullPath`), `-LiteralPath`, `git -C $root`, `tool_input.name` 폴백. [Source: specs/001-claude-setup/plan.md -> "Task 12: `finish-gate.ps1` (PreToolUse · Skill)"]
- `tester-write-guard.ps1` — tester 에이전트 frontmatter의 PreToolUse(`Edit|Write|MultiEdit|NotebookEdit`). `GetFullPath` 정규화 후 저장소 포함 검사(`root/` 접두 필수) + 화이트리스트 glob(`tests/**`, `e2e/**`, `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`)만 허용. [Source: specs/001-claude-setup/plan.md -> "Task 13: `tester-write-guard.ps1` (tester 에이전트 PreToolUse)"] [Source: specs/001-claude-setup/spec.md -> "**훅 I/O 계약**"]

**스킬 2종 (`.claude/skills/`, 프로젝트 소유)**
- `approval-review` — `SKILL.md` + `boundaries/{security,tenant-data,operability,trends,spec-consistency}.md`. 활성 feature 해석 → 기계 입력 수집 → 경계마다 서브에이전트 병렬 디스패치(프롬프트 = 경계 체크리스트 + spec/plan/tasks 관련 절만) → `reviews/YYYY-MM-DD-approval.md`(경계별 절 + `## 종합 의견` + `## 사용자 결정`) → 사용자 확정 질문 → `**Status**: Approved (날짜)`. [Source: specs/001-claude-setup/plan.md -> "Task 17: `/approval-review` 스킬 + 경계 5종 + 미러"] [Source: specs/001-claude-setup/spec.md -> "**approval-review 스킬**"]
- `finish` — `SKILL.md` + `boundaries/{report-vs-diff,e2e-evidence,study-contract,decisions}.md`. `report.md`(`# Report NNN-slug` / Summary / Changes Made / Validation / Next) → 학습 노트 초안 → CHANGELOG → Decisions → 한국어 미러(best-effort) → 경계 4 리뷰 병렬 → `reviews/YYYY-MM-DD-finish.md`(`Status: Approved | Issues`) → 인계. [Source: specs/001-claude-setup/plan.md -> "Task 18: `/finish` 스킬 + 경계 4종 + 미러"] [Source: specs/001-claude-setup/spec.md -> "**finish 스킬**"]

**생성 스킬 17종 (`.claude/skills/speckit-*/`, 무수정)** — 핵심 10 + git 5 + `speckit-agent-context-update` + `speckit-archive-run`. 모두 `settings.json` `skillOverrides`로만 통제한다(D13). [Source: specs/001-claude-setup/report.md -> "### Claude 레이어 (`.claude/`, 36)"] [Source: specs/001-claude-setup/report.md -> "SC-001 PASS"]

**에이전트 (`.claude/agents/tester.md`)** — `tools: Read, Grep, Glob, Bash, Edit, Write`; frontmatter `hooks.PreToolUse`로 `tester-write-guard.ps1`(timeout 5). 역할: 활성 feature의 User Story를 실제 사용자 관점으로 E2E 실행, 테스트 파일만 작성, 프로덕션 코드 금지, mock 최소; 보고 `## E2E Report — <feature>`(시나리오별 PASS/FAIL/SKIP, 재현 절차, 심각도, `### Failures`, `### Tests written`). 환경 부재는 SKIP + 사유. [Source: specs/001-claude-setup/plan.md -> "Task 15: `tester` 에이전트 + 한국어 미러"] [Source: specs/001-claude-setup/spec.md -> "**tester.md**"] [Source: specs/001-claude-setup/spec.md -> "D10"]

**규칙 3종 (`.claude/rules/`, `paths:` frontmatter로 경로 스코프)**
- `specs.md`(`specs/**`) — feature 디렉터리 불변, `**Status**` 값 `Draft → Approved (YYYY-MM-DD) → Done (YYYY-MM-DD)`(Approved는 `/approval-review`가 사람 확정 후, Done은 머지 후 archive 단계만), reviews/report 형식, `specs/README.md` 재생성 규칙, 승인 후 spec/plan/tasks read-only(예외: tasks 체크박스, converge가 덧붙인 phase), 서브에이전트 슬라이스 규칙.
- `docs.md`(`docs/**`) — `docs/README.md` 인덱스 필수 등재, `docs/decisions/NNNN-<kebab-title>.md` MADR 4.0 minimal(번호 재사용 금지, 변경은 supersede), `docs/kr/` 미러 경로 규칙(`.claude/rules/`·`.claude/agents/` 안에는 번역본 금지, 미동기 시 `> translation-pending (YYYY-MM-DD)` 표시, 미동기가 finish를 막지 않음), `docs/runbooks/` + 커스터마이즈 레지스터.
- `content.md`(`content/**`) — `content/study/<NNN-slug>.mdx` frontmatter 계약(`title, description, pubDate, updatedDate?, tags, series?, seriesOrder?, draft, change, sources`), 본문 절 순서(`## 문제` / `## 배운 개념` / `## 선택과 대안` / `## 결과와 검증` / `## 다음 학습`, 모두 비어 있지 않음), 비밀·개인정보 금지.
[Source: specs/001-claude-setup/plan.md -> "Task 16: 경로 규칙 3종 + 한국어 미러"] [Source: specs/001-claude-setup/spec.md -> "**rules**"]

**Spec Kit 커스터마이즈**
- `.specify/templates/overrides/tasks-template.md` — 각 User Story phase에 `### Tests for User Story N (MANDATORY — write first, verify they FAIL)` 절과 `### E2E for User Story N (MANDATORY — executed by the tester agent)` task를 둔다; `resolve-template.ps1 tasks-template` 출력에 `MANDATORY` ≥ 7, `OPTIONAL` 0. [Source: specs/001-claude-setup/plan.md -> "Task 8: `tasks-template.md` override — 테스트 필수화 + 스토리별 E2E task"] [Source: specs/001-claude-setup/spec.md -> "**tasks-template override**"]
- `.specify/memory/constitution.md` — JoshuaTech v2 헌법 1.0.0(영어): 6원칙(Spec-First, Test-First(NON-NEGOTIABLE), Tenant Boundary, Observability-Ready, Simplicity, Learning-in-Public) + Platform Constraints + Development Workflow & Quality Gates + Governance(SemVer, 개정은 `/speckit-constitution`). 미러 `docs/kr/constitution_kr.md`. [Source: specs/001-claude-setup/plan.md -> "Task 9: 프로젝트 헌법 (EN) + 한국어 미러"] [Source: specs/001-claude-setup/spec.md -> "**constitution (EN)**"]
- `.specify/extensions/git/git-config.yml` — `commit_style: conventional`. [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"]

**문서·인덱스**
- `CLAUDE.md`(영어, 60줄; `@AGENTS.md` import, Prerequisites / Tool boundaries / Lifecycle / Active feature resolution / 훅·스킬·에이전트 표 / Language / Documentation index / `<!-- SPECKIT START/END -->` 관리 블록) + `docs/kr/CLAUDE_kr.md`. [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"] [Source: specs/001-claude-setup/report.md -> "SC-004 PASS"]
- `AGENTS.md`(영어; 도구 중립 브리프 — Project / Active agent integration / Commands / Layout / Conventions / Workflow) + `docs/kr/AGENTS_kr.md`. [Source: specs/001-claude-setup/plan.md -> "Task 19: `AGENTS.md` (EN) + 미러"]
- `docs/README.md`(문서 인덱스), `docs/decisions/0000-use-madr.md`, `docs/decisions/0001-adopt-spec-kit-with-superpowers.md`, `docs/runbooks/spec-kit-upgrade.md`(커스터마이즈 레지스터 + 업그레이드·롤백 절차), `CHANGELOG.md`(Keep a Changelog 1.1.0), `README.md`, `specs/README.md`(feature 인덱스). [Source: specs/001-claude-setup/plan.md -> "Task 21: 문서 인덱스·ADR·업그레이드 런북·CHANGELOG·README·feature 인덱스"]
- 한국어 미러 9종: `docs/kr/{CLAUDE,AGENTS,constitution}_kr.md`, `docs/kr/agents/tester_kr.md`, `docs/kr/skills/{approval-review,finish}_kr.md`, `docs/kr/rules/{specs,docs,content}_kr.md` — 절 구조·표·코드 블록·식별자·제목은 원본과 동일, 산문만 번역. [Source: specs/001-claude-setup/plan.md -> "## 작업 규칙"] [Source: specs/001-claude-setup/report.md -> "SC-005 PASS"]
- 학습 노트: `content/study/001-claude-setup.mdx`, `content/study/002-smoke.mdx`(draft). [Source: specs/001-claude-setup/plan.md -> "Task 22: 첫 학습 노트 `content/study/001-claude-setup.mdx`"] [Source: specs/001-claude-setup/report.md -> "### 저장소 루트·문서"]

**테스트·스크립트**
- `tests/hooks/run-hook-tests.ps1` — 훅 하네스 23 케이스(approval 3, finish-gate 12, guard 8); 임시 git 저장소 픽스처(`try/finally` 정리), 모든 단언이 exit code를 검사. [Source: specs/001-claude-setup/plan.md -> "Task 10: 훅 단위 테스트 하네스 (RED)"] [Source: specs/001-claude-setup/report.md -> "SC-002 PASS"]
- `tests/run-all.ps1` — 저장소 검사 11절(12 Check). [Source: specs/001-claude-setup/plan.md -> "Task 23: `tests/run-all.ps1` — 저장소 전체 검사"] [Source: specs/001-claude-setup/report.md -> "### specs·tests"]
- `scripts/update-specs-index.ps1` + `tests/scripts/update-specs-index.tests.ps1` — 002-smoke 산출: 각 `specs/NNN-slug/spec.md` 헤더(H1, `**Status**`)에서 `specs/README.md` 표를 재생성(Status 값은 괄호 안 첫 쉼표 이후 주석을 제거해 정규화). [Source: specs/001-claude-setup/plan.md -> "Task 25: `002-smoke` — 전체 사이클 실주행 (SC-003)"] [Source: specs/001-claude-setup/report.md -> "### 저장소 루트·문서"]

## Project Structure

### Source Code (repository root)

현재 상태(001 + 002 머지 후). 범례: `[SK]` Spec Kit init · `[EXT]` 확장 설치 · `[P]` 프로젝트 작성 · `[RT]` 런타임 생성 · `[GI]` gitignore. [Source: specs/001-claude-setup/spec.md -> "### 2. 디렉터리 구조 (SP-0 완료 시점)"] [Source: specs/001-claude-setup/report.md -> "## Changes Made"]

```text
joshuatech_ver2/
├── AGENTS.md  CLAUDE.md  CHANGELOG.md  README.md  .gitignore  .gitattributes        [P]
├── .specify/
│   ├── memory/constitution.md [SK→P]  · memory/{spec,plan,changelog}.md [RT, archive]
│   ├── templates/{spec,plan,tasks,checklist,constitution}-template.md [SK]
│   ├── templates/overrides/tasks-template.md [P]
│   ├── scripts/powershell/{check-prerequisites,common,create-new-feature,resolve-template,setup-plan,setup-tasks}.ps1 [SK]
│   ├── extensions/{git,agent-context,archive}/ · extensions.yml · extensions/.registry [EXT]
│   ├── workflows/speckit/workflow.yml · workflows/workflow-registry.json [SK]
│   ├── integrations/{claude,speckit}.manifest.json · integration.json · init-options.json · .gitignore [SK]
│   └── feature.json [RT][GI]
├── .claude/
│   ├── settings.json [P] · settings.local.json [RT][GI]
│   ├── skills/speckit-*/ (17) [SK,EXT]
│   ├── skills/approval-review/{SKILL.md,boundaries/{security,tenant-data,operability,trends,spec-consistency}.md} [P]
│   ├── skills/finish/{SKILL.md,boundaries/{report-vs-diff,e2e-evidence,study-contract,decisions}.md} [P]
│   ├── agents/tester.md [P]
│   ├── rules/{specs,docs,content}.md [P]
│   └── hooks/{approval-review,finish-gate,tester-write-guard}.ps1 [P]
├── specs/
│   ├── README.md [P, scripts/update-specs-index.ps1로 재생성]
│   ├── 001-claude-setup/{spec.md,plan.md,report.md,research/,reviews/} [P]
│   ├── 002-smoke/{spec,plan,tasks,research,data-model,quickstart,report}.md · contracts/cli.md · checklists/ · reviews/ [SK+P]
│   └── NNN-slug/ (이후 feature: Spec Kit 산출 + reviews/ report.md)
├── scripts/update-specs-index.ps1 [P, 002]
├── tests/
│   ├── run-all.ps1 · hooks/run-hook-tests.ps1 [P]
│   └── scripts/update-specs-index.tests.ps1 [P, 002]
├── docs/
│   ├── README.md · decisions/{0000-use-madr,0001-adopt-spec-kit-with-superpowers}.md · runbooks/spec-kit-upgrade.md [P]
│   └── kr/{CLAUDE,AGENTS,constitution}_kr.md · kr/agents/tester_kr.md · kr/skills/{approval-review,finish}_kr.md · kr/rules/{specs,docs,content}_kr.md [P]
├── content/study/{001-claude-setup,002-smoke}.mdx [P/RT]
└── .worktrees/ .superpowers/ [RT][GI]
```

**Structure Decision**: 단일 저장소, 애플리케이션 소스 디렉터리 없음. `.specify/`는 Spec Kit 런타임(관리 파일은 `integrations/*.manifest.json`으로 추적, 프로젝트 변경은 `templates/overrides/`와 레지스터에만), `.claude/`는 Claude 게이트 레이어, `specs/`는 feature별 불변 이력, `docs/`·`content/`는 사람용 문서와 학습 콘텐츠, `tests/`·`scripts/`는 저장소 검사와 유틸리티다. `specs/` 경로는 Spec Kit 명령 템플릿에 하드코딩되어 이름을 바꾸지 않는다. 도메인 코드가 생기면 `.claude/rules/<domain>.md`, `.claude/agents/<domain>-builder.md`, `apps/<app>/CLAUDE.md` 패턴으로 확장한다. [Source: specs/001-claude-setup/plan.md -> "## Layout"] [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"] [Source: specs/001-claude-setup/spec.md -> "### 8. 확장 경로 (SP-1 이후)"]

## Workflow & Lifecycle

1. 착수: `/speckit-specify "<설명>"`(git 확장 `before_specify`가 브랜치 `NNN-slug` 생성) → 모호하면 `/speckit-clarify`(≤5문항). 아키텍처급 작업은 superpowers brainstorming → `create-new-feature.ps1 -ShortName <slug> -Json` → `spec.md`(spec-template 형식). 선택: `/speckit-assess-*`(Tier 2).
2. 계획: `/speckit-plan`(Constitution Check; agent-context `after_plan`이 CLAUDE.md SPECKIT 블록 갱신) → `/speckit-checklist` → `/speckit-tasks`(override 템플릿의 MANDATORY가 생성 스킬 프롬프트의 "tests optional"보다 우선).
3. 승인: 사용자가 "승인"하면 approval-review 훅이 `/approval-review` 선행을 지시 → 경계 5개 병렬 리뷰 → `reviews/*-approval.md` → 사용자 확정 후에만 `**Status**: Approved`.
4. 구현: superpowers subagent-driven-development가 `tasks.md` 실행 — implementer(TDD) → spec-reviewer → quality-reviewer → task당 커밋, `[X]` 체크.
5. 수렴: `/speckit-converge`가 Converged를 보고할 때까지(갭 task → 재실행).
6. 검증: `tester` 에이전트 디스패치(feature 디렉터리, spec의 User Scenarios 절, 테스트 명령) → User Story별 PASS/FAIL/SKIP; FAIL은 SDD 루프 복귀.
7. 마감: `/finish` → `superpowers:finishing-a-development-branch`(finish-gate 훅이 마감 산출물 없으면 deny).
8. 머지 후: `/speckit-archive-run specs/<NNN-slug>` → `.specify/memory/` 통합 → spec Status `Done` → `specs/README.md` 재생성.
[Source: specs/001-claude-setup/plan.md -> "## Lifecycle"] [Source: specs/001-claude-setup/spec.md -> "### 3. 워크플로우 — 전체 킷 배치"] [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]

- 게이트는 산출물 존재·경로 형태만 검사하므로 `finishing-a-development-branch` 밖의 수동 `git merge`/`gh pr merge`는 우회 가능 — 그 밖에서 머지하지 않는다. [Source: specs/001-claude-setup/report.md -> "## Next"]
- 브랜치 = feature 디렉터리 이름(`NNN-slug`), `main`은 통합 전용, worktree는 `.worktrees/` 아래. [Source: specs/001-claude-setup/plan.md -> "## Conventions"]
- 명령 배치: 핵심 `constitution / specify / clarify / plan / checklist / tasks / analyze(approval 경계로 사용) / converge / taskstoissues(원격 생기면)`; `implement` 미사용. 번들 확장 `git`·`agent-context`(SP-0), `assess`·`bug`(Tier 2). 커뮤니티 `archive`(SP-0), `adrkit`(Tier 2), `reconcile`/`security-review`/`review`/`pr-bridge`/`changelog`(Tier 2), `agent-assign`(SP-1 이후); 브릿지/worktree/tdd/branch-convention 확장과 프리셋 `lean`/`constitution-sync`는 미채택. [Source: specs/001-claude-setup/spec.md -> "### 3. 워크플로우 — 전체 킷 배치"]

## Configuration

- `.claude/settings.json` — `permissions.deny` 27개(Bash 16: `rm -rf *`, `rm -r*` 변형, `git reset --hard*`, `git * reset --hard*`, `git push --force*`/`-f*`, `git push * --force*`, `git clean -fd*`, `docker system prune*`, `docker * prune*` 등 + `PowerShell(...)` 11개 — 도구별 네임스페이스 분리); `hooks.UserPromptSubmit`에 `approval-review.ps1`(timeout 10), `hooks.PreToolUse` matcher `Skill`에 `finish-gate.ps1`(timeout 10); 훅 명령은 `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.ps1"`(cwd 변경에 견딤); `skillOverrides` 17개 전부 `name-only`(설명 숨김, 명시 호출·스킬 연쇄 호출 허용). `additionalDirectories` 없음. [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/report.md -> "### Claude 레이어 (`.claude/`, 36)"] [Source: specs/001-claude-setup/spec.md -> "**settings.json**"]
- `.claude/agents/tester.md` frontmatter — `hooks.PreToolUse[matcher "Edit|Write|MultiEdit|NotebookEdit"]` → `tester-write-guard.ps1`(timeout 5); 에이전트 안에서만 발화. [Source: specs/001-claude-setup/plan.md -> "Task 15: `tester` 에이전트 + 한국어 미러"]
- `.claude/rules/*.md` — `paths:` frontmatter(`specs/**`, `docs/**`, `content/**`)로 해당 경로 파일을 읽을 때만 로드. [Source: specs/001-claude-setup/plan.md -> "Task 16: 경로 규칙 3종 + 한국어 미러"]
- `.specify/extensions.yml` — `hooks: before_specify: speckit.git.feature`, `after_plan: speckit.agent-context.update`(after_plan은 선택 프롬프트). [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"] [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"]
- `.specify/extensions/git/git-config.yml` — `commit_style: conventional`, `auto_commit.default: false`(커밋은 SDD implementer가 task마다). [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"]
- `.specify/templates/overrides/tasks-template.md` — `resolve-template.ps1`이 최우선으로 해석. [Source: specs/001-claude-setup/plan.md -> "Task 8: `tasks-template.md` override — 테스트 필수화 + 스토리별 E2E task"]
- `CLAUDE.md` `<!-- SPECKIT START -->…<!-- SPECKIT END -->` — agent-context 확장이 관리(최신 plan 경로만 기록, 마커 밖 불변). [Source: specs/001-claude-setup/plan.md -> "## 커스터마이즈 레지스터"]
- `.gitattributes` — `* text=auto eol=lf`, `*.ps1/*.md/*.json/*.yml/*.yaml text eol=lf`, 이미지 `binary`(Windows 작업 복사본도 LF). [Source: specs/001-claude-setup/plan.md -> "Task 1: `.gitattributes`와 GitHub 원격"]
- `.gitignore` — `.specify/feature.json` 등; `.claude/settings.local.json`, `.worktrees/`, `.superpowers/`는 런타임 생성·gitignore. [Source: specs/001-claude-setup/report.md -> "### 저장소 루트·문서"] [Source: specs/001-claude-setup/spec.md -> "### 2. 디렉터리 구조 (SP-0 완료 시점)"]
- 환경 변수 — `SPECIFY_FEATURE_DIRECTORY`(활성 feature 최우선 소스; `create-new-feature.ps1`이 설정), `CLAUDE_PROJECT_DIR`(훅 경로 플레이스홀더). [Source: specs/001-claude-setup/spec.md -> "D12"] [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"] [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"]
- 저장소 밖(커밋 없음) — `~/.claude/settings.json` `enabledPlugins`: `superpowers@superpowers-dev: true`, `superpowers@claude-plugins-official: false`. [Source: specs/001-claude-setup/plan.md -> "Task 2: 사용자 레벨 superpowers 플러그인 단일화"] [Source: specs/001-claude-setup/report.md -> "### Task 24 — 새 세션 등록 확인 (2026-08-27)"]
- 커스터마이즈 레지스터(`docs/runbooks/spec-kit-upgrade.md`) — override 템플릿, 헌법, `git-config.yml`, `skillOverrides`, SPECKIT 블록, archive 확장 각각의 원본 버전·변경 이유·업그레이드 후 재검증 명령; 업그레이드는 `specify upgrade`(`--force` 금지) → `specify extension update` → 재검증 → run-all → CHANGELOG. [Source: specs/001-claude-setup/plan.md -> "## 커스터마이즈 레지스터"] [Source: specs/001-claude-setup/plan.md -> "## 업그레이드 절차"]

## Testing Strategy

- 단위: `tests/hooks/run-hook-tests.ps1` — 훅 3종에 stdin JSON을 넣어 stdout·exit code 검증, 외부 프레임워크 없음, finish-gate는 임시 git 저장소 픽스처로 브랜치·파일 상태 재현. 23 케이스(approval 3, finish-gate 12, guard 8) GREEN; "출력 없음 = allow" 단언도 `code -eq 0`을 함께 검사. [Source: specs/001-claude-setup/plan.md -> "Task 10: 훅 단위 테스트 하네스 (RED)"] [Source: specs/001-claude-setup/report.md -> "SC-002 PASS"] [Source: specs/001-claude-setup/spec.md -> "### 7. 테스트·검증 전략"]
- 저장소 검사: `tests/run-all.ps1` — 훅 하네스, CLAUDE.md ≤ 200줄, `settings.json` 파싱·`skillOverrides`가 모든 `speckit-*` 커버·훅 등록, kr 미러 9종 존재, 헌법 플레이스홀더 0, 정본 언어 헤더 9종, tasks 템플릿 override 활성(`MANDATORY` ≥ 7, `OPTIONAL` 0), 모든 feature 디렉터리가 `specs/README.md`에 등재 — 002 머지 후 12 Check ALL PASS(≈37초). [Source: specs/001-claude-setup/plan.md -> "Task 23: `tests/run-all.ps1` — 저장소 전체 검사"] [Source: specs/001-claude-setup/report.md -> "### Task 24 — 새 세션 등록 확인 (2026-08-27)"]
- 통합(세션 등록): 새 세션에서 `using-superpowers` 주입 1회, `specify check` 통과, 도구 목록에 `tester`·`approval-review`·`finish`·`speckit-*` 17개(name-only), 훅 UserPromptSubmit 1·PreToolUse(Skill) 1 — 2026-08-27 PASS. CLI 화면(`/hooks`·`/agents`·`/skills`)의 육안 확인은 사용자 몫. [Source: specs/001-claude-setup/report.md -> "### Task 24 — 새 세션 등록 확인 (2026-08-27)"]
- E2E(사이클): `002-smoke` 실주행 12 Step 전부 PASS(clarify는 마커 0으로 SKIP) — specify(브랜치 자동 생성) → plan/checklist/tasks(override 적용 확인) → 승인 훅 → `/approval-review`(analyze 6건 CRITICAL 0 + 경계 5 리뷰) → 게이트 부정 케이스(finish-gate deny 문구 일치) → SDD(RED→GREEN, task당 커밋) → converge 2회 → tester(US1 4·US2 3·US3 5·Edge 10 시나리오 PASS, FAIL/SKIP 0) → `/finish`(경계 4 리뷰 Approved) → finishing 게이트 통과 → 001로 fast-forward 머지 → run-all ALL PASS. [Source: specs/001-claude-setup/report.md -> "### Task 25 — `002-smoke` 전체 사이클 실주행 (SC-003)"]
- 스모크 대상 스크립트 테스트: `tests/scripts/update-specs-index.tests.ps1`(pwsh 단독 실행, exit 0/1). [Source: specs/001-claude-setup/plan.md -> "Task 25: `002-smoke` — 전체 사이클 실주행 (SC-003)"]
- 실행하지 않은 것: 001은 `tasks.md`가 없는 부트스트랩 예외라 `/speckit-converge` 불가(plan `## 자기 검토`의 FR/SC/US→task 전수 매핑으로 대체); US4 AC3(SKIP 보고)·AC4(FAIL→SDD 복귀)와 tester-write-guard의 세션 내 실제 deny는 002 E2E에서 발동하지 않음(하네스·오프라인 실행으로 대체). [Source: specs/001-claude-setup/report.md -> "### 실행하지 않은 것"]
- 테스트 파일 위치 규약: `tests/`, `e2e/`, `__tests__/` 또는 `*.test.*` / `*.spec.*`(tester-write-guard 화이트리스트와 동일). 테스트 선행은 헌법 II. [Source: specs/001-claude-setup/plan.md -> "## Conventions"]

## Error Handling

- 훅 공통: 입력 JSON 파싱 실패 → exit 0, 무출력(fail-open). 스크립트 예외도 exit 0. [Source: specs/001-claude-setup/spec.md -> "### 6. 에러 처리"] [Source: specs/001-claude-setup/plan.md -> "## 작업 규칙"]
- finish-gate: 2단계 구조 — 입력 파싱(1단계)만 fail-open, 게이트(2단계)는 예외·git 부재·깨진 `feature.json`·활성 feature 불일치·산출물 부재 모두 deny + `permissionDecisionReason`(모델에도 전달). [Source: specs/001-claude-setup/plan.md -> "Task 12: `finish-gate.ps1` (PreToolUse · Skill)"] [Source: specs/001-claude-setup/spec.md -> "**훅 I/O 계약**"]
- tester-write-guard: 같은 2단계 — 입력 파싱 fail-open / 경로 판정 fail-closed(저장소 밖·순회·접두 충돌·UNC는 deny). [Source: specs/001-claude-setup/plan.md -> "Task 13: `tester-write-guard.ps1` (tester 에이전트 PreToolUse)"]
- approval-review: 키워드 미매칭·오류 → 무출력(지시 주입만 하므로 오탐 비용 낮음). [Source: specs/001-claude-setup/plan.md -> "Task 11: `approval-review.ps1` (UserPromptSubmit)"] [Source: specs/001-claude-setup/spec.md -> "D15"]
- Tester: 환경 부재 → SKIP + 사유. FAIL → 컨트롤러가 SDD 루프 복귀(3회 넘으면 systematic-debugging). [Source: specs/001-claude-setup/spec.md -> "### 6. 에러 처리"]
- converge: 갭이 `unrequested`(요청 밖 구현)면 제거 task 또는 spec 개정을 사용자에게 묻는다. [Source: specs/001-claude-setup/spec.md -> "### 6. 에러 처리"]
- 확장 설치 실패: 기능을 수동 절차로 대체하고 `report.md` Validation에 기록(SP-0 완료를 막지 않음). [Source: specs/001-claude-setup/spec.md -> "### 6. 에러 처리"] [Source: specs/001-claude-setup/spec.md -> "## Assumptions"]
- Spec Kit 업그레이드 후: 런북 절차(`specify check` + `tests/run-all.ps1` + 레지스터 재검증); `skillOverrides`는 settings에 있어 영향 없음. 롤백은 이전 태그 재설치 후 브랜치 폐기. [Source: specs/001-claude-setup/spec.md -> "### 6. 에러 처리"] [Source: specs/001-claude-setup/plan.md -> "## 롤백"]
- 미러 동기화 실패는 finish를 막지 않는다(`> translation-pending (YYYY-MM-DD)` 표시). [Source: specs/001-claude-setup/plan.md -> "Task 16: 경로 규칙 3종 + 한국어 미러"]

## Known Issues & Gotchas

- superpowers 플러그인 2중 활성(`superpowers-dev` 5.1.0 + `claude-plugins-official` 6.x)은 같은 네임스페이스라 SessionStart 훅이 2중 주입된다 → official을 비활성화하고 정확히 1개만 켠다. [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 2. superpowers 5.1.0 규약"] [Source: specs/001-claude-setup/spec.md -> "D8"]
- `skillOverrides: user-invocable-only`는 모델의 모든 Skill 호출을 막아 스킬 연쇄(`speckit-specify` → `speckit-git-feature`)와 컨트롤러 호출까지 차단한다 → `name-only`(설명만 숨김)를 쓴다. [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/report.md -> "## Summary"]
- 훅 경로를 상대 경로로 등록하면 세션 cwd 변경에 깨진다 → `${CLAUDE_PROJECT_DIR}` 플레이스홀더; 명령에서는 `git -C`·절대 경로 선호. [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]
- 훅 하네스에서 "출력 없음 = allow" 단언이 exit code를 검사하지 않으면 훅 크래시가 PASS로 위장된다 → 모든 단언에 `$r.code -eq 0`, 픽스처는 `try/finally`로 삭제, 잔류 `SPECIFY_FEATURE_DIRECTORY` 초기화. [Source: specs/001-claude-setup/plan.md -> "Task 10: 훅 단위 테스트 하네스 (RED)"]
- tester-write-guard 우회 3건(`tests/../src` 순회, 저장소 접두 충돌 `…ver2tests\`, 저장소 밖 UNC 경로의 `*.test.*`) → `GetFullPath` 정규화 후 `root/` 접두 필수 검사. [Source: specs/001-claude-setup/plan.md -> "Task 13: `tester-write-guard.ps1` (tester 에이전트 PreToolUse)"]
- `.specify/feature.json`이 브랜치와 어긋나면 finish-gate가 deny한다(예: 002 머지 후 001로 돌아올 때) → `feature.json`을 제거해 브랜치 해석으로 돌린다; feature.json 단독 해석은 허용하지 않는다. [Source: specs/001-claude-setup/plan.md -> "Task 26: 001 마감 — finish → finishing → main 머지 → push → archive → Done"] [Source: specs/001-claude-setup/report.md -> "## Next"]
- `.claude/agents/`와 `.claude/rules/` 안의 모든 `.md`는 자동 로드(등록)된다 → 번역본·미러는 `docs/kr/`에 둔다. [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 1. Claude Code 프로젝트 설정 표면"] [Source: specs/001-claude-setup/spec.md -> "D9"]
- Spec Kit 명령 프롬프트는 회당 7~22KB이고 스킬 자동 트리거는 세션 이탈을 일으킨다 → 명시 호출만, clarify/checklist는 필요할 때만. [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"] [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"]
- `create-new-feature.ps1`은 git 브랜치를 만들지 않는다(git 확장의 `before_specify`가 만든다); 번호는 `specs/` 최대 + 1. `specs/` 경로는 하드코딩이라 이름 변경 금지. [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"]
- Windows ExecutionPolicy RemoteSigned → 훅은 반드시 `-ExecutionPolicy Bypass`; Git `core.autocrlf` 경고 → `.gitattributes`로 LF 강제. [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"]
- `/speckit-tasks` 생성 스킬 프롬프트에는 "tests optional" 문구가 남아 있다 → override 템플릿의 MANDATORY가 우선한다는 규칙을 CLAUDE.md에 명시. [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]
- 미러 제목은 원본과 동일하게 유지해야 한다(제목 번역 금지) — run-all 검사가 아니라 규칙 준수 사항. [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]
- superpowers가 constitution을 무시할 수 있다 → CLAUDE.md에 원칙 포인터 + approval 경계에 spec-consistency(analyze) 포함. 5.1.0 SDD는 task당 리뷰어 2명이라 느리다 → 작은 동형 task는 하나로 묶는다. [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"]
- agent-context 확장은 python3 + PyYAML을 요구한다(개발기 Python 3.14.2 + PyYAML 6.0.3 충족). [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 3. Spec Kit 1.0.1 실체"] [Source: specs/001-claude-setup/plan.md -> "## 실행 전 확인 사항 (2026-08-26 실측)"]
- 게이트는 산출물 존재·경로 형태만 검사하고 출처(provenance)는 검사하지 않는다 → `finishing-a-development-branch` 밖의 수동 머지는 우회 가능. [Source: specs/001-claude-setup/report.md -> "## Next"]

## Known Deviations

계획 대비 실제 구현이 달라진 곳(모두 문서화된 결정).

- `selftest` 확장: 1.0.2 카탈로그에 없어 설치 제외 → `specify check` + `tests/run-all.ps1` + 매니페스트 diff로 대체; 카탈로그 등재 시 Tier 2. [Source: specs/001-claude-setup/plan.md -> "Task 5: 번들 확장 `git`·`agent-context`"] [Source: specs/001-claude-setup/plan.md -> "Task 24: selftest와 세션 등록 확인"]
- `adrkit` 확장: 검토는 통과했으나 요구 버전 `spec-kit >=0.13,<0.16` vs 설치 1.0.2로 설치 불가(npm `@adrkit/cli` 별도 필요, ADR 경로는 env `ADRKIT_DIR` 전용) → ADR은 MADR 수작성, adrkit은 Tier 2로 이월. [Source: specs/001-claude-setup/plan.md -> "Task 7: 커뮤니티 확장 `adrkit`"] [Source: specs/001-claude-setup/spec.md -> "D14"]
- `skillOverrides` 값: `user-invocable-only` → `name-only`(연쇄 호출 보존). [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/spec.md -> "D13"]
- settings.json deny: 계획 7개 → 27개(Bash 16 + PowerShell 11); approval 훅 timeout 5s → 10s; 훅 경로 상대 → `${CLAUDE_PROJECT_DIR}`. [Source: specs/001-claude-setup/plan.md -> "Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`"] [Source: specs/001-claude-setup/report.md -> "### Claude 레이어 (`.claude/`, 36)"]
- 훅 정본은 plan 코드 블록과 다르다(리뷰 반영): finish-gate 2단계 fail-open/fail-closed·`Status: Approved` 정확 일치·feature.json 단독 해석 불허·비어 있지 않은 report/study 요구; tester-write-guard `GetFullPath` 정규화; 하네스 13 → 23 케이스. [Source: specs/001-claude-setup/plan.md -> "Task 12: `finish-gate.ps1` (PreToolUse · Skill)"] [Source: specs/001-claude-setup/plan.md -> "Task 13: `tester-write-guard.ps1` (tester 에이전트 PreToolUse)"]
- archive 스킬의 실제 이름은 `/speckit-archive-run specs/<NNN-slug>`(spec의 `/speckit-archive`는 예상 이름). [Source: specs/001-claude-setup/spec.md -> "## Assumptions"] [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]
- 001의 plan은 writing-plans 형식이며 `tasks.md`가 없다(FR-008 부트스트랩 예외) → `/speckit-converge` 미실행, 자기 검토 매핑으로 대체. 002부터는 `/speckit-plan` + `/speckit-tasks`. [Source: specs/001-claude-setup/plan.md -> "**Plan 위치 규칙:**"] [Source: specs/001-claude-setup/report.md -> "### 실행하지 않은 것"]
- ADR 0002(CI/CD 원칙)는 SP-0에서 만들지 않고 SP-1에서 런타임 트랙과 함께 작성(사용자 결정 2026-08-27). `research/2026-08-26-cicd-policy-{external,review}.md`는 채택되지 않은 참고 자료로만 001에 보존. [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 6. 외부 자문: CI/CD 정책"] [Source: specs/001-claude-setup/report.md -> "## Summary"]
- Task 14·20·21·23은 병렬 구현 후 컨트롤러가 커밋(task당 커밋 원칙의 배치 예외). [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"]

## Future Work

- 001 마감 잔여(Task 26 Step 3–6): `finishing-a-development-branch` 옵션 1(main 머지) → `git push origin main` → 원격 `001-claude-setup` 삭제 → `/speckit-archive-run` 001·002 → 두 spec Status `Done (2026-08-27)` → `scripts/update-specs-index.ps1` → run-all → 커밋·push. [Source: specs/001-claude-setup/report.md -> "## Next"] [Source: specs/001-claude-setup/plan.md -> "Task 26: 001 마감 — finish → finishing → main 머지 → push → archive → Done"]
- SP-1: 스택 결정(Cloudflare 네이티브 / Python MSA / 하이브리드; `assess → brainstorming → specify`), 도메인 규칙·에이전트; ADR 0002(CI/CD 원칙 — 불변 아티팩트·Git 정본·pull 기반·CI 무자격증명·rollback=revert)를 런타임 트랙과 함께 작성. 연구 입력: `research/2026-08-26-cicd-policy-review.md` §7 순서(테넌시 할당 확인 → repo 공개 여부 → 런타임 트랙 → web 호스팅 → DB). [Source: specs/001-claude-setup/report.md -> "## Next"] [Source: specs/001-claude-setup/spec.md -> "### 9. 서브 프로젝트 분해 (로드맵)"] [Source: specs/001-claude-setup/research/2026-08-26-research-summary.md -> "## 6. 외부 자문: CI/CD 정책"]
- 이월(Tier 2): `adrkit`(spec-kit 버전 게이트 해제 시), `selftest`(카탈로그 등재 시), `assess`·`bug` 번들 확장, `reconcile`/`security-review`/`review`/`pr-bridge`/`changelog` 커뮤니티 확장, 워크플로우 엔진 오버레이. [Source: specs/001-claude-setup/report.md -> "## Next"] [Source: specs/001-claude-setup/spec.md -> "### 3. 워크플로우 — 전체 킷 배치"]
- 테스트 도구: PSScriptAnalyzer 도입; run-all ≈37초(하네스 자식 pwsh 21회) → `-Quick` 분리 검토. [Source: specs/001-claude-setup/report.md -> "## Next"]
- 002 Next 이월: `contracts/cli.md` 문구(읽기 전용 메시지·정렬 문구), AGENTS.md Layout에 `scripts/` 추가, T018 힌트 문구, pwsh 7.6.5 하한을 CLAUDE.md Prerequisites에 기재할지. [Source: specs/001-claude-setup/report.md -> "## Next"]
- 확장 경로(SP-1 이후): 스택 결정 시 `.claude/rules/<domain>.md`(paths)·`.claude/agents/<domain>-builder.md`(skills 프리로드)·`boundaries/<domain>.md`·`apps/<app>/CLAUDE.md`·`settings.json` allow 목록; 서비스 증가 시 `agent-assign` 확장·`.specify/workflows/overlays/`·`security-review`/`review`·프로젝트 로컬 플러그인화(`.claude-plugin/`); 운영 시작 시 `docs/runbooks/`·`pr-bridge`·`changelog`·`taskstoissues`·3단 브랜치 승격(develop/release/main); 병렬 에이전트(Orca 등) 도입 시 `docs/runbooks/parallel-agents.md`와 `.worktrees/` 정합, 비-Claude 에이전트는 AGENTS.md + CI로 통제; 최소 CI `.github/workflows/ci.yml`(훅 단위 테스트·마크다운 린트·CLAUDE.md 200줄 검사) + main 보호 규칙; `.specify/memory/product.md`·`architecture.md`를 SP-1 산출물로 승격. [Source: specs/001-claude-setup/spec.md -> "### 8. 확장 경로 (SP-1 이후)"] [Source: specs/001-claude-setup/spec.md -> "D16"]
- 로드맵: SP-2 사이트 코어(포트폴리오·블로그·study 콘텐츠 컬렉션), SP-3 플랫폼·운영(인증·테넌트 경계·관측·CI/CD 승격·런북), SP-4+ 인터랙티브 서비스·멀티테넌트(B) 전환. [Source: specs/001-claude-setup/spec.md -> "### 9. 서브 프로젝트 분해 (로드맵)"]
- Linux 개발기가 생기면 훅 `.sh` 변형 추가. [Source: specs/001-claude-setup/spec.md -> "## Assumptions"]

## Risks

| 리스크 | 대응 | 출처 |
|---|---|---|
| Spec Kit 명령 프롬프트가 크다(7~22KB/회) | 명시 호출만(`skillOverrides: name-only`), clarify/checklist는 필요할 때만 | [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"] |
| superpowers가 constitution을 무시 | CLAUDE.md에 원칙 포인터 + approval 경계에 spec-consistency(analyze) 포함 | [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"] |
| approval 훅은 프롬프트 준수에 의존 | finish-gate·tester-write-guard는 결정적(파일·경로 검사) | [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"] |
| 확장이 서드파티(archive, adrkit) | 아카이브 URL 다운로드 후 위험 패턴 검토 뒤 설치, 실패 시 수동 절차 | [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"] [Source: specs/001-claude-setup/plan.md -> "Task 6: 커뮤니티 확장 `archive` (검토 후 설치)"] |
| 5.1.0 SDD 리뷰어 2명으로 느림 | 작은 동형 task는 하나로 묶어 `tasks.md` 작성 | [Source: specs/001-claude-setup/spec.md -> "### 10. 리스크"] |
| 게이트는 산출물 존재·경로 형태만 검사 — 수동 `git merge`/`gh pr merge`로 우회 가능 | `finishing-a-development-branch` 밖에서 머지하지 않는다(CLAUDE.md 명시) | [Source: specs/001-claude-setup/report.md -> "## Next"] |
| `feature.json`이 브랜치와 어긋나면 finish-gate deny | 체크아웃별 편의 파일로 취급, 어긋나면 제거 후 브랜치 해석 | [Source: specs/001-claude-setup/report.md -> "## Next"] |
| Spec Kit 업그레이드가 관리 파일을 덮음 | `specify upgrade`에 `--force` 금지, 레지스터 재검증, 매니페스트 diff, 롤백 절차 | [Source: specs/001-claude-setup/plan.md -> "## 업그레이드 절차"] |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| 001 plan이 Spec Kit plan/tasks 형식이 아닌 superpowers writing-plans 형식이며 `tasks.md`가 없다(FR-008 부트스트랩 예외; `/speckit-converge` 미실행) | Spec Kit 설치 전에 작성된 최초 feature — Spec Kit 산출물을 만들 도구가 아직 없었다 | 설치 후 재작성은 순환 의존이고 이력 가치가 없음; 002부터 `/speckit-plan` + `/speckit-tasks`가 정본. [Source: specs/001-claude-setup/plan.md -> "**Plan 위치 규칙:**"] [Source: specs/001-claude-setup/report.md -> "### 실행하지 않은 것"] |
| Task 14·20·21·23을 병렬 구현 후 컨트롤러가 일괄 커밋(task당 커밋 원칙 예외) | 독립 문서·설정 task를 병렬로 처리해 시간 단축 | 순차 커밋은 병렬 서브에이전트 산출물과 충돌 관리 비용이 큼. [Source: specs/001-claude-setup/plan.md -> "Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러"] |
| 훅이 PowerShell 단일 스크립트(`.sh` 변형 없음) | 개발기가 Windows 11 + pwsh 단일 환경(1인 개발) | 이중 유지보수는 현재 불필요; Linux 개발기가 생기면 추가. [Source: specs/001-claude-setup/spec.md -> "## Assumptions"] |
