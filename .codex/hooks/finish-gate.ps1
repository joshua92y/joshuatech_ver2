# Codex Stop hook for finish readiness.
# It gates only messages carrying CODEX_FINISH_READY and never recursively continues a turn.

function PassThrough {
    @{ continue = $true } | ConvertTo-Json -Compress | Write-Output
    exit 0
}

function Block([string]$Reason) {
    [ordered]@{ decision = 'block'; reason = $Reason } |
        ConvertTo-Json -Compress | Write-Output
    exit 0
}

function Normalize-Path([string]$Path, [string]$Root) {
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path = Join-Path $Root $Path }
    return [IO.Path]::GetFullPath($Path).TrimEnd('\', '/')
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

function Resolve-FeatureCandidate([string]$Path, [string]$Root, [string]$SpecsDir, [string]$Source) {
    if ([string]::IsNullOrWhiteSpace($Path)) {
        Block "finish-gate: $Source does not name a feature directory."
    }

    $candidate = Normalize-Path $Path $Root
    if (-not (Test-Path -LiteralPath $candidate -PathType Container)) {
        Block "finish-gate: $Source points to a missing feature directory ($candidate)."
    }

    $specs = Normalize-Path $SpecsDir $Root
    $parent = Normalize-Path (Split-Path -Parent $candidate) $Root
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not [string]::Equals($parent, $specs, $comparison)) {
        Block "finish-gate: $Source candidate '$candidate' fails feature containment; it must be an immediate child of '$specs'."
    }

    $name = Split-Path -Leaf $candidate
    if ($name -cnotmatch '^\d{3,}-[a-z0-9-]+$') {
        Block "finish-gate: $Source candidate '$candidate' has an invalid feature basename; expected NNN-slug."
    }

    $reparseAncestor = Get-ReparseAncestor -Root $Root -Target $candidate
    if ($reparseAncestor) {
        Block "finish-gate: $Source candidate '$candidate' crosses existing reparse point or link '$reparseAncestor'."
    }
    return $candidate
}

# Malformed or ambiguous Stop payloads block. Explicitly unrelated hook events
# remain pass-through after the event field is validated.
try {
    [Console]::InputEncoding = [Text.Encoding]::UTF8
    [Console]::OutputEncoding = [Text.Encoding]::UTF8

    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { Block 'finish-gate: hook input is missing or empty.' }
    $data = $raw | ConvertFrom-Json
    if ($data -isnot [pscustomobject]) { Block 'finish-gate: hook input must be a JSON object.' }

    $eventProperty = $data.PSObject.Properties['hook_event_name']
    if ($null -eq $eventProperty -or $eventProperty.Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$eventProperty.Value)) {
        Block 'finish-gate: hook input must contain a non-empty string event name.'
    }
    if ([string]$eventProperty.Value -cne 'Stop') { PassThrough }

    $activeProperty = $data.PSObject.Properties['stop_hook_active']
    if ($null -eq $activeProperty -or $activeProperty.Value -isnot [bool]) {
        Block 'finish-gate: Stop input must contain a boolean stop_hook_active field.'
    }
    $messageProperty = $data.PSObject.Properties['last_assistant_message']
    if ($null -eq $messageProperty -or $messageProperty.Value -isnot [string]) {
        Block 'finish-gate: Stop input must contain a string last_assistant_message field.'
    }

    if ($activeProperty.Value -eq $true) { PassThrough }

    $lastMessage = [string]$messageProperty.Value
    if ($lastMessage -notmatch 'CODEX_FINISH_READY') { PassThrough }
} catch {
    Block "finish-gate: hook input is not valid JSON ($($_.Exception.Message))."
}

try {
    $cwd = if ($data.cwd) { [string]$data.cwd } else { (Get-Location).Path }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Block 'finish-gate: git is not on PATH, so the active feature cannot be resolved.'
    }

    $rootOutput = @(& git -C $cwd rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or $rootOutput.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$rootOutput[0])) {
        Block "finish-gate: the active feature cannot be resolved because '$cwd' is not inside a git repository."
    }
    $rootText = ([string]$rootOutput[0]).Trim()
    $root = Normalize-Path $rootText $rootText
    $specsDir = Normalize-Path (Join-Path $root 'specs') $root
    $candidates = [ordered]@{}

    if (Test-Path Env:SPECIFY_FEATURE_DIRECTORY) {
        $candidates['env'] = Resolve-FeatureCandidate ([string]$env:SPECIFY_FEATURE_DIRECTORY) $root $specsDir 'SPECIFY_FEATURE_DIRECTORY'
    }

    $branchOutput = @(& git -C $root branch --show-current 2>$null)
    if ($LASTEXITCODE -ne 0) { Block 'finish-gate: the current git branch could not be resolved.' }
    $branch = if ($branchOutput.Count -gt 0) { ([string]$branchOutput[0]).Trim() } else { '' }
    if ($branch -match '^\d{3,}-[a-z0-9-]+$') {
        $featureFromBranch = Normalize-Path (Join-Path $specsDir $branch) $root
        if (Test-Path -LiteralPath $featureFromBranch -PathType Container) {
            $candidates['branch'] = Resolve-FeatureCandidate $featureFromBranch $root $specsDir 'current branch'
        }
    }

    $featureJsonPath = Join-Path $root '.specify/feature.json'
    if (Test-Path -LiteralPath $featureJsonPath -PathType Leaf) {
        try {
            $featureJson = Get-Content -LiteralPath $featureJsonPath -Raw | ConvertFrom-Json
        } catch {
            Block "finish-gate: .specify/feature.json is not valid JSON ($($_.Exception.Message))."
        }
        if ($featureJson -isnot [pscustomobject]) {
            Block 'finish-gate: .specify/feature.json must contain a JSON object.'
        }
        $featureDirectoryProperty = $featureJson.PSObject.Properties['feature_directory']
        if ($null -eq $featureDirectoryProperty -or $featureDirectoryProperty.Value -isnot [string] -or
            [string]::IsNullOrWhiteSpace([string]$featureDirectoryProperty.Value)) {
            Block 'finish-gate: .specify/feature.json must contain a non-empty string feature_directory.'
        }
        $candidates['feature.json'] = Resolve-FeatureCandidate ([string]$featureDirectoryProperty.Value) $root $specsDir '.specify/feature.json'
    }

    if (-not $candidates.Contains('env') -and -not $candidates.Contains('branch')) {
        Block 'finish-gate: active feature resolution requires a feature branch (NNN-slug) or SPECIFY_FEATURE_DIRECTORY; feature.json alone is not authoritative.'
    }

    $comparison = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
    $distinct = [Collections.Generic.HashSet[string]]::new($comparison)
    foreach ($candidate in $candidates.Values) { [void]$distinct.Add([string]$candidate) }
    if ($distinct.Count -gt 1) {
        $details = ($candidates.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '; '
        Block "finish-gate: active feature sources disagree ($details). Align branch, environment, and feature.json."
    }

    $feature = if ($candidates.Contains('env')) { [string]$candidates['env'] } else { [string]$candidates['branch'] }
    $featureName = Split-Path $feature -Leaf
    $missing = @()

    $finishReviews = @(Get-ChildItem -LiteralPath (Join-Path $feature 'reviews') -File -Filter '*-finish.md' -ErrorAction SilentlyContinue)
    $validReviews = @()
    foreach ($review in $finishReviews) {
        $nameMatch = [regex]::Match($review.Name, '^(?<date>\d{4}-\d{2}-\d{2})-finish\.md$')
        if (-not $nameMatch.Success) {
            Block "finish-gate: invalid finish-review filename '$($review.Name)'; expected YYYY-MM-DD-finish.md."
        }

        [datetime]$reviewDate = [datetime]::MinValue
        $validDate = [datetime]::TryParseExact(
            $nameMatch.Groups['date'].Value,
            'yyyy-MM-dd',
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None,
            [ref]$reviewDate
        )
        if (-not $validDate) {
            Block "finish-gate: finish-review filename '$($review.Name)' contains an invalid calendar date."
        }
        $validReviews += [pscustomobject]@{ File = $review; Date = $reviewDate }
    }
    $latestReview = @($validReviews | Sort-Object Date -Descending | Select-Object -First 1)
    $approved = $false
    if ($latestReview.Count -gt 0) {
        $statusMatch = [regex]::Match(
            (Get-Content -LiteralPath $latestReview[0].File.FullName -Raw),
            '(?m)^\s*(\*\*)?Status(\*\*)?:(\*\*)?[ \t]*(?<value>[^\r\n]*?)[ \t]*\r?$'
        )
        $approved = $statusMatch.Success -and
            ($statusMatch.Groups['value'].Value -ceq 'Approved')
    }
    if (-not $approved) {
        $missing += "newest reviews/YYYY-MM-DD-finish.md with exact Status: Approved"
    }

    $report = Get-Item -LiteralPath (Join-Path $feature 'report.md') -ErrorAction SilentlyContinue
    if (-not $report -or $report.PSIsContainer -or $report.Length -eq 0) {
        $missing += 'report.md (non-empty)'
    }

    $study = Get-ChildItem -LiteralPath (Join-Path $root 'content/study') -File -Filter "$featureName*.mdx" -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -gt 0 }
    if (-not $study) {
        $missing += "content/study/$featureName*.mdx (non-empty)"
    }

    if ($missing.Count -gt 0) {
        Block ("finish-gate: feature '$featureName' is not ready. Missing: " + ($missing -join ', ') + '.')
    }

    PassThrough
} catch {
    Block "finish-gate: internal error while checking finish artifacts: $($_.Exception.Message)"
}
