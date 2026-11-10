# scripts/backup-verify.ps1 — T048 백업 복원 가능성 검증: 최신 K3s 번들 · Vault Raft 스냅샷(age 암호문)을 운영자 개인키로 풀어 무결성을 본다.
#
# 목적: 노드 A의 platform-backup.sh가 매일 Object Storage(joshuatech-backup-platform)에 올리는 두 백업이 "복원할 수 있는 물건인가"를 확인한다.
#   복원 리허설이 아니다. 클러스터 · 버킷을 바꾸는 동작은 하나도 없다 — OCI 목록 · 내려받기(읽기)와 로컬 임시 파일뿐이다.
#   운영자가 자기 워크스테이션에서 개인키로 직접 실행한다(T048 기록 · 복원 런북 · 정기 점검에서 다시 쓴다).
#
# 실행 예:
#   내려받기 모드(버킷에서 최신 객체를 고른다 — OCI svc-verify 세션이 살아 있어야 한다):
#     pwsh -NoProfile -File scripts/backup-verify.ps1 -AgeKeyFile <age 개인키 파일>
#   로컬 파일 모드(이미 내려받은 암호문 — OCI 호출 없음, 둘 다 준다):
#     pwsh -NoProfile -File scripts/backup-verify.ps1 -AgeKeyFile <age 개인키 파일> -K3sAge <k3s-….tar.age> -VaultAge <vault-….snap.age>
#   그 밖의 인자: -Bucket(기본 joshuatech-backup-platform) · -OciProfile(기본 svc-verify) · -MaxAgeHours(기본 26) ·
#     -WorkRoot(작업 디렉터리를 만들 곳, 기본 사용자 임시 디렉터리 — 있는 디렉터리여야 한다).
#   암호로 보호된 개인키 파일은 시험하지 않았다 — age의 stdin은 콘솔을 그대로 물려받으므로 복호화마다(4번) 암호를 물을 것으로 본다.
#
# 계약(T048 지시서 — tests/scripts/backup-verify.tests.ps1이 시험한다):
#   - -K3sAge와 -VaultAge를 둘 다 주면 로컬 파일 모드, 둘 다 생략하면 내려받기 모드. 하나만 주면 사용법 오류(FAIL bv-usage · exit 1 ·
#     아무것도 만들지 않는다). -MaxAgeHours < 1 · 없는(또는 풀 수 없는) -WorkRoot도 사용법 오류다.
#   - 내려받기 모드: oci --profile <OciProfile> --auth security_token os object list --bucket-name <Bucket> --prefix k3s/|vault/ --all
#     --output json 의 객체 중 이름이 k3s/k3s-<YYYYMMDD>T<HHMMSS>Z.tar.age · vault/vault-<YYYYMMDD>T<HHMMSS>Z.snap.age 형식에 정확히
#     맞고(대소문자 구분 · ASCII 숫자 · 전체 일치) 시각이 실제 날짜인 것만 후보로 삼는다(이름의 시각은 UTC다). 후보 중 이름의 시각이
#     지금(UTC)보다 5분 넘게 미래인 것이 하나라도 있으면 FAIL(그런 이름이 있다는 것 자체가 이상이다 — 그 이름들을 보여 준다).
#     아니면 이름의 ordinal 정렬 마지막(= 이름 시각이 가장 늦은 것)을 고르고 이름 · 크기 · 생성 시각을 출력한다. FAIL: 이름 시각이
#     MaxAgeHours보다 오래됨 · time-created를 읽을 수 없음 · time-created가 MaxAgeHours보다 오래됨 · 둘의 차이가 1시간 초과(노드는 스냅샷을
#     뜬 직후에 올린다). os object get으로 작업 디렉터리에 받고 받은 크기 = 목록 크기를 확인한다. 세션이 만료됐으면 재인증 명령을
#     알려 준다. 목록이 JSON이 아니면 그 길이만 말한다(원문을 싣지 않는다).
#   - 검사 줄 'PASS|FAIL <id>: <설명> -- <detail>'(ASCII만), 앞 단계가 실패한 검사는 'FAIL <id>: not attempted (<앞 id>)',
#     마지막 줄 'N passed, N failed', exit 0 = FAIL 0. 한 컴포넌트가 실패해도 다른 컴포넌트는 계속 본다. 그 밖의 줄: started: · mode: ·
#     note:(시간 제한을 줄였을 때) · finished:.
#       bv-pre-1   도구: age · tar · vault · 파이썬(sqlite3 모듈 — py -3 · python3 · python 순 첫 번째) · 내려받기 모드면 oci. 없으면 여기서
#                  끝(작업 디렉터리를 지우는 bv-clean만 뒤따른다).
#       bv-pre-2   -AgeKeyFile이 있는 파일이다(경로는 출력하지 않는다 — 풀 수 없는 경로면 그 사유만). 아니면 컴포넌트 검사 전부 not attempted.
#       bv-pre-3   작업 루트에 앞 실행이 남긴 backup-verify-* 디렉터리가 없다. 있으면 FAIL '<개수> found: <끝 이름들>'(지우지 않는다 —
#                  강제 종료된 실행의 평문이 남아 있을 수 있으니 운영자가 확인하고 지운다). 나머지 검사는 계속한다.
#       bv-dl-k3s · bv-dl-vault   (내려받기 모드만) 위의 선택 · 신선도 · 내려받기 · 크기 대조.
#       bv-k3s-1   암호문 바이트 수 · SHA-256.
#       bv-k3s-2   전체 복호화 인증: age -d가 exit 0(평문은 메모리에서 세고 버린다 — age는 인증된 청크만 내보내고 잘린 암호문은 끝에서 실패한다).
#       bv-k3s-3   번들 항목(age -d | tar -tf - 로 이름, age -d | tar -tvf - 로 종류 · 크기 — 같은 순서, 둘 다 화면에 싣지 않는다):
#                  모든 항목 이름이 정규 형태(server/로 시작 · 빈 성분 · . · .. 성분 · 역슬래시 없음 — 디렉터리의 끝 /는 허용) · 같은 이름의
#                  중복 없음 · 일반 파일이고 크기 > 0인 것만 세어 server/db/state.db 정확히 1 · server/token 정확히 1 · server/cred/ 아래
#                  1개 이상 · server/tls/ 아래 1개 이상. detail은 개수와 문제의 개수만(이름을 출력하지 않는다). -tv의 크기 칸은 GNU tar
#                  (모드 · 소유자/그룹 · 크기 …)와 bsdtar(모드 · 링크 수 · 소유자 · 그룹 · 크기 …) 모양이 달라 둘 다 읽는다(날짜 칸은
#                  로캘마다 달라 읽지 않는다).
#       bv-k3s-4   state.db만 추출(age -d | tar -xOf - server/db/state.db → 작업 디렉터리의 state.db, 크기 > 0) → 파이썬 sqlite3로
#                  PRAGMA integrity_check 결과가 정확히 'ok' 한 줄 · 테이블 kine이 있고 행이 1개 이상. detail: SQLite 버전 · kine 행 수 ·
#                  max(id) · 바이트 수. DB는 mode=ro&immutable=1로 연다 — kine의 .backup 사본은 WAL 모드라 그냥 읽기 전용으로 열면
#                  -wal · -shm 파일이 생긴다. state.db 쓰기가 실패하면(디스크 가득 등) age와 tar를 바로 끝내고 FAIL.
#       bv-vault-1 암호문 바이트 수 · SHA-256.   bv-vault-2  age -d -o <작업 디렉터리>/vault.snap이 exit 0.
#       bv-vault-3 vault operator raft snapshot inspect(서버 없이 파일만 읽는다)가 exit 0이고 머리에 Index · Term 정수 줄이 있다.
#                  detail: ID · Size · Index · Term · Version · 키 행 수 · Total Size. 키 이름 표는 출력하지 않는다(마운트 식별자가 들어 있다).
#       bv-clean   작업 디렉터리 삭제 확인. 성공 · 실패 · 예외 어느 경로로 끝나든 finally에서 지운다(원본은 버킷에 있어 잃는 것이 없다).
#                  지우지 못하면 FAIL하고 끝 이름(backup-verify-<guid>)과 전체 경로를 따로 출력한다(운영자가 직접 지운다 — 이 줄만 경로를
#                  가리지 않는다. 경로에 ASCII 밖의 글자가 있으면 ?가 되므로 끝 이름으로도 찾을 수 있게).
#   - 자식 프로세스를 기다리는 곳마다 시간 제한(기본 600초 — oci 호출 포함)을 둔다. 넘으면 그 프로세스 트리를 끝내고 그 검사 FAIL.
#     환경 변수 BACKUP_VERIFY_CHILD_TIMEOUT_SEC(1–599)로 줄일 수만 있다(시험용 — 적용되면 'note:' 줄, 그 밖의 값은 무시하고 'note:' 줄).
#   - 시작 · 끝 시각을 'started: <UTC ISO 8601>' · 'finished: <UTC ISO 8601>'로 한 줄씩 출력한다(런북에 옮겨 적을 값).
#   - UI 문화권을 en-US로 둔다 — 한국어 로캘에서는 PowerShell 예외 문구가 ASCII 출력에서 ?의 연속이 되어 사유를 읽을 수 없다.
#   - 작업 디렉터리: <WorkRoot 또는 사용자 임시 디렉터리>/backup-verify-<guid>. 사용법 검사를 통과하면 자식 프로세스를 하나라도 띄우기
#     전에 만든다. <work>/tmp는 모든 자식 프로세스의 TMP · TEMP · TMPDIR다 — 도구가 남기는 임시 파일도 함께 지워진다(vault CLI 2.1.0은
#     시작할 때마다 TMP에 gosnowflake-cgo<숫자>/ DLL 디렉터리를 풀고 지우지 않는다).
#     상대 경로 인자는 PowerShell 현재 위치($PWD) 기준으로 푼다(.NET의 cwd는 Set-Location을 따르지 않는다 — 저장소 CLAUDE.md Known Issues).
#
# 비밀 규율:
#   - 개인키 파일의 경로와 내용, server/token 등 번들 항목의 내용을 어디에도 출력하지 않는다. 개인키 파일은 age에 경로로만 넘기고
#     읽거나 복사 · 수정하지 않는다.
#   - 평문 tar를 디스크에 쓰지 않는다 — 복호화 평문은 age → tar 사이의 메모리 파이프로만 흐른다(PowerShell 파이프라인이 아니라 두 프로세스를
#     직접 잇는다 — age와 tar의 종료 코드를 따로 본다). 디스크에 생기는 평문은 작업 디렉터리 안의 state.db와 vault.snap 둘뿐이다.
#   - 자식 프로세스의 출력을 detail에 실을 때 개인키 경로 · 암호문 경로 · 작업 디렉터리 · WorkRoot · 임시 디렉터리 · 홈 디렉터리를
#     <age-key> · <k3s-age> · <vault-age> · <work> · <work-root> · <tmp> · <home>으로 가린다(ordinal 치환 — 원문 · / 구분 · 역슬래시 두 겹
#     (age가 Go %q로 경로를 인용한다) · /c/… 형을 모두 긴 것부터). 그 뒤 공백을 접고 ASCII 밖의 글자는 ?로 바꾸고 자른다.
#   - 자격 증명을 이 스크립트가 다루지 않는다: OCI는 svc-verify 세션 프로필을 oci CLI가 읽고, 개인키는 운영자가 경로로 준다.
#
# 종료 코드: 0 = FAIL 0, 1 = FAIL 1개 이상(사용법 오류 · 예상하지 못한 오류 포함).
#Requires -Version 7.5
param(
    [Parameter(Mandatory)][string]$AgeKeyFile,   # 운영자 age 개인키 파일. 경로도 내용도 출력하지 않는다
    [string]$K3sAge,                             # 이미 내려받은 암호문(둘 다 주거나 둘 다 생략)
    [string]$VaultAge,
    [string]$Bucket = 'joshuatech-backup-platform',
    [string]$OciProfile = 'svc-verify',
    [int]$MaxAgeHours = 26,                      # 내려받기 모드에서 최신 객체의 나이 상한(매일 1회 백업 + 여유)
    [string]$WorkRoot                            # 기본 = 사용자 임시 디렉터리
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
[cultureinfo]::CurrentUICulture = 'en-US'   # 예외 문구를 영어로(ASCII 출력에서 읽을 수 있게)

$inv = [Globalization.CultureInfo]::InvariantCulture
$utf8 = [Text.UTF8Encoding]::new($false)
$script:pass = 0
$script:fail = 0
$script:redact = @()       # @{ s = 가릴 문자열; tag = 대체 } — 긴 것부터
$script:tools = @{}
$script:work = $null
$script:toolTmp = $null    # 자식 프로세스의 TMP · TEMP · TMPDIR(<work>/tmp)
$script:keyFull = $null
$script:keyError = $null   # -AgeKeyFile을 풀 수 없을 때의 사유
$script:k3sFull = $null; $script:k3sError = $null
$script:vaultFull = $null; $script:vaultError = $null

# 자식 프로세스 시간 제한(초). BACKUP_VERIFY_CHILD_TIMEOUT_SEC로 줄이기만 할 수 있다(시험용).
$script:childTimeoutDefault = 600
$script:childTimeout = $script:childTimeoutDefault
$script:timeoutNote = $null
$tv = [Environment]::GetEnvironmentVariable('BACKUP_VERIFY_CHILD_TIMEOUT_SEC')
if (-not [string]::IsNullOrEmpty($tv)) {
    $tn = 0
    if ($tv -match '\A[0-9]{1,6}\z' -and [int]::TryParse($tv, [ref]$tn) -and $tn -ge 1 -and $tn -lt $script:childTimeoutDefault) {
        $script:childTimeout = $tn
        $script:timeoutNote = "note: child process time limit shortened to $tn s by BACKUP_VERIFY_CHILD_TIMEOUT_SEC (default $($script:childTimeoutDefault) s)"
    } else {
        $script:timeoutNote = "note: BACKUP_VERIFY_CHILD_TIMEOUT_SEC ignored (it can only shorten the $($script:childTimeoutDefault) s limit: give 1 to $($script:childTimeoutDefault - 1))"
    }
}

# 이름 형식(전체 일치 — \z라 끝의 개행도 거른다. [0-9]라 다른 문자 체계의 숫자도 거른다. 대소문자 구분)
$script:namePattern = @{
    k3s   = '\Ak3s/k3s-([0-9]{8}T[0-9]{6}Z)\.tar\.age\z'
    vault = '\Avault/vault-([0-9]{8}T[0-9]{6}Z)\.snap\.age\z'
}
$script:nameShape = @{ k3s = 'k3s/k3s-<YYYYMMDD>T<HHMMSS>Z.tar.age'; vault = 'vault/vault-<YYYYMMDD>T<HHMMSS>Z.snap.age' }

# 파이썬 판정기(stdin으로 넘긴다 — 파일을 만들지 않는다). argv[1] = state.db. 어떤 예외도 JSON 한 줄로 바꾼다(추적 출력 없음).
$script:sqliteCheck = @'
import json, pathlib, sqlite3, sys
out = {'sqlite': sqlite3.sqlite_version}
stage = 'open'
try:
    con = sqlite3.connect(pathlib.Path(sys.argv[1]).resolve().as_uri() + '?mode=ro&immutable=1', uri=True)
    try:
        stage = 'integrity_check'
        rows = [str(r[0]) for r in con.execute('PRAGMA integrity_check').fetchall()]
        out['integrity_rows'] = len(rows)
        out['integrity'] = rows[:3]
        stage = 'table kine lookup'
        out['kine'] = con.execute("SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'kine'").fetchone()[0] == 1
        if out['kine']:
            stage = 'kine count'
            n, m = con.execute('SELECT count(*), max(id) FROM kine').fetchone()
            out['rows'] = n
            out['max_id'] = m
    finally:
        con.close()
except BaseException as e:
    out['error'] = '{} raised {}: {}'.format(stage, type(e).__name__, e)
print(json.dumps(out, ensure_ascii=True))
'@
$script:pythonProbe = "import sqlite3, sys`nprint(sys.version.split()[0], sqlite3.sqlite_version)`n"

# ---------- 출력 ----------
function Get-UtcStamp { return [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv) }
function ConvertTo-Ascii([string]$s) { return ($s -replace '[^ -~]', '?') }

# 가릴 경로 등록: 원문 · / 구분 · 역슬래시 두 겹(Go %q) · /c/… 형. 짧은 문자열(4자 미만)은 등록하지 않는다(엉뚱한 곳을 가리지 않게).
function Add-Redaction([string]$s, [string]$tag) {
    if ([string]::IsNullOrEmpty($s)) { return }
    $s = $s.TrimEnd('\', '/')
    if ($s.Length -lt 4) { return }
    $forms = @($s, $s.Replace('\', '/'), $s.Replace('\', '\\'))
    if ($s.Length -ge 3 -and $s[1] -eq ':' -and ($s[2] -eq '\' -or $s[2] -eq '/')) { $forms += '/' + [char]::ToLowerInvariant($s[0]) + '/' + $s.Substring(3).Replace('\', '/') }
    foreach ($f in $forms) { $script:redact += @{ s = $f; tag = $tag } }
    $script:redact = @($script:redact | Sort-Object -Property @{ Expression = { $_.s.Length }; Descending = $true })
}
function Redact([string]$s) {
    if ($null -eq $s) { return '' }
    foreach ($x in $script:redact) { $s = $s.Replace($x.s, $x.tag, [StringComparison]::OrdinalIgnoreCase) }
    return $s
}
function Clip([string]$s, [int]$max = 400) {
    $t = ConvertTo-Ascii (((Redact "$s") -replace '\s+', ' ').Trim())   # 자르기 전에 가린다 — 잘린 경로 조각이 치환을 비껴가지 않게
    if ($t.Length -le $max) { return $t }
    return $t.Substring(0, $max) + '...'
}
# -Raw: 가리지 않는다(bv-clean 실패 줄 — 운영자가 지울 경로를 그대로 보여 준다). ASCII 변환 · 공백 접기는 한다.
function Write-Check([string]$id, [bool]$ok, [string]$desc, [string]$detail, [switch]$Raw) {
    $d = if ($Raw) { ConvertTo-Ascii (($detail -replace '\s+', ' ').Trim()) } else { Clip $detail }
    if ($ok) { $script:pass++; Write-Host "PASS ${id}: $desc -- $d" }
    else { $script:fail++; Write-Host "FAIL ${id}: $desc -- $d" }
}
function Write-NotAttempted([string]$id, [string]$by) { $script:fail++; Write-Host "FAIL ${id}: not attempted ($by)" }
function Get-LastLine([string]$s) { $l = @("$s" -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }); if ($l.Count -gt 0) { return $l[-1] }; return '' }

# 한 검사: $blocker가 있으면 'not attempted', 아니면 본문(@{ ok; detail })을 실행해 줄을 찍는다. 본문의 예외는 그 검사의 FAIL이 된다.
# 돌려주는 값 = 다음 검사의 blocker(통과면 $null, 실패면 이 id, 이미 막혀 있었으면 그 blocker).
function Invoke-Step([string]$id, [string]$desc, [string]$blocker, [scriptblock]$body) {
    if (-not [string]::IsNullOrEmpty($blocker)) { Write-NotAttempted $id $blocker; return $blocker }
    $res = $null
    try { $res = @(& $body)[-1] }
    catch { $res = @{ ok = $false; detail = "unexpected $($_.Exception.GetType().Name): $($_.Exception.Message)" } }
    if ($res -isnot [hashtable]) { $res = @{ ok = $false; detail = 'unexpected: the check produced no result' } }
    $ok = [bool]$res.ok
    Write-Check $id $ok $desc ([string]$res.detail)
    if ($ok) { return $null }
    return $id
}

# ---------- 경로 ----------
# 상대 경로는 PowerShell 현재 위치 기준으로 푼다(.NET API는 $PWD가 아니라 프로세스 cwd를 쓴다).
# @{ path; error } — 풀 수 없으면(없는 드라이브 등) path = $null, error = 가장 안쪽 예외의 문구
function Resolve-UserPath([string]$p) {
    try { return @{ path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p); error = $null } }
    catch { return @{ path = $null; error = (Get-InnerMessage $_.Exception) } }
}
function Get-InnerMessage([Exception]$e) { while ($null -ne $e.InnerException) { $e = $e.InnerException }; return $e.Message }

# ---------- 자식 프로세스(셸을 거치지 않는다 — 인자는 ArgumentList로 하나씩, 공백 경로도 그대로) ----------
function Start-Native([string]$exe, [string[]]$argv, [switch]$Stdin, [hashtable]$Environment) {
    $psi = [Diagnostics.ProcessStartInfo]::new($exe)
    foreach ($a in $argv) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.StandardErrorEncoding = $utf8
    if ($Stdin) { $psi.RedirectStandardInput = $true; $psi.StandardInputEncoding = $utf8 }
    # 자식의 임시 파일은 작업 디렉터리 안(<work>/tmp)으로 — 함께 지워진다(vault CLI는 시작할 때마다 TMP에 DLL 디렉터리를 풀고 남긴다)
    if ($null -ne $script:toolTmp) { foreach ($n in @('TMP', 'TEMP', 'TMPDIR')) { $psi.Environment[$n] = $script:toolTmp } }
    if ($null -ne $Environment) { foreach ($k in $Environment.Keys) { $psi.Environment[$k] = [string]$Environment[$k] } }
    return [Diagnostics.Process]::Start($psi)
}
function Close-Native($p) {
    if ($null -eq $p) { return }
    try { if (-not $p.HasExited) { $p.Kill($true) } } catch { }
    try { $p.Dispose() } catch { }
}
# 남은 밀리초(시간 제한까지)
function Get-RemainingMs([datetime]$deadline) { return [int][Math]::Max(0, [Math]::Min([double][int]::MaxValue, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)) }
# 작업을 기다린다 — 끝나면 $null, 끝나기 전에 시간 제한이 지나면 'timeout', 출력 복사 작업($outTask)이 실패하면 'output'
function Wait-Task($task, [datetime]$deadline, $outTask) {
    while ($true) {
        $done = $false
        try { $done = $task.Wait(200) } catch { $done = $true }   # 실패로 끝난 작업은 Wait가 예외를 던진다 — 끝난 것으로 본다
        if ($done) { return $null }
        if ($null -ne $outTask -and $outTask.IsFaulted) { return 'output' }
        if ([DateTime]::UtcNow -gt $deadline) { return 'timeout' }
    }
}
# 텍스트 작업의 결과(제한 시간 안에 끝나지 않았거나 실패했으면 '')
function Get-TaskText($task, [int]$ms) { if ($null -eq $task) { return '' }; try { if ($task.Wait($ms)) { return [string]$task.Result } } catch { }; return '' }

# 실행해 끝날 때까지(시간 제한 안에서) 기다리고 @{ code; out; err }(텍스트)를 돌려준다. -StdinText를 주면 stdin으로 쓰고 닫는다.
#   시간 제한(기본 = 자식 시간 제한)을 넘기면 프로세스 트리를 끝내고 code -1 · err 'timed out after N s'.
function Invoke-Native([string]$exe, [string[]]$argv, [string]$StdinText, [hashtable]$Environment, [int]$TimeoutSec = -1) {
    if ($TimeoutSec -le 0) { $TimeoutSec = $script:childTimeout }
    $hasIn = $PSBoundParameters.ContainsKey('StdinText')
    $p = Start-Native $exe $argv -Stdin:$hasIn -Environment $Environment
    try {
        $o = $p.StandardOutput.ReadToEndAsync()
        $e = $p.StandardError.ReadToEndAsync()
        if ($hasIn) { try { $p.StandardInput.Write($StdinText); $p.StandardInput.Close() } catch { } }
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            Close-Native $p
            return @{ code = -1; out = ''; err = "timed out after $TimeoutSec s (process tree ended)" }
        }
        $p.WaitForExit()
        return @{ code = $p.ExitCode; out = (Get-TaskText $o ($TimeoutSec * 1000)); err = (Get-TaskText $e ($TimeoutSec * 1000)) }
    } finally { Close-Native $p }
}

# 평문 펌프: $src를 끝까지 읽어 $dst(없으면 버림)로 쓰고 @{ bytes; stop }을 돌려준다. 읽기 · 쓰기는 비동기로 하고 기다리는 동안
#   시간 제한($deadline)과 출력 복사 작업($outTask)의 실패를 본다 — 그러면 stop = 'timeout' | 'output'으로 멈춘다(호출부가 자식을 끝낸다).
#   $dst 쪽이 먼저 닫히면(tar가 일찍 끝남) 나머지는 읽어서 버린다 — age가 파이프 쓰기에서 멈추지 않고 제 종료 코드로 끝나게.
function Copy-Plain([IO.Stream]$src, [IO.StreamWriter]$dst, [datetime]$deadline, $outTask) {
    $buf = [byte[]]::new(65536)
    $total = [long]0
    $open = $null -ne $dst
    $stop = $null
    while ($true) {
        if ($null -ne $outTask -and $outTask.IsFaulted) { $stop = 'output'; break }
        $rt = $src.ReadAsync($buf, 0, $buf.Length)
        $stop = Wait-Task $rt $deadline $outTask
        if ($null -ne $stop) { break }
        if (-not $rt.IsCompletedSuccessfully) { break }   # 읽기 실패 = 끝(age의 종료 코드가 사유를 말한다)
        $n = $rt.Result
        if ($n -le 0) { break }
        $total += $n
        if ($open) {
            $wt = $null
            try { $wt = $dst.BaseStream.WriteAsync($buf, 0, $n) } catch { $open = $false }
            if ($null -ne $wt) {
                $stop = Wait-Task $wt $deadline $outTask
                if ($null -ne $stop) { break }
                if (-not $wt.IsCompletedSuccessfully) { $open = $false }
            }
        }
    }
    if ($null -eq $stop -and $null -ne $dst) { try { $dst.Close() } catch { } }
    return @{ bytes = $total; stop = $stop }
}

# age -d로 암호문 전체를 풀고 평문은 메모리 파이프로만 흘린다(디스크에 쓰지 않는다).
#   -TarArgs 없음  평문을 세고 버린다(전체 복호화 인증)
#   -TarArgs 있음  평문을 tar의 stdin으로 넘긴다. -OutFile이 있으면 tar의 stdout을 그 파일(새 파일만)로, 없으면 텍스트로 돌려준다
# age와 tar의 종료 코드를 따로 돌려준다. 시간 제한을 넘기거나 -OutFile 쓰기가 실패하면 age와 tar를 바로 끝내고
#   stop = 'timeout' | 'output'(그때 outError = 쓰기 예외의 문구)으로 돌려준다 — 종료 코드는 $null.
function Invoke-AgePipe([string]$Enc, [string[]]$TarArgs, [string]$OutFile) {
    $res = @{ ageCode = $null; tarCode = $null; bytes = [long]0; text = ''; ageErr = ''; tarErr = ''; stop = $null; outError = $null }
    $deadline = [DateTime]::UtcNow.AddSeconds($script:childTimeout)
    $fs = $null; $age = $null; $tar = $null
    try {
        if (-not [string]::IsNullOrEmpty($OutFile)) { $fs = [IO.FileStream]::new($OutFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None) }
        $age = Start-Native $script:tools['age'] @('-d', '-i', $script:keyFull, $Enc)
        $ageErr = $age.StandardError.ReadToEndAsync()
        $sink = $null; $tarOut = $null; $tarErr = $null; $copyTask = $null
        if ($null -ne $TarArgs -and $TarArgs.Count -gt 0) {
            $tar = Start-Native $script:tools['tar'] $TarArgs -Stdin
            $tarErr = $tar.StandardError.ReadToEndAsync()
            if ($null -ne $fs) { $tarOut = $tar.StandardOutput.BaseStream.CopyToAsync($fs); $copyTask = $tarOut } else { $tarOut = $tar.StandardOutput.ReadToEndAsync() }
            $sink = $tar.StandardInput
        }
        $pump = Copy-Plain $age.StandardOutput.BaseStream $sink $deadline $copyTask
        $res.bytes = $pump.bytes
        $res.stop = $pump.stop
        if ($null -eq $res.stop -and -not $age.WaitForExit((Get-RemainingMs $deadline))) { $res.stop = 'timeout' }
        if ($null -eq $res.stop -and $null -ne $tar) {
            $res.stop = Wait-Task $tarOut $deadline $copyTask
            if ($null -eq $res.stop -and -not $tar.WaitForExit((Get-RemainingMs $deadline))) { $res.stop = 'timeout' }
        }
        if ($null -ne $copyTask -and $copyTask.IsFaulted) { $res.stop = 'output'; $res.outError = Get-InnerMessage $copyTask.Exception }
        if ($null -ne $res.stop) {
            Close-Native $age; $age = $null   # 프로세스 트리를 바로 끝낸다
            Close-Native $tar; $tar = $null
        } else {
            $age.WaitForExit()
            $res.ageCode = $age.ExitCode
            if ($null -ne $tar) {
                $tar.WaitForExit()
                $res.tarCode = $tar.ExitCode
                if ($null -eq $fs) { $res.text = Get-TaskText $tarOut 5000 }
            }
        }
        $res.ageErr = Get-TaskText $ageErr 5000
        $res.tarErr = Get-TaskText $tarErr 5000
    } finally {
        Close-Native $age
        Close-Native $tar
        if ($null -ne $fs) { try { $fs.Dispose() } catch { } }
    }
    return $res
}
# 멈춘 파이프의 사유(검사 detail용)
function Get-StopText($p, [string]$what) {
    if ($p.stop -eq 'output') { return "writing $what failed: $($p.outError); age and tar were ended" }
    return "timed out after $($script:childTimeout) s; age and tar were ended"
}

# ---------- 도구 ----------
function Get-Command1([string]$name) { return Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1 }
# py -3 · python3 · python 순으로 sqlite3 모듈을 import할 수 있는 첫 번째(Windows 스토어 별칭처럼 실행만 되는 것은 거른다)
function Find-Python {
    foreach ($c in @(@{ n = 'py'; a = @('-3'); label = 'py -3' }, @{ n = 'python3'; a = @(); label = 'python3' }, @{ n = 'python'; a = @(); label = 'python' })) {
        $cmd = Get-Command1 $c.n
        if ($null -eq $cmd) { continue }
        try { $r = Invoke-Native $cmd.Source (@($c.a) + @('-')) -StdinText $script:pythonProbe -TimeoutSec ([Math]::Min(60, $script:childTimeout)) } catch { continue }
        $m = [regex]::Match("$($r.out)".Trim(), '\A(\S+) ([0-9][0-9.]*)\z')
        if ($r.code -eq 0 -and $m.Success) { return @{ exe = $cmd.Source; pre = @($c.a); label = $c.label; version = $m.Groups[1].Value; sqlite = $m.Groups[2].Value } }
    }
    return $null
}
# 버전 문자열(첫 줄의 앞부분만). 실패해도 도구가 있으면 통과다.
function Get-ToolVersion([string]$exe, [string[]]$argv, [string]$cut) {
    try {
        $r = Invoke-Native $exe $argv -TimeoutSec ([Math]::Min(30, $script:childTimeout))
        $first = "$(@("$($r.out)" -split "`r?`n" | Where-Object { $_.Trim().Length -gt 0 }) | Select-Object -First 1)".Trim()
        $i = $first.IndexOf($cut, [StringComparison]::Ordinal)
        if ($i -gt 0) { $first = $first.Substring(0, $i) }
        if ($first.Length -gt 40) { $first = $first.Substring(0, 40) }
        if ($first.Length -gt 0) { return $first }
    } catch { }
    return 'version unknown'
}
function Find-Tools([bool]$download) {
    $missing = @()
    $names = @('age', 'tar', 'vault')
    if ($download) { $names += 'oci' }
    foreach ($n in $names) {
        $c = Get-Command1 $n
        if ($null -ne $c) { $script:tools[$n] = $c.Source } else { $missing += $n }
    }
    $py = Find-Python
    if ($null -ne $py) { $script:tools['py'] = $py } else { $missing += 'python with the sqlite3 module (py -3, python3, python)' }
    if ($missing.Count -gt 0) { return @{ ok = $false; detail = "not found on PATH: $($missing -join ', ')" } }
    # 문자열 안의 $( ) 에 짝이 맞지 않는 괄호 문자열을 두지 않는다(PowerShell 토크나이저가 그 괄호를 센다) — 변수로 먼저 받는다
    $vAge = Get-ToolVersion $script:tools['age'] @('--version') ' '
    $vTar = Get-ToolVersion $script:tools['tar'] @('--version') ' - '
    $vVault = Get-ToolVersion $script:tools['vault'] @('version') ' ('
    # tar · vault의 버전 문자열에는 이름이 들어 있다(bsdtar 3.8.8 · tar (GNU tar) 1.35 · Vault v2.1.0)
    if ($vTar -eq 'version unknown') { $vTar = 'tar version unknown' }
    if ($vVault -eq 'version unknown') { $vVault = 'vault version unknown' }
    $parts = @("age $vAge", $vTar, $vVault, "python $($py.version) ($($py.label)), sqlite $($py.sqlite)")
    if ($download) { $parts += 'oci found' }
    return @{ ok = $true; detail = ($parts -join '; ') }
}

# ---------- 검사 본문 ----------
# $resolveError: 경로를 풀 수 없었을 때의 사유(없는 드라이브 등) — 그러면 그 사유로 FAIL
function Get-FileFacts([string]$path, [string]$resolveError) {
    if (-not [string]::IsNullOrEmpty($resolveError)) { return @{ ok = $false; detail = "the path cannot be resolved: $resolveError" } }
    if ([string]::IsNullOrEmpty($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ ok = $false; detail = 'file not found' } }
    $len = (Get-Item -LiteralPath $path).Length
    if ($len -le 0) { return @{ ok = $false; detail = 'file is empty (0 bytes)' } }
    $h = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    return @{ ok = $true; detail = "$len bytes, sha256 $h" }
}

# 이름 형식 검사: 형식에 정확히 맞고 시각이 실제 날짜일 때만 그 UTC 시각, 아니면 $null
function Get-ObjectTime([string]$name, [string]$kind) {
    $m = [regex]::Match($name, $script:namePattern[$kind], [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    if (-not $m.Success) { return $null }
    $t = [datetime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if (-not [datetime]::TryParseExact($m.Groups[1].Value, "yyyyMMdd'T'HHmmss'Z'", $inv, $styles, [ref]$t)) { return $null }
    return $t
}
function Get-OciHint($r) {
    if ("$($r.out)`n$($r.err)".IndexOf('session has expired', [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        return "OCI session has expired; re-authenticate with: oci session authenticate --profile-name $OciProfile (then rerun)"
    }
    return "oci exit $($r.code): $(Get-LastLine $r.err)"
}
# 내려받기: 목록 → 형식이 맞는 이름 중 이름 시각이 가장 늦은 것 → 나이 상한 → 작업 디렉터리로 get → 받은 크기 = 목록 크기
function Get-LatestBackup([string]$kind, [string]$prefix, [string]$dest) {
    $common = @('--profile', $OciProfile, '--auth', 'security_token')
    $envOci = @{ OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING = 'True' }
    $r = Invoke-Native $script:tools['oci'] ($common + @('os', 'object', 'list', '--bucket-name', $Bucket, '--prefix', $prefix, '--all', '--output', 'json')) -Environment $envOci
    if ($r.code -ne 0) { return @{ ok = $false; detail = "listing $prefix failed; $(Get-OciHint $r)" } }
    $doc = $null
    # 원문은 싣지 않는다(무엇이 들었을지 모른다) — 길이만
    try { $doc = "$($r.out)" | ConvertFrom-Json -AsHashtable -DateKind String } catch { return @{ ok = $false; detail = "listing $prefix is not JSON ($("$($r.out)".Length) characters of output, not shown)" } }
    $items = @()
    if ($doc -is [Collections.IDictionary] -and $null -ne $doc['data']) { $items = @($doc['data']) }
    $cands = [Collections.Generic.List[object]]::new()
    foreach ($o in $items) {
        if ($o -isnot [Collections.IDictionary]) { continue }
        $name = [string]$o['name']
        $t = Get-ObjectTime $name $kind
        if ($null -eq $t) { continue }   # 형식이 틀린 이름은 후보가 아니다
        $cands.Add(@{ name = $name; time = $t; size = $o['size']; created = [string]$o['time-created'] })
    }
    if ($cands.Count -eq 0) { return @{ ok = $false; detail = "no object matching $($script:nameShape[$kind]) under $prefix ($($items.Count) listed)" } }
    $nowUtc = [DateTime]::UtcNow
    # 이름의 시각이 5분 넘게 미래인 객체가 있으면 그것 자체가 이상이다(노드 시계 · 다른 업로더) — 고르지 않고 FAIL
    $future = [string[]]@($cands | Where-Object { $_.time -gt $nowUtc.AddMinutes(5) } | ForEach-Object { $_.name })
    if ($future.Count -gt 0) {
        [Array]::Sort($future, [StringComparer]::Ordinal)
        $shown = (@($future | Select-Object -First 3) -join ', ') + $(if ($future.Count -gt 3) { ', ...' } else { '' })
        return @{ ok = $false; detail = "$($future.Count) object name(s) under $prefix dated more than 5 min in the future (now $($nowUtc.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", $inv))): $shown; check the node clock and the bucket" }
    }
    # 이름의 ordinal 정렬 마지막 = 이름 시각이 가장 늦은 것(접두가 같고 시각이 고정 폭이다)
    $names = [string[]]@($cands | ForEach-Object { $_.name })
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $pick = $null
    foreach ($c in $cands) { if ([string]::Equals($c.name, $names[-1], [StringComparison]::Ordinal)) { $pick = $c } }
    $ageH = ($nowUtc - $pick.time).TotalHours
    $desc = "$($pick.name), listed $($pick.size) bytes, created $($pick.created), name time $($ageH.ToString('0.0', $inv)) h ago"
    if ($ageH -gt $MaxAgeHours) { return @{ ok = $false; detail = "latest is $desc; older than -MaxAgeHours $MaxAgeHours (is the daily backup running?)" } }
    # time-created(버킷이 기록한 업로드 시각)도 본다 — 이름만 최근인 오래된 객체를 걸러 낸다
    $created = [DateTimeOffset]::MinValue
    if ([string]::IsNullOrEmpty($pick.created) -or -not [DateTimeOffset]::TryParse($pick.created, $inv, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$created)) {
        return @{ ok = $false; detail = "$desc; its time-created cannot be parsed" }
    }
    $cAgeH = ($nowUtc - $created.UtcDateTime).TotalHours
    if ($cAgeH -gt $MaxAgeHours) { return @{ ok = $false; detail = "$desc; its time-created is $($cAgeH.ToString('0.0', $inv)) h old, older than -MaxAgeHours $MaxAgeHours" } }
    $diffH = [Math]::Abs(($pick.time - $created.UtcDateTime).TotalHours)
    if ($diffH -gt 1) { return @{ ok = $false; detail = "$desc; name time and time-created differ by $($diffH.ToString('0.0', $inv)) h (more than 1 h; the node uploads right after the snapshot)" } }
    if ($null -eq $pick.size) { return @{ ok = $false; detail = "$desc; the listing has no size for it" } }
    $g = Invoke-Native $script:tools['oci'] ($common + @('os', 'object', 'get', '--bucket-name', $Bucket, '--name', $pick.name, '--file', $dest)) -Environment $envOci
    if ($g.code -ne 0) { return @{ ok = $false; detail = "$desc; download failed; $(Get-OciHint $g)" } }
    if (-not (Test-Path -LiteralPath $dest -PathType Leaf)) { return @{ ok = $false; detail = "$desc; download produced no file" } }
    $got = (Get-Item -LiteralPath $dest).Length
    if ($got -ne [long]$pick.size) { return @{ ok = $false; detail = "$desc; downloaded $got bytes but the listing says $($pick.size) bytes" } }
    return @{ ok = $true; detail = "$desc; downloaded $got bytes"; path = $dest }
}

# 번들 항목 이름의 정규 형태: server/로 시작 · 역슬래시 없음 · 빈 성분(//) · '.' · '..' 성분 없음(디렉터리 항목의 끝 /는 허용).
# 절대 경로 · ./server/… · server//… · server/./… 같은 별칭 표기는 복원할 때 같은 파일로 겹쳐 써진다 — "정확히 1" 검사를 비껴간다.
function Test-CanonicalName([string]$n) {
    if ($n.IndexOf('\') -ge 0) { return $false }
    if (-not $n.StartsWith('server/', [StringComparison]::Ordinal)) { return $false }
    $body = if ($n.EndsWith('/', [StringComparison]::Ordinal)) { $n.Substring(0, $n.Length - 1) } else { $n }
    foreach ($seg in $body.Split('/')) {
        if ($seg.Length -eq 0 -or [string]::Equals($seg, '.', [StringComparison]::Ordinal) -or [string]::Equals($seg, '..', [StringComparison]::Ordinal)) { return $false }
    }
    return $true
}
# 번들 항목 판정. $names = tar -tf 줄(이름), $vlines = tar -tvf 줄(같은 순서). 정규 형태가 아닌 이름 · 중복 이름을 세고, 정규 이름 중
#   일반 파일('-')이고 크기 > 0인 것만 state.db · token · cred · tls로 센다(심볼릭 링크 · 하드 링크 · 디렉터리 · 0바이트는 세지 않는다).
# -tv 줄에서 이름 앞부분의 칸으로 크기를 읽는다: GNU tar = 모드 · 소유자/그룹 · 크기 · 날짜 · 시각, bsdtar = 모드 · 링크 수 · 소유자 ·
#   그룹 · 크기 · 날짜 세 칸(로캘마다 모양이 달라 날짜는 읽지 않는다). 일반 파일 줄이 그 이름으로 끝나지 않거나 크기를 읽을 수 없으면 unread.
function Measure-BundleEntries([string[]]$names, [string[]]$vlines) {
    $r = @{ db = 0; token = 0; cred = 0; tls = 0; nonCanonical = 0; duplicates = 0; unread = 0 }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $dup = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    for ($i = 0; $i -lt $names.Count; $i++) {
        $n = $names[$i]
        if (-not (Test-CanonicalName $n)) { $r.nonCanonical++; continue }
        if (-not $seen.Add($n)) { [void]$dup.Add($n) }
        $line = if ($i -lt $vlines.Count) { $vlines[$i] } else { '' }
        if ($line.Length -eq 0 -or -not [string]::Equals([string]$line[0], '-', [StringComparison]::Ordinal)) { continue }   # 일반 파일이 아니다
        if (-not $line.EndsWith(' ' + $n, [StringComparison]::Ordinal)) { $r.unread++; continue }
        $tok = @($line.Substring(0, $line.Length - $n.Length - 1) -split '\s+' | Where-Object { $_.Length -gt 0 })
        $sizeTok = $null
        if ($tok.Count -ge 3 -and $tok[1].Contains('/')) { $sizeTok = $tok[2] }   # GNU tar
        elseif ($tok.Count -ge 5) { $sizeTok = $tok[4] }                           # bsdtar
        if ($null -eq $sizeTok -or $sizeTok -notmatch '\A[0-9]+\z') { $r.unread++; continue }
        if ([long]$sizeTok -le 0) { continue }   # 0바이트는 세지 않는다
        if ([string]::Equals($n, 'server/db/state.db', [StringComparison]::Ordinal)) { $r.db++ }
        elseif ([string]::Equals($n, 'server/token', [StringComparison]::Ordinal)) { $r.token++ }
        elseif ($n.StartsWith('server/cred/', [StringComparison]::Ordinal)) { $r.cred++ }
        elseif ($n.StartsWith('server/tls/', [StringComparison]::Ordinal)) { $r.tls++ }
    }
    $r.duplicates = $dup.Count
    return $r
}

function Test-K3sComponent([string]$blocker, [bool]$download) {
    $ctx = @{ enc = $script:k3sFull }
    $b = $blocker
    if ($download) {
        $b = Invoke-Step 'bv-dl-k3s' 'latest K3s bundle in the bucket downloaded' $b {
            $r = Get-LatestBackup 'k3s' 'k3s/' (Join-Path $script:work 'k3s.tar.age')
            if ($r.ok) { $ctx.enc = $r.path }
            $r
        }
    }
    $b = Invoke-Step 'bv-k3s-1' 'K3s ciphertext read' $b { Get-FileFacts $ctx.enc $(if ($download) { $null } else { $script:k3sError }) }
    $b = Invoke-Step 'bv-k3s-2' 'K3s bundle decrypts and authenticates end to end (age -d, plaintext discarded)' $b {
        $p = Invoke-AgePipe $ctx.enc
        if ($null -ne $p.stop) { return @{ ok = $false; detail = (Get-StopText $p 'nothing') } }
        if ($p.ageCode -eq 0) { return @{ ok = $true; detail = "age exit 0, $($p.bytes) plaintext bytes (not written to disk)" } }
        return @{ ok = $false; detail = "age exit $($p.ageCode) after $($p.bytes) plaintext bytes: $($p.ageErr)" }
    }
    $b = Invoke-Step 'bv-k3s-3' 'K3s bundle entries are canonical, unique and hold the expected non-empty files (counts only)' $b {
        # 이름(-tf)과 종류 · 크기(-tvf)를 따로 읽는다 — 같은 순서다. 어느 쪽도 화면에 싣지 않는다.
        $p = Invoke-AgePipe $ctx.enc @('-tf', '-')
        if ($null -ne $p.stop) { return @{ ok = $false; detail = (Get-StopText $p 'nothing') } }
        if ($p.ageCode -ne 0 -or $p.tarCode -ne 0) { return @{ ok = $false; detail = "listing failed: age exit $($p.ageCode), tar exit $($p.tarCode): $(Get-LastLine $p.tarErr) $(Get-LastLine $p.ageErr)" } }
        $v = Invoke-AgePipe $ctx.enc @('-tvf', '-')
        if ($null -ne $v.stop) { return @{ ok = $false; detail = (Get-StopText $v 'nothing') } }
        if ($v.ageCode -ne 0 -or $v.tarCode -ne 0) { return @{ ok = $false; detail = "detailed listing failed: age exit $($v.ageCode), tar exit $($v.tarCode): $(Get-LastLine $v.tarErr) $(Get-LastLine $v.ageErr)" } }
        $names = [string[]]@("$($p.text)" -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        $vlines = [string[]]@("$($v.text)" -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        $m = Measure-BundleEntries $names $vlines
        $probs = @()
        if ($m.nonCanonical -gt 0) { $probs += "$($m.nonCanonical) entry name(s) not in canonical form" }
        if ($m.duplicates -gt 0) { $probs += "$($m.duplicates) duplicated name(s)" }
        if ($vlines.Count -ne $names.Count) { $probs += "listings disagree ($($names.Count) names, $($vlines.Count) detailed lines)" }
        if ($m.unread -gt 0) { $probs += "$($m.unread) detailed listing line(s) not understood" }
        if ($m.db -ne 1) { $probs += "state.db count $($m.db) (want 1)" }
        if ($m.token -ne 1) { $probs += "token count $($m.token) (want 1)" }
        if ($m.cred -lt 1) { $probs += "cred files $($m.cred) (want >= 1)" }
        if ($m.tls -lt 1) { $probs += "tls files $($m.tls) (want >= 1)" }
        $detail = "state.db $($m.db), token $($m.token), cred files $($m.cred), tls files $($m.tls) ($($names.Count) entries; regular non-empty files only)"
        if ($probs.Count -gt 0) { $detail += '; problems: ' + ($probs -join ', ') }
        return @{ ok = ($probs.Count -eq 0); detail = $detail }
    }
    $b = Invoke-Step 'bv-k3s-4' 'state.db extracted alone and passes SQLite integrity_check with a non-empty table kine' $b {
        $dbPath = Join-Path $script:work 'state.db'
        $p = Invoke-AgePipe $ctx.enc @('-xOf', '-', 'server/db/state.db') $dbPath
        if ($null -ne $p.stop) { return @{ ok = $false; detail = (Get-StopText $p 'state.db') } }
        if ($p.ageCode -ne 0 -or $p.tarCode -ne 0) { return @{ ok = $false; detail = "extraction failed: age exit $($p.ageCode), tar exit $($p.tarCode): $(Get-LastLine $p.tarErr) $(Get-LastLine $p.ageErr)" } }
        $len = (Get-Item -LiteralPath $dbPath).Length
        if ($len -le 0) { return @{ ok = $false; detail = 'extracted state.db is empty' } }
        $py = $script:tools['py']
        $c = Invoke-Native $py.exe (@($py.pre) + @('-', $dbPath)) -StdinText $script:sqliteCheck
        if ($c.code -ne 0) { return @{ ok = $false; detail = "sqlite checker exit $($c.code): $(Get-LastLine $c.err)" } }
        $j = $null
        try { $j = "$($c.out)".Trim() | ConvertFrom-Json -AsHashtable } catch { return @{ ok = $false; detail = "sqlite checker output is not JSON: $($c.out)" } }
        $ver = [string]$j['sqlite']
        if ($j.ContainsKey('error')) { return @{ ok = $false; detail = "sqlite $ver, state.db $len bytes: $($j['error'])" } }
        $rows = [int]$j['integrity_rows']
        $first = [string]@($j['integrity'])[0]
        if (-not ($rows -eq 1 -and [string]::Equals($first, 'ok', [StringComparison]::Ordinal))) {
            return @{ ok = $false; detail = "sqlite $ver, state.db $len bytes: integrity_check returned $rows row(s), first: $first" }
        }
        if (-not [bool]$j['kine']) { return @{ ok = $false; detail = "sqlite $ver, state.db $len bytes: integrity ok but table kine not found" } }
        if ([long]$j['rows'] -lt 1) { return @{ ok = $false; detail = "sqlite $ver, state.db $len bytes: integrity ok but table kine has no rows" } }
        $maxId = if ($null -eq $j['max_id']) { 'none' } else { [string]$j['max_id'] }
        return @{ ok = $true; detail = "sqlite $ver, kine rows $($j['rows']), max(id) $maxId, state.db $len bytes" }
    }
}

function Test-VaultComponent([string]$blocker, [bool]$download) {
    $ctx = @{ enc = $script:vaultFull }
    $b = $blocker
    if ($download) {
        $b = Invoke-Step 'bv-dl-vault' 'latest Vault snapshot in the bucket downloaded' $b {
            $r = Get-LatestBackup 'vault' 'vault/' (Join-Path $script:work 'vault.snap.age')
            if ($r.ok) { $ctx.enc = $r.path }
            $r
        }
    }
    $snap = Join-Path $script:work 'vault.snap'
    $b = Invoke-Step 'bv-vault-1' 'Vault ciphertext read' $b { Get-FileFacts $ctx.enc $(if ($download) { $null } else { $script:vaultError }) }
    $b = Invoke-Step 'bv-vault-2' 'Vault snapshot decrypts (age -d -o <work>/vault.snap)' $b {
        $r = Invoke-Native $script:tools['age'] @('-d', '-i', $script:keyFull, '-o', $snap, $ctx.enc)
        if ($r.code -ne 0) { return @{ ok = $false; detail = "age exit $($r.code): $($r.err)" } }
        if (-not (Test-Path -LiteralPath $snap -PathType Leaf) -or (Get-Item -LiteralPath $snap).Length -le 0) { return @{ ok = $false; detail = 'age exit 0 but vault.snap is missing or empty' } }
        return @{ ok = $true; detail = "age exit 0, vault.snap $((Get-Item -LiteralPath $snap).Length) bytes" }
    }
    $b = Invoke-Step 'bv-vault-3' 'Vault snapshot passes raft snapshot inspect (offline)' $b {
        $r = Invoke-Native $script:tools['vault'] @('operator', 'raft', 'snapshot', 'inspect', $snap) -Environment @{ VAULT_FORMAT = 'table' }
        if ($r.code -ne 0) { return @{ ok = $false; detail = "vault exit $($r.code): $($r.err)" } }
        $head = @{}
        $keys = 0; $total = $null; $inTable = $false; $sepSeen = 0
        foreach ($line in @("$($r.out)" -split "`r?`n")) {
            $m = [regex]::Match($line, '\A\s*(ID|Size|Index|Term|Version)\s+(\S+)\s*\z')
            if (-not $inTable -and $m.Success -and -not $head.ContainsKey($m.Groups[1].Value)) { $head[$m.Groups[1].Value] = $m.Groups[2].Value; continue }
            if ($line -match '\A\s*Key Name\s+Count\s+Size\s*\z') { $inTable = $true; $sepSeen = 0; continue }
            if ($inTable -and $line -match '\A\s*----') { $sepSeen++; if ($sepSeen -ge 2) { $inTable = $false }; continue }
            if ($inTable -and $sepSeen -eq 1 -and $line.Trim().Length -gt 0) { $keys++; continue }
            $t = [regex]::Match($line, '\A\s*Total Size\s+(\S+)\s*\z')
            if ($t.Success) { $total = $t.Groups[1].Value }
        }
        $intIndex = $head.ContainsKey('Index') -and $head['Index'] -match '\A[0-9]+\z'
        $intTerm = $head.ContainsKey('Term') -and $head['Term'] -match '\A[0-9]+\z'
        $fields = @(foreach ($k in @('ID', 'Size', 'Index', 'Term', 'Version')) { "$k $(if ($head.ContainsKey($k)) { $head[$k] } else { 'missing' })" })
        $detail = ($fields -join ', ') + ", keys $keys, Total Size $(if ($null -ne $total) { $total } else { 'missing' })"
        if (-not ($intIndex -and $intTerm)) { return @{ ok = $false; detail = "inspect exit 0 but no integer Index/Term in its head: $detail" } }
        return @{ ok = $true; detail = $detail }
    }
}

# 작업 디렉터리 삭제(남은 핸들이 풀릴 시간을 두고 몇 번 시도한다). 지울 수 있는 것은 다 지운다(-ErrorAction SilentlyContinue).
function Remove-WorkDir([string]$dir) {
    for ($i = 0; $i -lt 5; $i++) {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
        if (-not (Test-Path -LiteralPath $dir)) { return $true }
        Start-Sleep -Milliseconds 300
    }
    return $false
}

function Invoke-Main {
    # ---------- 사용법(아무것도 만들기 전에) ----------
    $k3sGiven = -not [string]::IsNullOrEmpty($K3sAge)
    $vaultGiven = -not [string]::IsNullOrEmpty($VaultAge)
    $usage = $null
    $root = $null
    if ($k3sGiven -ne $vaultGiven) {
        $usage = "give both -K3sAge and -VaultAge (local file mode) or neither (download mode); got only -$(if ($k3sGiven) { 'K3sAge' } else { 'VaultAge' })"
    } elseif ($MaxAgeHours -lt 1) {
        $usage = "-MaxAgeHours must be 1 or more (got $MaxAgeHours)"
    } elseif (-not [string]::IsNullOrEmpty($WorkRoot)) {
        Add-Redaction $WorkRoot '<work-root>'
        $rr = Resolve-UserPath $WorkRoot
        if ($null -eq $rr.path) { $usage = "-WorkRoot cannot be resolved: $($rr.error)" }
        elseif (-not (Test-Path -LiteralPath $rr.path -PathType Container)) { $usage = '-WorkRoot does not name an existing directory (path not shown)' }
        else { $root = $rr.path }
    }
    if ($null -ne $usage) { Write-Check 'bv-usage' $false 'arguments' $usage; return }
    if ($null -eq $root) { $root = [IO.Path]::GetTempPath() }
    $download = -not $k3sGiven

    # 가릴 경로(긴 것부터 치환된다). 풀 수 없는 경로는 원문을 가리고 그 사유를 해당 검사에서 말한다.
    Add-Redaction $AgeKeyFile '<age-key>'
    $kr = Resolve-UserPath $AgeKeyFile
    $script:keyFull = $kr.path; $script:keyError = $kr.error
    Add-Redaction $script:keyFull '<age-key>'
    if (-not $download) {
        Add-Redaction $K3sAge '<k3s-age>'
        Add-Redaction $VaultAge '<vault-age>'
        $kr = Resolve-UserPath $K3sAge
        $script:k3sFull = $kr.path; $script:k3sError = $kr.error
        $kr = Resolve-UserPath $VaultAge
        $script:vaultFull = $kr.path; $script:vaultError = $kr.error
        Add-Redaction $script:k3sFull '<k3s-age>'
        Add-Redaction $script:vaultFull '<vault-age>'
    }
    Add-Redaction $root '<work-root>'
    Add-Redaction ([IO.Path]::GetTempPath()) '<tmp>'
    Add-Redaction ([Environment]::GetFolderPath('UserProfile')) '<home>'
    Add-Redaction $HOME '<home>'

    if ($download) { Write-Host (ConvertTo-Ascii "mode: download (bucket $Bucket, profile $OciProfile, max age $MaxAgeHours h)") }
    else { Write-Host 'mode: local files' }
    if ($null -ne $script:timeoutNote) { Write-Host $script:timeoutNote }

    # 앞 실행이 남긴 작업 디렉터리(강제 종료 · 정리 실패) — 이번 작업 디렉터리를 만들기 전에 센다(bv-pre-3). 지우지 않는다.
    $leftover = [string[]]@(Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $_.StartsWith('backup-verify-', [StringComparison]::Ordinal) })
    [Array]::Sort($leftover, [StringComparer]::Ordinal)

    # ---------- 작업 디렉터리: 자식 프로세스를 하나라도 띄우기 전에 만들고, 어느 경로로 끝나든 finally에서 지운다 ----------
    #   <work>/tmp = 자식의 TMP · TEMP · TMPDIR(도구가 남기는 임시 파일도 함께 지워진다)
    $script:work = Join-Path $root ('backup-verify-' + [guid]::NewGuid().ToString('N'))
    try {
        [void][IO.Directory]::CreateDirectory($script:work)
        Add-Redaction $script:work '<work>'
        $script:toolTmp = Join-Path $script:work 'tmp'
        [void][IO.Directory]::CreateDirectory($script:toolTmp)

        # ---------- bv-pre-1 · bv-pre-2 ----------
        $t = Find-Tools $download
        Write-Check 'bv-pre-1' $t.ok "tools available (age, tar, vault, python with sqlite3$(if ($download) { ', oci' }))" $t.detail
        if (-not $t.ok) { return }
        $keyOk = $null -ne $script:keyFull -and (Test-Path -LiteralPath $script:keyFull -PathType Leaf)
        $keyDetail = if ($keyOk) { 'found' } elseif ($null -ne $script:keyError) { "the -AgeKeyFile path cannot be resolved: $($script:keyError)" } else { 'no file at the given -AgeKeyFile path' }
        Write-Check 'bv-pre-2' $keyOk 'age identity file exists (path not shown)' $keyDetail
        if ($leftover.Count -eq 0) { Write-Check 'bv-pre-3' $true 'no leftover work directories' 'none under the work root' }
        else {
            $shown = (@($leftover | Select-Object -First 5) -join ', ') + $(if ($leftover.Count -gt 5) { ', ...' } else { '' })
            Write-Check 'bv-pre-3' $false 'no leftover work directories' "$($leftover.Count) found: $shown (left under the work root by an earlier run that did not finish; they may hold decrypted state.db or vault.snap; not removed: check and delete them by hand)"
        }
        if (-not $keyOk) {
            $ids = @()
            if ($download) { $ids += 'bv-dl-k3s' }
            $ids += @('bv-k3s-1', 'bv-k3s-2', 'bv-k3s-3', 'bv-k3s-4')
            if ($download) { $ids += 'bv-dl-vault' }
            $ids += @('bv-vault-1', 'bv-vault-2', 'bv-vault-3')
            foreach ($id in $ids) { Write-NotAttempted $id 'bv-pre-2' }
            return
        }

        Test-K3sComponent $null $download
        Test-VaultComponent $null $download
    } finally {
        $leaf = [IO.Path]::GetFileName($script:work)
        if (Remove-WorkDir $script:work) { Write-Check 'bv-clean' $true 'work directory removed' "removed $leaf" }
        else { Write-Check 'bv-clean' $false 'work directory removed' "could not remove $leaf; full path: $($script:work); delete it by hand (it may hold decrypted state.db or vault.snap)" -Raw }
    }
}

Write-Host "started: $(Get-UtcStamp)"
try { Invoke-Main }
catch { Write-Check 'bv-error' $false 'unexpected error' "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
Write-Host "finished: $(Get-UtcStamp)"
Write-Host "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 }
exit 0
