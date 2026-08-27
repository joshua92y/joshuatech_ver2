# SP-0 Claude Code 기반 셋팅 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `joshuatech_ver2` 저장소에 Spec Kit(계약·흐름) + superpowers 5.1.0(실행) + 프로젝트 레이어(tester 에이전트·approval-review/finish 스킬·훅 3종·규칙 3종·문서·학습 노트 계약)를 설치·작성하고, `002-smoke`로 전체 사이클을 1회 실주행해 검증한 뒤 001을 마감한다.

**Architecture:** Spec Kit이 `specs/NNN-slug/`·constitution·`/speckit-*` 명령을 제공하고, superpowers가 구현(SDD/TDD)·리뷰·마감(finishing)을 수행하며, `.claude/`의 훅(결정적 게이트)·스킬(경계별 서브에이전트 리뷰)·에이전트(E2E tester)가 품질 게이트를 강제한다. 활성 feature는 `SPECIFY_FEATURE_DIRECTORY` env → 브랜치명 `NNN-slug` → `.specify/feature.json` 순으로 해석하고, 해석 실패·불일치는 fail-closed다.

**Tech Stack:** Windows 11, PowerShell 7.6 (`pwsh`), git + `gh` 2.93(인증됨), `uv` + `specify` CLI(Spec Kit 1.0.1), Claude Code(플러그인 `superpowers@superpowers-dev` 5.1.0), Python 3.14 + PyYAML(agent-context 확장용). 애플리케이션 코드 없음(스택 중립).

**Spec:** [spec.md](spec.md) — Status: Approved (2026-08-26). 조사 근거: [research/2026-08-26-research-summary.md](research/2026-08-26-research-summary.md)

**Plan 위치 규칙:** 이 plan은 spec FR-008의 부트스트랩 예외로 superpowers writing-plans 형식이다. 002부터는 `/speckit-plan` + `/speckit-tasks`가 `plan.md`·`tasks.md`를 만든다.

---

## 실행 전 확인 사항 (2026-08-26 실측)

- `pwsh` 7.6.3 (`C:\Program Files\PowerShell\7\7\pwsh.exe`, PATH에 있음). ExecutionPolicy LocalMachine=RemoteSigned → 모든 훅 명령은 `pwsh -NoProfile -ExecutionPolicy Bypass -File …`.
- `uv`·`uvx`·`specify` 없음 → Task 3. `python` 3.14.2 + PyYAML 6.0.3 있음(agent-context 확장 요구 충족).
- `gh` 2.93.0, `joshua92y` 계정 로그인.
- 현재 브랜치 `001-claude-setup`(main에서 분기). 커밋: `.gitignore`, spec, research. Git `core.autocrlf` 경고가 있었음 → Task 1의 `.gitattributes`.
- 스크래치패드에 Spec Kit 클론(`…\scratchpad\spec-kit`)과 `specify init` 데모 결과(`…\scratchpad\demo-claude`)가 있어 생성물 비교에 쓸 수 있다.
- 모든 Bash 예시는 Git Bash, PowerShell 예시는 `pwsh`. 저장소 루트 `d:\code\joshuatech_ver2`에서 실행한다.

## 작업 규칙

- 커밋 메시지: Conventional Commits(`type(scope): 한국어 설명`), 본문 끝에 트레일러 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- 파일 인코딩 UTF-8(BOM 없음), 줄 끝 LF. PowerShell 스크립트도 LF.
- 에이전트 파일(EN) 첫 줄(YAML frontmatter가 있으면 그 다음 줄)에 정본 언어 선언:
  ```
  > Canonical language: English. Korean mirror: docs/kr/<path>_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).
  ```
- 한국어 미러(`docs/kr/…_kr.md`)는 영어 원본과 **절 구조·표·코드 블록·식별자를 동일하게** 유지하고 산문만 한국어로 번역한다. 미러 첫 줄:
  ```
  > 번역본(편의용). 정본은 영어 원본 `<path>`이며 충돌 시 영어가 우선한다. 동기화: /finish.
  ```
- 서브에이전트에 task를 넘길 때 이 plan 전체가 아니라 해당 Task 절만 전달한다.
- 훅 스크립트는 예외 시 `exit 0`(fail-open). 게이트 불충족만 deny.

## 파일 구조 (생성·수정 대상)

```
joshuatech_ver2/
├── .gitattributes                                  Task 1
├── AGENTS.md · CLAUDE.md · CHANGELOG.md · README.md   Task 19·20·21
├── .specify/                                       Task 4(생성) · 5·6·7(확장) · 8(override) · 9(헌법)
│   ├── memory/constitution.md
│   ├── templates/overrides/tasks-template.md
│   ├── extensions/{git,agent-context,archive,adrkit}/ · extensions.yml
│   └── (init 생성물: scripts/powershell, templates, workflows, integrations, init-options.json)
├── .claude/
│   ├── settings.json                               Task 14
│   ├── hooks/{approval-review,finish-gate,tester-write-guard}.ps1   Task 11·12·13
│   ├── agents/tester.md                            Task 15
│   ├── rules/{specs,docs,content}.md               Task 16
│   ├── skills/approval-review/{SKILL.md,boundaries/*.md}   Task 17
│   ├── skills/finish/{SKILL.md,boundaries/*.md}    Task 18
│   └── skills/speckit-*/                           Task 4·5·6·7(생성)
├── tests/hooks/run-hook-tests.ps1                  Task 10
├── tests/run-all.ps1                               Task 23
├── specs/README.md                                 Task 21
├── specs/001-claude-setup/{report.md,reviews/}     Task 26
├── specs/002-smoke/**                              Task 25 (Spec Kit 흐름으로 생성)
├── scripts/update-specs-index.ps1 · tests/scripts/…   Task 25 (smoke 구현물)
├── docs/README.md · docs/decisions/{0000,0001}-*.md · docs/runbooks/spec-kit-upgrade.md   Task 21
├── docs/kr/{CLAUDE,AGENTS,constitution}_kr.md · docs/kr/{agents,skills,rules}/*_kr.md   각 원본 Task에서
└── content/study/001-claude-setup.mdx              Task 22
```

## Phase 구성

| Phase | Task | 내용 |
|---|---|---|
| A 기반 | 1–4 | `.gitattributes`·원격, 사용자 플러그인 정리, `uv`+`specify`, `specify init` |
| B Spec Kit 구성 | 5–9 | 번들 확장, 커뮤니티 확장(archive·adrkit), tasks 템플릿 override, 헌법 |
| C Claude 레이어 | 10–18 | 훅 테스트(RED) → 훅 3종(GREEN), settings, tester, rules, 스킬 2종 |
| D 문서 | 19–23 | AGENTS, CLAUDE, docs/decisions/runbook/CHANGELOG/README/인덱스, 학습 노트, run-all |
| E 검증·마감 | 24–26 | selftest·등록 확인, 002-smoke 실주행, 001 finish·머지·archive |

---

## Phase A — 기반

### Task 1: `.gitattributes`와 GitHub 원격

**Files:**
- Create: `.gitattributes`

- [x] **Step 1: `.gitattributes` 작성**

```gitattributes
# 줄 끝은 저장소에서 항상 LF. Windows 작업 복사본도 LF로 체크아웃한다.
* text=auto eol=lf
*.ps1 text eol=lf
*.md text eol=lf
*.json text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.png binary
*.jpg binary
*.webp binary
*.gif binary
```

- [x] **Step 2: 정규화 확인**

Run: `git add --renormalize . && git status --short`
Expected: 출력에 `A  .gitattributes`만 있고 기존 3개 파일은 변경 없음(이미 LF로 커밋됨). 이후 `git add`에서 CRLF 경고가 사라진다.

- [x] **Step 3: 커밋**

```bash
git add .gitattributes
git commit -m "chore: .gitattributes로 LF 강제

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [x] **Step 4: GitHub private 원격 생성 + 현재 브랜치 push**

Run: `gh repo create joshuatech_ver2 --private --source=. --remote=origin --push`
Expected:
```
✓ Created repository joshua92y/joshuatech_ver2 on github.com
✓ Added remote https://github.com/joshua92y/joshuatech_ver2.git
✓ Pushed commits to https://github.com/joshua92y/joshuatech_ver2.git
```

- [x] **Step 5: main도 push하고 원격 확인**

Run: `git push -u origin main && git ls-remote --heads origin`
Expected: `refs/heads/001-claude-setup`와 `refs/heads/main` 두 줄. (SC-009)

---

### Task 2: 사용자 레벨 superpowers 플러그인 단일화

**Files:**
- Modify: `C:\Users\2401\.claude\settings.json` (`enabledPlugins`) — 저장소 밖, 커밋 없음

- [x] **Step 1: 백업**

Run: `pwsh -NoProfile -c "Copy-Item $HOME/.claude/settings.json $HOME/.claude/settings.json.bak-2026-08-26; Get-ChildItem $HOME/.claude/settings.json*"`
Expected: `settings.json`과 `settings.json.bak-2026-08-26` 두 파일.

- [x] **Step 2: official 플러그인 비활성화**

`C:\Users\2401\.claude\settings.json`의 `enabledPlugins`를 다음으로 바꾼다(다른 키는 그대로).

```json
"enabledPlugins": {
  "superpowers@superpowers-dev": true,
  "superpowers@claude-plugins-official": false,
  "frontend-design@claude-plugins-official": true,
  "andrej-karpathy-skills@karpathy-skills": true,
  "ui-ux-pro-max@ui-ux-pro-max-skill": true
}
```

- [x] **Step 3: 확인**

Run: `pwsh -NoProfile -c "(Get-Content $HOME/.claude/settings.json -Raw | ConvertFrom-Json).enabledPlugins"`
Expected: `superpowers@superpowers-dev : True`, `superpowers@claude-plugins-official : False`.

- [x] **Step 4: 세션 재시작 후 검증 기록**

다음 Claude Code 세션 시작 시 `/plugin`에서 superpowers가 1개(superpowers-dev 5.1.0)만 활성인지 확인하고, 결과를 Task 26의 `report.md` Validation에 적는다(SC-007).

---

### Task 3: `uv`와 `specify` CLI 설치

**Files:** 없음(개발기 도구)

- [x] **Step 1: uv 설치**

Run (pwsh): `winget install --id=astral-sh.uv -e --accept-source-agreements --accept-package-agreements`
Expected: `Successfully installed`. winget이 없으면 대신 `pwsh -c "irm https://astral.sh/uv/install.ps1 | iex"`.

- [x] **Step 2: PATH 반영 후 버전 확인**

새 `pwsh` 창(또는 `uv tool update-shell` 후 새 창)에서
Run: `uv --version`
Expected: `uv 0.<x>.<y>` 한 줄.

- [x] **Step 3: specify CLI 설치 (v1.0.1 고정)**

Run: `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v1.0.1`
Expected: 마지막 줄 `Installed 1 executable: specify.exe`. 태그가 없다고 나오면 `…spec-kit.git@main`으로 재시도하고 실제 버전을 `docs/runbooks/spec-kit-upgrade.md`(Task 21) 레지스터에 적는다.

- [x] **Step 4: 동작 확인**

Run: `specify --version` 그리고 `specify check`
Expected: `1.0.1`(또는 설치된 버전) 출력; `check`가 git 감지, Claude Code CLI 감지 여부를 표로 보여준다(없어도 Task 4에서 `--ignore-agent-tools`로 진행).

---

### Task 4: `specify init` (Claude 통합, PowerShell 스크립트)

**Files:**
- Create(생성됨): `.specify/**`, `.claude/skills/speckit-*/SKILL.md` ×10

- [x] **Step 1: 초기화**

Run (저장소 루트, pwsh): `specify init --here --integration claude --script ps --non-interactive --force --ignore-agent-tools`
Expected: 진행 표시 후 `Project ready` 류의 완료 메시지. 오류 없이 종료.

- [x] **Step 2: 생성물 검증**

Run: `pwsh -NoProfile -c "(Get-ChildItem .claude/skills -Directory).Name; '---'; (Get-ChildItem .specify -Recurse -File).FullName -replace [regex]::Escape((Get-Location).Path + '\'), ''"`
Expected: 스킬 10개 — `speckit-analyze, speckit-checklist, speckit-clarify, speckit-constitution, speckit-converge, speckit-implement, speckit-plan, speckit-specify, speckit-tasks, speckit-taskstoissues`. `.specify/` 아래에 `memory/constitution.md`, `templates/{checklist,constitution,plan,spec,tasks}-template.md`, `scripts/powershell/{check-prerequisites,common,create-new-feature,resolve-template,setup-plan,setup-tasks}.ps1`, `workflows/speckit/workflow.yml`, `integrations/claude.manifest.json`, `init-options.json`, `.gitignore`. `CLAUDE.md`는 생성되지 않는다(`Test-Path CLAUDE.md` → False).

- [x] **Step 3: 데모와 대조(선택)**

Run: `pwsh -NoProfile -c "Compare-Object (Get-ChildItem .specify -Recurse -File | ForEach-Object { $_.FullName.Substring((Get-Location).Path.Length) }) (Get-ChildItem '$env:LOCALAPPDATA\Temp\claude\d--code-joshuatech-ver2\3f519c54-d0d7-41ee-85ba-61d3907e92eb\scratchpad\demo-claude\.specify' -Recurse -File | ForEach-Object { $_.FullName.Substring(($env:LOCALAPPDATA + '\Temp\claude\d--code-joshuatech-ver2\3f519c54-d0d7-41ee-85ba-61d3907e92eb\scratchpad\demo-claude').Length) })"`
Expected: 차이 없음(빈 출력). 차이가 있으면 버전 차이이므로 레지스터에 메모.

- [x] **Step 4: 커밋**

```bash
git add .specify .claude
git commit -m "chore(speckit): Spec Kit 1.0.1 초기화 (integration=claude, script=ps)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Phase B — Spec Kit 구성

### Task 5: 번들 확장 `git`·`agent-context` (selftest는 1.0.2 카탈로그에 없어 제외 — 실행 기록 2026-08-26)

**Files:**
- Create(생성됨): `.specify/extensions/{git,agent-context}/**`, `.specify/extensions.yml`, `.claude/skills/speckit-git-*`, `speckit-agent-context-update`
- Modify: `.specify/extensions/git/git-config.yml`

- [x] **Step 1: 설치**

Run: `specify extension add git; specify extension add agent-context`
Expected: 각각 `Installed extension '<id>'`와 등록된 명령 수. `.specify/extensions.yml`이 생기고 `hooks:`에 `before_specify: speckit.git.feature`, `after_plan: speckit.agent-context.update` 등이 나열된다.

- [x] **Step 2: git 확장 설정 — Conventional Commit 메시지, 자동 커밋 off 유지**

`.specify/extensions/git/git-config.yml`에서 `commit_style: fixed` → `commit_style: conventional`으로 바꾼다. `auto_commit.default: false`는 그대로 둔다(커밋은 SDD implementer가 task마다 수행).

- [x] **Step 3: 스킬 이름 기록**

Run: `pwsh -NoProfile -c "(Get-ChildItem .claude/skills -Directory | Where-Object Name -notin @('speckit-analyze','speckit-checklist','speckit-clarify','speckit-constitution','speckit-converge','speckit-implement','speckit-plan','speckit-specify','speckit-tasks','speckit-taskstoissues')).Name"`
Expected: `speckit-git-commit, speckit-git-feature, speckit-git-initialize, speckit-git-remote, speckit-git-validate, speckit-agent-context-update, speckit-selftest`(selftest 이름은 실제 출력을 따른다). 이 목록을 Task 20(CLAUDE.md)·Task 21(런북)에 그대로 쓴다.

- [x] **Step 4: 커밋**

```bash
git add .specify .claude
git commit -m "chore(speckit): git·agent-context 확장 설치, commit_style=conventional

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: 커뮤니티 확장 `archive` (검토 후 설치)

**Files:**
- Create(생성됨): `.specify/extensions/archive/**`, `.claude/skills/speckit-archive*/`

- [x] **Step 1: 후보 아카이브 URL 확인**

Run: `specify extension info archive`
Expected: 버전 `1.3.0`, 저장소 `https://github.com/stn1slv/spec-kit-archive`, `Candidate archive: https://github.com/stn1slv/spec-kit-archive/releases/download/…` 줄. 이 URL을 다음 단계의 `$url`에 넣는다.

- [x] **Step 2: 다운로드·내용 검토 (네트워크·파괴 명령 유무)**

```powershell
$url = "<Step 1의 Candidate archive URL>"
$tmp = Join-Path $env:TEMP 'speckit-archive-ext'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Invoke-WebRequest $url -OutFile "$tmp.zip"
Expand-Archive "$tmp.zip" -DestinationPath $tmp -Force
Get-ChildItem $tmp -Recurse -File | Select-Object -ExpandProperty FullName
Get-ChildItem $tmp -Recurse -Include *.ps1,*.sh,*.py,*.md,*.yml | Select-String -Pattern 'Invoke-WebRequest|curl |wget |Remove-Item .*-Recurse|rm -rf|git push|Set-ExecutionPolicy|Invoke-Expression|iex ' | Select-Object Path, LineNumber, Line
```
Expected: `extension.yml`, `commands/*.md`, (있으면) `scripts/`. 두 번째 명령은 **빈 출력**이어야 한다. 일치가 있으면 해당 줄을 읽고 설치를 중단·보고한다(문서 예시의 무해한 언급이면 사유를 적고 진행).

- [x] **Step 3: 설치**

Run: `specify extension add archive --from $url`
Expected: `Installed extension 'archive'`; `.specify/extensions/archive/`와 `speckit-archive*` 스킬 생성.

- [x] **Step 4: 명령명·출력 경로 기록**

Run: `pwsh -NoProfile -c "(Get-ChildItem .claude/skills -Directory | Where-Object Name -like 'speckit-archive*').Name; Get-Content .specify/extensions/archive/README.md | Select-Object -First 60"`
Expected: 스킬 이름(예: `speckit-archive`)과 README의 출력 경로(`.specify/memory/…`). 이 이름과 경로를 Task 18(`finish` 스킬 7단계)·Task 20(CLAUDE.md 8단계)·Task 21(런북)에 반영한다.

- [x] **Step 5: 커밋**

```bash
git add .specify .claude
git commit -m "chore(speckit): archive 확장 1.3.0 설치 (검토 완료)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 커뮤니티 확장 `adrkit` — **실행 기록 2026-08-26: 설치 불가**(확장 요구 spec-kit >=0.13,<0.16 vs 설치 1.0.2; npm `@adrkit/cli` 별도 필요; ADR 경로는 env `ADRKIT_DIR` 전용). 검토는 통과. ADR은 MADR 수작성, adrkit은 Tier 2로 이월.

**Files:**
- Create(생성됨): `.specify/extensions/adrkit/**`, `.claude/skills/speckit-adrkit-*/`
- Modify(있으면): `.specify/extensions/adrkit/adrkit-config.yml`

- [x] **Step 1: 후보 URL 확인**

Run: `specify extension info adrkit`
Expected: 버전 `0.1.2`, 저장소 `https://github.com/mbeacom/adrkit`, `Candidate archive:` URL.

- [x] **Step 2: 다운로드·검토** — Task 6 Step 2와 같은 스크립트를 `$tmp = Join-Path $env:TEMP 'speckit-adrkit-ext'`로 실행. Expected: 위험 패턴 검색 결과 빈 출력.

- [ ] **Step 3: 설치**

Run: `specify extension add adrkit --from $url`
Expected: `Installed extension 'adrkit'`; `speckit-adrkit-context`, `speckit-adrkit-check`, `speckit-adrkit-draft` 스킬(실제 이름은 출력 기준).

- [ ] **Step 4: ADR 디렉터리 설정**

Run: `pwsh -NoProfile -c "Get-ChildItem .specify/extensions/adrkit -Recurse -File | Select-Object -ExpandProperty FullName; Get-Content .specify/extensions/adrkit/README.md | Select-String -Pattern 'docs/adr|decisions|--dir|adr_dir|directory' | Select-Object -First 10"`
Expected: 설정 파일(`adrkit-config.yml` 또는 README가 지정하는 파일)에 ADR 디렉터리 키가 있다. 그 값을 `docs/decisions`로 바꾼다. 확장이 자체 CLI(`adrkit`)를 요구하면 `uv tool install adrkit`을 실행하고 `adrkit --version`으로 확인한다. 설정 키가 전혀 없고 `docs/adr`가 하드코딩이면 **`docs/decisions` 대신 `docs/adr`를 채택**하고 spec FR-011·Task 16(docs.md)·Task 21의 경로를 `docs/adr`로 통일한다(경로명은 규약 선택 사항이므로 spec 개정 없이 plan 메모로 처리).

- [x] **Step 5: 커밋**

```bash
git add .specify .claude
git commit -m "chore(speckit): adrkit 확장 0.1.2 설치, ADR 경로 docs/decisions

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: `tasks-template.md` override — 테스트 필수화 + 스토리별 E2E task

**Files:**
- Create: `.specify/templates/overrides/tasks-template.md`

- [x] **Step 1: 실패 확인(현재는 테스트가 선택)**

Run: `pwsh -NoProfile -File .specify/scripts/powershell/resolve-template.ps1 tasks-template | Select-String -Pattern 'MANDATORY|OPTIONAL' | Select-Object -First 3`
Expected: `Tests are OPTIONAL - only include them if explicitly requested` 등 OPTIONAL만 보인다.

- [x] **Step 2: override 파일 작성**

`.specify/templates/overrides/tasks-template.md` (원본 1.0.1 템플릿을 복사해 아래 표시된 부분만 바꾼 전체 파일):

```markdown
---

description: "Task list template for feature implementation (joshuatech override: tests mandatory, E2E per story)"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY (constitution II. Test-First). Every user story phase MUST contain (a) test tasks written and observed failing BEFORE implementation tasks and (b) exactly one E2E task per story, executed by the `tester` agent from the user's point of view. Do not omit these sections.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure
- Test files MUST live under `tests/`, `e2e/`, `__tests__/` or be named `*.test.*` / `*.spec.*` (the tester agent may only write there)

<!--
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration purposes only.

  The /speckit-tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [x] T001 Create project structure per implementation plan
- [x] T002 Initialize [language] project with [framework] dependencies
- [x] T003 [P] Configure linting and formatting tools

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your project):

- [x] T004 Setup database schema and migrations framework
- [x] T005 [P] Implement authentication/authorization framework
- [x] T006 [P] Setup API routing and middleware structure
- [x] T007 Create base models/entities that all stories depend on
- [x] T008 Configure error handling and logging infrastructure
- [x] T009 Setup environment configuration management

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1 (MANDATORY — write first, verify they FAIL) ⚠️

> **NOTE: Write these tests FIRST, run them, and confirm they FAIL before any implementation task below**

- [x] T010 [P] [US1] Contract test for [endpoint] in tests/contract/test_[name].py
- [x] T011 [P] [US1] Integration test for [user journey] in tests/integration/test_[name].py

### Implementation for User Story 1

- [x] T012 [P] [US1] Create [Entity1] model in src/models/[entity1].py
- [x] T013 [P] [US1] Create [Entity2] model in src/models/[entity2].py
- [x] T014 [US1] Implement [Service] in src/services/[service].py (depends on T012, T013)
- [x] T015 [US1] Implement [endpoint/feature] in src/[location]/[file].py
- [x] T016 [US1] Add validation and error handling
- [x] T017 [US1] Add logging for user story 1 operations

### E2E for User Story 1 (MANDATORY — executed by the tester agent)

- [x] T018 [US1] E2E: [Acceptance Scenario 1 from spec.md, as the user would do it] — evidence recorded in the tester report

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2 (MANDATORY — write first, verify they FAIL) ⚠️

- [x] T019 [P] [US2] Contract test for [endpoint] in tests/contract/test_[name].py
- [x] T020 [P] [US2] Integration test for [user journey] in tests/integration/test_[name].py

### Implementation for User Story 2

- [x] T021 [P] [US2] Create [Entity] model in src/models/[entity].py
- [x] T022 [US2] Implement [Service] in src/services/[service].py
- [x] T023 [US2] Implement [endpoint/feature] in src/[location]/[file].py
- [x] T024 [US2] Integrate with User Story 1 components (if needed)

### E2E for User Story 2 (MANDATORY — executed by the tester agent)

- [x] T025 [US2] E2E: [Acceptance Scenario from spec.md] — evidence recorded in the tester report

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3 (MANDATORY — write first, verify they FAIL) ⚠️

- [x] T026 [P] [US3] Contract test for [endpoint] in tests/contract/test_[name].py
- [x] T027 [P] [US3] Integration test for [user journey] in tests/integration/test_[name].py

### Implementation for User Story 3

- [x] T028 [P] [US3] Create [Entity] model in src/models/[entity].py
- [x] T029 [US3] Implement [Service] in src/services/[service].py
- [x] T030 [US3] Implement [endpoint/feature] in src/[location]/[file].py

### E2E for User Story 3 (MANDATORY — executed by the tester agent)

- [x] T031 [US3] E2E: [Acceptance Scenario from spec.md] — evidence recorded in the tester report

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [x] TXXX [P] Documentation updates in docs/
- [x] TXXX Code cleanup and refactoring
- [x] TXXX Performance optimization across all stories
- [x] TXXX [P] Additional unit tests in tests/unit/
- [x] TXXX Security hardening
- [x] TXXX Run quickstart.md validation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- E2E task runs last in the story and is executed by the tester agent, never by the implementer
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test for [endpoint] in tests/contract/test_[name].py"
Task: "Integration test for [user journey] in tests/integration/test_[name].py"

# Launch all models for User Story 1 together:
Task: "Create [Entity1] model in src/models/[entity1].py"
Task: "Create [Entity2] model in src/models/[entity2].py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
```

- [x] **Step 3: override가 적용되는지 확인**

Run: `pwsh -NoProfile -File .specify/scripts/powershell/resolve-template.ps1 tasks-template | Select-String -Pattern 'MANDATORY' | Measure-Object | Select-Object -ExpandProperty Count`
Expected: `7` 이상(헤더 1 + 스토리별 테스트 절 3 + E2E 절 3). `OPTIONAL`은 0건.

- [x] **Step 4: 커밋**

```bash
git add .specify/templates/overrides/tasks-template.md
git commit -m "feat(speckit): tasks 템플릿 override — 테스트 필수화·스토리별 E2E task

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: 프로젝트 헌법 (EN) + 한국어 미러

**Files:**
- Modify: `.specify/memory/constitution.md` (init이 만든 플레이스홀더 파일을 전체 교체)
- Create: `docs/kr/constitution_kr.md`

- [x] **Step 1: 플레이스홀더 상태 확인(실패 조건)**

Run: `pwsh -NoProfile -c "(Select-String -Path .specify/memory/constitution.md -Pattern '\[[A-Z_0-9]+\]' -AllMatches).Count"`
Expected: `10` 이상(템플릿 플레이스홀더가 남아 있음).

- [x] **Step 2: 헌법 작성 (전체 교체)**

```markdown
> Canonical language: English. Korean mirror: docs/kr/constitution_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# JoshuaTech v2 Constitution

## Core Principles

### I. Spec-First
Every change larger than a typo starts as a feature under `specs/NNN-slug/` with a `spec.md` (user stories, functional requirements, success criteria) before any code. The spec is the authority the plan and tasks argue from; code that contradicts an approved spec is a defect, not a design decision. Feature directories are immutable history: a change of intended behavior is a new feature directory, never a silent edit of a completed one.

### II. Test-First (NON-NEGOTIABLE)
No production code without a failing test first. Every user story phase in `tasks.md` MUST contain test tasks that are written and observed failing before implementation tasks, plus one end-to-end scenario executed by the `tester` agent from the user's point of view. Any template wording that makes tests optional is overridden by this article.

### III. Tenant Boundary
The product is designed as a multi-tenant SaaS even while it serves a single tenant. Every data-owning entity MUST name its owner and its isolation key (or state why it is global) in the spec's Key Entities; every service boundary MUST state what data it owns and what it merely references. Cross-boundary access goes through explicit contracts (APIs, events), never shared tables or implicit joins.

### IV. Observability-Ready
Each plan MUST state how the feature is observed in production — structured logs with a correlation id, the metrics that indicate health — and its rollback path. A feature without a rollback path is not ready to ship.

### V. Simplicity
Build the smallest thing that satisfies the spec (YAGNI). New frameworks, extensions, or abstractions require a documented reason in `plan.md` Complexity Tracking or an ADR under `docs/decisions/`. Prefer deleting over adding.

### VI. Learning-in-Public
Every completed feature produces a learning note in `content/study/NNN-slug.mdx` (the problem, what was learned, which alternatives were rejected and why, how it was verified, what to learn next). The note is a first-class deliverable checked by the finish gate, and the site publishes it.

## Platform Constraints
- The stack is undecided until SP-1; this constitution is stack-neutral and applies to tooling, documents, and future code alike.
- Secrets never enter the repository; configuration comes from the environment or a secret manager.
- Destructive operations (history rewrites, force pushes, data deletion, infrastructure teardown) require explicit human approval.

## Development Workflow & Quality Gates
1. Intake: `/speckit-specify` (superpowers brainstorming for architecture-level work), then `/speckit-clarify` when ambiguous.
2. Plan: `/speckit-plan` (Constitution Check gate) → `/speckit-checklist` → `/speckit-tasks`.
3. Approval: `/approval-review` runs per-boundary reviews (security, tenant/data, operability, trends, spec consistency) and records `reviews/*-approval.md`; the spec Status becomes Approved only after the human confirms.
4. Build: superpowers subagent-driven-development executes `tasks.md` with TDD and per-task review; `/speckit-implement` is not used.
5. Converge: `/speckit-converge` until Converged.
6. Verify: the `tester` agent executes every user story end-to-end.
7. Finish: `/finish` writes `report.md`, the learning note, the CHANGELOG entry, and `reviews/*-finish.md`; the finish gate blocks `finishing-a-development-branch` until that review is Approved.
8. Integrate: merge, then archive the feature into `.specify/memory/` so the current state of the system stays readable.

## Governance
This constitution supersedes all other practices in this repository. Amendments go through `/speckit-constitution`, bump the version (MAJOR: principle removed or redefined incompatibly; MINOR: principle or section added; PATCH: wording), and record a Sync Impact Report. Every plan's Constitution Check and every approval/finish review verifies compliance; violations are justified in Complexity Tracking or rejected. Agent operating mechanics live in `CLAUDE.md` and `AGENTS.md`; durable decisions live in `docs/decisions/`.

**Version**: 1.0.0 | **Ratified**: 2026-08-26 | **Last Amended**: 2026-08-26
```

- [x] **Step 3: 플레이스홀더 0 확인**

Run: `pwsh -NoProfile -c "(Select-String -Path .specify/memory/constitution.md -Pattern '\[[A-Z_0-9]+\]' -AllMatches).Count"`
Expected: `0`.

- [x] **Step 4: 한국어 미러 작성**

`docs/kr/constitution_kr.md`: 첫 줄 `> 번역본(편의용). 정본은 영어 원본 \`.specify/memory/constitution.md\`이며 충돌 시 영어가 우선한다. 동기화: /finish.` 다음에 Step 2의 본문을 절 구조·번호·강조·코드 식별자(`specs/NNN-slug/`, `/speckit-*`, `tester`, `report.md` 등)를 그대로 두고 산문만 한국어로 번역한다. 마지막 버전 줄은 동일하게 유지한다.

- [x] **Step 5: 커밋**

```bash
git add .specify/memory/constitution.md docs/kr/constitution_kr.md
git commit -m "feat(constitution): JoshuaTech v2 헌법 1.0.0 제정 (EN + kr 미러)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

## Phase C — Claude 레이어

### Task 10: 훅 단위 테스트 하네스 (RED)

**Files:**
- Create: `tests/hooks/run-hook-tests.ps1`

- [x] **Step 1: 테스트 스크립트 작성**

외부 테스트 프레임워크 없이 동작한다. 각 훅에 샘플 stdin JSON을 넣고 stdout/exit code를 검사한다. finish-gate 케이스는 임시 git 저장소를 만들어 브랜치·파일 상태를 재현한다.

```powershell
# Hook unit tests. Run: pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1
# Exit 0 = all pass, 1 = failures. No external test framework.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hooks = Join-Path $repo '.claude/hooks'
$script:pass = 0
$script:fail = 0

function Invoke-Hook([string]$name, [hashtable]$payload, [string]$cwd) {
    $json = $payload | ConvertTo-Json -Compress -Depth 6
    $scriptPath = Join-Path $hooks $name
    if (-not (Test-Path $scriptPath)) { return @{ out = "<missing: $name>"; code = 127 } }
    Push-Location $cwd
    try {
        $out = $json | pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>$null
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    return @{ out = (($out | ForEach-Object { "$_" }) -join "`n"); code = $code }
}

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function New-Fixture([string]$branch, [hashtable]$files, [string]$featureJson) {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('hooktest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    git -C $dir init -q -b main
    git -C $dir -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    if ($branch -ne 'main') { git -C $dir checkout -q -b $branch }
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        New-Item -ItemType Directory -Path (Split-Path $p) -Force | Out-Null
        Set-Content -Path $p -Value $files[$rel] -Encoding utf8
    }
    if ($featureJson) {
        New-Item -ItemType Directory -Path (Join-Path $dir '.specify') -Force | Out-Null
        Set-Content -Path (Join-Path $dir '.specify/feature.json') -Value $featureJson -Encoding utf8
    }
    return $dir
}

# ---------- approval-review ----------
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = 'plan 승인해줘'; cwd = $repo } $repo
Assert 'approval: keyword -> systemMessage mentions /approval-review' ($r.code -eq 0 -and $r.out -match 'approval-review') $r.out
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = '오늘 날씨 어때'; cwd = $repo } $repo
Assert 'approval: no keyword -> no output' ($r.code -eq 0 -and [string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = 'lgtm'; cwd = $repo } $repo
Assert 'approval: lgtm (case-insensitive) -> systemMessage' ($r.code -eq 0 -and $r.out -match 'approval-review') $r.out

# ---------- finish-gate ----------
$finishing = @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'superpowers:finishing-a-development-branch'; args = '' } }
$ready = @{
    'specs/002-smoke/spec.md'                       = '# x'
    'specs/002-smoke/report.md'                     = '# Report'
    'specs/002-smoke/reviews/2026-08-26-finish.md'  = "# Finish review`nStatus: Approved"
    'content/study/002-smoke.mdx'                   = '---'
}
$empty = @{ 'specs/002-smoke/spec.md' = '# x' }

$d = New-Fixture '002-smoke' $empty $null
$r = Invoke-Hook 'finish-gate.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'superpowers:brainstorming' }; cwd = $d } $d
Assert 'gate: other skill -> no output' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch resolved, artifacts missing -> deny' ($r.out -match '"permissionDecision":"deny"' -and $r.out -match 'report.md') $r.out

$d = New-Fixture '002-smoke' $ready $null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch resolved, artifacts present -> allow (no output)' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

$d = New-Fixture 'main' $ready $null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: unresolvable (main, no env, no feature.json) -> deny' ($r.out -match 'could not be resolved') $r.out

$d = New-Fixture '002-smoke' $ready '{"feature_directory":"specs/003-other"}'
New-Item -ItemType Directory -Path (Join-Path $d 'specs/003-other') -Force | Out-Null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch vs feature.json mismatch -> deny' ($r.out -match 'disagree') $r.out

$d = New-Fixture 'main' $ready $null
$env:SPECIFY_FEATURE_DIRECTORY = 'specs/002-smoke'
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Remove-Item Env:SPECIFY_FEATURE_DIRECTORY
Assert 'gate: env var resolves on main -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

# ---------- tester-write-guard ----------
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Write'; tool_input = @{ file_path = "$repo\tests\e2e\a.test.ts" }; cwd = $repo } $repo
Assert 'guard: tests/e2e/*.test.ts -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Edit'; tool_input = @{ file_path = "$repo\src\app.ts" }; cwd = $repo } $repo
Assert 'guard: src/app.ts -> deny' ($r.out -match '"permissionDecision":"deny"') $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Write'; tool_input = @{ file_path = 'apps/web/src/x.spec.ts' }; cwd = $repo } $repo
Assert 'guard: relative *.spec.ts -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Read'; tool_input = @{ file_path = 'src/app.ts' }; cwd = $repo } $repo
Assert 'guard: Read is not guarded -> no output' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
```

- [x] **Step 2: RED 확인**

Run: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1`
Expected: 훅 스크립트가 없으므로 모든 케이스가 `FAIL … <missing: …>`, 마지막 줄 `0 passed, 13 failed`, exit code 1(`$LASTEXITCODE`).

- [x] **Step 3: 커밋**

```bash
git add tests/hooks/run-hook-tests.ps1
git commit -m "test(hooks): 훅 단위 테스트 하네스 추가 (RED)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> **실행 기록 (2026-08-26)**: 구현 후 리뷰에서 (a) "출력 없음 = allow" 단언 6개가 exit code를 검사하지 않아 훅 크래시가 PASS로 위장될 수 있는 결함(Critical), (b) 임시 픽스처 미정리, (c) 잔류 `SPECIFY_FEATURE_DIRECTORY` 미초기화가 지적되어 모두 반영했다. 정본은 `tests/hooks/run-hook-tests.ps1`이며 위 코드 블록과 다음 점이 다르다: 모든 단언에 `$r.code -eq 0 -and`, `Detail $r`(출력+code), `try/finally`로 픽스처 삭제(`Remove-Fixtures`)·env 정리, `report\.md` 이스케이프. RED 기대값(0/13, exit 1)은 동일.

---

### Task 11: `approval-review.ps1` (UserPromptSubmit)

**Files:**
- Create: `.claude/hooks/approval-review.ps1`
- Test: `tests/hooks/run-hook-tests.ps1` (approval 3케이스)

- [x] **Step 1: 스크립트 작성**

```powershell
# approval-review hook (UserPromptSubmit).
# If the user's prompt looks like an approval, instruct the agent to run /approval-review first.
# Spec D15: the keyword set is intentionally broad. Fail-open: any error -> exit 0, no output.
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    $prompt = ''
    foreach ($k in @('prompt', 'userPrompt', 'message')) {
        if ($data.PSObject.Properties[$k] -and $data.$k) { $prompt = [string]$data.$k; break }
    }
    if (-not $prompt) { exit 0 }
    $pattern = '승인|approve|approved|lgtm|진행해'
    if ($prompt -notmatch $pattern) { exit 0 }
    $msg = @"
[APPROVAL REVIEW HOOK]
The user's message contains an approval keyword. If this is an approval of the active feature's spec, plan, or tasks:
1. Do NOT mark anything Approved yet.
2. Run the /approval-review skill first (parallel boundary reviews: security, tenant-data, operability, trends, spec-consistency).
3. Show the review summary and ask the user to confirm; only then set the spec Status to Approved.
If the message is not an approval of feature artifacts (it merely mentions approvals), ignore this notice.
"@
    @{ systemMessage = $msg } | ConvertTo-Json -Compress | Write-Output
    exit 0
} catch {
    exit 0
}
```

- [x] **Step 2: 테스트**

Run: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1 | Select-String 'approval'`
Expected: `PASS approval: keyword …`, `PASS approval: no keyword …`, `PASS approval: lgtm …` 3줄 모두 PASS.

- [x] **Step 3: 커밋**

```bash
git add .claude/hooks/approval-review.ps1
git commit -m "feat(hooks): approval-review 훅 — 승인 키워드 시 /approval-review 지시

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 12: `finish-gate.ps1` (PreToolUse · Skill)

**Files:**
- Create: `.claude/hooks/finish-gate.ps1`
- Test: `tests/hooks/run-hook-tests.ps1` (gate 6케이스)

- [x] **Step 1: 스크립트 작성**

```powershell
# finish-gate hook (PreToolUse, matcher: Skill).
# Denies superpowers:finishing-a-development-branch until the active feature has:
#   reviews/*-finish.md containing "Status: Approved", report.md, content/study/<feature>*.mdx
# Active feature resolution (spec D12): SPECIFY_FEATURE_DIRECTORY -> git branch NNN-slug -> .specify/feature.json.
# Unresolvable or inconsistent -> deny (fail-closed). Script errors -> exit 0 (fail-open).

function Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } |
        ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ($data.tool_name -ne 'Skill') { exit 0 }
    $skill = [string]$data.tool_input.skill
    if ($skill -notmatch 'finishing-a-development-branch') { exit 0 }

    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    Set-Location $root
    $specsDir = Join-Path $root 'specs'
    $candidates = @{}

    if ($env:SPECIFY_FEATURE_DIRECTORY) {
        $p = $env:SPECIFY_FEATURE_DIRECTORY
        if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
        if (Test-Path $p) { $candidates['env'] = (Resolve-Path $p).Path }
    }
    $branch = (git branch --show-current 2>$null)
    if ($branch -and $branch -match '^\d{3,}-[a-z0-9-]+$') {
        $p = Join-Path $specsDir $branch
        if (Test-Path $p) { $candidates['branch'] = (Resolve-Path $p).Path }
    }
    $fj = Join-Path $root '.specify/feature.json'
    if (Test-Path $fj) {
        $j = Get-Content $fj -Raw | ConvertFrom-Json
        $p = [string]$j.feature_directory
        if ($p) {
            if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
            if (Test-Path $p) { $candidates['feature.json'] = (Resolve-Path $p).Path }
        }
    }

    if ($candidates.Count -eq 0) {
        Deny 'finish-gate: active feature could not be resolved (SPECIFY_FEATURE_DIRECTORY, branch NNN-slug, .specify/feature.json all missing). Check out the feature branch or set SPECIFY_FEATURE_DIRECTORY, then run /finish before finishing.'
    }
    $distinct = @($candidates.Values | Sort-Object -Unique)
    if ($distinct.Count -gt 1) {
        $desc = ($candidates.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        Deny "finish-gate: active feature sources disagree ($desc). Align the branch and .specify/feature.json before finishing."
    }
    $feature = $distinct[0]
    $name = Split-Path $feature -Leaf

    $missing = @()
    $finishReview = Get-ChildItem (Join-Path $feature 'reviews') -Filter '*-finish.md' -ErrorAction SilentlyContinue |
        Where-Object { (Get-Content $_.FullName -Raw) -match '(?m)^\s*(\*\*)?Status(\*\*)?:\s*Approved' }
    if (-not $finishReview) { $missing += "reviews/YYYY-MM-DD-finish.md with 'Status: Approved'" }
    if (-not (Test-Path (Join-Path $feature 'report.md'))) { $missing += 'report.md' }
    $study = Get-ChildItem (Join-Path $root 'content/study') -Filter "$name*.mdx" -ErrorAction SilentlyContinue
    if (-not $study) { $missing += "content/study/$name*.mdx" }

    if ($missing.Count -gt 0) {
        Deny ("finish-gate: feature '$name' is not ready to finish. Missing: " + ($missing -join ', ') + '. Run /finish first.')
    }
    exit 0
} catch {
    exit 0
}
```

- [x] **Step 2: 테스트**

Run: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1 | Select-String 'gate'`
Expected: `gate:` 6케이스 모두 PASS(other skill / artifacts missing → deny / present → allow / unresolvable → deny / mismatch → deny / env → allow).

- [x] **Step 3: 커밋**

```bash
git add .claude/hooks/finish-gate.ps1
git commit -m "feat(hooks): finish-gate 훅 — feature 해석(env→브랜치→feature.json) + 마감 산출물 게이트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> **실행 기록 (2026-08-26)**: 품질 리뷰 반영으로 정본(`.claude/hooks/finish-gate.ps1`)은 위 코드 블록과 다르다 — ① 입력 파싱(1단계)만 fail-open, 게이트(2단계)는 예외·git 부재·깨진 feature.json 모두 **deny**(fail-closed); ② 최신 `*-finish.md`의 첫 `Status:` 줄이 정확히 `Approved`(대소문자 구분, `(YYYY-MM-DD)` 허용)일 때만 통과; ③ `.specify/feature.json` 단독 해석 불허(env 또는 `NNN-slug` 브랜치 필수, feature.json은 일치 검사용); ④ report·study는 비어 있지 않은 파일이어야 함; ⑤ 경로 정규화(`GetFullPath` + 끝 구분자 제거), `-LiteralPath`, `git -C $root`; ⑥ `tool_input.name` 폴백. 하네스에 gate 6케이스 추가(총 19).

---

### Task 13: `tester-write-guard.ps1` (tester 에이전트 PreToolUse)

**Files:**
- Create: `.claude/hooks/tester-write-guard.ps1`
- Test: `tests/hooks/run-hook-tests.ps1` (guard 4케이스)

- [x] **Step 1: 스크립트 작성**

```powershell
# tester-write-guard hook (PreToolUse Edit|Write|MultiEdit|NotebookEdit).
# Registered in .claude/agents/tester.md frontmatter, so it only runs inside the tester agent.
# The tester may only write test files; everything else is denied. Errors -> exit 0 (fail-open).

function Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } |
        ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ($data.tool_name -notin @('Edit', 'Write', 'MultiEdit', 'NotebookEdit')) { exit 0 }
    $path = [string]$data.tool_input.file_path
    if (-not $path) { $path = [string]$data.tool_input.notebook_path }
    if (-not $path) { exit 0 }
    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    $norm = $path -replace '\\', '/'
    $rootNorm = ($root -replace '\\', '/').TrimEnd('/')
    if ($norm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $norm = $norm.Substring($rootNorm.Length).TrimStart('/')
    }
    $allowed = @('^tests/', '^e2e/', '(^|/)__tests__/', '\.test\.[^/]+$', '\.spec\.[^/]+$')
    foreach ($re in $allowed) { if ($norm -match $re) { exit 0 } }
    Deny "tester-write-guard: '$norm' is not a test path. The tester may only write under tests/, e2e/, __tests__/ or *.test.* / *.spec.* files. Report the finding instead of changing production code."
} catch {
    exit 0
}
```

- [x] **Step 2: 전체 테스트 GREEN**

Run: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1`
Expected: 마지막 줄 `23 passed, 0 failed`, exit code 0.

- [x] **Step 3: 커밋**

```bash
git add .claude/hooks/tester-write-guard.ps1
git commit -m "feat(hooks): tester-write-guard 훅 — 테스트 경로 외 쓰기 차단

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> **실행 기록 (2026-08-26)**: 품질 리뷰가 우회 3건(`tests/../src` 순회, 저장소 접두 충돌 `…ver2tests\`, 저장소 밖 UNC 경로의 `*.test.*`)을 재현하여 정본(`.claude/hooks/tester-write-guard.ps1`)을 위 코드 블록과 다르게 고쳤다 — `GetFullPath` 정규화 후 저장소 포함 검사(`root/` 접두 필수), 2단계 구조(입력 파싱 fail-open / 경로 판정 fail-closed). 하네스에 guard 4케이스 추가(총 23).

---

### Task 14: `.claude/settings.json` — 권한 deny, 훅 등록, `skillOverrides`

**Files:**
- Create: `.claude/settings.json`

- [x] **Step 1: 기본 파일 작성**

```json
{
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(git reset --hard*)",
      "Bash(git reset --hard)",
      "Bash(git push --force*)",
      "Bash(git push -f*)",
      "Bash(git clean -fd*)",
      "Bash(docker system prune*)"
    ]
  },
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/approval-review.ps1",
            "timeout": 5
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Skill",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/finish-gate.ps1",
            "timeout": 10
          }
        ]
      }
    ]
  },
  "skillOverrides": {}
}
```

- [x] **Step 2: `skillOverrides`를 설치된 speckit-* 스킬 목록에서 생성**

```powershell
$names = (Get-ChildItem .claude/skills -Directory | Where-Object Name -like 'speckit-*').Name
$settings = Get-Content .claude/settings.json -Raw | ConvertFrom-Json -AsHashtable
$settings.skillOverrides = [ordered]@{}
foreach ($n in ($names | Sort-Object)) { $settings.skillOverrides[$n] = 'user-invocable-only' }
$settings | ConvertTo-Json -Depth 10 | Set-Content .claude/settings.json -Encoding utf8
Get-Content .claude/settings.json | Select-String 'user-invocable-only' | Measure-Object | Select-Object -ExpandProperty Count
```
Expected: 마지막 줄이 설치된 `speckit-*` 스킬 수(핵심 10 + git 5 + agent-context 1 + archive 1 = 17).

- [x] **Step 3: JSON 유효성·훅 등록 확인**

Run: `pwsh -NoProfile -c "$s = Get-Content .claude/settings.json -Raw | ConvertFrom-Json; $s.hooks.PreToolUse[0].matcher; $s.hooks.UserPromptSubmit[0].hooks[0].command; $s.permissions.deny.Count"`
Expected: `Skill`, approval-review 명령 문자열, `7`.

- [x] **Step 4: 세션 내 확인 메모**

새 Claude Code 세션에서 `/hooks`에 UserPromptSubmit 1개·PreToolUse(Skill) 1개가 보이고, 일반 대화에서 "speckit-plan 실행해"라고 하지 않는 한 모델이 `speckit-*`를 스스로 호출하지 않는지 확인한다(SC-001·SC-004). 결과는 Task 26 report에 기록.

- [x] **Step 5: 커밋**

```bash
git add .claude/settings.json
git commit -m "feat(claude): settings — 파괴 명령 deny, 훅 2종 등록, speckit-* 명시 호출 전용(skillOverrides)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> **실행 기록 (2026-08-26)**: 리뷰 반영으로 정본은 위 JSON과 다르다 — deny 패턴 16개(`git push * --force*`, `git * reset --hard*`, `rm -r*` 변형, `docker * prune*` 추가), approval 훅 timeout 10s. `skillOverrides`는 17개(핵심 10 + git 5 + agent-context-update + archive-run). 최종 리뷰 반영: `skillOverrides` 값은 `name-only`(`user-invocable-only`는 모델의 모든 Skill 호출을 막아 스킬 연쇄·컨트롤러 호출까지 차단됨을 문서로 확인), `PowerShell(...)` deny 11개 추가(도구별 네임스페이스 분리), 훅 경로는 `${CLAUDE_PROJECT_DIR}` 플레이스홀더(cwd 변경에 견딤).

---

### Task 15: `tester` 에이전트 + 한국어 미러

**Files:**
- Create: `.claude/agents/tester.md`
- Create: `docs/kr/agents/tester_kr.md`

- [x] **Step 1: 에이전트 작성**

```markdown
---
name: tester
description: "End-to-end tester for the active feature. Use when: E2E, user-story verification, acceptance scenarios, tester, 시나리오 검증, 유저 테스트. Executes each User Story from the user's point of view, may write test files only, reports PASS/FAIL/SKIP with reproduction steps."
tools: Read, Grep, Glob, Bash, Edit, Write
hooks:
  PreToolUse:
    - matcher: "Edit|Write|MultiEdit|NotebookEdit"
      hooks:
        - type: command
          command: pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tester-write-guard.ps1
          timeout: 5
---
> Canonical language: English. Korean mirror: docs/kr/agents/tester_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

You are the **tester** for the JoshuaTech v2 repository. Your only job is to verify the active feature's User Stories end-to-end, the way a real user would, and report the evidence.

## Inputs
The controller gives you: the feature directory (`specs/NNN-slug/`), the `## User Scenarios & Testing` section of its `spec.md`, and the test command(s) from `plan.md`. Do not read the whole spec or plan unless a scenario is unclear.

## Rules
- Never modify production code, `spec.md`, `plan.md`, `tasks.md`, or review files. You may create or edit **test files only** (`tests/**`, `e2e/**`, `__tests__/**`, `*.test.*`, `*.spec.*`); a hook denies anything else. If a bug needs a code change, report it — do not fix it.
- Prefer real execution over mocks: run the real command, call the real endpoint, open the real page. If the environment is missing (no server, no database, no browser), mark the scenario SKIP with the exact reason instead of FAIL.
- Exercise exception paths too: invalid input, missing permission, duplicate request, empty and oversized values.
- Run every scenario even after a failure.

## Procedure
1. List the User Stories and their Acceptance Scenarios (Given / When / Then).
2. Check the environment (`git status`, required services, test runner) and record what is available.
3. For each scenario: prepare the Given state, perform the When action with real commands, observe the Then outcome (exit codes, output, files, responses).
4. When a scenario needs an automated test that does not exist yet, write it under a test path, run it, and keep it.
5. Produce the report below and nothing else.

## Report format
```markdown
## E2E Report — <feature>
Environment: <available / missing>

| Story | Scenario | Result | Evidence |
|---|---|---|---|
| US1 | 1 | PASS | `command` → output excerpt |
| US1 | 2 | FAIL | expected X, got Y |
| US2 | 1 | SKIP | no browser available |

### Failures
- **US1-2** (severity: high | medium | low): reproduction steps (exact commands), expected vs actual, suspected location (file:line if known).

### Tests written
- `tests/...` — what it covers
```
```

- [x] **Step 2: 미러 작성**

`docs/kr/agents/tester_kr.md`: 첫 줄 미러 선언(정본 `.claude/agents/tester.md`) 후, frontmatter는 코드 블록으로 그대로 인용하고 본문을 절 구조 유지하며 번역한다.

- [x] **Step 3: 확인**

Run: `pwsh -NoProfile -c "(Get-Content .claude/agents/tester.md -TotalCount 12) -join [Environment]::NewLine"`
Expected: `name: tester`, `tools: Read, Grep, Glob, Bash, Edit, Write`, `hooks:` 블록에 `tester-write-guard.ps1` 경로. 새 세션 `/agents`에 `tester`가 보이는지 Task 24에서 확인.

- [x] **Step 4: 커밋**

```bash
git add .claude/agents/tester.md docs/kr/agents/tester_kr.md
git commit -m "feat(agents): tester 에이전트 — User Story E2E, 테스트 파일만 쓰기(경로 가드)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 16: 경로 규칙 3종 + 한국어 미러

**Files:**
- Create: `.claude/rules/specs.md`, `.claude/rules/docs.md`, `.claude/rules/content.md`
- Create: `docs/kr/rules/specs_kr.md`, `docs/kr/rules/docs_kr.md`, `docs/kr/rules/content_kr.md`

- [x] **Step 1: `.claude/rules/specs.md`**

```markdown
---
paths:
  - "specs/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/specs_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `specs/`

- One feature = one immutable directory `specs/NNN-slug/`, created by Spec Kit (`/speckit-specify`, or `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` when brainstorming writes the spec). Never rename, move, or delete a feature directory; a change of intent is a new feature.
- `spec.md` header `**Status**` values: `Draft` → `Approved (YYYY-MM-DD)` → `Done (YYYY-MM-DD)`. Only `/approval-review` (after the human confirms) sets Approved; only the archive step after merge sets Done.
- Spec Kit files (`spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`, `checklists/`) keep the Spec Kit template headings. Project additions per feature:
  - `reviews/YYYY-MM-DD-approval.md` — one section per boundary, `## 종합 의견`, `## 사용자 결정`.
  - `reviews/YYYY-MM-DD-finish.md` — `Status: Approved | Issues` on line 2, one section per boundary, `## Issues`.
  - `report.md` — `# Report NNN-slug` / `## Summary` / `## Changes Made` / `## Validation` / `## Next`.
- `specs/README.md` is an index table (number, feature, Status, priority, links) regenerated from each `spec.md` header. Change the header, then regenerate; never edit only the table.
- After approval, `spec.md`, `plan.md`, and `tasks.md` are read-only inputs for implementers. Allowed edits: `tasks.md` checkboxes (`[X]`) and phases appended by `/speckit-converge`.
- When dispatching subagents, pass only the task line(s) and the relevant spec/plan sections — never the whole feature directory.
- Prose in Korean; identifiers, slugs, and file names in English/ASCII.
```

- [x] **Step 2: `.claude/rules/docs.md`**

```markdown
---
paths:
  - "docs/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/docs_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `docs/`

- `docs/README.md` is the documentation index; add every new document to it.
- `docs/decisions/NNNN-<kebab-title>.md` follow MADR 4.0 minimal:
  ```markdown
  ---
  status: proposed | accepted | deprecated | superseded by ADR-NNNN
  date: YYYY-MM-DD
  decision-makers: joshua
  ---
  # <Title>
  ## Context and Problem Statement
  ## Considered Options
  ## Decision Outcome
  ### Consequences
  ```
  Numbers are never reused. A changed decision is a new ADR that supersedes the old one; the old body is never edited except its `status`.
- `docs/kr/` mirrors agent files: same relative path plus `_kr` (`docs/kr/CLAUDE_kr.md`, `docs/kr/AGENTS_kr.md`, `docs/kr/constitution_kr.md`, `docs/kr/agents/tester_kr.md`, `docs/kr/skills/<skill>_kr.md`, `docs/kr/rules/<rule>_kr.md`). Mirrors keep headings, tables, code, and identifiers identical and translate prose only. Never place translations inside `.claude/rules/` or `.claude/agents/` (every file there auto-loads). A stale mirror gets a first-line `> translation-pending (YYYY-MM-DD)` note; staleness never blocks a finish.
- `docs/runbooks/` hold operational procedures. `docs/runbooks/spec-kit-upgrade.md` also keeps the customization register: one row per customized Spec Kit file (origin version, origin path, reason, re-verify command).
- Prose in Korean; file names ASCII kebab-case.
```

- [x] **Step 3: `.claude/rules/content.md`**

```markdown
---
paths:
  - "content/**"
---
> Canonical language: English. Korean mirror: docs/kr/rules/content_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# Rules for `content/`

`content/study/*.mdx` are learning-in-public notes consumed by the site (SP-1 onward). Contract:

```yaml
---
title: "..."                        # required; Korean allowed
description: "..."                  # required; one sentence
pubDate: 2026-08-26                 # required; ISO date
updatedDate: 2026-08-27             # optional
tags: ["claude-code", "spec-kit"]   # required; may be empty
series: "sp-0-claude-setup"         # optional
seriesOrder: 1                      # optional integer
draft: true                         # required; generated notes start true, a human flips it to false
change: "001-claude-setup"          # required; the feature directory name
sources:                            # required; may be empty; path = repo path or url
  - { title: "spec", path: "specs/001-claude-setup/spec.md" }
---
```

- File name = `<NNN-slug>.mdx` (ASCII kebab-case). One note per feature; a second note for the same feature gets a `-2` suffix only after asking the human.
- Body sections, in this order: `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. Each must be non-empty.
- Write for a reader who was not in the session: state the concept, why it mattered here, what was rejected and why.
- Never include secrets, tokens, internal hostnames, or personal data.
```

- [x] **Step 4: 미러 3종 작성**

`docs/kr/rules/{specs,docs,content}_kr.md`: 첫 줄 미러 선언(정본 각 `.claude/rules/<name>.md`), frontmatter는 코드 블록으로 인용, 본문 번역(코드 블록·경로·값은 그대로).

- [x] **Step 5: 확인**

Run: `pwsh -NoProfile -c "Get-ChildItem .claude/rules, docs/kr/rules | Select-Object Name; Select-String -Path .claude/rules/*.md -Pattern '^paths:' | Measure-Object | Select-Object -ExpandProperty Count"`
Expected: 파일 6개, `paths:` 3건.

- [x] **Step 6: 커밋**

```bash
git add .claude/rules docs/kr/rules
git commit -m "feat(rules): specs/docs/content 경로 규칙 3종 + kr 미러

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 17: `/approval-review` 스킬 + 경계 5종 + 미러

**Files:**
- Create: `.claude/skills/approval-review/SKILL.md`
- Create: `.claude/skills/approval-review/boundaries/{security,tenant-data,operability,trends,spec-consistency}.md`
- Create: `docs/kr/skills/approval-review_kr.md`

- [x] **Step 1: `SKILL.md`**

```markdown
---
name: approval-review
description: "Run parallel per-boundary subagent reviews (security, tenant-data, operability, trends, spec-consistency) before a feature's spec/plan/tasks is marked Approved. Use when the user approves a feature, says 승인/approve/LGTM, or asks for a pre-approval review."
---
> Canonical language: English. Korean mirror: docs/kr/skills/approval-review_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# approval-review

Gate before implementation. Produces `specs/<feature>/reviews/YYYY-MM-DD-approval.md` and, only after the human confirms, sets the spec Status to Approved.

## 1. Resolve the active feature
In order: `$env:SPECIFY_FEATURE_DIRECTORY` → current git branch `NNN-slug` with `specs/<branch>/` → `.specify/feature.json` `feature_directory`. If none resolves or they disagree, ask the user which feature to review. Read `spec.md`, `plan.md`, `tasks.md`, and `checklists/*.md` if present. If `plan.md` or `tasks.md` is missing, stop and tell the user which Spec Kit command to run.

## 2. Gather machine inputs
- Run `/speckit-analyze` (read-only) and keep its report for the spec-consistency reviewer.
- Count unchecked `- [ ]` items in `checklists/*.md`.

## 3. Dispatch one reviewer per boundary — in parallel, in one message
For each file in `boundaries/` (`security.md`, `tenant-data.md`, `operability.md`, `trends.md`, `spec-consistency.md`) dispatch one `general-purpose` subagent. Prompt:

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
The `trends` reviewer may use WebSearch and must cite URLs; the other four must not fetch anything.

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
- [x] 승인 (YYYY-MM-DD)
```
Status cell values: ✅ 충족 · ⚠️ 보완 · ❌ 위반 · — 해당 없음.

## 5. Ask the human
Show `종합 의견` and the fix list, then use AskUserQuestion with options 승인 / 수정 후 재검토 / 재설계.
- 승인: tick the checkbox with today's date, set `**Status**: Approved (YYYY-MM-DD)` in `spec.md`, regenerate `specs/README.md`, commit `docs(<NNN-slug>): approval 리뷰 및 Status Approved`.
- 수정 후 재검토: list the edits as Spec Kit work (`/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`), then rerun this skill.
- 재설계: stop; the user decides the next step.

## Never
- Never set Approved without the human's explicit answer in step 5.
- Never paste whole files into reviewer prompts; excerpts only.
- Never start implementation from this skill.
```

- [x] **Step 2: `boundaries/security.md`**

```markdown
# Boundary: Security

## Purpose
Find security weaknesses in the design before code exists.

## Checklist
- Authentication and authorization: who may call what; default deny; admin surfaces protected.
- Input validation and injection (SQL/NoSQL/command/template); upload handling; size limits.
- Secrets: none in repo, config, or logs; rotation path stated.
- Data exposure: PII in logs, error bodies, or URLs; verbose error messages.
- Transport and storage: TLS; encryption at rest for sensitive fields; token lifetimes.
- Supply chain: each new dependency, extension, or tool is justified and pinned.
- Abuse: rate limits, enumeration, replay, CSRF/SSRF where relevant.

## Output format
`| 항목 | 상태 | 비고 |` — one row per checklist line, 상태 ∈ ✅/⚠️/❌/—.
`### Findings` — for each ⚠️/❌: severity (high/medium/low), what, where (spec/plan/tasks section), concrete fix.
```

- [x] **Step 3: `boundaries/tenant-data.md`**

```markdown
# Boundary: Tenant & data

## Purpose
Enforce constitution III (Tenant Boundary) and data ownership, even for single-tenant features.

## Checklist
- Every Key Entity names its owner and isolation key (tenant id or equivalent), or states why it is global.
- No cross-service table sharing or implicit joins; cross-boundary reads go through explicit contracts.
- Migrations are backward compatible, reversible, and owned by one service.
- Data lifecycle: retention, deletion, export, backup are addressed or explicitly out of scope.
- Nothing hard-codes a single tenant; tests include an isolation case wherever data exists.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` as in the security boundary.
```

- [x] **Step 4: `boundaries/operability.md`**

```markdown
# Boundary: Operability

## Purpose
Enforce constitution IV (Observability-Ready) and SaaS-grade operations.

## Checklist
- Logs are structured, carry a correlation id, and contain no secrets; health metrics and alert conditions are named.
- Rollback path documented; feature flag or reversible deploy where applicable.
- Failure modes, timeouts, retries, idempotency addressed.
- Runbook need identified (does this feature require a `docs/runbooks/` entry?).
- Cost and limits: quotas, free-tier constraints, rate limits.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` as in the security boundary.
```

- [x] **Step 5: `boundaries/trends.md`**

```markdown
# Boundary: Trends

## Purpose
Check the chosen libraries, tools, and patterns against current practice. WebSearch is allowed; cite URLs.

## Checklist
- Latest stable version and deprecations of each named dependency or tool.
- Recommended patterns versus the plan's approach; known pitfalls.
- Simpler alternatives with lower complexity (constitution V).
- Security advisories affecting the chosen versions.

## Output format
`| 기술 | 현재 plan | 최신 동향 | 제안 | 출처 |` — one row per technology.
`### Findings` — only items that should change the plan, with a URL each.
```

- [x] **Step 6: `boundaries/spec-consistency.md`**

```markdown
# Boundary: Spec consistency

## Purpose
Ensure spec, plan, tasks, checklists, and constitution agree with each other.

## Checklist
- Every FR and User Story is covered by at least one task; every task traces back to a requirement.
- No `[NEEDS CLARIFICATION]` remains; no contradictions between spec and plan.
- Plan's Constitution Check passed, or violations are justified in Complexity Tracking.
- Every user story phase has test tasks written first plus one E2E task for the tester (constitution II).
- `/speckit-analyze` findings triaged: CRITICAL must be fixed before approval; HIGH listed.
- Unchecked checklist items counted and judged blocking or not.

## Output format
`| 항목 | 상태 | 비고 |` per checklist line; `### Findings` listing analyze CRITICAL/HIGH items and uncovered requirements.
```

- [x] **Step 7: 미러 작성**

`docs/kr/skills/approval-review_kr.md`: 미러 선언 후 `SKILL.md` 본문을 번역하고, 끝에 `## Boundaries (요약)` 절로 경계 5종의 목적·체크리스트를 한국어로 요약한다(경계 파일 자체는 미러하지 않는다).

- [x] **Step 8: 확인**

Run: `pwsh -NoProfile -c "Get-ChildItem .claude/skills/approval-review -Recurse -File | Select-Object -ExpandProperty Name; (Get-Content .claude/skills/approval-review/SKILL.md -TotalCount 4) -join ' | '"`
Expected: `SKILL.md, security.md, tenant-data.md, operability.md, trends.md, spec-consistency.md`; frontmatter에 `name: approval-review`.

- [x] **Step 9: 커밋**

```bash
git add .claude/skills/approval-review docs/kr/skills/approval-review_kr.md
git commit -m "feat(skills): approval-review — 경계별 서브에이전트 병렬 리뷰 후 Approved

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 18: `/finish` 스킬 + 경계 4종 + 미러

**Files:**
- Create: `.claude/skills/finish/SKILL.md`
- Create: `.claude/skills/finish/boundaries/{report-vs-diff,e2e-evidence,study-contract,decisions}.md`
- Create: `docs/kr/skills/finish_kr.md`

- [x] **Step 1: `SKILL.md`**

```markdown
---
name: finish
description: "Close the active feature: write report.md, draft the learning note, update CHANGELOG, sync Korean mirrors, and run parallel per-boundary finish reviews so the finish-gate hook lets finishing-a-development-branch proceed. Use when implementation, converge, and E2E are done, or when the finish gate denies finishing."
---
> Canonical language: English. Korean mirror: docs/kr/skills/finish_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# finish

Run after `/speckit-converge` reports Converged and the tester reported PASS (or documented SKIPs). Produces the artifacts the `finish-gate` hook checks: `report.md`, `content/study/<feature>.mdx`, `reviews/YYYY-MM-DD-finish.md` with `Status: Approved`.

## 0. Resolve the feature and preconditions
Resolve the feature as in approval-review (env → branch → feature.json; ask if unresolved or inconsistent). Confirm `tasks.md` has no unchecked `- [ ]` task lines (checklists excluded). If some remain, stop and list them.

## 1. `report.md`
Write `specs/<feature>/report.md`:

```markdown
# Report <NNN-slug>
## Summary
<what was built and why — 3 to 6 lines>
## Changes Made
<one line per file from `git diff --stat $(git merge-base main HEAD)...HEAD`>
## Validation
<test commands and results; converge result; tester report summary (PASS/FAIL/SKIP counts); anything not run and why>
## Next
<follow-ups, deferred items, risks>
```

## 2. Learning note draft
Write `content/study/<NNN-slug>.mdx` following `.claude/rules/content.md`: full frontmatter with `draft: true`, `change: "<NNN-slug>"`, `sources` listing spec, plan, report, and any decisions touched; the five sections `## 문제`, `## 배운 개념`, `## 선택과 대안`, `## 결과와 검증`, `## 다음 학습`. Sources of substance: the spec's decision table, plan Complexity Tracking, approval review findings, the report. If a note already exists, ask before creating a `-2` file.

## 3. CHANGELOG
Under `## [Unreleased]` in `CHANGELOG.md` add one bullet per user-visible change in the right category (Added/Changed/Fixed/Removed), each linking `specs/<NNN-slug>/`.

## 4. Decisions
If the feature made a durable decision (framework, boundary, data ownership, protocol, convention), draft `docs/decisions/NNNN-<title>.md` (MADR minimal, `status: proposed`) — with the adrkit draft command if installed, otherwise by hand — and link it from the report. Otherwise write "no durable decision" in the report's Summary.

## 5. Korean mirrors (best-effort, never blocking)
For each agent file changed in this feature (`CLAUDE.md`, `AGENTS.md`, `.specify/memory/constitution.md`, `.claude/rules/*`, `.claude/agents/*`, `.claude/skills/*/SKILL.md`), update its `docs/kr/` mirror. If context or time is short, prepend `> translation-pending (YYYY-MM-DD)` to the stale mirror instead and mention it in the report.

## 6. Finish review — one subagent per boundary, in parallel
Boundaries in `boundaries/`: `report-vs-diff.md`, `e2e-evidence.md`, `study-contract.md`, `decisions.md`. Dispatch one `general-purpose` subagent each with the boundary file plus exactly the inputs it names. Write `specs/<feature>/reviews/YYYY-MM-DD-finish.md`:

```markdown
# Finish review — <NNN-slug> (YYYY-MM-DD)
Status: Approved | Issues

## Report vs diff
…
## E2E evidence
…
## Study contract
…
## Decisions
…

## Issues
1. … (empty section when Approved)
```
`Status: Approved` only when every boundary reports ✅. On Issues: fix them (report, note, changelog, tests), then rerun step 6 until Approved.

## 7. Hand off
Regenerate `specs/README.md` (Status stays Approved until archive). Commit `docs(<NNN-slug>): report·학습 노트·finish 리뷰`. Tell the user: "finish complete — run superpowers:finishing-a-development-branch; after the merge run the archive skill" and name the archive skill exactly as listed under `.claude/skills/speckit-archive*`.
```

- [x] **Step 2: `boundaries/report-vs-diff.md`**

```markdown
# Boundary: Report vs diff

## Purpose
`report.md` must describe exactly what changed.

## Inputs
`report.md`; output of `git diff --stat $(git merge-base main HEAD)...HEAD`; output of `git log --oneline $(git merge-base main HEAD)..HEAD`.

## Checklist
- Every file in the diff stat appears under Changes Made; nothing is claimed that is absent from the diff.
- Validation claims (commands, counts) match what was actually run; unrun checks are listed as such.
- Next lists every unchecked converge item and every deferred task.
- Commits follow Conventional Commits.

## Output format
`Verdict: ✅ | ❌` then a bullet list of mismatches (file or claim, what is wrong).
```

- [x] **Step 3: `boundaries/e2e-evidence.md`**

```markdown
# Boundary: E2E evidence

## Purpose
Every user story was verified end-to-end and the evidence exists.

## Inputs
The tester's `## E2E Report` (from the conversation or `reviews/`); `spec.md` User Scenarios; the test paths named in the report.

## Checklist
- Every User Story has PASS or a documented SKIP with reason; no unresolved FAIL.
- Test files named in "Tests written" exist under test paths; run them and confirm they pass.
- Exception paths were exercised, not only happy paths.

## Output format
`Verdict: ✅ | ❌` then per-story table `| Story | Result | Evidence ok? |` and a bullet list of gaps.
```

- [x] **Step 4: `boundaries/study-contract.md`**

```markdown
# Boundary: Study contract

## Purpose
The learning note follows `.claude/rules/content.md` and is worth publishing.

## Inputs
`content/study/<NNN-slug>.mdx`; `.claude/rules/content.md`.

## Checklist
- Frontmatter has every required field with valid values; `draft: true`; `change` equals the feature directory name; `sources` non-empty.
- The five sections exist in order and are non-empty; the note explains the concept, the rejected alternatives, and the verification.
- Korean prose, ASCII file name, no secrets or personal data.

## Output format
`Verdict: ✅ | ❌` then a bullet list of contract violations (field or section, what to fix).
```

- [x] **Step 5: `boundaries/decisions.md`**

```markdown
# Boundary: Decisions

## Purpose
Durable decisions are recorded and unrequested changes are justified.

## Inputs
`report.md`; `plan.md` Complexity Tracking; `docs/decisions/` listing; `tasks.md` convergence phases; `.specify/memory/constitution.md`.

## Checklist
- If the feature introduced a framework, boundary, data ownership, protocol, or convention, an ADR exists (status proposed/accepted) and the report links it.
- Constitution amendments, if any, went through the constitution command and bumped the version.
- Converge `unrequested` items were removed or justified in the report.
- Nothing in the change contradicts an accepted ADR.

## Output format
`Verdict: ✅ | ❌` then a bullet list (missing ADR, contradiction, unjustified change).
```

- [x] **Step 6: 미러 작성**

`docs/kr/skills/finish_kr.md`: 미러 선언 후 `SKILL.md` 본문 번역 + `## Boundaries (요약)` 절에 경계 4종 요약.

- [x] **Step 7: 확인**

Run: `pwsh -NoProfile -c "Get-ChildItem .claude/skills/finish -Recurse -File | Select-Object -ExpandProperty Name"`
Expected: `SKILL.md, report-vs-diff.md, e2e-evidence.md, study-contract.md, decisions.md`.

- [x] **Step 8: 커밋**

```bash
git add .claude/skills/finish docs/kr/skills/finish_kr.md
git commit -m "feat(skills): finish — report·학습 노트·CHANGELOG·미러·경계별 finish 리뷰

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

## Phase D — 문서

### Task 19: `AGENTS.md` (EN) + 미러

**Files:**
- Create: `AGENTS.md`
- Create: `docs/kr/AGENTS_kr.md`

- [x] **Step 1: 작성**

```markdown
> Canonical language: English. Korean mirror: docs/kr/AGENTS_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

# AGENTS.md — JoshuaTech v2

## Project
Developer portfolio platform rebuilt from scratch (v1: `d:\code\joshuatech`). Operated with SaaS-grade discipline and multi-tenant-ready boundaries; publishes its own learning notes (learning in public). **Current state (SP-0): tooling and conventions only — no application code. The stack is decided in SP-1.**

## Active agent integration
Spec Kit integration: `claude` only (skills under `.claude/skills/speckit-*`). Other agents (Codex, Gemini, …) read this file, `.specify/memory/constitution.md`, and `specs/<feature>/`. They do not get the Claude hooks, so they must follow the workflow manually and must never edit an approved `spec.md`, `plan.md`, or `tasks.md`.

## Commands
| Purpose | Command |
|---|---|
| Allocate a feature directory (brainstorming path) | `pwsh .specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` |
| Feature paths / prerequisites | `pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json` |
| Hook unit tests | `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1` |
| All repository checks | `pwsh -NoProfile -File tests/run-all.ps1` |
| Regenerate `specs/README.md` | `pwsh -NoProfile -File scripts/update-specs-index.ps1` (added by feature 002-smoke) |
| Spec Kit install / upgrade | `docs/runbooks/spec-kit-upgrade.md` |

## Layout
```
.specify/        Spec Kit runtime: memory/constitution.md, templates/ (+overrides/), scripts/powershell/, extensions/, feature.json (local only)
.claude/         Claude layer: settings.json, skills/, agents/tester.md, rules/, hooks/
specs/           one immutable directory per feature (NNN-slug) + README.md index
docs/            README.md index, decisions/ (MADR), runbooks/, kr/ (Korean mirrors)
content/study/   learning notes (.mdx) consumed by the site
tests/           hook tests and repository checks
```

## Conventions
- Branch = feature directory name (`NNN-slug`), created by the Spec Kit git extension; `main` is integration only; worktrees under `.worktrees/`.
- Commits: Conventional Commits, Korean description allowed (`feat(scope): 설명`); one commit per task; never force-push or rewrite shared history.
- Files: UTF-8, LF, ASCII kebab-case names. Korean prose in specs, docs, and notes; English in agent files and code identifiers.
- Tests first (constitution II). Test files live under `tests/`, `e2e/`, `__tests__/`, or are named `*.test.*` / `*.spec.*`.
- Secrets never enter the repository.

## Workflow (short form)
specify → clarify → plan → checklist → tasks → approval-review → build (TDD, subagent-driven) → converge → E2E (tester) → finish → finishing branch → merge → archive. Details: `CLAUDE.md` and the constitution.
```

- [x] **Step 2: 미러** — `docs/kr/AGENTS_kr.md`(정본 `AGENTS.md`), 표·트리·명령은 그대로.

- [x] **Step 3: 커밋**

```bash
git add AGENTS.md docs/kr/AGENTS_kr.md
git commit -m "docs: AGENTS.md 도구 중립 브리프 + kr 미러

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 20: `CLAUDE.md` (EN, ≤200줄) + 미러

**Files:**
- Create: `CLAUDE.md`
- Create: `docs/kr/CLAUDE_kr.md`

- [x] **Step 1: 작성** — Task 5·6·7에서 기록한 실제 스킬 이름(archive 명령 등)을 8단계와 표에 그대로 쓴다.

```markdown
> Canonical language: English. Korean mirror: docs/kr/CLAUDE_kr.md (convenience only). On conflict, English prevails. Sync: /finish (best-effort).

@AGENTS.md

# CLAUDE.md — how Claude works in this repository

## Prerequisites
- Exactly one superpowers plugin is enabled at user level: `superpowers@superpowers-dev` (5.1.0). Keep `superpowers@claude-plugins-official` disabled (it double-injects the SessionStart hook).
- The Spec Kit CLI (`specify`, installed with `uv`) is needed only for init, upgrade, and extension management; daily commands use `.specify/scripts/powershell/*.ps1`.
- Hooks run as `pwsh -NoProfile -ExecutionPolicy Bypass -File …`; PowerShell 7 must be on PATH.

## Tool boundaries
- **Spec Kit owns WHAT**: constitution, `specs/NNN-slug/{spec,plan,tasks,research,…}`, analyze, converge, archive. `speckit-*` skills are user-invocable only (settings `skillOverrides`); invoke them explicitly, never guess at them.
- **superpowers owns HOW**: brainstorming (architecture-level intake only), test-driven-development, subagent-driven-development, requesting-code-review, receiving-code-review, finishing-a-development-branch, using-git-worktrees, systematic-debugging, verification-before-completion.
- **This repository owns the gates**: the `tester` agent, `/approval-review`, `/finish`, and the hooks in `.claude/hooks/`.
- Do NOT use `speckit-implement`; superpowers subagent-driven-development executes `tasks.md`.
- Do NOT use superpowers `writing-plans`; `tasks.md` is the only implementation plan (the sole exception was `specs/001-claude-setup/plan.md`).
- When brainstorming is used, the design is saved as `specs/NNN-slug/spec.md` in Spec Kit spec-template format: run `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` to allocate the directory, fill that `spec.md`, then continue with `/speckit-plan`.
- Give subagents task slices and the relevant sections only — never whole spec or plan files.
- Read `.specify/memory/constitution.md` before planning and `docs/decisions/` before any architectural change.

## Lifecycle
1. Intake: `/speckit-specify "<description>"` (the git extension creates branch `NNN-slug`) → `/speckit-clarify` when ambiguous. Architecture-level work: superpowers brainstorming → spec.md as above.
2. Plan: `/speckit-plan` → `/speckit-checklist` → `/speckit-tasks`.
3. Approval: when the user approves, run `/approval-review` first; set `**Status**: Approved` only after the user confirms.
4. Build: superpowers subagent-driven-development over `tasks.md` (TDD, per-task review, one commit per task, tick `[X]`).
5. Converge: `/speckit-converge` until it reports Converged.
6. Verify: dispatch the `tester` agent with the feature directory, the spec's User Scenarios section, and the test command.
7. Finish: `/finish`, then `superpowers:finishing-a-development-branch` (the finish-gate hook denies it until the finish artifacts exist).
8. After merge: run the archive skill (`/speckit-archive…` — see `.claude/skills/`) so `.specify/memory/` reflects the merged feature; set the spec Status to Done and regenerate `specs/README.md`.

## Active feature resolution
`SPECIFY_FEATURE_DIRECTORY` → current branch `NNN-slug` ↔ `specs/<branch>/` → `.specify/feature.json`. Sources must agree; if none resolves, ask. `feature.json` is a per-checkout convenience, not the record; the record is the git branch plus `specs/<feature>/`.

## Project-owned hooks, skills, agents
| Item | Location | Role |
|---|---|---|
| approval-review hook | `.claude/hooks/approval-review.ps1` (UserPromptSubmit) | approval keyword → instructs to run `/approval-review` first |
| finish-gate hook | `.claude/hooks/finish-gate.ps1` (PreToolUse, Skill) | denies finishing until finish review Approved + `report.md` + study note exist |
| tester-write-guard | `.claude/hooks/tester-write-guard.ps1` (tester PreToolUse) | the tester may write test paths only |
| `/approval-review` | `.claude/skills/approval-review/` | five boundary subagents → `reviews/*-approval.md` |
| `/finish` | `.claude/skills/finish/` | report, study note, CHANGELOG, mirrors, four boundary subagents → `reviews/*-finish.md` |
| `tester` | `.claude/agents/tester.md` | E2E per user story, PASS/FAIL/SKIP report |
| rules | `.claude/rules/{specs,docs,content}.md` | path-scoped formats and contracts |

Hook tests: `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1`. All checks: `pwsh -NoProfile -File tests/run-all.ps1`.

## Language
Agent files (this file, `AGENTS.md`, the constitution, rules, agents, project skills) are English with mirrors in `docs/kr/`. Conversation, specs, plans, reports, learning notes, and comments are Korean. Identifiers, slugs, and file names are English/ASCII.

## Documentation index
`docs/README.md`.

<!-- SPECKIT START -->
<!-- SPECKIT END -->
```

- [x] **Step 2: 줄 수 확인**

Run: `pwsh -NoProfile -c "(Get-Content CLAUDE.md).Count"`
Expected: `200` 이하(초안은 약 70줄).

- [x] **Step 3: 미러** — `docs/kr/CLAUDE_kr.md`(정본 `CLAUDE.md`). `@AGENTS.md` 줄은 미러에서 `> (정본은 AGENTS.md를 import한다)`로 바꾼다(미러는 import 대상이 아니다).

- [x] **Step 4: 커밋**

```bash
git add CLAUDE.md docs/kr/CLAUDE_kr.md
git commit -m "docs: CLAUDE.md 운영 규칙(도구 경계·라이프사이클·훅 표) + kr 미러

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> **실행 기록 (2026-08-26)**: 정본(57줄)은 위 초안에 두 줄을 더한다 — `/speckit-tasks` 실행 시 override 템플릿의 MANDATORY가 생성 스킬 프롬프트의 "tests optional" 문구보다 우선한다는 규칙(Task 8 리뷰), 훅 상대 경로 때문에 세션 cwd를 루트에 유지하라는 주의(Task 14 리뷰). 8단계의 archive 명령은 실제 이름 `/speckit-archive-run specs/<NNN-slug>`. 배치 실행: Task 14·20·21·23은 병렬 구현 후 컨트롤러가 커밋했고, 미러 제목은 규칙(제목 동일 유지)에 맞춰 영어로 복원했다.

---

### Task 21: 문서 인덱스·ADR·업그레이드 런북·CHANGELOG·README·feature 인덱스

**Files:**
- Create: `docs/README.md`, `docs/decisions/0000-use-madr.md`, `docs/decisions/0001-adopt-spec-kit-with-superpowers.md`, `docs/runbooks/spec-kit-upgrade.md`, `CHANGELOG.md`, `README.md`, `specs/README.md`

- [x] **Step 1: `docs/README.md`**

```markdown
# 문서 인덱스

| 문서 | 내용 |
|---|---|
| [CLAUDE.md](../CLAUDE.md) · [kr](kr/CLAUDE_kr.md) | Claude Code 운영 규칙(도구 경계·라이프사이클·feature 해석·훅) |
| [AGENTS.md](../AGENTS.md) · [kr](kr/AGENTS_kr.md) | 도구 중립 프로젝트 브리프 |
| [constitution](../.specify/memory/constitution.md) · [kr](kr/constitution_kr.md) | 개발 헌법 1.0.0(6원칙·게이트·거버넌스) |
| [decisions/](decisions/) | ADR(MADR 4.0 minimal) |
| [runbooks/spec-kit-upgrade.md](runbooks/spec-kit-upgrade.md) | Spec Kit 커스터마이즈 레지스터·업그레이드 절차 |
| [specs/README.md](../specs/README.md) | feature 인덱스(불변 이력) |
| [content/study/](../content/study/) | 학습 노트(learning in public) |
| [kr/](kr/) | 에이전트 파일 한국어 미러(편의용, 정본은 영어) |
```

- [x] **Step 2: `docs/decisions/0000-use-madr.md`**

```markdown
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
MADR 4.0 minimal을 `docs/decisions/`에 둔다. 번호는 재사용하지 않고, 바뀐 결정은 새 ADR이 이전 ADR을 supersede한다(이전 본문은 `status`만 바꾼다). adrkit 확장이 plan 검토 시 이 디렉터리를 읽는다. 횡단 결정에만 쓴다 — feature 국소 결정은 `spec.md`·`research.md`의 Decision/Rationale/Alternatives로 충분하다.

### Consequences
- 좋음: 에이전트가 계획 전에 결정을 읽는다(CLAUDE.md 포인터); 학습 노트·사이트 콘텐츠의 원천이 된다.
- 나쁨: 결정마다 문서 한 편이 필요하다 — 횡단 결정으로 범위를 제한해 부담을 줄인다.
```

- [x] **Step 3: `docs/decisions/0001-adopt-spec-kit-with-superpowers.md`**

```markdown
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
D를 채택한다. Spec Kit 1.0.1이 constitution·`specs/NNN-slug/`·analyze·converge·archive를 제공하고, superpowers 5.1.0이 SDD·TDD·코드 리뷰·finishing을 수행하며, 프로젝트는 tester 에이전트·approval-review/finish 스킬·결정적 훅으로 게이트를 강제한다. 완료된 feature 디렉터리는 불변 이력(Flow-Forward)이고, 머지 후 archive 확장이 `.specify/memory/`에 현재 상태를 통합한다. 활성 feature는 `SPECIFY_FEATURE_DIRECTORY` → 브랜치명 → `.specify/feature.json` 순으로 해석하며 정본은 git 브랜치 + `specs/<feature>/`다. 근거: `specs/001-claude-setup/spec.md` 결정표 D1–D16과 `research/`.

### Consequences
- 좋음: 표준 산출물·업그레이드 경로·검증된 실행 루프를 동시에 얻는다; converge가 spec 준수를 기계적으로 점검한다.
- 나쁨: 두 도구의 경계 규칙(CLAUDE.md)을 유지해야 하고, Spec Kit 명령 프롬프트가 커서 명시 호출로 제한해야 한다; 커뮤니티 확장 2종은 서드파티 신뢰 검토가 필요하다.
```

- [x] **Step 4: `docs/runbooks/spec-kit-upgrade.md`** — Task 3·5·6·7에서 확인한 실제 버전·스킬 이름을 채운다.

```markdown
# Spec Kit 업그레이드 런북 · 커스터마이즈 레지스터

## 커스터마이즈 레지스터
Spec Kit이 관리하는 파일 중 프로젝트가 손댄 것과, 관리 파일 밖에서 Spec Kit 동작을 바꾸는 설정. 업그레이드 후 "재검증" 열을 전부 수행한다.

| 파일 | 원본 Spec Kit 버전 | 원본 경로 | 변경 이유 | 업그레이드 후 재검증 |
|---|---|---|---|---|
| `.specify/templates/overrides/tasks-template.md` | 1.0.1 | `templates/tasks-template.md` | 테스트 필수화 + 스토리별 E2E task(헌법 II) | `pwsh .specify/scripts/powershell/resolve-template.ps1 tasks-template` 출력에 `MANDATORY` 7건 이상, `OPTIONAL` 0건 |
| `.specify/memory/constitution.md` | 1.0.1 | `templates/constitution-template.md` | 프로젝트 헌법 본문 | 플레이스홀더 `[…]` 0건(`tests/run-all.ps1`) |
| `.specify/extensions/git/git-config.yml` | git ext 1.0.0 | `extensions/git/git-config.yml` | `commit_style: conventional` | `Select-String commit_style .specify/extensions/git/git-config.yml` → conventional |
| `.claude/settings.json` `skillOverrides` | — | (Claude Code 설정) | `speckit-*` 명시 호출 전용 | `tests/run-all.ps1`의 skillOverrides 검사 통과 |
| `CLAUDE.md` `<!-- SPECKIT START/END -->` | agent-context ext 1.0.0 | — | plan 경로 관리 블록 | 마커 2개 존재, 블록 안에 최신 plan 경로 |
| `.specify/extensions/archive/` | archive 1.3.0 (community) | https://github.com/stn1slv/spec-kit-archive | 머지 후 `.specify/memory/` 통합 | 스킬 `speckit-archive…` 존재; 출력 경로 README와 일치 |
| `.specify/extensions/adrkit/` | adrkit 0.1.2 (community) | https://github.com/mbeacom/adrkit | ADR 컨텍스트·검토·초안 | 스킬 `speckit-adrkit-{context,check,draft}` 존재; ADR 디렉터리 설정 = `docs/decisions` |

설치된 확장 명령명(Task 5·6·7 실측): _여기에 `Get-ChildItem .claude/skills` 결과를 붙인다._

## 업그레이드 절차
1. `git status`가 깨끗한지 확인하고 브랜치 `chore/speckit-upgrade-<version>`을 만든다.
2. CLI: `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<tag> --force` (또는 `uv tool upgrade specify-cli`).
3. 프로젝트: `specify upgrade` — **`--force`를 쓰지 않는다**(레지스터의 관리 파일이 덮인다). 충돌이 보고되면 `.specify/integrations/*.manifest.json` diff로 어떤 관리 파일이 바뀌었는지 확인한다.
4. 확장: `specify extension update`.
5. 레지스터의 재검증 열을 모두 수행하고 `pwsh -NoProfile -File tests/run-all.ps1`을 통과시킨다.
6. `CHANGELOG.md` Unreleased에 `Changed: Spec Kit <old> → <new>`를 적는다.
7. 커밋 `chore(speckit): <old> → <new> 업그레이드`, PR 또는 머지.

## 롤백
`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<old-tag> --force` 후 브랜치를 버린다(`.specify/`는 git이 추적하므로 체크아웃으로 복구된다).
```

- [x] **Step 5: `CHANGELOG.md`**

```markdown
# Changelog

이 프로젝트의 주목할 변경 사항을 기록한다. 형식은 [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), 버전은 [SemVer](https://semver.org/)를 따른다.

## [Unreleased]

### Added
- SP-0 Claude Code 기반 셋팅 — Spec Kit 1.0.1(+ git·agent-context·selftest·archive·adrkit 확장), 헌법 1.0.0, tester 에이전트, approval-review/finish 스킬, 훅 3종, 규칙 3종, 문서 정책(ADR·런북·kr 미러), 학습 노트 계약 ([specs/001-claude-setup](specs/001-claude-setup/))
```

- [x] **Step 6: `README.md`**

```markdown
# joshuatech_ver2

개발 포트폴리오 플랫폼 v2 — SaaS급 운영 규율과 learning in public을 목표로 처음부터 다시 만든다. 현재 단계: **SP-0 Claude Code 기반 셋팅**(애플리케이션 스택은 SP-1에서 결정).

- 작업 방식: [CLAUDE.md](CLAUDE.md) · [AGENTS.md](AGENTS.md) · [헌법](.specify/memory/constitution.md)
- feature 이력: [specs/README.md](specs/README.md)
- 문서 인덱스: [docs/README.md](docs/README.md)
- 학습 노트: [content/study/](content/study/)
- 변경 기록: [CHANGELOG.md](CHANGELOG.md)
```

- [x] **Step 7: `specs/README.md`**

```markdown
# Feature 인덱스

각 feature의 `spec.md` 헤더(`**Status**`)에서 재생성한다(002-smoke가 `scripts/update-specs-index.ps1`을 추가할 때까지는 수동). 디렉터리는 이동·삭제하지 않는다(불변 이력). 상태: Draft → Approved → Done.

| # | Feature | Status | 우선순위 | 링크 |
|---|---|---|---|---|
| 001 | Claude Code 기반 셋팅 (SP-0) | Approved (2026-08-26) | 🔴 | [spec](001-claude-setup/spec.md) · [plan](001-claude-setup/plan.md) |
```

- [x] **Step 8: 커밋**

```bash
git add docs README.md CHANGELOG.md specs/README.md
git commit -m "docs: 문서 인덱스, ADR 0000·0001, Spec Kit 업그레이드 런북, CHANGELOG, README, feature 인덱스

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 22: 첫 학습 노트 `content/study/001-claude-setup.mdx`

**Files:**
- Create: `content/study/001-claude-setup.mdx`

- [x] **Step 1: 작성** (계약: `.claude/rules/content.md`)

```mdx
---
title: "AI 에이전트 저장소의 뼈대 세우기 — Spec Kit과 superpowers를 함께 쓰는 법"
description: "포트폴리오 v2를 시작하며 계약(WHAT)과 실행(HOW)을 어떤 도구에 맡길지 정하고, 그 결정을 훅과 스킬로 강제한 과정."
pubDate: 2026-08-26
tags: ["claude-code", "spec-kit", "superpowers", "spec-driven-development", "hooks"]
series: "sp-0-claude-setup"
seriesOrder: 1
draft: true
change: "001-claude-setup"
sources:
  - { title: "spec", path: "specs/001-claude-setup/spec.md" }
  - { title: "plan", path: "specs/001-claude-setup/plan.md" }
  - { title: "research", path: "specs/001-claude-setup/research/2026-08-26-research-summary.md" }
  - { title: "ADR-0001", path: "docs/decisions/0001-adopt-spec-kit-with-superpowers.md" }
  - { title: "Spec Kit", url: "https://github.com/github/spec-kit" }
  - { title: "superpowers", url: "https://github.com/obra/superpowers" }
---

## 문제

v1 포트폴리오는 Django·FastAPI·Next.js를 기술 계층으로 쪼갠 "분산 모놀리스"였고, 에이전트 작업 규칙은 저장소마다 조금씩 다른 자체 컨벤션이었다. v2에서는 (1) 요구사항이 코드보다 먼저 기록되고, (2) 에이전트가 그 요구사항을 벗어나지 못하게 기계적으로 막고, (3) 배운 것이 사이트 콘텐츠로 남는 뼈대가 필요했다.

## 배운 개념

- **Spec-driven development의 공통 패턴**: Spec Kit·OpenSpec·Kiro 모두 "현재 진실"과 "변경 제안"을 분리하고 작업 단위에 번호를 붙인다. Spec Kit은 `specs/NNN-slug/{spec,plan,tasks}.md`와 constitution(온디맨드 거버넌스)을 제공하지만, 완료된 spec을 어떻게 다룰지는 정하지 않는다(Flow-Forward / Living / Flow-Back).
- **WHAT과 HOW의 분리**: 2026년 커뮤니티는 "Spec Kit이 WHAT, superpowers가 HOW"로 수렴했다. `tasks.md`를 인계점으로 삼고 "재계획 금지"를 규칙으로 두면 두 도구가 겹치지 않는다.
- **Claude Code의 결정적 게이트**: 훅은 stdin JSON을 받아 `permissionDecision: deny`로 도구 호출을 막을 수 있고, `settings.json`의 `skillOverrides`로 생성된 스킬을 파일 수정 없이 명시 호출 전용으로 만들 수 있다. 판단이 필요한 검토는 훅이 아니라 스킬이 띄우는 서브에이전트가 맡는다.
- **활성 feature의 정본**: gitignore된 포인터 파일은 worktree마다 다르므로 정본이 될 수 없다. env → 브랜치명 → 포인터 순으로 해석하고, 해석에 실패하면 막는 편(fail-closed)이 안전하다.

## 선택과 대안

| 선택지 | 결과 | 이유 |
|---|---|---|
| egenauto 컨벤션 상속 | 기각 | superpowers와 이중 구조, 학습·자동화 부재 |
| superpowers 단독 | 기각 | E2E 테스터·거버넌스 게이트 부재, Spec Kit 산출물 표준 상실 |
| Spec Kit 단독(`/speckit-implement`) | 기각 | 리뷰 루프·서브에이전트·커밋 규율이 없음 |
| **Spec Kit + superpowers + 프로젝트 게이트** | 채택 | 표준 산출물과 검증된 실행 루프를 동시에 확보 |
| 축소안(확장 0개로 시작) | 부분 기각 | 번들 확장은 비용 0; 커뮤니티 확장 2종은 URL 검토 후 설치 |

## 결과와 검증

훅 3종은 stdin JSON 샘플로 단위 검증했고(13 케이스), `002-smoke`로 specify → plan → tasks → 승인 리뷰 → SDD → converge → E2E → finish → finishing → archive 사이클을 1회 실주행했다. 세부 결과는 `specs/001-claude-setup/report.md`의 Validation 절에 있다.

## 다음 학습

- SP-1: 스택 결정(Cloudflare 네이티브 vs Python MSA vs 하이브리드)과 도메인 규칙·에이전트 추가.
- 병렬 에이전트(Orca 등) 도입 시 worktree별 scope 규칙과 fail-closed 해석의 실제 동작.
- Spec Kit 워크플로우 엔진 오버레이로 헤드리스 사이클을 돌릴 가치가 있는지.
```

- [x] **Step 2: 계약 확인**

Run: `pwsh -NoProfile -c "$t = Get-Content content/study/001-claude-setup.mdx -Raw; @('title:','description:','pubDate:','tags:','draft: true','change: \"001-claude-setup\"','sources:','## 문제','## 배운 개념','## 선택과 대안','## 결과와 검증','## 다음 학습') | ForEach-Object { if ($t -notmatch [regex]::Escape($_)) { \"MISSING $_\" } }; 'checked'"`
Expected: `MISSING` 줄 없이 `checked`만.

- [x] **Step 3: 커밋**

```bash
git add content/study/001-claude-setup.mdx
git commit -m "docs(study): 첫 학습 노트 001-claude-setup (draft)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 23: `tests/run-all.ps1` — 저장소 전체 검사

**Files:**
- Create: `tests/run-all.ps1`

- [x] **Step 1: 작성**

```powershell
# Repository checks. Run: pwsh -NoProfile -File tests/run-all.ps1
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo
$script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { Write-Host "PASS $name" } else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 1. hook unit tests
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/hooks/run-hook-tests.ps1 | Out-Host
Check 'hooks' ($LASTEXITCODE -eq 0) 'see hook test output'

# 2. CLAUDE.md <= 200 lines
$n = (Get-Content CLAUDE.md).Count
Check "CLAUDE.md lines ($n) <= 200" ($n -le 200) ''

# 3. settings.json parses and skillOverrides covers every speckit-* skill
$s = Get-Content .claude/settings.json -Raw | ConvertFrom-Json
$skills = (Get-ChildItem .claude/skills -Directory | Where-Object Name -like 'speckit-*').Name
$missing = @($skills | Where-Object { -not $s.skillOverrides.PSObject.Properties[$_] })
Check 'skillOverrides covers speckit-*' ($missing.Count -eq 0) ($missing -join ', ')
Check 'hooks registered (UserPromptSubmit + PreToolUse Skill)' ($s.hooks.UserPromptSubmit.Count -ge 1 -and $s.hooks.PreToolUse[0].matcher -eq 'Skill') ''

# 4. Korean mirror coverage (SC-005)
$pairs = @{
    'CLAUDE.md'                                = 'docs/kr/CLAUDE_kr.md'
    'AGENTS.md'                                = 'docs/kr/AGENTS_kr.md'
    '.specify/memory/constitution.md'          = 'docs/kr/constitution_kr.md'
    '.claude/agents/tester.md'                 = 'docs/kr/agents/tester_kr.md'
    '.claude/skills/approval-review/SKILL.md'  = 'docs/kr/skills/approval-review_kr.md'
    '.claude/skills/finish/SKILL.md'           = 'docs/kr/skills/finish_kr.md'
    '.claude/rules/specs.md'                   = 'docs/kr/rules/specs_kr.md'
    '.claude/rules/docs.md'                    = 'docs/kr/rules/docs_kr.md'
    '.claude/rules/content.md'                 = 'docs/kr/rules/content_kr.md'
}
$nomirror = @($pairs.Keys | Where-Object { -not (Test-Path $pairs[$_]) })
Check 'kr mirrors present (9)' ($nomirror.Count -eq 0) ($nomirror -join ', ')

# 5. constitution has no template placeholders
$ph = @(Select-String -Path .specify/memory/constitution.md -Pattern '\[[A-Z_0-9]+\]' -AllMatches)
Check 'constitution placeholders = 0' ($ph.Count -eq 0) (($ph | ForEach-Object { $_.Line }) -join ' | ')

# 6. canonical-language header on every agent file
$nohdr = @($pairs.Keys | Where-Object { -not (Select-String -Path $_ -Pattern 'Canonical language: English' -Quiet) })
Check 'canonical-language headers (9)' ($nohdr.Count -eq 0) ($nohdr -join ', ')

# 7. tasks template override active
$resolved = pwsh -NoProfile -File .specify/scripts/powershell/resolve-template.ps1 tasks-template
Check 'tasks-template override (MANDATORY, no OPTIONAL)' ((($resolved | Select-String 'MANDATORY').Count -ge 7) -and (($resolved | Select-String 'OPTIONAL').Count -eq 0)) ''

# 8. every feature dir is indexed in specs/README.md
$dirs = (Get-ChildItem specs -Directory | Where-Object Name -match '^\d{3,}-').Name
$idx = Get-Content specs/README.md -Raw
$unindexed = @($dirs | Where-Object { $idx -notmatch [regex]::Escape($_) })
Check 'specs/README.md indexes every feature' ($unindexed.Count -eq 0) ($unindexed -join ', ')

Write-Host ''
if ($script:fail -eq 0) { Write-Host 'ALL PASS'; exit 0 } else { Write-Host "$($script:fail) FAILED"; exit 1 }
```

- [x] **Step 2: 실행**

Run: `pwsh -NoProfile -File tests/run-all.ps1`
Expected: 8개 검사 모두 `PASS`, 마지막 줄 `ALL PASS`, exit 0. 실패하면 해당 Task로 돌아가 고친다(이 시점에 `specs/002-smoke`는 아직 없으므로 검사 8은 001만 본다).

- [x] **Step 3: 커밋**

```bash
git add tests/run-all.ps1
git commit -m "test: run-all — 훅·CLAUDE.md 줄 수·skillOverrides·kr 미러·헌법·템플릿·인덱스 검사

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

## Phase E — 검증·마감

> Task 24–26은 스킬 호출·서브에이전트 디스패치가 필요하므로 **컨트롤러 세션(사용자와 대화 중인 Claude)** 이 직접 수행한다. 서브에이전트에 위임하지 않는다.

### Task 24: selftest와 세션 등록 확인

**Files:** 없음(검증만)

- [x] **Step 1: 새 세션 시작**

Claude Code를 재시작한다(훅·settings·에이전트·스킬은 세션 시작 시 로드). 시작 로그에 superpowers `using-superpowers` 주입이 **1회**만 보이는지 확인한다(SC-007).

- [x] **Step 2: Spec Kit selftest**

Run: `specify check` (selftest 확장은 카탈로그에 없어 제외)
Expected: git·Claude Code 감지, 오류 없음. 관리 파일 무결성은 `tests/run-all.ps1`과 매니페스트 diff로 확인.

- [x] **Step 3: 등록 확인**

세션 내 `/hooks` → `UserPromptSubmit` 1개(approval-review), `PreToolUse` matcher `Skill` 1개(finish-gate). `/agents` → `tester`. `/skills` → `approval-review`, `finish`, `speckit-*`(user-invocable only 표시). (SC-004)

- [x] **Step 4: 저장소 검사**

Run: `pwsh -NoProfile -File tests/run-all.ps1`
Expected: `ALL PASS`.

- [x] **Step 5: 결과 기록**

Step 1–4의 결과(통과/실패, 실패 시 사유)를 메모해 두고 Task 26의 `report.md` Validation 절에 옮긴다.

---

### Task 25: `002-smoke` — 전체 사이클 실주행 (SC-003)

스모크 작업: **`scripts/update-specs-index.ps1`** — `specs/NNN-slug/spec.md` 헤더(제목·`**Status**`)에서 `specs/README.md` 표를 재생성하는 스크립트. 코드가 작아 사이클 검증에 적합하다.

**Files(사이클이 생성):** `specs/002-smoke/{spec,plan,tasks}.md`, `checklists/`, `reviews/`, `report.md`, `scripts/update-specs-index.ps1`, `tests/scripts/update-specs-index.tests.ps1`, `content/study/002-smoke.mdx`, `CHANGELOG.md` 항목, `CLAUDE.md` SPECKIT 블록

- [x] **Step 1: 시작 상태**

Run: `git status --short; git branch --show-current`
Expected: 변경 없음, 브랜치 `001-claude-setup`.

- [x] **Step 2: specify (git 확장이 브랜치 생성)**

Run (세션 내):
```
/speckit-specify specs/README.md의 feature 인덱스 표를 각 specs/NNN-slug/spec.md 헤더(H1 제목, **Status** 줄)에서 재생성하는 PowerShell 스크립트 scripts/update-specs-index.ps1를 추가한다. 표 열은 번호·Feature·Status·우선순위(spec.md에 **Priority** 줄이 없으면 '—')·링크(spec, plan이 있으면 plan). Status 셀은 `**Status**:` 줄의 값에서 괄호 안 첫 쉼표 이후의 주석을 제거해 `Approved (2026-08-26)` 형태로 정규화한다(예: `Approved (2026-08-26, 외부 리뷰 반영판)` → `Approved (2026-08-26)`). 기존 표의 머리말 문단은 유지한다. short name: smoke
```
Expected: `speckit.git.feature`가 먼저 실행되어 브랜치 `002-smoke` 생성 → `specs/002-smoke/spec.md`(User Story·FR·SC 포함, `[NEEDS CLARIFICATION]` ≤ 3) → `.specify/feature.json`이 `specs/002-smoke`를 가리킴. `git branch --show-current` = `002-smoke`.

- [x] **Step 3: clarify(마커가 있을 때만)**

Run: `/speckit-clarify` — `[NEEDS CLARIFICATION]`가 0개면 건너뛴다.
Expected: 질문 ≤ 5, `## Clarifications` 절 추가.

- [x] **Step 4: plan → checklist → tasks**

Run: `/speckit-plan` → agent-context 확장의 after_plan 프롬프트에 **예** → `/speckit-checklist requirements` → `/speckit-tasks`
Expected: `plan.md`(Constitution Check 통과), `CLAUDE.md`의 `<!-- SPECKIT START/END -->` 사이에 `specs/002-smoke/plan.md` 경로, `checklists/requirements.md`, `tasks.md`에 `### Tests for User Story 1 (MANDATORY` 절과 `E2E:` task가 있음(override 적용 확인: `Select-String -Path specs/002-smoke/tasks.md -Pattern 'MANDATORY|E2E:'` ≥ 2건).

- [x] **Step 5: 승인 훅 → approval-review**

세션에 `승인해줘`라고 입력한다.
Expected: 응답 앞에 `[APPROVAL REVIEW HOOK]` 안내가 반영되어 Claude가 `/approval-review`를 먼저 실행한다 → 서브에이전트 5개 병렬 → `specs/002-smoke/reviews/2026-MM-DD-approval.md`(경계 5절 + 종합 의견) → AskUserQuestion에서 **승인** 선택 → `spec.md` `**Status**: Approved (날짜)` → 커밋. (US2)

- [x] **Step 6: 게이트 부정 케이스**

Run (세션 내): `superpowers:finishing-a-development-branch` 스킬을 호출한다.
Expected: finish-gate가 deny하고 사유에 `Missing: reviews/… 'Status: Approved', report.md, content/study/002-smoke*.mdx` 및 `Run /finish first`가 보인다. (US3-1) 결과를 메모.

- [x] **Step 7: 구현 (SDD)**

Run: `superpowers:subagent-driven-development`로 `specs/002-smoke/tasks.md` 실행. 각 task는 tasks.md의 해당 줄 + plan의 관련 절만 전달.
Expected: 테스트 task가 먼저 RED → 구현 → GREEN, task마다 커밋, `tasks.md` 체크박스 `[X]`. 산출: `scripts/update-specs-index.ps1`, `tests/scripts/update-specs-index.tests.ps1`(pwsh 단독 실행, exit 0/1). `pwsh -NoProfile -File scripts/update-specs-index.ps1` 실행 시 `specs/README.md` 표에 001·002 두 행.

- [x] **Step 8: converge**

Run: `/speckit-converge`
Expected: `✅ Converged`(갭 0) 또는 갭 task 추가 → SDD로 처리 후 재실행하여 Converged.

- [x] **Step 9: E2E tester**

Run: Agent 도구로 `tester` 서브에이전트 디스패치. 프롬프트에 `specs/002-smoke`, `spec.md`의 `## User Scenarios & Testing` 절 전문, 테스트 명령 `pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1`를 넣는다.
Expected: `## E2E Report — 002-smoke`, 모든 스토리 PASS(환경 부재 시 SKIP + 사유). FAIL이 있으면 SDD로 수정 후 재디스패치. (US4)

- [x] **Step 10: finish**

Run: `/finish`
Expected: `specs/002-smoke/report.md`, `content/study/002-smoke.mdx`(frontmatter 계약 충족, `draft: true`, `change: "002-smoke"`), `CHANGELOG.md` Unreleased에 항목, `reviews/2026-MM-DD-finish.md`에 `Status: Approved`, `specs/README.md` 갱신, 커밋. (US5)

- [x] **Step 11: finishing (게이트 통과) → 001로 머지**

Run: `superpowers:finishing-a-development-branch` → 옵션 **1(Merge back to 001-claude-setup locally)**.
Expected: 게이트 통과(출력 없음), 테스트 통과 확인 후 `002-smoke`가 `001-claude-setup`에 머지되고 브랜치 삭제. (US3-2)

- [x] **Step 12: 산출물 점검 + push**

Run: `pwsh -NoProfile -File tests/run-all.ps1; git push origin 001-claude-setup`
Expected: `ALL PASS`(검사 8이 002 포함). 다음 파일이 모두 존재: `specs/002-smoke/{spec.md,plan.md,tasks.md,report.md}`, `specs/002-smoke/reviews/*-approval.md`, `specs/002-smoke/reviews/*-finish.md`, `content/study/002-smoke.mdx`, `scripts/update-specs-index.ps1`, `tests/scripts/update-specs-index.tests.ps1`; `CHANGELOG.md`에 002 항목; `CLAUDE.md` SPECKIT 블록. 원격 `001-claude-setup` 갱신.

---

### Task 26: 001 마감 — finish → finishing → main 머지 → push → archive → Done

**Files:**
- Create: `specs/001-claude-setup/report.md`, `specs/001-claude-setup/reviews/YYYY-MM-DD-finish.md`
- Modify: `specs/001-claude-setup/spec.md`(Status), `specs/002-smoke/spec.md`(Status), `specs/README.md`, `.specify/memory/*`(archive 산출), `CHANGELOG.md`

- [x] **Step 1: 활성 feature를 001로 정렬**

Run: `pwsh -NoProfile -c "Remove-Item .specify/feature.json -ErrorAction SilentlyContinue; git branch --show-current"`
Expected: `001-claude-setup`. (feature.json이 002를 가리키면 finish-gate가 불일치로 deny하므로 제거 → 브랜치 해석)

- [x] **Step 2: `/finish` (001)**

Run: `/finish`
Expected: `specs/001-claude-setup/report.md` — Validation 절에 Task 2(플러그인 단일화), 14(설정), 24(selftest·등록), 25(smoke 산출물·게이트 deny/allow 결과), `tests/run-all.ps1` 결과를 기록. 학습 노트는 Task 22 것을 그대로 인정(`content/study/001-claude-setup*.mdx` 존재). CHANGELOG는 Task 21 항목 유지. 미러 동기화 단계: 001에서 변경된 에이전트 파일은 모두 미러를 갖고 있으므로 "동기화 대상 없음"을 report에 기록(US6 검증). `reviews/YYYY-MM-DD-finish.md` `Status: Approved`.

- [x] **Step 3: finishing → main 머지 → push**

Run: `superpowers:finishing-a-development-branch` → 옵션 **1(Merge back to main locally)** → 이어서 `git push origin main`
Expected: 게이트 통과, `main`에 001 전체가 머지되고 로컬 `001-claude-setup` 삭제. 원격 정리: `git push origin --delete 001-claude-setup`.

- [x] **Step 4: archive (main에서)**

Run (세션 내): Task 6 Step 4에서 기록한 archive 스킬을 `001-claude-setup`, `002-smoke` 순서로 실행.
Expected: `.specify/memory/` 아래 통합본 파일(README가 지정한 경로)에 두 feature 내용이 반영. `git status`에 변경 파일이 보임. (US7)

- [x] **Step 5: Status Done + 인덱스 재생성**

`specs/001-claude-setup/spec.md`와 `specs/002-smoke/spec.md`의 `**Status**` 줄을 `Done (YYYY-MM-DD)`로 바꾼다.
Run: `pwsh -NoProfile -File scripts/update-specs-index.ps1; pwsh -NoProfile -File tests/run-all.ps1`
Expected: `specs/README.md` 두 행 모두 `Done`, `ALL PASS`.

- [x] **Step 6: 커밋·push**

```bash
git add -A
git commit -m "docs(specs): 001·002 archive 반영, Status Done

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push origin main
```
Expected: `git ls-remote --heads origin`에 `main`만(또는 main + 삭제되지 않은 브랜치). SP-0 완료.

---

## 실행 순서 요약

| 순서 | Task | 실행 주체 | 비고 |
|---|---|---|---|
| 1 | 1 → 2 → 3 → 4 | 서브에이전트 가능(2·3은 개발기 도구·사용자 설정이므로 컨트롤러 권장) | 4는 3 완료 후 |
| 2 | 5 → 6 → 7 → 8 → 9 | 서브에이전트 가능 | 6·7은 네트워크·검토 필요 |
| 3 | 10 → 11 → 12 → 13 | 서브에이전트 가능(TDD) | 10이 RED, 13에서 13/13 GREEN |
| 4 | 14 → 15 → 16 → 17 → 18 | 서브에이전트 가능 | 14는 5–7 이후 |
| 5 | 19 → 20 → 21 → 22 → 23 | 서브에이전트 가능 | 20은 5–7의 실제 스킬 이름 필요 |
| 6 | 24 → 25 → 26 | **컨트롤러** | 스킬 호출·서브에이전트 디스패치 |

## 자기 검토 (writing-plans Self-Review)

**Spec 커버리지**
- FR-001 → T1 · FR-002 → T3–T7 · FR-003 → T5 · FR-004 → T2 · FR-005 → T14 · FR-006/007/008/024 → T20 · FR-009 → T16·T17·T18(형식) + T25·T26(실제 산출) · FR-010 → T21·T25 · FR-011 → T21 · FR-012 → T21 · FR-013 → T9·T15–T20(미러) + T23(검사) · FR-014 → T9 · FR-015 → T8 · FR-016 → T13·T15 · FR-017 → T17 · FR-018 → T18 · FR-019 → T11–T13 · FR-020 → T14 · FR-021 → T16 · FR-022/023 → T16·T22 · FR-025 → T19·T21
- SC-001 → T14·T24 · SC-002 → T10–T13 · SC-003 → T25 · SC-004 → T20·T23·T24 · SC-005 → T23 · SC-006 → T21·T23 · SC-007 → T2·T24 · SC-008 → T21 · SC-009 → T1
- US1–US5·US7 → T25, US3 부정 케이스 → T25 Step 6, US6 → T26 Step 2. Edge Cases(feature.json 부재·불일치, 훅 fail-open, 업그레이드, 실행 정책) → T12 테스트 케이스·T21 런북·T14 명령 플래그.

**플레이스홀더 점검**: 런타임에만 알 수 있는 값 3곳(커뮤니티 확장 아카이브 URL, 확장 스킬 실제 이름, adrkit 설정 키)은 확인 명령과 기록 위치를 명시했다. `TBD/TODO` 없음.

**이름 일관성**: 훅 파일명(`approval-review.ps1`, `finish-gate.ps1`, `tester-write-guard.ps1`)은 T10 하네스·T14 settings·T15 에이전트·T20 표에서 동일. 경계 파일명은 T17/T18의 SKILL.md와 파일 목록에서 동일. 미러 경로 9개는 T23 `pairs`와 T16 docs.md 규칙에서 동일. `Status` 값(Draft/Approved/Done)은 T16·T17·T18·T21·T26에서 동일.

**리스크 메모**: (1) `specify init --here`가 대화형 확인을 요구하면 `--force --non-interactive` 조합으로 해결, 그래도 실패 시 데모(`demo-claude`) 산출물을 복사해 동일 결과를 만든다. (2) `skillOverrides` 키 형식이 문서와 다르면 T24에서 드러난다 — 그때는 생성 SKILL.md의 `disable-model-invocation`를 직접 바꾸고 런북 레지스터에 기록한다. (3) archive/adrkit 설치 실패 시 spec Assumptions대로 수동 절차(런북에 기록)로 대체하고 SP-0을 막지 않는다.
