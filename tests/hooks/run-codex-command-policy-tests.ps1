# Codex destructive-command handler contract tests.
# Run: pwsh -NoProfile -ExecutionPolicy Bypass -File tests/hooks/run-codex-command-policy-tests.ps1
# The command strings below are data passed to the hook; this harness never executes them.
# A green result proves handler behavior, not that a particular Codex runtime dispatches PreToolUse.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$configPath = Join-Path $repo '.codex/hooks.json'
$hookPath = Join-Path $repo '.codex/hooks/command-policy.ps1'
$script:pass = 0
$script:fail = 0
$script:tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
$script:fixture = $null

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
    if ($result.missing) { return "missing hook: $hookPath" }
    $stdout = if ([string]::IsNullOrWhiteSpace($result.out)) { '<empty>' } else { $result.out }
    $stderr = if ([string]::IsNullOrWhiteSpace($result.err)) { '<empty>' } else { $result.err }
    $parse = if ($result.jsonError) { "; jsonError=$($result.jsonError)" } else { '' }
    return "stdout=$stdout; stderr=$stderr; code=$($result.code)$parse"
}

function New-Fixture {
    $dir = Join-Path $script:tempRoot ('codex-command-policy-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $dir = [IO.Path]::GetFullPath($dir)
    $script:fixture = $dir

    git -C $dir init -q -b main
    if ($LASTEXITCODE -ne 0) { throw "git init failed for command-policy fixture: $dir" }
    git -C $dir -c user.name=codex-command-policy-test -c user.email=codex-command-policy@test.invalid commit -q --allow-empty -m init
    if ($LASTEXITCODE -ne 0) { throw "git commit failed for command-policy fixture: $dir" }
    return $dir
}

function Remove-Fixture {
    if (-not $script:fixture) { return }
    try {
        $full = [IO.Path]::GetFullPath($script:fixture)
        $tempPrefix = $script:tempRoot + [IO.Path]::DirectorySeparatorChar
        $leaf = Split-Path -Leaf $full
        if (-not $full.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or $leaf -notlike 'codex-command-policy-*') {
            Write-Warning "Refusing to remove unexpected fixture path: $full"
            return
        }
        Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        $script:fixture = $null
    }
}

function Invoke-Policy {
    param(
        [Parameter(Mandatory)][object]$Payload,
        [Parameter(Mandatory)][string]$Cwd,
        [switch]$RawJson
    )

    if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
        return [pscustomobject]@{
            out = ''
            err = ''
            code = 127
            json = $null
            jsonError = 'hook missing'
            missing = $true
        }
    }

    $inputText = if ($RawJson) { [string]$Payload } else { $Payload | ConvertTo-Json -Compress -Depth 20 }
    $stderrPath = Join-Path $script:tempRoot ('codex-command-policy-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        Push-Location $Cwd
        try {
            $lines = @($inputText | pwsh -NoProfile -ExecutionPolicy Bypass -File $hookPath 2> $stderrPath)
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
        }
    } finally {
        Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Command([object]$command, [string]$cwd) {
    return Invoke-Policy -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'Bash'
        tool_input = @{ command = $command }
        cwd = $cwd
    } -Cwd $cwd
}

function Test-Deny([object]$result) {
    return $result.code -eq 0 -and
        -not $result.jsonError -and
        $result.json.hookSpecificOutput.hookEventName -ceq 'PreToolUse' -and
        $result.json.hookSpecificOutput.permissionDecision -ceq 'deny' -and
        -not [string]::IsNullOrWhiteSpace([string]$result.json.hookSpecificOutput.permissionDecisionReason)
}

function Test-NoOutput([object]$result) {
    return $result.code -eq 0 -and
        [string]::IsNullOrWhiteSpace($result.out) -and
        [string]::IsNullOrWhiteSpace($result.err)
}

try {
    # ---------- project-global synchronous wiring ----------
    $config = $null
    $configError = $null
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 20 }
        catch { $configError = $_.Exception.Message }
    } else { $configError = 'missing .codex/hooks.json' }
    Assert 'config: hooks.json is valid JSON' ($null -ne $config -and -not $configError) $configError

    $preToolGroups = if ($config -and $config.hooks) { @($config.hooks.PreToolUse) } else { @() }
    $policyBindings = @()
    foreach ($group in $preToolGroups) {
        if ([string]$group.matcher -cne '^Bash$') { continue }
        foreach ($handler in @($group.hooks)) {
            if ($handler.type -ceq 'command' -and
                [string]$handler.command -match 'command-policy\.ps1' -and
                [string]$handler.commandWindows -match 'command-policy\.ps1') {
                $policyBindings += $handler
            }
        }
    }
    Assert 'config: exact ^Bash$ matcher wires command-policy command and commandWindows' (
        $policyBindings.Count -eq 1
    ) "matching bindings=$($policyBindings.Count)"

    $syncBindings = @($policyBindings | Where-Object {
        $asyncProperty = $_.PSObject.Properties['async']
        $null -eq $asyncProperty -or [bool]$asyncProperty.Value -eq $false
    })
    Assert 'config: command policy hook is synchronous' (
        $policyBindings.Count -eq 1 -and $syncBindings.Count -eq 1
    ) 'command-policy handler is missing or async=true'

    $globalTesterBindings = @()
    foreach ($group in $preToolGroups) {
        foreach ($handler in @($group.hooks)) {
            if ([string]$handler.command -match 'tester-write-guard\.ps1' -or
                [string]$handler.commandWindows -match 'tester-write-guard\.ps1') {
                $globalTesterBindings += $handler
            }
        }
    }
    Assert 'config: tester guard is not registered globally' ($globalTesterBindings.Count -eq 0) "global bindings=$($globalTesterBindings.Count)"

    # ---------- direct hook behavior ----------
    $fixture = New-Fixture
    $utf16LE = [Text.UnicodeEncoding]::new($false, $false)
    $encodedPayload = [Convert]::ToBase64String($utf16LE.GetBytes('git reset --hard'))
    $encodedRoundTrip = $utf16LE.GetString([Convert]::FromBase64String($encodedPayload))
    Assert 'harness: EncodedCommand fixture is UTF-16LE and round-trips' (
        $encodedRoundTrip -ceq 'git reset --hard'
    ) "decoded=$encodedRoundTrip"
    $safeDeletionTarget = Join-Path $fixture 'literal-safe-fixture'
    $denyCases = [ordered]@{
        'deny: git reset hard' = 'git reset --hard'
        'deny: git global option before reset' = 'git -C . reset --hard'
        'deny: git push long force after refspec' = 'git push origin main --force'
        'deny: git push short force after refspec' = 'git push origin main -f'
        'deny: git push force-with-lease assignment' = 'git push origin main --force-with-lease=refs/heads/main:abc123'
        'deny: git clean combined flags' = 'git clean -fd'
        'deny: docker global option before prune' = 'docker --context default system prune -af'
        'deny: privileged rm even without recursion' = 'sudo rm one.tmp'
        'deny: rm split recursive flags' = 'rm -f -r build'
        'deny: absolute rm executable' = '/bin/rm -rf build'
        'deny: env wrapper before rm' = 'env rm -rf build'
        'deny: command wrapper before absolute rm' = 'command /bin/rm -r build'
        'deny: absolute git executable' = "& 'C:\Program Files\Git\cmd\git.exe' push origin main --force"
        'deny: git global flag before reset' = 'git --no-pager reset --hard'
        'deny: destructive command before compound separator' = 'git reset --hard; Write-Output never'
        'deny: destructive command after compound separator' = 'Write-Output ok; git push origin main --force'
        'deny: pwsh Command wrapper' = 'pwsh -NoProfile -Command "git reset --hard"'
        'deny: powershell Command wrapper' = 'powershell.exe -NoProfile -Command "git push origin main -f"'
        'deny: pwsh UTF-16LE EncodedCommand wrapper' = "pwsh -NoProfile -EncodedCommand $encodedPayload"
        'deny: cmd c wrapper' = 'cmd /c "git clean -fd"'
        'deny: bash lc wrapper' = "bash -lc 'rm -rf build'"
        'deny: sh c wrapper' = "sh -c 'git clean -fd'"
        'deny: pwsh abbreviated Command wrapper' = 'pwsh -co "git reset --hard"'
        'deny: pwsh abbreviated EncodedCommand wrapper' = "pwsh -ec $encodedPayload"
        'deny: powershell slash Command wrapper' = 'powershell.exe /c "git push origin main -f"'
        'deny: dynamic PowerShell executable invocation' = '$g=''git''; & $g reset --hard'
        'deny: POSIX leading environment assignment' = 'FOO=bar git reset --hard'
        'deny: bash eval wrapper is ambiguous' = 'bash -c ''eval "git reset --hard"'''
        'deny: git push forced plus refspec' = 'git push origin +main:main'
        'deny: recursive PowerShell deletion' = "Remove-Item -Recurse -Force '$safeDeletionTarget'"
        'deny: abbreviated recursive PowerShell deletion probe' = "Remove-Item -r -Force 'D:\code\joshuatech_ver2\nonexistent-safe-probe-target'"
        'deny: del alias recursive PowerShell deletion' = "del -r -Force '$safeDeletionTarget'"
        'deny: erase alias recursive PowerShell deletion' = "erase -r -Force '$safeDeletionTarget'"
        'deny: rd alias recursive PowerShell deletion' = "rd -r -Force '$safeDeletionTarget'"
        'deny: ri alias recursive PowerShell deletion' = "ri -r -Force '$safeDeletionTarget'"
        'deny: rm alias recursive PowerShell deletion' = "rm -r -Force '$safeDeletionTarget'"
        'deny: rmdir alias recursive PowerShell deletion' = "rmdir -r -Force '$safeDeletionTarget'"
    }
    foreach ($case in $denyCases.GetEnumerator()) {
        $result = Invoke-Command -Command $case.Value -Cwd $fixture
        Assert $case.Key (Test-Deny $result) (Detail $result)
    }

    $result = Invoke-Policy -Payload '{ definitely not json' -Cwd $fixture -RawJson
    Assert 'deny: malformed JSON fails closed' (Test-Deny $result) (Detail $result)

    $invalidRoutingPayloads = [ordered]@{
        'deny: non-string hook event name fails closed' = @{
            hook_event_name = 42
            tool_name = 'Bash'
            tool_input = @{ command = 'git reset --hard' }
            cwd = $fixture
        }
        'deny: empty hook event name fails closed' = @{
            hook_event_name = ''
            tool_name = 'Bash'
            tool_input = @{ command = 'git reset --hard' }
            cwd = $fixture
        }
        'deny: non-string tool name fails closed' = @{
            hook_event_name = 'PreToolUse'
            tool_name = 42
            tool_input = @{ command = 'git reset --hard' }
            cwd = $fixture
        }
        'deny: empty tool name fails closed' = @{
            hook_event_name = 'PreToolUse'
            tool_name = ''
            tool_input = @{ command = 'git reset --hard' }
            cwd = $fixture
        }
    }
    foreach ($case in $invalidRoutingPayloads.GetEnumerator()) {
        $result = Invoke-Policy -Payload $case.Value -Cwd $fixture
        Assert $case.Key (Test-Deny $result) (Detail $result)
    }

    $result = Invoke-Policy -Payload @{
        hook_event_name = 'PostToolUse'
        tool_name = 'Bash'
        tool_input = @{ command = 'git reset --hard' }
        cwd = $fixture
    } -Cwd $fixture
    Assert 'allow: explicitly unrelated string event is ignored' (Test-NoOutput $result) (Detail $result)

    $result = Invoke-Policy -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'Bash'
        tool_input = @{}
        cwd = $fixture
    } -Cwd $fixture
    Assert 'deny: Bash payload missing command fails closed' (Test-Deny $result) (Detail $result)

    $result = Invoke-Command -Command 42 -Cwd $fixture
    Assert 'deny: Bash payload with non-string command fails closed' (Test-Deny $result) (Detail $result)

    $result = Invoke-Policy -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'Bash'
        tool_input = @{ command = $null }
        cwd = $fixture
    } -Cwd $fixture
    Assert 'deny: Bash payload with null command fails closed' (Test-Deny $result) (Detail $result)

    $result = Invoke-Command -Command '   ' -Cwd $fixture
    Assert 'deny: Bash payload with empty command fails closed' (Test-Deny $result) (Detail $result)

    $safeCases = [ordered]@{
        'allow: git status' = 'git status'
        'allow: git reset soft' = 'git reset --soft'
        'allow: normal feature push' = 'git push origin feature'
        'allow: docker disk usage inspection' = 'docker system df'
        'allow: one explicit rm target' = 'rm one.tmp'
        'allow: destructive text inside PowerShell quotes' = "Write-Output 'git reset --hard'"
        'allow: destructive text inside nested PowerShell quotes' = 'pwsh -Command "Write-Output ''git reset --hard''"'
    }
    foreach ($case in $safeCases.GetEnumerator()) {
        $result = Invoke-Command -Command $case.Value -Cwd $fixture
        Assert $case.Key (Test-NoOutput $result) (Detail $result)
    }

    $result = Invoke-Policy -Payload @{
        hook_event_name = 'PreToolUse'
        tool_name = 'apply_patch'
        tool_input = @{ command = 'git reset --hard' }
        cwd = $fixture
    } -Cwd $fixture
    Assert 'allow: non-Bash tool is ignored' (Test-NoOutput $result) (Detail $result)
} finally {
    Remove-Fixture
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
