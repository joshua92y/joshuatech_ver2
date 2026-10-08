# ===== T045 kv 값 정정 블록 v2 — 통째로 붙여 넣어도 안전(창 D, 창 C 의 port-forward 유지) =====
# 비상용(잠금 복구 R1 2단계 · G3 되돌리기). 원칙은 OP1 과 같다: 정지점마다 단어 입력, 모든 취득·put·되읽기가 fail-closed,
# finally 가 토큰·변수·클립보드를 정리한다. 이 블록은 **단일 필드 경로 전용**이다(kv put 은 경로 전체를 교체한다).
# 좌표(ns·Secret·키)는 손으로 입력하지 않는다 — 경로마다 고정 표에서 꺼낸다(교차 배선 = 운영자 잠금).
# 사전(블록 밖): 클립보드 기록 끄기 · PSReadLine 로드 확인 · 창 C 의 port-forward.
# 붙여넣기 안전: 전체가 `& { … }` 한 문이고 블록 안에 빈 줄이 없으며 파일 끝은 `}` + 개행 1개뿐이다(열 0 정렬 · 끝 공백 없음).
& {
  $ErrorActionPreference = 'Stop'
  # 정정할 경로(표에 있는 둘 중 하나만). 필드는 표가 정한다.
  $fixPath = 'kv/platform/cloudflare/tunnel'
  $wrote = $false
  try {
    # ---------- 경로 ↔ 라이브 출처 고정 표(손 입력 없음) ----------
    $fixMap = @{
      'kv/platform/cloudflare/tunnel'    = @{ field = 'token'; ns = 'cloudflared';  name = 'cloudflared-tunnel';  key = 'TUNNEL_TOKEN'; shape = 'tunnel' }
      'kv/platform/cloudflare/dns-token' = @{ field = 'token'; ns = 'cert-manager'; name = 'cloudflare-dns-token'; key = 'api-token';    shape = 'dns' } }
    if (-not $fixMap.ContainsKey($fixPath)) { throw "이 블록의 정정 대상이 아닌 경로: $fixPath — 단일 필드 경로 전용(다필드는 kv patch 전용 블록으로 분리)" }
    $fx = $fixMap[$fixPath]
    $fixField = [string]$fx.field
    # ---------- 헬퍼(OP1 과 동일 규약) ----------
    $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
    $ask = { param($msg)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      [string](Read-Host $msg) }
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt" }
      ($ss | ConvertFrom-SecureString -AsPlainText) }
    $state = { param($path)
      $raw = vault kv metadata get "-format=json" $path 2>$null
      $rc = $LASTEXITCODE; $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or [string]::IsNullOrWhiteSpace([string]($raw -join ''))) { return 'absent' }
      $d = (($raw -join "`n") | ConvertFrom-Json -DateKind String).data
      $ver = $d.versions.PSObject.Properties[[string]$d.current_version]
      if ($null -eq $ver -or $ver.Value.destroyed -or -not [string]::IsNullOrWhiteSpace([string]$ver.Value.deletion_time)) { return 'dead' }
      'live' }
    # 되읽기는 JSON 으로만(`-field` 캡처는 값 끝 개행 1개를 잃는다)
    $readField = { param($path, $field)
      $raw = vault kv get "-format=json" $path
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($raw -join ''))) { throw "되읽기 실패: $path .$field" }
      $pr = (($raw -join "`n") | ConvertFrom-Json -DateKind String).data.data.PSObject.Properties[$field]
      if ($null -eq $pr -or $pr.Value -isnot [string]) { throw "되읽기: $path .$field 가 없거나 문자열이 아니다 — 중단" }
      [string]$pr.Value }
    # 형제 경로의 현재 값을 "해시로만" 돌려준다(값은 이 스코프 밖으로 나가지 않는다). 없으면 빈 문자열.
    $fieldHash = { param($path, $field)
      if (-not [string]::Equals((& $state $path), 'live', [StringComparison]::Ordinal)) { return '' }
      (& $sha (& $readField $path $field)) }
    $isTunnelShape = { param($s)
      $r = $false
      try { $j = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$s)) | ConvertFrom-Json -DateKind String
            $r = [bool]($j.a -and $j.t -and $j.s) } catch { $r = $false }
      $r }
    # ---------- 0) 창 전제 ----------
    $ch = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시' }
    $env:VAULT_ADDR = 'http://127.0.0.1:18200'
    $sealRaw = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($sealRaw -join ''))) { throw 'Vault 도달 실패(빈 응답) — 창 C port-forward 확인' }
    $st = ($sealRaw -join "`n") | ConvertFrom-Json -DateKind String
    if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 미초기화 또는 sealed — 창 C·unseal 상태 확인' }
    $env:VAULT_TOKEN = (& $readSecret 'root 토큰(PM에서 복사 · 화면에 남지 않음)').Trim()
    if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
    $pol = (((vault token lookup "-format=json") -join "`n") | ConvertFrom-Json -DateKind String).data.policies
    if ($LASTEXITCODE -ne 0 -or -not (@($pol) | Where-Object { [string]::Equals([string]$_, 'root', [StringComparison]::Ordinal) })) { throw 'root 토큰 확인 실패 — 중단' }
    # ---------- 1) 정정 값 취득(세 갈래 · 좌표는 표에서만) ----------
    # kubectl 전제는 출처 a 안에서만 확인한다 — 잠금 복구 중에는 클러스터가 안 보여도 b·c 로 정정해야 한다.
    $src = & $ask "값 출처: a=라이브 Secret($($fx.ns)/$($fx.name) .$($fx.key)) · b=이 세션의 `$pre(base64) · c=PM 직접 입력"
    if ([string]::Equals($src, 'a', [StringComparison]::Ordinal)) {
      $nodes = @(kubectl get nodes -o name "--request-timeout=15s")
      if ($LASTEXITCODE -ne 0 -or -not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) { throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — admin kubeconfig 확인, 또는 출처 b·c 로 간다" }
      $b64 = kubectl -n $fx.ns get secret $fx.name -o "jsonpath={.data['$($fx.key)']}" "--request-timeout=15s"
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$b64)) { throw "라이브 Secret 취득 실패: $($fx.ns)/$($fx.name) .$($fx.key) — 중단" }
      $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$b64))
      if (-not [string]::Equals([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($new)), [string]$b64, [StringComparison]::Ordinal)) {
        throw "라이브 값이 UTF-8 왕복에서 바이트가 달라진다: $($fx.ns)/$($fx.name) .$($fx.key) — 중단" } }
    elseif ([string]::Equals($src, 'b', [StringComparison]::Ordinal)) {
      if ([string]::IsNullOrWhiteSpace([string]$pre)) { throw '$pre 가 비어 있다(이 세션이 아니다) — c 로 간다' }
      $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$pre)) }
    elseif ([string]::Equals($src, 'c', [StringComparison]::Ordinal)) {
      $new = & $readSecret "PM 값($fixPath .$fixField · 화면에 남지 않음)" }
    else { throw '출처가 a/b/c 가 아니다 — 중단(입력 버퍼에 남은 입력일 수 있다)' }
    # ---------- 1b) 값 모양 검사(값은 출력하지 않는다) ----------
    if ([string]::IsNullOrWhiteSpace($new)) { throw '정정 값이 비었다 — 중단' }
    if ($new.Length -lt 32) { throw "정정 값이 비정상적으로 짧다(길이 $($new.Length)) — 중단" }
    # `\A…\z` 를 쓴다 — `^…$` 는 문자열 끝 개행 1개를 통과시킨다(실측). 공백·개행·BOM·ZWSP 를 한 번에 잡는다.
    if ($new -cnotmatch '\A[\x21-\x7E]+\z') { throw '정정 값에 ASCII 인쇄 문자 밖의 문자(공백·개행·BOM·ZWSP 포함)가 있다 — 중단' }
    if ([string]::Equals($new, [string]$env:VAULT_TOKEN, [StringComparison]::Ordinal) -or $new.StartsWith('hvs.', [StringComparison]::Ordinal)) {
      throw '정정 값이 Vault 토큰이다(클립보드 잔류 의심) — 아무것도 쓰지 않았다' }
    # 교차 배선 검사 ①: 표의 다른 경로의 현재 kv 값과 같으면 중단(형식 가정이 필요 없는 검사)
    foreach ($o in $fixMap.Keys) {
      if ([string]::Equals([string]$o, $fixPath, [StringComparison]::Ordinal)) { continue }
      $oh = & $fieldHash ([string]$o) ([string]$fixMap[$o].field)
      if ($oh -and [string]::Equals($oh, (& $sha $new), [StringComparison]::Ordinal)) { throw "새 값이 $o 의 현재 kv 값과 같다 — 교차 배선이다. 아무것도 쓰지 않았다" } }
    # 교차 배선 검사 ②: 값 형식. 라이브로 아직 확정되지 않은 휴리스틱이므로 기본은 중단, 'override' 를 입력해야만 진행한다.
    $shapeIsTunnel = & $isTunnelShape $new
    $shapeWant = [string]::Equals([string]$fx.shape, 'tunnel', [StringComparison]::Ordinal)
    if ($shapeIsTunnel -ne $shapeWant) {
      Write-Warning "값 형식이 $fixPath 의 기대와 다르다(base64-JSON{a,t,s} = $shapeIsTunnel · 기대 = $shapeWant). 교차 배선일 수 있다. 이 판정은 OP1 B) 의 '참고(값 아님)' 줄로 확인한 뒤에만 신뢰한다"
      & $stop "형식 불일치 — 형식 판정이 틀렸다고 확인한 경우에만 진행한다" 'override' }
    # ---------- 2) 현재 상태(버전 · 키 집합 · 현재 값 해시) ----------
    if (-not [string]::Equals((& $state $fixPath), 'live', [StringComparison]::Ordinal)) {
      throw "$fixPath 의 현재 버전이 없거나 삭제·파기 상태다 — 정정이 아니라 시드(OP1) 또는 metadata delete 뒤 재시드 경로다" }
    $curRaw = vault kv metadata get "-format=json" $fixPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($curRaw -join ''))) { throw "current_version 취득 실패: $fixPath — 중단" }
    $cur = (($curRaw -join "`n") | ConvertFrom-Json -DateKind String).data.current_version
    if ($null -eq $cur) { throw "current_version 취득 실패: $fixPath — 중단" }
    $dRaw = vault kv get "-format=json" $fixPath
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($dRaw -join ''))) { throw "현재 값 취득 실패: $fixPath — 중단" }
    $curData = (($dRaw -join "`n") | ConvertFrom-Json -DateKind String).data.data
    if ($null -eq $curData) { throw "현재 버전에 데이터가 없다: $fixPath — 중단" }
    # kv put 은 경로 전체를 교체한다 — 다른 필드가 있으면 조용히 사라지므로 중단한다.
    $others = @(@($curData.PSObject.Properties.Name) | Where-Object { -not [string]::Equals([string]$_, $fixField, [StringComparison]::Ordinal) })
    if ($others.Count -gt 0) { throw "$fixPath 에 다른 필드가 있다($($others -join ', ')) — kv put 은 경로 전체를 교체한다. 이 블록은 단일 필드 경로 전용. 중단" }
    $curProp = $curData.PSObject.Properties[$fixField]
    if ($null -eq $curProp -or $curProp.Value -isnot [string]) { throw "$fixPath .$fixField 가 없거나 문자열이 아니다 — 중단" }
    if ([string]::Equals((& $sha $curProp.Value), (& $sha $new), [StringComparison]::Ordinal)) {
      "SKIP $fixPath .$fixField — 새 값이 현재 kv 값(버전 $cur)과 같다. 쓰지 않았다(출처가 a 였다면 라이브가 이미 kv 값으로 덮인 뒤일 수 있다 → b 또는 c 로 다시)" }
    else {
      # ---------- 3) 확인(출처·길이·버전을 문면에 노출한다) ----------
      $ok = & $ask "3) $fixPath .$fixField 의 현재 버전 $cur 를 [출처 $src · 새 값 길이 $($new.Length) · 현재 값과 다름] 로 덮어쓴다. 계속하려면 yes 를 입력하고 Enter"
      if (-not [string]::Equals($ok, 'yes', [StringComparison]::Ordinal)) { throw '취소됨 — 아무것도 쓰지 않았다' }
      # ---------- 4) CAS put → 되읽기 SHA-256 Ordinal 비교 ----------
      (@{ $fixField = $new } | ConvertTo-Json -Compress) | vault kv put "-cas=$cur" $fixPath -
      if ($LASTEXITCODE -ne 0) { throw "정정 put 실패(CAS 충돌이면 그 사이 다른 쓰기가 있었다): $fixPath" }
      $wrote = $true
      $back = & $readField $fixPath $fixField
      if (-not [string]::Equals((& $sha $back), (& $sha $new), [StringComparison]::Ordinal)) {
        Write-Warning "되읽기 불일치 — Vault 현재 버전은 $($cur + 1)(검증 실패 값)이고 직전 버전 $cur 는 보존돼 있다. ES 가 붙어 있으면 다음 refresh(≤5분)에 라이브로 전파된다"
        $rb = & $ask "직전 버전 $cur 의 값으로 되돌리려면 rollback 을 입력(그 외 = 그대로 두고 중단)"
        if ([string]::Equals($rb, 'rollback', [StringComparison]::Ordinal)) {
          vault kv rollback "-version=$cur" $fixPath
          if ($LASTEXITCODE -ne 0) { throw "rollback 실패 — 현재 버전 $($cur + 1) 이 검증 실패 값인 채로 남았다: $fixPath (수동: vault kv rollback `"-version=$cur`" $fixPath)" }
          throw "되읽기 불일치 → 버전 $cur 의 값으로 되돌렸다. 원인 확인 후 다시" }
        throw "되읽기 불일치 — 현재 버전 $($cur + 1) 이 검증 실패 값이다(되돌리기: vault kv rollback `"-version=$cur`" $fixPath)" }
      "OK 정정 완료: $fixPath .$fixField (버전 $cur → $($cur + 1))" }
  }
  finally {
    # ⚠ `$pre`·`$preUid` 는 지우지 않는다 — G4 되돌리기 R2 의 stdin 복구에 필요하다.
    Remove-Variable new, back, b64, src, ns, sn, sk, cur, ok, rb, curData, curProp, curRaw, dRaw, others, pol, st, sealRaw, nodes, oh, ch, fx, fixMap -ErrorAction SilentlyContinue
    if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
    if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
    try { Set-Clipboard -Value ' ' } catch { }
    # 이 아래는 Write-Host/Write-Warning 만 — Ctrl+C 중지 중에는 첫 "성공 스트림" 출력문에서 finally 가 끊긴다.
    if ($wrote) { Write-Host '이 블록이 kv 에 새 버전을 썼다 — 다음 refresh(≤5분) 또는 VD-15 force-sync 뒤 라이브 Secret 값을 다시 비교한다.' }
    else { Write-Host '이 블록은 kv 에 아무것도 쓰지 않았다(취소 · 검사 중단 · SKIP 중 하나).' }
  }
}
