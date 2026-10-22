param([string]$Show = '', [string]$Block = '', [string]$Runbook = '')
# ===== T054 OP1-DB 시드 블록(op1-seed-db.ps1) + 런북 「정리 판단」 두 블록(① 점검 · ② 삭제) — 모의 실행 하네스 =====
# 실물 Vault·클러스터에 닿지 않는다. 가드:
#   ⓪ S12 정적 검사를 맨 먼저 돌린다(블록을 실행하지 않는다) — 관문(파서 오류 0 · 명령 · 정적 형식 · $Host · 파일 리다이렉트 허용 목록)이 하나라도 FAIL 이면
#      런타임 시나리오를 하나도 돌리지 않고 exit 1(①②는 절대 경로 호출 · 프로세스 직접 기동을 막지 못한다 — 2026-10-14 리뷰 O8)
#   ① PowerShell 함수가 native 명령보다 우선하는 성질로 vault·kubectl(+ vault.exe·kubectl.exe·curl·curl.exe·oci·gh)을 모의 함수로 가린다
#   ② 실물 vault·kubectl 이 있는 디렉터리를 이 프로세스 PATH 에서 빼고 맨 앞에 함정 디렉터리(vault.cmd·kubectl.cmd — 불리면 표식 파일 + exit 97)를 둔다 ·
#      이 프로세스의 KUBECONFIG 를 없는 경로로 덮는다(운영자의 관리자 kubeconfig 를 상속하지 않는다 — 끝나면 복원)
#   ③ 블록을 돌리기 직전마다 ①②를 다시 확인하고(아니면 블록을 돌리지 않고 중단), 시나리오가 끝날 때마다 함정 표식 0 을 단언한다
# 그 밖의 모의: Read-Host(-AsSecureString · -MaskInput · 호출 시점의 화면 출력 수 기록) · Set-Clipboard(실패 결함 clipFail · 실물처럼 -WhatIf/ShouldProcess 를 따른다) ·
#   Get-Clipboard · Get-ItemProperty(클립보드 기록 설정 · PowerShell 모듈 로깅 정책 키 4) · Test-Path(~/.vault-token) · Set-PSDebug(-Off 만 허용 — 그 밖의 인자는 위반).
# 가짜 Vault = 메모리 kv v2(경로 → 버전 · 메타데이터 · soft-delete/destroy · CAS). kv put 은 stdin JSON 만 받는다(argv 값 = 위반).
# 모의 vault 는 허용 목록(version · status · token lookup · kv metadata get · kv get · kv put)만 답하고 그 밖은 전부 위반으로 기록한다
#   (kv metadata delete 는 런북 ② 삭제 블록 시나리오에서만 답한다 — 시드 블록 · ① 점검 블록이 부르면 위반).
# 가짜 값은 전부 MOCK 이 들어간 누가 봐도 가짜인 문자열이다 — 블록 파일에는 가짜 값이 하나도 없다(S12 가 검사).
# 호스트 UI 직접 쓰기($Host.UI.WriteLine 등)는 *>&1 로 잡히지 않는다 — 런타임 노출 검사의 사각이라 S12 정적 규칙($Host · $ExecutionContext 는 FlushInputBuffer 한 모양만)으로 막는다.
# 런북 블록(수정 라운드 4 — 리뷰 r3 O7 · 컨트롤러 결정 C6): docs/runbooks/bootstrap.md §4 T054 「정리 판단」의 ① 점검(읽기 전용) · ② 삭제 블록을
#   코드 펜스에서 그대로 추출해(표식 [t054-cleanup-inspect] · [t054-cleanup-delete]) 같은 모의 vault/Read-Host 로 돌린다 —
#   R1 · R2(정적 · 관문 6: 추출 · 파서 · 명령 · 정적 형식 · $Host · 리다이렉트) → GA01–GA08(① 점검 10개 — vault 쓰기 명령 0 단언 · GA08 = kv get 응답이 깨진 JSON) · GB01–GB12(② 삭제 — 6경로 허용 목록 Ordinal ·
#   경로 타자 재입력 · 삭제 뒤 No value found 확인 · 조회/삭제 실패 · 잔존 · 삭제 뒤 조회 오류 → 중단). 관문이 FAIL 인 런북 블록은 런타임 시나리오에서 한 번도 실행하지 않는다.
#   두 블록은 첫 Read-Host 전에 클립보드를 공백으로 덮는다(수정 라운드 6 — 리뷰 r6 S1/O1 = r4 O5: §0 절대 규칙 1 로 붙인 root 토큰이 클립보드에 남은 채 평문 프롬프트에 오붙임되는 경로) —
#   R1 · R2 가 문장을, Run-RbCase 공통 단언이 순서(clip:set < read:plain)와 값(공백만)을 고정한다.
# 사용: pwsh -NoProfile -File specs/003-platform-foundation/design/t054-blocks/harness.ps1
#       [-Show 'S01*'] 해당 시나리오의 화면 출력 표시 · [-Block <경로>] 다른 블록 파일(변이 사본)에 같은 시나리오를 돌린다 ·
#       [-Runbook <경로>] 다른 런북 파일(변이 사본)에서 「정리 판단」 두 블록을 추출한다
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockPath = if ([string]::IsNullOrEmpty($Block)) { Join-Path $here 'op1-seed-db.ps1' } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Block) }
# $here 는 절대 경로다 — GetFullPath 는 .. 만 정리한다(.NET cwd 에 기대지 않는다)
$RunbookPath = if ([string]::IsNullOrEmpty($Runbook)) { [IO.Path]::GetFullPath((Join-Path $here '..\..\..\..\docs\runbooks\bootstrap.md')) } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Runbook) }
# 세션 설정 원래 값(S10e 가 바꾼다 — Reset-Mocks 가 시나리오마다 되돌린다). $PSDefaultParameterValues 는 참조가 아니라 복제본을 저장한다 —
# S10e 가 제자리(['키'] = …)로 바꾸면 참조 저장은 같은 객체라 대입 복원이 무효다(리뷰 r4 O4 실측) → Clone 저장 · Clone 교체 복원 + S10e 가 복원 뒤 키 없음을 스스로 단언한다
$OrigWhatIf = $global:WhatIfPreference
$OrigPSDPV = $global:PSDefaultParameterValues.Clone()
# 런북 블록 추출 결과(표식 → 코드 본문 · 실패 사유) — R1 · R2 가 채우고 GA · GB 가 쓴다(Reset-Mocks 는 건드리지 않는다)
$global:RbCode = @{}
$global:RbWhy = @{}

# ---------------------------------------------------------------- 계약(블록과 독립으로 하네스가 들고 있는 기대값)
$global:EXPECTED_ADDR = 'http://127.0.0.1:18200'
$global:FAKE_ROOT = 'hvs.MOCK-ROOT-T054-aB3dE5gH7jK9mN1pQ2rS'
$global:FAKE_PRE_TOKEN = 'hvs.MOCK-PREEXISTING-zY8xW6vU4tS2rQ0pO9n'
$global:FAKE_SHARE = 'MOCK-recovery-share-Lk4Jh7Gf2Ds9Ap1Qw6Er'
$PATHS = @(
  [pscustomobject]@{ path = 'kv/prod/db/identity_admin/owner'; user = 'identity_admin_owner'; db = 'identity_admin' }
  [pscustomobject]@{ path = 'kv/prod/db/identity_admin/app'; user = 'identity_admin_app'; db = 'identity_admin' }
  [pscustomobject]@{ path = 'kv/dev/db/dev_identity_admin/owner'; user = 'dev_identity_admin_owner'; db = 'dev_identity_admin' }
  [pscustomobject]@{ path = 'kv/dev/db/dev_identity_admin/app'; user = 'dev_identity_admin_app'; db = 'dev_identity_admin' }
  [pscustomobject]@{ path = 'kv/platform/db/authentik/owner'; user = 'authentik_owner'; db = 'authentik' }
  [pscustomobject]@{ path = 'kv/platform/db/openfga/owner'; user = 'openfga_owner'; db = 'openfga' })
$URL_HOST = '@pg-main-rw.data.svc:5432/'
$URL_QUERY = '?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt'
$LIVE_PW = @{
  'kv/prod/db/identity_admin/owner'    = 'MOCK-live-po-Qx7Vb2Lm9Pt4Rk8Wn3Hd6Fb1Yc5Js'
  'kv/prod/db/identity_admin/app'      = 'MOCK-live-pa-Zr4Tg8Kp1Nw6Bx3Mv9Hq2Lc7Fd5Ys'
  'kv/dev/db/dev_identity_admin/owner' = 'MOCK-live-do-Jw2Hn7Rt4Kb9Xq6Pm1Lv8Cz3Gf5Ds'
  'kv/dev/db/dev_identity_admin/app'   = 'MOCK-live-da-Vk9Pb3Lx6Tm1Qr8Hn4Wz2Cg7Jd5Fs'
  'kv/platform/db/authentik/owner'     = 'MOCK-live-au-Hs5Mq2Wx8Lb4Tn7Kv1Pz9Rg3Cd6Fj'
  'kv/platform/db/openfga/owner'       = 'MOCK-live-of-Bt3Kw7Ny1Lq9Xm5Pv2Hr8Cz4Gd6Js' }
function Url-For { param($e, [string]$pw) 'postgresql://' + $e.user + ':' + $pw + $URL_HOST + $e.db + $URL_QUERY }
function SEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::Ordinal) }

# ---------------------------------------------------------------- 0) 실물 차단 가드(블록을 한 번이라도 돌리기 전에)
$TrapDir = Join-Path ([IO.Path]::GetTempPath()) ('t054-harness-trap-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TrapDir)
foreach ($n in 'vault', 'kubectl') {
  [IO.File]::WriteAllText((Join-Path $TrapDir "$n.cmd"), "@echo off`r`necho TRAP>`"%~dp0CALLED-$n`"`r`nexit /b 97`r`n", [Text.UTF8Encoding]::new($false)) }
$RealDirs = @(Get-Command vault, kubectl, vault.exe, kubectl.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { (Split-Path -Parent $_.Source).TrimEnd('\') })
$sep = [IO.Path]::PathSeparator
$keptPath = @($env:PATH -split [regex]::Escape($sep) | Where-Object {
    $d = $_; if ([string]::IsNullOrEmpty($d)) { return $false }
    foreach ($r in $RealDirs) { if ([string]::Equals($d.TrimEnd('\'), $r, [StringComparison]::OrdinalIgnoreCase)) { return $false } }
    $true })
$OrigPath = $env:PATH
$env:PATH = (@($TrapDir) + $keptPath) -join $sep
# 운영자 KUBECONFIG(관리자 자격일 수 있다)를 이 프로세스에서 끊는다 — 함정 디렉터리 안의 없는 경로로 덮고, 맨 끝 finally 에서 원래 값(없었으면 없음)으로 되돌린다
$OrigKubeconfig = $env:KUBECONFIG
$FakeKubeconfig = Join-Path $TrapDir 'no-such-kubeconfig'
$env:KUBECONFIG = $FakeKubeconfig

# ---------------------------------------------------------------- 모의 명령(블록의 StrictMode 3.0 아래에서 돈다 — 해시 테이블은 ['키'] 로만 읽는다)
function At { param($arr, [int]$i) $l = @($arr); if ($i -ge 0 -and $i -lt $l.Count) { [string]$l[$i] } else { '' } }
function Has-Flag { param($list, [string]$f) foreach ($x in @($list)) { if (SEq $x $f) { return $true } }; $false }
function Add-Event { param([string]$e) [void]$global:Events.Add($e) }
function Add-Violation { param([string]$v) [void]$global:Violations.Add($v) }
# native stderr 흉내: 호출자의 EAP=Stop 아래에서도 종료 오류가 되지 않게 지역 EAP 를 Continue 로 둔다(2>&1 이면 ErrorRecord 로 섞이고 2>$null 이면 버려진다 — 실물과 같다)
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
# mode(postMeta 결함 — put 이 성공한 뒤의 metadata 응답만 바꾼다. 저장소 자체는 그대로): cv2 = 다른 기록자가 v2 를 쓴 것처럼 current_version 2(v2 도 live) /
#   deletion = 마운트의 delete_version_after 처럼 현재 버전에 deletion_time(삭제 예약)
function Kv-MetaObj { param([string]$path, [string]$mode = '')
  $e = $global:Kv[$path]
  $cur = [int]$e['current']; $dva = '0s'
  $vers = [ordered]@{}
  foreach ($k in @($e['versions'].Keys | Sort-Object { [int]$_ })) {
    $v = $e['versions'][$k]
    $vers[[string]$k] = [ordered]@{ created_time = $v['created_time']; deletion_time = $v['deletion_time']; destroyed = $v['destroyed'] } }
  if ((SEq $mode 'cv2') -and $vers.Count -gt 0) { $cur = $cur + 1; $vers[[string]$cur] = [ordered]@{ created_time = '2026-10-14T03:00:01Z'; deletion_time = ''; destroyed = $false } }
  if ((SEq $mode 'deletion') -and $vers.Contains([string]$cur)) { $vers[[string]$cur]['deletion_time'] = '2026-10-21T03:00:00Z'; $dva = '168h0m0s' }
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
  if (SEq $mode 'garbage') { $global:LASTEXITCODE = 0; return 'not-json-at-all' }
  $o = [ordered]@{ type = 'ocikms'; initialized = $true; sealed = $false; t = 1; n = 1; progress = 0; nonce = ''; version = '2.0.4-MOCK'; build_date = '2026-01-01T00:00:00Z'
    migration = $false; cluster_name = 'vault-cluster-MOCK'; cluster_id = 'MOCK-cluster-id'; recovery_seal = $true; storage_type = 'raft'; ha_enabled = $true }
  $rc = 0
  if (SEq $mode 'sealed') { $o['sealed'] = $true; $rc = 2 }
  if (SEq $mode 'uninit') { $o['initialized'] = $false; $o['sealed'] = $true; $rc = 2 }
  if (SEq $mode 'stringbool') { $o['sealed'] = 'false' }
  # okrc1: 응답은 unsealed JSON 인데 종료 코드 1(2026-10-14 리뷰 O3 — 블록의 "unsealed 인데 exit≠0 → 판단 불가" 분기를 고정한다)
  if (SEq $mode 'okrc1') { $rc = 1 }
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
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv metadata get 인자 형식(플래그는 경로 앞 · -format=json): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:meta-get:$path"
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if (Take-Fault 'metaFalseAbsent' $path) { Mock-Stderr @("No value found at kv/metadata/$r"); $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'metaEmpty' $path) { $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'metaError' $path) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', "URL: GET $($global:EXPECTED_ADDR)/v1/kv/metadata/$r", 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  # postMeta 'err'(2026-10-14 리뷰 r3 O3): 이 경로에 put 이 한 번이라도 불린 뒤의 metadata 조회만 500 — 판정 단계(put 전)는 정상이다.
  # 쓰기 뒤 metadata 확인(S20c)과 put 비 0 뒤 재판정(S16d)의 일시 오류 분기를 고정한다
  if ((SEq ([string]$global:F['postMeta'][$path]) 'err') -and @($global:PutCalls | Where-Object { SEq $_.path $path }).Count -gt 0) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', "URL: GET $($global:EXPECTED_ADDR)/v1/kv/metadata/$r", 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  # postDelErr: 이 경로를 지운 뒤의 metadata 조회만 500 — 런북 ② 삭제 블록의 삭제 뒤 확인이 조회 오류를 "없어졌다"로 보지 않는지(GB12)
  if ($global:F['postDelErr'].ContainsKey($path) -and $global:Deleted.ContainsKey($path)) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/metadata/$r"); $global:LASTEXITCODE = 2; return }
  Json-Lines (Kv-MetaObj $path ([string]$global:F['postMeta'][$path])) }
function Mock-KvGet { param($rest)
  foreach ($x in @($rest)) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { Add-Violation 'kv get -field 사용(끝 개행을 잃는다 — T045 교훈)'; $global:LASTEXITCODE = 1; return } }
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv get 인자 형식(플래그는 경로 앞 · -format=json): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
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
    # 잘린 JSON — 안에 비밀 값이 들어 있다(블록이 해석 실패를 어떻게 다루는지 · $Error 에 값이 남는지 본다)
    $global:LASTEXITCODE = 0
    return @('{', '  "data": {', '    "data": {', ('      "password": "' + [string]$v['data']['password'] + '",'), '      "url": ') }
  $meta = [ordered]@{ created_time = $v['created_time']; custom_metadata = $null; deletion_time = $v['deletion_time']; destroyed = $v['destroyed']; version = [int]$cur }
  $data = $null
  if (-not $v['destroyed'] -and [string]::IsNullOrEmpty([string]$v['deletion_time'])) { $data = $v['data'] }
  Json-Lines ([ordered]@{ request_id = 'mock-req'; lease_id = ''; lease_duration = 0; renewable = $false; data = [ordered]@{ data = $data; metadata = $meta }; warnings = $null }) }
# tamper 결함(키 지정형 — 2026-10-14 리뷰 O2: 되읽기 대조가 세 키를 모두 보는지 고정한다): $global:F['tamper'][<경로>] = 모드. 저장 때 한 번만 값을 바꾼다.
#   password · username = 마지막 한 글자 · url = 비밀번호 부분 첫 글자(접두 · 접미 모양은 그대로 — 모양 판정으로는 못 잡고 해시 대조로만 잡힌다) ·
#   dropKey = url 키를 뺀다 · extraKey = 키 note 를 더한다
function One-Char { param([string]$s, [int]$i)
  if ($i -lt 0 -or $i -ge $s.Length) { return $s }
  $s.Substring(0, $i) + $(if (SEq $s.Substring($i, 1) 'A') { 'B' } else { 'A' }) + $s.Substring($i + 1) }
function Take-Tamper { param([string]$path)
  $t = $global:F['tamper']
  if (-not $t.ContainsKey($path)) { return '' }
  $m = [string]$t[$path]
  $t.Remove($path)
  $m }
function Tamper-Data { param($data, [string]$mode)
  if (SEq $mode 'password') { $p = [string]$data['password']; $data['password'] = One-Char $p ($p.Length - 1) }
  elseif (SEq $mode 'username') { $n = [string]$data['username']; $data['username'] = One-Char $n ($n.Length - 1) }
  elseif (SEq $mode 'url') { $u = [string]$data['url']; $data['url'] = One-Char $u ($u.IndexOf(':', 'postgresql://'.Length) + 1) }
  elseif (SEq $mode 'dropKey') { $data.Remove('url') }
  elseif (SEq $mode 'extraKey') { $data['note'] = 'x' }
  else { Add-Violation "하네스: 알 수 없는 tamper 모드 $mode" } }
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
  if ($null -ne $cas -and $cas -ne $cur) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $tm = Take-Tamper $path
  if ($tm) { Tamper-Data $data $tm }
  if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:NowIso; versions = @{} } }
  $n = [int]$global:Kv[$path]['current'] + 1
  $global:Kv[$path]['versions'][[string]$n] = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $n
  # 중단(Ctrl+C) 대용(putInterrupt 결함): 서버는 이미 커밋했는데 클라이언트 쪽 파이프라인이 끊겼다 — 블록 요약이 "쓰지 않았다"로 남으면 안 된다
  if (Take-Fault 'putInterrupt' $path) { throw '모의 중단(put 도중 Ctrl+C 대용) — 서버는 이미 커밋했다' }
  # putLost 결함(2026-10-14 리뷰 r3 O6): 서버는 커밋했는데 응답이 유실돼 CLI 자동 재시도(VAULT_MAX_RETRIES 기본 2)가 자기 기록과 CAS 충돌했다 —
  # 종료 2 · 진짜 CAS 충돌과 같은 문구(블록은 문구로 가를 수 없다 — 재판정으로만 가른다)
  if (Take-Fault 'putLost' $path) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $global:LASTEXITCODE = 0
  @('====== Secret Path ======', "kv/data/$r", '', '======= Metadata =======', 'Key                Value', '---                -----', "created_time       $($global:NowIso)",
    'custom_metadata    <nil>', 'deletion_time      n/a', 'destroyed          false', "version            $n") }
# kv metadata delete — 런북 ② 삭제 블록 시나리오($global:AllowDelete)에서만 답한다. 시드 블록 · ① 점검 블록이 부르면 위반이다.
# 결함: delFail(권한 거부 · 종료 2) · delNoop(종료 0 인데 지우지 않음) — 지운 경로는 $global:Deleted 에 남긴다(postDelErr 용)
function Mock-MetaDelete { param($rest)
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.flags).Count -gt 0 -or @($p.trailing).Count -gt 0) { Add-Violation "kv metadata delete 인자 형식(경로 하나만): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:meta-delete:$path"
  if (-not $global:AllowDelete) { Add-Violation "kv metadata delete 호출(시드 블록 · ① 점검 블록은 지우지 않는다): $path"; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if ($global:F['delFail'].ContainsKey($path)) {
    Mock-Stderr @("Error deleting kv/metadata/${r}: Error making API request.", '', 'Code: 403. Errors:', '', '* permission denied'); $global:LASTEXITCODE = 2; return }
  if (-not $global:F['delNoop'].ContainsKey($path)) { [void]$global:Kv.Remove($path); $global:Deleted[$path] = $true }
  $global:LASTEXITCODE = 0
  "Success! Data deleted (if it existed) at: kv/metadata/$r" }
function vault {
  $stdin = @($input)
  $a = @($args | ForEach-Object { [string]$_ })
  $line = $a -join ' '
  [void]$global:ArgvLog.Add($line)
  $global:LASTEXITCODE = 0
  $isPut = (SEq (At $a 0) 'kv') -and (SEq (At $a 1) 'put')
  if ($stdin.Count -gt 0 -and -not $isPut) { Add-Violation "put 이 아닌 vault 호출에 stdin: $line" }
  $rest1 = @($a | Select-Object -Skip 1)
  if (SEq (At $a 0) 'version') { Add-Event 'vault:version'; return 'Vault v0.0.0-MOCK (harness)' }
  if (SEq (At $a 0) 'status') { return (Mock-Status $rest1) }
  if ((SEq (At $a 0) 'token') -and (SEq (At $a 1) 'lookup')) { return (Mock-TokenLookup @($a | Select-Object -Skip 2)) }
  if (SEq (At $a 0) 'kv') {
    if ((SEq (At $a 1) 'metadata') -and (SEq (At $a 2) 'get')) { return (Mock-MetaGet @($a | Select-Object -Skip 3)) }
    if ((SEq (At $a 1) 'metadata') -and (SEq (At $a 2) 'delete')) { return (Mock-MetaDelete @($a | Select-Object -Skip 3)) }
    if (SEq (At $a 1) 'get') { return (Mock-KvGet @($a | Select-Object -Skip 2)) }
    if ($isPut) { return (Mock-KvPut @($a | Select-Object -Skip 2) $stdin) } }
  Add-Violation "허용 목록 밖 vault 호출: $line"
  $global:LASTEXITCODE = 1 }
function vault.exe { Add-Violation ('vault.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function kubectl { Add-Violation ('kubectl 호출(이 블록은 클러스터에 닿지 않는다): ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function kubectl.exe { Add-Violation ('kubectl.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function curl { Add-Violation 'curl 호출'; $global:LASTEXITCODE = 1 }
function curl.exe { Add-Violation 'curl.exe 호출'; $global:LASTEXITCODE = 1 }
function oci { Add-Violation 'oci 호출'; $global:LASTEXITCODE = 1 }
function gh { Add-Violation 'gh 호출'; $global:LASTEXITCODE = 1 }
function Read-Host { param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
  $p = [string]$Prompt
  [void]$global:Prompts.Add($p)
  $v = ''
  if ($global:Inputs.Count -gt 0) { $v = [string]$global:Inputs.Dequeue() }
  # items = 이 입력을 묻는 시점까지 화면에 나온 출력 수(Run-Case 가 센다 — 리뷰 r3 O2: INFO vault CLI 줄이 root 토큰 프롬프트보다 먼저인지)
  [void]$global:ReadLog.Add([pscustomobject]@{ prompt = $p; secure = [bool]$AsSecureString; masked = [bool]$MaskInput; value = $v; items = [int]$global:ItemCount })
  if ($AsSecureString) {
    Add-Event 'read:secure'
    $ss = [securestring]::new()
    foreach ($c in $v.ToCharArray()) { $ss.AppendChar($c) }
    return $ss }
  Add-Event 'read:plain'
  $v }
# clipFail 결함(2026-10-14 리뷰 O5): 다른 프로세스(rdpclip · 클립보드 관리자)가 클립보드를 잡고 있을 때처럼 예외 — 쓰려던 값은 먼저 기록한다("공백만" 단언 유지)
# 실물 Set-Clipboard 처럼 ShouldProcess 를 따른다(2026-10-14 리뷰 r3 O5): 세션 $WhatIfPreference · $PSDefaultParameterValues 의 -WhatIf 가 살아 있으면
# 아무것도 쓰지 않고(clip:whatif) 예외도 없다 — 블록이 비웠다고 믿는 채 root 토큰이 클립보드에 남는 경로를 재현한다
function Set-Clipboard { [CmdletBinding(SupportsShouldProcess = $true)] param([Parameter(ValueFromPipeline = $true, Position = 0)]$Value)
  if (-not $PSCmdlet.ShouldProcess('clipboard', 'Set-Clipboard')) { Add-Event 'clip:whatif'; return }
  [void]$global:ClipValues.Add([string]$Value); Add-Event 'clip:set'
  if ($global:F['clipFail']) { Add-Event 'clip:fail'; throw '모의 클립보드 열기 실패(다른 프로세스가 클립보드를 잡고 있다)' } }
# Set-PSDebug: -Off 만 허용(이벤트) — -Trace · -Step · -Strict 는 위반(2026-10-14 리뷰 O6). 실물을 부르지 않는다(하네스 프로세스의 strict 설정을 건드리지 않는다)
function Set-PSDebug { param([switch]$Off, [int]$Trace = -1, [switch]$Step, [switch]$Strict)
  if ($Off -and $Trace -lt 0 -and -not $Step -and -not $Strict) { Add-Event 'psdebug:off' } else { Add-Violation 'Set-PSDebug 를 -Off 가 아닌 인자로 호출' } }
function Get-Clipboard { Add-Violation 'Get-Clipboard 호출(블록은 클립보드를 읽지 않는다)'; ' ' }
# PowerShell 모듈 로깅 정책 키(PowerShellCore 2 + UseWindowsPowerShellPolicySetting=1 일 때 Windows PowerShell 2). 값 = $global:Policy[<키>] 해시(없으면 키 없음)
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
  if (SEq $global:ClipHistoryMode 'novalue') { return [pscustomobject]@{ ShellHotKeyUsed = 1 } }
  [pscustomobject]@{ EnableClipboardHistory = $global:ClipHistory } }
function Test-Path { param([Parameter(Position = 0)]$Path)
  if (([string]$Path).EndsWith('.vault-token', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:vault-token'; return [bool]$global:VaultTokenFile }
  Microsoft.PowerShell.Management\Test-Path -Path $Path }

# ---------------------------------------------------------------- 가드 확인 · 모의 상태
function Assert-Guard {
  foreach ($n in 'vault', 'kubectl', 'vault.exe', 'kubectl.exe', 'Set-PSDebug') {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($null -eq $c -or $c.CommandType -ne 'Function') { throw "가드 실패: $n 이 모의 함수로 풀리지 않는다 — 블록을 실행하지 않는다" } }
  foreach ($a in @(Get-Command vault, kubectl, vault.exe, kubectl.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    if (-not $a.Source.StartsWith($TrapDir, [StringComparison]::OrdinalIgnoreCase)) { throw "가드 실패: 실물 실행 파일이 PATH 에 남아 있다($($a.Source)) — 블록을 실행하지 않는다" } }
  if (-not (SEq $env:KUBECONFIG $FakeKubeconfig) -or (Microsoft.PowerShell.Management\Test-Path -LiteralPath $FakeKubeconfig)) { throw '가드 실패: KUBECONFIG 가 하네스의 없는 경로가 아니다 — 블록을 실행하지 않는다' } }
function Trap-Markers { @(Get-ChildItem -LiteralPath $TrapDir -Filter 'CALLED-*' -ErrorAction SilentlyContinue).Count }
function Reset-Mocks {
  # 세션 설정을 먼저 원래 값으로(S10e 가 WhatIf · 기본 매개변수 값을 바꾼다 — 아래 Remove-Item 이 그 설정에 걸리지 않게 맨 앞)
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $global:Kv = @{}
  $global:F = @{ status = 'ok'; metaFalseAbsent = @{}; metaEmpty = @{}; metaError = @{}; readFail = @{}; readGarbage = @{}; tamper = @{}; putFail = @{}; postMeta = @{}; putInterrupt = @{}; clipFail = $false
    putLost = @{}; delFail = @{}; delNoop = @{}; postDelErr = @{} }
  $global:AllowDelete = $false
  $global:Deleted = @{}
  $global:ItemCount = 0
  $global:Policy = @{}
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:TokenPolicies = @('default', 'root')
  $global:ClipHistory = 0
  $global:ClipHistoryMode = 'value'
  $global:VaultTokenFile = $false
  $global:NowIso = '2026-10-14T03:00:00Z'
  $global:PreRunPuts = -1
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }
Reset-Mocks
function Seed-Path { param([string]$path, $data, [int]$current = 1, [string]$deletion = '', [bool]$destroyed = $false)
  $vers = @{}
  if ($current -gt 0) { $vers[[string]$current] = @{ data = $data; deletion_time = $deletion; destroyed = $destroyed; created_time = '2026-10-13T00:00:00Z' } }
  $global:Kv[$path] = @{ current = $current; created = '2026-10-13T00:00:00Z'; versions = $vers } }
function Live-Data { param($e, [string]$pw = '') if ([string]::IsNullOrEmpty($pw)) { $pw = $LIVE_PW[$e.path] }; [ordered]@{ username = $e.user; password = $pw; url = (Url-For $e $pw) } }
function Seed-LiveOk { param($e) Seed-Path $e.path (Live-Data $e) }
function KvCur { param([string]$path) if ($global:Kv.ContainsKey($path)) { [int]$global:Kv[$path]['current'] } else { -1 } }
function KvData { param([string]$path)
  if (-not $global:Kv.ContainsKey($path)) { return $null }
  $v = $global:Kv[$path]['versions'][[string]$global:Kv[$path]['current']]
  if ($null -eq $v) { return $null }
  $v['data'] }
function Invoke-PreRun { param([string[]]$inputs)
  foreach ($x in $inputs) { $global:Inputs.Enqueue($x) }
  try { & $BlockPath *>&1 | Out-Null } catch { }
  $global:PreRunPuts = $global:PutCalls.Count
  $global:ItemCount = 0
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }

# ---------------------------------------------------------------- 노출 검사(바늘: 비밀 전체 · base64 · 8자 조각 전부 / url 은 전체 + 그 안의 비밀번호 부분)
$script:NSecrets = [System.Collections.Generic.List[string]]::new()
$script:NFulls = [System.Collections.Generic.List[string]]::new()
function Add-SecretField { param($k, $v)
  if ($null -eq $v) { return }
  $s = [string]$v
  if ([string]::IsNullOrEmpty($s)) { return }
  if (SEq $k 'password') { $script:NSecrets.Add($s) }
  elseif (SEq $k 'url') { $script:NFulls.Add($s); if ($s -match '^postgresql://[^:/@]+:([^@]+)@') { $script:NSecrets.Add($Matches[1]) } } }
function Build-Needles {
  $script:NSecrets = [System.Collections.Generic.List[string]]::new()
  $script:NFulls = [System.Collections.Generic.List[string]]::new()
  $script:NSecrets.Add($global:FAKE_ROOT)
  foreach ($x in $global:ExtraSecrets) { $script:NSecrets.Add([string]$x) }
  foreach ($path in @($global:Kv.Keys)) { foreach ($ver in @($global:Kv[$path]['versions'].Values)) {
      $d = $ver['data']; if ($null -eq $d) { continue }
      foreach ($k in @($d.Keys)) { Add-SecretField $k $d[$k] } } }
  foreach ($b in $global:PutBodies) { try { $o = $b | ConvertFrom-Json -AsHashtable -DateKind String; foreach ($k in @($o.Keys)) { Add-SecretField $k $o[$k] } } catch { } }
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($s in $script:NSecrets) {
    [void]$set.Add($s)
    [void]$set.Add([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)))
    if ($s.Length -gt 8) { for ($i = 0; $i -le $s.Length - 8; $i++) { [void]$set.Add($s.Substring($i, 8)) } } }
  foreach ($s in $script:NFulls) { [void]$set.Add($s) }
  # 해시도 바늘이다(브리프 S6 "값 · 해시 출력 금지" — 2026-10-14 리뷰 O1 변이 ③): 비밀 · url 마다 SHA-256 hex 의 대문자 · 소문자 전체 + 앞 16자
  # (블록의 $sha 는 UTF-8 바이트의 대문자 hex 다. 앞 16자 = 잘라 낸 "지문" 출력까지 잡는다 — 16 hex 우연 일치는 사실상 0)
  foreach ($s in @($script:NSecrets) + @($script:NFulls)) {
    $hx = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s)))
    foreach ($h in @($hx, $hx.ToLowerInvariant())) { [void]$set.Add($h); [void]$set.Add($h.Substring(0, 16)) } }
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
# pwsh -File 로 돌리면 이 스크립트의 script 범위가 곧 global 범위다 — 시나리오 도중 하네스가 다시 만드는 내부 상태(바늘 목록 등)는 제외한다
$HarnessGlobals = @('Kv', 'F', 'Inputs', 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets', 'TokenPolicies',
  'ClipHistory', 'ClipHistoryMode', 'VaultTokenFile', 'NowIso', 'PreRunPuts', 'CaseChecks', 'LastText', 'LastItems', 'GvBefore', 'EXPECTED_ADDR', 'FAKE_ROOT', 'FAKE_PRE_TOKEN', 'FAKE_SHARE',
  'NSecrets', 'NFulls', 'Policy', 'PolicyPaths', 'Error', 'ItemCount', 'AllowDelete', 'Deleted', 'WhatIfPreference', 'PSDefaultParameterValues', 'OrigWhatIf', 'OrigPSDPV',
  'RbCode', 'RbWhy')
function Flat-Text { param($v)
  if ($null -eq $v) { return '' }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Collections.IDictionary]) { return ((@($v.Keys) | ForEach-Object { [string]$_ + '=' + [string]$v[$_] }) -join "`n") }
  if ($v -is [System.Collections.IEnumerable]) { return ((@($v) | ForEach-Object { [string]$_ }) -join "`n") }
  [string]$v }
function Snapshot-Globals { $h = @{}; foreach ($g in @(Get-Variable -Scope Global)) { $h[$g.Name] = $g.Value }; $h }
function Globals-Hit { param($before, $needles)
  # 이 시나리오 동안 새로 생기거나 바뀐 전역 변수만 본다(하네스 자신의 모의 상태는 제외) — 맞으면 변수 이름만 돌려준다(값은 내지 않는다)
  foreach ($g in @(Get-Variable -Scope Global)) {
    if ($HarnessGlobals -contains $g.Name) { continue }
    if ($before.ContainsKey($g.Name) -and [object]::ReferenceEquals($before[$g.Name], $g.Value)) { continue }
    $hit = First-Needle (Flat-Text $g.Value) $needles
    if ($null -ne $hit) { return "`$$($g.Name)(바늘 길이 $($hit.Length))" } }
  $null }
function Env-Text { param([string[]]$skip = @()) ((@(Get-ChildItem Env: | Where-Object { $skip -notcontains $_.Name }) | ForEach-Object { [string]$_.Value }) -join "`n") }

# ---------------------------------------------------------------- 시나리오 실행기
$Results = [System.Collections.ArrayList]::new()
# -Gate: S12 의 관문 단언(파서 오류 · 명령 · 정적 형식 · $Host · 리다이렉트 허용 목록) — 하나라도 FAIL 이거나 빠지면 런타임 시나리오를 돌리지 않는다
function Check { param([string]$name, [bool]$ok, [string]$detail = '', [switch]$Gate) [void]$global:CaseChecks.Add([pscustomobject]@{ name = $name; ok = $ok; detail = $detail; gate = [bool]$Gate }) }
function Finish-Case { param([string]$id, [string]$desc, [string]$text)
  $bad = @($global:CaseChecks | Where-Object { -not $_.ok })
  [void]$Results.Add([pscustomobject]@{ id = $id; desc = $desc; pass = ($bad.Count -eq 0 -and $global:CaseChecks.Count -gt 0); total = $global:CaseChecks.Count; failed = $bad.Count
      detail = (($bad | Select-Object -First 6 | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) }) -join ' | ') })
  if ($bad.Count -gt 0 -or ($Show -and $id -like $Show)) { Write-Host "---- $id 화면 출력 ----`n$text`n" -ForegroundColor DarkGray } }
# finally 요약 표에서 그 경로의 행(요약 머리 뒤에서 경로로 시작하는 줄)
function Summary-Row { param([string]$path)
  $after = $false
  foreach ($l in ([string]$global:LastText -split "`n")) {
    if ($l.StartsWith('--- T054 DB 자격 시드 결과 요약', [StringComparison]::Ordinal)) { $after = $true; continue }
    if ($after -and $l.StartsWith($path + ' ', [StringComparison]::Ordinal)) { return $l } }
  '' }
function Ev-Index { param([string]$e, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (SEq $global:Events[$i] $e) { return $i } }; -1 }
function Ev-First { param([string]$prefix, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (([string]$global:Events[$i]).StartsWith($prefix, [StringComparison]::Ordinal)) { return $i } }; -1 }
function Check-Created { param($e)
  $d = KvData $e.path
  Check "$($e.path): v1" ((KvCur $e.path) -eq 1) "current=$(KvCur $e.path)"
  if ($null -eq $d) { Check "$($e.path): 데이터 있음" $false; return }
  $names = @(@($d.Keys) | ForEach-Object { [string]$_ } | Sort-Object)
  Check "$($e.path): 키 3 = password,url,username" (SEq ($names -join ',') 'password,url,username') ($names -join ',')
  Check "$($e.path): username = $($e.user)" (SEq $d['username'] $e.user)
  $pw = [string]$d['password']
  Check "$($e.path): password = base64url 43자(A–Z a–z 0–9 - _)" ($pw -cmatch '\A[A-Za-z0-9_-]{43}\z') "len=$($pw.Length)"
  Check "$($e.path): url = postgresql://<username>:<password>@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt" (SEq $d['url'] (Url-For $e $pw)) }
function Check-Unchanged { param($e, [string]$pw)
  Check "$($e.path): 버전 불변(v1)" ((KvCur $e.path) -eq 1) "current=$(KvCur $e.path)"
  $d = KvData $e.path
  Check "$($e.path): 값 불변" ($null -ne $d -and (SEq $d['password'] $pw)) }
function Check-Absent { param($e) Check "$($e.path): 쓰지 않음(경로 없음)" (-not $global:Kv.ContainsKey($e.path)) }
function Check-WriteOrder { param([object[]]$creates)
  $iStatus = Ev-Index 'vault:status'; $iSecure = Ev-Index 'read:secure'; $iLookup = Ev-Index 'vault:token-lookup'
  Check '순서: status → root 토큰 입력 → token lookup' ($iStatus -ge 0 -and $iSecure -gt $iStatus -and $iLookup -gt $iSecure)
  $iSeed = Ev-Index 'read:plain'
  Check '순서: 쓰기 확인 정지점(seed) 이 있다' ($iSeed -ge 0)
  $before = 0
  foreach ($e in $PATHS) { $j = Ev-Index "vault:meta-get:$($e.path)"; if ($j -gt $iLookup -and $j -lt $iSeed) { $before++ } }
  Check '순서: 6경로 판정(metadata get) 이 전부 정지점 앞(판정 단계 분리)' ($before -eq 6) "정지점 앞 $before"
  $firstPut = Ev-First 'vault:put:'
  Check '순서: 첫 put 이 정지점 뒤' ($firstPut -gt $iSeed) "put=$firstPut seed=$iSeed"
  $cursor = $iSeed; $ok = $true
  foreach ($e in $creates) {
    $ip = Ev-Index "vault:put:$($e.path)" $cursor
    $ig = Ev-Index "vault:kv-get:$($e.path)" ($ip + 1)
    $im = Ev-Index "vault:meta-get:$($e.path)" ($ig + 1)
    $nx = Ev-First 'vault:put:' ($ip + 1)
    if ($ip -lt 0 -or $ig -lt 0 -or $im -lt 0 -or ($nx -ge 0 -and $im -gt $nx)) { $ok = $false }
    $cursor = [Math]::Max($cursor, $im) }
  Check '순서: 경로마다 put → 되읽기(kv get) → metadata 확인 → 다음 경로' $ok }
function Run-Case {
  param([string]$Id, [string]$Desc, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [hashtable]$PreEnv = @{})
  Assert-Guard
  Reset-Mocks
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
  foreach ($k in @($PreEnv.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value ([string]$PreEnv[$k]) }
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $global:GvBefore = $gvBefore
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $BlockPath) {
    # 출력은 나오는 즉시 하류로 흐른다(한 스레드 파이프라인) — ItemCount = 지금까지 화면에 나온 출력 수(모의 Read-Host 가 호출 시점의 값을 남긴다)
    $global:ItemCount = 0
    try { & $BlockPath *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
    catch { $threw = $true; $errMsg = [string]$_.Exception.Message } }
  else { $threw = $true; $errMsg = '블록 파일 없음' }
  $lines = @($items | ForEach-Object { [string]$_ })
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  $global:LastItems = $items
  # ---- 결과 · 기대 줄
  if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg }
  else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  # ---- 공통 사후 조건 1: 비밀 노출 0(모든 면 · 8자 조각까지)
  $needles = Build-Needles
  $skipEnv = @(); if ($PreEnv.ContainsKey('VAULT_TOKEN')) { $skipEnv += 'VAULT_TOKEN' }
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv' = ($global:ArgvLog -join "`n"); '클립보드' = ($global:ClipValues -join "`n")
    '$Error' = (Error-Text); '환경 변수' = (Env-Text $skipEnv) }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  # ---- 공통 사후 조건 2: 환경 정리(조건부)
  if ($PreEnv.ContainsKey('VAULT_TOKEN')) { Check 'env: 시작 전 VAULT_TOKEN 은 건드리지 않는다' (SEq $env:VAULT_TOKEN $PreEnv['VAULT_TOKEN']) }
  else { Check 'env: VAULT_TOKEN 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN)) }
  if ($PreEnv.ContainsKey('VAULT_ADDR') -and -not (SEq $PreEnv['VAULT_ADDR'] $global:EXPECTED_ADDR)) { Check 'env: 시작 전 (다른 값의) VAULT_ADDR 은 건드리지 않는다' (SEq $env:VAULT_ADDR $PreEnv['VAULT_ADDR']) }
  else { Check 'env: VAULT_ADDR 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR)) }
  # ---- 공통 사후 조건 3: 실물·허용 목록·스트림·클립보드·입력 위생
  Check '위반 0(허용 목록 밖 vault · kubectl · -field · argv 값 · put 밖 stdin)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 vault/kubectl 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0(출력은 Write-Host/Write-Warning 뿐 — 돌려받지 않은 값이 화면에 찍힐 경로 없음)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
  Check '클립보드에는 공백만 쓴다' (@($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0)
  $secretReads = @($global:ReadLog | Where-Object { ([string]$_.value).StartsWith('hvs.', [StringComparison]::Ordinal) -or ([string]$_.value).Contains('MOCK') -or ([string]$_.value).Trim().StartsWith('hvs.', [StringComparison]::Ordinal) })
  Check '비밀 입력은 전부 -AsSecureString' (@($secretReads | Where-Object { -not $_.secure }).Count -eq 0)
  Check '입력은 전부 가려진다(비밀 = -AsSecureString · 정지점 단어 = -MaskInput — 정지점에 비밀을 잘못 붙여도 화면 · 스크롤백에 남지 않는다)' (@($global:ReadLog | Where-Object { -not $_.secure -and -not $_.masked }).Count -eq 0)
  Check 'kv put 은 전부 -cas=0 + stdin(-)' (@($global:PutCalls | Where-Object { $null -eq $_.cas -or $_.cas -ne 0 -or -not $_.stdin }).Count -eq 0)
  $iSeedAny = Ev-Index 'read:plain'; $iPut = Ev-First 'vault:put:'
  Check '쓰기 확인(seed 정지점) 전 put 0' ($iPut -lt 0 -or ($iSeedAny -ge 0 -and $iPut -gt $iSeedAny))
  Check 'finally 요약 출력(성공·실패 어느 쪽이든)' ($text.Contains('--- T054 DB 자격 시드 결과 요약') -and $text.Contains('창 종료 체크리스트'))
  Check '첫 동작 = Set-PSDebug -Off 1회(창에 켜져 있던 -Trace 가 이후 대입 — 토큰 · 비밀번호 · url — 을 찍지 않게 · 리뷰 O6)' ((Ev-Index 'psdebug:off') -eq 0 -and @($global:Events | Where-Object { SEq $_ 'psdebug:off' }).Count -eq 1) $(if ($global:Events.Count) { "첫 이벤트 $($global:Events[0])" } else { '이벤트 0' })
  # root 토큰 프롬프트까지 간 시나리오: INFO vault CLI 줄(명령 종류 · 경로)이 그 프롬프트보다 먼저 화면에 나와야 한다 — 런북은 "토큰을 붙이기 전에 종류가 Application 인지 본다"를
  # 이 순서에 기댄다(2026-10-14 리뷰 r3 O2 — INFO 줄을 토큰 확인 뒤로 옮긴 변이가 2017/2017 로 통과했다)
  $secRead = @($global:ReadLog | Where-Object { $_.secure })
  if ($secRead.Count -gt 0) {
    $iInfo = -1
    for ($i = 0; $i -lt $items.Count; $i++) { if (([string]$items[$i]).StartsWith('INFO vault CLI: ', [StringComparison]::Ordinal)) { $iInfo = $i; break } }
    Check '순서: INFO vault CLI 줄이 root 토큰 프롬프트보다 먼저 화면에 나온다(토큰을 붙이기 전 명령 종류 확인 · 리뷰 r3 O2)' ($iInfo -ge 0 -and $iInfo -lt [int]$secRead[0].items) "INFO 출력 순번 $iInfo · 토큰 프롬프트 시점 출력 수 $($secRead[0].items)" }
  if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($k in @($PreEnv.Keys)) { if (Microsoft.PowerShell.Management\Test-Path -LiteralPath ('Env:' + $k)) { Remove-Item -LiteralPath ('Env:' + $k) } }
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- S12 정적 구조·위생(블록을 실행하지 않는다 — 모든 시나리오보다 먼저 돈다)
$AllowedCmds = @('vault', 'Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Remove-Item', 'Remove-Variable',
  'Get-Command', 'ConvertFrom-Json', 'ConvertTo-Json', 'ConvertFrom-SecureString', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug')
# 관문 단언 수(파서 오류 0 · 명령 · 정적 형식 · $Host · 파일 리다이렉트 허용 목록) — Static-Gate 는 이 수만큼 있고 전부 PASS 일 때만 통과다(빠진 관문 = FAIL)
$GateCount = 5
$AllowedHelpers = @('eq', 'has', 'sha', 'stop', 'readSecret', 'firstErr', 'parseJson', 'prop', 'state', 'judge', 'write')
$AllowedTypes = @('string', 'System.String', 'Convert', 'System.Convert', 'StringComparison', 'System.StringComparison', 'System.Security.Cryptography.RandomNumberGenerator',
  'System.Security.Cryptography.SHA256', 'System.Text.Encoding', 'Array', 'System.Array', 'object', 'System.Object', 'System.Collections.Generic.List[object]', 'Math', 'System.Math')
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
# $Host 규칙용: 변수 이름(범위 · 드라이브 접두를 뗀 것 — $global:Host · $variable:Host · ${Host} 모두 Host). VariablePath.UnqualifiedPath 는 공개 속성이 아니다
function Var-Name { param($n) $u = [string]$n.VariablePath.UserPath; $i = $u.LastIndexOf(':'); if ($i -ge 0) { $u.Substring($i + 1) } else { $u } }
# $Host 규칙용: $node 가 $expr 를 대상으로 하는 인스턴스 멤버 $name(호출 여부 $invoke · 호출이면 인자 0)인가
function Is-Member { param($node, $expr, [string]$name, [bool]$invoke)
  if ($null -eq $node -or $node -isnot [System.Management.Automation.Language.MemberExpressionAst] -or $node.Static) { return $false }
  if (-not [object]::ReferenceEquals($node.Expression, $expr)) { return $false }
  if (-not (SEq $node.Member.Extent.Text $name)) { return $false }
  $isInv = $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]
  if ($invoke -ne $isInv) { return $false }
  if ($isInv -and $null -ne $node.Arguments -and $node.Arguments.Count -gt 0) { return $false }
  $true }
# 입력 버퍼 비움 규칙용(2026-10-14 리뷰 O1): 문장 $s 가 "$Host.UI.RawUI.FlushInputBuffer()" 한 식만으로 된 파이프라인 문장인가 — AST 노드로 본다
# (주석 · 문자열 안의 글자는 노드가 아니다)
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
# 그 문장 자체이거나, 본문이 그 문장 하나뿐인 try(catch 는 무엇이든 — 블록의 모양 try { …FlushInputBuffer() } catch { })인가
function Is-FlushOrTry { param($s)
  if (Is-FlushStmt $s) { return $true }
  ($s -is [System.Management.Automation.Language.TryStatementAst]) -and $s.Body.Statements.Count -eq 1 -and (Is-FlushStmt $s.Body.Statements[0]) }
# S12 관문 판정(리뷰 O8): 관문 단언이 $GateCount 개 있고 전부 PASS 면 '' — 아니면 실패 사유(단언 이름 · 세부)
function Static-Gate { param([int]$Expected = $GateCount)
  $g = @($global:CaseChecks | Where-Object { $_.gate })
  $bad = @($g | Where-Object { -not $_.ok } | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) })
  if ($g.Count -ne $Expected) { $bad += "관문 단언 $($g.Count)개(기대 $Expected)" }
  $bad -join ' · ' }
# ---- 정적 판정 함수(시드 블록 S12 · 런북 블록 R1/R2 공통 — 위반 목록을 돌려준다, 빈 목록 = 통과)
# 최상위가 "& { … }" 한 문이면 그 안쪽 스크립트블록 AST, 아니면 $null
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
# 비밀처럼 보이는 상수(대·소문자·숫자 섞인 32자+ 연속) — 앞 6자만 돌려준다
function Bad-Secrets { param([string]$text)
  , @([regex]::Matches($text, '[A-Za-z0-9_\-+/=]{32,}') | Where-Object { $_.Value -cmatch '[A-Z]' -and $_.Value -cmatch '[a-z]' -and $_.Value -cmatch '[0-9]' } | ForEach-Object { $_.Value.Substring(0, 6) + '…' }) }
function Run-Static {
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $exists = Microsoft.PowerShell.Management\Test-Path -LiteralPath $BlockPath
  Check '블록 파일 존재' $exists
  $bytes = [byte[]]@(); if ($exists) { $bytes = [IO.File]::ReadAllBytes($BlockPath) }
  Check '비어 있지 않다' ($bytes.Length -gt 0)
  Check 'BOM 없음' (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF))
  Check 'CR 0' (@($bytes | Where-Object { $_ -eq 13 }).Count -eq 0)
  # 키 이벤트로 들어오는 붙여넣기(conhost 우클릭 · Windows Terminal)에서 PSReadLine 은 탭을 완성 키로 처리한다 — 탭 하나가 붙여 넣은 코드를 바꿀 수 있다(리뷰 r3 O4)
  Check 'TAB 0(붙여넣기 탭 완성 방지)' (@($bytes | Where-Object { $_ -eq 9 }).Count -eq 0)
  $utf8ok = $true; try { [void][Text.UTF8Encoding]::new($false, $true).GetString($bytes) } catch { $utf8ok = $false }
  Check 'UTF-8 유효' $utf8ok
  # 끝 2바이트가 } LF 이면 } 뒤 개행은 정확히 1개다(T045 정본의 끝 3바이트 = 0A 7D 0A — } 앞의 0A 는 앞 줄의 끝)
  Check '끝 = } + LF 1개(7D 0A)' ($bytes.Length -ge 2 -and $bytes[$bytes.Length - 2] -eq 0x7D -and $bytes[$bytes.Length - 1] -eq 0x0A)
  $text = [Text.Encoding]::UTF8.GetString($bytes)
  $lines = $text.Split("`n")
  Check '첫 줄 = & {' ($lines.Count -gt 0 -and (SEq $lines[0] '& {'))
  $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
  Check '빈 줄 0(파일 전체)' ($blank -eq 0 -and $lines.Count -gt 1) "빈 줄 $blank"
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $stmts = $ast.EndBlock.Statements
  $inner = Find-Inner $ast
  Check '최상위 문장 1개 = & { … }' ($null -ne $inner)
  Check '} 뒤 남는 문자 0' ($null -ne $inner -and $stmts[0].Extent.EndOffset -eq $text.Length - 1)
  # ---- 관문 4종(명령 · 정적 형식 · $Host · 리다이렉트 허용 목록 — 리뷰 O8): 파일 전체 AST 에서 늘 잰다($inner 가 없어도 — 그때 & { … } 자체가 위반으로 잡힌다).
  #      Static-Gate 가 이 넷 + 파서 오류 0 이 전부 PASS 여야 런타임 시나리오를 돌린다(판정 함수는 런북 블록 R1 · R2 와 같은 것을 쓴다)
  $badCmd = Bad-Cmds $ast $AllowedCmds $AllowedHelpers $inner
  Check '명령 허용 목록(vault · 출력 · env/클립보드/JSON 기본 cmdlet · Set-PSDebug · 헬퍼 스크립트블록만 — Start-Transcript·Out-File·Invoke-Expression·Start-Process · 절대 경로 실행 파일 등 0)' ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $AllowedTypes
  Check '정적 .NET 호출 허용 목록([Console]·[IO.File]·[Environment]·[Diagnostics.Process] 등 0)' ($badType.Count -eq 0) ($badType -join '; ') -Gate
  # $Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양으로만 — 호스트 UI 직접 쓰기($Host.UI.WriteLine · WriteErrorLine ·
  # $ExecutionContext.Host.UI …)는 *>&1 로 잡히지 않아 런타임 노출 검사가 보지 못한다(2026-10-14 리뷰 O1 변이 ①② 가 46/46 으로 통과). 변수에 담는 별칭($h = $Host)도 위반.
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만(호스트 UI 직접 쓰기 · 별칭 0 — *>&1 밖의 화면 경로)' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  # ---- 본문(& { … }) 구조 — 최상위가 & { … } 가 아니면 FAIL 하나로 남긴다
  if ($null -eq $inner) { Check '본문 구조 검사(첫 문장 · try/finally)' $false '최상위 & { … } 아님 — 본문 검사 생략' }
  else {
    $b0 = @($inner.EndBlock.Statements)
    $psd = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-PSDebug', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
    $t0 = ''; if ($b0.Count -gt 0) { $t0 = $b0[0].Extent.Text; if ($t0.Length -gt 40) { $t0 = $t0.Substring(0, 40) + '…' } }
    Check '본문 첫 문장 = Set-PSDebug -Off · Set-PSDebug 는 그 1곳뿐(붙여넣기 창에 켜져 있던 -Trace 가 뒤의 대입 — 토큰 · 비밀번호 · url — 을 찍기 전에 끈다 · 리뷰 O6)' ($b0.Count -gt 0 -and (SEq $b0[0].Extent.Text 'Set-PSDebug -Off') -and $psd -eq 1) "첫 문장: $t0 · Set-PSDebug $psd 곳"
    # 붙여넣기 창의 세션 상태($WhatIfPreference = $true · $ConfirmPreference Low/Medium · $PSDefaultParameterValues 의 -WhatIf)는 finally 의 Remove-Item Env: 와 Set-Clipboard 를
    # 예외 없이 건너뛰게 한다(리뷰 r3 O5 실측 — root 토큰이 env · 클립보드에 남는다). 블록은 try 앞의 직계 문장으로 셋을 자기 범위에 고정해야 한다(런타임은 S10e 가 재현)
    $pre0 = @($b0 | ForEach-Object { $_.Extent.Text })
    $fix0 = @('$WhatIfPreference = $false', "`$ConfirmPreference = 'High'", '$PSDefaultParameterValues = @{}')
    $fixMissing = @($fix0 | Where-Object { $f = $_; @($pre0 | Where-Object { SEq $_ $f }).Count -ne 1 })
    Check '본문 직계 문장으로 세션 설정 고정: $WhatIfPreference = $false · $ConfirmPreference = ''High'' · $PSDefaultParameterValues = @{} 각 1문장(붙여넣기 창의 WhatIf · 확인 · 기본 매개변수 값이 finally 의 env 제거 · 클립보드 비우기를 조용히 무력화하지 못하게 · 리뷰 r3 O5)' ($fixMissing.Count -eq 0) ($fixMissing -join '; ')
    $tries = @($b0 | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
    Check '본문 try 1개 + finally' ($tries.Count -eq 1 -and $null -ne $tries[0].Finally)
    if ($tries.Count -eq 1 -and $null -ne $tries[0].Finally) {
      $fe = Finally-Emitters $tries[0].Finally.Statements
      Check 'finally 는 Write-Host/Write-Warning · Remove-* · Set-Clipboard 만(성공 스트림 출력 없음 — Ctrl+C 때 끊기지 않게)' ($fe.Count -eq 0) ($fe -join '; ')
      $fs = @($tries[0].Finally.Statements | ForEach-Object { $_.Extent.Text })
      Check 'finally 첫 두 문장 = 블록이 만든 VAULT_TOKEN · VAULT_ADDR 제거(Ctrl+C 를 거듭 눌러 finally 가 끊겨도 root 토큰부터 사라진다)' ($fs.Count -ge 2 -and $fs[0].StartsWith('if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN', [StringComparison]::Ordinal) -and $fs[1].StartsWith('if ($addrOwned) { Remove-Item Env:VAULT_ADDR', [StringComparison]::Ordinal)) $(if ($fs.Count -gt 0) { '첫 문장: ' + $fs[0].Substring(0, [Math]::Min(40, $fs[0].Length)) } else { '' }) } }
  # Read-Host 는 $stop/$readSecret 헬퍼 안에서만. 그 헬퍼 본문(직계 문장)에서 Read-Host 를 담은 문장의 "바로 앞" 직계 문장이 입력 버퍼 비움이어야 한다 —
  # $Host.UI.RawUI.FlushInputBuffer() 한 식 문장 또는 본문이 그 문장 하나뿐인 try. AST 로 본다: 주석 · 문자열 안의 글자 · 조건문(if) 안 · throw 뒤(도달 불가) ·
  # Read-Host 뒤의 호출은 인정하지 않는다(2026-10-14 리뷰 O1 — 라운드 1 의 텍스트 검색은 주석 처리한 호출로도 통과했다)
  $badRead = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)) {
    # Read-Host 를 감싸는 가장 가까운 스크립트블록 식을 찾고, 그 스크립트블록이 대입되는 변수 이름을 본다($ans = Read-Host 같은 안쪽 대입은 건너뛴다)
    $p = $c.Parent; $owner = $null; $sbx = $null
    while ($null -ne $p -and $null -eq $sbx) { if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { $sbx = $p }; $p = $p.Parent }
    if ($null -ne $sbx) {
      $p = $sbx.Parent
      while ($null -ne $p) {
        if ($p -is [System.Management.Automation.Language.AssignmentStatementAst] -and $p.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $owner = $p.Left.VariablePath.UserPath; break }
        if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { break }
        $p = $p.Parent } }
    if (-not (@('stop', 'readSecret') -ccontains [string]$owner) -or $null -eq $sbx) { $badRead += "L$($c.Extent.StartLineNumber) 헬퍼 밖 Read-Host"; continue }
    $eb = $sbx.ScriptBlock.EndBlock
    $body = @(); if ($null -ne $eb) { $body = @($eb.Statements) }
    $iR = -1
    for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
    if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $badRead += "L$($c.Extent.StartLineNumber) Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(`$Host.UI.RawUI.FlushInputBuffer())이 아니다" } }
  Check 'Read-Host 는 정지점 헬퍼 안에서만 + 바로 앞 직계 문장이 입력 버퍼 비움(AST — 주석 · 문자열 · 조건문 안 · throw 뒤 · Read-Host 뒤 = 위반)' ($badRead.Count -eq 0) ($badRead -join '; ')
  $rhCount = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check 'Read-Host 2곳($stop · $readSecret)' ($rhCount -eq 2) "Read-Host $rhCount 곳"
  # vault 호출의 정적 모양: kv put 은 "-cas=0" + 마지막 인자 - · -field 0 · kv 하위 명령 허용 목록
  $badVault = @(); $putN = 0
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true)) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    $sig = ($el | Select-Object -First 3) -join ' '
    foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $badVault += "L$($c.Extent.StartLineNumber) -field" } }
    if ((SEq (At $el 0) 'kv') -and (SEq (At $el 1) 'put')) {
      $putN++
      if (-not (Has-Flag $el '-cas=0') -or -not (SEq $el[$el.Count - 1] '-')) { $badVault += "L$($c.Extent.StartLineNumber) kv put 모양(-cas=0 · stdin -)" } }
    elseif (-not ($sig.StartsWith('version') -or $sig.StartsWith('status -format=json') -or $sig.StartsWith('token lookup -format=json') -or $sig.StartsWith('kv metadata get') -or $sig.StartsWith('kv get -format=json'))) { $badVault += "L$($c.Extent.StartLineNumber) vault $sig" } }
  Check 'vault 호출 모양(kv put = "-cas=0" … - · -field 0 · 하위 명령 허용 목록 · delete/destroy/patch 0)' ($badVault.Count -eq 0 -and $putN -eq 1) "$($badVault -join '; ') put=$putN"
  # 비밀처럼 보이는 상수 0(가짜 값은 하네스에만)
  Check 'MOCK 문자열 0(가짜 값은 하네스 파일에만)' (-not $text.Contains('MOCK'))
  $ent = Bad-Secrets $text
  Check '비밀처럼 보이는 상수 0(대·소문자·숫자 섞인 32자+ 연속)' ($ent.Count -eq 0) ($ent -join ', ')
  Check 'Vault 토큰 모양 상수 0(hvs.<영숫자>)' (-not ($text -cmatch 'hvs\.[A-Za-z0-9]'))
  Check 'Start-Transcript 0' (-not $text.Contains('Start-Transcript')) }

# ---------------------------------------------------------------- 런북 「정리 판단」 두 블록(수정 라운드 4 — 리뷰 r3 O7 · 결정 C6): 추출 · 정적(R1 · R2) · 런타임(GA · GB)
# 런북 블록은 운영자 창(vault-unseal.md §0 절대 규칙 1 로 VAULT_ADDR · VAULT_TOKEN 이 들어 있는 창 D)에서 통째로 붙여 넣는 & { … } 한 문이다 — 시드 블록과 달리
# env 를 만들지도 지우지도 않고, Read-Host 는 평문(경로 · 재입력 — 비밀 아님)이다. 그래서 공통 사후 조건이 시드 블록(Run-Case)과 다르다(Run-RbCase).
# Set-Clipboard · Write-Warning(수정 라운드 6 — 리뷰 r6 S1/O1): 첫 Read-Host 전 클립보드 비움 `try { Set-Clipboard -Value ' ' } catch { Write-Warning … }` 한 문장만을 위한 허용이다
$RbAllowedCmds = @('vault', 'Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'ConvertFrom-Json', 'Where-Object', 'ForEach-Object', 'Sort-Object')
$RbAllowedTypes = @('string', 'System.String', 'StringComparison', 'System.StringComparison')
# 관문 단언 수(추출 · 파서 오류 0 · 명령 · 정적 형식 · $Host · 리다이렉트) — 하나라도 FAIL 이면 그 블록의 런타임 시나리오(GA 또는 GB)를 돌리지 않는다
$RbGateCount = 6
# 런북 텍스트에서 표식 주석이 든 ```powershell 코드 펜스 정확히 하나를 찾아, 펜스의 들여쓰기를 뗀 본문을 돌려준다(끝 LF 1개). 못 찾거나 둘 이상이면 $null — 사유는 $global:RbWhy[표식]
function Get-RbBlock { param([string]$marker)
  $global:RbWhy[$marker] = ''
  if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $RunbookPath)) { $global:RbWhy[$marker] = "런북 파일 없음: $RunbookPath"; return $null }
  $lines = [IO.File]::ReadAllText($RunbookPath, [Text.UTF8Encoding]::new($false)).Split("`n")
  $found = @()
  $i = 0
  while ($i -lt $lines.Count) {
    $m = [regex]::Match($lines[$i], '^(\s*)```powershell\s*$')
    if (-not $m.Success) { $i++; continue }
    $indent = $m.Groups[1].Value
    $body = @(); $j = $i + 1; $closed = $false
    while ($j -lt $lines.Count) {
      if ($lines[$j] -cmatch ('^' + [regex]::Escape($indent) + '```\s*$')) { $closed = $true; break }
      $body += $lines[$j]; $j++ }
    if ($closed -and @($body | Where-Object { $_.Contains($marker) }).Count -gt 0) { $found += [pscustomobject]@{ line = $i + 1; indent = $indent; body = $body } }
    $i = $j + 1 }
  if ($found.Count -ne 1) { $global:RbWhy[$marker] = "표식 $marker 가 든 powershell 코드 펜스 $($found.Count)개(기대 1)"; return $null }
  $f = $found[0]
  $out = @(foreach ($l in $f.body) { if ($l.StartsWith($f.indent, [StringComparison]::Ordinal)) { $l.Substring($f.indent.Length) } else { $l } })
  ($out -join "`n") + "`n" }
# Read-Host 바로 앞 직계 문장이 입력 버퍼 비움인가 — 헬퍼 소유를 요구하지 않는 일반형(런북 블록은 본문 직계 문장에서 Read-Host 를 부른다). AST 로 본다(주석 · 문자열 안 = 노드 아님)
function Bad-ReadFlush { param($ast)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)) {
    $p = $c.Parent
    while ($null -ne $p -and -not ($p -is [System.Management.Automation.Language.StatementBlockAst] -or $p -is [System.Management.Automation.Language.NamedBlockAst])) { $p = $p.Parent }
    $body = @(); if ($null -ne $p) { $body = @($p.Statements) }
    $iR = -1
    for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
    if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $bad += "L$($c.Extent.StartLineNumber) Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(`$Host.UI.RawUI.FlushInputBuffer())이 아니다" } }
  , $bad }
# vault 호출 모양(런북 블록): 하위 명령 + 첫 플래그까지(요소 4개)가 허용 접두 중 하나로 시작해야 한다 · -field 0. 점검 블록 = metadata get · kv get 만(put · delete 0) / 삭제 블록 = metadata get · metadata delete 만
function Bad-VaultRb { param($ast, [string[]]$allowed)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true)) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    $sig = ($el | Select-Object -First 4) -join ' '
    foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $bad += "L$($c.Extent.StartLineNumber) -field" } }
    if (-not @($allowed | Where-Object { $sig.StartsWith($_, [StringComparison]::Ordinal) }).Count) { $bad += "L$($c.Extent.StartLineNumber) vault $sig" } }
  , $bad }
# R1 · R2: 런북 블록 정적 검사 + 관문. 돌려주는 값 = 관문 실패 사유('' = 통과 → GA/GB 를 돌린다)
function Run-RbStatic { param([string]$Id, [string]$Desc, [string]$Marker, [string[]]$AllowedVault, [int]$ReadHosts)
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $code = Get-RbBlock $Marker
  Check "런북 코드 펜스에서 추출(표식 $Marker 가 든 powershell 펜스 정확히 1개 · 펜스 들여쓰기 제거)" ($null -ne $code) ([string]$global:RbWhy[$Marker]) -Gate
  if ($null -eq $code) { $code = '' }
  $global:RbCode[$Marker] = $code
  $lines = $code.Split("`n")
  Check '첫 줄 = & {' ($lines.Count -gt 0 -and (SEq $lines[0] '& {'))
  Check "표식 주석 = & { 다음 줄(# $Marker …)" ($lines.Count -gt 1 -and $lines[1].TrimStart().StartsWith('# ' + $Marker, [StringComparison]::Ordinal))
  $nonEmpty = @($lines | Where-Object { $_.Length -gt 0 })
  Check '끝 줄 = }' ($nonEmpty.Count -gt 0 -and (SEq $nonEmpty[$nonEmpty.Count - 1] '}'))
  $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
  Check '빈 줄 0(붙여넣기 — 기본 콘솔 호스트의 빈 줄 종료 대비)' ($blank -eq 0 -and $lines.Count -gt 1) "빈 줄 $blank"
  Check 'TAB 0(붙여넣기 탭 완성 방지)' (-not $code.Contains("`t"))
  Check 'CR 0' (-not $code.Contains("`r"))
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $inner = Find-Inner $ast
  Check '최상위 문장 1개 = & { … }' ($null -ne $inner)
  $badCmd = Bad-Cmds $ast $RbAllowedCmds @() $inner
  Check '명령 허용 목록(vault · Read-Host · Write-Host · Write-Warning · Set-Clipboard · ConvertFrom-Json · Where-Object · ForEach-Object · Sort-Object 만 — Start-Transcript · Out-File · Invoke-Expression · kubectl · 절대 경로 실행 파일 등 0)' ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $RbAllowedTypes
  Check '정적 .NET 호출 허용 목록([string]:: · [StringComparison]:: 만)' ($badType.Count -eq 0) ($badType -join '; ') -Gate
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만(호스트 UI 직접 쓰기 · 별칭 0)' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  $badRead = Bad-ReadFlush $ast
  Check 'Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(AST — 주석 · 문자열 · if 안 · throw 뒤 = 위반)' ($badRead.Count -eq 0) ($badRead -join '; ')
  $rhCount = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check "Read-Host $ReadHosts 곳 · 전부 평문(경로 · 재입력은 비밀이 아니다 — -AsSecureString · -MaskInput 0)" ($rhCount -eq $ReadHosts -and -not $code.Contains('-AsSecureString') -and -not $code.Contains('-MaskInput')) "Read-Host $rhCount 곳"
  # 첫 Read-Host 전 클립보드 비움(수정 라운드 6 — 리뷰 r6 S1/O1 = r4 O5): 운영자는 vault-unseal.md §0 절대 규칙 1 로 root 토큰을 PM 에서 붙인 뒤 이 블록을 돌린다 — 프롬프트(경로 · 재입력)는
  # 평문이라 오붙임(우클릭 · Ctrl+V)이 나면 토큰이 화면 · 스크롤백에 남는다. 블록은 첫 Read-Host 전에 `Set-Clipboard -Value ' '` 로 클립보드를 덮고(정확히 1문장 · try 안),
  # 실패하면 catch 의 Write-Warning(값 없음 — "클립보드를 비우지 못했다 … root 토큰 …")을 낸다. AST 로 본다(런타임 순서 · 값은 Run-RbCase 공통 단언)
  $clips = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-Clipboard', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $warns = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Write-Warning', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $reads = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $firstRead = -1; foreach ($r in $reads) { if ($firstRead -lt 0 -or $r.Extent.StartOffset -lt $firstRead) { $firstRead = $r.Extent.StartOffset } }
  $clipTry = $null; $warnInCatch = $false
  if ($clips.Count -eq 1) { $p = $clips[0].Parent; while ($null -ne $p -and $null -eq $clipTry) { if ($p -is [System.Management.Automation.Language.TryStatementAst]) { $clipTry = $p }; $p = $p.Parent } }
  if ($null -ne $clipTry) { foreach ($cc in $clipTry.CatchClauses) { foreach ($w in $warns) { if ($w.Extent.StartOffset -ge $cc.Extent.StartOffset -and $w.Extent.EndOffset -le $cc.Extent.EndOffset -and $w.Extent.Text.Contains('클립보드를 비우지 못했다') -and $w.Extent.Text.Contains('root 토큰')) { $warnInCatch = $true } } } }
  Check "첫 Read-Host 전 클립보드 비움: Set-Clipboard -Value ' ' 문장 정확히 1개 · 첫 Read-Host 앞 · try 안 · catch 의 Write-Warning 1개(클립보드를 비우지 못했다 … root 토큰 — 값 없음)(§0 규칙 1 로 붙인 토큰의 오붙임 방어 · 리뷰 r6 S1)" ($clips.Count -eq 1 -and (SEq $clips[0].Extent.Text "Set-Clipboard -Value ' '") -and $firstRead -ge 0 -and $clips[0].Extent.StartOffset -lt $firstRead -and $warns.Count -eq 1 -and $warnInCatch) "Set-Clipboard $($clips.Count) 곳 · Write-Warning $($warns.Count) 곳"
  $badVault = Bad-VaultRb $ast $AllowedVault
  Check "vault 호출 모양(허용 접두: $($AllowedVault -join ' / ') · 그 밖 0 · -field 0)" ($badVault.Count -eq 0) ($badVault -join '; ')
  Check 'MOCK 문자열 0' (-not $code.Contains('MOCK'))
  $ent = Bad-Secrets $code
  Check '비밀처럼 보이는 상수 0(대·소문자·숫자 섞인 32자+ 연속)' ($ent.Count -eq 0) ($ent -join ', ')
  Check 'Vault 토큰 모양 상수 0(hvs.<영숫자>)' (-not ($code -cmatch 'hvs\.[A-Za-z0-9]'))
  Check 'Start-Transcript 0 · env 쓰기 0(VAULT_ADDR · VAULT_TOKEN 은 창의 것 — 블록이 만들지도 지우지도 않는다)' (-not $code.Contains('Start-Transcript') -and -not $code.Contains('$env:') -and -not $code.Contains('Env:'))
  Finish-Case $Id $Desc ''
  Static-Gate -Expected $RbGateCount }
# GA · GB: 추출한 런북 블록을 [scriptblock]::Create 로 그대로 돌린다 — 창 상태(VAULT_ADDR · VAULT_TOKEN)는 하네스가 넣고 끝나면 지운다. 공통 사후 조건은 아래
function Run-RbCase {
  param([string]$Id, [string]$Desc, [string]$Marker, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [switch]$AllowDelete)
  Assert-Guard
  Reset-Mocks
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $global:AllowDelete = [bool]$AllowDelete
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
  $env:VAULT_ADDR = $global:EXPECTED_ADDR
  $env:VAULT_TOKEN = $global:FAKE_ROOT
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $global:GvBefore = $gvBefore
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  $code = [string]$global:RbCode[$Marker]
  if ([string]::IsNullOrEmpty($code)) { $threw = $true; $errMsg = '런북 블록 추출 실패(R1 · R2 참조) — 실행하지 않았다' }
  else {
    $sb = [scriptblock]::Create($code)
    $global:ItemCount = 0
    try { & $sb *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
    catch { $threw = $true; $errMsg = [string]$_.Exception.Message } }
  $lines = @($items | ForEach-Object { [string]$_ })
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  $global:LastItems = $items
  if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg }
  else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  # ---- 공통 사후 조건 1: 비밀 노출 0(저장된 password · url · 터널 토큰 · root 토큰 — 8자 조각까지) — 점검 블록은 값을 읽지만 키 이름만 낸다
  $needles = Build-Needles
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv' = ($global:ArgvLog -join "`n"); '$Error' = (Error-Text); '환경 변수' = (Env-Text @('VAULT_TOKEN')) }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  # ---- 공통 사후 조건 2: 쓰기 경계 · 실물 · 스트림 · 창 상태
  Check '위반 0(허용 목록 밖 vault · kubectl · 점검 블록의 kv metadata delete · argv 값)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 vault/kubectl 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0(출력은 Write-Host 뿐 — vault 응답 · 삭제 응답이 그대로 화면에 흐르지 않는다)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
  Check 'kv put 0(런북 블록은 값을 쓰지 않는다)' ($global:PutCalls.Count -eq 0)
  if (-not $AllowDelete) { Check 'vault 쓰기 명령 0(① 점검 블록 — kv metadata delete · put · destroy 호출 없음)' ((Ev-First 'vault:meta-delete:') -lt 0 -and (Ev-First 'vault:put:') -lt 0) }
  Check '창의 VAULT_ADDR · VAULT_TOKEN 은 그대로(블록이 만든 것이 아니다 — 건드리지 않는다 · 창 종료 체크리스트가 지운다)' ((SEq $env:VAULT_ADDR $global:EXPECTED_ADDR) -and (SEq $env:VAULT_TOKEN $global:FAKE_ROOT))
  Check '입력은 전부 평문 Read-Host(경로 · 재입력 — 비밀 아님) · 보안 입력 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0)
  # 첫 Read-Host 전 클립보드 비움(수정 라운드 6 — 리뷰 r6 S1/O1 = r4 O5): §0 절대 규칙 1 로 붙인 root 토큰이 클립보드에 남은 채 평문 프롬프트에 오붙임되는 경로를 막는다 —
  # 모의 Set-Clipboard 의 clip:set 이 모의 Read-Host 의 read:plain 보다 앞이고, 기록된 클립보드 값은 전부 공백 하나(SEq Ordinal)여야 한다
  $iClip = Ev-Index 'clip:set'; $iRead = Ev-Index 'read:plain'
  Check '첫 Read-Host 전 클립보드 비움(clip:set ≥ 1 · 값은 공백만 — 첫 clip:set 이 첫 read:plain 보다 앞 · §0 규칙 1 로 붙인 root 토큰의 오붙임 방어 · 리뷰 r6 S1)' ($iClip -ge 0 -and $iRead -ge 0 -and $iClip -lt $iRead -and @($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0) "clip:set=$iClip · read:plain=$iRead · 클립보드 기록 $($global:ClipValues.Count)개"
  if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($v in @('VAULT_ADDR', 'VAULT_TOKEN')) { Remove-Item -LiteralPath ('Env:' + $v) -ErrorAction SilentlyContinue }
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- 시나리오
$GateMsg = ''
try {
  Write-Host "=== T054 모의 하네스 — 블록: $BlockPath ==="
  # ---- S12: 구조(정적 — 블록을 실행하지 않는다)를 맨 먼저 돌린다. 관문(파서 오류 0 · 명령 · 정적 형식 · $Host · 리다이렉트 허용 목록)이 하나라도
  #      FAIL 이면 런타임 시나리오를 하나도 돌리지 않는다 — 함수 가림 · PATH 함정은 절대 경로 실행 파일 · 프로세스 직접 기동을 막지 못한다(리뷰 O8)
  Run-Static
  Finish-Case 'S12' '구조: & { 로 시작하는 한 문 · 빈 줄 0 · 끝 } + LF 1 · BOM/CR 0 · Start-Transcript 0 · 파서 오류 0 · 명령/형식/$Host/리다이렉트 허용 목록(관문) · 첫 문장 Set-PSDebug -Off · finally 출력 규칙 + 첫 두 문장 = env 제거 · Read-Host 바로 앞 입력 버퍼 비움(AST) · 비밀 상수 0' ''
  $GateMsg = Static-Gate
  if ($GateMsg) {
    Write-Host "관문 FAIL(S12): $GateMsg — 런타임 시나리오를 실행하지 않는다(블록 실행 0회)" -ForegroundColor Red
    throw 'S12 관문 FAIL' }
  Assert-Guard
  Write-Host ("가드: S12 관문 PASS(블록 실행 전) · vault·kubectl(.exe 포함) · Set-PSDebug = 모의 함수 · 실물 디렉터리 {0}개를 PATH 에서 뺌 · 함정 디렉터리 맨 앞(표식 0 단언) · KUBECONFIG = 없는 경로" -f $RealDirs.Count)
  $ROOT = $global:FAKE_ROOT
  $OK2 = @($global:FAKE_ROOT, 'seed')
  $SUMMARY = '--- T054 DB 자격 시드 결과 요약'
  $OKLINE = { param($e) "OK   $($e.path) v1 — 생성 · 되읽기 해시 일치(username·password·url)" }
  $SKIPLINE = { param($e) "SKIP $($e.path) — live-ok" }
  $P0 = $PATHS[0]; $P1 = $PATHS[1]; $P2 = $PATHS[2]; $P3 = $PATHS[3]; $P4 = $PATHS[4]; $P5 = $PATHS[5]

  # ---- S01 · S02: 정상 첫 시드 + 노출 검사
  Run-Case 'S01' '6경로 absent → 6개 생성(v1 · 키 3 · username = role · url 구성 · url 의 비밀번호 = password · 경로마다 다른 값) · 판정/쓰기 순서' -Inputs $OK2 `
    -Want (@($PATHS | ForEach-Object { & $OKLINE $_ }) + @($PATHS | ForEach-Object { "PLAN $($_.path) — absent" }) + @('OK   Vault 도달 · 초기화됨 · unsealed', 'OK   토큰 정책에 root 포함', '쓸 경로 6개', '이 실행이 kv 에 새로 쓴 경로: 6건')) `
    -NotWant @('STOP ', '중단(') -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      $pws = @($PATHS | ForEach-Object { [string](KvData $_.path)['password'] } | Sort-Object -Unique)
      Check '경로마다 비밀번호가 서로 다르다(6개 고유)' ($pws.Count -eq 6) "고유 $($pws.Count)"
      $urls = @($PATHS | ForEach-Object { [string](KvData $_.path)['url'] } | Sort-Object -Unique)
      Check 'url 6개 고유' ($urls.Count -eq 6)
      Check 'put 6회' ($global:PutCalls.Count -eq 6)
      Check '입력 2회(root 토큰 보안 입력 1 · seed 1)' ($global:ReadLog.Count -eq 2 -and $global:ReadLog[0].secure -and -not $global:ReadLog[1].secure)
      Check 'seed 정지점 문구에 -cas=0 · 덮어쓰기 없음' ($global:Prompts.Count -eq 2 -and ([string]$global:Prompts[1]).Contains('seed') -and ([string]$global:Prompts[1]).Contains('-cas=0'))
      foreach ($e in $PATHS) { Check "쓰기 전 목록에 $($e.path)(값 없음)" ($global:LastText.Contains("  - $($e.path)  (username=$($e.user) · db=$($e.db))")) }
      Check-WriteOrder $PATHS
      Check '클립보드를 비웠다(토큰 입력 직후 + finally)' ($global:ClipValues.Count -ge 2)
      Check 'seed 정지점은 -MaskInput(가려진 입력)이고 문구에 "입력은 가려진다"' ($global:ReadLog.Count -eq 2 -and $global:ReadLog[1].masked -and ([string]$global:Prompts[1]).Contains('입력은 가려진다'))
      Check 'INFO 줄에 vault CLI 버전 · 명령 종류 · 경로(모의 = Function · 경로 없음)' ($global:LastText.Contains('INFO vault CLI: Vault v0.0.0-MOCK (harness) · Function (경로 없음) — '))
      Check '모듈 로깅 정책 키는 PowerShellCore 2개만 읽었다(UseWindowsPowerShellPolicySetting 없음)' ((Ev-Index "reg:policy:$($global:PolicyPaths[0])") -ge 0 -and (Ev-Index "reg:policy:$($global:PolicyPaths[1])") -ge 0 -and (Ev-First 'reg:policy:HKLM:\SOFTWARE\Policies\Microsoft\Windows') -lt 0 -and (Ev-First 'reg:policy:HKCU:\SOFTWARE\Policies\Microsoft\Windows') -lt 0)
      Check '모듈 로깅 정책 확인은 root 토큰 입력 전' ((Ev-First 'reg:policy:') -ge 0 -and (Ev-First 'reg:policy:') -lt (Ev-Index 'read:secure')) }

  Run-Case 'S02' '노출 검사 — 저장된 password·url · root 토큰이 화면·프롬프트·argv·클립보드·$Error·전역·환경 어디에도 없다(8자 조각 포함) + 검출기 자체 시험' -Inputs $OK2 -Post {
      $nd = Build-Needles
      Check '바늘 수 ≥ 6×(36 조각 + 전체 + base64) + url 6 + 토큰' ($nd.Count -ge 6 * 38 + 6 + 30) "바늘 $($nd.Count)"
      $pw0 = [string](KvData $P0.path)['password']
      Check '검출기 자체 시험: 비밀번호 앞 8자만 있어도 잡는다' ($null -ne (First-Needle ("정상 출력 " + $pw0.Substring(0, 8) + " 끝") $nd))
      Check '검출기 자체 시험: 비밀번호 가운데 8자 조각도 잡는다' ($null -ne (First-Needle ("x" + $pw0.Substring(17, 8) + "y") $nd))
      Check '검출기 자체 시험: root 토큰 앞 8자를 잡는다' ($null -ne (First-Needle ("token=" + $global:FAKE_ROOT.Substring(0, 8)) $nd))
      Check '검출기 자체 시험: url 의 비밀 아닌 부분(postgresql://role:…@host/db?…)은 잡지 않는다' ($null -eq (First-Needle ('postgresql://identity_admin_owner:' + '@pg-main-rw.data.svc:5432/identity_admin' + $URL_QUERY) $nd))
      Check '검출기 자체 시험: 이번 화면 출력 전체에는 바늘 0' ($null -eq (First-Needle $global:LastText $nd))
      $h0 = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($pw0)))
      Check '검출기 자체 시험: 비밀번호의 SHA-256 hex 대문자 · 소문자 · 앞 16자가 바늘 집합에 있다' (($nd -ccontains $h0) -and ($nd -ccontains $h0.ToLowerInvariant()) -and ($nd -ccontains $h0.Substring(0, 16)) -and ($nd -ccontains $h0.ToLowerInvariant().Substring(0, 16)))
      Check '검출기 자체 시험: 출력에 섞인 비밀번호 해시(대문자 · 소문자 · 앞 16자)를 잡는다' (($null -ne (First-Needle ('H ' + $h0) $nd)) -and ($null -ne (First-Needle ('h ' + $h0.ToLowerInvariant()) $nd)) -and ($null -ne (First-Needle ('p ' + $h0.Substring(0, 16) + ' q') $nd)))
      $hu = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string](KvData $P0.path)['url'])))
      $ht = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($global:FAKE_ROOT)))
      Check '검출기 자체 시험: url · root 토큰의 SHA-256 hex 도 바늘 집합에 있다' (($nd -ccontains $hu) -and ($nd -ccontains $ht) -and ($nd -ccontains $ht.ToLowerInvariant())) }

  # ---- S03: 일부 live-ok
  Run-Case 'S03' '일부 live-ok(prod owner · openfga owner) → 그 둘 SKIP · 나머지 4 생성 · live 경로의 버전·값 불변' -Setup { Seed-LiveOk $P0; Seed-LiveOk $P5 } -Inputs $OK2 `
    -Want @((& $SKIPLINE $P0), (& $SKIPLINE $P5), (& $OKLINE $P1), (& $OKLINE $P2), (& $OKLINE $P3), (& $OKLINE $P4), '쓸 경로 4개', '판정 결과: 생성 예정 4 · 건너뜀(live-ok) 2 · 중단 0') -NotWant @('STOP ') -Post {
      Check-Unchanged $P0 $LIVE_PW[$P0.path]; Check-Unchanged $P5 $LIVE_PW[$P5.path]
      foreach ($e in @($P1, $P2, $P3, $P4)) { Check-Created $e }
      Check 'put 4회 · live 경로에는 put 0' ($global:PutCalls.Count -eq 4 -and @($global:PutCalls | Where-Object { (SEq $_.path $P0.path) -or (SEq $_.path $P5.path) }).Count -eq 0)
      Check-WriteOrder @($P1, $P2, $P3, $P4) }

  # ---- S04: live-mismatch(쓰기 0) — 한 경로만 잘못된 live 값, 나머지는 absent
  function Run-Mismatch { param([string]$id, [string]$desc, $e, $data, [string]$reason, [string[]]$extraSecrets = @())
    $script:mmE = $e; $script:mmData = $data; $script:mmX = $extraSecrets
    Run-Case $id $desc -Setup { Seed-Path $script:mmE.path $script:mmData; foreach ($x in $script:mmX) { [void]$global:ExtraSecrets.Add($x) } } -Inputs $OK2 -Expect '판정 단계에서 중단' `
      -Want @("STOP $($e.path) — live-mismatch: $reason", '미실행(판정 단계에서 중단 — 쓰지 않았다)', $SUMMARY, '이 실행이 kv 에 새로 쓴 경로: 0건') -Post {
        Check 'put 0(쓰기 0)' ($global:PutCalls.Count -eq 0)
        Check '쓰기 확인 정지점까지 가지 않았다(입력 1 = 토큰)' ($global:ReadLog.Count -eq 1)
        Check 'live 경로 버전 불변' ((KvCur $script:mmE.path) -eq 1)
        foreach ($o in $PATHS) { if (-not (SEq $o.path $script:mmE.path)) { Check-Absent $o } } } }
  $pwA = $LIVE_PW[$P1.path]
  Run-Mismatch 'S04a' 'live-mismatch: 키 누락(url 없음) → 쓰기 0으로 중단' $P1 ([ordered]@{ username = $P1.user; password = $pwA }) '키 집합 불일치(누락: url · 여분 0개)'
  Run-Mismatch 'S04b' 'live-mismatch: username 이 role 이름과 다름 → 쓰기 0' $P1 ([ordered]@{ username = 'someone_else'; password = $pwA; url = (Url-For $P1 $pwA) }) 'username 이 기대 role 이름(identity_admin_app)과 다르다'
  $pwOther = 'MOCK-urlpw-Wq3Ze8Rv1Tb6Yn4Um9Ik2Ol7Pa5Sd0X'
  Run-Mismatch 'S04c' 'live-mismatch: url 의 비밀번호 부분 ≠ password → 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = $pwA; url = (Url-For $P1 $pwOther) }) 'url 의 비밀번호 부분이 password 값과 다르다' @($pwOther)
  $pwShort = 'MOCK-short-Ab3Cd5Ef7'
  Run-Mismatch 'S04d' 'live-mismatch: password 길이 < 32 → 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = $pwShort; url = (Url-For $P1 $pwShort) }) 'password 길이가 32 미만이다'
  Run-Mismatch 'S04e' 'live-mismatch: 여분 키(note) → 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = $pwA; url = (Url-For $P1 $pwA); note = 'x' }) '키 집합 불일치(누락: 없음 · 여분 1개)'
  Run-Mismatch 'S04f' 'live-mismatch: url 접미(DB 이름) 다름 → 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = $pwA; url = ('postgresql://' + $P1.user + ':' + $pwA + $URL_HOST + 'wrong_db' + $URL_QUERY) }) 'url 접미가'
  $pwAt = 'MOCK-live-at@Xq7Vb2Lm9Pt4Rk8Wn3Hd6Fb1Yc5J'
  Run-Mismatch 'S04g' 'live-mismatch: password 에 URL 예약 문자(@) → 쓰기 0(재구성 비교만으로는 통과하는 거짓 OK 차단)' $P1 ([ordered]@{ username = $P1.user; password = $pwAt; url = (Url-For $P1 $pwAt) }) 'password 에 URL 에 그대로 넣을 수 없는 문자' @($pwAt)
  Run-Mismatch 'S04h' 'live-mismatch: password 가 문자열이 아님(JSON 숫자) → 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = [long]98765432109876; url = (Url-For $P1 '98765432109876') }) 'password 값이 문자열이 아니다' @('98765432109876')
  # S04i(리뷰 O3): 43자 + 끝 LF — url 도 같은 값으로 구성. 판정 정규식의 \z 앵커를 고정한다(.NET 의 $ 는 끝 개행 앞에서도 맞아 live-ok 로 SKIP 된다 —
  # CNPG 는 앞뒤 공백을 지운 값을 role 비밀번호로 적용하므로 url 속 비밀번호와 실제 role 비밀번호가 어긋난다 · T045 CHANGES F9 의 ^…$ 교훈)
  $pwNl = 'MOCK-live-nl-Gt5Hy8Uj2Ik6Ol9Pz3Xc7Vb1Nm4Qwe' + "`n"
  Run-Mismatch 'S04i' 'live-mismatch: password 끝에 LF(43자 + 개행 · url 도 같은 값) → 쓰기 0(\z 앵커 — ^…$ 면 live-ok 로 SKIP 된다)' $P1 ([ordered]@{ username = $P1.user; password = $pwNl; url = (Url-For $P1 $pwNl) }) 'password 에 URL 에 그대로 넣을 수 없는 문자' @($pwNl)
  # S04j(리뷰 r3 O1): url 의 사용자 부분만 username 과 다른 같은 길이의 이름 — 길이가 같아 Substring 위치가 어긋나지 않으므로 비밀번호 부분 대조는 통과한다.
  # 접두 검사(postgresql://<username>:)가 없으면 live-ok 로 SKIP 되어 거짓 "url 구성 확인" 이 난다(변이 mA 가 2017/2017 로 통과했다)
  Run-Mismatch 'S04j' 'live-mismatch: url 사용자 부분 ≠ username(같은 길이 identity_admin_xyz · 비밀번호 부분은 일치) → url 접두 검사로 쓰기 0' $P1 ([ordered]@{ username = $P1.user; password = $pwA; url = ('postgresql://identity_admin_xyz:' + $pwA + $URL_HOST + $P1.db + $URL_QUERY) }) 'url 접두가 postgresql://<username>: 과 다르다'

  # ---- S05: dead(쓰기 0)
  Run-Case 'S05a' 'dead: 현재 버전 soft-delete → 쓰기 0으로 중단' -Setup { Seed-Path $P2.path (Live-Data $P2) 1 '2026-10-13T05:00:00Z' } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($P2.path) — dead: 현재 버전 1 에 deletion_time 이 있다") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰)' ($global:ReadLog.Count -eq 1) }
  Run-Case 'S05b' 'dead: 현재 버전 destroy → 쓰기 0' -Setup { Seed-Path $P2.path $null 1 '' $true } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($P2.path) — dead: 현재 버전 1 이 파기(destroy)됐다") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S05c' 'dead: 메타데이터만 있고 버전 없음(current_version 0) → 쓰기 0' -Setup { Seed-Path $P2.path $null 0 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($P2.path) — dead: current_version=0") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }

  # ---- S06: 정지점
  foreach ($c in @(@('S06a', '다른 단어(go)', 'go'), @('S06b', '빈 Enter', ''), @('S06c', '공백이 붙은 단어(" seed")', ' seed'), @('S06d', '대문자 단어("SEED" — Ordinal 대소문자 구분)', 'SEED'))) {
    Run-Case $c[0] "쓰기 확인 정지점에서 $($c[1]) → 쓰기 0으로 중단 · finally 정리 줄 출력" -Inputs @($ROOT, $c[2]) -Expect '정지점에서 중단' `
      -Want @('미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)', $SUMMARY, '창 종료 체크리스트', '이 실행이 kv 에 새로 쓴 경로: 0건') -Post {
        Check 'put 0' ($global:PutCalls.Count -eq 0)
        Check 'kv 비어 있음' ($global:Kv.Count -eq 0) } }

  # ---- S07: Vault 도달·봉인(토큰을 묻기 전에 중단)
  foreach ($c in @(@('S07a', 'Vault 도달 실패(port-forward 없음)', 'down', 'Vault 도달 실패'), @('S07b', 'sealed=true', 'sealed', 'Vault sealed'),
      @('S07c', '미초기화', 'uninit', 'Vault 미초기화'), @('S07d', 'status 응답이 JSON 아님', 'garbage', 'Vault 도달 실패'), @('S07e', 'sealed 가 bool 이 아닌 문자열', 'stringbool', 'Vault 도달 실패'),
      @('S07f', 'status 응답은 unsealed JSON 인데 exit=1(리뷰 O3 — 비 0 종료 분기 고정)', 'okrc1', 'vault status 가 unsealed 인데 exit=1 — 판단 불가'))) {
    $script:st7 = $c[2]
    Run-Case $c[0] "$($c[1]) → root 토큰을 묻기 전에 중단(쓰기 0)" -Setup { $global:F['status'] = $script:st7 } -Inputs $OK2 -Expect $c[3] -Want @('root 토큰은 아직 묻지 않았다') -Post {
        Check '입력 0(토큰을 묻지 않았다)' ($global:ReadLog.Count -eq 0)
        Check 'status 뒤 다른 vault 호출 0' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) -and -not (SEq $_ 'vault:status') -and -not (SEq $_ 'vault:version') }).Count -eq 0)
        Check 'put 0' ($global:PutCalls.Count -eq 0) } }

  # ---- S08: 일시 상태(transient)
  # S08a(리뷰 r3 O6 로 기대 문구 갱신): put 비 0 은 "쓰지 않았다"로 단정하지 않고 값 없이 재판정한다 — 여기서는 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌(다른 기록자의 값)
  Run-Case 'S08a' '일시 상태: metadata get 이 실제로 있는 경로를 "No value found"(absent)로 오판 → -cas=0 put 거부 → 재판정 live v1 · 되읽기 해시 불일치 = CAS 충돌(다른 값) → 그 자리에서 fail-closed(덮어쓰기 0 · 뒤 경로 미실행)' `
    -Setup { Seed-LiveOk $P2; $global:F['metaFalseAbsent'][$P2.path] = 1 } -Inputs $OK2 -Expect 'put 거부' `
    -Want @("STOP $($P2.path) — put 거부(exit=2) · CAS 충돌(다른 값)", (& $OKLINE $P0), (& $OKLINE $P1), '미실행(앞 경로에서 중단 — 쓰지 않았다)', '중단(put 거부 exit=2 — 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 2건') `
    -NotWant @("OK   $($P2.path)", '기록됨(응답 유실', '결과 미확인 1') -Post {
      Check-Unchanged $P2 $LIVE_PW[$P2.path]
      Check-Created $P0; Check-Created $P1
      foreach ($e in @($P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 3회(세 번째가 CAS 거부)' ($global:PutCalls.Count -eq 3)
      $ip = Ev-Index "vault:put:$($P2.path)"; $im = Ev-Index "vault:meta-get:$($P2.path)" ($ip + 1); $ig = Ev-Index "vault:kv-get:$($P2.path)" ($ip + 1)
      Check '재판정 순서: put 거부 → metadata get(live v1) → kv get(값 미출력 해시 대조)' ($ip -ge 0 -and $im -gt $ip -and $ig -gt $im) "put=$ip meta=$im get=$ig" }
  Run-Case 'S08b' '일시 상태: metadata get 일시 오류(비 0 · 빈 출력 · 오류 문구 없음) → absent 로 보지 않고 판정 불가 → 쓰기 0' `
    -Setup { $global:F['metaEmpty'][$P3.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($P3.path) — 판정 불가: metadata 조회 exit=2 · (오류 출력 없음)") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check 'kv 비어 있음' ($global:Kv.Count -eq 0) }
  Run-Case 'S08c' '일시 상태: metadata get 서버 오류(500) → 판정 불가 · 오류의 * 줄만 표시 → 쓰기 0' `
    -Setup { $global:F['metaError'][$P4.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($P4.path) — 판정 불가: metadata 조회 exit=2 · * context deadline exceeded") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S08d' '일시 상태: 되읽기 일시 실패(2번째 경로) → 다음 경로로 가지 않고 중단' -Setup { $global:F['readFail'][$P1.path] = 1 } -Inputs $OK2 -Expect '되읽기 실패' `
    -Want @("STOP $($P1.path) — 되읽기 실패(exit=2)", (& $OKLINE $P0), '기록됨 — 되읽기 실패', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 2건') -Post {
      Check-Created $P0
      Check "$($P1.path): put 은 됐다(v1)" ((KvCur $P1.path) -eq 1)
      foreach ($e in @($P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 2회' ($global:PutCalls.Count -eq 2) }
  Run-Case 'S08e' '재실행 복구: S08d 상태에서 다시 실행 → 앞 2경로 live-ok SKIP(덮어쓰기 0) · 나머지 4 생성' `
    -Setup { $global:F['readFail'][$P1.path] = 1; Invoke-PreRun @($global:FAKE_ROOT, 'seed') } -Inputs $OK2 `
    -Want @((& $SKIPLINE $P0), (& $SKIPLINE $P1), (& $OKLINE $P2), (& $OKLINE $P5)) -NotWant @('STOP ') -Post {
      Check '사전 실행은 2경로에서 멈췄다(put 2)' ($global:PreRunPuts -eq 2) "사전 put $($global:PreRunPuts)"
      foreach ($e in $PATHS) { Check-Created $e }
      Check '본 실행 put 4회(앞 2경로 0)' ($global:PutCalls.Count -eq 4 -and @($global:PutCalls | Where-Object { (SEq $_.path $P0.path) -or (SEq $_.path $P1.path) }).Count -eq 0) }

  # ---- S09: 되읽기 대조(모의 Vault 가 저장 때 값을 바꾼다 — tamper 모드는 키 지정형)
  Run-Case 'S09' '되읽기 해시 불일치(모의 Vault 가 저장 때 password 한 글자 변형) → 중단 · "해시 불일치" 줄 · 값 미출력 · 뒤 경로 미실행' `
    -Setup { $global:F['tamper'][$P0.path] = 'password' } -Inputs $OK2 -Expect '되읽기 해시 불일치' `
    -Want @("STOP $($P0.path) — 되읽기 해시 불일치(password)", '기록됨 — 되읽기 해시 불일치(password)') -NotWant @("OK   $($P0.path)") -Post {
      Check 'put 1회' ($global:PutCalls.Count -eq 1)
      foreach ($e in @($P1, $P2, $P3, $P4, $P5)) { Check-Absent $e } }
  # S09b–e(리뷰 O2): 되읽기 대조가 세 키(username · password · url)와 키 집합을 모두 보는지 고정한다 — 대조 키를 password 하나로 줄이는 회귀(변이 A)는
  # OK 줄이 "되읽기 해시 일치(username·password·url)" 라고 쓰면서 url · username 을 검증하지 않는 거짓 검증이다(T045 사고 유형). 경로를 바꿔 가며 앞 경로 OK · 뒤 경로 put 0 도 본다
  function Run-Tamper { param([string]$id, [string]$desc, [int]$idx, [string]$mode, [string]$expect, [string]$stopText, [string]$rowText)
    $script:tmE = $PATHS[$idx]; $script:tmMode = $mode; $script:tmIdx = $idx; $script:tmRow = $rowText
    Run-Case $id $desc -Setup { $global:F['tamper'][$script:tmE.path] = $script:tmMode } -Inputs $OK2 -Expect $expect `
      -Want @("STOP $($PATHS[$idx].path) — $stopText", $SUMMARY, "이 실행이 kv 에 새로 쓴 경로: $($idx + 1)건", '미실행(앞 경로에서 중단 — 쓰지 않았다)') -NotWant @("OK   $($PATHS[$idx].path)") -Post {
        $row = Summary-Row $script:tmE.path
        Check "요약 행($($script:tmE.path)) = $script:tmRow" ($row.Contains($script:tmRow)) $row
        for ($i = 0; $i -lt $script:tmIdx; $i++) { Check-Created $PATHS[$i] }
        Check "$($script:tmE.path): put 은 됐다(v1)" ((KvCur $script:tmE.path) -eq 1)
        for ($i = $script:tmIdx + 1; $i -lt $PATHS.Count; $i++) { Check-Absent $PATHS[$i] }
        Check "put $($script:tmIdx + 1)회(뒤 경로 put 0)" ($global:PutCalls.Count -eq $script:tmIdx + 1) "put $($global:PutCalls.Count)" } }
  Run-Tamper 'S09b' '되읽기: url 한 글자 변형(비밀번호 부분 첫 글자 — 모양은 그대로) → 해시 불일치(url)로 중단 · 값 미출력 · 뒤 경로 put 0' 1 'url' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(url)' '기록됨 — 되읽기 해시 불일치(url) · 수동 확인'
  Run-Tamper 'S09c' '되읽기: username 한 글자 변형 → 해시 불일치(username)로 중단 · 뒤 경로 put 0' 2 'username' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(username)' '기록됨 — 되읽기 해시 불일치(username) · 수동 확인'
  Run-Tamper 'S09d' '되읽기: 키 누락(url 없음) → 키 집합 불일치로 중단 · 뒤 경로 put 0' 3 'dropKey' '되읽기 불일치' `
    '되읽기 키 집합 불일치(누락: url · 여분 0개)' '기록됨 — 되읽기 키 집합 불일치(누락 1 · 여분 0) · 수동 확인'
  Run-Tamper 'S09e' '되읽기: 여분 키(note) → 키 집합 불일치로 중단 · 뒤 경로 put 0' 4 'extraKey' '되읽기 불일치' `
    '되읽기 키 집합 불일치(누락: 없음 · 여분 1개)' '기록됨 — 되읽기 키 집합 불일치(누락 0 · 여분 1) · 수동 확인'

  # ---- S10: 클립보드 기록
  Run-Case 'S10a' '클립보드 기록 켜짐 → 시작 전 중단(입력 0 · vault 호출 0)' -Setup { $global:ClipHistory = 1 } -Inputs $OK2 -Expect '클립보드 기록이 켜져 있음' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10b' '클립보드 기록 설정 키 없음 → 시작 전 중단' -Setup { $global:ClipHistoryMode = 'nokey' } -Inputs $OK2 -Expect '클립보드 기록 설정값을 읽지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10c' '클립보드 기록 설정값 없음(키만 있음) → 시작 전 중단' -Setup { $global:ClipHistoryMode = 'novalue' } -Inputs $OK2 -Expect '클립보드 기록 설정값을 읽지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0) }
  # S10d(리뷰 O5): 클립보드 비우기 실패(다른 프로세스가 클립보드를 잡고 있다)는 조용히 삼키지 않는다 — root 토큰이 클립보드에 남았을 수 있다는 경고(값 없음)를
  # 토큰 입력 직후와 finally 에서 한 번씩 낸다. 시드 자체는 계속한다(검사 공통 단언 "클립보드에는 공백만" 은 그대로 — 쓰려던 값은 공백뿐)
  # 세션의 $WarningPreference 가 SilentlyContinue 여도 경고가 나와야 한다(블록이 자기 범위에서 Continue 로 고정한다) — 하네스 전역 값은 Post 첫 줄에서 되돌린다
  Run-Case 'S10d' '클립보드 비우기 실패(Set-Clipboard 예외 · 세션 $WarningPreference = SilentlyContinue) → 경고 2줄(토큰 입력 직후 · finally — Write-Warning · 값 없음) · 6개 생성 완주' `
    -Setup { $global:F['clipFail'] = $true; $script:wpBefore = $global:WarningPreference; $global:WarningPreference = 'SilentlyContinue' } -Inputs $OK2 `
    -Want @('클립보드를 비우지 못했다', (& $OKLINE $P5), '판정: kv 6경로 준비 완료') -Post {
      $global:WarningPreference = $script:wpBefore
      $warn = @($global:LastItems | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -and ([string]$_).Contains('클립보드를 비우지 못했다') })
      Check '클립보드 경고 2개 = WarningRecord(Write-Warning — 토큰 입력 직후 1 · finally 1)' ($warn.Count -eq 2) "경고 $($warn.Count)개"
      $tl = @([string]$global:LastText -split "`n")
      $iw = @(for ($i = 0; $i -lt $tl.Count; $i++) { if ($tl[$i].Contains('클립보드를 비우지 못했다')) { $i } })
      $iTok = -1; $iSum = -1
      for ($i = 0; $i -lt $tl.Count; $i++) { if ($iTok -lt 0 -and $tl[$i].StartsWith('OK   토큰 정책에 root 포함', [StringComparison]::Ordinal)) { $iTok = $i }; if ($iSum -lt 0 -and $tl[$i].StartsWith($SUMMARY, [StringComparison]::Ordinal)) { $iSum = $i } }
      Check '첫 경고는 토큰 확인 줄보다 앞(붙여넣은 직후) · 둘째 경고는 요약 머리보다 앞(finally 정리)' ($iw.Count -eq 2 -and $iTok -ge 0 -and $iw[0] -lt $iTok -and $iw[1] -gt $iTok -and $iSum -gt $iw[1]) "경고 줄 $($iw -join ',') · 토큰 $iTok · 요약 $iSum"
      Check '클립보드 비우기를 두 번 시도했다(값은 공백)' ($global:ClipValues.Count -eq 2 -and (Ev-Index 'clip:fail') -ge 0)
      foreach ($e in $PATHS) { Check-Created $e } }
  # S10e(리뷰 r3 O5 · 결정 C8): 붙여넣기 창의 세션 상태 — $WhatIfPreference = $true 와 $PSDefaultParameterValues['Set-Clipboard:WhatIf'] = $true(제자리 변경) 가 살아 있으면
  # finally 의 Remove-Item Env:VAULT_TOKEN 과 두 번의 Set-Clipboard 가 'What if:' 한 줄만 내고 건너뛰어진다(실측 — 예외 없음 · 경고 없음 → root 토큰이 env · 클립보드에 남는다).
  # 블록은 자기 범위에서 $WhatIfPreference = $false · $ConfirmPreference = 'High' · $PSDefaultParameterValues = @{} 를 고정해야 한다. 하네스 전역은 Post 첫 줄에서 되돌리고(Clone 교체),
  # 복원이 실제로 됐는지(제자리 변경 뒤 참조 저장은 복원 무효 — 리뷰 r4 O4)를 하네스 자체 단언으로 둔다
  Run-Case 'S10e' '세션 $WhatIfPreference = $true + $PSDefaultParameterValues[Set-Clipboard:WhatIf] = $true(붙여넣기 창) → 블록이 자기 범위에서 고정 → 클립보드 비우기 2회 실제 실행 · VAULT_* 제거 · 6개 생성 완주' `
    -Setup { $global:WhatIfPreference = $true; $global:PSDefaultParameterValues['Set-Clipboard:WhatIf'] = $true } -Inputs $OK2 `
    -Want @((& $OKLINE $P5), '판정: kv 6경로 준비 완료') -NotWant @('What if') -Post {
      $global:WhatIfPreference = $OrigWhatIf
      $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
      Check '하네스 자체: 세션 $PSDefaultParameterValues 복원 뒤 Set-Clipboard:WhatIf 키 없음(Clone 저장 · Clone 교체 복원 — 참조 저장이면 제자리 변경이 남는다 · 리뷰 r4 O4)' (-not $global:PSDefaultParameterValues.ContainsKey('Set-Clipboard:WhatIf'))
      Check '하네스 자체: 세션 $WhatIfPreference 복원' ($global:WhatIfPreference -eq $OrigWhatIf)
      Check '클립보드 비우기 2회가 실제로 실행됐다(clip:set 2 · clip:whatif 0 — ShouldProcess 를 따르는 모의)' (@($global:Events | Where-Object { SEq $_ 'clip:set' }).Count -eq 2 -and (Ev-Index 'clip:whatif') -lt 0) "clip:set $(@($global:Events | Where-Object { SEq $_ 'clip:set' }).Count) · whatif $(@($global:Events | Where-Object { SEq $_ 'clip:whatif' }).Count)"
      Check 'VAULT_* 환경 변수 0(finally 의 Remove-Item 이 WhatIf 로 건너뛰어지지 않았다)' (@(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0)
      foreach ($e in $PATHS) { Check-Created $e } }

  # ---- S11: 실행 뒤 환경 · 조건부 정리 · $Error
  Run-Case 'S11a' '정상 완주 뒤 VAULT_TOKEN·VAULT_ADDR 없음 · 블록이 남긴 전역 변수·$Error 에 값 없음' -Inputs $OK2 -Post {
      Check 'VAULT_* 환경 변수 0' (@(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0)
      $newG = @(Get-Variable -Scope Global | Where-Object { $HarnessGlobals -notcontains $_.Name -and -not ($global:GvBefore.ContainsKey($_.Name) -and [object]::ReferenceEquals($global:GvBefore[$_.Name], $_.Value)) } |
          Where-Object { $t = Flat-Text $_.Value; $t.Contains('postgresql://') -or $t.Contains('hvs.') } | ForEach-Object { $_.Name })
      Check '이 실행으로 생기거나 바뀐 전역 변수에 url·토큰 모양 문자열 0' ($newG.Count -eq 0) ($newG -join ', ')
      Check '$Error 에 블록이 남긴 기록 0(finally 가 이 실행분을 지운다)' ($global:Error.Count -eq 0) "Error $($global:Error.Count)" }
  Run-Case 'S11b' '시작 전 VAULT_TOKEN 이 이미 있음 → 토큰을 묻지 않고 중단 · 기존 값은 건드리지 않는다(조건부 정리)' -PreEnv @{ VAULT_TOKEN = $global:FAKE_PRE_TOKEN } `
    -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_PRE_TOKEN) } -Inputs $OK2 -Expect 'VAULT_* 환경 변수가 이미 있다: VAULT_TOKEN' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S11c' '시작 전 VAULT_ADDR = 기대값(http://127.0.0.1:18200) → 그대로 진행 · 끝나면 제거' -PreEnv @{ VAULT_ADDR = $global:EXPECTED_ADDR } -Inputs $OK2 `
    -Want @((& $OKLINE $P5)) -Post { foreach ($e in $PATHS) { Check-Created $e } }
  Run-Case 'S11d' '시작 전 다른 VAULT_*(VAULT_NAMESPACE) → 이름만 보이고 중단 · 기존 변수는 건드리지 않는다' -PreEnv @{ VAULT_NAMESPACE = 'MOCK-ns' } -Inputs $OK2 `
    -Expect 'VAULT_NAMESPACE' -Post {
      Check '기존 VAULT_NAMESPACE 그대로' (SEq $env:VAULT_NAMESPACE 'MOCK-ns'); Check '입력 0' ($global:ReadLog.Count -eq 0) }
  Run-Case 'S11e' '시작 전 VAULT_ADDR 가 다른 주소 → 중단 · 기존 값 그대로(어느 Vault 인지 모호)' -PreEnv @{ VAULT_ADDR = 'https://vault.example.invalid' } -Inputs $OK2 `
    -Expect 'VAULT_ADDR' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S11f' '되읽기 응답이 깨진 JSON(안에 비밀번호) → 고정 문구로 중단 · 화면·$Error 에 값 없음' -Setup { $global:F['readGarbage'][$P0.path] = 1 } -Inputs $OK2 `
    -Expect '되읽기 실패' -Want @('되읽기 응답을 해석하지 못했다') -Post { Check 'put 1회' ($global:PutCalls.Count -eq 1) }

  # ---- S12(구조 · 정적)는 맨 앞에서 관문으로 돌았다

  # ---- S13–S19: 토큰 · put · 재실행 · 그 밖의 fail-closed
  Run-Case 'S13a' 'root 토큰 빈 입력 → 중단(token lookup 0 · 쓰기 0)' -Inputs @('', 'seed') -Expect '빈 입력 — 중단' -Post {
      Check 'token lookup 0' ((Ev-Index 'vault:token-lookup') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S13b' 'root 토큰 앞뒤 공백 → Trim 뒤 정상 완주' -Inputs @((' ' + $ROOT + ' '), 'seed') -Want @((& $OKLINE $P0)) -Post { foreach ($e in $PATHS) { Check-Created $e } }
  Run-Case 'S14' '토큰 정책에 root 없음 → 판정 전 중단(metadata 조회 0 · 쓰기 0)' -Setup { $global:TokenPolicies = @('default', 'admin') } -Inputs $OK2 -Expect '토큰 정책에 root 가 없다' -Post {
      Check 'metadata 조회 0' ((Ev-First 'vault:meta-get:') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S15' 'hvs. 로 시작하지 않는 값(복구 키 조각 등) → Vault 로 보내기 전에 중단' -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_SHARE) } -Inputs @($global:FAKE_SHARE, 'seed') `
    -Expect '입력이 Vault 토큰 형식' -Post { Check 'token lookup 0(Vault 로 보내지 않았다)' ((Ev-Index 'vault:token-lookup') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  # S16 · S16d · S16e(리뷰 r3 O6 · 결정 C8): put 비 0 = CAS 거부 · 권한 · 연결 · "응답 유실 뒤 CLI 자동 재시도(VAULT_MAX_RETRIES 기본 2)가 자기 기록과 CAS 충돌" 중 하나 —
  # 종료 코드 · 문구로 가를 수 없다(putLost 결함은 진짜 CAS 충돌과 같은 exit 2 · 같은 문구). 블록은 값을 출력하지 않고 재판정한다:
  #   absent → "쓰지 않았다"(S16) / live v1 + 되읽기 해시 일치 → 기록됨(응답 유실 — 이 실행의 값) · cv=1 확인 · 다음 경로로 계속(S16d) / live v1 + 해시 불일치 → CAS 충돌(다른 값) STOP(S08a) /
  #   재판정 자체가 일시 오류 → 결과 미확인(지우지 말고 재실행 · S16e)
  Run-Case 'S16' 'put 거부(권한 등 비 0 · 경로는 그대로 없음) → 재판정 absent = 쓰지 않았다 · 그 경로에서 중단 · 뒤 경로 미실행("쓰지 않았다" 는 재판정 뒤에만 말한다)' -Setup { $global:F['putFail'][$P0.path] = 2 } -Inputs $OK2 -Expect 'put 거부' `
    -Want @("STOP $($P0.path) — put 거부(exit=2) · 재판정 absent", '중단(put 거부 exit=2 — 재판정 absent · 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 0건') -NotWant @('기록됨(응답 유실', '결과 미확인 1', 'CAS 충돌') -Post {
      Check 'put 1회' ($global:PutCalls.Count -eq 1); foreach ($e in $PATHS) { Check-Absent $e }
      $ip = Ev-Index "vault:put:$($P0.path)"
      Check '재판정: put 거부 뒤 metadata get 1 · kv get 0(absent 라 되읽지 않는다)' ($ip -ge 0 -and (Ev-Index "vault:meta-get:$($P0.path)" ($ip + 1)) -gt $ip -and (Ev-First 'vault:kv-get:') -lt 0) }
  Run-Case 'S16d' 'put 응답 유실(서버는 커밋 · CLI 재시도가 자기 기록과 CAS 충돌 → exit 2 · 진짜 충돌과 같은 문구) → 재판정 live v1 · 되읽기 해시 일치 → 기록됨(응답 유실 — 이 실행의 값) · cv=1 확인 · 뒤 경로 계속 · 6개 완주' `
    -Setup { $global:F['putLost'][$P0.path] = 1 } -Inputs $OK2 `
    -Want @("OK   $($P0.path) v1 — 기록됨(응답 유실 — 이 실행의 값 · put exit=2 뒤 재판정) · 되읽기 해시 일치(username·password·url)", (& $OKLINE $P1), (& $OKLINE $P5), '응답 유실 뒤 재판정으로 검증 완료 1', '판정: kv 6경로 준비 완료') `
    -NotWant @('STOP ', 'CAS 충돌', '결과 미확인 1') -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      $row = Summary-Row $P0.path
      Check "요약 행($($P0.path)) = 기록됨(응답 유실 — 이 실행의 값 …) · 되읽기 해시 일치(username·password·url)" ($row.Contains('기록됨(응답 유실 — 이 실행의 값') -and $row.Contains('되읽기 해시 일치(username·password·url)')) $row
      Check 'put 6회(유실 경로를 다시 put 하지 않는다 — 재판정으로 가른다)' ($global:PutCalls.Count -eq 6)
      $ip = Ev-Index "vault:put:$($P0.path)"; $im = Ev-Index "vault:meta-get:$($P0.path)" ($ip + 1); $ig = Ev-Index "vault:kv-get:$($P0.path)" ($ip + 1); $im2 = Ev-Index "vault:meta-get:$($P0.path)" ($ig + 1)
      Check '재판정 순서: put(exit 2) → metadata get(live v1) → kv get(해시 대조) → metadata get(cv=1 확인) → 다음 경로 put' ($ip -ge 0 -and $im -gt $ip -and $ig -gt $im -and $im2 -gt $ig -and (Ev-Index "vault:put:$($P1.path)") -gt $im2) "put=$ip meta=$im get=$ig meta2=$im2"
      Check-WriteOrder $PATHS }
  Run-Case 'S16e' 'put 비 0 뒤 재판정 자체가 일시 오류(metadata 500) → 결과 미확인(이 실행의 값이 기록됐는지 모른다 — 지우지 말고 재실행) · 그 자리에서 중단 · 뒤 경로 put 0' `
    -Setup { $global:F['putFail'][$P1.path] = 2; $global:F['postMeta'][$P1.path] = 'err' } -Inputs $OK2 -Expect '결과 미확인' `
    -Want @("STOP $($P1.path) — put 거부(exit=2) · 재판정 error(current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)", (& $OKLINE $P0), '결과 미확인(put exit=2 — 재판정 error · current_version=-1 · 재실행이 판정한다)', '결과 미확인 1 ·', '판정: 미완', '미실행(앞 경로에서 중단 — 쓰지 않았다)') `
    -NotWant @("OK   $($P1.path)", 'CAS 충돌', '기록됨(응답 유실') -Post {
      $row = Summary-Row $P1.path
      Check "요약 행($($P1.path)) = 결과 미확인 · '쓰지 않았다' 없음" ($row.Contains('결과 미확인(put exit=2 — 재판정 error') -and -not $row.Contains('쓰지 않았다')) $row
      Check-Created $P0
      foreach ($e in @($P1, $P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 2회(뒤 경로 put 0)' ($global:PutCalls.Count -eq 2)
      $ip = Ev-Index "vault:put:$($P1.path)"
      Check '재판정: put 거부 뒤 metadata get(500) · kv get 0' ($ip -ge 0 -and (Ev-Index "vault:meta-get:$($P1.path)" ($ip + 1)) -gt $ip -and (Ev-Index "vault:kv-get:$($P1.path)") -lt 0) }
  Run-Case 'S17' '재실행: 6경로 모두 live-ok → 6 SKIP · 쓰기 0 · 쓰기 확인 정지점 없음' -Setup { foreach ($e in $PATHS) { Seed-LiveOk $e } } -Inputs @($ROOT) `
    -Want (@($PATHS | ForEach-Object { & $SKIPLINE $_ }) + @('INFO 쓸 경로 없음', '이 실행이 kv 에 새로 쓴 경로: 0건')) -NotWant @('STOP ', '쓸 경로 6개') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰만)' ($global:ReadLog.Count -eq 1)
      foreach ($e in $PATHS) { Check-Unchanged $e $LIVE_PW[$e.path] } }
  Run-Case 'S18' '~/.vault-token 존재 → 시작 전 중단' -Setup { $global:VaultTokenFile = $true } -Inputs $OK2 -Expect '~/.vault-token 존재' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S19' 'live 판정 중 kv get 실패 → 판정 불가 · 쓰기 0' -Setup { Seed-LiveOk $P0; $global:F['readFail'][$P0.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($P0.path) — 판정 불가: kv get exit=2") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }
  # S19b(리뷰 O4): 판정 단계의 kv get 응답 해석 실패(잘린 JSON — 일시 상태)는 live-mismatch(런북 조치 = 되돌릴 수 없는 「정리 판단」)가 아니라 판정 불가(조치 = 재실행)다
  Run-Case 'S19b' 'live 판정 중 kv get 응답이 깨진 JSON(안에 비밀번호) → 판정 불가(재실행 — live-mismatch 아님) · 쓰기 0 · 화면 · $Error 에 값 없음' `
    -Setup { Seed-LiveOk $P0; $global:F['readGarbage'][$P0.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($P0.path) — 판정 불가: kv get 응답을 해석하지 못했다(원문 미출력)", '중단(판정 불가 — kv get 응답을 해석하지 못했다(원문 미출력))') -NotWant @('live-mismatch') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰 — 쓰기 확인 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1)
      Check-Unchanged $P0 $LIVE_PW[$P0.path] }

  # ---- S20: 쓰기 뒤 metadata 판정(current_version=1 · 삭제 없음)을 행동으로 단언 — put 이 성공한 뒤의 metadata 응답만 바꾼다(2026-10-14 리뷰 O2)
  Run-Case 'S20a' '쓰기 뒤 metadata 가 current_version 2(다른 기록자 — v2 도 live) → 메타데이터 확인 실패로 중단 · 뒤 경로 put 0' `
    -Setup { $global:F['postMeta'][$P1.path] = 'cv2' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($P1.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(live · current_version=2", (& $OKLINE $P0), '기록됨 — 메타데이터 확인 실패(live · current_version=2)', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 2건') `
    -NotWant @("OK   $($P1.path)") -Post {
      Check-Created $P0
      Check "$($P1.path): put 은 됐다(v1)" ((KvCur $P1.path) -eq 1)
      foreach ($e in @($P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 2회(뒤 경로 put 0)' ($global:PutCalls.Count -eq 2) }
  Run-Case 'S20b' '쓰기 뒤 metadata 의 현재 버전에 deletion_time(마운트 delete_version_after 의 삭제 예약) → dead 로 중단 · 뒤 경로 put 0' `
    -Setup { $global:F['postMeta'][$P0.path] = 'deletion' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($P0.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(dead · current_version=1", '기록됨 — 메타데이터 확인 실패(dead · current_version=1)', '이 실행이 kv 에 새로 쓴 경로: 1건') `
    -NotWant @("OK   $($P0.path)") -Post {
      Check "$($P0.path): put 은 됐다(v1)" ((KvCur $P0.path) -eq 1)
      foreach ($e in @($P1, $P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 1회(뒤 경로 put 0)' ($global:PutCalls.Count -eq 1) }
  # S20c(리뷰 r3 O3): 쓰기 뒤 metadata 조회의 일시 오류(kind=error)도 OK 가 아니라 "메타데이터 확인 실패" 다 — 조건을 dead · live∧cv≠1 로 좁힌 변이(mC)는 오류를 OK 로 통과시켰다
  Run-Case 'S20c' '쓰기 뒤 metadata 조회가 일시 오류(500 · kind=error) → 메타데이터 확인 실패로 중단(OK 아님) · 요약 기록됨 — 메타데이터 확인 실패(error …) · 뒤 경로 put 0(런북 조치 = 재실행 → live-ok SKIP)' `
    -Setup { $global:F['postMeta'][$P0.path] = 'err' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($P0.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(error · current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)", '기록됨 — 메타데이터 확인 실패(error · current_version=-1)', '이 실행이 kv 에 새로 쓴 경로: 1건') `
    -NotWant @("OK   $($P0.path)") -Post {
      Check "$($P0.path): put 은 됐다(v1)" ((KvCur $P0.path) -eq 1)
      foreach ($e in @($P1, $P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 1회(뒤 경로 put 0)' ($global:PutCalls.Count -eq 1) }

  # ---- S21: put 도중 중단(서버는 커밋) — 요약이 "쓰지 않았다"로 남지 않는다 · 재실행이 판정한다(2026-10-14 리뷰 O4)
  Run-Case 'S21a' 'put 도중 중단(Ctrl+C 대용 — 서버는 이미 커밋) → 요약 행 = 결과 미확인("쓰지 않았다" 아님) · 집계 결과 미확인 1 · 판정 미완' `
    -Setup { $global:F['putInterrupt'][$P0.path] = 1 } -Inputs $OK2 -Expect '모의 중단' `
    -Want @('결과 미확인 1 ·', '판정: 미완', $SUMMARY, '창 종료 체크리스트') -NotWant @("OK   $($P0.path)") -Post {
      $row = Summary-Row $P0.path
      Check "요약 행($($P0.path)) = 결과 미확인 · '쓰지 않았다' 없음" ($row.Contains('결과 미확인(put 진행 중 중단') -and -not $row.Contains('쓰지 않았다')) $row
      Check "$($P0.path): 서버 쪽은 커밋됐다(v1)" ((KvCur $P0.path) -eq 1)
      foreach ($e in @($P1, $P2, $P3, $P4, $P5)) { Check-Absent $e }
      Check 'put 1회' ($global:PutCalls.Count -eq 1) }
  Run-Case 'S21b' '재실행 복구: S21a 상태에서 다시 실행 → 결과 미확인 경로는 live-ok 로 SKIP(덮어쓰기 0) · 나머지 5 생성' `
    -Setup { $global:F['putInterrupt'][$P0.path] = 1; Invoke-PreRun @($global:FAKE_ROOT, 'seed') } -Inputs $OK2 `
    -Want @((& $SKIPLINE $P0), (& $OKLINE $P1), (& $OKLINE $P5), '판정: kv 6경로 준비 완료') -NotWant @('STOP ') -Post {
      Check '사전 실행은 첫 경로 put 도중 멈췄다(put 1)' ($global:PreRunPuts -eq 1) "사전 put $($global:PreRunPuts)"
      foreach ($e in $PATHS) { Check-Created $e }
      Check '본 실행 put 5회(결과 미확인 경로 put 0)' ($global:PutCalls.Count -eq 5 -and @($global:PutCalls | Where-Object { SEq $_.path $P0.path }).Count -eq 0) }

  # ---- S22: PowerShell 모듈 로깅 정책(켜져 있으면 ConvertFrom-Json 의 InputObject — kv · token lookup 응답 원문 — 이 이벤트 4103 에 남는다 · 리뷰 O5)
  $PC_LM = $global:PolicyPaths[0]; $PC_CU = $global:PolicyPaths[1]; $WP_LM = $global:PolicyPaths[2]
  foreach ($c in @(@('S22a', 'PowerShellCore 모듈 로깅 켜짐(HKLM)', @{ $PC_LM = @{ EnableModuleLogging = 1 } }),
      @('S22b', 'PowerShellCore 모듈 로깅 켜짐(HKCU)', @{ $PC_CU = @{ EnableModuleLogging = 1 } }),
      @('S22c', 'UseWindowsPowerShellPolicySetting=1 + Windows PowerShell 모듈 로깅 켜짐(HKLM)', @{ $PC_LM = @{ UseWindowsPowerShellPolicySetting = 1 }; $WP_LM = @{ EnableModuleLogging = 1 } }))) {
    $script:pol22 = $c[2]
    Run-Case $c[0] "$($c[1]) → 시작 전 중단(입력 0 · vault 호출 0)" -Setup { foreach ($k in @($script:pol22.Keys)) { $global:Policy[$k] = $script:pol22[$k] } } -Inputs $OK2 `
      -Expect '모듈 로깅 정책이 켜져 있다' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) } }
  Run-Case 'S22d' 'UseWindowsPowerShellPolicySetting=1 · 양쪽 EnableModuleLogging=0 → 그대로 진행(6개 생성) · 정책 키 4개를 모두 읽었다' `
    -Setup { $global:Policy[$PC_LM] = @{ UseWindowsPowerShellPolicySetting = 1; EnableModuleLogging = 0 }; $global:Policy[$WP_LM] = @{ EnableModuleLogging = 0 } } -Inputs $OK2 `
    -Want @((& $OKLINE $P5)) -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      Check '정책 키 4개(PowerShellCore 2 · Windows PowerShell 2)를 읽었다' (@($global:PolicyPaths | Where-Object { (Ev-Index "reg:policy:$_") -ge 0 }).Count -eq 4) }

  # ---- 런북 「정리 판단」 두 블록(수정 라운드 4 — 리뷰 r3 O7 · 결정 C6): R1 · R2 정적(관문 6) → GA(① 점검 · vault 쓰기 명령 0 — GA01–GA08) · GB(② 삭제 · 설계 번호 G1–G9 = GB01–GB10 + GB11 · GB12)
  #      가짜 kv 에는 6경로 밖의 소비 중인 경로(kv/platform/cloudflare/tunnel · 가짜 토큰)도 둔다 — 허용 목록 밖 입력이 그 경로에 닿지 않는지(vault 호출 0) 본다
  $MI = '[t054-cleanup-inspect]'; $MD = '[t054-cleanup-delete]'
  $TUN = 'kv/platform/cloudflare/tunnel'
  $TUNTOK = 'MOCK-tunnel-token-Hx8Kq2Lw9Pz4Rt7Vb3Nm6Yc1Jd5Fs0Gp'
  function Seed-Tunnel { Seed-Path $TUN ([ordered]@{ token = $TUNTOK }); [void]$global:ExtraSecrets.Add($TUNTOK) }
  $gateR1 = Run-RbStatic 'R1' '런북 ① 점검 블록(읽기 전용) 정적: 코드 펜스 추출(표식 1 · 들여쓰기 제거) · 첫 줄 & { · 표식 주석 · 끝 } · 빈 줄 0 · TAB 0 · CR 0 · 파서 오류 0 · 최상위 1문 · 명령/형식/$Host/리다이렉트 허용 목록(관문) · Read-Host 1곳 평문 + 바로 앞 비움(AST) · vault = kv metadata get · kv get -format=json 만(put · delete 0) · MOCK/비밀 상수/hvs./Start-Transcript/env 쓰기 0' $MI @('kv metadata get -format=json', 'kv get -format=json') 1
  $gateR2 = Run-RbStatic 'R2' '런북 ② 삭제 블록 정적: 같은 검사 · Read-Host 2곳 평문(경로 · 재입력) + 바로 앞 비움 · vault = kv metadata get -format=json · kv metadata delete 만(put · kv get 0)' $MD @('kv metadata get -format=json', 'kv metadata delete') 2
  if ($gateR1) { Write-Host "관문 FAIL(R1): $gateR1 — GA 시나리오(① 점검 블록 실행)를 돌리지 않는다" -ForegroundColor Red }
  else {
    Run-RbCase 'GA01' '① 점검: live 경로 → 상태 · current_version · delete_version_after · 버전 이력(값 없음) · 현재 버전 키 이름만 · vault = metadata get 1 + kv get 1 · 쓰기 명령 0 · 값 노출 0' $MI `
      -Setup { Seed-LiveOk $P0; Seed-Tunnel } -Inputs @($P0.path) `
      -Want @("$($P0.path) — current_version=1 · delete_version_after=0s", '  v1  created=2026-10-13T00:00:00Z  deletion_time=  destroyed=False', '현재 버전 키 이름(값 미출력): password · url · username', '점검 끝 — 이 블록은 아무것도 쓰지 않았다') -NotWant @('OK   ') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1(그 밖 0)' ((Ev-Index "vault:meta-get:$($P0.path)") -ge 0 -and (Ev-Index "vault:kv-get:$($P0.path)") -gt (Ev-Index "vault:meta-get:$($P0.path)") -and @($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check '입력 1(경로)' ($global:ReadLog.Count -eq 1)
        Check-Unchanged $P0 $LIVE_PW[$P0.path] }
    Run-RbCase 'GA02' '① 점검: absent 경로 → "absent(메타데이터 없음 …)" 한 줄 · vault = metadata get 1 · kv get 0' $MI -Setup { Seed-Tunnel } -Inputs @($P1.path) `
      -Want @("$($P1.path) — absent(메타데이터 없음") -Post {
        Check 'vault 호출 = metadata get 1 만' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 1 -and (Ev-First 'vault:kv-get:') -lt 0) }
    foreach ($c in @(@('GA03a', '6경로 밖(소비 중인 kv/platform/cloudflare/tunnel)', $TUN), @('GA03b', '끝 공백이 붙은 경로', ($P0.path + ' ')), @('GA03c', '대소문자가 다른 경로(Ordinal)', $P0.path.ToUpperInvariant()))) {
      $script:ga3 = $c[2]
      Run-RbCase $c[0] "① 점검: $($c[1]) → vault 호출 0 으로 중단(아무것도 조회하지 않았다)" $MI -Setup { Seed-LiveOk $P0; Seed-Tunnel } -Inputs @($script:ga3) -Expect '6경로 밖이다' -Post {
          Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0); Check '입력 1' ($global:ReadLog.Count -eq 1) } }
    Run-RbCase 'GA04' '① 점검: dead(현재 버전 soft-delete) → deletion_time 이 보이고 현재 버전 데이터 없음 · 값 노출 0' $MI `
      -Setup { Seed-Path $P2.path (Live-Data $P2) 1 '2026-10-13T05:00:00Z'; Seed-Tunnel } -Inputs @($P2.path) `
      -Want @("$($P2.path) — current_version=1", '  v1  created=2026-10-13T00:00:00Z  deletion_time=2026-10-13T05:00:00Z  destroyed=False', '현재 버전 데이터: 없음(soft-delete · destroy)') -Post {
        Check '버전 불변' ((KvCur $P2.path) -eq 1) }
    Run-RbCase 'GA05' '① 점검: metadata 조회 일시 오류(500) → 판정 불가로 중단 · kv get 0' $MI -Setup { Seed-LiveOk $P0; $global:F['metaError'][$P0.path] = 1 } -Inputs @($P0.path) -Expect 'metadata 조회 실패(exit=2)' -Post {
        Check 'kv get 0' ((Ev-First 'vault:kv-get:') -lt 0) }
    Run-RbCase 'GA06' '① 점검: metadata 는 live 인데 kv get 이 비 0 → "현재 버전 데이터: 읽지 못했다" 로 끝난다(값 없음 · 완주)' $MI -Setup { Seed-LiveOk $P0; $global:F['readFail'][$P0.path] = 1 } -Inputs @($P0.path) `
      -Want @("$($P0.path) — current_version=1", '현재 버전 데이터: 읽지 못했다') -Post { Check-Unchanged $P0 $LIVE_PW[$P0.path] }
    Run-RbCase 'GA07' '① 점검: 메타데이터만 있고 버전 없음(current_version 0) → 이력 0행 · 데이터 읽지 못했다 · 쓰기 0' $MI -Setup { Seed-Path $P3.path $null 0 } -Inputs @($P3.path) `
      -Want @("$($P3.path) — current_version=0", '현재 버전 데이터: 읽지 못했다') -NotWant @('  v1  ') -Post { Check 'kv 그대로' ($global:Kv.ContainsKey($P3.path)) }
    # GA08(수정 라운드 6 — 리뷰 r6 O5): ① 점검 블록의 과도기 상태 — metadata 는 live 인데 kv get 응답이 잘린 JSON(안에 비밀번호 · 모의 readGarbage). 블록은 ConvertFrom-Json 을
    #   $ErrorActionPreference = 'Stop' 아래 직접 부르므로 종료 오류가 콘솔 · $Error 에 남는다 — 그 오류 문구 · TargetObject · 예외 전문 어디에도 값이 없어야 한다(노출 0 공통 단언 · 2026-10-15 실측:
    #   ConvertFrom-Json 오류는 키 경로 · 위치만 싣는다). 쓰기 0 · 값 불변. 노출이 잡혔다면 ① 블록의 ConvertFrom-Json 을 try/catch 로 감싸는 것이 조치였다(잡히지 않아 블록은 그대로)
    Run-RbCase 'GA08' '① 점검: kv get 응답이 깨진 JSON(안에 비밀번호 — 과도기 상태) → ConvertFrom-Json 종료 오류로 중단 · 화면 · $Error 에 값 없음 · 쓰기 0 · 값 불변' $MI `
      -Setup { Seed-LiveOk $P0; Seed-Tunnel; $global:F['readGarbage'][$P0.path] = 1 } -Inputs @($P0.path) -Expect 'Unexpected end when reading token' `
      -Want @("$($P0.path) — current_version=1 · delete_version_after=0s") -NotWant @('현재 버전 키 이름', '점검 끝') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1(그 밖 0)' ((Ev-Index "vault:meta-get:$($P0.path)") -ge 0 -and (Ev-Index "vault:kv-get:$($P0.path)") -gt (Ev-Index "vault:meta-get:$($P0.path)") -and @($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check '입력 1(경로)' ($global:ReadLog.Count -eq 1)
        Check-Unchanged $P0 $LIVE_PW[$P0.path] } }
  if ($gateR2) { Write-Host "관문 FAIL(R2): $gateR2 — GB 시나리오(② 삭제 블록 실행)를 돌리지 않는다" -ForegroundColor Red }
  else {
    # 공통 준비: P0 · P1 live(지울 수 있는 두 경로) + 6경로 밖 소비 중 경로(터널 토큰)
    foreach ($c in @(@('GB01', '6경로 밖(소비 중인 kv/platform/cloudflare/tunnel)', $TUN), @('GB02', '끝 공백이 붙은 경로', ($P0.path + ' ')), @('GB03', '대소문자가 다른 경로(Ordinal)', $P0.path.ToUpperInvariant()))) {
      $script:gb1 = $c[2]
      Run-RbCase $c[0] "② 삭제: $($c[1]) → vault 호출 0 · 삭제 0 으로 중단(G1–G3)" $MD -AllowDelete -Setup { Seed-LiveOk $P0; Seed-LiveOk $P1; Seed-Tunnel } -Inputs @($script:gb1, $script:gb1) -Expect '6경로 밖이다' -Post {
          Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0); Check '입력 1(재입력을 묻지 않았다)' ($global:ReadLog.Count -eq 1)
          Check 'kv 6경로 밖 경로 그대로' ($global:Kv.ContainsKey($TUN)); Check-Unchanged $P0 $LIVE_PW[$P0.path]; Check-Unchanged $P1 $LIVE_PW[$P1.path] } }
    foreach ($c in @(@('GB04', '재입력이 다른 6경로(owner → app)', $P1.path), @('GB05', '재입력 빈 Enter', ''), @('GB06', '재입력 끝 공백', ($P0.path + ' ')))) {
      $script:gb4 = $c[2]
      Run-RbCase $c[0] "② 삭제: 경로 입력 뒤 $($c[1]) → 삭제 0 으로 중단(G4–G5 · 재입력 Ordinal 일치만 통과)" $MD -AllowDelete -Setup { Seed-LiveOk $P0; Seed-LiveOk $P1; Seed-Tunnel } -Inputs @($P0.path, $script:gb4) -Expect '입력이 경로와 다르다' -Post {
          Check 'metadata get 1 · delete 0' ((Ev-Index "vault:meta-get:$($P0.path)") -ge 0 -and (Ev-First 'vault:meta-delete:') -lt 0)
          Check '입력 2' ($global:ReadLog.Count -eq 2); Check-Unchanged $P0 $LIVE_PW[$P0.path]; Check-Unchanged $P1 $LIVE_PW[$P1.path] } }
    Run-RbCase 'GB07' '② 삭제: 정확한 재입력 → metadata get → delete → metadata get(No value found) → OK · 그 경로만 사라짐(G6)' $MD -AllowDelete -Setup { Seed-LiveOk $P0; Seed-LiveOk $P1; Seed-Tunnel } -Inputs @($P0.path, $P0.path) `
      -Want @("OK   $($P0.path) — 모든 버전 · 메타데이터 삭제(No value found 확인)") -Post {
        Check "$($P0.path) 가 kv 에서 사라졌다" (-not $global:Kv.ContainsKey($P0.path))
        Check-Unchanged $P1 $LIVE_PW[$P1.path]; Check '6경로 밖 경로 그대로' ($global:Kv.ContainsKey($TUN))
        $i1 = Ev-Index "vault:meta-get:$($P0.path)"; $id = Ev-Index "vault:meta-delete:$($P0.path)"; $i2 = Ev-Index "vault:meta-get:$($P0.path)" ($id + 1)
        Check '순서: metadata get → metadata delete → metadata get(삭제 확인) · vault 호출 3' ($i1 -ge 0 -and $id -gt $i1 -and $i2 -gt $id -and $global:ArgvLog.Count -eq 3) "get=$i1 del=$id get2=$i2 argv=$($global:ArgvLog.Count)"
        Check '둘째 프롬프트에 "되돌릴 수 없다" · current_version' ($global:Prompts.Count -eq 2 -and ([string]$global:Prompts[1]).Contains('되돌릴 수 없다') -and ([string]$global:Prompts[1]).Contains('current_version=1')) }
    Run-RbCase 'GB08' '② 삭제: metadata 조회 실패(500) → 재입력을 묻지 않고 중단 · 삭제 0(G7)' $MD -AllowDelete -Setup { Seed-LiveOk $P0; $global:F['metaError'][$P0.path] = 1 } -Inputs @($P0.path, $P0.path) -Expect 'metadata 조회 실패(exit=2)' -Post {
        Check '입력 1 · delete 0' ($global:ReadLog.Count -eq 1 -and (Ev-First 'vault:meta-delete:') -lt 0); Check-Unchanged $P0 $LIVE_PW[$P0.path] }
    Run-RbCase 'GB09' '② 삭제: delete 가 비 0(권한 거부) → "삭제 실패" 로 중단 · 경로 그대로(G8)' $MD -AllowDelete -Setup { Seed-LiveOk $P0; $global:F['delFail'][$P0.path] = 1 } -Inputs @($P0.path, $P0.path) -Expect '삭제 실패(exit=2)' -NotWant @('OK   ') -Post {
        Check-Unchanged $P0 $LIVE_PW[$P0.path] }
    Run-RbCase 'GB10' '② 삭제: delete 는 exit 0 인데 경로가 남아 있다 → 삭제 뒤 확인(No value found 아님)으로 중단(G9)' $MD -AllowDelete -Setup { Seed-LiveOk $P0; $global:F['delNoop'][$P0.path] = 1 } -Inputs @($P0.path, $P0.path) -Expect '삭제 확인 실패(경로가 남았거나 조회 오류)' -NotWant @('OK   ') -Post {
        Check '경로가 남아 있다(모의 noop)' ($global:Kv.ContainsKey($P0.path)); Check 'metadata get 2(삭제 전 · 삭제 뒤 확인)' (@($global:Events | Where-Object { SEq $_ "vault:meta-get:$($P0.path)" }).Count -eq 2) }
    Run-RbCase 'GB11' '② 삭제: 경로가 이미 없다(absent) → "지울 것이 없다" 로 중단 · 재입력 없음 · delete 0(GB11)' $MD -AllowDelete -Setup { Seed-LiveOk $P1 } -Inputs @($P0.path, $P0.path) -Expect '이미 없다(absent)' -Post {
        Check '입력 1 · delete 0' ($global:ReadLog.Count -eq 1 -and (Ev-First 'vault:meta-delete:') -lt 0) }
    Run-RbCase 'GB12' '② 삭제: 삭제는 됐는데 삭제 뒤 확인 조회가 500 → "없어졌다" 로 보지 않고 삭제 확인 실패로 중단(OK 아님 · GB12)' $MD -AllowDelete -Setup { Seed-LiveOk $P0; $global:F['postDelErr'][$P0.path] = 1 } -Inputs @($P0.path, $P0.path) -Expect '삭제 확인 실패(경로가 남았거나 조회 오류)' -NotWant @('OK   ') -Post {
        Check '삭제는 됐다(모의)' (-not $global:Kv.ContainsKey($P0.path) -and (Ev-Index "vault:meta-delete:$($P0.path)") -ge 0) } }
}
catch {
  # 관문 FAIL 로 멈춘 경우만 여기서 삼킨다(결과 표 · exit 1 은 아래) — 그 밖의 예외(하네스 결함)는 그대로 다시 던진다
  if (-not $GateMsg) { throw }
}
finally {
  # 세션 설정을 먼저 되돌린다(S10e 가 바꾼 WhatIf · 기본 매개변수 값이 남아 있으면 아래 Remove-Item 이 건너뛰어진다)
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $env:PATH = $OrigPath
  if ($null -eq $OrigKubeconfig) { Remove-Item -LiteralPath Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $OrigKubeconfig }
  Remove-Item -LiteralPath $TrapDir -Recurse -Force -ErrorAction SilentlyContinue
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) }
}

# ---------------------------------------------------------------- 결과
Write-Host "`n=== 결과 ==="
if ($GateMsg) { Write-Host "관문 FAIL(S12 정적 허용 목록) — 런타임 시나리오 0개 실행(블록 실행 0회): $GateMsg" }
foreach ($r in $Results) { Write-Host ("{0} {1,-5} ({2,3}/{3,3}) {4}{5}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.id, ($r.total - $r.failed), $r.total, $r.desc, $(if ($r.pass) { '' } else { "`n        ↳ " + $r.detail })) }
$cases = $Results.Count
$casePass = @($Results | Where-Object { $_.pass }).Count
$checks = 0; $checkFail = 0; foreach ($r in $Results) { $checks += $r.total; $checkFail += $r.failed }
Write-Host ("시나리오 PASS {0} / {1}" -f $casePass, $cases)
Write-Host ("PASS {0} / {1}   (단언 수 — 시나리오 {2}개 · 정적 구조 검사 S12 · 런북 블록 R1 · R2 포함 · 실물 vault/kubectl 호출 0 가드)" -f ($checks - $checkFail), $checks, $cases)
if ($GateMsg -or $casePass -ne $cases -or $checkFail -gt 0) { exit 1 }
exit 0
