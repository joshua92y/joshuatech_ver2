& {
  # ===== T075 W-6 acl 삭제 블록 — kv/<env>/dragonfly/acl 한 경로의 모든 버전 · 메타데이터 삭제(변경 · 되돌릴 수 없다) · 한 번에 한 경로 · 통째로 붙여 넣어도 안전(창 D) =====
  # 목적: UD-9 적용 순서 2단계(설계 D20 · 런북 docs/runbooks/bootstrap.md §4 T075 B) — W-6 이 acl 을 B2 로 다시 렌더하려면 옛 규칙 acl 경로가 없어야 한다(W-6 은 옛 규칙 acl 을 덮어쓰지 않는다).
  # 왜 T057 ② 삭제 블록을 쓰지 않는가(리뷰 KB-3 · KA-5): 그 블록의 허용 목록은 T057 7경로(사용자 비밀번호 5 + acl 2)라 admin · 사용자 경로를 잘못 치면 영구 삭제되고(그 뒤 ACL LOAD 도 못 한다),
  #   성공 줄은 op1(옛 판) 재실행을 안내한다. 이 블록의 허용 목록은 acl 두 경로뿐이고 성공 줄은 W-6 을 안내한다.
  # 「머지 전에만 지운다」(§4 T057 「정리 판단」)의 예외인 까닭: acl 은 그 env 사용자 비밀번호(kv 사용자 경로 — 그대로 둔다)의 SHA-256 으로 만드는 파생값이다. 지운 뒤 W-6 이
  #   live 비밀번호로 같은 비밀번호의 acl 을 다시 렌더하므로 잃는 값이 없다(지우는 동안 ES 는 잠시 SecretSyncedError 일 수 있다 — Secret 은 Retain · 돌고 있는 Dragonfly 영향 0).
  # 판정(쓰기 전 · 값 0): 경로 = 허용 목록 두 경로 중 하나(Ordinal) · live · 키 집합 = {users.acl} 정확히 · 그 값이 문자열(내용은 읽어 넘기지 않는다 · 출력 0). absent 면 지울 것이 없다(성공 — 다음 = W-6).
  # 사전(블록 밖 — 런북 §4 T075 「사전」): ① 창 D 창 시작 체크리스트 ② 창 C port-forward ③ 이 창에 VAULT_* 없음 · ~/.vault-token 없음 ④ PM 의 root 토큰 ⑤ O-6 사전 출력(기대 = 옛 규칙)
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>' · 정지점: ① 지울 경로(가려진다) ② root 토큰(보안 입력) ③ 같은 경로 재타자(가려진다 · Ordinal — 다르면 지우지 않는다)
  # 원칙: 사람 동작마다 정지점 · 판정(읽기)과 변경(삭제 1회)을 정지점으로 가른다 · 삭제 뒤 No value found 로 확인 · 값 · 해시 · 토큰은 어디에도 0 · finally 정리
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
  $allow = @('kv/dev/dragonfly/acl', 'kv/prod/dragonfly/acl')
  $path = ''
  $result = '지우지 않았다(이 실행에서 삭제까지 오지 못했다)'
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $askPath = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host $prompt -MaskInput
      [string]$ans }
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt(아무것도 지우지 않았다)" }
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
    # 경로 상태(값 없음): absent(No value found) · live(current_version · 그 버전이 삭제 · 파기되지 않음) · dead · error
    $state = { param($p)
      $o = @(vault kv metadata get "-format=json" $p 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $errs = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      if ($rc -ne 0) {
        if (@($errs | Where-Object { ([string]$_).StartsWith('No value found at ', [StringComparison]::Ordinal) }).Count -gt 0) { return [pscustomobject]@{ kind = 'absent'; cv = 0; why = '' } }
        return [pscustomobject]@{ kind = 'error'; cv = -1; why = "metadata 조회 exit=$rc · $(& $firstErr $errs)" } }
      $md = & $prop (& $parseJson @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) 'data'
      $o = $null
      $cvs = [string](& $prop $md 'current_version')
      if ($null -eq $md -or $cvs -cnotmatch '\A[0-9]+\z') { return [pscustomobject]@{ kind = 'error'; cv = -1; why = 'metadata 응답을 해석하지 못했다(원문 미출력)' } }
      $vv = & $prop (& $prop $md 'versions') $cvs
      if ($null -eq $vv -or (& $prop $vv 'destroyed') -eq $true -or -not [string]::IsNullOrEmpty([string](& $prop $vv 'deletion_time'))) { return [pscustomobject]@{ kind = 'dead'; cv = [int]$cvs; why = '현재 버전이 삭제 · 파기됐거나 메타데이터만 있다' } }
      [pscustomobject]@{ kind = 'live'; cv = [int]$cvs; why = '' } }
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
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — 변경 = acl 한 경로 삭제 1회(허용 목록 = kv/dev/dragonfly/acl · kv/prod/dragonfly/acl)"
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
    # ---------- 정지점 ① 지울 경로(허용 목록 밖이면 토큰을 묻지 않고 멈춘다) ----------
    $p1 = & $askPath '지울 acl 경로 — kv/dev/dragonfly/acl 또는 kv/prod/dragonfly/acl 을 그대로 입력(입력은 가려진다 · 한 번에 한 경로 · 그 외 = 중단)'
    if (-not (& $has $allow $p1)) { $p1 = $null; throw '허용 목록(kv/dev/dragonfly/acl · kv/prod/dragonfly/acl) 밖의 입력이다 — 중단(아무것도 지우지 않았다 · 사용자 · admin 경로는 이 블록으로 지우지 않는다)' }
    $path = $p1
    $p1 = $null
    Write-Host "OK   지울 경로 = $path(허용 목록 · Ordinal)"
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
    Write-Host 'OK   토큰 정책에 root 포함 — 삭제 전 판정(읽기 전용)을 시작한다'
    # ---------- 판정(값 0): live · 키 집합 = {users.acl} ----------
    $s = & $state $path
    if (& $eq $s.kind 'absent') {
      $result = '이미 없음(absent — 지울 것이 없다) · 다음 = W-6(w6-render-dragonfly-acl.ps1)'
      Write-Host "INFO $path — 이미 없다(absent) · 지울 것이 없다 — 다음 = W-6"
      return }
    if (-not (& $eq $s.kind 'live')) { $result = "중단(판정 $($s.kind) — $($s.why) · 지우지 않았다)"; throw "판정 $($s.kind): $path — $($s.why)(지우지 않았다 · 컨트롤러에게 보고)" }
    $o = @(vault kv get "-format=json" $path 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $dd = & $prop (& $prop (& $parseJson $o) 'data') 'data'
    $o = $null
    if ($rc -ne 0 -or $null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) { $dd = $null; $result = "중단(v$($s.cv) 데이터를 읽지 못했다 · kv get exit=$rc · 지우지 않았다)"; throw "판정 불가: $path — v$($s.cv) 데이터를 읽지 못했다(kv get exit=$rc) · 지우지 않았다" }
    $names = @($dd.PSObject.Properties | ForEach-Object { $_.Name })
    $isStr = ($null -ne $dd.PSObject.Properties['users.acl']) -and ((& $prop $dd 'users.acl') -is [string])
    $dd = $null
    if ($names.Count -ne 1 -or -not (& $eq $names[0] 'users.acl') -or -not $isStr) {
      $result = "중단(키 집합이 users.acl 하나가 아니다 · 키 $($names.Count)개 — 지우지 않았다)"
      Write-Host "STOP $path — 키 집합이 {users.acl} 이 아니다(키 $($names.Count)개 · 값 미출력) — acl 경로가 아닌 값일 수 있다 · 지우지 않았다(컨트롤러에게 보고)"
      throw "키 집합 불일치: $path — 지우지 않았다" }
    Write-Host ''
    Write-Host "지울 경로: $path — live v$($s.cv) · 키 users.acl(값 미출력) · 모든 버전과 메타데이터를 지운다(되돌릴 수 없다)"
    Write-Host '  사용자 비밀번호 5경로는 그대로 둔다 — acl 은 그 비밀번호의 SHA-256 으로 만든 파생값이라 W-6 이 같은 비밀번호로 다시 렌더한다(「머지 전에만 지운다」의 예외 까닭)'
    $again = & $askPath "삭제 확인 — $path 를 다시 그대로 입력(입력은 가려진다 · 대소문자 구분 · 다르면 지우지 않는다)"
    if (-not (& $eq $again $path)) { $again = $null; $result = '지우지 않았다(재타자가 경로와 다르다)'; throw "정지점에서 중단: 재타자가 경로와 다르다 — 아무것도 지우지 않았다" }
    $again = $null
    $result = '결과 미확인(삭제를 보내는 중 중단 — O-6 사전 또는 이 블록 재실행으로 상태를 본다)'
    # ---------- 삭제 1회 → 다시 판정(No value found 여야 한다) ----------
    $null = @(vault kv metadata delete $path 2>&1)
    $drc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $s2 = & $state $path
    if (& $eq $s2.kind 'absent') {
      $how = '삭제'; if ($drc -ne 0) { $how = "삭제 응답 exit=$drc 뒤 재판정" }
      $result = "OK(모든 버전 · 메타데이터 삭제 — No value found 확인 · $how) · 다음 = W-6"
      Write-Host "OK   $path — 모든 버전 · 메타데이터 삭제(No value found 확인 · $how) · 다음 = W-6(w6-render-dragonfly-acl.ps1 — 두 env 의 acl 을 지운 뒤 한 번 · 사용자 경로는 그대로)" }
    elseif (& $eq $s2.kind 'error') {
      $result = "결과 미확인(삭제 exit=$drc · 뒤 조회 오류 — $($s2.why))"
      Write-Host "STOP $path — 삭제 확인 실패(조회 오류 — $($s2.why)) · 지워졌는지 모른다 — 이 블록을 다시 돌려 상태를 본다"
      throw "삭제 확인 실패: $path" }
    else {
      $result = "실패(삭제 exit=$drc · 경로가 남아 있다 — $($s2.kind) v$($s2.cv))"
      Write-Host "STOP $path — 삭제되지 않았다(삭제 exit=$drc · 경로가 남아 있다 — $($s2.kind) v$($s2.cv)) — 토큰 정책 · 창 C 확인 뒤 다시"
      throw "삭제 실패: $path" } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, o, dd, p1, again, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T075 acl 삭제 결과(값 · 해시 없음 — 런북 bootstrap.md §4 T075 기록 칸 B 에 그대로 기록) ---'
    Write-Host "acl-delete $(if ($path) { $path } else { '(경로 선택 전)' }) = $result"
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
