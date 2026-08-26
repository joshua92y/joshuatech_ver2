# Hook unit tests. Run: pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1
# Exit 0 = all pass, 1 = failures. No external test framework.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hooks = Join-Path $repo '.claude/hooks'
$script:pass = 0
$script:fail = 0

function Invoke-Hook([string]$name, [hashtable]$payload, [string]$cwd) {
    $json = $payload | ConvertTo-Json -Compress -Depth 6
    $scriptPath = Join-Path $hooks $name
    if (-not (Test-Path $scriptPath)) { return @{ out = "<missing: $name>"; code = 127 } }
    Push-Location $cwd
    try {
        $out = $json | pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2>$null
        $code = $LASTEXITCODE
    } finally { Pop-Location }
    return @{ out = (($out | ForEach-Object { "$_" }) -join "`n"); code = $code }
}

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function New-Fixture([string]$branch, [hashtable]$files, [string]$featureJson) {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ('hooktest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    git -C $dir init -q -b main
    git -C $dir -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
    if ($branch -ne 'main') { git -C $dir checkout -q -b $branch }
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        New-Item -ItemType Directory -Path (Split-Path $p) -Force | Out-Null
        Set-Content -Path $p -Value $files[$rel] -Encoding utf8
    }
    if ($featureJson) {
        New-Item -ItemType Directory -Path (Join-Path $dir '.specify') -Force | Out-Null
        Set-Content -Path (Join-Path $dir '.specify/feature.json') -Value $featureJson -Encoding utf8
    }
    return $dir
}

# ---------- approval-review ----------
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = 'plan 승인해줘'; cwd = $repo } $repo
Assert 'approval: keyword -> systemMessage mentions /approval-review' ($r.code -eq 0 -and $r.out -match 'approval-review') $r.out
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = '오늘 날씨 어때'; cwd = $repo } $repo
Assert 'approval: no keyword -> no output' ($r.code -eq 0 -and [string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'approval-review.ps1' @{ hook_event_name = 'UserPromptSubmit'; prompt = 'lgtm'; cwd = $repo } $repo
Assert 'approval: lgtm (case-insensitive) -> systemMessage' ($r.code -eq 0 -and $r.out -match 'approval-review') $r.out

# ---------- finish-gate ----------
$finishing = @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'superpowers:finishing-a-development-branch'; args = '' } }
$ready = @{
    'specs/002-smoke/spec.md'                       = '# x'
    'specs/002-smoke/report.md'                     = '# Report'
    'specs/002-smoke/reviews/2026-08-26-finish.md'  = "# Finish review`nStatus: Approved"
    'content/study/002-smoke.mdx'                   = '---'
}
$empty = @{ 'specs/002-smoke/spec.md' = '# x' }

$d = New-Fixture '002-smoke' $empty $null
$r = Invoke-Hook 'finish-gate.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'superpowers:brainstorming' }; cwd = $d } $d
Assert 'gate: other skill -> no output' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch resolved, artifacts missing -> deny' ($r.out -match '"permissionDecision":"deny"' -and $r.out -match 'report.md') $r.out

$d = New-Fixture '002-smoke' $ready $null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch resolved, artifacts present -> allow (no output)' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

$d = New-Fixture 'main' $ready $null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: unresolvable (main, no env, no feature.json) -> deny' ($r.out -match 'could not be resolved') $r.out

$d = New-Fixture '002-smoke' $ready '{"feature_directory":"specs/003-other"}'
New-Item -ItemType Directory -Path (Join-Path $d 'specs/003-other') -Force | Out-Null
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Assert 'gate: branch vs feature.json mismatch -> deny' ($r.out -match 'disagree') $r.out

$d = New-Fixture 'main' $ready $null
$env:SPECIFY_FEATURE_DIRECTORY = 'specs/002-smoke'
$r = Invoke-Hook 'finish-gate.ps1' ($finishing + @{ cwd = $d }) $d
Remove-Item Env:SPECIFY_FEATURE_DIRECTORY
Assert 'gate: env var resolves on main -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

# ---------- tester-write-guard ----------
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Write'; tool_input = @{ file_path = "$repo\tests\e2e\a.test.ts" }; cwd = $repo } $repo
Assert 'guard: tests/e2e/*.test.ts -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Edit'; tool_input = @{ file_path = "$repo\src\app.ts" }; cwd = $repo } $repo
Assert 'guard: src/app.ts -> deny' ($r.out -match '"permissionDecision":"deny"') $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Write'; tool_input = @{ file_path = 'apps/web/src/x.spec.ts' }; cwd = $repo } $repo
Assert 'guard: relative *.spec.ts -> allow' ([string]::IsNullOrWhiteSpace($r.out)) $r.out
$r = Invoke-Hook 'tester-write-guard.ps1' @{ hook_event_name = 'PreToolUse'; tool_name = 'Read'; tool_input = @{ file_path = 'src/app.ts' }; cwd = $repo } $repo
Assert 'guard: Read is not guarded -> no output' ([string]::IsNullOrWhiteSpace($r.out)) $r.out

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
