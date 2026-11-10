# 이 블록은 파드 1개를 지운다. 두 번 실행하면 두 커넥터가 모두 교체되어 '한쪽은 옛 값을 들고 있다'는 안전망이 사라진다.
# env(secretKeyRef)는 **컨테이너가 시작할 때마다** 재판독한다. 옛 값은 **컨테이너가 재시작되지 않는 동안만** 유지된다.
# 파일로만 실행한다. g4-adopt.ps1의 PASS와 preHash·preUid가 필요하며 이 블록에서 다시 검증한다.
# 삭제 대상은 startTime이 가장 늦은 파드(동률이면 이름 Ordinal)다. 처음부터 있던 커넥터도 컨테이너 재시작 시 새 값을 읽는다.
# 시각 기반 second는 경고 확인일 뿐 실행 이력을 증명하지 않는다. 요청은 실행당 최대 1번, 회계는 요청 전에 기록한다.
& {
  $ErrorActionPreference = 'Stop'
  # $PSNativeCommandUseErrorActionPreference 가 $true 면(프로필·버전에 따라 달라진다) 네이티브 명령의 비0 종료가
  # 내 검사보다 먼저 NativeCommandExitException 을 던져서 아래의 문면·재시도가 통째로 무력해진다.
  # 실측(2026-09-21 · pwsh 7.6.6 -NoProfile): 기본값은 False. 바깥이 True 여도 이 블록 안에서만 끄면 되고,
  # 끈 값은 세션으로 새지 않는다(자식 스코프 · 실측). 모든 호출 지점이 $LASTEXITCODE 를 직접 보고 fail-closed 로 판정한다.
  $PSNativeCommandUseErrorActionPreference = $false
  $NS = 'cloudflared'
  $SEC = 'cloudflared-tunnel'
  $ESN = 'cloudflared-tunnel'
  $KEY = 'TUNNEL_TOKEN'
  $APP = 'platform-cloudflared'
  $OWNER = 'platform-secrets'
  # 단계 요약(규칙 9)은 시작할 때 전부 채워 둔다 — 중간에 throw 해도 "여기까지 오지 못했다"가 표에 남는다.
  $log = [ordered]@{}
  foreach ($k in '0) 전제·break-glass', '1) 드릴 전제', '4) 파드 1개 드릴', '5) 접근 경로') {
    $log[$k] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  $changes = [System.Collections.ArrayList]::new()
  $preHash = ''
  $preUid = ''
  $podPre = ''
  $podPost = ''
  $podNow = ''
  $keysNow = ''
  # $recover 는 '' / 'value' / 'uid' 셋 중 하나다 — 원인이 다르면 복구 경로도 다르다(UID 만 바뀐 것은 kv 문제가 아니다).
  $recover = ''
  $mergeAsked = $false
  $judged = $false
  $noGlass = $false
  $preFromPm = $false
  $pmNote = ''
  # UID 가 어긋난 순간의 실제 UID(비밀 아님). 복구 안내가 "새 UID 를 넣어라"고만 하고 값을 주지 않으면 운영자가 다시 찾아야 한다.
  $uidNow = ''
  try {
    # ---------- 헬퍼 ----------
    $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $txt = { param($o) [string]::Join("`n", @(@($o) | ForEach-Object { [string]$_ })) }
    # 정지점: 버퍼를 비우고 단어를 요구한다. 빈 Enter·버퍼 잔여 입력으로는 통과하지 않는다.
    # Read-Host 가 $null 이면 stdin EOF 다(파이프·-NonInteractive) — "빈 입력"이 아니라 실행 방식이 틀렸다는 뜻이므로 그렇게 말한다.
    $stop = { param($msg, $word = 'go')
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $a = Read-Host "$msg — 진행하려면 $word 입력 후 Enter(그 외 입력 = 중단)"
      if ($null -eq $a) { throw '입력 스트림이 닫혔다(EOF) — 대화형 콘솔에서 파일로 실행한다(stdin 파이프·-NonInteractive 는 지원하지 않는다)' }
      if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }
    # 데이터 입력(비밀 아님). 반환값을 받아 쓰므로 입력이 화면에 되출력되지 않는다.
    $ask = { param($msg)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $v = Read-Host $msg
      if ($null -eq $v) { throw '입력 스트림이 닫혔다(EOF) — 대화형 콘솔에서 파일로 실행한다(stdin 파이프·-NonInteractive 는 지원하지 않는다)' }
      [string]$v }
    # 비밀 입력(1P·1R 에서만 쓴다): 버퍼를 비우고 -AsSecureString 으로 받은 뒤 즉시 클립보드를 비운다.
    # 비우기가 실패하면 침묵하지 않는다 — 토큰이 클립보드에 남은 채로 진행하는 것이 가장 흔한 누출 경로다.
    $readSecret = { param($prompt)
      try { $Host.UI.RawUI.FlushInputBuffer() } catch { }
      $ss = Read-Host $prompt -AsSecureString
      try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 토큰이 클립보드에 남아 있을 수 있다. Win+V 로 확인하고 직접 비운다' }
      if ($null -eq $ss -or $ss.Length -eq 0) { throw "빈 입력(또는 입력 스트림이 닫혔다 — 파일로 실행한다) — 중단: $prompt" }
      ($ss | ConvertFrom-SecureString -AsPlainText) }
    # 조회 전용 kubectl. 재시도는 "실패를 성공으로 읽는" 것이 아니다 — 3회 모두 실패하면 판정 불가로 중단한다(fail-closed).
    # 15분짜리 폴링 도중의 터널 순단 1회로 블록이 죽으면, 머지 뒤에는 기준값을 다시 잡을 수 없어 더 위험하다.
    # $okRc — `kubectl auth can-i` 는 답이 "no" 면 exit 1 로 끝난다(cani.go). 그 1 을 조회 실패로 읽으면 맞춤 문면이 죽은 코드가 된다.
    # 첫머리의 동사 허용 목록 — 이 헬퍼로는 조회만 나간다(요구 (h) 의 정적 보장을 런타임에서도 한 번 더 잠근다).
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
          $did = '이 실행은 아직 아무것도 바꾸지 않았다'
          if ($changes.Count -gt 0) { $did = "⚠ 이 실행은 이미 $($changes.Count) 건을 바꿨다(아래 요약) — 남은 파드는 절대 건드리지 않는다" }
          throw "kubectl 조회 실패(exit=$rc · 3회 시도): $desc — 판정 불가로 중단한다($did). 터널 순단일 수 있다 — cloudflared 파드를 재시작·삭제해서 고치려 하지 않는다(값이 미판정인 상태의 재시작이 유일한 잠금 경로다)" }
        Write-Warning "kubectl 조회 실패(exit=$rc): $desc — 5초 뒤 재시도($n/3)"
        Start-Sleep -Seconds 5 } }
    # 로그 조회는 증거 수집이지 판정이 아니다 — 실패해도 throw 하지 않는다(이미 드릴이 끝난 뒤다). 로그 본문은 출력하지 않는다.
    $klog = { param($pod)
      $out = & kubectl '-n' $NS 'logs' $pod '--tail=120' '--request-timeout=15s'
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0) { Write-Warning "새 파드 로그 조회 실패(exit=$rc) — 로그 확인은 건너뛴다(판정에는 쓰지 않는다)"; return '' }
      [string]::Join("`n", @(@($out) | ForEach-Object { [string]$_ })) }
    # ⚠ 클러스터를 바꾸는 유일한 헬퍼. 소스 안에 호출 지점이 1곳뿐이어야 한다(하네스 lint 가 인자까지 하나씩 정확 대조한다).
    # 회계($changes·$log)를 **요청을 보내기 전에** 적는다 — 삭제 도중 Ctrl+C 로 파이프라인이 멈춰도 요약이 "변경 0건"이라고 거짓말하지 않는다.
    # `--wait=false` — 기본 --wait 는 DELETE 뒤 watch 스트림을 물고 기다리는데, 그 스트림이 지금 지우는 커넥터를 타고 있을 수 있다.
    #   그 경우 삭제는 됐는데 kubectl 만 비0 으로 끝나 "삭제 실패"로 오판한다. 소멸·Ready 판정은 아래 드릴 폴링이 직접 한다.
    $kdel = { param($pod)
      [void]$changes.Add("kubectl -n $NS delete pod $pod (요청 시도 — 결과는 4) 줄에 남는다)")
      $log['4) 파드 1개 드릴'] = "삭제 요청을 보냈다($pod) — 결과 미확인(kubectl -n $NS get pods 로 확인한다)"
      $out = & kubectl '-n' $NS 'delete' 'pod' $pod '--wait=false' '--request-timeout=30s'
      $rc = $LASTEXITCODE
      $global:LASTEXITCODE = 0
      if ($rc -ne 0) { throw "파드 삭제 요청 실패(exit=$rc): $pod — 요청이 수락됐는지는 알 수 없다(응답만 잃었을 수 있다). kubectl -n $NS get pods 로 Terminating 여부를 확인하고, 남은 파드는 절대 건드리지 않는다" }
      [string]::Join(' ', @(@($out) | ForEach-Object { [string]$_ })) }
    # 파드 서명: 이름|restartCount|startTime 을 Ordinal 정렬해 이어 붙인다. Ready 는 순간적으로 흔들릴 수 있어 서명에 넣지 않고 따로 본다.
    # 라벨 셀렉터 `app=cloudflared` — ns 안의 디버그 파드·Evicted 잔재를 커넥터로 세지 않는다(Deployment 의 selector 와 같은 라벨).
    $pods = { param($desc)
      $raw = & $kq $desc @('-n', $NS, 'get', 'pods', '-l', 'app=cloudflared', '-o', 'jsonpath={range .items[*]}{.metadata.name}|{.status.containerStatuses[0].restartCount}|{.status.startTime}|{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}')
      $rows = @(@($raw) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      if ($rows.Count -eq 0) { throw "파드 목록이 비었다: $desc — 판정 불가(빈 응답을 '파드 없음'으로 읽지 않는다)" }
      $items = @()
      foreach ($r in $rows) {
        $p = $r -split '\|'
        if ($p.Count -ne 4 -or -not [regex]::IsMatch([string]$p[0], '\A[a-z0-9][a-z0-9.-]*\z') -or -not [regex]::IsMatch([string]$p[1], '\A\d+\z') -or -not [regex]::IsMatch([string]$p[2], '\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z')) { throw "파드 행 형식이 기대와 다르다($r) — 판정 불가" }
        $items += [pscustomobject]@{ name = [string]$p[0]; start = [string]$p[2]; sig = "$([string]$p[0])|$([string]$p[1])|$([string]$p[2])"; ready = [string]$p[3] } }
      $sigs = @($items | ForEach-Object { $_.sig })
      [Array]::Sort($sigs, [StringComparer]::Ordinal)
      [pscustomobject]@{ items = $items; sig = ($sigs -join ' ') } }
    # 키 집합(비밀 아님 — 키 이름만). 값이 바뀐 분기의 원인 감별에도 쓴다: TUNNEL_TOKEN 이 없으면 원인은 kv 가 아니라 ES 매핑이다.
    $keyset = {
      $k = @(@(& $kq '키 목록' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}')) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })
      [Array]::Sort($k, [StringComparer]::Ordinal)
      ($k -join ',') }
    # ES 생성 시각(RFC3339 초 단위 고정폭 → Ordinal 문자열 순서 = 시간 순서). 형식이 다르면 판정 불가로 중단한다.
    $esAtGet = {
      $v = (& $txt (& $kq 'ES 생성 시각' @('-n', $NS, 'get', 'externalsecret', $ESN, '-o', 'jsonpath={.metadata.creationTimestamp}'))).Trim()
      if (-not [regex]::IsMatch($v, '\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z')) { throw "ES creationTimestamp 형식이 기대와 다르다($v) — 판정 불가" }
      $v }
    # ---------- 0) 창 전제 · break-glass 실측 ----------
    $nodes = @(& $kq '노드 목록' @('get', 'nodes', '-o', 'name'))
    if (-not (@($nodes) | Where-Object { [string]::Equals([string]$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {
      throw "kubectl 이 joshuatech 클러스터를 보고 있지 않다(KUBECONFIG=$env:KUBECONFIG) — 창 D 에 admin kubeconfig 를 지정하고 다시" }
    foreach ($v in 'get secrets', 'delete pods') {
      $can = (& $txt (& $kq "권한 확인($v)" (@('auth', 'can-i') + @($v -split ' ') + @('-n', $NS)) @(0, 1))).Trim()
      if (-not [string]::Equals($can, 'yes', [StringComparison]::Ordinal)) {
        throw "현재 kubeconfig 로는 $NS 에서 '$v' 를 할 수 없다(응답='$can' · 빈 응답이면 조회 자체가 실패했다는 뜻이다) — agent-view 가 아니라 admin kubeconfig 인지 확인한다" } }
    # 1차 break-glass 는 "창 A 에 이미 열려 있는 세션"이다. 새 연결이 되는 것은 그 증거가 아니다(잠긴 뒤에는 새 연결을 만들 수 없다).
    # 그래서 주장을 **대조**로 바꾼다: 블록이 새 연결로 노드 A 의 boot_id 앞 8자를 읽고, 운영자가 창 A 의 열린 세션에서 같은 값을 읽어 입력한다.
    # boot_id 는 비밀이 아니다. `StrictHostKeyChecking=accept-new` 는 쓰지 않는다 — 보안 블록이 호스트 키를 무인 수락할 이유가 없다.
    $bootPre = ''
    try {
      $so = & ssh '-n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=15' 'ssh-a' 'cut -c1-8 /proc/sys/kernel/random/boot_id'
      if ($LASTEXITCODE -eq 0) { $bootPre = (& $txt $so).Trim() } } catch { $bootPre = '' }
    $global:LASTEXITCODE = 0
    $sshPre = [regex]::IsMatch($bootPre, '\A[0-9a-f]{8}\z')
    # oci 프로파일 확인 — 읽기 전용 세션 프로파일(svc-verify)로는 NSG 규칙을 넣을 수 없다. 그 자격의 성공은 break-glass 가 아니다.
    $ociProf = [string]$env:OCI_CLI_PROFILE
    if ([string]::IsNullOrWhiteSpace($ociProf)) { $ociProf = 'DEFAULT' }
    $ociPre = $false
    try {
      $oo = & oci 'iam' 'region' 'list' '--query' 'length(data)'
      $ociPre = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace((& $txt $oo))) } catch { $ociPre = $false }
    $global:LASTEXITCODE = 0
    if ([string]::Equals($ociProf, 'svc-verify', [StringComparison]::Ordinal) -or [string]::Equals([string]$env:OCI_CLI_AUTH, 'security_token', [StringComparison]::Ordinal)) {
      Write-Warning "이 창의 oci 는 읽기 전용 세션 프로파일(OCI_CLI_PROFILE=$ociProf · OCI_CLI_AUTH=$env:OCI_CLI_AUTH)을 본다 — NSG 규칙을 추가할 수 없으므로 break-glass 로 세지 않는다"
      $ociPre = $false }
    "새 연결 실측(기준점 · 그 자체로는 break-glass 가 아니다): ssh ssh-a = $sshPre · oci 자격(프로파일 $ociProf) = $ociPre"
    '창 A 의 열린 세션은 커넥터 파드 하나에 묶여 있어 두 커넥터가 모두 내려가면 함께 끊긴다 — 그때 남는 경로는 OCI(NSG 임시 22 규칙)뿐이다.'
    'oci 는 자격 유효만 증명한다 — NSG 규칙 추가 권한은 별개다(실제 명령은 infra/oci/instances.tf 5·8단계 · OCID 는 tofu -chdir=infra/oci output -raw nsg_cluster_id 로 미리 적어 둔다).'
    if ($sshPre) {
      $typed = (& $ask '창 A 의 **이미 열려 있는** ssh 세션에서  cut -c1-8 /proc/sys/kernel/random/boot_id  를 실행해 나온 8자를 입력').Trim()
      if (-not [string]::Equals($typed, $bootPre, [StringComparison]::Ordinal)) {
        throw '창 A 의 값이 노드 A 의 boot_id 와 다르다 — 창 A 에 노드 A 의 살아 있는 세션이 없다(또는 다른 호스트다). 세션을 열고 처음부터 다시' }
      'OK 창 A 에 노드 A 의 살아 있는 셸이 있다(boot_id 대조) — 이것이 1차 break-glass 다' }
    else { Write-Warning '새 연결이 안 되므로 창 A 세션을 대조할 수 없다 — 1차 break-glass 는 미확인 상태다' }
    # 확인된 break-glass 가 0 이면(1차·2차 모두 미확인) 이 실행은 판정까지만 한다 — 유일한 변경 동작(파드 삭제)을 하지 않는다.
    $noGlass = ((-not $sshPre) -and (-not $ociPre))
    $w0 = 'go'
    if ($noGlass) { $w0 = 'no-breakglass' }
    elseif (-not $ociPre) { $w0 = 'no-oci' }
    elseif (-not $sshPre) { $w0 = 'noglass' }
    $m0 = '0) 위 실측을 인수한다(단어가 실측 결과에 따라 달라진다). no-oci = 두 커넥터가 모두 내려가면 OCI 웹 콘솔 말고는 복구 수단이 없다. noglass = 창 A 세션을 대조하지 못했다. PM 에 터널 토큰 항목이 있는지도 지금 육안 확인한다(값 출력 금지)'
    if ($noGlass) {
      $m0 = '0) ⚠ break-glass **1차(창 A 의 열린 ssh 세션)·2차(OCI 운영자 자격) 모두 미확인**이다 — 잠기면 남는 복구 경로가 없다. 이 실행은 인수 판정까지만 하고 **4) 파드 삭제는 거부**한다(유일한 변경 동작이다). 그래도 판정을 진행하려면 no-breakglass 를 입력한다. PM 에 터널 토큰 항목이 있는지도 지금 육안 확인한다(값 출력 금지)' }
    & $stop $m0 $w0
    $log['0) 전제·break-glass'] = "완료(ssh 새연결=$sshPre · 창A 대조=$(if ($sshPre) { 'OK' } else { '불가' }) · oci=$ociPre(프로파일 $ociProf) · 확인 단어 $w0$(if ($noGlass) { ' · 이 실행은 파드를 삭제하지 않는다' } else { '' }))"
    if ($noGlass) { throw 'break-glass 1차·2차 모두 미확인 — 삭제 거부' }
    $preHash = (& $ask 'g4-adopt 판정의 preHash(64자리 대문자 16진수)').Trim()
    if (-not [regex]::IsMatch($preHash, '\A[0-9A-F]{64}\z')) { throw 'preHash 형식이 아니다' }
    $preUid = (& $ask 'g4-adopt 판정의 preUid').Trim()
    if (-not [regex]::IsMatch($preUid, '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z')) { throw 'preUid 형식이 아니다' }
    $esState = @((& $txt (& $kq 'ES Ready' @('-n', $NS, 'get', 'externalsecret', $ESN, '-o', 'jsonpath={.status.conditions[?(@.type=="Ready")].status}|{.status.conditions[?(@.type=="Ready")].reason}'))).Trim() -split '\|')
    if ($esState.Count -ne 2 -or -not [string]::Equals([string]$esState[0], 'True', [StringComparison]::Ordinal) -or -not [string]::Equals([string]$esState[1], 'SecretSynced', [StringComparison]::Ordinal)) { throw 'ES Ready=True/SecretSynced 가 아니다 — 삭제 거부' }
    $b64 = (& $txt (& $kq '드릴 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
    if ([string]::IsNullOrWhiteSpace($b64)) { $recover = 'value'; throw 'Secret 빈 값 — 삭제 거부' }
    $postHash = & $sha $b64
    Remove-Variable b64
    if (-not [string]::Equals($postHash, $preHash, [StringComparison]::Ordinal)) {
      $recover = 'value'
      try { $keysNow = & $keyset } catch { $keysNow = '(조회 실패)' }
      throw '값 해시가 입력과 다르다 — 삭제 거부' }
    $postUid = (& $txt (& $kq '드릴 UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
    if (-not [string]::Equals($postUid, $preUid, [StringComparison]::Ordinal)) {
      $recover = 'uid'
      $uidNow = $postUid
      throw 'UID 가 입력과 다르다 — 삭제 거부' }
    $dh = (& $txt (& $kq 'ESO data-hash' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.annotations.reconcile\.external-secrets\.io/data-hash}'))).Trim()
    if ([string]::IsNullOrWhiteSpace($dh)) { throw 'data-hash 어노테이션이 없다 — 삭제 거부' }
    $pd = & $pods '드릴 직전 파드'
    if (@($pd.items).Count -ne 2) { throw '파드가 정확히 2개가 아니다 — 삭제 거부' }
    foreach ($p in $pd.items) {
      if (-not [string]::Equals($p.ready, 'True', [StringComparison]::Ordinal)) { throw "파드 $($p.name) 이 Ready 가 아니다 — 삭제 거부" } }
    $log['1) 드릴 전제'] = 'PASS(ES Ready·값·UID·data-hash·파드 2개 Ready)'
    $esAt = & $esAtGet
    $after = @($pd.items | Where-Object { [string]::CompareOrdinal([string]$_.start, $esAt) -gt 0 })
    $w4 = 'drill'
    if ($after.Count -gt 0) { $w4 = 'second'; Write-Warning '이미 교체된 파드로 보인다 — 두 번째 실행 경고: second 입력이 필요하다(시각은 확정 증거가 아니다).' }
        $ord = @($pd.items | ForEach-Object { "$($_.start)|$($_.name)" })
        [Array]::Sort($ord, [StringComparer]::Ordinal)
        $survivor = [string](($ord[0] -split '\|')[1])
        $target = [string](($ord[1] -split '\|')[1])
        $sv0 = @($pd.items | Where-Object { [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) })[0]
        $tg0 = @($pd.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) })[0]
        $survSig = [string]$sv0.sig
    & $stop "지울 파드 이름 $target 을 직접 타자한다(남길 파드 $survivor). 창 A에서 Enter를 쳐 세션을 지금 다시 확인한다" $target
    $m4 = "4) $target 하나만 삭제한다. 새 파드가 Ready가 아니면 남은 파드는 절대 건드리지 않는다"
    & $stop $m4 $w4
        # 정지점에서 시간이 흘렀다 — 삭제 직전에 전제를 **전부** 다시 읽는다(fail-closed). 파드뿐 아니라 값·UID 도 다시 읽는다:
        # 사람 대기가 ESO refresh 주기(5분)를 넘기면 3) 의 PASS 는 더 이상 지금의 사실이 아니다.
        $hDel = & $sha (& $txt (& $kq '삭제 직전 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
        $uDel = (& $txt (& $kq '삭제 직전 UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
        if (-not [string]::Equals($hDel, $preHash, [StringComparison]::Ordinal)) {
          $recover = 'value'
          try { $podNow = (& $pods '복구 안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
          try { $keysNow = & $keyset } catch { $keysNow = '(조회 실패)' }
          throw '⚠ 정지점에서 기다리는 사이에 터널 값이 바뀌었다 — 파드를 삭제하지 않는다(3) 의 PASS 는 더 이상 유효하지 않다). 아래 복구 안내를 따른다' }
        if (-not [string]::Equals($uDel, $preUid, [StringComparison]::Ordinal)) {
          $recover = 'uid'
          $uidNow = $uDel
          try { $podNow = (& $pods '안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
          throw '⚠ 정지점에서 기다리는 사이에 Secret 이 재생성됐다(UID 변경) — 파드를 삭제하지 않는다. 아래 안내를 따른다' }
        $pd2 = & $pods '삭제 직전 재확인'
        if (@($pd2.items).Count -ne 2) {
          throw "삭제 직전 재확인에서 파드가 2개가 아니다($(@($pd2.items).Count) 개) — 정지점 사이에 롤아웃·스케일이 있었다. 삭제하지 않는다" }
    if (-not [string]::Equals($pd2.sig, $pd.sig, [StringComparison]::Ordinal) -or @($pd2.items | Where-Object { -not [string]::Equals($_.ready, 'True', [StringComparison]::Ordinal) }).Count -gt 0) { throw '정지점 사이 파드 상태 변경 — 삭제 거부' }
        & $kdel $target | Out-Null
        $log['4) 파드 1개 드릴'] = "삭제 요청함($target) — 새 파드 Ready 대기 중"
        $t1 = Get-Date
        $tick = 0
        $newName = ''
        while ((Get-Date) -lt $t1.AddSeconds(300)) {
          Start-Sleep -Seconds 10
          # 삭제 뒤에는 더 바꿀 것이 없다. 여기서 조회가 실패해도 기한까지 계속 기다린다 — 3회 실패로 죽어 봐야 검증만 잃고 재실행을 부른다.
          $pn = $null
          try { $pn = & $pods '드릴 대기' } catch { Write-Warning "드릴 대기 중 조회 실패 — 터널 순단일 수 있다. 남은 파드 $survivor 는 건드리지 않고 기한까지 계속 기다린다: $($_.Exception.Message)"; continue }
          $sv = @($pn.items | Where-Object { [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) })
          if ($sv.Count -ne 1) {
            throw "남은 파드 $survivor 가 사라졌다 — 두 커넥터가 모두 내려갔을 수 있다. 창 A 의 ssh 세션에서 상태를 본다(이 블록은 더 이상 아무것도 하지 않는다)" }
          if (-not [string]::Equals([string]$sv[0].sig, $survSig, [StringComparison]::Ordinal)) {
            throw "남은 파드 $survivor 가 재시작·교체됐다(서명 변경) — 유일한 경로가 흔들렸다. 더 이상 아무것도 삭제하지 않는다" }
          if (-not [string]::Equals($sv[0].ready, 'True', [StringComparison]::Ordinal)) { throw "남은 파드 $survivor 가 Ready 가 아니다 — 더 이상 삭제하지 않는다" }
          $nw = @($pn.items | Where-Object { -not [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) -and -not [string]::Equals($_.name, $target, [StringComparison]::Ordinal) })
          if (@($pn.items).Count -eq 2 -and @($pn.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) }).Count -eq 0 -and $nw.Count -eq 1 -and [string]::Equals([string]$nw[0].ready, 'True', [StringComparison]::Ordinal)) { $newName = [string]$nw[0].name; break }
          $tick = $tick + 1
          if (($tick % 3) -eq 0) { "  … $([int](((Get-Date) - $t1).TotalSeconds)) 초 경과(새 파드 Ready 대기 중)" } }
        if ([string]::IsNullOrWhiteSpace($newName)) {
          throw "새 파드가 300초 안에 Ready 가 되지 않았다 — 남은 파드 $survivor 를 절대 건드리지 않는다(유일한 경로다). 이벤트·로그로 원인을 확인한다" }
        "OK 새 파드 $newName 이 Ready · 남은 파드 $survivor 는 서명 불변"
        Write-Warning '창 A 의 ssh 세션이 방금 삭제한 커넥터를 타고 있었다면 끊겼다 — 지금 창 A 에서 Enter 를 쳐 확인하고, 끊겼으면 다시 연다(새 연결은 남은 커넥터로 간다).'
        # 로그는 본문을 출력하지 않는다 — 존재 여부만 본다.
        $hit = (& $klog $newName).Contains('Registered tunnel connection')
        if ($hit) { 'OK 새 파드 로그에 Registered tunnel connection 있음(연결 수는 T039 기록과 대조한다)' }
        else { Write-Warning '새 파드는 Ready 지만 로그에서 Registered tunnel connection 을 찾지 못했다(로그 지연·문구 변경일 수 있다) — T039 기록과 대조하고, 두 번째 파드는 교체하지 않는다' }
        $log['4) 파드 1개 드릴'] = "완료(삭제 $target → 새 파드 $newName Ready · 로그 확인 $hit)"
    # ---------- 5) 접근 경로 확인 ----------
    # kubectl 은 같은 터널을 타므로 여기서의 실패는 터널 자체의 실패다 → throw. ssh 는 운영자 환경(에이전트·키·Access 앱) 의존이라 경고로 둔다.
    $nd = & $txt (& $kq '노드 Ready' @('get', 'nodes', '-o', 'jsonpath={range .items[*]}{.metadata.name}={.status.conditions[?(@.type=="Ready")].status} {end}'))
    $ready2 = @([regex]::Matches($nd, '=True')).Count
    if ($ready2 -ne 2) { throw "kubectl get nodes 가 Ready 2 개가 아니다($nd) — 터널 또는 노드 상태를 확인한다" }
    "OK kubectl get nodes = Ready 2 ($nd)"
    $sshPost = $false
    try {
      $sp = & ssh '-n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=15' 'ssh-a' 'hostname'
      $sshPost = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace((& $txt $sp))) } catch { $sshPost = $false }
    $global:LASTEXITCODE = 0
    if ($sshPost) { 'OK ssh ssh-a 성공(새 연결)' }
    elseif ($sshPre) {
      Write-Warning '⚠ 드릴 전에는 되던 ssh ssh-a 가 드릴 뒤에 실패한다 — 커넥터 교체의 영향일 수 있다. 두 번째 파드를 절대 교체하지 말고(남은 파드가 유일한 SSH 경로다) 원인을 확인한다' }
    else { Write-Warning 'ssh ssh-a 는 드릴 전에도 실패했다 — 운영자 환경(키·에이전트·Access 앱) 문제일 가능성이 높다. T046 으로 가기 전에 반드시 복구한다' }
    Write-Warning '창 A 의 대화형 ssh 세션이 아직 살아 있는지 지금 확인한다(그 창에서 Enter 한 번). 끊겼으면 **즉시 다시 연다** — 두 번째 파드를 교체하기 전의 1차 break-glass 다.'
    $log['5) 접근 경로'] = "kubectl nodes=Ready2 · ssh 새연결 전=$sshPre 후=$sshPost"
  }
  finally {
    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, so, sp, oo, out, raw, tok, pmHash -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 직접 확인한다' }
    Write-Host '--- G4 드릴 단계 요약 ---'
    foreach ($e in $log.GetEnumerator()) { Write-Host ('{0,-20} {1}' -f $e.Key, $e.Value) }
    Write-Host "이 실행이 클러스터에 가한 변경: $($changes.Count) 건"
    foreach ($c in $changes) { Write-Host "  $c" }
    if ([string]::Equals($recover, 'uid', [StringComparison]::Ordinal)) {
      Write-Host '복구 인계(uid): 값은 입력 해시와 같다. kv-correct.ps1 · g4-restore.ps1 은 필요 없다(쓰면 안 된다). Secret 재생성 원인을 먼저 조사한다.'
      Write-Host "기준값 preUid = $preUid · 지금 UID = $uidNow · 기준값 preHash = $preHash"
      Write-Host '원인을 확인한 뒤 g4-adopt.ps1 resume에 새 UID와 보존한 해시를 사용해 판정한다. 파드는 건드리지 않는다.' }
    elseif ([string]::Equals($recover, 'value', [StringComparison]::Ordinal)) {
      Write-Host '복구 인계(value): 파드 재시작·삭제 금지. 옛 값 안전망은 컨테이너가 재시작되지 않는 동안만 유효하므로 복구를 미루지 않는다.'
      Write-Host "기준값 preHash = $preHash · preUid = $preUid · 지금 Secret 키 집합: $keysNow"
      if ([string]::IsNullOrWhiteSpace($keysNow) -or [string]::Equals($keysNow, '(조회 실패)', [StringComparison]::Ordinal)) { Write-Warning '키 집합을 읽지 못했다 — kv 값 오류와 ES 매핑 오류를 구별하지 못한다.' }
      elseif (-not [string]::Equals($keysNow, $KEY, [StringComparison]::Ordinal)) { Write-Warning '키 집합이 다르다 — ES 매핑 오류 가능성. R1 값 정정만으로 해결되지 않는다.' }
      Write-Host 'R1: kv-correct.ps1로 검증된 원본을 정정. R2: revert→ES 인수 해제→g4-restore.ps1. 상세 판단과 순서는 g4-adopt.ps1의 복구 안내를 읽는다.'
      Write-Host 'R3: kubectl·ssh가 모두 막혔으면 g4-adopt.ps1을 실행하지 않고 파일의 R3 노드 셸 절차를 읽는다. 살아 있는 창 A 또는 OCI 비상 경로에서 복구한다.' }
    if ($changes.Count -gt 0) {
      Write-Warning '남은 파드는 절대 건드리지 않는다. API 접근이 가능하면 g4-adopt.ps1으로 값·UID를 판정하고 복구 안내(R1/R2)를 따른다. 드릴을 바로 재실행하지 않는다.'
      Write-Warning 'kubectl·SSH가 막혔으면 g4-adopt.ps1을 실행하지 않고 파일의 R3 노드 셸 절차를 읽는다. 살아 있는 창 A 또는 OCI 비상 경로에서 복구한다.' }
  }
}
