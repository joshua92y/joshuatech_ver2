# scripts/update-specs-index.ps1 테스트. Run: pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/hooks/run-hook-tests.ps1와 같은 구조).
# 픽스처는 임시 디렉터리(specidx-<guid>)에 만들고 끝나면 지운다. 계약: specs/002-smoke/contracts/cli.md
$ErrorActionPreference = 'Stop'
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
        else { [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false)) }
    }
    return $dir
}

function Remove-Fixture {
    foreach ($f in $script:fixtures) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
    $script:fixtures = @()
}

# 스크립트를 -Root $root로 실행해 stdout·stderr를 따로 캡처한다. 스크립트 파일이 없으면 code=127.
# out/err는 줄을 LF로 잇고 끝 개행을 뗀 문자열.
function Invoke-Script([string]$root) {
    if (-not (Test-Path -LiteralPath $scriptPath)) { return @{ out = "<missing: $scriptPath>"; err = ''; code = 127 } }
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('specidx-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath -Root $root 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return @{
        out  = (@($out | ForEach-Object { "$_" }) -join "`n")
        err  = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code = $code
    }
}

try {
    # ---------- specs/ 없음 (FR-015, Edge Cases) ----------
    $d = New-Fixture @{}
    $r = Invoke-Script $d
    Assert 'root: specs/ missing -> exit 1, stderr starts with "error: specs directory not found"' ($r.code -eq 1 -and ([string]$r.err).StartsWith('error: specs directory not found', [StringComparison]::Ordinal)) (Format-Result $r)
} finally {
    Remove-Fixture
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
