& {
  # ===== T075 W-2 블록 — identity-admin kv 쓰기(env 하나씩 · dev 먼저) · 4경로 · 통째로 붙여 넣어도 안전(창 D) =====
  # 선례: T057 시드 블록(t057-blocks/op1-seed-dragonfly.ps1)의 원칙 (a)–(h) · 정지점 · 상태 기계 · JSON stdin · 되읽기 SHA-256 Ordinal · 응답 유실 재판정 · 조건부 정리 · 요약 표 · finally 를
  #       따르고, 경로 · 값 · 쓰기 꼴(kv patch · -cas=<현재 버전>)만 바꿨다(설계 t075-design.md D10 · CD-8 · CD-9 · CD-10 · VD-T075-11).
  # 목적: identity-admin 배포(gitops GP-2 · GP-3) 전에 그 env 의 4경로를 쓴다 — 판정은 이 블록의 쓰기 보호 가드뿐이고, 사람이 보는 판정은 앞 O-2 와 뒤 O-3(게이트)이다.
  # 경로(env 마다 4 · 이 순서로 쓴다):
  #   kv/<env>/authentik/identity-admin          jwks_url · issuer 만 계약 값으로 — vault kv patch "-cas=<n>" <path> issuer=<값> jwks_url=<값>(비밀 아님 — argv 허용 · 나머지 3키 보존)
  #                                              jwks_url = http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/ · issuer = https://auth.joshuatech.dev/application/o/identity-admin/
  #                                              client_id · client_secret · api_token 은 T044 sentinel 그대로(api_token 은 overlay JT_PLACEHOLDER_EXEMPT 로 면제 · 둘은 pod 에 매핑하지 않는다)
  #   kv/<env>/authentik/webhooks/identity-admin secret = RandomNumberGenerator 32바이트 → base64url(패딩 없음 · 43자) — T044 sentinel 을 "-cas=<n>" JSON stdin 으로 덮어쓴다 ·
  #                                              HMAC 키 = 그 43자 문자열의 ASCII 바이트(디코드하지 않는다 · 끝 줄바꿈 없음 — django-common auth.py secret.encode() · 설계 CD-9) ·
  #                                              dev ≠ prod · US4(T081)에서도 바꾸지 않는다 — 이미 실값이면 건너뛴다(회전이 아니다)
  #   kv/<env>/django/identity-admin             secret_key = RandomNumberGenerator 48바이트 → base64url 64자(W009 — 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 아님) · dev ≠ prod · "-cas=0"
  #   kv/<env>/sentry/identity-admin             {"dsn": ""} — 빈 값 = Sentry 끔(경로가 없으면 identity-admin-env 가 SecretSyncedError) · "-cas=0" · 실값은 T100
  # 쓰기 보호 가드(판정 단계 — 정지점 앞 · 쓰기 0 으로 끝날 수 있다):
  #   authentik: live · 키 집합 정확히 5 · 값 문자열 · jwks_url 과 issuer 가 둘 다 sentinel → patch 예정 / 둘 다 계약 값 → 건너뜀 / 그 밖 → STOP(사람 판정 · 덮어쓰지 않는다)
  #   webhook  : live · 키 집합 {secret} · sentinel → 덮어쓰기 예정 / 43자 base64url → 건너뜀 / 그 밖 · absent · dead → STOP
  #   django   : absent → 생성 예정 / live {secret_key} 64자 base64url + W009 → 건너뜀 / 그 밖 → STOP
  #   sentry   : absent → 생성 예정 / live {dsn: ""} → 건너뜀 / 그 밖(비지 않은 dsn 포함) → STOP
  #   쌍 판정  : 다른 env 의 webhook secret · secret_key 와 SHA-256 이 같으면 STOP(건너뜀 값은 판정 단계 · 생성 값은 put 직전). prod 차례에는 dev 두 값이 먼저 있어야 한다(dev 먼저)
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T075 · docs/runbooks/vault-unseal.md §0): ① 창 D 창 시작 체크리스트(클립보드 기록 0 · 모듈 로깅 정책 0)
  #   ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200 ③ 이 창에 VAULT_* 없음(VAULT_ADDR=http://127.0.0.1:18200 만 허용) · ~/.vault-token 없음
  #   ④ PM 의 root 토큰 항목 ⑤ O-2 출력(W-2 전제 충족)을 컨트롤러에게 붙였다
  # 실행: pwsh -NoProfile -File '<이 파일의 절대 경로>'(권장) 또는 pwsh -NoProfile 로 새로 연 창에 전문 붙여넣기(& { … } 한 문)
  # 정지점(입력 순서): ① env — dev 또는 prod 를 그대로(입력은 가려진다 · 그 외 = 중단) ② root 토큰 — 보안 입력(붙인 직후 클립보드를 비운다)
  #                  ③ seed — 쓰기 확인(쓸 경로가 0 이면 나오지 않는다 · 대소문자 구분)
  # 원칙: (a) 사람 동작마다 정지점(입력 버퍼를 비운 뒤 단어) (b) 가드 판정에서 STOP 이 하나라도 나오면 쓰기 0 (c) 쓰기는 kv patch(비밀 아닌 두 값) · kv put "-cas=<n>" + JSON stdin 뿐
  #       (d) 되읽기는 JSON + SHA-256 Ordinal + current_version = 쓰기 전 + 1 (e) 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 0 — 출력은 Write-Host/Write-Warning 뿐
  #       (f) 생성 값의 유일한 사본은 kv — 쓰기가 비 0 이어도 "쓰지 않았다"고 단정하지 않고 값 없이 다시 판정한다(current_version 그대로 = 쓰지 않았다 · +1 이고 되읽기 해시 일치 =
  #           기록됨(응답 유실 — 이 실행의 값) · +1 인데 다르면 CAS 충돌 STOP · 그 밖 = 결과 미확인) (g) 정리는 조건부(블록이 만든 VAULT_TOKEN · VAULT_ADDR 만)
  #       (h) finally 가 env · 비밀 변수 · 클립보드 · $Error(이 실행분)를 먼저 정리하고 요약을 낸다 · 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저다
  # 실행 뒤: O-3 <env>(게이트 — gate=PASS n/n 한 줄을 컨트롤러에게) · dev 는 O-3 dev 와 L6(UD-9) · data-assert 7 PASS 를 받은 뒤에만 GP-2 머지 명령이 나온다(설계 D10 순서)
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
  $sentinel = 'PLACEHOLDER-T044-SENTINEL'
  $jwksWant = 'http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/'
  $issWant = 'https://auth.joshuatech.dev/application/o/identity-admin/'
  $envSel = ''
  $paths = @()
  $sumLog = [ordered]@{}
  $tokenOwned = $false
  $addrOwned = $false
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
    $pickEnv = {
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host '대상 env — dev 또는 prod 를 그대로 입력(입력은 가려진다 · 그 외 입력 = 중단 · 이 실행은 그 env 의 4경로만 쓴다 · dev 먼저)' -MaskInput
      if (& $eq $ans 'dev') { return 'dev' }
      if (& $eq $ans 'prod') { return 'prod' }
      throw '정지점에서 중단: env 선택(dev · prod 가 아니다) — kv 쓰기 0건' }
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
    $w009 = { param($v) ($v -is [string]) -and $v.Length -ge 50 -and ([System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count -ge 5) -and -not $v.StartsWith('django-insecure-', [StringComparison]::Ordinal) }
    # 웹훅 secret 꼴: 43자 base64url + 서로 다른 글자 16 이상(T075 보정 2026-11-17 · 리뷰 KB-9 — 32바이트 CSPRNG 값이 16 미만일 확률 2.2×10^-13 이하 · 근거 = t075-blocks/README.md)
    $wh43 = { param($v) ($v -is [string]) -and ($v -cmatch '\A[A-Za-z0-9_-]{43}\z') -and ([System.Collections.Generic.HashSet[char]]::new([char[]]$v.ToCharArray()).Count -ge 16) }
    $newB64 = { param($n)
      $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes($n)
      try { [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') } finally { [Array]::Clear($bytes, 0, $bytes.Length) } }
    # 쓰기 1건(patch 또는 put) + 되읽기 + 메타데이터. 비 0 은 값 없이 다시 판정한다(원칙 f). 모든 분기가 $sumLog 를 확정 문구로 덮는다.
    #   $p = 계획 행(path · role · cv(쓰기 전 버전) · keys · want(되읽기 기대 — 키 → 값) · keep(보존할 키 → 쓰기 전 SHA-256))
    $write = { param($p)
      $json = $null; $o = $null; $dd = $null
      $lost = 0
      $next = $p.cv + 1
      try {
        $sumLog[$p.path] = '결과 미확인(쓰기 진행 중 중단 — kv 에 새 버전이 있을 수 있다 · 재실행이 판정한다)'
        if (& $eq $p.role 'authentik') { $null = vault kv patch "-cas=$($p.cv)" $p.path "issuer=$issWant" "jwks_url=$jwksWant" 2>$null }
        else {
          $json = $p.want | ConvertTo-Json -Compress
          $null = $json | vault kv put "-cas=$($p.cv)" $p.path - 2>$null
          $json = $null }
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($rc -ne 0) {
          $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 전 중단 · 재실행이 판정한다)"
          $m = & $state $p.path
          if (((& $eq $m.kind 'absent') -and $p.cv -eq 0) -or ((& $eq $m.kind 'live') -and $m.cv -eq $p.cv)) {
            $sumLog[$p.path] = "중단(쓰기 거부 exit=$rc — 재판정 current_version 그대로 · 쓰지 않았다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$rc) · 재판정 current_version 그대로 = 쓰지 않았다(권한 · 연결 · CAS · CLI 오류 — 같은 STOP 이 반복되면 토큰 정책 · 창 C 확인). 뒤 경로는 실행하지 않는다"
            throw "쓰기 거부: $($p.path) — 중단(쓰기 0 · 뒤 경로 미실행)" }
          if (-not (& $eq $m.kind 'live') -or $m.cv -ne $next) {
            $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 $($m.kind) · current_version=$($m.cv) · 재실행이 판정한다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$rc) · 재판정 $($m.kind)(current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why })): 이 실행의 값이 기록됐는지 확인하지 못했다 — 지우지 말고 O-2 로 본 뒤 재실행한다. 뒤 경로는 실행하지 않는다"
            throw "쓰기 거부: $($p.path) — 결과 미확인(뒤 경로 미실행)" }
          $lost = $rc
          $sumLog[$p.path] = "결과 미확인(쓰기 exit=$rc — 재판정 v$next · 되읽기 대조 전 중단)" }
        else { $sumLog[$p.path] = "기록됨 v$next — 되읽기 검증 전(아래 오류 확인)" }
        $how = '쓰기'
        if ($lost) { $how = "기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=$lost 뒤 재판정)" }
        $o = @(vault kv get "-format=json" $p.path 2>$null)
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($rc -ne 0 -or $o.Count -eq 0) {
          $sumLog[$p.path] = "기록됨 — 되읽기 실패(exit=$rc · O-2 로 본 뒤 재실행)"
          Write-Host "STOP $($p.path) — 되읽기 실패(exit=$rc). 뒤 경로로 가지 않는다 — O-2 로 그 경로를 본 뒤 재실행한다(모양이 맞으면 건너뛴다)"
          throw "되읽기 실패: $($p.path) — 중단(뒤 경로 미실행)" }
        $dd = & $prop (& $prop (& $parseJson $o) 'data') 'data'
        $o = $null
        if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) {
          $sumLog[$p.path] = '기록됨 — 되읽기 응답 해석 실패(O-2 로 본 뒤 재실행)'
          Write-Host "STOP $($p.path) — 되읽기 응답을 해석하지 못했다(원문 미출력). 뒤 경로로 가지 않는다"
          throw "되읽기 실패: $($p.path) — 중단(뒤 경로 미실행)" }
        $kc = [string](& $keyCheck $dd $p.keys)
        $bad = @()
        if ($kc.Length -eq 0) {
          foreach ($k in @($p.want.Keys)) { if (-not (& $eq (& $sha (& $prop $dd $k)) (& $sha $p.want[$k]))) { $bad += $k } }
          foreach ($k in @($p.keep.Keys)) { if (-not (& $eq (& $sha (& $prop $dd $k)) $p.keep[$k])) { $bad += $k } } }
        if ($kc.Length -gt 0 -or $bad.Count -gt 0) {
          $why = $kc
          if ($why.Length -eq 0) { $why = "해시 불일치($($bad -join '·'))" }
          if ($lost) {
            $sumLog[$p.path] = "중단(쓰기 거부 exit=$lost — 재판정 v$next · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)"
            Write-Host "STOP $($p.path) — 쓰기 거부(exit=$lost) · CAS 충돌(다른 값 — $why · 값 · 해시는 출력하지 않는다): kv 의 v$next 은 다른 기록자의 값이다. 뒤 경로는 실행하지 않는다"
            throw "쓰기 거부: $($p.path) — CAS 충돌(덮어쓰기 0 · 뒤 경로 미실행)" }
          $sumLog[$p.path] = "기록됨 — 되읽기 불일치($why) · 수동 확인"
          Write-Host "STOP $($p.path) — 되읽기 불일치($why — 값 · 해시는 출력하지 않는다). 뒤 경로로 가지 않는다"
          throw "되읽기 불일치: $($p.path) — 중단(뒤 경로 미실행)" }
        $m = & $state $p.path
        if (-not (& $eq $m.kind 'live') -or $m.cv -ne $next) {
          $sumLog[$p.path] = "기록됨 — 메타데이터 확인 실패($($m.kind) · current_version=$($m.cv) · 기대 $next)"
          Write-Host "STOP $($p.path) — 쓰기 뒤 메타데이터가 current_version=$next · 삭제 없음이 아니다($($m.kind) · current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why })). 뒤 경로로 가지 않는다"
          throw "메타데이터 확인 실패: $($p.path) — 중단(뒤 경로 미실행)" }
        $what = "되읽기 해시 일치($(@($p.want.Keys) -join '·'))"
        if ($p.keep.Count -gt 0) { $what = "되읽기 일치($(@($p.want.Keys) -join '·') = 계약 값 · 보존 $(@($p.keep.Keys) -join '·'))" }
        if ($lost) { $sumLog[$p.path] = "$how v$next · $what" }
        else { $sumLog[$p.path] = "$($p.verb) v$next · $what" }
        Write-Host "OK   $($p.path) v$next — $(if ($lost) { $how } else { $p.verb }) · $what" }
      finally { $json = $null; $o = $null; $dd = $null } }
    # ---------- 0) 창 전제 — 모듈 로깅 4키 가드가 ConvertFrom-Json 보다 먼저다 ----------
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
    $vcs = @(Get-Command vault -ErrorAction SilentlyContinue)
    if ($vcs.Count -eq 0) { throw 'vault CLI 를 찾을 수 없다(PATH) — 설치 · PATH 확인(아무것도 묻지 않았다)' }
    $vsrc = [string]$vcs[0].Source
    if ([string]::IsNullOrEmpty($vsrc)) { $vsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $vsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $vsrc = '~' + $vsrc.Substring($HOME.Length) }
    $ver = @(vault version 2>$null)
    $global:LASTEXITCODE = 0
    $verLine = '(버전 출력 없음)'
    if ($ver.Count -gt 0) { $verLine = ([string]$ver[0]).Trim() -replace '\p{Cc}', '?' }
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — JSON stdin 형식은 T045 · T054 · T056 · T057 블록의 되읽기 해시 일치로 CLI v2.1.0 에서 확인했다 · kv patch 꼴은 이 블록이 처음이다(VD-T075-11 — 되읽기가 잡는다)"
    # ---------- 0b) Vault 도달 — 토큰 없이 ----------
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
    # ---------- 1) env 선택 → 경로 4 ----------
    $envSel = [string](& $pickEnv)
    $other = 'prod'
    if (& $eq $envSel 'prod') { $other = 'dev' }
    $paths = @(
      [pscustomobject]@{ path = "kv/$envSel/authentik/identity-admin"; role = 'authentik'; keys = @('client_id', 'client_secret', 'jwks_url', 'issuer', 'api_token') }
      [pscustomobject]@{ path = "kv/$envSel/authentik/webhooks/identity-admin"; role = 'webhook'; keys = @('secret') }
      [pscustomobject]@{ path = "kv/$envSel/django/identity-admin"; role = 'django'; keys = @('secret_key') }
      [pscustomobject]@{ path = "kv/$envSel/sentry/identity-admin"; role = 'sentry'; keys = @('dsn') })
    foreach ($e in $paths) { $sumLog[$e.path] = '미실행(이 실행에서 여기까지 오지 못했다)' }
    Write-Host "OK   대상 env = $envSel — 쓸 수 있는 경로 4(아래 판정이 정한다)"
    # ---------- 2) root 토큰(PM) ----------
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
    # ---------- 3) 쓰기 보호 판정(읽기 전용) ----------
    $plan = @()
    $nSkip = 0
    $nStop = 0
    # 다른 env 의 webhook secret · secret_key(쌍 판정 — SHA-256 만 남긴다). prod 차례에는 dev 두 값이 먼저 있어야 한다(dev 먼저)
    $otherHash = @{}
    foreach ($q in @(@('webhook', "kv/$other/authentik/webhooks/identity-admin", 'secret'), @('django', "kv/$other/django/identity-admin", 'secret_key'))) {
      $s = & $state $q[1]
      $hv = ''
      if (& $eq $s.kind 'live') {
        $r = & $readData $q[1]
        if ($null -ne $r.dd) {
          $v = & $prop $r.dd $q[2]
          if (($v -is [string]) -and -not (& $eq $v $sentinel) -and ((($q[0] -ceq 'webhook') -and (& $wh43 $v)) -or (($q[0] -ceq 'django') -and ($v -cmatch '\A[A-Za-z0-9_-]{64}\z')))) { $hv = & $sha $v }
          $v = $null }
        $r = $null }
      $otherHash[$q[0]] = $hv
      if ((& $eq $envSel 'prod') -and $hv.Length -eq 0) {
        $nStop++
        Write-Host "STOP $($q[1]) — prod 차례인데 dev 의 $($q[2]) 값이 W-2 꼴로 있지 않다($($s.kind)) — dev 먼저: W-2 dev · O-3 dev 를 끝낸 뒤 prod 를 쓴다(쓰기 0)" } }
    foreach ($e in $paths) {
      $s = & $state $e.path
      $j = [pscustomobject]@{ kind = 'stop'; why = '' }
      if ((& $eq $s.kind 'absent') -and ((& $eq $e.role 'django') -or (& $eq $e.role 'sentry'))) { $j = [pscustomobject]@{ kind = 'plan'; why = 'absent → 생성 예정' } }
      elseif (& $eq $s.kind 'absent') { $j.why = 'absent — T044 sentinel 경로가 없다(O-2 출력과 대조 · 사람 판정)' }
      elseif (-not (& $eq $s.kind 'live')) { $j.why = "$($s.kind) — $($s.why)" }
      else {
        $r = & $readData $e.path
        if ($null -eq $r.dd) { $j.why = "판정 불가 — $($r.why)" }
        else {
          $kc = [string](& $keyCheck $r.dd $e.keys)
          if ($kc.Length -gt 0) { $j.why = "live-mismatch: $kc" }
          elseif (& $eq $e.role 'authentik') {
            $ju = & $prop $r.dd 'jwks_url'; $is = & $prop $r.dd 'issuer'
            if ((& $eq $ju $sentinel) -and (& $eq $is $sentinel)) {
              # 보존할 세 키의 쓰기 전 SHA-256(되읽기에서 그대로인지 본다 — 값 · 해시 미출력)
              $keepA = [ordered]@{}
              foreach ($n in @('client_id', 'client_secret', 'api_token')) { $keepA[$n] = & $sha (& $prop $r.dd $n) }
              $j = [pscustomobject]@{ kind = 'plan'; why = 'jwks_url · issuer = sentinel → 계약 값 patch 예정(나머지 3키 보존)' } }
            elseif ((& $eq $ju $jwksWant) -and (& $eq $is $issWant)) { $j = [pscustomobject]@{ kind = 'skip'; why = '키 5 · jwks_url · issuer = 계약 값(이미 썼다)' } }
            else { $j.why = 'live-mismatch: jwks_url · issuer 가 둘 다 sentinel 도 둘 다 계약 값도 아니다(사람 판정 · 덮어쓰지 않는다)' } }
          elseif (& $eq $e.role 'webhook') {
            $v = & $prop $r.dd 'secret'
            if (& $eq $v $sentinel) { $j = [pscustomobject]@{ kind = 'plan'; why = 'secret = sentinel → CSPRNG 43자로 덮어쓰기 예정' } }
            elseif ($v -cmatch '\A[A-Za-z0-9_-]{43}\z') {
              if (-not (& $wh43 $v)) { $j.why = 'live-mismatch: secret 의 서로 다른 글자가 16 미만이다(CSPRNG 값이 아니다 — 값 미출력 · 사람 판정)' }
              elseif ($otherHash['webhook'].Length -gt 0 -and (& $eq (& $sha $v) $otherHash['webhook'])) { $j.why = "secret 이 $other 의 것과 같다 — dev ≠ prod 이어야 한다(값 · 해시 미출력 · 사람 판정)" }
              else { $j = [pscustomobject]@{ kind = 'skip'; why = 'secret = 43자 base64url 실값(바꾸지 않는다 — 회전이 아니다)' } } }
            else { $j.why = 'live-mismatch: secret 이 sentinel 도 43자 base64url 도 아니다(줄바꿈 · 길이 · 문자 — 값 미출력)' }
            $v = $null }
          elseif (& $eq $e.role 'django') {
            $v = & $prop $r.dd 'secret_key'
            if (($v -cmatch '\A[A-Za-z0-9_-]{64}\z') -and (& $w009 $v)) {
              if ($otherHash['django'].Length -gt 0 -and (& $eq (& $sha $v) $otherHash['django'])) { $j.why = "secret_key 가 $other 의 것과 같다 — dev ≠ prod 이어야 한다(값 · 해시 미출력 · 사람 판정)" }
              else { $j = [pscustomobject]@{ kind = 'skip'; why = 'secret_key = 64자 base64url · W009 충족(이미 썼다)' } } }
            else { $j.why = 'live-mismatch: secret_key 가 이 블록의 꼴(64자 base64url · W009)이 아니다(값 미출력 · 사람 판정)' }
            $v = $null }
          else {
            if (& $eq (& $prop $r.dd 'dsn') '') { $j = [pscustomobject]@{ kind = 'skip'; why = 'dsn = 빈 값(이미 썼다)' } }
            else { $j.why = 'live-mismatch: dsn 이 빈 값이 아니다(Sentry 실값은 T100 — 사람 판정)' } } }
        $r = $null }
      if (& $eq $j.kind 'plan') {
        $row = [pscustomobject]@{ path = $e.path; role = $e.role; cv = $s.cv; keys = @($e.keys); want = [ordered]@{}; keep = [ordered]@{}; verb = '생성'; why = $j.why }
        if (& $eq $e.role 'authentik') { $row.want = [ordered]@{ jwks_url = $jwksWant; issuer = $issWant }; $row.keep = $keepA; $row.verb = 'patch' }
        elseif (& $eq $e.role 'webhook') { $row.verb = '덮어씀' }
        elseif (& $eq $e.role 'sentry') { $row.want = [ordered]@{ dsn = '' } }
        $plan += $row
        $sumLog[$e.path] = "쓰기 예정(판정 — $($j.why) · 쓰기 확인 전)"
        Write-Host "PLAN $($e.path) — $($j.why) · 지금 v$($s.cv)" }
      elseif (& $eq $j.kind 'skip') {
        $nSkip++
        $sumLog[$e.path] = "건너뜀($($j.why) — 덮어쓰지 않았다)"
        Write-Host "SKIP $($e.path) — $($j.why) · v$($s.cv) · 값 미출력 · 덮어쓰지 않는다" }
      else {
        $nStop++
        $sumLog[$e.path] = "중단($($j.why))"
        Write-Host "STOP $($e.path) — $($j.why)" } }
    $j = $null; $keepA = $null
    Write-Host "판정 결과: 쓰기 예정 $($plan.Count) · 건너뜀 $nSkip · 중단 $nStop"
    if ($nStop -gt 0) {
      foreach ($p in $plan) { $sumLog[$p.path] = '미실행(판정 단계에서 중단 — 쓰지 않았다)' }
      throw "판정 단계에서 중단 — STOP ${nStop}건(위 STOP 줄 · 런북 bootstrap.md §4 T075 실패 표) · kv 쓰기 0건" }
    if ($plan.Count -eq 0) {
      Write-Host "INFO 쓸 경로 없음 — $envSel 4경로 모두 이미 쓴 상태(재실행은 건너뛴다 · 회전이 아니다)"
      return }
    # ---------- 4) 쓰기 확인(정지점 — 경로 목록만 · 값은 아직 만들지도 않았다) ----------
    Write-Host ''
    Write-Host "쓸 경로 $($plan.Count)개(이 순서로 쓴다 — 값은 이 블록이 만든다 · 화면에 나오지 않는다):"
    foreach ($p in $plan) { Write-Host "  - $($p.path)  ($($p.verb) · -cas=$($p.cv) · $($p.why))" }
    try { & $stop "쓰기 확인: 위 $($plan.Count)개 경로를 -cas=<지금 버전>으로 쓴다(그 사이 바뀌었으면 거부 — 덮어쓰기 없음)" 'seed' }
    catch {
      foreach ($p in $plan) { $sumLog[$p.path] = '미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)' }
      throw }
    # ---------- 5) 값 생성(put 직전) · 쌍 판정(생성 몫) → 쓰기 + 되읽기 ----------
    foreach ($p in $plan) { $sumLog[$p.path] = '미실행(앞 경로에서 중단 — 쓰지 않았다)' }
    foreach ($p in $plan) {
      if (& $eq $p.role 'webhook') {
        $v = & $newB64 32
        if (-not (& $wh43 $v)) { throw "생성한 secret 이 43자 base64url · 서로 다른 글자 16 이상이 아니다: $($p.path) — 중단(쓰지 않았다 · 생성기 이상 신호 — 컨트롤러에게 보고)" }
        if ($otherHash['webhook'].Length -gt 0 -and (& $eq (& $sha $v) $otherHash['webhook'])) {
          $sumLog[$p.path] = '중단(생성한 secret 이 다른 env 의 것과 같다 — put 전 · 쓰지 않았다)'
          Write-Host "STOP $($p.path) — 생성한 secret 이 $other 의 것과 같다(값 · 해시 미출력) — 쓰지 않았다"
          throw "생성 값 중복: $($p.path) — 중단(쓰지 않았다 · 뒤 경로 미실행)" }
        $p.want = [ordered]@{ secret = $v }
        $v = $null }
      if (& $eq $p.role 'django') {
        $v = & $newB64 48
        if ($v -cnotmatch '\A[A-Za-z0-9_-]{64}\z' -or -not (& $w009 $v)) { throw "생성한 secret_key 가 64자 base64url · W009 가 아니다: $($p.path) — 중단(쓰지 않았다)" }
        if ($otherHash['django'].Length -gt 0 -and (& $eq (& $sha $v) $otherHash['django'])) {
          $sumLog[$p.path] = '중단(생성한 secret_key 가 다른 env 의 것과 같다 — put 전 · 쓰지 않았다)'
          Write-Host "STOP $($p.path) — 생성한 secret_key 가 $other 의 것과 같다(값 · 해시 미출력) — 쓰지 않았다"
          throw "생성 값 중복: $($p.path) — 중단(쓰지 않았다 · 뒤 경로 미실행)" }
        $p.want = [ordered]@{ secret_key = $v }
        $v = $null }
      try { & $write $p }
      finally { if (-not (& $eq $p.role 'authentik')) { $p.want = $null } } } }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, s, r, v, j, keepA, plan, otherHash, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    Write-Host ''
    Write-Host "--- T075 W-2 kv 쓰기 결과 요약(env=$(if ($envSel) { $envSel } else { '선택 전' }) · 값 없음 — 런북 bootstrap.md §4 T075 기록 칸에 그대로 기록) ---"
    foreach ($k in $sumLog.Keys) { Write-Host ('{0,-46} {1}' -f $k, $sumLog[$k]) }
    $vals = @($sumLog.Values | ForEach-Object { [string]$_ })
    $nNew = @($vals | Where-Object { $_.StartsWith('생성 v', [StringComparison]::Ordinal) -or $_.StartsWith('patch v', [StringComparison]::Ordinal) -or $_.StartsWith('덮어씀 v', [StringComparison]::Ordinal) }).Count
    $nLost = @($vals | Where-Object { $_.StartsWith('기록됨(응답 유실', [StringComparison]::Ordinal) }).Count
    $nRec = @($vals | Where-Object { $_.StartsWith('기록됨', [StringComparison]::Ordinal) }).Count - $nLost
    $nUnk = @($vals | Where-Object { $_.StartsWith('결과 미확인', [StringComparison]::Ordinal) }).Count
    $nSk = @($vals | Where-Object { $_.StartsWith('건너뜀', [StringComparison]::Ordinal) }).Count
    $nSt = @($vals | Where-Object { $_.StartsWith('중단', [StringComparison]::Ordinal) }).Count
    $nNo = $vals.Count - $nNew - $nLost - $nRec - $nUnk - $nSk - $nSt
    Write-Host "이 실행이 kv 에 쓴 경로: $($nNew + $nLost + $nRec)건(검증 완료 $nNew · 응답 유실 뒤 재판정으로 검증 완료 $nLost · 기록 후 검증 실패 $nRec) · 결과 미확인 $nUnk · 건너뜀 $nSk · 중단 $nSt · 미실행 $nNo"
    if ($nUnk -gt 0) { Write-Host '결과 미확인 = 쓰기 도중 중단 또는 비 0 뒤 재판정 불가 — kv 에 새 버전이 있을 수 있다. 지우지 말고 O-2 로 본 뒤 재실행한다(모양이 맞으면 건너뛴다)' }
    if ($vals.Count -gt 0 -and $nNew + $nLost + $nSk -eq $vals.Count) { Write-Host "판정: $envSel 4경로 준비 완료(쓰기 또는 이미 씀) — 다음 = O-3 $envSel(게이트 · gate=PASS n/n 한 줄을 컨트롤러에게)" }
    else { Write-Host '판정: 미완 — 위 STOP 줄과 런북 bootstrap.md §4 T075 실패 표를 본다(재실행은 안전하다: 이미 쓴 경로는 건너뛰고 -cas 는 덮어쓰지 않는다)' }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
