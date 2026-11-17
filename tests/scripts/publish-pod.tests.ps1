# publish-pod 시험(T074) — .github/workflows/publish-pod.yml · scripts/ci/publish-pod-assert-image.sh · scripts/ci/publish-pod-bump.sh.
# Run: pwsh -NoProfile -File tests/scripts/publish-pod.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/ci-gitleaks.tests.ps1 · events-compat.tests.ps1과 같은 구조).
# 설계: specs/003-platform-foundation/design/t074-design.md D14(pp-1–pp-25 · px-1–px-23) + 수정 라운드 1(리뷰 RA · RB — pp-26–pp-28 ·
#   px-24–px-36) + 라운드 1b(컨트롤러 결정 B5 — px-29 확장 · px-37 · pp-21 exec) + 라운드 2(결정 B6 — F8–F18: px-26 · px-27 · px-29 확장 ·
#   px-38 · pp-18 · pp-23 · pp-26 · pp-28 강화). id 하나가 단언 한 줄이다(「각각」인 사례는 한 단언 안에서
#   모두 성립해야 PASS — FAIL 줄의 설명에 사례별 결과를 적는다).
#   집계 단언(px-7 assert-image 전 실행 · px-21 · px-22 · px-27 bump 전 실행)은 그 계층의 모든 사례 뒤에 돈다 — 출력 순서가 번호 순이 아니다.
#
# 정적 계층(pp-*): 워크플로와 두 스크립트의 원문을 줄 단위로 읽는다 — YAML 파서 없이. 줄 단위 판독이 GitHub의 YAML 판독과 갈라지지 않게
#   워크플로의 문법 자체를 좁힌다(설계 D3 들여쓰기 규약 + 수정 라운드 1):
#   - pp-26 문법: 블록 스칼라 밖의 모든 코드 줄은 `^( *)(- )?[A-Za-z0-9_-]+:( |$)` 꼴(값이 흐름 { [ · 앵커 & · 별칭 * · 태그 ! 등으로 시작하지
#     않는다)이거나 평문 목록 항목이다. 따옴표 키 · `key :` · `?` · 흐름 꼴 · 여러 줄 평문은 FAIL이다. 예외는 최상위 `permissions: {}` 한 줄뿐이다.
#   - pp-27 블록 경계: 헤더 뒤 0칸 줄은 엄격한 최상위 키 여섯뿐(0칸 주석 없음) · on: · jobs: 아래 4칸 미만 줄은 엄격한 머리(트리거 셋 · job 셋 —
#     각각 한 번)뿐이고 4칸 미만 주석이 없다. 숨은 job(줄 끝 주석 머리 · 따옴표 · 흐름 꼴)과 블록을 자르는 얕은 주석을 막는다.
#   - 모든 맵 단언(on · env · concurrency · job 키 · permissions · outputs · 스텝의 with: · env:)은 판독하지 못한 줄(bad)이 0이어야 한다.
#   - pp-8 · pp-9 · pp-10 job 키 집합 정확 · pp-28 스텝 키 집합 정확(uses 스텝 = {uses, with} 또는 {id, uses, with} · run 스텝 =
#     {name, env, run}) — 스텝 if · continue-on-error · shell · working-directory · timeout-minutes · uses 스텝 env, job container · services ·
#     continue-on-error · strategy가 들어오면 FAIL이다.
#   - 값은 글자 그대로 대조한다: 액션 핀(SHA · 판) · BuildKit 이미지 · buildkitd-flags · 자기 검증 한 줄 · yq 설치 본문 전체(들여쓰기를 걷은
#     본문 = 이 파일의 상수). 이 값을 바꾸는 변경은 이 하네스의 상수도 함께 바꾼다(리뷰를 거치게 하는 드리프트 검사다).
#   Get-JobBlock · Get-RunBodies는 ci-gitleaks.tests.ps1, Get-Steps · Get-StepMap은 events-compat.tests.ps1에서 옮겼다(주석 줄은 블록 경계로
#   보지 않게 · Get-StepMap은 블록 스칼라 값과 판독하지 못한 줄도 돌려주게 고쳤다). 외부 도구 0 · SKIP 없음 · fail closed.
# 실행 계층(px-*): 두 스크립트를 Git/POSIX bash로 실제로 돌린다. PATH 맨 앞의 가짜 gh · docker · sleep(호출을 기록하고 사례마다 둔 시나리오
#   파일대로 답한다 · px-28 · px-29는 push만 가로채는 git 감싸개도)과 bare git 원격 픽스처(가짜 platform-gitops — 실제 git · 얕은 file:// 클론으로
#   CI의 fetch-depth 1을 흉내 낸다), 실제 yq v4.53.6을 쓴다. 네트워크를 쓰지 않는다. 가짜 gh는 머지를 흉내 낼 때 bare 원격 main에 squash
#   커밋을 만들고 그 sha를 merge_commit_sha로 준다(머지 결과 대조가 실제 git 객체로 돈다) · 모노레포 compare(낡은 실행 가드)와 gitops
#   compare(머지 커밋이 main에 있는가)에 답한다 · 호출마다 GH_TOKEN이 App 토큰인지 모노레포 토큰인지 표지(gh:app · gh:mono)만 기록한다
#   (값은 기록하지 않는다). 취소 사례(px-29)는 부모(bump 스크립트)에 SIGTERM · SIGINT를 보내는 가짜로 만든다 — 기다림(가짜 sleep — TERM ·
#   INT) · 실패 정리 도중(가짜 gh pr close) · push 창(가짜 git push — 올린 뒤 · 남의 커밋) · 머지 결과 대조 도중(가짜 gh gitops compare) ·
#   stop-commands 구간 안(가짜 head — show의 파이프 원소)(Git Bash 실측: 자식이 보낸 SIGTERM · SIGINT가 부모의 trap에 닿았다 — wait · 전경
#   자식 모두 10/10).
#   실행마다 임시 디렉터리(RUNNER_TEMP · TMPDIR · GITHUB_STEP_SUMMARY · 가짜 상태)를 쓰고, git은 사용자 설정과 떨어져 돈다(GIT_CONFIG_NOSYSTEM=1 ·
#   GIT_CONFIG_GLOBAL=빈 파일 · GIT_DIR류 지움 — events-compat 꼴). 자식 환경에서는 GITHUB_* · RUNNER_* · GH_* · GIT_* · 입력 이름을 지운 뒤
#   사례가 주는 값만 둔다.
#   Windows: Git의 usr/bin/bash.exe만 쓴다(bin/bash.exe는 PATH 앞에 /mingw64/bin:/usr/bin을 붙여 가짜를 가린다 — kernel-trial.tests.ps1).
#   MSYS는 PATH를 POSIX 꼴로 바꾸며 사용자 임시 디렉터리를 /tmp로 보이므로 RUNNER_TEMP · TMPDIR은 cygpath -u로 바꿔 준다(bump 스크립트가
#   `command -v yq` = "$RUNNER_TEMP/bin/yq"를 대조한다 — 2026-11-16 탐침). 경로 변환은 끄지 않는다(실제 git · yq가 /tmp 꼴 인자를 받는다).
#   bump 스크립트의 GH_TOKEN · MONOREPO_TOKEN은 실행마다 같은 가짜 값('ghs_FAKE' · 'ghs_FAKEMONO' + 무작위 32자)이다 — px-21이 모든 출력 ·
#   요약 · PR 본문 · 가짜 호출 기록 · 커밋(클론 · 원격)에서 두 값이 0번인지 본다(실제 자격은 쓰지 않는다). 클론의 .git/config는 보지 않는다 —
#   checkout v7은 토큰을 $RUNNER_TEMP의 파일에 두고 includeIf로 잇는데 픽스처 클론에는 자격이 없어 빈 검사였다(리뷰 RB-9).
# SKIP: 실행 사례에 필요한 도구가 없으면 그 사례만 'SKIP px-n -- not found: <도구>'와 끝의 'N skipped' 줄로 드러나고 통과 수에 들지 않는다
#   (assert-image 사례 = bash, bump 사례 = bash · git · yq v4.53.6, Windows는 cygpath도). px-23은 형제 클론
#   ../platform-gitops/tests/validate.sh가 없을 때만 SKIP이다. 정적 계층은 도구와 무관하게 늘 판정한다 — 파일 전체 SKIP 줄은 없다(run-all
#   1b6은 'N skipped'가 있으면 판정 줄과 별도로 NOTE 한 줄을 찍는다).
# yq: PUBLISH_POD_YQ → PATH의 yq → 저장소 .superpowers/bin/yq(.exe) 순으로 찾아 --version이 v4.53.6인 첫 것을 쓰고, 실행마다
#   "$RUNNER_TEMP/bin/yq"(그 바이너리를 exec하는 bash 감싸개)로 둔다.
# 환경 변수(사본 시험 · 선택 실행 — 하나라도 주면 요약 줄 끝에 접미가 붙어 tests/run-all.ps1 1b6의 판정을 통과하지 못한다):
#   PUBLISH_POD_WORKFLOW       정적 단언이 읽을 워크플로(기본 .github/workflows/publish-pod.yml) — ' (override: …)'
#   PUBLISH_POD_ASSERT_SCRIPT  시험할 이미지 단언 스크립트(기본 scripts/ci/publish-pod-assert-image.sh) — ' (override: …)'
#   PUBLISH_POD_BUMP_SCRIPT    시험할 bump 스크립트(기본 scripts/ci/publish-pod-bump.sh) — ' (override: …)'
#   PUBLISH_POD_TESTS_ONLY     쉼표로 나눈 id 또는 접두(pp · px · pp-12 …) — 그 단언만 돈다(나머지는 찍지도 세지도 않는다) — ' (filtered: …)'
#   PUBLISH_POD_YQ             yq 위치(도구 위치라 접미가 붙지 않는다)
# 요약: 'N passed, M failed'. 실패가 있으면 그 바로 앞에 'failed: <id>, …' 한 줄을 둔다.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$wfOverride = -not [string]::IsNullOrEmpty($env:PUBLISH_POD_WORKFLOW)
$asOverride = -not [string]::IsNullOrEmpty($env:PUBLISH_POD_ASSERT_SCRIPT)
$bsOverride = -not [string]::IsNullOrEmpty($env:PUBLISH_POD_BUMP_SCRIPT)
$wfPath = if ($wfOverride) { $env:PUBLISH_POD_WORKFLOW } else { Join-Path $repo '.github/workflows/publish-pod.yml' }
$asPath = if ($asOverride) { $env:PUBLISH_POD_ASSERT_SCRIPT } else { Join-Path $repo 'scripts/ci/publish-pod-assert-image.sh' }
$bsPath = if ($bsOverride) { $env:PUBLISH_POD_BUMP_SCRIPT } else { Join-Path $repo 'scripts/ci/publish-pod-bump.sh' }
$ciPath = Join-Path $repo '.github/workflows/ci.yml'
$deployBaseDir = Join-Path $repo 'apps/identity-admin/deploy/base'
$validatePath = Join-Path (Split-Path -Parent $repo) 'platform-gitops/tests/validate.sh'
$script:only = [string[]]@(if (-not [string]::IsNullOrEmpty($env:PUBLISH_POD_TESTS_ONLY)) { $env:PUBLISH_POD_TESTS_ONLY -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } })
# 선택 실행이 아니다 — 집계 단언(px-7 · px-21 · px-22 · px-27)은 그때만 실행 수 하한을 본다
$script:full = $script:only.Count -eq 0

# 상수(설계 D2–D8 · 계약 gitops-repo.md §dev bump · pod-template.md 이미지 행 · 조각 ② 근거 — 바꾸면 워크플로와 같은 변경에서 바꾼다)
$K = @{
    Pod        = 'identity-admin'
    Image      = 'ghcr.io/joshua92y/identity-admin'
    Runner     = 'ubuntu-24.04-arm'
    Paths      = @('apps/identity-admin/**', 'packages/django-common/**', '.github/workflows/publish-pod.yml', 'scripts/ci/publish-pod-*.sh')
    PrIf       = "github.event_name == 'pull_request'"
    PubIf      = "github.event_name != 'pull_request' && github.ref == 'refs/heads/main'"
    BotSlug    = 'joshuatech-gitapp-1'   # gitops tests/validate.sh:232 VALIDATE_BOT_AUTHORS 기본값의 App 이름(…[bot]에서 옮김)
    BotId      = '323873425'             # gitops tests/validate.sh:233 VALIDATE_BOT_IDS 기본값
    YqVersion  = 'v4.53.6'
    YqSha256   = '88a1016bc1d657375a35864e4f44b6f333df8ff97b559f51bba0adcb2169df09'   # gitops promote.yml:91(yq_linux_arm64)과 같은 값
    AsCall     = 'bash scripts/ci/publish-pod-assert-image.sh'
    # bump 스크립트는 exec로 부른다 — 러너의 취소 신호(스텝 셸 PID에만 — actions/runner ProcessInvoker.cs)를 스크립트가 직접 받는다(라운드 1b)
    BsCall     = 'exec bash scripts/ci/publish-pod-bump.sh'
    GitopsRepo = 'joshua92y/platform-gitops'
    # 액션 핀(조각 ② — git ls-remote 대조 · 발행 14일 원칙: login v4.8.0(2026-11-05)은 쓰지 않고 v4.7.0)
    Pins       = [ordered]@{
        'actions/checkout'                = @('3d3c42e5aac5ba805825da76410c181273ba90b1', '7.0.1')
        'docker/setup-buildx-action'      = @('f87e5991a6d7451dcb8d9637bfbc97413f497069', '4.4.1')
        'docker/login-action'             = @('81c6f93d4bc991e510b342a00b419b3bb4efc5c6', '4.7.0')
        'docker/metadata-action'          = @('dc802804100637a589fabce1cb79ff13a1411302', '6.2.0')
        'docker/build-push-action'        = @('c3c9e263c25d99ce0380d002d59b67737d91b0dc', '7.4.0')
        'actions/attest'                  = @('1e69f48acb82d1966a394da916b4c1698aa569d6', '4.2.2')
        'actions/create-github-app-token' = @('64ab729a6294000f5aa4a4bc0b73d1f32bc45510', '3.3.0')
    }
    BuildkitOpts  = 'image=moby/buildkit:v0.34.1@sha256:99368f3e46177c6405b9740e4461d91cee004128daeecca78d4ceac50ec1da5c'
    BuildkitFlags = '--debug=false'
    VerifyLine = 'gh attestation verify "oci://$IMAGE@$DIGEST" --repo "$GITHUB_REPOSITORY" --signer-workflow "$GITHUB_REPOSITORY/.github/workflows/publish-pod.yml" --source-ref refs/heads/main --deny-self-hosted-runners'
    BuildArgs  = "APP_VERSION=`${{ steps.meta.outputs.version }}`nAPP_GIT_SHA=`${{ github.sha }}"
    # 낡은 실행 가드의 모노레포 compare — 내보내지 않는 변수 $mono(⓪에서 MONOREPO_TOKEN을 옮겨 지운 값)를 이 한 줄에서만 GH_TOKEN으로 준다 ·
    # 머리는 refs/heads/main(같은 이름 태그로 풀리지 않게 — 라운드 2 F12 · F15)
    MonoCompareCall = 'GH_TOKEN="$mono" gh api "repos/$GITHUB_REPOSITORY/compare/$GITHUB_SHA...refs/heads/main"'
}
# yq 설치 스텝의 run: 본문(들여쓰기를 걷은 꼴 — Get-NormalizedBody) — 글자 그대로 대조한다(|| true · 순서 바꾸기 · 검증 앞 설치를 막는다)
$K.YqBody = @'
set -euo pipefail
step='yq 설치'
t0=$(date -u +%s)
on_exit() {
  local rc=$? t1
  t1=$(date -u +%s)
  printf -- '- **%s** · 시작 %s · 종료 %s · %d초 · exit %d\n' "$step" \
    "$(date -u -d "@$t0" +%FT%TZ)" "$(date -u -d "@$t1" +%FT%TZ)" "$((t1 - t0))" "$rc" >> "$GITHUB_STEP_SUMMARY" || true
  exit "$rc"
}
trap on_exit EXIT
bin="$RUNNER_TEMP/bin"
dl="$RUNNER_TEMP/dl"
mkdir -p "$bin" "$dl"
if [[ ! $YQ_SHA256 =~ ^[0-9a-f]{64}$ ]]; then
  printf '::error::YQ_SHA256 값의 형식이 틀렸다\n'
  exit 1
fi
# 리다이렉트(릴리스 자산은 objects.githubusercontent.com으로 302)까지 https만 · 시간 한도 · sha256 대조 뒤에만 설치한다
curl -fsSL --proto '=https' --proto-redir '=https' --retry 3 --connect-timeout 10 --max-time 120 \
  -o "$dl/yq" "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_arm64"
printf '%s  %s\n' "$YQ_SHA256" "$dl/yq" | sha256sum -c -
install -m 0755 "$dl/yq" "$bin/yq"
# 버전 확인 — 설치한 바이너리가 mikefarah yq의 기대 버전이 아니면 실패
yq_out=$("$bin/yq" --version || true)
if [[ $yq_out != *mikefarah* || ${yq_out##* } != "$YQ_VERSION" ]]; then
  printf '::error::yq 버전 불일치: 실제 %q · 기대 %s\n' "$yq_out" "$YQ_VERSION"
  exit 1
fi
# 다음 스텝부터 PATH 맨 앞에 온다(bump 스크립트가 command -v yq = $RUNNER_TEMP/bin/yq를 대조한다)
printf '%s\n' "$bin" >> "$GITHUB_PATH"
'@ -replace "`r`n", "`n"

$script:pass = 0
$script:fail = 0
$script:skips = [Collections.Generic.List[string]]::new()
$script:failedIds = [Collections.Generic.List[string]]::new()
$script:temps = [Collections.Generic.List[string]]::new()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; $script:failedIds.Add(($name -split ':', 2)[0]); Write-Host "FAIL $name -- $detail" }
}
# 사례를 돌리지 못했다 — 통과로 세지 않고 이유를 남긴다
function Skip-Assert([string]$id, [string]$reason) {
    $script:skips.Add($id)
    Write-Host "SKIP $id -- $reason (not counted as passed)"
}
function Test-Selected([string]$id) {
    if ($script:only.Count -eq 0) { return $true }
    foreach ($s in $script:only) { if ([string]::Equals($id, $s, [StringComparison]::Ordinal) -or $id.StartsWith("$s-", [StringComparison]::Ordinal)) { return $true } }
    return $false
}
# 단언 그룹 격리 — 한 그룹에서 예외가 나도 나머지 그룹은 계속 돈다(예외는 그 id의 FAIL). 본문은 이 함수의 범위에 점 소싱되므로 본문에서
# 매개변수 이름($id · $body)에 값을 넣지 않는다.
function Test-Group([string]$id, [scriptblock]$body) {
    if (-not (Test-Selected $id)) { return }
    try { . $body }
    catch { $script:fail++; $script:failedIds.Add($id); Write-Host "FAIL $id -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-Has([string]$text, [string]$needle) { $null -ne $text -and $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Get-Count([string]$text, [string]$needle) { $n = 0; $i = 0; while (($i = $text.IndexOf($needle, $i, [StringComparison]::Ordinal)) -ge 0) { $n++; $i += $needle.Length }; return $n }
function Test-SameSet([string[]]$a, [string[]]$b) {
    if ($a.Count -ne $b.Count) { return $false }
    $hs = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($x in $a) { if (-not $hs.Add($x)) { return $false } }
    foreach ($y in $b) { if (-not $hs.Contains($y)) { return $false } }
    return $true
}
function Test-SameList([string[]]$a, [string[]]$b) {
    if ($a.Count -ne $b.Count) { return $false }
    for ($i = 0; $i -lt $a.Count; $i++) { if (-not (Test-Same $a[$i] $b[$i])) { return $false } }
    return $true
}
function Unquote([string]$v) {
    if ($null -eq $v) { return $null }
    if ($v.Length -ge 2 -and (($v[0] -eq '"' -and $v[-1] -eq '"') -or ($v[0] -eq "'" -and $v[-1] -eq "'"))) { return $v.Substring(1, $v.Length - 2) }
    return $v
}
function Format-Map($map) { return (@($map.Keys | ForEach-Object { "$_=$($map[$_])" }) -join ', ') }
function Cut([string]$s, [int]$n = 1500) { if ($null -eq $s) { return '' }; if ($s.Length -le $n) { return $s }; return $s.Substring(0, $n) + '…' }
function Get-Indent([string]$l) { return $l.Length - $l.TrimStart(' ').Length }
function Test-CommentLine([string]$l) { return $l.TrimStart().StartsWith('#') }

# ---------- 원문 읽기 ----------
function Read-Lines([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return , ([string[]]@()) }
    $t = [IO.File]::ReadAllText($path)
    return , ([string[]]@($t -split "`n" | ForEach-Object { $_.TrimEnd("`r") }))
}
# 주석 · 빈 줄이 아닌 줄(첫 글자가 #인 줄 = 주석 · #! 포함)
function Get-CodeLines([string[]]$lines) { return , ([string[]]@($lines | Where-Object { $_.Trim().Length -gt 0 -and -not (Test-CommentLine $_) })) }
# run: 블록 본문의 정규형 — 줄 끝 공백 · 앞뒤 빈 줄을 지우고 공통 들여쓰기를 걷는다
function Get-NormalizedBody([string]$text) {
    $ls = [Collections.Generic.List[string]]::new()
    foreach ($l in (([string]$text) -replace "`r`n", "`n").Split("`n")) { $ls.Add($l.TrimEnd()) }
    while ($ls.Count -gt 0 -and $ls[$ls.Count - 1].Length -eq 0) { $ls.RemoveAt($ls.Count - 1) }
    while ($ls.Count -gt 0 -and $ls[0].Length -eq 0) { $ls.RemoveAt(0) }
    $min = [int]::MaxValue
    foreach ($l in $ls) { if ($l.Length -gt 0) { $min = [Math]::Min($min, (Get-Indent $l)) } }
    if ($min -eq [int]::MaxValue) { $min = 0 }
    return (@($ls | ForEach-Object { if ($_.Length -ge $min) { $_.Substring($min) } else { $_ } }) -join "`n")
}

# 최상위(0칸) 키 하나: 머리 줄의 값과 그 아래 줄(다음 0칸 코드 줄 전까지 — 0칸 주석은 블록을 끝내지 않는다)
function Get-TopBlock([string[]]$lines, [string]$key) {
    $start = -1; $value = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match($lines[$i], '^' + [regex]::Escape($key) + ':(\s+(.*?))?\s*$')
        if ($m.Success) { $start = $i + 1; $value = $m.Groups[2].Value; break }
    }
    if ($start -lt 0) { return @{ found = $false; value = $null; lines = [string[]]@() } }
    $block = [Collections.Generic.List[string]]::new()
    for ($i = $start; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^\S' -and -not $l.StartsWith('#')) { break }
        $block.Add($l)
    }
    return @{ found = $true; value = $value; lines = [string[]]$block.ToArray() }
}
# 줄 묶음 안 indent칸 키 하나의 아래 줄(다음 같은 깊이 이하 코드 줄 전까지)
function Get-SubBlock([string[]]$block, [int]$indent, [string]$key) {
    $start = -1; $value = $null
    for ($i = 0; $i -lt $block.Count; $i++) {
        $m = [regex]::Match($block[$i], '^ {' + $indent + '}' + [regex]::Escape($key) + ':(\s+(.*?))?\s*$')
        if ($m.Success) { $start = $i + 1; $value = $m.Groups[2].Value; break }
    }
    if ($start -lt 0) { return @{ found = $false; value = $null; lines = [string[]]@() } }
    $out = [Collections.Generic.List[string]]::new()
    for ($i = $start; $i -lt $block.Count; $i++) {
        $l = $block[$i]
        if ($l.Trim().Length -gt 0 -and -not (Test-CommentLine $l)) {
            if ((Get-Indent $l) -le $indent) { break }
        }
        $out.Add($l)
    }
    return @{ found = $true; value = $value; lines = [string[]]$out.ToArray() }
}
# 줄 묶음에서 정확히 indent칸인 'key: value' 줄의 표(주석 · 빈 줄 제외). 깊이가 같은데 키 꼴이 아니거나 같은 키가 둘이면 bad.
function Get-ChildMap([string[]]$block, [int]$indent) {
    $map = [ordered]@{}; $bad = [Collections.Generic.List[string]]::new()
    foreach ($l in $block) {
        if ($l.Trim().Length -eq 0 -or (Test-CommentLine $l)) { continue }
        if ((Get-Indent $l) -ne $indent) { continue }
        $m = [regex]::Match($l, '^ {' + $indent + '}([A-Za-z0-9_.-]+):(\s+(.*?))?\s*$')
        if (-not $m.Success) { $bad.Add("unparsed: $l"); continue }
        $k = $m.Groups[1].Value
        if ($map.Contains($k)) { $bad.Add("duplicate: $k") }
        $map[$k] = $m.Groups[3].Value
    }
    return @{ map = $map; bad = [string[]]$bad.ToArray() }
}
# indent칸 '- 값' 목록 항목(따옴표를 벗긴다)
function Get-ListItems([string[]]$block, [int]$indent) {
    $items = [Collections.Generic.List[string]]::new()
    foreach ($l in $block) {
        $m = [regex]::Match($l, '^ {' + $indent + '}-\s+(.*?)\s*$')
        if ($m.Success) { $items.Add((Unquote $m.Groups[1].Value)) }
    }
    return , ([string[]]$items.ToArray())
}

# jobs: 아래 2칸 들여쓰기 job 하나의 줄(머리 줄 다음부터 다음 job · 최상위 키 전까지 — 주석 줄은 경계로 보지 않는다). 없으면 빈 배열.
function Get-JobBlock([string[]]$lines, [string]$job) {
    $inJobs = $false; $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -cmatch '^jobs:\s*$') { $inJobs = $true; continue }
        if ($inJobs -and $lines[$i] -cmatch ('^  ' + [regex]::Escape($job) + ':\s*$')) { $start = $i + 1; break }
    }
    if ($start -lt 0) { return , ([string[]]@()) }
    $block = [Collections.Generic.List[string]]::new()
    for ($i = $start; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^ {0,2}\S' -and -not (Test-CommentLine $l)) { break }
        $block.Add($l)
    }
    return , ([string[]]$block.ToArray())
}
# 줄 묶음의 run: 본문들 — 블록 스칼라(| 또는 >)는 더 깊이 들여쓴 다음 줄들, 한 줄 run은 그 값(ci-gitleaks.tests.ps1)
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
                if ((Get-Indent $l) -le $indent) { break }
                [void]$sb.Append($l + "`n")
            }
            $bodies.Add($sb.ToString())
        } else { $bodies.Add($rest) }
    }
    return , ([string[]]$bodies.ToArray())
}
# job 블록의 steps: 목록을 스텝마다 줄 배열로 나눈다 — '      - '(6칸 목록 항목)가 스텝의 첫 줄이다(스텝 사이의 주석 줄은 앞 스텝에 붙고
# 첫 스텝 앞의 주석은 버린다). steps: 밖의 4칸 이하 코드 줄에서 멈춘다(주석 줄은 경계로 보지 않는다 — events-compat.tests.ps1을 고쳤다).
function Get-Steps([string[]]$block) {
    $steps = [Collections.Generic.List[object]]::new()
    $inSteps = $false; $cur = $null
    foreach ($l in $block) {
        if ($l -cmatch '^    steps:\s*$') { $inSteps = $true; continue }
        if (-not $inSteps) { continue }
        if (-not (Test-CommentLine $l) -and $l -match '^ {0,4}\S') { break }
        if ($l -match '^      - ') {
            if ($null -ne $cur) { $steps.Add([string[]]$cur.ToArray()) }
            $cur = [Collections.Generic.List[string]]::new()
        }
        if ($null -ne $cur) { $cur.Add($l) }
    }
    if ($null -ne $cur) { $steps.Add([string[]]$cur.ToArray()) }
    return , ($steps.ToArray())
}
# 스텝 키 깊이의 키 표(첫 줄 '- key: v'와 같은 깊이의 'key: v' 줄). 첫 줄이 그 꼴이 아니거나 그 깊이에 키 꼴이 아닌 줄 · 같은 키 둘이면 bad.
function Get-StepKeys([string[]]$step) {
    $map = [ordered]@{}; $bad = [Collections.Generic.List[string]]::new()
    if ($step.Count -eq 0) { return @{ map = $map; bad = [string[]]@() } }
    $h = [regex]::Match($step[0], '^(\s*)-\s+([A-Za-z0-9_-]+):(\s+(.*?))?\s*$')
    if (-not $h.Success) { $bad.Add($step[0]); return @{ map = $map; bad = [string[]]$bad.ToArray() } }
    $depth = $h.Groups[1].Value.Length + 2
    $map[$h.Groups[2].Value] = $h.Groups[4].Value
    for ($i = 1; $i -lt $step.Count; $i++) {
        $l = $step[$i]
        if ($l.Trim().Length -eq 0 -or (Test-CommentLine $l)) { continue }
        if ((Get-Indent $l) -ne $depth) { continue }
        $m = [regex]::Match($l, '^\s+([A-Za-z0-9_-]+):(\s+(.*?))?\s*$')
        if (-not $m.Success) { $bad.Add($l); continue }
        if ($map.Contains($m.Groups[1].Value)) { $bad.Add("duplicate: $($m.Groups[1].Value)") }
        $map[$m.Groups[1].Value] = $m.Groups[3].Value
    }
    return @{ map = $map; bad = [string[]]$bad.ToArray() }
}
# 스텝의 with: · env: 같은 매핑(events-compat.tests.ps1 Get-StepMap을 넓혔다): 키는 스텝 키 깊이의 그 키 아래 첫 깊이에서만 받는다.
# 블록 스칼라(| · >)의 값은 본문 줄(앞뒤 공백 제거 · 끝 빈 줄 제거)을 줄바꿈으로 이은 글자이고 blocks에 그 키가 든다. 깊이가 다른
# 줄 · 키 꼴이 아닌 줄 · 같은 키 둘은 bad. 키가 없으면 found = $false.
function Get-StepMap([string[]]$step, [string]$key) {
    $map = [ordered]@{}; $bad = [Collections.Generic.List[string]]::new(); $blocks = [Collections.Generic.List[string]]::new()
    $res = @{ map = $map; bad = $bad; blocks = $blocks; found = $false }
    $head = if ($step.Count -gt 0) { [regex]::Match($step[0], '^(\s*-\s+)') } else { $null }
    if ($null -eq $head -or -not $head.Success) { return $res }
    $depth = $head.Groups[1].Value.Length
    for ($i = 0; $i -lt $step.Count; $i++) {
        $m = [regex]::Match($step[$i], '^(\s*)(-\s+)?' + [regex]::Escape($key) + ':\s*$')
        if (-not $m.Success) { continue }
        if (($m.Groups[1].Value.Length + $m.Groups[2].Value.Length) -ne $depth) { continue }
        $res.found = $true
        $child = -1; $curKey = $null; $cur = $null
        $finish = { if ($null -ne $curKey) { while ($cur.Count -gt 0 -and $cur[$cur.Count - 1].Length -eq 0) { $cur.RemoveAt($cur.Count - 1) }; $map[$curKey] = ($cur.ToArray() -join "`n"); $blocks.Add($curKey) } }
        for ($j = $i + 1; $j -lt $step.Count; $j++) {
            $l = $step[$j]
            if ($l.Trim().Length -eq 0) { if ($null -ne $cur) { $cur.Add('') }; continue }
            $ind = Get-Indent $l
            if ($ind -le $depth) { break }
            if ($child -lt 0) { if (Test-CommentLine $l) { continue }; $child = $ind }
            if ($null -ne $cur -and $ind -gt $child) { $cur.Add($l.Trim()); continue }
            if (Test-CommentLine $l) { continue }
            if ($ind -ne $child) { $bad.Add($l); continue }
            . $finish; $curKey = $null; $cur = $null
            $kv = [regex]::Match($l, '^\s+([A-Za-z0-9_-]+):(\s+(.*?))?\s*$')
            if (-not $kv.Success) { $bad.Add($l); continue }
            $k = $kv.Groups[1].Value; $v = $kv.Groups[3].Value
            if ($map.Contains($k)) { $bad.Add("duplicate: $k") }
            # 블록 스칼라는 정확히 '|'만 블록으로 읽는다(라운드 2 F11 — '>' · '|-' · '|+' · 들여쓰기 지시자는 값 그대로 남아 대조에서 틀린다)
            if (Test-Same $v '|') { $curKey = $k; $cur = [Collections.Generic.List[string]]::new() }
            else { $map[$k] = $v }
        }
        . $finish
        break
    }
    return $res
}

# pp-26 문법 — 블록 스칼라 밖의 코드 줄이 엄격한 키 줄 · 한 줄 스칼라 목록 항목이 아니면 그 줄 번호와 까닭(예외: 최상위 permissions: {} 한 줄).
# 값이 있는 키 줄 · 목록 항목 다음의 코드 줄이 그 키 열(항목은 '-' 열)보다 깊으면 여러 줄 스칼라의 이음 줄이다(줄 단위 판독은 그 값을 첫 줄로만
# 본다 — 예: run: 한 줄 뒤의 '  - x || true'). 따옴표 값은 그 줄에서 닫혀야 한다. 파일 전체에 탭 밖의 제어 · 서식 문자와 줄 · 문단 구분 문자가
# 없어야 한다(YAML 1.1 계열 파서는 NEL · LS · PS를 줄바꿈으로 읽는다 — 줄 단위 판독은 주석 한 줄로 본다).
function Get-GrammarViolations([string[]]$lines, [string]$raw) {
    $bad = [Collections.Generic.List[string]]::new()
    foreach ($cm in [regex]::Matches($raw, '(?![\t\n])[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]')) {
        $bad.Add("char U+$(([int][char]$cm.Value).ToString('X4')) at offset $($cm.Index) (control / format / line or paragraph separator)")
        if ($bad.Count -ge 5) { break }
    }
    $reQuoted = '^("([^"\\]|\\.)*"|''([^'']|'''')*'')(\s+#.*)?$'
    $blk = -1
    $maxNext = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l.Trim().Length -eq 0) { continue }
        $ind = Get-Indent $l
        if ($blk -ge 0) { if ($ind -gt $blk) { continue } else { $blk = -1 } }
        if ($l.Contains("`t")) { $bad.Add("$($i + 1): tab outside a block scalar"); continue }
        if (Test-CommentLine $l) { continue }
        if ($maxNext -ge 0 -and $ind -gt $maxNext) { $bad.Add("$($i + 1): continuation line of a multi-line scalar (deeper than the previous value line)"); continue }
        $maxNext = -1
        if (Test-Same $l 'permissions: {}') { $maxNext = 0; continue }
        $m = [regex]::Match($l, '^( *)(- )?([A-Za-z0-9_-]+):( (.*))?$')
        if ($m.Success) {
            $col = $m.Groups[1].Value.Length + $m.Groups[2].Value.Length
            $v = $m.Groups[5].Value.TrimStart(' ')
            if ($v.Length -eq 0) { continue }
            if ($v -match '^[{\[&*!%@`#]' -or $v -match '^[-?:]( |$)') { $bad.Add("$($i + 1): value starts with a flow / anchor / alias / tag / comment / indicator character"); continue }
            if ($v -match '^[|>]') {
                # 블록 스칼라 머리는 정확히 '|'만 — 접기(>)와 줄 끝 처리(- +) · 들여쓰기 지시자는 YAML 값이 줄 단위 판독과 달라진다(라운드 2 F11)
                if (Test-Same $v '|') { $blk = $col } else { $bad.Add("$($i + 1): block scalar header other than exactly |") }
                continue
            }
            if ($v -match '^["'']' -and $v -notmatch $reQuoted) { $bad.Add("$($i + 1): quoted value not closed on its line"); continue }
            $maxNext = $col
            continue
        }
        $li = [regex]::Match($l, '^( *)- (.+)$')
        if ($li.Success) {
            $v = $li.Groups[2].Value.TrimStart(' ')
            if ($v -match '^[{\[&*!%@`#?|>]' -or $v -match '^[-:]( |$)' -or $v -match '^("[^"]*"|''[^'']*''|[^"''#][^#]*?)\s*:(\s|$)') { $bad.Add("$($i + 1): list item is not a one-line scalar"); continue }
            if ($v -match '^["'']' -and $v -notmatch $reQuoted) { $bad.Add("$($i + 1): quoted list item not closed on its line"); continue }
            $maxNext = $li.Groups[1].Value.Length
            continue
        }
        $bad.Add("$($i + 1): not a strict key line or one-line list item [$(Cut $l 60)]")
    }
    return , ([string[]]$bad.ToArray())
}
# pp-27 블록 경계 — 헤더 뒤 0칸 줄 · on: · jobs: 아래 4칸 미만 줄의 위반과 머리 목록
function Get-BoundaryReport([string[]]$lines) {
    $bad = [Collections.Generic.List[string]]::new()
    $heads = @{ on = [Collections.Generic.List[string]]::new(); jobs = [Collections.Generic.List[string]]::new() }
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -cmatch '^name:') { $start = $i; break } }
    if ($start -lt 0) { $bad.Add('no name: line') }
    $section = ''
    for ($i = [Math]::Max($start, 0); $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l.Trim().Length -eq 0) { continue }
        $ind = Get-Indent $l
        if ($ind -eq 0) {
            if ($l.StartsWith('#')) { $bad.Add("$($i + 1): column-0 comment after the header"); continue }
            $m = [regex]::Match($l, '^(name|on|permissions|concurrency|env|jobs):( .*)?$')
            if (-not $m.Success) { $bad.Add("$($i + 1): top-level line is not one of the six strict keys"); $section = ''; continue }
            $section = $m.Groups[1].Value
            continue
        }
        if (($section -eq 'on' -or $section -eq 'jobs') -and $ind -lt 4) {
            if (Test-CommentLine $l) { $bad.Add("$($i + 1): comment shallower than 4 columns under ${section}:"); continue }
            $pat = if ($section -eq 'on') { '^  (push|pull_request|workflow_dispatch):$' } else { '^  (build-check|publish|bump):$' }
            $hm = [regex]::Match($l, $pat)
            if (-not $hm.Success) { $bad.Add("$($i + 1): line under ${section}: is not a strict header [$(Cut $l 60)]"); continue }
            $heads[$section].Add($hm.Groups[1].Value)
        }
    }
    if (-not (Test-SameSet ([string[]]$heads.on.ToArray()) @('push', 'pull_request', 'workflow_dispatch'))) { $bad.Add("on: headers [$($heads.on -join ', ')]") }
    if (-not (Test-SameSet ([string[]]$heads.jobs.ToArray()) @('build-check', 'publish', 'bump'))) { $bad.Add("jobs: headers [$($heads.jobs -join ', ')]") }
    return @{ bad = [string[]]$bad.ToArray(); jobs = [string[]]$heads.jobs.ToArray() }
}

# 스텝의 종류: checkout(모노레포) · checkout-gitops(repository 입력) · setup-buildx · login · metadata · build-load · build-push ·
# build-other · attest · app · as · bs · verify · yq · run · run-multi · other · uses:<그 밖>
function Get-PpKind($s) {
    if ($s.uses.Length -gt 0) {
        switch -CaseSensitive ($s.uses) {
            'actions/checkout' { if ($s.with.map.Contains('repository')) { return 'checkout-gitops' } else { return 'checkout' } }
            'docker/setup-buildx-action' { return 'setup-buildx' }
            'docker/login-action' { return 'login' }
            'docker/metadata-action' { return 'metadata' }
            'docker/build-push-action' {
                $push = Unquote ([string]$s.with.map['push'])
                $hasLoad = $s.with.map.Contains('load')
                if ((Test-Same $push 'false') -and $hasLoad -and (Test-Same (Unquote ([string]$s.with.map['load'])) 'true')) { return 'build-load' }
                if ((Test-Same $push 'true') -and -not $hasLoad) { return 'build-push' }
                return 'build-other'
            }
            'actions/attest' { return 'attest' }
            'actions/create-github-app-token' { return 'app' }
            default { return "uses:$($s.uses)" }
        }
    }
    if ($s.runs.Count -gt 1) { return 'run-multi' }
    if ($s.runs.Count -eq 1) {
        $b = $s.runs[0].Trim()
        # 스크립트 호출 · 자기 검증은 한 줄 run 값이어야 한다(블록 스칼라 안의 같은 글자는 그 종류로 세지 않는다 — 글자 그대로 요구)
        $oneLine = -not ([string]$s.sk.map['run']).StartsWith('|', [StringComparison]::Ordinal) -and -not ([string]$s.sk.map['run']).StartsWith('>', [StringComparison]::Ordinal)
        if ($oneLine -and (Test-Same $b $K.AsCall)) { return 'as' }
        if ($oneLine -and (Test-Same $b $K.BsCall)) { return 'bs' }
        if ($oneLine -and $b.StartsWith('gh attestation verify ', [StringComparison]::Ordinal) -and -not $b.Contains("`n")) { return 'verify' }
        if (Test-Has $b 'yq_linux_arm64') { return 'yq' }
        return 'run'
    }
    return 'other'
}
function New-StepModel([string[]]$lines) {
    $m = @{ lines = $lines; text = ($lines -join "`n") }
    $m.sk = Get-StepKeys $lines
    $m.with = Get-StepMap $lines 'with'
    $m.env = Get-StepMap $lines 'env'
    $m.runs = Get-RunBodies $lines
    $u = [regex]::Match($m.text, '(?m)^\s*(-\s+)?uses:\s*([^@\s]+)@')
    $m.uses = if ($u.Success) { $u.Groups[2].Value } else { '' }
    $m.id = if ($m.sk.map.Contains('id')) { Unquote ([string]$m.sk.map['id']) } else { '' }
    $m.kind = Get-PpKind $m
    return $m
}
function Get-JobModel([string[]]$lines, [string]$name) {
    $block = Get-JobBlock $lines $name
    $jk = Get-ChildMap $block 4
    $steps = [Collections.Generic.List[object]]::new()
    foreach ($s in (Get-Steps $block)) { $steps.Add((New-StepModel ([string[]]$s))) }
    $kinds = [string[]]@(foreach ($s in $steps) { $s.kind })
    return @{ name = $name; block = $block; text = ($block -join "`n"); jk = $jk.map; jkBad = $jk.bad; steps = $steps.ToArray(); kinds = $kinds }
}
# job 키(4칸) 아래 6칸 표 — permissions · env · outputs
function Get-JobSubMap($job, [string]$key) {
    $sb = Get-SubBlock $job.block 4 $key
    if (-not $sb.found) { return @{ found = $false; value = $null; map = [ordered]@{}; bad = [string[]]@(); deeper = 0 } }
    $cm = Get-ChildMap $sb.lines 6
    $deeper = @($sb.lines | Where-Object { $_.Trim().Length -gt 0 -and -not (Test-CommentLine $_) -and (Get-Indent $_) -gt 6 }).Count
    return @{ found = $true; value = $sb.value; map = $cm.map; bad = $cm.bad; deeper = $deeper }
}
function Test-MapEquals($map, [hashtable]$want) {
    if ($null -eq $map) { return $false }
    if (-not (Test-SameSet ([string[]]@($map.Keys)) ([string[]]@($want.Keys)))) { return $false }
    foreach ($k in $want.Keys) { if (-not (Test-Same (Unquote ([string]$map[$k])) ([string]$want[$k]))) { return $false } }
    return $true
}
# 맵 결과(@{ map; bad; [deeper] })가 판독하지 못한 줄 없이 정확히 want인가(리뷰 RA-2 · RB-1 — 따옴표 키 · `key :`는 bad로 남는다)
function Test-MapExact($res, [hashtable]$want) {
    if ($null -eq $res -or $res.bad.Count -gt 0) { return $false }
    if ($res.ContainsKey('deeper') -and $res.deeper -gt 0) { return $false }
    return (Test-MapEquals $res.map $want)
}
# 그 종류의 스텝들(@{ job; step }) — 호출하는 쪽이 @( )로 감싼다(쉼표로 감싸 돌려주지 않는다 — @( )가 한 번 더 감싸 개수가 1이 된다)
function Find-Steps($jobs, [string]$kind) {
    foreach ($jn in $jobs.Keys) { foreach ($s in $jobs[$jn].steps) { if (Test-Same $s.kind $kind) { @{ job = $jn; step = $s } } } }
}

# ---------- 원문 모델 ----------
$wfExists = Test-Path -LiteralPath $wfPath -PathType Leaf
$wfRaw = if ($wfExists) { [IO.File]::ReadAllText($wfPath) } else { '' }
$wfLines = Read-Lines $wfPath
$wfText = $wfLines -join "`n"
$wfCode = Get-CodeLines $wfLines
$wfCodeText = $wfCode -join "`n"
$jobs = [ordered]@{}
foreach ($jn in @('build-check', 'publish', 'bump')) { $jobs[$jn] = Get-JobModel $wfLines $jn }
$asExists = Test-Path -LiteralPath $asPath -PathType Leaf
$asLines = Read-Lines $asPath
$asCode = Get-CodeLines $asLines
$asCodeText = $asCode -join "`n"
$bsExists = Test-Path -LiteralPath $bsPath -PathType Leaf
$bsLines = Read-Lines $bsPath
$bsCode = Get-CodeLines $bsLines
$bsCodeText = $bsCode -join "`n"
$pushStep = @(Find-Steps $jobs 'build-push')
$pushId = if ($pushStep.Count -eq 1) { $pushStep[0].step.id } else { '' }
$pushDigestExpr = "`${{ steps.$pushId.outputs.digest }}"

# ==================== 정적 계층 ====================
Test-Group 'pp-1' {
    $top = [string[]]@(foreach ($l in $wfLines) { $m = [regex]::Match($l, '^([A-Za-z_][A-Za-z0-9_-]*):(\s.*)?$'); if ($m.Success) { $m.Groups[1].Value } })
    $nameLines = @($wfLines | Where-Object { Test-Same $_ 'name: publish-pod' }).Count
    Assert 'pp-1: publish-pod.yml exists, has "name: publish-pod" once and exactly the top-level keys {name, on, permissions, concurrency, env, jobs}' (
        $wfExists -and $nameLines -eq 1 -and (Test-SameSet $top @('name', 'on', 'permissions', 'concurrency', 'env', 'jobs'))
    ) "exists: $wfExists; name lines: $nameLines; top-level keys: [$($top -join ', ')]"
}

Test-Group 'pp-2' {
    $on = Get-TopBlock $wfLines 'on'
    $onMap = Get-ChildMap $on.lines 2
    $push = Get-SubBlock $on.lines 2 'push'
    $pr = Get-SubBlock $on.lines 2 'pull_request'
    $wd = Get-SubBlock $on.lines 2 'workflow_dispatch'
    $pushMap = Get-ChildMap $push.lines 4
    $prMap = Get-ChildMap $pr.lines 4
    $branches = Get-ListItems (Get-SubBlock $push.lines 4 'branches').lines 6
    $pushPaths = Get-ListItems (Get-SubBlock $push.lines 4 'paths').lines 6
    $prPaths = Get-ListItems (Get-SubBlock $pr.lines 4 'paths').lines 6
    $wdCode = (Get-CodeLines $wd.lines).Count
    $banned = @($wfCode | Where-Object { $_ -match 'pull_request_target|workflow_run|schedule' })
    $ok = $on.found -and $on.value.Length -eq 0 -and $onMap.bad.Count -eq 0 -and $pushMap.bad.Count -eq 0 -and $prMap.bad.Count -eq 0 -and
        (Test-SameSet ([string[]]@($onMap.map.Keys)) @('push', 'pull_request', 'workflow_dispatch')) -and (@($onMap.map.Values | Where-Object { $_.Length -gt 0 }).Count -eq 0) -and
        (Test-SameSet ([string[]]@($pushMap.map.Keys)) @('branches', 'paths')) -and (@($pushMap.map.Values | Where-Object { $_.Length -gt 0 }).Count -eq 0) -and
        (Test-SameList $branches @('main')) -and (Test-SameSet ([string[]]@($prMap.map.Keys)) @('paths')) -and
        (Test-SameList $pushPaths $prPaths) -and (Test-SameSet $pushPaths $K.Paths) -and $wd.found -and $wdCode -eq 0 -and $banned.Count -eq 0
    Assert 'pp-2: on = {push, pull_request, workflow_dispatch} with no unparsed line; push.branches = [main] (block list); push and pull_request carry the same four paths (D2); workflow_dispatch has no inputs; no pull_request_target / workflow_run / schedule' $ok (
        "on keys: [$($onMap.map.Keys -join ', ')] bad [$($onMap.bad -join ' | ')]; push keys: [$(Format-Map $pushMap.map)] bad [$($pushMap.bad -join ' | ')]; branches: [$($branches -join ', ')]; pr keys: [$(Format-Map $prMap.map)]; push paths: [$($pushPaths -join ' | ')]; pr paths: [$($prPaths -join ' | ')]; dispatch code lines: $wdCode; banned: [$($banned -join ' | ')]")
}

Test-Group 'pp-3' {
    $perm = Get-TopBlock $wfLines 'permissions'
    $permLines = @($wfLines | Where-Object { $_ -match '^permissions:' }).Count
    $conc = Get-TopBlock $wfLines 'concurrency'
    $cm = Get-ChildMap $conc.lines 2
    $concOk = $conc.found -and $conc.value.Length -eq 0 -and (Test-MapExact $cm @{ group = 'publish-pod-${{ github.ref }}'; 'cancel-in-progress' = '${{ github.event_name == ''pull_request'' }}' })
    Assert 'pp-3: workflow permissions is exactly "{}" and concurrency is exactly group publish-pod-${{ github.ref }} with cancel-in-progress ${{ github.event_name == ''pull_request'' }} (literal, no unparsed line)' (
        $perm.found -and (Test-Same $perm.value '{}') -and (Get-CodeLines $perm.lines).Count -eq 0 -and $permLines -eq 1 -and $concOk
    ) "permissions: [$($perm.value)] (lines $permLines); concurrency: [$(Format-Map $cm.map)] bad [$($cm.bad -join ' | ')]"
}

Test-Group 'pp-4' {
    $envB = Get-TopBlock $wfLines 'env'
    $em = Get-ChildMap $envB.lines 2
    $img = Unquote ([string]$em.map['IMAGE'])
    $imgs = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $deployBaseDir -PathType Container) {
        foreach ($f in @(Get-ChildItem -LiteralPath $deployBaseDir -Filter '*.yaml' -File)) {
            foreach ($l in (Read-Lines $f.FullName)) { $m = [regex]::Match($l, '^\s*(-\s*)?image:\s*(\S+)\s*$'); if ($m.Success) { $imgs.Add((Unquote $m.Groups[2].Value)) } }
        }
    }
    $off = @($imgs | Where-Object { -not (Test-Same $_ $img) })
    $literal = (Test-Same ([string]$em.map['POD']) 'identity-admin') -and (Test-Same ([string]$em.map['IMAGE']) 'ghcr.io/joshua92y/identity-admin') -and (Test-Same ([string]$em.map['DOCKER_BUILD_RECORD_UPLOAD']) '"false"')
    Assert 'pp-4: workflow env is exactly {POD, IMAGE, DOCKER_BUILD_RECORD_UPLOAD} with the literal values identity-admin / ghcr.io/joshua92y/identity-admin / "false" and no unparsed line; IMAGE equals every image: value of apps/identity-admin/deploy/base' (
        $envB.found -and $em.bad.Count -eq 0 -and (Test-SameSet ([string[]]@($em.map.Keys)) @('POD', 'IMAGE', 'DOCKER_BUILD_RECORD_UPLOAD')) -and $literal -and $imgs.Count -ge 1 -and $off.Count -eq 0
    ) "env: [$(Format-Map $em.map)] bad [$($em.bad -join ' | ')]; deploy/base images: $($imgs.Count), differing: [$($off -join ', ')]"
}

Test-Group 'pp-5' {
    $jt = Get-TopBlock $wfLines 'jobs'
    $jobNames = [string[]]@(foreach ($l in $jt.lines) { $m = [regex]::Match($l, '^  ([A-Za-z0-9_-]+):\s*$'); if ($m.Success) { $m.Groups[1].Value } })
    $limits = @{ 'build-check' = 30; publish = 30; bump = 20 }
    $why = [Collections.Generic.List[string]]::new()
    foreach ($jn in $limits.Keys) {
        $j = $jobs[$jn]
        if ($j.block.Count -eq 0) { $why.Add("$jn missing"); continue }
        if ($j.jk.Contains('name')) { $why.Add("$jn has name:") }
        if (-not (Test-Same ([string]$j.jk['runs-on']) $K.Runner)) { $why.Add("$jn runs-on [$($j.jk['runs-on'])]") }
        $t = 0
        if (-not ([int]::TryParse([string]$j.jk['timeout-minutes'], [ref]$t)) -or $t -lt 1 -or $t -gt $limits[$jn]) { $why.Add("$jn timeout-minutes [$($j.jk['timeout-minutes'])]") }
        $def = Get-SubBlock $j.block 4 'defaults'
        $run = Get-SubBlock $def.lines 6 'run'
        $sh = Get-ChildMap $run.lines 8
        if (-not ($def.found -and $run.found -and (Test-MapExact $sh @{ shell = 'bash' }) -and (Get-CodeLines $def.lines).Count -eq 2)) { $why.Add("$jn defaults is not exactly run.shell bash") }
        if ($j.jkBad.Count -gt 0) { $why.Add("$jn job keys: $($j.jkBad -join ' | ')") }
    }
    Assert 'pp-5: jobs = {build-check, publish, bump}; no job-level name:; all run on ubuntu-24.04-arm with timeout-minutes <= 30 / 30 / 20 and defaults exactly run.shell bash' (
        (Test-SameSet $jobNames @('build-check', 'publish', 'bump')) -and $why.Count -eq 0
    ) "jobs: [$($jobNames -join ', ')]; $($why -join '; ')"
}

Test-Group 'pp-6' {
    $usesLines = @($wfCode | Where-Object { $_ -match '^\s*(-\s+)?uses:' })
    $bad = [Collections.Generic.List[string]]::new()
    foreach ($l in $usesLines) {
        $m = [regex]::Match($l, '^\s*(-\s+)?uses:\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([0-9a-f]{40}) # v(\d+\.\d+\.\d+)\s*$')
        if (-not $m.Success) { $bad.Add("form: $l"); continue }
        $a = $m.Groups[2].Value
        if (-not $K.Pins.Contains($a)) { $bad.Add("not allowed: $a"); continue }
        if (-not ((Test-Same $m.Groups[3].Value $K.Pins[$a][0]) -and (Test-Same $m.Groups[4].Value $K.Pins[$a][1]))) { $bad.Add("pin: $a@$($m.Groups[3].Value) v$($m.Groups[4].Value)") }
    }
    $ciCheckout = [Collections.Generic.HashSet[string]]::new()
    foreach ($l in (Get-CodeLines (Read-Lines $ciPath))) { $m = [regex]::Match($l, 'uses:\s*actions/checkout@([0-9a-f]{40})'); if ($m.Success) { [void]$ciCheckout.Add($m.Groups[1].Value) } }
    $coOk = $ciCheckout.Count -eq 1 -and (Test-Same (@($ciCheckout)[0]) $K.Pins['actions/checkout'][0])
    Assert 'pp-6: every uses: is <owner>/<repo>@<40-hex> # vX.Y.Z and equals the reviewed pin table (seven actions — checkout v7.0.1 = ci.yml, setup-buildx v4.4.1, login v4.7.0 (14-day rule), metadata v6.2.0, build-push v7.4.0, attest v4.2.2, create-github-app-token v3.3.0)' (
        $usesLines.Count -ge 1 -and $bad.Count -eq 0 -and $coOk
    ) "uses lines: $($usesLines.Count); problems: [$($bad -join ' | ')]; checkout same as ci.yml: $coOk"
}

Test-Group 'pp-7' {
    $allRuns = @(foreach ($jn in $jobs.Keys) { foreach ($s in $jobs[$jn].steps) { $s.runs } })
    $exprRuns = @($allRuns | Where-Object { Test-Has $_ '${{' })
    $sec = @($wfCode | Where-Object { $_ -match '(?i)\bsecrets\b' })
    $vars = @($wfCode | Where-Object { $_ -match '(?i)\bvars\b' })
    $tojson = [regex]::Matches($wfText, '(?i)tojson\s*\(').Count
    $app = @(Find-Steps $jobs 'app')
    $appOk = $app.Count -eq 1 -and (Test-Same $app[0].job 'bump') -and
        (Test-Same ([string]$app[0].step.with.map['private-key']) '${{ secrets.JOSHUATECH_CI_APP_PRIVATE_KEY }}') -and
        (Test-Same ([string]$app[0].step.with.map['client-id']) '${{ vars.JOSHUATECH_CI_APP_CLIENT_ID }}')
    Assert 'pp-7: no run: body contains ${{; no toJSON( anywhere; exactly one code line names secrets (bump private-key) and exactly one names vars (client-id)' (
        $wfExists -and $allRuns.Count -ge 1 -and $exprRuns.Count -eq 0 -and $tojson -eq 0 -and $sec.Count -eq 1 -and $vars.Count -eq 1 -and $appOk
    ) "run bodies: $($allRuns.Count) (with an expression: $($exprRuns.Count)); toJSON: $tojson; secrets lines: [$($sec -join ' | ')]; vars lines: [$($vars -join ' | ')]; app step ok: $appOk"
}

Test-Group 'pp-8' {
    $j = $jobs['build-check']
    $perm = Get-JobSubMap $j 'permissions'
    $want = @('checkout', 'setup-buildx', 'metadata', 'build-load', 'as')
    $forbidden = @($j.block | Where-Object { $_ -match 'docker/login-action|actions/attest|create-github-app-token' })
    $keysOk = (Test-SameSet ([string[]]@($j.jk.Keys)) @('if', 'runs-on', 'timeout-minutes', 'permissions', 'defaults', 'steps')) -and $j.jkBad.Count -eq 0
    Assert 'pp-8: build-check job keys are exactly {if, runs-on, timeout-minutes, permissions, defaults, steps} (no env / environment / container / services / strategy / continue-on-error), if github.event_name == ''pull_request'', permissions exactly contents: read, steps checkout -> setup-buildx -> metadata -> build (load) -> assert-image (local); no login / attest / app token' (
        $j.block.Count -gt 0 -and $keysOk -and (Test-Same ([string]$j.jk['if']) $K.PrIf) -and $perm.found -and (Test-MapExact $perm @{ contents = 'read' }) -and
        (Test-SameList $j.kinds $want) -and $forbidden.Count -eq 0
    ) "job keys: [$($j.jk.Keys -join ', ')] bad [$($j.jkBad -join ' | ')]; if: [$($j.jk['if'])]; permissions: [$(Format-Map $perm.map)] bad [$($perm.bad -join ' | ')]; steps: [$($j.kinds -join ', ')]; forbidden lines: $($forbidden.Count)"
}

Test-Group 'pp-9' {
    $j = $jobs['publish']
    $perm = Get-JobSubMap $j 'permissions'
    $outs = Get-JobSubMap $j 'outputs'
    $want = @('checkout', 'setup-buildx', 'login', 'metadata', 'build-load', 'as', 'build-push', 'as', 'attest', 'verify')
    $login = @(Find-Steps $jobs 'login')
    $loginOk = $login.Count -eq 1 -and (Test-Same $login[0].job 'publish') -and (Test-MapExact $login[0].step.with @{ registry = 'ghcr.io'; username = '${{ github.actor }}'; password = '${{ github.token }}' })
    $keysOk = (Test-SameSet ([string[]]@($j.jk.Keys)) @('if', 'runs-on', 'timeout-minutes', 'permissions', 'outputs', 'defaults', 'steps')) -and $j.jkBad.Count -eq 0
    Assert 'pp-9: publish job keys are exactly {if, runs-on, timeout-minutes, permissions, outputs, defaults, steps} (no env / environment / container / continue-on-error …), if (not pull_request and refs/heads/main), permissions exactly contents read, packages write, id-token write, attestations write, steps in the D6 order, outputs exactly digest = the push build step digest, login = ghcr.io / github.actor / github.token' (
        $j.block.Count -gt 0 -and $keysOk -and (Test-Same ([string]$j.jk['if']) $K.PubIf) -and
        (Test-MapExact $perm @{ contents = 'read'; packages = 'write'; 'id-token' = 'write'; attestations = 'write' }) -and
        (Test-SameList $j.kinds $want) -and $pushId.Length -gt 0 -and (Test-MapExact $outs @{ digest = $pushDigestExpr }) -and $loginOk
    ) "job keys: [$($j.jk.Keys -join ', ')] bad [$($j.jkBad -join ' | ')]; if: [$($j.jk['if'])]; permissions: [$(Format-Map $perm.map)] bad [$($perm.bad -join ' | ')]; steps: [$($j.kinds -join ', ')]; outputs: [$(Format-Map $outs.map)] (push step id [$pushId]); login ok: $loginOk"
}

Test-Group 'pp-10' {
    $j = $jobs['bump']
    $perm = Get-JobSubMap $j 'permissions'
    $envLines = @($wfCode | Where-Object { $_ -match '^\s+environment:' })
    $want = @('checkout', 'yq', 'app', 'checkout-gitops', 'bs')
    $keysOk = (Test-SameSet ([string[]]@($j.jk.Keys)) @('needs', 'if', 'runs-on', 'timeout-minutes', 'permissions', 'environment', 'env', 'defaults', 'steps')) -and $j.jkBad.Count -eq 0
    Assert 'pp-10: bump job keys are exactly {needs, if, runs-on, timeout-minutes, permissions, environment, env, defaults, steps} (no container / services / strategy / continue-on-error), needs publish, the same if as publish, environment production (the only environment: line of the file), permissions exactly contents: read, steps monorepo checkout -> yq -> app token -> gitops checkout -> bump script' (
        $j.block.Count -gt 0 -and $keysOk -and (Test-Same ([string]$j.jk['needs']) 'publish') -and (Test-Same ([string]$j.jk['if']) $K.PubIf) -and (Test-Same ([string]$j.jk['environment']) 'production') -and
        $envLines.Count -eq 1 -and (Test-MapExact $perm @{ contents = 'read' }) -and (Test-SameList $j.kinds $want)
    ) "job keys: [$($j.jk.Keys -join ', ')] bad [$($j.jkBad -join ' | ')]; needs: [$($j.jk['needs'])]; if: [$($j.jk['if'])]; environment: [$($j.jk['environment'])] (lines $($envLines.Count)); permissions: [$(Format-Map $perm.map)] bad [$($perm.bad -join ' | ')]; steps: [$($j.kinds -join ', ')]"
}

Test-Group 'pp-11' {
    $mono = @(Find-Steps $jobs 'checkout')
    $why = [Collections.Generic.List[string]]::new()
    $byJob = @{}
    foreach ($x in $mono) {
        $byJob[$x.job] = 1 + [int]$byJob[$x.job]
        $want = if (Test-Same $x.job 'bump') { @{ 'sparse-checkout' = 'scripts/ci'; 'persist-credentials' = 'false' } } else { @{ 'persist-credentials' = 'false' } }
        if (-not (Test-MapExact $x.step.with $want)) { $why.Add("$($x.job) with [$(Format-Map $x.step.with.map)] bad [$($x.step.with.bad -join ' | ')]") }
    }
    $first = @(foreach ($jn in $jobs.Keys) { if ($jobs[$jn].kinds.Count -gt 0) { $jobs[$jn].kinds[0] } else { '' } })
    Assert 'pp-11: three monorepo checkouts (first step of each job) with exactly persist-credentials: false (no ref / repository / token); only the bump one also has sparse-checkout, exactly scripts/ci' (
        $mono.Count -eq 3 -and $byJob['build-check'] -eq 1 -and $byJob['publish'] -eq 1 -and $byJob['bump'] -eq 1 -and (Test-SameList $first @('checkout', 'checkout', 'checkout')) -and $why.Count -eq 0
    ) "monorepo checkouts: $($mono.Count); first steps: [$($first -join ', ')]; $($why -join '; ')"
}

Test-Group 'pp-12' {
    $sb = @(Find-Steps $jobs 'setup-buildx')
    $why = [Collections.Generic.List[string]]::new()
    foreach ($x in $sb) {
        if ($x.step.with.blocks.Count -gt 0 -or -not (Test-MapExact $x.step.with @{ 'driver-opts' = $K.BuildkitOpts; 'buildkitd-flags' = $K.BuildkitFlags })) { $why.Add("$($x.job) with [$(Format-Map $x.step.with.map)] bad [$($x.step.with.bad -join ' | ')]") }
    }
    $same = $sb.Count -eq 2 -and (Test-Same $sb[0].step.text $sb[1].step.text)
    Assert 'pp-12: two setup-buildx steps (build-check, publish) with the same block and exactly driver-opts image=moby/buildkit:v0.34.1@sha256:99368f3e… and buildkitd-flags --debug=false (no driver / endpoint / version / config, no insecure entitlement)' (
        $sb.Count -eq 2 -and (Test-Same $sb[0].job 'build-check') -and (Test-Same $sb[1].job 'publish') -and $same -and $why.Count -eq 0
    ) "setup-buildx steps: $($sb.Count); same block: $same; $($why -join '; ')"
}

Test-Group 'pp-13' {
    $md = @(Find-Steps $jobs 'metadata')
    $why = [Collections.Generic.List[string]]::new()
    foreach ($x in $md) {
        if (-not (Test-Same $x.step.id 'meta')) { $why.Add("$($x.job) id [$($x.step.id)]") }
        if ($x.step.with.blocks.Count -gt 0 -or -not (Test-MapExact $x.step.with @{ images = '${{ env.IMAGE }}'; tags = 'type=sha,format=long'; flavor = 'latest=false' })) { $why.Add("$($x.job) with [$(Format-Map $x.step.with.map)] bad [$($x.step.with.bad -join ' | ')]") }
    }
    Assert 'pp-13: two metadata steps (id meta) with exactly images ${{ env.IMAGE }}, tags type=sha,format=long (one line), flavor latest=false' (
        $md.Count -eq 2 -and (Test-Same $md[0].job 'build-check') -and (Test-Same $md[1].job 'publish') -and $why.Count -eq 0
    ) "metadata steps: $($md.Count); $($why -join '; ')"
}

Test-Group 'pp-14' {
    $bp = @(foreach ($jn in $jobs.Keys) { foreach ($s in $jobs[$jn].steps) { if (Test-Same $s.uses 'docker/build-push-action') { @{ job = $jn; step = $s } } } })
    $why = [Collections.Generic.List[string]]::new()
    $base = @{ context = '.'; file = 'apps/identity-admin/Dockerfile'; platforms = 'linux/arm64'; provenance = 'false'; sbom = 'false'; 'build-args' = $K.BuildArgs; tags = '${{ steps.meta.outputs.tags }}' }
    foreach ($x in $bp) {
        $want = @{} + $base
        if (Test-Same $x.step.kind 'build-load') { $want.push = 'false'; $want.load = 'true' } else { $want.push = 'true' }
        if (-not (Test-MapExact $x.step.with $want)) { $why.Add("$($x.job)/$($x.step.kind) with [$(Format-Map $x.step.with.map)] bad [$($x.step.with.bad -join ' | ')]") }
        if (-not (Test-SameSet ([string[]]@($x.step.with.blocks)) @('build-args'))) { $why.Add("$($x.job) block keys [$($x.step.with.blocks -join ', ')]") }
    }
    $kinds = @($bp | ForEach-Object { "$($_.job)/$($_.step.kind)" })
    Assert 'pp-14: three build-push steps (build-check load, publish load, publish push) with exactly the eight inputs (+ load on the load builds): context . · file apps/identity-admin/Dockerfile · platforms linux/arm64 · provenance false · sbom false · build-args exactly two lines · tags; load = push false + load true, push = push true' (
        (Test-SameList $kinds @('build-check/build-load', 'publish/build-load', 'publish/build-push')) -and $why.Count -eq 0
    ) "build steps: [$($kinds -join ', ')]; $($why -join '; ')"
}

Test-Group 'pp-15' {
    $as = @(Find-Steps $jobs 'as')
    $why = [Collections.Generic.List[string]]::new()
    $modes = @('local', 'local', 'registry'); $where = @('build-check', 'publish', 'publish')
    for ($i = 0; $i -lt $as.Count -and $i -lt 3; $i++) {
        $x = $as[$i]
        $ref = if ($i -eq 2) { "`${{ env.IMAGE }}@`${{ steps.$pushId.outputs.digest }}" } else { '${{ env.IMAGE }}:${{ steps.meta.outputs.version }}' }
        if (-not (Test-Same $x.job $where[$i])) { $why.Add("call $($i + 1) in $($x.job)") }
        if ($x.step.env.blocks.Count -gt 0 -or -not (Test-MapExact $x.step.env @{ IMAGE_REF = $ref; EXPECT_SHA = '${{ github.sha }}'; ASSERT_MODE = $modes[$i] })) { $why.Add("call $($i + 1) env [$(Format-Map $x.step.env.map)] bad [$($x.step.env.bad -join ' | ')]") }
    }
    Assert 'pp-15: three assert-image calls whose run: is exactly "bash scripts/ci/publish-pod-assert-image.sh", env exactly {IMAGE_REF, EXPECT_SHA, ASSERT_MODE}, modes local · local · registry in build-check · publish · publish, EXPECT_SHA ${{ github.sha }}, IMAGE_REF tag (local) / push digest (registry)' (
        $as.Count -eq 3 -and $pushId.Length -gt 0 -and $why.Count -eq 0
    ) "calls: $($as.Count); $($why -join '; ')"
}

Test-Group 'pp-16' {
    $at = @(Find-Steps $jobs 'attest')
    $pub = $jobs['publish']
    $iAt = [Array]::IndexOf([string[]]$pub.kinds, 'attest')
    $verify = if ($iAt -ge 0 -and $iAt + 1 -lt $pub.steps.Count) { $pub.steps[$iAt + 1] } else { $null }
    $atOk = $at.Count -eq 1 -and (Test-Same $at[0].job 'publish') -and (Test-MapExact $at[0].step.with @{ 'subject-name' = '${{ env.IMAGE }}'; 'subject-digest' = $pushDigestExpr; 'push-to-registry' = 'true'; 'create-storage-record' = 'false' })
    $vb = if ($null -ne $verify -and $verify.runs.Count -eq 1) { $verify.runs[0] } else { '' }
    $vOk = $null -ne $verify -and (Test-Same $verify.kind 'verify') -and (Test-Same $vb $K.VerifyLine) -and (Test-MapExact $verify.env @{ GH_TOKEN = '${{ github.token }}'; DIGEST = $pushDigestExpr })
    Assert 'pp-16: one attest step (publish) with exactly subject-name ${{ env.IMAGE }} · subject-digest = push digest · push-to-registry true · create-storage-record false, followed by the self-verify run: that is ordinal-equal to the D7 line (gh attestation verify … --repo · --signer-workflow · --source-ref refs/heads/main · --deny-self-hosted-runners — nothing appended) with env exactly GH_TOKEN github.token · DIGEST' (
        $atOk -and $vOk
    ) "attest ok: $atOk; verify body: [$vb]; verify env: [$(if ($verify) { Format-Map $verify.env.map })]"
}

Test-Group 'pp-17' {
    $app = @(Find-Steps $jobs 'app')
    $usesCount = @($wfCode | Where-Object { $_ -match 'actions/create-github-app-token@' }).Count
    $w = if ($app.Count -eq 1) { $app[0].step.with } else { @{ map = [ordered]@{}; bad = [string[]]@('missing') } }
    Assert 'pp-17: the App token step exists once, in bump (id app), with exactly client-id (vars.JOSHUATECH_CI_APP_CLIENT_ID) · private-key (secrets.JOSHUATECH_CI_APP_PRIVATE_KEY) · repositories platform-gitops · permission-contents write · permission-pull-requests write and no unparsed line (no skip-token-revoke, no owner, no other permission — quoted keys included)' (
        $app.Count -eq 1 -and $usesCount -eq 1 -and (Test-Same $app[0].job 'bump') -and (Test-Same $app[0].step.id 'app') -and
        (Test-MapExact $w @{ 'client-id' = '${{ vars.JOSHUATECH_CI_APP_CLIENT_ID }}'; 'private-key' = '${{ secrets.JOSHUATECH_CI_APP_PRIVATE_KEY }}'; repositories = 'platform-gitops'; 'permission-contents' = 'write'; 'permission-pull-requests' = 'write' })
    ) "app steps: $($app.Count) (uses lines $usesCount); with: [$(Format-Map $w.map)] bad [$($w.bad -join ' | ')]"
}

Test-Group 'pp-18' {
    $tok = Get-Count $wfCodeText 'steps.app.outputs.token'
    $slug = Get-Count $wfCodeText 'steps.app.outputs.app-slug'
    # App 스텝 참조는 점 꼴 · 괄호 꼴(steps['app'] · steps["app"]) 모두 센다 — 위의 셋(token 둘 · app-slug 하나) 밖의 참조가 없어야 한다(라운드 2 F16)
    $appRefs = [regex]::Matches($wfCodeText, 'steps\s*(\.\s*app\b|\[\s*[''"]app[''"]\s*\])').Count
    $gco = @(Find-Steps $jobs 'checkout-gitops')
    $bs = @(Find-Steps $jobs 'bs')
    $ok = $tok -eq 2 -and $slug -eq 1 -and $appRefs -eq 3 -and $gco.Count -eq 1 -and $bs.Count -eq 1 -and
        (Test-Same ([string]$gco[0].step.with.map['token']) '${{ steps.app.outputs.token }}') -and
        (Test-Same ([string]$bs[0].step.env.map['GH_TOKEN']) '${{ steps.app.outputs.token }}') -and
        (Test-Same ([string]$bs[0].step.env.map['APP_SLUG']) '${{ steps.app.outputs.app-slug }}')
    Assert 'pp-18: the App step is referenced exactly three times in any form (dot or bracket — steps.app / steps[''app''] / steps["app"]): steps.app.outputs.token only in the gitops checkout token: and the bump script env GH_TOKEN, app-slug only in its APP_SLUG' $ok "token refs: $tok; app-slug refs: $slug; App step refs (any form): $appRefs; gitops checkouts: $($gco.Count); bump calls: $($bs.Count)"
}

Test-Group 'pp-19' {
    $gco = @(Find-Steps $jobs 'checkout-gitops')
    $cmt = if ($gco.Count -eq 1) { @($gco[0].step.lines | Where-Object { (Test-CommentLine $_) -and (Test-Has $_ 'git push') }).Count } else { 0 }
    $w = if ($gco.Count -eq 1) { $gco[0].step.with } else { @{ map = [ordered]@{}; bad = [string[]]@('missing') } }
    Assert 'pp-19: one gitops checkout (bump) with exactly repository joshua92y/platform-gitops · ref main · token = App token · persist-credentials true (with a comment line giving the reason — git push) · path gitops, and no unparsed line (no submodules etc., quoted keys included)' (
        $gco.Count -eq 1 -and (Test-Same $gco[0].job 'bump') -and $cmt -ge 1 -and
        (Test-MapExact $w @{ repository = $K.GitopsRepo; ref = 'main'; token = '${{ steps.app.outputs.token }}'; 'persist-credentials' = 'true'; path = 'gitops' })
    ) "gitops checkouts: $($gco.Count); reason comment lines: $cmt; with: [$(Format-Map $w.map)] bad [$($w.bad -join ' | ')]"
}

Test-Group 'pp-20' {
    $yq = @(Find-Steps $jobs 'yq')
    # 주의: Test-Group이 본문을 점 소싱하므로 그 매개변수 이름($id · $body)에 값을 넣지 않는다
    $yqBody = if ($yq.Count -eq 1) { Get-NormalizedBody $yq[0].step.runs[0] } else { '' }
    $want = Get-NormalizedBody $K.YqBody
    $same = Test-Same $yqBody $want
    $firstDiff = ''
    if (-not $same) {
        $a = $yqBody -split "`n"; $b = $want -split "`n"
        for ($i = 0; $i -lt [Math]::Max($a.Count, $b.Count); $i++) { if (-not (Test-Same $(if ($i -lt $a.Count) { $a[$i] } else { '<none>' }) $(if ($i -lt $b.Count) { $b[$i] } else { '<none>' }))) { $firstDiff = "line $($i + 1): got [$(if ($i -lt $a.Count) { $a[$i] })] want [$(if ($i -lt $b.Count) { $b[$i] })]"; break } }
    }
    Assert 'pp-20: one yq install step (bump) with env exactly YQ_VERSION v4.53.6 + the paired linux_arm64 sha256 (gitops promote value) and a run: body ordinal-equal (after removing the common indentation) to the harness constant — https-only fetch, sha256sum -c before install, version check against YQ_VERSION, $RUNNER_TEMP/bin + GITHUB_PATH (no || true, no reordering)' (
        $yq.Count -eq 1 -and (Test-Same $yq[0].job 'bump') -and (Test-MapExact $yq[0].step.env @{ YQ_VERSION = $K.YqVersion; YQ_SHA256 = $K.YqSha256 }) -and $same
    ) "yq steps: $($yq.Count); env: [$(if ($yq.Count -eq 1) { Format-Map $yq[0].step.env.map })]; body equal: $same; $firstDiff"
}

Test-Group 'pp-21' {
    $bs = @(Find-Steps $jobs 'bs')
    $je = Get-JobSubMap $jobs['bump'] 'env'
    $se = if ($bs.Count -eq 1) { $bs[0].step.env } else { @{ map = [ordered]@{}; bad = [string[]]@('missing') } }
    Assert 'pp-21: one bump script call (bump) whose run: is exactly "exec bash scripts/ci/publish-pod-bump.sh" (exec — the runner sends cancel signals to the step shell PID only), step env exactly {GH_TOKEN (App token), MONOREPO_TOKEN (github.token), DIGEST, APP_SLUG, GITOPS_DIR} with no unparsed line, bump job env exactly BOT_SLUG joshuatech-gitapp-1 · BOT_ID 323873425 (harness constants from gitops validate.sh:232-233)' (
        $bs.Count -eq 1 -and (Test-Same $bs[0].job 'bump') -and
        (Test-MapExact $se @{ GH_TOKEN = '${{ steps.app.outputs.token }}'; MONOREPO_TOKEN = '${{ github.token }}'; DIGEST = '${{ needs.publish.outputs.digest }}'; APP_SLUG = '${{ steps.app.outputs.app-slug }}'; GITOPS_DIR = 'gitops' }) -and
        $je.found -and (Test-MapExact $je @{ BOT_SLUG = $K.BotSlug; BOT_ID = $K.BotId })
    ) "calls: $($bs.Count); step env: [$(Format-Map $se.map)] bad [$($se.bad -join ' | ')]; job env: [$(Format-Map $je.map)] bad [$($je.bad -join ' | ')]"
}

Test-Group 'pp-22' {
    $why = [Collections.Generic.List[string]]::new()
    if (-not $asExists) { $why.Add('missing') }
    if ($asLines.Count -eq 0 -or -not (Test-Same $asLines[0] '#!/usr/bin/env bash')) { $why.Add('first line') }
    if (@($asCode | Where-Object { Test-Same $_ 'set -euo pipefail' }).Count -ne 1) { $why.Add('set -euo pipefail') }
    if (@($asCode | Where-Object { $_ -match '\bjq\b' }).Count -gt 0) { $why.Add('jq') }
    if (@($asCode | Where-Object { Test-Has $_ '--format' }).Count -lt 2) { $why.Add('--format') }
    if ((Get-Count $asCodeText 'printf "%q"') -lt 4) { $why.Add('printf "%q" templates') }
    if (-not (Test-Has $asCodeText 'readonly T_MEDIATYPE=''{{printf "%s" .Manifest.MediaType}}''')) { $why.Add('imagetools template must not start with {{.Manifest (buildx < v0.33.0 prints the whole manifest)') }
    foreach ($n in @('.venv', 'identity_admin', 'manage.py', 'pyproject.toml', 'uv.lock')) { if (-not (Test-Has $asCodeText $n)) { $why.Add("allow-list $n") } }
    if (-not (Test-Has $asCodeText '::stop-commands::')) { $why.Add('stop-commands') }
    if (-not ((Test-Has $asCodeText '/dev/urandom') -or (Test-Has $asCodeText 'random/uuid'))) { $why.Add('random token') }
    if (-not (Test-Has $asCodeText "'::%s::\n'")) { $why.Add('resume line') }
    Assert 'pp-22: assert-image source: #!/usr/bin/env bash, set -euo pipefail, no jq, docker --format templates with printf "%q" (imagetools template wrapped in printf — not starting with {{.Manifest), the five allow-list names, ::stop-commands:: with a random token and the resume line' (
        $why.Count -eq 0
    ) "problems: [$($why -join ', ')]"
}

Test-Group 'pp-23' {
    $why = [Collections.Generic.List[string]]::new()
    if (-not $bsExists) { $why.Add('missing') }
    if ($bsLines.Count -eq 0 -or -not (Test-Same $bsLines[0] '#!/usr/bin/env bash')) { $why.Add('first line') }
    if (@($bsCode | Where-Object { Test-Same $_ 'set -euo pipefail' }).Count -ne 1) { $why.Add('set -euo pipefail') }
    if (@($bsCode | Where-Object { $_ -match '(?i)kustomize' }).Count -gt 0) { $why.Add('kustomize') }
    $adds = @($bsCode | Where-Object { $_ -match '\bgit\s+(-c\s+\S+\s+)*add\b' })
    if ($adds.Count -ne 1 -or -not (Test-Same $adds[0].Trim() 'git add -- "$dev"')) { $why.Add("git add [$($adds -join ' | ')]") }
    $pushes = @($bsCode | Where-Object { $_ -match '\bgit\s+(-c\s+\S+\s+)*push\b' })
    $del = @($pushes | Where-Object { Test-Has $_ 'origin --delete' })
    $up = @($pushes | Where-Object { -not (Test-Has $_ '--delete') })
    if ($del.Count -lt 1 -or $up.Count -ne 1 -or -not (Test-Has $up[0] '"HEAD:refs/heads/$') -or $up[0] -match '(?i)--force|\s-f\b|\+HEAD|\+refs|\bmain\b|--mirror|--all|--tags') { $why.Add("push lines [$($pushes -join ' | ')]") }
    if (-not (Test-Has $bsCodeText '--auto --squash --match-head-commit')) { $why.Add('--auto --squash --match-head-commit') }
    if (@($bsCode | Where-Object { (Test-Has $_ 'gh api') -and (Test-Has $_ '/pulls/') }).Count -lt 1) { $why.Add('REST pulls/') }
    $banned = @($bsCode | Where-Object { $_ -match '(?i)statusCheckRollup|gh pr view|graphql|check-runs|gh pr checks' })
    if ($banned.Count -gt 0) { $why.Add("banned [$($banned -join ' | ')]") }
    $ps = [regex]::Match($bsCodeText, '(?m)^readonly POLL_SECONDS=(\d+)$'); $pl = [regex]::Match($bsCodeText, '(?m)^readonly POLL_LIMIT=(\d+)$'); $wl = [regex]::Match($bsCodeText, '(?m)^readonly WAIT_LIMIT_SECONDS=(\d+)$')
    if (-not ($ps.Success -and $pl.Success -and $wl.Success) -or ([int]$ps.Groups[1].Value * [int]$pl.Groups[1].Value) -gt 900 -or [int]$wl.Groups[1].Value -gt 900 -or [int]$ps.Groups[1].Value -lt 1) { $why.Add('wait limit (POLL_SECONDS x POLL_LIMIT <= 900 and WAIT_LIMIT_SECONDS <= 900)') }
    foreach ($n in @('gh pr close', '--disable-auto', 'ls-remote', '::stop-commands::')) { if (-not (Test-Has $bsCodeText $n)) { $why.Add($n) } }
    # 모노레포 토큰(F2 · 라운드 2 F15): MONOREPO_TOKEN은 ⓪ 존재 확인 · 내보내지 않는 변수로 옮기기 · unset 세 줄에만 있고, 그 값($mono)은
    # ①′ compare 한 줄에서만 GH_TOKEN으로 준다 — 그 밖의 GH_TOKEN 재설정 없음
    $monoLines = [string[]]@($bsCode | Where-Object { Test-Has $_ 'MONOREPO_TOKEN' } | ForEach-Object { $_.Trim() })
    $monoOk = $monoLines.Count -eq 3 -and $monoLines[0].StartsWith('[[ -n ${MONOREPO_TOKEN:-} ]] || fail input ', [StringComparison]::Ordinal) -and
        (Test-Same $monoLines[1] 'declare +x mono="$MONOREPO_TOKEN"') -and (Test-Same $monoLines[2] 'unset MONOREPO_TOKEN')
    $monoUse = @($bsCode | Where-Object { $_ -cmatch '\$(mono\b|\{mono\})' })
    $ghTokenSet = @($bsCode | Where-Object { $_ -match '(^|[\s;])(export\s+)?GH_TOKEN=' -and -not (Test-Has $_ $K.MonoCompareCall) })
    if (-not $monoOk -or $monoUse.Count -ne 1 -or -not (Test-Has $monoUse[0] $K.MonoCompareCall) -or $ghTokenSet.Count -gt 0) { $why.Add("MONOREPO_TOKEN lines [$($monoLines -join ' | ')]; `$mono uses [$($monoUse -join ' | ')]; GH_TOKEN assignments [$($ghTokenSet -join ' | ')]") }
    # 두 compare의 머리는 refs/heads/main(같은 이름 태그로 풀리지 않게 — 라운드 2 F12)
    if ((Test-Has $bsCodeText '...main"') -or -not (Test-Has $bsCodeText 'compare/$msha...refs/heads/main"')) { $why.Add('compare head must be refs/heads/main') }
    # 원격 브랜치 판정은 ref 이름이 정확히 같은 줄만 센다 — ls-remote --exit-code(꼬리 일치)를 쓰지 않는다(라운드 2 F17)
    if (Test-Has $bsCodeText 'ls-remote --exit-code') { $why.Add('ls-remote --exit-code (tail match)') }
    if (-not (Test-Has $bsCodeText 'trap on_signal INT TERM')) { $why.Add('trap on_signal INT TERM') }
    # 신호가 show의 stop-commands 구간 안에서 오면 on_signal이 그 구간부터 닫는다(라운드 2 F14)
    if (@($bsCode | Where-Object { Test-Same $_.Trim() 'if [[ -n ${SHOW_TOK:-} ]]; then printf ''::%s::\n'' "$SHOW_TOK"; SHOW_TOK=''''; fi' }).Count -ne 1) { $why.Add('on_signal closes an open stop-commands region (SHOW_TOK)') }
    Assert 'pp-23: bump source: #!/usr/bin/env bash, set -euo pipefail, no kustomize, git add only as git add -- "$dev", one branch push (no force / + / main) plus the cleanup delete push, --auto --squash --match-head-commit, REST pulls/ polling, no statusCheckRollup / gh pr view / graphql / check-runs, wait <= 15 min, cleanup (gh pr close · --disable-auto · push origin --delete · ls-remote), ::stop-commands::, MONOREPO_TOKEN only in the presence check and its move to an unexported variable (+ unset) whose value is used only by the stale-guard compare call (no other GH_TOKEN assignment), compare heads refs/heads/main, no ls-remote --exit-code, INT/TERM trap, on_signal closes an open stop-commands region' (
        $why.Count -eq 0
    ) "problems: [$($why -join ', ')]"
}

Test-Group 'pp-24' {
    $end = -1
    for ($i = 0; $i -lt $wfLines.Count; $i++) { if ($wfLines[$i] -match '^name:') { $end = $i; break } }
    $header = if ($end -gt 0) { [string[]]$wfLines[0..($end - 1)] } else { [string[]]@() }
    $nonComment = @($header | Where-Object { $_.Trim().Length -gt 0 -and -not $_.StartsWith('#') }).Count
    $h = $header -join "`n"
    $needles = @('# - job build-check', '# - job publish', '# - job bump', 'VD-5', '편차', 'kustomize', '캐시 없음', 'pull_request', 'workflow_dispatch', '불변식', 'APP_GIT_SHA', 'labels', 'annotations', 'push 전', '들여쓰기', 'Re-run은 가장 새 실행에 — 가드가 낡은 실행을 건너뛴다', '거는 순간의 head를 고정한다', 'GHSA-w26x-xg27-7qjc', 'GHSA-2fqp-xg6f-v7gj')
    $missing = @($needles | Where-Object { -not (Test-Has $h $_) })
    Assert 'pp-24: the header comment has an entry per job (build-check · publish · bump), VD-5, the deviations (kustomize not used · no cache · PR build-check · dispatch only when missed · Re-run on the newest run — the guard skips stale runs), the invariants (revision only from APP_GIT_SHA · no metadata labels / annotations · assert before push), the auto-merge head wording, the accepted BuildKit advisories and the indentation / syntax convention' (
        $header.Count -gt 0 -and $nonComment -eq 0 -and $missing.Count -eq 0
    ) "header lines: $($header.Count) (non-comment $nonComment); missing: [$($missing -join ' | ')]"
}

Test-Group 'pp-25' {
    $runSteps = @(foreach ($jn in $jobs.Keys) { foreach ($s in $jobs[$jn].steps) { if ($s.runs.Count -ge 1) { $s.kind } } })
    $count = @{}
    foreach ($k in $runSteps) { $count[$k] = 1 + [int]$count[$k] }
    Assert 'pp-25: the workflow has exactly six run: steps — yq install (1) · attestation self-verify (1) · assert-image calls (3) · bump script call (1); the logic lives in the two scripts' (
        $runSteps.Count -eq 6 -and $count['yq'] -eq 1 -and $count['verify'] -eq 1 -and $count['as'] -eq 3 -and $count['bs'] -eq 1
    ) "run steps: [$($runSteps -join ', ')]"
}

Test-Group 'pp-26' {
    $g = Get-GrammarViolations $wfLines $wfRaw
    Assert 'pp-26: YAML grammar — every code line outside block scalars is a strict key line (unquoted [A-Za-z0-9_-]+ directly followed by a colon; value not starting with { [ & * ! % @ ` #) or a one-line list item, block scalar headers are exactly | (no > >- >+ |- |+ or indentation indicator), no continuation line deeper than a value line, quoted values closed on their line, no tab outside block scalars, no control / format / line-separator character in the file; the only exception is the top-level "permissions: {}" (no quoted keys, "key :", ?, flow forms, anchors, aliases, tags, multi-line scalars)' (
        $wfExists -and $g.Count -eq 0
    ) "violations: [$($g -join ' | ')]"
}

Test-Group 'pp-27' {
    $br = Get-BoundaryReport $wfLines
    Assert 'pp-27: block boundaries — after the header every column-0 line is one of the six strict top-level keys (no column-0 comment); under on: and jobs: every line shallower than 4 columns is a strict header (push / pull_request / workflow_dispatch · build-check / publish / bump — each exactly once, no trailing comment) and no comment is shallower than 4 columns (no hidden job, no block-cutting comment)' (
        $wfExists -and $br.bad.Count -eq 0
    ) "violations: [$($br.bad -join ' | ')]"
}

Test-Group 'pp-28' {
    $why = [Collections.Generic.List[string]]::new()
    $n = 0
    foreach ($jn in $jobs.Keys) {
        $k = 0
        foreach ($s in $jobs[$jn].steps) {
            $k++; $n++
            $keys = [string[]]@($s.sk.map.Keys)
            if ($s.sk.bad.Count -gt 0) { $why.Add("$jn step $k unparsed [$($s.sk.bad -join ' | ')]"); continue }
            if ($s.uses.Length -gt 0) {
                if (-not ((Test-SameSet $keys @('uses', 'with')) -or (Test-SameSet $keys @('id', 'uses', 'with')))) { $why.Add("$jn step $k ($($s.uses)) keys [$($keys -join ', ')]") }
            } elseif (-not (Test-SameSet $keys @('name', 'env', 'run'))) { $why.Add("$jn step $k (run) keys [$($keys -join ', ')]") }
            # 스텝 이름은 로그 · 요약에 그대로 찍힌다 — 표현식을 넣지 않는다(토큰 참조가 이름으로 새는 길 · 라운드 2 F16)
            if ($s.sk.map.Contains('name') -and (Test-Has ([string]$s.sk.map['name']) '${{')) { $why.Add("$jn step $k name has an expression [$($s.sk.map['name'])]") }
        }
    }
    Assert 'pp-28: step key sets are exact — uses steps {uses, with} or {id, uses, with}, run steps {name, env, run}; no step-level if / continue-on-error / shell / working-directory / timeout-minutes, no env on a uses step, no unparsed step key line, no ${{ in a step name' (
        $n -ge 18 -and $why.Count -eq 0
    ) "steps: $n; $($why -join '; ')"
}

# ==================== 실행 계층 ====================
# ---------- 도구 ----------
# Windows: Git의 usr/bin/bash.exe만(머리 주석). 그 밖: PATH의 bash.
function Find-Bash {
    if ($IsWindows) {
        $roots = [Collections.Generic.List[string]]::new()
        foreach ($r in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) { if ($r) { $roots.Add((Join-Path $r 'Git')) } }
        if ($env:LOCALAPPDATA) { $roots.Add((Join-Path $env:LOCALAPPDATA 'Programs/Git')) }
        $g = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($g) { $d = Split-Path -Parent $g.Source; $roots.Add((Split-Path -Parent $d)); $roots.Add((Split-Path -Parent (Split-Path -Parent $d))) }
        foreach ($r in $roots) { $c = Join-Path $r 'usr/bin/bash.exe'; if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path } }
        return $null
    }
    $cmd = Get-Command bash -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}
# yq: PUBLISH_POD_YQ → PATH → .superpowers/bin 순 — --version이 mikefarah v4.53.6인 첫 것
function Find-Yq {
    $cands = [Collections.Generic.List[object]]::new()
    if (-not [string]::IsNullOrEmpty($env:PUBLISH_POD_YQ)) { $cands.Add(@{ p = $env:PUBLISH_POD_YQ; label = 'PUBLISH_POD_YQ' }) }
    foreach ($c in @(Get-Command yq -CommandType Application -All -ErrorAction SilentlyContinue)) { $cands.Add(@{ p = $c.Source; label = 'PATH' }) }
    foreach ($n in @('yq.exe', 'yq')) { $p = Join-Path $repo ".superpowers/bin/$n"; if (Test-Path -LiteralPath $p -PathType Leaf) { $cands.Add(@{ p = $p; label = '.superpowers/bin' }) } }
    foreach ($c in $cands) {
        if (-not (Test-Path -LiteralPath $c.p -PathType Leaf)) { continue }
        $v = ((@(& $c.p --version 2>$null) -join ' ')).Trim()
        if ((Test-Has $v 'mikefarah') -and $v.EndsWith(" $($K.YqVersion)", [StringComparison]::Ordinal)) { return $c }
    }
    return $null
}
$script:bash = Find-Bash
$script:bashDir = if ($script:bash) { Split-Path -Parent $script:bash } else { '' }
$script:cygpath = if ($IsWindows -and $script:bashDir) { Join-Path $script:bashDir 'cygpath.exe' } else { '' }
$script:gitCmd = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$script:yqInfo = Find-Yq
$asMissing = [string[]]@(if (-not $script:bash) { 'bash' }; if ($IsWindows -and $script:bash -and -not (Test-Path -LiteralPath $script:cygpath -PathType Leaf)) { 'cygpath' })
$bsMissing = [string[]]@($asMissing; if (-not $script:gitCmd) { 'git' }; if (-not $script:yqInfo) { "yq $($K.YqVersion)" })
if (@($script:only | Where-Object { $_ -like 'px*' }).Count -gt 0 -or $script:only.Count -eq 0) {
    Write-Host "info: bash = $(if ($script:bash) { if ($IsWindows) { 'Git usr/bin/bash.exe' } else { 'bash from PATH' } } else { 'not found' }); yq = $(if ($script:yqInfo) { "$($script:yqInfo.label) ($($K.YqVersion))" } else { 'not found' })"
}

# 환경 변수를 값으로 둔다 — $null · 빈 값이면 지운다(events-compat.tests.ps1)
function Set-EnvVar([string]$name, [string]$value) {
    if ([string]::IsNullOrEmpty($value)) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    else { Set-Item -LiteralPath "Env:$name" -Value $value }
}
function New-Dir([string]$p) { [void][IO.Directory]::CreateDirectory($p) }
function Write-Text([string]$p, [string]$s) { New-Dir (Split-Path -Parent $p); [IO.File]::WriteAllText($p, $s, [Text.UTF8Encoding]::new($false)) }
function Read-TextOrEmpty([string]$p) { if (Test-Path -LiteralPath $p -PathType Leaf) { return ([IO.File]::ReadAllText($p) -replace "`r`n", "`n") } else { return '' } }
function Set-Exec([string]$p) { if (-not $IsWindows) { [IO.File]::SetUnixFileMode($p, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute, GroupRead, GroupExecute') } }
# 하네스 임시 루트 아래 경로를 bash가 보는 꼴로(Windows = cygpath -u — 사용자 임시 디렉터리가 /tmp로 보인다)
function ConvertTo-Posix([string]$p) {
    if (-not $IsWindows) { return $p }
    if ($p.StartsWith($script:root, [StringComparison]::OrdinalIgnoreCase)) { return $script:rootPosix + ($p.Substring($script:root.Length) -replace '\\', '/') }
    return ((& $script:cygpath -u $p) | Select-Object -First 1)
}
function ConvertTo-Fwd([string]$p) { return ($p -replace '\\', '/') }

# 픽스처 git(events-compat.tests.ps1 Resolve-FixtureGit · Invoke-Git과 같은 방식): Windows에서는 설치의 실제 바이너리를 쓰고, exit -1에 출력이
# 없으면 두 번까지 · 「git: '<제 경로>' is not a git command」 한 줄이면 한 번 다시 부른다(판정과 무관한 거짓 FAIL 방지 — 횟수는 note 줄).
$script:gitRetries = 0
function Resolve-FixtureGit {
    if (-not $IsWindows) { return 'git' }
    $execPath = @(& git --exec-path 2>$null)
    if ($LASTEXITCODE -ne 0 -or $execPath.Count -ne 1) { return 'git' }
    $m = [regex]::Match(([string]$execPath[0]).Trim().Replace([string][char]0x5c, '/'), '^(.+)/libexec/git-core/?$')
    if (-not $m.Success) { return 'git' }
    $cand = "$($m.Groups[1].Value)/bin/git.exe"
    if (-not (Test-Path -LiteralPath $cand -PathType Leaf)) { return 'git' }
    if (-not (Test-Same ((@(& git --version 2>$null) -join "`n").Trim()) ((@(& $cand --version 2>$null) -join "`n").Trim()))) { return 'git' }
    return $cand
}
# 출력은 콘솔 코드 페이지와 무관하게 UTF-8로 디코드한다(호출 동안만 [Console]::OutputEncoding을 UTF-8로 — 커밋 제목의 → 등을 대조한다).
function Invoke-Git([string]$dir, [string[]]$gitArgs) {
    $spawn = 0; $self = $false
    $prevEnc = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        for ($attempt = 1; ; $attempt++) {
            $out = @(& $script:fixtureGit -C $dir @gitArgs 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            if ($code -eq -1 -and $out.Count -eq 0 -and $spawn -lt 2) { $spawn++; $script:gitRetries++; continue }
            if (-not $self -and $code -ne 0 -and $out.Count -eq 1 -and ([string]$out[0]) -match "\Agit: '.+' is not a git command\. See 'git --help'\.\z") { $self = $true; $script:gitRetries++; continue }
            break
        }
    } finally { [Console]::OutputEncoding = $prevEnc }
    if ($code -ne 0) { throw "git $($gitArgs -join ' ') (exit $code): $($out -join ' | ')" }
    return ($out -join "`n").Trim()
}

# ---------- 가짜 명령(bash) ----------
$fakeGh = @'
#!/usr/bin/env bash
# 가짜 gh(tests/scripts/publish-pod.tests.ps1 · T074) — 네트워크 없음. 호출을 PUBLISH_POD_FAKE_STATE/gh.log에 남기고(첫 칸 = gh:<토큰 표지> —
# GH_TOKEN이 App 토큰이면 app · 모노레포 토큰이면 mono · 그 밖 other — 값은 남기지 않는다) env의 MONOREPO_TOKEN 유무를 gh-env.log에 남긴 뒤
# 같은 디렉터리의 시나리오 파일(create · merge · close · disable · users-id · users-login · polls · compare · main-compare · gh-stderr ·
# inject-state · close-term · compare-term · decoy-on-create)대로 답한다. compare 경로의 머리 꼴은 가리지 않는다 — 머리가 refs/heads/main인지는
# 호출 기록으로 단언한다(px-8 · px-22 · 모노레포 compare 한 번 단언).
# 머지를 흉내 낼 때 bare 원격(PUBLISH_POD_FAKE_REMOTE) main에 squash 커밋을 만들고(브랜치는 지운다) 그 sha를 merge_commit_sha로 준다 — 그 뒤의
# PR 조회는 늘 머지 상태다.
set -u
st=${PUBLISH_POD_FAKE_STATE:?}
R=${PUBLISH_POD_FAKE_REMOTE:-}
DEV=${PUBLISH_POD_FAKE_DEV:-}
tok=other
if [[ -n ${GH_TOKEN:-} && ${GH_TOKEN:-} == "${PUBLISH_POD_FAKE_APP_TOKEN:-}" ]]; then tok=app; fi
if [[ -n ${GH_TOKEN:-} && ${GH_TOKEN:-} == "${PUBLISH_POD_FAKE_MONO_TOKEN:-}" ]]; then tok=mono; fi
{ printf 'gh:%s' "$tok"; for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >> "$st/gh.log"
# 호출마다 env에 MONOREPO_TOKEN이 있는지(값이 아니라 있음 · 없음만 — px-27 · 라운드 2 F15)
if [[ -n ${MONOREPO_TOKEN+x} ]]; then printf 'present\n' >> "$st/gh-env.log"; else printf 'absent\n' >> "$st/gh-env.log"; fi
if [[ -f $st/gh-stderr ]]; then cat -- "$st/gh-stderr" >&2; fi
opt() { if [[ -f $st/$1 ]]; then cat -- "$st/$1"; else printf '%s' "$2"; fi; }
gitr() { git --git-dir="$R" "$@"; }
bot='joshuatech-gitapp-1[bot]'
auto='{"enabled_by":{"login":"joshuatech-gitapp-1[bot]","id":323873425},"merge_method":"squash"}'
pr_json() { # <state> <merged> <merged_at> <merged_by> <auto_merge> <mergeable_state> <head sha> <head ref> <merge_commit_sha> <base ref>
  printf '{"number":7,"state":"%s","merged":%s,"merged_at":%s,"merged_by":%s,"auto_merge":%s,"mergeable_state":"%s","head":{"sha":"%s","ref":"%s"},"merge_commit_sha":%s,"base":{"ref":"%s"}}\n' "$@"
}
squash() { # <mode> <branch> — bare 원격 main에 머지 커밋을 한 번만 만든다(브랜치는 지운다 — delete_branch_on_merge)
  local mode=$1 b=$2 tip tree parent c idx blob content
  if [[ -f $st/merge-sha ]]; then cat -- "$st/merge-sha"; return 0; fi
  tip=$(gitr rev-parse --verify --quiet "refs/heads/$b") || return 1
  tree=$(gitr rev-parse "$tip^{tree}")
  if [[ $mode == merged-baddigest || $mode == merged-extrafile ]]; then
    idx=$st/squash.idx
    GIT_INDEX_FILE=$idx gitr read-tree "$tree"
    if [[ $mode == merged-baddigest ]]; then
      content=$(gitr show "$tree:$DEV" | sed -E 's/sha256:[0-9a-f]{64}/sha256:cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd/')
      blob=$(printf '%s\n' "$content" | gitr hash-object -w --stdin)
      GIT_INDEX_FILE=$idx gitr update-index --cacheinfo "100644,$blob,$DEV"
    else
      blob=$(printf 'extra: true\n' | gitr hash-object -w --stdin)
      GIT_INDEX_FILE=$idx gitr update-index --add --cacheinfo "100644,$blob,${DEV%/*}/extra.yaml"
    fi
    tree=$(GIT_INDEX_FILE=$idx gitr write-tree)
  fi
  parent=$(gitr rev-parse --verify refs/heads/main)
  if [[ $mode == merged-twoparents ]]; then
    c=$(GIT_AUTHOR_NAME=GitHub GIT_AUTHOR_EMAIL=noreply@github.com GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com gitr commit-tree "$tree" -p "$parent" -p "$tip" -m "merge (#7)")
  else
    c=$(GIT_AUTHOR_NAME=GitHub GIT_AUTHOR_EMAIL=noreply@github.com GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com gitr commit-tree "$tree" -p "$parent" -m "$(opt pr-title squash) (#7)")
  fi
  gitr update-ref refs/heads/main "$c" "$parent"
  gitr update-ref -d "refs/heads/$b"
  printf '%s' "$c" > "$st/merge-sha"
  printf '%s' "$c"
}
merged_json() { # <mode> <branch>
  local msha
  msha=$(squash "$1" "$2") || { echo 'fake gh: squash failed' >&2; exit 4; }
  pr_json closed true '"2026-11-16T00:00:00Z"' "{\"login\":\"$bot\",\"id\":323873425}" "$auto" unknown "$(opt pr-head-sha '')" "$2" "\"$msha\"" main
}
poll() {
  local n mode branch tip ms
  local -a P=()
  n=$(( $(opt poll-count 0) + 1 ))
  printf '%s' "$n" > "$st/poll-count"
  mapfile -t P < "$st/polls"
  if (( n <= ${#P[@]} )); then mode=${P[n-1]}; else mode=${P[${#P[@]}-1]}; fi
  if [[ -f $st/merge-sha ]]; then mode=merged; fi
  branch=$(opt pr-head '')
  tip=$(gitr rev-parse --verify --quiet "refs/heads/$branch") || tip=$(opt pr-head-sha '')
  ms='blocked'
  if [[ -f $st/inject-state ]]; then ms='::warning::injected-gh-state'; fi
  case $mode in
    open) pr_json open false null null "$auto" "$ms" "$tip" "$branch" '"2222222222222222222222222222222222222222"' main ;;
    noauto) pr_json open false null null null "$ms" "$tip" "$branch" '"2222222222222222222222222222222222222222"' main ;;
    headmove) pr_json open false null null "$auto" "$ms" 1111111111111111111111111111111111111111 "$branch" '"2222222222222222222222222222222222222222"' main ;;
    basechange) pr_json open false null null "$auto" "$ms" "$tip" "$branch" '"2222222222222222222222222222222222222222"' release ;;
    closed) pr_json closed false null null null "$ms" "$tip" "$branch" null main ;;
    apierror) echo 'gh: HTTP 502: Bad Gateway' >&2; exit 1 ;;
    merged | merged-baddigest | merged-extrafile | merged-twoparents) merged_json "$mode" "$branch" ;;
    *) echo 'fake gh: unknown poll mode' >&2; exit 4 ;;
  esac
}
mono_compare() { # 모노레포 compare(낡은 실행 가드) — 시나리오 compare
  local i
  case $(opt compare identical) in
    identical) printf '{"status":"identical","ahead_by":0,"behind_by":0,"total_commits":0,"commits":[],"files":[]}\n' ;;
    ahead-hit) printf '{"status":"ahead","ahead_by":2,"behind_by":0,"total_commits":2,"commits":[{"sha":"1111111111111111111111111111111111111111"},{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"docs/notes.md","status":"modified"},{"filename":"apps/identity-admin/identity_admin/views.py","status":"modified"}]}\n' ;;
    ahead-rename) printf '{"status":"ahead","ahead_by":1,"behind_by":0,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"docs/moved.py","status":"renamed","previous_filename":"packages/django-common/src/django_common/x.py"}]}\n' ;;
    ahead-nofiles) printf '{"status":"ahead","ahead_by":2,"behind_by":0,"total_commits":2,"commits":[{"sha":"1111111111111111111111111111111111111111"},{"sha":"cafe0123456789abcdef0123456789abcdef0123"}]}\n' ;;
    ahead-filesnull) printf '{"status":"ahead","ahead_by":2,"behind_by":0,"total_commits":2,"commits":[],"files":null}\n' ;;
    ahead-filesmap) printf '{"status":"ahead","ahead_by":1,"behind_by":0,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":{"a":{"filename":"apps/identity-admin/x"}}}\n' ;;
    ahead-nested) printf '{"status":"ahead","ahead_by":1,"behind_by":0,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"scripts/ci/publish-pod-x/y.sh","status":"added"}]}\n' ;;
    ahead-script) printf '{"status":"ahead","ahead_by":1,"behind_by":0,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"scripts/ci/publish-pod-bump.sh","status":"modified"}]}\n' ;;
    ahead-miss) printf '{"status":"ahead","ahead_by":3,"behind_by":0,"total_commits":3,"commits":[{"sha":"1111111111111111111111111111111111111111"},{"sha":"2222222222222222222222222222222222222222"},{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"docs/README.md","status":"modified"},{"filename":"apps/web/app/page.tsx","status":"renamed","previous_filename":"apps/web/app/old.tsx"},{"filename":"scripts/ci/events-compat.sh","status":"modified"}]}\n' ;;
    behind) printf '{"status":"behind","ahead_by":0,"behind_by":1,"total_commits":0,"commits":[],"files":[]}\n' ;;
    diverged) printf '{"status":"diverged","ahead_by":1,"behind_by":1,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":[{"filename":"docs/x.md","status":"modified"}]}\n' ;;
    files300)
      printf '{"status":"ahead","ahead_by":1,"behind_by":0,"total_commits":1,"commits":[{"sha":"cafe0123456789abcdef0123456789abcdef0123"}],"files":['
      for ((i = 0; i < 300; i++)); do
        if (( i )); then printf ','; fi
        printf '{"filename":"docs/f%03d.md","status":"modified"}' "$i"
      done
      printf ']}\n' ;;
    error) echo 'gh: HTTP 500 ::warning::injected-compare-error' >&2; exit 1 ;;
    *) echo 'fake gh: unknown compare mode' >&2; exit 4 ;;
  esac
}
gitops_compare() { # gitops compare <머지 커밋>...refs/heads/main — 시나리오 main-compare가 없으면 bare 원격의 실제 조상 관계로 답한다
  local base s m
  base=${1#repos/joshua92y/platform-gitops/compare/}
  base=${base%...*}
  # compare-term: 머지 결과 대조 도중 한 번만 부모(bump 스크립트)에 SIGTERM(px-29 (iv) — 대조 중 취소)
  if [[ -f $st/compare-term ]]; then rm -f -- "$st/compare-term"; kill -TERM "$PPID"; fi
  s=$(opt main-compare auto)
  if [[ $s == auto ]]; then
    m=$(gitr rev-parse --verify refs/heads/main)
    if [[ $base == "$m" ]]; then s=identical
    elif gitr merge-base --is-ancestor "$base" "$m" 2> /dev/null; then s=ahead
    else s=diverged; fi
  fi
  printf '{"status":"%s","ahead_by":0,"behind_by":0,"total_commits":0,"commits":[],"files":[]}\n' "$s"
}
create() {
  local a prev='' head='' body='' title='' tip t c
  for a in "$@"; do
    case $prev in --head) head=$a ;; --body-file) body=$a ;; --title) title=$a ;; esac
    prev=$a
  done
  printf '%s' "$head" > "$st/pr-head"
  printf '%s' "$title" > "$st/pr-title"
  if [[ -n $body && -f $body ]]; then cp -- "$body" "$st/pr-body.md"; fi
  tip=$(gitr rev-parse --verify --quiet "refs/heads/$head") || tip=''
  printf '%s' "$tip" > "$st/pr-head-sha"
  # decoy-on-create: 꼬리가 같은 남의 ref(refs/heads/x/refs/heads/<브랜치>)를 원격에 만든다 — 정리 확인이 그것을 「남아 있음」으로 보지 않아야 한다(px-38)
  if [[ -f $st/decoy-on-create ]]; then gitr update-ref "refs/heads/x/refs/heads/$head" "$(gitr rev-parse --verify refs/heads/main)"; fi
  case $(opt create ok) in
    ok) ;;
    fail) echo 'pull request create failed: GraphQL: Resource not accessible by integration (createPullRequest)' >&2; exit 1 ;;
    move)
      t=$(gitr rev-parse "$tip^{tree}")
      c=$(GIT_AUTHOR_NAME=intruder GIT_AUTHOR_EMAIL=intruder@example.invalid GIT_COMMITTER_NAME=intruder GIT_COMMITTER_EMAIL=intruder@example.invalid gitr commit-tree "$t" -p "$tip" -m intruder)
      gitr update-ref "refs/heads/$head" "$c" "$tip" ;;
    inject) printf '::warning::injected-gh-create\n' ;;
    badurl) printf 'https://github.com/joshua92y/platform-gitops/pull/7::warning::injected-gh-url\n'; exit 0 ;;
    *) echo 'fake gh: unknown create mode' >&2; exit 4 ;;
  esac
  printf 'https://github.com/joshua92y/platform-gitops/pull/7\n'
}
merge() {
  local a prev='' disable=0
  for a in "$@"; do if [[ $a == --disable-auto ]]; then disable=1; fi; done
  if (( disable )); then
    if [[ $(opt disable ok) != ok ]]; then echo 'could not disable auto-merge' >&2; exit 1; fi
    return 0
  fi
  if [[ $(opt merge ok) != ok ]]; then echo 'GraphQL: Pull request Auto merge is not allowed for this repository' >&2; exit 1; fi
  for a in "$@"; do if [[ $prev == --match-head-commit ]]; then printf '%s' "$a" > "$st/match-head"; fi; prev=$a; done
}
case "${1:-}" in
  api)
    case "${2:-}" in
      users/*) printf '{"login":"%s","id":%s,"type":"Bot"}\n' "$(opt users-login "$bot")" "$(opt users-id 323873425)" ;;
      repos/joshua92y/platform-gitops/pulls/*) poll ;;
      repos/joshua92y/joshuatech_ver2/compare/*) mono_compare ;;
      repos/joshua92y/platform-gitops/compare/*) gitops_compare "$2" ;;
      *) echo 'fake gh: unexpected api path' >&2; exit 3 ;;
    esac ;;
  pr)
    case "${2:-}" in
      create) create "$@" ;;
      merge) merge "$@" ;;
      close)
        # close-term: 닫기를 처리하기 전에 한 번만 부모(bump 스크립트)에 SIGTERM — 실패 갈래의 정리 도중 취소(px-29 (i))
        if [[ -f $st/close-term ]]; then rm -f -- "$st/close-term"; kill -TERM "$PPID"; fi
        case $(opt close ok) in
          ok) ;;
          merged) merged_json merged "$(opt pr-head '')" > /dev/null; echo 'GraphQL: Pull request is already merged (closePullRequest)' >&2; exit 1 ;;
          *) echo 'GraphQL: could not close the pull request' >&2; exit 1 ;;
        esac ;;
      *) echo 'fake gh: unexpected pr subcommand' >&2; exit 3 ;;
    esac ;;
  *) echo 'fake gh: unexpected command' >&2; exit 3 ;;
esac
'@
$fakeDocker = @'
#!/usr/bin/env bash
# 가짜 docker(tests/scripts/publish-pod.tests.ps1 · T074) — 데몬 · 네트워크 없음. 호출을 PUBLISH_POD_FAKE_STATE/docker.log에 남기고 같은
# 디렉터리의 값 파일(os · arch · user · label · env · mediatype)과 rootfs/(export의 tar 원천 · transform 파일이 있으면 GNU tar --transform)로
# 답한다. --format 템플릿에 printf "%q"가 있으면 값을 Go %q 꼴(큰따옴표 · \ " 탭 줄바꿈 이스케이프)로 낸다. inspect --format의 출력 끝에는
# 실제 docker처럼 줄바꿈 하나를 붙인다. *-fail 파일이 있으면 그 명령을 워크플로 명령 글자가 섞인 오류로 실패시킨다(px-33 — 출력 위생).
set -u
st=${PUBLISH_POD_FAKE_STATE:?}
{ printf 'docker'; for a in "$@"; do printf '\t%s' "$a"; done; printf '\n'; } >> "$st/docker.log"
gq() { local s=$1; s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\t'/\\t}; s=${s//$'\n'/\\n}; printf '"%s"' "$s"; }
sub=${1:-}
if (( $# )); then shift; fi
case $sub in
  image) [[ ${1:-} == inspect ]] || { echo 'fake docker: unexpected image subcommand' >&2; exit 3; }; shift ;;
  buildx) [[ ${1:-} == imagetools && ${2:-} == inspect ]] || { echo 'fake docker: unexpected buildx subcommand' >&2; exit 3; }; shift 2; sub=imagetools ;;
esac
fmt=''
pos=()
while (( $# )); do
  case $1 in
    --format) fmt=${2:-}; shift; if (( $# )); then shift; fi ;;
    --format=*) fmt=${1#--format=}; shift ;;
    -f|--force|-q|--quiet) shift ;;
    *) pos+=("$1"); shift ;;
  esac
done
case $sub in
  image)
    if [[ -f $st/inspect-fail ]]; then echo 'Error: No such image ::warning::injected-docker-err' >&2; exit 1; fi
    case $fmt in
      *'.Config.Labels'*) f=label ;;
      *'.Config.Env'*) f=env ;;
      *'.Config.User'*) f=user ;;
      *'.Architecture'*) f=arch ;;
      *'.Os'*) f=os ;;
      *) echo 'fake docker: unknown template' >&2; exit 3 ;;
    esac
    q=0
    if [[ $fmt == *'%q'* ]]; then q=1; fi
    if [[ $f == env ]]; then
      while IFS= read -r line || [[ -n $line ]]; do
        if (( q )); then gq "$line"; else printf '%s' "$line"; fi
        printf '\n'
      done < "$st/env"
    else
      v=''
      if [[ -f $st/$f ]]; then v=$(cat -- "$st/$f"); fi
      if (( q )); then gq "$v"; else printf '%s' "$v"; fi
    fi
    printf '\n' ;;
  imagetools)
    if [[ -f $st/imagetools-fail ]]; then echo 'ERROR: failed to resolve ::warning::injected-docker-err' >&2; exit 1; fi
    cat -- "$st/mediatype"; printf '\n' ;;
  pull)
    if [[ -f $st/pull-fail ]]; then echo 'Error response from daemon: manifest unknown ::warning::injected-docker-err' >&2; exit 1; fi
    printf '%s\n' "${pos[0]:-}" ;;
  create)
    if [[ -f $st/create-fail ]]; then echo 'Error: create failed ::warning::injected-docker-err' >&2; exit 1; fi
    printf 'c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00c0ffee00\n' ;;
  export)
    tf=()
    if [[ -f $st/transform ]]; then tf=(--transform "$(cat -- "$st/transform")"); fi
    cd -- "$st/rootfs" && tar -cf - "${tf[@]}" -- * ;;
  rm) ;;
  *) echo 'fake docker: unexpected command' >&2; exit 3 ;;
esac
'@
$fakeSleep = @'
#!/usr/bin/env bash
# 가짜 sleep(tests/scripts/publish-pod.tests.ps1 · T074) — 기다리지 않고 호출만 남긴다. 시나리오 파일 sleep-term · sleep-int가 있으면 한 번만
# 부모(bump 스크립트 — sleep & wait의 부모)에 SIGTERM · SIGINT를 보낸다(px-29 취소 사례 — 러너는 SIGINT를 먼저 보낸다)
st=${PUBLISH_POD_FAKE_STATE:?}
printf 'sleep\t%s\n' "$*" >> "$st/sleep.log"
if [[ -f $st/sleep-term ]]; then rm -f -- "$st/sleep-term"; kill -TERM "$PPID"; fi
if [[ -f $st/sleep-int ]]; then rm -f -- "$st/sleep-int"; kill -INT "$PPID"; fi
'@
$fakeHead = @'
#!/usr/bin/env bash
# 가짜 head(tests/scripts/publish-pod.tests.ps1 px-29 (vi)) — 시나리오 파일 show-term이 있으면 한 번만 부모(bump 스크립트 — show의 파이프
# 원소를 띄운 셸)에 SIGTERM을 보낸 뒤 실제 head로 넘긴다(stop-commands 구간 안에서 받은 취소). 상태 디렉터리가 없으면 그대로 넘긴다.
st=${PUBLISH_POD_FAKE_STATE:-}
if [[ -n $st && -f $st/show-term ]]; then rm -f -- "$st/show-term"; kill -TERM "$PPID"; fi
exec /usr/bin/head "$@"
'@
$fakeGit = @'
#!/usr/bin/env bash
# 가짜 git 감싸개(tests/scripts/publish-pod.tests.ps1 px-28 · px-29) — 지우기가 아닌 push를 시나리오 git-push대로 다룬다:
#   fail-after  실제로 올린 뒤 실패로 끝남 · fail-before  올리지 않고 실패
#   term-after  실제로 올린 뒤 부모(bump 스크립트)에 SIGTERM을 보내고 성공으로 끝남(push 창의 취소)
#   term-other  원격 브랜치를 남의 커밋(origin/main의 끝)으로 만든 뒤 부모에 SIGTERM을 보내고 실패로 끝남(push 창의 취소 · 원격 끝이 남의 것)
# push마다 git-push.log에 한 줄(지우기면 1)을 남긴다. 그 밖의 호출은 실제 git에 넘긴다.
real=${PUBLISH_POD_REAL_GIT:?}
st=${PUBLISH_POD_FAKE_STATE:?}
if [[ ${1:-} == push ]]; then
  del=0
  last=''
  for a in "$@"; do
    if [[ $a == --delete ]]; then del=1; fi
    last=$a
  done
  printf 'push\t%s\n' "$del" >> "$st/git-push.log"
  if (( ! del )); then
    case $(cat -- "$st/git-push" 2> /dev/null || printf 'ok') in
      fail-after) "$real" "$@" > /dev/null 2>&1; echo 'fatal: the remote end hung up unexpectedly' >&2; exit 128 ;;
      fail-before) echo 'fatal: unable to access the remote: The requested URL returned error: 503' >&2; exit 128 ;;
      term-after)
        "$real" "$@"
        rc=$?
        kill -TERM "$PPID"
        exit "$rc" ;;
      term-other)
        "$real" push --quiet origin "refs/remotes/origin/main:refs/heads/${last#HEAD:refs/heads/}" > /dev/null 2>&1
        kill -TERM "$PPID"
        echo ' ! [rejected]        HEAD -> branch (fetch first)' >&2
        exit 1 ;;
    esac
  fi
fi
exec "$real" "$@"
'@

# 자식 환경에서 지울 이름(사례가 주는 값만 남긴다)
function Test-ScrubName([string]$n) {
    if ($n -match '^(?i)(GITHUB_|RUNNER_|ACTIONS_|GH_|GIT_|PUBLISH_POD_|DOCKER_|BUILDX_)') { return $true }
    foreach ($x in @('POD', 'IMAGE', 'DIGEST', 'APP_SLUG', 'BOT_SLUG', 'BOT_ID', 'GITOPS_DIR', 'IMAGE_REF', 'EXPECT_SHA', 'ASSERT_MODE', 'TMPDIR', 'IMG', 'CI', 'MONOREPO_TOKEN', 'MSYS_NO_PATHCONV', 'MSYS2_ARG_CONV_EXCL', 'MSYS2_ENV_CONV_EXCL')) {
        if ([string]::Equals($n, $x, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}
# 스크립트를 bash로 실행한다(자식 환경만 바꾼다 — ProcessStartInfo). 스크립트가 없으면 실행하지 않고 code 127 · missing.
$script:runCount = 0
function Invoke-Script([string]$path, [string]$cwd, [hashtable]$envSet, [string[]]$pathPrefix) {
    $r = @{ code = -1; out = ''; err = ''; lines = [string[]]@(); missing = $false }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $r.code = 127; $r.out = '<missing script>'; $r.lines = [string[]]@('<missing script>'); $r.missing = $true; return $r }
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $script:bash
    $psi.ArgumentList.Add((ConvertTo-Fwd $path))
    $psi.WorkingDirectory = $cwd
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $enc = [Text.UTF8Encoding]::new($false)
    $psi.StandardOutputEncoding = $enc; $psi.StandardErrorEncoding = $enc
    foreach ($k in @($psi.Environment.Keys)) { if (Test-ScrubName $k) { [void]$psi.Environment.Remove($k) } }
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($p in $pathPrefix) { if ($p) { $parts.Add($p) } }
    if ($script:bashDir) { $parts.Add($script:bashDir) }
    $parts.Add($script:basePath)
    $psi.Environment['PATH'] = $parts -join [IO.Path]::PathSeparator
    foreach ($k in $script:gitIso.Keys) { $psi.Environment[$k] = $script:gitIso[$k] }
    foreach ($k in $envSet.Keys) { $v = [string]$envSet[$k]; if ($v.Length -eq 0) { [void]$psi.Environment.Remove($k) } else { $psi.Environment[$k] = $v } }
    $p = [Diagnostics.Process]::new(); $p.StartInfo = $psi
    [void]$p.Start()
    $p.StandardInput.Close()
    $ot = $p.StandardOutput.ReadToEndAsync(); $et = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit(600000)) { try { $p.Kill($true) } catch { }; $r.code = -2; $r.err = '<harness timeout 600 s>'; return $r }
    $p.WaitForExit()
    $r.code = $p.ExitCode
    $r.out = ($ot.Result -replace "`r`n", "`n").TrimEnd("`n")
    $r.err = ($et.Result -replace "`r`n", "`n").TrimEnd("`n")
    $r.lines = if ($r.out.Length -gt 0) { [string[]]($r.out -split "`n") } else { [string[]]@() }
    $script:runCount++
    return $r
}
function Format-Run($r) { "code=$($r.code) out=[$(Cut $r.out)] err=[$(Cut $r.err 600)]" }
# 가짜 호출 기록 — 줄마다 탭으로 나눈 인자 배열(첫 칸 = 명령 이름 · gh는 gh:<토큰 표지>)
function Read-CallLog([string]$p) {
    $t = Read-TextOrEmpty $p
    if ($t.Length -eq 0) { return , @() }
    return , @(foreach ($l in ($t.TrimEnd("`n") -split "`n")) { , ([string[]]($l -split "`t")) })
}
function Format-Calls($calls) { (@($calls | ForEach-Object { ($_ | Select-Object -Skip 1) -join ' ' }) -join ' / ') }
# stop-commands 구간 밖의 줄 — '::stop-commands::<토큰>'(토큰 [A-Za-z0-9-] 16자 이상)부터 '::<토큰>::'까지가 구간이다. 꼴이 틀린 여는 줄 ·
# 닫히지 않은 구간은 ok = $false.
function Get-Outside([string[]]$lines) {
    $out = [Collections.Generic.List[string]]::new(); $tok = $null; $ok = $true; $n = 0
    foreach ($l in $lines) {
        if ($null -eq $tok) {
            $m = [regex]::Match($l, '^::stop-commands::([A-Za-z0-9-]{16,})$')
            if ($m.Success) { $tok = $m.Groups[1].Value; $n++; continue }
            if ($l.StartsWith('::stop-commands::', [StringComparison]::Ordinal)) { $ok = $false }
            $out.Add($l)
        } elseif (Test-Same $l "::${tok}::") { $tok = $null }
    }
    if ($null -ne $tok) { $ok = $false }
    return @{ outside = [string[]]$out.ToArray(); ok = $ok; regions = $n }
}
function Test-Clean($r, [string]$marker) {
    $g = Get-Outside $r.lines
    return $g.ok -and @($g.outside | Where-Object { Test-Has $_ $marker }).Count -eq 0 -and -not (Test-Has $r.err $marker)
}

$script:root = $null
$script:asRuns = [Collections.Generic.List[object]]::new()
$script:bsRuns = [Collections.Generic.List[object]]::new()
$savedGitEnv = @{}
$gitEnvNames = @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_COMMON_DIR', 'GIT_NAMESPACE')
foreach ($n in $gitEnvNames) { $savedGitEnv[$n] = [Environment]::GetEnvironmentVariable($n) }
$script:basePath = $env:PATH
$script:caseNo = 0
function New-CaseDir([string]$prefix) { $script:caseNo++; $d = Join-Path $script:root ("$prefix-$($script:caseNo)"); New-Dir $d; return $d }

try {
    if ($asMissing.Count -eq 0) {
        $script:root = Join-Path ([IO.Path]::GetTempPath()) ('ppod-' + [guid]::NewGuid().ToString('N'))
        New-Dir $script:root
        $script:temps.Add($script:root)
        $script:rootPosix = if ($IsWindows) { ((& $script:cygpath -u $script:root) | Select-Object -First 1) } else { $script:root }
        $script:fakeBin = Join-Path $script:root 'fakebin'
        $script:gitShimBin = Join-Path $script:root 'fakebin-git'
        foreach ($pair in @(@($script:fakeBin, 'gh', $fakeGh), @($script:fakeBin, 'docker', $fakeDocker), @($script:fakeBin, 'sleep', $fakeSleep), @($script:fakeBin, 'head', $fakeHead), @($script:gitShimBin, 'git', $fakeGit))) {
            $p = Join-Path $pair[0] $pair[1]
            Write-Text $p (($pair[2] -replace "`r`n", "`n").TrimEnd("`n") + "`n")
            Set-Exec $p
        }
        # git을 사용자 설정과 떼어 놓는다(이 프로세스의 픽스처 git과 자식 둘 다)
        $emptyCfg = Join-Path $script:root 'gitconfig-empty'
        Write-Text $emptyCfg ''
        foreach ($n in $gitEnvNames) { Set-EnvVar $n $null }
        Set-EnvVar 'GIT_CONFIG_NOSYSTEM' '1'
        Set-EnvVar 'GIT_CONFIG_GLOBAL' $emptyCfg
        $script:gitIso = @{ GIT_CONFIG_NOSYSTEM = '1'; GIT_CONFIG_GLOBAL = (ConvertTo-Fwd $emptyCfg) }
        if ($script:gitCmd) {
            $script:fixtureGit = Resolve-FixtureGit
            # git 감싸개가 넘길 실제 git(절대 경로 — 감싸개 자신을 다시 부르지 않게)
            $script:realGitForBash = if ([IO.Path]::IsPathRooted($script:fixtureGit)) { ConvertTo-Fwd $script:fixtureGit } else { ConvertTo-Fwd $script:gitCmd.Source }
        }
        if ($script:yqInfo) {
            $yqp = (ConvertTo-Fwd $script:yqInfo.p).Replace("'", "'\''")
            $script:yqWrapper = "#!/usr/bin/env bash`n# 하네스의 yq 감싸개 — `$RUNNER_TEMP/bin/yq(bump 스크립트의 command -v yq 대조)`nexec '$yqp' `"`$@`"`n"
        }
    }
    $script:fakeToken = 'ghs_FAKE' + [guid]::NewGuid().ToString('N')
    $script:fakeMonoToken = 'ghs_FAKEMONO' + [guid]::NewGuid().ToString('N')

    # ==================== assert-image(px-1–px-6 · px-32–px-34 → 집계 px-7) ====================
    $asSha = '0123456789abcdef0123456789abcdef01234567'
    $asLocalRef = "$($K.Image):sha-$asSha"
    $asRegRef = "$($K.Image)@sha256:" + ('ab' * 32)
    $asEnvGood = @('PATH=/src/apps/identity-admin/.venv/bin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin', 'PYTHONDONTWRITEBYTECODE=1', 'PYTHONUNBUFFERED=1', 'DJANGO_SETTINGS_MODULE=identity_admin.settings', "APP_VERSION=sha-$asSha", "APP_GIT_SHA=$asSha")
    function New-AsCase([hashtable]$o) {
        $d = New-CaseDir 'as'
        $st = Join-Path $d 'state'; New-Dir $st
        $vals = [ordered]@{ os = 'linux'; arch = 'arm64'; user = '10001:10001'; label = $asSha; mediatype = 'application/vnd.oci.image.manifest.v1+json' }
        foreach ($k in @($vals.Keys)) { if ($o.ContainsKey($k)) { $vals[$k] = $o[$k] } }
        foreach ($k in $vals.Keys) { if ($null -ne $vals[$k]) { Write-Text (Join-Path $st $k) ([string]$vals[$k]) } }
        $envLines = if ($o.ContainsKey('env')) { $o.env } else { $asEnvGood }
        Write-Text (Join-Path $st 'env') (($envLines -join "`n") + "`n")
        $files = [ordered]@{
            'etc/passwd' = "root:x:0:0:root:/root:/bin/sh`n"
            'usr/bin/python3' = "#!fake`n"
            'src/apps/identity-admin/.venv/bin/python' = "#!fake`n"
            'src/apps/identity-admin/identity_admin/__init__.py' = "`n"
            'src/apps/identity-admin/manage.py' = "# manage`n"
            'src/apps/identity-admin/pyproject.toml' = "[project]`n"
            'src/apps/identity-admin/uv.lock' = "version = 1`n"
        }
        if ($o.ContainsKey('extra')) { foreach ($k in $o.extra.Keys) { $files[$k] = $o.extra[$k] } }
        foreach ($k in $files.Keys) { Write-Text (Join-Path (Join-Path $st 'rootfs') $k) $files[$k] }
        if ($o.ContainsKey('transform')) { Write-Text (Join-Path $st 'transform') $o.transform }
        foreach ($f in @($o.flags)) { if ($f) { Write-Text (Join-Path $st $f) '' } }
        $rt = Join-Path $d 'rt'; New-Dir $rt
        $tmp = Join-Path $d 'tmp'; New-Dir $tmp
        return @{ dir = $d; state = $st; rt = $rt; tmp = $tmp; summary = (Join-Path $d 'summary.md') }
    }
    function Invoke-As($c, [string]$mode, [string]$ref, [hashtable]$over) {
        $envSet = @{
            IMAGE_REF = $ref; EXPECT_SHA = $asSha; ASSERT_MODE = $mode
            RUNNER_TEMP = (ConvertTo-Posix $c.rt); TMPDIR = (ConvertTo-Posix $c.tmp)
            GITHUB_STEP_SUMMARY = (ConvertTo-Fwd $c.summary); PUBLISH_POD_FAKE_STATE = (ConvertTo-Fwd $c.state)
        }
        if ($null -ne $over) { foreach ($k in $over.Keys) { $envSet[$k] = $over[$k] } }
        $r = Invoke-Script $asPath $c.dir $envSet @($script:fakeBin)
        $r.calls = Read-CallLog (Join-Path $c.state 'docker.log')
        $r.summary = Read-TextOrEmpty $c.summary
        $r.left = [string[]]@(Get-ChildItem -LiteralPath $c.rt -Force | ForEach-Object { $_.Name })
        $script:asRuns.Add($r)
        return $r
    }
    # 이미지 단언이 실패로 끝났고(exit 1) 그 까닭 코드가 찍혔으며, 실제로 돌았다(요약 시간 줄 · exit 1)
    function Test-AsFail($r, [string]$code) {
        return -not $r.missing -and $r.code -eq 1 -and (Test-Has $r.out "[$code]") -and $r.summary -match '(?m)^- \*\*이미지 단언(\((local|registry)\))?\*\* · 시작 \S+ · 종료 \S+ · \d+초 · exit 1$'
    }
    function Get-Verbs($r) { return [string[]]@($r.calls | ForEach-Object { $_[1] }) }

    Test-Group 'px-1' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-1' "not found: $($asMissing -join ', ')"; return }
        $c = New-AsCase @{}
        $r = Invoke-As $c 'local' $asLocalRef
        $verbs = @(Get-Verbs $r)
        $inspects = @($r.calls | Where-Object { $_[1] -eq 'image' })
        $refOk = $inspects.Count -ge 5 -and @($inspects | Where-Object { -not (Test-Same $_[-1] $asLocalRef) }).Count -eq 0
        $rm = @($r.calls | Where-Object { $_[1] -eq 'rm' -and (Test-Same $_[-1] ('c0ffee00' * 8)) }).Count
        Assert 'px-1: assert-image local on a good image (fake docker) -> exit 0 with the pass result line, every inspect uses the given ref, no pull / imagetools, the created container is removed, one summary line with exit 0, no temp leftovers' (
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '결과: 통과') -and $refOk -and -not ($verbs -contains 'pull') -and -not ($verbs -contains 'buildx') -and
            ($verbs -contains 'create') -and ($verbs -contains 'export') -and $rm -eq 1 -and
            ([regex]::Matches($r.summary, '(?m)^- \*\*이미지 단언\(local\)\*\* · 시작 \S+ · 종료 \S+ · \d+초 · exit 0$').Count -eq 1) -and $r.left.Count -eq 0
        ) "$(Format-Run $r); calls: [$(Format-Calls $r.calls)]; summary: [$($r.summary)]; leftovers: [$($r.left -join ', ')]"
    }
    Test-Group 'px-2' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-2' "not found: $($asMissing -join ', ')"; return }
        $r = Invoke-As (New-AsCase @{ label = '0000000' }) 'local' $asLocalRef
        Assert 'px-2: revision label 0000000 (the Dockerfile default - build-arg missing) -> exit 1 [label]' (Test-AsFail $r 'label') (Format-Run $r)
    }
    Test-Group 'px-3' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-3' "not found: $($asMissing -join ', ')"; return }
        $a = Invoke-As (New-AsCase @{ env = @($asEnvGood | Where-Object { -not $_.StartsWith('APP_GIT_SHA=') }) }) 'local' $asLocalRef
        $b = Invoke-As (New-AsCase @{ env = @($asEnvGood + @("APP_VERSION=sha-$asSha")) }) 'local' $asLocalRef
        Assert 'px-3: Env without APP_GIT_SHA (label still right) and Env with APP_VERSION twice -> each exit 1 [env]' (
            (Test-AsFail $a 'env') -and (Test-AsFail $b 'env')
        ) "no APP_GIT_SHA: $(Format-Run $a) | APP_VERSION twice: $(Format-Run $b)"
    }
    Test-Group 'px-4' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-4' "not found: $($asMissing -join ', ')"; return }
        $a = Invoke-As (New-AsCase @{ arch = 'amd64' }) 'local' $asLocalRef
        $b = Invoke-As (New-AsCase @{ user = '0' }) 'local' $asLocalRef
        Assert 'px-4: linux/amd64 and User 0 -> each exit 1 ([platform] / [user])' ((Test-AsFail $a 'platform') -and (Test-AsFail $b 'user')) "amd64: $(Format-Run $a) | user 0: $(Format-Run $b)"
    }
    Test-Group 'px-5' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-5' "not found: $($asMissing -join ', ')"; return }
        $a = Invoke-As (New-AsCase @{ extra = @{ 'src/apps/identity-admin/.env' = "SECRET=x`n" } }) 'local' $asLocalRef
        $b = Invoke-As (New-AsCase @{ extra = @{ 'src/packages/django-common/pyproject.toml' = "[project]`n" } }) 'local' $asLocalRef
        Assert 'px-5: an extra .env under /src/apps/identity-admin and an extra /src/packages -> each exit 1 [tree]' ((Test-AsFail $a 'tree') -and (Test-AsFail $b 'tree')) ".env: $(Format-Run $a) | src/packages: $(Format-Run $b)"
    }
    Test-Group 'px-6' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-6' "not found: $($asMissing -join ', ')"; return }
        $idx = Invoke-As (New-AsCase @{ mediatype = 'application/vnd.oci.image.index.v1+json' }) 'registry' $asRegRef
        $lst = Invoke-As (New-AsCase @{ mediatype = 'application/vnd.docker.distribution.manifest.list.v2+json' }) 'registry' $asRegRef
        $oci = Invoke-As (New-AsCase @{}) 'registry' $asRegRef
        $d2 = Invoke-As (New-AsCase @{ mediatype = 'application/vnd.docker.distribution.manifest.v2+json' }) 'registry' $asRegRef
        $noPull = { param($r) $v = @(Get-Verbs $r); -not ($v -contains 'pull') -and -not ($v -contains 'image') }
        $okRun = { param($r)
            $v = [string[]]@(Get-Verbs $r)
            $iPull = [Array]::IndexOf($v, 'pull'); $iImg = [Array]::IndexOf($v, 'image'); $iBx = [Array]::IndexOf($v, 'buildx')
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '결과: 통과') -and $iBx -ge 0 -and $iPull -gt $iBx -and $iImg -gt $iPull -and
            @($r.calls | Where-Object { $_[1] -in @('pull', 'image', 'buildx') -and -not (Test-Same $_[$(if ($_[1] -eq 'buildx') { 4 } else { -1 })] $asRegRef) }).Count -eq 0
        }
        Assert 'px-6: registry mode - an index or a manifest list -> exit 1 [mediatype] before any pull; a single OCI or Docker v2 manifest -> imagetools, then pull by digest, then the same assertions -> exit 0' (
            (Test-AsFail $idx 'mediatype') -and (& $noPull $idx) -and (Test-AsFail $lst 'mediatype') -and (& $noPull $lst) -and (& $okRun $oci) -and (& $okRun $d2)
        ) "index: $(Format-Run $idx) [$(Format-Calls $idx.calls)] | list: $(Format-Run $lst) | oci: $(Format-Run $oci) [$(Format-Calls $oci.calls)] | docker v2: $(Format-Run $d2)"
    }
    Test-Group 'px-32' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-32' "not found: $($asMissing -join ', ')"; return }
        $r = Invoke-As (New-AsCase @{ extra = @{ 'src/apps/other/x' = "x`n" } }) 'local' $asLocalRef
        Assert 'px-32: a second directory under /src/apps (/src/apps/other/x) -> exit 1 [tree] (the /src/apps = {identity-admin} check)' ((Test-AsFail $r 'tree') -and $r.err.Length -eq 0) (Format-Run $r)
    }
    Test-Group 'px-33' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-33' "not found: $($asMissing -join ', ')"; return }
        $mk = '::warning::injected-docker-err'
        $res = [ordered]@{}
        foreach ($cs in @(@('inspect-fail', 'local', $asLocalRef, 'inspect'), @('imagetools-fail', 'registry', $asRegRef, 'mediatype'), @('pull-fail', 'registry', $asRegRef, 'pull'), @('create-fail', 'local', $asLocalRef, 'export'))) {
            $r = Invoke-As (New-AsCase @{ flags = @($cs[0]) }) $cs[1] $cs[2]
            $res[$cs[0]] = @{ r = $r; ok = (Test-AsFail $r $cs[3]) -and (Test-Clean $r $mk) -and (Test-Has $r.out 'injected-docker-err') -and $r.err.Length -eq 0 }
        }
        $bad = @($res.Keys | Where-Object { -not $res[$_].ok })
        Assert 'px-33: fake docker failures - inspect / imagetools / pull / create -> each exit 1 with its reason code ([inspect] / [mediatype] / [pull] / [export]); the docker error text (carrying ::warning::) is printed only inside a stop-commands region and stderr stays empty' (
            $bad.Count -eq 0
        ) ("failing: [$($bad -join ', ')]; " + (@($bad | ForEach-Object { "${_}: $(Format-Run $res[$_].r)" }) -join ' | '))
    }
    Test-Group 'px-34' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-34' "not found: $($asMissing -join ', ')"; return }
        $a = Invoke-As (New-AsCase @{}) 'bogus' $asLocalRef
        $b = Invoke-As (New-AsCase @{}) 'local' $asLocalRef @{ EXPECT_SHA = 'not-a-sha' }
        $cc = Invoke-As (New-AsCase @{}) 'registry' $asLocalRef
        $noDocker = @($a, $b, $cc | Where-Object { $_.calls.Count -gt 0 })
        Assert 'px-34: usage errors - ASSERT_MODE bogus, EXPECT_SHA not 40-hex, registry mode with a tag ref -> each exit 1 [usage] before any docker call' (
            (Test-AsFail $a 'usage') -and (Test-AsFail $b 'usage') -and (Test-AsFail $cc 'usage') -and $noDocker.Count -eq 0
        ) "mode: $(Format-Run $a) | sha: $(Format-Run $b) | ref: $(Format-Run $cc) | runs with docker calls: $($noDocker.Count)"
    }
    Test-Group 'px-7' {
        if ($asMissing.Count -gt 0) { Skip-Assert 'px-7' "not found: $($asMissing -join ', ')"; return }
        $mk = '::warning::injected'
        $a = Invoke-As (New-AsCase @{ label = '::warning::injected-label' }) 'local' $asLocalRef
        $b = Invoke-As (New-AsCase @{ env = @(@($asEnvGood | Where-Object { -not $_.StartsWith('APP_GIT_SHA=') }) + @('APP_GIT_SHA=::warning::injected-env')) }) 'local' $asLocalRef
        $cc = Invoke-As (New-AsCase @{ extra = @{ 'src/apps/identity-admin/WARNFILE' = "x`n" }; transform = 's,WARNFILE,::warning::injected-tar,' }) 'local' $asLocalRef
        $shown = (Test-Has $a.out 'injected-label') -and (Test-Has $b.out 'injected-env') -and (Test-Has $cc.out 'injected-tar')
        $all = @($script:asRuns)
        $dirty = @($all | Where-Object { $_.missing -or $_.err.Length -gt 0 -or $_.left.Count -gt 0 -or -not (Get-Outside $_.lines).ok })
        Assert 'px-7: label / Env / tar name carrying "::warning::..." -> each exit 1 ([label] / [env] / [tree]) and the text is printed only inside a stop-commands region; every assert-image run (all px-1-px-6 · px-32-px-34 runs too) has empty stderr, well-formed regions and no temp leftovers' (
            (Test-AsFail $a 'label') -and (Test-AsFail $b 'env') -and (Test-AsFail $cc 'tree') -and (Test-Clean $a $mk) -and (Test-Clean $b $mk) -and (Test-Clean $cc $mk) -and $shown -and
            (-not $script:full -or $all.Count -ge 22) -and $dirty.Count -eq 0
        ) "label: $(Format-Run $a) | env: $(Format-Run $b) | tar: $(Format-Run $cc) | shown in a region: $shown | runs: $($all.Count), with stderr / leftovers / bad regions: $($dirty.Count)"
    }

    # ==================== bump(px-8–px-20 · px-24–px-38 → 집계 px-21 · px-22 · px-27) ====================
    $bsSha = 'abcdef0123456789abcdef0123456789abcdef01'
    $zeros = '0' * 64
    $newHex = 'ab' * 32
    $bsDigest = "sha256:$newHex"
    $devRel = 'apps/identity-admin/overlays/dev/kustomization.yaml'
    $branchName = "bump/dev-identity-admin-$($bsSha.Substring(0, 7))"
    $subject = "chore(identity-admin): dev → $($newHex.Substring(0, 12))"
    $botIdent = "$($K.BotSlug)[bot] <$($K.BotId)+$($K.BotSlug)[bot]@users.noreply.github.com>"
    $monoCompare = "repos/joshua92y/joshuatech_ver2/compare/$bsSha...refs/heads/main"
    $devHead = "# apps/identity-admin/overlays/dev/ — 시험 픽스처(가짜 platform-gitops)`napiVersion: kustomize.config.k8s.io/v1beta1`nkind: Kustomization`nresources: []`n"
    function Get-DevSeed([string]$hex) { return $devHead + "# 자리 값 — 시험 픽스처`nimages:`n  - name: ghcr.io/joshua92y/identity-admin`n    newName: ghcr.io/joshua92y/identity-admin`n    digest: sha256:$hex`n" }
    $prodSkeleton = "apiVersion: kustomize.config.k8s.io/v1beta1`nkind: Kustomization`nresources: []`n"
    function Set-RepoFiles([string]$dir, [hashtable]$files) { foreach ($rel in $files.Keys) { Write-Text (Join-Path $dir $rel) ([string]$files[$rel]) } }
    function Get-Refs([string]$gitDir) { return (Invoke-Git $gitDir @('for-each-ref', '--format=%(refname) %(objectname)')) }
    function New-BsCase([hashtable]$o) {
        $d = New-CaseDir 'bs'
        $dev = if ($o.ContainsKey('dev')) { $o.dev } else { Get-DevSeed $zeros }
        $seed = Join-Path $d 'seed'; New-Dir $seed
        [void](Invoke-Git $seed @('init', '-q', '-b', 'main'))
        foreach ($kv in @(@('user.name', 'fixture'), @('user.email', 'fixture@example.invalid'), @('core.autocrlf', 'false'), @('commit.gpgsign', 'false'))) { [void](Invoke-Git $seed @('config', $kv[0], $kv[1])) }
        Set-RepoFiles $seed @{ 'README.md' = "platform-gitops fixture`n"; $devRel = $dev; 'apps/identity-admin/overlays/prod/kustomization.yaml' = $prodSkeleton }
        [void](Invoke-Git $seed @('add', '-A')); [void](Invoke-Git $seed @('commit', '-q', '-m', 'one'))
        Set-RepoFiles $seed @{ 'README.md' = "platform-gitops fixture 2`n" }
        [void](Invoke-Git $seed @('add', '-A')); [void](Invoke-Git $seed @('commit', '-q', '-m', 'two'))
        $main = Invoke-Git $seed @('rev-parse', 'HEAD')
        $remote = Join-Path $d 'remote.git'
        [void](Invoke-Git $d @('init', '-q', '--bare', '-b', 'main', 'remote.git'))
        [void](Invoke-Git $remote @('config', 'uploadpack.allowAnySHA1InWant', 'true'))
        [void](Invoke-Git $seed @('push', '-q', (ConvertTo-Fwd $remote), 'main'))
        if ($o.preBranch) { [void](Invoke-Git $remote @('update-ref', "refs/heads/$branchName", $main)) }
        # 꼬리가 같은 남의 ref — git ls-remote origin refs/heads/<b>는 꼬리 일치라 이것도 돌려준다(px-38 · 라운드 2 F17)
        if ($o.decoyRef) { [void](Invoke-Git $remote @('update-ref', "refs/heads/x/refs/heads/$branchName", $main)) }
        $ws = Join-Path $d 'ws'; New-Dir $ws
        [void](Invoke-Git $ws @('clone', '-q', '--depth', '1', '--branch', 'main', '--single-branch', ('file:///' + (ConvertTo-Fwd $remote)), 'gitops'))
        $gitops = Join-Path $ws 'gitops'
        [void](Invoke-Git $gitops @('config', 'core.autocrlf', 'false'))
        if ($o.dirty) { Set-RepoFiles $gitops @{ 'README.md' = "dirty`n" } }
        $st = Join-Path $d 'state'; New-Dir $st
        $polls = if ($o.ContainsKey('polls')) { $o.polls } else { @('open', 'merged') }
        Write-Text (Join-Path $st 'polls') (($polls -join "`n") + "`n")
        foreach ($k in @('create', 'merge', 'close', 'disable', 'users-id', 'users-login', 'compare', 'main-compare', 'git-push')) { if ($o.ContainsKey($k)) { Write-Text (Join-Path $st $k) ([string]$o[$k]) } }
        if ($o.inject) { Write-Text (Join-Path $st 'gh-stderr') "::warning::injected-gh-stderr`n"; Write-Text (Join-Path $st 'inject-state') '' }
        if ($o.sleepTerm) { Write-Text (Join-Path $st 'sleep-term') '' }
        if ($o.sleepInt) { Write-Text (Join-Path $st 'sleep-int') '' }
        if ($o.closeTerm) { Write-Text (Join-Path $st 'close-term') '' }
        if ($o.compareTerm) { Write-Text (Join-Path $st 'compare-term') '' }
        if ($o.showTerm) { Write-Text (Join-Path $st 'show-term') '' }
        if ($o.decoyOnCreate) { Write-Text (Join-Path $st 'decoy-on-create') '' }
        $rt = Join-Path $d 'rt'; $rtBin = Join-Path $rt 'bin'; New-Dir $rtBin
        Write-Text (Join-Path $rtBin 'yq') $script:yqWrapper; Set-Exec (Join-Path $rtBin 'yq')
        $tmp = Join-Path $d 'tmp'; New-Dir $tmp
        return @{ dir = $d; remote = $remote; main = $main; ws = $ws; gitops = $gitops; state = $st; rt = $rt; rtBin = $rtBin; tmp = $tmp; summary = (Join-Path $d 'summary.md'); refsBefore = (Get-Refs $remote); gitShim = [bool]$o.gitShim }
    }
    function Invoke-Bs($c, [hashtable]$over) {
        $envSet = @{
            GITHUB_REF = 'refs/heads/main'; GITHUB_SHA = $bsSha; GITHUB_REPOSITORY = 'joshua92y/joshuatech_ver2'; GITHUB_RUN_ID = '123456789'; GITHUB_SERVER_URL = 'https://github.com'
            GITHUB_STEP_SUMMARY = (ConvertTo-Fwd $c.summary); RUNNER_TEMP = (ConvertTo-Posix $c.rt); TMPDIR = (ConvertTo-Posix $c.tmp)
            POD = $K.Pod; IMAGE = $K.Image; DIGEST = $bsDigest; APP_SLUG = $K.BotSlug; BOT_SLUG = $K.BotSlug; BOT_ID = $K.BotId; GITOPS_DIR = 'gitops'
            GH_TOKEN = $script:fakeToken; MONOREPO_TOKEN = $script:fakeMonoToken
            PUBLISH_POD_FAKE_STATE = (ConvertTo-Fwd $c.state); PUBLISH_POD_FAKE_REMOTE = (ConvertTo-Fwd $c.remote); PUBLISH_POD_FAKE_DEV = $devRel
            PUBLISH_POD_FAKE_APP_TOKEN = $script:fakeToken; PUBLISH_POD_FAKE_MONO_TOKEN = $script:fakeMonoToken; PUBLISH_POD_REAL_GIT = $script:realGitForBash
        }
        if ($null -ne $over) { foreach ($k in $over.Keys) { $envSet[$k] = $over[$k] } }
        $prefix = if ($c.gitShim) { @($script:gitShimBin, $script:fakeBin, $c.rtBin) } else { @($script:fakeBin, $c.rtBin) }
        $r = Invoke-Script $bsPath $c.ws $envSet $prefix
        $r.calls = Read-CallLog (Join-Path $c.state 'gh.log')
        $r.sleeps = (Read-CallLog (Join-Path $c.state 'sleep.log')).Count
        $r.pushes = Read-CallLog (Join-Path $c.state 'git-push.log')
        $r.ghEnv = [string[]]@((Read-TextOrEmpty (Join-Path $c.state 'gh-env.log')).Split("`n", [StringSplitOptions]::RemoveEmptyEntries))
        $r.summary = Read-TextOrEmpty $c.summary
        $r.refsAfter = Get-Refs $c.remote
        $r.left = [string[]]@(Get-ChildItem -LiteralPath $c.rt -Force | Where-Object { $_.Name -ne 'bin' } | ForEach-Object { $_.Name })
        $r.ctx = $c
        $script:bsRuns.Add($r)
        return $r
    }
    function Get-GhVerbs($r) { return [string[]]@($r.calls | ForEach-Object { if ($_.Count -ge 3) { "$($_[1]) $($_[2])" } else { $_[1] } }) }
    function Test-BsFail($r, [string]$code) {
        return -not $r.missing -and $r.code -eq 1 -and (Test-Has $r.out "[$code]") -and $r.summary -match '(?m)^- \*\*dev bump\*\* · 시작 \S+ · 종료 \S+ · \d+초 · exit 1$'
    }
    function Test-NoGhPr($r) { return @($r.calls | Where-Object { $_[1] -eq 'pr' }).Count -eq 0 }
    # gh 호출이 낡은 실행 가드의 모노레포 compare 한 번뿐이다(②에서 멈춘 사례)
    function Test-OnlyMonoCompare($r) { $cs = @($r.calls); return $cs.Count -eq 1 -and $cs[0][1] -eq 'api' -and (Test-Same $cs[0][2] $monoCompare) }
    # ref 이름이 정확히 refs/heads/<브랜치>인 줄만 본다(꼬리가 같은 남의 ref — px-38 — 와 가른다)
    function Test-RemoteBranchGone($r) { return -not ($r.refsAfter -cmatch ('(?m)^' + [regex]::Escape("refs/heads/$branchName") + ' ')) }
    # 실패 뒤 정리(gh pr close · 브랜치 삭제 · ls-remote 확인)가 돌았다
    function Test-Cleaned($r, [bool]$withPr) {
        $close = @($r.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'close' }).Count
        return (Test-RemoteBranchGone $r) -and ($r.summary -match '(?m)^- \*\*정리\*\* ') -and (Test-Has $r.summary '원격에 없음') -and ($(if ($withPr) { $close -eq 1 } else { $close -eq 0 }))
    }

    Test-Group 'px-8' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-8' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{}
        $r = Invoke-Bs $c @{}
        $why = [Collections.Generic.List[string]]::new()
        $msha = Read-TextOrEmpty (Join-Path $c.state 'merge-sha')
        $verbs = [string[]]@(Get-GhVerbs $r)
        $wantVerbs = @("api $monoCompare", 'api users/joshuatech-gitapp-1[bot]', 'pr create', 'pr merge', 'api repos/joshua92y/platform-gitops/pulls/7', 'api repos/joshua92y/platform-gitops/pulls/7', "api repos/joshua92y/platform-gitops/compare/$msha...refs/heads/main")
        if (-not (Test-SameList $verbs $wantVerbs)) { $why.Add("gh calls [$($verbs -join ', ')]") }
        $commit = Read-TextOrEmpty (Join-Path $c.state 'pr-head-sha')
        $create = @($r.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'create' })
        $cArgs = if ($create.Count -eq 1) { [string[]]($create[0] | Select-Object -Skip 3) } else { [string[]]@() }
        $wantCreate = @('--repo', $K.GitopsRepo, '--base', 'main', '--head', $branchName, '--title', $subject, '--body-file')
        if ($cArgs.Count -ne 10 -or -not (Test-SameList ([string[]]$cArgs[0..8]) $wantCreate)) { $why.Add("pr create args [$($cArgs -join ' ')]") }
        $merge = @($r.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'merge' })
        $mArgs = if ($merge.Count -eq 1) { [string[]]($merge[0] | Select-Object -Skip 3) } else { [string[]]@() }
        if (-not (Test-SameList $mArgs @('7', '--repo', $K.GitopsRepo, '--auto', '--squash', '--match-head-commit', $commit))) { $why.Add("pr merge args [$($mArgs -join ' ')]") }
        if ($commit -notmatch '^[0-9a-f]{40}$') { $why.Add("bump commit [$commit]") }
        else {
            $info = (Invoke-Git $c.remote @('log', '-1', '--format=%an <%ae>%n%cn <%ce>%n%P%n%s', $commit)) -split "`n"
            if (-not ((Test-Same $info[0] $botIdent) -and (Test-Same $info[1] $botIdent))) { $why.Add("identity [$($info[0]) / $($info[1])]") }
            if (-not (Test-Same $info[2] $c.main)) { $why.Add("parent [$($info[2])] != main [$($c.main)]") }
            if (-not (Test-Same $info[3] $subject)) { $why.Add("subject [$($info[3])]") }
            $files = Invoke-Git $c.remote @('diff-tree', '--no-commit-id', '--name-only', '-r', $commit)
            if (-not (Test-Same $files $devRel)) { $why.Add("files [$files]") }
            $ns = Invoke-Git $c.remote @('diff', '--numstat', $c.main, $commit)
            if (-not (Test-Same $ns "1`t1`t$devRel")) { $why.Add("numstat [$ns]") }
            $want = Join-Path $c.dir 'want-dev.yaml'
            Write-Text $want (Get-DevSeed $newHex)
            if (-not (Test-Same (Invoke-Git $c.remote @('rev-parse', "${commit}:$devRel")) (Invoke-Git $c.dir @('hash-object', '--no-filters', '--', $want)))) { $why.Add('dev file at the bump commit is not the seed with only the hex replaced') }
        }
        if (-not (Test-Has $r.refsAfter "refs/heads/main $msha") -or $msha.Length -ne 40) { $why.Add('remote main is not the squash commit') }
        if (-not (Test-RemoteBranchGone $r)) { $why.Add('bump branch still on the remote') }
        if ($r.sleeps -ne 1) { $why.Add("sleeps $($r.sleeps)") }
        foreach ($n in @('enabled_by `joshuatech-gitapp-1[bot]`', 'merge_method `squash`', '**머지 확인**', $msha, '대조 통과', "머지 때 head: 이 실행의 커밋 ``$commit``", 'gitops main에 있다 — compare identical')) { if (-not (Test-Has $r.summary $n)) { $why.Add("summary lacks [$n]") } }
        if ($r.summary -notmatch '(?m)^- \*\*dev bump\*\* · 시작 \S+ · 종료 \S+ · \d+초 · exit 0$') { $why.Add('summary time line') }
        if (-not (Test-Has $r.out '낡음 가드: 모노레포 main = 원천 커밋(identical)')) { $why.Add('stale guard line') }
        if ($r.left.Count -gt 0) { $why.Add("leftovers [$($r.left -join ', ')]") }
        Assert 'px-8: bump on the placeholder seed (monorepo compare identical) -> in-place hex swap, branch push, pr create, merge --auto --squash --match-head-commit <commit>, MERGED, merge result checked (one -/+ pair, bot identity, parent = main, numstat 1 1 dev, one file, merge commit on gitops main) -> exit 0; summary records enabled_by / merge_method / the head at merge = this commit / the merge commit' (
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '결과: 통과') -and $r.err.Length -eq 0 -and $why.Count -eq 0
        ) "$(Format-Run $r); problems: [$($why -join '; ')]"
    }
    Test-Group 'px-9' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-9' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ dev = (Get-DevSeed $newHex) }
        $r = Invoke-Bs $c @{}
        Assert 'px-9: dev already at the published digest -> exit 0 with a notice, no push, no gh call at all (the stale guard is not reached)' (
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '결과: 할 일 없음') -and (Test-Has $r.out '::notice::') -and $r.calls.Count -eq 0 -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r); gh: [$(Format-Calls $r.calls)]"
    }
    Test-Group 'px-10' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-10' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ dev = $devHead }
        $r = Invoke-Bs $c @{}
        Assert 'px-10: dev overlay without an images entry (the skeleton) -> exit 1 [entry] pointing at the human seed PR; no push, no gh call' (
            (Test-BsFail $r 'entry') -and (Test-Has $r.out 'seed') -and $r.calls.Count -eq 0 -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r); gh: [$(Format-Calls $r.calls)]"
    }
    Test-Group 'px-11' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-11' "not found: $($bsMissing -join ', ')"; return }
        $two = $devHead + "images:`n  - name: ghcr.io/joshua92y/identity-admin`n    newName: ghcr.io/joshua92y/identity-admin`n    digest: sha256:$zeros`n  - name: identity-admin-copy`n    newName: ghcr.io/joshua92y/identity-admin`n    digest: sha256:$('1' * 64)`n"
        $shared = $devHead + "images:`n  - name: ghcr.io/joshua92y/identity-admin`n    newName: ghcr.io/joshua92y/identity-admin`n    digest: sha256:$zeros`n  - name: ghcr.io/joshua92y/other`n    newName: ghcr.io/joshua92y/other`n    digest: sha256:$zeros`n"
        $ca = New-BsCase @{ dev = $two }; $a = Invoke-Bs $ca @{}
        $cb = New-BsCase @{ dev = $shared }; $b = Invoke-Bs $cb @{}
        Assert 'px-11: two images entries for the image (no gh call) and two lines carrying the old digest (only the stale-guard compare) -> each exit 1 ([entry] / [line]); no push' (
            (Test-BsFail $a 'entry') -and (Test-BsFail $b 'line') -and $a.calls.Count -eq 0 -and (Test-OnlyMonoCompare $b) -and (Test-Same $a.refsAfter $ca.refsBefore) -and (Test-Same $b.refsAfter $cb.refsBefore)
        ) "two entries: $(Format-Run $a) | two lines: $(Format-Run $b) gh [$(Format-Calls $b.calls)]"
    }
    Test-Group 'px-12' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-12' "not found: $($bsMissing -join ', ')"; return }
        $dev = (Get-DevSeed $zeros).Replace("    digest: sha256:$zeros`n", "    digest: sha256:$zeros # 자리 값`n")
        $c = New-BsCase @{ dev = $dev }
        $r = Invoke-Bs $c @{}
        Assert 'px-12: the digest line is not the bot line shape (trailing comment) -> exit 1 [line]; no push, no gh call besides the stale-guard compare' (
            (Test-BsFail $r 'line') -and (Test-OnlyMonoCompare $r) -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r); gh [$(Format-Calls $r.calls)]"
    }
    Test-Group 'px-13' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-13' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ preBranch = $true }
        $r = Invoke-Bs $c @{}
        Assert 'px-13: the bump branch already exists on the remote -> exit 1 [branch-exists]; the branch is left as it was (not deleted), no pr call' (
            (Test-BsFail $r 'branch-exists') -and (Test-Same $r.refsAfter $c.refsBefore) -and (Test-Has $r.refsAfter "refs/heads/$branchName $($c.main)") -and (Test-NoGhPr $r)
        ) "$(Format-Run $r); refs after: [$($r.refsAfter)]; gh: [$(Format-Calls $r.calls)]"
    }
    Test-Group 'px-14' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-14' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{}
        $r = Invoke-Bs $c @{ GITHUB_REF = 'refs/heads/003-platform-foundation' }
        Assert 'px-14: GITHUB_REF is not refs/heads/main -> exit 1 [ref]; no push, no gh call' (
            (Test-BsFail $r 'ref') -and $r.calls.Count -eq 0 -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r)"
    }
    Test-Group 'px-15' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-15' "not found: $($bsMissing -join ', ')"; return }
        $res = [ordered]@{}
        foreach ($cs in @(@('closed', 'closed'), @('noauto', 'auto-off'), @('headmove', 'head-moved'), @('apierror', 'api'))) {
            $r = Invoke-Bs (New-BsCase @{ polls = @($cs[0]) }) @{}
            $res[$cs[0]] = @{ r = $r; ok = (Test-BsFail $r $cs[1]) -and (Test-Cleaned $r $true) -and @($r.calls | Where-Object { $_ -contains '--disable-auto' }).Count -eq 0 }
        }
        $t = Invoke-Bs (New-BsCase @{ polls = @('open') }) @{}
        $polls = @($t.calls | Where-Object { $_[1] -eq 'api' -and $_[2] -like 'repos/joshua92y/platform-gitops/pulls/*' }).Count
        $tOk = (Test-BsFail $t 'timeout') -and (Test-Cleaned $t $true) -and $polls -eq 90 -and $t.sleeps -eq 89 -and $t.summary -match '(?m)^- \*\*실패\*\* \[timeout\].*mergeable_state `blocked`'
        $res['timeout'] = @{ r = $t; ok = $tOk }
        $bad = @($res.Keys | Where-Object { -not $res[$_].ok })
        Assert 'px-15: wait (step 7) - closed unmerged, open with auto_merge null, open with the head moved, timeout (90 polls, fake sleep), gh api error -> each exit 1 ([closed] / [auto-off] / [head-moved] / [timeout] / [api]) and cleanup (gh pr close, branch deleted, ls-remote confirms); the timeout summary names mergeable_state only' (
            $bad.Count -eq 0
        ) ("failing: [$($bad -join ', ')]; " + (@($bad | ForEach-Object { "${_}: $(Format-Run $res[$_].r) gh [$(Format-Calls $res[$_].r.calls)] summary [$($res[$_].r.summary)]" }) -join ' | ') + "; timeout polls $polls sleeps $($t.sleeps)")
    }
    Test-Group 'px-16' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-16' "not found: $($bsMissing -join ', ')"; return }
        $a = Invoke-Bs (New-BsCase @{ create = 'fail' }) @{}
        $aOk = (Test-BsFail $a 'pr-create') -and (Test-Cleaned $a $false) -and (Test-SameList ([string[]]@(Get-GhVerbs $a)) @("api $monoCompare", 'api users/joshuatech-gitapp-1[bot]', 'pr create')) -and (Test-Has $a.summary '브랜치')
        $b = Invoke-Bs (New-BsCase @{ polls = @('noauto'); close = 'fail' }) @{}
        $dis = @($b.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'merge' -and ($_ -contains '--disable-auto') })
        $reread = @($b.calls | Where-Object { $_[1] -eq 'api' -and $_[2] -like 'repos/joshua92y/platform-gitops/pulls/*' }).Count
        $bOk = (Test-BsFail $b 'auto-off') -and (Test-RemoteBranchGone $b) -and $dis.Count -eq 1 -and $reread -eq 2 -and (Test-Has $b.summary 'auto-merge 해제: 해제했다') -and (Test-Has $b.summary '원격에 없음')
        Assert 'px-16: cleanup - pr create fails -> the branch is deleted and ls-remote confirms (no PR to close); close fails -> the PR is read once more (not merged) and gh pr merge --disable-auto is tried; both recorded in the summary' (
            $aOk -and $bOk
        ) "create fail: $aOk $(Format-Run $a) summary [$($a.summary)] | close fail: $bOk $(Format-Run $b) gh [$(Format-Calls $b.calls)] summary [$($b.summary)]"
    }
    Test-Group 'px-17' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-17' "not found: $($bsMissing -join ', ')"; return }
        $ca = New-BsCase @{}; $a = Invoke-Bs $ca @{ APP_SLUG = 'other-app' }
        $cb = New-BsCase @{ 'users-id' = '999' }; $b = Invoke-Bs $cb @{}
        $headA = Invoke-Git $ca.gitops @('rev-parse', 'HEAD'); $headB = Invoke-Git $cb.gitops @('rev-parse', 'HEAD')
        Assert 'px-17: bot identity mismatch (APP_SLUG differs, users/<slug>[bot] id differs) -> each exit 1 [identity] before commit and push (clone HEAD = main, remote unchanged, no pr call)' (
            (Test-BsFail $a 'identity') -and (Test-BsFail $b 'identity') -and (Test-Same $headA $ca.main) -and (Test-Same $headB $cb.main) -and
            (Test-Same $a.refsAfter $ca.refsBefore) -and (Test-Same $b.refsAfter $cb.refsBefore) -and (Test-NoGhPr $a) -and (Test-NoGhPr $b)
        ) "APP_SLUG: $(Format-Run $a) | id: $(Format-Run $b) gh [$(Format-Calls $b.calls)]"
    }
    Test-Group 'px-18' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-18' "not found: $($bsMissing -join ', ')"; return }
        $r = Invoke-Bs (New-BsCase @{ create = 'move' }) @{}
        $auto = @($r.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'merge' }).Count
        Assert 'px-18: right after pr create the remote branch tip is not this run''s commit -> exit 1 [pr-tip], no auto-merge, cleanup (close + delete + confirm)' (
            (Test-BsFail $r 'pr-tip') -and $auto -eq 0 -and (Test-Cleaned $r $true)
        ) "$(Format-Run $r); gh [$(Format-Calls $r.calls)]; summary [$($r.summary)]"
    }
    Test-Group 'px-19' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-19' "not found: $($bsMissing -join ', ')"; return }
        $a = Invoke-Bs (New-BsCase @{ polls = @('merged-baddigest') }) @{}
        $b = Invoke-Bs (New-BsCase @{ polls = @('merged-extrafile') }) @{}
        $noClean = { param($r) @($r.calls | Where-Object { $_[1] -eq 'pr' -and ($_[2] -eq 'close' -or ($_ -contains '--disable-auto')) }).Count -eq 0 -and $r.summary -notmatch '(?m)^- \*\*정리\*\* ' }
        Assert 'px-19: the merge commit carries another digest / another numstat -> each exit 1 [merge-check] with no cleanup (already merged)' (
            (Test-BsFail $a 'merge-check') -and (Test-BsFail $b 'merge-check') -and (& $noClean $a) -and (& $noClean $b)
        ) "digest: $(Format-Run $a) | numstat: $(Format-Run $b)"
    }
    Test-Group 'px-20' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-20' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ dirty = $true }
        $r = Invoke-Bs $c @{}
        Assert 'px-20: the gitops work tree is dirty -> exit 1 [tree]; no push, no gh call' (
            (Test-BsFail $r 'tree') -and $r.calls.Count -eq 0 -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r)"
    }
    Test-Group 'px-24' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-24' "not found: $($bsMissing -join ', ')"; return }
        $res = [ordered]@{}
        foreach ($mode in @('ahead-hit', 'ahead-rename')) {
            $c = New-BsCase @{ compare = $mode }
            $r = Invoke-Bs $c @{}
            $res[$mode] = @{ r = $r; ok = -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '결과: 할 일 없음 — 낡은 실행') -and (Test-Has $r.out '::notice::낡은 실행이다') -and
                ($r.summary -match '(?m)^- \[stale\] .*`cafe012`') -and (Test-OnlyMonoCompare $r) -and (Test-Same $r.refsAfter $c.refsBefore) -and $r.err.Length -eq 0 }
        }
        $bad = @($res.Keys | Where-Object { -not $res[$_].ok })
        Assert 'px-24: stale run - monorepo main is ahead and a changed file (filename, or previous_filename of a rename) hits the paths filter -> exit 0 with a notice and a [stale] summary line naming the newest main commit sha7; no branch, no PR (the only gh call is the monorepo compare)' (
            $bad.Count -eq 0
        ) ("failing: [$($bad -join ', ')]; " + (@($bad | ForEach-Object { "${_}: $(Format-Run $res[$_].r) gh [$(Format-Calls $res[$_].r.calls)] summary [$($res[$_].r.summary)]" }) -join ' | '))
    }
    Test-Group 'px-25' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-25' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ compare = 'ahead-miss' }
        $r = Invoke-Bs $c @{}
        Assert 'px-25: monorepo main is ahead but only outside the paths filter (incl. a rename whose old and new names are outside) -> the guard continues and the bump completes (exit 0, merged)' (
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '발행 경로 밖의 변경뿐이다') -and (Test-Has $r.out '결과: 통과') -and (Test-Has $r.summary '**머지 확인**')
        ) "$(Format-Run $r)"
    }
    Test-Group 'px-26' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-26' "not found: $($bsMissing -join ', ')"; return }
        $res = [ordered]@{}
        foreach ($mode in @('behind', 'diverged', 'files300', 'error', 'ahead-nofiles', 'ahead-filesnull', 'ahead-filesmap')) {
            $c = New-BsCase @{ compare = $mode }
            $r = Invoke-Bs $c @{}
            $res[$mode] = @{ r = $r; ok = (Test-BsFail $r 'stale-check') -and (Test-OnlyMonoCompare $r) -and (Test-Same $r.refsAfter $c.refsBefore) -and (Test-Clean $r '::warning::injected-compare-error') }
        }
        $bad = @($res.Keys | Where-Object { -not $res[$_].ok })
        Assert 'px-26: the stale guard fails closed - compare behind, diverged, 300 files (response cap), gh api error, and an ahead response whose files is not a sequence (missing, null, a map) -> each exit 1 [stale-check] with no branch / PR (the error text is printed only inside a stop-commands region)' (
            $bad.Count -eq 0
        ) ("failing: [$($bad -join ', ')]; " + (@($bad | ForEach-Object { "${_}: $(Format-Run $res[$_].r) gh [$(Format-Calls $res[$_].r.calls)]" }) -join ' | '))
    }
    Test-Group 'px-28' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-28' "not found: $($bsMissing -join ', ')"; return }
        $a = Invoke-Bs (New-BsCase @{ gitShim = $true; 'git-push' = 'fail-after' }) @{}
        $aDel = @($a.pushes | Where-Object { $_[1] -eq '1' }).Count; $aUp = @($a.pushes | Where-Object { $_[1] -eq '0' }).Count
        $aOk = (Test-BsFail $a 'push') -and (Test-Has $a.out '올리기는 실패로 끝났지만 원격 브랜치') -and (Test-Cleaned $a $false) -and (Test-NoGhPr $a) -and $aUp -eq 1 -and $aDel -eq 1
        $cb = New-BsCase @{ gitShim = $true; 'git-push' = 'fail-before' }
        $b = Invoke-Bs $cb @{}
        $bDel = @($b.pushes | Where-Object { $_[1] -eq '1' }).Count; $bUp = @($b.pushes | Where-Object { $_[1] -eq '0' }).Count
        $bOk = (Test-BsFail $b 'push') -and $b.summary -notmatch '(?m)^- \*\*정리\*\* ' -and $bUp -eq 1 -and $bDel -eq 0 -and (Test-Same $b.refsAfter $cb.refsBefore) -and (Test-NoGhPr $b)
        Assert 'px-28: the branch push ends in failure - after the remote took the ref (git ls-remote shows this commit) -> cleanup deletes it and confirms, exit 1 [push]; before the remote took it -> exit 1 [push] with no cleanup and no delete push' (
            $aOk -and $bOk
        ) "after: $aOk $(Format-Run $a) pushes [$(Format-Calls $a.pushes)] summary [$($a.summary)] | before: $bOk $(Format-Run $b) pushes [$(Format-Calls $b.pushes)]"
    }
    Test-Group 'px-29' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-29' "not found: $($bsMissing -join ', ')"; return }
        $exit130 = '(?m)^- \*\*dev bump\*\* · 시작 \S+ · 종료 \S+ · \d+초 · exit 130$'
        # (o) ⑦ 기다림 중 SIGTERM(가짜 sleep이 부모에) → 정리 · exit 130
        $o = Invoke-Bs (New-BsCase @{ polls = @('open'); sleepTerm = $true }) @{}
        $oOk = -not $o.missing -and $o.code -eq 130 -and (Test-Has $o.out '[cancel]') -and (Test-Cleaned $o $true) -and $o.sleeps -eq 1 -and
            $o.summary -match '(?m)^- \*\*실패\*\* \[cancel\] ' -and $o.summary -match $exit130
        # (i) 실패 갈래(auto-off)의 정리 도중 SIGTERM(가짜 gh pr close가 부모에) → 정리 중 신호는 무시 — 끝까지 정리하고 원래 실패(exit 1)
        $i = Invoke-Bs (New-BsCase @{ polls = @('noauto'); closeTerm = $true; gitShim = $true }) @{}
        $iDel = @($i.pushes | Where-Object { $_[1] -eq '1' }).Count
        $iOk = (Test-BsFail $i 'auto-off') -and (Test-Cleaned $i $true) -and $iDel -eq 1 -and -not (Test-Has $i.out '[cancel]') -and -not (Test-Has $i.summary '[cancel]')
        # (ii) push 창의 SIGTERM — 원격이 이 실행의 커밋을 받았다(가짜 git push가 올린 뒤 부모에) → 정리(지우기 push 1 · 원격에 없음) · exit 130
        $ii = Invoke-Bs (New-BsCase @{ gitShim = $true; 'git-push' = 'term-after' }) @{}
        $iiDel = @($ii.pushes | Where-Object { $_[1] -eq '1' }).Count
        $iiOk = -not $ii.missing -and $ii.code -eq 130 -and (Test-Has $ii.out '[cancel]') -and (Test-Cleaned $ii $false) -and $iiDel -eq 1 -and (Test-NoGhPr $ii) -and $ii.summary -match $exit130
        # (iii) push 창의 SIGTERM — 원격 끝이 남의 커밋(origin/main의 끝) → 지우지 않는다(지우기 push 0) · exit 130
        $ciii = New-BsCase @{ gitShim = $true; 'git-push' = 'term-other' }
        $iii = Invoke-Bs $ciii @{}
        $iiiDel = @($iii.pushes | Where-Object { $_[1] -eq '1' }).Count
        $iiiOk = -not $iii.missing -and $iii.code -eq 130 -and (Test-Has $iii.out '[cancel]') -and $iiiDel -eq 0 -and (Test-Has $iii.refsAfter "refs/heads/$branchName $($ciii.main)") -and
            $iii.summary -notmatch '(?m)^- \*\*정리\*\* ' -and (Test-NoGhPr $iii)
        # (iv) 머지를 본 뒤 대조 도중 SIGTERM(가짜 gh의 gitops compare가 부모에) → 정리 없음 · 요약에 「취소 중 머지 확인」 · exit 130
        $civ = New-BsCase @{ compareTerm = $true }
        $iv = Invoke-Bs $civ @{}
        $ivMsha = Read-TextOrEmpty (Join-Path $civ.state 'merge-sha')
        $ivOk = -not $iv.missing -and $iv.code -eq 130 -and (Test-Has $iv.out '[cancel]') -and (Test-Has $iv.summary '**취소 중 머지 확인**') -and
            -not (Test-Has $iv.summary '**머지 확인** — PR') -and $iv.summary -notmatch '(?m)^- \*\*정리\*\* ' -and
            @($iv.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'close' }).Count -eq 0 -and $ivMsha.Length -eq 40 -and (Test-Has $iv.refsAfter "refs/heads/main $ivMsha") -and $iv.summary -match $exit130
        # (v) ⑦ 기다림 중 SIGINT(러너가 먼저 보내는 신호 — 가짜 sleep이 부모에) → 정리 · exit 130
        $v = Invoke-Bs (New-BsCase @{ polls = @('open'); sleepInt = $true }) @{}
        $vOk = -not $v.missing -and $v.code -eq 130 -and (Test-Has $v.out '[cancel]') -and (Test-Cleaned $v $true) -and $v.sleeps -eq 1 -and $v.summary -match $exit130
        # (vi) stop-commands 구간 안(show — pr create 실패 출력)에서 SIGTERM(가짜 head가 부모에) → on_signal이 그 구간부터 닫고 [cancel]을 구간 밖에
        # 찍는다 · 정리(브랜치 지움 · PR 없음) · exit 130
        $vi = Invoke-Bs (New-BsCase @{ create = 'fail'; showTerm = $true }) @{}
        $viG = Get-Outside $vi.lines
        $viOk = -not $vi.missing -and $vi.code -eq 130 -and $viG.ok -and $viG.regions -ge 1 -and @($viG.outside | Where-Object { $_.StartsWith('::error::publish-pod-bump [cancel]', [StringComparison]::Ordinal) }).Count -eq 1 -and
            -not (Test-Has $vi.out '[pr-create]') -and (Test-Cleaned $vi $false) -and $vi.summary -match $exit130
        Assert 'px-29: cancellation signals - (o) SIGTERM during the wait (step 7, sleep & wait) -> cleanup and exit 130 [cancel]; (i) SIGTERM during the cleanup of a failure (gh pr close) -> ignored, cleanup completes (delete push 1, gone) and the run ends with the original failure (exit 1 [auto-off], no [cancel]); (ii) SIGTERM in the push window after the remote took this commit -> cleanup (delete push 1, gone), exit 130; (iii) SIGTERM in the push window while the remote tip is someone else''s commit -> no delete push, branch left, exit 130; (iv) SIGTERM while checking the merge result -> no cleanup, the summary records "cancelled after the merge was seen", exit 130; (v) SIGINT during the wait -> cleanup, exit 130; (vi) SIGTERM inside a stop-commands region (show) -> on_signal closes the region first, [cancel] is printed outside it, cleanup, exit 130' (
            $oOk -and $iOk -and $iiOk -and $iiiOk -and $ivOk -and $vOk -and $viOk
        ) "(o) $oOk $(Format-Run $o) | (i) $iOk $(Format-Run $i) pushes [$(Format-Calls $i.pushes)] summary [$($i.summary)] | (ii) $iiOk $(Format-Run $ii) pushes [$(Format-Calls $ii.pushes)] summary [$($ii.summary)] | (iii) $iiiOk $(Format-Run $iii) pushes [$(Format-Calls $iii.pushes)] refs [$($iii.refsAfter)] | (iv) $ivOk $(Format-Run $iv) summary [$($iv.summary)] | (v) $vOk $(Format-Run $v) | (vi) $viOk regions ok $($viG.ok) $(Format-Run $vi)"
    }
    Test-Group 'px-30' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-30' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ polls = @('noauto'); close = 'merged' }
        $r = Invoke-Bs $c @{}
        $msha = Read-TextOrEmpty (Join-Path $c.state 'merge-sha')
        Assert 'px-30: closing fails because the PR merged meanwhile -> the PR is read once more, cleanup stops (no --disable-auto, no branch delete) and the merge result is checked -> exit 0 with the earlier [auto-off] error, a notice and a summary that records it' (
            -not $r.missing -and $r.code -eq 0 -and (Test-Has $r.out '[auto-off]') -and (Test-Has $r.out '정리 중단') -and (Test-Has $r.out '결과: 통과') -and
            @($r.calls | Where-Object { $_ -contains '--disable-auto' }).Count -eq 0 -and $r.summary -notmatch '(?m)^- \*\*정리\*\* ' -and (Test-Has $r.summary '**정리 중단**') -and
            (Test-Has $r.summary '**머지 확인** — [auto-off] 판정 뒤') -and $msha.Length -eq 40 -and (Test-Has $r.refsAfter "refs/heads/main $msha")
        ) "$(Format-Run $r); gh [$(Format-Calls $r.calls)]; summary [$($r.summary)]"
    }
    Test-Group 'px-31' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-31' "not found: $($bsMissing -join ', ')"; return }
        $a = Invoke-Bs (New-BsCase @{ polls = @('basechange') }) @{}
        $b = Invoke-Bs (New-BsCase @{ 'main-compare' = 'diverged' }) @{}
        $bNoClean = @($b.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'close' }).Count -eq 0 -and $b.summary -notmatch '(?m)^- \*\*정리\*\* '
        Assert 'px-31: PR base is not main on a poll -> exit 1 [base] with cleanup; the merge commit is not on gitops main (compare diverged) -> exit 1 [merge-check] with no cleanup' (
            (Test-BsFail $a 'base') -and (Test-Cleaned $a $true) -and (Test-BsFail $b 'merge-check') -and (Test-Has $b.out 'gitops main에 없다') -and $bNoClean
        ) "base: $(Format-Run $a) | not on main: $(Format-Run $b)"
    }
    Test-Group 'px-35' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-35' "not found: $($bsMissing -join ', ')"; return }
        $c = New-BsCase @{ 'users-login' = 'someone-else[bot]' }
        $r = Invoke-Bs $c @{}
        $head = Invoke-Git $c.gitops @('rev-parse', 'HEAD')
        Assert 'px-35: users/<slug>[bot] answers with the right id but another login -> exit 1 [identity] before commit and push (clone HEAD = main, no pr call)' (
            (Test-BsFail $r 'identity') -and (Test-Same $head $c.main) -and (Test-NoGhPr $r) -and (Test-Same $r.refsAfter $c.refsBefore)
        ) "$(Format-Run $r)"
    }
    Test-Group 'px-36' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-36' "not found: $($bsMissing -join ', ')"; return }
        $r = Invoke-Bs (New-BsCase @{ polls = @('merged-twoparents') }) @{}
        Assert 'px-36: the merge commit has two parents (not a squash) -> exit 1 [merge-check] with no cleanup' (
            (Test-BsFail $r 'merge-check') -and (Test-Has $r.out '부모가 하나가 아니다') -and @($r.calls | Where-Object { $_[1] -eq 'pr' -and $_[2] -eq 'close' }).Count -eq 0
        ) "$(Format-Run $r)"
    }
    Test-Group 'px-37' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-37' "not found: $($bsMissing -join ', ')"; return }
        # GitHub paths 필터의 *는 /를 넘지 않는다 — scripts/ci/publish-pod-x/y.sh는 발행 경로가 아니고 scripts/ci/publish-pod-bump.sh는 발행 경로다
        $a = Invoke-Bs (New-BsCase @{ compare = 'ahead-nested' }) @{}
        $cb = New-BsCase @{ compare = 'ahead-script' }
        $b = Invoke-Bs $cb @{}
        $aOk = -not $a.missing -and $a.code -eq 0 -and (Test-Has $a.out '발행 경로 밖의 변경뿐이다') -and (Test-Has $a.out '결과: 통과') -and (Test-Has $a.summary '**머지 확인**')
        $bOk = -not $b.missing -and $b.code -eq 0 -and (Test-Has $b.out '결과: 할 일 없음 — 낡은 실행') -and $b.summary -match '(?m)^- \[stale\] ' -and (Test-OnlyMonoCompare $b) -and (Test-Same $b.refsAfter $cb.refsBefore)
        Assert 'px-37: the stale guard matches the paths filter like GitHub (* does not cross /) - only scripts/ci/publish-pod-x/y.sh changed -> not stale (the bump continues and merges); scripts/ci/publish-pod-bump.sh changed -> stale (exit 0, [stale], no branch / PR)' (
            $aOk -and $bOk
        ) "nested: $aOk $(Format-Run $a) | script: $bOk $(Format-Run $b) gh [$(Format-Calls $b.calls)]"
    }
    Test-Group 'px-38' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-38' "not found: $($bsMissing -join ', ')"; return }
        # git ls-remote origin refs/heads/<b>는 꼬리 일치라 refs/heads/x/refs/heads/<b>도 돌려준다 — ref 이름이 정확히 같은 줄만 세야 한다(라운드 2 F17)
        $decoy = "refs/heads/x/refs/heads/$branchName"
        $ca = New-BsCase @{ decoyRef = $true }
        $a = Invoke-Bs $ca @{}
        $aOk = -not $a.missing -and $a.code -eq 0 -and (Test-Has $a.out '결과: 통과') -and -not (Test-Has $a.out '[branch-exists]') -and (Test-Has $a.refsAfter "$decoy $($ca.main)")
        $b = Invoke-Bs (New-BsCase @{ polls = @('noauto'); decoyOnCreate = $true }) @{}
        $bOk = (Test-BsFail $b 'auto-off') -and (Test-Cleaned $b $true) -and -not (Test-Has $b.summary '남아 있음') -and (Test-Has $b.refsAfter "$decoy ")
        Assert 'px-38: a remote ref that only shares the tail (refs/heads/x/refs/heads/<branch>) - present before step 4 -> not [branch-exists] (the bump continues and merges); created after the push -> the cleanup confirmation does not report the branch as left (원격에 없음)' (
            $aOk -and $bOk
        ) "before: $aOk $(Format-Run $a) | after: $bOk $(Format-Run $b) summary [$($b.summary)] refs [$($b.refsAfter)]"
    }
    Test-Group 'px-21' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-21' "not found: $($bsMissing -join ', ')"; return }
        $mk = '::warning::injected'
        $a = Invoke-Bs (New-BsCase @{ inject = $true; create = 'inject' }) @{}
        $b = Invoke-Bs (New-BsCase @{ inject = $true; create = 'badurl' }) @{}
        $cc = Invoke-Bs (New-BsCase @{ inject = $true; polls = @('noauto') }) @{}
        $injOk = (-not $a.missing -and $a.code -eq 0 -and (Test-Has $a.out '결과: 통과')) -and (Test-BsFail $b 'pr-url') -and (Test-Cleaned $b $false) -and (Test-BsFail $cc 'auto-off') -and
            (Test-Has $cc.out 'mergeable_state 형식 밖') -and (Test-Clean $a $mk) -and (Test-Clean $b $mk) -and (Test-Clean $cc $mk) -and (Test-Has $b.out 'injected-gh-url')
        # 모든 bump 실행: stderr 빈 줄 · 구간 꼴 · 임시 잔여 0 · 가짜 토큰 둘이 0번(출력 · 요약 · PR 본문 · 가짜 호출 기록 · 커밋)
        $all = @($script:bsRuns)
        $dirty = @($all | Where-Object { $_.missing -or $_.err.Length -gt 0 -or $_.left.Count -gt 0 -or -not (Get-Outside $_.lines).ok })
        $leak = [Collections.Generic.List[string]]::new()
        foreach ($x in $all) {
            $c = $x.ctx
            # 클론의 --all은 스크립트가 만든 커밋(HEAD)까지, 원격의 --all은 squash · 남은 브랜치까지 덮는다
            $texts = @($x.out, $x.err, $x.summary, (Read-TextOrEmpty (Join-Path $c.state 'pr-body.md')), (Read-TextOrEmpty (Join-Path $c.state 'gh.log')), (Read-TextOrEmpty (Join-Path $c.state 'git-push.log')),
                (Invoke-Git $c.gitops @('log', '--all', '--format=%an%n%ae%n%cn%n%ce%n%B')), (Invoke-Git $c.remote @('log', '--all', '--format=%an%n%ae%n%cn%n%ce%n%B')))
            if (@($texts | Where-Object { (Test-Has $_ $script:fakeToken) -or (Test-Has $_ $script:fakeMonoToken) }).Count -gt 0) { $leak.Add($c.dir) }
        }
        Assert 'px-21: gh output carrying "::warning::..." (stderr of every call, pr create output, mergeable_state) never reaches the log outside a stop-commands region; every bump run (all px-8-px-38 runs) has empty stderr, well-formed regions, no temp leftovers, and neither fake token value (GH_TOKEN · MONOREPO_TOKEN) appears in any output, summary, PR body, fake call log or commit (clone and remote)' (
            $injOk -and (-not $script:full -or $all.Count -ge 38) -and $dirty.Count -eq 0 -and $leak.Count -eq 0
        ) "inject run: $(Format-Run $a) | bad url: $(Format-Run $b) | noauto: $(Format-Run $cc) | runs: $($all.Count), dirty: $($dirty.Count) [$(@($dirty | ForEach-Object { $_.ctx.dir }) -join ', ')], token found in: $($leak.Count)"
    }
    Test-Group 'px-22' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-22' "not found: $($bsMissing -join ', ')"; return }
        $all = @($script:bsRuns)
        $calls = @(foreach ($x in $all) { $x.calls })
        $banned = @($calls | Where-Object { $j = ($_ -join ' '); ($_[1] -eq 'pr' -and $_[2] -in @('view', 'checks', 'status')) -or $j -match '(?i)graphql|check-runs|statuses|statusCheckRollup' })
        $apiOther = @($calls | Where-Object { $_[1] -eq 'api' -and -not ($_[2] -cmatch '^users/[a-z0-9-]+\[bot\]$' -or $_[2] -cmatch '^repos/joshua92y/platform-gitops/pulls/[0-9]+$' -or $_[2] -cmatch '^repos/joshua92y/platform-gitops/compare/[0-9a-f]{40}\.\.\.refs/heads/main$' -or (Test-Same $_[2] $monoCompare)) })
        Assert 'px-22: across every bump run the fake gh log has no pr view / pr checks / api graphql / check-runs / statuses call - gh api is only users/<slug>[bot], REST pulls/<n>, the gitops compare <merge commit>...refs/heads/main and the monorepo compare <source>...refs/heads/main (head = the branch ref, never a same-named tag)' (
            $all.Count -ge 1 -and (-not $script:full -or ($all.Count -ge 38 -and $calls.Count -ge 60)) -and @($all | Where-Object { $_.missing }).Count -eq 0 -and $banned.Count -eq 0 -and $apiOther.Count -eq 0
        ) "runs: $($all.Count); gh calls: $($calls.Count); banned: [$(Format-Calls $banned)]; other api: [$(Format-Calls $apiOther)]"
    }
    Test-Group 'px-27' {
        if ($bsMissing.Count -gt 0) { Skip-Assert 'px-27' "not found: $($bsMissing -join ', ')"; return }
        $all = @($script:bsRuns)
        $calls = @(foreach ($x in $all) { $x.calls })
        $mono = @($calls | Where-Object { $_[1] -eq 'api' -and (Test-Same $_[2] $monoCompare) })
        $monoWrong = @($mono | Where-Object { -not (Test-Same $_[0] 'gh:mono') })
        $otherWrong = @($calls | Where-Object { -not ($_[1] -eq 'api' -and (Test-Same $_[2] $monoCompare)) -and -not (Test-Same $_[0] 'gh:app') })
        # 모노레포 토큰은 ⓪에서 내보내지 않는 변수로 옮기고 지운다 — gh 호출 어느 것의 env에도 MONOREPO_TOKEN이 없어야 한다(라운드 2 F15)
        $envMarks = @(foreach ($x in $all) { $x.ghEnv })
        $envPresent = @($envMarks | Where-Object { -not (Test-Same $_ 'absent') })
        Assert 'px-27: token separation - every monorepo compare call (the stale guard) runs with the monorepo token and every other gh call with the App token (fake gh token labels; values never logged), and no gh call has MONOREPO_TOKEN in its environment (moved to an unexported variable and unset right after the presence check)' (
            $all.Count -ge 1 -and (-not $script:full -or ($all.Count -ge 38 -and $mono.Count -ge 25)) -and $monoWrong.Count -eq 0 -and $otherWrong.Count -eq 0 -and
            $envMarks.Count -eq $calls.Count -and $envPresent.Count -eq 0
        ) "monorepo compare calls: $($mono.Count) (wrong token $($monoWrong.Count)); other calls with a non-App token: $($otherWrong.Count) [$(@($otherWrong | ForEach-Object { $_[0] + ' ' + (($_ | Select-Object -Skip 1) -join ' ') }) -join ' / ')]; env marks: $($envMarks.Count) for $($calls.Count) calls, MONOREPO_TOKEN present in $($envPresent.Count)"
    }
} finally {
    foreach ($n in $gitEnvNames) { Set-EnvVar $n $savedGitEnv[$n] }
    foreach ($t in $script:temps) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------- px-23: 워크플로의 봇 상수 ↔ gitops validate.sh 봇 기본값 ----------
Test-Group 'px-23' {
    if (-not (Test-Path -LiteralPath $validatePath -PathType Leaf)) { Skip-Assert 'px-23' 'not found: ../platform-gitops/tests/validate.sh (sibling clone)'; return }
    $vt = [IO.File]::ReadAllText($validatePath)
    $ma = [regex]::Match($vt, '(?m)^BOT_AUTHORS="\$\{VALIDATE_BOT_AUTHORS:-([^}"]*)\}"\s*$')
    $mi = [regex]::Match($vt, '(?m)^BOT_IDS="\$\{VALIDATE_BOT_IDS:-([^}"]*)\}"\s*$')
    $authors = if ($ma.Success) { [string[]]($ma.Groups[1].Value -split ',') } else { [string[]]@() }
    $ids = if ($mi.Success) { [string[]]($mi.Groups[1].Value -split ',') } else { [string[]]@() }
    $je = Get-JobSubMap $jobs['bump'] 'env'
    $slug = Unquote ([string]$je.map['BOT_SLUG']); $botIdValue = Unquote ([string]$je.map['BOT_ID'])
    Assert 'px-23: the workflow BOT_SLUG / BOT_ID are in the sibling clone validate.sh defaults (VALIDATE_BOT_AUTHORS has <BOT_SLUG>[bot], VALIDATE_BOT_IDS has BOT_ID)' (
        $slug.Length -gt 0 -and $botIdValue.Length -gt 0 -and ($authors -ccontains "$slug[bot]") -and ($ids -ccontains $botIdValue)
    ) "workflow: [$slug] [$botIdValue]; validate.sh authors: [$($authors -join ',')] ids: [$($ids -join ',')]"
}

$overrides = @()
if ($wfOverride) { $overrides += 'PUBLISH_POD_WORKFLOW' }
if ($asOverride) { $overrides += 'PUBLISH_POD_ASSERT_SCRIPT' }
if ($bsOverride) { $overrides += 'PUBLISH_POD_BUMP_SCRIPT' }
$suffix = ''
if ($overrides.Count -gt 0) { $suffix += " (override: $($overrides -join ', '))" }
if ($script:only.Count -gt 0) { $suffix += " (filtered: $($script:only -join ','))" }
if ($script:gitRetries -gt 0) { Write-Host "`nnote: fixture git calls retried (exit -1 with no output, or the self-path line): $($script:gitRetries)" }
if ($script:skips.Count -gt 0) { Write-Host "`n$($script:skips.Count) skipped (not counted as passed): $($script:skips -join ', ')" }
if ($script:failedIds.Count -gt 0) { Write-Host "`nfailed: $($script:failedIds -join ', ')"; Write-Host "$($script:pass) passed, $($script:fail) failed$suffix" }
else { Write-Host "`n$($script:pass) passed, $($script:fail) failed$suffix" }
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
