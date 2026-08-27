> 번역본(편의용). 정본은 영어 원본 `CLAUDE.md`이며 충돌 시 영어가 우선한다. 동기화: /finish. (2026-08-27 재동기화)

> (정본은 `AGENTS.md`를 import한다)

# CLAUDE.md — how Claude works in this repository

## Prerequisites
- superpowers 플러그인은 사용자 레벨에서 정확히 하나만 활성화한다: `superpowers@superpowers-dev` (5.1.0). `superpowers@claude-plugins-official`은 비활성 상태로 유지한다(SessionStart 훅을 이중으로 주입하기 때문).
- Spec Kit CLI(`specify`, `uv`로 설치, `~/.local/bin`)는 초기화, 업그레이드, 확장 관리에만 필요하다; 일상적인 명령에는 `.specify/scripts/powershell/*.ps1`을 사용한다.
- 훅은 `pwsh -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PROJECT_DIR}/.claude/hooks/<name>.ps1"`로 실행된다(Windows에서 훅 셸은 Git Bash); PowerShell 7이 PATH에 있어야 한다.

## Tool boundaries
- **Spec Kit owns WHAT**: constitution, `specs/NNN-slug/{spec,plan,tasks,research,…}`, analyze, converge, archive. `speckit-*` 스킬은 이름만 노출된다(설정 `skillOverrides`: 설명을 숨겨 자동으로 발동하지 않게 함); 사용자가 요청하거나 아래 lifecycle 단계가 요구할 때만 호출하고 — 추측으로 사용하지 않는다.
- **superpowers owns HOW**: brainstorming(아키텍처 수준 인테이크에만), test-driven-development, subagent-driven-development, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, systematic-debugging, verification-before-completion.
- **This repository owns the gates**: `tester` 에이전트, `/approval-review`, `/finish`, 그리고 `.claude/hooks/`의 훅들.
- `speckit-implement`는 사용하지 않는다; superpowers subagent-driven-development가 `tasks.md`를 실행한다.
- superpowers `writing-plans`는 사용하지 않는다; `tasks.md`가 유일한 구현 계획이다(유일한 예외는 `specs/001-claude-setup/plan.md`였다).
- brainstorming을 사용하는 경우, 설계 결과는 Spec Kit spec-template 형식으로 `specs/NNN-slug/spec.md`에 저장한다: `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json`을 실행해 디렉터리를 할당하고, 그 `spec.md`를 채운 다음 `/speckit-plan`으로 이어간다.
- 서브에이전트에는 태스크 단위와 관련 섹션만 전달한다 — spec이나 plan 파일 전체를 전달하지 않는다.
- `/speckit-tasks`: 해석된 템플릿(`.specify/templates/overrides/tasks-template.md`)은 테스트가 MANDATORY라고 명시하며, 이것이 생성된 스킬 프롬프트의 "tests optional" 문구보다 우선한다. 모든 user story phase는 테스트 우선 task와 `tester`용 E2E task 하나를 갖는다.
- 훅은 `${CLAUDE_PROJECT_DIR}`로 스크립트를 찾으므로 `cd`에도 살아남는다; 그래도 명령의 상대 경로가 유효하도록 `cd`보다 `git -C`와 절대 경로를 선호한다.
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

## Active Technologies
- PowerShell 7.6.5(`pwsh`) — 훅·테스트·저장소 스크립트(`.claude/hooks/*.ps1`, `tests/**/*.ps1`, `scripts/*.ps1`)
- Spec Kit `specify` 1.0.2.dev0(통합 `claude`, 스크립트 `ps`) + 확장 git·agent-context·archive
- superpowers 5.1.0(`superpowers@superpowers-dev`, 유일하게 활성화된 superpowers 플러그인)
- 애플리케이션 스택은 아직 없음 — SP-1에서 결정

## Project Structure
레이아웃 표는 `AGENTS.md`(위에서 import). 그 이후 추가된 것: `scripts/`(`update-specs-index.ps1`), `tests/scripts/`(그 테스트와 픽스처), `specs/002-smoke/`.

## Commands
명령 표는 `AGENTS.md`. 머지된 feature 아카이브: `/speckit-archive-run specs/<NNN-slug>`.

## Recent Changes
- specs/001-claude-setup: SP-0 도구화 — Spec Kit + superpowers + 저장소 게이트(훅/스킬/tester/규칙/테스트), 문서 정책, 스모크 feature 002 머지

## Known Issues & Gotchas
### ⚠️ Two superpowers plugins enabled at once
**Issue:** SessionStart에 `using-superpowers`가 두 번 주입되고, 두 플러그인 버전이 하나의 네임스페이스를 두고 충돌했다.
**Root Cause:** `superpowers@superpowers-dev`(5.1.0)와 `superpowers@claude-plugins-official`(6.x)이 같은 플러그인 이름으로 각각 SessionStart 훅을 등록한다.
**Prevention Rule:** superpowers 플러그인은 정확히 하나(`superpowers@superpowers-dev`)만 활성화한다; 플러그인을 바꾼 뒤에는 `~/.claude/settings.json`의 `enabledPlugins`를 확인한다.

### ⚠️ `skillOverrides: user-invocable-only` breaks skill chaining
**Issue:** `/speckit-specify`가 `speckit-git-feature`를 호출하지 못했고, 컨트롤러도 override된 스킬을 하나도 호출할 수 없었다.
**Root Cause:** `user-invocable-only`는 자동 발동만이 아니라 모델 측 `Skill` 호출 전부를 막는다; `name-only`만이 설명을 숨기면서 호출은 가능하게 둔다.
**Prevention Rule:** 명시적으로만 써야 하는 스킬에는 `name-only`를 쓴다; 다른 스킬이나 컨트롤러가 호출하는 스킬에 `user-invocable-only`를 쓰지 않는다.

### ⚠️ adrkit does not install on Spec Kit 1.0.x
**Issue:** `specify extension add adrkit`이 실패한다; SP-0의 ADR은 MADR 형식으로 수작성했다.
**Root Cause:** adrkit 0.1.2는 `spec-kit >=0.13,<0.16`을 선언하고, 별도의 npm `@adrkit/cli`가 필요하며, ADR 경로를 `ADRKIT_DIR`에서만 읽는다.
**Prevention Rule:** 확장을 계획에 넣기 전에 `specify extension info <name>`으로 `spec-kit` 범위를 확인한다; adrkit은 게이트가 풀릴 때까지 Tier 2에 둔다.

### ⚠️ `.specify/feature.json` disagreeing with the branch
**Issue:** `feature.json`이 현재 `NNN-slug` 브랜치와 다른 feature를 가리키면(머지 직후가 전형적) finish-gate가 `finishing-a-development-branch`를 거부한다.
**Root Cause:** `feature.json`은 `create-new-feature.ps1`이 쓰는 gitignore된 체크아웃별 파일이라, 브랜치는 바뀌어도 이 파일은 바뀌지 않는다.
**Prevention Rule:** feature는 `SPECIFY_FEATURE_DIRECTORY` 또는 브랜치에서 해석하고 `feature.json`은 일관성 검사로만 취급한다; 머지 뒤에는 삭제한다.

### ⚠️ Hook tests that treat "no output" as allow
**Issue:** 훅이 크래시해도 하네스 단언 6개가 통과했다 — 크래시한 PreToolUse 훅도 아무것도 출력하지 않기 때문이다.
**Root Cause:** 단언이 종료 코드가 아니라 stdout만 검사했다; 경로 가드도 정규화 전에는 `tests/../src`와 저장소 접두 충돌을 허용했다.
**Prevention Rule:** 모든 "allow" 단언은 종료 코드 0과 빈 출력을 함께 요구한다; 가드는 `GetFullPath`로 정규화하고 `<root>/` 접두를 요구한다; 게이트 로직은 fail-closed, 입력 파싱만 fail-open.

<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
at specs/002-smoke/plan.md
<!-- SPECKIT END -->
