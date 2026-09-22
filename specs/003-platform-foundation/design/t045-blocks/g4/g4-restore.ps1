# ===== T045 G4 복구 블록 — 덮인 터널 토큰 Secret 을 PM 원본으로 되돌린다(창 D) =====
# 언제 쓰나: g4-adopt.ps1 이 "값이 바뀌었다"로 중단했고, **R1(kv 값 정정)으로는 못 고치는 상황**일 때만.
#   R1 이 1순위다 — kv 를 고치면 ESO 가 5분 안에 라이브를 알아서 되돌린다(kv-correct.ps1). 이 블록은 R2 의 마지막 단계다.
#   오경보 확인에도 쓴다: 2) 의 해시 대조가 SKIP(이미 기준값과 같다)이면 값은 옳다 — 그때는 토큰을 묻지 않고 아무것도 쓰지 않는다.
# ⚠ 순서가 전부다. ES 가 살아 있으면 **이 블록이 쓴 값을 ESO 가 ≤5분 안에 다시 덮는다.** R2 의 정식 순서:
#   ① revert PR 머지 → ② platform-secrets 의 status.sync.revision 이 revert 커밋이고 해당 ExternalSecret 이 requiresPruning 인지 확인
#      (이 확인 없이 지우면 selfHeal 이 ES 를 곧바로 되살린다) → ③ kubectl -n cloudflared delete externalsecret cloudflared-tunnel
#      (Orphan 이라 Secret 은 남는다 · 평시 금지 · 이 비상 시에만) → ④ **이 블록**으로 값 복구 → ⑤ 파드는 **1개만**, 드릴 규칙 그대로 교체한다.
#   ⚠ ③ 의 전제: ESO 2.10.0 은 **모든 ES 에 finalizer 를 붙인다** → delete 는 ESO 컨트롤러가 Running 이고 webhook 이 Ready 일 때만 끝난다.
#      "덮어쓰기를 멈추려고" 컨트롤러를 먼저 scale 0 하면 delete 가 Terminating 에서 멈춘 것처럼 보인다(Retain 이라 Secret 은 안전하지만 진행이 막힌다).
#      webhook `externalsecret-validate` 는 DELETE·UPDATE 를 failurePolicy Fail 로 가로챈다 — 죽어 있으면 delete 도 finalizer 제거도 거부된다.
#      그때만: `kubectl delete validatingwebhookconfiguration externalsecret-validate` 뒤 재시도(selfHeal 이 곧 되살린다).
#   ⚠ R2 뒤에도 Secret 의 `reconcile.external-secrets.io/managed` 라벨은 남는다 — 재인수 때 g4-adopt 는 항상 1R) resume 경로로 간다
#      (ES 가 없으면 그 2) 가 "인수 해제 상태 — 재인수라면 지금 머지" 분기로 갈린다). 라벨을 지우는 것은 이 블록이 SKIP(해시 일치)을 낸 뒤에만 한다.
#   ES 가 아직 있는 채로 실행하면 블록이 그 사실을 감지해 정지 단어를 `temporary` 로 바꾼다(≤5분짜리 임시 조치임을 아는 사람만 통과).
#      `temporary` 의 쓸모: ES 를 아직 멈추지 못한 동안에도 옳은 값을 ≤5분간 놓아 **컨테이너 재시작 노출 창**을 줄인다(R1·R2 가 끝날 때까지 되풀이).
# ⚠ 실행 중 컨테이너는 옛 값을 들고 있다 — 그러나 그 안전망은 **컨테이너가 재시작되지 않는 동안만** 유효하다.
#   env(secretKeyRef)는 파드가 아니라 **컨테이너가 시작할 때마다** 다시 읽힌다: liveness(/ready 60초 연속 실패)·OOMKill(256Mi)·
#   노드 재부팅·drain 이면 같은 파드 이름·같은 UID 로 restartCount 만 오르며 틀린 값을 읽는다. 그러니 복구를 미루지 않는다.
#   그래도 **먼저 파드를 재시작하지는 않는다.** 복구가 끝나고 판정이 PASS 인 뒤에야 1개만 교체한다.
# 실행: **파일 실행만** — `& "<이 파일 경로>"`. **stdin 실행(`pwsh -Command -` · 파이프 주입)은 지원하지 않는다**
#   (정지점의 Read-Host 가 스크립트 본문을 답으로 읽거나 -AsSecureString 이 콘솔을 직접 열어 영영 기다린다).
#   붙여넣기는 이 크기로 검증하지 않았다 — 쓰지 않는다.
#   ⚠ 이 블록도 kubectl = 터널이다. **이미 잠긴 상태(R3)에서는 쓸 수 없다** — 그때는 g4-adopt 의 복구 안내 4번(노드 셸 bash 절차)을 따른다.
#   필요한 것: 이전 실행이 출력한 **preHash·preUid**(비밀 아님)와 **PM 의 터널 토큰 원본**(g4-adopt 1P 에서 해시로 검증해 둔 값).
# 사전(블록 밖): 설정 > 시스템 > 클립보드 > **클립보드 기록 끄기**(켜져 있으면 첫 검사에서 멈춘다) · 창 D 의 admin KUBECONFIG.
# 정지점에서 입력할 단어:
#   3) 쓰기 승인 — ES 가 없고 Git 에도 없음이 **확인되면** `restore`, ES 가 살아 있거나 Git 에 남아 있거나 **그 확인 자체가 안 되면** `temporary`.
#   3u) 현재 UID 가 preUid 와 다를 때만 나온다 — `newuid`.
# 토큰은 -AsSecureString 으로만 받고, 평문은 base64 로 바꿔 stdin 으로만 넘긴다(argv·화면·파일·클립보드에 남기지 않는다).
# 판정은 해시뿐이다: PM 값의 base64 를 SHA-256 한 값이 preHash 와 **정확히 같을 때만** 쓴다(다르면 아무것도 쓰지 않는다).
& {
  $ErrorActionPreference = 'Stop'
  # $PSNativeCommandUseErrorActionPreference 가 $true 면 비0 종료가 내 검사보다 먼저 예외를 던진다(문면·재시도 무력화).
  # 이 블록 안에서만 끈다(세션으로 새지 않음 · 실측). 모든 호출이 $LASTEXITCODE 를 직접 보고 fail-closed 로 판정한다.
  $PSNativeCommandUseErrorActionPreference = $false
  $NS = 'cloudflared'
  $SEC = 'cloudflared-tunnel'
  $ESN = 'cloudflared-tunnel'
  $KEY = 'TUNNEL_TOKEN'
  $OWNER = 'platform-secrets'
  # 양성 대조 행 — platform-secrets 가 선언하는 또 하나의 ExternalSecret. 응답에 이 행이 없으면 "조회가 된 것"이 아니다.
  $CTRL = 'cert-manager/cloudflare-dns-token='
  $log = [ordered]@{}
  foreach ($k in '0) 전제', '1) 기준값 입력', '2) ES 상태·현재 Secret', '3) 쓰기 승인', '4) Secret 복구', '5) 복구 확인') {
    $log[$k] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  $changes = [System.Collections.ArrayList]::new()
  $wrote = $false
  $attempted = $false
  # 5) 되읽기까지 통과했는가. 쓰기 성공($wrote)과 확인 성공($verified)은 다른 사실이다 —
  # apply 뒤에 ESO 가 곧바로 다시 덮으면 $wrote 는 참이지만 확인은 실패다. 요약이 그 둘을 섞어 말하지 않는다.
  $verified = $false
  try {
    $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $txt = { param($o) [string]::Join("`n", @(@($o) | ForEach-Object { [string]$_ })) }
    # Read-Host 가 $null 이면 stdin EOF 다(파이프·-NonInteractive) — "빈 입력"이 아니라 실행 방식이 틀렸다는 뜻이므로 그렇게 말한다.
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if ($null -eq $a) { throw '입력 스트림이 닫혔다(EOF) — 대화형 콘솔에서 파일로 실행한다(stdin 파이프·-NonInteractive 는 지원하지 않는다)' }
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
    $ask = { param($msg)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $v = Read-Host $msg
      if ($null -eq $v) { throw '입력 스트림이 닫혔다(EOF) — 대화형 콘솔에서 파일로 실행한다(stdin 파이프·-NonInteractive 는 지원하지 않는다)' }
      [string]$v }
    # 비밀 입력: 버퍼를 비우고 -AsSecureString 으로 받은 뒤 즉시 클립보드를 비운다(뒤의 평문 정지점에서 우클릭 붙여넣기 사고를 막는다).
    # 비우기가 실패하면 침묵하지 않는다 — 토큰이 클립보드에 남은 채로 진행하는 것이 가장 흔한 누출 경로다.
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 토큰이 클립보드에 남아 있을 수 있다. Win+V 로 확인하고 직접 비운다' }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력(또는 입력 스트림이 닫혔다 — 파일로 실행한다) — 중단: $prompt" }
      ($ss | ConvertFrom-SecureString -AsPlainText) }
    # 조회 전용 kubectl. $okRc — `kubectl auth can-i` 는 답이 "no" 면 exit 1 로 끝난다(cani.go). 그 1 을 조회 실패로 읽으면 맞춤 문면이 죽은 코드가 된다.
    # 첫머리의 동사 허용 목록 — 이 헬퍼로는 조회만 나간다(쓰기는 $kapply 하나뿐이라는 불변식을 런타임에서도 잠근다).
    $kq = { param($desc, [string[]]$ka, [int[]]$okRc = @(0))
      $vi = 0
      if ([string]::Equals([string]$ka[0], '-n', [StringComparison]::Ordinal)) { $vi = 2 }
      if (-not ([string]::Equals([string]$ka[$vi], 'get', [StringComparison]::Ordinal) -or [string]::Equals([string]$ka[$vi], 'auth', [StringComparison]::Ordinal))) {
        throw "조회 헬퍼에 조회가 아닌 동사가 들어왔다($([string]$ka[$vi])) — 블록 결함이다. 중단" }
      $n = 0
      while ($true) {
        $n = $n + 1
        $out = & kubectl @ka '--request-timeout=10s'
        $rc = $LASTEXITCODE
        $global:LASTEXITCODE = 0
        if ($okRc -contains $rc) { return $out }
        if ($n -ge 3) {
          $did = '이 실행은 아직 아무것도 쓰지 않았다'
          if ($changes.Count -gt 0) { $did = "⚠ 이 실행은 이미 쓰기를 시도했다(아래 요약) — 반영 여부는 이 블록을 다시 실행해 2) 의 해시 대조로 확인한다" }
          throw "kubectl 조회 실패(exit=$rc · 3회 시도): $desc — 판정 불가로 중단한다($did). 터널 순단일 수 있다 — cloudflared 파드를 재시작·삭제해서 고치려 하지 않는다" }
        Write-Warning "kubectl 조회 실패(exit=$rc): $desc — 5초 뒤 재시도($n/3)"
        Start-Sleep -Seconds 5 } }
    # ⚠ 클러스터를 바꾸는 유일한 헬퍼. 값은 stdin 으로만 들어간다(argv 금지). 소스 안 호출 지점은 1곳뿐이어야 한다(하네스 lint 가 인자까지 하나씩 대조한다).
    # 회계($changes·$log)를 **요청을 보내기 전에** 적는다 — apply 도중 Ctrl+C 로 멈춰도 요약이 "쓰지 않았다"고 거짓말하지 않는다.
    # `--request-timeout=30s` — 기본값은 무제한이라 터널이 멎으면 base64 토큰을 메모리에 든 채 무한 대기한다.
    # `--force-conflicts` — ESO 의 field manager 와 소유권이 갈린 필드를 비상 복구가 넘겨받기 위해서다(없으면 conflict 로 실패한다).
    $kapply = { param($json)
      [void]$changes.Add("kubectl apply --server-side secret/$SEC (-n $NS · .data.$KEY 1개 필드) — 요청 시도")
      $log['4) Secret 복구'] = 'apply 요청을 보냈다 — 결과 미확인'
      $out = $json | & kubectl 'apply' '--server-side' '--force-conflicts' '--field-manager=t045-restore' '--request-timeout=30s' '-f' '-'
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0) { throw "Secret 복구 apply 실패(exit=$rc) — 서버에 반영됐는지는 알 수 없다(응답만 잃었을 수 있다). 이 블록을 다시 실행하면 2) 가 현재 값 해시를 preHash 와 대조한다(SKIP = 이미 반영된 것). 그 전에는 파드를 건드리지 않는다" }
      [string]::Join(' ', @(@($out) | ForEach-Object { [string]$_ })) }
    # ---------- 0) 전제 ----------
    $ch = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
    if ($null -eq $ch) { throw '클립보드 기록 설정값을 읽지 못했다(값 없음) — Win+V 로 꺼짐을 확인하고 값을 0 으로 만든 뒤 다시' }
    if ($ch -ne 0) { throw '클립보드 기록이 켜져 있음 — 설정 > 시스템 > 클립보드에서 끄고 다시(토큰을 아직 입력하지 않았다)' }
    $nodes = @(& $kq '노드 목록' @('get', 'nodes', '-o', 'name'))
    if (-not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {
      throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — admin kubeconfig 를 지정하고 다시(토큰 미입력)" }
    $can = (& $txt (& $kq '권한 확인(patch secrets)' @('auth', 'can-i', 'patch', 'secrets', '-n', $NS) @(0, 1))).Trim()
    if (-not [string]::Equals($can, 'yes', [StringComparison]::Ordinal)) {
      throw "현재 kubeconfig 로는 $NS 의 Secret 을 쓸 수 없다(응답='$can' · 빈 응답이면 조회 자체가 실패했다는 뜻이다) — agent-view 가 아니라 admin kubeconfig 인지 확인한다(토큰 미입력)" }
    $log['0) 전제'] = '완료(클립보드 기록 꺼짐 · 클러스터·권한 확인)'
    # ---------- 1) 기준값(비밀 아님) ----------
    # `-match` 계열 연산자는 $Matches 에 매치 전체를 남긴다 — 여기서는 비밀이 아니지만, 토큰 검사와 같은 습관을 쓴다([regex]::IsMatch 는 $Matches 를 건드리지 않는다).
    $preHash = (& $ask 'preHash(g4-adopt 가 출력한 64자리 대문자 16진수) 붙여넣기').Trim()
    if (-not [regex]::IsMatch($preHash, '\A[0-9A-F]{64}\z')) { throw 'preHash 형식이 아니다(64자리 대문자 16진수) — 중단(토큰 미입력)' }
    $preUid = (& $ask 'preUid(g4-adopt 가 출력한 UID) 붙여넣기').Trim()
    if (-not [regex]::IsMatch($preUid, '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z')) { throw 'preUid 형식이 아니다(36자 UID) — 중단(토큰 미입력)' }
    $log['1) 기준값 입력'] = '완료(preHash · preUid)'
    # ---------- 2) ES 상태 · 현재 Secret ----------
    # "ES 가 지금 없다"는 "ESO 개입이 멈췄다"가 아니다. Git(platform-secrets)에 아직 선언돼 있으면 selfHeal 이 곧 되살리고 ESO 가 이 블록이 쓴 값을 다시 덮는다.
    $esNow = (& $txt (& $kq 'ES 존재 확인' @('-n', $NS, 'get', 'externalsecret', $ESN, '--ignore-not-found', '-o', 'name'))).Trim()
    # Argo 조회는 **최선 노력**이다 — 이것이 실패한다고 유일한 복구 수단을 막지는 않는다. 대신 확인하지 못한 상태를 더 신중한 단어(temporary)로 받는다.
    # 빈 응답을 "더 이상 선언하지 않는다"로 읽지 않는다: 항상 있어야 할 양성 대조 행($CTRL)이 보일 때만 "조회가 됐다"고 인정한다.
    $argoEs = ''
    $argoOk = $false
    try {
      $argoEs = & $txt (& $kq "$OWNER 가 선언한 ExternalSecret" @('-n', 'argocd', 'get', 'app', $OWNER, '-o', 'jsonpath={range .status.resources[?(@.kind=="ExternalSecret")]}{.namespace}/{.name}={.requiresPruning} {end}'))
      $argoOk = $argoEs.Contains($CTRL) } catch { $argoEs = ''; $argoOk = $false }
    $gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN=") -and -not $argoEs.Contains("$NS/$ESN=true"))
    $word = 'restore'
    if (-not [string]::IsNullOrWhiteSpace($esNow)) {
      Write-Warning "ES 가 아직 살아 있다($esNow) — 이 블록이 쓴 값을 ESO 가 다음 refresh(≤5분)에 다시 덮는다. 정식 순서는 revert PR → Argo 반영 확인 → delete externalsecret → 이 블록이다"
      $word = 'temporary' }
    elseif (-not $argoOk) {
      Write-Warning "Argo Application($OWNER)의 선언 목록을 확인하지 못했다(조회 실패이거나 양성 대조 행 '$CTRL' 이 없다 · 응답='$($argoEs.Trim())') — 빈 응답을 '더 이상 선언하지 않는다'로 읽지 않는다. 복구는 막지 않되 단어를 temporary 로 둔다(ES 가 selfHeal 로 되살아나면 ≤5분 뒤 다시 덮인다)"
      $word = 'temporary' }
    elseif ($gitLeft) {
      Write-Warning "ES 는 지금 없지만 Git($OWNER)에는 아직 선언돼 있다($argoEs) — selfHeal 이 곧 되살리고 ESO 가 이 블록이 쓴 값을 다시 덮는다. revert PR 머지·Argo 반영이 먼저다(R2 ①②)"
      $word = 'temporary' }
    else { "확인: $OWNER 는 이 ExternalSecret 을 더 이상 선언하지 않는다(status.resources 행: '$($argoEs.Trim())')" }
    # Secret 자체가 없으면 이 블록의 대상이 아니다 — $kq 의 일반 조회 실패 문면이 아니라 그 사실을 그대로 말한다.
    $secNow = (& $txt (& $kq 'Secret 존재 확인' @('-n', $NS, 'get', 'secret', $SEC, '--ignore-not-found', '-o', 'name'))).Trim()
    if ([string]::IsNullOrWhiteSpace($secNow)) {
      throw "$NS/$SEC 가 없다 — 이 블록은 **제자리 복구 전용**이다(신규 생성은 T039 의 수동 Secret 생성 절차다). 아무것도 쓰지 않았다" }
    $type = (& $txt (& $kq 'Secret type' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.type}'))).Trim()
    if ([string]::IsNullOrWhiteSpace($type)) { throw 'Secret 의 type 을 읽지 못했다 — 판정 불가(type 은 불변 필드라 apply 에 그대로 넣어야 한다)' }
    $curUid = (& $txt (& $kq '현재 UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
    if ([string]::IsNullOrWhiteSpace($curUid)) { throw '현재 UID 가 빈 응답이다 — 판정 불가로 중단(빈 응답을 "없음"으로 읽지 않는다)' }
    $curHash = & $sha (& $txt (& $kq '현재 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
    if ([string]::Equals($curHash, $preHash, [StringComparison]::Ordinal)) {
      $log['2) ES 상태·현재 Secret'] = '현재 값이 이미 preHash 와 같다'
      "SKIP 현재 Secret 의 값이 이미 기준값과 같다(해시 일치) — 쓰지 않는다. 복구가 끝났거나 애초에 덮이지 않았다(g4-adopt 의 판정이 오경보였다면 여기서 끝이다)"
      $log['3) 쓰기 승인'] = '불필요(SKIP)'
      $log['4) Secret 복구'] = '불필요(SKIP)'
      $log['5) 복구 확인'] = '불필요(SKIP)' }
    else {
      $log['2) ES 상태·현재 Secret'] = "값 불일치 확인(ES=$(if ([string]::IsNullOrWhiteSpace($esNow)) { '없음' } else { '살아 있음' }) · Git 선언=$(if ($gitLeft) { '남아 있음' } elseif ($argoOk) { '없음' } else { '확인 못 함' }) · type=$type)"
      if (-not [string]::Equals($curUid, $preUid, [StringComparison]::Ordinal)) {
        Write-Warning "현재 UID 가 preUid 와 다르다(현재 $curUid) — 그 사이에 Secret 이 지워지고 다시 만들어졌다는 뜻이다. 복구 자체는 유효하지만 원인을 알고 진행해야 한다"
        & $stop '3u) UID 가 달라진 것을 알고도 이 Secret 에 기준값을 쓰려면 newuid 를 입력한다' 'newuid' }
      # ---------- 3) 쓰기 승인(토큰을 꺼내기 **전에** 사람이 승인한다 — 평문이 사람 대기 구간을 건너지 않게 한다) ----------
      & $stop "3) $NS/$SEC 의 .$KEY 를 PM 원본으로 되돌린다. 실행 중 파드는 건드리지 않는다(값이 맞아도 재시작하지 않는다)" $word
      $log['3) 쓰기 승인'] = "완료(단어 $word)"
      # ---------- 4) PM 토큰 → 해시 검증 → 즉시 쓰기 ----------
      $tok = (& $readSecret 'PM 의 터널 토큰 원본(화면에 남지 않음)').Trim()
      if ($tok.Length -lt 32) { throw '토큰이 비정상적으로 짧다 — 아무것도 쓰지 않았다' }
      # `\A…\z` 를 쓴다 — `^…$` 는 문자열 끝 개행 1개를 통과시킨다(실측). 공백·개행·BOM·ZWSP 를 한 번에 잡는다.
      # ⚠ `-cnotmatch` 를 쓰면 매치 성공 시 $Matches[0] 에 **평문 토큰 전체**가 남아 Remove-Variable tok 로도 지워지지 않는다.
      #   [regex]::IsMatch 는 $Matches 를 건드리지 않는다(하네스 lint 가 tok/b64/new/payload 좌변의 -match 계열을 금지한다).
      if (-not [regex]::IsMatch($tok, '\A[\x21-\x7E]+\z')) { throw '토큰에 ASCII 인쇄 문자 밖의 문자(공백·개행·BOM·ZWSP 포함)가 있다 — 붙여넣기 손상이다. 아무것도 쓰지 않았다' }
      $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($tok))
      Remove-Variable tok
      if (-not [string]::Equals((& $sha $b64), $preHash, [StringComparison]::Ordinal)) {
        Remove-Variable b64
        throw 'PM 토큰의 해시가 preHash 와 다르다 — 이 값은 인수 전 라이브 값이 아니다. 아무것도 쓰지 않았다(PM 항목·회전 이력 확인, 또는 Cloudflare 대시보드·tofu -chdir=infra/cloudflare output -raw tunnel_token 에서 다시 꺼낸다)' }
      'OK PM 토큰 해시 = preHash — 이 값으로 되돌린다'
      $payload = (@{ apiVersion = 'v1'; kind = 'Secret'; type = $type; metadata = @{ name = $SEC; namespace = $NS }; data = @{ $KEY = $b64 } } | ConvertTo-Json -Compress -Depth 6)
      Remove-Variable b64
      $attempted = $true
      & $kapply $payload | Out-Null
      Remove-Variable payload
      $wrote = $true
      $log['4) Secret 복구'] = '완료(server-side apply · stdin)'
      # ---------- 5) 복구 확인 ----------
      $newHash = & $sha (& $txt (& $kq '복구 후 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
      if (-not [string]::Equals($newHash, $preHash, [StringComparison]::Ordinal)) {
        throw '복구 후 값이 여전히 preHash 와 다르다 — apply 가 반영되지 않았거나 ESO 가 이미 다시 덮었다. 파드를 건드리지 말고 ES 를 먼저 멈춘다(R2 ①∼③)' }
      $newUid = (& $txt (& $kq '복구 후 UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
      if (-not [string]::Equals($newUid, $curUid, [StringComparison]::Ordinal)) {
        throw "복구 과정에서 Secret 이 재생성됐다(UID $curUid → $newUid) — 제자리 수정이 아니다. 원인을 확인한다" }
      $verified = $true
      'OK 복구 완료: 값 해시 = preHash · UID 불변'
      $log['5) 복구 확인'] = 'PASS(값 해시 일치 · UID 불변)' }
  }
  finally {
    # 비밀이 스쳐 간 변수를 먼저 지우고 클립보드를 비운다. 그 뒤는 Write-Host/Write-Warning 만.
    Remove-Variable tok, b64, payload, out, raw -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다' }
    Write-Host ''
    Write-Host '--- G4 복구 단계 요약(런북 §3 기록용) ---'
    foreach ($e in $log.GetEnumerator()) { Write-Host ('{0,-22} {1}' -f $e.Key, $e.Value) }
    if ($changes.Count -eq 0) { Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).' }
    else {
      Write-Host "이 실행이 클러스터에 가한 변경: $($changes.Count) 건"
      foreach ($c in $changes) { Write-Host "  $c" } }
    if ($wrote) {
      if ($verified) {
        Write-Host '방금의 확인은 "지금 이 순간"의 값이다. 파드를 교체하기 전에 refresh 1주기(5분)가 지난 뒤 이 블록을 다시 실행해 SKIP(해시 일치)을 확인한다 — ES 가 되살아났다면 그때 드러난다.' }
      else {
        Write-Host '⚠ 값은 썼지만 5) 복구 확인이 끝나지 않았다 — 지금 값이 옳다고 가정하지 않는다(쓰기 성공과 확인 성공은 다른 사실이다).'
        Write-Host '   위 throw 문면이 원인이다. 파드를 건드리지 말고 원인을 먼저 없앤 뒤(대개 ES 정지) 이 블록을 다시 실행해 2) 의 해시 대조를 본다.' }
      Write-Host '다음: ES 가 아직 살아 있거나 Git 에 남아 있다면 이 값은 ≤5분 뒤 다시 덮인다 — kv 를 정정하거나(R1) ES 를 멈춘다(R2 ①∼③).'
      Write-Host '값이 옳다고 확인된 뒤에야 파드를 **1개만**, 드릴 규칙 그대로 교체한다(남은 1개가 Ready 인지 먼저 확인 · 두 번째 파드는 교체하지 않는다 · 전면 재시작 금지).'
      Write-Host 'field manager 로 t045-restore 가 남는다 — 이후 ESO 의 쓰기와 소유권이 갈릴 수 있으니 런북에 기록한다.' }
    elseif ($attempted -or $changes.Count -gt 0) {
      Write-Host '⚠ 쓰기를 시도했지만 결과를 확인하지 못했다 — "쓰지 않았다"고 가정하지 않는다. Secret 이 바뀌었을 수도, 그대로일 수도 있다.'
      Write-Host '   이 블록을 다시 실행해 2) 의 해시 대조로 확인한다(재실행 안전 · SKIP 이 나오면 반영된 것이다). 그 전에는 파드를 건드리지 않는다.' }
    else { Write-Host '이 실행은 Secret 에 아무것도 쓰지 않았다(SKIP · 취소 · 검증 실패 중 하나).' }
  }
}
