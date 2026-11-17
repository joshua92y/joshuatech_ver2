# scripts/ci/events-compat.sh 테스트(T067). Run: pwsh -NoProfile -File tests/scripts/events-compat.tests.ps1
# Exit 0 = all pass(또는 도구 없음 SKIP), 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/kubeconform-deploy.tests.ps1과 같은 구조).
#
# 도구가 없을 때 — 파일 전체 SKIP: bash(Git/POSIX bash — WSL의 System32 bash는 Windows 경로를 못 읽어 쓰지 않는다) · git · node 중
#   하나라도 없으면 첫 줄로 'SKIP events-compat tests -- not found: <없는 도구>'를 찍고 exit 0으로 끝난다. 정적 단언도 돌리지 않는다
#   (정적 단언만의 PASS가 실행 단언의 부재를 가리지 않게 — tests/run-all.ps1 1b5가 이 첫 줄만 SKIP으로 읽는다).
#   스크립트 부재는 SKIP이 아니다 — 실행 단언이 전부 FAIL한다(fail closed).
# 단언 하나만의 SKIP: 작업 트리의 심볼릭 링크 사례(ec-26b · ec-26c · ec-26f 로컬 · ec-26k 로컬 · ec-29g)는 실제 링크가 필요하다. 이
#   머신에서 링크를 만들 수 없으면(Windows에서 개발자 모드 · 권한 없음) 그 단언만 'SKIP <id> -- …' 줄을 찍고 통과로 세지 않는다(요약 줄
#   앞에 'N skipped' 줄이 더 붙는다).
# 진단(r3): 실패가 있으면 요약 줄 바로 앞에 'failed: <id>, …' 한 줄(로그가 잘려도 무엇이 깨졌는지 남는다). 시험 대상 실행이 종료 코드 -1에
#   stdout · stderr가 모두 비면(스크립트의 판정이 아니다 — 정상 종료 코드는 0 · 1 · 2뿐) 한 번 다시 부르고 'note: retried N spawn
#   failure(s) …' 줄로 센다(판정 단언은 그대로).
# 진단(r5 F28 · 리뷰 r4 B4-4): 시험 대상이 종료 코드 2 · stdout 없음 · stderr가 정확히 한 줄이고 그 줄이 스크립트의 --root git 위치 확인
#   die 두 문구(작업 트리가 아니다 · git 위치를 읽지 못했다) 가운데 하나와 같으면 한 번 다시 부르고 'note: retried N git-location
#   failure(s) …' 줄로 따로 센다 — Windows에서 시험 대상 자신의 git rev-parse가 드물게 실패한 꼴(r4 ec-7 · 1/38)이다. 그 두 문구를 기대하는
#   단언은 없고, 일부러 git 작업 트리가 아닌 디렉터리로 부르는 ec-16d는 다시 부르지 않는다(-NoLocationRetry). 다시 부르기 전에
#   GITHUB_STEP_SUMMARY를 첫 시도 전 상태로 되돌린다(스크립트의 EXIT trap은 일찍 멈춰도 요약 세 줄을 덧붙인다).
# 진단(r8 F40 · 리뷰 r7 R7-3): 픽스처 git(Invoke-Git)이 종료 코드 ≠ 0 · 출력(stdout + stderr 합)이 정확히 한 줄이고 그 줄이
#   「git: '<픽스처 git 경로>' is not a git command. See 'git --help'.」(경로는 구분자 \ · /와 대소문자를 가리지 않는다)이면 한 번 다시
#   부르고 'note: retried N fixture-git self-path failure(s) …' 줄로 따로 센다 — git은 하위 명령을 찾기 전에 끝나 픽스처를 바꾸지 않는다.
#   원인은 모른다(r4의 cmd 런처 전제는 r7에서 반증) · 판정과 무관한 거짓 FAIL만 낸다. 다른 줄이 더 있거나 경로가 다르거나 exit 0이면 다시
#   부르지 않는다.
# CI 모드(GITHUB_ACTIONS=true) 사례는 실제 CI처럼 변경 쪽을 커밋한 픽스처로 돈다 — CI에서는 변경 쪽을 HEAD 커밋에서 꺼내고 작업 트리
#   바이트가 그 blob과 같아야 하므로(r3 F10) 커밋하지 않은 작업 트리는 2가 된다(ec-29b · ec-29c가 그 갈래). 픽스처 저장소는
#   core.autocrlf false다(New-Repo).
# 방식: 실행마다 임시 git 저장소 픽스처를 만들고(저장소에 픽스처 파일을 두지 않는다) 저장소의 실제
#   packages/events/scripts/check-compat.mjs를 복사해 커밋한다. 스키마는 작은 합성 스키마다. PR은 git merge --no-ff로 만든 merge 커밋
#   (HEAD^1 = 기준 · HEAD^2 = PR head — GitHub의 PR merge ref와 같은 모양), push는 선형 커밋 두 개로 흉내 내고, 이벤트는 환경 변수
#   (GITHUB_EVENT_NAME · PR_HEAD_SHA · PUSH_BEFORE)로 준다. 픽스처에는 node_modules가 없다 — 검사기 CLI가 Node 내장 모듈만으로
#   도는지(기준 쪽 사본 실행 — contracts/events.md §호환성 규칙 「CI 기준과 검사기」)도 함께 증명된다.
#   기준 트리의 모양(심볼릭 링크 · 파일 · gitlink · 디렉터리인 .json)은 plumbing으로 만든다(임시 인덱스 + git hash-object -w +
#   git update-index --add --cacheinfo + git write-tree + git commit-tree — 작업 트리와 무관한 부모 없는 커밋을 --base로 준다).
#   손상된 기준(트리 객체 없음)은 느슨한 객체 파일을 지워 만든다.
#   git은 사용자 설정과 떨어져 돈다(GIT_CONFIG_NOSYSTEM=1 · GIT_CONFIG_GLOBAL=빈 파일 · GIT_DIR류 환경 변수 지움 · 픽스처마다
#   user.name/email · core.autocrlf false · commit.gpgsign false). 네트워크를 쓰지 않는다. 픽스처 git은 Windows에서 Git 설치의 실제
#   바이너리다(cmd 런처를 거치지 않는다 — r4 F22 · Resolve-FixtureGit · 시작 때 'info: fixture git = …' 한 줄). r4는 픽스처 git의
#   「git: '<제 경로>' is not a git command」 꼴을 cmd 런처 탓으로 봤지만 r7에서 실제 바이너리로도 재발했다 — 원인은 모르고, 판정과 무관한
#   거짓 FAIL만 낸다(그 꼴만 한 번 다시 부른다 — Invoke-Git · r8 F40).
#   스크립트는 bash <스크립트> --root <픽스처>로 부른다(PowerShell에서 bash로 넘기는 경로는 / 구분자로 바꾼다). 실행마다 TMPDIR을
#   그 실행 전용의 빈 디렉터리로 두고, 스크립트 입력 환경 변수(GITHUB_EVENT_NAME · PR_HEAD_SHA · PUSH_BEFORE · GITHUB_STEP_SUMMARY ·
#   GITHUB_ACTIONS · GITHUB_SHA)와 NODE_PATH · NODE_OPTIONS(r6 F30 — 게이트 job의 env처럼 없다: 픽스처 검사기가 Node 내장 모듈만으로
#   도는지의 증명이 물려받은 NODE_PATH로 흐려지지 않게)를 지운 뒤 사례가 주는 것만 둔다. 끝난 뒤 그 디렉터리와 시스템 임시 디렉터리에
#   남은 events-compat.* 항목을 센다(ec-14).
# 환경 변수:
#   EVENTS_COMPAT_SCRIPT  시험할 스크립트(기본 scripts/ci/events-compat.sh) — 변이 시험에서 사본을 가리킬 때 쓴다.
#   EVENTS_COMPAT_CI      정적 단언이 읽을 워크플로(기본 .github/workflows/ci.yml) — 변이 시험에서 사본을 가리킬 때 쓴다.
#   둘 중 하나라도 주면 요약 줄 끝에 ' (override: …)'가 붙어 tests/run-all.ps1 1b5의 판정을 통과하지 못한다(사본 실행이 전체 통과로
#   보이지 않게).
# 단언: ec-*는 실행 단언(build-notes 「T067」 D6 표 + r2 지시문 F2 · F3 · F4 + r3 지시문 F10 · F11 + r4 지시문 F19 · F20), st-*는
#   .github/workflows/ci.yml job events-compat · events-test와 스크립트 원문 · 저장소 .node-version의 정적 단언(YAML 파서 없이 줄 단위 —
#   Get-JobBlock · Get-Steps · r4 지시문 F17 · F18 · r5 지시문 F24 · F27 · r6 지시문 F31(st-3b --fail-if-no-match) · F33 · F34(st-11 ·
#   st-14 r6 문장) · r7 지시문 F36(Get-StepMap — 스텝 키 깊이의 with: · env:만 · st-5 job 블록 전체의 setup-node · node-version 키 줄 수)
#   · F37(st-11 · st-14 r7 문장 · events-test 주석) · r8 지시문 F39(st-11 · st-14 r8 범위 문장 — 줄 단위 드리프트 검사 · st-11
#   events-compat 주석의 좁힌 「꼴과 상관없이」 · NEL · LS · PS · 옛 「꼴과 상관없이」 문구)).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:EVENTS_COMPAT_SCRIPT)
$ciOverride = -not [string]::IsNullOrEmpty($env:EVENTS_COMPAT_CI)
$scriptPath = if ($scriptOverride) { $env:EVENTS_COMPAT_SCRIPT } else { Join-Path $repo 'scripts/ci/events-compat.sh' }
$ciPath = if ($ciOverride) { $env:EVENTS_COMPAT_CI } else { Join-Path $repo '.github/workflows/ci.yml' }
$checkerPath = Join-Path $repo 'packages/events/scripts/check-compat.mjs'
$script:pass = 0
$script:fail = 0
$script:skips = [Collections.Generic.List[string]]::new()       # 단언 하나만의 SKIP(통과로 세지 않는다)
$script:temps = [Collections.Generic.List[string]]::new()       # 끝에 지울 임시 디렉터리
$script:repos = [Collections.Generic.List[string]]::new()       # ec-15: 픽스처 저장소
$script:dirty = @{}                                             # ec-15: 작업 트리를 일부러 바꾼 픽스처 → 실행 전 git status
$script:outputs = [Collections.Generic.List[string]]::new()     # ec-20: 모든 실행의 stdout + stderr
$script:exempt = 0                                              # ec-20: node 적재 오류(구간 안)를 뺀 실행 수
$script:leftovers = [Collections.Generic.List[string]]::new()   # ec-14: 실행 뒤 남은 임시 항목
$script:tokens = [Collections.Generic.List[string]]::new()      # ec-13: 실행마다의 stop-commands 토큰
$script:runs = 0
$script:gitRetries = 0                                          # 픽스처 git이 exit -1(출력 없음)로 끝나 다시 부른 횟수
$script:gitSelfPathRetries = 0                                  # 픽스처 git이 「git: '<제 경로>' is not a git command」 한 줄(exit ≠ 0)로 끝나 다시 부른 횟수(r8 F40)
$script:compatRetries = 0                                       # 시험 대상 실행이 exit -1(stdout · stderr 없음)로 끝나 다시 부른 횟수
$script:locationRetries = 0                                     # 시험 대상이 --root git 위치 확인의 die 한 줄(exit 2)로 끝나 다시 부른 횟수(r5 F28)
$script:failedIds = [Collections.Generic.List[string]]::new()   # 실패한 단언 · 그룹의 id(요약 줄 바로 앞에 찍는다)

# ---------- 도구 ----------
# Git/POSIX bash를 찾는다(tests/scripts/kubeconform-deploy.tests.ps1과 같은 순서). WSL 런처(System32 · WindowsApps의 bash.exe)는 쓰지 않는다.
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
foreach ($t in @('git', 'node')) { if (-not (Get-Command $t -CommandType Application -ErrorAction SilentlyContinue)) { $missingTools += $t } }
if ($missingTools.Count -gt 0) {
    Write-Host "SKIP events-compat tests -- not found: $($missingTools -join ', ') (PATH; on Windows a Git bash is required)"
    exit 0
}

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; $script:failedIds.Add(($name -split ':', 2)[0]); Write-Host "FAIL $name -- $detail" }
}

# 단언 하나를 돌리지 못했다 — 통과로 세지 않고 이유를 남긴다
function Skip-Assert([string]$name, [string]$reason) {
    $script:skips.Add($name)
    Write-Host "SKIP $name -- $reason (not counted as passed)"
}

# 단언 그룹 격리. 한 그룹에서 예외가 나도 나머지 그룹은 계속 실행된다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; $script:failedIds.Add(($name -split ':', 2)[0]); Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Format-Result($r) { "out=[$($r.out)] err=[$($r.err)] [code=$($r.code)]" }

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-Has([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Test-HasLine([string[]]$lines, [string]$line) { foreach ($l in $lines) { if (Test-Same $l $line) { return $true } }; return $false }
function Test-HasLinePrefix([string[]]$lines, [string]$prefix) { foreach ($l in $lines) { if ($l.StartsWith($prefix, [StringComparison]::Ordinal)) { return $true } }; return $false }
# 줄 배열에서 needle을 담은 첫 줄의 번호(없으면 -1)
function Get-LineIndex([string[]]$lines, [string]$needle) { for ($i = 0; $i -lt $lines.Count; $i++) { if (Test-Has $lines[$i] $needle) { return $i } }; return -1 }

function ConvertTo-BashPath([string]$p) { return ($p -replace '\\', '/') }

# 환경 변수를 값으로 둔다 — $null · 빈 값이면 지운다. [Environment]::SetEnvironmentVariable($n, $null)은 쓰지 않는다: PowerShell이
# $null을 빈 문자열로 넘겨 '빈 값의 변수'가 남고(PowerShell 7.6 · .NET 10 실측), git은 빈 GIT_DIR을 오류로 본다.
function Set-EnvVar([string]$name, [string]$value) {
    if ([string]::IsNullOrEmpty($value)) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    else { Set-Item -LiteralPath "Env:$name" -Value $value }
}

# ---------- ci.yml 원문 읽기(YAML 파서 없이 줄 단위 — kubeconform-deploy.tests.ps1 · ci-gitleaks.tests.ps1과 같은 함수) ----------
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

# 줄 묶음의 run: 본문들 — 블록 스칼라(| 또는 >)는 더 깊이 들여쓴 다음 줄들, 한 줄 run은 그 값
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

# job 블록의 steps: 목록을 스텝마다 줄 배열로 나눈다 — '      - '(6칸 들여쓰기 목록 항목)가 스텝의 첫 줄이다(스텝 사이의 주석 줄은
# 앞 스텝에 붙는다 · 첫 스텝 앞의 주석은 버린다). steps: 밖의 job 키(4칸)에서 멈춘다.
function Get-Steps([string[]]$block) {
    $steps = [Collections.Generic.List[object]]::new()
    $inSteps = $false; $cur = $null
    foreach ($l in $block) {
        if ($l -match '^    steps:\s*$') { $inSteps = $true; continue }
        if (-not $inSteps) { continue }
        if ($l -match '^    \S') { break }
        if ($l -match '^      - ') {
            if ($null -ne $cur) { $steps.Add($cur.ToArray()) }
            $cur = [Collections.Generic.List[string]]::new()
        }
        if ($null -ne $cur) { $cur.Add($l) }
    }
    if ($null -ne $cur) { $steps.Add($cur.ToArray()) }
    return ,$steps.ToArray()
}

# 스텝의 종류: checkout · setup-node · pnpm-setup(액션) · gate · install · vitest(run 본문이 정확히 그 명령 — r6 F31: --fail-if-no-match 포함) ·
# 그 밖 uses:<액션> · run · other
function Get-StepKind([string[]]$step) {
    $text = $step -join "`n"
    $u = [regex]::Match($text, '(?m)^\s*(-\s+)?uses:\s*([^@\s]+)@')
    if ($u.Success) {
        switch -CaseSensitive ($u.Groups[2].Value) {
            'actions/checkout' { return 'checkout' }
            'actions/setup-node' { return 'setup-node' }
            'pnpm/action-setup' { return 'pnpm-setup' }
            default { return "uses:$($u.Groups[2].Value)" }
        }
    }
    $runs = Get-RunBodies $step
    if ($runs.Count -eq 1) {
        switch -CaseSensitive ($runs[0].Trim()) {
            'bash scripts/ci/events-compat.sh' { return 'gate' }
            'pnpm install --frozen-lockfile --ignore-scripts' { return 'install' }
            'pnpm --filter @jt/events --fail-if-no-match test' { return 'vitest' }
            default { return 'run' }
        }
    }
    return 'other'
}

# 스텝의 with: · env: 같은 매핑(키 → 값 문자열 · 주석 줄 제외). 키가 없으면 빈 표.
# r7 F36(리뷰 r6 R6-1 (c)): 키는 스텝 키 깊이(스텝 첫 줄에서 '- ' 다음 키가 시작하는 열)에서만 받는다 — env: 같은 다른 키 아래에 들여쓴
# with:는 그 스텝의 입력이 아니다(setup-node가 버전을 받지 못한다 · schemas.test.mjs sch-23과 같은 결속). 첫 줄이 '- ' 꼴이 아니면 빈 표.
function Get-StepMap([string[]]$step, [string]$key) {
    $map = [ordered]@{}
    $head = if ($step.Count -gt 0) { [regex]::Match($step[0], '^(\s*-\s+)') } else { $null }
    if ($null -eq $head -or -not $head.Success) { return $map }
    $depth = $head.Groups[1].Value.Length
    for ($i = 0; $i -lt $step.Count; $i++) {
        $m = [regex]::Match($step[$i], '^(\s*)(-\s+)?' + [regex]::Escape($key) + ':\s*$')
        if (-not $m.Success) { continue }
        $indent = $m.Groups[1].Value.Length + $m.Groups[2].Value.Length
        if ($indent -ne $depth) { continue }
        for ($j = $i + 1; $j -lt $step.Count; $j++) {
            $l = $step[$j]
            if ($l.Trim().Length -eq 0 -or $l.TrimStart().StartsWith('#')) { continue }
            if (($l.Length - $l.TrimStart().Length) -le $indent) { break }
            $kv = [regex]::Match($l, '^\s+([A-Za-z0-9_-]+):\s*(.*?)\s*$')
            if ($kv.Success) { $map[$kv.Groups[1].Value] = $kv.Groups[2].Value }
        }
    }
    return $map
}

function Format-Map($map) { return (@($map.Keys | ForEach-Object { "$_=$($map[$_])" }) -join ', ') }

# 정적 단언용 job 요약 — 블록 · 본문 · 스텝 · 스텝 종류 · run 본문
function Get-JobInfo([string[]]$ciLines, [string]$name) {
    $block = Get-JobBlock $ciLines $name
    $steps = Get-Steps $block
    $kinds = @(foreach ($s in $steps) { Get-StepKind $s })
    return @{ block = $block; text = ($block -join "`n"); steps = $steps; kinds = $kinds; runs = (Get-RunBodies $block) }
}

# job의 첫 kind 스텝(줄 배열 — 없으면 빈 배열)
function Find-Step($job, [string]$kind) {
    for ($i = 0; $i -lt $job.kinds.Count; $i++) { if (Test-Same $job.kinds[$i] $kind) { return ,$job.steps[$i] } }
    return ,@()
}

# ---------- 픽스처: 임시 git 저장소 ----------
function New-TempDir([string]$prefix) {
    $d = Join-Path ([IO.Path]::GetTempPath()) ($prefix + [guid]::NewGuid().ToString('N'))
    [void][IO.Directory]::CreateDirectory($d)
    $script:temps.Add($d)
    return $d
}

# 픽스처 git(r4 F22 · 리뷰 r3 B3-2): Windows에서는 PATH의 git(Git 설치의 cmd/git.exe 런처)을 거치지 않고 설치의 실제 바이너리
# <prefix>/bin/git.exe(git --exec-path = <prefix>/libexec/git-core)를 부른다. r4는 픽스처 git이 드물게 제 경로를 하위 명령으로 받은
# 꼴(exit 1 · "git: '…/mingw64/bin/git.exe' is not a git command")로 끝나 그 그룹이 거짓 FAIL한 것(리뷰 4회 중 1회)을 런처 탓으로 보고
# 이렇게 바꿨지만, r7에서 이 실제 바이너리로도 재발했다(final-slot-1b5-2 · git add -A) — cmd 런처 탓이 아니고 원인은 모른다. 저장소
# 상태를 바꾸지 않고 거짓 FAIL만 내므로 Invoke-Git이 그 꼴만 한 번 다시 부른다(r8 F40 · Test-GitSelfPathFailure). 그 바이너리가
# 있고 --version 출력이 PATH의 git과 같을 때만 쓰고, 아니면(또는 Windows가 아니면) PATH의 git이다. 시험 대상 스크립트의 git(bash의
# PATH)은 바꾸지 않는다. 어느 쪽인지 시작 때 정보 줄 하나로 찍는다(절대 경로 없이 — <prefix 끝 이름>/bin/git.exe).
function Resolve-FixtureGit {
    if (-not $IsWindows) { return @{ exe = 'git'; label = 'git from PATH (not Windows)' } }
    $execPath = @(& git --exec-path 2>$null)
    if ($LASTEXITCODE -ne 0 -or $execPath.Count -ne 1) { return @{ exe = 'git'; label = 'git from PATH (git --exec-path failed)' } }
    $m = [regex]::Match(([string]$execPath[0]).Trim().Replace([string][char]0x5c, '/'), '^(.+)/libexec/git-core/?$')
    if (-not $m.Success) { return @{ exe = 'git'; label = 'git from PATH (git --exec-path is not <prefix>/libexec/git-core)' } }
    $prefix = $m.Groups[1].Value
    $candidate = "$prefix/bin/git.exe"
    $shown = "$([IO.Path]::GetFileName($prefix))/bin/git.exe"
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return @{ exe = 'git'; label = "git from PATH ($shown not found)" } }
    $pathVersion = (@(& git --version 2>$null) -join "`n").Trim()
    $candidateVersion = (@(& $candidate --version 2>$null) -join "`n").Trim()
    if ($pathVersion.Length -eq 0 -or -not (Test-Same $pathVersion $candidateVersion)) { return @{ exe = 'git'; label = "git from PATH ($shown --version differs)" } }
    return @{ exe = $candidate; label = "$shown (the Git install's binary with the same --version as PATH git — not the cmd launcher)" }
}
$fixtureGitInfo = Resolve-FixtureGit
$script:fixtureGit = $fixtureGitInfo.exe
Write-Host "info: fixture git = $($fixtureGitInfo.label)"

# r8 F40(리뷰 r7 R7-3): 픽스처 git이 제 경로를 하위 명령으로 받은 꼴인가 — 종료 코드 ≠ 0 · 출력(stdout + stderr 합)이 정확히 한 줄 · 그
# 줄이 "git: '<경로>' is not a git command. See 'git --help'."와 같고 <경로>가 픽스처 git 경로다(구분자 \ · /와 대소문자를 가리지 않는다).
# 그 밖(다른 줄이 하나라도 더 있음 · 다른 경로 · exit 0)은 $false — 다시 부르지 않는다.
function Test-GitSelfPathFailure([int]$code, [object[]]$out) {
    if ($code -eq 0 -or $out.Count -ne 1) { return $false }
    $m = [regex]::Match([string]$out[0], "\Agit: '(.+)' is not a git command\. See 'git --help'\.\z")
    if (-not $m.Success) { return $false }
    $slash = [string][char]0x5c
    return [string]::Equals($m.Groups[1].Value.Replace($slash, '/'), ([string]$script:fixtureGit).Replace($slash, '/'), [StringComparison]::OrdinalIgnoreCase)
}

# git -C <dir> <인자> — 실패하면 예외(그 그룹의 FAIL). stdout을 한 문자열로(앞뒤 공백 제거) 돌려준다.
# 픽스처 준비용이다(시험 대상 스크립트의 git은 bash 안에서 돈다 · 픽스처 git은 위 Resolve-FixtureGit). exit -1에 출력이 없으면(git이 내는
# 종료 코드가 아니다 — 프로세스가 돌지 못했다) 두 번까지 다시 부른다: Windows · Git Bash에서 하네스 약 18회 중 2회 관찰(checkout ·
# commit-tree), 같은 꼴의 git 1680회 단독 반복으로는 재현되지 않았다. 다시 부른 횟수는 요약 줄 앞에 찍는다.
# r8 F40(리뷰 r7 R7-3): 종료 코드 ≠ 0 · 출력이 정확히 한 줄 「git: '<픽스처 git 경로>' is not a git command. See 'git --help'.」
# (Test-GitSelfPathFailure)이면 한 번 다시 부르고 따로 센다. git이 하위 명령을 찾기 전에 끝난 꼴이라 저장소 상태를 바꾸지 않는다(리뷰 r7
# 확인). 원인은 모른다 — cmd 런처 탓이 아니다(r7에서 실제 바이너리로도 재발 · git add -A · 하네스 · 슬롯 10회 중 1회). 판정과 무관한
# 거짓 FAIL만 낸다. 그 밖의 실패는 그대로 예외다(다른 꼴에는 재시도를 넓히지 않는다).
function Invoke-Git([string]$dir, [string[]]$gitArgs) {
    $spawnRetries = 0; $selfPathRetried = $false
    for ($attempt = 1; ; $attempt++) {
        $out = @(& $script:fixtureGit -C $dir @gitArgs 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        if ($code -eq -1 -and $out.Count -eq 0 -and $spawnRetries -lt 2) { $spawnRetries++; $script:gitRetries++; continue }
        if (-not $selfPathRetried -and (Test-GitSelfPathFailure $code $out)) { $selfPathRetried = $true; $script:gitSelfPathRetries++; continue }
        break
    }
    if ($code -ne 0) { throw "git $($gitArgs -join ' ') (exit $code, attempt $attempt): $($out -join ' | ')" }
    return ($out -join "`n").Trim()
}

function New-Repo {
    $d = New-TempDir 'evcompat-repo-'
    [void](Invoke-Git $d @('init', '-q', '-b', 'main'))
    [void](Invoke-Git $d @('config', 'user.name', 'events-compat test'))
    [void](Invoke-Git $d @('config', 'user.email', 'events-compat@example.invalid'))
    [void](Invoke-Git $d @('config', 'core.autocrlf', 'false'))
    [void](Invoke-Git $d @('config', 'commit.gpgsign', 'false'))
    $script:repos.Add($d)
    return $d
}

# 키 = 저장소 루트 기준 상대 경로, 값 = 내용(UTF-8 · BOM 없음 · 값 그대로). 값이 $null이면 지운다(디렉터리면 통째로).
function Set-RepoFiles([string]$dir, [hashtable]$files) {
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        if ($null -eq $files[$rel]) {
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
            continue
        }
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
        [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false))
    }
}

function Save-Commit([string]$dir, [string]$message) {
    [void](Invoke-Git $dir @('add', '-A'))
    [void](Invoke-Git $dir @('commit', '-q', '--allow-empty', '-m', $message))
    return (Invoke-Git $dir @('rev-parse', 'HEAD'))
}

# PR: main = README(+ 기준 파일) 커밋 → pr 브랜치에서 변경 커밋 → main에서 git merge --no-ff pr. HEAD = merge 커밋(HEAD^1 = 기준 · HEAD^2 = PR head)
function New-PrRepo([hashtable]$baseFiles, [hashtable]$prFiles) {
    $d = New-Repo
    Set-RepoFiles $d (@{ 'README.md' = "events-compat fixture`n" } + $baseFiles)
    [void](Save-Commit $d 'base')
    [void](Invoke-Git $d @('checkout', '-q', '-b', 'pr'))
    Set-RepoFiles $d $prFiles
    $prSha = Save-Commit $d 'pr'
    [void](Invoke-Git $d @('checkout', '-q', 'main'))
    [void](Invoke-Git $d @('merge', '-q', '--no-ff', '--no-edit', '-m', 'merge pr', 'pr'))
    return @{ dir = $d; pr = $prSha; base = (Invoke-Git $d @('rev-parse', 'HEAD^1')); head = (Invoke-Git $d @('rev-parse', 'HEAD')) }
}

# push: 선형 커밋 before → head(HEAD)
function New-PushRepo([hashtable]$beforeFiles, [hashtable]$afterFiles) {
    $d = New-Repo
    Set-RepoFiles $d (@{ 'README.md' = "events-compat fixture`n" } + $beforeFiles)
    $before = Save-Commit $d 'before'
    Set-RepoFiles $d $afterFiles
    $head = Save-Commit $d 'after'
    return @{ dir = $d; before = $before; head = $head }
}

# 기준 커밋을 plumbing으로 만든다 — 작업 트리 · 인덱스와 무관(임시 인덱스 파일). 항목 = @{ path; mode; content }:
#   100644 · 120000 = content를 blob으로(120000은 심볼릭 링크의 대상 글자) · 160000 = content는 커밋 ID(gitlink).
# 부모 없는 커밋 ID를 돌려준다 — 스크립트에는 --base로 준다.
function New-PlumbingCommit([string]$dir, [object[]]$entries) {
    $tmp = New-TempDir 'evcompat-plumb-'
    $index = Join-Path $tmp 'index'
    try {
        Set-EnvVar 'GIT_INDEX_FILE' $index
        $n = 0
        foreach ($e in $entries) {
            if (Test-Same $e.mode '160000') { $oid = $e.content }
            else {
                $blobFile = Join-Path $tmp "blob-$n"
                $n++
                [IO.File]::WriteAllText($blobFile, [string]$e.content, [Text.UTF8Encoding]::new($false))
                $oid = Invoke-Git $dir @('hash-object', '-w', '--no-filters', '--', $blobFile)
            }
            [void](Invoke-Git $dir @('update-index', '--add', '--cacheinfo', "$($e.mode),$oid,$($e.path)"))
        }
        $tree = Invoke-Git $dir @('write-tree')
    } finally { Set-EnvVar 'GIT_INDEX_FILE' $null }
    return (Invoke-Git $dir @('commit-tree', $tree, '-m', 'plumbing base'))
}

# 느슨한 객체 파일을 지워 그 객체를 읽을 수 없게 만든다(손상된 기준) — 지운 뒤에도 읽히면(팩에 있으면) 예외
function Remove-LooseObject([string]$dir, [string]$oid) {
    $file = Join-Path $dir (".git/objects/{0}/{1}" -f $oid.Substring(0, 2), $oid.Substring(2))
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "loose object file not found for $oid" }
    Remove-Item -LiteralPath $file -Force
    $null = @(& $script:fixtureGit -C $dir cat-file -e $oid 2>&1)
    if ($LASTEXITCODE -eq 0) { throw "object $oid is still readable after deleting its loose file" }
}

# 심볼릭 링크(디렉터리 · 파일)를 만든다 — 실패하면(권한 · 개발자 모드 없음) ok = $false와 사유
function New-SymLink([string]$link, [string]$target) {
    try {
        [void](New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop)
        return @{ ok = $true; reason = '' }
    } catch { return @{ ok = $false; reason = $_.Exception.Message } }
}

# 다음 커밋의 인덱스 항목 하나를 plumbing으로 둔다(작업 트리와 무관 — git hash-object -w + git update-index --add --cacheinfo).
# mode 120000이면 content는 심볼릭 링크의 대상 글자다.
function Set-IndexEntry([string]$dir, [string]$path, [string]$mode, [string]$content) {
    $blobFile = Join-Path (New-TempDir 'evcompat-blob-') 'blob'
    [IO.File]::WriteAllText($blobFile, $content, [Text.UTF8Encoding]::new($false))
    $oid = Invoke-Git $dir @('hash-object', '-w', '--no-filters', '--', $blobFile)
    [void](Invoke-Git $dir @('update-index', '--add', '--cacheinfo', "$mode,$oid,$path"))
}

# CI 모드 실행 환경 — 이벤트 변수에 GITHUB_ACTIONS=true · GITHUB_SHA(= HEAD 커밋)를 더한다
function Add-CiEnv([hashtable]$envSet, [string]$headSha) { return ($envSet + @{ GITHUB_ACTIONS = 'true'; GITHUB_SHA = $headSha }) }

function Get-RepoStatus([string]$dir) { return (Invoke-Git $dir @('status', '--porcelain', '--ignored', '--untracked-files=all')) }

# 스크립트를 bash로 실행한다. 매 실행마다 스크립트 입력 환경 변수(GITHUB_EVENT_NAME · PR_HEAD_SHA · PUSH_BEFORE ·
# GITHUB_STEP_SUMMARY · GITHUB_ACTIONS · GITHUB_SHA)와 NODE_PATH · NODE_OPTIONS(r6 F30 · 리뷰 r5 R5-1 (d) — 게이트 job의 env와 같게: 그
# job에는 둘 다 없고, 물려받은 NODE_PATH는 픽스처의 기준 쪽 검사기가 node_modules 없이 도는지의 증명을 흐린다)를 지우고 TMPDIR을 이 실행
# 전용의 빈 디렉터리로 둔 뒤 $envSet(이름 → 값, 빈 값이면 지움)을 덮어쓴다. 끝나면 반드시 원복한다(Windows의 Env: 드라이브는 이름의
# 대소문자를 가리지 않는다).
#   $pathValue    빈 값이면 PATH 유지, 아니면 PATH 전체를 그 값으로 바꾼다
#   -LoaderError  node가 검사기를 적재하지 못하는 사례 — 그 오류 · 스택(stop-commands 구간 안)에는 임시 디렉터리의 절대 경로가 있다
#                 (스크립트 머리 주석의 예외). ec-20은 그 실행에서 구간 밖의 줄과 stderr만 본다.
# stdout은 콘솔 코드 페이지와 무관하게 UTF-8로 디코드한다(호출 동안만 [Console]::OutputEncoding을 UTF-8로).
# 종료 코드 -1에 stdout · stderr가 모두 비면 한 번만 다시 부른다 — 스크립트의 정상 종료 코드는 0 · 1 · 2뿐이라 -1은 시험 대상의 판정이
# 아니다(프로세스가 돌지 못했다 · 픽스처 git의 같은 현상은 Invoke-Git 주석). 다시 부른 횟수는 요약 줄 앞의 note 줄로 센다.
# r5 F28(리뷰 r4 B4-4): 종료 코드 2 · stdout 없음 · stderr가 정확히 한 줄이고 그 줄이 $script:locationDies 가운데 하나(스크립트의 --root
# git 위치 확인 die — 접두 · 접미 포함 전체 줄)이면 그것도 한 번만 다시 부르고 따로 센다. 시험 대상 자신의 git rev-parse가 Windows에서
# 드물게 실패한 꼴이다(r4 ec-7 — 스크립트가 그 git의 stderr를 버려 원인은 알 수 없다). 이 두 문구를 기대하는 단언은 없다. 일부러 git 작업
# 트리가 아닌 디렉터리로 부르는 사례(ec-16d)는 -NoLocationRetry로 다시 부르지 않는다. 다른 꼴에는 재시도를 넓히지 않는다. 어느 재시도든
# 다시 부르기 전에 GITHUB_STEP_SUMMARY를 첫 시도 전 상태로 되돌린다(Reset-StepSummary — 다시 부른 실행만 남는다).
#   -NoLocationRetry  위 git 위치 재시도를 하지 않는다(그 die가 사례의 기대 결과일 때)
$script:locationDies = @(
    'events-compat: 루트가 git 작업 트리가 아니다(--root) — 검사하지 못했으므로 통과가 아니다(exit 2)',
    'events-compat: 루트의 git 위치를 읽지 못했다(--root) — 검사하지 못했으므로 통과가 아니다(exit 2)'
)
function Test-LocationDie([int]$code, [object[]]$out, [string]$err) {
    if ($code -ne 2 -or $out.Count -gt 0) { return $false }
    $e = $err -replace "`r`n", "`n"
    if ($e.EndsWith("`n")) { $e = $e.Substring(0, $e.Length - 1) }
    if ($e.Contains("`n")) { return $false }
    foreach ($d in $script:locationDies) { if (Test-Same $e $d) { return $true } }
    return $false
}
# 다시 부르기 전에 GITHUB_STEP_SUMMARY 파일을 첫 시도 전 바이트로 되돌린다(없었으면 지운다) — 스크립트의 EXIT trap은 일찍 멈춰도 요약 세
# 줄을 덧붙이므로, 되돌리지 않으면 실패한 시도의 줄이 남아 ec-12(정확히 세 줄)가 거짓 FAIL한다(r5 F28 시뮬레이션 SIM2에서 관찰). 그 die
# 지점까지 스크립트가 남기는 것은 이것뿐이다(작업 디렉터리는 그 뒤에 만든다).
function Reset-StepSummary([string]$path, [byte[]]$before) {
    if ([string]::IsNullOrEmpty($path)) { return }
    if ($null -ne $before) { [IO.File]::WriteAllBytes($path, $before) }
    elseif (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
function Invoke-Compat([string[]]$scriptArgs = @(), [hashtable]$envSet = @{}, [string]$pathValue = '', [switch]$LoaderError, [switch]$NoLocationRetry) {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        $r = @{ out = "<missing script: $scriptPath>"; err = ''; code = 127; lines = @() }
        $script:outputs.Add($r.out)
        return $r
    }
    $inputs = @('GITHUB_EVENT_NAME', 'PR_HEAD_SHA', 'PUSH_BEFORE', 'GITHUB_STEP_SUMMARY', 'GITHUB_ACTIONS', 'GITHUB_SHA', 'NODE_PATH', 'NODE_OPTIONS')
    $sysTmp = [IO.Path]::GetTempPath()
    $runTmp = New-TempDir 'evcompat-tmp-'
    $sysBefore = @(Get-ChildItem -LiteralPath $sysTmp -Filter 'events-compat.*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $names = @('PATH', 'TMPDIR') + $inputs + @($envSet.Keys)
    $saved = @{}
    foreach ($n in $names) { if (-not $saved.ContainsKey($n)) { $saved[$n] = [Environment]::GetEnvironmentVariable($n) } }
    $errFile = Join-Path $sysTmp ('evcompat-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $prevEncoding = [Console]::OutputEncoding
    $out = @(); $code = -1; $err = ''
    try {
        foreach ($n in $inputs) { Set-EnvVar $n $null }
        Set-EnvVar 'TMPDIR' (ConvertTo-BashPath $runTmp)
        foreach ($k in $envSet.Keys) { Set-EnvVar $k ([string]$envSet[$k]) }
        if (-not [string]::IsNullOrEmpty($pathValue)) { $env:PATH = $pathValue }
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $summaryPath = [string]$envSet['GITHUB_STEP_SUMMARY']
        $summaryBefore = if ($summaryPath -and (Test-Path -LiteralPath $summaryPath -PathType Leaf)) { [IO.File]::ReadAllBytes($summaryPath) } else { $null }
        $spawnRetried = $false; $locationRetried = $false
        while ($true) {
            $out = @(& $script:bash (ConvertTo-BashPath $scriptPath) @scriptArgs 2> $errFile)
            $code = $LASTEXITCODE
            $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
            if (-not $spawnRetried -and $code -eq -1 -and $out.Count -eq 0 -and $err.Length -eq 0) { $spawnRetried = $true; $script:compatRetries++; Reset-StepSummary $summaryPath $summaryBefore; continue }
            if (-not $locationRetried -and -not $NoLocationRetry -and (Test-LocationDie $code $out $err)) { $locationRetried = $true; $script:locationRetries++; Reset-StepSummary $summaryPath $summaryBefore; continue }
            break
        }
    } finally {
        [Console]::OutputEncoding = $prevEncoding
        foreach ($n in $saved.Keys) { Set-EnvVar $n $saved[$n] }
    }
    if (Test-Path -LiteralPath $errFile) { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
    $script:runs++
    $left = @(Get-ChildItem -LiteralPath $runTmp -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    $sysNew = @(Get-ChildItem -LiteralPath $sysTmp -Filter 'events-compat.*' -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $sysBefore -notcontains $_ })
    if ($left.Count -gt 0 -or $sysNew.Count -gt 0) { $script:leftovers.Add("run $($script:runs) ($($scriptArgs -join ' ')): TMPDIR [$($left -join ', ')] system temp [$($sysNew -join ', ')]") }
    $lines = @($out | ForEach-Object { "$_" })
    $r = @{
        out   = ($lines -join "`n")
        err   = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code  = $code
        lines = $lines
    }
    if ($LoaderError) {
        $region = Get-StopRegion $lines
        $outside = if ($null -ne $region) { @($lines | Select-Object -First ($region.open + 1)) + @($lines | Select-Object -Skip $region.close) } else { $lines }
        $script:outputs.Add(($outside -join "`n") + "`n" + $r.err)
        $script:exempt++
    } else {
        $script:outputs.Add($r.out + "`n" + $r.err)
    }
    return $r
}

# stop-commands 구간: '::stop-commands::<토큰>' 줄 하나와 그 뒤 '::<토큰>::' 줄 하나 — 없거나 짝이 안 맞으면 $null
function Get-StopRegion([string[]]$lines) {
    $opens = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^::stop-commands::(.+)$') { $i } })
    if ($opens.Count -ne 1) { return $null }
    $token = ([regex]::Match($lines[$opens[0]], '^::stop-commands::(.+)$')).Groups[1].Value
    $closes = @(for ($i = 0; $i -lt $lines.Count; $i++) { if (Test-Same $lines[$i] "::${token}::") { $i } })
    if ($closes.Count -ne 1 -or $closes[0] -le $opens[0]) { return $null }
    return @{ token = $token; open = $opens[0]; close = $closes[0] }
}

# ---------- 픽스처 조각 ----------
$schemaName = 'sample.compat.event.json'
$schemaRel = "packages/events/schemas/$schemaName"
$schemasDirRel = 'packages/events/schemas/'
$checkerRel = 'packages/events/scripts/check-compat.mjs'
$schemaBase = (@'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://joshuatech.dev/events/sample.compat.event/v1",
  "x-version": "1.0.0",
  "title": "sample.compat.event",
  "type": "object",
  "properties": {
    "x": { "type": "string" },
    "y": { "type": "integer" }
  },
  "required": ["y"]
}
'@ -replace "`r`n", "`n") + "`n"
$schemaAdded = $schemaBase.Replace('    "y": { "type": "integer" }', "    `"y`": { `"type`": `"integer`" },`n    `"z`": { `"type`": `"boolean`" }")   # 선택 필드 추가(허용)
$schemaNoX = $schemaBase.Replace("    `"x`": { `"type`": `"string`" },`n", '')                                                   # 필드 x 삭제(금지)
# 메타데이터만 바꾼다 — description에 ident 키워드 $Id$(ec-29: 체크아웃이 '$Id: <blob oid> $'로 바꾼다 · git checkout 실측)
$schemaIdent = $schemaBase.Replace('  "title": "sample.compat.event",', '  "title": "sample.compat.event",' + "`n" + '  "description": "$Id$",')
$checkerText = if (Test-Path -LiteralPath $checkerPath -PathType Leaf) { [IO.File]::ReadAllText($checkerPath) } else { "console.error('check-compat.mjs 없음 — 하네스 대역');`nprocess.exit(2);`n" }
$weakChecker = "// 항상 통과시키는 약한 검사기(ec-4 — PR이 검사기를 고쳐 제 위반을 통과시키려는 경우)`nprocess.exit(0);`n"
$oddChecker = "// 예상 밖 종료 코드로 끝나는 검사기(ec-19)`nprocess.exit(3);`n"
# 출력 계약(요약 줄 "check-compat: checked N · added M · violations K")을 어기는 기준 검사기(ec-27) — 하나씩 기준 커밋에 둔다
$fakeSyntax = "this is not javascript (`n"
$fakeSilent0 = "// 아무것도 찍지 않고 0으로 끝나는 검사기(요약 줄 없음 — 진입점 가드가 꺼진 검사기와 같은 꼴)`nprocess.exit(0);`n"
$fakeNoSummary1 = (@'
// 요약 줄 없이 위반 줄만 찍고 1로 끝나는 검사기
process.stdout.write("sample.compat.event.json #/properties/x field-removed 가짜 위반\n");
process.exit(1);
'@ -replace "`r`n", "`n") + "`n"
$fakeZeroButOne = (@'
// violations 0을 찍고 1로 끝나는 검사기
process.stderr.write("check-compat: checked 1 · added 0 · violations 0\n");
process.exit(1);
'@ -replace "`r`n", "`n") + "`n"
$fakeCountMismatch = (@'
// violations 2를 찍는데 위반 줄은 하나인 검사기
process.stdout.write("sample.compat.event.json #/properties/x field-removed 가짜 위반\n");
process.stderr.write("check-compat: checked 1 · added 0 · violations 2\n");
process.exit(1);
'@ -replace "`r`n", "`n") + "`n"
$fakeStdoutOn0 = (@'
// violations 0 · exit 0인데 위반 줄을 찍는 검사기
process.stdout.write("sample.compat.event.json #/properties/x field-removed 가짜 위반\n");
process.stderr.write("check-compat: checked 1 · added 0 · violations 0\n");
process.exit(0);
'@ -replace "`r`n", "`n") + "`n"
$fakeTwoSummaries = (@'
// 요약 줄을 두 번 찍는 검사기
process.stderr.write("check-compat: checked 1 · added 0 · violations 0\ncheck-compat: checked 1 · added 0 · violations 0\n");
process.exit(0);
'@ -replace "`r`n", "`n") + "`n"
# replace ref로 기준 검사기 blob 자리에 끼워 넣는 약한 검사기(ec-28) — 출력 계약은 지키고 위반을 숨긴다. 표식은 ASCII(EVCOMPAT-WEAK)
$replaceChecker = (@'
// EVCOMPAT-WEAK replacement checker (ec-28): obeys the output contract, hides every violation
process.stderr.write("check-compat: checked 1 · added 0 · violations 0\n");
process.exit(0);
'@ -replace "`r`n", "`n") + "`n"
$kindsRe = 'field-removed|type-changed|required-added|required-removed|enum-removed|schema-removed'
$zero40 = '0' * 40
$zero64 = '0' * 64
$violationX = "$schemaName #/properties/x field-removed "
$removedLine = "$schemaName # schema-removed "

$savedGitEnv = @{}
$gitEnvNames = @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_COMMON_DIR', 'GIT_NAMESPACE')
foreach ($n in $gitEnvNames) { $savedGitEnv[$n] = [Environment]::GetEnvironmentVariable($n) }

try {
    # git을 사용자 설정과 떼어 놓는다(시스템 · 전역 설정 없음 · 다른 저장소를 가리키는 GIT_DIR류 없음)
    $gitHome = New-TempDir 'evcompat-git-'
    $emptyConfig = Join-Path $gitHome 'gitconfig'
    [IO.File]::WriteAllText($emptyConfig, '', [Text.UTF8Encoding]::new($false))
    foreach ($n in $gitEnvNames) { Set-EnvVar $n $null }
    Set-EnvVar 'GIT_CONFIG_NOSYSTEM' '1'
    Set-EnvVar 'GIT_CONFIG_GLOBAL' $emptyConfig

    $withChecker = @{ $schemaRel = $schemaBase; $checkerRel = $checkerText }

    Test-Group 'pre' {
        Assert 'pre-1: packages/events/scripts/check-compat.mjs exists (the fixtures commit a copy of it)' (Test-Path -LiteralPath $checkerPath -PathType Leaf) "missing: $checkerPath"
    }

    # ---------- 정적: ci.yml 원문(job events-compat · events-test) + 스크립트 원문 ----------
    Test-Group 'static' {
        $ci = if (Test-Path -LiteralPath $ciPath -PathType Leaf) { [IO.File]::ReadAllText($ciPath) } else { '' }
        $ciLines = [string[]]@($ci -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
        $gate = Get-JobInfo $ciLines 'events-compat'
        $tst = Get-JobInfo $ciLines 'events-test'

        $jobsAt = [Array]::IndexOf($ciLines, 'jobs:')
        $jobNames = [string[]]@(if ($jobsAt -ge 0) { for ($i = $jobsAt + 1; $i -lt $ciLines.Count; $i++) { $m = [regex]::Match($ciLines[$i], '^  ([A-Za-z0-9_-]+):\s*$'); if ($m.Success) { $m.Groups[1].Value } } })
        $absent = @(foreach ($n in @('gitleaks', 'lint', 'test', 'kubeconform', 'events-compat', 'events-test')) { if (-not (Test-HasLine $jobNames $n)) { $n } })
        $iGateJob = [Array]::IndexOf($jobNames, 'events-compat')
        Assert 'st-1: ci.yml keeps the jobs gitleaks, lint, test and kubeconform and has events-compat followed directly by events-test' (
            $absent.Count -eq 0 -and $iGateJob -ge 0 -and $iGateJob + 1 -lt $jobNames.Count -and (Test-Same $jobNames[$iGateJob + 1] 'events-test')
        ) "jobs: [$($jobNames -join ', ')]; absent: [$($absent -join ', ')]"

        foreach ($pair in @(@('events-compat', $gate), @('events-test', $tst))) {
            $name = $pair[0]; $j = $pair[1]
            Assert "st-2: job ${name}: runs-on ubuntu-24.04-arm, timeout-minutes 10, no continue-on-error, no secrets.*, no job-level permissions" (
                $j.block.Count -gt 0 -and $j.text -match '(?m)^    runs-on: ubuntu-24\.04-arm\s*$' -and $j.text -match '(?m)^    timeout-minutes: 10(\s|$)' -and -not (Test-Has $j.text 'continue-on-error') -and -not (Test-Has $j.text 'secrets.') -and @($j.block | Where-Object { $_ -match '^\s+permissions:' }).Count -eq 0
            ) "job block: [$($j.text)]"
        }

        $pinRe = '^[A-Za-z0-9._-]+/[A-Za-z0-9._/-]+@[0-9a-f]{40}$'
        $gateUses = @($gate.block | ForEach-Object { [regex]::Match($_, '^\s*(-\s+)?uses:\s*(\S+)') } | Where-Object { $_.Success } | ForEach-Object { $_.Groups[2].Value })
        $tstUses = @($tst.block | ForEach-Object { [regex]::Match($_, '^\s*(-\s+)?uses:\s*(\S+)') } | Where-Object { $_.Success } | ForEach-Object { $_.Groups[2].Value })
        Assert 'st-3: job events-compat has exactly three steps in this order: actions/setup-node, actions/checkout, the gate (run: bash scripts/ci/events-compat.sh) — Node setup runs in the empty workspace before checkout, nothing else runs before or after the gate; actions pinned to a full 40-hex SHA' (
            (Test-Same ($gate.kinds -join ',') 'setup-node,checkout,gate') -and $gateUses.Count -eq 2 -and @($gateUses | Where-Object { $_ -notmatch $pinRe }).Count -eq 0
        ) "steps: [$($gate.kinds -join ', ')]; uses: [$($gateUses -join ', ')]"
        # r4 F17(리뷰 r3 B3-1): 체크아웃 뒤에는 게이트 스텝 하나뿐이다 — 체크아웃 뒤의 액션(예: setup-node의 node · npm · yarn --version
        # 탐침)은 PR 작업 공간을 cwd로 돌고, Yarn 1은 그 탐침에서 PR의 .yarnrc · .yarnrc.yml에 적힌 yarnPath를 먼저 실행한다
        $iCheckouts = @(for ($i = 0; $i -lt $gate.kinds.Count; $i++) { if (Test-Same $gate.kinds[$i] 'checkout') { $i } })
        $afterCheckout = [Collections.Generic.List[object]]::new()
        if ($iCheckouts.Count -ge 1) { for ($i = $iCheckouts[0] + 1; $i -lt $gate.steps.Count; $i++) { $afterCheckout.Add($gate.steps[$i]) } }
        $lastStep = if ($afterCheckout.Count -eq 1) { [string[]]$afterCheckout[0] } else { [string[]]@() }
        $lastUses = @($lastStep | Where-Object { $_ -match '^\s*(-\s+)?uses:' })
        $lastRunBodies = Get-RunBodies $lastStep
        $lastRuns = @($lastRunBodies | ForEach-Object { $_.Trim() })
        $afterKinds = @(foreach ($s in $afterCheckout) { Get-StepKind ([string[]]$s) })
        Assert 'st-3c: in events-compat exactly one step follows actions/checkout — it has no uses: and its run: is exactly "bash scripts/ci/events-compat.sh" (no action runs in the checked-out PR workspace before the gate)' (
            $iCheckouts.Count -eq 1 -and $afterCheckout.Count -eq 1 -and $lastUses.Count -eq 0 -and $lastRuns.Count -eq 1 -and (Test-Same $lastRuns[0] 'bash scripts/ci/events-compat.sh')
        ) "checkout steps: $($iCheckouts.Count); steps after checkout: $($afterCheckout.Count) [$($afterKinds -join ', ')]; uses: lines in that step: $($lastUses.Count); run bodies: [$($lastRuns -join ' / ')]"
        # r6 F31(리뷰 r5 R5-2): 테스트 스텝은 --fail-if-no-match를 둔다 — 걸러 낸 프로젝트가 없으면 pnpm --filter는 exit 0이라, 워크스페이스에서
        # packages/events를 빼는 변경(루트 pnpm-workspace.yaml)이 시험 0개의 빈 통과가 된다
        Assert 'st-3b: job events-test has exactly: actions/checkout, pnpm/action-setup, actions/setup-node, "pnpm install --frozen-lockfile --ignore-scripts", "pnpm --filter @jt/events --fail-if-no-match test" (install before vitest; --fail-if-no-match so a filter that matches no project fails instead of exiting 0 with no tests run); actions pinned to a full 40-hex SHA' (
            (Test-Same ($tst.kinds -join ',') 'checkout,pnpm-setup,setup-node,install,vitest') -and $tstUses.Count -eq 3 -and @($tstUses | Where-Object { $_ -notmatch $pinRe }).Count -eq 0
        ) "steps: [$($tst.kinds -join ', ')]; uses: [$($tstUses -join ', ')]"

        $gateCheckout = Get-StepMap (Find-Step $gate 'checkout') 'with'
        $tstCheckout = Get-StepMap (Find-Step $tst 'checkout') 'with'
        Assert 'st-4: events-compat checkout has fetch-depth: 0 and persist-credentials: false; events-test checkout has persist-credentials: false (no token left in .git/config)' (
            (Test-Same $gateCheckout['fetch-depth'] '0') -and (Test-Same $gateCheckout['persist-credentials'] 'false') -and (Test-Same $tstCheckout['persist-credentials'] 'false')
        ) "events-compat checkout with: [$(Format-Map $gateCheckout)]; events-test checkout with: [$(Format-Map $tstCheckout)]"

        # 저장소 .node-version(끝 줄바꿈 하나를 걷어 낸 내용) — 게이트 job의 Node 버전 고정값과 같아야 한다(st-5 · st-15)
        $nodeVersionFile = Join-Path $repo '.node-version'
        $nodeVersionRaw = if (Test-Path -LiteralPath $nodeVersionFile -PathType Leaf) { [IO.File]::ReadAllText($nodeVersionFile) } else { $null }
        $nodeVersion = if ($null -ne $nodeVersionRaw) { $nodeVersionRaw -replace '\r?\n\z', '' } else { '' }
        $gateNodeStep = Find-Step $gate 'setup-node'
        $gateNode = Get-StepMap $gateNodeStep 'with'
        $tstNode = Get-StepMap (Find-Step $tst 'setup-node') 'with'
        $cacheKeys = @($gateNodeStep | Where-Object { $_ -match '^\s+[A-Za-z0-9_-]*cache[A-Za-z0-9_-]*:' })
        $versionFileKeys = @($gateNodeStep | Where-Object { $_ -match '^\s+node-version-file\s*:' })
        # r7 F36(리뷰 r6 R6-1 (a)(b) — schemas.test.mjs sch-23과 같은 결속): job events-compat 블록 전체(주석 줄 제외)에서 setup-node를
        # 가리키는 줄은 꼴과 상관없이(앞의 '- ' · 따옴표 · 대소문자 · 흐름 매핑) 대시 꼴 스텝 머리 하나, node-version 키 줄은 꼴과 상관없이(따옴표
        # 키 · 흐름 매핑 · 대소문자 · INPUT_NODE-VERSION) 그 핀 하나, node-version-file 키 줄은 0 — -match는 대소문자를 가리지 않는다
        $gateKeyLines = @($gate.block | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith('#') })
        $setupRefs = @($gateKeyLines | Where-Object { $_ -match 'actions/setup-node[/@]' })
        $blockPins = @($gateKeyLines | Where-Object { $_ -match '(^|[^A-Za-z0-9.-])node-version["'']?[ \t]*(:|#|$)' })
        $blockFiles = @($gateKeyLines | Where-Object { $_ -match '(^|[^A-Za-z0-9.-])node-version-file["'']?[ \t]*(:|#|$)' })
        $gateKeys = [string[]]@($gateNode.Keys)
        [Array]::Sort($gateKeys, [StringComparer]::Ordinal)
        Assert "st-5: events-compat setup-node with: (read at the step key depth only — a with: nested under env: or another key is not the step's input) is exactly node-version: '<.node-version content>' and package-manager-cache: false — a literal version and no node-version-file (setup-node runs before checkout, so there is no .node-version to read), no cache input and the automatic package-manager cache off (defence in depth); that is the only cache-like key; across the whole events-compat block (comments excluded) exactly one line points at setup-node in the leading '- ', quoting, case or flow-mapping forms (the dash-form step head), exactly one node-version key line in those forms (that pin) and no node-version-file key line — a line-based drift check (contract r8); events-test setup-node has node-version-file: '.node-version' and cache: pnpm" (
            $nodeVersion.Length -gt 0 -and (Test-Same ($gateKeys -join ',') 'node-version,package-manager-cache') -and (Test-Same $gateNode['node-version'] "'$nodeVersion'") -and (Test-Same $gateNode['package-manager-cache'] 'false') -and $cacheKeys.Count -eq 1 -and $cacheKeys[0] -match '^\s+package-manager-cache:' -and $versionFileKeys.Count -eq 0 -and $setupRefs.Count -eq 1 -and $setupRefs[0] -cmatch '^\s*-\s+uses:\s*actions/setup-node@' -and $blockPins.Count -eq 1 -and $blockFiles.Count -eq 0 -and (Test-Same $tstNode['node-version-file'] "'.node-version'") -and (Test-Same $tstNode['cache'] 'pnpm')
        ) "events-compat setup-node with: [$(Format-Map $gateNode)]; .node-version content: [$nodeVersion]; cache-like key lines: [$(($cacheKeys | ForEach-Object { $_.Trim() }) -join ' / ')]; node-version-file lines: $($versionFileKeys.Count); whole events-compat block (comments excluded): setup-node lines $($setupRefs.Count), node-version key lines $($blockPins.Count), node-version-file key lines $($blockFiles.Count); events-test setup-node with: [$(Format-Map $tstNode)]"

        Assert 'st-6: the events-compat job block has no "pnpm" anywhere (no pnpm setup, install, cache or test — not even in a comment)' (
            $gate.block.Count -gt 0 -and $gate.text.IndexOf('pnpm', [StringComparison]::OrdinalIgnoreCase) -lt 0
        ) "job block: [$($gate.text)]"

        $gateRuns = @($gate.runs | ForEach-Object { $_.Trim() })
        Assert 'st-7: the only run: in events-compat is exactly "bash scripts/ci/events-compat.sh" (not wrapped, no arguments)' (
            $gateRuns.Count -eq 1 -and (Test-Same $gateRuns[0] 'bash scripts/ci/events-compat.sh')
        ) "run bodies: [$($gateRuns -join ' / ')]"

        $gateEnv = Get-StepMap (Find-Step $gate 'gate') 'env'
        $prEnv = @($gate.block | Where-Object { $_ -match '^\s+PR_HEAD_SHA: \$\{\{ github\.event\.pull_request\.head\.sha \}\}\s*$' })
        $pushEnv = @($gate.block | Where-Object { $_ -match '^\s+PUSH_BEFORE: \$\{\{ github\.event\.before \}\}\s*$' })
        $gateExpr = @($gate.block | Where-Object { $_ -match '^[^#]*\$\{\{' })
        $tstExpr = @($tst.block | Where-Object { $_ -match '^[^#]*\$\{\{' })
        Assert 'st-8: the gate step''s env is exactly PR_HEAD_SHA: ${{ github.event.pull_request.head.sha }} and PUSH_BEFORE: ${{ github.event.before }} — one line each, both on the gate step, the only expressions in events-compat; events-test has no ${{ at all' (
            (Test-Same (@($gateEnv.Keys) -join ',') 'PR_HEAD_SHA,PUSH_BEFORE') -and (Test-Same $gateEnv['PR_HEAD_SHA'] '${{ github.event.pull_request.head.sha }}') -and (Test-Same $gateEnv['PUSH_BEFORE'] '${{ github.event.before }}') -and $prEnv.Count -eq 1 -and $pushEnv.Count -eq 1 -and $gateExpr.Count -eq 2 -and $tstExpr.Count -eq 0
        ) "gate env: [$(Format-Map $gateEnv)]; PR_HEAD_SHA lines $($prEnv.Count); PUSH_BEFORE lines $($pushEnv.Count); expression lines: events-compat [$($gateExpr -join ' / ')] events-test [$($tstExpr -join ' / ')]"

        $exprRuns = @(@($gate.runs) + @($tst.runs) | Where-Object { $_.Contains('${{') })
        Assert 'st-9: no run: body of events-compat or events-test contains ${{ (values reach run: only through env:)' (
            $gate.runs.Count -eq 1 -and $tst.runs.Count -eq 2 -and $exprRuns.Count -eq 0
        ) "run bodies: events-compat $($gate.runs.Count), events-test $($tst.runs.Count); with an expression: $($exprRuns.Count)"

        $permIdx = @(for ($i = 0; $i -lt $ciLines.Count; $i++) { if ($ciLines[$i] -match '^permissions:') { $i } })
        $permOk = $permIdx.Count -eq 1 -and (Test-Same $ciLines[$permIdx[0]] 'permissions:') -and ($permIdx[0] + 1 -lt $ciLines.Count) -and (Test-Same $ciLines[$permIdx[0] + 1] '  contents: read') -and (($permIdx[0] + 2 -ge $ciLines.Count) -or ($ciLines[$permIdx[0] + 2] -notmatch '^\s+\S'))
        Assert 'st-10: workflow-level permissions is exactly "contents: read"' $permOk "workflow permissions lines: $($permIdx.Count)"

        $headerEnd = [Array]::IndexOf($ciLines, 'name: ci')
        $header = if ($headerEnd -gt 0) { ($ciLines[0..($headerEnd - 1)] -join "`n") } else { '' }
        # 계약 r7 문장(contracts/events.md 「CI 기준과 검사기」 — 「Node 설치는 체크아웃 전」 · 「한계」)의 요소 — 주석 줄바꿈과 무관하게 '# '를
        # 걷어 낸 한 줄에서 찾는다. st-11(ci.yml 머리)과 st-14(스크립트 머리 — 판정 규칙의 정본)가 같은 목록을 쓴다. r4의
        # 'packages/events/tests/' · '.gitattributes의 CODEOWNERS'는 r5 인계 목록(packages/events/ 전체 · 모든 깊이의 .gitattributes)으로 바뀌었다.
        # r6(F34 · 리뷰 r5 R5-1 · R5-2): 패키지 밖 사본 env(NODE_PATH · NODE_OPTIONS 제거) · sch-24 · 시험 실행 경로(루트 매니페스트 · 잠금파일
        # 포함) · --fail-if-no-match · 운영자 인계(루트 매니페스트 · 잠금파일 · .github/CODEOWNERS 자신)를 더했다 — r5의 'vitest 설정' · 인계 목록
        # needle은 그것을 그대로 담는 더 긴 r6 needle로 바뀌었다.
        # r7(F37 · 리뷰 r6 R6-2): 시험 실행 경로에 루트 .npmrc(pnpm node-options 등) · .pnpmfile.cjs와 「닫힌 목록이 아니다」, 운영자 인계에 루트
        # .npmrc · .pnpmfile.cjs(아직 없는 경로도 지정할 수 있다)를 더했다 — r6의 시험 실행 경로 needle은 그것을 앞머리로 담는 더 긴 r7 needle로
        # 바뀌었고, r6의 인계 목록 needle은 가운데에 두 경로가 들어가 r7 needle(r6 항목을 같은 순서로 모두 담는다)로 바뀌었다.
        # r8(F39 · 리뷰 r7 R7-1 · R7-2): 계약 r8의 범위 문장 두 개(sch-23 · st-5 · st-15 = 줄 단위 드리프트 검사 · 의도적으로 꼬아 쓴 ci.yml은
        # 범위 밖 — 게이트 파일 리뷰(코드 소유자))를 끝에 더했다(빠진 r7 needle은 없다).
        $r8Needles = @(
            '예외는 부트스트랩뿐',                        # PR 코드를 돌리지 않는다의 예외(A2-3 iii)
            'Node 설치(체크아웃 전',                      # 스텝 순서 Node 설치 → 체크아웃 → 게이트 스크립트(r4 F17 · B3-1)
            '체크아웃 뒤에 도는 것은 게이트 스크립트 하나뿐',
            'yarnPath',                                   # 순서의 이유: setup-node의 --version 탐침 → Yarn 1의 yarnPath 실행(B3-1)
            'Node 버전은 ci.yml의 고정값',                 # Node 버전 = ci.yml 고정값
            'PR 내용에서 읽지 않는다',
            'CI에서는 job events-test의 schemas.test.mjs sch-23',   # 고정값 = .node-version을 지키는 곳: CI = sch-23(r5 F24 · B4-2)
            '로컬에서는 하네스 st-5 · st-15',                        # · 로컬 = 하네스 st-5 · st-15
            'Node API',                                             # · 드리프트 + 새 Node API = 머지 뒤 교착
            'GitHub 호스티드 러너(job마다 새 VM',          # 빈 작업 공간의 전제(r5 F24 · B4-3 c)
            '자체 호스티드 러너',
            'package-manager-cache: false',               # 캐시 없음(F9 · B2-1 — 체크아웃 전에도 심층 방어로 둔다)
            'HEAD 커밋',                                  # 변경 쪽 = HEAD 커밋 객체(F10 · B2-2)
            'hash-object --no-filters',                   # 작업 트리 바이트 일치(F10)
            '다음 기준',                                  # 변경 쪽 모양 = 다음 기준의 모양(F11 · B2-3)
            '스키마 수와 상관없이',                        # 검사기 경로의 모양은 스키마 수와 무관(r4 F19 · B3-3 i)
            '기준에 검사기도 스키마도 없을 때만',            # 부트스트랩 조건(A2-3 ii)
            '요약 줄 정확히 하나',                         # 출력 계약(A2-3 i)
            '앞 0 없는 9자리 이하',
            '위반 줄 수 = K',
            'PR 내용에서 읽는 것은 이 둘뿐',                # 한계: 게이트 job이 PR 내용에서 읽는 것(r4 — .node-version은 빠졌다)
            '그 뒤 모든 PR',                               # 한계: 머지된 게이트 파일 변경(B2-4)
            '거짓 위반 1',                                 # 한계: 엄격 · 파손 검사기의 머지 뒤 교착 — 2 또는 거짓 위반 1(r5 · B4-3 e)
            '게이트 스크립트를 함께 고친 PR',                # 복구는 게이트 스크립트를 함께 고친 PR이 먼저(r5 · A4-2 i · B4-3 a)
            '운영자 머지',                                 # · 운영자 우회 머지는 다른 required check까지 비켜 가므로 마지막 수단
            '다른 required check',
            '마지막 수단',
            '패키지 밖 검사기 사본',                        # 머지 전 방어: sch-14(패키지 밖 사본 · 실제 스키마 — r5 F25 · B4-1) · sch-21 · sch-9 · sch-23
            'sch-14',
            'sch-21',
            'sch-9',
            'NODE_PATH · NODE_OPTIONS를 지운 env',          # 패키지 밖 사본의 실행 env(r6 F30 · R5-1)
            'sch-24',                                       # · 그 env에서 사본 위치가 ajv를 해석하지 못함을 먼저 확인하는 전제 단언
            'vitest 실행 shim',                             # · 이유: pnpm의 vitest 실행 shim이 NODE_PATH에 .pnpm/node_modules를 넣는다
            '게이트 조건(node_modules 없음)',
            '실제로 돌릴 때만',                             # · events-test가 그 시험을 실제로 돌릴 때만(r5 · A4-2 ii · B4-3 b)
            '시험 실행 경로',                               # · 그 경로(r6 · R5-2 b — 루트 매니페스트 · 잠금파일 포함 · r7 · R6-2 — .npmrc · .pnpmfile.cjs · 닫힌 목록 아님)
            'packages/events/package.json의 test 스크립트',
            'vitest 설정 · 루트 pnpm-workspace.yaml · package.json · pnpm-lock.yaml · .npmrc(pnpm node-options 등) · .pnpmfile.cjs 등 events-test가 읽는 pnpm · vitest 설정과 훅 파일',
            'events-test는 PR 코드를 도는 job이라 이 목록은 닫힌 목록이 아니다',
            '앞선 PR 포함',
            'pnpm --filter @jt/events --fail-if-no-match test',   # events-test 명령(r6 F31 · R5-2 a) — 걸러 낸 프로젝트가 없으면 exit 0이던 빈 통과
            '빈 통과',
            'packages/events/ · scripts/ci/ · .github/workflows/ · 모든 깊이의 .gitattributes · 루트 pnpm-workspace.yaml · package.json · pnpm-lock.yaml · .npmrc · .pnpmfile.cjs(아직 없는 경로도 지정할 수 있다) · .github/CODEOWNERS 자신',   # 운영자 인계(r6 · R5-2 c · r7 · R6-2)
            'CODEOWNERS',
            '코드 소유자 리뷰',
            'required check',
            '교착 방어가 events-test에 기댄다',             # · events-compat · events-test required check(B4-3 d)
            '이 검사들은 줄 단위 드리프트 검사다 — 실수로 갈라진 값 · 옮겨진 핀 · 늘어난 setup-node 스텝을 잡는다.',   # r8 범위(F39 · R7-1 · R7-2)
            'YAML 이어짐 줄 · 이스케이프 · 별칭 · 가짜 job 블록처럼 ci.yml을 일부러 꼬아 쓰는 편집은 이 검사의 범위가 아니다 — ci.yml을 고치는 PR은 게이트를 통째로 바꿀 수도 있으므로, 그런 편집은 아래 「한계」대로 게이트 파일 리뷰(코드 소유자)가 막는다'
        )
        # ci.yml 머리에만 있는 r6 문장(F33 · 리뷰 r5 R5-4): events-test는 토큰 · 비밀을 run 스텝에 넘기지 않을 뿐이다 — 액션의 기본 token 입력과
        # 캐시 토큰은 체크아웃 뒤 setup-node 탐침이 실행하는 PR 코드가 물려받을 수 있다(게이트와는 다른 VM — 게이트 무결성과는 무관)
        $ciOnlyNeedles = @(
            '토큰 · 비밀을 run 스텝에 넘기지 않는다',
            '기본 token 입력(contents: read)',
            '캐시 토큰',
            'setup-node 탐침이 실행하는 PR 코드',
            '게이트 무결성과는 무관'
        )
        # 있으면 FAIL인 옛 문장: r2의 부트스트랩 조건 · r3의 한계(.node-version을 게이트의 PR 입력으로 적은 문장) · r4의 한계(복구는 운영자
        # 머지뿐 · 머지 전 방어는 sch-14 · sch-21뿐 · 같은 PR이 그 시험을 고치지 않을 때만 · events-test의 required check는 운영자가 정한다 —
        # r5 F24) · r5의 events-test 「토큰과 비밀 없음」 · 「토큰 · 비밀은 쓰지 않는다」(r6 F33 — 넘기지 않을 뿐 탐침이 물려받는다) · r6의
        # 시험 실행 경로 · 인계 목록 끝(잠금파일 바로 뒤에서 닫힌다 — r7 F37: .npmrc · .pnpmfile.cjs가 빠진 꼴이 어디에도 남지 않게) · r7의
        # setup-node 주석 「setup-node를 가리키는 줄은 꼴과 상관없이」(r8 F39 · 리뷰 r7 R7-2: 실제보다 넓게 말했다 — 앞의 '- ' 유무 · 따옴표 ·
        # 대소문자 · 흐름 매핑 꼴로 좁혔다) · r3의 순서(체크아웃 · Node 설치 뒤) — 마지막은 괄호 꼬리(전체 이력 등)가 붙은 꼴까지 정규식으로 본다
        $staleLiterals = @(
            '검사기가 없을 때만',
            '.node-version(게이트의 Node 버전',
            '복구는 required check를 비켜 가는 운영자 머지뿐',
            'sch-14(실제 스키마 자기 비교) · sch-21(요약 줄)뿐이다',
            '같은 PR이 그 시험을 고치지 않을 때만',
            'required check에 넣을지는 운영자가 정한다',
            '토큰과 비밀 없음',
            '토큰 · 비밀은 쓰지 않는다',
            'package.json · pnpm-lock.yaml)를 바꾸는',
            'pnpm-lock.yaml · .github/CODEOWNERS 자신',
            'setup-node를 가리키는 줄은 꼴과 상관없이'
        )
        # r7(F37 · 리뷰 r6 R6-2): job events-test 주석도 시험 실행 경로를 계약 r7 문장으로 담는다(st-11 — 그 job의 주석 줄만 한 줄로 편다)
        $tstCommentNeedles = @(
            '시험 실행 경로',
            'vitest 설정 · 루트 pnpm-workspace.yaml · package.json · pnpm-lock.yaml · .npmrc(pnpm node-options 등) · .pnpmfile.cjs 등 events-test가 읽는 pnpm · vitest 설정과 훅 파일',
            'events-test는 PR 코드를 도는 job이라 이 목록은 닫힌 목록이 아니다',
            '앞선 PR 포함',
            'sch-24'
        )
        # r8(F39 · 리뷰 r7 R7-2): job events-compat 주석(setup-node 주석)은 sch-23 결속의 「꼴과 상관없이」를 계약 r8 범위로 좁혀 적고(줄 단위
        # 드리프트 검사 · 의도적으로 꼬아 쓴 ci.yml은 코드 소유자 리뷰), 원문 NEL · LS · PS 가드를 적는다(st-11 — 그 job의 주석 줄만 한 줄로 편다)
        $gateCommentNeedles = @(
            '앞의 `- ` 유무 · 따옴표 · 대소문자 · 흐름 매핑 꼴과 상관없이 — 줄 단위 드리프트 검사 · 의도적으로 꼬아 쓴 ci.yml은 코드 소유자 리뷰',
            'NEL · LS · PS'
        )
        $staleOrderRe = '체크아웃(\([^)]*\))?\s*·\s*Node 설치'
        $flatHeader = (@($ciLines[0..([Math]::Max($headerEnd, 1) - 1)] | ForEach-Object { $_ -replace '^#\s*', '' }) -join ' ')
        # r5 F27(리뷰 r4 A4-3): 옛 문장은 ci.yml 전체(머리 · job · 스텝 주석)에서 찾는다 — 줄마다 앞 공백과 주석 표시('#' · 그 뒤 공백)를
        # 걷어 낸 뒤 한 줄로 편다(들여쓴 job 주석의 줄바꿈과 무관하게)
        $flatCi = (@($ciLines | ForEach-Object { $_ -replace '^\s*#?\s*', '' }) -join ' ')
        $missingHeader = @(@('scripts/ci/events-compat.sh') + $r8Needles + $ciOnlyNeedles | Where-Object { -not (Test-Has $flatHeader $_) })
        $flatTstComments = (@($tst.block | Where-Object { $_ -match '^\s*#' } | ForEach-Object { $_ -replace '^\s*#\s*', '' }) -join ' ')
        $missingTst = @($tstCommentNeedles | Where-Object { -not (Test-Has $flatTstComments $_) })
        $flatGateComments = (@($gate.block | Where-Object { $_ -match '^\s*#' } | ForEach-Object { $_ -replace '^\s*#\s*', '' }) -join ' ')
        $missingGate = @($gateCommentNeedles | Where-Object { -not (Test-Has $flatGateComments $_) })
        $staleCi = @(@($staleLiterals | Where-Object { Test-Has $flatCi $_ }) + @([regex]::Matches($flatCi, $staleOrderRe) | ForEach-Object { $_.Value }))
        Assert 'st-11: the header comment has the "job events-compat · events-test" entry naming both jobs and the r8 contract sentences (the job events-test comment carries the test-execution path with .npmrc · .pnpmfile.cjs, not a closed list; the job events-compat comments narrow the sch-23 "in any form" to the leading "- ", quoting, case and flow-mapping forms — line-based drift checks, a deliberately obfuscated ci.yml left to code-owner review — and name the NEL · LS · PS guard) — logic of record, the step order (Node setup before checkout, the gate the only step after it) and its reason (yarnPath), the Node version as the ci.yml literal (not read from the PR) kept equal to .node-version by sch-23 in events-test (CI) and st-5 · st-15 (local) with the drift deadlock (Node API), the scope of those checks (line-based drift checks catching a value that drifted by mistake, a moved pin or an extra setup-node step; YAML continuation lines, escapes, aliases or a fake job block — a deliberately obfuscated ci.yml — are out of scope and left to the gate-file code-owner review of the limits), the GitHub-hosted runner premise (fresh VM per job; a self-hosted runner voids it), the bootstrap exception, no cache, change side from the HEAD commit + work-tree bytes, the next-baseline shape, the bootstrap condition, the output contract, events-test passing no token or secret to run steps (the default token input and the cache token can reach the PR code the setup-node probe runs after checkout — another VM, no effect on gate integrity), the limits (only those two files read from the PR, merged gate files, a stricter or broken checker exits 2 or reports false violations, recovery first by a PR that also edits the gate script with the operator merge past other required checks as the last resort, caught before merge by sch-14 (out-of-package checker copy) · sch-21 · sch-9 · sch-23 with the copies run under an env without NODE_PATH · NODE_OPTIONS whose premise sch-24 asserts (the pnpm vitest shim puts .pnpm/node_modules on NODE_PATH), only while events-test actually runs them (the test-execution path, root pnpm-workspace.yaml · package.json · pnpm-lock.yaml · .npmrc (pnpm node-options and the like) · .pnpmfile.cjs included, any other pnpm or vitest setting or hook file events-test reads — not a closed list), the events-test command pnpm --filter @jt/events --fail-if-no-match test against an empty pass, the packages/events/ · scripts/ci/ · .github/workflows/ · .gitattributes-at-any-depth · root manifests and lockfile · .npmrc · .pnpmfile.cjs (paths that do not exist yet can be listed) · .github/CODEOWNERS itself CODEOWNERS · code-owner review · required check handover the deadlock defence relies on) — and none of the stale sentences anywhere in ci.yml (header, job and step comments: only when the baseline has no checker · .node-version as the gate''s Node version · checkout and Node setup before the gate · recovery only by an operator merge · sch-14 · sch-21 as the only defence · only while the same PR leaves those tests · the operator decides whether events-test is required · events-test has or uses no token or secret · the r6 test-execution path and handover list that end at the lockfile · the r7 setup-node comment saying setup-node lines are counted "in any form")' (
            $headerEnd -gt 0 -and (Test-Has $header '# - job events-compat') -and (Test-Has $header 'events-test') -and $missingHeader.Count -eq 0 -and $missingTst.Count -eq 0 -and $missingGate.Count -eq 0 -and $staleCi.Count -eq 0
        ) "missing: [$($missingHeader -join ' | ')]; missing in the job events-test comment: [$($missingTst -join ' | ')]; missing in the job events-compat comments: [$($missingGate -join ' | ')]; stale (whole ci.yml): [$($staleCi -join ' | ')]; header: [$header]"

        $bytes = if (Test-Path -LiteralPath $scriptPath -PathType Leaf) { [IO.File]::ReadAllBytes($scriptPath) } else { $null }
        $hasBom = $null -ne $bytes -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $src = if ($null -ne $bytes) { [Text.UTF8Encoding]::new($false).GetString($bytes) } else { '' }
        $srcLines = @($src -split "`n")
        Assert 'st-12: script has no BOM and no CR, starts with #!/usr/bin/env bash and has the line "set -euo pipefail"' (
            $null -ne $bytes -and -not $hasBom -and -not $src.Contains("`r") -and (Test-Same $srcLines[0] '#!/usr/bin/env bash') -and (Test-HasLine $srcLines 'set -euo pipefail')
        ) "script missing, BOM, CR, shebang or set line ($scriptPath)"

        $iExport = -1; $iGit = -1; $archive = @()
        for ($i = 0; $i -lt $srcLines.Count; $i++) {
            $l = $srcLines[$i]
            if ($l -match '^\s*#') { continue }
            if ($iExport -lt 0 -and (Test-Same $l.Trim() 'export GIT_NO_REPLACE_OBJECTS=1 GIT_LITERAL_PATHSPECS=1')) { $iExport = $i }
            if ($iGit -lt 0 -and $l -cmatch '(^|[^A-Za-z0-9_.-])git([^A-Za-z0-9_.-]|$)') { $iGit = $i }
            if ($l -cmatch '\bgit\s+archive\b|(^|[\s|;&(])tar(\s|$)') { $archive += ($i + 1) }
        }
        Assert 'st-13: the script exports GIT_NO_REPLACE_OBJECTS=1 GIT_LITERAL_PATHSPECS=1 before any line that runs git, and uses neither git archive nor tar (the baseline is read with ls-tree + cat-file blob)' (
            $iExport -ge 0 -and $iGit -gt $iExport -and $archive.Count -eq 0
        ) "export line $($iExport + 1); first git line $($iGit + 1); git archive / tar lines [$($archive -join ', ')]"

        # 스크립트 머리 주석(판정 · 기준 규칙의 정본)도 계약 r8 문장을 담는다 — 'set -euo pipefail' 앞의 주석 줄을 한 줄로 편다(st-11과 같은
        # 목록 · 같은 옛 문장 — ci.yml 머리에만 있는 F33 문장은 빼고)
        $iSet = -1
        for ($i = 0; $i -lt $srcLines.Count; $i++) { if (Test-Same $srcLines[$i] 'set -euo pipefail') { $iSet = $i; break } }
        $flatScript = if ($iSet -gt 0) { (@($srcLines[0..($iSet - 1)] | Where-Object { $_ -match '^#' } | ForEach-Object { $_ -replace '^#\s*', '' }) -join ' ') } else { '' }
        $missingScript = @($r8Needles | Where-Object { -not (Test-Has $flatScript $_) })
        $staleScript = @(@($staleLiterals | Where-Object { Test-Has $flatScript $_ }) + @([regex]::Matches($flatScript, $staleOrderRe) | ForEach-Object { $_.Value }))
        Assert 'st-14: the script header comment (logic of record) states the r8 rules — the step order (Node setup before checkout, the gate the only step after it) and its reason (yarnPath), the Node version as the ci.yml literal kept equal to .node-version by sch-23 (CI) and st-5 · st-15 (local), the scope of those checks (line-based drift checks; a deliberately obfuscated ci.yml — YAML continuation lines, escapes, aliases, a fake job block — is out of scope and left to the gate-file code-owner review), the GitHub-hosted runner premise, the bootstrap exception, no cache, change side from the HEAD commit + work-tree bytes, the next-baseline shape (checker path whatever the schema count), the bootstrap condition, the output contract, the limits (only ci.yml and this script read from the PR, merged gate files, a stricter or broken checker exits 2 or reports false violations, recovery first by a PR that also edits the gate script and the operator merge as the last resort, caught before merge by sch-14 (out-of-package copy) · sch-21 · sch-9 · sch-23 with the copies run under an env without NODE_PATH · NODE_OPTIONS whose premise sch-24 asserts (pnpm vitest shim), only while events-test runs them (the test-execution path, root manifests, lockfile, .npmrc and .pnpmfile.cjs included — not a closed list), the events-test command with --fail-if-no-match against an empty pass, the operator handover with the root manifests, lockfile, .npmrc, .pnpmfile.cjs (paths that do not exist yet can be listed) and .github/CODEOWNERS itself) — and none of the stale sentences (only when the baseline has no checker · .node-version as the gate''s Node version · checkout and Node setup before the gate · recovery only by an operator merge · sch-14 · sch-21 as the only defence · only while the same PR leaves those tests · the r6 test-execution path and handover list that end at the lockfile · the r7 "in any form" setup-node wording)' (
            $iSet -gt 0 -and $missingScript.Count -eq 0 -and $staleScript.Count -eq 0
        ) "set line $($iSet + 1); missing: [$($missingScript -join ' | ')]; stale: [$($staleScript -join ' | ')]"

        # r4 F17: 게이트 job의 Node 버전은 ci.yml의 고정값이다(.node-version을 읽을 체크아웃이 아직 없다) — 저장소 .node-version과 글자가
        # 같아야 한다(드리프트 방지 · events-test는 node-version-file로 같은 파일을 읽는다)
        $gateNodeValue = [string]$gateNode['node-version']
        $gateNodeLiteral = if ($gateNodeValue -match "^'([^']*)'$") { $Matches[1] } elseif ($gateNodeValue -match '^"([^"]*)"$') { $Matches[1] } else { $gateNodeValue }
        $nodeVersionShown = if ($null -ne $nodeVersionRaw) { $nodeVersionRaw -replace "`r", '<CR>' -replace "`n", '<LF>' } else { '<missing>' }
        Assert 'st-15: the events-compat setup-node node-version value equals the repository .node-version content without its final line break (no drift between the gate''s literal Node version and .node-version)' (
            $null -ne $nodeVersionRaw -and $nodeVersion.Length -gt 0 -and (Test-Same $gateNodeLiteral $nodeVersion)
        ) "node-version in ci.yml: [$gateNodeValue]; .node-version: [$nodeVersionShown]"
    }

    # ---------- ec-1: 부트스트랩 PR — 기준에 packages/events가 없다 ----------
    Test-Group 'ec-1: bootstrap PR' {
        $s = New-PrRepo @{} $withChecker
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert 'ec-1: bootstrap PR (the base commit has no packages/events) -> exit 0, "  검사기: 부트스트랩 …", "  기준 스키마: 없음 …", "결과: 통과", no violation line' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '  검사기: 부트스트랩') -and (Test-HasLinePrefix $r.lines '  기준 스키마: 없음') -and (Test-HasLinePrefix $r.lines '결과: 통과') -and $r.out -notmatch $kindsRe
        ) (Format-Result $r)
    }

    # ---------- ec-2 · ec-3 · ec-12 · ec-13: 기준에 스키마와 검사기가 있는 PR ----------
    Test-Group 'ec-2: allowed change' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        $summary = Join-Path (New-TempDir 'evcompat-summary-') 'step-summary.md'
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr; GITHUB_STEP_SUMMARY = (ConvertTo-BashPath $summary) }
        Assert 'ec-2: PR adds an optional field -> exit 0, "  검사기: 기준 커밋 …" (the base checker), "결과: 통과", no violation line' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '  검사기: 기준 커밋 ') -and (Test-HasLinePrefix $r.lines '결과: 통과') -and $r.out -notmatch $kindsRe
        ) (Format-Result $r)
        $sum = if (Test-Path -LiteralPath $summary -PathType Leaf) { @([IO.File]::ReadAllLines($summary) | Where-Object { $_ -ne '' }) } else { @() }
        Assert 'ec-12: GITHUB_STEP_SUMMARY gets exactly three lines — 기준 · 검사기 · 결과 … exit 0' (
            $sum.Count -eq 3 -and $sum[0].StartsWith('- **기준** · ', [StringComparison]::Ordinal) -and $sum[1].StartsWith('- **검사기** · ', [StringComparison]::Ordinal) -and $sum[2].StartsWith('- **결과** · ', [StringComparison]::Ordinal) -and $sum[2].EndsWith('exit 0', [StringComparison]::Ordinal) -and (Test-Has $sum[0] $s.base.Substring(0, 12))
        ) ("summary: [$($sum -join ' / ')] " + (Format-Result $r))
    }

    Test-Group 'ec-3: field removed' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert "ec-3: PR removes field x -> exit 1, stdout line '$violationX…', ""결과: 실패""" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLinePrefix $r.lines '결과: 실패')
        ) (Format-Result $r)
        $region = Get-StopRegion $r.lines
        $vi = Get-LineIndex $r.lines $violationX
        $si = Get-LineIndex $r.lines 'check-compat: checked '
        if ($null -ne $region) { $script:tokens.Add($region.token) }
        $colons = @($r.lines | Where-Object { $_.StartsWith('::', [StringComparison]::Ordinal) })
        Assert 'ec-13: the checker output (stdout, then stderr) sits between exactly one "::stop-commands::<token>" line and one "::<token>::" line (a fresh token of 16+ characters [A-Za-z0-9-]), and no other line starts with ::' (
            $null -ne $region -and $region.open -lt $vi -and $vi -lt $si -and $si -lt $region.close -and $region.token -match '^[A-Za-z0-9-]{16,}$' -and $colons.Count -eq 2
        ) ("region: $(if ($region) { "$($region.open)..$($region.close) token $($region.token)" } else { 'none' }); violation line $vi; summary line $si; " + (Format-Result $r))
        $r2 = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        $region2 = Get-StopRegion $r2.lines
        if ($null -ne $region2) { $script:tokens.Add($region2.token) }
        Assert 'ec-13b: a second run on the same input uses a different stop-commands token and the same verdict' (
            $null -ne $region -and $null -ne $region2 -and -not (Test-Same $region.token $region2.token) -and $r2.code -eq 1
        ) ("run2: " + (Format-Result $r2))
    }

    # ---------- ec-4: PR이 검사기를 약하게 고쳐도 기준 쪽 검사기가 돈다 · ec-4b: 기준에 스키마만 있고 검사기가 없으면 2 ----------
    Test-Group 'ec-4: base checker' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX; $checkerRel = $weakChecker }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert "ec-4: PR replaces check-compat.mjs with one that always exits 0 and removes field x -> still exit 1 with '$violationX…' and ""  검사기: 기준 커밋 …"" (the base checker ran)" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLinePrefix $r.lines '  검사기: 기준 커밋 ') -and -not (Test-Has $r.out '부트스트랩')
        ) (Format-Result $r)
        # r1의 기대(부트스트랩 → 1)는 이제 금지된 동작이다: 검사기를 지운 변경이 머지되면 다음 PR이 제 검사기로 돌게 된다
        $s = New-PrRepo @{ $schemaRel = $schemaBase } @{ $schemaRel = $schemaNoX; $checkerRel = $checkerText }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert 'ec-4b: base has schemas but no checker (the PR adds one and removes field x) -> exit 2 before any checker runs; the stderr reason says the base has schemas but no checker (bootstrap needs a base with neither)' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '있는데 검사기')
        ) (Format-Result $r)
    }

    # ---------- ec-5: 스키마 디렉터리 삭제 ----------
    Test-Group 'ec-5: schemas directory deleted' {
        $s = New-PrRepo $withChecker @{ $schemasDirRel = $null }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert "ec-5: PR deletes packages/events/schemas/ -> exit 1 (not 2), '$removedLine…', ""  변경 쪽 스키마: 없음 …""" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $removedLine) -and (Test-HasLinePrefix $r.lines '  변경 쪽 스키마: 없음')
        ) (Format-Result $r)
    }

    # ---------- ec-6 · ec-7: PR 전제(merge 커밋 · PR head) ----------
    Test-Group 'ec-6/7: PR preconditions' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.base }
        Assert 'ec-6: PR_HEAD_SHA is a real commit but not HEAD^2 -> exit 2, the checker does not run (no stop-commands line)' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and -not (Test-HasLinePrefix $r.lines '결과: 통과')
        ) (Format-Result $r)
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaAdded }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $p.head }
        Assert 'ec-6b: pull_request whose HEAD is not a merge commit (no HEAD^2) -> exit 2' ($r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::')) (Format-Result $r)
        foreach ($bad in @('not-a-sha', '', $s.pr.ToUpperInvariant(), $s.pr.Substring(0, 12))) {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $bad }
            Assert "ec-7: PR_HEAD_SHA '$bad' is not a full lowercase commit ID (40 or 64 hex) -> exit 2 and the stderr reason names PR_HEAD_SHA (format check, not the HEAD^2 mismatch)" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err 'PR_HEAD_SHA')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-8 · ec-9 · ec-10: push ----------
    Test-Group 'ec-8/9/10: push' {
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaNoX }
        foreach ($z in @($zero40, $zero64)) {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $z }
            Assert "ec-8: push with before = $($z.Length) zeros (new branch) -> empty baseline: exit 0, ""  기준: 빈 기준 …"", ""  검사기: 부트스트랩 …""" (
                $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '  기준: 빈 기준') -and (Test-HasLinePrefix $r.lines '  검사기: 부트스트랩') -and $r.out -notmatch $kindsRe
            ) (Format-Result $r)
        }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before }
        Assert "ec-9: push whose before still has field x -> exit 1, '$violationX…', ""  검사기: 기준 커밋 …""" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLinePrefix $r.lines '  검사기: 기준 커밋 ')
        ) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = '1234567890abcdef1234567890abcdef12345678' }
        Assert 'ec-10: push with a full commit ID that is not in the repository -> exit 2, the stderr reason says it is missing (이 저장소에 없다)' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '이 저장소에 없다')
        ) (Format-Result $r)
        foreach ($bad in @('HEAD~1', '', $p.before.Substring(0, 12))) {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $bad }
            Assert "ec-10: push with before '$bad' (not a full commit ID, or empty) -> exit 2 and the stderr reason names PUSH_BEFORE" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err 'PUSH_BEFORE')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-11 · ec-12b: 모르는 이벤트 ----------
    Test-Group 'ec-11: unknown event' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        $summary = Join-Path (New-TempDir 'evcompat-summary-') 'step-summary.md'
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'workflow_dispatch'; GITHUB_STEP_SUMMARY = (ConvertTo-BashPath $summary) }
        Assert 'ec-11: GITHUB_EVENT_NAME=workflow_dispatch -> exit 2 (only pull_request and push have a baseline rule)' ($r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::')) (Format-Result $r)
        $sum = if (Test-Path -LiteralPath $summary -PathType Leaf) { @([IO.File]::ReadAllLines($summary) | Where-Object { $_ -ne '' }) } else { @() }
        Assert 'ec-12b: the step summary still gets its three lines when the script stops early — the last one ends with exit 2' (
            $sum.Count -eq 3 -and $sum[0].StartsWith('- **기준** · ', [StringComparison]::Ordinal) -and $sum[2].StartsWith('- **결과** · ', [StringComparison]::Ordinal) -and $sum[2].EndsWith('exit 2', [StringComparison]::Ordinal)
        ) "summary: [$($sum -join ' / ')]"
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir))
        Assert 'ec-11b: no GITHUB_EVENT_NAME and no --base -> exit 2' ($r.code -eq 2) (Format-Result $r)
    }

    # ---------- ec-16 · ec-17 · ec-18 · ec-19: 사용법 · 도구 · --base · 예상 밖 종료 코드 ----------
    Test-Group 'ec-16: usage' {
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaNoX }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir), '--bogus') @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before }
        Assert 'ec-16: unknown argument -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Compat @('--root') @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before }
        Assert 'ec-16b: --root without a value -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath (Join-Path $p.dir 'no-such-dir'))) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before }
        Assert 'ec-16c: --root that does not exist -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $plain = New-TempDir 'evcompat-plain-'
        # 이 사례의 기대 결과가 git 위치 확인의 die다 — 다시 부르지 않는다(r5 F28)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $plain)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $zero40 } -NoLocationRetry
        Assert 'ec-16d: --root that is not a git work tree -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath (Join-Path $p.dir 'packages'))) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before }
        Assert 'ec-16e: --root that is a subdirectory of the work tree (not its top level) -> exit 2' ($r.code -eq 2) (Format-Result $r)
    }

    Test-Group 'ec-17: missing tools' {
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaNoX }
        $emptyBin = New-TempDir 'evcompat-emptybin-'
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before } $emptyBin
        Assert 'ec-17: PATH holding only an empty directory (no node) -> exit 2, never 0 (fail closed)' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $p.before; TMPDIR = (ConvertTo-BashPath (Join-Path $emptyBin 'no-such-dir')) }
        Assert 'ec-14b: TMPDIR that does not exist (mktemp fails) -> exit 2 — the script makes its work directory under TMPDIR, so ec-14 watches the right place' ($r.code -eq 2) (Format-Result $r)
    }

    Test-Group 'ec-18: --base' {
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaNoX }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir), '--base', $p.before)
        Assert "ec-18: --base <before commit> without any event variables -> exit 1, '$violationX…', ""  기준: 지정 커밋(--base) …""" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLinePrefix $r.lines '  기준: 지정 커밋(--base) ')
        ) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir), '--base', 'HEAD') @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = 'not-a-sha' }
        Assert 'ec-18b: --base HEAD wins over the event variables (bogus PR_HEAD_SHA is not read) -> exit 0' ($r.code -eq 0 -and $r.out -notmatch $kindsRe) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir), '--base', 'no-such-ref')
        Assert 'ec-18c: --base naming no commit -> exit 2' ($r.code -eq 2) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir), '--base', '--output=x')
        Assert 'ec-18d: --base value that looks like an option (--output=x) is not passed to git as an option -> exit 2' ($r.code -eq 2) (Format-Result $r)
    }

    Test-Group 'ec-19: unexpected checker exit code' {
        $s = New-PrRepo @{ $schemaRel = $schemaBase; $checkerRel = $oddChecker } @{ 'README.md' = "changed`n" }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert 'ec-19: the base checker exits 3 (neither 0, 1 nor 2) -> exit 2 and "결과: 오류 …" (never passed through as an unknown code, never 0)' (
            $r.code -eq 2 -and (Test-HasLinePrefix $r.lines '결과: 오류')
        ) (Format-Result $r)
    }

    # ---------- ec-21: GITHUB_ACTIONS=true이면 GITHUB_SHA = HEAD(--base와 무관 · r2 F2) ----------
    Test-Group 'ec-21: GITHUB_SHA' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX }
        $root = @('--root', (ConvertTo-BashPath $s.dir))
        $pr = @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        $r = Invoke-Compat $root ($pr + @{ GITHUB_ACTIONS = 'true'; GITHUB_SHA = $s.head })
        Assert "ec-21: GITHUB_ACTIONS=true and GITHUB_SHA = HEAD -> the normal verdict (field x removed: exit 1, '$violationX…')" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX)
        ) (Format-Result $r)
        $r = Invoke-Compat $root ($pr + @{ GITHUB_ACTIONS = 'true'; GITHUB_SHA = $s.base })
        Assert 'ec-21b: GITHUB_ACTIONS=true and GITHUB_SHA names another commit -> exit 2 before the checker runs, the stderr reason names GITHUB_SHA' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err 'GITHUB_SHA')
        ) (Format-Result $r)
        foreach ($bad in @('not-a-sha', $s.head.ToUpperInvariant(), $s.head.Substring(0, 12), '')) {
            $r = Invoke-Compat $root ($pr + @{ GITHUB_ACTIONS = 'true'; GITHUB_SHA = $bad })
            Assert "ec-21c: GITHUB_ACTIONS=true and GITHUB_SHA '$bad' (not a full lowercase commit ID, or unset) -> exit 2, the stderr reason names GITHUB_SHA" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err 'GITHUB_SHA')
            ) (Format-Result $r)
        }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir), '--base', $s.base) @{ GITHUB_ACTIONS = 'true'; GITHUB_SHA = $s.base }
        Assert 'ec-21d: --base does not skip the check — GITHUB_ACTIONS=true with a GITHUB_SHA other than HEAD -> exit 2' (
            $r.code -eq 2 -and (Test-Has $r.err 'GITHUB_SHA')
        ) (Format-Result $r)
        foreach ($ga in @('', 'false')) {
            $r = Invoke-Compat $root ($pr + @{ GITHUB_ACTIONS = $ga; GITHUB_SHA = $s.base })
            Assert "ec-21e: GITHUB_ACTIONS '$ga' (not true) -> GITHUB_SHA is not checked: the normal verdict exit 1" (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX)
            ) (Format-Result $r)
        }
    }

    # ---------- ec-22: 기준 트리의 .gitattributes(export-ignore)가 기준 스키마를 숨기지 못한다(r1 A-4 · B-3) ----------
    Test-Group 'ec-22: base .gitattributes' {
        $attr = "*.json export-ignore`n"
        foreach ($case in @(@('ec-22', 'packages/events/schemas/.gitattributes'), @('ec-22b', '.gitattributes'))) {
            $attrRel = $case[1]
            $s = New-PrRepo ($withChecker + @{ $attrRel = $attr; 'packages/events/schemas/README.md' = "기준 스키마 디렉터리의 .json이 아닌 파일(무시한다)`n" }) @{ $schemaRel = $schemaNoX }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            Assert "$($case[0]): the base $attrRel holds '*.json export-ignore' and the PR removes field x -> still exit 1 with '$violationX…' and the baseline label '(.json 1개)' (attributes never hide baseline schemas; non-.json entries are ignored)" (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-Has $r.out '(.json 1개)')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-23: 기준 트리의 모양(plumbing) — 경로 성분이 트리가 아니거나 .json이 일반 파일이 아니면 2(r1 A-4 · A-5 · B-3) ----------
    Test-Group 'ec-23: base tree shapes' {
        # 작업 트리(HEAD)는 정상(필드 x 삭제 + 실제 검사기) — 기준 커밋만 plumbing으로 만들어 --base로 준다. 판정 차이는 기준 모양에서만 온다.
        $p = New-PushRepo $withChecker @{ $schemaRel = $schemaNoX }
        $root = @('--root', (ConvertTo-BashPath $p.dir))
        $schemaEntry = @{ path = $schemaRel; mode = '100644'; content = $schemaBase }
        $checkerEntry = @{ path = $checkerRel; mode = '100644'; content = $checkerText }
        $control = New-PlumbingCommit $p.dir @($schemaEntry, $checkerEntry)
        $r = Invoke-Compat ($root + @('--base', $control))
        Assert "ec-23: control — a plumbing-built base with the schema and the checker as regular blobs -> exit 1 with '$violationX…' and ""  검사기: 기준 커밋 …"" (the helper builds trees the gate reads normally)" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLinePrefix $r.lines '  검사기: 기준 커밋 ')
        ) (Format-Result $r)
        $cases = @(
            @{ id = 'ec-23a'; what = 'packages/events is a symbolic link (120000) to a sibling directory with the schema and the checker'; needles = @('packages/events', '120000')
               entries = @(@{ path = 'packages/events'; mode = '120000'; content = 'events-real' }, @{ path = "packages/events-real/schemas/$schemaName"; mode = '100644'; content = $schemaBase }, @{ path = 'packages/events-real/scripts/check-compat.mjs'; mode = '100644'; content = $checkerText }) },
            @{ id = 'ec-23b'; what = 'packages/events/schemas is a regular file'; needles = @('packages/events/schemas', '100644')
               entries = @(@{ path = 'packages/events/schemas'; mode = '100644'; content = "not a directory`n" }, $checkerEntry) },
            @{ id = 'ec-23c'; what = 'packages/events/schemas is a gitlink (160000)'; needles = @('packages/events/schemas', '160000')
               entries = @(@{ path = 'packages/events/schemas'; mode = '160000'; content = $p.head }, $checkerEntry) },
            @{ id = 'ec-23d'; what = 'the checker is a symbolic link (120000)'; needles = @('check-compat.mjs', '120000')
               entries = @($schemaEntry, @{ path = $checkerRel; mode = '120000'; content = '../../../README.md' }) },
            @{ id = 'ec-23e'; what = 'schemas/x.json is a directory (tree)'; needles = @('x.json', '040000')
               entries = @($schemaEntry, @{ path = 'packages/events/schemas/x.json/inner.json'; mode = '100644'; content = "{}`n" }, $checkerEntry) },
            @{ id = 'ec-23f'; what = 'schemas/x.json is a symbolic link (120000)'; needles = @('x.json', '120000')
               entries = @($schemaEntry, @{ path = 'packages/events/schemas/x.json'; mode = '120000'; content = $schemaName }, $checkerEntry) },
            @{ id = 'ec-23g'; what = 'schemas holds a .json whose name is outside the allowed form (bad name.json — a space)'; needles = @('bad')
               entries = @($schemaEntry, @{ path = 'packages/events/schemas/bad name.json'; mode = '100644'; content = $schemaBase }, $checkerEntry) }
        )
        foreach ($c in $cases) {
            $commit = New-PlumbingCommit $p.dir $c.entries
            $r = Invoke-Compat ($root + @('--base', $commit))
            $missing = @($c.needles | Where-Object { -not (Test-Has $r.err $_) })
            Assert "$($c.id): base $($c.what) -> exit 2 before any checker runs, the stderr reason names $($c.needles -join ' + ')" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and $missing.Count -eq 0
            ) (Format-Result $r)
        }
    }

    # ---------- ec-24: 기준에 스키마(.json)도 검사기도 없으면 부트스트랩(r2 F3) ----------
    Test-Group 'ec-24: base with neither schemas nor checker' {
        $s = New-PrRepo @{ 'packages/events/package.json' = "{ `"name`": `"@jt/events`" }`n"; 'packages/events/schemas/.gitkeep' = ''; 'packages/events/schemas/README.md' = "스키마 자리`n" } @{ $schemaRel = $schemaBase; $checkerRel = $checkerText }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert 'ec-24: base has packages/events/schemas with non-.json files only and no checker -> bootstrap: exit 0, "  검사기: 부트스트랩 …", baseline label "(.json 0개)"' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '  검사기: 부트스트랩') -and (Test-Has $r.out '(.json 0개)') -and $r.out -notmatch $kindsRe
        ) (Format-Result $r)
    }

    # ---------- ec-25: 기준 객체를 읽지 못하면 2 — "없음"으로 보지 않는다(r1 B-3) ----------
    Test-Group 'ec-25: unreadable base objects' {
        foreach ($case in @(@('ec-25', 'packages/events/schemas'), @('ec-25b', 'packages/events'))) {
            $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX }
            $oid = Invoke-Git $s.dir @('rev-parse', "$($s.base):$($case[1])")
            Remove-LooseObject $s.dir $oid
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            Assert "$($case[0]): the base tree object of $($case[1]) is missing (its loose object file deleted) -> exit 2 before any checker runs (a failing git read is never 'absent')" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-26: 변경 쪽 경로 모양 — 파일이면 2 · 심볼릭 링크면 2(따라가지 않는다 · r1 A-5 · r2 F3) ----------
    Test-Group 'ec-26: head side shapes' {
        $d = New-Repo
        Set-RepoFiles $d (@{ 'README.md' = "events-compat fixture`n" } + $withChecker)
        [void](Save-Commit $d 'base')
        [void](Invoke-Git $d @('checkout', '-q', '-b', 'pr'))
        Set-RepoFiles $d @{ $schemasDirRel = $null }
        Set-RepoFiles $d @{ 'packages/events/schemas' = "not a directory`n" }
        $prSha = Save-Commit $d 'pr'
        [void](Invoke-Git $d @('checkout', '-q', 'main'))
        [void](Invoke-Git $d @('merge', '-q', '--no-ff', '--no-edit', '-m', 'merge pr', 'pr'))
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $d)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $prSha }
        Assert 'ec-26: the head packages/events/schemas is a regular file (committed by the PR) -> exit 2 before any checker runs, the stderr reason names packages/events/schemas' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err 'packages/events/schemas')
        ) (Format-Result $r)
        foreach ($case in @(@('ec-26b', 'packages/events'), @('ec-26c', 'packages/events/schemas'))) {
            $s = New-PrRepo $withChecker @{ 'README.md' = "changed`n" }
            $link = Join-Path $s.dir $case[1]
            $target = $link + '-real'
            Move-Item -LiteralPath $link -Destination $target
            $made = New-SymLink $link $target
            if (-not $made.ok) {
                $script:dirty[$s.dir] = Get-RepoStatus $s.dir
                Skip-Assert $case[0] "cannot create a symbolic link on this machine: $($made.reason)"
                continue
            }
            $script:dirty[$s.dir] = Get-RepoStatus $s.dir
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            Assert "$($case[0]): the head $($case[1]) is a symbolic link (to a directory with the same content) -> exit 2 before any checker runs, the stderr reason names $($case[1]) — the gate does not follow it" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err "$($case[1])가 심볼릭 링크")
            ) (Format-Result $r)
        }
    }

    # ---------- ec-26d..l: 변경 쪽 모양 = 다음 기준의 모양(r3 F11 · B2-3 · A2-1 · r4 F19 · B3-3 i) — 로컬(작업 트리)과 CI(HEAD 커밋) 각각 ----------
    # 머지되면 다음 기준이 될 트리가 기준 꺼내기에서 2가 되는 모양이면 머지 전에 2(검사기 실행 전). 검사기 경로의 모양(경로 성분 = 디렉터리 ·
    # 검사기 = 일반 파일)은 스키마 수와 상관없이 보고, 검사기가 없는 것은 변경 쪽에 스키마가 있을 때만 2다.
    Test-Group 'ec-26d: head schema name outside the allowed form' {
        # [이름, 사유에 있어야 할 글자, id 꼬리] — r4 F20: 점으로 시작하는 이름(.x.json)도 꼴 밖이다(로컬 작업 트리 열거는 dotglob)
        foreach ($case in @(@('bad name.json', 'bad', ''), @('.x.json', '.x.json', ', dot name'))) {
            $s = New-PrRepo $withChecker @{ "packages/events/schemas/$($case[0])" = $schemaBase }
            foreach ($mode in @('local', 'CI')) {
                $envSet = @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
                if (Test-Same $mode 'CI') { $envSet = Add-CiEnv $envSet $s.head }
                $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) $envSet
                Assert "ec-26d ($mode$($case[2])): the PR adds packages/events/schemas/'$($case[0])' (outside the allowed name form) -> exit 2 before any checker runs, the stderr reason names the change-side schema name (변경 쪽 스키마 이름 … $($case[1]))" (
                    $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '변경 쪽 스키마 이름') -and (Test-Has $r.err $case[1])
                ) (Format-Result $r)
            }
        }
    }

    Test-Group 'ec-26e: head schemas without a checker' {
        $s = New-PrRepo $withChecker @{ $checkerRel = $null }
        foreach ($mode in @('local', 'CI')) {
            $envSet = @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            if (Test-Same $mode 'CI') { $envSet = Add-CiEnv $envSet $s.head }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) $envSet
            Assert "ec-26e ($mode): the PR keeps the schema but deletes packages/events/scripts/check-compat.mjs -> exit 2 before any checker runs (the base checker would pass it), the stderr reason says the change side has schemas but no regular-file checker (일반 파일로 없다)" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '일반 파일로 없다')
            ) (Format-Result $r)
        }
    }

    Test-Group 'ec-26f: head checker is a symbolic link' {
        # CI: push before = 정상 기준 · after = 검사기 항목을 plumbing으로 120000(심볼릭 링크)로 둔 커밋(작업 트리는 reset --hard로 맞춘다)
        $d = New-Repo
        Set-RepoFiles $d (@{ 'README.md' = "events-compat fixture`n" } + $withChecker)
        $before = Save-Commit $d 'before'
        Set-RepoFiles $d @{ 'packages/events/scripts/check-compat.real.mjs' = $checkerText }
        [void](Invoke-Git $d @('add', '-A'))
        Set-IndexEntry $d $checkerRel '120000' 'check-compat.real.mjs'
        [void](Invoke-Git $d @('commit', '-q', '-m', 'after'))
        [void](Invoke-Git $d @('reset', '-q', '--hard'))
        $after = Invoke-Git $d @('rev-parse', 'HEAD')
        $lsEntry = Invoke-Git $d @('ls-tree', 'HEAD', '--', $checkerRel)
        $script:dirty[$d] = Get-RepoStatus $d
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $d)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $before } $after)
        # r4 F19: 검사기가 일반 파일이 아닌 모양은 스키마 수와 상관없이 같은 사유(다음 기준의 모양이 아니다)다 — r3의 '일반 파일로 없다'는
        # 검사기가 없을 때(ec-26e)만 남는다
        Assert "ec-26f (CI): the pushed HEAD commit holds packages/events/scripts/check-compat.mjs as a symbolic link (mode 120000 — control: ls-tree '$lsEntry') and keeps the schema -> exit 2 before any checker runs, the stderr reason says the change-side checker path is not the next baseline's shape (다음 기준의 모양) and names 120000" (
            $lsEntry.StartsWith('120000 ', [StringComparison]::Ordinal) -and $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '다음 기준의 모양') -and (Test-Has $r.err '120000')
        ) (Format-Result $r)

        # 로컬: 작업 트리의 검사기를 실제 파일 심볼릭 링크로 바꾼다(만들 수 없으면 이 단언만 SKIP)
        $s = New-PrRepo $withChecker @{ 'README.md' = "changed`n" }
        $link = Join-Path $s.dir $checkerRel
        $target = Join-Path $s.dir 'packages/events/scripts/check-compat.real.mjs'
        Move-Item -LiteralPath $link -Destination $target
        $made = New-SymLink $link $target
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        if (-not $made.ok) {
            Skip-Assert 'ec-26f (local)' "cannot create a symbolic link on this machine: $($made.reason)"
        } else {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            Assert 'ec-26f (local): the work-tree packages/events/scripts/check-compat.mjs is a symbolic link (to a file with the real checker) and the schema stays -> exit 2 before any checker runs, the stderr reason says the change-side checker path is not the next baseline''s shape (다음 기준의 모양) and names the symbolic link (심볼릭 링크)' (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '다음 기준의 모양') -and (Test-Has $r.err '심볼릭 링크')
            ) (Format-Result $r)
        }
    }

    Test-Group 'ec-26g: head packages/events/scripts is a file' {
        $d = New-Repo
        Set-RepoFiles $d (@{ 'README.md' = "events-compat fixture`n" } + $withChecker)
        [void](Save-Commit $d 'base')
        [void](Invoke-Git $d @('checkout', '-q', '-b', 'pr'))
        Set-RepoFiles $d @{ 'packages/events/scripts/' = $null }
        Set-RepoFiles $d @{ 'packages/events/scripts' = "not a directory`n" }
        $prSha = Save-Commit $d 'pr'
        [void](Invoke-Git $d @('checkout', '-q', 'main'))
        [void](Invoke-Git $d @('merge', '-q', '--no-ff', '--no-edit', '-m', 'merge pr', 'pr'))
        $head = Invoke-Git $d @('rev-parse', 'HEAD')
        foreach ($mode in @('local', 'CI')) {
            $envSet = @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $prSha }
            if (Test-Same $mode 'CI') { $envSet = Add-CiEnv $envSet $head }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $d)) $envSet
            Assert "ec-26g ($mode): the PR turns packages/events/scripts into a regular file and keeps the schema -> exit 2 before any checker runs, the stderr reason names the change side and packages/events/scripts" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '변경 쪽') -and (Test-Has $r.err 'packages/events/scripts')
            ) (Format-Result $r)
        }
    }

    Test-Group 'ec-26h: head with neither schemas nor checker' {
        $s = New-PrRepo $withChecker @{ 'packages/events/' = $null }
        foreach ($mode in @('local', 'CI')) {
            $envSet = @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
            if (Test-Same $mode 'CI') { $envSet = Add-CiEnv $envSet $s.head }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) $envSet
            Assert "ec-26h ($mode): the PR deletes packages/events (schemas and checker) -> a missing checker is exit 2 only when the change side has schemas: exit 1 with '$removedLine…' and ""  변경 쪽 스키마: 없음 …"" (the base checker ran)" (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $removedLine) -and (Test-HasLinePrefix $r.lines '  변경 쪽 스키마: 없음') -and (Test-HasLinePrefix $r.lines '  검사기: 기준 커밋 ')
            ) (Format-Result $r)
        }
    }

    # r4 F19(리뷰 r3 B3-3 i): 기준 = 검사기만 있고 스키마가 0개인 커밋(plumbing · --base) — 변경 쪽에 스키마가 없어도 검사기 경로가 다음 기준의
    # 모양이 아니면 2다(머지되면 다음 기준 꺼내기가 그 경로에서 2가 되고, 되돌리는 PR까지 막힌다)
    Test-Group 'ec-26j: head packages/events/scripts is a file, no schemas' {
        $d = New-Repo
        Set-RepoFiles $d @{ 'README.md' = "events-compat fixture`n"; 'packages/events/scripts' = "not a directory`n" }
        $head = Save-Commit $d 'head'
        $base = New-PlumbingCommit $d @(@{ path = $checkerRel; mode = '100644'; content = $checkerText })
        foreach ($mode in @('local', 'CI')) {
            $envSet = if (Test-Same $mode 'CI') { Add-CiEnv @{} $head } else { @{} }
            # CI는 HEAD 트리에서 경로를 내려가다 성분이 트리가 아니면 그 자리에서 2(공통 resolve_path) · 로컬은 작업 트리 성분의 종류를 적는다
            $needles = if (Test-Same $mode 'CI') { @('변경 쪽 커밋의 packages/events/scripts', '100644') } else { @('다음 기준의 모양', '작업 트리의 packages/events/scripts: 일반 파일') }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $d), '--base', $base) $envSet
            $missing = @($needles | Where-Object { -not (Test-Has $r.err $_) })
            Assert "ec-26j ($mode): base = the checker only, no schemas (plumbing, --base); the change side turns packages/events/scripts into a regular file and has no schemas -> exit 2 before any checker runs (merged, the next baseline would exit 2), the stderr reason gives the checker path detail ($($needles -join ' + '))" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and $missing.Count -eq 0
            ) (Format-Result $r)
        }
    }

    Test-Group 'ec-26k: head checker is a symbolic link, no schemas' {
        # CI: HEAD 커밋의 검사기 항목을 plumbing으로 120000(심볼릭 링크)로 둔다(작업 트리는 reset --hard로 맞춘다)
        $d = New-Repo
        Set-RepoFiles $d @{ 'README.md' = "events-compat fixture`n"; 'packages/events/scripts/check-compat.real.mjs' = $checkerText }
        [void](Invoke-Git $d @('add', '-A'))
        Set-IndexEntry $d $checkerRel '120000' 'check-compat.real.mjs'
        [void](Invoke-Git $d @('commit', '-q', '-m', 'head'))
        [void](Invoke-Git $d @('reset', '-q', '--hard'))
        $head = Invoke-Git $d @('rev-parse', 'HEAD')
        $lsEntry = Invoke-Git $d @('ls-tree', 'HEAD', '--', $checkerRel)
        $base = New-PlumbingCommit $d @(@{ path = $checkerRel; mode = '100644'; content = $checkerText })
        $script:dirty[$d] = Get-RepoStatus $d
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $d), '--base', $base) (Add-CiEnv @{} $head)
        Assert "ec-26k (CI): base = the checker only, no schemas (plumbing, --base); the HEAD commit holds packages/events/scripts/check-compat.mjs as a symbolic link (mode 120000 — control: ls-tree '$lsEntry') and has no schemas -> exit 2 before any checker runs, the stderr reason says the change-side checker path is not the next baseline's shape (다음 기준의 모양) and names 120000" (
            $lsEntry.StartsWith('120000 ', [StringComparison]::Ordinal) -and $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '다음 기준의 모양') -and (Test-Has $r.err '120000')
        ) (Format-Result $r)

        # 로컬: 작업 트리의 검사기를 실제 파일 심볼릭 링크로 둔다(만들 수 없으면 이 단언만 SKIP)
        $s = New-Repo
        Set-RepoFiles $s @{ 'README.md' = "events-compat fixture`n"; 'packages/events/scripts/check-compat.real.mjs' = $checkerText }
        [void](Save-Commit $s 'head')
        $sBase = New-PlumbingCommit $s @(@{ path = $checkerRel; mode = '100644'; content = $checkerText })
        $made = New-SymLink (Join-Path $s $checkerRel) (Join-Path $s 'packages/events/scripts/check-compat.real.mjs')
        $script:dirty[$s] = Get-RepoStatus $s
        if (-not $made.ok) {
            Skip-Assert 'ec-26k (local)' "cannot create a symbolic link on this machine: $($made.reason)"
        } else {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s), '--base', $sBase)
            Assert 'ec-26k (local): base = the checker only, no schemas (plumbing, --base); the work-tree packages/events/scripts/check-compat.mjs is a symbolic link (to a file with the real checker) and there are no schemas -> exit 2 before any checker runs, the stderr reason says the change-side checker path is not the next baseline''s shape (다음 기준의 모양) and names the symbolic link (심볼릭 링크)' (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '다음 기준의 모양') -and (Test-Has $r.err '심볼릭 링크')
            ) (Format-Result $r)
        }
    }

    # 남은 부트스트랩 갈래(검사기 없음): 빈 기준이고 변경 쪽에도 스키마도 검사기도 없으면 2
    Test-Group 'ec-26l: empty baseline, head with neither schemas nor checker' {
        $p = New-PushRepo @{} @{ 'README.md' = "changed`n" }
        foreach ($mode in @('local', 'CI')) {
            $envSet = @{ GITHUB_EVENT_NAME = 'push'; PUSH_BEFORE = $zero40 }
            if (Test-Same $mode 'CI') { $envSet = Add-CiEnv $envSet $p.head }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $p.dir)) $envSet
            Assert "ec-26l ($mode): empty baseline (push before = 40 zeros) and the change side has neither schemas nor a checker -> exit 2 before any checker runs, the stderr reason says there is no checker anywhere (검사기가 없다 — 기준에도 …: the bootstrap branch that remains)" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '검사기가 없다 — 기준에도')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-27: 검사기 출력 계약 — 요약 줄이 없거나 종료 코드와 맞지 않으면 2(r1 A-6 · r2 F4) ----------
    Test-Group 'ec-27: checker output contract' {
        $cases = @(
            @{ id = 'ec-27'; what = 'has a syntax error (node cannot load it: exit 1 with an error and a stack)'; checker = $fakeSyntax; loader = $true },
            @{ id = 'ec-27b'; what = 'prints nothing and exits 0'; checker = $fakeSilent0; loader = $false },
            @{ id = 'ec-27c'; what = 'prints a violation line but no summary line and exits 1'; checker = $fakeNoSummary1; loader = $false },
            @{ id = 'ec-27d'; what = 'prints "violations 0" and exits 1'; checker = $fakeZeroButOne; loader = $false },
            @{ id = 'ec-27e'; what = 'prints "violations 2" with one violation line and exits 1'; checker = $fakeCountMismatch; loader = $false },
            @{ id = 'ec-27f'; what = 'prints "violations 0" and exits 0 but writes a violation line to stdout'; checker = $fakeStdoutOn0; loader = $false },
            @{ id = 'ec-27g'; what = 'prints the summary line twice and exits 0'; checker = $fakeTwoSummaries; loader = $false }
        )
        foreach ($c in $cases) {
            $s = New-PrRepo @{ $schemaRel = $schemaBase; $checkerRel = $c.checker } @{ 'README.md' = "changed`n" }
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } -LoaderError:([bool]$c.loader)
            Assert "$($c.id): the base checker $($c.what) -> exit 2 and ""결과: 오류 — 검사기 출력이 CLI 계약과 다르다 …"" inside a complete stop-commands region (never read as a pass or a violation)" (
                $r.code -eq 2 -and (Test-HasLinePrefix $r.lines '결과: 오류') -and (Test-Has $r.out 'CLI 계약') -and -not (Test-HasLinePrefix $r.lines '결과: 통과') -and -not (Test-HasLinePrefix $r.lines '결과: 실패') -and $null -ne (Get-StopRegion $r.lines)
            ) (Format-Result $r)
        }
    }

    # ---------- ec-28: replace ref는 기준 검사기를 바꾸지 못한다(GIT_NO_REPLACE_OBJECTS=1 · r1 B-1 ② · r2 F2) ----------
    Test-Group 'ec-28: replace refs' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX }
        $realOid = Invoke-Git $s.dir @('rev-parse', "$($s.base):$checkerRel")
        $weakFile = Join-Path (New-TempDir 'evcompat-blob-') 'weak.mjs'
        [IO.File]::WriteAllText($weakFile, $replaceChecker, [Text.UTF8Encoding]::new($false))
        $weakOid = Invoke-Git $s.dir @('hash-object', '-w', '--no-filters', '--', $weakFile)
        [void](Invoke-Git $s.dir @('replace', $realOid, $weakOid))
        $active = Test-Has (Invoke-Git $s.dir @('cat-file', 'blob', $realOid)) 'EVCOMPAT-WEAK'
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr }
        Assert "ec-28: a replace ref swaps the base checker blob for one that hides violations (control: plain git now reads the weak blob) -> the gate still runs the real base checker: exit 1 with '$violationX…'" (
            $active -and $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX)
        ) ("replace active for plain git: $active; " + (Format-Result $r))
    }

    # ---------- ec-29: CI의 변경 쪽 = HEAD 커밋 객체 + 작업 트리 바이트 일치(r3 F10 · B2-2) ----------
    Test-Group 'ec-29: change side bytes (.gitattributes ident)' {
        # PR이 packages/events/schemas/.gitattributes에 '*.json ident'를 더하고 description에 $Id$를 넣는다(메타데이터만). 스키마 파일을
        # 지우고 git checkout -- <경로>로 다시 쓰면 작업 트리는 '$Id: <blob oid> $'가 된다(체크아웃이 속성으로 바꾼 바이트).
        $s = New-PrRepo $withChecker @{ 'packages/events/schemas/.gitattributes' = "*.json ident`n"; $schemaRel = $schemaIdent }
        $wt = Join-Path $s.dir $schemaRel
        Remove-Item -LiteralPath $wt -Force
        [void](Invoke-Git $s.dir @('checkout', '--', $schemaRel))
        $expanded = Test-Has ([IO.File]::ReadAllText($wt)) '"description": "$Id: '
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
        Assert "ec-29 (CI): the PR adds '*.json ident' + a `$Id`$ description and the checkout writes '`$Id: <oid> `$' (control: expanded in the work tree = $expanded) -> exit 2 before any checker runs, the stderr reason names the work tree (작업 트리) and the schema" (
            $expanded -and $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '작업 트리') -and (Test-Has $r.err $schemaName)
        ) (Format-Result $r)
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir), '--base', $s.base)
        Assert 'ec-29e (local): the same fixture without GITHUB_ACTIONS (--base) reads the work tree -> a metadata-only change: exit 0, "결과: 통과", "  변경 쪽 스키마: packages/events/schemas(.json 1개)" — CI and local differ on purpose' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '결과: 통과') -and (Test-HasLine $r.lines '  변경 쪽 스키마: packages/events/schemas(.json 1개)') -and $r.out -notmatch $kindsRe
        ) (Format-Result $r)
    }

    Test-Group 'ec-29b/c: work tree differs from the HEAD commit' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        Set-RepoFiles $s.dir @{ 'packages/events/schemas/extra.json' = $schemaBase }
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
        Assert 'ec-29b (CI): an untracked packages/events/schemas/extra.json exists only in the work tree -> exit 2 before any checker runs, the stderr reason names the work tree and extra.json' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '작업 트리') -and (Test-Has $r.err 'extra.json')
        ) (Format-Result $r)
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        Set-RepoFiles $s.dir @{ $schemaRel = $schemaNoX }
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
        Assert 'ec-29c (CI): the work-tree schema is edited after the commit (uncommitted — field x removed, the commit only adds a field) -> exit 2 before any checker runs (neither the commit verdict 0 nor the work-tree verdict 1), the stderr reason names the work tree' (
            $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '작업 트리')
        ) (Format-Result $r)
    }

    Test-Group 'ec-29d/f: CI change side from the HEAD commit' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaNoX }
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
        $headLine = "  변경 쪽 스키마: HEAD 커밋 $($s.head.Substring(0, 12)):packages/events/schemas(.json 1개 · 작업 트리 바이트 일치)"
        Assert "ec-29d (CI): committed work tree identical to the HEAD commit (no .gitattributes) -> the normal verdict (field x removed: exit 1, '$violationX…') and the header line '$headLine'" (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $violationX) -and (Test-HasLine $r.lines $headLine)
        ) (Format-Result $r)
        # 부트스트랩(CI): 검사기는 HEAD 커밋의 blob — 작업 트리의 검사기(커밋하지 않은 수정: exit 3으로 끝나는 검사기)는 쓰지 않는다
        $s = New-PrRepo @{} $withChecker
        Set-RepoFiles $s.dir @{ $checkerRel = $oddChecker }
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
        Assert 'ec-29f (CI): bootstrap PR whose work-tree checker was replaced after the commit by one that exits 3 -> the HEAD commit''s checker blob runs: exit 0, "  검사기: 부트스트랩 … HEAD 커밋 …", "결과: 통과"' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines '  검사기: 부트스트랩') -and (Test-Has (@($r.lines | Where-Object { $_.StartsWith('  검사기: ', [StringComparison]::Ordinal) }) -join "`n") 'HEAD 커밋') -and (Test-HasLinePrefix $r.lines '결과: 통과')
        ) (Format-Result $r)
    }

    # r4 F20(리뷰 r3 A3-2): 바이트 대조의 '일반 파일 아님' 갈래 — 링크는 대상이 같은 바이트여도 받지 않는다(hash-object는 링크를 따라
    # 대상 내용을 해시하므로 이 갈래가 없으면 통과한다)
    Test-Group 'ec-29g: work-tree schema is a symbolic link (CI)' {
        $s = New-PrRepo $withChecker @{ $schemaRel = $schemaAdded }
        $wt = Join-Path $s.dir $schemaRel
        $target = Join-Path $s.dir 'schema-copy.txt'
        Move-Item -LiteralPath $wt -Destination $target
        $made = New-SymLink $wt $target
        $script:dirty[$s.dir] = Get-RepoStatus $s.dir
        if (-not $made.ok) {
            Skip-Assert 'ec-29g (CI)' "cannot create a symbolic link on this machine: $($made.reason)"
        } else {
            $r = Invoke-Compat @('--root', (ConvertTo-BashPath $s.dir)) (Add-CiEnv @{ GITHUB_EVENT_NAME = 'pull_request'; PR_HEAD_SHA = $s.pr } $s.head)
            Assert "ec-29g (CI): after the commit the work-tree schema is replaced by a symbolic link to a file with the same bytes -> exit 2 before any checker runs, the stderr reason says the work-tree $schemaName is not a regular file (작업 트리 … 일반 파일이 아니다)" (
                $r.code -eq 2 -and -not (Test-HasLinePrefix $r.lines '::stop-commands::') -and (Test-Has $r.err '작업 트리') -and (Test-Has $r.err $schemaName) -and (Test-Has $r.err '일반 파일이 아니다')
            ) (Format-Result $r)
        }
    }

    # ---------- ec-14 · ec-15 · ec-20: 모든 실행 뒤 ----------
    Test-Group 'ec-14/15/20: after all runs' {
        Assert "ec-14: no run left anything in its TMPDIR or an events-compat.* entry in the system temp directory ($($script:runs) runs)" (
            $script:runs -ge 60 -and $script:leftovers.Count -eq 0
        ) ('leftovers: ' + ($script:leftovers -join ' | '))

        $dirtyNow = @()
        foreach ($d in $script:repos) {
            $st = Get-RepoStatus $d
            $want = if ($script:dirty.ContainsKey($d)) { [string]$script:dirty[$d] } else { '' }
            if (-not (Test-Same $st $want)) { $dirtyNow += "$([IO.Path]::GetFileName($d)): [$($st -replace "`n", '; ')] expected [$($want -replace "`n", '; ')]" }
        }
        Assert "ec-15: every fixture work tree is unchanged by the runs (git status --porcelain --ignored --untracked-files=all is empty in all $($script:repos.Count) repositories, or equal to its snapshot taken before the run for the $($script:dirty.Count) fixtures whose work tree was changed on purpose)" (
            $script:repos.Count -ge 25 -and $dirtyNow.Count -eq 0
        ) ('changed: ' + ($dirtyNow -join ' | '))

        $needles = [Collections.Generic.List[string]]::new()
        foreach ($t in $script:temps) { $needles.Add([IO.Path]::GetFileName($t.TrimEnd('\', '/'))) }
        $tmp = [IO.Path]::GetTempPath().TrimEnd('\', '/')
        foreach ($p in @($tmp, $repo)) {
            $needles.Add($p)
            $needles.Add(($p -replace '\\', '/'))
            if ($p -match '^([A-Za-z]):[\\/](.*)$') { $needles.Add('/' + $Matches[1].ToLowerInvariant() + '/' + ($Matches[2] -replace '\\', '/')) }
        }
        $hits = @()
        foreach ($o in $script:outputs) { foreach ($n in $needles) { if ($n -and $o.IndexOf($n, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits += $n } } }
        Assert "ec-20: no output of any run ($($script:outputs.Count) runs) contains an absolute path — fixture or temp directories or the repository root, in POSIX or Windows form ($($script:exempt) run(s) with an expected node loader error: only the lines outside the stop-commands region and stderr are checked)" (
            $script:outputs.Count -ge 60 -and $hits.Count -eq 0
        ) ('found: ' + (@($hits | Select-Object -Unique) -join ' | '))
    }
} finally {
    foreach ($n in $gitEnvNames) { Set-EnvVar $n $savedGitEnv[$n] }
    foreach ($t in $script:temps) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

$overrides = @()
if ($scriptOverride) { $overrides += 'EVENTS_COMPAT_SCRIPT' }
if ($ciOverride) { $overrides += 'EVENTS_COMPAT_CI' }
$suffix = if ($overrides.Count -gt 0) { " (override: $($overrides -join ', '))" } else { '' }
$notes = @()
if ($script:gitRetries -gt 0) { $notes += "note: fixture git calls retried after exit -1 with no output: $($script:gitRetries)" }
if ($script:gitSelfPathRetries -gt 0) { $notes += "note: retried $($script:gitSelfPathRetries) fixture-git self-path failure(s) (non-zero exit and exactly one output line: git: '<the fixture git path>' is not a git command — git stops before running a subcommand, so the fixture is unchanged; cause unknown; verdict assertions unchanged)" }
if ($script:compatRetries -gt 0) { $notes += "note: retried $($script:compatRetries) spawn failure(s) of the script under test (exit -1 with empty stdout and stderr — not a verdict: the script exits 0, 1 or 2; verdict assertions unchanged)" }
if ($script:locationRetries -gt 0) { $notes += "note: retried $($script:locationRetries) git-location failure(s) of the script under test (exit 2, empty stdout and exactly one stderr line: its --root git work-tree / git-location die — no assertion expects that line, ec-16d is not retried; verdict assertions unchanged)" }
if ($notes.Count -gt 0) { Write-Host ("`n" + ($notes -join "`n")) }
if ($script:skips.Count -gt 0) { Write-Host "`n$($script:skips.Count) skipped (not counted as passed): $($script:skips -join ', ')" }
# 실패한 id는 요약 줄 바로 앞의 한 줄로도 남긴다(로그가 잘려도 무엇이 깨졌는지 보인다 — SKIP 목록 줄과 같은 꼴)
if ($script:failedIds.Count -gt 0) { Write-Host "`nfailed: $($script:failedIds -join ', ')"; Write-Host "$($script:pass) passed, $($script:fail) failed$suffix" }
else { Write-Host "`n$($script:pass) passed, $($script:fail) failed$suffix" }
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
