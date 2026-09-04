# tests/infra/platform-backup.tests.ps1 — infra/bootstrap/platform-backup.{sh,service,timer} 정적 검사 스위트 (T036, FR-047)
# Run: pwsh -NoProfile -File tests/infra/platform-backup.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/infra/k3s-server.tests.ps1 과 같은 구조). 문자열 비교는 전부 Ordinal.
#
# fail closed: 세 파일 중 하나라도 없으면 전 단언 FAIL. 유일한 SKIP은 syntax-1(bash -n) — Git bash가 없을 때만.
# 실행(노드·kubectl·vault·oci·age)은 하지 않는다 — 이 스위트는 원문만 읽는다. 실제 백업·복원 가능성 검증은 운영자(절차 3·4)와 T048 몫이다.
# systemd unit은 systemd-analyze verify를 쓸 수 없으므로(Windows) 섹션·키 철자를 허용 목록으로 직접 검사한다.
#
# 검사 계약(platform-backup.sh 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   FILE   file-1 sh 존재  file-2 첫 줄 '#!/usr/bin/env bash'  file-3 세 파일 모두 CR 없음·끝 개행  file-4 'set -euo pipefail'  file-5 umask 077
#          file-6 마지막 줄 'main "$@" </dev/null; exit'  file-7 한 local 안에서 자기 선언 변수를 참조하지 않음(SC2318)
#   K3S    k3s-1 sqlite3 ".backup" 온라인 스냅샷(WAL 안전)  k3s-2 PRAGMA integrity_check = ok 확인  k3s-3 server/token 포함  k3s-4 server/cred 포함
#          k3s-5 server/tls 포함(없으면 복원 시 인증서 재생성 → 노드 B 재조인 깨짐)  k3s-6 tar 구성원 정확히 state.db token cred tls
#          k3s-7 오브젝트 k3s/<UTC ts>.tar.age  k3s-8 평문 tar/디렉터리 shred
#   VAULT  v-1 kubectl create token vault-backup --audience vault --duration=10m  v-2 port-forward svc/vault :8200(빈 로컬 포트)
#          v-3 VAULT_ADDR = <scheme>://127.0.0.1:<port>  v-4 로그인 jwt=- (파이프; 명령줄·파일에 JWT 없음)  v-5 raft snapshot save
#          v-6 token revoke -self  v-7 port-forward 종료(trap + stop)  v-8 오브젝트 vault/<ts>.snap.age  v-9 공개 호스트·pod IP 미사용
#   AGE    age-1 recipient 파일 기본 경로 + 부재 die  age-2 age1 형식 검증  age-3 AGE-SECRET-KEY 거부  age-4 age -r "$AGE_RECIPIENT" -o
#          age-5 age -d 없음(복호화는 운영자 워크스테이션)  age-6 공개키 전체를 로그에 찍지 않음
#   OCI    oci-1 모든 oci 호출이 --auth instance_principal  oci-2 버킷 joshuatech-backup-platform + 네임스페이스 기본값  oci-3 OCI_BIN=/usr/local/bin/oci
#          oci-4 다른 자격 없음(api_key·security_token·~/.oci·profile)  oci-5 삭제·목록·다운로드 없음(put/head만)
#   TF     tf-1 textfile 디렉터리 경로  tf-2 지표 이름 + component 라벨(컴포넌트마다 별도 파일)  tf-3 임시 파일 + mv 원자 쓰기(임시는 .prom 아님)
#          tf-4 성공 경로에서만 기록  tf-5 디렉터리 install -d -m 755
#   CLI    cli-1 --pre-upgrade = 두 컴포넌트 필수 + --components 병용 거부  cli-2 --components 허용값 검증  cli-3 알 수 없는 인자 die
#          cli-4 BACKUP_COMPONENTS 기본 k3s,vault  cli-5 한 컴포넌트 실패해도 나머지 시도, 하나라도 실패면 exit 1
#   UNIT   unit-1 timer OnCalendar '*-*-* 02:30:00 Asia/Seoul'  unit-2 Persistent=true  unit-3 [Install] WantedBy=timers.target  unit-4 Unit=platform-backup.service
#          unit-5 service Type=oneshot + ExecStart 절대 경로  unit-6 EnvironmentFile=- (선택)  unit-7 unit에 비밀 없음  unit-8 섹션·키 철자 허용 목록
#   IDEM   idem-1 flock 단일 실행  idem-2 mktemp -d 작업 디렉터리 + trap cleanup  idem-3 cleanup이 평문 shred + port-forward 종료
#   SEC    sec-1 set -x/xtrace 없음  sec-2 Vault 토큰이 로그·summary에 없음  sec-3 server/token 내용 판독 없음(cp만)  sec-4 비밀 파일 grep은 -q/-c
#          sec-5 vault login·토큰 파일 기록 없음  sec-6 비밀로 보이는 문자열 없음
#   LOG    log-1 '[platform-backup]' 접두  log-2 컴포넌트별 OK/FAIL + object + bytes  log-3 exit 코드 줄
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
    'k3s-1', 'k3s-2', 'k3s-3', 'k3s-4', 'k3s-5', 'k3s-6', 'k3s-7', 'k3s-8',
    'v-1', 'v-2', 'v-3', 'v-4', 'v-5', 'v-6', 'v-7', 'v-8', 'v-9',
    'age-1', 'age-2', 'age-3', 'age-4', 'age-5', 'age-6',
    'oci-1', 'oci-2', 'oci-3', 'oci-4', 'oci-5',
    'tf-1', 'tf-2', 'tf-3', 'tf-4', 'tf-5',
    'cli-1', 'cli-2', 'cli-3', 'cli-4', 'cli-5',
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

# systemd unit 파싱: 섹션 → 키 목록(주석·빈 줄 제외)
function Parse-Unit([string]$unitText) {
    $result = [ordered]@{}
    $section = ''
    $bad = @()
    foreach ($l in ($unitText -split "`n")) {
        $t = $l.TrimEnd("`r")
        if ($t.Trim().Length -eq 0 -or $t -cmatch '^\s*#') { continue }
        if ($t -cmatch '^\[([A-Za-z]+)\]$') { $section = $Matches[1]; if (-not $result.Contains($section)) { $result[$section] = @() }; continue }
        if ($t -cmatch '^([A-Za-z][A-Za-z0-9]*)=(.*)$') {
            if ($section -eq '') { $bad += "key before section: $t"; continue }
            $result[$section] += $Matches[1]
            continue
        }
        $bad += "unparsed: $t"
    }
    return @{ Sections = $result; Bad = $bad }
}
$svcParsed = Parse-Unit $svc
$timerParsed = Parse-Unit $timer

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
    # 컴포넌트별 지표 파일 이름이 조용히 비는 사고(platform_backup_.prom 하나에 두 컴포넌트가 덮어쓰기)를 막는 계약.
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
    Assert 'k3s-1: online snapshot via sqlite3 ".backup" (never a raw file copy — kine SQLite runs in WAL mode, K3S-D9)' ($null -ne $b -and (Has $b 'sqlite3 "$K3S_STATE_DB" ".backup') -and (Has $codeText 'K3S_STATE_DB="$K3S_SERVER_DIR/db/state.db"') -and ($b -cnotmatch 'cp[^\n]*state\.db')) 'sqlite3 .backup missing or state.db copied directly'
    Assert 'k3s-2: snapshot verified with PRAGMA integrity_check = ok before upload' ($null -ne $b -and (Has $b 'PRAGMA integrity_check') -and (Has $b '[ "$check" = ok ]') -and ((Idx $b 'PRAGMA integrity_check') -lt (Idx $b 'tar -C'))) 'integrity check missing or after the tar'
    Assert 'k3s-3: server/token included (bootstrap data PBKDF2 key — without it the snapshot cannot be restored)' ($null -ne $b -and (Has $b 'cp -p -- "$K3S_SERVER_DIR/token" "$dir/token"') -and (Has $b '[ -f "$K3S_SERVER_DIR/token" ]')) 'token not bundled'
    Assert 'k3s-4: server/cred/ included' ($null -ne $b -and (Has $b 'cp -rp -- "$K3S_SERVER_DIR/cred" "$dir/cred"') -and (Has $b '[ -d "$K3S_SERVER_DIR/cred" ]')) 'cred/ not bundled'
    Assert 'k3s-5: server/tls/ included (restoring without it regenerates certificates and breaks the node B rejoin)' ($null -ne $b -and (Has $b 'cp -rp -- "$K3S_SERVER_DIR/tls" "$dir/tls"') -and (Has $b '[ -d "$K3S_SERVER_DIR/tls" ]')) 'tls/ not bundled — rollback.md depends on it'
    Assert 'k3s-6: tar members are exactly state.db token cred tls' ($null -ne $b -and ($b -cmatch '(?m)tar -C "\$dir"[^\n]*-cf "\$tar" state\.db token cred tls\b')) 'tar member list differs'
    Assert 'k3s-7: object name k3s/k3s-<UTC ts>.tar.age with ts=date -u +%Y%m%dT%H%M%SZ' ($null -ne $b -and (Has $b 'obj="k3s/k3s-$TS.tar.age"') -and (Has $codeText 'TS=$(date -u +%Y%m%dT%H%M%SZ)')) 'object naming or UTC timestamp missing'
    Assert 'k3s-8: plaintext is shredded (bundle dir during the run, everything again in the EXIT trap)' ($null -ne $b -and (Has $b 'shred -u --') -and (Has $codeText 'find "$WORKDIR" -type f -exec shred -u -- {} +')) 'plaintext shredding missing'
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
    Assert 'v-9: never the public host or a pod IP — no vault.joshuatech.dev, no https://vault., no 10.42/10.43 literal' ((-not (Has $text 'vault.joshuatech.dev')) -and ($codeText -cnotmatch 'VAULT_ADDR="?https?://(?!127\.0\.0\.1)') -and ($codeText -cnotmatch '10\.4[23]\.')) 'public host or pod IP reachable path found'
}

# ---------- AGE ----------
Test-Group 'age' {
    $pb = Get-FunctionBody $text 'preflight'
    $eb = Get-FunctionBody $text 'encrypt_file'
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
    Assert 'tf-1: node-exporter textfile dir /var/lib/node_exporter/textfile_collector' (Has $codeText 'TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector') 'textfile dir constant missing'
    Assert 'tf-2: one file per component with platform_backup_last_success_timestamp{component="<c>"}' ($null -ne $wb -and (Has $wb 'file="$TEXTFILE_DIR/platform_backup_$component.prom"') -and (Has $wb 'platform_backup_last_success_timestamp{component="%s"} %s') -and (Has $wb '# TYPE platform_backup_last_success_timestamp gauge')) 'per-component metric file missing (PlatformBackupStale must fire per component)'
    Assert 'tf-3: atomic write — mktemp in the same dir (temp name is not *.prom) then mv -f' ($null -ne $wb -and (Has $wb 'mktemp -p "$TEXTFILE_DIR" ".platform_backup_$component.XXXXXX"') -and (Has $wb 'mv -f "$tmp" "$file"') -and ((Idx $wb 'mktemp -p') -lt (Idx $wb 'mv -f "$tmp" "$file"')) -and ($wb -cnotmatch '> "\$file"')) 'non-atomic write (a half-written .prom would be scraped)'
    $callers = @($code | Where-Object { $_ -cmatch '^\s*write_textfile ' })
    Assert 'tf-4: the metric is written only on the success path (called from finish_component, after the upload)' ($null -ne $fb -and (Has $fb 'write_textfile "$component" "$now"') -and $callers.Count -eq 1 -and (Has $codeText 'finish_component k3s') -and (Has $codeText 'finish_component vault')) "write_textfile callers=$($callers.Count) (expected exactly 1: finish_component)"
    Assert 'tf-5: the textfile directory is created 0755 when absent' ($null -ne $wb -and (Has $wb 'install -d -m 755 "$TEXTFILE_DIR"')) 'directory creation missing'
}

# ---------- CLI ----------
Test-Group 'cli' {
    $pa = Get-FunctionBody $text 'parse_args'
    $mb = Get-FunctionBody $text 'main'
    $sb = Get-FunctionBody $text 'summary'
    Assert 'cli-1: --pre-upgrade forces both components and refuses --components (T037 prepare gate)' ($null -ne $pa -and (Has $pa '--pre-upgrade) PRE_UPGRADE=1') -and (Has $pa 'BACKUP_COMPONENTS=k3s,vault') -and (Has $pa '[ -z "$COMPONENTS_ARG" ] || die')) 'pre-upgrade semantics missing'
    Assert 'cli-2: --components accepts only k3s/vault (anything else dies)' ($null -ne $pa -and (Has $pa 'case "$c" in k3s|vault) ;; *) die')) 'component validation missing'
    Assert 'cli-3: an unknown argument dies with usage' ($null -ne $pa -and (Has $pa 'usage >&2; die')) 'unknown-arg guard missing'
    Assert 'cli-4: BACKUP_COMPONENTS default k3s,vault (env overridable so the timer can run k3s-only before T044)' (Has $codeText 'BACKUP_COMPONENTS="${BACKUP_COMPONENTS:-k3s,vault}"') 'default component list missing'
    Assert 'cli-5: a failing component does not stop the others, and any failure exits non-zero' ($null -ne $mb -and (Has $mb 'backup_k3s || true') -and (Has $mb 'backup_vault || true') -and ($null -ne $sb) -and (Has $sb 'rc=1') -and (Has $sb 'return "$rc"')) 'per-component isolation or the non-zero exit is missing (SUC prepare must be blocked on failure)'
}

# ---------- SYSTEMD UNITS ----------
Test-Group 'unit' {
    Assert 'unit-1: timer OnCalendar=*-*-* 02:30:00 Asia/Seoul (timezone pinned in the expression, not inherited)' (Has $timer 'OnCalendar=*-*-* 02:30:00 Asia/Seoul') "timer OnCalendar line missing"
    Assert 'unit-2: Persistent=true (a missed 02:30 run catches up after downtime)' (Has $timer 'Persistent=true') 'Persistent missing'
    Assert 'unit-3: [Install] WantedBy=timers.target' (($timerParsed.Sections.Contains('Install')) -and (Has $timer 'WantedBy=timers.target')) 'timer is not installable (systemctl enable would fail)'
    Assert 'unit-4: the timer points at platform-backup.service' (Has $timer 'Unit=platform-backup.service') 'Unit= missing'
    Assert 'unit-5: service Type=oneshot with the absolute ExecStart path' ((Has $svc 'Type=oneshot') -and (Has $svc 'ExecStart=/usr/local/bin/platform-backup.sh')) 'service type/ExecStart wrong'
    Assert 'unit-6: EnvironmentFile is optional (leading -) so a missing /etc/platform-backup/env is not a failure' (Has $svc 'EnvironmentFile=-/etc/platform-backup/env') 'optional EnvironmentFile missing'
    $unitSecret = @(@($svc, $timer) | Where-Object { $_ -cmatch '(?im)^\s*Environment=.*(TOKEN|SECRET|PASSWORD|KEY)' })
    Assert 'unit-7: no credentials in the unit files (credentials come from the instance principal at run time)' ($unitSecret.Count -eq 0) 'Environment= with a credential-looking name found'
    $allowed = @{
        'Unit'    = @('Description', 'Documentation', 'After', 'Wants', 'Before', 'Requires', 'ConditionPathExists')
        'Service' = @('Type', 'ExecStart', 'ExecStartPre', 'EnvironmentFile', 'Environment', 'TimeoutStartSec', 'Nice', 'IOSchedulingClass', 'IOSchedulingPriority', 'SyslogIdentifier', 'User', 'Group', 'WorkingDirectory', 'StandardOutput', 'StandardError')
        'Timer'   = @('OnCalendar', 'Persistent', 'AccuracySec', 'RandomizedDelaySec', 'Unit', 'OnBootSec')
        'Install' = @('WantedBy', 'RequiredBy', 'Also')
    }
    $badKeys = @()
    foreach ($p in @(@{ n = 'service'; v = $svcParsed }, @{ n = 'timer'; v = $timerParsed })) {
        $badKeys += @($p.v.Bad | ForEach-Object { "$($p.n): $_" })
        foreach ($sec in $p.v.Sections.Keys) {
            if (-not $allowed.Contains($sec)) { $badKeys += "$($p.n): unknown section [$sec]"; continue }
            foreach ($k in $p.v.Sections[$sec]) { if ($allowed[$sec] -notcontains $k) { $badKeys += "$($p.n): unknown key $sec/$k" } }
        }
    }
    Assert 'unit-8: every section and key is a known systemd directive (spelling check — systemd silently ignores typos)' ($badKeys.Count -eq 0) ($badKeys -join '; ')
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
