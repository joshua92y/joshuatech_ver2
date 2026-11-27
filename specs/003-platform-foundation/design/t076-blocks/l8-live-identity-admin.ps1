param([string]$ExpectedRevision = '')
& {
  # ===== T076 L-8 블록 — identity-admin dev · prod 라이브 사다리 ⓪–⑤(tester 1차 · 비밀 0 · 읽기만 · 쓰기 0 · Vault 0) · 파일로만 실행 =====
  # 설계 t076-design.md D6 · D12(ES 2 주입 · owner 자격 없음 — 증거 사다리) · D3(tester 블록 계약). 기대 리터럴 = gitops origin/main cb3ba13 의 apps/identity-admin/base/*.yaml ·
  #   overlays/{dev,prod}/kustomization.yaml(ES 템플릿 키 11 · 원격 키 · 어노테이션 · 보안 컨텍스트 · 프로브 · envFrom · 볼륨) — 라이브 객체가 git 과 다르면 FAIL 이다(리터럴을 고치지 않는다)
  # 실행(tester · Git Bash · Bash 도구 timeout 600000): chcp.com 65001 >/dev/null; pwsh -NoProfile -File '<이 파일의 절대 경로>' -ExpectedRevision <gitops main 40자 소문자 hex(컨트롤러가 fetch 뒤 rev-parse origin/main 으로 준다)>; echo "exit=$?"
  #   판정은 끝 줄과 종료 코드 · 한글 줄은 증거. 입력은 param 뿐(Read-Host 0) — 꼴이 아니거나 다른 인자가 있으면 아무것도 부르지 않고 멈춘다 · 끝 줄 l8=PASS 24/24 또는 l8=FAIL k/24 · 종료 코드 0 = 전부 PASS 일 때만
  # 사다리(env 마다 12 = 24): ⓪ Application identity-admin-<env>(Synced · Healthy · revision = 입력 · operationState Succeeded) ① ES identity-admin-env · identity-admin-migrate
  #   Ready=True(SecretSynced) ② ES 스펙(-env = vault-<env> · 템플릿 키 정확히 11 · 원격 키 12 줄 = git · /owner 0 · <env>/ 접두 / -migrate = 키 {DATABASE_OWNER_URL} · 원격 키
  #   <env>/db/<role>/owner · PreSync · BeforeHookCreation · wave -1 < Job wave 0) ③ 워크로드 셋(보안 컨텍스트 · /tmp emptyDir · 프로브 · -migrate 분리) ④ init startup-check 로그의
  #   startup_check: OK ⑤ 무자격 curl — m2m /health → 401 · Location 없음(편차 후보 6). INFO: admin 무자격 302 · Location = scheme://host/path 만(쿼리 0 — Test-AccessLocation 꼴 · US4 AC6)
  # 원칙: kubectl 은 리터럴 agent-view kubeconfig(--kubeconfig 늘 · KUBECONFIG 환경 변수 무시)로 get · logs 만 · Secret 을 읽지 않는다 · curl 은 자격 0 · 리다이렉트 미추적 ·
  #   응답에서 온 글자는 제어 문자 → ? · 160자 · 판정 불가 = FAIL · 출력은 Write-Host 뿐
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
    $names = { param($o) if ($null -eq $o) { @() } else { @($o.PSObject.Properties | ForEach-Object { $_.Name }) } }
    $check = { param($name, $ok, $why) if ($ok) { $res[$name] = 'PASS' } else { $res[$name] = "FAIL($why)" } }
    $clean = { param($s) $c = ([string]$s) -replace '\p{Cc}', '?'; if ($c.Length -gt 160) { $c = $c.Substring(0, 160) + '…' }; $c }
    $tilde = { param($s)
      $s = [string]$s
      if ([string]::IsNullOrEmpty($s)) { return '(경로 없음)' }
      if (-not [string]::IsNullOrEmpty($HOME) -and $s.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { return '~' + $s.Substring($HOME.Length) }
      $s }
    $hide = { param($s) $t = [string]$s; if (-not [string]::IsNullOrEmpty($HOME)) { $t = [regex]::Replace($t, '(?i)' + [regex]::Escape($HOME), '~') }; $t }
    $isT = { param($v) $v -is [bool] -and $v }
    $isF = { param($v) $v -is [bool] -and -not $v }
    $isN = { param($v, $n) $v -is [long] -and $v -eq $n }
    $list = { param($o, $n) @(& $prop $o $n | Where-Object { $null -ne $_ }) }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 부르지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 클러스터 객체 원문 · Access 응답(Location 의 meta 토큰)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 부르지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 클러스터 객체 원문 · Access 응답(Location 의 meta 토큰)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 부르지 않았다)" }
    # 입력(D3 · A-1): param 뿐 — 파일 실행 · 다른 인자 0 · -ExpectedRevision 꼴을 kubectl · curl 호출 전에 판정한다
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -ExpectedRevision <40자 hex>) — 아무것도 부르지 않았다' }
    if (@($script:args).Count -gt 0) { throw "입력은 -ExpectedRevision 하나뿐이다 — 그 밖의 인자 $(@($script:args).Count)개(값 미출력) · 아무것도 부르지 않았다" }
    if ($ExpectedRevision -cnotmatch '\A[0-9a-f]{40}\z') { throw '입력 -ExpectedRevision 이 40자 소문자 hex(gitops main 커밋)가 아니다(아무것도 부르지 않았다)' }
    # 환경 변수(T075 KB-1): curl · kubectl 의 신뢰 앵커 · 키 기록 · 프록시가 있으면 이름만 내고 멈춘다 · curl 은 첫 인자 -q 로 .curlrc 를 읽지 않는다
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains $_.Name } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 curl · kubectl 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. 그 변수가 없는 새 창에서 다시(아무것도 부르지 않았다)" }
    # 실행 파일(S-10): curl.exe · kubectl.exe 의 형식 필터 없는 Get-Command 첫 해석(= 호출이 실제로 부르는 것)이 실행 파일(Application)이 아니면 멈춘다(같은 이름 함수 · 별칭 · 프로필 정의 가림)
    $ccs = @(Get-Command curl.exe -ErrorAction SilentlyContinue)
    $kcs = @(Get-Command kubectl.exe -ErrorAction SilentlyContinue)
    if ($ccs.Count -eq 0 -or $kcs.Count -eq 0) { throw "curl.exe · kubectl.exe 를 찾지 못했다(PATH · 함수 · 별칭 어디에도 — curl $($ccs.Count) · kubectl $($kcs.Count)) — 아무것도 부르지 않았다" }
    $shadow = @(@($ccs[0], $kcs[0]) | Where-Object { -not (& $eq ([string]$_.CommandType) 'Application') } | ForEach-Object { "$($_.Name) = $([string]$_.CommandType)" })
    if ($shadow.Count -gt 0) { throw "첫 해석이 실행 파일(Application)이 아니다: $(& $clean ($shadow -join ' · ')) — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 부르지 않았다)" }
    $cv = @(curl.exe -q --version 2>$null)
    $global:LASTEXITCODE = 0
    $cm = $null; if ($cv.Count -gt 0) { $cm = [regex]::Match([string]$cv[0], '\Acurl ([0-9]+)\.([0-9]+)') }
    if ($null -eq $cm -or -not $cm.Success -or [int]$cm.Groups[1].Value -lt 7 -or ([int]$cm.Groups[1].Value -eq 7 -and [int]$cm.Groups[2].Value -lt 84)) { throw 'curl 7.84 이상이 필요하다(-w %header{…}) — 아무것도 부르지 않았다' }
    Write-Host "INFO curl $($cm.Groups[1].Value).$($cm.Groups[2].Value) · $([string]$ccs[0].CommandType) $(& $tilde $ccs[0].Source) · kubectl $([string]$kcs[0].CommandType) $(& $tilde $kcs[0].Source) — 읽기만 · 자격 0"
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
    # 객체 1개 읽기(get -o json — Secret 은 부르지 않는다): 돌려주는 것 = JSON 또는 $null · 실패 사유(stderr 첫 줄 · 홈 경로 ~)
    $kget = { param($ns, $kind, $name)
      $o = @(kubectl.exe --kubeconfig $kc --request-timeout=30s -n $ns get $kind $name -o json 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $el = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $j = $null
      if ($rc -eq 0) { $j = & $parseJson @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }) }
      $o = $null
      $why = ''
      if ($null -eq $j) { $why = "kubectl get $kind $name 실패(exit=$rc$(if ($el.Count) { ' · ' + (& $clean (& $hide $el[0])) }))" }
      [pscustomobject]@{ j = $j; why = $why } }
    # 무자격 GET 1회(-q · 리다이렉트 미추적 · 헤더 통째 0): 코드 · 미디어 타입 · Location 헤더(-w %header{location} — 판정에만 쓰고 쿼리는 내지 않는다)
    $wfmt = '\nT076-L1 code=%{http_code}\nT076-L2 ct=%{content_type}\nT076-L3 loc=%header{location}\n'
    $get = { param($url)
      $out = @(curl.exe -q -sS --max-time 20 -w $wfmt $url 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $lines = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
      $errl = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $out = $null
      $n = $lines.Count
      $ok = ($rc -eq 0 -and $n -ge 3 -and $lines[$n - 3] -cmatch '\AT076-L1 code=[0-9]{3}\z' -and $lines[$n - 2].StartsWith('T076-L2 ct=', [StringComparison]::Ordinal) -and $lines[$n - 1].StartsWith('T076-L3 loc=', [StringComparison]::Ordinal))
      if (-not $ok) {
        $e1 = '(오류 출력 없음)'; if ($errl.Count -gt 0) { $e1 = $errl[0] }
        $lines = $null
        return [pscustomobject]@{ ok = $false; code = ''; ct = ''; loc = ''; why = "curl exit=$rc · $(& $clean $e1)" } }
      $r = [pscustomobject]@{ ok = $true; code = $lines[$n - 3].Substring(13); ct = $lines[$n - 2].Substring(11); loc = $lines[$n - 1].Substring(12); why = '' }
      $lines = $null
      $r }
    # 기대 리터럴(gitops cb3ba13 — base/externalsecret-env.yaml data[0..11] · externalsecret-migrate.yaml · overlays/prod 인덱스 패치 · base 워크로드 셋)
    $tplEnv = @('DATABASE_URL', 'KAFKA_PASSWORD', 'DRAGONFLY_URL', 'AUTHENTIK_ISSUER', 'AUTHENTIK_JWKS_URL', 'SENTRY_DSN', 'SECRET_KEY', 'AUTHENTIK_API_TOKEN', 'AUTHENTIK_WEBHOOK_SECRET', 'OPENFGA_STORE_ID', 'OPENFGA_PRESHARED_KEY')
    $roleOf = @{ dev = 'dev_identity_admin'; prod = 'identity_admin' }
    $esData = { param($o) @(& $list (& $prop $o 'spec') 'data' | ForEach-Object { $rr = & $prop $_ 'remoteRef'; "$([string](& $prop $_ 'secretKey'))|$([string](& $prop $rr 'key'))|$([string](& $prop $rr 'property'))" }) }
    $esReady = { param($o) @(& $list (& $prop $o 'status') 'conditions' | Where-Object { (& $eq (& $prop $_ 'type') 'Ready') -and (& $eq (& $prop $_ 'status') 'True') -and (& $eq (& $prop $_ 'reason') 'SecretSynced') }).Count -eq 1 }
    $ann = { param($o, $k) [string](& $prop (& $prop (& $prop $o 'metadata') 'annotations') $k) }
    $podSpec = { param($o) & $prop (& $prop (& $prop $o 'spec') 'template') 'spec' }
    # 워크로드 보안 컨텍스트(D6 ③ — base 그대로): 컨테이너 구성 · pod runAsNonRoot · 10001 · seccomp RuntimeDefault · SA 토큰 0 · 모든 컨테이너(init 포함) 권한 상승 0 · drop [ALL] · 읽기 전용 루트 · /tmp emptyDir
    $secBad = { param($o, [string]$initW, [string]$mainW)
      $bad = @()
      $ps = & $podSpec $o
      if ($null -eq $ps) { return 'pod 템플릿 없음' }
      $ic = @(& $list $ps 'initContainers')
      $mc = @(& $list $ps 'containers')
      $in = @($ic | ForEach-Object { [string](& $prop $_ 'name') }) -join ','
      $mn = @($mc | ForEach-Object { [string](& $prop $_ 'name') }) -join ','
      if (-not (& $eq $in $initW) -or -not (& $eq $mn $mainW)) { $bad += "컨테이너 init[$(& $clean $in)] · [$(& $clean $mn)](기대 init[$initW] · [$mainW])" }
      if (-not (& $isF (& $prop $ps 'automountServiceAccountToken'))) { $bad += 'automountServiceAccountToken ≠ false' }
      $psc = & $prop $ps 'securityContext'
      if (-not (& $isT (& $prop $psc 'runAsNonRoot'))) { $bad += 'runAsNonRoot ≠ true' }
      if (-not (& $isN (& $prop $psc 'runAsUser') 10001) -or -not (& $isN (& $prop $psc 'runAsGroup') 10001)) { $bad += 'runAsUser · runAsGroup ≠ 10001' }
      if (-not (& $eq (& $prop (& $prop $psc 'seccompProfile') 'type') 'RuntimeDefault')) { $bad += 'seccompProfile ≠ RuntimeDefault' }
      $tmpVol = @(& $list $ps 'volumes' | Where-Object { $null -ne $_.PSObject.Properties['emptyDir'] } | ForEach-Object { [string](& $prop $_ 'name') })
      foreach ($c in @(@($ic) + @($mc))) {
        $cn = & $clean ([string](& $prop $c 'name'))
        $sc = & $prop $c 'securityContext'
        if (-not (& $isF (& $prop $sc 'allowPrivilegeEscalation'))) { $bad += "$cn allowPrivilegeEscalation ≠ false" }
        $drop = @(& $list (& $prop $sc 'capabilities') 'drop' | ForEach-Object { [string]$_ })
        if (-not ($drop.Count -eq 1 -and (& $eq $drop[0] 'ALL'))) { $bad += "$cn capabilities.drop ≠ [ALL]" }
        if (-not (& $isT (& $prop $sc 'readOnlyRootFilesystem'))) { $bad += "$cn readOnlyRootFilesystem ≠ true" }
        $tm = @(& $list $c 'volumeMounts' | Where-Object { & $eq (& $prop $_ 'mountPath') '/tmp' } | ForEach-Object { [string](& $prop $_ 'name') })
        if (-not ($tm.Count -eq 1 -and $tmpVol -ccontains $tm[0])) { $bad += "$cn /tmp emptyDir 마운트 없음" } }
      $bad }
    # 참조 목록(D6 ③ -migrate 분리): 컨테이너(init 포함)의 envFrom · secretKeyRef · configMapKeyRef와 pod 볼륨의 secret · configMap · projected — '종류:이름'(정렬)
    $refs = { param($o)
      $ps = & $podSpec $o
      $r = @()
      foreach ($c in @(@(& $list $ps 'initContainers') + @(& $list $ps 'containers'))) {
        $cn = [string](& $prop $c 'name')
        foreach ($ef in @(& $list $c 'envFrom')) {
          if ($null -ne (& $prop $ef 'secretRef')) { $r += "$($cn):envFrom-secret:$([string](& $prop (& $prop $ef 'secretRef') 'name'))" }
          if ($null -ne (& $prop $ef 'configMapRef')) { $r += "$($cn):envFrom-configmap:$([string](& $prop (& $prop $ef 'configMapRef') 'name'))" } }
        foreach ($ev0 in @(& $list $c 'env')) {
          $vf = & $prop $ev0 'valueFrom'
          if ($null -ne (& $prop $vf 'secretKeyRef')) { $r += "$($cn):secretKeyRef:$([string](& $prop (& $prop $vf 'secretKeyRef') 'name'))" }
          if ($null -ne (& $prop $vf 'configMapKeyRef')) { $r += "$($cn):configMapKeyRef:$([string](& $prop (& $prop $vf 'configMapKeyRef') 'name'))" } } }
      foreach ($v in @(& $list $ps 'volumes')) {
        if ($null -ne (& $prop $v 'secret')) { $r += "volume-secret:$([string](& $prop (& $prop $v 'secret') 'secretName'))" }
        if ($null -ne (& $prop $v 'configMap')) { $r += "volume-configmap:$([string](& $prop (& $prop $v 'configMap') 'name'))" }
        foreach ($src in @(& $list (& $prop $v 'projected') 'sources')) {
          if ($null -ne (& $prop $src 'secret')) { $r += "volume-projected-secret:$([string](& $prop (& $prop $src 'secret') 'name'))" }
          if ($null -ne (& $prop $src 'configMap')) { $r += "volume-projected-configmap:$([string](& $prop (& $prop $src 'configMap') 'name'))" } } }
      (@($r) | Sort-Object) -join ' ' }
    $refWeb = (@('startup-check:envFrom-configmap:identity-admin-config', 'startup-check:envFrom-secret:identity-admin-env', 'web:envFrom-configmap:identity-admin-config', 'web:envFrom-secret:identity-admin-env', 'relay:envFrom-configmap:identity-admin-config', 'relay:envFrom-secret:identity-admin-env', 'volume-secret:pg-main-ca', 'volume-secret:jt-kafka-cluster-ca-cert') | Sort-Object) -join ' '
    $refCelery = (@('celery:envFrom-configmap:identity-admin-config', 'celery:envFrom-secret:identity-admin-env', 'volume-secret:pg-main-ca') | Sort-Object) -join ' '
    $refJob = (@('migrate:envFrom-secret:identity-admin-migrate', 'volume-secret:pg-main-ca') | Sort-Object) -join ' '
    # 프로브(D6 ③ — base deployment.yaml): web liveness /healthz 20 · readiness /ready 5 · startup /ready 30 × 5 · timeout 3 · port http / relay liveness tcpSocket metrics(9464) 20 · 3 만 /
    #   startup-check · celery · migrate 프로브 0 / 어느 프로브도 /health 를 쓰지 않는다
    $hg = { param($pr, $path, $period, $fail)
      $g = & $prop $pr 'httpGet'
      ($null -ne $pr) -and (& $eq (& $prop $g 'path') $path) -and (& $eq ([string](& $prop $g 'port')) 'http') -and (& $isN (& $prop $pr 'periodSeconds') $period) -and (& $isN (& $prop $pr 'timeoutSeconds') 3) -and ($fail -eq 0 -or (& $isN (& $prop $pr 'failureThreshold') $fail)) }
    $probeBad = { param($dep, $cel, $job)
      $bad = @()
      $all = @()
      foreach ($w in @($dep, $cel, $job)) { $ps = & $podSpec $w; $all += @(& $list $ps 'initContainers') + @(& $list $ps 'containers') }
      $by = @{}
      foreach ($c in $all) { $by[[string](& $prop $c 'name')] = $c }
      $web = $by['web']; $relay = $by['relay']
      if ($null -eq $web -or -not (& $hg (& $prop $web 'livenessProbe') '/healthz' 20 0)) { $bad += 'web liveness ≠ GET /healthz(http) 20 s · 3 s' }
      if ($null -eq $web -or -not (& $hg (& $prop $web 'readinessProbe') '/ready' 5 0)) { $bad += 'web readiness ≠ GET /ready(http) 5 s · 3 s' }
      if ($null -eq $web -or -not (& $hg (& $prop $web 'startupProbe') '/ready' 5 30)) { $bad += 'web startup ≠ GET /ready(http) 30 × 5 s · 3 s' }
      $rl = & $prop $relay 'livenessProbe'
      $mport = @(& $list $relay 'ports' | Where-Object { & $eq (& $prop $_ 'name') 'metrics' } | ForEach-Object { & $prop $_ 'containerPort' })
      if ($null -eq $relay -or $null -eq $rl -or -not (& $eq ([string](& $prop (& $prop $rl 'tcpSocket') 'port')) 'metrics') -or $null -ne (& $prop $rl 'httpGet') -or -not ($mport.Count -eq 1 -and (& $isN $mport[0] 9464)) -or -not (& $isN (& $prop $rl 'periodSeconds') 20) -or -not (& $isN (& $prop $rl 'timeoutSeconds') 3)) { $bad += 'relay liveness ≠ tcpSocket metrics(9464) 20 s · 3 s' }
      if ($null -ne $relay -and ($null -ne (& $prop $relay 'readinessProbe') -or $null -ne (& $prop $relay 'startupProbe'))) { $bad += 'relay 에 readiness · startup 프로브가 있다' }
      foreach ($nm in @('startup-check', 'celery', 'migrate')) { $c = $by[$nm]; if ($null -eq $c -or $null -ne (& $prop $c 'livenessProbe') -or $null -ne (& $prop $c 'readinessProbe') -or $null -ne (& $prop $c 'startupProbe')) { $bad += "$nm 프로브 0 아님(또는 컨테이너 없음)" } }
      foreach ($c in $all) { foreach ($pk in @('livenessProbe', 'readinessProbe', 'startupProbe')) { if (& $eq (& $prop (& $prop (& $prop $c $pk) 'httpGet') 'path') '/health') { $bad += "$(& $clean ([string](& $prop $c 'name'))) $pk 가 /health 를 쓴다" } } }
      $bad }
    foreach ($ev in @('dev', 'prod')) {
      $ns = "jt-$ev"
      # ⓪ Application
      $a = & $kget 'argocd' 'applications.argoproj.io' "identity-admin-$ev"
      $sy = & $prop (& $prop $a.j 'status') 'sync'
      $sync = [string](& $prop $sy 'status'); $rev = [string](& $prop $sy 'revision')
      $hl = [string](& $prop (& $prop (& $prop $a.j 'status') 'health') 'status')
      $ph = [string](& $prop (& $prop (& $prop $a.j 'status') 'operationState') 'phase')
      $bad = @()
      if ($null -eq $a.j) { $bad += $a.why }
      else {
        if (-not (& $eq $sync 'Synced')) { $bad += "sync $(& $clean $sync)" }
        if (-not (& $eq $hl 'Healthy')) { $bad += "health $(& $clean $hl)" }
        if (-not (& $eq $rev $ExpectedRevision)) { $bad += "revision $(if ($rev -cmatch '\A[0-9a-f]{7,40}\z') { $rev } else { '(꼴 밖)' })" }
        if (-not (& $eq $ph 'Succeeded')) { $bad += "operationState $(& $clean $ph)" } }
      & $check "l8 $ev ⓪ Application identity-admin-$ev — Synced · Healthy · revision = 입력 · operationState Succeeded" ($bad.Count -eq 0) ($bad -join ' · ')
      $a = $null
      # ① ② ExternalSecret 둘
      $ee = & $kget $ns 'externalsecrets.external-secrets.io' 'identity-admin-env'
      $em = & $kget $ns 'externalsecrets.external-secrets.io' 'identity-admin-migrate'
      & $check "l8 $ev ① ES identity-admin-env Ready=True(SecretSynced)" ($null -ne $ee.j -and (& $esReady $ee.j)) $(if ($null -eq $ee.j) { $ee.why } else { 'Ready=True · SecretSynced 조건 없음' })
      & $check "l8 $ev ① ES identity-admin-migrate Ready=True(SecretSynced)" ($null -ne $em.j -and (& $esReady $em.j)) $(if ($null -eq $em.j) { $em.why } else { 'Ready=True · SecretSynced 조건 없음' })
      $bad = @()
      if ($null -eq $ee.j) { $bad += $ee.why }
      else {
        $st = & $prop (& $prop $ee.j 'spec') 'secretStoreRef'
        if (-not (& $eq (& $prop $st 'name') "vault-$ev") -or -not (& $eq (& $prop $st 'kind') 'ClusterSecretStore')) { $bad += "store $(& $clean ([string](& $prop $st 'kind'))) $(& $clean ([string](& $prop $st 'name')))(기대 ClusterSecretStore vault-$ev)" }
        $tk = @(& $names (& $prop (& $prop (& $prop (& $prop $ee.j 'spec') 'target') 'template') 'data'))
        if (-not ($tk.Count -eq 11 -and @($tplEnv | Where-Object { $tk -ccontains $_ }).Count -eq 11)) { $bad += "템플릿 키 $($tk.Count)개(정확히 11 — gitops base)" }
        $dl = @(& $esData $ee.j)
        $r = $roleOf[$ev]
        $want = @("db_username|$ev/db/$r/app|username", "db_password|$ev/db/$r/app|password", "kafka_password|$ev/kafka/identity-admin|password", "dragonfly_url|$ev/dragonfly/identity-admin|url", "authentik_issuer|$ev/authentik/identity-admin|issuer", "authentik_jwks_url|$ev/authentik/identity-admin|jwks_url", "sentry_dsn|$ev/sentry/identity-admin|dsn", "secret_key|$ev/django/identity-admin|secret_key", "authentik_api_token|$ev/authentik/identity-admin|api_token", "authentik_webhook_secret|$ev/authentik/webhooks/identity-admin|secret", "openfga_store_id|$ev/openfga/store_id|store_id", "openfga_preshared_key|$ev/openfga/preshared|key")
        $keys = @($dl | ForEach-Object { $_.Split('|')[1] })
        if (@($keys | Where-Object { $_.Contains('/owner') }).Count -gt 0) { $bad += '원격 키에 /owner 가 있다(런타임 env 에 owner 자격)' }
        if (@($keys | Where-Object { -not $_.StartsWith("$ev/", [StringComparison]::Ordinal) }).Count -gt 0) { $bad += "원격 키가 $ev/ 밖이다(다른 env 잔재)" }
        if (-not (& $eq ($dl -join ' ') ($want -join ' '))) { $bad += "data[] $($dl.Count)줄이 gitops 와 다르다(secretKey|key|property 12줄)" } }
      & $check "l8 $ev ② ES identity-admin-env 스펙 — ClusterSecretStore vault-$ev · 템플릿 키 정확히 11 · 원격 키 12줄 = gitops · /owner 0 · $ev/ 접두" ($bad.Count -eq 0) ($bad -join ' · ')
      $bad = @()
      if ($null -eq $em.j) { $bad += $em.why }
      else {
        $st = & $prop (& $prop $em.j 'spec') 'secretStoreRef'
        if (-not (& $eq (& $prop $st 'name') "vault-$ev") -or -not (& $eq (& $prop $st 'kind') 'ClusterSecretStore')) { $bad += "store $(& $clean ([string](& $prop $st 'kind'))) $(& $clean ([string](& $prop $st 'name')))(기대 ClusterSecretStore vault-$ev)" }
        $tk = @(& $names (& $prop (& $prop (& $prop (& $prop $em.j 'spec') 'target') 'template') 'data'))
        if (-not ($tk.Count -eq 1 -and (& $eq $tk[0] 'DATABASE_OWNER_URL'))) { $bad += "템플릿 키 $($tk.Count)개(정확히 {DATABASE_OWNER_URL})" }
        $r = $roleOf[$ev]
        if (-not (& $eq (@(& $esData $em.j) -join ' ') "db_username|$ev/db/$r/owner|username db_password|$ev/db/$r/owner|password")) { $bad += "원격 키 ≠ $ev/db/$r/owner(username · password)" }
        if (-not (& $eq (& $ann $em.j 'argocd.argoproj.io/hook') 'PreSync') -or -not (& $eq (& $ann $em.j 'argocd.argoproj.io/hook-delete-policy') 'BeforeHookCreation')) { $bad += 'hook ≠ PreSync · BeforeHookCreation' }
        if (-not (& $eq (& $ann $em.j 'argocd.argoproj.io/sync-wave') '-1')) { $bad += "sync-wave $(& $clean (& $ann $em.j 'argocd.argoproj.io/sync-wave'))(기대 -1 — Job wave 0 보다 앞)" } }
      & $check "l8 $ev ② ES identity-admin-migrate 스펙 — vault-$ev · 키 {DATABASE_OWNER_URL} · 원격 키 $ev/db/$($roleOf[$ev])/owner · PreSync · BeforeHookCreation · wave -1(Job 0 보다 앞)" ($bad.Count -eq 0) ($bad -join ' · ')
      $ee = $null; $em = $null
      # ③ 워크로드 셋
      $dw = & $kget $ns 'deployments.apps' 'identity-admin'
      $dc = & $kget $ns 'deployments.apps' 'identity-admin-celery'
      $dj = & $kget $ns 'jobs.batch' 'identity-admin-migrate'
      $bw = @(); if ($null -eq $dw.j) { $bw = @($dw.why) } else { $bw = @(& $secBad $dw.j 'startup-check' 'web,relay') }
      & $check "l8 $ev ③ Deployment identity-admin — init startup-check · web · relay · runAsNonRoot · 10001 · RuntimeDefault · SA 토큰 0 · 권한 상승 0 · drop [ALL] · 읽기 전용 루트 · /tmp emptyDir" ($bw.Count -eq 0) ($bw -join ' · ')
      $bc = @(); if ($null -eq $dc.j) { $bc = @($dc.why) } else { $bc = @(& $secBad $dc.j '' 'celery') }
      & $check "l8 $ev ③ Deployment identity-admin-celery — celery · 같은 보안 컨텍스트 · /tmp emptyDir" ($bc.Count -eq 0) ($bc -join ' · ')
      $bj = @()
      if ($null -eq $dj.j) { $bj = @("$($dj.why) — ttlSecondsAfterFinished 7일이 지났거나 sync 전") }
      else {
        $bj = @(& $secBad $dj.j '' 'migrate')
        if (-not (& $eq (& $ann $dj.j 'argocd.argoproj.io/hook') 'PreSync') -or -not (& $eq (& $ann $dj.j 'argocd.argoproj.io/hook-delete-policy') 'BeforeHookCreation') -or -not (& $eq (& $ann $dj.j 'argocd.argoproj.io/sync-wave') '0')) { $bj += 'Job hook ≠ PreSync · BeforeHookCreation · wave 0' } }
      & $check "l8 $ev ③ Job identity-admin-migrate — migrate · 같은 보안 컨텍스트 · /tmp emptyDir · PreSync · BeforeHookCreation · wave 0" ($bj.Count -eq 0) ($bj -join ' · ')
      $bp = @()
      if ($null -eq $dw.j -or $null -eq $dc.j -or $null -eq $dj.j) { $bp = @('워크로드 셋 중 읽지 못한 것이 있다(위 ③ 줄)') } else { $bp = @(& $probeBad $dw.j $dc.j $dj.j) }
      & $check "l8 $ev ③ 프로브 — web liveness /healthz 20 · readiness /ready 5 · startup /ready 30×5 · timeout 3 · relay tcpSocket 9464 만 · 그 밖 0 · /health 0" ($bp.Count -eq 0) ($bp -join ' · ')
      $bs = @()
      if ($null -eq $dw.j -or $null -eq $dc.j -or $null -eq $dj.j) { $bs = @('워크로드 셋 중 읽지 못한 것이 있다(위 ③ 줄)') }
      else {
        $rw = & $refs $dw.j; $rc2 = & $refs $dc.j; $rj = & $refs $dj.j
        if (-not (& $eq $rw $refWeb)) { $bs += "Deployment identity-admin 참조 ≠ gitops(config · -env · CA 볼륨 둘)$(if ($rw.Contains('identity-admin-migrate')) { ' — identity-admin-migrate 참조 있음' })" }
        if (-not (& $eq $rc2 $refCelery)) { $bs += "Deployment identity-admin-celery 참조 ≠ gitops(config · -env · pg CA)$(if ($rc2.Contains('identity-admin-migrate')) { ' — identity-admin-migrate 참조 있음' })" }
        if (-not (& $eq $rj $refJob)) { $bs += "Job 참조 ≠ gitops(envFrom identity-admin-migrate · pg CA 볼륨 — ConfigMap 0 · -env 0)$(if ($rj.Contains('identity-admin-env')) { ' — identity-admin-env 참조 있음' })" } }
      & $check "l8 $ev ③ -migrate 분리 — Deployment 둘 = identity-admin-config · identity-admin-env · CA 볼륨(-migrate 0) · Job 자격 Secret = identity-admin-migrate 뿐(볼륨은 CA pg-main-ca · ConfigMap 0)" ($bs.Count -eq 0) ($bs -join ' · ')
      $dw = $null; $dc = $null; $dj = $null
      # ④ init startup-check 로그(그 줄만 낸다 — 런타임 env 에 DATABASE_OWNER_URL 이 있으면 실패하는 장치의 증거)
      $lg = @(kubectl.exe --kubeconfig $kc --request-timeout=30s -n "jt-$ev" logs deploy/identity-admin -c startup-check 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $okl = @($lg | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Where-Object { & $eq ([string]$_).Trim() 'startup_check: OK' }).Count
      $lge = @($lg | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $lg = $null
      & $check "l8 $ev ④ init startup-check 로그에 「startup_check: OK」" ($rc -eq 0 -and $okl -ge 1) "exit=$rc · 그 줄 $okl 개$(if ($lge.Count) { ' · ' + (& $clean (& $hide $lge[0])) })"
      if ($rc -eq 0 -and $okl -ge 1) { $info.Add("l8 $ev ④ startup-check: startup_check: OK") }
      # ⑤ 무자격 m2m /health(편차 후보 6 — Access 401 · redirect 없음)
      $u = & $get "https://identity-m2m-$ev.joshuatech.dev/health"
      $bad = @()
      if (-not $u.ok) { $bad += $u.why }
      else {
        if (-not (& $eq $u.code '401')) { $bad += "응답 $(& $clean $u.code)" }
        if ($u.loc.Length -gt 0) { $bad += 'Location 있음(리다이렉트)' }
        $info.Add("l8 $ev ⑤ 무자격 GET /health 미디어 타입 = $(if ($u.ct) { & $clean (([string]$u.ct).Split(';')[0].Trim()) } else { '(없음)' })") }
      & $check "l8 $ev ⑤ 무자격 GET https://identity-m2m-$ev.joshuatech.dev/health → 401 · Location 없음(Access — 계약 C11 · 편차 후보 6)" ($bad.Count -eq 0) ($bad -join ' · ')
      $u = $null }
    # INFO(합격선 아님 — US4 AC6 · T085): admin 무자격 → 302 · Location 은 scheme://host/path 만 낸다(쿼리의 meta 토큰 0 — tests/platform/ingress.tests.ps1 Test-AccessLocation 꼴)
    $ad = & $get 'https://admin.joshuatech.dev/identity-admin/admin/'
    if (-not $ad.ok) { $info.Add("l8 admin 무자격 GET https://admin.joshuatech.dev/identity-admin/admin/ → 응답 없음($($ad.why)) — US4 AC6 · 합격선 아님") }
    else {
      $safe = '(Location 없음)'
      $lok = $false
      if ($ad.loc.Length -gt 0) {
        $uri = $null
        try { $uri = [System.Uri]::new($ad.loc) } catch { $uri = $null }
        if ($null -ne $uri -and $uri.IsAbsoluteUri) {
          $safe = "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"
          $lok = (& $eq $uri.Scheme 'https') -and [string]::Equals($uri.Host, 'joshua-tech.cloudflareaccess.com', [StringComparison]::OrdinalIgnoreCase) -and $uri.AbsolutePath.StartsWith('/cdn-cgi/access/login/', [StringComparison]::Ordinal) }
        else { $safe = '(Location 해석 불가 — 값 미출력)' }
        $uri = $null }
      $info.Add("l8 admin 무자격 GET https://admin.joshuatech.dev/identity-admin/admin/ → $(& $clean $ad.code) · Location $(& $clean $safe)$(if ($lok) { ' — Access 로그인 꼴(호스트 joshua-tech.cloudflareaccess.com · 경로 /cdn-cgi/access/login/)' } else { ' — Access 로그인 꼴 아님' }) · US4 AC6 · 합격선 아님(T085)") }
    $ad = $null
    $done = $true }
  catch {
    $stopWhy = [string]$_.Exception.Message
    if (-not [string]::IsNullOrEmpty($HOME)) { $stopWhy = [regex]::Replace($stopWhy, '(?i)' + [regex]::Escape($HOME), '~') } }
  finally {
    Remove-Variable a, ee, em, dw, dc, dj, lg, u, ad, uri -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T076 L-8 라이브 사다리 결과(identity-admin dev · prod ⓪–⑤ · 비밀 0 — tester 보고에 그대로) ---'
    foreach ($k in $res.Keys) {
      if (([string]$res[$k]).StartsWith('PASS', [StringComparison]::Ordinal)) { Write-Host "PASS $k" } else { Write-Host "FAIL $k — $(([string]$res[$k]) -replace '\p{Cc}', '?')" } }
    foreach ($l in $info) { Write-Host "INFO $(([string]$l) -replace '\p{Cc}', '?')" }
    if ($stopWhy.Length -gt 0) { Write-Host "STOP $($stopWhy -replace '\p{Cc}', '?')" }
    $nPass = @($res.Values | Where-Object { ([string]$_).StartsWith('PASS', [StringComparison]::Ordinal) }).Count
    if ($done -and $res.Count -eq 24 -and $nPass -eq 24) { Write-Host 'l8=PASS 24/24' } else { Write-Host "l8=FAIL $nPass/24" } }
  if ($done -and $res.Count -eq 24 -and $nPass -eq 24) { exit 0 }
  exit 1
}
