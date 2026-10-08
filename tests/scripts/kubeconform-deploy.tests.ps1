# scripts/ci/kubeconform-deploy.sh 테스트(T047 M1). Run: pwsh -NoProfile -File tests/scripts/kubeconform-deploy.tests.ps1
# Exit 0 = all pass(또는 도구 없음 SKIP), 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/run-platform-tests.tests.ps1와 같은 구조).
#
# 도구가 없을 때 — 선택 (a) 파일 전체 SKIP: bash(Git/POSIX bash — WSL의 System32 bash는 Windows 경로를 못 읽어 쓰지 않는다) ·
#   kustomize · kubeconform 중 하나라도 없으면 첫 줄로 'SKIP kubeconform-deploy tests -- <없는 도구>'를 찍고 exit 0으로 끝난다.
#   정적 단언도 돌리지 않는다: 정적 단언만의 PASS가 실행 단언의 부재를 가리지 않게 항목 전체를 SKIP으로 드러낸다
#   (tests/run-all.ps1 1b3이 이 첫 줄을 SKIP으로 읽는다 — 통과로 세지 않는다).
#   스크립트 부재는 SKIP이 아니다 — 실행 단언이 전부 FAIL한다(fail closed).
#   시작할 때 저장소의 .superpowers/bin(로컬 도구 위치 · gitignore)이 있으면 PATH 앞에 더한다(없으면 아무 일도 하지 않는다).
# 방식: 임시 디렉터리 픽스처(New-Fixture — 저장소에 픽스처 파일을 두지 않는다)에 트리를 만들고
#   bash <스크립트> --root <픽스처>로 부른다(PowerShell에서 bash로 넘기는 경로는 / 구분자로 바꾼다).
#   네트워크가 필요하다: kubeconform이 스키마를 내려받고, CRD의 "스키마 없음"(404)은 캐시되지 않아 매번 묻는다.
# 환경 변수:
#   KUBECONFORM_DEPLOY_SCRIPT  시험할 스크립트(기본 scripts/ci/kubeconform-deploy.sh) — 변이 시험에서 사본을 가리킬 때 쓴다.
#   KUBECONFORM_CACHE          kubeconform 스키마 캐시 — 주면 모든 실행에 그대로 넘기고 지우지 않는다. 없으면 이번 실행
#                              전용 임시 캐시를 만들고 끝에 지운다.
# 단언 이름의 번호 1–15는 지시서(T047 M1)의 실행 단언 번호다. d-*는 대상을 조용히 놓치는 경로(파일 이름 · 대소문자 ·
#   심볼릭 링크 · 공백 · 중복), t-*는 경보선의 변형(걸려야 할 것 · 걸리지 않아야 할 것), n-*는 스키마 판정의 보강(전부 건너뜀 ·
#   네트워크 실패 · 요약 줄 없음 — 가짜 kubeconform), r-1은 실제 저장소다.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptPath = if (-not [string]::IsNullOrEmpty($env:KUBECONFORM_DEPLOY_SCRIPT)) { $env:KUBECONFORM_DEPLOY_SCRIPT } else { Join-Path $repo 'scripts/ci/kubeconform-deploy.sh' }
$ciPath = Join-Path $repo '.github/workflows/ci.yml'
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:outputs = [Collections.Generic.List[string]]::new()   # 단언 15: 모든 실행의 stdout + stderr
$script:cacheDir = ''

# ---------- 도구 ----------
$localBin = Join-Path $repo '.superpowers/bin'
if (Test-Path -LiteralPath $localBin -PathType Container) { $env:PATH = $localBin + [IO.Path]::PathSeparator + $env:PATH }

# Git/POSIX bash를 찾는다(tests/infra/host-prep.tests.ps1과 같은 순서). WSL 런처(System32 · WindowsApps의 bash.exe)는 쓰지 않는다.
# Git의 bin\bash.exe를 먼저 고른다 — PATH 앞에 /usr/bin을 붙여 주므로 Git의 usr\bin이 PATH에 없는 콘솔에서도 셸 도구가 풀린다.
function Find-Bash {
    if ($IsWindows) {
        foreach ($c in @('C:\Program Files\Git\bin\bash.exe', 'C:\Program Files\Git\usr\bin\bash.exe')) { if (Test-Path -LiteralPath $c -PathType Leaf) { return $c } }
    }
    foreach ($cmd in @(Get-Command bash -CommandType Application -All -ErrorAction SilentlyContinue)) {
        if ($cmd.Source -and $cmd.Source -notmatch '(?i)[\\/](System32|WindowsApps)[\\/]') { return $cmd.Source }
    }
    return $null
}
$script:bash = Find-Bash
$missingTools = @()
if (-not $script:bash) { $missingTools += 'bash' }
foreach ($t in @('kustomize', 'kubeconform')) { if (-not (Get-Command $t -CommandType Application -ErrorAction SilentlyContinue)) { $missingTools += $t } }
if ($missingTools.Count -gt 0) {
    Write-Host "SKIP kubeconform-deploy tests -- not found: $($missingTools -join ', ') (PATH; on Windows a Git bash is required)"
    exit 0
}

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
function Test-Has([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }

# 줄 배열에 정확히(ordinal) 같은 줄 / 그 글자로 시작하는 줄이 있는지
function Test-HasLine([string[]]$lines, [string]$line) { foreach ($l in $lines) { if (Test-Same $l $line) { return $true } }; return $false }
function Test-HasLinePrefix([string[]]$lines, [string]$prefix) { foreach ($l in $lines) { if ($l.StartsWith($prefix, [StringComparison]::Ordinal)) { return $true } }; return $false }
function Get-LinesWithPrefix([string[]]$lines, [string]$prefix) { return ,@($lines | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }) }

function ConvertTo-BashPath([string]$p) { return ($p -replace '\\', '/') }

# 키 = 픽스처 루트 기준 상대 경로, 값 = 파일 내용(UTF-8, BOM 없음, 개행은 값 그대로). 키가 /로 끝나면 빈 디렉터리를 만든다.
# 경로는 글자 그대로 다룬다([IO.Directory] — {{pod_snake}} 같은 이름도 그대로).
function New-Fixture([hashtable]$files = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('kcdeploy-' + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($dir)
    $script:fixtures += $dir
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        if ($rel.EndsWith('/')) { [void][IO.Directory]::CreateDirectory($p); continue }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
        [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false))
    }
    return $dir
}

# 디렉터리 심볼릭 링크를 만든다. 만들 수 없으면(Windows: 개발자 모드 · 권한 없음) $false — 호출부가 SKIP 줄을 찍는다
function New-DirLink([string]$link, [string]$target) {
    try { New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Remove-Fixture {
    foreach ($f in $script:fixtures) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
    $script:fixtures = @()
}

# 픽스처 트리의 목록(상대 경로 · 크기 · SHA-256) — 스크립트가 --root 아래에 아무것도 쓰지 않는지 본다(단언 14)
function Get-TreeListing([string]$dir) {
    $items = foreach ($it in @(Get-ChildItem -LiteralPath $dir -Recurse -Force)) {
        $rel = [IO.Path]::GetRelativePath($dir, $it.FullName) -replace '\\', '/'
        if ($it.PSIsContainer) { "D $rel" } else { "F $rel $($it.Length) $((Get-FileHash -LiteralPath $it.FullName -Algorithm SHA256).Hash)" }
    }
    return (@($items | Sort-Object) -join "`n")
}

# 스크립트를 bash로 실행한다. 매 실행마다 스크립트 입력 환경 변수(KUBECONFORM_ROOT · KUBECONFORM_K8S_VERSION · GITHUB_ACTIONS)를
# 지우고 KUBECONFORM_CACHE를 이번 실행의 캐시로 둔 뒤 $envSet(이름 → 값, 빈 값이면 지움)을 덮어쓴다. 끝나면 반드시 원복한다.
#   $pathValue  빈 값이면 PATH 유지, 아니면 PATH 전체를 그 값으로 바꾼다
# stdout은 콘솔 코드 페이지와 무관하게 UTF-8로 디코드한다(호출 동안만 [Console]::OutputEncoding을 UTF-8로 — tofu.tests.ps1과 같은 방식).
function Invoke-Deploy([string[]]$scriptArgs = @(), [hashtable]$envSet = @{}, [string]$pathValue = '') {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        $r = @{ out = "<missing script: $scriptPath>"; err = ''; code = 127; lines = @() }
        $script:outputs.Add($r.out)
        return $r
    }
    $names = @('PATH', 'KUBECONFORM_ROOT', 'KUBECONFORM_K8S_VERSION', 'KUBECONFORM_CACHE', 'GITHUB_ACTIONS') + @($envSet.Keys)
    $saved = @{}
    foreach ($n in $names) { if (-not $saved.ContainsKey($n)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) } }
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('kcdeploy-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $prevEncoding = [Console]::OutputEncoding
    $out = @(); $code = -1
    try {
        foreach ($n in @('KUBECONFORM_ROOT', 'KUBECONFORM_K8S_VERSION', 'GITHUB_ACTIONS')) { [Environment]::SetEnvironmentVariable($n, $null) }
        [Environment]::SetEnvironmentVariable('KUBECONFORM_CACHE', $script:cacheDir)
        foreach ($k in $envSet.Keys) { [Environment]::SetEnvironmentVariable($k, [string]$envSet[$k]) }
        if (-not [string]::IsNullOrEmpty($pathValue)) { $env:PATH = $pathValue }
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $out = @(& $script:bash (ConvertTo-BashPath $scriptPath) @scriptArgs 2> $errFile)
        $code = $LASTEXITCODE
    } finally {
        [Console]::OutputEncoding = $prevEncoding
        foreach ($n in $saved.Keys) { [Environment]::SetEnvironmentVariable($n, $saved[$n]) }
    }
    $err = ''
    if (Test-Path -LiteralPath $errFile) {
        $err = [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8)
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    $lines = @($out | ForEach-Object { "$_" })
    $r = @{
        out   = ($lines -join "`n")
        err   = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code  = $code
        lines = $lines
    }
    $script:outputs.Add($r.out + "`n" + $r.err)
    return $r
}

# ---------- ci.yml 원문 읽기(YAML 파서 없이 줄 단위) ----------
# jobs: 아래 2칸 들여쓰기 job 하나의 줄(머리 줄 다음부터 다음 job · 최상위 키 전까지). 없으면 빈 배열.
function Get-JobBlock([string[]]$lines, [string]$job) {
    $inJobs = $false; $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^jobs:\s*$') { $inJobs = $true; continue }
        if ($inJobs -and $lines[$i] -match ('^  ' + [regex]::Escape($job) + ':\s*$')) { $start = $i + 1; break }
    }
    if ($start -lt 0) { return ,@() }
    $block = [Collections.Generic.List[string]]::new()
    for ($i = $start; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^ {0,2}\S') { break }
        $block.Add($lines[$i])
    }
    return ,$block.ToArray()
}

# job 블록의 run: 본문들 — 블록 스칼라(| 또는 >)는 더 깊이 들여쓴 다음 줄들, 한 줄 run은 그 값
function Get-RunBodies([string[]]$block) {
    $bodies = [Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $block.Count; $i++) {
        $m = [regex]::Match($block[$i], '^(\s*)(-\s+)?run:\s*(.*)$')
        if (-not $m.Success) { continue }
        $indent = $m.Groups[1].Value.Length + $m.Groups[2].Value.Length
        $rest = $m.Groups[3].Value
        if ($rest -match '^[|>]') {
            $sb = [Text.StringBuilder]::new()
            for ($j = $i + 1; $j -lt $block.Count; $j++) {
                $l = $block[$j]
                if ($l.Trim().Length -eq 0) { [void]$sb.Append("`n"); continue }
                if (($l.Length - $l.TrimStart().Length) -le $indent) { break }
                [void]$sb.Append($l + "`n")
            }
            $bodies.Add($sb.ToString())
        } else { $bodies.Add($rest) }
    }
    return ,$bodies.ToArray()
}

# ---------- 픽스처 조각 ----------
$yDeploy = @'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sample
  template:
    metadata:
      labels:
        app: sample
    spec:
      containers:
        - name: web
          image: registry.example.invalid/sample@sha256:0000000000000000000000000000000000000000000000000000000000000000
'@ + "`n"
$yService = @'
apiVersion: v1
kind: Service
metadata:
  name: sample
spec:
  selector:
    app: sample
  ports:
    - port: 80
      targetPort: 8000
'@ + "`n"
$yExternalSecret = @'
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: sample-env
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-dev
  target:
    name: sample-env
  dataFrom:
    - extract:
        key: dev/sample/env
'@ + "`n"
$yDeployBadReplicas = $yDeploy.Replace('replicas: 1', 'replicas: "two"')          # 타입 위반
$yDeployUnknownField = $yDeploy.Replace("  replicas: 1`n", "  replicas: 1`n  bogusField: true`n")   # -strict: 알 수 없는 필드
$yServiceBad = $yService.Replace('port: 80', 'port: "eighty"')
$yKust = "apiVersion: kustomize.config.k8s.io/v1beta1`nkind: Kustomization`nresources:`n  - deployment.yaml`n  - service.yaml`n"
$yKustEmpty = "apiVersion: kustomize.config.k8s.io/v1beta1`nkind: Kustomization`nresources: []`n"
$jinjaDeploy = "apiVersion: apps/v1`nkind: Deployment`nmetadata:`n  name: {{ pod_name }}`n"

# kustomize base 한 벌(kustomization + Deployment + Service)
function Get-Base([string]$prefix, [string]$deploy = $yDeploy, [string]$kustName = 'kustomization.yaml', [string]$service = $yService) {
    return @{
        "$prefix/$kustName"       = $yKust
        "$prefix/deployment.yaml" = $deploy
        "$prefix/service.yaml"    = $service
    }
}

try {
    # 이번 실행의 스키마 캐시
    if (-not [string]::IsNullOrEmpty($env:KUBECONFORM_CACHE)) { $script:cacheDir = ConvertTo-BashPath $env:KUBECONFORM_CACHE }
    else {
        $c = Join-Path ([IO.Path]::GetTempPath()) ('kcdeploy-cache-' + [guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($c)
        $script:fixtures += $c
        $script:cacheDir = ConvertTo-BashPath $c
    }

    # ---------- 정적: ci.yml 원문 + 스크립트 원문 ----------
    Test-Group 'static' {
        $ci = if (Test-Path -LiteralPath $ciPath -PathType Leaf) { [IO.File]::ReadAllText($ciPath) } else { '' }
        $ciLines = @($ci -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
        $job = Get-JobBlock $ciLines 'kubeconform'
        $jobText = $job -join "`n"
        $runs = Get-RunBodies $job
        $runLines = @(($runs -join "`n") -split "`n" | ForEach-Object { $_.Trim() })

        Assert 'static-1: ci.yml has job "kubeconform" under jobs:' ($job.Count -gt 0) "no '  kubeconform:' job found in $ciPath"

        $uses = @($ciLines | ForEach-Object { [regex]::Match($_, '^\s*(-\s+)?uses:\s*(\S+)') } | Where-Object { $_.Success } | ForEach-Object { $_.Groups[2].Value })
        $unpinned = @($uses | Where-Object { $_ -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+@[0-9a-f]{40}$' })
        $jobUses = @($job | Where-Object { $_ -match '^\s*(-\s+)?uses:' })
        Assert 'static-2: every uses: in ci.yml (including job kubeconform) is pinned to a full 40-hex commit SHA' ($uses.Count -gt 0 -and $jobUses.Count -ge 1 -and $unpinned.Count -eq 0) "unpinned: [$($unpinned -join ', ')]; uses total $($uses.Count), in job kubeconform $($jobUses.Count)"

        $exprRuns = @($runs | Where-Object { $_.Contains('${{') })
        Assert 'static-3: no run: body of job kubeconform contains ${{ (values reach run: only through env:)' ($job.Count -gt 0 -and $runs.Count -ge 2 -and $exprRuns.Count -eq 0) "run bodies: $($runs.Count); bodies with an expression: $($exprRuns.Count)"

        $pins = @(
            '^\s+KUSTOMIZE_VERSION:\s*v5\.8\.1\s*$',
            '^\s+KUSTOMIZE_SHA256:\s*0953ea3e476f66d6ddfcd911d750f5167b9365aa9491b2326398e289fef2c142\s*$',
            '^\s+KUBECONFORM_VERSION:\s*v0\.8\.0\s*$',
            '^\s+KUBECONFORM_SHA256:\s*1f53fc8e81258197a35e8603054162a5af1de8c5af13746c71ab680d9534ed87\s*$'
        )
        $missingPins = @()
        foreach ($p in $pins) { if (@($job | Where-Object { $_ -match $p }).Count -ne 1) { $missingPins += $p } }
        Assert 'static-4: job kubeconform pins kustomize v5.8.1 and kubeconform v0.8.0 with their linux arm64 sha256 values in env: (one line each)' ($job.Count -gt 0 -and $missingPins.Count -eq 0) "missing or duplicated: $($missingPins -join ' | ')"

        $install = @(
            'curl -fsSL --retry 3 --connect-timeout 10 --max-time 120',
            'sha256sum -c',
            '$RUNNER_TEMP/bin',
            'chmod 0755',
            '$GITHUB_PATH',
            'kustomize_${KUSTOMIZE_VERSION}_linux_arm64.tar.gz',
            'kubeconform-linux-arm64.tar.gz'
        )
        $missingInstall = @($install | Where-Object { -not (Test-Has ($runs -join "`n") $_) })
        $verChecks = @($runLines | Where-Object { $_ -match 'KUSTOMIZE_VERSION' -and $_ -match '(\$bin/kustomize|kustomize)"? version' }).Count + @($runLines | Where-Object { $_ -match 'KUBECONFORM_VERSION' -and $_ -match 'kubeconform"? -v' }).Count
        Assert 'static-5: the install step downloads with the pinned curl flags, verifies sha256sum -c, installs into $RUNNER_TEMP/bin, checks both versions and adds $GITHUB_PATH' ($job.Count -gt 0 -and $missingInstall.Count -eq 0 -and $verChecks -ge 2) "missing: [$($missingInstall -join ' | ')]; version-check lines: $verChecks"

        Assert 'static-6: job kubeconform runs exactly "bash scripts/ci/kubeconform-deploy.sh" (not wrapped) and has no continue-on-error' (
            (Test-HasLine $runLines 'bash scripts/ci/kubeconform-deploy.sh') -and -not (Test-Has $jobText 'continue-on-error')
        ) "run lines: [$($runLines -join ' / ')]"

        $permIdx = @(for ($i = 0; $i -lt $ciLines.Count; $i++) { if ($ciLines[$i] -match '^permissions:') { $i } })
        $permOk = $permIdx.Count -eq 1 -and (Test-Same $ciLines[$permIdx[0]] 'permissions:') -and ($permIdx[0] + 1 -lt $ciLines.Count) -and (Test-Same $ciLines[$permIdx[0] + 1] '  contents: read') -and (($permIdx[0] + 2 -ge $ciLines.Count) -or ($ciLines[$permIdx[0] + 2] -notmatch '^\s+\S'))
        $jobPerm = @($job | Where-Object { $_ -match '^\s+permissions:' })
        Assert 'static-7: workflow-level permissions is exactly "contents: read" and job kubeconform sets no permissions of its own' ($permOk -and $jobPerm.Count -eq 0 -and $job.Count -gt 0) "workflow permissions lines: $($permIdx.Count); job-level permissions lines: $($jobPerm.Count)"

        $absent = @(foreach ($n in @('gitleaks', 'lint', 'test')) { if (-not (Test-HasLine $ciLines "  ${n}:")) { $n } })
        Assert 'static-8: the existing jobs gitleaks, lint and test are still there' ($absent.Count -eq 0) "absent: $($absent -join ', ')"

        Assert 'static-9: job kubeconform: runs-on ubuntu-24.04-arm, timeout-minutes 10, checkout with persist-credentials: false, no secrets.*' (
            $jobText -match '(?m)^    runs-on: ubuntu-24\.04-arm\s*$' -and $jobText -match '(?m)^    timeout-minutes: 10(\s|$)' -and $jobText -match '(?m)^\s*(-\s+)?uses: actions/checkout@[0-9a-f]{40}' -and $jobText -match '(?m)^\s+persist-credentials: false\s*$' -and -not (Test-Has $jobText 'secrets.')
        ) "job block: [$jobText]"

        $bytes = if (Test-Path -LiteralPath $scriptPath -PathType Leaf) { [IO.File]::ReadAllBytes($scriptPath) } else { $null }
        $hasBom = $null -ne $bytes -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $src = if ($null -ne $bytes) { [Text.UTF8Encoding]::new($false).GetString($bytes) } else { '' }
        $srcLines = @($src -split "`n")
        Assert 'static-10: script has no BOM and no CR, starts with #!/usr/bin/env bash and has the line "set -euo pipefail"' (
            $null -ne $bytes -and -not $hasBom -and -not $src.Contains("`r") -and (Test-Same $srcLines[0] '#!/usr/bin/env bash') -and (Test-HasLine $srcLines 'set -euo pipefail')
        ) "script missing, BOM, CR, shebang or set line ($scriptPath)"
    }

    # ---------- 1: 빈 트리 → 대상 없음, exit 0 (GitHub Actions에서는 ::notice 한 줄) ----------
    Test-Group '1: empty tree' {
        $d = New-Fixture @{}
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '1: empty tree -> exit 0, a line starting "대상 없음", summary "결과: PASS · 대상 0 · 실패 0", no ::notice outside GitHub Actions' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음') -and (Test-HasLine $r.lines '결과: PASS · 대상 0 · 실패 0') -and -not (Test-HasLinePrefix $r.lines '::')
        ) (Format-Result $r)
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) @{ GITHUB_ACTIONS = 'true' }
        $notices = Get-LinesWithPrefix $r.lines '::notice'
        Assert '1b: same tree with GITHUB_ACTIONS=true -> exit 0 and exactly one "::notice" line that says 대상 없음' (
            $r.code -eq 0 -and $notices.Count -eq 1 -and (Test-Has $notices[0] '대상 없음')
        ) (Format-Result $r)
    }

    # ---------- 2: 올바른 pod base → PASS ----------
    Test-Group '2: valid pod base' {
        $d = New-Fixture (Get-Base 'apps/sample/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '2: apps/sample/deploy/base with kustomization + Deployment + Service -> exit 0, "[PASS] apps/sample/deploy/base — 객체 2개", summary PASS 1/0' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] apps/sample/deploy/base — 객체 2개') -and (Test-HasLine $r.lines '결과: PASS · 대상 1 · 실패 0')
        ) (Format-Result $r)
    }

    # ---------- 3: 스키마 위반(타입 · -strict 알 수 없는 필드) → FAIL ----------
    Test-Group '3: schema violations' {
        $d = New-Fixture (Get-Base 'apps/sample/deploy/base' $yDeployBadReplicas)
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $fl = Get-LinesWithPrefix $r.lines '[FAIL] apps/sample/deploy/base — '
        Assert '3a: Deployment spec.replicas: "two" -> exit 1, "[FAIL] apps/sample/deploy/base — 스키마 …" naming /spec/replicas, summary FAIL 1/1' (
            $r.code -eq 1 -and $fl.Count -eq 1 -and (Test-Has $fl[0] '— 스키마') -and (Test-Has $fl[0] '/spec/replicas') -and (Test-HasLine $r.lines '결과: FAIL · 대상 1 · 실패 1')
        ) (Format-Result $r)
        $d = New-Fixture (Get-Base 'apps/sample/deploy/base' $yDeployUnknownField)
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $fl = Get-LinesWithPrefix $r.lines '[FAIL] apps/sample/deploy/base — '
        Assert '3b: unknown field spec.bogusField (-strict) -> exit 1, one FAIL line for apps/sample/deploy/base naming bogusField' (
            $r.code -eq 1 -and $fl.Count -eq 1 -and (Test-Has $fl[0] 'bogusField')
        ) (Format-Result $r)
    }

    # ---------- 4: 렌더 실패(kustomization이 없는 파일을 가리킴) → FAIL ----------
    Test-Group '4: render failure' {
        $files = Get-Base 'apps/sample/deploy/base'
        $files['apps/sample/deploy/base/kustomization.yaml'] = $yKust + "  - missing.yaml`n"
        $d = New-Fixture $files
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '4: kustomization lists a file that does not exist -> exit 1, "[FAIL] apps/sample/deploy/base — 렌더 실패…" naming missing.yaml' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — 렌더 실패') -and (Test-Has $r.out 'missing.yaml') -and (Test-HasLine $r.lines '결과: FAIL · 대상 1 · 실패 1')
        ) (Format-Result $r)
    }

    # ---------- 5: 빈 렌더(resources: []) → FAIL (빈 입력은 kubeconform이 성공으로 끝난다) ----------
    Test-Group '5: empty render' {
        $d = New-Fixture @{ 'apps/sample/deploy/base/kustomization.yaml' = $yKustEmpty }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '5: kustomization with resources: [] renders nothing -> exit 1, "[FAIL] apps/sample/deploy/base — 빈 렌더…"' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — 빈 렌더') -and (Test-HasLine $r.lines '결과: FAIL · 대상 1 · 실패 1')
        ) (Format-Result $r)
    }

    # ---------- 6: pod 둘 중 하나만 위반 → PASS 줄 하나 · FAIL 줄 하나 · 요약 수 ----------
    Test-Group '6: two pods, one bad' {
        $d = New-Fixture ((Get-Base 'apps/good/deploy/base') + (Get-Base 'apps/bad/deploy/base' $yDeployBadReplicas))
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '6: one valid and one violating pod -> exit 1, "[PASS] apps/good/deploy/base — 객체 2개", one FAIL line for apps/bad, summary "결과: FAIL · 대상 2 · 실패 1"' (
            $r.code -eq 1 -and (Test-HasLine $r.lines '[PASS] apps/good/deploy/base — 객체 2개') -and (Get-LinesWithPrefix $r.lines '[FAIL] apps/bad/deploy/base — ').Count -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 1 -and (Test-HasLine $r.lines '결과: FAIL · 대상 2 · 실패 1')
        ) (Format-Result $r)
    }

    # ---------- 7: 경보선 — 템플릿에 배포 매니페스트가 있는데 --generated 없음 → FAIL ----------
    Test-Group '7: tripwire' {
        $d = New-Fixture @{ 'templates/django-pod/template/deploy/base/deployment.yaml.jinja' = $jinjaDeploy; 'templates/django-pod/copier.yml' = "_subdirectory: template`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $tw = Get-LinesWithPrefix $r.lines '[FAIL] templates/django-pod/template — '
        Assert '7: template/deploy/base/deployment.yaml.jinja without --generated -> exit 1, one FAIL line for templates/django-pod/template that names --generated and T072' (
            $r.code -eq 1 -and $tw.Count -eq 1 -and (Test-Has $tw[0] '--generated') -and (Test-Has $tw[0] 'T072') -and (Test-Has $tw[0] 'deploy/base/deployment.yaml.jinja') -and (Test-HasLine $r.lines '결과: FAIL · 대상 1 · 실패 1')
        ) (Format-Result $r)
    }

    # ---------- t: 경보선의 변형 — jinja 경로 · 대소문자 · 다른 디렉터리 이름(파일 이름 · 내용), 걸리지 않아야 할 파일 ----------
    Test-Group 't: tripwire variants' {
        $cases = @(
            @{ n = 't-1: jinja path segment template/{{pod_snake}}/deploy/job.yaml.jinja'; f = @{ 'templates/django-pod/template/{{pod_snake}}/deploy/job.yaml.jinja' = $jinjaDeploy } },
            @{ n = 't-2: case variant template/Deploy/base/deployment.yaml.jinja'; f = @{ 'templates/django-pod/template/Deploy/base/deployment.yaml.jinja' = $jinjaDeploy } },
            @{ n = 't-3: kustomization file name outside a deploy directory (template/k8s/kustomization.yaml.jinja)'; f = @{ 'templates/django-pod/template/k8s/kustomization.yaml.jinja' = "resources:`n  - web.yaml`n" } },
            @{ n = 't-4: manifest content (apiVersion: + kind: at line start) under another name (template/manifests/web.yaml.jinja)'; f = @{ 'templates/django-pod/template/manifests/web.yaml.jinja' = $jinjaDeploy } }
        )
        foreach ($c in $cases) {
            $d = New-Fixture $c.f
            $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
            Assert "$($c.n) -> exit 1, tripwire FAIL line" ($r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] templates/django-pod/template — ').Count -eq 1) (Format-Result $r)
        }
        $d = New-Fixture @{
            'templates/django-pod/template/.gitkeep'                        = ''
            'templates/django-pod/template/{{pod_snake}}/settings.py.jinja' = "kind = 'settings'`n"
            'templates/django-pod/template/compose.dev.yml.jinja'           = "services:`n  db:`n    image: postgres:18`n"
        }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 't-5: non-manifest template files (settings.py.jinja, compose.dev.yml.jinja, .gitkeep) -> no tripwire, exit 0, 대상 없음' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음') -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 0
        ) (Format-Result $r)
        # 디렉터리 규칙은 경로 성분 단위다 — 이름에 deploy가 들었을 뿐인 디렉터리(deployment_utils · redeploy)는 걸리지 않는다
        $d = New-Fixture @{
            'templates/django-pod/template/{{pod_snake}}/deployment_utils/helpers.py' = "def rollout():`n    return 'deploy'`n"
            'templates/django-pod/template/docs/redeploy/README.md'                   = "# redeploy notes`n"
        }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 't-7: directories whose names only contain "deploy" ({{pod_snake}}/deployment_utils/helpers.py, docs/redeploy/README.md) -> no tripwire (the rule matches a whole path component named deploy), exit 0, 대상 없음' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음') -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 0
        ) (Format-Result $r)
        $d = New-Fixture @{ 'templates/django-pod/template/.gitkeep' = ''; 'elsewhere/web.yaml.jinja' = $jinjaDeploy }
        if (-not (New-DirLink (Join-Path $d 'templates/django-pod/template/deploy') (Join-Path $d 'elsewhere'))) { Write-Host 'SKIP t-6 -- cannot create a directory symlink here; not counted' }
        else {
            $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
            Assert 't-6: template/deploy is a symlink (globstar does not descend into it) -> the link name still trips the wire: exit 1, tripwire FAIL line' (
                $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] templates/django-pod/template — ').Count -eq 1
            ) (Format-Result $r)
        }
    }

    # ---------- 8 · 9: --generated ----------
    Test-Group '8-9: --generated' {
        $tripFiles = @{ 'templates/django-pod/template/deploy/base/deployment.yaml.jinja' = $jinjaDeploy }
        $d = New-Fixture ($tripFiles + (Get-Base 'gen/sample-pod/deploy/base'))
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--generated', (ConvertTo-BashPath (Join-Path $d 'gen/sample-pod')))
        Assert '8: tripwire tree + --generated <valid output inside the root> -> exit 0, tripwire off, "[PASS] gen/sample-pod/deploy/base — 객체 2개"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] gen/sample-pod/deploy/base — 객체 2개') -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 0 -and (Test-HasLine $r.lines '결과: PASS · 대상 1 · 실패 0')
        ) (Format-Result $r)

        $d = New-Fixture $tripFiles
        $g = New-Fixture (Get-Base 'sample-pod/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--generated', (ConvertTo-BashPath (Join-Path $g 'sample-pod')))
        Assert '8b: --generated outside the root -> exit 0, printed with a label, not a path: "[PASS] <생성물 1: sample-pod>/deploy/base — 객체 2개"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] <생성물 1: sample-pod>/deploy/base — 객체 2개')
        ) (Format-Result $r)

        $d = New-Fixture @{ 'gen/nothing/README.md' = "no deploy here`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--generated', (ConvertTo-BashPath (Join-Path $d 'gen/nothing')))
        Assert '9: --generated <dir without deploy/base> -> exit 1, "[FAIL] gen/nothing/deploy/base — …"' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] gen/nothing/deploy/base — ').Count -eq 1
        ) (Format-Result $r)

        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--generated', (ConvertTo-BashPath (Join-Path $d 'gen/does-not-exist')))
        Assert '9b: --generated <nonexistent dir> -> exit 1, a FAIL line (not a pass, not 대상 없음)' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 1 -and -not (Test-HasLinePrefix $r.lines '대상 없음')
        ) (Format-Result $r)
    }

    # ---------- 10: 템플릿에 .gitkeep만 → 경보선 없음 ----------
    Test-Group '10: .gitkeep only' {
        $d = New-Fixture @{ 'templates/django-pod/template/.gitkeep' = ''; 'templates/django-pod/copier.yml' = "_subdirectory: template`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '10: templates/django-pod/template holds only .gitkeep -> no tripwire, exit 0, 대상 없음' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음') -and (Get-LinesWithPrefix $r.lines '[FAIL] ').Count -eq 0
        ) (Format-Result $r)
    }

    # ---------- 11: templates/django-pod/deploy/(과제 문면의 경로) ----------
    Test-Group '11: templates/django-pod/deploy' {
        $d = New-Fixture @{ 'templates/django-pod/deploy/service.yaml' = $yService }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '11: plain manifest in templates/django-pod/deploy/ -> checked as a file: exit 0, "[PASS] templates/django-pod/deploy/service.yaml — 객체 1개"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] templates/django-pod/deploy/service.yaml — 객체 1개')
        ) (Format-Result $r)
        $d = New-Fixture @{ 'templates/django-pod/deploy/service.yaml' = $yService; 'templates/django-pod/deploy/deployment.yml' = $yDeployBadReplicas }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '11b: a violating plain manifest there -> exit 1, "[FAIL] templates/django-pod/deploy/deployment.yml — …", the valid file still PASSes' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] templates/django-pod/deploy/deployment.yml — ').Count -eq 1 -and (Test-HasLine $r.lines '[PASS] templates/django-pod/deploy/service.yaml — 객체 1개')
        ) (Format-Result $r)
        $d = New-Fixture (Get-Base 'templates/django-pod/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '11c: a kustomization directory there is rendered, its files are not checked twice -> exit 0, "[PASS] templates/django-pod/deploy/base — 객체 2개", 대상 1' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] templates/django-pod/deploy/base — 객체 2개') -and (Test-HasLine $r.lines '결과: PASS · 대상 1 · 실패 0')
        ) (Format-Result $r)
        $d = New-Fixture @{ 'templates/django-pod/deploy/README.md' = "nothing to check`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '11d: templates/django-pod/deploy/ exists with nothing checkable -> exit 1 (not a silent 대상 없음)' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] templates/django-pod/deploy — ').Count -eq 1
        ) (Format-Result $r)
        $d = New-Fixture @{ 'templates/django-pod/deploy/notes.yaml' = "# comments only`n---`n# no objects here`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '11e: a plain manifest holding only comments and document separators -> exit 1, "[FAIL] templates/django-pod/deploy/notes.yaml — 빈 렌더…" (kubeconform alone exits 0 on it)' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] templates/django-pod/deploy/notes.yaml — 빈 렌더')
        ) (Format-Result $r)
    }

    # ---------- 12: 사용법 오류 · 도구 없음 → exit 2 ----------
    Test-Group '12: usage and missing tools' {
        $d = New-Fixture @{}
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--bogus')
        Assert '12: unknown argument -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $emptyBin = Join-Path $d 'emptybin'
        [void][IO.Directory]::CreateDirectory($emptyBin)
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) @{} $emptyBin
        Assert '12b: PATH holding only an empty directory (no kustomize, no kubeconform) -> exit 2, never 0 (fail closed)' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath (Join-Path $d 'no-such-dir')))
        Assert '12c: --root that does not exist -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Deploy @('--generated')
        Assert '12d: --generated without a value -> exit 2' ($r.code -eq 2) (Format-Result $r)
    }

    # ---------- 13 · n: 스키마가 없는 객체 ----------
    Test-Group '13: CRD and skipped objects' {
        $files = Get-Base 'apps/sample/deploy/base'
        $files['apps/sample/deploy/base/kustomization.yaml'] = $yKust + "  - externalsecret.yaml`n"
        $files['apps/sample/deploy/base/externalsecret.yaml'] = $yExternalSecret
        $d = New-Fixture $files
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert '13: ExternalSecret (external-secrets.io/v1, no schema) next to Deployment + Service -> exit 0, PASS line shows 객체 3개 and the skipped object: "건너뜀 1(ExternalSecret/sample-env)"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] apps/sample/deploy/base — 객체 3개 · 스키마 없어 건너뜀 1(ExternalSecret/sample-env)')
        ) (Format-Result $r)

        $d = New-Fixture @{ 'apps/sample/deploy/base/kustomization.yaml' = "resources:`n  - externalsecret.yaml`n"; 'apps/sample/deploy/base/externalsecret.yaml' = $yExternalSecret }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'n-1: every object skipped for lack of a schema (CRD only) -> exit 1, "[FAIL] … — 검증된 객체 0개 …" (a vacuous pass is not a pass)' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — 검증된 객체 0개')
        ) (Format-Result $r)

        $d = New-Fixture (Get-Base 'apps/sample/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) @{ KUBECONFORM_K8S_VERSION = '9.99.99' }
        Assert 'n-2: KUBECONFORM_K8S_VERSION with no schemas (9.99.99) -> every object skipped -> exit 1, 검증된 객체 0개 (not a silent PASS)' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — 검증된 객체 0개')
        ) (Format-Result $r)

        $proxy = 'http://127.0.0.1:9'
        $envNet = @{ HTTPS_PROXY = $proxy; HTTP_PROXY = $proxy; NO_PROXY = 'example.invalid'; KUBECONFORM_CACHE = '' }
        if (-not $IsWindows) { $envNet['https_proxy'] = $proxy; $envNet['http_proxy'] = $proxy; $envNet['no_proxy'] = 'example.invalid' }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) $envNet
        Assert 'n-3: schemas cannot be downloaded (proxy to a closed port, no cache) -> exit 1 with a FAIL line (not PASS, not 대상 없음)' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] apps/sample/deploy/base — ').Count -eq 1 -and -not (Test-HasLinePrefix $r.lines '[PASS] ')
        ) (Format-Result $r)
    }

    # ---------- n-4: kubeconform이 exit 0인데 요약 줄이 없다 → FAIL ----------
    # 가짜 kubeconform(입력을 읽어 버리고 아무것도 찍지 않고 exit 0 — -v는 입력을 읽지 않고 곧바로 exit 0)을 PATH 맨 앞에 둔다(12b처럼 PATH를
    # 바꾸되 나머지 PATH는 그대로 — kustomize는 진짜). 그 분기가 없으면 빈 렌더 분기가 대신 FAIL을 내므로 사유 문구까지 본다.
    Test-Group 'n-4: no kubeconform summary line' {
        $d = New-Fixture (Get-Base 'apps/sample/deploy/base')
        $fb = New-Fixture @{ 'kubeconform' = "#!/bin/sh`ncase `"`$1`" in -v) exit 0 ;; esac`nwhile read -r line; do :; done`nexit 0`n" }
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode((Join-Path $fb 'kubeconform'), [IO.UnixFileMode]'UserRead, UserWrite, UserExecute') }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) @{} ($fb + [IO.Path]::PathSeparator + $env:PATH)
        Assert 'n-4: kubeconform (fake, first on PATH) reads the input, prints nothing and exits 0 -> exit 1, "[FAIL] apps/sample/deploy/base — kubeconform의 요약 줄을 읽지 못했다…" (not PASS, not the 빈 렌더 fallback), summary FAIL 1/1' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — kubeconform의 요약 줄') -and (Get-LinesWithPrefix $r.lines '[PASS] ').Count -eq 0 -and (Test-HasLine $r.lines '결과: FAIL · 대상 1 · 실패 1')
        ) (Format-Result $r)
    }

    # ---------- d: 대상을 조용히 놓치는 경로 ----------
    Test-Group 'd: discovery' {
        $d = New-Fixture @{ 'apps/sample/deploy/base/deployment.yaml' = $yDeploy; 'apps/sample/deploy/base/service.yaml' = $yService }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'd-1: apps/<pod>/deploy/base without a kustomization file -> exit 1, "[FAIL] apps/sample/deploy/base — kustomization 파일 …" (not skipped)' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — kustomization 파일')
        ) (Format-Result $r)

        $d = New-Fixture ((Get-Base 'apps/sample/Deploy/base') + (Get-Base 'apps/other/deploy/Base'))
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $fl = Get-LinesWithPrefix $r.lines '[FAIL] apps/sample/Deploy — '
        $fl2 = Get-LinesWithPrefix $r.lines '[FAIL] apps/other/deploy/Base — '
        Assert 'd-2: case variants apps/sample/Deploy/base and apps/other/deploy/Base -> exit 1, one FAIL each naming the path and 대소문자, nothing PASSes (same on Windows and Linux)' (
            $r.code -eq 1 -and $fl.Count -eq 1 -and (Test-Has $fl[0] '대소문자') -and $fl2.Count -eq 1 -and (Test-Has $fl2[0] '대소문자') -and (Get-LinesWithPrefix $r.lines '[PASS] ').Count -eq 0
        ) (Format-Result $r)

        $d = New-Fixture (Get-Base 'apps/my pod/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'd-3: pod directory name with a space -> found and checked: exit 0, "[PASS] apps/my pod/deploy/base — 객체 2개"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] apps/my pod/deploy/base — 객체 2개')
        ) (Format-Result $r)

        $d = New-Fixture ((Get-Base 'apps/one/deploy/base' $yDeploy 'Kustomization') + (Get-Base 'apps/two/deploy/base' $yDeploy 'kustomization.yml'))
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'd-4: kustomization files named Kustomization and kustomization.yml are found too -> exit 0, both PASS, 대상 2' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] apps/one/deploy/base — 객체 2개') -and (Test-HasLine $r.lines '[PASS] apps/two/deploy/base — 객체 2개') -and (Test-HasLine $r.lines '결과: PASS · 대상 2 · 실패 0')
        ) (Format-Result $r)

        $d = New-Fixture (Get-Base 'apps/sample/deploy/k8s')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'd-5: apps/<pod>/deploy/ without deploy/base -> exit 1, "[FAIL] apps/sample/deploy — …" (not skipped)' (
            $r.code -eq 1 -and (Get-LinesWithPrefix $r.lines '[FAIL] apps/sample/deploy — ').Count -eq 1
        ) (Format-Result $r)

        # 심볼릭 링크 단언(d-6 · d-6b · t-6)은 링크를 만들 수 없는 환경에서는 SKIP 줄만 찍고 합계에 넣지 않는다
        $d = New-Fixture ((Get-Base 'real/base') + @{ 'apps/sample/deploy/' = '' })
        if (-not (New-DirLink (Join-Path $d 'apps/sample/deploy/base') (Join-Path $d 'real/base'))) { Write-Host 'SKIP d-6 -- cannot create a directory symlink here (Windows needs Developer Mode or the privilege); not counted' }
        else {
            $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
            Assert 'd-6: apps/<pod>/deploy/base is a symlink -> exit 1, "[FAIL] apps/sample/deploy/base — 심볼릭 링크 …" (not followed, not skipped)' (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy/base — 심볼릭 링크')
            ) (Format-Result $r)
        }
        $d = New-Fixture (Get-Base 'realapps/sample/deploy/base')
        if (-not (New-DirLink (Join-Path $d 'apps') (Join-Path $d 'realapps'))) { Write-Host 'SKIP d-6b -- cannot create a directory symlink here; not counted' }
        else {
            $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
            Assert 'd-6b: apps/ itself is a symlink (the glob would follow it) -> exit 1, "[FAIL] apps/sample/deploy — 심볼릭 링크 …", nothing PASSes' (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines '[FAIL] apps/sample/deploy — 심볼릭 링크') -and (Get-LinesWithPrefix $r.lines '[PASS] ').Count -eq 0
            ) (Format-Result $r)
        }

        $d = New-Fixture (Get-Base 'apps/sample/deploy/base')
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d), '--generated', (ConvertTo-BashPath (Join-Path $d 'apps/sample')))
        Assert 'd-7: --generated naming a pod that rule A already found -> checked once: exit 0, one line for apps/sample/deploy/base, 대상 1' (
            $r.code -eq 0 -and (Get-LinesWithPrefix $r.lines '[PASS] apps/sample/deploy/base — ').Count -eq 1 -and (Test-HasLine $r.lines '결과: PASS · 대상 1 · 실패 0')
        ) (Format-Result $r)

        $r = Invoke-Deploy @() @{ KUBECONFORM_ROOT = (ConvertTo-BashPath $d) }
        $r2 = Invoke-Deploy @('--root', (ConvertTo-BashPath $d)) @{ KUBECONFORM_ROOT = (ConvertTo-BashPath (Join-Path $d 'no-such-dir')) }
        Assert 'd-8: KUBECONFORM_ROOT selects the root when --root is absent, and --root wins over it' (
            $r.code -eq 0 -and (Test-HasLine $r.lines '[PASS] apps/sample/deploy/base — 객체 2개') -and $r2.code -eq 0 -and (Test-HasLine $r2.lines '[PASS] apps/sample/deploy/base — 객체 2개')
        ) ("env: " + (Format-Result $r) + " both: " + (Format-Result $r2))

        $d = New-Fixture @{ 'apps/README.md' = "pods`n"; 'apps/nodeploy/pyproject.toml' = "[project]`nname = 'nodeploy'`n" }
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        Assert 'd-9: pods without a deploy directory (like apps/identity-admin today) and files under apps/ -> exit 0, 대상 없음' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음')
        ) (Format-Result $r)
    }

    # ---------- 14: 멱등 — 같은 입력 두 번 → 같은 출력, --root 아래에 쓰지 않음 ----------
    Test-Group '14: idempotent' {
        $files = (Get-Base 'apps/good/deploy/base') + (Get-Base 'apps/bad/deploy/base' $yDeployBadReplicas 'kustomization.yaml' $yServiceBad)
        $files['apps/crd/deploy/base/kustomization.yaml'] = $yKust + "  - es-a.yaml`n  - es-b.yaml`n"
        $files['apps/crd/deploy/base/deployment.yaml'] = $yDeploy
        $files['apps/crd/deploy/base/service.yaml'] = $yService
        $files['apps/crd/deploy/base/es-a.yaml'] = $yExternalSecret.Replace('name: sample-env', 'name: zeta-env')
        $files['apps/crd/deploy/base/es-b.yaml'] = $yExternalSecret.Replace('name: sample-env', 'name: alpha-env')
        $d = New-Fixture $files
        $before = Get-TreeListing $d
        $r1 = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $r2 = Invoke-Deploy @('--root', (ConvertTo-BashPath $d))
        $after = Get-TreeListing $d
        Assert '14: same input twice (a PASS pod, a pod with two violations, a pod with two skipped CRDs) -> identical output and exit code, and nothing written under --root' (
            $r1.code -eq 1 -and $r2.code -eq 1 -and (Test-Same $r1.out $r2.out) -and (Test-Same $before $after) -and (Test-HasLinePrefix $r1.lines '[PASS] apps/crd/deploy/base — 객체 4개 · 스키마 없어 건너뜀 2(ExternalSecret/alpha-env, ExternalSecret/zeta-env)') -and (Test-HasLine $r1.lines '결과: FAIL · 대상 3 · 실패 1')
        ) ("run1: " + (Format-Result $r1) + " run2: " + (Format-Result $r2))
    }

    # ---------- r: 실제 저장소 루트 — 지금은 대상 없음 ----------
    # T072가 템플릿에 배포 매니페스트를 넣으면 이 단언은 경보선 때문에 깨진다(의도 — T072가 생성 단계를 연결하면서 이 단언도 고친다).
    Test-Group 'r: real repository root' {
        $r = Invoke-Deploy @('--root', (ConvertTo-BashPath $repo))
        Assert 'r-1: the real repository root today -> exit 0, "대상 없음", summary "결과: PASS · 대상 0 · 실패 0"' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '대상 없음') -and (Test-HasLine $r.lines '결과: PASS · 대상 0 · 실패 0')
        ) (Format-Result $r)
    }

    # ---------- 15: 출력에 절대 경로가 없다(모든 실행의 stdout + stderr) ----------
    Test-Group '15: no absolute paths' {
        $needles = [Collections.Generic.List[string]]::new()
        foreach ($f in $script:fixtures) { $needles.Add([IO.Path]::GetFileName($f.TrimEnd('\', '/'))) }
        $tmp = [IO.Path]::GetTempPath().TrimEnd('\', '/')
        foreach ($p in @($tmp, $repo)) {
            $needles.Add($p)
            $needles.Add(($p -replace '\\', '/'))
            if ($p -match '^([A-Za-z]):[\\/](.*)$') { $needles.Add('/' + $Matches[1].ToLowerInvariant() + '/' + ($Matches[2] -replace '\\', '/')) }
        }
        $hits = @()
        foreach ($o in $script:outputs) { foreach ($n in $needles) { if ($n -and $o.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += $n } } }
        Assert "15: no output of any run ($($script:outputs.Count) runs) contains an absolute path — fixture directories, the temp directory or the repository root, in POSIX or Windows form" (
            $script:outputs.Count -ge 30 -and $hits.Count -eq 0
        ) ('found: ' + (@($hits | Select-Object -Unique) -join ' | '))
    }
} finally {
    Remove-Fixture
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
