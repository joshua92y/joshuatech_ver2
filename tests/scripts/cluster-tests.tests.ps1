# tests/platform/cluster.tests.ps1 하네스 단위 테스트(T049 — argo-4 범위 분리 · 배포 게이트 · 조회 오류 사유 · np-2 문구).
# Run: pwsh -NoProfile -File tests/scripts/cluster-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/reboot-tests.tests.ps1과 같은 구조).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all의 cluster-harness 체크가 이 파일을 직접 실행한다).
#
# 무엇을 지키나(요구 원문 .superpowers/t049/prompts/harness-fix.md · harness-fix-round2.md — 사용자 결정 2026-10-07 · 설계 D1–D5 · D7 · 리뷰 반영):
#   - argo-4(US2 범위: Vault PVC · cert-manager · ESO CRD)는 SKIP 경로가 없고, 항목 0개 · 어노테이션 다름 · 조회 오류는 FAIL이다.
#   - argo-4-cnpg-crd · argo-4-pg-main · argo-4-strimzi · argo-4-dragonfly는 T049 허용 미배포 목록의 게이트로만 SKIP한다:
#     목록에 있음 + Argo CD Application 존재 + status.resources 비어 있음 + 소유 과제 줄이 tasks.md에 정확히 1개이고 미체크.
#     그 밖의 모든 경우(Application 없음 · 조회 오류 · tasks.md 문제 · 소유 과제 체크됨 + 자원 0 · 배포됨 + 객체 문제)는 FAIL이다.
#   - Application 조회가 그 이름의 Application argocd/<name> 하나가 아닌 것({} · 문자열 · 정수 · List · Status · 다른 이름 · 다른 ns · 객체 둘)을
#     돌려주면 FAIL이다 — SKIP도 check도 아니다(2라운드 적대 리뷰 F1: C13 · C15 · F06). 이름 · ns가 맞아도 kind가 다르면(같은 이름의 ApplicationSet) FAIL.
#   - 게이트가 FAIL이어도 D3 검사는 이어서 돌아 사유가 한 줄에 함께 나온다(C04-5) · 허용 목록 항목 형식 검사(F02-5) · 항목 0개 가드(F05).
#   - 한 조회의 오류는 그 항목의 사유가 될 뿐, 같은 단언의 다른 항목 사유를 가리지 않는다(사유는 한 줄에 전부).
#   - PASS는 무엇을 몇 개 확인했는지 적고, SKIP은 소유 과제와 Application 이름을 적는다. np-2-* SKIP은 job별 소유 과제를 적는다.
#   - np-2-*는 Job이 없을 때 소유 과제(data-assert · kafka-assert = T059, authz-assert = T085 — Job이 존재·성공해야 하는 E2E 과제; 하네스 작성 과제
#     T050 · T051 · T078이 아니다, 2026-10-08 라이브 FAIL로 정정)가 tasks.md에서 미체크일 때만 SKIP(C02-5), 체크됐으면 FAIL(C14), tasks.md 문제도 FAIL
#     (C07–C09 · C14); Job이 있으면 tasks.md를 보지 않는다(C06-6) — 2라운드 적대 리뷰 F2(컨트롤러 범위 확장).
#
# 방식 1 — E2E 케이스(C*): 케이스마다 임시 픽스처(%TEMP%/clustertest-<guid>)에
#     하네스 사본  repo/tests/platform/cluster.tests.ps1  (CLUSTER_HARNESS_SCRIPT가 있으면 그 파일의 사본)
#     픽스처 tasks repo/specs/003-platform-foundation/tasks.md — 하네스의 기본 경로($PSScriptRoot/../../specs/…)가 픽스처 안을 가리킨다.
#                  실제 specs/003-platform-foundation/tasks.md는 어떤 케이스도 읽지 않는다(사본이 저장소 밖에서 돈다).
#     가짜 kubectl bin/kubectl.cmd 심 → bin/fake-kubectl.ps1 · 응답표 responses.tsv + resp/ · 더미 kubeconfig.yaml · tmp/
#   를 만들고 하네스 사본을 자식 pwsh로 실행한다(KUBECONFIG = 더미 파일, TMP/TEMP = 픽스처 tmp/, 실행마다 시간 상한 — 넘기면 트리째 종료).
#   자식 PATH = 픽스처 bin + 지금 PATH에서 kubectl.* · oci.* · curl.* 파일이 있는 디렉터리를 뺀 나머지 — 실제 kubectl · oci(svc-verify
#   세션) · curl에 닿지 않는다. 실행마다 자식 PATH에서 처음 찾히는 kubectl이 픽스처 심인지, oci · curl이 하나도 안 찾히는지 확인하고,
#   아니면 하네스를 실행하지 않는다(백업 단언 backup-1..3은 'oci CLI not found'로 FAIL한다 — 이 시험의 범위 밖).
# 가짜 kubectl: 심이 넘긴 원래 명령줄(FAKE_KUBECTL_ARGV)을 Windows 규칙으로 나누고(pwsh -File이 '--kubeconfig=C:\…'를 쪼개므로 $args를
#   쓰지 않는다), --kubeconfig=… · --request-timeout=…을 뗀 나머지를 공백 하나로 이은 문자열(key)을 응답표에서 ordinal로 찾는다.
#   없으면 exit 1 + 'fake-kubectl: no fixture response'(기록의 served = default — 케이스마다 0개를 단언한다). port-forward는 곧바로 exit 1
#   (vault-1/2는 이 시험의 범위 밖). 모든 호출은 calls.log(TSV 줄)에 남는다 — "읽기 전용 동사만" · "응답표 밖 호출 0" ·
#   "모든 호출이 --kubeconfig로 픽스처를 명시" · "게이트가 SKIP한 항목은 US3 객체를 조회하지 않음"을 단언하는 데 쓴다.
#   응답표 기본값(New-Responses) = 라이브에서 예상되는 US2 상태: US2 객체는 맞고, US3 Application 넷은 자원 0으로 있고,
#   US3 CRD는 설치 전이라 Cluster · Kafka · KafkaNodePool 조회는 "리소스 타입 없음"으로 실패한다. 케이스가 필요한 줄만 바꾼다.
# 방식 2 — 함수 케이스(F*): 하네스 파일을 AST로 읽어 최상위 함수 정의와 허용 목록 상수($argo4Allowlist)만 동적 모듈 안에 정의한다
#   (최상위 문장은 실행하지 않는다). 게이트 함수 Resolve-Argo4Gate에 허용 목록을 넘겨 시험하고(설계 D2 "허용 목록에 없는 ID"),
#   Get-TaskLineState의 과제 줄 판정을 표로 시험한다. 조회는 주입한다(호출 횟수를 센다).
#
# 환경 변수:
#   CLUSTER_HARNESS_SCRIPT      시험할 하네스(기본 tests/platform/cluster.tests.ps1) — 변이 시험에서 사본을 가리킨다. 설정되면 요약 줄 끝에
#                               ' (script override: <파일 이름>)'이 붙어 run-all의 'N passed, 0 failed' 판정을 통과하지 못한다.
#   CLUSTER_HARNESS_TESTS_ONLY  쉼표로 나눈 케이스 ID(예: C01,F02)만 실행한다. 요약 줄 끝에 ' (filtered: …)'가 붙는다(부분 실행이 전체 통과로
#                               보이지 않게). 모르는 ID가 있으면 FAIL.
# 실행 시간: E2E 케이스 하나에 가짜 kubectl 호출 약 40번(호출마다 cmd + pwsh 하나 — 부하 없을 때 0.4–0.5초) → 케이스당 약 20–30초,
#   전체 약 5–7분(같은 PC에서 다른 무거운 작업이 돌면 두세 배까지 늘어난다).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:CLUSTER_HARNESS_SCRIPT)
$harnessPath = if ($scriptOverride) { $env:CLUSTER_HARNESS_SCRIPT } else { Join-Path $repo 'tests/platform/cluster.tests.ps1' }
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$sync = 'Delete=false,Prune=false'
$tasksRel = 'repo/specs/003-platform-foundation/tasks.md'
$sep = [IO.Path]::PathSeparator
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
if (-not [string]::IsNullOrWhiteSpace($env:CLUSTER_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:CLUSTER_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}
# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Has-Text([string]$s, [string]$needle) { return ($null -ne $s -and $s.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }

# 케이스 격리 + 선택 실행. 한 케이스에서 예외가 나도 나머지는 계속 실행된다.
#   본문은 이 함수의 범위에서 dot-source로 돈다 — 본문의 foreach ($id …)가 매개변수 $id를 덮어도 되게 케이스 ID를 따로 둔다.
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

# ---------- 가짜 kubectl(픽스처 bin/fake-kubectl.ps1로 쓴다) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/cluster-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
# 입력: ..\responses.tsv(줄 = 번호 TAB 종료코드 TAB key) + ..\resp\<번호>.out · <번호>.err
# 기록: ..\calls.log(줄 = served TAB 종료코드 TAB kubeconfig TAB request-timeout TAB key)
# JSON cmdlet은 쓰지 않는다 — 호출마다 새 pwsh라 그 모듈 적재 시간(호출당 약 0.4초)이 그대로 실행 시간이 된다.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
try { [Console]::OutputEncoding = $utf8 } catch { }   # 콘솔이 없는 자식이면 설정할 수 없다 — 응답표는 ASCII뿐이라 무관
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

# kubectl.cmd 심: CRLF, BOM 없음(@echo off가 1행이어야 한다). 받은 명령줄(%*)을 FAKE_KUBECTL_ARGV로 넘기고(가짜 본문의 주석 — pwsh -File이
# 콜론이 든 인자를 쪼개므로 인자로 넘기지 않는다) 현재 pwsh로 가짜 스크립트를 실행해 종료 코드를 그대로 돌려준다.
$crlf = "`r`n"
$shimBody = (@(
        '@echo off'
        'set "FAKE_KUBECTL_ARGV=%*"'
        "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0fake-kubectl.ps1`""
        'exit /b %ERRORLEVEL%'
    ) -join $crlf) + $crlf

# ---------- 자식 PATH(실제 kubectl · oci · curl을 가린다) ----------
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
# 자식 PATH에서 처음 찾히는 명령(디렉터리 순 · 확장자 '' → PATHEXT → .ps1 — reboot-tests.tests.ps1 Find-FirstKubectl과 같은 규칙). 없으면 $null
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

# ---------- 응답표 조각 ----------
function Json($o) { return (ConvertTo-Json -InputObject $o -Depth 30 -Compress) }
function R-Json($o) { return @{ out = (Json $o); err = ''; code = 0 } }
function R-None { return @{ out = ''; err = ''; code = 0 } }   # --ignore-not-found + 객체 없음 = 빈 출력 · exit 0
function R-Raw([string]$out) { return @{ out = $out; err = ''; code = 0 } }
function R-Err([string]$err, [int]$code = 1) { return @{ out = ''; err = $err; code = $code } }
function R-NoType([string]$plural) { return R-Err "error: the server doesn't have a resource type `"$plural`"" }
function R-Forbidden([string]$what) { return R-Err "Error from server (Forbidden): $what is forbidden: User `"$expectedUser`" cannot get resource in the namespace" }
$connErr = 'Unable to connect to the server: dial tcp 10.0.0.10:6443: connectex: No connection could be made because the target machine actively refused it.'
function New-List([object[]]$items) { return [ordered]@{ apiVersion = 'v1'; kind = 'List'; items = @(@($items) | Where-Object { $null -ne $_ }) } }
function New-Meta([string]$ns, [string]$name, $syncOpt, $labels = $null) {
    $m = [ordered]@{ name = $name }
    if (-not [string]::IsNullOrEmpty($ns)) { $m['namespace'] = $ns }
    if ($null -ne $labels) { $m['labels'] = $labels }
    if ($null -ne $syncOpt) { $m['annotations'] = [ordered]@{ 'argocd.argoproj.io/sync-options' = [string]$syncOpt; 'argocd.argoproj.io/tracking-id' = "fixture:$name" } }
    return $m
}
function New-Pvc([string]$ns, [string]$name, $syncOpt, $labels = $null) {
    return [ordered]@{ apiVersion = 'v1'; kind = 'PersistentVolumeClaim'; metadata = (New-Meta $ns $name $syncOpt $labels); spec = [ordered]@{ accessModes = @('ReadWriteOnce'); storageClassName = 'local-path' } }
}
function New-Cr([string]$apiVersion, [string]$kind, [string]$ns, [string]$name, $syncOpt) {
    return [ordered]@{ apiVersion = $apiVersion; kind = $kind; metadata = (New-Meta $ns $name $syncOpt); spec = [ordered]@{} }
}
# CRD 정의 목록(@(복수형, 그룹)) → CRD 객체. $override: CRD 이름 → sync-options 값('<absent>' = 어노테이션 없음). 나머지는 정확한 값.
function New-Crds([object[]]$defs, [hashtable]$override = @{}) {
    return @(foreach ($d in $defs) {
            $name = "$($d[0]).$($d[1])"
            $v = $sync
            if ($override.ContainsKey($name)) { $v = if (Test-Same ([string]$override[$name]) '<absent>') { $null } else { [string]$override[$name] } }
            [ordered]@{ apiVersion = 'apiextensions.k8s.io/v1'; kind = 'CustomResourceDefinition'; metadata = (New-Meta '' $name $v); spec = [ordered]@{ group = $d[1]; names = [ordered]@{ plural = $d[0] }; scope = 'Namespaced' } }
        })
}
# cert-manager 6(cert-manager.io 4 + acme.cert-manager.io 2) · ESO 8(external-secrets.io 5 + generators.external-secrets.io 3)
$certManagerCrds = @(@('certificaterequests', 'cert-manager.io'), @('certificates', 'cert-manager.io'), @('clusterissuers', 'cert-manager.io'), @('issuers', 'cert-manager.io'),
    @('challenges', 'acme.cert-manager.io'), @('orders', 'acme.cert-manager.io'))
$esoCrds = @(@('clusterexternalsecrets', 'external-secrets.io'), @('clustersecretstores', 'external-secrets.io'), @('externalsecrets', 'external-secrets.io'),
    @('pushsecrets', 'external-secrets.io'), @('secretstores', 'external-secrets.io'),
    @('acraccesstokens', 'generators.external-secrets.io'), @('passwords', 'generators.external-secrets.io'), @('vaultdynamicsecrets', 'generators.external-secrets.io'))
# 대조군(어노테이션 없음 · 어느 그룹에도 들지 않아야 한다): 다른 그룹 · 점 없이 끝이 같은 그룹 · 그룹 뒤에 꼬리가 붙은 그룹
$otherCrds = @(@('applications', 'argoproj.io'), @('widgets', 'xcert-manager.io'), @('things', 'external-secrets.io.example'), @('helmchartconfigs', 'helm.cattle.io'))
$strimziCrds = @(@('kafkas', 'kafka.strimzi.io'), @('kafkanodepools', 'kafka.strimzi.io'), @('kafkatopics', 'kafka.strimzi.io'), @('kafkausers', 'kafka.strimzi.io'), @('strimzipodsets', 'core.strimzi.io'))
$cnpgCrds = @(@('clusters', 'postgresql.cnpg.io'), @('databases', 'postgresql.cnpg.io'), @('poolers', 'postgresql.cnpg.io'), @('objectstores', 'barmancloud.cnpg.io'))
function New-Us2CrdList([hashtable]$override = @{}, [object[]]$extraDefs = @()) {
    $all = @(New-Crds ($certManagerCrds + $esoCrds + @($extraDefs)) $override) + @(New-Crds $otherCrds @{ 'applications.argoproj.io' = '<absent>'; 'widgets.xcert-manager.io' = '<absent>'; 'things.external-secrets.io.example' = '<absent>'; 'helmchartconfigs.helm.cattle.io' = '<absent>' })
    return (New-List $all)
}
# Argo CD Application. $resources: 'absent'(status 없음) · 'null'(status.resources = null) · 정수 N(자원 N개; 0 = 빈 배열)
function New-App([string]$name, $resources) {
    $a = [ordered]@{ apiVersion = 'argoproj.io/v1alpha1'; kind = 'Application'; metadata = [ordered]@{ name = $name; namespace = 'argocd' } }
    if ($resources -is [string] -and (Test-Same $resources 'absent')) { return $a }
    $st = [ordered]@{ sync = [ordered]@{ status = 'Synced' }; health = [ordered]@{ status = 'Healthy' } }
    if ($resources -is [string] -and (Test-Same $resources 'null')) { $st['resources'] = $null }
    else { $st['resources'] = @(for ($i = 1; $i -le [int]$resources; $i++) { [ordered]@{ group = ''; version = 'v1'; kind = 'ConfigMap'; namespace = 'data'; name = "res-$i"; status = 'Synced' } }) }
    $a['status'] = $st
    return $a
}

# 조회 key 표. 이름이 $Q인 이유: PowerShell 변수 이름은 대소문자를 가리지 않아 $K로 두면 함수 안의 foreach ($k …)가 가린다.
$Q = @{
    vaultPvc = 'get persistentvolumeclaims -n vault -o json'
    dataPvc  = 'get persistentvolumeclaims -n data -o json'
    crds     = 'get customresourcedefinitions.apiextensions.k8s.io -o json'
    pgMain   = '-n data get clusters.postgresql.cnpg.io pg-main --ignore-not-found -o json'
    kafka    = '-n data get kafkas.kafka.strimzi.io jt-kafka --ignore-not-found -o json'
    pools    = 'get kafkanodepools.kafka.strimzi.io -n data -o json'
}
function AppKey([string]$name) { return "-n argocd get applications.argoproj.io $name --ignore-not-found -o json" }
$us3Apps = @('platform-cnpg', 'platform-cnpg-cluster', 'platform-kafka', 'platform-dragonfly')
$gatedIds = @('argo-4-cnpg-crd', 'argo-4-pg-main', 'argo-4-strimzi', 'argo-4-dragonfly')

# 기본 응답표 = 라이브에서 예상되는 US2 상태(머리 주석). 그 밖의 단언(노드 · ESO · NetworkPolicy …)은 빈 목록/없음을 받아 FAIL·SKIP하지만
# 응답이 성공이라 캐시되므로 같은 목록을 되풀이해 묻지 않는다(실행 시간).
function New-Responses {
    $r = [ordered]@{}
    $r['auth whoami -o json'] = R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = $expectedUser } } })
    foreach ($k in @('get nodes -o json', 'get applications.argoproj.io -n argocd -o json', 'get clustersecretstores.external-secrets.io -o json',
            'get externalsecrets.external-secrets.io -A -o json', 'get namespaces -o json', 'get networkpolicies.networking.k8s.io -A -o json',
            'get events -A -o json', 'get daemonsets.apps -n monitoring -o json', 'get statefulsets.apps -n monitoring -o json',
            'get deployments.apps -n monitoring -o json', 'get pods -n jt-dev --field-selector=status.phase=Running -o json',
            'get pods -n jt-prod --field-selector=status.phase=Running -o json')) { $r[$k] = R-Json (New-List @()) }
    foreach ($p in @('default', 'dev', 'prod')) { $r["-n argocd get appprojects.argoproj.io $p --ignore-not-found -o json"] = R-None }
    foreach ($ns in @('identity', 'jt-dev', 'jt-prod')) {
        $r["auth can-i get secrets -n $ns"] = @{ out = 'no'; err = ''; code = 1 }
        $r["-n $ns get externalsecrets.external-secrets.io pg-main-ca --ignore-not-found -o json"] = R-None
    }
    foreach ($j in @('data-assert', 'kafka-assert', 'authz-assert')) { $r["-n jt-dev get jobs.batch $j --ignore-not-found -o json"] = R-None }
    $r['-n reloader get deployments.apps reloader --ignore-not-found -o json'] = R-None
    $r[(AppKey 'platform-reloader')] = R-None
    # argo-4 계열
    $r[$Q.vaultPvc] = R-Json (New-List @(New-Pvc 'vault' 'data-vault-0' $sync))
    $r[$Q.crds] = R-Json (New-Us2CrdList)
    foreach ($a in $us3Apps) { $r[(AppKey $a)] = R-Json (New-App $a 0) }
    $r[$Q.pgMain] = R-NoType 'clusters'
    $r[$Q.kafka] = R-NoType 'kafkas'
    $r[$Q.pools] = R-NoType 'kafkanodepools'
    $r[$Q.dataPvc] = R-Json (New-List @())
    return $r
}

# np-2-* 소유 과제 줄(data-assert · kafka-assert = T059 · authz-assert = T085 — Job이 존재·성공해야 하는 E2E 과제; 하네스 작성 과제 T050 · T051 · T078이 아니다,
#   2026-10-08 정정) — 기본은 미체크(실제 tasks.md와 같다). T059 줄은 하나만 둔다(두 Job이 같은 줄을 읽고 Get-TaskLineState는 정확히 1줄을 요구한다).
#   케이스가 바꿀 때는 New-TasksText의 둘째 인자로 넘긴다.
$np2Unchecked = @('- [ ] T059 [US3] E2E: data-assert and kafka-assert Jobs must be present and succeeded', '- [ ] T085 [US4] E2E: authz-assert Job must be present and succeeded')
$np2Checked = @($np2Unchecked | ForEach-Object { '- [X] ' + $_.Substring(6) })
# tasks.md 픽스처: 머리 + 앞뒤 과제 줄(잡음) + np-2-* 소유 과제 줄 + 케이스의 argo-4-* 소유 과제 줄. LF.
function New-TasksText([string[]]$lines, [string[]]$np2Lines = $script:np2Unchecked) {
    $head = @('# Tasks: fixture (tests/scripts/cluster-tests.tests.ps1)', '', '## Phase 4: User Story 2', '- [X] T048 [US2] earlier task', '- [ ] T049 [US2] E2E: US2 AC1-AC5', '', '## Phase 5: User Story 3')
    return ((@($head) + @($np2Lines) + @($lines) + @('- [ ] T058 [US3] later task', '')) -join "`n")
}
$tUnchecked = @('- [ ] T052 [US3] `platform/cnpg/`: operator Application', '- [ ] T053 [US3] `platform/cnpg-cluster/`: Cluster pg-main',
    '- [ ] T055 [US3] `platform/kafka/`: Strimzi operator Application', '- [ ] T057 [P] [US3] VD-4 Dragonfly ACL (implements platform/dragonfly/)')
$tChecked = @($tUnchecked | ForEach-Object { '- [X] ' + $_.Substring(6) })

# 기대 문구(설계 D2 · D5 · D7)
$skipText = @{
    'argo-4-cnpg-crd'  = 'until T052 deploys the cnpg.io CRDs (T049 allowlist; Argo CD Application platform-cnpg has no resources; T052 unchecked in tasks.md)'
    'argo-4-pg-main'   = 'until T053 deploys Cluster data/pg-main (T049 allowlist; Argo CD Application platform-cnpg-cluster has no resources; T053 unchecked in tasks.md)'
    'argo-4-strimzi'   = 'until T055 deploys the strimzi.io CRDs and Kafka data/jt-kafka (T049 allowlist; Argo CD Application platform-kafka has no resources; T055 unchecked in tasks.md)'
    'argo-4-dragonfly' = 'until T057 deploys the Dragonfly PVC in ns data (T049 allowlist; Argo CD Application platform-dragonfly has no resources; T057 unchecked in tasks.md)'
}
$us2PassDetail = "15 objects carry argocd.argoproj.io/sync-options=${sync}: PVC vault/data-vault-0; CRD group cert-manager.io 6; CRD group external-secrets.io 8"
$np2Text = @{
    'data-assert'  = 'until T059 (assert Job jt-dev/data-assert from platform/policies/tests not present; deployed with the tests Application after T054-T057; T059 unchecked in tasks.md)'
    'kafka-assert' = 'until T059 (assert Job jt-dev/kafka-assert from platform/policies/tests not present; deployed with the tests Application after T055-T056; T059 unchecked in tasks.md)'
    'authz-assert' = 'until T085 (assert Job jt-dev/authz-assert from platform/policies/tests not present; deployed with the tests Application after T082; T085 unchecked in tasks.md)'
}

# ---------- 픽스처 ----------
function New-Fixture($responses, $tasksText, [hashtable]$extraFiles = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('clustertest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($sub in @('bin', 'tmp', 'resp', 'repo/tests/platform', 'repo/specs/003-platform-foundation')) { New-Item -ItemType Directory -Path (Join-Path $dir $sub) -Force | Out-Null }
    # 응답표: responses.tsv(번호 TAB 종료코드 TAB key) + resp/<번호>.out · .err(가짜 본문 주석)
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
    if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { Copy-Item -LiteralPath $harnessPath -Destination (Join-Path $dir 'repo/tests/platform/cluster.tests.ps1') }
    if ($null -ne $tasksText) { [IO.File]::WriteAllText((Join-Path $dir $tasksRel), [string]$tasksText, $utf8) }
    foreach ($rel in @($extraFiles.Keys)) { [IO.File]::WriteAllText((Join-Path $dir $rel), [string]$extraFiles[$rel], $utf8) }
    return $dir
}
# 이 실행이 만든 clustertest-* 디렉터리만, responses.tsv가 있는지 확인하고 지운다
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('clustertest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'responses.tsv') -PathType Leaf)) {
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

# 하네스 사본을 자식 pwsh로 실행한다. 환경은 자식에게만 준다(이 프로세스의 환경은 바꾸지 않는다).
#   $lockPath: 비어 있지 않으면 실행 동안 그 파일을 배타(FileShare.None)로 열어 둔다 — tasks.md 읽기 실패 재현.
function Invoke-Harness([string]$dir, [string[]]$harnessArgs = @(), [string]$lockPath = '', [int]$timeoutSec = 180) {
    $h = Join-Path $dir 'repo/tests/platform/cluster.tests.ps1'
    if (-not (Test-Path -LiteralPath $h -PathType Leaf)) { return @{ out = "<missing harness: $harnessPath>"; err = ''; code = 127; wall = 0.0; timedOut = $false } }
    $childPath = (Join-Path $dir 'bin') + $sep + $script:safePath
    # 실행마다 확인: 처음 찾히는 kubectl = 픽스처 심, oci · curl = 없음(실제 클러스터 · OCI 세션 · 네트워크에 닿지 않게)
    $first = Find-FirstCommand $childPath 'kubectl'
    if (-not [string]::Equals($first, (Join-Path (Join-Path $dir 'bin') 'kubectl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first kubectl on the child PATH is '$first', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    foreach ($n in @('oci', 'curl')) {
        $f = Find-FirstCommand $childPath $n
        if ($null -ne $f) { return @{ out = "<refusing to run: '$n' is reachable on the child PATH ($f)>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    }
    $psi = [Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    foreach ($x in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $h) + @($harnessArgs)) { $psi.ArgumentList.Add([string]$x) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.Environment['KUBECONFIG'] = Join-Path $dir 'kubeconfig.yaml'
    $psi.Environment['PATH'] = $childPath
    $psi.Environment['TMP'] = Join-Path $dir 'tmp'
    $psi.Environment['TEMP'] = Join-Path $dir 'tmp'
    foreach ($k in @('OCI_CLI_AUTH', 'OCI_CLI_PROFILE', 'OCI_CLI_CONFIG_FILE')) { [void]$psi.Environment.Remove($k) }
    $lock = $null
    if (-not [string]::IsNullOrEmpty($lockPath)) { $lock = [IO.FileStream]::new($lockPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None) }
    try {
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
    } finally { if ($null -ne $lock) { $lock.Dispose() } }
    return @{ out = ($out -replace "`r`n", "`n"); err = ($err -replace "`r`n", "`n"); code = $code; wall = $wall; timedOut = $timedOut }
}

# ---------- 결과 · 호출 기록 도우미 ----------
function Get-Lines($r) { return @(($r.out.TrimEnd("`n")) -split "`n") }
function Format-Result($r) {
    $lines = @(Get-Lines $r)
    $tail = if ($lines.Count -gt 12) { @('...') + $lines[($lines.Count - 12)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
}
# id의 결과 줄('PASS|FAIL|SKIP <id>: <detail>') → @{ n = 줄 수; status; detail; line }
function Get-IdResult($r, [string]$id) {
    $hits = @(@(Get-Lines $r) | Where-Object { $l = $_; @(@('PASS', 'FAIL', 'SKIP') | Where-Object { $l.StartsWith("$_ ${id}: ", [StringComparison]::Ordinal) }).Count -gt 0 })
    if ($hits.Count -ne 1) { return @{ n = $hits.Count; status = ''; detail = ''; line = ($hits -join ' || ') } }
    $l = [string]$hits[0]
    return @{ n = 1; status = $l.Substring(0, 4); detail = $l.Substring(("XXXX ${id}: ").Length); line = $l }
}
# 한 ID: 정확히 1줄 · 상태 · detail에 있어야 할 조각 · 없어야 할 조각(ordinal)
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
# calls.log 줄(served TAB code TAB kubeconfig TAB request-timeout TAB key) → @{ served; code; kubeconfig; requestTimeout; key }
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
# 읽기 전용 동사만: get · auth whoami · auth can-i · -n <ns> get|logs|port-forward
function Test-ReadOnlyKey([string]$key) {
    $t = @($key.Split(' '))
    if ($t.Count -ge 1 -and (Test-Same $t[0] 'get')) { return $true }
    if ($t.Count -ge 2 -and (Test-Same $t[0] 'auth') -and ((Test-Same $t[1] 'whoami') -or (Test-Same $t[1] 'can-i'))) { return $true }
    if ($t.Count -ge 3 -and (Test-Same $t[0] '-n') -and ((Test-Same $t[2] 'get') -or (Test-Same $t[2] 'logs') -or (Test-Same $t[2] 'port-forward'))) { return $true }
    return $false
}
# 모든 실행 공통: 끝까지 돌았다(마지막 줄 = 요약) · 읽기 전용 동사만 · 응답표 밖 호출 0 · 모든 호출이 픽스처 kubeconfig를 --kubeconfig로 명시
function Assert-Run([string]$id, $r, [string]$dir) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    Assert "${id}-end: harness ran to completion (no timeout; last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and [regex]::IsMatch($last, '\A\d+ passed, \d+ failed, \d+ skipped\z')) (Format-Result $r)
    $calls = @(Get-Calls $dir)
    $notRo = @($calls | Where-Object { -not (Test-ReadOnlyKey ([string]$_['key'])) })
    Assert "${id}-ro: every kubectl call used a read-only verb (get / auth whoami / auth can-i / logs / port-forward)" ($calls.Count -gt 0 -and $notRo.Count -eq 0) "calls=$($calls.Count) :: not read-only: $((@($notRo | ForEach-Object { $_['key'] })) -join ' || ')"
    $unserved = @($calls | Where-Object { Test-Same ([string]$_['served']) 'default' })
    Assert "${id}-served: every kubectl call matched a fixture response (no call outside the scenario)" ($unserved.Count -eq 0) "outside: $((@($unserved | ForEach-Object { $_['key'] })) -join ' || ')"
    $kc = Join-Path $dir 'kubeconfig.yaml'
    $badKc = @($calls | Where-Object { -not [string]::Equals([string]$_['kubeconfig'], $kc, [StringComparison]::OrdinalIgnoreCase) })
    Assert "${id}-kc: every kubectl call named the fixture kubeconfig explicitly (--kubeconfig)" ($badKc.Count -eq 0) "without it: $((@($badKc | ForEach-Object { $_['key'] })) -join ' || ')"
}
# SKIP한 항목은 US3 객체를 묻지 않는다: 그 키의 호출 수 = 0
function Assert-NotCalled([string]$name, [string]$dir, [string[]]$keys) {
    $calls = @(Get-Calls $dir)
    $hit = @($keys | Where-Object { (Count-Key $calls $_) -gt 0 })
    Assert $name ($hit.Count -eq 0) "called: $($hit -join ' || ') :: $(Format-Calls $calls)"
}

# ---------- 함수 케이스용: 하네스의 최상위 함수 + 허용 목록 상수만 동적 모듈에 정의한다(최상위 문장은 실행하지 않는다) ----------
function Import-HarnessModule([string]$path) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "harness does not parse: $(@($errors)[0].Message)" }
    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $consts = @($ast.EndBlock.Statements | Where-Object {
            $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            (Test-Same $_.Left.VariablePath.UserPath 'argo4Allowlist') })
    $text = ((@($consts | ForEach-Object { $_.Extent.Text }) + @($funcs | ForEach-Object { $_.Extent.Text })) -join "`n") + "`nExport-ModuleMember -Function @()`n"
    return (New-Module -Name ('clusterharness-' + [guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($text)))
}
# 모듈 안에 그 이름의 함수가 있는가(없으면 FAIL 사유)
function Test-ModuleHas($mod, [string]$fn) { return [bool](& $mod { param($n) $null -ne (Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue) } $fn) }

$fullAllowlist = [ordered]@{
    'argo-4-cnpg-crd'  = @{ app = 'platform-cnpg'; task = 'T052'; component = 'the cnpg.io CRDs' }
    'argo-4-pg-main'   = @{ app = 'platform-cnpg-cluster'; task = 'T053'; component = 'Cluster data/pg-main' }
    'argo-4-strimzi'   = @{ app = 'platform-kafka'; task = 'T055'; component = 'the strimzi.io CRDs and Kafka data/jt-kafka' }
    'argo-4-dragonfly' = @{ app = 'platform-dragonfly'; task = 'T057'; component = 'the Dragonfly PVC in ns data' }
}
# 게이트 함수 케이스용 Application 객체 — 정체 확인(kind · metadata.name · metadata.namespace)을 지나는 모양. $resources: 배열(빈 배열 = 자원 0) 또는 $null
function New-GateApp([string]$name, [string]$ns, $resources) {
    return [pscustomobject]@{ kind = 'Application'; metadata = [pscustomobject]@{ name = $name; namespace = $ns }; status = [pscustomobject]@{ resources = $resources } }
}

try {
    # ================= 재현(지금 코드에서 빨강이어야 한다) =================
    # (요구 원문 「재현 테스트」 예외 재현) CNPG 조회가 "리소스 타입 없음" + exit 1. 수정 전 하네스는 argo-4 FAIL 한 줄(unhandled …)만 내고
    #   Vault PVC · CRD 사유가 없었다(첫 조회의 예외가 단언 전체를 끝냈다). 여기서는 Vault PVC와 cert-manager CRD에도 일부러 문제를 넣는다.
    Test-Case 'C01' 'reproduction: the CNPG lookup fails with "resource type not found" -> the US2 items are still checked and every reason is reported' {
        $resp = New-Responses
        $resp[$Q.vaultPvc] = R-Json (New-List @(New-Pvc 'vault' 'data-vault-0' $null))
        $resp[$Q.crds] = R-Json (New-Us2CrdList @{ 'certificates.cert-manager.io' = 'Prune=false' })
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json (New-App 'platform-cnpg-cluster' 2)   # 배포됨 → D3 검사가 pg-main을 조회한다
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C01' $r $d
        Assert-Id 'C01-1: argo-4 (US2) FAIL lists the Vault PVC reason and the cert-manager CRD reason -- not one "unhandled" line' $r 'argo-4' 'FAIL' @('2 problem(s)', 'PVC ns vault: 1 of 1 object(s)', 'vault/data-vault-0=<absent>', 'CRD group cert-manager.io: 1 of 6 object(s)', "certificates.cert-manager.io='Prune=false'") @('unhandled', 'resource type')
        Assert-Id 'C01-2: argo-4-pg-main FAIL carries the "resource type" error as its own reason (platform-cnpg-cluster has resources = deployed)' $r 'argo-4-pg-main' 'FAIL' @('Cluster data/pg-main: lookup failed', 'the server doesn''t have a resource type "clusters"') @('unhandled')
        foreach ($id in @('argo-4-cnpg-crd', 'argo-4-strimzi', 'argo-4-dragonfly')) { Assert-IdExact "C01-3 ${id}: SKIP with the allowlist text (Application has no resources, owner task unchecked)" $r $id 'SKIP' $skipText[$id] }
    }

    # ================= 라이브 예상 상태 · 매개변수 덮어쓰기 · np-2 문구 =================
    Test-Case 'C02' 'live-like state -> argo-4 PASS names its scope, the four argo-4-* SKIP without looking up US3 objects; -TasksMdPath overrides the default tasks.md; np-2-* SKIP names the owner task' {
        $resp = New-Responses
        $resp[(AppKey 'platform-cnpg')] = R-Json (New-App 'platform-cnpg' 'absent')            # status 없음
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json (New-App 'platform-cnpg-cluster' 'null')   # status.resources = null
        # platform-kafka · platform-dragonfly = 빈 배열(기본값)
        # 기본 위치의 tasks.md는 전부 체크됨(argo-4-* 소유 과제 넷 + np-2-* 소유 과제 둘 T059 · T085) — -TasksMdPath(전부 미체크)를 따르지 않으면 argo-4-* 넷 + np-2-* 셋 일곱 항목 다 FAIL이 된다
        $d = New-Fixture $resp (New-TasksText $tChecked $np2Checked) @{ 'alt-tasks.md' = (New-TasksText $tUnchecked) }
        $r = Invoke-Harness $d @('-TasksMdPath', (Join-Path $d 'alt-tasks.md'))
        Assert-Run 'C02' $r $d
        Assert-IdExact 'C02-1: argo-4 PASS names what it counted (objects, PVC names, CRD count per group)' $r 'argo-4' 'PASS' $us2PassDetail
        foreach ($id in $gatedIds) { Assert-IdExact "C02-2 ${id}: SKIP with the allowlist text (owner task + Application name), read from -TasksMdPath" $r $id 'SKIP' $skipText[$id] }
        Assert-NotCalled 'C02-3: a SKIP decided by the gate looked up no US3 object (no Cluster / Kafka / KafkaNodePool / ns data PVC call)' $d @($Q.pgMain, $Q.kafka, $Q.pools, $Q.dataPvc)
        $calls = @(Get-Calls $d)
        Assert 'C02-4: the CRD list was fetched once and each of the four US3 Applications was looked up once' ((Count-Key $calls $Q.crds) -eq 1 -and @($us3Apps | Where-Object { (Count-Key $calls (AppKey $_)) -ne 1 }).Count -eq 0) (Format-Calls $calls)
        foreach ($j in @('data-assert', 'kafka-assert', 'authz-assert')) { Assert-IdExact "C02-5 np-2-${j}: SKIP names its owner task and its unchecked state, read from -TasksMdPath (the default tasks.md has it checked)" $r "np-2-$j" 'SKIP' $np2Text[$j] }
        Assert 'C02-6: no output line says "until T041" any more' (@(@(Get-Lines $r) | Where-Object { Has-Text $_ 'until T041' }).Count -eq 0) (Format-Result $r)
    }

    # ================= 게이트(D2) =================
    # 미체크 → 그 ID만 SKIP · 체크됨(- [X]) + 자원 0 → FAIL · 과제 줄 0개(비슷한 줄은 세지 않는다) · 2개 → FAIL. 기본 tasks.md 경로(매개변수 없음).
    Test-Case 'C03' 'gate: unchecked -> only that id SKIPs; checked [X] with 0 resources -> FAIL; 0 or 2 owner task lines -> FAIL; argo-4 unaffected' {
        $resp = New-Responses
        $resp[(AppKey 'platform-cnpg')] = R-Json (New-App 'platform-cnpg' 'absent')
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json (New-App 'platform-cnpg-cluster' 'null')
        $lines = @(
            '- [ ] T052 [US3] `platform/cnpg/`: operator Application',
            '- [X] T053 [US3] `platform/cnpg-cluster/`: Cluster pg-main',
            '  - [ ] T055 indented sub-item (not at the start of the line)',
            '- [ ] T0550 another task id',
            '- [ ]  T055 two spaces (not the task-line shape)',
            '* [ ] T055 star bullet (not the task-line shape)',
            '- [ ] T055',
            '- [ ] t055 lowercase id',
            '- [ ] T057 [P] [US3] first copy',
            '- [ ] T057 [P] [US3] second copy'
        )
        $d = New-Fixture $resp (New-TasksText $lines)
        $r = Invoke-Harness $d
        Assert-Run 'C03' $r $d
        Assert-IdExact 'C03-1: argo-4-cnpg-crd SKIP (T052 unchecked, platform-cnpg has no status at all)' $r 'argo-4-cnpg-crd' 'SKIP' $skipText['argo-4-cnpg-crd']
        Assert-Id 'C03-2: argo-4-pg-main FAIL -- "- [X] T053" with an empty Application is the post-US3 empty state' $r 'argo-4-pg-main' 'FAIL' @('T053 is checked in tasks.md but Argo CD Application platform-cnpg-cluster has no resources')
        Assert-Id 'C03-3: argo-4-strimzi FAIL -- no line has the exact owner-task shape for T055 (near misses are not counted)' $r 'argo-4-strimzi' 'FAIL' @('tasks.md has 0 task line(s) for T055')
        Assert-Id 'C03-4: argo-4-dragonfly FAIL -- two owner-task lines for T057' $r 'argo-4-dragonfly' 'FAIL' @('tasks.md has 2 task line(s) for T057')
        Assert-IdExact 'C03-5: argo-4 (US2) still PASS in the same run (other ids are unaffected)' $r 'argo-4' 'PASS' $us2PassDetail
    }
    # 소문자 [x]도 체크됨 · Application 조회 forbidden → FAIL · Application 없음 → FAIL · 미체크 SKIP은 객체를 묻지 않는다
    Test-Case 'C04' 'gate: checked [x] -> FAIL; Application lookup forbidden -> FAIL (not SKIP); Application missing -> FAIL; unchecked -> SKIP without the object lookup' {
        $resp = New-Responses
        $resp[(AppKey 'platform-kafka')] = R-Forbidden 'applications.argoproj.io "platform-kafka"'
        $resp[(AppKey 'platform-dragonfly')] = R-None
        $lines = @('- [x] T052 [US3] lowercase check mark', '- [ ] T053 [US3] cnpg-cluster', '- [ ] T055 [US3] kafka', '- [ ] T057 [P] [US3] dragonfly')
        $d = New-Fixture $resp (New-TasksText $lines)
        $r = Invoke-Harness $d
        Assert-Run 'C04' $r $d
        Assert-Id 'C04-1: argo-4-cnpg-crd FAIL -- "[x]" counts as checked' $r 'argo-4-cnpg-crd' 'FAIL' @('T052 is checked in tasks.md but Argo CD Application platform-cnpg has no resources')
        Assert-IdExact 'C04-2: argo-4-pg-main SKIP (control in the same run)' $r 'argo-4-pg-main' 'SKIP' $skipText['argo-4-pg-main']
        Assert-NotCalled 'C04-3: the SKIP of argo-4-pg-main did not look up Cluster pg-main' $d @($Q.pgMain)
        Assert-Id 'C04-4: argo-4-strimzi FAIL -- the Application lookup was forbidden (an error is never a SKIP)' $r 'argo-4-strimzi' 'FAIL' @('Argo CD Application platform-kafka lookup failed', 'Forbidden')
        Assert-Id 'C04-5: argo-4-dragonfly FAIL -- Argo CD Application platform-dragonfly does not exist, and the D3 check still ran (its empty-PVC reason is on the same line, D4)' $r 'argo-4-dragonfly' 'FAIL' @('2 problem(s)', 'Argo CD Application platform-dragonfly (ns argocd) not found', 'Dragonfly PVC ns data: no Dragonfly PVC in ns data')
    }
    # 연결 실패 · 깨진 JSON → FAIL · 배포됨 + 객체 없음 / 어노테이션 다름 → FAIL(사유를 전부 한 줄에)
    Test-Case 'C05' 'gate: connection failure / broken JSON -> FAIL; deployed + missing objects / wrong annotation -> FAIL with every reason on one line' {
        $resp = New-Responses
        $resp[(AppKey 'platform-cnpg')] = R-Err $connErr
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Raw '{"apiVersion":"argoproj.io/v1alpha1","kind":"Application","metadata":{"name":'
        $resp[(AppKey 'platform-kafka')] = R-Json (New-App 'platform-kafka' 3)
        $resp[(AppKey 'platform-dragonfly')] = R-Json (New-App 'platform-dragonfly' 1)
        $resp[$Q.crds] = R-Json (New-Us2CrdList @{ 'kafkas.kafka.strimzi.io' = 'Delete=false' } $strimziCrds)
        $resp[$Q.kafka] = R-None
        $resp[$Q.pools] = R-Json (New-List @())
        $resp[$Q.dataPvc] = R-Json (New-List @((New-Pvc 'data' 'dragonfly-data-0' 'Prune=false'), (New-Pvc 'data' 'other-data' $null)))
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C05' $r $d
        Assert-Id 'C05-1: argo-4-cnpg-crd FAIL -- the Application lookup could not reach the server' $r 'argo-4-cnpg-crd' 'FAIL' @('Argo CD Application platform-cnpg lookup failed', 'Unable to connect to the server') @('until T052')
        Assert-Id 'C05-2: argo-4-pg-main FAIL -- the Application JSON is broken' $r 'argo-4-pg-main' 'FAIL' @('Argo CD Application platform-cnpg-cluster lookup failed', 'JSON parse failed') @('until T053')
        Assert-Id 'C05-3: argo-4-strimzi (deployed) FAIL with all three reasons: CRD annotation, Kafka missing, no KafkaNodePool' $r 'argo-4-strimzi' 'FAIL' @('3 problem(s)', "CRD group strimzi.io: 1 of 5 object(s) without sync-options exactly '$sync': kafkas.kafka.strimzi.io='Delete=false'", 'Kafka data/jt-kafka: not found', 'KafkaNodePool ns data: no KafkaNodePool in ns data')
        Assert-Id 'C05-4: argo-4-dragonfly (deployed) FAIL -- the Dragonfly PVC annotation differs (other PVCs in ns data are not looked at)' $r 'argo-4-dragonfly' 'FAIL' @("data/dragonfly-data-0='Prune=false'") @('other-data')
    }
    # 배포됨 + 리소스 타입 없음 → FAIL(조회 오류 둘이 서로를 가리지 않는다) · 배포됨 + 맞음 → PASS(범위 + Application 자원 수) · tasks.md가 없어도
    # 자원이 있는 Application은 과제 상태를 보지 않는다
    Test-Case 'C06' 'deployed: resource type missing -> FAIL (both lookup errors reported); right objects -> PASS with scope; tasks.md absent does not matter when the Application has resources' {
        $resp = New-Responses
        $resp[(AppKey 'platform-cnpg')] = R-Json (New-App 'platform-cnpg' 4)
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json (New-App 'platform-cnpg-cluster' 2)
        $resp[(AppKey 'platform-kafka')] = R-Json (New-App 'platform-kafka' 3)
        $resp[(AppKey 'platform-dragonfly')] = R-Json (New-App 'platform-dragonfly' 3)
        $resp[$Q.crds] = R-Json (New-Us2CrdList @{} $strimziCrds)
        $resp[$Q.pgMain] = R-Json (New-Cr 'postgresql.cnpg.io/v1' 'Cluster' 'data' 'pg-main' $sync)
        # kafka · pools = 리소스 타입 없음(기본값)
        $resp[$Q.dataPvc] = R-Json (New-List @((New-Pvc 'data' 'df-0' $sync @{ 'app.kubernetes.io/name' = 'dragonfly' }), (New-Pvc 'data' 'pg-main-1' $null)))
        # assert Job data-assert가 있으면(성공 + 로그) np-2-data-assert는 tasks.md 없이도 PASS — np-2 게이트는 Job이 없을 때만 tasks.md를 본다
        $resp['-n jt-dev get jobs.batch data-assert --ignore-not-found -o json'] = R-Json ([ordered]@{ apiVersion = 'batch/v1'; kind = 'Job'; metadata = [ordered]@{ name = 'data-assert'; namespace = 'jt-dev' }; status = [ordered]@{ succeeded = 1 } })
        $resp['-n jt-dev logs job/data-assert --tail=50'] = R-Raw "pg-main 5432 ok`ndragonfly 6379 ok`n"
        $d = New-Fixture $resp $null
        $r = Invoke-Harness $d
        Assert-Run 'C06' $r $d
        Assert-Id 'C06-1: argo-4-cnpg-crd (deployed) FAIL -- no CRD in group cnpg.io; tasks.md was not needed' $r 'argo-4-cnpg-crd' 'FAIL' @('CRD group cnpg.io: no CRD with spec.group cnpg.io or *.cnpg.io') @('tasks.md')
        Assert-IdExact 'C06-2: argo-4-pg-main (deployed, right annotation) PASS names the object and the Application resource count' $r 'argo-4-pg-main' 'PASS' "1 object carries argocd.argoproj.io/sync-options=${sync}: Cluster data/pg-main (Argo CD Application platform-cnpg-cluster has 2 resource(s))"
        Assert-Id 'C06-3: argo-4-strimzi (deployed) FAIL with both "resource type" errors on one line; the right CRD group is not a problem' $r 'argo-4-strimzi' 'FAIL' @('2 problem(s)', 'Kafka data/jt-kafka: lookup failed', 'resource type "kafkas"', 'KafkaNodePool ns data: lookup failed', 'resource type "kafkanodepools"') @('CRD group strimzi.io:', 'tasks.md')
        Assert-IdExact 'C06-4: argo-4-dragonfly (deployed) PASS -- the PVC labelled app.kubernetes.io/name=dragonfly counts, other PVCs in ns data do not' $r 'argo-4-dragonfly' 'PASS' "1 object carries argocd.argoproj.io/sync-options=${sync}: Dragonfly PVC data/df-0 (Argo CD Application platform-dragonfly has 3 resource(s))"
        Assert-IdExact 'C06-5: argo-4 (US2) PASS (strimzi CRDs are not part of its scope)' $r 'argo-4' 'PASS' $us2PassDetail
        Assert-Id 'C06-6: np-2-data-assert PASS -- the Job is present (succeeded, logs readable), so the absent tasks.md is never consulted' $r 'np-2-data-assert' 'PASS' @('Job jt-dev/data-assert succeeded') @('tasks.md', 'until T059')
    }
    # tasks.md 없음 · 읽기 실패(배타 잠금) · 파일이 아니라 디렉터리 → 자원 0인 넷 다 FAIL(fail closed), argo-4는 영향 없음
    Test-Case 'C07' 'gate: tasks.md missing -> FAIL for every empty Application (fail closed); argo-4 unaffected' {
        $d = New-Fixture (New-Responses) $null
        $r = Invoke-Harness $d
        Assert-Run 'C07' $r $d
        foreach ($id in $gatedIds) { Assert-Id "C07-1 ${id}: FAIL (not SKIP) -- tasks.md is missing" $r $id 'FAIL' @('tasks.md is not a readable file') @('until T0') }
        foreach ($j in @('data-assert', 'kafka-assert', 'authz-assert')) { Assert-Id "C07-3 np-2-${j}: FAIL (not SKIP) -- the Job is absent and tasks.md is missing (np-2 gate, same rule)" $r "np-2-$j" 'FAIL' @("assert Job jt-dev/$j not present and the state of", 'tasks.md is not a readable file') @('until T0') }
        Assert-IdExact 'C07-2: argo-4 (US2) PASS -- it never reads tasks.md' $r 'argo-4' 'PASS' $us2PassDetail
    }
    Test-Case 'C08' 'gate: tasks.md exists but cannot be read (held open exclusively) -> FAIL (fail closed)' {
        $d = New-Fixture (New-Responses) (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d @() (Join-Path $d $tasksRel)
        Assert-Run 'C08' $r $d
        foreach ($id in $gatedIds) { Assert-Id "C08-1 ${id}: FAIL (not SKIP) -- tasks.md unreadable" $r $id 'FAIL' @('tasks.md unreadable') @('until T0') }
        foreach ($j in @('data-assert', 'kafka-assert', 'authz-assert')) { Assert-Id "C08-2 np-2-${j}: FAIL (not SKIP) -- tasks.md unreadable" $r "np-2-$j" 'FAIL' @("assert Job jt-dev/$j not present", 'tasks.md unreadable') @('until T0') }
    }
    Test-Case 'C09' 'gate: the tasks.md path is a directory -> FAIL (fail closed)' {
        $d = New-Fixture (New-Responses) $null
        New-Item -ItemType Directory -Path (Join-Path $d $tasksRel) | Out-Null
        $r = Invoke-Harness $d
        Assert-Run 'C09' $r $d
        foreach ($id in $gatedIds) { Assert-Id "C09-1 ${id}: FAIL (not SKIP) -- tasks.md is not a file" $r $id 'FAIL' @('tasks.md is not a readable file') @('until T0') }
        foreach ($j in @('data-assert', 'kafka-assert', 'authz-assert')) { Assert-Id "C09-2 np-2-${j}: FAIL (not SKIP) -- tasks.md is not a file" $r "np-2-$j" 'FAIL' @("assert Job jt-dev/$j not present", 'tasks.md is not a readable file') @('until T0') }
    }

    # ================= US2 범위 argo-4 =================
    Test-Case 'C10' 'argo-4: no Vault PVC and no cert-manager CRD -> FAIL with both reasons (0 items is not evidence); look-alike groups are not counted' {
        $resp = New-Responses
        $resp[$Q.vaultPvc] = R-Json (New-List @())
        $resp[$Q.crds] = R-Json (New-List (@(New-Crds $esoCrds) + @(New-Crds $otherCrds @{ 'applications.argoproj.io' = '<absent>'; 'widgets.xcert-manager.io' = '<absent>'; 'things.external-secrets.io.example' = '<absent>'; 'helmchartconfigs.helm.cattle.io' = '<absent>' })))
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C10' $r $d
        Assert-Id 'C10-1: argo-4 FAIL: "no PVC in ns vault" and "no CRD in group cert-manager.io" on one line; the ESO group is fine; xcert-manager.io is not cert-manager' $r 'argo-4' 'FAIL' @('2 problem(s)', 'PVC ns vault: no PVC in ns vault', 'CRD group cert-manager.io: no CRD with spec.group cert-manager.io or *.cert-manager.io') @('CRD group external-secrets.io:', 'xcert-manager', 'external-secrets.io.example')
    }
    Test-Case 'C11' 'argo-4: the CRD list lookup fails -> both CRD groups report it and the Vault PVC mismatch is still reported; the argo-4-* gates are unaffected' {
        $resp = New-Responses
        $resp[$Q.crds] = R-Forbidden 'customresourcedefinitions.apiextensions.k8s.io'
        $resp[$Q.vaultPvc] = R-Json (New-List @((New-Pvc 'vault' 'data-vault-0' 'Prune=false,Delete=false'), (New-Pvc 'vault' 'audit-vault-0' $sync)))
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C11' $r $d
        Assert-Id 'C11-1: argo-4 FAIL with 3 reasons: PVC order-swapped value (exact match required) + CRD lookup failure for each group' $r 'argo-4' 'FAIL' @('3 problem(s)', "PVC ns vault: 1 of 2 object(s) without sync-options exactly '$sync': vault/data-vault-0='Prune=false,Delete=false'", 'CRD group cert-manager.io: lookup failed', 'CRD group external-secrets.io: lookup failed', 'Forbidden') @('audit-vault-0', 'unhandled')
        foreach ($id in $gatedIds) { Assert-IdExact "C11-2 ${id}: SKIP unchanged (the gate does not depend on the CRD list)" $r $id 'SKIP' $skipText[$id] }
    }
    Test-Case 'C12' 'argo-4: the Vault PVC lookup fails -> the cert-manager CRD mismatch is still reported on the same line' {
        $resp = New-Responses
        $resp[$Q.vaultPvc] = R-Err $connErr
        $resp[$Q.crds] = R-Json (New-Us2CrdList @{ 'challenges.acme.cert-manager.io' = 'Delete=false' })
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C12' $r $d
        Assert-Id 'C12-1: argo-4 FAIL with the PVC lookup failure and the CRD mismatch; the ESO group is not a problem' $r 'argo-4' 'FAIL' @('2 problem(s)', 'PVC ns vault: lookup failed', 'Unable to connect to the server', "CRD group cert-manager.io: 1 of 6 object(s) without sync-options exactly '$sync': challenges.acme.cert-manager.io='Delete=false'") @('CRD group external-secrets.io:', 'unhandled')
    }

    # ================= 게이트: 조회 결과의 정체(2라운드 적대 리뷰 F1) =================
    # Application 조회가 exit 0으로 "그 이름의 Application이 아닌 것"을 돌려주면 FAIL(SKIP 아님): 빈 객체 · 다른 이름 · List · 객체 둘(나머지 모양은 F06)
    Test-Case 'C13' 'gate: the Application get returns valid JSON that is not Application argocd/<name> ({} / another name / List / two objects) -> FAIL, never SKIP' {
        $resp = New-Responses
        $resp[(AppKey 'platform-cnpg')] = R-Raw '{}'
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json (New-App 'platform-cnpg' 0)
        $resp[(AppKey 'platform-kafka')] = R-Raw '{"apiVersion":"v1","kind":"List","metadata":{},"items":[]}'
        $resp[(AppKey 'platform-dragonfly')] = R-Raw ('[' + (Json (New-App 'platform-dragonfly' 0)) + ',' + (Json (New-App 'platform-dragonfly' 0)) + ']')
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C13' $r $d
        Assert-Id 'C13-1: argo-4-cnpg-crd FAIL -- {} is not an Application' $r 'argo-4-cnpg-crd' 'FAIL' @('lookup returned 1 object(s) that are not Application argocd/platform-cnpg', "kind=''") @('until T052')
        Assert-Id 'C13-2: argo-4-pg-main FAIL -- the object is named platform-cnpg, not platform-cnpg-cluster' $r 'argo-4-pg-main' 'FAIL' @('not Application argocd/platform-cnpg-cluster', "name='platform-cnpg'") @('until T053')
        Assert-Id 'C13-3: argo-4-strimzi FAIL -- a List is not an Application' $r 'argo-4-strimzi' 'FAIL' @('not Application argocd/platform-kafka', "kind='List'") @('until T055')
        Assert-Id 'C13-4: argo-4-dragonfly FAIL -- two objects came back for one name' $r 'argo-4-dragonfly' 'FAIL' @('lookup returned 2 object(s)') @('until T057')
        Assert-IdExact 'C13-5: argo-4 (US2) PASS in the same run' $r 'argo-4' 'PASS' $us2PassDetail
    }

    # ================= np-2-* 게이트(2라운드 적대 리뷰 F2 — 컨트롤러 범위 확장) =================
    # Job 없음 + 소유 과제 체크됨(소문자 [x] — 대문자 [X]는 같은 Get-TaskLineState를 argo-4-* 게이트 C03 · F04가 덮는다) → FAIL(SKIP 아님) · 과제 줄 0개(비슷한 줄은
    # 세지 않는다) → FAIL. data-assert · kafka-assert는 같은 T059 줄 하나를 읽으므로 둘 다 FAIL. 미체크 → SKIP은 C02-5, tasks.md 문제는 C07–C09.
    Test-Case 'C14' 'np-2 gate: Job absent + owner task checked -> FAIL (never SKIP); owner task line missing -> FAIL; argo-4-* and argo-4 unaffected' {
        $np2 = @('- [x] T059 [US3] E2E (lowercase check mark)', '  - [ ] T085 indented (not the task-line shape)')
        $d = New-Fixture (New-Responses) (New-TasksText $tUnchecked $np2)
        $r = Invoke-Harness $d
        Assert-Run 'C14' $r $d
        Assert-IdExact 'C14-1: np-2-data-assert FAIL -- T059 is checked ("[x]" counts as checked) but the Job is absent' $r 'np-2-data-assert' 'FAIL' 'T059 is checked in tasks.md but Job jt-dev/data-assert is absent'
        Assert-IdExact 'C14-2: np-2-kafka-assert FAIL -- the same checked T059 line gates kafka-assert too' $r 'np-2-kafka-assert' 'FAIL' 'T059 is checked in tasks.md but Job jt-dev/kafka-assert is absent'
        Assert-Id 'C14-3: np-2-authz-assert FAIL -- no line has the exact owner-task shape for T085' $r 'np-2-authz-assert' 'FAIL' @('assert Job jt-dev/authz-assert not present', 'tasks.md has 0 task line(s) for T085') @('until T085')
        foreach ($id in $gatedIds) { Assert-IdExact "C14-4 ${id}: SKIP unchanged (the np-2 owner lines do not affect the argo-4-* gate)" $r $id 'SKIP' $skipText[$id] }
        Assert-IdExact 'C14-5: argo-4 (US2) PASS in the same run' $r 'argo-4' 'PASS' $us2PassDetail
    }

    # 나머지 모양의 E2E(F06 표를 하네스 전체 경로로): 이름 · ns는 맞지만 kind가 다름(같은 이름의 ApplicationSet — kind 검사만이 잡는다) · ns가 다른 Application ·
    # JSON 문자열 · JSON 숫자 → FAIL(SKIP 아님)
    Test-Case 'C15' 'gate: right name but kind ApplicationSet / Application in another namespace / a JSON string / a JSON number -> FAIL, never SKIP' {
        $resp = New-Responses
        $appSet = New-App 'platform-cnpg' 0; $appSet['kind'] = 'ApplicationSet'
        $resp[(AppKey 'platform-cnpg')] = R-Json $appSet
        $otherNs = New-App 'platform-cnpg-cluster' 0; $otherNs['metadata']['namespace'] = 'default'
        $resp[(AppKey 'platform-cnpg-cluster')] = R-Json $otherNs
        $resp[(AppKey 'platform-kafka')] = R-Raw '"platform-kafka"'
        $resp[(AppKey 'platform-dragonfly')] = R-Raw '42'
        $d = New-Fixture $resp (New-TasksText $tUnchecked)
        $r = Invoke-Harness $d
        Assert-Run 'C15' $r $d
        Assert-Id 'C15-1: argo-4-cnpg-crd FAIL -- the right name and namespace but kind ApplicationSet' $r 'argo-4-cnpg-crd' 'FAIL' @('not Application argocd/platform-cnpg', "kind='ApplicationSet' name='platform-cnpg' namespace='argocd'") @('until T052')
        Assert-Id 'C15-2: argo-4-pg-main FAIL -- an Application of that name in ns default, not argocd' $r 'argo-4-pg-main' 'FAIL' @('not Application argocd/platform-cnpg-cluster', "namespace='default'") @('until T053')
        Assert-Id 'C15-3: argo-4-strimzi FAIL -- a JSON string is not an Application' $r 'argo-4-strimzi' 'FAIL' @('not Application argocd/platform-kafka', "kind='' name='' namespace=''") @('until T055')
        Assert-Id 'C15-4: argo-4-dragonfly FAIL -- a JSON number is not an Application' $r 'argo-4-dragonfly' 'FAIL' @('not Application argocd/platform-dragonfly', "kind='' name='' namespace=''") @('until T057')
        Assert-IdExact 'C15-5: argo-4 (US2) PASS in the same run' $r 'argo-4' 'PASS' $us2PassDetail
    }

    # ================= 정적(하네스 원문) =================
    Test-Case 'S01' 'harness source: header lists the four argo-4-* stage SKIPs and the np-2 owner tasks; "until T041" is gone' {
        $src = if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { [IO.File]::ReadAllText($harnessPath) } else { '' }
        # 머리 주석 = 파일 첫 줄부터 이어지는 '#' 줄들(첫 번째 '#' 아닌 줄에서 끝난다)
        $hdr = [Collections.Generic.List[string]]::new()
        foreach ($l in @($src -split "`r?`n")) { if ($l.StartsWith('#', [StringComparison]::Ordinal)) { $hdr.Add($l) } else { break } }
        $header = $hdr -join "`n"
        $missing = @(@($gatedIds + @('until T059', 'until T085')) | Where-Object { -not (Has-Text $header $_) })
        Assert 'S01-1: the header comment names argo-4-cnpg-crd, argo-4-pg-main, argo-4-strimzi, argo-4-dragonfly and the np-2 owners T059/T085' ($src.Length -gt 0 -and $missing.Count -eq 0) "missing in header: $($missing -join ', ')"
        Assert 'S01-2: the harness source no longer contains "until T041"' ($src.Length -gt 0 -and -not (Has-Text $src 'until T041')) 'found "until T041" (or harness missing)'
    }

    # ================= 함수(게이트에 목록을 넘겨 시험 — 설계 D2) =================
    $script:mod = $null
    $script:modError = ''
    try { $script:mod = Import-HarnessModule $harnessPath } catch { $script:modError = $_.Exception.Message }
    # 주입 조회: 입력은 이 스크립트의 script 범위에 두고 호출을 센다(GetNewClosure는 쓰지 않는다 — 클로저 모듈 안에서는
    # $script:가 그 모듈을 가리켜 횟수가 이 스크립트로 돌아오지 않는다).
    function Get-Gate([string]$id, $allowlist, $app, [string]$appError, $tasksLines, [string]$tasksError) {
        $script:appCalls = @(); $script:taskCalls = 0
        $script:gateIn = @{ app = $app; appError = $appError; lines = @($tasksLines); tasksError = $tasksError }
        $ga = { param([string]$n) $script:appCalls += $n; $e = [string]$script:gateIn.appError; return @{ obj = $script:gateIn.app; error = $(if ($e.Length -eq 0) { $null } else { $e }) } }
        $gt = { $script:taskCalls++; $e = [string]$script:gateIn.tasksError; return @{ lines = @($script:gateIn.lines); error = $(if ($e.Length -eq 0) { $null } else { $e }) } }
        return (& $script:mod { param($i, $l, $a, $t) Resolve-Argo4Gate $i $l $a $t } $id $allowlist $ga $gt)
    }

    Test-Case 'F01' 'allowlist constant: exactly the four T049 entries (id -> Application, owner task)' {
        $ok = $null -ne $script:mod
        $al = if ($ok) { & $script:mod { $argo4Allowlist } } else { $null }
        $got = if ($null -ne $al) { @(@($al.Keys) | ForEach-Object { "$_=$($al[$_]['app'])/$($al[$_]['task'])" }) -join ', ' } else { '' }
        $want = 'argo-4-cnpg-crd=platform-cnpg/T052, argo-4-pg-main=platform-cnpg-cluster/T053, argo-4-strimzi=platform-kafka/T055, argo-4-dragonfly=platform-dragonfly/T057'
        Assert 'F01-1: $argo4Allowlist = cnpg-crd/platform-cnpg/T052, pg-main/platform-cnpg-cluster/T053, strimzi/platform-kafka/T055, dragonfly/platform-dragonfly/T057 (in that order)' (Test-Same $got $want) "got [$got] $script:modError"
        $comp = if ($null -ne $al) { @(@($al.Keys) | ForEach-Object { "$_=$($al[$_]['component'])" }) -join ' | ' } else { '' }
        $wantComp = (@($fullAllowlist.Keys | ForEach-Object { "$_=$($fullAllowlist[$_]['component'])" })) -join ' | '
        Assert 'F01-2: every entry names the component its owner task deploys (used in the SKIP text)' (Test-Same $comp $wantComp) "got [$comp]"
    }
    Test-Case 'F02' 'Resolve-Argo4Gate: an id outside the allowlist never SKIPs, even with an empty Application and an unchecked owner task' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Resolve-Argo4Gate')
        Assert 'F02-0: the harness defines Resolve-Argo4Gate' $ok "missing (module: $script:modError)"
        if ($ok) {
            $empty = New-GateApp 'platform-cnpg' 'argocd' @()
            $g = Get-Gate 'argo-4-cnpg-crd' $fullAllowlist $empty '' @('- [ ] T052 x') ''
            Assert 'F02-1: control -- in the allowlist, empty Application, T052 unchecked -> skip with the allowlist text' ((Test-Same ([string]$g.decision) 'skip') -and (Test-Same ([string]$g.reason) $skipText['argo-4-cnpg-crd'])) "got $($g.decision): $($g.reason)"
            $without = [ordered]@{}; foreach ($k in @($fullAllowlist.Keys)) { if (-not (Test-Same $k 'argo-4-cnpg-crd')) { $without[$k] = $fullAllowlist[$k] } }
            $g = Get-Gate 'argo-4-cnpg-crd' $without $empty '' @('- [ ] T052 x') ''
            Assert 'F02-2: the same inputs with argo-4-cnpg-crd removed from the passed list -> check (no SKIP path), no lookup made' ((Test-Same ([string]$g.decision) 'check') -and $script:appCalls.Count -eq 0 -and $script:taskCalls -eq 0) "got $($g.decision): $($g.reason) appCalls=$($script:appCalls.Count) taskCalls=$script:taskCalls"
            $g = Get-Gate 'argo-4-pg-main' ([ordered]@{}) $empty '' @('- [ ] T053 x') ''
            Assert 'F02-3: an empty allowlist -> check for argo-4-pg-main' (Test-Same ([string]$g.decision) 'check') "got $($g.decision): $($g.reason)"
            $g = Get-Gate 'argo-4-unknown' $fullAllowlist $empty '' @('- [ ] T052 x') ''
            Assert 'F02-4: an id the allowlist does not know -> check' (Test-Same ([string]$g.decision) 'check') "got $($g.decision): $($g.reason)"
            # 목록 항목 형식 검사(2라운드 준수 리뷰 F2): app 비어 있음 · task가 T0NN이 아님 · component 비어 있음 → 조회 전에 fail(미체크 판정이 불가능한데 SKIP이 나오면 안 된다)
            $malformed = @(
                @{ name = 'app empty'; entry = @{ app = ''; task = 'T052'; component = 'the cnpg.io CRDs' } },
                @{ name = 'task id not T0NN'; entry = @{ app = 'platform-cnpg'; task = 'T52'; component = 'the cnpg.io CRDs' } },
                @{ name = 'component empty'; entry = @{ app = 'platform-cnpg'; task = 'T052'; component = '' } }
            )
            $bad = @()
            foreach ($m in $malformed) {
                $broken = [ordered]@{ 'argo-4-cnpg-crd' = $m.entry }
                $g = Get-Gate 'argo-4-cnpg-crd' $broken $empty '' @('- [ ] T052 x', '- [ ] T52 x') ''
                if (-not (Test-Same ([string]$g.decision) 'fail') -or -not (Has-Text ([string]$g.reason) 'malformed') -or $script:appCalls.Count -ne 0 -or $script:taskCalls -ne 0) { $bad += "$($m.name): got $($g.decision) [$($g.reason)] appCalls=$($script:appCalls.Count) taskCalls=$script:taskCalls" }
            }
            Assert 'F02-5: a malformed allowlist entry (app empty / task id not T0NN / component empty) -> fail before any lookup (never skip)' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    Test-Case 'F03' 'Resolve-Argo4Gate: lookup error / missing Application / tasks problems / checked owner task -> fail; resources present -> check without reading tasks.md' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Resolve-Argo4Gate')
        Assert 'F03-0: the harness defines Resolve-Argo4Gate' $ok "missing (module: $script:modError)"
        if ($ok) {
            $empty = New-GateApp 'platform-kafka' 'argocd' @()
            $full = New-GateApp 'platform-kafka' 'argocd' @([pscustomobject]@{ kind = 'Kafka'; name = 'jt-kafka' })
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $null 'kubectl get applications.argoproj.io/platform-kafka (ns ''argocd'') failed (exit 1): Error from server (Forbidden)' @('- [ ] T055 x') ''
            Assert 'F03-1: Application lookup error -> fail (not skip), tasks.md not consulted' ((Test-Same ([string]$g.decision) 'fail') -and (Has-Text ([string]$g.reason) 'Argo CD Application platform-kafka lookup failed') -and $script:taskCalls -eq 0) "got $($g.decision): $($g.reason) taskCalls=$script:taskCalls"
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $null '' @('- [ ] T055 x') ''
            Assert 'F03-2: Application missing -> fail' ((Test-Same ([string]$g.decision) 'fail') -and (Has-Text ([string]$g.reason) 'Argo CD Application platform-kafka (ns argocd) not found')) "got $($g.decision): $($g.reason)"
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $full '' @() 'tasks.md unreadable (x): denied'
            Assert 'F03-3: resources present -> check whatever tasks.md says (not read at all)' ((Test-Same ([string]$g.decision) 'check') -and $script:taskCalls -eq 0 -and $script:appCalls.Count -eq 1 -and (Test-Same $script:appCalls[0] 'platform-kafka')) "got $($g.decision): $($g.reason) taskCalls=$script:taskCalls appCalls=$($script:appCalls -join ',')"
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $empty '' @() 'tasks.md unreadable (x): denied'
            Assert 'F03-4: empty Application + tasks.md read failure -> fail (not skip)' ((Test-Same ([string]$g.decision) 'fail') -and (Has-Text ([string]$g.reason) 'tasks.md unreadable')) "got $($g.decision): $($g.reason)"
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $empty '' @('- [X] T055 x') ''
            Assert 'F03-5: empty Application + "- [X] T055" -> fail with the checked text' ((Test-Same ([string]$g.decision) 'fail') -and (Test-Same ([string]$g.reason) 'T055 is checked in tasks.md but Argo CD Application platform-kafka has no resources')) "got $($g.decision): $($g.reason)"
            $nullRes = New-GateApp 'platform-kafka' 'argocd' $null
            $g = Get-Gate 'argo-4-strimzi' $fullAllowlist $nullRes '' @('- [ ] T055 x') ''
            Assert 'F03-6: status.resources = null counts as empty -> skip' (Test-Same ([string]$g.decision) 'skip') "got $($g.decision): $($g.reason)"
        }
    }
    Test-Case 'F04' 'Get-TaskLineState: only "- [ ] T0NN " / "- [X] T0NN " / "- [x] T0NN " at the start of a line count; exactly one line or an error' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-TaskLineState')
        Assert 'F04-0: the harness defines Get-TaskLineState' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ lines = @('- [ ] T052 a'); want = 'unchecked' },
                @{ lines = @('- [X] T052 a'); want = 'checked' },
                @{ lines = @('- [x] T052 a'); want = 'checked' },
                @{ lines = @('- [ ] T052 a', '- [ ] T053 b', '- [X] T0521 c'); want = 'unchecked' },
                @{ lines = @(); want = 'error:0' },
                @{ lines = @('- [ ] T052 a', '- [ ] T052 b'); want = 'error:2' },
                @{ lines = @('- [ ] T052 a', '- [X] T052 b'); want = 'error:2' },
                @{ lines = @('- [x] T052 a', '- [X] T052 b', '- [ ] T052 c'); want = 'error:3' },
                @{ lines = @('  - [ ] T052 a'); want = 'error:0' },
                @{ lines = @('- [ ] T0520 a'); want = 'error:0' },
                @{ lines = @('- [ ] T052'); want = 'error:0' },
                @{ lines = @('- [ ]  T052 a'); want = 'error:0' },
                @{ lines = @('- [y] T052 a'); want = 'error:0' },
                @{ lines = @('* [ ] T052 a'); want = 'error:0' },
                @{ lines = @('- [ ] t052 a'); want = 'error:0' }
            )
            $bad = @()
            foreach ($row in $table) {
                $s = & $script:mod { param($l) Get-TaskLineState $l 'T052' } $row.lines
                $got = if (-not [string]::IsNullOrEmpty([string]$s.error)) { $m = [regex]::Match([string]$s.error, 'has (\d+) task line'); "error:$(if ($m.Success) { $m.Groups[1].Value } else { '?' })" } else { [string]$s.state }
                if (-not (Test-Same $got $row.want)) { $bad += "[$($row.lines -join ' / ')] -> $got (want $($row.want))" }
            }
            Assert 'F04-1: the task-line table (unchecked / checked / 0 / 2 / 3 / near misses)' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    # 항목 0개 가드(2라운드 준수 리뷰 F3): $argo4Checks 항목이 아무것도 내지 않는 회귀가 "0 objects carry …" PASS가 되면 안 된다
    Test-Case 'F05' 'Join-Argo4Result: no item at all -> FAIL (fail closed, never an empty PASS)' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Join-Argo4Result')
        Assert 'F05-0: the harness defines Join-Argo4Result' $ok "missing (module: $script:modError)"
        if ($ok) {
            $j = @(& $script:mod { Join-Argo4Result @() '' '' })
            Assert 'F05-1: zero items -> FAIL with "no item was checked"' ($j.Count -eq 2 -and (Test-Same ([string]$j[0]) 'FAIL') -and (Has-Text ([string]$j[1]) 'no item was checked')) "got [$($j -join ' | ')]"
        }
    }
    # 조회 결과의 정체 확인(2라운드 적대 리뷰 F1): Application argocd/<name> 정확히 하나가 아니면 전부 fail — skip도 check도 아니고 tasks.md는 읽지 않는다
    Test-Case 'F06' 'Resolve-Argo4Gate: a lookup result that is not exactly one Application argocd/<name> -> fail, never skip ({} / string / integer / two {} / List / Status / another name / another namespace / two same-name objects); the real one still skips or checks' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Resolve-Argo4Gate')
        Assert 'F06-0: the harness defines Resolve-Argo4Gate' $ok "missing (module: $script:modError)"
        if ($ok) {
            $rows = @(
                @{ name = 'empty object {}'; app = [pscustomobject]@{}; has = @('returned 1 object(s)', "kind='' name='' namespace=''") },
                @{ name = 'string'; app = 'platform-cnpg'; has = @('returned 1 object(s)', "kind='' name='' namespace=''") },
                @{ name = 'integer'; app = 42; has = @('returned 1 object(s)', "kind='' name='' namespace=''") },
                @{ name = 'two empty objects'; app = @([pscustomobject]@{}, [pscustomobject]@{}); has = @('returned 2 object(s)') },
                @{ name = 'kind List'; app = [pscustomobject]@{ apiVersion = 'v1'; kind = 'List'; metadata = [pscustomobject]@{}; items = @() }; has = @("kind='List'") },
                @{ name = 'kind Status'; app = [pscustomobject]@{ apiVersion = 'v1'; kind = 'Status'; metadata = [pscustomobject]@{}; status = 'Failure'; code = 404 }; has = @("kind='Status'") },
                # 이름 · ns는 맞고 kind만 다름 — kind 검사만이 잡는 모양(변이 K01: 이름 검사는 통과한다)
                @{ name = 'right name and namespace but kind ApplicationSet'; app = [pscustomobject]@{ kind = 'ApplicationSet'; metadata = [pscustomobject]@{ name = 'platform-cnpg'; namespace = 'argocd' }; status = [pscustomobject]@{ resources = @() } }; has = @("kind='ApplicationSet' name='platform-cnpg' namespace='argocd'") },
                @{ name = 'another name'; app = (New-GateApp 'platform-cnpg-cluster' 'argocd' @()); has = @("name='platform-cnpg-cluster'") },
                @{ name = 'another namespace'; app = (New-GateApp 'platform-cnpg' 'default' @()); has = @("namespace='default'") },
                @{ name = 'two same-name objects'; app = @((New-GateApp 'platform-cnpg' 'argocd' @()), (New-GateApp 'platform-cnpg' 'argocd' @())); has = @('returned 2 object(s)') }
            )
            $bad = @()
            foreach ($row in $rows) {
                $g = Get-Gate 'argo-4-cnpg-crd' $fullAllowlist $row.app '' @('- [ ] T052 x') ''
                $reason = [string]$g.reason
                $miss = @($row.has | Where-Object { -not (Has-Text $reason $_) })
                if (-not (Test-Same ([string]$g.decision) 'fail') -or -not (Has-Text $reason 'not Application argocd/platform-cnpg') -or $miss.Count -gt 0 -or $script:taskCalls -ne 0) { $bad += "$($row.name): got $($g.decision) [$reason] taskCalls=$script:taskCalls" }
            }
            Assert 'F06-1: every non-Application shape -> fail naming what came back (never skip), tasks.md not read' ($bad.Count -eq 0) ($bad -join '; ')
            $g = Get-Gate 'argo-4-cnpg-crd' $fullAllowlist (New-GateApp 'platform-cnpg' 'argocd' @()) '' @('- [ ] T052 x') ''
            Assert 'F06-2: control -- the real Application argocd/platform-cnpg with 0 resources still skips with the allowlist text' ((Test-Same ([string]$g.decision) 'skip') -and (Test-Same ([string]$g.reason) $skipText['argo-4-cnpg-crd'])) "got $($g.decision): $($g.reason)"
            $g = Get-Gate 'argo-4-cnpg-crd' $fullAllowlist (New-GateApp 'platform-cnpg' 'argocd' @([pscustomobject]@{ kind = 'CustomResourceDefinition'; name = 'clusters.postgresql.cnpg.io' })) '' @('- [ ] T052 x') ''
            Assert 'F06-3: control -- the real Application with 1 resource -> check (tasks.md not read)' ((Test-Same ([string]$g.decision) 'check') -and $script:taskCalls -eq 0) "got $($g.decision): $($g.reason) taskCalls=$script:taskCalls"
        }
    }

    # 선택 실행에 모르는 케이스 이름이 있으면 실패(오타로 아무것도 안 돌고 통과하지 않게)
    foreach ($o in $script:only) {
        if (@($script:known | Where-Object { Test-Same $_ $o }).Count -eq 0) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in CLUSTER_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
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
