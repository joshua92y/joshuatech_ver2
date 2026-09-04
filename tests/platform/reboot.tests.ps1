# tests/platform/reboot.tests.ps1 — 노드 A 재부팅 후 자동 복구 단언 (T034, US2 AC4)
# Run (평상시 — 러너 tests/platform/run-platform-tests.ps1이 인자 없이 호출):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1
#     → 전제(kubectl·KUBECONFIG·agent-view 신원)만 검사하고 reboot-1..4는 SKIP, exit 0. 재부팅 리허설이 아닐 때
#       다른 플랫폼 테스트를 막지 않기 위한 동작이며, 전제 실패(kubectl 부재·KUBECONFIG 부재·신원 불일치)는 여기서도 FAIL이다.
# Run (재부팅 리허설 — 운영자 수동 트리거): 운영자가 SSH(cloudflared 터널)로 노드 A를 재부팅한 직후 바로 실행한다.
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -AfterReboot
#     → 이 스크립트의 시작 시각을 0초로 잡고 아래 계약을 10초 간격으로 폴링해 단계별 통과 시각(경과 초)을 기록한다.
# Exit 0 = FAIL 0 (PASS/SKIP만), 1 = FAIL ≥ 1 (전제 실패 포함 — fail closed). 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 구조).
#
# 계약(tasks.md T034 · spec.md US2 AC4 · quickstart.md "재부팅 시나리오"):
#   reboot-0  API 서버 도달 + 컨텍스트 사용자 = system:serviceaccount:kube-system:agent-view (300초 내).
#             재부팅 직후에는 API 서버가 내려가 있으므로 도달 자체를 폴링한다. 도달했는데 다른 신원이면 즉시 FAIL하고 중단한다
#             (러너와 같은 fail-closed 신원 게이트 — admin kubeconfig로는 이 리허설도 돌리지 않는다).
#   reboot-1  Vault `GET /v1/sys/seal-status` → sealed=false 그리고 type=ocikms (300초 내). svc/vault port-forward 경유
#             (agent-view는 vault ns pods/portforward만 있고 exec는 없다 — quickstart 45–46행).
#   reboot-2  ClusterSecretStore가 정확히 5개(vault-platform·vault-dev·vault-prod·vault-data·k8s-data-ca; FR-049)이고 전부
#             조건 Ready=True (300초 내). 이름 집합이 다르면(누락·추가) 미충족.
#   reboot-3  argocd 네임스페이스의 Application 전부 status.health.status=Healthy (300초 내; 0개면 미충족 — task 문면은 Healthy만,
#             Synced 여부는 정보로만 출력).
#   reboot-4  ExternalSecret(전 네임스페이스, 1개 이상) 전부 조건 Ready=True/reason=SecretSynced. 판정 창은 reboot-0..3 폴링이
#             끝난 시각(전부 통과 또는 300초 마감)부터 다음 refresh(refreshInterval 5m = 300초) 안이다. 재부팅 직후 한 번의
#             조회로 판정하지 않는다(task 문면). store Ready 시각 기준 경과도 함께 출력한다. reboot-2가 끝내 Ready가 아니면
#             refresh가 성공할 수 없으므로 폴링하지 않고 바로 FAIL한다.
#
# 접근 경계: $env:KUBECONFIG(agent-view 토큰)로 `kubectl auth whoami`·`kubectl get`·`kubectl port-forward`(vault ns)만 쓴다.
#   클러스터를 바꾸는 동사는 하나도 쓰지 않는다(재부팅 자체는 운영자가 수행 — 이 파일은 관찰만 한다).
#   비밀·자격·개인 경로는 출력하지 않는다(KUBECONFIG 경로도 찍지 않는다).
#   port-forward는 Vault 확인 1회마다 짧게 띄우고(로컬 127.0.0.1:18200 → 8200; 운영자가 띄운 8200 port-forward와 충돌하지 않게)
#   try/finally로 반드시 종료한다. 재부팅 직후 vault 파드가 없으면 port-forward가 곧바로 종료되므로 그 경우도 "아직"으로 본다.
# 출력: `PASS|FAIL|SKIP <id>: …` 줄(폴링 진행 줄은 두 칸 들여쓰기), 마지막 줄 `N passed, N failed, N skipped`.
#   시간 계산은 [Diagnostics.Stopwatch]. 비교는 전부 ordinal(CLAUDE.md Known Issues).
param([switch]$AfterReboot)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다

# ---------- 상수(계약 값) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$expectedStores = @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')
$phaseDeadlineSec = 300        # reboot-0..3 마감(시작 시각 기준)
$esRefreshSec = 300            # ExternalSecret refreshInterval 5m 표준 — reboot-4 판정 창
$pollIntervalSec = 10          # 폴링 간격(10–15초 계약)
$kubectlTimeout = '--request-timeout=10s'
$vaultLocalPort = 18200
$pfReadyWaitSec = 8            # port-forward가 응답을 내기까지 기다리는 상한(확인 1회당)

$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:pf = $null             # 살아 있는 port-forward 프로세스(스크립트 종료 시 반드시 정리)
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$id, [string]$label, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS ${id}: $label -- $detail" }
    else { $script:fail++; Write-Host "FAIL ${id}: $label -- $detail" }
}
function Skip([string]$id, [string]$label) {
    $script:skip++
    Write-Host "SKIP ${id}: manual trigger only (-AfterReboot) -- $label"
}
function Finish {
    Write-Host ''
    Write-Host "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
    if ($script:fail -gt 0) { exit 1 } else { exit 0 }
}
function Elapsed { return [int][Math]::Round($script:sw.Elapsed.TotalSeconds) }
function Clip([string]$s, [int]$max = 300) {
    $t = ($s -replace '\s+', ' ').Trim()
    if ($t.Length -le $max) { return $t }
    return $t.Substring(0, $max) + '...'   # ASCII만 — CP949 콘솔에서 U+2026이 깨지지 않게
}
# 중첩 해시테이블을 안전하게 걷는다(중간에 없으면 $null). ConvertFrom-Json -AsHashtable 결과 전용.
function Get-Path($o, [string[]]$keys) {
    foreach ($k in $keys) {
        if ($null -eq $o -or -not ($o -is [System.Collections.IDictionary])) { return $null }
        $o = $o[$k]
    }
    return $o
}
function Get-ReadyCondition($item) {
    $conds = @(Get-Path $item @('status', 'conditions'))
    foreach ($c in $conds) {
        if ($c -is [System.Collections.IDictionary] -and [string]::Equals("$($c['type'])", 'Ready', [StringComparison]::Ordinal)) { return $c }
    }
    return $null
}
function Sort-Ordinal([string[]]$a) {
    $arr = @($a | ForEach-Object { "$_" })
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return $arr
}

# kubectl 실행(읽기 전용 동사만 넘긴다). stderr는 임시 파일로 받아 detail에 쓴다(러너와 같은 방식).
function Invoke-Kubectl([string[]]$kubectlArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('reboot-kubectl-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $lines = & kubectl @kubectlArgs 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { ([IO.File]::ReadAllText($errFile)).Trim() } else { '' }
    } finally {
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return @{ code = $code; out = (@($lines | ForEach-Object { "$_" }) -join "`n"); err = $err }
}
# `kubectl get … -o json` → @{ ok; obj(해시테이블); reason }
function Get-KubeJson([string[]]$kubectlArgs) {
    $r = Invoke-Kubectl $kubectlArgs
    if ($r.code -ne 0) { return @{ ok = $false; obj = $null; reason = "kubectl $($kubectlArgs[0]) $($kubectlArgs[1]) exit=$($r.code): $(Clip $r.err)" } }
    try { $obj = $r.out | ConvertFrom-Json -AsHashtable } catch { return @{ ok = $false; obj = $null; reason = "kubectl output is not JSON: $(Clip $_.Exception.Message)" } }
    if ($null -eq $obj -or -not ($obj -is [System.Collections.IDictionary])) { return @{ ok = $false; obj = $null; reason = 'kubectl JSON has no object root' } }
    return @{ ok = $true; obj = $obj; reason = '' }
}

# ---------- 조건 함수: 각각 @{ ok; detail; fatal } 를 돌려준다(fatal = 더 기다려도 소용없는 거부 → 즉시 중단) ----------
function Test-Identity {
    $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json', $kubectlTimeout)
    if ($r.code -ne 0) { return @{ ok = $false; fatal = $false; detail = "kubectl auth whoami exit=$($r.code): $(Clip $r.err)" } }
    $u = $null
    try {
        $j = $r.out | ConvertFrom-Json -AsHashtable
        $u = [string](Get-Path $j @('status', 'userInfo', 'username'))
    } catch { $u = $null }
    if ([string]::IsNullOrWhiteSpace($u)) { return @{ ok = $false; fatal = $false; detail = "could not parse 'kubectl auth whoami -o json' output" } }
    if (-not [string]::Equals($u, $expectedUser, [StringComparison]::Ordinal)) {
        return @{ ok = $false; fatal = $true; detail = "context user is '$u', expected '$expectedUser'; refusing to run with non-agent-view credentials (fail closed)" }
    }
    return @{ ok = $true; fatal = $false; detail = "context user $u" }
}

function Test-Vault {
    $kubectlExe = (Get-Command kubectl).Source
    $tmp = [IO.Path]::GetTempPath()
    $tag = [guid]::NewGuid().ToString('N')
    $outFile = Join-Path $tmp "reboot-pf-$tag.out.txt"
    $errFile = Join-Path $tmp "reboot-pf-$tag.err.txt"
    $p = $null
    try {
        $pfArgs = @('-n', 'vault', 'port-forward', 'svc/vault', "$($vaultLocalPort):8200", '--address', '127.0.0.1')
        $p = Start-Process -FilePath $kubectlExe -ArgumentList $pfArgs -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        $script:pf = $p
        $until = [DateTime]::UtcNow.AddSeconds($pfReadyWaitSec)
        $lastErr = ''
        while ([DateTime]::UtcNow -lt $until) {
            if ($p.HasExited) {
                $e = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
                return @{ ok = $false; fatal = $false; detail = "port-forward exited (exit=$($p.ExitCode)): $(Clip $e)" }
            }
            try {
                $j = Invoke-RestMethod -Uri "http://127.0.0.1:$vaultLocalPort/v1/sys/seal-status" -Method Get -TimeoutSec 5 -NoProxy
                $sealed = $j.sealed
                $type = "$($j.type)"
                $ok = ($sealed -is [bool]) -and (-not $sealed) -and [string]::Equals($type, 'ocikms', [StringComparison]::Ordinal)
                return @{ ok = $ok; fatal = $false; detail = "sealed=$sealed type=$type initialized=$($j.initialized)" }
            } catch {
                $lastErr = $_.Exception.Message
                Start-Sleep -Seconds 1
            }
        }
        return @{ ok = $false; fatal = $false; detail = "seal-status not answered within ${pfReadyWaitSec}s via port-forward: $(Clip $lastErr)" }
    } finally {
        if ($null -ne $p -and -not $p.HasExited) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            $null = $p.WaitForExit(3000)
        }
        $script:pf = $null
        Remove-Item -LiteralPath $outFile, $errFile -Force -ErrorAction SilentlyContinue
    }
}

function Test-Stores {
    $r = Get-KubeJson @('get', 'clustersecretstores.external-secrets.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; detail = $r.reason } }
    $items = @($r.obj['items'])
    $names = @()
    $ready = @()
    $notReady = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $names += $n
        $c = Get-ReadyCondition $it
        if ($null -ne $c -and [string]::Equals("$($c['status'])", 'True', [StringComparison]::Ordinal)) { $ready += $n }
        else { $notReady += "$n(status=$(if ($null -ne $c) { "$($c['status'])" } else { 'none' }) reason=$(if ($null -ne $c) { "$($c['reason'])" } else { '-' }))" }
    }
    $missing = @($expectedStores | Where-Object { $e = $_; -not ($names | Where-Object { [string]::Equals($_, $e, [StringComparison]::Ordinal) }) })
    $extra = @($names | Where-Object { $n = $_; -not ($expectedStores | Where-Object { [string]::Equals($_, $n, [StringComparison]::Ordinal) }) })
    $ok = ($items.Count -eq $expectedStores.Count -and $missing.Count -eq 0 -and $extra.Count -eq 0 -and $notReady.Count -eq 0)
    $detail = "ready $($ready.Count)/$($expectedStores.Count) [$((Sort-Ordinal $ready) -join ', ')]"
    if ($notReady.Count -gt 0) { $detail += " notReady [$((Sort-Ordinal $notReady) -join ', ')]" }
    if ($missing.Count -gt 0) { $detail += " missing [$((Sort-Ordinal $missing) -join ', ')]" }
    if ($extra.Count -gt 0) { $detail += " unexpected [$((Sort-Ordinal $extra) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; detail = $detail }
}

function Test-Argo {
    $r = Get-KubeJson @('-n', 'argocd', 'get', 'applications.argoproj.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; detail = $r.reason } }
    $items = @($r.obj['items'])
    $unhealthy = @()
    $outOfSync = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $h = "$(Get-Path $it @('status', 'health', 'status'))"
        $s = "$(Get-Path $it @('status', 'sync', 'status'))"
        if (-not [string]::Equals($h, 'Healthy', [StringComparison]::Ordinal)) { $unhealthy += "$n=$(if ($h) { $h } else { 'none' })" }
        if (-not [string]::Equals($s, 'Synced', [StringComparison]::Ordinal)) { $outOfSync += "$n=$(if ($s) { $s } else { 'none' })" }
    }
    $ok = ($items.Count -ge 1 -and $unhealthy.Count -eq 0)
    $detail = "applications $($items.Count), healthy $($items.Count - $unhealthy.Count)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($unhealthy.Count -gt 0) { $detail += " notHealthy [$((Sort-Ordinal $unhealthy) -join ', ')]" }
    if ($outOfSync.Count -gt 0) { $detail += " info: notSynced [$((Sort-Ordinal $outOfSync) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; detail = $detail }
}

function Test-ExternalSecrets {
    $r = Get-KubeJson @('get', 'externalsecrets.external-secrets.io', '-A', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; detail = $r.reason } }
    $items = @($r.obj['items'])
    $notSynced = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'namespace'))/$(Get-Path $it @('metadata', 'name'))"
        $c = Get-ReadyCondition $it
        $synced = ($null -ne $c -and [string]::Equals("$($c['status'])", 'True', [StringComparison]::Ordinal) -and [string]::Equals("$($c['reason'])", 'SecretSynced', [StringComparison]::Ordinal))
        if (-not $synced) { $notSynced += "$n=$(if ($null -ne $c) { "$($c['reason'])/$($c['status'])" } else { 'none' })" }
    }
    $ok = ($items.Count -ge 1 -and $notSynced.Count -eq 0)
    $detail = "externalsecrets $($items.Count), SecretSynced $($items.Count - $notSynced.Count)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($notSynced.Count -gt 0) { $detail += " notSynced [$((Sort-Ordinal $notSynced) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; detail = $detail }
}

# ---------- 폴링 엔진 ----------
# $conds 원소: @{ id; label; test=[scriptblock] → @{ok; detail; fatal}; after=<선행 id 또는 $null> }
# 반환: id → @{ ok; at(통과 경과 초); detail(마지막 관측); fatal; checked }
function Invoke-PollPhase([int]$deadlineSec, [object[]]$conds) {
    $state = @{}
    foreach ($c in $conds) { $state[$c.id] = @{ ok = $false; at = $null; detail = 'not checked'; fatal = $false; checked = $false } }
    while ($true) {
        foreach ($c in $conds) {
            if ($state[$c.id].ok) { continue }
            if ($null -ne $c.after -and -not $state[$c.after].ok) { continue }
            $r = & $c.test
            $state[$c.id].checked = $true
            $state[$c.id].detail = [string]$r.detail
            if ($r.ok) {
                $state[$c.id].ok = $true
                $state[$c.id].at = Elapsed
                Write-Host "  [$($state[$c.id].at)s] $($c.id) met -- $(Clip $r.detail 200)"
            } elseif ($r.fatal) {
                $state[$c.id].fatal = $true
                return $state
            }
        }
        $pending = @($conds | Where-Object { -not $state[$_.id].ok })
        if ($pending.Count -eq 0) { return $state }
        $remaining = $deadlineSec - $script:sw.Elapsed.TotalSeconds
        if ($remaining -le 0) { return $state }
        $summary = @($pending | ForEach-Object { "$($_.id)($(Clip $state[$_.id].detail 120))" }) -join '; '
        Write-Host "  [$(Elapsed)s] waiting (deadline ${deadlineSec}s): $summary"
        Start-Sleep -Seconds ([Math]::Min($pollIntervalSec, [Math]::Ceiling($remaining)))
    }
}

# ---------- 본체 ----------
try {
    $mode = if ($AfterReboot) { 'after-reboot (manual trigger)' } else { 'normal (runner path; reboot-1..4 skipped)' }
    Write-Host "reboot.tests.ps1: mode=$mode start=$([DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz'))"

    # 전제(항상, fail-closed): kubectl · KUBECONFIG(단일 파일 경로; 상대 경로는 PSPath로 해석 — CLAUDE.md Known Issues)
    $hasKubectl = $null -ne (Get-Command kubectl -ErrorAction SilentlyContinue)
    Assert 'reboot-pre-1' 'kubectl on PATH' $hasKubectl $(if ($hasKubectl) { 'found' } else { 'kubectl not found on PATH; cannot observe the cluster (fail closed)' })
    $kubeconfigOk = $false
    $kubeconfigWhy = 'found'
    if ([string]::IsNullOrWhiteSpace($env:KUBECONFIG)) { $kubeconfigWhy = 'KUBECONFIG is not set; an agent-view kubeconfig is required (fail closed)' }
    else {
        $kubeconfigPath = $null
        try { $kubeconfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:KUBECONFIG) } catch { $kubeconfigPath = $null }
        if ($kubeconfigPath -and (Test-Path -LiteralPath $kubeconfigPath -PathType Leaf)) { $kubeconfigOk = $true }
        else { $kubeconfigWhy = 'KUBECONFIG file not found (path not printed; single file path only)' }
    }
    Assert 'reboot-pre-2' 'KUBECONFIG set and file exists' $kubeconfigOk $kubeconfigWhy
    if ($script:fail -gt 0) { Finish }

    $phases = @(
        @{ id = 'reboot-0'; label = "API reachable and context user is $expectedUser"; test = { Test-Identity }; after = $null },
        @{ id = 'reboot-1'; label = 'vault seal-status sealed=false type=ocikms (port-forward svc/vault)'; test = { Test-Vault }; after = 'reboot-0' },
        @{ id = 'reboot-2'; label = "clustersecretstores exactly 5 and all Ready [$($expectedStores -join ', ')]"; test = { Test-Stores }; after = 'reboot-0' },
        @{ id = 'reboot-3'; label = 'argocd applications all Healthy'; test = { Test-Argo }; after = 'reboot-0' }
    )
    $esLabel = "externalsecrets all SecretSynced within next refresh (${esRefreshSec}s) after reboot-0..3 polling ends"

    if (-not $AfterReboot) {
        # 평상시: 신원은 한 번만 확인(러너가 이미 통과시켰지만 단독 실행도 같은 경계를 지킨다), 재부팅 단언은 SKIP.
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        foreach ($c in $phases) { if (-not [string]::Equals($c.id, 'reboot-0', [StringComparison]::Ordinal)) { Skip $c.id $c.label } }
        Skip 'reboot-4' $esLabel
        Finish
    }

    # ---------- 단계 A: reboot-0..3, 시작 시각부터 300초 ----------
    Write-Host "phase A: polling reboot-0..3 every ${pollIntervalSec}s until ${phaseDeadlineSec}s"
    $stA = Invoke-PollPhase $phaseDeadlineSec $phases
    $phaseAEnd = Elapsed
    $fatal = @($phases | Where-Object { $stA[$_.id].fatal }).Count -gt 0
    foreach ($c in $phases) {
        $s = $stA[$c.id]
        if ($s.ok) { Assert $c.id $c.label $true "met at $($s.at)s ($($s.detail))" }
        elseif ($s.fatal) { Assert $c.id $c.label $false $s.detail }
        elseif ($fatal) { Assert $c.id $c.label $false 'not attempted (identity refused)' }
        elseif (-not $s.checked) { Assert $c.id $c.label $false "not attempted ($($c.after) not met within ${phaseDeadlineSec}s)" }
        else { Assert $c.id $c.label $false "not met within ${phaseDeadlineSec}s (last: $($s.detail))" }
    }
    Write-Host "phase A ended at ${phaseAEnd}s"

    # ---------- 단계 B: reboot-4, 단계 A 종료 시각부터 +300초(다음 refresh) ----------
    if ($fatal) {
        Assert 'reboot-4' $esLabel $false 'not attempted (identity refused)'
    } elseif (-not $stA['reboot-2'].ok) {
        Assert 'reboot-4' $esLabel $false "not attempted (clustersecretstores were not Ready within ${phaseDeadlineSec}s, so no refresh can succeed; last: $($stA['reboot-2'].detail))"
    } else {
        $storeAt = [int]$stA['reboot-2'].at
        $esDeadline = $phaseAEnd + $esRefreshSec
        Write-Host "phase B: polling reboot-4 every ${pollIntervalSec}s until ${esDeadline}s (stores Ready at ${storeAt}s; refreshInterval ${esRefreshSec}s)"
        $stB = Invoke-PollPhase $esDeadline @(@{ id = 'reboot-4'; label = $esLabel; test = { Test-ExternalSecrets }; after = $null })
        $s = $stB['reboot-4']
        if ($s.ok) { Assert 'reboot-4' $esLabel $true "met at $($s.at)s (+$($s.at - $phaseAEnd)s after phase A, +$($s.at - $storeAt)s after stores Ready; $($s.detail))" }
        else { Assert 'reboot-4' $esLabel $false "not all SecretSynced by ${esDeadline}s (last: $($s.detail))" }
    }
    Finish
} finally {
    if ($null -ne $script:pf -and -not $script:pf.HasExited) {
        Stop-Process -Id $script:pf.Id -Force -ErrorAction SilentlyContinue
    }
}
