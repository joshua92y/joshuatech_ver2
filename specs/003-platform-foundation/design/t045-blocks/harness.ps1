param([string]$Show = '')   # 예: -Show 'DR1-1' · -Show 'OP1-*' — 해당 시나리오의 화면 출력을 그대로 보여준다
# ===== T045 운영자 블록 v2 — 모의 실행 하네스 =====
# 실제 Vault·클러스터에 접근하지 않는다. PowerShell 함수가 native 명령보다 우선한다는 성질을 이용해
# vault·kubectl·curl.exe 를 함수로 가리고, Read-Host·Set-Clipboard·Start-Sleep·Get-Date·Get-ItemProperty·Test-Path 를 모의한다.
# 사용: pwsh -NoProfile -File harness.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$blocks = [ordered]@{
  op1  = Join-Path $here 'op1-seed.ps1'
  fix  = Join-Path $here 'kv-correct.ps1'
  dr1  = Join-Path $here 'dr1-drill.ps1'
  kvcl = Join-Path $here 'dr1-kv-cleanup.ps1'
}
# 원본(수정 전) 블록 — 대조군으로만 실행한다. 지적이 실재함을 하네스가 스스로 증명한다.
$orig = Split-Path -Parent $here
$blocks['orig-fix'] = Join-Path $orig 't045-op1dr1-block2.ps1'
# 원본 block1 은 L46 파서 오류로 실행 자체가 불가능하므로, 그 줄만 고친 사본을 대조군으로 쓴다.
$blocks['orig-op1'] = Join-Path $orig 'lens-ps-block1-fixed-L46.ps1'
$origFiles = [ordered]@{
  'block1(OP1)'  = Join-Path $orig 't045-op1dr1-block1.ps1'
  'block2(정정)' = Join-Path $orig 't045-op1dr1-block2.ps1'
  'block3(DR1)'  = Join-Path $orig 't045-op1dr1-block3.ps1'
  'block4(정리)' = Join-Path $orig 't045-op1dr1-block4.ps1'
}

# ---------------------------------------------------------------- 가짜 값(시크릿 아님 · 화면 노출 검사 대상)
$FAKE_ROOT = 'hvs.MOCKROOT-0123456789abcdefghijklmnop'
$FAKE_DNS  = "dns<>&'`"\-token-0123456789abcdefghijklmnop"          # 특수문자 포함 · 끝 개행 없음
$FAKE_TUN  = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"a":"acct-0123456789","t":"tun<>&''x","s":"sec\"y-0123456789abcdef"}'))
$FAKE_AK   = 'ak-0123456789abcdefghijklmnopqrstuvwx'
$FAKE_SK   = 'sk-zyxwvutsrqponmlkjihgfedcba9876543210'
$FAKE_UNI  = 'dns토큰-유니코드-0123456789abcdefghijkl'              # 비ASCII(음성 시나리오용)
$SECRETS_NEVER_ON_SCREEN = @($FAKE_ROOT, $FAKE_DNS, $FAKE_TUN, $FAKE_AK, $FAKE_SK, $FAKE_UNI,
  [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($FAKE_TUN)))

# ---------------------------------------------------------------- 모의 상태
$global:Now = [datetime]::Parse('2026-09-21T09:00:00Z').ToUniversalTime()
$global:Kv = @{}
$global:Secrets = @{}
$global:Es = @{}
$global:Inputs = [System.Collections.Queue]::new()
$global:Prompts = [System.Collections.ArrayList]::new()
$global:ClipClears = 0
$global:VaultFail = @{}
$global:TamperRead = @{}
$global:VaultNoDelete = $false
$global:TokenPolicies = @('root')
$global:KubectlFail = @{}
$global:NeverSync = $false
$global:ClipHistory = 0
$global:ClipHistoryMissing = $false
$global:VaultTokenFile = $false
$global:SealJson = '{"initialized":true,"sealed":false,"type":"ocikms"}'

function Reset-Mocks {
  $global:Now = [datetime]::Parse('2026-09-21T09:00:00Z').ToUniversalTime()
  $global:Kv = @{}
  $global:Secrets = @{
    'cert-manager/cloudflare-dns-token' = @{ uid = 'uid-dns'; data = @{ 'api-token' = $FAKE_DNS }; labels = @{}; created = '2026-09-10T00:00:00Z' }
    'cloudflared/cloudflared-tunnel'    = @{ uid = 'uid-tun'; data = @{ 'TUNNEL_TOKEN' = $FAKE_TUN }; labels = @{}; created = '2026-09-10T00:00:00Z' }
  }
  $global:Es = @{}
  $global:Inputs = [System.Collections.Queue]::new()
  $global:Prompts = [System.Collections.ArrayList]::new()
  $global:ClipClears = 0
  $global:VaultFail = @{}
  $global:TamperRead = @{}
  $global:VaultNoDelete = $false
  $global:TokenPolicies = @('root')
  $global:KubectlFail = @{}
  $global:NeverSync = $false
  $global:ClipHistory = 0
  $global:ClipHistoryMissing = $false
  $global:VaultTokenFile = $false
  if (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
  if (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR) { Remove-Item Env:VAULT_ADDR }
}
function Seed-Kv { param($path, [hashtable]$data)
  $global:Kv[$path] = @{ current = 1; created = '2026-09-20T00:00:00Z'
    versions = @{ '1' = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = '2026-09-20T00:00:00Z' } } } }

# ---------------------------------------------------------------- 모의 명령
# native 인자 정규화: `get externalsecret,secret` 은 파서가 ArrayLiteralAst 로 만든다.
# native 명령에는 콤마로 이어 붙인 한 인자로 전달되지만(probe4 실측), 함수는 Object[] 를 그대로 받아
# 문자열화하면 공백으로 이어진다. 실물과 같게 보려면 콤마로 잇는다.
function Norm-Args { param($raw)
  $o = @()
  foreach ($x in $raw) {
    if ($x -is [array]) { $o += (($x | ForEach-Object { [string]$_ }) -join ',') } else { $o += [string]$x } }
  , $o }
function Get-Date { param() $global:Now }
function Start-Sleep { param([int]$Seconds, [int]$Milliseconds)
  if ($Seconds) { $global:Now = $global:Now.AddSeconds($Seconds) }
  if ($Milliseconds) { $global:Now = $global:Now.AddMilliseconds($Milliseconds) } }
function Set-Clipboard { param([Parameter(ValueFromPipeline = $true)]$Value) $global:ClipClears++; [void]$global:ClipValues.Add([string]$Value) }
function Read-Host { param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
  [void]$global:Prompts.Add([string]$Prompt)
  $v = if ($global:Inputs.Count -gt 0) { [string]$global:Inputs.Dequeue() } else { '' }
  [void]$global:ReadLog.Add([pscustomobject]@{ prompt = [string]$Prompt; secure = [bool]$AsSecureString; value = $v })
  if ($AsSecureString) {
    $ss = [securestring]::new()
    foreach ($c in $v.ToCharArray()) { $ss.AppendChar($c) }
    return $ss }
  $v }
function Get-ItemProperty { param([Parameter(Position = 0)]$Path)
  if ($global:ClipHistoryMissing) { return $null }
  [pscustomobject]@{ EnableClipboardHistory = $global:ClipHistory } }
function Test-Path { param([Parameter(Position = 0)]$Path)
  if ([string]$Path -like '*.vault-token') { return $global:VaultTokenFile }
  Microsoft.PowerShell.Management\Test-Path $Path }
function curl.exe { $global:LASTEXITCODE = 0; $global:SealJson }

function Kv-MetaJson { param($path)
  $e = $global:Kv[$path]
  $vers = @{}
  foreach ($k in $e.versions.Keys) { $vers[[string]$k] = @{ created_time = $e.versions[$k].created_time; deletion_time = $e.versions[$k].deletion_time; destroyed = $e.versions[$k].destroyed } }
  (@{ data = @{ current_version = $e.current; oldest_version = 1; created_time = $e.created; versions = $vers } } | ConvertTo-Json -Depth 8 -Compress) }

function vault {
  $stdin = @($input)
  $a = Norm-Args $args
  [void]$global:ArgvLog.Add(($a -join ' '))
  $global:LASTEXITCODE = 0
  $join = ($a -join ' ')
  if (-not [string]::Equals([string]$env:VAULT_TOKEN, $FAKE_ROOT, [StringComparison]::Ordinal) -or -not [string]::Equals([string]$env:VAULT_ADDR, 'http://127.0.0.1:18200', [StringComparison]::Ordinal)) { $global:LASTEXITCODE = 2; return }
  # vault token lookup -format=json
  if ($a[0] -eq 'token' -and $a[1] -eq 'lookup') {
    if (@($a | Where-Object { $_ -eq '-format=json' }).Count -eq 0) { return @('Key         Value', 'policies    [root]') }
    return (@{ data = @{ id = $env:VAULT_TOKEN; policies = $global:TokenPolicies } } | ConvertTo-Json -Depth 5 -Compress) }
  if ($a[0] -ne 'kv') { $global:LASTEXITCODE = 1; return }
  if ($a[1] -ne 'put') {
    $seenPos = $false; $startAt = if ($a[1] -eq 'metadata') { 3 } else { 2 }
    foreach ($x in $a[$startAt..($a.Count - 1)]) { if ($x.StartsWith('-')) { if ($seenPos) { $global:LASTEXITCODE = 1; return } } else { $seenPos = $true } } }
  $sub = $a[1]
  switch ($sub) {
    'put' {
      $cas = $null; $path = $null
      $useStdin = $false; $kvData = @(); $bad = $false
      foreach ($x in $a[2..($a.Count - 1)]) {
        if ($null -eq $path) {
          if ($x.StartsWith('-cas=')) { $cas = [int]$x.Substring(5) }
          elseif ($x.StartsWith('-')) { $bad = $true }
          else { $path = $x } }
        else {
          if ($x -eq '-') { $useStdin = $true }
          elseif ($x.Contains('=') -and -not $x.StartsWith('-')) { $kvData += $x }
          else { $bad = $true } } }
      [void]$global:PutCalls.Add([pscustomobject]@{ path = $path; cas = $cas; stdin = $useStdin })
      if ($bad -or (-not $useStdin -and $kvData.Count -eq 0)) { $global:LASTEXITCODE = 1; return }
      if (-not $useStdin) { $hh = @{}; foreach ($kvp in $kvData) { $ix = $kvp.IndexOf('='); $hh[$kvp.Substring(0, $ix)] = $kvp.Substring($ix + 1) }; $stdin = @(($hh | ConvertTo-Json -Compress)) }
      if ($global:VaultFail.ContainsKey("put:$path")) { $global:LASTEXITCODE = $global:VaultFail["put:$path"]; return }
      $body = ($stdin -join "`n")
      $obj = $null
      try { $obj = $body | ConvertFrom-Json } catch { $global:LASTEXITCODE = 1; return }
      $data = @{}
      foreach ($p in $obj.PSObject.Properties) {
        if ($p.Value -isnot [string]) { $global:LASTEXITCODE = 1; return }   # 비문자열은 실물 Vault 에서 감사 로그 평문 — 여기서는 거부
        $data[$p.Name] = [string]$p.Value }
      if ($global:DrillFaults['putMangle']) { $data = @{ blob = 'mangled' } }
      $cur = 0
      if ($global:Kv.ContainsKey($path)) { $cur = $global:Kv[$path].current }
      if ($null -ne $cas -and $cas -ne $cur) {
        Write-Host 'Error writing data: check-and-set parameter did not match the current version'
        $global:LASTEXITCODE = 2; return }
      if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:Now.ToString('o'); versions = @{} } }
      $n = $global:Kv[$path].current + 1
      $global:Kv[$path].versions[[string]$n] = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = $global:Now.ToString('o') }
      $global:Kv[$path].current = $n
      return @("======= Metadata =======", "created_time    $($global:Now.ToString('o'))", "destroyed       false", "version         $n") }
    'get' {
      $path = @($a[2..($a.Count - 1)] | Where-Object { -not $_.StartsWith('-') })[0]
      $field = $null
      foreach ($x in $a) { if ($x.StartsWith('-field=')) { $field = $x.Substring(7) } }
      if (-not $global:Kv.ContainsKey($path)) { $global:LASTEXITCODE = 2; return }
      if ($null -eq $field -and @($a | Where-Object { $_ -eq '-format=json' }).Count -eq 0) { return @('====== Data ======', 'Key      Value') }
      $e = $global:Kv[$path]
      $v = $e.versions[[string]$e.current]
      if ($null -ne $field) {
        # `-field` 는 값을 그대로 stdout 에 쓴다. PowerShell 의 native 캡처는 줄 단위라
        # 끝 개행 1개가 사라지고 중간 개행은 공백이 된다(실측). 그 손실을 그대로 흉내 낸다.
        if ($v.destroyed -or $v.deletion_time -or -not $v.data.ContainsKey($field)) { $global:LASTEXITCODE = 2; return }
        $raw = [string]$v.data[$field]
        if ($global:TamperRead.ContainsKey($path)) { $raw = $raw + '-TAMPERED' }
        $parts = [System.Collections.ArrayList]@($raw -split "`r?`n")
        while ($parts.Count -gt 1 -and [string]::IsNullOrEmpty([string]$parts[$parts.Count - 1])) { $parts.RemoveAt($parts.Count - 1) }
        return $parts.ToArray() }
      if ($v.destroyed -or $v.deletion_time) {
        # 실물 CLI 는 soft-delete/destroy 에서도 metadata 를 담은 JSON 을 돌려준다(data=null)
        return (@{ data = @{ data = $null; metadata = @{ version = $e.current; destroyed = $v.destroyed; deletion_time = $v.deletion_time } } } | ConvertTo-Json -Depth 6 -Compress) }
      $d = @{}
      foreach ($k in $v.data.Keys) {
        $val = $v.data[$k]
        if ($global:TamperRead.ContainsKey($path)) { $val = $val + '-TAMPERED' }
        $d[$k] = $val }
      return (@{ data = @{ data = $d; metadata = @{ version = $e.current; destroyed = $false; deletion_time = '' } } } | ConvertTo-Json -Depth 6 -Compress) }
    'metadata' {
      $op = $a[2]
      $path = @($a[3..($a.Count - 1)] | Where-Object { -not $_.StartsWith('-') })[0]
      if ($op -eq 'get') {
        if (-not $global:Kv.ContainsKey($path)) { $global:LASTEXITCODE = 2; return }
        if (@($a | Where-Object { $_ -eq '-format=json' }).Count -eq 0) { return @('========== Metadata ==========', 'Key      Value') }
        return (Kv-MetaJson $path) }
      if ($op -eq 'delete') {
        if ($global:VaultFail.ContainsKey("metadelete:$path")) { $global:LASTEXITCODE = $global:VaultFail["metadelete:$path"]; return }
        if (-not $global:VaultNoDelete) { $global:Kv.Remove($path) }
        return 'Success! Data deleted (if it existed) at: ' + $path }
      $global:LASTEXITCODE = 1; return }
    'rollback' {
      $ver = $null; $path = $null
      foreach ($x in $a[2..($a.Count - 1)]) { if ($x.StartsWith('-version=')) { $ver = [string][int]$x.Substring(9) } elseif (-not $x.StartsWith('-')) { $path = $x } }
      if ($global:VaultFail.ContainsKey("rollback:$path")) { $global:LASTEXITCODE = $global:VaultFail["rollback:$path"]; return }
      if (-not $global:Kv.ContainsKey($path) -or -not $global:Kv[$path].versions.ContainsKey($ver)) { $global:LASTEXITCODE = 2; return }
      $n = $global:Kv[$path].current + 1
      $global:Kv[$path].versions[[string]$n] = @{ data = $global:Kv[$path].versions[$ver].data; deletion_time = ''; destroyed = $false; created_time = $global:Now.ToString('o') }
      $global:Kv[$path].current = $n
      return "Key   Value`nversion  $n" }
    'list' {
      $path = @($a[2..($a.Count - 1)] | Where-Object { -not $_.StartsWith('-') })[0]
      $kids = @($global:Kv.Keys | Where-Object { $_.StartsWith($path + '/') } | ForEach-Object { ($_.Substring($path.Length + 1) -split '/')[0] } | Sort-Object -Unique)
      if ($kids.Count -eq 0) { $global:LASTEXITCODE = 2; return }
      return @('Keys', '----') + $kids }
    default { $global:LASTEXITCODE = 1; return } } }

function Tick-Es {
  foreach ($k in @($global:Es.Keys)) {
    $es = $global:Es[$k]
    if (-not $es.synced) { continue }
    while ($global:Now -ge $es.nextRefresh) {
      $es.nextRefresh = $es.nextRefresh.AddSeconds(300)
      $sk = "$($es.ns)/$($es.target)"
      $kvv = $null
      if ($global:Kv.ContainsKey('kv/' + $es.remotePath)) { $kvv = $global:Kv['kv/' + $es.remotePath].versions[[string]$global:Kv['kv/' + $es.remotePath].current].data[$es.remoteProp] }
      if ($null -eq $kvv) { $es.reason = 'SecretSyncedError'; continue }
      if (-not $global:Secrets.ContainsKey($sk)) {
        $global:Secrets[$sk] = @{ uid = 'uid-recreated-' + $global:Now.ToString('HHmmss'); data = @{ value = $kvv }; labels = @{ 'reconcile.external-secrets.io/managed' = 'true' }; created = $global:Now.ToString('o') } }
      $es.refreshTime = $global:Now.ToString('o') } } }

function Sync-Es { param($key)
  $es = $global:Es[$key]
  $full = 'kv/' + $es.remotePath
  if (-not $global:Kv.ContainsKey($full)) { $es.reason = 'SecretSyncedError'; $es.synced = $false; return }
  $kvv = $global:Kv[$full].versions[[string]$global:Kv[$full].current].data[$es.remoteProp]
  if ($null -eq $kvv) { $es.reason = 'SecretSyncedError'; $es.synced = $false; return }
  $sk = "$($es.ns)/$($es.target)"
  if ($global:Secrets.ContainsKey($sk)) {
    # Orphan 인수: UID 유지 · ES 가 열거한 키만 남긴다(다른 키는 사라진다) · managed 라벨을 붙인다
    $global:Secrets[$sk].data = @{ value = $kvv }
    if ($global:DrillFaults['uidChange']) { $global:Secrets[$sk].uid = 'uid-RECREATED-ON-ADOPT' }
    if (-not $global:DrillFaults['noLabel']) { $global:Secrets[$sk].labels['reconcile.external-secrets.io/managed'] = 'true' } }
  else {
    $global:Secrets[$sk] = @{ uid = 'uid-created-' + $global:Now.ToString('HHmmss'); data = @{ value = $kvv }; labels = @{ 'reconcile.external-secrets.io/managed' = 'true' }; created = $global:Now.ToString('o') } }
  $es.reason = 'SecretSynced'; $es.synced = $true
  $es.refreshTime = $global:Now.ToString('o')
  $es.nextRefresh = $global:Now.AddSeconds(300) }

function B64 { param($s) [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([string]$s)) }

function kubectl {
  $stdin = @($input)
  $a = Norm-Args $args
  [void]$global:ArgvLog.Add(($a -join ' '))
  $global:LASTEXITCODE = 0
  Tick-Es
  $ns = ''; $o = ''; $ignoreNotFound = $false; $pos = @()
  for ($i = 0; $i -lt $a.Count; $i++) {
    $x = $a[$i]
    if ($x -eq '-n') { $ns = $a[$i + 1]; $i++; continue }
    if ($x -eq '-o') { $o = $a[$i + 1]; $i++; continue }
    if ($x -eq '-f') { $i++; continue }
    if ($x -eq '--ignore-not-found') { $ignoreNotFound = $true; continue }
    if ($x.StartsWith('--timeout=') -or $x.StartsWith('--request-timeout=')) { continue }
    $pos += $x }
  $verb = $pos[0]
  if ($verb -eq 'auth') { return 'yes' }
  if ($verb -eq 'get' -and $pos[1] -eq 'nodes') {
    if ($global:KubectlFail.ContainsKey('get:nodes')) { $global:LASTEXITCODE = $global:KubectlFail['get:nodes']; return }
    return @('node/joshtech-api', 'node/joshtech-cache') }
  if ($verb -eq 'apply') {
    $obj = ($stdin -join "`n") | ConvertFrom-Json
    if ($global:KubectlFail.ContainsKey("apply:$($obj.kind)")) { $global:LASTEXITCODE = $global:KubectlFail["apply:$($obj.kind)"]; return }
    if ($obj.kind -eq 'Secret') {
      $k = "$($obj.metadata.namespace)/$($obj.metadata.name)"
      $d = @{}
      foreach ($p in $obj.stringData.PSObject.Properties) { $d[$p.Name] = [string]$p.Value }
      if ($global:Secrets.ContainsKey($k)) { $global:Secrets[$k].data = $d }
      else { $global:Secrets[$k] = @{ uid = 'uid-manual-1'; data = $d; labels = @{}; created = $global:Now.ToString('o') } }
      return "secret/$($obj.metadata.name) created" }
    if ($obj.kind -eq 'ExternalSecret') {
      $k = "$($obj.metadata.namespace)/$($obj.metadata.name)"
      $global:Es[$k] = @{ ns = $obj.metadata.namespace; name = $obj.metadata.name; target = $obj.spec.target.name
        remotePath = $obj.spec.data[0].remoteRef.key; remoteProp = $obj.spec.data[0].remoteRef.property
        reason = 'SecretSyncedError'; synced = $false; refreshTime = ''; nextRefresh = $global:Now.AddSeconds(300) }
      if (-not $global:NeverSync) { Sync-Es $k }
      return "externalsecret.external-secrets.io/$($obj.metadata.name) created" }
    $global:LASTEXITCODE = 1; return }
  if ($verb -eq 'delete') {
    $kind = $pos[1]; $name = $pos[2]
    $global:KubectlCallCount["delete:$kind"] = 1 + [int]$global:KubectlCallCount["delete:$kind"]
    if ($global:KubectlFailNth.ContainsKey("delete:$kind") -and $global:KubectlCallCount["delete:$kind"] -eq $global:KubectlFailNth["delete:$kind"]) { $global:LASTEXITCODE = 1; return }
    if ($global:KubectlFail.ContainsKey("delete:$kind")) { $global:LASTEXITCODE = $global:KubectlFail["delete:$kind"]; return }
    $k = "$ns/$name"
    if ($kind -eq 'externalsecret') {
      if ($global:Es.ContainsKey($k)) { if (-not $global:DrillFaults['deleteEsNoop']) { $global:Es.Remove($k) }; if ($global:DrillFaults['recreateOnEsDelete'] -and $global:Secrets.ContainsKey($k)) { $global:Secrets[$k].uid = 'uid-GC-RECREATED' }; return "externalsecret.external-secrets.io `"$name`" deleted" }
      if ($ignoreNotFound) { return }
      $global:LASTEXITCODE = 1; return }
    if ($kind -eq 'secret') {
      if ($global:Secrets.ContainsKey($k)) { $global:Secrets.Remove($k); return "secret `"$name`" deleted" }
      if ($ignoreNotFound) { return }
      $global:LASTEXITCODE = 1; return }
    $global:LASTEXITCODE = 1; return }
  if ($verb -ne 'get') { $global:LASTEXITCODE = 1; return }
  $kinds = @($pos[1] -split ',')
  $name = $pos[2]
  $k = "$ns/$name"
  if ($global:KubectlFail.ContainsKey("get:$($pos[1])")) { $global:LASTEXITCODE = $global:KubectlFail["get:$($pos[1])"]; return }
  $existsSecret = ($kinds -contains 'secret') -and $global:Secrets.ContainsKey($k)
  $existsEs = ($kinds -contains 'externalsecret') -and $global:Es.ContainsKey($k)
  if ($o -eq 'name') {
    $out = @()
    if ($existsEs) { $out += "externalsecret.external-secrets.io/$name" }
    if ($existsSecret) { $out += "secret/$name" }
    if ($out.Count -eq 0 -and -not $ignoreNotFound) { $global:LASTEXITCODE = 1; return }
    return $out }
  if ($o.StartsWith('go-template=')) {
    if (-not $existsSecret) { $global:LASTEXITCODE = 1; return }
    return ((@($global:Secrets[$k].data.Keys) | Sort-Object) -join ' ') + ' ' }
  if ($o.StartsWith('jsonpath=')) {
    $jp = $o.Substring(9)
    if ($kinds -contains 'externalsecret') {
      if (-not $existsEs) { $global:LASTEXITCODE = 1; return }
      $es = $global:Es[$k]
      if ($jp -like '*conditions*') { return $es.reason }
      if ($jp -like '*refreshTime*') { return $es.refreshTime }
      $global:LASTEXITCODE = 1; return }
    if (-not $existsSecret) { $global:LASTEXITCODE = 1; return }
    $s = $global:Secrets[$k]
    if ($jp -like '*metadata.uid*') { return $s.uid }
    if ($jp -like '*creationTimestamp*') { return $s.created }
    if ($jp -like '*ownerReferences*') { if ($global:DrillFaults['ownerRef']) { return '[{"kind":"ExternalSecret","name":"t045-probe"}]' }; return '' }
    if ($jp -like '*labels*managed*') { return [string]$s.labels['reconcile.external-secrets.io/managed'] }
    if ($jp -match "\.data\['([^']+)'\]") { return (B64 $s.data[$Matches[1]]) }
    if ($jp -match '\.data\.([A-Za-z0-9_.-]+)\}') { return (B64 $s.data[$Matches[1]]) }
    $global:LASTEXITCODE = 1; return }
  $global:LASTEXITCODE = 1; return }

# ---------------------------------------------------------------- 시나리오 실행기
function Reset-Strict {
  $global:ArgvLog = [System.Collections.ArrayList]::new()
  $global:PutCalls = [System.Collections.ArrayList]::new()
  $global:ClipValues = [System.Collections.ArrayList]::new()
  $global:ReadLog = [System.Collections.ArrayList]::new()
  $global:DrillFaults = @{}
  $global:KubectlFailNth = @{}
  $global:KubectlCallCount = @{} }
Reset-Strict
# static lint: output that bypasses PowerShell streams (or lands in files) cannot be seen by an in-process capture, so forbid it outright
function Lint-Block { param($path)
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tk, [ref]$er)
  $bad = @()
  $forbidden = @('Out-Host', 'Out-File', 'Set-Content', 'Add-Content', 'Tee-Object', 'Start-Transcript', 'Export-Clixml', 'Export-Csv', 'Out-Printer', 'Invoke-Expression', 'Write-EventLog')
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) { $nm = $c.GetCommandName(); if ($nm -and ($forbidden -contains $nm)) { $bad += "L$($c.Extent.StartLineNumber) $nm" } }
  foreach ($m in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] }, $true)) {
    if ($m.Expression.TypeName.FullName -match '(^|\.)Console$') { $bad += "L$($m.Extent.StartLineNumber) [Console]::$($m.Member)" } }
  foreach ($r in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FileRedirectionAst] }, $true)) { if ($r.Location.Extent.Text -ne '$null') { $bad += "L$($r.Extent.StartLineNumber) redirect to $($r.Location.Extent.Text)" } }
  , $bad }
$results = [System.Collections.ArrayList]::new()
function Run-Case { param($id, $desc, $block, [scriptblock]$setup, $expect, [string[]]$want = @(), [string[]]$notWant = @(), [scriptblock]$post = $null)
  Reset-Mocks
  Reset-Strict
  & $setup
  $gvBefore = @{}; foreach ($gv in (Get-Variable -Scope Global)) { if ($gv.Value -is [string]) { $gvBefore[$gv.Name] = $gv.Value } }
  $out = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''; $stack = ''
  try { & $blocks[$block] *>&1 | ForEach-Object { [void]$out.Add([string]$_) } }
  catch { $threw = $true; $errMsg = [string]$_.Exception.Message; $stack = [string]$_.ScriptStackTrace; [void]$out.Add("THROW: $errMsg") }
  $text = ($out -join "`n")
  $fails = [System.Collections.ArrayList]::new()
  if ($expect -eq 'ok' -and $threw) { [void]$fails.Add("예상: 완주 · 실제 throw($errMsg)") }
  if ($expect -ne 'ok') {
    if (-not $threw) { [void]$fails.Add('예상: throw · 실제 완주') }
    elseif (-not $errMsg.Contains($expect)) { [void]$fails.Add("throw 문구 불일치: '$errMsg'") } }
  foreach ($w in $want) { if (-not $text.Contains($w)) { [void]$fails.Add("누락: '$w'") } }
  foreach ($w in $notWant) { if ($text.Contains($w)) { [void]$fails.Add("있으면 안 됨: '$w'") } }
  # 공통 사후 조건 1: 시크릿 테스트 문자열이 화면(모든 스트림)에 한 번도 나오지 않는다
  foreach ($s in $SECRETS_NEVER_ON_SCREEN) { if ($text.Contains($s)) { [void]$fails.Add('시크릿 노출!') ; break } }
  # 공통 사후 조건 2: VAULT_TOKEN/VAULT_ADDR 가 남지 않는다
  if (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN) { [void]$fails.Add('VAULT_TOKEN 잔존') }
  if (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR) { [void]$fails.Add('VAULT_ADDR 잔존') }
  if ($id -notlike 'REG-*') {
    $needles = @(); foreach ($s in $SECRETS_NEVER_ON_SCREEN) { $needles += $s; $needles += [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)) }
    $gvNew = @(); foreach ($gv in (Get-Variable -Scope Global)) { if ($gv.Value -is [string] -and (-not $gvBefore.ContainsKey($gv.Name) -or -not [string]::Equals($gvBefore[$gv.Name], $gv.Value, [StringComparison]::Ordinal))) { $gvNew += $gv.Value } }
    $surfaces = [ordered]@{ screen = $text; prompt = ($global:Prompts -join "`n"); argv = ($global:ArgvLog -join "`n"); clipboard = ($global:ClipValues -join "`n"); globalvar = ($gvNew -join "`n") }
    foreach ($sn in $surfaces.Keys) { foreach ($n in $needles) { if (([string]$surfaces[$sn]).Contains($n)) { [void]$fails.Add("STRICT leak on surface: $sn"); break } } }
    foreach ($c in $global:ClipValues) { if (-not [string]::Equals([string]$c, ' ', [StringComparison]::Ordinal)) { [void]$fails.Add('STRICT clipboard set to a non-blank value'); break } }
    foreach ($r in $global:ReadLog) { if (($SECRETS_NEVER_ON_SCREEN -ccontains $r.value) -and -not $r.secure) { [void]$fails.Add("STRICT secret read without -AsSecureString: $($r.prompt)"); break } }
    foreach ($pc in $global:PutCalls) {
      if ($null -eq $pc.cas) { [void]$fails.Add("STRICT kv put without -cas: $($pc.path)") }
      if (-not $pc.stdin) { [void]$fails.Add("STRICT kv put without stdin marker: $($pc.path)") } }
    if ($expect -eq 'ok' -and $global:Inputs.Count -ne 0) { [void]$fails.Add("STRICT unconsumed inputs: $($global:Inputs.Count) (a stop point is missing)") } }
  if ($post) { foreach ($f in (& $post)) { [void]$fails.Add($f) } }
  [void]$results.Add([pscustomobject]@{ id = $id; desc = $desc; result = $(if ($fails.Count -eq 0) { 'PASS' } else { 'FAIL' }); detail = ($fails -join ' | ') })
  if ($fails.Count -gt 0 -or ($Show -and $id -like $Show)) {
    Write-Host "---- $id 출력 ----`n$text`n$(if ($stack -and $fails.Count -gt 0) { "STACK: $stack" })`n" -ForegroundColor DarkGray } }

function KvVal { param($path, $field)
  if (-not $global:Kv.ContainsKey($path)) { return $null }
  $e = $global:Kv[$path]; $e.versions[[string]$e.current].data[$field] }
function KvCur { param($path) if ($global:Kv.ContainsKey($path)) { $global:Kv[$path].current } else { -1 } }

# ---------------------------------------------------------------- 사전: 파서 오류 0 확인
Write-Host '=== 파서 검사 ==='
$parseBad = 0
foreach ($n in @($blocks.Keys) + @('harness.ps1')) {
  $p = if ($n -eq 'harness.ps1') { Join-Path $here $n } else { $blocks[$n] }
  $t = $null; $e = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$t, [ref]$e)
  $stmts = if ($n -eq 'harness.ps1') { -1 } else { $ast.EndBlock.Statements.Count }
  $lines = [IO.File]::ReadAllLines($p)
  $blank = 0; foreach ($l in $lines) { if ($l.Trim().Length -eq 0) { $blank++ } }
  if ($e.Count -gt 0) { $parseBad++ }
  Write-Host ("  {0,-20} 파서오류={1} 최상위문장={2} 빈줄={3}" -f (Split-Path -Leaf $p), $e.Count, $stmts, $blank)
  foreach ($er in $e) { Write-Host "     L$($er.Extent.StartLineNumber): $($er.Message)" -ForegroundColor Red } }

Write-Host "`n=== 원본 블록 파서·꼬리 검사(대조군 · PS-01 / PS-11 / F14) ==="
foreach ($n in $origFiles.Keys) {
  $p = $origFiles[$n]
  $t = $null; $e = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$t, [ref]$e)
  $b = [IO.File]::ReadAllBytes($p)
  $tail = ($b[-3..-1] | ForEach-Object { $_.ToString('X2') }) -join ' '
  $lines = [IO.File]::ReadAllLines($p)
  $blank = 0; foreach ($l in $lines) { if ($l.Trim().Length -eq 0) { $blank++ } }
  Write-Host ("  {0,-13} 파서오류={1} 끝3바이트={2} 빈줄={3}" -f $n, $e.Count, $tail, $blank)
  foreach ($er in $e) { Write-Host ("     L{0} C{1}: {2}" -f $er.Extent.StartLineNumber, $er.Extent.StartColumnNumber, $er.Message) -ForegroundColor Yellow } }

Write-Host "`n=== 시나리오 ==="
Write-Host '=== STRICT lint (host-direct / file output is forbidden in the four v2 blocks) ==='
foreach ($n in 'op1', 'fix', 'dr1', 'kvcl') { $lb = Lint-Block $blocks[$n]; Write-Host ("  {0,-5} {1}" -f $n, $(if ($lb.Count) { 'LINT-FAIL: ' + ($lb -join ' ; ') } else { 'clean' })); if ($lb.Count) { $parseBad++ } }
$IN = { param([string[]]$v) foreach ($x in $v) { $global:Inputs.Enqueue($x) } }

# ---- OP1
Run-Case 'OP1-1' '정상 첫 시드(C=skip)' 'op1' {
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'ok' `
  @('OK   VD-6', 'OK   kv/platform/cloudflare/dns-token', 'OK   kv/platform/cloudflare/tunnel', 'OK   kv/platform/test/t045-probe',
    '완료(신규)', '보류(키 쌍 미확인', '이연(T092', 'META kv/platform/cloudflare/dns-token  current_version=1', 'tunnel=True · dns-token=False') `
  @('중단', '미실행') {
  $f = @()
  if ((KvVal 'kv/platform/cloudflare/dns-token' 'token') -cne $FAKE_DNS) { $f += 'kv dns 값 불일치' }
  if ((KvVal 'kv/platform/cloudflare/tunnel' 'token') -cne $FAKE_TUN) { $f += 'kv tunnel 값 불일치' }
  if ($global:Kv.ContainsKey('kv/platform/_probe')) { $f += '프로브 경로 잔존' }
  if ($global:ClipClears -lt 1) { $f += '클립보드 비우기 미실행' }
  $f }

Run-Case 'OP1-2' '재실행 · 값 동일 → SKIP' 'op1' {
  Seed-Kv 'kv/platform/cloudflare/dns-token' @{ token = $FAKE_DNS }
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = $FAKE_TUN }
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'ok' `
  @('SKIP kv/platform/cloudflare/dns-token', 'SKIP kv/platform/cloudflare/tunnel', 'SKIP kv/platform/test/t045-probe', '이미 시드됨(값 동일)') `
  @('중단', '완료(신규)') {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += 'kv 버전이 늘었다(쓰지 말아야 한다)' }; $f }

Run-Case 'OP1-3' '이미 다른 값 존재 → 중단' 'op1' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'other-value-0123456789abcdefghijklmn' }
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } '이미 다른 값이 있다' `
  @('중단(존재하지만 값이 다름)', '미실행(이 실행에서 여기까지 오지 못했다)', 'kv/platform/test/t045-probe') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '덮어썼다' }; $f }

Run-Case 'OP1-4' '라이브 Secret 빈 값 → throw' 'op1' {
  $global:Secrets['cert-manager/cloudflare-dns-token'].data['api-token'] = ''
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } '라이브 Secret 취득 실패' `
  @('중단(라이브 Secret 취득 단계에서 실패)') @()

Run-Case 'OP1-5' 'vault put 비0 → throw' 'op1' {
  $global:VaultFail['put:kv/platform/cloudflare/dns-token'] = 1
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'vault kv put 실패' `
  @('중단(put 실패') @()

Run-Case 'OP1-6' '되읽기 해시 불일치 → throw' 'op1' {
  $global:TamperRead['kv/platform/cloudflare/tunnel'] = $true
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'kv 값 불일치' `
  @('중단(되읽기 불일치') @()

Run-Case 'OP1-7' '라이브 값이 비ASCII → throw(F9)' 'op1' {
  $global:Secrets['cert-manager/cloudflare-dns-token'].data['api-token'] = $FAKE_UNI
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'ASCII 인쇄 문자 밖' @() @()

Run-Case 'OP1-8' '기존 kv 값 끝 개행 → 동일로 오판하지 않는다(PS-02/F8)' 'op1' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = ($FAKE_TUN + "`n") }
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } '이미 다른 값이 있다' `
  @('중단(존재하지만 값이 다름)') @('SKIP kv/platform/cloudflare/tunnel')

Run-Case 'OP1-9' '프로브 경로 잔존 → 사전 정리 후 정상(F6/VKE-4)' 'op1' {
  Seed-Kv 'kv/platform/_probe' @{ old = 'junk' }
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'ok' `
  @('OK   VD-6', 'OK   kv/platform/cloudflare/tunnel') @('중단') {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/_probe')) { $f += '프로브 경로 잔존' }; $f }

Run-Case 'OP1-10' 'C) 빈 입력(버퍼 잔여) → 중단(PS-05)' 'op1' {
  & $IN @($FAKE_ROOT, 'go', 'go', '', 'y', 'go') } 'C) 응답이 y/skip 이 아니다' `
  @('완료(신규)', '미실행') @()

Run-Case 'OP1-11' 'root 토큰 빈 Enter → 명확한 중단(PS-10)' 'op1' {
  & $IN @('', 'go', 'go', 'skip', 'y', 'go') } '빈 입력 — 중단' `
  @('미실행(이 실행에서 여기까지 오지 못했다)') @()

Run-Case 'OP1-12' 'D) skip → 드릴 경로를 다시 만들지 않는다(VKE-8)' 'op1' {
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'skip', 'go') } 'ok' `
  @('건너뜀(DR1 완료') @('OK   kv/platform/test/t045-probe') {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/test/t045-probe')) { $f += '드릴 경로가 다시 생겼다' }; $f }

Run-Case 'OP1-13' 'C=y · oci 키 2개 시드' 'op1' {
  & $IN @($FAKE_ROOT, 'go', 'go', 'y', $FAKE_AK, $FAKE_SK, 'y', 'go') } 'ok' `
  @('OK   kv/platform/oci/s3 (access_key, secret_key)') @('중단') {
  $f = @()
  if ((KvVal 'kv/platform/oci/s3' 'access_key') -cne $FAKE_AK) { $f += 'ak 불일치' }
  if ((KvVal 'kv/platform/oci/s3' 'secret_key') -cne $FAKE_SK) { $f += 'sk 불일치' }
  $f }

Run-Case 'OP1-14' 'oci 입력에 root 토큰 붙여넣기 → 중단(F5)' 'op1' {
  & $IN @($FAKE_ROOT, 'go', 'go', 'y', $FAKE_ROOT, $FAKE_SK, 'y', 'go') } 'Vault 토큰이다' `
  @() @('OK   kv/platform/oci/s3') {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/oci/s3')) { $f += 'oci 경로가 쓰였다' }; $f }

Run-Case 'OP1-15' '클립보드 기록 켜짐 → 토큰 입력 전 중단(F11)' 'op1' {
  $global:ClipHistory = 1
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } '클립보드 기록이 켜져 있음' @() @()

Run-Case 'OP1-16' 'kubeconfig 가 클러스터를 못 봄 → 토큰 입력 전 중단(VKE-12)' 'op1' {
  $global:KubectlFail['get:nodes'] = 1
  & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') } 'joshuatech 클러스터를 보고 있지 않다' @() @() {
  $f = @(); if ($global:Prompts.Count -gt 0) { $f += "토큰을 먼저 물었다($($global:Prompts.Count))" }; $f }

# ---- 정정 블록
Run-Case 'FIX-1' '정상 CAS 덮어쓰기(출처 a)' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  & $IN @($FAKE_ROOT, 'a', 'yes') } 'ok' `
  @('OK 정정 완료: kv/platform/cloudflare/tunnel .token (버전 1 → 2)', '새 버전을 썼다') @('SKIP') {
  $f = @(); if ((KvVal 'kv/platform/cloudflare/tunnel' 'token') -cne $FAKE_TUN) { $f += '정정값 불일치' }; $f }

Run-Case 'FIX-2' "yes 미입력 → 중단" 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  & $IN @($FAKE_ROOT, 'a', 'no') } '취소됨' `
  @('아무것도 쓰지 않았다') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '버전이 늘었다' }; $f }

Run-Case 'FIX-3' 'CAS 충돌 → throw' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  $global:VaultFail['put:kv/platform/cloudflare/tunnel'] = 2
  & $IN @($FAKE_ROOT, 'a', 'yes') } '정정 put 실패' `
  @('아무것도 쓰지 않았다') @()

Run-Case 'FIX-4' '현재 값과 같으면 SKIP(규칙10 · F2/PS-07)' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = $FAKE_TUN }
  & $IN @($FAKE_ROOT, 'a') } 'ok' `
  @('SKIP kv/platform/cloudflare/tunnel .token') @('OK 정정 완료') {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '버전이 늘었다' }; $f }

Run-Case 'FIX-5' '교차 배선(DNS 값을 터널 경로에) → 중단(F1/VKE-3)' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  Seed-Kv 'kv/platform/cloudflare/dns-token' @{ token = $FAKE_DNS }
  & $IN @($FAKE_ROOT, 'c', $FAKE_DNS, 'yes') } '교차 배선' `
  @('아무것도 쓰지 않았다') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '썼다' }; $f }

Run-Case 'FIX-6' '형식 불일치 → override 게이트에서 중단' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  & $IN @($FAKE_ROOT, 'c', $FAKE_DNS, '', 'yes') } '정지점에서 중단' `
  @('값 형식이 kv/platform/cloudflare/tunnel 의 기대와 다르다') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '썼다' }; $f }

Run-Case 'FIX-7' '다필드 경로 → 전체 교체 거부(F3/VKE-2)' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn'; extra = 'keep-me' }
  & $IN @($FAKE_ROOT, 'a', 'yes') } '다른 필드가 있다' `
  @('경로 전체를 교체한다') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 1) { $f += '썼다' }; $f }

Run-Case 'FIX-8' '되읽기 불일치 → rollback 게이트(F4)' 'fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  $global:TamperRead['kv/platform/cloudflare/tunnel'] = $true
  & $IN @($FAKE_ROOT, 'a', 'yes', 'rollback') } '되돌렸다' `
  @('되읽기 불일치', '새 버전을 썼다') @() {
  $f = @()
  if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 3) { $f += "rollback 버전 이상($(KvCur 'kv/platform/cloudflare/tunnel'))" }
  if ((KvVal 'kv/platform/cloudflare/tunnel' 'token') -cne 'stale-value-0123456789abcdefghijklmn') { $f += '되돌린 값이 다르다' }
  $f }

Run-Case 'FIX-9' '경로가 없음(시드 전) → 정정이 아니라 시드 경로' 'fix' {
  & $IN @($FAKE_ROOT, 'a', 'yes') } '정정이 아니라 시드' @() @()

# ---- DR1 드릴
Run-Case 'DR1-1' '정상 경로' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  & $IN @('go', 'go', 'go', 'go', 'go') } 'ok' `
  @('인수 전 data 키: extra value', 'OK 드릴 인수', 'managed 라벨 확인', '인수 후 data 키: value',
    'OK ES 삭제 후에도 Secret 잔존', 'VD-20: 삭제 후 약', 'K8s 객체 정리 완료(부재까지 확인)') `
  @('잔존물이 남아 있다', '잔존물 조회 실패') {
  $f = @()
  if ($global:Secrets.ContainsKey('external-secrets/t045-probe')) { $f += 'Secret 잔존' }
  if ($global:Es.ContainsKey('external-secrets/t045-probe')) { $f += 'ES 잔존' }
  $f }

Run-Case 'DR1-2' '이전 잔존물 → 시작 거부' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:Secrets['external-secrets/t045-probe'] = @{ uid = 'old'; data = @{ value = 'x' }; labels = @{}; created = '2026-09-20T00:00:00Z' }
  & $IN @('go', 'go', 'go', 'go', 'go') } '이전 드릴 잔존물이 있다' `
  @('드릴 잔존물이 남아 있다', 'kubectl -n external-secrets delete externalsecret t045-probe') @()

Run-Case 'DR1-3' 'ES 삭제를 webhook 이 거부 → 가짜 PASS 없음' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:KubectlFail['delete:externalsecret'] = 1
  & $IN @('go', 'go', 'go', 'go', 'go') } 'ES 삭제 실패 또는 90초 초과' `
  @('드릴 잔존물이 남아 있다') @('OK ES 삭제 후에도 Secret 잔존', 'K8s 객체 정리 완료')

Run-Case 'DR1-4' 'SecretSynced 타임아웃 → throw + 잔존 안내' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:NeverSync = $true
  & $IN @('go', 'go', 'go', 'go', 'go') } '120초 안에 SecretSynced 가 되지 않았다' `
  @('드릴 잔존물이 남아 있다', 'kubectl -n external-secrets delete secret t045-probe') @('OK 드릴 인수')

Run-Case 'DR1-5' '6) 정리 삭제 실패 → 거짓 "정리 완료" 없음(VKE-1/F12)' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:Inputs.Enqueue('go'); $global:Inputs.Enqueue('go'); $global:Inputs.Enqueue('go'); $global:Inputs.Enqueue('go'); $global:Inputs.Enqueue('go')
  $global:KubectlFail['delete:secret'] = 1 } 'VD-20 측정 불가' `
  @('드릴 잔존물이 남아 있다') @('K8s 객체 정리 완료')

Run-Case 'DR1-6' '잔존물 조회 자체가 실패 → "없음"으로 읽지 않는다(PS-04)' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:KubectlFail['get:externalsecret,secret'] = 7
  & $IN @('go', 'go', 'go', 'go', 'go') } '잔존물 조회 실패 — 판정 불가' `
  @('잔존물 조회 실패(exit=7)', 'kubectl -n external-secrets delete externalsecret t045-probe') @()

Run-Case 'DR1-7' '1) 앞 정지점에서 중단 → 아무것도 만들지 않는다(F14)' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  & $IN @('', 'go', 'go', 'go', 'go') } '정지점에서 중단' @() @() {
  $f = @(); if ($global:Secrets.ContainsKey('external-secrets/t045-probe')) { $f += 'Secret 이 만들어졌다' }; $f }

# ---- kv 정리 블록
Run-Case 'KVCL-1' '정상 삭제' 'kvcl' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  & $IN @($FAKE_ROOT, 'go') } 'ok' `
  @('OK kv 드릴 경로 삭제') @() {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/test/t045-probe')) { $f += '경로 잔존' }; $f }

Run-Case 'KVCL-2' '삭제 뒤에도 경로 존재 → throw' 'kvcl' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:VaultNoDelete = $true
  & $IN @($FAKE_ROOT, 'go') } '경로가 아직 있다' @() @()

Run-Case 'KVCL-3' 'DR1 잔존 ES → 토큰 입력 전 중단(F13/VKE-7)' 'kvcl' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  $global:Es['external-secrets/t045-probe'] = @{ ns = 'external-secrets'; name = 't045-probe'; target = 't045-probe'
    remotePath = 'platform/test/t045-probe'; remoteProp = 'value'; reason = 'SecretSynced'; synced = $true; refreshTime = ''; nextRefresh = $global:Now.AddSeconds(300) }
  & $IN @($FAKE_ROOT, 'go') } 'DR1 K8s 객체가 아직 있다' @() @() {
  $f = @()
  if ($global:Prompts.Count -gt 0) { $f += '토큰을 먼저 물었다' }
  if (-not $global:Kv.ContainsKey('kv/platform/test/t045-probe')) { $f += 'kv 경로를 지웠다' }
  $f }

Run-Case 'KVCL-4' '경로가 이미 없음 → SKIP(재실행 안전)' 'kvcl' {
  & $IN @($FAKE_ROOT) } 'ok' `
  @('SKIP kv/platform/test/t045-probe') @()

# ---- 대조군: 원본 정정 블록(수정 전)이 같은 입력에서 실제로 위험한 결과를 내는지 확인한다.
#      여기서 PASS = "원본의 결함이 재현됐다" 는 뜻이다(하네스가 결함을 볼 수 있음을 증명).
Run-Case 'REG-1' '[대조군] 원본 정정 블록: 손 입력 좌표로 DNS 값이 터널 경로에 기록된다(F1/PS-06/VKE-3)' 'orig-fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn' }
  & $IN @($FAKE_ROOT, 'a', 'cert-manager', 'cloudflare-dns-token', 'api-token', 'yes') } 'ok' `
  @('OK 정정 완료') @() {
  $f = @()
  if ((KvVal 'kv/platform/cloudflare/tunnel' 'token') -cne $FAKE_DNS) { $f += '결함 재현 실패(교차 배선이 일어나지 않았다)' }
  $f }

Run-Case 'REG-2' '[대조군] 원본 정정 블록: 값이 같아도 매 실행마다 새 버전을 쓴다(F2/PS-07)' 'orig-fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = $FAKE_TUN }
  & $IN @($FAKE_ROOT, 'a', 'cloudflared', 'cloudflared-tunnel', 'TUNNEL_TOKEN', 'yes') } 'ok' `
  @('OK 정정 완료') @() {
  $f = @(); if ((KvCur 'kv/platform/cloudflare/tunnel') -ne 2) { $f += '결함 재현 실패(버전이 늘지 않았다)' }; $f }

Run-Case 'REG-4' '[대조군] 원본 OP1(L46만 고친 사본): 끝 개행이 붙은 kv 값을 "동일"로 오판해 SKIP 한다(PS-02/F8)' 'orig-op1' {
  Seed-Kv 'kv/platform/cloudflare/dns-token' @{ token = $FAKE_DNS }
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = ($FAKE_TUN + "`n") }
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }
  & $IN @($FAKE_ROOT, '', '', '', '', '') } 'ok' `
  @('SKIP kv/platform/cloudflare/tunnel — 이미 시드됨(값 동일)', '이미 시드됨(동일)') @()

Run-Case 'REG-3' '[대조군] 원본 정정 블록: 다필드 경로에서 다른 필드가 조용히 사라진다(F3/VKE-2)' 'orig-fix' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = 'stale-value-0123456789abcdefghijklmn'; extra = 'keep-me' }
  & $IN @($FAKE_ROOT, 'a', 'cloudflared', 'cloudflared-tunnel', 'TUNNEL_TOKEN', 'yes') } 'ok' `
  @('OK 정정 완료') @() {
  $f = @()
  if ($null -ne (KvVal 'kv/platform/cloudflare/tunnel' 'extra')) { $f += '결함 재현 실패(extra 가 남아 있다)' }
  $f }

# ---------------------------------------------------------------- 결과 표
Write-Host "`n=== 결과 ==="
# ======================= STRICT extra negative scenarios (verifier A) =======================
$OK6 = { & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'go') }
Run-Case 'S-OP1-A' 'stop A) empty Enter -> abort, nothing written' 'op1' { & $IN @($FAKE_ROOT, '') } '정지점에서 중단' @() @() {
  $f = @(); if ($global:Kv.Count -ne 0) { $f += 'kv was written' }; $f }
Run-Case 'S-OP1-E' 'stop E) wrong word -> abort' 'op1' { & $IN @($FAKE_ROOT, 'go', 'go', 'skip', 'y', 'x') } '정지점에서 중단' @() @()
Run-Case 'S-OP1-ZW' 'existing kv value differs only by U+200B -> must NOT be judged identical' 'op1' {
  Seed-Kv 'kv/platform/cloudflare/tunnel' @{ token = ($FAKE_TUN + [string][char]0x200B) }; & $OK6 } '이미 다른 값이 있다' @() @('SKIP kv/platform/cloudflare/tunnel')
Run-Case 'S-OP1-BOM' 'existing kv value differs only by a leading U+FEFF -> must NOT be judged identical' 'op1' {
  Seed-Kv 'kv/platform/cloudflare/dns-token' @{ token = ([string][char]0xFEFF + $FAKE_DNS) }; & $OK6 } '이미 다른 값이 있다' @() @('SKIP kv/platform/cloudflare/dns-token')
Run-Case 'S-OP1-NL' 'live value ends with a newline -> rejected' 'op1' {
  $global:Secrets['cert-manager/cloudflare-dns-token'].data['api-token'] = ($FAKE_DNS + "`n"); & $OK6 } 'ASCII 인쇄 문자 밖' @() @() {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/cloudflare/dns-token')) { $f += 'kv was written' }; $f }
Run-Case 'S-OP1-CH' 'clipboard history on -> abort BEFORE any prompt' 'op1' { $global:ClipHistory = 1; & $OK6 } '클립보드 기록이 켜져 있음' @() @() {
  $f = @(); if ($global:Prompts.Count -gt 0) { $f += "prompted before the check ($($global:Prompts.Count))" }; $f }
Run-Case 'S-OP1-TRIM' 'root token pasted with surrounding blanks -> still works (Trim)' 'op1' { & $IN @((' ' + $FAKE_ROOT + ' '), 'go', 'go', 'skip', 'y', 'go') } 'ok' @('OK   kv/platform/cloudflare/tunnel') @()
Run-Case 'S-OP1-SAME' 'oci access_key == secret_key -> abort' 'op1' { & $IN @($FAKE_ROOT, 'go', 'go', 'y', $FAKE_AK, $FAKE_AK, 'y', 'go') } 'access_key 와 secret_key 가 같다' @() @() {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/oci/s3')) { $f += 'oci path written' }; $f }
Run-Case 'S-OP1-VD6' 'vault stores stdin JSON in an unexpected shape -> A) aborts before any real secret is read' 'op1' { $global:DrillFaults['putMangle'] = $true; & $OK6 } 'JSON stdin 형식이 기대와 다르다' @() @() {
  $f = @(); if ($global:Kv.ContainsKey('kv/platform/cloudflare/dns-token')) { $f += 'secret path written' }; $f }
Run-Case 'S-KVCL-STOP' 'cleanup stop: empty Enter -> abort, path kept' 'kvcl' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }; & $IN @($FAKE_ROOT, '') } '정지점에서 중단' @() @() {
  $f = @(); if (-not $global:Kv.ContainsKey('kv/platform/test/t045-probe')) { $f += 'path deleted' }; $f }
Run-Case 'S-KVCL-DEL' 'cleanup: metadata delete exits non-zero -> throw' 'kvcl' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }; $global:VaultFail['metadelete:kv/platform/test/t045-probe'] = 2; & $IN @($FAKE_ROOT, 'go') } 'kv 경로 삭제 실패' @() @('OK kv')
$DRSEED = { Seed-Kv 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }; & $IN @('go', 'go', 'go', 'go', 'go') }
Run-Case 'S-DR1-UID' 'adoption recreates the Secret (UID changes)' 'dr1' { & $DRSEED; $global:DrillFaults['uidChange'] = $true } 'UID 가 바뀌었다' @() @('OK 드릴 인수')
Run-Case 'S-DR1-OWN' 'ownerReferences present after adoption' 'dr1' { & $DRSEED; $global:DrillFaults['ownerRef'] = $true } 'ownerReferences 가 붙었다' @() @('OK 드릴 인수')
Run-Case 'S-DR1-LBL' 'managed label missing (ESO never wrote the Secret)' 'dr1' { & $DRSEED; $global:DrillFaults['noLabel'] = $true } 'managed 라벨이 없다' @() @('OK 드릴 인수')
Run-Case 'S-DR1-VAL' 'kv value differs from the manual Secret' 'dr1' {
  Seed-Kv 'kv/platform/test/t045-probe' @{ value = 'a-different-value' }; & $IN @('go', 'go', 'go', 'go', 'go') } '값이 바뀌었다' @() @('OK 드릴 인수')
Run-Case 'S-DR1-ESNOOP' 'ES delete exits 0 but the ES is still there' 'dr1' { & $DRSEED; $global:DrillFaults['deleteEsNoop'] = $true } 'ES 가 아직 있다' @() @('OK ES 삭제 후에도')
Run-Case 'S-DR1-GC' 'Secret recreated when the ES is deleted' 'dr1' { & $DRSEED; $global:DrillFaults['recreateOnEsDelete'] = $true } 'Secret 이 재생성됐다' @() @('OK ES 삭제 후에도')
Run-Case 'S-DR1-STEP6' 'step 6) Secret delete fails (2nd delete call) -> no false "cleanup done"' 'dr1' { & $DRSEED; $global:KubectlFailNth['delete:secret'] = 2 } '정리: Secret 삭제 실패' @('드릴 잔존물이 남아 있다') @('K8s 객체 정리 완료')
$results | Format-Table -AutoSize -Property id, result, desc, detail | Out-String -Width 220 | Write-Host
$pass = @($results | Where-Object { $_.result -eq 'PASS' }).Count
Write-Host ("PASS {0} / {1}   (파서 오류 파일 {2}개)" -f $pass, $results.Count, $parseBad)
if ($pass -ne $results.Count -or $parseBad -gt 0) { exit 1 }
