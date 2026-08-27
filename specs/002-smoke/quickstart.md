# Quickstart: specs 인덱스 재생성 스크립트 (002-smoke)

검증 절차만 담는다. 구현 세부는 [plan.md](plan.md)·`tasks.md`, 계약은 [contracts/cli.md](contracts/cli.md).

## 전제

- PowerShell 7(`pwsh`)이 PATH에 있다(훅과 같은 전제). 확인: `pwsh -NoProfile -c '$PSVersionTable.PSVersion'` → `7.x`.
- 아래 명령은 저장소 루트(`d:\code\joshuatech_ver2`) 기준 상대 경로다(스크립트 자체는 cwd 무관).

## 1. 단위·계약 테스트 (구현 전 RED → 구현 후 GREEN)

```
pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1; echo $LASTEXITCODE
```

- 구현 전: 실패 다수, 종료 코드 `1`.
- 구현 후: `N passed, 0 failed`, 종료 코드 `0`.

## 2. 실제 저장소에서 재생성 (US1)

```
pwsh -NoProfile -File scripts/update-specs-index.ps1
```

- stdout: `specs/README.md: 2 features indexed`.
- `specs/README.md` 표: `001` 행 = `Approved (2026-08-26)` · 우선순위 `—`(Priority 줄 없음) · spec+plan 링크; `002` 행 = 헤더의 Status 값 · spec 링크(plan.md가 있으면 plan 링크도).
- 머리말 불변: `git diff specs/README.md`에 표 행 변경만 보인다.

## 3. 멱등성 (US1-3, SC-002)

```
pwsh -NoProfile -File scripts/update-specs-index.ps1; git status --short specs/README.md
```

- 두 번째 실행의 stdout에 `(unchanged)`, 첫 실행 이후 추가 diff 없음.

## 4. cwd 무관 (US1-4, FR-014)

```
pwsh -NoProfile -c 'Set-Location $env:TEMP; & "d:/code/joshuatech_ver2/scripts/update-specs-index.ps1"'
```

- 같은 결과, 대상은 저장소의 `specs/README.md`.

## 5. 정규화·결측·오류 (US2, US3)

테스트 파일이 임시 픽스처(`-Root <임시 디렉터리>`)로 검증한다. 수동 확인: 임시 디렉터리에 `specs/003-x/spec.md`를 Status 줄 없이 만들고 `-Root <임시 디렉터리>`로 실행 → stderr에 `error: 003-x/spec.md: missing **Status** line`, 종료 코드 `1`, README 미변경.

## 6. 저장소 전체 검사

```
pwsh -NoProfile -File tests/run-all.ps1
```

- `PASS scripts` 항목을 포함해 `ALL PASS`.

## 7. E2E (tester 에이전트)

tester에 `spec.md`의 `## User Scenarios & Testing` 절 전문과 1·2·3·4의 명령을 전달한다. 스토리별 PASS/FAIL/SKIP 보고를 받는다.
