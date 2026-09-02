# 플랫폼 테스트 러너 (T004). Run: pwsh -NoProfile -File tests/platform/run-platform-tests.ps1
# Exit 0 = 전부 통과 또는 SKIP, 1 = 게이트 거부(fail closed) 또는 테스트 실패.
#
# 동작:
#   0) infra 그룹(T006): infra/oci에 *.tf가 하나 이상 있으면 tests/infra/tofu.tests.ps1을 KUBECONFIG 게이트보다
#      먼저 실행한다(tofu 단언은 클러스터가 아니라 tofu를 요구한다). 없으면 "SKIP infra tests" 후 계속(T007 전).
#      인프라 테스트 실패·파일 부재는 즉시 exit 1(fail closed). flat-only 가드는 tests/platform/ 하위만 보므로
#      형제 디렉터리 tests/infra/에는 걸리지 않는다.
#   1) KUBECONFIG가 없거나(미설정/빈 값) 그 파일이 없으면: SKIP 요약(실행했을 *.tests.ps1 목록) 출력 후 exit 0.
#   2) KUBECONFIG가 있으면: 먼저 `kubectl auth whoami -o json`으로 현재 컨텍스트 사용자가
#      system:serviceaccount:kube-system:agent-view인지 단언한다. admin kubeconfig(k3s.yaml 등)면 FAIL로 실행 거부.
#      게이트는 fail-closed: kubectl 부재·whoami 실패·출력 파싱 실패 모두 FAIL(exit 1).
#   3) 이 디렉터리의 *.tests.ps1(자기 자신 제외)을 차례로 실행해 집계한다. 0개면 "0 test files (SKIP)" 후 exit 0.
#      발견은 이 디렉터리 한 단계(flat)뿐이다 — 하위 디렉터리에 *.tests.ps1이 있으면 조용히 건너뛰지 않고
#      KUBECONFIG 게이트보다 먼저 FAIL로 거부한다(fail closed; SKIP 경로가 중첩 파일을 숨기지 못하게).
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

# ---------- 0. flat-only 가드(fail-closed): 하위 디렉터리의 *.tests.ps1은 발견되지 않으므로 존재 자체가 FAIL ----------
# KUBECONFIG 게이트보다 먼저 검사한다 — SKIP 경로가 중첩 파일을 조용히 숨기면 안 된다.
$nested = @(Get-ChildItem -LiteralPath $PSScriptRoot -Directory |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -File -Filter '*.tests.ps1' -Recurse })
if ($nested.Count -gt 0) {
    Write-Host 'FAIL platform tests -- discovery is flat-only (tests/platform/*.tests.ps1); these nested test files would be silently skipped, move them directly under tests/platform/:'
    foreach ($n in $nested) { Write-Host "  $($n.FullName)" }
    exit 1
}

# ---------- 0b. infra 그룹(T006): KUBECONFIG 게이트보다 먼저 — tofu 단언은 클러스터를 요구하지 않는다 ----------
# 게이트: infra/oci에 *.tf가 하나 이상 있을 때만 tests/infra/tofu.tests.ps1을 실행한다(T007 전에는 SKIP — run-all 녹색 유지).
# JT_INFRA_DIR·JT_INFRA_TESTS는 하네스(tests/scripts/run-platform-tests.tests.ps1) 전용 오버라이드다 — 운영에서는 설정하지 않는다.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$infraDir = if (-not [string]::IsNullOrWhiteSpace($env:JT_INFRA_DIR)) { $env:JT_INFRA_DIR } else { Join-Path $repoRoot 'infra/oci' }
$infraTests = if (-not [string]::IsNullOrWhiteSpace($env:JT_INFRA_TESTS)) { $env:JT_INFRA_TESTS } else { Join-Path $repoRoot 'tests/infra/tofu.tests.ps1' }
$infraTfCount = 0
if (Test-Path -LiteralPath $infraDir -PathType Container) {
    $infraTfCount = @(Get-ChildItem -LiteralPath $infraDir -File -Filter '*.tf').Count
}
if ($infraTfCount -eq 0) {
    Write-Host 'SKIP infra tests -- infra/oci not present yet (T007+)'
} elseif (-not (Test-Path -LiteralPath $infraTests -PathType Leaf)) {
    # fail-closed: 구성은 있는데 인프라 테스트 파일이 없으면 조용히 지나가지 않는다
    Write-Host "FAIL infra tests -- infra config exists but test file is missing: $infraTests"
    exit 1
} else {
    Write-Host "--- infra: $([IO.Path]::GetFileName($infraTests))"
    & ([Environment]::ProcessPath) -NoProfile -ExecutionPolicy Bypass -File $infraTests | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Host "FAIL infra tests (exit=$LASTEXITCODE)"; exit 1 }
    Write-Host 'PASS infra tests'
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
