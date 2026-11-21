& {
  # ===== T075 O-2 블록 — identity-admin kv 판정(쓰기 0) · dev · prod 10경로씩 = 20경로 · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: T057 시드 블록(t057-blocks/op1-seed-dragonfly.ps1)의 창 전제 · Vault 도달 · root 토큰 · 상태 기계 · 정리(finally)를 그대로 쓰고, 쓰기 단계를 뺐다(판정 전용 — 설계 D10 「판정과 쓰기를 다른 블록으로」).
  # 목적: W-2(kv 쓰기) 앞의 관찰(L3). 경로마다 존재 · 버전 · 키 집합 · 키별 sentinel 여부 · 값 규칙 충족 여부만 출력한다(값 · 해시 0). 끝에 env 마다 「W-2 전제」 집계를 낸다.
  # 경로(env 마다 10 — <role> = dev_identity_admin(dev) · identity_admin(prod)):
  #   kv/<env>/db/<role>/app · kv/<env>/db/<role>/owner        username · password · url    T054 시드 — 키 집합만 본다(값은 비지 않은 문자열 · PLACEHOLDER- 없음)
  #   kv/<env>/kafka/identity-admin                            password                     T056 시드 — 같음
  #   kv/<env>/dragonfly/identity-admin                        password · url               T057 시드 — 같음
  #   kv/<env>/authentik/identity-admin                        client_id · client_secret · jwks_url · issuer · api_token   T044 sentinel → W-2 가 jwks_url · issuer 만 계약 값으로(kv patch)
  #   kv/<env>/authentik/webhooks/identity-admin               secret                       T044 sentinel → W-2 가 CSPRNG 43자로 덮어쓴다
  #   kv/<env>/django/identity-admin                           secret_key                   없음 → W-2 가 만든다(64자)
  #   kv/<env>/sentry/identity-admin                           dsn                          없음 → W-2 가 {"dsn": ""} 로 만든다
  #   kv/<env>/openfga/store_id · kv/<env>/openfga/preshared   store_id · key               T044 sentinel 그대로(면제 — T082 가 바꾼다)
  # 계약 값(비밀 아님 — contracts/identity-admin-api.md 「JWKS 도 svc DNS」 · data-model §8): jwks_url = http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/ ·
  #   issuer = https://auth.joshuatech.dev/application/o/identity-admin/ · sentinel = PLACEHOLDER-T044-SENTINEL(credential 아님 — vault-unseal.md §US6)
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T075 · docs/runbooks/vault-unseal.md §0): ① 창 D 창 시작 체크리스트(클립보드 기록 0 · 모듈 로깅 정책 0 — 블록도 첫 검사에서 본다)
  #   ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200 ③ 이 창에 VAULT_* 없음(VAULT_ADDR=http://127.0.0.1:18200 만 허용) · ~/.vault-token 없음 ④ PM 의 root 토큰 항목
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>'(권장 — 새 프로세스) 또는 pwsh -NoProfile 로 새로 연 창에 전문 붙여넣기(& { … } 한 문)
  # 정지점: root 토큰(보안 입력 · 빈 입력 = 중단 · 붙인 직후 클립보드를 비운다) 하나뿐이다 — 이 블록은 아무것도 쓰지 않는다(vault kv put · patch · delete 0)
  # 원칙: 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드에 0 · 출력은 Write-Host/Write-Warning 뿐 · fail-closed(판정 불가는 판정 불가로) · finally 가 env(VAULT_TOKEN 부터) · 변수 · 클립보드 ·
  #   $Error(이 실행분)를 정리한다 · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저다(켜져 있으면 kv 응답 원문이 이벤트 4103 에 남는다 — 설계 D10 CD-8)
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t075-blocks\harness.ps1 → PASS n / n
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $vaultAddr = 'http://127.0.0.1:18200'
  $clipWarn = '클립보드를 비우지 못했다 — root 토큰이 클립보드에 남아 있을 수 있다. PM 의 클립보드 지우기 또는 아무 텍스트 복사로 직접 비운다'
  $sentinel = 'PLACEHOLDER-T044-SENTINEL'
  $jwksWant = 'http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/'
  $issWant = 'https://auth.joshuatech.dev/application/o/identity-admin/'
  $paths = @()
  foreach ($ev in @('dev', 'prod')) {
    $role = 'identity_admin'
    if ($ev -ceq 'dev') { $role = 'dev_identity_admin' }
    $paths += [pscustomobject]@{ path = "kv/$ev/db/$role/app"; env = $ev; kind = 'db'; keys = @('username', 'password', 'url') }
    $paths += [pscustomobject]@{ path = "kv/$ev/db/$role/owner"; env = $ev; kind = 'db'; keys = @('username', 'password', 'url') }
    $paths += [pscustomobject]@{ path = "kv/$ev/kafka/identity-admin"; env = $ev; kind = 'kafka'; keys = @('password') }
    $paths += [pscustomobject]@{ path = "kv/$ev/dragonfly/identity-admin"; env = $ev; kind = 'dragonfly'; keys = @('password', 'url') }
    $paths += [pscustomobject]@{ path = "kv/$ev/authentik/identity-admin"; env = $ev; kind = 'authentik'; keys = @('client_id', 'client_secret', 'jwks_url', 'issuer', 'api_token') }
    $paths += [pscustomobject]@{ path = "kv/$ev/authentik/webhooks/identity-admin"; env = $ev; kind = 'webhook'; keys = @('secret') }
    $paths += [pscustomobject]@{ path = "kv/$ev/django/identity-admin"; env = $ev; kind = 'django'; keys = @('secret_key') }
    $paths += [pscustomobject]@{ path = "kv/$ev/sentry/identity-admin"; env = $ev; kind = 'sentry'; keys = @('dsn') }
    $paths += [pscustomobject]@{ path = "kv/$ev/openfga/store_id"; env = $ev; kind = 'store'; keys = @('store_id') }
    $paths += [pscustomobject]@{ path = "kv/$ev/openfga/preshared"; env = $ev; kind = 'preshared'; keys = @('key') } }
  # 경로별 요약은 시작할 때 전부 채워 둔다 — 중간에 throw 해도 "도달하지 못함"이 표에 남는다
  $sumLog = [ordered]@{}
  foreach ($e in $paths) { $sumLog[$e.path] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  $okCount = @{ dev = 0; prod = 0 }
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    # ---------- 헬퍼(값을 출력하지 않는다) ----------
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt(아무것도 읽지 않았다)" }
      try { ($ss | ConvertFrom-SecureString -AsPlainText) } finally { $ss.Dispose() } }
    $firstErr = { param($lines)
      $c = @(@($lines) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $star = @($c | Where-Object { $_.StartsWith('* ', [StringComparison]::Ordinal) })
      $pick = '(오류 출력 없음)'
      if ($star.Count -gt 0) { $pick = $star[0] } elseif ($c.Count -gt 0) { $pick = $c[0] }
      if ($pick.Length -gt 160) { $pick = $pick.Substring(0, 160) + '…' }
      $pick -replace '\p{Cc}', '?' }
    $parseJson = { param($lines)
      $t = (@($lines) | ForEach-Object { [string]$_ }) -join "`n"
      if ([string]::IsNullOrWhiteSpace($t)) { return $null }
      try { $t | ConvertFrom-Json -DateKind String } catch { $null } }
    $prop = { param($o, $n)
      if ($null -eq $o) { return $null }
      $p = $o.PSObject.Properties[$n]
      if ($null -eq $p) { return $null }
      $p.Value }
    # 경로 상태(T057 $state 그대로 — 값을 읽지 않는다): absent | live | dead | error
    $state = { param($path)
      $o = @(vault kv metadata get "-format=json" $path 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $errs = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      $outs = @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
      $noValue = @($errs | Where-Object { ([string]$_).StartsWith('No value found at ', [StringComparison]::Ordinal) }).Count -gt 0
      if ($rc -ne 0) {
        if ($outs.Count -eq 0 -and $noValue) { return [pscustomobject]@{ kind = 'absent'; why = ''; cv = 0 } }
        return [pscustomobject]@{ kind = 'error'; why = "metadata 조회 exit=$rc · $(& $firstErr $errs)"; cv = -1 } }
      $d = & $prop (& $parseJson $outs) 'data'
      if ($null -eq $d) { return [pscustomobject]@{ kind = 'error'; why = 'metadata 응답을 해석하지 못했다(JSON · data 없음)'; cv = -1 } }
      $cvs = [string](& $prop $d 'current_version')
      if ($cvs -cnotmatch '\A[0-9]{1,9}\z') { return [pscustomobject]@{ kind = 'error'; why = 'current_version 이 정수가 아니다'; cv = -1 } }
      $cv = [int]$cvs
      if ($cv -eq 0) { return [pscustomobject]@{ kind = 'dead'; why = 'current_version=0(메타데이터만 있고 버전이 없다)'; cv = 0 } }
      $ver = & $prop (& $prop $d 'versions') ([string]$cv)
      if ($null -eq $ver) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 항목이 versions 에 없다"; cv = $cv } }
      $des = & $prop $ver 'destroyed'
      if ($des -isnot [bool]) { return [pscustomobject]@{ kind = 'error'; why = "versions.$cv.destroyed 형식이 기대와 다르다"; cv = $cv } }
      if ($des) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 이 파기(destroy)됐다"; cv = $cv } }
      if (-not [string]::IsNullOrEmpty([string](& $prop $ver 'deletion_time'))) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 에 deletion_time 이 있다(soft-delete 또는 삭제 예약)"; cv = $cv } }
      [pscustomobject]@{ kind = 'live'; why = ''; cv = $cv } }
    # 현재 버전 데이터(값이 든 객체 — 출력하지 않는다 · 쓴 뒤 버린다). 읽기 실패 · 해석 실패 · data.data 가 객체 아님 = $null + 사유
    $readData = { param($path)
      $o = @(vault kv get "-format=json" $path 2>$null)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or $o.Count -eq 0) { return [pscustomobject]@{ dd = $null; why = "kv get exit=$rc(값을 읽지 못했다)" } }
      $jr = & $parseJson $o
      $o = $null
      if ($null -eq $jr) { return [pscustomobject]@{ dd = $null; why = 'kv get 응답을 해석하지 못했다(원문 미출력)' } }
      $dd = & $prop (& $prop $jr 'data') 'data'
      $jr = $null
      if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) { return [pscustomobject]@{ dd = $null; why = '현재 버전에 데이터가 없다(data.data 가 없거나 객체가 아니다)' } }
      [pscustomobject]@{ dd = $dd; why = '' } }
    # 값 분류(분류 이름만 돌려준다 — 값 · 길이 외의 내용 0)
    $classify = { param($kind, $k, $v)
      if ($v -isnot [string]) { return '문자열 아님' }
      if (& $eq $v $sentinel) { return 'sentinel' }
      if (& $eq $kind 'authentik') {
        if ((& $eq $k 'jwks_url') -or (& $eq $k 'issuer')) {
          $want = $jwksWant
          if (& $eq $k 'issuer') { $want = $issWant }
          if (& $eq $v $want) { return '계약 값' }
          return '계약 값도 sentinel 도 아님' }
        if ($v.Contains('PLACEHOLDER-')) { return '다른 자리값(PLACEHOLDER-)' }
        if ($v.Length -eq 0) { return '빈 값' }
        return '실값(sentinel 아님)' }
      if (& $eq $kind 'webhook') {
        # 서로 다른 글자 16 이상(T075 보정 2026-11-17 · 리뷰 KB-9 — 32바이트 CSPRNG 의 43자는 서로 다른 글자 평균 약 31 · 16 미만일 확률 2.2×10^-13 이하 · 근거 = t075-blocks/README.md)
        if ($v -cmatch '\A[A-Za-z0-9_-]{43}\z') {
          if ([System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count -lt 16) { return '규칙 불충족(서로 다른 글자 16 미만 — CSPRNG 값이 아니다)' }
          return '규칙 충족(43자 base64url)' }
        if ($v.Contains("`n") -or $v.Contains("`r")) { return '규칙 불충족(줄바꿈)' }
        if ($v.Length -ne 43) { return "규칙 불충족(길이 $($v.Length) — 43 기대)" }
        return '규칙 불충족(base64url 밖의 문자)' }
      if (& $eq $kind 'django') {
        $nd = [System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count
        if ($v.Length -lt 50) { return "규칙 불충족(길이 $($v.Length) — 50 이상 기대)" }
        if ($nd -lt 5) { return '규칙 불충족(서로 다른 글자 5 미만)' }
        if ($v.StartsWith('django-insecure-', [StringComparison]::Ordinal)) { return '규칙 불충족(django-insecure- 접두)' }
        if ($v -cmatch '\A[A-Za-z0-9_-]{64}\z') { return '규칙 충족(W009 · 64자 base64url — W-2 꼴)' }
        return '규칙 충족(W009 — W-2 꼴 아님)' }
      if (& $eq $kind 'sentry') {
        if ($v.Length -eq 0) { return '빈 값(Sentry 끔)' }
        return '비지 않은 값(Sentry 켜짐 — US6 기대와 다르다)' }
      if ((& $eq $kind 'store') -or (& $eq $kind 'preshared')) { return '실값(sentinel 아님)' }
      if ($v.Length -eq 0) { return '빈 값' }
      if ($v.Contains('PLACEHOLDER-')) { return '자리값(PLACEHOLDER-)' }
      '값 있음' }
    # W-2 전제(경로 종류별 기대 상태 — 사유 문자열 · OK 이면 'OK …')
    $premise = { param($e, $s, $cls)
      $k = $e.kind
      if (& $eq $s.kind 'absent') {
        if ((& $eq $k 'django') -or (& $eq $k 'sentry')) { return 'OK(absent — W-2 가 만든다)' }
        return '어긋남(absent — 이 경로는 있어야 한다)' }
      if (-not (& $eq $s.kind 'live')) { return "어긋남($($s.kind) — 판정 불가)" }
      if ($null -eq $cls) { return '어긋남(데이터를 읽지 못했다)' }
      if (-not $cls.keysOk) { return '어긋남(키 집합 불일치)' }
      $c = $cls.byKey
      if ((& $eq $k 'db') -or (& $eq $k 'kafka') -or (& $eq $k 'dragonfly')) {
        foreach ($n in @($e.keys)) { if (-not (& $eq $c[$n] '값 있음')) { return "어긋남($n = $($c[$n]))" } }
        return 'OK(기존 경로 — 그대로 둔다)' }
      if (& $eq $k 'authentik') {
        foreach ($n in @('client_id', 'client_secret', 'api_token')) { if (-not (& $eq $c[$n] 'sentinel')) { return "어긋남($n = $($c[$n]) — US6 동안 sentinel 그대로 둔다)" } }
        if ((& $eq $c['jwks_url'] 'sentinel') -and (& $eq $c['issuer'] 'sentinel')) { return 'OK(jwks_url · issuer = sentinel → W-2 가 계약 값으로 patch)' }
        if ((& $eq $c['jwks_url'] '계약 값') -and (& $eq $c['issuer'] '계약 값')) { return 'OK(jwks_url · issuer = 계약 값 — W-2 는 건너뛴다)' }
        return "어긋남(jwks_url = $($c['jwks_url']) · issuer = $($c['issuer']))" }
      if (& $eq $k 'webhook') {
        if (& $eq $c['secret'] 'sentinel') { return 'OK(sentinel → W-2 가 CSPRNG 43자로 덮어쓴다)' }
        if (& $eq $c['secret'] '규칙 충족(43자 base64url)') { return 'OK(이미 실값 — W-2 는 건너뛴다 · 바꾸지 않는다)' }
        return "어긋남(secret = $($c['secret']))" }
      if (& $eq $k 'django') {
        if (& $eq $c['secret_key'] '규칙 충족(W009 · 64자 base64url — W-2 꼴)') { return 'OK(이미 있음 — W-2 는 건너뛴다)' }
        return "어긋남(secret_key = $($c['secret_key']))" }
      if (& $eq $k 'sentry') {
        if (& $eq $c['dsn'] '빈 값(Sentry 끔)') { return 'OK(이미 빈 dsn — W-2 는 건너뛴다)' }
        return "어긋남(dsn = $($c['dsn']))" }
      $n = @($e.keys)[0]
      if (& $eq $c[$n] 'sentinel') { return 'OK(sentinel 그대로 — 면제 · T082)' }
      "어긋남($n = $($c[$n]) — US6 동안 sentinel 그대로 둔다)" }
    # ---------- 0) 창 전제(비밀을 묻기 전에 전부 확인한다) — 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저다 ----------
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 묻지 않았다)' }
    $ch = & $prop (Get-ItemProperty 'HKCU:\Software\Microsoft\Clipboard' -ErrorAction SilentlyContinue) 'EnableClipboardHistory'
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시(아무것도 묻지 않았다)' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시(아무것도 묻지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 kv · 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 묻지 않았다)" }
    # 모듈 로깅 실효 상태(T075 보정 2026-11-17 · 리뷰 KB-2 · 라운드 2 KB2-1): 정책 레지스트리가 비어도 powershell.config.json(시스템 = $PSHOME · 사용자 = 문서 폴더 PowerShell)이나
    #   pwsh -SettingsFile 로 켜질 수 있다 — 이 블록의 값이 지나가는 cmdlet 이 사는 넷(Core 스냅인 · Utility · Security · Management)의 LogPipelineExecutionDetails(이 프로세스의 실효 값)를 본다
    #   (-SettingsFile 로 준 파일은 블록이 읽을 수 없다 — 그 갈래는 실효 값이 잡는다). 설정 파일 두 곳은 값과 무관하게 판정한다: 텍스트에 ModuleLogging(대소문자 무관) 또는 역슬래시-u
    #   이스케이프가 있으면 멈춘다(문자열 true · 1 · 주석 · 따옴표 꼴 · 이스케이프 키 우회 — 리뷰 실측) · 텍스트로만 읽는다(ConvertFrom-Json 0) · 모듈 · 스냅인 · 사용자 위치를 확인하지 못하면 멈춘다
    Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security, Microsoft.PowerShell.Management
    $mlMods = @(Get-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security)
    $mlMgmt = @(Get-Module Microsoft.PowerShell.Management)
    $mlFe = @(Get-Command ForEach-Object -CommandType Cmdlet)
    $mlCore = $null
    if ($mlFe.Count -eq 1) { $mlCore = $mlFe[0].PSSnapIn }
    $mlEff = @(@($mlMods) + @($mlMgmt) | Where-Object { $_.LogPipelineExecutionDetails } | ForEach-Object { $_.Name })
    if ($null -ne $mlCore -and $mlCore.LogPipelineExecutionDetails) { $mlEff += 'Microsoft.PowerShell.Core' }
    $mlUser = ''
    if ($null -ne $PROFILE -and $null -ne $PROFILE.PSObject.Properties['CurrentUserAllHosts']) { $mlUser = Join-Path (Split-Path -Parent ([string]$PROFILE.CurrentUserAllHosts)) 'powershell.config.json' }
    $mlCfgOn = @(@((Join-Path $PSHOME 'powershell.config.json'), $mlUser) | Where-Object { $_.Length -gt 0 -and (Test-Path -LiteralPath $_) -and ((Get-Content -Raw -LiteralPath $_) -cmatch '(?i:ModuleLogging)|\x5Cu') })
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 kv · 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 묻지 않았다)" }
    if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인을 확인하고 지운 뒤 다시(아무것도 묻지 않았다)' }
    $pre = @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })
    $bad = @($pre | Where-Object { -not ([string]::Equals($_.Name, 'VAULT_ADDR', [StringComparison]::OrdinalIgnoreCase) -and (& $eq $_.Value $vaultAddr)) } | ForEach-Object { $_.Name })
    if ($bad.Count -gt 0) { throw "이 창에 VAULT_* 환경 변수가 이미 있다: $($bad -join ', ') — 블록은 건드리지 않았다. 확인 뒤 Remove-Item Env:<이름> 하고 다시(VAULT_ADDR=$vaultAddr 만 허용 · 아무것도 묻지 않았다)" }
    $vcs = @(Get-Command vault -ErrorAction SilentlyContinue)
    if ($vcs.Count -eq 0) { throw 'vault CLI 를 찾을 수 없다(PATH) — 설치 · PATH 확인(아무것도 묻지 않았다)' }
    $vsrc = [string]$vcs[0].Source
    if ([string]::IsNullOrEmpty($vsrc)) { $vsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $vsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $vsrc = '~' + $vsrc.Substring($HOME.Length) }
    $ver = @(vault version 2>$null)
    $global:LASTEXITCODE = 0
    $verLine = '(버전 출력 없음)'
    if ($ver.Count -gt 0) { $verLine = ([string]$ver[0]).Trim() -replace '\p{Cc}', '?' }
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — 판정 전용(쓰기 0)"
    # ---------- 0b) Vault 도달(창 C 의 port-forward) — 토큰 없이 ----------
    $addrOwned = $true
    $env:VAULT_ADDR = $vaultAddr
    $so = @(vault status "-format=json" 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $serr = @($so | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $st = & $parseJson @($so | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
    $ini = & $prop $st 'initialized'
    $sea = & $prop $st 'sealed'
    if ($ini -isnot [bool] -or $sea -isnot [bool]) { throw "Vault 도달 실패 또는 status 응답 해석 실패(status exit=$rc · $(& $firstErr $serr)) — 창 C port-forward 확인(root 토큰은 아직 묻지 않았다)" }
    if (-not $ini) { throw 'Vault 미초기화 — vault-unseal.md 확인(root 토큰은 아직 묻지 않았다)' }
    if ($sea) { throw 'Vault sealed — vault-unseal.md §1 · §2 확인(root 토큰은 아직 묻지 않았다)' }
    if ($rc -ne 0) { throw "vault status 가 unsealed 인데 exit=$rc — 판단 불가, 중단(root 토큰은 아직 묻지 않았다)" }
    Write-Host "OK   Vault 도달 · 초기화됨 · unsealed(seal type=$(([string](& $prop $st 'type')) -replace '\p{Cc}', '?') · server $(([string](& $prop $st 'version')) -replace '\p{Cc}', '?'))"
    # ---------- 1) root 토큰(PM) ----------
    $tok = ([string](& $readSecret 'root 토큰(PM 에서 복사 · 화면에 남지 않음 · 붙여넣은 직후 클립보드를 비운다)')).Trim()
    if ($tok -cnotmatch '\Ahvs\.[\x21-\x7E]+\z') { $tok = $null; throw '입력이 Vault 토큰 형식(hvs. 로 시작하는 공백 없는 ASCII)이 아니다 — PM 의 다른 항목을 붙여 넣었다. Vault 로 보내지 않았다' }
    $tokenOwned = $true
    $env:VAULT_TOKEN = $tok
    $tok = $null
    $tl = @(vault token lookup "-format=json" 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pol = @()
    if ($rc -eq 0) { $pol = @(& $prop (& $prop (& $parseJson $tl) 'data') 'policies') }
    $tl = $null
    if ($rc -ne 0) { throw "root 토큰 확인 실패(token lookup exit=$rc) — PM 항목 · 창 C 확인" }
    if (-not (& $has $pol 'root')) { throw '토큰 정책에 root 가 없다 — 이 블록은 root 토큰 전용이다(T044 D4)' }
    Write-Host 'OK   토큰 정책에 root 포함 — 판정(읽기 전용)을 시작한다'
    # ---------- 2) 판정(읽기 전용 — 경로마다 상태 → 데이터 → 키 집합 → 키별 분류 → W-2 전제) ----------
    foreach ($e in $paths) {
      $s = & $state $e.path
      $cls = $null
      $line = ''
      if (& $eq $s.kind 'live') {
        $r = & $readData $e.path
        if ($null -eq $r.dd) { $line = "live v$($s.cv) · $($r.why)" }
        else {
          $names = @($r.dd.PSObject.Properties | ForEach-Object { $_.Name })
          $missing = @(@($e.keys) | Where-Object { -not (& $has $names $_) })
          $extra = @($names | Where-Object { -not (& $has @($e.keys) $_) }).Count
          $byKey = @{}
          foreach ($n in @($e.keys)) { if (& $has $names $n) { $byKey[$n] = [string](& $classify $e.kind $n (& $prop $r.dd $n)) } else { $byKey[$n] = '없음' } }
          $cls = [pscustomobject]@{ keysOk = ($missing.Count -eq 0 -and $extra -eq 0); byKey = $byKey }
          $ks = '키 집합 일치'
          if (-not $cls.keysOk) { $ks = "키 집합 불일치(누락 $($missing.Count) · 여분 $extra)" }
          $line = "live v$($s.cv) · $ks · " + (@(@($e.keys) | ForEach-Object { "$_=$($byKey[$_])" }) -join ' · ') }
        $r = $null }
      elseif (& $eq $s.kind 'absent') { $line = 'absent(경로 없음)' }
      else { $line = "$($s.kind) — $($s.why)" }
      $pm = [string](& $premise $e $s $cls)
      $cls = $null
      if ($pm.StartsWith('OK', [StringComparison]::Ordinal)) { $okCount[$e.env] = $okCount[$e.env] + 1 }
      $sumLog[$e.path] = "$line → W-2 전제 $pm"
      Write-Host "JUDGE $($e.path) — $line → W-2 전제 $pm" } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, s, r, cls, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T075 O-2 kv 판정 요약(값 없음 · 쓰기 0 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---'
    foreach ($k in $sumLog.Keys) { Write-Host ('{0,-46} {1}' -f $k, $sumLog[$k]) }
    $nDev = @($paths | Where-Object { $_.env -ceq 'dev' }).Count
    $nProd = @($paths | Where-Object { $_.env -ceq 'prod' }).Count
    Write-Host "o2 W-2 전제: dev $($okCount['dev'])/$nDev · prod $($okCount['prod'])/$nProd"
    if ($okCount['dev'] -eq $nDev -and $okCount['prod'] -eq $nProd) { Write-Host '판정: W-2 전제 충족(dev · prod) — 이 출력을 컨트롤러에게 붙인 뒤 W-2 dev 를 실행한다' }
    else { Write-Host '판정: W-2 전제 미충족 — 어긋남 · 판정 불가 줄을 컨트롤러에게 붙이고 멈춘다(W-2 를 실행하지 않는다)' }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다(다음 블록도 새 프로세스로)'
  }
}
