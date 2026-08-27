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

# ---------- 읽기·파싱 ----------
$utf8Strict = [Text.UTF8Encoding]::new($false, $true)   # 잘못된 바이트는 예외(디코딩 실패는 error:로 보고)

# 파일을 UTF-8로 엄격히 디코딩한 원문(BOM은 U+FEFF로 남고 CRLF도 그대로)을 돌려준다.
function Read-Utf8Text([string]$path) { $utf8Strict.GetString([IO.File]::ReadAllBytes($path)) }

# BOM 제거·CRLF→LF 정규화
function ConvertTo-Lf([string]$text) { $text.TrimStart([char]0xFEFF).Replace("`r`n", "`n") }

# 줄 배열에서 패턴에 처음 맞는 줄의 캡처 그룹 1을 돌려준다(없으면 $null).
function Find-FirstMatch([string[]]$lines, [string]$pattern) {
    foreach ($line in $lines) { if ($line -cmatch $pattern) { return $Matches[1] } }
    return $null
}

# specs/<NNN-slug>/spec.md 헤더 → 항목. H1·Status 누락 시 빈 문자열(누락 보고는 별도 단계).
function Get-FeatureEntry([string]$dirPath, [string]$name, [string]$number) {
    $lines = (ConvertTo-Lf (Read-Utf8Text (Join-Path $dirPath 'spec.md'))) -split "`n"
    $title = Find-FirstMatch $lines '^#\s+(.+?)\s*$'
    $title = if ($null -eq $title) { '' } else { ($title -creplace '^Feature Specification:\s*', '').Trim() }   # FR-002
    $status = Find-FirstMatch $lines '^\*\*Status\*\*:\s*(.+?)\s*$'
    if ($null -eq $status) { $status = '' }
    $priority = Find-FirstMatch $lines '^\*\*Priority\*\*:\s*(.+?)\s*$'
    if ($null -eq $priority) { $priority = '—' }                                                       # FR-004
    [pscustomobject]@{
        Dir      = $name
        Number   = $number
        Title    = $title
        Status   = $status
        Priority = $priority
        HasPlan  = (Test-Path -LiteralPath (Join-Path $dirPath 'plan.md') -PathType Leaf)
    }
}

# feature 디렉터리 수집: NNN-slug(ASCII 숫자 3자리 이상 + 하이픈 + ASCII slug), 정션·심볼릭 링크 제외
$entries = [Collections.Generic.List[object]]::new()
foreach ($dir in @(Get-ChildItem -LiteralPath $specsDir -Directory -Attributes !ReparsePoint | Where-Object Name -CMatch '^[0-9]{3,}-[A-Za-z0-9][A-Za-z0-9-]*$')) {
    $number = $dir.Name.Substring(0, $dir.Name.IndexOf('-'))
    $entries.Add((Get-FeatureEntry $dir.FullName $dir.Name $number))
}
# 정렬: (번호 길이, 번호 ordinal, 디렉터리명 ordinal) — 숫자 캐스트 없이 자릿수가 커도 안전
$entries.Sort([Comparison[object]] {
    param($a, $b)
    $c = $a.Number.Length.CompareTo($b.Number.Length); if ($c -ne 0) { return $c }
    $c = [StringComparer]::Ordinal.Compare($a.Number, $b.Number); if ($c -ne 0) { return $c }
    return [StringComparer]::Ordinal.Compare($a.Dir, $b.Dir)
})

[Console]::Error.WriteLine('error: not implemented')
exit 1
