# Repository checks. Run: pwsh -NoProfile -File tests/run-all.ps1
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 pwsh의 0이 아닌 종료 코드를 예외로 바꾸지 않는다(프로파일이 $true로 켜도 무관) — Check가 $LASTEXITCODE로 판정한다
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

# 1b2. platform runner harness tests (tests/platform/run-platform-tests.ps1 단위 테스트)
pwsh -NoProfile -ExecutionPolicy Bypass -File tests/scripts/run-platform-tests.tests.ps1 | Out-Host
Check 'platform-harness' ($LASTEXITCODE -eq 0) 'see platform runner harness output'

# 1c. specs index freshness — 이 검사는 낡은 인덱스를 발견하면 specs/README.md를 갱신하는 부작용이 있다(FAIL이면 diff를 검토하고 커밋한다)
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/update-specs-index.ps1 2>&1 | Out-String
Check 'specs-index-fresh' ($LASTEXITCODE -eq 0 -and $o -match '\(unchanged\)') ("exit=$LASTEXITCODE; $($o.Trim()) -- if stale: README was regenerated now, review and commit specs/README.md; if error: fix the spec header and rerun")

# 1d. platform tests (T004) — KUBECONFIG 없으면 러너가 SKIP 요약 후 0으로 끝난다(SKIP 허용).
#     러너는 agent-view 신원 게이트를 통과해야만 tests/platform/*.tests.ps1을 실행한다(검사 본체는 US 단계에서 작성).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/platform/run-platform-tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
if ($c -eq 0 -and $o -match '(?m)^(SKIP platform tests -- |0 test files \(SKIP\))') { Write-Host 'SKIP platform -- allowed (no KUBECONFIG or no platform test files)' }
else { Check 'platform' ($c -eq 0 -and $o -match '(?m)^test files: \d+ passed, 0 failed\r?$') "exit=$c; see platform test output above" }

# 1e. adr-madr (T004 자리, 본체 T016·T017) — tests/decisions/madr.tests.ps1 + tests/memory/memory-docs.tests.ps1.
#     각 테스트 파일은 자기 대상 문서가 "전부" 없을 때만 첫 줄 'SKIP <name> tests -- ' + exit 0으로 끝난다
#     (madr: docs/decisions/00{02..10}-*.md 0/9, T018–T026 전; memory-docs: memory 2 파일 모두 부재, T027–T028 전).
#     부분 존재 = 전체 단언(fail closed). 실행된 파일이 모두 그 SKIP이면 슬롯도 SKIP(FAIL 아님); 아니면 Check로 판정.
$adrTests = @(@('tests/decisions/madr.tests.ps1', 'tests/memory/memory-docs.tests.ps1') | Where-Object { Test-Path -LiteralPath (Join-Path $repo $_) })
if ($adrTests.Count -eq 0) {
    Write-Host 'SKIP adr-madr -- test files not written yet (US1: tests/decisions/madr.tests.ps1, tests/memory/memory-docs.tests.ps1)'
} else {
    $adrFail = 0; $adrSkip = 0; $adrNoEvidence = 0
    foreach ($t in $adrTests) {
        $o = pwsh -NoProfile -ExecutionPolicy Bypass -File $t 2>&1 | Out-String
        $c = $LASTEXITCODE
        Write-Host ($o.TrimEnd())
        if ($c -ne 0) { $adrFail++ }
        elseif ($o -match '(?m)^SKIP (madr|memory-docs) tests -- ') { $adrSkip++ }
        elseif ($o -notmatch '(?m)^\d+ passed, 0 failed\r?$') { $adrFail++; $adrNoEvidence++ }   # exit 0인데 요약도 SKIP 마커도 없음(크래시/마커 표류) — 양성 증거 요구, fail closed (1d와 같은 규율)
    }
    if ($adrFail -eq 0 -and $adrSkip -eq $adrTests.Count) { Write-Host 'SKIP adr-madr -- allowed (subject docs not written yet; see SKIP lines above)' }
    else {
        $adrName = if ($adrSkip -gt 0) { "adr-madr ($adrSkip skipped)" } else { 'adr-madr' }
        $adrDetail = "$adrFail of $($adrTests.Count) test file(s) failed"
        if ($adrNoEvidence -gt 0) { $adrDetail += " ($adrNoEvidence exited 0 with no summary/SKIP marker)" }
        Check $adrName ($adrFail -eq 0) $adrDetail
    }
}

# 1f. agent-layer (T108 자리, 본체 T109·T110·T112) — tests/agents/agent-layer.tests.ps1.
#     이 스위트는 SKIP 없이 fail closed(대상 rules 5·builder 3·kr 미러가 없으면 FAIL이 정상 — RED 창구간).
#     1d·1e와 같은 양성 증거 규율: exit 0 이면서 요약 줄 'N passed, 0 failed'가 있어야 PASS(빈 출력 = FAIL).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/agents/agent-layer.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'agent-layer' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see agent-layer test output above"

# 1g. host-prep (T014) — tests/infra/host-prep.tests.ps1: infra/bootstrap/host-prep.sh 정적 검사(원문만; 노드 실행 없음).
#     SKIP 없이 fail closed(스크립트 부재 = 전 단언 FAIL; 유일한 SKIP 줄은 bash 부재 시 syntax-1 뿐이며 합계에 들어가지 않는다).
#     1f와 같은 양성 증거 규율: exit 0 이면서 요약 줄 'N passed, 0 failed'가 있어야 PASS(빈 출력 = FAIL).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/host-prep.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'host-prep' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see host-prep test output above"

# 1h. k3s-server (T035) — tests/infra/k3s-server.tests.ps1: infra/bootstrap/k3s-server.sh 정적 검사(원문만; 노드 실행·K3s 설치 없음).
#     1g와 같은 규율: SKIP 없이 fail closed(스크립트 부재 = 전 단언 FAIL; 유일한 SKIP 줄은 bash 부재 시 syntax-1 뿐이며 합계에 들어가지 않는다),
#     exit 0 이면서 요약 줄 'N passed, 0 failed'가 있어야 PASS(빈 출력 = FAIL).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/k3s-server.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'k3s-server' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see k3s-server test output above"

# 1i. k3s-agent (T036) — tests/infra/k3s-agent.tests.ps1: infra/bootstrap/k3s-agent.sh 정적 검사(원문만; 노드 실행·조인 없음).
#     1h와 같은 규율: SKIP 없이 fail closed(스크립트 부재 = 전 단언 FAIL; 유일한 SKIP 줄은 bash 부재 시 syntax-1 뿐이며 합계에 들어가지 않는다),
#     exit 0 이면서 요약 줄 'N passed, 0 failed'가 있어야 PASS(빈 출력 = FAIL).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/k3s-agent.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'k3s-agent' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see k3s-agent test output above"

# 1j. platform-backup (T036, FR-047) — tests/infra/platform-backup.tests.ps1: infra/bootstrap/platform-backup.{sh,service,timer} 정적 검사
#     (원문만; 백업 실행·kubectl·oci·age 호출 없음). 세 파일 중 하나라도 없으면 전 단언 FAIL(fail closed), 1i와 같은 양성 증거 규율.
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/platform-backup.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'platform-backup' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see platform-backup test output above"

# 1k. traefik-config (T038) — tests/infra/traefik-config.tests.ps1: infra/bootstrap/traefik-config.yaml(HelmChartConfig) 정적 검사
#     (원문만; 노드·kubectl·helm 실행 없음 — 적용은 운영자 절차). 1j와 같은 규율: SKIP 없이 fail closed(파일 부재 = 전 단언 FAIL),
#     exit 0 이면서 요약 줄 'N passed, 0 failed'가 있어야 PASS(빈 출력 = FAIL).
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/traefik-config.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'traefik-config' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see traefik-config test output above"

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
