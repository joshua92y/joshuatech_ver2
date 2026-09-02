# tests/platform/run-platform-tests.ps1 테스트. Run: pwsh -NoProfile -File tests/scripts/run-platform-tests.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/update-specs-index.tests.ps1와 같은 구조).
# 배치 이유: 러너는 자기 디렉터리(tests/platform/)의 *.tests.ps1을 발견·실행하므로, 이 하네스를 같은 폴더에
#   두면 러너 자신이 이 파일을 실행하게 된다. 그래서 스크립트 하네스가 있는 tests/scripts/에 둔다
#   (run-all의 platform-harness 체크가 이 파일을 직접 실행한다).
# 방식: 픽스처 디렉터리에 러너 사본 + 가짜 *.tests.ps1 파일을 만들고 사본을 실행한다.
#   kubectl은 픽스처 bin/의 kubectl.cmd 심(shim)으로 대체한다(PATH 앞에 끼워 넣어 실제 kubectl을 가린다).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runnerPath = Join-Path $repo 'tests/platform/run-platform-tests.ps1'
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$script:pass = 0
$script:fail = 0
$script:fixtures = @()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리. 한 그룹에서 예외가 나도 나머지 그룹은 계속 실행된다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Format-Result($r) { "out=[$($r.out)] err=[$($r.err)] [code=$($r.code)]" }

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }

# 줄 배열에 정확히(ordinal) 같은 줄이 있는지
function Test-HasLine([string[]]$lines, [string]$line) { foreach ($l in $lines) { if (Test-Same $l $line) { return $true } }; return $false }

# 키 = 픽스처 루트 기준 상대 경로, 값 = 문자열(UTF-8, BOM 없음, 개행은 값 그대로)
function New-Fixture([hashtable]$files = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('platformrun-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false))
    }
    return $dir
}

function Remove-Fixture {
    foreach ($f in $script:fixtures) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
    $script:fixtures = @()
}

# 러너 사본을 픽스처에 만들고 경로를 돌려준다. 러너가 아직 없으면 $null(호출부의 Invoke-Runner가 code 127 처리).
function Copy-Runner([string]$dir) {
    if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) { return $null }
    $dest = Join-Path $dir 'run-platform-tests.ps1'
    Copy-Item -LiteralPath $runnerPath -Destination $dest
    return $dest
}

# kubectl.cmd 심을 픽스처 bin/에 만들고 bin 경로를 돌려준다. CRLF로 쓴다(cmd 배치 파일 관례), BOM 없음(@echo off가 1행이어야 한다).
function New-KubectlShim([string]$dir, [string]$body) {
    $bin = Join-Path $dir 'bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $bin 'kubectl.cmd'), $body, [Text.UTF8Encoding]::new($false))
    return $bin
}

# KUBECONFIG·PATH를 바꿔 러너 사본을 자식 pwsh로 실행하고 반드시 원복한다.
#   $kubeconfig  ''이면 KUBECONFIG 변수 제거(미설정 시나리오)
#   $path        ''이면 PATH 유지
function Invoke-Runner([string]$runnerFile, [string]$kubeconfig, [string]$path) {
    if (-not $runnerFile -or -not (Test-Path -LiteralPath $runnerFile)) { return @{ out = "<missing runner: $runnerPath>"; err = ''; code = 127 } }
    $savedKc = $env:KUBECONFIG
    $savedPath = $env:PATH
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('platformrun-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        if ([string]::IsNullOrEmpty($kubeconfig)) { Remove-Item Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $kubeconfig }
        if (-not [string]::IsNullOrEmpty($path)) { $env:PATH = $path }
        $out = & ([Environment]::ProcessPath) -NoProfile -ExecutionPolicy Bypass -File $runnerFile 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
    } finally {
        if ($null -eq $savedKc) { Remove-Item Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $savedKc }
        $env:PATH = $savedPath
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return @{
        out  = (@($out | ForEach-Object { "$_" }) -join "`n")
        err  = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code = $code
    }
}

# ---------- 심 본문(cmd) — echo는 따옴표·중괄호를 그대로 출력한다 ----------
$crlf = "`r`n"
$shimAgentView = (@(
        '@echo off'
        'echo {"apiVersion":"authentication.k8s.io/v1","kind":"SelfSubjectReview","status":{"userInfo":{"username":"system:serviceaccount:kube-system:agent-view"}}}'
        'exit /b 0'
    ) -join $crlf) + $crlf
$shimAdmin = (@(
        '@echo off'
        'echo {"apiVersion":"authentication.k8s.io/v1","kind":"SelfSubjectReview","status":{"userInfo":{"username":"system:admin"}}}'
        'exit /b 0'
    ) -join $crlf) + $crlf
$shimFail = (@(
        '@echo off'
        'echo error: You must be logged in to the server 1>&2'
        'exit /b 1'
    ) -join $crlf) + $crlf
$shimBadJson = (@(
        '@echo off'
        'echo this is not json'
        'exit /b 0'
    ) -join $crlf) + $crlf

# ---------- 픽스처 조각 ----------
$kubeconfigYaml = "apiVersion: v1`nkind: Config`n"
$samplePassA = "Write-Host 'RAN-MARKER-alpha'`nexit 0`n"
$samplePassB = "Write-Host 'RAN-MARKER-beta'`nexit 0`n"
$sampleFail = "Write-Host 'RAN-MARKER-gamma'`nexit 1`n"
$sep = [IO.Path]::PathSeparator

try {
    # ---------- 정적: 러너 존재·ARGOCD_SERVER 미참조·기대 사용자 문자열 ----------
    Test-Group 'static' {
        $src = if (Test-Path -LiteralPath $runnerPath -PathType Leaf) { [IO.File]::ReadAllText($runnerPath) } else { $null }
        Assert 'static-1: runner exists at tests/platform/run-platform-tests.ps1' ($null -ne $src) "missing: $runnerPath"
        Assert 'static-2: runner never references ARGOCD_SERVER (agents get no Argo CD API credentials; Argo checks go through kubectl)' ($null -ne $src -and $src.IndexOf('ARGOCD_SERVER', [StringComparison]::Ordinal) -lt 0) 'ARGOCD_SERVER found in runner source (or runner missing)'
        Assert 'static-3: runner pins the exact expected user string' ($null -ne $src -and $src.IndexOf($expectedUser, [StringComparison]::Ordinal) -ge 0) "expected user string '$expectedUser' not found (or runner missing)"
    }

    # ---------- A: KUBECONFIG 미설정 → SKIP 요약(목록 포함), 테스트 파일 미실행, exit 0 ----------
    Test-Group 'A: no KUBECONFIG' {
        $d = New-Fixture @{ 'aa-sample.tests.ps1' = $samplePassA; 'bb-sample.tests.ps1' = $samplePassB }
        $runner = Copy-Runner $d
        $r = Invoke-Runner $runner '' ''
        $lines = $r.out -split "`n"
        Assert 'A-1: KUBECONFIG unset -> exit 0, first line "SKIP platform tests -- KUBECONFIG is not set"' (
            $r.code -eq 0 -and $lines.Count -ge 1 -and (Test-Same $lines[0] 'SKIP platform tests -- KUBECONFIG is not set')
        ) (Format-Result $r)
        Assert 'A-2: SKIP summary lists each would-be test file and none is executed' (
            $r.code -eq 0 -and (Test-HasLine $lines 'would have run: aa-sample.tests.ps1') -and (Test-HasLine $lines 'would have run: bb-sample.tests.ps1') -and $r.out.IndexOf('RAN-MARKER', [StringComparison]::Ordinal) -lt 0
        ) (Format-Result $r)
    }

    # ---------- B: KUBECONFIG가 없는 파일을 가리킴 → SKIP, exit 0 ----------
    Test-Group 'B: KUBECONFIG file missing' {
        $d = New-Fixture @{}
        $runner = Copy-Runner $d
        $r = Invoke-Runner $runner (Join-Path $d 'nope/kubeconfig.yaml') ''
        Assert 'B-1: KUBECONFIG points to a nonexistent file -> exit 0, "SKIP platform tests -- KUBECONFIG file not found: ...", "would have run: (none)"' (
            $r.code -eq 0 -and $r.out.StartsWith('SKIP platform tests -- KUBECONFIG file not found:', [StringComparison]::Ordinal) -and (Test-HasLine ($r.out -split "`n") 'would have run: (none)')
        ) (Format-Result $r)
    }

    # ---------- C: KUBECONFIG 있음 + kubectl 부재 → fail closed, exit 1 ----------
    Test-Group 'C: kubectl missing' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml }
        $runner = Copy-Runner $d
        $pwshDir = Split-Path ([Environment]::ProcessPath)
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') $pwshDir
        Assert 'C-1: KUBECONFIG set but kubectl not on PATH -> exit 1, FAIL says kubectl is not on PATH (fail closed)' (
            $r.code -eq 1 -and $r.out -match 'FAIL platform tests' -and $r.out -match 'kubectl is not on PATH'
        ) (Format-Result $r)
    }

    # ---------- D: 잘못된 사용자(admin 류) → 실행 거부, 테스트 파일 미실행, exit 1 ----------
    Test-Group 'D: wrong user' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml; 'aa-sample.tests.ps1' = $samplePassA }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimAdmin
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        Assert 'D-1: whoami returns system:admin -> exit 1, refusal names actual and expected user, tests are not run' (
            $r.code -eq 1 -and $r.out -match 'FAIL platform tests' -and $r.out.IndexOf("'system:admin'", [StringComparison]::Ordinal) -ge 0 -and $r.out.IndexOf($expectedUser, [StringComparison]::Ordinal) -ge 0 -and $r.out.IndexOf('RAN-MARKER', [StringComparison]::Ordinal) -lt 0
        ) (Format-Result $r)
    }

    # ---------- E: kubectl auth whoami 실패 → fail closed, exit 1 ----------
    Test-Group 'E: whoami failure' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimFail
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        Assert 'E-1: kubectl auth whoami exits nonzero -> runner exit 1, FAIL mentions whoami failure' (
            $r.code -eq 1 -and $r.out -match 'FAIL platform tests' -and $r.out -match 'whoami' -and $r.out -match 'failed'
        ) (Format-Result $r)
    }

    # ---------- F: whoami 출력이 JSON이 아님 → fail closed, exit 1 ----------
    Test-Group 'F: unparsable whoami output' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimBadJson
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        Assert 'F-1: whoami output not parsable as JSON -> exit 1 (fail closed), FAIL says could not parse' (
            $r.code -eq 1 -and $r.out -match 'FAIL platform tests' -and $r.out -match 'could not parse'
        ) (Format-Result $r)
    }

    # ---------- G: agent-view + 테스트 파일 0개 → "0 test files (SKIP)", exit 0 (러너 자신은 발견 대상이 아님) ----------
    Test-Group 'G: zero test files' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimAgentView
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        $lines = $r.out -split "`n"
        Assert 'G-1: agent-view + no *.tests.ps1 -> exit 0, "0 test files (SKIP)", context user echoed' (
            $r.code -eq 0 -and (Test-HasLine $lines '0 test files (SKIP)') -and (Test-HasLine $lines "context user: $expectedUser (ok)")
        ) (Format-Result $r)
    }

    # ---------- H: agent-view + 전부 통과 → 집계 "2 passed, 0 failed", exit 0 ----------
    Test-Group 'H: all pass' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml; 'aa-sample.tests.ps1' = $samplePassA; 'bb-sample.tests.ps1' = $samplePassB }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimAgentView
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        $lines = $r.out -split "`n"
        Assert 'H-1: two passing test files -> exit 0, both executed, summary "test files: 2 passed, 0 failed"' (
            $r.code -eq 0 -and $r.out.IndexOf('RAN-MARKER-alpha', [StringComparison]::Ordinal) -ge 0 -and $r.out.IndexOf('RAN-MARKER-beta', [StringComparison]::Ordinal) -ge 0 -and (Test-HasLine $lines 'test files: 2 passed, 0 failed')
        ) (Format-Result $r)
    }

    # ---------- I: agent-view + 하나 실패 → 집계 "1 passed, 1 failed", exit 1 ----------
    Test-Group 'I: one failure' {
        $d = New-Fixture @{ 'kubeconfig.yaml' = $kubeconfigYaml; 'aa-sample.tests.ps1' = $samplePassA; 'bb-fail.tests.ps1' = $sampleFail }
        $runner = Copy-Runner $d
        $bin = New-KubectlShim $d $shimAgentView
        $r = Invoke-Runner $runner (Join-Path $d 'kubeconfig.yaml') ($bin + $sep + $env:PATH)
        $lines = $r.out -split "`n"
        Assert 'I-1: one failing test file -> exit 1, failing file still executed, summary "test files: 1 passed, 1 failed"' (
            $r.code -eq 1 -and $r.out.IndexOf('RAN-MARKER-gamma', [StringComparison]::Ordinal) -ge 0 -and (Test-HasLine $lines 'test files: 1 passed, 1 failed')
        ) (Format-Result $r)
    }
} finally {
    Remove-Fixture
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
