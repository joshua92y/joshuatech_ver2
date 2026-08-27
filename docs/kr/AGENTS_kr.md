> 번역본(편의용). 정본은 영어 원본 `AGENTS.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

# AGENTS.md — JoshuaTech v2

## Project
처음부터 다시 만든 개발자 포트폴리오 플랫폼(v1: `d:\code\joshuatech`). SaaS급 규율과 멀티테넌트 대응 가능한 경계를 갖추고 운영되며, 자신의 학습 노트를 직접 공개한다(learning in public). **현재 상태(SP-0): 툴링과 규약만 존재 — 애플리케이션 코드는 아직 없다. 스택은 SP-1에서 결정한다.**

## Active agent integration
Spec Kit 통합 대상은 `claude`뿐이다(`.claude/skills/speckit-*` 아래의 스킬). 다른 에이전트(Codex, Gemini 등)는 이 파일, `.specify/memory/constitution.md`, `specs/<feature>/`를 읽는다. 이들은 Claude 훅(hook)을 제공받지 못하므로 워크플로우를 수동으로 따라야 하며, 승인된 `spec.md`, `plan.md`, `tasks.md`를 절대 수정해서는 안 된다.

## Commands
| 목적 | 명령어 |
|---|---|
| 기능 디렉터리 할당(브레인스토밍 경로) | `pwsh .specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` |
| 기능 경로 / 사전 조건 | `pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json` |
| 훅(hook) 단위 테스트 | `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1` |
| 전체 저장소 점검 | `pwsh -NoProfile -File tests/run-all.ps1` |
| `specs/README.md` 재생성 | `pwsh -NoProfile -File scripts/update-specs-index.ps1` |
| Spec Kit CLI(초기화 / 업그레이드 / 확장) | `~/.local/bin`의 `specify`(`uv`로 설치); 절차는 `docs/runbooks/spec-kit-upgrade.md` |

## Layout
```
.specify/        Spec Kit 런타임: memory/constitution.md, templates/ (+overrides/), scripts/powershell/, extensions/, feature.json (로컬 전용)
.claude/         Claude 레이어: settings.json, skills/, agents/tester.md, rules/, hooks/
specs/           기능(NNN-slug)마다 하나씩 존재하는 불변 디렉터리 + README.md 색인
docs/            README.md 색인, decisions/ (MADR), runbooks/, kr/ (한국어 미러)
content/study/   사이트가 사용하는 학습 노트(.mdx)
tests/           훅 테스트 및 저장소 점검
```

## Conventions
- 브랜치 = 기능 디렉터리 이름(`NNN-slug`), Spec Kit git 확장이 생성; `main`은 통합 전용; 워크트리는 `.worktrees/` 아래에 둔다.
- 커밋: Conventional Commits, 한국어 설명 허용(`feat(scope): 설명`); 태스크당 커밋 하나; 강제 푸시나 공유 이력 재작성 금지.
- 파일: UTF-8, LF, ASCII kebab-case 이름. spec, docs, 노트에는 한국어 산문; 에이전트 파일과 코드 식별자에는 영어.
- 테스트 우선(constitution II). 테스트 파일은 `tests/`, `e2e/`, `__tests__/` 아래에 두거나 `*.test.*` / `*.spec.*`로 명명한다.
- 비밀 정보(secrets)는 저장소에 절대 포함하지 않는다.

## Workflow (short form)
specify → clarify → plan → checklist → tasks → approval-review → build (TDD, subagent-driven) → converge → E2E (tester) → finish → finishing branch → merge → archive. 세부 사항: `CLAUDE.md`와 constitution 참고.
