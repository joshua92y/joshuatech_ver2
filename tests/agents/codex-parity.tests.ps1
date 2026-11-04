# Codex project-layer parity contract.
# Run: pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
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
    return $a.Count -eq $b.Count -and [string]::Equals(($a -join "`n"), ($b -join "`n"), [StringComparison]::Ordinal)
}

function Read-Text([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path))
    return [Text.UTF8Encoding]::new($false, $true).GetString($bytes)
}

$speckitSkills = @(
    'speckit-agent-context-update', 'speckit-analyze', 'speckit-archive-run',
    'speckit-checklist', 'speckit-clarify', 'speckit-constitution',
    'speckit-converge', 'speckit-git-commit', 'speckit-git-feature',
    'speckit-git-initialize', 'speckit-git-remote', 'speckit-git-validate',
    'speckit-implement', 'speckit-plan', 'speckit-specify', 'speckit-tasks',
    'speckit-taskstoissues'
)

# ---------- Explicit-only Spec Kit skills ----------
$policyErrors = @()
foreach ($name in $speckitSkills) {
    $path = ".agents/skills/$name/agents/openai.yaml"
    $text = Read-Text $path
    if ($null -eq $text) { $policyErrors += "missing:$path"; continue }
    if ([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $path)) -contains 13) { $policyErrors += "CR:$path" }
    $hits = [regex]::Matches($text, '(?m)^\s*allow_implicit_invocation:\s*false\s*$')
    if ($hits.Count -ne 1 -or $text -notmatch '(?m)^policy:\s*$') { $policyErrors += "policy:$path" }
    if ($text -match '(?m)^\s*allow_implicit_invocation:\s*true\s*$') { $policyErrors += "implicit-true:$path" }
}
Assert 'policy-1: all 17 Spec Kit skills are explicit-only with LF sidecars' ($policyErrors.Count -eq 0) ($policyErrors -join ', ')

# ---------- Managed placeholder compatibility ----------
$expectedArgumentCounts = [ordered]@{
    'speckit-analyze' = 2
    'speckit-archive-run' = 6
    'speckit-checklist' = 3
    'speckit-clarify' = 2
    'speckit-constitution' = 1
    'speckit-converge' = 1
    'speckit-git-feature' = 1
    'speckit-implement' = 1
    'speckit-plan' = 1
    'speckit-specify' = 2
    'speckit-tasks' = 2
    'speckit-taskstoissues' = 1
}
$actualArgumentCounts = [ordered]@{}
foreach ($name in $speckitSkills) {
    $text = Read-Text ".agents/skills/$name/SKILL.md"
    if ($null -eq $text) { continue }
    $count = [regex]::Matches($text, [regex]::Escape('$ARGUMENTS')).Count
    if ($count -gt 0) { $actualArgumentCounts[$name] = $count }
}
$argInventoryOk = (Same-Set @($actualArgumentCounts.Keys) @($expectedArgumentCounts.Keys))
foreach ($name in $expectedArgumentCounts.Keys) {
    if ($actualArgumentCounts[$name] -ne $expectedArgumentCounts[$name]) { $argInventoryOk = $false }
}
Assert 'args-1: managed literal $ARGUMENTS inventory is known (12 skills, 23 occurrences)' (
    $argInventoryOk -and (($actualArgumentCounts.Values | Measure-Object -Sum).Sum -eq 23)
) (($actualArgumentCounts.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')

$agents = Read-Text 'AGENTS.md'
$mirror = Read-Text 'docs/kr/AGENTS_kr.md'
$argsRuleOk = $agents -and
    $agents.Contains('`$ARGUMENTS`') -and $agents -match 'triggering user message' -and
    $agents -match 'exact remainder' -and $agents -match 'quotes and flags' -and
    $agents -match 'literal token is never input' -and
    $agents -match 'Nested Spec Kit hooks' -and $agents -match 'parent workflow'
$argsMirrorOk = $mirror -and $mirror.Contains('`$ARGUMENTS`') -and $mirror -match '사용자 메시지' -and $mirror -match '따옴표' -and $mirror -match '상위 워크플로'
Assert 'args-2: canonical and Korean guides define Codex argument binding' ($argsRuleOk -and $argsMirrorOk) 'missing explicit argument compatibility contract'

$registry = if (Test-Path -LiteralPath '.specify/extensions/.registry') {
    Get-Content -LiteralPath '.specify/extensions/.registry' -Raw | ConvertFrom-Json
} else { $null }
$commandErrors = @()
if ($registry) {
    foreach ($ext in $registry.extensions.PSObject.Properties.Value) {
        foreach ($id in @($ext.registered_commands.codex)) {
            $skill = '$' + ([string]$id).Replace('.', '-')
            $dir = '.agents/skills/' + $skill.Substring(1)
            if (-not (Test-Path -LiteralPath $dir -PathType Container)) { $commandErrors += "$id->$skill" }
        }
    }
} else { $commandErrors += 'missing-registry' }
$mapRuleOk = $agents -and $agents.Contains('`/{command}`') -and $agents.Contains('`/skill:`') -and $agents.Contains('`$speckit-<name>`')
Assert 'command-map-1: extension IDs map to existing $speckit-* skills and legacy forms are documented' ($commandErrors.Count -eq 0 -and $mapRuleOk) ($commandErrors -join ', ')

$extensionsConfig = Read-Text '.specify/extensions.yml'
$beforeSpecifyOk = $extensionsConfig -and $extensionsConfig -match '(?ms)^  before_specify:\r?\n(?:(?!^  \w).)*?^\s+command:\s*speckit\.git\.feature\s*$'
$nestedRuleOk = $agents -and $agents -match 'explicit child arguments win' -and $agents -match '\$speckit-specify' -and $agents -match '\$speckit-git-feature'
Assert 'args-3: before-specify git feature hook inherits bound parent arguments' (
    $beforeSpecifyOk -and $nestedRuleOk
) 'missing mandatory before_specify mapping or nested argument rule'

# ---------- Project-owned Codex skills ----------
$projectSkills = [ordered]@{
    'approval-review' = @('k8s-security.md', 'operability.md', 'security.md', 'spec-consistency.md', 'tenant-data.md', 'trends.md')
    'finish' = @('decisions.md', 'e2e-evidence.md', 'report-vs-diff.md', 'study-contract.md')
}
$projectErrors = @()
foreach ($name in $projectSkills.Keys) {
    $skillPath = ".agents/skills/$name/SKILL.md"
    $text = Read-Text $skillPath
    if ($null -eq $text) { $projectErrors += "missing:$skillPath"; continue }
    if ($text -notmatch "(?m)^name:\s*$([regex]::Escape($name))\s*$") { $projectErrors += "name:$skillPath" }
    if ($text -notmatch '(?m)^description:\s*\S') { $projectErrors += "description:$skillPath" }
    foreach ($bad in @('AskUserQuestion', 'general-purpose', '${CLAUDE_PROJECT_DIR}', 'superpowers:')) {
        if ($text.Contains($bad)) { $projectErrors += "claude-token:${name}:$bad" }
    }
    if ($text -match '(?<![\w$.-])/speckit-' -or $text -match '(?<![\w$.-])/finish(?:\s|`|$)') { $projectErrors += "slash-command:$name" }
    $actualBoundaries = if (Test-Path -LiteralPath ".agents/skills/$name/boundaries" -PathType Container) {
        @(Get-ChildItem -LiteralPath ".agents/skills/$name/boundaries" -File -Filter '*.md' | ForEach-Object Name)
    } else { @() }
    if (-not (Same-Set $actualBoundaries $projectSkills[$name])) { $projectErrors += "boundaries:$name=$($actualBoundaries -join ',')" }
    foreach ($boundary in $projectSkills[$name]) {
        $codexPath = ".agents/skills/$name/boundaries/$boundary"
        $claudePath = ".claude/skills/$name/boundaries/$boundary"
        $codexText = Read-Text $codexPath
        $claudeText = Read-Text $claudePath
        if (-not $codexText -or -not [string]::Equals($codexText, $claudeText, [StringComparison]::Ordinal)) {
            $projectErrors += "boundary-parity:$name/$boundary"
        }
    }
}
Assert 'project-skills-1: approval-review and finish are Codex-native with matching rubrics' ($projectErrors.Count -eq 0) ($projectErrors -join ', ')

$approval = Read-Text '.agents/skills/approval-review/SKILL.md'
$finish = Read-Text '.agents/skills/finish/SKILL.md'
$workflowTokensOk = $approval -and $approval.Contains('spawn_agent') -and $approval.Contains('wait_agent') -and
    $approval.Contains('$speckit-analyze') -and $approval.Contains('.agents/skills/speckit-analyze/SKILL.md') -and
    $approval.Contains('request_user_input') -and
    $finish -and $finish.Contains('spawn_agent') -and $finish.Contains('wait_agent') -and
    $finish.Contains('$speckit-converge') -and $finish.Contains('.agents/skills/speckit-converge/SKILL.md') -and
    $finish.Contains('$speckit-archive-run') -and
    $finish.Contains('CODEX_FINISH_READY')
Assert 'project-skills-2: Codex workflows use native tools, concrete nested skill paths, and finish marker' $workflowTokensOk 'missing Codex-native workflow token or nested skill path'

# ---------- Project custom agents ----------
$expectedAgents = @('api-builder.toml', 'infra-builder.toml', 'tester.toml', 'web-builder.toml')
$actualAgents = if (Test-Path -LiteralPath '.codex/agents' -PathType Container) {
    @(Get-ChildItem -LiteralPath '.codex/agents' -File -Filter '*.toml' | ForEach-Object Name)
} else { @() }
$agentErrors = @()
if (-not (Same-Set $actualAgents $expectedAgents)) { $agentErrors += "set=$($actualAgents -join ',')" }
foreach ($file in $expectedAgents) {
    $path = ".codex/agents/$file"
    $text = Read-Text $path
    if ($null -eq $text) { $agentErrors += "missing:$path"; continue }
    foreach ($key in @('name', 'description', 'developer_instructions')) {
        if ($text -notmatch "(?m)^$key\s*=\s*") { $agentErrors += "${key}:$path" }
    }
    if ($text -match '(?m)^model(?:_reasoning_effort)?\s*=') { $agentErrors += "model-pin:$path" }
    if ($text -notmatch 'approved.*spec\.md|approved `spec\.md`') { $agentErrors += "approved-artifacts:$path" }
}
$testerAgent = Read-Text '.codex/agents/tester.toml'
if (-not ($testerAgent -and $testerAgent -match '(?m)^sandbox_mode\s*=\s*"workspace-write"' -and
    $testerAgent -match '(?m)^\[\[hooks\.PreToolUse\]\]' -and $testerAgent -match 'apply_patch' -and
    $testerAgent -match 'tester-write-guard\.ps1')) { $agentErrors += 'tester-hook' }
Assert 'agents-1: four unpinned Codex agents preserve scopes and tester hook' ($agentErrors.Count -eq 0) ($agentErrors -join ', ')

# ---------- Path router and command policy ----------
$ruleDocs = @('content.md', 'django-pod.md', 'docs.md', 'events.md', 'fastapi-pod.md', 'infra.md', 'specs.md', 'web.md')
$routeErrors = @($ruleDocs | Where-Object { -not $agents.Contains(".claude/rules/$_") })
Assert 'router-1: AGENTS routes every Claude path rule for Codex' ($routeErrors.Count -eq 0 -and $agents -match 'before (reading or )?editing') ($routeErrors -join ', ')

$rulesPath = '.codex/rules/repository.rules'
$rulesText = Read-Text $rulesPath
$rulesOk = $rulesText -and $rulesText -match 'prefix_rule\(' -and $rulesText -match 'decision\s*=\s*"forbidden"' -and
    $rulesText -match 'git.*reset' -and $rulesText -match 'git.*push' -and $rulesText -match 'git.*clean' -and
    $rulesText -match 'docker.*prune' -and $rulesText -match 'rm.*-rf' -and
    $rulesText -match 'pattern\s*=\s*\["sudo",\s*"rm"\]'
Assert 'rules-1: Codex rules provide direct-prefix destructive-command defense' $rulesOk 'missing or incomplete .codex/rules/repository.rules'

$hooksConfig = if (Test-Path -LiteralPath '.codex/hooks.json') { Get-Content -LiteralPath '.codex/hooks.json' -Raw | ConvertFrom-Json -Depth 20 } else { $null }
$commandPolicy = Read-Text '.codex/hooks/command-policy.ps1'
$commandHookCount = 0
if ($hooksConfig -and $hooksConfig.hooks) {
    foreach ($group in @($hooksConfig.hooks.PreToolUse)) {
        if ([string]$group.matcher -cne '^Bash$') { continue }
        foreach ($handler in @($group.hooks)) {
            if ($handler.type -ceq 'command' -and [string]$handler.command -match 'command-policy\.ps1' -and
                [string]$handler.commandWindows -match 'command-policy\.ps1') { $commandHookCount++ }
        }
    }
}
$windowsLimitDocumented = $agents -match 'Windows limitation verified' -and $agents -match 'did not dispatch `PreToolUse`' -and
    $mirror -match 'Windows 제한' -and $mirror -match '디스패치하지 않았다'
$commandHookOk = $commandHookCount -eq 1 -and $commandPolicy -and
    $commandPolicy -match 'permissionDecision\s*=\s*''deny''' -and
    $agents -match 'direct-argv defense in depth' -and $mirror -match '직접 argv' -and $windowsLimitDocumented
Assert 'command-hook-1: handler is wired and Windows dispatch limitation is explicit' $commandHookOk "matching hooks=$commandHookCount; windowsLimit=$windowsLimitDocumented"

# ---------- Claude remains semantically intact ----------
$settings = if (Test-Path -LiteralPath '.claude/settings.json') { Get-Content -LiteralPath '.claude/settings.json' -Raw | ConvertFrom-Json } else { $null }
$overrideNames = if ($settings -and $settings.skillOverrides) { @($settings.skillOverrides.PSObject.Properties.Name) } else { @() }
$claudeOk = $settings -and @($settings.permissions.deny).Count -eq 27 -and
    (Same-Set $overrideNames $speckitSkills) -and
    @($overrideNames | Where-Object { $settings.skillOverrides.$_ -cne 'name-only' }).Count -eq 0 -and
    @($settings.hooks.UserPromptSubmit).Count -ge 1 -and @($settings.hooks.PreToolUse).Count -ge 1
Assert 'claude-1: Claude permissions, hooks, and 17 name-only overrides remain intact' $claudeOk 'Claude project settings drifted'

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
