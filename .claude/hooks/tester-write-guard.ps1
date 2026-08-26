# tester-write-guard hook (PreToolUse Edit|Write|MultiEdit|NotebookEdit).
# Registered in .claude/agents/tester.md frontmatter, so it only runs inside the tester agent.
# The tester may only write test files; everything else is denied. Errors -> exit 0 (fail-open).

function Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } |
        ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ($data.tool_name -notin @('Edit', 'Write', 'MultiEdit', 'NotebookEdit')) { exit 0 }
    $path = [string]$data.tool_input.file_path
    if (-not $path) { $path = [string]$data.tool_input.notebook_path }
    if (-not $path) { exit 0 }
    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    $norm = $path -replace '\\', '/'
    $rootNorm = ($root -replace '\\', '/').TrimEnd('/')
    if ($norm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        $norm = $norm.Substring($rootNorm.Length).TrimStart('/')
    }
    $allowed = @('^tests/', '^e2e/', '(^|/)__tests__/', '\.test\.[^/]+$', '\.spec\.[^/]+$')
    foreach ($re in $allowed) { if ($norm -match $re) { exit 0 } }
    Deny "tester-write-guard: '$norm' is not a test path. The tester may only write under tests/, e2e/, __tests__/ or *.test.* / *.spec.* files. Report the finding instead of changing production code."
} catch {
    exit 0
}
