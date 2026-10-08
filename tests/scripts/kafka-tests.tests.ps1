# tests/scripts/kafka-tests.tests.ps1 — tests/platform/kafka.tests.ps1 하네스 단위 테스트(T051).
# Run: pwsh -NoProfile -File tests/scripts/kafka-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/cluster-tests.tests.ps1과 같은 구조 — 가짜 kubectl 심 · 픽스처 · 선택 실행 · 요약 줄).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all 등록은 컨트롤러 몫 — 이 파일은 tests/run-all.ps1을 건드리지 않는다).
#
# 무엇을 지키나(요구 원문 .superpowers/t051/prompts/t051-brief.md — 설계 D1–D4 · 단위 테스트 절):
#   - 전부 갖춘 픽스처 → 17개 전부 PASS(exit 0)이고 PASS 문구가 정확하다(C01); 표현 변형(auto.create "false" 문자열 · retention.ms 숫자 ·
#     --maxmemory 분리 표기 · literal ACL · spec.topicName 명시 · Ready 조건이 있는 KafkaNodePool · 예전 단수 operation)도 PASS(C02).
#   - 지금 라이브 모양(Strimzi CRD 없음 · Deployment · Service 없음 · Job 없음) → 게이트 3개만 PASS, 나머지 14개 전부 FAIL이고 사유가 전부 남는다
#     (격리 — "unhandled" 0, "CRD … not installed (T055)" · "(T057)" · "not deployed yet" 문구), Job이 없으면 logs를 부르지 않는다(C03).
#   - 변이 하나 = 해당 ID 하나만 FAIL이고 문구 정확, 나머지 16개는 PASS(C04–C32 — 요구 원문의 변이 목록 + 역할 부분집합 · 중복 id · T041 Job 모양).
#   - 2라운드(리뷰 반영 2026-10-08): 중복 조건 양쪽 순서(C04b · C04c) · CrashLoopBackOff pod(C14b) · scale-to-zero · availableReplicas 0(C21b · C21c) ·
#     env/envFrom 비밀번호(C22b) · latency 토큰 초과/없음(C26 · C26b) · SUMMARY ↔ RESULT 수 불일치(C27b · C29b) · 다른 사용자 행의 패턴(C31b) ·
#     살아남은 변이를 죽이는 X01–X16(listener port · tls · status.secret · aclfile · SUMMARY 유일성 · 마스킹 · topic replicas · user auth · pool replicas ·
#     컨테이너 수 · topic 중복 선언 · 다른 클러스터 라벨 · auto.create 문자열 · topic Ready · Available · gate-2 경로 목록/미설정) ·
#     stderr 안내문 + 비밀번호 값 부재(X17) · 인증 없는 listener(X18) · superUsers(X19).
#   - 3라운드(재검토 반영 2026-10-08): 2라운드 규칙을 구속하는 K01–K12(변이 R01–R12를 죽인다 — latency 경계 · 토큰 2개 · pod Ready ordinal/ContainersReady ·
#     availableReplicas 정확히 1 · env 이름 대소문자 · sample-pod 행 경로/정규식 · RESULT FAIL 줄의 latency · roundtrip 줄 2개 · Available ordinal · listener tls 문자열) ·
#     absl --flagfile(K13) · 괄호 안 latency 토큰(K14) · role 라벨 없는 노드 role=<absent>(K15). 자식 출력은 UTF-8로 디코딩한다(하네스가 리다이렉트 시 UTF-8로 쓴다 — 콘솔 코드 페이지 무관).
#   - 모든 실행: 마지막 줄이 요약 · 읽기 전용 동사만 · 응답표 밖 호출 0 · 모든 호출이 --kubeconfig로 픽스처를 명시 · 픽스처 TEMP에 잔존 파일 0.
#   - 순수 함수(F*): 로그 파서 · 벽시계 초 추출 · ACL 접두 판정(교차 fail-closed 포함) · 플래그 토큰 판정 · latency 토큰 · 조건 중복 · superUser 표기 ·
#     SUMMARY 대조를 표로 시험한다. 정적(S01): 머리 주석이 단언 ID 전부와 T057 몫을 적는다.
#
# 방식 1 — E2E 케이스(C*): 케이스마다 임시 픽스처(%TEMP%/kafkatest-<guid>)에
#     하네스 사본  repo/tests/platform/kafka.tests.ps1  (KAFKA_HARNESS_SCRIPT가 있으면 그 파일의 사본)
#     가짜 kubectl bin/kubectl.cmd 심 → bin/fake-kubectl.ps1 · 응답표 responses.tsv + resp/ · 더미 kubeconfig.yaml · tmp/
#   를 만들고 하네스 사본을 자식 pwsh로 실행한다(KUBECONFIG = 더미 파일, TMP/TEMP = 픽스처 tmp/, 실행마다 시간 상한 — 넘기면 트리째 종료).
#   자식 PATH = 픽스처 bin + 지금 PATH에서 kubectl.* · oci.* · curl.* 파일이 있는 디렉터리를 뺀 나머지 — 실제 kubectl · oci · curl에 닿지 않는다.
#   실행마다 자식 PATH에서 처음 찾히는 kubectl이 픽스처 심인지, oci · curl이 하나도 안 찾히는지 확인하고, 아니면 하네스를 실행하지 않는다.
# 가짜 kubectl · 심 · PATH 가드 · 호출 기록(calls.log) · 결과 도우미는 tests/scripts/cluster-tests.tests.ps1에서 그대로 가져왔다(절 머리의 출처 주석).
#   응답표 key = --kubeconfig=… · --request-timeout=…을 뗀 나머지 인자를 공백 하나로 이은 문자열(ordinal). 없으면 exit 1 + 'no fixture response'
#   (기록의 served = default — 케이스마다 0개를 단언한다).
# 방식 2 — 함수 케이스(F*): 하네스 파일을 AST로 읽어 최상위 함수 정의만 동적 모듈 안에 정의한다(최상위 문장은 실행하지 않는다).
#
# 환경 변수:
#   KAFKA_HARNESS_SCRIPT      시험할 하네스(기본 tests/platform/kafka.tests.ps1) — 변이 시험에서 사본을 가리킨다. 설정되면 요약 줄 끝에
#                             ' (script override: <파일 이름>)'이 붙어 'N passed, 0 failed' 판정을 통과하지 못한다.
#   KAFKA_HARNESS_TESTS_ONLY  쉼표로 나눈 케이스 ID(예: C01,F02)만 실행한다. 요약 줄 끝에 ' (filtered: …)'가 붙는다(부분 실행이 전체 통과로
#                             보이지 않게). 모르는 ID가 있으면 FAIL.
# 실행 시간: E2E 케이스 하나에 가짜 kubectl 호출 약 15번(호출마다 cmd + pwsh 하나 — 실행 시간의 97%는 이 심의 프로세스 기동이다; 준수 리뷰 F4).
#   실측 2026-10-08 3라운드(이 PC, 변이 스윕 · 다른 전체 실행과 동시 — 과부하): 케이스당 약 10–13초, 전체 87 케이스(E2E 78 + 정적 1 + 함수 8) · 745 단언 · 919.1초
#   (2라운드: 72 케이스 · 627 단언 · 717.7초). 무부하 기준(준수 리뷰 실측 11.0–14.6초/케이스)도 비슷하다. 컴파일 심(csc.exe, −77%)으로의 전환은 cluster · data · kafka
#   세 하네스에 함께 적용할 별도 작업으로 미뤘다(컨트롤러 기록). 반복 중에는 KAFKA_HARNESS_TESTS_ONLY로 영향 받는 케이스만 돌리고, 전체는 마무리에 한 번 돌린다.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:KAFKA_HARNESS_SCRIPT)
$harnessPath = if ($scriptOverride) { $env:KAFKA_HARNESS_SCRIPT } else { Join-Path $repo 'tests/platform/kafka.tests.ps1' }
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$sync = 'Delete=false,Prune=false'
$sep = [IO.Path]::PathSeparator
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
if (-not [string]::IsNullOrWhiteSpace($env:KAFKA_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:KAFKA_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}
# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Has-Text([string]$s, [string]$needle) { return ($null -ne $s -and $s.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }
function In-List($arr, [string]$v) { foreach ($x in @($arr)) { if (Test-Same "$x" $v) { return $true } }; return $false }

# 케이스 격리 + 선택 실행(출처: cluster-tests.tests.ps1 Test-Case). 한 케이스에서 예외가 나도 나머지는 계속 실행된다.
function Test-Case([string]$id, [string]$title, [scriptblock]$body) {
    $caseId = $id
    $script:known += $caseId
    if ($script:only.Count -gt 0 -and @($script:only | Where-Object { Test-Same $_ $caseId }).Count -eq 0) { return }
    Write-Host "-- ${caseId}: $title"
    $caseWatch = [Diagnostics.Stopwatch]::StartNew()
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $caseId -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    Write-Host "   [$caseId took $($caseWatch.Elapsed.TotalSeconds.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))s]"
}

# ---------- 가짜 kubectl(출처: cluster-tests.tests.ps1 $fakeKubectl — 픽스처 bin/fake-kubectl.ps1로 쓴다) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/kafka-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
# 입력: ..\responses.tsv(줄 = 번호 TAB 종료코드 TAB key) + ..\resp\<번호>.out · <번호>.err
# 기록: ..\calls.log(줄 = served TAB 종료코드 TAB kubeconfig TAB request-timeout TAB key)
# JSON cmdlet은 쓰지 않는다 — 호출마다 새 pwsh라 그 모듈 적재 시간(호출당 약 0.4초)이 그대로 실행 시간이 된다.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
try { [Console]::OutputEncoding = $utf8 } catch { }   # 콘솔이 없는 자식이면 설정할 수 없다
# 인자는 $args가 아니라 심이 넘긴 원래 명령줄(FAKE_KUBECTL_ARGV = cmd의 %*)에서 읽는다: pwsh -File은 '-'로 시작하고 ':'가 든 인자를
# '-이름:값' 매개변수 문법으로 읽어 콜론을 떼고 둘로 나눈다(--kubeconfig=C:\… → '--kubeconfig=C' + '\…'). 나누기는 Windows 명령줄 규칙
# (CommandLineToArgvW: 따옴표 밖 공백 = 구분, " = 따옴표 토글, \ 2n개 + " = \ n개 + 토글, \ 2n+1개 + " = \ n개 + 문자 ")이다.
function Split-CommandLine([string]$s) {
    $bs = [char]92; $dq = [char]34
    $res = [Collections.Generic.List[string]]::new()
    $sb = [Text.StringBuilder]::new(); $inQ = $false; $have = $false; $i = 0
    while ($i -lt $s.Length) {
        $c = $s[$i]
        if ($c -eq $bs) {
            $n = 0
            while ($i -lt $s.Length -and $s[$i] -eq $bs) { $n++; $i++ }
            if ($i -lt $s.Length -and $s[$i] -eq $dq) {
                if ($n -ge 2) { [void]$sb.Append($bs, [int][Math]::Floor($n / 2)) }
                if ($n % 2 -eq 1) { [void]$sb.Append($dq); $i++ }
            } else { [void]$sb.Append($bs, $n) }
            $have = $true
            continue
        }
        if ($c -eq $dq) { $inQ = -not $inQ; $have = $true; $i++; continue }
        if (-not $inQ -and ($c -eq [char]32 -or $c -eq [char]9)) { if ($have) { $res.Add($sb.ToString()); [void]$sb.Clear(); $have = $false }; $i++; continue }
        [void]$sb.Append($c); $have = $true; $i++
    }
    if ($have) { $res.Add($sb.ToString()) }
    return , $res.ToArray()
}
$argv = Split-CommandLine ([string]$env:FAKE_KUBECTL_ARGV)
$kc = $null; $rt = $null
$rest = [Collections.Generic.List[string]]::new()
foreach ($x in $argv) {
    if ($x.StartsWith('--kubeconfig=', [StringComparison]::Ordinal)) { $kc = $x.Substring(13); continue }
    if ($x.StartsWith('--request-timeout=', [StringComparison]::Ordinal)) { $rt = $x.Substring(18); continue }
    $rest.Add($x)
}
$key = $rest -join ' '
$out = ''; $err = ''; $code = 1; $served = 'default'
if ($rest.Count -ge 3 -and [string]::Equals($rest[0], '-n', [StringComparison]::Ordinal) -and [string]::Equals($rest[2], 'port-forward', [StringComparison]::Ordinal)) {
    $err = 'error: fake-kubectl does not forward ports (outside this harness test)'; $served = 'port-forward'
} else {
    $hit = $null
    foreach ($row in [IO.File]::ReadAllLines((Join-Path $root 'responses.tsv'), $utf8)) {
        $f = $row.Split([char[]]@([char]9), 3)
        if ($f.Count -eq 3 -and [string]::Equals($f[2], $key, [StringComparison]::Ordinal)) { $hit = $f; break }
    }
    if ($null -ne $hit) {
        $out = [IO.File]::ReadAllText((Join-Path $root "resp\$($hit[0]).out"), $utf8)
        $err = [IO.File]::ReadAllText((Join-Path $root "resp\$($hit[0]).err"), $utf8)
        $code = [int]$hit[1]; $served = 'fixture'
    } else { $err = "fake-kubectl: no fixture response for: $key" }
}
$line = "$served`t$code`t$kc`t$rt`t$key"
for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::AppendAllText((Join-Path $root 'calls.log'), $line + "`n", $utf8); break } catch { Start-Sleep -Milliseconds 25 } }
if (-not [string]::IsNullOrEmpty($err)) { [Console]::Error.WriteLine($err) }
if (-not [string]::IsNullOrEmpty($out)) { [Console]::Out.Write($out) }
exit $code
'@

# kubectl.cmd 심(출처: cluster-tests.tests.ps1): CRLF, BOM 없음(@echo off가 1행이어야 한다). 받은 명령줄(%*)을 FAKE_KUBECTL_ARGV로 넘기고
# 현재 pwsh로 가짜 스크립트를 실행해 종료 코드를 그대로 돌려준다.
$crlf = "`r`n"
$shimBody = (@(
        '@echo off'
        'set "FAKE_KUBECTL_ARGV=%*"'
        "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0fake-kubectl.ps1`""
        'exit /b %ERRORLEVEL%'
    ) -join $crlf) + $crlf

# ---------- 자식 PATH(실제 kubectl · oci · curl을 가린다 — 출처: cluster-tests.tests.ps1) ----------
function Get-SafePath {
    $keep = [Collections.Generic.List[string]]::new()
    foreach ($p in "$env:PATH".Split($sep)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        try { if (-not [IO.Directory]::Exists($p)) { continue } } catch { continue }
        $hit = $false
        foreach ($pat in @('kubectl.*', 'oci.*', 'curl.*', 'kubectl', 'oci', 'curl')) {
            try { if (@([IO.Directory]::EnumerateFiles($p, $pat)).Count -gt 0) { $hit = $true; break } } catch { $hit = $true; break }
        }
        if (-not $hit) { $keep.Add($p) }
    }
    return ($keep -join $sep)
}
$script:safePath = Get-SafePath
# 자식 PATH에서 처음 찾히는 명령(디렉터리 순 · 확장자 '' → PATHEXT → .ps1). 없으면 $null
function Find-FirstCommand([string]$pathValue, [string]$name) {
    $exts = @('') + @("$env:PATHEXT".Split(';') | Where-Object { $_.Length -gt 0 }) + @('.ps1')
    foreach ($p in "$pathValue".Split($sep)) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        foreach ($e in $exts) {
            $cand = $null
            try { $cand = Join-Path $p ($name + $e) } catch { continue }
            if (Test-Path -LiteralPath $cand -PathType Leaf) { return $cand }
        }
    }
    return $null
}

# ---------- 응답표 조각(출처: cluster-tests.tests.ps1 — R-* · New-List) ----------
function Json($o) { return (ConvertTo-Json -InputObject $o -Depth 30 -Compress) }
function J($o) { return (ConvertFrom-Json (Json $o)) }   # 함수 케이스용: 픽스처 객체를 kubectl -o json 모양(PSCustomObject)으로
function R-Json($o) { return @{ out = (Json $o); err = ''; code = 0 } }
function R-None { return @{ out = ''; err = ''; code = 0 } }   # --ignore-not-found + 객체 없음 = 빈 출력 · exit 0
function R-Raw([string]$out) { return @{ out = $out; err = ''; code = 0 } }
function R-Err([string]$err, [int]$code = 1) { return @{ out = ''; err = $err; code = $code } }
function R-NoType([string]$plural) { return R-Err "error: the server doesn't have a resource type `"$plural`"" }
function R-Forbidden([string]$what) { return R-Err "Error from server (Forbidden): $what is forbidden: User `"$expectedUser`" cannot get resource in the namespace" }
function New-List([object[]]$items) { return [ordered]@{ apiVersion = 'v1'; kind = 'List'; items = @(@($items) | Where-Object { $null -ne $_ }) } }
function New-Meta([string]$ns, [string]$name, $labels = $null, $annotations = $null) {
    $m = [ordered]@{ name = $name }
    if ($ns.Length -gt 0) { $m['namespace'] = $ns }
    if ($null -ne $labels) { $m['labels'] = $labels }
    if ($null -ne $annotations) { $m['annotations'] = $annotations }
    return $m
}
function New-Cond([string]$type, [string]$status, [string]$reason = '', [string]$message = '') {
    $c = [ordered]@{ type = $type; status = $status; lastTransitionTime = '2026-10-07T00:00:00Z' }
    if ($reason.Length -gt 0) { $c['reason'] = $reason }
    if ($message.Length -gt 0) { $c['message'] = $message }
    return $c
}
# ready: 'True' | 'False' | 'none'(conditions 없음) | 'notready'(Strimzi NotReady=True만)
function Get-ReadyConds([string]$ready) {
    if (Test-Same $ready 'True') { return @(New-Cond 'Ready' 'True') }
    if (Test-Same $ready 'False') { return @(New-Cond 'Ready' 'False' 'Fixture' 'ready=false fixture') }
    if (Test-Same $ready 'notready') { return @(New-Cond 'NotReady' 'True' 'InvalidConfigurationException' 'fixture: broker config rejected') }
    return @()
}
function Opt([hashtable]$o, [string]$key, $default) { if ($o.ContainsKey($key)) { return $o[$key] } else { return $default } }
function Is-Absent($v) { return ($v -is [string] -and (Test-Same $v '<absent>')) }

# ---------- 객체 빌더(T055–T057 선언값 모양) ----------
function New-Kafka([hashtable]$o = @{}) {
    $auto = Opt $o 'autoCreate' $false
    $syncOpt = Opt $o 'syncOpt' $sync
    $cfg = [ordered]@{ 'offsets.topic.replication.factor' = 1; 'transaction.state.log.replication.factor' = 1; 'transaction.state.log.min.isr' = 1; 'default.replication.factor' = 1; 'min.insync.replicas' = 1 }
    if (-not (Is-Absent $auto)) { $cfg['auto.create.topics.enable'] = $auto }
    $ann = if ($null -eq $syncOpt) { $null } else { [ordered]@{ 'argocd.argoproj.io/sync-options' = [string]$syncOpt } }
    $version = [string](Opt $o 'version' '4.3.1')
    $listener = [ordered]@{ name = [string](Opt $o 'listenerName' 'tls'); port = [int](Opt $o 'listenerPort' 9093); type = 'internal'; tls = [bool](Opt $o 'listenerTls' $true); authentication = [ordered]@{ type = [string](Opt $o 'listenerAuth' 'scram-sha-512') } }
    $listeners = @($listener)
    if ($o.ContainsKey('extraListener')) { $listeners += [ordered]@{ name = [string]$o.extraListener; port = 9092; type = 'internal'; tls = $false } }
    $authorization = [ordered]@{ type = [string](Opt $o 'authz' 'simple') }
    if ($o.ContainsKey('superUsers')) { $authorization['superUsers'] = @($o.superUsers) }   # T055 선언값에는 없다 — kafka-2 변이용
    return [ordered]@{
        apiVersion = 'kafka.strimzi.io/v1'; kind = 'Kafka'
        metadata   = (New-Meta 'data' 'jt-kafka' $null $ann)
        spec       = [ordered]@{
            kafka          = [ordered]@{ version = $version; listeners = @($listeners); authorization = $authorization; config = $cfg }
            entityOperator = [ordered]@{ topicOperator = [ordered]@{}; userOperator = [ordered]@{} }
        }
        status     = [ordered]@{ conditions = @(Get-ReadyConds ([string](Opt $o 'ready' 'True'))); kafkaVersion = $version; clusterId = 'fixture-cluster-id'; observedGeneration = 1 }
    }
}
function New-Pool([hashtable]$o = @{}) {
    $name = [string](Opt $o 'name' 'combined'); $roles = @(Opt $o 'roles' @('controller', 'broker')); $cluster = [string](Opt $o 'cluster' 'jt-kafka')
    $st = [ordered]@{ conditions = @(Get-ReadyConds ([string](Opt $o 'ready' 'none'))); observedGeneration = 1; nodeIds = @(0); clusterId = 'fixture-cluster-id'; roles = @($roles); labelSelector = "strimzi.io/cluster=$cluster,strimzi.io/name=$cluster-kafka,strimzi.io/kind=Kafka,strimzi.io/pool-name=$name" }
    $sr = Opt $o 'statusReplicas' 1
    if (-not (Is-Absent $sr)) { $st['replicas'] = [int]$sr }
    return [ordered]@{ apiVersion = 'kafka.strimzi.io/v1'; kind = 'KafkaNodePool'; metadata = (New-Meta 'data' $name ([ordered]@{ 'strimzi.io/cluster' = $cluster })); spec = [ordered]@{ replicas = [int](Opt $o 'replicas' 1); roles = @($roles); storage = [ordered]@{ type = 'persistent-claim'; size = '20Gi' } }; status = $st }
}
# Kafka 노드 pod(Strimzi 라벨 — Labels.java). $labelsOverride: 값 $null = 그 라벨 제거. o.podReady = 'True'(기본) | 'False'(CrashLoopBackOff 모양:
#   phase Running + Ready=False ContainersNotReady + containerStatuses waiting CrashLoopBackOff) | 'none'(조건 없음)
function New-KafkaPod([hashtable]$o = @{}) {
    $labels = [ordered]@{ 'strimzi.io/cluster' = 'jt-kafka'; 'strimzi.io/kind' = 'Kafka'; 'strimzi.io/name' = 'jt-kafka-kafka'; 'strimzi.io/component-type' = 'kafka'; 'strimzi.io/pool-name' = 'combined'; 'strimzi.io/broker-role' = 'true'; 'strimzi.io/controller-role' = 'true' }
    $ov = Opt $o 'labels' @{}
    foreach ($k in @($ov.Keys)) { if ($null -eq $ov[$k]) { $labels.Remove($k) } else { $labels[$k] = $ov[$k] } }
    $spec = [ordered]@{ containers = @([ordered]@{ name = 'kafka'; image = 'quay.io/strimzi/kafka:1.2.0-kafka-4.3.1' }) }
    $node = [string](Opt $o 'node' 'node-a')
    if ($node.Length -gt 0) { $spec['nodeName'] = $node }
    $podReady = [string](Opt $o 'podReady' 'True')
    $status = [ordered]@{ phase = [string](Opt $o 'phase' 'Running') }
    if (Test-Same $podReady 'True') {
        $status['conditions'] = @((New-Cond 'Ready' 'True'), (New-Cond 'ContainersReady' 'True'))
        $status['containerStatuses'] = @([ordered]@{ name = 'kafka'; ready = $true; restartCount = 0; state = [ordered]@{ running = [ordered]@{ startedAt = '2026-10-07T00:00:00Z' } } })
    } elseif (Test-Same $podReady 'False') {
        $status['conditions'] = @((New-Cond 'Ready' 'False' 'ContainersNotReady' 'containers with unready status: [kafka]'), (New-Cond 'ContainersReady' 'False' 'ContainersNotReady' 'containers with unready status: [kafka]'))
        $status['containerStatuses'] = @([ordered]@{ name = 'kafka'; ready = $false; restartCount = 7; state = [ordered]@{ waiting = [ordered]@{ reason = 'CrashLoopBackOff' } } })
    }
    return [ordered]@{ apiVersion = 'v1'; kind = 'Pod'; metadata = (New-Meta 'data' ([string](Opt $o 'name' 'jt-kafka-combined-0')) $labels); spec = $spec; status = $status }
}
# 엔티티 오퍼레이터 pod — 클러스터 라벨은 같지만 component-type=entity-operator · pool-name 없음 → pool-2 대상이 아니다(노드 B에 둔다: 대조군)
function New-EoPod { return (New-KafkaPod @{ name = 'jt-kafka-entity-operator-7d9f8b6c5-x2k4q'; node = 'node-b'; labels = @{ 'strimzi.io/component-type' = 'entity-operator'; 'strimzi.io/name' = 'jt-kafka-entity-operator'; 'strimzi.io/pool-name' = $null; 'strimzi.io/broker-role' = $null; 'strimzi.io/controller-role' = $null } }) }
function New-Node([string]$name, [string]$role) {
    return [ordered]@{ apiVersion = 'v1'; kind = 'Node'; metadata = (New-Meta '' $name ([ordered]@{ role = $role; 'kubernetes.io/hostname' = $name })); status = [ordered]@{ conditions = @(New-Cond 'Ready' 'True') } }
}
function New-Topic([string]$name, [hashtable]$o = @{}) {
    $spec = [ordered]@{ partitions = [int](Opt $o 'partitions' 3); replicas = [int](Opt $o 'replicas' 1) }
    if ($o.ContainsKey('topicName')) { $spec['topicName'] = [string]$o.topicName }
    $cfg = [ordered]@{ 'cleanup.policy' = 'delete' }
    $ret = Opt $o 'retention' '604800000'
    if (-not (Is-Absent $ret)) { $cfg['retention.ms'] = $ret }
    $spec['config'] = $cfg
    $topicName = if ($o.ContainsKey('topicName')) { [string]$o.topicName } else { $name }
    return [ordered]@{ apiVersion = 'kafka.strimzi.io/v1'; kind = 'KafkaTopic'; metadata = (New-Meta 'data' $name ([ordered]@{ 'strimzi.io/cluster' = [string](Opt $o 'cluster' 'jt-kafka') })); spec = $spec; status = [ordered]@{ conditions = @(Get-ReadyConds ([string](Opt $o 'ready' 'True'))); observedGeneration = 1; topicName = $topicName; topicId = 'fixture-topic-id' } }
}
# ACL 한 줄. $patternType '' = 필드 생략(기본 literal). $ruleType '' = 필드 생략(기본 allow). $singleOp = 예전 단수 operation 필드
function New-Acl([string]$name, [string]$patternType = 'prefix', [string[]]$operations = @('Write', 'Describe'), [string]$resourceType = 'topic', [string]$ruleType = '', [string]$singleOp = '') {
    $res = [ordered]@{ type = $resourceType; name = $name }
    if ($patternType.Length -gt 0) { $res['patternType'] = $patternType }
    $a = [ordered]@{ resource = $res; host = '*' }
    if ($singleOp.Length -gt 0) { $a['operation'] = $singleOp } else { $a['operations'] = @($operations) }
    if ($ruleType.Length -gt 0) { $a['type'] = $ruleType }
    return $a
}
# T056 ACL 모양: 자기 접두 토픽 Write/Describe/Read + 자기 그룹 접두 Read
function Default-Acls([string]$user) {
    if (Test-Same $user 'identity-admin') { return @((New-Acl 'identity-admin.' 'prefix' @('Write', 'Describe', 'Read')), (New-Acl 'identity-admin-' 'prefix' @('Read') 'group')) }
    return @((New-Acl 'dev.identity-admin.' 'prefix' @('Write', 'Describe', 'Read')), (New-Acl 'dev-identity-admin-' 'prefix' @('Read') 'group'))
}
function New-User([string]$name, [hashtable]$o = @{}) {
    $acls = if ($o.ContainsKey('acls')) { @($o.acls) } else { @(Default-Acls $name) }
    $st = [ordered]@{ conditions = @(Get-ReadyConds ([string](Opt $o 'ready' 'True'))); observedGeneration = 1; username = $name }
    $secret = [string](Opt $o 'secret' $name)
    if ($secret.Length -gt 0) { $st['secret'] = $secret }
    return [ordered]@{ apiVersion = 'kafka.strimzi.io/v1'; kind = 'KafkaUser'; metadata = (New-Meta 'data' $name ([ordered]@{ 'strimzi.io/cluster' = [string](Opt $o 'cluster' 'jt-kafka') })); spec = [ordered]@{ authentication = [ordered]@{ type = [string](Opt $o 'auth' 'scram-sha-512') }; authorization = [ordered]@{ type = [string](Opt $o 'authz' 'simple'); acls = @($acls) } }; status = $st }
}
$dfArgs = @('--maxmemory=768mb', '--aclfile', '/etc/dragonfly/users.acl', '--dir', '/data', '--snapshot_cron', '*/5 * * * *')
# o.env = 컨테이너 env 항목 배열(이름 · value 또는 valueFrom) · o.envFrom = envFrom 배열 — T057 선언값에는 둘 다 없다(df-1 변이용)
function New-Deployment([string]$name, [hashtable]$o = @{}) {
    $c = [ordered]@{ name = 'dragonfly'; image = 'docker.dragonflydb.io/dragonflydb/dragonfly:v1.34.0@sha256:0000000000000000000000000000000000000000000000000000000000000000'; args = @(Opt $o 'args' $dfArgs); ports = @([ordered]@{ containerPort = 6379; name = 'redis' }) }
    if ($o.ContainsKey('command')) { $c['command'] = @($o.command) }
    if ($o.ContainsKey('env')) { $c['env'] = @($o.env) }
    if ($o.ContainsKey('envFrom')) { $c['envFrom'] = @($o.envFrom) }
    $containers = @($c)
    if ($o.ContainsKey('extraContainer')) { $containers += [ordered]@{ name = 'sidecar'; image = 'busybox@sha256:0000000000000000000000000000000000000000000000000000000000000000' } }
    $podSpec = [ordered]@{ terminationGracePeriodSeconds = [int](Opt $o 'grace' 60); nodeSelector = [ordered]@{ role = 'data' }; containers = @($containers) }
    $am = Opt $o 'automount' $false
    if (-not (Is-Absent $am)) { $podSpec['automountServiceAccountToken'] = [bool]$am }
    $st = [ordered]@{ replicas = 1; readyReplicas = 1; availableReplicas = 1; conditions = @((New-Cond 'Available' ([string](Opt $o 'available' 'True')) 'MinimumReplicasAvailable'), (New-Cond 'Progressing' 'True' 'NewReplicaSetAvailable')) }
    return [ordered]@{ apiVersion = 'apps/v1'; kind = 'Deployment'; metadata = (New-Meta 'data' $name ([ordered]@{ 'app.kubernetes.io/name' = 'dragonfly'; 'app.kubernetes.io/instance' = $name })); spec = [ordered]@{ replicas = 1; strategy = [ordered]@{ type = [string](Opt $o 'strategy' 'Recreate') }; selector = [ordered]@{ matchLabels = [ordered]@{ 'app.kubernetes.io/instance' = $name } }; template = [ordered]@{ metadata = [ordered]@{ labels = [ordered]@{ 'app.kubernetes.io/instance' = $name } }; spec = $podSpec } }; status = $st }
}
function New-Service([string]$name, [int[]]$ports = @(6379)) {
    return [ordered]@{ apiVersion = 'v1'; kind = 'Service'; metadata = (New-Meta 'data' $name); spec = [ordered]@{ type = 'ClusterIP'; selector = [ordered]@{ 'app.kubernetes.io/instance' = $name }; ports = @($ports | ForEach-Object { [ordered]@{ name = 'redis'; port = $_; targetPort = 6379; protocol = 'TCP' } }) } }
}
function New-Job([string]$name, $succeeded = 1, $failed = $null) {
    $st = [ordered]@{ startTime = '2026-10-07T00:00:00Z' }
    if ($null -ne $succeeded) { $st['succeeded'] = [int]$succeeded }
    if ($null -ne $failed) { $st['failed'] = [int]$failed }
    return [ordered]@{ apiVersion = 'batch/v1'; kind = 'Job'; metadata = (New-Meta 'jt-dev' $name); spec = [ordered]@{ backoffLimit = 0 }; status = $st }
}
# kafka-assert 로그(gitops job-kafka-assert.yaml의 실제 줄 모양 + T056이 더할 latency 토큰). o.sec = 벽시계 경과 초(기본 23 — JVM 2회 기동 + 컨슈머
#   --timeout-ms 20000 유휴 대기라 라이브에서 항상 ≥ 20), o.ms = 메시지 경로 지연 latency=<n>ms(기본 120; '<absent>' = 토큰 없음 = 지금 Job 모양),
#   o.roundtrip/cross = 'PASS'|'FAIL'|'none'|'dup', o.summary = 요약 줄('' = 없음)
function KafkaLog([hashtable]$o = @{}) {
    $sec = [int](Opt $o 'sec' 23); $rt = [string](Opt $o 'roundtrip' 'PASS'); $cross = [string](Opt $o 'cross' 'PASS')
    $ms = Opt $o 'ms' 120
    $lat = if (Is-Absent $ms) { '' } else { " latency=$([int]$ms)ms" }
    $lines = @()
    $rtPass = "RESULT: PASS roundtrip dev.identity-admin.session.revoked produce→consume ${sec}s (상한 30s, JVM 기동 포함)$lat"
    $rtFail = "RESULT: FAIL roundtrip 마커는 수신했으나 ${sec}s > 상한 30s"
    if (Test-Same $rt 'PASS') { $lines += $rtPass } elseif (Test-Same $rt 'FAIL') { $lines += $rtFail } elseif (Test-Same $rt 'dup') { $lines += $rtPass; $lines += $rtPass }
    $crPass = 'RESULT: PASS cross-env-denied dev-identity-admin -> identity-admin.session.revoked: org.apache.kafka.common.errors.TopicAuthorizationException: Not authorized to access topics: [identity-admin.session.revoked]'
    $crFail = 'RESULT: FAIL cross-env-denied dev 자격으로 prod 토픽 identity-admin.session.revoked write가 성공했다(ACL 회귀)'
    if (Test-Same $cross 'PASS') { $lines += $crPass } elseif (Test-Same $cross 'FAIL') { $lines += $crFail }
    $p = @($lines | Where-Object { $_.StartsWith('RESULT: PASS', [StringComparison]::Ordinal) }).Count; $f = @($lines | Where-Object { $_.StartsWith('RESULT: FAIL', [StringComparison]::Ordinal) }).Count
    $summary = [string](Opt $o 'summary' "SUMMARY: pass=$p fail=$f")
    if ($summary.Length -gt 0) { $lines += $summary }
    return (($lines -join "`n") + "`n")
}
$dataIds7 = @('acl-list', 'noperm', 'noauth', 'writer-set', 'reader-get', 'reader-set-denied', 'reader-cross-denied')
$dataNew5 = @('noauth', 'writer-set', 'reader-get', 'reader-set-denied', 'reader-cross-denied')
$dataPassText = @{
    'acl-list'            = 'user sample-pod 행에 %R~revoked:*(읽기 전용 revoked 패턴)이 있다'
    'noperm'              = 'DEL revoked:sub:assert-probe -> NOPERM: User sample-pod has no permissions to run the ''del'' command'
    'noauth'              = 'unauthenticated PING -> NOAUTH Authentication required.'
    'writer-set'          = 'identity-admin SET revoked:sub:x -> OK'
    'reader-get'          = 'sample-pod GET revoked:sub:x -> 1'
    'reader-set-denied'   = 'sample-pod SET revoked:sub:x -> NOPERM'
    'reader-cross-denied' = 'sample-pod SET identity-admin:x -> NOPERM'
}
# data-assert 로그(pg 4검사 PASS + Dragonfly 절). o.ids = 포함할 Dragonfly id(기본 7 전부) · o.fail = FAIL로 찍을 id · o.dup = 두 번 찍을 id ·
#   o.evidence = EVIDENCE 블록 포함(기본 $true) · o.aclPattern = acl-list 근거 · sample-pod EVIDENCE 행에 %R~revoked:* 포함(기본 $true) ·
#   o.patternRow = 'sample-pod'(기본) | 'identity-admin'(패턴을 identity-admin 행에만 싣고 acl-list 근거 · sample-pod 행에는 없음 — 하네스는 FAIL해야 한다) ·
#   o.summary = 요약 줄 덮어쓰기(기본 = 줄 수에서 계산; '' = 없음)
function DataLog([hashtable]$o = @{}) {
    $ids = @(Opt $o 'ids' $dataIds7); $failIds = @(Opt $o 'fail' @()); $dup = [string](Opt $o 'dup' ''); $withEvidence = [bool](Opt $o 'evidence' $true); $aclPattern = [bool](Opt $o 'aclPattern' $true)
    $patternRow = [string](Opt $o 'patternRow' 'sample-pod')
    if (-not (Test-Same $patternRow 'sample-pod')) { $aclPattern = $false }
    $lines = @(
        'RESULT: PASS pg-cross-db-denied dev_identity_admin_app -> identity_admin authentik openfga: 전부 permission denied for database',
        'RESULT: PASS catalog-connect-false has_database_privilege(identity_admin_app, {dev_identity_admin authentik openfga}, CONNECT) = false false false',
        'RESULT: PASS revoke-public authentik=revoked dev_identity_admin=revoked identity_admin=revoked openfga=revoked',
        'RESULT: PASS ssl-verify-full pg_stat_ssl(self) = true TLSv1.3 TLS_AES_256_GCM_SHA384 (DATABASE_URL sslmode=verify-full, CA /etc/pg/ca.crt)'
    )
    if ($withEvidence) {
        $sample = if ($aclPattern) { 'EVIDENCE:   user sample-pod on #<redacted> %R~revoked:* ~sample-pod:* +@all' } else { 'EVIDENCE:   user sample-pod on #<redacted> ~sample-pod:* +@all' }
        $admin = if (Test-Same $patternRow 'identity-admin') { 'EVIDENCE:   user identity-admin on #<redacted> %R~revoked:* ~identity-admin:* +@all' } else { 'EVIDENCE:   user identity-admin on #<redacted> ~revoked:* ~identity-admin:* +@all' }
        $lines += @('EVIDENCE: ACL LIST (dev, 비밀번호 해시 제거)', 'EVIDENCE:   user default off resetchannels -@all', 'EVIDENCE:   user admin on #<redacted> ~* &* +@all', $admin, $sample)
    }
    foreach ($id in $ids) {
        $text = [string]$dataPassText[$id]
        if ((Test-Same $id 'acl-list') -and -not $aclPattern) { $text = 'user sample-pod 행이 있다(패턴 검사 생략 — 픽스처)' }
        $status = if (In-List $failIds $id) { 'FAIL' } else { 'PASS' }
        if (Test-Same $status 'FAIL') { $text = "fixture failure for $id" }
        $lines += "RESULT: $status $id $text"
        if (Test-Same $dup $id) { $lines += "RESULT: $status $id $text" }
    }
    $p = @($lines | Where-Object { $_.StartsWith('RESULT: PASS', [StringComparison]::Ordinal) }).Count; $f = @($lines | Where-Object { $_.StartsWith('RESULT: FAIL', [StringComparison]::Ordinal) }).Count
    $summary = [string](Opt $o 'summary' "SUMMARY: pass=$p fail=$f")
    if ($summary.Length -gt 0) { $lines += $summary }
    return (($lines -join "`n") + "`n")
}

# 조회 key 표. 이름이 $Q인 이유: PowerShell 변수 이름은 대소문자를 가리지 않아 $K로 두면 함수 안의 foreach ($k …)가 가린다.
$Q = @{
    whoami = 'auth whoami -o json'
    kafka  = '-n data get kafkas.kafka.strimzi.io jt-kafka --ignore-not-found -o json'
    pools  = 'get kafkanodepools.kafka.strimzi.io -n data -o json'
    pods   = 'get pods -n data -l strimzi.io/cluster=jt-kafka -o json'
    nodes  = 'get nodes -o json'
    topics = 'get kafkatopics.kafka.strimzi.io -n data -o json'
    users  = 'get kafkausers.kafka.strimzi.io -n data -o json'
}
function DeployKey([string]$n) { return "-n data get deployments.apps $n --ignore-not-found -o json" }
function SvcKey([string]$n) { return "-n data get services $n --ignore-not-found -o json" }
function JobKey([string]$n) { return "-n jt-dev get jobs.batch $n --ignore-not-found -o json" }
function LogsKey([string]$n) { return "-n jt-dev logs job/$n --tail=50" }
$topics4 = @('identity-admin.session.revoked', 'dev.identity-admin.session.revoked', 'identity-admin.dlq', 'dev.identity-admin.dlq')
$dfNames = @('dragonfly-dev', 'dragonfly-prod')
$gateIds = @('gate-1', 'gate-2', 'gate-3')
$checkIds = @('kafka-1', 'kafka-2', 'pool-1', 'pool-2', 'topic-1', 'user-1', 'user-2', 'df-1', 'df-2', 'job-k-1', 'job-k-2', 'job-k-3', 'job-d-1', 'job-d-2')
$allIds = @($gateIds) + @($checkIds)
$whoamiResp = R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = $expectedUser } } })

# 전부 갖춘 응답표(T055–T057 선언값 — 기본값은 전부 "선언 그대로"; 케이스가 필요한 줄만 바꾼다)
function New-GoodResponses {
    $r = [ordered]@{}
    $r[$Q.whoami] = $whoamiResp
    $r[$Q.kafka] = R-Json (New-Kafka)
    $r[$Q.pools] = R-Json (New-List @(New-Pool))
    $r[$Q.pods] = R-Json (New-List @((New-KafkaPod), (New-EoPod)))
    $r[$Q.nodes] = R-Json (New-List @((New-Node 'node-a' 'platform'), (New-Node 'node-b' 'data')))
    $r[$Q.topics] = R-Json (New-List @($topics4 | ForEach-Object { New-Topic $_ }))
    $r[$Q.users] = R-Json (New-List @((New-User 'identity-admin'), (New-User 'dev-identity-admin')))
    foreach ($n in $dfNames) { $r[(DeployKey $n)] = R-Json (New-Deployment $n); $r[(SvcKey $n)] = R-Json (New-Service $n) }
    $r[(JobKey 'kafka-assert')] = R-Json (New-Job 'kafka-assert'); $r[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog)
    $r[(JobKey 'data-assert')] = R-Json (New-Job 'data-assert'); $r[(LogsKey 'data-assert')] = R-Raw (DataLog)
    return $r
}
# 지금 라이브 모양: Strimzi CRD 없음(리소스 타입 없음) · Kafka pod 0 · 노드 2 · Deployment · Service · Job 없음(logs 응답은 두지 않는다 — 호출되면 안 된다)
function New-LiveResponses {
    $r = [ordered]@{}
    $r[$Q.whoami] = $whoamiResp
    $r[$Q.kafka] = R-NoType 'kafkas'
    $r[$Q.pools] = R-NoType 'kafkanodepools'
    $r[$Q.topics] = R-NoType 'kafkatopics'
    $r[$Q.users] = R-NoType 'kafkausers'
    $r[$Q.pods] = R-Json (New-List @())
    $r[$Q.nodes] = R-Json (New-List @((New-Node 'node-a' 'platform'), (New-Node 'node-b' 'data')))
    foreach ($n in $dfNames) { $r[(DeployKey $n)] = R-None; $r[(SvcKey $n)] = R-None }
    foreach ($j in @('kafka-assert', 'data-assert')) { $r[(JobKey $j)] = R-None }
    return $r
}
# 기대 PASS 문구(정확 일치 — 하네스 D5 문구와 함께 바꾼다)
$passText = @{
    'gate-1'  = 'kubectl found'
    'gate-2'  = 'KUBECONFIG set (single existing file)'
    'gate-3'  = "context user is $expectedUser"
    'kafka-1' = "Kafka data/jt-kafka Ready=True, spec.kafka.version=4.3.1, auto.create.topics.enable=false, sync-options=$sync"
    'kafka-2' = "Kafka data/jt-kafka listener tls: port 9093, tls=true, authentication scram-sha-512; authorization simple; 1 listener(s), all TLS with authentication; 0 superUser(s) (none for identity-admin, dev-identity-admin or '*')"
    'pool-1'  = 'KafkaNodePool data/combined (cluster jt-kafka): replicas 1, roles {broker, controller}, status.replicas=1 (no Ready condition -- KafkaNodePool status carries none upstream)'
    'pool-2'  = '1 Kafka node pod(s) Running and Ready on role=platform node(s): jt-kafka-combined-0@node-a (pods with label strimzi.io/cluster=jt-kafka: 2)'
    'topic-1' = '4 KafkaTopics Ready (partitions 3, replicas 1, retention.ms 604800000): identity-admin.session.revoked, dev.identity-admin.session.revoked, identity-admin.dlq, dev.identity-admin.dlq; other topics in jt-kafka: 0'
    'user-1'  = 'KafkaUsers identity-admin, dev-identity-admin Ready=True, authentication scram-sha-512, authorization simple, status.secret set (identity-admin, dev-identity-admin)'
    'user-2'  = 'identity-admin: topic Write on identity-admin.* only (1 of 2 ACLs); dev-identity-admin: topic Write on dev.identity-admin.* only (1 of 2 ACLs) -- no cross-env Write'
    'df-1'    = 'Deployments data/dragonfly-dev, data/dragonfly-prod: Available, replicas 1/1, 1 container, --maxmemory=768mb, --aclfile /etc/dragonfly/users.acl, no --requirepass (args, env, envFrom), terminationGracePeriodSeconds=60, strategy Recreate, automountServiceAccountToken=false'
    'df-2'    = 'Services data/dragonfly-dev, data/dragonfly-prod expose port 6379'
    'job-k-1' = 'Job jt-dev/kafka-assert succeeded=1'
    'job-k-2' = 'roundtrip PASS, cross-env-denied PASS, SUMMARY pass=2 fail=0 matches 2 RESULT line(s) (last 50 log lines)'
    'job-k-3' = "roundtrip latency 120ms <= 5000ms (message path, spec US3 AC3; the Job's wall clock 23s includes JVM startup and the consumer idle wait)"
    'job-d-1' = 'Job jt-dev/data-assert succeeded=1'
    'job-d-2' = 'acl-list, noperm, noauth, writer-set, reader-get, reader-set-denied, reader-cross-denied PASS; pattern %R~revoked:* present on the sample-pod row (VD-4); SUMMARY pass=11 fail=0 matches 11 RESULT line(s)'
}

# ---------- 픽스처(출처: cluster-tests.tests.ps1 New-Fixture / Remove-Fixture — tasks.md 픽스처만 없다) ----------
function New-Fixture($responses) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('kafkatest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($sub in @('bin', 'tmp', 'resp', 'repo/tests/platform')) { New-Item -ItemType Directory -Path (Join-Path $dir $sub) -Force | Out-Null }
    $tsv = [Text.StringBuilder]::new(); $n = 0
    foreach ($k in @($responses.Keys)) {
        $n++; $v = $responses[$k]; $ks = [string]$k
        if ($ks.IndexOf([char]9) -ge 0 -or $ks.IndexOf([char]10) -ge 0 -or $ks.IndexOf([char]13) -ge 0) { throw "fixture key contains a tab or a line break: $ks" }
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.out"), [string]$v.out, $utf8)
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.err"), [string]$v.err, $utf8)
        [void]$tsv.Append("$n`t$([int]$v.code)`t$ks`n")
    }
    [IO.File]::WriteAllText((Join-Path $dir 'responses.tsv'), $tsv.ToString(), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'kubeconfig.yaml'), "apiVersion: v1`nkind: Config`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/kubectl.cmd'), $shimBody, $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-kubectl.ps1'), $fakeKubectl, $utf8)
    if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { Copy-Item -LiteralPath $harnessPath -Destination (Join-Path $dir 'repo/tests/platform/kafka.tests.ps1') }
    return $dir
}
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('kafkatest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'responses.tsv') -PathType Leaf)) {
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
# 픽스처 응답 하나(key)를 실패 응답(exit 1 · stderr = $err)으로 바꾼다 — stderr에 픽스처 kubeconfig 경로 · 홈 경로를 실어 마스킹 회귀를 잡는다(X06; 준수 리뷰 F2)
function Set-FixtureErr([string]$dir, [string]$key, [string]$err) {
    $utf8 = [Text.UTF8Encoding]::new($false)
    $rows = [IO.File]::ReadAllLines((Join-Path $dir 'responses.tsv'), $utf8)
    $out = @(); $hit = $false
    foreach ($row in $rows) {
        $f = $row.Split([char[]]@([char]9), 3)
        if ($f.Count -eq 3 -and (Test-Same $f[2] $key)) {
            $hit = $true; $out += "$($f[0])`t1`t$($f[2])"
            [IO.File]::WriteAllText((Join-Path $dir "resp/$($f[0]).out"), '', $utf8)
            [IO.File]::WriteAllText((Join-Path $dir "resp/$($f[0]).err"), $err, $utf8)
        } else { $out += $row }
    }
    if (-not $hit) { throw "no fixture row for key $key" }
    [IO.File]::WriteAllText((Join-Path $dir 'responses.tsv'), (($out -join "`n") + "`n"), $utf8)
}
# 하네스 사본을 자식 pwsh로 실행한다(출처: cluster-tests.tests.ps1 Invoke-Harness). 환경은 자식에게만 준다.
#   $kubeconfigValue: '' = 픽스처 kubeconfig.yaml(기본), '<unset>' = KUBECONFIG 제거, 그 밖 = 그 값(gate-2 경로 목록 사례 X16)
function Invoke-Harness([string]$dir, [int]$timeoutSec = 180, [string]$kubeconfigValue = '') {
    $h = Join-Path $dir 'repo/tests/platform/kafka.tests.ps1'
    if (-not (Test-Path -LiteralPath $h -PathType Leaf)) { return @{ out = "<missing harness: $harnessPath>"; err = ''; code = 127; wall = 0.0; timedOut = $false } }
    $childPath = (Join-Path $dir 'bin') + $sep + $script:safePath
    $first = Find-FirstCommand $childPath 'kubectl'
    if (-not [string]::Equals($first, (Join-Path (Join-Path $dir 'bin') 'kubectl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first kubectl on the child PATH is '$first', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    foreach ($n in @('oci', 'curl')) {
        $f = Find-FirstCommand $childPath $n
        if ($null -ne $f) { return @{ out = "<refusing to run: '$n' is reachable on the child PATH ($f)>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    }
    $psi = [Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    foreach ($x in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $h)) { $psi.ArgumentList.Add([string]$x) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # 하네스는 stdout이 리다이렉트되면 UTF-8로 쓴다(kafka.tests.ps1 머리) — 콘솔 코드 페이지와 무관하게 UTF-8로 읽는다([Console]::OutputEncoding 디코딩은 CP437 등에서 C26b가 깨진다; 2라운드 재검 실측)
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $psi.Environment['KUBECONFIG'] = Join-Path $dir 'kubeconfig.yaml'
    if (Test-Same $kubeconfigValue '<unset>') { [void]$psi.Environment.Remove('KUBECONFIG') } elseif ($kubeconfigValue.Length -gt 0) { $psi.Environment['KUBECONFIG'] = $kubeconfigValue }
    $psi.Environment['PATH'] = $childPath
    $psi.Environment['TMP'] = Join-Path $dir 'tmp'
    $psi.Environment['TEMP'] = Join-Path $dir 'tmp'
    foreach ($k in @('OCI_CLI_AUTH', 'OCI_CLI_PROFILE', 'OCI_CLI_CONFIG_FILE')) { [void]$psi.Environment.Remove($k) }
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

# ---------- 결과 · 호출 기록 도우미(출처: cluster-tests.tests.ps1) ----------
function Get-Lines($r) { return @(($r.out.TrimEnd("`n")) -split "`n") }
function Format-Result($r) {
    $lines = @(Get-Lines $r)
    $tail = if ($lines.Count -gt 12) { @('...') + $lines[($lines.Count - 12)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
}
function Get-IdResult($r, [string]$id) {
    $hits = @(@(Get-Lines $r) | Where-Object { $l = $_; @(@('PASS', 'FAIL', 'SKIP') | Where-Object { $l.StartsWith("$_ ${id}: ", [StringComparison]::Ordinal) }).Count -gt 0 })
    if ($hits.Count -ne 1) { return @{ n = $hits.Count; status = ''; detail = ''; line = ($hits -join ' || ') } }
    $l = [string]$hits[0]
    return @{ n = 1; status = $l.Substring(0, 4); detail = $l.Substring(("XXXX ${id}: ").Length); line = $l }
}
function Assert-Id([string]$name, $r, [string]$id, [string]$status, [string[]]$has = @(), [string[]]$hasNot = @()) {
    $x = Get-IdResult $r $id
    $bad = @()
    if ($x.n -ne 1) { $bad += "expected exactly 1 line for $id, got $($x.n)" }
    elseif (-not (Test-Same $x.status $status)) { $bad += "status $($x.status) (expected $status)" }
    foreach ($h in $has) { if (-not (Has-Text $x.detail $h)) { $bad += "detail lacks [$h]" } }
    foreach ($h in $hasNot) { if (Has-Text $x.detail $h) { $bad += "detail contains [$h]" } }
    Assert $name ($bad.Count -eq 0) "$($bad -join '; ') :: line=[$($x.line)]"
}
function Assert-IdExact([string]$name, $r, [string]$id, [string]$status, [string]$detail) {
    $x = Get-IdResult $r $id
    Assert $name ($x.n -eq 1 -and (Test-Same $x.status $status) -and (Test-Same $x.detail $detail)) "expected [$status ${id}: $detail] :: got $($x.n) line(s) [$($x.line)]"
}
function Get-Calls([string]$dir) {
    $p = Join-Path $dir 'calls.log'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @() }
    return @(foreach ($l in [IO.File]::ReadAllLines($p)) {
            if ($l.Trim().Length -eq 0) { continue }
            $f = $l.Split([char[]]@([char]9), 5)
            @{ served = $f[0]; code = $(if ($f.Count -ge 2) { $f[1] } else { '' }); kubeconfig = $(if ($f.Count -ge 3) { $f[2] } else { '' }); requestTimeout = $(if ($f.Count -ge 4) { $f[3] } else { '' }); key = $(if ($f.Count -ge 5) { $f[4] } else { '' }) }
        })
}
function Format-Calls($calls) { return 'calls=[' + ((@(@($calls) | Select-Object -First 80 | ForEach-Object { "$($_['served']):$($_['key'])" })) -join ' | ') + ']' }
function Count-Key($calls, [string]$key) { return @(@($calls) | Where-Object { Test-Same ([string]$_['key']) $key }).Count }
# 읽기 전용 동사만: get · auth whoami · auth can-i · -n <ns> get|logs
function Test-ReadOnlyKey([string]$key) {
    $t = @($key.Split(' '))
    if ($t.Count -ge 1 -and (Test-Same $t[0] 'get')) { return $true }
    if ($t.Count -ge 2 -and (Test-Same $t[0] 'auth') -and ((Test-Same $t[1] 'whoami') -or (Test-Same $t[1] 'can-i'))) { return $true }
    if ($t.Count -ge 3 -and (Test-Same $t[0] '-n') -and ((Test-Same $t[2] 'get') -or (Test-Same $t[2] 'logs'))) { return $true }
    return $false
}
# 모든 실행 공통: 끝까지 돌았다(마지막 줄 = 요약) · 읽기 전용 동사만 · 응답표 밖 호출 0 · 모든 호출이 픽스처 kubeconfig를 --kubeconfig로 명시 · 픽스처 TEMP 잔존 0
function Assert-Run([string]$id, $r, [string]$dir) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    Assert "${id}-end: harness ran to completion (no timeout; last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and [regex]::IsMatch($last, '\A\d+ passed, \d+ failed, 0 skipped\z')) (Format-Result $r)
    $calls = @(Get-Calls $dir)
    $notRo = @($calls | Where-Object { -not (Test-ReadOnlyKey ([string]$_['key'])) })
    Assert "${id}-ro: every kubectl call used a read-only verb (get / auth whoami / logs)" ($calls.Count -gt 0 -and $notRo.Count -eq 0) "calls=$($calls.Count) :: not read-only: $((@($notRo | ForEach-Object { $_['key'] })) -join ' || ')"
    $unserved = @($calls | Where-Object { Test-Same ([string]$_['served']) 'default' })
    Assert "${id}-served: every kubectl call matched a fixture response (no call outside the scenario)" ($unserved.Count -eq 0) "outside: $((@($unserved | ForEach-Object { $_['key'] })) -join ' || ')"
    $kc = Join-Path $dir 'kubeconfig.yaml'
    $badKc = @($calls | Where-Object { -not [string]::Equals([string]$_['kubeconfig'], $kc, [StringComparison]::OrdinalIgnoreCase) })
    Assert "${id}-kc: every kubectl call named the fixture kubeconfig explicitly (--kubeconfig)" ($badKc.Count -eq 0) "without it: $((@($badKc | ForEach-Object { $_['key'] })) -join ' || ')"
    $left = @(Get-ChildItem -LiteralPath (Join-Path $dir 'tmp') -File -Recurse -ErrorAction SilentlyContinue)
    Assert "${id}-tmp: no temp file left behind in the fixture TEMP (kafka-tests-* stderr files removed)" ($left.Count -eq 0) "left: $((@($left | ForEach-Object { $_.Name })) -join ', ')"
}
function Assert-NotCalled([string]$name, [string]$dir, [string[]]$keys) {
    $calls = @(Get-Calls $dir)
    $hit = @($keys | Where-Object { (Count-Key $calls $_) -gt 0 })
    Assert $name ($hit.Count -eq 0) "called: $($hit -join ' || ') :: $(Format-Calls $calls)"
}
# 요약 줄 숫자
function Get-Summary($r) {
    $lines = @(Get-Lines $r); $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    $m = [regex]::Match($last, '\A(\d+) passed, (\d+) failed, (\d+) skipped\z')
    if (-not $m.Success) { return @{ ok = $false; pass = -1; fail = -1; skip = -1 } }
    return @{ ok = $true; pass = [int]$m.Groups[1].Value; fail = [int]$m.Groups[2].Value; skip = [int]$m.Groups[3].Value }
}
# 변이 케이스 공통: 전부 갖춘 응답표에 $mutate를 적용 → $failId 하나만 FAIL(문구 조각 $has 포함 · $hasNot 불포함) · 나머지 16개는 PASS(문구 정확) · exit 1 · 요약 16/1/0
function Test-Mutation([string]$caseId, [string]$failId, [string[]]$has, [scriptblock]$mutate, [string[]]$hasNot = @()) {
    $resp = New-GoodResponses
    & $mutate $resp
    $d = New-Fixture $resp
    $r = Invoke-Harness $d
    Assert-Run $caseId $r $d
    Assert-Id "${caseId}-1: $failId is the one FAIL and its reason is exact" $r $failId 'FAIL' $has (@($hasNot) + @('unhandled'))
    $others = @($allIds | Where-Object { -not (Test-Same $_ $failId) })
    $bad = @()
    foreach ($id in $others) { $x = Get-IdResult $r $id; if ($x.n -ne 1 -or -not (Test-Same $x.status 'PASS') -or -not (Test-Same $x.detail ([string]$passText[$id]))) { $bad += "$id=[$($x.line)]" } }
    Assert "${caseId}-2: the other 16 ids PASS with their exact text (only $failId is affected)" ($bad.Count -eq 0) ($bad -join ' ;; ')
    $s = Get-Summary $r
    Assert "${caseId}-3: summary 16 passed, 1 failed, 0 skipped and exit 1" ($s.ok -and $s.pass -eq 16 -and $s.fail -eq 1 -and $s.skip -eq 0 -and $r.code -eq 1) (Format-Result $r)
}

# ---------- 함수 케이스용: 하네스의 최상위 함수만 동적 모듈에 정의한다(출처: cluster-tests.tests.ps1 Import-HarnessModule — 상수는 가져오지 않는다) ----------
function Import-HarnessModule([string]$path) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "harness does not parse: $(@($errors)[0].Message)" }
    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $text = ((@($funcs | ForEach-Object { $_.Extent.Text })) -join "`n") + "`nExport-ModuleMember -Function @()`n"
    return (New-Module -Name ('kafkaharness-' + [guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($text)))
}
function Test-ModuleHas($mod, [string]$fn) { return [bool](& $mod { param($n) $null -ne (Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue) } $fn) }

try {
    # ================= 전부 갖춘 픽스처 =================
    Test-Case 'C01' 'all declared values present -> 17 PASS with exact text, exit 0; logs read once per Job; the entity-operator pod on node B is ignored' {
        $d = New-Fixture (New-GoodResponses)
        $r = Invoke-Harness $d
        Assert-Run 'C01' $r $d
        foreach ($id in $allIds) { Assert-IdExact "C01-1 ${id}: PASS with the exact text" $r $id 'PASS' $passText[$id] }
        $s = Get-Summary $r
        Assert 'C01-2: summary 17 passed, 0 failed, 0 skipped and exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $s.skip -eq 0 -and $r.code -eq 0) (Format-Result $r)
        $calls = @(Get-Calls $d)
        Assert 'C01-3: each Job log was fetched exactly once (cached across job-k-2/job-k-3 and job-d-2) and the Kafka CR once' ((Count-Key $calls (LogsKey 'kafka-assert')) -eq 1 -and (Count-Key $calls (LogsKey 'data-assert')) -eq 1 -and (Count-Key $calls $Q.kafka) -eq 1 -and (Count-Key $calls $Q.users) -eq 1) (Format-Calls $calls)
    }
    Test-Case 'C02' 'representation variants still PASS: auto.create "false" string, retention.ms number, --maxmemory split, literal ACLs + old single operation, spec.topicName set, KafkaNodePool with a Ready condition' {
        $resp = New-GoodResponses
        $resp[$Q.kafka] = R-Json (New-Kafka @{ autoCreate = 'false' })
        $resp[$Q.pools] = R-Json (New-List @(New-Pool @{ ready = 'True'; statusReplicas = '<absent>' }))
        $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin-session-revoked' @{ topicName = 'identity-admin.session.revoked'; retention = 604800000 }), (New-Topic 'dev.identity-admin.session.revoked' @{ retention = 604800000 }), (New-Topic 'identity-admin.dlq'), (New-Topic 'dev.identity-admin.dlq')))
        $prodAcls = @((New-Acl 'identity-admin.session.revoked' '' @('Write', 'Describe')), (New-Acl 'identity-admin.dlq' 'literal' @() 'topic' '' 'Write'), (New-Acl 'identity-admin.session.revoked' 'literal' @('Read') 'topic'))
        $devAcls = @((New-Acl 'dev.identity-admin.session.revoked' 'literal' @('All')), (New-Acl 'dev.identity-admin.dlq' 'literal' @('Write')))
        $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin' @{ acls = $prodAcls }), (New-User 'dev-identity-admin' @{ acls = $devAcls })))
        $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ args = @('--maxmemory', '768mb', '--aclfile=/etc/dragonfly/users.acl', '--dir', '/data') })
        $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ sec = 41; ms = 5000 })   # 벽시계 41 s(상한 30 s 안이 아니어도 하네스는 보지 않는다) · latency 경계값 5000
        $d = New-Fixture $resp
        $r = Invoke-Harness $d
        Assert-Run 'C02' $r $d
        Assert-IdExact 'C02-1 kafka-1: string "false" accepted' $r 'kafka-1' 'PASS' $passText['kafka-1']
        Assert-IdExact 'C02-2 pool-1: a Ready=True condition is used when present (status.replicas absent)' $r 'pool-1' 'PASS' 'KafkaNodePool data/combined (cluster jt-kafka): replicas 1, roles {broker, controller}, Ready=True'
        Assert-IdExact 'C02-3 topic-1: spec.topicName and numeric retention.ms accepted' $r 'topic-1' 'PASS' $passText['topic-1']
        Assert-IdExact 'C02-4 user-2: literal names, the old single operation and All count as Write' $r 'user-2' 'PASS' 'identity-admin: topic Write on identity-admin.* only (2 of 3 ACLs); dev-identity-admin: topic Write on dev.identity-admin.* only (2 of 2 ACLs) -- no cross-env Write'
        Assert-IdExact 'C02-5 df-1: split --maxmemory and --aclfile=… accepted' $r 'df-1' 'PASS' $passText['df-1']
        Assert-IdExact 'C02-7 job-k-3: latency exactly 5000ms PASSes (boundary) and the 41s wall clock is reported, not judged' $r 'job-k-3' 'PASS' "roundtrip latency 5000ms <= 5000ms (message path, spec US3 AC3; the Job's wall clock 41s includes JVM startup and the consumer idle wait)"
        $s = Get-Summary $r
        Assert 'C02-6: summary 17 passed, 0 failed, exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $r.code -eq 0) (Format-Result $r)
    }

    # ================= 지금 라이브 모양 =================
    Test-Case 'C03' 'live-like state (no Strimzi CRD, no Dragonfly, no assert Job) -> gates PASS, all 14 checks FAIL with isolated reasons, no "unhandled", logs never requested' {
        $d = New-Fixture (New-LiveResponses)
        $r = Invoke-Harness $d
        Assert-Run 'C03' $r $d
        foreach ($id in $gateIds) { Assert-IdExact "C03-0 ${id}: PASS" $r $id 'PASS' $passText[$id] }
        foreach ($id in @('kafka-1', 'kafka-2')) { Assert-Id "C03-1 ${id}: FAIL names the missing CRD (T055)" $r $id 'FAIL' @('Kafka data/jt-kafka: CRD kafkas.kafka.strimzi.io not installed (T055)', 'doesn''t have a resource type "kafkas"') @('unhandled') }
        Assert-Id 'C03-2 pool-1: FAIL names the missing CRD (T055)' $r 'pool-1' 'FAIL' @('KafkaNodePool ns data: CRD kafkanodepools.kafka.strimzi.io not installed (T055)') @('unhandled')
        Assert-Id 'C03-3 pool-2: FAIL -- no Kafka node pod (T055)' $r 'pool-2' 'FAIL' @('no Kafka node pod in ns data', 'pods with the cluster label: 0', '(T055)') @('unhandled')
        Assert-Id 'C03-4 topic-1: FAIL names the missing CRD (T055)' $r 'topic-1' 'FAIL' @('KafkaTopic ns data: CRD kafkatopics.kafka.strimzi.io not installed (T055)') @('unhandled')
        foreach ($id in @('user-1', 'user-2')) { Assert-Id "C03-5 ${id}: FAIL names the missing CRD (T055)" $r $id 'FAIL' @('KafkaUser ns data: CRD kafkausers.kafka.strimzi.io not installed (T055)') @('unhandled') }
        Assert-Id 'C03-6 df-1: FAIL lists both missing Deployments (T057)' $r 'df-1' 'FAIL' @('2 problem(s)', 'Deployment data/dragonfly-dev not found (T057)', 'Deployment data/dragonfly-prod not found (T057)') @('unhandled')
        Assert-Id 'C03-7 df-2: FAIL lists both missing Services (T057)' $r 'df-2' 'FAIL' @('2 problem(s)', 'Service data/dragonfly-dev not found (T057)', 'Service data/dragonfly-prod not found (T057)') @('unhandled')
        foreach ($id in @('job-k-1', 'job-k-2', 'job-k-3')) { Assert-IdExact "C03-8 ${id}: FAIL -- Job kafka-assert not found (not deployed yet, or removed by its 7-day TTL)" $r $id 'FAIL' 'Job jt-dev/kafka-assert not found (platform/policies/tests not deployed yet (after T055-T057), or the Job was removed by ttlSecondsAfterFinished=7d -- re-run it)' }
        foreach ($id in @('job-d-1', 'job-d-2')) { Assert-IdExact "C03-9 ${id}: FAIL -- Job data-assert not found (not deployed yet, or removed by its 7-day TTL)" $r $id 'FAIL' 'Job jt-dev/data-assert not found (platform/policies/tests not deployed yet (after T055-T057), or the Job was removed by ttlSecondsAfterFinished=7d -- re-run it)' }
        Assert-NotCalled 'C03-10: no kubectl logs call when the Jobs are absent' $d @((LogsKey 'kafka-assert'), (LogsKey 'data-assert'))
        $s = Get-Summary $r
        Assert 'C03-11: summary 3 passed, 14 failed, 0 skipped and exit 1' ($s.ok -and $s.pass -eq 3 -and $s.fail -eq 14 -and $s.skip -eq 0 -and $r.code -eq 1) (Format-Result $r)
        Assert 'C03-12: no "unhandled" anywhere in the output (every lookup error became a reason)' (@(@(Get-Lines $r) | Where-Object { Has-Text $_ 'unhandled' }).Count -eq 0) (Format-Result $r)
    }

    # ================= 변이 하나 = 해당 ID만 FAIL =================
    Test-Case 'C04' 'kafka-1: Ready=False -> only kafka-1 FAILs' { Test-Mutation 'C04' 'kafka-1' @("Kafka data/jt-kafka: 1 problem(s): Ready condition status='False' (expected True) [Fixture: ready=false fixture]") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ ready = 'False' }) } }
    Test-Case 'C04b' 'kafka-1: duplicate Ready conditions [True, False] -> only kafka-1 FAILs as ambiguous (the first entry is not trusted)' { Test-Mutation 'C04b' 'kafka-1' @("Kafka data/jt-kafka: 1 problem(s): Ready condition status='ambiguous: 2 Ready conditions [True, False]' (expected True) [DuplicateCondition]") { param($resp) $k = New-Kafka; $k.status.conditions = @((New-Cond 'Ready' 'True'), (New-Cond 'Ready' 'False')); $resp[$Q.kafka] = R-Json $k } }
    Test-Case 'C04c' 'kafka-1: duplicate Ready conditions in the other order [False, True] -> only kafka-1 FAILs as ambiguous (order does not matter)' { Test-Mutation 'C04c' 'kafka-1' @("Kafka data/jt-kafka: 1 problem(s): Ready condition status='ambiguous: 2 Ready conditions [False, True]' (expected True) [DuplicateCondition]") { param($resp) $k = New-Kafka; $k.status.conditions = @((New-Cond 'Ready' 'False'), (New-Cond 'Ready' 'True')); $resp[$Q.kafka] = R-Json $k } }
    Test-Case 'C05' 'kafka-1: NotReady only (no Ready condition) -> only kafka-1 FAILs with the NotReady reason' { Test-Mutation 'C05' 'kafka-1' @('no Ready condition; NotReady=True [InvalidConfigurationException: fixture: broker config rejected]') { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ ready = 'notready' }) } }
    Test-Case 'C06' 'kafka-1: version 4.2.0 -> only kafka-1 FAILs' { Test-Mutation 'C06' 'kafka-1' @("spec.kafka.version='4.2.0' (expected 4.3.1)") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ version = '4.2.0' }) } }
    Test-Case 'C07' 'kafka-1: auto.create.topics.enable=true -> only kafka-1 FAILs' { Test-Mutation 'C07' 'kafka-1' @('spec.kafka.config[auto.create.topics.enable]=true (expected false; absent = broker default true)') { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ autoCreate = $true }) } }
    Test-Case 'C08' 'kafka-1: auto.create.topics.enable absent + sync-options missing -> only kafka-1 FAILs with both reasons' { Test-Mutation 'C08' 'kafka-1' @('2 problem(s)', 'spec.kafka.config[auto.create.topics.enable]=<absent> (expected false; absent = broker default true)', "annotation argocd.argoproj.io/sync-options=<absent> (expected exactly '$sync')") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ autoCreate = '<absent>'; syncOpt = $null }) } }
    Test-Case 'C09' 'kafka-2: listener tls with authentication tls (not scram) -> only kafka-2 FAILs' { Test-Mutation 'C09' 'kafka-2' @("listener tls: authentication.type='tls' (expected scram-sha-512)") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ listenerAuth = 'tls' }) } }
    Test-Case 'C10' 'kafka-2: listener named plain instead of tls + authorization custom -> only kafka-2 FAILs with both reasons' { Test-Mutation 'C10' 'kafka-2' @('2 problem(s)', 'listener named tls x0 (expected exactly 1; listeners: [plain])', "spec.kafka.authorization.type='custom' (expected simple)") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ listenerName = 'plain'; authz = 'custom' }) } }
    Test-Case 'C11' 'pool-1: two KafkaNodePools for jt-kafka -> only pool-1 FAILs' { Test-Mutation 'C11' 'pool-1' @('expected exactly 1 KafkaNodePool labelled strimzi.io/cluster=jt-kafka in ns data, got 2: combined, brokers') { param($resp) $resp[$Q.pools] = R-Json (New-List @((New-Pool), (New-Pool @{ name = 'brokers'; roles = @('broker') }))) } }
    Test-Case 'C12' 'pool-1: roles {broker} only (a subset) -> only pool-1 FAILs' { Test-Mutation 'C12' 'pool-1' @('KafkaNodePool data/combined: 1 problem(s): spec.roles=[broker] (expected exactly {broker, controller})') { param($resp) $resp[$Q.pools] = R-Json (New-List @(New-Pool @{ roles = @('broker') })) } }
    Test-Case 'C13' 'pool-2: the Kafka node pod sits on the role=data node -> only pool-2 FAILs' { Test-Mutation 'C13' 'pool-2' @("Kafka node pods: 1 problem(s): jt-kafka-combined-0: node 'node-b' has role='data' (expected platform)") { param($resp) $resp[$Q.pods] = R-Json (New-List @((New-KafkaPod @{ node = 'node-b' }), (New-EoPod))) } }
    Test-Case 'C14' 'pool-2: the Kafka node pod is Pending -> only pool-2 FAILs' { Test-Mutation 'C14' 'pool-2' @("jt-kafka-combined-0: phase='Pending' (expected Running)") { param($resp) $resp[$Q.pods] = R-Json (New-List @((New-KafkaPod @{ phase = 'Pending' }), (New-EoPod))) } }
    Test-Case 'C14b' 'pool-2: the Kafka node pod is Running but CrashLoopBackOff (Ready=False) -> only pool-2 FAILs' { Test-Mutation 'C14b' 'pool-2' @("Kafka node pods: 1 problem(s): jt-kafka-combined-0: pod condition Ready='False' (expected True; phase Running alone also matches CrashLoopBackOff) [ContainersNotReady: containers with unready status: [kafka]]") { param($resp) $resp[$Q.pods] = R-Json (New-List @((New-KafkaPod @{ podReady = 'False' }), (New-EoPod))) } }
    Test-Case 'C15' 'topic-1: dev session topic has partitions 2 -> only topic-1 FAILs' { Test-Mutation 'C15' 'topic-1' @('KafkaTopics (cluster jt-kafka, 4 object(s)): 1 problem(s): dev.identity-admin.session.revoked: spec.partitions=2 (expected 3)') { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked' @{ partitions = 2 }), (New-Topic 'identity-admin.dlq'), (New-Topic 'dev.identity-admin.dlq'))) } }
    Test-Case 'C16' 'topic-1: retention.ms 86400000 on the prod dlq -> only topic-1 FAILs' { Test-Mutation 'C16' 'topic-1' @("identity-admin.dlq: spec.config[retention.ms]='86400000' (expected 604800000)") { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked'), (New-Topic 'identity-admin.dlq' @{ retention = '86400000' }), (New-Topic 'dev.identity-admin.dlq'))) } }
    Test-Case 'C17' 'topic-1: one topic missing, one extra -> only topic-1 FAILs naming the missing one' { Test-Mutation 'C17' 'topic-1' @('missing KafkaTopic(s) for cluster jt-kafka: dev.identity-admin.dlq (T056)') { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked'), (New-Topic 'identity-admin.dlq'), (New-Topic 'other.topic'))) } }
    Test-Case 'C18' 'user-1: dev-identity-admin Ready=False -> only user-1 FAILs' { Test-Mutation 'C18' 'user-1' @("KafkaUsers (cluster jt-kafka, 2 object(s)): 1 problem(s): dev-identity-admin: Ready condition status='False' (expected True)") { param($resp) $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin'), (New-User 'dev-identity-admin' @{ ready = 'False' }))) } }
    Test-Case 'C19' 'user-2: identity-admin also has a prefix Write ACL on dev. -> only user-2 FAILs (cross-env)' { Test-Mutation 'C19' 'user-2' @("KafkaUser ACLs: 1 problem(s): identity-admin: topic Write ACL also covers dev.* (cross-env): prefix:'dev.'") { param($resp) $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin' @{ acls = @((New-Acl 'identity-admin.' 'prefix' @('Write', 'Describe')), (New-Acl 'dev.' 'prefix' @('Write'))) }), (New-User 'dev-identity-admin'))) } }
    Test-Case 'C20' 'user-2: dev-identity-admin has only a Read ACL (no Write) -> only user-2 FAILs' { Test-Mutation 'C20' 'user-2' @('dev-identity-admin: no topic Write ACL covering dev.identity-admin.* (literal or prefix) among 1 ACL(s)') { param($resp) $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin'), (New-User 'dev-identity-admin' @{ acls = @((New-Acl 'dev.identity-admin.' 'prefix' @('Read', 'Describe'))) }))) } }
    Test-Case 'C21' 'df-1: dragonfly-prod --maxmemory=512mb -> only df-1 FAILs' { Test-Mutation 'C21' 'df-1' @("1 problem(s): Deployment data/dragonfly-prod: args lack --maxmemory=768mb (got ['512mb'])") { param($resp) $resp[(DeployKey 'dragonfly-prod')] = R-Json (New-Deployment 'dragonfly-prod' @{ args = @('--maxmemory=512mb', '--aclfile', '/etc/dragonfly/users.acl') }) } }
    Test-Case 'C21b' 'df-1: dragonfly-prod scaled to zero (Available=True, replicas 0, availableReplicas absent) -> only df-1 FAILs' { Test-Mutation 'C21b' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: spec.replicas=0 (expected 1); status.availableReplicas=<absent> (expected 1; Available=True is vacuous at 0 replicas)') { param($resp) $d = New-Deployment 'dragonfly-prod'; $d.spec.replicas = 0; $d.status = [ordered]@{ observedGeneration = 1; conditions = @((New-Cond 'Available' 'True' 'MinimumReplicasAvailable')) }; $resp[(DeployKey 'dragonfly-prod')] = R-Json $d } }
    Test-Case 'C21c' 'df-1: dragonfly-dev with availableReplicas 0 while Available=True -> only df-1 FAILs' { Test-Mutation 'C21c' 'df-1' @('1 problem(s): Deployment data/dragonfly-dev: status.availableReplicas=0 (expected 1; Available=True is vacuous at 0 replicas)') { param($resp) $d = New-Deployment 'dragonfly-dev'; $d.status.availableReplicas = 0; $d.status.readyReplicas = 0; $resp[(DeployKey 'dragonfly-dev')] = R-Json $d } }
    Test-Case 'C22' 'df-1: dragonfly-dev carries --requirepass -> only df-1 FAILs and the password value is never printed' { Test-Mutation 'C22' 'df-1' @('Deployment data/dragonfly-dev: args carry --requirepass (passwords must come from the aclfile only)') { param($resp) $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ args = @($dfArgs + @('--requirepass=hunter2')) }) } -hasNot @('hunter2') }
    Test-Case 'C22b' 'df-1: dragonfly-prod sets DFLY_requirepass (secretKeyRef) + DFLY_PASSWORD (value) + envFrom -> only df-1 FAILs with the three env reasons, value never printed' { Test-Mutation 'C22b' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: env DFLY_requirepass set (requirepass via the environment; passwords must come from the aclfile only); env DFLY_PASSWORD set (requirepass via the environment; passwords must come from the aclfile only); envFrom present (DFLY_requirepass/DFLY_PASSWORD cannot be ruled out without reading the referenced Secret/ConfigMap; T057 declares no envFrom)') { param($resp) $resp[(DeployKey 'dragonfly-prod')] = R-Json (New-Deployment 'dragonfly-prod' @{ env = @([ordered]@{ name = 'DFLY_requirepass'; valueFrom = [ordered]@{ secretKeyRef = [ordered]@{ name = 'dragonfly-auth'; key = 'password' } } }, [ordered]@{ name = 'DFLY_PASSWORD'; value = 'hunter2' }); envFrom = @([ordered]@{ secretRef = [ordered]@{ name = 'dragonfly-env' } }) }) } -hasNot @('hunter2', 'dragonfly-auth') }
    Test-Case 'C23' 'df-1: grace 30 + RollingUpdate + automount absent on dragonfly-dev -> only df-1 FAILs with the three reasons' { Test-Mutation 'C23' 'df-1' @('Deployment data/dragonfly-dev: terminationGracePeriodSeconds=30 (expected 60); strategy.type=''RollingUpdate'' (expected Recreate); automountServiceAccountToken=<absent> (expected false; absent = default true)') { param($resp) $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ grace = 30; strategy = 'RollingUpdate'; automount = '<absent>' }) } }
    Test-Case 'C24' 'df-2: dragonfly-prod Service port 6380 -> only df-2 FAILs' { Test-Mutation 'C24' 'df-2' @('1 problem(s): Service data/dragonfly-prod: ports [6380] lack 6379') { param($resp) $resp[(SvcKey 'dragonfly-prod')] = R-Json (New-Service 'dragonfly-prod' @(6380)) } }
    Test-Case 'C25' 'job-k-1: kafka-assert failed (succeeded 0, failed 1) while its log still reads PASS -> only job-k-1 FAILs' { Test-Mutation 'C25' 'job-k-1' @('Job jt-dev/kafka-assert has not succeeded (status.succeeded=0, status.failed=1)') { param($resp) $resp[(JobKey 'kafka-assert')] = R-Json (New-Job 'kafka-assert' 0 1) } }
    Test-Case 'C26' 'job-k-3: latency 7000ms (the Job PASSes under its 30s wall-clock deadline) -> only job-k-3 FAILs' { Test-Mutation 'C26' 'job-k-3' @("roundtrip latency 7000ms > 5000ms (spec US3 AC3: produce->consume within 5 s; the Job's own 30 s wall-clock deadline is a separate check)") { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ ms = 7000 }) } }
    Test-Case 'C26b' 'job-k-3: the current Job shape (wall clock 23s, no latency token) -> only job-k-3 FAILs naming the missing token and the wall clock' { Test-Mutation 'C26b' 'job-k-3' @('roundtrip evidence has no latency=<n>ms token (the Job does not emit it yet -- T056 adds it; wall-clock 23s includes JVM startup and the consumer idle wait): dev.identity-admin.session.revoked produce→consume 23s (상한 30s, JVM 기동 포함)') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ ms = '<absent>' }) } }
    Test-Case 'C27' 'job-k-2: SUMMARY fail=1 with both RESULT lines PASS -> only job-k-2 FAILs (fail!=0 and the count mismatch)' { Test-Mutation 'C27' 'job-k-2' @('Job jt-dev/kafka-assert log: 2 problem(s): SUMMARY fail=1 (expected 0): SUMMARY: pass=2 fail=1; SUMMARY pass=2 fail=1 does not match the RESULT lines seen (2 PASS, 0 FAIL) -- log truncated by --tail=50 or inconsistent Job output') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ summary = 'SUMMARY: pass=2 fail=1' }) } }
    Test-Case 'C27b' 'job-k-2: SUMMARY pass=3 fail=0 while only 2 RESULT lines are visible (truncated log) -> only job-k-2 FAILs' { Test-Mutation 'C27b' 'job-k-2' @('Job jt-dev/kafka-assert log: 1 problem(s): SUMMARY pass=3 fail=0 does not match the RESULT lines seen (2 PASS, 0 FAIL) -- log truncated by --tail=50 or inconsistent Job output') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ summary = 'SUMMARY: pass=3 fail=0' }) } }
    Test-Case 'C28' 'job-k-2: cross-env-denied RESULT FAIL + SUMMARY missing -> only job-k-2 FAILs with both reasons; job-k-3 still reads roundtrip' { Test-Mutation 'C28' 'job-k-2' @('2 problem(s)', 'cross-env-denied: RESULT FAIL -- dev', '0 SUMMARY line(s) in the last 50 log lines (expected exactly 1)') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ cross = 'FAIL'; summary = '' }) } }
    Test-Case 'C29' 'job-d-2: the current (T041) Job shape emits only acl-list and noperm -> only job-d-2 FAILs naming the five ids T057 adds' { Test-Mutation 'C29' 'job-d-2' @('Job jt-dev/data-assert log (Dragonfly section): 1 problem(s): no RESULT line for noauth, writer-set, reader-get, reader-set-denied, reader-cross-denied (the Job does not emit these check ids yet; T057 adds them)') { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ ids = @('acl-list', 'noperm') }) } }
    Test-Case 'C29b' 'job-d-2: SUMMARY pass=12 fail=0 while 11 RESULT lines are visible (truncated log) -> only job-d-2 FAILs' { Test-Mutation 'C29b' 'job-d-2' @('Job jt-dev/data-assert log (Dragonfly section): 1 problem(s): SUMMARY pass=12 fail=0 does not match the RESULT lines seen (11 PASS, 0 FAIL) -- log truncated by --tail=50 or inconsistent Job output') { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ summary = 'SUMMARY: pass=12 fail=0' }) } }
    Test-Case 'C30' 'job-d-2: reader-get missing + noperm RESULT FAIL -> only job-d-2 FAILs with both reasons' { Test-Mutation 'C30' 'job-d-2' @('2 problem(s)', 'no RESULT line for reader-get (the Job does not emit these check ids yet; T057 adds them)', 'noperm: RESULT FAIL -- fixture failure for noperm') { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ ids = @('acl-list', 'noperm', 'noauth', 'writer-set', 'reader-set-denied', 'reader-cross-denied'); fail = @('noperm') }) } }
    Test-Case 'C31' 'job-d-2: acl-list evidence and EVIDENCE lines lack %R~revoked:* -> only job-d-2 FAILs (pattern absent, VD-4)' { Test-Mutation 'C31' 'job-d-2' @("1 problem(s): pattern %R~revoked:* absent from the acl-list evidence and from the EVIDENCE: lines on the sample-pod row (5 EVIDENCE: line(s); other users' rows do not count) (VD-4)") { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ aclPattern = $false }) } }
    Test-Case 'C31b' 'job-d-2: %R~revoked:* only on the identity-admin EVIDENCE row (not on sample-pod, not in the acl-list evidence) -> only job-d-2 FAILs' { Test-Mutation 'C31b' 'job-d-2' @("1 problem(s): pattern %R~revoked:* absent from the acl-list evidence and from the EVIDENCE: lines on the sample-pod row (5 EVIDENCE: line(s); other users' rows do not count) (VD-4)") { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ patternRow = 'identity-admin' }) } }
    Test-Case 'C32' 'job-d-2: noperm printed twice + acl-list RESULT FAIL (evidence hidden) -> only job-d-2 FAILs' { Test-Mutation 'C32' 'job-d-2' @('2 problem(s)', 'acl-list: RESULT FAIL', '2 RESULT lines for noperm (expected exactly 1)') { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw (DataLog @{ dup = 'noperm'; fail = @('acl-list') }) } -hasNot @('fixture failure for acl-list') }

    # ================= 조회 오류 격리 =================
    Test-Case 'C33' 'lookup errors: Kafka CR forbidden, topics connection refused, dragonfly-dev broken JSON, kafka-assert logs forbidden -> each affected id FAILs with that error, the rest PASS, no "unhandled"' {
        $resp = New-GoodResponses
        $resp[$Q.kafka] = R-Forbidden 'kafkas.kafka.strimzi.io "jt-kafka"'
        $resp[$Q.topics] = R-Err 'Unable to connect to the server: dial tcp 10.0.0.10:6443: connectex: No connection could be made because the target machine actively refused it.'
        $resp[(DeployKey 'dragonfly-dev')] = R-Raw '{"apiVersion":"apps/v1","kind":"Deployment","metadata":{"name":'
        $resp[(LogsKey 'kafka-assert')] = R-Forbidden 'pods "kafka-assert-abcde"'
        $d = New-Fixture $resp
        $r = Invoke-Harness $d
        Assert-Run 'C33' $r $d
        foreach ($id in @('kafka-1', 'kafka-2')) { Assert-Id "C33-1 ${id}: FAIL -- Kafka lookup forbidden (not a CRD message)" $r $id 'FAIL' @('Kafka data/jt-kafka: lookup failed:', 'Forbidden') @('not installed', 'unhandled') }
        Assert-Id 'C33-2 topic-1: FAIL -- connection refused' $r 'topic-1' 'FAIL' @('KafkaTopic ns data: lookup failed:', 'Unable to connect to the server') @('unhandled')
        Assert-Id 'C33-3 df-1: FAIL -- dragonfly-dev JSON broken, dragonfly-prod still fine' $r 'df-1' 'FAIL' @('1 problem(s)', 'Deployment data/dragonfly-dev: lookup failed: JSON parse failed') @('dragonfly-prod:', 'unhandled')
        Assert-Id 'C33-4 job-k-2: FAIL -- logs forbidden' $r 'job-k-2' 'FAIL' @('kubectl logs job/kafka-assert --tail=50 failed (exit 1)', 'Forbidden') @('unhandled')
        Assert-Id 'C33-5 job-k-3: FAIL -- the same logs error (shared lookup)' $r 'job-k-3' 'FAIL' @('kubectl logs job/kafka-assert --tail=50 failed (exit 1)') @('unhandled')
        foreach ($id in @('pool-1', 'pool-2', 'user-1', 'user-2', 'df-2', 'job-k-1', 'job-d-1', 'job-d-2')) { Assert-IdExact "C33-6 ${id}: PASS unchanged" $r $id 'PASS' $passText[$id] }
        $calls = @(Get-Calls $d)
        Assert 'C33-7: a failing lookup is not retried (Kafka CR fetched once, kafka-assert logs fetched once)' ((Count-Key $calls $Q.kafka) -eq 1 -and (Count-Key $calls (LogsKey 'kafka-assert')) -eq 1) (Format-Calls $calls)
        Assert 'C33-8: no "unhandled" anywhere' (@(@(Get-Lines $r) | Where-Object { Has-Text $_ 'unhandled' }).Count -eq 0) (Format-Result $r)
    }
    Test-Case 'C34' 'gate: whoami returns another user -> gate-3 FAIL and every check FAILs as "cluster unavailable" without any further kubectl call' {
        $resp = New-GoodResponses
        $resp[$Q.whoami] = R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = 'system:admin' } } })
        $d = New-Fixture $resp
        $r = Invoke-Harness $d
        Assert-Run 'C34' $r $d
        Assert-Id 'C34-1 gate-3: FAIL names the other user' $r 'gate-3' 'FAIL' @("context user is 'system:admin', expected $expectedUser")
        foreach ($id in $checkIds) { Assert-IdExact "C34-2 ${id}: FAIL cluster unavailable" $r $id 'FAIL' 'cluster unavailable (context user is not agent-view)' }
        $calls = @(Get-Calls $d)
        Assert 'C34-3: only the whoami call was made' ($calls.Count -eq 1 -and (Count-Key $calls $Q.whoami) -eq 1) (Format-Calls $calls)
    }

    # ================= 2라운드: 살아남은 변이를 죽이는 사례(준수 리뷰 F1–F3 원문) + 새 규칙(적대 리뷰 F8) =================
    Test-Case 'X01' 'kafka-2: listener tls on port 9092 -> only kafka-2 FAILs' { Test-Mutation 'X01' 'kafka-2' @('Kafka data/jt-kafka: 1 problem(s): listener tls: port=9092 (expected 9093)') { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ listenerPort = 9092 }) } }
    Test-Case 'X02' 'kafka-2: listener tls with tls=false -> only kafka-2 FAILs' { Test-Mutation 'X02' 'kafka-2' @('Kafka data/jt-kafka: 1 problem(s): listener tls: tls=false (expected true)') { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ listenerTls = $false }) } }
    Test-Case 'X03' 'user-1: identity-admin without status.secret -> only user-1 FAILs' { Test-Mutation 'X03' 'user-1' @('KafkaUsers (cluster jt-kafka, 2 object(s)): 1 problem(s): identity-admin: status.secret empty (no credential Secret name yet)') { param($resp) $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin' @{ secret = '' }), (New-User 'dev-identity-admin'))) } }
    Test-Case 'X04' 'df-1: dragonfly-dev without --aclfile -> only df-1 FAILs' { Test-Mutation 'X04' 'df-1' @('1 problem(s): Deployment data/dragonfly-dev: args lack --aclfile /etc/dragonfly/users.acl (got [])') { param($resp) $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ args = @('--maxmemory=768mb', '--dir', '/data') }) } }
    Test-Case 'X05' 'job-k-2: SUMMARY printed twice -> only job-k-2 FAILs' { Test-Mutation 'X05' 'job-k-2' @('Job jt-dev/kafka-assert log: 1 problem(s): 2 SUMMARY line(s) in the last 50 log lines (expected exactly 1)') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw ((KafkaLog) + "SUMMARY: pass=2 fail=0`n") } }
    Test-Case 'X06' 'masking: a kubectl error that quotes the kubeconfig path and the home directory -> the reason shows <KUBECONFIG> and ~, never the raw paths' {
        $resp = New-GoodResponses
        $d = New-Fixture $resp
        $kc = Join-Path $d 'kubeconfig.yaml'
        Set-FixtureErr $d $Q.topics "error: open ${kc}: permission denied (also $HOME\.kube\config)"
        $r = Invoke-Harness $d
        Assert-Run 'X06' $r $d
        Assert-Id 'X06-1 topic-1: FAIL quotes the masked kubeconfig path and home' $r 'topic-1' 'FAIL' @('KafkaTopic ns data: lookup failed:', 'open <KUBECONFIG>: permission denied', '(also ~\.kube\config)') @($kc, $HOME, 'unhandled')
        Assert 'X06-2: the raw fixture directory path and the home directory appear nowhere in the harness output' ($r.out.IndexOf($d, [StringComparison]::OrdinalIgnoreCase) -lt 0 -and $r.out.IndexOf($HOME, [StringComparison]::OrdinalIgnoreCase) -lt 0) (Format-Result $r)
    }
    Test-Case 'X07' 'topic-1: prod dlq with replicas 2 -> only topic-1 FAILs' { Test-Mutation 'X07' 'topic-1' @('KafkaTopics (cluster jt-kafka, 4 object(s)): 1 problem(s): identity-admin.dlq: spec.replicas=2 (expected 1)') { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked'), (New-Topic 'identity-admin.dlq' @{ replicas = 2 }), (New-Topic 'dev.identity-admin.dlq'))) } }
    Test-Case 'X08' 'user-1: dev-identity-admin with authentication tls -> only user-1 FAILs' { Test-Mutation 'X08' 'user-1' @("KafkaUsers (cluster jt-kafka, 2 object(s)): 1 problem(s): dev-identity-admin: spec.authentication.type='tls' (expected scram-sha-512)") { param($resp) $resp[$Q.users] = R-Json (New-List @((New-User 'identity-admin'), (New-User 'dev-identity-admin' @{ auth = 'tls' }))) } }
    Test-Case 'X09' 'pool-1: spec.replicas 2 -> only pool-1 FAILs' { Test-Mutation 'X09' 'pool-1' @('KafkaNodePool data/combined: 1 problem(s): spec.replicas=2 (expected 1)') { param($resp) $resp[$Q.pools] = R-Json (New-List @(New-Pool @{ replicas = 2 })) } }
    Test-Case 'X10' 'df-1: dragonfly-prod with a sidecar container -> only df-1 FAILs' { Test-Mutation 'X10' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: 2 containers (expected exactly 1: dragonfly, sidecar)') { param($resp) $resp[(DeployKey 'dragonfly-prod')] = R-Json (New-Deployment 'dragonfly-prod' @{ extraContainer = $true }) } }
    Test-Case 'X11' 'topic-1: two KafkaTopics declare the same topicName -> only topic-1 FAILs' { Test-Mutation 'X11' 'topic-1' @('KafkaTopics (cluster jt-kafka, 5 object(s)): 1 problem(s): identity-admin.session.revoked: declared by 2 KafkaTopics (identity-admin-session-revoked, identity-admin.session.revoked)') { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin-session-revoked' @{ topicName = 'identity-admin.session.revoked' }), (New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked'), (New-Topic 'identity-admin.dlq'), (New-Topic 'dev.identity-admin.dlq'))) } }
    Test-Case 'X12' 'cluster label: a KafkaNodePool and a KafkaTopic of another cluster in ns data are ignored -> all 17 PASS with the exact texts' {
        $resp = New-GoodResponses
        $resp[$Q.pools] = R-Json (New-List @((New-Pool), (New-Pool @{ name = 'other-pool'; cluster = 'other' })))
        $resp[$Q.topics] = R-Json (New-List @(@($topics4 | ForEach-Object { New-Topic $_ }) + @(New-Topic 'other-dlq' @{ topicName = 'identity-admin.dlq'; cluster = 'other' })))
        $d = New-Fixture $resp
        $r = Invoke-Harness $d
        Assert-Run 'X12' $r $d
        foreach ($id in $allIds) { Assert-IdExact "X12-1 ${id}: PASS with the exact text" $r $id 'PASS' $passText[$id] }
        $s = Get-Summary $r
        Assert 'X12-2: summary 17 passed, 0 failed and exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $r.code -eq 0) (Format-Result $r)
    }
    Test-Case 'X13' 'kafka-1: auto.create.topics.enable as the string "true" -> only kafka-1 FAILs' { Test-Mutation 'X13' 'kafka-1' @("Kafka data/jt-kafka: 1 problem(s): spec.kafka.config[auto.create.topics.enable]='true' (expected false; absent = broker default true)") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ autoCreate = 'true' }) } }
    Test-Case 'X14' 'topic-1: dev dlq Ready=False -> only topic-1 FAILs' { Test-Mutation 'X14' 'topic-1' @("KafkaTopics (cluster jt-kafka, 4 object(s)): 1 problem(s): dev.identity-admin.dlq: Ready condition status='False' (expected True) [Fixture: ready=false fixture]") { param($resp) $resp[$Q.topics] = R-Json (New-List @((New-Topic 'identity-admin.session.revoked'), (New-Topic 'dev.identity-admin.session.revoked'), (New-Topic 'identity-admin.dlq'), (New-Topic 'dev.identity-admin.dlq' @{ ready = 'False' }))) } }
    Test-Case 'X15' 'df-1: dragonfly-prod Available=False -> only df-1 FAILs' { Test-Mutation 'X15' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: not Available (readyReplicas=1) [MinimumReplicasAvailable]') { param($resp) $resp[(DeployKey 'dragonfly-prod')] = R-Json (New-Deployment 'dragonfly-prod' @{ available = 'False' }) } }
    Test-Case 'X16' 'gate-2: KUBECONFIG is a path list / unset -> gate-2 FAIL, every check FAILs as cluster unavailable, no kubectl call' {
        $d = New-Fixture (New-GoodResponses)
        $r = Invoke-Harness $d 180 ((Join-Path $d 'kubeconfig.yaml') + $sep + (Join-Path $d 'other.yaml'))
        Assert-IdExact 'X16-1 gate-2: path list refused' $r 'gate-2' 'FAIL' 'KUBECONFIG must be a single file path (path list not supported)'
        foreach ($id in $checkIds) { Assert-IdExact "X16-2 ${id}: FAIL cluster unavailable (path list)" $r $id 'FAIL' 'cluster unavailable (KUBECONFIG is a path list)' }
        Assert 'X16-3: no kubectl call at all and exit 1' ((@(Get-Calls $d)).Count -eq 0 -and $r.code -eq 1) (Format-Result $r)
        $d2 = New-Fixture (New-GoodResponses)
        $r2 = Invoke-Harness $d2 180 '<unset>'
        Assert-Id 'X16-4 gate-2: unset refused' $r2 'gate-2' 'FAIL' @('KUBECONFIG is not set')
        foreach ($id in $checkIds) { Assert-IdExact "X16-5 ${id}: FAIL cluster unavailable (not set)" $r2 $id 'FAIL' 'cluster unavailable (KUBECONFIG not set)' }
        Assert 'X16-6: no kubectl call at all and exit 1' ((@(Get-Calls $d2)).Count -eq 0 -and $r2.code -eq 1) (Format-Result $r2)
    }
    Test-Case 'X17' 'logs: kubectl logs succeeds but prints the "Defaulted container" notice on stderr (pod with an initContainer) -> job-d-2 still PASSes; a FAIL reason never carries the --requirepass value' {
        $resp = New-GoodResponses
        $resp[(LogsKey 'data-assert')] = @{ out = (DataLog); err = 'Defaulted container "pg-assert" out of: pg-assert, dragonfly-assert (init)'; code = 0 }
        $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ args = @($dfArgs + @('--requirepass=hunter2')) })
        $d = New-Fixture $resp
        $r = Invoke-Harness $d
        Assert-Run 'X17' $r $d
        Assert-IdExact 'X17-1 job-d-2: PASS despite the stderr notice' $r 'job-d-2' 'PASS' $passText['job-d-2']
        Assert-Id 'X17-2 df-1: FAIL names --requirepass without its value' $r 'df-1' 'FAIL' @('args carry --requirepass') @('hunter2')
        Assert 'X17-3: the password value appears nowhere in the harness output' ($r.out.IndexOf('hunter2', [StringComparison]::Ordinal) -lt 0 -and $r.err.IndexOf('hunter2', [StringComparison]::Ordinal) -lt 0) (Format-Result $r)
    }
    Test-Case 'X18' 'kafka-2: an extra plain listener (9092, tls=false, no authentication) next to tls -> only kafka-2 FAILs' { Test-Mutation 'X18' 'kafka-2' @('Kafka data/jt-kafka: 1 problem(s): listener plain: tls=false, authentication.type=<absent> (every declared listener must be TLS with authentication)') { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ extraListener = 'plain' }) } }
    Test-Case 'X19' 'kafka-2: superUsers lists dev-identity-admin and the CN form of identity-admin (another principal is fine) -> only kafka-2 FAILs naming the two' { Test-Mutation 'X19' 'kafka-2' @("Kafka data/jt-kafka: 1 problem(s): spec.kafka.authorization.superUsers grants unlimited access to 'User:CN=identity-admin,O=jt', 'User:dev-identity-admin' (the user-2 ACL check would be bypassed; T055 declares no superUsers)") { param($resp) $resp[$Q.kafka] = R-Json (New-Kafka @{ superUsers = @('User:CN=identity-admin,O=jt', 'User:dev-identity-admin', 'User:someone-else') }) } -hasNot @('someone-else') }

    # ================= 3라운드(재검토 반영 2026-10-08): 2라운드 규칙을 구속하는 사례(변이 R01–R12 킬 — K01–K12) + 재검토 패치 전용(K13 absl · K14 괄호 토큰 · K15 role 라벨 없음) =================
    Test-Case 'K01' 'job-k-3: latency 5001ms (one over the boundary) -> only job-k-3 FAILs' { Test-Mutation 'K01' 'job-k-3' @("roundtrip latency 5001ms > 5000ms (spec US3 AC3: produce->consume within 5 s; the Job's own 30 s wall-clock deadline is a separate check)") { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ ms = 5001 }) } }
    Test-Case 'K02' 'job-k-3: two latency tokens on the roundtrip line -> only job-k-3 FAILs as ambiguous (neither token is trusted)' { Test-Mutation 'K02' 'job-k-3' @('roundtrip evidence has 2 latency=<n>ms tokens (expected exactly 1; ambiguous, fail closed): ') { param($resp) $resp[(LogsKey 'kafka-assert')] = R-Raw ((KafkaLog @{ ms = 12 }).Replace('latency=12ms', 'latency=12ms latency=9000ms')) } }
    Test-Case 'K03' 'pool-2: pod Ready status "true" (lowercase) -> only pool-2 FAILs (ordinal)' { Test-Mutation 'K03' 'pool-2' @("Kafka node pods: 1 problem(s): jt-kafka-combined-0: pod condition Ready='true' (expected True; phase Running alone also matches CrashLoopBackOff)") { param($resp) $p = New-KafkaPod; $p.status.conditions = @((New-Cond 'Ready' 'true'), (New-Cond 'ContainersReady' 'True')); $resp[$Q.pods] = R-Json (New-List @($p, (New-EoPod))) } }
    Test-Case 'K04' 'pool-2: Ready=False while ContainersReady=True (readiness gate not met) -> only pool-2 FAILs' { Test-Mutation 'K04' 'pool-2' @("Kafka node pods: 1 problem(s): jt-kafka-combined-0: pod condition Ready='False' (expected True; phase Running alone also matches CrashLoopBackOff) [ReadinessGatesNotReady: corresponding condition of pod readiness gate `"x`" does not exist]") { param($resp) $p = New-KafkaPod; $p.status.conditions = @((New-Cond 'Ready' 'False' 'ReadinessGatesNotReady' 'corresponding condition of pod readiness gate "x" does not exist'), (New-Cond 'ContainersReady' 'True')); $resp[$Q.pods] = R-Json (New-List @($p, (New-EoPod))) } }
    Test-Case 'K05' 'df-1: availableReplicas 2 with spec.replicas 1 -> only df-1 FAILs (exactly 1, not >= 1)' { Test-Mutation 'K05' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: status.availableReplicas=2 (expected 1; Available=True is vacuous at 0 replicas)') { param($resp) $d = New-Deployment 'dragonfly-prod'; $d.status.availableReplicas = 2; $resp[(DeployKey 'dragonfly-prod')] = R-Json $d } }
    Test-Case 'K06' 'df-1: env DFLY_REQUIREPASS (uppercase; Dragonfly builds the env name as DFLY_ + flag name, case-sensitive) -> all 17 PASS' {
        $resp = New-GoodResponses
        $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ env = @([ordered]@{ name = 'DFLY_REQUIREPASS'; value = 'x' }) })
        $d = New-Fixture $resp; $r = Invoke-Harness $d; Assert-Run 'K06' $r $d
        Assert-IdExact 'K06-1 df-1: PASS (an uppercase name is not a Dragonfly password path)' $r 'df-1' 'PASS' $passText['df-1']
        $s = Get-Summary $r; Assert 'K06-2: summary 17 passed, 0 failed and exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $r.code -eq 0) (Format-Result $r)
    }
    Test-Case 'K07' 'job-d-2: the pattern only on the sample-pod EVIDENCE row (acl-list evidence without it) -> all 17 PASS through the EVIDENCE path' {
        $resp = New-GoodResponses
        $resp[(LogsKey 'data-assert')] = R-Raw ((DataLog @{ aclPattern = $false }).Replace('EVIDENCE:   user sample-pod on #<redacted> ~sample-pod:* +@all', 'EVIDENCE:   user sample-pod on #<redacted> %R~revoked:* ~sample-pod:* +@all'))
        $d = New-Fixture $resp; $r = Invoke-Harness $d; Assert-Run 'K07' $r $d
        Assert-IdExact 'K07-1 job-d-2: PASS (the sample-pod row carries the pattern)' $r 'job-d-2' 'PASS' $passText['job-d-2']
        $s = Get-Summary $r; Assert 'K07-2: summary 17 passed, 0 failed and exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $r.code -eq 0) (Format-Result $r)
    }
    Test-Case 'K08' 'job-d-2: the pattern only on a "user sample-pod-admin" row -> only job-d-2 FAILs (the row must be exactly user sample-pod)' { Test-Mutation 'K08' 'job-d-2' @("1 problem(s): pattern %R~revoked:* absent from the acl-list evidence and from the EVIDENCE: lines on the sample-pod row (6 EVIDENCE: line(s); other users' rows do not count) (VD-4)") { param($resp) $resp[(LogsKey 'data-assert')] = R-Raw ((DataLog @{ aclPattern = $false }).Replace('EVIDENCE:   user sample-pod on #<redacted> ~sample-pod:* +@all', "EVIDENCE:   user sample-pod on #<redacted> ~sample-pod:* +@all`nEVIDENCE:   user sample-pod-admin on #<redacted> %R~revoked:* +@all")) } }
    Test-Case 'K09' 'job-k-3: a roundtrip RESULT FAIL line that still carries latency=100ms -> job-k-2 and job-k-3 both FAIL (a FAIL line is never a latency source)' {
        $resp = New-GoodResponses
        $resp[(LogsKey 'kafka-assert')] = R-Raw ((KafkaLog @{ roundtrip = 'FAIL' }).Replace('> 상한 30s', '> 상한 30s latency=100ms'))
        $d = New-Fixture $resp; $r = Invoke-Harness $d; Assert-Run 'K09' $r $d
        Assert-Id 'K09-1 job-k-3: FAIL names the RESULT FAIL, never a latency verdict' $r 'job-k-3' 'FAIL' @('roundtrip: RESULT FAIL --', '(no PASS evidence to read the latency from)') @('<= 5000ms', 'unhandled')
        Assert-Id 'K09-2 job-k-2: FAIL (roundtrip FAIL)' $r 'job-k-2' 'FAIL' @('roundtrip: RESULT FAIL --') @('unhandled')
        $s = Get-Summary $r; Assert 'K09-3: summary 15 passed, 2 failed and exit 1' ($s.ok -and $s.pass -eq 15 -and $s.fail -eq 2 -and $r.code -eq 1) (Format-Result $r)
    }
    Test-Case 'K10' 'job-k-3: the roundtrip RESULT line printed twice -> job-k-2 and job-k-3 both FAIL (exactly one line is required by both)' {
        $resp = New-GoodResponses
        $resp[(LogsKey 'kafka-assert')] = R-Raw (KafkaLog @{ roundtrip = 'dup' })
        $d = New-Fixture $resp; $r = Invoke-Harness $d; Assert-Run 'K10' $r $d
        Assert-IdExact 'K10-1 job-k-3: FAIL -- 2 RESULT lines' $r 'job-k-3' 'FAIL' 'roundtrip: 2 RESULT line(s) (expected exactly 1) -- no latency to read'
        Assert-Id 'K10-2 job-k-2: FAIL -- 2 RESULT lines for roundtrip' $r 'job-k-2' 'FAIL' @('2 RESULT lines for roundtrip (expected exactly 1)') @('unhandled')
        $s = Get-Summary $r; Assert 'K10-3: summary 15 passed, 2 failed and exit 1' ($s.ok -and $s.pass -eq 15 -and $s.fail -eq 2 -and $r.code -eq 1) (Format-Result $r)
    }
    Test-Case 'K11' 'df-1: Available status "true" (lowercase) -> only df-1 FAILs (ordinal)' { Test-Mutation 'K11' 'df-1' @('1 problem(s): Deployment data/dragonfly-prod: not Available (readyReplicas=1) [MinimumReplicasAvailable]') { param($resp) $resp[(DeployKey 'dragonfly-prod')] = R-Json (New-Deployment 'dragonfly-prod' @{ available = 'true' }) } }
    Test-Case 'K12' 'kafka-2: a second listener whose tls is the string "true" -> only kafka-2 FAILs (tls must be the boolean true)' { Test-Mutation 'K12' 'kafka-2' @("Kafka data/jt-kafka: 1 problem(s): listener ext: tls='true', authentication.type='scram-sha-512' (every declared listener must be TLS with authentication)") { param($resp) $k = New-Kafka; $k.spec.kafka.listeners = @($k.spec.kafka.listeners) + @([ordered]@{ name = 'ext'; port = 9094; type = 'internal'; tls = 'true'; authentication = [ordered]@{ type = 'scram-sha-512' } }); $resp[$Q.kafka] = R-Json $k } }
    Test-Case 'K13' 'df-1: args carry --flagfile (absl flags import --requirepass from a file) -> only df-1 FAILs' { Test-Mutation 'K13' 'df-1' @('Deployment data/dragonfly-dev: args carry --flagfile (absl flags can import --requirepass from a file or from FLAGS_* environment variables; T057 declares none)') { param($resp) $resp[(DeployKey 'dragonfly-dev')] = R-Json (New-Deployment 'dragonfly-dev' @{ args = @($dfArgs + @('--flagfile=/etc/dragonfly/flags.conf')) }) } }
    Test-Case 'K14' 'job-k-3: the token written as (latency=120ms) -> still read, all 17 PASS' {
        $resp = New-GoodResponses
        $resp[(LogsKey 'kafka-assert')] = R-Raw ((KafkaLog @{ ms = 120 }).Replace(' latency=120ms', ' (latency=120ms)'))
        $d = New-Fixture $resp; $r = Invoke-Harness $d; Assert-Run 'K14' $r $d
        Assert-IdExact 'K14-1 job-k-3: PASS with the bracketed token' $r 'job-k-3' 'PASS' $passText['job-k-3']
        $s = Get-Summary $r; Assert 'K14-2: summary 17 passed, 0 failed and exit 0' ($s.ok -and $s.pass -eq 17 -and $s.fail -eq 0 -and $r.code -eq 0) (Format-Result $r)
    }
    Test-Case 'K15' 'pool-2: the Kafka node pod sits on a node without a role label -> only pool-2 FAILs and the reason says role=<absent>' { Test-Mutation 'K15' 'pool-2' @("Kafka node pods: 1 problem(s): jt-kafka-combined-0: node 'node-c' has role=<absent> (expected platform)") { param($resp) $n = New-Node 'node-c' 'x'; $n.metadata.labels.Remove('role'); $resp[$Q.nodes] = R-Json (New-List @((New-Node 'node-a' 'platform'), (New-Node 'node-b' 'data'), $n)); $resp[$Q.pods] = R-Json (New-List @((New-KafkaPod @{ node = 'node-c' }), (New-EoPod))) } }

    # ================= 정적(하네스 원문) =================
    Test-Case 'S01' 'harness source: the header names every assertion id, the T057 note for the five Dragonfly ids, and the fail-closed expectation' {
        $src = if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { [IO.File]::ReadAllText($harnessPath) } else { '' }
        $hdr = [Collections.Generic.List[string]]::new()
        foreach ($l in @($src -split "`r?`n")) { if ($l.StartsWith('#', [StringComparison]::Ordinal)) { $hdr.Add($l) } else { break } }
        $header = $hdr -join "`n"
        $missing = @(@($checkIds + @('T057', 'noauth', 'writer-set', 'reader-get', 'reader-set-denied', 'reader-cross-denied', 'FAIL', 'SKIP')) | Where-Object { -not (Has-Text $header $_) })
        Assert 'S01-1: the header comment names the 14 check ids, the five T057 ids and the FAIL/SKIP policy' ($src.Length -gt 0 -and $missing.Count -eq 0) "missing in header: $($missing -join ', ')"
        Assert 'S01-2: the harness source has no SKIP call path (no Skip function definition)' ($src.Length -gt 0 -and -not [regex]::IsMatch($src, '(?m)^function Skip\b')) 'found a Skip function'
    }

    # ================= 함수(순수 함수 표) =================
    $script:mod = $null
    $script:modError = ''
    try { $script:mod = Import-HarnessModule $harnessPath } catch { $script:modError = $_.Exception.Message }
    Test-Case 'F01' 'ConvertFrom-AssertLog: RESULT / SUMMARY / EVIDENCE parsed; NOTE and tool output ignored; CRLF and trailing spaces tolerated; id without evidence' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'ConvertFrom-AssertLog')
        Assert 'F01-0: the harness defines ConvertFrom-AssertLog' $ok "missing (module: $script:modError)"
        if ($ok) {
            $text = "NOTE: cleanup done`r`nRESULT: PASS roundtrip dev.x produce→consume 3s (상한 30s)  `r`nEVIDENCE: ACL LIST`r`nEVIDENCE:   user sample-pod on %R~revoked:*`r`nRESULT: FAIL cross-env-denied write succeeded`r`nRESULT: PASS bare`r`nRESULTS: PASS notaresult x`r`nSUMMARY: pass=2 fail=1`r`n"
            $p = & $script:mod { param($t) ConvertFrom-AssertLog $t } $text
            $ids = @(@($p.results) | ForEach-Object { "$($_.id)=$($_.status)" }) -join ','
            Assert 'F01-1: three RESULT lines in order with status (RESULTS: is not RESULT:)' (Test-Same $ids 'roundtrip=PASS,cross-env-denied=FAIL,bare=PASS') "got [$ids]"
            Assert 'F01-2: evidence text is the remainder after the id (trailing spaces trimmed); a bare id has empty evidence' ((Test-Same ([string]$p.results[0].evidence) 'dev.x produce→consume 3s (상한 30s)') -and (Test-Same ([string]$p.results[2].evidence) '')) "got [$($p.results[0].evidence)] / [$($p.results[2].evidence)]"
            Assert 'F01-3: one SUMMARY with pass=2 fail=1' (@($p.summaries).Count -eq 1 -and $p.summaries[0].pass -eq 2 -and $p.summaries[0].fail -eq 1) "got $(@($p.summaries).Count) summaries"
            Assert 'F01-4: two EVIDENCE: lines kept verbatim' (@($p.evidence).Count -eq 2 -and (Test-Same ([string]$p.evidence[1]) 'EVIDENCE:   user sample-pod on %R~revoked:*')) "got $(@($p.evidence).Count)"
            $e = & $script:mod { ConvertFrom-AssertLog '' }
            Assert 'F01-5: empty text -> no results, no summaries, no evidence' (@($e.results).Count -eq 0 -and @($e.summaries).Count -eq 0 -and @($e.evidence).Count -eq 0) "got $(@($e.results).Count)/$(@($e.summaries).Count)/$(@($e.evidence).Count)"
        }
    }
    Test-Case 'F02' 'Get-ElapsedSeconds: the produce→consume anchor wins, else the first <n>s word token; topic names with digits are not tokens; 10+ digits -> $null (no exception); none -> $null' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-ElapsedSeconds')
        Assert 'F02-0: the harness defines Get-ElapsedSeconds' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ in = 'dev.identity-admin.session.revoked produce→consume 3s (상한 30s, JVM 기동 포함)'; want = '3' },
                @{ in = 'dev.identity-admin.session.revoked produce→consume 23s (상한 30s, JVM 기동 포함) latency=120ms'; want = '23' },
                @{ in = 'topic2s produce→consume 12s (상한 30s)'; want = '12' },
                @{ in = 'dev.x (상한 30s) produce→consume 3s'; want = '3' },
                @{ in = 'produce→consume 0s'; want = '0' },
                @{ in = 'produce→consume 99999999999s'; want = '<null>' },
                @{ in = 'marker received, no timing'; want = '<null>' },
                @{ in = 'v4.3.1s is not a token: 7s'; want = '7' },
                @{ in = '(상한 30s) 5000ms'; want = '30' },
                @{ in = ''; want = '<null>' }
            )
            $bad = @()
            foreach ($row in $table) {
                $g = & $script:mod { param($s) Get-ElapsedSeconds $s } $row.in
                $got = if ($null -eq $g) { '<null>' } else { "$g" }
                if (-not (Test-Same $got $row.want)) { $bad += "[$($row.in)] -> $got (want $($row.want))" }
            }
            Assert 'F02-1: the elapsed-seconds table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F05' 'Get-LatencyMs / Get-LatencyTokens: exactly one latency=<n>ms token (brackets, quotes or a colon around it tolerated); two tokens, wrong unit, glued prefix/suffix, 10+ digits and absence -> $null' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-LatencyMs') -and (Test-ModuleHas $script:mod 'Get-LatencyTokens')
        Assert 'F05-0: the harness defines Get-LatencyMs and Get-LatencyTokens' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ in = 'dev.identity-admin.session.revoked produce→consume 23s (상한 30s, JVM 기동 포함) latency=120ms'; want = '120' },
                @{ in = 'latency=5001ms'; want = '5001' },
                @{ in = 'latency=0ms, marker 1 of 1'; want = '0' },
                @{ in = 'produce→consume 3s (상한 30s, JVM 기동 포함)'; want = '<null>' },
                @{ in = 'latency=7s'; want = '<null>' },
                @{ in = 'xlatency=120ms'; want = '<null>' },
                @{ in = 'latency=120msx'; want = '<null>' },
                @{ in = 'latency=99999999999ms'; want = '<null>' },
                @{ in = 'LATENCY=120ms'; want = '<null>' },
                @{ in = 'latency=12ms latency=9000ms'; want = '<null>' },
                @{ in = 'latency=9000ms latency=12ms'; want = '<null>' },
                @{ in = '(latency=120ms)'; want = '120' },
                @{ in = '[latency=120ms]'; want = '120' },
                @{ in = '"latency=120ms"'; want = '120' },
                @{ in = "'latency=120ms'"; want = '120' },
                @{ in = 'latency=120ms: ok'; want = '120' },
                @{ in = 'produce→consume 23s latency=120ms]'; want = '120' },
                @{ in = ''; want = '<null>' }
            )
            $bad = @()
            foreach ($row in $table) {
                $g = & $script:mod { param($s) Get-LatencyMs $s } $row.in
                $got = if ($null -eq $g) { '<null>' } else { "$g" }
                if (-not (Test-Same $got $row.want)) { $bad += "[$($row.in)] -> $got (want $($row.want))" }
            }
            Assert 'F05-1: the latency-token table' ($bad.Count -eq 0) ($bad -join '; ')
            $two = @(& $script:mod { param($s) Get-LatencyTokens $s } 'latency=12ms latency=9000ms')
            $none = @(& $script:mod { param($s) Get-LatencyTokens $s } 'produce→consume 23s (no token)')
            Assert 'F05-2: Get-LatencyTokens returns every token in order (two -> [12, 9000]; none -> empty)' ((Test-Same ($two -join ',') '12,9000') -and $none.Count -eq 0) "two=[$($two -join ',')] none=$($none.Count)"
        }
    }
    Test-Case 'F03' 'Test-AclWritesPrefix: literal / prefix / wildcard / deny / non-Write / group resource / All / old single operation / empty prefix name; cross judgment is fail-closed (only deny excludes)' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-AclWritesPrefix')
        Assert 'F03-0: the harness defines Test-AclWritesPrefix' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ name = 'prefix identity-admin. covers identity-admin.'; acl = (New-Acl 'identity-admin.' 'prefix' @('Write')); prefix = 'identity-admin.'; want = $true },
                @{ name = 'prefix identity-admin. does not cover dev.'; acl = (New-Acl 'identity-admin.' 'prefix' @('Write')); prefix = 'dev.'; want = $false },
                @{ name = 'prefix dev. covers dev.identity-admin. (shorter prefix)'; acl = (New-Acl 'dev.' 'prefix' @('Write')); prefix = 'dev.identity-admin.'; want = $true },
                @{ name = 'prefix dev.identity-admin.session covers dev.identity-admin. (longer prefix)'; acl = (New-Acl 'dev.identity-admin.session' 'prefix' @('Write')); prefix = 'dev.identity-admin.'; want = $true },
                @{ name = 'prefix empty name covers everything'; acl = (New-Acl '' 'prefix' @('Write')); prefix = 'identity-admin.'; want = $true },
                @{ name = 'literal (patternType omitted) exact topic under the prefix'; acl = (New-Acl 'identity-admin.session.revoked' '' @('Write')); prefix = 'identity-admin.'; want = $true },
                @{ name = 'literal topic of the other env'; acl = (New-Acl 'dev.identity-admin.session.revoked' 'literal' @('Write')); prefix = 'identity-admin.'; want = $false },
                @{ name = 'literal * (Kafka wildcard) covers everything'; acl = (New-Acl '*' 'literal' @('Write')); prefix = 'dev.'; want = $true },
                @{ name = 'deny rule never grants'; acl = (New-Acl 'identity-admin.' 'prefix' @('Write') 'topic' 'deny'); prefix = 'identity-admin.'; want = $false },
                @{ name = 'explicit allow grants'; acl = (New-Acl 'identity-admin.' 'prefix' @('Write') 'topic' 'allow'); prefix = 'identity-admin.'; want = $true },
                @{ name = 'Read/Describe only is not Write'; acl = (New-Acl 'identity-admin.' 'prefix' @('Read', 'Describe')); prefix = 'identity-admin.'; want = $false },
                @{ name = 'IdempotentWrite is not topic Write'; acl = (New-Acl 'identity-admin.' 'prefix' @('IdempotentWrite')); prefix = 'identity-admin.'; want = $false },
                @{ name = 'All counts as Write'; acl = (New-Acl 'identity-admin.' 'prefix' @('All')); prefix = 'identity-admin.'; want = $true },
                @{ name = 'group resource is not a topic'; acl = (New-Acl 'identity-admin-' 'prefix' @('Write') 'group'); prefix = 'identity-admin.'; want = $false },
                @{ name = 'old single operation Write'; acl = (New-Acl 'identity-admin.' 'prefix' @() 'topic' '' 'Write'); prefix = 'identity-admin.'; want = $true },
                @{ name = 'lowercase write is not Write (ordinal)'; acl = (New-Acl 'identity-admin.' 'prefix' @('write')); prefix = 'identity-admin.'; want = $false },
                @{ name = "type 'Allow' (not the enum value) does not grant for the own-prefix judgment"; acl = (New-Acl 'identity-admin.' 'prefix' @('Write') 'topic' 'Allow'); prefix = 'identity-admin.'; want = $false },
                @{ name = "cross: type 'Allow' counts as writable (fail closed)"; acl = (New-Acl 'dev.' 'prefix' @('Write') 'topic' 'Allow'); prefix = 'dev.'; cross = $true; want = $true },
                @{ name = 'cross: type absent counts as writable'; acl = (New-Acl 'dev.' 'prefix' @('Write')); prefix = 'dev.'; cross = $true; want = $true },
                @{ name = 'cross: deny is the only exclusion'; acl = (New-Acl 'dev.' 'prefix' @('Write') 'topic' 'deny'); prefix = 'dev.'; cross = $true; want = $false },
                @{ name = 'cross: Read only is still not Write'; acl = (New-Acl 'dev.' 'prefix' @('Read') 'topic' 'Allow'); prefix = 'dev.'; cross = $true; want = $false }
            )
            $bad = @()
            foreach ($row in $table) {
                $cross = [bool](Opt $row 'cross' $false)
                $g = & $script:mod { param($a, $p, $c) Test-AclWritesPrefix $a $p $c } (J $row.acl) $row.prefix $cross
                if ([bool]$g -ne [bool]$row.want) { $bad += "$($row.name): got $g (want $($row.want))" }
            }
            Assert 'F03-1: the ACL coverage table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F04' 'Get-FlagValues / Test-FlagValue / Test-FlagPresent: --flag=value, --flag value, -flag=value, duplicates, missing value, unrelated prefixes' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-FlagValue') -and (Test-ModuleHas $script:mod 'Test-FlagPresent')
        Assert 'F04-0: the harness defines Test-FlagValue and Test-FlagPresent' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ tokens = @('--maxmemory=768mb', '--aclfile', '/etc/dragonfly/users.acl'); flag = 'maxmemory'; value = '768mb'; wantValue = $true; wantPresent = $true },
                @{ tokens = @('--maxmemory', '768mb'); flag = 'maxmemory'; value = '768mb'; wantValue = $true; wantPresent = $true },
                @{ tokens = @('-maxmemory=768mb'); flag = 'maxmemory'; value = '768mb'; wantValue = $true; wantPresent = $true },
                @{ tokens = @('--maxmemory=768MB'); flag = 'maxmemory'; value = '768mb'; wantValue = $false; wantPresent = $true },
                @{ tokens = @('--maxmemory=768mb', '--maxmemory=1gb'); flag = 'maxmemory'; value = '768mb'; wantValue = $false; wantPresent = $true },
                @{ tokens = @('--maxmemory'); flag = 'maxmemory'; value = '768mb'; wantValue = $false; wantPresent = $true },
                @{ tokens = @('--maxmemory_policy=x', '--dir', '/data'); flag = 'maxmemory'; value = '768mb'; wantValue = $false; wantPresent = $false },
                @{ tokens = @('--requirepass=secret'); flag = 'requirepass'; value = ''; wantValue = $false; wantPresent = $true },
                @{ tokens = @('-requirepass', 'secret'); flag = 'requirepass'; value = 'secret'; wantValue = $true; wantPresent = $true },
                @{ tokens = @(); flag = 'requirepass'; value = ''; wantValue = $false; wantPresent = $false }
            )
            $bad = @()
            foreach ($row in $table) {
                $gv = & $script:mod { param($t, $f, $v) Test-FlagValue $t $f $v } $row.tokens $row.flag $row.value
                $gp = & $script:mod { param($t, $f) Test-FlagPresent $t $f } $row.tokens $row.flag
                if ([bool]$gv -ne [bool]$row.wantValue -or [bool]$gp -ne [bool]$row.wantPresent) { $bad += "[$($row.tokens -join ' ')] $($row.flag)=$($row.value): value=$gv present=$gp (want $($row.wantValue)/$($row.wantPresent))" }
            }
            Assert 'F04-1: the flag-token table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F06' 'Condition: one match -> that condition; none -> $null; duplicates of the type (either order) -> an ambiguous status with reason DuplicateCondition; other types ignored' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Condition')
        Assert 'F06-0: the harness defines Condition' $ok "missing (module: $script:modError)"
        if ($ok) {
            function Obj($conds) { return (J ([ordered]@{ status = [ordered]@{ conditions = @($conds) } })) }
            $table = @(
                @{ name = 'single Ready=True'; obj = (Obj @((New-Cond 'Ready' 'True'))); type = 'Ready'; want = 'True'; reason = '' },
                @{ name = 'no conditions'; obj = (J ([ordered]@{ status = [ordered]@{ observedGeneration = 1 } })); type = 'Ready'; want = '<null>'; reason = '' },
                @{ name = 'other types only'; obj = (Obj @((New-Cond 'Available' 'True'))); type = 'Ready'; want = '<null>'; reason = '' },
                @{ name = 'Ready among other types'; obj = (Obj @((New-Cond 'Progressing' 'True'), (New-Cond 'Ready' 'False' 'Fixture'), (New-Cond 'Available' 'True'))); type = 'Ready'; want = 'False'; reason = 'Fixture' },
                @{ name = 'duplicate [True, False]'; obj = (Obj @((New-Cond 'Ready' 'True'), (New-Cond 'Ready' 'False'))); type = 'Ready'; want = 'ambiguous: 2 Ready conditions [True, False]'; reason = 'DuplicateCondition' },
                @{ name = 'duplicate [False, True]'; obj = (Obj @((New-Cond 'Ready' 'False'), (New-Cond 'Ready' 'True'))); type = 'Ready'; want = 'ambiguous: 2 Ready conditions [False, True]'; reason = 'DuplicateCondition' },
                @{ name = 'triplicate Available'; obj = (Obj @((New-Cond 'Available' 'True'), (New-Cond 'Available' 'True'), (New-Cond 'Available' 'Unknown'))); type = 'Available'; want = 'ambiguous: 3 Available conditions [True, True, Unknown]'; reason = 'DuplicateCondition' },
                @{ name = 'type match is ordinal (ready != Ready)'; obj = (Obj @((New-Cond 'ready' 'True'))); type = 'Ready'; want = '<null>'; reason = '' }
            )
            $bad = @()
            foreach ($row in $table) {
                $c = & $script:mod { param($o, $t) Condition $o $t } $row.obj $row.type
                $got = if ($null -eq $c) { '<null>' } else { [string](& $script:mod { param($x) Prop $x 'status' } $c) }
                $reason = if ($null -eq $c) { '' } else { [string](& $script:mod { param($x) Prop $x 'reason' } $c) }
                if (-not (Test-Same $got $row.want) -or -not (Test-Same $reason $row.reason)) { $bad += "$($row.name): got [$got] reason [$reason] (want [$($row.want)] reason [$($row.reason)])" }
            }
            Assert 'F06-1: the condition table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F07' 'Test-ForbiddenSuperUser: User:<name> / bare / CN= / User:CN=<name>,... / * / User:* are forbidden; other principals, near-misses and empty are not' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-ForbiddenSuperUser')
        Assert 'F07-0: the harness defines Test-ForbiddenSuperUser' $ok "missing (module: $script:modError)"
        if ($ok) {
            $users = @('identity-admin', 'dev-identity-admin')
            $table = @(
                @{ in = 'User:identity-admin'; want = $true }, @{ in = 'User:dev-identity-admin'; want = $true }, @{ in = 'identity-admin'; want = $true },
                @{ in = 'CN=dev-identity-admin'; want = $true }, @{ in = 'User:CN=identity-admin'; want = $true }, @{ in = 'User:CN=identity-admin,O=jt,C=KR'; want = $true },
                @{ in = '*'; want = $true }, @{ in = 'User:*'; want = $true },
                @{ in = 'User:someone-else'; want = $false }, @{ in = 'User:identity-admin2'; want = $false }, @{ in = 'User:CN=identity-adminx'; want = $false },
                @{ in = 'User:CN=identity-admin;O=jt'; want = $false }, @{ in = 'User:Identity-Admin'; want = $false }, @{ in = 'User:'; want = $false }, @{ in = ''; want = $false },
                @{ in = 'User:dev-identity-admin.'; want = $false }
            )
            $bad = @()
            foreach ($row in $table) {
                $g = & $script:mod { param($p, $u) Test-ForbiddenSuperUser $p $u } $row.in $users
                if ([bool]$g -ne [bool]$row.want) { $bad += "[$($row.in)] -> $g (want $($row.want))" }
            }
            Assert 'F07-1: the superUser table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F08' 'Test-SummaryLine: exactly one SUMMARY whose pass/fail counts equal the RESULT lines; fail=0 only when required; missing / duplicate / mismatching -> problems' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-SummaryLine') -and (Test-ModuleHas $script:mod 'ConvertFrom-AssertLog')
        Assert 'F08-0: the harness defines Test-SummaryLine' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ name = 'consistent, fail=0 required'; log = "RESULT: PASS a x`nRESULT: PASS b y`nSUMMARY: pass=2 fail=0`n"; zero = $true; want = @() },
                @{ name = 'one FAIL, fail=0 required'; log = "RESULT: PASS a x`nRESULT: FAIL b y`nSUMMARY: pass=1 fail=1`n"; zero = $true; want = @('SUMMARY fail=1 (expected 0): SUMMARY: pass=1 fail=1') },
                @{ name = 'one FAIL, fail=0 not required (consistent)'; log = "RESULT: PASS a x`nRESULT: FAIL b y`nSUMMARY: pass=1 fail=1`n"; zero = $false; want = @() },
                @{ name = 'pass count too high (truncated log)'; log = "RESULT: PASS a x`nSUMMARY: pass=2 fail=0`n"; zero = $true; want = @('SUMMARY pass=2 fail=0 does not match the RESULT lines seen (1 PASS, 0 FAIL) -- log truncated by --tail=50 or inconsistent Job output') },
                @{ name = 'FAIL line hidden by fail=0'; log = "RESULT: FAIL a x`nSUMMARY: pass=1 fail=0`n"; zero = $false; want = @('SUMMARY pass=1 fail=0 does not match the RESULT lines seen (0 PASS, 1 FAIL) -- log truncated by --tail=50 or inconsistent Job output') },
                @{ name = 'fail=1 and mismatch -> both problems'; log = "RESULT: PASS a x`nRESULT: PASS b y`nSUMMARY: pass=2 fail=1`n"; zero = $true; want = @('SUMMARY fail=1 (expected 0): SUMMARY: pass=2 fail=1', 'SUMMARY pass=2 fail=1 does not match the RESULT lines seen (2 PASS, 0 FAIL) -- log truncated by --tail=50 or inconsistent Job output') },
                @{ name = 'no SUMMARY'; log = "RESULT: PASS a x`n"; zero = $true; want = @('0 SUMMARY line(s) in the last 50 log lines (expected exactly 1)') },
                @{ name = 'two SUMMARY lines'; log = "RESULT: PASS a x`nSUMMARY: pass=1 fail=0`nSUMMARY: pass=1 fail=0`n"; zero = $false; want = @('2 SUMMARY line(s) in the last 50 log lines (expected exactly 1)') },
                @{ name = 'empty log'; log = ''; zero = $true; want = @('0 SUMMARY line(s) in the last 50 log lines (expected exactly 1)') }
            )
            $bad = @()
            foreach ($row in $table) {
                $g = @(& $script:mod { param($t, $z) Test-SummaryLine (ConvertFrom-AssertLog $t) 50 $z } $row.log $row.zero)
                if (-not (Test-Same ($g -join ' || ') (@($row.want) -join ' || '))) { $bad += "$($row.name): got [$($g -join ' || ')] (want [$(@($row.want) -join ' || ')])" }
            }
            Assert 'F08-1: the SUMMARY table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }

    # 선택 실행에 모르는 케이스 이름이 있으면 실패(오타로 아무것도 안 돌고 통과하지 않게)
    foreach ($o in $script:only) {
        if (@($script:known | Where-Object { Test-Same $_ $o }).Count -eq 0) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in KAFKA_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
    }
} finally {
    Remove-Fixture
}

Write-Host "elapsed: $([Math]::Round($script:sw.Elapsed.TotalSeconds, 1)) s"
$suffix = ''
if ($script:only.Count -gt 0) { $suffix += " (filtered: $($script:only -join ','))" }
if ($scriptOverride) { $suffix += " (script override: $([IO.Path]::GetFileName($harnessPath)))" }
Write-Host "`n$($script:pass) passed, $($script:fail) failed$suffix"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
