# 플랫폼 테스트 러너 (T004). Run: pwsh -NoProfile -File tests/platform/run-platform-tests.ps1
# Exit 0 = 전부 통과 또는 SKIP, 1 = 게이트 거부(fail closed) 또는 테스트 실패.
#
# 동작:
#   1) KUBECONFIG가 없거나(미설정/빈 값) 그 파일이 없으면: SKIP 요약(실행했을 *.tests.ps1 목록) 출력 후 exit 0.
#   2) KUBECONFIG가 있으면: 먼저 `kubectl auth whoami -o json`으로 현재 컨텍스트 사용자가
#      system:serviceaccount:kube-system:agent-view인지 단언한다. admin kubeconfig(k3s.yaml 등)면 FAIL로 실행 거부.
#      게이트는 fail-closed: kubectl 부재·whoami 실패·출력 파싱 실패 모두 FAIL(exit 1).
#   3) 이 디렉터리의 *.tests.ps1(자기 자신 제외)을 차례로 실행해 집계한다. 0개면 "0 test files (SKIP)" 후 exit 0.
#
# Argo CD 확인은 `kubectl -n argocd get applications`로 한다 — 에이전트·tester에게 Argo CD API 자격을 주지
# 않으므로 이 러너는 Argo CD 서버 주소·자격을 전제하지 않는다(contracts/hostnames-and-access.md §에이전트 자격;
# `argocd --sso` 로그인은 운영자 수동 + 스크린샷).
# KUBECONFIG는 단일 파일 경로로 취급한다(경로 목록은 지원하지 않는다 — 목록이면 파일 없음으로 보고 SKIP).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$selfName = [IO.Path]::GetFileName($PSCommandPath)

# 대상 발견: 이 디렉터리의 *.tests.ps1 — 자기 자신은 방어적으로 제외(ordinal), 이름은 ordinal 정렬
$testFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter '*.tests.ps1' |
        Where-Object { -not [string]::Equals($_.Name, $selfName, [StringComparison]::Ordinal) })
[Array]::Sort($testFiles, [Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.Name, $b.Name) })

function Write-WouldRun {
    if ($testFiles.Count -eq 0) { Write-Host 'would have run: (none)' }
    else { foreach ($f in $testFiles) { Write-Host "would have run: $($f.Name)" } }
}

# ---------- 1. KUBECONFIG 게이트: 없으면 SKIP ----------
if ([string]::IsNullOrWhiteSpace($env:KUBECONFIG)) {
    Write-Host 'SKIP platform tests -- KUBECONFIG is not set'
    Write-WouldRun
    exit 0
}
# 사용자 제공 상대 경로는 PSPath로 해석한다(.NET cwd 아님 — CLAUDE.md Known Issues). 해석 불가면 파일 없음으로 취급(SKIP).
$kubeconfigPath = $null
try { $kubeconfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:KUBECONFIG) } catch { $kubeconfigPath = $null }
if (-not $kubeconfigPath -or -not (Test-Path -LiteralPath $kubeconfigPath -PathType Leaf)) {
    Write-Host "SKIP platform tests -- KUBECONFIG file not found: $($env:KUBECONFIG)"
    Write-WouldRun
    exit 0
}

# ---------- 2. 신원 게이트(fail-closed): agent-view가 아니면 실행 거부 ----------
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host 'FAIL platform tests -- KUBECONFIG is set but kubectl is not on PATH; cannot verify the context user, refusing to run (fail closed)'
    exit 1
}
$whoamiErrFile = Join-Path ([IO.Path]::GetTempPath()) ('platform-whoami-' + [guid]::NewGuid().ToString('N') + '.txt')
try {
    $whoamiOut = & kubectl auth whoami -o json 2> $whoamiErrFile
    $whoamiCode = $LASTEXITCODE
    $whoamiErr = if (Test-Path -LiteralPath $whoamiErrFile) { ([IO.File]::ReadAllText($whoamiErrFile)).Trim() } else { '' }
} finally {
    Remove-Item -LiteralPath $whoamiErrFile -Force -ErrorAction SilentlyContinue
}
if ($whoamiCode -ne 0) {
    Write-Host "FAIL platform tests -- 'kubectl auth whoami' failed (exit=$whoamiCode): $whoamiErr"
    exit 1
}
$username = $null
try {
    $whoamiJson = (@($whoamiOut | ForEach-Object { "$_" }) -join "`n") | ConvertFrom-Json
    if ($whoamiJson -and $whoamiJson.status -and $whoamiJson.status.userInfo) { $username = [string]$whoamiJson.status.userInfo.username }
} catch { $username = $null }
if ([string]::IsNullOrWhiteSpace($username)) {
    Write-Host "FAIL platform tests -- could not parse 'kubectl auth whoami -o json' output; refusing to run (fail closed)"
    exit 1
}
if (-not [string]::Equals($username, $expectedUser, [StringComparison]::Ordinal)) {
    Write-Host "FAIL platform tests -- current context user is '$username', expected '$expectedUser'; refusing to run with non-agent-view credentials (an admin kubeconfig such as k3s.yaml is rejected)"
    exit 1
}
Write-Host "context user: $username (ok)"

# ---------- 3. 실행·집계 ----------
if ($testFiles.Count -eq 0) {
    Write-Host '0 test files (SKIP)'
    exit 0
}
$passed = 0
$failed = 0
foreach ($f in $testFiles) {
    Write-Host "--- $($f.Name)"
    & ([Environment]::ProcessPath) -NoProfile -ExecutionPolicy Bypass -File $f.FullName | Out-Host
    if ($LASTEXITCODE -eq 0) { $passed++ }
    else { $failed++; Write-Host "FAIL $($f.Name) (exit=$LASTEXITCODE)" }
}
Write-Host ''
Write-Host "test files: $passed passed, $failed failed"
if ($failed -gt 0) { exit 1 } else { exit 0 }
