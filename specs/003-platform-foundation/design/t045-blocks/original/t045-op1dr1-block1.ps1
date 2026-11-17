# ===== T045 OP1 시드 블록 — 통째로 붙여 넣어도 안전(창 D) =====
# 원칙: (a) 사람 동작마다 Read-Host로 멈춘다 (b) 취득·put·되읽기는 전부 fail-closed(throw) — 출력만 하고 계속 가는 비교는 없다
#       (c) 검증 통과 전에는 원본(라이브 Secret·PM·변수)을 아무것도 지우지 않는다 (d) 값은 화면·argv·파일에 나오지 않는다
#       (e) 최초 쓰기는 `-cas=0`(이미 값이 있으면 거부), 재실행은 해시 비교로 "동일이면 통과 / 다르면 중단"(D10-⑤)
#       (f) 성공·실패 어느 쪽이든 finally가 토큰·변수·클립보드를 정리하고 경로별 요약을 낸다
$ErrorActionPreference = 'Stop'
$seedLog = [ordered]@{}   # 경로 → 완료(신규) / 이미 시드됨(동일) / 보류(사유) / 중단(사유)
try {
  if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
  if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인 확인 후 다시' }
  $env:VAULT_ADDR = 'http://127.0.0.1:18200'
  $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
  if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }

  $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
  if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
  $tl = vault token lookup "-format=json" | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

  $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
  $getLive = { param($ns, $name, $key)
    $b64 = kubectl -n $ns get secret $name -o "jsonpath={.data.$key}"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw "라이브 Secret 취득 실패: $ns/$name .$key — 시드 중단" }
    $v = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
    if ($v.Length -lt 32) { throw "라이브 값이 비정상적으로 짧다($($v.Length)) — 시드 중단" }
    if (-not [string]::Equals($v, $v.Trim(), [StringComparison]::Ordinal)) { throw "라이브 값 앞뒤에 공백/개행 — 그대로 복사하면 안 된다. 중단(사용자 결정)" }   # ⚠ `-cne`는 문화권 비교라 U+FEFF 같은 무시 가능 코드포인트를 놓친다
    $v }
  $exists = { param($path)                        # 경로에 현재 버전이 있는가(없으면 vault가 비0으로 끝난다)
    $j = $null
    try { $j = vault kv get "-format=json" $path 2>$null } catch { $j = $null }
    $ok = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$j))
    $global:LASTEXITCODE = 0
    $ok }
  $readField = { param($path, $field)
    $v = [string](vault kv get "-field=$field" $path)
    if ($LASTEXITCODE -ne 0) { throw "되읽기 실패: $path .$field" }
    $v }
  # 경로 1개 시드. 이미 값이 있으면 **덮어쓰지 않고** 해시로 가른다(재실행 안전).
  $seed = { param($path, [hashtable]$map)
    foreach ($k in $map.Keys) { if ($map[$k] -isnot [string] -or [string]::IsNullOrWhiteSpace($map[$k])) { throw "$path .$k 가 빈 값이거나 문자열이 아니다 — 중단" } }
    if (& $exists $path) {
      foreach ($k in $map.Keys) {
        $back = & $readField $path $k
        if (-not [string]::Equals((& $sha $back), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
          $seedLog[$path] = '중단(존재하지만 값이 다름)'
          throw "$path .$k: 이미 다른 값이 있다 — 덮어쓰지 않고 중단(값 교체는 T084 회전 절차)" } }
      $seedLog[$path] = '이미 시드됨(동일)'
      return "SKIP $path — 이미 시드됨(값 동일)" }
    ($map | ConvertTo-Json -Compress) | vault kv put "-cas=0" $path -   # JSON stdin 한 형식. `key=-` 금지(stdin 1회·개행 포함). 값은 JSON 문자열만.
    if ($LASTEXITCODE -ne 0) { $seedLog[$path] = '중단(put 실패 — CAS 충돌이면 이미 값이 있다)'; throw "vault kv put 실패: $path" }
    foreach ($k in $map.Keys) {
      $back = & $readField $path $k
      if (-not [string]::Equals((& $sha $back), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
        $seedLog[$path] = '중단(되읽기 불일치)'
        throw "kv 값 불일치: $path .$k — 중단(원본 유지)" } }
    $seedLog[$path] = '완료(신규)'
    "OK   $path ($((($map.Keys) | Sort-Object) -join ', '))" }

  Read-Host 'A) 폐기 경로로 JSON stdin 형식을 1회 실측한다(VD-6). Enter'
  ('{"a":"x","b":"y"}') | vault kv put "-cas=0" kv/platform/_probe -
  if ($LASTEXITCODE -ne 0) { throw '프로브 put 실패 — 경로가 이미 있거나 권한 문제. 확인 후 다시' }
  $pk = ((vault kv get "-format=json" kv/platform/_probe | ConvertFrom-Json).data.data.PSObject.Properties.Name | Sort-Object) -join ','
  if (-not [string]::Equals($pk, 'a,b', [StringComparison]::Ordinal)) { throw "JSON stdin 형식이 기대와 다르다(keys=$pk) — 중단, 설계 VD-6 폴백 검토" }
  vault kv metadata delete kv/platform/_probe | Out-Null
  if ($LASTEXITCODE -ne 0) { throw '프로브 경로 삭제 실패 — 수동 확인 후 다시(경로가 남으면 재실행 시 A)의 `-cas=0`이 막힌다)' }

  Read-Host 'B) 라이브 Secret 2건 → Vault 파이프 복사(값 비노출). Enter'
  $v1 = & $getLive 'cert-manager' 'cloudflare-dns-token' 'api-token'
  & $seed 'kv/platform/cloudflare/dns-token' @{ token = $v1 }
  $v2 = & $getLive 'cloudflared' 'cloudflared-tunnel' 'TUNNEL_TOKEN'
  & $seed 'kv/platform/cloudflare/tunnel' @{ token = $v2 }

  $ans = Read-Host 'C) kv/platform/oci/s3 — PM에 svc-s3-backup 키 쌍의 **두 절반이 모두** 있음을 확인했으면 y, 없으면 Enter(건너뜀 · 재발급하지 않음)'
  if ($ans -eq 'y') {
    $ak = (Read-Host 'access_key' -AsSecureString | ConvertFrom-SecureString -AsPlainText).Trim()
    $sk = (Read-Host 'secret_key' -AsSecureString | ConvertFrom-SecureString -AsPlainText).Trim()
    & $seed 'kv/platform/oci/s3' @{ access_key = $ak; secret_key = $sk }
  } else {
    $seedLog['kv/platform/oci/s3'] = '보류(키 쌍 미확인 — 자동 재발급 금지 · T053 전 별도 발급·교체 작업)'
  }

  Read-Host 'D) DR1 드릴용 비밀 아닌 값 1건(kv/platform/test/t045-probe). Enter'
  & $seed 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }

  # 이연(D10): kv/{dev,prod}/access/web-bff · kv/platform/access/tester-{m2m,k8s} → T077·T092
  #            kv/platform/grafana-cloud → T098(임시 값·sentinel 금지)
  $seedLog['kv/{dev,prod}/access/web-bff']            = '이연(T092 — 읽기 권한 범위·전달 절차 확정 후)'
  $seedLog['kv/platform/access/tester-{m2m,k8s}']     = '이연(T077 — 동일)'
  $seedLog['kv/platform/grafana-cloud']               = '이연(T098 — 소비자 기준 키 집합 확정 후)'

  vault kv metadata get kv/platform/cloudflare/dns-token | Select-String 'current_version|created_time'
  vault kv metadata get kv/platform/cloudflare/tunnel    | Select-String 'current_version|created_time'
  vault kv list kv/platform;  vault kv list kv/platform/cloudflare

  Read-Host 'E) 위 OK/SKIP 줄과 version 을 런북 §4 기록용으로 확인했으면 Enter — 정리로 넘어간다(라이브 Secret·PM 은 건드리지 않는다)'
}
finally {
  Remove-Variable v1, v2, ak, sk, pk, tl, st -ErrorAction SilentlyContinue
  if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
  if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
  try { Set-Clipboard -Value ' ' } catch { }
  ''
  '--- 시드 결과 요약(런북 §4에 그대로 기록) ---'
  $seedLog.GetEnumerator() | ForEach-Object { '{0,-46} {1}' -f $_.Key, $_.Value }
  if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
  '창 종료 체크리스트(런북 §0): 창 C port-forward 종료 · cloudflared access 캐시 토큰 삭제'
}
