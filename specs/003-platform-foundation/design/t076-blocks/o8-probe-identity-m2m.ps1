param([string]$ExpectedSha = '')
& {
  # ===== T076 O-8 블록 — identity-m2m-dev · -prod 탐침(tester 2차 · 읽기만 · 쓰기 0) · 자격 = Vault e2e-reader 로 읽은 tester-m2m(UD-15) · 파일로만 실행 =====
  # 파생(설계 t076-design.md D3 · D4 ①–⑫ · D10 · UD-15 · UD-16): T075 o5-probe-identity-m2m.ps1 의 바이트 사본에서 — 모듈 로깅 4키 가드 · 실효 확인 · $eq · $parseJson · $prop ·
  #   $names · $check · $tilde · curl 7.84 확인 · stdin 헤더(-H @-) · -w 허용 목록 · 제어 문자 치환 · $Error 정리는 그대로 두고 입력(Read-Host → param) · tofu 0 ·
  #   자격 출처(Vault HTTP API) · 가드(VAULT_* · Transcription · 실행 파일 위치 · agent-view whoami) · 판정(dev → prod · a + b–e) · 끝 줄 · 종료 코드를 바꿨다
  # 실행(tester · Git Bash · Bash 도구 timeout 600000): chcp.com 65001 >/dev/null; pwsh -NoProfile -File '<이 파일의 절대 경로>' -ExpectedSha <배포 이미지 revision — main 커밋 40자 소문자 hex(컨트롤러가 준다)>; echo "exit=$?"
  #   판정은 끝 줄과 종료 코드 · 한글 줄은 증거. 입력은 param 뿐(Read-Host 0) — 꼴이 아니거나 다른 인자가 있으면 아무것도 보내지 않고 멈춘다 · 끝 줄 o8=PASS 10/10 또는 o8=FAIL k/10 · 종료 코드 0 = 전부 PASS 일 때만
  # 사전: ① 운영자 O-9 가 이 라이브 창에 발급한 vault 전용 1시간 JWT — %LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt(DPAPI CurrentUser). 이 블록은 읽기만 하고 지우지 않는다
  #   (UD-16 — 그 1시간 안 재사용 · 삭제는 운영자 O-9 의 정지점 단어 clear) ② agent-view kubeconfig ~\.kube\agent-view.yaml(8h · vault ns pods/portforward) ③ e2e-reader 정책 · kv 시드(T076 W-7 · apply) 뒤
  # 흐름: 입력 → 가드(모듈 로깅 · 실효 · 환경 변수 · Transcription · 실행 파일(첫 해석 Application · 위치) · curl 7.84) → whoami → JWT(꼴 · 클레임) → port-forward(--address 127.0.0.1 · 포트는
  #   kubectl 이 고른다 · Forwarding 줄 정확히 한 줄) · seal-status(cluster_name) → 로그인 직전 재확인 → 로그인(본문 stdin) → capabilities-self 관문 → kv 읽기(키 둘 · 꼴) → 탐침 dev → prod
  #   (판정 a · b–e · INFO) → finally(revoke-self · port-forward 종료 · 정리 · 결과)
  # 대조 키(C-8): 모든 Access 요청에 쿼리 ?t076=<nonce> 와 비밀 아닌 X-Request-ID <nonce>-<env>-<id> 를 싣는다 — pod 로그 request 필드에는 쿼리가 없어(observability.py format_request)
  #   pod 줄은 request_id 로만 대조된다. INFO o8 start 는 첫 요청보다 60 s 앞이다(노드 시계 차이 여유 — C-8 --since-time)
  # 원칙: JWT · Vault 토큰 · client_id · client_secret · 쿠키는 출력 · 파일 · argv · 환경 변수 0(값은 이 프로세스 변수와 curl stdin 으로만) · 응답은 상태 코드 · -w 허용 목록 ·
  #   본문 필드만 · 응답에서 온 글자는 제어 문자 → ? · 160자 · 판정 불가 = FAIL · 출력은 Write-Host 뿐 · Set-Cookie 를 읽지도 내지도 않는다(-i · -D · -v · -c · -b 0)
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
  $vtok = ''
  $vbase = ''
  $pf = $null
  $jwt = ''
  $cid = ''
  $csec = ''
  $cred = $null
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
    $hit = { param($v) [string]::Equals(([string]$v).Trim(), 'HIT', [StringComparison]::OrdinalIgnoreCase) }
    # Access 요청 1회(GET): $hdr = 헤더 줄 배열(자격 · X-Request-ID — stdin -H @- 로만). -w 허용 목록 7개(모두 비밀 아님)를 줄마다 표식으로 낸다 — 본문 = 표식 일곱 줄 앞의 줄들
    $wfmt = '\nT076-W1 code=%{http_code}\nT076-W2 ct=%{content_type}\nT076-W3 size=%{size_download}\nT076-W4 xrid=%header{x-request-id}\nT076-W5 cc=%header{cache-control}\nT076-W6 cfc=%header{cf-cache-status}\nT076-W7 ray=%header{cf-ray}\n'
    $wkeys = @('code', 'ct', 'size', 'xrid', 'cc', 'cfc', 'ray')
    $get = { param($url, $hdr)
      $at = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
      $out = @($hdr | curl.exe -q -sS --max-time 20 -H '@-' -w $wfmt $url 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $lines = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
      $errl = @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $out = $null
      $f = @{}
      $iw = $lines.Count - 7
      $okw = ($rc -eq 0 -and $iw -ge 0)
      for ($k = 0; $okw -and $k -lt 7; $k++) {
        $pfx = "T076-W$($k + 1) $($wkeys[$k])="
        if ($lines[$iw + $k].StartsWith($pfx, [StringComparison]::Ordinal)) { $f[$wkeys[$k]] = $lines[$iw + $k].Substring($pfx.Length) } else { $okw = $false } }
      if ($okw -and ([string]$f['code']) -cnotmatch '\A[0-9]{3}\z') { $okw = $false }
      if (-not $okw) {
        $e1 = '(오류 출력 없음)'; if ($errl.Count -gt 0) { $e1 = $errl[0] }
        return [pscustomobject]@{ ok = $false; code = ''; ct = ''; size = ''; xrid = ''; cc = ''; cfc = ''; ray = ''; body = @(); at = $at; why = "curl exit=$rc · $(& $clean $e1)" } }
      $body = @(); if ($iw -gt 0) { $body = @($lines[0..($iw - 1)]) }
      [pscustomobject]@{ ok = $true; code = $f['code']; ct = $f['ct']; size = $f['size']; xrid = $f['xrid']; cc = $f['cc']; cfc = $f['cfc']; ray = $f['ray']; body = $body; at = $at; why = '' } }
    # Vault HTTP API 1회(port-forward http://127.0.0.1:<빈 포트> — vault CLI 0 · ~/.vault-token · 토큰 도우미 · VAULT_* 면 없음): seal = 무자격 GET · login = 본문 stdin(--data-binary @-) ·
    #   tok = 토큰 헤더 stdin(-H @-) + 비밀 아닌 본문 argv(--data — 비면 GET). 돌려주는 것 = 코드 · JSON(비밀이 들 수 있다 — 꺼내고 곧바로 지운다) · curl 종료 코드
    $vfmt = '\nT076-V code=%{http_code}\n'
    $vreq = { param($mode, $path, $stdin, $data)
      $u = $vbase + $path
      if (& $eq $mode 'seal') { $out = @(curl.exe -q -sS --max-time 5 -w $vfmt $u 2>&1) }
      elseif (& $eq $mode 'login') { $out = @($stdin | curl.exe -q -sS --max-time 20 -H 'Content-Type: application/json' --data-binary '@-' -w $vfmt $u 2>&1) }
      elseif ([string]::IsNullOrEmpty($data)) { $out = @($stdin | curl.exe -q -sS --max-time 20 -H '@-' -w $vfmt $u 2>&1) }
      else { $out = @($stdin | curl.exe -q -sS --max-time 20 -H '@-' --data $data -w $vfmt $u 2>&1) }
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $lines = @($out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ })
      $out = $null
      $n = $lines.Count
      $m = $null; if ($n -ge 1) { $m = [regex]::Match($lines[$n - 1], '\AT076-V code=([0-9]{3})\z') }
      if ($rc -ne 0 -or $null -eq $m -or -not $m.Success) { $lines = $null; return [pscustomobject]@{ ok = $false; code = ''; json = $null; rc = $rc } }
      $j = $null; if ($n -gt 1) { $j = & $parseJson @($lines[0..($n - 2)]) }
      $lines = $null
      [pscustomobject]@{ ok = $true; code = $m.Groups[1].Value; json = $j; rc = $rc } }
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 보내지 않았다)' }
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 로그인 응답(Vault 토큰) · kv 응답 원문(client_secret)이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 보내지 않았다)" }
    # 모듈 로깅 실효 상태(T075 블록 규약 그대로 — 리뷰 KB-2 · KB2-1): 정책 레지스트리가 비어도 powershell.config.json(시스템 = $PSHOME · 사용자 = 문서 폴더 PowerShell)이나
    #   pwsh -SettingsFile 로 켜질 수 있다 — 이 블록의 값이 지나가는 cmdlet 이 사는 넷(Core 스냅인 · Utility · Security · Management)의 LogPipelineExecutionDetails(이 프로세스의 실효 값)를 본다.
    #   설정 파일 두 곳은 값과 무관하게 판정한다: 텍스트에 ModuleLogging(대소문자 무관) 또는 역슬래시-u 이스케이프가 있으면 멈춘다 · 텍스트로만 읽는다(ConvertFrom-Json 0) · 확인 못 하면 멈춘다
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 로그인 응답(Vault 토큰) · kv 응답 원문(client_secret)이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 보내지 않았다)" }
    # ① 입력(D3 · A-1): param 뿐 — 파일 실행 · 다른 인자 0 · -ExpectedSha 꼴을 네트워크 · kubectl 호출 전에 판정한다
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -ExpectedSha <40자 hex>) — 아무것도 보내지 않았다' }
    if (@($script:args).Count -gt 0) { throw "입력은 -ExpectedSha 하나뿐이다 — 그 밖의 인자 $(@($script:args).Count)개(값 미출력) · 아무것도 보내지 않았다" }
    if ($ExpectedSha -cnotmatch '\A[0-9a-f]{40}\z') { throw '입력 -ExpectedSha 가 40자 소문자 hex 가 아니다(아무것도 보내지 않았다)' }
    # ② 환경 변수(D4 ② · T075 KB-1 · KB2-2): curl 신뢰 앵커 · TLS 키 기록 · 프록시(대소문자 무관) · VAULT_*(vault CLI · 토큰 도우미 면 — 이 블록은 vault CLI 를 쓰지 않지만 있으면 멈춘다) — 이름만 낸다
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY') -contains $_.Name -or $_.Name -like 'VAULT_*' } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 curl · Vault 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. 그 변수가 없는 새 창에서 다시(아무것도 보내지 않았다)" }
    # Transcription(D4 ② · B-03): 켜져 있으면 이 창의 화면이 파일로 남는다 — 레지스트리 PowerShellCore 두 키(UseWindowsPowerShellPolicySetting 값이 1 이면 Windows PowerShell 두 키 더) ·
    #   설정 파일 두 곳의 낱말 Transcription(대소문자 무관 · 값 무관 — 이스케이프 꼴은 위 모듈 로깅 판정의 역슬래시-u 가 잡는다)
    $trKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\Transcription')
    $trWin = $false
    foreach ($tk in $trKeys) { if ((& $prop (Get-ItemProperty $tk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $trWin = $true } }
    if ($trWin) { $trKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription') }
    $trOn = @($trKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableTranscripting') -eq 1 })
    $trCfgOn = @(@((Join-Path $PSHOME 'powershell.config.json'), $mlUser) | Where-Object { $_.Length -gt 0 -and (Test-Path -LiteralPath $_) -and ((Get-Content -Raw -LiteralPath $_) -cmatch '(?i:Transcription)') })
    if ($trOn.Count -gt 0 -or $trCfgOn.Count -gt 0) { throw "PowerShell Transcription 정책이 켜져 있다(레지스트리: $($trOn -join ', ') · 설정 파일(값 무관): $($trCfgOn -join ', ')) — 이 창의 출력이 파일로 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 보내지 않았다)" }
    # ③ 실행 파일(D4 ③ · B-03② · S-10): curl.exe · kubectl.exe 의 형식 필터 없는 Get-Command 첫 해석(= 호출 'curl.exe …' 가 실제로 부르는 것)이 실행 파일(Application)이 아니면 멈춘다 —
    #   같은 이름 함수 · 별칭(프로필 정의 포함)이 가리면 그쪽이 stdin 헤더(자격)를 받는다 · 해석 경로가 저장소 아래이거나 TEMP · TMP 아래면 멈춘다(심어 둔 가짜 — INFO 가 아니라 판정)
    $repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
    $roots = @(@($repo, $env:TEMP, $env:TMP) | Where-Object { -not [string]::IsNullOrEmpty($_) } | ForEach-Object { ([System.IO.Path]::GetFullPath([string]$_)).TrimEnd('\') + '\' })
    $ccs = @(Get-Command curl.exe -ErrorAction SilentlyContinue)
    $kcs = @(Get-Command kubectl.exe -ErrorAction SilentlyContinue)
    if ($ccs.Count -eq 0 -or $kcs.Count -eq 0) { throw "curl.exe · kubectl.exe 를 찾지 못했다(PATH · 함수 · 별칭 어디에도 — curl $($ccs.Count) · kubectl $($kcs.Count)) — 아무것도 보내지 않았다" }
    $shadow = @(@($ccs[0], $kcs[0]) | Where-Object { -not (& $eq ([string]$_.CommandType) 'Application') } | ForEach-Object { "$($_.Name) = $([string]$_.CommandType)" })
    if ($shadow.Count -gt 0) { throw "첫 해석이 실행 파일(Application)이 아니다: $(& $clean ($shadow -join ' · ')) — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 보내지 않았다)" }
    $exeBad = @(@($ccs[0], $kcs[0]) | Where-Object { $s = [System.IO.Path]::GetFullPath([string]$_.Source); @($roots | Where-Object { $s.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0 } | ForEach-Object { "$($_.Name) $(& $tilde $_.Source)" })
    if ($exeBad.Count -gt 0) { throw "실행 파일이 저장소 아래이거나 TEMP · TMP 아래에 있다: $($exeBad -join ' · ') — 심어 둔 실행 파일일 수 있다. 시스템 설치본이 PATH 앞에 오는 창에서 다시(아무것도 보내지 않았다)" }
    $csrc = & $tilde $ccs[0].Source
    $ksrc = & $tilde $kcs[0].Source
    $cv = @(curl.exe -q --version 2>$null)
    $global:LASTEXITCODE = 0
    $cm = $null; if ($cv.Count -gt 0) { $cm = [regex]::Match([string]$cv[0], '\Acurl ([0-9]+)\.([0-9]+)') }
    if ($null -eq $cm -or -not $cm.Success -or [int]$cm.Groups[1].Value -lt 7 -or ([int]$cm.Groups[1].Value -eq 7 -and [int]$cm.Groups[2].Value -lt 84)) { throw 'curl 7.84 이상이 필요하다(-w %header{…}) — 아무것도 보내지 않았다' }
    Write-Host "INFO curl $($cm.Groups[1].Value).$($cm.Groups[2].Value) · $([string]$ccs[0].CommandType) $csrc · kubectl $([string]$kcs[0].CommandType) $ksrc — 쓰기 0 · 자격 · 토큰 · JWT 는 stdin 으로만"
    # ④ kubeconfig(D4 ④): 리터럴 경로 · KUBECONFIG 환경 변수 무시(--kubeconfig 를 늘 준다) · 신원 = agent-view 가 아니면 멈춘다
    $kc = Join-Path $HOME '.kube\agent-view.yaml'
    if (-not (Test-Path -LiteralPath $kc)) { throw 'agent-view kubeconfig 가 없다(~\.kube\agent-view.yaml) — 컨트롤러 · 운영자에게 알린다(아무것도 보내지 않았다)' }
    $wo = @(kubectl.exe --kubeconfig $kc --request-timeout=20s auth whoami -o 'jsonpath={.status.userInfo.username}' 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $wl = @($wo | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { [string]$_ } | Where-Object { $_.Length -gt 0 })
    $we = @($wo | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
    $wo = $null
    if ($rc -ne 0 -or $wl.Count -ne 1 -or -not (& $eq $wl[0] 'system:serviceaccount:kube-system:agent-view')) { throw "kubectl auth whoami 가 agent-view 가 아니다(exit=$rc · 사용자 $(if ($wl.Count) { & $clean ($wl -join ' ') } else { '(없음)' })$(if ($we.Count) { ' · ' + (& $clean (& $hide $we[0])) })) — agent-view kubeconfig 로만 실행한다(아무것도 보내지 않았다)" }
    Write-Host 'OK   kubectl auth whoami = system:serviceaccount:kube-system:agent-view'
    # ⑤ JWT(D4 ⑤ · UD-16): 운영자 O-9 가 DPAPI(CurrentUser)로 쓴 파일 — 복호해 변수에만 둔다 · 파일은 지우지 않는다 · 꼴(점 둘 · base64url) · 클레임(aud · sub · exp · iat)
    if ([string]::IsNullOrEmpty($env:LOCALAPPDATA)) { throw 'LOCALAPPDATA 가 없다 — JWT 파일 자리를 정하지 못했다(아무것도 보내지 않았다)' }
    $jwtPath = Join-Path $env:LOCALAPPDATA 'jt-e2e\vault-e2e-reader.jwt'
    if (-not (Test-Path -LiteralPath $jwtPath)) { throw '운영자 O-9 필요 — JWT 파일이 없다(%LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt) · 운영자가 O-9 로 발급한 뒤 그 1시간 안에 다시(아무것도 보내지 않았다)' }
    try {
      $sec = ConvertTo-SecureString ([System.IO.File]::ReadAllText($jwtPath, [System.Text.Encoding]::ASCII).Trim())
      $jwt = [System.Net.NetworkCredential]::new('', $sec).Password }
    catch { $jwt = '' }
    $sec = $null
    if ([string]::IsNullOrEmpty($jwt)) { throw 'JWT 파일을 복호하지 못했다(이 Windows 사용자의 DPAPI 가 아니거나 깨졌다 — 값 미출력) · 운영자 O-9 를 다시(아무것도 보내지 않았다)' }
    $cl = $null
    $jm = [regex]::Match($jwt, '\A[A-Za-z0-9_-]+\.([A-Za-z0-9_-]+)\.[A-Za-z0-9_-]+\z')
    if ($jm.Success) {
      $p64 = $jm.Groups[1].Value.Replace('-', '+').Replace('_', '/')
      $p64 = $p64 + ('=' * ((4 - $p64.Length % 4) % 4))
      try { $cl = & $parseJson ([System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p64))) } catch { $cl = $null } }
    $jm = $null
    $p64 = $null
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $exp = $null
    $audForm = ''
    $jwhy = @()
    if ($null -eq $cl) { $jwhy += 'JWT 꼴 아님(점 둘 · base64url · JSON 페이로드)' }
    else {
      # aud(VD-T076-10): 문자열 "vault" 또는 원소 하나인 배열 ["vault"](원소도 문자열) — 뜻이 같다(오직 vault) · 그 밖(원소 둘 이상 · 다른 값 · 대소문자 다름 · 없음 · 다른 형)은 멈춘다
      $audP = $cl.PSObject.Properties['aud']
      if ($null -ne $audP -and $audP.Value -is [string] -and (& $eq $audP.Value 'vault')) { $audForm = '문자열' }
      elseif ($null -ne $audP -and $audP.Value -is [array] -and $audP.Value.Count -eq 1 -and $audP.Value[0] -is [string] -and (& $eq $audP.Value[0] 'vault')) { $audForm = '배열' }
      else { $jwhy += 'aud ≠ "vault" · ["vault"](문자열 또는 원소 하나 배열 — VD-T076-10)' }
      if (-not (& $eq (& $prop $cl 'sub') 'system:serviceaccount:kube-system:agent-view')) { $jwhy += 'sub ≠ system:serviceaccount:kube-system:agent-view' }
      $exp = & $prop $cl 'exp'
      $iat = & $prop $cl 'iat'
      if (-not ($exp -is [long] -and $iat -is [long])) { $jwhy += 'exp · iat 가 정수가 아니다' }
      else {
        if ($exp -le $now + 60) { $jwhy += 'exp 가 지금 + 60 s 안이다(만료 · 곧 만료 — 운영자 O-9 다시)' }
        if ($exp -le $iat -or $exp - $iat -gt 3610) { $jwhy += "수명 exp − iat = $($exp - $iat) s(0 초과 · 3610 이하여야 한다 — UD-16 1시간)" } } }
    $cl = $null
    if ($jwhy.Count -gt 0) { $jwt = ''; throw "JWT 판정 실패: $($jwhy -join ' · ') — Vault 로 아무것도 보내지 않았다" }
    $expS = [DateTimeOffset]::FromUnixTimeSeconds($exp).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    Write-Host "INFO jwt aud 꼴=$audForm(VD-T076-10 — 문자열 · 원소 하나 배열 둘 다 받는다)"
    Write-Host "INFO jwt exp=$expS 남은 $([Math]::Floor(($exp - $now) / 60))분(UD-16 — 같은 1시간 안 재사용 · 파일은 그대로 둔다)"
    # ⑥ port-forward(D4 ⑥ · A-9 · S-04 · RO2-01): 블록이 소유하는 백그라운드 kubectl(스레드 작업 — 끄면 kubectl 도 끝난다) · --address 127.0.0.1(::1 대체 0) · 로컬 포트는 kubectl 이 고르고 쥔다
    #   (:8200 — 빈 포트를 골랐다 놓는 경합 0) · 작업 출력에서 정확히 한 줄 「Forwarding from 127.0.0.1:<n> -> 8200」을
    #   ≤ 45 s 안에 읽어(터널 경유 수립 10–23 s 실측 — T048 F19 · tests/platform/reboot.tests.ps1 $pfReadyWaitSec 45) 그 n 만 쓴다(없음 · 둘 이상 · [::1] 줄 · 다른 꼴 → JWT 0 ·
    #   멈춤) · 작업 상태 NotStarted · Running 은 기다린다(시작 직후는 NotStarted — 실측) · 그 뒤 ≤ 15 s 동안 무자격 seal-status 를 기다린다 · 로그인 직전에 Running · 같은 한 줄을 다시 본다
    $pf = Start-ThreadJob -ScriptBlock { param($k) kubectl.exe --kubeconfig $k -n vault port-forward --address 127.0.0.1 svc/vault :8200 2>&1 } -ArgumentList $kc
    $pfRead = {
      $po = @(Receive-Job -Job $pf -Keep -ErrorAction SilentlyContinue | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $fw = @($po | Where-Object { $_.StartsWith('Forwarding from', [StringComparison]::Ordinal) })
      $n = 0
      $why = ''
      if ($fw.Count -gt 1) { $why = "Forwarding 줄 $($fw.Count)개(정확히 한 줄이어야 한다 — $(& $clean ($fw -join ' | ')))" }
      elseif ($fw.Count -eq 1) {
        $fm = [regex]::Match($fw[0], '\AForwarding from 127\.0\.0\.1:([1-9][0-9]{0,4}) -> 8200\z')
        if ($fm.Success -and [int]$fm.Groups[1].Value -le 65535) { $n = [int]$fm.Groups[1].Value } else { $why = "Forwarding 줄 꼴 아님($(& $clean $fw[0]) — 기대 127.0.0.1:<포트> -> 8200)" } }
      [pscustomobject]@{ port = $n; why = $why; last = $(if ($po.Count -gt 0) { & $clean (& $hide $po[$po.Count - 1]) } else { '' }) } }
    $port = 0
    $pw = $null
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)
    for ($i = 0; $i -lt 90 -and $port -eq 0 -and [DateTimeOffset]::UtcNow -lt $deadline; $i++) {
      $pw = & $pfRead
      if ($pw.why.Length -gt 0) { break }
      if ($pw.port -gt 0) { $port = $pw.port }
      elseif (-not (@('NotStarted', 'Running') -ccontains [string]$pf.State)) { break }
      else { Start-Sleep -Milliseconds 500 } }
    if ($port -eq 0) { throw "Vault port-forward 의 Forwarding 줄(정확히 한 줄 127.0.0.1:<포트> -> 8200)을 45 s 안에 얻지 못했다(작업 $([string]$pf.State) · $(if ($null -eq $pw) { '출력 없음' } elseif ($pw.why) { $pw.why } elseif ($pw.last) { '마지막 줄 ' + $pw.last } else { '출력 없음' })) — JWT 를 보내지 않았다" }
    $vbase = "http://127.0.0.1:$port"
    $seal = $null
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(15)
    for ($i = 0; $i -lt 30 -and $null -eq $seal -and [DateTimeOffset]::UtcNow -lt $deadline; $i++) {
      $s = & $vreq 'seal' '/v1/sys/seal-status' $null ''
      if ($s.ok) { $seal = $s }
      elseif (-not (& $eq ([string]$pf.State) 'Running')) { break }
      else { Start-Sleep -Milliseconds 500 } }
    if ($null -eq $seal) {
      $pw = & $pfRead
      throw "Vault port-forward(127.0.0.1:$port)가 15 s 안에 응답하지 않았다(작업 $([string]$pf.State)$(if ($pw.last) { ' · 마지막 줄 ' + $pw.last })) — JWT 를 보내지 않았다" }
    $sealed = & $prop $seal.json 'sealed'
    $cname = [string](& $prop $seal.json 'cluster_name')
    $scode = $seal.code
    $seal = $null
    if (-not (& $eq $scode '200') -or -not ($sealed -is [bool]) -or $sealed -or -not (& $eq $cname 'vault-cluster-d3b29227')) { throw "Vault seal-status 가 기대와 다르다(응답 $scode · sealed=$(& $clean ([string]$sealed)) · cluster_name=$(& $clean $cname)) — 다른 Vault 이거나 봉인돼 있다. JWT 를 보내지 않았다" }
    Write-Host "OK   Vault seal-status: sealed=false · cluster_name=vault-cluster-d3b29227(port-forward 127.0.0.1:$port — 블록 소유 · 포트는 kubectl 이 골랐다)"
    # 로그인 직전(S-04): port-forward 작업이 아직 Running 이고 Forwarding 줄이 그대로 정확히 한 줄(같은 포트)이어야 JWT 를 보낸다
    $pw = & $pfRead
    if (-not (& $eq ([string]$pf.State) 'Running') -or $pw.why.Length -gt 0 -or $pw.port -ne $port) { throw "로그인 직전 port-forward 재확인 실패(작업 $([string]$pf.State) · $(if ($pw.why) { $pw.why } elseif ($pw.port -ne $port) { 'Forwarding 포트 ' + $pw.port + ' ≠ ' + $port } else { 'Forwarding 줄 그대로' })) — JWT 를 보내지 않았다" }
    # ⑦ 로그인(D4 ⑦): 본문 {"role":"e2e-reader","jwt":…} 을 stdin 으로만 — 응답의 auth.client_token 은 변수에만 · policies ∋ e2e-reader · lease_duration ≤ 3600 · JWT 변수는 곧바로 비운다
    $lr = & $vreq 'login' '/v1/auth/kubernetes/login' ('{"role":"e2e-reader","jwt":"' + $jwt + '"}') ''
    $jwt = ''
    $lcode = $lr.code
    $la = & $prop $lr.json 'auth'
    $lr = $null
    $t0 = & $prop $la 'client_token'
    $lpol = @(& $prop $la 'policies' | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    $llease = & $prop $la 'lease_duration'
    $la = $null
    if ($t0 -is [string] -and $t0 -cmatch '\A[A-Za-z0-9._-]{20,256}\z') { $vtok = $t0 }
    $tbad = ($t0 -is [string] -and $t0.Length -gt 0 -and $vtok.Length -eq 0)
    $t0 = $null
    if (-not (& $eq $lcode '200') -or $vtok.Length -eq 0) { throw "Vault 로그인 실패(role e2e-reader · 응답 $(if ($lcode) { $lcode } else { '없음' })$(if ($tbad) { ' · 토큰 꼴 아님 — 값 미출력' })) — 그 뒤 아무것도 읽지 않았다" }
    if (-not ($lpol -ccontains 'e2e-reader') -or -not ($llease -is [long]) -or $llease -le 0 -or $llease -gt 3600) { throw "Vault 로그인 응답이 설계와 다르다(policies=$(& $clean ($lpol -join ',')) · lease_duration=$(& $clean ([string]$llease))) — 읽지 않았다(토큰은 finally 에서 revoke)" }
    Write-Host "OK   Vault 로그인(role e2e-reader) · policies=$(& $clean ($lpol -join ',')) · lease_duration=$llease s — 토큰 값 미출력"
    # ⑧ 권한 관문(D4 ⑧ · VD-T076-9 · B-02): 읽기 전에 sys/capabilities-self — 다섯 경로가 설계(tester-m2m · authentik/e2e read · tester-k8s · metadata · prod deny)와 하나라도 다르면 읽지 않는다
    $capWant = [ordered]@{ 'kv/data/platform/access/tester-m2m' = 'read'; 'kv/data/platform/access/tester-k8s' = 'deny'; 'kv/metadata/platform/access/tester-m2m' = 'deny'; 'kv/data/platform/authentik/e2e' = 'read'; 'kv/data/prod/db/identity_admin/app' = 'deny' }
    $cr = & $vreq 'tok' '/v1/sys/capabilities-self' @("X-Vault-Token: $vtok") '{"paths":["kv/data/platform/access/tester-m2m","kv/data/platform/access/tester-k8s","kv/metadata/platform/access/tester-m2m","kv/data/platform/authentik/e2e","kv/data/prod/db/identity_admin/app"]}'
    $ccode = $cr.code
    $cd = & $prop $cr.json 'data'
    if ($null -eq $cd) { $cd = $cr.json }
    $cr = $null
    $capRow = @(@($capWant.Keys) | ForEach-Object { $key = $_; "$key=[$(@(& $prop $cd $key | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }) -join ',')]" })
    $capBad = @(@($capWant.Keys) | Where-Object { $key = $_; $v = @(& $prop $cd $key | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }); -not ($v.Count -eq 1 -and (& $eq $v[0] $capWant[$key])) })
    $cd = $null
    if (-not (& $eq $ccode '200') -or $capBad.Count -gt 0) { throw "권한 관문 FAIL(sys/capabilities-self 응답 $(if ($ccode) { $ccode } else { '없음' }) · $((($capRow -join ' · ') -replace '\p{Cc}', '?'))) — 정책이 설계와 다르다(VD-T076-9). 읽지 않았다" }
    Write-Host "OK   권한 관문(sys/capabilities-self): $($capRow -join ' · ')"
    # ⑨ 읽기(D4 ⑨): kv/data/platform/access/tester-m2m — data.data 키가 정확히 {client_id, client_secret} · 꼴(D2-1 — id 32 hex + .access · secret 54자 [A-Za-z0-9_-] · -c 고정)이 아니면 Access 로 보내지 않는다
    $kr = & $vreq 'tok' '/v1/kv/data/platform/access/tester-m2m' @("X-Vault-Token: $vtok") ''
    $kcode = $kr.code
    $kd = & $prop (& $prop $kr.json 'data') 'data'
    $kr = $null
    $kn = @(& $names $kd)
    $cid = & $prop $kd 'client_id'
    $csec = & $prop $kd 'client_secret'
    $kd = $null
    if (-not (& $eq $kcode '200') -or $kn.Count -ne 2 -or -not ($kn -ccontains 'client_id') -or -not ($kn -ccontains 'client_secret') -or $cid -isnot [string] -or $csec -isnot [string] -or $cid -cnotmatch '\A[0-9a-f]{32}\.access\z' -or $csec -cnotmatch '\A[0-9A-Za-z_-]{54}\z') {
      $cid = ''; $csec = ''
      throw "tester-m2m 자격을 꺼내지 못했다(kv 응답 $(if ($kcode) { $kcode } else { '없음' }) · 키 $($kn.Count)개 · client_id ^[0-9a-f]{32}\.access$ · client_secret ^[0-9A-Za-z_-]{54}$ 꼴 아님 — 값 미출력) · Access 로 아무것도 보내지 않았다" }
    $cred = @("CF-Access-Client-Id: $cid", "CF-Access-Client-Secret: $csec")
    $cid = ''; $csec = ''
    Write-Host 'OK   tester-m2m 자격 = kv 키 둘(client_id · client_secret) · 꼴 일치(값 미출력)'
    # ⑩ 탐침(D4 ⑩ · D10): dev → prod · 판정 a(/health 200) · b–e(404 넷 = Traefik 라우터 없음 기준값) · INFO(VD-L9 · CN 음성 · 가짜 자격) — 요청마다
    #   INFO <env> <id> at=<UTC> code=<코드> ct=<원문 정제> cfc=<cf-cache-status 정제> cf-ray=<값>(VD-T076-5 · 6 근거 — 비밀 아님) · 날짜 글자는 InvariantCulture(C-12 — C-8 입력 정규식과 같은 꼴)
    $t0d = [DateTimeOffset]::UtcNow
    $nonce = 't076-' + $t0d.ToString("yyyyMMdd'T'HHmmss'Z'", [System.Globalization.CultureInfo]::InvariantCulture) + '-' + [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(3)).ToLowerInvariant()
    $startS = $t0d.AddSeconds(-60).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [System.Globalization.CultureInfo]::InvariantCulture)
    Write-Host "INFO o8 start=$startS nonce=$nonce — C-8 입력(-Since · -Nonce) · start 는 첫 요청보다 60 s 앞(노드 시계 차이 여유)"
    $fakeId = ('0' * 32) + '.access'
    $fakeSec = 'A' * 54
    $p404 = [ordered]@{ b = @('/admin/', 'admin'); c = @('/webhooks/authentik', 'webhooks'); d = @('/healthz', 'healthz'); e = @('/ready', 'ready') }
    $pInfo = @(@('/apix', 'apix'), @('/sessionsX', 'sessionsx'), @('/health/', 'healthslash'), @('/tenants/me', 'tenantsme'))
    $note = { param($ev, $id, $r) $info.Add("o8 $ev $id at=$($r.at) code=$(if ($r.code) { & $clean $r.code } else { '(없음)' }) ct=$(if ($r.ct) { & $clean $r.ct } else { '(없음)' }) cfc=$(if ($r.cfc) { & $clean $r.cfc } else { '(없음)' }) cf-ray=$(if ($r.ray) { & $clean $r.ray } else { '(없음)' })") }
    $desc = { param($r)
      if (-not $r.ok) { return $r.why }
      $mt = ([string]$r.ct).Split(';')[0].Trim()
      $ty = ''
      if ([string]::Equals($mt, 'application/problem+json', [StringComparison]::OrdinalIgnoreCase)) { $ty = [string](& $prop (& $parseJson $r.body) 'type') }
      $tr = (& $eq $r.code '404') -and [string]::Equals($mt, 'text/plain', [StringComparison]::OrdinalIgnoreCase) -and $r.body.Count -eq 2 -and (& $eq $r.body[0] '404 page not found') -and (& $eq $r.body[1] '') -and (& $eq $r.size '19')
      "$($r.code) · $(if ($mt) { & $clean $mt } else { '(미디어 타입 없음)' })$(if ($ty) { ' · type=' + (& $clean $ty) }) · $(& $clean $r.size) B · cf-cache-status=$(if ($r.cfc) { & $clean $r.cfc } else { '(없음)' })$(if ($tr) { ' · Traefik 404 꼴' })" }
    foreach ($ev in @('dev', 'prod')) {
      $base = "https://identity-m2m-$ev.joshuatech.dev"
      $q = "?t076=$nonce"
      $r = & $get "$base/health$q" (@($cred) + @("X-Request-ID: $nonce-$ev-health"))
      & $note $ev 'health' $r
      $bad = @()
      if (-not $r.ok) { $bad += $r.why }
      else {
        $b = & $parseJson $r.body
        $ck = & $prop $b 'checks'
        $cn = @(& $names $ck)
        if (-not (& $eq $r.code '200')) { $bad += "응답 $(& $clean $r.code)" }
        if (-not (& $eq (& $prop $b 'status') 'ok')) { $bad += "status = $(& $clean ([string](& $prop $b 'status')))" }
        if (-not ($cn.Count -eq 3 -and @(@('db', 'dragonfly', 'kafka_producer') | Where-Object { $cn -ccontains $_ }).Count -eq 3)) { $bad += "checks 키 $($cn.Count)개($(& $clean ($cn -join ',')))" }
        else { foreach ($n in @('db', 'dragonfly', 'kafka_producer')) { $st = [string](& $prop (& $prop $ck $n) 'status'); if (-not (& $eq $st 'ok')) { $bad += "checks.$n = $(& $clean $st)" } } }
        $gs = [string](& $prop $b 'git_sha')
        if (-not (& $eq $gs $ExpectedSha)) { $bad += "git_sha = $(if ($gs -cmatch '\A[0-9a-f]{7,64}\z') { $gs } else { '(꼴 밖)' })" }
        if (& $hit $r.cfc) { $bad += "cf-cache-status = $(& $clean $r.cfc)" }
        $b = $null
        $ck = $null
        $info.Add("o8 $ev health x-request-id $(if (& $eq $r.xrid "$nonce-$ev-health") { '= 보낸 값(VD-T076-4)' } else { '≠ 보낸 값(' + $(if ($r.xrid) { & $clean $r.xrid } else { '없음' }) + ' — VD-T076-4)' }) · Cache-Control = $(if ($r.cc) { & $clean $r.cc } else { '(없음)' })") }
      & $check "o8 $ev a GET /health → 200 · status ok · checks {db, dragonfly, kafka_producer} 모두 ok · git_sha = 입력 · cf-cache-status ≠ HIT" ($bad.Count -eq 0) ($bad -join ' · ')
      foreach ($k in @($p404.Keys)) {
        $pp = $p404[$k][0]
        $id = $p404[$k][1]
        $r = & $get "$base$pp$q" (@($cred) + @("X-Request-ID: $nonce-$ev-$id"))
        & $note $ev $id $r
        $bad = @()
        if (-not $r.ok) { $bad += $r.why }
        else {
          $mt = ([string]$r.ct).Split(';')[0].Trim()
          if (-not (& $eq $r.code '404')) { $bad += "응답 $(& $clean $r.code)" }
          if (-not [string]::Equals($mt, 'text/plain', [StringComparison]::OrdinalIgnoreCase)) { $bad += "미디어 타입 = $(if ($mt) { & $clean $mt } else { '(없음)' })" }
          if (-not ($r.body.Count -eq 2 -and (& $eq $r.body[0] '404 page not found') -and (& $eq $r.body[1] ''))) { $bad += "본문 ≠ 「404 page not found」 한 줄(줄 $($r.body.Count))" }
          if (-not (& $eq $r.size '19')) { $bad += "size_download = $(& $clean $r.size)" }
          if (& $hit $r.cfc) { $bad += "cf-cache-status = $(& $clean $r.cfc)" } }
        & $check "o8 $ev $k GET $pp → 404 · text/plain · 본문 「404 page not found」 한 줄 · 19 B · cf-cache-status ≠ HIT(Traefik 라우터 없음 — D10)" ($bad.Count -eq 0) ($bad -join ' · ') }
      foreach ($x in $pInfo) {
        $r = & $get "$base$($x[0])$q" (@($cred) + @("X-Request-ID: $nonce-$ev-$($x[1])"))
        & $note $ev $x[1] $r
        $info.Add("o8 $ev INFO GET $($x[0]) → $(& $desc $r)") }
      $r = & $get "$base/health$q" @("CF-Access-Client-Id: $fakeId", "CF-Access-Client-Secret: $fakeSec", "X-Request-ID: $nonce-$ev-fake")
      & $note $ev 'fake' $r
      $info.Add("o8 $ev INFO 가짜 자격(비밀 아닌 고정 값 — 0×32.access · A×54) GET /health → $(& $desc $r)(VD-T076-8)")
      $r = $null }
    $cred = $null
    $done = $true }
  catch {
    $stopWhy = [string]$_.Exception.Message
    foreach ($sv in @([string]$jwt, [string]$vtok, [string]$cid, [string]$csec)) { if ($sv.Length -ge 8 -and $stopWhy.Contains($sv)) { $stopWhy = $stopWhy.Replace($sv, '(값 가림)') } }
    if (-not [string]::IsNullOrEmpty($HOME)) { $stopWhy = [regex]::Replace($stopWhy, '(?i)' + [regex]::Escape($HOME), '~') } }
  finally {
    if ($vtok.Length -gt 0) {
      try {
        $rv = & $vreq 'tok' '/v1/auth/token/revoke-self' @("X-Vault-Token: $vtok") '{}'
        $info.Add("vault token revoked($(if ($rv.ok) { $rv.code } else { '응답 없음 · curl exit ' + $rv.rc }))") }
      catch { $info.Add('vault token revoke 실패(예외 — 토큰은 lease 1시간 안에 만료된다)') }
      $rv = $null }
    $vtok = ''
    if ($null -ne $pf) {
      Stop-Job -Job $pf -ErrorAction SilentlyContinue
      Remove-Job -Job $pf -Force -ErrorAction SilentlyContinue
      $info.Add('port-forward 종료(블록 소유 kubectl 스레드 작업)') }
    $pf = $null
    $jwt = ''
    $cid = ''
    $csec = ''
    $cred = $null
    Remove-Variable sec, lr, la, t0, kr, kd, cr, cd, r, b, ck, fakeSec -ErrorAction SilentlyContinue
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T076 O-8 탐침 결과(identity-m2m dev → prod · 자격 · 토큰 · JWT · 쿠키 없음 — tester 보고에 그대로) ---'
    # 응답에서 온 글자(코드 · 헤더 · 본문 필드 · curl 오류)는 제어 문자를 '?' 로 바꿔 낸다(T075 KB-7 — 터미널 제어열 · OSC 52 주입 방어)
    foreach ($k in $res.Keys) {
      if (([string]$res[$k]).StartsWith('PASS', [StringComparison]::Ordinal)) { Write-Host "PASS $k" } else { Write-Host "FAIL $k — $(([string]$res[$k]) -replace '\p{Cc}', '?')" } }
    foreach ($l in $info) { Write-Host "INFO $(([string]$l) -replace '\p{Cc}', '?')" }
    if ($stopWhy.Length -gt 0) { Write-Host "STOP $($stopWhy -replace '\p{Cc}', '?')" }
    $nPass = @($res.Values | Where-Object { ([string]$_).StartsWith('PASS', [StringComparison]::Ordinal) }).Count
    if ($done -and $res.Count -eq 10 -and $nPass -eq 10) { Write-Host 'o8=PASS 10/10' } else { Write-Host "o8=FAIL $nPass/10" } }
  if ($done -and $res.Count -eq 10 -and $nPass -eq 10) { exit 0 }
  exit 1
}
