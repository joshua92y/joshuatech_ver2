# Feature Specification: specs 인덱스 재생성 스크립트 (smoke)

**Feature Branch**: `002-smoke`

**Created**: 2026-08-27

**Status**: Draft

**Input**: User description: "specs/README.md의 feature 인덱스 표를 각 specs/NNN-slug/spec.md 헤더(H1 제목, **Status** 줄)에서 재생성하는 PowerShell 스크립트 scripts/update-specs-index.ps1를 추가한다. 표 열은 번호·Feature·Status·우선순위(spec.md에 **Priority** 줄이 없으면 '—')·링크(spec, plan이 있으면 plan). Status 셀은 `**Status**:` 줄의 값에서 괄호 안 첫 쉼표 이후의 주석을 제거해 `Approved (2026-08-26)` 형태로 정규화한다(예: `Approved (2026-08-26, 외부 리뷰 반영판)` → `Approved (2026-08-26)`). 기존 표의 머리말 문단은 유지한다. short name: smoke"

> 이 feature는 SP-0의 스모크 테스트다(001 spec SC-003): 실제 산출물은 작지만 specify → plan → checklist → tasks → 승인 → 구현 → converge → E2E → finish → 머지의 전체 사이클을 처음으로 실주행한다.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - 인덱스 한 번에 재생성 (Priority: P1)

저장소 운영자는 feature의 `spec.md` 헤더를 바꾼 뒤(예: Status가 Approved로 바뀜) 명령 하나로 `specs/README.md`의 feature 인덱스 표를 다시 만든다. 표 위의 머리말 문단은 손대지 않는다. 표를 손으로 고치다가 헤더와 어긋나는 일이 사라진다.

**Why this priority**: 이 feature의 존재 이유다. 인덱스는 `specs/` 규칙("헤더를 바꾸고 재생성한다, 표만 고치지 않는다")의 유일한 실행 수단이며, 이후 모든 feature의 finish·archive 단계가 이 명령에 의존한다.

**Independent Test**: feature 디렉터리 2개(001, 002)가 있는 현재 저장소에서 명령을 실행하고, 표의 행 수·각 셀·머리말이 `spec.md` 헤더와 기존 머리말에 일치하는지 확인한다. 이 스토리만으로도 실사용 가치가 있다.

**Acceptance Scenarios**:

1. **Given** `specs/` 아래에 `spec.md`를 가진 feature 디렉터리 `001-claude-setup`, `002-smoke`가 있고 `001`에만 `plan.md`가 있음, **When** 재생성 명령을 실행, **Then** 표에는 정확히 두 행이 번호 오름차순으로 있고, 각 행은 `# | Feature | Status | 우선순위 | 링크` 열(헤더 표기 `#` = 번호)을 가지며, Feature 셀은 해당 `spec.md`의 H1에서 `Feature Specification:` 접두를 뺀 제목, 링크 셀은 `[spec](NNN-slug/spec.md)`에 `plan.md`가 있는 feature만 ` · [plan](NNN-slug/plan.md)`이 덧붙는다.
2. **Given** `specs/README.md`에 표 앞 머리말 문단(제목·설명)이 있음, **When** 명령을 실행, **Then** 표 앞의 내용과 표 뒤의 내용은 문자 단위로 그대로이고 표만 교체된다.
3. **Given** 표가 이미 최신 상태, **When** 명령을 한 번 더 실행, **Then** 파일 내용이 바뀌지 않는다(멱등).
4. **Given** 어느 작업 디렉터리에서든, **When** 명령을 실행, **Then** 항상 저장소의 `specs/`와 `specs/README.md`를 대상으로 동작한다.

---

### User Story 2 - Status 값 정규화 (Priority: P2)

`spec.md`의 `**Status**` 줄에는 검토 이력 같은 주석이 괄호 안에 덧붙을 수 있다(`Approved (2026-08-26, 외부 리뷰 반영판)`). 인덱스에서는 상태와 날짜만 보이면 되므로 첫 쉼표 이후의 주석을 떼어 `Approved (2026-08-26)` 형태로 통일한다.

**Why this priority**: 인덱스 표의 가독성과 일관성. 정규화가 없으면 표가 주석으로 길어지고 상태 비교(Draft/Approved/Done)가 어려워진다. US1 없이는 의미가 없으므로 P2.

**Independent Test**: 주석 있는 값, 날짜만 있는 값, 괄호 없는 값을 각각 가진 `spec.md`로 표를 만들어 셀 값을 비교한다.

**Acceptance Scenarios**:

1. **Given** `**Status**: Approved (2026-08-26, 외부 리뷰 반영판)`, **When** 재생성, **Then** Status 셀은 `Approved (2026-08-26)`.
2. **Given** `**Status**: Done (2026-08-27)`, **When** 재생성, **Then** 셀은 `Done (2026-08-27)` 그대로.
3. **Given** `**Status**: Draft`(괄호 없음), **When** 재생성, **Then** 셀은 `Draft` 그대로.

---

### User Story 3 - 결측값과 예외 상황 처리 (Priority: P3)

헤더에 우선순위가 없거나 `plan.md`가 아직 없는 feature, `specs/` 안의 feature가 아닌 항목, 헤더가 깨진 `spec.md`가 있어도 명령은 예측 가능하게 동작한다: 있는 것은 표시하고, 없는 것은 `—`로 표시하며, 헤더가 깨진 경우에는 인덱스를 건드리지 않고 실패를 알린다.

**Why this priority**: 현재 저장소에도 우선순위 줄이 없는 spec과 `plan.md`가 없는 feature가 있으므로 결측 처리는 첫 실행부터 필요하지만, 예외 케이스는 드물다.

**Independent Test**: 우선순위 줄이 없는 spec, `plan.md`가 없는 feature, `spec.md`가 없는 디렉터리, Status 줄이 없는 spec을 각각 준비해 결과(셀 값, 경고/오류, 종료 상태, 인덱스 파일 변경 여부)를 확인한다.

**Acceptance Scenarios**:

1. **Given** `spec.md`에 `**Priority**` 줄이 없음, **When** 재생성, **Then** 우선순위 셀은 `—`.
2. **Given** `spec.md`에 `**Priority**: 🔴` 줄이 있음, **When** 재생성, **Then** 우선순위 셀은 `🔴`.
3. **Given** feature 디렉터리에 `plan.md`가 없음, **When** 재생성, **Then** 링크 셀은 `[spec](…)`만.
4. **Given** `specs/` 아래에 `README.md`처럼 `NNN-slug` 형식이 아닌 항목이나 `spec.md`가 없는 디렉터리가 있음, **When** 재생성, **Then** 그 항목은 표에 나타나지 않고(`NNN-slug` 디렉터리에 `spec.md`가 없는 경우에만 경고 메시지 출력, 형식이 아닌 항목은 조용히 무시), 나머지 feature는 정상 처리되며 명령은 성공으로 끝난다.
5. **Given** 어떤 `spec.md`에 H1 제목 또는 `**Status**` 줄이 없음, **When** 재생성, **Then** 문제 파일을 지목하는 오류 메시지가 출력되고 명령은 실패로 끝나며 `specs/README.md`는 변경되지 않는다.

---

### Edge Cases

- H1이 `Feature Specification:` 접두 없이 시작하면 H1 전체를 제목으로 쓴다.
- 헤더 줄 사이에 빈 줄이 있는 형식(Spec Kit 템플릿)과 없는 형식(001 spec) 모두 같은 결과를 낸다.
- Status 값의 괄호 안에 쉼표가 없으면 그대로 두고, 첫 여는 괄호 이전의 상태 단어는 그대로 유지한다.
- `specs/README.md`가 없으면 기본 제목·머리말과 표로 새로 만든다; 파일은 있으나 표가 없으면 기존 내용 뒤에 표를 덧붙인다.
- 표 뒤에 후행 텍스트가 있으면 그대로 보존한다.
- 셀 값에 `|`가 포함되면 표가 깨지지 않도록 이스케이프한다.
- 번호는 디렉터리 접두 그대로(`001`)이며 정렬은 숫자 기준이다. 같은 번호 접두를 가진 디렉터리가 둘 이상이면 모두 표시하고 이름의 문자 코드 순(ordinal)으로 정렬한다(오류 아님).
- `**Status**`·`**Priority**` 줄이 여러 번 나타나면 첫 번째 줄만 쓴다.
- 입력 `spec.md`나 `README.md`가 BOM 또는 CRLF를 가져도 같은 결과를 낸다(BOM 제거, 줄바꿈은 LF로 정규화). "문자 단위 동일"(SC-004)은 줄바꿈 정규화 후의 문자 기준이다.
- feature가 0개면 헤더 행과 구분 행만 있는 빈 표를 쓰고 성공 종료한다.
- 표가 없는 `README.md`에 덧붙일 때는 기존 내용의 끝 공백·개행을 제거한 뒤 빈 줄 하나를 두고 표를 붙이며, 파일은 개행 하나로 끝난다(반복 실행 시 동일).
- `specs/` 디렉터리 자체가 없으면 오류를 출력하고 실패 종료하며 아무것도 쓰지 않는다.
- `README.md`에 인덱스 표의 헤더 행이 둘 이상 있으면 어느 것을 교체할지 정할 수 없으므로 오류로 실패 종료하고 아무것도 쓰지 않는다.
- 입력 파일을 읽을 수 없거나 올바른 UTF-8이 아니거나, `README.md`를 쓸 수 없으면(권한·잠금) 문제를 지목하는 오류 한 줄을 출력하고 실패 종료하며 `README.md`는 변경되지 않는다.
- 결과 파일은 UTF-8(BOM 없음)·LF로 저장한다(저장소 파일 규칙).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: 명령은 `specs/` 바로 아래에서 `NNN-slug` 형식(3자리 이상 숫자, 하이픈, 슬러그)의 디렉터리 중 `spec.md`를 가진 것만 feature로 인식해야 한다.
- **FR-002**: 각 feature의 번호는 디렉터리 접두에서, Feature 제목은 `spec.md`의 첫 H1에서 `Feature Specification:` 접두와 양끝 공백을 제거한 값으로 얻어야 한다.
- **FR-003**: Status는 `spec.md`의 `**Status**:` 줄 값에서 얻고, 첫 괄호 안에 쉼표가 있으면 첫 쉼표 이후를 제거하고 괄호를 닫아 `상태 (날짜)` 형태로 정규화해야 한다(예: `Approved (2026-08-26, 외부 리뷰 반영판)` → `Approved (2026-08-26)`).
- **FR-004**: 우선순위는 `**Priority**:` 줄 값이며, 줄이 없으면 `—`를 써야 한다.
- **FR-005**: 링크 셀은 `[spec](NNN-slug/spec.md)`이고, 같은 디렉터리에 `plan.md`가 있으면 ` · [plan](NNN-slug/plan.md)`을 덧붙여야 한다.
- **FR-006**: 표는 `| # | Feature | Status | 우선순위 | 링크 |` 헤더를 가지며 feature당 한 행, 번호 오름차순이어야 한다.
- **FR-007**: 명령은 `specs/README.md`에서 표(헤더 행·구분 행·데이터 행의 연속 블록)만 교체하고, 표 앞의 머리말과 표 뒤의 내용은 그대로 보존해야 한다.
- **FR-008**: 같은 입력으로 반복 실행해도 결과 파일이 동일해야 한다(멱등).
- **FR-009**: 어떤 `spec.md`에 H1 또는 `**Status**` 줄이 없으면 그 파일을 지목하는 오류를 출력하고 실패 종료해야 하며, 이때 `specs/README.md`를 변경해서는 안 된다.
- **FR-010**: `spec.md`가 없는 `NNN-slug` 디렉터리는 경고를 출력하고 건너뛰되 명령은 성공 종료해야 한다; `NNN-slug` 형식이 아닌 항목은 조용히 무시해야 한다.
- **FR-011**: `specs/README.md`가 없으면 기본 제목·머리말과 표로 새로 만들고, 표가 없는 파일이면 기존 내용 뒤에 표를 덧붙여야 한다.
- **FR-012**: 결과 파일은 UTF-8(BOM 없음)·LF 줄바꿈으로 저장해야 한다.
- **FR-013**: 셀 값의 `|` 문자는 표를 깨뜨리지 않도록 이스케이프해야 한다.
- **FR-014**: 명령은 현재 작업 디렉터리와 무관하게 자신이 속한 저장소의 `specs/`를 대상으로 동작해야 한다.
- **FR-015**: 명령은 성공 시 종료 코드 0, 실패 시 0이 아닌 종료 코드로 결과를 알려야 한다.

### Key Entities

- **Feature 인덱스 항목**: 하나의 feature 디렉터리를 대표하는 행. 속성: 번호, 제목, 정규화된 Status, 우선순위(없으면 `—`), 링크(spec, 선택적으로 plan). 소유자: 저장소 자체(전역 메타데이터 — 제품·테넌트 데이터가 아닌 개발 도구 산출물이므로 격리 키 없음). 원천은 각 `spec.md` 헤더이며 인덱스는 파생물이다.
- **인덱스 문서**: `specs/README.md`. 구조: 머리말(보존) + 표(재생성) + 후행 텍스트(보존). 소유자: 저장소(전역, 위 항목과 같은 이유). 표 블록은 명령이 소유하며(`spec.md` 헤더의 파생물 — 표를 손으로 고친 내용은 다음 재생성에서 폐기된다), 머리말·후행 텍스트는 사람이 소유한다(명령은 읽어서 그대로 보존만 한다). 명령은 입력 `spec.md`·`plan.md`를 쓰거나 지우지 않으며, 이력·백업·롤백은 git이 담당한다.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 명령 1회 실행으로 현재 저장소의 모든 feature(2개)가 표에 나타나고, 모든 셀 값이 해당 `spec.md` 헤더에서 규칙대로 도출한 기대값과 100% 일치한다.
- **SC-002**: 같은 상태에서 2회 연속 실행하면 두 번째 실행 후 파일 변경이 0바이트다.
- **SC-003**: Status 정규화 검증 세트(주석 있음 / 날짜만 / 괄호 없음)의 결과가 기대값과 100% 일치한다.
- **SC-004**: 머리말과 후행 텍스트는 실행 전후 문자 단위로 100% 동일하다.
- **SC-005**: feature 100개까지 5초 이내에 완료된다.
- **SC-006**: 헤더가 깨진 `spec.md`가 하나라도 있으면 100% 실패로 보고되고 인덱스 파일은 변경되지 않는다.
- **SC-007**: 자동 테스트가 단독으로 실행되어 통과/실패를 종료 코드로 알리며, 재생성 후 저장소 전체 검사(`tests/run-all.ps1`)가 계속 모두 통과한다.

## Assumptions

- 산출물의 경로와 이름은 사용자가 지정했다: `scripts/update-specs-index.ps1`. 저장소의 도구 언어 관례(PowerShell 7, 훅·검사 스크립트와 동일)와 일치하며, 자동 테스트는 `tests/scripts/` 아래에 둔다(AGENTS.md 테스트 경로 규칙).
- 001 spec에는 `**Priority**` 줄이 없으므로 첫 재생성 후 001 행의 우선순위는 현재 수동 표기 `🔴` 대신 `—`가 된다. 의도된 결과다. 우선순위를 표시하려면 헤더에 `**Priority**` 줄을 추가해야 하는데, 001은 Approved 상태라 이번 feature에서는 손대지 않는다.
- 우선순위 값은 헤더의 문자열(예: `🔴`, `P1`)을 검증 없이 그대로 표시한다.
- `specs/README.md` 머리말의 "(002-smoke가 … 추가할 때까지는 수동)" 문구는 이 feature가 완료되면 한 번 수동으로 갱신한다. 머리말은 명령이 보존하므로 이후 재생성에 영향이 없다.
- 이 feature가 완료되기 전까지 002 행은 머리말 규칙대로 수동으로 유지한다(저장소 검사 8이 모든 feature의 인덱스 등재를 요구함).
- 범위 밖: 변경 여부만 검사하는 검증 전용 모드, 여러 `specs/` 루트, 정렬·열 구성 옵션, 표 이외의 README 내용 생성.
- 실행 환경: PowerShell 7이 PATH에 있다(훅과 동일한 전제).
