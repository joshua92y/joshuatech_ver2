# ===== T045 G4 인수 블록 — 터널 토큰 Secret 의 제자리 인수(창 D) =====
# ⚠ 대상: cloudflared/cloudflared-tunnel .TUNNEL_TOKEN — SSH 와 K8s API 의 유일한 경로(Cloudflare Tunnel)의 자격이다.
#    cloudflared 는 이 토큰을 **컨테이너가 시작할 때마다** env(secretKeyRef)로 읽는다 — 파드 교체뿐 아니라
#    liveness(/ready 60초 연속 실패)·OOMKill(limits 256Mi)·노드 재부팅·drain 에 의한 in-place 재시작도 포함이다.
#    그 경우 **같은 파드 이름·같은 UID 로 restartCount 만 오르며** 새 값을 읽는다.
#    즉 "실행 중 파드가 옛 값을 들고 있다"는 안전망은 **컨테이너가 재시작되지 않는 동안만** 유효하다 — 무기한이 아니다.
#    그래서 이 블록의 안전망은 둘이다 — **판정이 틀어지면 파드를 건드리지 않는다** · **복구를 미루지 않는다.**
#    deployment 단위 전면 재시작은 어떤 경우에도 하지 않는다.
# 실행: **파일 실행만** — `& "<이 파일 경로>"`(dot-source 가 아니다. 이 블록은 세션 변수를 남기지 않는다).
#    **stdin 실행(`pwsh -Command -` · 파이프 주입)은 지원하지 않는다** — 정지점의 Read-Host 가 스크립트 본문을 답으로 읽어 삼키거나,
#    `-AsSecureString` 이 콘솔을 직접 열어 영영 기다린다. 반드시 대화형 콘솔에서 파일로 실행한다(EOF 면 블록이 그 사실을 말하고 멈춘다).
#    붙여넣기는 구조상 방어해 두었으나(전체가 `& { … }` 한 문 · 블록 안 빈 줄 0 · 파일 끝 `}`+개행 1개)
#    이 크기(700줄 이상 · 85KB 이상)의 다중 행 버퍼 붙여넣기는 검증하지 않았다 — 쓰지 않는다.
# 사전 준비(블록 밖):
#    창 A — `ssh ssh-a` **대화형 세션을 미리 열어 둔다**. 0) 에서 노드 A 의 boot_id 앞 8자 대조로 그 세션의 실재를 확인한다.
#       ⚠ 그 세션은 커넥터 파드 **하나**를 지나는 TCP 스트림이다. 4) 드릴이 지우는 쪽이었다면 약 30초 뒤 끊긴다(정상 — 커넥터는 스트림을 옮기지 않는다).
#       ⚠ 두 커넥터가 모두 내려가는 진짜 잠금에서는 그 세션도 함께 죽는다. 그때 남는 경로는 OCI(NSG 임시 22 규칙)뿐이다.
#    창 B — `gh pr merge` 를 실행할 창. 이 블록이 2) 에서 폴링을 시작한 **뒤에** 거기서 머지한다.
#    창 D(이 창) — `$env:KUBECONFIG` = admin kubeconfig. 클러스터 API 도 같은 터널을 탄다(cloudflared access tcp → 127.0.0.1:6443).
#    2차 break-glass — OCI **운영자** 프로파일 자격(읽기 전용 svc-verify 아님). PM 에 터널 토큰 원본(1P 에서 해시로 대조한다).
#       ⚠ NSG OCID 를 **지금 미리** 적어 둔다: `tofu -chdir=infra/oci output -raw nsg_cluster_id`(이 블록은 실행하지 않는다).
#         잠긴 뒤에는 OCID 를 찾는 일부터가 늦다 — 임시 22 규칙의 실제 명령은 infra/oci/instances.tf 5·8단계다.
# 정지점에서 입력할 단어:
#    0) break-glass 인수 — 실측이 둘 다 성공이면 `go`, oci 만 실패면 `no-oci`, ssh 만 실패면 `noglass`,
#       **둘 다 실패면 `no-breakglass`** — 그 실행은 판정까지만 하고 4) 파드 삭제를 **거부**한다(확인된 복구 경로가 0 이므로).
#    1R) **이미 인수된 뒤에 실행했을 때만** 나온다 — `resume`. 이전 실행이 출력한 preHash·preUid·파드서명을 들고 판정만 잇는다.
#       preHash 기록이 없으면 그 프롬프트에 `pm` 을 넣어 PM 원본에서 해시만 유도할 수 있다 — 그 실행의 기준값은
#       **라이브로 검증된 적이 없는 값**이라 1P) 대조를 건너뛰고(같은 출처끼리의 비교라 항상 일치한다), 화면·요약·복구 안내가 그 사실을 계속 달고 다닌다.
#       파드 서명은 이전 실행이 드릴을 마쳤다면 요약이 인쇄한 `drilled:…` 줄을 **접두어째** 붙여 넣는다 — 그 실행은 파드를 삭제하지 않는다.
#    1D) **이전에 인수된 적이 있는데 managed 라벨만 지워진 Secret 일 때만** 나온다(ESO 의 data-hash 어노테이션이 그 흔적이다) — `readopt`,
#       이어서 `drilled`(이전 인수에서 이미 파드를 교체했다 → 이 실행은 삭제 0) 또는 `first`(이 재인수에서 아직 교체하지 않았다 → 4) 단어가 first-drill).
#    1P) PM 원본 대조 — 검증하면 `pm`, 건너뛰면 `skip-pm`(기준값이 PM 유도면 이 정지점 자체가 나오지 않는다).
#    2) 감시·폴링 시작 — `merge`(resume 이고 ES 가 살아 있으면 `continue`). **단어 입력이 먼저, 머지는 그 뒤다.**
#    4) 파드 1개 교체 드릴 — `drill`. **기준값을 이어받은 실행(1R resume)과 라벨이 지워진 재인수(1D first)에서는 `first-drill`** —
#       그 실행들에서는 "이미 드릴했다"를 블록이 스스로 알 수 없으므로(ES 가 다시 만들어졌으면 「인수 뒤 시작」 시각 판정도 함께 리셋된다),
#       이 실행이 그 인수의 **첫 드릴**이라는 것을 사람이 단어로 확인한다(이미 했다면 중단하고 파드 서명에 `drilled:` 를 붙여 다시 실행).
#    그 외 입력과 빈 Enter 는 전부 중단이다.
# 이 블록이 클러스터를 바꾸는 동작은 4) 의 **파드 1개 삭제** 하나뿐이다(그 외에는 조회만 한다. 중단하면 0건).
#    실행 횟수를 통틀어도 삭제가 1건을 넘지 않게 하는 것은 넷이다 — `drilled:` 접두어(무조건 SKIP) · 인수 뒤 시작한 파드가 있으면 SKIP(Ready 든 아니든)
#    · **기준값을 이어받은 모든 실행(1R resume)과 1D 재인수의 드릴 단어를 `first-drill` 로 가르는 것** · 라벨이 지워진 재인수를 data-hash 어노테이션으로 잡아내는 1D) 정지점.
#    뒤의 둘은 사람의 확인이다. 단어를 **ES 의 존재 여부(일시적 사실)가 아니라 기준값의 출처(구조적 사실)** 에 건다 —
#    운영자가 블록보다 먼저 머지한 재인수에서는 ES 가 살아 있어 "이미 드릴했다"를 시각으로 전혀 구분할 수 없다(5R 검증 B4-01).
# 비밀 값은 화면·argv·파일·클립보드·세션 변수에 남지 않는다. 판정 기준은 해시(SHA-256 · Ordinal)와 UID 뿐이다.
# 값 백업을 세션 변수에 두지 않는 근거: 복구 원본이 넷 있다 — ① 실행 중 컨테이너의 env(재시작 전까지만) ② PM(1P 에서 해시로 검증한다)
#    ③ Cloudflare 대시보드 ④ `tofu -chdir=infra/cloudflare output -raw tunnel_token`(출력은 파이프로만).
#    Vault kv 는 인수 사고의 원인일 수 있으므로 원본으로 세지 않는다.
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
  foreach ($k in '0) 전제·break-glass', '1) 머지 전 캡처', '1P) PM 원본 대조', '2) 머지 대기', '3) 인수 판정', '4) 파드 1개 드릴', '5) 접근 경로') {
    $log[$k] = '미실행(이 실행에서 여기까지 오지 못했다)' }
  $changes = [System.Collections.ArrayList]::new()
  $preHash = ''
  $preUid = ''
  $podPre = ''
  $podPost = ''
  $podNow = ''
  $podDrill = ''
  $keysNow = ''
  # $recover 는 '' / 'value' / 'uid' 셋 중 하나다 — 원인이 다르면 복구 경로도 다르다(UID 만 바뀐 것은 kv 문제가 아니다).
  $recover = ''
  $mergeAsked = $false
  $judged = $false
  $noGlass = $false
  $drilled = $false
  # 1R)·1D) 에서만 세워진다. $preFromPm = 기준값이 PM 원본에서 유도됐다(라이브로 검증된 적 없다) · $preDrilled = 운영자가 "이미 드릴했다"를 명시했다.
  $preFromPm = $false
  $preDrilled = $false
  # 1D) 에서만 세워진다 — managed 라벨은 지워졌지만 data-hash 어노테이션이 남은 재인수다(4) 단어가 first-drill 로 갈린다).
  $reAdopt = $false
  $pmNote = ''
  $nrNote = ''
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
        if ($p.Count -lt 4) { throw "파드 행 형식이 기대와 다르다($r) — 판정 불가" }
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
    # 드릴을 **하지 않고** 끝나는 실행(SKIP·거부)에서도 "지금 이중화가 성립하는가"를 판정해 경고와 요약에 남긴다.
    # 정상 드릴 경로는 남길 파드(throw)와 삭제 대상(경고)을 따로 보지만, SKIP 경로에는 그 검사가 아예 없었다 —
    # 그 실행의 "OK"가 T046(두 번째 파드 교체) 판단의 근거가 되므로, 한쪽이 NotReady 인 채로 조용히 끝나면 안 된다.
    $nrWarn = { param($items)
      $nr = @(@($items) | Where-Object { -not [string]::Equals([string]$_.ready, 'True', [StringComparison]::Ordinal) })
      if ($nr.Count -eq 0) { return '' }
      $nm = (@($nr | ForEach-Object { [string]$_.name }) -join ',')
      Write-Warning "⚠ 커넥터 $nm 이 Ready 가 아니다 — 드릴은 하지 않았지만 이중화는 지금 성립하지 않는다. 두 번째 파드를 절대 교체하지 않는다(T046 전에 원인을 해결한다)"
      " · ⚠ Ready 아닌 커넥터: $nm" }
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
    # ---------- 1) 머지 전 캡처 ----------
    # 가드 ⓐ — 아직 인수 전인가. 인수 뒤에 캡처하면 preHash = 덮인 값이라 3) 이 가짜 PASS 를 낸다.
    $mg0 = (& $txt (& $kq 'managed 라벨' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.labels.reconcile\.external-secrets\.io/managed}'))).Trim()
    $resumed = $false
    $esGone = $false
    if (-not [string]::IsNullOrWhiteSpace($mg0)) {
      $resumed = $true
      Write-Warning '이미 ESO 가 손댄 Secret 이다(managed 라벨) — 머지 전 기준값은 더 이상 잡을 수 없다. 지금 값을 기준으로 삼으면 가짜 PASS 가 된다'
      & $stop '1R) 이전 실행이 출력한 preHash·preUid 를 손에 들고 판정만 이어가려면 resume 를 입력한다(preHash 기록이 없으면 다음 프롬프트에 pm 을 넣어 PM 원본에서 해시만 유도한다)' 'resume'
      $preHash = (& $ask 'preHash(64자리 대문자 16진수) 붙여넣기 — 기록이 없으면 pm 입력(PM 원본에서 해시만 유도한다)').Trim()
      if ([string]::Equals($preHash, 'pm', [StringComparison]::Ordinal)) {
        $ch0 = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
        if ($null -eq $ch0 -or $ch0 -ne 0) { throw '클립보드 기록이 꺼져 있음을 확인하지 못했다 — 설정 > 시스템 > 클립보드에서 끄고 다시(토큰 미입력)' }
        $preHash = & $sha ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((& $readSecret 'PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)').Trim())))
        $preFromPm = $true
        $pmNote = ' (PM 유도 — 라이브로 검증된 적 없음)'
        Write-Warning 'preHash 를 PM 원본에서 유도했다 — "PM = 인수 전 라이브 값"이 전제이고 이 실행에서는 그것을 검증할 방법이 없다(1P 대조는 같은 출처끼리의 비교라 건너뛴다). 판정이 실패하면 "라이브가 틀렸다"와 "PM 이 낡았다"가 모두 가능하다' }
      if (-not [regex]::IsMatch($preHash, '\A[0-9A-F]{64}\z')) { throw 'preHash 형식이 아니다(64자리 대문자 16진수) — 중단' }
      $preUid = (& $ask 'preUid 붙여넣기').Trim()
      if (-not [regex]::IsMatch($preUid, '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z')) { throw 'preUid 형식이 아니다(36자 UID) — 중단' }
      # 빈 Enter 로 게이트를 포기시키지 않는다(안전 규칙 1) — 포기하려면 nopods 를 **명시**해야 하고, 그 실행은 파드를 삭제하지 않는다.
      $podPre = (& $ask '기록해 둔 파드 서명 붙여넣기(이전 실행이 드릴을 마쳤다면 요약이 인쇄한 drilled: 줄을 **접두어째** 그대로 넣는다 — 그 실행은 파드를 삭제하지 않는다 · 기록이 없으면 nopods 입력 — 파드 불변 판정과 드릴을 모두 포기한다)').Trim()
      if ([string]::IsNullOrWhiteSpace($podPre)) { throw '빈 입력 — 중단(파드 서명이 없으면 nopods 를 입력한다)' }
      # `drilled:` 접두어 = "이전 실행이 이미 파드 1개를 교체했다"는 **운영자의 선언**이다. 시각(ES creationTimestamp)으로는
      # R2 뒤 재인수에서 그 사실을 알 수 없으므로(ES 가 새로 만들어지면 기준이 리셋된다), 그 잠금을 입력에 둔다.
      if ($podPre.StartsWith('drilled:', [StringComparison]::Ordinal)) {
        $preDrilled = $true
        $podPre = $podPre.Substring(8).Trim() }
      if ([string]::Equals($podPre, 'nopods', [StringComparison]::Ordinal)) { $podPre = '' }
      elseif (-not [regex]::IsMatch($podPre, '\A\S+\|\d+\|\S+ \S+\|\d+\|\S+\z')) { throw '파드 서명 형식이 아니다(이름|재시작수|시작시각 2개를 공백 하나로 이어 붙인 문자열 · 드릴 후 서명이면 앞에 drilled: 를 붙인다) — 줄바꿈으로 잘렸는지 확인하고 중단' }
      # R2(인수 해제)를 거친 뒤의 재실행이면 라벨은 남아 있고 ES 는 없다. 그때 2) 를 continue 로 몰면 15분 타임아웃으로 끝난다.
      $esR = (& $txt (& $kq 'ES 존재 확인(resume)' @('-n', $NS, 'get', 'externalsecret', $ESN, '--ignore-not-found', '-o', 'name'))).Trim()
      $esGone = [string]::IsNullOrWhiteSpace($esR)
      if ($esGone) { Write-Warning 'managed 라벨은 남아 있지만 ES 가 없다 = 인수 해제 상태(R2 를 거쳤다) — 재인수라면 2) 에서 지금 머지한다' }
      $log['1) 머지 전 캡처'] = "resume(운영자가 입력한 기준값을 쓴다$(if ($preFromPm) { ' · 기준값 PM 유도 — 라이브로 검증된 적 없음' } else { '' })$(if ($preDrilled) { ' · 드릴 후 서명(drilled:) — 이 실행은 삭제 0' } else { '' })$(if ($esGone) { ' · ES 없음 = 인수 해제 상태' } else { '' }))" }
    else {
      # 가드 ⓑ — 키 집합. ES 가 매핑하지 않은 키는 인수 순간 삭제된다(2026-09-21 DR1 실측). 값은 출력하지 않는다.
      $keys0 = & $keyset
      if (-not [string]::Equals($keys0, $KEY, [StringComparison]::Ordinal)) {
        throw "$KEY 외의 키가 있다($keys0) — 인수 순간 삭제된다. ES 매핑에 넣기 전에는 머지하지 않는다" }
      # 가드 ⓒ — ES 가 아직 없어야 한다(있으면 이미 머지됐거나 다른 경로로 만들어졌다).
      $esPre = (& $txt (& $kq 'ES 부재 확인' @('-n', $NS, 'get', 'externalsecret', $ESN, '--ignore-not-found', '-o', 'name'))).Trim()
      if (-not [string]::IsNullOrWhiteSpace($esPre)) {
        throw "ES 가 이미 있다($esPre) — 머지 전 상태가 아니다. 인수 여부를 확인하고 1R) resume 경로로 판정한다" }
      # UID·managed 라벨·data-hash 어노테이션·값을 **하나의 GET**(= 한 resourceVersion)으로 읽는다. 가드 ⓐⓒ 와 값 읽기가 서로 다른 GET 이면
      # 그 사이에 인수가 일어나 preHash = 덮인 값이 되는 좁은 창이 열린다. 같은 응답의 라벨이 비어 있으면 그 값은 ESO 가 쓰기 전의 값이다.
      $snap = @((& $txt (& $kq '인수 전 스냅샷(단일 GET)' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.metadata.uid}|{.metadata.labels.reconcile\.external-secrets\.io/managed}|{.metadata.annotations.reconcile\.external-secrets\.io/data-hash}|{.data.$KEY}"))).Trim() -split '\|')
      if ($snap.Count -ne 4 -or [string]::IsNullOrWhiteSpace([string]$snap[0]) -or [string]::IsNullOrWhiteSpace([string]$snap[3])) {
        Remove-Variable snap
        throw '인수 전 스냅샷 취득 실패(형식·빈 값) — 중단' }
      if (-not [string]::IsNullOrWhiteSpace([string]$snap[1])) {
        Remove-Variable snap
        throw '캡처하는 사이에 ESO 가 Secret 에 손댔다(같은 GET 에 managed 라벨) — 이 값은 기준값이 될 수 없다. 1R) resume 또는 PM 원본 대조로 간다' }
      # 가드 ⓓ — 라벨은 없는데 ESO 의 data-hash 어노테이션이 남아 있으면, 이 Secret 은 **이전에 인수됐다가 라벨만 지워진** 것이다(R2 뒤 재인수).
      # 그 실행은 `drilled:` 접두어도 `first-drill` 단어도 거치지 않고 정상 캡처 경로로 들어와 사람 확인 없이 두 번째 파드를 지울 수 있었다(3R 검증 B3-02).
      # 라벨은 운영자가 지울 이유가 있지만(복구 안내 2번) data-hash 어노테이션은 지울 이유가 없다 — 그래서 그것을 흔적으로 쓴다.
      $dhPre = [string]$snap[2]
      $preUid = [string]$snap[0]
      $preHash = & $sha ([string]$snap[3])
      Remove-Variable snap
      if (-not [string]::IsNullOrWhiteSpace($dhPre)) {
        Write-Warning "managed 라벨은 없는데 ESO 의 data-hash 어노테이션이 남아 있다($dhPre) = 이 Secret 은 이전에 인수됐다가 라벨만 지워진 상태다 — 이 실행은 **첫 인수가 아니라 재인수**다"
        & $stop '1D) 이 Secret 은 이전에 인수된 적이 있다(data-hash 어노테이션이 남아 있다) — 재인수로 진행하려면 readopt 입력' 'readopt'
        $rd = (& $ask '이전 인수에서 이미 파드 1개를 교체했는가 — 교체했으면 drilled(이 실행은 파드를 삭제하지 않는다) · 이 재인수에서 아직 한 번도 교체하지 않았으면 first(4) 단어가 first-drill 로 갈린다)').Trim()
        if ([string]::Equals($rd, 'drilled', [StringComparison]::Ordinal)) { $preDrilled = $true }
        elseif ([string]::Equals($rd, 'first', [StringComparison]::Ordinal)) { $reAdopt = $true }
        else { throw '1D) 에서 중단 — drilled 도 first 도 아니다(모르겠으면 drilled 를 넣는다: 삭제 0 이 안전한 쪽이다)' } }
      $pp = & $pods '인수 전 파드'
      if (@($pp.items).Count -ne 2) { throw "파드가 2개가 아니다($(@($pp.items).Count) 개) — 노드당 1개 전제가 깨졌다. 드릴을 할 수 없으므로 중단" }
      foreach ($p in $pp.items) {
        if (-not [string]::Equals($p.ready, 'True', [StringComparison]::Ordinal)) { throw "파드 $($p.name) 이 Ready 가 아니다 — 한쪽 커넥터가 이미 불안정하다. 중단" } }
      $podPre = $pp.sig
      $log['1) 머지 전 캡처'] = "완료(키 1개 · ES 부재 · 단일 GET 스냅샷 · 파드 2개 Ready$(if ($preDrilled) { ' · 1D 라벨 없는 재인수 — 이미 드릴함, 이 실행은 삭제 0' } elseif ($reAdopt) { ' · 1D 라벨 없는 재인수 — 이 재인수의 첫 드릴' } else { '' }))" }
    # preHash·preUid 는 비밀이 아니다(고엔트로피 값의 SHA-256 과 UID). 블록이 죽었을 때 1R) resume 과 g4-restore 에 필요하니 적어 둔다.
    "기준값 preHash = $preHash$pmNote"
    "기준값 preUid  = $preUid"
    "기준값 파드서명 = $podPre$(if ($preDrilled) { ' (이미 드릴했다고 선언됐다 — 이 실행은 파드를 삭제하지 않는다)' } else { '' })"
    '↑ 세 줄을 손으로 적어 둔다(파일에 남기지 않는다). 블록이 중간에 죽으면 1R) resume 와 g4-restore.ps1 이 이 값을 요구한다.'
    '   ⚠ 파드 서명은 **마지막 요약이 권위 있는 값**이다 — 요약에 drilled: 로 시작하는 서명 줄이 나오면, 다음 실행에는 이 줄이 아니라 그 줄을 접두어째 넣는다.'
    # ---------- 1P) PM 원본 대조(머지 **전**에만 의미가 있다) ----------
    # g4-restore.ps1 이 받는 입력은 단 하나 — "해시가 preHash 와 같은 PM 토큰"이다. PM 이 라이브와 같다는 것은 어디서도 검증된 적이 없다
    # (OP1 은 kv 를 **라이브 Secret** 에서 시드했지 PM 에서 시드하지 않았다). 지금 틀리면 아무것도 잠기지 않았지만,
    # 비상 중에 발견하면 복구 블록이 막다른 길이 된다. 평문은 변수에 담지 않고 해시 식 안에서만 지나간다.
    # 기준값이 PM 유도(1R) pm)면 이 대조는 **같은 출처끼리의 비교**다 — 무엇을 넣어도 일치하므로 아무것도 검증하지 못하면서
    # 화면과 요약에는 "PM 해시 = preHash"라는 통과 기록만 남는다. 그래서 그 실행에서는 정지점 자체를 내지 않는다.
    $pmAns = 'pm-derived'
    if ($preFromPm) { Write-Warning '1P) PM 원본 대조를 건너뛴다 — 기준값이 방금 그 PM 원본에서 유도한 값이라 자기 자신과의 대조가 된다(항상 일치한다). 이 실행의 기준값은 라이브로 검증된 적이 없다' }
    else { $pmAns = (& $ask '1P) PM 의 터널 토큰이 방금 잡은 기준값과 같은지 지금 검증한다(g4-restore 가 받는 유일한 입력이다) — 검증 = pm · 건너뜀 = skip-pm').Trim() }
    if ([string]::Equals($pmAns, 'pm-derived', [StringComparison]::Ordinal)) {
      $log['1P) PM 원본 대조'] = '건너뜀(기준값이 PM 유도라 같은 출처 대조는 성립하지 않는다 — 라이브 검증 없음)' }
    elseif ([string]::Equals($pmAns, 'pm', [StringComparison]::Ordinal)) {
      $ch = (Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory
      if ($null -eq $ch -or $ch -ne 0) { throw '클립보드 기록이 꺼져 있음을 확인하지 못했다 — 설정 > 시스템 > 클립보드에서 끄고 다시(토큰 미입력 · 아직 아무것도 하지 않았다)' }
      $pmHash = & $sha ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((& $readSecret 'PM 의 터널 토큰 원본(화면에 남지 않음)').Trim())))
      if (-not [string]::Equals($pmHash, $preHash, [StringComparison]::Ordinal)) {
        Remove-Variable pmHash
        throw 'PM 의 토큰이 기준값과 다르다 — 머지하지 않는다. 어느 쪽이 옳은지는 이 사실만으로 알 수 없다(실행 중 컨테이너는 시작 시점의 값을 쓰므로 라이브가 현재값이라는 보장이 없다): Cloudflare 대시보드나 tofu -chdir=infra/cloudflare output -raw tunnel_token 과 대조해 옳은 쪽을 가리고, 틀린 쪽을 바로잡아 이 검증을 통과시킨 뒤에 머지한다(지금은 아무것도 잠기지 않았다)' }
      Remove-Variable pmHash
      'OK PM 토큰 해시 = preHash — R2(g4-restore.ps1) 의 입력이 유효하다'
      $log['1P) PM 원본 대조'] = '완료(PM 해시 = preHash)' }
    elseif ([string]::Equals($pmAns, 'skip-pm', [StringComparison]::Ordinal)) {
      Write-Warning 'PM 검증을 건너뛰었다 — 값이 덮였을 때 g4-restore 가 PM 토큰을 거부할 수 있다(그때 남는 출처는 Cloudflare 대시보드와 tofu output 뿐이다)'
      $log['1P) PM 원본 대조'] = '건너뜀(skip-pm)' }
    else { throw '1P) 정지점에서 중단 — pm 도 skip-pm 도 아니다' }
    # ---------- 2) 감시·폴링 시작 → 그 뒤에 머지(ES 출현 · SecretSynced 폴링 · 그동안 값·UID 감시) ----------
    # 순서를 뒤집었다: 단어가 감시를 **먼저** 시작하고, 머지는 그 뒤에 한다. 이 프롬프트에서 오타(IME 켜짐)로 죽어도 아직 아무 일도 일어나지 않았다.
    $w2 = 'merge'
    $m2 = "2) **아직 머지하지 않는다.** merge 를 입력하면 블록이 Secret 값 해시·UID 감시와 ES 폴링(최대 15분)을 먼저 시작한다 → 진행 줄('… N 초 경과')이 보이면 그때 **다른 창**에서 gh pr merge 한다(platform-secrets 가 새 리비전을 읽기까지 최대 3∼4분 — timeout.reconciliation 180초 + jitter. 2026-09-21 G3 실측 약 2분). 영문 입력 상태(IME 끔)를 확인한다"
    if ($resumed -and -not $esGone) {
      $w2 = 'continue'
      $m2 = '2) 이미 머지된 상태다(managed 라벨 · ES 존재) — **새로 머지하지 않는다.** continue 를 입력하면 ES 의 SecretSynced 를 확인하며 판정으로 이어간다' }
    elseif ($resumed -and $esGone) {
      $m2 = "2) managed 라벨은 남아 있지만 ES 가 없다 = **인수 해제 상태**(R2 를 거쳤다). 재인수라면 **아직 머지하지 않는다** — merge 를 입력하면 감시·폴링(최대 15분)을 먼저 시작한다 → 진행 줄이 보이면 다른 창에서 gh pr merge 한다. 재인수가 아니라면 그 외 입력으로 중단한다" }
    & $stop $m2 $w2
    $mergeAsked = $true
    $log['2) 머지 대기'] = "$w2 입력됨 — 폴링 도중 중단(인수 판정 미완)"
    $t0 = Get-Date
    $tick = 0
    $errN = 0
    $reason = ''
    $synced = $false
    while ((Get-Date) -lt $t0.AddSeconds(900)) {
      $hNow = & $sha (& $txt (& $kq '감시: 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
      if (-not [string]::Equals($hNow, $preHash, [StringComparison]::Ordinal)) {
        $recover = 'value'
        try { $podNow = (& $pods '복구 안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
        try { $keysNow = & $keyset } catch { $keysNow = '(조회 실패)' }
        throw '⚠ 대기 중 터널 값이 바뀌었다 — 파드를 재시작하지 않는다. 아래 복구 안내를 따른다(안전망은 컨테이너가 재시작되지 않는 동안만 유효하다)' }
      $uNow = (& $txt (& $kq '감시: UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
      if (-not [string]::Equals($uNow, $preUid, [StringComparison]::Ordinal)) {
        $recover = 'uid'
        $uidNow = $uNow
        try { $podNow = (& $pods '안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
        throw '⚠ 대기 중 Secret 이 재생성됐다(UID 변경) = 제자리 인수가 아니다 — 파드를 재시작하지 않는다. 아래 안내를 따른다' }
      $nm = (& $txt (& $kq 'ES 출현 확인' @('-n', $NS, 'get', 'externalsecret', $ESN, '--ignore-not-found', '-o', 'name'))).Trim()
      if (-not [string]::IsNullOrWhiteSpace($nm)) {
        $reason = (& $txt (& $kq 'ES reason' @('-n', $NS, 'get', 'externalsecret', $ESN, '-o', 'jsonpath={.status.conditions[?(@.type=="Ready")].reason}'))).Trim()
        if ([string]::Equals($reason, 'SecretSynced', [StringComparison]::Ordinal)) { $synced = $true; break }
        if ([string]::Equals($reason, 'SecretSyncedError', [StringComparison]::Ordinal)) {
          $errN = $errN + 1
          if ($errN -ge 3) {
            throw 'ES 가 SecretSyncedError 로 굳었다(30초 연속) — provider 실패면 Secret 의 값·UID 는 미변경이다(managed 라벨만 붙는다). 파드를 건드리지 말고 store·경로·권한을 확인한다' } }
        else { $errN = 0 } }
      $tick = $tick + 1
      if (($tick % 3) -eq 0) { "  … $([int](((Get-Date) - $t0).TotalSeconds)) 초 경과(ES=$nm reason=$reason · 값·UID 불변 확인 중)" }
      Start-Sleep -Seconds 10 }
    if (-not $synced) {
      throw "머지 뒤 15분 안에 ES 가 SecretSynced 가 되지 않았다(마지막 reason=$reason) — Argo 의 platform-secrets 동기화를 확인한다. 이 블록은 아무것도 바꾸지 않았다" }
    $log['2) 머지 대기'] = "완료(SecretSynced · 대기 $([int](((Get-Date) - $t0).TotalSeconds))초 · 값·UID 불변)"
    # ---------- 3) 인수 판정 ----------
    $postHash = & $sha (& $txt (& $kq '인수 후 값' @('-n', $NS, 'get', 'secret', $SEC, '-o', "jsonpath={.data.$KEY}"))).Trim()
    if (-not [string]::Equals($postHash, $preHash, [StringComparison]::Ordinal)) {
      $recover = 'value'
      try { $podNow = (& $pods '복구 안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
      try { $keysNow = & $keyset } catch { $keysNow = '(조회 실패)' }
      throw '⚠ 인수 뒤 터널 값이 바뀌었다 — 파드를 재시작하지 않는다. 아래 복구 안내를 따른다(안전망은 컨테이너가 재시작되지 않는 동안만 유효하다)' }
    $postUid = (& $txt (& $kq '인수 후 UID' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.uid}'))).Trim()
    if (-not [string]::Equals($postUid, $preUid, [StringComparison]::Ordinal)) {
      $recover = 'uid'
      $uidNow = $postUid
      try { $podNow = (& $pods '안내용 파드 서명').sig } catch { $podNow = '(조회 실패)' }
      throw '⚠ UID 가 바뀌었다 = 제자리 인수가 아니라 재생성이다 — 파드를 재시작하지 않는다. 아래 안내를 따른다' }
    $own = & $txt (& $kq 'ownerReferences' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.ownerReferences}'))
    if (-not [string]::IsNullOrWhiteSpace($own)) {
      throw 'ownerReferences 가 붙었다 — creationPolicy 가 Orphan 이 아니다. ES 를 지우지 말고(지우면 Secret 이 GC 된다) 매니페스트를 고친다. 파드는 건드리지 않는다' }
    # managed 라벨은 "ESO 가 이 Secret 을 대상으로 잡았다"까지만 말한다 — ESO 2.10.0 은 라벨을 provider 조회 **전에** 별도 PATCH 로 붙이고 requeue 한다.
    # 데이터를 실제로 썼다는 증거는 mutationFunc 안에서만 세팅되는 data-hash 어노테이션이다. 그래서 둘 다 하드 판정한다.
    $mg1 = (& $txt (& $kq '인수 후 managed 라벨' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.labels.reconcile\.external-secrets\.io/managed}'))).Trim()
    if (-not [string]::Equals($mg1, 'true', [StringComparison]::Ordinal)) {
      throw 'SecretSynced 인데 managed 라벨이 없다 — ESO 가 이 Secret 을 대상으로 잡지 않았다(값 불변이 자명한 통과였다). 인수 성립을 확인하기 전에는 드릴하지 않는다' }
    $trkS = & $txt (& $kq 'Secret 의 Argo tracking' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.annotations.argocd\.argoproj\.io/tracking-id}'))
    if (-not [string]::IsNullOrWhiteSpace($trkS)) {
      throw "Secret 에 Argo tracking 어노테이션이 복사됐다($trkS) — Argo 가 이 Secret 을 자기 자원으로 보게 된다(prune 위험). 매니페스트의 target.template.metadata 를 확인한다" }
    # 이 클러스터의 추적 방식은 annotation 으로 확정돼 있다(bootstrap/argocd/argocd-cm.yaml: application.resourceTrackingMethod=annotation).
    $trkE = (& $txt (& $kq 'ES 의 Argo tracking' @('-n', $NS, 'get', 'externalsecret', $ESN, '-o', 'jsonpath={.metadata.annotations.argocd\.argoproj\.io/tracking-id}'))).Trim()
    if ([string]::IsNullOrWhiteSpace($trkE)) {
      throw 'ES 의 tracking-id 가 비었다 — 단일 소유를 확인할 수 없다(추적 방식은 annotation 으로 확정이므로 비어 있으면 그 자체가 이상이다). 판정 불가' }
    if (-not [string]::Equals(([string]$trkE -split ':')[0], $OWNER, [StringComparison]::Ordinal)) {
      throw "ES 를 관리하는 Application 이 $OWNER 가 아니다($trkE) — 두 Application 이 같은 객체를 소유하면 서로 되돌린다. 중단" }
    $res = & $txt (& $kq "$APP 의 status.resources" @('-n', 'argocd', 'get', 'app', $APP, '-o', 'jsonpath={range .status.resources[*]}{.group}/{.kind} {end}'))
    if ([string]::IsNullOrWhiteSpace($res)) { throw "$APP 의 status.resources 가 비었다 — 판정 불가(빈 응답을 '0건'으로 읽지 않는다)" }
    if ($res.Contains('external-secrets.io/')) {
      throw "$APP 이 external-secrets.io 자원을 소유하고 있다($res) — ES 는 $OWNER 하나만 소유해야 한다. 중단" }
    $dh = (& $txt (& $kq 'ESO data-hash' @('-n', $NS, 'get', 'secret', $SEC, '-o', 'jsonpath={.metadata.annotations.reconcile\.external-secrets\.io/data-hash}'))).Trim()
    if ([string]::IsNullOrWhiteSpace($dh)) {
      throw 'SecretSynced 인데 data-hash 어노테이션이 없다 — ESO 의 쓰기(mutationFunc)가 이 Secret 에 닿지 않았다(managed 라벨은 provider 조회 전에 붙으므로 쓰기의 증거가 아니다). 드릴하지 않는다' }
    $pq = & $pods '인수 후 파드'
    $podPost = $pq.sig
    if ([string]::IsNullOrWhiteSpace($podPre)) {
      Write-Warning "파드 불변 판정 불가(resume · nopods 로 기준 서명이 없다) — 인수 후 서명만 기록한다: $podPost" }
    elseif (-not [string]::Equals($podPost, $podPre, [StringComparison]::Ordinal)) {
      # 서명이 다르다고 곧장 "인수가 커넥터를 교체했다"로 단정하지 않는다. 기준의 파드 하나가 서명 그대로 남아 있고 나머지 하나가
      # **ES 생성 뒤**에 시작해 Ready 라면, 그것은 이번 인수가 아니라 **이전 실행의 드릴**이 만든 상태다(드릴 뒤 재실행에서 정상적으로 나온다).
      # 그 경우에만 판정을 잇고, 4) 는 SKIP 한다(삭제 0). 그 밖에는 전과 같이 중단한다.
      $esAt0 = & $esAtGet
      $preSigs = @(@($podPre -split ' ') | Where-Object { $_.Length -gt 0 })
      $kept = @($pq.items | Where-Object { $s = [string]$_.sig
        @($preSigs | Where-Object { [string]::Equals([string]$_, $s, [StringComparison]::Ordinal) }).Count -eq 1 })
      $fresh = @($pq.items | Where-Object { $s = [string]$_.sig
        @($preSigs | Where-Object { [string]::Equals([string]$_, $s, [StringComparison]::Ordinal) }).Count -eq 0 -and [string]::CompareOrdinal([string]$_.start, $esAt0) -gt 0 -and [string]::Equals([string]$_.ready, 'True', [StringComparison]::Ordinal) })
      if (@($pq.items).Count -eq 2 -and $kept.Count -eq 1 -and $fresh.Count -eq 1) {
        $drilled = $true
        "파드 서명이 기준과 다르지만 **이전 실행의 드릴 결과**다($($kept[0].name) 는 서명 그대로 · $($fresh[0].name) 가 ES 생성 $esAt0 뒤에 시작해 Ready) — 이번 인수가 커넥터를 교체한 것이 아니다. 4) 드릴은 SKIP 한다(삭제 0)" }
      else {
        throw "파드가 바뀌었다(전= $podPre / 후= $podPost) — 인수 과정에서 커넥터가 교체·재시작됐다는 뜻이다. 원인을 확인하기 전에는 드릴하지 않는다(이전 실행의 드릴 결과라면 기준 파드 1개가 서명 그대로 남고 나머지 1개가 ES 생성 뒤에 시작해 Ready 여야 한다 — 그 조건을 채우지 못했다)" } }
    # 합격 문면은 **판정한 것만** 말한다. 판정하지 않은 항목이 게이트 문면과 런북 기록에 PASS 로 들어가지 않게 한다.
    $podNote = '파드 불변'
    if ([string]::IsNullOrWhiteSpace($podPre)) { $podNote = '파드 불변은 판정하지 않았다(resume · 기준 서명 없음)' }
    elseif ($drilled) { $podNote = '파드 불변은 판정하지 않았다(이전 실행의 드릴 결과 — 기준 1개 유지 · 새 파드 Ready)' }
    elseif ($preDrilled) { $podNote = '파드 불변(이미 드릴했다는 선언이 있다 — 이 실행은 드릴하지 않는다)' }
    "OK 값 불변 · UID 불변 · ownerRef 없음 · managed 라벨 · data-hash 있음 · Argo tracking 미복사 · 단일 소유 · $podNote"
    $judged = $true
    $log['3) 인수 판정'] = "PASS(값·UID·ownerRef·라벨·data-hash·tracking·단일 소유 · $podNote)"
    "참고(비밀 아님): ESO data-hash = $dh · ES tracking-id = $trkE"
    # ---------- 4) 파드 1개만 교체하는 드릴 ----------
    # 값이 같아도 "새 파드가 이 Secret 으로 뜬다"는 것은 아직 증명되지 않았다. 반대쪽 커넥터가 살아 있는 동안 1개만 확인한다.
    # 불변식: 삭제는 **파드 집합이 머지 전 기준과 같다고 증명된 실행에서만** 한다. 한 실행 안에서 삭제가 1건을 넘지 않는 것은
    # 변경 헬퍼의 호출 지점이 1곳뿐이라는 정적 사실이다. **실행 횟수를 통튼** 1건은 그것만으로는 성립하지 않는다 —
    # 2라운드 검증(VB2-01·VB2-02)이 두 반례를 실증했다: ① R2(ES 삭제) 뒤 재인수에서는 ES creationTimestamp 가 리셋돼
    # K8S-04 의 SKIP 이 풀린다 ② 드릴이 만든 파드가 NotReady 면 "인수 뒤 시작한 Ready 파드" 조건이 거짓이 된다.
    # 그래서 잠금을 넷으로 나눴다: `drilled:` 접두어(운영자 선언 · 무조건 SKIP) · 인수 뒤 시작한 파드가 **하나라도** 있으면 SKIP
    # (Ready 든 아니든 — NotReady 면 더더욱 지우면 안 된다) · **기준값을 이어받은 실행(1R resume)과 1D 재인수의 드릴 단어를 `first-drill` 로 갈라 사람이 확인**
    # · 라벨이 지워져 정상 캡처 경로로 들어온 재인수를 1D) 가 data-hash 어노테이션으로 잡아 같은 확인을 받는다(3R 검증 B3-02).
    # 셋째 잠금의 조건은 4R 까지 `$esGone`(= 캡처 시점에 ES 가 없다) 이었다 — **일시적 사실**이라 운영자가 블록보다 먼저 머지하면 게이트가 통째로 사라졌다(5R 검증 B4-01).
    # 5R 에 `$resumed`(= 이 실행이 머지 전 상태를 직접 보지 못했다)로 바꿨다: 그것은 이 실행의 **구조적 사실**이고 ES 상태로 뒤집히지 않는다.
    # 남는 구멍은 하나다: 운영자가 `drilled:` 를 떼고 넣거나 1D) 에 `first` 를 넣고, 이어서 `first-drill` 까지 입력하는 경우.
    # 그때는 삭제가 1건 더 일어난다 — 그래서 **두 단어를 모두 사람이 입력해야** 하고, 요약은 붙여 넣을 줄을 접두어째 인쇄한다
    # (그 두 확인을 모두 잘못 넘기는 것 말고는 경로가 없다는 것이 5R 의 상태다 · NOTES §2 · 런북에 그대로 적는다).
    if ($noGlass) {
      Write-Warning 'break-glass 1차(창 A 의 열린 세션)·2차(OCI 운영자 자격)가 모두 미확인이다 — 확인된 복구 경로가 0 인 상태에서 유일한 변경 동작(파드 1개 삭제)을 하지 않는다. 인수 판정은 위에 끝나 있다'
      "SKIP 드릴: break-glass 1차·2차가 모두 미확인이다 — 파드를 삭제하지 않는다. 창 A 세션을 열거나 OCI 운영자 자격을 복구한 뒤, 1R) resume 으로 다시 실행해 드릴만 한다"
      $nrNote = & $nrWarn $pq.items
      # 이 실행이 **드릴을 이어받은 경우에만** 체인용 줄을 남긴다. 드릴하지 않은 실행이 `drilled:` 줄을 인쇄하면
      # 다음 실행이 그 줄을 믿고 4) 를 무조건 SKIP 해 드릴이 영영 일어나지 않는다(3R 검증 B3-05·A3-4).
      if ($preDrilled -or $drilled) { $podDrill = $podPost }
      $log['4) 파드 1개 드릴'] = "거부(break-glass 1차·2차 모두 미확인 — 삭제 0) — 현재 파드: $podPost$nrNote" }
    elseif ($preDrilled) {
      "SKIP 드릴: 이미 드릴했다는 선언이 있다(파드 서명의 drilled: 접두어 또는 1D 의 drilled) = 이전 실행이 이미 파드 1개를 교체했다 — 이 실행은 삭제하지 않는다(실행 횟수를 통틀어 삭제 1건)"
      $nrNote = & $nrWarn $pq.items
      $podDrill = $podPost
      $log['4) 파드 1개 드릴'] = "건너뜀(이미 드릴했다는 선언 — 삭제 0) — 현재 파드: $podPost$nrNote" }
    elseif ($drilled) {
      "SKIP 드릴: 이전 실행의 드릴 결과가 이미 있다 — 새 파드가 이 Secret 으로 뜬다는 것은 그때 증명됐다. 삭제하지 않는다"
      $nrNote = & $nrWarn $pq.items
      $podDrill = $podPost
      $log['4) 파드 1개 드릴'] = "불필요(SKIP — 이전 실행의 드릴 결과) — 현재 파드: $podPost$nrNote" }
    elseif ([string]::IsNullOrWhiteSpace($podPre)) {
      Write-Warning '파드 기준 서명 없이(nopods) 이어 온 실행이다 — 이전 실행이 이미 파드 1개를 교체했을 수 있으므로 이 실행은 파드를 삭제하지 않는다'
      $nrNote = & $nrWarn $pq.items
      $log['4) 파드 1개 드릴'] = "건너뜀(nopods · 삭제 0) — 현재 파드: $podPost$nrNote" }
    else {
      $pd = & $pods '드릴 직전 파드'
      if (@($pd.items).Count -ne 2) { throw "파드가 2개가 아니다($(@($pd.items).Count) 개) — 드릴 전제가 성립하지 않는다. 중단" }
      # 드릴의 목적이 이미 달성돼 있으면(인수 뒤에 시작한 파드가 있으면) 삭제하지 않는다.
      # startTime·creationTimestamp 는 둘 다 초 단위 RFC3339 UTC 고정폭이라 Ordinal 문자열 순서 = 시간 순서다.
      # 조건을 **Ready 로 좁히지 않는다**(2R 검증 VB2-02): 인수 뒤에 시작한 파드가 NotReady 라는 것은 "드릴이 이미 일어났고
      # 그 결과가 불안정하다"는 뜻이다 — 그 상태에서 남은 하나를 지우는 것이 바로 전면 잠금이다.
      $esAt = & $esAtGet
      $after = @($pd.items | Where-Object { [string]::CompareOrdinal([string]$_.start, $esAt) -gt 0 })
      $already = @($after | Where-Object { [string]::Equals($_.ready, 'True', [StringComparison]::Ordinal) })
      # 이 두 SKIP 도 드릴하지 않고 끝나는 실행이다 — **반대쪽 커넥터의 Ready 를 판정하지 않은 채** "SKIP … 이미 증명됐다"로
      # 끝내면 그 OK 가 T046(두 번째 교체) 판단의 근거가 되면서 이중화 미성립이 조용히 넘어간다(3R 검증 B3-06).
      if ($already.Count -ge 1) {
        "SKIP 드릴: 인수 뒤에 시작한 파드가 이미 Ready 다($($already[0].name) · start $($already[0].start) > ES $esAt) — 새 파드가 이 Secret 으로 뜬다는 것은 이미 증명됐다. 삭제하지 않는다"
        $nrNote = & $nrWarn $pd.items
        $podDrill = $podPost
        $log['4) 파드 1개 드릴'] = "불필요(SKIP — $($already[0].name) 가 인수 뒤 시작 · Ready)$nrNote" }
      elseif ($after.Count -ge 1) {
        "SKIP 드릴: 인수 뒤에 시작한 파드가 있지만 Ready 가 아니다($($after[0].name) · start $($after[0].start) > ES $esAt) — 드릴은 이미 일어났고 그 결과가 불안정하다는 뜻이다. 삭제하지 않는다"
        Write-Warning "⚠ $($after[0].name) 가 인수 뒤에 시작했는데 Ready 가 아니다 — 지금 남은 하나를 지우면 경로가 모두 끊긴다. 이벤트·로그로 그 파드의 원인을 먼저 해결한다(두 번째 파드는 절대 교체하지 않는다)"
        $nrNote = & $nrWarn $pd.items
        $podDrill = $podPost
        $log['4) 파드 1개 드릴'] = "건너뜀(SKIP — $($after[0].name) 가 인수 뒤 시작 · Ready 아님 · 삭제 0)$nrNote" }
      else {
        # 대상 = startTime 이 **가장 늦은** 파드. 이러면 재실행은 항상 "이미 교체된 쪽"을 다시 교체하고, 옛 값을 든 커넥터는 끝까지 남는다.
        # startTime 이 빈 Pending 파드는 '|'(0x7C) > 숫자라 자동으로 대상 쪽으로 간다.
        $ord = @($pd.items | ForEach-Object { "$($_.start)|$($_.name)" })
        [Array]::Sort($ord, [StringComparer]::Ordinal)
        $survivor = [string](($ord[0] -split '\|')[1])
        $target = [string](($ord[1] -split '\|')[1])
        $sv0 = @($pd.items | Where-Object { [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) })[0]
        $tg0 = @($pd.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) })[0]
        if (-not [string]::Equals($sv0.ready, 'True', [StringComparison]::Ordinal)) {
          throw "남길 파드 $survivor 가 Ready 가 아니다 — 지금 하나를 지우면 경로가 모두 끊길 수 있다. 삭제하지 않는다" }
        if (-not [string]::Equals($tg0.ready, 'True', [StringComparison]::Ordinal)) {
          Write-Warning "삭제 대상 $target 이 Ready 가 아니다 — 드릴 결과 해석에 주의한다(원래 불안정했을 수 있다)" }
        $survSig = [string]$sv0.sig
        # R2(인수 해제) 뒤의 재인수는 ES 가 새로 만들어져 creationTimestamp 가 리셋된다 — 위의 "인수 뒤 시작" 판정이
        # 이전 실행의 드릴을 더 이상 보지 못한다. 그 실행에서만 단어를 갈라, "이 재인수의 첫 드릴"임을 사람이 확인하게 한다.
        # 0) 의 break-glass 확인과 여기 사이에는 최대 15분의 폴링과 이 정지점의 **무한정 사람 대기**가 있다 — 그 사이 창 A 세션이
        # 끊길 수 있는데 블록은 그것을 보지 못한다(삭제 직전 재확인은 kubectl = 터널만 본다. 그것은 "창 A 의 이미 열린 세션이 산다"의
        # 증거가 아니다 — 0) 의 설계 근거가 바로 그 구분이다). 그래서 사람에게 1줄로 다시 묻는다(3R 검증 B3-04).
        $bg4 = ' ⚠ **지금 창 A 에서 Enter 를 쳐 세션이 살아 있는지 확인했으면** 단어를 입력한다 — 끊겨 있으면 먼저 다시 열고(그동안 이 정지점은 기다린다), 그래도 안 열리면 그 외 입력으로 중단한다.'
        $w4 = 'drill'
        $m4 = "4) 드릴: $target **하나만** 삭제해 새 파드가 이 Secret 으로 뜨는지 본다(남길 파드 $survivor 는 Ready 확인됨). 새 파드가 Ready 가 안 되면 남은 파드는 절대 건드리지 않는다. ⚠ 창 A 의 ssh 세션이 삭제 대상 커넥터를 타고 있었다면 약 30초 뒤 끊긴다(정상) — 끊기면 드릴이 끝난 직후 다시 연다.$bg4"
        # 게이트는 **기준값의 출처**에 건다(5R 검증 B4-01). `$esGone` 은 캡처 순간의 ES 유무라서, 운영자가 블록보다 먼저 머지하면
        # 같은 재인수인데도 거짓이 되어 게이트가 통째로 사라졌다. `$resumed` 는 "이 실행이 머지 전 상태를 직접 보지 못했다"는
        # 구조적 사실이고 ES 상태로 뒤집히지 않는다. 정상 첫 인수(정상 캡처 경로)는 이 실행이 인수 전 상태를 직접 확인했으므로 `drill` 그대로다.
        if ($resumed -or $reAdopt) {
          $w4 = 'first-drill'
          $m4 = "4) ⚠ 이 실행은 $(if ($esGone) { '**R2(인수 해제) 뒤의 재인수**다 — ES 가 지워진 상태로 왔다' } elseif ($reAdopt) { '**라벨만 지워진 재인수**다 — 1D 정지점에서 확인했다: managed 라벨이 지워졌고 data-hash 어노테이션이 남아 있었다' } else { '**기준값을 이어받은 실행(1R resume)**이다 — 머지 전 상태를 이 실행에서 직접 보지 못했다(이미 머지된 재인수라면 ES 가 살아 있어도 같은 상황이다)' }). 이 블록은 이 인수에서 드릴이 이미 있었는지 스스로 알 수 없다 — ES 가 다시 만들어졌으면 '인수 뒤 시작' 시각 판정도 함께 리셋되기 때문이다. 이전 실행에서 이미 파드를 교체했다면 **여기서 중단**하고, 파드 서명에 drilled: 를 붙이거나 1D 에 drilled 를 넣어 다시 실행한다(그러면 삭제 0). 이 인수에서 아직 한 번도 교체하지 않았다면 $target 하나만 삭제한다(남길 파드 $survivor 는 Ready 확인됨). ⚠ 창 A 의 ssh 세션이 삭제 대상 커넥터를 타고 있었다면 약 30초 뒤 끊긴다(정상).$bg4" }
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
        $sv1 = @($pd2.items | Where-Object { [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) })
        if ($sv1.Count -ne 1 -or -not [string]::Equals($sv1[0].ready, 'True', [StringComparison]::Ordinal) -or -not [string]::Equals([string]$sv1[0].sig, $survSig, [StringComparison]::Ordinal)) {
          throw "정지점 사이에 남길 파드 $survivor 의 상태가 바뀌었다 — 삭제하지 않는다" }
        if (@($pd2.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) }).Count -ne 1) {
          throw "삭제 대상 $target 이 이미 사라졌다 — 상태를 다시 확인하고 처음부터 판단한다" }
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
          $nw = @($pn.items | Where-Object { -not [string]::Equals($_.name, $survivor, [StringComparison]::Ordinal) -and -not [string]::Equals($_.name, $target, [StringComparison]::Ordinal) })
          if ($nw.Count -eq 1 -and [string]::Equals([string]$nw[0].ready, 'True', [StringComparison]::Ordinal)) { $newName = [string]$nw[0].name; $podDrill = [string]$pn.sig; break }
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
        $log['4) 파드 1개 드릴'] = "완료(삭제 $target → 새 파드 $newName Ready · 로그 확인 $hit)" } }
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
    # 정리를 먼저 한다(이 블록은 자격을 잡지 않지만 값이 스쳐 간 변수를 지우고 클립보드를 비운다). 그 뒤는 Write-Host/Write-Warning 만 —
    # Ctrl+C 중지 중에는 첫 "성공 스트림" 출력문에서 finally 가 끊긴다.
    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, own, trkS, trkE, res, dh, nd, so, sp, oo, out, raw, pmHash, tok -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 1P·1R 에서 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다' }
    Write-Host ''
    Write-Host '--- G4 단계 요약(런북 §3 기록용) ---'
    foreach ($e in $log.GetEnumerator()) { Write-Host ('{0,-20} {1}' -f $e.Key, $e.Value) }
    if (-not [string]::IsNullOrWhiteSpace($preHash)) {
      Write-Host "기준값 preHash = $preHash$pmNote"
      Write-Host "기준값 preUid  = $preUid"
      Write-Host '(둘 다 비밀이 아니다 — 고엔트로피 값의 SHA-256 과 UID 다. 다만 "이 토큰이 그 토큰인가"를 확인시켜 주는 값이므로 공개 채널에는 올리지 않는다)' }
    # ⚠ 이 줄과 아래 `드릴 후 파드서명` 줄은 값이 **글자 하나까지 같을 수 있다**(드릴을 이어받기만 한 실행: $podDrill = $podPost = $podPre).
    # 접두어를 뗀 쌍둥이 값을 `기준값 파드서명` 이라는 권위 있는 이름으로 나란히 인쇄하면, 런북에 옮겨 적는 운영자가 그 줄을
    # 다음 실행에 넣어 `drilled:` 잠금을 스스로 푼다(3R 검증 A3-1). 4R 은 이름과 단서만 바꿨는데 값은 그대로 남아 있었다(5R 검증 B4-03) —
    # 그래서 **값이 같으면 값을 아예 인쇄하지 않고**, 다른 경우(이 실행이 실제로 드릴했다)에만 단서를 달아 인쇄한다.
    if (-not [string]::IsNullOrWhiteSpace($podPre)) {
      if ([string]::IsNullOrWhiteSpace($podDrill)) { Write-Host "기준값 파드서명 = $podPre" }
      elseif ([string]::Equals($podDrill, $podPre, [StringComparison]::Ordinal)) { Write-Host '기준값 파드서명: 이 실행의 입력은 아래 drilled: 줄과 값이 같다 — 여기에 값을 다시 찍지 않는다(다음 실행에는 아래 줄을 접두어째 넣는다).' }
      else { Write-Host "기준값 파드서명(이 실행의 입력 · 다음 실행에는 이 줄이 아니라 아래 drilled: 줄을 넣는다) = $podPre" } }
    if (-not [string]::IsNullOrWhiteSpace($podDrill)) {
      Write-Host "드릴 후 파드서명 = drilled:$podDrill"
      Write-Host '↑ 다음 실행의 1R) 파드 서명에는 이 줄의 값을 **drilled: 접두어째 그대로** 넣는다 — 그 실행은 파드를 삭제하지 않는다.'
      Write-Host '   접두어를 떼면 다음 실행은 4) 에서 단어가 first-drill 로 갈려 한 번 더 묻는다(1R resume 은 언제나 그렇다) — 거기서도 잘못 답하면 드릴이 한 번 더 돈다.' }
    if ($changes.Count -eq 0) { Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).' }
    else {
      Write-Host "이 실행이 클러스터에 가한 변경: $($changes.Count) 건"
      foreach ($c in $changes) { Write-Host "  $c" } }
    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
      Write-Warning '인수 판정이 끝나지 않았다 — 머지가 이미 됐다면 ESO 가 Secret 을 덮었을 수 있다. 판정 PASS 전에는 cloudflared 파드를 재시작·삭제하지 않는다. 이 블록을 다시 실행하면 1R) resume 으로 판정만 잇는다.'
      Write-Warning '⚠ 미판정 상태를 미루지 않는다 — env 는 컨테이너가 시작할 때마다 다시 읽히므로 값이 덮였다면 다음 재시작에서 드러난다. 판정이 끝날 때까지 노드 재부팅·SUC Plan·drain·Deployment 수정 금지.' }
    if ([string]::Equals($recover, 'uid', [StringComparison]::Ordinal)) {
      Write-Host ''
      Write-Host '=== 안내(UID 만 바뀌었다 · 값 해시는 preHash 와 같다) ==='
      Write-Host '값은 옳다 — kv 는 틀리지 않았다. kv-correct.ps1 · g4-restore.ps1 은 필요 없다(쓰면 안 된다).'
      Write-Host '누군가 Secret 을 지웠고 ESO 가 다음 refresh(≤5분)에 다시 만들었다는 뜻이다(Orphan 은 isSecretValid 가 항상 true 라 즉시 재생성이 아니다 — DR1 실측 302초).'
      Write-Host '누가 지웠는지(Argo prune 이력 · 다른 창의 kubectl)를 먼저 확인한다. 파드는 건드리지 않는다.'
      Write-Host "   캡처 시 파드서명: $podPre"
      Write-Host "   지금   파드서명: $podNow"
      Write-Host "   기준값 preUid : $preUid"
      Write-Host "   지금   UID    : $uidNow   ← 1R) resume 의 preUid 에는 **이 값**을 넣는다(UID 는 비밀이 아니다)"
      Write-Host '   (다시 읽으려면: kubectl -n cloudflared get secret cloudflared-tunnel -o ''jsonpath={.metadata.uid}'')'
      Write-Host '원인을 확인한 뒤 1R) resume 으로 다시 돌린다(preUid 에는 위의 새 UID 를 넣는다).' }
    elseif ([string]::Equals($recover, 'value', [StringComparison]::Ordinal)) {
      Write-Host ''
      Write-Host '=== 복구 안내(터널 값이 바뀌었다) ==='
      if ($preFromPm) {
        Write-Host '⚠ 이 실행의 기준값 preHash 는 1R) pm 으로 **PM 원본에서 유도**한 값이다 — 라이브로 검증된 적이 없다.'
        Write-Host '   그러므로 "라이브가 틀렸다"와 "PM 이 낡았다"가 **모두** 가능하다. 아래 1·2·3 으로 가기 전에 먼저 어느 쪽이 틀렸는지 가린다:'
        Write-Host '   Cloudflare 대시보드 또는  tofu -chdir=infra/cloudflare output -raw tunnel_token  과 대조한다(출력은 파이프로만).'
        Write-Host '   PM 이 낡은 것이라면 라이브 값은 옳다 — 아무것도 쓰지 않는다(kv 를 PM 값으로 정정하면 옳은 값을 낡은 값으로 덮는다).'
        Write-Host '   ⚠ 이 경우 g4-restore.ps1 의 해시 게이트는 같은 PM 토큰을 그대로 통과시키는 **자기 자신 비교**라 방어가 되지 않는다.' }
      Write-Host '0. 안전망은 **컨테이너가 재시작되지 않는 동안만** 유효하다. env(secretKeyRef)는 파드가 아니라 컨테이너가 시작할 때마다 다시 읽힌다 —'
      Write-Host '   liveness(/ready 60초 연속 실패)·OOMKill(256Mi)·노드 재부팅·drain 이면 **같은 파드 이름으로도** 틀린 값을 읽는다. 복구를 미루지 않는다.'
      Write-Host "   캡처 시 파드서명: $podPre"
      Write-Host "   지금   파드서명: $podNow   ← restartCount 가 늘었으면 그 커넥터는 이미 새 값으로 떠 있다"
      Write-Host '   복구가 끝날 때까지 노드 재부팅·SUC Plan·drain·Deployment 수정 금지. 전면 재시작은 절대 하지 않는다.'
      Write-Host "   지금 Secret 의 키 집합: $keysNow   (기대: $KEY · 비밀이 아니다 — 키 이름만 읽었다)"
      if ([string]::Equals($keysNow, $KEY, [StringComparison]::Ordinal)) {
        Write-Host '   → 키 집합은 정상이다. 원인은 ①kv 값 또는 ③일시적 덮어씀 쪽이다(②ES 매핑은 아니다).' }
      elseif ([string]::Equals($keysNow, '(조회 실패)', [StringComparison]::Ordinal)) {
        Write-Host '   → 키 집합을 읽지 못했다(조회 실패를 "정상"으로 읽지 않는다). 먼저 직접 확인한다:' }
      else {
        Write-Host '   → ⚠ 키 집합이 기대와 다르다 = **원인은 ②ES 매핑**이다. R1(kv 정정)은 무의미하니 건너뛰고 곧장 R2 로 간다.' }
      Write-Host '     kubectl -n cloudflared get secret cloudflared-tunnel -o ''go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'''
      Write-Host '0b. 오경보 먼저 확인(비파괴): g4-restore.ps1 을 preHash·preUid 로 돌려 2) 의 해시 대조가 **SKIP(이미 기준값과 같다)** 이면 값은 옳다 —'
      Write-Host '    이 블록의 판정이 오경보였다는 뜻이므로 아무것도 쓰지 않고 끝낸다(복구 블록은 SKIP 경로에서 토큰을 묻지 않는다).'
      Write-Host '    ⚠ 전제: g4-restore 는 해시 대조에 닿기 전에 **클립보드 기록 꺼짐 · admin kubeconfig · patch secrets 권한**을 하드 검사한다(SKIP 경로에서도 그렇다).'
      Write-Host '       클립보드 기록이 켜진 창에서는 그 검사에서 먼저 멈춘다 — 그것은 "값이 틀렸다"는 뜻이 아니다.'
      Write-Host '1. ①kv 값이 틀린 경우 → R1(비파괴 · 1순위): kv-correct.ps1 로 kv/platform/cloudflare/tunnel .token 을 정정한다.'
      Write-Host '   값의 출처는 **c(PM 직접 입력)뿐**이다 — a(라이브 Secret)는 지금 덮인 값을 읽어 SKIP 만 내고, b($pre)는 이 블록이 만들지 않는 세션 변수다.'
      Write-Host '   PM 마저 틀렸을 때만: tofu -chdir=infra/cloudflare output -raw tunnel_token | Set-Clipboard → 출처 c 프롬프트에 붙여넣기'
      Write-Host '   (kv-correct 의 비밀 입력은 -AsSecureString 으로 받은 **직후 클립보드를 비운다**).'
      Write-Host '   ⚠ kv-correct 가 SKIP("새 값이 현재 kv 값과 같다")을 내면 kv 는 이미 옳다 = 원인은 ②매핑·ESO 쪽이다 → R1 을 접고 곧장 R2 로 간다.'
      Write-Host '   정정 뒤 ESO 가 다시 썼는지 먼저 본다: kubectl -n cloudflared get externalsecret cloudflared-tunnel -o ''jsonpath={.status.refreshTime}'''
      Write-Host '   그 시각이 kv 정정 시각보다 뒤일 때 이 블록을 1R) resume 으로 다시 돌린다(먼저 돌리면 같은 "값이 바뀌었다"가 다시 나온다).'
      Write-Host '2. ②ES 매핑이 틀린 경우(TUNNEL_TOKEN 키가 없거나 다른 키가 생겼다) → R1 은 무의미하다. 곧장 R2:'
      Write-Host '   revert PR 머지 → Argo 반영 확인 → delete externalsecret → g4-restore.ps1 로 값 복구.'
      Write-Host '   (키가 사라진 상태는 값이 틀린 것보다 나쁘다 — 컨테이너가 시작하면 CreateContainerConfigError 로 아예 뜨지 못한다.)'
      Write-Host '   확인 명령: kubectl -n argocd get app platform-secrets -o ''jsonpath={.status.sync.revision}'''
      Write-Host '            kubectl -n argocd get app platform-secrets -o ''jsonpath={range .status.resources[?(@.kind=="ExternalSecret")]}{.name}/{.requiresPruning}{"\n"}{end}'''
      Write-Host '   ⚠ ES 에는 finalizer 가 있다 — delete 는 ESO 컨트롤러가 Running 이고 webhook 이 Ready 일 때만 끝난다. 컨트롤러를 먼저 scale 0 하지 않는다.'
      Write-Host '     webhook 이 죽어 DELETE 가 거부되면: kubectl delete validatingwebhookconfiguration externalsecret-validate 뒤 재시도(selfHeal 이 곧 되살린다).'
      Write-Host '   (Orphan 이라 Secret 은 남는다 · 평시 금지 · 이 비상 시에만)'
      Write-Host '   ⚠ R2 뒤에도 Secret 의 managed 라벨은 남는다 — 재인수 때 g4-adopt 는 항상 1R) resume 경로로 간다(ES 가 없으면 2) 가 재머지 분기로 갈린다).'
      Write-Host '     재인수는 **g4-adopt 를 먼저 띄운 뒤**(ES 가 없는 상태에서) 2) 정지점에서 머지한다 — 먼저 머지해도 4) 단어는 first-drill 로 갈리지만(1R resume 은 언제나 그렇다),'
      Write-Host '     그 순서라야 "ES 없음 = 인수 해제 상태"가 화면·요약·런북에 기록으로 남는다.'
      Write-Host '     정상 캡처 경로로 되돌리려고 라벨을 지우는 것은 **g4-restore 가 SKIP(해시 일치)을 낸 뒤에만** 한다 — 라벨을 먼저 지우면 가드 ⓐ 가 풀려 덮인 값이 기준값이 된다.'
      Write-Host '     ⚠ 라벨을 지우면 drilled: 접두어와 first-drill 잠금도 함께 풀린다 — 그 재인수를 붙잡는 것은 ESO 의 data-hash 어노테이션뿐이다(가드 ⓓ · 1D 정지점).'
      Write-Host '       그러니 **data-hash 어노테이션은 어떤 경우에도 지우지 않는다.** 이전 실행이 이미 파드를 교체했다면 1D) 에 drilled 를 넣는다(그 재인수의 삭제는 0 이 된다).'
      Write-Host '3. ③kv 도 매핑도 옳은데 Secret 만 틀어진 경우 → ES 가 살아 있으면 ≤5분(Periodic 5m) 안에 ESO 가 스스로 되돌린다. 기다린 뒤 1R) resume.'
      Write-Host '   기다리는 동안의 노출(컨테이너 재시작)을 줄이려면 g4-restore.ps1 을 **temporary** 로 돌려 옳은 값을 놓는다 —'
      Write-Host '   ES 가 살아 있으면 그 값도 ≤5분 뒤 다시 덮이므로, R1·R2 가 끝날 때까지 5분 단위로 되풀이하는 임시 조치다(근본 해결이 아니다).'
      Write-Host '4. R3(이미 잠겼다 — 두 커넥터가 모두 내려가 kubectl·ssh 가 다 막혔다): **이 두 PowerShell 블록은 터널을 전제로 하므로 R3 에서는 쓸 수 없다.**'
      Write-Host '   경로: 창 A 의 열린 ssh 세션(살아 있다면) → 없으면 OCI CLI 로 NSG 임시 22 규칙(infra/oci/instances.tf 5단계 · OCID 는 tofu -chdir=infra/oci output -raw nsg_cluster_id) → 노드 직접 SSH. 복구 뒤 8단계로 규칙 제거.'
      Write-Host '   ① 먼저 GitHub 웹에서 revert PR 을 머지한다(터널 밖에서 된다). ES 가 살아 있으면 아래 ③ 이 ≤5분 뒤 다시 덮인다.'
      Write-Host '   ② 노드 셸(bash)에서 Argo 반영을 확인하고 ES 를 지운다(ES 에는 finalizer 가 있다 — 위 2번의 webhook 단서를 그대로 적용한다:'
      Write-Host '     delete 가 Terminating 에서 멎으면 ESO 컨트롤러 Running·webhook Ready 를 확인하고, 죽었으면 validatingwebhookconfiguration externalsecret-validate 를 지운 뒤 재시도):'
      Write-Host '     sudo k3s kubectl -n argocd get app platform-secrets -o "jsonpath={.status.sync.revision}"'
      Write-Host '     sudo k3s kubectl -n cloudflared delete externalsecret cloudflared-tunnel'
      Write-Host '   ③ 노드 셸(bash)에서 값 복구. ⚠ 붙여넣기에 개행이 섞이면 read 는 **첫 줄만** 먹고 나머지가 그대로 셸 명령으로 실행돼 화면·~/.bash_history 에 남는다'
      Write-Host '     (토큰 앞에 개행이 있으면 T 는 빈 값이 되고 토큰 **전체**가 히스토리로 간다). 그래서 먼저 히스토리를 끄고, 형식·길이를 검사한 뒤에만 쓴다.'
      Write-Host '     토큰 자체는 argv 에 실리지 않는다(read·printf 는 셸 내장 · base64 와 kubectl 은 stdin 으로만 받는다).'
      Write-Host '     ⚠ 이 조각은 **첫 줄(set +o history)부터** 실행한다 — 중간(read 줄)부터 다시 붙여 넣지 않는다. 마지막 줄이 히스토리를 다시 켜므로,'
      Write-Host '       재시도할 때도 반드시 첫 줄부터다. (case 줄의 ''!'' 를 따옴표로 감싼 것은 대화형 bash 의 히스토리 확장 때문이다 —'
      Write-Host '        따옴표가 없으면 그 자리가 직전 명령으로 치환돼 패턴이 **직전 명령에 따라 제멋대로 바뀐다** — 정상 토큰을 BROKEN-PASTE 로 읽기도 하고,'
      Write-Host '        치환 결과가 [:~] 같은 모양이 되면 깨진 토큰을 그냥 통과시키기도 한다. 보호하는 것은 여는 대괄호가 아니라 **첫 느낌표 다음 글자**다 —'
      Write-Host '        느낌표 두 개는 유효한 이벤트라 확장되고, 느낌표 뒤에 따옴표가 오면 이벤트가 만들어지지 않는다. 2026-09-21 bash 5.2.21 대화형 실측.)'
      Write-Host '     set +o history'
      Write-Host '     read -rsp "PM token: " T; echo'
      Write-Host '     unset B'
      Write-Host '     case "$T" in ''''|*[!''!''-~]*) echo BROKEN-PASTE;; *) if [ "${#T}" -ge 32 ]; then B=$(printf ''%s'' "$T" | base64 -w0); else echo TOO-SHORT; fi;; esac'
      Write-Host '     unset T'
      Write-Host '     if [ -n "$B" ]; then printf ''{"apiVersion":"v1","kind":"Secret","type":"Opaque","metadata":{"name":"cloudflared-tunnel","namespace":"cloudflared"},"data":{"TUNNEL_TOKEN":"%s"}}'' "$B" | sudo k3s kubectl apply --server-side --force-conflicts --field-manager=t045-restore -f -; fi'
      Write-Host '     unset B'
      Write-Host '     sudo k3s kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath=''{.data.TUNNEL_TOKEN}'' | sha256sum'
      Write-Host '     set -o history'
      Write-Host '     ↑ 마지막 sha256sum 결과를 적어 둔 preHash 와 **대소문자 무시**로 대조한다(preHash 는 이 base64 문자열의 SHA-256 이라 그대로 맞는다).'
      Write-Host '     판정은 네 갈래다 — 이 넷을 섞지 않는다:'
      Write-Host '       (0) **apply 줄에 kubectl 오류가 찍혔다 → 쓰기는 0건이다.** 오류가 field is immutable 이면 이 조각이 하드코딩한'
      Write-Host '           "type":"Opaque" 가 라이브 type 과 다르다는 뜻이다(Secret 의 type 은 불변 필드다). 실제 type 을 읽어 그 값으로 바꾼 뒤 첫 줄부터 다시 실행한다:'
      Write-Host '             sudo k3s kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath=''{.type}'''
      Write-Host '           (그 밖의 오류면 문면을 먼저 읽는다 — 재시도만으로는 풀리지 않는다. 이 갈래에서는 아래 (2) 의 "이미 썼을 수 있다"로 가지 않는다.)'
      Write-Host '       (1) BROKEN-PASTE·TOO-SHORT 가 찍혔다 → 쓰기는 **0건**이다(apply 가 아예 실행되지 않았다). 첫 줄부터 다시 붙여 넣는다.'
      Write-Host '       (2) 해시가 다르다 → **이미 썼는데 값이 틀렸을 수 있다.** 형식만 맞는 다른 토큰이 Secret 을 덮었을 수 있다.'
      Write-Host '       (3) 해시가 빈 입력의 해시 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 이거나'
      Write-Host '           **마지막 되읽기 줄(get … | sha256sum)** 에 kubectl 오류가 찍혔다 → 되읽기 자체가 실패한 것이다'
      Write-Host '           (파이프라인 종료 코드는 0 이라 조용히 지나간다). 값은 옳게 복구됐을 수도 있다. ※ apply 줄의 오류는 (3) 이 아니라 (0) 이다.'
      Write-Host '     (2)(3) 어느 쪽이든 **"쓰지 않았다"고 가정하지 않는다** — 옳은 토큰으로 첫 줄부터 다시 실행해 해시가 맞을 때까지 파드를 건드리지 않는다.'
      Write-Host '     ⚠ BROKEN-PASTE 가 뜬 순간 토큰의 일부 또는 전부가 **이 터미널 화면에 이미 에코됐다**(히스토리와는 별개다 — set +o history 는 기록만 막는다).'
      Write-Host '       스크롤백·세션 로그(tmux·screen·터미널 로깅)를 지우고, 토큰 회전 여부는 T084 에서 판단한다.'
      Write-Host '     sudo 는 -S 없이는 stdin 에서 암호를 읽지 않는다 — tty 가 없고 askpass 도 없으면 "no tty present" 로 중단할 뿐 파이프를 먹지 않는다.'
      Write-Host '       그래도 암호를 묻는 환경이면 조각을 시작하기 전에 sudo -v 로 자격을 캐시한다.'
      Write-Host '   ④ 위 sha256sum 대조로 값이 옳은 것을 확인한 뒤에만 파드를 **1개만** 지운다(드릴 규칙 그대로 · 전면 재시작 금지):'
      Write-Host '     sudo k3s kubectl -n cloudflared get pods -l app=cloudflared'
      Write-Host '     sudo k3s kubectl -n cloudflared delete pod POD_NAME     # POD_NAME = 위 목록의 이름 **하나**(그대로 붙여 넣으면 bash 문법 오류가 나지 않는다)'
      Write-Host '5. 복구 전에 preHash·preUid 를 적어 둔다(위 줄). g4-restore.ps1 이 PM 토큰을 검증할 때 쓴다.' }
  }
}
