# finish-gate hook (PreToolUse, matcher: Skill).
# Denies superpowers:finishing-a-development-branch until the active feature has:
#   reviews/*-finish.md containing "Status: Approved", report.md, content/study/<feature>*.mdx
# Active feature resolution (spec D12): SPECIFY_FEATURE_DIRECTORY -> git branch NNN-slug -> .specify/feature.json.
# Unresolvable or inconsistent -> deny (fail-closed). Script errors -> exit 0 (fail-open).

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
    if ($data.tool_name -ne 'Skill') { exit 0 }
    $skill = [string]$data.tool_input.skill
    if ($skill -notmatch 'finishing-a-development-branch') { exit 0 }

    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    Set-Location $root
    $specsDir = Join-Path $root 'specs'
    $candidates = @{}

    if ($env:SPECIFY_FEATURE_DIRECTORY) {
        $p = $env:SPECIFY_FEATURE_DIRECTORY
        if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
        if (Test-Path $p) { $candidates['env'] = (Resolve-Path $p).Path }
    }
    $branch = (git branch --show-current 2>$null)
    if ($branch -and $branch -match '^\d{3,}-[a-z0-9-]+$') {
        $p = Join-Path $specsDir $branch
        if (Test-Path $p) { $candidates['branch'] = (Resolve-Path $p).Path }
    }
    $fj = Join-Path $root '.specify/feature.json'
    if (Test-Path $fj) {
        $j = Get-Content $fj -Raw | ConvertFrom-Json
        $p = [string]$j.feature_directory
        if ($p) {
            if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
            if (Test-Path $p) { $candidates['feature.json'] = (Resolve-Path $p).Path }
        }
    }

    if ($candidates.Count -eq 0) {
        Deny 'finish-gate: active feature could not be resolved (SPECIFY_FEATURE_DIRECTORY, branch NNN-slug, .specify/feature.json all missing). Check out the feature branch or set SPECIFY_FEATURE_DIRECTORY, then run /finish before finishing.'
    }
    $distinct = @($candidates.Values | Sort-Object -Unique)
    if ($distinct.Count -gt 1) {
        $desc = ($candidates.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        Deny "finish-gate: active feature sources disagree ($desc). Align the branch and .specify/feature.json before finishing."
    }
    $feature = $distinct[0]
    $name = Split-Path $feature -Leaf

    $missing = @()
    $finishReview = Get-ChildItem (Join-Path $feature 'reviews') -Filter '*-finish.md' -ErrorAction SilentlyContinue |
        Where-Object { (Get-Content $_.FullName -Raw) -match '(?m)^\s*(\*\*)?Status(\*\*)?:\s*Approved' }
    if (-not $finishReview) { $missing += "reviews/YYYY-MM-DD-finish.md with 'Status: Approved'" }
    if (-not (Test-Path (Join-Path $feature 'report.md'))) { $missing += 'report.md' }
    $study = Get-ChildItem (Join-Path $root 'content/study') -Filter "$name*.mdx" -ErrorAction SilentlyContinue
    if (-not $study) { $missing += "content/study/$name*.mdx" }

    if ($missing.Count -gt 0) {
        Deny ("finish-gate: feature '$name' is not ready to finish. Missing: " + ($missing -join ', ') + '. Run /finish first.')
    }
    exit 0
} catch {
    exit 0
}
