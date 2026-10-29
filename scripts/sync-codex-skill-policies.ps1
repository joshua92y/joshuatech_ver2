# Restores project-owned Codex invocation policies after Spec Kit regeneration.
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Root = (Join-Path $PSScriptRoot '..')
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path -LiteralPath $Root).Path
$skillsRoot = Join-Path $repoRoot '.agents/skills'

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    throw "Codex skills directory not found: $skillsRoot"
}

$skillDirs = @(
    Get-ChildItem -LiteralPath $skillsRoot -Directory -Filter 'speckit-*' |
        Where-Object {
            Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') -PathType Leaf
        } |
        Sort-Object Name
)

if ($skillDirs.Count -eq 0) {
    throw "No Codex Spec Kit skills found under: $skillsRoot"
}

$utf8NoBom = [Text.UTF8Encoding]::new($false)
$policyText = "policy:`n  allow_implicit_invocation: false`n"
$policyBytes = $utf8NoBom.GetBytes($policyText)
$expectedBase64 = [Convert]::ToBase64String($policyBytes)

$created = 0
$updated = 0
$unchanged = 0

foreach ($skillDir in $skillDirs) {
    $agentsDir = Join-Path $skillDir.FullName 'agents'
    $policyPath = Join-Path $agentsDir 'openai.yaml'

    if (Test-Path -LiteralPath $policyPath -PathType Leaf) {
        $currentBytes = [IO.File]::ReadAllBytes($policyPath)
        if ([Convert]::ToBase64String($currentBytes) -ceq $expectedBase64) {
            $unchanged++
            continue
        }
        $updated++
    } else {
        if (Test-Path -LiteralPath $policyPath) {
            throw "Policy path exists but is not a file: $policyPath"
        }
        $created++
    }

    [void](New-Item -ItemType Directory -Path $agentsDir -Force)
    [IO.File]::WriteAllText($policyPath, $policyText, $utf8NoBom)
}

Write-Output (
    'Codex skill policies: {0} synced (created={1}, updated={2}, unchanged={3})' -f
        $skillDirs.Count, $created, $updated, $unchanged
)
