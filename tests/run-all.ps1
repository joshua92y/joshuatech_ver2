# Repository checks. Run: pwsh -NoProfile -File tests/run-all.ps1
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repo
$script:fail = 0
function Check([string]$name, [bool]$ok, [string]$detail) {
    if ($ok) { Write-Host "PASS $name" } else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 1. hook unit tests
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/hooks/run-hook-tests.ps1 | Out-Host
Check 'hooks' ($LASTEXITCODE -eq 0) 'see hook test output'

# 1b. scripts tests
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/scripts/update-specs-index.tests.ps1 | Out-Host
Check 'scripts' ($LASTEXITCODE -eq 0) 'see scripts test output'

# 1c. specs index freshness — 이 검사는 낡은 인덱스를 발견하면 specs/README.md를 갱신하는 부작용이 있다(FAIL이면 diff를 검토하고 커밋한다)
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/update-specs-index.ps1 2>&1 | Out-String
Check 'specs-index-fresh' ($LASTEXITCODE -eq 0 -and $o -match '\(unchanged\)') 'specs/README.md was stale (regenerated now) - review and commit'

# 2. CLAUDE.md <= 200 lines
$n = if (Test-Path CLAUDE.md) { (Get-Content CLAUDE.md).Count } else { -1 }
Check "CLAUDE.md lines ($n) <= 200" ($n -ge 0 -and $n -le 200) 'missing or too long'

# 3. settings.json parses; skillOverrides covers every speckit-* skill; hooks registered
$s = $null
if (Test-Path .claude/settings.json) { $s = Get-Content .claude/settings.json -Raw | ConvertFrom-Json }
$skills = (Get-ChildItem .claude/skills -Directory | Where-Object Name -like 'speckit-*').Name
$missing = @($skills | Where-Object { -not ($s -and $s.skillOverrides -and $s.skillOverrides.$_ -eq 'name-only') })
Check 'skillOverrides name-only for every speckit-*' ($s -and $missing.Count -eq 0) ($missing -join ', ')
Check 'hooks registered (UserPromptSubmit + PreToolUse Skill)' ($s -and $s.hooks.UserPromptSubmit.Count -ge 1 -and $s.hooks.PreToolUse[0].matcher -eq 'Skill') 'settings.json missing or hooks not registered'

# 4. Korean mirror coverage (SC-005)
$pairs = @{
    'CLAUDE.md'                                = 'docs/kr/CLAUDE_kr.md'
    'AGENTS.md'                                = 'docs/kr/AGENTS_kr.md'
    '.specify/memory/constitution.md'          = 'docs/kr/constitution_kr.md'
    '.claude/agents/tester.md'                 = 'docs/kr/agents/tester_kr.md'
    '.claude/skills/approval-review/SKILL.md'  = 'docs/kr/skills/approval-review_kr.md'
    '.claude/skills/finish/SKILL.md'           = 'docs/kr/skills/finish_kr.md'
    '.claude/rules/specs.md'                   = 'docs/kr/rules/specs_kr.md'
    '.claude/rules/docs.md'                    = 'docs/kr/rules/docs_kr.md'
    '.claude/rules/content.md'                 = 'docs/kr/rules/content_kr.md'
}
$nomirror = @($pairs.Keys | Where-Object { -not (Test-Path $pairs[$_]) })
Check 'kr mirrors present (9)' ($nomirror.Count -eq 0) ($nomirror -join ', ')

# 5. constitution has no template placeholders
$ph = @(Select-String -Path .specify/memory/constitution.md -Pattern '\[[A-Z_0-9]+\]' -AllMatches)
Check 'constitution placeholders = 0' ($ph.Count -eq 0) (($ph | ForEach-Object { $_.Line }) -join ' | ')

# 6. canonical-language header on every agent file
$nohdr = @($pairs.Keys | Where-Object { -not (Test-Path $_) -or -not (Select-String -Path $_ -Pattern 'Canonical language: English' -Quiet) })
Check 'canonical-language headers (9)' ($nohdr.Count -eq 0) ($nohdr -join ', ')

# 7. tasks template override active
$resolved = pwsh -NoProfile -File .specify/scripts/powershell/resolve-template.ps1 tasks-template
Check 'tasks-template override (MANDATORY, no OPTIONAL)' ((($resolved | Select-String 'MANDATORY').Count -ge 7) -and (($resolved | Select-String 'OPTIONAL').Count -eq 0)) ''

# 8. every feature dir is indexed in specs/README.md
$dirs = (Get-ChildItem specs -Directory | Where-Object Name -match '^\d{3,}-').Name
$idx = if (Test-Path specs/README.md) { Get-Content specs/README.md -Raw } else { '' }
$unindexed = @($dirs | Where-Object { $idx -notmatch [regex]::Escape($_) })
Check 'specs/README.md indexes every feature' ($unindexed.Count -eq 0) ($unindexed -join ', ')

# 9. mirrors keep English headings (translate prose only)
$badHeadings = @()
foreach ($src in $pairs.Keys) {
    $mir = $pairs[$src]
    if (-not (Test-Path $src) -or -not (Test-Path $mir)) { continue }
    $srcH = @(Select-String -Path $src -Pattern '^#{1,6} ' | ForEach-Object { $_.Line.Trim() })
    $mirText = Get-Content $mir -Raw
    foreach ($h in $srcH) { if ($mirText -notmatch [regex]::Escape($h)) { $badHeadings += "$mir lacks '$h'" } }
}
Check 'mirrors keep English headings' ($badHeadings.Count -eq 0) ($badHeadings -join '; ')

Write-Host ''
if ($script:fail -eq 0) { Write-Host 'ALL PASS'; exit 0 } else { Write-Host "$($script:fail) FAILED"; exit 1 }
