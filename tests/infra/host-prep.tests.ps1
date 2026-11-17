# tests/infra/host-prep.tests.ps1 — infra/bootstrap/host-prep.sh 정적 검사 스위트 (T014, test-first)
# Run: pwsh -NoProfile -File tests/infra/host-prep.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/agents·tests/infra/tofu 하네스와 같은 구조). 문자열 비교는 전부 Ordinal.
#
# fail closed: 대상 파일이 없으면 전 단언 FAIL. 유일한 SKIP은 syntax-1(bash -n) — Windows에서 Git bash를 찾지 못하면
# 'SKIP syntax-1 -- ...' 한 줄을 내고 합계(passed/failed)에 넣지 않는다(WSL의 System32\bash.exe는 쓰지 않는다: Windows 경로를 못 읽는다).
# 실행(SSH·노드)은 하지 않는다 — 이 스위트는 원문만 읽는다. 실행 검증(두 번 실행해 같은 결과)은 운영자가 노드에서 한다(.claude/rules/infra.md).
#
# 검사 계약(host-prep.sh 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   FILE   file-1 존재  file-2 첫 줄 '#!/usr/bin/env bash'  file-3 CR 없음(LF only)·끝 개행  file-4 'set -euo pipefail' 한 줄
#   FORBID forbid-1 'cloud-init clean' 없음  forbid-2 /var/lib/cloud 삭제 없음  forbid-3 ufw 편집/활성 없음
#          forbid-4 apt upgrade 없음  forbid-5 OCI 자격 설정(oci setup config·~/.oci/config 쓰기) 없음  forbid-6 authorized_keys rm 없음
#   IPT    ipt-1 6443/tcp  ipt-2 51820/udp  ipt-3 10250/tcp  ipt-4 파드 CIDR 규칙(기본 10.42.0.0/16)  ipt-5 VXLAN 8472 없음
#          ipt-6 REJECT 앞 삽입 앵커('-j REJECT')  ipt-7 netfilter-persistent reload  ipt-8 iptables -C 검증  ipt-9 K3s 활성 시 reload 회피 가드
#          ipt-10 FORWARD 앵커 부재 폴백(정책 ACCEPT → skip, 아니면 COMMIT 앞 append) + INPUT 앵커 부재는 die
#   WG     wg-1 'lsmod | grep -q '^wireguard' || modprobe wireguard'  wg-2 /etc/modules-load.d/wireguard.conf  wg-3 등재 전 grep -qxF 가드
#   AK     ak-1 경로 /home/ubuntu/.ssh/authorized_keys  ak-2 NEW_PUBKEY 필수 + ed25519 정규식  ak-3 추가 전 grep -qxF 가드
#          ak-4 chmod 600 + chown ubuntu  ak-5 줄 수 출력  ak-6 제거 함수 호출은 정확히 1회이며 DROP_V1_KEY=1 게이트 안
#          ak-7 제거 함수에 세션 지문 가드(sshd 'Accepted publickey')  ak-8 제거 함수가 빈 결과로 파일을 덮어쓰지 않는다(-s 가드)
#   IDEM   idem-1 ensure_rule_before_reject: grep -qxF가 insert_rule_before 호출보다 앞  idem-2 write_if_changed: cmp -s
#          idem-3 apt_install_missing: dpkg-query 가드  idem-4 install_oci_cli: pipx list가 pipx install보다 앞
#          idem-5 install_vault_cli: 키링 -s 가드가 curl보다 앞  idem-6 setup_timezone: timedatectl show가 set-timezone보다 앞
#          idem-7 rules.v4·authorized_keys 교체는 같은 디렉터리 mktemp + mv(rename) 원자 교체('cat >' 덮어쓰기 없음)
#   CG     cg-1 stat -fc %T /sys/fs/cgroup == cgroup2fs
#   PKG    pkg-1 sqlite3·age  pkg-2 vault(HashiCorp apt, arch=arm64, signed-by, Pin: version)  pkg-3 oci-cli(pipx)
#          pkg-4 NODE_ROLE platform|data 검증 + platform 전용 게이트
#   UU     uu-1 50unattended-upgrades·20auto-upgrades  uu-2 -security 오리진만(주석 아닌 줄에 -updates 없음)  uu-3 Unattended-Upgrade "1"
#   TZ     tz-1 set-timezone Asia/Seoul
#   STDIN  stdin-1 마지막 줄 'main "$@" </dev/null; exit' (bash -s 스트리밍 시 자식이 스크립트 본문을 먹지 않게)
#   SECRET secret-1 비밀로 보이는 문자열 없음
#   SYNTAX syntax-1 bash -n (bash 없으면 SKIP)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/host-prep.sh'

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

# 'name() {' 부터 열 0의 '}' 까지 — 함수 본문. 없으면 $null(fail closed 단언용).
function Get-FunctionBody([string]$text, [string]$name) {
    $m = [regex]::Match($text, '(?ms)^' + [regex]::Escape($name) + '\(\) \{\n(.*?)^\}')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

# 주석(#로 시작) 아닌 줄만
function Get-CodeLines([string[]]$lines) { return @($lines | Where-Object { $_ -cnotmatch '^\s*#' }) }

if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    # fail closed: 파일이 없으면 계약의 단언 전부 FAIL
    foreach ($n in @('file-1', 'file-2', 'file-3', 'file-4', 'forbid-1', 'forbid-2', 'forbid-3', 'forbid-4', 'forbid-5', 'forbid-6',
            'ipt-1', 'ipt-2', 'ipt-3', 'ipt-4', 'ipt-5', 'ipt-6', 'ipt-7', 'ipt-8', 'ipt-9', 'ipt-10', 'wg-1', 'wg-2', 'wg-3',
            'ak-1', 'ak-2', 'ak-3', 'ak-4', 'ak-5', 'ak-6', 'ak-7', 'ak-8', 'idem-1', 'idem-2', 'idem-3', 'idem-4', 'idem-5', 'idem-6', 'idem-7',
            'cg-1', 'pkg-1', 'pkg-2', 'pkg-3', 'pkg-4', 'uu-1', 'uu-2', 'uu-3', 'tz-1', 'stdin-1', 'secret-1', 'syntax-1')) {
        Assert $n $false "missing: infra/bootstrap/host-prep.sh"
    }
    Write-Host "`n$($script:pass) passed, $($script:fail) failed"
    exit 1
}

$text = Read-Text $target
$lines = $text -split "`n"
$code = Get-CodeLines $lines
$codeText = ($code -join "`n")

# ---------- FILE ----------
Test-Group 'file' {
    Assert 'file-1: infra/bootstrap/host-prep.sh exists' $true ''
    Assert 'file-2: first line is #!/usr/bin/env bash' ([string]::Equals($lines[0], '#!/usr/bin/env bash', [StringComparison]::Ordinal)) "first line: '$($lines[0])'"
    Assert 'file-3: LF only (no CR) and ends with newline' ((-not (Has $text "`r")) -and $text.EndsWith("`n", [StringComparison]::Ordinal)) 'CR found or missing final newline (.gitattributes forces LF; bash chokes on CRLF)'
    Assert 'file-4: set -euo pipefail present as a whole line' (@($lines | Where-Object { [string]::Equals($_, 'set -euo pipefail', [StringComparison]::Ordinal) }).Count -ge 1) 'no exact line "set -euo pipefail"'
}

# ---------- FORBID ----------
Test-Group 'forbid' {
    Assert 'forbid-1: no "cloud-init clean"' (-not (Has $codeText 'cloud-init clean')) 'cloud-init clean re-injects the immutable-metadata v1 key on next boot'
    Assert 'forbid-2: no deletion of /var/lib/cloud' ($codeText -cnotmatch '\brm\b[^\n]*/var/lib/cloud') 'rm ... /var/lib/cloud found'
    Assert 'forbid-3: ufw is never edited or enabled' ($codeText -cnotmatch '\bufw\s+(allow|deny|enable|default|reject|route|insert)\b') 'ufw editing found (Oracle: never edit rules with ufw on OCI Ubuntu)'
    Assert 'forbid-4: no apt-get upgrade / dist-upgrade' ($codeText -cnotmatch '\bapt(-get)?\s+(dist-)?upgrade\b') 'apt upgrade found (host-prep installs packages only)'
    Assert 'forbid-5: no OCI credential setup (oci setup config / ~/.oci/config write)' ((-not (Has $codeText 'oci setup')) -and ($codeText -cnotmatch '\.oci/config')) 'instance-principal is a runtime flag; nothing secret is configured'
    # rm 의 인자(옵션 뒤 첫 경로)가 authorized_keys 또는 $AK_FILE 인 경우만 — 같은 줄의 메시지 문자열은 보지 않는다
    Assert 'forbid-6: authorized_keys is never rm-ed' ($codeText -cnotmatch '\brm\s+(-[A-Za-z]+\s+)*("?\$\{?AK_FILE\}?"?|\S*authorized_keys)') 'rm <...>authorized_keys / rm "$AK_FILE" found'
}

# ---------- IPT ----------
Test-Group 'ipt' {
    Assert 'ipt-1: 6443/tcp ACCEPT rule' ($codeText -cmatch '-A INPUT -s \$VCN_CIDR -p tcp -m tcp --dport 6443 -j ACCEPT') 'expected "-A INPUT -s $VCN_CIDR -p tcp -m tcp --dport 6443 -j ACCEPT"'
    Assert 'ipt-2: 51820/udp ACCEPT rule (flannel wireguard-native)' ($codeText -cmatch '-A INPUT -s \$VCN_CIDR -p udp -m udp --dport 51820 -j ACCEPT') 'expected "-A INPUT -s $VCN_CIDR -p udp -m udp --dport 51820 -j ACCEPT"'
    Assert 'ipt-3: 10250/tcp ACCEPT rule' ($codeText -cmatch '-A INPUT -s \$VCN_CIDR -p tcp -m tcp --dport 10250 -j ACCEPT') 'expected "-A INPUT -s $VCN_CIDR -p tcp -m tcp --dport 10250 -j ACCEPT"'
    Assert 'ipt-4: pod CIDR rule with K3s default 10.42.0.0/16' ((Has $codeText '-A INPUT -s $POD_CIDR -j ACCEPT') -and (Has $codeText 'POD_CIDR="${POD_CIDR:-10.42.0.0/16}"')) 'expected "-A INPUT -s $POD_CIDR -j ACCEPT" and default POD_CIDR 10.42.0.0/16'
    Assert 'ipt-5: no VXLAN 8472 anywhere in code' (-not (Has $codeText '8472')) 'wireguard-native uses 51820/udp only; 8472 must not be opened'
    Assert 'ipt-6: rules are inserted before the "-j REJECT" anchor' ((Has $codeText 'insert_rule_before "^-A $chain -j REJECT" "$rule"') -and (Has $codeText '$0 ~ anchor { print rule; done = 1 }')) 'insert_rule_before "^-A $chain -j REJECT" call / awk anchor insert not found'
    Assert 'ipt-10: FORWARD anchor fallback (policy ACCEPT -> skip; else append before COMMIT) and INPUT anchor missing -> die' ((Has $codeText 'grep -qE ''^:FORWARD ACCEPT '' "$RULES_V4"') -and (Has $codeText 'insert_rule_before ''^COMMIT$'' "$rule"') -and (Has $codeText 'die "$RULES_V4 에 ''-A $chain -j REJECT'' 줄이 없다')) 'FORWARD fallback branches or INPUT die missing'
    Assert 'ipt-7: netfilter-persistent reload' (Has $codeText 'netfilter-persistent reload') 'missing netfilter-persistent reload'
    Assert 'ipt-8: live verification with iptables -C' ($codeText -cmatch 'iptables \$\{rule/#-A /-C \}') 'missing iptables -C verification'
    Assert 'ipt-9: full reload is skipped while k3s/k3s-agent is active' ((Has $codeText 'systemctl is-active --quiet k3s') -and (Has $codeText 'systemctl is-active --quiet k3s-agent')) 'iptables-restore would flush kube-proxy/flannel chains'
}

# ---------- WG ----------
Test-Group 'wg' {
    Assert 'wg-1: lsmod | grep -q ''^wireguard'' || modprobe wireguard' (Has $codeText "lsmod | grep -q '^wireguard' || modprobe wireguard") 'exact task-text form expected'
    Assert 'wg-2: /etc/modules-load.d/wireguard.conf' (Has $codeText 'WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf') 'missing WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf'
    $b = Get-FunctionBody $text 'setup_wireguard_module'
    Assert 'wg-3: modules-load entry guarded by grep -qxF before append' ($null -ne $b -and (Has $b 'grep -qxF wireguard "$WG_MODULES_CONF"') -and ((Idx $b 'grep -qxF wireguard') -lt (Idx $b '>> "$WG_MODULES_CONF"'))) 'setup_wireguard_module missing or guard not before append'
}

# ---------- AK ----------
Test-Group 'ak' {
    Assert 'ak-1: authorized_keys path /home/ubuntu/.ssh/authorized_keys' ((Has $codeText 'AK_DIR=/home/ubuntu/.ssh') -and (Has $codeText 'AK_FILE="$AK_DIR/authorized_keys"')) 'path constants missing'
    Assert 'ak-2: NEW_PUBKEY required and validated as exactly ssh-ed25519 | sk-ssh-ed25519@openssh.com' ((Has $codeText '[ -n "${NEW_PUBKEY:-}" ] || die') -and (Has $codeText '^(ssh-ed25519|sk-ssh-ed25519@openssh\.com) [A-Za-z0-9+/]+=*( [^[:cntrl:]]*)?$')) 'required check or tightened ed25519 regex missing'
    $b = Get-FunctionBody $text 'setup_authorized_keys'
    Assert 'ak-3: add guarded by grep -qxF -- "$NEW_PUBKEY" before append' ($null -ne $b -and (Has $b 'grep -qxF -- "$NEW_PUBKEY" "$AK_FILE"') -and ((Idx $b 'grep -qxF -- "$NEW_PUBKEY"') -lt (Idx $b '>> "$AK_FILE"'))) 'setup_authorized_keys missing or guard not before append'
    Assert 'ak-4: chmod 600 + chown ubuntu:ubuntu on authorized_keys' ($null -ne $b -and (Has $b 'chmod 600 "$AK_FILE"') -and (Has $b 'chown ubuntu:ubuntu "$AK_FILE"')) 'perm/owner fix missing'
    Assert 'ak-5: resulting line count is printed' ($null -ne $b -and (Has $b 'AK_LINES=$(grep -c . "$AK_FILE"') -and (Has $b 'authorized_keys 줄 수: $AK_LINES')) 'line count print missing'
    # ak-6: 제거 함수 호출(정의 제외)은 정확히 1회, DROP_V1_KEY=1 게이트 블록 안
    $callLines = @()
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -cmatch '^\s+drop_other_keys\s*$') { $callLines += $i } }
    $gateStart = -1; $gateEnd = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ([string]::Equals($lines[$i], '  if [ "${DROP_V1_KEY:-0}" = 1 ]; then', [StringComparison]::Ordinal)) { $gateStart = $i; break } }
    if ($gateStart -ge 0) {
        for ($i = $gateStart + 1; $i -lt $lines.Count; $i++) { if ($lines[$i] -cmatch '^  (else|fi)\s*$') { $gateEnd = $i; break } }
    }
    $inGate = ($callLines.Count -eq 1 -and $gateStart -ge 0 -and $gateEnd -gt $gateStart -and $callLines[0] -gt $gateStart -and $callLines[0] -lt $gateEnd)
    Assert 'ak-6: drop_other_keys is called exactly once, inside the DROP_V1_KEY=1 gate' $inGate "calls=$($callLines.Count) gate=[$gateStart,$gateEnd] call=$($callLines -join ',')"
    $d = Get-FunctionBody $text 'drop_other_keys'
    Assert 'ak-7: drop_other_keys refuses unless this session logged in with NEW_PUBKEY (sshd Accepted publickey fingerprint)' ($null -ne $d -and (Has $d 'current_session_fingerprint') -and (Has $codeText 'Accepted publickey for ubuntu') -and (Has $d '[ "$have" = "$want" ] || die')) 'session fingerprint guard missing'
    Assert 'ak-8: drop_other_keys never replaces the file with an empty result (-s guard before the atomic mv)' ($null -ne $d -and (Has $d '[ -s "$tmp" ] ||') -and (Has $d 'mktemp -p "$AK_DIR"') -and (Has $d 'mv -f "$tmp" "$AK_FILE"') -and ((Idx $d '[ -s "$tmp" ] ||') -lt (Idx $d 'mv -f "$tmp" "$AK_FILE"'))) '-s guard missing, or not before mv, or temp not in $AK_DIR'
}

# ---------- IDEM ----------
Test-Group 'idem' {
    $b = Get-FunctionBody $text 'ensure_rule_before_reject'
    Assert 'idem-1: ensure_rule_before_reject greps (-qxF) before calling insert_rule_before' ($null -ne $b -and (Has $b 'grep -qxF -- "$rule" "$RULES_V4"') -and ((Idx $b 'grep -qxF') -lt (Idx $b 'insert_rule_before'))) 'guard missing or after insert'
    $b = Get-FunctionBody $text 'insert_rule_before'
    Assert 'idem-7: insert_rule_before replaces rules.v4 atomically (same-dir mktemp + mv), never "cat >" overwrite' ($null -ne $b -and (Has $b 'mktemp -p "$(dirname "$RULES_V4")"') -and (Has $b 'mv -f "$tmp" "$RULES_V4"') -and (-not (Has $codeText 'cat "$tmp" > "$RULES_V4"'))) 'atomic replace missing or cat > overwrite present'
    $b = Get-FunctionBody $text 'write_if_changed'
    Assert 'idem-2: write_if_changed compares with cmp -s before writing' ($null -ne $b -and (Has $b 'cmp -s') -and ((Idx $b 'cmp -s') -lt (Idx $b 'install -m'))) 'cmp -s guard missing'
    $b = Get-FunctionBody $text 'apt_install_missing'
    Assert 'idem-3: apt_install_missing checks dpkg-query before apt-get install' ($null -ne $b -and (Has $b 'dpkg-query -W') -and ((Idx $b 'dpkg-query -W') -lt (Idx $b 'apt-get install'))) 'dpkg-query guard missing'
    $b = Get-FunctionBody $text 'install_oci_cli'
    Assert 'idem-4: install_oci_cli checks pipx list before pipx install' ($null -ne $b -and (Has $b 'pipx list --short') -and ((Idx $b 'pipx list --short') -lt (Idx $b 'pipx install oci-cli'))) 'pipx list guard missing'
    $b = Get-FunctionBody $text 'install_vault_cli'
    Assert 'idem-5: install_vault_cli downloads the keyring only when absent (-s guard before curl)' ($null -ne $b -and (Has $b '[ ! -s "$HC_KEYRING" ]') -and ((Idx $b '[ ! -s "$HC_KEYRING" ]') -lt (Idx $b 'curl -fsSL'))) 'keyring guard missing'
    $b = Get-FunctionBody $text 'setup_timezone'
    Assert 'idem-6: setup_timezone reads current zone before set-timezone' ($null -ne $b -and (Has $b 'timedatectl show -p Timezone --value') -and ((Idx $b 'timedatectl show') -lt (Idx $b 'timedatectl set-timezone'))) 'timezone guard missing'
}

# ---------- CG ----------
Test-Group 'cg' {
    Assert 'cg-1: cgroup v2 check (stat -fc %T /sys/fs/cgroup == cgroup2fs, fail otherwise)' ((Has $codeText 'stat -fc %T /sys/fs/cgroup') -and (Has $codeText '[ "$fs" = cgroup2fs ] || die')) 'cgroup2fs check missing'
}

# ---------- PKG ----------
Test-Group 'pkg' {
    Assert 'pkg-1: sqlite3 and age installed via apt' ($codeText -cmatch 'apt_install_missing [^\n]*\bsqlite3\b[^\n]*\bage\b') 'apt_install_missing ... sqlite3 ... age missing'
    Assert 'pkg-2: vault CLI from the official HashiCorp apt repo (arm64, signed-by, major pinned)' ((Has $codeText 'https://apt.releases.hashicorp.com') -and (Has $codeText 'deb [arch=arm64 signed-by=$HC_KEYRING] https://apt.releases.hashicorp.com noble main') -and (Has $codeText 'Pin: version') -and (Has $codeText 'VAULT_MAJOR=2')) 'hashicorp repo/pin missing'
    Assert 'pkg-3: OCI CLI via pipx (no pip pollution), instance principal only at runtime' ((Has $codeText 'pipx install oci-cli') -and (Has $codeText 'PIPX_HOME_DIR=/opt/pipx') -and (Has $codeText 'export PIPX_HOME="$PIPX_HOME_DIR"') -and (Has $text '--auth instance_principal')) 'pipx oci-cli install (PIPX_HOME_DIR=/opt/pipx, export PIPX_HOME) missing'
    Assert 'pkg-4: NODE_ROLE validated (platform|data) and platform-only gate for vault/oci' ((Has $codeText 'case "${NODE_ROLE:-}" in platform|data)') -and (Has $codeText 'if [ "$NODE_ROLE" = platform ]; then')) 'NODE_ROLE validation/gate missing'
}

# ---------- UU ----------
Test-Group 'uu' {
    Assert 'uu-1: writes 50unattended-upgrades and 20auto-upgrades' ((Has $codeText 'UU_CONF=/etc/apt/apt.conf.d/50unattended-upgrades') -and (Has $codeText 'UU_AUTO=/etc/apt/apt.conf.d/20auto-upgrades')) 'paths missing'
    $sec = @($lines | Where-Object { $_ -cmatch '^\s*"\$\{distro_id\}[A-Za-z]*:\$\{distro_codename\}-[a-z-]*security";' })
    $upd = @($lines | Where-Object { $_ -cmatch '^\s*"\$\{distro_id\}:\$\{distro_codename\}(-updates|-proposed|-backports)?";' })
    Assert 'uu-2: Allowed-Origins are security pockets only (no release/-updates/-proposed/-backports lines)' ($sec.Count -ge 1 -and $upd.Count -eq 0) "security lines=$($sec.Count), non-security lines=$($upd.Count)"
    Assert 'uu-3: APT::Periodic::Unattended-Upgrade "1" and Update-Package-Lists "1"' ((Has $codeText 'APT::Periodic::Unattended-Upgrade "1";') -and (Has $codeText 'APT::Periodic::Update-Package-Lists "1";')) 'periodic settings missing'
}

# ---------- TZ ----------
Test-Group 'tz' {
    Assert 'tz-1: timedatectl set-timezone Asia/Seoul' ((Has $codeText 'TZ_WANT=Asia/Seoul') -and (Has $codeText 'timedatectl set-timezone "$TZ_WANT"')) 'timezone step missing'
}

# ---------- STDIN ----------
Test-Group 'stdin' {
    $nonEmpty = @($lines | Where-Object { $_.Length -gt 0 })
    $last = if ($nonEmpty.Count -gt 0) { $nonEmpty[$nonEmpty.Count - 1] } else { '' }
    Assert 'stdin-1: last line is main "$@" </dev/null; exit (safe under bash -s streaming)' ([string]::Equals($last, 'main "$@" </dev/null; exit', [StringComparison]::Ordinal)) "last line: '$last'"
}

# ---------- SECRET ----------
Test-Group 'secret' {
    $patterns = @(
        '-----BEGIN [A-Z ]*PRIVATE KEY-----',
        'AKIA[0-9A-Z]{16}',
        'hvs\.[A-Za-z0-9]{20,}',
        'ghp_[A-Za-z0-9]{30,}',
        'ssh-rsa AAAA',
        'ssh-ed25519 AAAA',
        'ocid1\.(user|tenancy|key|instance|credential)\.',
        '(?i)(password|passwd|secret|api[_-]?key|token)\s*=\s*[''"][^''"$][^''"]{7,}[''"]',
        '(?i)CLOUDFLARE_API_TOKEN\s*=\s*\S'
    )
    $hits = @()
    foreach ($p in $patterns) { if ($text -cmatch $p) { $hits += $p } }
    Assert 'secret-1: no secret-looking strings (private key blocks, cloud tokens, embedded public keys/OCIDs, literal passwords)' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
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
        Write-Host 'SKIP syntax-1 -- bash -n: no Git/POSIX bash found on this machine (WSL System32 bash is not used); run "bash -n infra/bootstrap/host-prep.sh" where bash exists'
    } else {
        $unixPath = $target -replace '\\', '/'
        $out = & $bash -n $unixPath 2>&1 | Out-String
        $c = $LASTEXITCODE
        Assert "syntax-1: bash -n passes ($bash)" ($c -eq 0) "exit=$c; $($out.Trim())"
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
