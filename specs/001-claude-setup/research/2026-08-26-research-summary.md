# SP-0 조사 요약 (2026-08-26)

브레인스토밍 중 서브에이전트 4건(Claude Code 설정 표면, docs 정책 동향, Spec Kit 저장소 실체, Spec Kit 생태계)의 조사 결과에서
구현에 필요한 사실만 추린 것이다. 원문은 세션 로그에만 있으므로 여기 없는 세부는 출처를 다시 확인한다.

## 1. Claude Code 프로젝트 설정 표면 (출처: https://code.claude.com/docs/en/{sub-agents,skills,hooks,memory,settings-reference,workflows,plugins}.md)

- `.claude/agents/*.md` frontmatter: `name, description, tools, disallowedTools, model, permissionMode, memory, skills, isolation, mcpServers, maxTurns, hooks`. 하위 디렉터리 불가(평면). `name` 있는 모든 .md가 서브에이전트로 등록됨 → 번역본을 여기 두면 안 됨.
- `.claude/skills/<name>/SKILL.md` frontmatter: `name, description, disable-model-invocation, allowed-tools, context, ...`. `disable-model-invocation: true` = `/name` 명시 호출만. `references/`, `scripts/` 하위 폴더 허용. 경로 스코프 스킬은 없음(경로 스코프는 rules).
- `.claude/commands/*.md`: 스킬로 통합(하위 호환). 신규는 skills 사용.
- 훅 이벤트: SessionStart, SessionEnd, UserPromptSubmit, Stop, StopFailure, PreToolUse, PostToolUse, FileChanged, CwdChanged, ConfigChange, Notification, SubagentStart, SubagentStop, InstructionsLoaded. matcher는 도구명/정규식(`Skill`, `Edit|Write`).
  - stdin JSON: `session_id, cwd, permission_mode, hook_event_name, prompt(UserPromptSubmit), tool_name, tool_input, tool_use_id`.
  - stdout JSON(exit 0): `{"systemMessage": "..."}`, `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow|deny|escalate", "permissionDecisionReason": "...", "additionalContext": "..."}}`. exit 2 = 무조건 차단(PreToolUse/UserPromptSubmit). 기타 exit = 비차단.
  - 명령은 단일 `command` 문자열(+선택 `shell` 필드). Windows는 `powershell -NoProfile -ExecutionPolicy Bypass -File ...`로 호출.
- `.claude/rules/*.md`: 재귀 로드. `paths: ["specs/**"]` frontmatter가 있으면 해당 파일을 읽을 때만 로드. 없으면 세션 시작 시 로드(CLAUDE.md처럼). 우선순위: managed → user → project.
- CLAUDE.md: `@path` import(최대 4단계), `CLAUDE.local.md`(gitignored), 하위 디렉터리 CLAUDE.md는 해당 경로 파일을 읽을 때 온디맨드 로드. 권장 200줄 이하. HTML 주석은 주입 전 제거(SPECKIT 마커는 토큰 0).
- `.claude/settings.json`: `permissions.{defaultMode,allow,ask,deny}` (`Bash(rm -rf *)` 형식), `additionalDirectories`, `env`, `model`, `hooks`. `settings.local.json`은 자동 gitignore.
- `.claude/workflows/*.js`: `export const meta = {...}` + `agent()/pipeline()/parallel()` 스크립트. `/workflows`에서 저장하면 `/workflow-name`.
- 프로젝트 로컬 플러그인: `.claude-plugin/plugin.json` + `skills/ agents/ hooks/ .mcp.json` (플러그인 루트에). `claude --plugin-dir ./my-plugin`으로 테스트.
- 자동 메모리: `~/.claude/projects/<project>/memory/MEMORY.md`(첫 200줄 로드) — CLAUDE.md와 별개.
- 추가 검증(2026-08-26, 외부 리뷰 대응): SKILL.md frontmatter도 `hooks`를 지원(스킬 호출 이후 세션 동안 활성 — 최초 트리거로는 부적합). 훅 핸들러 타입 `command`/`prompt`(안정)/`agent`(실험). UserPromptSubmit 훅의 stdout·`systemMessage`·`additionalContext`는 모두 모델 컨텍스트에 들어감(`systemMessage`는 사용자에게도 표시). PreToolUse deny의 `permissionDecisionReason`은 모델에 전달. **`settings.json`의 `skillOverrides: {"<skill>": "user-invocable-only"}`** 로 SKILL.md 수정 없이 명시 호출 전용화 가능. 프로젝트 훅은 서브에이전트 도구 호출에도 발화하며 입력에 `agent_id`/`agent_type` 포함.

## 2. superpowers 5.1.0 규약 (경로: `~/.claude/plugins/cache/superpowers-dev/superpowers/5.1.0/skills/`)

- 두 플러그인 동시 활성화됨: `superpowers@superpowers-dev`(5.1.0) + `superpowers@claude-plugins-official`(6.2.0/6.3.0). 같은 네임스페이스 → 5.1.0이 이김, SessionStart 훅 2중 주입. **결정: official 비활성화.**
- brainstorming: spec을 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`에 저장·커밋 — "User preferences for spec location override this default". 종착은 writing-plans 고정(CLAUDE.md로 오버라이드).
- writing-plans: `docs/superpowers/plans/YYYY-MM-DD-<feature>.md`, 오버라이드 가능. 헤더 Goal/Architecture/Tech Stack, task 5단계(RED/GREEN/커밋). 5.1.0엔 `Spec:` 헤더·Global Constraints 없음(6.3.0에 있음).
- subagent-driven-development(5.1.0): task마다 implementer(`implementer-prompt.md`) → spec-reviewer(`spec-reviewer-prompt.md`) → code-quality-reviewer(`code-quality-reviewer-prompt.md` → `requesting-code-review/code-reviewer.md`). implementer가 커밋. 전체 완료 후 최종 코드 리뷰 → finishing. 확장 훅 없음 → Tester 삽입은 CLAUDE.md 규칙(전체 task 완료 후, finishing 전).
- finishing-a-development-branch: 테스트 통과 필수, 4옵션(머지/PR/유지/discard). `.worktrees/` 정리. changelog는 어떤 스킬도 쓰지 않음(프로젝트 몫).
- using-git-worktrees: 네이티브 `EnterWorktree` 우선, `.worktrees/`는 gitignore 필수.
- 우선순위 명문화: CLAUDE.md > superpowers 스킬 > 기본 프롬프트.
- Windows: SessionStart 훅 PowerShell 이슈 이력(#1751 등) — 현재 사용자 환경에서는 동작 중.

## 3. Spec Kit 1.0.1 실체 (클론: scratchpad/spec-kit, HEAD 2026-08-25)

- 설치: `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` 또는 `uvx`. `specify init --here --integration claude --script ps [--non-interactive]`. `--ai`/`--no-git`은 폐지(`--integration`, git은 확장).
- Claude 생성물: `.claude/skills/speckit-<name>/SKILL.md` 10개(constitution, specify, clarify, plan, tasks, checklist, analyze, implement, converge, taskstoissues). frontmatter `name, description, argument-hint, compatibility, metadata, user-invocable: true, disable-model-invocation: false`. 확장 명령은 `speckit-<ext>-<cmd>` (예: `speckit-git-feature`, `speckit-agent-context-update`). CLAUDE.md·훅·서브에이전트 생성 안 함.
- `.specify/`: `memory/constitution.md`, `templates/{spec,plan,tasks,checklist,constitution}-template.md`, `templates/overrides/`(최우선), `scripts/powershell/{check-prerequisites,common,create-new-feature,resolve-template,setup-plan,setup-tasks}.ps1`, `workflows/speckit/workflow.yml`, `extensions/<id>/`(+ `<id>-config.yml`), `extensions.yml`(훅 등록), `feature.json`(gitignored, 활성 feature), `init-options.json`, `integrations/*.manifest.json`.
- 명령 프롬프트 크기: specify 345줄/18KB, clarify 291/19KB, plan 170/7.7KB, tasks 219/10.8KB, implement 222/12.4KB, analyze 255/11.4KB, checklist 379/22KB, constitution 177/9.8KB, converge 273/12.4KB. 모두 `/memory/constitution.md`를 읽음.
- 스크립트: `create-new-feature.ps1 -ShortName <slug> -Json [-Number N] [-Timestamp] [-DryRun]` → `specs/NNN-slug/spec.md` 생성 + feature.json 기록 + `$env:SPECIFY_FEATURE_DIRECTORY` 설정. **git 브랜치는 만들지 않음**(git 확장이 `before_specify`에서). 번호는 `specs/` 최대 + 1(`%03d`). `setup-plan.ps1 -Json`(plan.md 없을 때만 템플릿 복사), `setup-tasks.ps1 -Json`(plan·spec 필수), `check-prerequisites.ps1 -Json [-RequireTasks] [-IncludeTasks] [-PathsOnly]`. 런타임은 pwsh만 필요(프리셋 합성 시에만 Python).
- 템플릿 헤더: spec = `# Feature Specification: [NAME]` / `**Feature Branch**` / `**Created**` / `**Status**: Draft` / `**Input**` / `## User Scenarios & Testing *(mandatory)*`(User Story N (Priority: P1) + Why/Independent Test/Acceptance Scenarios Given-When-Then, Edge Cases) / `## Requirements *(mandatory)*`(FR-001, `[NEEDS CLARIFICATION]`, Key Entities) / `## Success Criteria *(mandatory)*`(SC-001) / `## Assumptions`. plan = Summary / Technical Context / Constitution Check(GATE) / Project Structure / Complexity Tracking. tasks = `[ID] [P?] [Story] Description`, Phase 1 Setup → 2 Foundational → 3+ User Story별(🎯 MVP) → Polish; "Tests OPTIONAL - only if explicitly requested"(→ override로 필수화).
- 확장: `git`(feature/validate/remote/initialize/commit; `before_specify`=feature 필수 훅, auto_commit 기본 off, `commit_style: conventional` 가능, `{number}-{slug}`), `agent-context`(`after_specify`/`after_plan` 선택 훅 → CLAUDE.md `<!-- SPECKIT START -->…<!-- SPECKIT END -->`에 plan 경로만 기록, 마커 밖 불변, python3+PyYAML 필요), `assess`(intake/research/define/shape/decide → `.specify/assessments/<slug>/`), `bug`(assess/fix/test → `.specify/bugs/<slug>/`), `selftest`. 커뮤니티(discovery-only, `specify extension info <name>`로 아카이브 URL 확인 후 `add <name> --from <url>`): `archive` 1.3.0(stn1slv), `adrkit` 0.1.2(mbeacom; context/check(after_plan)/draft), `reconcile` 1.2.1, `security-review` 2.0, `review` 1.0.1, `pr-bridge`, `changelog`, `agent-assign`, `worktree(s)`, `tdd`, `branch-convention`, `speckit-superpowers-bridge`(PowerShell 지원, superpowers 5.1.0 요구), `superb`, `superspec`.
- 사후 모델: Flow-Forward / Living Spec / Flow-Back 중 팀 관례(CLI 설정 아님). archive 없음 → community `archive`가 `.specify/memory/{spec,plan,changelog}.md`에 통합.
- `specs/` 경로는 specify 명령 템플릿에 하드코딩 — 이름 변경 금지. 활성 feature는 브랜치가 아니라 feature.json.
- 유지자 입장: constitution = 제품·품질 거버넌스(온디맨드), CLAUDE.md = 에이전트 운영(상시). 공식 Claude 플러그인 패키징은 거부됨(#1451).
- 커뮤니티 함정: 스킬 자동 트리거로 세션 이탈(명시 호출), spec 전체 투입 시 18k+ 토큰, superpowers가 constitution 무시(CLAUDE.md 포인터), "tasks.md 이후 재계획 금지".
- 이 개발기 상태: Git Bash PATH에 `uv`/`uvx`/`specify` 없음, `python`은 있으나 `typer` 미설치 → SP-0 첫 task에서 `uv` 설치·PATH 확인 필요.

## 4. 문서 정책 동향

- AGENTS.md(agents.md, Linux Foundation AAIF): 도구 중립 브리프. Claude Code는 읽지 않음 → `CLAUDE.md`에 `@AGENTS.md`. CLAUDE.md 200줄 이하, 코드에서 유추 가능한 내용 제외.
- spec-driven 도구 공통: "현재 진실" vs "변경 제안" 분리, 작업 단위에 번호/날짜 접두(Spec Kit `001-`, OpenSpec `YYYY-MM-DD-`, Backlog.md `task-N`). `backlog/` 이름은 Backlog.md 도구 규약과 충돌.
- ADR: MADR 4.0(`docs/decisions/NNNN-title.md`, `0000-use-markdown-architectural-decision-records.md`, status/date/decision-makers frontmatter, Context → Decision Drivers → Considered Options → Decision Outcome/Consequences). 번호 재사용 금지, 수정 대신 supersede. AI 시대 가이드: CLAUDE.md에서 decisions를 먼저 읽게.
- changelog: Keep a Changelog 1.1.0(Unreleased, Added/Changed/Deprecated/Removed/Fixed/Security, ISO 날짜) + Conventional Commits 1.0. 변경별 update_log는 표준 없음 → 변경 디렉터리 내 노트(report.md) + CHANGELOG.
- 에이전트 문서 열람 실측(2026-08): 지시 파일 35%·작업 노트 25% vs 사람용 10.6%(ADR 4%) → 사람용 설명 문서는 사이트 콘텐츠로.
- 학습 콘텐츠 frontmatter(Astro/Hugo 공통): `title, description, pubDate, updatedDate, tags, series, draft, slug(선택)`; 파일명 ASCII kebab-case; draft는 `import.meta.env.PROD ? !draft : true` 필터.
- llms.txt: 저장소 안에서는 무의미(에이전트는 CLAUDE.md/작업 노트를 봄). 사이트에만 선택 적용.
- 한국어 사용(KakaoPay 2026-03): 자연어 spec은 한국어, 식별자·파일명·템플릿은 영어; constitution 무시 사례, 토큰 비용 주의.

## 5. 참고 저장소(사용자 기존 컨벤션 — 상속하지 않되 참고)

- `d:\code\egenauto-backend-cc`, `d:\code\egenauto-frontend-cc`, `d:\code\egenauto-backend-msa`: Planner/Builder/Tester/Reviewer 에이전트 + `plan-approval-review` 훅(UserPromptSubmit, 승인 키워드 → 보안·트렌드 검토 지시, sh/ps1) + `docs/plan/{01.main_plan.md, open/{slug}/main-plan.md, close/}` + `docs/update_log/update_v{X.Y.Z}.md`(Summary/Changes Made/Validation/Next Version Plan) + commit 스킬 + 3단 브랜치(develop/release/main).
- `d:\code\joshuatech`(v1): `joshtech_study.md`(명령어 치트시트), `docs/user/*`(에이전트 비교 분석 보고서 — 분석+검증 에이전트 쌍 방식).

## 6. 외부 자문: CI/CD 정책 (SP-1·SP-3 참고, SP-0 범위 밖)

- 원문: [2026-08-26-cicd-policy-external.md](2026-08-26-cicd-policy-external.md) — "OCI + K3s + GHCR + Argo CD" GitOps 정책 제안(외부 AI 자문, 채택 안 됨).
- 검토: [2026-08-26-cicd-policy-review.md](2026-08-26-cicd-policy-review.md) — 15 에이전트 다관점 검토(74건, 1차 출처 검증). 결론: 원칙 계층(불변 아티팩트·Git 정본·pull 기반·CI 무자격증명·rollback=revert)만 ADR 0002로 채택, K3s 세부는 SP-1 결정 후 조건부. 핵심 제약: OCI Always Free A1이 2026-06-15부터 **2 OCPU / 12 GB**, GitHub Free의 ruleset·environment·attestation은 **public repo 한정**, 원문의 GitHub Environment 게이트는 pull 기반 흐름에서 무효.
- SP-1이 먼저 답할 것: 테넌시 실제 할당(인스턴스 종료 금지) → repo 공개 여부 → 런타임 트랙(Cloudflare-native / web CF + API K3s / web CF + API compose-pull) → web 호스팅(Pages vs Workers) → DB.
- **결정(2026-08-27)**: ADR 0002(CI/CD 원칙)는 SP-0에서 만들지 않고 **SP-1에서 작성**한다(런타임 트랙 결정과 함께). 위 두 문서는 참고 자료로만 001에 보존한다.
