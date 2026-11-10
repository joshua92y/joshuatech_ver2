# ===== T045 DR1 kv 정리 블록 — 통째로 붙여 넣어도 안전(창 D) =====
$ErrorActionPreference = 'Stop'
try {
  if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
  $env:VAULT_ADDR = 'http://127.0.0.1:18200'
  $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
  if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }
  $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
  if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
  $tl = vault token lookup "-format=json" | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

  Read-Host 'kv/platform/test/t045-probe 를 메타데이터째 삭제한다(드릴 전용 · 비밀 아님). Enter'
  vault kv metadata delete kv/platform/test/t045-probe
  if ($LASTEXITCODE -ne 0) { throw 'kv 경로 삭제 실패 — 수동 확인' }
  vault kv metadata get kv/platform/test/t045-probe 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { throw '경로가 아직 있다 — 삭제가 되지 않았다' }
  $global:LASTEXITCODE = 0
  'OK kv 드릴 경로 삭제'
}
finally {
  Remove-Variable tl, st -ErrorAction SilentlyContinue
  if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
  if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
  try { Set-Clipboard -Value ' ' } catch { }
}
