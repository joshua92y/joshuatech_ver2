# update-specs-index.ps1 — specs/README.md의 feature 인덱스 표를 specs/<NNN-slug>/spec.md 헤더에서 재생성한다.
#
# 호출: pwsh -NoProfile -File scripts/update-specs-index.ps1 [-Root <path>]
#   -Root <path>  저장소 루트. 기본값은 이 스크립트 파일의 상위 디렉터리(FR-014, cwd 무관).
#                 <Root>/specs를 읽고 <Root>/specs/README.md를 쓴다. 외부 모듈·네트워크·git 미사용.
# 종료 코드: 0 = 성공(경고가 있어도 0), 1 = 오류 1건 이상(specs/README.md 미변경).
# 출력(specs/002-smoke/contracts/cli.md 요약):
#   stdout  specs/README.md: <N> features indexed[ (unchanged)]
#   stderr  warning: skip <dir>: spec.md missing
#           error: <NNN-slug>/spec.md: missing H1 title
#           error: <NNN-slug>/spec.md: missing **Status** line
#           error: specs directory not found: <path>
#           error: specs/README.md: multiple index tables
#           error: cannot resolve repository root
#           error: <.NET 예외 메시지>  (I/O·디코딩 실패, 스택 없음)
# 복구 절차:
#   - run-all `scripts`/`specs-index-fresh` FAIL → 이 스크립트를 실행한 뒤 specs/README.md를 커밋한다.
#   - `error: <dir>/spec.md: …` → 지목된 spec.md 헤더(H1·**Status** 줄)를 고치고 다시 실행한다.
[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($PSScriptRoot)) {
    [Console]::Error.WriteLine('error: cannot resolve repository root')
    exit 1
}
if ([string]::IsNullOrEmpty($Root)) { $Root = Split-Path $PSScriptRoot -Parent }
$Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)
$specsDir = Join-Path $Root 'specs'
$readmePath = Join-Path $specsDir 'README.md'

if (-not (Test-Path -LiteralPath $specsDir -PathType Container)) {
    [Console]::Error.WriteLine("error: specs directory not found: $specsDir")
    exit 1
}

[Console]::Error.WriteLine('error: not implemented')
exit 1
