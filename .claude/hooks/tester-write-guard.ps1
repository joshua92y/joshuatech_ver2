# tester-write-guard hook (PreToolUse Edit|Write|MultiEdit|NotebookEdit).
# Registered in .claude/agents/tester.md frontmatter (spec D10 / FR-016), so it only runs inside the tester agent.
# The tester may only write test files INSIDE the repository; everything else is denied.
# Phase 1 (input parsing) is fail-open: a hook bug must not block unrelated work.
# Phase 2 (path decision) is fail-closed: any error -> deny with a diagnostic reason.

function Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } |
        ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

# ---- Phase 1: parse input (fail-open) ----
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ([string]$data.tool_name -notin @('Edit', 'Write', 'MultiEdit', 'NotebookEdit')) { exit 0 }
    $path = [string]$data.tool_input.file_path
    if (-not $path) { $path = [string]$data.tool_input.notebook_path }
    if (-not $path) { exit 0 }
} catch {
    exit 0
}

# ---- Phase 2: decide (fail-closed) ----
try {
    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    $root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    $full = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $root $path }
    $full = [System.IO.Path]::GetFullPath($full)
    $rootSlash = $root -replace '\\', '/'
    $fullSlash = $full -replace '\\', '/'
    if (-not $fullSlash.StartsWith($rootSlash + '/', [System.StringComparison]::OrdinalIgnoreCase)) {
        Deny "tester-write-guard: '$fullSlash' is outside the repository ($rootSlash). The tester may only write test files inside the repository."
    }
    $rel = $fullSlash.Substring($rootSlash.Length + 1)
    $allowed = @('^tests/', '^e2e/', '(^|/)__tests__/', '\.test\.[^/]+$', '\.spec\.[^/]+$')
    foreach ($re in $allowed) { if ($rel -match $re) { exit 0 } }
    Deny "tester-write-guard: '$rel' is not a test path. The tester may only write under tests/, e2e/, __tests__/ or *.test.* / *.spec.* files. Report the finding instead of changing production code."
} catch {
    Deny "tester-write-guard: internal error while checking the path: $($_.Exception.Message)"
}
