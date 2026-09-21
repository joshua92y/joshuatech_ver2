# ===== T045 OP1 kv 시드 블록 v2 — 통째로 붙여 넣어도 안전(창 D) =====
# 원칙: (a) 사람 동작마다 정지점에서 멈춘다(빈 Enter 로는 통과하지 않는다 — 단어를 입력해야 한다)
#       (b) 취득·put·되읽기는 전부 fail-closed(throw) — 출력만 하고 계속 가는 비교는 없다
#       (c) 검증 통과 전에는 원본(라이브 Secret·PM·변수)을 아무것도 지우지 않는다
#       (d) 값은 화면·argv·파일에 나오지 않는다  (e) 최초 쓰기는 `-cas=0`, 재실행은 해시 비교로 가른다(D10-⑤)
#       (f) 성공·실패 어느 쪽이든 finally 가 토큰·변수·클립보드를 정리하고 경로별 요약을 낸다
# 사전(블록 밖): 런북 §0 체크리스트 · 창 C 의 port-forward · PM 육안 확인 ·
#       **설정 > 시스템 > 클립보드 > 클립보드 기록 끄기**(Win+V 로 확인 — 켜져 있으면 아래 첫 검사에서 멈춘다) ·
#       `if (-not (Get-Module PSReadLine)) { throw 'PSReadLine 미로드 — 이 창에서는 블록을 붙여 넣지 않는다' }` 를 별도로 1회 실행
# 붙여넣기 안전: 아래 전체가 `& { … }` 한 문(statement)이다 — 중괄호가 닫힐 때까지 입력이 모이므로 전체가 파싱된 뒤 한 번에 실행되고,
#       중간 줄이 단독 실행되지 않는다. 블록 안에는 빈 줄이 없고(빈 줄에서 입력 수집을 끝내는 기본 콘솔 호스트 대비),
#       파일 끝은 `}` + 개행 1개뿐이다(남은 문자가 첫 Read-Host 로 흘러들지 않는다).
#       모든 정지점은 직전에 콘솔 입력 버퍼를 비우고 단어 입력을 요구한다(미리 눌린 Enter 로 통과하지 않는다).
& {
  $ErrorActionPreference = 'Stop'
  # 경로별 요약(규칙 9)은 시작할 때 전부 채워 둔다 — 중간에 throw 해도 "도달하지 못함"이 표에 남는다.
  $seedLog = [ordered]@{}
  foreach ($p in 'kv/platform/cloudflare/dns-token', 'kv/platform/cloudflare/tunnel', 'kv/platform/oci/s3', 'kv/platform/test/t045-probe') {
    $seedLog[$p] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  # 이연 3행도 먼저 넣는다(D10-④ 범위가 throw 때도 요약에 남는다)
  $seedLog['kv/{dev,prod}/access/web-bff']        = '이연(T092 — 읽기 권한 범위·전달 절차 확정 후)'
  $seedLog['kv/platform/access/tester-{m2m,k8s}'] = '이연(T077 — 동일)'
  $seedLog['kv/platform/grafana-cloud']           = '이연(T098 — 소비자 기준 키 집합 확정 후)'
  try {
    # ---------- 헬퍼 ----------
    $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    # 정지점: 버퍼를 비우고 단어를 요구한다. 빈 Enter·버퍼 잔여 입력으로는 통과하지 않는다.
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
    # 분기 질문(y/skip). 반환값을 받아 쓰므로 입력이 화면에 되출력되지 않는다.
    $ask = { param($msg)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      [string](Read-Host $msg) }
    # 비밀 입력: 붙여넣은 직후 클립보드를 비운다(뒤의 평문 정지점에서 우클릭 붙여넣기 사고를 막는다).
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력 — 중단: $prompt" }
      ($ss | ConvertFrom-SecureString -AsPlainText) }
    # 경로 상태: absent | live | dead(현재 버전이 soft-delete 또는 destroy). 비밀 값을 읽지 않는다.
    $state = { param($path)
      $raw = vault kv metadata get "-format=json" $path 2>$null
      $rc = $LASTEXITCODE; $global:LASTEXITCODE = 0
      if ($rc -ne 0 -or [string]::IsNullOrWhiteSpace([string]($raw -join ''))) { return 'absent' }
      $d = (($raw -join "`n") | ConvertFrom-Json -DateKind String).data
      $ver = $d.versions.PSObject.Properties[[string]$d.current_version]
      if ($null -eq $ver -or $ver.Value.destroyed -or -not [string]::IsNullOrWhiteSpace([string]$ver.Value.deletion_time)) { return 'dead' }
      'live' }
    # 되읽기는 JSON 으로만 한다 — `-field` 캡처는 값 끝의 개행 1개를 구조적으로 잃어 "다른 값"을 "같음"으로 오판한다.
    $readField = { param($path, $field)
      $raw = vault kv get "-format=json" $path
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($raw -join ''))) { throw "되읽기 실패: $path .$field" }
      $pr = (($raw -join "`n") | ConvertFrom-Json -DateKind String).data.data.PSObject.Properties[$field]
      if ($null -eq $pr -or $pr.Value -isnot [string]) { throw "되읽기: $path .$field 가 없거나 문자열이 아니다 — 중단" }
      [string]$pr.Value }
    # 값 형식 참고 판정(비밀 아님 · 불리언만 돌려준다): cloudflared 터널 토큰 = base64(JSON{a,t,s})
    $isTunnelShape = { param($s)
      $r = $false
      try { $j = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$s)) | ConvertFrom-Json -DateKind String
            $r = [bool]($j.a -and $j.t -and $j.s) } catch { $r = $false }
      $r }
    # 라이브 Secret 취득: base64 왕복으로 바이트 동일성을 확인하고, ASCII 인쇄 문자만 통과시킨다.
    # `\A…\z` 를 쓴다 — `^…$` 는 문자열 끝 개행 1개를 통과시킨다(실측).
    $getLive = { param($ns, $name, $key)
      $b64 = kubectl -n $ns get secret $name -o "jsonpath={.data['$($key)']}" "--request-timeout=15s"
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$b64)) { throw "라이브 Secret 취득 실패: $ns/$name .$key — 시드 중단" }
      $v = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$b64))
      if (-not [string]::Equals([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($v)), [string]$b64, [StringComparison]::Ordinal)) {
        throw "라이브 값이 UTF-8 왕복에서 바이트가 달라진다: $ns/$name .$key — 문자열 복사로 동일성을 보장할 수 없다. 중단" }
      if ($v.Length -lt 32) { throw "라이브 값이 비정상적으로 짧다(길이 $($v.Length)): $ns/$name .$key — 시드 중단" }
      if ($v -cnotmatch '\A[\x21-\x7E]+\z') { throw "라이브 값에 ASCII 인쇄 문자 밖의 문자(공백·개행·BOM·ZWSP 포함)가 있다: $ns/$name .$key — 중단(사용자 결정)" }
      $v }
    # 경로 1개 시드. 이미 값이 있으면 덮어쓰지 않고 해시로 가른다(재실행 안전). 모든 분기가 $seedLog 를 확정 문구로 덮는다.
    $seed = { param($path, [hashtable]$map)
      $seedLog[$path] = '중단(시드 단계에서 실패 — 아래 오류 참조)'
      foreach ($k in $map.Keys) {
        if ($map[$k] -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$map[$k])) {
          $seedLog[$path] = "중단(빈 값 또는 비문자열: $k)"
          throw "${path} .${k} 가 빈 값이거나 문자열이 아니다 — 중단" } }
      $st8 = & $state $path
      if ([string]::Equals($st8, 'dead', [StringComparison]::Ordinal)) {
        $seedLog[$path] = '중단(현재 버전이 삭제·파기 상태 — -cas=0 불가)'
        throw "${path}: 현재 버전이 삭제·파기됐다 — 'vault kv metadata delete' 뒤 재실행하거나 정정 블록(-cas=현재버전)을 쓴다" }
      if ([string]::Equals($st8, 'live', [StringComparison]::Ordinal)) {
        foreach ($k in $map.Keys) {
          if (-not [string]::Equals((& $sha (& $readField $path $k)), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
            $seedLog[$path] = '중단(존재하지만 값이 다름)'
            throw "${path} .${k}: 이미 다른 값이 있다 — 덮어쓰지 않고 중단(값 교체는 정정 블록 · T084 회전 절차)" } }
        $seedLog[$path] = '이미 시드됨(값 동일)'
        return "SKIP $path — 이미 시드됨(값 동일)" }
      ($map | ConvertTo-Json -Compress) | vault kv put "-cas=0" $path -
      if ($LASTEXITCODE -ne 0) {
        $seedLog[$path] = '중단(put 실패 — CAS 충돌이면 이미 값이 있다)'
        throw "vault kv put 실패: $path" }
      # put 이 성공한 순간을 요약에 남긴다 — 되읽기 명령이 실패해도 "썼다"는 사실이 표에 남는다.
      $seedLog[$path] = '기록됨 — 되읽기 검증 전(아래 오류 확인 · 값이 이미 kv 에 있다)'
      foreach ($k in $map.Keys) {
        if (-not [string]::Equals((& $sha (& $readField $path $k)), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
          $seedLog[$path] = '중단(되읽기 불일치 — 값이 기록됐으나 검증 실패 · 정정 블록으로 정정)'
          throw "kv 값 불일치: $path .$k — 중단(원본은 그대로 · 정정 블록으로 정정한다)" } }
      $seedLog[$path] = '완료(신규)'
      "OK   $path ($((($map.Keys) | Sort-Object) -join ', '))" }
    # ---------- 0) 창 전제(비밀을 꺼내기 전에 전부 확인한다) ----------
    $ch = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시' }
    if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인 확인 후 다시' }
    # 0b) kubectl 전제 — root 토큰을 PM 에서 꺼내기 "전에" 확인한다(전제가 틀리면 토큰 노출 주기를 헛되이 쓴다)
    $nodes = @(kubectl get nodes -o name "--request-timeout=15s")
    if ($LASTEXITCODE -ne 0 -or -not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {
      throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — 창 D 에서 admin kubeconfig 를 지정하고 다시(root 토큰은 아직 입력하지 않았다)" }
    $can = kubectl auth can-i get secrets -n cert-manager "--request-timeout=15s"
    if ($LASTEXITCODE -ne 0 -or -not [string]::Equals([string]$can, 'yes', [StringComparison]::Ordinal)) {
      throw '현재 kubeconfig 로는 Secret 을 읽을 수 없다(agent-view 인가?) — admin kubeconfig 확인(root 토큰 미입력)' }
    foreach ($s in @(@{ ns = 'cert-manager'; name = 'cloudflare-dns-token' }, @{ ns = 'cloudflared'; name = 'cloudflared-tunnel' })) {
      $nm = kubectl -n $s.ns get secret $s.name -o name "--request-timeout=15s"
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$nm)) {
        throw "사전 점검 실패: kubectl 로 $($s.ns)/$($s.name) 을 읽을 수 없다 — KUBECONFIG(admin)·터널 창 확인(root 토큰 미입력)" } }
    # 0c) Vault 도달(창 C 의 port-forward)
    $env:VAULT_ADDR = 'http://127.0.0.1:18200'
    $sealRaw = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($sealRaw -join ''))) { throw 'Vault 도달 실패(빈 응답) — 창 C port-forward 확인' }
    $st = ($sealRaw -join "`n") | ConvertFrom-Json -DateKind String
    if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 미초기화 또는 sealed — 창 C·unseal 상태 확인' }
    # ---------- 1) root 토큰 ----------
    $env:VAULT_TOKEN = (& $readSecret 'root 토큰(PM에서 복사 · 화면에 남지 않음)').Trim()
    if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
    # lookup 응답 전체($tl)는 남기지 않는다 — data.id 가 root 토큰 평문이다. 정책 목록만 꺼낸다.
    $pol = (((vault token lookup "-format=json") -join "`n") | ConvertFrom-Json -DateKind String).data.policies
    if ($LASTEXITCODE -ne 0 -or -not (@($pol) | Where-Object { [string]::Equals([string]$_, 'root', [StringComparison]::Ordinal) })) { throw 'root 토큰 확인 실패 — 중단' }
    # ---------- A) JSON stdin 형식 실측(VD-6) — 폐기 경로. 사전 정리 + 자체 finally 로 재실행 안전 ----------
    & $stop 'A) 폐기 경로로 JSON stdin 형식을 1회 실측한다(VD-6)'
    if (-not [string]::Equals((& $state 'kv/platform/_probe'), 'absent', [StringComparison]::Ordinal)) {
      vault kv metadata delete kv/platform/_probe | Out-Null
      if ($LASTEXITCODE -ne 0) { throw '프로브 경로 사전 정리 실패 — 권한·연결 확인(kv/platform/_probe)' } }
    try {
      ('{"a":"x","b":"y"}') | vault kv put "-cas=0" kv/platform/_probe - | Out-Null
      if ($LASTEXITCODE -ne 0) { throw '프로브 put 실패 — 권한·감사 장치 확인' }
      $pRaw = vault kv get "-format=json" kv/platform/_probe
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($pRaw -join ''))) { throw '프로브 되읽기 실패 — 중단' }
      $pd = (($pRaw -join "`n") | ConvertFrom-Json -DateKind String).data.data
      $pk = (@($pd.PSObject.Properties.Name) | Sort-Object) -join ','
      if (-not ([string]::Equals($pk, 'a,b', [StringComparison]::Ordinal) -and [string]::Equals([string]$pd.a, 'x', [StringComparison]::Ordinal) -and [string]::Equals([string]$pd.b, 'y', [StringComparison]::Ordinal))) {
        throw "JSON stdin 형식이 기대와 다르다(keys=$pk) — 중단, 설계 VD-6 폴백 검토" }
      'OK   VD-6: JSON stdin 이 문자열 필드로 저장된다(keys=a,b · 값 x,y 일치)'
    } finally {
      vault kv metadata delete kv/platform/_probe | Out-Null
      if ($LASTEXITCODE -ne 0) { Write-Warning 'kv/platform/_probe 삭제 실패(비밀 아님) — 다음 실행의 A)가 먼저 지운다' }
      $global:LASTEXITCODE = 0 }
    # ---------- B) 라이브 Secret 2건 → Vault 파이프 복사 ----------
    & $stop 'B) 라이브 Secret 2건(dns-token · tunnel) 을 Vault 로 파이프 복사한다(값 비노출)'
    $seedLog['kv/platform/cloudflare/dns-token'] = '중단(라이브 Secret 취득 단계에서 실패)'
    $v1 = & $getLive 'cert-manager' 'cloudflare-dns-token' 'api-token'
    & $seed 'kv/platform/cloudflare/dns-token' @{ token = $v1 }
    $seedLog['kv/platform/cloudflare/tunnel'] = '중단(라이브 Secret 취득 단계에서 실패)'
    $v2 = & $getLive 'cloudflared' 'cloudflared-tunnel' 'TUNNEL_TOKEN'
    & $seed 'kv/platform/cloudflare/tunnel' @{ token = $v2 }
    # 값이 아니라 불리언 2개만 찍는다 — 정정 블록의 교차배선 형식 검사(base64 JSON{a,t,s})가 옳은지 확정하는 근거다.
    Write-Host "참고(값 아님) 형식 판정 base64-JSON{a,t,s}: tunnel=$(& $isTunnelShape $v2) · dns-token=$(& $isTunnelShape $v1)  → tunnel=True · dns=False 이면 정정 블록의 형식 검사를 그대로 신뢰한다"
    # ---------- C) oci/s3(조건부) ----------
    $ansC = & $ask 'C) kv/platform/oci/s3 — PM 에 svc-s3-backup 키 쌍의 **두 절반이 모두** 있으면 y, 없으면 skip 을 입력(빈 Enter 는 중단)'
    if ([string]::Equals($ansC, 'y', [StringComparison]::Ordinal)) {
      $ak = (& $readSecret 'access_key').Trim()
      $sk = (& $readSecret 'secret_key').Trim()
      foreach ($x in @($ak, $sk)) {
        if ([string]::Equals($x, [string]$env:VAULT_TOKEN, [StringComparison]::Ordinal) -or $x.StartsWith('hvs.', [StringComparison]::Ordinal)) {
          throw 'oci/s3 입력이 Vault 토큰이다(클립보드 잔류 의심) — 아무것도 쓰지 않았다' }
        if ($x -cnotmatch '\A[\x21-\x7E]+\z') { throw 'oci/s3 입력에 ASCII 인쇄 문자 밖의 문자가 있다 — 아무것도 쓰지 않았다' } }
      if ([string]::Equals($ak, $sk, [StringComparison]::Ordinal)) { throw 'access_key 와 secret_key 가 같다(같은 클립보드를 두 번 붙였다) — 아무것도 쓰지 않았다' }
      & $seed 'kv/platform/oci/s3' @{ access_key = $ak; secret_key = $sk } }
    elseif ([string]::Equals($ansC, 'skip', [StringComparison]::Ordinal)) {
      $seedLog['kv/platform/oci/s3'] = if ([string]::Equals((& $state 'kv/platform/oci/s3'), 'live', [StringComparison]::Ordinal)) {
        '이미 존재(이전 실행에서 시드됨 · 이번 실행에서는 값 미대조)' } else {
        '보류(키 쌍 미확인 — 자동 재발급 금지 · T053 전 별도 발급·교체 작업)' } }
    else { throw 'C) 응답이 y/skip 이 아니다 — 중단(입력 버퍼에 남은 입력일 수 있다)' }
    # ---------- D) DR1 드릴 경로(비밀 아님) ----------
    $ansD = & $ask 'D) kv/platform/test/t045-probe — DR1 을 아직 안 했으면 y, 이미 끝내고 경로까지 지웠으면 skip 을 입력'
    if ([string]::Equals($ansD, 'y', [StringComparison]::Ordinal)) {
      & $seed 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' } }
    elseif ([string]::Equals($ansD, 'skip', [StringComparison]::Ordinal)) {
      $seedLog['kv/platform/test/t045-probe'] = '건너뜀(DR1 완료 — 드릴 경로를 다시 만들지 않는다)' }
    else { throw 'D) 응답이 y/skip 이 아니다 — 중단(입력 버퍼에 남은 입력일 수 있다)' }
    # ---------- 메타데이터 확인(게이트 문면: current_version) ----------
    foreach ($p in 'kv/platform/cloudflare/dns-token', 'kv/platform/cloudflare/tunnel') {
      $mdRaw = vault kv metadata get "-format=json" $p
      if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($mdRaw -join ''))) { throw "메타데이터 조회 실패: $p — 중단" }
      $md = (($mdRaw -join "`n") | ConvertFrom-Json -DateKind String).data
      "META $p  current_version=$($md.current_version)  oldest_version=$($md.oldest_version)  created_time=$($md.created_time)" }
    $lsRaw = vault kv list kv/platform 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Warning 'vault kv list kv/platform 실패(참고용 · 판정에는 쓰지 않는다)' } else { "LIST kv/platform: $(($lsRaw -join ' ') -replace '\s+', ' ')" }
    $global:LASTEXITCODE = 0
    & $stop 'E) 위 OK/SKIP/META 줄을 런북 §4 기록용으로 확인했으면 진행한다(라이브 Secret·PM 은 건드리지 않는다)'
  }
  finally {
    # 정리(자격·변수·클립보드)를 먼저 한다 — Ctrl+C 중지 중에도 여기까지는 실행된다.
    Remove-Variable v1, v2, ak, sk, pol, st, sealRaw, pd, pRaw, pk, md, mdRaw, lsRaw, nodes, can, nm, ansC, ansD, ch, x, s -ErrorAction SilentlyContinue
    if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
    if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
    try { Set-Clipboard -Value ' ' } catch { }
    # 이 아래는 Write-Host/Write-Warning 만 쓴다 — Ctrl+C 중지 중에는 첫 "성공 스트림" 출력문에서 finally 가 끊긴다.
    Write-Host ''
    Write-Host '--- 시드 결과 요약(런북 §4에 그대로 기록) ---'
    foreach ($e in $seedLog.GetEnumerator()) { Write-Host ('{0,-46} {1}' -f $e.Key, $e.Value) }
    if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
    $wrote = @($seedLog.Values | Where-Object { ([string]$_).StartsWith('완료', [StringComparison]::Ordinal) -or ([string]$_).StartsWith('기록됨', [StringComparison]::Ordinal) })
    if ($wrote.Count -gt 0) { Write-Host "이 실행이 kv 에 새로 쓴 경로: $($wrote.Count) 건 — 위 요약을 그대로 옮겨 적는다." }
    else { Write-Host '이 실행은 kv 에 아무것도 새로 쓰지 않았다(위 요약에 완료·기록됨 항목이 없다).' }
    Write-Host '창 종료 체크리스트(런북 §0): 창 C port-forward 종료 · cloudflared access 캐시 토큰 삭제'
  }
}
