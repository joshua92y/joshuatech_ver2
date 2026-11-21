& {
  # ===== T076 O-9 블록 — tester 의 Vault 로그인 JWT(vault 전용 · 1시간) 발급 → DPAPI 파일(issue) · 또는 그 파일 삭제(clear) · 운영자(관리자 kubeconfig · 런북 §3 T076 ④-1(issue) · ④-3(clear) · 창 D) · 라이브 창마다 1번 =====
  # 선례: T075 O-5 의 창 전제(모듈 로깅 4키 가드 + 실효 확인 · 환경 변수 판정 · 실행 파일 경로 ~) · W-6 ACL LOAD 의 관리자 kubeconfig 꼴($HOME\.kube\joshuatech-admin.yaml 을 --kubeconfig 로
  #       직접 · 인자 배열 @kargs 펼침) · 가려진 정지점 · finally 정리를 따른다(설계 t076-design.md D2-3 · D3 · D7 · D16 · UD-16).
  # 목적(UD-16): tester 의 O-8 블록이 Vault role e2e-reader 로 로그인할 JWT 를 운영자가 라이브 창마다 한 번 발급한다 —
  #   kubectl create token agent-view -n kube-system --audience vault --duration=1h. 이 JWT 는 audience 가 vault 뿐이라 K8s API 에 쓸 수 없고 1시간 뒤 무효다.
  #   저장소 밖 %LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt 에 DPAPI(CurrentUser — ConvertFrom-SecureString 에 -Key 없음)로 암호화해 ASCII 로 둔다(덮어쓰기).
  #   O-8 은 같은 경로 · 같은 꼴로 읽는다: [System.IO.File]::ReadAllText(<경로>, ASCII).Trim() | ConvertTo-SecureString → NetworkCredential.Password — 이 블록이 쓴 뒤 그 꼴로 되읽어 대조한다
  # 판정(파일 쓰기 전 — 하나라도 어긋나면 쓰기 0 · 기존 파일 그대로): kubectl 출력 한 줄 · 꼴(점 둘 · base64url 세 조각) · payload 클레임 aud = 문자열 "vault" 또는 원소 하나인 배열
  #   ["vault"](뜻이 같다 — 오직 vault · Ordinal · 대소문자 구분 · 원소 둘 이상 · 빈 배열 · 다른 값 · 다른 형 · 없음 = STOP · 통과한 꼴은 INFO aud 꼴=문자열|배열 — VD-T076-10) ·
  #   sub = system:serviceaccount:kube-system:agent-view · exp − iat = 3600 ± 10 · iat = 지금 ± 120 s(이 PC 시계 — 서명은 보지 않는다: 클레임은 발급 확인용이다)
  # 가드(정지점 · kubectl 전 — 하나라도 어긋나면 아무것도 하지 않는다): 모듈 로깅(4키 + 실효) → 남는 인자 0($script:args — 모드는 인자가 아니다) → TLS · 프록시 환경 변수 →
  #   LOCALAPPDATA → 관리자 kubeconfig → kubectl 첫 해석 = Application(형식 필터 없는 Get-Command — 같은 이름의 함수 · 별칭 · 프로필 정의면 멈춘다)
  # 자격: 관리자 kubeconfig — 운영자 창만 · 에이전트는 이 블록을 실행하지 않는다
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §3 T076 · docs/runbooks/vault-unseal.md §12): ① 창 시작 체크리스트(모듈 로깅 정책 0 — JWT 가 ConvertTo-SecureString 을 지난다)
  #   ② 관리자 kubeconfig = $HOME\.kube\joshuatech-admin.yaml ③ TLS · 프록시 환경 변수 없음(블록도 본다) ④ tester 1차가 끝났다(설계 D14 — 2차 직전에 발급)
  # 실행: 파일로만(런북 정본) — pwsh -NoProfile -File '<이 파일의 절대 경로>' · 인자 0(남는 인자가 하나라도 있으면 아무것도 하지 않고 o9=STOP 인자 …)
  # 정지점 하나(가려진 입력 · 대소문자 구분 · 그 외 = 중단): issue = 발급(기존 파일은 덮어쓴다) · clear = 파일 삭제(세션 끝 — tester 2차가 끝나면)
  #   (모드는 인자가 아니라 이 정지점의 단어다 — 설계 D7 의 「-Clear」 = 이 정지점의 clear · T075 블록 규약(최상위 & { } 한 문 · param 0) · -Clear 같은 인자를 주면 멈춘다)
  # 원칙: JWT 는 이 프로세스의 변수에만 — 화면 · argv · 평문 파일 · 클립보드 · 전사 0(파일은 DPAPI 암호문뿐) · 출력은 Write-Host/Write-Warning 뿐 · 판정 불가 = 쓰기 0 ·
  #   응답(kubectl · 클레임)에서 온 글자는 제어 문자를 ? 로 · 160자 · finally 가 JWT 변수 · $Error(이 실행분)를 정리한다
  # 출력: o9 issued exp=<UTC> file=~\AppData\Local\jt-e2e\vault-e2e-reader.jwt · o9 cleared · o9 nothing-to-clear · 그 밖 = o9=STOP <사유>(남는 인자 = o9=STOP 인자 n개(…))
  # 받아들인 위험(설계 D16 ①): DPAPI CurrentUser 파일은 같은 Windows 사용자로 도는 프로세스(에이전트 포함)가 복호할 수 있다 — vault audience 전용 · 1시간 · 정책 두 경로 · 세션 끝 clear 로 줄인다
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-op.ps1 → 시나리오 PASS n / n
  Set-PSDebug -Off
  $ErrorActionPreference = 'Stop'
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $mode = ''
  $result = 'STOP 판정 전 중단(위 오류 — kubectl 0 · 파일 쓰기 0)'
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $pick = { param($prompt, $choices)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host $prompt -MaskInput
      foreach ($c in @($choices)) { if (& $eq $ans $c) { return $c } }
      throw '정지점에서 중단: 모드가 issue · clear 가 아니다(kubectl 0 · 파일 쓰기 0)' }
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
    # aud 표시(판정 실패 사유용 — 클레임은 비밀이 아니다): 문자열 = "값" · 배열 = [원소, …] · null = null · 그 밖의 형 = <형 이름>(해석한 꼴 — 호출자가 제어 문자 → ? · 160자)
    $audTxt = { param($v)
      if ($null -eq $v) { return 'null' }
      if ($v -is [string]) { return '"' + $v + '"' }
      if ($v -is [array]) { return '[' + ((@($v) | ForEach-Object { & $audTxt $_ }) -join ', ') + ']' }
      '<' + $v.GetType().Name + '>' }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 하지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 JWT 가 ConvertTo-SecureString 의 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 하지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 JWT 가 ConvertTo-SecureString 의 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 하지 않았다)" }
    # 남는 인자(T076 r1 — 리뷰 S-07 · C-02 · RO-02): 모드는 인자가 아니라 정지점 단어(issue · clear)로만 고른다 — 파일 실행의 인자(-Clear 등)는 $script:args 로 들어와 조용히 버려지므로
    #   하나라도 있으면 아무것도 하지 않고 멈춘다(값 미출력). $script:args 가 $null 이면 인자 0 이다(@($null).Count = 1 이라 $null 을 걸러 센다 · 붙여넣기 = 전역 범위의 $args)
    $nArg = @($script:args | Where-Object { $null -ne $_ }).Count
    if ($nArg -gt 0) {
      $result = "STOP 인자 ${nArg}개(모드는 정지점 단어 issue/clear — 인자를 받지 않는다 · 값 미출력) — kubectl 0 · 파일 그대로(쓰기 · 삭제 0) · 인자 없이 다시 실행해 정지점에 issue 또는 clear"
      throw "남는 인자 ${nArg}개 — 이 블록은 인자를 받지 않는다(모드는 정지점 단어 issue/clear) · kubectl 0 · 파일 쓰기 · 삭제 0" }
    # TLS · 프록시 동작을 바꾸는 환경 변수(T075 O-5 와 같은 목록 — tofu 를 쓰지 않아 TF_* 는 뺐다 · 리뷰 KB-1 · KB2-2): kubectl(Go)은 *_PROXY 를 따른다 — JWT 응답이 지나는 길에
    #   예상 밖 중계가 끼지 않게 이름만 내고 멈춘다(값은 내지 않는다 · 대소문자 무관)
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains $_.Name } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. Remove-Item Env:<이름> 뒤 새 창에서 다시(kubectl 0 · 파일 쓰기 0)" }
    if ([string]::IsNullOrEmpty($env:LOCALAPPDATA) -or -not [System.IO.Path]::IsPathFullyQualified($env:LOCALAPPDATA) -or -not [System.IO.Directory]::Exists($env:LOCALAPPDATA)) {
      throw 'LOCALAPPDATA 가 없거나 절대 경로의 폴더가 아니다 — JWT 파일 위치를 정할 수 없다(kubectl 0 · 파일 쓰기 0)' }
    $dir = Join-Path $env:LOCALAPPDATA 'jt-e2e'
    $file = Join-Path $env:LOCALAPPDATA 'jt-e2e\vault-e2e-reader.jwt'
    $kc = Join-Path $HOME '.kube\joshuatech-admin.yaml'
    if (-not (Test-Path -LiteralPath $kc)) { throw '관리자 kubeconfig 가 $HOME\.kube\joshuatech-admin.yaml 에 없다(vault-unseal.md §0) — kubectl 0 · 파일 쓰기 0' }
    $kcs = @(Get-Command kubectl -ErrorAction SilentlyContinue)
    if ($kcs.Count -eq 0) { throw 'kubectl 을 찾을 수 없다(PATH) — 파일 쓰기 0' }
    # kubectl 첫 해석(T076 r1 — 리뷰 S-10): 형식 필터 없는 Get-Command 의 첫 해석 = 아래에서 kubectl 을 부를 때 실제로 도는 것 — Application 이 아니면(같은 이름의 함수 · 별칭 · 프로필
    #   정의 — 발급한 JWT 가 그 함수의 출력으로 온다) 멈춘다(kubectl 0 · 파일 쓰기 0)
    if (-not (& $eq ([string]$kcs[0].CommandType) 'Application')) {
      $result = "STOP 첫 해석이 실행 파일이 아니다: kubectl → $(& $clean ([string]$kcs[0].CommandType))(같은 이름의 함수 · 별칭 · 프로필 정의) — kubectl 0 · 파일 쓰기 0"
      throw '첫 해석이 실행 파일(Application)이 아니다: kubectl — kubectl 0 · 파일 쓰기 0' }
    $ksrc = & $tilde $kcs[0].Source
    $had = [System.IO.File]::Exists($file)
    Write-Host "INFO kubectl $([string]$kcs[0].CommandType) $ksrc · kubeconfig ~\.kube\joshuatech-admin.yaml · JWT 파일 $(& $tilde $file)($(if ($had) { '있음 — issue 는 덮어쓰고 clear 는 지운다' } else { '없음' }))"
    $mode = [string](& $pick 'o9 모드 — issue(vault 전용 1시간 JWT 발급 · 파일 덮어쓰기) 또는 clear(파일 삭제 — 세션 끝)를 그대로 입력(입력은 가려진다 · 그 외 = 중단)' @('issue', 'clear'))
    if (& $eq $mode 'clear') {
      if (-not [System.IO.File]::Exists($file)) {
        $result = 'nothing-to-clear'
        return }
      $result = 'STOP clear 도중 중단(파일이 남았을 수 있다 — 직접 확인)'
      [System.IO.File]::Delete($file)
      if ([System.IO.File]::Exists($file)) {
        $result = 'STOP clear 실패(파일이 남아 있다 — 직접 지운다)'
        throw 'clear 실패: 파일이 남아 있다' }
      $result = 'cleared'
      return }
    # ---------- issue: 발급(변수로만) → 판정 → DPAPI → 쓰기 → 되읽기(O-8 꼴) ----------
    $result = 'STOP 발급 도중 중단(위 오류 — 파일 쓰기 0)'
    $kargs = @('--kubeconfig', $kc, 'create', 'token', 'agent-view', '-n', 'kube-system', '--audience', 'vault', '--duration=1h')
    $out = @(kubectl @kargs 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $outs = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    $errs = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    $out = $null
    if ($rc -ne 0) {
      $outs = $null
      $result = "STOP kubectl create token 실패(exit=$rc · $(& $firstErr $errs)) — 파일 쓰기 0$(if ($had) { ' · 기존 파일 그대로' })"
      throw "kubectl create token 실패(exit=$rc) — 파일 쓰기 0" }
    if ($outs.Count -ne 1) {
      $n = $outs.Count
      $outs = $null
      $result = "STOP kubectl 출력이 한 줄이 아니다($n 줄 — 값 미출력) — 파일 쓰기 0$(if ($had) { ' · 기존 파일 그대로' })"
      throw 'kubectl 출력이 한 줄이 아니다 — 파일 쓰기 0' }
    $jwt = $outs[0]
    $outs = $null
    $pl = & $payload $jwt
    if ($null -eq $pl) {
      $jwt = $null
      $result = "STOP JWT 꼴이 아니다(점 둘 · base64url 세 조각 · payload JSON — 값 미출력) — 파일 쓰기 0$(if ($had) { ' · 기존 파일 그대로' })"
      throw 'JWT 꼴이 아니다 — 파일 쓰기 0' }
    $bad = @()
    $audForm = ''
    $audP = $pl.PSObject.Properties['aud']
    if ($null -eq $audP) { $bad += 'aud 없음' }
    elseif ($audP.Value -is [string] -and (& $eq $audP.Value 'vault')) { $audForm = '문자열' }
    elseif ($audP.Value -is [array] -and $audP.Value.Count -eq 1 -and $audP.Value[0] -is [string] -and (& $eq $audP.Value[0] 'vault')) { $audForm = '배열' }
    else { $bad += "aud = $(& $clean (& $audTxt $audP.Value))(문자열 `"vault`" 또는 원소 하나인 배열 [`"vault`"] 가 아니다 — Ordinal · 대소문자 구분)" }
    $sub = & $prop $pl 'sub'
    if (-not (& $eq $sub 'system:serviceaccount:kube-system:agent-view')) { $bad += "sub = $(& $clean $sub)(system:serviceaccount:kube-system:agent-view 가 아니다)" }
    $exp = & $prop $pl 'exp'
    $iat = & $prop $pl 'iat'
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($exp -isnot [long] -or $iat -isnot [long]) { $bad += 'exp · iat 가 정수가 아니다' }
    else {
      if ([Math]::Abs(($exp - $iat) - 3600) -gt 10) { $bad += "수명 exp − iat = $($exp - $iat) s(기대 3600 ± 10)" }
      if ([Math]::Abs($iat - $now) -gt 120) { $bad += "iat − 지금 = $($iat - $now) s(기대 ± 120 — 이 PC 시계 · 클러스터 시계 확인)" } }
    $pl = $null; $audP = $null
    if ($audForm) { Write-Host "INFO aud 꼴=$audForm(VD-T076-10 관찰 — K3s TokenRequest 의 단일 audience 직렬화 · 문자열 `"vault`" · [`"vault`"] 둘 다 오직 vault)" }
    if ($bad.Count -gt 0) {
      $jwt = $null
      $result = "STOP 클레임 판정 실패($($bad -join ' · ')) — 파일 쓰기 0$(if ($had) { ' · 기존 파일 그대로' })"
      throw '클레임 판정 실패 — 파일 쓰기 0' }
    Write-Host 'OK   JWT 꼴 · aud = 오직 vault(문자열 "vault" 또는 원소 하나인 배열 ["vault"]) · sub = agent-view · 수명 3600 s · iat = 지금(값 미출력) — DPAPI 로 암호화해 파일에 쓴다'
    $enc = ConvertFrom-SecureString -SecureString (ConvertTo-SecureString -String $jwt -AsPlainText -Force)
    $null = [System.IO.Directory]::CreateDirectory($dir)
    $result = 'STOP 파일 쓰기 도중 중단(파일이 바뀌었을 수 있다 — 다시 issue 또는 clear)'
    [System.IO.File]::WriteAllText($file, $enc, [System.Text.Encoding]::ASCII)
    $enc = $null
    # 되읽기(O-8 과 같은 꼴) — 복호 값이 발급한 JWT 와 Ordinal 로 같아야 한다(값 · 해시 미출력). 다르면 O-8 이 쓸 수 없는 파일이라 지운다
    $back = $null
    try {
      $ss = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::ASCII).Trim() | ConvertTo-SecureString
      $back = [System.Net.NetworkCredential]::new('', $ss).Password
      $ss.Dispose() }
    catch { $back = $null }
    $same = & $eq $back $jwt
    $back = $null; $ss = $null; $jwt = $null
    if (-not $same) {
      [System.IO.File]::Delete($file)
      $result = 'STOP 되읽기 불일치(O-8 꼴로 복호한 값이 발급한 JWT 와 다르다 — 파일을 지웠다)'
      throw '되읽기 불일치 — 파일을 지웠다' }
    $result = "issued exp=$([DateTimeOffset]::FromUnixTimeSeconds($exp).UtcDateTime.ToString('s'))Z file=$(& $tilde $file)"
    if ($had) { Write-Host 'OK   기존 파일을 덮어썼다 · 되읽기(O-8 꼴) 일치' } else { Write-Host 'OK   새 파일 · 되읽기(O-8 꼴) 일치' } }
  finally {
    Remove-Variable jwt, enc, ss, back, out, outs, errs, pl, audP -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T076 O-9 결과(모드=$(if ($mode) { $mode } else { '선택 전' }) · JWT · 암호문 없음 — 런북 bootstrap.md §3 T076 기록 칸에 그대로 기록) ---"
    if ($result.StartsWith('STOP', [StringComparison]::Ordinal)) { Write-Host "o9=$result" } else { Write-Host "o9 $result" }
    if ($result.StartsWith('issued ', [StringComparison]::Ordinal)) { Write-Host '다음: 컨트롤러가 이 1시간 안에 tester 2차(O-8)를 디스패치한다 · 2차가 끝나면 이 블록을 clear 로 다시 돌린다(세션 끝)' }
  }
}
