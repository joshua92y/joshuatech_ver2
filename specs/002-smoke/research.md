# Research: specs 인덱스 재생성 스크립트 (002-smoke)

**Date**: 2026-08-27 | **Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

Technical Context에 `NEEDS CLARIFICATION`은 없다. 아래는 구현 방식 결정과 근거, 기각한 대안이다.

## R1. 헤더 파싱 방식

- **Decision**: 줄 단위 정규식 — 첫 `# ` 줄(제목), 첫 `**Status**:` 줄, 첫 `**Priority**:` 줄만 읽는다.
- **Rationale**: 헤더는 Spec Kit 템플릿이 고정한 형식이고 줄 사이 빈 줄 유무만 다르다(템플릿 vs 001 spec). 외부 마크다운 파서가 필요 없다(헌법 V).
- **Alternatives considered**: Markdig 등 파서 — 의존성 설치가 필요하고 이득이 없음. YAML frontmatter — 템플릿과 001 spec이 사용하지 않음.

## R2. 표 교체 전략

- **Decision**: `| # |`로 시작하는 헤더 행부터 연속된 `|` 시작 행 블록을 표로 인식해 그 블록만 교체한다. 앞(머리말)·뒤(후행) 텍스트는 그대로. 표가 없으면 파일 끝에 빈 줄 + 표를 덧붙이고, 파일이 없으면 기본 머리말과 함께 생성한다.
- **Rationale**: spec FR-007 "표만 교체". 기존 `specs/README.md` 형식을 바꾸지 않고 바로 동작한다.
- **Alternatives considered**: `<!-- INDEX START/END -->` 마커 — 더 견고하지만 README 형식 변경이 필요하고 현재 파일에 없음(필요해지면 후속 feature). 파일 전체 재생성 — 머리말 보존 요구(FR-007) 위반.

## R3. 오류 정책

- **Decision**: fail-closed. 어느 `spec.md`라도 H1 또는 `**Status**`가 없으면 발견한 오류를 모두 stderr로 보고하고 종료 코드 1, README는 건드리지 않는다. `spec.md`가 없는 `NNN-slug` 디렉터리는 경고 후 건너뛴다(종료 코드 0).
- **Rationale**: 부분 갱신된 표가 커밋되면 헤더와 어긋난 인덱스가 남는다(specs 규칙 위반). finish-gate 훅의 fail-closed 철학과 같다(FR-009, FR-010).
- **Alternatives considered**: best-effort(결측을 `—`로 채우고 계속) — 잘못된 spec을 숨긴다.

## R4. 파일 쓰기(인코딩·줄바꿈)

- **Decision**: 본문을 LF로 조립하고 `[System.IO.File]::WriteAllText(path, text, [System.Text.UTF8Encoding]::new($false))`로 쓴다. 기존 내용과 같으면 쓰지 않는다.
- **Rationale**: pwsh 7의 `Set-Content`/`Out-File`은 BOM 없는 UTF-8이지만 줄바꿈이 OS 기본(Windows=CRLF)이라 `.gitattributes`(LF)와 충돌한다. 동일 내용 미기록은 멱등성(SC-002)과 mtime 불변을 함께 보장한다(FR-008, FR-012).
- **Alternatives considered**: `Set-Content -NoNewline`에 수동 join — 가능하나 .NET API가 의도를 명시한다.

## R5. 테스트 방식

- **Decision**: 프레임워크 없는 자체 하네스 — `tests/hooks/run-hook-tests.ps1`와 같은 구조(Assert 함수, PASS/FAIL 카운트, 임시 픽스처 생성·정리, 종료 코드 0/1). `tests/run-all.ps1`에 검사 항목으로 등록한다.
- **Rationale**: 저장소 관례와 일관. Pester는 pwsh 7에 기본 포함되지 않아 설치 단계가 늘어난다(헌법 V).
- **Alternatives considered**: Pester 5 — 표현력은 높지만 의존성 추가.

## R6. 테스트 가능성을 위한 `-Root` 매개변수

- **Decision**: `-Root <dir>`(기본값: 스크립트 파일의 상위 디렉터리 = 저장소 루트). 테스트는 임시 디렉터리를 Root로 넘긴다.
- **Rationale**: 저장소 파일을 건드리지 않고 오류·결측·성능 시나리오를 재현할 수 있다. cwd 무관 동작(FR-014)은 `$PSScriptRoot` 기반 기본값으로 충족된다.
- **Alternatives considered**: 환경 변수 — 암묵적. 저장소 실물로만 테스트 — 오류 케이스 재현 불가.

## R7. Status 정규화 규칙

- **Decision**: 첫 번째 괄호 그룹에 한해 `\(([^,)]*),[^)]*\)` → `($1)`. 괄호 밖 텍스트와 괄호 없는 값은 그대로.
- **Rationale**: spec FR-003 예시와 1:1 대응. 그룹 하나만 치환해 뒤따르는 괄호(드묾)를 건드리지 않는다.
- **Alternatives considered**: 허용값(Draft/Approved/Done) 검증 — spec Assumptions에서 범위 밖으로 둠.

## R8. 정렬·번호

- **Decision**: 디렉터리 이름의 `^\d{3,}` 접두를 정수로 정렬하고 셀에는 접두 문자열을 그대로 쓴다(`001`). 동률은 이름순.
- **Rationale**: run-all 검사 8의 디렉터리 인식 정규식(`^\d{3,}-`)과 일치. timestamp 번호 체계(`YYYYMMDD-HHMMSS-slug`)도 첫 숫자 그룹 기준으로 정렬된다(현재 설정은 sequential).
- **Alternatives considered**: 문자열 정렬 — 자릿수가 달라지면(`1000`) 순서가 깨진다.
