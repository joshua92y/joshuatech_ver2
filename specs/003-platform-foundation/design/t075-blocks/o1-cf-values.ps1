& {
  # ===== T075 O-1 블록 — Cloudflare 값 5(Access AUD 셋 · 서비스 토큰 Client ID 둘) 확보(쓰기 0) · 파일로만 실행 =====
  # 목적(설계 D11 · CD-8 · CD-21 · L2): GP-2 · GP-3 overlay ConfigMap 의 ACCESS_AUD_M2M(identity-m2m-<env>) · ACCESS_AUD_ADMIN(admin) · ACCESS_EXPECTED_CN(web-bff-<env> 의 Client ID)에 넣을 값을
  #       tofu 출력에서 읽는다. 출력 값은 비밀이 아니다(공개 저장소의 overlay 에 들어간다 · ia:16 · ha:41) — 운영자가 컨트롤러에 붙이고 build-notes 에 적는다.
  # 읽는 것: ① AUD 셋 = tofu -chdir=<저장소>\infra\cloudflare output -json access_app_aud(비민감 출력)에서만 — 키 identity-m2m-dev · identity-m2m-prod · admin
  #          ② Client ID 둘 = output -json service_tokens(sensitive — 토큰 넷의 client_secret 이 함께 든다)에서 web-bff-dev · web-bff-prod 의 .client_id 만 — 속성 이름을 단언한다
  #             (객체에 client_id 문자열이 있다). 나머지(client_secret · tester 둘)는 변수 밖으로 내지 않고 바로 버린다
  # 키별 정규식(-cmatch · \A…\z): AUD = ^[0-9a-f]{64}$ · Client ID = ^[0-9a-f]{32}\.access$ — 공통 정규식을 쓰지 않는다(service_tokens 의 client_secret 도 64 hex 꼴이라 속성을 잘못 고르면
  #   비밀이 「형식 PASS」로 보인다 — 75A-8 · 75B-6). 출력: PASS 일 때만 `<키> PASS <값>` · FAIL 이면 `<키> FAIL(사유 분류)`만(값 없음)
  #   T075 보정 2026-11-19(L4 d5 실측): client_secret 실물은 54자 [A-Za-z0-9_-] 다(research.md R12 :4256 — 2026-08 이후 신규 발급 = cfast_[40자][8자 checksum] · 위 괄호의 64 hex 는
  #   옛 꼴이다 — Cloudflare 에서는 아직 유효). 키별 정규식은 그대로 둔다(어느 꼴이든 속성 혼동을 막는다 — 하네스 O1-02(54자 꼴) · O1-02b(64 hex 꼴))
  # 사전: ① 창 시작 체크리스트(vault-unseal.md §0 — 모듈 로깅 정책 0: 켜져 있으면 service_tokens JSON 원문이 ConvertFrom-Json 의 이벤트 4103 에 남는다 · 블록도 첫 검사에서 본다)
  #   ② 이 창에서 tofu 상태를 읽을 수 있다(운영자 자격 — infra/cloudflare 백엔드) · 에이전트는 이 블록을 실행하지 않는다
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>'(파일로만 — 저장소 경로를 파일 위치에서 찾는다) · 정지점 없음(입력 0 · 쓰기 0)
  # 원칙: client_secret 은 화면 · argv · 파일 · 클립보드에 0 · 출력은 Write-Host 뿐 · finally 가 변수 · $Error(이 실행분)를 정리한다
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t075-blocks\harness.ps1 → PASS n / n
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $res = [ordered]@{}
  $done = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $firstErr = { param($lines)
      $c = @(@($lines) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $pick = '(오류 출력 없음)'
      if ($c.Count -gt 0) { $pick = $c[0] }
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
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 읽지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 service_tokens 출력 원문(client_secret)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 읽지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 service_tokens 출력 원문(client_secret)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 읽지 않았다)" }
    # tofu 동작을 바꾸는 환경 변수(T075 보정 2026-11-17 · 리뷰 KB-8): TF_LOG*(로그 — sensitive 출력 원문이 화면 · 파일에 남을 수 있다) · TF_CLI_ARGS*(숨은 인자) · TF_WORKSPACE · TF_DATA_DIR(다른 상태)가
    #   있으면 tofu 를 부르기 전에 멈춘다 — 이름만 낸다(값은 내지 않는다)
    $tfBad = @(Get-ChildItem Env: | Where-Object { $_.Name -like 'TF_LOG*' -or $_.Name -like 'TF_CLI_ARGS*' -or @('TF_WORKSPACE', 'TF_DATA_DIR') -contains $_.Name } | ForEach-Object { $_.Name })
    if ($tfBad.Count -gt 0) { throw "이 창에 tofu 동작을 바꾸는 환경 변수가 있다: $($tfBad -join ', ') — 값은 내지 않는다. Remove-Item Env:<이름> 뒤 새 창에서 다시(아무것도 읽지 않았다)" }
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로>) — 저장소 경로를 파일 위치에서 찾는다(아무것도 읽지 않았다)' }
    $infra = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\infra\cloudflare'))
    if (-not (Test-Path -LiteralPath (Join-Path $infra 'outputs.tf'))) { throw "infra/cloudflare 를 찾지 못했다($infra) — 블록 파일이 저장소 밖에 있다(아무것도 읽지 않았다)" }
    $tcs = @(Get-Command tofu -ErrorAction SilentlyContinue)
    if ($tcs.Count -eq 0) { throw 'tofu CLI 를 찾을 수 없다(PATH) — 아무것도 읽지 않았다' }
    # 실행 파일 경로(라운드 2 · 리뷰 KB2-2): 어느 tofu 가 sensitive 출력을 읽는지 본다 — 사용자 홈은 ~ 로 줄인다(기록 칸에 사용자 이름을 남기지 않는다)
    $tsrc = [string]$tcs[0].Source
    if ([string]::IsNullOrEmpty($tsrc)) { $tsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $tsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $tsrc = '~' + $tsrc.Substring($HOME.Length) }
    $tv = @(tofu version 2>$null)
    $global:LASTEXITCODE = 0
    $tvl = '(버전 출력 없음)'
    if ($tv.Count -gt 0) { $tvl = ([string]$tv[0]).Trim() -replace '\p{Cc}', '?' }
    Write-Host "INFO tofu CLI: $tvl · $([string]$tcs[0].CommandType) $tsrc — infra/cloudflare 출력 읽기 전용(쓰기 0)"
    # ---------- ① AUD 셋(비민감 출력) ----------
    $o = @(tofu "-chdir=$infra" output -json access_app_aud 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $aerr = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $aud = $null
    if ($rc -eq 0) { $aud = & $parseJson @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) }
    $o = $null
    foreach ($k in @('identity-m2m-dev', 'identity-m2m-prod', 'admin')) {
      $v = & $prop $aud $k
      if ($rc -ne 0) { $res["aud $k"] = [pscustomobject]@{ ok = $false; v = ''; why = "tofu output exit=$rc · $(& $firstErr $aerr)" } }
      elseif ($null -eq $aud) { $res["aud $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '출력 JSON 을 해석하지 못했다' } }
      elseif ($null -eq $v) { $res["aud $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '키 없음' } }
      elseif (($v -is [string]) -and ($v -cmatch '\A[0-9a-f]{64}\z')) { $res["aud $k"] = [pscustomobject]@{ ok = $true; v = $v; why = '' } }
      else { $res["aud $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '꼴이 ^[0-9a-f]{64}$ 가 아니다(값 미출력)' } } }
    $aud = $null; $v = $null
    # ---------- ② Client ID 둘(sensitive 출력 — client_id 만 꺼내고 나머지는 버린다) ----------
    $o = @(tofu "-chdir=$infra" output -json service_tokens 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $j = $null
    if ($rc -eq 0) { $j = & $parseJson $o }
    $o = $null
    foreach ($k in @('web-bff-dev', 'web-bff-prod')) {
      $t = & $prop $j $k
      $v = & $prop $t 'client_id'
      if ($rc -ne 0) { $res["cn $k"] = [pscustomobject]@{ ok = $false; v = ''; why = "tofu output exit=$rc(오류 문구는 내지 않는다 — sensitive 출력)" } }
      elseif ($null -eq $j) { $res["cn $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '출력 JSON 을 해석하지 못했다' } }
      elseif ($null -eq $t) { $res["cn $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '토큰 키 없음' } }
      elseif ($v -isnot [string]) { $res["cn $k"] = [pscustomobject]@{ ok = $false; v = ''; why = 'client_id 속성이 없거나 문자열이 아니다' } }
      elseif ($v -cmatch '\A[0-9a-f]{32}\.access\z') { $res["cn $k"] = [pscustomobject]@{ ok = $true; v = $v; why = '' } }
      else { $res["cn $k"] = [pscustomobject]@{ ok = $false; v = ''; why = '꼴이 ^[0-9a-f]{32}\.access$ 가 아니다(값 미출력)' } } }
    $t = $null; $v = $null; $j = $null
    $done = $true }
  finally {
    Remove-Variable o, j, t, v, aud -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T075 O-1 Cloudflare 값(비밀 아님 — PASS 줄만 값이 있다 · 컨트롤러에게 붙이고 build-notes 에 적는다) ---'
    foreach ($k in $res.Keys) {
      if ($res[$k].ok) { Write-Host "$k PASS $($res[$k].v)" } else { Write-Host "$k FAIL($($res[$k].why))" } }
    $nPass = @($res.Values | Where-Object { $_.ok }).Count
    if (-not $done) { Write-Host 'o1=판정 불가(중단 — 위 오류)' }
    elseif ($nPass -eq 5 -and $res.Count -eq 5) { Write-Host 'o1=PASS 5/5' }
    else { Write-Host "o1=FAIL $nPass/5" }
  }
}
