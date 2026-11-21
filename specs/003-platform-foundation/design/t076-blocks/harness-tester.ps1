param([string]$Show = '', [string]$Dir = '', [string]$Only = '')
# ===== T076 tester 블록 모의 실행 하네스 — O-8(o8-probe-identity-m2m.ps1) · C-8(c8-correlate-logs.ps1) · L-8(l8-live-identity-admin.ps1) =====
# 파생: T075 harness.ps1(닫힌 과제 — 고치지 않는다) B부의 모의 방식 — 함정 PATH(kubectl · vault · tofu .cmd) · 함수 가림 · KUBECONFIG 덮기 · 공통 사후 조건(노출 0 · 위반 0 · 함정 표식 0 ·
#   성공 스트림 0 · 첫 동작 Set-PSDebug -Off · 모듈 로깅 정책 · 실효 확인이 값 동작보다 먼저 · 화면 제어 문자 0 · $Error 정리 · 새 전역 변수 노출 0)과 정적 관문(파서 · 명령 · 정적 형식 ·
#   $Host · 리다이렉트 = 관문 5 + 블록 구조 · 세션 고정 · finally · 모듈 로깅 문장 꼴 · 대입 제한)을 tester 블록 계약(설계 t076-design.md D3 · D8)에 맞춰 바꿨다:
#   ① Read-Host 0 · 입력은 param 뿐(줄 1 = param 줄 · 줄 2 = & {) · 끝 두 문장 = exit 0 / exit 1 · 끝 줄 <블록>=PASS n/n | =FAIL k/n · 종료 코드 단언
#   ② HTTP 모의는 Ingress 표를 모델로 갖는다(F3-7 — 모델링하지 않은 경로를 404 로 돌리면 거짓 PASS): m2m 호스트 = /api · /session · /sessions · /tenants Prefix(글자 접두 — VD-L9) ·
#      /health Exact · 그 밖 Traefik 404(text/plain; charset=utf-8 · 「404 page not found」+LF 19 B · DYNAMIC) · pod 규칙(헬스 셋 · 웹훅 = Access 면제 + HMAC 401 · CN 불일치 403 problem+json ·
#      변이 꼴 pod 404 problem+json) · Access(무헤더 401 · 가짜 자격 401 · tester-m2m 통과) · admin 호스트 302(Location 쿼리에 meta 토큰 — 바늘)
#   ③ Vault HTTP 모의(127.0.0.1 리스너 모형 — kubectl 이 127.0.0.1 에서 Running 일 때만 그 포트가 답한다 · 끊긴 포트는 curl exit 7 · [::1]만 띄운 사례는 127.0.0.1 의 같은 포트를 남이 쥐고
#      Vault 로 중계하는 모형(S-04)): seal-status · login(본문 JSON · JWT 대조) · capabilities-self · kv · revoke-self
#   ④ kubectl 모의(--kubeconfig 리터럴 · whoami · port-forward --address 127.0.0.1 svc/vault :8200(포트는 모의 kubectl 이 고른다 — 실행마다 다르다) · get -o json 픽스처 · logs 픽스처 —
#      운영자 IP · UA · ClientHost 가 든 Traefik 줄) · Start-ThreadJob 모의(스크립트블록을 그 자리에서 모의 kubectl 로 돌려 출력 줄을 받는다 — 실물 스레드 작업은 띄우지 않는다 · 상태는
#      시작 직후 NotStarted(실측) · 출력은 한 번 늦게 보인다 · 연결마다 「Handling connection for <포트>」 줄이 붙는다) · Stop-Job · Remove-Job · Receive-Job(-Keep 필수) · Start-Sleep(기다리지 않는다)
#   ⑤ LOCALAPPDATA 를 시나리오마다 임시 디렉터리로 돌리고 DPAPI JWT 파일 픽스처를 하네스가 ConvertFrom-SecureString 으로 만든다(블록은 실물 [System.IO.File] · ConvertTo-SecureString 으로 읽는다)
#   ⑥ 노출 바늘 = JWT · Vault 토큰 · accessor · client_secret · 쿠키 · admin meta 토큰(전체 · base64 · 8자 이상 조각 · SHA-256 hex) + client_id · 운영자 IP · UA · ClientHost · ClientAddr ·
#      ClientUsername · ServiceAddr(전체) — 화면 · argv · $Error · 환경 변수 · 모의 호출 시점 환경 변수 · 새 전역 변수 · 블록 디렉터리 · 임시 LOCALAPPDATA 의 새 파일 · 7자 이하 조각은 범위 밖(S-08)
#   ⑦ 요청별 사후 조건(S-02): 헤더 이름 집합(O-8 m2m = 정확히 {CF-Access-Client-Id, CF-Access-Client-Secret, X-Request-ID} · Vault seal · 로그인 = stdin 헤더 0(로그인 argv -H =
#      Content-Type: application/json 하나) · Vault 토큰 요청 = 정확히 {X-Vault-Token} · L-8 = 0) · 자격의 길 = 바늘 집합(client_id · client_secret 은 m2m 요청의 그 두 헤더 값에만 ·
#      JWT 는 로그인 본문 jwt 값에만 · Vault 토큰은 X-Vault-Token 값에만 — URL · 다른 헤더 · 다른 본문 · argv 0)
#   ⑧ Get-Command 모의: 형식 필터 없는 질의만 받는다 · 정상 = Application 꼴 객체 · 사례가 Function · Alias 첫 해석(같은 이름 함수 · 별칭 가림)을 돌려준다(S-10)
#   ⑨ r2(확인 리뷰 rv2 — RO2-01 · S2-04): O-8 Forwarding 줄 기다림 = 90회 · 45 s(ST-O8 기다림 꼴 · O8-19b 출력 40회 지연 → PASS · O8-23c 상한 90회) · seal-status 기다림
#      30회 · 15 s 는 그대로(O8-22) · 남는 인자 1개(O8-84b — 문턱 -gt 0 을 런타임으로)
#   ⑩ r2 검증(V1-01 · V1-02 — 컨트롤러 보정 r2): 기다림 고리 꼴(ST-O8 — try 본문 문장 목록) — 각 고리 바로 앞 문장 = 제 $deadline 대입 · 고리 본문의 대기 =
#      Start-Sleep -Milliseconds 500 정확히 하나 · o8 의 Start-Sleep 은 그 둘뿐(모의 Start-Sleep 은 지속 시간을 버리므로 간격은 정적으로만 지킨다)
# 실물 Vault · 클러스터 · Cloudflare · HTTP 에 닿지 않는다(curl.exe · kubectl.exe 는 함수가 가린다 · 실물 kubectl · vault · tofu 디렉터리는 PATH 에서 뺀다 · 정적 관문이 절대 경로 실행 파일 ·
#   Start-Process · Invoke-WebRequest 를 막는다).
# 사용: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-tester.ps1 [-Only O8,C8,L8] [-Show 'O8-0*'] [-Dir <블록 변이 사본 디렉터리>]
#   (Git Bash 에서는 chcp.com 65001 >/dev/null; 를 앞에 붙여야 한글이 온전하다) · 종료 코드 = 실패 시나리오 · 관문 FAIL 이 있으면 1
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$OrigCulture = [System.Globalization.CultureInfo]::CurrentCulture
$Clock = [Diagnostics.Stopwatch]::StartNew()
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockDir = if ([string]::IsNullOrEmpty($Dir)) { $here } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dir) }
$OnlySet = @(@($Only -split ',') | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { $_.Length -gt 0 })
function Want-Block { param([string]$b) $OnlySet.Count -eq 0 -or $OnlySet -contains $b }
function SEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::Ordinal) }
function Hex-Lower { param([string]$s) -join @([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) }
function B64U { param([byte[]]$b) [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function At { param($arr, [int]$i) $l = @($arr); if ($i -ge 0 -and $i -lt $l.Count) { [string]$l[$i] } else { '' } }
function Add-Event { param([string]$e) [void]$global:Events.Add($e) }
function Add-Violation { param([string]$v) [void]$global:Violations.Add($v) }
function Mock-Stderr { param([string[]]$lines) $ErrorActionPreference = 'Continue'; foreach ($l in $lines) { Write-Error -Message $l } }
function Env-Text { param([string[]]$skip = @()) ((@(Get-ChildItem Env: | Where-Object { $skip -notcontains $_.Name }) | ForEach-Object { [string]$_.Value }) -join "`n") }
function Snap-Env { param([string]$who) [void]$global:EnvAtCall.Add([pscustomobject]@{ who = $who; text = (Env-Text) }) }

# ---------------------------------------------------------------- 0) 실물 차단 가드
$TrapDir = Join-Path ([IO.Path]::GetTempPath()) ('t076-tester-harness-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TrapDir)
foreach ($n in 'vault', 'kubectl', 'tofu') { [IO.File]::WriteAllText((Join-Path $TrapDir "$n.cmd"), "@echo off`r`necho TRAP>`"%~dp0CALLED-$n`"`r`nexit /b 97`r`n", [Text.UTF8Encoding]::new($false)) }
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
# 블록이 멈추는 환경 변수(curl · kubectl 동작 · VAULT_*)가 이 PC 에 있으면 정상 시나리오가 엉뚱하게 멈춘다 — 하네스 동안 지우고 끝에 되돌린다(값은 출력하지 않는다)
$NetEnvNames = @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY')
$NetEnvSaved = @{}
foreach ($v in @(Get-ChildItem Env: | Where-Object { $NetEnvNames -contains $_.Name -or $_.Name -like 'VAULT_*' })) { $NetEnvSaved[$v.Name] = $v.Value; Remove-Item -LiteralPath ('Env:' + $v.Name) }
$OrigLocalAppData = $env:LOCALAPPDATA
$CaseRoot = Join-Path $TrapDir 'cases'
[void](New-Item -ItemType Directory -Path $CaseRoot)
$global:KcPath = Join-Path $HOME '.kube\agent-view.yaml'

# ---------------------------------------------------------------- 계약 · 가짜 값(전부 MOCK 이 든 누가 봐도 가짜인 값 — 블록 파일에는 0)
$global:M_DeploySha = (Hex-Lower 'git-sha-t076').Substring(0, 40)
$global:M_Rev = (Hex-Lower 'gitops-rev-t076').Substring(0, 40)
function Cf-Secret { param([string]$s) ('MOCK-' + (B64U ([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes($s))))).Substring(0, 54) }
$global:M_Cred = @{ id = ((Hex-Lower 'cid-tester-m2m').Substring(0, 32) + '.access'); secret = (Cf-Secret 'secret-tester-m2m') }
if ($global:M_Cred.secret -cnotmatch '\A[0-9A-Za-z_-]{54}\z' -or $global:M_Cred.id -cnotmatch '\A[0-9a-f]{32}\.access\z') { throw '하네스 결함: 가짜 tester-m2m 자격이 실측 꼴이 아니다' }
$global:M_VTok = 'hvs.MOCK' + (B64U ([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes('vault-token')))).Replace('-', 'x').Replace('_', 'y').Substring(0, 86)
$global:M_Accessor = 'MOCKacc' + (Hex-Lower 'accessor').Substring(0, 20)
$global:M_Meta = 'MOCKMETA' + (B64U ([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes('meta-token'))))
$global:M_AdminLoc = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/admin.joshuatech.dev?kid=' + (Hex-Lower 'kid') + '&redirect_url=%2Fidentity-admin%2Fadmin%2F&meta=' + $global:M_Meta
$global:M_Cookie = 'MOCKcfauth' + (B64U ([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes('cf-authorization'))))
$global:M_IP = '203.0.113.77'
$global:M_UA = 'curl/8.23.0-MOCKUA'
$global:M_CHost = '10.42.0.199'
$global:M_CAddr = '10.42.0.199:53311'
$global:M_CUser = 'mock-client-user-x'
$global:M_SAddr = '10.42.1.88:8000'
$global:M_Nonce = 't076-20261120T094312Z-a1b2c3'
$global:W_O8 = '\nT076-W1 code=%{http_code}\nT076-W2 ct=%{content_type}\nT076-W3 size=%{size_download}\nT076-W4 xrid=%header{x-request-id}\nT076-W5 cc=%header{cache-control}\nT076-W6 cfc=%header{cf-cache-status}\nT076-W7 ray=%header{cf-ray}\n'
$global:W_V = '\nT076-V code=%{http_code}\n'
$global:W_L8 = '\nT076-L1 code=%{http_code}\nT076-L2 ct=%{content_type}\nT076-L3 loc=%header{location}\n'
$CurlForbidden = @('-v', '--verbose', '-i', '--include', '-I', '--head', '-D', '--dump-header', '-c', '--cookie-jar', '-b', '--cookie', '-L', '--location', '--location-trusted', '-x', '--proxy', '-K', '--config', '-n', '--netrc', '--netrc-optional', '--netrc-file', '-o', '--output', '-O', '--remote-name', '-k', '--insecure', '-u', '--user')
$CapDefault = [ordered]@{ 'kv/data/platform/access/tester-m2m' = @('read'); 'kv/data/platform/access/tester-k8s' = @('deny'); 'kv/metadata/platform/access/tester-m2m' = @('deny'); 'kv/data/platform/authentik/e2e' = @('read'); 'kv/data/prod/db/identity_admin/app' = @('deny') }

# ---------------------------------------------------------------- JWT 픽스처(가짜 — DPAPI 파일로만 블록에 건넨다)
function Make-Jwt { param($aud = @('vault'), [long]$iat, [long]$exp, [string]$sub = 'system:serviceaccount:kube-system:agent-view', [switch]$NoAud)
  $c = [ordered]@{}
  if (-not $NoAud) { $c['aud'] = $aud }
  $c['exp'] = $exp; $c['iat'] = $iat; $c['iss'] = 'https://kubernetes.default.svc.cluster.local'
  $c['kubernetes.io'] = [ordered]@{ namespace = 'kube-system'; serviceaccount = [ordered]@{ name = 'agent-view'; uid = 'MOCK-uid-agent-view' } }
  $c['nbf'] = $iat; $c['sub'] = $sub
  $h = B64U ([Text.Encoding]::UTF8.GetBytes('{"alg":"RS256","kid":"MOCK-kid-t076"}'))
  $p = B64U ([Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $c -Compress -Depth 6)))
  $s = B64U ([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes('MOCK-sig-' + $p + $sub)))
  "$h.$p.$s" }
function Now-Unix { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function Write-JwtFile { param([string]$jwt, $raw = $null)
  $d = Join-Path $env:LOCALAPPDATA 'jt-e2e'
  [void](New-Item -ItemType Directory -Force -Path $d)
  $f = Join-Path $d 'vault-e2e-reader.jwt'
  if ($null -ne $raw) { [IO.File]::WriteAllText($f, $raw, [Text.Encoding]::ASCII); return }
  $enc = ConvertFrom-SecureString (ConvertTo-SecureString $jwt -AsPlainText -Force)
  [IO.File]::WriteAllText($f, $enc, [Text.Encoding]::ASCII)
  [void]$global:Secrets.Add($jwt)
  $global:M_Jwt = $jwt }

# ---------------------------------------------------------------- 모의 명령(블록의 StrictMode 3.0 아래에서 돈다)
function Next-Ray { $global:RayN++; (Hex-Lower ('ray-' + $global:RayN)).Substring(0, 16) + '-ICN' }
function Resp { param([string]$code, [string]$ct = '', [string]$body = '', [string]$xrid = '', [string]$cc = '', [string]$cfc = 'DYNAMIC', [string]$loc = '', [string]$cookie = '')
  [pscustomobject]@{ code = $code; ct = $ct; body = $body; xrid = $xrid; cc = $cc; cfc = $cfc; ray = (Next-Ray); loc = $loc; cookie = $cookie } }
function Problem { param([string]$code, [string]$slug, [string]$xrid) Resp $code 'application/problem+json' ('{"type":"https://joshuatech.dev/problems/' + $slug + '","title":"x","status":' + $code + '}') -xrid $xrid -cookie ('CF_Authorization=' + $global:M_Cookie) }
function Health-Body {
  $ck = [ordered]@{ db = [ordered]@{ status = 'ok'; latency_ms = 3 }; dragonfly = [ordered]@{ status = 'ok'; latency_ms = 1 }; kafka_producer = [ordered]@{ status = 'ok'; latency_ms = 9 } }
  $b = [ordered]@{ status = 'ok'; version = '0.1.0'; git_sha = $global:M_DeploySha; checks = $ck }
  if ($null -ne $global:HealthMut) { & $global:HealthMut $b }
  ConvertTo-Json -InputObject $b -Depth 6 -Compress }
# m2m · admin 응답 모형(Ingress 표 · Access · pod 규칙) — $global:Model 의 스위치가 변이 꼴을 켠다
function Http-Default { param($req)
  $o = $global:Model
  if (SEq $req.host 'admin.joshuatech.dev') {
    if ($req.hdr.Count -gt 0) { Add-Violation 'admin 호스트에 헤더(자격)를 보냈다' }
    return (Resp '302' 'text/html' '' -cfc '' -loc $global:M_AdminLoc) }
  $id = [string]$req.hdr['CF-Access-Client-Id']; $sec = [string]$req.hdr['CF-Access-Client-Secret']
  if ($id.Length -eq 0 -and $sec.Length -eq 0) { return (Resp '401' 'text/html; charset=UTF-8' '<html><body>Unauthorized</body></html>' -cfc '') }
  if (-not ((SEq $id $global:M_Cred.id) -and (SEq $sec $global:M_Cred.secret))) { return (Resp '401' 'text/html; charset=UTF-8' '<html><body>Unauthorized</body></html>' -cfc '') }
  if ($o['credReject']) { return (Resp ([string]$o['credReject']) 'text/html; charset=UTF-8' '<html><body>Forbidden</body></html>' -cfc '') }
  $p = $req.path
  $healthRoute = SEq $p '/health'
  if ($o['healthPrefix']) { $healthRoute = $p.StartsWith('/health', [StringComparison]::Ordinal) }
  $routed = $healthRoute -or $p.StartsWith('/api', [StringComparison]::Ordinal) -or $p.StartsWith('/session', [StringComparison]::Ordinal) -or $p.StartsWith('/tenants', [StringComparison]::Ordinal)
  if ($o['openAdmin'] -or $o['podAdmin404']) { $routed = $routed -or $p.StartsWith('/admin', [StringComparison]::Ordinal) }
  if (-not $routed) {
    $b = "404 page not found`n"; if ($o['crlf']) { $b = "404 page not found`r`n" }
    $cfc = 'DYNAMIC'; if ($o['hit404']) { $cfc = 'HIT' } elseif ($o['stale404']) { $cfc = 'STALE' }
    return (Resp '404' 'text/plain; charset=utf-8' $b -cfc $cfc) }
  $up = [string]$req.hdr['X-Request-ID']
  $rid = 'mock-' + (Hex-Lower ('rid' + $global:RayN)).Substring(0, 24)
  if ($up -cmatch '\A[A-Za-z0-9._:-]{1,128}\z' -and -not $o['noXrid']) { $rid = $up }
  if ($healthRoute -and (SEq $p '/health')) {
    $r = Resp '200' 'application/json' (Health-Body) -xrid $rid -cookie ('CF_Authorization=' + $global:M_Cookie)
    if ($o['hitHealth']) { $r.cfc = 'HIT' }
    return $r }
  if ((SEq $p '/healthz') -or (SEq $p '/ready')) { return (Resp '200' 'application/json' '{"status":"ok"}' -xrid $rid) }
  if ($o['podAdmin404'] -and $p.StartsWith('/admin', [StringComparison]::Ordinal)) { return (Problem '404' 'not-found' $rid) }
  if (SEq $p '/webhooks/authentik') { return (Problem '401' 'webhook-signature-invalid' $rid) }
  Problem '403' 'access-required' $rid }
# Vault HTTP 모형(port-forward 너머 — 블록이 소유한 포트 · 상태여야 닿는다)
function Vault-Http { param([string]$method, [string]$path, $hdr, [string]$body, [string]$data)
  $tok = [string]$hdr['X-Vault-Token']
  [void]$global:VCalls.Add([pscustomobject]@{ method = $method; path = $path; tok = $tok; body = $body; data = $data })
  Add-Event "vault-http:$method $path"
  $v = $global:V
  $deny = { [pscustomobject]@{ code = '403'; body = '{"errors":["permission denied"]}' } }
  if ((SEq $method 'GET') -and (SEq $path '/v1/sys/seal-status')) {
    return [pscustomobject]@{ code = '200'; body = (ConvertTo-Json -Compress -InputObject ([ordered]@{ type = 'shamir'; initialized = $true; sealed = [bool]$v['sealed']; t = 2; n = 3; progress = 0; nonce = ''; version = '2.0.4'; build_date = '2026-01-01T00:00:00Z'; migration = $false; cluster_name = [string]$v['cluster']; cluster_id = 'mock-cluster-id'; recovery_seal = $true; storage_type = 'raft' })) } }
  if ((SEq $method 'POST') -and (SEq $path '/v1/auth/kubernetes/login')) {
    $global:JwtSent++
    $j = $null; try { $j = $body | ConvertFrom-Json -AsHashtable } catch { $j = $null }
    if ($null -eq $j -or -not (SEq $j['role'] 'e2e-reader') -or @($j.Keys).Count -ne 2) { return [pscustomobject]@{ code = '400'; body = '{"errors":["invalid request"]}' } }
    if (-not (SEq $j['jwt'] $global:M_Jwt)) { return [pscustomobject]@{ code = '403'; body = '{"errors":["permission denied"]}' } }
    if ($v['loginCode'] -ne '200') { return [pscustomobject]@{ code = [string]$v['loginCode']; body = '{"errors":["error validating token: invalid audience (aud) claim"]}' } }
    $global:TokIssued++; $global:TokLive = $true
    $auth = [ordered]@{ client_token = [string]$v['token']; accessor = $global:M_Accessor; policies = @($v['policies']); token_policies = @($v['policies']); metadata = [ordered]@{ role = 'e2e-reader'; service_account_name = 'agent-view' }; lease_duration = $v['lease']; renewable = $true; token_type = 'service'; orphan = $true }
    return [pscustomobject]@{ code = '200'; body = (ConvertTo-Json -Compress -Depth 6 -InputObject ([ordered]@{ request_id = 'mock-login'; lease_id = ''; renewable = $false; lease_duration = 0; data = $null; auth = $auth })) } }
  if (-not (SEq $tok $global:M_VTok) -or -not $global:TokLive) { return (& $deny) }
  if ((SEq $method 'POST') -and (SEq $path '/v1/sys/capabilities-self')) {
    $j = $null; try { $j = $data | ConvertFrom-Json -AsHashtable } catch { $j = $null }
    if ($null -eq $j -or $null -eq $j['paths']) { return [pscustomobject]@{ code = '400'; body = '{"errors":["missing paths"]}' } }
    [void]$global:CapAsked.Add((@($j['paths']) -join ','))
    $m = [ordered]@{}
    foreach ($pp in @($j['paths'])) { if ($v['caps'].Contains([string]$pp)) { $m[[string]$pp] = @($v['caps'][[string]$pp]) } else { $m[[string]$pp] = @('deny') } }
    $top = [ordered]@{}; foreach ($k in @($m.Keys)) { $top[$k] = $m[$k] }
    $top['request_id'] = 'mock-cap'; $top['data'] = $m
    return [pscustomobject]@{ code = [string]$v['capCode']; body = (ConvertTo-Json -Compress -Depth 6 -InputObject $top) } }
  if ((SEq $method 'GET') -and (SEq $path '/v1/kv/data/platform/access/tester-m2m')) {
    $global:KvReads++
    if ($v['kvCode'] -ne '200') { return [pscustomobject]@{ code = [string]$v['kvCode']; body = '{"errors":[]}' } }
    $kvb = ConvertTo-Json -Compress -Depth 6 -InputObject ([ordered]@{ request_id = 'mock-kv'; data = [ordered]@{ data = $v['kv']; metadata = [ordered]@{ created_time = '2026-11-20T08:00:00Z'; custom_metadata = $null; deletion_time = ''; destroyed = $false; version = 1 } } })
    return [pscustomobject]@{ code = '200'; body = $kvb } }
  if ((SEq $method 'POST') -and (SEq $path '/v1/auth/token/revoke-self')) {
    $global:Revokes++
    if ($v['revokeFail']) { return [pscustomobject]@{ code = '500'; body = '{"errors":["internal"]}' } }
    $global:TokLive = $false
    return [pscustomobject]@{ code = '204'; body = '' } }
  Add-Violation "허용 목록 밖 Vault HTTP: $method $path"
  [pscustomobject]@{ code = '404'; body = '{"errors":[]}' } }
function Split-Native { param([string]$t)
  $parts = @([regex]::Split($t, "\r\n|\n|\r"))
  if ($parts.Count -gt 0 -and $parts[$parts.Count - 1].Length -eq 0 -and ($t.EndsWith([char]10) -or $t.EndsWith([char]13))) { if ($parts.Count -eq 1) { $parts = @() } else { $parts = @($parts[0..($parts.Count - 2)]) } }
  $parts }
# curl.exe(블록 셋): -q --version · -q -sS --max-time N [-H X …] [--data-binary @- | --data X] -w <형식> <url> — 형식은 블록 글자 셋 중 하나 · 첫 인자 -q · 금지 플래그 · -H 는 @- 또는
#   Content-Type: application/json(로그인 본문 stdin 과 함께)만 · 응답 = 모형 → 형식의 허용 자리만 채운다(Set-Cookie 는 금지 플래그로만 나온다 — 그때는 헤더를 통째로 흉내 낸다)
function curl.exe {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('curl.exe ' + ($a -join ' '))
  Snap-Env 'curl'
  if (-not $global:Allow['curl']) { Add-Violation ('curl.exe 호출(이 블록은 HTTP 를 쓰지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  if (-not (SEq (At $a 0) '-q')) { Add-Violation ('curl.exe 첫 인자가 -q 가 아니다(.curlrc 를 읽는다): ' + ($a -join ' ')) }
  $global:LASTEXITCODE = 0
  if ($a.Count -eq 2 -and (SEq $a[1] '--version')) { Add-Event 'curl:version'; return @([string]$global:CurlVersion, 'Protocols: http https') }
  $bad = @($a | Where-Object { $CurlForbidden -ccontains $_ -or $_.StartsWith('--trace', [StringComparison]::Ordinal) })
  if ($bad.Count -gt 0) { Add-Violation "curl.exe 금지 플래그: $($bad -join ' ')" }
  $H = @(); $w = $null; $db = $null; $dt = $null; $url = $null; $mt = $null; $sS = $false
  for ($i = 1; $i -lt $a.Count; $i++) {
    $x = $a[$i]
    if (SEq $x '-sS') { $sS = $true }
    elseif (SEq $x '--max-time') { $i++; $mt = At $a $i }
    elseif (SEq $x '-H') { $i++; $H += (At $a $i) }
    elseif (SEq $x '-w') { $i++; $w = At $a $i }
    elseif (SEq $x '--data-binary') { $i++; $db = At $a $i }
    elseif (SEq $x '--data') { $i++; $dt = At $a $i }
    elseif ($i -eq $a.Count - 1 -and -not $x.StartsWith('-', [StringComparison]::Ordinal)) { $url = $x }
    elseif (-not ($CurlForbidden -ccontains $x)) { Add-Violation "curl.exe 모르는 인자: $x" } }
  if (-not $sS -or $mt -cnotmatch '\A[0-9]+\z') { Add-Violation "curl.exe -sS · --max-time 없음: $($a -join ' ')" }
  if (-not (@($global:W_O8, $global:W_V, $global:W_L8) -ccontains [string]$w)) { Add-Violation "curl.exe -w 형식이 블록 글자 셋 밖이다: $w" }
  foreach ($h in $H) { if (-not ((SEq $h '@-') -or ((SEq $h 'Content-Type: application/json') -and (SEq $db '@-')))) { Add-Violation "curl -H 가 @-(stdin) 가 아니다 — 헤더 값이 argv 에 나온다: $h" } }
  if (($H -ccontains '@-') -and (SEq $db '@-')) { Add-Violation 'curl -H @- 와 --data-binary @- 를 함께(stdin 하나)' }
  if ($null -ne $db -and -not (SEq $db '@-')) { Add-Violation "curl --data-binary 가 @- 가 아니다(본문이 argv 에): $db" }
  if ($null -eq $url) { Add-Violation 'curl.exe URL 없음'; $global:LASTEXITCODE = 2; return }
  $m = [regex]::Match($url, '\A(https?)://([^/:?#]+)(?::([0-9]+))?(/[^?#]*)?(?:\?([^#]*))?\z')
  if (-not $m.Success) { Add-Violation "curl.exe URL 꼴: $url"; $global:LASTEXITCODE = 3; return }
  # stdin 헤더: 이름 · 줄을 받은 그대로(대소문자 · 중복 그대로) 기록한다 — $hdr(대소문자 무관 해시)는 모형 응답용 · 사후 조건(S-02)은 hdrNames · hdrLines · argv 를 본다
  $hdr = @{}; $hNames = [System.Collections.Generic.List[string]]::new(); $hLines = [System.Collections.Generic.List[string]]::new(); $bodyIn = ''
  if ($H -ccontains '@-') { foreach ($l in @($stdin | ForEach-Object { [string]$_ })) { [void]$hLines.Add($l); $j = $l.IndexOf([char]':'); if ($j -gt 0) { $hn = $l.Substring(0, $j).Trim(); [void]$hNames.Add($hn); $hdr[$hn] = $l.Substring($j + 1).Trim() } else { Add-Violation 'curl -H @- 줄이 헤더 꼴이 아니다' } } }
  elseif (SEq $db '@-') { $bodyIn = (@($stdin | ForEach-Object { [string]$_ }) -join "`n") }
  elseif ($stdin.Count -gt 0) { Add-Violation 'curl stdin 을 쓰는 플래그 없이 stdin 을 받았다' }
  $req = [pscustomobject]@{ url = $url; scheme = $m.Groups[1].Value; host = $m.Groups[2].Value; port = $m.Groups[3].Value; path = $(if ($m.Groups[4].Success) { $m.Groups[4].Value } else { '/' }); query = $m.Groups[5].Value
    hdr = $hdr; hdrNames = @($hNames); hdrLines = @($hLines); argv = ($a -join ' '); body = $bodyIn; data = $dt; method = $(if ($null -ne $db -or $null -ne $dt) { 'POST' } else { 'GET' }); w = $w; argvHeaders = @($H | Where-Object { -not (SEq $_ '@-') }) }
  [void]$global:CurlCalls.Add($req)
  $resp = $null
  if ((SEq $req.scheme 'http') -and (SEq $req.host '127.0.0.1')) {
    Add-Event "curl:vault:$($req.path)"
    # 127.0.0.1:<포트> 가 답하는 때 = 블록 소유 kubectl 이 그 주소에서 Running · 또는 남이 그 포트를 쥐고 Vault 로 중계(Relay127 — [::1]만 띄운 사례의 위협 모형)
    $listening = ((SEq $global:PfState 'Running') -and (SEq $global:PfAddr '127.0.0.1')) -or $global:Relay127
    $refuse = (-not (SEq $req.port ([string]$global:PfPort))) -or -not $listening
    if (-not $refuse -and (SEq $req.path '/v1/sys/seal-status') -and $global:SealRefuse -gt 0) { $global:SealRefuse--; $refuse = $true }
    if ($refuse) { Mock-Stderr @("curl: (7) Failed to connect to 127.0.0.1 port $($req.port) after 0 ms: Couldn't connect to server"); $global:LASTEXITCODE = 7; return (Split-Native ($w.Replace('\n', "`n").Replace('%{http_code}', '000'))) }
    $global:PfConns++
    $resp = Vault-Http $req.method $req.path $hdr $bodyIn ([string]$dt)
    if (SEq $req.path '/v1/sys/seal-status') {
      if ($global:F['pfDieAfterSeal']) { $global:PfState = 'Completed' }
      if ($global:F['pfLateLine']) { $global:PfLate = @("Forwarding from [::1]:$($global:PfPort) -> 8200") } }
    $resp = [pscustomobject]@{ code = $resp.code; ct = 'application/json'; body = $resp.body; xrid = ''; cc = ''; cfc = ''; ray = ''; loc = ''; cookie = '' } }
  elseif ((SEq $req.scheme 'https') -and (@('identity-m2m-dev.joshuatech.dev', 'identity-m2m-prod.joshuatech.dev', 'admin.joshuatech.dev') -ccontains $req.host)) {
    Add-Event "curl:get:$($req.host)$($req.path)"
    if ($global:F['curlFail']) { Mock-Stderr @('curl: (6) Could not resolve host: ' + $req.host); $global:LASTEXITCODE = 6; return (Split-Native ($w.Replace('\n', "`n") -replace '%\{[a-z_]+\}', '0' -replace '%header\{[a-z-]+\}', '')) }
    $resp = & $global:HttpFn $req
    [void]$global:Responses.Add($resp) }
  else { Add-Violation "curl.exe 허용 밖 호스트: $url"; Mock-Stderr @('curl: (6) Could not resolve host'); $global:LASTEXITCODE = 6; return }
  $size = [Text.Encoding]::UTF8.GetByteCount([string]$resp.body)
  $wx = ([string]$w).Replace('\n', "`n").Replace('%{http_code}', [string]$resp.code).Replace('%{content_type}', [string]$resp.ct).Replace('%{size_download}', [string]$size).Replace('%header{x-request-id}', [string]$resp.xrid).Replace('%header{cache-control}', [string]$resp.cc).Replace('%header{cf-cache-status}', [string]$resp.cfc).Replace('%header{cf-ray}', [string]$resp.ray).Replace('%header{location}', [string]$resp.loc)
  if ($wx -match '%\{|%header\{') { Add-Violation "curl -w 허용 밖 자리: $w" }
  $text = [string]$resp.body + $wx
  if (@($a | Where-Object { @('-i', '--include', '-D', '--dump-header', '-v', '--verbose') -ccontains $_ }).Count -gt 0) { $text = "HTTP/2 $($resp.code)`nset-cookie: CF_Authorization=$($global:M_Cookie)`nlocation: $($resp.loc)`n`n" + $text }
  Split-Native $text }
function curl { Add-Violation 'curl 호출(curl.exe 를 써야 한다 — PowerShell 별칭 · 다른 판 회피)'; $global:LASTEXITCODE = 1 }
# kubectl.exe(블록 셋): --kubeconfig <리터럴 ~\.kube\agent-view.yaml> [--request-timeout=N] 다음 auth whoami · -n vault port-forward --address 127.0.0.1 svc/vault :8200 ·
#   -n <ns> get <kind> <name> -o json · -n <ns> logs <대상> [-c <컨테이너>] [--since-time=<t>] 만 — 그 밖 · 쓰기 동사 · Secret = 위반
#   port-forward 출력($global:F['pf']): '' = 「Forwarding from 127.0.0.1:<포트> -> 8200」 한 줄 · rbac(Failed) · bind(Completed — 127.0.0.1 바인드 실패) · silent(줄 없음) · v6only([::1] 줄만 +
#   127.0.0.1 의 같은 포트를 남이 중계) · both(두 줄) · remote(-> 8201) · range(포트 70000)
function kubectl.exe {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('kubectl.exe ' + ($a -join ' '))
  Snap-Env 'kubectl'
  if (-not $global:Allow['kubectl']) { Add-Violation ('kubectl.exe 호출(이 블록은 클러스터에 닿지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  if ($stdin.Count -gt 0) { Add-Violation 'kubectl.exe 에 stdin' }
  $global:LASTEXITCODE = 0
  if (-not (SEq (At $a 0) '--kubeconfig') -or -not (SEq (At $a 1) $global:KcPath)) { Add-Violation ('kubectl --kubeconfig 가 리터럴 agent-view 경로가 아니다: ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  $r = @($a | Select-Object -Skip 2)
  if ($r.Count -gt 0 -and $r[0].StartsWith('--request-timeout=', [StringComparison]::Ordinal)) { [void]$global:KTimeouts.Add($r[0]); $r = @($r | Select-Object -Skip 1) } else { [void]$global:KTimeouts.Add('') }
  $line = $r -join ' '
  if (@($r | Where-Object { @('secret', 'secrets', 'exec', 'delete', 'apply', 'patch', 'edit', 'create', 'scale', 'drain', 'cordon', '-o=yaml', 'yaml') -ccontains $_ }).Count -gt 0) { Add-Violation "kubectl 금지 동사 · 대상: $line"; $global:LASTEXITCODE = 1; return }
  if (SEq $line 'auth whoami -o jsonpath={.status.userInfo.username}') {
    Add-Event 'kubectl:whoami'
    if ($global:F['whoamiFail']) { Mock-Stderr @("error: You must be logged in to the server (Unauthorized) — config $($global:KcPath)"); $global:LASTEXITCODE = 1; return }
    return [string]$global:Whoami }
  if ($r.Count -eq 7 -and (SEq $r[0] '-n') -and (SEq $r[1] 'vault') -and (SEq $r[2] 'port-forward') -and (SEq $r[3] '--address') -and (SEq $r[4] '127.0.0.1') -and (SEq $r[5] 'svc/vault') -and (SEq $r[6] ':8200')) {
    Add-Event 'kubectl:port-forward'
    $global:PfCalls++
    $global:PfPort = Get-Random -Minimum 49152 -Maximum 65536
    $md = [string]$global:F['pf']
    $p = $global:PfPort
    if (SEq $md 'rbac') { $global:PfState = 'Failed'; Mock-Stderr @('error: error upgrading connection: pods "vault-0" is forbidden: User "system:serviceaccount:kube-system:agent-view" cannot create resource "pods/portforward"'); $global:LASTEXITCODE = 1; return }
    if (SEq $md 'bind') { $global:PfState = 'Completed'; Mock-Stderr @('Unable to listen on port 0: Listeners failed to create with the following errors: [unable to create listener: Error listen tcp4 127.0.0.1:0: bind: An attempt was made to access a socket in a way forbidden by its access permissions.]', 'error: unable to listen on any of the requested ports: [{0 8200}]'); $global:LASTEXITCODE = 1; return }
    $global:PfState = 'Running'
    if (SEq $md 'silent') { return }
    if (SEq $md 'v6only') { $global:PfAddr = '[::1]'; $global:Relay127 = $true; return @("Forwarding from [::1]:$p -> 8200") }
    if (SEq $md 'both') { return @("Forwarding from 127.0.0.1:$p -> 8200", "Forwarding from [::1]:$p -> 8200") }
    if (SEq $md 'remote') { return @("Forwarding from 127.0.0.1:$p -> 8201") }
    if (SEq $md 'range') { return @('Forwarding from 127.0.0.1:70000 -> 8200') }
    return @("Forwarding from 127.0.0.1:$p -> 8200") }
  if ($r.Count -eq 7 -and (SEq $r[0] '-n') -and (SEq $r[2] 'get') -and (SEq $r[5] '-o') -and (SEq $r[6] 'json')) {
    $key = "$($r[1])|$($r[3])|$($r[4])"
    Add-Event "kubectl:get:$key"
    [void]$global:KGets.Add($key)
    if (-not $global:KAllowGet.Contains($key)) { Add-Violation "kubectl get 허용 목록 밖: $key" }
    if ($global:F['getFail'].ContainsKey($key)) { Mock-Stderr @("Error from server (Forbidden): $($r[3]) `"$($r[4])`" is forbidden: User `"system:serviceaccount:kube-system:agent-view`" cannot get resource"); $global:LASTEXITCODE = 1; return }
    if (-not $global:KObj.Contains($key) -or $null -eq $global:KObj[$key]) { Mock-Stderr @("Error from server (NotFound): $($r[3]) `"$($r[4])`" not found"); $global:LASTEXITCODE = 1; return }
    return @((ConvertTo-Json -InputObject $global:KObj[$key] -Depth 40) -split "`r?`n") }
  if ($r.Count -ge 4 -and (SEq $r[0] '-n') -and (SEq $r[2] 'logs')) {
    $ns = $r[1]; $tgt = $r[3]; $ctr = ''; $since = ''
    for ($i = 4; $i -lt $r.Count; $i++) {
      if ((SEq $r[$i] '-c') -and $i + 1 -lt $r.Count) { $i++; $ctr = $r[$i] }
      elseif ($r[$i].StartsWith('--since-time=', [StringComparison]::Ordinal)) { $since = $r[$i].Substring(13) }
      else { Add-Violation "kubectl logs 모르는 인자: $($r[$i])" } }
    $key = "$ns|$tgt|$ctr"
    Add-Event "kubectl:logs:$key"
    [void]$global:KLogCalls.Add([pscustomobject]@{ key = $key; since = $since })
    if (-not $global:KAllowLogs.Contains($key)) { Add-Violation "kubectl logs 허용 목록 밖: $key" }
    if ($global:F['logsFail'].ContainsKey($key)) { Mock-Stderr @("Error from server (Forbidden): pods is forbidden — config $($global:KcPath)"); $global:LASTEXITCODE = 1; return }
    if (-not $global:KLogs.ContainsKey($key)) { return }
    return @($global:KLogs[$key]) }
  Add-Violation "허용 목록 밖 kubectl: $line"
  $global:LASTEXITCODE = 1 }
function kubectl { Add-Violation ('kubectl(확장자 없이) 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function vault { Add-Violation ('vault CLI 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function vault.exe { Add-Violation ('vault.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function tofu { Add-Violation ('tofu 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function tofu.exe { Add-Violation ('tofu.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function oci { Add-Violation 'oci 호출'; $global:LASTEXITCODE = 1 }
function gh { Add-Violation 'gh 호출'; $global:LASTEXITCODE = 1 }
function Read-Host { Add-Violation 'Read-Host 호출(tester 블록은 비대화형 — 입력은 param 뿐)'; '' }
function Set-Clipboard { Add-Violation 'Set-Clipboard 호출' }
function Get-Clipboard { Add-Violation 'Get-Clipboard 호출'; '' }
function Start-Process { Add-Violation 'Start-Process 호출' }
function Start-Job { Add-Violation 'Start-Job 호출(프로세스 작업 — kubectl 이 고아로 남는다)' }
function Invoke-WebRequest { Add-Violation 'Invoke-WebRequest 호출' }
function Invoke-RestMethod { Add-Violation 'Invoke-RestMethod 호출' }
function Set-PSDebug { param([switch]$Off, [int]$Trace = -1, [switch]$Step, [switch]$Strict)
  if ($Off -and $Trace -lt 0 -and -not $Step -and -not $Strict) { Add-Event 'psdebug:off' } else { Add-Violation 'Set-PSDebug 를 -Off 가 아닌 인자로 호출' } }
# 스레드 작업 모의(O-8 port-forward): 스크립트블록을 그 자리에서 모의 kubectl 로 돌려 출력 줄을 받는다 · 상태 = 처음 $global:PfNotStarted 번은 NotStarted(실측 — 시작 직후 ·
#   출력이 한 번 보인 뒤에는 NotStarted 가 아니다 — 출력을 낸 작업은 이미 돈다) 뒤 모의
#   port-forward 상태 · 출력은 처음 $global:PfLag 번의 Receive-Job 에 안 보인다 · 받은 연결마다 「Handling connection for <포트>」 · $global:PfLate(뒤에 붙는 줄) · Stop-Job 이 port-forward 를 끊는다
function Start-ThreadJob { [CmdletBinding()] param([scriptblock]$ScriptBlock, [object[]]$ArgumentList = @())
  Add-Event 'job:start'
  if (-not $global:Allow['job']) { Add-Violation 'Start-ThreadJob 호출(이 블록은 작업을 띄우지 않는다)' }
  [void]$global:JobLog.Add([pscustomobject]@{ sb = $ScriptBlock.ToString(); args = @($ArgumentList | ForEach-Object { [string]$_ }) })
  $out = @(& $ScriptBlock @ArgumentList)
  $j = [pscustomobject]@{ Id = 4242; Name = 'mock-pf'; Out = $out; Stopped = $false; Removed = $false }
  $j | Add-Member -MemberType ScriptProperty -Name State -Value { if ($global:PfNotStarted -gt 0 -and -not $global:PfOutSeen) { $global:PfNotStarted--; 'NotStarted' } elseif (@('Running', 'Failed', 'Completed', 'Stopped') -ccontains [string]$global:PfState) { [string]$global:PfState } else { 'Failed' } } -SecondValue { param($v) $global:PfState = [string]$v }
  $global:FakeJob = $j
  $j }
function Stop-Job { [CmdletBinding()] param([Parameter(Position = 0)]$Job)
  Add-Event 'job:stop'
  if ($null -ne $Job) { $Job.State = 'Stopped'; $Job.Stopped = $true }
  if (SEq $global:PfState 'Running') { $global:PfState = 'Stopped' } }
function Remove-Job { [CmdletBinding()] param([Parameter(Position = 0)]$Job, [switch]$Force) Add-Event 'job:remove'; if ($null -ne $Job) { $Job.Removed = $true } }
function Receive-Job { [CmdletBinding()] param([Parameter(Position = 0)]$Job, [switch]$Keep)
  Add-Event 'job:receive'
  $global:PfReads++
  if (-not $Keep) { Add-Violation 'Receive-Job 에 -Keep 없음(출력을 소비하면 로그인 직전 재확인이 Forwarding 줄을 못 본다)' }
  if ($null -eq $Job) { return }
  if ($global:PfLag -gt 0) { $global:PfLag--; return }
  $o = @(@($Job.Out) + @(for ($i = 0; $i -lt $global:PfConns; $i++) { "Handling connection for $($global:PfPort)" }) + @($global:PfLate))
  if ($o.Count -gt 0) { $global:PfOutSeen = $true }
  $o }
function Start-Sleep { param([int]$Milliseconds = 0, [int]$Seconds = 0) Add-Event 'sleep' }
# 정책 레지스트리: 모듈 로깅 · Transcription 키 넷씩(값 = $global:Policy[<키>] 해시 — 없으면 키 없음)
$global:PolicyPaths = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging',
  'HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription')
function Get-ItemProperty { param([Parameter(Position = 0)]$Path, [Parameter(Position = 1)]$Name)
  foreach ($pp in $global:PolicyPaths) {
    if ([string]::Equals([string]$Path, $pp, [StringComparison]::OrdinalIgnoreCase)) {
      if ($pp.EndsWith('ModuleLogging', [StringComparison]::Ordinal)) { Add-Event "reg:policy:$pp" } else { Add-Event "reg:tr:$pp" }
      $h = $global:Policy[$pp]
      if ($null -eq $h) { return $null }
      return [pscustomobject]$h } }
  Add-Violation "Get-ItemProperty 다른 경로: $Path"; $null }
function Cfg-Scope { param([string]$q) if ($q.StartsWith($PSHOME, [StringComparison]::OrdinalIgnoreCase)) { 'system' } else { 'user' } }
function Test-Path { param([Parameter(Position = 0)]$Path, [string]$LiteralPath = '')
  $q = [string]$Path; if ($LiteralPath.Length -gt 0) { $q = $LiteralPath }
  if ($q.EndsWith('powershell.config.json', [StringComparison]::OrdinalIgnoreCase)) { $sc = Cfg-Scope $q; Add-Event "cfg:test:$sc"; return ($null -ne $global:CfgText[$sc]) }
  if ($q.EndsWith('\.kube\agent-view.yaml', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:kubeconfig'; if (-not (SEq $q $global:KcPath)) { Add-Violation "kubeconfig 경로가 리터럴과 다르다: $q" }; return [bool]$global:KcExists }
  if ($q.EndsWith('\jt-e2e\vault-e2e-reader.jwt', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:jwt'; [void]$global:FsLog.Add($q) }
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
# Get-Command 가림: ForEach-Object(Core 스냅인 실효 값) · $global:FakeSrc[이름](실행 파일 경로 모의 — 없음 표시 $global:FakeGone · 첫 해석 형식 $global:FakeType[이름] = Function · Alias(S-10 —
#   같은 이름 함수 · 별칭 가림) · 형식 필터 · -All 이 붙은 질의는 위반(첫 해석 판정이 아니다)) · 그 밖은 실물
function Get-Command { [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name, [string[]]$CommandType, [switch]$All)
  $n0 = [string](@($Name)[0])
  if (@($Name).Count -eq 1 -and (SEq $n0 'ForEach-Object')) {
    Add-Event 'mod:core'
    if (-not (SEq (@($CommandType) -join ',') 'Cmdlet')) { Add-Violation 'Get-Command ForEach-Object 에 -CommandType Cmdlet 없음' }
    if ($global:CoreMissing) { return }
    $snap = $null
    if (-not $global:CoreNoSnap) { $snap = [pscustomobject]@{ Name = 'Microsoft.PowerShell.Core'; LogPipelineExecutionDetails = [bool]$global:CoreLog } }
    return [pscustomobject]@{ Name = 'ForEach-Object'; CommandType = 'Cmdlet'; PSSnapIn = $snap; Source = 'Microsoft.PowerShell.Core' } }
  if (@($Name).Count -eq 1 -and $null -ne $global:FakeGone -and $global:FakeGone -contains $n0) { Add-Event "exe:$n0"; return }
  if (@($Name).Count -eq 1 -and $null -ne $global:FakeSrc -and $global:FakeSrc.ContainsKey($n0)) {
    Add-Event "exe:$n0"
    if (@($CommandType | Where-Object { $null -ne $_ }).Count -gt 0 -or $All) { Add-Violation "Get-Command $n0 에 형식 필터 · -All($(@($CommandType) -join ',')) — 형식 필터 없는 첫 해석 판정이어야 한다(S-10)" }
    if ($global:FakeType.ContainsKey($n0)) { return [pscustomobject]@{ Name = $n0; CommandType = [System.Management.Automation.CommandTypes]([string]$global:FakeType[$n0]); Source = '' } }
    return [pscustomobject]@{ Name = $n0; CommandType = [System.Management.Automation.CommandTypes]::Application; Source = [string]$global:FakeSrc[$n0] } }
  Microsoft.PowerShell.Core\Get-Command @PSBoundParameters }

# ---------------------------------------------------------------- 가드 확인 · 모의 상태
$MockNames = @('kubectl.exe', 'curl.exe', 'kubectl', 'curl', 'vault', 'vault.exe', 'tofu', 'tofu.exe', 'oci', 'gh', 'Read-Host', 'Set-Clipboard', 'Get-Clipboard', 'Start-Process', 'Start-Job', 'Invoke-WebRequest', 'Invoke-RestMethod',
  'Set-PSDebug', 'Start-ThreadJob', 'Stop-Job', 'Remove-Job', 'Receive-Job', 'Start-Sleep', 'Get-ItemProperty', 'Test-Path', 'Get-Content', 'Import-Module', 'Get-Module', 'Get-Command')
function Assert-Guard {
  foreach ($n in $MockNames) {
    $c = Microsoft.PowerShell.Core\Get-Command $n -ErrorAction SilentlyContinue
    if ($null -eq $c -or $c.CommandType -ne 'Function') { throw "가드 실패: $n 이 모의 함수로 풀리지 않는다 — 블록을 실행하지 않는다" } }
  foreach ($x in @(Microsoft.PowerShell.Core\Get-Command vault, kubectl, tofu, vault.exe, kubectl.exe, tofu.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    if (-not $x.Source.StartsWith($TrapDir, [StringComparison]::OrdinalIgnoreCase)) { throw "가드 실패: 실물 실행 파일이 PATH 에 남아 있다($($x.Source)) — 블록을 실행하지 않는다" } }
  if (-not (SEq $env:KUBECONFIG $FakeKubeconfig)) { throw '가드 실패: KUBECONFIG 가 하네스의 없는 경로가 아니다' } }
function Trap-Markers { @(Get-ChildItem -LiteralPath $TrapDir -Filter 'CALLED-*' -ErrorAction SilentlyContinue).Count }
function Reset-Mocks {
  [System.Globalization.CultureInfo]::CurrentCulture = $OrigCulture
  $global:F = @{ curlFail = $false; whoamiFail = $false; pf = ''; pfDieAfterSeal = $false; pfLateLine = $false; getFail = @{}; logsFail = @{} }
  $global:Model = @{}
  $global:HealthMut = $null
  $global:ModLog = @{ 'Microsoft.PowerShell.Utility' = $false; 'Microsoft.PowerShell.Security' = $false; 'Microsoft.PowerShell.Management' = $false }
  $global:ModMissing = @()
  $global:CoreLog = $false; $global:CoreNoSnap = $false; $global:CoreMissing = $false
  $global:FakeSrc = @{ 'curl.exe' = 'C:\Program Files\MockTools\curl.exe'; 'kubectl.exe' = 'C:\Program Files\MockTools\kubectl.exe' }
  $global:FakeGone = @()
  $global:FakeType = @{}
  $global:CfgText = @{ system = '{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned","WindowsPowerShellCompatibilityModuleDenyList":["PSScheduledJob"]}'; user = $null }
  $global:Policy = @{}
  foreach ($n in 'Events', 'Violations', 'XArgv', 'EnvAtCall', 'CurlCalls', 'Responses', 'VCalls', 'CapAsked', 'JobLog', 'KGets', 'KLogCalls', 'KTimeouts', 'FsLog', 'Secrets', 'Fulls') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:Allow = @{ curl = $false; kubectl = $false; job = $false }
  $global:CurlVersion = 'curl 8.23.0 (Windows) libcurl/8.23.0 Schannel'
  $global:HttpFn = { param($req) Http-Default $req }
  $global:RayN = 0
  $global:Whoami = 'system:serviceaccount:kube-system:agent-view'
  $global:KcExists = $true
  $global:PfPort = -1; $global:PfState = 'None'; $global:PfCalls = 0; $global:SealRefuse = 0; $global:FakeJob = $null
  $global:PfAddr = '127.0.0.1'; $global:Relay127 = $false; $global:PfNotStarted = 1; $global:PfLag = 1; $global:PfConns = 0; $global:PfLate = @(); $global:PfReads = 0; $global:PfOutSeen = $false
  $global:V = @{ sealed = $false; cluster = 'vault-cluster-d3b29227'; loginCode = '200'; token = $global:M_VTok; policies = @('default', 'e2e-reader'); lease = [long]3600; caps = [ordered]@{}; capCode = '200'
    kv = [ordered]@{ client_id = $global:M_Cred.id; client_secret = $global:M_Cred.secret }; kvCode = '200'; revokeFail = $false }
  foreach ($k in @($CapDefault.Keys)) { $global:V['caps'][$k] = @($CapDefault[$k]) }
  $global:JwtSent = 0; $global:TokIssued = 0; $global:TokLive = $false; $global:Revokes = 0; $global:KvReads = 0
  $global:M_Jwt = ''
  $global:KObj = [ordered]@{}
  $global:KLogs = @{}
  $global:KAllowGet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  $global:KAllowLogs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name -like 'VAULT_*' })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }
Reset-Mocks

# ---------------------------------------------------------------- 노출 검사(바늘)
# 비밀 하나의 바늘 집합 = 전체 · 표준 base64 · 8자 창 전부(8자 이상 조각은 모두 8자 창을 품는다) · SHA-256 hex(대 · 소문자 · 전체 · 앞 16자) — 8자 미만 값은 바늘 0
#   바늘을 하나씩 흘려보낸다(@(Needles-Of x) = 바늘 배열 — 「, @(집합)」으로 돌려주면 @() 가 배열 하나짜리로 감싸 바늘이 한 줄로 합쳐진다)
function Needles-Of { param([string]$s)
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  if ($s.Length -ge 8) {
    [void]$set.Add($s)
    [void]$set.Add([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)))
    for ($i = 0; $i -le $s.Length - 8; $i++) { [void]$set.Add($s.Substring($i, 8)) }
    $hx = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)))
    foreach ($h in @($hx, $hx.ToLowerInvariant())) { [void]$set.Add($h); [void]$set.Add($h.Substring(0, 16)) } }
  foreach ($x in $set) { $x } }
function Build-Needles {
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($s in @($global:Secrets)) { foreach ($n in @(Needles-Of ([string]$s))) { [void]$set.Add($n) } }
  foreach ($s in @($global:Fulls)) { if (([string]$s).Length -ge 6) { [void]$set.Add([string]$s) } }
  , @($set) }
# 하네스 자체 확인: 바늘 배열이 낱개로 나온다(10자 → 전체 1 · base64 1 · 8자 창 3 · SHA-256 4 = 9) — 합쳐진 한 줄이면 노출 · 자격의 길 검사가 빈 판정이 된다
$selfN = @(Needles-Of 'abcdefghij')
if ($selfN.Count -ne 9 -or -not ($selfN -ccontains 'cdefghij') -or @($selfN | Where-Object { $_.Contains(' ') }).Count -gt 0) { throw "하네스 결함: Needles-Of 가 바늘 배열을 낱개로 돌려주지 않는다(개수 $($selfN.Count))" }
# 요청별 헤더 기대(S-02 ①): 돌려주는 것 = stdin 헤더 이름 집합 · argv -H 정확한 목록
function Want-Hdr { param([string]$File, $c)
  $none = [string[]]@()
  if ($File.StartsWith('o8', [StringComparison]::Ordinal)) {
    if ($c.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal)) { return [pscustomobject]@{ stdin = [string[]]@('CF-Access-Client-Id', 'CF-Access-Client-Secret', 'X-Request-ID'); argv = $none } }
    if (SEq $c.host '127.0.0.1') {
      if (SEq $c.path '/v1/sys/seal-status') { return [pscustomobject]@{ stdin = $none; argv = $none } }
      if (SEq $c.path '/v1/auth/kubernetes/login') { return [pscustomobject]@{ stdin = $none; argv = [string[]]@('Content-Type: application/json') } }
      return [pscustomobject]@{ stdin = [string[]]@('X-Vault-Token'); argv = $none } } }
  [pscustomobject]@{ stdin = $none; argv = $none } }
# 이름 집합이 정확히 같다(Ordinal · 중복 없음) / 목록이 정확히 같다(순서 그대로)
function Names-Are { param($got, [string[]]$want)
  $g = [string[]]@($got | ForEach-Object { [string]$_ })
  if ($g.Count -ne $want.Count) { return $false }
  $s = [System.Collections.Generic.HashSet[string]]::new($g, [StringComparer]::Ordinal)
  ($s.Count -eq $want.Count) -and @($want | Where-Object { -not $s.Contains($_) }).Count -eq 0 }
function Lines-Are { param($got, [string[]]$want) $g = [string[]]@($got | ForEach-Object { [string]$_ }); ($g.Count -eq $want.Count) -and [string]::Equals(($g -join "`n"), ($want -join "`n"), [StringComparison]::Ordinal) }
function First-Needle { param([string]$text, $needles) foreach ($n in @($needles)) { if ($text.Contains($n)) { return $n } }; $null }
function Error-Text {
  $sb = [System.Text.StringBuilder]::new()
  foreach ($e in @($global:Error)) { [void]$sb.AppendLine([string]$e); if ($e -is [System.Management.Automation.ErrorRecord]) { [void]$sb.AppendLine($e.Exception.ToString()); [void]$sb.AppendLine([string]$e.TargetObject) } }
  $sb.ToString() }
function Flat-Text { param($v)
  if ($null -eq $v) { return '' }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Collections.IDictionary]) { return ((@($v.Keys) | ForEach-Object { [string]$_ + '=' + [string]$v[$_] }) -join "`n") }
  if ($v -is [System.Collections.IEnumerable]) { return ((@($v) | ForEach-Object { [string]$_ }) -join "`n") }
  [string]$v }
$HarnessGlobals = @('F', 'Model', 'HealthMut', 'ModLog', 'ModMissing', 'CoreLog', 'CoreNoSnap', 'CoreMissing', 'FakeSrc', 'FakeGone', 'FakeType', 'CfgText', 'Policy', 'PolicyPaths', 'Events', 'Violations', 'XArgv', 'EnvAtCall', 'CurlCalls',
  'PfAddr', 'Relay127', 'PfNotStarted', 'PfLag', 'PfConns', 'PfLate', 'PfReads', 'PfOutSeen',
  'Responses', 'VCalls', 'CapAsked', 'JobLog', 'KGets', 'KLogCalls', 'KTimeouts', 'FsLog', 'Secrets', 'Fulls', 'Allow', 'CurlVersion', 'HttpFn', 'RayN', 'Whoami', 'KcExists', 'KcPath', 'PfPort', 'PfState', 'PfCalls', 'SealRefuse',
  'FakeJob', 'V', 'JwtSent', 'TokIssued', 'TokLive', 'Revokes', 'KvReads', 'M_Jwt', 'KObj', 'KLogs', 'KAllowGet', 'KAllowLogs', 'CaseChecks', 'LastText', 'Error', 'LASTEXITCODE', 'M_DeploySha', 'M_Rev', 'M_Cred', 'M_VTok',
  'M_Accessor', 'M_Meta', 'M_AdminLoc', 'M_Cookie', 'M_IP', 'M_UA', 'M_CHost', 'M_CAddr', 'M_CUser', 'M_SAddr', 'M_Nonce', 'W_O8', 'W_V', 'W_L8', 'BGate', 'O8Mut', 'Fx')
function Snapshot-Globals { $h = @{}; foreach ($g in @(Get-Variable -Scope Global)) { $h[$g.Name] = $g.Value }; $h }
function Globals-Hit { param($before, $needles)
  foreach ($g in @(Get-Variable -Scope Global)) {
    if ($HarnessGlobals -contains $g.Name) { continue }
    if ($before.ContainsKey($g.Name) -and [object]::ReferenceEquals($before[$g.Name], $g.Value)) { continue }
    $hit = First-Needle (Flat-Text $g.Value) $needles
    if ($null -ne $hit) { return "`$$($g.Name)(바늘 길이 $($hit.Length))" } }
  $null }

# ---------------------------------------------------------------- 시나리오 실행기
$Results = [System.Collections.ArrayList]::new()
function Check { param([string]$name, [bool]$ok, [string]$detail = '', [switch]$Gate) [void]$global:CaseChecks.Add([pscustomobject]@{ name = $name; ok = $ok; detail = $detail; gate = [bool]$Gate }) }
function Finish-Case { param([string]$id, [string]$desc, [string]$text)
  $bad = @($global:CaseChecks | Where-Object { -not $_.ok })
  [void]$Results.Add([pscustomobject]@{ id = $id; desc = $desc; pass = ($bad.Count -eq 0 -and $global:CaseChecks.Count -gt 0); total = $global:CaseChecks.Count; failed = $bad.Count
      detail = (($bad | Select-Object -First 6 | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) }) -join ' | ') })
  if ($bad.Count -gt 0 -or ($Show -and $id -like $Show)) { Write-Host "---- $id 화면 출력 ----`n$text`n" -ForegroundColor DarkGray } }
function Ev-First { param([string]$prefix) for ($i = 0; $i -lt $global:Events.Count; $i++) { if (([string]$global:Events[$i]).StartsWith($prefix, [StringComparison]::Ordinal)) { return $i } }; -1 }
function Last-Line { param([string]$text) $ls = @($text -split "`n" | Where-Object { $_.Trim().Length -gt 0 }); if ($ls.Count) { $ls[$ls.Count - 1] } else { '' } }
$global:BGate = @{}
function Run-TCase {
  param([string]$Id, [string]$Desc, [string]$File, [hashtable]$P = @{}, [string[]]$Extra = @(), [hashtable]$Allow = @{}, [scriptblock]$Setup = $null, [string]$Final = '', [int]$Exit = 1,
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [hashtable]$PreEnv = @{})
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($global:BGate.ContainsKey($File) -and $global:BGate[$File]) { Check "정적 관문 통과(블록 $File)" $false ([string]$global:BGate[$File]); Finish-Case $Id $Desc '(정적 관문 FAIL — 실행하지 않았다)'; return }
  Assert-Guard
  Reset-Mocks
  $caseDir = Join-Path $CaseRoot $Id
  [void](New-Item -ItemType Directory -Force -Path $caseDir)
  $env:LOCALAPPDATA = $caseDir
  foreach ($k in @($Allow.Keys)) { $global:Allow[$k] = [bool]$Allow[$k] }
  foreach ($s in @($global:M_Cred.secret, $global:M_VTok, $global:M_Accessor, $global:M_Meta, $global:M_Cookie)) { [void]$global:Secrets.Add($s) }
  foreach ($s in @($global:M_Cred.id, $global:M_IP, $global:M_UA, $global:M_CHost, $global:M_CAddr, $global:M_CUser, $global:M_SAddr)) { [void]$global:Fulls.Add($s) }
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  Check '하네스 자체: 모의 상태 표(F · Model · ModLog · FakeSrc · CfgText · V)가 해시 테이블 그대로' ($global:F -is [hashtable] -and $global:Model -is [hashtable] -and $global:ModLog -is [hashtable] -and $global:FakeSrc -is [hashtable] -and $global:CfgText -is [hashtable] -and $global:V -is [hashtable])
  $jwtFile = Join-Path $caseDir 'jt-e2e\vault-e2e-reader.jwt'
  $jwtBefore = Microsoft.PowerShell.Management\Test-Path -LiteralPath $jwtFile
  $filesBefore = @(Get-ChildItem -LiteralPath $caseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
  $blockFilesBefore = @(Get-ChildItem -LiteralPath $BlockDir -File | Where-Object { @('o8-probe-identity-m2m.ps1', 'c8-correlate-logs.ps1', 'l8-live-identity-admin.ps1') -contains $_.Name } | ForEach-Object { $_.Name + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks })
  foreach ($k in @($PreEnv.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value ([string]$PreEnv[$k]) }
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  $path = Join-Path $BlockDir $File
  $global:LASTEXITCODE = 99
  try { & $path @P @Extra *>&1 | ForEach-Object { [void]$items.Add($_) } } catch { $threw = $true; $errMsg = [string]$_.Exception.Message }
  $rcBlock = $global:LASTEXITCODE
  $lines = @($items | ForEach-Object { [string]$_ })
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  Check 'outcome: 블록이 예외를 밖으로 내지 않았다(멈춤도 STOP 줄 + 끝 줄로 끝난다)' (-not $threw) $errMsg
  Check "끝 줄 = $Final" (SEq (Last-Line $text) $Final) (Last-Line $text)
  Check "종료 코드 = $Exit(0 은 전부 PASS 일 때만)" ($rcBlock -eq $Exit) "exit $rcBlock"
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  $needles = Build-Needles
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; 'argv(curl · kubectl)' = (@($global:XArgv) -join "`n"); '$Error' = (Error-Text); '환경 변수' = (Env-Text) }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $envHit = $null
  foreach ($s in $global:EnvAtCall) { $h = First-Needle ([string]$s.text) $needles; if ($null -ne $h) { $envHit = "$($s.who) 호출 시점(바늘 길이 $($h.Length))"; break } }
  Check '노출 0: 모의 호출 시점 환경 변수(curl · kubectl 자식 프로세스 env)' ($null -eq $envHit) ([string]$envHit)
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  $newFiles = @(Get-ChildItem -LiteralPath $caseDir -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName } | Where-Object { $filesBefore -notcontains $_ })
  $fileHit = $null; foreach ($f in @(Get-ChildItem -LiteralPath $caseDir -Recurse -File -ErrorAction SilentlyContinue)) { $h = First-Needle ([IO.File]::ReadAllText($f.FullName)) $needles; if ($null -ne $h) { $fileHit = $f.Name } }
  Check '파일: 임시 LOCALAPPDATA 에 블록이 만든 파일 0 · 그 안의 파일에 바늘 0(DPAPI 파일 = 평문 0)' ($newFiles.Count -eq 0 -and $null -eq $fileHit) "새 파일 $($newFiles.Count) · 바늘 파일 $fileHit"
  $blockFilesAfter = @(Get-ChildItem -LiteralPath $BlockDir -File | Where-Object { @('o8-probe-identity-m2m.ps1', 'c8-correlate-logs.ps1', 'l8-live-identity-admin.ps1') -contains $_.Name } | ForEach-Object { $_.Name + '|' + $_.Length + '|' + $_.LastWriteTimeUtc.Ticks })
  Check '파일: tester 블록 파일 셋 변경 0(블록은 쓰지 않는다 — 같은 디렉터리의 다른 조각 파일은 보지 않는다)' ((@($blockFilesBefore) -join ';') -ceq (@($blockFilesAfter) -join ';'))
  if ($jwtBefore) { Check 'JWT 파일을 지우지 않았다(UD-16 — 1시간 안 재사용 · 삭제는 운영자 O-9 의 정지점 단어 clear)' (Microsoft.PowerShell.Management\Test-Path -LiteralPath $jwtFile) }
  Check '위반 0(허용 목록 밖 curl · kubectl · Vault HTTP · Read-Host · vault · tofu · 금지 플래그)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 kubectl · vault · tofu 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0 · 오류 스트림 0(출력은 Write-Host 뿐)' ($succ.Count -eq 0 -and @($items | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count -eq 0) "성공 $($succ.Count)"
  Check '첫 동작 = Set-PSDebug -Off 1회' ($global:Events.Count -gt 0 -and (SEq $global:Events[0] 'psdebug:off') -and @($global:Events | Where-Object { SEq $_ 'psdebug:off' }).Count -eq 1) $(if ($global:Events.Count) { "첫 이벤트 $($global:Events[0])" } else { '이벤트 0' })
  $iVal = -1
  foreach ($pfx in 'kubectl:', 'curl:get:', 'curl:vault:', 'vault-http:', 'fs:jwt', 'job:start') { $j = Ev-First $pfx; if ($j -ge 0 -and ($iVal -lt 0 -or $j -lt $iVal)) { $iVal = $j } }
  if ($iVal -ge 0) {
    $iPol = Ev-First 'reg:policy:'; $iMod = Ev-First 'mod:get'; $iCore = Ev-First 'mod:core'; $iCs = Ev-First 'cfg:test:system'; $iCu = Ev-First 'cfg:test:user'
    Check '모듈 로깅 정책 · 실효 확인(Get-Module · Core 스냅인 · 설정 파일 둘)이 값이 오가는 첫 동작(kubectl · curl · Vault · JWT 파일 · 작업)보다 먼저' ($iPol -ge 0 -and $iPol -lt $iVal -and $iMod -ge 0 -and $iMod -lt $iVal -and $iCore -ge 0 -and $iCore -lt $iVal -and $iCs -ge 0 -and $iCs -lt $iVal -and $iCu -ge 0 -and $iCu -lt $iVal) "정책 $iPol · mod $iMod · core $iCore · cfg $iCs/$iCu · 첫 값 동작 $iVal" }
  Check '화면에 제어 문자 0(LF 밖 — 응답 · 로그 글자의 터미널 제어열)' (-not ($text -cmatch '[\p{Cc}-[\n]]'))
  Check '$Error 에 블록이 남긴 기록 0(블록 finally 가 이 실행분을 지운다 — 멈춤도 블록 안에서 잡는다)' ($global:Error.Count -eq 0) "남은 기록 $($global:Error.Count)"
  if ($global:PfCalls -gt 0 -or $null -ne $global:FakeJob) { Check 'port-forward(스레드 작업)를 finally 에서 끄고 지웠다' ($null -ne $global:FakeJob -and $global:FakeJob.Stopped -and $global:FakeJob.Removed -and -not (SEq $global:PfState 'Running')) }
  if ($global:TokIssued -gt 0 -and -not $global:V['revokeFail']) { Check 'Vault 토큰을 finally 에서 revoke-self 로 1번 지웠다' ($global:Revokes -eq 1 -and -not $global:TokLive) "revoke $($global:Revokes)" }
  # 요청별 헤더 이름 집합(S-02 ①): stdin 헤더 이름(받은 그대로 · 중복 포함) · argv -H 를 요청 종류마다 정확히 — 그 밖 헤더 0(Want-Hdr)
  $hdrBad = @()
  foreach ($c in @($global:CurlCalls)) {
    $wh = Want-Hdr $File $c
    if (-not (Names-Are $c.hdrNames $wh.stdin) -or -not (Lines-Are $c.argvHeaders $wh.argv)) { $hdrBad += "$($c.host)$($c.path): stdin [$(@($c.hdrNames) -join ',')] · argv -H [$(@($c.argvHeaders) -join ' | ')]" } }
  Check '요청별 헤더 이름 집합(S-02 ①): O-8 m2m = 정확히 {CF-Access-Client-Id · CF-Access-Client-Secret · X-Request-ID}(가짜 자격 포함) · Vault seal · 로그인 = stdin 헤더 0(로그인 argv -H = Content-Type: application/json 하나) · Vault 토큰 요청 = 정확히 {X-Vault-Token} · L-8 = 0 · argv -H 그 밖 0' ($hdrBad.Count -eq 0) (@($hdrBad | Select-Object -First 2) -join ' ; ')
  # 자격의 길(S-02 ② — 바늘 집합): 자격마다 허용 자리 하나(그 헤더 값 · 로그인 본문 jwt 값)만 비우고 요청의 나머지(URL · argv · 헤더 줄 이름 · 값 · 본문 · data)에서 바늘을 찾는다
  $pathBad = @()
  $ways = [ordered]@{ 'client_id' = @($global:M_Cred.id, 'CF-Access-Client-Id', 'm2m'); 'client_secret' = @($global:M_Cred.secret, 'CF-Access-Client-Secret', 'm2m'); 'Vault 토큰' = @($global:M_VTok, 'X-Vault-Token', 'vault') }
  if ($global:M_Jwt.Length -gt 0) { $ways['JWT'] = @($global:M_Jwt, '', 'login') }
  foreach ($wk in @($ways.Keys)) {
    $sv = [string]$ways[$wk][0]; $ah = [string]$ways[$wk][1]; $wz = [string]$ways[$wk][2]
    # 바늘 집합을 리터럴 대안 정규식 하나로(뜻 = 「바늘 하나라도 부분 문자열로 있다」 — 요청마다 PowerShell 고리 대신 .NET 한 번)
    $ndl = @(Needles-Of $sv)
    if ($ndl.Count -eq 0) { $pathBad += "$wk — 바늘 0(8자 미만 — 하네스 결함)"; continue }
    $nd = [regex]::new((($ndl | ForEach-Object { [regex]::Escape([string]$_) }) -join '|'), [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    foreach ($c in @($global:CurlCalls)) {
      $isM2m = $c.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal)
      $isVault = SEq $c.host '127.0.0.1'
      $isLogin = $isVault -and (SEq $c.path '/v1/auth/kubernetes/login')
      $sb = [System.Text.StringBuilder]::new()
      [void]$sb.AppendLine([string]$c.url); [void]$sb.AppendLine([string]$c.argv); [void]$sb.AppendLine([string]$c.data)
      $bd = [string]$c.body
      if ((SEq $wz 'login') -and $isLogin) {
        $bj = $null; try { $bj = $bd | ConvertFrom-Json -AsHashtable } catch { $bj = $null }
        if ($null -eq $bj -or @($bj.Keys).Count -ne 2 -or -not (SEq $bj['role'] 'e2e-reader') -or -not (SEq $bj['jwt'] $sv)) { $pathBad += 'JWT — 로그인 본문이 정확히 {role: e2e-reader, jwt: <JWT>} 가 아니다' }
        $bd = $bd.Replace($sv, '') }
      [void]$sb.AppendLine($bd)
      foreach ($hl in @($c.hdrLines)) {
        $ix = ([string]$hl).IndexOf([char]':'); $hn = $(if ($ix -gt 0) { ([string]$hl).Substring(0, $ix).Trim() } else { [string]$hl })
        $here = ($ah.Length -gt 0) -and (SEq $hn $ah) -and (((SEq $wz 'm2m') -and $isM2m) -or ((SEq $wz 'vault') -and $isVault))
        if ($here) { [void]$sb.AppendLine($hn) } else { [void]$sb.AppendLine([string]$hl) } }
      $hm = $nd.Match($sb.ToString())
      if ($hm.Success) { $pathBad += "$wk → $($c.host)$($c.path)(바늘 길이 $($hm.Value.Length))" } } }
  Check '자격의 길(S-02 ② — 바늘 = 전체 · base64 · 8자 이상 조각 · SHA-256): client_id · client_secret = O-8 m2m 요청의 그 두 헤더 값에만 · JWT = 로그인 본문 jwt 값에만 · Vault 토큰 = X-Vault-Token 값에만 — URL · 다른 헤더 · 다른 본문 · argv 0' ($pathBad.Count -eq 0) (@($pathBad | Select-Object -First 3) -join ' ; ')
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($k in @($PreEnv.Keys)) { if (Microsoft.PowerShell.Management\Test-Path -LiteralPath ('Env:' + $k)) { Remove-Item -LiteralPath ('Env:' + $k) } }
  $env:LOCALAPPDATA = $OrigLocalAppData
  Remove-Item -LiteralPath $caseDir -Recurse -Force -ErrorAction SilentlyContinue
  $global:Error.Clear()
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- 정적 관문(블록마다 — 관문 5 가 FAIL 이면 그 블록의 런타임 시나리오를 돌리지 않는다)
function Var-Name { param($n) $u = [string]$n.VariablePath.UserPath; $i = $u.LastIndexOf([char]':'); if ($i -ge 0) { $u.Substring($i + 1) } else { $u } }
function Cmd-Text { param($c) (@($c.CommandElements) | ForEach-Object { $_.Extent.Text }) -join ' ' }
function Sb-Names { param($ast)
  @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and $n.Right.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true) | ForEach-Object { Var-Name $_.Left }) }
function Find-Inner { param($ast)
  $stmts = $ast.EndBlock.Statements
  if ($stmts.Count -ne 1 -or $null -ne $ast.BeginBlock -or $null -ne $ast.ProcessBlock -or $null -eq $ast.ParamBlock) { return $null }
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
function Bad-Host { param($ast) , @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and ([string]::Equals((Var-Name $n), 'Host', [StringComparison]::OrdinalIgnoreCase) -or [string]::Equals((Var-Name $n), 'ExecutionContext', [StringComparison]::OrdinalIgnoreCase)) }, $true) | ForEach-Object { "L$($_.Extent.StartLineNumber) $($_.Extent.Text)" }) }
function Bad-Redir { param($ast) , @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FileRedirectionAst] }, $true) | Where-Object { -not (SEq $_.Location.Extent.Text '$null') } | ForEach-Object { "L$($_.Extent.StartLineNumber) $($_.Extent.Text)" }) }
function Bad-Secrets { param([string]$text) , @([regex]::Matches($text, '[A-Za-z0-9_\-+/=]{32,}') | Where-Object { $_.Value -cmatch '[A-Z]' -and $_.Value -cmatch '[a-z]' -and $_.Value -cmatch '[0-9]' } | ForEach-Object { $_.Value.Substring(0, 6) + '…' }) }
$FinallyCmds = @('Write-Host', 'Write-Warning', 'Remove-Variable', 'Stop-Job', 'Remove-Job')
function Finally-Emitters { param($stmts)
  $bad = @()
  foreach ($s in @($stmts)) {
    if ($s -is [System.Management.Automation.Language.AssignmentStatementAst]) { continue }
    if ($s -is [System.Management.Automation.Language.PipelineAst]) {
      $last = $s.PipelineElements[$s.PipelineElements.Count - 1]
      if ($last -is [System.Management.Automation.Language.CommandAst]) { if ($FinallyCmds -notcontains [string]$last.GetCommandName()) { $bad += "L$($s.Extent.StartLineNumber) $($last.GetCommandName())" } }
      elseif ($last -is [System.Management.Automation.Language.CommandExpressionAst] -and $last.Expression -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and (@('RemoveAt', 'Add') -contains [string]$last.Expression.Member.Value) -and @('$Error', '$info') -contains $last.Expression.Expression.Extent.Text) { }
      else { $bad += "L$($s.Extent.StartLineNumber) 값 출력 가능 식" }
      continue }
    if ($s -is [System.Management.Automation.Language.IfStatementAst]) { foreach ($c in $s.Clauses) { $bad += Finally-Emitters $c.Item2.Statements }; if ($null -ne $s.ElseClause) { $bad += Finally-Emitters $s.ElseClause.Statements }; continue }
    if ($s -is [System.Management.Automation.Language.TryStatementAst]) { $bad += Finally-Emitters $s.Body.Statements; foreach ($cc in $s.CatchClauses) { $bad += Finally-Emitters $cc.Body.Statements }; if ($null -ne $s.Finally) { $bad += Finally-Emitters $s.Finally.Statements }; continue }
    if ($s -is [System.Management.Automation.Language.LoopStatementAst]) { $bad += Finally-Emitters $s.Body.Statements; continue }
    $bad += "L$($s.Extent.StartLineNumber) 알 수 없는 문장($($s.GetType().Name))" }
  , $bad }
function Str-Values { param($ast) @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }, $true) | ForEach-Object { [string]$_.Value }) }
$TypesBase = @('string', 'System.String', 'StringComparison', 'System.StringComparison', 'regex', 'object', 'System.Object', 'DateTimeOffset', 'System.DateTimeOffset', 'System.Collections.Generic.List[string]', 'System.IO.Path', 'Math', 'System.Math')
$CmdsBase = @('Write-Host', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Get-Command', 'ConvertFrom-Json', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug', 'Remove-Variable', 'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path', 'kubectl.exe')
$WhoamiText = "kubectl.exe --kubeconfig `$kc --request-timeout=20s auth whoami -o 'jsonpath={.status.userInfo.username}'"
function Run-TStatic { param([string]$Id, [string]$File, [string]$ParamLine, [string[]]$Cmds, [string[]]$Types, [int]$N, [string]$Tag, [string[]]$KubectlTexts, [string[]]$CurlTexts, [string[]]$Hosts, [scriptblock]$Extra = $null, [string[]]$Exes = @())
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
  Check "줄 1 = $ParamLine · 줄 2 = & { · 빈 줄 0" ($lines.Count -gt 2 -and (SEq $lines[0] $ParamLine) -and (SEq $lines[1] '& {') -and $blank -eq 0) "빈 줄 $blank"
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $inner = Find-Inner $ast
  Check 'param 블록 = 줄 1 그대로(특성 · CmdletBinding 0 — 공통 매개변수 0) · 최상위 문장 1개 = & { … } · } 뒤 남는 문자 0' ($null -ne $inner -and (SEq $ast.ParamBlock.Extent.Text $ParamLine) -and $ast.ParamBlock.Attributes.Count -eq 0 -and @($ast.ParamBlock.Parameters | Where-Object { @($_.Attributes | Where-Object { $_ -isnot [System.Management.Automation.Language.TypeConstraintAst] }).Count -gt 0 }).Count -eq 0 -and $ast.EndBlock.Statements[0].Extent.EndOffset -eq $text.Length - 1)
  $helpers = Sb-Names $ast
  $badCmd = Bad-Cmds $ast $Cmds $helpers $inner
  Check "명령 허용 목록($($Cmds.Count)개 · 스크립트블록 헬퍼만 & — Read-Host · vault · tofu · Start-Process · Invoke-WebRequest · 절대 경로 실행 파일 0)" ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $Types
  Check '정적 .NET 호출 허용 목록' ($badType.Count -eq 0) ($badType -join '; ') -Gate
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 0(tester 블록은 입력을 받지 않는다)' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  if ($null -ne $inner) {
    $b0 = @($inner.EndBlock.Statements)
    $psd = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-PSDebug', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
    Check '본문 첫 문장 = Set-PSDebug -Off · 그 1곳뿐' ($b0.Count -gt 0 -and (SEq $b0[0].Extent.Text 'Set-PSDebug -Off') -and $psd -eq 1)
    $pre0 = @($b0 | ForEach-Object { $_.Extent.Text })
    $fixMissing = @(@("`$ErrorActionPreference = 'Stop'", '$PSNativeCommandUseErrorActionPreference = $false', "`$PSNativeCommandArgumentPassing = 'Standard'", '$WhatIfPreference = $false', "`$ConfirmPreference = 'High'", '$PSDefaultParameterValues = @{}', 'Set-StrictMode -Version 3.0') | Where-Object { $f = $_; @($pre0 | Where-Object { SEq $_ $f }).Count -ne 1 })
    Check '본문 직계 문장으로 세션 고정 7문장(오류 · 네이티브 · 인자 전달 Standard · WhatIf · Confirm · 기본 매개변수 · StrictMode)' ($fixMissing.Count -eq 0) ($fixMissing -join '; ')
    $tries = @($b0 | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
    Check '본문 try 1개 = catch(전부) + finally' ($tries.Count -eq 1 -and $null -ne $tries[0].Finally -and $tries[0].CatchClauses.Count -eq 1 -and $tries[0].CatchClauses[0].IsCatchAll)
    if ($tries.Count -eq 1 -and $null -ne $tries[0].Finally) {
      $fe = Finally-Emitters $tries[0].Finally.Statements
      Check 'finally 는 Write-Host · Remove-Variable · Stop-Job · Remove-Job · 대입 · $info.Add · $Error.RemoveAt 만(성공 스트림 출력 없음)' ($fe.Count -eq 0) ($fe -join '; ')
      $ft = $tries[0].Finally.Extent.Text
      Check "finally 끝 줄 = $Tag=PASS $N/$N 또는 $Tag=FAIL `$nPass/$N" ($ft.Contains("Write-Host '$Tag=PASS $N/$N'") -and $ft.Contains("Write-Host `"$Tag=FAIL `$nPass/$N`"") -and $ft.Contains("if (`$done -and `$res.Count -eq $N -and `$nPass -eq $N)")) }
    Check '본문 끝 두 문장 = 전부 PASS 일 때만 exit 0 · 그 밖 exit 1' ($b0.Count -ge 2 -and (SEq $b0[$b0.Count - 2].Extent.Text "if (`$done -and `$res.Count -eq $N -and `$nPass -eq $N) { exit 0 }") -and (SEq $b0[$b0.Count - 1].Extent.Text 'exit 1'))
    $iTry = [array]::IndexOf($b0, $tries[0])
    Check 'try 앞 직계 문장 = 세션 고정 · 상태 변수 대입 · $errTop 만(값 동작 0)' (@($b0[1..($iTry - 1)] | Where-Object { -not ($_ -is [System.Management.Automation.Language.AssignmentStatementAst] -or (SEq $_.Extent.Text 'Set-StrictMode -Version 3.0') -or (SEq $_.Extent.Text 'if ($Error.Count -gt 0) { $errTop = $Error[0] }')) }).Count -eq 0) }
  $reads = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check 'Read-Host 0(비대화형 — 입력은 param 뿐)' ($reads -eq 0)
  Check "다른 인자 판정 = @(`$script:args).Count -gt 0 → 멈춤(throw)" ($text.Contains('if (@($script:args).Count -gt 0) { throw "입력은'))
  Check '파일 실행 판정($PSScriptRoot)이 다른 인자 · 입력 꼴 판정보다 먼저' ($text.IndexOf('if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw', [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf('if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw', [StringComparison]::Ordinal) -lt $text.IndexOf('if (@($script:args).Count -gt 0)', [StringComparison]::Ordinal))
  Check '모듈 로깅 4키 가드 문장(PowerShellCore · UseWindowsPowerShellPolicySetting · Windows\PowerShell · EnableModuleLogging)' ($text.Contains('PowerShellCore\ModuleLogging') -and $text.Contains('UseWindowsPowerShellPolicySetting') -and $text.Contains('Windows\PowerShell\ModuleLogging') -and $text.Contains("'EnableModuleLogging') -eq 1"))
  $im = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Import-Module', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ })
  $gm = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Module', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ })
  $gfe = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Command', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ } | Where-Object { $_.Contains('ForEach-Object') })
  Check '모듈 로깅 실효 확인 문장(T075 KB-2 · KB2-1 꼴 그대로): Import-Module 셋 · Get-Module 둘 · Get-Command ForEach-Object -CommandType Cmdlet · 설정 파일 값 무관 텍스트 판정 · 확인 못 하면 멈춤' ($im.Count -eq 1 -and (SEq $im[0] 'Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security, Microsoft.PowerShell.Management') -and $gm.Count -eq 2 -and ($gm -ccontains 'Get-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security') -and ($gm -ccontains 'Get-Module Microsoft.PowerShell.Management') -and $gfe.Count -eq 1 -and (SEq $gfe[0] 'Get-Command ForEach-Object -CommandType Cmdlet') -and $text.Contains('{ $mlCore = $mlFe[0].PSSnapIn }') -and $text.Contains("if (`$null -ne `$mlCore -and `$mlCore.LogPipelineExecutionDetails) { `$mlEff += 'Microsoft.PowerShell.Core' }") -and $text.Contains('$mlEff = @(@($mlMods) + @($mlMgmt) | Where-Object { $_.LogPipelineExecutionDetails }') -and $text.Contains("-cmatch '(?i:ModuleLogging)|\x5Cu'") -and $text.Contains('if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw') -and $text.Contains("(Join-Path `$PSHOME 'powershell.config.json')") -and $text.Contains('$PROFILE.CurrentUserAllHosts'))
  $bad5 = @()
  foreach ($a5 in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    $lv = $a5.Left
    while ($lv -is [System.Management.Automation.Language.ConvertExpressionAst] -or $lv -is [System.Management.Automation.Language.AttributedExpressionAst]) { $lv = $lv.Child }
    while ($lv -is [System.Management.Automation.Language.MemberExpressionAst] -or $lv -is [System.Management.Automation.Language.IndexExpressionAst]) { if ($lv -is [System.Management.Automation.Language.IndexExpressionAst]) { $lv = $lv.Target } else { $lv = $lv.Expression } }
    if ($lv -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
    $vp = $lv.VariablePath
    if ($vp.IsDriveQualified -and [string]::Equals([string]$vp.DriveName, 'env', [StringComparison]::OrdinalIgnoreCase)) { $bad5 += "L$($a5.Extent.StartLineNumber) env 대입" }
    elseif ($vp.IsScript -or $vp.IsGlobal) { if (-not ($vp.IsGlobal -and (SEq (Var-Name $lv) 'LASTEXITCODE') -and $a5.Left -is [System.Management.Automation.Language.VariableExpressionAst])) { $bad5 += "L$($a5.Extent.StartLineNumber) $($lv.Extent.Text) 대입" } } }
  Check '$env: 대입 0 · $script: · $global: 대입은 $global:LASTEXITCODE 만(자식 프로세스 env · 전역에 값이 남는 길 0)' ($bad5.Count -eq 0) ($bad5 -join '; ')
  $kcRef = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.VariablePath.UserPath, 'env:KUBECONFIG', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check 'MOCK 0 · 비밀처럼 보이는 상수 0 · hvs.<영숫자> 0 · Start-Transcript 0 · $env:KUBECONFIG 참조 0' (-not $text.Contains('MOCK') -and (Bad-Secrets $text).Count -eq 0 -and -not ($text -cmatch 'hvs\.[A-Za-z0-9]') -and -not $text.Contains('Start-Transcript') -and $kcRef -eq 0) "$((Bad-Secrets $text) -join ', ') · KUBECONFIG $kcRef"
  $kca = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'kc') }, $true) | ForEach-Object { $_.Extent.Text })
  Check "kubeconfig = 리터럴 1곳(`$kc = Join-Path `$HOME '.kube\agent-view.yaml')" ($kca.Count -eq 1 -and (SEq $kca[0] "`$kc = Join-Path `$HOME '.kube\agent-view.yaml'"))
  $kt = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'kubectl.exe', [StringComparison]::Ordinal) }, $true) | ForEach-Object { Cmd-Text $_ })
  $ktBad = @($kt | Where-Object { -not ($KubectlTexts -ccontains $_) })
  Check "kubectl.exe 호출 = 정해진 꼴 $($KubectlTexts.Count)가지뿐(--kubeconfig 리터럴 첫 인자 · get · logs · whoami$(if ($File.StartsWith('o8', [StringComparison]::Ordinal)) { ' · port-forward' }) — 쓰기 · exec · Secret 0)" ($kt.Count -ge 1 -and $ktBad.Count -eq 0 -and @($KubectlTexts | Where-Object { $kt -ccontains $_ }).Count -eq $KubectlTexts.Count) ($ktBad -join ' | ')
  $ct = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'curl.exe', [StringComparison]::Ordinal) }, $true))
  $ctTexts = @($ct | ForEach-Object { Cmd-Text $_ })
  $ctBad = @($ctTexts | Where-Object { -not ($CurlTexts -ccontains $_) })
  Check "curl.exe 호출 = 정해진 꼴 $($CurlTexts.Count)가지뿐(첫 인자 -q)" ($ctBad.Count -eq 0 -and $ctTexts.Count -eq $CurlTexts.Count -and @($ctTexts | Where-Object { -not $_.StartsWith('curl.exe -q ', [StringComparison]::Ordinal) }).Count -eq 0) ($ctBad -join ' | ')
  $flagBad = @($ct | ForEach-Object { @($_.CommandElements | Select-Object -Skip 1) } | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] -or $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] } | ForEach-Object { if ($_ -is [System.Management.Automation.Language.CommandParameterAst]) { '-' + $_.ParameterName } else { [string]$_.Value } } | Where-Object { $CurlForbidden -ccontains $_ -or $_.StartsWith('--trace', [StringComparison]::Ordinal) })
  Check 'curl 금지 플래그 0(-v · -i · -D · -c · -b · --trace* · -L · --location* · -x · --proxy · -K · --config · -n · --netrc · -o · -k · -u)' ($flagBad.Count -eq 0) ($flagBad -join ' ')
  $sv = Str-Values $ast
  $hostVals = @($sv | Where-Object { $_.Contains('joshuatech.dev') -and $_ -notmatch '\s' } | Sort-Object -Unique)
  $hostBad = @($hostVals | Where-Object { -not ($Hosts -ccontains $_) })
  Check "리터럴 호스트 · URL = $($Hosts -join ' | ') 뿐(문자열 상수 · 확장 문자열 — 주석은 노드가 아니다)" ($hostBad.Count -eq 0 -and @($Hosts | Where-Object { $hostVals -ccontains $_ }).Count -eq $Hosts.Count) ($hostBad -join ' | ')
  # S-10: 외부 실행 파일은 형식 필터 없는 Get-Command 로만 찾고(-CommandType · -All 0) 첫 해석이 Application 이 아니면 — 그 어느 외부 호출(curl.exe · kubectl.exe · Start-ThreadJob)보다 먼저 — 멈춘다
  $gcx = [string[]]@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Command', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ } | Where-Object { -not $_.Contains('ForEach-Object') })
  $gcWant = [string[]]@($Exes | ForEach-Object { "Get-Command $_ -ErrorAction SilentlyContinue" })
  [Array]::Sort($gcx, [StringComparer]::Ordinal); [Array]::Sort($gcWant, [StringComparer]::Ordinal)
  $shSubj = $(if ($Exes.Count -eq 2) { '$shadow = @(@($ccs[0], $kcs[0]) | Where-Object' } else { '$shadow = @(@($kcs[0]) | Where-Object' })
  $shAt = $text.IndexOf('if ($shadow.Count -gt 0) { throw', [StringComparison]::Ordinal)
  # 첫 외부 호출 = 본문(& { }) 직계 흐름의 curl.exe · kubectl.exe · Start-ThreadJob 호출과 curl · kubectl 을 품은 헬퍼(& $get 등) 호출 가운데 가장 앞 — 헬퍼 정의(스크립트블록 글자)는 호출이 아니다
  $inner0 = Find-Inner $ast
  $exH = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and $n.Right.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true) | Where-Object { $_.Right.Extent.Text.Contains('curl.exe') -or $_.Right.Extent.Text.Contains('kubectl.exe') } | ForEach-Object { Var-Name $_.Left })
  $extAt = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | Where-Object { (@('curl.exe', 'kubectl.exe', 'Start-ThreadJob') -ccontains [string]$_.GetCommandName()) -or ($_.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $_.CommandElements[0] -is [System.Management.Automation.Language.VariableExpressionAst] -and $exH -ccontains [string]$_.CommandElements[0].VariablePath.UserPath) } | Where-Object { $p0 = $_.Parent; while ($null -ne $p0 -and $p0 -isnot [System.Management.Automation.Language.ScriptBlockAst]) { $p0 = $p0.Parent }; [object]::ReferenceEquals($p0, $inner0) } | ForEach-Object { $_.Extent.StartOffset } | Sort-Object)
  Check "실행 파일 첫 해석(S-10): $($gcWant -join ' · ') 그대로(형식 필터 · -All 0) · 첫 해석 CommandType ≠ Application 이면 멈춤 · 그 판정이 첫 외부 호출보다 먼저" ($Exes.Count -gt 0 -and (SEq ($gcx -join "`n") ($gcWant -join "`n")) -and $text.Contains($shSubj + " { -not (& `$eq ([string]`$_.CommandType) 'Application') } | ForEach-Object { `"`$(`$_.Name) = `$([string]`$_.CommandType)`" })") -and $shAt -gt 0 -and $extAt.Count -gt 0 -and $shAt -lt $extAt[0] -and -not $text.Contains('-CommandType Application')) "Get-Command [$($gcx -join ' | ')] · 판정 위치 $shAt · 첫 외부 호출 $(if ($extAt.Count) { $extAt[0] } else { '없음' })"
  # C-12: 날짜 꼴 ToString 은 InvariantCulture + 따옴표 리터럴 두 꼴뿐(문화권의 시간 구분자 · 달력이 끼지 않는다 — C-8 입력 정규식과 같은 꼴)
  $tsBad = @(); $tsN = 0
  foreach ($im in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]::Equals([string]$n.Member.Extent.Text, 'ToString', [StringComparison]::Ordinal) -and $null -ne $n.Arguments -and $n.Arguments.Count -ge 1 }, $true))) {
    $a0 = $im.Arguments[0]
    $fmt = $(if ($a0 -is [System.Management.Automation.Language.StringConstantExpressionAst]) { [string]$a0.Value } else { '' })
    if ($fmt -cnotmatch 'yy|MM|dd|HH|mm|ss') { continue }
    $tsN++
    if (-not ($im.Arguments.Count -eq 2 -and (SEq $im.Arguments[1].Extent.Text '[System.Globalization.CultureInfo]::InvariantCulture') -and @("yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyyMMdd'T'HHmmss'Z'") -ccontains $fmt)) { $tsBad += "L$($im.Extent.StartLineNumber) $($im.Extent.Text)" } }
  Check "날짜 꼴 ToString $tsN 곳 = InvariantCulture + 따옴표 리터럴(yyyy-MM-dd'T'HH:mm:ss'Z' · yyyyMMdd'T'HHmmss'Z')뿐(C-12)" ($tsBad.Count -eq 0) ($tsBad -join '; ')
  if ($Extra) { try { & $Extra $ast $text } catch { Check '블록별 정적 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  Finish-Case $Id "정적 — $File(관문 5 + 구조 · 세션 고정 · finally · 끝 줄 · exit · Read-Host 0 · 입력 판정 · 모듈 로깅 · 대입 제한 · kubeconfig 리터럴 · kubectl · curl 꼴 · 리터럴 호스트 · 블록별)" ''
  $g = @($global:CaseChecks | Where-Object { $_.gate })
  $badG = @($g | Where-Object { -not $_.ok } | ForEach-Object { $_.name })
  if ($g.Count -ne 5) { $badG += "관문 단언 $($g.Count)개(기대 5)" }
  $badG -join ' · ' }

try {
  # 멈춤 사례 공통: STOP 줄이 정확히 하나이고 그 줄에 사유 글자가 든다(블록은 멈춤도 잡아서 STOP 줄 + 끝 줄로 끝낸다)
  $script:stopLine = { param([string]$t)
    $sl = @($global:LastText -split "`n" | Where-Object { $_.StartsWith('STOP ', [StringComparison]::Ordinal) })
    Check "STOP 줄 1개 · 사유에 「$t」" ($sl.Count -eq 1 -and $sl[0].Contains($t)) $(if ($sl.Count) { $sl[0] } else { 'STOP 줄 없음' }) }
  # ================================================================ 정적 관문
  $o8Extra = { param($ast, $text)
    Check 'Vault = curl HTTP API 뿐(vault CLI 0) · port-forward(S-04) = Start-ThreadJob 한 꼴(--address 127.0.0.1 svc/vault :8200 — 포트는 kubectl 이 고른다 · TcpListener 0) · Forwarding 줄 판정(정확히 한 줄 · 127.0.0.1:<1–65535> -> 8200) · 출력 읽기 -Keep · Forwarding 줄 기다림(NotStarted · Running 만 · 90회 · 45 s — 터널 경유 수립 10–23 s · RO2-01) · seal-status 기다림 30회 · 15 s · 두 deadline 은 각 고리 앞(순서 — 「바로 앞」 · 대기 간격은 아래 기다림 고리 단언) · finally 에서 Stop-Job · Remove-Job' ($text.Contains('$pf = Start-ThreadJob -ScriptBlock { param($k) kubectl.exe --kubeconfig $k -n vault port-forward --address 127.0.0.1 svc/vault :8200 2>&1 } -ArgumentList $kc') -and -not $text.Contains('TcpListener') -and -not $text.Contains('IPAddress') -and $text.Contains('$po = @(Receive-Job -Job $pf -Keep -ErrorAction SilentlyContinue | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })') -and $text.Contains("`$fw = @(`$po | Where-Object { `$_.StartsWith('Forwarding from', [StringComparison]::Ordinal) })") -and $text.Contains('if ($fw.Count -gt 1) { $why = ') -and $text.Contains("`$fm = [regex]::Match(`$fw[0], '\AForwarding from 127\.0\.0\.1:([1-9][0-9]{0,4}) -> 8200\z')") -and $text.Contains('if ($fm.Success -and [int]$fm.Groups[1].Value -le 65535) { $n = [int]$fm.Groups[1].Value } else { $why = ') -and $text.Contains('for ($i = 0; $i -lt 90 -and $port -eq 0 -and [DateTimeOffset]::UtcNow -lt $deadline; $i++) {') -and $text.Contains('if ($pw.why.Length -gt 0) { break }') -and $text.Contains("elseif (-not (@('NotStarted', 'Running') -ccontains [string]`$pf.State)) { break }") -and $text.Contains('if ($port -eq 0) { throw') -and $text.Contains('for ($i = 0; $i -lt 30 -and $null -eq $seal -and [DateTimeOffset]::UtcNow -lt $deadline; $i++) {') -and @([regex]::Matches($text, [regex]::Escape('$deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)'))).Count -eq 1 -and @([regex]::Matches($text, [regex]::Escape('$deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)'))).Count -eq 1 -and $text.IndexOf('$deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)', [StringComparison]::Ordinal) -lt $text.IndexOf('for ($i = 0; $i -lt 90 -and $port -eq 0', [StringComparison]::Ordinal) -and $text.IndexOf('for ($i = 0; $i -lt 90 -and $port -eq 0', [StringComparison]::Ordinal) -lt $text.IndexOf('$deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)', [StringComparison]::Ordinal) -and $text.IndexOf('$deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)', [StringComparison]::Ordinal) -lt $text.IndexOf('for ($i = 0; $i -lt 30 -and $null -eq $seal', [StringComparison]::Ordinal) -and $text.Contains('$vbase = "http://127.0.0.1:$port"') -and $text.Contains('Stop-Job -Job $pf -ErrorAction SilentlyContinue') -and $text.Contains('Remove-Job -Job $pf -Force -ErrorAction SilentlyContinue') -and @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Start-ThreadJob', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count -eq 1)
    # 로그인 직전 재확인(S-04): try 본문에서 로그인 바로 앞 두 문장 = $pw = & $pfRead · (작업 Running · Forwarding 정확히 한 줄 · 같은 포트가 아니면 멈춤) — seal-status 판정 뒤
    $o8In = Find-Inner $ast
    $o8Tb = @(); if ($null -ne $o8In) { $o8Tr = @($o8In.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] }); if ($o8Tr.Count -eq 1) { $o8Tb = @($o8Tr[0].Body.Statements) } }
    $iL = -1; for ($q = 0; $q -lt $o8Tb.Count; $q++) { if ($o8Tb[$q].Extent.Text.StartsWith("`$lr = & `$vreq 'login'", [StringComparison]::Ordinal)) { $iL = $q } }
    Check '로그인 직전 재확인(S-04): 로그인 바로 앞 두 문장 = $pw = & $pfRead → 작업 Running · Forwarding 정확히 한 줄 · 같은 포트가 아니면 멈춤 · seal-status 판정 뒤' ($iL -ge 2 -and (SEq $o8Tb[$iL - 2].Extent.Text '$pw = & $pfRead') -and $o8Tb[$iL - 1].Extent.Text.StartsWith("if (-not (& `$eq ([string]`$pf.State) 'Running') -or `$pw.why.Length -gt 0 -or `$pw.port -ne `$port) { throw", [StringComparison]::Ordinal) -and $text.IndexOf("-not (& `$eq `$cname 'vault-cluster-d3b29227')", [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf("-not (& `$eq `$cname 'vault-cluster-d3b29227')", [StringComparison]::Ordinal) -lt $o8Tb[$iL - 1].Extent.StartOffset) "로그인 문장 위치 $iL"
    # 기다림 고리(r2 검증 V1-01 · V1-02 — 컨트롤러 보정 r2): 실효 기다림 = min(기한, 횟수 × 간격)이다. 위 단언은 기한 · 횟수 글자와 상대 순서만 보고, 모의 Start-Sleep 은 지속 시간을
    # 버린다(런타임은 간격을 못 본다) — 그래서 여기서 고정한다: 각 고리 바로 앞 문장 = 제 $deadline 대입 · 고리 본문의 대기 = Start-Sleep -Milliseconds 500 정확히 하나 · o8 의 Start-Sleep 은 그 둘뿐
    $iFw = -1; $iSe = -1; for ($q = 0; $q -lt $o8Tb.Count; $q++) { if ($o8Tb[$q] -is [System.Management.Automation.Language.ForStatementAst]) { if ($o8Tb[$q].Extent.Text.StartsWith('for ($i = 0; $i -lt 90 -and $port -eq 0', [StringComparison]::Ordinal)) { $iFw = $q } elseif ($o8Tb[$q].Extent.Text.StartsWith('for ($i = 0; $i -lt 30 -and $null -eq $seal', [StringComparison]::Ordinal)) { $iSe = $q } } }
    $slp = { param($n) @($n.FindAll({ param($m) $m -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$m.GetCommandName(), 'Start-Sleep', [StringComparison]::OrdinalIgnoreCase) }, $true)) }
    $sFw = @(); if ($iFw -ge 0) { $sFw = @(& $slp $o8Tb[$iFw].Body) }
    $sSe = @(); if ($iSe -ge 0) { $sSe = @(& $slp $o8Tb[$iSe].Body) }
    Check '기다림 고리(V1-01 · V1-02): 각 고리 바로 앞 문장 = 제 $deadline 대입(45 s → 90회 · 15 s → 30회) · 고리 본문의 대기 = Start-Sleep -Milliseconds 500 정확히 하나(실효 ≤ 45 s · ≤ 15 s) · o8 의 Start-Sleep 은 그 둘뿐' ($iFw -ge 1 -and $iSe -ge 1 -and (SEq $o8Tb[$iFw - 1].Extent.Text '$deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)') -and (SEq $o8Tb[$iSe - 1].Extent.Text '$deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)') -and $sFw.Count -eq 1 -and $sSe.Count -eq 1 -and (SEq $sFw[0].Extent.Text 'Start-Sleep -Milliseconds 500') -and (SEq $sSe[0].Extent.Text 'Start-Sleep -Milliseconds 500') -and @(& $slp $ast).Count -eq 2) "고리 위치 $iFw · $iSe · 대기 $($sFw.Count) · $($sSe.Count)"
    # 요청 호출 꼴(S-02 ③): & $get 네 곳 · & $vreq 다섯 곳의 글자를 고정한다(헤더 배열 · 경로 · 본문 — 여분 헤더 · 다른 경로 · 다른 본문 0)
    $hv = [string[]]@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $n.CommandElements[0] -is [System.Management.Automation.Language.VariableExpressionAst] -and @('get', 'vreq') -ccontains [string]$n.CommandElements[0].VariablePath.UserPath }, $true) | ForEach-Object { Cmd-Text $_ })
    $hvWant = [string[]]@('$get "$base/health$q" (@($cred) + @("X-Request-ID: $nonce-$ev-health"))', '$get "$base$pp$q" (@($cred) + @("X-Request-ID: $nonce-$ev-$id"))', '$get "$base$($x[0])$q" (@($cred) + @("X-Request-ID: $nonce-$ev-$($x[1])"))',
      '$get "$base/health$q" @("CF-Access-Client-Id: $fakeId", "CF-Access-Client-Secret: $fakeSec", "X-Request-ID: $nonce-$ev-fake")', '$vreq ''seal'' ''/v1/sys/seal-status'' $null ''''', '$vreq ''login'' ''/v1/auth/kubernetes/login'' (''{"role":"e2e-reader","jwt":"'' + $jwt + ''"}'') ''''',
      '$vreq ''tok'' ''/v1/sys/capabilities-self'' @("X-Vault-Token: $vtok") ''{"paths":["kv/data/platform/access/tester-m2m","kv/data/platform/access/tester-k8s","kv/metadata/platform/access/tester-m2m","kv/data/platform/authentik/e2e","kv/data/prod/db/identity_admin/app"]}''',
      '$vreq ''tok'' ''/v1/kv/data/platform/access/tester-m2m'' @("X-Vault-Token: $vtok") ''''', '$vreq ''tok'' ''/v1/auth/token/revoke-self'' @("X-Vault-Token: $vtok") ''{}''')
    [Array]::Sort($hv, [StringComparer]::Ordinal); [Array]::Sort($hvWant, [StringComparer]::Ordinal)
    Check '요청 호출 꼴(S-02 ③): & $get 네 꼴 · & $vreq 다섯 꼴 그대로(헤더 배열 · 경로 · 본문 — 여분 헤더 · 다른 경로 0)' (SEq ($hv -join "`n") ($hvWant -join "`n")) "$($hv.Count)곳 · 다른 것: $(@($hv | Where-Object { $hvWant -cnotcontains $_ }) -join ' | ')"
    Check '요청별 INFO($note — C-05): at · code · ct · cfc · cf-ray(값마다 $clean — 제어 문자 → ? · 160자) · 날짜 ToString 네 곳(at · jwt exp · nonce · start)이 InvariantCulture(C-12)' ($text.Contains('$note = { param($ev, $id, $r) $info.Add("o8 $ev $id at=$($r.at) code=$(if ($r.code) { & $clean $r.code } else { ''(없음)'' }) ct=$(if ($r.ct) { & $clean $r.ct } else { ''(없음)'' }) cfc=$(if ($r.cfc) { & $clean $r.cfc } else { ''(없음)'' }) cf-ray=$(if ($r.ray) { & $clean $r.ray } else { ''(없음)'' })") }') -and @([regex]::Matches($text, [regex]::Escape(', [System.Globalization.CultureInfo]::InvariantCulture)'))).Count -eq 4)
    $fio = @([regex]::Matches($text, '\[System\.IO\.File\]::[A-Za-z]+\([^)]*\)') | ForEach-Object { $_.Value })
    Check 'JWT 파일 = 리터럴 경로 · 읽기 꼴 하나([System.IO.File]::ReadAllText(path, ASCII).Trim() → ConvertTo-SecureString → NetworkCredential) · 지우기 · 쓰기 0' ($text.Contains("`$jwtPath = Join-Path `$env:LOCALAPPDATA 'jt-e2e\vault-e2e-reader.jwt'") -and $fio.Count -eq 1 -and (SEq $fio[0] '[System.IO.File]::ReadAllText($jwtPath, [System.Text.Encoding]::ASCII)') -and $text.Contains('$sec = ConvertTo-SecureString ([System.IO.File]::ReadAllText($jwtPath, [System.Text.Encoding]::ASCII).Trim())') -and $text.Contains("`$jwt = [System.Net.NetworkCredential]::new('', `$sec).Password") -and -not $text.Contains('Remove-Item') -and -not $text.Contains('WriteAll'))
    Check 'JWT 클레임 판정(aud = 문자열 "vault" 또는 원소 하나 문자열 배열 ["vault"] · Ordinal — VD-T076-10 · sub agent-view · exp > 지금 + 60 · exp − iat ≤ 3610)이 port-forward 보다 먼저 · INFO aud 꼴' ($text.Contains("if (`$null -ne `$audP -and `$audP.Value -is [string] -and (& `$eq `$audP.Value 'vault')) { `$audForm = '문자열' }") -and $text.Contains("elseif (`$null -ne `$audP -and `$audP.Value -is [array] -and `$audP.Value.Count -eq 1 -and `$audP.Value[0] -is [string] -and (& `$eq `$audP.Value[0] 'vault')) { `$audForm = '배열' }") -and $text.Contains("else { `$jwhy += 'aud ≠ ") -and $text.Contains('Write-Host "INFO jwt aud 꼴=$audForm(') -and $text.Contains('if ($exp -le $now + 60)') -and $text.Contains('if ($exp -le $iat -or $exp - $iat -gt 3610)') -and $text.IndexOf('if ($exp -le $now + 60)', [StringComparison]::Ordinal) -lt $text.IndexOf('$pf = Start-ThreadJob', [StringComparison]::Ordinal))
    Check '로그인 본문 = stdin(--data-binary @-) · JWT 변수는 로그인 다음 문장에서 비운다 · 응답 판정(policies ∋ e2e-reader · lease ≤ 3600)' ($text.Contains("`$lr = & `$vreq 'login' '/v1/auth/kubernetes/login' ('{`"role`":`"e2e-reader`",`"jwt`":`"' + `$jwt + '`"}') ''`n    `$jwt = ''") -and $text.Contains("-not (`$lpol -ccontains 'e2e-reader') -or -not (`$llease -is [long]) -or `$llease -le 0 -or `$llease -gt 3600"))
    Check '권한 관문 다섯 경로 · 기대 값(read · deny)이 설계 D4 ⑧ 그대로 · kv 읽기보다 먼저' ($text.Contains("`$capWant = [ordered]@{ 'kv/data/platform/access/tester-m2m' = 'read'; 'kv/data/platform/access/tester-k8s' = 'deny'; 'kv/metadata/platform/access/tester-m2m' = 'deny'; 'kv/data/platform/authentik/e2e' = 'read'; 'kv/data/prod/db/identity_admin/app' = 'deny' }") -and $text.Contains("'{`"paths`":[`"kv/data/platform/access/tester-m2m`",`"kv/data/platform/access/tester-k8s`",`"kv/metadata/platform/access/tester-m2m`",`"kv/data/platform/authentik/e2e`",`"kv/data/prod/db/identity_admin/app`"]}'") -and $text.IndexOf('/v1/sys/capabilities-self', [StringComparison]::Ordinal) -lt $text.IndexOf("'/v1/kv/data/platform/access/tester-m2m'", [StringComparison]::Ordinal))
    Check 'kv 판정: 키 정확히 둘 · client_id \A[0-9a-f]{32}\.access\z · client_secret \A[0-9A-Za-z_-]{54}\z(-cnotmatch)' ($text.Contains("`$kn.Count -ne 2 -or -not (`$kn -ccontains 'client_id') -or -not (`$kn -ccontains 'client_secret')") -and $text.Contains("`$cid -cnotmatch '\A[0-9a-f]{32}\.access\z' -or `$csec -cnotmatch '\A[0-9A-Za-z_-]{54}\z'"))
    Check 'seal-status 판정(sealed false · cluster_name vault-cluster-d3b29227)이 로그인보다 먼저' ($text.Contains("-not (& `$eq `$cname 'vault-cluster-d3b29227')") -and $text.IndexOf("-not (& `$eq `$cname 'vault-cluster-d3b29227')", [StringComparison]::Ordinal) -lt $text.IndexOf("`$lr = & `$vreq 'login'", [StringComparison]::Ordinal))
    Check '-w 형식 = 허용 목록 7개 그대로(%{http_code} · %{content_type} · %{size_download} · x-request-id · cache-control · cf-cache-status · cf-ray) · Vault 형식 = http_code 만 · Set-Cookie 0' ($text.Contains("`$wfmt = '" + $global:W_O8 + "'") -and $text.Contains("`$vfmt = '" + $global:W_V + "'") -and -not ($text -match '(?i)set-cookie\}') -and @([regex]::Matches($text, '%header\{[a-z-]+\}') | ForEach-Object { $_.Value } | Sort-Object -Unique).Count -eq 4)
    Check '헤더 줄 stdin: 자격 · X-Request-ID 는 $hdr | curl.exe -H @- 로만 · 토큰은 "X-Vault-Token: $vtok" 배열을 stdin 으로만' ($text.Contains('$cred = @("CF-Access-Client-Id: $cid", "CF-Access-Client-Secret: $csec")') -and $text.Contains('$out = @($hdr | curl.exe') -and @([regex]::Matches($text, '@\("X-Vault-Token: \$vtok"\)')).Count -eq 3)
    Check '환경 변수 멈춤 목록 = SSL_CERT_FILE · SSL_CERT_DIR · CURL_CA_BUNDLE · SSLKEYLOGFILE · *_PROXY · VAULT_*(대소문자 무관) · TF_* 0(tofu 0)' ($text.Contains("@('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains `$_.Name -or `$_.Name -like 'VAULT_*'") -and -not $text.Contains('TF_'))
    Check 'Transcription 정책 판정(레지스트리 PowerShellCore 둘 + Windows 둘 · 설정 파일 낱말) · 실행 파일 위치 판정(저장소 · TEMP · TMP — 멈춤)' ($text.Contains('PowerShellCore\Transcription') -and $text.Contains('Windows\PowerShell\Transcription') -and $text.Contains("'EnableTranscripting') -eq 1") -and $text.Contains("-cmatch '(?i:Transcription)'") -and $text.Contains('$roots = @(@($repo, $env:TEMP, $env:TMP)') -and $text.Contains('if ($exeBad.Count -gt 0) { throw'))
    Check 'finally: 토큰이 있으면 revoke-self(stdin 헤더) → port-forward 종료 순서 · INFO o8 start 가 첫 Access 요청보다 먼저' ($text.IndexOf("'/v1/auth/token/revoke-self'", [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf("'/v1/auth/token/revoke-self'", [StringComparison]::Ordinal) -lt $text.IndexOf('Stop-Job -Job $pf', [StringComparison]::Ordinal) -and $text.IndexOf('Write-Host "INFO o8 start=', [StringComparison]::Ordinal) -lt $text.IndexOf('$r = & $get "$base/health$q"', [StringComparison]::Ordinal)) }
  $c8Extra = { param($ast, $text)
    $sv = Str-Values $ast
    $forb = @($sv | Where-Object { $_ -notmatch '\s' } | Where-Object { $v = $_; @('Cf-Connecting', 'User-Agent', 'ClientHost', 'ClientAddr', 'ClientUsername', 'ServiceAddr', 'ServiceURL') | Where-Object { $v.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0 } })
    Check '투영 밖 필드 이름(Cf-Connecting-Ip · User-Agent · ClientHost · ClientAddr · ClientUsername · ServiceAddr · ServiceURL)을 필드 이름 꼴 문자열(공백 0)로 부르지 않는다(읽지도 옮기지도 않는다)' ($forb.Count -eq 0) ($forb -join ' | ')
    Check '투영 = StartUTC · RequestHost · RequestMethod · RequestPath · DownstreamStatus · OriginStatus · RouterName 유무 · request_Cf-Ray(대소문자 무관 이름)' ($text.Contains("start = [string](& `$prop `$o 'StartUTC'); host = `$rh; method = [string](& `$prop `$o 'RequestMethod'); path = `$rp; ds = [string](& `$prop `$o 'DownstreamStatus'); os = [string](& `$prop `$o 'OriginStatus'); router = (`$null -ne `$rn -and ([string]`$rn).Length -gt 0)") -and $text.Contains("[string]::Equals(`$_.Name, 'request_Cf-Ray', [StringComparison]::OrdinalIgnoreCase)"))
    Check '입력 판정(-Since 꼴 · 날짜 · 범위 · -Nonce 꼴)이 첫 kubectl 보다 먼저 · Traefik 복제 판정이 logs 보다 먼저' ($text.IndexOf("if (`$Nonce -cnotmatch '\At076-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}\z')", [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf("if (`$Nonce -cnotmatch", [StringComparison]::Ordinal) -lt $text.IndexOf('$wo = @(kubectl.exe', [StringComparison]::Ordinal) -and $text.IndexOf("if (`$Since -cnotmatch '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z')", [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf('-n kube-system get deployments.apps traefik -o json', [StringComparison]::Ordinal) -gt 0 -and $text.IndexOf('-n kube-system get deployments.apps traefik -o json', [StringComparison]::Ordinal) -lt $text.IndexOf('-n kube-system logs deploy/traefik "--since-time=$Since"', [StringComparison]::Ordinal))
    Check 'curl 0 · Vault 0 · JWT 0(비밀 0 블록)' (-not $text.Contains('curl.exe') -and -not $text.Contains('jwt') -and -not $text.Contains('Start-ThreadJob')) }
  $l8Extra = { param($ast, $text)
    Check 'admin Location = [System.Uri] 로 읽어 scheme://host/path 만 낸다(쿼리 0) · 호스트 joshua-tech.cloudflareaccess.com · 경로 접두 /cdn-cgi/access/login/' ($text.Contains('$uri = [System.Uri]::new($ad.loc)') -and $text.Contains('$safe = "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"') -and $text.Contains("[string]::Equals(`$uri.Host, 'joshua-tech.cloudflareaccess.com', [StringComparison]::OrdinalIgnoreCase)") -and $text.Contains("`$uri.AbsolutePath.StartsWith('/cdn-cgi/access/login/', [StringComparison]::Ordinal)") -and -not $text.Contains('$uri.Query') -and -not $text.Contains('$ad.loc)"'))
    Check '-w 형식 = http_code · content_type · %header{location} 만(헤더 통째 · Set-Cookie 0)' ($text.Contains("`$wfmt = '" + $global:W_L8 + "'"))
    Check '기대 리터럴(gitops cb3ba13): 템플릿 키 11 · 원격 키 12줄 · -migrate owner · wave · 참조 셋 · 프로브 값' ($text.Contains("`$tplEnv = @('DATABASE_URL', 'KAFKA_PASSWORD', 'DRAGONFLY_URL', 'AUTHENTIK_ISSUER', 'AUTHENTIK_JWKS_URL', 'SENTRY_DSN', 'SECRET_KEY', 'AUTHENTIK_API_TOKEN', 'AUTHENTIK_WEBHOOK_SECRET', 'OPENFGA_STORE_ID', 'OPENFGA_PRESHARED_KEY')") -and $text.Contains("`$roleOf = @{ dev = 'dev_identity_admin'; prod = 'identity_admin' }") -and $text.Contains("'volume-secret:jt-kafka-cluster-ca-cert'") -and $text.Contains("`$refJob = (@('migrate:envFrom-secret:identity-admin-migrate', 'volume-secret:pg-main-ca') | Sort-Object) -join ' '") -and $text.Contains("(& `$hg (& `$prop `$web 'startupProbe') '/ready' 5 30)"))
    $kg = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.CommandElements.Count -eq 4 -and $n.CommandElements[0].Extent.Text -ceq '$kget' }, $true) | ForEach-Object { Cmd-Text $_ } | Sort-Object -Unique)
    $kgWant = @("`$kget 'argocd' 'applications.argoproj.io' `"identity-admin-`$ev`"", "`$kget `$ns 'externalsecrets.external-secrets.io' 'identity-admin-env'", "`$kget `$ns 'externalsecrets.external-secrets.io' 'identity-admin-migrate'", "`$kget `$ns 'deployments.apps' 'identity-admin'", "`$kget `$ns 'deployments.apps' 'identity-admin-celery'", "`$kget `$ns 'jobs.batch' 'identity-admin-migrate'")
    Check 'kubectl get 대상 = Application · ES 둘 · Deployment 둘 · Job 뿐(Secret 0)' ($kg.Count -eq 6 -and @($kgWant | Where-Object { $kg -ccontains $_ }).Count -eq 6) ($kg -join ' | ')
    Check 'Vault 0 · JWT 0 · 자격 헤더 0(비밀 0 블록 — X-Vault-Token · /v1/ · jwt · CF-Access · stdin 헤더 0)' (-not $text.Contains('X-Vault-Token') -and -not $text.Contains('/v1/') -and -not $text.Contains('jwt') -and -not $text.Contains('CF-Access') -and -not $text.Contains("-H '@-'") -and -not $text.Contains('Start-ThreadJob')) }
  $o8Cmds = @($CmdsBase) + @('curl.exe', 'ConvertTo-SecureString', 'Start-ThreadJob', 'Receive-Job', 'Stop-Job', 'Remove-Job', 'Start-Sleep')
  $o8Types = @($TypesBase) + @('System.IO.File', 'System.Text.Encoding', 'System.Net.NetworkCredential', 'Convert', 'System.Security.Cryptography.RandomNumberGenerator', 'System.Globalization.CultureInfo')
  $o8Curl = @('curl.exe -q -sS --max-time 20 -H ''@-'' -w $wfmt $url', 'curl.exe -q -sS --max-time 5 -w $vfmt $u', 'curl.exe -q -sS --max-time 20 -H ''Content-Type: application/json'' --data-binary ''@-'' -w $vfmt $u', 'curl.exe -q -sS --max-time 20 -H ''@-'' -w $vfmt $u', 'curl.exe -q -sS --max-time 20 -H ''@-'' --data $data -w $vfmt $u', 'curl.exe -q --version')
  $c8Kube = @($WhoamiText, 'kubectl.exe --kubeconfig $kc --request-timeout=30s -n kube-system get deployments.apps traefik -o json', 'kubectl.exe --kubeconfig $kc --request-timeout=30s -n kube-system logs deploy/traefik "--since-time=$Since"', 'kubectl.exe --kubeconfig $kc --request-timeout=30s -n "jt-$ev" logs deploy/identity-admin -c web "--since-time=$Since"')
  $l8Kube = @($WhoamiText, 'kubectl.exe --kubeconfig $kc --request-timeout=30s -n $ns get $kind $name -o json', 'kubectl.exe --kubeconfig $kc --request-timeout=30s -n "jt-$ev" logs deploy/identity-admin -c startup-check')
  $Stat = @(
    @('ST-O8', 'o8-probe-identity-m2m.ps1', "param([string]`$ExpectedSha = '')", $o8Cmds, $o8Types, 10, 'o8', @($WhoamiText, 'kubectl.exe --kubeconfig $k -n vault port-forward --address 127.0.0.1 svc/vault :8200'), $o8Curl, @('https://identity-m2m-$ev.joshuatech.dev'), $o8Extra, 'O8', @('curl.exe', 'kubectl.exe')),
    @('ST-C8', 'c8-correlate-logs.ps1', "param([string]`$Since = '', [string]`$Nonce = '')", (@($CmdsBase) + @('Sort-Object')), (@($TypesBase) + @('System.Collections.Generic.List[object]', 'System.Globalization.CultureInfo', 'System.Globalization.DateTimeStyles')), 10, 'c8', $c8Kube, @(), @('identity-m2m-$ev.joshuatech.dev', 'identity-m2m-dev.joshuatech.dev', 'identity-m2m-prod.joshuatech.dev'), $c8Extra, 'C8', @('kubectl.exe')),
    @('ST-L8', 'l8-live-identity-admin.ps1', "param([string]`$ExpectedRevision = '')", (@($CmdsBase) + @('curl.exe', 'Sort-Object')), (@($TypesBase) + @('System.Uri')), 24, 'l8', $l8Kube, @('curl.exe -q --version', 'curl.exe -q -sS --max-time 20 -w $wfmt $url'), @('https://identity-m2m-$ev.joshuatech.dev/health', 'https://admin.joshuatech.dev/identity-admin/admin/'), $l8Extra, 'L8', @('curl.exe', 'kubectl.exe')))
  foreach ($s in $Stat) {
    if (-not (Want-Block $s[11])) { continue }
    $g = Run-TStatic -Id $s[0] -File $s[1] -ParamLine $s[2] -Cmds $s[3] -Types $s[4] -N $s[5] -Tag $s[6] -KubectlTexts $s[7] -CurlTexts $s[8] -Hosts $s[9] -Extra $s[10] -Exes $s[12]
    $global:BGate[$s[1]] = $g
    if ($g) { Write-Host "관문 FAIL($($s[0])): $g — 그 블록의 런타임 시나리오를 실행하지 않는다" -ForegroundColor Red } }

  # ================================================================ O-8 런타임
  if (Want-Block 'O8') {
    Write-Host '=== O-8 ==='
    $O8F = 'o8-probe-identity-m2m.ps1'
    $AO8 = @{ curl = $true; kubectl = $true; job = $true }
    $script:o8Ok = { $n = Now-Unix; Write-JwtFile (Make-Jwt -iat ($n - 600) -exp ($n + 3000)) }
    $script:o8Info = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$final, [int]$exit, [string[]]$want, [string[]]$notwant, [scriptblock]$post, [hashtable]$pre = @{}, [hashtable]$p = $null, [string[]]$extra = @())
      if ($null -eq $p) { $p = @{ ExpectedSha = $global:M_DeploySha } }
      Run-TCase -Id $id -Desc $desc -File $O8F -P $p -Extra $extra -Allow $AO8 -Setup $setup -Final $final -Exit $exit -Want $want -NotWant $notwant -Post $post -PreEnv $pre }
    # 요청 순서 · 대조 키 · 자격 길(정상 · FAIL 판정 사례 공통): dev → prod · env 마다 health · admin · webhooks · healthz · ready · apix · sessionsX · health/ · tenants/me · 가짜 자격
    $script:o8Order = {
      $acc = @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) })
      $want = @(foreach ($ev in 'dev', 'prod') { foreach ($x in @(@('/health', 'health'), @('/admin/', 'admin'), @('/webhooks/authentik', 'webhooks'), @('/healthz', 'healthz'), @('/ready', 'ready'), @('/apix', 'apix'), @('/sessionsX', 'sessionsx'), @('/health/', 'healthslash'), @('/tenants/me', 'tenantsme'), @('/health', 'fake'))) { "identity-m2m-$ev.joshuatech.dev|$($x[0])|$ev-$($x[1])" } })
      $mn = [regex]::Match($global:LastText, 'INFO o8 start=([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z) nonce=(t076-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}) ')
      Check 'INFO o8 start=<UTC> nonce=<t076-…> 줄 1개 · 첫 Access 요청보다 먼저(C-8 입력)' ($mn.Success -and @([regex]::Matches($global:LastText, 'INFO o8 start=')).Count -eq 1)
      $nonce = $mn.Groups[2].Value
      $got = @($acc | ForEach-Object { "$($_.host)|$($_.path)|" + $(if ([string]$_.hdr['X-Request-ID'] -cmatch ('\A' + [regex]::Escape($nonce) + '-(.+)\z')) { $Matches[1] } else { '?' }) })
      Check 'Access 요청 20개 = dev → prod · 정해진 순서 · 경로 · X-Request-ID <nonce>-<env>-<id>' ((@($got) -join ';') -ceq (@($want) -join ';')) "$($got.Count)개"
      Check '모든 Access 요청 쿼리 = t076=<nonce> 하나 · GET · 헤더는 stdin 만(argv -H 0)' (@($acc | Where-Object { -not (SEq $_.query "t076=$nonce") -or -not (SEq $_.method 'GET') -or $_.argvHeaders.Count -gt 0 }).Count -eq 0)
      Check '자격 헤더: 판정 · INFO 요청 18개 = tester-m2m · 가짜 자격 2개 = 비밀 아닌 고정 값(0×32.access · A×54)' (@($acc | Where-Object { $_.hdr['X-Request-ID'] -notlike '*-fake' -and -not ((SEq $_.hdr['CF-Access-Client-Id'] $global:M_Cred.id) -and (SEq $_.hdr['CF-Access-Client-Secret'] $global:M_Cred.secret)) }).Count -eq 0 -and @($acc | Where-Object { $_.hdr['X-Request-ID'] -like '*-fake' -and (SEq $_.hdr['CF-Access-Client-Id'] (('0' * 32) + '.access')) -and (SEq $_.hdr['CF-Access-Client-Secret'] ('A' * 54)) }).Count -eq 2)
      Check '요청마다 INFO <env> <id> at=<UTC> code=<코드> ct=<원문 정제> cfc=<값 정제> cf-ray=<값> 20줄(C-05 · at 은 InvariantCulture 꼴)' (@([regex]::Matches($global:LastText, 'INFO o8 (dev|prod) [a-z]+ at=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z code=([0-9]{3}|\(없음\)) ct=[^\n]+ cfc=\S+ cf-ray=\S+')).Count -eq 20) }
    $script:o8Vault = {
      Check 'Vault 순서 = seal-status → login(본문 stdin · Content-Type argv 만) → capabilities-self(다섯 경로) → kv 1회 → revoke-self(finally)' ((@($global:VCalls | ForEach-Object { "$($_.method) $($_.path)" }) -join ';') -ceq 'GET /v1/sys/seal-status;POST /v1/auth/kubernetes/login;POST /v1/sys/capabilities-self;GET /v1/kv/data/platform/access/tester-m2m;POST /v1/auth/token/revoke-self') ((@($global:VCalls | ForEach-Object { "$($_.method) $($_.path)" }) -join ';'))
      Check 'port-forward 1회 = -n vault port-forward --address 127.0.0.1 svc/vault :8200(포트는 kubectl 이 고른다) · 작업 인자 = 리터럴 kubeconfig 하나 · Vault 요청 포트 = Forwarding 줄의 포트(실행마다 다른 모의 포트)' ($global:PfCalls -eq 1 -and $global:JobLog.Count -eq 1 -and $global:JobLog[0].args.Count -eq 1 -and (SEq $global:JobLog[0].args[0] $global:KcPath) -and @($global:CurlCalls | Where-Object { SEq $_.host '127.0.0.1' }).Count -ge 1 -and @($global:CurlCalls | Where-Object { (SEq $_.host '127.0.0.1') -and -not (SEq $_.port ([string]$global:PfPort)) }).Count -eq 0)
      Check 'capabilities-self 경로 = 설계 다섯 그대로' ($global:CapAsked.Count -eq 1 -and (SEq $global:CapAsked[0] 'kv/data/platform/access/tester-m2m,kv/data/platform/access/tester-k8s,kv/metadata/platform/access/tester-m2m,kv/data/platform/authentik/e2e,kv/data/prod/db/identity_admin/app'))
      Check 'kubectl 호출 = whoami(--request-timeout=20s) · port-forward 뿐' ((@($global:XArgv | Where-Object { $_.StartsWith('kubectl.exe ', [StringComparison]::Ordinal) }) -join ';') -ceq ("kubectl.exe --kubeconfig $($global:KcPath) --request-timeout=20s auth whoami -o jsonpath={.status.userInfo.username};kubectl.exe --kubeconfig $($global:KcPath) -n vault port-forward --address 127.0.0.1 svc/vault :8200")) }
    # port-forward 멈춤 사례 공통: Vault 0(seal-status 도 · 로그인 curl 도 0) · JWT 0 · 작업은 finally 에서 끈다
    $script:o8PfNothing = {
      Check 'Vault 요청 0(seal-status · 로그인 curl 0) · JWT 0 · kv 0 · Access 0' (@($global:CurlCalls | Where-Object { SEq $_.host '127.0.0.1' }).Count -eq 0 -and $global:JwtSent -eq 0 -and $global:KvReads -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0) }
    # 꼴이 틀린 Forwarding 줄 · 끝난 작업은 곧바로 멈춘다(Forwarding 줄 기다림 상한 45 s 를 기다리지 않는다): 기다림 = 시작 대기 1(NotStarted · 출력 지연) · Receive-Job 2
    $script:o8PfQuick = { & $script:o8PfNothing; Check '곧바로 멈춤(기다림 1 = 시작 대기만 · Receive-Job 2)' (@($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 1 -and $global:PfReads -eq 2) "기다림 $(@($global:Events | Where-Object { SEq $_ 'sleep' }).Count) · Receive-Job $($global:PfReads)" }
    $script:o8Nothing = { param([string]$what)
      Check "아무것도 보내지 않았다($what — Access · Vault · port-forward 0)" (@($global:CurlCalls | Where-Object { -not (SEq $_.host '127.0.0.1') }).Count -eq 0 -and $global:JwtSent -eq 0 -and $global:KvReads -eq 0) }
    & $script:o8Info 'O8-01' 'O-8 정상: dev · prod 판정 10 PASS · INFO(VD-L9 403 type · /health/ Traefik 꼴 · CN 음성 403 · 가짜 자격 401 · x-request-id = 보낸 값) · revoke 204 · port-forward 종료 · 자격 · 토큰 · JWT · 쿠키 노출 0' $script:o8Ok 'o8=PASS 10/10' 0 `
      @('PASS o8 dev a GET /health', 'PASS o8 prod e GET /ready', 'INFO o8 dev INFO GET /apix → 403 · application/problem+json · type=https://joshuatech.dev/problems/access-required', 'INFO o8 prod INFO GET /sessionsX → 403', 'INFO o8 dev INFO GET /health/ → 404 · text/plain · 19 B · cf-cache-status=DYNAMIC · Traefik 404 꼴', 'INFO o8 prod INFO GET /tenants/me → 403 · application/problem+json · type=https://joshuatech.dev/problems/access-required', 'INFO o8 dev INFO 가짜 자격(비밀 아닌 고정 값 — 0×32.access · A×54) GET /health → 401', 'INFO o8 dev health x-request-id = 보낸 값(VD-T076-4)', 'INFO vault token revoked(204)', 'INFO port-forward 종료', 'OK   권한 관문(sys/capabilities-self): kv/data/platform/access/tester-m2m=[read] · kv/data/platform/access/tester-k8s=[deny]', 'INFO jwt exp=', 'INFO jwt aud 꼴=배열(VD-T076-10', 'OK   Vault seal-status: sealed=false · cluster_name=vault-cluster-d3b29227(port-forward 127.0.0.1:', 'INFO curl 8.23 · Application C:\Program Files\MockTools\curl.exe · kubectl Application C:\Program Files\MockTools\kubectl.exe',
        'INFO o8 dev admin at=', ' code=404 ct=text/plain; charset=utf-8 cfc=DYNAMIC cf-ray=', 'INFO o8 prod health at=', ' code=200 ct=application/json cfc=DYNAMIC cf-ray=', 'INFO o8 prod fake at=', ' code=401 ct=text/html; charset=UTF-8 cfc=(없음) cf-ray=', ' code=403 ct=application/problem+json cfc=DYNAMIC cf-ray=') `
      @('FAIL ', 'STOP ', 'aud 꼴=문자열') { & $script:o8Order; & $script:o8Vault; Check 'port-forward 시작: NotStarted 1회 · 출력 지연 1회를 기다렸다(기다림 1 · Receive-Job 3 = 기다림 고리 2 + 로그인 직전 1 · -Keep)' (@($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 1 -and $global:PfReads -eq 3) "기다림 $(@($global:Events | Where-Object { SEq $_ 'sleep' }).Count) · Receive-Job $($global:PfReads)" }
    $script:o8Fail = @(
      @('O8-02', '/admin/ 가 pod 에 닿아 404 problem+json(Ingress 가 열림 · pod 404) → b FAIL 둘', { & $script:o8Ok; $global:Model['podAdmin404'] = $true }, 'o8=FAIL 8/10', @('FAIL o8 dev b GET /admin/', '미디어 타입 = application/problem+json', '본문 ≠ 「404 page not found」 한 줄')),
      @('O8-03', 'Ingress /health 를 Prefix 로 넓힌 변이 — /healthz 200(pod 면제 경로) → d FAIL 둘 · /health/ 는 pod 403(INFO — Exact 가 아니다)', { & $script:o8Ok; $global:Model['healthPrefix'] = $true }, 'o8=FAIL 8/10', @('FAIL o8 dev d GET /healthz', 'FAIL o8 prod d GET /healthz', '응답 200', 'INFO o8 dev INFO GET /health/ → 403 · application/problem+json')),
      @('O8-04', '/admin 경로가 열림(라우터 → pod CN 불일치 403) → b FAIL 둘', { & $script:o8Ok; $global:Model['openAdmin'] = $true }, 'o8=FAIL 8/10', @('FAIL o8 prod b GET /admin/', '응답 403')),
      @('O8-05', '404 넷이 cf-cache-status HIT(Cloudflare 저장본) → b–e FAIL 여덟', { & $script:o8Ok; $global:Model['hit404'] = $true }, 'o8=FAIL 2/10', @('FAIL o8 dev c GET /webhooks/authentik', 'cf-cache-status = HIT')),
      @('O8-06', '/health 가 cf-cache-status HIT → a FAIL 둘', { & $script:o8Ok; $global:Model['hitHealth'] = $true }, 'o8=FAIL 8/10', @('FAIL o8 dev a GET /health', 'cf-cache-status = HIT')),
      @('O8-07', 'Access 가 tester-m2m 을 거부(403 — include 밖) → 판정 10 FAIL', { & $script:o8Ok; $global:Model['credReject'] = '403' }, 'o8=FAIL 0/10', @('FAIL o8 dev a GET /health', '응답 403', 'FAIL o8 prod e GET /ready')),
      @('O8-08', 'Access 가 tester-m2m 을 401 로 거부 → 판정 10 FAIL', { & $script:o8Ok; $global:Model['credReject'] = '401' }, 'o8=FAIL 0/10', @('응답 401', 'FAIL o8 prod b GET /admin/')),
      @('O8-09', '404 본문이 CRLF(20 B · 줄바꿈 다름) → b–e FAIL 여덟(size_download)', { & $script:o8Ok; $global:Model['crlf'] = $true }, 'o8=FAIL 2/10', @('size_download = 20')),
      @('O8-10', 'git_sha 가 입력과 다르다(옛 이미지) → a FAIL 둘', { & $script:o8Ok; $global:HealthMut = { param($b) $b['git_sha'] = (Hex-Lower 'other-sha').Substring(0, 40) } }, 'o8=FAIL 8/10', @('FAIL o8 dev a GET /health', 'git_sha = ')),
      @('O8-11', 'checks 에 키 하나 더(openfga) → a FAIL 둘', { & $script:o8Ok; $global:HealthMut = { param($b) $b['checks']['openfga'] = [ordered]@{ status = 'ok' } } }, 'o8=FAIL 8/10', @('checks 키 4개')),
      @('O8-12', 'status degraded · checks.dragonfly fail → a FAIL 둘', { & $script:o8Ok; $global:HealthMut = { param($b) $b['status'] = 'degraded'; $b['checks']['dragonfly']['status'] = 'fail' } }, 'o8=FAIL 8/10', @('status = degraded', 'checks.dragonfly = fail')))
    foreach ($c in $script:o8Fail) { & $script:o8Info $c[0] "O-8 $($c[1])" $c[2] $c[3] 1 $c[4] @('STOP ') { & $script:o8Order; & $script:o8Vault } }
    & $script:o8Info 'O8-13' 'O-8 pod 가 상류 X-Request-ID 를 버림(uuid) → INFO 만(VD-T076-4) · 판정 10 PASS' { & $script:o8Ok; $global:Model['noXrid'] = $true } 'o8=PASS 10/10' 0 @('≠ 보낸 값(mock-') @('FAIL ') { & $script:o8Order }
    & $script:o8Info 'O8-14' 'O-8 Access 응답 헤더 cf-ray 에 터미널 제어열(OSC 52) → INFO 줄은 ? 로' { & $script:o8Ok; $global:HttpFn = { param($req) $r = Http-Default $req; $r.ray = 'ray-x' + [char]27 + ']52;c;QUJD' + [char]7; $r } } 'o8=PASS 10/10' 0 @('cf-ray=ray-x?]52;c;QUJD?') @() $null
    & $script:o8Info 'O8-15' 'O-8 curl 이 이름 풀이 실패(exit 6) → 판정 10 FAIL(curl exit=6) · revoke · port-forward 종료' { & $script:o8Ok; $global:F['curlFail'] = $true } 'o8=FAIL 0/10' 1 @('curl exit=6 · curl: (6) Could not resolve host: identity-m2m-dev.joshuatech.dev') @('STOP ') { & $script:o8Vault }
    & $script:o8Info 'O8-14b' 'O-8 INFO 경로 응답의 Content-Type · cf-cache-status 에 터미널 제어열 → 요청별 INFO 의 ct= · cfc= 는 ? 로(C-05 정제) · 판정 10 PASS' { & $script:o8Ok; $global:HttpFn = { param($req) $r = Http-Default $req; if (SEq $req.path '/apix') { $r.ct = 'application/problem+json' + [char]27 + ']52;c;QUJD' + [char]7 }; if (SEq $req.path '/tenants/me') { $r.cfc = 'DYN' + [char]27 + '[2JAMIC' }; $r } } 'o8=PASS 10/10' 0 @('ct=application/problem+json?]52;c;QUJD? cfc=DYNAMIC cf-ray=', ' cfc=DYN?[2JAMIC cf-ray=') @('FAIL ', 'STOP ') $null
    & $script:o8Info 'O8-16' 'O-8 seal-status 가 두 번 거절된 뒤 응답(port-forward 기동 중) → 기다렸다가 정상 PASS' { & $script:o8Ok; $global:PfNotStarted = 0; $global:PfLag = 0; $global:SealRefuse = 2 } 'o8=PASS 10/10' 0 @() @('FAIL ') { Check 'seal-status 재시도 3회 · 기다림 2회' (@($global:CurlCalls | Where-Object { SEq $_.path '/v1/sys/seal-status' }).Count -eq 3 -and @($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 2) }
    & $script:o8Info 'O8-17' 'O-8 404 응답이 cf-cache-status STALE → b–e 판정은 「≠ HIT」 그대로 PASS(원 서버 도달은 C-8 Traefik 줄 · request_id 가 판정 — C-05) · 요청별 INFO 에 cfc=STALE 이 남는다' { & $script:o8Ok; $global:Model['stale404'] = $true } 'o8=PASS 10/10' 0 @('PASS o8 dev b GET /admin/', ' code=404 ct=text/plain; charset=utf-8 cfc=STALE cf-ray=') @('FAIL ', 'STOP ') { & $script:o8Order; Check '요청별 INFO cfc=STALE 10줄(판정 404 넷 + INFO /health/ — dev · prod)' (@([regex]::Matches($global:LastText, ' code=404 ct=text/plain; charset=utf-8 cfc=STALE ')).Count -eq 10) }
    & $script:o8Info 'O8-18' 'O-8 현재 문화권 th-TH(불기 달력) + 시간 구분자 「.」 → start · nonce · at · jwt exp 는 그레고리력 · 「:」 그대로(C-12 — C-8 의 -Since · -Nonce 정규식에 맞는다)' { & $script:o8Ok; $ci = [System.Globalization.CultureInfo]::new('th-TH'); $ci.DateTimeFormat.TimeSeparator = '.'; [System.Globalization.CultureInfo]::CurrentCulture = $ci } 'o8=PASS 10/10' 0 @() @('FAIL ', 'STOP ') {
      $near = { param([string]$s, [string]$f, [int]$h) $d = [DateTimeOffset]::MinValue; ([DateTimeOffset]::TryParseExact($s, $f, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$d)) -and [Math]::Abs(($d - [DateTimeOffset]::UtcNow).TotalHours) -lt $h }
      $c8s = '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z'; $c8n = '\At076-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}\z'; $iso = "yyyy-MM-dd'T'HH:mm:ss'Z'"
      $mn = [regex]::Match($global:LastText, 'INFO o8 start=(\S+) nonce=(\S+) ')
      $ex = [regex]::Match($global:LastText, 'INFO jwt exp=(\S+) ')
      $ats = @([regex]::Matches($global:LastText, 'INFO o8 (?:dev|prod) [a-z]+ at=(\S+) ') | ForEach-Object { $_.Groups[1].Value })
      Check 'start · nonce = C-8 입력 정규식(-Since · -Nonce) 꼴 · 그레고리력(지금 ±1시간)' ($mn.Success -and $mn.Groups[1].Value -cmatch $c8s -and $mn.Groups[2].Value -cmatch $c8n -and (& $near $mn.Groups[1].Value $iso 1) -and (& $near $mn.Groups[2].Value.Substring(5, 16) "yyyyMMdd'T'HHmmss'Z'" 1)) "start=$($mn.Groups[1].Value) nonce=$($mn.Groups[2].Value)"
      Check 'jwt exp · 요청별 at 20개도 같은 꼴(그레고리력 · 「:」)' ($ex.Success -and $ex.Groups[1].Value -cmatch $c8s -and (& $near $ex.Groups[1].Value $iso 2) -and $ats.Count -eq 20 -and @($ats | Where-Object { $_ -cnotmatch $c8s -or -not (& $near $_ $iso 1) }).Count -eq 0) "exp=$($ex.Groups[1].Value) · at $($ats.Count)개"
      [System.Globalization.CultureInfo]::CurrentCulture = $OrigCulture }
    & $script:o8Info 'O8-19' 'O-8 port-forward 가 늦게 뜬다(NotStarted 3회 · 출력 3회 늦음) → 기다렸다가 정상 PASS(NotStarted 에서 멈추지 않는다 — 실측: 시작 직후 NotStarted)' { & $script:o8Ok; $global:PfNotStarted = 3; $global:PfLag = 3 } 'o8=PASS 10/10' 0 @() @('FAIL ', 'STOP ') { Check 'Forwarding 줄 기다림 3회 · Receive-Job 5(기다림 고리 4 + 로그인 직전 1)' (@($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 3 -and $global:PfReads -eq 5) "기다림 $(@($global:Events | Where-Object { SEq $_ 'sleep' }).Count) · Receive-Job $($global:PfReads)" }
    # RO2-01(T076 r2): 터널 경유 port-forward 수립 10–23 s(T048 F19 · reboot-1 15.7 s) — Forwarding 줄이 출력 40회 늦게(0.5 s × 40 = 20 s) 보여도 기다린다(30회 · 15 s 상한이면 멈췄을 지연)
    & $script:o8Info 'O8-19b' 'O-8 Forwarding 줄이 출력 40회 늦게 보인다(터널 경유 수립 지연 ≈ 20 s — 30회 · 15 s 상한이면 멈췄다 · RO2-01) → 기다렸다가 정상 PASS' { & $script:o8Ok; $global:PfLag = 40 } 'o8=PASS 10/10' 0 @('OK   Vault seal-status: sealed=false') @('FAIL ', 'STOP ') { & $script:o8Vault; Check 'Forwarding 줄 기다림 40회 · Receive-Job 42(기다림 고리 41 + 로그인 직전 1)' (@($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 40 -and $global:PfReads -eq 42) "기다림 $(@($global:Events | Where-Object { SEq $_ 'sleep' }).Count) · Receive-Job $($global:PfReads)" }
    # ---- 멈춤 사례(아무것도 보내지 않거나 · 읽지 않거나 · Access 0)
    $script:o8Stop = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$stopText, [scriptblock]$post, [hashtable]$pre = @{}, [hashtable]$p = $null, [string[]]$extra = @())
      $global:Fx = @($stopText, $post)
      & $script:o8Info $id $desc $setup 'o8=FAIL 0/10' 1 @('STOP ') @('PASS o8 ') { & $script:stopLine $global:Fx[0]; if ($null -ne $global:Fx[1]) { & $global:Fx[1] } } $pre $p $extra }
    & $script:o8Stop 'O8-20' 'O-8 seal-status cluster_name 이 다른 Vault → JWT 0 전송 · 멈춤' { & $script:o8Ok; $global:V['cluster'] = 'vault-cluster-832ae26d' } 'Vault seal-status 가 기대와 다르다(응답 200 · sealed=False · cluster_name=vault-cluster-832ae26d)' { & $script:o8Nothing 'JWT 0' }
    & $script:o8Stop 'O8-21' 'O-8 Vault 가 봉인(sealed true) → JWT 0 전송 · 멈춤' { & $script:o8Ok; $global:V['sealed'] = $true } 'Vault seal-status 가 기대와 다르다(응답 200 · sealed=True' { & $script:o8Nothing 'JWT 0' }
    & $script:o8Stop 'O8-22' 'O-8 port-forward 가 15 s 안에 응답 없음(seal-status 30회 거절) → JWT 0 · 작업 종료' { & $script:o8Ok; $global:PfNotStarted = 0; $global:PfLag = 0; $global:SealRefuse = 999 } ')가 15 s 안에 응답하지 않았다(작업 Running · 마지막 줄 Forwarding from 127.0.0.1:' { & $script:o8Nothing 'JWT 0'; Check 'seal-status 30회 · 기다림 30회(0.5 s × 30 = 15 s 상한)' (@($global:CurlCalls | Where-Object { SEq $_.path '/v1/sys/seal-status' }).Count -eq 30 -and @($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 30) }
    & $script:o8Stop 'O8-23' 'O-8 port-forward 실패(pods/portforward 거부) → 작업 Failed · 곧바로 멈춤 · Vault · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'rbac' } '을 45 s 안에 얻지 못했다(작업 Failed · 마지막 줄 error: error upgrading connection' { & $script:o8PfQuick }
    # ---- port-forward Forwarding 줄 판정(S-04): 바인드 실패 · 줄 없음 · [::1]만(127.0.0.1 의 같은 포트를 남이 중계) · 두 줄 · 다른 원격 포트 · 포트 범위 밖 · 로그인 직전 작업 종료 · 로그인 직전 줄 늘어남
    & $script:o8Stop 'O8-23b' 'O-8 port-forward 127.0.0.1 바인드 실패(kubectl 종료 → 작업 Completed) → 곧바로 멈춤 · Vault · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'bind' } '을 45 s 안에 얻지 못했다(작업 Completed · 마지막 줄 error: unable to listen on any of the requested ports: [{0 8200}])' { & $script:o8PfQuick }
    & $script:o8Stop 'O8-23c' 'O-8 port-forward 가 Running 인데 Forwarding 줄이 45 s 안에 없다 → 멈춤 · Vault · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'silent' } '을 45 s 안에 얻지 못했다(작업 Running · 출력 없음)' { & $script:o8PfNothing; Check 'Receive-Job 90 · 기다림 90(0.5 s × 90 = 45 s 상한 — RO2-01)' ($global:PfReads -eq 90 -and @($global:Events | Where-Object { SEq $_ 'sleep' }).Count -eq 90) "Receive-Job $($global:PfReads) · 기다림 $(@($global:Events | Where-Object { SEq $_ 'sleep' }).Count)" }
    & $script:o8Stop 'O8-23d' 'O-8 port-forward 가 [::1] 줄만(127.0.0.1 의 같은 포트는 남이 쥐고 Vault 로 중계 — S-04 위협 모형) → 꼴 아님 · 멈춤 · seal-status 도 0 · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'v6only' } 'Forwarding 줄 꼴 아님(Forwarding from [::1]:' { & $script:o8PfQuick }
    & $script:o8Stop 'O8-23e' 'O-8 port-forward Forwarding 줄 둘(127.0.0.1 · [::1]) → 정확히 한 줄 아님 · 멈춤 · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'both' } '(작업 Running · Forwarding 줄 2개(정확히 한 줄이어야 한다 — Forwarding from 127.0.0.1:' { & $script:o8PfQuick }
    & $script:o8Stop 'O8-23f' 'O-8 port-forward 원격 포트가 8201(다른 꼴) → 멈춤 · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'remote' } ' -> 8201 — 기대 127.0.0.1:<포트> -> 8200)' { & $script:o8PfQuick }
    & $script:o8Stop 'O8-23g' 'O-8 port-forward 로컬 포트 70000(범위 밖 — 다른 꼴) → 멈춤 · JWT 0' { & $script:o8Ok; $global:F['pf'] = 'range' } 'Forwarding 줄 꼴 아님(Forwarding from 127.0.0.1:70000 -> 8200 — 기대' { & $script:o8PfQuick }
    & $script:o8Stop 'O8-23h' 'O-8 seal-status 뒤 · 로그인 직전에 port-forward 작업이 끝남(Completed) → 재확인에서 멈춤 · 로그인 curl 0 · JWT 0' { & $script:o8Ok; $global:F['pfDieAfterSeal'] = $true } '로그인 직전 port-forward 재확인 실패(작업 Completed · Forwarding 줄 그대로) — JWT 를 보내지 않았다' { Check 'seal-status 1 · 로그인 curl 0 · JWT 0 · kv 0 · Access 0' (@($global:CurlCalls | Where-Object { SEq $_.path '/v1/sys/seal-status' }).Count -eq 1 -and @($global:CurlCalls | Where-Object { SEq $_.path '/v1/auth/kubernetes/login' }).Count -eq 0 -and $global:JwtSent -eq 0 -and $global:KvReads -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0) }
    & $script:o8Stop 'O8-23i' 'O-8 seal-status 뒤 · 로그인 직전에 Forwarding 줄이 둘로 늘어남([::1] 줄이 붙음) → 재확인에서 멈춤 · 로그인 curl 0' { & $script:o8Ok; $global:F['pfLateLine'] = $true } '로그인 직전 port-forward 재확인 실패(작업 Running · Forwarding 줄 2개' { Check 'seal-status 1 · 로그인 curl 0 · JWT 0' (@($global:CurlCalls | Where-Object { SEq $_.path '/v1/sys/seal-status' }).Count -eq 1 -and @($global:CurlCalls | Where-Object { SEq $_.path '/v1/auth/kubernetes/login' }).Count -eq 0 -and $global:JwtSent -eq 0) }
    & $script:o8Stop 'O8-24' 'O-8 capabilities 가 설계와 다름(tester-k8s read) → kv 읽기 0 · Access 0 · revoke' { & $script:o8Ok; $global:V['caps']['kv/data/platform/access/tester-k8s'] = @('read') } '권한 관문 FAIL(sys/capabilities-self 응답 200 · kv/data/platform/access/tester-m2m=[read] · kv/data/platform/access/tester-k8s=[read]' { Check 'kv 읽기 0 · Access 0' ($global:KvReads -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0); Check 'revoke 1회' ($global:Revokes -eq 1) }
    foreach ($c in @(@('O8-25', 'metadata 경로 read', 'kv/metadata/platform/access/tester-m2m', @('read', 'list')), @('O8-26', 'prod DB 경로 read', 'kv/data/prod/db/identity_admin/app', @('read')), @('O8-27', 'tester-m2m deny(정책 apply 전)', 'kv/data/platform/access/tester-m2m', @('deny')))) {
      $global:O8Mut = @($c[2], $c[3])
      & $script:o8Stop $c[0] "O-8 capabilities 가 설계와 다름($($c[1])) → kv 읽기 0 · Access 0" { & $script:o8Ok; $global:V['caps'][$global:O8Mut[0]] = @($global:O8Mut[1]) } '권한 관문 FAIL' { Check 'kv 읽기 0 · Access 0' ($global:KvReads -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0) } }
    $okS = Cf-Secret 'secret-shape-t076'
    foreach ($c in @(@('O8-28', '키 하나 더(note)', { $global:V['kv']['note'] = 'x' }, @()), @('O8-29', 'client_secret 없음', { $global:V['kv'].Remove('client_secret') }, @()),
        @('O8-30', 'client_secret 64 소문자 hex(옛 꼴)', { $global:V['kv']['client_secret'] = (Hex-Lower 'MOCK-hex64') }, @((Hex-Lower 'MOCK-hex64'))),
        @('O8-31', 'client_secret 맞는 54자 + 끝 LF', { $global:V['kv']['client_secret'] = $okS + "`n" }, @($okS)),
        @('O8-32', 'client_secret 가운데 CR(헤더 주입)', { $global:V['kv']['client_secret'] = $okS.Substring(0, 26) + "`r" + $okS.Substring(26, 27) }, @($okS.Substring(0, 26), $okS.Substring(26, 27))),
        @('O8-33', 'client_secret 53자 + U+212A(Kelvin — -c 고정)', { $global:V['kv']['client_secret'] = $okS.Substring(0, 53) + [string][char]0x212A }, @($okS.Substring(0, 53))),
        @('O8-34', 'client_id 대문자 hex', { $global:V['kv']['client_id'] = (Hex-Lower 'cid-upper').Substring(0, 32).ToUpperInvariant() + '.access' }, @()))) {
      $global:O8Mut = @($c[2], $c[3])
      & $script:o8Stop $c[0] "O-8 kv 값이 꼴 밖($($c[1])) → Access 0 · 값 미출력 · revoke" { & $script:o8Ok; & $global:O8Mut[0]; foreach ($x in @($global:O8Mut[1])) { [void]$global:Secrets.Add([string]$x) } } 'tester-m2m 자격을 꺼내지 못했다(kv 응답 200' { Check 'Access 0' (@($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0); Check 'kv 읽기 1 · revoke 1' ($global:KvReads -eq 1 -and $global:Revokes -eq 1) } }
    & $script:o8Stop 'O8-35' 'O-8 kv 읽기 403 → Access 0 · revoke' { & $script:o8Ok; $global:V['kvCode'] = '403' } 'tester-m2m 자격을 꺼내지 못했다(kv 응답 403' { Check 'Access 0' (@($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0) }
    $script:jwtStop = @(
      @('O8-40', 'JWT 만료(exp = 지금 + 30 s)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -iat ($n - 3570) -exp ($n + 30)) }, 'JWT 판정 실패: exp 가 지금 + 60 s 안이다'),
      @('O8-41', 'JWT aud 가 K8s API(audience 없는 agent-view 토큰)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud @('https://kubernetes.default.svc.cluster.local', 'k3s') -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42b', 'JWT aud 가 원소 둘(vault + K8s API)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud @('vault', 'https://kubernetes.default.svc.cluster.local') -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42c', 'JWT aud 가 문자열 "Vault"(대소문자 다름 — Ordinal)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud 'Vault' -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42d', 'JWT aud 가 배열 ["Vault"](대소문자 다름)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud @('Vault') -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42e', 'JWT aud 가 숫자 1(다른 형)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud 1 -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42f', 'JWT aud 가 겹 배열 [["vault"]](원소가 문자열 아님 — [string] 변환이면 "vault" 로 보인다)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud @(, @('vault')) -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42g', 'JWT aud 가 빈 배열 []', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud @() -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42h', 'JWT aud 가 null', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud $null -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-42i', 'JWT aud 가 문자열 "vault "(끝 공백)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud 'vault ' -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-43', 'JWT aud 없음', { $n = Now-Unix; Write-JwtFile (Make-Jwt -NoAud -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: aud ≠ "vault" · ["vault"]'),
      @('O8-44', 'JWT sub 가 다른 SA', { $n = Now-Unix; Write-JwtFile (Make-Jwt -sub 'system:serviceaccount:kube-system:default' -iat ($n - 600) -exp ($n + 3000)) }, 'JWT 판정 실패: sub ≠ system:serviceaccount:kube-system:agent-view'),
      @('O8-45', 'JWT 수명 8h(exp − iat = 28800 — UD-16 1시간 밖)', { $n = Now-Unix; Write-JwtFile (Make-Jwt -iat ($n - 600) -exp ($n - 600 + 28800)) }, 'JWT 판정 실패: 수명 exp − iat = 28800 s'),
      @('O8-46', 'JWT 꼴 아님(점 하나)', { $j = Make-Jwt -iat 1 -exp 2; $parts = $j.Split('.'); Write-JwtFile ($parts[0] + '.' + $parts[1]) }, 'JWT 판정 실패: JWT 꼴 아님'),
      @('O8-47', 'JWT 파일이 DPAPI 가 아니다(깨진 글자)', { Write-JwtFile '' -raw 'zz-not-dpapi' }, 'JWT 파일을 복호하지 못했다'),
      @('O8-48', 'JWT 파일 없음', { }, '운영자 O-9 필요 — JWT 파일이 없다'))
    foreach ($c in $script:jwtStop) {
      & $script:o8Stop $c[0] "O-8 $($c[1]) → 멈춤 · port-forward · Vault · Access 0" $c[2] $c[3] { & $script:o8Nothing 'JWT 단계'; Check 'port-forward 0 · 작업 0' ($global:PfCalls -eq 0 -and $global:JobLog.Count -eq 0) } }
    & $script:o8Info 'O8-42' 'O-8 JWT aud 가 문자열 "vault"(K3s 단일 audience 직렬화 후보 — VD-T076-10) → 받는다 · INFO aud 꼴=문자열 · 판정 10 PASS' { $n = Now-Unix; Write-JwtFile (Make-Jwt -aud 'vault' -iat ($n - 600) -exp ($n + 3000)) } 'o8=PASS 10/10' 0 @('INFO jwt aud 꼴=문자열(VD-T076-10') @('FAIL ', 'STOP ', 'aud 꼴=배열') { & $script:o8Order; & $script:o8Vault }
    & $script:o8Stop 'O8-49' 'O-8 로그인 거부(403 — aud 판정 · role 정책) → 읽기 0 · revoke 0(토큰 없음)' { & $script:o8Ok; $global:V['loginCode'] = '403' } 'Vault 로그인 실패(role e2e-reader · 응답 403)' { Check '토큰 발급 0 · capabilities · kv 0 · Access 0' ($global:TokIssued -eq 0 -and $global:CapAsked.Count -eq 0 -and $global:KvReads -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.StartsWith('identity-m2m-', [StringComparison]::Ordinal) }).Count -eq 0) }
    & $script:o8Stop 'O8-50' 'O-8 로그인 응답 policies 에 e2e-reader 없음 → 읽기 0 · revoke' { & $script:o8Ok; $global:V['policies'] = @('default', 'eso-platform') } 'Vault 로그인 응답이 설계와 다르다(policies=default,eso-platform · lease_duration=3600)' { Check 'capabilities · kv 0 · revoke 1' ($global:CapAsked.Count -eq 0 -and $global:KvReads -eq 0 -and $global:Revokes -eq 1) }
    & $script:o8Stop 'O8-51' 'O-8 로그인 응답 lease_duration 7200 → 읽기 0 · revoke' { & $script:o8Ok; $global:V['lease'] = [long]7200 } 'Vault 로그인 응답이 설계와 다르다(policies=default,e2e-reader · lease_duration=7200)' { Check 'capabilities · kv 0 · revoke 1' ($global:CapAsked.Count -eq 0 -and $global:KvReads -eq 0 -and $global:Revokes -eq 1) }
    & $script:o8Info 'O8-52' 'O-8 revoke-self 가 500 → INFO 로 기록 · 판정 10 PASS(토큰은 lease 안에 만료)' { & $script:o8Ok; $global:V['revokeFail'] = $true } 'o8=PASS 10/10' 0 @('INFO vault token revoked(500)') @() $null
    foreach ($c in @(@('O8-60', 'VAULT_TOKEN', 'hvs.not-a-real-token-0000'), @('O8-61', 'vault_addr', 'http://127.0.0.1:18200'), @('O8-62', 'HTTPS_PROXY', 'http://127.0.0.1:8888'), @('O8-63', 'https_proxy', 'http://127.0.0.1:8889'), @('O8-64', 'ALL_PROXY', 'socks5://127.0.0.1:1080'), @('O8-65', 'SSLKEYLOGFILE', 'C:\keylog.txt'), @('O8-66', 'CURL_CA_BUNDLE', 'C:\other-ca.pem'), @('O8-67', 'SSL_CERT_FILE', 'C:\other-ca.pem'))) {
      & $script:o8Stop $c[0] "O-8 환경 변수 $($c[1]) 있음 → 이름만 내고 멈춤 · 아무것도 부르지 않는다" $script:o8Ok "이 창에 curl · Vault 동작을 바꾸는 환경 변수가 있다: $($c[1])" { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } @{ $c[1] = $c[2] } }
    & $script:o8Stop 'O8-68' 'O-8 Transcription 정책(HKLM PowerShellCore) 켜짐 → 멈춤 · 아무것도 부르지 않는다' { & $script:o8Ok; $global:Policy['HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription'] = @{ EnableTranscripting = 1 } } 'PowerShell Transcription 정책이 켜져 있다(레지스트리: HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) }
    & $script:o8Stop 'O8-69' 'O-8 Transcription(UseWindowsPowerShellPolicySetting=1 → Windows HKCU 키) 켜짐 → 멈춤' { & $script:o8Ok; $global:Policy['HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription'] = @{ UseWindowsPowerShellPolicySetting = 1 }; $global:Policy['HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription'] = @{ EnableTranscripting = 1 } } 'PowerShell Transcription 정책이 켜져 있다(레지스트리: HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) }
    & $script:o8Stop 'O8-70' 'O-8 사용자 powershell.config.json 에 Transcription(값 무관) → 멈춤' { & $script:o8Ok; $global:CfgText['user'] = '{ "PowerShellPolicies": { "Transcription": { "EnableTranscripting": false } } }' } 'PowerShell Transcription 정책이 켜져 있다(레지스트리:  · 설정 파일(값 무관): ' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) }
    $script:repoCurl = Join-Path ([IO.Path]::GetFullPath((Join-Path $BlockDir '..\..\..\..'))) 'tools\curl.exe'
    $script:tempKube = Join-Path $env:TEMP 'evil\kubectl.exe'
    & $script:o8Stop 'O8-71' 'O-8 curl.exe 가 저장소 아래 → 멈춤(판정 — INFO 아님)' { & $script:o8Ok; $global:FakeSrc['curl.exe'] = $script:repoCurl } '실행 파일이 저장소 아래이거나 TEMP · TMP 아래에 있다: curl.exe' { Check 'kubectl · curl 호출 0' ($global:XArgv.Count -eq 0) }
    & $script:o8Stop 'O8-72' 'O-8 kubectl.exe 가 TEMP 아래 → 멈춤' { & $script:o8Ok; $global:FakeSrc['kubectl.exe'] = $script:tempKube } '실행 파일이 저장소 아래이거나 TEMP · TMP 아래에 있다: kubectl.exe ~' { Check 'kubectl · curl 호출 0' ($global:XArgv.Count -eq 0) }
    & $script:o8Stop 'O8-73' 'O-8 curl.exe 가 어디에도 없다(PATH · 함수 · 별칭) → 멈춤' { & $script:o8Ok; $global:FakeGone = @('curl.exe') } 'curl.exe · kubectl.exe 를 찾지 못했다(PATH · 함수 · 별칭 어디에도 — curl 0 · kubectl 1)' { Check 'kubectl · curl 호출 0' ($global:XArgv.Count -eq 0) }
    & $script:o8Stop 'O8-73b' 'O-8 curl.exe 첫 해석이 같은 이름 함수(프로필 정의 — stdin 헤더 = 자격을 받을 자리) → 멈춤 · 외부 호출 0(S-10)' { & $script:o8Ok; $global:FakeType['curl.exe'] = 'Function' } '첫 해석이 실행 파일(Application)이 아니다: curl.exe = Function — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다' { Check 'kubectl · curl 호출 0 · JWT 파일 판정 0' ($global:XArgv.Count -eq 0 -and (Ev-First 'fs:jwt') -lt 0) }
    & $script:o8Stop 'O8-73c' 'O-8 kubectl.exe 첫 해석이 별칭 → 멈춤 · 외부 호출 0(S-10)' { & $script:o8Ok; $global:FakeType['kubectl.exe'] = 'Alias' } '첫 해석이 실행 파일(Application)이 아니다: kubectl.exe = Alias' { Check 'kubectl · curl 호출 0 · JWT 파일 판정 0' ($global:XArgv.Count -eq 0 -and (Ev-First 'fs:jwt') -lt 0) }
    & $script:o8Stop 'O8-74' 'O-8 curl 7.83(%header 없음) → 멈춤' { & $script:o8Ok; $global:CurlVersion = 'curl 7.83.1 (x86_64-pc-win32)' } 'curl 7.84 이상이 필요하다' { Check 'kubectl 0 · Access 0' (@($global:XArgv | Where-Object { $_.StartsWith('kubectl', [StringComparison]::Ordinal) }).Count -eq 0) }
    & $script:o8Stop 'O8-75' 'O-8 whoami 가 관리자(kubernetes-admin) → 멈춤 · JWT 파일 읽기 전' { & $script:o8Ok; $global:Whoami = 'kubernetes-admin' } 'kubectl auth whoami 가 agent-view 가 아니다(exit=0 · 사용자 kubernetes-admin)' { & $script:o8Nothing 'whoami'; Check 'JWT 파일 판정 전(fs:jwt 0)' ((Ev-First 'fs:jwt') -lt 0) }
    & $script:o8Stop 'O8-76' 'O-8 whoami 실패(토큰 만료 — 오류 줄의 홈 경로는 ~) → 멈춤' { & $script:o8Ok; $global:F['whoamiFail'] = $true } 'kubectl auth whoami 가 agent-view 가 아니다(exit=1 · 사용자 (없음) · error: You must be logged in to the server (Unauthorized) — config ~\.kube\agent-view.yaml' { & $script:o8Nothing 'whoami' }
    & $script:o8Stop 'O8-77' 'O-8 agent-view kubeconfig 없음 → 멈춤' { & $script:o8Ok; $global:KcExists = $false } 'agent-view kubeconfig 가 없다' { Check 'kubectl · curl 0(curl --version 밖)' (@($global:XArgv | Where-Object { -not (SEq $_ 'curl.exe -q --version') }).Count -eq 0) }
    foreach ($c in @(@('O8-80', '-ExpectedSha 7자(짧음)', @{ ExpectedSha = $global:M_DeploySha.Substring(0, 7) }), @('O8-81', '-ExpectedSha 대문자 hex', @{ ExpectedSha = $global:M_DeploySha.ToUpperInvariant() }), @('O8-82', '-ExpectedSha 끝 LF', @{ ExpectedSha = $global:M_DeploySha + "`n" }), @('O8-83', '-ExpectedSha 없음', @{}))) {
      & $script:o8Stop $c[0] "O-8 입력 꼴 아님($($c[1])) → 아무것도 보내지 않는다" $script:o8Ok '입력 -ExpectedSha 가 40자 소문자 hex 가 아니다' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } @{} $c[2] }
    & $script:o8Stop 'O8-84' 'O-8 다른 인자(-Foo bar) → 아무것도 보내지 않는다' $script:o8Ok '입력은 -ExpectedSha 하나뿐이다 — 그 밖의 인자 2개' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } @{} @{ ExpectedSha = $global:M_DeploySha } @('-Foo', 'bar')
    & $script:o8Stop 'O8-84b' 'O-8 다른 인자 1개(extra — 문턱은 -gt 0 · S2-04) → 아무것도 보내지 않는다' $script:o8Ok '입력은 -ExpectedSha 하나뿐이다 — 그 밖의 인자 1개' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } @{} @{ ExpectedSha = $global:M_DeploySha } @('extra')
    foreach ($c in @(@('O8-90', 'Utility LogPipelineExecutionDetails 켜짐', { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }, '실효 켜짐: Microsoft.PowerShell.Utility'), @('O8-91', 'Core 스냅인만 켜짐(-SettingsFile)', { $global:CoreLog = $true }, '실효 켜짐: Microsoft.PowerShell.Core'),
        @('O8-92', '시스템 설정 파일 ModuleLogging(값 false)', { $global:CfgText['system'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":false}}}' }, '설정 파일 정책(값 무관): '), @('O8-93', 'HKCU 정책 레지스트리 켜짐', { $global:Policy['HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging'] = @{ EnableModuleLogging = 1 } }, 'PowerShell 모듈 로깅 정책이 켜져 있다(HKCU:'),
        @('O8-94', 'Management 모듈 확인 불가', { $global:ModMissing = @('Microsoft.PowerShell.Management') }, 'Management 0/1'))) {
      $global:O8Mut = $c[2]
      & $script:o8Stop $c[0] "O-8 모듈 로깅: $($c[1]) → 아무것도 부르기 전에 멈춤" { & $script:o8Ok; & $global:O8Mut } $c[3] { Check 'kubectl · curl 0 · JWT 파일 판정 0' ($global:XArgv.Count -eq 0 -and (Ev-First 'fs:jwt') -lt 0) } } }

  # ================================================================ C-8 런타임
  if (Want-Block 'C8') {
    Write-Host '=== C-8 ==='
    $C8F = 'c8-correlate-logs.ps1'
    $AC8 = @{ kubectl = $true }
    $script:sinceOk = [DateTimeOffset]::UtcNow.AddMinutes(-20).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    function Tf-Line { param([string]$rh, [string]$path, [int]$ds, [int]$os, [string]$router = '', [string]$ray = '', [string]$start = '2026-11-20T09:44:01.123456789Z', [string]$ua = $global:M_UA)
      $o = [ordered]@{ ClientAddr = $global:M_CAddr; ClientHost = $global:M_CHost; ClientPort = '53311'; ClientUsername = $global:M_CUser; DownstreamContentSize = 19; DownstreamStatus = $ds; Duration = 123456; OriginContentSize = 0; OriginDuration = 0; OriginStatus = $os; Overhead = 123456
        RequestAddr = $rh; RequestContentSize = 0; RequestCount = 4321; RequestHost = $rh; RequestMethod = 'GET'; RequestPath = $path; RequestPort = '-'; RequestProtocol = 'HTTP/2.0'; RequestScheme = 'https'; RetryAttempts = 0; StartLocal = $start; StartUTC = $start
        TLSCipher = 'TLS_AES_128_GCM_SHA256'; TLSClientSubject = 'CN=origin-pull.cloudflare.net,O=Cloudflare Inc.,L=San Francisco,ST=CA,C=US'; TLSVersion = '1.3'; entryPointName = 'websecure'; level = 'info'; msg = ''
        'request_Cf-Connecting-Ip' = $global:M_IP; 'request_Cf-Ray' = $ray; 'request_User-Agent' = $ua; time = $start }
      if ($router) { $o['RouterName'] = $router; $o['ServiceName'] = 'jt-x-identity-admin-http@kubernetes'; $o['ServiceAddr'] = $global:M_SAddr; $o['ServiceURL'] = 'http://' + $global:M_SAddr }
      ConvertTo-Json -InputObject $o -Compress }
    function Pod-Line { param([string]$event, [string]$rid, [string]$req, [int]$code = 0)
      $o = [ordered]@{}
      if ($code -gt 0) { $o['code'] = $code }
      $o['request'] = $req
      if (SEq $event 'request_started') { $o['user_agent'] = $global:M_UA }
      $o['event'] = $event; $o['request_id'] = $rid; $o['ts'] = '2026-11-20T09:44:01.5Z'; $o['level'] = 'info'; $o['logger'] = 'django_structlog.middlewares.request'
      ConvertTo-Json -InputObject $o -Compress }
    # Traefik · pod 로그 픽스처: $mut['<env>|<경로>'] = @{ ds; os; router }(줄 값 바꿈) · $drop(줄 뺌) · $dup(줄 둘) · $podAdd(<env>|<id> 의 pod 줄 더함) · $podDrop(<env>|<id> 의 pod 줄 뺌) ·
    #   $extraTf(Traefik 줄 더함) — 운영자 IP · UA · ClientHost · ServiceAddr 가 든 줄 · 다른 nonce · 다른 호스트 · UA 속 nonce · 비 JSON · 일반 로그 줄을 늘 섞는다
    function Seed-C8 { param([string]$nonce = $global:M_Nonce, [hashtable]$mut = @{}, [string[]]$drop = @(), [string[]]$dup = @(), [string[]]$podAdd = @(), [string[]]$podDrop = @(), [string[]]$extraTf = @())
      $global:KAllowGet = [System.Collections.Generic.HashSet[string]]::new([string[]]@('kube-system|deployments.apps|traefik'), [StringComparer]::Ordinal)
      $global:KAllowLogs = [System.Collections.Generic.HashSet[string]]::new([string[]]@('kube-system|deploy/traefik|', 'jt-dev|deploy/identity-admin|web', 'jt-prod|deploy/identity-admin|web'), [StringComparer]::Ordinal)
      $global:KObj['kube-system|deployments.apps|traefik'] = [ordered]@{ apiVersion = 'apps/v1'; kind = 'Deployment'; metadata = [ordered]@{ name = 'traefik'; namespace = 'kube-system' }; spec = [ordered]@{ replicas = 1 }; status = [ordered]@{ replicas = 1; readyReplicas = 1; availableReplicas = 1 } }
      $q = "?t076=$nonce"
      $tf = [System.Collections.Generic.List[string]]::new()
      $tf.Add('time="2026-11-20T09:40:00Z" level=error msg="otlp exporter: connection refused" — 비 JSON 줄')
      $tf.Add('{"level":"error","error":"traces export: context deadline exceeded","time":"2026-11-20T09:40:01Z"}')
      $tf.Add((Tf-Line 'identity-m2m-dev.joshuatech.dev' '/healthz?t076=t076-20261119T070957Z-000000' 404 0 -ray 'old-ray'))
      $tf.Add((Tf-Line 'auth.joshuatech.dev' "/admin/$q" 404 0 -ray 'other-host'))
      $tf.Add((Tf-Line 'identity-m2m-dev.joshuatech.dev' '/session/check?sub=x' 400 400 -router 'jt-dev-identity-admin-identity-m2m-dev-joshuatech-dev-session@kubernetes' -ua ('curl/x' + $q)))
      $n = 0
      foreach ($ev in 'dev', 'prod') {
        $rh = "identity-m2m-$ev.joshuatech.dev"
        foreach ($p in '/admin/', '/webhooks/authentik', '/healthz', '/ready', '/health/') {
          $n++
          $key = "$ev|$p"
          if ($drop -contains $key) { continue }
          $ds = 404; $os = 0; $router = ''
          if ($mut.ContainsKey($key)) { $ds = [int]$mut[$key]['ds']; $os = [int]$mut[$key]['os']; $router = [string]$mut[$key]['router'] }
          $line = Tf-Line $rh "$p$q" $ds $os -router $router -ray ("ray$n" + 'f00d-ICN')
          $tf.Add($line)
          if ($dup -contains $key) { $tf.Add($line) } }
        foreach ($p in '/apix', '/sessionsX', '/tenants/me') { $n++; $tf.Add((Tf-Line $rh "$p$q" 403 403 -router "jt-$ev-identity-admin-identity-m2m-$ev-joshuatech-dev-$($p.Trim('/').Split('/')[0].ToLowerInvariant())@kubernetes" -ray ("ray$n" + 'beef-ICN'))) } }
      foreach ($x in $extraTf) { $tf.Add($x) }
      $global:KLogs['kube-system|deploy/traefik|'] = $tf
      foreach ($ev in 'dev', 'prod') {
        $pl = [System.Collections.Generic.List[string]]::new()
        $pl.Add('[2026-11-20 09:40:00 +0000] [1] [INFO] Booting worker with pid: 7 — gunicorn 원시 줄')
        $pl.Add((Pod-Line 'request_finished' 'b5e0c8d2-0000-4000-8000-000000000001' 'GET /healthz' 200))
        $pl.Add((Pod-Line 'request_finished' 'b5e0c8d2-0000-4000-8000-000000000002' 'GET /ready' 200))
        foreach ($x in @(@('health', '/health', 200), @('apix', '/apix', 403), @('sessionsx', '/sessionsX', 403), @('tenantsme', '/tenants/me', 403))) {
          if ($podDrop -contains "$ev|$($x[0])") { continue }
          $pl.Add((Pod-Line 'request_started' "$nonce-$ev-$($x[0])" "GET $($x[1])")); $pl.Add((Pod-Line 'request_finished' "$nonce-$ev-$($x[0])" "GET $($x[1])" $x[2])) }
        foreach ($x in @($podAdd | Where-Object { $_.StartsWith("$ev|", [StringComparison]::Ordinal) })) { $id = $x.Substring($ev.Length + 1); $pl.Add((Pod-Line 'request_finished' "$nonce-$ev-$id" 'GET /x' 403)) }
        $pl.Add((Pod-Line 'request_finished' 't076-20261119T070957Z-000000-dev-admin' 'GET /admin/' 403))
        $global:KLogs["jt-$ev|deploy/identity-admin|web"] = $pl } }
    $script:c8Case = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$final, [int]$exit, [string[]]$want, [string[]]$notwant, [scriptblock]$post, [hashtable]$p = $null, [string[]]$extra = @(), [hashtable]$pre = @{})
      if ($null -eq $p) { $p = @{ Since = $script:sinceOk; Nonce = $global:M_Nonce } }
      Run-TCase -Id $id -Desc $desc -File $C8F -P $p -Extra $extra -Allow $AC8 -Setup $setup -Final $final -Exit $exit -Want $want -NotWant $notwant -Post $post -PreEnv $pre }
    $script:c8Calls = {
      Check 'kubectl = whoami · get traefik · logs traefik · logs web dev · prod(--since-time = 입력 · --request-timeout)' ((@($global:KLogCalls | ForEach-Object { "$($_.key)@$($_.since)" }) -join ';') -ceq ("kube-system|deploy/traefik|@$script:sinceOk;jt-dev|deploy/identity-admin|web@$script:sinceOk;jt-prod|deploy/identity-admin|web@$script:sinceOk") -and $global:KGets.Count -eq 1 -and @($global:KTimeouts | Where-Object { $_ -notlike '--request-timeout=*' }).Count -eq 0) }
    & $script:c8Case 'C8-01' 'C-8 정상: 404 넷 × 2 = Traefik 라우터 없음 · pod 0줄 · 대조 키 줄 있음 → c8=PASS 10/10 · 투영 필드만(운영자 IP · UA · ClientHost · ServiceAddr 0) · 다른 nonce · 다른 호스트 · UA 속 nonce 줄은 무시' { Seed-C8 } 'c8=PASS 10/10' 0 `
      @('PASS c8 dev b GET /admin/', 'PASS c8 prod e GET /ready', 'PASS c8 dev pod', 'PASS c8 prod pod', "INFO c8 dev traefik StartUTC=2026-11-20T09:44:01.123456789Z · GET identity-m2m-dev.joshuatech.dev/apix?t076=$($global:M_Nonce) · DownstreamStatus=403 · OriginStatus=403 · RouterName 있음 · request_Cf-Ray=", 'VD-L9(RouterName 있음', "INFO c8 prod pod request_id=$($global:M_Nonce)-prod-health · GET /health · 200(request_finished) — 상류 X-Request-ID 가 그대로(VD-T076-4)", "RouterName 없음 · request_Cf-Ray=ray1f00d-ICN", 'OK   Traefik 로그(--since-time=') `
      @('FAIL ', 'STOP ', 'old-ray', 'other-host', 'auth.joshuatech.dev', 'session/check', 'jt-x-identity-admin-http', 'TLSClientSubject', 'b5e0c8d2') { & $script:c8Calls; Check 'INFO traefik 줄 = 우리 nonce · m2m 호스트 16줄' (@([regex]::Matches($global:LastText, 'INFO c8 (dev|prod) traefik ')).Count -eq 16) }
    $script:c8Mut = @(
      @('C8-02', 'dev /admin/ 줄에 RouterName(라우터가 받음 · OriginStatus 403)', { Seed-C8 -mut @{ 'dev|/admin/' = @{ ds = 403; os = 403; router = 'jt-dev-identity-admin-x@kubernetes' } } }, 'c8=FAIL 9/10', @('FAIL c8 dev b GET /admin/', 'DownstreamStatus 403 · OriginStatus 403 · RouterName 있음(라우터가 받았다)')),
      @('C8-02b', 'dev /healthz 줄이 404 · OriginStatus 0 인데 RouterName 있음(라우터가 받고 원점 없이 404 — RouterName 판정만 잡는다)', { Seed-C8 -mut @{ 'dev|/healthz' = @{ ds = 404; os = 0; router = 'jt-dev-identity-admin-y@kubernetes' } } }, 'c8=FAIL 9/10', @('FAIL c8 dev d GET /healthz', 'RouterName 있음(라우터가 받았다)')),
      @('C8-03', 'prod /ready 줄 OriginStatus 404(pod 404 · 라우터 이름이 빠진 꼴)', { Seed-C8 -mut @{ 'prod|/ready' = @{ ds = 404; os = 404; router = '' } } }, 'c8=FAIL 9/10', @('FAIL c8 prod e GET /ready', 'OriginStatus 404')),
      @('C8-04', 'dev /healthz 줄이 둘(중복)', { Seed-C8 -dup @('dev|/healthz') }, 'c8=FAIL 9/10', @('FAIL c8 dev d GET /healthz', '줄 2개(정확히 1 이어야 한다)')),
      @('C8-05', 'prod /webhooks/authentik 줄 없음(로그 소실)', { Seed-C8 -drop @('prod|/webhooks/authentik') }, 'c8=FAIL 9/10', @('FAIL c8 prod c GET /webhooks/authentik', '줄 0개')),
      @('C8-06', 'dev pod 로그에 admin 대조 키 줄(pod 에 닿음)', { Seed-C8 -podAdd @('dev|admin') }, 'c8=FAIL 9/10', @('FAIL c8 dev pod', '404 네 경로의 pod 줄 1개(admin — pod 에 닿았다)')),
      @('C8-06b', 'prod pod 로그에 healthz · ready 대조 키 줄 둘', { Seed-C8 -podAdd @('prod|healthz', 'prod|ready') }, 'c8=FAIL 9/10', @('FAIL c8 prod pod', '404 네 경로의 pod 줄 2개(healthz,ready — pod 에 닿았다)')),
      @('C8-07', 'prod pod 로그에 health 대조 키 줄 없음(상류 X-Request-ID 미전달 — 0줄 판정 근거 없음)', { Seed-C8 -podDrop @('prod|health') }, 'c8=FAIL 9/10', @('FAIL c8 prod pod', "대조 키 줄 없음 — /health 요청의 request_id $($global:M_Nonce)-prod-health 가 pod 로그에 없다")),
      @('C8-08', 'dev pod 로그 읽기 실패(RBAC — 오류 줄 홈 경로 ~)', { Seed-C8; $global:F['logsFail']['jt-dev|deploy/identity-admin|web'] = $true }, 'c8=FAIL 9/10', @('FAIL c8 dev pod', 'pod 로그를 읽지 못했다(exit=1 · Error from server (Forbidden): pods is forbidden — config ~\.kube\agent-view.yaml)')),
      @('C8-09', 'Traefik 줄 RequestPath · Cf-Ray 에 제어열(OSC 52 · CSI)', { Seed-C8 -extraTf @((Tf-Line 'identity-m2m-dev.joshuatech.dev' ('/zz' + [char]27 + ']52;c;QUJD' + [char]7 + "?t076=$($global:M_Nonce)") 404 0 -ray ('ray' + [char]27 + '[2J'))) }, 'c8=PASS 10/10', @('/zz?]52;c;QUJD??t076=', 'request_Cf-Ray=ray?[2J')),
      @('C8-09b', 'Traefik 줄 헤더 이름 대소문자(request_CF-RAY)', { Seed-C8 -extraTf @(((Tf-Line 'identity-m2m-prod.joshuatech.dev' "/zz2?t076=$($global:M_Nonce)" 404 0 -ray 'upper-ray-ICN').Replace('"request_Cf-Ray"', '"request_CF-RAY"'))) }, 'c8=PASS 10/10', @('/zz2?t076=', 'request_Cf-Ray=upper-ray-ICN')))
    foreach ($c in $script:c8Mut) { & $script:c8Case $c[0] "C-8 $($c[1])" $c[2] $c[3] $(if ($c[3].StartsWith('c8=PASS', [StringComparison]::Ordinal)) { 0 } else { 1 }) $c[4] @('STOP ', $global:M_IP) $null }
    $script:c8Stop = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$stopText, [scriptblock]$post, [hashtable]$p = $null, [string[]]$extra = @(), [hashtable]$pre = @{})
      $global:Fx = @($stopText, $post)
      & $script:c8Case $id $desc $setup 'c8=FAIL 0/10' 1 @('STOP ') @('PASS c8 ') { & $script:stopLine $global:Fx[0]; if ($null -ne $global:Fx[1]) { & $global:Fx[1] } } $p $extra $pre }
    & $script:c8Stop 'C8-10' 'C-8 Traefik 복제 2(spec) → 멈춤 · logs 0' { Seed-C8; $global:KObj['kube-system|deployments.apps|traefik']['spec']['replicas'] = 2 } 'Traefik Deployment 복제가 1 이 아니다(exit=0 · spec 2 · status 1)' { Check 'logs 0' ($global:KLogCalls.Count -eq 0) }
    & $script:c8Stop 'C8-11' 'C-8 Traefik 롤아웃 중(status 2) → 멈춤' { Seed-C8; $global:KObj['kube-system|deployments.apps|traefik']['status']['replicas'] = 2 } 'Traefik Deployment 복제가 1 이 아니다(exit=0 · spec 1 · status 2)' { Check 'logs 0' ($global:KLogCalls.Count -eq 0) }
    & $script:c8Stop 'C8-12' 'C-8 Traefik 로그 읽기 실패 → 멈춤' { Seed-C8; $global:F['logsFail']['kube-system|deploy/traefik|'] = $true } 'Traefik 로그를 읽지 못했다(exit=1' $null
    & $script:c8Stop 'C8-13' 'C-8 whoami 가 agent-view 아님 → 멈춤 · get · logs 0' { Seed-C8; $global:Whoami = 'system:admin' } 'kubectl auth whoami 가 agent-view 가 아니다(exit=0 · 사용자 system:admin)' { Check 'get · logs 0' ($global:KGets.Count -eq 0 -and $global:KLogCalls.Count -eq 0) }
    foreach ($c in @(@('C8-20', '-Since 꼴(초 없음)', @{ Since = '2026-11-20T09:43Z'; Nonce = $global:M_Nonce }, '입력 -Since 가 UTC ISO 8601'), @('C8-21', '-Since 달 13', @{ Since = '2026-13-20T09:43:12Z'; Nonce = $global:M_Nonce }, '입력 -Since 가 날짜로 읽히지 않거나 범위 밖이다'),
        @('C8-22', '-Since 미래(1시간 뒤)', @{ Since = [DateTimeOffset]::UtcNow.AddHours(1).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture); Nonce = $global:M_Nonce }, '입력 -Since 가 날짜로 읽히지 않거나 범위 밖이다'), @('C8-23', '-Since 이틀 전', @{ Since = [DateTimeOffset]::UtcNow.AddDays(-2).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture); Nonce = $global:M_Nonce }, '입력 -Since 가 날짜로 읽히지 않거나 범위 밖이다'),
        @('C8-24', '-Nonce 꼴(대문자 hex)', @{ Since = $script:sinceOk; Nonce = 't076-20261120T094312Z-A1B2C3' }, '입력 -Nonce 가 O-8 의 nonce 꼴'), @('C8-25', '-Nonce 없음', @{ Since = $script:sinceOk }, '입력 -Nonce 가 O-8 의 nonce 꼴'))) {
      & $script:c8Stop $c[0] "C-8 입력 꼴 아님($($c[1])) → kubectl 0" { Seed-C8 } $c[3] { Check 'kubectl 0' ($global:XArgv.Count -eq 0) } $c[2] }
    & $script:c8Stop 'C8-26' 'C-8 다른 인자 → kubectl 0' { Seed-C8 } '입력은 -Since · -Nonce 둘뿐이다 — 그 밖의 인자 1개' { Check 'kubectl 0' ($global:XArgv.Count -eq 0) } $null @('extra')
    & $script:c8Stop 'C8-27' 'C-8 모듈 로깅 실효(Security) 켜짐 → kubectl 0(운영자 IP 가 든 원문이 4103 에 남는 길)' { Seed-C8; $global:ModLog['Microsoft.PowerShell.Security'] = $true } 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: Microsoft.PowerShell.Security' { Check 'kubectl 0' ($global:XArgv.Count -eq 0) }
    & $script:c8Stop 'C8-28' 'C-8 HTTPS_PROXY 있음 → kubectl 0' { Seed-C8 } '이 창에 kubectl 동작을 바꾸는 환경 변수가 있다: HTTPS_PROXY' { Check 'kubectl 0' ($global:XArgv.Count -eq 0) } $null @() @{ HTTPS_PROXY = 'http://127.0.0.1:8888' }
    & $script:c8Stop 'C8-29' 'C-8 kubectl.exe 첫 해석이 같은 이름 함수(프로필 정의) → 멈춤 · kubectl 0(S-10)' { Seed-C8; $global:FakeType['kubectl.exe'] = 'Function' } '첫 해석이 실행 파일(Application)이 아니다: kubectl.exe = Function — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다' { Check 'kubectl 0' ($global:XArgv.Count -eq 0) }
    & $script:c8Stop 'C8-29b' 'C-8 kubectl.exe 첫 해석이 별칭 → 멈춤 · kubectl 0(S-10)' { Seed-C8; $global:FakeType['kubectl.exe'] = 'Alias' } '첫 해석이 실행 파일(Application)이 아니다: kubectl.exe = Alias' { Check 'kubectl 0' ($global:XArgv.Count -eq 0) }
    & $script:c8Case 'C8-30' 'C-8 현재 문화권 th-TH(불기 달력) + 시간 구분자 「.」 → -Since 판정 · 대조는 그대로 c8=PASS 10/10(C-12 — 입력 판정 = ParseExact InvariantCulture)' { Seed-C8; $ci = [System.Globalization.CultureInfo]::new('th-TH'); $ci.DateTimeFormat.TimeSeparator = '.'; [System.Globalization.CultureInfo]::CurrentCulture = $ci } 'c8=PASS 10/10' 0 @('PASS c8 dev pod', 'PASS c8 prod e GET /ready') @('FAIL ', 'STOP ') { & $script:c8Calls; [System.Globalization.CultureInfo]::CurrentCulture = $OrigCulture } }

  # ================================================================ L-8 런타임
  if (Want-Block 'L8') {
    Write-Host '=== L-8 ==='
    $L8F = 'l8-live-identity-admin.ps1'
    $AL8 = @{ kubectl = $true; curl = $true }
    function SecCtx { [ordered]@{ allowPrivilegeEscalation = $false; capabilities = [ordered]@{ drop = @('ALL') }; readOnlyRootFilesystem = $true } }
    function EnvFromRt { @([ordered]@{ configMapRef = [ordered]@{ name = 'identity-admin-config' } }, [ordered]@{ secretRef = [ordered]@{ name = 'identity-admin-env' } }) }
    function EnvField { param([string]$n, [string]$fp) [ordered]@{ name = $n; valueFrom = [ordered]@{ fieldRef = [ordered]@{ apiVersion = 'v1'; fieldPath = $fp } } } }
    function Mnt { param([string[]]$names) @(foreach ($n in $names) { @{ tmp = [ordered]@{ mountPath = '/tmp'; name = 'tmp' }; 'pg-ca' = [ordered]@{ mountPath = '/etc/pg'; name = 'pg-ca'; readOnly = $true }; 'kafka-ca' = [ordered]@{ mountPath = '/etc/kafka'; name = 'kafka-ca'; readOnly = $true } }[$n] }) }
    function Ctr { param([string]$name, [hashtable]$more)
      $c = [ordered]@{ name = $name; image = 'ghcr.io/joshua92y/identity-admin@sha256:' + (Hex-Lower 'digest'); imagePullPolicy = 'IfNotPresent' }
      foreach ($k in @($more.Keys | Sort-Object)) { $c[$k] = $more[$k] }
      $c['resources'] = [ordered]@{ limits = [ordered]@{ memory = '512Mi' }; requests = [ordered]@{ memory = '256Mi' } }
      if (-not $c.Contains('securityContext')) { $c['securityContext'] = SecCtx }
      $c['terminationMessagePath'] = '/dev/termination-log'; $c['terminationMessagePolicy'] = 'File'
      $c }
    function HProbe { param([string]$path, [int]$period, [int]$fail = 3) [ordered]@{ failureThreshold = $fail; httpGet = [ordered]@{ path = $path; port = 'http'; scheme = 'HTTP' }; periodSeconds = $period; successThreshold = 1; timeoutSeconds = 3 } }
    function PodSec { [ordered]@{ runAsGroup = 10001; runAsNonRoot = $true; runAsUser = 10001; seccompProfile = [ordered]@{ type = 'RuntimeDefault' } } }
    function Vol { param([string[]]$names) @(foreach ($n in $names) { @{ tmp = [ordered]@{ emptyDir = [ordered]@{}; name = 'tmp' }; 'pg-ca' = [ordered]@{ name = 'pg-ca'; secret = [ordered]@{ defaultMode = 420; secretName = 'pg-main-ca' } }; 'kafka-ca' = [ordered]@{ name = 'kafka-ca'; secret = [ordered]@{ defaultMode = 420; secretName = 'jt-kafka-cluster-ca-cert' } } }[$n] }) }
    function Obj-Dep { param([string]$ev)
      $init = Ctr 'startup-check' @{ command = @('python', 'manage.py', 'startup_check'); envFrom = (EnvFromRt); env = @(EnvField 'POD_NAMESPACE' 'metadata.namespace'); volumeMounts = (Mnt @('tmp', 'pg-ca')) }
      $web = Ctr 'web' @{ ports = @([ordered]@{ containerPort = 8000; name = 'http'; protocol = 'TCP' }, [ordered]@{ containerPort = 9100; name = 'web-metrics'; protocol = 'TCP' }); envFrom = (EnvFromRt); env = @((EnvField 'POD_IP' 'status.podIP'), (EnvField 'POD_NAMESPACE' 'metadata.namespace'))
        livenessProbe = (HProbe '/healthz' 20); readinessProbe = (HProbe '/ready' 5); startupProbe = (HProbe '/ready' 5 30); lifecycle = [ordered]@{ preStop = [ordered]@{ sleep = [ordered]@{ seconds = 5 } } }; volumeMounts = (Mnt @('tmp', 'pg-ca', 'kafka-ca')) }
      $relay = Ctr 'relay' @{ command = @('python', 'manage.py', 'outbox_relay'); ports = @([ordered]@{ containerPort = 9464; name = 'metrics'; protocol = 'TCP' }); envFrom = (EnvFromRt); env = @(EnvField 'POD_NAMESPACE' 'metadata.namespace')
        livenessProbe = [ordered]@{ failureThreshold = 3; periodSeconds = 20; successThreshold = 1; tcpSocket = [ordered]@{ port = 'metrics' }; timeoutSeconds = 3 }; volumeMounts = (Mnt @('tmp', 'pg-ca', 'kafka-ca')) }
      [ordered]@{ apiVersion = 'apps/v1'; kind = 'Deployment'; metadata = [ordered]@{ name = 'identity-admin'; namespace = "jt-$ev"; annotations = [ordered]@{ 'reloader.stakater.com/auto' = 'true' } }
        spec = [ordered]@{ replicas = 1; template = [ordered]@{ metadata = [ordered]@{ labels = [ordered]@{ 'app.kubernetes.io/name' = 'identity-admin' } }; spec = [ordered]@{ automountServiceAccountToken = $false; containers = @($web, $relay); dnsPolicy = 'ClusterFirst'; initContainers = @($init); restartPolicy = 'Always'; securityContext = (PodSec); terminationGracePeriodSeconds = 90; volumes = (Vol @('tmp', 'pg-ca', 'kafka-ca')) } } }
        status = [ordered]@{ readyReplicas = 1; replicas = 1 } } }
    function Obj-Cel { param([string]$ev)
      $c = Ctr 'celery' @{ command = @('celery', '--app', 'identity_admin', 'worker'); envFrom = (EnvFromRt); env = @(EnvField 'POD_NAMESPACE' 'metadata.namespace'); volumeMounts = (Mnt @('tmp', 'pg-ca')) }
      [ordered]@{ apiVersion = 'apps/v1'; kind = 'Deployment'; metadata = [ordered]@{ name = 'identity-admin-celery'; namespace = "jt-$ev" }
        spec = [ordered]@{ replicas = 1; template = [ordered]@{ spec = [ordered]@{ automountServiceAccountToken = $false; containers = @($c); securityContext = (PodSec); volumes = (Vol @('tmp', 'pg-ca')) } } } } }
    function Obj-Job { param([string]$ev)
      $c = Ctr 'migrate' @{ command = @('python', '-c', 'import os'); envFrom = @([ordered]@{ secretRef = [ordered]@{ name = 'identity-admin-migrate' } }); env = @([ordered]@{ name = 'JT_SETTINGS_PROFILE'; value = 'migrate' }); volumeMounts = (Mnt @('tmp', 'pg-ca')) }
      [ordered]@{ apiVersion = 'batch/v1'; kind = 'Job'; metadata = [ordered]@{ name = 'identity-admin-migrate'; namespace = "jt-$ev"; annotations = [ordered]@{ 'argocd.argoproj.io/hook' = 'PreSync'; 'argocd.argoproj.io/hook-delete-policy' = 'BeforeHookCreation'; 'argocd.argoproj.io/sync-wave' = '0' } }
        spec = [ordered]@{ backoffLimit = 1; template = [ordered]@{ spec = [ordered]@{ automountServiceAccountToken = $false; containers = @($c); restartPolicy = 'Never'; securityContext = (PodSec); volumes = (Vol @('tmp', 'pg-ca')) } } }; status = [ordered]@{ succeeded = 1 } } }
    function EsD { param([string]$sk, [string]$key, [string]$pp) [ordered]@{ remoteRef = [ordered]@{ conversionStrategy = 'Default'; decodingStrategy = 'None'; key = $key; metadataPolicy = 'None'; property = $pp }; secretKey = $sk } }
    function EsStatus { [ordered]@{ binding = [ordered]@{ name = 'x' }; conditions = @([ordered]@{ lastTransitionTime = '2026-11-19T07:30:00Z'; message = 'secret synced'; reason = 'SecretSynced'; status = 'True'; type = 'Ready' }); refreshTime = '2026-11-20T09:00:00Z' } }
    function Obj-EsEnv { param([string]$ev)
      $r = @{ dev = 'dev_identity_admin'; prod = 'identity_admin' }[$ev]
      $tpl = [ordered]@{}; foreach ($k in 'DATABASE_URL', 'KAFKA_PASSWORD', 'DRAGONFLY_URL', 'AUTHENTIK_ISSUER', 'AUTHENTIK_JWKS_URL', 'SENTRY_DSN', 'SECRET_KEY', 'AUTHENTIK_API_TOKEN', 'AUTHENTIK_WEBHOOK_SECRET', 'OPENFGA_STORE_ID', 'OPENFGA_PRESHARED_KEY') { $tpl[$k] = '{{ .' + $k.ToLowerInvariant() + ' }}' }
      $data = @((EsD 'db_username' "$ev/db/$r/app" 'username'), (EsD 'db_password' "$ev/db/$r/app" 'password'), (EsD 'kafka_password' "$ev/kafka/identity-admin" 'password'), (EsD 'dragonfly_url' "$ev/dragonfly/identity-admin" 'url'), (EsD 'authentik_issuer' "$ev/authentik/identity-admin" 'issuer'), (EsD 'authentik_jwks_url' "$ev/authentik/identity-admin" 'jwks_url'),
        (EsD 'sentry_dsn' "$ev/sentry/identity-admin" 'dsn'), (EsD 'secret_key' "$ev/django/identity-admin" 'secret_key'), (EsD 'authentik_api_token' "$ev/authentik/identity-admin" 'api_token'), (EsD 'authentik_webhook_secret' "$ev/authentik/webhooks/identity-admin" 'secret'), (EsD 'openfga_store_id' "$ev/openfga/store_id" 'store_id'), (EsD 'openfga_preshared_key' "$ev/openfga/preshared" 'key'))
      [ordered]@{ apiVersion = 'external-secrets.io/v1'; kind = 'ExternalSecret'; metadata = [ordered]@{ name = 'identity-admin-env'; namespace = "jt-$ev"; annotations = [ordered]@{ 'argocd.argoproj.io/sync-wave' = '-1' } }
        spec = [ordered]@{ data = $data; refreshInterval = '5m'; secretStoreRef = [ordered]@{ kind = 'ClusterSecretStore'; name = "vault-$ev" }; target = [ordered]@{ creationPolicy = 'Owner'; name = 'identity-admin-env'; template = [ordered]@{ data = $tpl; engineVersion = 'v2'; mergePolicy = 'Replace' } } }; status = (EsStatus) } }
    function Obj-EsMig { param([string]$ev)
      $r = @{ dev = 'dev_identity_admin'; prod = 'identity_admin' }[$ev]
      [ordered]@{ apiVersion = 'external-secrets.io/v1'; kind = 'ExternalSecret'; metadata = [ordered]@{ name = 'identity-admin-migrate'; namespace = "jt-$ev"; annotations = [ordered]@{ 'argocd.argoproj.io/hook' = 'PreSync'; 'argocd.argoproj.io/hook-delete-policy' = 'BeforeHookCreation'; 'argocd.argoproj.io/sync-wave' = '-1' } }
        spec = [ordered]@{ data = @((EsD 'db_username' "$ev/db/$r/owner" 'username'), (EsD 'db_password' "$ev/db/$r/owner" 'password')); secretStoreRef = [ordered]@{ kind = 'ClusterSecretStore'; name = "vault-$ev" }; target = [ordered]@{ name = 'identity-admin-migrate'; template = [ordered]@{ data = [ordered]@{ DATABASE_OWNER_URL = 'postgresql://{{ .db_username }}:{{ .db_password }}@pg-main-rw.data.svc:5432/x' } } } }; status = (EsStatus) } }
    function Obj-App { param([string]$ev) [ordered]@{ apiVersion = 'argoproj.io/v1alpha1'; kind = 'Application'; metadata = [ordered]@{ name = "identity-admin-$ev"; namespace = 'argocd' }; status = [ordered]@{ health = [ordered]@{ status = 'Healthy' }; operationState = [ordered]@{ phase = 'Succeeded' }; sync = [ordered]@{ revision = $global:M_Rev; status = 'Synced' } } } }
    function Seed-L8 {
      foreach ($ev in 'dev', 'prod') {
        $ns = "jt-$ev"
        $global:KObj["argocd|applications.argoproj.io|identity-admin-$ev"] = Obj-App $ev
        $global:KObj["$ns|externalsecrets.external-secrets.io|identity-admin-env"] = Obj-EsEnv $ev
        $global:KObj["$ns|externalsecrets.external-secrets.io|identity-admin-migrate"] = Obj-EsMig $ev
        $global:KObj["$ns|deployments.apps|identity-admin"] = Obj-Dep $ev
        $global:KObj["$ns|deployments.apps|identity-admin-celery"] = Obj-Cel $ev
        $global:KObj["$ns|jobs.batch|identity-admin-migrate"] = Obj-Job $ev
        $global:KLogs["$ns|deploy/identity-admin|startup-check"] = @('{"event": "db_connect_retry", "attempt": 1}', 'startup_check: OK') }
      foreach ($k in @($global:KObj.Keys)) { [void]$global:KAllowGet.Add($k) }
      foreach ($k in @($global:KLogs.Keys)) { [void]$global:KAllowLogs.Add($k) } }
    function KO { param([string]$key) $global:KObj[$key] }
    $script:l8Case = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$final, [int]$exit, [string[]]$want, [string[]]$notwant, [scriptblock]$post, [hashtable]$p = $null, [string[]]$extra = @(), [hashtable]$pre = @{})
      if ($null -eq $p) { $p = @{ ExpectedRevision = $global:M_Rev } }
      Run-TCase -Id $id -Desc $desc -File $L8F -P $p -Extra $extra -Allow $AL8 -Setup $setup -Final $final -Exit $exit -Want $want -NotWant $notwant -Post $post -PreEnv $pre }
    $script:l8Calls = {
      Check 'curl = --version · m2m dev · prod /health · admin(무자격 · 헤더 0 · stdin 0)' ((@($global:CurlCalls | ForEach-Object { "$($_.host)$($_.path)" }) -join ';') -ceq 'identity-m2m-dev.joshuatech.dev/health;identity-m2m-prod.joshuatech.dev/health;admin.joshuatech.dev/identity-admin/admin/' -and @($global:CurlCalls | Where-Object { $_.hdr.Count -gt 0 -or $_.argvHeaders.Count -gt 0 }).Count -eq 0)
      Check 'kubectl get = Application · ES 둘 · Deployment 둘 · Job × dev · prod(12) · logs = startup-check × 2 · Secret 0' ($global:KGets.Count -eq 12 -and $global:KLogCalls.Count -eq 2 -and @($global:KGets | Where-Object { $_ -match '(?i)secret\|' }).Count -eq 0) }
    & $script:l8Case 'L8-01' 'L-8 정상: dev · prod 사다리 ⓪–⑤ 24 PASS · admin 302 INFO = scheme://host/path 만(meta 토큰 · 쿼리 0)' { Seed-L8 } 'l8=PASS 24/24' 0 `
      @('PASS l8 dev ⓪ Application identity-admin-dev', 'PASS l8 prod ② ES identity-admin-env 스펙', 'PASS l8 prod ③ -migrate 분리', 'PASS l8 dev ④ init startup-check', 'PASS l8 prod ⑤ 무자격 GET https://identity-m2m-prod.joshuatech.dev/health → 401', 'INFO l8 admin 무자격 GET https://admin.joshuatech.dev/identity-admin/admin/ → 302 · Location https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/admin.joshuatech.dev — Access 로그인 꼴', 'INFO l8 dev ④ startup-check: startup_check: OK', 'INFO l8 prod ⑤ 무자격 GET /health 미디어 타입 = text/html') `
      @('FAIL ', 'STOP ', 'kid=', 'redirect_url', 'db_connect_retry') { & $script:l8Calls }
    $script:l8Mut = @(
      @('L8-02', 'dev Application revision 이 입력과 다름', { Seed-L8; (KO 'argocd|applications.argoproj.io|identity-admin-dev')['status']['sync']['revision'] = (Hex-Lower 'older').Substring(0, 40) }, 23, @('FAIL l8 dev ⓪', 'revision ')),
      @('L8-03', 'prod Application OutOfSync · Degraded · phase Failed', { Seed-L8; $s = (KO 'argocd|applications.argoproj.io|identity-admin-prod')['status']; $s['sync']['status'] = 'OutOfSync'; $s['health']['status'] = 'Degraded'; $s['operationState']['phase'] = 'Failed' }, 23, @('FAIL l8 prod ⓪', 'sync OutOfSync · health Degraded', 'operationState Failed')),
      @('L8-04', 'dev ES -env Ready=False(SecretSyncedError)', { Seed-L8; $c = (KO 'jt-dev|externalsecrets.external-secrets.io|identity-admin-env')['status']['conditions'][0]; $c['status'] = 'False'; $c['reason'] = 'SecretSyncedError' }, 23, @('FAIL l8 dev ① ES identity-admin-env')),
      @('L8-05', 'prod ES -migrate 없음(NotFound)', { Seed-L8; $global:KObj['jt-prod|externalsecrets.external-secrets.io|identity-admin-migrate'] = $null }, 22, @('FAIL l8 prod ① ES identity-admin-migrate', 'kubectl get externalsecrets.external-secrets.io identity-admin-migrate 실패(exit=1 · Error from server (NotFound)')),
      @('L8-06', 'dev ES -env 템플릿 키 12(DATABASE_OWNER_URL 더함)', { Seed-L8; (KO 'jt-dev|externalsecrets.external-secrets.io|identity-admin-env')['spec']['target']['template']['data']['DATABASE_OWNER_URL'] = 'x' }, 23, @('FAIL l8 dev ② ES identity-admin-env', '템플릿 키 12개')),
      @('L8-07', 'dev ES -env 원격 키에 owner(런타임 owner 자격)', { Seed-L8; (KO 'jt-dev|externalsecrets.external-secrets.io|identity-admin-env')['spec']['data'][0]['remoteRef']['key'] = 'dev/db/dev_identity_admin/owner' }, 23, @('원격 키에 /owner 가 있다')),
      @('L8-08', 'prod ES -env 에 dev/ 잔재 · store vault-dev(패치 누락)', { Seed-L8; $o = KO 'jt-prod|externalsecrets.external-secrets.io|identity-admin-env'; $o['spec']['data'][11]['remoteRef']['key'] = 'dev/openfga/preshared'; $o['spec']['secretStoreRef']['name'] = 'vault-dev' }, 23, @('원격 키가 prod/ 밖이다', 'store ClusterSecretStore vault-dev')),
      @('L8-09', 'dev ES -migrate wave 0 · hook 없음', { Seed-L8; $a = (KO 'jt-dev|externalsecrets.external-secrets.io|identity-admin-migrate')['metadata']['annotations']; $a['argocd.argoproj.io/sync-wave'] = '0'; $a.Remove('argocd.argoproj.io/hook') }, 23, @('FAIL l8 dev ② ES identity-admin-migrate', 'hook ≠ PreSync', 'sync-wave 0(기대 -1')),
      @('L8-10', 'dev Deployment web 권한 상승 true · runAsUser 0', { Seed-L8; $s = (KO 'jt-dev|deployments.apps|identity-admin')['spec']['template']['spec']; $s['containers'][0]['securityContext']['allowPrivilegeEscalation'] = $true; $s['securityContext']['runAsUser'] = 0 }, 23, @('FAIL l8 dev ③ Deployment identity-admin —', 'web allowPrivilegeEscalation ≠ false', 'runAsUser · runAsGroup ≠ 10001')),
      @('L8-11', 'prod celery readOnlyRootFilesystem false · /tmp 없음', { Seed-L8; $c = (KO 'jt-prod|deployments.apps|identity-admin-celery')['spec']['template']['spec']['containers'][0]; $c['securityContext']['readOnlyRootFilesystem'] = $false; $c['volumeMounts'] = @($c['volumeMounts'][1]) }, 23, @('celery readOnlyRootFilesystem ≠ true', 'celery /tmp emptyDir 마운트 없음')),
      @('L8-12', 'dev init startup-check drop 비어 있음 · automountServiceAccountToken 없음', { Seed-L8; $s = (KO 'jt-dev|deployments.apps|identity-admin')['spec']['template']['spec']; $s['initContainers'][0]['securityContext']['capabilities']['drop'] = @(); $s.Remove('automountServiceAccountToken') }, 23, @('startup-check capabilities.drop ≠ [ALL]', 'automountServiceAccountToken ≠ false')),
      @('L8-13', 'dev web liveness 가 /health(의존 셋 — 재시작 연쇄)', { Seed-L8; (KO 'jt-dev|deployments.apps|identity-admin')['spec']['template']['spec']['containers'][0]['livenessProbe']['httpGet']['path'] = '/health' }, 23, @('FAIL l8 dev ③ 프로브', 'web liveness ≠ GET /healthz', 'web livenessProbe 가 /health 를 쓴다')),
      @('L8-14', 'prod relay 에 readiness 프로브 · celery 에 liveness', { Seed-L8; (KO 'jt-prod|deployments.apps|identity-admin')['spec']['template']['spec']['containers'][1]['readinessProbe'] = (HProbe '/ready' 5); (KO 'jt-prod|deployments.apps|identity-admin-celery')['spec']['template']['spec']['containers'][0]['livenessProbe'] = (HProbe '/healthz' 20) }, 23, @('relay 에 readiness · startup 프로브가 있다', 'celery 프로브 0 아님')),
      @('L8-15', 'dev startup 프로브 failureThreshold 3(30 × 5 아님)', { Seed-L8; (KO 'jt-dev|deployments.apps|identity-admin')['spec']['template']['spec']['containers'][0]['startupProbe']['failureThreshold'] = 3 }, 23, @('web startup ≠ GET /ready(http) 30 × 5 s · 3 s')),
      @('L8-16', 'dev Deployment web envFrom 에 identity-admin-migrate(owner 자격이 런타임에)', { Seed-L8; $c = (KO 'jt-dev|deployments.apps|identity-admin')['spec']['template']['spec']['containers'][0]; $c['envFrom'] = @($c['envFrom']) + @([ordered]@{ secretRef = [ordered]@{ name = 'identity-admin-migrate' } }) }, 23, @('FAIL l8 dev ③ -migrate 분리', 'identity-admin-migrate 참조 있음')),
      @('L8-17', 'prod celery env secretKeyRef identity-admin-migrate', { Seed-L8; $c = (KO 'jt-prod|deployments.apps|identity-admin-celery')['spec']['template']['spec']['containers'][0]; $c['env'] = @($c['env']) + @([ordered]@{ name = 'DATABASE_OWNER_URL'; valueFrom = [ordered]@{ secretKeyRef = [ordered]@{ key = 'DATABASE_OWNER_URL'; name = 'identity-admin-migrate' } } }) }, 23, @('Deployment identity-admin-celery 참조 ≠ gitops', 'identity-admin-migrate 참조 있음')),
      @('L8-18', 'dev Job 이 identity-admin-env · ConfigMap 참조', { Seed-L8; $c = (KO 'jt-dev|jobs.batch|identity-admin-migrate')['spec']['template']['spec']['containers'][0]; $c['envFrom'] = @($c['envFrom']) + @(EnvFromRt) }, 23, @('Job 참조 ≠ gitops', 'identity-admin-env 참조 있음')),
      @('L8-19', 'prod Job 없음(TTL 7일 지남) → ③ Job · 프로브 · 분리 FAIL', { Seed-L8; $global:KObj['jt-prod|jobs.batch|identity-admin-migrate'] = $null }, 21, @('FAIL l8 prod ③ Job identity-admin-migrate', 'ttlSecondsAfterFinished 7일이 지났거나 sync 전', '워크로드 셋 중 읽지 못한 것이 있다')),
      @('L8-20', 'dev startup-check 로그에 startup_check: OK 없음', { Seed-L8; $global:KLogs['jt-dev|deploy/identity-admin|startup-check'] = @('startup_check: FAIL check_rls session_user') }, 23, @('FAIL l8 dev ④', '그 줄 0 개')),
      @('L8-21', 'prod m2m 무자격이 200(Access 앞단 열림)', { Seed-L8; $global:HttpFn = { param($req) if ((SEq $req.host 'identity-m2m-prod.joshuatech.dev')) { Resp '200' 'application/json' '{"status":"ok"}' } else { Http-Default $req } } }, 23, @('FAIL l8 prod ⑤', '응답 200')),
      @('L8-22', 'dev m2m 무자격 401 에 Location(리다이렉트)', { Seed-L8; $global:HttpFn = { param($req) $r = Http-Default $req; if ((SEq $req.host 'identity-m2m-dev.joshuatech.dev')) { $r.loc = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/x' }; $r } }, 23, @('FAIL l8 dev ⑤', 'Location 있음(리다이렉트)')),
      @('L8-23', 'dev Deployment 읽기 거부(RBAC) → ③ 다섯 FAIL', { Seed-L8; $global:F['getFail']['jt-dev|deployments.apps|identity-admin'] = $true }, 21, @('kubectl get deployments.apps identity-admin 실패(exit=1 · Error from server (Forbidden)')))
    foreach ($c in $script:l8Mut) { & $script:l8Case $c[0] "L-8 $($c[1])" $c[2] "l8=FAIL $($c[3])/24" 1 $c[4] @('STOP ') $null }
    & $script:l8Case 'L8-30' 'L-8 admin Location 이 Access 밖 호스트 → INFO(불일치 표시 · 합격선 아님) · l8=PASS 24/24' { Seed-L8; $global:HttpFn = { param($req) $r = Http-Default $req; if (SEq $req.host 'admin.joshuatech.dev') { $r.loc = 'https://evil.example.com/login?meta=' + $global:M_Meta }; $r } } 'l8=PASS 24/24' 0 @('Location https://evil.example.com/login — Access 로그인 꼴 아님') @('meta=') $null
    & $script:l8Case 'L8-31' 'L-8 admin Location 에 제어열 → INFO 는 ? 로 · 쿼리 0' { Seed-L8; $global:HttpFn = { param($req) $r = Http-Default $req; if (SEq $req.host 'admin.joshuatech.dev') { $r.loc = 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/a' + [char]27 + '[2J?meta=' + $global:M_Meta }; $r } } 'l8=PASS 24/24' 0 @('Location https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/a%1B[2J — Access 로그인 꼴') @('meta=') $null
    $script:l8Stop = { param([string]$id, [string]$desc, [scriptblock]$setup, [string]$stopText, [scriptblock]$post, [hashtable]$p = $null, [string[]]$extra = @(), [hashtable]$pre = @{})
      $global:Fx = @($stopText, $post)
      & $script:l8Case $id $desc $setup 'l8=FAIL 0/24' 1 @('STOP ') @('PASS l8 ') { & $script:stopLine $global:Fx[0]; if ($null -ne $global:Fx[1]) { & $global:Fx[1] } } $p $extra $pre }
    foreach ($c in @(@('L8-40', '-ExpectedRevision 짧음', @{ ExpectedRevision = $global:M_Rev.Substring(0, 12) }), @('L8-41', '-ExpectedRevision 없음', @{}), @('L8-42', '-ExpectedRevision 대문자', @{ ExpectedRevision = $global:M_Rev.ToUpperInvariant() }))) {
      & $script:l8Stop $c[0] "L-8 입력 꼴 아님($($c[1])) → kubectl · curl 0" { Seed-L8 } '입력 -ExpectedRevision 이 40자 소문자 hex' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } $c[2] }
    & $script:l8Stop 'L8-43' 'L-8 다른 인자 → 0' { Seed-L8 } '입력은 -ExpectedRevision 하나뿐이다 — 그 밖의 인자 1개' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } $null @('x')
    & $script:l8Stop 'L8-44' 'L-8 whoami 가 관리자 → get · logs · Access 0' { Seed-L8; $global:Whoami = 'kubernetes-admin' } 'kubectl auth whoami 가 agent-view 가 아니다(exit=0 · 사용자 kubernetes-admin)' { Check 'get · logs · m2m 0' ($global:KGets.Count -eq 0 -and $global:KLogCalls.Count -eq 0 -and @($global:CurlCalls | Where-Object { $_.host.Contains('joshuatech') }).Count -eq 0) }
    & $script:l8Stop 'L8-45' 'L-8 모듈 로깅(사용자 설정 ModuleLogging) → 0' { Seed-L8; $global:CfgText['user'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":true}}}' } '설정 파일 정책(값 무관): ' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) }
    & $script:l8Stop 'L8-46' 'L-8 ALL_PROXY 있음 → 0' { Seed-L8 } '이 창에 curl · kubectl 동작을 바꾸는 환경 변수가 있다: ALL_PROXY' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } $null @() @{ ALL_PROXY = 'socks5://127.0.0.1:1080' }
    & $script:l8Stop 'L8-47' 'L-8 curl 7.80 → 0' { Seed-L8; $global:CurlVersion = 'curl 7.80.0' } 'curl 7.84 이상이 필요하다' { Check 'kubectl 0' (@($global:XArgv | Where-Object { $_.StartsWith('kubectl', [StringComparison]::Ordinal) }).Count -eq 0) }
    & $script:l8Stop 'L8-48' 'L-8 curl.exe 첫 해석이 별칭 → 멈춤 · kubectl · curl 0(S-10)' { Seed-L8; $global:FakeType['curl.exe'] = 'Alias' } '첫 해석이 실행 파일(Application)이 아니다: curl.exe = Alias — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) }
    & $script:l8Stop 'L8-48b' 'L-8 kubectl.exe 첫 해석이 같은 이름 함수 → 멈춤 · kubectl · curl 0(S-10)' { Seed-L8; $global:FakeType['kubectl.exe'] = 'Function' } '첫 해석이 실행 파일(Application)이 아니다: kubectl.exe = Function' { Check 'kubectl · curl 0' ($global:XArgv.Count -eq 0) } }
}
finally {
  [System.Globalization.CultureInfo]::CurrentCulture = $OrigCulture
  $env:PATH = $OrigPath
  if ($null -eq $OrigKubeconfig) { Remove-Item -LiteralPath Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $OrigKubeconfig }
  $env:LOCALAPPDATA = $OrigLocalAppData
  foreach ($k in @($NetEnvSaved.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value $NetEnvSaved[$k] }
  Microsoft.PowerShell.Management\Remove-Item -LiteralPath $TrapDir -Recurse -Force -ErrorAction SilentlyContinue }

# ---------------------------------------------------------------- 결과
Write-Host "`n=== 결과 ==="
foreach ($r in $Results) { Write-Host ("{0} {1,-6} ({2,3}/{3,3}) {4}{5}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.id, ($r.total - $r.failed), $r.total, $r.desc, $(if ($r.pass) { '' } else { "`n        ↳ " + $r.detail })) }
$cases = $Results.Count
$casePass = @($Results | Where-Object { $_.pass }).Count
$checks = 0; $checkFail = 0; foreach ($r in $Results) { $checks += $r.total; $checkFail += $r.failed }
$gateFail = @($global:BGate.Values | Where-Object { $_ }).Count
Write-Host ("시나리오 PASS {0} / {1}" -f $casePass, $cases)
Write-Host ("PASS {0} / {1}   (단언 수 — 정적 관문 ST-O8 · ST-C8 · ST-L8 포함 · 실물 kubectl · vault · tofu · HTTP 0 가드)" -f ($checks - $checkFail), $checks)
Write-Host ("실행 시간 {0:N1}초" -f $Clock.Elapsed.TotalSeconds)
if ($gateFail -gt 0 -or $casePass -ne $cases -or $checkFail -gt 0 -or $cases -eq 0) { exit 1 }
exit 0
