param([string]$Since = '', [string]$Nonce = '')
& {
  # ===== T076 C-8 블록 — O-8 요청의 Traefik 액세스 로그 · identity-admin web 로그 대조(tester 2차 · 비밀 0 · 읽기만 · 쓰기 0) · 파일로만 실행 =====
  # 설계 t076-design.md D5 · D3(tester 블록 계약) · VD-T076-2 · 3 · 4 · 5 — m2m 404 넷이 Traefik 라우터 없음(OriginStatus 0 · RouterName 없음)에서 났고 pod 에 닿지 않았음을 로그로 보인다
  # 실행(tester · Git Bash · Bash 도구 timeout 600000): chcp.com 65001 >/dev/null; pwsh -NoProfile -File '<이 파일의 절대 경로>' -Since <O-8 의 INFO o8 start — UTC yyyy-MM-ddTHH:mm:ssZ> -Nonce <O-8 의 nonce>; echo "exit=$?"
  #   판정은 끝 줄과 종료 코드 · 한글 줄은 증거. 입력은 param 뿐(Read-Host 0) — 꼴이 아니거나 다른 인자가 있으면 kubectl 을 부르지 않고 멈춘다 · 끝 줄 c8=PASS 10/10 또는 c8=FAIL k/10 · 종료 코드 0 = 전부 PASS 일 때만
  # 사전: agent-view kubeconfig ~\.kube\agent-view.yaml(8h) · O-8 실행 뒤 Traefik 재시작 없음(UD-13 정비 · SUC 창 전 — 재시작하면 액세스 로그가 사라진다)
  # Traefik(infra/bootstrap/traefik-config.yaml — JSON · 400–599 만 · 헤더 keep = CF-Connecting-IP · CF-Ray · User-Agent): kubectl -n kube-system logs deploy/traefik --since-time=<Since>
  #   (Deployment 복제가 1 이 아니면 멈춘다) → RequestHost ∈ {identity-m2m-dev · -prod.joshuatech.dev} 이고 RequestPath 가 ?t076=<Nonce> 로 끝나는 줄만 → 투영 필드만 낸다:
  #   StartUTC · RequestHost · RequestMethod · RequestPath · DownstreamStatus · OriginStatus · RouterName 유무(값 아님) · request_Cf-Ray. 운영자 공인 IP(Cf-Connecting-Ip) · UA ·
  #   ClientHost · ClientAddr · ClientUsername · ServiceAddr 는 어디에도 내지 않는다(B-08 — 투영 밖은 읽지도 옮기지도 않는다)
  # 판정(env 마다 다섯 = 10): b–e /admin/ · /webhooks/authentik · /healthz · /ready 각각 Traefik 줄 정확히 1 · DownstreamStatus 404 · OriginStatus 0 · RouterName 없음(VD-T076-2) +
  #   pod: kubectl -n jt-<env> logs deploy/identity-admin -c web --since-time=<Since> 에서 request_id(상류 X-Request-ID — O-8 이 <Nonce>-<env>-<id> 로 보낸다)가 404 네 경로의 것인
  #   줄 0 · 대조 키 줄(<Nonce>-<env>-health)은 있어야 한다(pod 로그 request 필드에는 쿼리가 없어 nonce 쿼리로는 pod 줄을 고를 수 없다 — 대조 키가 pod 에 닿지 않으면 0줄 판정이
  #   비어 있으므로 판정 불가 = FAIL · VD-T076-4). INFO: /apix · /sessionsX 403 줄(RouterName 있음 · OriginStatus 403 = 글자 접두 → pod · VD-L9) · pod 의 request_id · 요청 · 코드
  # 원칙: 출력은 투영 필드 · 판정 줄뿐 · 로그에서 온 글자는 제어 문자 → ? · 160자 · 판정 불가 = FAIL · 출력은 Write-Host 뿐 · 원시 로그 줄을 내지 않는다
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-tester.ps1 → 전부 PASS
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $PSNativeCommandArgumentPassing = 'Standard'
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $res = [ordered]@{}
  $info = [System.Collections.Generic.List[string]]::new()
  $done = $false
  $stopWhy = ''
  $nPass = 0
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $parseJson = { param($lines)
      $t = (@($lines) | ForEach-Object { [string]$_ }) -join "`n"
      if ([string]::IsNullOrWhiteSpace($t)) { return $null }
      try { $t | ConvertFrom-Json -DateKind String } catch { $null } }
    $prop = { param($o, $n)
      if ($null -eq $o) { return $null }
      $p = $o.PSObject.Properties[$n]
      if ($null -eq $p) { return $null }
      $p.Value }
    $check = { param($name, $ok, $why) if ($ok) { $res[$name] = 'PASS' } else { $res[$name] = "FAIL($why)" } }
    $clean = { param($s) $c = ([string]$s) -replace '\p{Cc}', '?'; if ($c.Length -gt 160) { $c = $c.Substring(0, 160) + '…' }; $c }
    $tilde = { param($s)
      $s = [string]$s
      if ([string]::IsNullOrEmpty($s)) { return '(경로 없음)' }
      if (-not [string]::IsNullOrEmpty($HOME) -and $s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { return '~' + $s.Substring($HOME.Length) }
      $s }
    $hide = { param($s) $t = [string]$s; if (-not [string]::IsNullOrEmpty($HOME)) { $t = [regex]::Replace($t, '(?i)' + [regex]::Escape($HOME), '~') }; $t }
    $proj = { param($m) "StartUTC=$(& $clean $m.start) · $(& $clean $m.method) $(& $clean $m.host)$(& $clean $m.path) · DownstreamStatus=$(& $clean $m.ds) · OriginStatus=$(if ($m.os) { & $clean $m.os } else { '(없음)' }) · RouterName $(if ($m.router) { '있음' } else { '없음' }) · request_Cf-Ray=$(if ($m.ray) { & $clean $m.ray } else { '(없음)' })" }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 부르지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 Traefik 액세스 로그 원문(운영자 공인 IP · UA)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 부르지 않았다)" }
    # 모듈 로깅 실효 상태(T075 블록 규약 그대로 — 리뷰 KB-2 · KB2-1): 레지스트리 밖(powershell.config.json · -SettingsFile)으로 켜진 경우 — Core 스냅인 · Utility · Security · Management 의
    #   LogPipelineExecutionDetails(이 프로세스의 실효 값) · 설정 파일 두 곳은 값과 무관하게 텍스트 판정(ModuleLogging 대소문자 무관 · 역슬래시-u) · 확인 못 하면 멈춘다
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 Traefik 액세스 로그 원문(운영자 공인 IP · UA)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 부르지 않았다)" }
    # 입력(D3 · A-1): param 뿐 — 파일 실행 · 다른 인자 0 · -Since(UTC ISO 8601 · 지금 + 5분 이전 · 24시간 안) · -Nonce(O-8 꼴)를 kubectl 호출 전에 판정한다
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -Since <UTC> -Nonce <nonce>) — 아무것도 부르지 않았다' }
    if (@($script:args).Count -gt 0) { throw "입력은 -Since · -Nonce 둘뿐이다 — 그 밖의 인자 $(@($script:args).Count)개(값 미출력) · 아무것도 부르지 않았다" }
    if ($Since -cnotmatch '\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z') { throw '입력 -Since 가 UTC ISO 8601(yyyy-MM-ddTHH:mm:ssZ — O-8 의 start) 꼴이 아니다(아무것도 부르지 않았다)' }
    $sinceT = $null
    try { $sinceT = [DateTimeOffset]::ParseExact($Since, "yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal) } catch { $sinceT = $null }
    $nowT = [DateTimeOffset]::UtcNow
    if ($null -eq $sinceT -or $sinceT -gt $nowT.AddMinutes(5) -or $sinceT -lt $nowT.AddHours(-24)) { throw '입력 -Since 가 날짜로 읽히지 않거나 범위 밖이다(지금 + 5분 이전 · 24시간 안 — O-8 의 start 를 그대로) · 아무것도 부르지 않았다' }
    if ($Nonce -cnotmatch '\At076-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}\z') { throw '입력 -Nonce 가 O-8 의 nonce 꼴(t076-<yyyyMMddTHHmmssZ>-<6 hex>)이 아니다(아무것도 부르지 않았다)' }
    # 환경 변수(T075 KB-1): kubectl 도 HTTPS_PROXY · ALL_PROXY 를 따른다 — 신뢰 앵커 · 키 기록 · 프록시가 있으면 이름만 내고 멈춘다
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains $_.Name } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 kubectl 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. 그 변수가 없는 새 창에서 다시(아무것도 부르지 않았다)" }
    # 실행 파일(S-10): kubectl.exe 의 형식 필터 없는 Get-Command 첫 해석(= 호출 'kubectl.exe …' 가 실제로 부르는 것)이 실행 파일(Application)이 아니면 멈춘다(같은 이름 함수 · 별칭 · 프로필 정의 가림)
    $kcs = @(Get-Command kubectl.exe -ErrorAction SilentlyContinue)
    if ($kcs.Count -eq 0) { throw 'kubectl.exe 를 찾지 못했다(PATH · 함수 · 별칭 어디에도) — 아무것도 부르지 않았다' }
    $shadow = @(@($kcs[0]) | Where-Object { -not (& $eq ([string]$_.CommandType) 'Application') } | ForEach-Object { "$($_.Name) = $([string]$_.CommandType)" })
    if ($shadow.Count -gt 0) { throw "첫 해석이 실행 파일(Application)이 아니다: $(& $clean ($shadow -join ' · ')) — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 부르지 않았다)" }
    Write-Host "INFO kubectl $([string]$kcs[0].CommandType) $(& $tilde $kcs[0].Source) — 읽기만 · 투영 필드만 낸다"
    $kc = Join-Path $HOME '.kube\agent-view.yaml'
    if (-not (Test-Path -LiteralPath $kc)) { throw 'agent-view kubeconfig 가 없다(~\.kube\agent-view.yaml) — 컨트롤러 · 운영자에게 알린다(아무것도 부르지 않았다)' }
    $wo = @(kubectl.exe --kubeconfig $kc --request-timeout=20s auth whoami -o 'jsonpath={.status.userInfo.username}' 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $wl = @($wo | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ } | Where-Object { $_.Length -gt 0 })
    $we = @($wo | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    $wo = $null
    if ($rc -ne 0 -or $wl.Count -ne 1 -or -not (& $eq $wl[0] 'system:serviceaccount:kube-system:agent-view')) { throw "kubectl auth whoami 가 agent-view 가 아니다(exit=$rc · 사용자 $(if ($wl.Count) { & $clean ($wl -join ' ') } else { '(없음)' })$(if ($we.Count) { ' · ' + (& $clean (& $hide $we[0])) })) — agent-view kubeconfig 로만 실행한다(아무것도 판정하지 않았다)" }
    Write-Host 'OK   kubectl auth whoami = system:serviceaccount:kube-system:agent-view'
    # Traefik 복제 = 1(D5): deploy/traefik 로그가 요청 전부를 담는다는 전제 — spec · status 둘 다 1 이 아니면(롤아웃 중 포함) 멈춘다
    $to = @(kubectl.exe --kubeconfig $kc --request-timeout=30s -n kube-system get deployments.apps traefik -o json 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $tj = $null
    if ($rc -eq 0) { $tj = & $parseJson @($to | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) }
    $to = $null
    $tsr = [string](& $prop (& $prop $tj 'spec') 'replicas')
    $tst = [string](& $prop (& $prop $tj 'status') 'replicas')
    $tj = $null
    if (-not (& $eq $tsr '1') -or -not (& $eq $tst '1')) { throw "Traefik Deployment 복제가 1 이 아니다(exit=$rc · spec $(& $clean $tsr) · status $(& $clean $tst)) — deploy/traefik 로그가 요청 전부를 담는다고 볼 수 없다(판정하지 않았다)" }
    # Traefik 액세스 로그: nonce 쿼리가 든 줄만 JSON 으로 읽고 투영 필드만 남긴다(원시 줄은 곧바로 버린다)
    $tl = @(kubectl.exe --kubeconfig $kc --request-timeout=30s -n kube-system logs deploy/traefik "--since-time=$Since" 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $tle = @($tl | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    if ($rc -ne 0) { $tl = $null; throw "Traefik 로그를 읽지 못했다(exit=$rc$(if ($tle.Count) { ' · ' + (& $clean (& $hide $tle[0])) })) — 판정하지 않았다" }
    $needle = "?t076=$Nonce"
    $mine = [System.Collections.Generic.List[object]]::new()
    foreach ($l in @($tl | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) {
      $s = [string]$l
      if (-not $s.Contains($needle)) { continue }
      $o = & $parseJson $s
      $rh = [string](& $prop $o 'RequestHost')
      $rp = [string](& $prop $o 'RequestPath')
      if (-not (@('identity-m2m-dev.joshuatech.dev', 'identity-m2m-prod.joshuatech.dev') -ccontains $rh) -or -not $rp.EndsWith($needle, [StringComparison]::Ordinal)) { $o = $null; continue }
      $rn = & $prop $o 'RouterName'
      $ray = @($o.PSObject.Properties | Where-Object { [string]::Equals($_.Name, 'request_Cf-Ray', [StringComparison]::OrdinalIgnoreCase) } | ForEach-Object { [string]$_.Value })
      $mine.Add([pscustomobject]@{ start = [string](& $prop $o 'StartUTC'); host = $rh; method = [string](& $prop $o 'RequestMethod'); path = $rp; ds = [string](& $prop $o 'DownstreamStatus'); os = [string](& $prop $o 'OriginStatus'); router = ($null -ne $rn -and ([string]$rn).Length -gt 0); ray = $(if ($ray.Count -gt 0) { $ray[0] } else { '' }) })
      $o = $null }
    $tl = $null
    $s = $null
    Write-Host "OK   Traefik 로그(--since-time=$Since): nonce 줄 $($mine.Count)개 — 투영 필드만 남겼다"
    foreach ($ev in @('dev', 'prod')) {
      $h = "identity-m2m-$ev.joshuatech.dev"
      foreach ($x in @(@('b', '/admin/'), @('c', '/webhooks/authentik'), @('d', '/healthz'), @('e', '/ready'))) {
        $ls = @($mine | Where-Object { (& $eq $_.host $h) -and (& $eq $_.path ($x[1] + $needle)) })
        $bad = @()
        if ($ls.Count -ne 1) { $bad += "줄 $($ls.Count)개(정확히 1 이어야 한다)" }
        else {
          if (-not (& $eq $ls[0].ds '404')) { $bad += "DownstreamStatus $(& $clean $ls[0].ds)" }
          if (-not (& $eq $ls[0].os '0')) { $bad += "OriginStatus $(if ($ls[0].os) { & $clean $ls[0].os } else { '(없음)' })" }
          if ($ls[0].router) { $bad += 'RouterName 있음(라우터가 받았다)' } }
        & $check "c8 $ev $($x[0]) GET $($x[1]) — Traefik 줄 정확히 1 · DownstreamStatus 404 · OriginStatus 0 · RouterName 없음(VD-T076-2)" ($bad.Count -eq 0) ($bad -join ' · ') }
      foreach ($m in @($mine | Where-Object { & $eq $_.host $h })) {
        $tag = ''
        if ($m.path.StartsWith('/apix?', [StringComparison]::Ordinal) -or $m.path.StartsWith('/sessionsX?', [StringComparison]::Ordinal)) { $tag = ' — VD-L9(RouterName 있음 · OriginStatus 403 이면 글자 접두 → pod)' }
        $info.Add("c8 $ev traefik $(& $proj $m)$tag") }
      # pod(D5): 대조 키 = request_id(상류 X-Request-ID). 404 네 경로의 키(<Nonce>-<env>-admin · webhooks · healthz · ready) 줄 0 · health 키 줄 있음(대조 키가 pod 에 닿는다는 근거)
      $po = @(kubectl.exe --kubeconfig $kc --request-timeout=30s -n "jt-$ev" logs deploy/identity-admin -c web "--since-time=$Since" 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $poe = @($po | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $pre = "$Nonce-$ev-"
      $rows = [System.Collections.Generic.List[object]]::new()
      if ($rc -eq 0) {
        foreach ($l in @($po | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })) {
          $s = [string]$l
          if (-not $s.Contains($pre)) { continue }
          $o = & $parseJson $s
          $rid = [string](& $prop $o 'request_id')
          if (-not $rid.StartsWith($pre, [StringComparison]::Ordinal)) { $o = $null; continue }
          $rows.Add([pscustomobject]@{ rid = $rid; id = $rid.Substring($pre.Length); event = [string](& $prop $o 'event'); req = [string](& $prop $o 'request'); code = [string](& $prop $o 'code') })
          $o = $null } }
      $po = $null
      $s = $null
      $hrows = @($rows | Where-Object { & $eq $_.id 'health' })
      $brows = @($rows | Where-Object { @('admin', 'webhooks', 'healthz', 'ready') -ccontains $_.id })
      foreach ($w in @($rows | Where-Object { (& $eq $_.event 'request_finished') -or (& $eq $_.event 'request_failed') })) {
        $info.Add("c8 $ev pod request_id=$(& $clean $w.rid) · $(& $clean $w.req) · $(& $clean $w.code)($(& $clean $w.event))$(if (& $eq $w.id 'health') { ' — 상류 X-Request-ID 가 그대로(VD-T076-4)' })") }
      $bad = @()
      if ($rc -ne 0) { $bad += "pod 로그를 읽지 못했다(exit=$rc$(if ($poe.Count) { ' · ' + (& $clean (& $hide $poe[0])) }))" }
      else {
        if ($brows.Count -gt 0) { $bad += "404 네 경로의 pod 줄 $($brows.Count)개($(& $clean ((@($brows | ForEach-Object { $_.id }) | Sort-Object -Unique) -join ',')) — pod 에 닿았다)" }
        if ($hrows.Count -eq 0) { $bad += "대조 키 줄 없음 — /health 요청의 request_id $Nonce-$ev-health 가 pod 로그에 없다(상류 X-Request-ID 미전달 · 다른 pod · 로그 소실 — 0줄 판정의 근거가 없다 · VD-T076-4)" } }
      & $check "c8 $ev pod — 404 네 경로(request_id …-$ev-admin · webhooks · healthz · ready)의 web 로그 줄 0(pod 에 닿지 않았다) · 대조 키 줄(…-$ev-health) 있음" ($bad.Count -eq 0) ($bad -join ' · ') }
    $done = $true }
  catch {
    $stopWhy = [string]$_.Exception.Message
    if (-not [string]::IsNullOrEmpty($HOME)) { $stopWhy = [regex]::Replace($stopWhy, '(?i)' + [regex]::Escape($HOME), '~') } }
  finally {
    Remove-Variable tl, to, po, s, o, mine, rows -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T076 C-8 로그 대조 결과(Traefik · identity-admin web — 투영 필드만 · 운영자 IP · UA · ClientHost 없음 — tester 보고에 그대로) ---'
    foreach ($k in $res.Keys) {
      if (([string]$res[$k]).StartsWith('PASS', [StringComparison]::Ordinal)) { Write-Host "PASS $k" } else { Write-Host "FAIL $k — $(([string]$res[$k]) -replace '\p{Cc}', '?')" } }
    foreach ($l in $info) { Write-Host "INFO $(([string]$l) -replace '\p{Cc}', '?')" }
    if ($stopWhy.Length -gt 0) { Write-Host "STOP $($stopWhy -replace '\p{Cc}', '?')" }
    $nPass = @($res.Values | Where-Object { ([string]$_).StartsWith('PASS', [StringComparison]::Ordinal) }).Count
    if ($done -and $res.Count -eq 10 -and $nPass -eq 10) { Write-Host 'c8=PASS 10/10' } else { Write-Host "c8=FAIL $nPass/10" } }
  if ($done -and $res.Count -eq 10 -and $nPass -eq 10) { exit 0 }
  exit 1
}
