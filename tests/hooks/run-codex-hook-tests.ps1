# Codex hook contract tests.
# Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/hooks/run-codex-hook-tests.ps1
# Exit 0 = all pass, 1 = contract failures. No external test framework.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$hooks = Join-Path $repo '.codex/hooks'
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

function Assert([string]$name, [bool]$condition, [string]$detail) {
    if ($condition) {
        $script:pass++
        Write-Host "PASS $name"
    } else {
        $script:fail++
        Write-Host "FAIL $name -- $detail"
    }
}

function Detail([object]$result) {
    if ($result.missing) { return "missing hook: $($result.path)" }
    $stdout = if ([string]::IsNullOrWhiteSpace($result.out)) { '<empty>' } else { $result.out }
    $stderr = if ([string]::IsNullOrWhiteSpace($result.err)) { '<empty>' } else { $result.err }
    $parse = if ($result.jsonError) { "; jsonError=$($result.jsonError)" } else { '' }
    return "stdout=$stdout; stderr=$stderr; code=$($result.code)$parse"
}

function Invoke-Hook {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Payload,
        [Parameter(Mandatory)][string]$Cwd,
        [switch]$RawJson
    )

    $scriptPath = Join-Path $hooks $Name
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return [pscustomobject]@{
            out = ''
            err = ''
            code = 127
            json = $null
            jsonError = 'hook missing'
            missing = $true
            path = $scriptPath
        }
    }

    $inputText = if ($RawJson) { [string]$Payload } else { $Payload | ConvertTo-Json -Compress -Depth 20 }
    $stderrPath = Join-Path $script:tempRoot ('codex-hook-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $lines = @()
    $code = 1
    try {
        Push-Location $Cwd
        try {
            $lines = @($inputText | pwsh -NoProfile -ExecutionPolicy Bypass -File $scriptPath 2> $stderrPath)
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $stdout = ($lines | ForEach-Object { [string]$_ }) -join "`n"
        $stderr = if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            [IO.File]::ReadAllText($stderrPath)
        } else { '' }
        $parsed = $null
        $jsonError = $null
        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            try { $parsed = $stdout | ConvertFrom-Json -Depth 20 }
            catch { $jsonError = $_.Exception.Message }
        }

        return [pscustomobject]@{
            out = $stdout
            err = $stderr
            code = $code
            json = $parsed
            jsonError = $jsonError
            missing = $false
            path = $scriptPath
        }
    } finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-PreToolDeny([object]$result) {
    return $result.code -eq 0 -and
        -not $result.jsonError -and
        $result.json.hookSpecificOutput.hookEventName -ceq 'PreToolUse' -and
        $result.json.hookSpecificOutput.permissionDecision -ceq 'deny' -and
        -not [string]::IsNullOrWhiteSpace([string]$result.json.hookSpecificOutput.permissionDecisionReason)
}

function Test-StopBlock([object]$result) {
    return $result.code -eq 0 -and
        -not $result.jsonError -and
        $result.json.decision -ceq 'block' -and
        -not [string]::IsNullOrWhiteSpace([string]$result.json.reason)
}

function Test-StopPassThrough([object]$result) {
    if ($result.code -ne 0 -or $result.jsonError -or [string]::IsNullOrWhiteSpace($result.out) -or $null -eq $result.json) {
        return $false
    }
    if ($result.json.decision -ceq 'block') { return $false }
    if ($null -ne $result.json.PSObject.Properties['continue'] -and $result.json.continue -eq $false) { return $false }
    return $true
}

function Test-StopDoesNotRepeat([object]$result) {
    return $result.code -eq 0 -and
        -not $result.jsonError -and
        -not [string]::IsNullOrWhiteSpace($result.out) -and
        $null -ne $result.json -and
        $result.json.decision -cne 'block'
}

function New-Fixture([string]$branch, [hashtable]$files, [string]$featureJson) {
    $dir = Join-Path $script:tempRoot ('codex-hooktest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $dir = [IO.Path]::GetFullPath($dir)
    $script:fixtures += $dir

    git -C $dir init -q -b main
    if ($LASTEXITCODE -ne 0) { throw "git init failed for fixture: $dir" }
    git -C $dir -c user.name=codex-hook-test -c user.email=codex-hook@test.invalid commit -q --allow-empty -m init
    if ($LASTEXITCODE -ne 0) { throw "git commit failed for fixture: $dir" }
    if ($branch -cne 'main') {
        git -C $dir checkout -q -b $branch
        if ($LASTEXITCODE -ne 0) { throw "git checkout failed for fixture branch: $branch" }
    }

    foreach ($relativePath in $files.Keys) {
        $path = Join-Path $dir $relativePath
        $parent = Split-Path -Parent $path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
        [IO.File]::WriteAllText($path, [string]$files[$relativePath], [Text.UTF8Encoding]::new($false))
    }
    if ($featureJson) {
        $specify = Join-Path $dir '.specify'
        New-Item -ItemType Directory -Path $specify -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $specify 'feature.json'), $featureJson, [Text.UTF8Encoding]::new($false))
    }
    return $dir
}

function Remove-Fixtures {
    $tempPrefix = $script:tempRoot + [IO.Path]::DirectorySeparatorChar
    foreach ($fixture in $script:fixtures) {
        try {
            $full = [IO.Path]::GetFullPath($fixture)
            $leaf = Split-Path -Leaf $full
            if (-not $full.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or $leaf -notlike 'codex-hooktest-*') {
                Write-Warning "Refusing to remove unexpected fixture path: $full"
                continue
            }
            Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not remove fixture '$fixture': $($_.Exception.Message)"
        }
    }
    $script:fixtures = @()
}

function Get-ConfiguredHandlers([object]$config, [string]$eventName) {
    if ($null -eq $config -or $null -eq $config.hooks) { return @() }
    $eventProperty = $config.hooks.PSObject.Properties[$eventName]
    if ($null -eq $eventProperty) { return @() }
    $handlers = @()
    foreach ($group in @($eventProperty.Value)) { $handlers += @($group.hooks) }
    return $handlers
}

function Test-ConfiguredScript([object]$config, [string]$eventName, [string]$scriptName) {
    $escaped = [regex]::Escape($scriptName)
    foreach ($handler in @(Get-ConfiguredHandlers $config $eventName)) {
        $windowsCommand = if ($handler.commandWindows) { [string]$handler.commandWindows } else { [string]$handler.command_windows }
        if ($handler.type -ceq 'command' -and
            [string]$handler.command -match $escaped -and
            $windowsCommand -match $escaped) {
            return $true
        }
    }
    return $false
}

$featureEnvExisted = Test-Path Env:SPECIFY_FEATURE_DIRECTORY
$savedFeatureEnv = $env:SPECIFY_FEATURE_DIRECTORY
Remove-Item Env:SPECIFY_FEATURE_DIRECTORY -ErrorAction SilentlyContinue
$testerReparsePath = $null
$finishReparsePath = $null

try {
    # ---------- native hook wiring ----------
    $configPath = Join-Path $repo '.codex/hooks.json'
    $config = $null
    $configError = $null
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 20 }
        catch { $configError = $_.Exception.Message }
    } else { $configError = 'missing .codex/hooks.json' }

    Assert 'config: hooks.json is valid JSON' ($null -ne $config -and -not $configError) $configError
    Assert 'config: UserPromptSubmit wires approval hook for both command variants' (
        Test-ConfiguredScript $config 'UserPromptSubmit' 'approval-review.ps1'
    ) 'missing command/commandWindows approval-review handler'
    Assert 'config: Stop wires finish gate for both command variants' (
        Test-ConfiguredScript $config 'Stop' 'finish-gate.ps1'
    ) 'missing command/commandWindows finish-gate handler'
    $globalTester = @(Get-ConfiguredHandlers $config 'PreToolUse' | Where-Object {
        ([string]$_.command -match 'tester-write-guard\.ps1') -or ([string]$_.commandWindows -match 'tester-write-guard\.ps1')
    })
    Assert 'config: tester guard is not global' ($globalTester.Count -eq 0) 'tester-write-guard must be registered only on the tester agent'

    # ---------- UserPromptSubmit / approval-review ----------
    $result = Invoke-Hook -Name 'approval-review.ps1' -Payload @{
        hook_event_name = 'UserPromptSubmit'
        prompt = 'plan 승인해줘'
        cwd = $repo
    } -Cwd $repo
    $approvalContext = [string]$result.json.hookSpecificOutput.additionalContext
    Assert 'approval: Korean approval returns valid additionalContext' (
        $result.code -eq 0 -and -not $result.jsonError -and
        $result.json.hookSpecificOutput.hookEventName -ceq 'UserPromptSubmit' -and
        $approvalContext.Contains('$approval-review')
    ) (Detail $result)

    $result = Invoke-Hook -Name 'approval-review.ps1' -Payload @{
        hook_event_name = 'UserPromptSubmit'
        prompt = 'LGTM, 진행해 주세요'
        cwd = $repo
    } -Cwd $repo
    $approvalContext = [string]$result.json.hookSpecificOutput.additionalContext
    Assert 'approval: LGTM is case-insensitive and names the Codex skill' (
        $result.code -eq 0 -and -not $result.jsonError -and $approvalContext.Contains('$approval-review')
    ) (Detail $result)

    $result = Invoke-Hook -Name 'approval-review.ps1' -Payload @{
        hook_event_name = 'UserPromptSubmit'
        prompt = '오늘 테스트 결과를 요약해줘'
        cwd = $repo
    } -Cwd $repo
    Assert 'approval: neutral prompt is a no-op' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    $result = Invoke-Hook -Name 'approval-review.ps1' -Payload @{
        hook_event_name = 'UserPromptSubmit'
        prompt = 'The plan was disapproved and must not proceed.'
        cwd = $repo
    } -Cwd $repo
    Assert 'approval: embedded negated English keyword is a no-op' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    $result = Invoke-Hook -Name 'approval-review.ps1' -Payload '{ definitely not json' -Cwd $repo -RawJson
    Assert 'approval: malformed JSON fails open' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    # ---------- PreToolUse / tester apply_patch guard ----------
    $testerFixture = New-Fixture '002-hook-contract' @{} $null
    $testerNestedCwd = Join-Path $testerFixture 'nested/workdir'
    New-Item -ItemType Directory -Path $testerNestedCwd -Force | Out-Null
    $allowedPatch = @'
*** Begin Patch
*** Add File: tests/hooks/new.test.ts
+export const added = true;
*** Update File: apps/web/src/widget.spec.ts
@@
-old
+updated
*** Delete File: e2e/obsolete.ts
*** Update File: packages/tool/__tests__/before.ts
*** Move to: packages/tool/__tests__/after.ts
@@
-before
+after
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $allowedPatch }
        cwd = $testerNestedCwd
    } -Cwd $testerNestedCwd
    Assert 'tester: Add/Update/Delete/Move resolve from git root under a nested cwd' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    $mixedPatch = @'
*** Begin Patch
*** Add File: tests/hooks/safe.test.ts
+safe
*** Update File: apps/web/src/production.ts
@@
-old
+unsafe
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $mixedPatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: one production target makes a mixed patch deny' (
        (Test-PreToolDeny $result) -and [string]$result.json.hookSpecificOutput.permissionDecisionReason -match 'production\.ts'
    ) (Detail $result)

    $outsidePath = (Join-Path $script:tempRoot ('codex-outside-' + [guid]::NewGuid().ToString('N') + '.ts')) -replace '\\', '/'
    $outsidePatch = "*** Begin Patch`n*** Add File: $outsidePath`n+outside`n*** End Patch"
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $outsidePatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: absolute path outside git root is denied' (
        (Test-PreToolDeny $result) -and [string]$result.json.hookSpecificOutput.permissionDecisionReason -match 'outside'
    ) (Detail $result)

    $traversalPatch = @'
*** Begin Patch
*** Delete File: tests/../../escape.ts
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $traversalPatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: normalized traversal outside git root is denied' (
        (Test-PreToolDeny $result) -and [string]$result.json.hookSpecificOutput.permissionDecisionReason -match 'outside|escape\.ts'
    ) (Detail $result)

    $reparseTarget = Join-Path $script:tempRoot ('codex-hooktest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $reparseTarget | Out-Null
    $script:fixtures += $reparseTarget
    $testerReparsePath = Join-Path $testerFixture 'tests/reparse-outside'
    New-Item -ItemType Directory -Path (Split-Path -Parent $testerReparsePath) -Force | Out-Null
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $testerReparsePath -Target $reparseTarget | Out-Null
    $reparsePatch = @'
*** Begin Patch
*** Add File: tests/reparse-outside/escape.test.ts
+escaped through a reparse point
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $reparsePatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: existing reparse-point ancestor is denied' (
        (Test-PreToolDeny $result) -and [string]$result.json.hookSpecificOutput.permissionDecisionReason -match 'reparse|link|outside'
    ) (Detail $result)

    $moveFromProduction = @'
*** Begin Patch
*** Update File: apps/web/src/production.ts
*** Move to: tests/production.test.ts
@@
-old
+new
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $moveFromProduction }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: move source is independently checked' (Test-PreToolDeny $result) (Detail $result)

    $moveToProduction = @'
*** Begin Patch
*** Update File: tests/production.test.ts
*** Move to: apps/web/src/production.ts
@@
-old
+new
*** End Patch
'@
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $moveToProduction }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: move destination is independently checked' (Test-PreToolDeny $result) (Detail $result)

    $noTargetPatch = "*** Begin Patch`n*** End Patch"
    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $noTargetPatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: recognized apply_patch with zero targets fails closed' (Test-PreToolDeny $result) (Detail $result)

    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'Bash'
        tool_input = @{ command = $mixedPatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: non-apply_patch tool is a no-op' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    $result = Invoke-Hook -Name 'tester-write-guard.ps1' -Payload @{
        hook_event_name = 'PostToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = $mixedPatch }
        cwd = $testerFixture
    } -Cwd $testerFixture
    Assert 'tester: explicitly unrelated hook event is a no-op' (
        $result.code -eq 0 -and [string]::IsNullOrWhiteSpace($result.out)
    ) (Detail $result)

    $testerMalformedPayloads = [ordered]@{
        'tester: empty hook input fails closed' = @{ Payload = ''; RawJson = $true }
        'tester: malformed JSON fails closed' = @{ Payload = '{ definitely not json'; RawJson = $true }
        'tester: missing event name fails closed' = @{ Payload = @{ tool_name = 'apply_patch'; tool_input = @{ command = $allowedPatch } }; RawJson = $false }
        'tester: non-string event name fails closed' = @{ Payload = @{ hook_event_name = @('PreToolUse'); tool_name = 'apply_patch'; tool_input = @{ command = $allowedPatch } }; RawJson = $false }
        'tester: missing tool name fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_input = @{ command = $allowedPatch } }; RawJson = $false }
        'tester: non-string tool name fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_name = 42; tool_input = @{ command = $allowedPatch } }; RawJson = $false }
        'tester: missing tool input fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_name = 'apply_patch' }; RawJson = $false }
        'tester: non-object tool input fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_name = 'apply_patch'; tool_input = 'patch' }; RawJson = $false }
        'tester: missing patch command fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_name = 'apply_patch'; tool_input = @{} }; RawJson = $false }
        'tester: non-string patch command fails closed' = @{ Payload = @{ hook_event_name = 'PreToolUse'; tool_name = 'apply_patch'; tool_input = @{ command = 42 } }; RawJson = $false }
    }
    foreach ($case in $testerMalformedPayloads.GetEnumerator()) {
        $invokeArgs = @{
            Name = 'tester-write-guard.ps1'
            Payload = $case.Value.Payload
            Cwd = $testerFixture
        }
        if ($case.Value.RawJson) { $invokeArgs.RawJson = $true }
        $result = Invoke-Hook @invokeArgs
        Assert $case.Key (Test-PreToolDeny $result) (Detail $result)
    }

    # ---------- Stop / finish gate ----------
    $readyFiles = @{
        'specs/002-smoke/spec.md' = "# Spec`n**Status**: Approved`n"
        'specs/002-smoke/plan.md' = "# Plan`n"
        'specs/002-smoke/tasks.md' = "# Tasks`n- [x] T001 complete`n"
        'specs/002-smoke/report.md' = "# Report`nVerified.`n"
        'specs/002-smoke/reviews/2026-09-04-finish.md' = "# Finish review`nStatus: Approved`n"
        'content/study/002-smoke.mdx' = "---`ntitle: smoke`ndraft: true`n---`n"
    }
    $incompleteFiles = @{
        'specs/002-smoke/spec.md' = "# Spec`n**Status**: Approved`n"
        'specs/002-smoke/plan.md' = "# Plan`n"
        'specs/002-smoke/tasks.md' = "# Tasks`n- [x] T001 complete`n"
    }
    $finishMarker = "Finish workflow completed.`n<!-- CODEX_FINISH_READY -->"

    $stopMalformedPayloads = [ordered]@{
        'finish: empty hook input blocks' = @{ Payload = ''; RawJson = $true }
        'finish: malformed JSON blocks' = @{ Payload = '{ definitely not json'; RawJson = $true }
        'finish: missing event name blocks' = @{ Payload = @{ stop_hook_active = $false; last_assistant_message = 'ordinary' }; RawJson = $false }
        'finish: non-string event name blocks' = @{ Payload = @{ hook_event_name = @('Stop'); stop_hook_active = $false; last_assistant_message = 'ordinary' }; RawJson = $false }
        'finish: missing stop-hook-active flag blocks' = @{ Payload = @{ hook_event_name = 'Stop'; last_assistant_message = 'ordinary' }; RawJson = $false }
        'finish: non-boolean stop-hook-active flag blocks' = @{ Payload = @{ hook_event_name = 'Stop'; stop_hook_active = 'false'; last_assistant_message = 'ordinary' }; RawJson = $false }
        'finish: missing assistant message blocks' = @{ Payload = @{ hook_event_name = 'Stop'; stop_hook_active = $false }; RawJson = $false }
        'finish: non-string assistant message blocks' = @{ Payload = @{ hook_event_name = 'Stop'; stop_hook_active = $false; last_assistant_message = 42 }; RawJson = $false }
    }
    foreach ($case in $stopMalformedPayloads.GetEnumerator()) {
        $invokeArgs = @{
            Name = 'finish-gate.ps1'
            Payload = $case.Value.Payload
            Cwd = $repo
        }
        if ($case.Value.RawJson) { $invokeArgs.RawJson = $true }
        $result = Invoke-Hook @invokeArgs
        Assert $case.Key (Test-StopBlock $result) (Detail $result)
    }

    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'PostToolUse'
        stop_hook_active = $false
        last_assistant_message = 'ordinary'
        cwd = $repo
    } -Cwd $repo
    Assert 'finish: explicitly unrelated hook event passes through' (Test-StopPassThrough $result) (Detail $result)

    $fixture = New-Fixture '002-smoke' $incompleteFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = 'Implementation is still in progress.'
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: ordinary Stop passes through without gating' (Test-StopPassThrough $result) (Detail $result)

    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: readiness marker with missing artifacts continues the turn' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'report\.md|finish\.md|study'
    ) (Detail $result)

    $fixture = New-Fixture '002-smoke' $readyFiles $null
    $finishNestedCwd = Join-Path $fixture 'specs/002-smoke'
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $finishNestedCwd
    } -Cwd $finishNestedCwd
    Assert 'finish: complete feature under nested cwd may stop' (Test-StopPassThrough $result) (Detail $result)

    $fixture = New-Fixture 'main' $readyFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: marker on unresolved main branch is blocked' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'feature|branch|resolve'
    ) (Detail $result)

    $mismatchFiles = $readyFiles.Clone()
    $mismatchFiles['specs/003-other/spec.md'] = "# Other`n"
    $fixture = New-Fixture '002-smoke' $mismatchFiles '{"feature_directory":"specs/003-other"}'
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: branch and feature.json disagreement is blocked' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'disagree|mismatch'
    ) (Detail $result)

    $fixture = New-Fixture '002-smoke' $readyFiles $null
    $outsideFeature = New-Fixture 'main' @{
        'report.md' = "# Outside report`n"
        'reviews/2026-09-04-finish.md' = "# Outside review`nStatus: Approved`n"
    } $null
    $env:SPECIFY_FEATURE_DIRECTORY = $outsideFeature
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Remove-Item Env:SPECIFY_FEATURE_DIRECTORY -ErrorAction SilentlyContinue
    Assert 'finish: environment candidate outside specs is blocked as containment failure' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'containment|immediate child'
    ) (Detail $result)

    $nestedFiles = $readyFiles.Clone()
    $nestedFiles['specs/002-smoke/nested/placeholder.md'] = "nested`n"
    $fixture = New-Fixture '002-smoke' $nestedFiles $null
    $env:SPECIFY_FEATURE_DIRECTORY = 'specs/002-smoke/nested'
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Remove-Item Env:SPECIFY_FEATURE_DIRECTORY -ErrorAction SilentlyContinue
    Assert 'finish: nested environment candidate is blocked as containment failure' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'containment|immediate child'
    ) (Detail $result)

    $invalidNameFiles = $readyFiles.Clone()
    $invalidNameFiles['specs/not_a_feature/placeholder.md'] = "invalid name`n"
    $fixture = New-Fixture '002-smoke' $invalidNameFiles $null
    $env:SPECIFY_FEATURE_DIRECTORY = 'specs/not_a_feature'
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Remove-Item Env:SPECIFY_FEATURE_DIRECTORY -ErrorAction SilentlyContinue
    Assert 'finish: invalid feature basename from environment is blocked' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'basename|NNN-slug|valid feature name'
    ) (Detail $result)

    $fixture = New-Fixture '002-smoke' $readyFiles ('{"feature_directory":"' + ($outsideFeature -replace '\\', '\\\\') + '"}')
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: feature.json candidate outside specs is blocked before source comparison' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'containment|immediate child'
    ) (Detail $result)

    $linkTarget = New-Fixture 'main' @{
        'report.md' = "# Linked report`n"
        'reviews/2026-09-04-finish.md' = "# Linked review`nStatus: Approved`n"
    } $null
    $linkedSourceFiles = @{
        'content/study/004-linked.mdx' = "---`ntitle: linked`ndraft: true`n---`n"
    }
    $fixture = New-Fixture '004-linked' $linkedSourceFiles $null
    $finishReparsePath = Join-Path $fixture 'specs/004-linked'
    New-Item -ItemType Directory -Path (Split-Path -Parent $finishReparsePath) -Force | Out-Null
    New-Item -ItemType $linkType -Path $finishReparsePath -Target $linkTarget | Out-Null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: linked branch feature directory is blocked' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'reparse|link'
    ) (Detail $result)
    Remove-Item -LiteralPath $finishReparsePath -Force -ErrorAction SilentlyContinue
    $finishReparsePath = $null

    $nonApprovedFiles = $readyFiles.Clone()
    $nonApprovedFiles['specs/002-smoke/reviews/2026-09-05-finish.md'] = "# Newest finish review`nStatus: Issues`n"
    $fixture = New-Fixture '002-smoke' $nonApprovedFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: newest finish review must be exactly Approved' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'Approved|finish\.md|review'
    ) (Detail $result)

    $datedStatusFiles = $readyFiles.Clone()
    $datedStatusFiles['specs/002-smoke/reviews/2026-09-05-finish.md'] = "# Dated approval`nStatus: Approved (2026-09-05)`n"
    $fixture = New-Fixture '002-smoke' $datedStatusFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: newest finish review requires exact bare Approved status' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'exact|Approved|status'
    ) (Detail $result)

    $invalidDateFiles = $readyFiles.Clone()
    $invalidDateFiles['specs/002-smoke/reviews/2026-02-30-finish.md'] = "# Impossible date`nStatus: Approved`n"
    $fixture = New-Fixture '002-smoke' $invalidDateFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: impossible calendar date in finish-review name is rejected' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'date|filename|review name'
    ) (Detail $result)

    $invalidReviewNameFiles = $readyFiles.Clone()
    $invalidReviewNameFiles['specs/002-smoke/reviews/zzzz-finish.md'] = "# Invalid review name`nStatus: Approved`n"
    $fixture = New-Fixture '002-smoke' $invalidReviewNameFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $false
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: invalid finish-review filename is rejected' (
        (Test-StopBlock $result) -and [string]$result.json.reason -match 'filename|review name|YYYY-MM-DD'
    ) (Detail $result)

    $fixture = New-Fixture '002-smoke' $incompleteFiles $null
    $result = Invoke-Hook -Name 'finish-gate.ps1' -Payload @{
        hook_event_name = 'Stop'
        stop_hook_active = $true
        last_assistant_message = $finishMarker
        cwd = $fixture
    } -Cwd $fixture
    Assert 'finish: stop_hook_active prevents recursive continuation' (Test-StopDoesNotRepeat $result) (Detail $result)
} finally {
    if ($featureEnvExisted) { $env:SPECIFY_FEATURE_DIRECTORY = $savedFeatureEnv }
    else { Remove-Item Env:SPECIFY_FEATURE_DIRECTORY -ErrorAction SilentlyContinue }
    if ($testerReparsePath -and (Test-Path -LiteralPath $testerReparsePath)) {
        Remove-Item -LiteralPath $testerReparsePath -Force -ErrorAction SilentlyContinue
    }
    if ($finishReparsePath -and (Test-Path -LiteralPath $finishReparsePath)) {
        Remove-Item -LiteralPath $finishReparsePath -Force -ErrorAction SilentlyContinue
    }
    Remove-Fixtures
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
