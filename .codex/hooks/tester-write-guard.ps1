# Codex PreToolUse guard for apply_patch calls made by the tester agent.
# Every patch target must resolve to a test path inside the repository.

function Deny([string]$Reason) {
    [ordered]@{
        hookSpecificOutput = [ordered]@{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

function Get-ReparseAncestor([string]$Root, [string]$Target) {
    $relative = [IO.Path]::GetRelativePath($Root, $Target)
    $current = $Root
    foreach ($part in @($relative -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($part) -or $part -eq '.') { continue }
        $current = Join-Path $current $part
        if (-not (Test-Path -LiteralPath $current)) { break }

        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            return $current
        }
    }
    return $null
}

# Malformed or ambiguous protected payloads fail closed. Explicitly unrelated
# events and tools remain no-ops after their routing fields are validated.
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8

    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Deny 'tester-write-guard: hook input is missing or empty.'
    }
    $data = $raw | ConvertFrom-Json
    if ($data -isnot [pscustomobject]) {
        Deny 'tester-write-guard: hook input must be a JSON object.'
    }

    $eventProperty = $data.PSObject.Properties['hook_event_name']
    if ($null -eq $eventProperty -or $eventProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$eventProperty.Value)) {
        Deny 'tester-write-guard: hook input must contain a non-empty string event name.'
    }
    if ([string]$eventProperty.Value -cne 'PreToolUse') { exit 0 }

    $toolProperty = $data.PSObject.Properties['tool_name']
    if ($null -eq $toolProperty -or $toolProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$toolProperty.Value)) {
        Deny 'tester-write-guard: PreToolUse input must contain a non-empty string tool name.'
    }
    if ([string]$toolProperty.Value -cne 'apply_patch') { exit 0 }

    $toolInputProperty = $data.PSObject.Properties['tool_input']
    if ($null -eq $toolInputProperty -or $toolInputProperty.Value -isnot [pscustomobject]) {
        Deny 'tester-write-guard: apply_patch input must contain a JSON object tool_input.'
    }
    $commandProperty = $toolInputProperty.Value.PSObject.Properties['command']
    if ($null -eq $commandProperty -or $commandProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$commandProperty.Value)) {
        Deny 'tester-write-guard: apply_patch input must contain a non-empty string command.'
    }
    $patchText = [string]$commandProperty.Value
} catch {
    Deny "tester-write-guard: hook input is not valid JSON ($($_.Exception.Message))."
}

# Once an apply_patch call is recognized, uncertainty fails closed.
try {
    $cwd = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Deny 'tester-write-guard: git is not on PATH, so the repository boundary cannot be resolved.'
    }

    $gitOutput = @(& git -C $cwd rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $gitOutput.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$gitOutput[0])) {
        Deny "tester-write-guard: '$cwd' is not inside a resolvable git repository."
    }
    $root = [IO.Path]::GetFullPath(([string]$gitOutput[0]).Trim()).TrimEnd('\', '/')

    $targets = @()
    $filePattern = '(?m)^\*\*\* (?:Add|Update|Delete) File:[ \t]*(?<path>.+?)[ \t]*\r?$'
    $movePattern = '(?m)^\*\*\* Move to:[ \t]*(?<path>.+?)[ \t]*\r?$'
    foreach ($match in [regex]::Matches($patchText, $filePattern)) {
        $targets += $match.Groups['path'].Value
    }
    foreach ($match in [regex]::Matches($patchText, $movePattern)) {
        $targets += $match.Groups['path'].Value
    }
    if ($targets.Count -eq 0) {
        Deny 'tester-write-guard: apply_patch contained no recognized file targets; refusing an unclassifiable write.'
    }

    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $rootPrefix = $root + [IO.Path]::DirectorySeparatorChar
    $allowedPatterns = @('^tests/', '^e2e/', '(^|/)__tests__/', '\.test\.[^/]+$', '\.spec\.[^/]+$')

    foreach ($rawTarget in $targets) {
        $target = ([string]$rawTarget).Trim()
        if ([string]::IsNullOrWhiteSpace($target)) {
            Deny 'tester-write-guard: apply_patch contained an empty file target.'
        }

        $full = if ([IO.Path]::IsPathRooted($target)) {
            [IO.Path]::GetFullPath($target)
        } else {
            [IO.Path]::GetFullPath((Join-Path $root $target))
        }

        if (-not $full.StartsWith($rootPrefix, $comparison)) {
            Deny "tester-write-guard: '$target' resolves outside the repository ($root)."
        }

        $reparseAncestor = Get-ReparseAncestor -Root $root -Target $full
        if ($reparseAncestor) {
            Deny "tester-write-guard: '$target' crosses existing reparse point or link '$reparseAncestor'; outside writes cannot be excluded."
        }

        $relative = ([IO.Path]::GetRelativePath($root, $full) -replace '\\', '/')
        $allowed = $false
        foreach ($pattern in $allowedPatterns) {
            if ($relative -match $pattern) {
                $allowed = $true
                break
            }
        }
        if (-not $allowed) {
            Deny "tester-write-guard: '$relative' is not a test path. The tester may write only under tests/, e2e/, __tests__/, or to *.test.* / *.spec.* files."
        }
    }

    exit 0
} catch {
    Deny "tester-write-guard: internal error while validating patch targets: $($_.Exception.Message)"
}
