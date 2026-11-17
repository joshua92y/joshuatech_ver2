# tests/platform/ingress.tests.ps1 하네스 단위 테스트(T049 — cert-2 notAfter의 UTC 처리 · 30일 경계). Run: pwsh -NoProfile -File tests/scripts/ingress-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/reboot-tests.tests.ps1과 같은 구조).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all의 ingress-harness 체크가 이 파일을 직접 실행한다).
#
# 무엇을 지키나(요구 원문 .superpowers/t049/prompts/harness-fix.md 설계 D6): cert-2는 Certificate status.notAfter를 문자열로 왕복하지 않는다.
#   수정 전 코드는 ConvertFrom-Json이 만든 [DateTime](Kind=Utc)을 "$x"로 문자열화해(오프셋 소실) RoundtripKind로 다시 읽었고, 그 값이
#   로컬 시각으로 읽혀 UTC가 로컬 오프셋만큼 틀렸다(+09:00 머신에서 9시간 이름 — 남은 일수도 0.375일 적다).
#   시간대 주의: 이 오차는 머신 시간대에 따라 다르다. 시간대가 UTC인 머신에서는 수정 전 코드도 우연히 맞으므로 I01 · I02 · I04 · I06(그리고
#   함수 케이스의 문자열 경로)은 그런 머신에서 수정 전 코드를 잡지 못한다. 단언은 언제나 정확한 UTC 문자열이다. 실행 첫머리에 이 머신의
#   시간대를 NOTE로 찍는다.
# 방식 1 — E2E 케이스(I*): 케이스마다 임시 픽스처(%TEMP%/ingresstest-<guid>)에 하네스 사본 · 가짜 kubectl(bin/kubectl.cmd → bin/fake-kubectl.ps1) ·
#   응답표(responses.tsv + resp/) · 더미 kubeconfig를 만들고 하네스 사본을 자식 pwsh로 실행한다. 자식 PATH = 픽스처 bin + 지금 PATH에서
#   kubectl.* · oci.* · curl.* 파일이 있는 디렉터리를 뺀 나머지 — curl.exe가 없으므로 HTTP 단언(tool-1 · argo-1 · vault-1 · traefik-1 · aop-1)은
#   'curl.exe unavailable'로 FAIL하고 네트워크(Cloudflare 엣지 · 노드 A 공인 IP)에 닿지 않는다(이 시험의 범위 밖). 실행마다 처음 찾히는
#   kubectl이 픽스처 심인지, oci · curl이 안 찾히는지 확인하고 아니면 실행하지 않는다. 가짜 kubectl은 cluster-tests.tests.ps1과 같다
#   (인자에서 --kubeconfig · --request-timeout을 떼고 응답표를 ordinal로 찾는다; 없으면 exit 1 + 기록 served = default).
# 방식 2 — 함수 케이스(F*): 하네스 파일의 최상위 함수만 AST로 꺼내 동적 모듈에 정의하고 ConvertTo-UtcInstant를 직접 부른다
#   ([DateTime]의 Kind 셋 · [DateTimeOffset] · 문자열 · 그 밖의 형).
# 환경 변수:
#   INGRESS_HARNESS_SCRIPT      시험할 하네스(기본 tests/platform/ingress.tests.ps1) — 변이 시험에서 사본을 가리킨다. 설정되면 요약 줄 끝에
#                               ' (script override: <파일 이름>)'이 붙어 run-all의 판정을 통과하지 못한다.
#   INGRESS_HARNESS_TESTS_ONLY  쉼표로 나눈 케이스 ID만 실행한다. 요약 줄 끝에 ' (filtered: …)'가 붙는다. 모르는 ID가 있으면 FAIL.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:INGRESS_HARNESS_SCRIPT)
$harnessPath = if ($scriptOverride) { $env:INGRESS_HARNESS_SCRIPT } else { Join-Path $repo 'tests/platform/ingress.tests.ps1' }
$inv = [Globalization.CultureInfo]::InvariantCulture
$utcFmt = "yyyy-MM-dd'T'HH:mm:ss'Z'"
$sep = [IO.Path]::PathSeparator
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
if (-not [string]::IsNullOrWhiteSpace($env:INGRESS_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:INGRESS_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}
function Test-Same([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Has-Text([string]$s, [string]$needle) { return ($null -ne $s -and $s.IndexOf($needle, [StringComparison]::Ordinal) -ge 0) }
function Test-Case([string]$id, [string]$title, [scriptblock]$body) {
    $caseId = $id   # 본문은 이 함수 범위에서 dot-source로 돈다 — 본문이 $id를 덮어도 되게
    $script:known += $caseId
    if ($script:only.Count -gt 0 -and @($script:only | Where-Object { Test-Same $_ $caseId }).Count -eq 0) { return }
    Write-Host "-- ${caseId}: $title"
    $caseWatch = [Diagnostics.Stopwatch]::StartNew()
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $caseId -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    Write-Host "   [$caseId took $($caseWatch.Elapsed.TotalSeconds.ToString('0.0', $inv))s]"
}

# ---------- 가짜 kubectl(cluster-tests.tests.ps1과 같은 본문) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/ingress-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
# 입력: ..\responses.tsv(줄 = 번호 TAB 종료코드 TAB key) + ..\resp\<번호>.out · <번호>.err
# 기록: ..\calls.log(줄 = served TAB 종료코드 TAB kubeconfig TAB request-timeout TAB key). JSON cmdlet은 쓰지 않는다(호출마다 새 pwsh — 적재 시간).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$utf8 = [Text.UTF8Encoding]::new($false)
try { [Console]::OutputEncoding = $utf8 } catch { }
# 인자는 $args가 아니라 심이 넘긴 원래 명령줄(FAKE_KUBECTL_ARGV = cmd의 %*)에서 읽는다(pwsh -File이 '--kubeconfig=C:\…'를
# '-이름:값' 문법으로 쪼개 콜론을 떼기 때문 — cluster-tests.tests.ps1 같은 자리 주석). 나누기는 Windows 명령줄 규칙(CommandLineToArgvW)이다.
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
$line = "$served`t$code`t$kc`t$rt`t$key"
for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::AppendAllText((Join-Path $root 'calls.log'), $line + "`n", $utf8); break } catch { Start-Sleep -Milliseconds 25 } }
if (-not [string]::IsNullOrEmpty($err)) { [Console]::Error.WriteLine($err) }
if (-not [string]::IsNullOrEmpty($out)) { [Console]::Out.Write($out) }
exit $code
'@
$crlf = "`r`n"
# kubectl.cmd 심: CRLF, BOM 없음. 받은 명령줄(%*)을 FAKE_KUBECTL_ARGV로 넘긴다(인자로 넘기면 pwsh -File이 콜론이 든 인자를 쪼갠다).
$shimBody = (@(
        '@echo off'
        'set "FAKE_KUBECTL_ARGV=%*"'
        "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0fake-kubectl.ps1`""
        'exit /b %ERRORLEVEL%'
    ) -join $crlf) + $crlf

# ---------- 자식 PATH(실제 kubectl · oci · curl을 가린다 — cluster-tests.tests.ps1과 같은 규칙) ----------
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

# ---------- 응답표 ----------
function Json($o) { return (ConvertTo-Json -InputObject $o -Depth 30 -Compress) }
function New-List([object[]]$items) { return [ordered]@{ apiVersion = 'v1'; kind = 'List'; items = @(@($items) | Where-Object { $null -ne $_ }) } }
# 와일드카드 Certificate 1장(Ready=True). $notAfter: 문자열(그대로 JSON 문자열로) · $null = status.notAfter 없음
function New-CertList($notAfter) {
    $st = [ordered]@{ conditions = @([ordered]@{ type = 'Ready'; status = 'True'; reason = 'Ready'; message = 'Certificate is up to date and has not expired' }) }
    if ($null -ne $notAfter) { $st['notAfter'] = [string]$notAfter; $st['notBefore'] = '2026-09-09T05:12:35Z'; $st['renewalTime'] = '2026-11-08T05:12:34Z' }
    $cert = [ordered]@{ apiVersion = 'cert-manager.io/v1'; kind = 'Certificate'; metadata = [ordered]@{ name = 'wildcard-joshuatech-dev'; namespace = 'kube-system' }; spec = [ordered]@{ secretName = 'wildcard-joshuatech-dev-tls'; dnsNames = @('*.joshuatech.dev') }; status = $st }
    return (New-List @($cert))
}
function New-Responses($notAfter) {
    $r = [ordered]@{}
    $r['get nodes -l role=platform -o json'] = @{ out = (Json (New-List @())); err = ''; code = 0 }
    $r['get ingress -A -o json'] = @{ out = (Json (New-List @())); err = ''; code = 0 }
    $r['get certificates.cert-manager.io -n kube-system -o json'] = @{ out = (Json (New-CertList $notAfter)); err = ''; code = 0 }
    return $r
}

# ---------- 픽스처 · 실행 ----------
function New-Fixture($responses) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('ingresstest-' + [guid]::NewGuid().ToString('N'))
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
    if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { Copy-Item -LiteralPath $harnessPath -Destination (Join-Path $dir 'repo/tests/platform/ingress.tests.ps1') }
    return $dir
}
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('ingresstest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'responses.tsv') -PathType Leaf)) {
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
function Invoke-Harness([string]$dir, [int]$timeoutSec = 120) {
    $h = Join-Path $dir 'repo/tests/platform/ingress.tests.ps1'
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
    $psi.Environment['KUBECONFIG'] = Join-Path $dir 'kubeconfig.yaml'
    $psi.Environment['PATH'] = $childPath
    $psi.Environment['TMP'] = Join-Path $dir 'tmp'
    $psi.Environment['TEMP'] = Join-Path $dir 'tmp'
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
function Get-Lines($r) { return @(($r.out.TrimEnd("`n")) -split "`n") }
function Format-Result($r) {
    $lines = @(Get-Lines $r)
    $tail = if ($lines.Count -gt 12) { @('...') + $lines[($lines.Count - 12)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
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
# 'PASS|FAIL <name>: … -- <detail>' 줄 → @{ n; status; detail; line }. 이 하네스의 단언 이름은 'cert-2: …' 처럼 ID 뒤에 설명이 붙는다.
function Get-IdResult($r, [string]$id) {
    $hits = @(@(Get-Lines $r) | Where-Object { $_.StartsWith("PASS ${id}: ", [StringComparison]::Ordinal) -or $_.StartsWith("FAIL ${id}: ", [StringComparison]::Ordinal) })
    if ($hits.Count -ne 1) { return @{ n = $hits.Count; status = ''; detail = ''; line = ($hits -join ' || ') } }
    $l = [string]$hits[0]
    $at = $l.IndexOf(' -- ', [StringComparison]::Ordinal)
    return @{ n = 1; status = $l.Substring(0, 4); detail = $(if ($at -ge 0) { $l.Substring($at + 4) } else { '' }); line = $l }
}
# cert-2 detail 'notAfter=<UTC> daysLeft=<d.dd> (must exceed 30)' → @{ notAfter; daysLeft }(형식이 다르면 $null)
function Get-Cert2Values([string]$detail) {
    $m = [regex]::Match("$detail", '\AnotAfter=(\S+) daysLeft=(-?\d+\.\d\d) \(must exceed 30\)\z')
    if (-not $m.Success) { return $null }
    return @{ notAfter = $m.Groups[1].Value; daysLeft = [double]::Parse($m.Groups[2].Value, $inv) }
}
# 공통: 끝까지 돌았다 · 응답표 밖 호출 0 · 모든 호출이 픽스처 kubeconfig를 --kubeconfig로 명시 · get만
function Assert-Run([string]$id, $r, [string]$dir) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    Assert "${id}-end: harness ran to completion (last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and [regex]::IsMatch($last, '\A\d+ passed, \d+ failed, \d+ skipped\z')) (Format-Result $r)
    $calls = @(Get-Calls $dir)
    $bad = @($calls | Where-Object { (Test-Same ([string]$_['served']) 'default') -or -not ([string]$_['key']).StartsWith('get ', [StringComparison]::Ordinal) -or -not [string]::Equals([string]$_['kubeconfig'], (Join-Path $dir 'kubeconfig.yaml'), [StringComparison]::OrdinalIgnoreCase) })
    Assert "${id}-calls: every kubectl call is a fixture 'get' with the fixture kubeconfig named explicitly" ($calls.Count -gt 0 -and $bad.Count -eq 0) "calls=$($calls.Count) bad: $((@($bad | ForEach-Object { "$($_['served']):$($_['key'])" })) -join ' || ')"
}
# cert-2: 상태 · notAfter 문자열(정확히) · daysLeft(이 테스트가 같은 UTC로 계산한 값과 ±0.01일) · 필요하면 detail 조각
function Assert-Cert2([string]$name, $r, [string]$wantStatus, [string]$wantNotAfterUtc) {
    $x = Get-IdResult $r 'cert-2'
    $v = Get-Cert2Values $x.detail
    $bad = @()
    if ($x.n -ne 1) { $bad += "expected exactly 1 cert-2 line, got $($x.n)" }
    elseif (-not (Test-Same $x.status $wantStatus)) { $bad += "status $($x.status) (expected $wantStatus)" }
    if ($null -eq $v) { $bad += 'detail is not "notAfter=<UTC> daysLeft=<d.dd> (must exceed 30)"' }
    else {
        if (-not (Test-Same $v.notAfter $wantNotAfterUtc)) { $bad += "notAfter=$($v.notAfter) (expected $wantNotAfterUtc)" }
        $want = ([DateTime]::ParseExact($wantNotAfterUtc, $utcFmt, $inv, [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal) - [DateTime]::UtcNow).TotalDays
        if ([Math]::Abs($v.daysLeft - $want) -gt 0.01) { $bad += "daysLeft=$($v.daysLeft) (expected about $($want.ToString('0.00', $inv)) from the exact UTC)" }
    }
    Assert $name ($bad.Count -eq 0) "$($bad -join '; ') :: line=[$($x.line)]"
}
function Import-HarnessModule([string]$path) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "harness does not parse: $(@($errors)[0].Message)" }
    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $text = (@($funcs | ForEach-Object { $_.Extent.Text }) -join "`n") + "`nExport-ModuleMember -Function @()`n"
    return (New-Module -Name ('ingressharness-' + [guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($text)))
}

$tz = [TimeZoneInfo]::Local
$off = $tz.GetUtcOffset([DateTime]::UtcNow)
Write-Host "NOTE: local time zone $($tz.Id) (UTC$(if ($off -lt [TimeSpan]::Zero) { '-' } else { '+' })$($off.Duration().ToString('hh\:mm', $inv))) -- the pre-fix string round trip shifted a Kind=Utc notAfter by this offset; with offset 00:00 cases I01, I02, I04 and I06 cannot reproduce it"

try {
    # ================= 재현(지금 코드에서 빨강이어야 한다 — 로컬 오프셋이 0이 아닌 머신) =================
    Test-Case 'I01' 'reproduction: notAfter 2026-12-08T05:12:34Z -> cert-2 reports exactly that UTC instant and the matching days left' {
        $d = New-Fixture (New-Responses '2026-12-08T05:12:34Z')
        $r = Invoke-Harness $d
        Assert-Run 'I01' $r $d
        $c1 = Get-IdResult $r 'cert-1'
        Assert 'I01-1: cert-1 PASS (Certificate Ready=True -- the fixture reaches cert-2)' ($c1.n -eq 1 -and (Test-Same $c1.status 'PASS')) "line=[$($c1.line)]"
        $wantDays = ([DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Utc) - [DateTime]::UtcNow).TotalDays
        if ([Math]::Abs($wantDays - 30) -lt 0.02) { Write-Host 'NOTE: I01 runs within 30 min of the 30-day boundary; the asserted status can flip between the harness and this test reading UtcNow (I02/I03 cover the boundary deterministically)' }
        $status = if ($wantDays -gt 30) { 'PASS' } else { 'FAIL' }
        Assert-Cert2 'I01-2: cert-2 notAfter=2026-12-08T05:12:34Z exactly (not shifted by the local offset), daysLeft from that instant' $r $status '2026-12-08T05:12:34Z'
    }
    # 30일 경계(TotalDays > 30, 내림 없음): +30일 30분 → PASS, +30일 -30분 → FAIL. 수정 전 코드는 +09:00 머신에서 앞의 것도 FAIL로 냈다.
    Test-Case 'I02' 'boundary: notAfter = now + 30 days + 30 min (Z) -> PASS' {
        $na = [DateTime]::UtcNow.AddDays(30).AddMinutes(30).ToString($utcFmt, $inv)
        $d = New-Fixture (New-Responses $na)
        $r = Invoke-Harness $d
        Assert-Run 'I02' $r $d
        Assert-Cert2 "I02-1: cert-2 PASS just past 30 days (notAfter=$na)" $r 'PASS' $na
    }
    Test-Case 'I03' 'boundary: notAfter = now + 30 days - 30 min (Z) -> FAIL' {
        $na = [DateTime]::UtcNow.AddDays(30).AddMinutes(-30).ToString($utcFmt, $inv)
        $d = New-Fixture (New-Responses $na)
        $r = Invoke-Harness $d
        Assert-Run 'I03' $r $d
        Assert-Cert2 "I03-1: cert-2 FAIL just under 30 days (notAfter=$na)" $r 'FAIL' $na
    }
    # 다른 표기: 오프셋 없는 ISO(Kind=Unspecified → UTC로 간주) · 다른 오프셋(Kind=Local → ToUniversalTime) · ISO가 아닌 문자열(문자열 경로)
    Test-Case 'I04' 'notAfter without an offset (2026-12-08T05:12:34) -> read as UTC, never as local time' {
        $d = New-Fixture (New-Responses '2026-12-08T05:12:34')
        $r = Invoke-Harness $d
        Assert-Run 'I04' $r $d
        $status = if ((([DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Utc) - [DateTime]::UtcNow).TotalDays) -gt 30) { 'PASS' } else { 'FAIL' }
        Assert-Cert2 'I04-1: cert-2 notAfter=2026-12-08T05:12:34Z' $r $status '2026-12-08T05:12:34Z'
    }
    Test-Case 'I05' 'notAfter with an explicit offset (2026-12-08T00:12:34-05:00) -> the same UTC instant' {
        $d = New-Fixture (New-Responses '2026-12-08T00:12:34-05:00')
        $r = Invoke-Harness $d
        Assert-Run 'I05' $r $d
        $status = if ((([DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Utc) - [DateTime]::UtcNow).TotalDays) -gt 30) { 'PASS' } else { 'FAIL' }
        Assert-Cert2 'I05-1: cert-2 notAfter=2026-12-08T05:12:34Z' $r $status '2026-12-08T05:12:34Z'
    }
    Test-Case 'I06' 'notAfter that ConvertFrom-Json keeps as a string (2026-12-08 05:12:34) -> parsed as UTC (AssumeUniversal)' {
        $d = New-Fixture (New-Responses '2026-12-08 05:12:34')
        $r = Invoke-Harness $d
        Assert-Run 'I06' $r $d
        $status = if ((([DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Utc) - [DateTime]::UtcNow).TotalDays) -gt 30) { 'PASS' } else { 'FAIL' }
        Assert-Cert2 'I06-1: cert-2 notAfter=2026-12-08T05:12:34Z' $r $status '2026-12-08T05:12:34Z'
    }
    Test-Case 'I07' 'notAfter that is not a date -> cert-2 FAIL (unparseable)' {
        $d = New-Fixture (New-Responses 'not-a-date')
        $r = Invoke-Harness $d
        Assert-Run 'I07' $r $d
        $x = Get-IdResult $r 'cert-2'
        Assert 'I07-1: cert-2 FAIL says unparseable and shows the value' ($x.n -eq 1 -and (Test-Same $x.status 'FAIL') -and (Has-Text $x.detail 'unparseable') -and (Has-Text $x.detail 'not-a-date')) "line=[$($x.line)]"
    }
    Test-Case 'I08' 'no status.notAfter -> cert-2 FAIL (absent)' {
        $d = New-Fixture (New-Responses $null)
        $r = Invoke-Harness $d
        Assert-Run 'I08' $r $d
        $x = Get-IdResult $r 'cert-2'
        Assert 'I08-1: cert-2 FAIL says status.notAfter is absent' ($x.n -eq 1 -and (Test-Same $x.status 'FAIL') -and (Has-Text $x.detail 'status.notAfter is absent')) "line=[$($x.line)]"
    }

    # ================= 함수: ConvertTo-UtcInstant =================
    Test-Case 'F01' 'ConvertTo-UtcInstant: DateTime (Utc / Local / Unspecified), DateTimeOffset and strings all become the same UTC instant; others are errors' {
        $mod = $null; $modErr = ''
        try { $mod = Import-HarnessModule $harnessPath } catch { $modErr = $_.Exception.Message }
        $has = ($null -ne $mod) -and [bool](& $mod { $null -ne (Get-Command -Name 'ConvertTo-UtcInstant' -CommandType Function -ErrorAction SilentlyContinue) })
        Assert 'F01-0: the harness defines ConvertTo-UtcInstant' $has "missing $modErr"
        if ($has) {
            $want = '2026-12-08T05:12:34Z'
            $utc = [DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Utc)
            $rows = @(
                @{ name = 'DateTime Kind=Utc'; value = $utc; want = $want },
                @{ name = 'DateTime Kind=Local (same instant)'; value = $utc.ToLocalTime(); want = $want },
                @{ name = 'DateTime Kind=Unspecified (taken as UTC)'; value = [DateTime]::new(2026, 12, 8, 5, 12, 34, [DateTimeKind]::Unspecified); want = $want },
                @{ name = 'DateTimeOffset +09:00'; value = [DateTimeOffset]::new(2026, 12, 8, 14, 12, 34, [TimeSpan]::FromHours(9)); want = $want },
                @{ name = "string 'Z'"; value = '2026-12-08T05:12:34Z'; want = $want },
                @{ name = 'string +09:00'; value = '2026-12-08T14:12:34+09:00'; want = $want },
                @{ name = 'string without offset (ISO)'; value = '2026-12-08T05:12:34'; want = $want },
                @{ name = 'string without offset (space)'; value = '2026-12-08 05:12:34'; want = $want },
                @{ name = 'string garbage'; value = 'not-a-date'; want = 'error' },
                @{ name = 'null'; value = $null; want = 'error' },
                @{ name = 'integer'; value = 42; want = 'error' }
            )
            $bad = @()
            foreach ($row in $rows) {
                $res = & $mod { param($v) ConvertTo-UtcInstant $v } $row.value
                $got = if ($null -ne $res.utc) { "$($res.utc.ToString($utcFmt, $inv)) kind=$($res.utc.Kind)" } else { 'error' }
                $exp = if (Test-Same $row.want 'error') { 'error' } else { "$($row.want) kind=Utc" }
                if (-not (Test-Same $got $exp)) { $bad += "$($row.name): got [$got] (want [$exp])" }
                if ((Test-Same $exp 'error') -and [string]::IsNullOrEmpty([string]$res.error)) { $bad += "$($row.name): no error text" }
            }
            Assert 'F01-1: the conversion table (every accepted form -> 2026-12-08T05:12:34Z Kind=Utc; garbage / null / integer -> error)' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }

    foreach ($o in $script:only) {
        if (@($script:known | Where-Object { Test-Same $_ $o }).Count -eq 0) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in INGRESS_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
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
