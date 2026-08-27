> translation-pending (2026-08-26): Prerequisites·Tool boundaries 3개 항목(훅 경로 플레이스홀더, skillOverrides name-only, cwd 주의) 갱신 필요.
> 번역본(편의용). 정본은 영어 원본 `CLAUDE.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

> (정본은 `AGENTS.md`를 import한다)

# CLAUDE.md — how Claude works in this repository

## Prerequisites
- superpowers 플러그인은 사용자 레벨에서 정확히 하나만 활성화한다: `superpowers@superpowers-dev` (5.1.0). `superpowers@claude-plugins-official`은 비활성 상태로 유지한다(SessionStart 훅을 이중으로 주입하기 때문).
- Spec Kit CLI(`specify`, `uv`로 설치, `~/.local/bin`)는 초기화, 업그레이드, 확장 관리에만 필요하다; 일상적인 명령에는 `.specify/scripts/powershell/*.ps1`을 사용한다.
- 훅은 `pwsh -NoProfile -ExecutionPolicy Bypass -File …`로 실행된다; PowerShell 7이 PATH에 있어야 한다.

## Tool boundaries
- **Spec Kit owns WHAT**: constitution, `specs/NNN-slug/{spec,plan,tasks,research,…}`, analyze, converge, archive. `speckit-*` 스킬은 사용자가 직접 호출하는 용도로만 존재한다(설정 `skillOverrides`); 항상 명시적으로 호출하고 추측으로 사용하지 않는다.
- **superpowers owns HOW**: brainstorming(아키텍처 수준 인테이크에만), test-driven-development, subagent-driven-development, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, systematic-debugging, verification-before-completion.
- **This repository owns the gates**: `tester` 에이전트, `/approval-review`, `/finish`, 그리고 `.claude/hooks/`의 훅들.
- `speckit-implement`는 사용하지 않는다; superpowers subagent-driven-development가 `tasks.md`를 실행한다.
- superpowers `writing-plans`는 사용하지 않는다; `tasks.md`가 유일한 구현 계획이다(유일한 예외는 `specs/001-claude-setup/plan.md`였다).
- brainstorming을 사용하는 경우, 설계 결과는 Spec Kit spec-template 형식으로 `specs/NNN-slug/spec.md`에 저장한다: `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json`을 실행해 디렉터리를 할당하고, 그 `spec.md`를 채운 다음 `/speckit-plan`으로 이어간다.
- 서브에이전트에는 태스크 단위와 관련 섹션만 전달한다 — spec이나 plan 파일 전체를 전달하지 않는다.
- 계획 전에는 `.specify/memory/constitution.md`를, 아키텍처 변경 전에는 `docs/decisions/`를 읽는다.

## Lifecycle
1. 인테이크: `/speckit-specify "<description>"`(git 확장이 브랜치 `NNN-slug`를 생성) → 모호한 경우 `/speckit-clarify`. 아키텍처 수준 작업: superpowers brainstorming → 위와 같이 spec.md.
2. 계획: `/speckit-plan` → `/speckit-checklist` → `/speckit-tasks`.
3. 승인: 사용자가 승인하면 먼저 `/approval-review`를 실행한다; 사용자가 확인한 뒤에만 `**Status**: Approved`로 설정한다.
4. 빌드: `tasks.md`에 대해 superpowers subagent-driven-development를 수행한다(TDD, 태스크별 리뷰, 태스크당 커밋 하나, `[X]` 체크).
5. 수렴: `/speckit-converge`가 Converged를 보고할 때까지 반복한다.
6. 검증: 기능 디렉터리, spec의 User Scenarios 섹션, 테스트 명령을 전달해 `tester` 에이전트를 파견한다.
7. 마무리: `/finish`를 실행한 뒤, 기능 브랜치에서 `superpowers:finishing-a-development-branch`를 실행한다(finish-gate 훅이 finish 산출물이 존재할 때까지 이를 거부한다).
8. 병합 후: `/speckit-archive-run specs/<NNN-slug>`를 실행해 `.specify/memory/`가 병합된 기능을 반영하게 한다; spec의 Status를 Done으로 설정하고 `specs/README.md`를 재생성한다.

## Active feature resolution
`SPECIFY_FEATURE_DIRECTORY` → 현재 브랜치 `NNN-slug` ↔ `specs/<branch>/` → `.specify/feature.json`(일관성 검사 용도일 뿐, 그 자체로 기능을 확정하지 않는다). 출처들은 서로 일치해야 하며, 어느 것도 확정되지 않으면 질문한다. `feature.json`은 체크아웃별 편의 도구일 뿐 기록이 아니다; 기록은 git 브랜치와 `specs/<feature>/`이다.

## Project-owned hooks, skills, agents
| Item | Location | Role |
|---|---|---|
| approval-review hook | `.claude/hooks/approval-review.ps1` (UserPromptSubmit) | 승인 키워드가 감지되면 먼저 `/approval-review`를 실행하라고 안내한다 |
| finish-gate hook | `.claude/hooks/finish-gate.ps1` (PreToolUse, Skill) | 최신 finish 리뷰가 Approved이고 `report.md` + study note가 존재할 때까지 마무리를 거부한다 |
| tester-write-guard | `.claude/hooks/tester-write-guard.ps1` (tester PreToolUse) | tester는 저장소 내부의 테스트 경로에만 쓸 수 있다 |
| `/approval-review` | `.claude/skills/approval-review/` | 다섯 개의 경계 서브에이전트 → `reviews/*-approval.md` |
| `/finish` | `.claude/skills/finish/` | report, study note, CHANGELOG, 미러, 네 개의 경계 서브에이전트 → `reviews/*-finish.md` |
| `tester` | `.claude/agents/tester.md` | 사용자 스토리별 E2E, PASS/FAIL/SKIP 보고 |
| rules | `.claude/rules/{specs,docs,content}.md` | 경로 기반 형식과 계약 |

게이트는 산출물의 존재 여부와 경로 형태만 검사하며 출처(provenance)는 검사하지 않는다; 수동으로 하는 `git merge`/`gh pr merge`는 이를 우회한다 — `finishing-a-development-branch` 외의 방식으로는 병합하지 않는다. 훅 테스트: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1`. 전체 점검: `pwsh -NoProfile -File tests/run-all.ps1`.

## Language
에이전트 파일(이 파일, `AGENTS.md`, constitution, rules, agents, 프로젝트 스킬)은 영어로 작성하며 `docs/kr/`에 미러를 둔다. 대화, spec, plan, 보고서, 학습 노트, 코멘트는 한국어로 작성한다. 식별자, 슬러그, 파일명은 영어/ASCII를 사용한다.

## Documentation index
`docs/README.md`.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/002-smoke/plan.md
<!-- SPECKIT END -->
