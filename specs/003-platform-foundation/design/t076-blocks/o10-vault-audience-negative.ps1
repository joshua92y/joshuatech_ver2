& {
  # ===== T076 O-10 블록 — 음성 대조(VD-T076-1): audience 를 주지 않은 agent-view 토큰은 Vault role e2e-reader 로그인이 거부돼야 한다 · 판정만 · 정책 apply · W-7 시드 전 1회(운영자 · 런북 §3 T076 ①-2 · 창 D) =====
  # 선례: T075 O-5 의 창 전제 · curl 가드(첫 인자 -q · 환경 변수 판정 · 7.84 이상 · 실행 파일 경로 ~) · 응답 문자열 정제와 W-6 ACL LOAD 의 관리자 kubeconfig 꼴 · W-2 의 Vault 판정(도달 확인 뒤에만
  #       자격을 보낸다)을 따른다(설계 t076-design.md D2-4 · D3 · D7 · D14 · VD-T076-1 · 비판 B-02).
  # 왜: 로그인이 통과하면 지금 에이전트들의 agent-view 8h 토큰(audience = API 서버 기본)이 이미 Vault e2e-reader 자격이라는 뜻이다 — UD-15 로 그 role 이 tester-m2m 을 읽게 되기 전에 확인한다.
  # 흐름(쓰기 = agent-view 10분 토큰 발급 1회뿐 · vault CLI 0 — Vault HTTP API 를 curl 로 · ~/.vault-token · 토큰 도우미 · VAULT_* 면이 없다):
  #   ① 관리자 kubeconfig 로 kubectl create token agent-view -n kube-system --duration=10m(audience 없음 = API 서버 기본)을 변수로만 받는다
  #   ② 클레임 판정: aud 에 vault 없음(배열 · 문자열 어느 꼴이든 · 대소문자 무관) · sub = system:serviceaccount:kube-system:agent-view · exp − iat = 600 ± 10 · iat = 지금 ± 120 s — 아니면 JWT 0 전송
  #   ③ 무자격 GET http://127.0.0.1:18200/v1/sys/seal-status(창 C) — 200 · sealed = false · cluster_name = vault-cluster-d3b29227(bootstrap.md 「git 밖 라이브 상태」)이 아니면 JWT 0 전송
  #   ④ POST /v1/auth/kubernetes/login — 본문 {"role":"e2e-reader","jwt":…}을 stdin(--data-binary @-)으로 한 번 · JWT 변수는 본문을 만든 직후 지운다
  #   ⑤ 응답에 auth.client_token 이 있으면(통과) 그 자리에서 POST /v1/auth/token/revoke-self(토큰 헤더는 stdin -H @-) → o10=FAIL(정책 · 시드로 넘어가지 않는다) ·
  #      4xx 이고 auth 없음(거부) → o10=PASS(코드 · errors 첫 줄 정제) · 그 밖(5xx · 응답 없음 · auth 만 있음 · 해석 불가) → o10=FAIL 판정 불가
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §3 T076 · docs/runbooks/vault-unseal.md §0): ① 창 시작 체크리스트(모듈 로깅 정책 0 — Vault 응답이 ConvertFrom-Json 을 지난다)
  #   ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200 ③ 관리자 kubeconfig = $HOME\.kube\joshuatech-admin.yaml
  #   ④ curl · TLS · 프록시 환경 변수 없음(SSL_CERT_FILE · SSL_CERT_DIR · CURL_CA_BUNDLE · SSLKEYLOGFILE · *_PROXY — 블록도 본다) ⑤ curl 7.84 이상
  # 가드(정지점 · 외부 호출 전 — 하나라도 어긋나면 아무것도 하지 않는다): 모듈 로깅(4키 + 실효) → 남는 인자 0($script:args) → curl · TLS · 프록시 환경 변수 → 관리자 kubeconfig →
  #   kubectl · curl.exe 첫 해석 = Application(형식 필터 없는 Get-Command — 같은 이름의 함수 · 별칭 · 프로필 정의면 멈춘다 · curl --version 도 그 뒤) → curl 7.84
  # 실행: 파일로만(런북 정본) — pwsh -NoProfile -File '<이 파일의 절대 경로>' · 인자 0(남는 인자가 하나라도 있으면 아무것도 하지 않고 o10=FAIL 판정 불가(인자 …))
  # 정지점 하나: probe — 토큰 발급 · 로그인 시도 확인(가려진 입력 · 대소문자 구분 · 그 외 = 중단 — 아무것도 하지 않는다)
  # 원칙: JWT · Vault 토큰은 이 프로세스의 변수에만(화면 · argv · 파일 · 클립보드 · 전사 0) · 자격이 든 값은 stdin 으로만 curl 에 · curl 첫 인자 -q · 응답 헤더를 통째로 읽지 않는다 ·
  #   응답에서 온 글자는 제어 문자 → ? · 160자 · 판정 불가 = FAIL · finally 가 JWT · 토큰 변수 · $Error(이 실행분)를 정리한다
  # 출력: 끝 줄 o10=PASS …(로그인 거부) · o10=FAIL …(로그인 통과 = 정책 · 시드로 넘어가지 않는다 · 또는 판정 불가 — 남는 인자 = o10=FAIL 판정 불가(인자 n개 …))
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-op.ps1 → 시나리오 PASS n / n
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $base = 'http://127.0.0.1:18200'
  $result = 'FAIL 판정 불가(중단 — 위 오류 · JWT 전송 0)'
  $sent = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $stop = { param($msg, $word)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)" -MaskInput
      if (-not (& $eq $ans $word)) { throw "정지점에서 중단: $msg — 토큰 발급 0 · JWT 전송 0" } }
    $firstErr = { param($lines)
      $c = @(@($lines) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $pk = '(오류 출력 없음)'
      if ($c.Count -gt 0) { $pk = $c[0] }
      if ($pk.Length -gt 160) { $pk = $pk.Substring(0, 160) + '…' }
      $pk -replace '\p{Cc}', '?' }
    $clean = { param($s)
      $x = [string]$s
      if ($x.Length -gt 160) { $x = $x.Substring(0, 160) + '…' }
      $x -replace '\p{Cc}', '?' }
    $parseJson = { param($lines)
      $t = (@($lines) | ForEach-Object { [string]$_ }) -join "`n"
      if ([string]::IsNullOrWhiteSpace($t)) { return $null }
      try { $t | ConvertFrom-Json -DateKind String } catch { $null } }
    $prop = { param($o, $n)
      if ($null -eq $o) { return $null }
      $p = $o.PSObject.Properties[$n]
      if ($null -eq $p) { return $null }
      $p.Value }
    $tilde = { param($s)
      $s = [string]$s
      if ([string]::IsNullOrEmpty($s)) { return '(경로 없음)' }
      if (-not [string]::IsNullOrEmpty($HOME) -and $s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { return '~' + $s.Substring($HOME.Length) }
      $s }
    # JWT payload(두 번째 조각 — base64url · 패딩 없음)를 JSON 객체로. 꼴이 아니면 $null(서명은 보지 않는다 — 클레임은 비밀이 아니다 · JWT 원문은 돌려주지 않는다)
    $payload = { param($jwt)
      if (([string]$jwt) -cnotmatch '\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z') { return $null }
      $seg = ([string]$jwt).Split('.')[1].Replace('-', '+').Replace('_', '/')
      if ($seg.Length % 4 -eq 1) { return $null }
      if ($seg.Length % 4 -gt 0) { $seg += '=' * (4 - $seg.Length % 4) }
      $txt = $null
      try { $txt = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($seg)) } catch { return $null }
      & $parseJson $txt }
    # HTTP 1회(curl → Vault HTTP API): get = 무자격 GET · login = 본문 stdin POST(--data-binary @-) · revoke = 토큰 헤더 stdin POST(-X POST -H @-).
    #   돌려주는 것 = ok(-w 줄을 읽었고 curl exit 0) · 상태 코드 · 본문 줄 · 사유(curl 오류 첫 줄 정제) — 응답 헤더는 읽지 않는다(-w 는 http_code 하나)
    $wfmt = '\nT076-W code=%{http_code}\n'
    $http = { param($kind, $url, $in)
      if (& $eq $kind 'get') { $out = @(curl.exe -q -sS --max-time 20 -w $wfmt $url 2>&1) }
      elseif (& $eq $kind 'login') { $out = @($in | curl.exe -q -sS --max-time 20 --data-binary '@-' -w $wfmt $url 2>&1) }
      else { $out = @($in | curl.exe -q -sS --max-time 20 -X POST -H '@-' -w $wfmt $url 2>&1) }
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $lines = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
      $errl = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      $out = $null
      $iw = -1
      for ($i = $lines.Count - 1; $i -ge 0; $i--) { if ($lines[$i].StartsWith('T076-W ', [StringComparison]::Ordinal)) { $iw = $i; break } }
      $m = $null
      if ($iw -ge 0) { $m = [regex]::Match($lines[$iw], '\AT076-W code=([0-9]{3})\z') }
      if ($rc -ne 0 -or $null -eq $m -or -not $m.Success) {
        $lines = $null
        return [pscustomobject]@{ ok = $false; code = ''; body = @(); why = "curl exit=$rc · $(& $firstErr $errl)" } }
      $body = @(); if ($iw -gt 0) { $body = @($lines[0..($iw - 1)]) }
      $lines = $null
      [pscustomobject]@{ ok = $true; code = $m.Groups[1].Value; body = $body; why = '' } }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 하지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 Vault 응답 원문(통과면 client_token)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 하지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 Vault 응답 원문(통과면 client_token)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 하지 않았다)" }
    # 남는 인자(T076 r1 — 리뷰 S-07 · C-02 · RO-02): 이 블록은 인자를 받지 않는다(입력은 정지점 단어 probe 뿐) — 파일 실행의 인자는 $script:args 로 들어와 조용히 버려지므로 하나라도
    #   있으면 아무것도 하지 않고 멈춘다(값 미출력). $script:args 가 $null 이면 인자 0 이다(@($null).Count = 1 이라 $null 을 걸러 센다 · 붙여넣기 = 전역 범위의 $args)
    $nArg = @($script:args | Where-Object { $null -ne $_ }).Count
    if ($nArg -gt 0) {
      $result = "FAIL 판정 불가(인자 ${nArg}개 — 값 미출력 · 이 블록은 인자를 받지 않는다(입력은 정지점 단어 probe 뿐) · 토큰 발급 0 · JWT 전송 0)"
      throw "남는 인자 ${nArg}개 — 이 블록은 인자를 받지 않는다 · 토큰 발급 0 · JWT 전송 0" }
    # curl · TLS · 프록시 동작을 바꾸는 환경 변수(T075 O-5 와 같은 목록 — tofu 를 쓰지 않아 TF_* 는 뺐다 · 리뷰 KB-1 · KB2-2): SSL_CERT_FILE · SSL_CERT_DIR · CURL_CA_BUNDLE(신뢰 앵커 교체) ·
    #   SSLKEYLOGFILE(TLS 키 기록) · HTTP_PROXY · HTTPS_PROXY · ALL_PROXY(대소문자 무관 — JWT · 토큰이 프록시를 지난다)가 있으면 멈춘다 — 이름만 낸다.
    #   .curlrc 는 curl 첫 인자 -q 로 읽지 않는다(실측: -q 없으면 사용자 curlrc 의 --trace-ascii · --cookie-jar 가 요청 본문 · 헤더를 파일에 남긴다 — T075 O-5)
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains $_.Name } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 curl · TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. Remove-Item Env:<이름> 뒤 새 창에서 다시(토큰 발급 0 · JWT 전송 0)" }
    $kc = Join-Path $HOME '.kube\joshuatech-admin.yaml'
    if (-not (Test-Path -LiteralPath $kc)) { throw '관리자 kubeconfig 가 $HOME\.kube\joshuatech-admin.yaml 에 없다(vault-unseal.md §0) — 토큰 발급 0 · JWT 전송 0' }
    $kcs = @(Get-Command kubectl -ErrorAction SilentlyContinue)
    if ($kcs.Count -eq 0) { throw 'kubectl 을 찾을 수 없다(PATH) — 토큰 발급 0 · JWT 전송 0' }
    $ccs = @(Get-Command curl.exe -ErrorAction SilentlyContinue)
    if ($ccs.Count -eq 0) { throw 'curl.exe 를 찾을 수 없다(PATH) — 토큰 발급 0 · JWT 전송 0' }
    # 첫 해석(T076 r1 — 리뷰 S-10): 형식 필터 없는 Get-Command 의 첫 해석 = 이 블록이 kubectl · curl.exe 를 부를 때 실제로 도는 것 — Application 이 아니면(같은 이름의 함수 · 별칭 ·
    #   프로필 정의 — JWT · 로그인 본문 · 토큰 헤더가 그 함수로 간다) 멈춘다(curl --version 을 포함해 외부 호출 0)
    $shadow = @()
    if (-not (& $eq ([string]$kcs[0].CommandType) 'Application')) { $shadow += "kubectl → $(& $clean ([string]$kcs[0].CommandType))" }
    if (-not (& $eq ([string]$ccs[0].CommandType) 'Application')) { $shadow += "curl.exe → $(& $clean ([string]$ccs[0].CommandType))" }
    if ($shadow.Count -gt 0) {
      $result = "FAIL 판정 불가(첫 해석이 실행 파일이 아니다: $($shadow -join ' · ') — 같은 이름의 함수 · 별칭 · 프로필 정의 · 토큰 발급 0 · JWT 전송 0)"
      throw "첫 해석이 실행 파일(Application)이 아니다: $($shadow -join ' · ') — 토큰 발급 0 · JWT 전송 0" }
    $ksrc = & $tilde $kcs[0].Source
    $csrc = & $tilde $ccs[0].Source
    $cv = @(curl.exe -q --version 2>$null)
    $global:LASTEXITCODE = 0
    $cm = $null; if ($cv.Count -gt 0) { $cm = [regex]::Match([string]$cv[0], '\Acurl ([0-9]+)\.([0-9]+)') }
    if ($null -eq $cm -or -not $cm.Success -or [int]$cm.Groups[1].Value -lt 7 -or ([int]$cm.Groups[1].Value -eq 7 -and [int]$cm.Groups[2].Value -lt 84)) { throw 'curl 7.84 이상이 필요하다 — 토큰 발급 0 · JWT 전송 0' }
    Write-Host "INFO curl $($cm.Groups[1].Value).$($cm.Groups[2].Value) · $([string]$ccs[0].CommandType) $csrc · kubectl $([string]$kcs[0].CommandType) $ksrc · Vault $base(창 C) — 쓰기 = agent-view 10분 토큰 발급 1회뿐 · vault CLI 0"
    & $stop 'o10 음성 대조: agent-view 10분 토큰(audience 없음)을 발급해 e2e-reader 로그인에 한 번 넣는다(거부돼야 PASS · 통과하면 받은 토큰을 바로 revoke)' 'probe'
    # ---------- ① audience 없는 agent-view 토큰(변수로만) ----------
    $result = 'FAIL 판정 불가(토큰 발급 도중 중단 — 위 오류 · JWT 전송 0)'
    $kargs = @('--kubeconfig', $kc, 'create', 'token', 'agent-view', '-n', 'kube-system', '--duration=10m')
    $out = @(kubectl @kargs 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $outs = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    $errs = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $out = $null
    if ($rc -ne 0 -or $outs.Count -ne 1) {
      $n = $outs.Count
      $outs = $null
      $result = "FAIL 판정 불가(kubectl create token exit=$rc · 출력 $n 줄 · $(& $firstErr $errs) — JWT 전송 0)"
      throw 'kubectl create token 실패 — JWT 전송 0' }
    $jwt = $outs[0]
    $outs = $null
    # ---------- ② 클레임 판정(음성 대조가 성립하는 토큰인가) ----------
    $pl = & $payload $jwt
    if ($null -eq $pl) {
      $jwt = $null
      $result = 'FAIL 판정 불가(JWT 꼴이 아니다 — 점 둘 · base64url 세 조각 · payload JSON · 값 미출력 · JWT 전송 0)'
      throw 'JWT 꼴이 아니다 — JWT 전송 0' }
    $bad = @()
    $audP = $pl.PSObject.Properties['aud']
    $auds = @(); if ($null -ne $audP) { $auds = @($audP.Value) }
    $audShow = & $clean ($auds -join ', ')
    if ($null -eq $audP -or $auds.Count -eq 0 -or @($auds | Where-Object { $_ -isnot [string] }).Count -gt 0) { $bad += 'aud 가 없거나 문자열(또는 문자열 배열)이 아니다' }
    elseif (@($auds | Where-Object { [string]::Equals([string]$_, 'vault', [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) { $bad += "aud 에 vault 가 있다([$audShow]) — 음성 대조가 성립하지 않는다" }
    $sub = & $prop $pl 'sub'
    if (-not (& $eq $sub 'system:serviceaccount:kube-system:agent-view')) { $bad += "sub = $(& $clean $sub)(system:serviceaccount:kube-system:agent-view 가 아니다)" }
    $exp = & $prop $pl 'exp'
    $iat = & $prop $pl 'iat'
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($exp -isnot [long] -or $iat -isnot [long]) { $bad += 'exp · iat 가 정수가 아니다' }
    else {
      if ([Math]::Abs(($exp - $iat) - 600) -gt 10) { $bad += "수명 exp − iat = $($exp - $iat) s(기대 600 ± 10)" }
      if ([Math]::Abs($iat - $now) -gt 120) { $bad += "iat − 지금 = $($iat - $now) s(기대 ± 120 — 이 PC 시계 · 클러스터 시계 확인)" } }
    $pl = $null; $audP = $null
    if ($bad.Count -gt 0) {
      $jwt = $null
      $result = "FAIL 판정 불가(클레임 — $($bad -join ' · ') · JWT 전송 0)"
      throw '클레임 판정 실패 — JWT 전송 0' }
    Write-Host "OK   agent-view 10분 토큰 — aud = [$audShow](vault 없음) · sub = agent-view · 수명 600 s · iat = 지금(값 미출력)"
    # ---------- ③ Vault 도달 · 클러스터 확인(무자격 — JWT 를 보내기 전) ----------
    $r = & $http 'get' "$base/v1/sys/seal-status" $null
    $sb = $null; if ($r.ok) { $sb = & $parseJson $r.body }
    $sea = & $prop $sb 'sealed'
    $cn = & $prop $sb 'cluster_name'
    if (-not $r.ok -or -not (& $eq $r.code '200') -or $sea -isnot [bool] -or $sea -or -not (& $eq $cn 'vault-cluster-d3b29227')) {
      $jwt = $null
      $why = $r.why
      if ($r.ok) { $why = "코드 $($r.code) · sealed = $(& $clean $sea) · cluster_name = $(& $clean $cn)" }
      $result = "FAIL 판정 불가(seal-status — $why · 기대 200 · sealed false · vault-cluster-d3b29227 — 창 C · 클러스터 확인 · JWT 전송 0)"
      throw 'seal-status 판정 실패 — JWT 를 보내지 않았다' }
    Write-Host "OK   Vault seal-status 200 · sealed = false · cluster_name = vault-cluster-d3b29227($base — 창 C)"
    # ---------- ④ 로그인 1회(본문 stdin) — JWT 변수는 본문을 만든 직후 지운다 ----------
    $body = '{"role":"e2e-reader","jwt":"' + $jwt + '"}'
    $jwt = $null
    $result = 'FAIL 판정 불가(로그인 도중 중단 — 토큰이 발급됐는지 모른다 · 받은 토큰 0 · TTL 뒤 만료)'
    $sent = $true
    $r = & $http 'login' "$base/v1/auth/kubernetes/login" $body
    $body = $null
    $lb = $null; if ($r.ok) { $lb = & $parseJson $r.body }
    $r.body = @()
    # @(& $prop …)는 값이 없으면 $null 하나짜리 배열이다(실측) — $null 을 걸러 센다
    $auth = & $prop $lb 'auth'
    $hasAuth = $null -ne $auth
    $ct = & $prop $auth 'client_token'
    $pol = @(@(& $prop $auth 'policies') | Where-Object { $null -ne $_ })
    $lease = & $prop $auth 'lease_duration'
    $e1 = '(errors 없음)'
    $el = @(@(& $prop $lb 'errors') | Where-Object { $null -ne $_ })
    if ($el.Count -gt 0) { $e1 = & $clean $el[0] }
    elseif ($r.ok -and $null -eq $lb) { $e1 = '(본문 해석 불가)' }
    $lb = $null; $auth = $null
    if ($ct -is [string] -and $ct.Length -gt 0) {
      # ---------- ⑤ 통과 — 받은 토큰을 그 자리에서 revoke(헤더 stdin) ----------
      $hdr = "X-Vault-Token: $ct"
      $ct = $null
      $rv = & $http 'revoke' "$base/v1/auth/token/revoke-self" $hdr
      $hdr = $null
      $rvs = "실패($($rv.why) — 토큰은 이 프로세스 메모리에만 있었고 버렸다 · lease 뒤 만료)"
      if ($rv.ok -and (& $eq $rv.code '204')) { $rvs = '204(취소됨)' }
      elseif ($rv.ok) { $rvs = "실패(코드 $($rv.code) — 토큰은 이 프로세스 메모리에만 있었고 버렸다 · lease 뒤 만료)" }
      $result = "FAIL 로그인 통과(코드 $($r.code) · 정책 [$(& $clean ($pol -join ', '))] · lease $(& $clean $lease) s) — audience 없는 agent-view 토큰이 e2e-reader 자격이다 · revoke-self $rvs — 정책 apply · W-7 시드로 넘어가지 않는다(멈추고 컨트롤러 · 사용자에게 보고)" }
    elseif ($r.ok -and ($r.code -cmatch '\A4[0-9]{2}\z') -and -not $hasAuth) {
      $result = "PASS 로그인 거부(코드 $($r.code) · $e1) — audience 없는 agent-view 토큰은 e2e-reader 자격이 아니다(VD-T076-1)" }
    else {
      $why = $r.why
      if ($r.ok) { $why = "코드 $($r.code) · $e1" }
      $result = "FAIL 판정 불가(로그인 응답 — $why · 받은 토큰 0)" } }
  finally {
    Remove-Variable jwt, body, hdr, ct, lb, auth, r, rv, out, outs, errs, pl, audP, sb -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T076 O-10 음성 대조 결과(JWT · Vault 토큰 없음 · 로그인 시도 $(if ($sent) { '1회' } else { '0회' }) — 런북 bootstrap.md §4 T076 기록 칸에 그대로 기록) ---"
    Write-Host "o10=$result"
  }
}
