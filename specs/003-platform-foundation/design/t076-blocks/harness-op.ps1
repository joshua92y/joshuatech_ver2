param([string]$Show = '', [string]$Dir = '', [string]$Only = '')
# ===== T076 운영자 블록 모의 실행 하네스 — W-7(w7-seed-tester-m2m.ps1) · O-9(o9-issue-vault-jwt.ps1) · O-10(o10-vault-audience-negative.ps1) =====
# 파생: T075 운영자 블록 하네스(../t075-blocks/harness.ps1 — 닫힌 과제 · 고치지 않는다)의 B부. 그대로 옮긴 것: 실물 차단 가드(PATH 함정 .cmd · 함수 가림 · KUBECONFIG 끊기 · curl/tofu 환경 변수 비움) ·
#   모의(vault 메모리 kv v2 + 결함 · tofu · Read-Host · Set-Clipboard · Set-PSDebug · Get-ItemProperty · Test-Path · Get-Content · Import-Module · Get-Module · Get-Command) · 노출 바늘(전체 · base64 · 8자 조각 ·
#   SHA-256 hex) · 공통 사후 조건(Check-R1 · Check-ErrClean · 위반 0 · 함정 표식 0 · 성공 스트림 0 · 입력 가림 · 첫 동작 Set-PSDebug -Off · 모듈 로깅 확인 순서 · 붙여넣기 모드) ·
#   정적 관문(파서 · 명령 · 형식 · $Host · 리다이렉트 + 구조 · 세션 고정 · finally · Read-Host · vault 모양 · 모듈 로깅 가드 · 비밀 상수 0 · Static-R1).
# 이 세 블록에 맞춘 것: kubectl 모의 = create token agent-view(--audience vault --duration=1h · --duration=10m)만 · curl.exe 모의 = Vault HTTP API(seal-status GET · kubernetes/login POST 본문 stdin ·
#   revoke-self POST 헤더 stdin)만 — 첫 인자 -q 아님 · 금지 플래그(-v · -i · -I · -D · -c · -b · --trace* · -L · --location* · -x · --proxy · -K · --config · -n · --netrc* · -o · -O · -k) = 위반 ·
#   tofu 모의 = version · "-chdir=<저장소>\infra\cloudflare" output -json service_tokens 만 · vault 모의 = W-7 의 version · status · token lookup · kv metadata get · kv get · kv put 만(그 밖 = 위반).
# 파일(O-9): 시나리오마다 LOCALAPPDATA 를 함정 디렉터리 아래 새 폴더로 바꾼다 — 블록은 이 프로세스에서 돈다(T075 하네스 꼴 · 모의 함수가 블록에 보이게) · 끝나면 원래 값으로 되돌린다.
#   DPAPI 는 실물이다(같은 Windows 사용자) — 하네스가 O-8 과 같은 꼴(ReadAllText(ASCII).Trim() | ConvertTo-SecureString → NetworkCredential.Password)로 복호해 발급한 모의 JWT 와 대조한다.
#   노출 검사에 「만든 파일」 면을 더했다(LOCALAPPDATA 아래 모든 파일의 글자 — 평문 JWT · secret · 토큰 0) · 시나리오마다 파일 목록을 기대 목록과 정확히 대조한다(W-7 · O-10 = 0).
# 실물 Vault · 클러스터 · Cloudflare 에 닿지 않는다(함정 표식 0 · KUBECONFIG = 없는 경로 · 관리자 kubeconfig · ~/.vault-token · 설정 파일은 Test-Path · Get-Content 모의가 답한다).
# r1(T076 보정 2026-11-20 — 리뷰 S-07 · C-02 · RO-02 · S-09 · S-10 · RO-03 · aud 두 꼴): 남는 인자(블록 파일을 같은 프로세스에서 & <경로> @ArgList 로 — $script:args = 그 인자 ·
#   붙여넣기 사례는 이 스크립트의 $args 를 $null 로 둔 꼴도) · 외부 명령 첫 해석(Get-Command 형식 필터 없는 질의 모의 — 기본 Application 꼴 · Function · Alias · ExternalScript 가림) ·
#   W-7 cluster_name(다름 · 없음 · 제어 문자) · W-7 창 정리 줄(결정 RO-03 글자 그대로) · O-9 aud 문자열 "vault" 통과 + 경계 사례를 더했다.
# r2(확인 리뷰 rv2 — RO2-02 · rv2C-03): W-7 창 정리 줄을 결과로 가른다 — OK · SKIP 사례 = 닫기 줄($W7CLOSE) · 그 밖 전부 = 유지 줄($W7KEEP) · 둘 다 블록 출력의 마지막 줄(공통 사후 · ST-W7) ·
#   O-10 결과 머리 줄의 기록 자리 = 런북 §4 T076 기록 칸(ST-O10).
# 사용: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-op.ps1 [-Show 'W7-0*'] [-Dir <변이 사본 디렉터리>] [-Only W7|O9|O10]
#   종료 코드 = 실패 시나리오가 있으면 1
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
# 하네스의 남는 인자 0: 붙여넣기 사례(& $psb)의 블록은 이 스크립트 범위의 $args 를 $script:args 로 본다(실측 2026-11-20 pwsh 7.6.10) — 하네스 인자가 블록의 「남는 인자」 판정에 새지 않게
if (@($args | Where-Object { $null -ne $_ }).Count -gt 0) { throw "하네스 인자는 -Show · -Dir · -Only 뿐이다(남는 인자 $(@($args).Count)개 — 붙여넣기 사례의 블록이 이 스크립트의 `$args 를 본다)" }
$Clock = [Diagnostics.Stopwatch]::StartNew()
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockDir = if ([string]::IsNullOrEmpty($Dir)) { $here } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dir) }
$OnlySel = [string]$Only
if ($OnlySel.Length -gt 0 -and -not (@('W7', 'O9', 'O10') -contains $OnlySel)) { throw "-Only 는 W7 · O9 · O10 중 하나다(받은 값: $OnlySel)" }
$RunW7 = ($OnlySel.Length -eq 0) -or [string]::Equals($OnlySel, 'W7', [StringComparison]::OrdinalIgnoreCase)
$RunO9 = ($OnlySel.Length -eq 0) -or [string]::Equals($OnlySel, 'O9', [StringComparison]::OrdinalIgnoreCase)
$RunO10 = ($OnlySel.Length -eq 0) -or [string]::Equals($OnlySel, 'O10', [StringComparison]::OrdinalIgnoreCase)
$OrigWhatIf = $global:WhatIfPreference
$OrigPSDPV = $global:PSDefaultParameterValues.Clone()

# ---------------------------------------------------------------- 계약(블록과 독립으로 하네스가 들고 있는 기대값 — 설계 t076-design.md D2 · D7 · 계약 · T075 실측)
$global:EXPECTED_ADDR = 'http://127.0.0.1:18200'
$global:FAKE_ROOT = 'hvs.MOCK-ROOT-Qw7Er9Ty2Ui4Op6As8DfGh'
$global:FAKE_WRONG = 'hvs.MOCK-WRONG-Lk3Jh5Gf7Ds9Ap1Qw2Ee'
$global:FAKE_VTOKEN = 'hvs.MOCK-VTOK-Zx1Cv3Bn5Mm7Kk9Ll0Pp'
$W7PATH = 'kv/platform/access/tester-m2m'
$CLUSTER = 'vault-cluster-d3b29227'
$AGENT_SUB = 'system:serviceaccount:kube-system:agent-view'
$JWT_REL = 'jt-e2e\vault-e2e-reader.jwt'
$DEF_AUD = [string[]]@('https://kubernetes.default.svc.cluster.local', 'k3s')
# W-7 finally 의 창 정리 줄 — 결과로 가른다(컨트롤러 결정 .superpowers/t076/decisions-controller.md 의 정확한 글자): $W7CLOSE = 「r0 리뷰 처리」 RO-03(w7=OK … · w7=SKIP live-same 일 때만 —
#   창 C 종료) · $W7KEEP = 「rv2 확인 리뷰 처리」 RO2-02(그 밖 전부 — w7=STOP … · 예외 · 중단 = 기본값 · 실패 표 조치에 18200 이 필요하다)
$W7CLOSE = '창 정리(T076 — 런북 bootstrap.md §3 T076 ①-5): 창 C port-forward(18200) 종료(Ctrl+C — 뒤 단계는 18200 을 쓰지 않는다) · 창 A 터널 · 창 D 는 닫지 않는다(②-3 O-7 · ④-1 · ④-3 O-9 · ⑤ 세션 끝 정리까지)'
$W7KEEP = '창 정리(T076 — 런북 bootstrap.md §4 T076 실패 표): 창 C port-forward(18200) 는 닫지 않는다(실패 표 조치 — 재실행 · 버전 이력 · cluster_name 조사에 18200 이 필요하다) · 창 A 터널 · 창 D 도 닫지 않는다'
# 남는 인자 사례의 임의 값(화면 · $Error 등 모든 면에 0 이어야 한다 — 전체 일치 바늘)
$ARGVAL = 'ARGVAL-q8w7e6r5t4y3'
function SEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::Ordinal) }
function IEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::OrdinalIgnoreCase) }
function Hex-Lower { param([string]$s) -join @([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) }
function B64U { param([string]$s) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function Tilde { param([string]$s) if (-not [string]::IsNullOrEmpty($HOME) -and $s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { '~' + $s.Substring($HOME.Length) } else { $s } }
# Cloudflare 서비스 토큰 모의(T075 L4 실측 꼴): client_id = 소문자 hex 32 + .access · client_secret = 54자 [A-Za-z0-9_-]('MOCK-' 5자 + SHA-512 base64url 49자 · hex 밖 글자 있음)
function Cf-Secret { param([string]$s) ('MOCK-' + [Convert]::ToBase64String([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes($s))).Replace('+', '-').Replace('/', '_')).Substring(0, 54) }
$TOKV = [ordered]@{}
foreach ($k in 'web-bff-dev', 'web-bff-prod', 'tester-m2m', 'tester-k8s') { $TOKV[$k] = [ordered]@{ client_id = ((Hex-Lower "cid-$k").Substring(0, 32) + '.access'); client_secret = (Cf-Secret "secret-$k"); expires_at = '2027-09-03T00:00:00Z' } }
$TM_ID = [string]$TOKV['tester-m2m']['client_id']
$TM_SEC = [string]$TOKV['tester-m2m']['client_secret']

# ---------------------------------------------------------------- 0) 실물 차단 가드(블록을 한 번이라도 돌리기 전에 — T075 하네스 그대로)
$TrapDir = Join-Path ([IO.Path]::GetTempPath()) ('t076-harness-op-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TrapDir)
foreach ($n in 'vault', 'kubectl', 'tofu') {
  [IO.File]::WriteAllText((Join-Path $TrapDir "$n.cmd"), "@echo off`r`necho TRAP>`"%~dp0CALLED-$n`"`r`nexit /b 97`r`n", [Text.UTF8Encoding]::new($false)) }
$RealDirs = @(Get-Command vault, kubectl, tofu, vault.exe, kubectl.exe, tofu.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { (Split-Path -Parent $_.Source).TrimEnd('\') })
$sep = [IO.Path]::PathSeparator
$keptPath = @($env:PATH -split [regex]::Escape($sep) | Where-Object {
    $d = $_; if ([string]::IsNullOrEmpty($d)) { return $false }
    foreach ($r in $RealDirs) { if ([string]::Equals($d.TrimEnd('\'), $r, [StringComparison]::OrdinalIgnoreCase)) { return $false } }
    $true })
$OrigPath = $env:PATH
$env:PATH = (@($TrapDir) + $keptPath) -join $sep
$OrigKubeconfig = $env:KUBECONFIG
$FakeKubeconfig = Join-Path $TrapDir 'no-such-kubeconfig'
$env:KUBECONFIG = $FakeKubeconfig
# 블록이 멈추는 환경 변수(curl · tofu · TLS · 프록시)를 하네스 동안 지우고 끝에 되돌린다(값은 출력하지 않는다 — 이름만 저장 목록에)
$NetEnvNames = @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR')
$NetEnvSaved = @{}
foreach ($v in @(Get-ChildItem Env: | Where-Object { $NetEnvNames -contains $_.Name -or $_.Name -like 'TF_LOG*' -or $_.Name -like 'TF_CLI_ARGS*' })) { $NetEnvSaved[$v.Name] = $v.Value; Remove-Item -LiteralPath ('Env:' + $v.Name) }
# LOCALAPPDATA: 하네스 동안 함정 디렉터리 아래(시나리오마다 새 폴더) — 운영자의 실물 %LOCALAPPDATA%\jt-e2e 를 건드리지 않는다
$OrigLad = $env:LOCALAPPDATA
$LadRoot = Join-Path $TrapDir 'lad'
[void](New-Item -ItemType Directory -Path $LadRoot)
$env:LOCALAPPDATA = $LadRoot

# ---------------------------------------------------------------- 모의 명령(블록의 StrictMode 3.0 아래에서 돈다 — 해시 테이블은 ['키'] 로만 읽는다)
function At { param($arr, [int]$i) $l = @($arr); if ($i -ge 0 -and $i -lt $l.Count) { [string]$l[$i] } else { '' } }
function Has-Flag { param($list, [string]$f) foreach ($x in @($list)) { if (SEq $x $f) { return $true } }; $false }
function Add-Event { param([string]$e) [void]$global:Events.Add($e) }
function Add-Violation { param([string]$v) [void]$global:Violations.Add($v) }
# native stderr 흉내(T075 그대로): 호출자의 EAP=Stop 아래에서도 종료 오류가 되지 않게 지역 EAP 를 Continue 로 둔다
function Mock-Stderr { param([string[]]$lines) $ErrorActionPreference = 'Continue'; foreach ($l in $lines) { Write-Error -Message $l } }
function Json-Lines { param($obj) @((ConvertTo-Json -InputObject $obj -Depth 10) -split "`r?`n") }
function Take-Fault { param([string]$kind, [string]$path)
  $t = $global:F[$kind]
  if ($null -eq $t -or -not $t.ContainsKey($path)) { return $false }
  $c = [int]$t[$path]
  if ($c -le 0) { return $false }
  $t[$path] = $c - 1
  $true }
function KvRest { param([string]$path) if ($path.StartsWith('kv/', [StringComparison]::Ordinal)) { $path.Substring(3) } else { $path } }
function Split-FlagsPath { param($rest)
  $flags = @(); $path = $null; $trail = @(); $bad = ''
  foreach ($x in @($rest)) {
    $s = [string]$x
    if ($null -eq $path) {
      if (SEq $s '-') { $bad = 'stdin 표식이 경로 앞' }
      elseif ($s.StartsWith('-', [StringComparison]::Ordinal)) { $flags += $s }
      else { $path = $s } }
    else { $trail += $s } }
  [pscustomobject]@{ flags = $flags; path = $path; trailing = $trail; bad = $bad } }
function Need-Auth {
  if (-not (SEq $env:VAULT_ADDR $global:EXPECTED_ADDR)) {
    Mock-Stderr @('Error making API request.', '', "URL: GET $([string]$env:VAULT_ADDR)", '* dial tcp: connection refused'); return 'addr' }
  if (-not (SEq $env:VAULT_TOKEN $global:FAKE_ROOT)) {
    Mock-Stderr @('Error making API request.', '', 'Code: 403. Errors:', '', '* permission denied'); return 'token' }
  '' }
function Kv-MetaObj { param([string]$path, [string]$mode = '')
  $e = $global:Kv[$path]
  $cur = [int]$e['current']; $dva = '0s'
  $vers = [ordered]@{}
  foreach ($k in @($e['versions'].Keys | Sort-Object { [int]$_ })) {
    $v = $e['versions'][$k]
    $vers[[string]$k] = [ordered]@{ created_time = $v['created_time']; deletion_time = $v['deletion_time']; destroyed = $v['destroyed'] } }
  if ((SEq $mode 'cv2') -and $vers.Count -gt 0) { $cur = $cur + 1; $vers[[string]$cur] = [ordered]@{ created_time = '2026-11-20T03:00:01Z'; deletion_time = ''; destroyed = $false } }
  $oldest = 0; if ($e['versions'].Count -gt 0) { $oldest = 1 }
  [ordered]@{ request_id = 'mock-req'; lease_id = ''; lease_duration = 0; renewable = $false
    data = [ordered]@{ cas_required = $false; created_time = $e['created']; current_version = $cur; custom_metadata = $null; delete_version_after = $dva
      max_versions = 0; oldest_version = $oldest; updated_time = $e['created']; versions = $vers }
    warnings = $null } }
function Mock-Status { param($rest)
  Add-Event 'vault:status'
  if (-not (Has-Flag $rest '-format=json')) { Add-Violation 'vault status 에 -format=json 없음'; $global:LASTEXITCODE = 1; return }
  $mode = [string]$global:F['status']
  if (-not (SEq $env:VAULT_ADDR $global:EXPECTED_ADDR) -or (SEq $mode 'down')) {
    Mock-Stderr @("Error checking seal status: Get `"$([string]$env:VAULT_ADDR)/v1/sys/seal-status`": dial tcp 127.0.0.1:18200: connectex: No connection could be made because the target machine actively refused it.")
    $global:LASTEXITCODE = 1; return }
  $o = [ordered]@{ type = 'ocikms'; initialized = $true; sealed = $false; t = 1; n = 1; progress = 0; nonce = ''; version = '2.0.4-MOCK'; build_date = '2026-01-01T00:00:00Z'
    migration = $false; cluster_name = 'vault-cluster-d3b29227'; cluster_id = 'MOCK-cluster-id'; recovery_seal = $true; storage_type = 'raft'; ha_enabled = $true }
  $rc = 0
  if (SEq $mode 'sealed') { $o['sealed'] = $true; $rc = 2 }
  if (SEq $mode 'ctrl') { $o['type'] = 'ocikms' + [char]27 + '[2J'; $o['version'] = '2.0.4' + [char]27 + ']52;c;QUJD' + [char]7 }
  # cluster_name 결함(T076 r1 — S-09): 다른 클러스터 · 키 없음 · 제어 문자
  if (SEq $mode 'otherCluster') { $o['cluster_name'] = 'vault-cluster-0ther999' }
  if (SEq $mode 'noCluster') { $o.Remove('cluster_name') }
  if (SEq $mode 'ctrlCluster') { $o['cluster_name'] = 'vault-cluster-' + [char]27 + ']52;c;QUJD' + [char]7 }
  $global:LASTEXITCODE = $rc
  Json-Lines $o }
function Mock-TokenLookup { param($rest)
  Add-Event 'vault:token-lookup'
  if (-not (Has-Flag $rest '-format=json')) { Add-Violation 'token lookup 에 -format=json 없음'; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  # 실물처럼 data.id 에 토큰 평문이 들어 있다 — 블록이 응답을 출력하면 노출 검사가 잡는다
  Json-Lines ([ordered]@{ request_id = 'mock-req'; data = [ordered]@{ accessor = 'MOCK-accessor'; id = [string]$env:VAULT_TOKEN; policies = @($global:TokenPolicies); ttl = 0 } }) }
function Mock-MetaGet { param($rest)
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv metadata get 인자 형식: $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:meta-get:$path"
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if (Take-Fault 'metaError' $path) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', "URL: GET $($global:EXPECTED_ADDR)/v1/kv/metadata/$r", 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  if ((SEq ([string]$global:F['postMeta'][$path]) 'err') -and @($global:PutCalls | Where-Object { SEq $_.path $path }).Count -gt 0) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/metadata/$r"); $global:LASTEXITCODE = 2; return }
  Json-Lines (Kv-MetaObj $path ([string]$global:F['postMeta'][$path])) }
function Mock-KvGet { param($rest)
  foreach ($x in @($rest)) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { Add-Violation 'kv get -field 사용'; $global:LASTEXITCODE = 1; return } }
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv get 인자 형식: $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:kv-get:$path"
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if (Take-Fault 'readFail' $path) { $global:LASTEXITCODE = 2; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/data/$r"); $global:LASTEXITCODE = 2; return }
  $e = $global:Kv[$path]
  $cur = [string]$e['current']
  $v = $e['versions'][$cur]
  if ($null -eq $v) { Mock-Stderr @("No value found at kv/data/$r"); $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'readGarbage' $path) {
    # 잘린 JSON — 안에 값(첫 키)이 들어 있다(해석 실패를 어떻게 다루는지 · $Error 에 값이 남는지 본다)
    $global:LASTEXITCODE = 0
    $k0 = [string]@($v['data'].Keys)[0]
    return @('{', '  "data": {', '    "data": {', ('      "' + $k0 + '": "' + [string]$v['data'][$k0] + '",'), '      "x": ') }
  $meta = [ordered]@{ created_time = $v['created_time']; custom_metadata = $null; deletion_time = $v['deletion_time']; destroyed = $v['destroyed']; version = [int]$cur }
  $data = $null
  if (-not $v['destroyed'] -and [string]::IsNullOrEmpty([string]$v['deletion_time'])) { $data = $v['data'] }
  Json-Lines ([ordered]@{ request_id = 'mock-req'; lease_id = ''; lease_duration = 0; renewable = $false; data = [ordered]@{ data = $data; metadata = $meta }; warnings = $null }) }
function One-Char { param([string]$s, [int]$i)
  if ($i -lt 0 -or $i -ge $s.Length) { return $s }
  $s.Substring(0, $i) + $(if (SEq $s.Substring($i, 1) 'A') { 'B' } else { 'A' }) + $s.Substring($i + 1) }
function Take-Tamper { param([string]$path)
  $t = $global:F['tamper']
  if (-not $t.ContainsKey($path)) { return '' }
  $m = [string]$t[$path]
  $t.Remove($path)
  $m }
# tamper(저장 때 한 번 값 변형): secret = client_secret 마지막 글자(꼴은 그대로 — 해시 대조로만 잡힌다) · dropKey = client_secret 키를 뺀다 · extraKey = 키 note 를 더한다
function Tamper-Data { param($data, [string]$mode)
  if (SEq $mode 'secret') { $s = [string]$data['client_secret']; $data['client_secret'] = One-Char $s ($s.Length - 1) }
  elseif (SEq $mode 'dropKey') { $data.Remove('client_secret') }
  elseif (SEq $mode 'extraKey') { $data['note'] = 'x' }
  else { Add-Violation "하네스: 알 수 없는 tamper 모드 $mode" } }
# 다른 기록자의 쓰기(putRace 결함): $global:RaceData[<경로>] 를 새 버전으로 커밋하고 그 버전 번호를 돌려준다
function Race-Write { param([string]$path)
  if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:NowIso; versions = @{} } }
  $rn = [int]$global:Kv[$path]['current'] + 1
  $global:Kv[$path]['versions'][[string]$rn] = @{ data = $global:RaceData[$path]; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $rn
  Add-Event "race:$path"
  $rn }
function Mock-KvPut { param($rest, $stdin)
  $p = Split-FlagsPath $rest
  $cas = $null
  foreach ($f in @($p.flags)) { if ($f.StartsWith('-cas=', [StringComparison]::Ordinal)) { $cas = [int]$f.Substring(5) } else { Add-Violation "kv put 플래그: $f" } }
  $trail = @($p.trailing)
  $useStdin = ($trail.Count -eq 1 -and (SEq $trail[0] '-'))
  if (@($trail | Where-Object { -not (SEq $_ '-') }).Count -gt 0) { Add-Violation 'kv put 이 argv 로 값을 받았다(k=v — 값이 argv 에 나온다)' }
  $body = (@($stdin) | ForEach-Object { [string]$_ }) -join "`n"
  [void]$global:PutCalls.Add([pscustomobject]@{ path = [string]$p.path; cas = $cas; stdin = $useStdin })
  if (-not [string]::IsNullOrEmpty($body)) { [void]$global:PutBodies.Add($body) }
  Add-Event "vault:put:$([string]$p.path)"
  if ($null -eq $p.path -or -not $useStdin -or $p.bad) { $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if ($global:F['putFail'].ContainsKey($path)) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', 'Code: 403. Errors:', '', '* permission denied')
    $global:LASTEXITCODE = [int]$global:F['putFail'][$path]; return }
  $obj = $null
  try { $obj = $body | ConvertFrom-Json -AsHashtable -DateKind String } catch { $global:LASTEXITCODE = 1; return }
  if ($obj -isnot [System.Collections.IDictionary]) { $global:LASTEXITCODE = 1; return }
  $data = [ordered]@{}
  foreach ($k in @($obj.Keys)) {
    if ($obj[$k] -isnot [string]) { Add-Violation "kv put 값이 문자열이 아니다: $k"; $global:LASTEXITCODE = 1; return }
    $data[[string]$k] = [string]$obj[$k] }
  $cur = 0
  if ($global:Kv.ContainsKey($path)) { $cur = [int]$global:Kv[$path]['current'] }
  if (Take-Fault 'putRace' $path) { $cur = Race-Write $path }
  if ($null -ne $cas -and $cas -ne $cur) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $tm = Take-Tamper $path
  if ($tm) { Tamper-Data $data $tm }
  if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:NowIso; versions = @{} } }
  $n = [int]$global:Kv[$path]['current'] + 1
  $global:Kv[$path]['versions'][[string]$n] = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $n
  if (Take-Fault 'putInterrupt' $path) { throw '모의 중단(put 도중 Ctrl+C 대용) — 서버는 이미 커밋했다' }
  # putLost(T054 리뷰 r3 O6): 서버는 커밋했는데 응답이 유실돼 CLI 자동 재시도가 자기 기록과 CAS 충돌 — 종료 2 · 진짜 CAS 충돌과 같은 문구(재판정으로만 가른다)
  if (Take-Fault 'putLost' $path) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $global:LASTEXITCODE = 0
  @('====== Secret Path ======', "kv/data/$r", '', '======= Metadata =======', "version            $n") }
# 모의 호출 시점의 환경 변수(T075 KB-4 · KB-5): vault 호출은 VAULT_TOKEN(그 호출에 필요하다)을 뺀다 · kubectl · tofu · curl 은 아무것도 빼지 않는다 · 이름 목록도 남긴다(tofu 시점 VAULT_* 0 단언)
function Env-Text { param([string[]]$skip = @()) ((@(Get-ChildItem Env: | Where-Object { $skip -notcontains $_.Name }) | ForEach-Object { [string]$_.Value }) -join "`n") }
function Snap-Env { param([string]$who)
  $skip = @(); if (SEq $who 'vault') { $skip = @('VAULT_TOKEN') }
  [void]$global:EnvAtCall.Add([pscustomobject]@{ who = $who; text = (Env-Text $skip); names = @(Get-ChildItem Env: | ForEach-Object { $_.Name }) }) }
function vault {
  $stdin = @($input)
  $a = @($args | ForEach-Object { [string]$_ })
  $line = $a -join ' '
  [void]$global:ArgvLog.Add($line)
  Snap-Env 'vault'
  $global:LASTEXITCODE = 0
  if (-not $global:Allow['vault']) { Add-Violation "vault 호출(이 블록은 vault CLI 를 쓰지 않는다): $line"; $global:LASTEXITCODE = 1; return }
  $isPut = (SEq (At $a 0) 'kv') -and (SEq (At $a 1) 'put')
  if ($stdin.Count -gt 0 -and -not $isPut) { Add-Violation "put 이 아닌 vault 호출에 stdin: $line" }
  if (SEq (At $a 0) 'version') { Add-Event 'vault:version'; return 'Vault v0.0.0-MOCK (harness)' }
  if (SEq (At $a 0) 'status') { return (Mock-Status @($a | Select-Object -Skip 1)) }
  if ((SEq (At $a 0) 'token') -and (SEq (At $a 1) 'lookup')) { return (Mock-TokenLookup @($a | Select-Object -Skip 2)) }
  if (SEq (At $a 0) 'kv') {
    if ((SEq (At $a 1) 'metadata') -and (SEq (At $a 2) 'get')) { return (Mock-MetaGet @($a | Select-Object -Skip 3)) }
    if (SEq (At $a 1) 'get') { return (Mock-KvGet @($a | Select-Object -Skip 2)) }
    if ($isPut) { return (Mock-KvPut @($a | Select-Object -Skip 2) $stdin) } }
  Add-Violation "허용 목록 밖 vault 호출: $line"
  $global:LASTEXITCODE = 1 }
function vault.exe { Add-Violation ('vault.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
# kubectl(O-9 · O-10 만): --kubeconfig <…\.kube\joshuatech-admin.yaml> create token agent-view -n kube-system [--audience vault] --duration=<기간> — 출력 = & $global:KubeFn <호출>(줄 배열) ·
#   결함 $global:KubeRc(≠ 0 이면 stderr $global:KubeErr + 그 종료 코드 · 출력 0)
function kubectl {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('kubectl ' + ($a -join ' '))
  Snap-Env 'kubectl'
  if (-not $global:Allow['kubectl']) { Add-Violation ('kubectl 호출(이 블록은 클러스터에 닿지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  if ($stdin.Count -gt 0) { Add-Violation 'kubectl 에 stdin(이 블록들은 kubectl 에 아무것도 넘기지 않는다)' }
  $ok = ($a.Count -ge 8 -and (SEq $a[0] '--kubeconfig') -and ([string]$a[1]).EndsWith('\.kube\joshuatech-admin.yaml', [StringComparison]::Ordinal) -and (SEq $a[2] 'create') -and (SEq $a[3] 'token') -and (SEq $a[4] 'agent-view') -and (SEq $a[5] '-n') -and (SEq $a[6] 'kube-system'))
  $aud = ''; $dur = ''
  if ($ok) {
    $rest = @($a | Select-Object -Skip 7)
    if ($rest.Count -eq 3 -and (SEq $rest[0] '--audience') -and (SEq $rest[1] 'vault') -and $rest[2].StartsWith('--duration=', [StringComparison]::Ordinal)) { $aud = 'vault'; $dur = $rest[2].Substring(11) }
    elseif ($rest.Count -eq 1 -and $rest[0].StartsWith('--duration=', [StringComparison]::Ordinal)) { $dur = $rest[0].Substring(11) }
    else { $ok = $false } }
  if (-not $ok) { Add-Violation ('kubectl 인자 꼴(--kubeconfig <관리자> create token agent-view -n kube-system [--audience vault] --duration=…): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  $call = [pscustomobject]@{ aud = $aud; dur = $dur; kc = [string]$a[1] }
  [void]$global:KubeCalls.Add($call)
  Add-Event "kubectl:token:$(if ($aud) { $aud } else { 'none' }):$dur"
  if ($global:KubeRc -ne 0) { Mock-Stderr @($global:KubeErr); $global:LASTEXITCODE = $global:KubeRc; return }
  $global:LASTEXITCODE = 0
  $out = @(& $global:KubeFn $call)
  foreach ($o in $out) { if (([string]$o).Split('.').Count -eq 3) { [void]$global:KubeIssued.Add([string]$o) } }
  $out }
function kubectl.exe { Add-Violation ('kubectl.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
# tofu(W-7 만): version · "-chdir=<저장소>\infra\cloudflare" output -json service_tokens — 값 = $global:TofuOut(JSON 문자열) · 결함 tofuFail(exit)
function tofu {
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('tofu ' + ($a -join ' '))
  Snap-Env 'tofu'
  if (-not $global:Allow['tofu']) { Add-Violation ('tofu 호출(이 블록은 tofu 를 쓰지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  $global:LASTEXITCODE = 0
  if ($a.Count -eq 1 -and (SEq $a[0] 'version')) { Add-Event 'tofu:version'; return 'OpenTofu v0.0.0-MOCK' }
  if ($a.Count -eq 4 -and $a[0].StartsWith('-chdir=', [StringComparison]::Ordinal) -and (SEq $a[1] 'output') -and (SEq $a[2] '-json') -and (SEq $a[3] 'service_tokens')) {
    [void]$global:TofuCalls.Add([pscustomobject]@{ chdir = $a[0].Substring(7); name = $a[3] })
    Add-Event "tofu:output:$($a[3])"
    if ($global:F['tofuFail'] -ne 0) { Mock-Stderr @('Error: No outputs found', '', 'The state file either has no outputs defined, or all the defined outputs are empty.'); $global:LASTEXITCODE = [int]$global:F['tofuFail']; return }
    return @(([string]$global:TofuOut) -split "`n") }
  Add-Violation ('허용 목록 밖 tofu 호출: ' + ($a -join ' ')); $global:LASTEXITCODE = 1 }
function tofu.exe { Add-Violation ('tofu.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function curl { Add-Violation 'curl 호출(curl.exe 를 써야 한다 — PowerShell 별칭 · 다른 판 회피)'; $global:LASTEXITCODE = 1 }
# Vault HTTP API 모형(O-10): seal-status($global:SealMode — ok · sealed · down · garbage / $global:SealCluster) · kubernetes/login($global:LoginMode) · token/revoke-self($global:RevokeMode)
#   돌려주는 것 = @{ rc = curl 종료 코드; code = HTTP 상태(rc ≠ 0 이면 000); body = 본문; err = stderr 줄 }
function Vault-Http { param($req)
  $ok200 = { param($b) @{ rc = 0; code = '200'; body = $b; err = '' } }
  if ((SEq $req.method 'GET') -and (SEq $req.path '/v1/sys/seal-status')) {
    Add-Event 'vault-http:seal-status'
    if (SEq $global:SealMode 'down') { return @{ rc = 7; code = '000'; body = ''; err = "curl: (7) Failed to connect to 127.0.0.1 port 18200 after 0 ms: Couldn't connect to server" } }
    if (SEq $global:SealMode 'garbage') { return (& $ok200 'not-json-at-all') }
    $o = [ordered]@{ type = 'ocikms'; initialized = $true; sealed = (SEq $global:SealMode 'sealed'); t = 1; n = 1; progress = 0; nonce = ''; version = '2.0.4-MOCK'; build_date = '2026-01-01T00:00:00Z'
      migration = $false; cluster_name = [string]$global:SealCluster; cluster_id = 'MOCK-cluster-id'; recovery_seal = $true; storage_type = 'raft' }
    return (& $ok200 (ConvertTo-Json -InputObject $o -Compress)) }
  if ((SEq $req.method 'POST') -and (SEq $req.path '/v1/auth/kubernetes/login')) {
    $b = $null; try { $b = $req.body | ConvertFrom-Json -AsHashtable } catch { $b = $null }
    $role = ''; $jwt = ''; if ($b -is [System.Collections.IDictionary]) { $role = [string]$b['role']; $jwt = [string]$b['jwt'] }
    [void]$global:LoginCalls.Add([pscustomobject]@{ role = $role; jwt = $jwt; keys = $(if ($b -is [System.Collections.IDictionary]) { (@($b.Keys) | Sort-Object) -join ',' } else { '' }); headers = $req.headers.Count })
    $m = [string]$global:LoginMode
    if (SEq $m 'reject403') { return @{ rc = 0; code = '403'; body = '{"errors":["permission denied"]}'; err = '' } }
    if (SEq $m 'reject400') { return @{ rc = 0; code = '400'; body = '{"errors":["invalid audience (aud) claim: audience claim does not match any expected audience"]}'; err = '' } }
    # ctrl: errors 에 JSON 이스케이프 제어열(ESC ]52 · BEL — OSC 52) — 역슬래시는 실행 중에 만든다(편집 도구가 역슬래시-u 를 글자로 바꾼다)
    if (SEq $m 'ctrl') { $bs = [string][char]92; return @{ rc = 0; code = '403'; body = ('{"errors":["permission denied' + $bs + 'u001b]52;c;QUJD' + $bs + 'u0007"]}'); err = '' } }
    if (SEq $m 'long') { return @{ rc = 0; code = '400'; body = ('{"errors":["' + ('x' * 300) + '"]}'); err = '' } }
    if (SEq $m 'nonjson') { return @{ rc = 0; code = '403'; body = 'Forbidden'; err = '' } }
    if (SEq $m 'e500') { return @{ rc = 0; code = '500'; body = '{"errors":["internal error"]}'; err = '' } }
    if (SEq $m 'noauth200') { return (& $ok200 '{"request_id":"mock","auth":null,"warnings":null}') }
    if (SEq $m 'authNoToken') { return (& $ok200 '{"request_id":"mock","auth":{"policies":["default"],"lease_duration":3600}}') }
    if (SEq $m 'authNoToken403') { return @{ rc = 0; code = '403'; body = '{"errors":["permission denied"],"auth":{"policies":["default"]}}'; err = '' } }
    if (SEq $m 'lost') { return @{ rc = 28; code = '000'; body = ''; err = 'curl: (28) Operation timed out after 20001 milliseconds with 0 bytes received' } }
    $auth = [ordered]@{ client_token = $global:FAKE_VTOKEN; accessor = 'MOCK-accessor-t076'; policies = @('default', 'e2e-reader'); token_policies = @('default', 'e2e-reader')
      metadata = [ordered]@{ role = 'e2e-reader'; service_account_name = 'agent-view'; service_account_namespace = 'kube-system' }; lease_duration = 3600; renewable = $true; token_type = 'service'; orphan = $true }
    $body = ConvertTo-Json -InputObject ([ordered]@{ request_id = 'mock'; lease_id = ''; renewable = $false; lease_duration = 0; data = $null; auth = $auth }) -Compress -Depth 5
    if (SEq $m 'pass') { return (& $ok200 $body) }
    if (SEq $m 'pass403') { return @{ rc = 0; code = '403'; body = $body; err = '' } }
    Add-Violation "하네스: 알 수 없는 LoginMode $m"
    return @{ rc = 0; code = '500'; body = ''; err = '' } }
  if ((SEq $req.method 'POST') -and (SEq $req.path '/v1/auth/token/revoke-self')) {
    $tok = [string]$req.headers['X-Vault-Token']
    [void]$global:RevokeCalls.Add([pscustomobject]@{ tokenOk = (SEq $tok $global:FAKE_VTOKEN); headers = $req.headers.Count; body = [string]$req.body })
    if (SEq $global:RevokeMode 'deny') { return @{ rc = 0; code = '403'; body = '{"errors":["permission denied"]}'; err = '' } }
    if (SEq $global:RevokeMode 'down') { return @{ rc = 7; code = '000'; body = ''; err = "curl: (7) Failed to connect to 127.0.0.1 port 18200 after 0 ms: Couldn't connect to server" } }
    return @{ rc = 0; code = '204'; body = ''; err = '' } }
  Add-Violation "Vault HTTP 허용 목록 밖: $($req.method) $($req.path)"
  @{ rc = 0; code = '404'; body = '{"errors":[]}'; err = '' } }
# curl.exe(O-10 만): 첫 인자 -q · -q --version · GET(-w) · POST --data-binary @-(본문 stdin) · POST -X POST -H @-(헤더 stdin). 금지 플래그 · -w 형식 다름 · 주소가 Vault(127.0.0.1:18200) 아님 = 위반
function curl.exe {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('curl.exe ' + ($a -join ' '))
  Snap-Env 'curl'
  if (-not $global:Allow['curl']) { Add-Violation ('curl.exe 호출(이 블록은 HTTP 를 쓰지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  if (-not (SEq (At $a 0) '-q')) { Add-Violation ('curl.exe 첫 인자가 -q 가 아니다(.curlrc 를 읽는다): ' + ($a -join ' ')) }
  $global:LASTEXITCODE = 0
  if ($a.Count -eq 2 -and (SEq $a[1] '--version')) { Add-Event 'curl:version'; return @([string]$global:CurlVersion, 'Protocols: http https') }
  $forbid = @('-v', '--verbose', '-i', '--include', '-I', '--head', '-D', '--dump-header', '-c', '--cookie-jar', '-b', '--cookie', '-L', '--location', '--location-trusted', '-x', '--proxy', '-K', '--config', '-n', '--netrc', '--netrc-optional', '--netrc-file', '-o', '--output', '-O', '-k', '--insecure')
  $bad = @($a | Where-Object { ($forbid -ccontains $_) -or $_.StartsWith('--trace', [StringComparison]::Ordinal) })
  if ($bad.Count -gt 0) { Add-Violation "curl.exe 금지 플래그: $($bad -join ' ')" }
  $iw = [array]::IndexOf([string[]]$a, '-w'); $fmt = ''; if ($iw -ge 0 -and $iw + 1 -lt $a.Count) { $fmt = $a[$iw + 1] }
  if (-not (SEq $fmt '\nT076-W code=%{http_code}\n')) { Add-Violation "curl -w 형식이 '\nT076-W code=%{http_code}\n' 이 아니다: $fmt" }
  $url = [string]$a[$a.Count - 1]
  if (-not $url.StartsWith('http://127.0.0.1:18200/v1/', [StringComparison]::Ordinal)) { Add-Violation "curl 주소가 창 C 의 Vault(http://127.0.0.1:18200/v1/…)가 아니다: $url" }
  $isData = ($a -ccontains '--data-binary'); $isH = ($a -ccontains '-H'); $isX = ($a -ccontains '-X')
  if ($isData) { $j = [array]::IndexOf([string[]]$a, '--data-binary'); if (-not (SEq (At $a ($j + 1)) '@-')) { Add-Violation '--data-binary 가 @-(stdin) 가 아니다 — 본문이 argv 에 나온다' } }
  if ($isH) { $j = [array]::IndexOf([string[]]$a, '-H'); if (-not (SEq (At $a ($j + 1)) '@-')) { Add-Violation '-H 가 @-(stdin) 가 아니다 — 헤더 값이 argv 에 나온다' } }
  if ($isX) { $j = [array]::IndexOf([string[]]$a, '-X'); if (-not (SEq (At $a ($j + 1)) 'POST')) { Add-Violation '-X 가 POST 가 아니다' } }
  if ($isData -and $isH) { Add-Violation 'curl 한 호출에 본문 stdin 과 헤더 stdin 을 함께 썼다' }
  if (-not $isData -and -not $isH -and $stdin.Count -gt 0) { Add-Violation 'stdin 을 쓰지 않는 curl 호출에 stdin' }
  $method = 'GET'; if ($isData -or $isX) { $method = 'POST' }
  $lines = @($stdin | ForEach-Object { [string]$_ })
  $hdr = @{}
  if ($isH) { foreach ($l in $lines) { $k = $l.IndexOf(':'); if ($k -gt 0) { $hdr[$l.Substring(0, $k).Trim()] = $l.Substring($k + 1).Trim() } } }
  $req = [pscustomobject]@{ method = $method; url = $url; path = ([regex]::Match($url, '\Ahttps?://[^/]+(/[^?]*)')).Groups[1].Value; body = $(if ($isData) { $lines -join "`n" } else { '' }); headers = $hdr; stdinLines = $stdin.Count }
  [void]$global:CurlCalls.Add($req)
  Add-Event "curl:$($method.ToLowerInvariant()):$($req.path)"
  $resp = Vault-Http $req
  $w = $fmt.Replace('\n', "`n").Replace('%{http_code}', [string]$resp['code'])
  if ([int]$resp['rc'] -ne 0) { Mock-Stderr @([string]$resp['err']); $global:LASTEXITCODE = [int]$resp['rc'] }
  @(([string]$resp['body'] + $w) -split "`n") }
function oci { Add-Violation 'oci 호출'; $global:LASTEXITCODE = 1 }
function gh { Add-Violation 'gh 호출'; $global:LASTEXITCODE = 1 }
function Read-Host { param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
  $p = [string]$Prompt
  [void]$global:Prompts.Add($p)
  $v = ''
  if ($global:Inputs.Count -gt 0) { $v = [string]$global:Inputs.Dequeue() }
  [void]$global:ReadLog.Add([pscustomobject]@{ prompt = $p; secure = [bool]$AsSecureString; masked = [bool]$MaskInput; value = $v; items = [int]$global:ItemCount })
  if ($AsSecureString) {
    Add-Event 'read:secure'
    $ss = [securestring]::new()
    foreach ($c in $v.ToCharArray()) { $ss.AppendChar($c) }
    return $ss }
  Add-Event 'read:plain'
  $v }
function Set-Clipboard { [CmdletBinding(SupportsShouldProcess = $true)] param([Parameter(ValueFromPipeline = $true, Position = 0)]$Value)
  if (-not $PSCmdlet.ShouldProcess('clipboard', 'Set-Clipboard')) { Add-Event 'clip:whatif'; return }
  [void]$global:ClipValues.Add([string]$Value); Add-Event 'clip:set'
  if ($global:F['clipFail']) { Add-Event 'clip:fail'; throw '모의 클립보드 열기 실패(다른 프로세스가 클립보드를 잡고 있다)' } }
function Set-PSDebug { param([switch]$Off, [int]$Trace = -1, [switch]$Step, [switch]$Strict)
  if ($Off -and $Trace -lt 0 -and -not $Step -and -not $Strict) { Add-Event 'psdebug:off' } else { Add-Violation 'Set-PSDebug 를 -Off 가 아닌 인자로 호출' } }
function Get-Clipboard { Add-Violation 'Get-Clipboard 호출(블록은 클립보드를 읽지 않는다)'; ' ' }
$global:PolicyPaths = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging')
function Get-ItemProperty { param([Parameter(Position = 0)]$Path, [Parameter(Position = 1)]$Name)
  foreach ($pp in $global:PolicyPaths) {
    if ([string]::Equals([string]$Path, $pp, [StringComparison]::OrdinalIgnoreCase)) {
      Add-Event "reg:policy:$pp"
      $h = $global:Policy[$pp]
      if ($null -eq $h) { return $null }
      return [pscustomobject]$h } }
  Add-Event 'reg:get'
  if (-not ([string]$Path).EndsWith('Microsoft\Clipboard', [StringComparison]::OrdinalIgnoreCase)) { Add-Violation "Get-ItemProperty 다른 경로: $Path"; return $null }
  if (SEq $global:ClipHistoryMode 'nokey') { return $null }
  [pscustomobject]@{ EnableClipboardHistory = $global:ClipHistory } }
# Test-Path: ~/.vault-token · 설정 파일 두 곳 · 관리자 kubeconfig · infra\cloudflare\outputs.tf 는 실물 파일을 건드리지 않고 모의 값으로 답한다(하네스는 관리자 kubeconfig 를 읽지도 확인하지도 않는다)
function Cfg-Scope { param([string]$q) if ($q.StartsWith($PSHOME, [StringComparison]::OrdinalIgnoreCase)) { 'system' } else { 'user' } }
function Test-Path { param([Parameter(Position = 0)]$Path, [string]$LiteralPath = '')
  $q = [string]$Path; if ($LiteralPath.Length -gt 0) { $q = $LiteralPath }
  if ($q.EndsWith('.vault-token', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:vault-token'; return [bool]$global:VaultTokenFile }
  if ($q.EndsWith('powershell.config.json', [StringComparison]::OrdinalIgnoreCase)) { $sc = Cfg-Scope $q; Add-Event "cfg:test:$sc"; [void]$global:FsLog.Add($q); return ($null -ne $global:CfgText[$sc]) }
  if ($q.EndsWith('joshuatech-admin.yaml', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:admin-kubeconfig'; [void]$global:FsLog.Add($q); return [bool]$global:AdminKc }
  if ($q.EndsWith('\infra\cloudflare\outputs.tf', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:infra-outputs'; [void]$global:FsLog.Add($q); return [bool]$global:InfraOk }
  Microsoft.PowerShell.Management\Test-Path -LiteralPath $q }
function Get-Content { param([Parameter(Position = 0)]$Path, [string]$LiteralPath = '', [switch]$Raw)
  $q = [string]$Path; if ($LiteralPath.Length -gt 0) { $q = $LiteralPath }
  if ($q.EndsWith('powershell.config.json', [StringComparison]::OrdinalIgnoreCase)) { $sc = Cfg-Scope $q; Add-Event "cfg:read:$sc"; if (-not $Raw) { Add-Violation 'Get-Content 에 -Raw 없음(설정 파일)' }; return $global:CfgText[$sc] }
  Add-Violation "Get-Content 다른 경로(블록은 설정 파일 둘만 읽는다): $q"; $null }
function Import-Module { param([Parameter(Position = 0)][string[]]$Name)
  if (-not (SEq (@($Name) -join ',') 'Microsoft.PowerShell.Utility,Microsoft.PowerShell.Security,Microsoft.PowerShell.Management')) { Add-Violation "Import-Module 인자: $(@($Name) -join ',')" }
  Add-Event 'mod:import' }
function Get-Module { param([Parameter(Position = 0)][string[]]$Name)
  Add-Event 'mod:get'
  foreach ($n in @($Name)) { if ($global:ModLog.ContainsKey($n) -and -not ($global:ModMissing -ccontains $n)) { [pscustomobject]@{ Name = $n; LogPipelineExecutionDetails = [bool]$global:ModLog[$n] } } } }
function Get-Command { [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name, [string[]]$CommandType, [switch]$All)
  $n0 = [string](@($Name)[0])
  if (@($Name).Count -eq 1 -and (SEq $n0 'ForEach-Object')) {
    Add-Event 'mod:core'
    if (-not (SEq (@($CommandType) -join ',') 'Cmdlet')) { Add-Violation 'Get-Command ForEach-Object 에 -CommandType Cmdlet 없음' }
    if ($global:CoreMissing) { return }
    $snap = $null
    if (-not $global:CoreNoSnap) { $snap = [pscustomobject]@{ Name = 'Microsoft.PowerShell.Core'; LogPipelineExecutionDetails = [bool]$global:CoreLog } }
    return [pscustomobject]@{ Name = 'ForEach-Object'; CommandType = 'Cmdlet'; PSSnapIn = $snap; Source = 'Microsoft.PowerShell.Core' } }
  # 외부 명령 첫 해석(T076 r1 — S-10): 블록이 부르는 이름(kubectl · curl.exe · tofu · vault)의 질의는 형식 필터 없이 와야 하고(-CommandType · -All = 위반) 실물처럼 첫 해석 하나를 돌려준다
  #   (실측 2026-11-20 pwsh 7.6.10: 같은 이름 함수 · 별칭이 있으면 그것 하나) — 기본 = Application 꼴(이름.exe · 경로 C:\jt-mock-bin\ — FakeSrc 가 경로만 바꾼다) ·
  #   $global:CmdShape[이름] = Function · Alias · ExternalScript(가림) · missing(찾지 못함)
  if (@($Name).Count -eq 1 -and (@('kubectl', 'curl.exe', 'tofu', 'vault') -ccontains $n0)) {
    Add-Event "gc:$n0"
    if ($PSBoundParameters.ContainsKey('CommandType') -or $All) { Add-Violation "Get-Command $n0 에 -CommandType · -All(첫 해석 판정은 형식 필터 없는 질의여야 한다)" }
    $shape = 'Application'; if ($global:CmdShape.ContainsKey($n0)) { $shape = [string]$global:CmdShape[$n0] }
    if (SEq $shape 'missing') { return }
    $exe = $n0; if (-not $exe.EndsWith('.exe', [StringComparison]::Ordinal)) { $exe += '.exe' }
    if (-not (SEq $shape 'Application')) { return [pscustomobject]@{ Name = $n0; CommandType = $shape; Source = '' } }
    $src = 'C:\jt-mock-bin\' + $exe; if ($global:FakeSrc.ContainsKey($n0)) { $src = [string]$global:FakeSrc[$n0] }
    return [pscustomobject]@{ Name = $exe; CommandType = 'Application'; Source = $src } }
  if (@($Name).Count -eq 1 -and $null -ne $global:FakeSrc -and $global:FakeSrc.ContainsKey($n0)) { return [pscustomobject]@{ Name = $n0; CommandType = 'Application'; Source = [string]$global:FakeSrc[$n0] } }
  Microsoft.PowerShell.Core\Get-Command @PSBoundParameters }

# ---------------------------------------------------------------- 가드 확인 · 모의 상태
function Assert-Guard {
  foreach ($n in 'vault', 'kubectl', 'tofu', 'curl', 'vault.exe', 'kubectl.exe', 'tofu.exe', 'curl.exe', 'Set-PSDebug', 'Read-Host', 'Test-Path', 'Get-ItemProperty', 'Set-Clipboard', 'Get-Content', 'Import-Module', 'Get-Module', 'Get-Command') {
    $c = Microsoft.PowerShell.Core\Get-Command $n -ErrorAction SilentlyContinue
    if ($null -eq $c -or $c.CommandType -ne 'Function') { throw "가드 실패: $n 이 모의 함수로 풀리지 않는다 — 블록을 실행하지 않는다" } }
  foreach ($a in @(Microsoft.PowerShell.Core\Get-Command vault, kubectl, tofu, vault.exe, kubectl.exe, tofu.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    if (-not $a.Source.StartsWith($TrapDir, [StringComparison]::OrdinalIgnoreCase)) { throw "가드 실패: 실물 실행 파일이 PATH 에 남아 있다($($a.Source)) — 블록을 실행하지 않는다" } }
  if (-not (SEq $env:KUBECONFIG $FakeKubeconfig) -or (Microsoft.PowerShell.Management\Test-Path -LiteralPath $FakeKubeconfig)) { throw '가드 실패: KUBECONFIG 가 하네스의 없는 경로가 아니다 — 블록을 실행하지 않는다' } }
function Trap-Markers { @(Get-ChildItem -LiteralPath $TrapDir -Filter 'CALLED-*' -ErrorAction SilentlyContinue).Count }
function Reset-Mocks {
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $global:Kv = @{}
  $global:F = @{ status = 'ok'; metaError = @{}; readFail = @{}; readGarbage = @{}; tamper = @{}; putFail = @{}; postMeta = @{}; putInterrupt = @{}; putLost = @{}; putRace = @{}; clipFail = $false; tofuFail = 0 }
  $global:RaceData = @{}
  $global:ModLog = @{ 'Microsoft.PowerShell.Utility' = $false; 'Microsoft.PowerShell.Security' = $false; 'Microsoft.PowerShell.Management' = $false }
  $global:ModMissing = @()
  $global:CoreLog = $false; $global:CoreNoSnap = $false; $global:CoreMissing = $false
  $global:FakeSrc = @{}
  $global:CmdShape = @{}
  $global:CfgText = @{ system = '{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned","WindowsPowerShellCompatibilityModuleDenyList":["PSScheduledJob"]}'; user = $null }
  $global:ItemCount = 0
  $global:Policy = @{}
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets', 'ExtraFulls', 'XArgv', 'KubeCalls', 'KubeIssued', 'CurlCalls', 'TofuCalls', 'FsLog', 'EnvAtCall', 'LoginCalls', 'RevokeCalls', 'Jwts') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:Allow = @{ vault = $false; kubectl = $false; tofu = $false; curl = $false }
  $global:TofuOut = ''
  $global:CurlVersion = 'curl 8.22.0 (Windows) libcurl/8.22.0 Schannel'
  $global:AdminKc = $true
  $global:InfraOk = $true
  $global:TokenPolicies = @('default', 'root')
  $global:ClipHistory = 0
  $global:ClipHistoryMode = 'value'
  $global:VaultTokenFile = $false
  $global:NowIso = '2026-11-20T03:00:00Z'
  $global:KubeRc = 0
  $global:KubeErr = 'error: failed to create token: serviceaccounts "agent-view" is forbidden'
  $global:KubeFn = { param($call) Jwt-ForCall $call }
  $global:SealMode = 'ok'
  $global:SealCluster = 'vault-cluster-d3b29227'
  $global:LoginMode = 'reject403'
  $global:RevokeMode = 'ok'
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }
# 모의 JWT(K8s TokenRequest 꼴): header.payload.signature — 클레임 aud(배열 · 문자열 · 없음) · exp · iat · iss · kubernetes.io · nbf · sub. 서명 = SHA-512 두 번(171자 base64url — 바늘)
function Sig-For { param([string]$tag) $b1 = [System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes('MOCK-sig-' + $tag)); $b2 = [System.Security.Cryptography.SHA512]::HashData($b1); [Convert]::ToBase64String([byte[]]($b1 + $b2)).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function Make-Jwt { param($Aud, [string]$Sub = $AGENT_SUB, [long]$Life = 3600, [long]$Skew = 0, [string]$Tag = 'jwt', [switch]$NoAud, $ExpOverride = $null)
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() + $Skew
  $c = [ordered]@{}
  if (-not $NoAud) { $c['aud'] = $Aud }
  $c['exp'] = $(if ($null -ne $ExpOverride) { $ExpOverride } else { $now + $Life }); $c['iat'] = $now; $c['iss'] = 'https://kubernetes.default.svc.cluster.local'
  $c['kubernetes.io'] = [ordered]@{ namespace = 'kube-system'; serviceaccount = [ordered]@{ name = 'agent-view'; uid = 'MOCK-uid-agent-view' } }
  $c['nbf'] = $now; $c['sub'] = $Sub
  $jwt = (B64U '{"alg":"RS256","kid":"MOCK-kid"}') + '.' + (B64U (ConvertTo-Json -InputObject $c -Compress -Depth 6)) + '.' + (Sig-For "$Tag-$now-$([guid]::NewGuid().ToString('N'))")
  [void]$global:Jwts.Add($jwt)
  $jwt }
# 호출에 맞는 기본 토큰: --audience vault → aud ["vault"] · 없음 → API 서버 기본 audience 둘 · 기간 1h = 3600 s · 10m = 600 s
function Jwt-ForCall { param($call)
  $aud = $DEF_AUD; if (SEq $call.aud 'vault') { $aud = [string[]]@('vault') }
  $life = 0; if (SEq $call.dur '1h') { $life = 3600 } elseif (SEq $call.dur '10m') { $life = 600 }
  Make-Jwt -Aud $aud -Life $life -Tag 'issued' }
function Jwt-Claims { param([string]$jwt) $s = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/'); while ($s.Length % 4) { $s += '=' }; [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) | ConvertFrom-Json }
# 모의 JWT payload 원문 JSON(사례 전제 확인 — aud 직렬화 꼴이 그 사례가 말하는 꼴인지)
function Jwt-PayloadText { param([string]$jwt) $s = $jwt.Split('.')[1].Replace('-', '+').Replace('_', '/'); while ($s.Length % 4) { $s += '=' }; [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($s)) }
# O-8 과 같은 꼴로 읽는다(독립 구현): ReadAllText(ASCII).Trim() | ConvertTo-SecureString → NetworkCredential.Password
function Read-JwtFile { param([string]$path) $ss = [IO.File]::ReadAllText($path, [Text.Encoding]::ASCII).Trim() | ConvertTo-SecureString; try { [System.Net.NetworkCredential]::new('', $ss).Password } finally { $ss.Dispose() } }
function Write-JwtFile { param([string]$jwt) $d = Join-Path $global:CaseLad 'jt-e2e'; [void](New-Item -ItemType Directory -Path $d -Force); [IO.File]::WriteAllText((Join-Path $global:CaseLad $JWT_REL), (ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $jwt -AsPlainText -Force)), [Text.Encoding]::ASCII) }
function Lad-File { Join-Path $global:CaseLad $JWT_REL }
function Seed-Path { param([string]$path, $data, [int]$current = 1, [string]$deletion = '', [bool]$destroyed = $false)
  $vers = @{}
  if ($current -gt 0) { $vers[[string]$current] = @{ data = $data; deletion_time = $deletion; destroyed = $destroyed; created_time = '2026-11-19T00:00:00Z' } }
  $global:Kv[$path] = @{ current = $current; created = '2026-11-19T00:00:00Z'; versions = $vers } }
function KvCur { param([string]$path) if ($global:Kv.ContainsKey($path)) { [int]$global:Kv[$path]['current'] } else { -1 } }
function KvData { param([string]$path)
  if (-not $global:Kv.ContainsKey($path)) { return $null }
  $v = $global:Kv[$path]['versions'][[string]$global:Kv[$path]['current']]
  if ($null -eq $v) { return $null }
  $v['data'] }
function Seed-Tofu { param($tok = $TOKV)
  $global:TofuOut = (ConvertTo-Json -InputObject $tok -Depth 5 -Compress)
  foreach ($k in @($TOKV.Keys)) { [void]$global:ExtraSecrets.Add([string]$TOKV[$k]['client_secret']); [void]$global:ExtraFulls.Add([string]$TOKV[$k]['client_id']) } }
# tester-m2m 한 자리만 바꾼 tofu 출력(나머지 토큰 셋은 그대로)
function Tok-With { param([string]$cid = $TM_ID, [string]$csec = $TM_SEC, [switch]$Drop)
  $t = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $t[$k] = [ordered]@{ client_id = $TOKV[$k]['client_id']; client_secret = $TOKV[$k]['client_secret']; expires_at = $TOKV[$k]['expires_at'] } }
  if ($Drop) { $t.Remove('tester-m2m') } else { $t['tester-m2m'] = [ordered]@{ client_id = $cid; client_secret = $csec; expires_at = '2027-09-03T00:00:00Z' } }
  $t }
Reset-Mocks

# ---------------------------------------------------------------- 노출 검사(바늘: 비밀 전체 · base64 · 8자 조각 · SHA-256 hex 대 · 소문자 전체와 앞 16자 / 전체만: client_id · JWT · JWT payload 조각)
function Add-Field { param($sec, $full, $k, $v)
  if ($null -eq $v) { return }
  $s = [string]$v
  if ($s.Length -lt 8) { return }
  if (SEq $k 'client_secret') { $sec.Add($s) } elseif (SEq $k 'client_id') { $full.Add($s) } elseif (@('note') -ccontains [string]$k) { } else { $sec.Add($s) } }
function Build-Needles {
  $sec = [System.Collections.Generic.List[string]]::new(); $full = [System.Collections.Generic.List[string]]::new()
  foreach ($t in @($global:FAKE_ROOT, $global:FAKE_WRONG, $global:FAKE_VTOKEN)) { $sec.Add($t) }
  foreach ($x in $global:ExtraSecrets) { $sec.Add([string]$x) }
  foreach ($x in $global:ExtraFulls) { $full.Add([string]$x) }
  foreach ($j in $global:Jwts) { $full.Add([string]$j); $parts = ([string]$j).Split('.'); if ($parts.Count -eq 3) { $full.Add($parts[1]); $sec.Add($parts[2]) } }
  foreach ($path in @($global:Kv.Keys)) { foreach ($ver in @($global:Kv[$path]['versions'].Values)) { $d = $ver['data']; if ($null -eq $d) { continue }; foreach ($k in @($d.Keys)) { Add-Field $sec $full $k $d[$k] } } }
  foreach ($b in $global:PutBodies) { try { $o = $b | ConvertFrom-Json -AsHashtable; foreach ($k in @($o.Keys)) { Add-Field $sec $full $k $o[$k] } } catch { } }
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($s in $sec) {
    if ($s.Length -lt 8) { continue }
    [void]$set.Add($s)
    [void]$set.Add([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)))
    for ($i = 0; $i -le $s.Length - 8; $i++) { [void]$set.Add($s.Substring($i, 8)) }
    $hx = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)))
    foreach ($h in @($hx, $hx.ToLowerInvariant())) { [void]$set.Add($h); [void]$set.Add($h.Substring(0, 16)) } }
  foreach ($s in $full) { if ($s.Length -ge 8) { [void]$set.Add($s) } }
  , @($set) }
function First-Needle { param([string]$text, $needles) foreach ($n in @($needles)) { if ($text.Contains($n)) { return $n } }; $null }
function Error-Text {
  $sb = [System.Text.StringBuilder]::new()
  foreach ($e in @($global:Error)) {
    [void]$sb.AppendLine([string]$e)
    if ($e -is [System.Management.Automation.ErrorRecord]) {
      [void]$sb.AppendLine($e.Exception.ToString()); [void]$sb.AppendLine([string]$e.TargetObject)
      if ($null -ne $e.ErrorDetails) { [void]$sb.AppendLine([string]$e.ErrorDetails) } }
    elseif ($e -is [Exception]) { [void]$sb.AppendLine($e.ToString()) } }
  $sb.ToString() }
$HarnessGlobals = @('Kv', 'F', 'RaceData', 'ModLog', 'ModMissing', 'CoreLog', 'CoreNoSnap', 'CoreMissing', 'FakeSrc', 'CmdShape', 'CfgText', 'ItemCount', 'Policy', 'PolicyPaths', 'Inputs', 'Prompts', 'ReadLog', 'ArgvLog',
  'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets', 'ExtraFulls', 'XArgv', 'KubeCalls', 'KubeIssued', 'CurlCalls', 'TofuCalls', 'FsLog', 'EnvAtCall', 'LoginCalls', 'RevokeCalls', 'Jwts',
  'Allow', 'TofuOut', 'CurlVersion', 'AdminKc', 'InfraOk', 'TokenPolicies', 'ClipHistory', 'ClipHistoryMode', 'VaultTokenFile', 'NowIso', 'KubeRc', 'KubeErr', 'KubeFn', 'SealMode', 'SealCluster', 'LoginMode', 'RevokeMode',
  'CaseChecks', 'LastText', 'LastItems', 'GvBefore', 'CaseLad', 'CaseFiles', 'EXPECTED_ADDR', 'FAKE_ROOT', 'FAKE_WRONG', 'FAKE_VTOKEN', 'BGate', 'Error', 'WhatIfPreference', 'PSDefaultParameterValues',
  'OrigWhatIf', 'OrigPSDPV', 'Results', 'CaseVar')
function Flat-Text { param($v)
  if ($null -eq $v) { return '' }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Collections.IDictionary]) { return ((@($v.Keys) | ForEach-Object { [string]$_ + '=' + [string]$v[$_] }) -join "`n") }
  if ($v -is [System.Collections.IEnumerable]) { return ((@($v) | ForEach-Object { [string]$_ }) -join "`n") }
  [string]$v }
function Snapshot-Globals { $h = @{}; foreach ($g in @(Get-Variable -Scope Global)) { $h[$g.Name] = $g.Value }; $h }
function Globals-Hit { param($before, $needles)
  foreach ($g in @(Get-Variable -Scope Global)) {
    if ($HarnessGlobals -contains $g.Name) { continue }
    if ($before.ContainsKey($g.Name) -and [object]::ReferenceEquals($before[$g.Name], $g.Value)) { continue }
    $hit = First-Needle (Flat-Text $g.Value) $needles
    if ($null -ne $hit) { return "`$$($g.Name)(바늘 길이 $($hit.Length))" } }
  $null }

# ---------------------------------------------------------------- 시나리오 실행기 · 공통 사후 조건(T075 Run-OCase 꼴)
$Results = [System.Collections.ArrayList]::new()
function Check { param([string]$name, [bool]$ok, [string]$detail = '', [switch]$Gate) [void]$global:CaseChecks.Add([pscustomobject]@{ name = $name; ok = $ok; detail = $detail; gate = [bool]$Gate }) }
function Finish-Case { param([string]$id, [string]$desc, [string]$text)
  $bad = @($global:CaseChecks | Where-Object { -not $_.ok })
  [void]$Results.Add([pscustomobject]@{ id = $id; desc = $desc; pass = ($bad.Count -eq 0 -and $global:CaseChecks.Count -gt 0); total = $global:CaseChecks.Count; failed = $bad.Count
      detail = (($bad | Select-Object -First 6 | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) }) -join ' | ') })
  if ($bad.Count -gt 0 -or ($Show -and $id -like $Show)) { Write-Host "---- $id 화면 출력 ----`n$text`n" -ForegroundColor DarkGray } }
function Ev-Index { param([string]$e, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (SEq $global:Events[$i] $e) { return $i } }; -1 }
function Ev-First { param([string]$prefix, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (([string]$global:Events[$i]).StartsWith($prefix, [StringComparison]::Ordinal)) { return $i } }; -1 }
function Ev-Count { param([string]$prefix) @($global:Events | Where-Object { ([string]$_).StartsWith($prefix, [StringComparison]::Ordinal) }).Count }
$ValPfx = @('vault:status', 'vault:token-lookup', 'vault:kv-get:', 'vault:meta-get:', 'tofu:output:', 'curl:get:', 'curl:post:', 'kubectl:token:', 'read:secure')
function First-Val { $iVal = -1; foreach ($pfx in $ValPfx) { $j = Ev-First $pfx; if ($j -ge 0 -and ($iVal -lt 0 -or $j -lt $iVal)) { $iVal = $j } }; $iVal }
# 공통 사후(T075 라운드 1 · 2): ① 모듈 로깅 실효 확인이 값이 오가는 첫 동작보다 먼저 ② 보안 입력 바로 다음 = 클립보드 비움 ③ 모의 호출 시점 env 에 비밀 0 ④ 화면 제어 문자 0 ⑤ $Error 정리
function Check-ErrClean { param([bool]$threw, [string]$errMsg)
  $left = @($global:Error | Where-Object { -not ($threw -and ($_ -is [System.Management.Automation.ErrorRecord]) -and (SEq ([string]$_.Exception.Message) $errMsg)) })
  Check '$Error 에 블록이 남긴 기록 0(finally 가 이 실행분을 지운다 — throw 시나리오는 그 throw 1건만)' ($left.Count -eq 0) "남은 기록 $($left.Count)" }
function Check-R1 { param([string]$text, $needles)
  $iVal = First-Val
  if ($iVal -ge 0) {
    $iMod = Ev-First 'mod:get'; $iCs = Ev-First 'cfg:test:system'; $iCu = Ev-First 'cfg:test:user'; $iCore = Ev-First 'mod:core'
    Check '모듈 로깅 실효 확인(Utility · Security · Management · Core 스냅인 · 설정 파일 둘)이 값이 오가는 첫 동작(vault · tofu output · curl GET/POST · kubectl create token · 보안 입력)보다 먼저' ($iMod -ge 0 -and $iMod -lt $iVal -and $iCore -ge 0 -and $iCore -lt $iVal -and $iCs -ge 0 -and $iCs -lt $iVal -and $iCu -ge 0 -and $iCu -lt $iVal) "mod:get $iMod · mod:core $iCore · cfg $iCs/$iCu · 첫 값 동작 $iVal" }
  $badClip = @(); for ($i = 0; $i -lt $global:Events.Count; $i++) { if ((SEq $global:Events[$i] 'read:secure') -and -not ((($i + 1) -lt $global:Events.Count) -and (SEq $global:Events[$i + 1] 'clip:set'))) { $badClip += $i } }
  Check '보안 입력(root 토큰) 바로 다음 동작 = 클립보드 비움' ($badClip.Count -eq 0) "어긋난 이벤트 위치 $($badClip -join ',')"
  $envHit = $null
  foreach ($s in $global:EnvAtCall) { $h = First-Needle ([string]$s.text) $needles; if ($null -ne $h) { $envHit = "$($s.who) 호출 시점(바늘 길이 $($h.Length))"; break } }
  Check '모의 호출 시점 env 에 비밀 0(vault 는 VAULT_TOKEN 만 예외 · kubectl · tofu · curl 은 예외 없음)' ($null -eq $envHit) ([string]$envHit)
  Check '화면에 제어 문자 0(LF 밖 — 응답 문자열의 터미널 제어열 · OSC 52)' (-not ($text -cmatch '[\p{Cc}-[\n]]')) }
function Run-Case {
  param([string]$Id, [string]$Desc, [string]$File, [hashtable]$Allow = @{}, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [hashtable]$PreEnv = @{}, [string]$Summary = '', [string[]]$Files = @(), [switch]$Vault, [switch]$Paste, [switch]$NoLad,
    [string[]]$ArgList = @(), [switch]$NullArgs)
  if ($global:BGate.ContainsKey($File) -and $global:BGate[$File]) {
    $global:CaseChecks = [System.Collections.ArrayList]::new()
    Check "정적 관문 통과(블록 $File)" $false ([string]$global:BGate[$File])
    Finish-Case $Id $Desc '(정적 관문 FAIL — 실행하지 않았다)'
    return }
  Assert-Guard
  Reset-Mocks
  $global:CaseLad = Join-Path $LadRoot $Id
  [void](New-Item -ItemType Directory -Path $global:CaseLad -Force)
  if ($NoLad) { Remove-Item -LiteralPath Env:LOCALAPPDATA -ErrorAction Ignore } else { $env:LOCALAPPDATA = $global:CaseLad }
  foreach ($k in @($Allow.Keys)) { $global:Allow[$k] = [bool]$Allow[$k] }
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  Check '하네스 자체: 모의 상태 표(CfgText · ModLog · FakeSrc · CmdShape · F)가 해시 테이블 그대로(스크립트 변수 이름 충돌 0)' ($global:CfgText -is [hashtable] -and $global:ModLog -is [hashtable] -and $global:FakeSrc -is [hashtable] -and $global:CmdShape -is [hashtable] -and $global:F -is [hashtable])
  foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
  foreach ($k in @($PreEnv.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value ([string]$PreEnv[$k]) }
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $global:GvBefore = $gvBefore
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  $path = Join-Path $BlockDir $File
  $global:ItemCount = 0
  $pBefore = @{}
  if ($Paste) { foreach ($v in @(Get-Variable -Scope Global)) { $pBefore['g:' + $v.Name] = $true }; foreach ($v in @(Get-Variable -Scope Script)) { $pBefore['s:' + $v.Name] = $true } }
  # 남는 인자(T076 r1): 파일 사례 = 블록 파일을 이 프로세스에서 & <경로> @ArgList(블록의 $script:args = 그 인자 — pwsh -File <경로> <인자> 와 같다 · 모의 함수가 보인다) ·
  #   -NullArgs = 붙여넣기 사례에서 이 스크립트의 $args 를 $null 로(블록의 $script:args = $null — @($null).Count = 1 함정) · 끝나면 @() 로 되돌린다
  if ($NullArgs) { Set-Variable -Name args -Scope Script -Value $null; Check '하네스 자체: 붙여넣기 범위(이 스크립트)의 $args = $null(실행 직전)' ($null -eq (Get-Variable -Name args -Scope Script -ValueOnly)) }
  try {
    if ($Paste) { $psb = [scriptblock]::Create([IO.File]::ReadAllText($path)); & $psb *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
    else { & $path @ArgList *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } } }
  catch { $threw = $true; $errMsg = [string]$_.Exception.Message }
  finally { if ($NullArgs) { Set-Variable -Name args -Scope Script -Value @() } }
  $pNew = @()
  if ($Paste) {
    foreach ($v in @(Get-Variable -Scope Global)) { if (-not $pBefore.ContainsKey('g:' + $v.Name) -and -not (SEq $v.Name 'psb')) { $pNew += 'g:' + $v.Name } }
    foreach ($v in @(Get-Variable -Scope Script)) { if (-not $pBefore.ContainsKey('s:' + $v.Name)) { $pNew += 's:' + $v.Name } } }
  $lines = @($items | ForEach-Object { [string]$_ })
  # 블록 출력의 마지막 줄(하네스가 붙이는 THROW 줄 앞 — W-7 창 정리 줄 판정용)
  $outLast = ''; if ($lines.Count -gt 0) { $outLast = $lines[$lines.Count - 1] }
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  $global:LastItems = $items
  if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg } else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  # 만든 파일(LOCALAPPDATA 아래 전부 — 시나리오 폴더) — 목록을 기대와 정확히 대조하고 글자를 노출 면으로 본다
  # 주의: 변수 이름은 매개변수 $Files([string[]] — 대소문자 무관 같은 변수)와 겹치지 않게 $found 로 둔다
  $found = @(Get-ChildItem -LiteralPath $global:CaseLad -Recurse -File -Force -ErrorAction Ignore)
  $global:CaseFiles = @($found | ForEach-Object { $_.FullName.Substring($global:CaseLad.Length + 1) } | Sort-Object)
  $fileText = (@($found | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n")
  Check "만든 파일 목록 = [$($Files -join ', ')](LOCALAPPDATA 아래 — 그 밖의 파일 0)" (SEq ($global:CaseFiles -join '|') ((@($Files) | Sort-Object) -join '|')) ($global:CaseFiles -join ', ')
  $needles = Build-Needles
  $skipEnv = @(); if ($PreEnv.ContainsKey('VAULT_TOKEN')) { $skipEnv += 'VAULT_TOKEN' }
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv(vault · kubectl · tofu · curl)' = (@($global:ArgvLog) + @($global:XArgv) -join "`n"); '클립보드' = ($global:ClipValues -join "`n")
    '$Error' = (Error-Text); '환경 변수' = (Env-Text $skipEnv); '만든 파일(글자)' = $fileText }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  Check-R1 $text $needles
  Check-ErrClean $threw $errMsg
  # 외부 명령 첫 해석 판정(T076 r1 — S-10): 그 명령의 첫 호출보다 앞에 형식 필터 없는 Get-Command 질의(모의 이벤트 gc:<이름>)가 있다
  $gcBad = @()
  foreach ($pair in @(@('kubectl:', 'gc:kubectl'), @('curl:', 'gc:curl.exe'), @('tofu:', 'gc:tofu'), @('vault:', 'gc:vault'))) {
    $iX = Ev-First $pair[0]
    if ($iX -ge 0) { $iG = Ev-Index $pair[1]; if ($iG -lt 0 -or $iG -gt $iX) { $gcBad += "$($pair[0]) 첫 호출 $iX · $($pair[1]) $iG" } } }
  Check '외부 명령마다 첫 해석 판정(형식 필터 없는 Get-Command)이 그 명령의 첫 호출보다 앞(S-10)' ($gcBad.Count -eq 0) ($gcBad -join ' · ')
  # W-7 finally 의 창 정리 줄(T076 r1 — RO-03 · r2 — RO2-02): 사례가 기대하는 끝 줄이 w7=OK … · w7=SKIP live-same(Want)이면 닫기 줄($W7CLOSE) · 그 밖 전부(w7=STOP … · 예외 · 중단)는
  #   유지 줄($W7KEEP) — 정확히 1 · 다른 꼴 0 · 블록 출력의 마지막 줄 · 옛 「창 종료 체크리스트」 0. 사례 분류는 블록 출력이 아니라 사례 선언(Want · Expect)에서 온다
  if (SEq $File 'w7-seed-tester-m2m.ps1') {
    $w7Ok = @($Want | Where-Object { ([string]$_).StartsWith('w7=OK ', [StringComparison]::Ordinal) -or (SEq $_ 'w7=SKIP live-same') }).Count -gt 0
    Check '하네스 자체: W-7 OK · SKIP 사례(Want 에 w7=OK … · w7=SKIP live-same) = 완주 사례(Expect ok) — 창 정리 줄 분류의 전제' ($w7Ok -eq (SEq $Expect 'ok')) "w7Ok=$w7Ok · Expect=$Expect"
    $wWant = $W7KEEP; $wNot = $W7CLOSE; $wName = '유지 줄(창 C 를 닫지 않는다 — 결정 RO2-02 · STOP · 예외 · 중단 = 기본값)'
    if ($w7Ok) { $wWant = $W7CLOSE; $wNot = $W7KEEP; $wName = '닫기 줄(창 C 종료 — 결정 RO-03 · OK · SKIP 만)' }
    Check "W-7 finally 창 정리 줄 = $wName 정확히 1 · 다른 꼴 0 · 블록 출력의 마지막 줄 · 옛 창 종료 체크리스트 0" (@($lines | Where-Object { SEq $_ $wWant }).Count -eq 1 -and @($lines | Where-Object { SEq $_ $wNot }).Count -eq 0 -and (SEq $outLast $wWant) -and -not $text.Contains('창 종료 체크리스트')) "마지막 줄: $outLast" }
  if ($Paste) {
    $pNew = @($pNew | Where-Object { -not (@('g:StackTrace', 's:StackTrace') -ccontains $_) })
    Check '붙여넣기 실행 뒤 새 전역 · 스크립트 변수 0(블록 밖 범위에 값이 남는 길 0)' ($pNew.Count -eq 0) ($pNew -join ', ')
    foreach ($n in $pNew) { if ($n.StartsWith('g:', [StringComparison]::Ordinal)) { Remove-Variable -Scope Global -Name $n.Substring(2) -ErrorAction SilentlyContinue } else { Remove-Variable -Scope Script -Name $n.Substring(2) -ErrorAction SilentlyContinue } } }
  if ($Vault) {
    if ($PreEnv.ContainsKey('VAULT_TOKEN')) { Check 'env: 시작 전 VAULT_TOKEN 은 건드리지 않는다' (SEq $env:VAULT_TOKEN $PreEnv['VAULT_TOKEN']) }
    else { Check 'env: VAULT_TOKEN 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN)) }
    if ($PreEnv.ContainsKey('VAULT_ADDR') -and -not (SEq $PreEnv['VAULT_ADDR'] $global:EXPECTED_ADDR)) { Check 'env: 시작 전 (다른 값의) VAULT_ADDR 은 건드리지 않는다' (SEq $env:VAULT_ADDR $PreEnv['VAULT_ADDR']) }
    else { Check 'env: VAULT_ADDR 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR)) }
    $sec = @($global:ReadLog | Where-Object { $_.secure })
    if ($sec.Count -gt 0) { Check 'INFO vault CLI 줄이 첫 출력이고 root 토큰 보안 입력보다 먼저다' ($text.StartsWith('INFO vault CLI: ', [StringComparison]::Ordinal) -and $sec[0].items -ge 1) "보안 입력 시점의 출력 수 $($sec[0].items)" } }
  else { Check 'vault CLI 호출 0 · VAULT_* env 를 만들지 않았다' ($global:ArgvLog.Count -eq 0 -and @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) -and -not $PreEnv.ContainsKey($_.Name) }).Count -eq 0) }
  Check '위반 0(허용 목록 밖 vault · kubectl · tofu · curl 인자 · 금지 플래그 · argv 값 · stdin 꼴)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 vault · kubectl · tofu 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0(출력은 Write-Host/Write-Warning 뿐)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
  Check '클립보드에는 공백만 쓴다' (@($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0)
  Check '비밀(hvs. · MOCK) 입력은 전부 -AsSecureString · 입력은 전부 가려진다(-AsSecureString 또는 -MaskInput)' (@($global:ReadLog | Where-Object { (([string]$_.value).Contains('hvs.') -or ([string]$_.value).Contains('MOCK')) -and -not $_.secure }).Count -eq 0 -and @($global:ReadLog | Where-Object { -not $_.secure -and -not $_.masked }).Count -eq 0)
  Check '첫 동작 = Set-PSDebug -Off 1회' ((Ev-Index 'psdebug:off') -eq 0 -and @($global:Events | Where-Object { SEq $_ 'psdebug:off' }).Count -eq 1) $(if ($global:Events.Count) { "첫 이벤트 $($global:Events[0])" } else { '이벤트 0' })
  $iPol = Ev-First 'reg:policy:'
  $iVal = First-Val
  Check '모듈 로깅 정책 확인이 값이 오가는 첫 동작보다 먼저(설계 D3 — 첫 단계)' ($iVal -lt 0 -or ($iPol -ge 0 -and $iPol -lt $iVal)) "정책 $iPol · 첫 값 동작 $iVal"
  if ($Summary) { Check "finally 요약 출력($Summary)" $text.Contains($Summary) }
  if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($k in @($PreEnv.Keys)) { if (Microsoft.PowerShell.Management\Test-Path -LiteralPath ('Env:' + $k)) { Remove-Item -LiteralPath ('Env:' + $k) } }
  $env:LOCALAPPDATA = $LadRoot
  $global:FakeSrc = @{}; $global:CmdShape = @{}; $global:CoreLog = $false; $global:CoreNoSnap = $false; $global:CoreMissing = $false
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- 정적 관문(T075 S12 · Run-OStatic 의 판정 함수 그대로 — 블록을 실행하지 않는다)
$FinallyCmds = @('Write-Host', 'Write-Warning', 'Remove-Item', 'Remove-Variable', 'Set-Clipboard')
function Finally-Emitters { param($stmts)
  $bad = @()
  foreach ($s in @($stmts)) {
    if ($s -is [System.Management.Automation.Language.AssignmentStatementAst]) { continue }
    if ($s -is [System.Management.Automation.Language.PipelineAst]) {
      $last = $s.PipelineElements[$s.PipelineElements.Count - 1]
      if ($last -is [System.Management.Automation.Language.CommandAst]) { if ($FinallyCmds -notcontains [string]$last.GetCommandName()) { $bad += "L$($s.Extent.StartLineNumber) $($last.GetCommandName())" } }
      elseif ($last -is [System.Management.Automation.Language.CommandExpressionAst] -and $last.Expression -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and (@('RemoveAt', 'Clear') -contains [string]$last.Expression.Member.Value)) { }
      else { $bad += "L$($s.Extent.StartLineNumber) 값 출력 가능 식" }
      continue }
    if ($s -is [System.Management.Automation.Language.IfStatementAst]) {
      foreach ($c in $s.Clauses) { $bad += Finally-Emitters $c.Item2.Statements }
      if ($null -ne $s.ElseClause) { $bad += Finally-Emitters $s.ElseClause.Statements }
      continue }
    if ($s -is [System.Management.Automation.Language.TryStatementAst]) {
      $bad += Finally-Emitters $s.Body.Statements
      foreach ($cc in $s.CatchClauses) { $bad += Finally-Emitters $cc.Body.Statements }
      if ($null -ne $s.Finally) { $bad += Finally-Emitters $s.Finally.Statements }
      continue }
    if ($s -is [System.Management.Automation.Language.LoopStatementAst]) { $bad += Finally-Emitters $s.Body.Statements; continue }
    $bad += "L$($s.Extent.StartLineNumber) 알 수 없는 문장($($s.GetType().Name))" }
  , $bad }
function Var-Name { param($n) $u = [string]$n.VariablePath.UserPath; $i = $u.LastIndexOf(':'); if ($i -ge 0) { $u.Substring($i + 1) } else { $u } }
function Is-Member { param($node, $expr, [string]$name, [bool]$invoke)
  if ($null -eq $node -or $node -isnot [System.Management.Automation.Language.MemberExpressionAst] -or $node.Static) { return $false }
  if (-not [object]::ReferenceEquals($node.Expression, $expr)) { return $false }
  if (-not (SEq $node.Member.Extent.Text $name)) { return $false }
  $isInv = $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]
  if ($invoke -ne $isInv) { return $false }
  if ($isInv -and $null -ne $node.Arguments -and $node.Arguments.Count -gt 0) { return $false }
  $true }
function Is-FlushStmt { param($s)
  if ($s -isnot [System.Management.Automation.Language.PipelineAst] -or $s.PipelineElements.Count -ne 1) { return $false }
  $ce = $s.PipelineElements[0]
  if ($ce -isnot [System.Management.Automation.Language.CommandExpressionAst]) { return $false }
  $m3 = $ce.Expression
  if ($m3 -isnot [System.Management.Automation.Language.InvokeMemberExpressionAst]) { return $false }
  $m2 = $m3.Expression
  if ($m2 -isnot [System.Management.Automation.Language.MemberExpressionAst]) { return $false }
  $m1 = $m2.Expression
  if ($m1 -isnot [System.Management.Automation.Language.MemberExpressionAst]) { return $false }
  $v = $m1.Expression
  ($v -is [System.Management.Automation.Language.VariableExpressionAst]) -and [string]::Equals((Var-Name $v), 'Host', [StringComparison]::OrdinalIgnoreCase) -and
    (Is-Member $m1 $v 'UI' $false) -and (Is-Member $m2 $m1 'RawUI' $false) -and (Is-Member $m3 $m2 'FlushInputBuffer' $true) }
function Is-FlushOrTry { param($s)
  if (Is-FlushStmt $s) { return $true }
  ($s -is [System.Management.Automation.Language.TryStatementAst]) -and $s.Body.Statements.Count -eq 1 -and (Is-FlushStmt $s.Body.Statements[0]) }
function Static-Gate { param([int]$Expected = 5)
  $g = @($global:CaseChecks | Where-Object { $_.gate })
  $bad = @($g | Where-Object { -not $_.ok } | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) })
  if ($g.Count -ne $Expected) { $bad += "관문 단언 $($g.Count)개(기대 $Expected)" }
  $bad -join ' · ' }
function Find-Inner { param($ast)
  $stmts = $ast.EndBlock.Statements
  if ($stmts.Count -ne 1 -or $null -ne $ast.BeginBlock -or $null -ne $ast.ProcessBlock -or $null -ne $ast.ParamBlock) { return $null }
  if ($stmts[0] -isnot [System.Management.Automation.Language.PipelineAst] -or $stmts[0].PipelineElements.Count -ne 1) { return $null }
  $c = $stmts[0].PipelineElements[0]
  if ($c -is [System.Management.Automation.Language.CommandAst] -and $c.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $c.CommandElements.Count -eq 1 -and $c.CommandElements[0] -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { return $c.CommandElements[0].ScriptBlock }
  $null }
function Bad-Cmds { param($ast, [string[]]$allowed, [string[]]$helpers, $inner)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
    if ($c.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot) { $bad += "L$($c.Extent.StartLineNumber) dot-source"; continue }
    $nm = $c.GetCommandName()
    if ($null -ne $nm) { if (-not (@($allowed | Where-Object { [string]::Equals($_, $nm, [StringComparison]::OrdinalIgnoreCase) }).Count)) { $bad += "L$($c.Extent.StartLineNumber) $nm" }; continue }
    $first = $c.CommandElements[0]
    if ($first -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and [object]::ReferenceEquals($first.ScriptBlock, $inner)) { continue }
    if ($first -is [System.Management.Automation.Language.VariableExpressionAst] -and (@($helpers) -ccontains $first.VariablePath.UserPath)) { continue }
    $bad += "L$($c.Extent.StartLineNumber) & $($first.Extent.Text)" }
  , $bad }
function Bad-Types { param($ast, [string[]]$allowed)
  $bad = @()
  foreach ($m in $ast.FindAll({ param($n) ($n -is [System.Management.Automation.Language.MemberExpressionAst]) -and $n.Static -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] }, $true)) {
    $tn = $m.Expression.TypeName.FullName
    if (-not (@($allowed | Where-Object { [string]::Equals($_, $tn, [StringComparison]::OrdinalIgnoreCase) }).Count)) { $bad += "L$($m.Extent.StartLineNumber) [$tn]::" } }
  , $bad }
function Bad-Host { param($ast)
  $bad = @()
  foreach ($v in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and ([string]::Equals((Var-Name $n), 'Host', [StringComparison]::OrdinalIgnoreCase) -or [string]::Equals((Var-Name $n), 'ExecutionContext', [StringComparison]::OrdinalIgnoreCase)) }, $true)) {
    $m1 = $v.Parent; $m2 = $null; $m3 = $null
    if ($null -ne $m1) { $m2 = $m1.Parent }
    if ($null -ne $m2) { $m3 = $m2.Parent }
    $ok = [string]::Equals((Var-Name $v), 'Host', [StringComparison]::OrdinalIgnoreCase) -and (Is-Member $m1 $v 'UI' $false) -and (Is-Member $m2 $m1 'RawUI' $false) -and (Is-Member $m3 $m2 'FlushInputBuffer' $true)
    if (-not $ok) {
      $top = $v
      while ($null -ne $top.Parent -and $top.Parent -is [System.Management.Automation.Language.MemberExpressionAst] -and [object]::ReferenceEquals($top.Parent.Expression, $top)) { $top = $top.Parent }
      $t = $top.Extent.Text; if ($t.Length -gt 60) { $t = $t.Substring(0, 60) + '…' }
      $bad += "L$($v.Extent.StartLineNumber) $t" } }
  , $bad }
function Bad-Redir { param($ast)
  $bad = @()
  foreach ($r in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FileRedirectionAst] }, $true)) { if (-not (SEq $r.Location.Extent.Text '$null')) { $bad += "L$($r.Extent.StartLineNumber) $($r.Extent.Text)" } }
  , $bad }
function Bad-Secrets { param([string]$text)
  , @([regex]::Matches($text, '[A-Za-z0-9_\-+/=]{32,}') | Where-Object { $_.Value -cmatch '[A-Z]' -and $_.Value -cmatch '[a-z]' -and $_.Value -cmatch '[0-9]' } | ForEach-Object { $_.Value.Substring(0, 6) + '…' }) }
function Cmd-Text { param($c) (@($c.CommandElements) | ForEach-Object { $_.Extent.Text }) -join ' ' }
function Find-Cmd { param($ast, [string]$name) @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), $name, [StringComparison]::Ordinal) }, $true)) }
function Sb-Names { param($ast)
  @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and $n.Right.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true) | ForEach-Object { Var-Name $_.Left }) }
function Assigns { param($ast, [string]$name) @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) $name) }, $true)) }
# T075 Static-R1 그대로: $env: 대입은 VAULT_ADDR · VAULT_TOKEN 만 · $script: · $global: 대입은 $global:LASTEXITCODE 만 · 모듈 로깅 실효 확인 문장의 정확한 꼴
function Static-R1 { param($ast, [string]$text)
  $bad5 = @()
  foreach ($a5 in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    $lv = $a5.Left
    while ($lv -is [System.Management.Automation.Language.ConvertExpressionAst] -or $lv -is [System.Management.Automation.Language.AttributedExpressionAst]) { $lv = $lv.Child }
    while ($lv -is [System.Management.Automation.Language.MemberExpressionAst] -or $lv -is [System.Management.Automation.Language.IndexExpressionAst]) { if ($lv -is [System.Management.Automation.Language.IndexExpressionAst]) { $lv = $lv.Target } else { $lv = $lv.Expression } }
    if ($lv -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
    $vp = $lv.VariablePath
    $up = [string]$vp.UserPath
    if ($vp.IsDriveQualified -and [string]::Equals([string]$vp.DriveName, 'env', [StringComparison]::OrdinalIgnoreCase)) {
      $nm = $up.Substring($up.IndexOf(':') + 1)
      if (-not (@('VAULT_ADDR', 'VAULT_TOKEN') -ccontains $nm)) { $bad5 += "L$($a5.Extent.StartLineNumber) `$env:$nm 대입" } }
    elseif ($vp.IsScript -or $vp.IsGlobal) {
      if (-not ($vp.IsGlobal -and (SEq (Var-Name $lv) 'LASTEXITCODE') -and $a5.Left -is [System.Management.Automation.Language.VariableExpressionAst])) { $bad5 += "L$($a5.Extent.StartLineNumber) $($lv.Extent.Text) 대입" } } }
  Check '$env: 대입은 VAULT_ADDR · VAULT_TOKEN 만 · $script: · $global: 대입은 $global:LASTEXITCODE 만(자식 프로세스 env · 붙여넣기 전역에 값이 남는 경로 0)' ($bad5.Count -eq 0) ($bad5 -join '; ')
  $im = @(Find-Cmd $ast 'Import-Module' | ForEach-Object { Cmd-Text $_ })
  $gm = @(Find-Cmd $ast 'Get-Module' | ForEach-Object { Cmd-Text $_ })
  $gc = @(Find-Cmd $ast 'Get-Content' | ForEach-Object { Cmd-Text $_ })
  $gfe = @(Find-Cmd $ast 'Get-Command' | ForEach-Object { Cmd-Text $_ } | Where-Object { $_.Contains('ForEach-Object') })
  $gmWant = @('Get-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security', 'Get-Module Microsoft.PowerShell.Management')
  Check '모듈 로깅 실효 확인 문장(T075 KB-2 · KB2-1 꼴 그대로): Import-Module 세 모듈 1곳 · Get-Module 두 곳 · Get-Command ForEach-Object -CommandType Cmdlet 1곳 · Get-Content -Raw 1곳 · 값 무관 텍스트 판정 · 확인 못 하면 멈춤' ($im.Count -eq 1 -and (SEq $im[0] 'Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security, Microsoft.PowerShell.Management') -and $gm.Count -eq 2 -and @($gm | Where-Object { $gmWant -ccontains $_ } | Sort-Object -Unique).Count -eq 2 -and $gfe.Count -eq 1 -and (SEq $gfe[0] 'Get-Command ForEach-Object -CommandType Cmdlet') -and $text.Contains('{ $mlCore = $mlFe[0].PSSnapIn }') -and $text.Contains("if (`$null -ne `$mlCore -and `$mlCore.LogPipelineExecutionDetails) { `$mlEff += 'Microsoft.PowerShell.Core' }") -and $text.Contains('$mlEff = @(@($mlMods) + @($mlMgmt) | Where-Object { $_.LogPipelineExecutionDetails }') -and $gc.Count -eq 1 -and (SEq $gc[0] 'Get-Content -Raw -LiteralPath $_') -and $text.Contains("-cmatch '(?i:ModuleLogging)|\x5Cu'") -and $text.Contains('if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw') -and $text.Contains("(Join-Path `$PSHOME 'powershell.config.json')") -and $text.Contains('$PROFILE.CurrentUserAllHosts')) "Import-Module $($im.Count) · Get-Module $($gm.Count) · Get-Command ForEach-Object $($gfe.Count) · Get-Content $($gc.Count)" }
# curl 금지 플래그(설계 D8 — 모든 블록 · 대소문자 구분: -x = 프록시 · -X = 메서드) · 첫 인자 -q
$CurlForbid = @('-v', '--verbose', '-i', '--include', '-I', '--head', '-D', '--dump-header', '-c', '--cookie-jar', '-b', '--cookie', '-L', '--location', '--location-trusted', '-x', '--proxy', '-K', '--config', '-n', '--netrc', '--netrc-optional', '--netrc-file', '-o', '--output', '-O', '-k', '--insecure')
function Run-Static { param([string]$Id, [string]$File, [string[]]$Cmds, [string[]]$Types, [string[]]$Owners, [string[]]$VSigs = @(), [int]$ReadHosts = 0, [switch]$VaultEnv, [scriptblock]$Extra = $null)
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $path = Join-Path $BlockDir $File
  $exists = Microsoft.PowerShell.Management\Test-Path -LiteralPath $path
  Check '블록 파일 존재' $exists
  $bytes = [byte[]]@(); if ($exists) { $bytes = [IO.File]::ReadAllBytes($path) }
  Check 'BOM 없음 · CR 0 · TAB 0' ($bytes.Length -gt 0 -and -not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) -and @($bytes | Where-Object { $_ -eq 13 -or $_ -eq 9 }).Count -eq 0)
  $utf8ok = $true; try { [void][Text.UTF8Encoding]::new($false, $true).GetString($bytes) } catch { $utf8ok = $false }
  Check 'UTF-8 유효 · 끝 = } + LF 1개' ($utf8ok -and $bytes.Length -ge 2 -and $bytes[$bytes.Length - 2] -eq 0x7D -and $bytes[$bytes.Length - 1] -eq 0x0A)
  $text = [Text.Encoding]::UTF8.GetString($bytes)
  $lines = $text.Split("`n")
  $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
  Check '첫 줄 = & { · 빈 줄 0(파일 전체 — 붙여넣기 안전)' ($lines.Count -gt 1 -and (SEq $lines[0] '& {') -and $blank -eq 0) "빈 줄 $blank"
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $inner = Find-Inner $ast
  Check '최상위 문장 1개 = & { … } · } 뒤 남는 문자 0 · param 0' ($null -ne $inner -and $ast.EndBlock.Statements[0].Extent.EndOffset -eq $text.Length - 1 -and $null -eq $inner.ParamBlock)
  $helpers = Sb-Names $ast
  $badCmd = Bad-Cmds $ast $Cmds $helpers $inner
  Check "명령 허용 목록($($Cmds.Count)개 · 스크립트블록 헬퍼만 & 호출 — Start-Transcript · Out-File · Invoke-Expression · Start-Process · 절대 경로 실행 파일 등 0)" ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $Types
  Check "정적 .NET 호출 허용 목록($($Types.Count)개 — [Console] · [Environment] · [Diagnostics.Process] 등 0)" ($badType.Count -eq 0) ($badType -join '; ') -Gate
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  if ($null -ne $inner) {
    $b0 = @($inner.EndBlock.Statements)
    $psd = @(Find-Cmd $ast 'Set-PSDebug').Count
    Check '본문 첫 문장 = Set-PSDebug -Off · 그 1곳뿐' ($b0.Count -gt 0 -and (SEq $b0[0].Extent.Text 'Set-PSDebug -Off') -and $psd -eq 1)
    $pre0 = @($b0 | ForEach-Object { $_.Extent.Text })
    $fixMissing = @(@('$WhatIfPreference = $false', "`$ConfirmPreference = 'High'", '$PSDefaultParameterValues = @{}') | Where-Object { $f = $_; @($pre0 | Where-Object { SEq $_ $f }).Count -ne 1 })
    Check '본문 직계 문장으로 세션 설정 고정 3문장' ($fixMissing.Count -eq 0) ($fixMissing -join '; ')
    $tries = @($b0 | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
    Check '본문 try 1개 + finally' ($tries.Count -eq 1 -and $null -ne $tries[0].Finally)
    if ($tries.Count -eq 1 -and $null -ne $tries[0].Finally) {
      $fe = Finally-Emitters $tries[0].Finally.Statements
      Check 'finally 는 Write-Host/Write-Warning · Remove-* · Set-Clipboard · 대입만(성공 스트림 출력 없음)' ($fe.Count -eq 0) ($fe -join '; ')
      if ($VaultEnv) {
        $fs = @($tries[0].Finally.Statements | ForEach-Object { $_.Extent.Text })
        Check 'finally 첫 두 문장 = 블록이 만든 VAULT_TOKEN · VAULT_ADDR 제거' ($fs.Count -ge 2 -and $fs[0].StartsWith('if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN', [StringComparison]::Ordinal) -and $fs[1].StartsWith('if ($addrOwned) { Remove-Item Env:VAULT_ADDR', [StringComparison]::Ordinal)) } } }
  $badRead = @()
  $reads = @(Find-Cmd $ast 'Read-Host')
  foreach ($c in $reads) {
    $p = $c.Parent; $owner = $null; $sbx = $null
    while ($null -ne $p -and $null -eq $sbx) { if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { $sbx = $p }; $p = $p.Parent }
    if ($null -ne $sbx) { $p = $sbx.Parent; while ($null -ne $p) { if ($p -is [System.Management.Automation.Language.AssignmentStatementAst] -and $p.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $owner = $p.Left.VariablePath.UserPath; break }; if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { break }; $p = $p.Parent } }
    if (-not (@($Owners) -ccontains [string]$owner) -or $null -eq $sbx) { $badRead += "L$($c.Extent.StartLineNumber) 헬퍼 밖 Read-Host"; continue }
    $body = @($sbx.ScriptBlock.EndBlock.Statements)
    $iR = -1; for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
    if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $badRead += "L$($c.Extent.StartLineNumber) 바로 앞 직계 문장이 입력 버퍼 비움이 아니다" } }
  Check "Read-Host $ReadHosts 곳 · 정지점 헬퍼($($Owners -join ' · ')) 안에서만 · 바로 앞 직계 문장 = 입력 버퍼 비움(AST) · 가려진 입력(-MaskInput · -AsSecureString)" ($badRead.Count -eq 0 -and $reads.Count -eq $ReadHosts -and @($reads | Where-Object { -not ((Cmd-Text $_).Contains(' -MaskInput') -or (Cmd-Text $_).Contains(' -AsSecureString')) }).Count -eq 0) "$($badRead -join '; ') · Read-Host $($reads.Count) 곳"
  $badVault = @()
  foreach ($c in (Find-Cmd $ast 'vault')) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    $sig = ($el | Select-Object -First 3) -join ' '
    foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $badVault += "L$($c.Extent.StartLineNumber) -field" } }
    if (-not @($VSigs | Where-Object { $sig.StartsWith($_, [StringComparison]::Ordinal) }).Count) { $badVault += "L$($c.Extent.StartLineNumber) vault $sig" } }
  Check "vault 호출 모양(허용 접두: $(if ($VSigs.Count) { $VSigs -join ' / ' } else { '없음 — vault 0' }) · -field 0)" ($badVault.Count -eq 0) ($badVault -join '; ')
  $badCurl = @()
  foreach ($c in (Find-Cmd $ast 'curl.exe')) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    if (-not (SEq (At $el 0) '-q')) { $badCurl += "L$($c.Extent.StartLineNumber) 첫 인자 -q 아님" }
    foreach ($x in $el) { if (($CurlForbid -ccontains [string]$x) -or ([string]$x).StartsWith('--trace', [StringComparison]::Ordinal)) { $badCurl += "L$($c.Extent.StartLineNumber) 금지 플래그 $x" } } }
  Check 'curl.exe 호출마다 첫 인자 -q · 금지 플래그 0(-v · -i · -I · -D · -c · -b · --trace* · -L · --location* · -x · --proxy · -K · --config · -n · --netrc* · -o · -O · -k — 대소문자 구분)' ($badCurl.Count -eq 0) ($badCurl -join '; ')
  # 날짜 꼴(T076 r1 — 리뷰 C-12): 글자 꼴 ToString 은 표준 s · o(문화권 불변 — 실측 2026-11-20: ko-KR · fi-FI · th-TH · ar-SA · fa-IR 같은 값)와 N(Guid) · x2(16진) 밖이면
  #   두 번째 인자 [Globalization.CultureInfo]::InvariantCulture 가 있어야 한다 — 사용자 지정 꼴의 : · 연도가 문화권(시간 구분자 · 달력)을 따르지 않게
  $badFmt = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and -not $n.Static -and (SEq $n.Member.Extent.Text 'ToString') -and $null -ne $n.Arguments -and $n.Arguments.Count -ge 1 -and $n.Arguments[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) |
      Where-Object { -not (@('s', 'o', 'N', 'x2') -ccontains [string]$_.Arguments[0].Value) -and -not ($_.Arguments.Count -eq 2 -and (SEq $_.Arguments[1].Extent.Text '[Globalization.CultureInfo]::InvariantCulture')) } | ForEach-Object { "L$($_.Extent.StartLineNumber) $($_.Extent.Text)" })
  Check '글자 꼴 ToString = 표준 s · o · N · x2 이거나 InvariantCulture 와 함께(C-12 — 사용자 지정 날짜 꼴이 문화권을 따르지 않는다)' ($badFmt.Count -eq 0) ($badFmt -join '; ')
  Check '모듈 로깅 4키 가드 문장이 있다(PowerShellCore · UseWindowsPowerShellPolicySetting · Windows\PowerShell · EnableModuleLogging)' ($text.Contains('PowerShellCore\ModuleLogging') -and $text.Contains('UseWindowsPowerShellPolicySetting') -and $text.Contains('Windows\PowerShell\ModuleLogging') -and $text.Contains("'EnableModuleLogging') -eq 1"))
  $kcRef = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.VariablePath.UserPath, 'env:KUBECONFIG', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check 'MOCK 0 · 비밀처럼 보이는 상수 0 · hvs.<영숫자> 0 · Start-Transcript 0 · $env:KUBECONFIG 참조 0' (-not $text.Contains('MOCK') -and (Bad-Secrets $text).Count -eq 0 -and -not ($text -cmatch 'hvs\.[A-Za-z0-9]') -and -not $text.Contains('Start-Transcript') -and $kcRef -eq 0) "$((Bad-Secrets $text) -join ', ') · KUBECONFIG 참조 $kcRef"
  Static-R1 $ast $text
  if ($Extra) { try { & $Extra $ast $text } catch { Check '블록별 정적 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  Finish-Case $Id "정적 — $File(관문 5: 파서 · 명령 · 형식 · `$Host · 리다이렉트 + 구조 · 세션 고정 · finally · Read-Host · vault · curl 모양 · 모듈 로깅 가드 · 비밀 상수 0 · 블록별 꼴)" ''
  Static-Gate -Expected 5 }

# ---------------------------------------------------------------- 블록별 정적 꼴
# 관리자 kubeconfig 로 kubectl 한 곳 · 인자 = @kargs 펼침 · $kargs 글자 정확히 · 관리자 kubeconfig 존재 확인 · INFO 줄에 kubectl 경로
$kubectlOne = { param($ast, $text, [string]$want)
  $kc = @(Find-Cmd $ast 'kubectl')
  $pl = $null; if ($kc.Count -eq 1) { $pl = $kc[0].Parent }
  Check 'kubectl 호출 정확히 1곳 · 인자 = @kargs 하나(펼침) · stdin 0(파이프 앞 원소 없음)' ($kc.Count -eq 1 -and $kc[0].CommandElements.Count -eq 2 -and $kc[0].CommandElements[1] -is [System.Management.Automation.Language.VariableExpressionAst] -and $kc[0].CommandElements[1].Splatted -and (SEq (Var-Name $kc[0].CommandElements[1]) 'kargs') -and $null -ne $pl -and $pl -is [System.Management.Automation.Language.PipelineAst] -and $pl.PipelineElements.Count -eq 1)
  $ka = @(Assigns $ast 'kargs')
  Check "`$kargs = $want(토큰 · 비밀 변수 0)" ($ka.Count -eq 1 -and (SEq $ka[0].Right.Extent.Text $want)) $(if ($ka.Count -eq 1) { $ka[0].Right.Extent.Text } else { "대입 $($ka.Count)곳" })
  $iTest = $text.IndexOf("if (-not (Test-Path -LiteralPath `$kc)) { throw '관리자 kubeconfig", [StringComparison]::Ordinal)
  $iK = $text.IndexOf('kubectl @kargs', [StringComparison]::Ordinal)
  Check '관리자 kubeconfig = Join-Path $HOME ''.kube\joshuatech-admin.yaml''(--kubeconfig 로 직접) · 존재 확인이 kubectl 보다 앞 · INFO 줄에 kubectl 경로(~)' ($text.Contains("`$kc = Join-Path `$HOME '.kube\joshuatech-admin.yaml'") -and $iTest -ge 0 -and $iK -gt $iTest -and $text.Contains('$ksrc = & $tilde $kcs[0].Source') -and $text.Contains('kubectl $([string]$kcs[0].CommandType) $ksrc')) }
# 남는 인자 판정(T076 r1 — S-07 · C-02 · RO-02): 정확한 꼴 1곳 · 멈춤 · 모듈 로깅 실효 확인 뒤 · 첫 외부 이름 질의($anchor) 앞 · $null 을 1 로 세는 @($script:args).Count 꼴 0
$argsShape = { param($ast, $text, [string]$anchor)
  $want = '$nArg = @($script:args | Where-Object { $null -ne $_ }).Count'
  $n = ([regex]::Matches($text, [regex]::Escape($want))).Count
  $iA = $text.IndexOf($want, [StringComparison]::Ordinal); $iMl = $text.IndexOf('if ($mlMods.Count -ne 2 -or', [StringComparison]::Ordinal); $iF = $text.IndexOf($anchor, [StringComparison]::Ordinal)
  Check "남는 인자 판정 = $want 1곳 · if (`$nArg -gt 0) 멈춤 · 모듈 로깅 실효 확인 뒤 · 첫 외부 이름 질의($anchor) 앞 · @(`$script:args).Count 꼴 0" ($n -eq 1 -and $text.Contains('if ($nArg -gt 0) {') -and $iMl -ge 0 -and $iA -gt $iMl -and $iF -gt $iA -and -not $text.Contains('@($script:args).Count')) "판정 $n 곳 · 위치 $iMl < $iA < $iF"
  Check '외부 이름(kubectl · curl.exe · tofu · vault) Get-Command 질의에 형식 필터 0(-CommandType — 첫 해석 판정을 우회한다)' (-not ($text -cmatch 'Get-Command (kubectl|curl\.exe|tofu|vault)\b[^\n]*-CommandType')) }
$w7Shape = { param($ast, $text)
  $tc = @(Find-Cmd $ast 'tofu' | ForEach-Object { Cmd-Text $_ })
  Check 'tofu 호출 = tofu version · tofu "-chdir=$infra" output -json service_tokens 각 1곳뿐(apply · state · show · 다른 output 0)' ($tc.Count -eq 2 -and @($tc | Where-Object { SEq $_ 'tofu version' }).Count -eq 1 -and @($tc | Where-Object { SEq $_ 'tofu "-chdir=$infra" output -json service_tokens' }).Count -eq 1) ($tc -join ' | ')
  $iEnv = $text.IndexOf("@('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR') -contains `$_.Name -or `$_.Name -like 'TF_LOG*' -or `$_.Name -like 'TF_CLI_ARGS*'", [StringComparison]::Ordinal)
  $iTofu = $text.IndexOf('tofu "-chdir=$infra" output', [StringComparison]::Ordinal)
  $iTok = $text.IndexOf("& `$readSecret 'root 토큰", [StringComparison]::Ordinal)
  $iAddr = $text.IndexOf('$env:VAULT_ADDR = $vaultAddr', [StringComparison]::Ordinal)
  Check '환경 변수 판정(T075 O-5 와 같은 목록 + TF_LOG* · TF_CLI_ARGS*)이 첫 tofu output 보다 앞 · tofu output 이 VAULT_ADDR 설정 · root 토큰 입력보다 앞(tofu 가 도는 동안 VAULT_* 0)' ($iEnv -ge 0 -and $iTofu -gt $iEnv -and $iAddr -gt $iTofu -and $iTok -gt $iAddr) "env $iEnv · tofu $iTofu · addr $iAddr · token $iTok"
  & $argsShape $ast $text '$tcs = @(Get-Command tofu'
  $iT = $text.IndexOf("if (-not (& `$eq ([string]`$tcs[0].CommandType) 'Application')) { `$shadow +=", [StringComparison]::Ordinal)
  $iV = $text.IndexOf("if (-not (& `$eq ([string]`$vcs[0].CommandType) 'Application')) { `$shadow +=", [StringComparison]::Ordinal)
  $iSh = $text.IndexOf('if ($shadow.Count -gt 0) {', [StringComparison]::Ordinal)
  Check 'tofu · vault 첫 해석 판정(S-10) = 형식 필터 없는 @(Get-Command tofu|vault -ErrorAction SilentlyContinue) · CommandType 이 Application 아니면 멈춤 · 판정이 vault version · tofu version 앞' ($text.Contains('$tcs = @(Get-Command tofu -ErrorAction SilentlyContinue)') -and $text.Contains('$vcs = @(Get-Command vault -ErrorAction SilentlyContinue)') -and $iT -ge 0 -and $iV -gt $iT -and $iSh -gt $iV -and $iSh -lt $text.IndexOf('$ver = @(vault version', [StringComparison]::Ordinal) -and $iSh -lt $text.IndexOf('$tv = @(tofu version', [StringComparison]::Ordinal)) "tofu $iT · vault $iV · 멈춤 $iSh"
  $iCn = $text.IndexOf("if (-not (& `$eq `$cn 'vault-cluster-d3b29227')) {", [StringComparison]::Ordinal)
  Check 'cluster_name 판정(S-09) = vault status 응답의 cluster_name = vault-cluster-d3b29227(Ordinal) · vault status 뒤 · root 토큰 입력 앞' ($text.Contains("`$cn = & `$prop `$st 'cluster_name'") -and $iCn -gt $text.IndexOf('$so = @(vault status', [StringComparison]::Ordinal) -and $iCn -lt $iTok) "cluster_name $iCn · token $iTok"
  Check 'finally 창 정리 줄 두 꼴 = 결정 RO-03(닫기 — OK · SKIP) · RO2-02(유지 — 그 밖 · 기본값) 글자 그대로 Write-Host 각 1곳 · 옛 창 종료 체크리스트 0' ($text.Contains("Write-Host '$W7CLOSE'") -and $text.Contains("Write-Host '$W7KEEP'") -and ([regex]::Matches($text, [regex]::Escape($W7CLOSE))).Count -eq 1 -and ([regex]::Matches($text, [regex]::Escape($W7KEEP))).Count -eq 1 -and -not $text.Contains('창 종료 체크리스트'))
  $vc = @(Find-Cmd $ast 'vault' | ForEach-Object { Cmd-Text $_ })
  Check 'kv put 1곳 = vault kv put "-cas=$($p.cv)" $p.path -(JSON stdin · 값 argv 0) · patch · delete · destroy · undelete · write · read 0' (@($vc | Where-Object { SEq $_ 'vault kv put "-cas=$($p.cv)" $p.path -' }).Count -eq 1 -and @($vc | Where-Object { $_.Contains(' put ') }).Count -eq 1 -and @($vc | Where-Object { $_.Contains(' patch') -or $_.Contains(' delete') -or $_.Contains(' destroy') -or $_.Contains(' undelete') -or $_.Contains(' write') -or $_.StartsWith('vault read', [StringComparison]::Ordinal) }).Count -eq 0) ($vc -join ' | ')
  $kvc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and ([string]$n.Value).StartsWith('kv/', [StringComparison]::Ordinal) }, $true) | ForEach-Object { [string]$_.Value } | Sort-Object -Unique)
  Check '경로 상수 = kv/platform/access/tester-m2m 하나(그 밖의 kv/ 경로 상수 0) · 토큰 이름 상수 tester-m2m' ((SEq ($kvc -join '|') 'kv/platform/access/tester-m2m') -and $text.Contains("`$kvPath = 'kv/platform/access/tester-m2m'") -and $text.Contains("`$tokName = 'tester-m2m'")) ($kvc -join ' | ')
  Check '자격 꼴(T075 L4 실측) — client_id -cnotmatch ''\A[0-9a-f]{32}\.access\z'' · client_secret -cnotmatch ''\A[0-9A-Za-z_-]{54}\z''(-c 고정 · \z) · 판정이 Vault 도달 확인보다 앞' ($text.Contains("`$cid -cnotmatch '\A[0-9a-f]{32}\.access\z'") -and $text.Contains("`$csec -cnotmatch '\A[0-9A-Za-z_-]{54}\z'") -and $text.IndexOf("`$csec -cnotmatch", [StringComparison]::Ordinal) -lt $iAddr)
  Check '쓸 값 = 키 정확히 둘 [ordered]@{ client_id = $cid; client_secret = $csec } · 계획은 absent 갈래 한 곳(cv = 0)' ($text.Contains('$plan = [pscustomobject]@{ path = $kvPath; cv = 0; keys = @(''client_id'', ''client_secret''); want = [ordered]@{ client_id = $cid; client_secret = $csec }; verb = ''생성'' }') -and @([regex]::Matches($text, 'want = \[ordered\]@\{')).Count -eq 1)
  Check 'live 갈래 = 키 집합 정확히 둘 + 두 키의 SHA-256 Ordinal 대조(같으면 건너뜀 · 다르면 STOP · 회전 = T084)' ($text.Contains("`$kc = [string](& `$keyCheck `$r.dd @('client_id', 'client_secret'))") -and $text.Contains("if (-not (& `$eq (& `$sha (& `$prop `$r.dd 'client_id')) (& `$sha `$cid))) { `$diff += 'client_id' }") -and $text.Contains("if (-not (& `$eq (& `$sha (& `$prop `$r.dd 'client_secret')) (& `$sha `$csec))) { `$diff += 'client_secret' }"))
  $iSeed = $text.IndexOf("'seed' }", [StringComparison]::Ordinal)
  $iW = $text.IndexOf('try { & $write $plan }', [StringComparison]::Ordinal)
  Check '쓰기 확인 정지점(seed)이 & $write 보다 앞 · & $write 1곳' ($iSeed -ge 0 -and $iW -gt $iSeed -and @([regex]::Matches($text, '& \$write ')).Count -eq 1)
  Check 'INFO 줄에 vault · tofu 실행 파일 경로 · 사용자 홈은 ~ 로' ($text.Contains('Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc · tofu $tvl · $([string]$tcs[0].CommandType) $tsrc —') -and $text.Contains("`$tsrc = '~' + `$tsrc.Substring(`$HOME.Length)") -and $text.Contains("`$vsrc = '~' + `$vsrc.Substring(`$HOME.Length)")) }
$o9Shape = { param($ast, $text)
  & $kubectlOne $ast $text "@('--kubeconfig', `$kc, 'create', 'token', 'agent-view', '-n', 'kube-system', '--audience', 'vault', '--duration=1h')"
  Check '파일 경로 리터럴 = Join-Path $env:LOCALAPPDATA ''jt-e2e\vault-e2e-reader.jwt'' · 폴더 = Join-Path $env:LOCALAPPDATA ''jt-e2e''(O-8 과 같은 경로)' ($text.Contains("`$file = Join-Path `$env:LOCALAPPDATA 'jt-e2e\vault-e2e-reader.jwt'") -and $text.Contains("`$dir = Join-Path `$env:LOCALAPPDATA 'jt-e2e'") -and @(Assigns $ast 'file').Count -eq 1 -and @(Assigns $ast 'dir').Count -eq 1)
  $cfs = @(Find-Cmd $ast 'ConvertFrom-SecureString' | ForEach-Object { Cmd-Text $_ })
  $keyPar = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandParameterAst] -and (@('Key', 'SecureKey') -contains [string]$n.ParameterName) }, $true)).Count
  Check 'DPAPI = ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $jwt -AsPlainText -Force) 1곳 · 매개변수 -Key · -SecureKey 0(AST — DPAPI CurrentUser)' ($cfs.Count -eq 1 -and (SEq $cfs[0] 'ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $jwt -AsPlainText -Force)') -and $keyPar -eq 0) "$($cfs -join ' | ') · -Key/-SecureKey $keyPar"
  $fm = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Static -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] -and (IEq $n.Expression.TypeName.FullName 'System.IO.File') }, $true))
  $fmBad = @($fm | Where-Object { -not (@('WriteAllText', 'ReadAllText', 'Exists', 'Delete') -ccontains [string]$_.Member.Value) -or $_.Arguments.Count -lt 1 -or -not (SEq $_.Arguments[0].Extent.Text '$file') } | ForEach-Object { $_.Extent.Text })
  Check '[System.IO.File]:: = WriteAllText · ReadAllText · Exists · Delete 뿐 · 경로 인자는 $file 하나 · WriteAllText = ($file, $enc, [System.Text.Encoding]::ASCII) 1곳(덮어쓰기)' ($fmBad.Count -eq 0 -and @($fm | Where-Object { SEq $_.Extent.Text '[System.IO.File]::WriteAllText($file, $enc, [System.Text.Encoding]::ASCII)' }).Count -eq 1 -and @($fm | Where-Object { SEq $_.Member.Value 'WriteAllText' }).Count -eq 1) ($fmBad -join ' | ')
  Check '되읽기 = O-8 과 같은 꼴: [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::ASCII).Trim() | ConvertTo-SecureString → [System.Net.NetworkCredential]::new('''', $ss).Password → Ordinal 대조' ($text.Contains('$ss = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::ASCII).Trim() | ConvertTo-SecureString') -and $text.Contains("`$back = [System.Net.NetworkCredential]::new('', `$ss).Password") -and $text.Contains('$same = & $eq $back $jwt'))
  $dm = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Static -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] -and (IEq $n.Expression.TypeName.FullName 'System.IO.Directory') }, $true) | ForEach-Object { $_.Extent.Text } | Sort-Object -Unique)
  Check '[System.IO.Directory]:: = Exists($env:LOCALAPPDATA) · CreateDirectory($dir) 뿐' (SEq ($dm -join '|') '[System.IO.Directory]::CreateDirectory($dir)|[System.IO.Directory]::Exists($env:LOCALAPPDATA)') ($dm -join ' | ')
  & $argsShape $ast $text '$kcs = @(Get-Command kubectl'
  $iApp = $text.IndexOf("if (-not (& `$eq ([string]`$kcs[0].CommandType) 'Application')) {", [StringComparison]::Ordinal)
  Check 'kubectl 첫 해석 판정(S-10) = 형식 필터 없는 @(Get-Command kubectl -ErrorAction SilentlyContinue) · CommandType 이 Application 아니면 멈춤 · 판정이 정지점(& $pick) · kubectl @kargs 앞' ($text.Contains('$kcs = @(Get-Command kubectl -ErrorAction SilentlyContinue)') -and $iApp -ge 0 -and $iApp -lt $text.IndexOf('$mode = [string](& $pick', [StringComparison]::Ordinal) -and $iApp -lt $text.IndexOf('kubectl @kargs', [StringComparison]::Ordinal)) "판정 $iApp"
  Check '클레임 판정 리터럴 = aud 문자열 "vault" 또는 원소 하나(문자열)인 배열 ["vault"](Ordinal — 꼴 기록 $audForm · 그 밖 = 실패 사유) · 통과 꼴 INFO · sub = system:serviceaccount:kube-system:agent-view · exp − iat = 3600 ± 10 · iat = 지금 ± 120(쓰기 앞)' ($text.Contains('elseif ($audP.Value -is [string] -and (& $eq $audP.Value ''vault'')) { $audForm = ''문자열'' }') -and $text.Contains('elseif ($audP.Value -is [array] -and $audP.Value.Count -eq 1 -and $audP.Value[0] -is [string] -and (& $eq $audP.Value[0] ''vault'')) { $audForm = ''배열'' }') -and $text.Contains('else { $bad += "aud = $(& $clean (& $audTxt $audP.Value))(') -and $text.Contains('if ($audForm) { Write-Host "INFO aud 꼴=$audForm(') -and $text.Contains("if (-not (& `$eq `$sub 'system:serviceaccount:kube-system:agent-view'))") -and $text.Contains('if ([Math]::Abs(($exp - $iat) - 3600) -gt 10)') -and $text.Contains('if ([Math]::Abs($iat - $now) -gt 120)') -and $text.IndexOf('if ($bad.Count -gt 0) {', [StringComparison]::Ordinal) -lt $text.IndexOf('[System.IO.File]::WriteAllText', [StringComparison]::Ordinal))
  Check '$env: 대입 0 · 모드 정지점 = issue · clear(그 외 = 중단)' (@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.VariablePath.IsDriveQualified }, $true)).Count -eq 0 -and $text.Contains("@('issue', 'clear'))")) }
$o10Shape = { param($ast, $text)
  & $kubectlOne $ast $text "@('--kubeconfig', `$kc, 'create', 'token', 'agent-view', '-n', 'kube-system', '--duration=10m')"
  & $argsShape $ast $text '$kcs = @(Get-Command kubectl'
  $iK2 = $text.IndexOf("if (-not (& `$eq ([string]`$kcs[0].CommandType) 'Application')) { `$shadow +=", [StringComparison]::Ordinal)
  $iC2 = $text.IndexOf("if (-not (& `$eq ([string]`$ccs[0].CommandType) 'Application')) { `$shadow +=", [StringComparison]::Ordinal)
  $iSh2 = $text.IndexOf('if ($shadow.Count -gt 0) {', [StringComparison]::Ordinal)
  Check 'kubectl · curl.exe 첫 해석 판정(S-10) = 형식 필터 없는 Get-Command 둘 · CommandType 이 Application 아니면 멈춤 · 판정이 curl --version · 정지점 · kubectl 앞' ($text.Contains('$kcs = @(Get-Command kubectl -ErrorAction SilentlyContinue)') -and $text.Contains('$ccs = @(Get-Command curl.exe -ErrorAction SilentlyContinue)') -and $iK2 -ge 0 -and $iC2 -gt $iK2 -and $iSh2 -gt $iC2 -and $iSh2 -lt $text.IndexOf('$cv = @(curl.exe -q --version', [StringComparison]::Ordinal)) "kubectl $iK2 · curl $iC2 · 멈춤 $iSh2"
  Check '--audience 0(파일 전체 — audience 를 주지 않는다 = API 서버 기본 audience)' (-not $text.Contains('--audience'))
  $cc = @(Find-Cmd $ast 'curl.exe' | ForEach-Object { Cmd-Text $_ })
  $want = @('curl.exe -q --version', 'curl.exe -q -sS --max-time 20 -w $wfmt $url', "curl.exe -q -sS --max-time 20 --data-binary '@-' -w `$wfmt `$url", "curl.exe -q -sS --max-time 20 -X POST -H '@-' -w `$wfmt `$url")
  Check 'curl.exe 호출 = -q --version · GET · login(--data-binary ''@-'' — 본문 stdin) · revoke(-X POST -H ''@-'' — 헤더 stdin) 넷뿐' ($cc.Count -eq 4 -and @($want | Where-Object { $w = $_; @($cc | Where-Object { SEq $_ $w }).Count -eq 1 }).Count -eq 4) ($cc -join ' | ')
  Check '-w = ''\nT076-W code=%{http_code}\n'' 하나(응답 헤더 · Set-Cookie 0)' ($text.Contains("`$wfmt = '\nT076-W code=%{http_code}\n'") -and -not $text.Contains('%header{') -and -not $text.Contains('header_json'))
  Check 'Vault 주소 · 경로 리터럴 = http://127.0.0.1:18200(창 C) · /v1/sys/seal-status · /v1/auth/kubernetes/login · /v1/auth/token/revoke-self · cluster_name vault-cluster-d3b29227 · role e2e-reader' ($text.Contains("`$base = 'http://127.0.0.1:18200'") -and $text.Contains("& `$http 'get' `"`$base/v1/sys/seal-status`" `$null") -and $text.Contains("& `$http 'login' `"`$base/v1/auth/kubernetes/login`" `$body") -and $text.Contains("& `$http 'revoke' `"`$base/v1/auth/token/revoke-self`" `$hdr") -and $text.Contains("(& `$eq `$cn 'vault-cluster-d3b29227')") -and $text.Contains("`$body = '{`"role`":`"e2e-reader`",`"jwt`":`"' + `$jwt + '`"}'"))
  Check '로그인 본문을 만든 직후 $jwt = $null · 토큰 헤더 "X-Vault-Token: $ct" 를 만든 직후 $ct = $null · 둘 다 stdin 으로만' ($text.Contains("`$body = '{`"role`":`"e2e-reader`",`"jwt`":`"' + `$jwt + '`"}'`n    `$jwt = `$null") -and $text.Contains("`$hdr = `"X-Vault-Token: `$ct`"`n      `$ct = `$null"))
  $o = @(@('$kargs = @(', '$pl = & $payload $jwt', "& `$http 'get'", "& `$http 'login'", "& `$http 'revoke'") | ForEach-Object { $text.IndexOf($_, [StringComparison]::Ordinal) })
  Check '순서(파일 위치): kubectl → 클레임 판정 → seal-status → login → revoke' (@($o | Where-Object { $_ -lt 0 }).Count -eq 0 -and $o[0] -lt $o[1] -and $o[1] -lt $o[2] -and $o[2] -lt $o[3] -and $o[3] -lt $o[4]) ($o -join ' < ')
  Check '환경 변수 판정 = curl · TLS · 프록시 목록(T075 O-5 의 것에서 TF_* 를 뺀 글자)이 curl --version 보다 앞' ($text.Contains("@('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains `$_.Name") -and $text.IndexOf("'ALL_PROXY') -contains", [StringComparison]::Ordinal) -lt $text.IndexOf('curl.exe -q --version', [StringComparison]::Ordinal))
  Check '결과 머리 줄 = 「런북 bootstrap.md §4 T076 기록 칸에 그대로 기록」(rv2C-03 — O-10 기록 자리는 §4 기록 칸 1) · 「§3 T076 기록 칸」 글자 0' ($text.Contains('— 런북 bootstrap.md §4 T076 기록 칸에 그대로 기록) ---"') -and -not $text.Contains('§3 T076 기록 칸'))
  Check '$env: 대입 0 · 정지점 단어 probe(토큰 발급 앞)' ((@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Left.VariablePath.IsDriveQualified }, $true)).Count -eq 0) -and $text.Contains("받은 토큰을 바로 revoke)' 'probe'") -and ($text.IndexOf("revoke)' 'probe'", [StringComparison]::Ordinal) -lt $text.IndexOf('$out = @(kubectl @kargs', [StringComparison]::Ordinal))) }

# ---------------------------------------------------------------- 시나리오
$GateMsg = ''
try {
  Write-Host "=== T076 운영자 블록 모의 하네스(W-7 · O-9 · O-10) — 블록 디렉터리: $BlockDir · 범위: $(if ($OnlySel) { $OnlySel } else { '전체' }) ==="
  # 하네스 자체 전제(어긋나면 하네스 결함 → 예외): 가짜 서비스 토큰 꼴 · Hex-Lower 표준 벡터 · 모의 JWT 의 클레임 · aud 직렬화(배열 하나 = ["vault"])
  foreach ($k in @($TOKV.Keys)) { $sx = [string]$TOKV[$k]['client_secret']; if (-not [regex]::IsMatch($sx, '\A[0-9A-Za-z_-]{54}\z') -or [regex]::IsMatch($sx, '\A[0-9a-f]+\z') -or -not [regex]::IsMatch([string]$TOKV[$k]['client_id'], '\A[0-9a-f]{32}\.access\z')) { throw "하네스 결함: 가짜 서비스 토큰 꼴($k)" } }
  if (-not (SEq (Hex-Lower 'abc') 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')) { throw '하네스 결함: Hex-Lower 가 SHA-256 표준 벡터(abc)와 다르다' }
  $global:Jwts = [System.Collections.ArrayList]::new()
  $jp = (Jwt-ForCall ([pscustomobject]@{ aud = 'vault'; dur = '1h' })).Split('.')[1].Replace('-', '+').Replace('_', '/'); while ($jp.Length % 4) { $jp += '=' }
  $jtxt = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($jp))
  if (-not $jtxt.Contains('"aud":["vault"]') -or -not $jtxt.Contains('"sub":"system:serviceaccount:kube-system:agent-view"')) { throw "하네스 결함: 모의 JWT 클레임 꼴: $jtxt" }
  Reset-Mocks
  $W7S = '--- T076 W-7 tester-m2m kv 시드 결과'
  $O9S = '--- T076 O-9 결과'
  $O10S = '--- T076 O-10 음성 대조 결과'
  $TOK = $global:FAKE_ROOT
  $INFRA = [IO.Path]::GetFullPath((Join-Path $BlockDir '..\..\..\..\infra\cloudflare'))
  $global:BGate = @{}
  # ---- 정적 관문(블록마다 — FAIL 이면 그 블록의 런타임 시나리오는 실행하지 않는다)
  $CmdsBase = @('Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Remove-Item', 'Remove-Variable', 'Get-Command', 'ConvertFrom-Json', 'ConvertFrom-SecureString', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug',
    'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path')
  $CmdsOp = @('Read-Host', 'Write-Host', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Remove-Variable', 'Get-Command', 'ConvertFrom-Json', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug', 'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path', 'kubectl')
  $TypesBase = @('string', 'System.String', 'StringComparison', 'System.StringComparison', 'object', 'System.Object', 'Convert', 'System.Convert', 'System.Text.Encoding')
  $StatList = @(
    @('ST-W7', 'w7-seed-tester-m2m.ps1', (@($CmdsBase) + @('vault', 'ConvertTo-Json', 'tofu')), (@($TypesBase) + @('System.Security.Cryptography.SHA256', 'System.IO.Path')), @('stop', 'readSecret'),
      @('version', 'status -format=json', 'token lookup -format=json', 'kv metadata get', 'kv get -format=json', 'kv put'), 2, $true, $w7Shape, $RunW7),
    @('ST-O9', 'o9-issue-vault-jwt.ps1', (@($CmdsOp) + @('ConvertTo-SecureString', 'ConvertFrom-SecureString')), (@($TypesBase) + @('DateTimeOffset', 'Math', 'System.Math', 'System.IO.File', 'System.IO.Directory', 'System.IO.Path', 'System.Net.NetworkCredential')), @('pick'),
      @(), 1, $false, $o9Shape, $RunO9),
    @('ST-O10', 'o10-vault-audience-negative.ps1', (@($CmdsOp) + @('curl.exe')), (@($TypesBase) + @('DateTimeOffset', 'Math', 'System.Math', 'regex')), @('stop'),
      @(), 1, $false, $o10Shape, $RunO10))
  foreach ($s in $StatList) {
    if (-not $s[9]) { continue }
    $g = Run-Static -Id $s[0] -File $s[1] -Cmds $s[2] -Types $s[3] -Owners $s[4] -VSigs $s[5] -ReadHosts $s[6] -VaultEnv:([bool]$s[7]) -Extra $s[8]
    $global:BGate[$s[1]] = $g
    if ($g) { Write-Host "관문 FAIL($($s[0])): $g — 그 블록의 런타임 시나리오를 실행하지 않는다" -ForegroundColor Red } }
  Assert-Guard
  Write-Host ("가드: vault · kubectl · tofu(.exe 포함) · curl.exe · Read-Host · Set-PSDebug = 모의 함수 · 실물 디렉터리 {0}개를 PATH 에서 뺌 · 함정 디렉터리 맨 앞(표식 0 단언) · KUBECONFIG = 없는 경로 · LOCALAPPDATA = 함정 디렉터리 아래" -f $RealDirs.Count)
  $mlWhy = 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다'
  $home2 = { param($rel) Join-Path $HOME $rel }

  # ======================================================================= W-7
  if ($RunW7) {
  $AW = @{ vault = $true; tofu = $true }
  $okLine = "OK   $W7PATH v1 — 생성 · 되읽기 해시 일치(client_id·client_secret)"
  $w7Done = {
    $d = KvData $W7PATH
    Check "kv: $W7PATH v1 · 키 정확히 client_id · client_secret · 값 = tofu 의 tester-m2m(Ordinal)" ((KvCur $W7PATH) -eq 1 -and $null -ne $d -and @($d.Keys).Count -eq 2 -and (SEq $d['client_id'] $TM_ID) -and (SEq $d['client_secret'] $TM_SEC)) "cv=$(KvCur $W7PATH)"
    Check 'put 1회 · -cas=0 · stdin(-) · 경로 = kv/platform/access/tester-m2m' ($global:PutCalls.Count -eq 1 -and $global:PutCalls[0].cas -eq 0 -and $global:PutCalls[0].stdin -and (SEq $global:PutCalls[0].path $W7PATH))
    Check 'put 본문(JSON) = 키 정확히 client_id · client_secret · 값 문자열 · 줄바꿈 0' ($global:PutBodies.Count -eq 1 -and (SEq ((@(($global:PutBodies[0] | ConvertFrom-Json -AsHashtable).Keys) | Sort-Object) -join ',') 'client_id,client_secret') -and -not $global:PutBodies[0].Contains("`n"))
    $iPut = Ev-First 'vault:put:'; $iGet = Ev-Index "vault:kv-get:$W7PATH" ($iPut + 1); $iMeta = Ev-Index "vault:meta-get:$W7PATH" ($iGet + 1)
    Check '순서: tofu output → vault status → root 토큰 보안 입력 → token lookup → metadata get(판정) → seed 정지점 → put → kv get(되읽기) → metadata get(확인)' ((Ev-First 'tofu:output:') -ge 0 -and (Ev-First 'tofu:output:') -lt (Ev-Index 'vault:status') -and (Ev-Index 'vault:status') -lt (Ev-Index 'read:secure') -and (Ev-Index 'read:secure') -lt (Ev-Index 'vault:token-lookup') -and (Ev-Index 'vault:token-lookup') -lt (Ev-Index "vault:meta-get:$W7PATH") -and (Ev-Index "vault:meta-get:$W7PATH") -lt (Ev-Index 'read:plain') -and (Ev-Index 'read:plain') -lt $iPut -and $iPut -lt $iGet -and $iGet -lt $iMeta) ($global:Events -join ' > ') }
  $w7NoWrite = { Check '쓰기 0(kv put 0)' ($global:PutCalls.Count -eq 0 -and (Ev-First 'vault:put:') -lt 0) }
  $w7Before = { param([string]$why) Check "Vault 토큰을 묻기 전 중단($why) — 보안 입력 0 · vault status · token lookup · kv 0 · 쓰기 0" (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0 -and (Ev-Index 'vault:status') -lt 0 -and (Ev-Index 'vault:token-lookup') -lt 0 -and (Ev-First 'vault:meta-get:') -lt 0 -and (Ev-First 'vault:put:') -lt 0) }
  $w7TofuEnv = { $t = @($global:EnvAtCall | Where-Object { SEq $_.who 'tofu' }); Check 'tofu 호출 시점 env 에 VAULT_* 0(tofu 가 도는 동안 VAULT_TOKEN · VAULT_ADDR 없음)' ($t.Count -ge 1 -and @($t | Where-Object { @($_.names | Where-Object { ([string]$_).StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 }).Count -eq 0) "tofu 호출 $($t.Count)" }
  Run-Case 'W7-01' 'W-7 absent → 정지점 seed 뒤 put 1회(-cas=0 · JSON stdin · 키 정확히 둘) · 되읽기 해시 일치 · current_version 1 · w7=OK absent→v1 · 값 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu } -Inputs @($TOK, 'seed') `
    -Want @("OK   tofu 출력 service_tokens → tester-m2m 의 client_id · client_secret 꼴 확인(값 미출력 · 나머지 토큰은 버렸다)", "PLAN $W7PATH — absent → 생성 예정(키 client_id · client_secret · -cas=0) · 지금 v0", $okLine, 'w7=OK absent→v1') -NotWant @('STOP ', 'w7=STOP', 'w7=SKIP') `
    -Post { & $w7Done; & $w7TofuEnv
      Check 'tofu 호출 = version · output -json service_tokens 1회 · -chdir = 저장소 infra\cloudflare(블록 위치에서 찾음)' ($global:TofuCalls.Count -eq 1 -and (IEq $global:TofuCalls[0].chdir $INFRA) -and (Ev-Count 'tofu:version') -eq 1) "$($global:TofuCalls.Count) · $(if ($global:TofuCalls.Count) { $global:TofuCalls[0].chdir })"
      Check '입력 2(root 토큰 보안 입력 · seed 가려짐)' ($global:ReadLog.Count -eq 2 -and $global:ReadLog[0].secure -and $global:ReadLog[1].masked)
      Check '다른 토큰(web-bff · tester-k8s)의 Client ID · secret 은 kv · 화면에 0(tester-m2m 둘만 꺼낸다)' (@($TOKV.Keys | Where-Object { -not (SEq $_ 'tester-m2m') } | Where-Object { $global:LastText.Contains([string]$TOKV[$_]['client_id']) -or ($global:PutBodies -join '').Contains([string]$TOKV[$_]['client_secret']) }).Count -eq 0) }
  Run-Case 'W7-02' 'W-7 재실행(live 같음 — W7-01 뒤 상태) → 이미 있음 · 같음 · 쓰기 0 · seed 정지점 없음 · w7=SKIP live-same' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }) } -Inputs @($TOK) `
    -Want @("SKIP $W7PATH — 이미 있음 · 같음(v1 · 키 client_id · client_secret = tofu 의 tester-m2m · 값 · 해시 미출력 · 덮어쓰지 않는다)", 'w7=SKIP live-same') -NotWant @('STOP ', 'PLAN ') `
    -Post { & $w7NoWrite; Check '입력 1(seed 없음)' ($global:ReadLog.Count -eq 1); Check 'kv 그대로(v1)' ((KvCur $W7PATH) -eq 1) }
  foreach ($c in @(
      @('W7-03', 'live 다름(client_secret — 회전된 토큰)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = (Cf-Secret 'rotated') }); [void]$global:ExtraSecrets.Add((Cf-Secret 'rotated')) }, "STOP $W7PATH — live-different: client_secret 가 tofu 의 tester-m2m 과 다르다(회전 = T084 — 덮어쓰지 않는다 · 값 · 해시 미출력)"),
      @('W7-04', 'live 다름(client_id · client_secret 둘 — 다시 만든 토큰)', { Seed-Path $W7PATH ([ordered]@{ client_id = ((Hex-Lower 'cid-other').Substring(0, 32) + '.access'); client_secret = (Cf-Secret 'other') }); [void]$global:ExtraSecrets.Add((Cf-Secret 'other')) }, "STOP $W7PATH — live-different: client_id·client_secret 가 tofu 의 tester-m2m 과 다르다"),
      @('W7-05', 'live 키 여분(note)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC; note = 'x' }) }, "STOP $W7PATH — live-mismatch: 키 집합 불일치(누락: 없음 · 여분 1개)(값 미출력 · 사람 판단 — 덮어쓰지 않는다)"),
      @('W7-06', 'live 키 누락(client_secret 없음)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID }) }, "STOP $W7PATH — live-mismatch: 키 집합 불일치(누락: client_secret · 여분 0개)"),
      @('W7-07', 'dead(현재 버전 soft-delete)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }) 1 '2026-11-19T01:00:00Z' }, "STOP $W7PATH — dead — 현재 버전 1 에 deletion_time 이 있다(soft-delete 또는 삭제 예약)(사람 판단 — 되살리거나 지우지 않는다)"),
      @('W7-08', 'dead(현재 버전 destroy)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }) 1 '' $true }, "STOP $W7PATH — dead — 현재 버전 1 이 파기(destroy)됐다"),
      @('W7-09', 'dead(메타데이터만 · current_version=0)', { Seed-Path $W7PATH $null 0 }, "STOP $W7PATH — dead — current_version=0(메타데이터만 있고 버전이 없다)"),
      @('W7-10', '판정 불가(metadata 조회 500)', { $global:F['metaError'][$W7PATH] = 1 }, "STOP $W7PATH — 판정 불가 — metadata 조회 exit=2 · * context deadline exceeded"),
      @('W7-11', '판정 불가(live 인데 kv get 실패)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }); $global:F['readFail'][$W7PATH] = 1 }, "STOP $W7PATH — 판정 불가 — kv get exit=2(값을 읽지 못했다)"),
      @('W7-12', '판정 불가(live 인데 kv get 응답이 잘린 JSON — 안에 값)', { Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }); $global:F['readGarbage'][$W7PATH] = 1 }, "STOP $W7PATH — 판정 불가 — kv get 응답을 해석하지 못했다(원문 미출력)"))) {
    $script:w7Set = $c[2]
    Run-Case $c[0] "W-7 $($c[1]) → 판정 STOP · 쓰기 0 · seed 정지점 없음 · 값 미출력" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; & $script:w7Set } -Inputs @($TOK) -Expect '판정 단계에서 중단' `
      -Want @($c[3], 'w7=STOP 중단(') -Post { & $w7NoWrite; Check '입력 1(seed 없음)' ($global:ReadLog.Count -eq 1) } }
  # tofu 출력 꼴(T075 O5-09 · 09b–e 의 성질 + client_id 꼴): 아무것도 묻지 않고 · Vault 에 닿지 않고 중단
  $okS = Cf-Secret 'shape-ok'
  foreach ($c in @(
      @('W7-13', 'client_secret = 64 소문자 hex(옛 꼴 — 일부러 거부)', (Tok-With -csec (Hex-Lower 'MOCK-secret-hex64')), @((Hex-Lower 'MOCK-secret-hex64'))),
      @('W7-14', 'client_secret = 53자(짧음)', (Tok-With -csec $okS.Substring(0, 53)), @($okS.Substring(0, 53))),
      @('W7-15', 'client_secret = 맞는 54자 + 끝 LF(\z 고정)', (Tok-With -csec ($okS + "`n")), @($okS)),
      @('W7-16', 'client_secret = 54자 가운데 CR(유효 26 + CR + 유효 27)', (Tok-With -csec ($okS.Substring(0, 26) + "`r" + $okS.Substring(26, 27))), @($okS.Substring(0, 26), $okS.Substring(26, 27))),
      @('W7-17', 'client_secret = 맞는 53자 + U+212A(Kelvin — -c 고정)', (Tok-With -csec ($okS.Substring(0, 53) + [string][char]0x212A)), @($okS.Substring(0, 53))),
      @('W7-18', 'client_id = 대문자 hex(꼴 아님)', (Tok-With -cid (((Hex-Lower 'cid-upper').Substring(0, 32)).ToUpperInvariant() + '.access')), @()),
      @('W7-19', 'tester-m2m 키 없음(출력에 토큰 셋뿐)', (Tok-With -Drop), @()))) {
    $script:w7Tok = $c[2]; $script:w7Extra = @($c[3])
    Run-Case $c[0] "W-7 tofu 출력 꼴 아님 — $($c[1]) → Vault 토큰을 묻기 전 중단 · Vault 0 · 쓰기 0 · 값 미출력" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
      -Setup { Seed-Tofu -tok $script:w7Tok; foreach ($x in $script:w7Extra) { [void]$global:ExtraSecrets.Add([string]$x) } } -Inputs @($TOK, 'seed') -Expect '자격을 꺼내지 못했다' `
      -Want @('w7=STOP 미실행(자격 꼴 아님 — tofu 출력에서 tester-m2m 을 꺼내지 못했다 · Vault 토큰을 묻지 않았다 · 쓰기 0)') -Post { & $w7Before '자격 꼴' } }
  Run-Case 'W7-20' 'W-7 tofu output 실패(exit 1) → Vault 토큰을 묻기 전 중단 · 오류 문구는 내지 않는다(sensitive 출력)' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:F['tofuFail'] = 1 } -Inputs @($TOK) -Expect '자격을 꺼내지 못했다' `
    -Want @('tofu output exit=1') -NotWant @('No outputs found') -Post { & $w7Before 'tofu 실패' }
  Run-Case 'W7-21' 'W-7 put 응답 유실(서버 커밋 · CLI exit 2 · 자기 CAS 충돌) → 재판정 live v1 · 되읽기 해시 일치 = 기록됨(응답 유실 — 이 실행의 값) · w7=OK absent→v1' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['putLost'][$W7PATH] = 1 } -Inputs @($TOK, 'seed') `
    -Want @("OK   $W7PATH v1 — 기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=2 뒤 재판정) · 되읽기 해시 일치(client_id·client_secret)", 'w7=OK absent→v1 · 응답 유실 뒤 재판정') -NotWant @('STOP ') `
    -Post { & $w7Done; Check 'put 1회(다시 보내지 않았다) · put 과 되읽기 사이에 값 없는 재판정(metadata get) 1회' ($global:PutCalls.Count -eq 1 -and (Ev-Index "vault:meta-get:$W7PATH" ((Ev-First 'vault:put:') + 1)) -lt (Ev-Index "vault:kv-get:$W7PATH" ((Ev-First 'vault:put:') + 1))) }
  Run-Case 'W7-22' 'W-7 put 거부(403 · 경로 그대로 absent) → 재판정 current_version 그대로 = 쓰지 않았다 · STOP' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['putFail'][$W7PATH] = 2 } -Inputs @($TOK, 'seed') -Expect '쓰기 거부' `
    -Want @("STOP $W7PATH — 쓰기 거부(exit=2) · 재판정 current_version 그대로 = 쓰지 않았다", 'w7=STOP 중단(쓰기 거부 exit=2 — 재판정 current_version 그대로 · 쓰지 않았다)') -Post { Check 'kv 경로 없음' (-not $global:Kv.ContainsKey($W7PATH)) }
  $script:raceVal = [ordered]@{ client_id = $TM_ID; client_secret = (Cf-Secret 'race') }
  Run-Case 'W7-23' 'W-7 CAS 충돌(판정 뒤 다른 기록자가 v1 을 썼다 — 응답 유실과 같은 문구) → 재판정 v1 인데 되읽기 값이 다르다 = CAS 충돌 STOP · 덮어쓰기 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['putRace'][$W7PATH] = 1; $global:RaceData[$W7PATH] = $script:raceVal; [void]$global:ExtraSecrets.Add([string]$script:raceVal['client_secret']) } -Inputs @($TOK, 'seed') -Expect 'CAS 충돌' `
    -Want @("STOP $W7PATH — 쓰기 거부(exit=2) · CAS 충돌(다른 값 — 해시 불일치(client_secret)", 'w7=STOP 중단(쓰기 거부 exit=2 — 재판정 v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)') `
    -Post { Check 'kv = 다른 기록자의 v1 그대로' ((KvCur $W7PATH) -eq 1 -and (SEq (KvData $W7PATH)['client_secret'] $script:raceVal['client_secret'])) }
  Run-Case 'W7-24' 'W-7 저장 때 값 변형(tamper secret) → 되읽기 해시 불일치 STOP' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['tamper'][$W7PATH] = 'secret' } -Inputs @($TOK, 'seed') -Expect '되읽기 불일치' `
    -Want @("STOP $W7PATH — 되읽기 불일치(해시 불일치(client_secret) — 값 · 해시는 출력하지 않는다)", 'w7=STOP 기록됨 — 되읽기 불일치(해시 불일치(client_secret)) · 수동 확인')
  Run-Case 'W7-25' 'W-7 저장 때 키 여분(tamper extraKey) → 되읽기 키 집합 불일치 STOP' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['tamper'][$W7PATH] = 'extraKey' } -Inputs @($TOK, 'seed') -Expect '되읽기 불일치' -Want @("STOP $W7PATH — 되읽기 불일치(키 집합 불일치(누락: 없음 · 여분 1개)")
  Run-Case 'W7-26' 'W-7 쓰기 뒤 메타데이터가 current_version 2(다른 기록자) → 메타데이터 확인 실패 STOP' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['postMeta'][$W7PATH] = 'cv2' } -Inputs @($TOK, 'seed') -Expect '메타데이터 확인 실패' `
    -Want @("STOP $W7PATH — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(live · current_version=2)", 'w7=STOP 기록됨 — 메타데이터 확인 실패(live · current_version=2 · 기대 1)')
  Run-Case 'W7-27' 'W-7 쓰기 뒤 메타데이터 조회 500 → 재판정 불가 = 메타데이터 확인 실패 STOP(기록됨 — 단정하지 않는다)' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['postMeta'][$W7PATH] = 'err' } -Inputs @($TOK, 'seed') -Expect '메타데이터 확인 실패' -Want @('w7=STOP 기록됨 — 메타데이터 확인 실패(error · current_version=-1 · 기대 1)')
  Run-Case 'W7-28' 'W-7 put 도중 중단(서버 커밋 · Ctrl+C 대용) → 요약 = 결과 미확인 · 재실행 안내' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; $global:F['putInterrupt'][$W7PATH] = 1 } -Inputs @($TOK, 'seed') -Expect '모의 중단' `
    -Want @('w7=STOP 결과 미확인(쓰기 진행 중 중단 — kv 에 새 버전이 있을 수 있다 · 재실행이 판정한다)', '결과 미확인 = 쓰기 도중 중단 또는 비 0 뒤 재판정 불가')
  Run-Case 'W7-29' 'W-7 재실행 복구: W7-28 뒤 상태(v1 = 그 실행의 값) → 이미 있음 · 같음 · 쓰기 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S `
    -Setup { Seed-Tofu; Seed-Path $W7PATH ([ordered]@{ client_id = $TM_ID; client_secret = $TM_SEC }) } -Inputs @($TOK) -Want @('w7=SKIP live-same') -Post { & $w7NoWrite }
  Run-Case 'W7-30' 'W-7 seed 대신 다른 단어(SEED) → 쓰기 0 · 미실행(쓰기 확인 정지점)' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu } -Inputs @($TOK, 'SEED') -Expect '정지점에서 중단' `
    -Want @('w7=STOP 미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)') -Post { & $w7NoWrite; Check 'kv 경로 없음' (-not $global:Kv.ContainsKey($W7PATH)) }
  Run-Case 'W7-31' 'W-7 root 토큰 자리에 hvs. 꼴이 아닌 값 → Vault 로 보내지 않는다 · token lookup 0 · 쓰기 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; [void]$global:ExtraSecrets.Add('MOCK-not-a-token-value') } -Inputs @('MOCK-not-a-token-value', 'seed') `
    -Expect '입력이 Vault 토큰 형식' -Post { Check 'token lookup 0 · metadata 0 · 쓰기 0' ((Ev-Index 'vault:token-lookup') -lt 0 -and (Ev-First 'vault:meta-get:') -lt 0); & $w7NoWrite }
  Run-Case 'W7-32' 'W-7 root 가 아닌 토큰(정책 default 뿐) → 쓰기 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:TokenPolicies = @('default') } -Inputs @($TOK, 'seed') -Expect '토큰 정책에 root 가 없다' -Post { & $w7NoWrite }
  Run-Case 'W7-33' 'W-7 틀린 토큰(403) → token lookup 실패 · 쓰기 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu } -Inputs @($global:FAKE_WRONG, 'seed') -Expect 'root 토큰 확인 실패(token lookup exit=2)' -Post { & $w7NoWrite }
  Run-Case 'W7-34' 'W-7 Vault sealed → root 토큰을 묻기 전 중단(tofu 는 이미 읽었다 — 값은 변수에서 버린다)' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:F['status'] = 'sealed' } -Inputs @($TOK) -Expect 'Vault sealed' `
    -Post { Check '보안 입력 0 · 쓰기 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0); & $w7NoWrite }
  Run-Case 'W7-35' 'W-7 Vault 도달 실패(창 C 없음) → root 토큰을 묻기 전 중단' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:F['status'] = 'down' } -Inputs @($TOK) -Expect 'Vault 도달 실패' `
    -Post { Check '보안 입력 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0) }
  Run-Case 'W7-36' 'W-7 Vault status 의 type · version 에 터미널 제어열 → OK 줄은 ? 로 · 시드는 정상' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:F['status'] = 'ctrl' } -Inputs @($TOK, 'seed') `
    -Want @('OK   Vault 도달 · 초기화됨 · unsealed · cluster_name = vault-cluster-d3b29227(seal type=ocikms?[2J · server 2.0.4?]52;c;QUJD?)', 'w7=OK absent→v1') -Post { & $w7Done }
  Run-Case 'W7-37' 'W-7 ~/.vault-token 있음 → 아무것도 묻기 · 읽기 전에 중단' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:VaultTokenFile = $true } -Inputs @($TOK) -Expect '~/.vault-token 존재' `
    -Post { Check '입력 0 · vault · tofu 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) }
  Run-Case 'W7-38' 'W-7 클립보드 기록 켜짐 → 아무것도 묻기 · 읽기 전에 중단' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:ClipHistory = 1 } -Inputs @($TOK) -Expect '클립보드 기록이 켜져 있음' `
    -Post { Check '입력 0 · vault · tofu 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) }
  foreach ($c in @(@('W7-39', 'VAULT_TOKEN', $global:FAKE_ROOT, 'VAULT_TOKEN'), @('W7-40', 'VAULT_ADDR', 'https://vault.joshuatech.dev', 'VAULT_ADDR'), @('W7-41', 'VAULT_NAMESPACE', 'admin', 'VAULT_NAMESPACE'))) {
    Run-Case $c[0] "W-7 이 창에 $($c[1]) 가 이미 있음 → 건드리지 않고 아무것도 묻기 · 읽기 전에 중단" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu } -PreEnv @{ $c[1] = $c[2] } -Inputs @($TOK) `
      -Expect "이 창에 VAULT_* 환경 변수가 이미 있다: $($c[3])" -Post { Check '입력 0 · vault · tofu 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  foreach ($c in @(@('W7-42', 'TF_LOG', 'TRACE'), @('W7-43', 'TF_CLI_ARGS_output', '-no-color'), @('W7-44', 'TF_WORKSPACE', 'other'), @('W7-45', 'TF_DATA_DIR', 'C:\elsewhere'),
      @('W7-46', 'HTTPS_PROXY', 'http://127.0.0.1:8888'), @('W7-47', 'https_proxy', 'http://127.0.0.1:8889'), @('W7-48', 'ALL_PROXY', 'socks5://127.0.0.1:1080'), @('W7-49', 'SSL_CERT_FILE', 'C:\other-ca.pem'), @('W7-50', 'SSLKEYLOGFILE', 'C:\keylog.txt'))) {
    Run-Case $c[0] "W-7 환경 변수 $($c[1]) 있음 → tofu 를 부르기 전 · 아무것도 묻기 전에 중단 · 이름만 낸다" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu } -PreEnv @{ $c[1] = $c[2] } -Inputs @($TOK) `
      -Expect "이 창에 tofu · TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($c[1])" -NotWant @($c[2]) -Post { Check 'tofu · vault 호출 0 · 입력 0' ($global:XArgv.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:ReadLog.Count -eq 0) } }
  foreach ($c in @(@('W7-51', 'Utility 실효 켜짐(-SettingsFile 꼴)', { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }), @('W7-52', '시스템 powershell.config.json 에 ModuleLogging', { $global:CfgText['system'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":true}}}' }),
      @('W7-53', 'Core 스냅인만 켜짐(-SettingsFile 의 Core 대상 정책)', { $global:CoreLog = $true }), @('W7-54', 'Management 모듈 확인 불가', { $global:ModMissing = @('Microsoft.PowerShell.Management') }))) {
    $script:mlSet = $c[2]
    Run-Case $c[0] "W-7 모듈 로깅 — $($c[1]) → 아무것도 묻기 · 부르기 전에 중단" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; & $script:mlSet } -Inputs @($TOK) -Expect $mlWhy `
      -Post { Check '입력 0 · vault · tofu 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  Run-Case 'W7-55' 'W-7 모듈 로깅 정책 레지스트리(PowerShellCore HKLM) 켜짐 → 아무것도 묻기 · 부르기 전에 중단' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:Policy['HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging'] = @{ EnableModuleLogging = 1 } } -Inputs @($TOK) `
    -Expect 'PowerShell 모듈 로깅 정책이 켜져 있다' -Post { Check '입력 0 · vault · tofu 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) }
  Run-Case 'W7-56' 'W-7 붙여넣기 실행 → 파일로만(첫 검사) · 아무것도 읽지 않는다 · 블록 밖 범위에 새 변수 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Paste -Setup { Seed-Tofu } -Inputs @($TOK) -Expect '파일로만 실행한다' `
    -Post { Check 'tofu · vault 호출 0 · 입력 0' ($global:XArgv.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:ReadLog.Count -eq 0) }
  Run-Case 'W7-57' 'W-7 블록 파일이 저장소 밖(infra\cloudflare\outputs.tf 없음) → 아무것도 읽지 않는다' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:InfraOk = $false } -Inputs @($TOK) -Expect 'infra/cloudflare 를 찾지 못했다' `
    -Post { Check 'tofu · vault 호출 0' ($global:XArgv.Count -eq 0 -and $global:ArgvLog.Count -eq 0) }
  $script:hv = & $home2 'tools\vault.exe'; $script:ht = & $home2 'tools\tofu.exe'
  Run-Case 'W7-58' 'W-7 vault · tofu 가 사용자 홈 아래 → INFO 줄 두 경로 모두 ~ 로 · 화면에 홈 경로 0' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:FakeSrc['vault'] = $script:hv; $global:FakeSrc['tofu'] = $script:ht } -Inputs @($TOK, 'seed') `
    -Want @('INFO vault CLI: Vault v0.0.0-MOCK (harness) · Application ~\tools\vault.exe · tofu OpenTofu v0.0.0-MOCK · Application ~\tools\tofu.exe —', 'w7=OK absent→v1') -NotWant @($HOME)
  # 남는 인자(T076 r1 — S-07 · C-02 · RO-02): 블록 파일을 이 프로세스에서 & <경로> <인자> → 아무것도 묻지 · 읽지 않고 STOP(정지점 0 · vault · tofu 0 · 외부 이름 질의 0) · 값 미출력
  $w7NoTouch = { Check '정지점 0 · vault · tofu 호출 0 · 외부 이름 질의(Get-Command) 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0 -and (Ev-First 'gc:') -lt 0) }
  foreach ($c in @(@('W7-59', @('-Clear'), 1), @('W7-60', @('issue'), 1), @('W7-61', @('아무 글자', $ARGVAL), 2))) {
    Run-Case $c[0] "W-7 파일 실행에 남는 인자 $($c[2])개($(@($c[1])[0]) …) → 아무것도 묻지 · 읽지 않고 STOP · 값 미출력" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -ArgList $c[1] `
      -Setup { Seed-Tofu; [void]$global:ExtraFulls.Add($ARGVAL) } -Inputs @($TOK, 'seed') -Expect "남는 인자 $($c[2])개" `
      -Want @("w7=STOP 인자 $($c[2])개(값 미출력 — 이 블록은 인자를 받지 않는다 · 입력은 정지점 root 토큰 · seed 뿐) — 미실행(아무것도 묻지 · 읽지 않았다 · 쓰기 0)") -NotWant @('아무 글자') -Post { & $w7NoTouch } }
  Run-Case 'W7-62' 'W-7 붙여넣기 · 하네스 $args = $null(전역 범위 붙여넣기의 $script:args 꼴) → 인자 0 으로 본다 · 파일로만 검사에서 멈춘다(인자 STOP 아님)' 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Paste -NullArgs `
    -Setup { Seed-Tofu } -Inputs @($TOK) -Expect '파일로만 실행한다' -NotWant @('w7=STOP 인자') -Post { Check 'tofu · vault 호출 0 · 입력 0' ($global:XArgv.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:ReadLog.Count -eq 0) }
  # 외부 명령 첫 해석(T076 r1 — S-10): tofu · vault 가 같은 이름의 함수 · 별칭 · 스크립트로 가려짐 → 아무것도 읽지 않고 STOP(tofu · vault 0 · 정지점 0)
  foreach ($c in @(@('W7-63', @{ tofu = 'Function' }, 'tofu → Function'), @('W7-64', @{ vault = 'Alias' }, 'vault → Alias'), @('W7-65', @{ tofu = 'ExternalScript'; vault = 'Function' }, 'tofu → ExternalScript · vault → Function'))) {
    $script:w7Gc = $c[1]
    Run-Case $c[0] "W-7 첫 해석 가림($($c[2])) → tofu · vault 0 · 정지점 0 · STOP" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; foreach ($k in @($script:w7Gc.Keys)) { $global:CmdShape[$k] = $script:w7Gc[$k] } } -Inputs @($TOK, 'seed') `
      -Expect '첫 해석이 실행 파일(Application)이 아니다' -Want @("w7=STOP 미실행(첫 해석이 실행 파일이 아니다: $($c[2]) — 같은 이름의 함수 · 별칭 · 프로필 정의 · 아무것도 읽지 않았다 · 쓰기 0)") `
      -Post { Check 'tofu · vault 호출 0 · 입력 0' ($global:XArgv.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:ReadLog.Count -eq 0) } }
  # cluster_name(T076 r1 — S-09): vault status 뒤 · root 토큰을 묻기 전에 멈춘다(보안 입력 · token lookup · kv · 쓰기 0)
  $w7NoTok = { Check '보안 입력 0 · token lookup 0 · kv 0 · 쓰기 0(vault status 뒤 멈춤)' ($global:ReadLog.Count -eq 0 -and (Ev-Index 'vault:status') -ge 0 -and (Ev-Index 'vault:token-lookup') -lt 0 -and (Ev-First 'vault:meta-get:') -lt 0 -and (Ev-First 'vault:put:') -lt 0) }
  foreach ($c in @(@('W7-66', 'otherCluster', 'cluster_name 다름(다른 Vault)', 'vault-cluster-0ther999'), @('W7-67', 'noCluster', 'cluster_name 없음', '(없음)'), @('W7-68', 'ctrlCluster', 'cluster_name 에 터미널 제어열(OSC 52) → ? 로', 'vault-cluster-?]52;c;QUJD?'))) {
    $script:w7St = $c[1]
    Run-Case $c[0] "W-7 vault status $($c[2]) → root 토큰을 묻기 전 STOP · 쓰기 0" 'w7-seed-tester-m2m.ps1' -Allow $AW -Vault -Summary $W7S -Setup { Seed-Tofu; $global:F['status'] = $script:w7St } -Inputs @($TOK, 'seed') `
      -Expect 'Vault cluster_name 이 vault-cluster-d3b29227 이 아니다' -Want @("w7=STOP 미실행(Vault cluster_name = $($c[3]) — 기대 vault-cluster-d3b29227 · 창 C 가 다른 Vault 를 가리킨다 · root 토큰을 묻지 않았다 · 쓰기 0)") `
      -NotWant @('OK   Vault 도달') -Post { & $w7NoTok } }
  }

  # ======================================================================= O-9
  if ($RunO9) {
  $AK = @{ kubectl = $true }
  $o9Issued = { param([string]$jwt)
    $f = Lad-File
    Check '파일 = %LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt 하나 · 내용 = DPAPI 암호문(소문자 hex 만 · 평문 JWT 0)' ([IO.File]::Exists($f) -and ([IO.File]::ReadAllText($f, [Text.Encoding]::ASCII) -cmatch '\A[0-9a-f]+\z'))
    $back = $null; try { $back = Read-JwtFile $f } catch { $back = $null }
    Check 'O-8 꼴(ReadAllText(ASCII).Trim() | ConvertTo-SecureString → NetworkCredential.Password)로 복호 = 발급한 JWT(Ordinal)' (SEq $back $jwt)
    $back = $null
    $exp = [long](Jwt-Claims $jwt).exp
    $want = "o9 issued exp=$([DateTimeOffset]::FromUnixTimeSeconds($exp).UtcDateTime.ToString('s'))Z file=$(Tilde $f)"
    Check "끝 줄 = $want" ($global:LastText.Contains($want)) }
  $o9Kube = { param([string]$aud = 'vault', [string]$dur = '1h') Check "kubectl 1회 = --kubeconfig <관리자> create token agent-view -n kube-system --audience $aud --duration=$dur" ($global:KubeCalls.Count -eq 1 -and (SEq $global:KubeCalls[0].aud $aud) -and (SEq $global:KubeCalls[0].dur $dur) -and $global:KubeCalls[0].kc.EndsWith('\.kube\joshuatech-admin.yaml', [StringComparison]::Ordinal)) }
  Run-Case 'O9-01' 'O-9 issue → kubectl 1회(--audience vault --duration=1h) · 클레임 PASS · DPAPI 파일 생성 · O-8 꼴 복호 = 원래 JWT · o9 issued exp=<UTC> file=~\… · JWT 0(화면 · argv · 파일 평문 · 전역)' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S `
    -Inputs @('issue') -Files @($JWT_REL) -Want @('INFO aud 꼴=배열(VD-T076-10 관찰 — K3s TokenRequest 의 단일 audience 직렬화 · 문자열 "vault" · ["vault"] 둘 다 오직 vault)', 'OK   JWT 꼴 · aud = 오직 vault(문자열 "vault" 또는 원소 하나인 배열 ["vault"]) · sub = agent-view · 수명 3600 s · iat = 지금(값 미출력) — DPAPI 로 암호화해 파일에 쓴다', 'OK   새 파일 · 되읽기(O-8 꼴) 일치', '다음: 컨트롤러가 이 1시간 안에 tester 2차(O-8)를 디스패치한다') -NotWant @('o9=STOP', $HOME, 'INFO aud 꼴=문자열') `
    -Post { & $o9Kube; & $o9Issued ([string]$global:KubeIssued[0]); Check '입력 1(모드 — 가려짐)' ($global:ReadLog.Count -eq 1 -and $global:ReadLog[0].masked); Check '사례 전제: 모의 JWT payload 의 aud = ["vault"](배열 꼴)' ((Jwt-PayloadText ([string]$global:KubeIssued[0])).Contains('"aud":["vault"]')) }
  Run-Case 'O9-02' 'O-9 issue — 기존 파일(옛 JWT) 있음 → 덮어쓰기 · 복호 = 새 JWT(옛 JWT 아님)' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Files @($JWT_REL) `
    -Setup { Write-JwtFile (Make-Jwt -Aud ([string[]]@('vault')) -Tag 'old') } -Inputs @('issue') -Want @('(있음 — issue 는 덮어쓰고 clear 는 지운다)', 'OK   기존 파일을 덮어썼다 · 되읽기(O-8 꼴) 일치') `
    -Post { & $o9Issued ([string]$global:KubeIssued[0]); Check '옛 JWT 와 새 JWT 는 다르다(덮어쓰기 확인의 전제)' (-not (SEq $global:Jwts[0] $global:KubeIssued[0])) }
  $o9Stop = { param([string]$why) Check "파일 쓰기 0($why)" (-not [IO.File]::Exists((Lad-File))) }
  # 클레임 판정 실패(파일 쓰기 0): 열 = id · 설명 · 발급 함수 · 실패 사유 앞부분 · 사례 전제(모의 payload 원문 JSON 조각 — '' = 보지 않음) · aud 통과 여부($true = INFO aud 꼴=배열 · $false = INFO 0)
  #   aud(T076 r1 — B2 우려 · VD-T076-10): 문자열 "vault" · 원소 하나인 배열 ["vault"] 만 통과 — 원소 둘 · 빈 배열 · 다른 값 · 대소문자 · 숫자 · 객체 · 중첩 배열([string] 변환 함정) · null · 끝 공백 · 없음 = STOP
  $audWhy = '(문자열 "vault" 또는 원소 하나인 배열 ["vault"] 가 아니다 — Ordinal · 대소문자 구분)'
  foreach ($c in @(
      @('O9-03', 'aud 가 API 서버 기본(audience 를 잃은 발급)', { param($call) Make-Jwt -Aud $DEF_AUD -Life 3600 }, ('aud = ["https://kubernetes.default.svc.cluster.local", "k3s"]' + $audWhy), '"aud":["https://kubernetes.default.svc.cluster.local","k3s"]', $false),
      @('O9-04', 'aud = ["vault", "other"](원소 둘 — 여분)', { param($call) Make-Jwt -Aud ([string[]]@('vault', 'other')) -Life 3600 }, ('aud = ["vault", "other"]' + $audWhy), '"aud":["vault","other"]', $false),
      @('O9-05b', 'aud = 문자열 "Vault"(대소문자 다름 — Ordinal)', { param($call) Make-Jwt -Aud 'Vault' -Life 3600 }, ('aud = "Vault"' + $audWhy), '"aud":"Vault"', $false),
      @('O9-05c', 'aud = [](빈 배열)', { param($call) Make-Jwt -Aud ([string[]]@()) -Life 3600 }, ('aud = []' + $audWhy), '"aud":[]', $false),
      @('O9-05d', 'aud = ["Vault"](원소 하나 · 대소문자 다름)', { param($call) Make-Jwt -Aud ([string[]]@('Vault')) -Life 3600 }, ('aud = ["Vault"]' + $audWhy), '"aud":["Vault"]', $false),
      @('O9-05e', 'aud = 7(숫자)', { param($call) Make-Jwt -Aud 7 -Life 3600 }, ('aud = <Int64>' + $audWhy), '"aud":7', $false),
      @('O9-05f', 'aud = {"vault":"vault"}(객체)', { param($call) Make-Jwt -Aud ([ordered]@{ vault = 'vault' }) -Life 3600 }, ('aud = <PSCustomObject>' + $audWhy), '"aud":{"vault":"vault"}', $false),
      @('O9-05g', 'aud = [["vault"]](중첩 배열 — [string] 변환이면 vault 로 보이는 함정)', { param($call) Make-Jwt -Aud (, [string[]]@('vault')) -Life 3600 }, ('aud = [["vault"]]' + $audWhy), '"aud":[["vault"]]', $false),
      @('O9-05h', 'aud = null', { param($call) Make-Jwt -Aud $null -Life 3600 }, ('aud = null' + $audWhy), '"aud":null', $false),
      @('O9-05i', 'aud = 문자열 "vault "(끝 공백)', { param($call) Make-Jwt -Aud 'vault ' -Life 3600 }, ('aud = "vault "' + $audWhy), '"aud":"vault "', $false),
      @('O9-06', 'aud 없음', { param($call) Make-Jwt -NoAud -Life 3600 }, 'aud 없음', '', $false),
      @('O9-07', 'sub 다름(다른 SA — aud 는 통과)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Sub 'system:serviceaccount:kube-system:other' -Life 3600 }, 'sub = system:serviceaccount:kube-system:other(system:serviceaccount:kube-system:agent-view 가 아니다)', '"aud":["vault"]', $true),
      @('O9-08', '수명 8h(28800 s — 1h 가 아니다)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 28800 }, '수명 exp − iat = 28800 s(기대 3600 ± 10)', '"aud":["vault"]', $true),
      @('O9-09', '수명 3611 s(± 10 밖 — 경계)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 3611 }, '수명 exp − iat = 3611 s(기대 3600 ± 10)', '', $true),
      @('O9-10', '수명 600 s(10분 — 1h 가 아니다)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 600 }, '수명 exp − iat = 600 s(기대 3600 ± 10)', '', $true),
      @('O9-11', 'iat 가 지금보다 300 s 앞(시계 어긋남 · 오래된 토큰 — 초 경계로 -301 일 수 있다)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 3600 -Skew (-300) }, 'iat − 지금 = -30', '', $true),
      @('O9-12', 'exp 가 문자열(정수 아님)', { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 3600 -ExpOverride 'soon' }, 'exp · iat 가 정수가 아니다', '', $true))) {
    $script:o9Fn = $c[2]; $script:o9Raw = [string]$c[4]
    $audW = @(); $audN = @('INFO aud 꼴=문자열'); if ($c[5]) { $audW = @('INFO aud 꼴=배열(VD-T076-10 관찰') } else { $audN += 'INFO aud 꼴=' }
    Run-Case $c[0] "O-9 issue — $($c[1]) → 클레임 판정 실패 · 파일 쓰기 0 · JWT 미출력" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:KubeFn = $script:o9Fn } -Inputs @('issue') -Expect '클레임 판정 실패' `
      -Want (@("o9=STOP 클레임 판정 실패($($c[3])") + $audW) -NotWant $audN `
      -Post { & $o9Kube; & $o9Stop '클레임'; if ($script:o9Raw.Length -gt 0) { Check "사례 전제: 모의 JWT payload 원문에 $($script:o9Raw)" ((Jwt-PayloadText ([string]$global:KubeIssued[0])).Contains($script:o9Raw)) } } }
  Run-Case 'O9-05' 'O-9 issue — aud = 문자열 "vault"(RFC 7519 단일 꼴 · VD-T076-10 — 뜻이 같다) → 통과 · INFO aud 꼴=문자열 · issued · O-8 꼴 복호 = 발급 JWT' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Files @($JWT_REL) `
    -Setup { $global:KubeFn = { param($call) Make-Jwt -Aud 'vault' -Life 3600 } } -Inputs @('issue') `
    -Want @('INFO aud 꼴=문자열(VD-T076-10 관찰 — K3s TokenRequest 의 단일 audience 직렬화 · 문자열 "vault" · ["vault"] 둘 다 오직 vault)', 'OK   JWT 꼴 · aud = 오직 vault(문자열 "vault" 또는 원소 하나인 배열 ["vault"])', 'o9 issued exp=') -NotWant @('INFO aud 꼴=배열', 'o9=STOP') `
    -Post { & $o9Kube; & $o9Issued ([string]$global:KubeIssued[0]); Check '사례 전제: 모의 JWT payload 원문에 "aud":"vault"(문자열 꼴)' ((Jwt-PayloadText ([string]$global:KubeIssued[0])).Contains('"aud":"vault"')) }
  Run-Case 'O9-13' 'O-9 issue — 수명 3610 s(± 10 안 — 경계) → issued' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Files @($JWT_REL) -Setup { $global:KubeFn = { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Life 3610 } } -Inputs @('issue') -Want @('o9 issued exp=') `
    -Post { & $o9Issued ([string]$global:KubeIssued[0]) }
  Run-Case 'O9-14' 'O-9 issue — 기존 파일 + 클레임 실패(sub 다름) → 기존 파일 그대로(덮어쓰지 않는다)' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Files @($JWT_REL) `
    -Setup { $script:oldJwt = Make-Jwt -Aud ([string[]]@('vault')) -Tag 'old'; Write-JwtFile $script:oldJwt; $global:KubeFn = { param($call) Make-Jwt -Aud ([string[]]@('vault')) -Sub 'system:serviceaccount:default:default' -Life 3600 } } -Inputs @('issue') -Expect '클레임 판정 실패' `
    -Want @('— 파일 쓰기 0 · 기존 파일 그대로') -Post { Check '기존 파일 복호 = 옛 JWT 그대로' (SEq (Read-JwtFile (Lad-File)) $script:oldJwt) }
  foreach ($c in @(
      @('O9-15', 'JWT 꼴 아님(두 조각)', { param($call) 'MOCK-header.MOCK-payload' }, 'JWT 꼴이 아니다', 'o9=STOP JWT 꼴이 아니다(점 둘 · base64url 세 조각 · payload JSON — 값 미출력) — 파일 쓰기 0'),
      @('O9-16', 'payload 가 JSON 이 아님', { param($call) (B64U '{"alg":"RS256"}') + '.' + (B64U 'not json at all') + '.' + (Sig-For 'nonjson') }, 'JWT 꼴이 아니다', 'o9=STOP JWT 꼴이 아니다'),
      @('O9-17', 'kubectl 출력 두 줄', { param($call) @((Jwt-ForCall $call), (Jwt-ForCall $call)) }, 'kubectl 출력이 한 줄이 아니다', 'o9=STOP kubectl 출력이 한 줄이 아니다(2 줄 — 값 미출력) — 파일 쓰기 0'),
      @('O9-18', 'kubectl 출력 0줄', { param($call) @() }, 'kubectl 출력이 한 줄이 아니다', 'o9=STOP kubectl 출력이 한 줄이 아니다(0 줄 — 값 미출력)'))) {
    $script:o9Fn = $c[2]
    Run-Case $c[0] "O-9 issue — $($c[1]) → 파일 쓰기 0" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:KubeFn = $script:o9Fn } -Inputs @('issue') -Expect $c[3] -Want @($c[4]) -Post { & $o9Stop $c[1] } }
  Run-Case 'O9-19' 'O-9 issue — kubectl 실패(exit 1 · forbidden) → 파일 쓰기 0 · 오류 첫 줄(정제)' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:KubeRc = 1 } -Inputs @('issue') -Expect 'kubectl create token 실패' `
    -Want @('o9=STOP kubectl create token 실패(exit=1 · error: failed to create token: serviceaccounts "agent-view" is forbidden) — 파일 쓰기 0') -Post { & $o9Stop 'kubectl 실패' }
  Run-Case 'O9-20' 'O-9 issue — kubectl 오류 문구에 터미널 제어열 → ? 로' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:KubeRc = 1; $global:KubeErr = 'error: x' + [char]27 + ']52;c;QUJD' + [char]7 } -Inputs @('issue') -Expect 'kubectl create token 실패' `
    -Want @('o9=STOP kubectl create token 실패(exit=1 · error: x?]52;c;QUJD?)')
  Run-Case 'O9-21' 'O-9 clear — 파일 있음 → 지운다 · o9 cleared · kubectl 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { Write-JwtFile (Make-Jwt -Aud ([string[]]@('vault')) -Tag 'old') } -Inputs @('clear') -Want @('o9 cleared') -NotWant @('o9=STOP') `
    -Post { Check '파일 없음 · kubectl 0' (-not [IO.File]::Exists((Lad-File)) -and $global:KubeCalls.Count -eq 0) }
  Run-Case 'O9-22' 'O-9 clear — 파일 없음 → o9 nothing-to-clear · kubectl 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Inputs @('clear') -Want @('o9 nothing-to-clear') -Post { Check 'kubectl 0' ($global:KubeCalls.Count -eq 0) }
  Run-Case 'O9-23' 'O-9 issue → clear 연쇄(같은 폴더) → 파일 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S `
    -Setup { $global:Inputs.Enqueue('issue'); try { & (Join-Path $BlockDir 'o9-issue-vault-jwt.ps1') *>&1 | Out-Null } catch { }
      if (-not [IO.File]::Exists((Lad-File))) { throw '연쇄 전제: issue 가 파일을 만들지 않았다' }
      foreach ($n in 'Prompts', 'ReadLog', 'Events', 'XArgv', 'KubeCalls', 'EnvAtCall') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
      $global:Inputs = [System.Collections.Queue]::new(); $global:Error.Clear() } -Inputs @('clear') -Want @('o9 cleared') -Post { Check '파일 없음' (-not [IO.File]::Exists((Lad-File))) }
  foreach ($c in @(@('O9-24', 'Issue'), @('O9-25', 'clear '), @('O9-26', ''))) {
    Run-Case $c[0] "O-9 모드 입력 「$($c[1])」 → 정지점 중단 · kubectl 0 · 파일 0(Ordinal)" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Inputs @($c[1]) -Expect '정지점에서 중단: 모드가 issue · clear 가 아니다' `
      -Want @('o9=STOP 판정 전 중단(위 오류 — kubectl 0 · 파일 쓰기 0)') -Post { Check 'kubectl 0' ($global:KubeCalls.Count -eq 0) } }
  Run-Case 'O9-27' 'O-9 관리자 kubeconfig 없음 → 묻기 전에 중단 · kubectl 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:AdminKc = $false } -Inputs @('issue') -Expect '관리자 kubeconfig 가' `
    -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) }
  Run-Case 'O9-28' 'O-9 LOCALAPPDATA 없음 → 묻기 전에 중단 · kubectl 0 · 파일 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -NoLad -Inputs @('issue') -Expect 'LOCALAPPDATA 가 없거나' `
    -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) }
  Run-Case 'O9-29' 'O-9 LOCALAPPDATA 가 상대 경로 → 묻기 전에 중단' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -NoLad -PreEnv @{ LOCALAPPDATA = 'relative\appdata' } -Inputs @('issue') -Expect 'LOCALAPPDATA 가 없거나' `
    -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) }
  foreach ($c in @(@('O9-30', 'HTTPS_PROXY', 'http://127.0.0.1:8888'), @('O9-31', 'all_proxy', 'socks5://127.0.0.1:1080'), @('O9-32', 'SSL_CERT_DIR', 'C:\other-ca-dir'))) {
    Run-Case $c[0] "O-9 환경 변수 $($c[1]) 있음 → kubectl 전 · 묻기 전에 중단 · 이름만" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -PreEnv @{ $c[1] = $c[2] } -Inputs @('issue') -Expect "이 창에 TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($c[1])" `
      -NotWant @($c[2]) -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) } }
  foreach ($c in @(@('O9-33', 'Security 실효 켜짐(ConvertTo-SecureString 이 사는 모듈)', { $global:ModLog['Microsoft.PowerShell.Security'] = $true }), @('O9-34', '사용자 설정 파일에 ModuleLogging(값 false 여도)', { $global:CfgText['user'] = '{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": false } } }' }),
      @('O9-35', 'Core 스냅인 확인 불가(ForEach-Object 없음)', { $global:CoreMissing = $true }))) {
    $script:mlSet = $c[2]
    Run-Case $c[0] "O-9 모듈 로깅 — $($c[1]) → 묻기 · kubectl 전에 중단" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { & $script:mlSet } -Inputs @('issue') -Expect $mlWhy `
      -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) } }
  Run-Case 'O9-36' 'O-9 붙여넣기 모드 — issue 정상 · 블록 밖 범위에 새 변수 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Paste -Files @($JWT_REL) -Inputs @('issue') -Want @('o9 issued exp=') -Post { & $o9Issued ([string]$global:KubeIssued[0]) }
  $script:hk = & $home2 'bin\kubectl.exe'
  Run-Case 'O9-37' 'O-9 kubectl 이 사용자 홈 아래 → INFO 줄 경로 ~ · JWT 파일 경로도 ~(홈 경로 0)' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Files @($JWT_REL) -Setup { $global:FakeSrc['kubectl'] = $script:hk } -Inputs @('issue') `
    -Want @('INFO kubectl Application ~\bin\kubectl.exe · kubeconfig ~\.kube\joshuatech-admin.yaml · JWT 파일 ', 'o9 issued exp=') -NotWant @($HOME)
  # 남는 인자(T076 r1 — S-07 · C-02 · RO-02): 블록 파일을 이 프로세스에서 & <경로> <인자> → STOP(정지점 0 · kubectl 0 · 외부 이름 질의 0) · 파일 그대로 · 값 미출력
  $o9NoTouch = { Check '정지점 0 · kubectl 0 · 외부 이름 질의(Get-Command) 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:XArgv.Count -eq 0 -and (Ev-First 'gc:') -lt 0) }
  foreach ($c in @(@('O9-38', @('-Clear'), 1), @('O9-39', @('issue'), 1), @('O9-40', @('아무 글자', $ARGVAL), 2))) {
    Run-Case $c[0] "O-9 파일 실행에 남는 인자 $($c[2])개($(@($c[1])[0]) …) → STOP · kubectl 0 · 정지점 0 · 파일 0 · 값 미출력" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -ArgList $c[1] `
      -Setup { [void]$global:ExtraFulls.Add($ARGVAL) } -Inputs @('issue') -Expect "남는 인자 $($c[2])개" `
      -Want @("o9=STOP 인자 $($c[2])개(모드는 정지점 단어 issue/clear — 인자를 받지 않는다 · 값 미출력) — kubectl 0 · 파일 그대로(쓰기 · 삭제 0) · 인자 없이 다시 실행해 정지점에 issue 또는 clear") -NotWant @('아무 글자') -Post { & $o9NoTouch } }
  Run-Case 'O9-41' 'O-9 기존 파일 + 인자 -Clear(r0 런북 꼴) → STOP · 파일을 지우지 않는다(복호 = 옛 JWT 그대로) · kubectl 0 · 정지점 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -ArgList @('-Clear') -Files @($JWT_REL) `
    -Setup { $script:oldJwt = Make-Jwt -Aud ([string[]]@('vault')) -Tag 'old'; Write-JwtFile $script:oldJwt } -Inputs @('clear') -Expect '남는 인자 1개' -Want @('o9=STOP 인자 1개(', '파일 그대로(쓰기 · 삭제 0)') `
    -Post { & $o9NoTouch; Check '기존 파일 복호 = 옛 JWT 그대로(지우지 않았다)' (SEq (Read-JwtFile (Lad-File)) $script:oldJwt) }
  Run-Case 'O9-42' 'O-9 붙여넣기 · 하네스 $args = $null(전역 범위 붙여넣기의 $script:args 꼴) → 인자 0 으로 본다 · issue 정상' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Paste -NullArgs -Files @($JWT_REL) -Inputs @('issue') `
    -Want @('o9 issued exp=') -NotWant @('o9=STOP') -Post { & $o9Issued ([string]$global:KubeIssued[0]) }
  # kubectl 첫 해석(T076 r1 — S-10): 같은 이름의 함수 · 별칭 · 스크립트로 가려짐 → STOP(정지점 0 · kubectl 0 · 파일 0) · 찾지 못함 → 중단
  foreach ($c in @(@('O9-43', 'Function'), @('O9-44', 'Alias'), @('O9-45', 'ExternalScript'))) {
    $script:o9Gc = $c[1]
    Run-Case $c[0] "O-9 kubectl 첫 해석 = $($c[1])(같은 이름 가림) → STOP · kubectl 0 · 정지점 0 · 파일 0" 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:CmdShape['kubectl'] = $script:o9Gc } -Inputs @('issue') `
      -Expect '첫 해석이 실행 파일(Application)이 아니다: kubectl' -Want @("o9=STOP 첫 해석이 실행 파일이 아니다: kubectl → $($c[1])(같은 이름의 함수 · 별칭 · 프로필 정의) — kubectl 0 · 파일 쓰기 0") `
      -Post { Check '정지점 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  Run-Case 'O9-46' 'O-9 kubectl 을 찾지 못함(PATH) → 묻기 전에 중단 · kubectl 0' 'o9-issue-vault-jwt.ps1' -Allow $AK -Summary $O9S -Setup { $global:CmdShape['kubectl'] = 'missing' } -Inputs @('issue') -Expect 'kubectl 을 찾을 수 없다' `
    -Post { Check '정지점 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) }
  }

  # ======================================================================= O-10
  if ($RunO10) {
  $AC = @{ kubectl = $true; curl = $true }
  $o10Sent = { param([int]$n)
    Check "로그인 POST $n 회 · role = e2e-reader · 본문 키 = jwt · role · jwt = 발급한 10분 토큰(stdin 으로만 — argv 0) · 로그인에 헤더 0" ($global:LoginCalls.Count -eq $n -and ($n -eq 0 -or ((SEq $global:LoginCalls[0].role 'e2e-reader') -and (SEq $global:LoginCalls[0].keys 'jwt,role') -and (SEq $global:LoginCalls[0].jwt $global:KubeIssued[0]) -and $global:LoginCalls[0].headers -eq 0)))
    if ($n -gt 0) { Check '순서: kubectl create token → seal-status GET → login POST' ((Ev-First 'kubectl:token:') -lt (Ev-First 'curl:get:/v1/sys/seal-status') -and (Ev-First 'curl:get:/v1/sys/seal-status') -lt (Ev-First 'curl:post:/v1/auth/kubernetes/login')) } }
  $o10Kube = { Check 'kubectl 1회 = create token agent-view -n kube-system --duration=10m(audience 없음)' ($global:KubeCalls.Count -eq 1 -and (SEq $global:KubeCalls[0].aud '') -and (SEq $global:KubeCalls[0].dur '10m')) }
  $o10NoRevoke = { Check 'revoke-self 0(받은 토큰 없음)' ($global:RevokeCalls.Count -eq 0) }
  Run-Case 'O10-01' 'O-10 거부(403 permission denied) → o10=PASS · 코드 · errors 첫 줄 · JWT 는 stdin 1회 · revoke 0' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Inputs @('probe') `
    -Want @('OK   agent-view 10분 토큰 — aud = [https://kubernetes.default.svc.cluster.local, k3s](vault 없음) · sub = agent-view · 수명 600 s · iat = 지금(값 미출력)', 'OK   Vault seal-status 200 · sealed = false · cluster_name = vault-cluster-d3b29227', 'o10=PASS 로그인 거부(코드 403 · permission denied) — audience 없는 agent-view 토큰은 e2e-reader 자격이 아니다(VD-T076-1)', '로그인 시도 1회') -NotWant @('o10=FAIL') `
    -Post { & $o10Kube; & $o10Sent 1; & $o10NoRevoke; Check '입력 1(probe — 가려짐)' ($global:ReadLog.Count -eq 1 -and $global:ReadLog[0].masked) }
  Run-Case 'O10-02' 'O-10 거부(400 invalid audience) → o10=PASS' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'reject400' } -Inputs @('probe') `
    -Want @('o10=PASS 로그인 거부(코드 400 · invalid audience (aud) claim: audience claim does not match any expected audience)') -Post { & $o10Sent 1; & $o10NoRevoke }
  Run-Case 'O10-03' 'O-10 통과(200 · client_token) → 그 자리에서 revoke-self 1회(토큰 헤더 stdin) · o10=FAIL · 정책 · 시드로 넘어가지 않는다 · 토큰 0(화면 · argv · env)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'pass' } -Inputs @('probe') `
    -Want @('o10=FAIL 로그인 통과(코드 200 · 정책 [default, e2e-reader] · lease 3600 s) — audience 없는 agent-view 토큰이 e2e-reader 자격이다 · revoke-self 204(취소됨) — 정책 apply · W-7 시드로 넘어가지 않는다(멈추고 컨트롤러 · 사용자에게 보고)') -NotWant @('o10=PASS') `
    -Post { & $o10Sent 1; Check 'revoke-self 1회 · 헤더 X-Vault-Token = 받은 토큰(stdin 한 줄) · 본문 0 · login 바로 뒤' ($global:RevokeCalls.Count -eq 1 -and $global:RevokeCalls[0].tokenOk -and $global:RevokeCalls[0].headers -eq 1 -and $global:RevokeCalls[0].body.Length -eq 0 -and (Ev-First 'curl:post:/v1/auth/token/revoke-self') -gt (Ev-First 'curl:post:/v1/auth/kubernetes/login')) }
  Run-Case 'O10-04' 'O-10 통과 + revoke 거부(403) → o10=FAIL · revoke-self 실패(코드 403 — 메모리에만 있었고 버렸다)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'pass'; $global:RevokeMode = 'deny' } -Inputs @('probe') `
    -Want @('revoke-self 실패(코드 403 — 토큰은 이 프로세스 메모리에만 있었고 버렸다 · lease 뒤 만료)', 'o10=FAIL 로그인 통과') -Post { Check 'revoke 1회' ($global:RevokeCalls.Count -eq 1) }
  Run-Case 'O10-05' 'O-10 통과 + revoke 연결 실패(curl 7) → o10=FAIL · revoke-self 실패(curl exit=7 …)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'pass'; $global:RevokeMode = 'down' } -Inputs @('probe') `
    -Want @('revoke-self 실패(curl exit=7 · curl: (7) Failed to connect to 127.0.0.1 port 18200', 'o10=FAIL 로그인 통과')
  Run-Case 'O10-06' 'O-10 4xx 인데 응답에 client_token(이상 응답) → 통과로 다룬다: revoke 1회 · o10=FAIL' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'pass403' } -Inputs @('probe') `
    -Want @('o10=FAIL 로그인 통과(코드 403') -Post { Check 'revoke 1회 · 토큰 일치' ($global:RevokeCalls.Count -eq 1 -and $global:RevokeCalls[0].tokenOk) }
  foreach ($c in @(
      @('O10-07', 'seal-status cluster_name 다름(다른 Vault — 창 C 가 다른 클러스터)', { $global:SealCluster = 'vault-cluster-0ther999' }, 'o10=FAIL 판정 불가(seal-status — 코드 200 · sealed = False · cluster_name = vault-cluster-0ther999'),
      @('O10-08', 'sealed = true', { $global:SealMode = 'sealed' }, 'o10=FAIL 판정 불가(seal-status — 코드 200 · sealed = True · cluster_name = vault-cluster-d3b29227'),
      @('O10-09', 'seal-status 연결 실패(창 C 없음 — curl 7)', { $global:SealMode = 'down' }, 'o10=FAIL 판정 불가(seal-status — curl exit=7 · curl: (7) Failed to connect'),
      @('O10-10', 'seal-status 본문이 JSON 이 아님', { $global:SealMode = 'garbage' }, 'o10=FAIL 판정 불가(seal-status — 코드 200 · sealed =  · cluster_name = '))) {
    $script:o10Set = $c[2]
    Run-Case $c[0] "O-10 $($c[1]) → JWT 0 전송(로그인 0) · o10=FAIL 판정 불가" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { & $script:o10Set } -Inputs @('probe') -Expect 'seal-status 판정 실패' `
      -Want @($c[3], '로그인 시도 0회') -Post { & $o10Kube; & $o10Sent 0; & $o10NoRevoke } }
  foreach ($c in @(
      @('O10-11', 'audience 없는 토큰에 vault 가 있다(배열)', { param($call) Make-Jwt -Aud ([string[]]@('https://kubernetes.default.svc.cluster.local', 'vault')) -Life 600 }, 'aud 에 vault 가 있다([https://kubernetes.default.svc.cluster.local, vault]) — 음성 대조가 성립하지 않는다'),
      @('O10-12', 'aud = 문자열 Vault(대소문자 무관으로 vault)', { param($call) Make-Jwt -Aud 'Vault' -Life 600 }, 'aud 에 vault 가 있다([Vault])'),
      @('O10-13', 'aud 없음', { param($call) Make-Jwt -NoAud -Life 600 }, 'aud 가 없거나 문자열(또는 문자열 배열)이 아니다'),
      @('O10-14', 'sub 다름', { param($call) Make-Jwt -Aud $DEF_AUD -Sub 'system:serviceaccount:kube-system:other' -Life 600 }, 'sub = system:serviceaccount:kube-system:other(system:serviceaccount:kube-system:agent-view 가 아니다)'),
      @('O10-15', '수명 3600 s(10분이 아니다)', { param($call) Make-Jwt -Aud $DEF_AUD -Life 3600 }, '수명 exp − iat = 3600 s(기대 600 ± 10)'),
      @('O10-16', 'iat 가 지금보다 600 s 뒤(시계 어긋남 — 초 경계로 599 일 수 있다)', { param($call) Make-Jwt -Aud $DEF_AUD -Life 600 -Skew 600 }, 'iat − 지금 = '),
      @('O10-17', 'JWT 꼴 아님', { param($call) 'MOCK-not-a-jwt' }, ''))) {
    $script:o10Fn = $c[2]
    $exp = 'FAIL 판정 불가(클레임 — '; if ($c[0] -ceq 'O10-17') { $exp = 'FAIL 판정 불가(JWT 꼴이 아니다' }
    Run-Case $c[0] "O-10 클레임 — $($c[1]) → seal-status · 로그인 0(JWT 0 전송) · o10=FAIL 판정 불가" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:KubeFn = $script:o10Fn; [void]$global:ExtraFulls.Add('MOCK-not-a-jwt') } -Inputs @('probe') `
      -Expect 'JWT 전송 0' -Want @("o10=$exp$($c[3])", '로그인 시도 0회') -Post { Check 'seal-status 0 · 로그인 0' ($global:CurlCalls.Count -eq 0 -and $global:LoginCalls.Count -eq 0) } }
  Run-Case 'O10-18' 'O-10 kubectl 실패(exit 1) → curl 0(버전 밖) · o10=FAIL 판정 불가' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:KubeRc = 1 } -Inputs @('probe') -Expect 'kubectl create token 실패' `
    -Want @('o10=FAIL 판정 불가(kubectl create token exit=1 · 출력 0 줄 · error: failed to create token') -Post { Check 'HTTP 0' ($global:CurlCalls.Count -eq 0) }
  foreach ($c in @(
      @('O10-19', '로그인 500', 'e500', 'o10=FAIL 판정 불가(로그인 응답 — 코드 500 · internal error · 받은 토큰 0)'),
      @('O10-20', '로그인 200 인데 auth 없음', 'noauth200', 'o10=FAIL 판정 불가(로그인 응답 — 코드 200 · (errors 없음) · 받은 토큰 0)'),
      @('O10-21', '로그인 200 · auth 는 있는데 client_token 없음', 'authNoToken', 'o10=FAIL 판정 불가(로그인 응답 — 코드 200 · (errors 없음) · 받은 토큰 0)'),
      @('O10-21b', '로그인 403 인데 auth 객체가 있다(client_token 없음 — 「4xx · auth 없음」이 아니다)', 'authNoToken403', 'o10=FAIL 판정 불가(로그인 응답 — 코드 403 · permission denied · 받은 토큰 0)'),
      @('O10-22', '로그인 응답 유실(curl 28 — 토큰이 발급됐는지 모른다)', 'lost', 'o10=FAIL 판정 불가(로그인 응답 — curl exit=28 · curl: (28) Operation timed out'))) {
    $script:o10Mode = $c[2]
    Run-Case $c[0] "O-10 $($c[1]) → o10=FAIL 판정 불가 · revoke 0" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = $script:o10Mode } -Inputs @('probe') -Want @($c[3]) -NotWant @('o10=PASS') -Post { & $o10Sent 1; & $o10NoRevoke } }
  Run-Case 'O10-23' 'O-10 거부 응답의 errors 에 터미널 제어열(OSC 52) → ? 로 · PASS' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'ctrl' } -Inputs @('probe') -Want @('o10=PASS 로그인 거부(코드 403 · permission denied?]52;c;QUJD?)')
  Run-Case 'O10-24' 'O-10 거부 응답의 errors 가 300자 → 160자 + … 로 자른다' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'long' } -Inputs @('probe') -Want @("o10=PASS 로그인 거부(코드 400 · $('x' * 160)…)")
  Run-Case 'O10-25' 'O-10 거부 응답이 JSON 이 아님(403 Forbidden) → PASS(본문 해석 불가)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:LoginMode = 'nonjson' } -Inputs @('probe') -Want @('o10=PASS 로그인 거부(코드 403 · (본문 해석 불가))')
  Run-Case 'O10-26' 'O-10 curl 7.83 → 아무것도 하기 전에 중단(kubectl · HTTP 0)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:CurlVersion = 'curl 7.83.1 (x86_64-pc-win32)' } -Inputs @('probe') -Expect 'curl 7.84 이상이 필요하다' `
    -Post { Check '입력 0 · kubectl 0 · HTTP 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:CurlCalls.Count -eq 0) }
  foreach ($c in @(@('O10-27', 'HTTPS_PROXY', 'http://127.0.0.1:8888'), @('O10-28', 'https_proxy', 'http://127.0.0.1:8889'), @('O10-29', 'HTTP_PROXY', 'http://127.0.0.1:8887'), @('O10-30', 'ALL_PROXY', 'socks5://127.0.0.1:1080'),
      @('O10-31', 'SSLKEYLOGFILE', 'C:\keylog.txt'), @('O10-32', 'CURL_CA_BUNDLE', 'C:\other-ca.pem'), @('O10-33', 'ssl_cert_file', 'C:\other-ca2.pem'))) {
    Run-Case $c[0] "O-10 환경 변수 $($c[1]) 있음 → 토큰 발급 · HTTP 전에 중단 · 이름만(대소문자 무관)" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -PreEnv @{ $c[1] = $c[2] } -Inputs @('probe') -Expect "이 창에 curl · TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($c[1])" `
      -NotWant @($c[2]) -Post { Check '입력 0 · kubectl 0 · curl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  foreach ($c in @(@('O10-34', 'Utility 실효 켜짐(ConvertFrom-Json 이 사는 모듈)', { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }), @('O10-35', '정책 레지스트리(HKCU PowerShellCore)', { $global:Policy['HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging'] = @{ EnableModuleLogging = 1 } }),
      @('O10-36', 'UseWindowsPowerShellPolicySetting=1 + Windows PowerShell 정책 켜짐', { $global:Policy['HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging'] = @{ UseWindowsPowerShellPolicySetting = 1 }; $global:Policy['HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging'] = @{ EnableModuleLogging = 1 } }))) {
    $script:mlSet = $c[2]
    Run-Case $c[0] "O-10 모듈 로깅 — $($c[1]) → 아무것도 하기 전에 중단" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { & $script:mlSet } -Inputs @('probe') -Expect '모듈 로깅' `
      -Post { Check '입력 0 · kubectl 0 · curl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  Run-Case 'O10-37' 'O-10 정지점 단어가 probe 가 아님(PROBE) → 토큰 발급 0 · HTTP 0(버전 밖)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Inputs @('PROBE') -Expect '정지점에서 중단' `
    -Want @('o10=FAIL 판정 불가(중단 — 위 오류 · JWT 전송 0)', '로그인 시도 0회') -Post { Check 'kubectl 0 · HTTP 0' ($global:KubeCalls.Count -eq 0 -and $global:CurlCalls.Count -eq 0) }
  Run-Case 'O10-38' 'O-10 관리자 kubeconfig 없음 → 묻기 전에 중단' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:AdminKc = $false } -Inputs @('probe') -Expect '관리자 kubeconfig 가' `
    -Post { Check '입력 0 · kubectl 0 · curl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:XArgv.Count -eq 0) }
  Run-Case 'O10-39' 'O-10 붙여넣기 모드 — 거부 → PASS · 블록 밖 범위에 새 변수 0' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Paste -Inputs @('probe') -Want @('o10=PASS 로그인 거부(코드 403 · permission denied)') -Post { & $o10Sent 1 }
  Run-Case 'O10-40' 'O-10 붙여넣기 모드 — 통과 → revoke · FAIL · 새 변수 0(토큰이 남는 범위 0)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Paste -Setup { $global:LoginMode = 'pass' } -Inputs @('probe') -Want @('o10=FAIL 로그인 통과') -Post { Check 'revoke 1회' ($global:RevokeCalls.Count -eq 1) }
  $script:hk2 = & $home2 'bin\kubectl.exe'; $script:hc2 = & $home2 'bin\curl.exe'
  Run-Case 'O10-41' 'O-10 kubectl · curl 이 사용자 홈 아래 → INFO 줄 두 경로 ~(홈 경로 0)' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { $global:FakeSrc['kubectl'] = $script:hk2; $global:FakeSrc['curl.exe'] = $script:hc2 } -Inputs @('probe') `
    -Want @('INFO curl 8.22 · Application ~\bin\curl.exe · kubectl Application ~\bin\kubectl.exe · Vault http://127.0.0.1:18200(창 C)') -NotWant @($HOME)
  # 남는 인자(T076 r1 — S-07 · C-02 · RO-02): 블록 파일을 이 프로세스에서 & <경로> <인자> → FAIL 판정 불가(정지점 0 · kubectl 0 · curl 0(--version 포함) · 외부 이름 질의 0) · 값 미출력
  $o10NoTouch = { Check '정지점 0 · kubectl 0 · curl 0(--version 포함) · 외부 이름 질의(Get-Command) 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:CurlCalls.Count -eq 0 -and $global:XArgv.Count -eq 0 -and (Ev-First 'gc:') -lt 0) }
  foreach ($c in @(@('O10-42', @('-Clear'), 1), @('O10-43', @('issue'), 1), @('O10-44', @('아무 글자', $ARGVAL), 2))) {
    Run-Case $c[0] "O-10 파일 실행에 남는 인자 $($c[2])개($(@($c[1])[0]) …) → FAIL 판정 불가 · 토큰 발급 0 · HTTP 0 · 정지점 0 · 값 미출력" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -ArgList $c[1] `
      -Setup { [void]$global:ExtraFulls.Add($ARGVAL) } -Inputs @('probe') -Expect "남는 인자 $($c[2])개" `
      -Want @("o10=FAIL 판정 불가(인자 $($c[2])개 — 값 미출력 · 이 블록은 인자를 받지 않는다(입력은 정지점 단어 probe 뿐) · 토큰 발급 0 · JWT 전송 0)", '로그인 시도 0회') -NotWant @('아무 글자') -Post { & $o10NoTouch } }
  Run-Case 'O10-45' 'O-10 붙여넣기 · 하네스 $args = $null(전역 범위 붙여넣기의 $script:args 꼴) → 인자 0 으로 본다 · 거부 → PASS' 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Paste -NullArgs -Inputs @('probe') `
    -Want @('o10=PASS 로그인 거부(코드 403 · permission denied)') -NotWant @('o10=FAIL') -Post { & $o10Sent 1 }
  # 첫 해석(T076 r1 — S-10): kubectl · curl.exe 가 같은 이름의 함수 · 별칭으로 가려짐 → FAIL 판정 불가(토큰 발급 0 · HTTP 0 — --version 포함 · 정지점 0)
  foreach ($c in @(@('O10-46', @{ kubectl = 'Function' }, 'kubectl → Function'), @('O10-47', @{ 'curl.exe' = 'Alias' }, 'curl.exe → Alias'), @('O10-48', @{ kubectl = 'Alias'; 'curl.exe' = 'Function' }, 'kubectl → Alias · curl.exe → Function'))) {
    $script:o10Gc = $c[1]
    Run-Case $c[0] "O-10 첫 해석 가림($($c[2])) → 토큰 발급 0 · HTTP 0(--version 포함) · 정지점 0 · FAIL 판정 불가" 'o10-vault-audience-negative.ps1' -Allow $AC -Summary $O10S -Setup { foreach ($k in @($script:o10Gc.Keys)) { $global:CmdShape[$k] = $script:o10Gc[$k] } } -Inputs @('probe') `
      -Expect '첫 해석이 실행 파일(Application)이 아니다' -Want @("o10=FAIL 판정 불가(첫 해석이 실행 파일이 아니다: $($c[2]) — 같은 이름의 함수 · 별칭 · 프로필 정의 · 토큰 발급 0 · JWT 전송 0)", '로그인 시도 0회') `
      -Post { Check '정지점 0 · kubectl 0 · curl 0(--version 포함)' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0 -and $global:CurlCalls.Count -eq 0 -and $global:XArgv.Count -eq 0) } }
  }
}
catch {
  if (-not $GateMsg) { throw }
}
finally {
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $env:PATH = $OrigPath
  if ($null -eq $OrigKubeconfig) { Remove-Item -LiteralPath Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $OrigKubeconfig }
  if ($null -eq $OrigLad) { Remove-Item -LiteralPath Env:LOCALAPPDATA -ErrorAction SilentlyContinue } else { $env:LOCALAPPDATA = $OrigLad }
  foreach ($k in @($NetEnvSaved.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value $NetEnvSaved[$k] }
  Remove-Item -LiteralPath $TrapDir -Recurse -Force -ErrorAction SilentlyContinue
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) }
}

# ---------------------------------------------------------------- 결과
Write-Host "`n=== 결과 ==="
foreach ($r in $Results) { Write-Host ("{0} {1,-7} ({2,3}/{3,3}) {4}{5}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.id, ($r.total - $r.failed), $r.total, $r.desc, $(if ($r.pass) { '' } else { "`n        ↳ " + $r.detail })) }
$cases = $Results.Count
$casePass = @($Results | Where-Object { $_.pass }).Count
$checks = 0; $checkFail = 0; foreach ($r in $Results) { $checks += $r.total; $checkFail += $r.failed }
Write-Host ("시나리오 PASS {0} / {1}" -f $casePass, $cases)
Write-Host ("PASS {0} / {1}   (단언 수 — 정적 관문 ST-W7 · ST-O9 · ST-O10 포함 · 실물 vault/kubectl/tofu 호출 0 가드)" -f ($checks - $checkFail), $checks)
Write-Host ("실행 시간 {0:N1}초" -f $Clock.Elapsed.TotalSeconds)
if ($casePass -ne $cases -or $checkFail -gt 0) { exit 1 }
exit 0
