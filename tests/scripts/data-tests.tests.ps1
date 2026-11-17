# tests/platform/data.tests.ps1 하네스 단위 테스트(T050 — US3 데이터 플랫폼 단언, test-first).
# Run: pwsh -NoProfile -File tests/scripts/data-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/cluster-tests.tests.ps1과 같은 구조).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all의 data-harness 체크가 이 파일을 직접 실행한다 — 등록은 컨트롤러).
#
# 무엇을 지키나(요구 원문 .superpowers/t050/prompts/t050-brief.md — 설계 D1–D6; 리뷰 반영 2라운드 …/t050-fix-round2.md · 3라운드 …/t050-fix-round3.md):
#   - 16 단언(gate 3 · pg 2 · db 2 · role 2 · backup 2 · bucket 2 · job 2 · env 1)이 전부 갖춰진 픽스처에서 PASS 문구를 정확히 낸다.
#   - 지금 라이브 모양(CNPG CRD 없음 · Job 없음 · 버킷 오브젝트 0 · Deployment 0)에서 pg/db/role/backup/bucket/job 전부 FAIL하고 사유에
#     "CRD not installed (T052 …)" 등 소유 과제(ScheduledBackup · 버킷 = T053, Database/DatabaseRole = T054)가 남으며(D4 격리 — 어떤 단언도
#     'unhandled'로 끝나지 않는다), env-1만 D3 게이트로 SKIP한다. 단언 본문이 자기 try/catch 밖에서 예외를 내면(C12: Job status.succeeded가 숫자가
#     아님) ClusterAssert 안전망이 그 단언만 'unhandled …' FAIL로 바꾸고 나머지 단언은 계속 돈다(요약 줄까지). whoami가 다른 사용자면(C13)
#     gate-3 FAIL + 클러스터 단언 13개 전부 'cluster unavailable (context user is not agent-view)' + kubectl 1회 · oci 0회(fail closed).
#   - 집합 비교는 정확 일치(하나 더 · 하나 모자람 · 같은 이름 둘 · applied≠true · spec.ensure=absent(Database · DatabaseRole 둘 다) · generation≠observedGeneration
#     전부 FAIL) · owner 대조(absent 객체는 후보 아님) · role 속성(app role도 createdb/createrole; absent 객체는 후보 아님) · schedule · suspend · completed 0 ·
#     최근 completed 25 h 초과(나이 소수 한 자리) · 시각 없음 · base 없음 · 다른 serverName만 · backupId 불일치 ·
#     WAL 세그먼트 개수/불연속/신선도(유휴 OR 가지 = ContinuousArchiving(조건은 type으로 고른다 — Ready가 먼저 와도) + endWal + endWal부터 최신까지 전 구간 연속) ·
#     라벨/히스토리 파일 제외 · Job failed(succeeded와 무관)/진행 중/없음 · RESULT id 빠짐/FAIL/중복 · SUMMARY 없음/fail≠0/RESULT 수 불일치/추적 밖 FAIL ·
#     -migrate 참조(envFrom · secretKeyRef · 볼륨) · Deployment 정확히 1개는 평가(SKIP 아님) · T075 체크됨 + Deployment 0 · tasks.md 없음/줄 ≠ 1 ·
#     OCI 세션 만료/파싱 실패/CLI 없음 · exit 0인데 목록 모양이 아닌 JSON(Status · 단일 객체 · items 없는 List · items: null인 List; 단일 자리의 List —
#     env-1은 SKIP이 아니라 FAIL)
#     → 각각 해당 ID만 FAIL/SKIP이고 문구가 정확하다.
#   - 모든 kubectl 호출은 읽기 전용 동사(get · logs · auth whoami) + --kubeconfig 명시 + 응답표 안이고, oci 호출은 정확히 1번 ·
#     `--profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup --prefix pg-main/ --all … --output json`이며
#     쓰기 동사가 없다. Job 로그의 EVIDENCE: 내용은 출력에 옮겨지지 않는다. kubectl이 되돌린 kubeconfig 경로는 출력에서 <KUBECONFIG>로 가려진다
#     (Mask-Text — C02의 {KUBECONFIG} 자리표시자). 실행 뒤 픽스처 tmp/에 data-tests-* 임시 파일이 남지 않는다.
#
# 방식 1 — E2E 케이스(C*): 케이스마다 임시 픽스처(%TEMP%/datatest-<guid>)에
#     하네스 사본  repo/tests/platform/data.tests.ps1  (DATA_HARNESS_SCRIPT가 있으면 그 파일의 사본)
#     픽스처 tasks repo/specs/003-platform-foundation/tasks.md — 하네스의 기본 경로($PSScriptRoot/../../specs/…)가 픽스처 안을 가리킨다.
#                  실제 specs/003-platform-foundation/tasks.md는 어떤 케이스도 읽지 않는다(사본이 저장소 밖에서 돈다).
#     가짜 kubectl bin/kubectl.cmd 심 → bin/fake-kubectl.ps1 · 응답표 responses.tsv + resp/ · 더미 kubeconfig.yaml · tmp/
#     가짜 oci     bin/oci.cmd 심 → bin/fake-oci.ps1 · 응답 oci-resp/{out,err,code}.txt · 기록 oci-calls.log(C11은 심을 두지 않는다)
#   를 만들고 하네스 사본을 자식 pwsh로 실행한다(KUBECONFIG = 더미 파일, TMP/TEMP = 픽스처 tmp/, OCI_CLI_* 제거, 실행마다 시간 상한).
#   자식 PATH = 픽스처 bin + 지금 PATH에서 kubectl.* · oci.* · curl.* 파일이 있는 디렉터리를 뺀 나머지 — 실제 kubectl · oci(svc-verify 세션)에
#   닿지 않는다. 실행마다 자식 PATH에서 처음 찾히는 kubectl · oci가 픽스처 심인지 확인하고, 아니면 하네스를 실행하지 않는다.
# 가짜 kubectl · oci: 심이 넘긴 원래 명령줄(FAKE_KUBECTL_ARGV · FAKE_OCI_ARGV)을 Windows 규칙으로 나눈다(pwsh -File이 '--kubeconfig=C:\…'를
#   쪼개므로 $args를 쓰지 않는다). kubectl은 --kubeconfig=… · --request-timeout=…을 뗀 나머지를 공백 하나로 이은 key를 응답표에서 ordinal로
#   찾는다(없으면 exit 1 + 'no fixture response' — 케이스마다 0개를 단언). oci는 인자 전부를 oci-calls.log에 TAB으로 기록하고 oci-resp/를 그대로 낸다
#   (모듈 cmdlet 없이 .NET만 — 하네스의 Invoke-Oci가 호출 동안 PSModulePath에서 pwsh 7 모듈 경로를 빼기 때문).
# 방식 2 — 함수 케이스(F*): 하네스 파일을 AST로 읽어 최상위 함수 정의와 몇 개 상수만 동적 모듈 안에 정의한다(최상위 문장은 실행하지 않는다).
#   순수 함수(Test-JobLog · Get-WalSegment · Test-WalContiguity(상위 3개 · $floorHex) · Test-WalFreshness · Find-MigrateRefs · Test-NamedSet ·
#   Get-TaskLineState · Items)를 표로 시험한다 — 지금 시각과 유휴 근거는 주입한다.
#
# 환경 변수:
#   DATA_HARNESS_SCRIPT      시험할 하네스(기본 tests/platform/data.tests.ps1) — 변이 시험에서 사본을 가리킨다. 설정되면 요약 줄 끝에
#                            ' (script override: <파일 이름>)'이 붙어 run-all의 'N passed, 0 failed' 판정을 통과하지 못한다.
#   DATA_HARNESS_TESTS_ONLY  쉼표로 나눈 케이스 ID(예: C01,F02)만 실행한다. 요약 줄 끝에 ' (filtered: …)'가 붙는다. 모르는 ID가 있으면 FAIL.
# 실행 시간: E2E 케이스 하나에 가짜 kubectl 호출 12번 + oci 1번(호출마다 cmd + pwsh 하나) → 이 PC 무부하 실측 케이스당 약 7–10 s(2026-10-08 두 번: 6.7–8.3 s ·
#   7.9–9.6 s; C13은 호출 1번이라 약 1.4 s), E2E 20건 + 정적 1 · 함수 6 케이스로 전체 약 2.5분(2026-10-08 3라운드 실측 137.9 s · 166 s; 2라운드 E2E 17건 때
#   116–118 s; 같은 PC에서 다른 무거운 작업이 돌면 5분 이상).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:DATA_HARNESS_SCRIPT)
$harnessPath = if ($scriptOverride) { $env:DATA_HARNESS_SCRIPT } else { Join-Path $repo 'tests/platform/data.tests.ps1' }
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$tasksRel = 'repo/specs/003-platform-foundation/tasks.md'
$sep = [IO.Path]::PathSeparator
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
if (-not [string]::IsNullOrWhiteSpace($env:DATA_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:DATA_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}
# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Has-Text([string]$s, [string]$needle) { return ($null -ne $s -and $s.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }
function In-Set($arr, [string]$v) { return (@(@($arr) | Where-Object { Test-Same ([string]$_) $v }).Count -gt 0) }

# 케이스 격리 + 선택 실행. 한 케이스에서 예외가 나도 나머지는 계속 실행된다.
function Test-Case([string]$id, [string]$title, [scriptblock]$body) {
    $caseId = $id
    $script:known += $caseId
    if ($script:only.Count -gt 0 -and -not (In-Set $script:only $caseId)) { return }
    Write-Host "-- ${caseId}: $title"
    $caseWatch = [Diagnostics.Stopwatch]::StartNew()
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $caseId -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    Write-Host "   [$caseId took $($caseWatch.Elapsed.TotalSeconds.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))s]"
}

# ---------- 가짜 명령줄 나누기(두 가짜가 공유) ----------
$splitCommandLine = @'
# 나누기는 Windows 명령줄 규칙(CommandLineToArgvW: 따옴표 밖 공백 = 구분, " = 따옴표 토글, \ 2n개 + " = \ n개 + 토글, \ 2n+1개 + " = \ n개 + 문자 ")이다.
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
'@

# ---------- 가짜 kubectl(픽스처 bin/fake-kubectl.ps1 — cluster-tests.tests.ps1과 같은 동작) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/data-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
# 입력: ..\responses.tsv(줄 = 번호 TAB 종료코드 TAB key) + ..\resp\<번호>.out · <번호>.err
# 기록: ..\calls.log(줄 = served TAB 종료코드 TAB kubeconfig TAB request-timeout TAB key)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetDirectoryName($PSScriptRoot)
$utf8 = [Text.UTF8Encoding]::new($false)
try { [Console]::OutputEncoding = $utf8 } catch { }
'@ + "`n" + $splitCommandLine + @'

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
$hit = $null
foreach ($row in [IO.File]::ReadAllLines([IO.Path]::Combine($root, 'responses.tsv'), $utf8)) {
    $f = $row.Split([char[]]@([char]9), 3)
    if ($f.Count -eq 3 -and [string]::Equals($f[2], $key, [StringComparison]::Ordinal)) { $hit = $f; break }
}
if ($null -ne $hit) {
    $out = [IO.File]::ReadAllText([IO.Path]::Combine($root, 'resp', "$($hit[0]).out"), $utf8)
    $err = [IO.File]::ReadAllText([IO.Path]::Combine($root, 'resp', "$($hit[0]).err"), $utf8)
    $code = [int]$hit[1]; $served = 'fixture'
} else { $err = "fake-kubectl: no fixture response for: $key" }
$line = "$served`t$code`t$kc`t$rt`t$key"
for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::AppendAllText([IO.Path]::Combine($root, 'calls.log'), $line + "`n", $utf8); break } catch { Start-Sleep -Milliseconds 25 } }
if (-not [string]::IsNullOrEmpty($err)) { [Console]::Error.WriteLine($err) }
if (-not [string]::IsNullOrEmpty($out)) { [Console]::Out.Write($out) }
exit $code
'@

# ---------- 가짜 oci(픽스처 bin/fake-oci.ps1) ----------
$fakeOci = @'
# 가짜 oci(tests/scripts/data-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 OCI · svc-verify 세션에 닿지 않는다.
# 입력: ..\oci-resp\out.txt · err.txt · code.txt   기록: ..\oci-calls.log(줄 = 인자 전부를 TAB으로 이음)
# 모듈 cmdlet을 쓰지 않는다(.NET만): 하네스의 Invoke-Oci가 호출 동안 PSModulePath에서 pwsh 7 모듈 경로를 빼므로 Split-Path · Join-Path에 기대지 않는다.
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetDirectoryName($PSScriptRoot)
$utf8 = [Text.UTF8Encoding]::new($false)
'@ + "`n" + $splitCommandLine + @'

$argv = Split-CommandLine ([string]$env:FAKE_OCI_ARGV)
$line = ($argv -join "`t")
for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::AppendAllText([IO.Path]::Combine($root, 'oci-calls.log'), $line + "`n", $utf8); break } catch { Start-Sleep -Milliseconds 25 } }
$dir = [IO.Path]::Combine($root, 'oci-resp')
$out = [IO.File]::ReadAllText([IO.Path]::Combine($dir, 'out.txt'), $utf8)
$err = [IO.File]::ReadAllText([IO.Path]::Combine($dir, 'err.txt'), $utf8)
$code = [int]([IO.File]::ReadAllText([IO.Path]::Combine($dir, 'code.txt'), $utf8).Trim())
if (-not [string]::IsNullOrEmpty($err)) { [Console]::Error.Write($err) }
if (-not [string]::IsNullOrEmpty($out)) { [Console]::Out.Write($out) }
exit $code
'@

# .cmd 심: CRLF, BOM 없음(@echo off가 1행이어야 한다). 받은 명령줄(%*)을 환경 변수로 넘기고 현재 pwsh로 가짜 스크립트를 실행해 종료 코드를 돌려준다.
$crlf = "`r`n"
function New-Shim([string]$envName, [string]$scriptName) {
    return (@(
            '@echo off'
            "set `"$envName=%*`""
            "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0$scriptName`""
            'exit /b %ERRORLEVEL%'
        ) -join $crlf) + $crlf
}

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

# ---------- 응답표 조각 ----------
function Json($o) { return (ConvertTo-Json -InputObject $o -Depth 30 -Compress) }
function R-Json($o) { return @{ out = (Json $o); err = ''; code = 0 } }
function R-None { return @{ out = ''; err = ''; code = 0 } }   # --ignore-not-found + 객체 없음 = 빈 출력 · exit 0
function R-Raw([string]$out) { return @{ out = $out; err = ''; code = 0 } }
function R-Err([string]$err, [int]$code = 1) { return @{ out = ''; err = $err; code = $code } }
function R-NoType([string]$plural) { return R-Err "error: the server doesn't have a resource type `"$plural`"" }
function New-List([object[]]$items) { return [ordered]@{ apiVersion = 'v1'; kind = 'List'; items = @(@($items) | Where-Object { $null -ne $_ }) } }
$inv = [Globalization.CultureInfo]::InvariantCulture
# 가장 최근 completed Backup의 시각은 지금(UTC)으로부터 2 h 전(backup-2의 25 h 창 안)이다 — 초 단위로 잘라 픽스처와 기대 문구가 같은 값을 쓴다.
#   픽스처는 startedAt을 'Z'로, stoppedAt을 +09:00 오프셋 표기로 낸다(문자열 왕복 없이 UTC로 바뀌는지 본다 — 기대 문구는 UTC 'Z').
$script:nowAtStart = [DateTime]::UtcNow
$script:latestStop = [DateTime]::new($script:nowAtStart.Year, $script:nowAtStart.Month, $script:nowAtStart.Day, $script:nowAtStart.Hour, $script:nowAtStart.Minute, $script:nowAtStart.Second, [DateTimeKind]::Utc).AddHours(-2)
$script:latestStart = $script:latestStop.AddSeconds(-38)
function Fmt-Utc([DateTime]$d) { return $d.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv) }
function Fmt-Kst([DateTime]$d) { return $d.AddHours(9).ToString("yyyy-MM-dd'T'HH:mm:ss'+09:00'", $inv) }

# ---------- 객체 빌더(CNPG 1.30 CRD 모양 — 하네스 머리 주석 「필드 출처」) ----------
function New-Node([string]$name, [string]$role) {
    return [ordered]@{ apiVersion = 'v1'; kind = 'Node'; metadata = [ordered]@{ name = $name; labels = [ordered]@{ role = $role; 'kubernetes.io/hostname' = $name } }; status = [ordered]@{ conditions = @([ordered]@{ type = 'Ready'; status = 'True' }) } }
}
function New-Pod([string]$name, [string]$node, [string]$phase = 'Running') {
    return [ordered]@{ apiVersion = 'v1'; kind = 'Pod'; metadata = [ordered]@{ name = $name; namespace = 'data'; labels = [ordered]@{ 'cnpg.io/cluster' = 'pg-main'; 'cnpg.io/podRole' = 'instance'; 'cnpg.io/instanceName' = $name } }; spec = [ordered]@{ nodeName = $node }; status = [ordered]@{ phase = $phase } }
}
# Cluster status.conditions[] 원소(type · status) — bucket-2 유휴 OR 가지의 ContinuousArchiving
function Cond([string]$type, [string]$status) { return [ordered]@{ type = $type; status = $status; reason = "${type}Success"; message = ''; lastTransitionTime = '2026-10-07T00:00:00Z' } }
# $conditions: $null = status.conditions 없음(기본 — 유휴 가지가 "no ContinuousArchiving condition"으로 FAIL), 배열이면 그대로
function New-Cluster([string]$phase = 'Cluster in healthy state', [int]$instances = 1, $ready = 1, [object[]]$conditions = $null) {
    $st = [ordered]@{ phase = $phase; readyInstances = $ready; instances = $instances }
    if ($null -ne $conditions) { $st['conditions'] = @($conditions) }
    return [ordered]@{ apiVersion = 'postgresql.cnpg.io/v1'; kind = 'Cluster'; metadata = [ordered]@{ name = 'pg-main'; namespace = 'data' }; spec = [ordered]@{ instances = $instances; imageName = 'ghcr.io/cloudnative-pg/postgresql:18.0' }; status = $st }
}
# $applied: $true · $false · 'absent'(status 없음). $ensure: spec.ensure('present' 기본 — API 기본값; 'absent' = 삭제 선언).
#   $generation/$observedGeneration: metadata.generation · status.observedGeneration(기본 1 = 1; 다르면 stale, $null이면 observedGeneration 없음)
function New-Database([string]$name, [string]$owner, $applied = $true, [string]$cluster = 'pg-main', [string]$ensure = 'present', [int]$generation = 1, $observedGeneration = 1) {
    $o = [ordered]@{ apiVersion = 'postgresql.cnpg.io/v1'; kind = 'Database'; metadata = [ordered]@{ name = ($name -replace '_', '-'); namespace = 'data'; generation = $generation }; spec = [ordered]@{ cluster = [ordered]@{ name = $cluster }; name = $name; owner = $owner; ensure = $ensure; databaseReclaimPolicy = 'retain' } }
    if (-not ($applied -is [string])) { $o['status'] = [ordered]@{ applied = $applied; observedGeneration = $observedGeneration } }
    return $o
}
# $attrs: login · superuser · bypassrls · createdb · createrole 가운데 넣을 것만. $secret: 이름, '' = passwordSecret 없음. $ensure · generation은 New-Database와 같다
function New-Role([string]$name, [hashtable]$attrs, $applied = $true, [string]$cluster = 'pg-main', [string]$secret = 'auto', [string]$ensure = 'present', [int]$generation = 1, $observedGeneration = 1) {
    $spec = [ordered]@{ cluster = [ordered]@{ name = $cluster }; name = $name; ensure = $ensure }
    foreach ($k in @('login', 'superuser', 'bypassrls', 'createdb', 'createrole')) { if ($attrs.ContainsKey($k)) { $spec[$k] = $attrs[$k] } }
    if (Test-Same $secret 'auto') { $secret = ($name -replace '_', '-') + '-password' }
    if ($secret.Length -gt 0) { $spec['passwordSecret'] = [ordered]@{ name = $secret } }
    $o = [ordered]@{ apiVersion = 'postgresql.cnpg.io/v1'; kind = 'DatabaseRole'; metadata = [ordered]@{ name = ($name -replace '_', '-'); namespace = 'data'; generation = $generation }; spec = $spec }
    if (-not ($applied -is [string])) { $o['status'] = [ordered]@{ applied = $applied; observedGeneration = $observedGeneration } }
    return $o
}
function Role-App([string]$name, [hashtable]$override = @{}) { $a = @{ login = $true; superuser = $false; bypassrls = $false }; foreach ($k in $override.Keys) { $a[$k] = $override[$k] }; return (New-Role $name $a) }
function Role-Owner([string]$name, [hashtable]$override = @{}) { $a = @{ login = $true; superuser = $false; bypassrls = $true; createdb = $false; createrole = $false }; foreach ($k in $override.Keys) { $a[$k] = $override[$k] }; return (New-Role $name $a) }
function Role-Shared([string]$name, [hashtable]$override = @{}, [string]$secret = 'auto') { $a = @{ login = $true; superuser = $false }; foreach ($k in $override.Keys) { $a[$k] = $override[$k] }; return (New-Role $name $a $true 'pg-main' $secret) }
# $suspend: $null = spec.suspend 없음(기본), $true/$false = 그대로
function New-ScheduledBackup([string]$name = 'pg-main-daily', [string]$schedule = '0 0 17 * * *', [string]$cluster = 'pg-main', $suspend = $null) {
    $spec = [ordered]@{ schedule = $schedule; cluster = [ordered]@{ name = $cluster }; method = 'plugin'; backupOwnerReference = 'self' }
    if ($null -ne $suspend) { $spec['suspend'] = $suspend }
    return [ordered]@{ apiVersion = 'postgresql.cnpg.io/v1'; kind = 'ScheduledBackup'; metadata = [ordered]@{ name = $name; namespace = 'data' }; spec = $spec }
}
# $backupId · $endWal: status.backupId(버킷 base/<backupId>/ — bucket-1 교차 확인) · status.endWal(bucket-2 유휴 가지); '' = 없음
function New-Backup([string]$name, [string]$phase, [string]$started, [string]$stopped, [string]$cluster = 'pg-main', [string]$backupId = '', [string]$endWal = '') {
    $st = [ordered]@{ phase = $phase; method = 'plugin' }
    if ($started.Length -gt 0) { $st['startedAt'] = $started }
    if ($stopped.Length -gt 0) { $st['stoppedAt'] = $stopped }
    if ($backupId.Length -gt 0) { $st['backupId'] = $backupId }
    if ($endWal.Length -gt 0) { $st['endWal'] = $endWal }
    return [ordered]@{ apiVersion = 'postgresql.cnpg.io/v1'; kind = 'Backup'; metadata = [ordered]@{ name = $name; namespace = 'data' }; spec = [ordered]@{ cluster = [ordered]@{ name = $cluster }; method = 'plugin' }; status = $st }
}
function Good-Dbs { return @((New-Database 'identity_admin' 'identity_admin_owner'), (New-Database 'dev_identity_admin' 'dev_identity_admin_owner'), (New-Database 'authentik' 'authentik_owner'), (New-Database 'openfga' 'openfga_owner')) }
function Good-Roles { return @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'authentik_owner'), (Role-Shared 'openfga_owner')) }
# 가장 최근 completed(2 h 전)는 stoppedAt을 오프셋 표기(+09:00)로 둔다 — 문자열 왕복 없이 UTC로 바뀌는지 본다. backupId는 $baseObjs의 base/<backupId>/와 같다.
$latestBackupId = '20261006T170003'
function Good-Backups {
    return @((New-Backup 'pg-main-daily-20261005170000' 'completed' (Fmt-Utc $script:latestStart.AddDays(-1)) (Fmt-Utc $script:latestStop.AddDays(-1)) 'pg-main' '20261005T170002' '0000000100000000000000B0'),
        (New-Backup 'pg-main-daily-20261006170000' 'completed' (Fmt-Utc $script:latestStart) (Fmt-Kst $script:latestStop) 'pg-main' $latestBackupId '0000000100000000000000C0'),
        (New-Backup 'pg-main-daily-20261004170000' 'failed' (Fmt-Utc $script:latestStart.AddDays(-2)) ''))
}
function New-Job([string]$name = 'data-assert', $succeeded = 1, $failed = $null, $active = $null) {
    $st = [ordered]@{}
    if ($null -ne $succeeded) { $st['succeeded'] = $succeeded }
    if ($null -ne $failed) { $st['failed'] = $failed }
    if ($null -ne $active) { $st['active'] = $active }
    return [ordered]@{ apiVersion = 'batch/v1'; kind = 'Job'; metadata = [ordered]@{ name = $name; namespace = 'jt-dev' }; status = $st }
}
$jobIdsAll = @('pg-cross-db-denied', 'catalog-connect-false', 'revoke-public', 'ssl-verify-full', 'role-attrs', 'app-session-timeouts', 'acl-list', 'noperm')
$evidenceMarker = 'EVIDENCE-MARKER-DO-NOT-COPY'
# Job 로그(README §로그 계약 모양 + EVIDENCE/NOTE 보조 줄). $override: id → 'PASS'/'FAIL', $omit: 빼는 id, $duplicate: 두 번 내는 id,
#   $summary: 'auto'(세어서 냄) · $null(없음) · 문자열(그대로)
function New-JobLog([hashtable]$override = @{}, [string[]]$omit = @(), [string[]]$duplicate = @(), $summary = 'auto') {
    $lines = @('NOTE: data-assert start', "EVIDENCE: ACL LIST user sample-pod on #<redacted> $evidenceMarker")
    $pass = 0; $fail = 0
    foreach ($id in $jobIdsAll) {
        if (In-Set $omit $id) { continue }
        $st = if ($override.ContainsKey($id)) { [string]$override[$id] } else { 'PASS' }
        $times = if (In-Set $duplicate $id) { 2 } else { 1 }
        for ($i = 0; $i -lt $times; $i++) {
            if (Test-Same $st 'PASS') { $pass++ } else { $fail++ }
            $lines += "RESULT: $st $id evidence-for-$id $evidenceMarker"
        }
    }
    if ($summary -is [string] -and (Test-Same $summary 'auto')) { $lines += "SUMMARY: pass=$pass fail=$fail" }
    elseif ($null -ne $summary) { $lines += [string]$summary }
    return (($lines -join "`n") + "`n")
}
# Deployment: $envFrom = secretRef 이름들, $envKeys = ENV → secretKeyRef 이름, $initEnvKeys = initContainer의 ENV → secretKeyRef 이름,
#   $secretVolumes = volumes[].secret.secretName(볼륨 이름 sv1, sv2 …), $projectedSecrets = volumes[].projected.sources[].secret.name(pv1 …)
function New-Deployment([string]$ns, [string]$name, [string[]]$envFrom = @(), [hashtable]$envKeys = @{}, [hashtable]$initEnvKeys = @{}, [string[]]$secretVolumes = @(), [string[]]$projectedSecrets = @()) {
    $c = [ordered]@{ name = $name; image = "ghcr.io/joshuatech/$name@sha256:0000000000000000000000000000000000000000000000000000000000000000"; envFrom = @(); env = @() }
    foreach ($s in $envFrom) { $c['envFrom'] += , [ordered]@{ secretRef = [ordered]@{ name = $s } } }
    $c['envFrom'] += , [ordered]@{ configMapRef = [ordered]@{ name = "$name-config" } }
    foreach ($k in @($envKeys.Keys | Sort-Object)) { $c['env'] += , [ordered]@{ name = $k; valueFrom = [ordered]@{ secretKeyRef = [ordered]@{ name = $envKeys[$k]; key = 'url' } } } }
    $c['env'] += , [ordered]@{ name = 'LOG_LEVEL'; value = 'info' }
    $podSpec = [ordered]@{ containers = @($c) }
    if ($initEnvKeys.Count -gt 0) {
        $ic = [ordered]@{ name = 'migrate-wait'; image = 'busybox@sha256:0000000000000000000000000000000000000000000000000000000000000000'; env = @() }
        foreach ($k in @($initEnvKeys.Keys | Sort-Object)) { $ic['env'] += , [ordered]@{ name = $k; valueFrom = [ordered]@{ secretKeyRef = [ordered]@{ name = $initEnvKeys[$k]; key = 'url' } } } }
        $podSpec['initContainers'] = @($ic)
    }
    $vols = @(); $i = 0
    foreach ($s in $secretVolumes) { $i++; $vols += , [ordered]@{ name = "sv$i"; secret = [ordered]@{ secretName = $s } } }
    $i = 0
    foreach ($s in $projectedSecrets) { $i++; $vols += , [ordered]@{ name = "pv$i"; projected = [ordered]@{ sources = @([ordered]@{ secret = [ordered]@{ name = $s } }) } } }
    if ($vols.Count -gt 0) { $podSpec['volumes'] = @($vols) }
    return [ordered]@{ apiVersion = 'apps/v1'; kind = 'Deployment'; metadata = [ordered]@{ name = $name; namespace = $ns }; spec = [ordered]@{ replicas = 1; template = [ordered]@{ spec = $podSpec } } }
}
# OCI 오브젝트(--output json의 data[] 모양: name · size · time-created)
function Oci-Obj([string]$name, [DateTime]$utc, [int]$size = 1024) { return [ordered]@{ name = $name; size = $size; 'time-created' = $utc.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'+00:00'", $inv) } }
function New-OciListing([object[]]$objs) { return (Json ([ordered]@{ data = @(@($objs) | Where-Object { $null -ne $_ }); prefixes = @() })) }
# WAL 세그먼트 이름: timeline 1 · logno 0 · segno $i(hex) — pg-main/pg-main/wals/0000000100000000/0000000100000000<X8>.lz4
function Wal-Name([int]$i) { return 'pg-main/pg-main/wals/0000000100000000/0000000100000000' + $i.ToString('X8', $inv) + '.lz4' }
$baseObjs = @((Oci-Obj 'pg-main/pg-main/base/20261006T170003/backup.info' ([DateTime]::new(2026, 10, 6, 17, 0, 41, [DateTimeKind]::Utc)) 2048), (Oci-Obj 'pg-main/pg-main/base/20261006T170003/data.tar' ([DateTime]::new(2026, 10, 6, 17, 0, 40, [DateTimeKind]::Utc)) 1048576))
# wals/ 아래의 세그먼트가 아닌 오브젝트(라벨 파일 · 타임라인 히스토리) — 목록 총수에는 들고 WAL 세그먼트 수에는 들지 않는다
$walExtraObjs = @((Oci-Obj 'pg-main/pg-main/wals/0000000100000000/0000000100000000000000C0.00000028.backup.lz4' ([DateTime]::new(2026, 10, 6, 17, 0, 42, [DateTimeKind]::Utc)) 300), (Oci-Obj 'pg-main/pg-main/wals/00000002.history' ([DateTime]::new(2026, 10, 1, 0, 0, 0, [DateTimeKind]::Utc)) 50))
# WAL 오브젝트: 지금(UTC)으로부터 $agesMin 분 전(가장 최근 것부터; 나이는 하네스 실행까지의 몇 초가 더해진다). 세그먼트 번호는 $segnos(없으면 199, 198, … = C7, C6, …)
function New-WalObjects([double[]]$agesMin, [int[]]$segnos = @()) {
    $now = [DateTime]::UtcNow; $i = 0
    return @(foreach ($a in $agesMin) { $i++; $n = if ($segnos.Count -ge $i) { $segnos[$i - 1] } else { 200 - $i }; Oci-Obj (Wal-Name $n) ($now.AddMinutes(-$a)) })
}
function Oci-Resp([string]$out, [string]$err = '', [int]$code = 0) { return @{ out = $out; err = $err; code = $code } }
# 전부 갖춰진 목록 = base 2 + WAL 세그먼트 5(C7..C3, 2–22분 전) + 세그먼트 아닌 wals/ 오브젝트 2 = 9
function Good-Oci { return (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(2, 7, 12, 17, 22)) + @($walExtraObjs)))) }

# 조회 key 표(가짜 kubectl이 보는 모양 — --kubeconfig · --request-timeout 제거 후). 이름이 $Q인 이유: 함수 안의 foreach ($k …)가 가리지 않게.
$Q = @{
    who     = 'auth whoami -o json'
    cluster = '-n data get clusters.postgresql.cnpg.io pg-main --ignore-not-found -o json'
    pods    = 'get pods -n data -l cnpg.io/cluster=pg-main,cnpg.io/podRole=instance -o json'
    nodes   = 'get nodes -o json'
    dbs     = 'get databases.postgresql.cnpg.io -n data -o json'
    roles   = 'get databaseroles.postgresql.cnpg.io -n data -o json'
    sched   = 'get scheduledbackups.postgresql.cnpg.io -n data -o json'
    backups = 'get backups.postgresql.cnpg.io -n data -o json'
    job     = '-n jt-dev get jobs.batch data-assert --ignore-not-found -o json'
    logs    = '-n jt-dev logs job/data-assert --tail=50'
    depDev  = 'get deployments.apps -n jt-dev -o json'
    depProd = 'get deployments.apps -n jt-prod -o json'
}
# 전부 갖춰진 응답표(T052–T054 · T075 뒤의 모양)
function New-GoodResponses {
    $r = [ordered]@{}
    $r[$Q.who] = R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = $expectedUser } } })
    $r[$Q.cluster] = R-Json (New-Cluster)
    $r[$Q.pods] = R-Json (New-List @(New-Pod 'pg-main-1' 'node-b'))
    $r[$Q.nodes] = R-Json (New-List @((New-Node 'node-a' 'platform'), (New-Node 'node-b' 'data')))
    $r[$Q.dbs] = R-Json (New-List (Good-Dbs))
    $r[$Q.roles] = R-Json (New-List (Good-Roles))
    $r[$Q.sched] = R-Json (New-List @(New-ScheduledBackup))
    $r[$Q.backups] = R-Json (New-List (Good-Backups))
    $r[$Q.job] = R-Json (New-Job)
    $r[$Q.logs] = R-Raw (New-JobLog)
    $r[$Q.depDev] = R-Json (New-List @(New-Deployment 'jt-dev' 'web' @('web-env')))
    $r[$Q.depProd] = R-Json (New-List @(New-Deployment 'jt-prod' 'relay' @() @{ DATABASE_URL = 'relay-env' }))
    return $r
}
# 지금 라이브 모양(T050 시점): CNPG CRD 없음 · 인스턴스 pod 0 · Job 없음 · Deployment 0
function New-LiveResponses {
    $r = New-GoodResponses
    $r[$Q.cluster] = R-NoType 'clusters'
    $r[$Q.pods] = R-Json (New-List @())
    $r[$Q.dbs] = R-NoType 'databases'
    $r[$Q.roles] = R-NoType 'databaseroles'
    $r[$Q.sched] = R-NoType 'scheduledbackups'
    $r[$Q.backups] = R-NoType 'backups'
    $r[$Q.job] = R-None
    # kubectl stderr에 kubeconfig 경로가 섞여 돌아오는 모양({KUBECONFIG} = 픽스처 경로) — 하네스는 <KUBECONFIG>로 가려야 한다(Mask-Text)
    $r[$Q.logs] = R-Err 'error: error from server (NotFound): jobs.batch "data-assert" not found (kubeconfig {KUBECONFIG})'
    $r[$Q.depDev] = R-Json (New-List @())
    $r[$Q.depProd] = R-Json (New-List @())
    return $r
}
$t075Unchecked = '- [ ] T075 [US6] `apps/identity-admin`: first pod Deployment (web + relay) in jt-dev'
$t075Checked = '- [X] ' + $t075Unchecked.Substring(6)
# tasks.md 픽스처: 머리 + 잡음 줄 + T075 줄(들). LF.
function New-TasksText([string[]]$t075Lines = @($script:t075Unchecked)) {
    $head = @('# Tasks: fixture (tests/scripts/data-tests.tests.ps1)', '', '## Phase 5: User Story 3', '- [ ] T050 [P] [US3] `tests/platform/data.tests.ps1`', '- [ ] T052 [US3] `platform/cnpg/`', '  - [ ] T075 indented (not the task-line shape)', '- [ ] T0750 another id', '', '## Phase 8: User Story 6')
    return ((@($head) + @($t075Lines) + @('- [ ] T076 [US6] later task', '')) -join "`n")
}

# 기대 문구(설계 D2 · D3 · D5)
$skipEnv = 'until T075 deploys the first pod Deployment (no Deployment in jt-dev/jt-prod; T075 unchecked in tasks.md)'
$crdNote = 'CRD not installed (T052 deploys the CNPG operator and its CRDs)'
$pendingNote = 'the Job does not emit this check id yet -- T054 adds role-attrs and app-session-timeouts to job-data-assert.yaml'
$goodDetail = @{
    'gate-1'   = 'kubectl found'
    'gate-2'   = 'KUBECONFIG set (single existing file)'
    'gate-3'   = "context user is $expectedUser"
    'pg-1'     = "Cluster data/pg-main: status.phase='Cluster in healthy state', spec.instances=1, status.readyInstances=1"
    'pg-2'     = '1 instance pod(s) Running on role=data node(s): pg-main-1'
    'db-1'     = '4 Database objects for cluster pg-main: identity_admin, dev_identity_admin, authentik, openfga (all status.applied=true at the current generation)'
    'db-2'     = 'Database owners: identity_admin=identity_admin_owner, dev_identity_admin=dev_identity_admin_owner, authentik=authentik_owner, openfga=openfga_owner'
    'role-1'   = '6 DatabaseRole objects for cluster pg-main: identity_admin_app, dev_identity_admin_app, identity_admin_owner, dev_identity_admin_owner, authentik_owner, openfga_owner (all status.applied=true at the current generation)'
    'role-2'   = 'DatabaseRole attributes: app roles (identity_admin_app, dev_identity_admin_app) login=true bypassrls!=true superuser!=true createdb/createrole!=true; pod owners (identity_admin_owner, dev_identity_admin_owner) bypassrls=true superuser!=true createdb/createrole!=true; shared owners (authentik_owner, openfga_owner) superuser!=true; all 6 name a passwordSecret (value never read)'
    'backup-1' = "ScheduledBackup pg-main-daily for cluster pg-main: spec.schedule='0 0 17 * * *' (02:00 KST), not suspended"
    'backup-2' = "2 completed Backup(s) for cluster pg-main; latest pg-main-daily-20261006170000 startedAt=$(Fmt-Utc $script:latestStart) stoppedAt=$(Fmt-Utc $script:latestStop) (UTC; latest within 25h)"
    'bucket-1' = '2 base backup object(s) under joshuatech-backup/pg-main/pg-main/base/ (e.g. pg-main/pg-main/base/20261006T170003/backup.info; 9 objects total); latest completed Backup pg-main-daily-20261006170000 backupId=20261006T170003 has 2 object(s)'
    'job-1'    = 'Job jt-dev/data-assert succeeded (status.succeeded=1, failed=0)'
    'job-2'    = 'Job jt-dev/data-assert log: RESULT PASS for all 6 check ids (pg-cross-db-denied, catalog-connect-false, revoke-public, ssl-verify-full, role-attrs, app-session-timeouts); SUMMARY pass=8 fail=0 (EVIDENCE lines not copied)'
    'env-1'    = "2 Deployment(s) in jt-dev/jt-prod reference no '*-migrate' Secret (envFrom.secretRef, env.valueFrom.secretKeyRef, volumes.secret/projected; containers and initContainers): jt-dev/web, jt-prod/relay"
}
$allIds = @('gate-1', 'gate-2', 'gate-3', 'pg-1', 'pg-2', 'db-1', 'db-2', 'role-1', 'role-2', 'backup-1', 'backup-2', 'bucket-1', 'bucket-2', 'job-1', 'job-2', 'env-1')
# bucket-1 PASS 문구는 목록의 오브젝트 총수에 따라 달라진다(base 2 + WAL n [+ 세그먼트 아닌 wals/ 오브젝트])
function Bucket1Detail([int]$total) { return "2 base backup object(s) under joshuatech-backup/pg-main/pg-main/base/ (e.g. pg-main/pg-main/base/20261006T170003/backup.info; $total objects total); latest completed Backup pg-main-daily-20261006170000 backupId=20261006T170003 has 2 object(s)" }
# bucket-2 PASS 문구(신선 가지)의 고정 부분: Good-Oci의 세그먼트 5개(C7..C3) 가운데 최신 3개가 연속 · 최신 C7의 나이는 실행마다 다르다
$bucket2FreshPrefix = 'joshuatech-backup/pg-main/pg-main/wals/: 5 WAL segment object(s); newest 3 WAL segments contiguous (timeline 1): 0000000100000000000000C7.lz4, 0000000100000000000000C6.lz4, 0000000100000000000000C5.lz4; newest segment 0000000100000000000000C7.lz4 is '
$bucket2FreshSuffix = 's old (<= 900s)'

# ---------- 픽스처 ----------
function New-Fixture($responses, $tasksText, $oci, [hashtable]$extraFiles = @{}, [bool]$withOci = $true) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('datatest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($sub in @('bin', 'tmp', 'resp', 'oci-resp', 'repo/tests/platform', 'repo/specs/003-platform-foundation')) { New-Item -ItemType Directory -Path (Join-Path $dir $sub) -Force | Out-Null }
    $tsv = [Text.StringBuilder]::new(); $n = 0
    $kcPath = Join-Path $dir 'kubeconfig.yaml'   # 응답 본문의 {KUBECONFIG} 자리표시자 = 이 픽스처의 kubeconfig 경로(하네스가 <KUBECONFIG>로 가려야 한다)
    foreach ($k in @($responses.Keys)) {
        $n++; $v = $responses[$k]; $ks = [string]$k
        if ($ks.IndexOf([char]9) -ge 0 -or $ks.IndexOf([char]10) -ge 0 -or $ks.IndexOf([char]13) -ge 0) { throw "fixture key contains a tab or a line break: $ks" }
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.out"), ([string]$v.out).Replace('{KUBECONFIG}', $kcPath), $utf8)
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.err"), ([string]$v.err).Replace('{KUBECONFIG}', $kcPath), $utf8)
        [void]$tsv.Append("$n`t$([int]$v.code)`t$ks`n")
    }
    [IO.File]::WriteAllText((Join-Path $dir 'responses.tsv'), $tsv.ToString(), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'kubeconfig.yaml'), "apiVersion: v1`nkind: Config`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/kubectl.cmd'), (New-Shim 'FAKE_KUBECTL_ARGV' 'fake-kubectl.ps1'), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-kubectl.ps1'), $fakeKubectl, $utf8)
    if ($withOci) {
        [IO.File]::WriteAllText((Join-Path $dir 'bin/oci.cmd'), (New-Shim 'FAKE_OCI_ARGV' 'fake-oci.ps1'), $utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-oci.ps1'), $fakeOci, $utf8)
        if ($null -eq $oci) { $oci = Good-Oci }
        [IO.File]::WriteAllText((Join-Path $dir 'oci-resp/out.txt'), [string]$oci.out, $utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'oci-resp/err.txt'), [string]$oci.err, $utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'oci-resp/code.txt'), "$([int]$oci.code)", $utf8)
    }
    if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { Copy-Item -LiteralPath $harnessPath -Destination (Join-Path $dir 'repo/tests/platform/data.tests.ps1') }
    if ($null -ne $tasksText) { [IO.File]::WriteAllText((Join-Path $dir $tasksRel), [string]$tasksText, $utf8) }
    foreach ($rel in @($extraFiles.Keys)) { [IO.File]::WriteAllText((Join-Path $dir $rel), [string]$extraFiles[$rel], $utf8) }
    return $dir
}
# 이 실행이 만든 datatest-* 디렉터리만, responses.tsv가 있는지 확인하고 지운다
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('datatest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'responses.tsv') -PathType Leaf)) {
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
function Invoke-Harness([string]$dir, [string[]]$harnessArgs = @(), [bool]$withOci = $true, [int]$timeoutSec = 180) {
    $h = Join-Path $dir 'repo/tests/platform/data.tests.ps1'
    if (-not (Test-Path -LiteralPath $h -PathType Leaf)) { return @{ out = "<missing harness: $harnessPath>"; err = ''; code = 127; wall = 0.0; timedOut = $false } }
    $bin = Join-Path $dir 'bin'
    $childPath = $bin + $sep + $script:safePath
    # 실행마다 확인: 처음 찾히는 kubectl = 픽스처 심, oci = 픽스처 심(심을 두지 않은 케이스면 없음) — 실제 클러스터 · OCI 세션에 닿지 않게
    $first = Find-FirstCommand $childPath 'kubectl'
    if (-not [string]::Equals($first, (Join-Path $bin 'kubectl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first kubectl on the child PATH is '$first', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    $firstOci = Find-FirstCommand $childPath 'oci'
    if ($withOci) {
        if (-not [string]::Equals($firstOci, (Join-Path $bin 'oci.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first oci on the child PATH is '$firstOci', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    } elseif ($null -ne $firstOci) { return @{ out = "<refusing to run: 'oci' is reachable on the child PATH ($firstOci)>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
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

# ---------- 결과 · 호출 기록 도우미 ----------
function Get-Lines($r) { return @(($r.out.TrimEnd("`n")) -split "`n") }
function Format-Result($r) {
    $lines = @(Get-Lines $r)
    $tail = if ($lines.Count -gt 18) { @('...') + $lines[($lines.Count - 18)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
}
function Get-Summary($r) { $l = @(Get-Lines $r); if ($l.Count -eq 0) { return '' }; return [string]$l[$l.Count - 1] }
# id의 결과 줄('PASS|FAIL|SKIP <id>: <detail>') → @{ n = 줄 수; status; detail; line }
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
# 지정한 ID 밖의 모든 ID가 PASS이고 문구가 전부 갖춰진 픽스처의 PASS 문구와 같다(bucket-2는 시각이 달라져 접두만 본다).
#   $override: 그 케이스의 픽스처가 달라 PASS 문구가 바뀌는 ID → 기대 문구(예: OCI 목록의 오브젝트 수가 다른 bucket-1)
function Assert-OthersPass([string]$name, $r, [string[]]$except, [hashtable]$override = @{}) {
    $bad = @()
    foreach ($id in $allIds) {
        if (In-Set $except $id) { continue }
        $x = Get-IdResult $r $id
        if ($x.n -ne 1 -or -not (Test-Same $x.status 'PASS')) { $bad += "$id=[$($x.line)]"; continue }
        $want = if ($override.ContainsKey($id)) { [string]$override[$id] } else { [string]$goodDetail[$id] }
        if (Test-Same $id 'bucket-2') { if (-not $x.detail.StartsWith($bucket2FreshPrefix, [StringComparison]::Ordinal) -or -not $x.detail.EndsWith($bucket2FreshSuffix, [StringComparison]::Ordinal)) { $bad += "$id=[$($x.line)]" } }
        elseif (-not (Test-Same $x.detail $want)) { $bad += "$id=[$($x.line)] (expected [$want])" }
    }
    Assert $name ($bad.Count -eq 0) ($bad -join ' || ')
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
function Get-OciCalls([string]$dir) {
    $p = Join-Path $dir 'oci-calls.log'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @() }
    return @(foreach ($l in [IO.File]::ReadAllLines($p)) { if ($l.Trim().Length -gt 0) { , @($l.Split([char[]]@([char]9))) } })
}
function Format-Calls($calls) { return 'calls=[' + ((@(@($calls) | ForEach-Object { "$($_['served']):$($_['key'])" })) -join ' | ') + ']' }
function Count-Key($calls, [string]$key) { return @(@($calls) | Where-Object { Test-Same ([string]$_['key']) $key }).Count }
# 읽기 전용 동사만: get · auth whoami · -n <ns> get|logs
function Test-ReadOnlyKey([string]$key) {
    $t = @($key.Split(' '))
    if ($t.Count -ge 1 -and (Test-Same $t[0] 'get')) { return $true }
    if ($t.Count -ge 2 -and (Test-Same $t[0] 'auth') -and (Test-Same $t[1] 'whoami')) { return $true }
    if ($t.Count -ge 3 -and (Test-Same $t[0] '-n') -and ((Test-Same $t[2] 'get') -or (Test-Same $t[2] 'logs'))) { return $true }
    return $false
}
$ociMutatingVerbs = @('put', 'delete', 'bulk-upload', 'bulk-delete', 'copy', 'rename', 'update', 'create', 'restore', 'reencrypt', 'sync', 'resume', 'head')
# 인자 배열에서 연속 토큰 열을 찾는다(ordinal)
function Has-Seq([string[]]$argv, [string[]]$seq) {
    for ($i = 0; $i -le $argv.Count - $seq.Count; $i++) {
        $ok = $true
        for ($j = 0; $j -lt $seq.Count; $j++) { if (-not (Test-Same $argv[$i + $j] $seq[$j])) { $ok = $false; break } }
        if ($ok) { return $true }
    }
    return $false
}
# 모든 실행 공통: 끝까지 돌았다(마지막 줄 = 요약) · 읽기 전용 동사만 · 응답표 밖 호출 0 · 모든 호출이 픽스처 kubeconfig를 --kubeconfig로 명시 ·
#   EVIDENCE 마커가 출력에 없다 · 픽스처 tmp/에 잔존 파일 0 · (oci 심이 있으면) oci 호출 정확히 1번 · 읽기 전용 인자
function Assert-Run([string]$id, $r, [string]$dir, [bool]$withOci = $true) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    Assert "${id}-end: harness ran to completion (no timeout; last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and [regex]::IsMatch($last, '\A\d+ passed, \d+ failed, \d+ skipped\z')) (Format-Result $r)
    $calls = @(Get-Calls $dir)
    $notRo = @($calls | Where-Object { -not (Test-ReadOnlyKey ([string]$_['key'])) })
    Assert "${id}-ro: every kubectl call used a read-only verb (get / auth whoami / logs)" ($calls.Count -gt 0 -and $notRo.Count -eq 0) "calls=$($calls.Count) :: not read-only: $((@($notRo | ForEach-Object { $_['key'] })) -join ' || ')"
    $unserved = @($calls | Where-Object { Test-Same ([string]$_['served']) 'default' })
    Assert "${id}-served: every kubectl call matched a fixture response (no call outside the scenario)" ($unserved.Count -eq 0) "outside: $((@($unserved | ForEach-Object { $_['key'] })) -join ' || ')"
    $kc = Join-Path $dir 'kubeconfig.yaml'
    $badKc = @($calls | Where-Object { -not [string]::Equals([string]$_['kubeconfig'], $kc, [StringComparison]::OrdinalIgnoreCase) })
    Assert "${id}-kc: every kubectl call named the fixture kubeconfig explicitly (--kubeconfig)" ($badKc.Count -eq 0) "without it: $((@($badKc | ForEach-Object { $_['key'] })) -join ' || ')"
    Assert "${id}-evidence: the EVIDENCE marker from the Job log never appears in the harness output" (-not (Has-Text $r.out $evidenceMarker)) (Format-Result $r)
    $left = @(Get-ChildItem -LiteralPath (Join-Path $dir 'tmp') -File -Recurse -ErrorAction SilentlyContinue)
    Assert "${id}-tmp: no temp file left in the fixture tmp/ (data-tests-* stderr/oci redirects are removed)" ($left.Count -eq 0) "left: $((@($left | ForEach-Object { $_.Name })) -join ', ')"
    if ($withOci) {
        $oc = @(Get-OciCalls $dir)
        $bad = @()
        if ($oc.Count -ne 1) { $bad += "expected exactly 1 oci call, got $($oc.Count)" }
        foreach ($argv in $oc) {
            $a = @($argv)
            if (-not (Has-Seq $a @('--profile', 'svc-verify'))) { $bad += 'no --profile svc-verify' }
            if (-not (Has-Seq $a @('--auth', 'security_token'))) { $bad += 'no --auth security_token' }
            if (-not (Has-Seq $a @('os', 'object', 'list'))) { $bad += 'not os object list' }
            if (-not (Has-Seq $a @('--bucket-name', 'joshuatech-backup'))) { $bad += 'bucket is not joshuatech-backup' }
            if (-not (Has-Seq $a @('--prefix', 'pg-main/'))) { $bad += 'prefix is not pg-main/' }
            if (-not (In-Set $a '--all')) { $bad += 'no --all' }
            if (-not (Has-Seq $a @('--output', 'json'))) { $bad += 'no --output json' }
            $mut = @($a | Where-Object { In-Set $ociMutatingVerbs $_ })
            if ($mut.Count -gt 0) { $bad += "mutating token(s): $($mut -join ',')" }
        }
        Assert "${id}-oci: exactly 1 oci call, read-only: --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup --prefix pg-main/ --all --output json" ($bad.Count -eq 0) "$($bad -join '; ') :: $((@($oc | ForEach-Object { @($_) -join ' ' })) -join ' || ')"
    }
}

# ---------- 함수 케이스용: 하네스의 최상위 함수 + 몇 개 상수만 동적 모듈에 정의한다(최상위 문장은 실행하지 않는다) ----------
$harnessConsts = @('clusterName', 'dataNs', 'dataObjectsTask', 'clusterTask', 'bucketPrefix', 'serverName', 'basePrefixPath', 'walPrefixPath', 'archivingCondition')
function Import-HarnessModule([string]$path) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "harness does not parse: $(@($errors)[0].Message)" }
    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $consts = @($ast.EndBlock.Statements | Where-Object {
            $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            (In-Set $script:harnessConsts $_.Left.VariablePath.UserPath) })
    $text = ((@($consts | ForEach-Object { $_.Extent.Text }) + @($funcs | ForEach-Object { $_.Extent.Text })) -join "`n") + "`nExport-ModuleMember -Function @()`n"
    return (New-Module -Name ('dataharness-' + [guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($text)))
}
function Test-ModuleHas($mod, [string]$fn) { return [bool](& $mod { param($n) $null -ne (Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue) } $fn) }

try {
    # ================= 전부 갖춰진 픽스처 → 16 PASS =================
    Test-Case 'C01' 'every object in place (post T052-T054/T075 shape) -> all 16 assertions PASS with the exact wording; oci called once, read-only' {
        $d = New-Fixture (New-GoodResponses) (New-TasksText) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C01' $r $d
        Assert 'C01-1: exit 0 and summary "16 passed, 0 failed, 0 skipped"' ($r.code -eq 0 -and (Test-Same (Get-Summary $r) '16 passed, 0 failed, 0 skipped')) (Format-Result $r)
        Assert-OthersPass 'C01-2: every id PASS with the expected detail (bucket-2 by prefix)' $r @()
        $x = Get-IdResult $r 'bucket-2'
        Assert 'C01-3: bucket-2 PASS reports 5 WAL segments (label/history files not counted), the newest 3 contiguous by number, the newest a few minutes old (fresh branch)' ($x.n -eq 1 -and (Test-Same $x.status 'PASS') -and [regex]::IsMatch($x.detail, '\Ajoshuatech-backup/pg-main/pg-main/wals/: 5 WAL segment object\(s\); newest 3 WAL segments contiguous \(timeline 1\): 0000000100000000000000C7\.lz4, 0000000100000000000000C6\.lz4, 0000000100000000000000C5\.lz4; newest segment 0000000100000000000000C7\.lz4 is 1[2-9]\ds old \(<= 900s\)\z')) "line=[$($x.line)]"
        $calls = @(Get-Calls $d)
        Assert 'C01-4: 12 kubectl calls, each list fetched once (whoami, Cluster, pods, nodes, databases, databaseroles, scheduledbackups, backups, Job, logs, deployments x2)' ($calls.Count -eq 12 -and @(@($Q.Values) | Where-Object { (Count-Key $calls $_) -ne 1 }).Count -eq 0) (Format-Calls $calls)
    }

    # ================= 지금 라이브 모양 → 12 FAIL + env-1 SKIP(격리) =================
    Test-Case 'C02' 'live-like state (no CNPG CRD, no instance pod, no Job, empty bucket, no Deployment) -> pg/db/role/backup/bucket/job FAIL with their own reasons (owner task named), env-1 SKIP' {
        $d = New-Fixture (New-LiveResponses) (New-TasksText) (Oci-Resp (New-OciListing @()))
        $r = Invoke-Harness $d
        Assert-Run 'C02' $r $d
        Assert 'C02-1: exit 1 and summary "3 passed, 12 failed, 1 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '3 passed, 12 failed, 1 skipped')) (Format-Result $r)
        Assert-Id 'C02-2: pg-1 FAIL -- Cluster lookup: CRD not installed (T052), kubectl text kept' $r 'pg-1' 'FAIL' @("Cluster data/pg-main lookup failed: $crdNote", 'resource type "clusters"') @('unhandled')
        Assert-Id 'C02-3: pg-2 FAIL -- no instance pod (T053 named)' $r 'pg-2' 'FAIL' @('no instance pod with labels cnpg.io/cluster=pg-main,cnpg.io/podRole=instance in ns data (T053 deploys Cluster pg-main)')
        Assert-Id 'C02-4: db-1 FAIL -- Database list: CRD not installed (T052)' $r 'db-1' 'FAIL' @("Database list in ns data lookup failed: $crdNote", 'resource type "databases"') @('unhandled')
        Assert-Id 'C02-5: db-2 FAIL -- same reason (the failed list is cached, not re-fetched)' $r 'db-2' 'FAIL' @("Database list in ns data lookup failed: $crdNote")
        Assert-Id 'C02-6: role-1 FAIL -- DatabaseRole list: CRD not installed (T052)' $r 'role-1' 'FAIL' @("DatabaseRole list in ns data lookup failed: $crdNote", 'resource type "databaseroles"')
        Assert-Id 'C02-7: role-2 FAIL -- same reason' $r 'role-2' 'FAIL' @("DatabaseRole list in ns data lookup failed: $crdNote")
        Assert-Id 'C02-8: backup-1 FAIL -- ScheduledBackup list: CRD not installed (T052)' $r 'backup-1' 'FAIL' @("ScheduledBackup list in ns data lookup failed: $crdNote")
        Assert-Id 'C02-9: backup-2 FAIL -- Backup list: CRD not installed (T052)' $r 'backup-2' 'FAIL' @("Backup list in ns data lookup failed: $crdNote")
        Assert-IdExact 'C02-10: bucket-1 FAIL -- 0 objects (empty listing is not evidence; T053 owns the first backup)' $r 'bucket-1' 'FAIL' '0 objects under joshuatech-backup/pg-main/ (empty listing is not evidence; the first ScheduledBackup run fills it -- T053)'
        Assert-Id 'C02-11: bucket-2 FAIL -- 0 WAL segment objects' $r 'bucket-2' 'FAIL' @('joshuatech-backup/pg-main/pg-main/wals/: only 0 WAL segment object(s)', 'need >= 3 to check archive contiguity')
        Assert-IdExact 'C02-12: job-1 FAIL -- Job not found' $r 'job-1' 'FAIL' 'Job jt-dev/data-assert not found (assert Job from platform/policies/tests is not deployed yet)'
        Assert-Id 'C02-13: job-2 FAIL -- kubectl logs failed with the NotFound text (first line only)' $r 'job-2' 'FAIL' @('kubectl -n jt-dev logs job/data-assert --tail=50 failed (exit 1): error: error from server (NotFound): jobs.batch "data-assert" not found')
        Assert-IdExact 'C02-14: env-1 SKIP with the D3 text (no Deployment, T075 unchecked)' $r 'env-1' 'SKIP' $skipEnv
        $calls = @(Get-Calls $d)
        Assert 'C02-15: each failing list was fetched once (failures are cached too) and every call is on the fixture table' (@(@($Q.dbs, $Q.roles, $Q.sched, $Q.backups, $Q.cluster) | Where-Object { (Count-Key $calls $_) -ne 1 }).Count -eq 0) (Format-Calls $calls)
        Assert-Id 'C02-16: a kubeconfig path echoed by kubectl is masked as <KUBECONFIG> in the job-2 reason (Mask-Text)' $r 'job-2' 'FAIL' @('not found (kubeconfig <KUBECONFIG>)') @('kubeconfig.yaml')
        Assert 'C02-17: the fixture kubeconfig path never appears in the harness output' (-not (Has-Text $r.out (Join-Path $d 'kubeconfig.yaml')) -and -not (Has-Text $r.out ((Join-Path $d 'kubeconfig.yaml').Replace('\', '/')))) (Format-Result $r)
    }

    # ================= 개별 ID(집합 · owner · role · schedule · completed · base · Job failed · -migrate) =================
    Test-Case 'C03' 'extra Database / extra DatabaseRole / wrong schedule / no completed Backup / no base object / Job failed / -migrate envFrom -> only db-1, role-1, backup-1, backup-2, bucket-1, job-1, env-1 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.dbs] = R-Json (New-List (@(Good-Dbs) + @(New-Database 'scratch' 'scratch_owner')))
        $resp[$Q.roles] = R-Json (New-List (@(Good-Roles) + @(Role-App 'reporting_ro')))
        $resp[$Q.sched] = R-Json (New-List @(New-ScheduledBackup 'pg-main-daily' '0 0 2 * * *'))
        $resp[$Q.backups] = R-Json (New-List @((New-Backup 'pg-main-daily-20261005170000' 'failed' '2026-10-05T17:00:02Z' ''), (New-Backup 'pg-main-daily-20261006170000' 'running' '2026-10-06T17:00:03Z' '')))
        $resp[$Q.job] = R-Json (New-Job 'data-assert' $null 1 $null)
        $resp[$Q.depDev] = R-Json (New-List @(New-Deployment 'jt-dev' 'web' @('web-env', 'web-migrate')))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (New-WalObjects @(2, 7, 12, 17, 22))))
        $r = Invoke-Harness $d
        Assert-Run 'C03' $r $d
        Assert-IdExact 'C03-1: db-1 FAIL names the unexpected Database' $r 'db-1' 'FAIL' 'Database set for cluster pg-main: unexpected (not in the SP-1 set): scratch'
        Assert-IdExact 'C03-2: role-1 FAIL names the unexpected DatabaseRole' $r 'role-1' 'FAIL' 'DatabaseRole set for cluster pg-main: unexpected (not in the SP-1 set): reporting_ro'
        Assert-IdExact 'C03-3: backup-1 FAIL -- schedule differs' $r 'backup-1' 'FAIL' "ScheduledBackup pg-main-daily: spec.schedule='0 0 2 * * *' (expected '0 0 17 * * *')"
        Assert-IdExact 'C03-4: backup-2 FAIL -- 0 completed, phases listed' $r 'backup-2' 'FAIL' '0 completed Backup(s) for cluster pg-main (2 Backup objects: pg-main-daily-20261005170000=failed, pg-main-daily-20261006170000=running)'
        Assert-IdExact 'C03-5: bucket-1 FAIL -- WAL objects only, nothing under pg-main/pg-main/base/' $r 'bucket-1' 'FAIL' 'no object under joshuatech-backup/pg-main/pg-main/base/ (5 objects total)'
        Assert-IdExact 'C03-6: job-1 FAIL -- Job failed (failed=1, succeeded=0)' $r 'job-1' 'FAIL' 'Job jt-dev/data-assert has a failed attempt (status.failed=1, succeeded=0; backoffLimit 0 means a failure is evidence) -- read its RESULT lines in job-2'
        Assert-IdExact 'C03-7: env-1 FAIL names the -migrate envFrom reference' $r 'env-1' 'FAIL' "1 Secret reference(s) ending in '-migrate' in runtime Deployments (owner credentials belong to the PreSync migrate Job only): jt-dev/web containers[web] envFrom.secretRef=web-migrate"
        Assert-OthersPass 'C03-8: every other id PASS unchanged (db-2, role-2, bucket-2, job-2, pg-*, gates)' $r @('db-1', 'role-1', 'backup-1', 'backup-2', 'bucket-1', 'job-1', 'env-1')
        Assert 'C03-9: exit 1, summary "9 passed, 7 failed, 0 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '9 passed, 7 failed, 0 skipped')) (Format-Result $r)
    }
    Test-Case 'C04' 'missing Database + wrong owner / app role bypassrls+createrole=true + owner without bypassrls / WAL segment C6 missing / RESULT id missing -> db-1, db-2, role-2, bucket-2, job-2 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.dbs] = R-Json (New-List @((New-Database 'identity_admin' 'identity_admin_owner'), (New-Database 'dev_identity_admin' 'dev_identity_admin_owner'), (New-Database 'authentik' 'postgres')))
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app' @{ bypassrls = $true; createrole = $true }), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (New-Role 'dev_identity_admin_owner' @{ login = $true; superuser = $false }), (Role-Shared 'authentik_owner'), (Role-Shared 'openfga_owner')))
        $resp[$Q.logs] = R-Raw (New-JobLog @{} @('ssl-verify-full'))
        # 세그먼트 C7, C5, C4, C3(C6 없음) — 업로드 시각이 촘촘해도 번호가 끊기면 아카이브 누락이다
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(2, 7, 12, 17) @(199, 197, 196, 195)))))
        $r = Invoke-Harness $d
        Assert-Run 'C04' $r $d
        Assert-IdExact 'C04-1: db-1 FAIL -- missing openfga (nothing unexpected)' $r 'db-1' 'FAIL' 'Database set for cluster pg-main: missing: openfga'
        Assert-IdExact 'C04-2: db-2 FAIL -- authentik owner differs and openfga is absent' $r 'db-2' 'FAIL' "Database owners: authentik: spec.owner='postgres' (expected 'authentik_owner'); openfga: not found"
        Assert-IdExact 'C04-3: role-2 FAIL -- app role with bypassrls and createrole, owner without bypassrls (role-1 still PASS: 6 names, all applied)' $r 'role-2' 'FAIL' 'DatabaseRole attributes: identity_admin_app: bypassrls must not be true, createrole must not be true; dev_identity_admin_owner: bypassrls must be true'
        Assert-IdExact 'C04-4: bucket-2 FAIL -- C7 is not immediately preceded by C5 (C6 missing)' $r 'bucket-2' 'FAIL' 'joshuatech-backup/pg-main/pg-main/wals/: WAL archive gap: 0000000100000000000000C7.lz4 is not immediately preceded by 0000000100000000000000C5.lz4 (expected 0000000100000000000000C6)'
        Assert-IdExact 'C04-5: job-2 FAIL -- ssl-verify-full RESULT line missing (not a T054-pending id, so no note)' $r 'job-2' 'FAIL' 'Job jt-dev/data-assert log: 1 problem(s): missing RESULT line for ssl-verify-full'
        Assert-OthersPass 'C04-6: every other id PASS unchanged (bucket-1 counts 6 objects in this listing)' $r @('db-1', 'db-2', 'role-2', 'bucket-2', 'job-2') @{ 'bucket-1' = (Bucket1Detail 6) }
    }
    Test-Case 'C05' '5 DatabaseRoles / 2 WAL objects / Job still running / RESULT FAIL id / Cluster not healthy -> role-1, role-2, bucket-2, job-1, job-2, pg-1 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'openfga_owner')))
        $resp[$Q.job] = R-Json (New-Job 'data-assert' $null $null 1)
        $resp[$Q.logs] = R-Raw (New-JobLog @{ 'revoke-public' = 'FAIL' })
        $resp[$Q.cluster] = R-Json (New-Cluster 'Setting up primary')
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(2, 7)))))
        $r = Invoke-Harness $d
        Assert-Run 'C05' $r $d
        Assert-IdExact 'C05-1: role-1 FAIL -- missing authentik_owner' $r 'role-1' 'FAIL' 'DatabaseRole set for cluster pg-main: missing: authentik_owner'
        Assert-IdExact 'C05-2: role-2 FAIL -- authentik_owner not found (attributes of the other five are fine)' $r 'role-2' 'FAIL' 'DatabaseRole attributes: authentik_owner: not found'
        Assert-IdExact 'C05-3: bucket-2 FAIL -- only 2 WAL segment objects' $r 'bucket-2' 'FAIL' 'joshuatech-backup/pg-main/pg-main/wals/: only 2 WAL segment object(s) (<16hex>/<24hex>[.gz|.bz2|.lz4|.zst|.snappy|.xz] under the wals/ prefix; .backup/.history/.partial files excluded); need >= 3 to check archive contiguity'
        Assert-IdExact 'C05-4: job-1 FAIL -- still running' $r 'job-1' 'FAIL' 'Job jt-dev/data-assert still running (status.active=1, succeeded=0)'
        Assert-IdExact 'C05-5: job-2 FAIL -- RESULT FAIL for revoke-public and SUMMARY fail=1' $r 'job-2' 'FAIL' 'Job jt-dev/data-assert log: 2 problem(s): RESULT FAIL for revoke-public; SUMMARY fail=1 (expected 0; pass=7)'
        Assert-IdExact 'C05-6: pg-1 FAIL -- phase differs' $r 'pg-1' 'FAIL' "Cluster data/pg-main: status.phase='Setting up primary' (expected 'Cluster in healthy state')"
        Assert-OthersPass 'C05-7: every other id PASS unchanged (bucket-1 still PASS from the same 4-object listing)' $r @('role-1', 'role-2', 'bucket-2', 'job-1', 'job-2', 'pg-1') @{ 'bucket-1' = (Bucket1Detail 4) }
    }
    Test-Case 'C06' 'newest WAL 20 min old with no ContinuousArchiving condition / duplicate RESULT id / T075 checked + 0 Deployment / pod on the platform node / Database not applied / DatabaseRole without status -> bucket-2, job-2, env-1, pg-2, db-1, role-1 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.logs] = R-Raw (New-JobLog @{} @() @('catalog-connect-false'))
        $resp[$Q.depDev] = R-Json (New-List @()); $resp[$Q.depProd] = R-Json (New-List @())
        $resp[$Q.pods] = R-Json (New-List @(New-Pod 'pg-main-1' 'node-a'))
        $resp[$Q.dbs] = R-Json (New-List @((New-Database 'identity_admin' 'identity_admin_owner'), (New-Database 'dev_identity_admin' 'dev_identity_admin_owner'), (New-Database 'authentik' 'authentik_owner'), (New-Database 'openfga' 'openfga_owner' $false)))
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'authentik_owner'), (New-Role 'openfga_owner' @{ login = $true; superuser = $false } 'absent')))
        $d = New-Fixture $resp (New-TasksText @($t075Checked)) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(20, 25, 30)))))
        $r = Invoke-Harness $d
        Assert-Run 'C06' $r $d
        Assert-Id 'C06-1: bucket-2 FAIL -- newest segment about 1200s old (> 900s) and the Cluster has no ContinuousArchiving condition (segments contiguous)' $r 'bucket-2' 'FAIL' @('joshuatech-backup/pg-main/pg-main/wals/: newest WAL segment 0000000100000000000000C7.lz4 is 12', 's old (> 900s) and the idle-safe evidence does not hold: Cluster data/pg-main has no ContinuousArchiving condition') @('gap')
        Assert-IdExact 'C06-2: job-2 FAIL -- catalog-connect-false appears twice' $r 'job-2' 'FAIL' 'Job jt-dev/data-assert log: 1 problem(s): 2 RESULT lines for catalog-connect-false (expected exactly 1)'
        Assert-IdExact 'C06-3: env-1 FAIL -- "- [X] T075" with no Deployment is the post-US6 empty state (never SKIP)' $r 'env-1' 'FAIL' 'T075 is checked in tasks.md but no Deployment in jt-dev/jt-prod'
        Assert-IdExact 'C06-4: pg-2 FAIL -- the instance pod sits on the role=platform node (node name not printed)' $r 'pg-2' 'FAIL' "pod pg-main-1: node label role='platform' (expected 'data')"
        Assert-IdExact 'C06-5: db-1 FAIL -- openfga status.applied=false' $r 'db-1' 'FAIL' "Database set for cluster pg-main: not applied: openfga(status.applied='False')"
        Assert-IdExact 'C06-6: role-1 FAIL -- openfga_owner has no status at all (not applied, and no observedGeneration = stale)' $r 'role-1' 'FAIL' "DatabaseRole set for cluster pg-main: not applied: openfga_owner(status.applied=''); status stale: openfga_owner(generation=1 observedGeneration='')"
        Assert 'C06-7: pg-2 FAIL line does not contain the node name' (-not (Has-Text (Get-IdResult $r 'pg-2').line 'node-a')) (Get-IdResult $r 'pg-2').line
        Assert-OthersPass 'C06-8: every other id PASS unchanged (db-2 and role-2 are unaffected by status.applied; bucket-1 counts 5 objects)' $r @('bucket-2', 'job-2', 'env-1', 'pg-2', 'db-1', 'role-1') @{ 'bucket-1' = (Bucket1Detail 5) }
    }
    Test-Case 'C07' 'no SUMMARY line / tasks.md missing + 0 Deployment / OCI session expired / two ScheduledBackups / shared owner superuser + missing passwordSecret -> job-2, env-1, bucket-1, bucket-2, backup-1, role-2 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.logs] = R-Raw (New-JobLog @{} @() @() $null)
        $resp[$Q.depDev] = R-Json (New-List @()); $resp[$Q.depProd] = R-Json (New-List @())
        $resp[$Q.sched] = R-Json (New-List @((New-ScheduledBackup 'pg-main-daily'), (New-ScheduledBackup 'pg-main-weekly' '0 0 17 * * 0')))
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'authentik_owner' @{ superuser = $true }), (Role-Shared 'openfga_owner' @{} '')))
        $expired = "ERROR: This CLI session has expired. Do you want to re-authenticate? [Y/n]:  Aborted!`n"
        $d = New-Fixture $resp $null (Oci-Resp '' $expired 1)
        $r = Invoke-Harness $d
        Assert-Run 'C07' $r $d
        Assert-IdExact 'C07-1: job-2 FAIL -- no SUMMARY line' $r 'job-2' 'FAIL' 'Job jt-dev/data-assert log: 1 problem(s): no SUMMARY line (expected "SUMMARY: pass=<n> fail=<n>")'
        Assert-Id 'C07-2: env-1 FAIL (not SKIP) -- tasks.md is missing' $r 'env-1' 'FAIL' @('no Deployment in jt-dev/jt-prod and the state of T075 is unknown: tasks.md is not a readable file') @('until T075')
        $sessionText = 'oci os object list --bucket-name joshuatech-backup --prefix pg-main/ failed (exit 1): ERROR: This CLI session has expired. Do you want to re-authenticate? [Y/n]:  Aborted!'
        Assert-IdExact 'C07-3: bucket-1 FAIL -- the expired-session first line' $r 'bucket-1' 'FAIL' $sessionText
        Assert-IdExact 'C07-4: bucket-2 FAIL -- same reason (one oci call for both)' $r 'bucket-2' 'FAIL' $sessionText
        Assert-IdExact 'C07-5: backup-1 FAIL -- two ScheduledBackups' $r 'backup-1' 'FAIL' 'expected exactly 1 ScheduledBackup for cluster pg-main, got 2: pg-main-daily, pg-main-weekly'
        Assert-IdExact 'C07-6: role-2 FAIL -- shared owner superuser / no passwordSecret' $r 'role-2' 'FAIL' 'DatabaseRole attributes: authentik_owner: superuser must not be true; openfga_owner: passwordSecret.name is empty'
        Assert-OthersPass 'C07-7: every other id PASS unchanged' $r @('job-2', 'env-1', 'bucket-1', 'bucket-2', 'backup-1', 'role-2')
    }
    Test-Case 'C08' 'SUMMARY fail=1 with all RESULT PASS / readyInstances 0 / pod Pending / Backup+ScheduledBackup of another cluster / -migrate secretKeyRef in initContainer / OCI output not JSON -> job-2, pg-1, pg-2, backup-2, backup-1, env-1, bucket-1, bucket-2 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.logs] = R-Raw (New-JobLog @{} @() @() 'SUMMARY: pass=8 fail=1')
        $resp[$Q.cluster] = R-Json (New-Cluster 'Cluster in healthy state' 1 0)
        $resp[$Q.pods] = R-Json (New-List @(New-Pod 'pg-main-1' 'node-b' 'Pending'))
        $resp[$Q.backups] = R-Json (New-List @(New-Backup 'other-daily-1' 'completed' '2026-10-06T17:00:03Z' '2026-10-06T17:00:41Z' 'other'))
        $resp[$Q.sched] = R-Json (New-List @(New-ScheduledBackup 'other-daily' '0 0 17 * * *' 'other'))
        $resp[$Q.depProd] = R-Json (New-List @(New-Deployment 'jt-prod' 'relay' @() @{ DATABASE_URL = 'relay-env' } @{ OWNER_URL = 'relay-migrate' }))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp 'garbage')
        $r = Invoke-Harness $d
        Assert-Run 'C08' $r $d
        Assert-IdExact 'C08-1: job-2 FAIL -- SUMMARY fail=1 even though every RESULT is PASS (and the counts disagree with the RESULT lines)' $r 'job-2' 'FAIL' 'Job jt-dev/data-assert log: 2 problem(s): SUMMARY fail=1 (expected 0; pass=8); SUMMARY pass=8 fail=1 does not match the RESULT lines (PASS 8, FAIL 0) -- output may be truncated by --tail=50'
        Assert-IdExact 'C08-2: pg-1 FAIL -- readyInstances 0' $r 'pg-1' 'FAIL' "Cluster data/pg-main: status.readyInstances='0' (expected 1)"
        Assert-IdExact 'C08-3: pg-2 FAIL -- pod Pending' $r 'pg-2' 'FAIL' "pod pg-main-1: phase 'Pending' (expected Running)"
        Assert-IdExact 'C08-4: backup-2 FAIL -- the only Backup belongs to another cluster (T053 owns the first run)' $r 'backup-2' 'FAIL' 'no Backup for cluster pg-main in ns data (the first ScheduledBackup run has not happened; T053)'
        Assert-IdExact 'C08-5: backup-1 FAIL -- the only ScheduledBackup belongs to another cluster (T053 deploys it)' $r 'backup-1' 'FAIL' 'no ScheduledBackup for cluster pg-main in ns data (T053 deploys it)'
        Assert-IdExact 'C08-6: env-1 FAIL names the initContainer secretKeyRef' $r 'env-1' 'FAIL' "1 Secret reference(s) ending in '-migrate' in runtime Deployments (owner credentials belong to the PreSync migrate Job only): jt-prod/relay initContainers[migrate-wait] env[OWNER_URL].valueFrom.secretKeyRef=relay-migrate"
        Assert-Id 'C08-7: bucket-1 FAIL -- oci output is not JSON' $r 'bucket-1' 'FAIL' @('JSON parse failed for oci os object list --prefix pg-main/')
        Assert-Id 'C08-8: bucket-2 FAIL -- same reason' $r 'bucket-2' 'FAIL' @('JSON parse failed for oci os object list --prefix pg-main/')
        Assert-OthersPass 'C08-9: every other id PASS unchanged' $r @('job-2', 'pg-1', 'pg-2', 'backup-2', 'backup-1', 'env-1', 'bucket-1', 'bucket-2')
    }

    # ================= D3 게이트 · 매개변수 =================
    Test-Case 'C09' '-TasksMdPath overrides the default tasks.md (default has T075 checked, the override unchecked) -> env-1 SKIP; everything else PASS' {
        $resp = New-GoodResponses
        $resp[$Q.depDev] = R-Json (New-List @()); $resp[$Q.depProd] = R-Json (New-List @())
        $d = New-Fixture $resp (New-TasksText @($t075Checked)) (Good-Oci) @{ 'alt-tasks.md' = (New-TasksText) }
        $r = Invoke-Harness $d @('-TasksMdPath', (Join-Path $d 'alt-tasks.md'))
        Assert-Run 'C09' $r $d
        Assert-IdExact 'C09-1: env-1 SKIP read from -TasksMdPath' $r 'env-1' 'SKIP' $skipEnv
        Assert-OthersPass 'C09-2: every other id PASS' $r @('env-1')
        Assert 'C09-3: exit 0 and summary "15 passed, 0 failed, 1 skipped"' ($r.code -eq 0 -and (Test-Same (Get-Summary $r) '15 passed, 0 failed, 1 skipped')) (Format-Result $r)
    }
    Test-Case 'C10' 'two T075 lines + 0 Deployment -> env-1 FAIL (fail closed, never SKIP); a lowercase "[x]" line counts as checked in the function table (F05)' {
        $resp = New-GoodResponses
        $resp[$Q.depDev] = R-Json (New-List @()); $resp[$Q.depProd] = R-Json (New-List @())
        $d = New-Fixture $resp (New-TasksText @($t075Unchecked, '- [ ] T075 [US6] second copy')) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C10' $r $d
        Assert-Id 'C10-1: env-1 FAIL -- tasks.md has 2 task lines for T075' $r 'env-1' 'FAIL' @('no Deployment in jt-dev/jt-prod and tasks.md has 2 task line(s) for T075') @('until T075')
        Assert-OthersPass 'C10-2: every other id PASS' $r @('env-1')
    }
    Test-Case 'C11' 'oci CLI not on PATH -> bucket-1 and bucket-2 FAIL "oci CLI not found on PATH"; everything else PASS' {
        $d = New-Fixture (New-GoodResponses) (New-TasksText) $null @{} $false
        $r = Invoke-Harness $d @() $false
        Assert-Run 'C11' $r $d $false
        Assert-IdExact 'C11-1: bucket-1 FAIL -- oci missing' $r 'bucket-1' 'FAIL' 'oci CLI not found on PATH'
        Assert-IdExact 'C11-2: bucket-2 FAIL -- oci missing' $r 'bucket-2' 'FAIL' 'oci CLI not found on PATH'
        Assert-OthersPass 'C11-3: every other id PASS' $r @('bucket-1', 'bucket-2')
        Assert 'C11-4: exit 1 and summary "14 passed, 2 failed, 0 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '14 passed, 2 failed, 0 skipped')) (Format-Result $r)
    }
    # ClusterAssert 안전망(D4): 단언 본문이 자기 try/catch 밖에서 예외를 내도(API 스키마상 불가능한 값 — status.succeeded가 문자열) 그 단언만
    #   'unhandled …' FAIL이 되고 나머지 단언과 요약 줄은 그대로 나온다. 변이 M3a(catch { throw })는 이 케이스가 죽인다.
    Test-Case 'C12' 'an assertion body throws outside its own try/catch (Job status.succeeded is not a number) -> ClusterAssert turns it into "unhandled …" FAIL and every other assertion still runs' {
        $resp = New-GoodResponses
        $resp[$Q.job] = R-Json (New-Job 'data-assert' 'lots')
        $d = New-Fixture $resp (New-TasksText) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C12' $r $d
        # 예외 메시지는 OS 로케일을 따른다(한국어 Windows: 값 "lots"을(를) 형식 "System.Int32"(으)로 변환할 수 없습니다) — 로케일에 무관한 조각만 본다
        Assert-Id 'C12-1: job-1 FAIL -- the cast exception is caught by ClusterAssert (reason starts with "unhandled", names the value, the type and the line)' $r 'job-1' 'FAIL' @('unhandled', 'lots', 'System.Int32', '(line ')
        Assert-OthersPass 'C12-2: every other id PASS (the exception did not end the run; job-2 read the log on its own)' $r @('job-1')
        Assert 'C12-3: exit 1 and summary "15 passed, 1 failed, 0 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '15 passed, 1 failed, 0 skipped')) (Format-Result $r)
    }
    # 접근 계약의 핵심 안전장치(gate-3): admin/다른 kubeconfig는 거부되고 클러스터 단언은 하나도 돌지 않는다(kubectl 1회 · oci 0회).
    Test-Case 'C13' 'kubectl auth whoami reports another user -> gate-3 FAIL, every cluster assertion FAIL "cluster unavailable (context user is not agent-view)", exactly 1 kubectl call, oci never called' {
        $resp = New-GoodResponses
        $resp[$Q.who] = R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = 'system:admin' } } })
        $d = New-Fixture $resp (New-TasksText) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C13' $r $d $false
        Assert 'C13-0: oci never called (bucket-1/2 fail closed before the OCI call)' (@(Get-OciCalls $d).Count -eq 0) (Format-Result $r)
        Assert-IdExact 'C13-1: gate-3 FAIL names the refused user' $r 'gate-3' 'FAIL' "context user is 'system:admin', expected $expectedUser (admin/other kubeconfig refused)"
        $bad = @()
        foreach ($id in @($allIds | Where-Object { -not $_.StartsWith('gate-', [StringComparison]::Ordinal) })) { $x = Get-IdResult $r $id; if ($x.n -ne 1 -or -not (Test-Same $x.status 'FAIL') -or -not (Test-Same $x.detail 'cluster unavailable (context user is not agent-view)')) { $bad += "$id=[$($x.line)]" } }
        Assert 'C13-2: all 13 cluster assertions FAIL with "cluster unavailable (context user is not agent-view)" (env-1 never SKIPs)' ($bad.Count -eq 0) ($bad -join ' || ')
        Assert 'C13-3: exactly 1 kubectl call (whoami), exit 1, summary "2 passed, 14 failed, 0 skipped"' (@(Get-Calls $d).Count -eq 1 -and $r.code -eq 1 -and (Test-Same (Get-Summary $r) '2 passed, 14 failed, 0 skipped')) (Format-Result $r)
    }
    Test-Case 'C14' 'Database declared absent / ScheduledBackup suspended / Job with a failed attempt / latest completed Backup 26 h old / a single base object -> db-1, db-2, backup-1, backup-2, job-1 FAIL; bucket-1 PASS printing the whole object name' {
        $resp = New-GoodResponses
        $resp[$Q.dbs] = R-Json (New-List @((New-Database 'identity_admin' 'identity_admin_owner'), (New-Database 'dev_identity_admin' 'dev_identity_admin_owner'), (New-Database 'authentik' 'authentik_owner'), (New-Database 'openfga' 'openfga_owner' $true 'pg-main' 'absent')))
        $resp[$Q.sched] = R-Json (New-List @(New-ScheduledBackup 'pg-main-daily' '0 0 17 * * *' 'pg-main' $true))
        $resp[$Q.job] = R-Json (New-Job 'data-assert' 1 1)
        $old = [DateTime]::UtcNow.AddHours(-26)   # 26 h 전(케이스 시작 기준 — 나이 문구 '26.0h'가 앞선 케이스들의 소요 시간에 흔들리지 않게)
        $resp[$Q.backups] = R-Json (New-List @(New-Backup 'pg-main-daily-old' 'completed' (Fmt-Utc $old.AddSeconds(-38)) (Fmt-Utc $old) 'pg-main' $latestBackupId '0000000100000000000000C0'))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs[0]) + @(New-WalObjects @(2, 7, 12, 17, 22)))))
        $r = Invoke-Harness $d
        Assert-Run 'C14' $r $d
        Assert-IdExact 'C14-1: db-1 FAIL -- openfga is declared absent (not counted as present) and therefore missing' $r 'db-1' 'FAIL' 'Database set for cluster pg-main: declared absent (spec.ensure=absent): openfga; missing: openfga'
        Assert-IdExact 'C14-2: db-2 FAIL -- the absent Database is not a candidate for the owner check' $r 'db-2' 'FAIL' 'Database owners: openfga: not found'
        Assert-IdExact 'C14-3: backup-1 FAIL -- spec.suspend=true' $r 'backup-1' 'FAIL' 'ScheduledBackup pg-main-daily: spec.suspend=true (the schedule never fires)'
        Assert-Id 'C14-4: backup-2 FAIL -- the latest completed Backup is 26 h old (age printed with one decimal)' $r 'backup-2' 'FAIL' @('latest completed Backup pg-main-daily-old stoppedAt=', ' is 26.0h old (> 25h; ScheduledBackup is daily)')
        Assert-IdExact 'C14-5: job-1 FAIL -- failed=1 even though succeeded=1 (backoffLimit 0)' $r 'job-1' 'FAIL' 'Job jt-dev/data-assert has a failed attempt (status.failed=1, succeeded=1; backoffLimit 0 means a failure is evidence) -- read its RESULT lines in job-2'
        Assert-IdExact 'C14-6: bucket-1 PASS -- a single base object is printed whole (not its first character); the 26 h old Backup still cross-checks by backupId' $r 'bucket-1' 'PASS' '1 base backup object(s) under joshuatech-backup/pg-main/pg-main/base/ (e.g. pg-main/pg-main/base/20261006T170003/backup.info; 6 objects total); latest completed Backup pg-main-daily-old backupId=20261006T170003 has 1 object(s)'
        Assert-OthersPass 'C14-7: every other id PASS' $r @('db-1', 'db-2', 'backup-1', 'backup-2', 'job-1', 'bucket-1')
        Assert 'C14-8: exit 1 and summary "11 passed, 5 failed, 0 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '11 passed, 5 failed, 0 skipped')) (Format-Result $r)
    }
    # D3/D4 fail closed: exit 0이지만 목록 모양이 아닌 JSON은 "빈 목록"이 아니라 그 단언의 FAIL이다(env-1의 유일한 SKIP 경로가 모양에 대해 열려 있지 않다)
    Test-Case 'C15' 'exit 0 with the wrong JSON shape (Status object as a list, a List with items: null, a single object as a list, a List without items, a List as the single object, a Pod as the Job) -> env-1 FAIL (never SKIP), backup-1, role-1, role-2, pg-1, job-1 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.depDev] = R-Json ([ordered]@{ kind = 'Status'; apiVersion = 'v1'; metadata = [ordered]@{}; status = 'Failure'; message = 'deployments.apps is forbidden: User "x" cannot list resource "deployments"'; reason = 'Forbidden'; code = 403 })
        $resp[$Q.depProd] = R-Raw '{"apiVersion":"v1","kind":"List","metadata":{"resourceVersion":""},"items":null}'
        $resp[$Q.sched] = R-Json (New-ScheduledBackup)
        $resp[$Q.roles] = R-Json ([ordered]@{ apiVersion = 'v1'; kind = 'List'; metadata = [ordered]@{ resourceVersion = '' } })
        $resp[$Q.cluster] = R-Json (New-List @(New-Cluster))
        $resp[$Q.job] = R-Json (New-Pod 'data-assert-abc12' 'node-a')
        $d = New-Fixture $resp (New-TasksText) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C15' $r $d
        Assert-IdExact 'C15-1: env-1 FAIL -- a Status object (jt-dev) and a List with items: null (jt-prod) where Lists were expected; both reasons, no SKIP' $r 'env-1' 'FAIL' "Deployment list in ns jt-dev lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='Status' items=missing; Deployment list in ns jt-prod lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='List' items=null"
        Assert-IdExact 'C15-2: backup-1 FAIL -- a single ScheduledBackup object where a List was expected' $r 'backup-1' 'FAIL' "ScheduledBackup list in ns data lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='ScheduledBackup' items=missing"
        Assert-IdExact 'C15-3: role-1 FAIL -- a List without an items field' $r 'role-1' 'FAIL' "DatabaseRole list in ns data lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='List' items=missing"
        Assert-IdExact 'C15-4: role-2 FAIL -- the same cached reason' $r 'role-2' 'FAIL' "DatabaseRole list in ns data lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='List' items=missing"
        Assert-IdExact 'C15-5: pg-1 FAIL -- a List where the Cluster object was expected' $r 'pg-1' 'FAIL' "Cluster data/pg-main lookup failed: kubectl get clusters.postgresql.cnpg.io/pg-main returned kind 'List' (expected Cluster)"
        Assert-IdExact 'C15-6: job-1 FAIL -- a Pod where the Job object was expected' $r 'job-1' 'FAIL' "Job jt-dev/data-assert lookup failed: kubectl get jobs.batch/data-assert returned kind 'Pod' (expected Job)"
        Assert-OthersPass 'C15-7: every other id PASS (db-*, pg-2, backup-2, bucket-*, job-2)' $r @('env-1', 'backup-1', 'role-1', 'role-2', 'pg-1', 'job-1')
        Assert 'C15-8: exit 1 and summary "10 passed, 6 failed, 0 skipped" (no SKIP)' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '10 passed, 6 failed, 0 skipped')) (Format-Result $r)
    }
    # 유휴 클러스터: 최신 세그먼트가 오래됐어도 ContinuousArchiving=True + 최신 ≥ endWal이면 PASS; backupId 교차 확인 · observedGeneration은 각각 FAIL
    Test-Case 'C16' 'idle cluster: newest WAL 20 min old but ContinuousArchiving=True and newest >= endWal -> bucket-2 PASS (idle-safe); base objects not under the latest completed backupId -> bucket-1 FAIL; generation != observedGeneration -> db-1, role-1 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.cluster] = R-Json (New-Cluster 'Cluster in healthy state' 1 1 @((Cond 'Ready' 'True'), (Cond 'ContinuousArchiving' 'True')))
        $resp[$Q.backups] = R-Json (New-List @(New-Backup 'pg-main-daily-20261006170000' 'completed' (Fmt-Utc $script:latestStart) (Fmt-Utc $script:latestStop) 'pg-main' '20261007T020000' '0000000100000000000000C5'))
        $resp[$Q.dbs] = R-Json (New-List @((New-Database 'identity_admin' 'identity_admin_owner' $true 'pg-main' 'present' 3 1), (New-Database 'dev_identity_admin' 'dev_identity_admin_owner'), (New-Database 'authentik' 'authentik_owner'), (New-Database 'openfga' 'openfga_owner')))
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (New-Role 'authentik_owner' @{ login = $true; superuser = $false } $true 'pg-main' 'auto' 'present' 2 1), (Role-Shared 'openfga_owner')))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(20, 25, 30)))))
        $r = Invoke-Harness $d
        Assert-Run 'C16' $r $d
        Assert-Id 'C16-1: bucket-2 PASS -- idle-safe branch (ContinuousArchiving=True, newest C7 >= endWal C5) and every segment from endWal C5 up to C7 contiguous' $r 'bucket-2' 'PASS' @('joshuatech-backup/pg-main/pg-main/wals/: 3 WAL segment object(s); newest 3 WAL segments contiguous (timeline 1): 0000000100000000000000C7.lz4, 0000000100000000000000C6.lz4, 0000000100000000000000C5.lz4; newest segment 0000000100000000000000C7.lz4 is 12', 's old (> 900s) but idle-safe: ContinuousArchiving=True and 0000000100000000000000C7 >= endWal 0000000100000000000000C5 of Backup pg-main-daily-20261006170000; all 3 WAL segment(s) from endWal 0000000100000000000000C5 to 0000000100000000000000C7 contiguous (timeline 1)')
        Assert-IdExact 'C16-2: bucket-1 FAIL -- base objects exist but none for the latest completed backupId 20261007T020000' $r 'bucket-1' 'FAIL' '2 base backup object(s) under joshuatech-backup/pg-main/pg-main/base/ but none under pg-main/pg-main/base/20261007T020000/ for the latest completed Backup pg-main-daily-20261006170000 (status.backupId=20261007T020000; e.g. pg-main/pg-main/base/20261006T170003/backup.info)'
        Assert-IdExact 'C16-3: db-1 FAIL -- identity_admin generation 3 vs observedGeneration 1 (stale applied=true)' $r 'db-1' 'FAIL' "Database set for cluster pg-main: status stale: identity_admin(generation=3 observedGeneration='1')"
        Assert-IdExact 'C16-4: role-1 FAIL -- authentik_owner generation 2 vs observedGeneration 1' $r 'role-1' 'FAIL' "DatabaseRole set for cluster pg-main: status stale: authentik_owner(generation=2 observedGeneration='1')"
        Assert-OthersPass 'C16-5: every other id PASS (db-2 and role-2 ignore generation; backup-2 PASS with 1 completed)' $r @('bucket-2', 'bucket-1', 'db-1', 'role-1') @{ 'backup-2' = "1 completed Backup(s) for cluster pg-main; latest pg-main-daily-20261006170000 startedAt=$(Fmt-Utc $script:latestStart) stoppedAt=$(Fmt-Utc $script:latestStop) (UTC; latest within 25h)" }
        $calls = @(Get-Calls $d)
        Assert 'C16-6: the idle branch re-used the cached Cluster and Backup lookups (still 12 kubectl calls, each once)' ($calls.Count -eq 12 -and @(@($Q.Values) | Where-Object { (Count-Key $calls $_) -ne 1 }).Count -eq 0) (Format-Calls $calls)
    }
    Test-Case 'C17' 'only another serverName in the bucket / -migrate Secret mounted as a volume / app role createdb=true / latest completed Backup without timestamps -> bucket-1, bucket-2, env-1, role-2, backup-2 FAIL' {
        $resp = New-GoodResponses
        $resp[$Q.depProd] = R-Json (New-List @(New-Deployment 'jt-prod' 'relay' @() @{ DATABASE_URL = 'relay-env' } @{} @('relay-migrate')))
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app' @{ createdb = $true }), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'authentik_owner'), (Role-Shared 'openfga_owner')))
        $resp[$Q.backups] = R-Json (New-List @(New-Backup 'pg-main-daily-x' 'completed' '' '' 'pg-main' $latestBackupId))
        $old = [DateTime]::new(2025, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        # 이전 세대 클러스터(serverName pg-old)의 오브젝트만 — base/와 wals/ 세그먼트 3개가 있어도 pg-main의 근거가 아니다
        $listing = @((Oci-Obj 'pg-main/pg-old/base/20250101T000000/backup.info' $old), (Oci-Obj 'pg-main/pg-old/wals/0000000100000000/000000010000000000000003.lz4' $old), (Oci-Obj 'pg-main/pg-old/wals/0000000100000000/000000010000000000000004.lz4' $old), (Oci-Obj 'pg-main/pg-old/wals/0000000100000000/000000010000000000000005.lz4' ([DateTime]::UtcNow)))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing $listing))
        $r = Invoke-Harness $d
        Assert-Run 'C17' $r $d
        Assert-IdExact 'C17-1: bucket-1 FAIL -- pg-main/pg-old/base/ is not pg-main/pg-main/base/' $r 'bucket-1' 'FAIL' 'no object under joshuatech-backup/pg-main/pg-main/base/ (4 objects total)'
        Assert-IdExact 'C17-2: bucket-2 FAIL -- the other serverName WAL objects are not segments of pg-main' $r 'bucket-2' 'FAIL' 'joshuatech-backup/pg-main/pg-main/wals/: only 0 WAL segment object(s) (<16hex>/<24hex>[.gz|.bz2|.lz4|.zst|.snappy|.xz] under the wals/ prefix; .backup/.history/.partial files excluded); need >= 3 to check archive contiguity'
        Assert-IdExact 'C17-3: env-1 FAIL names the secret volume' $r 'env-1' 'FAIL' "1 Secret reference(s) ending in '-migrate' in runtime Deployments (owner credentials belong to the PreSync migrate Job only): jt-prod/relay volumes[sv1].secret.secretName=relay-migrate"
        Assert-IdExact 'C17-4: role-2 FAIL -- app role createdb=true' $r 'role-2' 'FAIL' 'DatabaseRole attributes: dev_identity_admin_app: createdb must not be true'
        Assert-IdExact 'C17-5: backup-2 FAIL -- completed but neither stoppedAt nor startedAt' $r 'backup-2' 'FAIL' 'latest completed Backup pg-main-daily-x has neither stoppedAt nor startedAt (startedAt is absent; stoppedAt is absent)'
        Assert-OthersPass 'C17-6: every other id PASS' $r @('bucket-1', 'bucket-2', 'env-1', 'role-2', 'backup-2')
    }
    # 유휴 근거는 조건을 type으로 고른다(재검토 변이 X15 — 조건 목록의 첫 원소를 읽으면 Ready=True가 ContinuousArchiving으로 읽혀 거짓 PASS)
    Test-Case 'C18' 'idle cluster whose conditions list Ready=True first and ContinuousArchiving=False -> bucket-2 FAIL names the False condition (evidence is picked by condition type, not position)' {
        $resp = New-GoodResponses
        $resp[$Q.cluster] = R-Json (New-Cluster 'Cluster in healthy state' 1 1 @((Cond 'Ready' 'True'), (Cond 'ContinuousArchiving' 'False')))
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(20, 25, 30)))))
        $r = Invoke-Harness $d
        Assert-Run 'C18' $r $d
        Assert-Id 'C18-1: bucket-2 FAIL -- ContinuousArchiving is False even though the first condition (Ready) is True' $r 'bucket-2' 'FAIL' @("s old (> 900s) and the idle-safe evidence does not hold: Cluster condition ContinuousArchiving is 'False' (expected True)") @('idle-safe:')
        Assert-OthersPass 'C18-2: every other id PASS (bucket-1 counts 5 objects)' $r @('bucket-2') @{ 'bucket-1' = (Bucket1Detail 5) }
    }
    # DatabaseRole의 ensure=absent(재검토 변이 X16 — role-2가 absent 객체를 후보로 쓰면 거짓 PASS) + Deployment 정확히 1개(변이 X20 — 1개에서도 SKIP이면 거짓 SKIP)
    Test-Case 'C19' 'DatabaseRole declared absent (spec.ensure=absent, applied=true) -> role-1 FAIL (declared absent + missing) and role-2 FAIL (not a candidate); a single Deployment -> env-1 evaluated, never SKIP' {
        $resp = New-GoodResponses
        $resp[$Q.roles] = R-Json (New-List @((Role-App 'identity_admin_app'), (Role-App 'dev_identity_admin_app'), (Role-Owner 'identity_admin_owner'), (Role-Owner 'dev_identity_admin_owner'), (Role-Shared 'authentik_owner'), (New-Role 'openfga_owner' @{ login = $true; superuser = $false } $true 'pg-main' 'auto' 'absent')))
        $resp[$Q.depProd] = R-Json (New-List @())
        $d = New-Fixture $resp (New-TasksText) (Good-Oci)
        $r = Invoke-Harness $d
        Assert-Run 'C19' $r $d
        Assert-IdExact 'C19-1: role-1 FAIL -- openfga_owner declared absent and therefore missing' $r 'role-1' 'FAIL' 'DatabaseRole set for cluster pg-main: declared absent (spec.ensure=absent): openfga_owner; missing: openfga_owner'
        Assert-IdExact 'C19-2: role-2 FAIL -- the absent role is not a candidate' $r 'role-2' 'FAIL' 'DatabaseRole attributes: openfga_owner: not found'
        Assert-IdExact 'C19-3: env-1 PASS with exactly one Deployment (the D3 gate only at 0)' $r 'env-1' 'PASS' "1 Deployment(s) in jt-dev/jt-prod reference no '*-migrate' Secret (envFrom.secretRef, env.valueFrom.secretKeyRef, volumes.secret/projected; containers and initContainers): jt-dev/web"
        Assert-OthersPass 'C19-4: every other id PASS' $r @('role-1', 'role-2', 'env-1')
    }
    # 유휴 가지의 전 구간 연속성(3라운드 F6) + items: null인 List(F3): 상위 3개(C7..C5)는 연속이고 ContinuousArchiving=True · C7 ≥ endWal C0이지만 endWal과
    #   그 사이(C2)가 비어 있다 → bucket-2 FAIL; jt-prod의 Deployment 목록이 {"kind":"List","items":null}이면 "Deployment 0개"가 아니라 env-1 FAIL(T075 미체크여도 SKIP 아님)
    Test-Case 'C20' 'idle cluster (ContinuousArchiving=True, newest C7 >= endWal C0) but C2 is missing between endWal and the newest 3 -> bucket-2 FAIL names the gap; jt-prod Deployment list with items: null -> env-1 FAIL (never SKIP, T075 unchecked)' {
        $resp = New-GoodResponses
        $resp[$Q.cluster] = R-Json (New-Cluster 'Cluster in healthy state' 1 1 @((Cond 'Ready' 'True'), (Cond 'ContinuousArchiving' 'True')))
        $resp[$Q.depDev] = R-Json ([ordered]@{ apiVersion = 'apps/v1'; kind = 'DeploymentList'; metadata = [ordered]@{ resourceVersion = '' }; items = @() })
        $resp[$Q.depProd] = R-Raw '{"apiVersion":"v1","kind":"List","metadata":{"resourceVersion":""},"items":null}'
        # 세그먼트 C7, C6, C5, C4, C3, C1, C0(C2 없음) — 전부 20분 이상 전; Good-Backups의 최신 completed endWal = C0
        $d = New-Fixture $resp (New-TasksText) (Oci-Resp (New-OciListing (@($baseObjs) + @(New-WalObjects @(20, 25, 30, 35, 40, 50, 55) @(199, 198, 197, 196, 195, 193, 192)))))
        $r = Invoke-Harness $d
        Assert-Run 'C20' $r $d
        Assert-IdExact 'C20-1: bucket-2 FAIL -- the newest 3 are contiguous and the idle evidence holds, but C3 is not immediately preceded by C1 (C2 missing between endWal C0 and the newest)' $r 'bucket-2' 'FAIL' 'joshuatech-backup/pg-main/pg-main/wals/: WAL archive gap between endWal 0000000100000000000000C0 and the newest segment: 0000000100000000000000C3.lz4 is not immediately preceded by 0000000100000000000000C1.lz4 (expected 0000000100000000000000C2) (idle-safe branch: newest segment 0000000100000000000000C7.lz4 is not fresh, so every segment from endWal 0000000100000000000000C0 of Backup pg-main-daily-20261006170000 up to the newest must be archived)'
        Assert-IdExact 'C20-2: env-1 FAIL (not SKIP) -- items: null is not an empty list (jt-dev with items: [] is fine)' $r 'env-1' 'FAIL' "Deployment list in ns jt-prod lookup failed: expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='List' items=null"
        Assert-OthersPass 'C20-3: every other id PASS (bucket-1 counts 9 objects)' $r @('bucket-2', 'env-1') @{ 'bucket-1' = (Bucket1Detail 9) }
        Assert 'C20-4: exit 1 and summary "14 passed, 2 failed, 0 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '14 passed, 2 failed, 0 skipped')) (Format-Result $r)
        $calls = @(Get-Calls $d)
        Assert 'C20-5: the second contiguity pass re-used the cached Cluster and Backup lookups (still 12 kubectl calls, each once)' ($calls.Count -eq 12 -and @(@($Q.Values) | Where-Object { (Count-Key $calls $_) -ne 1 }).Count -eq 0) (Format-Calls $calls)
    }

    # ================= 정적(하네스 원문) =================
    Test-Case 'S01' 'harness source: the header names every assertion id, the T054-pending Job ids, the bucket name exception and the CNPG 1.30 field sources' {
        $src = if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { [IO.File]::ReadAllText($harnessPath) } else { '' }
        $hdr = [Collections.Generic.List[string]]::new()
        foreach ($l in @($src -split "`r?`n")) { if ($l.StartsWith('#', [StringComparison]::Ordinal)) { $hdr.Add($l) } else { break } }
        $header = $hdr -join "`n"
        $need = @('gate-1..3', 'pg-1', 'pg-2', 'db-1', 'db-2', 'role-1', 'role-2', 'backup-1', 'backup-2', 'bucket-1', 'bucket-2', 'job-1', 'job-2', 'env-1', 'until T075', 'role-attrs', 'app-session-timeouts', 'T053', 'T054', 'joshuatech-backup', 'jt-backup', 'cloudnative-pg/release-1.30', 'status.applied', 'observedGeneration', 'spec.ensure', 'spec.suspend', 'backupId', 'endWal', 'ContinuousArchiving', 'serverName', 'Cluster in healthy state', 'svc-verify', 'Mask-Text', 'agent-view-extra', '검증 후 결정')
        $missing = @($need | Where-Object { -not (Has-Text $header $_) })
        Assert 'S01-1: header lists the 16 ids, the D3 gate text, the T054-pending ids, the T053/T054 owners, the bucket name exception, the CNPG 1.30 sources and the verify-then-decide items' ($src.Length -gt 0 -and $missing.Count -eq 0) "missing in header: $($missing -join ', ')"
        # 쓰기 동사 토큰은 어디에도 없고, Secret 읽기는 kubectl 인자 모양('get', 'secrets' …)으로 나타나지 않는다(볼륨 접근자의 'secret' 키는 JSON 필드 이름이라 허용)
        $verbTokens = @("'exec'", "'delete'", "'apply'", "'patch'", "'edit'", "'scale'", "'create'", "'replace'", "'cp'", "'port-forward'", "'describe'")
        $secretReads = @("'get',\s*'secrets?", "'secrets?(\.v1)?'\s*,\s*'-n'", "Get-KubeOne\s+\S+\s+'secrets?'", "Get-ListCached\s+@\('get',\s*'secrets?")
        Assert 'S01-2: the harness never calls kubectl with a mutating verb or reads Secret values (no exec/delete/apply/patch/edit/scale/create/replace/cp/port-forward/describe tokens; no "get secrets" argument shape)' ($src.Length -gt 0 -and @($verbTokens | Where-Object { Has-Text $src $_ }).Count -eq 0 -and @($secretReads | Where-Object { [regex]::IsMatch($src, $_) }).Count -eq 0) 'found a forbidden verb token or a Secret read'
    }

    # ================= 함수(순수 함수 표) =================
    $script:mod = $null
    $script:modError = ''
    try { $script:mod = Import-HarnessModule $harnessPath } catch { $script:modError = $_.Exception.Message }
    $ids6 = @('pg-cross-db-denied', 'catalog-connect-false', 'revoke-public', 'ssl-verify-full', 'role-attrs', 'app-session-timeouts')
    $pend = @('role-attrs', 'app-session-timeouts')
    function Call-JobLog([string[]]$lines) { return (& $script:mod { param($l, $i, $p, $n) Test-JobLog $l $i $p $n } $lines $ids6 $pend 'pending-note') }
    Test-Case 'F01' 'Test-JobLog: exact-one PASS per id, last SUMMARY wins, prefix ids and EVIDENCE lines never count, pending ids carry the note' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-JobLog')
        Assert 'F01-0: the harness defines Test-JobLog' $ok "missing (module: $script:modError)"
        if ($ok) {
            $good = @($ids6 | ForEach-Object { "RESULT: PASS $_ evidence" }) + @('RESULT: PASS acl-list x', 'RESULT: PASS noperm y', 'SUMMARY: pass=8 fail=0')
            $rows = @(
                @{ name = 'all good (+ Dragonfly ids ignored)'; lines = $good; ok = $true; has = @() },
                @{ name = 'missing pending id -> note'; lines = @($good | Where-Object { -not (Has-Text $_ 'role-attrs') }); ok = $false; has = @('missing RESULT line for role-attrs (pending-note)') },
                @{ name = 'missing non-pending id -> no note'; lines = @($good | Where-Object { -not (Has-Text $_ 'revoke-public') }); ok = $false; has = @('missing RESULT line for revoke-public'); hasNot = @('pending-note') },
                @{ name = 'duplicate id'; lines = @('RESULT: PASS ssl-verify-full again') + $good; ok = $false; has = @('2 RESULT lines for ssl-verify-full (expected exactly 1)') },
                @{ name = 'FAIL id'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS catalog-connect-false', 'RESULT: FAIL catalog-connect-false') }); ok = $false; has = @('RESULT FAIL for catalog-connect-false') },
                @{ name = 'no SUMMARY'; lines = @($good | Where-Object { -not $_.StartsWith('SUMMARY', [StringComparison]::Ordinal) }); ok = $false; has = @('no SUMMARY line') },
                @{ name = 'SUMMARY fail=2'; lines = @($good | ForEach-Object { $_.Replace('fail=0', 'fail=2') }); ok = $false; has = @('SUMMARY fail=2 (expected 0; pass=8)') },
                @{ name = 'two SUMMARY lines -> the last wins'; lines = @('SUMMARY: pass=0 fail=9') + $good; ok = $true; has = @() },
                @{ name = 'prefix id does not count (revoke-public-extra is not revoke-public)'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS revoke-public evidence', 'RESULT: PASS revoke-public-extra evidence') }); ok = $false; has = @('missing RESULT line for revoke-public') },
                @{ name = 'EVIDENCE/NOTE lines carrying RESULT text do not count'; lines = @('EVIDENCE: RESULT: PASS ssl-verify-full fake', 'NOTE: RESULT: FAIL role-attrs fake') + $good; ok = $true; has = @() },
                @{ name = 'indented RESULT does not count (anchored)'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS role-attrs', ' RESULT: PASS role-attrs') }); ok = $false; has = @('missing RESULT line for role-attrs') },
                @{ name = 'empty log'; lines = @(); ok = $false; has = @('missing RESULT line for pg-cross-db-denied', 'no SUMMARY line') },
                @{ name = 'a NOTE line carrying SUMMARY text after the real SUMMARY does not replace it (anchored)'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS catalog-connect-false', 'RESULT: FAIL catalog-connect-false').Replace('SUMMARY: pass=8 fail=0', 'SUMMARY: pass=7 fail=1') }) + @('NOTE: SUMMARY: pass=8 fail=0'); ok = $false; has = @('RESULT FAIL for catalog-connect-false', 'SUMMARY fail=1 (expected 0; pass=7)') },
                @{ name = 'SUMMARY counts must match the RESULT lines (pass=1 vs 8 PASS lines)'; lines = @($good | ForEach-Object { $_.Replace('SUMMARY: pass=8 fail=0', 'SUMMARY: pass=1 fail=0') }); ok = $false; has = @('SUMMARY pass=1 fail=0 does not match the RESULT lines (PASS 8, FAIL 0) -- output may be truncated by --tail=50') },
                @{ name = 'consistent SUMMARY with all PASS has no count problem'; lines = $good; ok = $true; hasNot = @('does not match') },
                @{ name = 'a FAIL for an id outside the tracked set (acl-list) is a problem even with SUMMARY fail=0'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS acl-list x', 'RESULT: FAIL acl-list x') }); ok = $false; has = @('RESULT FAIL for acl-list (outside the tracked set)', 'does not match the RESULT lines (PASS 7, FAIL 1)') },
                @{ name = 'a FAIL for an untracked id with a consistent SUMMARY is still a problem'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS noperm y', 'RESULT: FAIL noperm y').Replace('SUMMARY: pass=8 fail=0', 'SUMMARY: pass=7 fail=1') }); ok = $false; has = @('RESULT FAIL for noperm (outside the tracked set)', 'SUMMARY fail=1 (expected 0; pass=7)'); hasNot = @('does not match') }
            )
            $bad = @()
            foreach ($row in $rows) {
                $v = Call-JobLog @($row.lines)
                $text = @($v.problems) -join '; '
                # 행에 hasNot 키가 없으면 @($row.hasNot)은 @($null)이고, 빈 바늘은 언제나 "찾힘"이 되므로 빈/널 바늘은 걸러낸다
                $miss = @(@($row.has) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { -not (Has-Text $text $_) })
                $extra = @(@($row.hasNot) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { Has-Text $text $_ })
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $extra.Count -gt 0) { $bad += "$($row.name): ok=$($v.ok) [$text]" }
            }
            Assert 'F01-1: the Job-log table' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F02' 'Get-WalSegment / Test-WalContiguity / Test-WalFreshness: segments only (labels, history, partial, other serverName excluded); newest 3 contiguous by number (FF->00 boundary, timeline switch = gap); fresh <= 900s or idle-safe (ContinuousArchiving=True and newest >= endWal)' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-WalSegment') -and (Test-ModuleHas $script:mod 'Test-WalContiguity') -and (Test-ModuleHas $script:mod 'Test-WalFreshness')
        Assert 'F02-0: the harness defines Get-WalSegment, Test-WalContiguity and Test-WalFreshness' $ok "missing (module: $script:modError)"
        if ($ok) {
            $pfx = 'pg-main/pg-main/wals/'
            function SegOf([string]$name) { return (& $script:mod { param($n, $p) Get-WalSegment $n $p } $name $pfx) }
            # 세그먼트 필터 표: name → 세그먼트인가(file · hex 기대)
            $segRows = @(
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.lz4'; seg = $true; file = '0000000100000000000000C7.lz4'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7'; seg = $true; file = '0000000100000000000000C7'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.gz'; seg = $true; file = '0000000100000000000000C7.gz'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.bz2'; seg = $true; file = '0000000100000000000000C7.bz2'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.zst'; seg = $true; file = '0000000100000000000000C7.zst'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.snappy'; seg = $true; file = '0000000100000000000000C7.snappy'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.xz'; seg = $true; file = '0000000100000000000000C7.xz'; hex = '0000000100000000000000C7' },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C0.00000028.backup.lz4'; seg = $false },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C0.00000028.backup'; seg = $false },
                @{ name = "$pfx" + '00000002.history'; seg = $false },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.partial'; seg = $false },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.tar'; seg = $false },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000c7.lz4'; seg = $false },
                @{ name = "$pfx" + '0000000100000000/0000000100000000000000C7.lz4.bak'; seg = $false },
                @{ name = "$pfx" + '0000000100000000000000C7.lz4'; seg = $false },
                @{ name = 'pg-main/pg-old/wals/0000000100000000/0000000100000000000000C7.lz4'; seg = $false },
                @{ name = 'pg-main/pg-main/walsx/0000000100000000/0000000100000000000000C7.lz4'; seg = $false },
                @{ name = 'pg-main/pg-main/base/20261006T170003/backup.info'; seg = $false },
                @{ name = ''; seg = $false }
            )
            $bad = @()
            foreach ($row in $segRows) {
                $s = SegOf $row.name
                if ($row.seg) {
                    if ($null -eq $s -or -not (Test-Same ([string]$s.file) $row.file) -or -not (Test-Same ([string]$s.hex) $row.hex) -or $s.timeline -ne 1 -or $s.logno -ne 0 -or $s.segno -ne 199) { $bad += "$($row.name): expected a segment (file=$($row.file), timeline 1, logno 0, segno 199), got [$(if ($null -eq $s) { 'null' } else { "$($s.file) $($s.timeline)/$($s.logno)/$($s.segno)" })]" }
                } elseif ($null -ne $s) { $bad += "$($row.name): expected not a segment, got $($s.file)" }
            }
            Assert 'F02-1: the segment filter table (7 segment shapes accepted; label, history, partial, unknown extension, lowercase, no hash dir, other serverName, walsx, base, empty rejected)' ($bad.Count -eq 0) ($bad -join ' || ')

            $now = [DateTime]::new(2026, 10, 7, 9, 0, 0, [DateTimeKind]::Utc)
            function Seg([string]$hex, [string]$ext = '.lz4', [double]$ageSec = 120) {
                $s = SegOf ("$pfx" + $hex.Substring(0, 16) + '/' + $hex + $ext)
                if ($null -eq $s) { throw "fixture segment name rejected: $hex$ext" }
                $s.utc = $now.AddSeconds(-$ageSec); return $s
            }
            $c7 = '0000000100000000000000C7'; $c6 = '0000000100000000000000C6'; $c5 = '0000000100000000000000C5'; $c4 = '0000000100000000000000C4'; $c2 = '0000000100000000000000C2'
            $contRows = @(
                @{ name = 'C7,C6,C5 contiguous'; segs = @((Seg $c7), (Seg $c6), (Seg $c5)); ok = $true; has = @("newest 3 WAL segments contiguous (timeline 1): $c7.lz4, $c6.lz4, $c5.lz4"); newest = $c7 },
                @{ name = 'unsorted input is sorted by segment number (not by time)'; segs = @((Seg $c5 '.lz4' 10), (Seg $c7 '.lz4' 900), (Seg $c6 '.lz4' 500)); ok = $true; has = @("$c7.lz4, $c6.lz4, $c5.lz4"); newest = $c7 },
                @{ name = 'a gap below the newest 3 is ignored (C7,C6,C5,C2)'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c2)); ok = $true; has = @("$c7.lz4, $c6.lz4, $c5.lz4"); newest = $c7 },
                @{ name = 'C6 missing -> gap'; segs = @((Seg $c7), (Seg $c5), (Seg $c4)); ok = $false; has = @("WAL archive gap: $c7.lz4 is not immediately preceded by $c5.lz4 (expected $c6)") },
                @{ name = 'second pair broken (C7,C6,C4) -> gap'; segs = @((Seg $c7), (Seg $c6), (Seg $c4)); ok = $false; has = @("WAL archive gap: $c6.lz4 is not immediately preceded by $c4.lz4 (expected $c5)") },
                @{ name = 'log boundary FF -> 00 is contiguous'; segs = @((Seg '000000010000000100000000'), (Seg '0000000100000000000000FF'), (Seg '0000000100000000000000FE')); ok = $true; has = @('(timeline 1): 000000010000000100000000.lz4, 0000000100000000000000FF.lz4, 0000000100000000000000FE.lz4') },
                @{ name = 'timeline switch inside the newest 3 is a gap'; segs = @((Seg '000000020000000000000005'), (Seg '000000010000000000000004'), (Seg '000000010000000000000003')); ok = $false; has = @('WAL archive gap: 000000020000000000000005.lz4 is not immediately preceded by 000000010000000000000004.lz4 (expected 000000020000000000000004)') },
                @{ name = 'first segment of a timeline cannot be checked across timelines'; segs = @((Seg '000000020000000000000000'), (Seg '0000000100000000000000FF'), (Seg '0000000100000000000000FE')); ok = $false; has = @('000000020000000000000000.lz4 is the first segment of timeline 2') },
                @{ name = 'mixed extensions are still contiguous'; segs = @((Seg $c7 '.gz'), (Seg $c6 ''), (Seg $c5 '.zst')); ok = $true; has = @("$c7.gz, $c6, $c5.zst") },
                @{ name = 'duplicate object for one segment (two compressions) is a gap, not contiguous'; segs = @((Seg $c7 '.gz'), (Seg $c7 '.lz4'), (Seg $c6)); ok = $false; has = @("WAL archive gap: $c7.gz is not immediately preceded by $c7.lz4 (expected $c6)") },
                @{ name = '2 segments -> FAIL'; segs = @((Seg $c7), (Seg $c6)); ok = $false; has = @('only 2 WAL segment object(s)', 'need >= 3 to check archive contiguity') },
                @{ name = '0 segments -> FAIL'; segs = @(); ok = $false; has = @('only 0 WAL segment object(s)') }
            )
            $bad = @()
            foreach ($row in $contRows) {
                $v = & $script:mod { param($s, $n) Test-WalContiguity $s $n } @($row.segs) 3
                $miss = @(@($row.has) | Where-Object { -not (Has-Text ([string]$v.detail) $_) })
                $newestBad = ($row.ContainsKey('newest') -and ($null -eq $v.newest -or -not (Test-Same ([string]$v.newest.hex) $row.newest)))
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $newestBad) { $bad += "$($row.name): ok=$($v.ok) newest=$(if ($null -ne $v.newest) { $v.newest.hex } else { 'null' }) [$($v.detail)]" }
            }
            Assert 'F02-2: the contiguity table' ($bad.Count -eq 0) ($bad -join ' || ')

            # 유휴 근거 묶음(Get-IdleArchiveEvidence가 모으는 모양) — 매개변수는 형식을 붙이지 않는다($null을 ''로 바꾸지 않게)
            function Ev($archiving, $endWal, $clusterError = $null, $backupError = $null) { return @{ clusterError = $clusterError; archiving = $archiving; backupError = $backupError; backupName = 'b1'; endWal = $endWal } }
            $freshRows = @(
                @{ name = 'age 120 -> fresh'; age = 120; ev = $null; ok = $true; has = @("newest segment $c7.lz4 is 120s old (<= 900s)") },
                @{ name = 'age exactly 900 -> fresh'; age = 900; ev = $null; ok = $true; has = @('is 900s old (<= 900s)') },
                @{ name = 'future (clock skew) -> fresh'; age = -30; ev = $null; ok = $true; has = @('is -30s old (<= 900s)') },
                @{ name = 'age 901 + ContinuousArchiving True + endWal C0 -> idle-safe'; age = 901; ev = (Ev 'True' '0000000100000000000000C0'); ok = $true; has = @("newest segment $c7.lz4 is 901s old (> 900s) but idle-safe: ContinuousArchiving=True and $c7 >= endWal 0000000100000000000000C0 of Backup b1") },
                @{ name = 'endWal equal to the newest -> idle-safe'; age = 901; ev = (Ev 'True' $c7); ok = $true; has = @('idle-safe') },
                @{ name = 'endWal above the newest -> FAIL'; age = 901; ev = (Ev 'True' '0000000100000000000000C8'); ok = $false; has = @("newest segment $c7.lz4 < status.endWal=0000000100000000000000C8 of Backup b1 (the archive does not cover the latest base backup)") },
                @{ name = 'endWal on a later timeline -> FAIL'; age = 901; ev = (Ev 'True' '000000020000000000000001'); ok = $false; has = @('< status.endWal=000000020000000000000001') },
                @{ name = 'no ContinuousArchiving condition -> FAIL'; age = 901; ev = (Ev $null '0000000100000000000000C0'); ok = $false; has = @("newest WAL segment $c7.lz4 is 901s old (> 900s) and the idle-safe evidence does not hold: Cluster data/pg-main has no ContinuousArchiving condition") },
                @{ name = 'ContinuousArchiving False -> FAIL'; age = 901; ev = (Ev 'False' '0000000100000000000000C0'); ok = $false; has = @("Cluster condition ContinuousArchiving is 'False' (expected True)") },
                @{ name = 'ContinuousArchiving Unknown -> FAIL'; age = 901; ev = (Ev 'Unknown' '0000000100000000000000C0'); ok = $false; has = @("Cluster condition ContinuousArchiving is 'Unknown' (expected True)") },
                @{ name = 'Cluster lookup failed -> FAIL with that reason'; age = 901; ev = (Ev 'True' '0000000100000000000000C0' 'Cluster data/pg-main lookup failed: boom'); ok = $false; has = @('does not hold: Cluster data/pg-main lookup failed: boom') },
                @{ name = 'no completed Backup -> FAIL with that reason'; age = 901; ev = (Ev 'True' $null $null 'no Backup for cluster pg-main in ns data (x)'); ok = $false; has = @('does not hold: no Backup for cluster pg-main in ns data (x)') },
                @{ name = 'Backup without endWal -> FAIL'; age = 901; ev = (Ev 'True' ''); ok = $false; has = @('latest completed Backup b1 has no status.endWal') },
                @{ name = 'endWal not a WAL name -> FAIL'; age = 901; ev = (Ev 'True' 'bogus'); ok = $false; has = @("status.endWal='bogus' of Backup b1 is not a WAL segment name") },
                @{ name = 'no evidence object on the idle branch -> FAIL'; age = 901; ev = $null; ok = $false; has = @('no idle evidence gathered') },
                @{ name = 'unusable time -> FAIL naming the segment'; age = $null; ev = $null; ok = $false; has = @("newest WAL segment $c7.lz4 time-created unusable: unparseable: [bogus]") }
            )
            $bad = @()
            foreach ($row in $freshRows) {
                $newest = Seg $c7
                if ($null -eq $row.age) { $newest.utc = $null; $newest.error = 'unparseable: [bogus]' } else { $newest.utc = $now.AddSeconds(-[double]$row.age) }
                $v = & $script:mod { param($s, $n, $m, $e) Test-WalFreshness $s $n $m $e } $newest $now 900 $row.ev
                $miss = @(@($row.has) | Where-Object { -not (Has-Text ([string]$v.detail) $_) })
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0) { $bad += "$($row.name): ok=$($v.ok) [$($v.detail)]" }
            }
            Assert 'F02-3: the freshness table (fresh branch, idle-safe branch, every idle failure reason)' ($bad.Count -eq 0) ($bad -join ' || ')

            # 유휴 가지의 두 번째 호출($floorHex = endWal): endWal 이상 전부 내림차순 · 가장 낮은 것이 endWal 자신 · 미만은 무시
            $c3 = '0000000100000000000000C3'; $c1 = '0000000100000000000000C1'; $c0 = '0000000100000000000000C0'; $c8 = '0000000100000000000000C8'
            $floorRows = @(
                @{ name = 'floor C4: C7..C4 all present -> contiguous'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c4)); floor = $c4; ok = $true; has = @("all 4 WAL segment(s) from endWal $c4 to $c7 contiguous (timeline 1)"); newest = $c7 },
                @{ name = 'segments below the floor are ignored (C7,C6,C5,C2 with floor C5)'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c2)); floor = $c5; ok = $true; has = @("all 3 WAL segment(s) from endWal $c5 to $c7 contiguous (timeline 1)"); newest = $c7 },
                @{ name = 'unsorted input with a floor is sorted by number'; segs = @((Seg $c4 '.lz4' 10), (Seg $c7 '.lz4' 900), (Seg $c5), (Seg $c6)); floor = $c4; ok = $true; has = @("all 4 WAL segment(s) from endWal $c4 to $c7 contiguous"); newest = $c7 },
                @{ name = 'gap in the middle, above the floor and below the newest 3 (C7,C6,C5,C2,C1,C0 with floor C0: C4,C3 missing) -> gap'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c2), (Seg $c1), (Seg $c0)); floor = $c0; ok = $false; has = @("WAL archive gap between endWal $c0 and the newest segment: $c5.lz4 is not immediately preceded by $c2.lz4 (expected $c4)") },
                @{ name = 'the same list without a floor passes (the newest-3 sample does not see that gap)'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c2), (Seg $c1), (Seg $c0)); floor = ''; ok = $true; has = @("newest 3 WAL segments contiguous (timeline 1): $c7.lz4, $c6.lz4, $c5.lz4") },
                @{ name = 'the floor itself is missing (C7,C6,C5,C2 with floor C4) -> gap'; segs = @((Seg $c7), (Seg $c6), (Seg $c5), (Seg $c2)); floor = $c4; ok = $false; has = @("WAL archive gap: endWal $c4 of the latest completed Backup is not in the archive (lowest segment >= endWal is $c5.lz4)") },
                @{ name = 'floor equal to the newest (C7) -> 1 segment, contiguous'; segs = @((Seg $c7), (Seg $c6), (Seg $c5)); floor = $c7; ok = $true; has = @("all 1 WAL segment(s) from endWal $c7 to $c7 contiguous (timeline 1)"); newest = $c7 },
                @{ name = 'floor above the newest (C8) -> no segment >= endWal'; segs = @((Seg $c7), (Seg $c6), (Seg $c5)); floor = $c8; ok = $false; has = @("WAL archive gap: no WAL segment object >= endWal $c8") },
                @{ name = 'floor across the FF->00 log boundary is contiguous'; segs = @((Seg '000000010000000100000001'), (Seg '000000010000000100000000'), (Seg '0000000100000000000000FF'), (Seg '0000000100000000000000FE')); floor = '0000000100000000000000FE'; ok = $true; has = @('all 4 WAL segment(s) from endWal 0000000100000000000000FE to 000000010000000100000001 contiguous (timeline 1)') },
                @{ name = 'timeline switch above the floor is a gap'; segs = @((Seg '000000020000000000000005'), (Seg '000000010000000000000004'), (Seg '000000010000000000000003')); floor = '000000010000000000000003'; ok = $false; has = @('WAL archive gap between endWal 000000010000000000000003 and the newest segment: 000000020000000000000005.lz4 is not immediately preceded by 000000010000000000000004.lz4 (expected 000000020000000000000004)') },
                @{ name = 'floor that is the first segment of a timeline is fine as the lowest element'; segs = @((Seg '000000020000000000000002'), (Seg '000000020000000000000001'), (Seg '000000020000000000000000')); floor = '000000020000000000000000'; ok = $true; has = @('all 3 WAL segment(s) from endWal 000000020000000000000000 to 000000020000000000000002 contiguous (timeline 2)') },
                @{ name = 'floor not a WAL segment name -> FAIL'; segs = @((Seg $c7), (Seg $c6), (Seg $c5)); floor = 'bogus'; ok = $false; has = @("WAL archive floor 'bogus' is not a WAL segment name") },
                @{ name = 'fewer than 3 segments with a floor -> the count FAIL first'; segs = @((Seg $c7), (Seg $c6)); floor = $c6; ok = $false; has = @('only 2 WAL segment object(s)', 'need >= 3 to check archive contiguity') }
            )
            $bad = @()
            foreach ($row in $floorRows) {
                $v = & $script:mod { param($s, $n, $f) Test-WalContiguity $s $n $f } @($row.segs) 3 ([string]$row.floor)
                $miss = @(@($row.has) | Where-Object { -not (Has-Text ([string]$v.detail) $_) })
                $newestBad = ($row.ContainsKey('newest') -and ($null -eq $v.newest -or -not (Test-Same ([string]$v.newest.hex) $row.newest)))
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $newestBad) { $bad += "$($row.name): ok=$($v.ok) newest=$(if ($null -ne $v.newest) { $v.newest.hex } else { 'null' }) [$($v.detail)]" }
            }
            Assert 'F02-4: the floor table (idle branch: every segment from endWal up to the newest; gap in the middle, floor missing, floor above the newest, FF->00 boundary, timeline switch, bad floor, count)' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F03' 'Find-MigrateRefs: envFrom.secretRef, env.valueFrom.secretKeyRef (containers and initContainers) and volumes.secret/projected; configMapRef, configMap volumes and non-suffix names never count' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Find-MigrateRefs')
        Assert 'F03-0: the harness defines Find-MigrateRefs' $ok "missing (module: $script:modError)"
        if ($ok) {
            $deps = @(
                (New-Deployment 'jt-dev' 'web' @('web-env', 'web-migrate') @{ DATABASE_URL = 'web-env'; OWNER_URL = 'web-migrate' } @{ INIT_URL = 'web-migrate' }),
                (New-Deployment 'jt-prod' 'relay' @('relay-env') @{ DATABASE_URL = 'relay-env' }),
                (New-Deployment 'jt-prod' 'odd' @('migrate-relay', 'relay-migrate-x', 'x-MIGRATE') @{ A = 'migrate' }),
                (New-Deployment 'jt-prod' 'vol' @('vol-env') @{} @{} @('vol-env', 'vol-migrate') @('vol-env', 'vol-migrate'))
            )
            $deps[2]['spec']['template']['spec']['containers'][0]['envFrom'] += , [ordered]@{ configMapRef = [ordered]@{ name = 'cm-migrate' } }
            # 볼륨 유사체: configMap 볼륨 cm-migrate · 접미가 다른 secret 볼륨 relay-migrate-x · 이름이 -migrate인 emptyDir(Secret 아님)
            $deps[2]['spec']['template']['spec']['volumes'] = @([ordered]@{ name = 'cmv'; configMap = [ordered]@{ name = 'cm-migrate' } }, [ordered]@{ name = 'sx'; secret = [ordered]@{ secretName = 'relay-migrate-x' } }, [ordered]@{ name = 'tmp-migrate'; emptyDir = [ordered]@{} })
            $json = (Json (New-List $deps)) | ConvertFrom-Json -Depth 30
            $hits = @(& $script:mod { param($d, $s) Find-MigrateRefs $d $s } @($json.items) '-migrate')
            $want = @('jt-dev/web initContainers[migrate-wait] env[INIT_URL].valueFrom.secretKeyRef=web-migrate', 'jt-dev/web containers[web] envFrom.secretRef=web-migrate', 'jt-dev/web containers[web] env[OWNER_URL].valueFrom.secretKeyRef=web-migrate', 'jt-prod/vol volumes[sv2].secret.secretName=vol-migrate', 'jt-prod/vol volumes[pv2].projected.secret=vol-migrate')
            Assert 'F03-1: exactly the three -migrate references of jt-dev/web (initContainers-then-containers order) plus the secret volume and the projected secret of jt-prod/vol; relay and the look-alikes (migrate-relay, relay-migrate-x, x-MIGRATE, configMapRef/configMap cm-migrate, emptyDir tmp-migrate) do not count' (Test-Same ($hits -join "`n") ($want -join "`n")) "got [$($hits -join ' | ')]"
            $none = @(& $script:mod { param($d, $s) Find-MigrateRefs $d $s } @() '-migrate')
            Assert 'F03-2: no Deployment -> no reference' ($none.Count -eq 0) "got $($none.Count)"
        }
    }
    Test-Case 'F04' 'Test-NamedSet: exact set, duplicates, missing, extra, status.applied, spec.ensure=absent, generation vs observedGeneration' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-NamedSet')
        Assert 'F04-0: the harness defines Test-NamedSet' $ok "missing (module: $script:modError)"
        if ($ok) {
            function Obj([string]$n, $applied = $true, [string]$ensure = 'present', [int]$generation = 1, $observedGeneration = 1) { return (Json (New-Database $n 'o' $applied 'pg-main' $ensure $generation $observedGeneration)) | ConvertFrom-Json -Depth 30 }
            $exp = @('a', 'b')
            $rows = @(
                @{ name = 'exact'; objs = @((Obj 'a'), (Obj 'b')); ok = $true; has = @() },
                @{ name = 'order does not matter'; objs = @((Obj 'b'), (Obj 'a')); ok = $true; has = @() },
                @{ name = 'missing b'; objs = @((Obj 'a')); ok = $false; has = @('missing: b') },
                @{ name = 'extra c'; objs = @((Obj 'a'), (Obj 'b'), (Obj 'c')); ok = $false; has = @('unexpected (not in the SP-1 set): c') },
                @{ name = 'duplicate a (subset comparison would pass)'; objs = @((Obj 'a'), (Obj 'a'), (Obj 'b')); ok = $false; has = @('duplicate spec.name: a') },
                @{ name = 'applied=false'; objs = @((Obj 'a' $false), (Obj 'b')); ok = $false; has = @("not applied: a(status.applied='False')") },
                @{ name = 'status absent'; objs = @((Obj 'a' 'absent'), (Obj 'b')); ok = $false; has = @("not applied: a(status.applied='')") },
                @{ name = 'case differs (ordinal)'; objs = @((Obj 'A'), (Obj 'b')); ok = $false; has = @('missing: a', 'unexpected (not in the SP-1 set): A') },
                @{ name = 'empty'; objs = @(); ok = $false; has = @('no Database for cluster pg-main in ns data (T054 deploys them)') },
                @{ name = 'declared absent (spec.ensure=absent with applied=true is not present)'; objs = @((Obj 'a'), (Obj 'b' $true 'absent')); ok = $false; has = @('declared absent (spec.ensure=absent): b', 'missing: b'); hasNot = @('unexpected') },
                @{ name = 'all declared absent -> declared absent + no objects'; objs = @((Obj 'a' $true 'absent'), (Obj 'b' $true 'absent')); ok = $false; has = @('declared absent (spec.ensure=absent): a, b', 'no Database for cluster pg-main in ns data (T054 deploys them)') },
                @{ name = 'an extra name declared absent is reported as absent, not as unexpected'; objs = @((Obj 'a'), (Obj 'b'), (Obj 'c' $true 'absent')); ok = $false; has = @('declared absent (spec.ensure=absent): c'); hasNot = @('unexpected', 'missing') },
                @{ name = 'stale: generation 3 vs observedGeneration 1 (applied=true)'; objs = @((Obj 'a' $true 'present' 3 1), (Obj 'b')); ok = $false; has = @("status stale: a(generation=3 observedGeneration='1')"); hasNot = @('not applied') },
                @{ name = 'status without observedGeneration is stale'; objs = @((Obj 'a' $true 'present' 1 $null), (Obj 'b')); ok = $false; has = @("status stale: a(generation=1 observedGeneration='')") },
                @{ name = 'generation 2 = observedGeneration 2 is current'; objs = @((Obj 'a' $true 'present' 2 2), (Obj 'b')); ok = $true; has = @() }
            )
            $bad = @()
            foreach ($row in $rows) {
                $v = & $script:mod { param($o, $e) Test-NamedSet $o $e 'Database' } @($row.objs) $exp
                $text = @($v.problems) -join '; '
                $miss = @(@($row.has) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { -not (Has-Text $text $_) })
                $extra = @(@($row.hasNot) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { Has-Text $text $_ })
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $extra.Count -gt 0) { $bad += "$($row.name): ok=$($v.ok) [$text]" }
            }
            Assert 'F04-1: the named-set table' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F05' 'Get-TaskLineState (copied gate rule): "- [ ] T075 " / "- [X] T075 " / "- [x] T075 " at the start of a line; exactly one line or an error' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-TaskLineState')
        Assert 'F05-0: the harness defines Get-TaskLineState' $ok "missing (module: $script:modError)"
        if ($ok) {
            $table = @(
                @{ lines = @('- [ ] T075 a'); want = 'unchecked' },
                @{ lines = @('- [X] T075 a'); want = 'checked' },
                @{ lines = @('- [x] T075 a'); want = 'checked' },
                @{ lines = @('- [ ] T075 a', '- [ ] T076 b', '- [X] T0751 c'); want = 'unchecked' },
                @{ lines = @(); want = 'error:0' },
                @{ lines = @('- [ ] T075 a', '- [X] T075 b'); want = 'error:2' },
                @{ lines = @('  - [ ] T075 a'); want = 'error:0' },
                @{ lines = @('- [ ] T075'); want = 'error:0' },
                @{ lines = @('* [ ] T075 a'); want = 'error:0' },
                @{ lines = @('- [ ] t075 a'); want = 'error:0' }
            )
            $bad = @()
            foreach ($row in $table) {
                $s = & $script:mod { param($l) Get-TaskLineState $l 'T075' } $row.lines
                $got = if (-not [string]::IsNullOrEmpty([string]$s.error)) { $m = [regex]::Match([string]$s.error, 'has (\d+) task line'); "error:$(if ($m.Success) { $m.Groups[1].Value } else { '?' })" } else { [string]$s.state }
                if (-not (Test-Same $got $row.want)) { $bad += "[$($row.lines -join ' / ')] -> $got (want $($row.want))" }
            }
            Assert 'F05-1: the task-line table' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }
    # Items 모양 검사(3라운드 F3): items가 JSON 배열일 때만 받는다 — kubectl은 빈 목록을 items: []로 내므로 null · 객체 · 문자열 · 없음은 모양 실패 = throw
    Test-Case 'F06' 'Items: accepted only when kind ends in List and items is a JSON array (empty, 1, n); items null/object/string/missing, a Status object, a lowercase kind and a null document throw' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Items')
        Assert 'F06-0: the harness defines Items' $ok "missing (module: $script:modError)"
        if ($ok) {
            $rows = @(
                @{ name = 'List items []'; json = '{"kind":"List","apiVersion":"v1","items":[]}'; count = 0 },
                @{ name = 'List items [1]'; json = '{"kind":"List","apiVersion":"v1","items":[{"kind":"Deployment","metadata":{"name":"x"}}]}'; count = 1 },
                @{ name = 'List items [2]'; json = '{"kind":"List","items":[{"a":1},{"a":2}]}'; count = 2 },
                @{ name = 'DeploymentList items [1]'; json = '{"kind":"DeploymentList","apiVersion":"apps/v1","items":[{"metadata":{"name":"x"}}]}'; count = 1 },
                @{ name = 'List items null'; json = '{"kind":"List","apiVersion":"v1","items":null}'; throws = "expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='List' items=null" },
                @{ name = 'List items {}'; json = '{"kind":"List","apiVersion":"v1","items":{}}'; throws = "got kind='List' items=PSCustomObject" },
                @{ name = 'List items "str"'; json = '{"kind":"List","apiVersion":"v1","items":"str"}'; throws = "got kind='List' items=String" },
                @{ name = 'List without items'; json = '{"kind":"List","apiVersion":"v1","metadata":{}}'; throws = "got kind='List' items=missing" },
                @{ name = 'Status with items []'; json = '{"kind":"Status","items":[]}'; throws = "got kind='Status' items=Object[]" },
                @{ name = 'kind list (lowercase, ordinal)'; json = '{"kind":"list","items":[]}'; throws = "got kind='list'" },
                @{ name = 'null document'; json = 'null'; throws = "got kind='' items=missing" }
            )
            $bad = @()
            foreach ($row in $rows) {
                $obj = $row.json | ConvertFrom-Json -Depth 20
                $got = $null; $err = $null
                try { $got = @(& $script:mod { param($o) Items $o } $obj) } catch { $err = $_.Exception.Message }
                if ($row.ContainsKey('throws')) {
                    if ($null -eq $err) { $bad += "$($row.name): expected a throw, got $($got.Count) item(s)" }
                    elseif (-not (Has-Text $err $row.throws)) { $bad += "$($row.name): throw text lacks [$($row.throws)] :: [$err]" }
                } elseif ($null -ne $err) { $bad += "$($row.name): unexpected throw [$err]" }
                elseif ($got.Count -ne $row.count) { $bad += "$($row.name): expected $($row.count) item(s), got $($got.Count)" }
            }
            Assert 'F06-1: the Items table' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }

    # 선택 실행에 모르는 케이스 이름이 있으면 실패(오타로 아무것도 안 돌고 통과하지 않게)
    foreach ($o in $script:only) {
        if (-not (In-Set $script:known $o)) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in DATA_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
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
