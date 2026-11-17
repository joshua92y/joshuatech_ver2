& {
  # ===== T075 O-6 사전 블록 — Dragonfly kv acl 줄 꼴 · pod 사용자 꼬리 판정(쓰기 0) · dev · prod · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: 같은 디렉터리 O-2 의 창 전제 · Vault 도달 · root 토큰 · 정리를 그대로 쓰고, 판정 규칙은 W-6(w6-render-dragonfly-acl.ps1)의 $lint 를 글자 그대로 옮겼다
  #       (설계 D20 「W-6 판정 = O-6 과 같은 판정 규칙」 — 하네스가 두 $lint 의 글자 일치를 본다).
  # 목적: UD-9 적용 순서 1단계(사전 — 기대 = 옛 규칙)와 W-6 뒤 재확인. kv/<env>/dragonfly/acl 의 users.acl 을 읽어 줄 꼴(dev 4줄 · prod 3줄 · default 줄 정확 · admin 줄)과
  #       pod 사용자 줄(identity-admin · dev 의 sample-pod)의 꼬리를 분류해 출력한다 — 해시 · 내용 0. pod 사용자 줄에 B2 꼬리(+@all -@admin -@dangerous -client)가 없으면 FAIL 이다
  #       (적용 전에는 「옛 규칙」으로 기대한 FAIL · 적용 뒤에는 회귀). kv 판정이라 라이브 메모리(ACL LOAD 여부)는 보지 않는다 — 그것은 O-6 사후(admin ACL DRYRUN)가 본다.
  # 사전 · 실행: O-2 와 같다(창 D · 창 C port-forward · VAULT_* 없음 · ~/.vault-token 없음 · PM root 토큰) — pwsh -NoProfile -File '<이 파일의 절대 경로>'
  # 정지점: root 토큰(보안 입력) 하나 — 이 블록은 아무것도 쓰지 않는다
  # 원칙: 값 · 해시 · acl 내용 · 토큰은 화면 · argv · 파일 · 클립보드에 0 · 판정 불가는 FAIL · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저 · finally 정리
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
  $verdict = [ordered]@{ dev = '판정 전'; prod = '판정 전' }
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
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
    # 렌더 줄 대조 — W-6 의 $lint 를 글자 그대로(순수 함수 · 출력 = '' 이면 통과 · 아니면 사유 분류 — 내용 · 해시 0)
    $lint = { param($ev, $text)
      if ($text -isnot [string]) { return '바이트: 문자열이 아니다' }
      $isDev = [string]::Equals([string]$ev, 'dev', [StringComparison]::Ordinal)
      if (-not $isDev -and -not [string]::Equals([string]$ev, 'prod', [StringComparison]::Ordinal)) { return 'env 가 dev · prod 가 아니다' }
      if ($text -cnotmatch '\A[\x20-\x7E\n]+\z') { return '바이트: ASCII 인쇄 문자 · LF 밖의 문자(CR · TAB · BOM · 비 ASCII)가 있다' }
      if (-not $text.EndsWith("`n", [StringComparison]::Ordinal) -or $text.EndsWith("`n`n", [StringComparison]::Ordinal)) { return '바이트: 끝 LF 가 정확히 1개가 아니다' }
      $lines = $text.Substring(0, $text.Length - 1).Split("`n")
      $tail = ' +@all -@admin -@dangerous -client'
      foreach ($l in $lines) {
        foreach ($pu in @('identity-admin', 'sample-pod')) {
          if ($l.StartsWith('USER ' + $pu + ' ', [StringComparison]::Ordinal) -and -not $l.EndsWith($tail, [StringComparison]::Ordinal)) { return "B2 꼬리 없음($pu 줄 — 옛 규칙 또는 다른 꼬리)" } } }
      $want = @(@('USER', 'default', 'OFF', '+auth', '+hello'), @('USER', 'admin', 'ON', '#', '~*', '&*', '+@all'), @('USER', 'identity-admin', 'ON', '#', '~revoked:*', '~identity-admin:*', '+@all', '-@admin', '-@dangerous', '-client'))
      if ($isDev) { $want += , @('USER', 'sample-pod', 'ON', '#', '%R~revoked:*', '~sample-pod:*', '+@all', '-@admin', '-@dangerous', '-client') }
      for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($t in $lines[$i].Split(' ')) {
          if ($t.Contains('|')) { return "금지 꼴: $($i + 1)줄에 세로 막대가 든 토큰(cmd 와 sub 를 이은 꼴 — 기동 무인증)" }
          if ($t.StartsWith('reset', [StringComparison]::OrdinalIgnoreCase)) { return "금지 꼴: $($i + 1)줄에 reset 계열 토큰(기동 무인증 꼴)" }
          if (($t.StartsWith('+@', [StringComparison]::Ordinal) -or $t.StartsWith('-@', [StringComparison]::Ordinal)) -and -not (@('+@all', '-@admin', '-@dangerous') -ccontains $t)) { return "금지 꼴: $($i + 1)줄에 허용 밖 카테고리 토큰(기동 무인증 꼴 — Redis 카테고리 이름 등)" } } }
      if ($lines.Count -ne $want.Count) { return "줄 수 $($lines.Count)(기대 $($want.Count) — dev 4 · prod 3)" }
      for ($i = 0; $i -lt $lines.Count; $i++) {
        $tk = $lines[$i].Split(' ')
        $w = $want[$i]
        $ok = ($tk.Count -eq $w.Count)
        for ($j = 0; $ok -and $j -lt $w.Count; $j++) {
          if ([string]::Equals($w[$j], '#', [StringComparison]::Ordinal)) { $ok = ($tk[$j] -cmatch '\A#[0-9a-f]{64}\z') }
          else { $ok = [string]::Equals($tk[$j], $w[$j], [StringComparison]::Ordinal) } }
        if (-not $ok) { return "$($i + 1)줄 토큰이 허용 꼴과 다르다(기대 USER $($w[1]) …)" } }
      '' }
    # 줄 꼴 분류(출력용 — 내용 · 해시 0): 줄 수 · default 줄 · admin 줄 꼴 · pod 사용자 줄의 꼬리(B2 · 옛 규칙(+@all) · 기타 꼬리 · 줄 없음)
    $shape = { param($ev, $text)
      $lines = $text.Substring(0, $text.Length - 1).Split("`n")
      $out = @("$($lines.Count)줄")
      if ($lines.Count -gt 0 -and (& $eq $lines[0] 'USER default OFF +auth +hello')) { $out += 'default 줄 정확' } else { $out += 'default 줄 다름' }
      $adm = @($lines | Where-Object { $_.StartsWith('USER admin ', [StringComparison]::Ordinal) })
      if ($adm.Count -eq 1 -and ($adm[0] -cmatch '\AUSER admin ON #[0-9a-f]{64} ~\* &\* \+@all\z')) { $out += 'admin 줄 꼴 정확' } else { $out += "admin 줄 꼴 다름($($adm.Count)줄)" }
      $pods = @('identity-admin')
      if (& $eq $ev 'dev') { $pods += 'sample-pod' }
      $tails = @()
      foreach ($pu in $pods) {
        $pl = @($lines | Where-Object { $_.StartsWith('USER ' + $pu + ' ', [StringComparison]::Ordinal) })
        $tc = '줄 없음'
        if ($pl.Count -gt 1) { $tc = "줄 $($pl.Count)개" }
        elseif ($pl.Count -eq 1) {
          if ($pl[0].EndsWith(' +@all -@admin -@dangerous -client', [StringComparison]::Ordinal)) { $tc = 'B2' }
          elseif ($pl[0].EndsWith(' +@all', [StringComparison]::Ordinal)) { $tc = '옛 규칙(+@all)' }
          else { $tc = '기타 꼬리' } }
        $tails += $tc
        $out += "$pu 꼬리 = $tc" }
      if (& $eq $ev 'prod') {
        if (@($lines | Where-Object { $_.StartsWith('USER sample-pod ', [StringComparison]::Ordinal) }).Count -gt 0) { $out += 'sample-pod 줄 있음(prod 에는 없어야 한다)' } else { $out += 'sample-pod 줄 없음(prod — 계약)' } }
      [pscustomobject]@{ text = ($out -join ' · '); tails = $tails } }
    # 옛 꼬리(+@all)로 끝나는 pod 사용자 줄에 B2 꼬리를 덧붙인 글자(T075 보정 2026-11-17 · 리뷰 KA-3 — 「옛 규칙」 판정용 · 출력하지 않는다): 이 글자에 $lint = '' 일 때만 「옛 규칙」이다 —
    #   아니면 옛 꼬리 밖에 다른 결함(F12 전 default 줄 · admin 줄 금지 꼴 · 줄 누락 등)이 있다 → FAIL(그 사유)
    $toB2 = { param($text)
      $ls = $text.Substring(0, $text.Length - 1).Split("`n")
      $o2 = @(foreach ($l in $ls) { if (($l.StartsWith('USER identity-admin ', [StringComparison]::Ordinal) -or $l.StartsWith('USER sample-pod ', [StringComparison]::Ordinal)) -and $l.EndsWith(' +@all', [StringComparison]::Ordinal)) { $l + ' -@admin -@dangerous -client' } else { $l } })
      ($o2 -join "`n") + "`n" }
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
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — kv acl 판정 전용(쓰기 0)"
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
    Write-Host 'OK   토큰 정책에 root 포함 — kv acl 판정(읽기 전용)을 시작한다'
    foreach ($ev in @('dev', 'prod')) {
      $path = "kv/$ev/dragonfly/acl"
      $o = @(vault kv metadata get "-format=json" $path 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $md = & $prop (& $parseJson @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) 'data'
      $merr = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      $o = $null
      if ($rc -ne 0 -or $null -eq $md) {
        $verdict[$ev] = "FAIL(판정 불가 — metadata 조회 exit=$rc · $(& $firstErr $merr))"
        Write-Host "O6PRE $path — $($verdict[$ev])"
        continue }
      $cv = [string](& $prop $md 'current_version')
      $o = @(vault kv get "-format=json" $path 2>$null)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $dd = & $prop (& $prop (& $parseJson $o) 'data') 'data'
      $o = $null
      if ($rc -ne 0 -or $null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) {
        $verdict[$ev] = "FAIL(판정 불가 — v$cv 데이터를 읽지 못했다 · kv get exit=$rc · soft-delete · destroy 포함)"
        Write-Host "O6PRE $path — $($verdict[$ev])"
        $dd = $null
        continue }
      $names = @($dd.PSObject.Properties | ForEach-Object { $_.Name })
      $acl = & $prop $dd 'users.acl'
      $dd = $null
      if ($names.Count -ne 1 -or -not (& $eq $names[0] 'users.acl') -or $acl -isnot [string]) {
        $verdict[$ev] = "FAIL(키 집합이 users.acl 하나가 아니다 · 키 $($names.Count)개 — 값 미출력)"
        Write-Host "O6PRE $path — live v$cv · $($verdict[$ev])"
        $acl = $null
        continue }
      $lw = [string](& $lint $ev $acl)
      $shp = ''
      $tails = @()
      if (-not $lw.StartsWith('바이트', [StringComparison]::Ordinal)) { $sh = & $shape $ev $acl; $shp = ' · ' + $sh.text; $tails = @($sh.tails) }
      $fx = ''
      if ($lw.StartsWith('B2 꼬리 없음', [StringComparison]::Ordinal)) { $fx = [string](& $lint $ev (& $toB2 $acl)) }
      $acl = $null
      if ($lw.Length -eq 0) { $verdict[$ev] = 'PASS(B2)' }
      elseif ($lw.StartsWith('B2 꼬리 없음', [StringComparison]::Ordinal) -and @($tails | Where-Object { -not (& $eq $_ '옛 규칙(+@all)') -and -not (& $eq $_ 'B2') }).Count -eq 0) {
        if ($fx.Length -eq 0) { $verdict[$ev] = 'FAIL(옛 규칙 — UD-9 적용 전이면 기대한 FAIL · 적용 뒤면 회귀)' }
        else { $verdict[$ev] = "FAIL(옛 규칙 꼬리 밖의 결함 — $fx)" } }
      else { $verdict[$ev] = "FAIL($lw)" }
      Write-Host "O6PRE $path — live v$cv · 키 users.acl$shp → $($verdict[$ev])" } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, o, dd, acl, md, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T075 O-6 사전 요약(kv acl 줄 꼴 · 해시 · 내용 없음 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---'
    Write-Host "o6-pre dev=$($verdict['dev']) prod=$($verdict['prod'])"
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
