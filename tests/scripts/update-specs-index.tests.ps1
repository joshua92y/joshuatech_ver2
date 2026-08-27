# scripts/update-specs-index.ps1 테스트. Run: pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/hooks/run-hook-tests.ps1와 같은 구조).
# 픽스처는 임시 디렉터리(specidx-<guid>)에 만들고 끝나면 지운다. 계약: specs/002-smoke/contracts/cli.md
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptPath = Join-Path $repo 'scripts/update-specs-index.ps1'
$script:pass = 0
$script:fail = 0
$script:fixtures = @()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function Format-Result($r) { "out=[$($r.out)] err=[$($r.err)] [code=$($r.code)]" }

# 키 = 픽스처 루트 기준 상대 경로, 값 = 문자열(UTF-8, BOM 없음) 또는 [byte[]](원본 바이트 그대로)
function New-Fixture([hashtable]$files = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('specidx-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        if ($files[$rel] -is [byte[]]) { [IO.File]::WriteAllBytes($p, $files[$rel]) }
        elseif ($files[$rel] -is [string]) { [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false)) }
        else { throw "New-Fixture: value for '$rel' must be [string] or [byte[]]" }
    }
    return $dir
}

function Remove-Fixture {
    foreach ($f in $script:fixtures) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
    $script:fixtures = @()
}

# 스크립트를 실행해 stdout·stderr를 따로 캡처한다. 스크립트 파일이 없으면 code=127.
#   $root  -Root 값. 비어 있으면 -Root 없이 실행한다(기본값 = 스크립트 상위 디렉터리, FR-014).
#   $file  실행할 스크립트 경로(기본값 저장소의 scripts/update-specs-index.ps1). 픽스처에 복사한 사본을 지정할 수 있다.
#   $cwd   실행 중 작업 디렉터리. 비어 있으면 현재 위치 그대로.
# out/err는 줄을 LF로 잇고 끝 개행을 뗀 문자열.
function Invoke-Script([string]$root, [string]$file = $scriptPath, [string]$cwd) {
    if (-not (Test-Path -LiteralPath $file)) { return @{ out = "<missing: $file>"; err = ''; code = 127 } }
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('specidx-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $file)
    if ($root) { $argv += @('-Root', $root) }
    if ($cwd) { Push-Location -LiteralPath $cwd }
    try {
        $out = & ([Environment]::ProcessPath) @argv 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
    } finally {
        if ($cwd) { Pop-Location }
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return @{
        out  = (@($out | ForEach-Object { "$_" }) -join "`n")
        err  = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code = $code
    }
}

function Read-Text([string]$path) { [IO.File]::ReadAllText($path) }
function Get-Stamp([string]$path) { (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks }

# ---------- US1 기본 픽스처 ----------
# README = 머리말 2문단 + 기존 표(내용은 틀림: 교체되어야 함) + 후행 문단
$us1Pre = "# Feature 인덱스`n`n둘째 머리말 문단. 이 줄은 그대로 남아야 한다.`n`n"
$us1OldTable = "| # | Feature | Status | 우선순위 | 링크 |`n|---|---|---|---|---|`n| 999 | stale | Draft | — | x |`n"
$us1Post = "`n> 후행 텍스트`n"
$us1Files = @{
    'specs/README.md'        = $us1Pre + $us1OldTable + $us1Post
    'specs/001-alpha/spec.md' = "# Feature Specification: 알파 (SP-0)`n**Status**: Approved (2026-08-26)`n**Priority**: 🔴`n"
    'specs/001-alpha/plan.md' = "# Implementation Plan: 알파`n"
    'specs/002-beta/spec.md'  = "# Feature Specification: 베타`n`n**Status**: Draft`n"
}
$us1Table = @(
    '| # | Feature | Status | 우선순위 | 링크 |'
    '|---|---|---|---|---|'
    '| 001 | 알파 (SP-0) | Approved (2026-08-26) | 🔴 | [spec](001-alpha/spec.md) · [plan](001-alpha/plan.md) |'
    '| 002 | 베타 | Draft | — | [spec](002-beta/spec.md) |'
)
$us1Inputs = @('specs/001-alpha/spec.md', 'specs/001-alpha/plan.md', 'specs/002-beta/spec.md')

# 표 4줄이 이 순서로 연속해서 나오는지
function Test-TableLines([string[]]$lines, [string[]]$expected) {
    $i = [Array]::IndexOf($lines, $expected[0])
    if ($i -lt 0 -or $i + $expected.Count -gt $lines.Count) { return $false }
    for ($k = 0; $k -lt $expected.Count; $k++) { if ($lines[$i + $k] -cne $expected[$k]) { return $false } }
    return $true
}

try {
    # ---------- specs/ 없음 (FR-015, Edge Cases) ----------
    $d = New-Fixture @{}
    $r = Invoke-Script $d
    Assert 'root: specs/ missing -> exit 1, stderr starts with "error: specs directory not found"' ($r.code -eq 1 -and ([string]$r.err).StartsWith('error: specs directory not found', [StringComparison]::Ordinal)) (Format-Result $r)

    # ---------- US1: 표 생성·머리말 보존·멱등·LF/BOM·입력 불변 ----------
    $repoReadme = Join-Path $repo 'specs/README.md'
    $repoStampBefore = Get-Stamp $repoReadme
    $d = New-Fixture $us1Files
    $readme = Join-Path $d 'specs/README.md'
    $inputBefore = @{}
    foreach ($rel in $us1Inputs) { $p = Join-Path $d $rel; $inputBefore[$rel] = @{ text = (Read-Text $p); stamp = (Get-Stamp $p) } }

    $r = Invoke-Script $d
    $after = Read-Text $readme
    $lines = $after -split "`n"
    $headerCount = @($lines | Where-Object { $_ -cmatch '^\| # \|' }).Count
    Assert 'US1-1: two features -> exit 0, "2 features indexed", table rows in order, single header (FR-005/006)' (
        $r.code -eq 0 -and $r.out -ceq 'specs/README.md: 2 features indexed' -and (Test-TableLines $lines $us1Table) -and $headerCount -eq 1
    ) ((Format-Result $r) + " headers=$headerCount readme=[$after]")
    Assert 'US1-2: preamble before and trailer after the table preserved verbatim (FR-007)' (
        $r.code -eq 0 -and $after.StartsWith($us1Pre, [StringComparison]::Ordinal) -and $after.EndsWith($us1Post, [StringComparison]::Ordinal)
    ) "readme=[$after]"
    $bytes = [IO.File]::ReadAllBytes($readme)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $hasCr = [Array]::IndexOf($bytes, [byte]13) -ge 0
    Assert 'US1-5: output is UTF-8 without BOM and has no CR (FR-012)' ($r.code -eq 0 -and -not $hasBom -and -not $hasCr) "code=$($r.code) bom=$hasBom cr=$hasCr"

    $text1 = $after
    $stamp1 = Get-Stamp $readme
    $r2 = Invoke-Script $d
    $text2 = Read-Text $readme
    $stamp2 = Get-Stamp $readme
    Assert 'US1-3: second run -> "(unchanged)", content and LastWriteTime untouched (FR-008)' (
        $r2.code -eq 0 -and $r2.out -ceq 'specs/README.md: 2 features indexed (unchanged)' -and $text2 -ceq $text1 -and $stamp2 -eq $stamp1
    ) ((Format-Result $r2) + " stamp1=$stamp1 stamp2=$stamp2 same=$($text2 -ceq $text1)")

    $inputsIntact = $true
    foreach ($rel in $us1Inputs) {
        $p = Join-Path $d $rel
        if ((Read-Text $p) -cne $inputBefore[$rel].text -or (Get-Stamp $p) -ne $inputBefore[$rel].stamp) { $inputsIntact = $false }
    }
    $repoStampAfter = Get-Stamp $repoReadme
    Assert 'US1-6: spec.md/plan.md inputs and the real specs/README.md untouched (read-only inputs, isolation)' (
        $r.code -eq 0 -and $r2.code -eq 0 -and $inputsIntact -and $repoStampAfter -eq $repoStampBefore
    ) "codes=$($r.code)/$($r2.code) inputsIntact=$inputsIntact repoStamp=$repoStampBefore/$repoStampAfter"

    # ---------- US1-4: cwd 무관 — 픽스처의 scripts/ 사본을 -Root 없이 다른 cwd에서 실행 (FR-014) ----------
    $d = New-Fixture $us1Files
    New-Item -ItemType Directory -Path (Join-Path $d 'scripts') | Out-Null
    $copy = Join-Path $d 'scripts/update-specs-index.ps1'
    Copy-Item -LiteralPath $scriptPath -Destination $copy
    $tempRoot = [IO.Path]::GetTempPath()
    $strayReadme = Join-Path $tempRoot 'specs/README.md'
    $r = Invoke-Script '' $copy $tempRoot
    $after = Read-Text (Join-Path $d 'specs/README.md')
    Assert 'US1-4: no -Root from another cwd -> resolves root from script location, no README under cwd (FR-014)' (
        $r.code -eq 0 -and (Test-TableLines ($after -split "`n") $us1Table) -and -not (Test-Path -LiteralPath $strayReadme)
    ) ((Format-Result $r) + " stray=$(Test-Path -LiteralPath $strayReadme) readme=[$after]")
} finally {
    Remove-Fixture
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
