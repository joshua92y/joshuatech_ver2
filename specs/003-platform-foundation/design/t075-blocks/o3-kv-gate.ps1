& {
  # ===== T075 O-3 블록 — identity-admin kv 게이트 1(키 단위 · 쓰기 0) · env 하나씩 · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: 같은 디렉터리 O-2(o2-kv-judge.ps1)의 창 전제 · Vault 도달 · root 토큰 · 상태 기계 · 정리를 그대로 쓴다. vault-unseal.md §US6 게이트 1 의 키 단위 개정(설계 D10 · C8)이다 —
  #       경로 단위 블록(read=8/8 hits=0)은 T044 판정 기록으로 남는다(T075 뒤에는 면제 셋이 sentinel 이라 hits 0 이 될 수 없다).
  # 목적: W-2 <env> 뒤 · 그 env 의 identity-admin 배포(GP-2 · GP-3) 전의 게이트. 컨트롤러에는 마지막 줄 gate=PASS n/n 하나만 붙인다(값 · 해시 0).
  # 시점(T075 보정 2026-11-17 · 리뷰 KA-8): 이 블록은 US6(T075) 시점의 게이트다 — api_token · store_id · preshared · client_id · client_secret 이 sentinel 이어야 PASS 다. T081(Authentik 실값) ·
  #   T082(OpenFGA 실값) 뒤에 이 블록을 그대로 돌리면 그 행이 구조적으로 FAIL 한다 — 그때는 기대를 바꾼 판(T081 · T082 가 만든다)을 쓴다. 이 블록을 고쳐 돌리지 않는다.
  # PASS 조건(설계 D10 — dev 21 · prod 23):
  #   authentik/identity-admin: 키 집합 정확히 5 · jwks_url · issuer = 계약 값(글자까지) · api_token = sentinel(면제 — JT_PLACEHOLDER_EXEMPT) · client_id · client_secret = sentinel(판정 밖 — 매핑 없음)
  #   authentik/webhooks/identity-admin: 키 {secret} · sentinel 아님 · 정확히 43자 ^[A-Za-z0-9_-]{43}$ · 끝 줄바꿈 없음 · 서로 다른 글자 16 이상(KB-9) · (prod 차례) dev 해시 ≠ prod 해시
  #   django/identity-admin: 키 {secret_key} · 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 접두 아님 · (prod 차례) dev ≠ prod
  #   sentry/identity-admin: 키 {dsn} · 빈 값 · openfga/store_id · openfga/preshared: 키 {store_id} · {key} · sentinel(면제)
  #   기존 경로(db app · owner · kafka · dragonfly identity-admin): 키 집합이 맞다 · 10경로 전체에서 면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0
  # 사전 · 실행: O-2 와 같다(창 D · 창 C port-forward · VAULT_* 없음 · ~/.vault-token 없음 · PM root 토큰) — pwsh -NoProfile -File '<이 파일의 절대 경로>'
  # 정지점: ① env — dev 또는 prod 를 그대로(입력은 가려진다) ② root 토큰(보안 입력) — 이 블록은 아무것도 쓰지 않는다(vault kv put · patch · delete 0)
  # 원칙: 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드에 0 · 판정 불가는 FAIL(fail-closed) · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저 · finally 정리(env · 변수 · 클립보드 · $Error)
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
  $envSel = ''
  $gate = [ordered]@{}
  $gateDone = $false
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $sha = { param($s) [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $pickEnv = {
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host '게이트를 볼 env — dev 또는 prod 를 그대로 입력(입력은 가려진다 · 그 외 입력 = 중단)' -MaskInput
      if (& $eq $ans 'dev') { return 'dev' }
      if (& $eq $ans 'prod') { return 'prod' }
      throw '정지점에서 중단: env 선택(dev · prod 가 아니다) — 아무것도 읽지 않았다' }
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
    # 경로 읽기 = 상태 + 현재 버전 데이터(값이 든 객체 — 출력하지 않는다). 읽지 못하면 dd = $null · why = 분류
    $load = { param($path)
      $s = & $state $path
      if (-not (& $eq $s.kind 'live')) { return [pscustomobject]@{ dd = $null; why = "$($s.kind)$(if ($s.why) { ' — ' + $s.why })"; cv = $s.cv } }
      $o = @(vault kv get "-format=json" $path 2>$null)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or $o.Count -eq 0) { return [pscustomobject]@{ dd = $null; why = "kv get exit=$rc(값을 읽지 못했다)"; cv = $s.cv } }
      $jr = & $parseJson $o
      $o = $null
      if ($null -eq $jr) { return [pscustomobject]@{ dd = $null; why = 'kv get 응답을 해석하지 못했다(원문 미출력)'; cv = $s.cv } }
      $dd = & $prop (& $prop $jr 'data') 'data'
      $jr = $null
      if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) { return [pscustomobject]@{ dd = $null; why = '현재 버전에 데이터가 없다'; cv = $s.cv } }
      [pscustomobject]@{ dd = $dd; why = ''; cv = $s.cv } }
    # 판정 한 줄을 기록한다(이름 → 'PASS' 또는 'FAIL(사유)' — 사유는 분류만)
    $check = { param($name, $ok, $why)
      if ($ok) { $gate[$name] = 'PASS' } else { $gate[$name] = "FAIL($why)" } }
    $keysOf = { param($r, $keys)
      if ($null -eq $r.dd) { return "읽지 못했다 — $($r.why)" }
      $names = @($r.dd.PSObject.Properties | ForEach-Object { $_.Name })
      $missing = @(@($keys) | Where-Object { -not (& $has $names $_) })
      $extra = @($names | Where-Object { -not (& $has @($keys) $_) }).Count
      if ($missing.Count -gt 0 -or $extra -gt 0) {
        $ms = '없음'
        if ($missing.Count -gt 0) { $ms = $missing -join '·' }
        return "키 집합 불일치(누락: $ms · 여분 ${extra}개)" }
      foreach ($k in @($keys)) { if ((& $prop $r.dd $k) -isnot [string]) { return "$k 값이 문자열이 아니다" } }
      '' }
    $w009 = { param($v) ($v -is [string]) -and $v.Length -ge 50 -and ([System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count -ge 5) -and -not $v.StartsWith('django-insecure-', [StringComparison]::Ordinal) }
    # ---------- 0) 창 전제 — 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저다 ----------
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
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — 게이트 판정 전용(쓰기 0)"
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
    $envSel = [string](& $pickEnv)
    $role = 'identity_admin'
    if (& $eq $envSel 'dev') { $role = 'dev_identity_admin' }
    Write-Host "OK   게이트 env = $envSel"
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
    Write-Host 'OK   토큰 정책에 root 포함 — 게이트 판정(읽기 전용)을 시작한다'
    # ---------- 판정(읽기 전용) — 10경로를 읽고(값은 메모리에만) 조건마다 PASS/FAIL ----------
    $p = [ordered]@{
      app = "kv/$envSel/db/$role/app"; owner = "kv/$envSel/db/$role/owner"; kafka = "kv/$envSel/kafka/identity-admin"; dragonfly = "kv/$envSel/dragonfly/identity-admin"
      authentik = "kv/$envSel/authentik/identity-admin"; webhook = "kv/$envSel/authentik/webhooks/identity-admin"; django = "kv/$envSel/django/identity-admin"
      sentry = "kv/$envSel/sentry/identity-admin"; store = "kv/$envSel/openfga/store_id"; preshared = "kv/$envSel/openfga/preshared" }
    $keysWant = @{ app = @('username', 'password', 'url'); owner = @('username', 'password', 'url'); kafka = @('password'); dragonfly = @('password', 'url')
      authentik = @('client_id', 'client_secret', 'jwks_url', 'issuer', 'api_token'); webhook = @('secret'); django = @('secret_key'); sentry = @('dsn'); store = @('store_id'); preshared = @('key') }
    $data = @{}
    foreach ($k in @($p.Keys)) { $data[$k] = & $load $p[$k] }
    $a = $data['authentik']
    $ka = [string](& $keysOf $a $keysWant['authentik'])
    & $check "authentik 키 집합 = client_id · client_secret · jwks_url · issuer · api_token($($p['authentik']))" ($ka.Length -eq 0) $ka
    foreach ($q in @(@('jwks_url', $jwksWant), @('issuer', $issWant))) {
      $v = $null; if ($ka.Length -eq 0) { $v = & $prop $a.dd $q[0] }
      $why = '계약 값과 다르다(값 미출력)'
      if ($ka.Length -gt 0) { $why = '키 집합 판정 실패' } elseif (& $eq $v $sentinel) { $why = 'sentinel 그대로(W-2 미실행)' }
      & $check "authentik $($q[0]) = 계약 값(글자까지)" (($ka.Length -eq 0) -and (& $eq $v $q[1])) $why }
    foreach ($q in @(@('api_token', '면제 — JT_PLACEHOLDER_EXEMPT'), @('client_id', '판정 밖 — pod 에 매핑하지 않는다'), @('client_secret', '판정 밖 — pod 에 매핑하지 않는다'))) {
      $v = $null; if ($ka.Length -eq 0) { $v = & $prop $a.dd $q[0] }
      $why = '키 집합 판정 실패'; if ($ka.Length -eq 0) { $why = 'sentinel 이 아니다(US6 동안 바뀌지 않아야 한다 — T081 · T082 가 바꾼다 · 값 미출력)' }
      & $check "authentik $($q[0]) = sentinel($($q[1]))" (($ka.Length -eq 0) -and (& $eq $v $sentinel)) $why }
    $w = $data['webhook']
    $kw = [string](& $keysOf $w $keysWant['webhook'])
    & $check "webhooks 키 집합 = secret($($p['webhook']))" ($kw.Length -eq 0) $kw
    $v = $null; if ($kw.Length -eq 0) { $v = [string](& $prop $w.dd 'secret') }
    $why = '키 집합 판정 실패'
    if ($kw.Length -eq 0) {
      if (& $eq $v $sentinel) { $why = 'sentinel 그대로(W-2 미실행)' }
      elseif ($v.Contains("`n") -or $v.Contains("`r")) { $why = '줄바꿈이 있다' }
      elseif ($v.Length -ne 43) { $why = "길이 $($v.Length)(43 기대)" }
      else { $why = 'base64url 밖의 문자' } }
    $wOk = ($kw.Length -eq 0) -and -not (& $eq $v $sentinel) -and ($v -cmatch '\A[A-Za-z0-9_-]{43}\z')
    # 서로 다른 글자 16 이상(T075 보정 2026-11-17 · 리뷰 KB-9 — 32바이트 CSPRNG 의 43자가 16 미만일 확률 2.2×10^-13 이하 · 값 · 글자 수 미출력 · 근거 = t075-blocks/README.md)
    if ($wOk -and [System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count -lt 16) { $wOk = $false; $why = '서로 다른 글자 16 미만(CSPRNG 값이 아니다 · 값 미출력)' }
    & $check 'webhooks secret: sentinel 아님 · 정확히 43자 · ^[A-Za-z0-9_-]{43}$ · 끝 줄바꿈 없음 · 서로 다른 글자 16 이상' $wOk $why
    $wHash = ''; if ($wOk) { $wHash = & $sha $v }
    $d = $data['django']
    $kd = [string](& $keysOf $d $keysWant['django'])
    & $check "django 키 집합 = secret_key($($p['django']))" ($kd.Length -eq 0) $kd
    $v = $null; if ($kd.Length -eq 0) { $v = [string](& $prop $d.dd 'secret_key') }
    $why = '키 집합 판정 실패'
    if ($kd.Length -eq 0) {
      if ($v.Length -lt 50) { $why = "길이 $($v.Length)(50 이상 기대)" }
      elseif ($v.StartsWith('django-insecure-', [StringComparison]::Ordinal)) { $why = 'django-insecure- 접두' }
      else { $why = '서로 다른 글자 5 미만' } }
    $dOk = ($kd.Length -eq 0) -and (& $w009 $v)
    & $check 'django secret_key: 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 접두 아님(W009)' $dOk $why
    $dHash = ''; if ($dOk) { $dHash = & $sha $v }
    $v = $null
    $s = $data['sentry']
    $ks = [string](& $keysOf $s $keysWant['sentry'])
    & $check "sentry 키 집합 = dsn($($p['sentry']))" ($ks.Length -eq 0) $ks
    $why = '키 집합 판정 실패'; if ($ks.Length -eq 0) { $why = '빈 값이 아니다(값 미출력)' }
    & $check 'sentry dsn = 빈 값(Sentry 끔 — 실값은 T100)' (($ks.Length -eq 0) -and (& $eq (& $prop $s.dd 'dsn') '')) $why
    foreach ($q in @(@('store', 'store_id', 'openfga/store_id'), @('preshared', 'key', 'openfga/preshared'))) {
      $r = $data[$q[0]]
      $kq = [string](& $keysOf $r $keysWant[$q[0]])
      & $check "$($q[2]) 키 집합 = $($q[1])($($p[$q[0]]))" ($kq.Length -eq 0) $kq
      $why = '키 집합 판정 실패'; if ($kq.Length -eq 0) { $why = 'sentinel 이 아니다(값 미출력)' }
      & $check "$($q[2]) $($q[1]) = sentinel(면제 — JT_PLACEHOLDER_EXEMPT · 교체는 T082)" (($kq.Length -eq 0) -and (& $eq (& $prop $r.dd $q[1]) $sentinel)) $why }
    foreach ($q in @(@('app', 'db app'), @('owner', 'db owner'), @('kafka', 'kafka'), @('dragonfly', 'dragonfly'))) {
      $kq = [string](& $keysOf $data[$q[0]] $keysWant[$q[0]])
      & $check "$($q[1]) 키 집합 = $($keysWant[$q[0]] -join ' · ')($($p[$q[0]]))" ($kq.Length -eq 0) $kq }
    # 면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0(10경로 전체 — 읽지 못한 경로가 있으면 판정 불가 = FAIL)
    $exempt = @('authentik:api_token', 'authentik:client_id', 'authentik:client_secret', 'store:store_id', 'preshared:key')
    $hits = @(); $unread = @()
    foreach ($k in @($p.Keys)) {
      $r = $data[$k]
      if ($null -eq $r.dd) { $unread += $k; continue }
      foreach ($pp in @($r.dd.PSObject.Properties)) {
        if (& $has $exempt "${k}:$($pp.Name)") { continue }
        if (($pp.Value -is [string]) -and $pp.Value.Contains('PLACEHOLDER-')) { $hits += "$($p[$k]):$($pp.Name)" } } }
    $why = ''
    if ($unread.Count -gt 0) { $why = "읽지 못한 경로 $($unread.Count)($($unread -join '·')) — 판정 불가" } elseif ($hits.Count -gt 0) { $why = "$($hits.Count)건 — $($hits -join ' · ')" }
    & $check '면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0(10경로 전체)' ($unread.Count -eq 0 -and $hits.Count -eq 0) $why
    # (prod 차례) dev 해시 ≠ prod 해시 — dev 두 값을 읽어 SHA-256 만 비교한다(값 · 해시 미출력)
    if (& $eq $envSel 'prod') {
      foreach ($q in @(@('webhook', 'kv/dev/authentik/webhooks/identity-admin', 'secret', $wHash, 'webhooks secret'), @('django', 'kv/dev/django/identity-admin', 'secret_key', $dHash, 'django secret_key'))) {
        $r = & $load $q[1]
        $dv = $null; if ($null -ne $r.dd) { $dv = & $prop $r.dd $q[2] }
        $why = ''
        if ($null -eq $r.dd) { $why = "dev 값을 읽지 못했다 — $($r.why)" }
        elseif ($dv -isnot [string] -or (& $eq $dv $sentinel)) { $why = 'dev 값이 실값이 아니다(W-2 dev 먼저)' }
        elseif ($q[3].Length -eq 0) { $why = 'prod 값이 위 조건을 통과하지 못했다' }
        elseif (& $eq (& $sha $dv) $q[3]) { $why = 'dev 와 prod 가 같다(값 · 해시 미출력)' }
        & $check "$($q[4]): dev 해시 ≠ prod 해시" ($why.Length -eq 0) $why
        $r = $null; $dv = $null } }
    $data = $null; $a = $null; $w = $null; $d = $null; $s = $null; $r = $null; $wHash = $null; $dHash = $null
    $gateDone = $true }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, data, a, w, d, s, r, v, dv, wHash, dHash, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T075 O-3 게이트 1(키 단위 · env=$(if ($envSel) { $envSel } else { '선택 전' }) · 값 없음 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---"
    foreach ($k in $gate.Keys) {
      if (([string]$gate[$k]).StartsWith('PASS', [StringComparison]::Ordinal)) { Write-Host "PASS $k" } else { Write-Host "FAIL $k — $($gate[$k])" } }
    $nAll = $gate.Count
    $nPass = @($gate.Values | Where-Object { ([string]$_).StartsWith('PASS', [StringComparison]::Ordinal) }).Count
    if (-not $gateDone) { Write-Host 'gate=판정 불가(중단 — 위 오류 · 런북 §4 T075 실패 표)' }
    elseif ($nPass -eq $nAll -and $nAll -gt 0) { Write-Host "gate=PASS $nPass/$nAll" }
    else { Write-Host "gate=FAIL $nPass/$nAll" }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
