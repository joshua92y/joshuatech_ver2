# tests/platform/identity.tests.ps1 하네스 단위 테스트(T078 — US4 플랫폼 신원 단언, test-first).
# Run: pwsh -NoProfile -File tests/scripts/identity-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/data-tests.tests.ps1과 같은 구조).
# 배치 이유: 러너 tests/platform/run-platform-tests.ps1은 자기 폴더의 *.tests.ps1을 발견·실행하므로 이 파일은 tests/scripts/에 둔다
#   (run-all의 identity-harness 슬롯이 이 파일을 직접 실행한다 — 등록은 컨트롤러, 설계 D8 ⑧ · D12).
#
# 설계 정본: specs/003-platform-foundation/design/t077-design.md §1-2(T078 id · 오늘 기대) · D5(실패 분류 접두) · D8(하네스 · 짝 하네스) ·
#   D9(빨강 확인 — 빌더는 오프라인 시험만) · D10(노출 0 · 정리).
# 무엇을 지키나:
#   - 오늘 상태(C01): 22 단언이 §1-2 「오늘 기대」와 줄마다 같다(사유 글자까지 — FAIL 사유 앞에는 D5 분류 접두) — `6 passed, 12 failed, 4 skipped` · exit 1.
#   - T080 뒤 상태(C02): Ingress · Authentik 공개 경로 · authz-assert Job이 갖춰지면 18 PASS · SKIP 4(자격 블록 전용 2 · 운영자 수동 2) · exit 0.
#   - 변이(C03–C07): acc-1(302/403 × Ingress 유무 · Location 다른 호스트) · 공개 200 text/html · JSON인데 판정 키 없음 · JSON 배열 루트 · 리다이렉트 ·
#     curl exit 6 · 7 · 28 · 5xx · 서명이 어긋난 404(18 B · sha256 · cf-cache-status HIT — [gate] 아님) · Job(옛 id만 · 중복 · SUMMARY 불일치 ·
#     추적 밖 FAIL · 로그 조회 실패) · Ingress 조회 실패 → 해당 id만 FAIL이고 분류 접두([gate] · [env] · [product])가 맞다.
#   - 게이트(C08–C12): whoami ≠ agent-view · KUBECONFIG 없음 · 경로 목록 → kubectl 단언만 그 사유로 FAIL(acc-1은 ing-1 짝이라 [env]) · HTTP 단언은
#     계속 돈다. curl 판 < 7.84 · 함수/별칭 가림 · curl 없음 → tool-1 FAIL + HTTP 단언 전부 [env](curl 호출 없음).
#   - 음성 사례(r1 — C-5 · 리뷰 C 변이 I01–I07이 살아남은 빈자리): Ingress가 있어도 acc-1 403 + Location · 403 application/json은 [product](빈 PASS 아님 —
#     C13 · C14) · m2m 401 + Location · xchg-0 405 + Location은 FAIL(C13) · 옛 id만 + 옛 id FAIL은 fga [product]([gate] until T082 아님 — 「잘못된 이유의
#     빨강」을 가리지 않게, C13) · whoami = 다른 서비스 계정(kube-system:default) · 닮은 이름(agent-view-x)은 gate-3 FAIL(정확 일치만 — C15).
#   - curl env 가드(r1 — B-9 · C16 · F07): 이름 끝 _PROXY(대소문자 무관) · SSLKEYLOGFILE · CURL_CA_BUNDLE · SSL_CERT_FILE · SSL_CERT_DIR가 있으면 tool-1은
#     PASS 그대로이고 HTTP 단언 전부 `[guard] curl-env-not-allowed <정렬된 이름>`(값 출력 0) · curl 호출은 판 검사 1번뿐.
#   - 가드(G01 · G02): 미끼 curl · 미끼 kubectl(r1 — A-11)이 심보다 앞이면 실행 거부 · 자식 env에서 curl env 가드 대상 이름을 지운다(개발자 창의 프록시 env가
#     모든 E2E 케이스를 [guard]로 바꾸지 않게 — 가드를 시험하는 C16만 -extraEnv로 다시 넣는다).
#   - 모든 실행 공통(Assert-Run): 끝 줄 요약 · 22 id 정확히 한 번씩 · `<STATUS> <id> -- <근거>` 꼴 · FAIL은 분류 접두 · SKIP은 두 문구뿐 ·
#     kubectl 호출 = 읽기 전용 동사(get · logs · auth whoami) + --kubeconfig 명시 + --request-timeout · curl 호출 = 글자 고정 argv
#     (`-q -s -S --max-time 20 --proto =https -o <tmp> -w @<tmp> <url>` — `-q` 첫 인자 · 금지 플래그 0) · 형식 파일 내용 정확 일치 ·
#     임시 파일은 픽스처 tmp/ 아래 identity-tests-* 이고 실행 뒤 0개 · 실행마다 만든 바늘(본문 · Location 쿼리 · Job 로그 EVIDENCE)이 출력에 0.
#   - 함수(F*): 교환 판정 Test-ExchangeClaims(aud 배열 · 다른 aud · tenant_id 없음 · 꼴 아님 · 299/301 · B에서 act 있음 PASS · A에서 act.sub 다름 FAIL ·
#     깨진 JWT) · Test-ExchangeRejection(invalid_target 아님) · 합성 토큰 바늘이 반환 문구에 0 · Test-JobLog · Get-JobIdState · Traefik 404 서명 ·
#     Access Location · 안전 URL · curl 판 · write-out 파싱 · Ingress host 일치 · 본문 필드 접근(배열 언래핑 없음).
#
# 방식 1 — E2E 케이스(C*): 케이스마다 임시 픽스처(%TEMP%/identitytest-<guid>)에
#     하네스 사본  repo/tests/platform/identity.tests.ps1  (IDENTITY_HARNESS_SCRIPT가 있으면 그 파일의 사본)
#     가짜 kubectl bin/kubectl.cmd 심 → bin/fake-kubectl.ps1 · 응답표 responses.tsv + resp/ · 기록 calls.log(data-tests.tests.ps1과 같은 동작)
#     가짜 curl    bin/curl.cmd 심 → bin/fake-curl.ps1 · 응답표 curl-responses.tsv + curl-resp/ · 기록 curl-calls.log(심 = data-tests의
#                  FAKE_KUBECTL_ARGV 꼴 → FAKE_CURL_ARGV; -w @<형식 파일>을 읽어 그 순서로 값을 낸다 · -o 파일에 본문을 쓴다)
#   를 만들고 하네스 사본을 자식 pwsh로 실행한다(KUBECONFIG = 더미 파일, TMP/TEMP = 픽스처 tmp/, 실행마다 시간 상한, stdout UTF-8 디코드,
#   curl env 가드 대상 이름은 자식 env에서 지운다 — 케이스가 -extraEnv로 준 것만 남는다).
#   자식 PATH = 픽스처 bin + 지금 PATH에서 kubectl.* · oci.* · curl.* 파일이 있는 디렉터리를 뺀 나머지 — 실제 kubectl · curl에 닿지 않는다(네트워크 ·
#   클러스터 접근 0). 실행마다 자식 PATH에서 처음 찾히는 kubectl · curl이 픽스처 심인지(curl 없는 케이스는 curl이 안 찾히는지) 확인하고, 아니면
#   하네스를 실행하지 않는다(G01이 이 거부를 시험한다). 호출 기록 수 = 기대 수로 실제 도구가 불리지 않았음을 한 번 더 증명한다.
# 방식 2 — 함수 케이스(F*) · 상수(S02): 하네스 파일을 AST로 읽어 최상위 함수 정의와 몇 개 상수만 동적 모듈 안에 정의한다(최상위 문장은 실행하지 않는다).
# 방식 3 — 정적(S01): 하네스 원문 · AST(머리 주석 · 쓰기 동사 · tasks.md 게이트 · SKIP 문구 · 교환 판정 함수 미호출 · 다른 HTTP 클라이언트 · 금지 curl 플래그 ·
#   curl env 가드가 env 이름만 읽는지).
#
# 환경 변수:
#   IDENTITY_HARNESS_SCRIPT      시험할 하네스(기본 tests/platform/identity.tests.ps1) — 변이 시험에서 사본을 가리킨다. 설정되면 요약 줄 끝에
#                                ' (script override: <파일 이름>)'이 붙어 run-all의 'N passed, 0 failed' 판정을 통과하지 못한다.
#   IDENTITY_HARNESS_TESTS_ONLY  쉼표로 나눈 케이스 ID(예: C01,F02)만 실행한다. 요약 줄 끝에 ' (filtered: …)'가 붙는다. 모르는 ID가 있으면 FAIL.
# 실행 시간: 무거운 E2E 케이스 하나에 가짜 호출 13–14번(호출마다 cmd + pwsh 하나) — 이 PC에서 케이스당 약 8–12 s, 전체 약 2–3분.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:IDENTITY_HARNESS_SCRIPT)
$harnessPath = if ($scriptOverride) { $env:IDENTITY_HARNESS_SCRIPT } else { Join-Path $repo 'tests/platform/identity.tests.ps1' }
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$sep = [IO.Path]::PathSeparator
$inv = [Globalization.CultureInfo]::InvariantCulture
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:known = @()
$script:only = @()
$script:needle = ''
if (-not [string]::IsNullOrWhiteSpace($env:IDENTITY_HARNESS_TESTS_ONLY)) {
    $script:only = @($env:IDENTITY_HARNESS_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
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
# 실행마다 새 바늘(소스 · 기대값에 바늘 값 리터럴 0 — D10 ⑧과 같은 규율)
function New-Needle { return 'JTIDNEEDLE' + [guid]::NewGuid().ToString('N').Substring(0, 16) }

# 케이스 격리 + 선택 실행. 한 케이스에서 예외가 나도 나머지는 계속 실행된다.
function Test-Case([string]$id, [string]$title, [scriptblock]$body) {
    $caseId = $id   # 본문은 이 함수 범위에서 dot-source로 돈다 — 본문이 $id를 덮어도 되게
    $script:known += $caseId
    if ($script:only.Count -gt 0 -and -not (In-Set $script:only $caseId)) { return }
    Write-Host "-- ${caseId}: $title"
    $caseWatch = [Diagnostics.Stopwatch]::StartNew()
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $caseId -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    Write-Host "   [$caseId took $($caseWatch.Elapsed.TotalSeconds.ToString('0.0', $inv))s]"
}

# ---------- 가짜 명령줄 나누기(두 가짜가 공유 — data-tests.tests.ps1과 같은 본문) ----------
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

# ---------- 가짜 kubectl(픽스처 bin/fake-kubectl.ps1 — data-tests.tests.ps1과 같은 동작) ----------
$fakeKubectl = @'
# 가짜 kubectl(tests/scripts/identity-tests.tests.ps1이 픽스처 bin/에 쓴다). 실제 클러스터에 닿지 않는다.
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

# ---------- 가짜 curl(픽스처 bin/fake-curl.ps1) ----------
$fakeCurl = @'
# 가짜 curl(tests/scripts/identity-tests.tests.ps1이 픽스처 bin/에 쓴다). 네트워크에 닿지 않는다.
# 입력: ..\curl-responses.tsv(줄 = 번호 TAB 종료코드 TAB key — key = URL(마지막 인자) 또는 '--version') + ..\curl-resp\<번호>.meta
#   (status · content-type · location · cf-cache-status 네 줄) · .body(본문 바이트 — -o 파일로 쓴다, 0바이트면 파일을 만들지 않는다) ·
#   .out(--version stdout) · .err(stderr)
# 기록: ..\curl-calls.log(줄 = served TAB 종료코드 TAB 형식 파일 내용(CR · LF · TAB → <CR> · <LF> · <TAB>) TAB argv[0] TAB argv[1] …)
# -w @<형식 파일>을 읽어 그 순서로 값을 낸다: %{http_code} · %{content_type} · %{size_download} · %header{<이름>} · 역슬래시 n/r/t · %%.
# 종료 코드 ≠ 0(6 · 7 · 28 …)이면 http_code 000 · 나머지 빈 값으로 -w를 내고 본문 파일은 쓰지 않는다(실제 curl도 실패에서 -w를 낸다).
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetDirectoryName($PSScriptRoot)
$utf8 = [Text.UTF8Encoding]::new($false)
'@ + "`n" + $splitCommandLine + @'

$argv = Split-CommandLine ([string]$env:FAKE_CURL_ARGV)
$ord = [StringComparison]::Ordinal
$isVersion = $false
foreach ($x in $argv) { if ([string]::Equals($x, '--version', $ord)) { $isVersion = $true } }
$key = ''
if ($isVersion) { $key = '--version' } elseif ($argv.Count -gt 0) { $key = $argv[$argv.Count - 1] }
$outFile = $null; $fmtFile = $null
for ($i = 0; $i -lt $argv.Count - 1; $i++) {
    if ([string]::Equals($argv[$i], '-o', $ord)) { $outFile = $argv[$i + 1] }
    if ([string]::Equals($argv[$i], '-w', $ord) -and $argv[$i + 1].StartsWith('@', $ord)) { $fmtFile = $argv[$i + 1].Substring(1) }
}
$fmt = ''
if ($null -ne $fmtFile -and [IO.File]::Exists($fmtFile)) { $fmt = [IO.File]::ReadAllText($fmtFile, $utf8) }
$hit = $null
foreach ($row in [IO.File]::ReadAllLines([IO.Path]::Combine($root, 'curl-responses.tsv'), $utf8)) {
    $f = $row.Split([char[]]@([char]9), 3)
    if ($f.Count -eq 3 -and [string]::Equals($f[2], $key, $ord)) { $hit = $f; break }
}
$served = 'default'; $code = 2; $stdout = ''; $stderr = "fake-curl: no fixture response for: $key"
if ($null -ne $hit) {
    $served = 'fixture'; $code = [int]$hit[1]
    $base = [IO.Path]::Combine($root, 'curl-resp', $hit[0])
    $stderr = [IO.File]::ReadAllText($base + '.err', $utf8)
    if ($isVersion) { $stdout = [IO.File]::ReadAllText($base + '.out', $utf8) }
    else {
        $meta = [IO.File]::ReadAllText($base + '.meta', $utf8).Split([char[]]@([char]10))
        $body = [IO.File]::ReadAllBytes($base + '.body')
        $vals = @{ 'http_code' = $meta[0]; 'content_type' = $meta[1]; 'size_download' = [string]$body.Length; 'location' = $meta[2]; 'cf-cache-status' = $meta[3] }
        if ($code -ne 0) { $vals = @{ 'http_code' = '000'; 'content_type' = ''; 'size_download' = '0'; 'location' = ''; 'cf-cache-status' = '' } }
        elseif ($null -ne $outFile -and $body.Length -gt 0) { [IO.File]::WriteAllBytes($outFile, $body) }
        $sb = [Text.StringBuilder]::new(); $j = 0
        while ($j -lt $fmt.Length) {
            $c = $fmt[$j]
            if ($c -eq [char]92 -and $j + 1 -lt $fmt.Length) {
                $n = $fmt[$j + 1]
                if ($n -ceq [char]'n') { [void]$sb.Append([char]10); $j += 2; continue }
                if ($n -ceq [char]'r') { [void]$sb.Append([char]13); $j += 2; continue }
                if ($n -ceq [char]'t') { [void]$sb.Append([char]9); $j += 2; continue }
            }
            if ($c -eq [char]37) {
                if ($j + 1 -lt $fmt.Length -and $fmt[$j + 1] -eq [char]37) { [void]$sb.Append([char]37); $j += 2; continue }
                $m = [regex]::Match($fmt.Substring($j), '\A%(?:\{([a-z_]+)\}|header\{([A-Za-z0-9-]+)\})')
                if ($m.Success) {
                    $name = if ($m.Groups[1].Success) { $m.Groups[1].Value } else { $m.Groups[2].Value.ToLowerInvariant() }
                    if ($vals.ContainsKey($name)) { [void]$sb.Append([string]$vals[$name]) }
                    $j += $m.Length; continue
                }
            }
            [void]$sb.Append($c); $j++
        }
        $stdout = $sb.ToString()
    }
}
$fmtEsc = $fmt.Replace([string][char]13, '<CR>').Replace([string][char]10, '<LF>').Replace([string][char]9, '<TAB>')
$line = "$served`t$code`t$fmtEsc`t" + ($argv -join "`t")
for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::AppendAllText([IO.Path]::Combine($root, 'curl-calls.log'), $line + "`n", $utf8); break } catch { Start-Sleep -Milliseconds 25 } }
if (-not [string]::IsNullOrEmpty($stderr)) { [Console]::Error.Write($stderr) }
if (-not [string]::IsNullOrEmpty($stdout)) { [Console]::Out.Write($stdout) }
exit $code
'@

# .cmd 심: CRLF, BOM 없음(@echo off가 1행이어야 한다). 받은 명령줄(%*)을 환경 변수로 넘기고 현재 pwsh로 가짜 스크립트를 실행해 종료 코드를 돌려준다.
#   하네스의 curl argv에는 %가 없다(형식은 파일로 넘긴다 — 설계 D8 ③) — %*를 지나도 글자가 바뀌지 않는다.
$crlf = "`r`n"
function New-Shim([string]$envName, [string]$scriptName) {
    return (@(
            '@echo off'
            "set `"$envName=%*`""
            "`"$([Environment]::ProcessPath)`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0$scriptName`""
            'exit /b %ERRORLEVEL%'
        ) -join $crlf) + $crlf
}
# 가림 케이스의 진입 스크립트: 함수 · 별칭 curl을 전역에 만든 뒤 하네스 사본을 부른다(하네스가 이름 curl을 부르면 throw — 부르지 않아야 한다)
$bootstrapFunction = @'
function global:curl { throw 'the shadowing curl function must never be called' }
& (Join-Path $PSScriptRoot 'repo/tests/platform/identity.tests.ps1')
exit $LASTEXITCODE
'@
$bootstrapAlias = @'
Set-Alias -Name curl -Value Get-Date -Scope Global
& (Join-Path $PSScriptRoot 'repo/tests/platform/identity.tests.ps1')
exit $LASTEXITCODE
'@

# ---------- 자식 PATH(실제 kubectl · oci · curl을 가린다 — data-tests.tests.ps1과 같은 규칙) ----------
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
# 하네스 curl env 가드(r1 — B-9)의 대상 이름 — 짝 하네스 사본(자식 env 정리 · G02 탐침용; 하네스 함수 자체는 F07이 표로 본다):
#   이름 끝 _PROXY(대소문자 무관 — http_proxy · HTTPS_PROXY · ALL_PROXY · NO_PROXY …) · 아래 넷(대소문자 무관)
$curlGuardExact = @('SSLKEYLOGFILE', 'CURL_CA_BUNDLE', 'SSL_CERT_FILE', 'SSL_CERT_DIR')
function Test-CurlGuardEnvName([string]$n) {
    if ([string]::IsNullOrEmpty($n)) { return $false }
    if ($n.EndsWith('_PROXY', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    foreach ($x in $curlGuardExact) { if ([string]::Equals($n, $x, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}
# G02 자식 env 탐침(진입 스크립트): 위 대상 이름만(값 0) ordinal 정렬로 한 줄씩 내고 끝 줄 probe-done
$envProbe = @'
$exact = @('SSLKEYLOGFILE', 'CURL_CA_BUNDLE', 'SSL_CERT_FILE', 'SSL_CERT_DIR')
$hit = [Collections.Generic.List[string]]::new()
foreach ($k in @([Environment]::GetEnvironmentVariables().Keys)) {
    $n = [string]$k
    $bad = $n.EndsWith('_PROXY', [StringComparison]::OrdinalIgnoreCase)
    foreach ($x in $exact) { if ([string]::Equals($n, $x, [StringComparison]::OrdinalIgnoreCase)) { $bad = $true } }
    if ($bad) { $hit.Add($n) }
}
$hit.Sort([StringComparer]::Ordinal)
foreach ($n in $hit) { [Console]::Out.WriteLine($n) }
[Console]::Out.WriteLine('probe-done')
exit 0
'@

# ---------- 응답표 조각(kubectl) ----------
function Json($o) { return (ConvertTo-Json -InputObject $o -Depth 30 -Compress) }
function R-Json($o) { return @{ out = (Json $o); err = ''; code = 0 } }
function R-None { return @{ out = ''; err = ''; code = 0 } }   # --ignore-not-found + 객체 없음 = 빈 출력 · exit 0
function R-Raw([string]$out) { return @{ out = $out; err = ''; code = 0 } }
function R-Err([string]$err, [int]$code = 1) { return @{ out = ''; err = $err; code = $code } }
function New-List([object[]]$items) { return [ordered]@{ apiVersion = 'v1'; kind = 'List'; items = @(@($items) | Where-Object { $null -ne $_ }) } }
function New-WhoamiResp([string]$user = $expectedUser) { return R-Json ([ordered]@{ apiVersion = 'authentication.k8s.io/v1'; kind = 'SelfSubjectReview'; status = [ordered]@{ userInfo = [ordered]@{ username = $user } } }) }
function New-Ingress([string]$ns, [string]$name, [string[]]$hosts) {
    $rules = @(foreach ($h in $hosts) { [ordered]@{ host = $h; http = [ordered]@{ paths = @([ordered]@{ path = '/'; pathType = 'Prefix'; backend = [ordered]@{ service = [ordered]@{ name = 'authentik-server'; port = [ordered]@{ number = 9000 } } } }) } } })
    return [ordered]@{ apiVersion = 'networking.k8s.io/v1'; kind = 'Ingress'; metadata = [ordered]@{ name = $name; namespace = $ns }; spec = [ordered]@{ ingressClassName = 'traefik'; rules = $rules } }
}
function New-Job { return [ordered]@{ apiVersion = 'batch/v1'; kind = 'Job'; metadata = [ordered]@{ name = 'authz-assert'; namespace = 'jt-dev' }; status = [ordered]@{ succeeded = 1 } } }
$authzOldIds = @('check-allowed', 'cross-tenant-false')
$fgaIds = @('check-member-allowed', 'check-owner-allowed', 'cross-tenant-member-false', 'cross-tenant-owner-false')
# Job 로그(README 로그 계약 모양 + EVIDENCE/NOTE 보조 줄 — 바늘이 든다). $override: id → 'PASS'/'FAIL', $duplicate: 두 번 내는 id,
#   $summary: 'auto'(세어서 냄) · $null(없음) · 문자열(그대로)
function New-AuthzLog([string[]]$ids = @($authzOldIds + $fgaIds), [hashtable]$override = @{}, [string[]]$duplicate = @(), $summary = 'auto') {
    $lines = @('NOTE: authz-assert start', "EVIDENCE: openfga probe tuples $script:needle")
    $pass = 0; $fail = 0
    foreach ($id in $ids) {
        $st = if ($override.ContainsKey($id)) { [string]$override[$id] } else { 'PASS' }
        $times = if (In-Set $duplicate $id) { 2 } else { 1 }
        for ($i = 0; $i -lt $times; $i++) {
            if (Test-Same $st 'PASS') { $pass++ } else { $fail++ }
            $lines += "RESULT: $st $id evidence-$id $script:needle"
        }
    }
    if ($summary -is [string] -and (Test-Same $summary 'auto')) { $lines += "SUMMARY: pass=$pass fail=$fail" }
    elseif ($null -ne $summary) { $lines += [string]$summary }
    return (($lines -join "`n") + "`n")
}
# 조회 key 표(가짜 kubectl이 보는 모양 — --kubeconfig · --request-timeout 제거 후)
$Q = @{
    who  = 'auth whoami -o json'
    ing  = 'get ingresses.networking.k8s.io -n identity -o json'
    job  = '-n jt-dev get jobs.batch authz-assert --ignore-not-found -o json'
    logs = '-n jt-dev logs job/authz-assert --tail=50'
}
# 오늘 모양: ns identity Ingress 0 · authz-assert Job 없음(로그는 조회하지 않아야 한다 — 표에 없다)
function New-TodayKube {
    $r = [ordered]@{}
    $r[$Q.who] = New-WhoamiResp
    $r[$Q.ing] = R-Json (New-List @())
    $r[$Q.job] = R-None
    return $r
}
# T080 · T082 · 렌더 뒤 모양: Authentik Ingress · Job(옛 id 2 + 새 id 4 전부 PASS)
function New-GoodKube {
    $r = New-TodayKube
    $r[$Q.ing] = R-Json (New-List @((New-Ingress 'identity' 'authentik' @('auth.joshuatech.dev'))))
    $r[$Q.job] = R-Json (New-Job)
    $r[$Q.logs] = R-Raw (New-AuthzLog)
    return $r
}

# ---------- 응답표 조각(curl) ----------
$U = [ordered]@{
    acc1  = 'https://auth.joshuatech.dev/if/admin/'
    acc2  = 'https://admin.joshuatech.dev/identity-admin/admin/'
    acc3  = 'https://identity-m2m-prod.joshuatech.dev/health'
    pub1  = 'https://auth.joshuatech.dev/api/v3/root/config/'
    pub2  = 'https://auth.joshuatech.dev/api/v3/flows/executor/default-authentication-flow/'
    pub3  = 'https://auth.joshuatech.dev/application/o/identity-admin/.well-known/openid-configuration'
    pub4  = 'https://auth.joshuatech.dev/application/o/identity-admin/jwks/'
    pub5  = 'https://auth.joshuatech.dev/.well-known/oauth-authorization-server/application/o/identity-admin'
    xchg0 = 'https://auth.joshuatech.dev/application/o/token/'
}
$expectedFmt = '%{http_code}\n%{content_type}\n%{size_download}\n%header{location}\n%header{cf-cache-status}\n'
function C-Resp([string]$status, [string]$ctype, [string]$body = '', [string]$location = '', [string]$cf = 'DYNAMIC') { return @{ status = $status; ctype = $ctype; location = $location; cf = $cf; body = $body; code = 0; err = ''; out = '' } }
function C-Exit([int]$code, [string]$err) { return @{ status = ''; ctype = ''; location = ''; cf = ''; body = ''; code = $code; err = $err; out = '' } }
function C-Version([string]$version) { return @{ status = ''; ctype = ''; location = ''; cf = ''; body = ''; code = 0; err = ''; out = "curl $version (x86_64-w64-mingw32) libcurl/$version Schannel zlib/1.3`nRelease-Date: 2023-10-11`nProtocols: http https`n" } }
function C-Traefik404 { return C-Resp '404' 'text/plain; charset=utf-8' "404 page not found`n" }
# Access 로그인 302 — Location 쿼리에 바늘(출력 0이어야 한다)
function C-AccessLogin([string]$forHost, [string]$loginHost = 'joshua-tech.cloudflareaccess.com', [string]$loginPath = '/cdn-cgi/access/login/') {
    return C-Resp '302' '' '' ("https://$loginHost$loginPath$forHost" + '?kid=0123abcd&redirect_url=%2F&meta=' + $script:needle)
}
function C-Access401 { return C-Resp '401' 'text/html' "<!DOCTYPE html><html><body>Unauthorized $script:needle</body></html>" }
function C-Json($obj, [string]$status = '200', [string]$ctype = 'application/json') { return C-Resp $status $ctype (Json $obj) }
$goodIssuer = 'https://auth.joshuatech.dev/application/o/identity-admin/'
function New-GoodCurl {
    $r = [ordered]@{}
    $r['--version'] = C-Version '8.4.0'
    $r[$U.acc1] = C-AccessLogin 'auth.joshuatech.dev'
    $r[$U.acc2] = C-AccessLogin 'admin.joshuatech.dev'
    $r[$U.acc3] = C-Access401
    $r[$U.pub1] = C-Json ([ordered]@{ capabilities = @('can_save_media', 'can_geo_ip'); error_reporting = [ordered]@{ enabled = $false }; x_note = $script:needle })
    $r[$U.pub2] = C-Json ([ordered]@{ type = 'native'; component = 'ak-stage-identification'; flow_info = [ordered]@{ title = $script:needle; layout = 'stacked' } })
    $r[$U.pub3] = C-Json ([ordered]@{ issuer = $goodIssuer; jwks_uri = 'https://auth.joshuatech.dev/application/o/identity-admin/jwks/'; authorization_endpoint = 'https://auth.joshuatech.dev/application/o/authorize/'; x_note = $script:needle })
    $r[$U.pub4] = C-Json ([ordered]@{ keys = @([ordered]@{ kty = 'RSA'; alg = 'RS256'; use = 'sig'; kid = $script:needle; n = 'fixture-modulus'; e = 'AQAB' }) })   # 키 값은 판정하지 않는다(keys 개수만)
    $r[$U.pub5] = C-Json ([ordered]@{ issuer = $goodIssuer; token_endpoint = 'https://auth.joshuatech.dev/application/o/token/'; x_note = $script:needle })
    $r[$U.xchg0] = C-Resp '405' 'text/html; charset=utf-8' ''
    return $r
}
# 오늘 모양: auth. 공개 경로는 라우터 없음(Traefik 404 서명 전체) · /if/admin/은 엣지 Access 302 · admin. 302 · m2m 401
function New-TodayCurl {
    $r = New-GoodCurl
    foreach ($k in @('pub1', 'pub2', 'pub3', 'pub4', 'pub5', 'xchg0')) { $r[$U[$k]] = C-Traefik404 }
    return $r
}

# ---------- 기대 문구(§1-2 오늘 기대 + D5 분류 접두) ----------
$skipCred = '자격 블록 전용 — T077-b · S-01 개정(T080–T081)'
$skipManual = '운영자 수동 + 스크린샷(R30)'
$gateTraefik = '[gate] Traefik 404 (no router) — until T080'
$gateJob = '[gate] Job jt-dev/authz-assert absent — rendered with the tests Application after T082 (T085)'
$allIds = @('gate-1', 'gate-2', 'gate-3', 'tool-1', 'ing-1', 'acc-1', 'acc-2', 'acc-3', 'pub-1', 'pub-2', 'pub-3', 'pub-4', 'pub-5', 'xchg-0', 'xchg-1', 'xchg-2', 'fga-1', 'fga-2', 'fga-3', 'fga-4', 'man-1', 'man-2')
$httpIds = @('acc-1', 'acc-2', 'acc-3', 'pub-1', 'pub-2', 'pub-3', 'pub-4', 'pub-5', 'xchg-0')
$acc2Pass = '302 -> https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/admin.joshuatech.dev (Cloudflare Access login; query not shown)'
$acc3Pass = '401 text/html without Location (Access service auth; contract C11)'
$todayExpect = [ordered]@{
    'gate-1' = @('PASS', 'kubectl found')
    'gate-2' = @('PASS', 'KUBECONFIG set (single existing file)')
    'gate-3' = @('PASS', "context user is $expectedUser")
    'ing-1'  = @('FAIL', '[gate] until T080 (no Ingress for auth.joshuatech.dev in ns identity)')
    'acc-1'  = @('FAIL', '[gate] 302 is edge-only (Access app auth-admin — T011); origin route absent — until T080')
    'acc-2'  = @('PASS', $acc2Pass)
    'acc-3'  = @('PASS', $acc3Pass)
    'pub-1'  = @('FAIL', $gateTraefik)
    'pub-2'  = @('FAIL', $gateTraefik)
    'pub-3'  = @('FAIL', $gateTraefik)
    'pub-4'  = @('FAIL', $gateTraefik)
    'pub-5'  = @('FAIL', $gateTraefik)
    'xchg-0' = @('FAIL', $gateTraefik)
    'xchg-1' = @('SKIP', $skipCred)
    'xchg-2' = @('SKIP', $skipCred)
    'fga-1'  = @('FAIL', $gateJob)
    'fga-2'  = @('FAIL', $gateJob)
    'fga-3'  = @('FAIL', $gateJob)
    'fga-4'  = @('FAIL', $gateJob)
    'man-1'  = @('SKIP', $skipManual)
    'man-2'  = @('SKIP', $skipManual)
}
$goodPass = [ordered]@{
    'gate-1' = 'kubectl found'
    'gate-2' = 'KUBECONFIG set (single existing file)'
    'gate-3' = "context user is $expectedUser"
    'ing-1'  = 'Ingress identity/authentik has rules[].host auth.joshuatech.dev'
    'acc-1'  = '302 -> https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/auth.joshuatech.dev (Access app auth-admin; query not shown); origin route present (ing-1: Ingress identity/authentik)'
    'acc-2'  = $acc2Pass
    'acc-3'  = $acc3Pass
    'pub-1'  = "GET $($U.pub1) -> 200 application/json with key capabilities"
    'pub-2'  = "GET $($U.pub2) -> 200 application/json with key component (login flow default-authentication-flow)"
    'pub-3'  = "GET $($U.pub3) -> 200 application/json; issuer = $goodIssuer; jwks_uri present"
    'pub-4'  = "GET $($U.pub4) -> 200 application/json; keys[] has 1 key(s)"
    'pub-5'  = "GET $($U.pub5) -> 200 application/json with key issuer (RFC 8414 candidate path; VD-T080-a)"
    'xchg-0' = "GET $($U.xchg0) -> 405 (token endpoint reached; never probed with POST)"
    'fga-1'  = 'Job jt-dev/authz-assert log: RESULT PASS check-member-allowed; all 4 tracked check ids PASS exactly once; SUMMARY pass=6 fail=0 (EVIDENCE lines not copied)'
    'fga-2'  = 'Job jt-dev/authz-assert log: RESULT PASS check-owner-allowed; all 4 tracked check ids PASS exactly once; SUMMARY pass=6 fail=0 (EVIDENCE lines not copied)'
    'fga-3'  = 'Job jt-dev/authz-assert log: RESULT PASS cross-tenant-member-false; all 4 tracked check ids PASS exactly once; SUMMARY pass=6 fail=0 (EVIDENCE lines not copied)'
    'fga-4'  = 'Job jt-dev/authz-assert log: RESULT PASS cross-tenant-owner-false; all 4 tracked check ids PASS exactly once; SUMMARY pass=6 fail=0 (EVIDENCE lines not copied)'
}

# ---------- 픽스처 ----------
# $curlResponses = $null이면 curl 심을 두지 않는다(curl 없는 케이스). $extraFiles: 픽스처 상대 경로 → 내용(진입 스크립트 등)
function New-Fixture($kubectlResponses, $curlResponses, [hashtable]$extraFiles = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('identitytest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($sub in @('bin', 'tmp', 'resp', 'curl-resp', 'repo/tests/platform')) { New-Item -ItemType Directory -Path (Join-Path $dir $sub) -Force | Out-Null }
    $kcPath = Join-Path $dir 'kubeconfig.yaml'   # 응답 본문의 {KUBECONFIG} 자리표시자 = 이 픽스처의 kubeconfig 경로(하네스가 <KUBECONFIG>로 가려야 한다)
    $tsv = [Text.StringBuilder]::new(); $n = 0
    foreach ($k in @($kubectlResponses.Keys)) {
        $n++; $v = $kubectlResponses[$k]; $ks = [string]$k
        if ($ks.IndexOf([char]9) -ge 0 -or $ks.IndexOf([char]10) -ge 0 -or $ks.IndexOf([char]13) -ge 0) { throw "fixture key contains a tab or a line break: $ks" }
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.out"), ([string]$v.out).Replace('{KUBECONFIG}', $kcPath), $utf8)
        [IO.File]::WriteAllText((Join-Path $dir "resp/$n.err"), ([string]$v.err).Replace('{KUBECONFIG}', $kcPath), $utf8)
        [void]$tsv.Append("$n`t$([int]$v.code)`t$ks`n")
    }
    [IO.File]::WriteAllText((Join-Path $dir 'responses.tsv'), $tsv.ToString(), $utf8)
    [IO.File]::WriteAllText($kcPath, "apiVersion: v1`nkind: Config`n", $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/kubectl.cmd'), (New-Shim 'FAKE_KUBECTL_ARGV' 'fake-kubectl.ps1'), $utf8)
    [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-kubectl.ps1'), $fakeKubectl, $utf8)
    if ($null -ne $curlResponses) {
        $ctsv = [Text.StringBuilder]::new(); $m = 0
        foreach ($k in @($curlResponses.Keys)) {
            $m++; $v = $curlResponses[$k]; $ks = [string]$k
            [IO.File]::WriteAllText((Join-Path $dir "curl-resp/$m.meta"), "$($v.status)`n$($v.ctype)`n$($v.location)`n$($v.cf)`n", $utf8)
            [IO.File]::WriteAllBytes((Join-Path $dir "curl-resp/$m.body"), $utf8.GetBytes([string]$v.body))
            [IO.File]::WriteAllText((Join-Path $dir "curl-resp/$m.err"), [string]$v.err, $utf8)
            [IO.File]::WriteAllText((Join-Path $dir "curl-resp/$m.out"), [string]$v.out, $utf8)
            [void]$ctsv.Append("$m`t$([int]$v.code)`t$ks`n")
        }
        [IO.File]::WriteAllText((Join-Path $dir 'curl-responses.tsv'), $ctsv.ToString(), $utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'bin/curl.cmd'), (New-Shim 'FAKE_CURL_ARGV' 'fake-curl.ps1'), $utf8)
        [IO.File]::WriteAllText((Join-Path $dir 'bin/fake-curl.ps1'), $fakeCurl, $utf8)
    }
    if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { Copy-Item -LiteralPath $harnessPath -Destination (Join-Path $dir 'repo/tests/platform/identity.tests.ps1') }
    foreach ($rel in @($extraFiles.Keys)) { [IO.File]::WriteAllText((Join-Path $dir $rel), [string]$extraFiles[$rel], $utf8) }
    return $dir
}
# 이 실행이 만든 identitytest-* 디렉터리만, responses.tsv가 있는지 확인하고 지운다
function Remove-Fixture {
    foreach ($f in $script:fixtures) {
        $leaf = Split-Path $f -Leaf
        if (-not $leaf.StartsWith('identitytest-', [StringComparison]::Ordinal) -or -not (Test-Path -LiteralPath (Join-Path $f 'responses.tsv') -PathType Leaf)) {
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

# 하네스 사본(또는 진입 스크립트)을 자식 pwsh로 실행한다. 환경은 자식에게만 준다(이 프로세스의 환경은 바꾸지 않는다).
#   $kubeconfigValue: '' = 픽스처 kubeconfig · '<unset>' = KUBECONFIG 제거 · 그 밖 = 그 값 그대로. $prependPath: 가드 시험용(G01) — bin 앞에 둘 디렉터리.
#   $extraEnv: 자식에만 줄 env(이름 → 값) — curl env 가드 대상 이름을 지운 뒤에 넣는다(C16 · G02 양성 대조).
function Invoke-Harness([string]$dir, [string]$entry = 'repo/tests/platform/identity.tests.ps1', [bool]$withCurl = $true, [string]$kubeconfigValue = '', [string]$prependPath = '', [int]$timeoutSec = 240, [System.Collections.IDictionary]$extraEnv = @{}) {
    $h = Join-Path $dir 'repo/tests/platform/identity.tests.ps1'
    if (-not (Test-Path -LiteralPath $h -PathType Leaf)) { return @{ out = "<missing harness: $harnessPath>"; err = ''; code = 127; wall = 0.0; timedOut = $false } }
    $bin = Join-Path $dir 'bin'
    $childPath = $bin + $sep + $script:safePath
    if ($prependPath.Length -gt 0) { $childPath = $prependPath + $sep + $childPath }
    # 실행마다 확인: 처음 찾히는 kubectl = 픽스처 심, curl = 픽스처 심(심을 두지 않은 케이스면 없음) — 실제 클러스터 · 네트워크에 닿지 않게
    $first = Find-FirstCommand $childPath 'kubectl'
    if (-not [string]::Equals($first, (Join-Path $bin 'kubectl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first kubectl on the child PATH is '$first', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    $firstCurl = Find-FirstCommand $childPath 'curl'
    if ($withCurl) {
        if (-not [string]::Equals($firstCurl, (Join-Path $bin 'curl.cmd'), [StringComparison]::OrdinalIgnoreCase)) { return @{ out = "<refusing to run: the first curl on the child PATH is '$firstCurl', not the fixture shim>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    } elseif ($null -ne $firstCurl) { return @{ out = "<refusing to run: 'curl' is reachable on the child PATH ($firstCurl)>"; err = ''; code = 125; wall = 0.0; timedOut = $false } }
    $psi = [Diagnostics.ProcessStartInfo]::new([Environment]::ProcessPath)
    foreach ($x in @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $dir $entry))) { $psi.ArgumentList.Add([string]$x) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # 하네스는 stdout이 리다이렉트되면 UTF-8로 쓴다(머리) — 콘솔 코드 페이지와 무관하게 UTF-8로 읽는다(SKIP 문구는 한국어)
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $psi.Environment['KUBECONFIG'] = Join-Path $dir 'kubeconfig.yaml'
    if (Test-Same $kubeconfigValue '<unset>') { [void]$psi.Environment.Remove('KUBECONFIG') } elseif ($kubeconfigValue.Length -gt 0) { $psi.Environment['KUBECONFIG'] = $kubeconfigValue }
    $psi.Environment['PATH'] = $childPath
    $psi.Environment['TMP'] = Join-Path $dir 'tmp'
    $psi.Environment['TEMP'] = Join-Path $dir 'tmp'
    foreach ($k in @('OCI_CLI_AUTH', 'OCI_CLI_PROFILE', 'OCI_CLI_CONFIG_FILE')) { [void]$psi.Environment.Remove($k) }
    # curl env 가드 대상(프록시 · TLS 키 로그 · CA 묶음 — 하네스 B-9)은 자식에서 지운다: 개발자 창의 프록시 env가 모든 E2E 케이스를 [guard]로 바꾸지 않게(G02).
    foreach ($k in @($psi.Environment.Keys)) { if (Test-CurlGuardEnvName ([string]$k)) { [void]$psi.Environment.Remove([string]$k) } }
    foreach ($k in @($extraEnv.Keys)) { $psi.Environment[[string]$k] = [string]$extraEnv[$k] }
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
    $tail = if ($lines.Count -gt 26) { @('...') + $lines[($lines.Count - 26)..($lines.Count - 1)] } else { $lines }
    return "code=$($r.code) wall=$([Math]::Round([double]$r.wall, 1))s timedOut=$($r.timedOut) out=[$($tail -join ' | ')] err=[$($r.err.Trim())]"
}
function Get-Summary($r) { $l = @(Get-Lines $r); if ($l.Count -eq 0) { return '' }; return [string]$l[$l.Count - 1] }
# id의 결과 줄('PASS|FAIL|SKIP <id> -- <detail>') → @{ n = 줄 수; status; detail; line }
function Get-IdResult($r, [string]$id) {
    $hits = @(@(Get-Lines $r) | Where-Object { $l = $_; @(@('PASS', 'FAIL', 'SKIP') | Where-Object { $l.StartsWith("$_ $id -- ", [StringComparison]::Ordinal) }).Count -gt 0 })
    if ($hits.Count -ne 1) { return @{ n = $hits.Count; status = ''; detail = ''; line = ($hits -join ' || ') } }
    $l = [string]$hits[0]
    return @{ n = 1; status = $l.Substring(0, 4); detail = $l.Substring(("XXXX $id -- ").Length); line = $l }
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
    Assert $name ($x.n -eq 1 -and (Test-Same $x.status $status) -and (Test-Same $x.detail $detail)) "expected [$status $id -- $detail] :: got $($x.n) line(s) [$($x.line)]"
}
# 지정한 ID 밖의 모든 PASS 대상 ID($goodPass — tool-1은 경로가 들어 따로 본다)가 전부 갖춰진 픽스처의 PASS 문구와 같다
function Assert-OthersPass([string]$name, $r, [string[]]$except) {
    $bad = @()
    foreach ($id in @($goodPass.Keys)) {
        if (In-Set $except $id) { continue }
        $x = Get-IdResult $r $id
        if ($x.n -ne 1 -or -not (Test-Same $x.status 'PASS') -or -not (Test-Same $x.detail ([string]$goodPass[$id]))) { $bad += "$id=[$($x.line)] (expected [PASS $id -- $($goodPass[$id])])" }
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
# curl-calls.log 줄(served TAB code TAB fmt TAB argv…) → @{ served; code; fmt; argv }
function Get-CurlCalls([string]$dir) {
    $p = Join-Path $dir 'curl-calls.log'
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return @() }
    return @(foreach ($l in [IO.File]::ReadAllLines($p)) {
            if ($l.Trim().Length -eq 0) { continue }
            $f = $l.Split([char[]]@([char]9))
            $argv = if ($f.Count -ge 4) { @($f[3..($f.Count - 1)]) } else { @() }
            @{ served = $f[0]; code = $(if ($f.Count -ge 2) { $f[1] } else { '' }); fmt = $(if ($f.Count -ge 3) { $f[2] } else { '' }); argv = $argv }
        })
}
function Format-Calls($calls) { return 'calls=[' + ((@(@($calls) | ForEach-Object { "$($_['served']):$($_['key'])" })) -join ' | ') + ']' }
# 읽기 전용 동사만: get · auth whoami · -n <ns> get|logs
function Test-ReadOnlyKey([string]$key) {
    $t = @($key.Split(' '))
    if ($t.Count -ge 1 -and (Test-Same $t[0] 'get')) { return $true }
    if ($t.Count -ge 2 -and (Test-Same $t[0] 'auth') -and (Test-Same $t[1] 'whoami')) { return $true }
    if ($t.Count -ge 3 -and (Test-Same $t[0] '-n') -and ((Test-Same $t[2] 'get') -or (Test-Same $t[2] 'logs'))) { return $true }
    return $false
}
# 금지 curl 플래그(설계 D8 ⑧ + 기록 · 자격 · 덮기 꼴 — D10). --data로 시작하는 것도 금지.
$forbiddenCurl = @('-L', '--location', '--location-trusted', '-k', '--insecure', '-H', '--header', '-u', '--user', '-b', '--cookie', '-c', '--cookie-jar', '-x', '--proxy',
    '-K', '--config', '-d', '-X', '--request', '-F', '--form', '-T', '--upload-file', '--json', '-n', '--netrc', '--netrc-optional', '--oauth2-bearer', '-v', '--verbose',
    '--trace', '--trace-ascii', '-D', '--dump-header', '-E', '--cert', '--key', '--negotiate', '--ntlm', '--basic', '--digest', '--anyauth', '--aws-sigv4', '-i', '--include',
    '--libcurl', '--stderr', '-e', '--referer', '-A', '--user-agent')
function Test-ForbiddenCurlToken([string]$t) { return ((In-Set $forbiddenCurl $t) -or $t.StartsWith('--data', [StringComparison]::Ordinal)) }
# 임시 파일 경로가 픽스처 tmp/ 바로 아래이고 이름이 identity-tests-로 시작하는가
function Test-TmpFile([string]$path, [string]$dir) {
    if ([string]::IsNullOrEmpty($path)) { return $false }
    $parent = ''
    try { $parent = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path)) } catch { return $false }
    $tmp = [IO.Path]::GetFullPath((Join-Path $dir 'tmp')).TrimEnd('\', '/')
    return [string]::Equals($parent.TrimEnd('\', '/'), $tmp, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($path).StartsWith('identity-tests-', [StringComparison]::Ordinal)
}

# 모든 실행 공통 단언. $kubectlCalls · $curlCalls = 기대 호출 수(실제 도구가 불리지 않았다는 증거의 일부).
function Assert-Run([string]$id, $r, [string]$dir, [int]$kubectlCalls, [int]$curlCalls) {
    $lines = @(Get-Lines $r)
    $last = if ($lines.Count -gt 0) { $lines[$lines.Count - 1] } else { '' }
    $sm = [regex]::Match($last, '\A(\d+) passed, (\d+) failed, (\d+) skipped\z')
    Assert "${id}-end: harness ran to completion (no timeout; last line is the 'N passed, N failed, N skipped' summary)" ((-not $r.timedOut) -and $sm.Success) (Format-Result $r)
    # 22 id가 정확히 한 번씩, s1-2 순서로, '<STATUS> <id> -- <근거>' 꼴(기계 판독 부분 = ' -- ' 앞, ASCII)
    $asserted = @($lines | Where-Object { [regex]::IsMatch($_, '\A(PASS|FAIL|SKIP) ') })
    $ids = @($asserted | ForEach-Object { $m = [regex]::Match($_, '\A(?:PASS|FAIL|SKIP) ([a-z0-9-]+) -- \S'); if ($m.Success) { $m.Groups[1].Value } else { "<malformed:$_>" } })
    Assert "${id}-ids: exactly the 22 ids, once each, in the s1-2 order, each line '<STATUS> <id> -- <reason>'" (Test-Same ($ids -join ',') ($allIds -join ',')) "got [$($ids -join ',')]"
    if ($sm.Success) {
        $np = @($asserted | Where-Object { $_.StartsWith('PASS ', [StringComparison]::Ordinal) }).Count
        $nf = @($asserted | Where-Object { $_.StartsWith('FAIL ', [StringComparison]::Ordinal) }).Count
        $ns = @($asserted | Where-Object { $_.StartsWith('SKIP ', [StringComparison]::Ordinal) }).Count
        Assert "${id}-count: the summary counts equal the PASS/FAIL/SKIP lines" ($np -eq [int]$sm.Groups[1].Value -and $nf -eq [int]$sm.Groups[2].Value -and $ns -eq [int]$sm.Groups[3].Value) "lines P=$np F=$nf S=$ns vs [$last]"
    }
    $badFail = @($asserted | Where-Object { $_.StartsWith('FAIL ', [StringComparison]::Ordinal) } | Where-Object { -not [regex]::IsMatch($_, '\AFAIL [a-z0-9-]+ -- \[(gate|env|product|guard|decision|state)\] ') })
    Assert "${id}-class: every FAIL reason starts with a D5 class prefix ([gate] [env] [product] ...)" ($badFail.Count -eq 0) ($badFail -join ' || ')
    $badSkip = @($asserted | Where-Object { $_.StartsWith('SKIP ', [StringComparison]::Ordinal) } | Where-Object { $d = $_.Substring($_.IndexOf(' -- ', [StringComparison]::Ordinal) + 4); -not ((Test-Same $d $skipCred) -or (Test-Same $d $skipManual)) })
    Assert "${id}-skip: every SKIP reason is exactly one of the two phrases (credential block only / operator manual)" ($badSkip.Count -eq 0) ($badSkip -join ' || ')
    Assert "${id}-unhandled: no assertion ended in an unhandled exception" (-not (Has-Text $r.out 'unhandled')) (Format-Result $r)
    # kubectl
    $calls = @(Get-Calls $dir)
    Assert "${id}-kubectl-n: $kubectlCalls kubectl call(s)" ($calls.Count -eq $kubectlCalls) (Format-Calls $calls)
    $notRo = @($calls | Where-Object { -not (Test-ReadOnlyKey ([string]$_['key'])) })
    Assert "${id}-kubectl-ro: every kubectl call used a read-only verb (get / auth whoami / logs)" ($notRo.Count -eq 0) "not read-only: $((@($notRo | ForEach-Object { $_['key'] })) -join ' || ')"
    $unserved = @($calls | Where-Object { Test-Same ([string]$_['served']) 'default' })
    Assert "${id}-kubectl-served: every kubectl call matched a fixture response" ($unserved.Count -eq 0) "outside: $((@($unserved | ForEach-Object { $_['key'] })) -join ' || ')"
    $kc = Join-Path $dir 'kubeconfig.yaml'
    $badKc = @($calls | Where-Object { -not [string]::Equals([string]$_['kubeconfig'], $kc, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Same ([string]$_['requestTimeout']) '30s') })
    Assert "${id}-kubectl-kc: every kubectl call named the fixture kubeconfig (--kubeconfig) and --request-timeout=30s" ($badKc.Count -eq 0) "without: $((@($badKc | ForEach-Object { $_['key'] })) -join ' || ')"
    # curl
    $cc = @(Get-CurlCalls $dir)
    Assert "${id}-curl-n: $curlCalls curl call(s)" ($cc.Count -eq $curlCalls) "got $($cc.Count): $((@($cc | ForEach-Object { @($_['argv']) -join ' ' })) -join ' || ')"
    $bad = @()
    $seen = @{}
    foreach ($c in $cc) {
        $a = @($c['argv'])
        if (-not (Test-Same ([string]$c['served']) 'fixture')) { $bad += "unserved: $($a -join ' ')" }
        $forb = @($a | Where-Object { Test-ForbiddenCurlToken $_ })
        if ($forb.Count -gt 0) { $bad += "forbidden flag(s) $($forb -join ',')" }
        if ($a.Count -eq 0 -or -not (Test-Same $a[0] '-q')) { $bad += "first argument is not -q: $($a -join ' ')"; continue }
        if (In-Set $a '--version') {
            if (-not (Test-Same ($a -join ' ') '-q --version')) { $bad += "version call is not exactly '-q --version': $($a -join ' ')" }
            continue
        }
        if ($a.Count -ne 12) { $bad += "argv has $($a.Count) tokens (expected 12): $($a -join ' ')"; continue }
        $fixed = @{ 1 = '-s'; 2 = '-S'; 3 = '--max-time'; 4 = '20'; 5 = '--proto'; 6 = '=https'; 7 = '-o'; 9 = '-w' }
        foreach ($i in @($fixed.Keys)) { if (-not (Test-Same $a[$i] $fixed[$i])) { $bad += "argv[$i]='$($a[$i])' (expected '$($fixed[$i])')" } }
        if (-not (Test-TmpFile $a[8] $dir)) { $bad += "-o target is not fixture tmp/identity-tests-*: $($a[8])" }
        if (-not $a[10].StartsWith('@', [StringComparison]::Ordinal) -or -not (Test-TmpFile $a[10].Substring(1) $dir)) { $bad += "-w is not @<fixture tmp/identity-tests-*>: $($a[10])" }
        if (-not (In-Set @($U.Values) $a[11])) { $bad += "url outside the contract set: $($a[11])" }
        if ($seen.ContainsKey($a[11])) { $bad += "url called twice: $($a[11])" } else { $seen[$a[11]] = 1 }
        if (-not (Test-Same ([string]$c['fmt']) $expectedFmt)) { $bad += "write-out format file [$($c['fmt'])] (expected [$expectedFmt])" }
    }
    Assert "${id}-curl-argv: every curl call is '-q -s -S --max-time 20 --proto =https -o <tmp> -w @<tmp> <contract url>' (or '-q --version'), served by the fixture, no forbidden flag, exact write-out format" ($bad.Count -eq 0) ($bad -join ' || ')
    $left = @(Get-ChildItem -LiteralPath (Join-Path $dir 'tmp') -Force -Recurse -ErrorAction SilentlyContinue)
    Assert "${id}-tmp: no temp file left in the fixture tmp/ (identity-tests-* body/format/stderr files removed)" ($left.Count -eq 0) "left: $((@($left | ForEach-Object { $_.Name })) -join ', ')"
    Assert "${id}-needle: the run's needle (bodies, Location queries, Job EVIDENCE/RESULT text) never appears in the harness output" (-not [string]::IsNullOrEmpty($script:needle) -and -not (Has-Text $r.out $script:needle) -and -not (Has-Text $r.err $script:needle)) 'needle found in output'
    Assert "${id}-kcpath: the fixture kubeconfig path never appears in the harness output" (-not (Has-Text $r.out $kc) -and -not (Has-Text $r.out $kc.Replace('\', '/'))) (Format-Result $r)
}

# ---------- 함수 케이스용: 하네스의 최상위 함수 + 몇 개 상수만 동적 모듈에 정의한다(최상위 문장은 실행하지 않는다) ----------
$harnessConsts = @('AuthHost', 'AccessLoginHost', 'AccessLoginPathPrefix', 'OidcSlug', 'ExpectedIssuer', 'WellKnownRootPath', 'LoginFlowSlug', 'RootConfigKey',
    'Traefik404Sha256', 'Traefik404ContentType', 'Traefik404Size', 'CurlMinVersion', 'CurlWriteOut', 'HttpTimeoutSec', 'ExchangeAudience', 'ExchangeLifetimeSec',
    'ExchangeActSub', 'RejectedAudience', 'RejectError', 'Vd1Option', 'FgaIds', 'FgaPendingIds', 'FgaPendingNote', 'SkipCredBlock', 'SkipManual', 'CurlEnvGuardNames')
function Import-HarnessModule([string]$path) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw "harness does not parse: $(@($errors)[0].Message)" }
    $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
    $consts = @($ast.EndBlock.Statements | Where-Object {
            $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            (In-Set $script:harnessConsts $_.Left.VariablePath.UserPath) })
    $text = ((@($consts | ForEach-Object { $_.Extent.Text }) + @($funcs | ForEach-Object { $_.Extent.Text })) -join "`n") + "`nExport-ModuleMember -Function @()`n"
    return (New-Module -Name ('identityharness-' + [guid]::NewGuid().ToString('N')) -ScriptBlock ([scriptblock]::Create($text)))
}
function Test-ModuleHas($mod, [string]$fn) { return [bool](& $mod { param($n) $null -ne (Get-Command -Name $n -CommandType Function -ErrorAction SilentlyContinue) } $fn) }

# ---------- JWT 조립(F01 — 합성 토큰 · 바늘은 실행마다) ----------
function B64Url([byte[]]$b) { return [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function B64UrlText([string]$s) { return (B64Url ([Text.Encoding]::UTF8.GetBytes($s))) }
function New-Jwt($claims, [string]$needle) {
    $hdr = B64UrlText (Json ([ordered]@{ alg = 'RS256'; typ = 'JWT'; kid = "kid-$needle" }))
    $pl = if ($claims -is [string]) { B64UrlText $claims } else { B64UrlText (Json $claims) }
    $sig = B64UrlText ("sig-$needle-" + [guid]::NewGuid().ToString('N'))
    return "$hdr.$pl.$sig"
}
function Good-Claims([string]$needle) {
    return [ordered]@{ iss = 'https://auth.joshuatech.dev/application/o/identity-admin/'; sub = "sub-$needle"; aud = 'identity-admin'; tenant_id = '3f2b8c1e-9a4d-4e6b-8f1a-2c3d4e5f6a7b'; iat = 1795000000; exp = 1795000300; jti = "jti-$needle" }
}

try {
    # ================= 가드: 실제 도구에 닿지 않는다 =================
    Test-Case 'G01' 'guard: the child PATH has no real kubectl/oci/curl, and a decoy curl or a decoy kubectl ahead of the fixture shim makes Invoke-Harness refuse to run (exit 125, no call made)' {
        Assert 'G01-1: the safe PATH resolves no kubectl, oci or curl' ($null -eq (Find-FirstCommand $script:safePath 'kubectl') -and $null -eq (Find-FirstCommand $script:safePath 'curl') -and $null -eq (Find-FirstCommand $script:safePath 'oci')) "kubectl=[$(Find-FirstCommand $script:safePath 'kubectl')] curl=[$(Find-FirstCommand $script:safePath 'curl')] oci=[$(Find-FirstCommand $script:safePath 'oci')]"
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) (New-TodayCurl)
        $decoy = Join-Path $d 'decoy'
        New-Item -ItemType Directory -Path $decoy | Out-Null
        [IO.File]::WriteAllText((Join-Path $decoy 'curl.cmd'), "@echo off`r`nexit /b 99`r`n", [Text.UTF8Encoding]::new($false))
        $r = Invoke-Harness $d -prependPath $decoy
        Assert 'G01-2: a decoy curl ahead of the shim -> refused (exit 125), nothing called' ($r.code -eq 125 -and (Has-Text $r.out '<refusing to run: the first curl') -and @(Get-CurlCalls $d).Count -eq 0 -and @(Get-Calls $d).Count -eq 0) (Format-Result $r)
        $r2 = Invoke-Harness $d -withCurl $false
        Assert 'G01-3: a curl-less case with the shim present -> refused (exit 125)' ($r2.code -eq 125 -and (Has-Text $r2.out "<refusing to run: 'curl' is reachable")) (Format-Result $r2)
        # r1 — A-11: kubectl 거부 갈래도 시험한다(처음 찾히는 kubectl이 미끼면 하네스를 띄우지 않는다)
        $decoyK = Join-Path $d 'decoy-kubectl'
        New-Item -ItemType Directory -Path $decoyK | Out-Null
        [IO.File]::WriteAllText((Join-Path $decoyK 'kubectl.cmd'), "@echo off`r`nexit /b 99`r`n", [Text.UTF8Encoding]::new($false))
        $r3 = Invoke-Harness $d -prependPath $decoyK
        Assert 'G01-4: a decoy kubectl ahead of the shim -> refused (exit 125), nothing called (r1 -- A-11)' ($r3.code -eq 125 -and (Has-Text $r3.out '<refusing to run: the first kubectl') -and @(Get-CurlCalls $d).Count -eq 0 -and @(Get-Calls $d).Count -eq 0) (Format-Result $r3)
    }

    # ================= 가드: 자식 env의 curl env 가드 대상 이름(r1 — B-9) =================
    Test-Case 'G02' 'guard: Invoke-Harness removes every curl-guarded variable (*_PROXY, SSLKEYLOGFILE, CURL_CA_BUNDLE, SSL_CERT_FILE, SSL_CERT_DIR) from the child environment, so a developer proxy cannot turn the E2E cases into [guard] lines; -extraEnv puts chosen names back (positive control)' {
        $d = New-Fixture (New-TodayKube) (New-TodayCurl) @{ 'envprobe.ps1' = $envProbe }
        $planted = [ordered]@{ HTTPS_PROXY = 'http://g02-proxy.invalid:3128'; SSLKEYLOGFILE = (Join-Path $d 'g02-keys.log'); CURL_CA_BUNDLE = (Join-Path $d 'g02-ca.pem') }
        $saved = @{}
        foreach ($n in @($planted.Keys)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) }
        try {
            foreach ($n in @($planted.Keys)) { Set-Item -LiteralPath "Env:$n" -Value ([string]$planted[$n]) }
            $r = Invoke-Harness $d -entry 'envprobe.ps1'
            Assert 'G02-1: guarded names set in this process never reach the child (the probe sees none)' ($r.code -eq 0 -and (Test-Same ($r.out.TrimEnd("`n")) 'probe-done')) (Format-Result $r)
            $r2 = Invoke-Harness $d -entry 'envprobe.ps1' -extraEnv ([ordered]@{ all_proxy = 'socks5://g02-proxy.invalid:1080'; SSL_CERT_DIR = (Join-Path $d 'g02-certs') })
            Assert 'G02-2: positive control -- names passed with -extraEnv do reach the child (the probe is not blind)' ($r2.code -eq 0 -and (Test-Same ($r2.out.TrimEnd("`n")) "SSL_CERT_DIR`nall_proxy`nprobe-done")) (Format-Result $r2)
        } finally {
            foreach ($n in @($planted.Keys)) { if ($null -eq $saved[$n]) { Remove-Item -LiteralPath "Env:$n" -ErrorAction SilentlyContinue } else { Set-Item -LiteralPath "Env:$n" -Value ([string]$saved[$n]) } }
        }
        $left = @(@($planted.Keys) | Where-Object { -not (Test-Same ([string][Environment]::GetEnvironmentVariable($_)) ([string]$saved[$_])) })
        Assert 'G02-3: this process environment is restored after the case' ($left.Count -eq 0) "not restored: $($left -join ', ')"
    }

    # ================= 오늘 상태 → §1-2 =================
    Test-Case 'C01' 'today (no Authentik Ingress, auth. paths = Traefik 404 signature, /if/admin/ = edge Access 302, admin. 302, m2m 401, no authz-assert Job) -> every line equals the s1-2 expectation; 6 passed, 12 failed, 4 skipped' {
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) (New-TodayCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C01' $r $d 3 10
        Assert 'C01-1: exit 1 and summary "6 passed, 12 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '6 passed, 12 failed, 4 skipped')) (Format-Result $r)
        foreach ($tid in @($todayExpect.Keys)) { Assert-IdExact "C01-2 ${tid}: the s1-2 line (class prefix + reason text)" $r $tid ([string]$todayExpect[$tid][0]) ([string]$todayExpect[$tid][1]) }
        Assert-Id 'C01-3 tool-1: PASS names the curl version and the %header{} floor' $r 'tool-1' 'PASS' @('curl 8.4.0 (', 'curl.cmd) supports %header{} write-out (>= 7.84.0)') @($HOME)
        $cc = @(Get-CurlCalls $d)
        Assert 'C01-4: curl -q --version first, then the 9 contract URLs once each in the s1-2 order' (Test-Same ((@($cc | ForEach-Object { $a = @($_['argv']); $a[$a.Count - 1] })) -join ',') ((@('--version') + @($U.Values)) -join ',')) "order=[$((@($cc | ForEach-Object { $a = @($_['argv']); $a[$a.Count - 1] })) -join ',')]"
        $calls = @(Get-Calls $d)
        Assert 'C01-5: kubectl = whoami, Ingress list in ns identity, Job lookup (no logs call while the Job is absent)' (Test-Same ((@($calls | ForEach-Object { $_['key'] })) -join ' | ') (@($Q.who, $Q.ing, $Q.job) -join ' | ')) (Format-Calls $calls)
    }

    # ================= T080 뒤 상태 → 18 PASS =================
    Test-Case 'C02' 'after T080-T082 + render (Ingress, Authentik public paths, authz-assert Job with the four new ids) -> 18 PASS, 4 SKIP, exit 0' {
        $script:needle = New-Needle
        $d = New-Fixture (New-GoodKube) (New-GoodCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C02' $r $d 4 10
        Assert 'C02-1: exit 0 and summary "18 passed, 0 failed, 4 skipped"' ($r.code -eq 0 -and (Test-Same (Get-Summary $r) '18 passed, 0 failed, 4 skipped')) (Format-Result $r)
        Assert-OthersPass 'C02-2: every PASS id with the exact wording' $r @()
        foreach ($sid in @('xchg-1', 'xchg-2', 'man-1', 'man-2')) { Assert-IdExact "C02-3 ${sid}: still SKIP with its phrase" $r $sid 'SKIP' ([string]$todayExpect[$sid][1]) }
    }

    # ================= 변이 A =================
    Test-Case 'C03' 'variant A: 403 text/html + Ingress (acc-1 PASS) / admin. Location on another host / m2m 401 JSON / 200 text/html / JSON without component / redirect not followed / curl exit 28 / 503 / 18-byte 404 / Job with the old ids only' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.ing] = R-Json (New-List @((New-Ingress 'identity' 'openfga-x' @('openfga.joshuatech.dev')), (New-Ingress 'identity' 'authentik' @('auth.joshuatech.dev'))))
        $k[$Q.logs] = R-Raw (New-AuthzLog $authzOldIds)
        $c = New-GoodCurl
        $c[$U.acc1] = C-Resp '403' 'text/html; charset=UTF-8' "<html>Forbidden $script:needle</html>"
        $c[$U.acc2] = C-AccessLogin 'admin.joshuatech.dev' 'evil.example'
        $c[$U.acc3] = C-Json ([ordered]@{ error = 'unauthorized'; x_note = $script:needle }) '401'
        $c[$U.pub1] = C-Resp '200' 'text/html; charset=utf-8' "<html>$script:needle</html>"
        $c[$U.pub2] = C-Json ([ordered]@{ type = 'native'; flow_info = [ordered]@{ title = $script:needle } })
        $c[$U.pub3] = C-Resp '302' '' '' ('https://auth.joshuatech.dev/if/flow/default-authentication-flow/?next=' + $script:needle)
        $c[$U.pub4] = C-Exit 28 'curl: (28) Operation timed out after 20002 milliseconds with 0 bytes received'
        $c[$U.pub5] = C-Resp '503' 'text/html' "<html>$script:needle</html>"
        $c[$U.xchg0] = C-Resp '404' 'text/plain; charset=utf-8' '404 page not found'
        $d = New-Fixture $k $c
        $r = Invoke-Harness $d
        Assert-Run 'C03' $r $d 4 10
        Assert-IdExact 'C03-1: ing-1 PASS lists only the Ingress whose rule host is auth.joshuatech.dev' $r 'ing-1' 'PASS' 'Ingress identity/authentik has rules[].host auth.joshuatech.dev'
        Assert-IdExact 'C03-2: acc-1 PASS -- 403 text/html without Location paired with the Ingress' $r 'acc-1' 'PASS' '403 text/html without Location (Access app auth-admin); origin route present (ing-1: Ingress identity/authentik)'
        Assert-Id 'C03-3: acc-2 FAIL [product] -- Location on another host (safe form, query never printed)' $r 'acc-2' 'FAIL' @('[product] 302 -> https://evil.example/cdn-cgi/access/login/admin.joshuatech.dev for GET https://admin.joshuatech.dev/identity-admin/admin/ is not the Cloudflare Access login') @('?', 'meta=')
        Assert-Id 'C03-4: acc-3 FAIL [product] -- 401 but application/json' $r 'acc-3' 'FAIL' @('[product] 401 application/json for GET https://identity-m2m-prod.joshuatech.dev/health (expected 401 text/html without Location')
        Assert-IdExact 'C03-5: pub-1 FAIL [product] -- public 200 text/html' $r 'pub-1' 'FAIL' "[product] 200 text/html; charset=utf-8 for GET $($U.pub1) (expected application/json)"
        Assert-IdExact 'C03-6: pub-2 FAIL [product] -- JSON without the judgment key' $r 'pub-2' 'FAIL' "[product] 200 application/json for GET $($U.pub2) but the body lacks key component"
        Assert-IdExact 'C03-7: pub-3 FAIL [product] -- 302 is not followed; Location shown as scheme://host/path only' $r 'pub-3' 'FAIL' "[product] 302 (no content-type); Location https://auth.joshuatech.dev/if/flow/default-authentication-flow/ for GET $($U.pub3) (expected 200 application/json; redirects are not followed)"
        Assert-IdExact 'C03-8: pub-4 FAIL [env] -- curl exit 28 with its label and stderr first line' $r 'pub-4' 'FAIL' "[env] curl exit 28 (operation timed out) for GET $($U.pub4): curl: (28) Operation timed out after 20002 milliseconds with 0 bytes received"
        Assert-IdExact 'C03-9: pub-5 FAIL [env] -- origin 5xx is not red evidence' $r 'pub-5' 'FAIL' "[env] origin 503 for GET $($U.pub5) (text/html)"
        Assert-IdExact 'C03-10: xchg-0 FAIL [product] (not [gate]) -- an 18-byte 404 is not the Traefik signature' $r 'xchg-0' 'FAIL' "[product] 404 for GET $($U.xchg0) is not the Traefik no-router signature (size 18 B (expected 19 B); body sha256 differs)"
        foreach ($i in 0..3) { Assert-IdExact "C03-11 fga-$($i + 1): FAIL [gate] until T082 -- the Job emits only the old ids" $r "fga-$($i + 1)" 'FAIL' "[gate] until T082 (Job jt-dev/authz-assert does not emit the new check id(s) yet: check-member-allowed, check-owner-allowed, cross-tenant-member-false, cross-tenant-owner-false; $($fgaIds[$i]): no RESULT line)" }
        Assert 'C03-12: exit 1 and summary "6 passed, 12 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '6 passed, 12 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 B =================
    Test-Case 'C04' 'variant B: 403 + no matching Ingress (acc-1 [gate]) / Location path not the login / m2m 403 / curl exit 6 and 7 / wrong issuer / keys [] / Traefik 404 but cf-cache-status HIT / 19-byte 404 with another hash / duplicate RESULT id' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.ing] = R-Json (New-List @((New-Ingress 'identity' 'authentik-old' @('auth-old.joshuatech.dev'))))
        $k[$Q.logs] = R-Raw (New-AuthzLog @($authzOldIds + $fgaIds) @{} @('check-owner-allowed'))
        $c = New-GoodCurl
        $c[$U.acc1] = C-Resp '403' 'text/html' "<html>$script:needle</html>"
        $c[$U.acc2] = C-AccessLogin 'admin.joshuatech.dev' 'joshua-tech.cloudflareaccess.com' '/cdn-cgi/access/logout/'
        $c[$U.acc3] = C-Resp '403' 'text/html' "<html>$script:needle</html>"
        $c[$U.pub1] = C-Exit 6 'curl: (6) Could not resolve host: auth.joshuatech.dev'
        $c[$U.pub2] = C-Exit 7 'curl: (7) Failed to connect to auth.joshuatech.dev port 443 after 21 ms: Could not connect to server'
        $c[$U.pub3] = C-Json ([ordered]@{ issuer = "https://auth.joshuatech.dev/application/o/$script:needle/"; jwks_uri = 'https://auth.joshuatech.dev/application/o/identity-admin/jwks/' })
        $c[$U.pub4] = C-Json ([ordered]@{ keys = @() })
        $hit = C-Traefik404; $hit.cf = 'HIT'
        $c[$U.pub5] = $hit
        $c[$U.xchg0] = C-Resp '404' 'text/plain; charset=utf-8' "404 page NOT found`n"
        $d = New-Fixture $k $c
        $r = Invoke-Harness $d
        Assert-Run 'C04' $r $d 4 10
        Assert-IdExact 'C04-1: ing-1 FAIL [gate] -- an Ingress for another host does not count' $r 'ing-1' 'FAIL' '[gate] until T080 (no Ingress for auth.joshuatech.dev in ns identity)'
        Assert-IdExact 'C04-2: acc-1 FAIL [gate] -- 403 without the origin route' $r 'acc-1' 'FAIL' '[gate] 403 is edge-only (Access app auth-admin — T011); origin route absent — until T080'
        Assert-Id 'C04-3: acc-2 FAIL [product] -- Location path is not /cdn-cgi/access/login/' $r 'acc-2' 'FAIL' @('[product] 302 -> https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/logout/admin.joshuatech.dev for GET', 'is not the Cloudflare Access login')
        Assert-Id 'C04-4: acc-3 FAIL [product] -- m2m 403 is not the contract 401' $r 'acc-3' 'FAIL' @('[product] 403 text/html for GET https://identity-m2m-prod.joshuatech.dev/health')
        Assert-IdExact 'C04-5: pub-1 FAIL [env] -- curl exit 6' $r 'pub-1' 'FAIL' "[env] curl exit 6 (could not resolve host) for GET $($U.pub1): curl: (6) Could not resolve host: auth.joshuatech.dev"
        Assert-Id 'C04-6: pub-2 FAIL [env] -- curl exit 7' $r 'pub-2' 'FAIL' @("[env] curl exit 7 (failed to connect) for GET $($U.pub2)")
        Assert-IdExact 'C04-7: pub-3 FAIL [product] -- issuer differs (the value is not printed)' $r 'pub-3' 'FAIL' "[product] 200 application/json for GET $($U.pub3) but issuer is not $goodIssuer"
        Assert-IdExact 'C04-8: pub-4 FAIL [product] -- keys [] is not a non-empty array' $r 'pub-4' 'FAIL' "[product] 200 application/json for GET $($U.pub4) but keys is not a non-empty array"
        Assert-IdExact 'C04-9: pub-5 FAIL [product] (not [gate]) -- a cached 404 is not origin evidence' $r 'pub-5' 'FAIL' "[product] 404 for GET $($U.pub5) is not the Traefik no-router signature (cf-cache-status HIT (a cached copy is not origin evidence))"
        Assert-IdExact 'C04-10: xchg-0 FAIL [product] -- 19 bytes, right type, different body' $r 'xchg-0' 'FAIL' "[product] 404 for GET $($U.xchg0) is not the Traefik no-router signature (body sha256 differs)"
        foreach ($i in 0..3) { Assert-Id "C04-11 fga-$($i + 1): FAIL [product] -- duplicate RESULT line for check-owner-allowed" $r "fga-$($i + 1)" 'FAIL' @('[product] Job jt-dev/authz-assert log: ', '1 problem(s): 2 RESULT lines for check-owner-allowed (expected exactly 1)') }
        Assert-Id 'C04-12: fga-2 names its own state (2 RESULT lines)' $r 'fga-2' 'FAIL' @('log: check-owner-allowed 2 RESULT lines;')
        Assert 'C04-13: exit 1 and summary "4 passed, 14 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '4 passed, 14 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 C =================
    Test-Case 'C05' 'variant C: acc-1 Location on a look-alike host / application/json that is not JSON / empty component / no jwks_uri / keys as an object / JSON array root / SUMMARY count mismatch; xchg-0 405 PASS' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.logs] = R-Raw (New-AuthzLog @($authzOldIds + $fgaIds) @{} @() 'SUMMARY: pass=3 fail=0')
        $c = New-GoodCurl
        $c[$U.acc1] = C-AccessLogin 'auth.joshuatech.dev' 'joshua-tech.cloudflareaccess.com.evil.example'
        $c[$U.pub1] = C-Resp '200' 'application/json' "not json $script:needle"
        $c[$U.pub2] = C-Json ([ordered]@{ component = '' })
        $c[$U.pub3] = C-Json ([ordered]@{ issuer = $goodIssuer })
        $c[$U.pub4] = C-Json ([ordered]@{ keys = [ordered]@{ kid = $script:needle } })
        $c[$U.pub5] = C-Resp '200' 'application/json' ('[{"issuer":"' + $goodIssuer + '"}]')
        $d = New-Fixture $k $c
        $r = Invoke-Harness $d
        Assert-Run 'C05' $r $d 4 10
        Assert-Id 'C05-1: acc-1 FAIL [product] -- joshua-tech.cloudflareaccess.com.evil.example is not the team domain' $r 'acc-1' 'FAIL' @('[product] 302 -> https://joshua-tech.cloudflareaccess.com.evil.example/cdn-cgi/access/login/auth.joshuatech.dev for GET https://auth.joshuatech.dev/if/admin/ is not the Cloudflare Access login') @('meta=')
        Assert-IdExact 'C05-2: pub-1 FAIL [product] -- application/json that does not parse' $r 'pub-1' 'FAIL' "[product] 200 application/json for GET $($U.pub1) but the body is not a JSON object"
        Assert-IdExact 'C05-3: pub-2 FAIL [product] -- component is an empty string' $r 'pub-2' 'FAIL' "[product] 200 application/json for GET $($U.pub2) but the body lacks key component"
        Assert-IdExact 'C05-4: pub-3 FAIL [product] -- no jwks_uri' $r 'pub-3' 'FAIL' "[product] 200 application/json for GET $($U.pub3) but the body lacks key jwks_uri"
        Assert-IdExact 'C05-5: pub-4 FAIL [product] -- keys is an object' $r 'pub-4' 'FAIL' "[product] 200 application/json for GET $($U.pub4) but keys is not a non-empty array"
        Assert-IdExact 'C05-6: pub-5 FAIL [product] -- a JSON array root is not an object (no unwrapping of a one-element array)' $r 'pub-5' 'FAIL' "[product] 200 application/json for GET $($U.pub5) but the body is not a JSON object"
        Assert-IdExact 'C05-7: xchg-0 PASS -- 405' $r 'xchg-0' 'PASS' ([string]$goodPass['xchg-0'])
        foreach ($i in 0..3) { Assert-Id "C05-8 fga-$($i + 1): FAIL [product] -- SUMMARY counts do not match the RESULT lines" $r "fga-$($i + 1)" 'FAIL' @('[product] Job jt-dev/authz-assert log: ', 'SUMMARY pass=3 fail=0 does not match the RESULT lines (PASS 6, FAIL 0)') }
        Assert-OthersPass 'C05-9: every other id PASS unchanged' $r @('acc-1', 'pub-1', 'pub-2', 'pub-3', 'pub-4', 'pub-5', 'fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C05-10: exit 1 and summary "8 passed, 10 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '8 passed, 10 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 D: 추적 밖 FAIL =================
    Test-Case 'C06' 'variant D: an old id (check-allowed) FAILs with a consistent SUMMARY -> fga-1..4 FAIL [product] (outside the tracked set + SUMMARY fail=1); everything else PASS' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.logs] = R-Raw (New-AuthzLog @($authzOldIds + $fgaIds) @{ 'check-allowed' = 'FAIL' })
        $d = New-Fixture $k (New-GoodCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C06' $r $d 4 10
        foreach ($i in 0..3) { Assert-IdExact "C06-1 fga-$($i + 1): FAIL [product] with its own id state and both problems" $r "fga-$($i + 1)" 'FAIL' "[product] Job jt-dev/authz-assert log: $($fgaIds[$i]) RESULT PASS; 2 problem(s): RESULT FAIL for check-allowed (outside the tracked set); SUMMARY fail=1 (expected 0; pass=5)" }
        Assert-OthersPass 'C06-2: every other id PASS unchanged' $r @('fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C06-3: exit 1 and summary "14 passed, 4 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '14 passed, 4 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 E: 조회 실패 =================
    Test-Case 'C07' 'variant E: Ingress list forbidden (kubectl text masks the kubeconfig) and the Job present but its logs unreadable -> ing-1, acc-1, fga-1..4 FAIL [env]; HTTP ids PASS' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.ing] = R-Err 'Error from server (Forbidden): ingresses.networking.k8s.io is forbidden (kubeconfig {KUBECONFIG})'
        $k[$Q.logs] = R-Err 'error: error from server (BadRequest): container "openfga-assert" in pod "authz-assert-x7k2p" is waiting to start: ContainerCreating (kubeconfig {KUBECONFIG})'
        $d = New-Fixture $k (New-GoodCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C07' $r $d 4 10
        Assert-Id 'C07-1: ing-1 FAIL [env] -- lookup error text kept, kubeconfig masked' $r 'ing-1' 'FAIL' @('[env] Ingress list in ns identity lookup failed: kubectl get ingresses.networking.k8s.io -n identity failed (exit 1): Error from server (Forbidden)', '(kubeconfig <KUBECONFIG>)') @('kubeconfig.yaml')
        Assert-Id 'C07-2: acc-1 FAIL [env] -- the edge answered but the origin route is unknown' $r 'acc-1' 'FAIL' @('[env] 302 at the edge but the origin route is unknown (ing-1: Ingress list in ns identity lookup failed:')
        foreach ($i in 0..3) { Assert-Id "C07-3 fga-$($i + 1): FAIL [env] -- logs unreadable, kubeconfig masked" $r "fga-$($i + 1)" 'FAIL' @('[env] kubectl -n jt-dev logs job/authz-assert --tail=50 failed (exit 1): error: error from server (BadRequest)', '(kubeconfig <KUBECONFIG>)') @('kubeconfig.yaml') }
        Assert-OthersPass 'C07-4: every HTTP id except acc-1 PASS unchanged' $r @('ing-1', 'acc-1', 'fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C07-5: exit 1 and summary "12 passed, 6 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '12 passed, 6 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 게이트: kubectl =================
    Test-Case 'C08' 'kubectl gate fails (whoami is not agent-view) -> gate-3, ing-1, fga-1..4 FAIL [env] (1 kubectl call); acc-1 [env] (needs ing-1); every other HTTP assertion still runs and PASSes' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.who] = New-WhoamiResp 'system:admin'
        $d = New-Fixture $k (New-GoodCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C08' $r $d 1 10
        Assert-IdExact 'C08-1: gate-3 FAIL [env] -- other user refused' $r 'gate-3' 'FAIL' "[env] context user is 'system:admin', expected $expectedUser (admin/other kubeconfig refused)"
        Assert-IdExact 'C08-2: ing-1 FAIL [env] cluster unavailable' $r 'ing-1' 'FAIL' '[env] cluster unavailable (context user is not agent-view)'
        Assert-IdExact 'C08-3: acc-1 FAIL [env] -- the pair ing-1 is unavailable' $r 'acc-1' 'FAIL' '[env] 302 at the edge but the origin route is unknown (ing-1: cluster unavailable (context user is not agent-view))'
        foreach ($i in 1..4) { Assert-IdExact "C08-4 fga-${i}: FAIL [env] cluster unavailable" $r "fga-$i" 'FAIL' '[env] cluster unavailable (context user is not agent-view)' }
        Assert-OthersPass 'C08-5: gate-1, gate-2, tool-1 and the HTTP ids except acc-1 PASS unchanged' $r @('gate-3', 'ing-1', 'acc-1', 'fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C08-6: exit 1 and summary "11 passed, 7 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '11 passed, 7 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 게이트: curl 판 + KUBECONFIG 없음 =================
    Test-Case 'C09' 'KUBECONFIG unset + curl 7.83.1 (no %header{}) -> gate-2/3 and tool-1 FAIL [env]; every HTTP id FAIL [env] curl unusable without a call; 0 kubectl calls, 1 curl call (-q --version)' {
        $script:needle = New-Needle
        $c = New-GoodCurl
        $c['--version'] = C-Version '7.83.1'
        $d = New-Fixture (New-GoodKube) $c
        $r = Invoke-Harness $d -kubeconfigValue '<unset>'
        Assert-Run 'C09' $r $d 0 1
        Assert-IdExact 'C09-1: gate-2 FAIL [env] KUBECONFIG not set' $r 'gate-2' 'FAIL' '[env] KUBECONFIG is not set -- no cluster (agent-view token kubeconfig required; cluster unavailable)'
        Assert-IdExact 'C09-2: gate-3 FAIL [env]' $r 'gate-3' 'FAIL' '[env] cluster unavailable (KUBECONFIG not set)'
        Assert-IdExact 'C09-3: tool-1 FAIL [env] -- curl older than 7.84.0' $r 'tool-1' 'FAIL' '[env] curl 7.83.1 is older than 7.84.0 (no %header{} write-out)'
        foreach ($hid in $httpIds) { Assert-IdExact "C09-4 ${hid}: FAIL [env] curl unusable" $r $hid 'FAIL' '[env] curl unusable (tool-1: curl 7.83.1 is older than 7.84.0 (no %header{} write-out))' }
        Assert-IdExact 'C09-5: ing-1 FAIL [env] cluster unavailable' $r 'ing-1' 'FAIL' '[env] cluster unavailable (KUBECONFIG not set)'
        Assert 'C09-6: exit 1 and summary "1 passed, 17 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '1 passed, 17 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 게이트: curl 가림(함수) =================
    Test-Case 'C10' 'curl shadowed by a function -> tool-1 FAIL [env], no curl call at all (the shadow is never invoked), HTTP ids FAIL [env]; kubectl assertions unaffected (today state)' {
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) (New-TodayCurl) @{ 'bootstrap.ps1' = $bootstrapFunction }
        $r = Invoke-Harness $d -entry 'bootstrap.ps1'
        Assert-Run 'C10' $r $d 3 0
        $shadow = "the first resolution of 'curl' has command type Function, not Application -- an alias, function or script shadows the curl application"
        Assert-IdExact 'C10-1: tool-1 FAIL [env] -- shadowed by a function' $r 'tool-1' 'FAIL' "[env] $shadow"
        foreach ($hid in $httpIds) { Assert-IdExact "C10-2 ${hid}: FAIL [env] curl unusable" $r $hid 'FAIL' "[env] curl unusable (tool-1: $shadow)" }
        Assert-IdExact 'C10-3: ing-1 keeps its today line' $r 'ing-1' 'FAIL' ([string]$todayExpect['ing-1'][1])
        Assert 'C10-4: exit 1 and summary "3 passed, 15 failed, 4 skipped"; the shadow function never ran' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '3 passed, 15 failed, 4 skipped') -and -not (Has-Text $r.out 'must never be called') -and -not (Has-Text $r.err 'must never be called')) (Format-Result $r)
    }

    # ================= 게이트: curl 가림(별칭) + KUBECONFIG 경로 목록 =================
    Test-Case 'C11' 'curl shadowed by an alias + KUBECONFIG is a path list -> tool-1 FAIL [env] (alias), gate-2 FAIL [env] (path list), 0 kubectl and 0 curl calls' {
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) (New-TodayCurl) @{ 'bootstrap.ps1' = $bootstrapAlias }
        $kc = Join-Path $d 'kubeconfig.yaml'
        $r = Invoke-Harness $d -entry 'bootstrap.ps1' -kubeconfigValue "$kc$sep$kc"
        Assert-Run 'C11' $r $d 0 0
        Assert-IdExact 'C11-1: tool-1 FAIL [env] -- shadowed by an alias' $r 'tool-1' 'FAIL' "[env] the first resolution of 'curl' has command type Alias, not Application -- an alias, function or script shadows the curl application"
        Assert-IdExact 'C11-2: gate-2 FAIL [env] -- path list' $r 'gate-2' 'FAIL' '[env] KUBECONFIG must be a single file path (path list not supported)'
        Assert-IdExact 'C11-3: gate-3 FAIL [env]' $r 'gate-3' 'FAIL' '[env] cluster unavailable (KUBECONFIG is a path list)'
        Assert 'C11-4: exit 1 and summary "1 passed, 17 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '1 passed, 17 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 게이트: curl 없음 =================
    Test-Case 'C12' 'no curl on PATH -> tool-1 FAIL [env] curl not found; HTTP ids FAIL [env]; kubectl assertions keep the today lines' {
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) $null
        $r = Invoke-Harness $d -withCurl $false
        Assert-Run 'C12' $r $d 3 0
        Assert-IdExact 'C12-1: tool-1 FAIL [env] -- curl not found' $r 'tool-1' 'FAIL' '[env] curl not found on PATH'
        foreach ($hid in $httpIds) { Assert-IdExact "C12-2 ${hid}: FAIL [env] curl unusable" $r $hid 'FAIL' '[env] curl unusable (tool-1: curl not found on PATH)' }
        foreach ($tid in @('fga-1', 'fga-2', 'fga-3', 'fga-4')) { Assert-IdExact "C12-3 ${tid}: keeps its today line" $r $tid 'FAIL' $gateJob }
        Assert 'C12-4: exit 1 and summary "3 passed, 15 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '3 passed, 15 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 F(r1 — C-5): Location이 붙은 403 · 401 · 405, 옛 id FAIL이 겹친 「새 id 없음」 =================
    Test-Case 'C13' 'variant F (r1 -- C-5): acc-1 403 text/html WITH a Location + Ingress -> [product] (not an empty PASS); m2m 401 text/html with a Location -> FAIL; xchg-0 405 with a Location -> FAIL; Job with the old ids only AND an old id FAILing -> fga [product] (not [gate] until T082)' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.logs] = R-Raw (New-AuthzLog $authzOldIds @{ 'check-allowed' = 'FAIL' })
        $c = New-GoodCurl
        $c[$U.acc1] = C-Resp '403' 'text/html; charset=UTF-8' "<html>Forbidden $script:needle</html>" ('https://auth.joshuatech.dev/if/flow/default-authentication-flow/?next=' + $script:needle)
        $c[$U.acc3] = C-Resp '401' 'text/html' "<html>$script:needle</html>" ('https://identity-m2m-prod.joshuatech.dev/cdn-cgi/access/login/x?meta=' + $script:needle)
        $c[$U.xchg0] = C-Resp '405' 'text/html; charset=utf-8' '' ('https://auth.joshuatech.dev/if/flow/default-authentication-flow/?next=' + $script:needle)
        $d = New-Fixture $k $c
        $r = Invoke-Harness $d
        Assert-Run 'C13' $r $d 4 10
        Assert-IdExact 'C13-1: acc-1 FAIL [product] -- a 403 with a Location is not the Access block page, even with the origin route (I01)' $r 'acc-1' 'FAIL' "[product] 403 text/html; charset=UTF-8; Location https://auth.joshuatech.dev/if/flow/default-authentication-flow/ for GET $($U.acc1) (expected 302 to the Cloudflare Access login or 403 text/html without Location)"
        Assert-IdExact 'C13-2: acc-3 FAIL [product] -- a 401 with a Location is not the contract C11 answer (I07)' $r 'acc-3' 'FAIL' "[product] 401 text/html; Location https://identity-m2m-prod.joshuatech.dev/cdn-cgi/access/login/x for GET $($U.acc3) (expected 401 text/html without Location -- Access service auth, contract C11)"
        Assert-IdExact 'C13-3: xchg-0 FAIL [product] -- a 405 with a Location is not the token endpoint answer; the reason names the missing condition (I03)' $r 'xchg-0' 'FAIL' "[product] 405 text/html; charset=utf-8; Location https://auth.joshuatech.dev/if/flow/default-authentication-flow/ for GET $($U.xchg0) (expected 405 without Location -- the Authentik token endpoint refuses GET)"
        $pendNote = 'the Job does not emit this check id yet -- T082 adds the four check ids to the authz-assert Job'
        $problems = (@($fgaIds | ForEach-Object { "missing RESULT line for $_ ($pendNote)" }) + @('RESULT FAIL for check-allowed (outside the tracked set)', 'SUMMARY fail=1 (expected 0; pass=1)')) -join '; '
        foreach ($i in 0..3) { Assert-IdExact "C13-4 fga-$($i + 1): FAIL [product], not [gate] until T082 -- the missing new ids come with another problem (I04)" $r "fga-$($i + 1)" 'FAIL' "[product] Job jt-dev/authz-assert log: $($fgaIds[$i]) no RESULT line; 6 problem(s): $problems" }
        Assert-OthersPass 'C13-5: every other id PASS unchanged' $r @('acc-1', 'acc-3', 'xchg-0', 'fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C13-6: exit 1 and summary "11 passed, 7 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '11 passed, 7 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 변이 G(r1 — C-5): 미디어 타입이 다른 403 =================
    Test-Case 'C14' 'variant G (r1 -- C-5): acc-1 403 application/json without a Location + Ingress -> [product] (the media type is part of the Access block-page form); everything else PASS' {
        $script:needle = New-Needle
        $c = New-GoodCurl
        $c[$U.acc1] = C-Json ([ordered]@{ detail = 'forbidden'; x_note = $script:needle }) '403'
        $d = New-Fixture (New-GoodKube) $c
        $r = Invoke-Harness $d
        Assert-Run 'C14' $r $d 4 10
        Assert-IdExact 'C14-1: acc-1 FAIL [product] -- 403 application/json is not the Access block page (I02)' $r 'acc-1' 'FAIL' "[product] 403 application/json for GET $($U.acc1) (expected 302 to the Cloudflare Access login or 403 text/html without Location)"
        Assert-OthersPass 'C14-2: every other id PASS unchanged' $r @('acc-1')
        Assert 'C14-3: exit 1 and summary "17 passed, 1 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '17 passed, 1 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 게이트(r1 — C-5): 다른 서비스 계정 · 닮은 이름 =================
    Test-Case 'C15' 'kubectl gate (r1 -- C-5): whoami is another service account (system:serviceaccount:kube-system:default) or a look-alike that starts with the agent-view user -> gate-3 FAIL [env]; only the exact agent-view user passes' {
        $script:needle = New-Needle
        $k = New-GoodKube
        $k[$Q.who] = New-WhoamiResp 'system:serviceaccount:kube-system:default'
        $d = New-Fixture $k (New-GoodCurl)
        $r = Invoke-Harness $d
        Assert-Run 'C15' $r $d 1 10
        Assert-IdExact 'C15-1: gate-3 FAIL [env] -- another service account is refused (I05)' $r 'gate-3' 'FAIL' "[env] context user is 'system:serviceaccount:kube-system:default', expected $expectedUser (admin/other kubeconfig refused)"
        Assert-IdExact 'C15-2: ing-1 FAIL [env] cluster unavailable' $r 'ing-1' 'FAIL' '[env] cluster unavailable (context user is not agent-view)'
        foreach ($i in 1..4) { Assert-IdExact "C15-3 fga-${i}: FAIL [env] cluster unavailable" $r "fga-$i" 'FAIL' '[env] cluster unavailable (context user is not agent-view)' }
        Assert-OthersPass 'C15-4: gate-1, gate-2, tool-1 and the HTTP ids except acc-1 PASS unchanged' $r @('gate-3', 'ing-1', 'acc-1', 'fga-1', 'fga-2', 'fga-3', 'fga-4')
        Assert 'C15-5: exit 1 and summary "11 passed, 7 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '11 passed, 7 failed, 4 skipped')) (Format-Result $r)
        # 닮은 이름(agent-view 사용자로 시작) — 정확 일치만 통과한다. 빠른 실행: curl 심 없음(HTTP 단언은 curl 호출 없이 [env])
        $script:needle = New-Needle
        $k2 = New-GoodKube
        $k2[$Q.who] = New-WhoamiResp "$expectedUser-x"
        $d2 = New-Fixture $k2 $null
        $r2 = Invoke-Harness $d2 -withCurl $false
        Assert-Run 'C15b' $r2 $d2 1 0
        Assert-IdExact 'C15-6: gate-3 FAIL [env] -- a look-alike starting with the agent-view user is refused (exact match only)' $r2 'gate-3' 'FAIL' "[env] context user is '$expectedUser-x', expected $expectedUser (admin/other kubeconfig refused)"
        Assert 'C15-7: exit 1 and summary "2 passed, 16 failed, 4 skipped"' ($r2.code -eq 1 -and (Test-Same (Get-Summary $r2) '2 passed, 16 failed, 4 skipped')) (Format-Result $r2)
    }

    # ================= curl env 가드(r1 — B-9) =================
    Test-Case 'C16' 'curl env guard (r1 -- B-9): HTTPS_PROXY, all_proxy, NO_PROXY, SSLKEYLOGFILE and CURL_CA_BUNDLE in the environment -> tool-1 PASS; every HTTP id FAIL [guard] curl-env-not-allowed <sorted names> without a curl call (only -q --version); no value printed; kubectl assertions keep the today lines' {
        $script:needle = New-Needle
        $d = New-Fixture (New-TodayKube) (New-TodayCurl)
        $planted = [ordered]@{
            HTTPS_PROXY    = "http://$script:needle.proxy.invalid:3128"
            all_proxy      = "socks5://$script:needle.proxy.invalid:1080"
            NO_PROXY       = "$script:needle.example"
            SSLKEYLOGFILE  = (Join-Path $d "keys-$script:needle.log")
            CURL_CA_BUNDLE = (Join-Path $d "ca-$script:needle.pem")
        }
        $r = Invoke-Harness $d -extraEnv $planted
        Assert-Run 'C16' $r $d 3 1
        $guardLine = '[guard] curl-env-not-allowed CURL_CA_BUNDLE,HTTPS_PROXY,NO_PROXY,SSLKEYLOGFILE,all_proxy (proxy, TLS key log or CA bundle variables would reach curl; values not shown -- unset them and rerun)'
        Assert-Id 'C16-1: tool-1 PASS -- the curl binary itself is fine' $r 'tool-1' 'PASS' @('curl 8.4.0 (')
        foreach ($hid in $httpIds) { Assert-IdExact "C16-2 ${hid}: FAIL [guard] with the variable names only, no curl call" $r $hid 'FAIL' $guardLine }
        foreach ($tid in @('ing-1', 'fga-1', 'fga-2', 'fga-3', 'fga-4')) { Assert-IdExact "C16-3 ${tid}: keeps its today line" $r $tid 'FAIL' ([string]$todayExpect[$tid][1]) }
        Assert 'C16-4: exit 1 and summary "4 passed, 14 failed, 4 skipped"' ($r.code -eq 1 -and (Test-Same (Get-Summary $r) '4 passed, 14 failed, 4 skipped')) (Format-Result $r)
    }

    # ================= 정적(하네스 원문 · AST) =================
    Test-Case 'S01' 'harness source: the header names every id and the s1-2 expectations; the code never mutates, never gates on tasks.md, SKIPs only via the two phrase constants, never calls the exchange judges live, uses no other HTTP client and no forbidden curl flag' {
        $src = if (Test-Path -LiteralPath $harnessPath -PathType Leaf) { [IO.File]::ReadAllText($harnessPath) } else { '' }
        Assert 'S01-0: the harness file exists' ($src.Length -gt 0) "missing: $harnessPath"
        if ($src.Length -gt 0) {
            $hdr = [Collections.Generic.List[string]]::new()
            foreach ($l in @($src -split "`r?`n")) { if ($l.StartsWith('#', [StringComparison]::Ordinal)) { $hdr.Add($l) } else { break } }
            $header = $hdr -join "`n"
            $need = @('tests/platform/identity.tests.ps1', 'T078', 'US4', 'test-first', 'Run:', 'chcp.com 65001', 'run-platform-tests.ps1', 'Exit 0', 'gate-1..3', 'tool-1', 'ing-1', 'acc-1', 'acc-2', 'acc-3',
                'pub-1', 'pub-2', 'pub-3', 'pub-4', 'pub-5', 'xchg-0', 'xchg-1', 'xchg-2', 'fga-1', 'fga-2', 'fga-3', 'fga-4', 'man-1', 'man-2', '6 passed, 12 failed, 4 skipped',
                '[gate]', '[env]', '[product]', 'Traefik 404', 'until T080', 'T082', 'T085', 'VD-T080-a', 'VD-T081-d', 'VD-T082-a', 'VD-1', 'Test-ExchangeClaims', 'Test-ExchangeRejection',
                'agent-view', '-q -s -S --max-time 20 --proto =https', 'identity-tests-', 'Mask-Text', 'R30', 'tests/scripts/identity-tests.tests.ps1',
                '[guard]', 'curl-env-not-allowed', '_PROXY', 'SSLKEYLOGFILE', 'CURL_CA_BUNDLE', 'SSL_CERT_FILE', 'SSL_CERT_DIR')
            $missing = @($need | Where-Object { -not (Has-Text $header $_) })
            Assert 'S01-1: the header lists every id, the s1-2 summary, the class prefixes, the owner tasks, the VD items, the exchange judges and the curl call shape' ($missing.Count -eq 0) "missing in header: $($missing -join ', ')"
            $verbTokens = @("'exec'", "'delete'", "'apply'", "'patch'", "'edit'", "'scale'", "'create'", "'replace'", "'cp'", "'port-forward'", "'describe'", "'drain'", "'cordon'")
            $secretReads = @("'get',\s*'secrets?", "'secrets?(\.v1)?'\s*,\s*'-n'")
            Assert 'S01-2: no mutating kubectl verb token and no Secret read' (@($verbTokens | Where-Object { Has-Text $src $_ }).Count -eq 0 -and @($secretReads | Where-Object { [regex]::IsMatch($src, $_) }).Count -eq 0) 'found a forbidden verb token or a Secret read'
            $tokens = $null; $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$tokens, [ref]$errors)
            Assert 'S01-3: the harness parses' (@($errors).Count -eq 0) "$(@($errors | ForEach-Object { $_.Message }) -join '; ')"
            $cmds = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))
            $names = @($cmds | ForEach-Object { [string]$_.GetCommandName() } | Where-Object { $_.Length -gt 0 })
            $badCmd = @($names | Where-Object { In-Set @('Invoke-WebRequest', 'Invoke-RestMethod', 'iwr', 'irm', 'curl', 'curl.exe', 'wget', 'Start-BitsTransfer', 'Test-ExchangeClaims', 'Test-ExchangeRejection', 'Read-TasksMd', 'Get-TaskLineState') $_ })
            Assert 'S01-4: no other HTTP client, no bare curl by name, no live call to the exchange judges, no tasks.md gate' ($badCmd.Count -eq 0) "found: $($badCmd -join ', ')"
            # 금지 curl 플래그는 curl argv를 만드는 Invoke-Curl 안에서 본다(kubectl 인자 '-n'은 curl의 --netrc 짧은 꼴과 글자가 같다 — 실행 argv는 Assert-Run이 본다)
            $strings = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
            $curlFn = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and (Test-Same $n.Name 'Invoke-Curl') }, $true))
            $curlStrings = @($curlFn | ForEach-Object { $_.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) } | ForEach-Object { [string]$_.Value })
            $badStr = @($strings | Where-Object { (Has-Text $_ 'tasks.md') -or (Has-Text $_ 'Net.WebClient') -or (Has-Text $_ 'Net.Http.HttpClient') }) + @($curlStrings | Where-Object { Test-ForbiddenCurlToken $_ })
            Assert 'S01-5: Invoke-Curl exists and builds no forbidden curl flag; no tasks.md path or .NET HTTP client among the string constants' ($curlFn.Count -eq 1 -and $badStr.Count -eq 0) "Invoke-Curl definitions=$($curlFn.Count); found: $($badStr -join ' | ')"
            $funcs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object { $_.Name })
            Assert 'S01-6: the exchange judges are defined (a credential block reuses them byte-for-byte)' ((In-Set $funcs 'Test-ExchangeClaims') -and (In-Set $funcs 'Test-ExchangeRejection')) "functions: $($funcs -join ', ')"
            # 함수 정의 밖의 Skip 호출(ClusterAssert · HttpAssert 안의 Skip $id $detail은 래퍼라 뺀다)
            $topSkips = @($cmds | Where-Object {
                    $p = $_.Parent; $inFn = $false
                    while ($null -ne $p) { if ($p -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $inFn = $true; break }; $p = $p.Parent }
                    (Test-Same ([string]$_.GetCommandName()) 'Skip') -and -not $inFn })
            $badSkip = @($topSkips | Where-Object { $_.CommandElements.Count -lt 3 -or -not ($_.CommandElements[2] -is [System.Management.Automation.Language.VariableExpressionAst]) -or -not (In-Set @('SkipCredBlock', 'SkipManual') $_.CommandElements[2].VariablePath.UserPath) })
            Assert 'S01-7: exactly 4 top-level Skip calls, each with $SkipCredBlock or $SkipManual; no assertion body returns SKIP' ($topSkips.Count -eq 4 -and $badSkip.Count -eq 0 -and -not (Has-Text $src "@('SKIP'")) "top-level Skip calls=$($topSkips.Count); bad: $(@($badSkip | ForEach-Object { $_.Extent.Text }) -join ' || ')"
            $envVars = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | ForEach-Object { $_.VariablePath.UserPath } | Where-Object { $_.StartsWith('env:', [StringComparison]::OrdinalIgnoreCase) })
            $badEnv = @($envVars | Where-Object { -not (In-Set @('env:KUBECONFIG', 'env:USERPROFILE') $_) })
            Assert 'S01-8: the only environment variable values read are KUBECONFIG and USERPROFILE (no JT_E2E_*, Vault or token variable; the curl env guard reads names only -- S01-9)' ($badEnv.Count -eq 0) "found: $((@($badEnv) | Sort-Object -Unique) -join ', ')"
            # curl env 가드는 이름만 본다(r1 — B-9): [Environment]::GetEnvironmentVariables()는 정확히 한 번 · 그 결과의 .Keys로만 쓰고 · 값 하나 읽기(GetEnvironmentVariable) 0
            $envCalls = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and ((Test-Same $n.Member.Value 'GetEnvironmentVariables') -or (Test-Same $n.Member.Value 'GetEnvironmentVariable')) }, $true))
            $keysOnly = @($envCalls | Where-Object { (Test-Same $_.Member.Value 'GetEnvironmentVariables') -and $_.Parent -is [System.Management.Automation.Language.MemberExpressionAst] -and [object]::ReferenceEquals($_.Parent.Expression, $_) -and $_.Parent.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and (Test-Same $_.Parent.Member.Value 'Keys') })
            Assert 'S01-9: the curl env guard reads environment names only -- one [Environment]::GetEnvironmentVariables() call used as .Keys, no single-variable read (r1 -- B-9)' ($envCalls.Count -eq 1 -and $keysOnly.Count -eq 1) "calls: [$(@($envCalls | ForEach-Object { $_.Parent.Extent.Text }) -join ' || ')]"
        }
    }

    # ================= 함수(순수 함수 표) =================
    $script:mod = $null
    $script:modError = ''
    try { $script:mod = Import-HarnessModule $harnessPath } catch { $script:modError = $_.Exception.Message }
    Test-Case 'S02' 'harness constants: VD-1 option B, the RFC 8414 candidate path, the write-out format, the login slug, the root-config key, the four check ids (pending until T082), the Traefik 404 signature, the SKIP phrases, the curl env guard names (= the companion copy)' {
        $ok = ($null -ne $script:mod)
        Assert 'S02-0: the harness module imports' $ok "module: $script:modError"
        if ($ok) {
            $v = & $script:mod { @{ vd1 = $Vd1Option; wk = $WellKnownRootPath; fmt = $CurlWriteOut; slug = $LoginFlowSlug; key = $RootConfigKey; ids = (@($FgaIds) -join ','); pend = (@($FgaPendingIds) -join ','); sha = $Traefik404Sha256; ct = $Traefik404ContentType; size = $Traefik404Size; min = "$CurlMinVersion"; aud = $ExchangeAudience; life = $ExchangeLifetimeSec; rej = $RejectedAudience; err = $RejectError; iss = $ExpectedIssuer; cred = $SkipCredBlock; man = $SkipManual; to = $HttpTimeoutSec; envg = (@($CurlEnvGuardNames) -join ',') } }
            # envg: curl env 가드 이름(r1 — B-9) = 짝 하네스 사본 $curlGuardExact — 둘이 어긋나면 자식 env 정리(Invoke-Harness)와 하네스 가드가 갈라진다
            $want = [ordered]@{ vd1 = 'B'; wk = '/.well-known/oauth-authorization-server/application/o/identity-admin'; fmt = $expectedFmt; slug = 'default-authentication-flow'; key = 'capabilities'; ids = ($fgaIds -join ','); pend = ($fgaIds -join ','); sha = 'b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793'; ct = 'text/plain; charset=utf-8'; size = '19'; min = '7.84.0'; aud = 'identity-admin'; life = '300'; rej = 'portfolio-core'; err = 'invalid_target'; iss = $goodIssuer; cred = $skipCred; man = $skipManual; to = '20'; envg = ($curlGuardExact -join ',') }
            $bad = @($want.Keys | Where-Object { -not (Test-Same ([string]$v[$_]) ([string]$want[$_])) } | ForEach-Object { "$_=[$($v[$_])] (expected [$($want[$_])])" })
            Assert 'S02-1: the constants the s1-2 table and D8 fix' ($bad.Count -eq 0) ($bad -join '; ')
        }
    }

    Test-Case 'F01' 'Test-ExchangeClaims: aud (string / one-element array / two entries / other / absent), tenant_id (canonical lowercase UUID only), exp - iat = 300, VD-1 option B ignores act, option A requires act.sub = the web-bff client, broken JWTs, iss as INFO; no value of the token in the returned text' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-ExchangeClaims')
        Assert 'F01-0: the harness defines Test-ExchangeClaims' $ok "missing (module: $script:modError)"
        if ($ok) {
            $n = New-Needle
            function Edit-Claims([scriptblock]$edit) { $c = Good-Claims $n; & $edit $c; return $c }
            $hdr = B64UrlText (Json ([ordered]@{ alg = 'RS256'; kid = "kid-$n" }))
            $sig = B64UrlText "sig-$n"
            $notJson = B64UrlText "not json $n"
            $arrPayload = B64UrlText '[{"aud":"identity-admin"}]'
            $rows = @(
                @{ name = 'good: aud string, canonical tenant_id, exp-iat 300, no act, option B'; jwt = (New-Jwt (Good-Claims $n) $n); opt = 'B'; ok = $true; has = @('iss=https://auth.joshuatech.dev/application/o/identity-admin/', 'act absent') },
                @{ name = 'aud as a one-element array'; jwt = (New-Jwt (Edit-Claims { param($c) $c['aud'] = @('identity-admin') }) $n); opt = 'B'; ok = $true },
                @{ name = 'aud with two entries'; jwt = (New-Jwt (Edit-Claims { param($c) $c['aud'] = @('identity-admin', 'portfolio-core') }) $n); opt = 'B'; ok = $false; has = @('aud has 2 entries') },
                @{ name = 'other aud'; jwt = (New-Jwt (Edit-Claims { param($c) $c['aud'] = 'portfolio-core' }) $n); opt = 'B'; ok = $false; has = @("aud is 'portfolio-core' (expected 'identity-admin')") },
                @{ name = 'aud absent'; jwt = (New-Jwt (Edit-Claims { param($c) $c.Remove('aud') }) $n); opt = 'B'; ok = $false; has = @('aud is absent') },
                @{ name = 'tenant_id absent'; jwt = (New-Jwt (Edit-Claims { param($c) $c.Remove('tenant_id') }) $n); opt = 'B'; ok = $false; has = @('tenant_id is absent') },
                @{ name = 'tenant_id not a uuid'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = "t-$n" }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'tenant_id uppercase'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = '3F2B8C1E-9A4D-4E6B-8F1A-2C3D4E5F6A7B' }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'tenant_id without dashes'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = '3f2b8c1e9a4d4e6b8f1a2c3d4e5f6a7b' }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'tenant_id in braces'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = '{3f2b8c1e-9a4d-4e6b-8f1a-2c3d4e5f6a7b}' }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'tenant_id with a trailing newline'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = "3f2b8c1e-9a4d-4e6b-8f1a-2c3d4e5f6a7b`n" }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'tenant_id a number'; jwt = (New-Jwt (Edit-Claims { param($c) $c['tenant_id'] = 123 }) $n); opt = 'B'; ok = $false; has = @('tenant_id is not a canonical lowercase UUID string') },
                @{ name = 'exp - iat = 299'; jwt = (New-Jwt (Edit-Claims { param($c) $c['exp'] = 1795000299 }) $n); opt = 'B'; ok = $false; has = @('exp - iat = 299 (expected 300)') },
                @{ name = 'exp - iat = 301'; jwt = (New-Jwt (Edit-Claims { param($c) $c['exp'] = 1795000301 }) $n); opt = 'B'; ok = $false; has = @('exp - iat = 301 (expected 300)') },
                @{ name = 'exp absent'; jwt = (New-Jwt (Edit-Claims { param($c) $c.Remove('exp') }) $n); opt = 'B'; ok = $false; has = @('exp is absent or not a number') },
                @{ name = 'iat as a string'; jwt = (New-Jwt (Edit-Claims { param($c) $c['iat'] = '1795000000' }) $n); opt = 'B'; ok = $false; has = @('iat is absent or not a number') },
                @{ name = 'option B with act present'; jwt = (New-Jwt (Edit-Claims { param($c) $c['act'] = [ordered]@{ sub = "actor-$n" } }) $n); opt = 'B'; ok = $true; has = @('act present (VD-1 option B: not asserted)') },
                @{ name = 'option A with act.sub = the web-bff client'; jwt = (New-Jwt (Edit-Claims { param($c) $c['act'] = [ordered]@{ sub = 'web-bff-dev' } }) $n); opt = 'A'; ok = $true; has = @('act.sub matches the web-bff client (VD-1 option A)') },
                @{ name = 'option A with another act.sub'; jwt = (New-Jwt (Edit-Claims { param($c) $c['act'] = [ordered]@{ sub = "actor-$n" } }) $n); opt = 'A'; ok = $false; has = @("act.sub differs from 'web-bff-dev' (VD-1 option A)") },
                @{ name = 'option A without act'; jwt = (New-Jwt (Good-Claims $n) $n); opt = 'A'; ok = $false; has = @("act is absent (VD-1 option A requires act.sub = 'web-bff-dev')") },
                @{ name = 'unknown option'; jwt = (New-Jwt (Good-Claims $n) $n); opt = 'C'; ok = $false; has = @("unknown VD-1 option 'C' (expected A or B)") },
                @{ name = 'two parts'; jwt = "$hdr.$sig"; opt = 'B'; ok = $false; has = @('not a compact JWS (expected 3 dot-separated parts, got 2)') },
                @{ name = 'payload not base64url'; jwt = "$hdr.!!$n!!.$sig"; opt = 'B'; ok = $false; has = @('JWT payload is not base64url') },
                @{ name = 'payload not JSON'; jwt = "$hdr.$notJson.$sig"; opt = 'B'; ok = $false; has = @('JWT payload is not UTF-8 JSON') },
                @{ name = 'payload a JSON array'; jwt = "$hdr.$arrPayload.$sig"; opt = 'B'; ok = $false; has = @('JWT payload is not a JSON object') },
                @{ name = 'empty token'; jwt = ''; opt = 'B'; ok = $false; has = @('not a compact JWS') },
                @{ name = 'iss elsewhere -> INFO only, value withheld'; jwt = (New-Jwt (Edit-Claims { param($c) $c['iss'] = "https://evil.example/$n/" }) $n); opt = 'B'; ok = $true; has = @('iss not under https://auth.joshuatech.dev/ (value not shown)') }
            )
            $bad = @()
            foreach ($row in $rows) {
                $v = & $script:mod { param($j, $o, $a) Test-ExchangeClaims $j $o $a } $row.jwt $row.opt 'web-bff-dev'
                $text = (@($v.problems) + @($v.info)) -join ' | '
                $miss = @(@($row.has) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { -not (Has-Text $text $_) })
                $parts = @(([string]$row.jwt).Split('.') | Where-Object { $_.Length -ge 8 })
                $leak = (Has-Text $text $n) -or @($parts | Where-Object { Has-Text $text $_ }).Count -gt 0
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $leak) { $bad += "$($row.name): ok=$($v.ok) leak=$leak [$text]" }
            }
            Assert 'F01-1: the exchange-claims table (no token value, needle or JWT segment in the returned text)' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F02' 'Test-ExchangeRejection: 400 + error = invalid_target only (ordinal); other codes, other statuses, non-JSON, a JSON array or an issued token FAIL; no body value printed except a plain error code' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-ExchangeRejection')
        Assert 'F02-0: the harness defines Test-ExchangeRejection' $ok "missing (module: $script:modError)"
        if ($ok) {
            $n = New-Needle
            $tokenBody = Json ([ordered]@{ access_token = (New-Jwt (Good-Claims $n) $n); issued_token_type = 'urn:ietf:params:oauth:token-type:access_token'; token_type = 'Bearer'; expires_in = 300 })
            $rows = @(
                @{ name = '400 invalid_target'; status = 400; body = ('{"error":"invalid_target","error_description":"' + $n + '"}'); ok = $true; has = @('error=invalid_target') },
                @{ name = '400 invalid_request'; status = 400; body = ('{"error":"invalid_request","error_description":"' + $n + '"}'); ok = $false; has = @("error='invalid_request' (expected 'invalid_target'") },
                @{ name = '200 with an issued token'; status = 200; body = $tokenBody; ok = $false; has = @('status 200 (expected 400)', 'an access_token was issued') },
                @{ name = '400 not JSON'; status = 400; body = "<html>$n</html>"; ok = $false; has = @('body is not JSON') },
                @{ name = '401 invalid_client'; status = 401; body = '{"error":"invalid_client"}'; ok = $false; has = @('status 401 (expected 400)', "error='invalid_client'") },
                @{ name = '400 INVALID_TARGET (ordinal; non-standard value withheld)'; status = 400; body = '{"error":"INVALID_TARGET"}'; ok = $false; has = @('error is a non-standard value (not shown)') },
                @{ name = '400 without error'; status = 400; body = '{}'; ok = $false; has = @("error is absent (expected 'invalid_target')") },
                @{ name = '400 error carrying a needle'; status = 400; body = ('{"error":"bad ' + $n + '"}'); ok = $false; has = @('error is a non-standard value (not shown)') },
                @{ name = '400 JSON array'; status = 400; body = '[{"error":"invalid_target"}]'; ok = $false; has = @('body is not a JSON object') }
            )
            $bad = @()
            foreach ($row in $rows) {
                $v = & $script:mod { param($s, $b) Test-ExchangeRejection $s $b } $row.status $row.body
                $text = (@($v.problems) + @($v.info)) -join ' | '
                $miss = @(@($row.has) | Where-Object { -not (Has-Text $text $_) })
                $leak = Has-Text $text $n
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0 -or $leak) { $bad += "$($row.name): ok=$($v.ok) leak=$leak [$text]" }
            }
            Assert 'F02-1: the exchange-rejection table (no needle in the returned text)' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F03' 'Test-JobLog (copied rule) over the four new ids + Get-JobIdState: exact-one PASS per id, last SUMMARY wins, SUMMARY counts, untracked FAIL, pending note; EVIDENCE lines never count' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-JobLog') -and (Test-ModuleHas $script:mod 'Get-JobIdState')
        Assert 'F03-0: the harness defines Test-JobLog and Get-JobIdState' $ok "missing (module: $script:modError)"
        if ($ok) {
            $good = @(@($authzOldIds + $fgaIds) | ForEach-Object { "RESULT: PASS $_ evidence" }) + @('SUMMARY: pass=6 fail=0')
            $rows = @(
                @{ name = 'all good (old ids ignored)'; lines = $good; pend = @(); ok = $true; has = @() },
                @{ name = 'old ids only, pending -> 4 missing with the note'; lines = @('RESULT: PASS check-allowed x', 'RESULT: PASS cross-tenant-false y', 'SUMMARY: pass=2 fail=0'); pend = $fgaIds; ok = $false; has = @('missing RESULT line for check-member-allowed (pending-note)', 'missing RESULT line for cross-tenant-owner-false (pending-note)') },
                @{ name = 'duplicate id'; lines = @('RESULT: PASS check-owner-allowed again') + $good; pend = @(); ok = $false; has = @('2 RESULT lines for check-owner-allowed (expected exactly 1)') },
                @{ name = 'own FAIL'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS cross-tenant-owner-false', 'RESULT: FAIL cross-tenant-owner-false').Replace('pass=6 fail=0', 'pass=5 fail=1') }); pend = @(); ok = $false; has = @('RESULT FAIL for cross-tenant-owner-false', 'SUMMARY fail=1 (expected 0; pass=5)') },
                @{ name = 'untracked FAIL with a consistent SUMMARY'; lines = @($good | ForEach-Object { $_.Replace('RESULT: PASS check-allowed', 'RESULT: FAIL check-allowed').Replace('pass=6 fail=0', 'pass=5 fail=1') }); pend = @(); ok = $false; has = @('RESULT FAIL for check-allowed (outside the tracked set)') },
                @{ name = 'SUMMARY count mismatch'; lines = @($good | ForEach-Object { $_.Replace('pass=6', 'pass=4') }); pend = @(); ok = $false; has = @('SUMMARY pass=4 fail=0 does not match the RESULT lines (PASS 6, FAIL 0)') },
                @{ name = 'EVIDENCE line carrying RESULT text does not count'; lines = @('EVIDENCE: RESULT: PASS check-member-allowed fake') + @($good | Where-Object { -not (Has-Text $_ 'check-member-allowed') }) ; pend = @(); ok = $false; has = @('missing RESULT line for check-member-allowed') },
                @{ name = 'no SUMMARY'; lines = @($good | Where-Object { -not $_.StartsWith('SUMMARY', [StringComparison]::Ordinal) }); pend = @(); ok = $false; has = @('no SUMMARY line') }
            )
            $bad = @()
            foreach ($row in $rows) {
                $v = & $script:mod { param($l, $i, $p) Test-JobLog $l $i $p 'pending-note' } @($row.lines) $fgaIds @($row.pend)
                $text = @($v.problems) -join '; '
                $miss = @(@($row.has) | Where-Object { -not [string]::IsNullOrEmpty($_) } | Where-Object { -not (Has-Text $text $_) })
                if ([bool]$v.ok -ne [bool]$row.ok -or $miss.Count -gt 0) { $bad += "$($row.name): ok=$($v.ok) [$text]" }
            }
            Assert 'F03-1: the Job-log table over the four new ids' ($bad.Count -eq 0) ($bad -join ' || ')
            $srows = @(
                @{ lines = $good; id = 'check-member-allowed'; count = 1; text = 'RESULT PASS' },
                @{ lines = @('RESULT: PASS check-allowed x'); id = 'check-member-allowed'; count = 0; text = 'no RESULT line' },
                @{ lines = @('RESULT: PASS check-owner-allowed a', 'RESULT: PASS check-owner-allowed b'); id = 'check-owner-allowed'; count = 2; text = '2 RESULT lines' },
                @{ lines = @('RESULT: FAIL cross-tenant-member-false a'); id = 'cross-tenant-member-false'; count = 1; text = 'RESULT FAIL' },
                @{ lines = @('RESULT: PASS cross-tenant-member-false-extra a', ' RESULT: PASS cross-tenant-member-false b', 'EVIDENCE: RESULT: PASS cross-tenant-member-false c'); id = 'cross-tenant-member-false'; count = 0; text = 'no RESULT line' }
            )
            $sbad = @()
            foreach ($row in $srows) {
                $s = & $script:mod { param($l, $i) Get-JobIdState $l $i } @($row.lines) $row.id
                if ([int]$s.count -ne [int]$row.count -or -not (Test-Same ([string]$s.text) $row.text)) { $sbad += "$($row.id) in [$($row.lines -join ' / ')]: count=$($s.count) text=[$($s.text)] (want $($row.count) [$($row.text)])" }
            }
            Assert 'F03-2: the Get-JobIdState table (anchored, exact id, EVIDENCE/indented/prefix lines never count)' ($sbad.Count -eq 0) ($sbad -join ' || ')
        }
    }
    Test-Case 'F04' 'HTTP judges: Traefik 404 signature (every part, cf-cache-status HIT, exact type), media type, Access Location (host exact, https, path prefix, look-alike and userinfo tricks), safe URL (query/fragment dropped), body field access without array unwrapping' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-Traefik404Mismatch') -and (Test-ModuleHas $script:mod 'Test-Traefik404') -and (Test-ModuleHas $script:mod 'Get-MediaType') -and (Test-ModuleHas $script:mod 'Test-AccessLocation') -and (Test-ModuleHas $script:mod 'ConvertTo-SafeUrl') -and (Test-ModuleHas $script:mod 'Get-JsonField')
        Assert 'F04-0: the harness defines Get-Traefik404Mismatch, Test-Traefik404, Get-MediaType, Test-AccessLocation, ConvertTo-SafeUrl and Get-JsonField' $ok "missing (module: $script:modError)"
        if ($ok) {
            $sigSha = 'b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793'
            # 이름 주의: 'h'는 Get-History 별칭이라 같은 이름의 함수보다 먼저 해석된다
            function New-Resp404([hashtable]$o) { $x = @{ status = '404'; ctype = 'text/plain; charset=utf-8'; size = '19'; bodyLen = 19; bodySha = $sigSha; cf = 'DYNAMIC' }; foreach ($k in $o.Keys) { $x[$k] = $o[$k] }; return $x }
            $trows = @(
                @{ name = 'full signature'; h = (New-Resp404 @{}); is = $true; has = '' },
                @{ name = 'cf-cache-status absent'; h = (New-Resp404 @{ cf = '' }); is = $true; has = '' },
                @{ name = 'status 200'; h = (New-Resp404 @{ status = '200' }); is = $false; has = 'status 200 (expected 404)' },
                @{ name = 'text/html'; h = (New-Resp404 @{ ctype = 'text/html' }); is = $false; has = "content-type 'text/html' (expected 'text/plain; charset=utf-8')" },
                @{ name = 'no space after the semicolon (exact type)'; h = (New-Resp404 @{ ctype = 'text/plain;charset=utf-8' }); is = $false; has = 'content-type' },
                @{ name = '18 bytes'; h = (New-Resp404 @{ size = '18'; bodyLen = 18 }); is = $false; has = 'size 18 B (expected 19 B)' },
                @{ name = 'write-out size differs from the body file'; h = (New-Resp404 @{ size = '20' }); is = $false; has = 'write-out size_download 20 differs from the body file (19 B)' },
                @{ name = 'other hash'; h = (New-Resp404 @{ bodySha = ('0' * 64) }); is = $false; has = 'body sha256 differs' },
                @{ name = 'HIT'; h = (New-Resp404 @{ cf = 'HIT' }); is = $false; has = 'cf-cache-status HIT' },
                @{ name = 'hit lowercase'; h = (New-Resp404 @{ cf = 'hit' }); is = $false; has = 'cf-cache-status HIT' }
            )
            $bad = @()
            foreach ($row in $trows) {
                $mm = @(& $script:mod { param($h) Get-Traefik404Mismatch $h } $row.h)
                $is = [bool](& $script:mod { param($h) Test-Traefik404 $h } $row.h)
                if ($is -ne $row.is -or ($row.has.Length -gt 0 -and -not (Has-Text ($mm -join '; ') $row.has))) { $bad += "$($row.name): is=$is [$($mm -join '; ')]" }
            }
            Assert 'F04-1: the Traefik 404 signature table' ($bad.Count -eq 0) ($bad -join ' || ')
            $mrows = @(@('application/json; charset=utf-8', 'application/json'), @('Application/JSON', 'application/json'), @(' text/html ;charset=x', 'text/html'), @('', ''))
            $mbad = @($mrows | Where-Object { -not (Test-Same ([string](& $script:mod { param($c) Get-MediaType $c } $_[0])) $_[1]) } | ForEach-Object { "[$($_[0])]" })
            Assert 'F04-2: Get-MediaType lowercases the type before the first semicolon' ($mbad.Count -eq 0) ($mbad -join ', ')
            $lrows = @(
                @{ loc = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/auth.joshuatech.dev?kid=1&meta=SECRETQ'; ok = $true; safe = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/auth.joshuatech.dev' },
                @{ loc = 'https://JOSHUA-TECH.cloudflareaccess.com/cdn-cgi/access/login/x'; ok = $true; safe = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/x' },
                @{ loc = 'http://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/x'; ok = $false; safe = 'http://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/x' },
                @{ loc = 'https://evil.example/cdn-cgi/access/login/x'; ok = $false; safe = 'https://evil.example/cdn-cgi/access/login/x' },
                @{ loc = 'https://joshua-tech.cloudflareaccess.com.evil.example/cdn-cgi/access/login/x'; ok = $false; safe = 'https://joshua-tech.cloudflareaccess.com.evil.example/cdn-cgi/access/login/x' },
                @{ loc = 'https://joshua-tech.cloudflareaccess.com@evil.example/cdn-cgi/access/login/x'; ok = $false; safe = 'https://evil.example/cdn-cgi/access/login/x' },
                @{ loc = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/logout/x'; ok = $false; safe = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/logout/x' },
                @{ loc = '/cdn-cgi/access/login/x?meta=SECRETQ'; ok = $false; safe = '' },
                @{ loc = ''; ok = $false; safe = '' }
            )
            $lbad = @()
            foreach ($row in $lrows) {
                $t = @(& $script:mod { param($l) Test-AccessLocation $l } $row.loc)
                if ([bool]$t[0] -ne $row.ok -or ($row.safe.Length -gt 0 -and -not (Test-Same ([string]$t[1]) $row.safe)) -or (Has-Text ([string]$t[1]) 'SECRETQ')) { $lbad += "[$($row.loc)] -> ok=$($t[0]) safe=[$($t[1])]" }
            }
            Assert 'F04-3: Test-AccessLocation (copied from ingress.tests.ps1): https + team host exact + /cdn-cgi/access/login/ prefix; safe form drops query and userinfo' ($lbad.Count -eq 0) ($lbad -join ' || ')
            $urows = @(
                @(('https://auth.joshuatech.dev/if/flow/x/?next=SECRETQ#frag'), 'https://auth.joshuatech.dev/if/flow/x/'),
                @(('/if/flow/x/?next=SECRETQ'), '/if/flow/x/'),
                @(('/if/flow/x/#SECRETQ'), '/if/flow/x/'),
                @('', ''),
                @(('ftp://evil.example/x?SECRETQ'), '(unparseable Location)'),
                @(('relative/path?SECRETQ'), '(unparseable Location)')
            )
            $ubad = @($urows | Where-Object { -not (Test-Same ([string](& $script:mod { param($l) ConvertTo-SafeUrl $l } $_[0])) $_[1]) } | ForEach-Object { "[$($_[0])] -> [$(& $script:mod { param($l) ConvertTo-SafeUrl $l } $_[0])] (want [$($_[1])])" })
            Assert 'F04-4: ConvertTo-SafeUrl keeps scheme://host/path (or a /path) and drops query and fragment' ($ubad.Count -eq 0) ($ubad -join ' || ')
            $obj = '{"one":["a"],"none":[],"nul":null,"str":"x","obj":{"k":1}}' | ConvertFrom-Json -NoEnumerate
            $f1 = & $script:mod { param($o) Get-JsonField $o 'one' } $obj
            $f0 = & $script:mod { param($o) Get-JsonField $o 'none' } $obj
            $fn = & $script:mod { param($o) Get-JsonField $o 'nul' } $obj
            $fm = & $script:mod { param($o) Get-JsonField $o 'missing' } $obj
            $fc = & $script:mod { param($o) Get-JsonField $o 'STR' } $obj
            Assert 'F04-5: Get-JsonField keeps arrays (one element stays an array, empty stays empty), tells null from missing, matches names ordinally' ($f1.present -and ($f1.value -is [System.Collections.IList]) -and $f1.value.Count -eq 1 -and $f0.present -and ($f0.value -is [System.Collections.IList]) -and $f0.value.Count -eq 0 -and $fn.present -and $null -eq $fn.value -and -not $fm.present -and -not $fc.present) "one=$($f1.present)/$($f1.value.GetType().Name) none=$($f0.present) nul=$($fn.present) missing=$($fm.present) STR=$($fc.present)"
        }
    }
    Test-Case 'F05' 'curl helpers: Test-CurlVersion (numeric compare against 7.84.0) and ConvertFrom-CurlWriteOut (five fields, CRLF, missing trailing fields, bad status/size)' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Test-CurlVersion') -and (Test-ModuleHas $script:mod 'ConvertFrom-CurlWriteOut')
        Assert 'F05-0: the harness defines Test-CurlVersion and ConvertFrom-CurlWriteOut' $ok "missing (module: $script:modError)"
        if ($ok) {
            $vrows = @(
                @{ t = "curl 8.4.0 (x86_64-w64-mingw32) libcurl/8.4.0`nRelease-Date: x"; ok = $true; v = '8.4.0' },
                @{ t = 'curl 7.84.0 (Windows) libcurl/7.84.0'; ok = $true; v = '7.84.0' },
                @{ t = 'curl 7.83.1 (Windows) libcurl/7.83.1'; ok = $false; v = '7.83.1' },
                @{ t = 'curl 7.9.0 (x)'; ok = $false; v = '7.9.0' },
                @{ t = 'curl 10.0.0 (x)'; ok = $true; v = '10.0.0' },
                @{ t = 'not curl 8.4.0'; ok = $false; v = '' },
                @{ t = ''; ok = $false; v = '' }
            )
            $bad = @()
            foreach ($row in $vrows) {
                $v = & $script:mod { param($t) Test-CurlVersion $t } $row.t
                if ([bool]$v.ok -ne $row.ok -or -not (Test-Same ([string]$v.version) $row.v)) { $bad += "[$($row.t)] -> ok=$($v.ok) v=$($v.version)" }
            }
            Assert 'F05-1: the curl version table' ($bad.Count -eq 0) ($bad -join ' || ')
            $wrows = @(
                @{ t = "200`napplication/json`n12`n`nDYNAMIC"; ok = $true; status = '200'; ctype = 'application/json'; size = '12'; loc = ''; cf = 'DYNAMIC' },
                @{ t = "302`r`n`r`n0`r`nhttps://x.example/a?b`r`nDYNAMIC`r`n"; ok = $true; status = '302'; ctype = ''; size = '0'; loc = 'https://x.example/a?b'; cf = 'DYNAMIC' },
                @{ t = "401`ntext/html`n0"; ok = $true; status = '401'; ctype = 'text/html'; size = '0'; loc = ''; cf = '' },
                @{ t = "abc`ntext/html`n0`n`n"; ok = $false },
                @{ t = "200`ntext/html`nx`n`n"; ok = $false },
                @{ t = '200'; ok = $false },
                @{ t = ''; ok = $false }
            )
            $wbad = @()
            foreach ($row in $wrows) {
                $w = & $script:mod { param($t) ConvertFrom-CurlWriteOut $t } $row.t
                if ([bool]$w.ok -ne $row.ok) { $wbad += "[$($row.t)] -> ok=$($w.ok)"; continue }
                if ($row.ok -and -not ((Test-Same $w.status $row.status) -and (Test-Same $w.ctype $row.ctype) -and (Test-Same $w.size $row.size) -and (Test-Same $w.location $row.loc) -and (Test-Same $w.cf $row.cf))) { $wbad += "[$($row.t)] -> $($w.status)|$($w.ctype)|$($w.size)|$($w.location)|$($w.cf)" }
            }
            Assert 'F05-2: the write-out table' ($wbad.Count -eq 0) ($wbad -join ' || ')
        }
    }
    Test-Case 'F06' 'Find-IngressHost: rules[].host equals the host (case-insensitive), any rule of any Ingress; other hosts, missing rules and empty lists never match' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Find-IngressHost')
        Assert 'F06-0: the harness defines Find-IngressHost' $ok "missing (module: $script:modError)"
        if ($ok) {
            function Items-Of([object[]]$ings) { return @((Json (New-List $ings)) | ConvertFrom-Json -Depth 30).items }
            $rows = @(
                @{ name = 'one match'; ings = @((New-Ingress 'identity' 'authentik' @('auth.joshuatech.dev'))); want = 'identity/authentik' },
                @{ name = 'second rule matches, uppercase host'; ings = @((New-Ingress 'identity' 'multi' @('x.joshuatech.dev', 'AUTH.joshuatech.dev'))); want = 'identity/multi' },
                @{ name = 'two Ingresses, one matches'; ings = @((New-Ingress 'identity' 'a' @('openfga.joshuatech.dev')), (New-Ingress 'identity' 'b' @('auth.joshuatech.dev'))); want = 'identity/b' },
                @{ name = 'look-alike hosts'; ings = @((New-Ingress 'identity' 'c' @('auth.joshuatech.dev.evil', 'xauth.joshuatech.dev'))); want = '' },
                @{ name = 'no rules'; ings = @([ordered]@{ apiVersion = 'networking.k8s.io/v1'; kind = 'Ingress'; metadata = [ordered]@{ name = 'd'; namespace = 'identity' }; spec = [ordered]@{ defaultBackend = [ordered]@{ service = [ordered]@{ name = 's' } } } }); want = '' },
                @{ name = 'empty list'; ings = @(); want = '' }
            )
            $bad = @()
            foreach ($row in $rows) {
                $items = @(Items-Of $row.ings)
                $got = @(& $script:mod { param($i, $h) Find-IngressHost $i $h } $items 'auth.joshuatech.dev') -join ','
                if (-not (Test-Same $got $row.want)) { $bad += "$($row.name): [$got] (want [$($row.want)])" }
            }
            Assert 'F06-1: the Ingress host table' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }
    Test-Case 'F07' 'Get-CurlEnvViolation (r1 -- B-9): names ending in _PROXY (any case) and SSLKEYLOGFILE / CURL_CA_BUNDLE / SSL_CERT_FILE / SSL_CERT_DIR (any case) are flagged once each, sorted ordinally; look-alike names are not' {
        $ok = ($null -ne $script:mod) -and (Test-ModuleHas $script:mod 'Get-CurlEnvViolation')
        Assert 'F07-0: the harness defines Get-CurlEnvViolation' $ok "missing (module: $script:modError)"
        if ($ok) {
            $rows = @(
                @{ names = @('PATH', 'HTTPS_PROXY'); want = 'HTTPS_PROXY' },
                @{ names = @('https_proxy'); want = 'https_proxy' },
                @{ names = @('http_proxy', 'All_Proxy', 'NO_PROXY'); want = 'All_Proxy,NO_PROXY,http_proxy' },
                @{ names = @('no_proxy', 'FTP_PROXY'); want = 'FTP_PROXY,no_proxy' },
                @{ names = @('SSLKEYLOGFILE'); want = 'SSLKEYLOGFILE' },
                @{ names = @('sslkeylogfile'); want = 'sslkeylogfile' },
                @{ names = @('SSL_CERT_FILE', 'KUBECONFIG', 'CURL_CA_BUNDLE', 'SSL_CERT_DIR'); want = 'CURL_CA_BUNDLE,SSL_CERT_DIR,SSL_CERT_FILE' },
                @{ names = @('curl_ca_bundle', 'Ssl_Cert_Dir'); want = 'Ssl_Cert_Dir,curl_ca_bundle' },
                @{ names = @('PROXY', 'HTTPS_PROXY_HOST', 'MY_PROXYCONF', 'SSLKEYLOG', 'SSLKEYLOGFILE2', 'CURL_HOME', 'SSL_CERT', 'USERPROFILE', 'KUBECONFIG'); want = '' },
                @{ names = @(); want = '' },
                @{ names = @('', 'HTTPS_PROXY', 'HTTPS_PROXY'); want = 'HTTPS_PROXY' }
            )
            $bad = @()
            foreach ($row in $rows) {
                $got = @(& $script:mod { param($n) Get-CurlEnvViolation $n } @($row.names))
                if (-not (Test-Same ($got -join ',') $row.want)) { $bad += "[$($row.names -join ',')] -> [$($got -join ',')] (want [$($row.want)])" }
            }
            Assert 'F07-1: the curl env guard name table' ($bad.Count -eq 0) ($bad -join ' || ')
        }
    }

    # 선택 실행에 모르는 케이스 이름이 있으면 실패(오타로 아무것도 안 돌고 통과하지 않게)
    foreach ($o in $script:only) {
        if (-not (In-Set $script:known $o)) { $script:fail++; Write-Host "FAIL filter -- unknown case id '$o' in IDENTITY_HARNESS_TESTS_ONLY (known: $($script:known -join ','))" }
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
