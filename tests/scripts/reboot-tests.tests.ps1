# tests/platform/reboot.tests.ps1 하네스 단위 테스트(T048 선행 — "실제로 재부팅됐는가" 가드). Run: pwsh -NoProfile -File tests/scripts/reboot-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/run-platform-tests.tests.ps1와 같은 구조).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all의 reboot-harness 체크가 이 파일을 직접 실행한다).
# 방식: 케이스마다 임시 픽스처(%TEMP%/reboottest-<guid>)에 가짜 kubectl(bin/kubectl.cmd 심 → bin/fake-kubectl.ps1)·시나리오(scenario.json)·
#   더미 kubeconfig를 만들고, PATH 앞에 bin/을 끼워 실제 kubectl을 가린 채 하네스를 자식 pwsh로 실행한다(KUBECONFIG = 더미 파일,
#   TMP/TEMP = 픽스처 tmp/, 자식마다 시간 상한 — 넘기면 프로세스 트리째 종료). 실제 클러스터·실제 kubectl·~/.kube/에 닿지 않는다.
# 가짜 kubectl: 하네스가 쓰는 정확한 읽기 전용 인자 목록 6종(auth whoami · get nodes -l role=platform · clustersecretstores ·
#   applications · externalsecrets · port-forward svc/vault)만 인정하고, 그 밖의 호출은 'unexpected'로 기록한 뒤 실패한다.
#   시나리오는 단계(phase)의 목록이다. 단계는 `kubectl auth whoami` 호출 횟수(= 하네스의 reboot-0 폴링 라운드)로 넘어가므로
#   기계 속도와 무관하게 결정적이다. 단계 안에서는 종류별 호출 순번으로 응답 목록의 원소를 고른다(마지막 원소 반복) — 과도 상태
#   (API 불통 · sealed→unsealed · store NotReady→Ready · Application Progressing→Healthy · 옛 refreshTime→새 값)를 흉내 낸다.
#   port-forward는 실제로 127.0.0.1:<port>를 열고 'Forwarding from 127.0.0.1:<port> -> 8200'을 stdout에 쓴 뒤 /v1/sys/seal-status에
#   JSON으로 답한다(하네스가 프로세스 트리를 죽일 때까지; 안전장치로 60 s 뒤 스스로 끝난다).
#   모든 호출은 calls.log(JSON 줄: seq · elapsed(첫 호출 기준 초) · phase · kind · idx · code · served · args)에 남고 단언에 쓰인다.
#   단계별 첫 호출 시각은 state.json의 phaseFirstAt에 남는다. 가짜의 0초 = 첫 kubectl 호출이고 하네스의 0초(옛 부팅을 한 번도 못 봤으면
#   스크립트 시작)는 그보다 앞서므로, 하네스가 보고한 경과 초 >= 가짜가 기록한 같은 순간의 경과 초다(S12 · S32의 "단계 시작 이후" 단언의
#   근거). 하네스가 옛 부팅을 보면(armed) 0초가 그 관측의 시작으로 옮겨지므로 S2는 "마지막 옛 부팅 whoami" 기준으로 같은 단언을 한다.
#   가짜는 모든 조회에 --request-timeout=30s를 요구한다(H1 — 다른 값이면 'unexpected').
#   호출 단위의 실패(수정 지시서 6 — 하네스의 재시도 A): 단계의 whoamiFailAt / nodesFailAt = 그 단계 안에서 몇 번째(1부터) whoami / get nodes
#   호출이 "도달 실패"(실제 경로의 TLS handshake timeout 흉내, exit 1 — 기록의 served = transport-fail)인지. nodesDelayMs = 그 단계의 get nodes
#   응답을 늦춘다(느린 API — 관측 하나가 마감을 가로지르게). transportFailDelayMs = 그 단계의 도달 실패 응답만 늦춘다(실제 실패는 10 s쯤 걸린다).
#   하네스가 재시도한 whoami는 단계 진행에 한 번 더 세어지므로, 재시도가 일어나는 관측의
#   단계는 whoamiCalls에 그 몫을 더해 둔다(수정 전 하네스에서는 그 몫이 다음 관측이 된다).
#   Invoke-Harness는 실행마다 자식의 PATH에서 처음 찾히는 kubectl이 픽스처의 심(bin/kubectl.cmd)인지 확인하고, 아니면 하네스를 실행하지 않는다.
# 시간: 하네스 손잡이 REBOOT_TESTS_*로 간격을 1 s로 줄인다. 마감까지 기다려야 끝나는 케이스(expired)는 6–30 s, 마감 전에 끝나야 함을
#   단언하는 final 경로(S5a · S20)는 30 s, 성공하면 바로 끝나는 케이스(S2 · S5c · S12 · S16 · S21 · S23 · S37 · S38 · S40 · S41 · S42–S45 · S48–S51)는
#   20–60 s로 넉넉히 둔다(실행 시간을 늘리지 않으면서, 다른 프로세스가 같은 PC를 쓰는 부하에서도 흔들리지 않게). arm 시간 제한은 S1 · S47 · S52에서만
#   줄인다(S52는 굳은 상태가 제한을 넘길 만큼 불통 관측을 길게 둔다 — "관측 N번이 M초 안에"에 기대지 않게).
# 반복용 손잡이: REBOOT_HARNESS_TESTS_ONLY=S1,S3 → 그 케이스만 실행한다. 이때 요약 줄 끝에 ' (filtered: …)'가 붙어
#   run-all의 'N passed, 0 failed' 판정을 통과하지 못한다(부분 실행이 전체 통과로 보이지 않게).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$harnessPath = Join-Path $repo 'tests/platform/reboot.tests.ps1'
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$knobNames = @('REBOOT_TESTS_PHASE_DEADLINE_SEC', 'REBOOT_TESTS_ES_REFRESH_SEC', 'REBOOT_TESTS_POLL_INTERVAL_SEC', 'REBOOT_TESTS_ARM_TIMEOUT_SEC')
$sep = [IO.Path]::PathSeparator
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
if (-not [string]::IsNullOrWhiteSpace($env:REBOOT_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:REBOOT_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Has-Text([string]$s, [string]$needle) { return ($null -ne $s -and $s.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }

# 케이스 격리 + 선택 실행. 한 케이스에서 예외가 나도 나머지는 계속 실행된다.
function Test-Case([string]$id, [string]$title, [scriptblock]$body) {
    $script:known += $id
    if ($script:only.Count -gt 0 -and @($script:only | Where-Object { Test-Same $_ $id }).Count -eq 0) { return }
    Write-Host "-- ${id}: $title"
    $caseWatch = [Diagnostics.Stopwatch]::StartNew()
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $id -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    # 케이스별 걸린 시간(진단용 — 실행 시간을 줄일 곳을 찾는 데 쓴다; PASS/FAIL·요약 줄 형식과 겹치지 않는다)
    Write-Host "   [$id took $($caseWatch.Elapsed.TotalSeconds.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))s]"
}

# ---------- 가짜 kubectl(픽스처 bin/fake-kubectl.ps1로 쓴다) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/reboot-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
# 입력: ..\scenario.json(단계 목록) · 상태: ..\state.json(..\state.lock 배타 잠금 아래에서만 읽고 쓴다) · 기록: ..\calls.log(JSON 줄)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$lockPath = Join-Path $root 'state.lock'
$statePath = Join-Path $root 'state.json'
$logPath = Join-Path $root 'calls.log'
$utf8 = [Text.UTF8Encoding]::new($false)
$scn = [IO.File]::ReadAllText((Join-Path $root 'scenario.json')) | ConvertFrom-Json -AsHashtable -DateKind String
$phases = @($scn['phases'])
$a = @($args | ForEach-Object { "$_" })
$rt = '--request-timeout=30s'

function Eq([string]$x, [string]$y) { return [string]::Equals($x, $y, [StringComparison]::Ordinal) }
function Same([object[]]$x, [object[]]$y) {
    if ($x.Count -ne $y.Count) { return $false }
    for ($i = 0; $i -lt $x.Count; $i++) { if (-not (Eq "$($x[$i])" "$($y[$i])")) { return $false } }
    return $true
}
# 응답 목록에서 i번째(1부터) 원소 — 목록보다 길면 마지막 원소를 반복한다
function Pick($list, [int]$i) {
    $l = @($list | Where-Object { $null -ne $_ })
    if ($l.Count -eq 0) { return $null }
    return $l[[Math]::Min($i, $l.Count) - 1]
}
function Open-Lock {
    $until = [DateTime]::UtcNow.AddSeconds(15)
    while ($true) {
        try { return [IO.FileStream]::new($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
        catch { if ([DateTime]::UtcNow -gt $until) { throw }; Start-Sleep -Milliseconds 20 }
    }
}
# whoami 호출 횟수 → 단계 번호(마지막 단계는 끝까지 유지)
function Get-PhaseIndex([int]$whoamiCount) {
    $acc = 0
    for ($i = 0; $i -lt $phases.Count - 1; $i++) {
        $acc += [int]$phases[$i]['whoamiCalls']
        if ($whoamiCount -le $acc) { return $i }
    }
    return $phases.Count - 1
}
function New-Json($o) { return ($o | ConvertTo-Json -Depth 20 -Compress) }
function Write-CallLog($entry) { [IO.File]::AppendAllText($logPath, (New-Json $entry) + "`n", $utf8) }

# 호출 종류: 정확한 인자 목록만 인정한다(다른 동사·인자 = unexpected)
$kind = 'unexpected'
$pfPort = 0
if (Same $a @('auth', 'whoami', '-o', 'json', $rt)) { $kind = 'whoami' }
elseif (Same $a @('get', 'nodes', '-l', 'role=platform', '-o', 'json', $rt)) { $kind = 'nodes' }
elseif (Same $a @('get', 'clustersecretstores.external-secrets.io', '-o', 'json', $rt)) { $kind = 'stores' }
elseif (Same $a @('-n', 'argocd', 'get', 'applications.argoproj.io', '-o', 'json', $rt)) { $kind = 'apps' }
elseif (Same $a @('get', 'externalsecrets.external-secrets.io', '-A', '-o', 'json', $rt)) { $kind = 'es' }
elseif ($a.Count -eq 7 -and (Same $a[0..3] @('-n', 'vault', 'port-forward', 'svc/vault')) -and (Same $a[5..6] @('--address', '127.0.0.1')) -and [regex]::IsMatch($a[4], '\A[0-9]{1,5}:8200\z')) {
    $kind = 'pf'
    $pfPort = [int]($a[4].Split(':')[0])
}

$resp = @{ out = $null; err = $null; code = 0; served = ''; sealed = $false; delay = 0.0 }
$lock = Open-Lock
try {
    $st = $null
    if (Test-Path -LiteralPath $statePath) { $st = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json -AsHashtable }
    if ($null -eq $st) { $st = @{ t0 = [DateTime]::UtcNow.Ticks; seq = 0; whoami = 0; phase = 0; counts = @{}; phaseFirstAt = @{} } }
    $st['seq'] = [int]$st['seq'] + 1
    if (Eq $kind 'whoami') {
        $st['whoami'] = [int]$st['whoami'] + 1
        $st['phase'] = Get-PhaseIndex ([int]$st['whoami'])
    }
    $pi = [int]$st['phase']
    $t0 = [long]$st['t0']
    $elapsed = [Math]::Round(([DateTime]::UtcNow.Ticks - $t0) / 1e7, 3)
    if (-not $st['phaseFirstAt'].ContainsKey("$pi")) { $st['phaseFirstAt']["$pi"] = $elapsed }
    $ck = "${pi}:$kind"
    $idx = 1
    if ($st['counts'].ContainsKey($ck)) { $idx = [int]$st['counts'][$ck] + 1 }
    $st['counts'][$ck] = $idx
    $ph = $phases[$pi]

    if (Eq $kind 'unexpected') {
        $resp.err = "fake-kubectl: unexpected invocation: $($a -join ' ')"; $resp.code = 97; $resp.served = 'unexpected'
    } elseif (Eq "$($ph['api'])" 'down') {
        $resp.err = 'Unable to connect to the server: dial tcp 10.0.0.10:6443: connectex: No connection could be made because the target machine actively refused it.'
        $resp.code = 1; $resp.served = 'api-down'
    } elseif (((Eq $kind 'whoami') -and (@($ph['whoamiFailAt']) -contains $idx)) -or ((Eq $kind 'nodes') -and (@($ph['nodesFailAt']) -contains $idx))) {
        # 호출 단위의 도달 실패(이 단계의 idx번째 whoami / get nodes만): 실제 경로에서 가끔 10 s쯤 걸려 실패하는 TLS 핸드셰이크 시간 초과 흉내
        $resp.err = 'Unable to connect to the server: net/http: TLS handshake timeout'
        $resp.code = 1; $resp.served = 'transport-fail'
    } elseif (Eq $kind 'whoami') {
        if ([bool]$ph['whoamiUnauthorized']) {
            $resp.err = 'error: You must be logged in to the server (Unauthorized)'; $resp.code = 1; $resp.served = 'unauthorized'
        } else {
            $resp.out = New-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = @{ userInfo = @{ username = "$($ph['user'])"; groups = @('system:serviceaccounts', 'system:authenticated') } } })
            $resp.served = "user=$($ph['user'])"
        }
    } elseif (Eq $kind 'nodes') {
        if ([int]$ph['nodesExit'] -ne 0) {
            $resp.err = 'Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes)'
            $resp.code = [int]$ph['nodesExit']; $resp.served = "nodes-exit=$($ph['nodesExit'])"
        } elseif ($null -ne $ph['nodesRaw']) {
            $resp.out = "$($ph['nodesRaw'])"; $resp.served = 'nodes-raw'
        } else {
            $specs = @($ph['nodes'] | Where-Object { $null -ne $_ })
            $items = @(foreach ($n in $specs) {
                    $ni = [ordered]@{ architecture = 'arm64'; kubeletVersion = 'v1.36.4+k3s1'; osImage = 'Ubuntu 24.04.3 LTS' }
                    if ($null -ne $n['bootID']) { $ni['bootID'] = $n['bootID'] }
                    # Ready 조건: heartbeat가 없으면 lastHeartbeatTime을 뺀다(부팅 anchor 부재 시나리오)
                    $cond = [ordered]@{ type = 'Ready'; status = "$($n['ready'])"; reason = 'KubeletReady'; lastTransitionTime = '2026-01-01T00:00:00Z' }
                    if ($null -ne $n['heartbeat']) { $cond['lastHeartbeatTime'] = "$($n['heartbeat'])" }
                    [ordered]@{
                        apiVersion = 'v1'; kind = 'Node'
                        metadata   = [ordered]@{ name = "$($n['name'])"; labels = @{ role = 'platform' } }
                        status     = [ordered]@{ conditions = @($cond); nodeInfo = $ni }
                    }
                })
            $resp.out = New-Json ([ordered]@{ apiVersion = 'v1'; kind = 'List'; items = $items; metadata = @{ resourceVersion = '' } })
            $resp.served = "nodes=$($specs.Count) names=$((@($specs | ForEach-Object { "$($_['name'])" })) -join ',') bootIDs=$((@($specs | ForEach-Object { if ($null -ne $_['bootID']) { "$($_['bootID'])" } else { '<none>' } })) -join ',') ready=$((@($specs | ForEach-Object { "$($_['ready'])" })) -join ',')"
        }
    } elseif (Eq $kind 'stores') {
        $e = Pick $ph['stores'] $idx
        $ready = [bool]$e['ready']
        # 경과 시간 기반 ES 응답의 기준점: 가짜가 처음으로 "store 전부 Ready"를 답한 시각(= 하네스가 reboot-2를 통과하는 관측)
        if ($ready -and -not $st.ContainsKey('storesReadyAt')) { $st['storesReadyAt'] = $elapsed }
        $items = @(foreach ($nm in @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')) {
                $ok = $ready -or -not $nm.StartsWith('vault-', [StringComparison]::Ordinal)
                $cond = if ($ok) { @{ type = 'Ready'; status = 'True'; reason = 'Valid'; message = 'store validated'; lastTransitionTime = "$($e['ltt'])" } }
                else { @{ type = 'Ready'; status = 'False'; reason = 'ValidationFailed'; message = 'unable to validate store'; lastTransitionTime = "$($e['ltt'])" } }
                [ordered]@{ apiVersion = 'external-secrets.io/v1'; kind = 'ClusterSecretStore'; metadata = @{ name = $nm }; status = @{ conditions = @($cond) } }
            })
        $resp.out = New-Json ([ordered]@{ apiVersion = 'v1'; kind = 'List'; items = $items })
        $resp.served = "ready=$ready ltt=$($e['ltt'])"
    } elseif (Eq $kind 'apps') {
        $h = "$(Pick $ph['apps'] $idx)"
        $items = @(foreach ($nm in @('platform-root', 'vault', 'external-secrets')) {
                $hh = if (Eq $nm 'vault') { $h } else { 'Healthy' }
                [ordered]@{ apiVersion = 'argoproj.io/v1alpha1'; kind = 'Application'; metadata = @{ name = $nm; namespace = 'argocd' }; status = @{ health = @{ status = $hh }; sync = @{ status = 'Synced' } } }
            })
        $resp.out = New-Json ([ordered]@{ apiVersion = 'v1'; kind = 'List'; items = $items })
        $resp.served = "vault=$h"
    } elseif (Eq $kind 'es') {
        $rtime = "$(Pick $ph['es'] $idx)"
        # 경과 시간 기반(F1 마감 경계): storesReadyAt + esFreshAfterStoresSec 이전에는 esStale, 이후에는 esFresh
        if ($null -ne $ph['esFreshAfterStoresSec']) {
            $isFresh = $st.ContainsKey('storesReadyAt') -and (($elapsed - [double]$st['storesReadyAt']) -ge [double]$ph['esFreshAfterStoresSec'])
            $rtime = if ($isFresh) { "$($ph['esFresh'])" } else { "$($ph['esStale'])" }
        }
        $items = @(foreach ($pair in @(@('platform', 'cloudflared-token'), @('identity', 'authentik-env'))) {
                [ordered]@{ apiVersion = 'external-secrets.io/v1'; kind = 'ExternalSecret'; metadata = @{ namespace = $pair[0]; name = $pair[1] }; status = @{ refreshTime = $rtime; conditions = @(@{ type = 'Ready'; status = 'True'; reason = 'SecretSynced'; lastTransitionTime = $rtime }) } }
            })
        $resp.out = New-Json ([ordered]@{ apiVersion = 'v1'; kind = 'List'; items = $items })
        $resp.served = "refreshTime=$rtime"
    } elseif (Eq $kind 'pf') {
        $v = Pick $ph['vault'] $idx
        $resp.sealed = [bool]$v['sealed']
        if ($null -ne $v['establishDelaySec']) { $resp.delay = [double]$v['establishDelaySec'] }
        $resp.served = "sealed=$($resp.sealed) port=$pfPort establishDelay=$($resp.delay)s"
        if ([bool]$v['exitImmediately']) {
            # 곧바로 죽는 port-forward(파드 없음 · 엔드포인트 없음 흉내)
            $resp.err = 'error: unable to forward port because pod is not running. Current status=Pending'
            $resp.code = 1
            $resp.served = "exit-immediately port=$pfPort"
        }
    }
    [IO.File]::WriteAllText($statePath, (New-Json $st), $utf8)
    Write-CallLog ([ordered]@{ seq = $st['seq']; elapsed = $elapsed; phase = $pi; phaseName = "$($ph['name'])"; kind = $kind; idx = $idx; code = $resp.code; served = $resp.served; args = ($a -join ' ') })
} finally {
    $lock.Dispose()
}

# 느린 API 흉내(F1): ES 응답을 잠금 밖에서 늦춘다 — 관측 하나가 마감을 가로지르게 한다
if ((Eq $kind 'es') -and $null -ne $ph['esDelayMs']) { Start-Sleep -Milliseconds ([int]$ph['esDelayMs']) }
# 느린 get nodes(B-1): reboot-0 관측 하나가 마감을 가로지르게 한다
if ((Eq $kind 'nodes') -and $null -ne $ph['nodesDelayMs'] -and [int]$ph['nodesDelayMs'] -gt 0) { Start-Sleep -Milliseconds ([int]$ph['nodesDelayMs']) }
# 느린 도달 실패(S53): 실제 경로의 실패는 10 s쯤 걸린다(TLS 핸드셰이크 시간 초과) — transport-fail 응답만 늦춘다
if ((Eq $resp.served 'transport-fail') -and $null -ne $ph['transportFailDelayMs'] -and [int]$ph['transportFailDelayMs'] -gt 0) { Start-Sleep -Milliseconds ([int]$ph['transportFailDelayMs']) }
if ($null -ne $resp.err) { [Console]::Error.WriteLine($resp.err) }
if (-not (Eq $kind 'pf') -or $resp.code -ne 0) {
    if ($null -ne $resp.out) { [Console]::Out.WriteLine($resp.out) }
    exit $resp.code
}

# port-forward: 실제로 로컬 포트를 열고 seal-status에 답한다(죽을 때까지; 안전장치 60 s)
#   수립 지연(G3): 실제 kubectl은 API 서버(터널 너머)와 연결을 맺은 뒤에야 로컬 포트를 열고 'Forwarding from' 줄을 낸다 —
#   그동안에는 리스너도 줄도 없다(실측 10–23 s). establishDelaySec만큼 그 상태로 있다가 연다.
if ($resp.delay -gt 0) { Start-Sleep -Milliseconds ([int][Math]::Round($resp.delay * 1000)) }
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $pfPort)
try { $listener.Start() } catch { [Console]::Error.WriteLine("error: unable to listen on 127.0.0.1:${pfPort}: $($_.Exception.Message)"); exit 1 }
[Console]::Out.WriteLine("Forwarding from 127.0.0.1:$pfPort -> 8200")
[Console]::Out.Flush()
$lk = Open-Lock
try { Write-CallLog ([ordered]@{ seq = 0; elapsed = [Math]::Round(([DateTime]::UtcNow.Ticks - $t0) / 1e7, 3); phase = $pi; phaseName = "$($ph['name'])"; kind = 'pf-ready'; idx = $idx; code = 0; served = "forwarding port=$pfPort after establishDelay=$($resp.delay)s"; args = '' }) }
finally { $lk.Dispose() }
$body = New-Json ([ordered]@{ type = 'ocikms'; initialized = $true; sealed = $resp.sealed; t = 1; n = 1; progress = 0; nonce = ''; version = '2.0.4'; migration = $false; recovery_seal = $true; storage_type = 'raft' })
$until = [DateTime]::UtcNow.AddSeconds(60)
while ([DateTime]::UtcNow -lt $until) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 25; continue }
    $c = $listener.AcceptTcpClient()
    try {
        $s = $c.GetStream()
        $s.ReadTimeout = 5000
        $buf = [byte[]]::new(4096)
        $req = ''
        while ($req.IndexOf("`r`n`r`n", [StringComparison]::Ordinal) -lt 0 -and $req.Length -lt 65536) {
            $n = $s.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $req += [Text.Encoding]::ASCII.GetString($buf, 0, $n)
        }
        $line0 = ($req -split "`r`n")[0]
        $okPath = $line0.StartsWith('GET /v1/sys/seal-status ', [StringComparison]::Ordinal)
        # 응답 전에 기록한다(하네스가 응답 직후 프로세스를 죽여도 기록 줄이 잘리지 않게)
        $lk = Open-Lock
        try { Write-CallLog ([ordered]@{ seq = 0; elapsed = [Math]::Round(([DateTime]::UtcNow.Ticks - $t0) / 1e7, 3); phase = $pi; phaseName = "$($ph['name'])"; kind = 'pf-http'; idx = $idx; code = $(if ($okPath) { 200 } else { 404 }); served = "sealed=$($resp.sealed) request=$line0"; args = '' }) }
        finally { $lk.Dispose() }
        $payload = [Text.Encoding]::ASCII.GetBytes($(if ($okPath) { $body } else { '{"errors":["fake: not found"]}' }))
        $status = if ($okPath) { '200 OK' } else { '404 Not Found' }
        $hdr = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 $status`r`nContent-Type: application/json`r`nContent-Length: $($payload.Length)`r`nConnection: close`r`n`r`n")
        $s.Write($hdr, 0, $hdr.Length)
        $s.Write($payload, 0, $payload.Length)
        $s.Flush()
    } catch { } finally { $c.Close() }
}
$listener.Stop()
exit 0
'@

# kubectl.cmd 심: CRLF, BOM 없음(@echo off가 1행이어야 한다). 현재 pwsh로 가짜 스크립트를 실행하고 종료 코드를 그대로 돌려준다.
$crlf = "`r`n"
$shimBody = (@(
        '@echo off'
        "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0fake-kubectl.ps1`" %*"
        'exit /b %ERRORLEVEL%'
    ) -join $crlf) + $crlf
$kubeconfigYaml = "apiVersion: v1`nkind: Config`n"

# ---------- 시나리오 조각 ----------
$oldBoot = 'a1b2c3d4-0000-4000-8000-000000000001'   # 재부팅 전(= -Baseline이 적어 둔 값)
$newBoot = 'e5f6a7b8-0000-4000-8000-000000000002'   # 재부팅 뒤
$preLtt = '2026-01-01T00:00:00Z'                    # 재부팅 전 store Ready 전이 시각(서버 시각)
$preRefresh = '2026-01-01T00:05:00Z'                # 재부팅 전 ES refreshTime — 옛 anchor보다 뒤라, 재부팅 전 상태만 보면 reboot-4도 통과한다
$postNotReadyLtt = '2026-01-01T01:00:00Z'
$postLtt = '2026-01-01T01:00:30Z'                   # 재부팅 뒤 store Ready 전이 시각 = 새 store anchor
$postRefresh = '2026-01-01T01:01:00Z'               # 재부팅 뒤 refresh(두 anchor 모두 이후)
$preHeartbeat = '2026-01-01T00:00:10Z'              # 재부팅 전 노드 Ready lastHeartbeatTime
$postHeartbeat = '2026-01-01T01:00:05Z'             # 재부팅 뒤(새 bootID를 쓴 kubelet) Ready lastHeartbeatTime = 부팅 anchor

# 단계 하나(기본 = 재부팅 뒤 · 전부 건강). whoamiCalls = 이 단계가 차지하는 whoami 호출 수(마지막 단계는 무시 — 끝까지 유지)
function New-Phase([hashtable]$o = @{}) {
    $p = [ordered]@{
        name = 'post-reboot'; whoamiCalls = 0; api = 'up'; user = $expectedUser; whoamiUnauthorized = $false
        nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'True'; heartbeat = $postHeartbeat })
        nodesExit = 0; nodesRaw = $null
        whoamiFailAt = @(); nodesFailAt = @(); nodesDelayMs = 0; transportFailDelayMs = 0   # 호출 단위의 도달 실패(단계 안의 순번 목록) · 느린 get nodes · 느린 도달 실패(ms)
        vault = @(@{ sealed = $false })
        stores = @(@{ ready = $true; ltt = $postLtt })
        apps = @('Healthy')
        es = @($postRefresh)
    }
    foreach ($k in $o.Keys) { $p[$k] = $o[$k] }
    return $p
}
# 재부팅 전 단계(옛 bootID · 전부 건강 — 옛 anchor 기준으로는 ES도 신선하다)
function New-PrePhase([hashtable]$o = @{}) {
    $base = @{ name = 'pre-reboot'; nodes = @(@{ name = 'jt-node-a'; bootID = $oldBoot; ready = 'True'; heartbeat = $preHeartbeat }); stores = @(@{ ready = $true; ltt = $preLtt }); es = @($preRefresh) }
    foreach ($k in $o.Keys) { $base[$k] = $o[$k] }
    return New-Phase $base
}
function Knobs([int]$deadline, [int]$es, [int]$interval = 1, [int]$arm = 0) {
    $k = @{ REBOOT_TESTS_PHASE_DEADLINE_SEC = "$deadline"; REBOOT_TESTS_ES_REFRESH_SEC = "$es"; REBOOT_TESTS_POLL_INTERVAL_SEC = "$interval" }
    if ($arm -gt 0) { $k['REBOOT_TESTS_ARM_TIMEOUT_SEC'] = "$arm" }   # arm 시간 제한(초) — 0이면 기본값(30분)
    return $k
}
# 진행 줄 · 요약 앞 줄(H2 — 0초 기준점)
$zeroScriptStartLine = '  zero point = script start (the old boot was never observed)'
function Get-ArmedLines($r) { return @(@(Get-Lines $r) | Where-Object { $_.StartsWith('  armed: old boot still up (bootID unchanged) -- zero point moves with each observation; waiting for the reboot (arm timeout in ', [StringComparison]::Ordinal) }) }
# '  zero point fixed at <UTC> (last observation of the old boot); deadlines count from here' 줄들의 <UTC>
function Get-FixedZeros($r) {
    return @(@(Get-Lines $r) | ForEach-Object { $m = [regex]::Match($_, '\A  zero point fixed at (\S+) \(last observation of the old boot\); deadlines count from here\z'); if ($m.Success) { $m.Groups[1].Value } })
}
# J1: '  old boot seen again after the zero point was fixed (1 of 3 needed to move it again); zero point stays at <UTC>' 줄들의 <UTC>
function Get-StayZeros($r) {
    return @(@(Get-Lines $r) | ForEach-Object { $m = [regex]::Match($_, '\A  old boot seen again after the zero point was fixed \(1 of 3 needed to move it again\); zero point stays at (\S+)\z'); if ($m.Success) { $m.Groups[1].Value } })
}
# J1: 세 번째 연속 관측에서 기준점이 다시 움직일 때의 note 줄
function Get-RearmNotes($r) { return @(@(Get-Lines $r) | Where-Object { $_.StartsWith('  note: the old boot was seen 3 times in a row after the zero point had been fixed', [StringComparison]::Ordinal) }) }
# A(수정 지시서 6): '  retried: …' 진행 줄(구간마다 첫 재시도에 한 줄, 그 뒤로는 최대 60초에 한 줄)
function Get-RetryLines($r) { return @(@(Get-Lines $r) | Where-Object { $_.StartsWith('  retried: ', [StringComparison]::Ordinal) }) }
# A: reboot-0 waiting 줄 가운데 detail이 'retried: '로 시작하는 것(재시도한 관측의 detail은 120자로 잘려도 그 표시가 맨 앞에 남는다)
function Get-RetriedWaits($r) { return @(@(Get-Lines $r) | Where-Object { [regex]::IsMatch($_, '\A  \[\d+s\] waiting: reboot-0\(deadline \d+s: retried: ') }) }
# E(수정 지시서 6): 줄 안의 'observation UTC <시작> .. <끝>'(밀리초 · Z) → @{ start; end }(DateTime UTC). 없거나 형식이 다르면 $null
function Get-ObsUtc([string]$line) {
    $m = [regex]::Match("$line", 'observation UTC (\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z) \.\. (\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z)')
    if (-not $m.Success) { return $null }
    $a = Parse-ZeroUtc $m.Groups[1].Value
    $b = Parse-ZeroUtc $m.Groups[2].Value
    if ($null -eq $a -or $null -eq $b) { return $null }
    return @{ start = $a; end = $b }
}
# B(수정 지시서 6): 굳은 채 재부팅 전에 만료된 reboot-0 FAIL 줄에 덧붙는 문구(기준점 UTC · 근거 뒤)
$bText = 'the old boot kept being seen after that but never 3 times in a row -- no reboot was observed; restart the harness'
# 줄 목록에서 조건을 만족하는 줄의 위치(0부터)
function Get-LineIndexes($r, [scriptblock]$pred) {
    $lines = @(Get-Lines $r)
    return @(for ($i = 0; $i -lt $lines.Count; $i++) { if (& $pred $lines[$i]) { $i } })
}
# 하네스가 찍은 기준점 UTC(밀리초, ...Z) → DateTime(UTC). 형식이 다르면 $null
function Parse-ZeroUtc([string]$s) {
    $d = [DateTime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([DateTime]::TryParseExact("$s", "yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return $d }
    return $null
}
# 가짜의 0초(첫 kubectl 호출)의 UTC — state.json의 t0(ticks). 호출 기록 하나의 UTC = 이 값 + 그 기록의 elapsed
function Get-FakeT0Utc([string]$dir) {
    $p = Join-Path $dir 'state.json'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    return [DateTime]::new([long](([IO.File]::ReadAllText($p) | ConvertFrom-Json -AsHashtable)['t0']), [DateTimeKind]::Utc)
}
function Get-CallUtc($t0Utc, $call) { return $t0Utc.AddSeconds([double]$call['elapsed']) }
# 'zero point (UTC): <UTC> (<why>)' 줄 → @{ utc; why } (없으면 $null)
function Get-ZeroSummary($r) {
    foreach ($l in @(Get-Lines $r)) {
        $m = [regex]::Match($l, '\Azero point \(UTC\): (\S+) \((last observation of the old boot|script start)\)\z')
        if ($m.Success) { return @{ utc = $m.Groups[1].Value; why = $m.Groups[2].Value } }
    }
    return $null
}

# ---------- 픽스처 ----------
function New-Fixture([object[]]$phases) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('reboottest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    $utf8 = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText((Join-Path $dir 'scenario.json'), (@{ phases = @($phases) } | ConvertTo-Json -Depth 20), $utf8)
    New-Item -ItemType Directory -Path (Join-Path $dir 'bin') | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'tmp') | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'kubeconfig.yaml'), $kubeconfigYaml, $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/kubectl.cmd'), $shimBody, $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-kubectl.ps1'), $fakeKubectl, $utf8)
    return $dir
}

# 이 실행이 만든 reboottest-* 디렉터리만, scenario.json이 있는지 확인하고 지운다
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('reboottest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'scenario.json') -PathType Leaf)) {
            Write-Host "NOTE: not removing unrecognized fixture path $f"
            continue
        }
        for ($i = 0; $i -lt 5; $i++) {
            Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path -LiteralPath $f)) { break }
            Start-Sleep -Milliseconds 400
        }
    }
    $script:fixtures = @()
}

# 하네스를 자식 pwsh로 실행한다. 환경은 자식에게만 준다(이 프로세스의 환경은 바꾸지 않는다).
#   주변 환경의 REBOOT_TESTS_* 손잡이는 지우고, $knobs에 있는 것만 넣는다. 시간 상한을 넘기면 트리째 종료하고 timedOut=$true.
#   $kubeconfig: ''이면 픽스처의 kubeconfig.yaml(기본), 아니면 그 경로(R6 — 경로 마스킹 케이스)
# 자식의 PATH에서 처음 찾히는 kubectl(PATHEXT 순서) — 실제 kubectl을 가리는지 실행마다 확인하는 데 쓴다
function Find-FirstKubectl([string]$pathValue) {
    $exts = @('') + @("$env:PATHEXT".Split(';') | Where-Object { $_.Length -gt 0 })
    foreach ($p in "$pathValue".Split($sep)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        foreach ($e in $exts) {
            $cand = Join-Path $p ('kubectl' + $e)
            if (Test-Path -LiteralPath $cand -PathType Leaf) { return $cand }
        }
    }
    return $null
}
function Invoke-Harness([string]$dir, [string[]]$harnessArgs = @(), [hashtable]$knobs = @{}, [int]$timeoutSec = 60, [string]$kubeconfig = '') {
    if (-not (Test-Path -LiteralPath $harnessPath -PathType Leaf)) { return @{ out = "<missing harness: $harnessPath>"; err = ''; code = 127; wall = 0.0; timedOut = $false } }
    $psi = [Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    foreach ($x in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $harnessPath) + @($harnessArgs)) { $psi.ArgumentList.Add([string]$x) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['KUBECONFIG'] = if ([string]::IsNullOrEmpty($kubeconfig)) { Join-Path $dir 'kubeconfig.yaml' } else { $kubeconfig }
    $psi.Environment['PATH'] = (Join-Path $dir 'bin') + $sep + $env:PATH
    # 실행마다 확인: 자식이 처음 찾는 kubectl이 픽스처의 심이 아니면(실제 kubectl에 닿을 수 있으면) 하네스를 실행하지 않는다.
    #   Windows 경로는 대소문자를 가리지 않는다(PATHEXT는 '.CMD') — 경로 비교만 OrdinalIgnoreCase(문화권 비교는 아니다)
    $firstKubectl = Find-FirstKubectl $psi.Environment['PATH']
    if (-not [string]::Equals($firstKubectl, (Join-Path (Join-Path $dir 'bin') 'kubectl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first kubectl on the child PATH is '$firstKubectl', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    $psi.Environment['TMP'] = Join-Path $dir 'tmp'
    $psi.Environment['TEMP'] = Join-Path $dir 'tmp'
    foreach ($k in $knobNames) { [void]$psi.Environment.Remove($k) }
    foreach ($k in $knobs.Keys) { $psi.Environment[$k] = [string]$knobs[$k] }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = [Diagnostics.Process]::Start($psi)
    $ot = $p.StandardOutput.ReadToEndAsync()
    $et = $p.StandardError.ReadToEndAsync()
    $timedOut = -not $p.WaitForExit($timeoutSec * 1000)
    if ($timedOut) {
        try { $p.Kill($true) } catch { }
        $null = $p.WaitForExit(10000)
    } else { $p.WaitForExit() }
    $null = $ot.Wait(15000)
    $null = $et.Wait(15000)
    $wall = $sw.Elapsed.TotalSeconds
    $code = if ($timedOut) { 124 } else { $p.ExitCode }
    $out = if ($ot.IsCompleted) { $ot.Result } else { '<stdout not drained>' }
    $err = if ($et.IsCompleted) { $et.Result } else { '<stderr not drained>' }
    $p.Dispose()
    return @{ out = ($out -replace "`r`n", "`n"); err = ($err -replace "`r`n", "`n"); code = $code; wall = $wall; timedOut = $timedOut }
}

# ---------- 결과 · 호출 기록 도우미(배열을 돌려주는 함수는 호출부에서 항상 @()로 감싼다) ----------
function Get-Lines($r) { return @(($r.out.TrimEnd("`n")) -split "`n") }
function Lines-Starting($r, [string]$prefix) { return @(@(Get-Lines $r) | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }) }
function Has-Line($r, [string]$line) { return (@(@(Get-Lines $r) | Where-Object { Test-Same $_ $line }).Count -ge 1) }
# "  [Ns] <id> met -- …" 줄의 N(없으면 $null)
function Get-MetSec($r, [string]$id) {
    foreach ($l in @(Get-Lines $r)) {
        $m = [regex]::Match($l, '\A  \[(\d+)s\] ' + [regex]::Escape($id) + ' met -- ')
        if ($m.Success) { return [int]$m.Groups[1].Value }
    }
    return $null
}
function Get-EndSec($r) {
    foreach ($l in @(Get-Lines $r)) {
        $m = [regex]::Match($l, '\Apolling ended at (\d+)s\z')
        if ($m.Success) { return [int]$m.Groups[1].Value }
    }
    return $null
}
function Format-Result($r) {
    $lines = @(Get-Lines $r)
    $tail = if ($lines.Count -gt 25) { @('...') + $lines[($lines.Count - 25)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
}
function Get-Calls([string]$dir) {
    $p = Join-Path $dir 'calls.log'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @() }
    return @([IO.File]::ReadAllLines($p) | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { $_ | ConvertFrom-Json -AsHashtable -DateKind String })
}
function Get-CallsOf($calls, [string]$kind, $phase = $null) {
    return @(@($calls) | Where-Object { $null -ne $_ -and (Test-Same "$($_['kind'])" $kind) -and ($null -eq $phase -or [int]$_['phase'] -eq [int]$phase) })
}
function Count-Calls($calls, [string]$kind, $phase = $null) { return @(Get-CallsOf $calls $kind $phase).Count }
function Format-Calls($calls) {
    return 'calls=[' + ((@(@($calls) | Select-Object -First 60 | ForEach-Object { "#$($_['seq']) p$($_['phase']) $($_['kind'])#$($_['idx']) code=$($_['code']) $($_['served'])" })) -join ' | ') + ']'
}
# 단계 i의 첫 호출 시각(가짜 기준 경과 초; 그 단계에 도달하지 않았으면 $null)
function Get-PhaseStart([string]$dir, [int]$i) {
    $p = Join-Path $dir 'state.json'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    $m = ([IO.File]::ReadAllText($p) | ConvertFrom-Json -AsHashtable)['phaseFirstAt']
    if ($null -eq $m -or -not $m.ContainsKey("$i")) { return $null }
    return [double]$m["$i"]
}

# 공통 단언: 하네스가 끝까지 돌았다(요약 줄이 마지막) · 가짜가 모르는 kubectl 호출이 없다(읽기 전용 인자 목록만)
function Assert-Completed([string]$id, $r, $calls) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    Assert "${id}-end: harness ran to completion (no timeout; last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and [regex]::IsMatch($last, '\A\d+ passed, \d+ failed, \d+ skipped\z')) (Format-Result $r)
    $unexpected = @(Get-CallsOf $calls 'unexpected')
    Assert "${id}-ro: every kubectl call used an expected read-only argument list" ($unexpected.Count -eq 0) ("unexpected: " + ((@($unexpected | ForEach-Object { $_['args'] })) -join ' || '))
}
# reboot-1..4: PASS 줄이 없고 각각 정확히 하나의 'not attempted' FAIL
function Assert-NotAttempted([string]$id, $r) {
    $bad = @()
    foreach ($n in 1..4) {
        if (@(Lines-Starting $r "PASS reboot-${n}:").Count -ne 0) { $bad += "PASS reboot-$n present" }
        $fl = @(Lines-Starting $r "FAIL reboot-${n}:")
        if ($fl.Count -ne 1 -or -not (Has-Text $fl[0] 'not attempted')) { $bad += "reboot-$n is not a single 'not attempted' FAIL" }
    }
    Assert "${id}-na: reboot-1..4 have no PASS line and each is a 'not attempted' FAIL" ($bad.Count -eq 0) "$($bad -join '; ') :: $(Format-Result $r)"
}
# 인자 검사에서 거부: exit 1 · FAIL reboot-pre-4(그 경우의 사유 + 필요하면 "-Baseline을 먼저" 안내) · 폴링 없음(폴링 줄 없음 · 노드/port-forward/store/app/ES 호출 0)
#   사유 문구까지 본다 — 다른 검사가 우연히 거부해도(예: 필수 검사가 빠졌는데 다른 규칙이 막음) 통과하지 않게
$guidanceText = "run 'pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -Baseline' BEFORE rebooting node A"
function Assert-RefusedBeforePolling([string]$id, $r, $calls, [string]$reason, [bool]$guidance) {
    $f = @(Lines-Starting $r 'FAIL reboot-pre-4: ')
    $ok = $r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] $reason) -and (-not $guidance -or (Has-Text $f[0] $guidanceText))
    Assert "${id}-1: exit 1 and a single 'FAIL reboot-pre-4' line with the reason '$reason'$(if ($guidance) { " and the 'run -Baseline first' guidance" })" $ok (Format-Result $r)
    $polled = (Count-Calls $calls 'nodes') + (Count-Calls $calls 'pf') + (Count-Calls $calls 'stores') + (Count-Calls $calls 'apps') + (Count-Calls $calls 'es')
    Assert "${id}-2: no polling started (no 'polling reboot-0..4' line; zero get nodes / port-forward / stores / apps / externalsecrets calls)" (@(Lines-Starting $r 'polling reboot-0..4').Count -eq 0 -and $polled -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
    # 인자 거부는 kubectl을 한 번도 부르기 전이어야 한다(whoami 포함 — 가짜의 호출 기록 0건)
    Assert "${id}-0calls: refused before any kubectl call (fake call log is empty, whoami included)" (@($calls).Count -eq 0) (Format-Calls $calls)
}
# 노드 수가 1이 아님 → final FAIL(개수) · 마감 전에 끝남 · get nodes 정확히 1회
function Assert-NodeCountFail([string]$id, $r, $calls, [int]$count, [int]$deadline) {
    $f = @(Lines-Starting $r 'FAIL reboot-0: ')
    Assert "${id}-1: exit 1 and 'FAIL reboot-0' names the node count (role=platform nodes: $count)" ($r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] "role=platform nodes: $count")) (Format-Result $r)
    $end = Get-EndSec $r
    Assert "${id}-2: ended without waiting for the ${deadline}s deadline (polling ended < ${deadline}s, wall < ${deadline}s, exactly one get nodes call)" ($null -ne $end -and $end -lt $deadline -and $r.wall -lt $deadline -and (Count-Calls $calls 'nodes') -eq 1) "end=$end $(Format-Result $r) :: $(Format-Calls $calls)"
    Assert-NotAttempted $id $r
}

$afterArgs = @('-AfterReboot', '-BaselineBootId', $oldBoot, '-BaselineNode', 'jt-node-a')

try {
    # 주변 환경의 손잡이가 이 프로세스에서 새지 않게 한다(자식에게는 Invoke-Harness가 명시적으로만 준다)
    foreach ($k in $knobNames) { Remove-Item "Env:$k" -ErrorAction SilentlyContinue }

    Test-Case 'static' 'harness file exists' {
        Assert 'static-1: harness exists at tests/platform/reboot.tests.ps1' (Test-Path -LiteralPath $harnessPath -PathType Leaf) "missing: $harnessPath"
    }

    # ---------- S1: 재부팅이 일어나지 않음(bootID가 끝까지 baseline, 나머지는 전부 건강) ----------
    #   H2: 옛 부팅이 보이는 동안은 armed — 기준점이 관측마다 움직이고 reboot-0의 마감은 만료되지 않는다. 재부팅이 끝내 없으면
    #   arm 시간 제한(손잡이 16초 — 부하에서도 관측 세 번이 들어가게)에서 FAIL("no reboot observed within") — "재부팅 없이 PASS" 방어는 그대로 단언한다.
    #   baseline은 대문자로 준다(옛 S1b를 합침 — 같은 부팅 ID를 대소문자만 바꿔 줘도 재부팅으로 보지 않는다: OrdinalIgnoreCase).
    #   감시 시간 60 s: arm 시간 제한이 빠지면(변이) 끝나지 않아 시간 초과로 실패한다.
    Test-Case 'S1' 'no reboot: bootID stays at the baseline (given in upper case) -> armed until the arm timeout, then FAIL' {
        $d = New-Fixture @(New-PrePhase)
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $oldBoot.ToUpperInvariant(), '-BaselineNode', 'jt-node-a') (Knobs 10 10 1 16) 60
        $calls = @(Get-Calls $d)
        Assert-Completed 'S1' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S1-1: exit 1 and "FAIL reboot-0" says no reboot observed within the 16s arm timeout (baseline bootID kept)' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'no reboot observed within 16s') -and (Has-Text $f0[0] 'kept reporting the baseline bootID')) (Format-Result $r)
        Assert-NotAttempted 'S1' $r
        $other = (Count-Calls $calls 'pf') + (Count-Calls $calls 'stores') + (Count-Calls $calls 'apps') + (Count-Calls $calls 'es')
        Assert 'S1-2: reboot-0 polled repeatedly (>= 3 get nodes) and reboot-1..4 never queried the cluster' ((Count-Calls $calls 'nodes') -ge 3 -and $other -eq 0) (Format-Calls $calls)
        # (바) armed 진행 줄은 관측마다 나오지 않는다(최대 60초에 한 줄) · armed 동안 reboot-0 waiting 줄도 내지 않는다
        $armed = @(Get-ArmedLines $r)
        $unchangedWaits = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: reboot-0(') -and (Has-Text $_ 'bootID unchanged') })
        Assert 'S1-3: one armed line for all the old-boot observations (not one per observation) and no per-poll waiting lines while armed' ($armed.Count -eq 1 -and (Count-Calls $calls 'nodes') -ge 3 -and $unchangedWaits.Count -eq 0) "armed=$($armed.Count) nodes=$(Count-Calls $calls 'nodes') unchangedWaits=$($unchangedWaits.Count) :: $(Format-Result $r)"
        $z = Get-ZeroSummary $r
        Assert 'S1-4: the summary says the zero point is the last observation of the old boot' ($null -ne $z -and (Test-Same $z.why 'last observation of the old boot') -and @(Lines-Starting $r $zeroScriptStartLine).Count -eq 0) (Format-Result $r)
    }

    # ---------- S2: 경쟁 뒤 실제 재부팅 — ①재부팅 전 건강 ②API 불통 ③새 bootID + 과도 상태 ----------
    Test-Case 'S2' 'race then a real reboot: healthy pre-reboot -> API down -> new bootID with transient states' {
        $pre = New-PrePhase @{ whoamiCalls = 2 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $post = New-Phase @{
            name   = 'post-reboot'
            vault  = @(@{ sealed = $true }, @{ sealed = $false })
            stores = @(@{ ready = $false; ltt = $postNotReadyLtt }, @{ ready = $true; ltt = $postLtt })
            apps   = @('Progressing', 'Healthy')
            es     = @($preRefresh, $postRefresh)
        }
        $d = New-Fixture @($pre, $down, $post)
        $r = Invoke-Harness $d $afterArgs (Knobs 45 20) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S2' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S2-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        # H2: 경과 초는 기준점(마지막으로 옛 부팅을 본 관측의 시작) 기준이다. 가짜 시계에서 "③ 시작 - 마지막 옛 부팅 whoami"보다 앞설 수 없다
        #   (하네스의 관측 시작은 가짜가 whoami를 기록하기 전이므로 하네스 쪽 간격이 같거나 더 길다).
        $p3 = Get-PhaseStart $d 2
        $m0 = Get-MetSec $r 'reboot-0'
        $oldWho = @(Get-CallsOf $calls 'whoami' 0)
        $lastOld = if ($oldWho.Count -gt 0) { [double]$oldWho[$oldWho.Count - 1]['elapsed'] } else { $null }
        $nodeCalls = @(Get-CallsOf $calls 'nodes')
        $metByPost = $nodeCalls.Count -gt 0 -and [int]$nodeCalls[$nodeCalls.Count - 1]['phase'] -eq 2 -and (Has-Text $nodeCalls[$nodeCalls.Count - 1]['served'] $newBoot)
        Assert 'S2-2: reboot-0 was met by a phase-3 observation (new bootID), and its elapsed second (from the zero point) is no earlier than phase 3 started after the last old-boot observation' ($null -ne $p3 -and $null -ne $m0 -and $null -ne $lastOld -and $metByPost -and $m0 -ge [Math]::Floor($p3 - $lastOld)) "phase3Start=$p3 lastOldBoot=$lastOld reboot0Met=$m0 :: $(Format-Result $r)"
        $m = @{}
        foreach ($i in 1..4) { $m[$i] = Get-MetSec $r "reboot-$i" }
        $order = ($null -ne $m0) -and ($null -ne $m[1]) -and ($null -ne $m[2]) -and ($null -ne $m[3]) -and ($null -ne $m[4]) -and $m[1] -ge $m0 -and $m[2] -ge $m0 -and $m[3] -ge $m0 -and $m[4] -ge $m[2]
        Assert 'S2-3: reboot-1/2/3 met no earlier than reboot-0, reboot-4 no earlier than reboot-2' $order "met: r0=$m0 r1=$($m[1]) r2=$($m[2]) r3=$($m[3]) r4=$($m[4])"
        $sealedHttp = @(Get-CallsOf $calls 'pf-http' 2 | Where-Object { Has-Text $_['served'] 'sealed=True' })
        $unsealedHttp = @(Get-CallsOf $calls 'pf-http' 2 | Where-Object { Has-Text $_['served'] 'sealed=False' })
        $st1 = @(Get-CallsOf $calls 'stores' 2 | Where-Object { $_['idx'] -eq 1 -and (Has-Text $_['served'] 'ready=False') })
        $ap1 = @(Get-CallsOf $calls 'apps' 2 | Where-Object { $_['idx'] -eq 1 -and (Has-Text $_['served'] 'vault=Progressing') })
        $es1 = @(Get-CallsOf $calls 'es' 2 | Where-Object { $_['idx'] -eq 1 -and (Has-Text $_['served'] "refreshTime=$preRefresh") })
        $transient = $sealedHttp.Count -ge 1 -and $unsealedHttp.Count -ge 1 -and $st1.Count -eq 1 -and (Count-Calls $calls 'stores' 2) -ge 2 -and $ap1.Count -eq 1 -and (Count-Calls $calls 'apps' 2) -ge 2 -and $es1.Count -eq 1 -and (Count-Calls $calls 'es' 2) -ge 2
        Assert 'S2-4: the harness polled through every phase-3 transient (sealed seal-status answered, store NotReady, app Progressing, stale refreshTime) before passing' $transient (Format-Calls $calls)
        $preNodes = @(Get-CallsOf $calls 'nodes' 0 | Where-Object { Has-Text $_['served'] $oldBoot })
        $downWho = @(Get-CallsOf $calls 'whoami' 1 | Where-Object { $_['code'] -eq 1 })
        Assert 'S2-5: phase 1 (old bootID, API up) and phase 2 (API down) were both observed' ($preNodes.Count -ge 1 -and $downWho.Count -ge 1) (Format-Calls $calls)
        $early = 0
        foreach ($ph in 0, 1) { foreach ($k in 'pf', 'stores', 'apps', 'es') { $early += (Count-Calls $calls $k $ph) } }
        Assert 'S2-6: no port-forward / stores / apps / externalsecrets call before the new bootID was seen' ($early -eq 0) (Format-Calls $calls)
        $applied = @(Lines-Starting $r 'note: REBOOT_TESTS_PHASE_DEADLINE_SEC=45 applied').Count + @(Lines-Starting $r 'note: REBOOT_TESTS_ES_REFRESH_SEC=20 applied').Count + @(Lines-Starting $r 'note: REBOOT_TESTS_POLL_INTERVAL_SEC=1 applied').Count
        Assert 'S2-7: applied test knobs are announced and shown on the polling line' ($applied -eq 3 -and (Has-Line $r 'polling reboot-0..4 (nominal interval 1s; reboot-0..3 deadline 45s from the zero point; reboot-4 deadline = reboot-2 pass + 20s; arm timeout 30 minutes)')) (Format-Result $r)
        $met0 = @(@(Get-Lines $r) | Where-Object { [regex]::IsMatch($_, '\A  \[\d+s\] reboot-0 met -- ') })
        $pass0 = @(Lines-Starting $r 'PASS reboot-0: ')
        $change = "node jt-node-a bootID $oldBoot -> $newBoot"
        # met 진행 줄은 폴링 엔진이 200자로 자른다(기존 동작) — 두 bootID 전체·ready=True는 그 안에, 부팅 anchor는 PASS 줄에서 전부 본다
        Assert 'S2-8: reboot-0 met line and PASS line show the full boot ID change and Ready=True; the PASS line shows the boot anchor (node Ready lastHeartbeatTime)' ($met0.Count -eq 1 -and (Has-Text $met0[0] "context user $expectedUser") -and (Has-Text $met0[0] $change) -and (Has-Text $met0[0] 'ready=True') -and $pass0.Count -eq 1 -and (Has-Text $pass0[0] $change) -and (Has-Text $pass0[0] "ready=True bootAnchor=$postHeartbeat")) (Format-Result $r)
        $pass4 = @(Lines-Starting $r 'PASS reboot-4: ')
        Assert 'S2-9: reboot-4 uses max(store anchor, boot anchor) and prints both (store Ready transitioned after the reboot -> using=storeAnchor)' ($pass4.Count -eq 1 -and (Has-Text $pass4[0] "storeAnchor=$postLtt bootAnchor=$postHeartbeat using=storeAnchor")) (Format-Result $r)
        Assert 'S2-10: pre-4 PASS line shows the full baseline boot ID' (@(@(Lines-Starting $r 'PASS reboot-pre-4: ') | Where-Object { Has-Text $_ "baseline bootID $oldBoot" }).Count -eq 1) (Format-Result $r)
        # H2: 옛 부팅 두 라운드(armed) → 불통에서 기준점이 굳는다(한 줄) → 요약 앞 줄은 같은 시각, "last observation of the old boot"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S2-11: armed once, the zero point fixed once at the API outage, and the summary repeats that zero point' (@(Get-ArmedLines $r).Count -eq 1 -and $fixed.Count -eq 1 -and $null -ne $z -and (Test-Same $z.why 'last observation of the old boot') -and (Test-Same $z.utc $fixed[0]) -and @(Lines-Starting $r $zeroScriptStartLine).Count -eq 0) (Format-Result $r)
        # H1: 모든 kubectl 조회가 --request-timeout=30s로 불렸다(가짜는 정확한 인자 목록만 인정한다 — 여기서는 기록으로 다시 본다)
        $queries = @(@($calls) | Where-Object { @('whoami', 'nodes', 'stores', 'apps', 'es') -contains "$($_['kind'])" })
        $bad = @($queries | Where-Object { -not ("$($_['args'])".EndsWith(' --request-timeout=30s', [StringComparison]::Ordinal)) })
        Assert 'S2-12: every whoami/get call carried --request-timeout=30s' ($queries.Count -ge 8 -and $bad.Count -eq 0) "queries=$($queries.Count) bad=[$((@($bad | ForEach-Object { $_['args'] })) -join ' || ')]"
    }

    # ---------- S3: -AfterReboot인데 -BaselineBootId 없음 ----------
    Test-Case 'S3' '-AfterReboot without -BaselineBootId' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterReboot') (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S3' $r $calls
        Assert-RefusedBeforePolling 'S3' $r $calls '-AfterReboot requires -BaselineBootId' $true
    }

    # ---------- S4: -BaselineBootId 형식 오류 2종 ----------
    Test-Case 'S4a' '-BaselineBootId is not a UUID (abc)' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', 'abc', '-BaselineNode', 'jt-node-a') (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S4a' $r $calls
        Assert-RefusedBeforePolling 'S4a' $r $calls "-BaselineBootId 'abc' is not a boot ID" $true
    }
    Test-Case 'S4b' '-BaselineBootId has a leading space' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', " $oldBoot", '-BaselineNode', 'jt-node-a') (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S4b' $r $calls
        Assert-RefusedBeforePolling 'S4b' $r $calls "-BaselineBootId ' $oldBoot' is not a boot ID" $true
    }

    # ---------- S5: role=platform 노드가 2개 / 0개 → final FAIL, 마감까지 기다리지 않음 ----------
    Test-Case 'S5a' 'two role=platform nodes (first one has a new bootID) -> final FAIL' {
        $post = New-Phase @{ nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'True'; heartbeat = $postHeartbeat }, @{ name = 'jt-node-b'; bootID = $oldBoot; ready = 'True'; heartbeat = $postHeartbeat }) }
        $d = New-Fixture @($post)
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S5a' $r $calls
        Assert-NodeCountFail 'S5a' $r $calls 2 30
    }
    # R3: 처음 한 번 0개 → 그다음 정상(새 bootID) → PASS
    Test-Case 'S5c' 'first node list is empty, then node A shows the new bootID -> PASS' {
        $p0 = New-Phase @{ name = 'empty-list'; whoamiCalls = 1; nodes = @() }
        $d = New-Fixture @($p0, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S5c' $r $calls
        Assert 'S5c-1: exit 0 and PASS reboot-0 after an empty node list was seen first' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1 -and (Count-Calls $calls 'nodes' 0) -ge 1 -and (Count-Calls $calls 'nodes' 1) -ge 1) "$(Format-Result $r) :: $(Format-Calls $calls)"
    }

    # ---------- S6: reboot-0 미충족 사유 넷을 단계가 바뀌는 한 번의 실행으로(옛 S5b · S6 · S17 · S18을 합침 — F5) ----------
    #   ① 노드 0개(R3: final 아님) ② bootID 없음 ③ 새 bootID · Ready=True인데 lastHeartbeatTime 없음(부팅 anchor 없음)
    #   ④ 새 bootID · Ready=False(heartbeat 있음 — anchor는 정해지지만 충족은 아님)가 마감까지. 어느 단계에서든 충족으로 잘못 보면
    #   reboot-0이 PASS하거나 다음 단계에 도달하지 못한다. 순서가 중요하다: ④를 ③ 앞에 두면 ④에서 정한 anchor로 ③이 충족된다(F2).
    Test-Case 'S6' 'reboot-0 not met for four reasons in turn: 0 nodes -> no bootID -> no heartbeat -> Ready=False (until the deadline)' {
        $p0 = New-Phase @{ name = 'zero-nodes'; whoamiCalls = 1; nodes = @() }
        $p1 = New-Phase @{ name = 'no-bootid'; whoamiCalls = 1; nodes = @(@{ name = 'jt-node-a'; bootID = $null; ready = 'True'; heartbeat = $postHeartbeat }) }
        $p2 = New-Phase @{ name = 'no-heartbeat'; whoamiCalls = 1; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'True'; heartbeat = $null }) }
        $p3 = New-Phase @{ name = 'ready-false'; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'False'; heartbeat = $postHeartbeat }) }
        $d = New-Fixture @($p0, $p1, $p2, $p3)
        $r = Invoke-Harness $d $afterArgs (Knobs 15 15)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S6' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S6-1: exit 1 and "FAIL reboot-0" expired (not met within 15s) with the last reason ready=False' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'not met within 15s') -and (Has-Text $f0[0] 'ready=False')) (Format-Result $r)
        $seen = @(0..3 | Where-Object { (Count-Calls $calls 'nodes' $_) -ge 1 })
        Assert 'S6-2: every phase was observed (>= 1 get nodes in each of the four phases) -- none of them ended the polling early' ($seen.Count -eq 4) "phases seen=[$($seen -join ',')] :: $(Format-Calls $calls)"
        $waits = @(@(Get-Lines $r) | Where-Object { Has-Text $_ 'waiting: reboot-0(' })
        $reasons = @('role=platform nodes: 0', 'bootID missing', 'lastHeartbeatTime missing', 'ready=False')
        $shown = @($reasons | Where-Object { $n = $_; @($waits | Where-Object { Has-Text $_ $n }).Count -ge 1 })
        Assert 'S6-3: each reason is visible in a reboot-0 waiting line (reason comes before the long boot ID text, so the 120-char clip keeps it)' ($shown.Count -eq 4) "shown=[$($shown -join ' | ')] :: $(Format-Result $r)"
        $other = (Count-Calls $calls 'pf') + (Count-Calls $calls 'stores') + (Count-Calls $calls 'apps') + (Count-Calls $calls 'es')
        Assert 'S6-4: reboot-1..4 never queried the cluster' ($other -eq 0) (Format-Calls $calls)
        Assert-NotAttempted 'S6' $r
    }

    # ---------- S7: -Baseline 모드 ----------
    Test-Case 'S7a' '-Baseline prints the node A boot ID' {
        $d = New-Fixture @(New-PrePhase)
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7a' $r $calls
        $summary = @(@(Get-Lines $r) | Where-Object { [regex]::IsMatch($_, '\A\d+ passed, 0 failed, 0 skipped\z') })
        Assert 'S7a-1: exit 0 with "baseline: node=jt-node-a bootID=<fake value> ready=True" and a 0-failed summary' ($r.code -eq 0 -and (Has-Line $r "baseline: node=jt-node-a bootID=$oldBoot ready=True") -and $summary.Count -eq 1) (Format-Result $r)
        $other = (Count-Calls $calls 'pf') + (Count-Calls $calls 'stores') + (Count-Calls $calls 'apps') + (Count-Calls $calls 'es')
        Assert 'S7a-2: read once and did not poll (exactly one get nodes call, no polling line, nothing else queried)' ((Count-Calls $calls 'nodes') -eq 1 -and $other -eq 0 -and @(Lines-Starting $r 'polling reboot-0..4').Count -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
    }
    Test-Case 'S7b' '-Baseline while the API is unreachable' {
        $d = New-Fixture @(New-Phase @{ name = 'api-down'; api = 'down' })
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7b' $r $calls
        Assert 'S7b-1: exit 1, a "FAIL reboot-baseline" line and no "baseline:" line' ($r.code -eq 1 -and @(Lines-Starting $r 'FAIL reboot-baseline: ').Count -eq 1 -and @(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }
    Test-Case 'S7c' '-Baseline together with -AfterReboot' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-Baseline', '-AfterReboot') (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7c' $r $calls
        Assert-RefusedBeforePolling 'S7c' $r $calls '-Baseline and -AfterReboot are mutually exclusive' $true
        Assert 'S7c-3: no "baseline:" line' (@(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }
    Test-Case 'S7d' '-Baseline with two role=platform nodes' {
        $pre = New-PrePhase @{ nodes = @(@{ name = 'jt-node-a'; bootID = $oldBoot; ready = 'True' }, @{ name = 'jt-node-b'; bootID = $newBoot; ready = 'True' }) }
        $d = New-Fixture @($pre)
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7d' $r $calls
        $f = @(Lines-Starting $r 'FAIL reboot-baseline: ')
        Assert 'S7d-1: exit 1 and "FAIL reboot-baseline" names the node count, no "baseline:" line' ($r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] 'role=platform nodes: 2') -and @(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }
    Test-Case 'S7e' '-Baseline when get nodes fails (identity ok)' {
        $d = New-Fixture @(New-PrePhase @{ nodesExit = 1 })
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7e' $r $calls
        $f = @(Lines-Starting $r 'FAIL reboot-baseline: ')
        Assert 'S7e-1: exit 1 and "FAIL reboot-baseline" reports the failed query (exit=1)' ($r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] 'exit=1') -and @(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }
    Test-Case 'S7f' '-Baseline when node A has no bootID' {
        $d = New-Fixture @(New-PrePhase @{ nodes = @(@{ name = 'jt-node-a'; bootID = $null; ready = 'True' }) })
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7f' $r $calls
        $f = @(Lines-Starting $r 'FAIL reboot-baseline: ')
        Assert 'S7f-1: exit 1 and "FAIL reboot-baseline" names the missing bootID' ($r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] 'bootID missing') -and @(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }
    # R5: -Baseline도 신원 게이트를 지난 뒤에만 노드를 읽는다(다른 신원이면 get nodes 0회)
    Test-Case 'S7g' '-Baseline with a non-agent-view identity' {
        $d = New-Fixture @(New-PrePhase @{ user = 'system:admin' })
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7g' $r $calls
        $f3 = @(Lines-Starting $r 'FAIL reboot-pre-3: ')
        Assert 'S7g-1: exit 1, "FAIL reboot-pre-3" names the wrong user, no "baseline:" line, zero get nodes calls' ($r.code -eq 1 -and $f3.Count -eq 1 -and (Has-Text $f3[0] "context user is 'system:admin'") -and @(Lines-Starting $r 'baseline:').Count -eq 0 -and (Count-Calls $calls 'nodes') -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
    }
    # R3: -Baseline은 그대로 "정확히 1개가 아니면 FAIL"(0개 포함 — 한 번의 조회라 기다리지 않는다)
    Test-Case 'S7h' '-Baseline with zero role=platform nodes' {
        $d = New-Fixture @(New-PrePhase @{ nodes = @() })
        $r = Invoke-Harness $d @('-Baseline')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S7h' $r $calls
        $f = @(Lines-Starting $r 'FAIL reboot-baseline: ')
        Assert 'S7h-1: exit 1 and "FAIL reboot-baseline" names the node count 0, no "baseline:" line' ($r.code -eq 1 -and $f.Count -eq 1 -and (Has-Text $f[0] 'role=platform nodes: 0') -and @(Lines-Starting $r 'baseline:').Count -eq 0) (Format-Result $r)
    }

    # ---------- S8: 평상시 모드(스위치 없음) — 출력·종료 코드 불변(회귀) ----------
    Test-Case 'S8' 'normal mode (no switches) output is unchanged' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @()
        $calls = @(Get-Calls $d)
        Assert-Completed 'S8' $r $calls
        $expected = @(
            'PASS reboot-pre-1: kubectl on PATH -- found'
            'PASS reboot-pre-2: KUBECONFIG set and file exists -- found'
            "PASS reboot-pre-3: context user is $expectedUser -- context user $expectedUser"
            'SKIP reboot-1: manual trigger only (-AfterReboot) -- vault seal-status sealed=false type=ocikms (port-forward svc/vault)'
            'SKIP reboot-2: manual trigger only (-AfterReboot) -- clustersecretstores exactly 5 and all Ready [vault-platform, vault-dev, vault-prod, vault-data, k8s-data-ca]'
            'SKIP reboot-3: manual trigger only (-AfterReboot) -- argocd applications all Healthy'
            'SKIP reboot-4: manual trigger only (-AfterReboot) -- externalsecrets all SecretSynced with refreshTime >= store Ready anchor, within 300s after reboot-2'
            ''
            '3 passed, 0 failed, 4 skipped'
        )
        $lines = @(Get-Lines $r)
        $same = ($lines.Count -eq $expected.Count + 1) -and [regex]::IsMatch($lines[0], '\Areboot\.tests\.ps1: mode=normal \(runner path; reboot-1\.\.4 skipped\) start=\S+\z')
        if ($same) { for ($i = 0; $i -lt $expected.Count; $i++) { if (-not (Test-Same $lines[$i + 1] $expected[$i])) { $same = $false } } }
        Assert 'S8-1: exit 0 and the exact pre-change output (mode line, PASS reboot-pre-1..3, SKIP reboot-1..4, summary)' ($r.code -eq 0 -and $same) (Format-Result $r)
        Assert 'S8-2: one whoami call and no get nodes / port-forward / stores / apps / externalsecrets call' ((Count-Calls $calls 'whoami') -eq 1 -and ((Count-Calls $calls 'nodes') + (Count-Calls $calls 'pf') + (Count-Calls $calls 'stores') + (Count-Calls $calls 'apps') + (Count-Calls $calls 'es')) -eq 0) (Format-Calls $calls)
    }

    # ---------- S9: 신원 불일치 + 유효한 baseline → fatal FAIL, 300 s를 기다리지 않음(회귀) ----------
    Test-Case 'S9' 'wrong identity with -AfterReboot and a valid -BaselineBootId (default deadlines)' {
        $d = New-Fixture @(New-Phase @{ user = 'system:admin' })
        $r = Invoke-Harness $d $afterArgs @{} 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S9' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S9-1: exit 1 and fatal "FAIL reboot-0" refuses non-agent-view credentials' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] "context user is 'system:admin'") -and (Has-Text $f0[0] 'refusing to run with non-agent-view credentials')) (Format-Result $r)
        Assert 'S9-2: did not wait for the 300s deadline (wall < 60s) and queried nothing after the refusal' ($r.wall -lt 60 -and (Count-Calls $calls 'nodes') -eq 0 -and (Count-Calls $calls 'pf') -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S9' $r
    }

    # ---------- S10: 손잡이 무시(기본값보다 큼 · 정수 아님) — fatal 경로로 곧바로 끝낸다 ----------
    $defaultPollingLine = 'polling reboot-0..4 (nominal interval 10s; reboot-0..3 deadline 300s from the zero point; reboot-4 deadline = reboot-2 pass + 300s; arm timeout 30 minutes)'
    Test-Case 'S10a' 'knobs above the defaults are ignored' {
        $d = New-Fixture @(New-Phase @{ user = 'system:admin' })
        $r = Invoke-Harness $d $afterArgs @{ REBOOT_TESTS_PHASE_DEADLINE_SEC = '301'; REBOOT_TESTS_ES_REFRESH_SEC = '99999'; REBOOT_TESTS_POLL_INTERVAL_SEC = '11'; REBOOT_TESTS_ARM_TIMEOUT_SEC = '1801' } 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S10a' $r $calls
        $ignored = @($knobNames | Where-Object { @(Lines-Starting $r "note: $_ ignored").Count -eq 1 })
        Assert 'S10a-1: one "ignored" note per knob (4, incl. the arm timeout) and no "applied" note' ($ignored.Count -eq 4 -and @(@(Get-Lines $r) | Where-Object { Has-Text $_ ' applied' }).Count -eq 0) (Format-Result $r)
        Assert 'S10a-2: the polling line shows the defaults (10s / 300s / 300s / 30 minutes)' (Has-Line $r $defaultPollingLine) (Format-Result $r)
        Assert 'S10a-3: exit 1 via the identity refusal, quickly (wall < 60s)' ($r.code -eq 1 -and $r.wall -lt 60) (Format-Result $r)
    }
    Test-Case 'S10b' 'non-integer / zero knobs are ignored' {
        $d = New-Fixture @(New-Phase @{ user = 'system:admin' })
        $r = Invoke-Harness $d $afterArgs @{ REBOOT_TESTS_PHASE_DEADLINE_SEC = 'abc'; REBOOT_TESTS_ES_REFRESH_SEC = '1.5'; REBOOT_TESTS_POLL_INTERVAL_SEC = '0'; REBOOT_TESTS_ARM_TIMEOUT_SEC = '6s' } 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S10b' $r $calls
        $ignored = @($knobNames | Where-Object { @(Lines-Starting $r "note: $_ ignored").Count -eq 1 })
        Assert 'S10b-1: one "ignored" note per knob (4, incl. the arm timeout) and no "applied" note' ($ignored.Count -eq 4 -and @(@(Get-Lines $r) | Where-Object { Has-Text $_ ' applied' }).Count -eq 0) (Format-Result $r)
        Assert 'S10b-2: the polling line shows the defaults (10s / 300s / 300s / 30 minutes)' (Has-Line $r $defaultPollingLine) (Format-Result $r)
        Assert 'S10b-3: exit 1 via the identity refusal, quickly (wall < 60s)' ($r.code -eq 1 -and $r.wall -lt 60) (Format-Result $r)
    }

    # ---------- S11: bootID는 바뀌었는데 Vault가 마감 뒤까지 sealed ----------
    Test-Case 'S11' 'rebooted but vault stays sealed past the deadline' {
        $d = New-Fixture @(New-Phase @{ vault = @(@{ sealed = $true }) })
        $r = Invoke-Harness $d $afterArgs (Knobs 15 15)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S11' $r $calls
        $f1 = @(Lines-Starting $r 'FAIL reboot-1: ')
        Assert 'S11-1: exit 1, PASS reboot-0 and "FAIL reboot-1" not met within 15s (sealed=True)' ($r.code -eq 1 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1 -and $f1.Count -eq 1 -and (Has-Text $f1[0] 'not met within 15s') -and (Has-Text $f1[0] 'sealed=True')) (Format-Result $r)
        Assert 'S11-2: vault was re-checked through port-forward until the deadline (>= 2 answered seal-status requests)' ((Count-Calls $calls 'pf-http') -ge 2) (Format-Calls $calls)
    }

    # ---------- S12: 노드 조회 실패(exit 1) · JSON 아님 → 미충족으로 계속 폴링, 복귀 뒤 통과 ----------
    Test-Case 'S12' 'get nodes fails, then returns non-JSON, then shows the new bootID' {
        $p0 = New-Phase @{ name = 'nodes-exit-1'; whoamiCalls = 1; nodesExit = 1 }
        $p1 = New-Phase @{ name = 'nodes-not-json'; whoamiCalls = 1; nodesRaw = 'this is not json' }
        $p2 = New-Phase
        $d = New-Fixture @($p0, $p1, $p2)
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S12' $r $calls
        $p3 = Get-PhaseStart $d 2
        $m0 = Get-MetSec $r 'reboot-0'
        Assert 'S12-1: exit 0 and PASS reboot-0 met only after the node query recovered' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1 -and $null -ne $p3 -and $null -ne $m0 -and $m0 -ge [Math]::Floor($p3)) "phase3Start=$p3 reboot0Met=$m0 $(Format-Result $r)"
        Assert 'S12-2: the failed and the non-JSON node queries were both seen (kept polling instead of failing)' ((Count-Calls $calls 'nodes' 0) -ge 1 -and (Count-Calls $calls 'nodes' 1) -ge 1 -and (Count-Calls $calls 'nodes' 2) -ge 1) (Format-Calls $calls)
    }

    # ---------- S13: -AfterReboot 없이 -BaselineBootId만 → 거부(평상시 SKIP로 통과한 것처럼 보이지 않게) ----------
    Test-Case 'S13' '-BaselineBootId without -AfterReboot' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-BaselineBootId', $oldBoot)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S13' $r $calls
        Assert-RefusedBeforePolling 'S13' $r $calls '-BaselineBootId is only used with -AfterReboot' $true
        Assert 'S13-3: no SKIP line (must not look like a normal-mode pass)' (@(Lines-Starting $r 'SKIP ').Count -eq 0) (Format-Result $r)
    }

    # ---------- S14: 알 수 없는 인자(오타) → 거부 ----------
    Test-Case 'S14' 'unknown argument (typo -AfterRebot)' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterRebot')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S14' $r $calls
        Assert-RefusedBeforePolling 'S14' $r $calls 'unexpected argument(s) [-AfterRebot]' $false
        Assert 'S14-3: no SKIP line (must not look like a normal-mode pass)' (@(Lines-Starting $r 'SKIP ').Count -eq 0) (Format-Result $r)
    }

    # ---------- R1: 재부팅 뒤의 refresh를 요구한다 — reboot-0에 Ready=True + 부팅 anchor, reboot-4 anchor = max(store, 부팅) ----------
    Test-Case 'S15' 'R1: rebooted (new bootID, Ready=True) but store and ExternalSecret status are still the pre-reboot values' {
        $d = New-Fixture @(New-Phase @{ stores = @(@{ ready = $true; ltt = $preLtt }); es = @($preRefresh) })
        $r = Invoke-Harness $d $afterArgs (Knobs 20 6)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S15' $r $calls
        $p03 = @(0..3 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        $f4 = @(Lines-Starting $r 'FAIL reboot-4: ')
        Assert 'S15-1: exit 1, PASS reboot-0..3 and "FAIL reboot-4" -- refreshTime is before the boot anchor (using=bootAnchor)' ($r.code -eq 1 -and $p03.Count -eq 4 -and $f4.Count -eq 1 -and (Has-Text $f4[0] "storeAnchor=$preLtt bootAnchor=$postHeartbeat using=bootAnchor") -and (Has-Text $f4[0] 'refreshTime before anchor')) (Format-Result $r)
        $p2 = @(Lines-Starting $r 'PASS reboot-2: ')
        Assert 'S15-2: reboot-2 still passes (5 Ready) but notes that the store Ready did not transition after the reboot' ($p2.Count -eq 1 -and (Has-Text $p2[0] "info: store Ready did not transition after the reboot (readyAnchor $preLtt < bootAnchor $postHeartbeat)")) (Format-Result $r)
    }
    Test-Case 'S16' 'R1: same stale store, but an ExternalSecret refresh after the boot anchor arrives -> PASS' {
        $d = New-Fixture @(New-Phase @{ stores = @(@{ ready = $true; ltt = $preLtt }); es = @($preRefresh, $postRefresh) })
        $r = Invoke-Harness $d $afterArgs (Knobs 20 20) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S16' $r $calls
        $p4 = @(Lines-Starting $r 'PASS reboot-4: ')
        Assert 'S16-1: exit 0 and PASS reboot-4 against the boot anchor after first seeing the stale refreshTime' ($r.code -eq 0 -and $p4.Count -eq 1 -and (Has-Text $p4[0] "storeAnchor=$preLtt bootAnchor=$postHeartbeat using=bootAnchor") -and (Count-Calls $calls 'es') -ge 2) "$(Format-Result $r) :: $(Format-Calls $calls)"
    }
    # F4(선택): refreshTime이 부팅 anchor와 정확히 같으면 재부팅 뒤의 refresh로 친다(>= 경계)
    Test-Case 'S33' 'F4: refreshTime exactly equal to the boot anchor counts as a post-reboot refresh' {
        $d = New-Fixture @(New-Phase @{ stores = @(@{ ready = $true; ltt = $preLtt }); es = @($postHeartbeat) })
        $r = Invoke-Harness $d $afterArgs (Knobs 20 10) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S33' $r $calls
        $p4 = @(Lines-Starting $r 'PASS reboot-4: ')
        Assert 'S33-1: exit 0 and PASS reboot-4 with refreshTime = bootAnchor (using=bootAnchor)' ($r.code -eq 0 -and $p4.Count -eq 1 -and (Has-Text $p4[0] "refreshed since anchor ${postHeartbeat}: 2") -and (Has-Text $p4[0] 'using=bootAnchor')) (Format-Result $r)
    }

    # ---------- F1: 마감 판정은 관측을 시작한 시각 기준(마감 안에 시작한 관측이 충족이면 통과) ----------
    #   경과 시간 기반 가짜: ES refreshTime은 "store 전부 Ready"를 처음 답한 뒤 esFreshAfterStoresSec초가 지나야 새 값이 된다.
    #   ES 응답은 2초 늦게 온다(느린 API) — 마감 1초 전에 시작한 마지막 관측이 마감을 넘겨 끝난다. 간격 6 s(손잡이).
    #   reboot-4 마감 = reboot-2 통과 + 8 s. 첫 관측(+0.4 s · 옛 값, 약 2.5 s 걸림) 뒤 "마감 1초 전"까지 자고 다시 관측한다
    #   (간격 6 s보다 짧은 대기 — 마감에 맞춰 줄인 마지막 대기가 이 케이스의 대상이다).
    Test-Case 'S26' 'F1: the refresh lands 3s before the reboot-4 deadline; the last observation starts inside and ends past the deadline -> PASS' {
        $ph = New-Phase @{ esFreshAfterStoresSec = 5; esFresh = $postRefresh; esStale = $preRefresh; esDelayMs = 2000 }
        $d = New-Fixture @($ph)
        $r = Invoke-Harness $d $afterArgs @{ REBOOT_TESTS_PHASE_DEADLINE_SEC = '45'; REBOOT_TESTS_ES_REFRESH_SEC = '8'; REBOOT_TESTS_POLL_INTERVAL_SEC = '6' } 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S26' $r $calls
        $p4 = @(Lines-Starting $r 'PASS reboot-4: ')
        Assert 'S26-1: exit 0 and PASS reboot-4 although the observation ended after the deadline (detail shows when it started)' ($r.code -eq 0 -and $p4.Count -eq 1 -and (Has-Text $p4[0] 'observation started at') -and (Has-Text $p4[0] "refreshed since anchor ${postLtt}: 2")) (Format-Result $r)
        $esCalls = @(Get-CallsOf $calls 'es')
        Assert 'S26-2: the stale refreshTime was observed first, then the fresh one (2 ES observations)' ($esCalls.Count -eq 2 -and (Has-Text $esCalls[0]['served'] $preRefresh) -and (Has-Text $esCalls[1]['served'] $postRefresh)) (Format-Calls $calls)
    }
    Test-Case 'S27' 'F1: the refresh lands 3s after the reboot-4 deadline -> FAIL (not met within)' {
        $ph = New-Phase @{ esFreshAfterStoresSec = 11; esFresh = $postRefresh; esStale = $preRefresh; esDelayMs = 2000 }
        $d = New-Fixture @($ph)
        $r = Invoke-Harness $d $afterArgs @{ REBOOT_TESTS_PHASE_DEADLINE_SEC = '45'; REBOOT_TESTS_ES_REFRESH_SEC = '8'; REBOOT_TESTS_POLL_INTERVAL_SEC = '6' } 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S27' $r $calls
        $f4 = @(Lines-Starting $r 'FAIL reboot-4: ')
        Assert 'S27-1: exit 1 and "FAIL reboot-4" not met within the deadline (stale refreshTime)' ($r.code -eq 1 -and $f4.Count -eq 1 -and (Has-Text $f4[0] 'not met within') -and (Has-Text $f4[0] 'refreshTime before anchor')) (Format-Result $r)
        Assert 'S27-2: the fresh refreshTime was never served before the run ended' (@(Get-CallsOf $calls 'es' | Where-Object { Has-Text $_['served'] $postRefresh }).Count -eq 0) (Format-Calls $calls)
    }

    # ---------- F2: 부팅 anchor = 새 bootID를 처음 본 관측(heartbeat가 있는 첫 관측)의 heartbeat — Ready 값과 무관, 한 번 정하면 유지 ----------
    #   ① 새 bootID · Ready=False · heartbeat 없음(anchor 미정) ② 새 bootID · Ready=False · h1(anchor = h1) ③ Ready=True · h2(충족, anchor는 h1 유지).
    #   store는 옛 Ready(anchor가 쓰임), ES refreshTime은 h1과 h2 사이 — anchor가 h2였다면 reboot-4가 실패한다.
    Test-Case 'S28' 'F2: boot anchor = heartbeat of the first observation that saw the new bootID (Ready=False), kept when Ready=True arrives' {
        $h1 = '2026-01-01T01:00:02Z'
        $h2 = '2026-01-01T01:00:20Z'
        $between = '2026-01-01T01:00:10Z'
        $common = @{ stores = @(@{ ready = $true; ltt = $preLtt }); es = @($between) }
        $p0 = New-Phase ($common + @{ name = 'new-boot-no-heartbeat'; whoamiCalls = 1; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'False'; heartbeat = $null }) })
        $p1 = New-Phase ($common + @{ name = 'new-boot-ready-false'; whoamiCalls = 1; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'False'; heartbeat = $h1 }) })
        $p2 = New-Phase ($common + @{ name = 'ready-true'; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'True'; heartbeat = $h2 }) })
        $d = New-Fixture @($p0, $p1, $p2)
        $r = Invoke-Harness $d $afterArgs (Knobs 30 10) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S28' $r $calls
        $p0l = @(Lines-Starting $r 'PASS reboot-0: ')
        $p4l = @(Lines-Starting $r 'PASS reboot-4: ')
        Assert 'S28-1: exit 0; PASS reboot-0 records bootAnchor=h1 (not h2)' ($r.code -eq 0 -and $p0l.Count -eq 1 -and (Has-Text $p0l[0] "bootAnchor=$h1") -and -not (Has-Text $p0l[0] "bootAnchor=$h2")) (Format-Result $r)
        Assert 'S28-2: reboot-4 passes against h1 (refreshTime between h1 and h2; using=bootAnchor)' ($p4l.Count -eq 1 -and (Has-Text $p4l[0] "bootAnchor=$h1 using=bootAnchor")) (Format-Result $r)
        Assert 'S28-3: all three phases were observed' (@(0..2 | Where-Object { (Count-Calls $calls 'nodes' $_) -ge 1 }).Count -eq 3) (Format-Calls $calls)
    }
    # ---------- R2: 부팅 ID 전체 출력 · -BaselineNode ----------
    $otherNodeBoot = '0b0b0b0b-0000-4000-8000-00000000000b'
    Test-Case 'S20' 'R2: -BaselineNode jt-node-a but the role=platform node is jt-node-b (label moved)' {
        $d = New-Fixture @(New-Phase @{ nodes = @(@{ name = 'jt-node-b'; bootID = $otherNodeBoot; ready = 'True'; heartbeat = $postHeartbeat }) })
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $oldBoot, '-BaselineNode', 'jt-node-a') (Knobs 30 30)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S20' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        $end = Get-EndSec $r
        Assert 'S20-1: exit 1 and final "FAIL reboot-0" names jt-node-b vs -BaselineNode jt-node-a' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] "'jt-node-b'") -and (Has-Text $f0[0] "-BaselineNode 'jt-node-a'")) (Format-Result $r)
        Assert 'S20-2: final -- one get nodes call, polling ended before the 30s deadline' ((Count-Calls $calls 'nodes') -eq 1 -and $null -ne $end -and $end -lt 30) "end=$end $(Format-Result $r) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S20' $r
    }
    # 옛 S19를 합침(F5): 새 bootID가 baseline과 앞 8자가 같아도 재부팅이고, 두 값 전체가 출력에 있어야 대조할 수 있다
    Test-Case 'S21' 'R2: -BaselineNode matches; the new bootID shares the 8-char prefix with the baseline' {
        $prefixBoot = 'a1b2c3d4-1111-4111-8111-111111111111'
        $d = New-Fixture @(New-Phase @{ nodes = @(@{ name = 'jt-node-a'; bootID = $prefixBoot; ready = 'True'; heartbeat = $postHeartbeat }) })
        $r = Invoke-Harness $d $afterArgs (Knobs 20 20) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S21' $r $calls
        $pre4 = @(Lines-Starting $r 'PASS reboot-pre-4: ')
        $p0 = @(Lines-Starting $r 'PASS reboot-0: ')
        Assert 'S21-1: exit 0, PASS reboot-0, and the pre-4 PASS line shows the baseline node' ($r.code -eq 0 -and $p0.Count -eq 1 -and $pre4.Count -eq 1 -and (Has-Text $pre4[0] 'baseline node jt-node-a')) (Format-Result $r)
        Assert 'S21-2: PASS reboot-0 shows both full boot IDs (same 8-char prefix)' ($p0.Count -eq 1 -and (Has-Text $p0[0] "node jt-node-a bootID $oldBoot -> $prefixBoot")) (Format-Result $r)
        # (라) H2: 재부팅 뒤에 시작(옛 부팅을 한 번도 못 봄) — 기준점은 스크립트 시작, 그 사실을 한 줄로 · 요약 앞 줄도 "script start"
        $z = Get-ZeroSummary $r
        Assert 'S21-3: started after the reboot -> one "zero point = script start" line, no armed/fixed lines, summary "(script start)"' (@(Lines-Starting $r $zeroScriptStartLine).Count -eq 1 -and @(Get-ArmedLines $r).Count -eq 0 -and @(Get-FixedZeros $r).Count -eq 0 -and $null -ne $z -and (Test-Same $z.why 'script start')) (Format-Result $r)
    }
    Test-Case 'S22' 'R2: -BaselineNode without -AfterReboot' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-BaselineNode', 'jt-node-a')
        $calls = @(Get-Calls $d)
        Assert-Completed 'S22' $r $calls
        Assert-RefusedBeforePolling 'S22' $r $calls '-BaselineNode is only used with -AfterReboot' $true
    }
    Test-Case 'S22b' 'R2: -BaselineNode is not a DNS-1123 name' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $oldBoot, '-BaselineNode', 'Bad_Name') (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S22b' $r $calls
        Assert-RefusedBeforePolling 'S22b' $r $calls "-BaselineNode 'Bad_Name' is not a node name" $false
    }
    # F3: -BaselineNode는 -AfterReboot의 필수 인자다(없으면 폴링 없이 pre-4 FAIL, kubectl 호출 0)
    Test-Case 'S30' 'F3: -AfterReboot with a valid -BaselineBootId but no -BaselineNode' {
        $d = New-Fixture @(New-Phase)
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $oldBoot) (Knobs 10 10)
        $calls = @(Get-Calls $d)
        Assert-Completed 'S30' $r $calls
        Assert-RefusedBeforePolling 'S30' $r $calls '-AfterReboot requires -BaselineNode' $true
    }

    # ---------- R4: -AfterReboot의 401은 연속 두 번일 때만 fatal(다른 신원은 그대로 즉시 fatal — S9) ----------
    Test-Case 'S23' 'R4: API down, then one 401, then healthy -> PASS' {
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 1; api = 'down' }
        $unauth = New-Phase @{ name = 'unauthorized-once'; whoamiCalls = 1; whoamiUnauthorized = $true }
        $d = New-Fixture @($down, $unauth, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S23' $r $calls
        $once = @(@(Get-Lines $r) | Where-Object { Has-Text $_ '401 (1 of 2 before fatal)' })
        Assert 'S23-1: exit 0 and PASS reboot-0 after a single 401 that was reported as 1 of 2' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1 -and $once.Count -ge 1 -and (Count-Calls $calls 'whoami' 1) -eq 1) "$(Format-Result $r) :: $(Format-Calls $calls)"
    }
    Test-Case 'S24' 'R4: 401 persists -> fatal at the second consecutive observation (default 300s deadline, no wait)' {
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 1; api = 'down' }
        $unauth = New-Phase @{ name = 'unauthorized'; whoamiUnauthorized = $true }
        $d = New-Fixture @($down, $unauth)
        $r = Invoke-Harness $d $afterArgs @{ REBOOT_TESTS_POLL_INTERVAL_SEC = '1' } 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S24' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S24-1: exit 1, fatal "FAIL reboot-0" says 401 (2 of 2), exactly two 401 whoami calls, wall < 60s' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] '401 (2 of 2)') -and (Count-Calls $calls 'whoami' 1) -eq 2 -and $r.wall -lt 60) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S24' $r
    }
    # F4: 연속 횟수는 401이 아닌 관측(접속 실패 포함)에서 0으로 돌아간다 — 401 → 불통 → 401 → 정상 = PASS
    Test-Case 'S31' 'F4: 401 -> connection failure -> 401 -> healthy -> PASS (the streak resets on a non-401 observation)' {
        $u1 = New-Phase @{ name = 'unauthorized-1'; whoamiCalls = 1; whoamiUnauthorized = $true }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 1; api = 'down' }
        $u2 = New-Phase @{ name = 'unauthorized-2'; whoamiCalls = 1; whoamiUnauthorized = $true }
        $d = New-Fixture @($u1, $down, $u2, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S31' $r $calls
        $once = @(@(Get-Lines $r) | Where-Object { Has-Text $_ '401 (1 of 2 before fatal)' })
        Assert 'S31-1: exit 0 and PASS reboot-0; both 401s were reported as 1 of 2 and no "2 of 2"' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1 -and $once.Count -ge 2 -and @(@(Get-Lines $r) | Where-Object { Has-Text $_ '401 (2 of 2)' }).Count -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert 'S31-2: all four phases were observed (401, down, 401, healthy)' (@(0..3 | Where-Object { (Count-Calls $calls 'whoami' $_) -ge 1 }).Count -eq 4) (Format-Calls $calls)
    }
    # F4: Ready=Unknown은 미충족이다("False만 거부"가 아니다) — Unknown 두 라운드 뒤 True가 되면 그때 통과
    Test-Case 'S32' 'F4: node A Ready=Unknown with the new bootID is not met; Ready=True afterwards passes' {
        $pu = New-Phase @{ name = 'ready-unknown'; whoamiCalls = 2; nodes = @(@{ name = 'jt-node-a'; bootID = $newBoot; ready = 'Unknown'; heartbeat = $postHeartbeat }) }
        $d = New-Fixture @($pu, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S32' $r $calls
        $p1 = Get-PhaseStart $d 1
        $m0 = Get-MetSec $r 'reboot-0'
        $unknownWait = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: reboot-0(') -and (Has-Text $_ 'ready=Unknown') })
        Assert 'S32-1: exit 0; reboot-0 met only after Ready=True was served (not during Ready=Unknown), and the waiting line shows ready=Unknown' ($r.code -eq 0 -and $null -ne $p1 -and $null -ne $m0 -and $m0 -ge [Math]::Floor($p1) -and $unknownWait.Count -ge 1 -and (Count-Calls $calls 'nodes' 0) -ge 2) "phase2Start=$p1 reboot0Met=$m0 $(Format-Result $r) :: $(Format-Calls $calls)"
    }

    # ---------- R6: 사용자 입력은 가린 뒤 자른다(경로를 인자로 잘못 넘겨도 잘린 조각이 새지 않게) ----------
    Test-Case 'S25' 'R6: the KUBECONFIG path passed as an argument value is masked before clipping' {
        $d = New-Fixture @(New-Phase)
        $deep = Join-Path $d ('k' * 70)
        New-Item -ItemType Directory -Path $deep | Out-Null
        $kc = Join-Path $deep 'kubeconfig.yaml'
        [IO.File]::WriteAllText($kc, $kubeconfigYaml, [Text.UTF8Encoding]::new($false))
        $r = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $kc, '-BaselineNode', 'jt-node-a') (Knobs 10 10) 60 $kc
        $calls = @(Get-Calls $d)
        Assert-Completed 'S25' $r $calls
        $all = $r.out + "`n" + $r.err
        Assert 'S25-1: -BaselineBootId <path>: FAIL reboot-pre-4 shows <KUBECONFIG> and no fragment of the path' ($r.code -eq 1 -and (Has-Text $r.out "-BaselineBootId '<KUBECONFIG>' is not a boot ID") -and -not (Has-Text $all 'reboottest-') -and -not (Has-Text $all 'kkkkkkkkkk')) (Format-Result $r)
        $r2 = Invoke-Harness $d @('-AfterReboot', '-BaselineBootId', $oldBoot, '-BaselineNode', $kc) (Knobs 10 10) 60 $kc
        $all2 = $r2.out + "`n" + $r2.err
        Assert 'S25-2: -BaselineNode <path>: FAIL reboot-pre-4 shows <KUBECONFIG> and no fragment of the path' ($r2.code -eq 1 -and @(Lines-Starting $r2 'FAIL reboot-pre-4: ').Count -eq 1 -and (Has-Text $r2.out '<KUBECONFIG>') -and -not (Has-Text $all2 'reboottest-') -and -not (Has-Text $all2 'kkkkkkkkkk')) (Format-Result $r2)
        Assert 'S25-3: both refused before any kubectl call' (@(Get-Calls $d).Count -eq 0) (Format-Calls @(Get-Calls $d))
    }

    # ---------- G3: port-forward 수립 지연(실제 터널 너머 10–23 s 실측) — 확인 1회 상한 45 s · 걸린 시간 기록 ----------
    # 'pf' 기록의 elapsed = 가짜 kubectl이 port-forward로 불린 시각(첫 호출 기준) — 두 확인의 시작 간격으로 첫 확인의 길이를 잰다
    $pfStartGap = {
        param($calls)
        $pfs = @(Get-CallsOf $calls 'pf')
        if ($pfs.Count -lt 2) { return $null }
        return ([double]$pfs[1]['elapsed'] - [double]$pfs[0]['elapsed'])
    }
    # (가) 수립에 12 s가 걸리는 정상 복구 → 확인 한 번으로 PASS(상한 8 s였다면 매번 미충족)
    Test-Case 'S34' 'G3: port-forward takes 12s to establish (tunnel latency) -> one check waits it out -> PASS' {
        $d = New-Fixture @(New-Phase @{ vault = @(@{ sealed = $false; establishDelaySec = 12 }) })
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S34' $r $calls
        $p1 = @(Lines-Starting $r 'PASS reboot-1: ')
        $m = if ($p1.Count -eq 1) { [regex]::Match($p1[0], 'forward ready in (\d+\.\d)s, answered in (\d+\.\d)s\)') } else { $null }
        $timed = $null -ne $m -and $m.Success -and [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture) -ge 12.0 -and [double]::Parse($m.Groups[2].Value, [Globalization.CultureInfo]::InvariantCulture) -ge [double]::Parse($m.Groups[1].Value, [Globalization.CultureInfo]::InvariantCulture)
        Assert 'S34-1: exit 0 and PASS reboot-1 whose detail records the wait (forward ready in >= 12.0s, answered no earlier)' ($r.code -eq 0 -and $timed) (Format-Result $r)
        Assert 'S34-2: a single check waited out the 12s establishment (exactly one port-forward, one Forwarding line, one answered request)' ((Count-Calls $calls 'pf') -eq 1 -and (Count-Calls $calls 'pf-ready') -eq 1 -and (Count-Calls $calls 'pf-http') -eq 1) (Format-Calls $calls)
    }
    # (나) port-forward가 곧바로 죽는다(파드·엔드포인트 없음) → 그 확인은 바로 끝나고 다음 폴링으로 넘어간다(45 s를 기다리지 않는다)
    Test-Case 'S35' 'G3: port-forward exits immediately -> the check returns at once, the next poll passes' {
        $d = New-Fixture @(New-Phase @{ vault = @(@{ exitImmediately = $true }, @{ sealed = $false }) })
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S35' $r $calls
        $gap = & $pfStartGap $calls
        Assert 'S35-1: exit 0 and PASS reboot-1 on the second port-forward' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-1: ').Count -eq 1 -and (Count-Calls $calls 'pf') -eq 2) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert 'S35-2: the failed check did not wait for the 45s cap (next port-forward started < 10s later)' ($null -ne $gap -and $gap -lt 10) "gap=$gap :: $(Format-Calls $calls)"
        $waitExit = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: ') -and [regex]::IsMatch($_, 'reboot-1\(deadline \d+s: port-forward exited after \d+\.\ds \(exit=1\)') })
        Assert 'S35-3: the waiting line records the early exit with its duration ("port-forward exited after N.Ns (exit=1)")' ($waitExit.Count -ge 1) (Format-Result $r)
    }
    # (다) 수립이 끝까지 안 됨(가짜는 90 s 뒤에야 줄을 낸다) → 그 확인은 45 s 근처에서 미충족으로 끝나고, 다음 확인(새 port-forward)이 통과
    #   상한은 손잡이로 줄이지 않는다(실제 기본값을 그대로 시험 — 약 50 s 걸린다).
    Test-Case 'S36' 'G3: port-forward never establishes -> that check ends unmet near the 45s cap, the next one passes' {
        $d = New-Fixture @(New-Phase @{ vault = @(@{ sealed = $false; establishDelaySec = 90 }, @{ sealed = $false }) })
        $r = Invoke-Harness $d $afterArgs (Knobs 120 60) 150
        $calls = @(Get-Calls $d)
        Assert-Completed 'S36' $r $calls
        $gap = & $pfStartGap $calls
        $firstReady = @(Get-CallsOf $calls 'pf-ready' | Where-Object { [int]$_['idx'] -eq 1 })
        Assert 'S36-1: exit 0 and PASS reboot-1 on the second port-forward; the first never printed its Forwarding line' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-1: ').Count -eq 1 -and (Count-Calls $calls 'pf') -eq 2 -and $firstReady.Count -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert 'S36-2: the first check ended near the 45s cap (next port-forward started 44..56s later), not at 8s and not at 90s' ($null -ne $gap -and $gap -ge 44 -and $gap -le 56) "gap=$gap :: $(Format-Calls $calls)"
        $waitCap = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: ') -and (Has-Text $_ 'seal-status not answered within 45s via port-forward') -and (Has-Text $_ "no 'Forwarding' line after") })
        Assert 'S36-3: the waiting line says "not answered within 45s" and "no Forwarding line after N.Ns"' ($waitCap.Count -ge 1) (Format-Result $r)
    }

    # ---------- H2: 0초 기준점 = 마지막으로 옛 부팅을 본 관측(armed 시작) ----------
    # (가) 옛 부팅이 마감(20 s)보다 오래(가짜 시계로 약 27 s 이상) 보인다 → 재부팅(불통 한 라운드) → 곧바로 복구 → PASS.
    #   경과 초는 기준점 기준이라 실행 시간보다 훨씬 작다. 0초가 스크립트 시작이었다면 reboot-0은 옛 부팅을 보는 동안 20 s에 만료됐다(RED).
    #   -ArmTimeoutMinutes 5(유효한 값)로 매개변수 경로도 함께 지난다. (바)도 여기서 본다(옛 부팅 관측 >= 8번에 armed 줄 <= 2).
    #   불통 단계는 whoami 2회: armed였던 첫 불통 관측은 도달 실패한 호출을 한 번 더 하고(A — 수정 지시서 6) 그것도 실패해야 기준점이 굳는다.
    Test-Case 'S37' 'H2: the old boot stays up longer than the deadline, then reboots and recovers -> PASS counted from the last old-boot observation' {
        $pre = New-PrePhase @{ whoamiCalls = 16 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $d = New-Fixture @($pre, $down, (New-Phase))
        $r = Invoke-Harness $d ($afterArgs + @('-ArmTimeoutMinutes', '5')) (Knobs 20 20) 180
        $calls = @(Get-Calls $d)
        Assert-Completed 'S37' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S37-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $p0 = @(Lines-Starting $r 'PASS reboot-0: ')
        $mAt = if ($p0.Count -eq 1) { [regex]::Match($p0[0], ' -- met at (\d+)s \(deadline 20s\)') } else { $null }
        $metAt = if ($null -ne $mAt -and $mAt.Success) { [int]$mAt.Groups[1].Value } else { $null }
        $oldWho = @(Get-CallsOf $calls 'whoami' 0)
        $oldSpan = if ($oldWho.Count -ge 2) { [double]$oldWho[$oldWho.Count - 1]['elapsed'] - [double]$oldWho[0]['elapsed'] } else { 0.0 }
        Assert 'S37-2: reboot-0 "met at" counts from the zero point (<= 15s and >= 20s below the run time) although the old boot was visible longer than the 20s deadline (>= 22s on the fake clock)' ($null -ne $metAt -and $metAt -le 15 -and ($r.wall - $metAt) -ge 20 -and $oldSpan -ge 22) "metAt=$metAt wall=$([Math]::Round([double]$r.wall, 1)) oldSpan=$oldSpan :: $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S37-3: exactly one "zero point fixed at" line and the summary repeats it (last observation of the old boot)' ($fixed.Count -eq 1 -and $null -ne $z -and (Test-Same $z.utc $fixed[0]) -and (Test-Same $z.why 'last observation of the old boot') -and @(Lines-Starting $r $zeroScriptStartLine).Count -eq 0) (Format-Result $r)
        $armed = @(Get-ArmedLines $r)
        $unchangedWaits = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: reboot-0(') -and (Has-Text $_ 'bootID unchanged') })
        Assert 'S37-4: (바) >= 8 old-boot observations produced 1..2 armed lines (the first says "arm timeout in 5m") and no per-poll waiting lines while armed' ((Count-Calls $calls 'nodes' 0) -ge 8 -and $armed.Count -ge 1 -and $armed.Count -le 2 -and $armed[0].EndsWith('(arm timeout in 5m)', [StringComparison]::Ordinal) -and $unchangedWaits.Count -eq 0) "oldBootNodes=$(Count-Calls $calls 'nodes' 0) armed=$($armed.Count) unchangedWaits=$($unchangedWaits.Count) :: $(Format-Result $r)"
        Assert 'S37-5: the polling line shows the arm timeout from -ArmTimeoutMinutes 5' (@(@(Lines-Starting $r 'polling reboot-0..4 (') | Where-Object { $_.EndsWith('; arm timeout 5 minutes)', [StringComparison]::Ordinal) }).Count -eq 1) (Format-Result $r)
    }
    # (나) J1: 옛 부팅 → 호출 실패(armed라 한 번 더 하고 그것도 실패 — whoami 2회) → 옛 부팅 세 번(세 번째 관측에서 기준점이 다시 움직인다) → 재부팅 → 복구.
    #   기준점은 굳었다가(줄 1) 세 번째 연속 관측에서 다시 움직이고 다시 굳는다(줄 2) — 마지막 기준점은 그 세 번째 관측이다(가짜 시계로 대조).
    #   C-2도 여기서 본다: 옛 bootID + Ready=True(New-PrePhase)는 굳은 뒤에도 옛 부팅으로 세어진다(세 번째에 다시 armed).
    Test-Case 'S38' 'J1: old boot -> one failed call -> old boot 3 times in a row (moves again at the third) -> reboot -> recovery' {
        $pre1 = New-PrePhase @{ name = 'old-boot-1'; whoamiCalls = 2 }
        $blip = New-Phase @{ name = 'call-failure'; whoamiCalls = 2; api = 'down' }
        $pre2 = New-PrePhase @{ name = 'old-boot-2'; whoamiCalls = 3 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $d = New-Fixture @($pre1, $blip, $pre2, $down, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S38' $r $calls
        Assert 'S38-1: exit 0 and PASS reboot-0' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1) (Format-Result $r)
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S38-2: two "zero point fixed at" lines, the second later than the first, and the summary reports the second' ($fixed.Count -eq 2 -and [string]::CompareOrdinal($fixed[1], $fixed[0]) -gt 0 -and $null -ne $z -and (Test-Same $z.utc $fixed[1]) -and (Test-Same $z.why 'last observation of the old boot')) "fixed=[$($fixed -join ', ')] :: $(Format-Result $r)"
        $stay = @(Get-StayZeros $r)
        Assert 'S38-3: one "seen again (1 of 3)" line staying at the first fixed zero point, one "seen 3 times in a row" note, two armed lines; every phase observed' ($stay.Count -eq 1 -and $fixed.Count -ge 1 -and (Test-Same $stay[0] $fixed[0]) -and @(Get-RearmNotes $r).Count -eq 1 -and @(Get-ArmedLines $r).Count -eq 2 -and @(0..4 | Where-Object { (Count-Calls $calls 'whoami' $_) -ge 1 }).Count -eq 5) "stay=[$($stay -join ', ')] notes=$(@(Get-RearmNotes $r).Count) armed=$(@(Get-ArmedLines $r).Count) :: $(Format-Result $r)"
        # 마지막 기준점 = 둘째 구간의 세 번째 관측의 시작: UTC(둘째 구간 whoami #2) < 기준점 <= UTC(둘째 구간 whoami #3)
        $t0u = Get-FakeT0Utc $d
        $w = @(Get-CallsOf $calls 'whoami' 2)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $ok4 = $null -ne $t0u -and $null -ne $zu -and $w.Count -eq 3 -and $zu -gt (Get-CallUtc $t0u $w[1]) -and $zu -le (Get-CallUtc $t0u $w[2])
        Assert 'S38-4: the final zero point is the start of the third old-boot observation after the failure (between the 2nd and 3rd whoami of that stretch on the fake clock)' $ok4 "zero=$(if ($null -ne $z) { $z.utc }) w=[$((@($w | ForEach-Object { (Get-CallUtc $t0u $_).ToString('HH:mm:ss.fff', [Globalization.CultureInfo]::InvariantCulture) })) -join ', ')]"
    }
    # (가) J1: 재부팅 뒤의 낡은 bootID — 옛 부팅(armed) → 불통 → 옛 bootID 두 번(API는 돌아왔지만 kubelet이 아직 새 status를 올리지 않음)
    #   → 새 bootID · 복구. 연속 세 번이 아니므로 기준점은 불통 전의 마지막 옛 부팅 관측에 머물고, PASS 줄의 경과 초가 불통 구간을 포함한다.
    #   수정 4까지의 규칙(옛 부팅마다 기준점을 옮김)이면 기준점이 낡은 관측으로 옮겨져 경과 초가 작게 나온다(RED — 경과 초의 하한으로 단언).
    #   불통 단계의 whoami 2회는 armed였던 첫 불통 관측의 호출 + 재시도(A — 둘 다 실패해 굳는다)다.
    Test-Case 'S40' 'J1: stale old bootID right after the reboot (seen twice) does not move the zero point' {
        $pre = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 2 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $stale = New-PrePhase @{ name = 'stale-old-bootid'; whoamiCalls = 2 }
        $d = New-Fixture @($pre, $down, $stale, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S40' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S40-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        $stay = @(Get-StayZeros $r)
        Assert 'S40-2: the zero point is fixed once (at the outage) and stays there: one "seen again (1 of 3)" line at that zero point, no "3 times in a row" note, one armed line, summary = that zero point' ($fixed.Count -eq 1 -and $stay.Count -eq 1 -and (Test-Same $stay[0] $fixed[0]) -and @(Get-RearmNotes $r).Count -eq 0 -and @(Get-ArmedLines $r).Count -eq 1 -and $null -ne $z -and (Test-Same $z.utc $fixed[0]) -and (Test-Same $z.why 'last observation of the old boot')) "fixed=[$($fixed -join ', ')] stay=[$($stay -join ', ')] notes=$(@(Get-RearmNotes $r).Count) armed=$(@(Get-ArmedLines $r).Count) :: $(Format-Result $r)"
        # 기준점 = 불통 전의 마지막 옛 부팅 관측(첫 구간 whoami #1 < 기준점 <= 첫 구간 whoami #2, 그리고 낡은 관측보다 앞)
        $t0u = Get-FakeT0Utc $d
        $w0 = @(Get-CallsOf $calls 'whoami' 0)
        $wStale = @(Get-CallsOf $calls 'whoami' 2)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $ok3 = $null -ne $t0u -and $null -ne $zu -and $w0.Count -eq 2 -and $wStale.Count -ge 1 -and $zu -gt (Get-CallUtc $t0u $w0[0]) -and $zu -le (Get-CallUtc $t0u $w0[1]) -and $zu -lt (Get-CallUtc $t0u $wStale[0])
        Assert 'S40-3: the zero point is the last old-boot observation before the outage, not a stale one after it (fake clock)' $ok3 "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
        # PASS 줄의 경과 초 >= (가짜 시계) 복구를 충족한 get nodes - 불통 전 마지막 옛 부팅 whoami  — 불통·낡은 구간을 포함한다
        $m0 = Get-MetSec $r 'reboot-0'
        $nodeCalls = @(Get-CallsOf $calls 'nodes')
        $bound = if ($nodeCalls.Count -gt 0 -and $w0.Count -gt 0) { [Math]::Floor([double]$nodeCalls[$nodeCalls.Count - 1]['elapsed'] - [double]$w0[$w0.Count - 1]['elapsed']) } else { $null }
        Assert 'S40-4: reboot-0 "met at" (from the zero point) includes the outage and the stale observations (>= the fake-clock gap from the last pre-outage old-boot observation)' ($null -ne $m0 -and $null -ne $bound -and $m0 -ge $bound) "metAt=$m0 bound=$bound :: $(Format-Result $r)"
    }
    # (다) J1: 일시 오류(armed라 한 번 더 하고 그것도 실패 — whoami 2회) 뒤 옛 부팅이 두 번만 보이고 곧 재부팅 → 기준점은 오류 전 관측에 머문다
    #   (엄격한 쪽) · 복구가 마감 안이면 PASS. 불통의 첫 관측은 연속 2라 한 번 더 하고 그것도 실패한다(불통 단계 whoami 2회).
    Test-Case 'S41' 'J1: after a transient failure the old boot is seen only twice, then the reboot starts -> the zero point stays before the failure' {
        $pre1 = New-PrePhase @{ name = 'old-boot-1'; whoamiCalls = 2 }
        $blip = New-Phase @{ name = 'call-failure'; whoamiCalls = 2; api = 'down' }
        $pre2 = New-PrePhase @{ name = 'old-boot-2'; whoamiCalls = 2 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $d = New-Fixture @($pre1, $blip, $pre2, $down, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S41' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S41-1: exit 0 and PASS reboot-0..4 (recovery within the deadline counted from before the failure)' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        $stay = @(Get-StayZeros $r)
        Assert 'S41-2: fixed once at the failure and never moved again: one "seen again (1 of 3)" line, no "3 times in a row" note, one armed line, summary = that zero point' ($fixed.Count -eq 1 -and $stay.Count -eq 1 -and (Test-Same $stay[0] $fixed[0]) -and @(Get-RearmNotes $r).Count -eq 0 -and @(Get-ArmedLines $r).Count -eq 1 -and $null -ne $z -and (Test-Same $z.utc $fixed[0])) "fixed=[$($fixed -join ', ')] stay=[$($stay -join ', ')] :: $(Format-Result $r)"
        $t0u = Get-FakeT0Utc $d
        $w0 = @(Get-CallsOf $calls 'whoami' 0)
        $w2 = @(Get-CallsOf $calls 'whoami' 2)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $ok3 = $null -ne $t0u -and $null -ne $zu -and $w0.Count -eq 2 -and $w2.Count -ge 1 -and $zu -gt (Get-CallUtc $t0u $w0[0]) -and $zu -le (Get-CallUtc $t0u $w0[1]) -and $zu -lt (Get-CallUtc $t0u $w2[0])
        Assert 'S41-3: the zero point is the last old-boot observation before the failure (fake clock)' $ok3 "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
        $m0 = Get-MetSec $r 'reboot-0'
        $nodeCalls = @(Get-CallsOf $calls 'nodes')
        $bound = if ($nodeCalls.Count -gt 0 -and $w0.Count -gt 0) { [Math]::Floor([double]$nodeCalls[$nodeCalls.Count - 1]['elapsed'] - [double]$w0[$w0.Count - 1]['elapsed']) } else { $null }
        Assert 'S41-4: reboot-0 "met at" includes the failure, the two old-boot observations and the outage (>= the fake-clock gap from the last observation before the failure)' ($null -ne $m0 -and $null -ne $bound -and $m0 -ge $bound) "metAt=$m0 bound=$bound :: $(Format-Result $r)"
    }
    # ---------- A(수정 지시서 6): 직전 관측이 옛 부팅이었으면 도달 실패한 호출을 그 자리에서 한 번 더 ----------
    #   실제 경로의 호출은 가끔 실패한다(여섯–여덟 번에 한 번). 실패마다 기준점이 굳으면 대기 시간의 절반 이상이 굳은 상태가 되고, 그때 재부팅이
    #   시작되면 모든 경과 초에 (재부팅 시작 - 굳은 기준점)이 더해진다(재리뷰 3 발견 A). 가짜의 whoamiFailAt / nodesFailAt로 호출 하나만 실패시킨다.
    # (A-1) armed → 신원 호출 첫 번 실패(재시도 성공) → 다음 관측의 노드 조회 첫 번 실패(재시도 성공) → 불통(armed였던 첫 불통 관측은 재시도까지 실패) →
    #   복구 → PASS. 기준점은 불통 전까지 굳지 않고, 마지막에는 "다시 한 노드 조회"의 시작이다 — 경과 초가 두 실패를 포함하지 않는다(가짜 시계로 단언).
    #   수정 전에는 첫 실패에서 기준점이 굳는다(RED). E-1도 여기서 본다: met 줄 · PASS 줄의 'observation UTC <시작> .. <끝>'.
    Test-Case 'S42' 'A-1: armed; whoami fails once and the immediate retry answers, then get nodes the same -> the zero point does not fix before the outage; reboot -> PASS' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 2 }
        $wBlip = New-PrePhase @{ name = 'whoami-blip'; whoamiCalls = 2; whoamiFailAt = @(1) }
        $nBlip = New-PrePhase @{ name = 'nodes-blip'; whoamiCalls = 1; nodesFailAt = @(1) }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 3; api = 'down' }
        $d = New-Fixture @($old, $wBlip, $nBlip, $down, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S42' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S42-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S42-2: the zero point fixed only once, at the outage: no "seen again" line, no "3 times in a row" note, one armed line, and the summary repeats it' ($fixed.Count -eq 1 -and @(Get-StayZeros $r).Count -eq 0 -and @(Get-RearmNotes $r).Count -eq 0 -and @(Get-ArmedLines $r).Count -eq 1 -and $null -ne $z -and (Test-Same $z.utc $fixed[0]) -and (Test-Same $z.why 'last observation of the old boot')) "fixed=[$($fixed -join ', ')] :: $(Format-Result $r)"
        $wb = @(Get-CallsOf $calls 'whoami' 1)
        $nb = @(Get-CallsOf $calls 'nodes' 2)
        $okCalls = $wb.Count -eq 2 -and (Test-Same "$($wb[0]['served'])" 'transport-fail') -and (Count-Calls $calls 'nodes' 1) -eq 1 -and (Count-Calls $calls 'whoami' 2) -eq 1 -and $nb.Count -eq 2 -and (Test-Same "$($nb[0]['served'])" 'transport-fail')
        Assert 'S42-3: each failed call was retried once, at once, inside the same observation (whoami-blip: 2 whoami + 1 get nodes; nodes-blip: 1 whoami + 2 get nodes)' $okCalls (Format-Calls $calls)
        $t0u = Get-FakeT0Utc $d
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $okZero = $null -ne $t0u -and $null -ne $zu -and $nb.Count -eq 2 -and $zu -gt (Get-CallUtc $t0u $nb[0]) -and $zu -le (Get-CallUtc $t0u $nb[1])
        Assert 'S42-4: the zero point is the start of the retried get nodes (later than its failed first attempt), so the elapsed seconds include neither failure (fake clock)' $okZero "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
        Assert 'S42-5: one "retried:" progress line for the three retried observations of the armed stretch (not one per retry), and the waiting line after the outage shows "retried:" first in the reboot-0 detail' (@(Get-RetryLines $r).Count -eq 1 -and @(Get-RetriedWaits $r).Count -ge 1) "retried=$(@(Get-RetryLines $r).Count) retriedWaits=$(@(Get-RetriedWaits $r).Count) :: $(Format-Result $r)"
        # E-1: met 줄과 PASS 줄의 관측 UTC(밀리초) — 형식 · 시작 <= 끝 · 두 줄이 같은 관측 · reboot-0을 충족한 get nodes 호출이 그 사이(가짜 시계)
        $badE = @()
        foreach ($i in 0..4) {
            $pl = @(Lines-Starting $r "PASS reboot-${i}: ")
            $ml = @(@(Get-Lines $r) | Where-Object { [regex]::IsMatch($_, '\A  \[\d+s\] reboot-' + $i + ' met -- observation UTC ') })
            $pu = if ($pl.Count -eq 1) { Get-ObsUtc $pl[0] } else { $null }
            $mu = if ($ml.Count -eq 1) { Get-ObsUtc $ml[0] } else { $null }
            if ($null -eq $pu -or $null -eq $mu -or $pu.start -gt $pu.end -or $pu.start -ne $mu.start -or $pu.end -ne $mu.end) { $badE += "reboot-$i" }
        }
        Assert 'S42-6 (E-1): every met line and PASS line (reboot-0..4) carries "observation UTC <start> .. <end>" in ms, start <= end, the same observation on both lines' ($badE.Count -eq 0) "bad=[$($badE -join ', ')] :: $(Format-Result $r)"
        $p0 = @(Lines-Starting $r 'PASS reboot-0: ')
        $o0 = if ($p0.Count -eq 1) { Get-ObsUtc $p0[0] } else { $null }
        $metNodes = @(Get-CallsOf $calls 'nodes' 4)
        $nu = if ($metNodes.Count -ge 1 -and $null -ne $t0u) { Get-CallUtc $t0u $metNodes[$metNodes.Count - 1] } else { $null }
        $inv = [Globalization.CultureInfo]::InvariantCulture
        Assert 'S42-7 (E-1): the get nodes call that met reboot-0 lies inside that observation''s UTC range (fake clock)' ($null -ne $o0 -and $null -ne $nu -and $o0.start -lt $nu -and $nu -lt $o0.end) "obs=$(if ($null -ne $o0) { "$($o0.start.ToString('HH:mm:ss.fff', $inv)) .. $($o0.end.ToString('HH:mm:ss.fff', $inv))" }) nodes=$(if ($null -ne $nu) { $nu.ToString('HH:mm:ss.fff', $inv) })"
    }
    # (A-2) armed → 호출과 재시도가 둘 다 실패 → 굳는다 → 옛 부팅 1번째 관측(연속 0이라 재시도 대상이 아니다 — 실패 없음) → 2번째 관측의 신원 호출 첫 번
    #   실패(재시도 성공) → 3번째 관측의 노드 조회 첫 번 실패(재시도 성공) → 연속 횟수가 끊기지 않아 세 번째에서 다시 armed(기준점 = 다시 한 노드 조회의
    #   시작) → 재부팅 → PASS. 수정 전에는 실패마다 연속 횟수가 0으로 돌아가 다시 armed가 되지 않는다(RED).
    Test-Case 'S43' 'A-2: fixed after a call and its retry both fail; the next old-boot observations each lose one call but the retry answers -> the streak survives and moves the zero point again at the third' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $dbl = New-Phase @{ name = 'call-and-retry-fail'; whoamiCalls = 2; api = 'down' }
        $o1 = New-PrePhase @{ name = 'old-1'; whoamiCalls = 1 }
        $o2 = New-PrePhase @{ name = 'old-2-whoami-blip'; whoamiCalls = 2; whoamiFailAt = @(1) }
        $o3 = New-PrePhase @{ name = 'old-3-nodes-blip'; whoamiCalls = 1; nodesFailAt = @(1) }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 3; api = 'down' }
        $d = New-Fixture @($old, $dbl, $o1, $o2, $o3, $down, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S43' $r $calls
        Assert 'S43-1: exit 0 and PASS reboot-0' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1) (Format-Result $r)
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        $stay = @(Get-StayZeros $r)
        Assert 'S43-2: fixed twice (the double failure, then the outage); one "seen again (1 of 3)" line at the first; one "3 times in a row" note; two armed lines; summary = the second' ($fixed.Count -eq 2 -and $stay.Count -eq 1 -and (Test-Same $stay[0] $fixed[0]) -and @(Get-RearmNotes $r).Count -eq 1 -and @(Get-ArmedLines $r).Count -eq 2 -and $null -ne $z -and (Test-Same $z.utc $fixed[1])) "fixed=[$($fixed -join ', ')] stay=[$($stay -join ', ')] notes=$(@(Get-RearmNotes $r).Count) armed=$(@(Get-ArmedLines $r).Count) :: $(Format-Result $r)"
        $okCalls = (Count-Calls $calls 'whoami' 1) -eq 2 -and (Count-Calls $calls 'nodes' 1) -eq 0 -and (Count-Calls $calls 'whoami' 2) -eq 1 -and (Count-Calls $calls 'nodes' 2) -eq 1 -and (Count-Calls $calls 'whoami' 3) -eq 2 -and (Count-Calls $calls 'nodes' 3) -eq 1 -and (Count-Calls $calls 'whoami' 4) -eq 1 -and (Count-Calls $calls 'nodes' 4) -eq 2
        Assert 'S43-3: retried exactly where the previous observation saw the old boot (double failure: 2 whoami; old-1: no retry; old-2: 2 whoami + 1 get nodes; old-3: 1 whoami + 2 get nodes)' $okCalls (Format-Calls $calls)
        $t0u = Get-FakeT0Utc $d
        $n4 = @(Get-CallsOf $calls 'nodes' 4)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $okZero = $null -ne $t0u -and $null -ne $zu -and $n4.Count -eq 2 -and $zu -gt (Get-CallUtc $t0u $n4[0]) -and $zu -le (Get-CallUtc $t0u $n4[1])
        Assert 'S43-4: the zero point moved again at the third old-boot observation, to the start of its retried get nodes (fake clock)' $okZero "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
        Assert 'S43-5: "retried:" lines, one per stretch: armed (the double failure), fixed (two retried observations), armed again (the outage) = 3 lines for 4 retried observations' (@(Get-RetryLines $r).Count -eq 3) "retried=$(@(Get-RetryLines $r).Count) :: $(Format-Result $r)"
    }
    # (A-3) 굳은 상태 · 연속 횟수 0에서는 재시도하지 않는다(재부팅으로 내려가 있는 구간으로 본다 — 관측이 길어지면 복구를 늦게 본다).
    #   get nodes가 계속 도달 실패하는 단계에서 관측 4번: armed였던 첫 관측만 다시 한다 → 그 단계의 whoami 4회 · get nodes 5회(호출 수로 단언).
    Test-Case 'S44' 'A-3: no retry while the zero point is fixed and the old-boot streak is 0 (call counts)' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 2 }
        $nd = New-PrePhase @{ name = 'nodes-unreachable'; whoamiCalls = 4; nodesFailAt = @(1..20) }
        $d = New-Fixture @($old, $nd, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S44' $r $calls
        Assert 'S44-1: exit 0 and PASS reboot-0' ($r.code -eq 0 -and @(Lines-Starting $r 'PASS reboot-0: ').Count -eq 1) (Format-Result $r)
        $w = Count-Calls $calls 'whoami' 1
        $n = Count-Calls $calls 'nodes' 1
        Assert 'S44-2: 4 observations while get nodes kept failing, only the first (armed) one retried: 4 whoami and 5 get nodes calls in that phase' ($w -eq 4 -and $n -eq 5) "whoami=$w nodes=$n :: $(Format-Calls $calls)"
        Assert 'S44-3: the zero point fixed once (at that first failed observation) and one "retried:" line' (@(Get-FixedZeros $r).Count -eq 1 -and @(Get-RetryLines $r).Count -eq 1) (Format-Result $r)
    }
    # (A-4) 재시도가 401 · 다른 신원을 만나도 신원 규칙은 그대로다(401 연속 두 번 = fatal · 다른 신원 = 즉시 fatal) — 401 자체는 판정 결과라 다시 하지 않는다.
    #   재시도한 관측은 401 셈에서 관측 하나다(첫 시도의 도달 실패가 셈을 0으로 돌리지도, 재시도의 401을 두 번 세지도 않는다).
    Test-Case 'S45' 'A-4: a retry that meets 401 or another identity keeps the identity rules; a 401 itself is never retried' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 2 }
        # (a) armed → whoami 도달 실패 → 재시도 401(1 of 2) → 다음 관측(굳음 · 연속 0 — 재시도 없음) 401 → fatal(2 of 2): 그 단계 whoami 정확히 3회
        $d = New-Fixture @($old, (New-Phase @{ name = 'unreachable-then-401'; whoamiFailAt = @(1); whoamiUnauthorized = $true }))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S45a' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        $retried401 = @(@(Get-RetriedWaits $r) | Where-Object { Has-Text $_ '401 (1 of 2 before fatal)' })
        Assert 'S45a-1: exit 1; the retried observation met 401 and counted once ("retried: ... 401 (1 of 2" in its waiting line); the next observation''s 401 is fatal "401 (2 of 2)"; whoami calls in that phase exactly 3, no get nodes' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] '401 (2 of 2)') -and $retried401.Count -eq 1 -and (Count-Calls $calls 'whoami' 1) -eq 3 -and (Count-Calls $calls 'nodes' 1) -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S45a' $r
        # (b) armed → 첫 시도가 401 → 다시 하지 않는다 → 다음 관측 401 → fatal: 그 단계 whoami 정확히 2회 · 'retried:' 줄 없음
        $d = New-Fixture @($old, (New-Phase @{ name = 'unauthorized'; whoamiUnauthorized = $true }))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S45b' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S45b-1: exit 1, fatal "401 (2 of 2)" at the second 401 observation; whoami calls in that phase exactly 2 (a 401 is not retried) and no "retried:" line' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] '401 (2 of 2)') -and (Count-Calls $calls 'whoami' 1) -eq 2 -and @(Get-RetryLines $r).Count -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        # (c) armed → whoami 도달 실패 → 재시도가 다른 신원 → 그 관측에서 바로 fatal: 그 단계 whoami 2회 · get nodes 0회
        $d = New-Fixture @($old, (New-Phase @{ name = 'unreachable-then-admin'; whoamiFailAt = @(1); user = 'system:admin' }))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S45c' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S45c-1: exit 1; the retry met another identity and that observation was fatal at once ("retried: context user is ''system:admin''" ... "refusing to run with non-agent-view credentials"); whoami calls in that phase exactly 2, no get nodes' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] "retried: context user is 'system:admin'") -and (Has-Text $f0[0] 'refusing to run with non-agent-view credentials') -and (Count-Calls $calls 'whoami' 1) -eq 2 -and (Count-Calls $calls 'nodes' 1) -eq 0) "$(Format-Result $r) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S45c' $r
    }
    # (A-5 · 지시서 밖 판정) 재시도한 관측은 다시 한 호출을 시작한 시각을 그 관측의 시작으로 본다(옛 부팅이면 기준점 · 충족이면 마감 판정 · UTC 표기).
    #   마감 전에 시작한 관측의 첫 get nodes가 15 s 걸려 마감(20 s) 뒤에 실패하고, 마감 뒤에 다시 한 호출이 새 bootID · Ready=True를 보면 late(FAIL)다 —
    #   재시도가 마감 뒤에 모은 증거로 PASS하지 않는다(재시도가 없던 때는 그 관측이 마감을 넘겨 끝난 미충족 = FAIL이었다). 관측 시작(첫 시도 앞)으로
    #   판정하면 PASS가 된다(변이로 확인).
    Test-Case 'S53' 'A (added): a retry that starts after the deadline and then meets reboot-0 is late, not a pass -- the retried call is the observation start' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $stale = New-PrePhase @{ name = 'stale-old-bootid'; whoamiCalls = 1 }
        $slow = New-Phase @{ name = 'new-boot-first-nodes-call-fails-slowly'; nodesFailAt = @(1); transportFailDelayMs = 15000 }
        $d = New-Fixture @($old, $down, $stale, $slow)
        $r = Invoke-Harness $d $afterArgs (Knobs 20 20) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S53' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S53-1: exit 1 and "FAIL reboot-0" met late (deadline 20s) by the retried observation ("retried:" detail)' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'met late at') -and (Has-Text $f0[0] 'after the deadline 20s') -and (Has-Text $f0[0] 'retried: ')) (Format-Result $r)
        $t0u = Get-FakeT0Utc $d
        $fixed = @(Get-FixedZeros $r)
        $zu = if ($fixed.Count -eq 1) { Parse-ZeroUtc $fixed[0] } else { $null }
        $n3 = @(Get-CallsOf $calls 'nodes' 3)
        $okPre = $null -ne $t0u -and $null -ne $zu -and $n3.Count -eq 2 -and ((Get-CallUtc $t0u $n3[0]) - $zu).TotalSeconds -le 20 -and ((Get-CallUtc $t0u $n3[1]) - $zu).TotalSeconds -gt 20
        Assert 'S53-2: precondition on the fake clock -- the slow first get nodes started before the deadline (<= 20s after the zero point) and the retry after it (> 20s)' $okPre "zero=$(if ($fixed.Count) { $fixed[0] }) :: $(Format-Calls $calls)"
        $fu = if ($f0.Count -eq 1) { Get-ObsUtc $f0[0] } else { $null }
        Assert 'S53-3 (E): the late FAIL line''s observation UTC starts at the retried call (after the slow first attempt failed, before the fake logged the retry)' ($null -ne $fu -and $null -ne $t0u -and $n3.Count -eq 2 -and $fu.start -lt (Get-CallUtc $t0u $n3[1]) -and $fu.start -gt (Get-CallUtc $t0u $n3[0]).AddSeconds(15)) (Format-Result $r)
        Assert-NotAttempted 'S53' $r
    }

    # ---------- B(수정 지시서 6): 굳은 채 재부팅 전에 마감이 지난 경우를 FAIL 문구로 구분한다 ----------
    # (B-1) armed → 호출과 재시도가 둘 다 실패(굳음) → 옛 부팅(연속 1) → 다시 둘 다 실패(연속 0) → 옛 부팅이 느리게(get nodes 15 s) 계속 —
    #   마지막 관측이 옛 부팅인 채 마감(25 s)을 넘긴다(앞 단계는 부하에서도 마감 전에 끝나고, 느린 관측 두 번이면 연속 세 번 전에 반드시 마감을 넘는다).
    #   판정(FAIL)과 종료 코드는 그대로이고 문구만 덧붙는다. 수정 전 하네스에는 그 문구가 없다(RED).
    Test-Case 'S46' 'B-1: the zero point is fixed and the old boot shows up again but never 3 times in a row; the deadline runs out before any reboot -> FAIL says no reboot was observed' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $dbl1 = New-Phase @{ name = 'call-and-retry-fail-1'; whoamiCalls = 2; api = 'down' }
        $o1 = New-PrePhase @{ name = 'old-1'; whoamiCalls = 1 }
        $dbl2 = New-Phase @{ name = 'call-and-retry-fail-2'; whoamiCalls = 2; api = 'down' }
        $slow = New-PrePhase @{ name = 'old-slow'; nodesDelayMs = 15000 }
        $d = New-Fixture @($old, $dbl1, $o1, $dbl2, $slow)
        $r = Invoke-Harness $d $afterArgs (Knobs 25 25) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S46' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        $fixed = @(Get-FixedZeros $r)
        Assert 'S46-1: exit 1 and "FAIL reboot-0" expired (not met within 25s) on an old-boot observation (bootID unchanged)' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'not met within 25s') -and (Has-Text $f0[0] 'node A has not rebooted yet (bootID unchanged)')) (Format-Result $r)
        Assert 'S46-2: the FAIL line adds "zero point fixed at <the fixed zero point> (last observation of the old boot); the old boot kept being seen after that but never 3 times in a row -- no reboot was observed; restart the harness"' ($f0.Count -eq 1 -and $fixed.Count -eq 1 -and (Has-Text $f0[0] "zero point fixed at $($fixed[0]) (last observation of the old boot); $bText")) (Format-Result $r)
        Assert-NotAttempted 'S46' $r
        $newServed = @(@(Get-CallsOf $calls 'nodes') | Where-Object { Has-Text $_['served'] $newBoot })
        Assert 'S46-3: never re-armed and never saw a new bootID: one fixed line, >= 2 "seen again" lines (one per old-boot stretch), no "3 times in a row" note, one armed line' ($fixed.Count -eq 1 -and @(Get-StayZeros $r).Count -ge 2 -and @(Get-RearmNotes $r).Count -eq 0 -and @(Get-ArmedLines $r).Count -eq 1 -and $newServed.Count -eq 0) "stay=$(@(Get-StayZeros $r).Count) :: $(Format-Result $r)"
        $fu = if ($f0.Count -eq 1) { Get-ObsUtc $f0[0] } else { $null }
        Assert 'S46-4 (E): the expired FAIL line carries the last observation UTC in ms (start <= end, at least the 15s get nodes apart)' ($null -ne $fu -and ($fu.end - $fu.start).TotalSeconds -ge 15) (Format-Result $r)
    }

    # ---------- C(수정 지시서 6): "옛 부팅이 살아 있다"는 Ready=True일 때만 ----------
    # (C-1) armed → 불통 → 옛 bootID + Ready=Unknown이 계속(재부팅 뒤 kubelet이 끝내 status를 못 올리는 고장) → 옛 부팅이 아니므로 다시 armed가 되지 않고
    #   reboot-0은 마감(30 s)에 만료된다 — arm 제한(50 s)까지 가지 않는다. 수정 전에는 세 번째 관측에서 다시 armed → arm 제한에서 끝난다(RED).
    Test-Case 'S47' 'C-1: after the outage node A keeps reporting the baseline bootID with Ready=Unknown -> not the old boot: no re-arm; reboot-0 expires at the deadline, not at the arm timeout' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $stale = New-PrePhase @{ name = 'stale-ready-unknown'; nodes = @(@{ name = 'jt-node-a'; bootID = $oldBoot; ready = 'Unknown'; heartbeat = $preHeartbeat }) }
        $d = New-Fixture @($old, $down, $stale)
        $r = Invoke-Harness $d $afterArgs (Knobs 30 30 1 50) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S47' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S47-1: exit 1 and "FAIL reboot-0" not met within 30s with the reason "ready=Unknown with the baseline bootID" (not "no reboot observed")' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'not met within 30s') -and (Has-Text $f0[0] 'node A ready=Unknown with the baseline bootID') -and -not (Has-Text $f0[0] 'no reboot observed')) (Format-Result $r)
        Assert 'S47-2: >= 3 such observations, none counted as the old boot: one armed line, one fixed line, no "seen again" line, no "3 times in a row" note' ((Count-Calls $calls 'nodes' 2) -ge 3 -and @(Get-ArmedLines $r).Count -eq 1 -and @(Get-FixedZeros $r).Count -eq 1 -and @(Get-StayZeros $r).Count -eq 0 -and @(Get-RearmNotes $r).Count -eq 0) "staleNodes=$(Count-Calls $calls 'nodes' 2) :: $(Format-Result $r)"
        $unkWaits = @(@(Get-Lines $r) | Where-Object { (Has-Text $_ 'waiting: reboot-0(') -and (Has-Text $_ 'node A ready=Unknown with the baseline bootID') })
        Assert 'S47-3: the waiting lines keep that reason inside the 120-char clip, and the FAIL line has no "no reboot was observed" text (its last observation was not the old boot)' ($unkWaits.Count -ge 2 -and $f0.Count -eq 1 -and -not (Has-Text $f0[0] 'no reboot was observed')) (Format-Result $r)
        Assert-NotAttempted 'S47' $r
    }
    # (C-2) 옛 bootID + Ready=True는 지금처럼 옛 부팅 — 대조: 불통 뒤 옛 bootID + Ready=Unknown 세 번은 연속 횟수를 올리지 않고(옛 부팅이 아니다),
    #   이어지는 Ready=True 세 번이 기준점을 다시 움직인다(그 세 번째 관측의 시작) → 재부팅 → PASS. 수정 전에는 Unknown 세 번이 옛 부팅으로 세어진다(RED).
    Test-Case 'S48' 'C-2: the baseline bootID counts as the old boot with Ready=True only: 3 Ready=Unknown observations leave the streak at 0, the next 3 Ready=True ones move the zero point again' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $unk = New-PrePhase @{ name = 'old-bootid-ready-unknown'; whoamiCalls = 3; nodes = @(@{ name = 'jt-node-a'; bootID = $oldBoot; ready = 'Unknown'; heartbeat = $preHeartbeat }) }
        $tru = New-PrePhase @{ name = 'old-bootid-ready-true'; whoamiCalls = 3 }
        $down2 = New-Phase @{ name = 'api-down-2'; whoamiCalls = 3; api = 'down' }
        $d = New-Fixture @($old, $down, $unk, $tru, $down2, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 60 40) 150
        $calls = @(Get-Calls $d)
        Assert-Completed 'S48' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S48-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $unkIdx = @(Get-LineIndexes $r { param($l) Has-Text $l 'node A ready=Unknown with the baseline bootID' })
        $stayIdx = @(Get-LineIndexes $r { param($l) $l.StartsWith('  old boot seen again after the zero point was fixed', [StringComparison]::Ordinal) })
        $noteIdx = @(Get-LineIndexes $r { param($l) $l.StartsWith('  note: the old boot was seen 3 times in a row', [StringComparison]::Ordinal) })
        $order = $unkIdx.Count -ge 3 -and $stayIdx.Count -eq 1 -and $noteIdx.Count -eq 1 -and $stayIdx[0] -gt $unkIdx[$unkIdx.Count - 1] -and $noteIdx[0] -gt $stayIdx[0]
        Assert 'S48-2: the 3 Ready=Unknown observations were reported as not the old boot (>= 3 lines with "node A ready=Unknown with the baseline bootID"); the one "seen again (1 of 3)" line and the one "3 times in a row" note come only after them' $order "unk=[$($unkIdx -join ',')] stay=[$($stayIdx -join ',')] note=[$($noteIdx -join ',')] :: $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S48-3: fixed twice (the outage, the outage again), two armed lines, summary = the second fixed zero point' ($fixed.Count -eq 2 -and @(Get-ArmedLines $r).Count -eq 2 -and $null -ne $z -and (Test-Same $z.utc $fixed[1])) "fixed=[$($fixed -join ', ')] :: $(Format-Result $r)"
        $t0u = Get-FakeT0Utc $d
        $w3 = @(Get-CallsOf $calls 'whoami' 3)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        Assert 'S48-4: the zero point moved again at the third Ready=True observation (between its 2nd and 3rd whoami on the fake clock)' ($null -ne $t0u -and $null -ne $zu -and $w3.Count -eq 3 -and $zu -gt (Get-CallUtc $t0u $w3[1]) -and $zu -le (Get-CallUtc $t0u $w3[2])) "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
        Assert 'S48-5: one get nodes per Ready=Unknown observation (3 whoami, 3 get nodes -- no retry while the streak is 0)' ((Count-Calls $calls 'whoami' 2) -eq 3 -and (Count-Calls $calls 'nodes' 2) -eq 3) (Format-Calls $calls)
    }

    # ---------- 재리뷰 3 §5.2 가운데 S34–S41이 덮지 않는 시나리오 ----------
    # (Z1-3) 문서화된 잔여(잘못된 PASS 쪽): 불통 뒤 낡은 옛 bootID(Ready=True)가 연속 세 번 보이면 기준점이 다시 움직여 불통 뒤로 간다(재부팅 뒤 낡은
    #   bootID 창이 폴링 간격 둘 이상 이어지는 경우 — 실측 전). 그 동작을 고정해 둔다(바뀌면 이 케이스가 드러낸다). k <= 2는 S40(두 번 — 그대로)이 덮는다.
    Test-Case 'S49' 'Z1-3 (documented residual): a stale old bootID seen 3 times in a row right after the outage moves the zero point past the outage' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 2 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 2; api = 'down' }
        $stale = New-PrePhase @{ name = 'stale-old-bootid'; whoamiCalls = 3 }
        $d = New-Fixture @($old, $down, $stale, (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 120
        $calls = @(Get-Calls $d)
        Assert-Completed 'S49' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S49-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S49-2: fixed twice (the outage, then the new bootID), one "seen again", one "3 times in a row" note, two armed lines; summary = the second' ($fixed.Count -eq 2 -and @(Get-StayZeros $r).Count -eq 1 -and @(Get-RearmNotes $r).Count -eq 1 -and @(Get-ArmedLines $r).Count -eq 2 -and $null -ne $z -and (Test-Same $z.utc $fixed[1])) "fixed=[$($fixed -join ', ')] :: $(Format-Result $r)"
        $t0u = Get-FakeT0Utc $d
        $ws = @(Get-CallsOf $calls 'whoami' 2)
        $wd = @(Get-CallsOf $calls 'whoami' 1)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        Assert 'S49-3: the final zero point is the start of the third stale observation, later than every api-down call (fake clock) -- reboot-0 counts from after the outage' ($null -ne $t0u -and $null -ne $zu -and $ws.Count -eq 3 -and $wd.Count -ge 1 -and $zu -gt (Get-CallUtc $t0u $ws[1]) -and $zu -le (Get-CallUtc $t0u $ws[2]) -and $zu -gt (Get-CallUtc $t0u $wd[$wd.Count - 1])) "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
    }
    # (Z2 · Z4) 첫 관측부터 옛 부팅 네 번 → 하네스가 불통을 보지 못한 채 새 bootID → 기준점 = 마지막 옛 부팅 관측의 시작 · 요약 '(last observation of the old boot)'
    Test-Case 'S50' 'Z2/Z4: old boot from the first observation (4 times), then the new bootID without an observed outage -> zero point = the last old-boot observation' {
        $d = New-Fixture @((New-PrePhase @{ name = 'old-boot'; whoamiCalls = 4 }), (New-Phase))
        $r = Invoke-Harness $d $afterArgs (Knobs 40 40) 90
        $calls = @(Get-Calls $d)
        Assert-Completed 'S50' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S50-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        Assert 'S50-2: armed once and fixed once (by the new-bootID observation), no "seen again" / note line; summary "(last observation of the old boot)" = the fixed zero point' ($fixed.Count -eq 1 -and @(Get-ArmedLines $r).Count -eq 1 -and @(Get-StayZeros $r).Count -eq 0 -and @(Get-RearmNotes $r).Count -eq 0 -and $null -ne $z -and (Test-Same $z.utc $fixed[0]) -and (Test-Same $z.why 'last observation of the old boot') -and @(Lines-Starting $r $zeroScriptStartLine).Count -eq 0) (Format-Result $r)
        $t0u = Get-FakeT0Utc $d
        $w0 = @(Get-CallsOf $calls 'whoami' 0)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        Assert 'S50-3: the zero point is the start of the 4th old-boot observation (between its 3rd and 4th whoami on the fake clock)' ($null -ne $t0u -and $null -ne $zu -and $w0.Count -eq 4 -and $zu -gt (Get-CallUtc $t0u $w0[2]) -and $zu -le (Get-CallUtc $t0u $w0[3])) "zero=$(if ($null -ne $z) { $z.utc }) :: $(Format-Calls $calls)"
    }
    # (Z3) 옛 부팅과 "호출 + 재시도 실패"가 번갈아 온다(old, fail, old, fail, old, fail, old, old) → 연속 세 번이 끝내 안 나와 기준점은 첫 실패 앞의
    #   옛 부팅 관측에 머문다(엄격한 쪽) → 재부팅 → PASS. 옛 부팅 다음의 실패는 매번 재시도까지 실패한다(그 단계 whoami 2회).
    Test-Case 'S51' 'Z3: old boot and double failures alternate -> the zero point stays at the observation before the first failure -> reboot -> PASS' {
        $ph = @(
            (New-PrePhase @{ name = 'old-0'; whoamiCalls = 1 })
            (New-Phase @{ name = 'fail-1'; whoamiCalls = 2; api = 'down' })
            (New-PrePhase @{ name = 'old-1'; whoamiCalls = 1 })
            (New-Phase @{ name = 'fail-2'; whoamiCalls = 2; api = 'down' })
            (New-PrePhase @{ name = 'old-2'; whoamiCalls = 1 })
            (New-Phase @{ name = 'fail-3'; whoamiCalls = 2; api = 'down' })
            (New-PrePhase @{ name = 'old-3'; whoamiCalls = 2 })
            (New-Phase)
        )
        $d = New-Fixture $ph
        $r = Invoke-Harness $d $afterArgs (Knobs 60 40) 150
        $calls = @(Get-Calls $d)
        Assert-Completed 'S51' $r $calls
        $passIds = @(0..4 | Where-Object { @(Lines-Starting $r "PASS reboot-${_}:").Count -eq 1 })
        Assert 'S51-1: exit 0 and PASS reboot-0..4' ($r.code -eq 0 -and $passIds.Count -eq 5) "pass=[$($passIds -join ',')] $(Format-Result $r)"
        $fixed = @(Get-FixedZeros $r)
        $z = Get-ZeroSummary $r
        $stay = @(Get-StayZeros $r)
        Assert 'S51-2: fixed once; three "seen again (1 of 3)" lines (one per old-boot stretch), all at that zero point; no note; one armed line; summary = it' ($fixed.Count -eq 1 -and $stay.Count -eq 3 -and @($stay | Where-Object { -not (Test-Same $_ $fixed[0]) }).Count -eq 0 -and @(Get-RearmNotes $r).Count -eq 0 -and @(Get-ArmedLines $r).Count -eq 1 -and $null -ne $z -and (Test-Same $z.utc $fixed[0])) "fixed=[$($fixed -join ', ')] stay=[$($stay -join ', ')] :: $(Format-Result $r)"
        $t0u = Get-FakeT0Utc $d
        $w0 = @(Get-CallsOf $calls 'whoami' 0)
        $zu = if ($null -ne $z) { Parse-ZeroUtc $z.utc } else { $null }
        $m0 = Get-MetSec $r 'reboot-0'
        $nodeCalls = @(Get-CallsOf $calls 'nodes')
        $bound = if ($nodeCalls.Count -gt 0 -and $w0.Count -gt 0) { [Math]::Floor([double]$nodeCalls[$nodeCalls.Count - 1]['elapsed'] - [double]$w0[0]['elapsed']) } else { $null }
        Assert 'S51-3: the zero point is the first observation (not later than its whoami on the fake clock) and reboot-0 "met at" includes all the alternation (>= the fake-clock gap from that whoami)' ($null -ne $t0u -and $null -ne $zu -and $w0.Count -eq 1 -and $zu -le (Get-CallUtc $t0u $w0[0]) -and $null -ne $m0 -and $null -ne $bound -and $m0 -ge $bound) "zero=$(if ($null -ne $z) { $z.utc }) metAt=$m0 bound=$bound :: $(Format-Calls $calls)"
        Assert 'S51-4: every failure that followed an old-boot observation was a call plus one retry (2 whoami calls in each fail phase)' ((Count-Calls $calls 'whoami' 1) -eq 2 -and (Count-Calls $calls 'whoami' 3) -eq 2 -and (Count-Calls $calls 'whoami' 5) -eq 2) (Format-Calls $calls)
        Assert 'S51-5: "retried:" lines, one per stretch: armed (fail-1) and fixed (fail-2, fail-3) = 2 lines for 3 retried observations' (@(Get-RetryLines $r).Count -eq 2) "retried=$(@(Get-RetryLines $r).Count) :: $(Format-Result $r)"
    }
    # (F4) arm 시간 제한은 기준점이 움직이는 관측에서만 판정된다(설계 — F): armed 첫 관측 뒤 불통이 길어(굳은 채) 제한 15 s를 넘겨도 판정하지 않고,
    #   불통 뒤 옛 부팅을 연속 세 번 봐 기준점이 다시 움직이는 그 관측에서야 'no reboot observed within 15s'로 끝난다. 불통 관측 15번(간격 1 s)은
    #   부하와 무관하게 15 s를 넘긴다(가짜 시계로 확인 — "관측 N번이 M초 안에"에 기대지 않는다).
    Test-Case 'S52' 'F4: the arm timeout is judged only on observations that move the zero point -> fixed past the limit, it fails only at the third old-boot observation' {
        $old = New-PrePhase @{ name = 'old-boot'; whoamiCalls = 1 }
        $down = New-Phase @{ name = 'api-down'; whoamiCalls = 16; api = 'down' }
        $d = New-Fixture @($old, $down, (New-PrePhase @{ name = 'old-boot-again' }))
        $r = Invoke-Harness $d $afterArgs (Knobs 120 40 1 15) 150
        $calls = @(Get-Calls $d)
        Assert-Completed 'S52' $r $calls
        $f0 = @(Lines-Starting $r 'FAIL reboot-0: ')
        Assert 'S52-1: exit 1 and "FAIL reboot-0" says no reboot observed within 15s' ($r.code -eq 1 -and $f0.Count -eq 1 -and (Has-Text $f0[0] 'no reboot observed within 15s')) (Format-Result $r)
        $again = @(Get-CallsOf $calls 'whoami' 2)
        Assert 'S52-2: the limit had passed while fixed (the first old-boot-again whoami >= 15s on the fake clock) but was judged only at the third old-boot observation after the outage (exactly 3 whoami and 3 get nodes calls in that phase)' ($again.Count -eq 3 -and [double]$again[0]['elapsed'] -ge 15 -and (Count-Calls $calls 'nodes' 2) -eq 3) "again=$($again.Count) firstAt=$(if ($again.Count) { $again[0]['elapsed'] }) :: $(Format-Calls $calls)"
        Assert-NotAttempted 'S52' $r
    }

    # (마) -ArmTimeoutMinutes: 범위 밖(0 · 121) · 정수 아님 · -AfterReboot 없이 → pre-4 FAIL, kubectl 호출 0
    Test-Case 'S39' 'H2: -ArmTimeoutMinutes out of range, not an integer, or without -AfterReboot -> pre-4 FAIL before any kubectl call' {
        $variants = @(
            @{ id = 'S39a'; args = ($afterArgs + @('-ArmTimeoutMinutes', '0')); reason = "-ArmTimeoutMinutes '0' is not an integer 1..120" },
            @{ id = 'S39b'; args = ($afterArgs + @('-ArmTimeoutMinutes', '121')); reason = "-ArmTimeoutMinutes '121' is not an integer 1..120" },
            @{ id = 'S39c'; args = ($afterArgs + @('-ArmTimeoutMinutes', 'abc')); reason = "-ArmTimeoutMinutes 'abc' is not an integer 1..120" },
            @{ id = 'S39d'; args = @('-ArmTimeoutMinutes', '30'); reason = '-ArmTimeoutMinutes is only used with -AfterReboot' }
        )
        foreach ($v in $variants) {
            $d = New-Fixture @(New-Phase)
            $r = Invoke-Harness $d ([string[]]$v.args) (Knobs 10 10)
            $calls = @(Get-Calls $d)
            Assert-Completed $v.id $r $calls
            Assert-RefusedBeforePolling $v.id $r $calls $v.reason $false
        }
    }

    # 선택 실행에 모르는 케이스 이름이 있으면 실패(오타로 아무것도 안 돌고 통과하지 않게)
    foreach ($o in $script:only) {
        if (@($script:known | Where-Object { Test-Same $_ $o }).Count -eq 0) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in REBOOT_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
    }
} finally {
    Remove-Fixture
}

$suffix = if ($script:only.Count -gt 0) { " (filtered: $($script:only -join ','))" } else { '' }
Write-Host "`n$($script:pass) passed, $($script:fail) failed$suffix"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
