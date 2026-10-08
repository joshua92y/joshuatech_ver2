  # ===== T045 kv 값 정정 블록 — 통째로 붙여 넣어도 안전(창 D, 창 C의 port-forward 유지) =====
  # 원칙은 OP1과 같다: 사람 동작마다 Read-Host, 모든 취득·put·되읽기가 fail-closed, finally가 토큰·변수·클립보드를 정리한다.
  $ErrorActionPreference = 'Stop'
  $fixPath  = 'kv/platform/cloudflare/tunnel'    # 정정할 경로(DNS면 kv/platform/cloudflare/dns-token)
  $fixField = 'token'
  try {
    if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
    $env:VAULT_ADDR = 'http://127.0.0.1:18200'
    $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
    if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }
    $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
    if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
    $tl = vault token lookup "-format=json" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

    # 1) 정정 값 취득(세 갈래). 빈 값·짧은 값·앞뒤 공백이면 중단한다.
    $src = Read-Host '값 출처: a=라이브 Secret · b=이 세션의 $pre(base64) · c=PM 직접 입력'
    switch ($src) {
      'a' { $ns = Read-Host 'ns'; $sn = Read-Host 'secret 이름'; $sk = Read-Host 'secret 키'
            $b64 = kubectl -n $ns get secret $sn -o "jsonpath={.data.$sk}"
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw '라이브 Secret 취득 실패 — 중단' }
            $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }
      'b' { if ([string]::IsNullOrWhiteSpace($pre)) { throw '$pre 가 비어 있다(이 세션이 아니다) — c 로 간다' }
            $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pre)) }
      'c' { $new = (Read-Host 'PM 값' -AsSecureString | ConvertFrom-SecureString -AsPlainText) }
      default { throw '출처를 고르지 않았다 — 중단' }
    }
    if ([string]::IsNullOrWhiteSpace($new) -or $new.Length -lt 32) { throw '정정 값이 비었거나 비정상적으로 짧다 — 중단' }
    if (-not [string]::Equals($new, $new.Trim(), [StringComparison]::Ordinal)) { throw '정정 값 앞뒤에 공백/개행 — 중단' }

    # 2) CAS 대상 = 현재 버전. 못 읽으면 중단(덮어쓰기를 눈감고 하지 않는다).
    $cur = (vault kv metadata get "-format=json" $fixPath | ConvertFrom-Json).data.current_version
    if ($LASTEXITCODE -ne 0 -or $null -eq $cur) { throw "current_version 취득 실패: $fixPath — 중단" }
    $ok = Read-Host "3) $fixPath 의 현재 버전 $cur 를 덮어쓴다. 계속하려면 yes 를 입력하고 Enter"
    if (-not [string]::Equals($ok, 'yes', [StringComparison]::Ordinal)) { throw '취소됨 — 아무것도 쓰지 않았다' }

    # 4) CAS put → 되읽기 SHA-256 Ordinal 비교
    (@{ $fixField = $new } | ConvertTo-Json -Compress) | vault kv put "-cas=$cur" $fixPath -
    if ($LASTEXITCODE -ne 0) { throw "정정 put 실패(CAS 충돌이면 그 사이 다른 쓰기가 있었다): $fixPath" }
    $sha  = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $back = [string](vault kv get "-field=$fixField" $fixPath)
    if ($LASTEXITCODE -ne 0) { throw "되읽기 실패: $fixPath .$fixField" }
    if (-not [string]::Equals((& $sha $back), (& $sha $new), [StringComparison]::Ordinal)) { throw '되읽기 해시 불일치 — 값이 기대와 다르다. 다음 refresh 전에 다시 정정한다' }
    "OK 정정 완료: $fixPath .$fixField (새 버전 $($cur + 1))"
  }
  finally {
    # ⚠ `$pre`·`$preUid`는 지우지 않는다 — G4 되돌리기 R2의 stdin 복구에 필요하다.
    Remove-Variable new, back, b64, src, ns, sn, sk, sha, tl, st, cur, ok -ErrorAction SilentlyContinue
    if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
    if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
    try { Set-Clipboard -Value ' ' } catch { }
    '다음 refresh(≤5분) 또는 VD-15 force-sync 뒤 라이브 Secret 값을 다시 비교한다.'
  }
  