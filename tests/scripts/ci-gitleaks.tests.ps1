# .github/workflows/ci.yml job gitleaks 정적 검사(T049 AC5). Run: pwsh -NoProfile -File tests/scripts/ci-gitleaks.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 · 외부 도구 없음(파일을 줄 단위로 읽는다 — YAML 파서 없이,
# tests/scripts/kubeconform-deploy.tests.ps1의 Get-JobBlock · Get-RunBodies와 같은 방식). SKIP 없이 fail closed(파일 부재 = 전 단언 FAIL).
# 무엇을 지키는가: job id `gitleaks`가 ruleset(main)의 required check 이름이라는 것, 액션(gitleaks-action — PR 커밋 30개 한계)으로
#   되돌아가지 않는다는 것, 버전과 sha256이 한 쌍으로 고정돼 있다는 것, 범위(--log-opts)와 기대 커밋 수가 같은 옵션(--remerge-diff 포함)으로
#   세어져 대조된다는 것, 탐지 설정을 워크플로가 고정한다는 것(--config · --ignore-gitleaks-allow · 작업 트리의 .gitleaks.toml ·
#   .gitleaksignore 존재 시 실패), 내려받기가 리다이렉트까지 https뿐이라는 것(--proto · --proto-redir), PR 이벤트의 head 확인(조상 +
#   둘째 부모 · 오류 문구는 %q), 출력이 --redact라는 것, 요약 다섯 줄이 남는다는 것.
# 환경 변수: CI_GITLEAKS_WORKFLOW — 검사할 워크플로 파일(기본 .github/workflows/ci.yml) — 변이 시험에서 사본을 가리킬 때 쓴다.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$ciPath = if (-not [string]::IsNullOrEmpty($env:CI_GITLEAKS_WORKFLOW)) { $env:CI_GITLEAKS_WORKFLOW } else { Join-Path $repo '.github/workflows/ci.yml' }
$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}
# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-Has([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Get-Count([string]$text, [string]$needle) { $n = 0; $i = 0; while (($i = $text.IndexOf($needle, $i, [StringComparison]::Ordinal)) -ge 0) { $n++; $i += $needle.Length }; return $n }

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

$ci = if (Test-Path -LiteralPath $ciPath -PathType Leaf) { [IO.File]::ReadAllText($ciPath) } else { '' }
$ciLines = @($ci -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
$job = Get-JobBlock $ciLines 'gitleaks'
$jobText = $job -join "`n"
$runs = Get-RunBodies $job
$runText = $runs -join "`n"
$runLines = @($runText -split "`n" | ForEach-Object { $_.Trim() })
# 첫 run: 본문 = 설치 스텝, 둘째 = 스캔 스텝(job의 스텝 순서)
$installBody = if ($runs.Count -ge 1) { $runs[0] } else { '' }
$installLines = @($installBody -split "`n" | ForEach-Object { $_.Trim() })
$scanBody = if ($runs.Count -ge 2) { $runs[1] } else { '' }
$scanLines = @($scanBody -split "`n" | ForEach-Object { $_.Trim() })

Assert 'g-1: ci.yml has job "gitleaks" under jobs: and the job sets no name: of its own (the ruleset required check is the job id)' (
    $job.Count -gt 0 -and @($job | Where-Object { $_ -match '^    name:' }).Count -eq 0
) "job lines: $($job.Count); file: $ciPath"

$uses = @($job | ForEach-Object { [regex]::Match($_, '^\s*(-\s+)?uses:\s*(\S+)') } | Where-Object { $_.Success } | ForEach-Object { $_.Groups[2].Value })
$notCheckout = @($uses | Where-Object { $_ -notmatch '^actions/checkout@[0-9a-f]{40}$' })
Assert 'g-2: the only action in job gitleaks is actions/checkout pinned to a 40-hex SHA (no gitleaks-action, no other third-party action)' (
    $job.Count -gt 0 -and $uses.Count -eq 1 -and $notCheckout.Count -eq 0 -and -not (Test-Has $jobText 'gitleaks-action')
) "uses: [$($uses -join ', ')]"

Assert 'g-3: job gitleaks: runs-on ubuntu-24.04-arm, timeout-minutes 10, fetch-depth: 0, persist-credentials: false, no secrets.*, no continue-on-error' (
    $jobText -match '(?m)^    runs-on: ubuntu-24\.04-arm\s*$' -and $jobText -match '(?m)^    timeout-minutes: 10(\s|$)' -and $jobText -match '(?m)^\s+fetch-depth: 0\s*$' -and $jobText -match '(?m)^\s+persist-credentials: false\s*$' -and -not (Test-Has $jobText 'secrets.') -and -not (Test-Has $jobText 'continue-on-error')
) "job block: [$jobText]"

$pins = @('^\s+GITLEAKS_VERSION:\s*8\.30\.1\s*$', '^\s+GITLEAKS_SHA256:\s*e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080\s*$')
$missingPins = @($pins | Where-Object { $p = $_; @($job | Where-Object { $_ -match $p }).Count -ne 1 })
Assert 'g-4: job gitleaks pins GITLEAKS_VERSION 8.30.1 and the linux_arm64 sha256 (gitops validate.yml step 3 value) in env:, one line each' (
    $job.Count -gt 0 -and $missingPins.Count -eq 0
) "missing or duplicated: $($missingPins -join ' | ')"

$install = @(
    'curl -fsSL',
    '--retry 3 --connect-timeout 10 --max-time 120',
    'sha256sum -c',
    'gitleaks_${GITLEAKS_VERSION}_linux_arm64.tar.gz',
    '$RUNNER_TEMP/bin',
    'chmod 0755'
)
$missingInstall = @($install | Where-Object { -not (Test-Has $installBody $_) })
$verCheck = @($installLines | Where-Object { $_ -match '^got=\$\("\$bin/gitleaks" version' }).Count
Assert 'g-5: the install step downloads with the pinned curl flags, verifies sha256sum -c, extracts into $RUNNER_TEMP/bin and checks "gitleaks version" against GITLEAKS_VERSION' (
    $runs.Count -ge 2 -and $missingInstall.Count -eq 0 -and $verCheck -eq 1 -and (Test-Has $installBody '!= "$GITLEAKS_VERSION"')
) "missing: [$($missingInstall -join ' | ')]; version-check lines: $verCheck"

# 범위 옵션은 gitleaks 호출(--log-opts)과 기대 커밋 수의 git log --numstat에 같은 문자열로 들어가야 한다 — --remerge-diff 포함
# (머지의 충돌 해결 내용이 스캔되고, 셈이 양쪽에서 같게 유지된다)
$opts = '--all --full-history --diff-filter=uxdb --remerge-diff'
$glCall = @($scanLines | Where-Object { $_ -match '^"\$gl" git ' })
$numstat = @($scanLines | Where-Object { $_ -match '^git .*log --numstat ' })
Assert 'g-6: exactly one gitleaks call, with --redact, --no-color and --log-opts naming the whole-history range incl. --remerge-diff; the expected count uses the same range options on git log --numstat' (
    $glCall.Count -eq 1 -and (Test-Has $glCall[0] '--redact') -and (Test-Has $glCall[0] '--no-color') -and (Test-Has $glCall[0] ("--log-opts='" + $opts + "'")) -and $numstat.Count -eq 1 -and (Test-Has $numstat[0] ($opts + ' '))
) "gitleaks call lines: [$($glCall -join ' / ')]; numstat lines: [$($numstat -join ' / ')]"

Assert 'g-7: the scan step parses the "<n> commits scanned." line, fails when it is not exactly one line or differs from the expected count, and fails on ERR/FTL/PNC lines' (
    (Test-Has $scanBody 'commits scanned\.$') -and (Test-Has $scanBody '-eq 1 ]]') -and (Test-Has $scanBody '$scanned_n -ne $expected_n') -and (Test-Has $scanBody '(ERR|FTL|PNC) ')
) "scan body: [$scanBody]"

$labels = @('gitleaks 버전', '범위', '기대 커밋 수', '검사 커밋 수', '결과')
$missingLabels = @($labels | Where-Object { -not (Test-Has $scanBody ('**' + $_ + '**')) })
Assert 'g-8: the scan step writes the five summary lines (version, range, expected, scanned, result) to $GITHUB_STEP_SUMMARY and wraps PR-chosen output in ::stop-commands::' (
    $missingLabels.Count -eq 0 -and (Test-Has $scanBody '$GITHUB_STEP_SUMMARY') -and (Test-Has $scanBody '::stop-commands::')
) "missing labels: [$($missingLabels -join ', ')]"

$exprRuns = @($runs | Where-Object { $_.Contains('${{') })
$permIdx = @(for ($i = 0; $i -lt $ciLines.Count; $i++) { if ($ciLines[$i] -match '^permissions:') { $i } })
$permOk = $permIdx.Count -eq 1 -and (Test-Same $ciLines[$permIdx[0]] 'permissions:') -and ($permIdx[0] + 1 -lt $ciLines.Count) -and (Test-Same $ciLines[$permIdx[0] + 1] '  contents: read') -and (($permIdx[0] + 2 -ge $ciLines.Count) -or ($ciLines[$permIdx[0] + 2] -notmatch '^\s+\S'))
Assert 'g-9: no run: body of job gitleaks contains ${{ (values reach run: only through env:), workflow permissions is exactly "contents: read" and the job sets none of its own' (
    $runs.Count -ge 2 -and $exprRuns.Count -eq 0 -and $permOk -and @($job | Where-Object { $_ -match '^\s+permissions:' }).Count -eq 0
) "bodies with an expression: $($exprRuns.Count); workflow permissions lines: $($permIdx.Count)"

$headerEnd = [Array]::IndexOf($ciLines, 'name: ci')
$header = if ($headerEnd -gt 0) { ($ciLines[0..($headerEnd - 1)] -join "`n") } else { '' }
Assert 'g-10: the header comment has a "job gitleaks" entry that names the 30-commit limit of the action, the sha256 pin, the count comparison and the missing daily schedule' (
    (Test-Has $header '# - job gitleaks(') -and (Test-Has $header '30') -and (Test-Has $header 'sha256') -and (Test-Has $header '검사 커밋 수') -and (Test-Has $header 'schedule')
) "header: [$header]"

# 탐지 설정 고정(coverage F1): 작업 트리의 .gitleaks.toml · .gitleaksignore가 있으면 스캔 전에 exit 1, 워크플로가 쓴 설정
# 파일([extend] useDefault = true)을 --config로 넘기고, 인라인 gitleaks:allow는 --ignore-gitleaks-allow로 무시한다.
# 순서: 존재 검사 → 설정 파일 쓰기 → gitleaks 호출.
$chkIdx = -1; $cfgIdx = -1; $glIdx = -1
for ($i = 0; $i -lt $scanLines.Count; $i++) {
    if ($chkIdx -lt 0 -and (Test-Same $scanLines[$i] 'for f in .gitleaks.toml .gitleaksignore; do')) { $chkIdx = $i }
    if ($cfgIdx -lt 0 -and (Test-Same $scanLines[$i] 'printf ''[extend]\nuseDefault = true\n'' > "$work/gitleaks.toml"')) { $cfgIdx = $i }
    if ($glIdx -lt 0 -and $scanLines[$i] -match '^"\$gl" git ') { $glIdx = $i }
}
$chkShape = $chkIdx -ge 0 -and ($chkIdx + 5) -lt $scanLines.Count -and
    (Test-Same $scanLines[$chkIdx + 1] 'if [[ -e $f || -L $f ]]; then') -and
    ($scanLines[$chkIdx + 2] -match '^printf ''::error::%s 가 체크아웃에 있다') -and
    (Test-Same $scanLines[$chkIdx + 3] 'exit 1') -and
    (Test-Same $scanLines[$chkIdx + 4] 'fi') -and
    (Test-Same $scanLines[$chkIdx + 5] 'done')
Assert 'g-11: the scan step fails before scanning when .gitleaks.toml or .gitleaksignore exists in the checkout, writes the pinned config ([extend] useDefault = true) and calls gitleaks with --config "$work/gitleaks.toml" --ignore-gitleaks-allow, in that order' (
    $chkShape -and $cfgIdx -gt $chkIdx -and $glIdx -gt $cfgIdx -and (Test-Has $glCall[0] '--config "$work/gitleaks.toml"') -and (Test-Has $glCall[0] '--ignore-gitleaks-allow')
) "existence-check line: $chkIdx (shape ok: $chkShape); config line: $cfgIdx; gitleaks call line: $glIdx; call: [$($glCall -join ' / ')]"

# 내려받기 스킴 제한(coverage F4): 설치 스텝의 curl은 하나뿐이고 리다이렉트까지 https만 허용한다
$curlLines = @($installLines | Where-Object { $_ -match '^curl ' })
Assert 'g-12: the install step has exactly one curl line and it restricts the scheme to https for the request and its redirects (--proto =https --proto-redir =https)' (
    $curlLines.Count -eq 1 -and (Test-Has $curlLines[0] "--proto '=https' --proto-redir '=https'") -and (Test-Has $curlLines[0] '-fsSL') -and (Test-Has $curlLines[0] '-o "$dl/$2" "$1"')
) "curl lines: [$($curlLines -join ' / ')]"

# PR 이벤트의 head 확인(compliance F2 · F3): PR head는 merge 커밋의 조상이어야 하고 둘째 부모(HEAD^2)여야 한다.
# 이벤트가 준 값을 찍는 오류 문구는 %q(gitops validate.yml 관례)다.
Assert 'g-13: on pull_request the scan step requires PR_HEAD_SHA to be a full commit ID, an ancestor of HEAD and HEAD^2 (GitHub merge ref = two parents); both error lines print the event value with %q' (
    (Test-Has $scanBody '|| ! git merge-base --is-ancestor "$PR_HEAD_SHA" "$head_sha"; then') -and
    (Test-Has $scanBody 'if [[ $(git rev-parse --verify --quiet ''HEAD^2'' || true) != "$PR_HEAD_SHA" ]]; then') -and
    (Get-Count $scanBody 'PR head %q ') -eq 2 -and -not (Test-Has $scanBody 'PR head %s')
) "PR head %q lines: $(Get-Count $scanBody 'PR head %q '); HEAD^2 check: $(Test-Has $scanBody '''HEAD^2''')"

# git 최소 버전 문구(compliance F1): --attr-source · GIT_ATTR_SOURCE는 git 2.41.0에서 나왔다 — 두 곳 모두 2.41, 2.40은 없다
Assert 'g-14: the job comments state the --attr-source / GIT_ATTR_SOURCE minimum as git 2.41 (two places) and never 2.40' (
    (Get-Count $jobText 'git 2.41') -eq 2 -and -not (Test-Has $jobText '2.40')
) "git 2.41 count: $(Get-Count $jobText 'git 2.41'); has 2.40: $(Test-Has $jobText '2.40')"

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
