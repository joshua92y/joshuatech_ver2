& {
  # ===== T075 W-6 ACL LOAD 블록 — Dragonfly admin ACL LOAD 1회(변경 · 재시작 아님) · env 하나씩 · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: 같은 디렉터리 O-6 사후(o6-post-dragonfly-dryrun.ps1)의 창 전제 · Vault 도달 · root 토큰 · kubectl exec 꼴 · 응답 분류 · 정리를 그대로 쓰고, 보내는 명령을 ACL LOAD 하나로 바꿨다.
  # 목적: UD-9 적용 순서 6단계(설계 D20) — W-6 재렌더 → ESO 갱신(4단계) → kubelet 반영(5단계) 뒤, 실행 중인 Dragonfly 가 마운트 aclfile 을 다시 읽게 한다. **재시작은 하지 않는다**:
  #       실행 중 ACL LOAD 가 실패하면 옛 규칙이 메모리에 남는다(안전) · 같은 파일로 기동하면 무인증이다(UD-9 실측). 성공한 LOAD 는 모든 연결을 끊는다(소비자는 다시 붙는다).
  # 왜 블록인가(설계 §5 는 「런북 명령 줄 kubectl … exec -it … redis-cli --user admin --askpass ACL LOAD」 — D10 이 「블록이 넘기는 꼴」의 방법을 빌더에게 맡겼다):
  #   admin 비밀번호는 kv/<env>/dragonfly/admin 에만 있다(T057 생성 · 사본 없음) — 운영자가 -it 프롬프트에 칠 값을 화면 · 클립보드 없이 손에 넣을 길이 없다. 그래서 이 블록이 kv 에서 읽어
  #   kubectl exec -i 의 stdin 으로만 redis-cli --askpass 에 준다(argv · env · 화면 · 파일 · 클립보드 0). PowerShell 파이프는 끝에 CRLF 를 붙여 CR 이 비밀번호에 남는다 → 값 뒤에 LF 를 먼저 붙인다
  #   (VD-T075-17 실측 — 붙이지 않으면 AUTH failed). redis-cli 6.0.16 은 AUTH 실패 · 오류 응답에도 종료 코드 0 이다 → 응답 줄로 판정한다(OK = 성공 · 그 밖 = 실패).
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T075 적용 순서): ① 창 D 창 시작 체크리스트 ② 창 C port-forward ③ VAULT_* 없음 · ~/.vault-token 없음 ④ PM 의 root 토큰
  #   ⑤ 관리자 kubeconfig = $HOME\.kube\joshuatech-admin.yaml(--kubeconfig 로 직접 적는다) ⑥ 그 env 의 W-6 OK · ES refreshTime 이 쓰기 뒤(4단계) · 마운트 반영(5단계)을 확인했다
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>' · 정지점: ① env(dev 또는 prod · 가려진다) ② root 토큰(보안 입력) ③ load-<env> — 보내기 확인(가려진다 · 대소문자 구분)
  # 원칙: 사람 동작마다 정지점 · 판정(읽기)은 kv admin 비밀번호 확인뿐이고 변경은 ACL LOAD 한 번뿐 · 실패 = 재시작하지 않는다 · 값 · 해시 · 토큰은 어디에도 0 · finally 정리
  # 실행 뒤: 성공이면 O-6 사후(o6-post-dragonfly-dryrun.ps1) PASS 를 본다 · 실패면 런북 §4 T075 「실패 갈래」(그 env 의 재시작 요인을 멈춘다 — SUC 창 · 노드 작업 보류)
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
  $envSel = ''
  $result = '보내지 않았다(이 실행에서 ACL LOAD 까지 오지 못했다)'
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $stop = { param($msg, $word)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)" -MaskInput
      if (-not (& $eq $ans $word)) { throw "정지점에서 중단: $msg — ACL LOAD 0건" } }
    $pickEnv = {
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host 'ACL LOAD 할 env — dev 또는 prod 를 그대로 입력(입력은 가려진다 · 그 외 입력 = 중단 · dev 먼저)' -MaskInput
      if (& $eq $ans 'dev') { return 'dev' }
      if (& $eq $ans 'prod') { return 'prod' }
      throw '정지점에서 중단: env 선택(dev · prod 가 아니다) — ACL LOAD 0건' }
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt(아무것도 보내지 않았다)" }
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
    $classify = { param($lines)
      $outs = @(@($lines) | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $errs = @(@($lines) | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $show = ''
      if ($outs.Count -gt 0) { $show = [regex]::Replace($outs[0], '#[0-9A-Fa-f]{8,}', '#<hash>') -replace '\p{Cc}', '?' }
      if ($show.Length -gt 160) { $show = $show.Substring(0, 160) + '…' }
      if (@($errs | Where-Object { $_.Contains('AUTH failed') }).Count -gt 0 -or @($outs | Where-Object { $_.StartsWith('NOAUTH', [StringComparison]::Ordinal) -or $_.StartsWith('WRONGPASS', [StringComparison]::Ordinal) }).Count -gt 0) { return [pscustomobject]@{ kind = 'auth'; show = 'admin AUTH 실패(NOAUTH · AUTH failed)' } }
      if ($outs.Count -eq 1 -and (& $eq $outs[0] 'OK')) { return [pscustomobject]@{ kind = 'ok'; show = 'OK' } }
      if ($outs.Count -eq 0) { return [pscustomobject]@{ kind = 'err'; show = "응답 없음(stderr: $(& $firstErr $errs))" } }
      [pscustomobject]@{ kind = 'err'; show = $show } }
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
    $kc = Join-Path $HOME '.kube\joshuatech-admin.yaml'
    if (-not (Test-Path -LiteralPath $kc)) { throw '관리자 kubeconfig 가 $HOME\.kube\joshuatech-admin.yaml 에 없다(vault-unseal.md §0) — 아무것도 묻지 않았다' }
    $vcs = @(Get-Command vault -ErrorAction SilentlyContinue)
    if ($vcs.Count -eq 0) { throw 'vault CLI 를 찾을 수 없다(PATH) — 설치 · PATH 확인(아무것도 묻지 않았다)' }
    $kcs = @(Get-Command kubectl -ErrorAction SilentlyContinue)
    if ($kcs.Count -eq 0) { throw 'kubectl 을 찾을 수 없다(PATH) — 아무것도 묻지 않았다' }
    $vsrc = [string]$vcs[0].Source
    if ([string]::IsNullOrEmpty($vsrc)) { $vsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $vsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $vsrc = '~' + $vsrc.Substring($HOME.Length) }
    $ksrc = [string]$kcs[0].Source
    if ([string]::IsNullOrEmpty($ksrc)) { $ksrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $ksrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $ksrc = '~' + $ksrc.Substring($HOME.Length) }
    $ver = @(vault version 2>$null)
    $global:LASTEXITCODE = 0
    $verLine = '(버전 출력 없음)'
    if ($ver.Count -gt 0) { $verLine = ([string]$ver[0]).Trim() -replace '\p{Cc}', '?' }
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc · kubectl $([string]$kcs[0].CommandType) $ksrc — 변경 = admin ACL LOAD 1회뿐(재시작 0)"
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
    $envSel = [string](& $pickEnv)
    Write-Host "OK   ACL LOAD env = $envSel(deploy/dragonfly-$envSel · ns data)"
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
    $o = @(vault kv get "-format=json" "kv/$envSel/dragonfly/admin" 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pw = $null
    if ($rc -eq 0) { $pw = & $prop (& $prop (& $prop (& $parseJson $o) 'data') 'data') 'password' }
    $o = $null
    if ($rc -ne 0 -or $pw -isnot [string] -or $pw -cnotmatch '\A[A-Za-z0-9_-]{43}\z') { $pw = $null; throw "admin 비밀번호를 읽지 못했다(kv/$envSel/dragonfly/admin · kv get exit=$rc · 또는 base64url 43자가 아님 — 값 미출력) — ACL LOAD 0건" }
    # vault 호출은 여기서 끝난다 — root 토큰을 env 에서 바로 지운다(T075 보정 2026-11-17 · 리뷰 KB-4: 뒤의 kubectl 자식 프로세스 env 에 토큰이 남지 않게)
    Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue
    $tokenOwned = $false
    Write-Host "OK   토큰 정책에 root 포함 · kv/$envSel/dragonfly/admin 읽음(값 미출력) · VAULT_TOKEN 지움"
    Write-Host ''
    Write-Host "보낼 명령 1개: kubectl --kubeconfig <관리자 kubeconfig> -n data exec -i deploy/dragonfly-$envSel -c dragonfly -- redis-cli --user admin --askpass ACL LOAD(비밀번호는 stdin 으로만)"
    Write-Host '  성공하면 Dragonfly 의 모든 연결이 끊긴다(소비자는 다시 붙는다) · 실패하면 옛 규칙이 메모리에 남는다(안전) — 어느 쪽이든 재시작하지 않는다'
    & $stop "보내기 확인: dragonfly-$envSel 에 admin ACL LOAD 를 한 번 보낸다(재시작 아님)" "load-$envSel"
    $result = '결과 미확인(ACL LOAD 를 보내는 중 중단 — O-6 사후로 라이브 규칙을 본다)'
    # 인자 목록을 배열로 만들어 펼친다(O-6 사후와 같은 꼴 — 받는 쪽이 무엇이든 낱말이 따로 간다) · 비밀번호는 argv 에 없다
    $kargs = @('--kubeconfig', $kc, '-n', 'data', 'exec', '-i', "deploy/dragonfly-$envSel", '-c', 'dragonfly', '--', 'redis-cli', '--user', 'admin', '--askpass', 'ACL', 'LOAD')
    $out = @(($pw + "`n") | kubectl @kargs 2>&1)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pw = $null
    if ($rc -ne 0) {
      $kerr = & $firstErr @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      $out = $null
      $result = "결과 미확인(kubectl exec exit=$rc · $kerr — ACL LOAD 가 Dragonfly 에 닿았는지 모른다 · O-6 사후로 라이브 규칙을 본다)"
      throw "kubectl exec 실패(exit=$rc · $kerr) — 결과 미확인: ACL LOAD 가 닿았는지 모른다 — O-6 사후로 본다(재시작하지 않는다)" }
    $c = & $classify $out
    $out = $null
    if (& $eq $c.kind 'ok') {
      $result = 'OK(admin ACL LOAD — 마운트 aclfile 을 다시 읽었다 · 모든 연결이 끊겼다)'
      Write-Host "OK   dragonfly-$envSel ACL LOAD — OK · 다음 = O-6 사후(o6-post-dragonfly-dryrun.ps1) $envSel" }
    elseif (& $eq $c.kind 'auth') {
      $result = '실패(admin AUTH 실패 — ACL LOAD 는 실행되지 않았다 · kv admin 비밀번호와 라이브 aclfile 이 어긋난다)'
      Write-Host "STOP dragonfly-$envSel — $($c.show) · ACL LOAD 는 실행되지 않았다 — 재시작하지 않는다 · 컨트롤러에게 보고(회전 반쪽 · 옛 aclfile 확인)" }
    else {
      $result = "실패(ACL LOAD 응답 = $($c.show) — 옛 규칙이 메모리에 남는다)"
      Write-Host "STOP dragonfly-$envSel — ACL LOAD 실패($($c.show)) · 옛 규칙이 메모리에 남는다(안전) — 재시작하지 않는다 · 그 env 의 Dragonfly 재시작 요인을 멈춘다(SUC 창 · 노드 작업 보류) · 런북 §4 T075 실패 갈래 ①" } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable pw, tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, o, out, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T075 W-6 ACL LOAD 결과(env=$(if ($envSel) { $envSel } else { '선택 전' }) · 비밀번호 · 해시 없음 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---"
    Write-Host "acl-load $(if ($envSel) { $envSel } else { '-' }) = $result"
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
