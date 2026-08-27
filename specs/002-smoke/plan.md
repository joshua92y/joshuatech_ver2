# Implementation Plan: specs 인덱스 재생성 스크립트 (smoke)

**Branch**: `002-smoke` | **Date**: 2026-08-27 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-smoke/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

`specs/README.md`의 feature 인덱스 표를 각 `specs/NNN-slug/spec.md` 헤더(H1 제목, `**Status**`, 선택 `**Priority**`, `plan.md` 존재 여부)에서 재생성하는 단일 PowerShell 스크립트 `scripts/update-specs-index.ps1`를 추가한다. 표 블록만 교체하고 머리말·후행 텍스트는 보존하며, Status는 `Approved (2026-08-26, 주석)` → `Approved (2026-08-26)`으로 정규화한다. 헤더가 깨진 spec·읽을 수 없는 입력·쓸 수 없는 README·표 중복이 있으면 아무것도 쓰지 않고 `error:` 한 줄로 실패한다(fail-closed). 검증은 프레임워크 없는 pwsh 하네스(`tests/scripts/update-specs-index.tests.ps1`)로 하고 `tests/run-all.ps1`에 `scripts`·`specs-index-fresh` 검사로 등록한다. 이 feature는 SP-0 스모크 테스트(001 SC-003)로서 specify→…→finish→머지 전체 사이클을 실주행한다.

## Technical Context

**Language/Version**: PowerShell 7.6 LTS — `pwsh` **7.6.5 이상**(2026-08-17 보안 수정 CVE-2026-50523/70337/70338 포함; 개발기 7.6.5; 7.4/7.5는 2026-11-10 EOS). 훅·검사 스크립트와 동일. .NET 내장 API만 사용

**Primary Dependencies**: 없음(외부 모듈·git 호출 없음). `System.IO.File`, `System.Text.UTF8Encoding`, `System.Text.RegularExpressions`

**Storage**: 파일 — 입력 `specs/<NNN-slug>/{spec.md,plan.md}`(읽기 전용; 스크립트는 입력을 쓰거나 지우지 않는다), 출력 `specs/README.md`(유일한 쓰기 대상). 파일·디렉터리 삭제 없음. 이력·백업·롤백은 git

**Testing**: 자체 하네스 `tests/scripts/update-specs-index.tests.ps1`(임시 픽스처, Assert, 종료 코드 0/1; `tests/hooks/run-hook-tests.ps1`와 같은 구조) + `tests/run-all.ps1` 검사 항목 `scripts`(테스트)·`specs-index-fresh`(실물 인덱스가 최신인지) + tester E2E

**Target Platform**: Windows 11 개발기(pwsh 7); 경로 처리는 `Join-Path`/.NET만 써서 Linux/macOS pwsh에서도 동작(파일명은 소문자 고정)

**Project Type**: 개발 도구 CLI 스크립트(단일 파일)

**Performance Goals**: feature 100개 기준 5초 이내(SC-005; 개발기에서 `Stopwatch`로 측정, pwsh 기동 포함)

**Constraints**: 출력 UTF-8(BOM 없음)·LF(`.gitattributes`); 오류 시 README 미변경; cwd 무관(`$PSScriptRoot` 기반 기본 Root, `GetFullPath`로 정규화); 변경 없으면 파일 미기록(멱등); 쓰기는 임시 파일 + 교체(원자적); 모든 I/O·디코딩 예외는 `error: <사유>` 한 줄 + 종료 코드 1(스택 출력 금지); 입력은 엄격한 UTF-8 디코딩(잘못된 바이트 → 오류)

**Scale/Scope**: feature 수십 개; 스크립트 ≤ ~150줄, 테스트 ≤ ~300줄(목표치, 구속 아님)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 판정 | 근거 |
|---|---|---|
| I. Spec-First | PASS | `specs/002-smoke/spec.md`(Draft, 내장 체크리스트 16/16, 리뷰어 체크리스트 `requirements-quality.md` 28항목) 선행. 코드는 spec의 FR-001~015를 그대로 구현 |
| II. Test-First (NON-NEGOTIABLE) | PASS | T001이 단언 1개로 RED에서 시작(T002가 GREEN), 스토리마다 테스트 task가 구현 task보다 앞(T003→T004·T005, T007→T008, T010→T011) + 스토리별 tester E2E task(T006·T009·T012) |
| III. Tenant Boundary | PASS | Key Entities: 인덱스 항목·인덱스 문서 모두 저장소 전역 메타데이터, 테넌트·격리 키 없음(제품 데이터 아님)과 소유 구분(표 = 스크립트, 머리말·후행 = 사람)을 명시 |
| IV. Observability-Ready | PASS | 아래 "Observability & Rollback": stdout 요약·stderr `warning:`/`error:`·종료 코드, 건강 지표 2개(run-all `scripts`, `specs-index-fresh`), 실패 모드, 롤백 = `git checkout -- specs/README.md`(파생물, 재생성 가능) |
| V. Simplicity | PASS | 단일 스크립트, 의존성 0, 새 프레임워크 없음(Pester·PSScriptAnalyzer·Markdig 모두 설치가 필요한 외부 모듈이라 미채택, research R1·R5). 유일한 추가 표면은 `-Root` 매개변수(테스트 격리용, research R6) — 위반 아님 |
| VI. Learning-in-Public | PASS | `/finish`가 `content/study/002-smoke.mdx` 초안 생성(finish-gate가 존재 검사) |

**Post-design re-check (Phase 1 이후)**: 설계 산출물(research R1–R8, data-model, contracts/cli.md)이 새 의존성·추상화를 도입하지 않음 → 전 항목 PASS 유지. 2026-08-27 approval review 반영(원자적 쓰기, I/O 예외 처리, 표 중복 오류, `specs-index-fresh` 검사) 후에도 의존성 0·단일 파일 유지 → PASS. Complexity Tracking 해당 없음.

## Project Structure

### Documentation (this feature)

```text
specs/002-smoke/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── cli.md           # Phase 1 output — 명령 계약(매개변수·메시지·종료 코드·표 스키마)
├── checklists/
│   ├── requirements.md          # /speckit-specify 품질 체크리스트(16/16)
│   └── requirements-quality.md  # /speckit-checklist 요구사항 품질 체크리스트(28항목, 리뷰어 소유)
├── reviews/
│   └── 2026-08-27-approval.md   # /approval-review 산출(경계 5)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
scripts/
└── update-specs-index.ps1            # 신규: 인덱스 재생성 스크립트 (-Root 매개변수)

tests/
├── run-all.ps1                       # 수정: 검사 항목 'scripts'(테스트 실행)·'specs-index-fresh'(실물 인덱스 최신) 추가
└── scripts/
    ├── update-specs-index.tests.ps1  # 신규: 자체 하네스(임시 픽스처), 종료 코드 0/1
    └── fixtures/                     # tester E2E 임시 픽스처 위치(실행 후 삭제, 커밋되지 않음)

specs/README.md                       # 재생성 결과 + 머리말 문구 1회 갱신("스크립트 전까지 수동" 제거)
AGENTS.md, docs/kr/AGENTS_kr.md       # 명령 표의 "(added by feature 002-smoke)" 주석 제거(문구만)
```

**Structure Decision**: 단일 스크립트 + 단일 테스트 파일. 저장소 관례(`tests/hooks/` 하네스, `tests/run-all.ps1`)를 따르고 AGENTS.md 테스트 경로 규칙(`tests/` 하위)을 지킨다. `src/`·모듈 구조는 불필요(헌법 V).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

해당 없음 — 위반 0.

## Implementation Approach

research.md의 결정(R1–R8)과 2026-08-27 approval review 반영 사항을 실행 단위로 옮긴 것이다. 세부 코드는 tasks.md와 구현 단계에서.

1. **수집** (R1, R8): `<Root>/specs` 바로 아래 디렉터리 중 `^[0-9]{3,}-[A-Za-z0-9][A-Za-z0-9-]*$` 매칭만 대상(ASCII 숫자; 정션·심볼릭 링크는 `-Attributes !ReparsePoint`로 제외). `spec.md` 없으면 stderr 경고 후 건너뜀. 각 spec.md를 엄격한 UTF-8(`UTF8Encoding($false, $true)`)로 읽어 BOM 제거·LF 정규화 후 줄 배열에서 첫 `^#\s+(.+)$`, 첫 `^\*\*Status\*\*:\s*(.+?)\s*$`, 첫 `^\*\*Priority\*\*:\s*(.+?)\s*$`를 찾는다. `plan.md`(파일) 존재 여부를 기록한다.
2. **검증** (R3): H1 또는 Status가 없는 파일은 오류 목록에 추가. 순회가 끝난 뒤 오류가 1건 이상이면 모두 stderr에 출력하고 `exit 1` — README를 읽거나 쓰기 전에 끝낸다.
3. **변환** (R7, FR-002/004/005/013): 제목에서 `^Feature Specification:\s*` 제거·Trim; Status는 첫 괄호 그룹만 `\(([^,)]*),[^)]*\)` → `($1)`; Priority 없으면 `—`; 링크 `[spec](<dir>/spec.md)` (+ ` · [plan](<dir>/plan.md)`); 모든 셀은 `\` → `\\` 먼저, 그다음 `|` → `\|`.
4. **정렬·조립** (R8, FR-006): 번호 문자열을 (길이, ordinal) 순으로, 동률은 디렉터리명 ordinal — 정수 캐스트 없음(자릿수 무제한). 헤더 `| # | Feature | Status | 우선순위 | 링크 |`, 구분 `|---|---|---|---|---|`, 행들.
5. **README 병합** (R2, FR-007/011): 기존 파일 원문을 읽고(비교용으로 보관) BOM 제거·LF 정규화한 텍스트에서 `^\| # \|` 줄을 센다 — 0개: `content.TrimEnd() + "\n\n" + table + "\n"`; 1개: 그 줄부터 연속된 `|` 시작 줄 블록을 표로 보고 `preamble + table + trailer`; 2개 이상: `error: specs/README.md: multiple index tables`, `exit 1`. 파일 없음 → 기본 머리말(`# Feature 인덱스` + 한 문단) + 표.
6. **쓰기** (R4, FR-008/012): 조립 결과를 디스크 원문과 비교해 같으면 쓰지 않고 `(unchanged)` 표시(CRLF/BOM이던 README는 첫 실행에서 한 번 LF·BOM 없음으로 재기록); 다르면 같은 디렉터리의 임시 파일에 `WriteAllText(..., UTF8Encoding($false))` 후 `File.Move(tmp, target, overwrite)`로 교체. 본문 전체는 `try/catch`로 감싸 모든 예외를 `error: <사유>` 한 줄 + `exit 1`로 보고. stdout `specs/README.md: N features indexed[ (unchanged)]`, `exit 0`.
7. **테스트** (R5, R6): T001은 단언 1개(`specs/` 부재 → exit 1)로 RED에서 시작. 픽스처 생성 함수(임시 디렉터리에 `specs/` + README + feature 디렉터리들; 바이트 값 지원) → 각 시나리오가 `-Root`로 실행하고 파일 내용·stdout/stderr·종료 코드·LastWriteTime을 단언. 시나리오: US1-1(2행·열·링크·헤더 1개), US1-2(머리말·후행 보존), US1-3(멱등), US1-4(픽스처에 스크립트 복사 후 `$env:TEMP`에서 기본 Root 검증, `$env:TEMP/specs` 미생성), 입력 불변·실저장소 README 불변, US2-1/2/3(+ 첫 괄호 그룹만·쉼표 뒤 공백 없음), US3-1~5, Edge(접두 없는 H1, 빈 줄 헤더, `\`·`|` 이스케이프, README 없음/표 없음/표 중복, BOM/CRLF 입력(spec·README), 중복 Status/Priority 줄, 잘못된 UTF-8, 읽기 전용 README, feature 0개, 번호 중복 ordinal), SC-005(feature 100개 < 5초).
8. **통합**: `tests/run-all.ps1`에 검사 `scripts`(테스트 실행, `$LASTEXITCODE -eq 0`)와 `specs-index-fresh`(스크립트 실행 결과가 `(unchanged)` — 낡은 인덱스를 잡는 지표; 낡았으면 파일을 갱신하는 부작용을 주석에 명시) 추가; 실제 저장소에서 스크립트 1회 실행해 `specs/README.md` 재생성(001 우선순위 `🔴` → `—`는 spec Assumptions대로 의도된 변화, 표 1개 확인) + 머리말 문구 갱신; AGENTS.md 주석 제거(+ kr 미러).

## Observability & Rollback

- **관측**: 실행마다 stdout 한 줄 요약(`N features indexed`, 변경 없음 표시), stderr에 `warning:`/`error:` 접두 메시지(spec 상대 경로 포함, 스택 없음), 종료 코드 0/1. 상관 id는 불필요(단일 프로세스, 단일 출력 파일; 호출 맥락 = run-all 검사명 또는 lifecycle 단계). 건강 지표 = `tests/run-all.ps1`의 `scripts`(테스트 통과)·`specs-index-fresh`(실물 인덱스가 헤더와 일치)·검사 8(모든 feature 등재) 통과.
- **실패 모드**: 헤더 결손·읽을 수 없는 입력(권한·잘못된 UTF-8)·쓸 수 없는 README(권한·잠금)·표 중복·`specs/` 부재 → `error:` 한 줄 + exit 1, README 미변경. 쓰기는 임시 파일 + 교체라 중단 시 잘린 파일이 남지 않는다. 동시 실행은 지원하지 않는다(단일 개발자 로컬 도구). 타임아웃·재시도 해당 없음(네트워크·외부 프로세스 없음).
- **수용한 리스크**: spec 헤더의 마크다운/HTML(링크·이미지)은 이스케이프하지 않고 README에 그대로 전파된다 — 작성자는 신뢰된 커미터이고 spec.md 자체도 렌더링되므로 잔여 위험 낮음. `specs/README.md`가 심볼릭 링크인 경우는 지원하지 않는다(Windows git 기본 설정에서 파일로 체크아웃됨).
- **런북**: 별도 `docs/runbooks/` 문서는 불필요(단일 명령). 복구 절차 2가지("run-all `scripts`/`specs-index-fresh` FAIL → 스크립트 실행 후 `specs/README.md` 커밋", "`error: <dir>/spec.md: …` → 지목된 spec 헤더 수정 후 재실행")는 스크립트 헤더 주석과 AGENTS.md Commands 행에 둔다.
- **롤백**: `specs/README.md`는 파생물이다. 잘못된 결과는 `git checkout -- specs/README.md`로 되돌리고, 스크립트 자체는 `scripts/update-specs-index.ps1` 삭제 + run-all 검사 항목 제거(커밋 revert)로 제거한다. 데이터 이전 없음.

## Phase 0 / Phase 1 Outputs

- Phase 0: [research.md](research.md) — R1 파싱, R2 표 교체, R3 오류 정책, R4 쓰기, R5 테스트, R6 `-Root`, R7 정규화, R8 정렬. `NEEDS CLARIFICATION` 0.
- Phase 1: [data-model.md](data-model.md)(FeatureEntry, IndexDocument, 진단 출력), [contracts/cli.md](contracts/cli.md)(명령 계약), [quickstart.md](quickstart.md)(검증 절차 7단계).
- 다음: `/speckit-checklist requirements` → `/speckit-tasks`(override 템플릿: 스토리별 테스트 task 필수 + E2E task) → `/approval-review`.
