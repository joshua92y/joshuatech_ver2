# ===== T045 DR1 드릴 블록 — 통째로 붙여 넣어도 안전 =====
# 원칙: (a) 사람 동작마다 Read-Host (b) 모든 취득·적용·삭제가 fail-closed(exit 확인 뒤 판정)
#       (c) 시작 시 이전 잔존물이 있으면 중단(잔존물 위에서는 "첫 인수" 실측이 아니다 — managed 라벨·data-hash가 이미 있다)
#       (d) finally 가 잔존물을 알리고 정리 명령을 출력한다(잔존 ES 는 하네스 eso-2 에도 영향)
$ErrorActionPreference = 'Stop'
$NS = 'external-secrets'; $N = 't045-probe'
try {
  # 0) 이전 실행의 잔존물 검사
  $pre0 = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name
  if ($LASTEXITCODE -ne 0) { throw '잔존물 조회 실패 — 판정 불가' }
  if ($pre0) { throw "이전 드릴 잔존물이 있다($pre0) — 6) 정리 두 줄을 먼저 실행하고 다시" }

  # ES YAML 은 변수에 담아 2)와 5)에서 재사용한다(다른 창에서 손으로 재구성하지 않는다)
  $esYaml = @"
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: $N, namespace: $NS }
spec:
  refreshPolicy: Periodic
  refreshInterval: 5m
  secretStoreRef: { kind: ClusterSecretStore, name: vault-platform }
  target:
    name: $N
    creationPolicy: Orphan
    deletionPolicy: Retain
    template:
      metadata: {}
  data:
    - secretKey: value
      remoteRef: { key: platform/test/t045-probe, property: value }
"@
  # SecretSynced 까지 최대 120초 폴링(5초 간격). 고정 sleep 을 쓰지 않는다.
  $waitSynced = {
    $c = ''
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $c = kubectl -n $NS get externalsecret $N -o "jsonpath={.status.conditions[?(@.type=='Ready')].reason}"
      if ($LASTEXITCODE -eq 0 -and [string]::Equals([string]$c, 'SecretSynced', [StringComparison]::Ordinal)) { return }
      Start-Sleep -Seconds 5
    }
    throw "드릴 ES 가 120초 안에 SecretSynced 가 되지 않았다(마지막 reason=$c) — 원인 확인(store·권한·경로)"
  }

  # 1) 수동 Secret 생성(비밀 아님) → 인수 전 UID·값 기록
  (@{apiVersion='v1';kind='Secret';type='Opaque';metadata=@{name=$N;namespace=$NS};stringData=@{value='t045-drill-not-a-secret'}} | ConvertTo-Json -Compress -Depth 5) | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 생성 실패' }
  $uid0 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h0   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid0) -or [string]::IsNullOrWhiteSpace($h0)) { throw '인수 전 상태 취득 실패' }

  Read-Host '2) 이제 드릴 ES 를 적용한다(Orphan/Retain/Periodic 5m). Enter'
  $esYaml | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 ES 적용 실패 — admission(webhook) 또는 store 문제' }
  & $waitSynced

  # 3) 인수 실측: UID 불변 · 값 불변 · ownerRef 부재
  $uid1 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h1   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid1) -or [string]::IsNullOrWhiteSpace($h1)) { throw '인수 후 상태 취득 실패 — 판정 불가' }
  $own = kubectl -n $NS get secret $N -o "jsonpath={.metadata.ownerReferences}"
  if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
  if (-not [string]::Equals($uid0, $uid1, [StringComparison]::Ordinal)) { throw '드릴: UID가 바뀌었다 = 제자리 인수가 아니라 재생성이다 — G3/G4 게이트 문면을 다시 짠다' }
  if (-not [string]::Equals($h0,   $h1,   [StringComparison]::Ordinal)) { throw '드릴: 값이 바뀌었다 — kv 값과 수동 값이 달랐다는 뜻' }
  if (-not [string]::IsNullOrWhiteSpace($own)) { throw '드릴: ownerReferences 가 붙었다 — Orphan이 기대대로 동작하지 않는다. G4를 열지 않는다' }
  'OK 드릴 인수: UID 불변 · 값 불변 · ownerRef 없음'

  Read-Host '4) ES 삭제 후 Secret 잔존 확인. Enter'
  kubectl -n $NS delete externalsecret $N
  if ($LASTEXITCODE -ne 0) { throw 'ES 삭제 실패(webhook 이 DELETE 를 거부했나?) — 잔존 판정 불가' }
  Start-Sleep -Seconds 15    # 비동기 GC 가 있었다면 이 사이에 드러난다(삭제 직후 즉시 조회는 자명하게 통과한다)
  $left = kubectl -n $NS get externalsecret $N --ignore-not-found -o name
  if ($LASTEXITCODE -ne 0) { throw 'ES 부재 확인 실패 — 판정 불가' }
  if ($left) { throw "ES 가 아직 있다($left) — 삭제가 실제로 되지 않았다" }
  $uid2 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h2   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid2)) { throw '드릴: ES 삭제 후 Secret 이 사라졌다 — Orphan 전제 붕괴' }
  if (-not [string]::Equals($uid0, $uid2, [StringComparison]::Ordinal)) { throw '드릴: Secret 이 재생성됐다(UID 변경) — Orphan 전제 붕괴' }
  if (-not [string]::Equals($h0,   $h2,   [StringComparison]::Ordinal)) { throw '드릴: ES 삭제 후 값이 바뀌었다 — 원인 확인' }
  'OK ES 삭제 후에도 Secret 잔존(같은 UID · 같은 값)'

  Read-Host '5) ES 를 다시 적용하고 Secret 을 삭제해 재생성 시점을 잰다(VD-20). Enter'
  $esYaml | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 ES 재적용 실패' }
  & $waitSynced
  $t0 = Get-Date
  kubectl -n $NS delete secret $N
  if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 삭제 실패 — VD-20 측정 불가' }
  $back = $null
  while ((Get-Date) -lt $t0.AddSeconds(420)) {
    $back = kubectl -n $NS get secret $N --ignore-not-found -o name
    if ($LASTEXITCODE -eq 0 -and $back) { break }
    $back = $null
    Start-Sleep -Seconds 5
  }
  if (-not $back) { throw 'VD-20 = 미재생성(420초) — 런북에 그대로 기록하고 G3 전에 원인을 확인한다' }
  "VD-20: Secret 재생성까지 약 $([int]((Get-Date) - $t0).TotalSeconds) 초(폴링 간격 5초) — 즉시인지 ≤5분 주기인지의 판정 근거"

  Read-Host '6) 정리(전부 삭제). Enter'
  kubectl -n $NS delete externalsecret $N --ignore-not-found
  kubectl -n $NS delete secret $N --ignore-not-found
  'K8s 객체 정리 완료 — kv 경로는 아래 "kv 정리 블록"에서 지운다(root 토큰을 한 번 더 입력한다)'
}
finally {
  $leftOver = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name 2>$null
  $global:LASTEXITCODE = 0
  if ($leftOver) {
    Write-Warning "드릴 잔존물이 남아 있다($leftOver) — 아래 두 줄을 실행해 정리한다(잔존 ES 는 하네스 eso-2 에도 영향)"
    "kubectl -n $NS delete externalsecret $N --ignore-not-found"
    "kubectl -n $NS delete secret $N --ignore-not-found"
  }
  Remove-Variable pre0, esYaml, waitSynced, uid0, uid1, uid2, h0, h1, h2, own, left, back, t0, leftOver -ErrorAction SilentlyContinue
}
