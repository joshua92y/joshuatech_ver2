# tests/platform/reboot.tests.ps1 — 노드 A 재부팅 후 자동 복구 단언 (T034, US2 AC4)
# Run (평상시 — 러너 tests/platform/run-platform-tests.ps1이 인자 없이 호출):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1
#     → 전제(kubectl·KUBECONFIG·agent-view 신원)만 검사하고 reboot-1..4는 SKIP, exit 0. 재부팅 리허설이 아닐 때
#       다른 플랫폼 테스트를 막지 않기 위한 동작이며, 전제 실패(kubectl 부재·KUBECONFIG 부재·신원 불일치)는 여기서도 FAIL이다.
# Run (재부팅 리허설 — 운영자 수동 트리거): 운영자가 SSH(cloudflared 터널)로 노드 A를 재부팅한 직후 바로 실행한다.
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -AfterReboot
#     → 이 스크립트의 시작 시각을 0초로 잡고 아래 계약을 한 루프에서 폴링해 조건별 통과 시각(경과 초)을 기록한다.
#       간격은 명목 10 s다(한 라운드가 kubectl 호출·port-forward 시간만큼 길어지면 그만큼 늘어난다). 조건마다 마감이 있고,
#       마감을 넘긴 뒤의 관측은 충족이어도 FAIL("met late at Ns (deadline Ds)")이다 — 마감 안의 관측만 통과로 기록한다.
# Exit 0 = FAIL 0 (PASS/SKIP만), 1 = FAIL ≥ 1 (전제 실패 포함 — fail closed). 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 구조).
#
# 계약(tasks.md T034 · spec.md US2 AC4 · quickstart.md "재부팅 시나리오"):
#   reboot-0  API 서버 도달 + 컨텍스트 사용자 = system:serviceaccount:kube-system:agent-view (마감 300 s, 시작 기준).
#             재부팅 직후에는 API 서버가 내려가 있으므로 도달 자체를 폴링한다. 도달했는데 다른 신원이거나 401 Unauthorized(토큰 만료·
#             무효)면 즉시 FAIL하고 전체를 중단한다(300 s 재시도 없음 — 러너와 같은 fail-closed 신원 게이트).
#   reboot-1  Vault `GET /v1/sys/seal-status` → sealed=false 그리고 type=ocikms (마감 300 s). svc/vault port-forward 경유
#             (agent-view는 vault ns pods/portforward만 있고 exec는 없다 — quickstart 45–46행). 확인 1회마다 빈 로컬 포트를
#             새로 할당해 짧게 띄우고, port-forward stdout의 "Forwarding from 127.0.0.1:<port> ->" 줄을 본 뒤에만 질의하며,
#             응답 뒤 프로세스 생존을 재확인한다(죽어 있으면 타인 리스너의 응답으로 보고 불신). 종료는 프로세스 트리째(Kill(true)).
#   reboot-2  ClusterSecretStore가 정확히 5개(vault-platform·vault-dev·vault-prod·vault-data·k8s-data-ca; FR-049)이고 전부
#             조건 Ready=True (마감 300 s). 이름 집합이 다르면(누락·추가) 미충족. 통과 관측에서 Ready 조건 lastTransitionTime의
#             최대값(서버 시각, UTC)을 anchor로 기록한다(reboot-4의 전이 증거 기준).
#   reboot-3  argocd 네임스페이스의 Application 전부 status.health.status=Healthy (마감 300 s; 0개면 미충족 — task 문면은 Healthy만,
#             Synced 여부는 정보로만 출력).
#   reboot-4  ExternalSecret(전 네임스페이스, 1개 이상) 전부 조건 Ready=True/reason=SecretSynced 이고 status.refreshTime ≥ anchor
#             (= 재부팅 뒤 store가 Ready로 돌아온 다음 실제 refresh가 일어났다는 전이 증거). 마감 = reboot-2 통과 시각 + 300 s
#             (refreshInterval 5m 표준 = 다음 refresh; 문면 정본 — Argo 등 다른 조건의 지연으로 늘어나지 않는다). reboot-2 통과
#             직후부터 폴링한다(재부팅 직후 한 번의 조회로 판정하지 않는다). reboot-2가 최종 실패(마감 초과·late)면 not attempted.
#             refreshTime·lastTransitionTime 부재/파싱 불가는 fail-closed(FAIL).
#
# 접근 경계: $env:KUBECONFIG(agent-view 토큰)로 `kubectl auth whoami`·`kubectl get`·`kubectl port-forward`(vault ns)만 쓴다.
#   클러스터를 바꾸는 동사는 하나도 쓰지 않는다(재부팅 자체는 운영자가 수행 — 이 파일은 관찰만 한다).
#   비밀·자격·개인 경로는 출력하지 않는다: KUBECONFIG 경로가 kubectl 오류 문구에 섞여 나오면 `<KUBECONFIG>`로 치환(ordinal)한다.
# 출력: `PASS|FAIL|SKIP <id>: …` 줄(폴링 진행 줄은 두 칸 들여쓰기), 마지막 줄 `N passed, N failed, N skipped`.
#   시간 계산은 [Diagnostics.Stopwatch]. 비교는 전부 ordinal(CLAUDE.md Known Issues).
param([switch]$AfterReboot)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다

# ---------- 상수(계약 값) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$expectedStores = @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')
$phaseDeadlineSec = 300        # reboot-0..3 마감(시작 시각 기준)
$esRefreshSec = 300            # ExternalSecret refreshInterval 5m 표준 — reboot-4 마감 = reboot-2 통과 시각 + 이 값
$pollIntervalSec = 10          # 명목 폴링 간격(라운드 길이만큼 늘어남)
$kubectlTimeout = '--request-timeout=10s'
$pfReadyWaitSec = 8            # port-forward 확인 1회당 상한(Forwarding 줄 대기 + 응답 대기)
$pfPostResponseWaitMs = 500    # 응답 뒤 port-forward 생존 재확인 유예

$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:pf = $null             # 살아 있는 port-forward 프로세스(스크립트 종료 시 반드시 정리)
$script:pfFiles = @()          # 그 리디렉션 파일
$script:redact = @()           # 출력에서 <KUBECONFIG>로 치환할 문자열들
$script:storeAnchor = $null    # reboot-2 통과 관측의 Ready lastTransitionTime 최대값(UTC DateTime)
$script:storeAnchorReason = 'reboot-2 has not passed yet'
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Now { return [double]$script:sw.Elapsed.TotalSeconds }
function Sec([double]$t) { return [int][Math]::Round($t) }
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Redact([string]$s) {
    if ($null -eq $s) { return '' }
    foreach ($x in $script:redact) { if (-not [string]::IsNullOrEmpty($x)) { $s = $s.Replace($x, '<KUBECONFIG>', [StringComparison]::Ordinal) } }
    return $s
}
function Assert([string]$id, [string]$label, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS ${id}: $label -- $(Redact $detail)" }
    else { $script:fail++; Write-Host "FAIL ${id}: $label -- $(Redact $detail)" }
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
function Clip([string]$s, [int]$max = 300) {
    $t = ((Redact "$s") -replace '\s+', ' ').Trim()   # 자르기 전에 마스킹 — 잘린 경로 조각이 치환을 비껴가지 않게
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
        if ($c -is [System.Collections.IDictionary] -and (Eq "$($c['type'])" 'Ready')) { return $c }
    }
    return $null
}
function Sort-Ordinal([string[]]$a) {
    $arr = @($a | ForEach-Object { "$_" })
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return $arr
}
# RFC 3339(서버 시각) → UTC DateTime; 부재·파싱 불가면 $null
function Parse-Utc([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $d = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([DateTimeOffset]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return $d.UtcDateTime }
    return $null
}
function Fmt-Utc([DateTime]$d) { return $d.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) }
# 자식이 아직 쓰고 있는 리디렉션 파일을 읽는다(FileShare.ReadWrite — ReadAllText는 공유 위반으로 실패한다)
function Read-SharedText([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    try {
        $fs = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try { $sr = [IO.StreamReader]::new($fs, [Text.Encoding]::UTF8); return $sr.ReadToEnd() } finally { $fs.Dispose() }
    } catch { return '' }
}
function Remove-TempFiles([string[]]$paths) {
    for ($i = 1; $i -le 3; $i++) {
        $left = @()
        foreach ($p in $paths) {
            if ([string]::IsNullOrEmpty($p)) { continue }
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $p) { $left += $p }
        }
        if ($left.Count -eq 0) { return }
        Start-Sleep -Milliseconds 300
    }
}
# port-forward 프로세스를 트리째 종료한다(cmd/래퍼가 끼어도 손자까지)
function Stop-Tree($p) {
    if ($null -eq $p) { return }
    try { if (-not $p.HasExited) { $p.Kill($true) } } catch { }
    try { $null = $p.WaitForExit(3000) } catch { }
}
function Get-FreeLocalPort {
    $l = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop(); return $port
}

# kubectl 실행(읽기 전용 동사만 넘긴다). stderr는 임시 파일로 받아 detail에 쓴다(러너와 같은 방식).
function Invoke-Kubectl([string[]]$kubectlArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('reboot-kubectl-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $lines = & kubectl @kubectlArgs 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { ([IO.File]::ReadAllText($errFile)).Trim() } else { '' }
    } finally {
        Remove-TempFiles @($errFile)
    }
    return @{ code = $code; out = (@($lines | ForEach-Object { "$_" }) -join "`n"); err = $err; cmd = "kubectl $($kubectlArgs -join ' ')" }
}
# `kubectl get … -o json` → @{ ok; items(널 제거된 배열); reason } — items 부재는 별도 reason(fail closed)
function Get-KubeItems([string[]]$kubectlArgs) {
    $r = Invoke-Kubectl $kubectlArgs
    if ($r.code -ne 0) { return @{ ok = $false; items = @(); reason = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" } }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return @{ ok = $false; items = @(); reason = "$($r.cmd) produced no output" } }
    try { $obj = $r.out | ConvertFrom-Json -AsHashtable } catch { return @{ ok = $false; items = @(); reason = "$($r.cmd) output is not JSON: $(Clip $_.Exception.Message)" } }
    if ($null -eq $obj -or -not ($obj -is [System.Collections.IDictionary])) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON root is not an object" } }
    if (-not $obj.ContainsKey('items') -or $null -eq $obj['items']) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON has no 'items' list" } }
    $items = @($obj['items'] | Where-Object { $null -ne $_ })
    return @{ ok = $true; items = $items; reason = '' }
}

# ---------- 조건 함수: 각각 @{ ok; detail; fatal; final } 를 돌려준다 ----------
#   fatal = 더 기다려도 소용없는 거부(전체 중단), final = 이 조건만 더 폴링하지 않고 FAIL 확정
function Test-Identity {
    $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json', $kubectlTimeout)
    if ($r.code -ne 0) {
        if ($r.err.IndexOf('Unauthorized', [StringComparison]::Ordinal) -ge 0) {
            return @{ ok = $false; fatal = $true; final = $false; detail = "$($r.cmd): 401 Unauthorized -- the agent-view token is expired or invalid; refusing to retry for ${phaseDeadlineSec}s (fail closed): $(Clip $r.err)" }
        }
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" }
    }
    $u = $null
    try {
        $j = $r.out | ConvertFrom-Json -AsHashtable
        $u = [string](Get-Path $j @('status', 'userInfo', 'username'))
    } catch { $u = $null }
    if ([string]::IsNullOrWhiteSpace($u)) { return @{ ok = $false; fatal = $false; final = $false; detail = "could not parse '$($r.cmd)' output" } }
    if (-not (Eq $u $expectedUser)) {
        return @{ ok = $false; fatal = $true; final = $false; detail = "context user is '$u', expected '$expectedUser'; refusing to run with non-agent-view credentials (fail closed)" }
    }
    return @{ ok = $true; fatal = $false; final = $false; detail = "context user $u" }
}

function Test-Vault {
    $kubectlExe = (Get-Command kubectl).Source
    $port = Get-FreeLocalPort
    $tmp = [IO.Path]::GetTempPath()
    $tag = [guid]::NewGuid().ToString('N')
    $outFile = Join-Path $tmp "reboot-pf-$tag.out.txt"
    $errFile = Join-Path $tmp "reboot-pf-$tag.err.txt"
    $marker = "Forwarding from 127.0.0.1:$port ->"
    $p = $null
    try {
        $pfArgs = @('-n', 'vault', 'port-forward', 'svc/vault', "${port}:8200", '--address', '127.0.0.1')
        try {
            $p = Start-Process -FilePath $kubectlExe -ArgumentList $pfArgs -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        } catch {
            return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward start failed: $(Clip $_.Exception.Message)" }
        }
        $script:pf = $p
        $script:pfFiles = @($outFile, $errFile)
        $until = [DateTime]::UtcNow.AddSeconds($pfReadyWaitSec)
        $lastErr = 'no attempt yet'
        $forwarding = $false
        while ([DateTime]::UtcNow -lt $until) {
            if ($p.HasExited) {
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited (exit=$($p.ExitCode)): $(Clip (Read-SharedText $errFile))" }
            }
            if (-not $forwarding) {
                if ((Read-SharedText $outFile).IndexOf($marker, [StringComparison]::Ordinal) -ge 0) { $forwarding = $true }
                else { $lastErr = "waiting for '$marker' on port-forward stdout"; Start-Sleep -Milliseconds 500; continue }
            }
            try {
                $j = Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/sys/seal-status" -Method Get -TimeoutSec 5 -NoProxy
            } catch {
                $lastErr = $_.Exception.Message
                Start-Sleep -Seconds 1
                continue
            }
            # 응답 뒤 생존 재확인: 그 사이 죽었으면 응답은 우리 port-forward가 아니라 그 포트의 다른 리스너에서 온 것일 수 있다
            $null = $p.WaitForExit($pfPostResponseWaitMs)
            if ($p.HasExited) {
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited right after responding (exit=$($p.ExitCode)); response on local port $port not trusted (foreign listener?): $(Clip (Read-SharedText $errFile))" }
            }
            $sealed = $j.sealed
            $type = "$($j.type)"
            $ok = ($sealed -is [bool]) -and (-not $sealed) -and (Eq $type 'ocikms')
            return @{ ok = $ok; fatal = $false; final = $false; detail = "sealed=$sealed type=$type initialized=$($j.initialized) (local port $port)" }
        }
        return @{ ok = $false; fatal = $false; final = $false; detail = "seal-status not answered within ${pfReadyWaitSec}s via port-forward (local port $port): $(Clip $lastErr)" }
    } finally {
        Stop-Tree $p
        $script:pf = $null
        $script:pfFiles = @()
        Remove-TempFiles @($outFile, $errFile)
    }
}

function Test-Stores {
    $r = Get-KubeItems @('get', 'clustersecretstores.external-secrets.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $names = @()
    $ready = @()
    $notReady = @()
    $noLtt = @()
    $anchor = $null
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $names += $n
        $c = Get-ReadyCondition $it
        if ($null -ne $c -and (Eq "$($c['status'])" 'True')) {
            $ready += $n
            $ltt = Parse-Utc "$($c['lastTransitionTime'])"
            if ($null -eq $ltt) { $noLtt += $n } elseif ($null -eq $anchor -or $ltt -gt $anchor) { $anchor = $ltt }
        } else {
            $notReady += "$n(status=$(if ($null -ne $c) { "$($c['status'])" } else { 'none' }) reason=$(if ($null -ne $c) { "$($c['reason'])" } else { '-' }))"
        }
    }
    $missing = @($expectedStores | Where-Object { $e = $_; -not ($names | Where-Object { Eq $_ $e }) })
    $extra = @($names | Where-Object { $n = $_; -not ($expectedStores | Where-Object { Eq $_ $n }) })
    $ok = ($items.Count -eq $expectedStores.Count -and $missing.Count -eq 0 -and $extra.Count -eq 0 -and $notReady.Count -eq 0)
    $detail = "ready $($ready.Count)/$($expectedStores.Count) [$((Sort-Ordinal $ready) -join ', ')]"
    if ($notReady.Count -gt 0) { $detail += " notReady [$((Sort-Ordinal $notReady) -join ', ')]" }
    if ($missing.Count -gt 0) { $detail += " missing [$((Sort-Ordinal $missing) -join ', ')]" }
    if ($extra.Count -gt 0) { $detail += " unexpected [$((Sort-Ordinal $extra) -join ', ')]" }
    if ($ok) {
        if ($noLtt.Count -gt 0) {
            $script:storeAnchor = $null
            $script:storeAnchorReason = "Ready condition lastTransitionTime missing/unparseable for [$((Sort-Ordinal $noLtt) -join ', ')]"
            $detail += " readyAnchor=unavailable ($($script:storeAnchorReason))"
        } else {
            $script:storeAnchor = $anchor
            $script:storeAnchorReason = ''
            $detail += " readyAnchor=$(Fmt-Utc $anchor) (max Ready lastTransitionTime, server time)"
        }
    }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-Argo {
    $r = Get-KubeItems @('-n', 'argocd', 'get', 'applications.argoproj.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $unhealthy = @()
    $outOfSync = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $h = "$(Get-Path $it @('status', 'health', 'status'))"
        $s = "$(Get-Path $it @('status', 'sync', 'status'))"
        if (-not (Eq $h 'Healthy')) { $unhealthy += "$n=$(if ($h) { $h } else { 'none' })" }
        if (-not (Eq $s 'Synced')) { $outOfSync += "$n=$(if ($s) { $s } else { 'none' })" }
    }
    $ok = ($items.Count -ge 1 -and $unhealthy.Count -eq 0)
    $detail = "applications $($items.Count), healthy $($items.Count - $unhealthy.Count)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($unhealthy.Count -gt 0) { $detail += " notHealthy [$((Sort-Ordinal $unhealthy) -join ', ')]" }
    if ($outOfSync.Count -gt 0) { $detail += " info: notSynced [$((Sort-Ordinal $outOfSync) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-ExternalSecrets {
    if ($null -eq $script:storeAnchor) {
        return @{ ok = $false; fatal = $false; final = $true; detail = "store Ready anchor unavailable ($($script:storeAnchorReason)); cannot prove a post-reboot refresh (fail closed)" }
    }
    $anchor = [DateTime]$script:storeAnchor
    $r = Get-KubeItems @('get', 'externalsecrets.external-secrets.io', '-A', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $notSynced = @()
    $noRefresh = @()
    $stale = @()
    $fresh = 0
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'namespace'))/$(Get-Path $it @('metadata', 'name'))"
        $c = Get-ReadyCondition $it
        $synced = ($null -ne $c -and (Eq "$($c['status'])" 'True') -and (Eq "$($c['reason'])" 'SecretSynced'))
        if (-not $synced) { $notSynced += "$n=$(if ($null -ne $c) { "$($c['reason'])/$($c['status'])" } else { 'none' })"; continue }
        $rt = Parse-Utc "$(Get-Path $it @('status', 'refreshTime'))"
        if ($null -eq $rt) { $noRefresh += $n }
        elseif ($rt -lt $anchor) { $stale += "$n=refreshTime $(Fmt-Utc $rt)" }
        else { $fresh++ }
    }
    $ok = ($items.Count -ge 1 -and $notSynced.Count -eq 0 -and $noRefresh.Count -eq 0 -and $stale.Count -eq 0)
    $detail = "externalsecrets $($items.Count), SecretSynced $($items.Count - $notSynced.Count), refreshed since store Ready anchor $(Fmt-Utc $anchor): $fresh"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($notSynced.Count -gt 0) { $detail += " notSynced [$((Sort-Ordinal $notSynced) -join ', ')]" }
    if ($noRefresh.Count -gt 0) { $detail += " refreshTime missing/unparseable [$((Sort-Ordinal $noRefresh) -join ', ')]" }
    if ($stale.Count -gt 0) { $detail += " refreshTime before anchor [$((Sort-Ordinal $stale) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

# ---------- 폴링 엔진(조건별 마감) ----------
# $conds 원소: @{ id; label; test=[scriptblock] → @{ok; detail; fatal; final}; after=<선행 id 또는 $null>; deadline=[scriptblock]($state) → 초 }
# 반환: id → @{ verdict; at; deadline; detail; checks }
#   verdict: pending | ok | late(마감 뒤 충족 관측) | expired(마감까지 미충족) | final(재폴링 무의미한 FAIL) | fatal | not-attempted
function Invoke-PollLoop([object[]]$conds) {
    $state = @{}
    foreach ($c in $conds) { $state[$c.id] = @{ verdict = 'pending'; at = $null; deadline = $null; detail = 'not checked'; checks = 0 } }
    while ($true) {
        foreach ($c in $conds) {
            $s = $state[$c.id]
            if (-not (Eq $s.verdict 'pending')) { continue }
            if ($null -ne $c.after) {
                $a = $state[$c.after]
                if (Eq $a.verdict 'pending') { continue }                                   # 선행 조건 대기(마감도 아직 미정)
                if (-not (Eq $a.verdict 'ok')) { $s.verdict = 'not-attempted'; $s.detail = "$($c.after) $($a.verdict)"; continue }
            }
            if ($null -eq $s.deadline) { $s.deadline = [double](& $c.deadline $state) }
            $r = & $c.test
            $t = Now
            $s.checks++
            $s.detail = [string]$r.detail
            if ($r.fatal) { $s.verdict = 'fatal'; $s.at = $t; return $state }
            if ($r.ok) {
                $s.at = $t
                if ($t -le $s.deadline) { $s.verdict = 'ok'; Write-Host "  [$(Sec $t)s] $($c.id) met -- $(Redact (Clip $r.detail 200))" }
                else { $s.verdict = 'late'; Write-Host "  [$(Sec $t)s] $($c.id) observed met AFTER its deadline ($(Sec $s.deadline)s) -- $(Redact (Clip $r.detail 200))" }
            } elseif ($r.final) { $s.verdict = 'final'; $s.at = $t }
            elseif ($t -gt $s.deadline) { $s.verdict = 'expired'; $s.at = $t }
        }
        $pending = @($conds | Where-Object { Eq $state[$_.id].verdict 'pending' })
        if ($pending.Count -eq 0) { return $state }
        $now = Now
        $nextDeadline = $null
        $parts = @()
        foreach ($c in $pending) {
            $s = $state[$c.id]
            if ($null -eq $s.deadline) { $parts += "$($c.id)(blocked by $($c.after))"; continue }
            if ($null -eq $nextDeadline -or $s.deadline -lt $nextDeadline) { $nextDeadline = $s.deadline }
            $parts += "$($c.id)(deadline $(Sec $s.deadline)s: $(Redact (Clip $s.detail 120)))"
        }
        Write-Host "  [$(Sec $now)s] waiting: $($parts -join '; ')"
        $sleep = [double]$pollIntervalSec
        if ($null -ne $nextDeadline) { $sleep = [Math]::Min($sleep, [Math]::Max(0.0, $nextDeadline - $now)) }   # 마감을 넘겨 자지 않는다
        if ($sleep -gt 0) { Start-Sleep -Milliseconds ([int][Math]::Ceiling($sleep * 1000)) }
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
        # 출력 마스킹 대상: 원문·해석 경로와 슬래시 방향 변형
        foreach ($v in @($env:KUBECONFIG, $kubeconfigPath)) {
            if ([string]::IsNullOrWhiteSpace($v)) { continue }
            $script:redact += $v
            $script:redact += $v.Replace('\', '/')
            $script:redact += $v.Replace('/', '\')
        }
    }
    Assert 'reboot-pre-2' 'KUBECONFIG set and file exists' $kubeconfigOk $kubeconfigWhy
    if ($script:fail -gt 0) { Finish }

    $fixed = { param($st) $phaseDeadlineSec }
    $conds = @(
        @{ id = 'reboot-0'; label = "API reachable and context user is $expectedUser"; test = { Test-Identity }; after = $null; deadline = $fixed },
        @{ id = 'reboot-1'; label = 'vault seal-status sealed=false type=ocikms (port-forward svc/vault)'; test = { Test-Vault }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-2'; label = "clustersecretstores exactly 5 and all Ready [$($expectedStores -join ', ')]"; test = { Test-Stores }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-3'; label = 'argocd applications all Healthy'; test = { Test-Argo }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-4'; label = "externalsecrets all SecretSynced with refreshTime >= store Ready anchor, within ${esRefreshSec}s after reboot-2"; test = { Test-ExternalSecrets }; after = 'reboot-2'; deadline = { param($st) $st['reboot-2'].at + $esRefreshSec } }
    )

    if (-not $AfterReboot) {
        # 평상시: 신원은 한 번만 확인(러너가 이미 통과시켰지만 단독 실행도 같은 경계를 지킨다), 재부팅 단언은 SKIP.
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        foreach ($c in $conds) { if (-not (Eq $c.id 'reboot-0')) { Skip $c.id $c.label } }
        Finish
    }

    Write-Host "polling reboot-0..4 (nominal interval ${pollIntervalSec}s; reboot-0..3 deadline ${phaseDeadlineSec}s from start; reboot-4 deadline = reboot-2 pass + ${esRefreshSec}s)"
    $st = Invoke-PollLoop $conds
    $fatalId = $null
    foreach ($c in $conds) { if (Eq $st[$c.id].verdict 'fatal') { $fatalId = $c.id } }
    foreach ($c in $conds) {
        $s = $st[$c.id]
        $rel = ''
        if ($null -ne $c.after -and $null -ne $s.at -and (Eq $st[$c.after].verdict 'ok')) { $rel = " (+$(Sec ($s.at - $st[$c.after].at))s after $($c.after))" }
        switch ($s.verdict) {
            'ok' { Assert $c.id $c.label $true "met at $(Sec $s.at)s (deadline $(Sec $s.deadline)s)$rel; $($s.detail)" }
            'late' { Assert $c.id $c.label $false "met late at $(Sec $s.at)s (deadline $(Sec $s.deadline)s)$rel; $($s.detail)" }
            'expired' { Assert $c.id $c.label $false "not met within $(Sec $s.deadline)s (last observation at $(Sec $s.at)s: $($s.detail))" }
            'final' { Assert $c.id $c.label $false "$($s.detail) (at $(Sec $s.at)s)" }
            'fatal' { Assert $c.id $c.label $false $s.detail }
            'not-attempted' { Assert $c.id $c.label $false "not attempted ($($s.detail))" }
            default { Assert $c.id $c.label $false "not attempted (aborted by $fatalId)" }
        }
    }
    Write-Host "polling ended at $(Sec (Now))s"
    Finish
} finally {
    if ($null -ne $script:pf) {
        Stop-Tree $script:pf
        Remove-TempFiles $script:pfFiles
    }
}
