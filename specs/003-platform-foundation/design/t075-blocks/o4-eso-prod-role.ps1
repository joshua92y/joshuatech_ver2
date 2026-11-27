& {
  # ===== T075 O-4 블록 — vault-prod 첫 로그인 전 점검(쓰기 0) · auth/kubernetes/role/eso-prod 투영 + 정책 eso-prod · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: 같은 디렉터리 O-2 의 창 전제 · Vault 도달 · root 토큰 · 정리를 그대로 쓴다(설계 D10 표 O-4 · CD-27 · §5 L3).
  # 목적: vault-prod 는 소비자가 0 이다 — T075 의 prod ExternalSecret(GP-3)이 첫 로그인이다. 그 전에 role 과 정책이 infra/vault 선언과 같은지 본다(비밀 아닌 값만 출력).
  # 기대(infra/vault/roles.tf · policies.tf — T044):
  #   bound_service_account_names = [eso-prod] · bound_service_account_namespaces = [external-secrets] · audience = vault · token_policies = [eso-prod] ·
  #   token_ttl = 3600(1h) · token_max_ttl = 14400(4h) · 정책 eso-prod = path "kv/data/prod/*" { capabilities = ["read"] } + path "kv/metadata/prod/*" { capabilities = ["read"] } 두 줄뿐 ·
  #   (T075 보정 2026-11-17 · 리뷰 KB-6) token_type = service · token_period · token_explicit_max_ttl · token_num_uses = 0 · token_bound_cidrs = [] · token_no_default_policy = false ·
  #   bound_service_account_namespace_selector = "" — 모두 14줄 · o4=PASS 14/14
  # 사전 · 실행: O-2 와 같다(창 D · 창 C port-forward · VAULT_* 없음 · ~/.vault-token 없음 · PM root 토큰) — pwsh -NoProfile -File '<이 파일의 절대 경로>'
  # 정지점: root 토큰(보안 입력) 하나 — 이 블록은 아무것도 쓰지 않는다(vault read · vault policy read 뿐)
  # 원칙: 토큰은 화면 · argv · 파일 · 클립보드에 0 · 출력은 비밀 아닌 role 필드와 정책 본문뿐 · 판정 불가는 FAIL · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저(token lookup 응답에 토큰 평문)
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
  $polWant = @('path "kv/data/prod/*" { capabilities = ["read"] }', 'path "kv/metadata/prod/*" { capabilities = ["read"] }')
  $res = [ordered]@{}
  $done = $false
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
    # 목록 정확히(순서 무관 · Ordinal · 중복 없음)
    $sameSet = { param($got, $want)
      $g = @($got | ForEach-Object { [string]$_ })
      $w = @($want | ForEach-Object { [string]$_ })
      if ($g.Count -ne $w.Count) { return $false }
      foreach ($x in $w) { if (@($g | Where-Object { & $eq $_ $x }).Count -ne 1) { return $false } }
      $true }
    $show = { param($v) if ($null -eq $v) { '(없음)' } else { '[' + (@($v | ForEach-Object { [string]$_ }) -join ', ') + ']' } }
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
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 묻지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 묻지 않았다)" }
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
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — 읽기 전용(vault read · vault policy read)"
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
    Write-Host 'OK   토큰 정책에 root 포함 — role · 정책 읽기(읽기 전용)'
    # ---------- role 투영(비밀 아닌 값) ----------
    $ro = @(vault read "-format=json" auth/kubernetes/role/eso-prod 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $rerr = @($ro | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $rd = & $prop (& $parseJson @($ro | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) 'data'
    $ro = $null
    if ($rc -ne 0 -or $null -eq $rd) { throw "role 조회 실패(vault read exit=$rc · $(& $firstErr $rerr)) — auth/kubernetes/role/eso-prod 를 읽지 못했다(판정 불가)" }
    foreach ($q in @(@('bound_service_account_names', @('eso-prod')), @('bound_service_account_namespaces', @('external-secrets')), @('token_policies', @('eso-prod')))) {
      $v = & $prop $rd $q[0]
      $ok = ($null -ne $v) -and (& $sameSet $v $q[1])
      $res[$q[0]] = [pscustomobject]@{ ok = $ok; got = (& $show $v); want = (& $show $q[1]) } }
    $v = & $prop $rd 'audience'
    $res['audience'] = [pscustomobject]@{ ok = (($v -is [string]) -and (& $eq $v 'vault')); got = [string]$v; want = 'vault' }
    foreach ($q in @(@('token_ttl', '3600'), @('token_max_ttl', '14400'))) {
      $v = & $prop $rd $q[0]
      $res[$q[0]] = [pscustomobject]@{ ok = (($null -ne $v) -and ([string]$v -cmatch '\A[0-9]+\z') -and (& $eq ([string]$v) $q[1])); got = [string]$v; want = $q[1] } }
    # 그 밖의 토큰 필드(T075 보정 2026-11-17 · 리뷰 KB-6 — roles.tf 는 token_type = "service" 만 정하고 나머지는 기본값이다): token_type = service · token_period · token_explicit_max_ttl ·
    #   token_num_uses = 0 · token_bound_cidrs = 빈 목록 · token_no_default_policy = false · bound_service_account_namespace_selector = 빈 값(키는 있어야 한다 — 없으면 FAIL)
    $v = & $prop $rd 'token_type'
    $res['token_type'] = [pscustomobject]@{ ok = (($v -is [string]) -and (& $eq $v 'service')); got = [string]$v; want = 'service' }
    foreach ($q in @('token_period', 'token_explicit_max_ttl', 'token_num_uses')) {
      $v = & $prop $rd $q
      $res[$q] = [pscustomobject]@{ ok = (($null -ne $v) -and (& $eq ([string]$v) '0')); got = [string]$v; want = '0' } }
    $pp = $rd.PSObject.Properties['token_bound_cidrs']
    $res['token_bound_cidrs'] = [pscustomobject]@{ ok = (($null -ne $pp) -and @(@($pp.Value) | Where-Object { $null -ne $_ }).Count -eq 0); got = $(if ($null -eq $pp) { '(키 없음)' } else { & $show @(@($pp.Value) | Where-Object { $null -ne $_ }) }); want = '[]' }
    $v = & $prop $rd 'token_no_default_policy'
    $res['token_no_default_policy'] = [pscustomobject]@{ ok = (($v -is [bool]) -and -not $v); got = [string]$v; want = 'False' }
    $pp = $rd.PSObject.Properties['bound_service_account_namespace_selector']
    $res['bound_service_account_namespace_selector'] = [pscustomobject]@{ ok = (($null -ne $pp) -and ($pp.Value -is [string]) -and $pp.Value.Length -eq 0); got = $(if ($null -eq $pp) { '(키 없음)' } else { '"' + [string]$pp.Value + '"' }); want = '""' }
    $pp = $null
    $rd = $null
    # ---------- 정책 본문(비밀 아님 — 줄을 다듬어 두 줄 정확히) ----------
    $po = @(vault policy read eso-prod 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $perr = @($po | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $pl = @($po | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    if ($rc -ne 0) { $res['policy eso-prod'] = [pscustomobject]@{ ok = $false; got = "읽지 못했다(exit=$rc · $(& $firstErr $perr))"; want = ($polWant -join ' / ') } }
    else { $res['policy eso-prod'] = [pscustomobject]@{ ok = (& $sameSet $pl $polWant); got = ($pl -join ' / '); want = ($polWant -join ' / ') } }
    $done = $true }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, ro, rd, po, pp, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T075 O-4 eso-prod role · 정책 점검 요약(비밀 아닌 값 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---'
    # Vault 응답에서 온 값은 제어 문자를 '?' 로 바꿔 낸다(T075 보정 2026-11-17 · 리뷰 KB-7)
    foreach ($k in $res.Keys) {
      if ($res[$k].ok) { Write-Host "PASS $k = $(([string]$res[$k].got) -replace '\p{Cc}', '?')" } else { Write-Host "FAIL $k = $(([string]$res[$k].got) -replace '\p{Cc}', '?')(기대 $($res[$k].want))" } }
    $nPass = @($res.Values | Where-Object { $_.ok }).Count
    if (-not $done) { Write-Host 'o4=판정 불가(중단 — 위 오류 · 런북 §4 T075 실패 표)' }
    elseif ($nPass -eq $res.Count) { Write-Host "o4=PASS $nPass/$($res.Count)" }
    else { Write-Host "o4=FAIL $nPass/$($res.Count) — infra/vault 와 라이브가 다르다(tofu plan 으로 드리프트를 본다 · vault-prod ES 를 배포하지 않는다)" }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
