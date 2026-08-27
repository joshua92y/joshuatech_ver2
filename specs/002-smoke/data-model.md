# Data Model: specs 인덱스 재생성 스크립트 (002-smoke)

**Spec**: [spec.md](spec.md) · **Plan**: [plan.md](plan.md) · **Contract**: [contracts/cli.md](contracts/cli.md)

## FeatureEntry — `spec.md` 헤더에서 파생되는 행

| 필드 | 타입 | 출처 | 규칙 |
|---|---|---|---|
| `dirName` | string | `specs/` 바로 아래 디렉터리 이름 | `^\d{3,}-[A-Za-z0-9][A-Za-z0-9-]*$`에 맞고 `spec.md`가 있을 때만 인식 (FR-001, FR-010) |
| `number` | string | `dirName`의 숫자 접두 | 셀에는 문자열 그대로(`001`); 정렬 키는 정수 (FR-006) |
| `title` | string | 첫 `# ` 줄 | `Feature Specification:` 접두와 양끝 공백 제거 (FR-002); 없으면 오류 (FR-009) |
| `statusRaw` | string | 첫 `**Status**:` 줄의 값 | 없으면 오류 (FR-009) |
| `status` | string | `statusRaw` | 첫 괄호 그룹에서 첫 쉼표 이후 제거 → `상태 (날짜)` (FR-003) |
| `priority` | string | 첫 `**Priority**:` 줄의 값 | 없으면 `—` (FR-004) |
| `hasPlan` | bool | `<dir>/plan.md` 존재 여부 | 링크 셀에 ` · [plan](…)` 추가 (FR-005) |
| `specLink` / `planLink` | string | `NNN-slug/spec.md`, `NNN-slug/plan.md` | README 기준 상대 경로 |

- 셀 렌더링: 값 안의 `|`는 `\|`로 이스케이프 (FR-013).
- 소유·격리(헌법 III): 저장소 전역 메타데이터. 테넌트 없음 — 제품 데이터가 아닌 개발 도구 산출물이므로 격리 키를 두지 않는다. 원천은 각 `spec.md` 헤더이고 이 행은 파생물이다.

## IndexDocument — `specs/README.md`

| 부분 | 규칙 |
|---|---|
| `preamble` | 표 헤더 행(`| # |`로 시작) 이전의 텍스트 전부, 문자 단위 보존 (FR-007) |
| `table` | 헤더 `| # | Feature | Status | 우선순위 | 링크 |` + 구분 `|---|---|---|---|---|` + 행들(번호 오름차순, feature당 1행) (FR-006) |
| `trailer` | 표 블록(헤더 행부터 연속된 `|` 시작 행) 이후의 텍스트 전부, 보존 (FR-007) |
| 파일 없음 | 기본 제목·머리말 + 표로 생성 (FR-011) |
| 표 없음 | 기존 내용 + 빈 줄 + 표 (FR-011) |
| 인코딩·줄바꿈 | UTF-8(BOM 없음), LF (FR-012) |
| 쓰기 조건 | 조립한 내용이 기존과 같으면 쓰지 않음 (FR-008) |

## Status 값(참고)

`Draft` → `Approved (YYYY-MM-DD)` → `Done (YYYY-MM-DD)` (specs 규칙). 이 feature는 값을 검증하지 않고 정규화만 한다(허용값 검증은 spec Assumptions에서 범위 밖).

## 진단 출력과 종료 코드

| 상황 | 채널·메시지 | 종료 코드 | README |
|---|---|---|---|
| 정상 | stdout `specs/README.md: N features indexed` (변경 없으면 뒤에 ` (unchanged)`) | 0 | 갱신 또는 유지 |
| `spec.md` 없는 `NNN-slug` 디렉터리 | stderr `warning: skip <dir>: spec.md missing` | 0 | 갱신 |
| H1 또는 `**Status**` 누락 | stderr `error: <specs 기준 상대 경로>: missing H1 title` / `missing **Status** line` (파일마다 1줄) | 1 | 미변경 |
| `specs/` 없음 | stderr `error: specs directory not found: <path>` | 1 | 미변경 |
| 저장소 루트 해석 불가(`$PSScriptRoot` 비어 있음) | stderr `error: cannot resolve repository root` | 1 | 미변경 |
| README에 표 헤더 행 2개 이상 | stderr `error: specs/README.md: multiple index tables` | 1 | 미변경 |
| 읽기·쓰기·디코딩 실패(권한, 잠금, 잘못된 UTF-8) | stderr `error: <.NET 예외 메시지>` 한 줄(스택 없음) | 1 | 미변경(쓰기는 임시 파일 + 교체) |
