# Codex + Claude Spec Kit integration contract.
# Run: pwsh -NoProfile -File tests/agents/codex-integration.tests.ps1
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo

$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$condition, [string]$detail) {
    if ($condition) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function Same-Set([object[]]$left, [object[]]$right) {
    $a = @($left | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    $b = @($right | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive)
    return $a.Count -eq $b.Count -and (($a -join "`n") -ceq ($b -join "`n"))
}

function Read-Json([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json }
    catch { return $null }
}

$state = Read-Json '.specify/integration.json'
Assert 'state-1: integration.json parses' ($null -ne $state) 'missing or invalid JSON'
Assert 'state-2: Claude remains the default integration' ($state -and $state.integration -ceq 'claude') "actual=$($state.integration)"
Assert 'state-3: exactly Claude and Codex are installed' ($state -and (Same-Set @($state.installed_integrations) @('claude', 'codex'))) (($state.installed_integrations -join ', '))
Assert 'state-4: both integrations use PowerShell scripts' (
    $state -and $state.integration_settings.claude.script -ceq 'ps' -and $state.integration_settings.codex.script -ceq 'ps'
) 'expected integration_settings.{claude,codex}.script = ps'

$expectedSkills = @(
    'speckit-agent-context-update',
    'speckit-analyze',
    'speckit-archive-run',
    'speckit-checklist',
    'speckit-clarify',
    'speckit-constitution',
    'speckit-converge',
    'speckit-git-commit',
    'speckit-git-feature',
    'speckit-git-initialize',
    'speckit-git-remote',
    'speckit-git-validate',
    'speckit-implement',
    'speckit-plan',
    'speckit-specify',
    'speckit-tasks',
    'speckit-taskstoissues'
)
$actualSkills = if (Test-Path -LiteralPath '.agents/skills' -PathType Container) {
    @(Get-ChildItem -LiteralPath '.agents/skills' -Directory | Where-Object Name -like 'speckit-*' | ForEach-Object Name)
} else { @() }
Assert 'skills-1: Codex has the expected 17 Spec Kit skills' (Same-Set $actualSkills $expectedSkills) "actual=$($actualSkills -join ', ')"

$skillErrors = @()
foreach ($name in $expectedSkills) {
    $path = ".agents/skills/$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $skillErrors += "missing:$path"; continue }
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    if ($bytes -contains 13) { $skillErrors += "CR:$path" }
    if ($text -notmatch "(?ms)\A---\n(?<frontmatter>.*?)\n---") { $skillErrors += "frontmatter:$path"; continue }
    $frontmatter = $Matches.frontmatter
    $namePattern = '(?m)^name:\s*["'']?' + [regex]::Escape($name) + '["'']?\s*$'
    if ($frontmatter -notmatch $namePattern) { $skillErrors += "name:$path" }
    if ($frontmatter -notmatch '(?m)^description:\s*\S') { $skillErrors += "description:$path" }
}
Assert 'skills-2: every Codex skill has matching frontmatter and LF endings' ($skillErrors.Count -eq 0) ($skillErrors -join ', ')

$codexManifest = Read-Json '.specify/integrations/codex.manifest.json'
Assert 'manifest-1: Codex manifest parses' ($null -ne $codexManifest) 'missing or invalid JSON'
$manifestErrors = @()
$manifestFiles = if ($codexManifest) { @($codexManifest.files.PSObject.Properties) } else { @() }
foreach ($entry in $manifestFiles) {
    $path = [string]$entry.Name
    if ($path -notmatch '^\.agents/skills/speckit-[a-z0-9-]+/SKILL\.md$') { $manifestErrors += "unsafe:$path"; continue }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $manifestErrors += "missing:$path"; continue }
    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne [string]$entry.Value) { $manifestErrors += "hash:$path" }
}
Assert 'manifest-2: 10 core Codex files match the managed manifest' ($manifestFiles.Count -eq 10 -and $manifestErrors.Count -eq 0) "count=$($manifestFiles.Count); $($manifestErrors -join ', ')"

$claudeManifest = Read-Json '.specify/integrations/claude.manifest.json'
$claudeErrors = @()
$claudeFiles = if ($claudeManifest) { @($claudeManifest.files.PSObject.Properties) } else { @() }
foreach ($entry in $claudeFiles) {
    $path = [string]$entry.Name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $claudeErrors += "missing:$path"; continue }
    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -cne [string]$entry.Value) { $claudeErrors += "hash:$path" }
}
Assert 'manifest-3: Claude managed files remain intact' ($claudeFiles.Count -ge 1 -and $claudeErrors.Count -eq 0) ($claudeErrors -join ', ')

$registry = Read-Json '.specify/extensions/.registry'
$expectedExtensions = @{
    git = @('speckit.git.commit', 'speckit.git.feature', 'speckit.git.initialize', 'speckit.git.remote', 'speckit.git.validate')
    'agent-context' = @('speckit.agent-context.update')
    archive = @('speckit.archive.run')
}
$registryErrors = @()
foreach ($extension in $expectedExtensions.Keys) {
    $entry = if ($registry) { $registry.extensions.$extension } else { $null }
    if (-not $entry) { $registryErrors += "missing:$extension"; continue }
    foreach ($agent in @('claude', 'codex')) {
        if (-not (Same-Set @($entry.registered_commands.$agent) $expectedExtensions[$extension])) {
            $registryErrors += "$extension/$agent"
        }
    }
}
Assert 'extensions-1: enabled extensions are registered identically for Claude and Codex' ($registryErrors.Count -eq 0) ($registryErrors -join ', ')

$lfErrors = @()
foreach ($path in @(
    '.specify/init-options.json',
    '.specify/integration.json',
    '.specify/integrations/codex.manifest.json',
    '.specify/integrations/speckit.manifest.json',
    '.specify/extensions/.registry'
)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $lfErrors += "missing:$path"; continue }
    if ([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path)) -contains 13) { $lfErrors += "CR:$path" }
}
Assert 'format-1: integration metadata uses LF endings' ($lfErrors.Count -eq 0) ($lfErrors -join ', ')

$agentsText = if (Test-Path -LiteralPath 'AGENTS.md') { Get-Content -LiteralPath 'AGENTS.md' -Raw } else { '' }
$mirrorText = if (Test-Path -LiteralPath 'docs/kr/AGENTS_kr.md') { Get-Content -LiteralPath 'docs/kr/AGENTS_kr.md' -Raw } else { '' }
Assert 'docs-1: canonical and Korean agent guides describe both integrations' (
    $agentsText -match '`claude`' -and $agentsText -match '`codex`' -and $agentsText -match '\.agents/skills/' -and
    $mirrorText -match '`claude`' -and $mirrorText -match '`codex`' -and $mirrorText -match '\.agents/skills/'
) 'AGENTS.md or its Korean mirror is stale'

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
