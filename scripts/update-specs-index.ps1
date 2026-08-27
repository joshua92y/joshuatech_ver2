# update-specs-index.ps1 — specs/README.md의 feature 인덱스 표를 specs/<NNN-slug>/spec.md 헤더에서 재생성한다.
#
# 호출: pwsh -NoProfile -File scripts/update-specs-index.ps1 [-Root <path>]
#   -Root <path>  저장소 루트. 기본값은 이 스크립트 파일의 상위 디렉터리(= 저장소 루트, scripts/의 상위; FR-014, cwd 무관).
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
#           error: specs/README.md is read-only: <path>
#           error: <.NET 예외 메시지>  (I/O·디코딩 실패, 스택 없음)
# 실패 닫힘(fail-closed): 본문 전체가 try/catch 안에서 실행되어 어떤 예외도 `error: <메시지>` 한 줄 + exit 1로 끝난다.
#   H1·Status 누락은 모든 spec.md를 훑은 뒤 한꺼번에 보고하며, README는 읽기·쓰기 전에 중단된다.
# 복구 절차:
#   - run-all `scripts`/`specs-index-fresh` FAIL → 이 스크립트를 실행한 뒤 specs/README.md를 커밋한다.
#   - `error: <dir>/spec.md: …` → 지목된 spec.md 헤더(H1·**Status** 줄)를 고치고 다시 실행한다.
#   - `warning: skip <dir>: spec.md missing` → 그 디렉터리에 spec.md를 만들거나 디렉터리를 정리한다.
[CmdletBinding()]
param([string]$Root)
$ErrorActionPreference = 'Stop'

# ---------- 헬퍼(정의만; 실행은 아래 try 안에서) ----------
$utf8Strict = [Text.UTF8Encoding]::new($false, $true)   # 잘못된 바이트는 예외(디코딩 실패는 error:로 보고)

# 파일을 UTF-8로 엄격히 디코딩한 원문(BOM은 U+FEFF로 남고 CRLF도 그대로)을 돌려준다.
function Read-Utf8Text([string]$path) { $utf8Strict.GetString([IO.File]::ReadAllBytes($path)) }

# BOM 제거·CRLF→LF 정규화
function ConvertTo-Lf([string]$text) { $text.TrimStart([char]0xFEFF).Replace("`r`n", "`n") }

# 줄 배열에서 패턴에 처음 맞는 줄의 캡처 그룹 1을 돌려준다(없으면 $null). 같은 줄이 여러 개면 첫 줄만 쓴다.
function Find-FirstMatch([string[]]$lines, [string]$pattern) {
    foreach ($line in $lines) { if ($line -cmatch $pattern) { return $Matches[1] } }
    return $null
}

# Status 정규화(FR-003, research R7): 첫 번째 괄호 그룹에 쉼표가 있을 때만 그 첫 쉼표부터 닫는 괄호 앞까지를 지운다(1회만). 결과는 Trim.
#   정규식이 문자열 시작(^)에 앵커되어 있으므로 첫 괄호 그룹만 검사하며, 두 번째 이후 괄호 그룹은 쉼표가 있어도 절대 건드리지 않는다.
#   "Approved (2026-08-26, 주석) (extra, y)" → "Approved (2026-08-26) (extra, y)",  "Approved (2026-08-26) (note, x)"·"Done (2026-08-27)"·"Draft" → 그대로
function ConvertTo-NormalizedStatus([string]$s) { [regex]::new('^([^(]*\()([^,)]*),[^)]*\)').Replace($s, '$1$2)', 1).Trim() }

# 셀 값 정리: 홀로 남은 CR 제거(출력에 CR이 절대 없도록, FR-012) + Trim
function ConvertTo-CellText([string]$s) { $s.Replace("`r", '').Trim() }

# specs/<NNN-slug>/spec.md 헤더 → 항목. H1·Status 누락(줄 없음 또는 공백뿐)은 빈 문자열(누락 보고는 수집 뒤 한꺼번에).
function Get-FeatureEntry([string]$dirPath, [string]$name, [string]$number) {
    $lines = (ConvertTo-Lf (Read-Utf8Text (Join-Path $dirPath 'spec.md'))) -split "`n"
    $title = Find-FirstMatch $lines '^#\s+(.+?)\s*$'
    $title = if ($null -eq $title) { '' } else { ConvertTo-CellText ($title -creplace '^Feature Specification:\s*', '') }   # FR-002
    $status = Find-FirstMatch $lines '^\*\*Status\*\*:\s*(.+?)\s*$'
    $status = if ($null -eq $status) { '' } else { ConvertTo-CellText (ConvertTo-NormalizedStatus $status) }              # FR-003
    $priority = Find-FirstMatch $lines '^\*\*Priority\*\*:\s*(.+?)\s*$'
    $priority = if ($null -eq $priority) { '' } else { ConvertTo-CellText $priority }
    if ($priority.Length -eq 0) { $priority = '—' }                                                                       # FR-004: 줄 없음·공백뿐 → —
    [pscustomobject]@{
        Dir      = $name
        Number   = $number
        Title    = $title
        Status   = $status
        Priority = $priority
        HasPlan  = (Test-Path -LiteralPath (Join-Path $dirPath 'plan.md') -PathType Leaf)
    }
}

# 셀 이스케이프: `\` → `\\` 먼저, 그다음 `|` → `\|` (FR-013; 이미 `\|`인 값도 깨지지 않는다)
function ConvertTo-Cell([string]$value) { $value.Replace('\', '\\').Replace('|', '\|') }

function Format-Row($entry) {
    $links = "[spec]($($entry.Dir)/spec.md)"
    if ($entry.HasPlan) { $links += " · [plan]($($entry.Dir)/plan.md)" }
    return "| $($entry.Number) | $(ConvertTo-Cell $entry.Title) | $(ConvertTo-Cell $entry.Status) | $(ConvertTo-Cell $entry.Priority) | $links |"
}

# ---------- 본문: 모든 예외는 catch에서 `error: <메시지>` 한 줄 + exit 1 (exit는 catch에 잡히지 않는다) ----------
try {
    if ([string]::IsNullOrEmpty($PSScriptRoot)) {
        [Console]::Error.WriteLine('error: cannot resolve repository root')
        exit 1
    }
    if ([string]::IsNullOrEmpty($Root)) { $Root = Split-Path $PSScriptRoot -Parent }
    # 상대 경로·`~`를 .NET 프로세스 cwd가 아니라 PowerShell의 $PWD·PS 드라이브 기준으로 푼다([IO.Path]::GetFullPath를 쓰지 않은 이유)
    $Root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Root)   # 알 수 없는 드라이브 등은 예외 → error:
    $specsDir = Join-Path $Root 'specs'
    $readmePath = Join-Path $specsDir 'README.md'

    if (-not (Test-Path -LiteralPath $specsDir -PathType Container)) {
        [Console]::Error.WriteLine("error: specs directory not found: $specsDir")
        exit 1
    }

    # ---------- 수집 ----------
    # feature 디렉터리: NNN-slug(ASCII 숫자 3자리 이상 + 하이픈 + ASCII slug), 정션·심볼릭 링크 제외. 그 밖의 항목은 조용히 무시.
    # spec.md가 없는 NNN 디렉터리는 경고 후 건너뛴다(FR-010; 종료 코드에 영향 없음).
    # 디렉터리는 이름 ordinal 순으로 훑는다 — 경고(warning: skip …)가 파일시스템과 무관하게 늘 같은 순서로 나온다.
    $dirs = [Collections.Generic.List[object]]::new([object[]]@(Get-ChildItem -LiteralPath $specsDir -Directory -Attributes !ReparsePoint | Where-Object Name -CMatch '^[0-9]{3,}-[A-Za-z0-9][A-Za-z0-9-]*$'))
    $dirs.Sort([Comparison[object]] { param($a, $b) [StringComparer]::Ordinal.Compare($a.Name, $b.Name) })
    $entries = [Collections.Generic.List[object]]::new()
    foreach ($dir in $dirs) {
        if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName 'spec.md') -PathType Leaf)) {
            [Console]::Error.WriteLine("warning: skip $($dir.Name): spec.md missing")
            continue
        }
        $number = $dir.Name.Substring(0, $dir.Name.IndexOf([char]'-'))
        $entries.Add((Get-FeatureEntry $dir.FullName $dir.Name $number))
    }
    # 정렬: (번호 길이, 번호 ordinal, 디렉터리명 ordinal) — 숫자 캐스트 없이 자릿수가 커도 안전
    $entries.Sort([Comparison[object]] {
        param($a, $b)
        $c = $a.Number.Length.CompareTo($b.Number.Length); if ($c -ne 0) { return $c }
        $c = [StringComparer]::Ordinal.Compare($a.Number, $b.Number); if ($c -ne 0) { return $c }
        return [StringComparer]::Ordinal.Compare($a.Dir, $b.Dir)
    })

    # ---------- 누락 검증(FR-009): README를 읽거나 쓰기 전에, 모든 오류를 모아 한꺼번에 보고 ----------
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($entry in $entries) {
        if ($entry.Title.Length -eq 0) { $errors.Add("error: $($entry.Dir)/spec.md: missing H1 title") }
        if ($entry.Status.Length -eq 0) { $errors.Add("error: $($entry.Dir)/spec.md: missing **Status** line") }
    }
    if ($errors.Count -gt 0) {
        foreach ($message in $errors) { [Console]::Error.WriteLine($message) }
        exit 1
    }

    # ---------- 표 조립 ----------
    $table = (@('| # | Feature | Status | 우선순위 | 링크 |', '|---|---|---|---|---|') + @($entries | ForEach-Object { Format-Row $_ })) -join "`n"

    # ---------- README 병합 ----------
    # 파일 없음 → 기본 머리말 + 표 (FR-011). 있음 → `| # |` 헤더 줄부터 연속된 `|` 줄 블록만 교체, 앞뒤는 그대로 (FR-007).
    # 표가 없으면 본문 뒤에 빈 줄 하나 두고 덧붙인다; 본문이 비어 있으면(0바이트·공백뿐) 표가 1행부터 시작한다.
    $defaultPreamble = "# Feature 인덱스`n`n" + '각 feature의 `spec.md` 헤더에서 `scripts/update-specs-index.ps1`로 재생성한다. 디렉터리는 이동·삭제하지 않는다(불변 이력). 상태: Draft → Approved → Done.' + "`n`n"
    $raw = $null   # 디스크 원문(BOM·CRLF 포함). 비교는 이 값과 하므로 CRLF/BOM README는 1회 LF·BOM 없음으로 재기록된다.
    if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
        $raw = Read-Utf8Text $readmePath
        $lines = (ConvertTo-Lf $raw) -split "`n"
        $headerIdx = @(0..($lines.Count - 1) | Where-Object { $lines[$_] -cmatch '^\| # \|' })
        if ($headerIdx.Count -ge 2) {
            [Console]::Error.WriteLine('error: specs/README.md: multiple index tables')
            exit 1
        }
        if ($headerIdx.Count -eq 0) {
            $body = (ConvertTo-Lf $raw).TrimEnd()
            $new = if ($body.Length -eq 0) { $table + "`n" } else { $body + "`n`n" + $table + "`n" }
        } else {
            $start = $headerIdx[0]
            $end = $start
            while ($end + 1 -lt $lines.Count -and $lines[$end + 1].StartsWith('|', [StringComparison]::Ordinal)) { $end++ }
            $preamble = if ($start -gt 0) { $lines[0..($start - 1)] } else { @() }
            $trailer = if ($end -lt $lines.Count - 1) { $lines[($end + 1)..($lines.Count - 1)] } else { @() }
            $new = (@($preamble) + @($table) + @($trailer)) -join "`n"
        }
    } else {
        $new = $defaultPreamble + $table + "`n"
    }

    # ---------- 쓰기 (멱등·원자적) ----------
    $count = $entries.Count
    if ($null -ne $raw -and [string]::Equals($new, $raw, [StringComparison]::Ordinal)) {   # -ceq는 문화권 비교라 BOM(U+FEFF) 등 무시 가능 문자를 건너뛴다
        Write-Output "specs/README.md: $count features indexed (unchanged)"
        exit 0
    }
    # 읽기 전용 README는 플랫폼과 무관하게 실패시킨다(Linux rename은 읽기 전용 대상도 덮어쓴다). README는 그대로 남는다.
    #   FileInfo로 검사한다(프로바이더 무관): Get-Item은 Hidden 파일을 못 찾아 엉뚱한 메시지(Could not find item)를 낸다.
    #   $raw ≠ $null ⇔ README가 존재한다(없는 파일의 FileInfo.IsReadOnly는 true이므로 이 가드가 필요하다).
    if ($null -ne $raw -and [IO.FileInfo]::new($readmePath).IsReadOnly) {
        throw "specs/README.md is read-only: $readmePath"
    }
    $tmp = Join-Path $specsDir ('README.md.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($tmp, $new, [Text.UTF8Encoding]::new($false))   # UTF-8, BOM 없음, LF (FR-012)
        [IO.File]::Move($tmp, $readmePath, $true)                               # 원자적 교체
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
    Write-Output "specs/README.md: $count features indexed"
    exit 0
} catch {
    [Console]::Error.WriteLine("error: $($_.Exception.GetBaseException().Message)")
    exit 1
}
