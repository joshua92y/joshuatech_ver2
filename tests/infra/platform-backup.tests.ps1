# tests/infra/platform-backup.tests.ps1 — infra/bootstrap/platform-backup.{sh,service,timer} 정적 검사 스위트 (T036, FR-047)
# Run: pwsh -NoProfile -File tests/infra/platform-backup.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/infra/k3s-server.tests.ps1 과 같은 구조). 문자열 비교는 전부 Ordinal.
#
# fail closed: 세 파일 중 하나라도 없으면 전 단언 FAIL. 유일한 SKIP은 syntax-1(bash -n) — Git bash가 없을 때만.
# 실행(노드·kubectl·vault·oci·age)은 하지 않는다 — 이 스위트는 원문만 읽는다. 실제 백업·복원 가능성 검증은 운영자(절차 3·4)와 T048 몫이다.
# systemd unit은 systemd-analyze verify를 쓸 수 없으므로(Windows) 섹션·키를 파싱해 **값까지** 대조한다(부분 문자열 일치는 주석 처리·삭제를 놓친다 — 리뷰 지적).
#
# 이 스위트가 고정하는 핵심 안전 속성(리뷰에서 실측된 실패 양식):
#   * `backup_* || true`는 그 함수의 동적 범위 전체에서 set -e를 끈다 → 컴포넌트 함수 안의 **모든 명령**에 명시적 실패 분기가 있어야 한다(k3s-9).
#   * textfile 기록 실패가 RESULT=OK로 보고되면 --pre-upgrade 게이트가 뚫리고 PlatformBackupStale도 안 뜬다(tf-6·tf-7).
#   * 업로드 대상은 반드시 age 산출물이어야 한다(age-7) — 평문 tar/스냅샷 업로드는 계약 위반.
#   * main 호출 그래프가 고정되지 않으면 parse_args 한 줄 삭제로 --pre-upgrade가 조용히 무시된다(cli-6).
#
# 검사 계약(platform-backup.sh 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   FILE   file-1 sh+unit 2개 존재  file-2 첫 줄 '#!/usr/bin/env bash'  file-3 세 파일 CR 없음·끝 개행  file-4 'set -euo pipefail'  file-5 umask 077
#          file-6 마지막 줄 'main "$@" </dev/null; exit'  file-7 한 local 안에서 자기 선언 변수 미참조(SC2318)
#   K3S    k3s-1 sqlite3 ".backup" 온라인 스냅샷  k3s-2 PRAGMA integrity_check=ok + 실패 분기  k3s-3 server/token  k3s-4 server/cred/  k3s-5 server/tls/
#          k3s-6 tar 구성원은 server/ 하나(복원 = tar -C /var/lib/rancher/k3s -xf)  k3s-7 오브젝트 k3s/<UTC ts>.tar.age  k3s-8 평문 shred
#          k3s-9 backup_k3s의 모든 명령에 실패 분기(errexit 무력화 대비)  k3s-10 원본 cred+tls 파일 수 ↔ 번들 항목 수 대조
#   VAULT  v-1 create token(audience vault, 10m)  v-2 port-forward svc/vault :8200  v-3 VAULT_ADDR=127.0.0.1  v-4 jwt=- 파이프  v-5 raft snapshot save
#          v-6 revoke -self  v-7 port-forward 종료(trap+stop)  v-8 오브젝트 vault/<ts>.snap.age  v-9 공개 호스트·pod IP 미사용  v-10 stderr 캡처 후 진단 로그
#   AGE    age-1 recipient 기본 경로+부재 die  age-2 age1 형식  age-3 AGE-SECRET-KEY 거부  age-4 age -r -o + 평문 shred  age-5 age -d/age-keygen 호출 없음
#          age-6 공개키 전체 미로깅  age-7 업로드 인자는 항상 "$enc"(암호화 → 업로드 순서 포함)
#   OCI    oci-1 모든 호출 --auth instance_principal  oci-2 버킷·네임스페이스  oci-3 OCI_BIN 고정 경로  oci-4 다른 자격 없음  oci-5 put/head만
#   TF     tf-1 textfile 디렉터리  tf-2 컴포넌트별 지표  tf-3 mktemp+mv 원자 쓰기  tf-4 성공 경로에서만(업로드 → finish 순서 포함)  tf-5 install -d 0755
#          tf-6 finish_component가 write_textfile 실패를 FAIL로  tf-7 write_textfile의 모든 단계가 실패를 전파
#   CLI    cli-1 --pre-upgrade + --components 병용 거부  cli-2 컴포넌트 허용값  cli-3 알 수 없는 인자 die  cli-4 기본 k3s,vault
#          cli-5 컴포넌트 격리 + 실패 시 exit 1  cli-6 main 호출 그래프·순서  cli-7 --pre-upgrade의 vault 탐지 분기(존재/부재 두 경로)
#   UNIT   unit-1 Timer.OnCalendar 값  unit-2 Timer.Persistent=true  unit-3 Install.WantedBy=timers.target  unit-4 Timer.Unit=platform-backup.service
#          unit-5 Service.Type=oneshot + ExecStart 절대 경로  unit-6 Service.EnvironmentFile=-/etc/platform-backup/env  unit-7 unit에 자격 없음
#          unit-8 섹션·키 철자 허용 목록 + 필수 키 존재
#   IDEM   idem-1 flock  idem-2 mktemp -d + trap  idem-3 cleanup이 shred + port-forward 종료
#   SEC    sec-1 set -x 없음  sec-2 Vault 토큰 미출력  sec-3 server/token 판독 없음  sec-4 자격 인접 파일 grep은 -q/-c  sec-5 vault login·토큰 파일 없음
#          sec-6 비밀로 보이는 문자열 없음
#   LOG    log-1 '[platform-backup]' 접두  log-2 컴포넌트별 OK/FAIL+object+bytes  log-3 exit 코드·게이트 결과
#   SYNTAX syntax-1 bash -n (bash 없으면 SKIP)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/platform-backup.sh'
$svcPath = Join-Path $repo 'infra/bootstrap/platform-backup.service'
$timerPath = Join-Path $repo 'infra/bootstrap/platform-backup.timer'

$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Read-Text([string]$path) {
    $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
    return $raw
}

function Has([string]$hay, [string]$needle) { return $hay.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Idx([string]$hay, [string]$needle) { return $hay.IndexOf($needle, [StringComparison]::Ordinal) }

function Get-FunctionBody([string]$text, [string]$name) {
    $m = [regex]::Match($text, '(?ms)^' + [regex]::Escape($name) + '\(\) \{\n(.*?)^\}')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Get-CodeLines([string[]]$lines) { return @($lines | Where-Object { $_ -cnotmatch '^\s*#' }) }

$allNames = @('file-1', 'file-2', 'file-3', 'file-4', 'file-5', 'file-6', 'file-7',
    'k3s-1', 'k3s-2', 'k3s-3', 'k3s-4', 'k3s-5', 'k3s-6', 'k3s-7', 'k3s-8', 'k3s-9', 'k3s-10',
    'v-1', 'v-2', 'v-3', 'v-4', 'v-5', 'v-6', 'v-7', 'v-8', 'v-9', 'v-10',
    'age-1', 'age-2', 'age-3', 'age-4', 'age-5', 'age-6', 'age-7',
    'oci-1', 'oci-2', 'oci-3', 'oci-4', 'oci-5',
    'tf-1', 'tf-2', 'tf-3', 'tf-4', 'tf-5', 'tf-6', 'tf-7',
    'cli-1', 'cli-2', 'cli-3', 'cli-4', 'cli-5', 'cli-6', 'cli-7',
    'unit-1', 'unit-2', 'unit-3', 'unit-4', 'unit-5', 'unit-6', 'unit-7', 'unit-8',
    'idem-1', 'idem-2', 'idem-3',
    'sec-1', 'sec-2', 'sec-3', 'sec-4', 'sec-5', 'sec-6',
    'log-1', 'log-2', 'log-3', 'syntax-1')

$missingFiles = @(@($target, $svcPath, $timerPath) | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
if ($missingFiles.Count -gt 0) {
    # fail closed: 세 파일이 다 있어야 계약이 성립한다(스크립트만 있고 unit이 없으면 타이머가 없는 것)
    foreach ($n in $allNames) { Assert $n $false ("missing: " + (($missingFiles | ForEach-Object { $_.Substring($repo.Length + 1) -replace '\\', '/' }) -join ', ')) }
    Write-Host "`n$($script:pass) passed, $($script:fail) failed"
    exit 1
}

$text = Read-Text $target
$lines = $text -split "`n"
$code = Get-CodeLines $lines
$codeText = ($code -join "`n")
$svc = Read-Text $svcPath
$timer = Read-Text $timerPath

# systemd unit 파싱: 섹션 → (키 → 값 목록). 주석·빈 줄 제외, 파싱 불가 줄은 Bad에 모은다(공허한 부분 문자열 단언을 없애는 핵심).
function ConvertFrom-Unit([string]$unitText) {
    $sections = [ordered]@{}
    $section = ''
    $bad = @()
    foreach ($l in ($unitText -split "`n")) {
        $t = $l.TrimEnd("`r")
        if ($t.Trim().Length -eq 0 -or $t -cmatch '^\s*#') { continue }
        if ($t -cmatch '^\[([A-Za-z]+)\]$') { $section = $Matches[1]; if (-not $sections.Contains($section)) { $sections[$section] = [ordered]@{} }; continue }
        if ($t -cmatch '^([A-Za-z][A-Za-z0-9]*)=(.*)$') {
            if ($section -eq '') { $bad += "key before section: $t"; continue }
            $k = $Matches[1]; $v = $Matches[2]
            if (-not $sections[$section].Contains($k)) { $sections[$section][$k] = @() }
            $sections[$section][$k] += $v
            continue
        }
        $bad += "unparsed: $t"
    }
    return @{ Sections = $sections; Bad = $bad }
}
$svcU = ConvertFrom-Unit $svc
$timerU = ConvertFrom-Unit $timer

# 섹션/키가 없으면 $null (부재 = FAIL 이 되도록 단일 값으로 돌려준다)
function UnitVal($parsed, [string]$section, [string]$key) {
    if (-not $parsed.Sections.Contains($section)) { return $null }
    if (-not $parsed.Sections[$section].Contains($key)) { return $null }
    $vals = @($parsed.Sections[$section][$key])
    if ($vals.Count -ne 1) { return "<multiple: $($vals -join '|')>" }
    return $vals[0]
}
function UnitEq($parsed, [string]$section, [string]$key, [string]$expected) {
    $v = UnitVal $parsed $section $key
    return ($null -ne $v) -and [string]::Equals($v, $expected, [StringComparison]::Ordinal)
}

# ---------- FILE ----------
Test-Group 'file' {
    Assert 'file-1: infra/bootstrap/platform-backup.sh + .service + .timer exist' $true ''
    Assert 'file-2: first line is #!/usr/bin/env bash' ([string]::Equals($lines[0], '#!/usr/bin/env bash', [StringComparison]::Ordinal)) "first line: '$($lines[0])'"
    $crlfOk = $true
    foreach ($t in @($text, $svc, $timer)) { if ((Has $t "`r") -or (-not $t.EndsWith("`n", [StringComparison]::Ordinal))) { $crlfOk = $false } }
    Assert 'file-3: all three files are LF only and end with a newline' $crlfOk 'CR found or missing final newline (.gitattributes forces LF; bash and systemd both dislike CRLF)'
    Assert 'file-4: set -euo pipefail present as a whole line' (@($lines | Where-Object { [string]::Equals($_, 'set -euo pipefail', [StringComparison]::Ordinal) }).Count -ge 1) 'no exact line "set -euo pipefail"'
    Assert 'file-5: umask 077 (plaintext snapshots and tars are never group/world readable)' (@($lines | Where-Object { [string]::Equals($_, 'umask 077', [StringComparison]::Ordinal) }).Count -ge 1) 'no exact line "umask 077"'
    $nonEmpty = @($lines | Where-Object { $_.Length -gt 0 })
    $last = if ($nonEmpty.Count -gt 0) { $nonEmpty[$nonEmpty.Count - 1] } else { '' }
    Assert 'file-6: last line is main "$@" </dev/null; exit' ([string]::Equals($last, 'main "$@" </dev/null; exit', [StringComparison]::Ordinal)) "last line: '$last'"
    # SC2318: bash는 'local a=1 b=$a' 한 줄의 모든 단어를 builtin 실행 전에 확장한다 — $a는 호출자 스코프의 동명 변수(동적 스코프)로 우연히 채워질 뿐이다.
    $badLocal = @()
    foreach ($l in $code) {
        if ($l -cnotmatch '^\s*local\s') { continue }
        foreach ($d in @([regex]::Matches($l, '(?<![\w$])([A-Za-z_][A-Za-z0-9_]*)=') | ForEach-Object { $_.Groups[1].Value })) {
            if ($l -cmatch ('\$\{?' + [regex]::Escape($d) + '\b')) { $badLocal += $l.Trim() }
        }
    }
    Assert 'file-7: no single "local" declares and dereferences the same name (SC2318 — it silently reads the caller scope)' ($badLocal.Count -eq 0) ($badLocal -join ' | ')
}

# ---------- K3S BUNDLE ----------
Test-Group 'k3s' {
    $b = Get-FunctionBody $text 'backup_k3s'
    Assert 'k3s-1: online snapshot via sqlite3 ".backup" (never a raw copy — kine SQLite runs in WAL mode, K3S-D9)' ($null -ne $b -and (Has $b 'sqlite3 "$K3S_STATE_DB" ".backup') -and (Has $codeText 'K3S_STATE_DB="$K3S_SERVER_DIR/db/state.db"') -and ($b -cnotmatch 'cp[^\n]*state\.db')) 'sqlite3 .backup missing or state.db copied directly'
    Assert 'k3s-2: the snapshot is verified (PRAGMA integrity_check = ok) before the tar, with an explicit failure branch' ($null -ne $b -and (Has $b 'PRAGMA integrity_check') -and ($b -cmatch '\[ "\$check" = ok \] \|\| \{ fail_component k3s') -and ((Idx $b 'PRAGMA integrity_check') -lt (Idx $b 'tar -C'))) 'integrity check missing, unguarded, or after the tar'
    Assert 'k3s-3: server/token included (bootstrap PBKDF2 key — without it the snapshot cannot be restored)' ($null -ne $b -and (Has $b 'cp -p -- "$K3S_SERVER_DIR/token" "$dir/server/token"') -and (Has $b '[ -f "$K3S_SERVER_DIR/token" ]')) 'token not bundled'
    Assert 'k3s-4: server/cred/ included' ($null -ne $b -and (Has $b 'cp -rp -- "$K3S_SERVER_DIR/cred" "$dir/server/cred"') -and (Has $b '[ -d "$K3S_SERVER_DIR/cred" ]')) 'cred/ not bundled'
    Assert 'k3s-5: server/tls/ included (restoring without it regenerates certificates and breaks the node B rejoin)' ($null -ne $b -and (Has $b 'cp -rp -- "$K3S_SERVER_DIR/tls" "$dir/server/tls"') -and (Has $b '[ -d "$K3S_SERVER_DIR/tls" ]')) 'tls/ not bundled — rollback.md depends on it'
    Assert 'k3s-6: the tar holds the single member server/ so restore is "tar -C /var/lib/rancher/k3s -xf" with no path juggling' ($null -ne $b -and ($b -cmatch '(?m)tar -C "\$dir"[^\n]*-cf "\$tar" server\s*\|\|') -and (Has $b '"$dir/server/db/state.db"')) 'tar member list differs from the documented restore layout'
    Assert 'k3s-7: object name k3s/k3s-<UTC ts>.tar.age with ts=date -u +%Y%m%dT%H%M%SZ' ($null -ne $b -and (Has $b 'obj="k3s/k3s-$TS.tar.age"') -and (Has $codeText 'TS=$(date -u +%Y%m%dT%H%M%SZ)')) 'object naming or UTC timestamp missing'
    Assert 'k3s-8: plaintext is shredded (staging dir during the run, everything again in the EXIT trap)' ($null -ne $b -and (Has $b 'shred -u --') -and (Has $codeText 'find "$WORKDIR" -type f -exec shred -u -- {} +')) 'plaintext shredding missing'
    # 리뷰 실측: `backup_k3s || true` 는 이 함수 전체(중첩 함수 포함)에서 set -e 를 끈다 → 검사 없는 명령은 실패해도 계속 진행돼 RESULT=OK 로 끝난다.
    $unchecked = @()
    if ($null -ne $b) {
        foreach ($l in ($b -split "`n")) {
            $t = $l.Trim()
            if ($t.Length -eq 0 -or $t.StartsWith('#') -or $t.StartsWith('local ') -or $t -ceq '}' -or $t -ceq '{') { continue }
            if ($t -cmatch '^[A-Za-z_][A-Za-z0-9_]*=') { continue }   # 값 검증은 바로 뒤 테스트가 한다
            if ($t -cnotmatch '\|\|') { $unchecked += $t }
        }
    }
    Assert 'k3s-9: every command in backup_k3s has an explicit failure branch (errexit is disabled inside "backup_k3s || true")' ($null -ne $b -and $unchecked.Count -eq 0) "unchecked: $($unchecked -join ' | ')"
    Assert 'k3s-10: bundle completeness is proven by comparing source cred+tls file count with the tar members (GNU cp keeps copying after a per-item error)' ($null -ne $b -and (Has $b 'find "$K3S_SERVER_DIR/cred" "$K3S_SERVER_DIR/tls" -type f') -and (Has $b 'tar -tf "$tar"') -and (Has $b '-eq "${dst:-0}"') -and ((Idx $b 'tar -tf "$tar"') -lt (Idx $b 'encrypt_file'))) 'member-count cross-check missing or after encryption'
}

# ---------- VAULT ----------
Test-Group 'v' {
    $b = Get-FunctionBody $text 'backup_vault'
    $pf = Get-FunctionBody $text 'start_port_forward'
    $stop = Get-FunctionBody $text 'stop_port_forward'
    Assert 'v-1: kubectl create token vault-backup --audience vault --duration=10m (must match the role audiences [vault], T044)' ($null -ne $b -and (Has $b 'create token "$VAULT_SA" --audience vault --duration=10m') -and (Has $codeText 'VAULT_SA=vault-backup') -and (Has $codeText 'VAULT_NAMESPACE=vault')) 'TokenRequest call missing or wrong audience/TTL'
    Assert 'v-2: Vault is reached through kubectl port-forward svc/vault :8200 on a free local port' ($null -ne $pf -and (Has $pf 'port-forward --address 127.0.0.1 "svc/$VAULT_SERVICE" "$port:8200"') -and (Has $codeText 'VAULT_SERVICE=vault') -and (Has $codeText 'pick_free_port')) 'port-forward missing (rules/infra.md: Vault only via port-forward)'
    Assert 'v-3: VAULT_ADDR points at 127.0.0.1 with the forwarded port (scheme overridable for the T044 TLS decision)' ($null -ne $b -and (Has $b 'export VAULT_ADDR="$VAULT_ADDR_SCHEME://127.0.0.1:$port"') -and (Has $codeText 'VAULT_ADDR_SCHEME="${VAULT_ADDR_SCHEME:-http}"')) 'VAULT_ADDR wrong'
    Assert 'v-4: login sends the JWT through a pipe (jwt=-), never on the command line or a temp file' ($null -ne $b -and (Has $b '| vault write -field=token "auth/kubernetes/login" role="$VAULT_ROLE" jwt=-') -and ($b -cnotmatch 'jwt=\$') -and ($b -cnotmatch 'jwt=@')) 'JWT would be visible in ps output or left on disk'
    Assert 'v-5: snapshot via vault operator raft snapshot save into the temp workdir' ($null -ne $b -and (Has $b 'vault operator raft snapshot save "$snap"') -and (Has $b 'snap="$WORKDIR/vault-$TS.snap"')) 'raft snapshot save missing'
    Assert 'v-6: the short-lived Vault token is revoked (revoke -self) after use' ($null -ne $b -and (Has $b 'vault token revoke -self')) 'token revoke missing'
    Assert 'v-7: the port-forward is always torn down (stop_port_forward + EXIT trap kill)' ($null -ne $stop -and (Has $stop 'kill "$PF_PID"') -and ($null -ne $b) -and (Has $b 'stop_port_forward') -and ((Get-FunctionBody $text 'cleanup') -match 'kill "\$PF_PID"') -and (Has $codeText 'trap cleanup EXIT')) 'port-forward teardown missing'
    Assert 'v-8: object name vault/vault-<ts>.snap.age' ($null -ne $b -and (Has $b 'obj="vault/vault-$TS.snap.age"')) 'object naming wrong'
    Assert 'v-9: never the public host or a pod IP — no vault.<domain> literal, no direct https:// VAULT_ADDR, no 10.42/10.43' ((-not (Has $text 'vault.joshuatech.dev')) -and ($codeText -cnotmatch 'VAULT_ADDR="?https?://(?!127\.0\.0\.1)') -and ($codeText -cnotmatch '10\.4[23]\.')) 'public host or pod IP reachable path found'
    Assert 'v-10: port-forward and vault status stderr is captured and surfaced in the failure reason (diagnosis, not credentials)' ((Has $codeText 'PF_ERR="$WORKDIR/pf.err"') -and (Has $codeText 'VAULT_ERR="$WORKDIR/vault.err"') -and ($null -ne $pf -and (Has $pf '2>"$PF_ERR"')) -and ($null -ne $b -and (Has $b '2>"$VAULT_ERR"')) -and (Has $codeText 'err_tail') -and ($null -ne $b -and (Has $b '$(err_tail "$PF_ERR")') -and (Has $b '$(err_tail "$VAULT_ERR")'))) 'stderr capture/reporting missing (cause would be invisible in the journal)'
}

# ---------- AGE ----------
Test-Group 'age' {
    $pb = Get-FunctionBody $text 'preflight'
    $eb = Get-FunctionBody $text 'encrypt_file'
    $bk = Get-FunctionBody $text 'backup_k3s'
    $bv = Get-FunctionBody $text 'backup_vault'
    Assert 'age-1: recipient file default /etc/platform-backup/age-recipient, missing -> die (no unencrypted upload)' ((Has $codeText 'AGE_RECIPIENT_FILE="${AGE_RECIPIENT_FILE:-/etc/platform-backup/age-recipient}"') -and ($null -ne $pb) -and (Has $pb '[ -f "$AGE_RECIPIENT_FILE" ] || die')) 'recipient file guard missing'
    Assert 'age-2: recipient validated as an age1 public key (age1 + 58 chars)' ($null -ne $pb -and (Has $pb '^age1[a-z0-9]{58}$')) 'recipient format validation missing'
    Assert 'age-3: a private key in the recipient file is refused (AGE-SECRET-KEY -> die)' ($null -ne $pb -and (Has $pb "grep -q 'AGE-SECRET-KEY' `"`$AGE_RECIPIENT_FILE`" || die")) 'private-key guard missing (the node only ever holds the public key)'
    Assert 'age-4: encryption is age -r "$AGE_RECIPIENT" -o <out> <plain> and the plaintext is shredded right after' ($null -ne $eb -and (Has $eb 'age -r "$AGE_RECIPIENT" -o "$enc" "$plain"') -and (Has $eb 'shred -u -- "$plain"') -and ((Idx $eb 'age -r') -lt (Idx $eb 'shred -u -- "$plain"'))) 'encrypt_file wrong'
    # 호출 위치(줄 머리 또는 명령 치환)만 본다 — die 메시지 안의 'age-keygen -y' 안내 문구는 실행이 아니다.
    $ageCalls = @($code | Where-Object { $_ -cmatch '(?m)(^\s*|\$\(|&&\s*|\|\|\s*|;\s*)age(-keygen)?\s' })
    $badAge = @($ageCalls | Where-Object { $_ -cnotmatch 'age -r "\$AGE_RECIPIENT" -o "\$enc" "\$plain"' })
    Assert 'age-5: the only age invocation is encryption (no age -d / --decrypt / age-keygen on the node; decryption is the operator workstation, T048)' (($codeText -cnotmatch '\bage\s+(-[a-zA-Z]*d\b|--decrypt)') -and ($codeText -cnotmatch '(?m)(^\s*|\$\()age-keygen\b') -and (-not (Has $codeText 'AGE-SECRET-KEY=')) -and $ageCalls.Count -eq 1 -and $badAge.Count -eq 0) "age invocations: [$($ageCalls -join ' | ')] unexpected: [$($badAge -join ' | ')]"
    $fullLog = @($code | Where-Object { $_ -cmatch '(log|warn|err|die|printf|echo)[^\n]*\$AGE_RECIPIENT\b' -and $_ -cnotmatch '\$\{AGE_RECIPIENT:0:' })
    Assert 'age-6: the recipient is only ever logged truncated (${AGE_RECIPIENT:0:10}), never in full' ($fullLog.Count -eq 0) "full recipient logged on: $($fullLog -join ' | ')"
    # 업로드 대상이 age 산출물임을 구속한다: 평문 tar/스냅샷을 올리는 변이를 막는 유일한 단언.
    $uploadCalls = @([regex]::Matches($codeText, 'upload_object\s+"\$[A-Za-z_][A-Za-z0-9_]*"') | ForEach-Object { $_.Value })
    $badUploads = @($uploadCalls | Where-Object { $_ -cnotmatch 'upload_object\s+"\$enc"' })
    $orderOk = ($null -ne $bk) -and ($null -ne $bv) -and ((Idx $bk 'encrypt_file') -lt (Idx $bk 'upload_object')) -and ((Idx $bv 'encrypt_file') -lt (Idx $bv 'upload_object'))
    Assert 'age-7: every upload uploads the age output ("$enc") and encryption precedes upload in both components' ($uploadCalls.Count -eq 2 -and $badUploads.Count -eq 0 -and $orderOk) "uploads=[$($uploadCalls -join ' | ')] bad=[$($badUploads -join ' | ')] order=$orderOk"
}

# ---------- OCI ----------
Test-Group 'oci' {
    $ub = Get-FunctionBody $text 'upload_object'
    $ociLines = @($code | Where-Object { $_ -cmatch '^\s*"\$OCI_BIN"' })
    $noAuth = @($ociLines | Where-Object { $_ -cnotmatch '--auth instance_principal' })
    Assert 'oci-1: every oci invocation carries --auth instance_principal (>= 2 calls: put + head)' ($ociLines.Count -ge 2 -and $noAuth.Count -eq 0) "calls=$($ociLines.Count) without instance_principal=[$($noAuth -join ' | ')]"
    Assert 'oci-2: bucket joshuatech-backup-platform + namespace default (naming exception: design says jt-backup-platform)' ((Has $codeText 'OCI_BUCKET="${OCI_BUCKET:-joshuatech-backup-platform}"') -and (Has $codeText 'OCI_NAMESPACE="${OCI_NAMESPACE:-') -and ($null -ne $ub) -and (Has $ub '--bucket-name "$OCI_BUCKET"') -and (Has $ub '--namespace "$OCI_NAMESPACE"')) 'bucket/namespace wiring missing'
    Assert 'oci-3: the CLI path is the pinned pipx binary /usr/local/bin/oci' (Has $codeText 'OCI_BIN=/usr/local/bin/oci') 'OCI_BIN constant missing (PATH lookup is not enough under systemd/chroot)'
    Assert 'oci-4: no other credential path (no api_key, no security_token, no ~/.oci, no --profile, no config file)' ((-not (Has $codeText '--auth api_key')) -and (-not (Has $codeText 'security_token')) -and (-not (Has $codeText '~/.oci')) -and (-not (Has $codeText '.oci/config')) -and ($codeText -cnotmatch '--profile\b') -and (-not (Has $codeText 'OCI_CLI_'))) 'a credential source other than the instance principal appeared'
    Assert 'oci-5: object storage is write+inspect only (put/head); no delete, list or get — retention is the bucket lifecycle' ((Has $codeText 'os object put') -and (Has $codeText 'os object head') -and ($codeText -cnotmatch 'os object (delete|bulk-delete|get|list)\b') -and ($codeText -cnotmatch 'os bucket \w')) 'a non-allowed object operation appeared (the dynamic group only has OBJECT_CREATE + OBJECT_INSPECT)'
}

# ---------- TEXTFILE ----------
Test-Group 'tf' {
    $wb = Get-FunctionBody $text 'write_textfile'
    $fb = Get-FunctionBody $text 'finish_component'
    $bk = Get-FunctionBody $text 'backup_k3s'
    $bv = Get-FunctionBody $text 'backup_vault'
    Assert 'tf-1: node-exporter textfile dir /var/lib/node_exporter/textfile_collector' (Has $codeText 'TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector') 'textfile dir constant missing'
    Assert 'tf-2: one file per component with platform_backup_last_success_timestamp{component="<c>"}' ($null -ne $wb -and (Has $wb 'file="$TEXTFILE_DIR/platform_backup_$component.prom"') -and (Has $wb 'platform_backup_last_success_timestamp{component="%s"} %s') -and (Has $wb '# TYPE platform_backup_last_success_timestamp gauge')) 'per-component metric file missing (PlatformBackupStale must fire per component)'
    Assert 'tf-3: atomic write — mktemp in the same dir (temp name is not *.prom) then mv -f' ($null -ne $wb -and (Has $wb 'mktemp -p "$TEXTFILE_DIR" ".platform_backup_$component.XXXXXX"') -and (Has $wb 'mv -f "$tmp" "$file"') -and ((Idx $wb 'mktemp -p') -lt (Idx $wb 'mv -f "$tmp" "$file"')) -and ($wb -cnotmatch '> "\$file"')) 'non-atomic write (a half-written .prom would be scraped)'
    $callers = @($code | Where-Object { $_ -cmatch '^\s*write_textfile ' })
    $orderOk = ($null -ne $bk) -and ($null -ne $bv) -and ((Idx $bk 'upload_object') -lt (Idx $bk 'finish_component')) -and ((Idx $bv 'upload_object') -lt (Idx $bv 'finish_component'))
    Assert 'tf-4: the metric is written only on the success path — from finish_component, which both components call after the upload' ($null -ne $fb -and (Has $fb 'write_textfile "$component" "$now"') -and $callers.Count -eq 1 -and (Has $codeText 'finish_component k3s') -and (Has $codeText 'finish_component vault') -and $orderOk) "write_textfile callers=$($callers.Count) (expected 1) upload-before-finish=$orderOk"
    Assert 'tf-5: the textfile directory is created 0755 when absent' ($null -ne $wb -and (Has $wb 'install -d -m 755 "$TEXTFILE_DIR"')) 'directory creation missing'
    Assert 'tf-6: finish_component turns a textfile write failure into FAIL (an unmonitorable backup is not a success; the --pre-upgrade gate depends on it)' ($null -ne $fb -and ($fb -cmatch 'write_textfile "\$component" "\$now" \|\| \{ fail_component "\$component"') -and ((Idx $fb 'write_textfile') -lt (Idx $fb 'RESULT[$component]=OK'))) 'write_textfile result ignored, or RESULT=OK set before it'
    $wtUnchecked = @()
    if ($null -ne $wb) {
        foreach ($l in ($wb -split "`n")) {
            $t = $l.Trim()
            if ($t.Length -eq 0 -or $t.StartsWith('#') -or $t.StartsWith('local ') -or $t -ceq '}' -or $t -ceq '{') { continue }
            if ($t -cnotmatch '\|\|') { $wtUnchecked += $t }
        }
    }
    Assert 'tf-7: every step of write_textfile propagates failure (install -d / mktemp / printf / chmod / mv)' ($null -ne $wb -and $wtUnchecked.Count -eq 0 -and (Has $wb 'return 1')) "unchecked: $($wtUnchecked -join ' | ')"
}

# ---------- CLI ----------
Test-Group 'cli' {
    $pa = Get-FunctionBody $text 'parse_args'
    $mb = Get-FunctionBody $text 'main'
    $sb = Get-FunctionBody $text 'summary'
    $pu = Get-FunctionBody $text 'pre_upgrade_components'
    $vd = Get-FunctionBody $text 'vault_deployed'
    $pb = Get-FunctionBody $text 'preflight'
    Assert 'cli-1: --pre-upgrade refuses --components (the gate scope cannot be narrowed by an argument)' ($null -ne $pa -and (Has $pa '--pre-upgrade) PRE_UPGRADE=1') -and (Has $pa '[ -z "$COMPONENTS_ARG" ] || die')) 'pre-upgrade/components exclusivity missing'
    Assert 'cli-2: --components accepts only k3s/vault (anything else dies)' ($null -ne $pa -and (Has $pa 'case "$c" in k3s|vault) ;; *) die')) 'component validation missing'
    Assert 'cli-3: an unknown argument dies with usage' ($null -ne $pa -and (Has $pa 'usage >&2; die')) 'unknown-arg guard missing'
    Assert 'cli-4: BACKUP_COMPONENTS default k3s,vault (env overridable so the timer can run k3s-only before T044)' (Has $codeText 'BACKUP_COMPONENTS="${BACKUP_COMPONENTS:-k3s,vault}"') 'default component list missing'
    Assert 'cli-5: a failing component does not stop the others, and any failure exits non-zero' ($null -ne $mb -and (Has $mb 'backup_k3s || true') -and (Has $mb 'backup_vault || true') -and ($null -ne $sb) -and (Has $sb 'rc=1') -and (Has $sb 'return "$rc"')) 'per-component isolation or the non-zero exit is missing (SUC prepare must be blocked on failure)'
    # main 호출 그래프: parse_args 한 줄만 지워도 --pre-upgrade 가 조용히 무시되어 SUC 게이트가 평범한 백업으로 격하된다(리뷰 실측).
    # 주석은 제거하고 본다 — 줄 끝 주석의 단어('summary …')가 호출 위치로 오인되면 순서 판정이 무의미해진다.
    $mbCode = $null
    if ($null -ne $mb) { $mbCode = (($mb -split "`n" | ForEach-Object { ($_ -replace '#.*$', '') }) -join "`n") }
    $order = @('parse_args "$@"', 'preflight', 'backup_k3s', 'backup_vault', 'summary')
    $graphOk = $null -ne $mbCode
    if ($graphOk) { for ($i = 0; $i -lt $order.Count; $i++) { if ((Idx $mbCode $order[$i]) -lt 0) { $graphOk = $false } elseif ($i -gt 0 -and (Idx $mbCode $order[$i - 1]) -ge (Idx $mbCode $order[$i])) { $graphOk = $false } } }
    Assert 'cli-6: main calls parse_args -> preflight -> component loop (backup_k3s/backup_vault) -> summary, in that order' $graphOk "main body (code only): $($mbCode -replace "`n", ' ')"
    Assert 'cli-7: --pre-upgrade requires k3s always and vault only when deployed (detected via kubectl get svc), with WARN on the skip path' (($null -ne $pa -and (Has $pa 'BACKUP_COMPONENTS=k3s')) -and ($null -ne $vd) -and (Has $vd 'get svc "$VAULT_SERVICE"') -and ($null -ne $pu) -and (Has $pu 'BACKUP_COMPONENTS=k3s,vault') -and (Has $pu 'BACKUP_COMPONENTS=k3s') -and ($pu -cmatch '(?m)^\s*warn ') -and ($null -ne $pb) -and (Has $pb 'pre_upgrade_components')) 'the T044-era deadlock guard is missing: forcing vault before it exists would block every K3s upgrade'
}

# ---------- SYSTEMD UNITS ----------
Test-Group 'unit' {
    Assert 'unit-1: Timer.OnCalendar is exactly "*-*-* 02:30:00 Asia/Seoul" (timezone pinned in the expression)' (UnitEq $timerU 'Timer' 'OnCalendar' '*-*-* 02:30:00 Asia/Seoul') "OnCalendar = '$(UnitVal $timerU 'Timer' 'OnCalendar')'"
    Assert 'unit-2: Timer.Persistent is exactly true (a missed 02:30 run catches up after downtime)' (UnitEq $timerU 'Timer' 'Persistent' 'true') "Persistent = '$(UnitVal $timerU 'Timer' 'Persistent')'"
    Assert 'unit-3: Install.WantedBy is exactly timers.target (otherwise systemctl enable does nothing)' (UnitEq $timerU 'Install' 'WantedBy' 'timers.target') "WantedBy = '$(UnitVal $timerU 'Install' 'WantedBy')'"
    Assert 'unit-4: Timer.Unit is exactly platform-backup.service' (UnitEq $timerU 'Timer' 'Unit' 'platform-backup.service') "Unit = '$(UnitVal $timerU 'Timer' 'Unit')'"
    Assert 'unit-5: Service.Type=oneshot and Service.ExecStart=/usr/local/bin/platform-backup.sh' ((UnitEq $svcU 'Service' 'Type' 'oneshot') -and (UnitEq $svcU 'Service' 'ExecStart' '/usr/local/bin/platform-backup.sh')) "Type='$(UnitVal $svcU 'Service' 'Type')' ExecStart='$(UnitVal $svcU 'Service' 'ExecStart')'"
    Assert 'unit-6: Service.EnvironmentFile is exactly -/etc/platform-backup/env (leading - = optional)' (UnitEq $svcU 'Service' 'EnvironmentFile' '-/etc/platform-backup/env') "EnvironmentFile = '$(UnitVal $svcU 'Service' 'EnvironmentFile')'"
    $envKeys = @()
    foreach ($p in @($svcU, $timerU)) {
        foreach ($sec in $p.Sections.Keys) {
            if (-not $p.Sections[$sec].Contains('Environment')) { continue }
            foreach ($v in $p.Sections[$sec]['Environment']) { if ($v -cmatch '(?i)(TOKEN|SECRET|PASSWORD|KEY)') { $envKeys += "$sec/Environment=$v" } }
        }
    }
    Assert 'unit-7: no credentials in the unit files (they come from the instance principal at run time)' ($envKeys.Count -eq 0) ($envKeys -join '; ')
    $allowed = @{
        'Unit'    = @('Description', 'Documentation', 'After', 'Wants', 'Before', 'Requires', 'ConditionPathExists')
        'Service' = @('Type', 'ExecStart', 'ExecStartPre', 'EnvironmentFile', 'Environment', 'TimeoutStartSec', 'Nice', 'IOSchedulingClass', 'IOSchedulingPriority', 'SyslogIdentifier', 'User', 'Group', 'WorkingDirectory', 'StandardOutput', 'StandardError')
        'Timer'   = @('OnCalendar', 'Persistent', 'AccuracySec', 'RandomizedDelaySec', 'Unit', 'OnBootSec')
        'Install' = @('WantedBy', 'RequiredBy', 'Also')
    }
    $required = @{ 'service' = @{ 'Unit' = @('Description'); 'Service' = @('Type', 'ExecStart') }; 'timer' = @{ 'Timer' = @('OnCalendar', 'Persistent', 'Unit'); 'Install' = @('WantedBy') } }
    $problems = @()
    foreach ($p in @(@{ n = 'service'; v = $svcU }, @{ n = 'timer'; v = $timerU })) {
        $problems += @($p.v.Bad | ForEach-Object { "$($p.n): $_" })
        foreach ($sec in $p.v.Sections.Keys) {
            if (-not $allowed.Contains($sec)) { $problems += "$($p.n): unknown section [$sec]"; continue }
            foreach ($k in $p.v.Sections[$sec].Keys) { if ($allowed[$sec] -notcontains $k) { $problems += "$($p.n): unknown key $sec/$k" } }
        }
        foreach ($sec in $required[$p.n].Keys) {
            if (-not $p.v.Sections.Contains($sec)) { $problems += "$($p.n): missing section [$sec]"; continue }
            foreach ($k in $required[$p.n][$sec]) { if (-not $p.v.Sections[$sec].Contains($k)) { $problems += "$($p.n): missing required key $sec/$k" } }
        }
    }
    Assert 'unit-8: known sections/keys only (spelling — systemd ignores typos silently) and every required key present' ($problems.Count -eq 0) ($problems -join '; ')
}

# ---------- IDEM ----------
Test-Group 'idem' {
    $pb = Get-FunctionBody $text 'preflight'
    $cb = Get-FunctionBody $text 'cleanup'
    Assert 'idem-1: only one run at a time (flock on a lock fd; a concurrent timer/pre-upgrade run dies cleanly)' ($null -ne $pb -and (Has $pb 'exec 9>"$LOCK_FILE"') -and (Has $pb 'flock -n 9 || die') -and (Has $codeText 'LOCK_FILE=/run/lock/platform-backup.lock')) 'flock guard missing'
    Assert 'idem-2: work happens in a fresh mktemp -d workdir with an EXIT trap' ($null -ne $pb -and (Has $pb 'WORKDIR=$(mktemp -d -p "$WORK_PARENT" platform-backup.XXXXXX)') -and (Has $codeText 'trap cleanup EXIT')) 'temp workdir or trap missing'
    Assert 'idem-3: cleanup shreds every plaintext file and removes the workdir even on failure' ($null -ne $cb -and (Has $cb 'find "$WORKDIR" -type f -exec shred -u -- {} +') -and (Has $cb 'rm -rf -- "$WORKDIR"')) 'cleanup incomplete'
}

# ---------- SECRETS ----------
Test-Group 'sec' {
    Assert 'sec-1: no shell tracing (set -x / xtrace / bash -x) — tracing would echo the JWT and the Vault token' (($codeText -cnotmatch '(?m)^\s*set\s+-[a-z]*x') -and (-not (Has $codeText 'xtrace')) -and ($codeText -cnotmatch '\bbash\s+-[a-z]*x\b')) 'tracing found in code lines'
    $tokenPrint = @($code | Where-Object { $_ -cmatch '\b(log|warn|err|die|echo)\b[^\n]*\$(vault_token|VAULT_TOKEN)\b' -or $_ -cmatch 'printf[^\n]*\$(vault_token|VAULT_TOKEN)\b' })
    Assert 'sec-2: the Vault token never reaches a log line, the summary or a command line (env prefix only)' ($tokenPrint.Count -eq 0 -and ($codeText -cnotmatch '-token[= ]') -and ($codeText -cnotmatch 'VAULT_TOKEN="\$vault_token" vault[^\n]*\$vault_token')) "token printed on: $($tokenPrint -join ' | ')"
    Assert 'sec-3: the K3s server token is copied, never read (no cat/head/tail/od/xxd/hexdump/base64/strings/awk/sed/grep on it)' ($codeText -cnotmatch '(?m)\b(cat|head|tail|od|xxd|hexdump|base64|strings|awk|sed|grep)\b[^\n]*(server/token|K3S_SERVER_DIR/token)') 'the bundled token would leak into output'
    $recipientGreps = @([regex]::Matches($codeText, 'grep(\s+-[^\s]+)*(?=[^\n]*AGE_RECIPIENT_FILE)') | ForEach-Object { $_.Value })
    $badGreps = @($recipientGreps | Where-Object { $_ -cnotmatch '^grep\s+-[A-Za-z]*[qc]' })
    Assert 'sec-4: every grep against a credential-adjacent file is quiet (-q/-c), so contents cannot reach stdout' ($recipientGreps.Count -ge 1 -and $badGreps.Count -eq 0) "greps=[$($recipientGreps -join ' | ')] non-quiet=[$($badGreps -join ' | ')]"
    Assert 'sec-5: no vault login and no token written to disk (~/.vault-token stays absent)' ((-not (Has $codeText 'vault login')) -and (-not (Has $codeText '.vault-token')) -and ($codeText -cnotmatch '\$vault_token"?\s*>')) 'a persisted Vault token path appeared'
    $patterns = @(
        '-----BEGIN [A-Z ]*PRIVATE KEY-----',
        'AKIA[0-9A-Z]{16}',
        'hvs\.[A-Za-z0-9]{20,}',
        's\.[A-Za-z0-9]{24,}',
        'ghp_[A-Za-z0-9]{30,}',
        'ssh-ed25519 AAAA',
        'AGE-SECRET-KEY-1[A-Z0-9]{20,}',
        'age1[a-z0-9]{58}',
        'ocid1\.(user|tenancy|key|instance|credential)\.',
        '(?i)(password|passwd|secret|api[_-]?key|token)\s*=\s*[''"][^''"$][^''"]{7,}[''"]',
        'K10[0-9a-f]{20,}::',
        '(?m)^[0-9a-f]{64}$'
    )
    $hits = @()
    foreach ($p in $patterns) { if ($text -cmatch $p) { $hits += $p } }
    Assert 'sec-6: no secret-looking strings (private keys, cloud/Vault tokens, a real age recipient, OCIDs, literal passwords)' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
}

# ---------- LOG ----------
Test-Group 'log' {
    $sb = Get-FunctionBody $text 'summary'
    Assert 'log-1: [platform-backup] prefixed log/warn/err/die helpers' ((Has $codeText "printf '[platform-backup] %s\n'") -and (Has $codeText "printf '[platform-backup] WARN: %s\n'") -and (Has $codeText "printf '[platform-backup] ERROR: %s\n'")) 'log helpers missing'
    Assert 'log-2: summary reports each component with OK/FAIL, the object name and the encrypted size' ($null -ne $sb -and (Has $sb 'OK   object=%s bytes=%s') -and (Has $sb 'FAIL reason=%s') -and (Has $sb '${OBJECT[$c]}') -and (Has $sb '${BYTES[$c]}')) 'per-component summary fields missing'
    Assert 'log-3: summary ends with the exit code and states the pre-upgrade gate result' ($null -ne $sb -and (Has $sb "==== end: exit %d ====") -and (Has $sb 'pre-upgrade gate: %s')) 'summary tail missing'
}

# ---------- SYNTAX ----------
Test-Group 'syntax' {
    $bash = $null
    foreach ($c in @('C:\Program Files\Git\bin\bash.exe', 'C:\Program Files\Git\usr\bin\bash.exe')) { if (Test-Path -LiteralPath $c -PathType Leaf) { $bash = $c; break } }
    if (-not $bash) {
        $cmd = Get-Command bash -ErrorAction SilentlyContinue
        if ($cmd -and $cmd.Source -and $cmd.Source -notmatch '(?i)\\System32\\') { $bash = $cmd.Source }
    }
    if (-not $bash) {
        Write-Host 'SKIP syntax-1 -- bash -n: no Git/POSIX bash found on this machine (WSL System32 bash is not used); run "bash -n infra/bootstrap/platform-backup.sh" where bash exists'
    } else {
        $unixPath = $target -replace '\\', '/'
        $out = & $bash -n $unixPath 2>&1 | Out-String
        $c = $LASTEXITCODE
        Assert "syntax-1: bash -n passes ($bash)" ($c -eq 0) "exit=$c; $($out.Trim())"
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
