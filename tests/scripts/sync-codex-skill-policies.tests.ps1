# Codex Spec Kit policy-sidecar synchronizer tests.
# Run: pwsh -NoProfile -File tests/scripts/sync-codex-skill-policies.tests.ps1
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$subject = Join-Path $repo 'scripts/sync-codex-skill-policies.ps1'
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('codex-policy-' + [guid]::NewGuid().ToString('N'))
$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$condition, [string]$detail) {
    if ($condition) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function Invoke-Sync([string]$root, [string]$cwd) {
    Push-Location $cwd
    try {
        $out = pwsh -NoProfile -ExecutionPolicy Bypass -File $subject -Root $root 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    return @{ out = $out.Trim(); code = $code }
}

function New-Skill([string]$root, [string]$name) {
    $dir = Join-Path $root ".agents/skills/$name"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value "---`nname: $name`n---" -Encoding utf8NoBOM
}

try {
    New-Item -ItemType Directory -Path $fixture | Out-Null
    New-Skill $fixture 'speckit-alpha'
    New-Skill $fixture 'speckit-beta'
    New-Skill $fixture 'other-skill'

    $r = Invoke-Sync $fixture ([IO.Path]::GetTempPath())
    Assert 'sync-1: discovers every and only speckit-* skill from an arbitrary cwd' (
        $r.code -eq 0 -and $r.out -match 'Codex skill policies:\s*2 synced'
    ) "$($r.out) [code=$($r.code)]"

    $expected = "policy:`n  allow_implicit_invocation: false`n"
    $formatErrors = @()
    foreach ($name in @('speckit-alpha', 'speckit-beta')) {
        $path = Join-Path $fixture ".agents/skills/$name/agents/openai.yaml"
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $formatErrors += "missing:$name"; continue }
        $bytes = [IO.File]::ReadAllBytes($path)
        $text = [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
        if (-not [string]::Equals($text, $expected, [StringComparison]::Ordinal)) { $formatErrors += "content:$name" }
        if ($bytes -contains 13 -or ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
            $formatErrors += "encoding:$name"
        }
    }
    Assert 'sync-2: writes exact UTF-8-no-BOM LF explicit-only policy' ($formatErrors.Count -eq 0) ($formatErrors -join ', ')
    Assert 'sync-3: leaves non-Spec-Kit skills alone' (
        -not (Test-Path -LiteralPath (Join-Path $fixture '.agents/skills/other-skill/agents') -PathType Container)
    ) 'other-skill received an unexpected policy sidecar'

    $broken = Join-Path $fixture '.agents/skills/speckit-alpha/agents/openai.yaml'
    [IO.File]::WriteAllBytes($broken, [Text.Encoding]::UTF8.GetBytes("policy:`r`n  allow_implicit_invocation: true`r`n"))
    $r = Invoke-Sync $fixture $fixture
    $repaired = [Text.UTF8Encoding]::new($false, $true).GetString([IO.File]::ReadAllBytes($broken))
    Assert 'sync-4: repairs drift and remains content-idempotent on repeat' (
        $r.code -eq 0 -and [string]::Equals($repaired, $expected, [StringComparison]::Ordinal)
    ) "$($r.out) [code=$($r.code)]"
    $before = (Get-FileHash -LiteralPath $broken -Algorithm SHA256).Hash
    $r = Invoke-Sync $fixture $repo
    $after = (Get-FileHash -LiteralPath $broken -Algorithm SHA256).Hash
    Assert 'sync-5: second clean run preserves policy bytes' ($r.code -eq 0 -and $before -ceq $after) "$($r.out) [code=$($r.code)]"

    $empty = Join-Path $fixture 'empty'
    New-Item -ItemType Directory -Path (Join-Path $empty '.agents/skills') -Force | Out-Null
    $r = Invoke-Sync $empty $repo
    Assert 'sync-6: zero discovered Spec Kit skills fails closed' ($r.code -ne 0 -and $r.out -match 'Spec Kit skills') "$($r.out) [code=$($r.code)]"
} finally {
    Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
