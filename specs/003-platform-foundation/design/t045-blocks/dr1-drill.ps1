# ===== T045 DR1 드릴 블록 v2 — 통째로 붙여 넣어도 안전(창 D) =====
# 원칙: (a) 상태를 바꾸는 단계마다 정지점(단어 입력 · 빈 Enter 로는 통과하지 않는다)
#       (b) 모든 취득·적용·삭제가 fail-closed(exit 확인 뒤 판정 · 조회 실패를 "없음"으로 읽지 않는다)
#       (c) 시작 시 이전 잔존물이 있으면 중단(잔존물 위에서는 "첫 인수" 실측이 아니다)
#       (d) finally 가 잔존물을 알리고 정리 명령을 출력한다(잔존 ES 는 하네스 eso-2 에도 영향)
# 이 블록은 비밀을 다루지 않는다(드릴 값은 비밀이 아니다). Vault 토큰도 쓰지 않는다.
# 붙여넣기 안전: 전체가 `& { … }` 한 문이고 빈 줄이 없으며 파일 끝은 `}` + 개행 1개뿐이다.
# ES/Secret 매니페스트는 YAML 히어스트링이 아니라 JSON 으로 만든다 — 붙여넣기에서 들여쓰기가 흐트러져도 깨지지 않는다.
& {
  $ErrorActionPreference = 'Stop'
  $NS = 'external-secrets'
  $N = 't045-probe'
  try {
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
    # 0a) 클러스터 확인 — 다른 클러스터에 드릴 객체를 만들지 않는다
    $nodes = @(kubectl get nodes -o name "--request-timeout=15s")
    if ($LASTEXITCODE -ne 0 -or -not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {
      throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — admin kubeconfig 를 지정하고 다시" }
    # 0b) 이전 실행의 잔존물 검사
    $pre0 = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name "--request-timeout=15s"
    if ($LASTEXITCODE -ne 0) { throw '잔존물 조회 실패 — 판정 불가(접속 확인 후 다시)' }
    if ($pre0) { throw "이전 드릴 잔존물이 있다($pre0) — 6) 정리 두 줄을 먼저 실행하고 다시" }
    # 드릴 매니페스트(2)와 5)에서 재사용한다 — 다른 창에서 손으로 재구성하지 않는다)
    $esJson = (@{
      apiVersion = 'external-secrets.io/v1'
      kind = 'ExternalSecret'
      metadata = @{ name = $N; namespace = $NS }
      spec = @{
        refreshPolicy = 'Periodic'
        refreshInterval = '5m'
        secretStoreRef = @{ kind = 'ClusterSecretStore'; name = 'vault-platform' }
        target = @{ name = $N; creationPolicy = 'Orphan'; deletionPolicy = 'Retain'; template = @{ metadata = @{} } }
        data = @(, @{ secretKey = 'value'; remoteRef = @{ key = 'platform/test/t045-probe'; property = 'value' } })
      } } | ConvertTo-Json -Compress -Depth 10)
    # 수동 Secret 은 키가 2개다 — Orphan 인수가 ES 에 없는 키(extra)를 지우는지 양성 증거로 본다(G3·G4 의 ES 는 라이브 키를 전부 열거해야 한다).
    $secJson = (@{
      apiVersion = 'v1'; kind = 'Secret'; type = 'Opaque'
      metadata = @{ name = $N; namespace = $NS }
      stringData = @{ value = 't045-drill-not-a-secret'; extra = 't045-extra-key' } } | ConvertTo-Json -Compress -Depth 10)
    # SecretSynced 까지 최대 120초 폴링(5초 간격). 고정 sleep 을 쓰지 않는다.
    $waitSynced = {
      $c = ''
      $deadline = (Get-Date).AddSeconds(120)
      while ((Get-Date) -lt $deadline) {
        $c = kubectl -n $NS get externalsecret $N -o "jsonpath={.status.conditions[?(@.type=='Ready')].reason}" "--request-timeout=10s"
        if ($LASTEXITCODE -eq 0 -and [string]::Equals([string]$c, 'SecretSynced', [StringComparison]::Ordinal)) { return }
        Start-Sleep -Seconds 5 }
      throw "드릴 ES 가 120초 안에 SecretSynced 가 되지 않았다(마지막 reason=$c) — 원인 확인(store·권한·경로)" }
    # ---------- 1) 수동 Secret 생성(비밀 아님) → 인수 전 UID·값 기록 ----------
    & $stop "1) ns $NS 에 드릴용 Secret $N 을 만든다(비밀 아님 · 키 2개: value, extra)"
    $secJson | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 생성 실패' }
    $uid0 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}" "--request-timeout=10s"
    $h0 = kubectl -n $NS get secret $N -o "jsonpath={.data.value}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$uid0) -or [string]::IsNullOrWhiteSpace([string]$h0)) { throw '인수 전 상태 취득 실패' }
    $ks0 = kubectl -n $NS get secret $N -o 'go-template={{range $k, $v := .data}}{{$k}} {{end}}' "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw '인수 전 키 목록 취득 실패' }
    "인수 전 data 키: $ks0"
    # ---------- 2) ES 적용(Orphan/Retain/Periodic 5m) ----------
    & $stop '2) 이제 드릴 ES 를 적용한다(Orphan / Retain / Periodic 5m)'
    $esJson | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) { throw '드릴 ES 적용 실패 — admission(webhook) 또는 store 문제' }
    & $waitSynced
    # ---------- 3) 인수 실측: UID 불변 · 값 불변 · ownerRef 부재 + ESO 가 실제로 썼다는 양성 증거 ----------
    $uid1 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}" "--request-timeout=10s"
    $h1 = kubectl -n $NS get secret $N -o "jsonpath={.data.value}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$uid1) -or [string]::IsNullOrWhiteSpace([string]$h1)) { throw '인수 후 상태 취득 실패 — 판정 불가' }
    $own = kubectl -n $NS get secret $N -o "jsonpath={.metadata.ownerReferences}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
    $mg = kubectl -n $NS get secret $N -o "jsonpath={.metadata.labels['reconcile\.external-secrets\.io/managed']}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw 'managed 라벨 조회 실패 — 판정 불가' }
    if (-not [string]::Equals($uid0, [string]$uid1, [StringComparison]::Ordinal)) { throw '드릴: UID 가 바뀌었다 = 제자리 인수가 아니라 재생성이다 — G3/G4 게이트 문면을 다시 짠다' }
    if (-not [string]::Equals($h0, [string]$h1, [StringComparison]::Ordinal)) { throw '드릴: 값이 바뀌었다 — kv 값과 수동 값이 달랐다는 뜻' }
    if (-not [string]::IsNullOrWhiteSpace([string]$own)) { throw '드릴: ownerReferences 가 붙었다 — Orphan 이 기대대로 동작하지 않는다. G4 를 열지 않는다' }
    # 음성 증거(안 바뀜)만으로는 "ESO 가 이 Secret 에 손대지 않았다"와 구분되지 않는다 — managed 라벨로 양성 증거를 요구한다.
    if (-not [string]::Equals([string]$mg, 'true', [StringComparison]::Ordinal)) { throw '드릴: SecretSynced 인데 managed 라벨이 없다 — ESO 가 이 Secret 을 실제로 쓰지 않았다(값 불변이 자명한 통과였다)' }
    $ks1 = kubectl -n $NS get secret $N -o 'go-template={{range $k, $v := .data}}{{$k}} {{end}}' "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw '인수 후 키 목록 취득 실패' }
    "인수 후 data 키: $ks1  (extra 가 사라졌으면 Orphan 인수는 ES 에 없는 키를 지운다 → G3/G4 의 ES 는 라이브 Secret 의 키를 전부 열거해야 한다)"
    'OK 드릴 인수: UID 불변 · 값 불변 · ownerRef 없음 · managed 라벨 확인'
    # ---------- 4) ES 삭제 후 Secret 잔존 확인 ----------
    & $stop '4) ES 를 삭제하고 Secret 이 남는지 본다(Retain)'
    kubectl -n $NS delete externalsecret $N "--timeout=90s"
    if ($LASTEXITCODE -ne 0) { throw 'ES 삭제 실패 또는 90초 초과(webhook 이 DELETE 를 거부했나 · finalizer 대기?) — 잔존 판정 불가' }
    Start-Sleep -Seconds 15
    $left = kubectl -n $NS get externalsecret $N --ignore-not-found -o name "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw 'ES 부재 확인 실패 — 판정 불가' }
    if ($left) { throw "ES 가 아직 있다($left) — 삭제가 실제로 되지 않았다" }
    $uid2 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}" "--request-timeout=10s"
    $h2 = kubectl -n $NS get secret $N -o "jsonpath={.data.value}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$uid2)) { throw '드릴: ES 삭제 후 Secret 이 사라졌다 — Orphan 전제 붕괴' }
    if (-not [string]::Equals($uid0, [string]$uid2, [StringComparison]::Ordinal)) { throw '드릴: Secret 이 재생성됐다(UID 변경) — Orphan 전제 붕괴' }
    if (-not [string]::Equals($h0, [string]$h2, [StringComparison]::Ordinal)) { throw '드릴: ES 삭제 후 값이 바뀌었다 — 원인 확인' }
    'OK ES 삭제 후에도 Secret 잔존(같은 UID · 같은 값)'
    # ---------- 5) VD-20: Secret 을 지우고 재생성 시점을 잰다 ----------
    # Orphan 에서는 isSecretValid 가 항상 true 라 삭제 이벤트로는 재생성되지 않는다 — 다음 "주기" refresh 를 기다린다(5분 안팎이 정상).
    & $stop '5) ES 를 다시 적용하고 Secret 을 삭제해 재생성 시점을 잰다(VD-20 · 최대 7분 기다린다)'
    $esJson | kubectl apply -f -
    if ($LASTEXITCODE -ne 0) { throw '드릴 ES 재적용 실패' }
    & $waitSynced
    $rt = kubectl -n $NS get externalsecret $N -o "jsonpath={.status.refreshTime}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$rt)) { throw 'refreshTime 취득 실패 — VD-20 기준점 없음' }
    $t0 = Get-Date
    kubectl -n $NS delete secret $N "--timeout=90s"
    if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 삭제 실패 — VD-20 측정 불가' }
    'Secret 삭제됨 — 재생성을 최대 420초 기다린다(Orphan 은 다음 주기 refresh 에서만 다시 만든다 → 5분 안팎이 정상. 멈춘 것이 아니다)'
    $back = $null
    $tick = 0
    while ((Get-Date) -lt $t0.AddSeconds(420)) {
      $back = kubectl -n $NS get secret $N --ignore-not-found -o name "--request-timeout=10s"
      if ($LASTEXITCODE -eq 0 -and $back) { break }
      $back = $null
      $tick = $tick + 1
      if (($tick % 6) -eq 0) { "  … $([int]((Get-Date) - $t0).TotalSeconds) 초 경과(대기 중)" }
      Start-Sleep -Seconds 5 }
    if (-not $back) { throw 'VD-20 = 미재생성(420초) — 런북에 그대로 기록하고 G3 전에 원인을 확인한다' }
    $ct = kubectl -n $NS get secret $N -o "jsonpath={.metadata.creationTimestamp}" "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0) { throw '재생성 Secret 의 creationTimestamp 취득 실패 — 판정 근거 부족' }
    "VD-20: 삭제 후 약 $([int]((Get-Date) - $t0).TotalSeconds) 초 · 직전 refreshTime=$rt · 새 creationTimestamp=$ct (차가 약 5분이면 주기 refresh, 수 초면 즉시)"
    # ---------- 6) 정리(전부 삭제 · 부재까지 확인) ----------
    & $stop '6) 드릴 객체를 전부 지운다(ES 먼저)'
    kubectl -n $NS delete externalsecret $N --ignore-not-found "--timeout=90s"
    if ($LASTEXITCODE -ne 0) { throw '정리: ES 삭제 실패 — 잔존. 접속·webhook 확인 뒤 finally 가 출력한 두 줄로 다시 지운다' }
    kubectl -n $NS delete secret $N --ignore-not-found "--timeout=90s"
    if ($LASTEXITCODE -ne 0) { throw '정리: Secret 삭제 실패 — 잔존' }
    $chk = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name "--request-timeout=10s"
    if ($LASTEXITCODE -ne 0 -or $chk) { throw "정리 확인 실패(조회 exit=$LASTEXITCODE · 잔존=$chk) — kv 정리 블록으로 가지 않는다" }
    'K8s 객체 정리 완료(부재까지 확인) — kv 경로는 "kv 정리 블록"에서 지운다(root 토큰을 한 번 더 입력한다)'
  }
  finally {
    # 조회 실패를 "잔존물 없음"으로 읽지 않는다 — 터널 끊김·토큰 만료가 드릴 중 throw 의 가장 흔한 원인이다.
    $leftOver = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name "--request-timeout=10s" 2>$null
    $rc = $LASTEXITCODE; $global:LASTEXITCODE = 0
    # 아래는 Write-Host/Write-Warning 만 — Ctrl+C 중지 중에는 첫 "성공 스트림" 출력문에서 finally 가 끊긴다.
    if ($rc -ne 0) { Write-Warning "잔존물 조회 실패(exit=$rc) — '잔존물 없음'이 아니다. 접속 복구 뒤 아래 두 줄로 확인·정리하고, 그 전에는 kv 정리 블록으로 가지 않는다" }
    elseif ($leftOver) { Write-Warning "드릴 잔존물이 남아 있다($leftOver) — 아래 두 줄을 실행해 정리한다(잔존 ES 는 하네스 eso-2 에도 영향)" }
    if ($rc -ne 0 -or $leftOver) {
      Write-Host "kubectl -n $NS delete externalsecret $N --ignore-not-found `"--timeout=90s`""
      Write-Host "kubectl -n $NS delete secret $N --ignore-not-found `"--timeout=90s`"" }
    Remove-Variable pre0, esJson, secJson, waitSynced, uid0, uid1, uid2, h0, h1, h2, ks0, ks1, mg, own, left, back, t0, tick, rt, ct, chk, leftOver, rc, nodes -ErrorAction SilentlyContinue
  }
}
