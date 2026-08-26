# finish-gate hook (PreToolUse, matcher: Skill).
# Denies superpowers:finishing-a-development-branch until the active feature has:
#   - the NEWEST reviews/*-finish.md whose first "Status:" line is exactly "Approved",
#   - a non-empty report.md,
#   - a non-empty content/study/<feature>*.mdx
# Active feature resolution (spec D12): SPECIFY_FEATURE_DIRECTORY -> git branch NNN-slug -> .specify/feature.json.
# feature.json is a consistency check only; it never resolves a feature on its own.
# Phase 1 (input parsing) is fail-open: a hook bug must not block unrelated work.
# Phase 2 (the gate) is fail-closed: any error or ambiguity -> deny with a diagnostic reason.

function Deny([string]$reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } |
        ConvertTo-Json -Compress -Depth 5 | Write-Output
    exit 0
}

function Normalize([string]$p, [string]$root) {
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $root $p }
    return [System.IO.Path]::GetFullPath($p).TrimEnd('\', '/')
}

# ---- Phase 1: parse input (fail-open) ----
try {
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $data = $raw | ConvertFrom-Json
    if ([string]$data.tool_name -ne 'Skill') { exit 0 }
    $skill = [string]$data.tool_input.skill
    if (-not $skill) { $skill = [string]$data.tool_input.name }
    if ($skill -notmatch 'finishing-a-development-branch') { exit 0 }
} catch {
    exit 0
}

# ---- Phase 2: the gate (fail-closed) ----
try {
    $root = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    $root = [System.IO.Path]::GetFullPath($root).TrimEnd('\', '/')
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Deny 'finish-gate: git is not on PATH, so the active feature cannot be resolved.'
    }
    $specsDir = Join-Path $root 'specs'
    $candidates = [ordered]@{}

    if ($env:SPECIFY_FEATURE_DIRECTORY) {
        $p = Normalize $env:SPECIFY_FEATURE_DIRECTORY $root
        if (-not (Test-Path -LiteralPath $p -PathType Container)) {
            Deny "finish-gate: SPECIFY_FEATURE_DIRECTORY points to a missing directory ($p)."
        }
        $candidates['env'] = $p
    }
    $branch = (git -C $root branch --show-current 2>$null)
    if ($branch -and $branch -match '^\d{3,}-[a-z0-9-]+$') {
        $p = Normalize (Join-Path $specsDir $branch) $root
        if (Test-Path -LiteralPath $p -PathType Container) { $candidates['branch'] = $p }
    }
    $fj = Join-Path $root '.specify/feature.json'
    if (Test-Path -LiteralPath $fj -PathType Leaf) {
        try { $j = Get-Content -LiteralPath $fj -Raw | ConvertFrom-Json }
        catch { Deny "finish-gate: .specify/feature.json is not valid JSON ($($_.Exception.Message)). Fix or delete it." }
        $p = [string]$j.feature_directory
        if ($p) {
            $p = Normalize $p $root
            if (Test-Path -LiteralPath $p -PathType Container) { $candidates['feature.json'] = $p }
        }
    }

    if (-not $candidates.Contains('env') -and -not $candidates.Contains('branch')) {
        Deny 'finish-gate: active feature could not be resolved. Finishing must run on the feature branch (NNN-slug) or with SPECIFY_FEATURE_DIRECTORY set; .specify/feature.json alone is not authoritative. Run /finish before finishing.'
    }
    $distinct = @($candidates.Values | ForEach-Object { $_.ToLowerInvariant() } | Sort-Object -Unique)
    if ($distinct.Count -gt 1) {
        $desc = ($candidates.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        Deny "finish-gate: active feature sources disagree ($desc). Align the branch, SPECIFY_FEATURE_DIRECTORY, and .specify/feature.json before finishing."
    }
    $feature = if ($candidates.Contains('env')) { $candidates['env'] } else { $candidates['branch'] }
    $name = Split-Path $feature -Leaf

    $missing = @()
    $latest = Get-ChildItem -LiteralPath (Join-Path $feature 'reviews') -File -Filter '*-finish.md' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    $approved = $false
    if ($latest) {
        $m = [regex]::Match((Get-Content -LiteralPath $latest.FullName -Raw), '(?m)^\s*(\*\*)?Status(\*\*)?:(\*\*)?[ \t]*(?<v>[^\r\n]*?)[ \t]*\r?$')
        $approved = $m.Success -and ($m.Groups['v'].Value -cmatch '^Approved(\s*\(\d{4}-\d{2}-\d{2}\))?$')
    }
    if (-not $approved) { $missing += "newest reviews/YYYY-MM-DD-finish.md with 'Status: Approved'" }
    $report = Get-Item -LiteralPath (Join-Path $feature 'report.md') -ErrorAction SilentlyContinue
    if (-not $report -or $report.PSIsContainer -or $report.Length -eq 0) { $missing += 'report.md (non-empty)' }
    $study = Get-ChildItem -LiteralPath (Join-Path $root 'content/study') -File -Filter "$name*.mdx" -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 }
    if (-not $study) { $missing += "content/study/$name*.mdx (non-empty)" }

    if ($missing.Count -gt 0) {
        Deny ("finish-gate: feature '$name' is not ready to finish. Missing: " + ($missing -join ', ') + '. Run /finish first.')
    }
    exit 0
} catch {
    Deny "finish-gate: internal error while checking finish artifacts: $($_.Exception.Message)"
}
