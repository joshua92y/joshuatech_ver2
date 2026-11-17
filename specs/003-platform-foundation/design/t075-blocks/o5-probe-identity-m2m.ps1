& {
  # ===== T075 O-5 블록 — identity-m2m-<env> 탐침(쓰기 0) · a = 배포 전 404 · b = 배포 뒤 /health 게이트 · c = /session/check 양성 + UD-10 400 표본 · 파일로만 실행 =====
  # 목적(설계 D16 · D18 · CD-4 · CD-7 · VR-12 · L4 · L11 · L15):
  #   a(배포 전 · L4): 헤더 없는 GET /health 의 Access 응답 코드를 기록한다(합격선 없음 — C11) · tester-m2m 자격의 GET /health → Traefik 404 여야 한다(라우터가 없다 = 토큰 · DNS · AOP 정상)
  #   b(배포 뒤 게이트 · dev L11 · prod L15): tester-m2m 자격의 GET /health → 200 · status ok · checks = {db, dragonfly, kafka_producer} 모두 ok · git_sha = 배포 이미지의 revision(입력) ·
  #     응답 헤더 x-request-id 있음 — /health 는 pod 에서 Access 단계 면제라 ACCESS_AUD_M2M · ACCESS_EXPECTED_CN · ACCESS_TEAM_DOMAIN 은 증명하지 않는다(75A-4)
  #   c(양성 탐침): web-bff-<env> 자격의 GET /session/check?sub=<고정 가짜 uuid>&iat=<지금 epoch 초>&sid=<고정 가짜 64 hex> → 200 · 본문 정확히 {"active": true}(nbf 없음) ·
  #     Cache-Control 에 no-store — Access 전용 경로라 1단계(aud · common_name)만 거친다 = AUD_M2M · CN = Client ID · 팀 도메인 · B2 ACL 아래 Dragonfly 읽기를 한 번에 증명한다.
  #     같은 자격 · 같은 가짜 sub · sid 로 iat=x 인 요청 하나를 더 보낸다(UD-10 표본 — 400 validation_error) — 그 UTC 시각과 x-request-id 를 낸다: 컨트롤러가 Traefik 액세스 로그(400–599 만 남는다)에서
  #     그 줄의 요청 경로에 쿼리(sub · sid 가짜 값)가 실리는지 기록한다
  # 자격(비밀): tofu -chdir=<저장소>\infra\cloudflare output -json service_tokens 에서 그 토큰의 client_id · client_secret 만 변수로 받고(나머지는 버린다) curl 의 stdin 헤더(-H @-)로만 보낸다 —
  #   argv · 화면 · 파일 · 클립보드 0. 응답은 상태 코드 · 허용 목록 헤더(x-request-id · Cache-Control — curl -w %header{…})와 본문 필드만 읽는다: 응답 헤더를 통째로 읽거나 내지 않는다 —
  #   Access 가 서비스 토큰 응답에 실을 수 있는 Set-Cookie: CF_Authorization(앱 범위 JWT · 24h)은 자격이다(-i · -D · -v · -c 를 쓰지 않는다 · VR-12). curl 7.84 이상(%header) 필요.
  # 사전: ① 창 시작 체크리스트(모듈 로깅 정책 0 — service_tokens 원문이 ConvertFrom-Json 을 지난다) ② tofu 상태를 읽을 수 있는 창(운영자) ③ b 의 기대 git_sha = 그 env 에 배포된
  #   이미지 digest 를 만든 모노레포 main 커밋 40자(소문자 hex) — 컨트롤러가 build-notes 「T074 결과」 · publish-pod 요약(dev bump PR 본문)에서 찾아 준다(지금 dev = 9fd9f2c7… · 리뷰 KA-12)
  # 환경(T075 보정 2026-11-17 · 리뷰 KB-1 · KB-8): curl 은 첫 인자 -q 로 .curlrc 를 읽지 않는다 · CURL_CA_BUNDLE · SSLKEYLOGFILE · *_PROXY · TF_LOG* · TF_CLI_ARGS* · TF_WORKSPACE · TF_DATA_DIR 가 있으면 멈춘다
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>' · 정지점: ① env(dev · prod) ② 모드(a · b · c) ③ (b 만) 기대 git_sha — 모두 가려진 입력 · 그 외 입력 = 중단
  # 원칙: 자격 값 · 쿠키는 어디에도 0 · 출력은 판정 줄과 비밀 아닌 응답 필드뿐 · 판정 불가는 FAIL · finally 가 자격 변수 · $Error(이 실행분)를 정리한다
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t075-blocks\harness.ps1 → PASS n / n
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $envSel = ''
  $mode = ''
  $res = [ordered]@{}
  $info = [System.Collections.Generic.List[string]]::new()
  $done = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $pick = { param($prompt, $choices)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host $prompt -MaskInput
      foreach ($c in @($choices)) { if (& $eq $ans $c) { return $c } }
      throw "정지점에서 중단: $prompt — 허용 입력이 아니다(아무것도 보내지 않았다)" }
    $readSha = {
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host '기대 git_sha — 배포 이미지 digest 를 만든 main 커밋 40자 소문자 hex(컨트롤러가 준 값 · 입력은 가려진다)' -MaskInput
      if ($ans -cnotmatch '\A[0-9a-f]{40}\z') { throw '정지점에서 중단: git_sha 가 40자 소문자 hex 가 아니다(아무것도 보내지 않았다)' }
      $ans }
    $parseJson = { param($lines)
      $t = (@($lines) | ForEach-Object { [string]$_ }) -join "`n"
      if ([string]::IsNullOrWhiteSpace($t)) { return $null }
      try { $t | ConvertFrom-Json -DateKind String } catch { $null } }
    $prop = { param($o, $n)
      if ($null -eq $o) { return $null }
      $p = $o.PSObject.Properties[$n]
      if ($null -eq $p) { return $null }
      $p.Value }
    $names = { param($o) if ($null -eq $o) { @() } else { @($o.PSObject.Properties | ForEach-Object { $_.Name }) } }
    $check = { param($name, $ok, $why) if ($ok) { $res[$name] = 'PASS' } else { $res[$name] = "FAIL($why)" } }
    # GET 1회: $hdr = 헤더 줄 배열(자격 — stdin 으로만) 또는 $null(헤더 없음). 돌려주는 것 = 상태 코드 · x-request-id · Cache-Control · 본문 줄 · curl 종료 코드 · 보낸 시각(UTC)
    $get = { param($url, $hdr)
      $wfmt = '\nT075-W code=%{http_code} xrid=%header{x-request-id} cc=%header{cache-control}\n'
      $at = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
      if ($null -eq $hdr) { $out = @(curl.exe -q -sS --max-time 20 -w $wfmt $url 2>&1) }
      else { $out = @($hdr | curl.exe -q -sS --max-time 20 -H '@-' -w $wfmt $url 2>&1) }
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $lines = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
      $errl = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $out = $null
      $iw = -1
      for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].StartsWith('T075-W ', [StringComparison]::Ordinal)) { $iw = $i; break } }
      $m = $null
      if ($iw -ge 0) { $m = [regex]::Match($lines[$iw], '\AT075-W code=([0-9]{3}) xrid=(\S*) cc=(.*)\z') }
      if ($null -eq $m -or -not $m.Success) {
        $e1 = '(오류 출력 없음)'; if ($errl.Count -gt 0) { $e1 = $errl[0] }
        if ($e1.Length -gt 160) { $e1 = $e1.Substring(0, 160) + '…' }
        return [pscustomobject]@{ ok = $false; code = ''; xrid = ''; cc = ''; body = @(); rc = $rc; at = $at; why = "curl exit=$rc · $e1" } }
      $body = @(); if ($iw -gt 0) { $body = @($lines[0..($iw - 1)]) }
      [pscustomobject]@{ ok = $true; code = $m.Groups[1].Value; xrid = $m.Groups[2].Value; cc = $m.Groups[3].Value.Trim(); body = $body; rc = $rc; at = $at; why = '' } }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 보내지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 service_tokens 출력 원문(client_secret)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 보내지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 service_tokens 출력 원문(client_secret)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 보내지 않았다)" }
    # curl · tofu 동작을 바꾸는 환경 변수(T075 보정 2026-11-17 · 리뷰 KB-1 · KB-8): CURL_CA_BUNDLE(신뢰 앵커 교체) · SSLKEYLOGFILE(TLS 키 기록 — 자격이 든 요청을 풀 수 있다) ·
    #   HTTP_PROXY · HTTPS_PROXY · ALL_PROXY(대소문자 무관 — 자격 헤더가 프록시를 지난다) · TF_LOG* · TF_CLI_ARGS* · TF_WORKSPACE · TF_DATA_DIR 가 있으면 읽기 전에 멈춘다 — 이름만 낸다.
    #   .curlrc 는 curl 첫 인자 -q 로 읽지 않는다(아래 $get · 버전 확인 — 실측: -q 없으면 사용자 curlrc 의 --trace-ascii · --cookie-jar 가 자격 · 쿠키를 파일에 남긴다)
    #   (라운드 2 · 리뷰 KB2-2) SSL_CERT_FILE · SSL_CERT_DIR 도 신뢰 앵커를 바꾼다(curl --libcurl 실측 — CAINFO · CAPATH 로 쓰인다) — 같은 목록에서 멈춘다(대소문자 무관)
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR') -contains $_.Name -or $_.Name -like 'TF_LOG*' -or $_.Name -like 'TF_CLI_ARGS*' } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 curl · tofu 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. Remove-Item Env:<이름> 뒤 새 창에서 다시(아무것도 보내지 않았다)" }
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로>) — 저장소 경로를 파일 위치에서 찾는다(아무것도 보내지 않았다)' }
    $infra = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\infra\cloudflare'))
    if (-not (Test-Path -LiteralPath (Join-Path $infra 'outputs.tf'))) { throw "infra/cloudflare 를 찾지 못했다($infra) — 아무것도 보내지 않았다" }
    $tcs = @(Get-Command tofu -ErrorAction SilentlyContinue)
    if ($tcs.Count -eq 0) { throw 'tofu CLI 를 찾을 수 없다(PATH) — 아무것도 보내지 않았다' }
    $ccs = @(Get-Command curl.exe -ErrorAction SilentlyContinue)
    if ($ccs.Count -eq 0) { throw 'curl.exe 를 찾을 수 없다(PATH) — 아무것도 보내지 않았다' }
    # 실행 파일 경로(라운드 2 · 리뷰 KB2-2): 운영자가 자격을 넘기기 전에 어느 tofu · curl 이 불리는지 본다 — 사용자 홈은 ~ 로 줄인다(기록 칸에 사용자 이름을 남기지 않는다)
    $tilde = { param($s)
      $s = [string]$s
      if ([string]::IsNullOrEmpty($s)) { return '(경로 없음)' }
      if (-not [string]::IsNullOrEmpty($HOME) -and $s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { return '~' + $s.Substring($HOME.Length) }
      $s }
    $tsrc = & $tilde $tcs[0].Source
    $csrc = & $tilde $ccs[0].Source
    $cv = @(curl.exe -q --version 2>$null)
    $global:LASTEXITCODE = 0
    $cm = $null; if ($cv.Count -gt 0) { $cm = [regex]::Match([string]$cv[0], '\Acurl ([0-9]+)\.([0-9]+)') }
    if ($null -eq $cm -or -not $cm.Success -or [int]$cm.Groups[1].Value -lt 7 -or ([int]$cm.Groups[1].Value -eq 7 -and [int]$cm.Groups[2].Value -lt 84)) { throw 'curl 7.84 이상이 필요하다(-w %header{…}) — 아무것도 보내지 않았다' }
    Write-Host "INFO curl $($cm.Groups[1].Value).$($cm.Groups[2].Value) · $([string]$ccs[0].CommandType) $csrc · tofu $([string]$tcs[0].CommandType) $tsrc — 쓰기 0 · 자격은 stdin 헤더로만"
    $envSel = [string](& $pick 'env — dev 또는 prod 를 그대로 입력(입력은 가려진다 · 그 외 = 중단)' @('dev', 'prod'))
    $mode = [string](& $pick '모드 — a(배포 전 404) · b(배포 뒤 /health 게이트) · c(/session/check 양성 + UD-10 400 표본) 중 하나(입력은 가려진다)' @('a', 'b', 'c'))
    $shaWant = ''
    if (& $eq $mode 'b') { $shaWant = [string](& $readSha) }
    $tokName = 'tester-m2m'
    if (& $eq $mode 'c') { $tokName = "web-bff-$envSel" }
    Write-Host "OK   env = $envSel · 모드 = $mode · 자격 = $tokName(값 미출력)$(if ($shaWant) { ' · 기대 git_sha = ' + $shaWant })"
    # 자격(sensitive 출력 — 그 토큰의 client_id · client_secret 만 꺼내고 나머지는 버린다)
    $o = @(tofu "-chdir=$infra" output -json service_tokens 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $j = $null
    if ($rc -eq 0) { $j = & $parseJson $o }
    $o = $null
    $t = & $prop $j $tokName
    $j = $null
    $cid = & $prop $t 'client_id'
    $csec = & $prop $t 'client_secret'
    $t = $null
    if ($rc -ne 0 -or $cid -isnot [string] -or $csec -isnot [string] -or $cid -cnotmatch '\A[0-9a-f]{32}\.access\z' -or $csec -cnotmatch '\A[0-9a-f]{64}\z') {
      $cid = $null; $csec = $null
      throw "자격을 꺼내지 못했다($tokName — tofu output exit=$rc · client_id ^[0-9a-f]{32}\.access$ · client_secret ^[0-9a-f]{64}$ 꼴 아님 — 값 미출력) · 아무것도 보내지 않았다" }
    $hdr = @("CF-Access-Client-Id: $cid", "CF-Access-Client-Secret: $csec")
    $cid = $null; $csec = $null
    $base = "https://identity-m2m-$envSel.joshuatech.dev"
    if (& $eq $mode 'a') {
      $r0 = & $get "$base/health" $null
      if ($r0.ok) { $info.Add("o5a $envSel 헤더 없음 GET /health → $($r0.code)(기록 — 합격선 없음 · C11)") } else { $info.Add("o5a $envSel 헤더 없음 GET /health → 응답 없음($($r0.why))") }
      $r = & $get "$base/health" $hdr
      $why = "응답 $($r.code)"; if (-not $r.ok) { $why = $r.why }
      & $check "o5a $envSel tester-m2m GET /health → 404(Traefik — 라우터 없음 · 토큰 · DNS · AOP 정상)" ($r.ok -and (& $eq $r.code '404')) $why }
    elseif (& $eq $mode 'b') {
      $r = & $get "$base/health" $hdr
      $b = $null; if ($r.ok) { $b = & $parseJson $r.body }
      $why = "응답 $($r.code)"; if (-not $r.ok) { $why = $r.why }
      & $check "o5b $envSel GET /health → 200" ($r.ok -and (& $eq $r.code '200')) $why
      & $check "o5b $envSel 본문 status = ok" (& $eq (& $prop $b 'status') 'ok') "status = $([string](& $prop $b 'status'))"
      $ck = & $prop $b 'checks'
      $cn = @(& $names $ck)
      & $check "o5b $envSel 본문 checks = {db, dragonfly, kafka_producer}(정확히)" ($cn.Count -eq 3 -and @(@('db', 'dragonfly', 'kafka_producer') | Where-Object { $cn -ccontains $_ }).Count -eq 3) "키 $($cn.Count)개($($cn -join ','))"
      foreach ($n in @('db', 'dragonfly', 'kafka_producer')) { & $check "o5b $envSel checks.$n.status = ok" (& $eq (& $prop (& $prop $ck $n) 'status') 'ok') "status = $([string](& $prop (& $prop $ck $n) 'status'))" }
      $gs = [string](& $prop $b 'git_sha')
      & $check "o5b $envSel 본문 git_sha = 배포 이미지 revision(입력)" (& $eq $gs $shaWant) "git_sha = $(if ($gs -cmatch '\A[0-9a-f]{7,64}\z') { $gs } else { '(꼴 밖)' })"
      & $check "o5b $envSel 응답 헤더 x-request-id 있음" ($r.ok -and $r.xrid.Length -gt 0) 'x-request-id 없음'
      if ($r.ok) { $info.Add("o5b $envSel 기록: version = $([string](& $prop $b 'version')) · Cache-Control = $(if ($r.cc) { $r.cc } else { '(없음)' }) · x-request-id = $($r.xrid)") }
      $b = $null }
    else {
      $sub = '7075c0de-7075-4075-8075-7075c0de7075'
      $sid = '7075c0de' * 8
      $iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
      $r = & $get "$base/session/check?sub=$sub&iat=$iat&sid=$sid" $hdr
      $b = $null; if ($r.ok) { $b = & $parseJson $r.body }
      $why = "응답 $($r.code)"; if (-not $r.ok) { $why = $r.why }
      & $check "o5c $envSel GET /session/check(web-bff-$envSel · 가짜 sub · sid · iat=지금) → 200" ($r.ok -and (& $eq $r.code '200')) $why
      $bn = @(& $names $b)
      & $check "o5c $envSel 본문 = {`"active`": true}(nbf 없음)" ($bn.Count -eq 1 -and (& $eq $bn[0] 'active') -and ((& $prop $b 'active') -is [bool]) -and (& $prop $b 'active')) "키 $($bn.Count)개($($bn -join ',')) · active = $([string](& $prop $b 'active'))"
      $ccOk = $r.ok -and @(@($r.cc.Split(',')) | Where-Object { [string]::Equals($_.Trim(), 'no-store', [StringComparison]::OrdinalIgnoreCase) }).Count -ge 1
      & $check "o5c $envSel 응답 헤더 Cache-Control 에 no-store" $ccOk "Cache-Control = $(if ($r.ok -and $r.cc) { $r.cc } else { '(없음)' })"
      $b = $null
      $r2 = & $get "$base/session/check?sub=$sub&iat=x&sid=$sid" $hdr
      $b2 = $null; if ($r2.ok) { $b2 = & $parseJson $r2.body }
      $why = "응답 $($r2.code)"; if (-not $r2.ok) { $why = $r2.why }
      & $check "o5c $envSel UD-10 표본 GET /session/check?…&iat=x → 400" ($r2.ok -and (& $eq $r2.code '400')) $why
      & $check "o5c $envSel UD-10 표본 본문 type = https://joshuatech.dev/problems/validation-error" (& $eq (& $prop $b2 'type') 'https://joshuatech.dev/problems/validation-error') "type = $([string](& $prop $b2 'type'))"
      $info.Add("o5c $envSel UD-10 표본: 보낸 시각(UTC) $($r2.at) · x-request-id = $(if ($r2.ok -and $r2.xrid) { $r2.xrid } else { '(없음)' }) · 경로 /session/check · 가짜 sub = $sub · 가짜 sid = 7075c0de×8 — 컨트롤러가 Traefik 액세스 로그(kube-system)에서 그 400 줄의 요청 경로에 쿼리가 실리는지 본다")
      $b2 = $null }
    $hdr = $null
    $done = $true }
  finally {
    Remove-Variable hdr, cid, csec, o, j, t, r, r0, r2, b, b2 -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T075 O-5 탐침 결과(env=$(if ($envSel) { $envSel } else { '선택 전' }) · 모드=$(if ($mode) { $mode } else { '선택 전' }) · 자격 · 쿠키 없음 — 런북 bootstrap.md §3 T075 기록 칸에 그대로 기록) ---"
    # 응답에서 온 글자(코드 · 헤더 · 본문 필드 · curl 오류)는 제어 문자를 '?' 로 바꿔 낸다(T075 보정 2026-11-17 · 리뷰 KB-7 — 터미널 제어열 · OSC 52 주입 방어)
    foreach ($k in $res.Keys) {
      if (([string]$res[$k]).StartsWith('PASS', [StringComparison]::Ordinal)) { Write-Host "PASS $k" } else { Write-Host "FAIL $k — $(([string]$res[$k]) -replace '\p{Cc}', '?')" } }
    foreach ($l in $info) { Write-Host "INFO $(([string]$l) -replace '\p{Cc}', '?')" }
    $nPass = @($res.Values | Where-Object { ([string]$_).StartsWith('PASS', [StringComparison]::Ordinal) }).Count
    $tag = "o5$mode $envSel"
    if (-not $done) { Write-Host "$(if ($mode) { $tag } else { 'o5' })=판정 불가(중단 — 위 오류)" }
    elseif ($nPass -eq $res.Count -and $res.Count -gt 0) { Write-Host "$tag=PASS $nPass/$($res.Count)" }
    else { Write-Host "$tag=FAIL $nPass/$($res.Count)" }
  }
}
