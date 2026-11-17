# scripts/backup-verify.ps1 테스트(T048). Run: pwsh -NoProfile -File tests/scripts/backup-verify.tests.ps1
# Exit 0 = all pass(또는 도구 없음 SKIP), 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/kubeconform-deploy.tests.ps1와 같은 구조).
#
# 진짜 도구로 돈다: age · age-keygen · tar · vault · 파이썬(sqlite3 모듈 — py -3 · python3 · python 순).
#   하나라도 없으면 첫 줄 'SKIP backup-verify tests -- <없는 도구>' + exit 0으로 끝난다(tests/run-all.ps1 1b2b가 그 첫 줄만 SKIP으로 받는다).
#   Windows가 아니어도 같은 SKIP이다 — 가짜 oci · tar 심이 cmd 배치 파일이다.
#   oci만 가짜다 — 픽스처 bin의 oci.cmd 심(PATH 맨 앞)이 시나리오 JSON대로 답하고 받은 인자를 기록한다.
#   실제 버킷 · 실제 개인키 · 실제 OCI 세션 · 클러스터에 닿지 않는다. 로컬 Vault 서버도 띄우지 않는다(커밋된 견본 스냅샷을 쓴다).
#   스크립트 부재 · 견본 스냅샷 부재는 SKIP이 아니다 — 단언이 전부 FAIL한다(fail closed).
# 픽스처(실행마다 사용자 임시 디렉터리의 bvtest-<guid>에 새로 만들고 끝에 지운다 — 저장소에는 견본 스냅샷과 README뿐):
#   일회용 age 키쌍 둘(age-keygen) · 파이썬이 만든 WAL 모드 SQLite(kine 테이블 400행을 넣고 앞 50행을 지움 — count 350 · max(id) 400,
#   인덱스 둘 — 노드의 sqlite3 .backup 사본과 같은 모양) · 파이썬 tarfile로 만든 번들(server/db/state.db · server/token · server/cred/* ·
#   server/tls/*과 그 변형 — 별칭 이름 · 중복 · 링크 · 0바이트)을 age로 암호화한 것 · 견본 Vault 스냅샷(tests/scripts/fixtures/backup-verify/
#   vault-mock.snap)을 암호화한 것. 더미 토큰 · 인증서 · DB 값에는 표식 문자열(BVTEST-…-MARKER)을, 번들 항목 이름에는 bvname을,
#   키 파일 이름에는 bvkey를 넣어 "출력에 없다"를 단언한다(경로가 어떤 모양으로 찍혀도 — 역슬래시 두 겹(Go %q) · / 구분자 — 이름 조각이
#   남으면 걸린다).
# 실행: 스크립트는 자식 pwsh로 돌리고(작업 디렉터리 = 저장소 루트), 실행마다 감시 시간(기본 180초)을 넘기면 프로세스 트리를 끝내고
#   그 실행을 실패로 기록한다(멈춘 스크립트가 하네스를 멈추지 않게 — G-7).
# 환경 변수:
#   BACKUP_VERIFY_SCRIPT      시험할 스크립트(기본 scripts/backup-verify.ps1) — 변이 시험에서 사본을 가리킬 때 쓴다. 설정돼 있으면 요약 줄
#                             끝에 ' (script override: <파일 이름>)'이 붙는다(run-all의 판정을 통과하지 못한다).
#   BACKUP_VERIFY_TESTS_ONLY  쉼표로 나눈 그룹 이름(예: V3,V6)만 실행한다(반복 중 영향 받는 케이스만 돌릴 때). 정적 S · 공통 G는 늘 돈다.
#                             요약 줄 끝에 ' (filtered: …)'가 붙어 run-all의 'N passed, 0 failed' 판정을 통과하지 못한다(부분 실행이 전체 통과로 보이지 않게).
# 실패 사유 단언은 검사 줄의 detail(' -- ' 뒤)에서만 찾는다(설명문에 같은 낱말이 있으면 공허해진다).
# 그룹 이름 V1–V15는 첫 지시서의 표 번호다. 지시서 밖에서 더한 것: V6c(인덱스 불일치 — integrity_check가 행을 돌려주는 손상) ·
#   V10b(형식이 틀린 키 파일 — age 오류문에 키 경로가 실린다) · V13d(-MaxAgeHours 인자 배선) · V13c(후보 없음) · V16(작업 디렉터리를
#   지우지 못함 — Windows 전용) · V17(기본 작업 루트 = TMP · 자식 도구의 임시 파일도 작업 디렉터리 안) · V18(상대 경로 + $PWD와 .NET cwd
#   불일치) · F-*(픽스처 전제) · G-*(모든 실행 공통 규율) · V1-3/V11-4/V15/V18의 파일 감시(디스크에 생기는 이름 전부).
# 리뷰 반영(수정 지시서 B1–B10): V7b(빈 kine) · V9-maxage(-MaxAgeHours 0) · V19(신선도 — 미래 이름 · time-created · 경계) ·
#   V20(시간 제한 · state.db 쓰기 실패 — 오류 주입 사본) · V21(남은 작업 디렉터리) · V22(없는 드라이브 — en-US 예외 문구) ·
#   V23(oci 출력이 JSON이 아님) · V24(홈 · 임시 폴더 · 대소문자가 다른 경로의 가림) · V25(별칭 · 중복 항목 이름) · V26(항목 종류 · 크기).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptPath = if (-not [string]::IsNullOrEmpty($env:BACKUP_VERIFY_SCRIPT)) { $env:BACKUP_VERIFY_SCRIPT } else { Join-Path $repo 'scripts/backup-verify.ps1' }
$scriptOverride = -not [string]::IsNullOrEmpty($env:BACKUP_VERIFY_SCRIPT)
$snapFixture = Join-Path $PSScriptRoot 'fixtures/backup-verify/vault-mock.snap'
$pwshExe = [Environment]::ProcessPath
$inv = [Globalization.CultureInfo]::InvariantCulture
$script:pass = 0
$script:fail = 0
$script:runs = [Collections.Generic.List[object]]::new()   # 모든 실행의 결과(G-* 단언)
$script:tmpRoot = $null
$script:aclLocked = @()                                     # V16에서 거부 ACE가 걸린 경로(끝에 반드시 푼다)
$script:sw = [Diagnostics.Stopwatch]::StartNew()

$only = @()
if (-not [string]::IsNullOrEmpty($env:BACKUP_VERIFY_TESTS_ONLY)) { $only = @($env:BACKUP_VERIFY_TESTS_ONLY.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }) }
function Test-Selected([string]$name) {
    if ($only.Count -eq 0) { return $true }
    foreach ($o in $only) { if ([string]::Equals($o, $name, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# ---------- 도구 ----------
# 파이썬: 스크립트와 같은 순서(py -3 · python3 · python)로 import sqlite3가 되는 첫 번째
function Find-Python {
    foreach ($c in @(@{ n = 'py'; a = @('-3') }, @{ n = 'python3'; a = @() }, @{ n = 'python'; a = @() })) {
        $cmd = Get-Command $c.n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { continue }
        $null = & $cmd.Source @($c.a) -c 'import sqlite3' 2>$null
        if ($LASTEXITCODE -eq 0) { return @{ exe = $cmd.Source; pre = @($c.a) } }
    }
    return $null
}
$tools = @{}
$missingTools = @()
foreach ($t in @('age', 'age-keygen', 'tar', 'vault')) {
    $cmd = Get-Command $t -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $tools[$t] = $cmd.Source } else { $missingTools += $t }
}
$py = Find-Python
if (-not $py) { $missingTools += 'python with the sqlite3 module (py -3, python3, python)' }
if (-not $IsWindows) { $missingTools += 'Windows (the fake oci and tar shims are .cmd files)' }
if ($missingTools.Count -gt 0) {
    Write-Host "SKIP backup-verify tests -- not found: $($missingTools -join ', ') (PATH)"
    exit 0
}
Write-Host "info: tar under test = $($tools['tar'])"

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리. 한 그룹에서 예외가 나도 나머지 그룹은 계속 실행된다. 선택 실행이면 고르지 않은 그룹은 건너뛴다(S · G는 늘 돈다).
function Test-Group([string]$name, [scriptblock]$body) {
    if (-not (Test-Same $name 'S') -and -not (Test-Same $name 'G') -and -not (Test-Selected $name)) { return }
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Format-Result($r) { "out=[$($r.out)] err=[$($r.err)] [code=$($r.code)]" }

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-Has([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Test-HasI([string]$text, [string]$needle) { $text.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
function Get-LinesWithPrefix([string[]]$lines, [string]$prefix) { return ,@($lines | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }) }

# 검사 줄: 'PASS <id>: …' 또는 'FAIL <id>: …'
function Get-CheckLines($r, [string]$id) {
    return ,@($r.lines | Where-Object { $_.StartsWith("PASS ${id}:", [StringComparison]::Ordinal) -or $_.StartsWith("FAIL ${id}:", [StringComparison]::Ordinal) })
}
function Get-CheckLine($r, [string]$id) { $l = Get-CheckLines $r $id; if ($l.Count -eq 1) { return $l[0] }; return '' }
# 검사 줄의 detail(첫 ' -- ' 뒤). 실패 사유 단언은 여기서만 찾는다(설명문의 낱말에 걸려 공허해지지 않게). 줄이 없거나 ' -- '가 없으면 ''.
function Get-Detail($r, [string]$id) {
    $l = Get-CheckLine $r $id
    $i = $l.IndexOf(' -- ', [StringComparison]::Ordinal)
    if ($i -lt 0) { return '' }
    return $l.Substring($i + 4)
}
function Test-Check($r, [string]$id, [string]$status) {
    $l = Get-CheckLines $r $id
    return ($l.Count -eq 1 -and $l[0].StartsWith("$status ${id}:", [StringComparison]::Ordinal))
}
function Test-NotAttempted($r, [string]$id, [string]$by) {
    $l = Get-CheckLines $r $id
    return ($l.Count -eq 1 -and (Test-Same $l[0] "FAIL ${id}: not attempted ($by)"))
}
# 마지막 비어 있지 않은 줄 'N passed, N failed'
function Get-Summary($r) {
    $last = "$(@($r.lines | Where-Object { $_.Trim().Length -gt 0 }) | Select-Object -Last 1)"
    $m = [regex]::Match($last, '\A([0-9]+) passed, ([0-9]+) failed\z')
    if ($m.Success) { return @{ pass = [int]$m.Groups[1].Value; fail = [int]$m.Groups[2].Value } }
    return $null
}
# 주어진 id가 전부 PASS · FAIL 줄 0 · 요약 'N passed, 0 failed'(N = id 수) · exit 0
function Test-AllPass($r, [string[]]$ids) {
    foreach ($id in $ids) { if (-not (Test-Check $r $id 'PASS')) { return $false } }
    $s = Get-Summary $r
    return ($r.code -eq 0 -and $null -ne $s -and $s.pass -eq $ids.Count -and $s.fail -eq 0 -and (Get-LinesWithPrefix $r.lines 'FAIL ').Count -eq 0)
}
function Get-WorkDirs([string]$root) { return ,@(Get-ChildItem -LiteralPath $root -Force -Filter 'backup-verify-*' -ErrorAction SilentlyContinue) }

$localIds = @('bv-pre-1', 'bv-pre-2', 'bv-pre-3', 'bv-k3s-1', 'bv-k3s-2', 'bv-k3s-3', 'bv-k3s-4', 'bv-vault-1', 'bv-vault-2', 'bv-vault-3', 'bv-clean')
$dlIds = @('bv-pre-1', 'bv-pre-2', 'bv-pre-3', 'bv-dl-k3s', 'bv-k3s-1', 'bv-k3s-2', 'bv-k3s-3', 'bv-k3s-4', 'bv-dl-vault', 'bv-vault-1', 'bv-vault-2', 'bv-vault-3', 'bv-clean')
$k3sIds = @('bv-k3s-1', 'bv-k3s-2', 'bv-k3s-3', 'bv-k3s-4')
$vaultIds = @('bv-vault-1', 'bv-vault-2', 'bv-vault-3')

# ---------- 파일 감시: 실행 동안 감시 디렉터리 아래에 생긴 이름(상대 경로, / 구분) ----------
# 이벤트는 -Action 없이 세션 이벤트 큐에 쌓이고(자식 실행으로 막혀 있어도 쌓인다) Stop-Watch가 꺼낸다.
function Start-Watch([string]$dir) {
    $w = [IO.FileSystemWatcher]::new($dir)
    $w.IncludeSubdirectories = $true
    $w.NotifyFilter = [IO.NotifyFilters]'FileName, DirectoryName'
    $id = 'bvw-' + [guid]::NewGuid().ToString('N')
    $null = Register-ObjectEvent -InputObject $w -EventName Created -SourceIdentifier "$id-c"
    $null = Register-ObjectEvent -InputObject $w -EventName Renamed -SourceIdentifier "$id-r"
    $w.EnableRaisingEvents = $true
    return @{ w = $w; id = $id; dir = $dir }
}
function Stop-Watch($h) {
    Start-Sleep -Milliseconds 300
    $h.w.EnableRaisingEvents = $false
    $names = [Collections.Generic.List[string]]::new()
    foreach ($sid in @("$($h.id)-c", "$($h.id)-r")) {
        foreach ($e in @(Get-Event -SourceIdentifier $sid -ErrorAction SilentlyContinue)) {
            $names.Add(([IO.Path]::GetRelativePath($h.dir, $e.SourceEventArgs.FullPath) -replace '\\', '/'))
            Remove-Event -EventIdentifier $e.EventIdentifier -ErrorAction SilentlyContinue
        }
        Unregister-Event -SourceIdentifier $sid -ErrorAction SilentlyContinue
    }
    $h.w.Dispose()
    return ,$names.ToArray()
}
# 감시 결과가 정확히 작업 디렉터리 하나 + 그 안의 허용 이름들 + 도구 임시 디렉터리 tmp/ 인가(허용 이름과 tmp는 전부 나타나야 한다 —
#   감시가 실제로 동작했다는 증거). tmp/ 아래에는 vault CLI가 시작할 때마다 푸는 gosnowflake-cgo<숫자>/libsf_mini_core_*.dll과
#   PowerShell이 시작할 때 만들었다 바로 지우는 __PSScriptPolicyTest_*.ps1/.psm1(가짜 oci가 pwsh라서 생긴다)만 허용한다
#   (그 밖의 임시 파일은 실패 — 도구가 평문을 임시 파일로 흘리는 길일 수 있다).
$psPolicyTest = '__PSScriptPolicyTest_[a-z0-9]+\.[a-z0-9]+\.psm?1'
function Test-CreatedExactly([string[]]$created, [string[]]$allowedLeaves) {
    $dirs = @($created | Where-Object { $_ -match '\Abackup-verify-[0-9a-f]{32}\z' } | Select-Object -Unique)
    if ($dirs.Count -ne 1) { return $false }
    $d = $dirs[0]
    $expected = @($d, "$d/tmp") + @($allowedLeaves | ForEach-Object { "$d/$_" })
    $toolJunk = '\A' + [regex]::Escape("$d/tmp/") + '(gosnowflake-cgo[0-9]+(/libsf_mini_core_[a-z0-9_]+\.dll)?|' + $psPolicyTest + ')\z'
    foreach ($c in $created) {
        if ($expected -ccontains $c) { continue }
        if ($c -cmatch $toolJunk) { continue }
        return $false
    }
    foreach ($x in $expected) { if (-not ($created -ccontains $x)) { return $false } }
    return $true
}

# 스크립트를 자식 pwsh로 실행한다(Process API — 환경은 자식에게만 준다: $envSet(이름 → 값, $null이면 지움) · PATH 앞 디렉터리($pathPrefix)).
#   $watchDir     주면 그 아래에 생기는 이름을 모은다(r.created)
#   $command      주면 -File 대신 -Command로 실행한다(V18 — Set-Location 뒤 상대 경로 호출)
#   $script       시험할 스크립트 파일(기본 $scriptPath — V20b의 오류 주입 사본)
#   $watchdogSec  이 시간 안에 끝나지 않으면 프로세스 트리를 끝내고 r.timedOut = $true(멈춘 실행이 하네스를 멈추지 않게)
# 자식의 작업 디렉터리는 저장소 루트(V18이 .NET cwd와 $PWD의 불일치를 확실히 만들게). stdout · stderr는 UTF-8로 읽는다.
function Invoke-BV([string[]]$argv = @(), [hashtable]$envSet = @{}, [string]$pathPrefix = '', [string]$watchDir = '', [string]$command = '', [string]$scriptFile = $scriptPath, [int]$watchdogSec = 180) {
    $r = @{ out = ''; err = ''; code = -1; lines = @(); created = @(); secs = 0.0; missing = $false; timedOut = $false }
    if (-not (Test-Path -LiteralPath $scriptFile -PathType Leaf)) {
        $r.out = "<missing script: $scriptFile>"; $r.code = 127; $r.missing = $true
        $script:runs.Add($r)
        return $r
    }
    $psi = [Diagnostics.ProcessStartInfo]::new($pwshExe)
    foreach ($a in @('-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass')) { $psi.ArgumentList.Add($a) }
    if (-not [string]::IsNullOrEmpty($command)) { $psi.ArgumentList.Add('-Command'); $psi.ArgumentList.Add($command) }
    else { $psi.ArgumentList.Add('-File'); $psi.ArgumentList.Add($scriptFile); foreach ($a in $argv) { $psi.ArgumentList.Add($a) } }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $psi.WorkingDirectory = $repo
    foreach ($k in $envSet.Keys) { if ($null -eq $envSet[$k]) { [void]$psi.Environment.Remove($k) } else { $psi.Environment[$k] = [string]$envSet[$k] } }
    if (-not [string]::IsNullOrEmpty($pathPrefix)) { $psi.Environment['PATH'] = $pathPrefix + [IO.Path]::PathSeparator + $psi.Environment['PATH'] }
    $watch = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $p = $null
    try {
        if (-not [string]::IsNullOrEmpty($watchDir)) { $watch = Start-Watch $watchDir }
        $p = [Diagnostics.Process]::Start($psi)
        $o = $p.StandardOutput.ReadToEndAsync()
        $e = $p.StandardError.ReadToEndAsync()
        if (-not $p.WaitForExit($watchdogSec * 1000)) {
            $r.timedOut = $true
            try { $p.Kill($true) } catch { }
            [void]$p.WaitForExit(30000)
        } else { $p.WaitForExit() }
        $r.code = if ($r.timedOut) { -999 } else { $p.ExitCode }
        $outText = if ($o.Wait(30000)) { $o.Result } else { '' }
        $errText = if ($e.Wait(30000)) { $e.Result } else { '' }
    } finally {
        if ($null -ne $p) { $p.Dispose() }
        if ($null -ne $watch) { $r.created = Stop-Watch $watch }
    }
    $r.secs = $sw.Elapsed.TotalSeconds
    $r.err = (($errText -replace "`r`n", "`n").TrimEnd("`n"))
    if ($r.timedOut) { $r.err = ("<harness watchdog: killed after $watchdogSec s>`n" + $r.err).TrimEnd("`n") }
    $norm = ($outText -replace "`r`n", "`n").TrimEnd("`n")
    $r.lines = @(if ($norm.Length -gt 0) { $norm -split "`n" })
    $r.out = $r.lines -join "`n"
    $script:runs.Add($r)
    return $r
}

# ---------- 픽스처 ----------
function New-Dir([string]$path) { [void][IO.Directory]::CreateDirectory($path); return $path }
function New-WorkRoot([string]$label) { return New-Dir (Join-Path $script:fx ('wr-' + $label)) }
function Get-Sha256([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() }
# $src의 앞 $count바이트만 $dst에 쓴다
function Write-Prefix([string]$src, [string]$dst, [long]$count) {
    $b = [IO.File]::ReadAllBytes($src)
    $fs = [IO.File]::Create($dst)
    try { $fs.Write($b, 0, [int]$count) } finally { $fs.Dispose() }
}
function Protect-Age([string]$recipient, [string]$in, [string]$out) {
    $o = & $tools['age'] -r $recipient -o $out $in 2>&1
    if ($LASTEXITCODE -ne 0) { throw "age encrypt failed for $([IO.Path]::GetFileName($in)): $o" }
}
function New-AgeKey([string]$path) {
    $null = & $tools['age-keygen'] -o $path 2>&1
    if ($LASTEXITCODE -ne 0) { throw "age-keygen failed" }
    $line = @(Get-Content -LiteralPath $path | Where-Object { $_.StartsWith('# public key: ', [StringComparison]::Ordinal) })
    if ($line.Count -ne 1) { throw "no public key line in generated key file" }
    return $line[0].Substring(14).Trim()
}

# 파이썬 픽스처 생성기: WAL 모드 SQLite(실제 kine과 같은 열 · 인덱스는 행을 넣은 뒤 만든다 — 테이블 페이지가 파일 앞쪽에 모인다)와
#   그 손상본 · kine 없는 DB, 그리고 번들 tar 변형들을 만든다. 마지막 줄에 픽스처 전제(F-*)를 JSON으로 찍는다.
#   손상: midzero = 가운데 페이지 전체를 0으로 · headzero = 앞 512바이트를 0으로 · idxzero = 가운데 행(id 200)의 name 바이트를
#   테이블에서만 0으로(레코드 모양은 그대로 → integrity_check가 '인덱스에 없는 행'을 행으로 돌려주고 count · max는 된다).
# 역슬래시를 쓰지 않는다(개행은 bytes([10])).
$genPy = @'
import io, json, os, pathlib, sqlite3, sys, tarfile

out = sys.argv[1]
NL = bytes([10])
TOKEN = b'K10BVTEST-TOKEN-MARKER-5e1d::server:0f1e2d3c4b5a69788796a5b4c3d2e1f0' + NL
CRED = [('server/cred/passwd-bvname-c1', b'bvtest,server,server,k3s:server' + NL),
        ('server/cred/ipsec-bvname-c2.psk', b'BVTEST-TOKEN-MARKER-psk' + NL)]
TLS = [('server/tls/server-ca-bvname-t1.crt', b'-----BEGIN CERTIFICATE-----' + NL + b'BVTEST-TLS-MARKER' + NL + b'-----END CERTIFICATE-----' + NL),
       ('server/tls/server-ca-bvname-t2.key', b'-----BEGIN EC PRIVATE KEY-----' + NL + b'BVTEST-TLS-MARKER' + NL + b'-----END EC PRIVATE KEY-----' + NL)]
NEEDLE = b'/registry/configmaps/default/cm-0200'


def rm(path):
    for s in ('', '-wal', '-shm', '-journal'):
        if os.path.exists(path + s):
            os.remove(path + s)


def make_db(path, kine=True, rows=400, drop_first=50):
    rm(path)
    con = sqlite3.connect(path)
    try:
        con.execute('PRAGMA journal_mode=WAL')
        if kine:
            con.execute('CREATE TABLE kine (id INTEGER PRIMARY KEY AUTOINCREMENT, name INTEGER, created INTEGER, deleted INTEGER, '
                        'create_revision INTEGER, prev_revision INTEGER, lease INTEGER, value BLOB, old_value BLOB)')
            con.executemany('INSERT INTO kine (name, created, deleted, create_revision, prev_revision, lease, value, old_value) '
                            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                            [('/registry/configmaps/default/cm-%04d' % i, 1, 0, i, i - 1, 0,
                              b'BVTEST-DB-MARKER ' + bytes([i % 256]) * 300, b'') for i in range(1, rows + 1)])
            # 앞 행을 지워 count(*)와 max(id)가 다르게 한다(실제 kine도 compact 뒤 그렇다 — 둘을 뒤바꾼 변이가 잡히게)
            con.execute('DELETE FROM kine WHERE id <= ?', (drop_first,))
            con.execute('CREATE INDEX kine_name_index ON kine (name)')
            con.execute('CREATE INDEX kine_name_id_index ON kine (name, id)')
        else:
            con.execute('CREATE TABLE other (id INTEGER PRIMARY KEY, v TEXT)')
            con.executemany('INSERT INTO other (v) VALUES (?)', [('row-%d' % i,) for i in range(1, 401)])
        con.commit()
    finally:
        con.close()
    for s in ('-wal', '-shm'):
        if os.path.exists(path + s):
            os.remove(path + s)


def corrupt(src, dst, how):
    data = bytearray(open(src, 'rb').read())
    if how == 'midzero':
        ps = int.from_bytes(data[16:18], 'big')
        n = len(data) // ps
        off = (n // 2) * ps
        data[off:off + ps] = bytes(ps)
    elif how == 'headzero':
        data[0:512] = bytes(512)
    elif how == 'idxzero':
        i = data.find(NEEDLE)
        data[i:i + len(NEEDLE)] = bytes(len(NEEDLE))
    with open(dst, 'wb') as f:
        f.write(bytes(data))


def probe(path):
    r = {}
    con = sqlite3.connect(pathlib.Path(path).resolve().as_uri() + '?mode=ro&immutable=1', uri=True)
    try:
        try:
            rows = [str(x[0]) for x in con.execute('PRAGMA integrity_check').fetchall()]
            r['integrity'] = rows[:3]
            r['integrity_rows'] = len(rows)
        except sqlite3.Error as e:
            r['raised'] = str(e)
            return r
        try:
            r['count'] = list(con.execute('SELECT count(*), max(id) FROM kine').fetchone())
        except sqlite3.Error as e:
            r['count_raised'] = str(e)
        r['wal'] = open(path, 'rb').read(20)[18]
    finally:
        con.close()
    return r


# 항목: ('d', 이름) 디렉터리 · ('f', 이름, 바이트) 일반 파일 · ('l', 이름, 대상) 심볼릭 링크 · ('h', 이름, 대상) 하드 링크
def make_tar(path, entries):
    with tarfile.open(path, 'w', format=tarfile.PAX_FORMAT) as t:
        for e in entries:
            ti = tarfile.TarInfo(e[1])
            ti.mtime = 1700000000
            if e[0] == 'd':
                ti.type = tarfile.DIRTYPE
                ti.mode = 0o700
                t.addfile(ti)
            elif e[0] == 'f':
                ti.size = len(e[2])
                ti.mode = 0o600
                t.addfile(ti, io.BytesIO(e[2]))
            elif e[0] == 'l':
                ti.type = tarfile.SYMTYPE
                ti.linkname = e[2]
                ti.mode = 0o777
                t.addfile(ti)
            elif e[0] == 'h':
                ti.type = tarfile.LNKTYPE
                ti.linkname = e[2]
                ti.mode = 0o600
                t.addfile(ti)


# 노드 번들과 같은 모양(server/ 접두 · 디렉터리 항목 포함). db = 바이트 또는 None, token · cred · tls = 그 부분의 항목 목록(None이면 기본)
def bundle(db, token=None, cred=None, tls=None, extra=()):
    e = [('d', 'server'), ('d', 'server/db')]
    if db is not None:
        e.append(('f', 'server/db/state.db', db))
    e += token if token is not None else [('f', 'server/token', TOKEN)]
    e += [('d', 'server/cred')] + (cred if cred is not None else [('f', k, v) for k, v in CRED])
    e += [('d', 'server/tls')] + (tls if tls is not None else [('f', k, v) for k, v in TLS])
    return e + list(extra)


plain = os.path.join(out, 'plain')
os.makedirs(plain, exist_ok=True)
good = os.path.join(plain, 'state-good.db')
make_db(good)
nokine = os.path.join(plain, 'state-nokine.db')
make_db(nokine, kine=False)
emptykine = os.path.join(plain, 'state-emptykine.db')
make_db(emptykine, rows=0, drop_first=0)
raw = open(good, 'rb').read()
facts = {'needle_count': raw.count(NEEDLE), 'needle_first': raw.find(NEEDLE), 'needle_second': raw.find(NEEDLE, raw.find(NEEDLE) + 1),
         'size': len(raw)}
dbs = {'good': good, 'nokine': nokine, 'emptykine': emptykine}
for how in ('midzero', 'headzero', 'idxzero'):
    p = os.path.join(plain, 'state-%s.db' % how)
    corrupt(good, p, how)
    dbs[how] = p
for k, p in dbs.items():
    facts['probe_' + k] = probe(p)
data = {k: open(p, 'rb').read() for k, p in dbs.items()}
G = data['good']
ALIAS = b'BVTEST-ALIAS-NOT-A-DATABASE ' * 20
bundles = {
    'good': bundle(G), 'nodb': bundle(None), 'notoken': bundle(G, token=[]), 'nocred': bundle(G, cred=[]), 'notls': bundle(G, tls=[]),
    'midzero': bundle(data['midzero']), 'headzero': bundle(data['headzero']), 'idxzero': bundle(data['idxzero']),
    'nokine': bundle(data['nokine']), 'emptykine': bundle(data['emptykine']),
    # B3: 정상 번들 뒤에 같은 파일을 가리키는 별칭 이름 · 접두 밖 이름 · 정규 이름의 중복
    'alias-dotslash': bundle(G, extra=[('f', './server/db/state.db', ALIAS)]),
    'alias-dblslash': bundle(G, extra=[('f', 'server//db/state.db', ALIAS)]),
    'alias-dotseg': bundle(G, extra=[('f', 'server/./db/state.db', ALIAS)]),
    'alias-dotdot': bundle(G, extra=[('f', 'server/db/../db/state.db', ALIAS)]),
    'alias-outside': bundle(G, extra=[('f', 'other/bvname-outside.txt', b'x' + NL)]),
    'dup-db': bundle(G, extra=[('f', 'server/db/state.db', G)]),
    'dup-cred': bundle(G, extra=[('f', CRED[0][0], CRED[0][1])]),
    # B4: 일반 파일이고 크기 > 0인 것만 센다
    'db-symlink': bundle(None, extra=[('l', 'server/db/state.db', 'state-bvname.db')]),
    'db-empty': bundle(b''),
    'token-symlink': bundle(G, token=[('l', 'server/token', 'cred/passwd-bvname-c1')]),
    'cred-hardlink': bundle(G, cred=[('h', 'server/cred/passwd-bvname-c1', 'server/token')]),
    'cred-dironly': bundle(G, cred=[('d', 'server/cred/sub-bvname')]),
    'tls-empty': bundle(G, tls=[('f', 'server/tls/server-ca-bvname-t1.crt', b'')]),
}
for k, entries in bundles.items():
    make_tar(os.path.join(plain, 'bundle-%s.tar' % k), entries)
facts['bundles'] = sorted(bundles.keys())
for p in dbs.values():
    rm(p)
print(json.dumps(facts))
'@

# 가짜 oci(oci.cmd → pwsh oci-fake.ps1). 시나리오 JSON($env:BVTEST_OCI_SCENARIO):
#   expired  true면 모든 호출이 exit 1 + 'session has expired'(stderr)
#   list     [{name, size, time-created}] — 'os object list'는 --prefix로 시작하는 것만 {"data": […]}로 돌려준다(비ASCII는 \u 이스케이프)
#   objects  {이름: 로컬 파일} — 'os object get'이 --file로 복사한다. drop {이름: n}이면 뒤 n바이트를 빼고 쓴다
#   listFail 문자열이면 'os object list'가 그것을 stderr에 쓰고 exit 1(V24 — 경로가 든 오류문의 가림)
#   listRaw  문자열이면 'os object list'가 그것을 stdout에 그대로 쓰고 exit 0(V23 — JSON이 아닌 출력)
# 받은 인자 · OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING 값을 $env:BVTEST_OCI_LOG에 한 줄 JSON으로 남긴다.
$ociFake = @'
$ErrorActionPreference = 'Stop'
$argv = @($args)
$sc = [IO.File]::ReadAllText($env:BVTEST_OCI_SCENARIO) | ConvertFrom-Json -AsHashtable -DateKind String
$entry = [ordered]@{ argv = $argv; suppress = "$env:OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING" }
[IO.File]::AppendAllText($env:BVTEST_OCI_LOG, ($entry | ConvertTo-Json -Compress -Depth 5 -EscapeHandling EscapeNonAscii) + "`n")
function Get-Opt([string]$n) { $i = [Array]::IndexOf($argv, $n); if ($i -ge 0 -and $i + 1 -lt $argv.Count) { return $argv[$i + 1] }; return $null }
if ($sc['expired']) { [Console]::Error.WriteLine('ERROR: This CLI session has expired, so it cannot currently be used to run commands'); exit 1 }
$joined = $argv -join ' '
if ($joined.Contains('os object list')) {
    if ($sc['listFail']) { [Console]::Error.WriteLine([string]$sc['listFail']); exit 1 }
    if ($sc['listRaw']) { [Console]::Out.Write([string]$sc['listRaw']); exit 0 }
    $prefix = Get-Opt '--prefix'
    $items = @($sc['list'] | Where-Object { $_['name'].StartsWith($prefix, [StringComparison]::Ordinal) })
    [Console]::Out.Write((@{ data = $items; prefixes = @() } | ConvertTo-Json -Depth 5 -EscapeHandling EscapeNonAscii))
    exit 0
}
if ($joined.Contains('os object get')) {
    $name = Get-Opt '--name'
    $file = Get-Opt '--file'
    if (-not $sc['objects'].ContainsKey($name)) { [Console]::Error.WriteLine('ServiceError: {"code": "ObjectNotFound", "status": 404}'); exit 1 }
    $bytes = [IO.File]::ReadAllBytes($sc['objects'][$name])
    $drop = 0
    if ($sc.ContainsKey('drop') -and $sc['drop'].ContainsKey($name)) { $drop = [int]$sc['drop'][$name] }
    $fs = [IO.File]::Create($file)
    try { $fs.Write($bytes, 0, $bytes.Length - $drop) } finally { $fs.Dispose() }
    exit 0
}
[Console]::Error.WriteLine("fake oci: unsupported call: $joined")
exit 2
'@

# cmd 심 본문(CRLF, BOM 없음). 경로는 따옴표로 감싼다.
function Write-Cmd([string]$path, [string[]]$lines) { [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), [Text.UTF8Encoding]::new($false)) }

# 시나리오 JSON을 쓰고 이번 실행용 환경(시나리오 · 로그 경로)을 돌려준다
function New-OciScenario([string]$label, [hashtable]$scenario) {
    $sc = Join-Path $script:fx "oci-$label.json"
    $log = Join-Path $script:fx "oci-$label.log"
    [IO.File]::WriteAllText($sc, ($scenario | ConvertTo-Json -Depth 6 -EscapeHandling EscapeNonAscii), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($log, '', [Text.UTF8Encoding]::new($false))
    return @{ env = @{ BVTEST_OCI_SCENARIO = $sc; BVTEST_OCI_LOG = $log }; log = $log }
}
function Read-OciLog([string]$log) {
    return ,@([IO.File]::ReadAllLines($log) | Where-Object { $_.Trim().Length -gt 0 } | ForEach-Object { $_ | ConvertFrom-Json -AsHashtable })
}
function Get-NameTime([double]$hoursAgo) { return $script:now.AddHours(-$hoursAgo).ToString("yyyyMMdd'T'HHmmss'Z'", $inv) }
function Format-Created([datetime]$utc) { return $utc.ToString("yyyy-MM-dd'T'HH:mm:ss'.000000+00:00'", $inv) }
# 목록 항목. time-created: $created(문자열)를 주면 그대로, 아니면 이름의 시각 + 20초(노드는 스냅샷 직후 올린다), 이름에 시각이 없으면 지금
function New-ListItem([string]$name, [string]$file, [string]$created = '') {
    if ([string]::IsNullOrEmpty($created)) {
        $m = [regex]::Match($name, '-([0-9]{8}T[0-9]{6}Z)\.')
        $t = [datetime]::MinValue
        $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
        if ($m.Success -and [datetime]::TryParseExact($m.Groups[1].Value, "yyyyMMdd'T'HHmmss'Z'", $inv, $styles, [ref]$t)) { $created = Format-Created $t.AddSeconds(20) }
        else { $created = Format-Created $script:now }
    }
    return [ordered]@{ name = $name; size = (Get-Item -LiteralPath $file).Length; 'time-created' = $created }
}

try {
    $script:tmpRoot = New-Dir (Join-Path ([IO.Path]::GetTempPath()) ('bvtest-' + [guid]::NewGuid().ToString('N')))
    $script:fx = New-Dir (Join-Path $script:tmpRoot 'fx')
    $script:now = [DateTime]::UtcNow
    $fx = $script:fx

    # ---------- 픽스처 만들기 ----------
    $keyMain = Join-Path $fx 'bvkey-main.txt'
    $keyOther = Join-Path $fx 'bvkey-other.txt'
    $keyBad = Join-Path $fx 'bvkey-bad.txt'
    $keyMissing = Join-Path $fx 'bvkey-missing/none-bvkey.txt'
    $pubMain = New-AgeKey $keyMain
    $null = New-AgeKey $keyOther
    [IO.File]::WriteAllText($keyBad, "this is not an age identity`n", [Text.UTF8Encoding]::new($false))

    $genFile = Join-Path $fx 'gen.py'
    [IO.File]::WriteAllText($genFile, $genPy, [Text.UTF8Encoding]::new($false))
    $genOut = @(& $py.exe @($py.pre) $genFile $fx 2>&1 | ForEach-Object { "$_" })
    $genCode = $LASTEXITCODE
    $facts = $null
    if ($genCode -eq 0) { $facts = ($genOut | Select-Object -Last 1) | ConvertFrom-Json -AsHashtable }
    Assert 'F-1: fixture generator (python sqlite3 + tarfile) exits 0 and reports its facts' ($genCode -eq 0 -and $null -ne $facts) "exit=$genCode out=[$($genOut -join ' / ')]"
    if ($null -eq $facts) { throw 'fixture generation failed' }
    $pg = $facts['probe_good']; $pm = $facts['probe_midzero']; $ph = $facts['probe_headzero']; $pi = $facts['probe_idxzero']; $pe = $facts['probe_emptykine']
    Assert 'F-2: good state.db is WAL mode (header byte 18 = 2, like the node''s sqlite3 .backup copy), integrity ok, count(*) 350 and max(id) 400 (different on purpose); the empty-kine DB is sound with 0 rows' (
        $pg['wal'] -eq 2 -and $pg['integrity_rows'] -eq 1 -and (Test-Same $pg['integrity'][0] 'ok') -and $pg['count'][0] -eq 350 -and $pg['count'][1] -eq 400 -and
        $pe['integrity_rows'] -eq 1 -and (Test-Same $pe['integrity'][0] 'ok') -and $pe['count'][0] -eq 0
    ) ($facts | ConvertTo-Json -Compress -Depth 5)
    Assert 'F-3: corruption fixtures do what V6 needs -- midzero raises "malformed", headzero raises "not a database", idxzero returns integrity rows while count/max still work' (
        $pm.ContainsKey('raised') -and (Test-Has $pm['raised'] 'malformed') -and $ph.ContainsKey('raised') -and (Test-Has $ph['raised'] 'not a database') -and
        $pi.ContainsKey('integrity_rows') -and $pi['integrity_rows'] -ge 1 -and -not (Test-Same $pi['integrity'][0] 'ok') -and $pi['count'][0] -eq 350 -and
        $facts['needle_count'] -eq 3 -and $facts['needle_first'] -lt $facts['needle_second']
    ) ($facts | ConvertTo-Json -Compress -Depth 5)
    Assert 'F-4: committed Vault sample snapshot exists (tests/scripts/fixtures/backup-verify/vault-mock.snap)' (Test-Path -LiteralPath $snapFixture -PathType Leaf) "missing: $snapFixture"

    # 번들 암호화(평문 tar는 바로 지운다)
    $k3s = @{}
    foreach ($v in @($facts['bundles'])) {
        $plainTar = Join-Path $fx "plain/bundle-$v.tar"
        $k3s[$v] = Join-Path $fx "k3s-$v.tar.age"
        Protect-Age $pubMain $plainTar $k3s[$v]
        Remove-Item -LiteralPath $plainTar -Force
    }
    $k3s['trunc'] = Join-Path $fx 'k3s-trunc.tar.age'
    $goodLen = (Get-Item -LiteralPath $k3s['good']).Length
    Write-Prefix $k3s['good'] $k3s['trunc'] ([long][Math]::Floor($goodLen * 2 / 3))

    $vault = @{}
    $vault['good'] = Join-Path $fx 'vault-good.snap.age'
    Protect-Age $pubMain $snapFixture $vault['good']
    $junkPlain = Join-Path $fx 'plain/vault-junk.snap'
    $rb = [byte[]]::new(3000); [Random]::new(7).NextBytes($rb); $rb[0] = 0x42
    [IO.File]::WriteAllBytes($junkPlain, $rb)
    $vault['junk'] = Join-Path $fx 'vault-junk.snap.age'
    Protect-Age $pubMain $junkPlain $vault['junk']
    $truncPlain = Join-Path $fx 'plain/vault-trunc.snap'
    Write-Prefix $snapFixture $truncPlain ([long][Math]::Floor((Get-Item -LiteralPath $snapFixture).Length / 2))
    $vault['trunc'] = Join-Path $fx 'vault-trunc.snap.age'
    Protect-Age $pubMain $truncPlain $vault['trunc']
    Remove-Item -LiteralPath $junkPlain, $truncPlain -Force

    # 내려받기 모드의 미끼 객체 내용(age 형식이 아님 — 잘못 고르면 복호화가 실패한다)
    $junkObj = Join-Path $fx 'junk-object.bin'
    $jb = [byte[]]::new(1000); [Random]::new(11).NextBytes($jb)
    [IO.File]::WriteAllBytes($junkObj, $jb)

    # 가짜 oci · 가짜 tar
    $realTar = $tools['tar']
    $binOci = New-Dir (Join-Path $fx 'bin-oci')
    [IO.File]::WriteAllText((Join-Path $binOci 'oci-fake.ps1'), $ociFake, [Text.UTF8Encoding]::new($false))
    Write-Cmd (Join-Path $binOci 'oci.cmd') @('@echo off', "`"$pwshExe`" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"%~dp0oci-fake.ps1`" %*", 'exit /b %ERRORLEVEL%')
    $binTarCrash = New-Dir (Join-Path $fx 'bin-tar-crash')
    Write-Cmd (Join-Path $binTarCrash 'tar.cmd') @('@echo off', 'if "%~1"=="-xOf" goto crash', "`"$realTar`" %*", 'exit /b %ERRORLEVEL%', ':crash', 'echo partial-output', 'exit /b -1073741819')
    $binTarDir = New-Dir (Join-Path $fx 'bin-tar-dir')
    Write-Cmd (Join-Path $binTarDir 'tar.cmd') @('@echo off', 'if not "%~1"=="-tf" goto pass', 'for /d %%D in ("%BVTEST_WORKROOT%\backup-verify-*") do mkdir "%%D\state.db"', ':pass', "`"$realTar`" %*", 'exit /b %ERRORLEVEL%')
    $binTarLock = New-Dir (Join-Path $fx 'bin-tar-lock')
    Write-Cmd (Join-Path $binTarLock 'tar.cmd') @(
        '@echo off', 'if not "%~1"=="-tf" goto pass',
        'for /d %%D in ("%BVTEST_WORKROOT%\backup-verify-*") do (',
        '  echo held>"%%D\held.lock"',
        '  icacls "%%D\held.lock" /deny "*S-1-1-0:(D)" >nul',
        '  icacls "%%D" /deny "*S-1-1-0:(DC)" >nul',
        ')', ':pass', "`"$realTar`" %*", 'exit /b %ERRORLEVEL%')
    # 추출 단계에서 끝나지 않는 tar(V20a — 스크립트의 자식 시간 제한이 프로세스 트리를 끝내야 한다). stdin을 읽지 않는다.
    $binTarHang = New-Dir (Join-Path $fx 'bin-tar-hang')
    Write-Cmd (Join-Path $binTarHang 'tar.cmd') @('@echo off', 'if "%~1"=="-xOf" goto hang', "`"$realTar`" %*", 'exit /b %ERRORLEVEL%', ':hang', 'ping -n 3600 127.0.0.1 >nul', 'exit /b 0')

    # ---------- S: 스크립트 원문 ----------
    Test-Group 'S' {
        $bytes = if (Test-Path -LiteralPath $scriptPath -PathType Leaf) { [IO.File]::ReadAllBytes($scriptPath) } else { $null }
        $hasBom = $null -ne $bytes -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $src = if ($null -ne $bytes) { [Text.UTF8Encoding]::new($false).GetString($bytes) } else { '' }
        Assert 'S-1: scripts/backup-verify.ps1 exists, UTF-8 without BOM, LF only, starts with a comment header' (
            $null -ne $bytes -and -not $hasBom -and -not $src.Contains("`r") -and $src.StartsWith('#', [StringComparison]::Ordinal)
        ) "missing, BOM, CR or no header ($scriptPath)"
        Assert 'S-2: script sets $PSNativeCommandUseErrorActionPreference = $false and declares -AgeKeyFile as a mandatory parameter' (
            (Test-Has $src '$PSNativeCommandUseErrorActionPreference = $false') -and $src -match '\[Parameter\(Mandatory\)\]\[string\]\$AgeKeyFile'
        ) 'missing line or parameter declaration'
    }

    # ---------- V1: 정상(로컬 파일 모드) ----------
    Test-Group 'V1' {
        $wr = New-WorkRoot 'v1'
        $keyHash = Get-Sha256 $keyMain
        $keyTime = (Get-Item -LiteralPath $keyMain).LastWriteTimeUtc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) -watchDir $wr
        Assert 'V1-1: valid bundle + snapshot, local file mode -> exit 0, all 11 checks PASS (bv-pre-1 .. bv-pre-3 .. bv-clean), no FAIL line, summary "11 passed, 0 failed"' (Test-AllPass $r $localIds) (Format-Result $r)
        Assert 'V1-2: work directory removed -- no backup-verify-* left under -WorkRoot, bv-clean names the removed backup-verify-<guid>' (
            (Get-WorkDirs $wr).Count -eq 0 -and (Get-CheckLine $r 'bv-clean') -match 'removed backup-verify-[0-9a-f]{32}'
        ) ("left: $((Get-WorkDirs $wr).Name -join ', '); " + (Format-Result $r))
        Assert 'V1-3: the only things created on disk were backup-verify-<guid>/, its state.db, its vault.snap and its tool temp dir tmp/ (no plaintext tar, no -wal/-shm, nothing else)' (
            Test-CreatedExactly $r.created @('state.db', 'vault.snap')
        ) ("created: [$($r.created -join ', ')]")
        $leak = @(foreach ($n in @('bvkey', 'AGE-SECRET-KEY', 'BVTEST-TOKEN-MARKER', 'BVTEST-TLS-MARKER', 'BVTEST-DB-MARKER', 'bvname')) { if (Test-HasI ($r.out + "`n" + $r.err) $n) { $n } })
        Assert 'V1-4: output holds no key path, no AGE-SECRET-KEY, no token/TLS/DB marker and no bundle entry file names' ($leak.Count -eq 0) ("found: $($leak -join ', ')")
        $l1 = Get-Detail $r 'bv-k3s-1'; $l3 = Get-Detail $r 'bv-k3s-3'; $l4 = Get-Detail $r 'bv-k3s-4'; $v1 = Get-Detail $r 'bv-vault-1'; $v3 = Get-Detail $r 'bv-vault-3'
        Assert 'V1-5: details -- ciphertext bytes + sha256 for both, entry counts only ("state.db 1, token 1, cred files 2, tls files 2"), sqlite version + kine rows 350 + max(id) 400 (different values) + bytes, inspect head (Index 45, Term 3) + keys 23 + Total Size' (
            (Test-Has $l1 "$((Get-Item -LiteralPath $k3s['good']).Length) bytes") -and (Test-Has $l1 (Get-Sha256 $k3s['good'])) -and
            (Test-Has $v1 "$((Get-Item -LiteralPath $vault['good']).Length) bytes") -and (Test-Has $v1 (Get-Sha256 $vault['good'])) -and
            (Test-Has $l3 'state.db 1, token 1, cred files 2, tls files 2') -and -not (Test-Has $l3 'problems') -and
            $l4 -match '\Asqlite [0-9]+\.[0-9]+\.[0-9]+, kine rows 350, max\(id\) 400, state\.db [0-9]+ bytes\z' -and
            (Test-Has $v3 'ID bolt-snapshot') -and (Test-Has $v3 'Index 45') -and (Test-Has $v3 'Term 3') -and (Test-Has $v3 'keys 23') -and (Test-Has $v3 'Total Size 14.4KB')
        ) "k3s-1=[$l1] k3s-3=[$l3] k3s-4=[$l4] vault-1=[$v1] vault-3=[$v3]"
        Assert 'V1-6: one "started: <UTC ISO 8601>" and one "finished: <UTC ISO 8601>" line' (
            @($r.lines | Where-Object { $_ -match '\Astarted: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z' }).Count -eq 1 -and
            @($r.lines | Where-Object { $_ -match '\Afinished: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z' }).Count -eq 1
        ) (Format-Result $r)
        Assert 'V1-7: the age identity file is neither modified nor touched (same SHA-256, same mtime)' (
            (Test-Same (Get-Sha256 $keyMain) $keyHash) -and (Get-Item -LiteralPath $keyMain).LastWriteTimeUtc -eq $keyTime
        ) 'key file changed'
        $v3Text = $v3
        Assert 'V1-8: the snapshot key-name table is not printed (no core/ sys/ logical/ key names)' (
            -not (Test-Has $r.out 'core/') -and -not (Test-Has $r.out 'sys/policy') -and -not (Test-Has $r.out 'logical/')
        ) "vault-3=[$v3Text]"
    }

    # ---------- V2: 다른 키 ----------
    Test-Group 'V2' {
        $wr = New-WorkRoot 'v2'
        $r = Invoke-BV @('-AgeKeyFile', $keyOther, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V2-1: a different age key -> FAIL bv-k3s-2 and FAIL bv-vault-2 (age: no identity matched), later checks "not attempted", exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-pre-2' 'PASS') -and (Test-Check $r 'bv-k3s-1' 'PASS') -and (Test-Check $r 'bv-k3s-2' 'FAIL') -and
            (Test-Has (Get-Detail $r 'bv-k3s-2') 'no identity matched') -and (Test-Has (Get-Detail $r 'bv-vault-2') 'no identity matched') -and
            (Test-NotAttempted $r 'bv-k3s-3' 'bv-k3s-2') -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-2') -and
            (Test-Check $r 'bv-vault-1' 'PASS') -and (Test-Check $r 'bv-vault-2' 'FAIL') -and (Test-NotAttempted $r 'bv-vault-3' 'bv-vault-2')
        ) (Format-Result $r)
        Assert 'V2-2: work directory removed after the failures (PASS bv-clean, no backup-verify-* left)' ((Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0) (Format-Result $r)
    }

    # ---------- V3: 잘린 K3s 암호문 ----------
    Test-Group 'V3' {
        $wr = New-WorkRoot 'v3'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['trunc'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V3-1: K3s ciphertext missing its last third -> FAIL bv-k3s-2 (full decryption is not authenticated: age exit 1), bv-k3s-3/4 not attempted, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-1' 'PASS') -and (Test-Check $r 'bv-k3s-2' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-2') 'age exit 1') -and
            (Test-NotAttempted $r 'bv-k3s-3' 'bv-k3s-2') -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-2')
        ) (Format-Result $r)
        Assert 'V3-2: the Vault component is still checked and PASSes (bv-vault-1..3), work directory removed' (
            (Test-Check $r 'bv-vault-1' 'PASS') -and (Test-Check $r 'bv-vault-2' 'PASS') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
    }

    # ---------- V4 · V5: 번들 항목 ----------
    Test-Group 'V4' {
        $wr = New-WorkRoot 'v4'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['nodb'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V4-1: bundle without server/db/state.db -> FAIL bv-k3s-3 showing the count "state.db 0" and the problem "state.db count 0 (want 1)", bv-k3s-4 not attempted, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-2' 'PASS') -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-3') 'state.db 0') -and
            (Test-Has (Get-Detail $r 'bv-k3s-3') 'state.db count 0 (want 1)') -and
            (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-3') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
    }
    Test-Group 'V5' {
        foreach ($c in @(@{ v = 'notoken'; want = 'token count 0 (want 1)' }, @{ v = 'nocred'; want = 'cred files 0 (want >= 1)' }, @{ v = 'notls'; want = 'tls files 0 (want >= 1)' })) {
            $wr = New-WorkRoot "v5-$($c.v)"
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s[$c.v], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
            $l = Get-Detail $r 'bv-k3s-3'
            Assert "V5-$($c.v): bundle $($c.v) -> FAIL bv-k3s-3 with the problem `"$($c.want)`" (counts only), bv-k3s-4 not attempted, exit 1" (
                $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has $l $c.want) -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-3') -and
                -not (Test-HasI $r.out 'bvname') -and (Get-WorkDirs $wr).Count -eq 0
            ) (Format-Result $r)
        }
    }

    # ---------- V6 · V7: state.db 손상 · kine 없음 ----------
    Test-Group 'V6' {
        foreach ($c in @(
                @{ v = 'midzero'; want = 'malformed'; label = 'middle page zeroed' },
                @{ v = 'headzero'; want = 'not a database'; label = 'header zeroed' },
                @{ v = 'idxzero'; want = 'integrity_check returned'; label = 'V6c: name bytes of one row zeroed in the table only (integrity_check returns rows, count/max still work)' })) {
            $wr = New-WorkRoot "v6-$($c.v)"
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s[$c.v], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
            $l = Get-Detail $r 'bv-k3s-4'
            Assert "V6-$($c.v): state.db $($c.label) -> FAIL bv-k3s-4 with a one-line reason naming `"$($c.want)`", no Traceback, k3s-1..3 and vault PASS, exit 1" (
                $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'PASS') -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has $l $c.want) -and
                -not (Test-HasI ($r.out + "`n" + $r.err) 'Traceback') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
            ) (Format-Result $r)
        }
    }
    Test-Group 'V7' {
        $wr = New-WorkRoot 'v7'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['nokine'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V7-1: a sound SQLite file without table kine -> FAIL bv-k3s-4, detail says "table kine not found", exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-4') 'table kine not found') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
        $wr = New-WorkRoot 'v7b'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['emptykine'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V7b: table kine exists but has 0 rows (integrity ok) -> FAIL bv-k3s-4, detail says "table kine has no rows", exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-4') 'table kine has no rows') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
    }

    # ---------- V8: Vault 스냅샷 쓰레기 · 잘림 ----------
    Test-Group 'V8' {
        foreach ($v in @('junk', 'trunc')) {
            $wr = New-WorkRoot "v8-$v"
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault[$v], '-WorkRoot', $wr)
            Assert "V8-${v}: Vault snapshot $v (decrypts fine) -> PASS bv-vault-2, FAIL bv-vault-3 carrying vault's reason (vault exit 1: Error reading snapshot), k3s all PASS, exit 1, work directory removed" (
                $r.code -eq 1 -and (Test-Check $r 'bv-vault-2' 'PASS') -and (Test-Check $r 'bv-vault-3' 'FAIL') -and (Test-Check $r 'bv-k3s-4' 'PASS') -and
                (Test-Has (Get-Detail $r 'bv-vault-3') 'vault exit 1') -and (Test-Has (Get-Detail $r 'bv-vault-3') 'Error reading snapshot') -and (Get-WorkDirs $wr).Count -eq 0
            ) (Format-Result $r)
        }
    }

    # ---------- V9: 인자 하나만 ----------
    Test-Group 'V9' {
        foreach ($c in @(@{ n = 'K3sAge'; a = @('-K3sAge', $k3s['good']) }, @{ n = 'VaultAge'; a = @('-VaultAge', $vault['good']) })) {
            $wr = New-WorkRoot "v9-$($c.n)"
            $r = Invoke-BV (@('-AgeKeyFile', $keyMain) + $c.a + @('-WorkRoot', $wr)) -watchDir $wr
            $checks = @($r.lines | Where-Object { $_ -match '\A(PASS|FAIL) bv-' })
            Assert "V9-$($c.n): only -$($c.n) given -> usage FAIL (one FAIL line, no other check), exit 1, nothing created under -WorkRoot" (
                $r.code -eq 1 -and $checks.Count -eq 1 -and $checks[0].StartsWith('FAIL bv-usage: ', [StringComparison]::Ordinal) -and
                $r.created.Count -eq 0 -and @(Get-ChildItem -LiteralPath $wr -Force).Count -eq 0
            ) ("created: [$($r.created -join ', ')] " + (Format-Result $r))
        }
        # -MaxAgeHours 0(내려받기 모드 인자) — 사용법 오류, 도구 · oci를 부르기 전에 끝난다
        $wr = New-WorkRoot 'v9-maxage'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr, '-MaxAgeHours', '0') -watchDir $wr
        $checks = @($r.lines | Where-Object { $_ -match '\A(PASS|FAIL) bv-' })
        Assert 'V9-maxage: -MaxAgeHours 0 -> usage FAIL naming MaxAgeHours (one FAIL line, no other check), exit 1, nothing created under -WorkRoot' (
            $r.code -eq 1 -and $checks.Count -eq 1 -and $checks[0].StartsWith('FAIL bv-usage: ', [StringComparison]::Ordinal) -and (Test-Has (Get-Detail $r 'bv-usage') 'MaxAgeHours') -and
            $r.created.Count -eq 0 -and @(Get-ChildItem -LiteralPath $wr -Force).Count -eq 0
        ) ("created: [$($r.created -join ', ')] " + (Format-Result $r))
    }

    # ---------- V10: 키 파일 없음 · 키 파일 형식 틀림 ----------
    Test-Group 'V10' {
        $wr = New-WorkRoot 'v10'
        $r = Invoke-BV @('-AgeKeyFile', $keyMissing, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        $na = @($k3sIds + $vaultIds | Where-Object { -not (Test-NotAttempted $r $_ 'bv-pre-2') })
        Assert 'V10-1: -AgeKeyFile names no file -> FAIL bv-pre-2 ("no file"), PASS bv-pre-3, every component check "not attempted (bv-pre-2)", exit 1, work directory removed' (
            $r.code -eq 1 -and (Test-Check $r 'bv-pre-2' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-pre-2') 'no file') -and (Test-Check $r 'bv-pre-3' 'PASS') -and
            $na.Count -eq 0 -and @(Get-ChildItem -LiteralPath $wr -Force).Count -eq 0
        ) ("not marked: $($na -join ', '); " + (Format-Result $r))
        Assert 'V10-2: the missing key path is not in the output (not even its file or directory name)' (-not (Test-HasI ($r.out + "`n" + $r.err) 'bvkey')) (Format-Result $r)

        $wr = New-WorkRoot 'v10b'
        $r = Invoke-BV @('-AgeKeyFile', $keyBad, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        Assert 'V10b-1: a key file that is not an age identity -> PASS bv-pre-2, FAIL bv-k3s-2 and bv-vault-2 carrying age''s reason (unknown identity type), exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-pre-2' 'PASS') -and (Test-Check $r 'bv-k3s-2' 'FAIL') -and (Test-Check $r 'bv-vault-2' 'FAIL') -and
            (Test-Has (Get-Detail $r 'bv-k3s-2') 'unknown identity type') -and (Test-Has (Get-Detail $r 'bv-k3s-2') '<age-key>')
        ) (Format-Result $r)
        Assert 'V10b-2: age quotes the key path in its error (Go %q, doubled backslashes) -- the output still holds no part of it (redacted)' (
            -not (Test-HasI ($r.out + "`n" + $r.err) 'bvkey') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
    }

    # ---------- V11–V13: 내려받기 모드(가짜 oci) ----------
    $k3sPick = "k3s/k3s-$(Get-NameTime 1).tar.age"
    $vaultPick = "vault/vault-$(Get-NameTime 2).snap.age"
    $arabic = -join @(0x0662, 0x0660, 0x0669, 0x0669, 0x0661, 0x0662, 0x0663, 0x0661 | ForEach-Object { [char]$_ })   # 아라비아-인도 숫자 8자(정규식 [0-9]가 아니다)
    $k3sDecoys = @(
        'k3s/k3s-20991231T235959Z.tar.age.tmp',
        ("k3s/k3s-20991231T235959Z.tar.age" + "`n"),
        'k3s/K3S-20991231T235959Z.tar.age',
        'k3s/k3s-20991231T2359Z.tar.age',
        'k3s/sub/k3s-20991231T235959Z.tar.age',
        'k3s/k3s-20991399T996959Z.tar.age',
        "k3s/k3s-${arabic}T235959Z.tar.age",
        'k3s/k3s-20991231T235959Z.tar.gz'
    )
    $vaultDecoys = @(
        'vault/vault-20991231T235959Z.snap.age.partial',
        ("vault/vault-20991231T235959Z.snap.age" + "`n"),
        'vault/vault-20991231T235959Z.snap',
        'vault/Vault-20991231T235959Z.snap.age'
    )
    # $olderHours: 고를 K3s 객체보다 오래된(형식은 맞는) 객체들의 나이 — 미끼 내용이라 잘못 고르면 복호화가 실패한다
    # $k3sCreated: 고를 K3s 객체의 time-created(빈 값이면 이름의 시각 + 20초)
    function New-DlScenario([string]$k3sName, [string]$k3sFile, [string]$vaultName, [string]$vaultFile, [switch]$NoValidK3s, [double[]]$olderHours = @(25, 49), [string]$k3sCreated = '') {
        $list = [Collections.Generic.List[object]]::new()
        $objects = [ordered]@{}
        if (-not $NoValidK3s) {
            $list.Add((New-ListItem $k3sName $k3sFile $k3sCreated)); $objects[$k3sName] = $k3sFile
            foreach ($h in $olderHours) { $n = "k3s/k3s-$(Get-NameTime $h).tar.age"; $list.Add((New-ListItem $n $junkObj)); $objects[$n] = $junkObj }
        }
        foreach ($n in $k3sDecoys) { $list.Add((New-ListItem $n $junkObj)); $objects[$n] = $junkObj }
        $list.Add((New-ListItem $vaultName $vaultFile)); $objects[$vaultName] = $vaultFile
        $n = "vault/vault-$(Get-NameTime 26.5).snap.age"; $list.Add((New-ListItem $n $junkObj)); $objects[$n] = $junkObj
        foreach ($n in $vaultDecoys) { $list.Add((New-ListItem $n $junkObj)); $objects[$n] = $junkObj }
        return [ordered]@{ expired = $false; list = $list.ToArray(); objects = $objects; drop = [ordered]@{} }
    }

    Test-Group 'V11' {
        $wr = New-WorkRoot 'v11'
        $o = New-OciScenario 'v11' (New-DlScenario $k3sPick $k3s['good'] $vaultPick $vault['good'])
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr) $o.env $binOci $wr
        Assert 'V11-1: download mode, listing holds several valid names, malformed names and later-looking malformed names -> exit 0, all 13 checks PASS' (Test-AllPass $r $dlIds) (Format-Result $r)
        Assert 'V11-2: the latest well-formed name is chosen and printed (bv-dl-k3s names the 1 h old bundle, bv-dl-vault the 2 h old snapshot)' (
            (Test-Has (Get-Detail $r 'bv-dl-k3s') $k3sPick) -and (Test-Has (Get-Detail $r 'bv-dl-vault') $vaultPick)
        ) (Format-Result $r)
        $calls = Read-OciLog $o.log
        $lists = @($calls | Where-Object { ($_['argv'] -join ' ').Contains('os object list') })
        $gets = @($calls | Where-Object { ($_['argv'] -join ' ').Contains('os object get') })
        $common = @($calls | Where-Object {
                $j = ' ' + ($_['argv'] -join ' ') + ' '
                (Test-Has $j ' --profile svc-verify ') -and (Test-Has $j ' --auth security_token ') -and (Test-Has $j ' --bucket-name joshuatech-backup-platform ') -and (Test-Same $_['suppress'] 'True')
            })
        $listOk = @($lists | Where-Object { $j = ' ' + ($_['argv'] -join ' ') + ' '; (Test-Has $j ' --all ') -and (Test-Has $j ' --output json ') }).Count -eq 2 -and
            @($lists | Where-Object { (' ' + ($_['argv'] -join ' ') + ' ').Contains(' --prefix k3s/ ') }).Count -eq 1 -and
            @($lists | Where-Object { (' ' + ($_['argv'] -join ' ') + ' ').Contains(' --prefix vault/ ') }).Count -eq 1
        $getNames = @($gets | ForEach-Object { $a = @($_['argv']); $i = [Array]::IndexOf($a, '--name'); if ($i -ge 0) { $a[$i + 1] } })
        Assert 'V11-3: oci is called only for "os object list" (twice: --prefix k3s/ and vault/, --all, --output json) and "os object get" (the two chosen names), always with --profile svc-verify --auth security_token, the bucket, and OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True' (
            $calls.Count -eq 4 -and $lists.Count -eq 2 -and $gets.Count -eq 2 -and $common.Count -eq 4 -and $listOk -and
            ($getNames -ccontains $k3sPick) -and ($getNames -ccontains $vaultPick)
        ) ("calls: " + (@($calls | ForEach-Object { ($_['argv'] -join ' ') + ' suppress=' + $_['suppress'] }) -join ' | '))
        Assert 'V11-4: downloads go into the work directory only -- created: backup-verify-<guid>/ with k3s.tar.age, vault.snap.age, state.db, vault.snap; all removed' (
            (Test-CreatedExactly $r.created @('k3s.tar.age', 'vault.snap.age', 'state.db', 'vault.snap')) -and (Get-WorkDirs $wr).Count -eq 0
        ) ("created: [$($r.created -join ', ')]")
    }

    Test-Group 'V12' {
        $wr = New-WorkRoot 'v12'
        $sc = New-DlScenario $k3sPick $k3s['good'] $vaultPick $vault['good']
        $sc['expired'] = $true
        $o = New-OciScenario 'v12' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr) $o.env $binOci
        $lk = Get-Detail $r 'bv-dl-k3s'; $lv = Get-Detail $r 'bv-dl-vault'
        Assert 'V12-1: OCI session expired -> FAIL bv-dl-k3s and FAIL bv-dl-vault, each telling to re-authenticate (oci session authenticate ... svc-verify), exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Check $r 'bv-dl-vault' 'FAIL') -and
            (Test-Has $lk 'oci session authenticate') -and (Test-Has $lk 'svc-verify') -and (Test-Has $lv 'oci session authenticate')
        ) (Format-Result $r)
        $na = @(@($k3sIds | Where-Object { -not (Test-NotAttempted $r $_ 'bv-dl-k3s') }) + @($vaultIds | Where-Object { -not (Test-NotAttempted $r $_ 'bv-dl-vault') }))
        Assert 'V12-2: every later check is "not attempted (bv-dl-k3s|bv-dl-vault)", work directory removed' ($na.Count -eq 0 -and (Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0) ("not marked: $($na -join ', '); " + (Format-Result $r))
    }

    Test-Group 'V13' {
        # V13a: 받은 크기 ≠ 목록 크기
        $wr = New-WorkRoot 'v13a'
        $sc = New-DlScenario $k3sPick $k3s['good'] $vaultPick $vault['good']
        $sc['drop'] = [ordered]@{ $k3sPick = 7 }
        $o = New-OciScenario 'v13a' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr) $o.env $binOci
        $l = Get-Detail $r 'bv-dl-k3s'
        $want = (Get-Item -LiteralPath $k3s['good']).Length
        Assert 'V13a: downloaded size differs from the listed size (7 bytes short) -> FAIL bv-dl-k3s naming both sizes, k3s checks not attempted, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has $l "$want") -and (Test-Has $l "$($want - 7)") -and
            (Test-NotAttempted $r 'bv-k3s-1' 'bv-dl-k3s') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)

        # V13b: 최신 객체가 MaxAgeHours보다 오래됨
        $oldName = "k3s/k3s-$(Get-NameTime 30).tar.age"
        $wr = New-WorkRoot 'v13b'
        $sc = New-DlScenario $oldName $k3s['good'] $vaultPick $vault['good'] -olderHours @(31, 55)
        $o = New-OciScenario 'v13b' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr) $o.env $binOci
        $l = Get-Detail $r 'bv-dl-k3s'
        Assert 'V13b: latest K3s object is 30 h old (> -MaxAgeHours 26) -> FAIL bv-dl-k3s naming the object and MaxAgeHours, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has $l $oldName) -and (Test-Has $l 'MaxAgeHours') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)

        # V13d: 같은 목록에 -MaxAgeHours 48 → 통과(인자 배선)
        $wr = New-WorkRoot 'v13d'
        $o = New-OciScenario 'v13d' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr, '-MaxAgeHours', '48') $o.env $binOci
        Assert 'V13d: the same 30 h old object with -MaxAgeHours 48 -> all 13 checks PASS, exit 0' ((Test-AllPass $r $dlIds) -and (Test-Has (Get-Detail $r 'bv-dl-k3s') $oldName)) (Format-Result $r)

        # V13c: 형식이 맞는 후보가 없음
        $wr = New-WorkRoot 'v13c'
        $o = New-OciScenario 'v13c' (New-DlScenario '' '' $vaultPick $vault['good'] -NoValidK3s)
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', $wr) $o.env $binOci
        Assert 'V13c: k3s/ holds only malformed names -> FAIL bv-dl-k3s (no object matching the name format), vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') 'no object') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
    }

    # ---------- V14: 도중 비정상 종료 · 예외 ----------
    Test-Group 'V14' {
        $wr = New-WorkRoot 'v14a'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) @{ BVTEST_WORKROOT = $wr } $binTarCrash
        Assert 'V14a: tar (fake, first on PATH) crashes in the extraction step (exit -1073741819) -> FAIL bv-k3s-4 naming the tar exit code, vault PASS, exit 1, work directory removed' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'PASS') -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-4') 'tar exit -1073741819') -and
            (Test-Check $r 'bv-vault-3' 'PASS') -and (Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)

        $wr = New-WorkRoot 'v14b'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) @{ BVTEST_WORKROOT = $wr } $binTarDir
        Assert 'V14b: an exception inside the script (fake tar leaves a directory where state.db is to be written) -> FAIL bv-k3s-4 "unexpected ...", vault still checked, exit 1, work directory (with that subdirectory) removed' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-4') 'unexpected') -and
            (Test-Check $r 'bv-vault-3' 'PASS') -and (Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0 -and $r.err.Length -eq 0
        ) (Format-Result $r)
    }

    # ---------- V15: 공백이 든 경로 ----------
    Test-Group 'V15' {
        $sp = New-Dir (Join-Path $fx 'with space/key dir')
        $spKey = Join-Path $sp 'bvkey main copy.txt'
        $spK3s = Join-Path $fx 'with space/k3s good.tar.age'
        $spVault = Join-Path $fx 'with space/vault good.snap.age'
        Copy-Item -LiteralPath $keyMain -Destination $spKey
        Copy-Item -LiteralPath $k3s['good'] -Destination $spK3s
        Copy-Item -LiteralPath $vault['good'] -Destination $spVault
        $wr = New-Dir (Join-Path $fx 'with space/work root')
        $r = Invoke-BV @('-AgeKeyFile', $spKey, '-K3sAge', $spK3s, '-VaultAge', $spVault, '-WorkRoot', $wr) -watchDir $wr
        Assert 'V15-1: spaces in -WorkRoot, both ciphertext paths and the key path -> same as V1: exit 0, all 11 PASS, work directory removed, only state.db + vault.snap created' (
            (Test-AllPass $r $localIds) -and (Get-WorkDirs $wr).Count -eq 0 -and (Test-CreatedExactly $r.created @('state.db', 'vault.snap'))
        ) ("created: [$($r.created -join ', ')] " + (Format-Result $r))
        Assert 'V15-2: no part of the key path in the output' (-not (Test-HasI ($r.out + "`n" + $r.err) 'bvkey')) (Format-Result $r)
    }

    # ---------- V16: 작업 디렉터리를 지우지 못함(Windows 전용 — 거부 ACE) ----------
    Test-Group 'V16' {
        if (-not $IsWindows) { Write-Host 'SKIP V16 -- deny ACEs need Windows; not counted'; return }
        $wr = New-WorkRoot 'v16'
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) @{ BVTEST_WORKROOT = $wr } $binTarLock
        $left = Get-WorkDirs $wr
        foreach ($d in $left) { $script:aclLocked += $d.FullName }
        $inside = @(if ($left.Count -eq 1) { Get-ChildItem -LiteralPath $left[0].FullName -Force -Recurse | ForEach-Object { $_.Name } })
        $lc = Get-Detail $r 'bv-clean'
        Assert 'V16-1: a file in the work directory cannot be deleted -> FAIL bv-clean naming the leaf backup-verify-<guid> on its own and printing the exact full path for manual removal, exit 1, all other checks PASS' (
            $r.code -eq 1 -and $left.Count -eq 1 -and (Test-Check $r 'bv-clean' 'FAIL') -and (Test-Has $lc ('could not remove ' + $left[0].Name + ';')) -and
            (Test-Has $lc ('full path: ' + $left[0].FullName)) -and (Test-Check $r 'bv-k3s-4' 'PASS') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)
        Assert 'V16-2: everything else was still deleted -- only the undeletable held.lock remains (state.db and vault.snap are gone)' (
            $inside.Count -eq 1 -and (Test-Same $inside[0] 'held.lock')
        ) ("inside: [$($inside -join ', ')]")
    }

    # ---------- V17: 기본 작업 루트 = 사용자 임시 디렉터리(TMP) ----------
    Test-Group 'V17' {
        $tmpDir = New-Dir (Join-Path $fx 'tmp-v17')
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good']) @{ TMP = $tmpDir; TEMP = $tmpDir } '' $tmpDir
        $ours = @($r.created | Where-Object { $_ -match '\Abackup-verify-[0-9a-f]{32}\z' })
        Assert 'V17-1: without -WorkRoot the work directory is backup-verify-<guid> under the user temp directory (TMP) and is removed; all 11 PASS' (
            (Test-AllPass $r $localIds) -and $ours.Count -eq 1 -and (Get-WorkDirs $tmpDir).Count -eq 0
        ) ("created: [$($r.created -join ', ')] " + (Format-Result $r))
        # 스크립트를 띄운 pwsh 자신이 시작할 때 TMP에 만들었다 지우는 정책 시험 파일은 스크립트의 일이 아니라 뺀다
        $mine = @($r.created | Where-Object { $_ -cnotmatch ('\A' + $psPolicyTest + '\z') })
        $outside = @($mine | Where-Object { $ours.Count -ne 1 -or -not ($_ -ceq $ours[0] -or $_.StartsWith("$($ours[0])/", [StringComparison]::Ordinal)) })
        $leftInTmp = @(Get-ChildItem -LiteralPath $tmpDir -Force | ForEach-Object { $_.Name })
        Assert 'V17-2: child tools write their temp files inside the work directory (nothing else appears in TMP -- the vault CLI unpacks a DLL directory into TMP on every start) and TMP is left empty' (
            $ours.Count -eq 1 -and $outside.Count -eq 0 -and (Test-CreatedExactly $mine @('state.db', 'vault.snap')) -and $leftInTmp.Count -eq 0
        ) ("outside: [$($outside -join ', ')]; left in TMP: [$($leftInTmp -join ', ')]; created: [$($r.created -join ', ')]")
    }

    # ---------- V18: 상대 경로($PWD ≠ .NET cwd) ----------
    Test-Group 'V18' {
        $wr = New-WorkRoot 'v18'
        $q = { param($s) "'" + $s.Replace("'", "''") + "'" }
        $cmd = "Set-Location -LiteralPath $(& $q $fx); & $(& $q $scriptPath) -AgeKeyFile 'bvkey-main.txt' -K3sAge 'k3s-good.tar.age' -VaultAge 'vault-good.snap.age' -WorkRoot 'wr-v18'; exit `$LASTEXITCODE"
        $r = Invoke-BV -command $cmd -watchDir $wr
        Assert 'V18-1: relative -AgeKeyFile/-K3sAge/-VaultAge/-WorkRoot after Set-Location (the .NET cwd stays elsewhere) resolve against $PWD -> all 11 PASS, work directory removed' (
            (Test-AllPass $r $localIds) -and (Get-WorkDirs $wr).Count -eq 0 -and (Test-CreatedExactly $r.created @('state.db', 'vault.snap'))
        ) ("created: [$($r.created -join ', ')] " + (Format-Result $r))
    }

    # ---------- V19: 신선도(B1) — 미래 이름 · time-created · 나이 경계 ----------
    # 이름의 시각은 UTC다(이 PC가 UTC가 아니면 AssumeLocal 같은 실수가 경계 케이스에서 드러난다).
    Test-Group 'V19' {
        $script:now = [DateTime]::UtcNow
        $good1 = "k3s/k3s-$(Get-NameTime 1).tar.age"
        $fails = @{}
        # V19a: 형식이 맞는 3시간 뒤 이름(내용은 정상 번들) + 정상 1시간 전 객체
        $future = "k3s/k3s-$(Get-NameTime -3).tar.age"
        $sc = New-DlScenario $good1 $k3s['good'] $vaultPick $vault['good']
        $sc['list'] = @($sc['list']) + @(New-ListItem $future $k3s['good'])
        $sc['objects'][$future] = $k3s['good']
        $o = New-OciScenario 'v19a' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19a')) $o.env $binOci
        $d = Get-Detail $r 'bv-dl-k3s'
        Assert 'V19a: a well-formed object name dated 3 h in the future next to a normal 1 h old object -> FAIL bv-dl-k3s naming it ("dated more than 5 min in the future"), k3s checks not attempted, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has $d 'dated more than 5 min in the future') -and (Test-Has $d $future) -and
            (Test-NotAttempted $r 'bv-k3s-1' 'bv-dl-k3s') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)

        # V19b: 2분 뒤 이름(시계 차이 허용 안) → 고르고 통과
        $soon = "k3s/k3s-$(Get-NameTime (-2.0 / 60)).tar.age"
        $o = New-OciScenario 'v19b' (New-DlScenario $soon $k3s['good'] $vaultPick $vault['good'])
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19b')) $o.env $binOci
        Assert 'V19b: the latest name is 2 min in the future (within the 5 min tolerance) -> chosen, all 13 checks PASS' ((Test-AllPass $r $dlIds) -and (Test-Has (Get-Detail $r 'bv-dl-k3s') $soon)) (Format-Result $r)

        # V19c: 이름은 1시간 전인데 time-created는 40일 전
        $o = New-OciScenario 'v19c' (New-DlScenario $good1 $k3s['good'] $vaultPick $vault['good'] -k3sCreated (Format-Created $script:now.AddDays(-40)))
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19c')) $o.env $binOci
        $d = Get-Detail $r 'bv-dl-k3s'
        Assert 'V19c: name 1 h old but time-created 40 days old -> FAIL bv-dl-k3s, detail says time-created is older than -MaxAgeHours, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has $d 'time-created') -and (Test-Has $d 'MaxAgeHours') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)

        # V19d: 나이 경계 25.9시간(통과) · 26.1시간(실패) — 이름 시각을 UTC로 읽어야 맞는다
        $script:now = [DateTime]::UtcNow
        $n259 = "k3s/k3s-$(Get-NameTime 25.9).tar.age"
        $o = New-OciScenario 'v19d1' (New-DlScenario $n259 $k3s['good'] $vaultPick $vault['good'] -olderHours @(30, 49))
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19d1')) $o.env $binOci
        Assert 'V19d-25.9h: latest object 25.9 h old (name and time-created) -> PASS with -MaxAgeHours 26 (the name time is UTC regardless of this PC''s time zone)' ((Test-AllPass $r $dlIds) -and (Test-Has (Get-Detail $r 'bv-dl-k3s') $n259)) (Format-Result $r)
        $script:now = [DateTime]::UtcNow
        $n261 = "k3s/k3s-$(Get-NameTime 26.1).tar.age"
        $o = New-OciScenario 'v19d2' (New-DlScenario $n261 $k3s['good'] $vaultPick $vault['good'] -olderHours @(30, 49))
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19d2')) $o.env $binOci
        Assert 'V19d-26.1h: latest object 26.1 h old -> FAIL bv-dl-k3s naming MaxAgeHours, vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') 'MaxAgeHours') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)

        # V19e: time-created를 읽을 수 없음
        $o = New-OciScenario 'v19e' (New-DlScenario $good1 $k3s['good'] $vaultPick $vault['good'] -k3sCreated 'not-a-time')
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19e')) $o.env $binOci
        Assert 'V19e: time-created "not-a-time" -> FAIL bv-dl-k3s ("time-created ... cannot be parsed"), vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') 'cannot be parsed') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)

        # V19f: 이름 2시간 전 · time-created 3.5시간 전(둘 다 26시간 안) — 차이 1.5시간
        $script:now = [DateTime]::UtcNow
        $n2 = "k3s/k3s-$(Get-NameTime 2).tar.age"
        $o = New-OciScenario 'v19f' (New-DlScenario $n2 $k3s['good'] $vaultPick $vault['good'] -olderHours @(30, 49) -k3sCreated (Format-Created $script:now.AddHours(-3.5)))
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v19f')) $o.env $binOci
        Assert 'V19f: name time and time-created 1.5 h apart (both within 26 h) -> FAIL bv-dl-k3s ("differ by ... more than 1 h"), vault PASS, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') 'differ by') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)
    }

    # ---------- V20: 자식 시간 제한 · state.db 쓰기 실패(B5) ----------
    Test-Group 'V20' {
        # V20a: 추출 단계의 tar가 끝나지 않는다 → 줄인 시간 제한(5초)이 프로세스 트리를 끝내고 FAIL
        $wr = New-WorkRoot 'v20a'
        $pingBefore = @(Get-Process -Name 'PING' -ErrorAction SilentlyContinue).Count
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) @{ BACKUP_VERIFY_CHILD_TIMEOUT_SEC = '5' } $binTarHang -watchdogSec 90
        Start-Sleep -Milliseconds 500
        $pingAfter = @(Get-Process -Name 'PING' -ErrorAction SilentlyContinue).Count
        $notes = @($r.lines | Where-Object { $_.StartsWith('note: ', [StringComparison]::Ordinal) })
        Assert 'V20a: tar never ends in the extraction step, BACKUP_VERIFY_CHILD_TIMEOUT_SEC=5 -> a "note:" line, FAIL bv-k3s-4 "timed out after 5 s", vault PASS, exit 1, finished well within the harness watchdog, work directory removed' (
            -not $r.timedOut -and $r.code -eq 1 -and $r.secs -lt 60 -and $notes.Count -eq 1 -and (Test-Has $notes[0] 'BACKUP_VERIFY_CHILD_TIMEOUT_SEC') -and (Test-Has $notes[0] '5 s') -and
            (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-4') 'timed out after 5 s') -and (Test-Check $r 'bv-vault-3' 'PASS') -and
            (Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
        ) ("secs=$([Math]::Round($r.secs, 1)) " + (Format-Result $r))
        Assert 'V20a-2: the hung tar process tree was ended (no PING process left behind)' ($pingAfter -le $pingBefore) "PING before=$pingBefore after=$pingAfter"

        # V20a-3: 시간 제한은 줄이기만 된다 — 기본(600초)보다 큰 값은 무시하고 그렇다고 알린다(정상 실행)
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot 'v20a3')) @{ BACKUP_VERIFY_CHILD_TIMEOUT_SEC = '9999' }
        $notes = @($r.lines | Where-Object { $_.StartsWith('note: ', [StringComparison]::Ordinal) })
        Assert 'V20a-3: BACKUP_VERIFY_CHILD_TIMEOUT_SEC=9999 (longer than the default) is ignored with a "note:" line saying so; all 11 PASS' (
            (Test-AllPass $r $localIds) -and $notes.Count -eq 1 -and (Test-Has $notes[0] 'ignored')
        ) (Format-Result $r)

        # V20b: 오류 주입 사본 — state.db를 쓰는 스트림이 64 KiB 뒤 '디스크 공간 부족' 예외를 던진다(스크립트 원문의 FileStream 생성 한 곳을 바꾼 사본)
        $src = [IO.File]::ReadAllText($scriptPath)
        $anchor = '$PSNativeCommandUseErrorActionPreference = $false' + "`n"
        $fsNew = '[IO.FileStream]::new($OutFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)'
        $ai = $src.IndexOf($anchor, [StringComparison]::Ordinal); $fi = $src.IndexOf($fsNew, [StringComparison]::Ordinal)
        $once = $ai -ge 0 -and $src.IndexOf($anchor, $ai + 1, [StringComparison]::Ordinal) -lt 0 -and $fi -ge 0 -and $src.IndexOf($fsNew, $fi + 1, [StringComparison]::Ordinal) -lt 0
        Assert 'V20b-0: fault-injection anchors found exactly once in the script under test ($PSNativeCommandUseErrorActionPreference line, the state.db FileStream)' $once "anchor at $ai, FileStream at $fi"
        if ($once) {
            $cs = @(
                'namespace BvTest { public class FullDisk : System.IO.FileStream {',
                '  long n;',
                '  public FullDisk(string p) : base(p, System.IO.FileMode.CreateNew, System.IO.FileAccess.Write, System.IO.FileShare.None) {}',
                '  void Check(int c) { n += c; if (n > 65536) throw new System.IO.IOException("There is not enough space on the disk. : ''" + Name + "''"); }',
                '  public override void Write(byte[] b, int o, int c) { Check(c); base.Write(b, o, c); }',
                '  public override void Write(System.ReadOnlySpan<byte> b) { Check(b.Length); base.Write(b); }',
                '  public override System.Threading.Tasks.Task WriteAsync(byte[] b, int o, int c, System.Threading.CancellationToken t) { Check(c); return base.WriteAsync(b, o, c, t); }',
                '  public override System.Threading.Tasks.ValueTask WriteAsync(System.ReadOnlyMemory<byte> b, System.Threading.CancellationToken t = default(System.Threading.CancellationToken)) { Check(b.Length); return base.WriteAsync(b, t); }',
                '} }') -join "`n"
            $inject = "Add-Type -TypeDefinition @'`n" + $cs + "`n'@`n"
            $faulty = $src.Substring(0, $ai + $anchor.Length) + $inject + $src.Substring($ai + $anchor.Length)
            $faulty = $faulty.Replace($fsNew, '[BvTest.FullDisk]::new($OutFile)')
            $faultFile = Join-Path (New-Dir (Join-Path $fx 'fault')) 'backup-verify.fault.ps1'
            [IO.File]::WriteAllText($faultFile, $faulty, [Text.UTF8Encoding]::new($false))
            $wr = New-WorkRoot 'v20b'
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr) @{ BACKUP_VERIFY_CHILD_TIMEOUT_SEC = '30' } -scriptFile $faultFile -watchdogSec 90
            $d = Get-Detail $r 'bv-k3s-4'
            Assert 'V20b: writing state.db fails part-way (disk full) -> age and tar are ended at once, FAIL bv-k3s-4 "writing state.db failed: ... not enough space ..." (path shown as <work>), vault PASS, exit 1, well before the 30 s limit, work directory removed' (
                -not $r.timedOut -and $r.code -eq 1 -and $r.secs -lt 25 -and (Test-Check $r 'bv-k3s-4' 'FAIL') -and (Test-Has $d 'writing state.db failed') -and
                (Test-Has $d 'not enough space') -and (Test-Has $d '<work>') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Test-Check $r 'bv-clean' 'PASS') -and (Get-WorkDirs $wr).Count -eq 0
            ) ("secs=$([Math]::Round($r.secs, 1)) " + (Format-Result $r))
        }
    }

    # ---------- V21: 앞 실행이 남긴 작업 디렉터리(B6) ----------
    Test-Group 'V21' {
        $wr = New-WorkRoot 'v21'
        $old1 = New-Dir (Join-Path $wr 'backup-verify-0123456789abcdef0123456789abcdef')
        [IO.File]::WriteAllText((Join-Path $old1 'state.db'), 'leftover', [Text.UTF8Encoding]::new($false))
        $old2 = New-Dir (Join-Path $wr 'backup-verify-leftover')
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        $d = Get-Detail $r 'bv-pre-3'
        $after = @(Get-WorkDirs $wr | ForEach-Object { $_.Name } | Sort-Object)
        Assert 'V21-1: two backup-verify-* directories already under the work root -> FAIL bv-pre-3 "2 found: <their names>", every other check still runs and PASSes, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-pre-3' 'FAIL') -and $d.StartsWith('2 found: ', [StringComparison]::Ordinal) -and
            (Test-Has $d 'backup-verify-0123456789abcdef0123456789abcdef') -and (Test-Has $d 'backup-verify-leftover') -and
            (Test-Check $r 'bv-k3s-4' 'PASS') -and (Test-Check $r 'bv-vault-3' 'PASS') -and (Test-Check $r 'bv-clean' 'PASS') -and (Get-Summary $r).fail -eq 1
        ) (Format-Result $r)
        Assert 'V21-2: the leftovers are reported, not deleted (both still there with their content); this run''s own work directory is gone' (
            $after.Count -eq 2 -and (Test-Path -LiteralPath (Join-Path $old1 'state.db')) -and (Test-Path -LiteralPath $old2)
        ) ("left: [$($after -join ', ')]")
    }

    # ---------- V22: 없는 드라이브 — 예외 문구가 영어 ASCII로 읽힌다(B7) ----------
    Test-Group 'V22' {
        $used = @([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name.Substring(0, 1).ToUpperInvariant() })
        $letter = @('Y', 'X', 'W', 'V', 'U', 'T', 'S', 'R', 'Q', 'P', 'O', 'N', 'L', 'K', 'J', 'I', 'H') | Where-Object { $used -notcontains $_ } | Select-Object -First 1
        if (-not $letter) { Write-Host 'SKIP V22 -- no unused drive letter; not counted'; return }
        $wr = New-WorkRoot 'v22'
        $r = Invoke-BV @('-AgeKeyFile', "${letter}:\bvkey-nodrive\key.txt", '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', $wr)
        $na = @($k3sIds + $vaultIds | Where-Object { -not (Test-NotAttempted $r $_ 'bv-pre-2') })
        Assert "V22a: -AgeKeyFile on a drive that does not exist (${letter}:) -> FAIL bv-pre-2 with the English reason ""Cannot find drive"", no run of '?' in the output, components not attempted, exit 1" (
            $r.code -eq 1 -and (Test-Check $r 'bv-pre-2' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-pre-2') 'Cannot find drive') -and -not (Test-Has $r.out '??') -and
            $na.Count -eq 0 -and -not (Test-HasI ($r.out + "`n" + $r.err) 'bvkey') -and (Get-WorkDirs $wr).Count -eq 0
        ) (Format-Result $r)
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', "${letter}:\bv-nodrive\k3s.tar.age", '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot 'v22b'))
        Assert "V22b: -K3sAge on a drive that does not exist -> FAIL bv-k3s-1 with ""Cannot find drive"" (no '??'), later k3s checks not attempted, vault PASS, exit 1" (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-1' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-1') 'Cannot find drive') -and -not (Test-Has $r.out '??') -and
            (Test-NotAttempted $r 'bv-k3s-2' 'bv-k3s-1') -and (Test-Check $r 'bv-vault-3' 'PASS')
        ) (Format-Result $r)
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['good'], '-VaultAge', $vault['good'], '-WorkRoot', "${letter}:\bv-nodrive-root")
        Assert "V22c: -WorkRoot on a drive that does not exist -> usage FAIL with ""Cannot find drive"" (no '??'), exit 1" (
            $r.code -eq 1 -and (Test-Check $r 'bv-usage' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-usage') 'Cannot find drive') -and -not (Test-Has $r.out '??')
        ) (Format-Result $r)
    }

    # ---------- V23: oci 목록이 JSON이 아님 — 원문을 싣지 않는다(B9) ----------
    Test-Group 'V23' {
        $sc = New-DlScenario $k3sPick $k3s['good'] $vaultPick $vault['good']
        $sc['listRaw'] = 'BVTEST-OCI-STDOUT-MARKER this is not json'
        $o = New-OciScenario 'v23' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v23')) $o.env $binOci
        Assert 'V23: the listing is not JSON -> FAIL bv-dl-k3s and bv-dl-vault saying "is not JSON" with the output length only (the raw stdout is not printed), exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') 'is not JSON') -and (Test-Has (Get-Detail $r 'bv-dl-k3s') '41 characters') -and
            (Test-Check $r 'bv-dl-vault' 'FAIL') -and -not (Test-Has $r.out 'BVTEST-OCI-STDOUT-MARKER')
        ) (Format-Result $r)
    }

    # ---------- V24: 홈 · 임시 폴더 · 대소문자가 다른 표기의 가림(B10) ----------
    # oci가 경로를 담은 오류문을 내면(설정 파일 · 로그 위치) 홈은 <home>, 임시 폴더는 <tmp>로 — 대소문자가 다르게 적혀도 가린다.
    Test-Group 'V24' {
        $homeP = [Environment]::GetFolderPath('UserProfile')
        $tempP = [IO.Path]::GetTempPath().TrimEnd('\', '/')
        $sc = New-DlScenario $k3sPick $k3s['good'] $vaultPick $vault['good']
        $sc['listFail'] = "ServiceError: could not read $homeP\.oci\config-bvredact-a; see $tempP\oci-bvredact-b.log; also $($homeP.ToUpperInvariant())\.OCI\CONFIG-BVREDACT-C"
        $o = New-OciScenario 'v24' $sc
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-WorkRoot', (New-WorkRoot 'v24')) $o.env $binOci
        $d = Get-Detail $r 'bv-dl-k3s'
        Assert 'V24: an oci error naming paths under the user home and the temp folder (one written in upper case) -> shown as <home>\.oci\..., <tmp>\..., <home>\.OCI\...; the home path appears nowhere in any case' (
            $r.code -eq 1 -and (Test-Check $r 'bv-dl-k3s' 'FAIL') -and (Test-Has $d '<home>\.oci\config-bvredact-a') -and (Test-Has $d '<tmp>\oci-bvredact-b.log') -and
            (Test-Has $d '<home>\.OCI\CONFIG-BVREDACT-C') -and -not (Test-HasI ($r.out + "`n" + $r.err) $homeP)
        ) (Format-Result $r)
    }

    # ---------- V25: 별칭 이름 · 중복 항목(B3) ----------
    Test-Group 'V25' {
        foreach ($c in @(
                @{ v = 'alias-dotslash'; hide = './server' }, @{ v = 'alias-dblslash'; hide = 'server//db' }, @{ v = 'alias-dotseg'; hide = 'server/./db' },
                @{ v = 'alias-dotdot'; hide = 'db/../db' }, @{ v = 'alias-outside'; hide = 'other/' })) {
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s[$c.v], '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot "v25-$($c.v)"))
            $d = Get-Detail $r 'bv-k3s-3'
            Assert "V25-$($c.v): a normal bundle plus one entry under a non-canonical name -> FAIL bv-k3s-3 ""1 entry name(s) not in canonical form"" (count only, the name is not printed), state.db not extracted (bv-k3s-4 not attempted), exit 1" (
                $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has $d '1 entry name(s) not in canonical form') -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-3') -and
                -not (Test-Has $r.out $c.hide) -and (Test-Check $r 'bv-vault-3' 'PASS')
            ) (Format-Result $r)
        }
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['dup-db'], '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot 'v25-dup-db'))
        $d = Get-Detail $r 'bv-k3s-3'
        Assert 'V25-dup-db: server/db/state.db twice under the same canonical name -> FAIL bv-k3s-3 with "state.db count 2 (want 1)" and "1 duplicated name(s)", bv-k3s-4 not attempted, exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has $d 'state.db count 2 (want 1)') -and (Test-Has $d '1 duplicated name(s)') -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-3')
        ) (Format-Result $r)
        $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s['dup-cred'], '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot 'v25-dup-cred'))
        Assert 'V25-dup-cred: one server/cred/ file twice -> FAIL bv-k3s-3 "1 duplicated name(s)" (the name is not printed), exit 1' (
            $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has (Get-Detail $r 'bv-k3s-3') '1 duplicated name(s)') -and -not (Test-HasI $r.out 'bvname')
        ) (Format-Result $r)
    }

    # ---------- V26: 항목 종류 · 크기 — 일반 파일이고 크기 > 0인 것만 센다(B4) ----------
    Test-Group 'V26' {
        foreach ($c in @(
                @{ v = 'db-symlink'; want = 'state.db count 0 (want 1)' }, @{ v = 'db-empty'; want = 'state.db count 0 (want 1)' },
                @{ v = 'token-symlink'; want = 'token count 0 (want 1)' }, @{ v = 'cred-hardlink'; want = 'cred files 0 (want >= 1)' },
                @{ v = 'cred-dironly'; want = 'cred files 0 (want >= 1)' }, @{ v = 'tls-empty'; want = 'tls files 0 (want >= 1)' })) {
            $r = Invoke-BV @('-AgeKeyFile', $keyMain, '-K3sAge', $k3s[$c.v], '-VaultAge', $vault['good'], '-WorkRoot', (New-WorkRoot "v26-$($c.v)"))
            $d = Get-Detail $r 'bv-k3s-3'
            Assert "V26-$($c.v): only a non-regular or empty entry there -> FAIL bv-k3s-3 with ""$($c.want)"" and nothing else wrong (the entry's kind is recognized, not 'not understood'), bv-k3s-4 not attempted, exit 1" (
                $r.code -eq 1 -and (Test-Check $r 'bv-k3s-3' 'FAIL') -and (Test-Has $d $c.want) -and -not (Test-Has $d 'not understood') -and -not (Test-Has $d 'canonical') -and
                -not (Test-Has $d 'duplicated') -and (Test-NotAttempted $r 'bv-k3s-4' 'bv-k3s-3') -and -not (Test-HasI $r.out 'bvname')
            ) (Format-Result $r)
        }
    }

    # ---------- G: 모든 실행에 공통인 규율 ----------
    Test-Group 'G' {
        $runs = @($script:runs | Where-Object { -not $_.missing })
        $missing = @($script:runs | Where-Object { $_.missing }).Count
        $min = if ($only.Count -gt 0) { 1 } else { 55 }
        Assert "G-0: the script ran ($($runs.Count) runs, $missing with the script missing; at least $min expected)" ($missing -eq 0 -and $runs.Count -ge $min) "runs=$($runs.Count) missing=$missing"
        $leaks = @()
        $nonAscii = @()
        $badLines = @()
        $badSummary = @()
        $noTimes = @()
        $stderr = @()
        $watchdog = @()
        $i = 0
        foreach ($r in $runs) {
            $i++
            $all = $r.out + "`n" + $r.err
            if ($r.timedOut) { $watchdog += "run ${i}: killed after $([Math]::Round($r.secs, 1)) s" }
            foreach ($n in @('bvkey', 'AGE-SECRET-KEY', 'BVTEST-TOKEN-MARKER', 'BVTEST-TLS-MARKER', 'BVTEST-DB-MARKER', 'BVTEST-OCI-STDOUT-MARKER', 'bvname', 'Traceback')) { if (Test-HasI $all $n) { $leaks += "run ${i}: $n" } }
            foreach ($ch in $r.out.ToCharArray()) { if (([int]$ch -lt 0x20 -and $ch -ne "`n" -and $ch -ne "`r") -or [int]$ch -gt 0x7E) { $nonAscii += "run ${i}: U+$(([int]$ch).ToString('X4'))"; break } }
            foreach ($l in $r.lines) {
                if ($l -match '\A(PASS|FAIL) ') {
                    $ok = $l -match '\A(PASS|FAIL) bv-[a-z0-9-]+: \S.* -- .*\z' -or $l -match '\AFAIL bv-[a-z0-9-]+: not attempted \(bv-[a-z0-9-]+\)\z'
                    if (-not $ok) { $badLines += "run ${i}: $l" }
                }
            }
            $s = Get-Summary $r
            $np = (Get-LinesWithPrefix $r.lines 'PASS ').Count
            $nf = (Get-LinesWithPrefix $r.lines 'FAIL ').Count
            if ($null -eq $s -or $s.pass -ne $np -or $s.fail -ne $nf -or ($nf -gt 0 -and $r.code -ne 1) -or ($nf -eq 0 -and $r.code -ne 0)) { $badSummary += "run ${i}: code=$($r.code) pass=$np fail=$nf summary=$(if ($s) { "$($s.pass)/$($s.fail)" } else { 'none' })" }
            if (@($r.lines | Where-Object { $_ -match '\Astarted: ' }).Count -ne 1 -or @($r.lines | Where-Object { $_ -match '\Afinished: ' }).Count -ne 1) { $noTimes += "run $i" }
            if ($r.err.Length -gt 0) { $stderr += "run ${i}: $($r.err)" }
        }
        Assert 'G-1: no run printed a key path fragment, AGE-SECRET-KEY, a dummy secret marker, a bundle entry name or a Python Traceback (stdout + stderr)' ($leaks.Count -eq 0) ($leaks -join ' | ')
        Assert 'G-2: every run''s stdout is ASCII only' ($nonAscii.Count -eq 0) ($nonAscii -join ' | ')
        Assert 'G-3: every check line is "PASS|FAIL <id>: <description> -- <detail>" or "FAIL <id>: not attempted (<id>)"' ($badLines.Count -eq 0) ($badLines -join ' | ')
        Assert 'G-4: every run ends with "N passed, N failed" matching its PASS/FAIL line counts, and exits 0 exactly when there is no FAIL (1 otherwise)' ($badSummary.Count -eq 0) ($badSummary -join ' | ')
        Assert 'G-5: every run prints one started: and one finished: line' ($noTimes.Count -eq 0) ($noTimes -join ', ')
        Assert 'G-6: no run wrote anything to stderr (no unhandled PowerShell error)' ($stderr.Count -eq 0) ($stderr -join ' | ')
        Assert 'G-7: no run had to be killed by the harness watchdog (the script ends on its own, even when a child hangs)' ($watchdog.Count -eq 0) ($watchdog -join ' | ')
    }
} finally {
    # V16의 거부 ACE를 풀고 임시 픽스처 루트를 지운다(이 하네스가 만든 bvtest-<guid>만)
    foreach ($p in $script:aclLocked) {
        $lock = Join-Path $p 'held.lock'
        if (Test-Path -LiteralPath $lock) { $null = & icacls $lock /remove:d '*S-1-1-0' 2>&1 }
        if (Test-Path -LiteralPath $p) { $null = & icacls $p /remove:d '*S-1-1-0' 2>&1 }
    }
    if ($script:tmpRoot -and (Test-Path -LiteralPath $script:tmpRoot) -and ([IO.Path]::GetFileName($script:tmpRoot)).StartsWith('bvtest-', [StringComparison]::Ordinal)) {
        Remove-Item -LiteralPath $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Assert 'cleanup: the temporary fixture root (keys, plaintext fixtures, work roots) is gone' ($null -eq $script:tmpRoot -or -not (Test-Path -LiteralPath $script:tmpRoot)) "left: $($script:tmpRoot)"

Write-Host "elapsed: $([Math]::Round($script:sw.Elapsed.TotalSeconds, 1)) s"
$suffix = ''
if ($only.Count -gt 0) { $suffix += " (filtered: $($only -join ','))" }
if ($scriptOverride) { $suffix += " (script override: $([IO.Path]::GetFileName($scriptPath)))" }
Write-Host "`n$($script:pass) passed, $($script:fail) failed$suffix"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
