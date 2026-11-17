# gitops base 동기화 하네스(T075 D2) — 모노레포 origin/main의 apps/<pod>/deploy/base ↔ 형제 클론 ../platform-gitops origin/main의
#   apps/<pod>/base.
# Run: pwsh -NoProfile -File tests/scripts/gitops-base-sync.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/publish-pod.tests.ps1과 같은 구조 — Assert · Test-Group · 요약 줄).
# 설계: specs/003-platform-foundation/design/t075-design.md D2 — base 정본 = 모노레포 apps/<pod>/deploy/base(시험이 읽는다) · gitops
#   apps/<pod>/base = 파일 이름 1:1 바이트 사본 · 변경 흐름은 모노레포 main 발행(이미지) 뒤에 gitops 사본 PR(매니페스트).
#
# 두 층:
#   자기 시험(gbs-*): 대조 함수 Invoke-GitopsBaseSync · 출력 함수 Format-SyncReport · 집계 함수 Measure-SyncResults · Format-SyncSummary ·
#     형제 자리 함수 Resolve-SiblingClone을 가짜 git 저장소(임시 디렉터리 — 모노레포 꼴 · gitops 꼴 · 원격 접속 없이 refs/remotes/origin/main을
#     update-ref로 · remote.origin.url을 config로 세운다)로 시험한다: PASS · FAIL(이름 · 대소문자만 다른 이름 · blob · mode · 빈 base) · SKIP
#     (형제 클론 없음) · INFO 발행 대기(작업 트리 ≠ origin/main) · origin/main만 읽음(HEAD · 다른 브랜치 · 작업 트리 무관) · replace ref 무시 ·
#     fail closed(origin/main 없음 · 작업 트리 꼭대기 아님(다른 작업 트리의 하위 폴더 포함) · 파일 · base 경로 없음 · base가 파일 ·
#     remote.origin.url이 계약 저장소가 아님(다른 호스트 · 로컬 경로 · file:// 포함) · 형제 클론이 부분 클론 · 주 체크아웃을 풀지 못함
#     (--separate-git-dir) · 형제 자리 오류가 있으면 형제 경로가 없어도 SKIP이 아닌 FAIL · 시간 상한 초과) · 읽기 전용 git(GIT_TRACE2_EVENT로
#     본 git 프로세스의 하위 명령이 읽기 전용 허용 목록 안 · fetch 0 · config는 --get remote.origin.url · extensions.partialclone ·
#     remote.origin.promisor만 · 모든 호출에 -C <저장소> --no-optional-locks --no-replace-objects · 두 .git 디렉터리 그대로) · 자식 env
#     (GIT_NO_LAZY_FETCH=1 · GIT_TERMINAL_PROMPT=0 — 가짜 git이 되비친다) · 홈 경로 가림 · SKIP을 통과로 세지 않는 집계와 run-all 1b7이
#     읽는 요약 줄.
#   실제 대조(sync-<pod>): 동기화 표($SyncPods — 지금 identity-admin 한 줄)의 pod마다 본다.
#     기준 = 모노레포 refs/remotes/origin/main의 apps/<pod>/deploy/base 트리(git ls-tree -r) ↔ 형제 클론 refs/remotes/origin/main의
#     apps/<pod>/base 트리(git ls-tree -r). 항목이 1개 이상이고 이름 집합(트리 기준 상대 경로 — 하위 디렉터리 포함 · ordinal) + blob id + mode가
#     정확히 같으면 PASS, 아니면 FAIL이다(차이를 전부 한 줄에 적는다). 대조한 두 커밋(전체 sha · 커밋 날짜)을 먼저 출력한다.
#     fetch하지 않는다 — 낡았으면 컨트롤러가 두 클론을 fetch한 뒤 다시 돈다.
#     모노레포 작업 트리(git ls-files --cached --others --exclude-standard = 추적 파일 + 무시되지 않은 새 파일 · git hash-object = git add가
#     만들 blob)가 모노레포 origin/main과 다르면 INFO 「발행 대기」 줄만 낸다(FAIL 아님 — 모노레포 main 발행 뒤에 gitops 사본 PR을 낸다).
#     형제 클론 = 주 체크아웃(git rev-parse --path-format=absolute --git-common-dir의 부모)의 부모 안 platform-gitops다 — .worktrees/<x> 같은
#     연결 worktree에서 돌아도 같은 형제를 찾는다(수정 라운드 1 RB-4). SKIP은 그 경로에 아무것도 없을 때뿐이다(px-23 선례 —
#     tests/scripts/publish-pod.tests.ps1). 주 체크아웃을 풀지 못하거나, 그 경로에 무엇이 있는데 git 작업 트리의 꼭대기가 아니거나
#     origin/main · base 경로가 없거나 remote.origin.url이 github.com의 joshua92y/platform-gitops가 아니거나(https · scp · ssh:// 꼴만 —
#     Invoke-GitopsBaseSync 위 주석) 부분 클론(extensions.partialclone · remote.origin.promisor 설정 — git 판과 무관하게 fetch 0)이면
#     FAIL이다(fail closed — URL 값은 출력하지 않는다). 모노레포 쪽 문제(origin/main · base 경로 없음)는 형제 클론이 없어도 FAIL이다.
#     모노레포 PR CI에는 두지 않는다(순서가 이미지 → 매니페스트라 PR 단계에서 강제하면 꼬인다) — 과제 마감의 run-all(1b7)이 강제한다.
#   git 호출(Invoke-GitRead): -C <저장소> --no-optional-locks --no-replace-objects · 자식 env GIT_NO_LAZY_FETCH=1(git 2.44+가 읽는다 — 이 PC의
#     2.43은 무시한다) · GIT_TERMINAL_PROMPT=0 · stdin 닫음 · 호출마다 시간 상한 60 s(넘기면 프로세스 트리를 죽이고 그 pod는 FAIL) · FAIL
#     상세의 git 오류 줄은 사용자 홈 경로를 ~로 가린다.
#   git 환경: 실행 내내 다른 저장소를 가리키는 GIT_DIR류 변수를 지운다. 자기 시험은 사용자 설정과 떨어져 돈다(GIT_CONFIG_NOSYSTEM=1 ·
#     GIT_CONFIG_GLOBAL=빈 파일 — events-compat.tests.ps1 꼴). 실제 대조는 사용자 설정 그대로 돈다(safe.directory 등).
#   실행 시간: 자기 시험 약 1.5–2분(가짜 저장소 약 55개 · 시간 상한 사례 약 5초 — 수정 라운드 2 실측 81–130 s) + 실제 대조 1초 안팎.
# 환경 변수:
#   GITOPS_BASE_SYNC_TESTS_ONLY  쉼표로 나눈 id 또는 접두(gbs · gbs-3 · sync · sync-identity-admin …) — 그 단언만 돈다. 요약 줄 끝에
#                                ' (filtered: …)'가 붙어 tests/run-all.ps1 1b7의 판정을 통과하지 못한다.
# 요약: 'N passed, M failed'. 실패가 있으면 그 바로 앞에 'failed: <id>, …' 한 줄 · SKIP이 있으면 'N skipped …' 줄(통과로 세지 않는다).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
# 형제 클론의 자리는 실제 대조 때 Resolve-SiblingClone이 주 체크아웃(git common dir의 부모) 기준으로 푼다 — 표시는 그 기준의 상대 꼴이다
$gitopsDisplay = '../platform-gitops'
# 동기화 표(설계 D2) — gitops apps/<pod>/base가 모노레포 apps/<pod>/deploy/base의 바이트 사본인 pod. 새 pod의 base 사본이 gitops에 서면 더한다.
$SyncPods = @('identity-admin')
$script:only = [string[]]@(if (-not [string]::IsNullOrEmpty($env:GITOPS_BASE_SYNC_TESTS_ONLY)) { $env:GITOPS_BASE_SYNC_TESTS_ONLY -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } })

$script:pass = 0
$script:fail = 0
$script:skips = [Collections.Generic.List[string]]::new()
$script:failedIds = [Collections.Generic.List[string]]::new()
$script:temps = [Collections.Generic.List[string]]::new()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; $script:failedIds.Add(($name -split ':', 2)[0]); Write-Host "FAIL $name -- $detail" }
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
# 내용 비교는 ordinal로만 한다(-eq · -ceq는 문화권 비교라 무시 가능 문자를 건너뛴다 — CLAUDE.md Known Issues).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-Has([string]$text, [string]$needle) { $null -ne $text -and $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
# 환경 변수를 값으로 둔다 — $null · 빈 값이면 지운다([Environment]::SetEnvironmentVariable($n, $null)은 빈 값의 변수를 남긴다 — events-compat 주석).
function Set-EnvVar([string]$name, [string]$value) {
    if ([string]::IsNullOrEmpty($value)) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
    else { Set-Item -LiteralPath "Env:$name" -Value $value }
}

# ---------- 대조(시험 대상 — 자기 시험이 가짜 저장소로, 실제 대조가 두 클론으로 돌린다) ----------
$script:gitExe = $null           # 첫 호출 때 PATH의 git으로 푼다(자기 시험 gbs-16이 가짜 git으로 잠시 바꾼다)
$script:gitTimeoutMs = 60000     # git 호출 하나의 시간 상한 — 넘기면 프로세스 트리를 죽이고 그 호출은 실패다(수정 라운드 1 RB-5)
# git -C <dir> --no-optional-locks --no-replace-objects <인자> — 읽기 전용 하위 명령만 쓴다(rev-parse · cat-file · ls-tree · ls-files ·
#   hash-object · log · config --get · fetch 없음). replace ref가 비교 대상 객체를 바꿔 보이지 못하게 --no-replace-objects를 붙이고(리뷰 B
#   P2 — replace가 있으면 drift가 PASS했다), 자식 env에 GIT_NO_LAZY_FETCH=1(부분 클론의 지연 fetch 금지 — git 2.44+가 읽는다 · 더 낮은 판은
#   무시한다) · GIT_TERMINAL_PROMPT=0(자격 프롬프트 금지)을 둔다. 반환 @{ code; out; err; timedOut }. stdout · stderr는 UTF-8로 읽는다
#   (콘솔 코드 페이지와 무관 · -z 출력의 NUL 그대로) · stdin은 바로 닫는다 · $script:gitTimeoutMs를 넘기면 code -1 + timedOut.
function Invoke-GitRead([string]$dir, [string[]]$gitArgs) {
    if ($null -eq $script:gitExe) {
        $c = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue)
        if ($c.Count -eq 0) { throw 'git not found on PATH' }
        $script:gitExe = $c[0].Source
    }
    $psi = [Diagnostics.ProcessStartInfo]::new($script:gitExe)
    foreach ($a in @('-C', $dir, '--no-optional-locks', '--no-replace-objects') + @($gitArgs)) { $psi.ArgumentList.Add([string]$a) }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $psi.Environment['GIT_NO_LAZY_FETCH'] = '1'
    $psi.Environment['GIT_TERMINAL_PROMPT'] = '0'
    $p = [Diagnostics.Process]::Start($psi)
    try {
        $p.StandardInput.Close()
        $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($script:gitTimeoutMs)) {
            try { $p.Kill($true) } catch { }
            $p.WaitForExit()
            $sec = [Math]::Round($script:gitTimeoutMs / 1000.0, 1)
            return @{ code = -1; out = ''; err = "git $(@($gitArgs)[0]) timed out after $sec s (process tree killed)"; timedOut = $true }
        }
        return @{ code = $p.ExitCode; out = $o.Result; err = $e.Result.Trim(); timedOut = $false }
    } finally { $p.Dispose() }
}
function Get-FirstLine([string]$s) { if ([string]::IsNullOrEmpty($s)) { return '' }; return ($s -split "`r?`n", 2)[0].Trim() }
# 사용자 홈 경로를 ~로 가린다(\ · / 두 구분자 · 대소문자 무시 — git 오류 줄이 저장소 경로를 그대로 싣는다: 수정 라운드 1 N3)
function Hide-Home([string]$s) {
    $h = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrEmpty($s) -or [string]::IsNullOrEmpty($h)) { return $s }
    $pattern = [regex]::Escape($h.TrimEnd('\', '/')).Replace('\\', '[\\/]')
    return [regex]::Replace($s, $pattern, '~', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
}
# git 오류의 첫 줄(홈 경로를 가린 꼴) — FAIL 상세에 싣는 유일한 git 원문이다
function Get-ErrLine([string]$s) { return Hide-Home (Get-FirstLine $s) }
# 형제 클론 자리 = 주 체크아웃(git common dir의 부모)의 부모 안 <name>. .worktrees/<x> 같은 연결 worktree에서 돌아도 주 체크아웃 기준으로 푼다
#   (수정 라운드 1 RB-4 ② · 설계 D2 「형제 클론이 없을 때만 SKIP」). → @{ error = 이유 | $null; path }
function Resolve-SiblingClone([string]$monoRoot, [string]$name) {
    $r = Invoke-GitRead $monoRoot @('rev-parse', '--path-format=absolute', '--git-common-dir')
    $common = $r.out.Trim()
    if ($r.code -ne 0 -or $common.Length -eq 0) { return @{ error = "monorepo: cannot locate the main checkout (git rev-parse --git-common-dir exit $($r.code): $(Get-ErrLine $r.err))"; path = $null } }
    $trimmed = $common.TrimEnd('/', '\')
    if (-not (Test-Same ([IO.Path]::GetFileName($trimmed)) '.git')) { return @{ error = "monorepo: cannot locate the main checkout (the common git directory is not <checkout>/.git)"; path = $null } }
    $main = [IO.Path]::GetDirectoryName($trimmed)
    return @{ error = $null; path = (Join-Path ([IO.Path]::GetDirectoryName($main)) $name) }
}
# 저장소 작업 트리의 꼭대기인지 보고(부모 저장소로 풀리면 안 된다) refs/remotes/origin/main 커밋을 푼다 — fetch하지 않는다.
#   반환 @{ error = 이유 | $null; sha; date }
function Resolve-OriginMain([string]$dir, [string]$label) {
    $top = Invoke-GitRead $dir @('rev-parse', '--show-cdup')
    if ($top.timedOut) { return @{ error = "${label}: $(Get-ErrLine $top.err)" } }
    if ($top.code -ne 0) { return @{ error = "${label}: not the top of a git work tree (git rev-parse --show-cdup exit $($top.code): $(Get-ErrLine $top.err))" } }
    if ($top.out.Trim().Length -gt 0) { return @{ error = "${label}: not the top of a git work tree (the enclosing work tree starts at $($top.out.Trim()))" } }
    $c = Invoke-GitRead $dir @('rev-parse', '--verify', '--quiet', 'refs/remotes/origin/main^{commit}')
    $sha = $c.out.Trim()
    if ($c.timedOut) { return @{ error = "${label}: $(Get-ErrLine $c.err)" } }
    if ($c.code -ne 0 -or -not [regex]::IsMatch($sha, '\A(?:[0-9a-f]{40}|[0-9a-f]{64})\z')) { return @{ error = "${label}: refs/remotes/origin/main not found (this harness never fetches -- fetch the clone first)" } }
    $d = Invoke-GitRead $dir @('log', '-1', '--format=%cs', $sha)
    return @{ error = $null; sha = $sha; date = $(if ($d.code -eq 0) { $d.out.Trim() } else { '?' }) }
}
# gitops 클론의 remote.origin.url이 계약 저장소인가(값은 출력하지 않는다 — 자격이 든 URL일 수 있다) → 이유 | $null.
#   대소문자 무시는 패턴 안의 (?i:…)(호스트)뿐이고 CultureInvariant로 맞춘다(문화권별 대소문자 규칙과 무관).
function Test-GitopsRemote([string]$dir, [string]$label, [string]$pattern) {
    $u = Invoke-GitRead $dir @('config', '--get', 'remote.origin.url')
    if ($u.timedOut) { return "${label}: $(Get-ErrLine $u.err)" }
    $url = $u.out.Trim()
    if ($u.code -ne 0 -or $url.Length -eq 0) { return "${label}: remote.origin.url is not set (expected the github.com/joshua92y/platform-gitops clone)" }
    if (-not [regex]::IsMatch($url, $pattern, [Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        return "${label}: remote.origin.url is not github.com/joshua92y/platform-gitops (value not printed; expected https://github.com/, git@github.com: or ssh://git@github.com/ + joshua92y/platform-gitops, optional .git)"
    }
    return $null
}
# 부분 클론이면 객체를 읽다가 지연 fetch할 수 있다(GIT_NO_LAZY_FETCH는 git 2.44+만 읽는다) — 설정만 읽어(config --get) 판정한다.
#   extensions.partialclone 또는 remote.origin.promisor가 있으면(값과 무관) 이유를 돌려준다. exit 1 = 없음 · 그 밖의 exit = 읽기 실패(fail closed).
function Test-PartialClone([string]$dir, [string]$label) {
    foreach ($key in @('extensions.partialclone', 'remote.origin.promisor')) {
        $c = Invoke-GitRead $dir @('config', '--get', $key)
        if ($c.timedOut) { return "${label}: $(Get-ErrLine $c.err)" }
        if ($c.code -eq 0) { return "${label}: partial clone ($key is set) -- reading its objects could fetch lazily; this harness never fetches -- use a full clone" }
        if ($c.code -ne 1) { return "${label}: cannot read $key (git config --get exit $($c.code): $(Get-ErrLine $c.err))" }
    }
    return $null
}
function New-EntryMap { return [Collections.Generic.SortedDictionary[string, string]]::new([StringComparer]::Ordinal) }
# <commit>:<path> 트리의 항목(재귀 — 이름 = 트리 기준 상대 경로 · ordinal) → @{ error; oids = 이름 → object id; modes = 이름 → mode }
function Get-TreeEntries([string]$dir, [string]$sha, [string]$path, [string]$label) {
    $short = $sha.Substring(0, 7)
    $t = Invoke-GitRead $dir @('cat-file', '-t', "${sha}:$path")
    if ($t.timedOut) { return @{ error = "$path in $label origin/main ${short}: $(Get-ErrLine $t.err)" } }
    if ($t.code -ne 0) { return @{ error = "$path absent in $label origin/main $short (git: $(Get-ErrLine $t.err))" } }
    $type = $t.out.Trim()
    if (-not (Test-Same $type 'tree')) { return @{ error = "$path is a $type in $label origin/main $short (expected a directory)" } }
    $l = Invoke-GitRead $dir @('ls-tree', '-r', '-z', "${sha}:$path")
    if ($l.code -ne 0) { return @{ error = "git ls-tree of $path in $label origin/main $short failed (exit $($l.code): $(Get-ErrLine $l.err))" } }
    $oids = New-EntryMap; $modes = New-EntryMap
    foreach ($rec in $l.out.Split([char]0)) {
        if ($rec.Length -eq 0) { continue }
        $m = [regex]::Match($rec, '\A([0-7]{6}) [a-z]+ ([0-9a-f]{40}|[0-9a-f]{64})\t(.+)\z', [Text.RegularExpressions.RegexOptions]::Singleline)
        if (-not $m.Success) { return @{ error = "unexpected git ls-tree record under $path in $label origin/main $short" } }
        $oids[$m.Groups[3].Value] = $m.Groups[2].Value
        $modes[$m.Groups[3].Value] = $m.Groups[1].Value
    }
    return @{ error = $null; oids = $oids; modes = $modes }
}
# 모노레포 작업 트리의 <path> — 추적 파일 + 무시되지 않은 새 파일(ls-files --cached --others --exclude-standard) 가운데 작업 트리에 있는 것의
#   git add가 만들 blob(hash-object — 저장소 속성의 줄 끝 정규화 포함). 작업 트리에 없는 추적 파일은 빠진 것이다. → @{ error; oids }
function Get-WorktreeEntries([string]$dir, [string]$path) {
    $l = Invoke-GitRead $dir @('ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', "$path/")
    if ($l.code -ne 0) { return @{ error = "git ls-files of the monorepo working tree $path failed (exit $($l.code): $(Get-ErrLine $l.err))" } }
    $rels = [Collections.Generic.List[string]]::new()
    foreach ($p in $l.out.Split([char]0)) {
        if ($p.Length -eq 0 -or $rels.Contains($p)) { continue }
        if (Test-Path -LiteralPath (Join-Path $dir $p) -PathType Leaf) { $rels.Add($p) }
    }
    $oids = New-EntryMap
    if ($rels.Count -gt 0) {
        $h = Invoke-GitRead $dir (@('hash-object', '--') + $rels.ToArray())
        $ids = @($h.out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
        if ($h.code -ne 0 -or $ids.Count -ne $rels.Count) { return @{ error = "git hash-object of the monorepo working tree $path failed (exit $($h.code): $(Get-ErrLine $h.err))" } }
        for ($i = 0; $i -lt $rels.Count; $i++) { $oids[$rels[$i].Substring($path.Length + 1)] = $ids[$i] }
    }
    return @{ error = $null; oids = $oids }
}
# 두 항목 표의 차이 → @{ onlyA; onlyB; differ } (이름은 ordinal 순)
function Compare-EntryMaps($a, $b) {
    $onlyA = @($a.Keys | Where-Object { -not $b.ContainsKey($_) })
    $onlyB = @($b.Keys | Where-Object { -not $a.ContainsKey($_) })
    $differ = @($a.Keys | Where-Object { $b.ContainsKey($_) -and -not (Test-Same $a[$_] $b[$_]) })
    return @{ onlyA = $onlyA; onlyB = $onlyB; differ = $differ }
}
# 동기화 표의 pod마다 대조한다 → 보고 객체(MonoCommit · MonoDate · GitopsState(ok · absent · error) · GitopsCommit · GitopsDate · GitopsDisplay ·
#   Results = pod마다 @{ Pod; Id = sync-<pod>; Verdict = PASS | FAIL | SKIP; Detail; Info = 발행 대기 문장 | $null }).
#   SKIP은 형제 클론 경로에 아무것도 없고 모노레포 쪽이 풀릴 때뿐이다(그 밖의 문제는 전부 FAIL — fail closed). $GitopsLocateError(형제 자리를
#   풀지 못함)가 있으면 경로를 보지 않고 FAIL이다. 형제 클론은 꼭대기 · origin/main · remote.origin.url(= $GitopsRemotePattern — 수정 라운드 1
#   RB-4 ① · 라운드 2 RB2-2에서 호스트까지 고정) · 부분 클론 아님(라운드 2 덤 — 트리 객체를 읽기 전)을 지나야 대조한다. PASS = 항목 1개 이상 +
#   이름 집합 · blob id · mode가 모두 같음(N1).
#   원격 패턴: https://[userinfo@]github.com/ · git@github.com: · ssh://git@github.com/ 뒤에 joshua92y/platform-gitops[.git][/]로 끝난다. 호스트만
#   대소문자 무시((?i:…)) · 소유자 · 저장소 이름은 정확히. userinfo는 @ / ? # \를 품지 못한다 — https://<다른 호스트>#@github.com/…처럼 권한부가
#   @ 앞에서 끝나 실제 접속 호스트가 github.com이 아닌 꼴을 막는다(수정 라운드 2 — 리뷰 정규식의 [^@/]+를 좁힘).
function Invoke-GitopsBaseSync([string]$MonoRoot, [string]$GitopsRoot, [string]$GitopsDisplay, [string[]]$Pods, [string]$GitopsLocateError = '',
    [string]$GitopsRemotePattern = '\A(?:https://(?:[^@/?#\\]+@)?(?i:github\.com)/|git@(?i:github\.com):|ssh://git@(?i:github\.com)/)joshua92y/platform-gitops(?:\.git)?/?\z') {
    $rep = [ordered]@{ MonoCommit = $null; MonoDate = $null; GitopsState = 'ok'; GitopsCommit = $null; GitopsDate = $null; GitopsDisplay = $GitopsDisplay; Results = [Collections.Generic.List[object]]::new() }
    $mono = Resolve-OriginMain $MonoRoot 'monorepo'
    if ($null -eq $mono.error) { $rep.MonoCommit = $mono.sha; $rep.MonoDate = $mono.date }
    $gitopsError = $null
    if (-not [string]::IsNullOrEmpty($GitopsLocateError)) { $rep.GitopsState = 'error'; $gitopsError = $GitopsLocateError }
    elseif (-not (Test-Path -LiteralPath $GitopsRoot)) { $rep.GitopsState = 'absent' }
    elseif (-not (Test-Path -LiteralPath $GitopsRoot -PathType Container)) { $rep.GitopsState = 'error'; $gitopsError = "gitops ${GitopsDisplay}: exists but is not a directory" }
    else {
        $g = Resolve-OriginMain $GitopsRoot "gitops $GitopsDisplay"
        if ($null -ne $g.error) { $rep.GitopsState = 'error'; $gitopsError = $g.error }
        else {
            $cloneError = Test-GitopsRemote $GitopsRoot "gitops $GitopsDisplay" $GitopsRemotePattern
            if ($null -eq $cloneError) { $cloneError = Test-PartialClone $GitopsRoot "gitops $GitopsDisplay" }
            if ($null -ne $cloneError) { $rep.GitopsState = 'error'; $gitopsError = $cloneError }
            else { $rep.GitopsCommit = $g.sha; $rep.GitopsDate = $g.date }
        }
    }
    foreach ($pod in $Pods) {
        $monoPath = "apps/$pod/deploy/base"; $gitopsPath = "apps/$pod/base"
        $problems = [Collections.Generic.List[string]]::new(); $info = $null; $monoTree = $null
        if ($null -ne $mono.error) { $problems.Add($mono.error) }
        else {
            $monoTree = Get-TreeEntries $MonoRoot $rep.MonoCommit $monoPath 'monorepo'
            if ($null -ne $monoTree.error) { $problems.Add($monoTree.error); $monoTree = $null }
            else {
                $wt = Get-WorktreeEntries $MonoRoot $monoPath
                if ($null -ne $wt.error) { $problems.Add($wt.error) }
                else {
                    $d = Compare-EntryMaps $monoTree.oids $wt.oids
                    $parts = @()
                    if ($d.differ.Count -gt 0) { $parts += "changed: $($d.differ -join ', ')" }
                    if ($d.onlyB.Count -gt 0) { $parts += "new: $($d.onlyB -join ', ')" }
                    if ($d.onlyA.Count -gt 0) { $parts += "removed: $($d.onlyA -join ', ')" }
                    if ($parts.Count -gt 0) {
                        $info = "발행 대기 -- the monorepo working tree differs from monorepo origin/main in $monoPath ($($parts -join '; ')) -- not a FAIL: publish to monorepo main first, then the gitops base copy PR (image -> manifest)"
                    }
                }
            }
        }
        $verdict = 'FAIL'; $detail = $null
        if (Test-Same $rep.GitopsState 'absent') {
            if ($problems.Count -eq 0) { $verdict = 'SKIP'; $detail = "not found: $GitopsDisplay (sibling clone)" }
        } elseif (Test-Same $rep.GitopsState 'error') { $problems.Add($gitopsError) }
        else {
            $gitopsTree = Get-TreeEntries $GitopsRoot $rep.GitopsCommit $gitopsPath 'gitops'
            if ($null -ne $gitopsTree.error) { $problems.Add($gitopsTree.error) }
            elseif ($null -ne $monoTree) {
                $d = Compare-EntryMaps $monoTree.oids $gitopsTree.oids
                if ($d.onlyA.Count -gt 0) { $problems.Add("only in monorepo ${monoPath}: $($d.onlyA -join ', ')") }
                if ($d.onlyB.Count -gt 0) { $problems.Add("only in gitops ${gitopsPath}: $($d.onlyB -join ', ')") }
                if ($d.differ.Count -gt 0) {
                    $blobs = @($d.differ | ForEach-Object { "$_ (monorepo $($monoTree.oids[$_].Substring(0, 7)), gitops $($gitopsTree.oids[$_].Substring(0, 7)))" })
                    $problems.Add("blob differs: $($blobs -join ', ')")
                }
                $md = Compare-EntryMaps $monoTree.modes $gitopsTree.modes
                $modeDiff = @($md.differ)
                if ($modeDiff.Count -gt 0) {
                    $modes = @($modeDiff | ForEach-Object { "$_ (monorepo $($monoTree.modes[$_]), gitops $($gitopsTree.modes[$_]))" })
                    $problems.Add("mode differs: $($modes -join ', ')")
                }
                if ($problems.Count -eq 0 -and $monoTree.oids.Count -eq 0) { $problems.Add("no entries under $monoPath and $gitopsPath (an empty base is not a copy)") }
                if ($problems.Count -eq 0) {
                    $verdict = 'PASS'
                    $detail = "$monoPath (monorepo origin/main) == $gitopsPath (gitops origin/main): $($monoTree.oids.Count) entries, same names, blob ids and modes"
                }
            }
        }
        if (Test-Same $verdict 'FAIL') { $detail = "$($problems.Count) problem(s): $($problems -join '; ')" }
        $rep.Results.Add([pscustomobject]@{ Pod = $pod; Id = "sync-$pod"; Verdict = $verdict; Detail = $detail; Info = $info })
    }
    return [pscustomobject]$rep
}
# 보고 → 출력 줄: 대조한 두 커밋 한 줄, 그다음 pod마다 판정 줄(PASS | FAIL | SKIP sync-<pod>: …)과 발행 대기면 INFO 줄
function Format-SyncReport($rep) {
    $lines = [Collections.Generic.List[string]]::new()
    $m = if ($null -ne $rep.MonoCommit) { "$($rep.MonoCommit) ($($rep.MonoDate))" } else { '<unresolved>' }
    $g = if ($null -ne $rep.GitopsCommit) { "$($rep.GitopsCommit) ($($rep.GitopsDate))" } elseif (Test-Same $rep.GitopsState 'absent') { '<sibling clone not found>' } else { '<unresolved>' }
    $lines.Add("commits: monorepo refs/remotes/origin/main = $m · gitops $($rep.GitopsDisplay) refs/remotes/origin/main = $g -- no fetch (fetch both clones first when stale)")
    foreach ($r in @($rep.Results)) {
        $lines.Add("$($r.Verdict) $($r.Id): $($r.Detail)")
        if ($null -ne $r.Info) { $lines.Add("INFO $($r.Id): $($r.Info)") }
    }
    return $lines.ToArray()
}
# 실제 대조 결과 → 집계(수정 라운드 1 RB-3): PASS만 통과로 센다 · SKIP은 따로 모으고 통과로 세지 않는다 · 그 밖의 판정은 전부 실패다(ordinal).
#   → @{ pass; fail; skips = id 목록; failed = id 목록 }
function Measure-SyncResults($results) {
    $t = @{ pass = 0; fail = 0; skips = [Collections.Generic.List[string]]::new(); failed = [Collections.Generic.List[string]]::new() }
    foreach ($r in @($results)) {
        if (Test-Same ([string]$r.Verdict) 'PASS') { $t.pass++ }
        elseif (Test-Same ([string]$r.Verdict) 'SKIP') { $t.skips.Add([string]$r.Id) }
        else { $t.fail++; $t.failed.Add([string]$r.Id) }
    }
    return $t
}
# 요약 줄들 — SKIP이 있으면 'N skipped (not counted as passed): …'(run-all 1b7의 NOTE가 읽는다) · 실패가 있으면 'failed: …' 뒤에 마지막 줄
#   'P passed, F failed<접미>'(run-all 1b7의 판정 줄)
function Format-SyncSummary([int]$pass, [int]$fail, [string[]]$skips, [string[]]$failedIds, [string]$suffix) {
    $lines = [Collections.Generic.List[string]]::new()
    if (@($skips).Count -gt 0) { $lines.Add(''); $lines.Add("$(@($skips).Count) skipped (not counted as passed): $(@($skips) -join ', ')") }
    $lines.Add('')
    if (@($failedIds).Count -gt 0) { $lines.Add("failed: $(@($failedIds) -join ', ')") }
    $lines.Add("$pass passed, $fail failed$suffix")
    return $lines.ToArray()
}

# ---------- 자기 시험 픽스처(가짜 git 저장소 — 시험 대상과 따로 git을 부른다) ----------
function New-TempDir([string]$prefix) {
    $d = Join-Path ([IO.Path]::GetTempPath()) ($prefix + [guid]::NewGuid().ToString('N').Substring(0, 12))
    [void][IO.Directory]::CreateDirectory($d)
    $script:temps.Add($d)
    return $d
}
function Invoke-FixtureGit([string]$dir, [string[]]$gitArgs) {
    $out = @(& git -C $dir @gitArgs 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) { throw "fixture git $($gitArgs -join ' ') (exit $LASTEXITCODE): $($out -join ' | ')" }
    return ($out -join "`n").Trim()
}
# 키 = 저장소 기준 상대 경로, 값 = 내용(UTF-8 · BOM 없음 · 값 그대로 — 줄 끝도 그대로). 값이 $null이면 지운다.
function Write-Files([string]$dir, [hashtable]$files) {
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
function Save-FixtureCommit([string]$dir, [string]$message) {
    [void](Invoke-FixtureGit $dir @('add', '-A'))
    [void](Invoke-FixtureGit $dir @('-c', 'user.name=gitops-base-sync test', '-c', 'user.email=gbs@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-q', '-m', $message))
}
# 저장소 하나 — 파일을 쓰고 커밋한다. -NoOrigin이 아니면 refs/remotes/origin/main을 그 커밋에 세운다(원격 · fetch 없음).
function New-FixtureRepo([string]$prefix, [hashtable]$files, [switch]$NoOrigin) {
    $d = New-TempDir $prefix
    [void](Invoke-FixtureGit $d @('init', '-q', '-b', 'main'))
    Write-Files $d $files
    Save-FixtureCommit $d 'fixture'
    if (-not $NoOrigin) { [void](Invoke-FixtureGit $d @('update-ref', 'refs/remotes/origin/main', 'HEAD')) }
    return $d
}
# pod → @{ 이름 → 내용 } 표로 base 파일 목록을 만든다(모노레포 apps/<pod>/deploy/base · gitops apps/<pod>/base)
function Get-FixtureFiles([string]$readme, [string]$baseDir, [hashtable]$pods, [hashtable]$extra) {
    $f = @{ 'README.md' = "$readme`n" }
    foreach ($pod in $pods.Keys) { foreach ($name in $pods[$pod].Keys) { $f[($baseDir -f $pod) + '/' + $name] = $pods[$pod][$name] } }
    foreach ($k in $extra.Keys) { $f[$k] = $extra[$k] }
    return $f
}
function New-MonoFixture([hashtable]$pods, [hashtable]$extra = @{}, [switch]$NoOrigin) {
    return New-FixtureRepo 'gbs-mono-' (Get-FixtureFiles 'monorepo fixture' 'apps/{0}/deploy/base' $pods $extra) -NoOrigin:$NoOrigin
}
# gitops 꼴 저장소 — remote.origin.url을 $Remote로 둔다(기본 = 계약 저장소 URL · 빈 값이면 두지 않는다 · 원격 접속은 없다)
$fixtureGitopsRemote = 'https://github.com/joshua92y/platform-gitops.git'
function New-GitopsFixture([hashtable]$pods, [hashtable]$extra = @{}, [switch]$NoOrigin, [string]$Remote = $fixtureGitopsRemote) {
    $d = New-FixtureRepo 'gbs-gitops-' (Get-FixtureFiles 'gitops fixture' 'apps/{0}/base' $pods $extra) -NoOrigin:$NoOrigin
    if (-not [string]::IsNullOrEmpty($Remote)) { [void](Invoke-FixtureGit $d @('config', 'remote.origin.url', $Remote)) }
    return $d
}
function Get-FixtureRev([string]$dir, [string]$rev) { return Invoke-FixtureGit $dir @('rev-parse', $rev) }
function Format-Results($results) { return ((@($results) | ForEach-Object { "$($_.Id)=$($_.Verdict) [$($_.Detail)] info=[$($_.Info)]" }) -join ' ;; ') }
# 트리 하나를 만든다(git mktree — 줄 = "<mode> <type> <sha>`t<이름>" · 정렬은 mktree가 한다). 입력은 LF 바이트로 직접 쓴다 — PowerShell
#   파이프는 Windows에서 네이티브 stdin에 CRLF를 붙여 항목 이름이 'base\r'이 된다(이 하네스 수정 라운드 1 실측).
function New-FixtureTree([string]$dir, [string[]]$entries) {
    $psi = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in @('-C', $dir, 'mktree')) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [Diagnostics.Process]::Start($psi)
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes((($entries -join "`n") + "`n"))
        $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length); $p.StandardInput.Close()
        $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) { throw "fixture git mktree (exit $($p.ExitCode)): $($e.Result.Trim())" }
        return $o.Result.Trim()
    } finally { $p.Dispose() }
}
# <segments>(예 apps/pod-a/base)가 빈 트리인 커밋을 refs/remotes/origin/main에 세운다(git은 빈 디렉터리를 커밋하지 않으므로 plumbing으로 만든다)
function Set-EmptyBaseOrigin([string]$dir, [string[]]$segments) {
    $child = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'   # 빈 트리
    for ($i = $segments.Count - 1; $i -ge 1; $i--) { $child = New-FixtureTree $dir @("040000 tree $child`t$($segments[$i])") }
    $readme = Invoke-FixtureGit $dir @('rev-parse', 'HEAD:README.md')
    $root = New-FixtureTree $dir @("100644 blob $readme`tREADME.md", "040000 tree $child`t$($segments[0])")
    $commit = Invoke-FixtureGit $dir @('-c', 'user.name=gitops-base-sync test', '-c', 'user.email=gbs@example.invalid', 'commit-tree', $root, '-m', 'empty base')
    [void](Invoke-FixtureGit $dir @('update-ref', 'refs/remotes/origin/main', $commit))
}
# 문자열 목록에 ordinal로 있는가(-contains · -ccontains는 문화권 비교 — CLAUDE.md Known Issues)
function Test-InList([string[]]$list, [string]$v) { foreach ($x in @($list)) { if (Test-Same $x $v) { return $true } }; return $false }
# 홈 경로(두 구분자 · 대소문자 무시)가 들어 있는가
function Test-HasHome([string]$s) {
    $h = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrEmpty($s) -or [string]::IsNullOrEmpty($h)) { return $false }
    return $s.IndexOf($h, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or $s.IndexOf($h.Replace('\', '/'), [StringComparison]::OrdinalIgnoreCase) -ge 0
}
# GIT_TRACE2_EVENT로 본문의 git 프로세스를 기록한다(start 이벤트의 argv에 -C · 전역 옵션 · 하위 명령이 그대로 실린다)
function Invoke-Traced([string]$traceFile, [scriptblock]$sb) {
    $saved = [Environment]::GetEnvironmentVariable('GIT_TRACE2_EVENT')
    Set-EnvVar 'GIT_TRACE2_EVENT' $traceFile
    try { return (& $sb) } finally { Set-EnvVar 'GIT_TRACE2_EVENT' $saved }
}
# 기록 파일의 start 이벤트마다 @{ dir = -C 값; opts = 하위 명령 앞의 전역 옵션; sub = 하위 명령; rest = 하위 명령 뒤 인자 }
function Get-TraceCalls([string]$file) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { return @() }
    $calls = [Collections.Generic.List[object]]::new()
    foreach ($l in [IO.File]::ReadAllLines($file)) {
        if ($l.IndexOf('"event":"start"', [StringComparison]::Ordinal) -lt 0) { continue }
        $argv = [string[]]@(($l | ConvertFrom-Json).argv)
        $dir = $null; $opts = [Collections.Generic.List[string]]::new(); $i = 1
        while ($i -lt $argv.Count) {
            if (Test-Same $argv[$i] '-C') { $dir = $argv[$i + 1]; $i += 2; continue }
            if ($argv[$i].StartsWith('-', [StringComparison]::Ordinal)) { $opts.Add($argv[$i]); $i++; continue }
            break
        }
        $sub = if ($i -lt $argv.Count) { $argv[$i] } else { '' }
        $rest = if ($i + 1 -lt $argv.Count) { [string[]]$argv[($i + 1)..($argv.Count - 1)] } else { [string[]]@() }
        $calls.Add(@{ dir = $dir; opts = $opts.ToArray(); sub = $sub; rest = $rest })
    }
    return $calls.ToArray()
}
function Test-SamePath([string]$a, [string]$b) {
    if ($null -eq $a -or $null -eq $b) { return $false }
    return [string]::Equals($a.Replace('\', '/').TrimEnd('/'), $b.Replace('\', '/').TrimEnd('/'), [StringComparison]::OrdinalIgnoreCase)
}
# .git 디렉터리의 파일 목록(상대 경로 · 크기 · 쓰기 시각) — 대조 전후가 같아야 한다(쓰기 0)
function Get-GitDirSnapshot([string]$dir) {
    $g = Join-Path $dir '.git'
    return ((@(Get-ChildItem -LiteralPath $g -Recurse -File -Force | ForEach-Object { "$($_.FullName.Substring($g.Length))|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) | Sort-Object) -join "`n")
}

$yA = "apiVersion: v1`nkind: ConfigMap`nmetadata:`n  name: a`n"
$yB = "apiVersion: v1`nkind: Service`nmetadata:`n  name: b`n"
$yC = "apiVersion: apps/v1`nkind: Deployment`nmetadata:`n  name: c`n"
$readOnlyGit = [string[]]@('rev-parse', 'cat-file', 'ls-tree', 'ls-files', 'hash-object', 'log', 'config')   # config는 --get만(gbs-9)

$savedGitEnv = @{}
$gitEnvNames = @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_DIR', 'GIT_WORK_TREE', 'GIT_INDEX_FILE', 'GIT_OBJECT_DIRECTORY', 'GIT_ALTERNATE_OBJECT_DIRECTORIES', 'GIT_COMMON_DIR', 'GIT_NAMESPACE', 'GIT_TRACE2_EVENT')
foreach ($n in $gitEnvNames) { $savedGitEnv[$n] = [Environment]::GetEnvironmentVariable($n) }

try {
    # 다른 저장소를 가리키는 GIT_DIR류는 실행 내내 지운다(실제 대조 포함). 자기 시험 동안만 사용자 설정과 떼어 놓는다.
    foreach ($n in $gitEnvNames) { Set-EnvVar $n $null }
    $gitHome = New-TempDir 'gbs-git-'
    $emptyConfig = Join-Path $gitHome 'gitconfig'
    [IO.File]::WriteAllText($emptyConfig, '', [Text.UTF8Encoding]::new($false))
    Set-EnvVar 'GIT_CONFIG_NOSYSTEM' '1'
    Set-EnvVar 'GIT_CONFIG_GLOBAL' $emptyConfig

    # ---------- 자기 시험 ----------
    Test-Group 'gbs-1' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB } }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB } }
        $mSha = Get-FixtureRev $m 'refs/remotes/origin/main'; $gSha = Get-FixtureRev $g 'refs/remotes/origin/main'
        $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
        $x = @($rep.Results)
        Assert 'gbs-1: identical bases (same names, same bytes) -> PASS sync-pod-a naming 2 entries, no INFO (clean working tree); the report carries both refs/remotes/origin/main commits' (
            $x.Count -eq 1 -and (Test-Same $x[0].Id 'sync-pod-a') -and (Test-Same $x[0].Verdict 'PASS') -and (Test-Has $x[0].Detail '2 entries') -and $null -eq $x[0].Info -and
            (Test-Same $rep.MonoCommit $mSha) -and (Test-Same $rep.GitopsCommit $gSha)
        ) "results: $(Format-Results $x); commits: [$($rep.MonoCommit)] [$($rep.GitopsCommit)] expected [$mSha] [$gSha]"
        $lines = [string[]]@(Format-SyncReport $rep)
        Assert 'gbs-1b: report = the commits line (both full shas, "no fetch") then exactly one line "PASS sync-pod-a: ..."' (
            $lines.Count -eq 2 -and $lines[0].StartsWith('commits: ', [StringComparison]::Ordinal) -and (Test-Has $lines[0] $mSha) -and (Test-Has $lines[0] $gSha) -and
            (Test-Has $lines[0] 'no fetch') -and $lines[1].StartsWith('PASS sync-pod-a: ', [StringComparison]::Ordinal)
        ) "lines: [$($lines -join ' | ')]"
    }

    Test-Group 'gbs-2' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }; 'pod-b' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB } }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }; 'pod-b' = @{ 'a.yaml' = $yA; 'sub/c.yaml' = $yC } }
        $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a', 'pod-b')
        $x = @($rep.Results)
        Assert 'gbs-2: pod by pod in table order -- pod-a PASS; pod-b FAIL naming b.yaml only in the monorepo and sub/c.yaml only in gitops (subdirectories compared recursively), no blob difference' (
            $x.Count -eq 2 -and (Test-Same $x[0].Id 'sync-pod-a') -and (Test-Same $x[0].Verdict 'PASS') -and (Test-Same $x[1].Id 'sync-pod-b') -and (Test-Same $x[1].Verdict 'FAIL') -and
            (Test-Has $x[1].Detail 'only in monorepo apps/pod-b/deploy/base: b.yaml') -and (Test-Has $x[1].Detail 'only in gitops apps/pod-b/base: sub/c.yaml') -and
            -not (Test-Has $x[1].Detail 'blob differs')
        ) "results: $(Format-Results $x)"
        $lines = [string[]]@(Format-SyncReport $rep)
        Assert 'gbs-2b: report = commits, "PASS sync-pod-a: ...", "FAIL sync-pod-b: ..." (one verdict line per pod)' (
            $lines.Count -eq 3 -and $lines[0].StartsWith('commits: ', [StringComparison]::Ordinal) -and $lines[1].StartsWith('PASS sync-pod-a: ', [StringComparison]::Ordinal) -and
            $lines[2].StartsWith('FAIL sync-pod-b: ', [StringComparison]::Ordinal)
        ) "lines: [$($lines -join ' | ')]"
    }

    Test-Group 'gbs-3' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB } }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB.Replace("`n", "`r`n") } }
        $idM = Get-FixtureRev $m 'refs/remotes/origin/main:apps/pod-a/deploy/base/b.yaml'
        $idG = Get-FixtureRev $g 'refs/remotes/origin/main:apps/pod-a/base/b.yaml'
        $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
        $x = @($rep.Results)
        Assert 'gbs-3: same names but b.yaml differs only in line endings (CRLF in gitops -- not a byte copy) -> FAIL naming b.yaml with both short blob ids; no name difference, a.yaml not named' (
            -not (Test-Same $idM $idG) -and $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and
            (Test-Has $x[0].Detail "blob differs: b.yaml (monorepo $($idM.Substring(0, 7)), gitops $($idG.Substring(0, 7)))") -and
            -not (Test-Has $x[0].Detail 'only in') -and -not (Test-Has $x[0].Detail 'a.yaml')
        ) "results: $(Format-Results $x); blobs: [$idM] [$idG]"
    }

    Test-Group 'gbs-4' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $absent = Join-Path (New-TempDir 'gbs-parent-') 'platform-gitops'
        $trace = Join-Path (New-TempDir 'gbs-trace-') 'trace2.json'
        $rep = Invoke-Traced $trace { Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $absent -GitopsDisplay '../platform-gitops' -Pods @('pod-a') }
        $calls = @(Get-TraceCalls $trace)
        $toGitops = @($calls | Where-Object { Test-SamePath $_.dir $absent })
        $x = @($rep.Results)
        $lines = [string[]]@(Format-SyncReport $rep)
        Assert 'gbs-4: sibling clone directory absent -> SKIP sync-pod-a "not found: ../platform-gitops (sibling clone)" (not FAIL), no git call against that path, the commits line says the clone was not found' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'SKIP') -and (Test-Same $x[0].Detail 'not found: ../platform-gitops (sibling clone)') -and $null -eq $rep.GitopsCommit -and
            $calls.Count -ge 1 -and $toGitops.Count -eq 0 -and $lines.Count -eq 2 -and (Test-Has $lines[0] 'sibling clone not found') -and
            (Test-Same $lines[1] 'SKIP sync-pod-a: not found: ../platform-gitops (sibling clone)')
        ) "results: $(Format-Results $x); git calls: $($calls.Count), against the absent path: $($toGitops.Count); lines: [$($lines -join ' | ')]"
    }

    Test-Group 'gbs-5' {
        $base = @{ 'a.yaml' = $yA; 'b.yaml' = $yB; 'c.yaml' = $yC }
        $m = New-MonoFixture @{ 'pod-a' = $base } @{ '.gitattributes' = "* text=auto eol=lf`n"; '.gitignore' = "*.tmp`n" }
        $g = New-GitopsFixture @{ 'pod-a' = $base }
        Write-Files $m @{
            'apps/pod-a/deploy/base/a.yaml' = $yA + "# changed`n"
            'apps/pod-a/deploy/base/b.yaml' = $null
            'apps/pod-a/deploy/base/c.yaml' = $yC.Replace("`n", "`r`n")
            'apps/pod-a/deploy/base/n.yaml' = $yB
            'apps/pod-a/deploy/base/x.tmp'  = "scratch`n"
        }
        $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
        $x = @($rep.Results)
        Assert 'gbs-5: monorepo working tree != monorepo origin/main (changed a.yaml, removed b.yaml, new untracked n.yaml) while both origin/main bases match -> PASS plus INFO 발행 대기 naming exactly those three; a CRLF copy of c.yaml (eol=lf: git add makes the same blob) and the ignored x.tmp are not listed' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'PASS') -and (Test-Has $x[0].Info '발행 대기') -and (Test-Has $x[0].Info 'changed: a.yaml;') -and
            (Test-Has $x[0].Info 'new: n.yaml;') -and (Test-Has $x[0].Info 'removed: b.yaml)') -and -not (Test-Has $x[0].Info 'c.yaml') -and -not (Test-Has $x[0].Info 'x.tmp')
        ) "results: $(Format-Results $x)"
        $lines = [string[]]@(Format-SyncReport $rep)
        Assert 'gbs-5b: report = commits, "PASS sync-pod-a: ...", "INFO sync-pod-a: 발행 대기 ..." -- no FAIL line' (
            $lines.Count -eq 3 -and $lines[1].StartsWith('PASS sync-pod-a: ', [StringComparison]::Ordinal) -and $lines[2].StartsWith('INFO sync-pod-a: 발행 대기', [StringComparison]::Ordinal) -and
            @($lines | Where-Object { $_.StartsWith('FAIL ', [StringComparison]::Ordinal) }).Count -eq 0
        ) "lines: [$($lines -join ' | ')]"
    }

    Test-Group 'gbs-6' {
        $base = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }
        $m = New-MonoFixture @{ 'pod-a' = $base }
        $g = New-GitopsFixture @{ 'pod-a' = $base }
        $mOrigin = Get-FixtureRev $m 'refs/remotes/origin/main'; $gOrigin = Get-FixtureRev $g 'refs/remotes/origin/main'
        # 모노레포: origin/main보다 앞선 로컬 커밋(a.yaml) · gitops: 다른 브랜치를 체크아웃해 커밋(b.yaml) + 커밋하지 않은 변경(a.yaml)
        Write-Files $m @{ 'apps/pod-a/deploy/base/a.yaml' = $yA + "# local commit`n" }
        Save-FixtureCommit $m 'local ahead of origin/main'
        [void](Invoke-FixtureGit $g @('checkout', '-q', '-b', 'local'))
        Write-Files $g @{ 'apps/pod-a/base/b.yaml' = $yB + "# local branch`n" }
        Save-FixtureCommit $g 'local branch'
        Write-Files $g @{ 'apps/pod-a/base/a.yaml' = $yA + "# dirty`n" }
        $mHead = Get-FixtureRev $m 'HEAD'; $gHead = Get-FixtureRev $g 'HEAD'
        $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
        $x = @($rep.Results)
        Assert 'gbs-6: only refs/remotes/origin/main counts on both sides -- a monorepo commit ahead of origin/main and a gitops checkout of another branch with a dirty working tree still PASS; the reported commits are the origin/main ones (not HEAD); the monorepo change shows as INFO 발행 대기 (changed: a.yaml)' (
            -not (Test-Same $mHead $mOrigin) -and -not (Test-Same $gHead $gOrigin) -and $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'PASS') -and
            (Test-Same $rep.MonoCommit $mOrigin) -and (Test-Same $rep.GitopsCommit $gOrigin) -and (Test-Has $x[0].Info '발행 대기') -and (Test-Has $x[0].Info 'changed: a.yaml')
        ) "results: $(Format-Results $x); commits: [$($rep.MonoCommit)] [$($rep.GitopsCommit)]; origin/main: [$mOrigin] [$gOrigin]; HEAD: [$mHead] [$gHead]"
    }

    Test-Group 'gbs-7' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $gNoOrigin = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } } -NoOrigin
        $gPlain = New-TempDir 'gbs-gitops-plain-'
        Write-Files $gPlain @{ 'apps/pod-a/base/a.yaml' = $yA }
        $gFile = Join-Path (New-TempDir 'gbs-parent-') 'platform-gitops'
        [IO.File]::WriteAllText($gFile, "not a directory`n", [Text.UTF8Encoding]::new($false))
        $mNoOrigin = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } } -NoOrigin
        $gOk = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $absent = Join-Path (New-TempDir 'gbs-parent-') 'platform-gitops'
        $r1 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gNoOrigin -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r2 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gPlain -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r3 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gFile -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r4 = @((Invoke-GitopsBaseSync -MonoRoot $mNoOrigin -GitopsRoot $gOk -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r5 = @((Invoke-GitopsBaseSync -MonoRoot $mNoOrigin -GitopsRoot $absent -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-7: a gitops repository without refs/remotes/origin/main -> FAIL naming the missing ref and that nothing is fetched (not SKIP)' (
            $r1.Count -eq 1 -and (Test-Same $r1[0].Verdict 'FAIL') -and (Test-Has $r1[0].Detail 'gitops fixture-gitops: refs/remotes/origin/main not found') -and (Test-Has $r1[0].Detail 'never fetches')
        ) "results: $(Format-Results $r1)"
        Assert 'gbs-7b: a directory that is not the top of a git work tree -> FAIL (not SKIP)' (
            $r2.Count -eq 1 -and (Test-Same $r2[0].Verdict 'FAIL') -and (Test-Has $r2[0].Detail 'gitops fixture-gitops: not the top of a git work tree')
        ) "results: $(Format-Results $r2)"
        Assert 'gbs-7c: a file at the sibling clone path -> FAIL "exists but is not a directory" (not SKIP)' (
            $r3.Count -eq 1 -and (Test-Same $r3[0].Verdict 'FAIL') -and (Test-Has $r3[0].Detail 'gitops fixture-gitops: exists but is not a directory')
        ) "results: $(Format-Results $r3)"
        Assert 'gbs-7d: monorepo without refs/remotes/origin/main -> FAIL, with the gitops clone present and also with it absent (SKIP needs the monorepo side to resolve)' (
            $r4.Count -eq 1 -and (Test-Same $r4[0].Verdict 'FAIL') -and (Test-Has $r4[0].Detail 'monorepo: refs/remotes/origin/main not found') -and
            $r5.Count -eq 1 -and (Test-Same $r5[0].Verdict 'FAIL') -and (Test-Has $r5[0].Detail 'monorepo: refs/remotes/origin/main not found')
        ) "present: $(Format-Results $r4) ;; absent: $(Format-Results $r5)"
    }

    Test-Group 'gbs-8' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $gNoBase = New-GitopsFixture @{}
        $gFileBase = New-GitopsFixture @{} @{ 'apps/pod-a/base' = "not a directory`n" }
        $mNoBase = New-MonoFixture @{} @{ 'apps/pod-a/README.md' = "no deploy/base`n" }
        $gOk = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $r1 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gNoBase -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r2 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gFileBase -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $r3 = @((Invoke-GitopsBaseSync -MonoRoot $mNoBase -GitopsRoot $gOk -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-8: gitops origin/main without apps/pod-a/base -> FAIL "apps/pod-a/base absent in gitops origin/main"' (
            $r1.Count -eq 1 -and (Test-Same $r1[0].Verdict 'FAIL') -and (Test-Has $r1[0].Detail 'apps/pod-a/base absent in gitops origin/main')
        ) "results: $(Format-Results $r1)"
        Assert 'gbs-8b: gitops apps/pod-a/base is a file -> FAIL "is a blob in gitops origin/main ... (expected a directory)"' (
            $r2.Count -eq 1 -and (Test-Same $r2[0].Verdict 'FAIL') -and (Test-Has $r2[0].Detail 'apps/pod-a/base is a blob in gitops origin/main') -and (Test-Has $r2[0].Detail '(expected a directory)')
        ) "results: $(Format-Results $r2)"
        Assert 'gbs-8c: monorepo origin/main without apps/pod-a/deploy/base -> FAIL "absent in monorepo origin/main" and no INFO' (
            $r3.Count -eq 1 -and (Test-Same $r3[0].Verdict 'FAIL') -and (Test-Has $r3[0].Detail 'apps/pod-a/deploy/base absent in monorepo origin/main') -and $null -eq $r3[0].Info
        ) "results: $(Format-Results $r3)"
    }

    Test-Group 'gbs-9' {
        $base = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }
        $m = New-MonoFixture @{ 'pod-a' = $base; 'pod-b' = $base }
        $g = New-GitopsFixture @{ 'pod-a' = $base; 'pod-b' = @{ 'a.yaml' = $yA } }
        Write-Files $m @{ 'apps/pod-a/deploy/base/a.yaml' = $yA + "# changed`n"; 'apps/pod-a/deploy/base/n.yaml' = $yC }
        $before = @((Get-GitDirSnapshot $m), (Get-GitDirSnapshot $g))
        $trace = Join-Path (New-TempDir 'gbs-trace-') 'trace2.json'
        $rep = Invoke-Traced $trace { Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a', 'pod-b') }
        $after = @((Get-GitDirSnapshot $m), (Get-GitDirSnapshot $g))
        $calls = @(Get-TraceCalls $trace)
        $x = @($rep.Results)
        $badSub = @($calls | Where-Object { -not (Test-InList $readOnlyGit $_.sub) })
        $badDir = @($calls | Where-Object { -not ((Test-SamePath $_.dir $m) -or (Test-SamePath $_.dir $g)) })
        $noLock = @($calls | Where-Object { -not (Test-InList $_.opts '--no-optional-locks') })
        $noReplace = @($calls | Where-Object { -not (Test-InList $_.opts '--no-replace-objects') })
        $configCalls = @($calls | Where-Object { Test-Same $_.sub 'config' })
        $configKeys = [string[]]@('remote.origin.url', 'extensions.partialclone', 'remote.origin.promisor')
        $badConfig = @($configCalls | Where-Object { -not (@($_.rest).Count -eq 2 -and (Test-Same $_.rest[0] '--get') -and (Test-InList $configKeys $_.rest[1])) })
        $askedKeys = [string[]]@($configCalls | Where-Object { (Test-SamePath $_.dir $g) -and @($_.rest).Count -eq 2 } | ForEach-Object { [string]$_.rest[1] })
        $missingKeys = @($configKeys | Where-Object { -not (Test-InList $askedKeys $_) })
        $gitopsCalls = @($calls | Where-Object { Test-SamePath $_.dir $g })
        Assert 'gbs-9: every git process of a run (PASS + INFO + FAIL paths) is a read-only subcommand (rev-parse, cat-file, ls-tree, ls-files, hash-object, log, config --get of remote.origin.url / extensions.partialclone / remote.origin.promisor only -- all three asked of the sibling clone; no fetch), runs with -C <one of the two repositories> and carries --no-optional-locks and --no-replace-objects before the subcommand' (
            $x.Count -eq 2 -and (Test-Same $x[0].Verdict 'PASS') -and $null -ne $x[0].Info -and (Test-Same $x[1].Verdict 'FAIL') -and
            $calls.Count -ge 6 -and $gitopsCalls.Count -ge 2 -and $configCalls.Count -ge 3 -and $badSub.Count -eq 0 -and $badDir.Count -eq 0 -and
            $noLock.Count -eq 0 -and $noReplace.Count -eq 0 -and $badConfig.Count -eq 0 -and $missingKeys.Count -eq 0
        ) "results: $(Format-Results $x); calls: $($calls.Count) (gitops $($gitopsCalls.Count), config $($configCalls.Count)); not read-only: [$(@($badSub | ForEach-Object { $_.sub }) -join ', ')]; other -C: $($badDir.Count); without --no-optional-locks: [$(@($noLock | ForEach-Object { $_.sub }) -join ', ')]; without --no-replace-objects: [$(@($noReplace | ForEach-Object { $_.sub }) -join ', ')]; config other than --get of the three keys: $($badConfig.Count); keys not asked of the sibling: [$($missingKeys -join ', ')]"
        Assert 'gbs-9b: both .git directories are unchanged by the run (file list, sizes and write times -- no index refresh, no objects, no FETCH_HEAD)' (
            (Test-Same $before[0] $after[0]) -and (Test-Same $before[1] $after[1]) -and $before[0].Length -gt 0
        ) "monorepo .git same: $(Test-Same $before[0] $after[0]); gitops .git same: $(Test-Same $before[1] $after[1])"
    }

    # ---------- 수정 라운드 1(리뷰 B RB-3 · RB-4 · RB-5 · nit N1 · N3) ----------
    Test-Group 'gbs-10' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $sub = Join-Path $g 'apps'
        $rTop = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        $rSub = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $sub -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-10: the sibling path is a subfolder of another work tree (git rev-parse --show-cdup not empty) -> FAIL "not the top of a git work tree" even though the enclosing repository would match (control: its top PASSes)' (
            $rTop.Count -eq 1 -and (Test-Same $rTop[0].Verdict 'PASS') -and $rSub.Count -eq 1 -and (Test-Same $rSub[0].Verdict 'FAIL') -and
            (Test-Has $rSub[0].Detail 'gitops fixture-gitops: not the top of a git work tree (the enclosing work tree starts at ../)')
        ) "top: $(Format-Results $rTop) ;; subfolder: $(Format-Results $rSub)"
    }

    Test-Group 'gbs-11' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB } }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'A.yaml' = $yA; 'b.yaml' = $yB } }
        $x = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-11: names that differ only in letter case (a.yaml vs A.yaml, same bytes) -> FAIL naming each as only on its side (names compare ordinal, as git trees and Linux checkouts do)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail 'only in monorepo apps/pod-a/deploy/base: a.yaml') -and
            (Test-Has $x[0].Detail 'only in gitops apps/pod-a/base: A.yaml')
        ) "results: $(Format-Results $x)"
    }

    Test-Group 'gbs-12' {
        $mixed = @(
            [pscustomobject]@{ Id = 'sync-a'; Verdict = 'PASS' }, [pscustomobject]@{ Id = 'sync-b'; Verdict = 'SKIP' },
            [pscustomobject]@{ Id = 'sync-c'; Verdict = 'FAIL' }, [pscustomobject]@{ Id = 'sync-d'; Verdict = 'pass' }
        )
        $t = Measure-SyncResults $mixed
        Assert 'gbs-12: tally of the real comparison -- PASS counts as passed, SKIP is listed apart and never counted as passed, FAIL and any other verdict (lowercase "pass" included) count as failed' (
            $t.pass -eq 1 -and $t.fail -eq 2 -and (Test-Same (@($t.skips) -join ',') 'sync-b') -and (Test-Same (@($t.failed) -join ',') 'sync-c,sync-d')
        ) "pass $($t.pass) fail $($t.fail) skips [$(@($t.skips) -join ',')] failed [$(@($t.failed) -join ',')]"
        $only = Measure-SyncResults @([pscustomobject]@{ Id = 'sync-x'; Verdict = 'SKIP' })
        $text = (@(Format-SyncSummary (18 + $only.pass) $only.fail @($only.skips) @($only.failed) '') -join "`n")
        $failText = (@(Format-SyncSummary 18 1 @() @('sync-y') '') -join "`n")
        $note = [regex]::Match($text, '(?m)^(\d+) skipped\b')
        Assert 'gbs-12b: summary lines -- a SKIP-only real comparison still ends "18 passed, 0 failed" (run-all 1b7 PASS regex) with a separate "1 skipped (not counted as passed): sync-x" line (run-all NOTE regex); a FAIL prints "failed: <id>" before "18 passed, 1 failed"' (
            $only.pass -eq 0 -and [regex]::IsMatch($text, '(?m)^18 passed, 0 failed\r?$') -and $note.Success -and (Test-Same $note.Groups[1].Value '1') -and
            (Test-Has $text '1 skipped (not counted as passed): sync-x') -and [regex]::IsMatch($failText, '(?m)^failed: sync-y\r?\n18 passed, 1 failed\r?$')
        ) "skip-only: [$($text.Replace("`n", ' | '))] ;; fail: [$($failText.Replace("`n", ' | '))]"
    }

    Test-Group 'gbs-13' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $fake = 'tok' + [guid]::NewGuid().ToString('N').Substring(0, 16)
        $cases = [ordered]@{
            'scp form'               = @{ remote = 'git@github.com:joshua92y/platform-gitops.git'; want = 'PASS' }
            'https without .git'     = @{ remote = 'https://github.com/joshua92y/platform-gitops'; want = 'PASS' }
            'https with user info'   = @{ remote = "https://x-access-token:$fake@github.com/joshua92y/platform-gitops.git"; want = 'PASS' }
            'ssh url'                = @{ remote = 'ssh://git@github.com/joshua92y/platform-gitops.git'; want = 'PASS' }
            'host letter case'       = @{ remote = 'https://GitHub.com/joshua92y/platform-gitops.git'; want = 'PASS' }
            'trailing slash'         = @{ remote = 'https://github.com/joshua92y/platform-gitops/'; want = 'PASS' }
            'another repository'     = @{ remote = "https://user:$fake@example.invalid/someone/platform-gitops-fork.git"; want = 'FAIL'; has = 'remote.origin.url is not' }
            'suffix after .git'      = @{ remote = 'https://github.com/joshua92y/platform-gitops.git.evil'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'no origin url'          = @{ remote = ''; want = 'FAIL'; has = 'remote.origin.url is not set' }
            'other host https'       = @{ remote = 'https://example.invalid/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'local path'             = @{ remote = 'D:/mirror/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'file url'               = @{ remote = 'file:///D:/mirror/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'owner letter case'      = @{ remote = 'https://github.com/Joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'github host in a path'  = @{ remote = 'https://example.invalid/github.com/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            # 권한부가 @ 앞의 # · ? · \에서 끝나면 실제 접속 호스트는 example.invalid다(리뷰 정규식의 [^@/]+는 이 셋을 통과시킨다)
            'fragment before @'      = @{ remote = 'https://example.invalid#@github.com/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'query before @'         = @{ remote = 'https://example.invalid?@github.com/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
            'backslash before @'     = @{ remote = 'https://example.invalid\@github.com/joshua92y/platform-gitops.git'; want = 'FAIL'; has = 'remote.origin.url is not' }
        }
        $bad = @()
        foreach ($name in $cases.Keys) {
            $c = $cases[$name]
            $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } } -Remote $c.remote
            $rep = Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
            $x = @($rep.Results)
            $lines = (@(Format-SyncReport $rep) -join "`n")
            $ok = $x.Count -eq 1 -and (Test-Same $x[0].Verdict $c.want) -and ($null -eq $c.has -or (Test-Has $x[0].Detail $c.has)) -and
                -not (Test-Has $lines $fake) -and -not (Test-Has $lines 'example.invalid') -and -not (Test-Has $lines 'mirror/') -and
                -not (Test-Has $lines 'joshua92y/platform-gitops.git.evil')
            if (-not $ok) { $bad += "${name}: $(Format-Results $x)" }
        }
        Assert "gbs-13: the sibling clone must be github.com/joshua92y/platform-gitops ($($cases.Count) remote.origin.url forms) -- https (user info allowed), scp and ssh:// on github.com (host in any letter case, owner and repository exact, optional .git and trailing /) PASS; another host, a local path, file://, github.com only inside a path or after a # ? \ that ends the authority, another owner case, a suffix after .git or no origin URL -> FAIL; the URL itself is never printed (a credential in it stays out of the output)" ($bad.Count -eq 0) ($bad -join ' ;; ')
    }

    Test-Group 'gbs-14' {
        $parent = New-TempDir 'gbs-sib-'
        $main = Join-Path $parent 'mono'
        [void][IO.Directory]::CreateDirectory($main)
        [void](Invoke-FixtureGit $main @('init', '-q', '-b', 'main'))
        Write-Files $main @{ 'README.md' = "main checkout`n" }
        Save-FixtureCommit $main 'main'
        $wt = Join-Path $main '.worktrees/w1'
        [void](Invoke-FixtureGit $main @('worktree', 'add', '-q', $wt, '-b', 'w1'))
        $plain = New-TempDir 'gbs-plain-'
        $want = Join-Path $parent 'platform-gitops'
        $r1 = Resolve-SiblingClone $main 'platform-gitops'
        $r2 = Resolve-SiblingClone $wt 'platform-gitops'
        $r3 = Resolve-SiblingClone $plain 'platform-gitops'
        Assert 'gbs-14: the sibling clone is resolved from the main checkout (git rev-parse --path-format=absolute --git-common-dir) -- from the main checkout and from a linked worktree under .worktrees/ both give <parent of the main checkout>/platform-gitops; a directory outside any repository -> error (fail closed, never SKIP)' (
            $null -eq $r1.error -and (Test-SamePath $r1.path $want) -and $null -eq $r2.error -and (Test-SamePath $r2.path $want) -and
            $null -ne $r3.error -and (Test-Has $r3.error 'cannot locate the main checkout')
        ) "main: [$($r1.path)] err [$($r1.error)]; worktree: [$($r2.path)] err [$($r2.error)]; plain: err [$($r3.error)]; want [$want]"
        # 수정 라운드 2 RB2-3: 공통 git 디렉터리가 <체크아웃>/.git이 아닌 저장소(git init --separate-git-dir) — 주 체크아웃을 알 수 없다
        $sepParent = New-TempDir 'gbs-sep-'
        $sepTree = Join-Path $sepParent 'tree'
        $sepGit = Join-Path $sepParent 'store/tree.git'
        [void][IO.Directory]::CreateDirectory((Join-Path $sepParent 'store'))   # git은 --separate-git-dir의 부모를 만들지 않는다
        [void](Invoke-FixtureGit $sepParent @('init', '-q', '-b', 'main', "--separate-git-dir=$sepGit", $sepTree))
        $r4 = Resolve-SiblingClone $sepTree 'platform-gitops'
        Assert 'gbs-14b: a repository whose common git directory is not <checkout>/.git (git init --separate-git-dir) -> error "the common git directory is not <checkout>/.git", no path (never a guessed sibling)' (
            $null -ne $r4.error -and (Test-Has $r4.error 'the common git directory is not <checkout>/.git') -and $null -eq $r4.path
        ) "separate git dir: path [$($r4.path)] err [$($r4.error)]"
        # 형제 자리를 풀지 못한 사유가 있으면 경로를 보지 않고 그 사유로 FAIL이다(없는 경로여도 SKIP이 아니다)
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $absent = Join-Path (New-TempDir 'gbs-parent-') 'platform-gitops'
        $reason = 'monorepo: cannot locate the main checkout (fixture reason)'
        $x = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $absent -GitopsDisplay 'fixture-gitops' -Pods @('pod-a') -GitopsLocateError $reason).Results)
        Assert 'gbs-14c: a sibling-locate error with an absent sibling path -> FAIL carrying that reason, not SKIP (the error wins over the path test)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail $reason)
        ) "results: $(Format-Results $x)"
    }

    Test-Group 'gbs-15' {
        $base = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }
        $m = New-MonoFixture @{ 'pod-a' = $base }
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA; 'b.yaml' = $yB + "# drift`n" } }
        $drift = Get-FixtureRev $g 'refs/remotes/origin/main'
        # 맞는 base를 담은 다른 커밋을 만들고 replace ref로 origin/main 커밋을 그 커밋으로 바꿔 보이게 한다(리뷰 B P2 재현)
        Write-Files $g @{ 'apps/pod-a/base/b.yaml' = $yB }
        Save-FixtureCommit $g 'matching base'
        $match = Get-FixtureRev $g 'HEAD'
        [void](Invoke-FixtureGit $g @('replace', $drift, $match))
        $monoBlob = Get-FixtureRev $m 'refs/remotes/origin/main:apps/pod-a/deploy/base/b.yaml'
        $seenPlain = Get-FixtureRev $g "${drift}:apps/pod-a/base/b.yaml"
        $seenRaw = Invoke-FixtureGit $g @('--no-replace-objects', 'rev-parse', "${drift}:apps/pod-a/base/b.yaml")
        $x = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-15: a replace ref that makes the drifted gitops origin/main look like the monorepo base (control: plain git sees the monorepo blob) -> still FAIL "blob differs: b.yaml" (every call runs with --no-replace-objects)' (
            (Test-Same $seenPlain $monoBlob) -and -not (Test-Same $seenRaw $monoBlob) -and $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail 'blob differs: b.yaml')
        ) "results: $(Format-Results $x); plain git sees [$seenPlain], raw [$seenRaw], monorepo [$monoBlob]"
    }

    Test-Group 'gbs-16' {
        $fakeDir = New-TempDir 'gbs-fakegit-'
        $marker = 'gbs-hang-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
        $echo = Join-Path $fakeDir 'echo-git.cmd'
        [IO.File]::WriteAllText($echo, "@echo off`r`necho %GIT_NO_LAZY_FETCH%:%GIT_TERMINAL_PROMPT%:%*`r`n", [Text.Encoding]::ASCII)
        $hang = Join-Path $fakeDir 'hang-git.cmd'
        [IO.File]::WriteAllText($hang, "@echo off`r`npwsh -NoProfile -Command ""Start-Sleep -Seconds 8 # $marker""`r`n", [Text.Encoding]::ASCII)
        $dirA = New-TempDir 'gbs-hangA-'; $dirB = New-TempDir 'gbs-hangB-'
        $savedExe = $script:gitExe; $savedMs = $script:gitTimeoutMs
        $savedPrompt = [Environment]::GetEnvironmentVariable('GIT_TERMINAL_PROMPT'); $savedLazy = [Environment]::GetEnvironmentVariable('GIT_NO_LAZY_FETCH')
        try {
            # 부모 env에 반대 값을 둔다 — 자식 값은 Invoke-GitRead가 직접 둔 것이어야 한다(이 PC의 셸은 GIT_TERMINAL_PROMPT=0을 이미 내보낸다 — 변이 M11)
            Set-EnvVar 'GIT_TERMINAL_PROMPT' '1'; Set-EnvVar 'GIT_NO_LAZY_FETCH' '0'
            $script:gitExe = $echo
            $e = Invoke-GitRead 'C:\gbs-fake' @('rev-parse', '--show-cdup')
            Set-EnvVar 'GIT_TERMINAL_PROMPT' $savedPrompt; Set-EnvVar 'GIT_NO_LAZY_FETCH' $savedLazy
            $script:gitExe = $hang; $script:gitTimeoutMs = 2000
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $x = @((Invoke-GitopsBaseSync -MonoRoot $dirA -GitopsRoot $dirB -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
            $elapsed = $sw.Elapsed.TotalSeconds
        } finally {
            $script:gitExe = $savedExe; $script:gitTimeoutMs = $savedMs
            Set-EnvVar 'GIT_TERMINAL_PROMPT' $savedPrompt; Set-EnvVar 'GIT_NO_LAZY_FETCH' $savedLazy
        }
        Start-Sleep -Milliseconds 300
        $left = @(Get-CimInstance -ClassName Win32_Process | Where-Object { "$($_.CommandLine)" -like "*$marker*" })
        Assert 'gbs-16: every git process runs with GIT_NO_LAZY_FETCH=1 and GIT_TERMINAL_PROMPT=0 set by the harness (the parent env holds the opposite values during the call) and "-C <dir> --no-optional-locks --no-replace-objects" before the subcommand (fake git that echoes them)' (
            $e.code -eq 0 -and (Test-Same $e.out.Trim() '1:0:-C C:\gbs-fake --no-optional-locks --no-replace-objects rev-parse --show-cdup')
        ) "fake git printed [$($e.out.Trim())] exit $($e.code)"
        Assert 'gbs-16b: a git call that does not finish within the per-call limit is killed with its process tree and the pod FAILs naming the timeout (fake git that sleeps 8 s, limit 2 s -- two calls, under 7.5 s in all)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail 'timed out after 2 s') -and $elapsed -lt 7.5 -and $left.Count -eq 0
        ) "results: $(Format-Results $x); elapsed $([Math]::Round($elapsed, 1)) s; processes left with the marker: $($left.Count)"
    }

    Test-Group 'gbs-17' {
        $base = @{ 'a.yaml' = $yA; 'b.yaml' = $yB }
        $m = New-MonoFixture @{ 'pod-a' = $base }
        $g = New-GitopsFixture @{ 'pod-a' = $base } -NoOrigin
        [void](Invoke-FixtureGit $g @('update-index', '--chmod=+x', 'apps/pod-a/base/b.yaml'))
        Save-FixtureCommit $g 'b.yaml executable'
        [void](Invoke-FixtureGit $g @('update-ref', 'refs/remotes/origin/main', 'HEAD'))
        $x = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-17: same names and blob ids but b.yaml is 100755 in gitops -> FAIL "mode differs: b.yaml (monorepo 100644, gitops 100755)" (the copy is exact, mode included)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail 'mode differs: b.yaml (monorepo 100644, gitops 100755)') -and -not (Test-Has $x[0].Detail 'blob differs')
        ) "results: $(Format-Results $x)"
    }

    Test-Group 'gbs-18' {
        $m = New-MonoFixture @{} -NoOrigin
        Set-EmptyBaseOrigin $m @('apps', 'pod-a', 'deploy', 'base')
        $g = New-GitopsFixture @{} -NoOrigin
        Set-EmptyBaseOrigin $g @('apps', 'pod-a', 'base')
        $x = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-18: both bases are empty trees (same names, trivially) -> FAIL "no entries" (PASS needs at least one entry)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail 'no entries under apps/pod-a/deploy/base')
        ) "results: $(Format-Results $x)"
    }

    Test-Group 'gbs-19' {
        $absentMono = Join-Path ([Environment]::GetFolderPath('UserProfile')) ('gbs-absent-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
        $g = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $rep = Invoke-GitopsBaseSync -MonoRoot $absentMono -GitopsRoot $g -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')
        $x = @($rep.Results)
        $lines = (@(Format-SyncReport $rep) -join "`n")
        $masked = Hide-Home ("fatal: at '" + [Environment]::GetFolderPath('UserProfile').Replace('\', '/') + "/x' and " + [Environment]::GetFolderPath('UserProfile').ToUpperInvariant() + '\y')
        Assert 'gbs-19: a git error that quotes a path under the user home (a monorepo path that does not exist) -> FAIL whose detail shows the path as ~/... and never the home directory itself (either separator, any letter case)' (
            $x.Count -eq 1 -and (Test-Same $x[0].Verdict 'FAIL') -and (Test-Has $x[0].Detail '~') -and (Test-Has $x[0].Detail 'gbs-absent-') -and -not (Test-HasHome $lines) -and
            (Test-Same $masked "fatal: at '~/x' and ~\y")
        ) "detail: [$($x[0].Detail)]; masked sample: [$masked]"
    }

    # 수정 라운드 2(덤): 형제 클론이 부분 클론이면 객체를 읽다가 지연 fetch할 수 있다 — git 판(GIT_NO_LAZY_FETCH는 2.44+)과 무관하게 FAIL
    Test-Group 'gbs-20' {
        $m = New-MonoFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        $gPartial = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        [void](Invoke-FixtureGit $gPartial @('config', 'core.repositoryformatversion', '1'))
        [void](Invoke-FixtureGit $gPartial @('config', 'extensions.partialclone', 'origin'))
        $gPromisor = New-GitopsFixture @{ 'pod-a' = @{ 'a.yaml' = $yA } }
        [void](Invoke-FixtureGit $gPromisor @('config', 'remote.origin.promisor', 'true'))
        $trace = Join-Path (New-TempDir 'gbs-trace-') 'trace2.json'
        $x1 = @((Invoke-Traced $trace { Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gPartial -GitopsDisplay 'fixture-gitops' -Pods @('pod-a') }).Results)
        # 추적이 그 클론의 호출을 실제로 담았는지 먼저 본다(추적이 비면 「트리 읽기 0」이 거저 참이 된다)
        $partialCalls = @(@(Get-TraceCalls $trace) | Where-Object { Test-SamePath $_.dir $gPartial })
        $treeReads = @($partialCalls | Where-Object { (Test-Same $_.sub 'cat-file') -or (Test-Same $_.sub 'ls-tree') })
        $askedPartial = @($partialCalls | Where-Object { (Test-Same $_.sub 'config') -and @($_.rest).Count -eq 2 -and (Test-Same $_.rest[1] 'extensions.partialclone') })
        $x2 = @((Invoke-GitopsBaseSync -MonoRoot $m -GitopsRoot $gPromisor -GitopsDisplay 'fixture-gitops' -Pods @('pod-a')).Results)
        Assert 'gbs-20: a partial-clone sibling (extensions.partialclone, or remote.origin.promisor) -> FAIL "partial clone" before any tree object of it is read (no lazy fetch whatever the git version; the trace holds that clone''s calls, config --get extensions.partialclone among them)' (
            $x1.Count -eq 1 -and (Test-Same $x1[0].Verdict 'FAIL') -and (Test-Has $x1[0].Detail 'partial clone') -and $partialCalls.Count -ge 3 -and
            $askedPartial.Count -eq 1 -and $treeReads.Count -eq 0 -and
            $x2.Count -eq 1 -and (Test-Same $x2[0].Verdict 'FAIL') -and (Test-Has $x2[0].Detail 'partial clone')
        ) "extensions.partialclone: $(Format-Results $x1) (traced calls on it: $($partialCalls.Count), config --get extensions.partialclone: $($askedPartial.Count), tree reads: $($treeReads.Count)) ;; remote.origin.promisor: $(Format-Results $x2)"
    }
} finally {
    foreach ($n in $gitEnvNames) { if ($n -in @('GIT_CONFIG_NOSYSTEM', 'GIT_CONFIG_GLOBAL', 'GIT_TRACE2_EVENT')) { Set-EnvVar $n $savedGitEnv[$n] } }
    foreach ($t in $script:temps) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# ---------- 실제 대조(동기화 표의 pod마다 — 사용자 git 설정 그대로 · GIT_DIR류는 지운 채) ----------
$selectedPods = @($SyncPods | Where-Object { Test-Selected "sync-$_" })
if ($selectedPods.Count -gt 0) {
    Write-Host ''
    Write-Host "-- real comparison: monorepo $(Split-Path -Leaf $repo) <-> $gitopsDisplay (sibling of the main checkout; sync table: $($selectedPods -join ', '))"
    try {
        $sibling = Resolve-SiblingClone $repo 'platform-gitops'
        $report = Invoke-GitopsBaseSync -MonoRoot $repo -GitopsRoot ([string]$sibling.path) -GitopsDisplay $gitopsDisplay -Pods $selectedPods -GitopsLocateError ([string]$sibling.error)
        foreach ($line in @(Format-SyncReport $report)) { Write-Host $line }
        $tally = Measure-SyncResults $report.Results
        $script:pass += $tally.pass; $script:fail += $tally.fail
        foreach ($id in $tally.skips) { $script:skips.Add($id) }
        foreach ($id in $tally.failed) { $script:failedIds.Add($id) }
    } catch {
        $script:fail++; $script:failedIds.Add('sync')
        Write-Host "FAIL sync -- unhandled $($_.Exception.GetType().Name): $(Hide-Home $_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))"
    }
}
foreach ($n in $gitEnvNames) { Set-EnvVar $n $savedGitEnv[$n] }

$suffix = ''
if ($script:only.Count -gt 0) { $suffix += " (filtered: $($script:only -join ','))" }
foreach ($line in @(Format-SyncSummary $script:pass $script:fail $script:skips.ToArray() $script:failedIds.ToArray() $suffix)) { Write-Host $line }
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
