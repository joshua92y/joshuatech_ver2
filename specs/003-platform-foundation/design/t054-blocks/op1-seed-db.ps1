& {
  # ===== T054 OP1-DB 시드 블록 — DB 자격 kv 6경로(랜덤) · 통째로 붙여 넣어도 안전(창 D) =====
  # 목적: gitops T054 PR(platform/cnpg-databases — ExternalSecret 6 → DatabaseRole 6 의 passwordSecret) 머지 "전에" Vault kv 6경로에
  #       DB role 자격(username · password · url)을 경로마다 따로 랜덤 생성해 넣는다 → ExternalSecret 이 처음부터 SecretSynced 가 된다.
  # 경로(6) — 키 = username · password · url(data-model §8) · username = PG role 이름:
  #   kv/prod/db/identity_admin/owner      identity_admin_owner       db identity_admin      (store vault-data)
  #   kv/prod/db/identity_admin/app        identity_admin_app         db identity_admin      (store vault-data)
  #   kv/dev/db/dev_identity_admin/owner   dev_identity_admin_owner   db dev_identity_admin  (store vault-data)
  #   kv/dev/db/dev_identity_admin/app     dev_identity_admin_app     db dev_identity_admin  (store vault-data)
  #   kv/platform/db/authentik/owner       authentik_owner            db authentik           (store vault-platform)
  #   kv/platform/db/openfga/owner         openfga_owner              db openfga             (store vault-platform)
  # password = RandomNumberGenerator 32바이트 → base64url(패딩 없음 · 43자 · A–Z a–z 0–9 - _) — URL·libpq·셸 어디서도 인코딩이 필요 없다
  # url      = postgresql://<username>:<password>@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt
  # 사전(블록 밖 — 런북 docs/runbooks/bootstrap.md §4 T054 소절 · docs/runbooks/vault-unseal.md §0):
  #   ① 이 창(창 D)에서 vault-unseal.md §0 창 시작 체크리스트 — HistorySaveStyle SaveNothing · 전사 없음 · 클립보드 기록 0
  #      (설정 > 시스템 > 클립보드 > 클립보드 기록 끄기 — Win+V 로 확인. 켜져 있으면 아래 첫 검사에서 멈춘다)
  #      PowerShell 모듈 로깅 정책(PowerShellCore 키 · 그 키의 UseWindowsPowerShellPolicySetting 값이 1 이면 Windows PowerShell 키도)이 켜져 있어도 첫 검사에서 멈춘다
  #   ② 창 C: 관리자 kubeconfig 로 kubectl -n vault port-forward svc/vault 18200:8200 (이 블록 자신은 kubectl 을 쓰지 않는다)
  #   ③ 이 창에 VAULT_* 환경 변수 없음(VAULT_ADDR=http://127.0.0.1:18200 만 허용) · ~/.vault-token 없음 — 있으면 첫 검사에서 멈춘다
  #   ④ 비밀번호 관리자(PM)에서 root 토큰 항목을 열어 둔다(T044 D4 — 시드는 root 로 · revoke 보류)
  #   ⑤ 붙여넣기로 실행할 때만: pwsh -NoProfile 로 새로 연 창에서 한다(프로필이 vault · Read-Host · ConvertFrom-Json 을 함수 · 별칭으로 가리거나
  #      Set-PSDebug · 중단점을 켜 두는 경로가 없는 창) + if (-not (Get-Module PSReadLine)) { throw 'PSReadLine 미로드 — 이 창에서는 블록을 붙여 넣지 않는다' } 를 따로 1회
  # 실행(둘 중 하나): pwsh -NoProfile -File '<이 파일의 절대 경로>'(권장 — 새 프로세스 · 프로필 없음 · env·변수가 프로세스와 함께 사라진다)
  #                  또는 이 파일 전문을 ⑤의 창에 붙여 넣는다(전체가 & { … } 한 문이다 — 중간 줄이 따로 실행되지 않는다)
  # 정지점(입력 순서): ① root 토큰 — 보안 입력(빈 입력 = 중단). 붙이기 전에 화면의 INFO vault CLI 줄의 종류가 Application 인지 본다 —
  #                    아니면(함수 · 별칭이 vault 를 가리고 있다) 붙이지 말고 Ctrl+C
  #                  ② seed — 쓰기 확인(입력은 가려진다 · 대소문자 구분 · 쓸 경로가 0 이면 나오지 않는다)
  # 원칙: (a) 사람 동작마다 정지점 — 입력 버퍼를 비운 뒤 단어를 요구한다(빈 Enter · 붙여넣기 잔여 입력으로 통과하지 않는다)
  #       (b) 판정(읽기 전용)과 쓰기를 단계로 나눈다 — 판정에서 STOP 이 하나라도 나오면 kv 쓰기 0 으로 끝난다
  #       (c) 쓰기는 vault kv put "-cas=0" + JSON stdin 뿐 — 값이 argv 에 나오지 않고, 이미 있는 경로는 덮어쓰지 않는다(live 판정 + CAS 이중)
  #       (d) 되읽기는 JSON 으로만(-field 캡처는 끝 개행을 잃는다 — T045) + SHA-256 Ordinal 비교 + current_version=1 — 실패하면 다음 경로로 가지 않는다
  #       (e) 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 나오지 않는다 — 출력은 Write-Host/Write-Warning 뿐(성공 스트림 0)
  #       (f) 생성 값의 유일한 사본은 kv 다 — 메모리 값은 되읽기 대조 뒤 버린다. put 이 비 0 으로 끝나도 "쓰지 않았다"고 단정하지 않는다: 응답 유실 뒤 CLI 자동 재시도
  #           (VAULT_MAX_RETRIES 기본 2)가 자기 기록과 CAS 충돌하면 서버에는 이 실행의 값이 v1 로 있는데 종료 코드 · 문구는 진짜 충돌과 같다 → 값을 출력하지 않고 다시 판정한다
  #           (absent = 쓰지 않았다 · live v1 + 되읽기 해시 일치 = 기록됨(응답 유실 — 이 실행의 값) · 다르면 CAS 충돌로 STOP(덮어쓰지 않았다) · 재판정 불가 = 결과 미확인)
  #       (g) 정리는 조건부 — 블록이 만든 VAULT_TOKEN 만 지우고, 시작 전에 있던 VAULT_* 는 건드리지 않은 채 중단한다
  #       (h) finally 가 성공 · 실패 · Ctrl+C 어느 쪽이든 env(VAULT_TOKEN 부터) · 비밀 변수 · 클립보드 · $Error(이 실행분)를 정리하고
  #           경로별 요약(put 도중 중단 · put 비 0 뒤 재판정 불가는 "결과 미확인") + 창 종료 체크리스트를 낸다. 세션의 $WhatIfPreference · $ConfirmPreference ·
  #           $PSDefaultParameterValues(-WhatIf) 가 이 정리를 조용히 건너뛰게 하지 못하도록 블록 범위에서 셋을 고정한다
  # 재실행: live-ok 경로는 건너뛴다 — 값을 다시 만들지 않는다(회전이 아니다; 회전은 secret-rotation.md · T084 예정).
  #         되읽기 일시 실패 · put 도중 중단 · put 비 0 뒤 재판정 불가(결과 미확인)로 멈췄다면 재실행이 복구다 — 그 경로를 live 로 판정해 모양이 맞으면 SKIP 한다.
  # 실행 뒤 확인: gitops T054 PR 머지 → agent-view 로 ns data 의 ExternalSecret 6장(pg-main-*-owner · pg-main-*-app)이 SecretSynced = kv 6경로 실재 증명
  #   (머지가 먼저 됐다면 런북 §4 T054 소절 「늦은 시드」 — ES 6장 force-sync 어노테이션 · 필요하면 수동 Sync)
  # 모의 하네스: pwsh -NoProfile -File specs/003-platform-foundation/design/t054-blocks/harness.ps1 → PASS n / n(이 블록은 그 하네스를 통과한 판만 운영자에게 준다)
  Set-PSDebug -Off
  # ↑ 첫 문장: 창에 Set-PSDebug -Trace 가 켜져 있으면 뒤의 모든 대입(root 토큰 · 비밀번호 · url)이 값과 함께 화면에 찍힌다 — 다른 어떤 문장보다 먼저 끈다.
  #   세션 전체 설정이다(붙여넣기 실행이면 그 창의 전역 strict 모드도 함께 꺼진다). 프로필의 함수 · 별칭 · 중단점은 막지 못한다 — 머리 주석 ⑤의 새 창이 막는다
  $ErrorActionPreference = 'Stop'
  # 경고(클립보드 비우기 실패 등)가 세션 설정으로 숨거나(SilentlyContinue) 예외가 되어 finally 를 끊지(Stop) 않게 이 블록 안에서만 고정한다
  $WarningPreference = 'Continue'
  $PSNativeCommandUseErrorActionPreference = $false
  # 붙여넣기 창의 세션 상태($WhatIfPreference = $true · $ConfirmPreference Low/Medium · $PSDefaultParameterValues 의 -WhatIf)는 finally 의 Remove-Item Env: 와 Set-Clipboard 를
  # 예외 · 경고 없이 건너뛰게 한다(실측 — root 토큰이 env · 클립보드에 남는다). 이 블록 범위에서만 셋을 고정한다(-File 실행은 새 프로세스라 원래 면역이다)
  $WhatIfPreference = $false
  $ConfirmPreference = 'High'
  $PSDefaultParameterValues = @{}
  Set-StrictMode -Version 3.0
  $vaultAddr = 'http://127.0.0.1:18200'
  $clipWarn = '클립보드를 비우지 못했다 — root 토큰이 클립보드에 남아 있을 수 있다. PM 의 클립보드 지우기 또는 아무 텍스트 복사로 직접 비운다'
  $pgHostPort = 'pg-main-rw.data.svc:5432'
  $pgQuery = '?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt'
  $keys = @('username', 'password', 'url')
  $paths = @(
    [pscustomobject]@{ path = 'kv/prod/db/identity_admin/owner'; user = 'identity_admin_owner'; db = 'identity_admin' }
    [pscustomobject]@{ path = 'kv/prod/db/identity_admin/app'; user = 'identity_admin_app'; db = 'identity_admin' }
    [pscustomobject]@{ path = 'kv/dev/db/dev_identity_admin/owner'; user = 'dev_identity_admin_owner'; db = 'dev_identity_admin' }
    [pscustomobject]@{ path = 'kv/dev/db/dev_identity_admin/app'; user = 'dev_identity_admin_app'; db = 'dev_identity_admin' }
    [pscustomobject]@{ path = 'kv/platform/db/authentik/owner'; user = 'authentik_owner'; db = 'authentik' }
    [pscustomobject]@{ path = 'kv/platform/db/openfga/owner'; user = 'openfga_owner'; db = 'openfga' })
  # 경로별 요약은 시작할 때 전부 채워 둔다 — 중간에 throw 해도 "도달하지 못함"이 표에 남는다(T045 규칙 9)
  $seedLog = [ordered]@{}
  foreach ($e in $paths) { $seedLog[$e.path] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  $tokenOwned = $false
  $addrOwned = $false
  $errTop = $null
  if ($Error.Count -gt 0) { $errTop = $Error[0] }
  try {
    # ---------- 헬퍼(값을 출력하지 않는다 — 돌려주는 것은 판정 · 불리언 · 해시뿐이고 해시도 출력하지 않는다) ----------
    $eq = { param($a, $b) [string]::Equals([string]$a, [string]$b, [StringComparison]::Ordinal) }
    $has = { param($list, $x) foreach ($i in @($list)) { if (& $eq $i $x) { return $true } }; $false }
    $sha = { param($s) [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes([string]$s))) }
    # 정지점: 입력 버퍼를 비우고 단어를 요구한다. 빈 Enter · 버퍼 잔여 · 앞뒤 공백 붙은 단어 · 대소문자가 다른 단어로는 통과하지 않는다(Ordinal).
    # 입력은 가려진다(-MaskInput) — 불안해서 PM 의 비밀을 이 프롬프트에 다시 붙여 넣어도 화면 · 스크롤백에 남지 않는다(그 입력은 중단으로 끝난다).
    $stop = { param($msg, $word)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ans = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)" -MaskInput
      if (-not (& $eq $ans $word)) { throw "정지점에서 중단: $msg — kv 쓰기 0건" } }
    # 비밀 입력: 버퍼를 비우고 보안 입력으로 받은 직후 클립보드를 비운다(뒤의 평문 정지점에서 우클릭 붙여넣기 사고를 막는다).
    # 비우기가 실패하면(다른 프로세스가 클립보드를 잡고 있다 — rdpclip · 클립보드 관리자) 조용히 넘기지 않고 경고한다(값 없음 · 시드는 계속한다).
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt(아무것도 쓰지 않았다)" }
      try { ($ss | ConvertFrom-SecureString -AsPlainText) } finally { $ss.Dispose() } }
    # 오류 출력 첫 줄(비밀이 오가지 않는 status · metadata 조회에만 쓴다): "* …" 상세 줄을 우선, 160자에서 자른다.
    $firstErr = { param($lines)
      $c = @(@($lines) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      $star = @($c | Where-Object { $_.StartsWith('* ', [StringComparison]::Ordinal) })
      $pick = '(오류 출력 없음)'
      if ($star.Count -gt 0) { $pick = $star[0] } elseif ($c.Count -gt 0) { $pick = $c[0] }
      if ($pick.Length -gt 160) { $pick = $pick.Substring(0, 160) + '…' }
      $pick }
    # JSON 해석: 실패는 $null(예외 문구에 원문을 싣지 않는다). -DateKind String — 날짜꼴 값을 DateTime 으로 바꾸지 않는다.
    $parseJson = { param($lines)
      $t = (@($lines) | ForEach-Object { [string]$_ }) -join "`n"
      if ([string]::IsNullOrWhiteSpace($t)) { return $null }
      try { $t | ConvertFrom-Json -DateKind String } catch { $null } }
    # 속성 읽기(없으면 $null — StrictMode 에서도 예외 없이)
    $prop = { param($o, $n)
      if ($null -eq $o) { return $null }
      $p = $o.PSObject.Properties[$n]
      if ($null -eq $p) { return $null }
      $p.Value }
    # 경로 상태(값을 읽지 않는다): absent(No value found) | live | dead(현재 버전 삭제 · 파기 · 버전 없음) | error(그 밖 — 판정 불가)
    # 비 0 종료라도 "No value found" 가 아니면 absent 로 보지 않는다 — 일시 오류를 "없음"으로 오판해 쓰러 가지 않는다.
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
    # live 경로 판정(값을 읽지만 출력하지 않는다): 키 집합 = {username,password,url} · 전부 문자열 · username = role ·
    # password 길이 ≥ 32 + URL 비예약 문자만 · url = postgresql://<username>:<password>@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt
    $judge = { param($e)
      $o = @(vault kv get "-format=json" $e.path 2>$null)
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or $o.Count -eq 0) { return [pscustomobject]@{ kind = 'error'; why = "kv get exit=$rc(값을 읽지 못했다)" } }
      # 응답 해석 실패(잘린 JSON 등 일시 상태)는 판정 불가(조치 = 재실행)다 — live-mismatch(런북 조치 = 되돌릴 수 없는 「정리 판단」)로 보내지 않는다
      $jr = & $parseJson $o
      $o = $null
      if ($null -eq $jr) { return [pscustomobject]@{ kind = 'error'; why = 'kv get 응답을 해석하지 못했다(원문 미출력)' } }
      $dd = & $prop (& $prop $jr 'data') 'data'
      $jr = $null
      if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) { return [pscustomobject]@{ kind = 'mismatch'; why = '현재 버전에 데이터가 없다(data.data 가 없거나 객체가 아니다)' } }
      $names = @($dd.PSObject.Properties | ForEach-Object { $_.Name })
      $missing = @($keys | Where-Object { -not (& $has $names $_) })
      $extra = @($names | Where-Object { -not (& $has $keys $_) }).Count
      if ($missing.Count -gt 0 -or $extra -gt 0) {
        $ms = '없음'
        if ($missing.Count -gt 0) { $ms = $missing -join '·' }
        return [pscustomobject]@{ kind = 'mismatch'; why = "키 집합 불일치(누락: $ms · 여분 ${extra}개)" } }
      foreach ($k in $keys) { if ((& $prop $dd $k) -isnot [string]) { return [pscustomobject]@{ kind = 'mismatch'; why = "$k 값이 문자열이 아니다" } } }
      $u = [string](& $prop $dd 'username')
      $p = [string](& $prop $dd 'password')
      $url = [string](& $prop $dd 'url')
      if (-not (& $eq $u $e.user)) { return [pscustomobject]@{ kind = 'mismatch'; why = "username 이 기대 role 이름($($e.user))과 다르다" } }
      if ($p.Length -lt 32) { return [pscustomobject]@{ kind = 'mismatch'; why = 'password 길이가 32 미만이다' } }
      if ($p -cnotmatch '\A[A-Za-z0-9._~-]+\z') { return [pscustomobject]@{ kind = 'mismatch'; why = 'password 에 URL 에 그대로 넣을 수 없는 문자가 있다(허용: A–Z a–z 0–9 - . _ ~)' } }
      $pre = 'postgresql://' + $e.user + ':'
      $suf = '@' + $pgHostPort + '/' + $e.db + $pgQuery
      if (-not $url.StartsWith($pre, [StringComparison]::Ordinal)) { return [pscustomobject]@{ kind = 'mismatch'; why = 'url 접두가 postgresql://<username>: 과 다르다' } }
      if (-not $url.EndsWith($suf, [StringComparison]::Ordinal)) { return [pscustomobject]@{ kind = 'mismatch'; why = "url 접미가 @$pgHostPort/$($e.db)$pgQuery 와 다르다" } }
      if ($url.Length -lt $pre.Length + $suf.Length) { return [pscustomobject]@{ kind = 'mismatch'; why = 'url 구성이 기대와 다르다(접두·접미가 겹친다)' } }
      if (-not (& $eq $url.Substring($pre.Length, $url.Length - $pre.Length - $suf.Length) $p)) { return [pscustomobject]@{ kind = 'mismatch'; why = 'url 의 비밀번호 부분이 password 값과 다르다' } }
      [pscustomobject]@{ kind = 'ok'; why = '' } }
    # 경로 1개 생성 + 되읽기. 실패하면 STOP 줄을 내고 throw — 다음 경로로 가지 않는다. 모든 분기가 $seedLog 를 확정 문구로 덮는다.
    # put 비 0 은 재판정한다(원칙 f): absent → 쓰지 않았다 / live v1 → 아래 되읽기 해시 대조가 "이 실행의 값(응답 유실)" 과 "다른 기록자의 값(CAS 충돌)" 을 가른다 / 그 밖 → 결과 미확인
    $write = { param($e)
      $seedLog[$e.path] = '중단(값 생성 중 — put 전이라 쓰지 않았다 · 아래 오류 참조)'
      $pw = $null; $url = $null; $want = $null; $json = $null; $o = $null; $dd = $null
      $lost = 0
      try {
        $bytes = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
        try { $pw = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') } finally { [Array]::Clear($bytes, 0, $bytes.Length) }
        if ($pw -cnotmatch '\A[A-Za-z0-9_-]{43}\z') { throw "생성한 비밀번호가 base64url 43자가 아니다: $($e.path) — 중단(쓰지 않았다)" }
        $url = 'postgresql://' + $e.user + ':' + $pw + '@' + $pgHostPort + '/' + $e.db + $pgQuery
        $want = [ordered]@{ username = $e.user; password = $pw; url = $url }
        $json = $want | ConvertTo-Json -Compress
        # put 이 도는 동안 중단(Ctrl+C)되면 서버는 이미 커밋했을 수 있다 — 요약이 "쓰지 않았다"로 남지 않게 put 직전에 바꿔 둔다
        $seedLog[$e.path] = '결과 미확인(put 진행 중 중단 — kv 에 v1 이 있을 수 있다 · 재실행이 판정한다)'
        $null = $json | vault kv put "-cas=0" $e.path - 2>$null
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        $json = $null
        if ($rc -ne 0) {
          # 종료 코드 · 문구로는 CAS 거부 · 권한 · 연결 · "응답 유실 뒤 CLI 자동 재시도의 자기 CAS 충돌"(서버에는 이 실행의 값이 v1)을 가를 수 없다 — 값 없이 다시 판정한다
          $seedLog[$e.path] = "결과 미확인(put exit=$rc — 재판정 전 중단 · kv 에 이 실행의 v1 이 있을 수 있다 · 재실행이 판정한다)"
          $m = & $state $e.path
          if (& $eq $m.kind 'absent') {
            $seedLog[$e.path] = "중단(put 거부 exit=$rc — 재판정 absent · 쓰지 않았다)"
            Write-Host "STOP $($e.path) — put 거부(exit=$rc) · 재판정 absent: kv 에 이 경로가 없다 = 쓰지 않았다(권한 · 연결 · CLI 오류 — 같은 STOP 이 반복되면 토큰 정책 · 창 C 확인). 뒤 경로는 실행하지 않는다"
            throw "put 거부: $($e.path) — 중단(쓰기 0 · 뒤 경로 미실행)" }
          if (-not (& $eq $m.kind 'live') -or $m.cv -ne 1) {
            $seedLog[$e.path] = "결과 미확인(put exit=$rc — 재판정 $($m.kind) · current_version=$($m.cv) · 재실행이 판정한다)"
            Write-Host "STOP $($e.path) — put 거부(exit=$rc) · 재판정 $($m.kind)(current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why })): 이 실행의 값이 기록됐는지 확인하지 못했다 — 지우지 말고 재실행한다(판정이 live 로 보고 모양이 맞으면 SKIP). 뒤 경로는 실행하지 않는다"
            throw "put 거부: $($e.path) — 결과 미확인(뒤 경로 미실행)" }
          $lost = $rc
          $seedLog[$e.path] = "결과 미확인(put exit=$rc — 재판정 live v1 · 되읽기 대조 전 중단 · 재실행이 판정한다)" }
        else { $seedLog[$e.path] = '기록됨 — 되읽기 검증 전(아래 오류 확인 · 값은 kv 에 있다)' }
        $how = '생성'
        if ($lost) { $how = "기록됨(응답 유실 — 이 실행의 값 · put exit=$lost 뒤 재판정)" }
        $o = @(vault kv get "-format=json" $e.path 2>$null)
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($rc -ne 0 -or $o.Count -eq 0) {
          if ($lost) { $seedLog[$e.path] = "결과 미확인(put exit=$lost — 재판정 live v1 · 되읽기 실패 exit=$rc · 재실행이 판정한다)" }
          else { $seedLog[$e.path] = "기록됨 — 되읽기 실패(exit=$rc · 재실행하면 이 경로를 live 로 판정한다)" }
          Write-Host "STOP $($e.path) — 되읽기 실패(exit=$rc): v1 이 kv 에 있다$(if ($lost) { "(이 실행의 값인지는 미확인 — put exit=$lost 뒤 재판정)" } else { '(put 은 성공했다)' }). 뒤 경로로 가지 않는다 — 재실행하면 이 경로를 live 로 판정한다"
          throw "되읽기 실패: $($e.path) — 중단(뒤 경로 미실행)" }
        $dd = & $prop (& $prop (& $parseJson $o) 'data') 'data'
        $o = $null
        if ($null -eq $dd -or $dd -isnot [System.Management.Automation.PSCustomObject]) {
          if ($lost) { $seedLog[$e.path] = "결과 미확인(put exit=$lost — 재판정 live v1 · 되읽기 응답 해석 실패 · 재실행이 판정한다)" }
          else { $seedLog[$e.path] = '기록됨 — 되읽기 응답 해석 실패(재실행하면 이 경로를 live 로 판정한다)' }
          Write-Host "STOP $($e.path) — 되읽기 응답을 해석하지 못했다(JSON · data.data 없음 — 원문은 출력하지 않는다). 뒤 경로로 가지 않는다"
          throw "되읽기 실패: $($e.path) — 중단(뒤 경로 미실행)" }
        $names = @($dd.PSObject.Properties | ForEach-Object { $_.Name })
        $missing = @($keys | Where-Object { -not (& $has $names $_) })
        $extra = @($names | Where-Object { -not (& $has $keys $_) }).Count
        if ($missing.Count -gt 0 -or $extra -gt 0) {
          $ms = '없음'
          if ($missing.Count -gt 0) { $ms = $missing -join '·' }
          if ($lost) {
            $seedLog[$e.path] = "중단(put 거부 exit=$lost — 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)"
            Write-Host "STOP $($e.path) — put 거부(exit=$lost) · CAS 충돌(다른 값): kv 의 v1 은 다른 기록자의 값이다(키 집합 불일치 — 누락: $ms · 여분 ${extra}개) — 덮어쓰지 않았다. 뒤 경로는 실행하지 않는다"
            throw "put 거부: $($e.path) — CAS 충돌(덮어쓰기 0 · 뒤 경로 미실행)" }
          $seedLog[$e.path] = "기록됨 — 되읽기 키 집합 불일치(누락 $($missing.Count) · 여분 $extra) · 수동 확인"
          Write-Host "STOP $($e.path) — 되읽기 키 집합 불일치(누락: $ms · 여분 ${extra}개). 뒤 경로로 가지 않는다"
          throw "되읽기 불일치: $($e.path) — 중단(뒤 경로 미실행)" }
        $bad = @($keys | Where-Object { $v = & $prop $dd $_; ($v -isnot [string]) -or -not (& $eq (& $sha $v) (& $sha $want[$_])) })
        if ($bad.Count -gt 0) {
          if ($lost) {
            $seedLog[$e.path] = "중단(put 거부 exit=$lost — 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)"
            Write-Host "STOP $($e.path) — put 거부(exit=$lost) · CAS 충돌(다른 값): kv 의 v1 은 다른 기록자의 값이다(해시 불일치: $($bad -join '·') — 값 · 해시는 출력하지 않는다) — 덮어쓰지 않았다. 뒤 경로는 실행하지 않는다"
            throw "put 거부: $($e.path) — CAS 충돌(덮어쓰기 0 · 뒤 경로 미실행)" }
          $seedLog[$e.path] = "기록됨 — 되읽기 해시 불일치($($bad -join '·')) · 수동 확인"
          Write-Host "STOP $($e.path) — 되읽기 해시 불일치($($bad -join '·')): kv 의 값이 이 블록이 만든 값과 다르다(값 · 해시는 출력하지 않는다). 뒤 경로로 가지 않는다"
          throw "되읽기 해시 불일치: $($e.path) — 중단(뒤 경로 미실행)" }
        $m = & $state $e.path
        if (-not (& $eq $m.kind 'live') -or $m.cv -ne 1) {
          $seedLog[$e.path] = "기록됨 — 메타데이터 확인 실패($($m.kind) · current_version=$($m.cv))"
          Write-Host "STOP $($e.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다($($m.kind) · current_version=$($m.cv)$(if ($m.why) { ' · ' + $m.why })). 뒤 경로로 가지 않는다"
          throw "메타데이터 확인 실패: $($e.path) — 중단(뒤 경로 미실행)" }
        if ($lost) { $seedLog[$e.path] = "$how · 되읽기 해시 일치(username·password·url)" }
        else { $seedLog[$e.path] = '생성 v1 · 되읽기 해시 일치(username·password·url)' }
        Write-Host "OK   $($e.path) v1 — $how · 되읽기 해시 일치(username·password·url)" }
      finally { $pw = $null; $url = $null; $want = $null; $json = $null; $o = $null; $dd = $null } }
    # ---------- 0) 창 전제(비밀을 묻기 전에 전부 확인한다 — 여기서 멈추면 아무것도 묻지 않았다) ----------
    if ($PSVersionTable.PSVersion.Major -lt 7 -or ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
      throw 'PowerShell 7.5 이상(pwsh)이 필요하다 — powershell.exe(5.1)에서는 실행하지 않는다(아무것도 묻지 않았다)' }
    $ch = & $prop (Get-ItemProperty 'HKCU:\Software\Microsoft\Clipboard' -ErrorAction SilentlyContinue) 'EnableClipboardHistory'
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시(아무것도 묻지 않았다)' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시(아무것도 묻지 않았다)' }
    # PowerShell 모듈 로깅 정책: 켜져 있으면 ConvertFrom-Json 의 InputObject(kv get 응답 · token lookup 응답 원문 = 비밀번호 · url · root 토큰)가
    # 이벤트 4103(ParameterBinding)에 남는다. PowerShellCore 키를 보고, 그 키의 UseWindowsPowerShellPolicySetting 값이 1 이면 Windows PowerShell 키도 본다(HKLM · HKCU — 하나라도 켜져 있으면 중단).
    $mlKeys = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging')
    $mlWin = $false
    foreach ($mk in $mlKeys) { if ((& $prop (Get-ItemProperty $mk -ErrorAction SilentlyContinue) 'UseWindowsPowerShellPolicySetting') -eq 1) { $mlWin = $true } }
    if ($mlWin) { $mlKeys += @('HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging') }
    $mlOn = @($mlKeys | Where-Object { (& $prop (Get-ItemProperty $_ -ErrorAction SilentlyContinue) 'EnableModuleLogging') -eq 1 })
    if ($mlOn.Count -gt 0) { throw "PowerShell 모듈 로깅 정책이 켜져 있다($($mlOn -join ', ')) — 켜진 채로는 kv · 토큰 조회 응답 원문이 이벤트 로그(4103)에 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 묻지 않았다)" }
    if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인을 확인하고 지운 뒤 다시(아무것도 묻지 않았다)' }
    $pre = @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })
    $bad = @($pre | Where-Object { -not ([string]::Equals($_.Name, 'VAULT_ADDR', [StringComparison]::OrdinalIgnoreCase) -and (& $eq $_.Value $vaultAddr)) } | ForEach-Object { $_.Name })
    if ($bad.Count -gt 0) { throw "이 창에 VAULT_* 환경 변수가 이미 있다: $($bad -join ', ') — 블록은 건드리지 않았다. 확인 뒤 Remove-Item Env:<이름> 하고 다시(VAULT_ADDR=$vaultAddr 만 허용 · 아무것도 묻지 않았다)" }
    $vcs = @(Get-Command vault -ErrorAction SilentlyContinue)
    if ($vcs.Count -eq 0) { throw 'vault CLI 를 찾을 수 없다(PATH) — 설치 · PATH 확인(아무것도 묻지 않았다)' }
    # 실제로 불릴 vault 의 종류 · 경로를 남긴다(실행 기록에 옮겨 적는다 — 사용자 프로필 경로는 ~ 로 줄여 계정 이름을 남기지 않는다)
    $vsrc = [string]$vcs[0].Source
    if ([string]::IsNullOrEmpty($vsrc)) { $vsrc = '(경로 없음)' }
    elseif (-not [string]::IsNullOrEmpty($HOME) -and $vsrc.StartsWith($HOME, [StringComparison]::OrdinalIgnoreCase)) { $vsrc = '~' + $vsrc.Substring($HOME.Length) }
    $ver = @(vault version 2>$null)
    $global:LASTEXITCODE = 0
    $verLine = '(버전 출력 없음)'
    if ($ver.Count -gt 0) { $verLine = ([string]$ver[0]).Trim() }
    Write-Host "INFO vault CLI: $verLine · $([string]$vcs[0].CommandType) $vsrc — JSON stdin 형식 실측(VD-6)은 T045 블록이 2026-09-21 에 CLI v2.1.0 으로 했다(다르면 되읽기 대조가 첫 경로에서 잡는다)"
    # ---------- 0b) Vault 도달(창 C 의 port-forward) — 토큰 없이 ----------
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
    Write-Host "OK   Vault 도달 · 초기화됨 · unsealed(seal type=$([string](& $prop $st 'type')) · server $([string](& $prop $st 'version')))"
    # ---------- 1) root 토큰(PM) — 형식을 먼저 보고, 맞을 때만 Vault 로 보낸다 ----------
    $tok = ([string](& $readSecret 'root 토큰(PM 에서 복사 · 화면에 남지 않음 · 붙여넣은 직후 클립보드를 비운다)')).Trim()
    if ($tok -cnotmatch '\Ahvs\.[\x21-\x7E]+\z') { $tok = $null; throw '입력이 Vault 토큰 형식(hvs. 로 시작하는 공백 없는 ASCII)이 아니다 — PM 의 다른 항목(복구 키 조각 등)을 붙여 넣었거나, root 토큰 형식이 이 블록의 가정(hvs. — Vault 1.10 이후 서비스 토큰 · README §5 VD)과 다르다. Vault 로 보내지 않았다 · 아무것도 쓰지 않았다' }
    $tokenOwned = $true
    $env:VAULT_TOKEN = $tok
    $tok = $null
    # lookup 응답 전체는 남기지 않는다 — data.id 가 root 토큰 평문이다. 정책 목록만 꺼낸다.
    $tl = @(vault token lookup "-format=json" 2>$null)
    $rc = $LASTEXITCODE
    $global:LASTEXITCODE = 0
    $pol = @()
    if ($rc -eq 0) { $pol = @(& $prop (& $prop (& $parseJson $tl) 'data') 'policies') }
    $tl = $null
    if ($rc -ne 0) { throw "root 토큰 확인 실패(token lookup exit=$rc) — PM 항목 · 창 C 확인. 아무것도 쓰지 않았다" }
    if (-not (& $has $pol 'root')) { throw '토큰 정책에 root 가 없다 — 이 블록은 root 토큰 전용이다(T044 D4). 아무것도 쓰지 않았다' }
    Write-Host 'OK   토큰 정책에 root 포함 — 판정(읽기 전용)을 시작한다'
    # ---------- 2) 판정(읽기 전용 — 이 단계는 아무것도 쓰지 않는다) ----------
    $creates = @()
    $nSkip = 0
    $nStop = 0
    foreach ($e in $paths) {
      $s = & $state $e.path
      if (& $eq $s.kind 'absent') {
        $seedLog[$e.path] = '생성 예정(판정 absent — 쓰기 확인 전)'
        $creates += $e
        Write-Host "PLAN $($e.path) — absent → 생성 예정" }
      elseif (& $eq $s.kind 'live') {
        $j = & $judge $e
        if (& $eq $j.kind 'ok') {
          $nSkip++
          $seedLog[$e.path] = '건너뜀(live-ok — 덮어쓰지 않았다)'
          Write-Host "SKIP $($e.path) — live-ok(키 3 · username · url 구성 · 비밀번호 형식 확인 — 값 미출력 · 덮어쓰지 않는다)" }
        else {
          $nStop++
          $tag = '판정 불가'
          if (& $eq $j.kind 'mismatch') { $tag = 'live-mismatch' }
          $seedLog[$e.path] = "중단($tag — $($j.why))"
          Write-Host "STOP $($e.path) — ${tag}: $($j.why)" } }
      elseif (& $eq $s.kind 'dead') {
        $nStop++
        $seedLog[$e.path] = "중단(dead — $($s.why))"
        Write-Host "STOP $($e.path) — dead: $($s.why)" }
      else {
        $nStop++
        $seedLog[$e.path] = "중단(판정 불가 — $($s.why))"
        Write-Host "STOP $($e.path) — 판정 불가: $($s.why)" } }
    Write-Host "판정 결과: 생성 예정 $($creates.Count) · 건너뜀(live-ok) $nSkip · 중단 $nStop"
    if ($nStop -gt 0) {
      foreach ($e in $creates) { $seedLog[$e.path] = '미실행(판정 단계에서 중단 — 쓰지 않았다)' }
      throw "판정 단계에서 중단 — STOP ${nStop}건(위 STOP 줄 · 런북 bootstrap.md §4 T054 소절 실패 시 표) · kv 쓰기 0건" }
    if ($creates.Count -eq 0) {
      Write-Host 'INFO 쓸 경로 없음 — 6경로 모두 live-ok(재실행은 건너뛴다 · 회전이 아니다)'
      return }
    # ---------- 3) 쓰기 확인(정지점 — 쓸 경로 목록만 보인다, 값은 아직 만들지도 않았다) ----------
    Write-Host ''
    Write-Host "쓸 경로 $($creates.Count)개 — 값은 이 블록이 경로마다 따로 랜덤 생성한다(화면에 나오지 않는다):"
    foreach ($e in $creates) { Write-Host "  - $($e.path)  (username=$($e.user) · db=$($e.db))" }
    try { & $stop "쓰기 확인: 위 $($creates.Count)개 경로에 -cas=0 으로 쓴다(이미 있으면 거부 — 덮어쓰기 없음)" 'seed' }
    catch {
      foreach ($e in $creates) { $seedLog[$e.path] = '미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)' }
      throw }
    # ---------- 4) 쓰기 + 되읽기(경로마다 — 실패하면 그 자리에서 멈춘다) ----------
    foreach ($e in $creates) { $seedLog[$e.path] = '미실행(앞 경로에서 중단 — 쓰지 않았다)' }
    foreach ($e in $creates) { & $write $e }
  }
  finally {
    if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue }
    if ($addrOwned) { Remove-Item Env:VAULT_ADDR -ErrorAction SilentlyContinue }
    # 위 두 줄(블록이 만든 자격 — 조건부)이 finally 의 첫 문장이다: Ctrl+C 를 거듭 눌러 finally 가 중간에 끊겨도 root 토큰부터 사라진다.
    # 이어서 변수 · 클립보드 · $Error 를 정리하고, 요약은 그 뒤에 낸다.
    Remove-Variable tok, tl, pol, st, so, serr, ch, pre, bad, ver, verLine, j, s, ini, sea -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning $clipWarn }
    # 이 실행이 $Error 에 남긴 기록(값이 섞일 수 있는 예외 대비)만 지운다 — 이전 기록은 그대로.
    try { while ($Error.Count -gt 0 -and -not [object]::ReferenceEquals($Error[0], $errTop)) { $Error.RemoveAt(0) } } catch { }
    # 이 아래는 Write-Host/Write-Warning 만 쓴다 — Ctrl+C 중지 중에는 첫 "성공 스트림" 출력에서 finally 가 끊긴다.
    Write-Host ''
    Write-Host '--- T054 DB 자격 시드 결과 요약(값 없음 — 런북 bootstrap.md §4 T054 소절에 그대로 기록) ---'
    foreach ($k in $seedLog.Keys) { Write-Host ('{0,-36} {1}' -f $k, $seedLog[$k]) }
    $vals = @($seedLog.Values | ForEach-Object { [string]$_ })
    $nNew = @($vals | Where-Object { $_.StartsWith('생성 v1', [StringComparison]::Ordinal) }).Count
    $nLost = @($vals | Where-Object { $_.StartsWith('기록됨(응답 유실', [StringComparison]::Ordinal) }).Count
    $nRec = @($vals | Where-Object { $_.StartsWith('기록됨', [StringComparison]::Ordinal) }).Count - $nLost
    $nUnk = @($vals | Where-Object { $_.StartsWith('결과 미확인', [StringComparison]::Ordinal) }).Count
    $nSk = @($vals | Where-Object { $_.StartsWith('건너뜀', [StringComparison]::Ordinal) }).Count
    $nSt = @($vals | Where-Object { $_.StartsWith('중단', [StringComparison]::Ordinal) }).Count
    $nNo = $vals.Count - $nNew - $nLost - $nRec - $nUnk - $nSk - $nSt
    Write-Host "이 실행이 kv 에 새로 쓴 경로: $($nNew + $nLost + $nRec)건(생성·검증 완료 $nNew · 응답 유실 뒤 재판정으로 검증 완료 $nLost · 기록 후 검증 실패 $nRec) · 결과 미확인 $nUnk · 건너뜀 $nSk · 중단 $nSt · 미실행 $nNo"
    if ($nUnk -gt 0) { Write-Host '결과 미확인 = put 도중 중단 또는 put 비 0 뒤 재판정 불가 — kv 에 v1 이 있을 수 있다. 지우지 말고 재실행한다(판정이 live 로 보고 모양이 맞으면 SKIP · 없으면 생성)' }
    if ($nNew + $nLost + $nSk -eq $vals.Count) { Write-Host '판정: kv 6경로 준비 완료(생성 또는 live-ok) — gitops T054 PR 머지 전제 충족 · 머지 뒤 ExternalSecret 6장 SecretSynced 를 확인한다(이미 머지됐다면 런북 §4 T054 소절 「늦은 시드」)' }
    else { Write-Host '판정: 미완 — 위 STOP 줄과 런북 bootstrap.md §4 T054 소절의 실패 시 표를 본다(재실행은 안전하다: live-ok 는 건너뛰고 -cas=0 은 덮어쓰지 않는다)' }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    Write-Host '창 종료 체크리스트(docs/runbooks/vault-unseal.md §0 · 창 D): 창 C port-forward 종료(Ctrl+C) · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제 · 이 창을 닫는다'
  }
}
