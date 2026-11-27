& {
  # ===== T076 W-7 블록 — kv/platform/access/tester-m2m 시드(Cloudflare tofu 출력 → Vault · 1회 · 쓰기 0 으로 끝날 수 있다) · 파일로만 실행(창 D) =====
  # 선례: T075 W-2(t075-blocks/w2-kv-seed.ps1 — 닫힌 과제 · 고치지 않는다)의 바이트 사본에서 파생했다 — 원칙 (a)–(h) · 정지점 · 상태 기계(absent · live · dead) · JSON stdin ·
  #       되읽기 SHA-256 Ordinal + current_version +1 · 응답 유실 재판정 · 조건부 정리 · 요약 · finally 는 그대로이고, 경로(하나) · 값의 출처(tofu 출력 — O-1 · O-5 의 추출 꼴) ·
  #       live 갈래(같으면 건너뜀 · 다르면 멈춤)만 바꿨다(설계 t076-design.md D2-1 · D3 · D7 · UD-15 · 비판 B-10).
  # 목적: tester 의 Access 서비스 토큰 tester-m2m(T011 · 2027-09-03 만료)의 client_id · client_secret 을 kv/platform/access/tester-m2m 에 넣는다 — T077 몫이던 시드를 앞당겼다(UD-15).
  #       그 경로를 읽는 것은 tester 의 O-8 블록(role e2e-reader)뿐이다 — eso-platform 정책은 platform/access/* 를 deny 한다(D2-2 · 「ESO 밖」을 Vault ACL 로 강제)
  # 자격(운영자 창): ① tofu 상태를 읽을 수 있는 창(infra/cloudflare 백엔드 — O-1 · O-5 와 같다) ② Vault root 토큰(PM — T084 뒤에는 OIDC admin) · 에이전트는 이 블록을 실행하지 않는다
  # 값의 출처: tofu -chdir=<저장소>\infra\cloudflare output -json service_tokens(sensitive — 토큰 넷의 client_secret 이 함께 든다)에서 tester-m2m 의 client_id · client_secret 둘만 변수로
  #   받고 나머지(토큰 셋 · expires_at)는 바로 버린다. 꼴(T075 L4 실측 · -cmatch · \A…\z): client_id = ^[0-9a-f]{32}\.access$ · client_secret = ^[0-9A-Za-z_-]{54}$ —
  #   아니면 Vault 토큰을 묻기 전에 멈춘다(쓰기 0 · 값 미출력)
  # 쓰기 보호 판정(정지점 앞 · 쓰기 0 으로 끝날 수 있다):
  #   absent → 생성 예정 — vault kv put "-cas=0" + JSON stdin · 키 정확히 client_id · client_secret
  #   live   → 키 집합 정확히 {client_id, client_secret} · 두 값이 tofu 의 것과 SHA-256 Ordinal 로 같으면 건너뜀(이미 있음 · 같음 — 쓰기 0) · 다르면 STOP(회전 = T084 — 덮어쓰지 않는다)
  #   dead   → STOP(soft-delete · destroy · current_version=0 — 사람 판단 · 되살리거나 지우지 않는다) · 조회 오류 · 해석 실패 → STOP(판정 불가 = FAIL)
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T076 · docs/runbooks/vault-unseal.md §0 · §12): ① 창 D 창 시작 체크리스트(클립보드 기록 0 · 모듈 로깅 정책 0)
  #   ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200 ③ 이 창에 VAULT_* 없음(VAULT_ADDR=http://127.0.0.1:18200 만 허용) · ~/.vault-token 없음 ·
  #   TF_LOG* · TF_CLI_ARGS* · TF_WORKSPACE · TF_DATA_DIR · SSL_CERT_FILE · SSL_CERT_DIR · CURL_CA_BUNDLE · SSLKEYLOGFILE · *_PROXY 없음(블록도 첫머리에서 본다)
  #   ④ PM 의 root 토큰 항목 ⑤ O-10(음성 대조) PASS · Vault 정책 apply(D2-2)를 끝냈다(설계 D14 순서)
  # 가드(묻기 · 읽기 전 — 하나라도 어긋나면 아무것도 묻지 · 읽지 않는다): 클립보드 기록 → 모듈 로깅(4키 + 실효) → 남는 인자 0($script:args) → ~/.vault-token · VAULT_* →
  #   tofu · TLS · 프록시 환경 변수 → 파일 실행 · infra\cloudflare → tofu · vault 첫 해석 = Application(형식 필터 없는 Get-Command — 같은 이름의 함수 · 별칭 · 프로필 정의면 멈춘다)
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>'(파일로만 — 저장소 경로를 파일 위치에서 찾는다 · 붙여넣기는 첫 검사에서 멈춘다) · 인자 0(남는 인자가 하나라도 있으면 w7=STOP 인자 …)
  # 정지점(입력 순서): ① root 토큰 — 보안 입력(tofu 출력의 꼴을 본 뒤 · vault status 의 cluster_name = vault-cluster-d3b29227 을 본 뒤에 묻는다 — tofu 가 도는 동안 VAULT_TOKEN 0 ·
  #                    붙인 직후 클립보드를 비운다)
  #                  ② seed — 쓰기 확인(absent 일 때만 나온다 · 대소문자 구분 · 가려진다)
  # 원칙: (a) 사람 동작마다 정지점(입력 버퍼를 비운 뒤 단어) (b) 판정에서 STOP 이면 쓰기 0 (c) 쓰기는 kv put "-cas=0" + JSON stdin 한 번뿐(patch · delete 0)
  #       (d) 되읽기는 JSON + SHA-256 Ordinal + current_version = 쓰기 전 + 1 (e) 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 0 — 출력은 Write-Host/Write-Warning 뿐
  #       (f) 쓰기가 비 0 이어도 「쓰지 않았다」고 단정하지 않고 값 없이 다시 판정한다(current_version 그대로 = 쓰지 않았다 · +1 이고 되읽기 해시 일치 = 기록됨(응답 유실 — 이 실행의 값) ·
  #           +1 인데 다르면 CAS 충돌 STOP · 그 밖 = 결과 미확인) (g) 정리는 조건부(블록이 만든 VAULT_TOKEN · VAULT_ADDR 만)
  #       (h) finally 가 env · 비밀 변수 · 클립보드 · $Error(이 실행분)를 먼저 정리하고 요약을 낸다 · 모듈 로깅 4키 가드 + 실효 확인이 ConvertFrom-Json · tofu 보다 먼저다
  # 출력: 끝 줄 하나 — w7=OK absent→v1 · w7=SKIP live-same · w7=STOP <사유>(값 · 해시 없음 — 런북 §4 T076 기록 칸에 그대로) · 마지막 줄 = 창 정리 안내 두 꼴(w7=OK · w7=SKIP 이면
  #       창 C 종료 · 그 밖(STOP · 예외 · 중단 — 기본값)은 창 C 유지 — 런북 §4 T076 실패 표 조치에 18200 이 필요하다 · RO2-02)
  # 모의 하네스: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-op.ps1 → 시나리오 PASS n / n
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
  $kvPath = 'kv/platform/access/tester-m2m'
  $tokName = 'tester-m2m'
  $sumLog = [ordered]@{}
  $sumLog[$kvPath] = '미실행(판정 전 중단 — 쓰기 0)'
  $tokenOwned = $false
  $addrOwned = $false
  # 창 정리 줄(T076 r2 — RO2-02): 기본값 = 창 C 유지(w7=STOP · 예외 · 중단 — 런북 §4 실패 표 조치에 18200 이 필요하다) · finally 의 w7=OK · w7=SKIP 갈래에서만 닫기로 바꾼다
  $winClose = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    # ---------- 헬퍼(값을 출력하지 않는다 — 돌려주는 것은 판정 · 불리언 · 해시뿐이고 해시도 출력하지 않는다) ----------
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $sha = { param($s) [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $stop = { param($msg, $word)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)" -MaskInput
      if (-not (& $eq $ans $word)) { throw "정지점에서 중단: $msg — kv 쓰기 0건" } }
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt(아무것도 쓰지 않았다)" }
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
    $state = { param($path)
      $o = @(vault kv metadata get "-format=json" $path 2>&1)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      $errs = @($o | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
      $outs = @($o | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] })
      $noValue = @($errs | Where-Object { ([string]$_).StartsWith('No value found at ', [StringComparison]::Ordinal) }).Count -gt 0
      if ($rc -ne 0) {
        if ($outs.Count -eq 0 -and $noValue) { return [pscustomobject]@{ kind = 'absent'; why = ''; cv = 0 } }
        return [pscustomobject]@{ kind = 'error'; why = "metadata 조회 exit=$rc · $(& $firstErr $errs)"; cv = -1 } }
      $d = & $prop (& $parseJson $outs) 'data'
      if ($null -eq $d) { return [pscustomobject]@{ kind = 'error'; why = 'metadata 응답을 해석하지 못했다(JSON · data 없음)'; cv = -1 } }
      $cvs = [string](& $prop $d 'current_version')
      if ($cvs -cnotmatch '\A[0-9]{1,9}\z') { return [pscustomobject]@{ kind = 'error'; why = 'current_version 이 정수가 아니다'; cv = -1 } }
      $cv = [int]$cvs
      if ($cv -eq 0) { return [pscustomobject]@{ kind = 'dead'; why = 'current_version=0(메타데이터만 있고 버전이 없다)'; cv = 0 } }
      $ver = & $prop (& $prop $d 'versions') ([string]$cv)
      if ($null -eq $ver) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 항목이 versions 에 없다"; cv = $cv } }
      $des = & $prop $ver 'destroyed'
      if ($des -isnot [bool]) { return [pscustomobject]@{ kind = 'error'; why = "versions.$cv.destroyed 형식이 기대와 다르다"; cv = $cv } }
      if ($des) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 이 파기(destroy)됐다"; cv = $cv } }
      if (-not [string]::IsNullOrEmpty([string](& $prop $ver 'deletion_time'))) { return [pscustomobject]@{ kind = 'dead'; why = "현재 버전 $cv 에 deletion_time 이 있다(soft-delete 또는 삭제 예약)"; cv = $cv } }
      [pscustomobject]@{ kind = 'live'; why = ''; cv = $cv } }
    $readData = { param($path)
      $o = @(vault kv get "-format=json" $path 2>$null)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or $o.Count -eq 0) { return [pscustomobject]@{ dd = $null; why = "kv get exit=$rc(값을 읽지 못했다)" } }
      $jr = & $parseJson $o
      $o = $null
      if ($null -eq $jr) { return [pscustomobject]@{ dd = $null; why = 'kv get 응답을 해석하지 못했다(원문 미출력)' } }
      $dd = & $prop (& $prop $jr 'data') 'data'
      $jr = $null
      if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) { return [pscustomobject]@{ dd = $null; why = '현재 버전에 데이터가 없다(data.data 가 없거나 객체가 아니다)' } }
      [pscustomobject]@{ dd = $dd; why = '' } }
    # 키 집합 정확히 + 값 문자열(분류 사유만)
    $keyCheck = { param($dd, $keys)
      $names = @($dd.PSObject.Properties | ForEach-Object { $_.Name })
      $missing = @(@($keys) | Where-Object { -not (& $has $names $_) })
      $extra = @($names | Where-Object { -not (& $has @($keys) $_) }).Count
      if ($missing.Count -gt 0 -or $extra -gt 0) {
        $ms = '없음'
        if ($missing.Count -gt 0) { $ms = $missing -join '·' }
        return "키 집합 불일치(누락: $ms · 여분 ${extra}개)" }
      foreach ($k in @($keys)) { if ((& $prop $dd $k) -isnot [string]) { return "$k 값이 문자열이 아니다" } }
      '' }
    # 쓰기 1건(put) + 되읽기 + 메타데이터. 비 0 은 값 없이 다시 판정한다(원칙 f). 모든 분기가 $sumLog 를 확정 문구로 덮는다.
    #   $p = 계획 행(path · cv(쓰기 전 버전 — absent = 0) · keys · want(되읽기 기대 — 키 → 값) · verb)
    $write = { param($p)
      $json = $null; $o = $null; $dd = $null
      $lost = 0
      $next = $p.cv + 1
      try {
        $sumLog[$p.path] = '결과 미확인(쓰기 진행 중 중단 — kv 에 새 버전이 있을 수 있다 · 재실행이 판정한다)'
        $json = $p.want | ConvertTo-Json -Compress
        $null = $json | vault kv put "-cas=$($p.cv)" $p.path - 2>$null
        $json = $null
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($rc -ne 0) {
          $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 전 중단 · 재실행이 판정한다)"
          $m = & $state $p.path
          if (((& $eq $m.kind 'absent') -and $p.cv -eq 0) -or ((& $eq $m.kind 'live') -and $m.cv -eq $p.cv)) {
            $sumLog[$p.path] = "중단(쓰기 거부 exit=$rc — 재판정 current_version 그대로 · 쓰지 않았다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$rc) · 재판정 current_version 그대로 = 쓰지 않았다(권한 · 연결 · CAS · CLI 오류 — 같은 STOP 이 반복되면 토큰 정책 · 창 C 확인)"
            throw "쓰기 거부: $($p.path) — 중단(쓰기 0)" }
          if (-not (& $eq $m.kind 'live') -or $m.cv -ne $next) {
            $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 $($m.kind) · current_version=$($m.cv) · 재실행이 판정한다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$rc) · 재판정 $($m.kind)(current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why })): 이 실행의 값이 기록됐는지 확인하지 못했다 — 지우지 말고 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)"
            throw "쓰기 거부: $($p.path) — 결과 미확인" }
          $lost = $rc
          $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 v$next · 되읽기 대조 전 중단)" }
        else { $sumLog[$p.path] = "기록됨 v$next — 되읽기 검증 전(아래 오류 확인)" }
        $how = '쓰기'
        if ($lost) { $how = "기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=$lost 뒤 재판정)" }
        $o = @(vault kv get "-format=json" $p.path 2>$null)
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($rc -ne 0 -or $o.Count -eq 0) {
          $sumLog[$p.path] = "기록됨 — 되읽기 실패(exit=$rc · 재실행이 판정한다)"
          Write-Host "STOP $($p.path) — 되읽기 실패(exit=$rc). 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)"
          throw "되읽기 실패: $($p.path) — 중단" }
        $dd = & $prop (& $prop (& $parseJson $o) 'data') 'data'
        $o = $null
        if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) {
          $sumLog[$p.path] = '기록됨 — 되읽기 응답 해석 실패(재실행이 판정한다)'
          Write-Host "STOP $($p.path) — 되읽기 응답을 해석하지 못했다(원문 미출력)"
          throw "되읽기 실패: $($p.path) — 중단" }
        $kc = [string](& $keyCheck $dd $p.keys)
        $bad = @()
        if ($kc.Length -eq 0) { foreach ($k in @($p.want.Keys)) { if (-not (& $eq (& $sha (& $prop $dd $k)) (& $sha $p.want[$k]))) { $bad += $k } } }
        if ($kc.Length -gt 0 -or $bad.Count -gt 0) {
          $why = $kc
          if ($why.Length -eq 0) { $why = "해시 불일치($($bad -join '·'))" }
          if ($lost) {
            $sumLog[$p.path] = "중단(쓰기 거부 exit=$lost — 재판정 v$next · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$lost) · CAS 충돌(다른 값 — $why · 값 · 해시는 출력하지 않는다): kv 의 v$next 은 다른 기록자의 값이다(사람 판단)"
            throw "쓰기 거부: $($p.path) — CAS 충돌(덮어쓰기 0)" }
          $sumLog[$p.path] = "기록됨 — 되읽기 불일치($why) · 수동 확인"
          Write-Host "STOP $($p.path) — 되읽기 불일치($why — 값 · 해시는 출력하지 않는다)"
          throw "되읽기 불일치: $($p.path) — 중단" }
        $m = & $state $p.path
        if (-not (& $eq $m.kind 'live') -or $m.cv -ne $next) {
          $sumLog[$p.path] = "기록됨 — 메타데이터 확인 실패($($m.kind) · current_version=$($m.cv) · 기대 $next)"
          Write-Host "STOP $($p.path) — 쓰기 뒤 메타데이터가 current_version=$next · 삭제 없음이 아니다($($m.kind) · current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why }))"
          throw "메타데이터 확인 실패: $($p.path) — 중단" }
        $what = "되읽기 해시 일치($(@($p.want.Keys) -join '·'))"
        if ($lost) { $sumLog[$p.path] = "$how v$next · $what" }
        else { $sumLog[$p.path] = "$($p.verb) v$next · $what" }
        Write-Host "OK   $($p.path) v$next — $(if ($lost) { $how } else { $p.verb }) · $what" }
      finally { $json = $null; $o = $null; $dd = $null } }
    # ---------- 0) 창 전제 — 모듈 로깅 4키 가드 + 실효 확인이 ConvertFrom-Json · tofu 보다 먼저다 ----------
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
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 service_tokens 출력 원문(client_secret) · kv · 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 묻지 않았다)" }
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
    if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw "PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: $($mlEff -join ', ') · 설정 파일 정책(값 무관): $($mlCfgOn -join ', ') · 모듈 $($mlMods.Count)/2 · Management $($mlMgmt.Count)/1 · Core 스냅인 $(if ($null -ne $mlCore) { '확인' } else { '모름' }) · 사용자 설정 위치 $(if ($mlUser) { '확인' } else { '모름' })) — 켜진 채로는 service_tokens 출력 원문(client_secret) · kv · 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 끈 창 · PC 에서 다시(아무것도 묻지 않았다)" }
    # 남는 인자(T076 r1 — 리뷰 S-07 · C-02 · RO-02): 이 블록은 인자를 받지 않는다(입력은 정지점 root 토큰 · seed 뿐) — 파일 실행의 인자는 $script:args 로 들어와 조용히 버려지므로
    #   하나라도 있으면 아무것도 묻지 · 읽지 않고 멈춘다(값 미출력). $script:args 가 $null 이면 인자 0 이다(@($null).Count = 1 이라 $null 을 걸러 센다)
    $nArg = @($script:args | Where-Object { $null -ne $_ }).Count
    if ($nArg -gt 0) {
      $sumLog[$kvPath] = "인자 ${nArg}개(값 미출력 — 이 블록은 인자를 받지 않는다 · 입력은 정지점 root 토큰 · seed 뿐) — 미실행(아무것도 묻지 · 읽지 않았다 · 쓰기 0)"
      throw "남는 인자 ${nArg}개 — 이 블록은 인자를 받지 않는다(아무것도 묻지 · 읽지 않았다)" }
    if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인을 확인하고 지운 뒤 다시(아무것도 묻지 않았다)' }
    $pre = @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })
    $bad = @($pre | Where-Object { -not ([string]::Equals($_.Name, 'VAULT_ADDR', [StringComparison]::OrdinalIgnoreCase) -and (& $eq $_.Value $vaultAddr)) } | ForEach-Object { $_.Name })
    if ($bad.Count -gt 0) { throw "이 창에 VAULT_* 환경 변수가 이미 있다: $($bad -join ', ') — 블록은 건드리지 않았다. 확인 뒤 Remove-Item Env:<이름> 하고 다시(VAULT_ADDR=$vaultAddr 만 허용 · 아무것도 묻지 않았다)" }
    # tofu · TLS · 프록시 동작을 바꾸는 환경 변수(T075 O-1 · O-5 와 같은 목록 — 리뷰 KB-1 · KB-8 · KB2-2): TF_LOG*(sensitive 출력 원문이 로그에) · TF_CLI_ARGS*(숨은 인자) · TF_WORKSPACE ·
    #   TF_DATA_DIR(다른 상태) · SSL_CERT_FILE · SSL_CERT_DIR · CURL_CA_BUNDLE(신뢰 앵커 교체) · SSLKEYLOGFILE(TLS 키 기록) · HTTP_PROXY · HTTPS_PROXY · ALL_PROXY(대소문자 무관)가
    #   있으면 tofu 를 부르기 전에 멈춘다 — 이름만 낸다(값은 내지 않는다)
    $netBad = @(Get-ChildItem Env: | Where-Object { @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR') -contains $_.Name -or $_.Name -like 'TF_LOG*' -or $_.Name -like 'TF_CLI_ARGS*' } | ForEach-Object { $_.Name })
    if ($netBad.Count -gt 0) { throw "이 창에 tofu · TLS · 프록시 동작을 바꾸는 환경 변수가 있다: $($netBad -join ', ') — 값은 내지 않는다. Remove-Item Env:<이름> 뒤 새 창에서 다시(아무것도 읽지 않았다)" }
    if ([string]::IsNullOrEmpty($PSScriptRoot)) { throw '파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로>) — 저장소 경로를 파일 위치에서 찾는다(아무것도 읽지 않았다)' }
    $infra = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\infra\cloudflare'))
    if (-not (Test-Path -LiteralPath (Join-Path $infra 'outputs.tf'))) { throw "infra/cloudflare 를 찾지 못했다($infra) — 블록 파일이 저장소 밖에 있다(아무것도 읽지 않았다)" }
    $tcs = @(Get-Command tofu -ErrorAction SilentlyContinue)
    if ($tcs.Count -eq 0) { throw 'tofu CLI 를 찾을 수 없다(PATH) — 아무것도 읽지 않았다' }
    $vcs = @(Get-Command vault -ErrorAction SilentlyContinue)
    if ($vcs.Count -eq 0) { throw 'vault CLI 를 찾을 수 없다(PATH) — 설치 · PATH 확인(아무것도 묻지 않았다)' }
    # 첫 해석(T076 r1 — 리뷰 S-10): 형식 필터 없는 Get-Command 의 첫 해석 = 이 블록이 tofu · vault 를 부를 때 실제로 도는 것 — Application 이 아니면(같은 이름의 함수 · 별칭 · 프로필
    #   정의 — tofu 출력의 client_secret · root 토큰 · kv 본문이 그 함수로 간다) 멈춘다(tofu · vault 0)
    $shadow = @()
    if (-not (& $eq ([string]$tcs[0].CommandType) 'Application')) { $shadow += "tofu → $(([string]$tcs[0].CommandType) -replace '\p{Cc}', '?')" }
    if (-not (& $eq ([string]$vcs[0].CommandType) 'Application')) { $shadow += "vault → $(([string]$vcs[0].CommandType) -replace '\p{Cc}', '?')" }
    if ($shadow.Count -gt 0) {
      $sumLog[$kvPath] = "미실행(첫 해석이 실행 파일이 아니다: $($shadow -join ' · ') — 같은 이름의 함수 · 별칭 · 프로필 정의 · 아무것도 읽지 않았다 · 쓰기 0)"
      throw "첫 해석이 실행 파일(Application)이 아니다: $($shadow -join ' · ') — 아무것도 읽지 않았다" }
    $vsrc = [string]$vcs[0].Source
    if ([string]::IsNullOrEmpty($vsrc)) { $vsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $vsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $vsrc = '~' + $vsrc.Substring($HOME.Length) }
    $tsrc = [string]$tcs[0].Source
    if ([string]::IsNullOrEmpty($tsrc)) { $tsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $tsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $tsrc = '~' + $tsrc.Substring($HOME.Length) }
    $ver = @(vault version 2>$null)
    $global:LASTEXITCODE = 0
    $verLine = '(버전 출력 없음)'
    if ($ver.Count -gt 0) { $verLine = ([string]$ver[0]).Trim() -replace '\p{Cc}', '?' }
    $tv = @(tofu version 2>$null)
    $global:LASTEXITCODE = 0
    $tvl = '(버전 출력 없음)'
    if ($tv.Count -gt 0) { $tvl = ([string]$tv[0]).Trim() -replace '\p{Cc}', '?' }
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc · tofu $tvl · $([string]$tcs[0].CommandType) $tsrc — 쓰기 = kv put -cas=0 한 번뿐(absent 일 때) · tofu 는 출력 읽기만"
    # ---------- 1) tester-m2m 자격(sensitive 출력 — client_id · client_secret 만 꺼내고 나머지는 버린다 · Vault 토큰을 묻기 전 · 이 창에 VAULT_TOKEN 0) ----------
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
    # 자격 꼴(T075 L4 d5 실측 — 토큰 넷 모두 같다): client_id = 소문자 hex 32 + .access · client_secret = 54자 [A-Za-z0-9_-](옛 64 hex 꼴 · 끝 줄바꿈 · CR · 유니코드 꼴은 밖)
    if ($rc -ne 0 -or $cid -isnot [string] -or $csec -isnot [string] -or $cid -cnotmatch '\A[0-9a-f]{32}\.access\z' -or $csec -cnotmatch '\A[0-9A-Za-z_-]{54}\z') {
      $cid = $null; $csec = $null
      $sumLog[$kvPath] = '미실행(자격 꼴 아님 — tofu 출력에서 tester-m2m 을 꺼내지 못했다 · Vault 토큰을 묻지 않았다 · 쓰기 0)'
      throw "자격을 꺼내지 못했다($tokName — tofu output exit=$rc · client_id ^[0-9a-f]{32}\.access$ · client_secret ^[0-9A-Za-z_-]{54}$ 꼴 아님 — 값 미출력) · Vault 토큰을 묻지 않았다 · 쓰기 0" }
    Write-Host "OK   tofu 출력 service_tokens → $tokName 의 client_id · client_secret 꼴 확인(값 미출력 · 나머지 토큰은 버렸다)"
    # ---------- 2) Vault 도달 — 토큰 없이 ----------
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
    # cluster_name(T076 r1 — 리뷰 S-09): root 토큰을 묻기 전에 창 C 가 가리키는 Vault 가 이 클러스터의 것인지 본다 — O-10 · O-8 과 같은 값(bootstrap.md 「git 밖 라이브 상태」) ·
    #   다르거나 없으면 멈춘다(토큰을 묻지 않는다 · 쓰기 0) · cluster_name 은 비밀이 아니다(제어 문자 → ? · 160자로 낸다)
    $cn = & $prop $st 'cluster_name'
    if (-not (& $eq $cn 'vault-cluster-d3b29227')) {
      $cns = ([string]$cn) -replace '\p{Cc}', '?'
      if ($cns.Length -gt 160) { $cns = $cns.Substring(0, 160) + '…' }
      if ($cns.Length -eq 0) { $cns = '(없음)' }
      $sumLog[$kvPath] = "미실행(Vault cluster_name = $cns — 기대 vault-cluster-d3b29227 · 창 C 가 다른 Vault 를 가리킨다 · root 토큰을 묻지 않았다 · 쓰기 0)"
      throw 'Vault cluster_name 이 vault-cluster-d3b29227 이 아니다 — 창 C port-forward 대상 확인(root 토큰은 아직 묻지 않았다 · 쓰기 0)' }
    Write-Host "OK   Vault 도달 · 초기화됨 · unsealed · cluster_name = vault-cluster-d3b29227(seal type=$(([string](& $prop $st 'type')) -replace '\p{Cc}', '?') · server $(([string](& $prop $st 'version')) -replace '\p{Cc}', '?'))"
    # ---------- 3) root 토큰(PM) ----------
    $tok = ([string](& $readSecret 'root 토큰(PM 에서 복사 · 화면에 남지 않음 · 붙여넣은 직후 클립보드를 비운다)')).Trim()
    if ($tok -cnotmatch '\Ahvs\.[\x21-\x7E]+\z') { $tok = $null; throw '입력이 Vault 토큰 형식(hvs. 로 시작하는 공백 없는 ASCII)이 아니다 — PM 의 다른 항목을 붙여 넣었다. Vault 로 보내지 않았다 · 아무것도 쓰지 않았다' }
    $tokenOwned = $true
    $env:VAULT_TOKEN = $tok
    $tok = $null
    $tl = @(vault token lookup "-format=json" 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pol = @()
    if ($rc -eq 0) { $pol = @(& $prop (& $prop (& $parseJson $tl) 'data') 'policies') }
    $tl = $null
    if ($rc -ne 0) { throw "root 토큰 확인 실패(token lookup exit=$rc) — PM 항목 · 창 C 확인. 아무것도 쓰지 않았다" }
    if (-not (& $has $pol 'root')) { throw '토큰 정책에 root 가 없다 — 이 블록은 root 토큰 전용이다(T044 D4). 아무것도 쓰지 않았다' }
    Write-Host 'OK   토큰 정책에 root 포함 — 쓰기 보호 판정(읽기 전용)을 시작한다'
    # ---------- 4) 쓰기 보호 판정(읽기 전용) ----------
    $plan = $null
    $why = ''
    $s = & $state $kvPath
    if (& $eq $s.kind 'absent') {
      $plan = [pscustomobject]@{ path = $kvPath; cv = 0; keys = @('client_id', 'client_secret'); want = [ordered]@{ client_id = $cid; client_secret = $csec }; verb = '생성' }
      $sumLog[$kvPath] = '쓰기 예정(판정 — absent → 생성 예정 · 쓰기 확인 전)'
      Write-Host "PLAN $kvPath — absent → 생성 예정(키 client_id · client_secret · -cas=0) · 지금 v0" }
    elseif (& $eq $s.kind 'live') {
      $r = & $readData $kvPath
      if ($null -eq $r.dd) { $why = "판정 불가 — $($r.why)" }
      else {
        $kc = [string](& $keyCheck $r.dd @('client_id', 'client_secret'))
        if ($kc.Length -gt 0) { $why = "live-mismatch: $kc(값 미출력 · 사람 판단 — 덮어쓰지 않는다)" }
        else {
          $diff = @()
          if (-not (& $eq (& $sha (& $prop $r.dd 'client_id')) (& $sha $cid))) { $diff += 'client_id' }
          if (-not (& $eq (& $sha (& $prop $r.dd 'client_secret')) (& $sha $csec))) { $diff += 'client_secret' }
          if ($diff.Count -gt 0) { $why = "live-different: $($diff -join '·') 가 tofu 의 $tokName 과 다르다(회전 = T084 — 덮어쓰지 않는다 · 값 · 해시 미출력)" } } }
      $r = $null
      if ($why.Length -eq 0) {
        $sumLog[$kvPath] = "건너뜀(이미 있음 · 같음 — v$($s.cv) · 키 client_id · client_secret · 덮어쓰지 않았다)"
        Write-Host "SKIP $kvPath — 이미 있음 · 같음(v$($s.cv) · 키 client_id · client_secret = tofu 의 $tokName · 값 · 해시 미출력 · 덮어쓰지 않는다)" } }
    elseif (& $eq $s.kind 'dead') { $why = "dead — $($s.why)(사람 판단 — 되살리거나 지우지 않는다)" }
    else { $why = "판정 불가 — $($s.why)" }
    if ($why.Length -gt 0) {
      $sumLog[$kvPath] = "중단($why)"
      Write-Host "STOP $kvPath — $why"
      throw "판정 단계에서 중단 — $kvPath · kv 쓰기 0건" }
    if ($null -eq $plan) { return }
    # ---------- 5) 쓰기 확인(정지점 — 경로 · 키 이름만 · 값은 화면에 나오지 않는다) ----------
    Write-Host ''
    Write-Host "쓸 경로 1개: $kvPath  (생성 · -cas=0 · 키 client_id · client_secret = tofu 출력의 $tokName — 값은 화면에 나오지 않는다)"
    try { & $stop "쓰기 확인: $kvPath 를 -cas=0 으로 만든다(그 사이 누가 만들었으면 거부 — 덮어쓰기 없음)" 'seed' }
    catch {
      $sumLog[$kvPath] = '미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)'
      throw }
    # ---------- 6) 쓰기 + 되읽기 ----------
    try { & $write $plan }
    finally { $plan.want = $null } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, tv, tvl, o, j, t, cid, csec, s, r, plan, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host '--- T076 W-7 tester-m2m kv 시드 결과(값 · 해시 없음 — 런북 bootstrap.md §4 T076 기록 칸에 그대로 기록) ---'
    foreach ($k in $sumLog.Keys) { Write-Host ('{0,-32} {1}' -f $k, $sumLog[$k]) }
    $row = [string]$sumLog[$kvPath]
    if ($row.StartsWith('생성 v1 ', [StringComparison]::Ordinal)) { Write-Host 'w7=OK absent→v1'; $winClose = $true }
    elseif ($row.StartsWith('기록됨(응답 유실', [StringComparison]::Ordinal)) { Write-Host 'w7=OK absent→v1 · 응답 유실 뒤 재판정(이 실행의 값 · 되읽기 해시 일치)'; $winClose = $true }
    elseif ($row.StartsWith('건너뜀(', [StringComparison]::Ordinal)) { Write-Host 'w7=SKIP live-same'; $winClose = $true }
    else { Write-Host "w7=STOP $row" }
    if ($row.StartsWith('결과 미확인', [StringComparison]::Ordinal)) { Write-Host '결과 미확인 = 쓰기 도중 중단 또는 비 0 뒤 재판정 불가 — kv 에 새 버전이 있을 수 있다. 지우지 말고 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)' }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    # 마지막 줄 = 창 정리 안내(RO-03 · RO2-02): w7=OK · w7=SKIP 이면 창 C 를 닫고 · 그 밖(STOP · 예외 · 중단 — 기본값)은 창 C 를 닫지 않는다(실패 표 조치가 18200 을 쓴다)
    if ($winClose) { Write-Host '창 정리(T076 — 런북 bootstrap.md §3 T076 ①-5): 창 C port-forward(18200) 종료(Ctrl+C — 뒤 단계는 18200 을 쓰지 않는다) · 창 A 터널 · 창 D 는 닫지 않는다(②-3 O-7 · ④-1 · ④-3 O-9 · ⑤ 세션 끝 정리까지)' }
    else { Write-Host '창 정리(T076 — 런북 bootstrap.md §4 T076 실패 표): 창 C port-forward(18200) 는 닫지 않는다(실패 표 조치 — 재실행 · 버전 이력 · cluster_name 조사에 18200 이 필요하다) · 창 A 터널 · 창 D 도 닫지 않는다' }
  }
}
