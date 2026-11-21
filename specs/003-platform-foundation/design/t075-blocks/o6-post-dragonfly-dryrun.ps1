& {
  # ===== T075 O-6 사후 블록 — Dragonfly 라이브 규칙 판정(admin ACL DRYRUN · 쓰기 0 · 명령 실행 0) · env 하나씩 · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: 같은 디렉터리 O-2 의 창 전제 · Vault 도달 · root 토큰 · 정리를 그대로 쓰고, kubectl exec 로 Dragonfly pod 안의 redis-cli 6.0.16 을 부른다(설계 D20 「O-6 판정 — 사후」 · D10).
  # 목적: UD-9 적용 순서 7단계 — admin ACL LOAD(6단계) 뒤 라이브 메모리의 규칙이 B2 인지 admin 의 ACL DRYRUN 표로 본다. DRYRUN 은 명령을 실행하지 않는다(REPLICAOF 를 실제로 보내지 않는다)
  #       · ACL GETUSER 는 해시를 보이므로 쓰지 않는다 · MONITOR 는 쓰지 않는다(HELLO … AUTH 비밀번호 평문).
  # 표(설계 D20): identity-admin ACL LIST · REPLICAOF NO ONE · CLIENT LIST → 거부 / identity-admin GET revoked:sub:x · SET identity-admin:x 1 → 허용 /
  #               (dev 만) sample-pod SET revoked:sub:x 1 · CLIENT KILL ID 1 → 거부 — prod 에는 sample-pod 사용자가 없다(실측: ERR User 'sample-pod' not found)
  # admin 비밀번호(설계 D10 — argv · env · 화면 · 파일 · 클립보드 0): kv/<env>/dragonfly/admin 에서 읽어 kubectl exec -i 의 stdin 으로만 redis-cli --askpass 에 준다.
  #   ⚠ PowerShell 은 파이프로 보낸 문자열 끝에 CRLF 를 붙이고 redis-cli(linenoise 비 TTY)는 LF 까지 읽어 CR 을 비밀번호에 남긴다 → AUTH 실패(VD-T075-17 실측) — 그래서 값 뒤에 LF 를 먼저 붙여 보낸다.
  #   redis-cli 6.0.16 은 AUTH 실패 · 오류 응답에도 종료 코드 0 이다(실측) — 판정은 응답 줄로 한다: OK = 허용 · This user has no permissions to run the '<명령>' command = 거부 ·
  #   NOAUTH · AUTH failed = 판정 불가(STOP) · ERR … = 오류(그 행 FAIL).
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T075): ① 창 D 창 시작 체크리스트 ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200
  #   ③ 이 창에 VAULT_* 없음 · ~/.vault-token 없음 ④ PM 의 root 토큰 항목 ⑤ 관리자 kubeconfig 가 $HOME\.kube\joshuatech-admin.yaml 에 있다(vault-unseal.md §0 — 블록은 --kubeconfig 로 직접 적는다 ·
  #   $env:KUBECONFIG 를 쓰지도 바꾸지도 않는다) ⑥ 그 env 의 admin ACL LOAD(w6-acl-load.ps1)가 OK 였다
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>' · 정지점: ① env — dev 또는 prod(입력은 가려진다) ② root 토큰(보안 입력)
  # 원칙: 비밀번호 · 토큰 · 해시는 화면 · argv · env · 파일 · 클립보드에 0 · 출력은 표의 판정과 응답 분류뿐 · 판정 불가는 FAIL · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저 · finally 정리
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
  $res = [ordered]@{}
  $done = $false
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $pickEnv = {
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host 'DRYRUN 을 볼 env — dev 또는 prod 를 그대로 입력(입력은 가려진다 · 그 외 입력 = 중단)' -MaskInput
      if (& $eq $ans 'dev') { return 'dev' }
      if (& $eq $ans 'prod') { return 'prod' }
      throw '정지점에서 중단: env 선택(dev · prod 가 아니다) — 아무것도 읽지 않았다' }
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
    # redis-cli 응답 분류(값 없음): stdout 줄(공백 제거 · 빈 줄 제외)과 stderr 줄로 → ok · deny · auth · err
    $classify = { param($lines)
      $outs = @(@($lines) | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $errs = @(@($lines) | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $show = ''
      if ($outs.Count -gt 0) { $show = [regex]::Replace($outs[0], '#[0-9A-Fa-f]{8,}', '#<hash>') -replace '\p{Cc}', '?' }
      if ($show.Length -gt 120) { $show = $show.Substring(0, 120) + '…' }
      if (@($errs | Where-Object { $_.Contains('AUTH failed') }).Count -gt 0 -or @($outs | Where-Object { $_.StartsWith('NOAUTH', [StringComparison]::Ordinal) -or $_.StartsWith('WRONGPASS', [StringComparison]::Ordinal) }).Count -gt 0) { return [pscustomobject]@{ kind = 'auth'; show = 'admin AUTH 실패(NOAUTH · AUTH failed)' } }
      if ($outs.Count -eq 1 -and (& $eq $outs[0] 'OK')) { return [pscustomobject]@{ kind = 'ok'; show = 'OK' } }
      if ($outs.Count -eq 1 -and $outs[0].StartsWith("This user has no permissions to run the '", [StringComparison]::Ordinal)) { return [pscustomobject]@{ kind = 'deny'; show = $show } }
      if ($outs.Count -eq 0) { return [pscustomobject]@{ kind = 'err'; show = "응답 없음(stderr: $(& $firstErr $errs))" } }
      [pscustomobject]@{ kind = 'err'; show = "다른 응답: $show" } }
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
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc · kubectl $([string]$kcs[0].CommandType) $ksrc — admin ACL DRYRUN 판정 전용(쓰기 0 · 명령 실행 0)"
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
    Write-Host "OK   DRYRUN env = $envSel(deploy/dragonfly-$envSel · ns data)"
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
    # admin 비밀번호(kv — 값은 이 변수에만 · 출력하지 않는다)
    $o = @(vault kv get "-format=json" "kv/$envSel/dragonfly/admin" 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pw = $null
    if ($rc -eq 0) { $pw = & $prop (& $prop (& $prop (& $parseJson $o) 'data') 'data') 'password' }
    $o = $null
    if ($rc -ne 0 -or $pw -isnot [string] -or $pw -cnotmatch '\A[A-Za-z0-9_-]{43}\z') { $pw = $null; throw "admin 비밀번호를 읽지 못했다(kv/$envSel/dragonfly/admin · kv get exit=$rc · 또는 base64url 43자가 아님 — 값 미출력) — 판정 불가" }
    # vault 호출은 여기서 끝난다 — root 토큰을 env 에서 바로 지운다(T075 보정 2026-11-17 · 리뷰 KB-4: 뒤의 kubectl 자식 프로세스 env 에 토큰이 남지 않게)
    Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue
    $tokenOwned = $false
    Write-Host "OK   토큰 정책에 root 포함 · kv/$envSel/dragonfly/admin 읽음(값 미출력) · VAULT_TOKEN 지움 — admin ACL DRYRUN 표를 시작한다"
    $rows = @(
      [pscustomobject]@{ user = 'identity-admin'; cmd = @('ACL', 'LIST'); want = 'deny' }
      [pscustomobject]@{ user = 'identity-admin'; cmd = @('REPLICAOF', 'NO', 'ONE'); want = 'deny' }
      [pscustomobject]@{ user = 'identity-admin'; cmd = @('CLIENT', 'LIST'); want = 'deny' }
      [pscustomobject]@{ user = 'identity-admin'; cmd = @('GET', 'revoked:sub:x'); want = 'ok' }
      [pscustomobject]@{ user = 'identity-admin'; cmd = @('SET', 'identity-admin:x', '1'); want = 'ok' })
    if (& $eq $envSel 'dev') {
      $rows += [pscustomobject]@{ user = 'sample-pod'; cmd = @('SET', 'revoked:sub:x', '1'); want = 'deny' }
      $rows += [pscustomobject]@{ user = 'sample-pod'; cmd = @('CLIENT', 'KILL', 'ID', '1'); want = 'deny' } }
    $kname = @{ ok = '허용'; deny = '거부' }
    foreach ($r in $rows) {
      $label = "ACL DRYRUN $($r.user) $($r.cmd -join ' ')"
      # 인자 목록을 배열로 만들어 펼친다(@kargs) — 명령 낱말이 따로따로 간다(배열 인자를 그대로 넘기면 받는 쪽이 함수일 때 한 덩어리 'REPLICAOF NO ONE' 이 되고 -- 도 사라진다 — 실측) · 비밀번호는 argv 에 없다
      $kargs = @('--kubeconfig', $kc, '-n', 'data', 'exec', '-i', "deploy/dragonfly-$envSel", '-c', 'dragonfly', '--', 'redis-cli', '--user', 'admin', '--askpass', 'ACL', 'DRYRUN', $r.user) + @($r.cmd)
      $out = @(($pw + "`n") | kubectl @kargs 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0) {
        $kerr = & $firstErr @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
        $out = $null
        throw "kubectl exec 실패(exit=$rc · $kerr) — $label 를 보내지 못했다(판정 불가 · 관리자 kubeconfig · pod 상태 확인)" }
      $c = & $classify $out
      $out = $null
      if (& $eq $c.kind 'auth') { throw "admin AUTH 실패 — $label(kv 의 admin 비밀번호와 라이브 aclfile 이 어긋난다 · ACL LOAD 여부 · 회전 반쪽 확인 — 판정 불가)" }
      $ok = (& $eq $c.kind $r.want)
      $got = $c.show
      if (& $eq $c.kind 'ok') { $got = '허용(OK)' } elseif (& $eq $c.kind 'deny') { $got = "거부($($c.show))" }
      $res[$label] = [pscustomobject]@{ ok = $ok; text = "$got · 기대 $($kname[$r.want])" } }
    $pw = $null
    $done = $true }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable pw, tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, o, out, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T075 O-6 사후 요약(admin ACL DRYRUN · env=$(if ($envSel) { $envSel } else { '선택 전' }) · 비밀번호 · 해시 없음 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---"
    foreach ($k in $res.Keys) {
      if ($res[$k].ok) { Write-Host "PASS $k → $($res[$k].text)" } else { Write-Host "FAIL $k → $($res[$k].text)" } }
    $nPass = @($res.Values | Where-Object { $_.ok }).Count
    if (-not $done) { Write-Host "o6-post $(if ($envSel) { $envSel } else { '-' })=판정 불가(중단 — 위 오류 · 런북 §4 T075 실패 표)" }
    elseif ($nPass -eq $res.Count) { Write-Host "o6-post $envSel=PASS $nPass/$($res.Count)" }
    else { Write-Host "o6-post $envSel=FAIL $nPass/$($res.Count) — ACL LOAD 가 OK 였다면 마운트 파일이 아직 옛 내용이었다(5단계 미반영) → 기다린 뒤 6–7단계를 다시 한다(런북 §4 T075 실패 갈래)" }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
