# ===== T045 DR1 kv 정리 블록 v2 — 통째로 붙여 넣어도 안전(창 D) =====
# DR1 드릴 뒤 `kv/platform/test/t045-probe` 를 메타데이터째 지운다. root 토큰을 한 번 더 입력한다(창 C 의 port-forward 는 유지).
# 먼저 K8s 쪽 드릴 객체가 없어진 것을 확인한다 — 살아 있는 ES 의 원본을 지우면 그 ES 가 계속 SecretSyncedError 가 되어 하네스 eso-2 를 깨뜨린다.
# 사전(블록 밖): 클립보드 기록 끄기 · PSReadLine 로드 확인.
# 붙여넣기 안전: 전체가 `& { … }` 한 문이고 빈 줄이 없으며 파일 끝은 `}` + 개행 1개뿐이다. 정지점은 버퍼를 비우고 단어를 요구한다.
& {
  $ErrorActionPreference = 'Stop'
  $kvPath = 'kv/platform/test/t045-probe'
  try {
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
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
    # 0) 창 전제
    $ch = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시' }
    # 0b) K8s 쪽 드릴 잔존물 확인 — root 토큰을 꺼내기 전에 한다
    $nodes = @(kubectl get nodes -o name "--request-timeout=15s")
    if ($LASTEXITCODE -ne 0 -or -not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {
      throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — 잔존 ES 여부를 확인할 수 없다. root 토큰은 아직 입력하지 않았다" }
    $k8sLeft = kubectl -n external-secrets get externalsecret,secret t045-probe --ignore-not-found -o name "--request-timeout=15s"
    if ($LASTEXITCODE -ne 0) { throw 'DR1 잔존물 조회 실패 — kv 를 지우기 전에 K8s 쪽 정리를 확인해야 한다(root 토큰 미입력)' }
    if ($k8sLeft) { throw "DR1 K8s 객체가 아직 있다($k8sLeft) — DR1 블록의 6) 정리를 먼저 끝낸다(kv 를 먼저 지우면 ES 가 오류 상태로 남는다)" }
    # 0c) Vault 도달
    $env:VAULT_ADDR = 'http://127.0.0.1:18200'
    $sealRaw = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]($sealRaw -join ''))) { throw 'Vault 도달 실패(빈 응답) — 창 C port-forward 확인' }
    $st = ($sealRaw -join "`n") | ConvertFrom-Json -DateKind String
    if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 미초기화 또는 sealed — 창 C·unseal 상태 확인' }
    # 1) root 토큰
    $env:VAULT_TOKEN = (& $readSecret 'root 토큰(PM에서 복사 · 화면에 남지 않음)').Trim()
    if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
    $pol = (((vault token lookup "-format=json") -join "`n") | ConvertFrom-Json -DateKind String).data.policies
    if ($LASTEXITCODE -ne 0 -or -not (@($pol) | Where-Object { [string]::Equals([string]$_, 'root', [StringComparison]::Ordinal) })) { throw 'root 토큰 확인 실패 — 중단' }
    # 2) 삭제(이미 없으면 SKIP — 재실행 안전)
    if ([string]::Equals((& $state $kvPath), 'absent', [StringComparison]::Ordinal)) {
      "SKIP $kvPath — 경로가 이미 없다(지울 것이 없음)" }
    else {
      & $stop "2) $kvPath 를 메타데이터째 삭제한다(드릴 전용 · 비밀 아님)"
      vault kv metadata delete $kvPath
      if ($LASTEXITCODE -ne 0) { throw "kv 경로 삭제 실패 — 수동 확인: $kvPath" }
      if (-not [string]::Equals((& $state $kvPath), 'absent', [StringComparison]::Ordinal)) { throw "경로가 아직 있다 — 삭제가 되지 않았다: $kvPath" }
      "OK kv 드릴 경로 삭제: $kvPath" }
  }
  finally {
    Remove-Variable pol, st, sealRaw, nodes, k8sLeft, ch -ErrorAction SilentlyContinue
    if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
    if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
    try { Set-Clipboard -Value ' ' } catch { }
    # 아래는 Write-Host 만 — Ctrl+C 중지 중에는 첫 "성공 스트림" 출력문에서 finally 가 끊긴다.
    Write-Host '창 종료 체크리스트(런북 §0): 창 C port-forward 종료 · cloudflared access 캐시 토큰 삭제'
  }
}
