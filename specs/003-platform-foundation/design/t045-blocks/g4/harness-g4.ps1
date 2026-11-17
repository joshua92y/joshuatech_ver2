param([string]$Show = '', [string]$BlockDir = '')   # -Show 'G4-01' · -Show 'R-*' — 해당 시나리오 화면 출력 · -BlockDir 은 변이 시험용(블록 사본 디렉터리)
# ===== T045 G4 블록 — 모의 실행 하네스(엄격판) =====
# t045-blocks/harness.ps1 의 구조를 그대로 쓴다: PowerShell 함수가 native 명령보다 우선한다는 성질로
# kubectl·ssh·oci 를 가리고 Read-Host·Set-Clipboard·Start-Sleep·Get-Date·Get-ItemProperty 를 모의한다.
# 실제 클러스터·Vault·Cloudflare 에 접근하지 않는다. 시간은 가상이다(Start-Sleep 이 가상 시계를 진행).
# 사용: pwsh -NoProfile -File harness-g4.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not [string]::IsNullOrWhiteSpace($BlockDir)) { $here = (Resolve-Path $BlockDir).Path }
$blocks = [ordered]@{
  adopt   = Join-Path $here 'g4-adopt.ps1'
  restore = Join-Path $here 'g4-restore.ps1'
  drill = Join-Path $here 'g4-drill.ps1'
}
# ---------------------------------------------------------------- 가짜 값(시크릿 아님 · 노출 검사 대상)
$TOK_JSON  = '{"a":"acct-0123456789abcdef","t":"11112222-3333-4444-5555-666677778888","s":"sec<>&''\"x-0123456789abcdefghijklmnop"}'
$TOK       = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($TOK_JSON))          # 터널 토큰 원본(base64-JSON{a,t,s})
$TOK2_JSON = '{"a":"acct-WRONGWRONGWRONG","t":"99998888-7777-6666-5555-444433332222","s":"sec-WRONG-0123456789abcdefghijklmn"}'
$TOK2      = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($TOK2_JSON))         # kv 가 틀렸을 때 덮이는 값
function B64 { param($s) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$s)) }
function SHA { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
$PRE_HASH = SHA (B64 $TOK)
$PRE_UID  = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d'
$SECRETS_NEVER_ON_SCREEN = @($TOK, $TOK2, $TOK_JSON, $TOK2_JSON, (B64 $TOK), (B64 $TOK2))
# 누출 검사는 **전체 문자열 포함**만으로는 부족하다 — 앞 16자만 찍는 변이가 그대로 빠져나갔다.
# 각 비밀의 앞 12자·뒤 12자 창을 함께 금지한다(12자면 이 값들 사이에서 우연 일치가 나지 않는다 · 아래에서 확인한다).
$LEAK_NEEDLES = @($SECRETS_NEVER_ON_SCREEN)
foreach ($s in $SECRETS_NEVER_ON_SCREEN) {
  if ($s.Length -ge 12) { $LEAK_NEEDLES += $s.Substring(0, 12); $LEAK_NEEDLES += $s.Substring($s.Length - 12) } }
$LEAK_NEEDLES = @($LEAK_NEEDLES | Sort-Object -Unique)
$POD1 = 'cloudflared-6d4f7c9b8-aa11a'
$POD2 = 'cloudflared-6d4f7c9b8-bb22b'
$POD3 = 'cloudflared-6d4f7c9b8-cc33c'
$ST1 = '2026-09-14T07:48:23Z'
$ST2 = '2026-09-14T07:49:07Z'
$ST3 = '2026-09-21T08:40:00Z'
$POD_SIG = "$POD1|0|$ST1 $POD2|0|$ST2"      # 기본 상태(POD1·POD2)의 파드 서명
$POD_SIG_23 = "$POD2|0|$ST2 $POD3|0|$ST3"   # 드릴이 한 번 끝난 상태(POD2 생존 + POD3 신규)의 서명
$BOOT = 'a1b2c3d4'                          # 노드 A 의 boot_id 앞 8자(비밀 아님)
$ES_TRACK_OK = 'platform-secrets:external-secrets.io/ExternalSecret:cloudflared/cloudflared-tunnel'
# ---------------------------------------------------------------- 모의 상태
function Reset-Mocks {
  $global:Now = [datetime]::Parse('2026-09-21T09:00:00Z').ToUniversalTime()
  $global:Sec = @{ uid = $PRE_UID; type = 'Opaque'; owner = ''
    data = [ordered]@{ TUNNEL_TOKEN = $TOK }
    labels = @{}; ann = @{} }
  $global:Es = $null
  $global:EsReady = 'True'
  $global:Pods = @(
    @{ name = $POD1; restarts = 0; start = $ST1; ready = 'True'; lab = 'app=cloudflared' },
    @{ name = $POD2; restarts = 0; start = $ST2; ready = 'True'; lab = 'app=cloudflared' })
  $global:AppRes = '/Deployment /Service /ServiceAccount '
  # platform-secrets 의 status.resources(ExternalSecret 만). `cert-manager/cloudflare-dns-token=` 은 항상 있어야 하는
  # **양성 대조** 행이다 — 이 행이 없으면 "조회가 됐지만 선언이 없다"가 아니라 "조회를 못 믿는다"로 읽어야 한다.
  $global:ArgoEs = 'cert-manager/cloudflare-dns-token= '
  $global:EsTrack = $ES_TRACK_OK
  $global:EsReason = 'SecretSynced'
  $global:EsDelay = 120
  $global:EsAppears = $true
  $global:EsCreated = ''
  $global:MergeAt = $null
  $global:Adopted = $false
  $global:Faults = @{}
  $global:FailAlways = @{}
  $global:FailN = @{}
  $global:PodReadyDelay = 30
  $global:NewPodReady = $true
  $global:NewPodAt = $null
  $global:DeleteRemoves = $true
  $global:NewPodWithOld = $false
  $global:ThrowDelete = $false
  $global:SurvivorNotReadyAfterDelete=$false
  $global:BumpSurvivorOnDelete = $false
  $global:FailPodsAfterDelete = $false
  $global:LogHit = $true
  $global:SshOk = $true
  $global:SshOkAfter = $null
  $global:SshCalls = 0
  $global:BootId = $BOOT
  $global:NodeNames = @('node/joshtech-api', 'node/joshtech-cache')
  $global:SecGone = $false
  $global:RevertAfterApply = $false
  $global:ChangeUidAfterApply = $false
  $global:OciOk = $true
  # 4라운드 결함 스위치 — 3라운드 검증 A 의 ESCAPED 변이(V03·V04·V05·V10·V13·V14·V15·V18)가 통과한 창을 닫는다.
  $global:OciEmpty = $false          # oci 가 exit 0 인데 **빈 출력**(V04)
  $global:BadPodRow = $false         # 파드 jsonpath 가 4필드가 아니라 3필드로 온다(V13)
  $global:NoPodRows = $false         # 파드 목록이 exit 0 인데 빈 응답(V14)
  $global:EmptyType = $false         # Secret 의 .type 이 exit 0 인데 빈 응답(V10)
  $global:CanIDeny = ''              # 이 동사의 auth can-i 만 'no'(V15)
  $global:AppliedType = ''           # 복구 apply 페이로드가 실은 type(V18)
  $global:ClipHistory = 0
  $global:ClipHistoryMissing = $false
  $global:OnMerge = $null
  $global:OnDrill = $null
  $env:OCI_CLI_PROFILE = ''
  $env:OCI_CLI_AUTH = ''
  $global:EofAfter = -1
  $global:ReadCount = 0
  $global:Inputs = [System.Collections.Queue]::new() }
function EsStamp {
  if (-not [string]::IsNullOrWhiteSpace($global:EsCreated)) { return [string]$global:EsCreated }
  $global:Now.ToString('yyyy-MM-ddTHH:mm:ss') + 'Z' }
function Adopt-Now {
  # 이미 인수가 끝난 상태(1R resume 시나리오·복구 시나리오용)
  $global:Adopted = $true
  $global:Es = @{ reason = 'SecretSynced'; created = (EsStamp); ann = @{ 'argocd.argoproj.io/tracking-id' = $global:EsTrack } }
  $global:Sec.labels['reconcile.external-secrets.io/managed'] = 'true'
  $global:Sec.ann['reconcile.external-secrets.io/data-hash'] = 'dee8952bf80d747f83dde48edad29237eabeb2a5c4b28b2d492b94bb' }
function FailCode { param($tag)
  if ($global:FailN.ContainsKey($tag) -and $global:FailN[$tag] -gt 0) { $global:FailN[$tag] = $global:FailN[$tag] - 1; return 1 }
  if ($global:FailAlways.ContainsKey($tag)) { return $global:FailAlways[$tag] }
  0 }
function Tick {
  if ($null -ne $global:MergeAt -and -not $global:Adopted -and $global:EsAppears -and $global:Now -ge $global:MergeAt.AddSeconds($global:EsDelay)) {
    $global:Adopted = $true
    $global:Es = @{ reason = $global:EsReason; created = (EsStamp); ann = @{ 'argocd.argoproj.io/tracking-id' = $global:EsTrack } }
    # provider 실패(SecretSyncedError)면 Secret 의 값·UID 는 손대지 않는다 — managed 라벨만 붙는다.
    if (-not $global:Faults['noLabel']) { $global:Sec.labels['reconcile.external-secrets.io/managed'] = 'true' }
    if ([string]::Equals($global:EsReason, 'SecretSynced', [StringComparison]::Ordinal)) {
      if (-not $global:Faults['noDataHash']) { $global:Sec.ann['reconcile.external-secrets.io/data-hash'] = 'dee8952bf80d747f83dde48edad29237eabeb2a5c4b28b2d492b94bb' }
      if ($global:Faults['changeValue']) { $global:Sec.data['TUNNEL_TOKEN'] = $TOK2 }
      # ES 의 secretKey 매핑이 틀린 경우 — 인수 순간 TUNNEL_TOKEN 이 **삭제**되고 매핑된 키만 남는다(DR1 실측 동작).
      # 값이 틀린 것보다 나쁘다: 컨테이너가 시작하면 CreateContainerConfigError 로 아예 뜨지 못한다.
      if ($global:Faults['dropKey']) { $global:Sec.data.Remove('TUNNEL_TOKEN'); $global:Sec.data['WRONG_KEY'] = $TOK2 }
      if ($global:Faults['changeUid']) { $global:Sec.uid = 'ffffeeee-dddd-4ccc-8bbb-aaaa99998888' }
      if ($global:Faults['ownerRef']) { $global:Sec.owner = '[{"apiVersion":"external-secrets.io/v1","kind":"ExternalSecret","name":"cloudflared-tunnel"}]' }
      if ($global:Faults['copyTracking']) { $global:Sec.ann['argocd.argoproj.io/tracking-id'] = 'platform-secrets:/Secret:cloudflared/cloudflared-tunnel' }
      if ($global:Faults['podRestart']) { $global:Pods[0].restarts = 1 }
      if ($global:Faults['survivorNotReady']) { $global:Pods[0].ready = 'False' }
      if ($global:Faults['targetNotReady']) { $global:Pods[1].ready = 'False' } } }
  if ($null -ne $global:NewPodAt -and $global:Now -ge $global:NewPodAt -and $global:NewPodReady) {
    foreach ($p in $global:Pods) { if ([string]::Equals([string]$p.name, $POD3, [StringComparison]::Ordinal)) { $p.ready = 'True' } } } }
# ---------------------------------------------------------------- 모의 명령
function Get-Date { param() $global:Now }
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds)
  if ($Seconds) { $global:Now = $global:Now.AddSeconds($Seconds) }
  if ($Milliseconds) { $global:Now = $global:Now.AddMilliseconds($Milliseconds) } }
function Set-Clipboard { param([Parameter(ValueFromPipeline = $true)]$Value)
  [void]$global:ClipValues.Add([string]$Value)
  [void]$global:Seq.Add('clip') }
function Read-Host { param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
  [void]$global:Prompts.Add([string]$Prompt)
  [void]$global:Seq.Add($(if ($AsSecureString) { 'read:secure' } else { 'read:plain' }))
  $global:ReadCount++
  if ($global:EofAfter -ge 0 -and $global:ReadCount -ge $global:EofAfter) { return $null }
  $v = if ($global:Inputs.Count -gt 0) { [string]$global:Inputs.Dequeue() } else { '' }
  [void]$global:ReadLog.Add([pscustomobject]@{ prompt = [string]$Prompt; secure = [bool]$AsSecureString; value = $v })
  if ([string]::Equals($v, 'merge', [StringComparison]::Ordinal)) {
    $global:MergeAt = $global:Now
    if ($global:OnMerge) { & $global:OnMerge } }
  if (($v -eq $POD2 -or $v -eq 'drill' -or $v -eq 'second') -and $global:OnDrill) { & $global:OnDrill }
  if ($AsSecureString) {
    $ss = [securestring]::new()
    foreach ($c in $v.ToCharArray()) { $ss.AppendChar($c) }
    return $ss }
  $v }
function Get-ItemProperty { param([Parameter(Position = 0)]$Path)
  if ($global:ClipHistoryMissing) { return $null }
  [pscustomobject]@{ EnableClipboardHistory = $global:ClipHistory } }
function ssh {
  $a = @($args | ForEach-Object { [string]$_ })
  [void]$global:ArgvLog.Add('ssh ' + ($a -join ' '))
  $global:SshCalls = $global:SshCalls + 1
  $ok = $global:SshOk
  if ($global:SshCalls -gt 1 -and $null -ne $global:SshOkAfter) { $ok = $global:SshOkAfter }
  if (-not $ok) { $global:LASTEXITCODE = 255; return }
  $global:LASTEXITCODE = 0
  if (@($a | Where-Object { $_.Contains('boot_id') }).Count -gt 0) { return $global:BootId }
  'joshtech-api' }
function oci {
  $a = @($args | ForEach-Object { [string]$_ })
  [void]$global:ArgvLog.Add('oci ' + ($a -join ' '))
  if (-not $global:OciOk) { $global:LASTEXITCODE = 1; return }
  # 실물에서 있을 수 있는 상태: 호출은 성공(exit 0)인데 결과가 비어 돌아온다(자격은 유효하지만 응답이 없다).
  # 이것을 "자격 확인됨"으로 읽으면 확인된 복구 경로가 0 인 채로 드릴이 진행된다.
  if ($global:OciEmpty) { $global:LASTEXITCODE = 0; return '' }
  $global:LASTEXITCODE = 0
  '9' }
function kubectl {
  $stdin = @($input)
  $a = @($args | ForEach-Object { [string]$_ })
  [void]$global:ArgvLog.Add(($a -join ' '))
  $global:LASTEXITCODE = 0
  Tick
  $ns = ''; $o = ''; $sel = ''; $ign = $false; $pos = @()
  for ($i = 0; $i -lt $a.Count; $i++) {
    $x = [string]$a[$i]
    if ([string]::Equals($x, '-n', [StringComparison]::Ordinal)) { $ns = [string]$a[$i + 1]; $i++; continue }
    if ([string]::Equals($x, '-o', [StringComparison]::Ordinal)) { $o = [string]$a[$i + 1]; $i++; continue }
    if ([string]::Equals($x, '-l', [StringComparison]::Ordinal)) { $sel = [string]$a[$i + 1]; $i++; continue }
    if ([string]::Equals($x, '-f', [StringComparison]::Ordinal)) { $i++; continue }
    if ([string]::Equals($x, '--ignore-not-found', [StringComparison]::Ordinal)) { $ign = $true; continue }
    if ($x.StartsWith('--')) { continue }
    $pos += $x }
  $verb = [string]$pos[0]
  # ⚠ 변경 로그는 **조회 동사(get·auth·logs) 밖의 모든 동사**를 전체 argv 그대로 기록한다.
  # 허용 헬퍼 안에 숨어든 변경 호출(scale·rollout·patch …)과 인자만 바꾼 변이(--all·-l·이름 2개·--force)를
  # 정확 일치 대조로 잡기 위해서다(짧은 요약으로 기록하면 argv 변이가 같은 줄로 접힌다).
  if (-not (@('get', 'auth', 'logs') -contains $verb)) { [void]$global:Mut.Add(($a -join ' ')); if ($global:ActiveBlock -eq 'adopt') { throw 'ADOPT-WRITE: adopt 변경 동사 거부' } }
  if ([string]::Equals($verb, 'auth', [StringComparison]::Ordinal)) {
    if ($ns -cne 'cloudflared') { throw '권한 조회 namespace 불일치' }
    if ($global:Faults['canINo']) { $global:LASTEXITCODE = 1; return 'no' }
    # 동사 하나만 거부한다 — "get secrets 는 되는데 delete pods 는 안 된다"를 만들어 0) 의 권한 사전 확인 두 항목을 따로 시험한다.
    if (-not [string]::IsNullOrWhiteSpace($global:CanIDeny) -and (@($pos | Where-Object { [string]::Equals([string]$_, [string]$global:CanIDeny, [StringComparison]::Ordinal) }).Count -gt 0)) {
      $global:LASTEXITCODE = 1; return 'no' }
    $c = FailCode 'cani'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return 'yes' }
  if ([string]::Equals($verb, 'apply', [StringComparison]::Ordinal)) {
    $c = FailCode 'apply'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    $body = ($stdin -join "`n")
    if ([string]::IsNullOrWhiteSpace($body)) { $global:LASTEXITCODE = 1; return }
    $obj = $null
    try { $obj = $body | ConvertFrom-Json } catch { $global:LASTEXITCODE = 1; return }
    # type 은 불변 필드다 — 페이로드에 실린 값이 실제 Secret 의 type 과 다르면 실물 apply 는 거부된다.
    $global:AppliedType = [string]$obj.type
    foreach ($p in $obj.data.PSObject.Properties) {
      $global:Sec.data[$p.Name] = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String([string]$p.Value)) }
    # apply 직후 ESO 가 곧바로 다시 덮는 상황(값·UID) — 쓰기 뒤 되읽기 판정만이 잡을 수 있는 창이다.
    if ($global:RevertAfterApply) { $global:Sec.data['TUNNEL_TOKEN'] = $TOK2 }
    if ($global:ChangeUidAfterApply) { $global:Sec.uid = 'ffffeeee-dddd-4ccc-8bbb-aaaa99998888' }
    return "secret/$($obj.metadata.name) serverside-applied" }
  if ([string]::Equals($verb, 'logs', [StringComparison]::Ordinal)) {
    $c = FailCode 'logs'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    if ($global:LogHit) { return @('2026-09-21T06:00:01Z INF Starting tunnel', '2026-09-21T06:00:03Z INF Registered tunnel connection connIndex=0', '2026-09-21T06:00:04Z INF Registered tunnel connection connIndex=1') }
    return @('2026-09-21T06:00:01Z INF Starting tunnel', '2026-09-21T06:00:09Z INF Waiting for edge connection') }
  if ([string]::Equals($verb, 'delete', [StringComparison]::Ordinal)) {
    if ($global:ThrowDelete) { throw 'mock interrupt' }
    $name = [string]$pos[2]
    $c = FailCode 'delete'
    if ($global:FailPodsAfterDelete) { $global:FailAlways['pods'] = 1 }
    if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    if ($global:DeleteRemoves) {
      $global:Pods = @($global:Pods | Where-Object { -not [string]::Equals([string]$_.name, $name, [StringComparison]::Ordinal) })
      # 삭제 직후 남은 커넥터까지 재시작하는 상황(유일한 경로가 흔들린다)
      if ($global:BumpSurvivorOnDelete) { foreach ($p in $global:Pods) { $p.restarts = 1 } }
      if ($global:SurvivorNotReadyAfterDelete) { foreach ($p in $global:Pods) { $p.ready='False' } }
      $global:Pods += @{ name = $POD3; restarts = 0; start = ($global:Now.ToString('yyyy-MM-ddTHH:mm:ss') + 'Z'); ready = 'False'; lab = 'app=cloudflared' }
      $global:NewPodAt = $global:Now.AddSeconds($global:PodReadyDelay) }
    if ($global:NewPodWithOld) {
      $global:Pods += @{ name = $POD3; restarts = 0; start = $ST3; ready = 'True'; lab = 'app=cloudflared' } }
    return "pod `"$name`" deleted" }
  if (-not [string]::Equals($verb, 'get', [StringComparison]::Ordinal)) { $global:LASTEXITCODE = 1; return }
  $kind = [string]$pos[1]
  if ([string]::Equals($kind, 'nodes', [StringComparison]::Ordinal)) {
    $c = FailCode 'nodes'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    if ($o.Contains('conditions')) { return $global:NodeReady }
    return @($global:NodeNames) }
  if ([string]::Equals($kind, 'pods', [StringComparison]::Ordinal)) {
    $c = FailCode 'pods'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    # exit 0 인데 응답이 비어 있는 경우(권한·필드 셀렉터·apiserver 상태) — "파드 없음"으로 읽으면 안 된다.
    if ($global:NoPodRows) { return @() }
    $list = @($global:Pods)
    if (-not [string]::IsNullOrWhiteSpace($sel)) { $list = @($list | Where-Object { [string]::Equals([string]$_.lab, $sel, [StringComparison]::Ordinal) }) }
    # jsonpath 의 Ready 조건 표기가 달라져 필드가 하나 모자라게 오는 경우 — 조용히 오판하면 안 된다.
    if ($global:BadPodRow) { return @($list | ForEach-Object { "$($_.name)|$($_.restarts)|$($_.start)" }) }
    return @($list | ForEach-Object { "$($_.name)|$($_.restarts)|$($_.start)|$($_.ready)" }) }
  if ([string]::Equals($kind, 'app', [StringComparison]::Ordinal)) {
    if ($o.Contains('requiresPruning')) {
      $c = FailCode 'app.es'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
      return $global:ArgoEs }
    $c = FailCode 'app.res'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return $global:AppRes }
  if ([string]::Equals($kind, 'externalsecret', [StringComparison]::Ordinal)) {
    if ($o.Contains('&&')) { throw 'unsupported kubectl JSONPath operator &' }
    if ($o.Contains('tracking-id')) { $c = FailCode 'es.trk' }
    elseif ($o.Contains('creationTimestamp')) { $c = FailCode 'es.created' }
    elseif ($o.Contains('conditions')) { $c = FailCode 'es.reason' }
    else { $c = FailCode 'es.name' }
    if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    if ($null -eq $global:Es) {
      if ($ign) { return }
      $global:LASTEXITCODE = 1; return }
    if ([string]::Equals($o, 'name', [StringComparison]::Ordinal)) { return "externalsecret.external-secrets.io/cloudflared-tunnel" }
    if ($o.Contains('creationTimestamp')) { return [string]$global:Es.created }
    if ($o.Contains('conditions')) {
      $r = [string]$global:Es.reason
      # SecretSynced 를 본 직후(= 폴링 루프가 빠져나간 뒤, 3) 판정이 읽기 전) 값·UID 가 바뀌는 좁은 창.
      # 감시 루프가 아니라 **3) 인수 판정**만이 잡을 수 있는 경로다.
      if ([string]::Equals($r, 'SecretSynced', [StringComparison]::Ordinal)) {
        if ($global:Faults['changeAfterSync']) { $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:Faults['changeAfterSync'] = $false }
        if ($global:Faults['changeUidAfterSync']) { $global:Sec.uid = 'ffffeeee-dddd-4ccc-8bbb-aaaa99998888'; $global:Faults['changeUidAfterSync'] = $false } }
      if ($o.Contains('].status}|')) {
        if ($o -cne 'jsonpath={.status.conditions[?(@.type=="Ready")].status}|{.status.conditions[?(@.type=="Ready")].reason}') { throw 'ES 상태/이유 JSONPath 계약 불일치' }
        return "$($global:EsReady)|$r" }; return $r }
    if ($o.Contains('tracking-id')) { return [string]$global:Es.ann['argocd.argoproj.io/tracking-id'] }
    $global:LASTEXITCODE = 1; return }
  if (-not [string]::Equals($kind, 'secret', [StringComparison]::Ordinal)) { $global:LASTEXITCODE = 1; return }
  $s = $global:Sec
  # Secret 존재 확인(`--ignore-not-found -o name`) — 없으면 exit 0 + 빈 응답이다(실물과 같다).
  if ([string]::Equals($o, 'name', [StringComparison]::Ordinal)) {
    $c = FailCode 'sec.name'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    if ($global:SecGone) {
      if ($ign) { return }
      $global:LASTEXITCODE = 1; return }
    return 'secret/cloudflared-tunnel' }
  if ($global:SecGone) {
    if ($ign) { return }
    $global:LASTEXITCODE = 1; return }
  if ($o.StartsWith('go-template=')) {
    $c = FailCode 'sec.keys'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return @($s.data.Keys | ForEach-Object { [string]$_ }) }
  if (-not $o.StartsWith('jsonpath=')) { $global:LASTEXITCODE = 1; return }
  # 인수 전 스냅샷(단일 GET) — uid|managed 라벨|값 을 한 응답으로 준다. 라벨·값 분기보다 **먼저** 본다.
  if ($o.Contains('}|{')) {
    $c = FailCode 'sec.data'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    $lab = [string]$s.labels['reconcile.external-secrets.io/managed']
    if ($global:Faults['snapLabel']) { $lab = 'true' }
    $val = ''
    if ($s.data.Contains('TUNNEL_TOKEN')) { $val = (B64 $s.data['TUNNEL_TOKEN']) }
    # 4필드: uid|managed 라벨|ESO data-hash 어노테이션|값. 세 번째가 가드 ⓓ(라벨만 지워진 재인수 탐지)의 근거다.
    # **요청한 필드만** 돌려준다 — 고정 4필드를 돌려주면 jsonpath 에서 필드를 빼는 변이가 모의에 보이지 않는다.
    $parts = @()
    if ($o.Contains('metadata.uid')) { $parts += [string]$s.uid }
    if ($o.Contains('labels.reconcile')) { $parts += $lab }
    if ($o.Contains('data-hash')) { $parts += [string]$s.ann['reconcile.external-secrets.io/data-hash'] }
    if ($o.Contains('.data.')) { $parts += $val }
    return ($parts -join '|') }
  if ($o.Contains('labels')) {
    $c = FailCode 'sec.label'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return [string]$s.labels['reconcile.external-secrets.io/managed'] }
  if ($o.Contains('data-hash')) {
    $c = FailCode 'sec.dh'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return [string]$s.ann['reconcile.external-secrets.io/data-hash'] }
  if ($o.Contains('tracking-id')) {
    $c = FailCode 'sec.trk'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return [string]$s.ann['argocd.argoproj.io/tracking-id'] }
  if ($o.Contains('ownerReferences')) {
    $c = FailCode 'sec.owner'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return [string]$s.owner }
  if ($o.Contains('metadata.uid')) {
    $c = FailCode 'sec.uid'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    return [string]$s.uid }
  if ([string]::Equals($o, 'jsonpath={.type}', [StringComparison]::Ordinal)) {
    $c = FailCode 'sec.type'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    # exit 0 인데 빈 응답 — type 은 불변 필드라 빈 값을 그대로 apply 에 실으면 서버가 거부한다.
    if ($global:EmptyType) { return '' }
    return [string]$s.type }
  if ($o.Contains('.data.')) {
    $c = FailCode 'sec.data'; if ($c -ne 0) { $global:LASTEXITCODE = $c; return }
    $k = 'TUNNEL_TOKEN'
    if (-not $s.data.Contains($k)) { return '' }
    return (B64 $s.data[$k]) }
  $global:LASTEXITCODE = 1; return }
# ---------------------------------------------------------------- 정적 검사(AST lint)
function Lint-Block { param($path, [string[]]$kubeHelpers, [string]$mutHelper, [string[]]$mustClear = @(), [string[]]$mutFlags = @(),
  [hashtable]$helperVerbs = @{}, [hashtable]$exactElems = @{}, [string[]]$allowCmds = @(), [string[]]$firstTwo = @(), [hashtable]$nativePins = @{},
  [hashtable]$callCounts = @{})
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
  $bad = @()
  foreach ($e in $er) { $bad += "파서오류 L$($e.Extent.StartLineNumber)" }
  if ($er.Count -eq 0 -and $ast.EndBlock.Statements.Count -ne 1) { $bad += "최상위 문장이 $($ast.EndBlock.Statements.Count) 개(1 이어야 한다)" }
  $lines = [IO.File]::ReadAllLines($path)
  $blank = 0; foreach ($l in $lines) { if ($l.Trim().Length -eq 0) { $blank++ } }
  if ($blank -ne 0) { $bad += "빈 줄 $blank 개" }
  $b = [IO.File]::ReadAllBytes($path)
  $tail = ($b[-3..-1] | ForEach-Object { $_.ToString('X2') }) -join ' '
  if (-not [string]::Equals($tail, '0A 7D 0A', [StringComparison]::Ordinal)) { $bad += "끝 3바이트=$tail(0A 7D 0A 이어야 한다)" }
  if (@($b | Where-Object { $_ -eq 13 }).Count -ne 0) { $bad += 'CR 바이트 존재' }
  # L-F 명령 이름 **허용 목록**(블랙리스트가 아니다 — 새 명령이 늘면 그 자체로 실패해야 한다).
  # 블랙리스트는 목록에 없는 한 줄(Out-Printer 든 curl 이든 sudo 든)을 통과시킨다. 이 블록들이 쓰는 명령은 고정돼 있다.
  $cmds = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true))
  foreach ($c in $cmds) {
    $nm = $c.GetCommandName()
    if ([string]::IsNullOrWhiteSpace([string]$nm)) { continue }
    if (-not (@($allowCmds | Where-Object { [string]::Equals([string]$_, [string]$nm, [StringComparison]::Ordinal) }).Count)) {
      $bad += "L$($c.Extent.StartLineNumber) 허용 목록에 없는 명령 '$nm'" } }
  # L-G 첫 두 문 고정($ErrorActionPreference·$PSNativeCommandUseErrorActionPreference) — 둘 중 하나만 빠져도
  # 네이티브 비0 종료 처리와 비종료 오류 처리가 통째로 달라진다(문면·재시도가 무력화된다).
  if ($er.Count -eq 0 -and $firstTwo.Count -gt 0) {
    $inner = @($ast.EndBlock.Statements[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $false))
    if ($inner.Count -lt 1) { $bad += '최상위 `& { … }` 스크립트블록을 찾지 못했다' }
    else {
      $st = @($inner[0].ScriptBlock.EndBlock.Statements)
      for ($i = 0; $i -lt $firstTwo.Count; $i++) {
        $got = if ($i -lt $st.Count) { ([string]$st[$i].Extent.Text).Trim() } else { '(없음)' }
        if (-not [string]::Equals($got, [string]$firstTwo[$i], [StringComparison]::Ordinal)) { $bad += "블록 $($i + 1)번째 문이 고정값과 다르다: '$got'" } } } }
  foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] }, $true)) {
    if ($m.Expression.TypeName.FullName -match '(^|\.)Console$') { $bad += "L$($m.Extent.StartLineNumber) [Console]::$($m.Member)" } }
  foreach ($r in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FileRedirectionAst] }, $true)) {
    if ($r.Location.Extent.Text -ne '$null') { $bad += "L$($r.Extent.StartLineNumber) redirect $($r.Location.Extent.Text)" } }
  # L-N 안전 규칙 8(Ordinal 비교). `-eq`/`-ne`/`-ceq`/`-cne` 는 **인바리언트 컬처** 비교라 U+FEFF 같은 무시 가능 코드포인트를
  # 건너뛴다(이 저장소가 `-ceq` 로 이미 겪은 결함이다 — CLAUDE.md). 문자열 판정은 전부 [string]::Equals(…, Ordinal) 이어야 하므로,
  # **한쪽이 문자열 리터럴인** 그 연산자를 전부 실패로 센다(숫자 비교 `$_.Count -ne 2` 는 리터럴이 문자열이 아니라 통과한다).
  $eqOps = @('Ieq', 'Ine', 'Ceq', 'Cne')
  foreach ($be in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true)) {
    if (-not (@($eqOps | Where-Object { [string]::Equals([string]$_, [string]$be.Operator, [StringComparison]::Ordinal) }).Count)) { continue }
    $isLit = { param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $x -is [System.Management.Automation.Language.ExpandableStringExpressionAst] }
    if ((& $isLit $be.Left) -or (& $isLit $be.Right)) {
      $bad += "L$($be.Extent.StartLineNumber) 문자열 리터럴에 $([string]$be.Operator)(컬처 민감) — [string]::Equals(…, Ordinal) 이어야 한다: $(([string]$be.Extent.Text).Trim())" } }
  # L-M 지정한 헬퍼의 **호출 지점 수**를 고정한다(대입문 좌변 제외). 같은 판정을 여러 분기에서 불러야 하는 헬퍼는
  # 분기가 늘 때마다 호출이 빠지기 쉽다 — 개수를 고정하면 분기 추가 그 자체가 실패로 드러난다(5R 검증 A4-3).
  foreach ($cn2 in $callCounts.Keys) {
    $rr2 = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.VariablePath.UserPath, [string]$cn2, [StringComparison]::Ordinal) }, $true))
    $cc2 = @($rr2 | Where-Object { -not ($_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) })
    if ($cc2.Count -ne [int]$callCounts[$cn2]) { $bad += "헬퍼 `$$cn2 의 호출 지점이 $($cc2.Count) 곳(고정값 $([int]$callCounts[$cn2]) 곳)" } }
  # 비밀이 스쳐 가는 변수에 -match 계열 금지 — 매치가 성공하면 $Matches[0] 에 평문 전체가 남고 Remove-Variable 로 지워지지 않는다.
  $secretVars = @('tok', 'b64', 'new', 'payload', 'pm', 'pmTok')
  foreach ($be in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true)) {
    if (-not ([string]$be.Operator).ToLowerInvariant().Contains('match')) { continue }
    if ($be.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and ($secretVars -contains [string]$be.Left.VariablePath.UserPath)) {
      $bad += "L$($be.Extent.StartLineNumber) `$$([string]$be.Left.VariablePath.UserPath) 에 -match 계열(=`$Matches 에 평문 잔류)" } }
  # 모든 kubectl 호출이 지정된 헬퍼 안에만 있는가(= 모든 호출이 $LASTEXITCODE 를 검사한다)
  # 감싸는 대입문의 이름을 **전부** 모은다($out = & kubectl … 처럼 안쪽 대입이 먼저 걸리므로 첫 하나만 보면 안 된다)
  $enc = { param($node)
    $names = @()
    $p = $node.Parent
    while ($null -ne $p) {
      if ($p -is [System.Management.Automation.Language.AssignmentStatementAst] -and $p.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $names += [string]$p.Left.VariablePath.UserPath }
      $p = $p.Parent }
    $names }
  # kubectl 동사 전체 사전 — 헬퍼별 허용 목록의 여집합을 "못 보고 지나치는" 일이 없게 한다.
  $allVerbs = @('get', 'auth', 'logs', 'describe', 'top', 'explain', 'api-resources', 'api-versions', 'version', 'config', 'cluster-info', 'wait', 'events',
    'delete', 'apply', 'patch', 'create', 'replace', 'edit', 'scale', 'rollout', 'drain', 'cordon', 'uncordon', 'exec', 'annotate', 'label', 'taint',
    'evict', 'cp', 'port-forward', 'proxy', 'run', 'expose', 'set', 'debug', 'attach', 'autoscale', 'diff', 'kustomize')
  $byHelper = @{}
  foreach ($c in $cmds) {
    $nm = $c.GetCommandName()
    if (-not [string]::Equals([string]$nm, 'kubectl', [StringComparison]::Ordinal)) { continue }
    $h = @(& $enc $c)
    $own = @($h | Where-Object { $kubeHelpers -contains $_ })
    if (-not $own.Count) { $bad += "L$($c.Extent.StartLineNumber) kubectl 호출이 헬퍼 밖($($h -join '<'))"; continue }
    $hn = [string]$own[$own.Count - 1]
    if (-not $byHelper.ContainsKey($hn)) { $byHelper[$hn] = @() }
    $byHelper[$hn] += , $c
    # L-H 헬퍼별 동사 허용 목록 — `$klog` 안에 `scale`·`rollout` 을 끼워 넣는 식의 우회를 정적으로 막는다.
    # (허용 헬퍼 안이기만 하면 통과하던 기존 규칙의 구멍이다.)
    if ($helperVerbs.ContainsKey($hn)) {
      $ok = @($helperVerbs[$hn])
      foreach ($sc in $c.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
        $v = ([string]$sc.Value).ToLowerInvariant()
        if (-not ($allVerbs -contains $v)) { continue }
        if (-not (@($ok | Where-Object { [string]::Equals([string]$_, $v, [StringComparison]::Ordinal) }).Count)) {
          $bad += "L$($c.Extent.StartLineNumber) 헬퍼 `$$hn 에 허용되지 않은 동사 '$v'(허용: $($ok -join '/'))" } } } }
  # L-I 헬퍼의 kubectl 인자를 **요소 하나씩 정확 일치**로 고정한다.
  # 필수 플래그 존재 검사는 추가된 플래그(--force · --grace-period=0)와 넓어진 셀렉터(--all · -l · 이름 2개)를 보지 못한다.
  foreach ($hn in $exactElems.Keys) {
    $cc = @($byHelper[$hn])
    if ($cc.Count -ne 1) { $bad += "헬퍼 `$$hn 안의 kubectl 호출이 $($cc.Count) 개(1 이어야 한다)"; continue }
    $got = @($cc[0].CommandElements | ForEach-Object { [string]$_.Extent.Text })
    $exp = @($exactElems[$hn])
    if ($got.Count -ne $exp.Count -or -not [string]::Equals(($got -join ' '), ($exp -join ' '), [StringComparison]::Ordinal)) {
      $bad += "헬퍼 `$$hn 의 kubectl 인자가 고정값과 다르다: 실제[$($got -join ' ')] 기대[$($exp -join ' ')]" } }
  # L-J kubectl 밖의 네이티브 명령(ssh·oci)도 인자를 고정한다 — 변경 경로는 kubectl 만이 아니다.
  # (ssh 원격 명령 한 문자열에 `sudo k3s kubectl rollout restart` 를 붙이면 lint·모의 어느 쪽에도 걸리지 않았다.)
  foreach ($cn in $nativePins.Keys) {
    $want = @($nativePins[$cn])
    $got = @($cmds | Where-Object { [string]::Equals([string]$_.GetCommandName(), [string]$cn, [StringComparison]::Ordinal) } |
      ForEach-Object { (@($_.CommandElements | Select-Object -Skip 1 | ForEach-Object { [string]$_.Extent.Text }) -join ' ') })
    if ($got.Count -ne $want.Count) { $bad += "네이티브 '$cn' 호출이 $($got.Count) 곳(고정값 $($want.Count) 곳)"; continue }
    for ($i = 0; $i -lt $want.Count; $i++) {
      if (-not [string]::Equals([string]$got[$i], [string]$want[$i], [StringComparison]::Ordinal)) {
        $bad += "네이티브 '$cn' $($i + 1)번째 인자가 고정값과 다르다: 실제[$($got[$i])] 기대[$($want[$i])]" } } }
  # 조회 헬퍼 $kq 의 인자에 변경 동사가 섞여 들어오지 않는가(요구 (h) 의 정적 보장을 $kq 까지 넓힌다 · 런타임 허용 목록과 이중)
  $badVerbs = @('delete', 'apply', 'patch', 'create', 'replace', 'edit', 'scale', 'rollout', 'drain', 'cordon', 'uncordon', 'exec', 'annotate', 'label', 'taint', 'evict')
  foreach ($c in $cmds) {
    if ($c.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Ampersand) { continue }
    $first = $c.CommandElements[0]
    if (-not ($first -is [System.Management.Automation.Language.VariableExpressionAst])) { continue }
    if (-not [string]::Equals([string]$first.VariablePath.UserPath, 'kq', [StringComparison]::Ordinal)) { continue }
    $consts = @($c.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { ([string]$_.Value).ToLowerInvariant() })
    # `auth can-i patch secrets` 의 'patch' 는 동사가 아니라 검사 대상이다 — can-i 호출은 통째로 예외로 둔다(동사는 'auth' 로 고정).
    if ($consts -contains 'can-i') { continue }
    foreach ($sc in $c.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
      if ($badVerbs -contains ([string]$sc.Value).ToLowerInvariant()) { $bad += "L$($c.Extent.StartLineNumber) 조회 헬퍼 `$kq 인자에 변경 동사 '$($sc.Value)'" } } }
  $runtimeGuard = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith("if (-not ([string]::Equals([string]`$ka[`$vi], 'get',", [StringComparison]::Ordinal) }, $true))
  $expectedGuard = 'if (-not ([string]::Equals([string]$ka[$vi], ''get'', [StringComparison]::Ordinal) -or [string]::Equals([string]$ka[$vi], ''auth'', [StringComparison]::Ordinal))) {
        throw "조회 헬퍼에 조회가 아닌 동사가 들어왔다($([string]$ka[$vi])) — 블록 결함이다. 중단" }'
  if ($runtimeGuard.Count -ne 1 -or -not [string]::Equals($runtimeGuard[0].Extent.Text, $expectedGuard, [StringComparison]::Ordinal)) { $bad += '런타임 조회 동사 허용 목록 불일치' }
  foreach ($c in $cmds) {
    if ($c.CommandElements[0].Extent.Text -eq '$kq' -and $c.Extent.Text.Contains("'can-i'")) {
      if (-not $c.Extent.Text.Contains("'-n', `$NS")) { $bad += 'auth can-i namespace 누락' } }
  }
  # 클러스터를 바꾸는 헬퍼의 호출 지점이 1곳뿐인가
  if (-not [string]::IsNullOrWhiteSpace($mutHelper)) {
  $refs = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.VariablePath.UserPath, $mutHelper, [StringComparison]::Ordinal) }, $true))
  $call = @($refs | Where-Object { -not ($_.Parent -is [System.Management.Automation.Language.AssignmentStatementAst]) })
  if ($call.Count -ne 1) { $bad += "변경 헬퍼 `$$mutHelper 의 호출 지점이 $($call.Count) 곳(1 이어야 한다)" }
  # 변경 헬퍼의 회계(변경 로그 · 단계 기록)가 요청을 보내기 **전에** 있는가 + 필수 플래그가 붙어 있는가
  # (Ctrl+C 로 네이티브 호출 도중 파이프라인이 멈춰도 요약이 "변경 0건"이라고 거짓말하지 않게 하는 구조적 조건이다)
  $mh = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.Left.VariablePath.UserPath, $mutHelper, [StringComparison]::Ordinal) }, $true))
  if ($mh.Count -ne 1) { $bad += "변경 헬퍼 `$$mutHelper 정의가 $($mh.Count) 개(1 이어야 한다)" }
  else {
    $body = $mh[0].Right
    $kc = @($body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'kubectl', [StringComparison]::Ordinal) }, $true))
    if ($kc.Count -ne 1) { $bad += "변경 헬퍼 안 kubectl 호출이 $($kc.Count) 개(1 이어야 한다)" }
    else {
      $kline = $kc[0].Extent.StartLineNumber
      $adds = @($body.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]::Equals([string]$n.Member.Value, 'Add', [StringComparison]::Ordinal) }, $true))
      if (-not (@($adds | Where-Object { $_.Extent.StartLineNumber -lt $kline }).Count)) { $bad += '변경 로그($changes.Add)가 kubectl 호출보다 뒤에 있다' }
      $logs = @($body.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.IndexExpressionAst] }, $true))
      if (-not (@($logs | Where-Object { $_.Extent.StartLineNumber -lt $kline }).Count)) { $bad += '단계 기록($log[...])이 kubectl 호출보다 뒤에 있다' }
      foreach ($flag in $mutFlags) {
        if (-not (@($kc[0].CommandElements | Where-Object { ([string]$_.Extent.Text).Contains($flag) }).Count)) { $bad += "변경 헬퍼의 kubectl 인자에 $flag 없음" } } } }
  }
  # finally 가 비밀이 스쳐 간 변수를 정리하는가(규칙 5)
  $fins = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.TryStatementAst] }, $true) | ForEach-Object { $_.Finally } | Where-Object { $null -ne $_ })
  $clearedTxt = ''
  foreach ($f in $fins) {
    foreach ($c in $f.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
      if (-not [string]::Equals([string]$c.GetCommandName(), 'Remove-Variable', [StringComparison]::Ordinal)) { continue }
      $clearedTxt = $clearedTxt + ' ' + (@($c.CommandElements | ForEach-Object { [string]$_.Extent.Text }) -join ' ') } }
  foreach ($m in $mustClear) {
    if (-not [regex]::IsMatch($clearedTxt, "(^|[\s,])$m([\s,]|$)")) { $bad += "finally 의 Remove-Variable 목록에 $m 없음" } }
  # L-K finally 규약(규칙 5): **첫 문이 Remove-Variable** 이고, finally 안에 "맨 표현식"(성공 스트림 출력)이 없어야 한다.
  # Ctrl+C 중지 중에는 첫 성공 스트림 출력에서 finally 가 끊긴다 — 그 앞에 정리가 끝나 있어야 하고,
  # 요약은 Write-Host/Write-Warning 으로만 나가야 한다(맨 문자열은 그 규약을 조용히 깬다).
  foreach ($f in $fins) {
    $st = @($f.Statements)
    $first = if ($st.Count -gt 0) { $st[0] } else { $null }
    $isRemove = $false
    if ($null -ne $first) {
      $fc = @($first.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $false))
      $isRemove = ($fc.Count -eq 1 -and [string]::Equals([string]$fc[0].GetCommandName(), 'Remove-Variable', [StringComparison]::Ordinal)) }
    if (-not $isRemove) { $bad += "finally 의 첫 문이 Remove-Variable 이 아니다: '$(if ($null -ne $first) { ([string]$first.Extent.Text).Trim() } else { '(빈 finally)' })'" }
    foreach ($sb in @($f.FindAll({ param($n) $n -is [System.Management.Automation.Language.StatementBlockAst] }, $true))) {
      # `$( … )`·`@( … )` 안의 문은 표현식의 일부다(Write-Host 인자 안의 `$($changes.Count)`) — 문장 자리의 맨 표현식만 본다.
      if ($sb.Parent -is [System.Management.Automation.Language.SubExpressionAst] -or $sb.Parent -is [System.Management.Automation.Language.ArrayExpressionAst]) { continue }
      foreach ($s in @($sb.Statements)) {
        if (-not ($s -is [System.Management.Automation.Language.PipelineAst])) { continue }
        if (@($s.PipelineElements).Count -ne 1) { continue }
        if ($s.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) {
          $bad += "L$($s.Extent.StartLineNumber) finally 안의 맨 표현식(성공 스트림 출력): '$(([string]$s.Extent.Text).Trim())'" } } } }
  # L-L 정지점·데이터 입력·비밀 입력의 Read-Host 앞에는 같은 스크립트블록 안에 FlushInputBuffer 가 있어야 한다(안전 규칙 1).
  # 없으면 미리 눌러 둔 Enter·타이핑 잔여가 정지점을 통과시킨다.
  foreach ($sbe in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true))) {
    $rh = @($sbe.ScriptBlock.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::Ordinal) }, $false))
    if (-not $rh.Count) { continue }
    $fl = @($sbe.ScriptBlock.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and [string]::Equals([string]$n.Member.Value, 'FlushInputBuffer', [StringComparison]::Ordinal) }, $true))
    foreach ($r in $rh) {
      if (-not (@($fl | Where-Object { $_.Extent.StartLineNumber -lt $r.Extent.StartLineNumber }).Count)) {
        $bad += "L$($r.Extent.StartLineNumber) Read-Host 앞에 FlushInputBuffer 가 없다" } } }
  , $bad }
# ---------------------------------------------------------------- 시나리오 실행기
function Reset-Strict {
  $global:ArgvLog = [System.Collections.ArrayList]::new()
  $global:ClipValues = [System.Collections.ArrayList]::new()
  $global:Prompts = [System.Collections.ArrayList]::new()
  $global:ReadLog = [System.Collections.ArrayList]::new()
  $global:Mut = [System.Collections.ArrayList]::new()
  $global:Seq = [System.Collections.ArrayList]::new()
  $global:NodeReady = 'joshtech-api=True joshtech-cache=True ' }
Reset-Strict
$results = [System.Collections.ArrayList]::new()
function Run-Case { param($id, $desc, $block, [scriptblock]$setup, $expect, [string[]]$want = @(), [string[]]$notWant = @(), [string[]]$mut = @(), [scriptblock]$post = $null, [string[]]$wantPrompt = @(), [string[]]$notWantPrompt = @(), [int]$leftover = 0)
  Reset-Mocks
  Reset-Strict
  $global:ActiveBlock = $block
  & $setup
  $gvBefore = @{}; foreach ($gv in (Get-Variable -Scope Global)) { if ($gv.Value -is [string]) { $gvBefore[$gv.Name] = $gv.Value } }
  $out = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''; $stack = ''
  try { & $blocks[$block] *>&1 | ForEach-Object { [void]$out.Add([string]$_) } }
  catch { $threw = $true; $errMsg = [string]$_.Exception.Message; $stack = [string]$_.ScriptStackTrace; [void]$out.Add("THROW: $errMsg") }
  $text = ($out -join "`n")
  $fails = [System.Collections.ArrayList]::new()
  if ([string]::Equals($expect, 'ok', [StringComparison]::Ordinal) -and $threw) { [void]$fails.Add("예상: 완주 · 실제 throw($errMsg)") }
  if (-not [string]::Equals($expect, 'ok', [StringComparison]::Ordinal)) {
    if (-not $threw) { [void]$fails.Add('예상: throw · 실제 완주') }
    elseif (-not $errMsg.Contains($expect)) { [void]$fails.Add("throw 문구 불일치: '$errMsg'") } }
  foreach ($w in $want) { if (-not $text.Contains($w)) { [void]$fails.Add("누락: '$w'") } }
  foreach ($w in $notWant) { if ($text.Contains($w)) { [void]$fails.Add("있으면 안 됨: '$w'") } }
  # 정지점 문면은 Read-Host 프롬프트로만 나간다(성공 스트림이 아니다) — 별도 표면으로 대조한다.
  $ptext = ($global:Prompts -join "`n")
  foreach ($w in $wantPrompt) { if (-not $ptext.Contains($w)) { [void]$fails.Add("프롬프트 누락: '$w'") } }
  foreach ($w in $notWantPrompt) { if ($ptext.Contains($w)) { [void]$fails.Add("프롬프트에 있으면 안 됨: '$w'") } }
  # 공통 사후 조건 1 — 가짜 토큰이 어떤 표면에도 나오지 않는다(화면·프롬프트·argv·클립보드·새 전역 변수)
  $gvNew = @(); foreach ($gv in (Get-Variable -Scope Global)) {
    if ($gv.Value -is [string] -and (-not $gvBefore.ContainsKey($gv.Name) -or -not [string]::Equals([string]$gvBefore[$gv.Name], [string]$gv.Value, [StringComparison]::Ordinal))) { $gvNew += [string]$gv.Value } }
  $surfaces = [ordered]@{ screen = $text; prompt = ($global:Prompts -join "`n"); argv = ($global:ArgvLog -join "`n"); clipboard = ($global:ClipValues -join "`n"); globalvar = ($gvNew -join "`n") }
  foreach ($sn in $surfaces.Keys) { foreach ($n in $LEAK_NEEDLES) { if (([string]$surfaces[$sn]).Contains($n)) { [void]$fails.Add("STRICT 누출 표면: $sn(창 '$($n.Substring(0, [Math]::Min(12, $n.Length)))…')"); break } } }
  foreach ($c in $global:ClipValues) { if (-not [string]::Equals([string]$c, ' ', [StringComparison]::Ordinal)) { [void]$fails.Add('STRICT 클립보드에 공백 아닌 값'); break } }
  foreach ($r in $global:ReadLog) { if (($SECRETS_NEVER_ON_SCREEN -ccontains $r.value) -and -not $r.secure) { [void]$fails.Add("STRICT 비밀을 -AsSecureString 없이 읽음: $($r.prompt)"); break } }
  # 공통 사후 조건 1b — 비밀 입력마다 **즉시** 클립보드를 비웠는가.
  # ① 순서: `read:secure` 바로 다음 사건이 `clip` 이어야 한다(그 사이에 다른 프롬프트가 끼면 평문 붙여넣기 사고 구간이 생긴다).
  # ② 횟수: finally 의 비우기 1회는 어느 실행에나 있으므로, 비밀 입력 n 회면 최소 n+1 회여야 한다
  #    (순서만 보면 "readSecret 의 비우기를 지우고 finally 것만 남긴" 변이가 마지막 입력에서 통과한다).
  $sq = @($global:Seq)
  $nSecure = @($sq | Where-Object { [string]::Equals([string]$_, 'read:secure', [StringComparison]::Ordinal) }).Count
  for ($i = 0; $i -lt $sq.Count; $i++) {
    if (-not [string]::Equals([string]$sq[$i], 'read:secure', [StringComparison]::Ordinal)) { continue }
    $nx = if ($i + 1 -lt $sq.Count) { [string]$sq[$i + 1] } else { '(없음)' }
    if (-not [string]::Equals($nx, 'clip', [StringComparison]::Ordinal)) { [void]$fails.Add("STRICT 비밀 입력 직후 클립보드 비우기 없음(다음 사건 = $nx)"); break } }
  if ($global:ClipValues.Count -lt ($nSecure + 1)) { [void]$fails.Add("STRICT 클립보드 비우기 $($global:ClipValues.Count) 회(비밀 입력 $nSecure 회 + finally 1 회 = $($nSecure + 1) 회 이상이어야 한다)") }
  # 공통 사후 조건 2 — 클러스터 변경 동작 로그가 기대 집합과 정확히 일치한다
  if ($block -eq 'adopt' -and $global:Mut.Count -ne 0) { [void]$fails.Add('ADOPT-WRITE: 공통 사후조건 변경 0 위반') }
  if ($global:Mut.Count -gt 1) { [void]$fails.Add('WRITE-LIMIT: 실행당 쓰기 1 초과') }
  $got = ($global:Mut -join ' ; ')
  $exp = ($mut -join ' ; ')
  if (-not [string]::Equals($got, $exp, [StringComparison]::Ordinal)) { [void]$fails.Add("변경 로그 불일치: 실제[$got] 기대[$exp]") }
  # 남은 입력은 "정지점이 빠졌다"의 신호다. 다만 일부러 남기는 시나리오가 있다(가드가 소비하지 **않아야** 할 단어를 넣어 두고,
  # 가드를 제거한 변이만 그 단어를 먹고 삭제까지 가게 하는 방식 — `$leftover` 로 기대값을 명시한다).
  if ([string]::Equals($expect, 'ok', [StringComparison]::Ordinal) -and $global:Inputs.Count -ne $leftover) { [void]$fails.Add("STRICT 남은 입력 $($global:Inputs.Count) 개(기대 $leftover 개)") }
  # 사후 검사에는 화면 전체를 넘긴다(출현 **횟수**를 세는 단언용 — `want` 의 부분 문자열 검사는 같은 문장이 두 곳에 찍힐 때
  # 한쪽만 지운 변이를 통과시킨다). 인자를 받지 않는 기존 post 블록은 그대로 동작한다($args 로 흘러간다).
  if ($post) { foreach ($f in (& $post $text)) { [void]$fails.Add($f) } }
  [void]$results.Add([pscustomobject]@{ id = $id; desc = $desc; result = $(if ($fails.Count -eq 0) { 'PASS' } else { 'FAIL' }); detail = ($fails -join ' | ') })
  if ($fails.Count -gt 0 -or ($Show -and $id -like $Show)) {
    Write-Host "---- $id 출력 ----`n$text`n$(if ($stack -and $fails.Count -gt 0) { "STACK: $stack" })`n" -ForegroundColor DarkGray } }
# ---------------------------------------------------------------- 정적 검사 실행
Write-Host '=== 정적 검사(AST lint · 붙여넣기 안전성) ==='
$lintBad = 0
$lint = [ordered]@{}
$EAP = "`$ErrorActionPreference = 'Stop'"
$PSN = '$PSNativeCommandUseErrorActionPreference = $false'
# 헬퍼별 동사 허용 목록 · kubectl 인자 고정값 · 네이티브(ssh·oci) 인자 고정값 · 명령 이름 허용 목록.
# `$kq` 의 kubectl 은 splat(@ka)이라 동사 리터럴이 없다 — 동사 방어는 런타임 허용 목록 + L-E(호출 지점 인자) 쪽이다.
$lint['g4-adopt.ps1'] = Lint-Block $blocks['adopt'] @('kq') '' @('snap', 'b64', 'hNow', 'uNow', 'hDel', 'uDel', 'pmHash') @('--wait=false', '--request-timeout=') `
  @{ kq = @('get', 'auth') } `
  @{ kq   = @('kubectl', '@ka', "'--request-timeout=10s'") } `
  @('ConvertFrom-SecureString', 'ForEach-Object', 'Get-Date', 'Get-ItemProperty', 'kubectl', 'oci', 'Out-Null', 'Read-Host', 'Remove-Variable', 'Set-Clipboard', 'ssh', 'Start-Sleep', 'Where-Object', 'Write-Host', 'Write-Warning') `
  @($EAP, $PSN) `
  @{ ssh = @("'-n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=15' 'ssh-a' 'cut -c1-8 /proc/sys/kernel/random/boot_id'")
     oci = @("'iam' 'region' 'list' '--query' 'length(data)'") } `
  @{}
$lint['g4-drill.ps1'] = Lint-Block $blocks['drill'] @('kq', 'klog', 'kdel') 'kdel' @('snap', 'b64', 'hNow', 'uNow', 'hDel', 'uDel', 'pmHash') @('--wait=false', '--request-timeout=') `
  @{ kq = @('get', 'auth'); klog = @('logs'); kdel = @('delete') } `
  @{ kq   = @('kubectl', '@ka', "'--request-timeout=10s'")
     klog = @('kubectl', "'-n'", '$NS', "'logs'", '$pod', "'--tail=120'", "'--request-timeout=15s'")
     kdel = @('kubectl', "'-n'", '$NS', "'delete'", "'pod'", '$pod', "'--wait=false'", "'--request-timeout=30s'") } `
  @('ConvertFrom-SecureString', 'ForEach-Object', 'Get-Date', 'Get-ItemProperty', 'kubectl', 'oci', 'Out-Null', 'Read-Host', 'Remove-Variable', 'Set-Clipboard', 'ssh', 'Start-Sleep', 'Where-Object', 'Write-Host', 'Write-Warning') `
  @($EAP, $PSN) `
  @{ ssh = @("'-n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=15' 'ssh-a' 'cut -c1-8 /proc/sys/kernel/random/boot_id'",
             "'-n' '-o' 'BatchMode=yes' '-o' 'ConnectTimeout=15' 'ssh-a' 'hostname'")
     oci = @("'iam' 'region' 'list' '--query' 'length(data)'") } `
  @{}
$lint['g4-restore.ps1'] = Lint-Block $blocks['restore'] @('kq', 'kapply') 'kapply' @('tok', 'b64', 'payload') @('--server-side', '--request-timeout=') `
  @{ kq = @('get', 'auth'); kapply = @('apply') } `
  @{ kq     = @('kubectl', '@ka', "'--request-timeout=10s'")
     kapply = @('kubectl', "'apply'", "'--server-side'", "'--force-conflicts'", "'--field-manager=t045-restore'", "'--request-timeout=30s'", "'-f'", "'-'") } `
  @('ConvertFrom-SecureString', 'ConvertTo-Json', 'ForEach-Object', 'Get-ItemProperty', 'kubectl', 'Out-Null', 'Read-Host', 'Remove-Variable', 'Set-Clipboard', 'Start-Sleep', 'Where-Object', 'Write-Host', 'Write-Warning') `
  @($EAP, $PSN) @{}
$readOnlyAst = [System.Management.Automation.Language.Parser]::ParseFile($blocks['adopt'], [ref]$null, [ref]$null)
foreach ($cmd in $readOnlyAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'kubectl' }, $true)) {
  $parts = @($cmd.CommandElements | ForEach-Object { $_.Extent.Text })
  if ($parts -contains '@ka') { continue }
  $verb = if ($parts[1] -eq "'-n'") { $parts[3].Trim("'") } else { $parts[1].Trim("'") }
  if ($verb -notin @('get', 'auth', 'logs')) { $lint['g4-adopt.ps1'] += "ADOPT-WRITE AST 금지 동사: $verb" }
}
if (-not (Test-Path (Join-Path $here 'g4-drill.ps1'))) { $lint['g4-drill.ps1'] = @('DRILL-MISSING: 독립 드릴 게이트 블록이 없다') }
foreach ($k in $lint.Keys) {
  $v = $lint[$k]
  Write-Host ("  {0,-16} {1}" -f $k, $(if ($v.Count) { 'LINT-FAIL: ' + ($v -join ' ; ') } else { 'clean(단일 최상위 문 · 빈 줄 0 · CR 0 · 명령 이름 허용 목록 · 첫 두 문 고정 · kubectl 은 헬퍼 안 · 헬퍼별 동사 허용 목록 · 헬퍼 kubectl 인자 정확 일치 · ssh/oci 인자 고정 · 비밀 변수에 -match 0 · finally 첫 문 Remove-Variable + 맨 표현식 0 · Read-Host 앞 FlushInputBuffer)' }))
  if ($v.Count) { $lintBad++ } }
Write-Host "`n=== 시나리오 ==="
$IN = { param([string[]]$v) foreach ($x in $v) { $global:Inputs.Enqueue($x) } }
# 정상 입력열: boot_id 대조 → 0) go → 1P) skip-pm → 2) merge → 4) drill
$OK = { & $IN @($BOOT, 'go', 'skip-pm', 'merge') }
# 변경 로그는 **전체 argv 정확 일치**다 — 셀렉터·이름 개수·플래그가 하나라도 달라지면 불일치다.
$DELARGV = { param($p) "-n cloudflared delete pod $p --wait=false --request-timeout=30s" }
$DEL2 = @((& $DELARGV $POD2))   # 드릴 대상은 startTime 이 가장 늦은 파드 = POD2(ST2 > ST1)
# 5R 검증 A4-2: R3 조각의 `unset B`(case **앞**)·`unset T` 는 재시도 안전과 평문 잔류를 떠받치는 줄인데 무시험이었다.
# 부분 문자열 want 로는 `unset B` 두 줄 중 하나가 사라져도 다른 하나가 매치돼 통과한다 — 그래서 **줄 순서 전체**를 대조한다.
$R3_SEQ = @('     set +o history',
  '     read -rsp "PM token: " T; echo',
  '     unset B',
  '     case "$T" in ''''|*[!''!''-~]*) echo BROKEN-PASTE;; *) if [ "${#T}" -ge 32 ]; then B=$(printf ''%s'' "$T" | base64 -w0); else echo TOO-SHORT; fi;; esac',
  '     unset T',
  '     if [ -n "$B" ]; then printf ''{"apiVersion":"v1","kind":"Secret","type":"Opaque","metadata":{"name":"cloudflared-tunnel","namespace":"cloudflared"},"data":{"TUNNEL_TOKEN":"%s"}}'' "$B" | sudo k3s kubectl apply --server-side --force-conflicts --field-manager=t045-restore -f -; fi',
  '     unset B',
  '     sudo k3s kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath=''{.data.TUNNEL_TOKEN}'' | sha256sum',
  '     set -o history')
$R3_ORDER = { param($t)
  $f = @()
  $ls = @(($t -split "`n") | ForEach-Object { ([string]$_).TrimEnd() })
  $i0 = -1; $i1 = -1
  for ($i = 0; $i -lt $ls.Count; $i++) {
    if ([string]::Equals([string]$ls[$i], '     set +o history', [StringComparison]::Ordinal)) { $i0 = $i }
    if ([string]::Equals([string]$ls[$i], '     set -o history', [StringComparison]::Ordinal)) { $i1 = $i } }
  if ($i0 -lt 0 -or $i1 -le $i0) { return @('R3 조각의 set +o history … set -o history 구간을 찾지 못했다') }
  $got = @($ls[$i0..$i1] | ForEach-Object { ([string]$_).Trim() })
  if ($got.Count -ne $R3_SEQ.Count) { return @("R3 조각이 $($got.Count) 줄(기대 $($R3_SEQ.Count) 줄 · 줄이 빠지거나 끼었다): $($got -join ' ⏎ ')") }
  for ($i = 0; $i -lt $R3_SEQ.Count; $i++) {
    if (-not [string]::Equals([string]$got[$i], ([string]$R3_SEQ[$i]).Trim(), [StringComparison]::Ordinal)) {
      $f += "R3 조각 $($i + 1)번째 줄이 기대와 다르다(기대 '$([string]$R3_SEQ[$i])' · 실제 '$([string]$got[$i])')" } }
  $f }
# X05 계열(요약의 기준값 파드서명 줄 자체를 없애는 변이) — 그 줄은 1) 화면 출력과 문면이 같아서 부분 문자열 want 로는
# 요약 쪽만 사라진 것을 볼 수 없다. 출현 **횟수**(화면 1 · 요약 1 = 2)로 고정한다.
$PODSIG_TWICE = { param($t)
  $n = @([regex]::Matches($t, '(?m)^기준값 파드서명 = ')).Count
  if ($n -ne 2) { return @("'기준값 파드서명 = ' 줄이 $n 개(화면 1 · 요약 1 = 2 이어야 한다)") }
  @() }
# ---- 정상 경로
$DOK = { Adopt-Now; & $IN @($BOOT, 'go', $PRE_HASH, $PRE_UID, $POD2, 'drill') }
Run-Case 'G4-01' '캡처 → 머지 대기 → 판정 PASS → 인계(쓰기 0)' 'adopt' { & $OK } 'ok' @(' 초 경과(ES=', 'OK 값 불변', 'drill 입력 preHash', 'g4-drill.ps1', '이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-02b' 'resume은 해시·UID만 이어받아 판정(파드 불변 미판정)' 'adopt' { Adopt-Now; & $IN @($BOOT,'go','resume',$PRE_HASH,$PRE_UID,'skip-pm','continue') } 'ok' @('파드 불변은 판정하지 않았다', '이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-53' '중단한 resume도 쓰기 0(A5-1)' 'adopt' { Adopt-Now; $global:Sec.data['TUNNEL_TOKEN']=$TOK2; & $IN @($BOOT,'go','resume',$PRE_HASH,$PRE_UID,'skip-pm','continue') } '대기 중 터널 값' @('이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-54' '라벨·data-hash 둘 다 제거한 재인수도 쓰기 0(B5-02)' 'adopt' { & $OK; $global:Pods[1].start=$ST3 } 'ok' @('이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-55' '라벨만 제거한 재인수도 쓰기 0' 'adopt' { & $OK; $global:Sec.ann['reconcile.external-secrets.io/data-hash']='prior' } 'ok' @('이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-EOF1' '정지점 EOF' 'adopt' { & $OK; $global:EofAfter=2 } 'EOF'
Run-Case 'G4-EOF2' '기준 해시 입력 EOF' 'adopt' { Adopt-Now; & $IN @($BOOT,'go','resume'); $global:EofAfter=4 } 'EOF'
Run-Case 'G4-EOF3' 'PM 비밀 EOF' 'adopt' { & $IN @($BOOT,'go','pm'); $global:EofAfter=4 } '입력 스트림이 닫혔다'
Run-Case 'G4-EMPTY' 'PM 비밀 빈 입력' 'adopt' { & $IN @($BOOT,'go','pm','') } '빈 입력'
Run-Case 'G4-02' '이미 인수된 Secret(managed 라벨) → 시작 거부' 'adopt' { Adopt-Now; & $IN @($BOOT, 'go', '') } '정지점에서 중단' `
  @('이미 ESO 가 손댄 Secret') @('OK 값 불변') @()
Run-Case 'G4-02c' 'resume: 기준값 형식이 아니면 거부' 'adopt' {
  Adopt-Now; & $IN @($BOOT, 'go', 'resume', 'not-a-hash', $PRE_UID, 'skip-pm', 'continue') } 'preHash 형식이 아니다' @() @() @()
Run-Case 'G4-02g' 'resume: ES 존재 확인 자체가 실패 → "ES 없음 = 인수 해제 상태"로 읽지 않는다(fail-closed)' 'adopt' {
  Adopt-Now; $global:FailAlways['es.name'] = 1
  & $IN @($BOOT, 'go', 'resume', $PRE_HASH, $PRE_UID, 'skip-pm', 'continue') } 'ES 존재 확인(resume)' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('인수 해제 상태', 'OK 값 불변') @()
Run-Case 'G4-03' '키가 2개 → 거부(인수 순간 삭제되는 키)' 'adopt' {
  $global:Sec.data['EXTRA'] = 'not-a-secret'; & $OK } 'TUNNEL_TOKEN 외의 키가 있다' @() @('OK 값 불변') @()
Run-Case 'G4-04' '머지 대기 중 ES 미출현 → 타임아웃(파드 미접촉)' 'adopt' {
  $global:EsAppears = $false; & $OK } '15분 안에 ES 가 SecretSynced 가 되지 않았다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('드릴 후 파드서명') @()
Run-Case 'G4-05' 'ES SecretSyncedError → 파드 미접촉 중단' 'adopt' {
  $global:EsReason = 'SecretSyncedError'; & $OK } 'SecretSyncedError 로 굳었다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변') @()
Run-Case 'G4-06' '인수 뒤 값 해시 변경(폴링 중) → 파드 미접촉 중단 + 복구 안내(컨테이너 재시작 경고 · 키 집합 감별 포함)' 'adopt' {
  $global:Faults['changeValue'] = $true; & $OK } '대기 중 터널 값' `
  @('복구 안내(터널 값이 바뀌었다)', '컨테이너가 재시작되지 않는 동안만', '지금   파드서명:', '지금 Secret 의 키 집합: TUNNEL_TOKEN',
    '키 집합은 정상이다', 'kv-correct.ps1', 'g4-restore.ps1', '출처는 **c(PM 직접 입력)뿐**', 'temporary',
    '④ 위 sha256sum 대조로 값이 옳은 것을 확인한 뒤에만 파드를 **1개만** 지운다',
    'finalizer 가 있다', 'R3(이미 잠겼다', 'read -rsp', '이 실행이 클러스터에 가한 변경: 0 건',
    '⚠ 전제: g4-restore 는 해시 대조에 닿기 전에', '위 2번의 webhook 단서를 그대로 적용한다',
    "`n     set +o history`n", "`n     set -o history`n", '대소문자 무시', 'sudo -v',
    'get secret cloudflared-tunnel -o jsonpath=''{.data.TUNNEL_TOKEN}'' | sha256sum',
    'case "$T" in ''''|*[!''!''-~]*) echo BROKEN-PASTE;;',
    '이 조각은 **첫 줄(set +o history)부터** 실행한다',
    '판정은 네 갈래다', '쓰기는 **0건**이다', '이미 썼는데 값이 틀렸을 수 있다',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', '"쓰지 않았다"고 가정하지 않는다',
    '이 터미널 화면에 이미 에코됐다', '스크롤백·세션 로그', 'delete pod POD_NAME',
    'sudo 는 -S 없이는 stdin 에서 암호를 읽지 않는다',
    '**data-hash 어노테이션은 어떤 경우에도 지우지 않는다.**',
    "`n     unset B`n", "`n     unset T`n",
    '(0) **apply 줄에 kubectl 오류가 찍혔다 → 결과 미확정이다.**', 'field is immutable',
    'get secret cloudflared-tunnel -o jsonpath=''{.type}''',
    '※ apply 줄의 오류는 (3) 이 아니라 (0) 이다.',
    'case 줄의 ''!'' 를 따옴표로 감싼 것은 대화형 bash 의 히스토리 확장 때문이다',
    '따옴표가 없으면 그 자리가 직전 명령으로 치환돼 패턴이 **직전 명령에 따라 제멋대로 바뀐다**',
    '보호하는 것은 여는 대괄호가 아니라 **첫 느낌표 다음 글자**다') `
  @('라이브가 아직 옳으면', '출처 a', '기준값 preHash 는 1R) pm 으로',
    '*[!!-~]*', 'delete pod <', '해시가 다르면 **아무것도 쓰지 않은 것**이다',
    '판정은 세 갈래다', '정상 토큰도 늘 BROKEN-PASTE') @() -post $R3_ORDER
Run-Case 'G4-06c' 'ES 매핑이 틀려 TUNNEL_TOKEN 키가 사라짐 → 원인을 kv 가 아니라 매핑으로 지목하고 R2 로 보낸다(B-1)' 'adopt' {
  $global:Faults['dropKey'] = $true
  & $OK } '대기 중 터널 값' `
  @('지금 Secret 의 키 집합: WRONG_KEY', '원인은 ②ES 매핑', 'R1(kv 정정)은 무의미하니 건너뛰고 곧장 R2',
    'CreateContainerConfigError', '이 실행이 클러스터에 가한 변경: 0 건') @('키 집합은 정상이다') @()
Run-Case 'G4-06d' '값 변경 + 키 집합 조회까지 실패 → "정상"으로 읽지 않는다(fail-closed 안내)' 'adopt' {
  $global:Faults['changeValue'] = $true
  $global:OnMerge = { $global:FailAlways['sec.keys'] = 1 }
  & $OK } '대기 중 터널 값' `
  @('지금 Secret 의 키 집합: (조회 실패)', '키 집합을 읽지 못했다') @('키 집합은 정상이다', '원인은 ②ES 매핑') @()
Run-Case 'G4-32' '폴링 중 값이 바뀌고 ES 는 끝내 SecretSynced 가 되지 않는다 → 감시 루프만이 잡을 수 있는 경로' 'adopt' {
  $global:EsAppears = $false
  $global:OnMerge = { $global:Sec.data['TUNNEL_TOKEN'] = $TOK2 }
  & $OK } '대기 중 터널 값' `
  @('복구 안내(터널 값이 바뀌었다)', '이 실행이 클러스터에 가한 변경: 0 건') `
  @('15분 안에 ES 가 SecretSynced 가 되지 않았다', '아무것도 바꾸지 않았다') @()
Run-Case 'G4-33' 'resume 인데 라이브 값이 이미 덮여 있다 → 운영자가 든 preHash 가 그것을 드러낸다(가짜 PASS 금지)' 'adopt' {
  Adopt-Now; $global:Sec.data['TUNNEL_TOKEN'] = $TOK2
  & $IN @($BOOT, 'go', 'resume', $PRE_HASH, $PRE_UID, 'skip-pm', 'continue') } '터널 값이 바뀌었다' `
  @('복구 안내(터널 값이 바뀌었다)', '이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변') @()
Run-Case 'G4-07' 'UID 만 변경(값 해시는 같다) → kv 정정이 아니라 UID 전용 안내' 'adopt' {
  $global:Faults['changeUid'] = $true; & $OK } 'Secret 이 재생성됐다' `
  @('안내(UID 만 바뀌었다', 'kv 는 틀리지 않았다',
    '지금   UID    : ffffeeee-dddd-4ccc-8bbb-aaaa99998888', "기준값 preUid : $PRE_UID",
    'kubectl -n cloudflared get secret cloudflared-tunnel -o ''jsonpath={.metadata.uid}''') `
  @('복구 안내(터널 값이 바뀌었다)', '드릴 후 파드서명') @()
Run-Case 'G4-06b' 'SecretSynced 직후(폴링이 끝난 뒤) 값이 바뀜 → 3) 인수 판정이 잡는다' 'adopt' {
  $global:Faults['changeAfterSync'] = $true; & $OK } '인수 뒤 터널 값' `
  @('복구 안내(터널 값이 바뀌었다)', '이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변', '대기 중 터널 값') @()
Run-Case 'G4-07b' 'SecretSynced 직후(폴링이 끝난 뒤) UID 가 바뀜 → 3) 인수 판정이 잡는다' 'adopt' {
  $global:Faults['changeUidAfterSync'] = $true; & $OK } 'UID 가 바뀌었다 = 제자리 인수가 아니라 재생성이다' `
  @('안내(UID 만 바뀌었다', '이 실행이 클러스터에 가한 변경: 0 건',
    '지금   UID    : ffffeeee-dddd-4ccc-8bbb-aaaa99998888') @('OK 값 불변', '드릴 후 파드서명') @()
Run-Case 'G4-08' 'ownerReferences 부착 → 중단' 'adopt' {
  $global:Faults['ownerRef'] = $true; & $OK } 'ownerReferences 가 붙었다' @('이 실행이 클러스터에 가한 변경: 0 건') @() @()
Run-Case 'G4-09' 'Argo tracking 어노테이션이 Secret 에 복사됨 → 중단' 'adopt' {
  $global:Faults['copyTracking'] = $true; & $OK } 'Argo tracking 어노테이션이 복사됐다' @() @() @()
Run-Case 'G4-10' '머지 대기 중 파드 재시작(restartCount 변화) → 중단' 'adopt' {
  $global:Faults['podRestart'] = $true; & $OK } '파드가 바뀌었다' @('이 실행이 클러스터에 가한 변경: 0 건') @() @()
Run-Case 'G4-13a' 'kubectl 조회 실패(캡처 시점) → fail-closed' 'adopt' {
  $global:FailAlways['sec.data'] = 1; & $OK } 'kubectl 조회 실패(exit=1 · 3회 시도)' `
  @('이 실행은 아직 아무것도 바꾸지 않았다', '재시작·삭제해서 고치려 하지 않는다') @() @()
Run-Case 'G4-13b' 'kubectl 조회 실패(머지 대기 폴링 중 · merge 입력 뒤에 무장) → fail-closed + 재시작 금지 경고' 'adopt' {
  & $OK; $global:OnMerge = { $global:FailAlways['es.name'] = 1 } } 'ES 출현 확인' `
  @('이 실행이 클러스터에 가한 변경: 0 건', '인수 판정이 끝나지 않았다',
    'merge 입력됨 — 폴링 도중 중단(인수 판정 미완)') @('드릴 후 파드서명') @()
Run-Case 'G4-13c' 'kubectl 조회 실패(판정 시점) → fail-closed' 'adopt' {
  & $OK; $global:FailAlways['sec.owner'] = 7 } 'kubectl 조회 실패(exit=7 · 3회 시도): ownerReferences' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @() @()
Run-Case 'G4-13e' '일시적 조회 실패 1회(폴링 중) → 재시도로 완주(실패를 성공으로 읽지 않는다)' 'adopt' {
  & $OK; $global:OnMerge = { $global:FailN['sec.uid'] = 1 } } 'ok' @('5초 뒤 재시도(1/3)', 'OK 값 불변') @() @()
Run-Case 'G4-14a' '정지점 0) 에 빈 Enter → 중단' 'adopt' { & $IN @($BOOT, '') } '정지점에서 중단' @() @('기준값 preHash') @()
Run-Case 'G4-14c' '정지점 단어는 Ordinal 비교다 — 대문자 GO 로는 통과하지 못한다' 'adopt' { & $IN @($BOOT, 'GO') } '정지점에서 중단' `
  @() @('기준값 preHash') @()
Run-Case 'G4-15' 'ssh 새 연결 실패 → 창 A 대조 불가 · 확인 단어가 noglass 로 바뀐다(미리 눌러 둔 go 가 통과하지 못한다)' 'adopt' {
  $global:SshOk = $false; & $IN @('go', 'skip-pm', 'merge') } '정지점에서 중단' `
  @('ssh ssh-a = False', '창 A 세션을 대조할 수 없다') @('OK 창 A 에', '드릴 후 파드서명') @()
Run-Case 'G4-15b' 'oci 자격 실패 → 단어가 no-oci 로 바뀐다(ssh 만 실패한 noglass 와 구분)' 'adopt' {
  $global:OciOk = $false; & $IN @($BOOT, 'no-oci', 'skip-pm', 'merge') } 'ok' `
  @('oci 자격(프로파일 DEFAULT) = False') @() @()
Run-Case 'G4-15c' '창 A 의 boot_id 가 노드 A 와 다르다 → 열린 세션 없음으로 중단' 'adopt' {
  & $IN @('deadbeef', 'go', 'skip-pm', 'merge') } '창 A 의 값이 노드 A 의 boot_id 와 다르다' @() @() @()
Run-Case 'G4-15d' '읽기 전용 svc-verify 프로파일 → oci 를 break-glass 로 세지 않는다(단어 no-oci)' 'adopt' {
  $env:OCI_CLI_PROFILE = 'svc-verify'; & $IN @($BOOT, 'no-oci', 'skip-pm', 'merge') } 'ok' `
  @('읽기 전용 세션 프로파일', 'oci 자격(프로파일 svc-verify) = False') @() @()
Run-Case 'G4-16' 'SecretSynced 인데 managed 라벨 없음 → 양성 증거 부재로 중단' 'adopt' {
  $global:Faults['noLabel'] = $true; & $OK } 'managed 라벨이 없다' @() @() @()
Run-Case 'G4-16b' 'managed 라벨은 있는데 data-hash 없음 → ESO 의 쓰기가 닿지 않았다(하드 판정)' 'adopt' {
  $global:Faults['noDataHash'] = $true; & $OK } 'data-hash 어노테이션이 없다' @() @('OK 값 불변') @()
Run-Case 'G4-17' 'ES 의 tracking-id 가 platform-secrets 가 아님 → 중단' 'adopt' {
  $global:EsTrack = 'platform-cloudflared:external-secrets.io/ExternalSecret:cloudflared/cloudflared-tunnel'; & $OK } 'ES 를 관리하는 Application 이 platform-secrets 가 아니다' @() @() @()
Run-Case 'G4-17b' 'ES 의 tracking-id 가 비었음 → 판정 불가로 중단' 'adopt' {
  $global:EsTrack = ''; & $OK } 'tracking-id 가 비었다' @() @('app.kubernetes.io/instance') @()
Run-Case 'G4-18' 'platform-cloudflared 가 external-secrets.io 자원을 소유 → 중단' 'adopt' {
  $global:AppRes = '/Deployment external-secrets.io/ExternalSecret '; & $OK } 'external-secrets.io 자원을 소유하고 있다' @() @() @()
Run-Case 'G4-19' '파드가 3개(노드당 1개 전제 붕괴) → 중단' 'adopt' {
  $global:Pods += @{ name = 'cloudflared-6d4f7c9b8-dd44d'; restarts = 0; start = $ST2; ready = 'True'; lab = 'app=cloudflared' }; & $OK } '파드가 2개가 아니다' @() @() @()
Run-Case 'G4-19b' 'ns 안의 무관한 파드(app 라벨 다름)는 커넥터로 세지 않는다' 'adopt' {
  $global:Pods += @{ name = 'debug-shell'; restarts = 0; start = $ST2; ready = 'True'; lab = 'app=debug' }; & $OK } 'ok' `
  @('OK 값 불변') @('파드가 2개가 아니다') @()
Run-Case 'G4-20' '머지 전인데 ES 가 이미 있다 → 중단' 'adopt' {
  $global:Es = @{ reason = 'SecretSynced'; created = (EsStamp); ann = @{ 'argocd.argoproj.io/tracking-id' = $ES_TRACK_OK } }; & $OK } 'ES 가 이미 있다' @() @() @()
Run-Case 'G4-21' '새 파드 로그에 Registered tunnel connection 없음 → 경고(중단 아님)' 'drill' {
  $global:LogHit = $false; & $DOK } 'ok' @('Registered tunnel connection 을 찾지 못했다', '두 번째 파드는 교체하지 않는다') @('OK 새 파드 로그에') $DEL2
Run-Case 'G4-22' '드릴 뒤 노드가 Ready 2 가 아니다 → 중단' 'drill' {
  $global:NodeReady = 'joshtech-api=True joshtech-cache=False '; & $DOK } 'Ready 2 개가 아니다' @() @() $DEL2
Run-Case 'G4-23' '드릴 뒤 ssh 만 실패(kubectl 은 정상) → 경고로 남기고 완주' 'drill' {
  $global:SshOkAfter = $false; & $DOK } 'ok' `
  @('드릴 전에는 되던 ssh ssh-a 가 드릴 뒤에 실패한다', '두 번째 파드를 절대 교체하지 말고') @() $DEL2
Run-Case 'G4-26' 'agent-view kubeconfig(auth can-i = no · exit 1) → 재시도 없이 맞춤 문면' 'adopt' {
  $global:Faults['canINo'] = $true; & $OK } "'get secrets' 를 할 수 없다(응답='no'" `
  @() @('5초 뒤 재시도') @()
Run-Case 'G4-27' '가드 통과 직후 ESO 가 손댐 → 같은 GET 의 managed 라벨로 잡아 가짜 기준값을 막는다' 'adopt' {
  $global:Faults['snapLabel'] = $true; & $OK } '캡처하는 사이에 ESO 가 Secret 에 손댔다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변') @()
Run-Case 'G4-31' '드릴 대기 중 남은 파드까지 재시작(서명 변경) → 더 이상 아무것도 삭제하지 않는다' 'drill' {
  $global:BumpSurvivorOnDelete = $true; & $DOK } '재시작·교체됐다(서명 변경)' `
  @('이 실행이 클러스터에 가한 변경: 1 건') @() $DEL2
Run-Case 'G4-30' '1P) PM 토큰 해시가 기준값과 다르다 → 머지 전에 중단(아무것도 잠기지 않았다)' 'adopt' {
  & $IN @($BOOT, 'go', 'pm', $TOK2, 'merge') } 'PM 의 토큰이 기준값과 다르다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('OK PM 토큰 해시') @()
Run-Case 'G4-30b' '1P) PM 토큰 해시 일치 → 확인 문면(토큰은 SecureString · 어떤 표면에도 남지 않는다)' 'adopt' {
  & $IN @($BOOT, 'go', 'pm', $TOK, 'merge') } 'ok' `
  @('OK PM 토큰 해시 = preHash', '완료(PM 해시 = preHash)') @() @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ([string]::Equals([string]$r.value, $TOK, [StringComparison]::Ordinal) -and -not $r.secure) { $f += '토큰을 평문으로 읽었다' } }; $f }
Run-Case 'G4-30c' '1P) 클립보드 기록이 켜져 있으면 토큰을 묻지 않는다' 'adopt' {
  $global:ClipHistory = 1; & $IN @($BOOT, 'go', 'pm', $TOK, 'merge') } '클립보드 기록이 꺼져 있음을 확인하지 못했다' @() @() @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
Run-Case 'G4-30d' '1P) 에 엉뚱한 단어 → 중단' 'adopt' { & $IN @($BOOT, 'go', 'yes', 'merge') } '1P) 정지점에서 중단' @() @() @()
Run-Case 'G4-34' 'KUBECONFIG 가 다른 클러스터를 본다 → 아무것도 하지 않고 중단(A-7)' 'adopt' {
  $global:NodeNames = @('node/other-a', 'node/other-b'); & $OK } 'joshuatech 클러스터를 보고 있지 않다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('기준값 preHash') @()
Run-Case 'G4-35' '머지 전 파드 하나가 NotReady → 캡처 단계에서 중단(한쪽 커넥터가 이미 불안정하다 · A-7)' 'adopt' {
  $global:Pods[1].ready = 'False'; & $OK } "파드 $POD2 이 Ready 가 아니다" `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변', 'SKIP 드릴') @() -notWantPrompt @('2)')
Run-Case 'G4-36b' 'break-glass 둘 다 실패인데 예전 단어(no-oci)를 넣으면 통과하지 못한다' 'adopt' {
  $global:SshOk = $false; $global:OciOk = $false
  & $IN @('no-oci', 'skip-pm', 'merge') } '정지점에서 중단' @() @('기준값 preHash', '드릴 후 파드서명') @()
Run-Case 'G4-38' '1R) preHash 기록이 없어 pm 으로 유도 → 1P) 대조는 건너뛰고(같은 출처 비교) 기준값에 "PM 유도" 꼬리표가 붙는다(F-B2-02)' 'adopt' {
  Adopt-Now
  & $IN @($BOOT, 'go', 'resume', 'pm', $TOK, $PRE_UID, 'continue') } 'ok' `
  @('preHash 를 PM 원본에서 유도했다', "기준값 preHash = $PRE_HASH (PM 유도 — 라이브로 검증된 적 없음)",
    '1P) PM 원본 대조를 건너뛴다', '건너뜀(기준값이 PM 유도라 같은 출처 대조는 성립하지 않는다', 'OK 값 불변') `
  @('OK PM 토큰 해시 = preHash', '완료(PM 해시 = preHash)') @() {
  param($t)
  $f = @()
  foreach ($r in $global:ReadLog) { if ([string]::Equals([string]$r.value, $TOK, [StringComparison]::Ordinal) -and -not $r.secure) { $f += '토큰을 평문으로 읽었다' } }
  # 꼬리표는 **화면과 요약 두 곳** 모두에 있어야 한다 — 한쪽만 지운 변이를 부분 문자열 검사로는 볼 수 없다.
  $n = @([regex]::Matches($t, [regex]::Escape("기준값 preHash = $PRE_HASH (PM 유도 — 라이브로 검증된 적 없음)"))).Count
  if ($n -ne 2) { $f += "PM 유도 꼬리표가 붙은 기준값 줄이 $n 개(화면 1 · 요약 1 = 2 이어야 한다)" }
  $f }
Run-Case 'G4-38b' '1R) pm 인데 클립보드 기록이 켜져 있다 → 토큰을 묻기 전에 중단(A2-2)' 'adopt' {
  Adopt-Now; $global:ClipHistory = 1
  & $IN @($BOOT, 'go', 'resume', 'pm', $TOK, $PRE_UID, 'continue') } '클립보드 기록이 꺼져 있음을 확인하지 못했다' `
  @() @('OK 값 불변') @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
$PRE_HASH_PM = SHA (B64 $TOK2)
Run-Case 'G4-42' '기준값이 PM 유도인데 라이브와 다르다 → 복구 안내가 "kv 를 PM 값으로 정정"으로 단정하지 않는다(F-B2-02)' 'adopt' {
  Adopt-Now
  & $IN @($BOOT, 'go', 'resume', 'pm', $TOK2, $PRE_UID, 'continue') } '대기 중 터널 값이 바뀌었다' `
  @("기준값 preHash = $PRE_HASH_PM (PM 유도 — 라이브로 검증된 적 없음)", '1P) PM 원본 대조를 건너뛴다',
    '복구 안내(터널 값이 바뀌었다)', '라이브로 검증된 적이 없다', 'PM 이 낡은 것이라면 라이브 값은 옳다',
    '자기 자신 비교', '이 실행이 클러스터에 가한 변경: 0 건') `
  @('OK PM 토큰 해시 = preHash') @()
Run-Case 'G4-46b' '같은 상황에서 옛 단어(noglass)로는 통과하지 못한다(A3-3)' 'adopt' {
  $global:SshOk = $false; $global:OciEmpty = $true
  & $IN @('noglass', 'skip-pm', 'merge') } '정지점에서 중단' @() @('기준값 preHash') @()
Run-Case 'G4-47' '파드 jsonpath 가 3필드로 온다 → 오판하지 않고 중단(A3-5)' 'adopt' {
  $global:BadPodRow = $true; & $OK } '파드 행 형식이 기대와 다르다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('OK 값 불변', '삭제 요청') @()
Run-Case 'G4-47b' '파드 목록이 exit 0 인데 빈 응답 → "파드 없음"으로 읽지 않는다(A3-5)' 'adopt' {
  $global:NoPodRows = $true; & $OK } '파드 목록이 비었다' `
  @('이 실행이 클러스터에 가한 변경: 0 건') @('삭제 요청') @()
Run-Case 'G4-48' 'ssh 가 boot_id 형식이 아닌 것을 돌려준다 → 창 A 대조를 하지 않고 단어가 noglass 로 갈린다(A3-5)' 'adopt' {
  $global:BootId = 'joshtech-api'
  & $IN @('noglass', 'skip-pm', 'merge') } 'ok' `
  @('ssh ssh-a = False', '창 A 세션을 대조할 수 없다') @('OK 창 A 에') @()
# ---- 복구 블록
$APPLY1 = @('apply --server-side --force-conflicts --field-manager=t045-restore --request-timeout=30s -f -')
Run-Case 'R-01' '정상 복구: ES 없음 · Git 선언 없음 · PM 토큰 해시 일치 → 제자리 복구' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } 'ok' `
  @('OK PM 토큰 해시 = preHash', 'OK 복구 완료: 값 해시 = preHash · UID 불변', '이 실행이 클러스터에 가한 변경: 1 건',
    '"지금 이 순간"의 값이다', '더 이상 선언하지 않는다') @() $APPLY1 {
  $f = @(); if (-not [string]::Equals([string]$global:Sec.data['TUNNEL_TOKEN'], $TOK, [StringComparison]::Ordinal)) { $f += '복구된 값이 다르다' }; $f }
Run-Case 'R-02' '해시 불일치 토큰 → 거부(아무것도 쓰지 않는다)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK2) } 'PM 토큰의 해시가 preHash 와 다르다' `
  @('아무것도 쓰지 않았다') @() @() {
  $f = @(); if (-not [string]::Equals([string]$global:Sec.data['TUNNEL_TOKEN'], $TOK2, [StringComparison]::Ordinal)) { $f += 'Secret 이 바뀌었다' }; $f }
Run-Case 'R-03' 'ES 가 아직 살아 있다 → restore 로는 통과하지 못한다(temporary 요구)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; Adopt-Now
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '정지점에서 중단' `
  @('ES 가 아직 살아 있다', 'revert PR') @() @()
Run-Case 'R-04' 'ES 가 살아 있어도 temporary 를 입력하면 임시 복구' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; Adopt-Now
  & $IN @($PRE_HASH, $PRE_UID, 'temporary', $TOK) } 'ok' `
  @('OK 복구 완료', '≤5분 뒤 다시 덮인다') @() $APPLY1
Run-Case 'R-05' '현재 값이 이미 기준값과 같다 → SKIP(재실행 안전 · 토큰을 묻지 않는다)' 'restore' {
  & $IN @($PRE_HASH, $PRE_UID) } 'ok' `
  @('SKIP 현재 Secret 의 값이 이미 기준값과 같다') @('PM 의 터널 토큰 원본') @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
Run-Case 'R-06' '클립보드 기록이 켜져 있음 → 프롬프트 전에 중단' 'restore' {
  $global:ClipHistory = 1; & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '클립보드 기록이 켜져 있음' @() @() @() {
  $f = @(); if ($global:Prompts.Count -gt 0) { $f += "먼저 물었다($($global:Prompts.Count))" }; $f }
Run-Case 'R-07' '붙여넣기 손상(공백 섞임) → 거부' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2
  & $IN @($PRE_HASH, $PRE_UID, 'restore', ($TOK.Substring(0, 10) + ' ' + $TOK.Substring(10))) } 'ASCII 인쇄 문자 밖의 문자' `
  @('아무것도 쓰지 않았다') @() @()
Run-Case 'R-08' '현재 UID 가 preUid 와 다름 → newuid 정지점에서 중단' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:Sec.uid = 'ffffeeee-dddd-4ccc-8bbb-aaaa99998888'
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '정지점에서 중단' `
  @('현재 UID 가 preUid 와 다르다') @() @()
Run-Case 'R-09' 'apply 가 비0 으로 끝남 → "쓰지 않았다"고 단정하지 않는다(모호한 실패)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:FailAlways['apply'] = 1
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '서버에 반영됐는지는 알 수 없다' `
  @('apply 요청을 보냈다 — 결과 미확인', '쓰기를 시도했지만 결과를 확인하지 못했다', '이 블록을 다시 실행해 2) 의 해시 대조로 확인한다') `
  @('아무것도 쓰지 않았다', 'OK 복구 완료', ('4) Secret 복구' + (' ' * 11) + '미실행')) $APPLY1
Run-Case 'R-10' 'ES 는 없지만 Git 에 아직 선언돼 있다 → restore 로는 통과하지 못한다(selfHeal 이 되살린다)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:ArgoEs = 'cert-manager/cloudflare-dns-token= cloudflared/cloudflared-tunnel= '
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '정지점에서 중단' `
  @('Git(platform-secrets)에는 아직 선언돼 있다') @() @()
Run-Case 'R-10b' 'Git 에서 빠져 requiresPruning=true → 정상 순서이므로 restore 로 통과' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:ArgoEs = 'cert-manager/cloudflare-dns-token= cloudflared/cloudflared-tunnel=true '
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } 'ok' @('OK 복구 완료') @('아직 선언돼 있다') $APPLY1
Run-Case 'R-11' 'agent-view kubeconfig(auth can-i = no · exit 1) → 재시도 없이 맞춤 문면 · 토큰 미입력' 'restore' {
  $global:Faults['canINo'] = $true; & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } "Secret 을 쓸 수 없다(응답='no'" `
  @('토큰 미입력') @('5초 뒤 재시도') @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
Run-Case 'R-12' 'apply 직후 ESO 가 값을 다시 덮음 → 쓰기 뒤 되읽기가 잡는다("OK 복구 완료"를 내지 않는다)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:RevertAfterApply = $true
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '복구 후 값이 여전히 preHash 와 다르다' `
  @('값은 썼지만 5) 복구 확인이 끝나지 않았다', 'ES 를 먼저 멈춘다') @('OK 복구 완료', '방금의 확인은') $APPLY1
Run-Case 'R-13' 'apply 직후 Secret 이 재생성(UID 변경) → 제자리 수정이 아니라고 잡는다' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:ChangeUidAfterApply = $true
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '복구 과정에서 Secret 이 재생성됐다' `
  @('값은 썼지만 5) 복구 확인이 끝나지 않았다') @('OK 복구 완료', '방금의 확인은') $APPLY1
Run-Case 'R-14' 'Argo 조회 실패 → 복구를 막지는 않되 단어를 temporary 로(빈 응답을 "선언 없음"으로 읽지 않는다 · B-3)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:FailAlways['app.es'] = 1
  & $IN @($PRE_HASH, $PRE_UID, 'temporary', $TOK) } 'ok' `
  @('선언 목록을 확인하지 못했다', 'OK 복구 완료', 'Git 선언=확인 못 함') @('확인: platform-secrets 는 이 ExternalSecret 을 더 이상 선언하지 않는다') $APPLY1
Run-Case 'R-14b' 'Argo 응답에 양성 대조 행이 없다 → 같은 취급(조회가 된 것이 아니다 · B-3)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:ArgoEs = ' '
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '정지점에서 중단' `
  @("양성 대조 행 'cert-manager/cloudflare-dns-token=' 이 없다") @('확인: platform-secrets 는 이 ExternalSecret 을 더 이상 선언하지 않는다') @()
Run-Case 'R-15' 'Secret 자체가 없다 → 제자리 복구 전용이라는 그 사실을 말한다(일반 조회 실패 문면이 아니다 · B-10)' 'restore' {
  $global:SecGone = $true; & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } '제자리 복구 전용' `
  @('아무것도 쓰지 않았다') @('kubectl 조회 실패') @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
# A3-5 / V10·V18 — type 은 불변 필드다. 빈 값을 읽고도 진행하거나 Opaque 로 하드코딩하면 실물 apply 가 거부된다.
Run-Case 'R-16' '(복구) Secret 의 type 이 exit 0 인데 빈 응답 → 판정 불가로 중단(A3-5)' 'restore' {
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2; $global:EmptyType = $true
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } 'Secret 의 type 을 읽지 못했다' `
  @('아무것도 쓰지 않았다') @('OK 복구 완료') @() {
  $f = @(); foreach ($r in $global:ReadLog) { if ($r.secure) { $f += '토큰을 물었다' } }; $f }
Run-Case 'R-17' '(복구) apply 페이로드의 type 은 실제 Secret 의 type 이다(Opaque 하드코딩이 아니다 · A3-5)' 'restore' {
  $global:Sec.type = 'joshuatech.dev/tunnel-token'
  $global:Sec.data['TUNNEL_TOKEN'] = $TOK2
  & $IN @($PRE_HASH, $PRE_UID, 'restore', $TOK) } 'ok' `
  @('OK 복구 완료', 'type=joshuatech.dev/tunnel-token') @() $APPLY1 {
  $f = @()
  if (-not [string]::Equals([string]$global:AppliedType, 'joshuatech.dev/tunnel-token', [StringComparison]::Ordinal)) {
    $f += "apply 페이로드의 type 이 '$([string]$global:AppliedType)' 이다(실제 Secret 의 type 이어야 한다)" }
  $f }
# 독립 드릴: 각 게이트가 없어지면 변경 로그 또는 실패 문면이 달라져야 한다.
$DOK = { Adopt-Now; & $IN @($BOOT, 'go', $PRE_HASH, $PRE_UID, $POD2, 'drill') }
Run-Case 'D-01' '독립 드릴 정상 경로' 'drill' { & $DOK } 'ok' @('OK 새 파드', '방금 삭제한 커넥터를 타고 있었다면 끊겼다', 'PASS(ES Ready·값·UID·data-hash·파드 2개 Ready)') @() $DEL2 -wantPrompt @('창 A에서 Enter를 쳐 세션을 지금 다시 확인한다')
Run-Case 'D-02' '드릴 클러스터 신원 거부' 'drill' { & $DOK; $global:NodeNames=@('node/other') } '클러스터'
Run-Case 'D-03' '드릴 삭제 권한 거부' 'drill' { & $DOK; $global:CanIDeny='delete' } '할 수 없다'
Run-Case 'D-04' '드릴 ES 준비 상태 거부' 'drill' { & $DOK; $global:Es.reason='SecretSyncedError' } 'ES Ready'
Run-Case 'D-05' '드릴 값 해시 거부' 'drill' { & $DOK; $global:Sec.data['TUNNEL_TOKEN']=$TOK2 } '값 해시' @('복구 인계(value)')
Run-Case 'D-06' '드릴 UID 거부' 'drill' { & $DOK; $global:Sec.uid='ffffeeee-dddd-4ccc-8bbb-aaaa99998888' } 'UID' @('복구 인계(uid)') -notWantPrompt @('지울 파드 이름')
Run-Case 'D-07' '드릴 data-hash 없음 거부' 'drill' { & $DOK; $global:Sec.ann.Clear() } 'data-hash'
Run-Case 'D-08' '드릴 파드 개수 거부' 'drill' { & $DOK; $global:Pods=@($global:Pods[0]) } '2개'
Run-Case 'D-09' '드릴 대상 NotReady 거부' 'drill' { & $DOK; $global:Pods[1].ready='False' } 'Ready' -notWantPrompt @('지울 파드 이름')
Run-Case 'D-10' '드릴 남길 파드 NotReady 거부' 'drill' { & $DOK; $global:Pods[0].ready='False' } 'Ready' -notWantPrompt @('지울 파드 이름')
Run-Case 'D-11' '양쪽 break-glass 실패는 단어 확인 후 삭제 거부' 'drill' { Adopt-Now; $global:SshOk=$false; $global:OciOk=$false; & $IN @('no-breakglass') } '삭제 거부'
Run-Case 'D-12' '지울 파드 이름 오타 거부' 'drill' { Adopt-Now; & $IN @($BOOT,'go',$PRE_HASH,$PRE_UID,'typo','drill') } '정지점'
Run-Case 'D-13' '이전 교체 흔적 second 입력' 'drill' { Adopt-Now; $global:Es.created='2026-09-14T07:49:00Z'; & $IN @($BOOT,'go',$PRE_HASH,$PRE_UID,$POD2,'second') } 'ok' @('second') @() $DEL2
Run-Case 'D-14' '이전 교체 흔적 일반 drill 단어 거부' 'drill' { & $DOK; $global:Es.created='2026-09-14T07:49:00Z' } '정지점'
Run-Case 'D-15' '새 파드 Ready 타임아웃' 'drill' { & $DOK; $global:NewPodReady=$false } '300초' @('이 실행이 클러스터에 가한 변경: 1 건') @() $DEL2
Run-Case 'D-16' '삭제 후 kubectl 지속 실패' 'drill' { & $DOK; $global:FailPodsAfterDelete=$true } '300초' @('이 실행이 클러스터에 가한 변경: 1 건', '실행하지 않고 파일의 R3') @() $DEL2
Run-Case 'D-17' '삭제 실패 회계 선행' 'drill' { & $DOK; $global:FailAlways['delete']=1 } '요청 실패' @('이 실행이 클러스터에 가한 변경: 1 건') @() $DEL2
Run-Case 'D-18' '정지점 뒤 값 변경' 'drill' { & $DOK; $global:OnDrill={ $global:Sec.data['TUNNEL_TOKEN']=$TOK2 } } '정지점에서 기다리는 사이' @('복구 인계(value)', 'R1', 'R2', 'R3', '실행하지 않고', '컨테이너가 재시작되지 않는 동안만')
Run-Case 'D-19' '정지점 뒤 UID 변경' 'drill' { & $DOK; $global:OnDrill={ $global:Sec.uid='ffffeeee-dddd-4ccc-8bbb-aaaa99998888' } } 'UID 변경' @('복구 인계(uid)', 'kv-correct.ps1 · g4-restore.ps1 은 필요 없다', 'ffffeeee-dddd-4ccc-8bbb-aaaa99998888')
Run-Case 'D-20' '정지점 뒤 파드 변경' 'drill' { & $DOK; $global:OnDrill={ $global:Pods[1].restarts=1 } } '파드 상태'
Run-Case 'D-21' '입력 EOF는 삭제 전에 중단' 'drill' { & $DOK; $global:EofAfter=2 } 'EOF'
Run-Case 'D-22' 'Ready=False + SecretSynced 이유는 거부' 'drill' { & $DOK; $global:EsReady='False' } 'ES Ready'
Run-Case 'D-23' '삭제 대상 선택 startTime이 이름보다 우선' 'drill' { Adopt-Now; $global:Pods[0].start=$ST2; $global:Pods[1].start=$ST1; & $IN @($BOOT,'go',$PRE_HASH,$PRE_UID,$POD1,'drill') } 'ok' @("삭제 $POD1") @() @((& $DELARGV $POD1))
Run-Case 'D-24' '시각 같으면 이름 Ordinal 동률 해소' 'drill' { & $DOK; $global:Pods[0].start=$ST2 } 'ok' @("삭제 $POD2") @() $DEL2
Run-Case 'D-25' '삭제 후 남길 파드 변경 감지' 'drill' { & $DOK; $global:BumpSurvivorOnDelete=$true } '재시작·교체됐다' @() @() $DEL2
Run-Case 'D-26' 'OCI 빈 응답과 SSH 실패는 삭제 거부' 'drill' { Adopt-Now; $global:SshOk=$false; $global:OciEmpty=$true; & $IN @('no-breakglass') } '삭제 거부'
Run-Case 'D-27' '조회 일시 오류는 기한 내 재시도' 'drill' { & $DOK; $global:OnDrill={ $global:FailN['pods']=1 } } 'ok' @('5초 뒤 재시도') @() $DEL2
Run-Case 'D-28' '삭제 중 예외 회계 선행' 'drill' { & $DOK; $global:ThrowDelete=$true } 'mock interrupt' @('이 실행이 클러스터에 가한 변경: 1 건') @() $DEL2
Run-Case 'D-29' 'ES 시각 형식 판정 불가' 'drill' { & $DOK; $global:Es.created='2026-09-22T00:00:00+09:00' } 'creationTimestamp 형식'
Run-Case 'D-30' '빈 파드 시작시각은 판정 불가' 'drill' { & $DOK; $global:Pods[1].start='' } '파드 행 형식'
Run-Case 'D-31' '빈 Secret 값을 빈 문자열 해시로 승인할 수 없다' 'drill' { Adopt-Now; $global:Sec.data.Remove('TUNNEL_TOKEN'); & $IN @($BOOT,'go',(SHA ''),$PRE_UID,$POD2,'drill') } '빈 값'
Run-Case 'D-32' '삭제 후 생존 파드 Ready 상실' 'drill' { & $DOK; $global:SurvivorNotReadyAfterDelete=$true } '남은 파드' @('이 실행이 클러스터에 가한 변경: 1 건') @('OK 새 파드') $DEL2
Run-Case 'D-34' '삭제 대상이 남은 3파드 상태는 완료가 아니다' 'drill' { & $DOK; $global:DeleteRemoves=$false; $global:NewPodWithOld=$true } '300초' @('이 실행이 클러스터에 가한 변경: 1 건') @('OK 새 파드') $DEL2
Run-Case 'D-35' '비교는 Ordinal: 대문자 파드 이름 거부' 'drill' { Adopt-Now; & $IN @($BOOT,'go',$PRE_HASH,$PRE_UID,$POD2.ToUpperInvariant(),'drill') } '정지점'
Run-Case 'D-36' 'break-glass 거부의 경고 프롬프트' 'drill' { Adopt-Now; $global:SshOk=$false; $global:OciOk=$false; & $IN @('no-breakglass') } '삭제 거부' -wantPrompt @('잠기면 남는 복구 경로가 없다', '파드 삭제는 거부')
Run-Case 'D-37' '삭제 직전 키 조회 실패의 복구 진단' 'drill' { & $DOK; $global:OnDrill={ $global:Sec.data['TUNNEL_TOKEN']=$TOK2; $global:FailAlways['sec.keys']=1 } } '정지점에서 기다리는 사이' @('키 집합: (조회 실패)', '키 집합을 읽지 못했다')
# R3 대화형 bash 회귀: 실제 운영 블록은 실행하지 않고, 출력 전용 9줄만 AST에서 추출한다.
$bashPath = Join-Path $env:ProgramFiles 'Git/bin/bash.exe'
if (Test-Path -LiteralPath $bashPath) {
  $r3Ast = [System.Management.Automation.Language.Parser]::ParseFile($blocks['adopt'], [ref]$null, [ref]$null)
  $r3Lines = @($r3Ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Write-Host' }, $true) | Where-Object { $_.CommandElements.Count -eq 2 -and $_.CommandElements[1] -is [System.Management.Automation.Language.StringConstantExpressionAst] } | ForEach-Object { $_.CommandElements[1].Value })
  $begin = [Array]::IndexOf($r3Lines, '     set +o history')
  $end = [Array]::IndexOf($r3Lines, '     set -o history')
  $same = $begin -ge 0 -and $end -gt $begin -and ($end - $begin + 1) -eq $R3_SEQ.Count
  if ($same) { for ($i=0; $i -lt $R3_SEQ.Count; $i++) { if ($r3Lines[$begin+$i] -cne $R3_SEQ[$i]) { $same=$false } } }
  if (-not $same) {
    [void]$results.Add([pscustomobject]@{id='R3-BASH';result='FAIL';desc='대화형 모의';detail='출력 조각 계약이 달라 실행 거부'})
  } else {
    $mockPrefix = 'sudo() {
  if [[ "$*" == *"apply --server-side"* ]]; then
    local payload; IFS= read -r payload
    if [[ "$payload" == *''"TUNNEL_TOKEN":"QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE="''* ]]; then echo MOCK-APPLY-OK; else echo MOCK-PAYLOAD-FAIL; return 99; fi
  elif [[ "$*" == *"get secret"* ]]; then printf ''%s'' ''QUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUE='';
  else echo MOCK-UNEXPECTED; return 98; fi
}
kubectl() { echo DENIED; return 97; }
ssh() { echo DENIED; return 97; }
oci() { echo DENIED; return 97; }
readonly -f sudo kubectl ssh oci
set -H
'
    $scriptPath = Join-Path ([IO.Path]::GetTempPath()) ('t045-g4-r3-' + [guid]::NewGuid().ToString('N') + '.sh')
    try {
      [IO.File]::WriteAllText($scriptPath, $mockPrefix + (($r3Lines[$begin..$end] | ForEach-Object { $_.Trim() }) -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
      foreach ($case in @(@{id='GOOD';token=('A'*32);marker='MOCK-APPLY-OK'}, @{id='SHORT';token=('A'*8);marker='TOO-SHORT'}, @{id='BROKEN';token=(('A'*16)+' '+('A'*16));marker='BROKEN-PASTE'})) {
        $psi = [Diagnostics.ProcessStartInfo]::new($bashPath)
        foreach ($arg in @('--noprofile','--norc','-i',$scriptPath)) { [void]$psi.ArgumentList.Add($arg) }
        $psi.UseShellExecute=$false; $psi.CreateNoWindow=$true
        $psi.RedirectStandardInput=$true; $psi.RedirectStandardOutput=$true; $psi.RedirectStandardError=$true
        $psi.Environment['HISTFILE']='/dev/null'; $psi.Environment['BASH_ENV']=''; $psi.Environment['ENV']=''
        $proc = [Diagnostics.Process]::Start($psi)
        try {
          $stdout = $proc.StandardOutput.ReadToEndAsync(); $stderr = $proc.StandardError.ReadToEndAsync()
          $proc.StandardInput.Write($case.token + "`n"); $proc.StandardInput.Close()
          $done = $proc.WaitForExit(10000)
          if (-not $done) { $proc.Kill($true); throw '로컬 bash 모의 timeout' }
          $text = $stdout.GetAwaiter().GetResult(); $err = $stderr.GetAwaiter().GetResult()
          $ok = $proc.ExitCode -eq 0 -and $text.Contains($case.marker) -and -not $text.Contains('DENIED') -and -not $text.Contains('MOCK-PAYLOAD-FAIL')
          if ($case.id -ne 'GOOD' -and $text.Contains('MOCK-APPLY')) { $ok=$false }
          [void]$results.Add([pscustomobject]@{id=('R3-BASH-'+$case.id);result=$(if ($ok) {'PASS'} else {'FAIL'});desc='실제 R3 조각 · bash -i · 로컬 모의';detail=$(if ($ok) {''} else {'정상/거부 계약 불일치'})})
        } finally { $proc.Dispose() }
      }
    } finally { if (Test-Path -LiteralPath $scriptPath) { Remove-Item -LiteralPath $scriptPath -Force } }
  }
} else { Write-Host 'R3-BASH SKIP: Git Bash가 없어 대화형 모의를 실행하지 못했다(정적 전문·순서 검사는 수행됨)' }
# ---------------------------------------------------------------- 결과 표
Write-Host "`n=== 결과 ==="
$results | Format-Table -AutoSize -Property id, result, desc, detail | Out-String -Width 240 | Write-Host
$pass = @($results | Where-Object { [string]::Equals($_.result, 'PASS', [StringComparison]::Ordinal) }).Count
Write-Host ("PASS {0} / {1}   (lint 실패 파일 {2} 개)" -f $pass, $results.Count, $lintBad)
if ($pass -ne $results.Count -or $lintBad -gt 0) { exit 1 }
