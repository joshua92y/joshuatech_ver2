# CLI Contract: `scripts/update-specs-index.ps1`

테스트(`tests/scripts/update-specs-index.tests.ps1`)와 tester E2E가 고정하는 계약이다. 매개변수·메시지·표 형식을 바꾸려면 새 feature에서 한다.

## 호출

```
pwsh -NoProfile -File scripts/update-specs-index.ps1 [-Root <path>]
```

| 매개변수 | 기본값 | 의미 |
|---|---|---|
| `-Root <path>` | 스크립트 파일의 상위 디렉터리(= 저장소 루트) | `<Root>/specs`를 읽고 `<Root>/specs/README.md`를 쓴다 |

- 현재 작업 디렉터리에 의존하지 않는다(FR-014).
- 외부 모듈·네트워크·git 명령을 사용하지 않는다.

## 입력

- `<Root>/specs/<NNN-slug>/spec.md`: 첫 `# ` 줄(제목), 첫 `**Status**:` 줄(필수), 첫 `**Priority**:` 줄(선택).
- `<Root>/specs/<NNN-slug>/plan.md`: 존재 여부만 본다.
- `<Root>/specs/README.md`: 선택. 있으면 표 블록만 교체한다.

## 출력

- 파일: `<Root>/specs/README.md` (규칙은 [data-model.md](../data-model.md) IndexDocument).
- stdout(성공): `specs/README.md: <N> features indexed` 또는 `specs/README.md: <N> features indexed (unchanged)`.
- stderr(경고): `warning: skip <dir>: spec.md missing`.
- stderr(오류): `error: <NNN-slug>/spec.md: missing H1 title`, `error: <NNN-slug>/spec.md: missing **Status** line`, `error: specs directory not found: <path>`, `error: specs/README.md: multiple index tables`, `error: cannot resolve repository root`, 그리고 I/O·디코딩 실패는 `error: <.NET 예외 메시지>` 한 줄(스택 없음).
- 번호 접두는 ASCII 숫자(`[0-9]{3,}`)만 인식하며 자릿수 제한 없이 (길이, 문자 코드) 순으로 정렬한다.

## 종료 코드

| 코드 | 의미 |
|---|---|
| 0 | 성공(경고가 있어도 0) |
| 1 | 오류 1건 이상 — README 미변경 |

## 표 스키마

```
| # | Feature | Status | 우선순위 | 링크 |
|---|---|---|---|---|
| <number> | <title> | <status> | <priority 또는 —> | [spec](<dir>/spec.md) · [plan](<dir>/plan.md) |
```

- `· [plan](…)`은 `plan.md`가 있을 때만.
- 셀 값의 `|`는 `\|`.
- 행 순서: `<number>` 정수 오름차순.

## 안정성 약속

- 같은 입력 → 같은 바이트(멱등), 변경 없으면 파일을 쓰지 않는다. 쓰기는 임시 파일 + 교체(원자적)이며, 오류 시 `README.md`는 변경되지 않는다.
- 입력 `spec.md`·`plan.md`는 읽기 전용이다.
- 표 앞·뒤 텍스트는 문자 단위로 불변.
- 출력 파일은 UTF-8(BOM 없음)·LF.
