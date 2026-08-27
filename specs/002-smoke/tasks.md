# Tasks: specs 인덱스 재생성 스크립트 (smoke)

**Input**: Design documents from `/specs/002-smoke/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are MANDATORY (constitution II. Test-First). Every user story phase MUST contain (a) test tasks written and observed failing BEFORE implementation tasks and (b) exactly one E2E task per story, executed by the `tester` agent from the user's point of view. Do not omit these sections.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- 단일 스크립트 프로젝트: 스크립트 `scripts/update-specs-index.ps1`, 테스트 `tests/scripts/update-specs-index.tests.ps1`, 저장소 검사 `tests/run-all.ps1` (plan.md Project Structure).
- Test files MUST live under `tests/`, `e2e/`, `__tests__/` or be named `*.test.*` / `*.spec.*` (the tester agent may only write there). tester의 임시 픽스처는 `tests/scripts/fixtures/<guid>/` 아래에 만들고 끝나면 지운다(`$env:TEMP` 사용 금지 — 쓰기 가드 우회 금지).
- 모든 스크립트는 pwsh 7.6.5 이상, UTF-8(BOM 없음)·LF. 테스트는 프레임워크 없는 자체 하네스(`tests/hooks/run-hook-tests.ps1`와 같은 구조: `Assert`, PASS/FAIL 카운트, 임시 픽스처, 종료 코드 0/1). 스크립트 호출 계약은 `contracts/cli.md`.
- 함수 이름은 PowerShell 승인 동사 + 단수 명사(`Get-Verb`; 예: `ConvertTo-NormalizedStatus`, `Remove-Fixture`) — 나중에 PSScriptAnalyzer를 무비용으로 도입할 수 있게.
- 저장소에 기록되는 출력(quickstart 검증 기록, tester 보고서)에서는 절대 경로·계정명을 `<REPO>`/`<TEMP>`로 치환한다.
- 구현 규칙: 한 task = 한 커밋(컨트롤러가 커밋), 같은 파일을 만지는 task는 순차. 테스트 task는 실행해서 **FAIL을 확인한 뒤** 다음 task로 넘어간다.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 테스트 하네스 뼈대 — 모든 스토리의 테스트가 공유한다. 첫 단언 1개로 RED 상태에서 시작한다.

- [X] T001 테스트 하네스 뼈대 작성 `tests/scripts/update-specs-index.tests.ps1`: 헤더 주석(실행법·종료 코드), `$ErrorActionPreference='Stop'`, `$repo`(=`$PSScriptRoot/../..`)와 `$scriptPath`(=`scripts/update-specs-index.ps1`) 해석, `Assert([string]$name,[bool]$cond,[string]$detail)`(PASS/FAIL 출력·카운트), `New-Fixture([hashtable]$files)`(임시 디렉터리 `specidx-<guid>` 생성, 키=상대 경로·값=내용을 `[IO.File]::WriteAllText`+UTF-8 BOM 없음으로 기록, 바이트 배열 값이면 `WriteAllBytes`, `$script:fixtures`에 등록), `Remove-Fixture`(등록된 픽스처 전부 삭제), `Invoke-Script([string]$root)`(`& pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Root $root`를 실행해 `@{ out; err; code }` 반환 — stdout·stderr 분리 캡처, 스크립트 파일이 없으면 `code=127`), 본문은 `try { } finally { Remove-Fixture }`, 끝에 `"$pass passed, $fail failed"` 출력과 `exit 1/0`. **단언 1개**: `specs/` 없는 빈 픽스처에 `-Root` → 종료 코드 1, stderr가 `error: specs directory not found`로 시작(FR-015, Edge Cases). 실행 → `0 passed, 1 failed`, 종료 코드 1(RED — 스크립트가 아직 없음).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 스크립트 파일과 매개변수 계약이 있어야 스토리별 테스트가 "실패"로 시작할 수 있다. T001의 단언을 GREEN으로 만든다.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T002 [P] 스크립트 뼈대 작성 `scripts/update-specs-index.ps1`: 헤더 주석(용도·호출법·종료 코드·contracts/cli.md 요약 + 복구 절차 2줄: "run-all `scripts`/`specs-index-fresh` FAIL → 이 스크립트 실행 후 `specs/README.md` 커밋", "`error: <dir>/spec.md: …` → 지목된 spec 헤더를 고치고 재실행"), `[CmdletBinding()] param([string]$Root)`, `$ErrorActionPreference='Stop'`, `$PSScriptRoot`가 비면 stderr `error: cannot resolve repository root` + `exit 1`, `$Root` 기본값 = `Split-Path $PSScriptRoot -Parent`(저장소 루트, FR-014), `$Root = [IO.Path]::GetFullPath($Root)`로 정규화, `$specsDir`/`$readmePath` 계산, `specs/`가 없으면 stderr `error: specs directory not found: <specsDir>` 후 `exit 1`(Edge Cases). 그 외에는 아직 stderr `error: not implemented` + `exit 1`. 테스트 실행 → `1 passed, 0 failed`, 종료 코드 0(GREEN).

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 인덱스 한 번에 재생성 (Priority: P1) 🎯 MVP

**Goal**: `-Root` 아래 `specs/<NNN-slug>/spec.md` 헤더에서 표를 만들어 `specs/README.md`의 표 블록만 교체한다. 머리말·후행 텍스트 보존, 멱등, cwd 무관, 입력은 읽기 전용.

**Independent Test**: 임시 픽스처(001 = plan.md 있음, 002 = 없음)에서 실행해 표 2행·열·링크가 헤더와 일치하고, 머리말이 그대로이며, 두 번째 실행이 `(unchanged)`인지 확인한다.

### Tests for User Story 1 (MANDATORY — write first, verify they FAIL) ⚠️

> **NOTE: Write these tests FIRST, run them, and confirm they FAIL before any implementation task below**

- [X] T003 [US1] `tests/scripts/update-specs-index.tests.ps1`에 US1 단언 추가(기본 픽스처: `specs/README.md` = 머리말 2문단 + 기존 표(임의 내용, 헤더 `| # | Feature | Status | 우선순위 | 링크 |`) + 후행 문단 `> 후행 텍스트`; `specs/001-alpha/spec.md` = `# Feature Specification: 알파 (SP-0)` + `**Status**: Approved (2026-08-26)` + `**Priority**: 🔴`(빈 줄 없이 연속), `specs/001-alpha/plan.md` 존재; `specs/002-beta/spec.md` = 템플릿 형식(헤더 줄 사이 빈 줄) `# Feature Specification: 베타` + `**Status**: Draft`, plan 없음): (1) US1-1 종료 코드 0, stdout `specs/README.md: 2 features indexed`, README에 정확히 `| # | Feature | Status | 우선순위 | 링크 |`, `|---|---|---|---|---|`, `| 001 | 알파 (SP-0) | Approved (2026-08-26) | 🔴 | [spec](001-alpha/spec.md) · [plan](001-alpha/plan.md) |`, `| 002 | 베타 | Draft | — | [spec](002-beta/spec.md) |` 순서로 4줄이고 `| # |` 헤더 행은 1개뿐(FR-005/006); (2) US1-2 표 앞 머리말과 표 뒤 후행 문단이 실행 전과 문자 단위로 동일(FR-007); (3) US1-3 두 번째 실행 stdout에 `(unchanged)`, 파일 내용·LastWriteTime 불변(FR-008); (4) US1-4 픽스처에 `scripts/`를 만들어 스크립트를 복사한 뒤 `Push-Location $env:TEMP` … `finally { Pop-Location }`에서 `-Root` 없이 실행 → 픽스처의 README가 갱신되고 `$env:TEMP/specs/README.md`는 생기지 않음(FR-014); (5) 출력 파일 첫 3바이트가 BOM(`EF BB BF`)이 아니고 `\r` 없음(FR-012); (6) 실행 후 픽스처의 각 `spec.md`·`plan.md` 내용과 LastWriteTime 불변, 그리고 픽스처 실행 전후 실제 저장소 `specs/README.md`의 LastWriteTime 불변(입력 읽기 전용·격리). 실행: `pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1` → US1 단언 전부 FAIL, 종료 코드 1 확인.

### Implementation for User Story 1

- [X] T004 [US1] `scripts/update-specs-index.ps1`에 수집·파싱 구현(plan §Implementation Approach 1, research R1·R8): `Get-ChildItem $specsDir -Directory -Attributes !ReparsePoint | Where-Object Name -match '^[0-9]{3,}-[A-Za-z0-9][A-Za-z0-9-]*$'`(ASCII 숫자만, 정션·심볼릭 링크 제외); 각 디렉터리에서 `spec.md`를 `[IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false, $true))`(잘못된 바이트는 예외 → T011의 catch가 `error:`로 보고)로 읽어 BOM 제거·`\r\n`→`\n` 정규화 후 줄 배열로 분리; 첫 `^#\s+(.+?)\s*$` → 제목(`^Feature Specification:\s*` 제거·Trim, FR-002), 첫 `^\*\*Status\*\*:\s*(.+?)\s*$` → statusRaw, 첫 `^\*\*Priority\*\*:\s*(.+?)\s*$` → priority(없으면 `—`, FR-004) — 각각 첫 매치만; `Test-Path (Join-Path $dir 'plan.md') -PathType Leaf` → hasPlan; 항목 객체 `[pscustomobject]@{ Dir; Number(문자열); Title; Status; Priority; HasPlan }` 목록을 **캐스트 없이** (Number.Length, Number ordinal, Dir ordinal) 순으로 정렬(`[StringComparer]::Ordinal`; 20자리 이상도 안전). (H1/Status 누락 처리는 T011에서 — 여기서는 누락 시 빈 문자열.)
- [X] T005 [US1] `scripts/update-specs-index.ps1`에 표 조립·README 병합·쓰기 구현(plan §4–6, research R2·R4): 셀 이스케이프는 `\`→`\\` **먼저**, 그다음 `|`→`\|`(FR-013; 이미 `\|`인 값도 깨지지 않음); 행 `| <Number> | <Title> | <Status> | <Priority> | [spec](<Dir>/spec.md)[ · [plan](<Dir>/plan.md)] |`; 표 = 헤더+구분+행들을 `\n`으로 결합. README가 있으면 원문(`$raw`)을 읽고 BOM 제거·LF 정규화한 `$text`의 줄 배열에서 `^\| # \|` 줄을 찾는다 — 0개면 `text.TrimEnd() + "\n\n" + table + "\n"`, 1개면 그 줄부터 연속된 `^\|` 줄 블록을 표로 간주해 `preamble + table + trailer` 재결합, **2개 이상이면 stderr `error: specs/README.md: multiple index tables` + `exit 1`(미기록)**; 파일 없음 → `"# Feature 인덱스\n\n각 feature의 ``spec.md`` 헤더에서 ``scripts/update-specs-index.ps1``로 재생성한다. 디렉터리는 이동·삭제하지 않는다(불변 이력). 상태: Draft → Approved → Done.\n\n" + table + "\n"`(FR-011). 비교는 **디스크 원문 `$raw`와** 수행(CRLF/BOM README는 1회 LF·BOM 없음으로 재기록되고 그 뒤 `(unchanged)`): 같으면 쓰지 않고 stdout `specs/README.md: N features indexed (unchanged)`, 다르면 같은 디렉터리의 `README.md.<guid>.tmp`에 `[IO.File]::WriteAllText($tmp, $new, [Text.UTF8Encoding]::new($false))` 후 `[IO.File]::Move($tmp, $readmePath, $true)`(원자적 교체, 실패 시 tmp 삭제) 후 `specs/README.md: N features indexed`; `exit 0`. `not implemented` 제거. 테스트 실행 → T001+US1 단언 전부 PASS.

### E2E for User Story 1 (MANDATORY — executed by the tester agent)

- [ ] T006 [US1] E2E(Polish T013 이후 tester가 T009·T012와 함께 1회 dispatch로 실행): 사용자 관점 — (a) 저장소 실물에서 `pwsh -NoProfile -File scripts/update-specs-index.ps1` 실행 → stdout `specs/README.md: 2 features indexed (unchanged)`, `git diff --exit-code -- specs/README.md`가 0(저장소 파일을 바꾸지 않음), `specs/README.md` 표에 001·002 두 행이 각 `spec.md` 헤더와 일치하고 `| # |` 헤더 행 1개, 머리말 문단 존재; (b) 두 번째 실행도 `(unchanged)`(US1-3); (c) `Set-Location $env:TEMP` 후 절대 경로로 실행해도 같은 결과(US1-4); (d) `tests/scripts/fixtures/<guid>/`에 001·002 spec 사본으로 만든 임시 픽스처(`-Root`)에서 표가 새로 생성되어 (a)와 같은 행이 나오고, 끝나면 픽스처 삭제 — evidence recorded in the tester report(경로는 `<REPO>`/`<TEMP>`로 치환)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Status 값 정규화 (Priority: P2)

**Goal**: `**Status**` 값의 첫 괄호 그룹에서 첫 쉼표 이후 주석을 제거해 `상태 (날짜)`로 통일한다.

**Independent Test**: 주석 있음 / 날짜만 / 괄호 없음 세 spec을 가진 픽스처에서 Status 셀을 비교한다.

### Tests for User Story 2 (MANDATORY — write first, verify they FAIL) ⚠️

- [X] T007 [US2] `tests/scripts/update-specs-index.tests.ps1`에 US2 단언 추가(픽스처: `010-a` Status `Approved (2026-08-26, 외부 리뷰 반영판)`, `011-b` Status `Done (2026-08-27)`, `012-c` Status `Draft`, `013-d` Status `Approved (2026-08-26, 주석) (extra)`, `014-e` Status `Approved (2026-08-26,주석)`): 셀이 각각 `Approved (2026-08-26)`, `Done (2026-08-27)`, `Draft`, `Approved (2026-08-26) (extra)`(첫 괄호 그룹만 치환, research R7), `Approved (2026-08-26)`(쉼표 뒤 공백 없음)(FR-003). 실행 → 주석 케이스 FAIL 확인.

### Implementation for User Story 2

- [X] T008 [US2] `scripts/update-specs-index.ps1`에 정규화 함수 `ConvertTo-NormalizedStatus([string]$s)` 추가: `[regex]::new('\(([^,)]*),[^)]*\)').Replace($s, '($1)', 1)` (첫 그룹 1회만), 결과 Trim; T004의 statusRaw에 적용. 테스트 실행 → US1+US2 PASS.

### E2E for User Story 2 (MANDATORY — executed by the tester agent)

- [ ] T009 [US2] E2E(T013 이후): 실행 시점의 `specs/001-claude-setup/spec.md` `**Status**` 헤더 값 X를 기록하고, 저장소 실물 실행 후 `specs/README.md`의 001 행 Status 셀이 X에 "첫 괄호 안 첫 쉼표 이후 제거·괄호 닫힘" 규칙을 적용한 값과 같은지 확인(2026-08-27 기준 X = `Approved (2026-08-26, 외부 리뷰 반영판)` → 셀 `Approved (2026-08-26)`); X에 주석이 없으면 `tests/scripts/fixtures/<guid>/`의 T007 픽스처 사본으로 대체 검증; 002 행은 헤더 값 그대로 — evidence recorded in the tester report

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - 결측값과 예외 상황 처리 (Priority: P3)

**Goal**: 결측은 `—`/생략으로 표시하고, 비-feature 항목은 무시(디렉터리는 경고)하며, 헤더가 깨진 spec·읽을 수 없는 입력·쓸 수 없는 README·표 중복이 있으면 README를 건드리지 않고 `error:` 한 줄로 실패한다. README 부재·표 부재·특수문자·BOM/CRLF 입력·feature 0개·번호 중복·중복 헤더 줄·성능까지 계약대로.

**Independent Test**: 각 예외 픽스처에서 셀 값, stderr 메시지, 종료 코드, README 변경 여부를 확인한다.

### Tests for User Story 3 (MANDATORY — write first, verify they FAIL) ⚠️

- [X] T010 [US3] `tests/scripts/update-specs-index.tests.ps1`에 US3·Edge 단언 추가: (1) Priority 줄 없음 → `—`, 있음 → 값(US3-1/2); (2) plan.md 없음 → 링크 셀 `[spec](…)`만(US3-3); (3) `specs/README.md`·`specs/notes/`(비-NNN 디렉터리)·`specs/zz-x/`는 표에 없고 stderr 비어 있음, `specs/020-empty/`(spec.md 없음)는 표에 없고 stderr에 `warning: skip 020-empty: spec.md missing`, 종료 코드 0(US3-4, FR-010); (4) `specs/030-bad/spec.md`에 Status 줄 없음 → stderr `error: 030-bad/spec.md: missing **Status** line`, 종료 코드 1, README 내용·LastWriteTime 불변(US3-5, FR-009); H1 없음 → `error: 031-noh1/spec.md: missing H1 title`; 두 오류가 있으면 두 줄 모두 출력; (5) `-Root`에 `specs/`가 없음 → stderr가 `error: specs directory not found`로 시작, 종료 코드 1(T001 단언과 중복 허용); (6) feature 0개(빈 `specs/`) → README에 헤더+구분 행만, 종료 코드 0; (7) 같은 번호 `040-a-b`·`040-ab` → 두 행 모두, ordinal 순(`040-a-b`가 먼저: `-`(0x2D) < `a`); (8) 제목 `A | B` → 셀 `A \| B`, 제목 `A \| B` → 셀 `A \\\| B`; H1이 `# 그냥 제목` → 셀 `그냥 제목`; (9) spec.md가 BOM+CRLF → 결과 동일; (10) README 없음 → 기본 머리말(`# Feature 인덱스`로 시작)+표 생성; README에 표 없음(머리말만, 끝 개행 없음) → `머리말\n\n표\n`, 두 번째 실행 `(unchanged)`; (11) feature 100개 픽스처 → 종료 코드 0, 경과 5초 미만(`[Diagnostics.Stopwatch]`, SC-005); (12) `050-dup/spec.md`에 `**Status**: Draft` 뒤 `**Status**: Done (2026-01-01)`, `**Priority**: 🔴` 뒤 `**Priority**: 🟢` → 셀 `Draft`·`🔴`(첫 줄만); (13) `060-bin/spec.md`가 잘못된 UTF-8 바이트(예: `0xC3 0x28`) 포함 → stderr 첫 줄이 `error:`로 시작, 종료 코드 1, README 불변; (14) README가 `IsReadOnly = $true`이고 변경이 필요한 입력 → 종료 코드 1, stderr 첫 줄 `error:`, README 내용·LastWriteTime 불변(I/O 실패 계약); (15) README가 BOM+CRLF → 첫 실행은 `(unchanged)` 없이 재기록되어 결과가 BOM 없음·`\r` 없음, 두 번째 실행 `(unchanged)`; (16) README에 `| # |` 헤더 행이 2개 → stderr `error: specs/README.md: multiple index tables`, 종료 코드 1, README 불변. 실행 → 미구현 케이스 FAIL 확인(경고·오류·빈 표·README 없음·읽기 전용 등).

### Implementation for User Story 3

- [X] T011 [US3] `scripts/update-specs-index.ps1`에 예외 처리 구현(plan §2·§6, research R3): 본문 전체를 `try { … } catch { [Console]::Error.WriteLine("error: $($_.Exception.GetBaseException().Message)"); exit 1 }`로 감싸 모든 I/O·디코딩 예외가 계약된 한 줄 + exit 1로 끝나게(스택·PowerShell 오류 덤프 금지); `spec.md` 없는 NNN 디렉터리 → `[Console]::Error.WriteLine("warning: skip $dir: spec.md missing")` 후 건너뜀; 파싱 중 H1/Status 누락은 `$errors += "error: $dir/spec.md: missing H1 title"` / `missing **Status** line`로 수집하고 순회 후 `$errors.Count -gt 0`이면 모두 stderr 출력 + `exit 1`(README 읽기·쓰기 전에); feature 0개면 헤더+구분 행만; README 없음/표 없음/표 중복 분기·`\`·`|` 이스케이프·BOM/CRLF 정규화·원자적 쓰기가 T005 구현에서 빠졌다면 보완; 100개 처리에 파일당 1회 읽기만 하도록 확인. 테스트 실행 → 전부 PASS, 종료 코드 0.

### E2E for User Story 3 (MANDATORY — executed by the tester agent)

- [ ] T012 [US3] E2E(T013 이후): 사용자 관점 — `tests/scripts/fixtures/<guid>/`(쓰기 가드 허용 범위)에 `specs/001-x/spec.md`(Priority 없음, plan 없음)와 `specs/002-y/spec.md`(Status 줄 없음)를 만들고 `-Root`로 실행 → stderr에 `error: 002-y/spec.md: missing **Status** line`, 종료 코드 1, README 미생성; `002-y`의 Status를 추가하고 재실행 → 종료 코드 0, README 생성, 001 행 우선순위 `—`·링크 spec만, 002 행 존재; 끝나면 픽스처 삭제 — evidence recorded in the tester report(경로는 `<REPO>`/`<TEMP>`로 치환)

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 저장소 실물 적용, 검사 등록, 문서 문구 정리, quickstart 검증.

- [X] T013 저장소 실물 적용: `pwsh -NoProfile -File scripts/update-specs-index.ps1` 실행 → `specs/README.md` 표가 001(`Approved (2026-08-26)`, 우선순위 `—`, spec+plan)·002(헤더 Status, spec+plan) 두 행으로 재생성되고 `| # |` 헤더 행이 1개(기존 표가 교체됨, 중복 없음)임을 확인(001 `🔴`→`—`는 spec Assumptions대로); 머리말 문단의 "(002-smoke가 `scripts/update-specs-index.ps1`을 추가할 때까지는 수동)"을 "`pwsh -NoProfile -File scripts/update-specs-index.ps1`로 재생성한다"는 문구로 고친 뒤 스크립트를 한 번 더 실행해 `(unchanged)` 확인.
- [X] T014 `tests/run-all.ps1`에 검사 2개 추가(1번 hooks 검사 바로 뒤, 주석 `# 1b. scripts tests`, `# 1c. specs index freshness`): `pwsh -NoProfile -ExecutionPolicy Bypass -File tests/scripts/update-specs-index.tests.ps1 | Out-Host; Check 'scripts' ($LASTEXITCODE -eq 0) 'see scripts test output'` 그리고 `$o = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/update-specs-index.ps1 2>&1 | Out-String; Check 'specs-index-fresh' ($LASTEXITCODE -eq 0 -and $o -match '\(unchanged\)') 'specs/README.md was stale (regenerated now) - review and commit'`(주석: 이 검사는 낡은 인덱스를 발견하면 파일을 갱신하는 부작용이 있다). 실행 → `PASS scripts`·`PASS specs-index-fresh` 포함 `ALL PASS`.
- [X] T015 [P] `AGENTS.md` Commands 표의 "Regenerate `specs/README.md`" 행에서 "(added by feature 002-smoke)" 제거; `docs/kr/AGENTS_kr.md`의 같은 행도 동일하게 정리(영어 제목 유지).
- [X] T016 quickstart.md 검증 실행(1·2·3·4·6 단계) 후 실제 출력(stdout 문구, `N passed, 0 failed`, `ALL PASS`)을 `specs/002-smoke/quickstart.md` 끝에 `## 검증 기록 (YYYY-MM-DD)` 절로 기록(절대 경로·계정명은 `<REPO>`/`<TEMP>`로 치환).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존 없음 — 즉시 시작(RED 1건)
- **Foundational (Phase 2)**: T001 이후(T001의 단언을 GREEN으로) — 다른 파일이지만 RED→GREEN 순서를 위해 T001 다음에 실행
- **User Stories (Phase 3+)**: US1 → US2 → US3 순차(모두 같은 두 파일을 수정하므로 병렬 불가; 스토리 자체는 독립적으로 테스트 가능)
- **Polish (Phase 6)**: 세 스토리 완료 후. T015는 T013·T014와 병렬 가능
- **E2E (T006·T009·T012)**: Polish T013 이후 tester 1회 dispatch로 함께 실행(저장소 실물이 최종 상태여야 `(unchanged)` 시나리오가 성립하고 tester가 `tests/` 밖 파일을 바꾸지 않음) — CLAUDE.md lifecycle 6(Verify)과 일치

### User Story Dependencies

- **US1 (P1)**: Foundational 이후. 다른 스토리에 의존 없음
- **US2 (P2)**: US1의 파싱 결과(statusRaw)에 정규화를 얹음 — 코드 의존은 있으나 픽스처로 독립 검증
- **US3 (P3)**: US1·US2의 파이프라인에 예외 분기를 추가 — 독립 픽스처로 검증

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- 파싱(T004) → 조립·쓰기(T005) 순
- E2E task runs last in the story and is executed by the tester agent, never by the implementer
- Story complete before moving to next priority

### Parallel Opportunities

- T015 ∥ T013/T014 (다른 파일)
- 그 외는 같은 파일(`scripts/update-specs-index.ps1`, `tests/scripts/update-specs-index.tests.ps1`)을 순차 수정

---

## Parallel Example: Polish

```bash
# 동시에 실행 가능(다른 파일):
Task: "T013 저장소 실물 적용 + specs/README.md 머리말 문구"
Task: "T015 AGENTS.md / docs/kr/AGENTS_kr.md 문구 정리"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 + 2 (T001 RED → T002 GREEN)
2. Phase 3 (T003 RED → T004·T005 GREEN)
3. **STOP and VALIDATE**: 픽스처에서 US1 독립 검증
4. 이 시점에 저장소 실물에도 적용 가능(정규화 없이 Status 원문 표시)

### Incremental Delivery

1. US1 → 표 재생성(MVP)
2. US2 → Status 정규화
3. US3 → 결측·예외·I/O 실패·성능
4. Polish → 실물 적용·run-all 등록·문구 정리·quickstart 기록
5. E2E(tester) → converge → finish

### Parallel Team Strategy

단일 스크립트·단일 테스트 파일이므로 병렬은 T015∥T013/T014에 한정. 001 계획의 실행 방식(독립 구현자 병렬 배치, 커밋은 컨트롤러)은 여기서는 순차 배치로 축소한다.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- 서브에이전트에는 해당 task 줄 + plan의 §Implementation Approach 해당 항목 + contracts/cli.md만 전달한다(전체 spec/plan 금지)
- 2026-08-27 approval review 반영: T001 RED 단언·`Remove-Fixture`, T002 경로 정규화·복구 주석, T003(4)(6), T004 ASCII 숫자·캐스트 없는 ordinal 정렬·strict UTF-8·reparse 제외, T005 `\` 선행 이스케이프·표 중복 오류·원문 비교·원자적 쓰기, T008 승인 동사, T010(7)(8)(12)–(16), T011 try/catch, T006/T009/T012 tester 경계·경로 치환, T013 표 1개 확인, T014 `specs-index-fresh`

---

## Phase 7: Convergence

- [X] T017 [US2] `scripts/update-specs-index.ps1`의 `ConvertTo-NormalizedStatus`를 **첫 괄호 그룹**에 앵커 — 정규식 `^([^(]*\()([^,)]*),[^)]*\)` → 치환 `$1$2)`(1회, Trim 유지); `tests/scripts/update-specs-index.tests.ps1` US2에 단언 추가: `Approved (2026-08-26) (note, x)` → 원문 그대로(첫 괄호에 쉼표 없음), `Approved (2026-08-26, 주석) (extra, y)` → `Approved (2026-08-26) (extra, y)`; RED 확인 후 GREEN per FR-003 · Edge Cases "괄호 안에 쉼표가 없으면 그대로" (contradicts)
- [X] T018 [P] `AGENTS.md` Commands 표 "Regenerate `specs/README.md`" 행에 복구 힌트를 같은 행에 덧붙임: "if run-all `scripts`/`specs-index-fresh` fails: run it, then commit `specs/README.md`; on `error: <dir>/spec.md: …`: fix that spec header and rerun"; `docs/kr/AGENTS_kr.md`의 같은 행에 한국어로 동일 반영(영어 제목 유지) per plan §Observability & Rollback "복구 절차는 스크립트 헤더 주석과 AGENTS.md Commands 행" (partial)
- [ ] T019 `/finish`가 쓰는 `specs/002-smoke/report.md` Changes Made에 계약 외 동작 2건을 기록: (a) 읽기 전용 README 사전 검사 메시지 `error: specs/README.md is read-only: <path>`(계약의 "I/O 실패 → `error:` 한 줄" 범주, approval review Ops 2·Sec F6 반영), (b) 빈 README(0바이트·공백뿐)는 선행 빈 줄 없이 표부터 기록(approval review Minor 반영) per contracts/cli.md §출력 · plan §Implementation Approach 5 (unrequested)
