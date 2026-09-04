# tests/infra/k3s-server.tests.ps1 — infra/bootstrap/k3s-server.sh 정적 검사 스위트 (T035, test-first)
# Run: pwsh -NoProfile -File tests/infra/k3s-server.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/infra/host-prep.tests.ps1 과 같은 구조). 문자열 비교는 전부 Ordinal.
#
# fail closed: 대상 파일이 없으면 전 단언 FAIL. 유일한 SKIP은 syntax-1(bash -n) — Windows에서 Git bash를 찾지 못하면
# 'SKIP syntax-1 -- ...' 한 줄을 내고 합계(passed/failed)에 넣지 않는다(WSL의 System32\bash.exe는 쓰지 않는다: Windows 경로를 못 읽는다).
# 실행(SSH·노드·K3s 설치)은 하지 않는다 — 이 스위트는 원문만 읽는다. 실행 검증(두 번 실행해 changes this run: 0)은 운영자가 노드 A에서 한다(.claude/rules/infra.md).
#
# 검사 계약(k3s-server.sh 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   FILE   file-1 존재  file-2 첫 줄 '#!/usr/bin/env bash'  file-3 CR 없음(LF only)·끝 개행  file-4 'set -euo pipefail' 한 줄
#   CFG    cfg-1 경로 /etc/rancher/k3s/config.yaml  cfg-2 write-kubeconfig-mode "0600"  cfg-3 token-file: $K3S_TOKEN_FILE(기본 /etc/rancher/k3s/token)
#          cfg-4 tls-san 2개 = "$NODE_PRIVATE_IP"(기본 10.0.7.78) + "$TLS_SAN_HOST"(기본 k8s.joshuatech.dev)
#          cfg-5 node-label 2개 = role=platform + svccontroller.k3s.cattle.io/enablelb=true  cfg-6 secrets-encryption: true
#          cfg-7 secrets-encryption-provider: secretbox  cfg-8 flannel-backend: wireguard-native  cfg-9 write_if_changed ... 600
#          cfg-10 렌더된 최상위 키가 허용 집합(7개)과 정확히 같다(그 외 키 없음)  cfg-11 main 순서 render_config < install_k3s < ensure_service < wait_node_ready
#   FORBID forbid-1 외부 IP 키 없음  forbid-2 번들 컴포넌트 끄기 키/플래그 없음  forbid-3 vxlan 없음  forbid-4 구 호스트명 k3s.joshuatech.dev 없음(파일 전체)
#          forbid-5 채널 설치 없음(INSTALL_K3S_CHANNEL)  forbid-6 curl 파이프 sh 없음  forbid-7 IMDS 조회 없음  forbid-8 클러스터 변경 명령 없음(kubectl은 get만,
#          systemctl restart/stop·k3s-uninstall·tofu 없음)  forbid-9 host-prep 재구성 없음(iptables -A/-I·netfilter-persistent reload·modprobe·set-timezone·apt-get install)
#          forbid-10 셸 트레이싱 없음(set -x·xtrace·bash -x·PS4)
#   TOKEN  tok-1 openssl rand 없음  tok-2 echo … token 없음  tok-3 K3S_TOKEN= 없음  tok-4 토큰 파일 cat/read/$(<) 없음
#          tok-5 토큰 파일 존재·600·root:root·-s 검증 + die  tok-6 보안 형식(K10) 거부  tok-7 한 줄·공백 없음 검증  tok-8 코드에 k3s.yaml 참조 없음
#          tok-9 check_token_file 본문에 값을 읽는 명령(cat/head/tail/od/xxd/hexdump/base64/awk/sed/read) 없음 + 파일 인자 grep 은 -q/-c 뿐
#   VER    ver-1 기본 v1.36.4+k3s1  ver-2 INSTALL_K3S_VERSION="$K3S_VERSION"  ver-3 INSTALL_K3S_EXEC=server 뿐(CLI 인자 없음)
#          ver-4 다른 버전 설치 시 die(system-upgrade-controller 언급)  ver-5 같은 버전 + unit 존재면 설치 skip(return 0이 sh 호출보다 앞)  ver-6 버전 형식 정규식
#   PRE    pre-1 root  pre-2 Ubuntu 24.04 + aarch64  pre-3 cgroup2fs  pre-4 wireguard 모듈·modules-load 검증(modprobe 없음)  pre-5 rules.v4 6443/51820/10250
#          pre-6 Asia/Seoul 검증(set-timezone 없음)  pre-7 ufw 활성 시 die  pre-8 'host-prep.sh 먼저' die ≥ 6  pre-9 NODE_PRIVATE_IP 기본 10.0.7.78 + 로컬 인터페이스 가드
#          pre-10 TLS_SAN_HOST 기본 k8s.joshuatech.dev
#   INST   inst-1 INSTALL_SCRIPT 기본 /tmp/install-k3s.sh + 부재 die + 사본 sanity(#!/bin/sh·verify_binary)  inst-2 INSTALL_SCRIPT_SHA256 선택 대조 + 불일치 die
#          inst-3 env -i 격리 실행 한 줄  inst-4 설치 뒤 버전 재확인 die  inst-5 is-enabled/is-active 가드가 enable --now 보다 앞
#          inst-6 Ready 대기(READY_TIMEOUT=180, k3s kubectl get nodes, $2 ~ /^Ready(,|$)/ — cordon 허용, 초과 die)  inst-7 라벨 확인 die
#          inst-8 secrets-encrypt status Enabled die + provider 표기 XSalsa20|secretbox
#          inst-9 config 변경 + 실행 중이면 warn(재시작 없음)
#   IDEM   idem-1 write_if_changed: cmp -s가 mv보다 앞  idem-2 같은 디렉터리 mktemp -p + mv -f 원자 교체  idem-3 내용 같고 권한만 다르면 권한만 고침
#          idem-4 installed_k3s_version 검사가 sh 호출보다 앞
#   LOG    log-1 '[k3s-server]' 접두 log/warn/die  log-2 'changes this run: %d'  log-3 summary에 installed/want·Ready·changed
#   STDIN  stdin-1 마지막 줄 'main "$@" </dev/null; exit'
#   SECRET secret-1 비밀로 보이는 문자열 없음
#   SYNTAX syntax-1 bash -n (bash 없으면 SKIP)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/k3s-server.sh'

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

$allNames = @('file-1', 'file-2', 'file-3', 'file-4',
    'cfg-1', 'cfg-2', 'cfg-3', 'cfg-4', 'cfg-5', 'cfg-6', 'cfg-7', 'cfg-8', 'cfg-9', 'cfg-10', 'cfg-11',
    'forbid-1', 'forbid-2', 'forbid-3', 'forbid-4', 'forbid-5', 'forbid-6', 'forbid-7', 'forbid-8', 'forbid-9', 'forbid-10',
    'tok-1', 'tok-2', 'tok-3', 'tok-4', 'tok-5', 'tok-6', 'tok-7', 'tok-8', 'tok-9',
    'ver-1', 'ver-2', 'ver-3', 'ver-4', 'ver-5', 'ver-6',
    'pre-1', 'pre-2', 'pre-3', 'pre-4', 'pre-5', 'pre-6', 'pre-7', 'pre-8', 'pre-9', 'pre-10',
    'inst-1', 'inst-2', 'inst-3', 'inst-4', 'inst-5', 'inst-6', 'inst-7', 'inst-8', 'inst-9',
    'idem-1', 'idem-2', 'idem-3', 'idem-4', 'log-1', 'log-2', 'log-3', 'stdin-1', 'secret-1', 'syntax-1')

if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    # fail closed: 파일이 없으면 계약의 단언 전부 FAIL
    foreach ($n in $allNames) { Assert $n $false "missing: infra/bootstrap/k3s-server.sh" }
    Write-Host "`n$($script:pass) passed, $($script:fail) failed"
    exit 1
}

$text = Read-Text $target
$lines = $text -split "`n"
$code = Get-CodeLines $lines
$codeText = ($code -join "`n")

# render_config 의 heredoc(config.yaml 원문) — 없으면 '' (cfg 단언이 전부 FAIL 되게)
$renderBody = Get-FunctionBody $text 'render_config'
$cfg = ''
if ($null -ne $renderBody) {
    $m = [regex]::Match($renderBody, '(?ms)content=\$\(cat <<EOF\n(.*?)\nEOF\n')
    if ($m.Success) { $cfg = $m.Groups[1].Value }
}
$cfgLines = @($cfg -split "`n")
# 최상위 키 → 리스트 항목 파싱(YAML 주석 제외)
$cfgKeys = [ordered]@{}
$curKey = $null
foreach ($l in $cfgLines) {
    if ($l -cmatch '^\s*#' -or $l.Trim().Length -eq 0) { continue }
    if ($l -cmatch '^([a-z][a-z-]*):\s*(.*)$') { $curKey = $Matches[1]; $cfgKeys[$curKey] = @(); if ($Matches[2].Length -gt 0) { $cfgKeys[$curKey] += $Matches[2] }; continue }
    if ($l -cmatch '^  - (.+)$' -and $curKey) { $cfgKeys[$curKey] += $Matches[1]; continue }
    $cfgKeys['__unparsed__'] = @($l)
}
function CfgVal([string]$k) { if ($cfgKeys.Contains($k)) { return @($cfgKeys[$k]) } else { return @() } }

# ---------- FILE ----------
Test-Group 'file' {
    Assert 'file-1: infra/bootstrap/k3s-server.sh exists' $true ''
    Assert 'file-2: first line is #!/usr/bin/env bash' ([string]::Equals($lines[0], '#!/usr/bin/env bash', [StringComparison]::Ordinal)) "first line: '$($lines[0])'"
    Assert 'file-3: LF only (no CR) and ends with newline' ((-not (Has $text "`r")) -and $text.EndsWith("`n", [StringComparison]::Ordinal)) 'CR found or missing final newline (.gitattributes forces LF; bash chokes on CRLF)'
    Assert 'file-4: set -euo pipefail present as a whole line' (@($lines | Where-Object { [string]::Equals($_, 'set -euo pipefail', [StringComparison]::Ordinal) }).Count -ge 1) 'no exact line "set -euo pipefail"'
}

# ---------- CFG ----------
Test-Group 'cfg' {
    Assert 'cfg-1: config path /etc/rancher/k3s/config.yaml' ((Has $codeText 'K3S_CONFIG_DIR=/etc/rancher/k3s') -and (Has $codeText 'K3S_CONFIG="$K3S_CONFIG_DIR/config.yaml"') -and ($cfg.Length -gt 0)) 'path constants or render_config heredoc missing'
    Assert 'cfg-2: write-kubeconfig-mode: "0600"' ((CfgVal 'write-kubeconfig-mode') -contains '"0600"') "write-kubeconfig-mode = $((CfgVal 'write-kubeconfig-mode') -join ',')"
    Assert 'cfg-3: token-file: $K3S_TOKEN_FILE with default /etc/rancher/k3s/token' (((CfgVal 'token-file') -contains '$K3S_TOKEN_FILE') -and (Has $codeText 'K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"')) "token-file = $((CfgVal 'token-file') -join ',')"
    $san = @(CfgVal 'tls-san')
    Assert 'cfg-4: tls-san exactly ["$NODE_PRIVATE_IP", "$TLS_SAN_HOST"] with defaults 10.0.7.78 / k8s.joshuatech.dev' ($san.Count -eq 2 -and $san[0] -eq '"$NODE_PRIVATE_IP"' -and $san[1] -eq '"$TLS_SAN_HOST"' -and (Has $codeText 'NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.7.78}"') -and (Has $codeText 'TLS_SAN_HOST="${TLS_SAN_HOST:-k8s.joshuatech.dev}"')) "tls-san = [$($san -join ', ')]"
    $lbl = @(CfgVal 'node-label')
    Assert 'cfg-5: node-label exactly [role=platform, svccontroller.k3s.cattle.io/enablelb=true]' ($lbl.Count -eq 2 -and $lbl[0] -eq '"role=platform"' -and $lbl[1] -eq '"svccontroller.k3s.cattle.io/enablelb=true"') "node-label = [$($lbl -join ', ')]"
    Assert 'cfg-6: secrets-encryption: true' ((CfgVal 'secrets-encryption') -contains 'true') "secrets-encryption = $((CfgVal 'secrets-encryption') -join ',')"
    Assert 'cfg-7: secrets-encryption-provider: secretbox' ((CfgVal 'secrets-encryption-provider') -contains 'secretbox') "provider = $((CfgVal 'secrets-encryption-provider') -join ',')"
    Assert 'cfg-8: flannel-backend: wireguard-native' ((CfgVal 'flannel-backend') -contains 'wireguard-native') "flannel-backend = $((CfgVal 'flannel-backend') -join ',')"
    Assert 'cfg-9: rendered with write_if_changed "$K3S_CONFIG" "$content" 600' ($null -ne $renderBody -and (Has $renderBody 'write_if_changed "$K3S_CONFIG" "$content" 600')) 'write_if_changed ... 600 call missing'
    $allowed = @('write-kubeconfig-mode', 'token-file', 'tls-san', 'node-label', 'secrets-encryption', 'secrets-encryption-provider', 'flannel-backend')
    $keys = @($cfgKeys.Keys)
    $extra = @($keys | Where-Object { $allowed -notcontains $_ })
    $missing = @($allowed | Where-Object { $keys -notcontains $_ })
    Assert 'cfg-10: rendered top-level keys are exactly the allowed 7 (no extra keys, no unparsed lines)' ($extra.Count -eq 0 -and $missing.Count -eq 0) "extra=[$($extra -join ',')] missing=[$($missing -join ',')]"
    $mb = Get-FunctionBody $text 'main'
    Assert 'cfg-11: main order render_config < install_k3s < ensure_service < wait_node_ready' ($null -ne $mb -and (Idx $mb 'render_config') -ge 0 -and (Idx $mb 'render_config') -lt (Idx $mb 'install_k3s') -and (Idx $mb 'install_k3s') -lt (Idx $mb 'ensure_service') -and (Idx $mb 'ensure_service') -lt (Idx $mb 'wait_node_ready')) 'main missing or order wrong (config must exist before the installer starts k3s)'
}

# ---------- FORBID ----------
Test-Group 'forbid' {
    Assert 'forbid-1: no node-external-ip (code or rendered config)' (-not (Has $codeText 'node-external-ip')) 'K3S-D3: OCI public IP is NAT; ServiceLB externalTrafficPolicy=Local misbehaves'
    Assert 'forbid-2: no "disable" key/flag (bundled components stay)' (($cfg -cnotmatch '(?m)^\s*disable[A-Za-z-]*:') -and (-not (Has $codeText '--disable'))) 'K3S-D3: servicelb/traefik/local-storage/coredns/metrics-server all kept'
    Assert 'forbid-3: no vxlan anywhere' (-not (Has $text 'vxlan')) 'flannel-backend must be wireguard-native (task text overrides the research snippet)'
    Assert 'forbid-4: no stale hostname k3s.joshuatech.dev anywhere' (-not (Has $text 'k3s.joshuatech.dev')) 'tls-san host is k8s.joshuatech.dev (task text; research snippet is stale)'
    Assert 'forbid-5: no INSTALL_K3S_CHANNEL in code (version pinned)' (-not (Has $codeText 'INSTALL_K3S_CHANNEL')) 'K3S-D1: channel resolution is not reproducible'
    Assert 'forbid-6: no curl | sh (installer runs from a reviewed local copy)' (($codeText -cnotmatch 'curl[^\n]*get\.k3s\.io') -and ($codeText -cnotmatch '\|\s*(sudo\s+)?sh\b')) 'curl ... get.k3s.io or "| sh" found in code'
    Assert 'forbid-7: no IMDS lookup (static NODE_PRIVATE_IP)' ((-not (Has $codeText '169.254.169.254')) -and (-not (Has $codeText '/opc/v'))) 'IMDS v1 is off; the private IP is a static input'
    Assert 'forbid-8: no cluster-mutating commands (kubectl only get; no systemctl restart/stop; no k3s-uninstall; no tofu)' (($codeText -cnotmatch 'k3s kubectl (?!get )') -and ($codeText -cnotmatch '(?m)^\s*(k3s\s+)?kubectl\s+(delete|apply|patch|edit|scale|drain|cordon|label|create)\b') -and ($codeText -cnotmatch '(?m)^\s*systemctl\s+(restart|stop)\b') -and (-not (Has $codeText 'k3s-uninstall')) -and ($codeText -cnotmatch '\btofu\b') -and (-not (Has $codeText 'secrets-encrypt rotate'))) 'only install + enable --now may change cluster state'
    # forbid-10: xtrace 는 토큰 파일 경로를 다루는 모든 명령행을 stderr 로 찍는다(비밀 유출 경로) — 어떤 형태로도 켜지 않는다
    Assert 'forbid-10: no shell tracing (set -x / set -o xtrace / bash -x)' (($codeText -cnotmatch '(?m)^\s*set\s+-[a-z]*x') -and (-not (Has $codeText 'xtrace')) -and ($codeText -cnotmatch '\b(bash|sh)\s+-[a-z]*x\b') -and ($codeText -cnotmatch 'PS4=')) 'tracing would echo token-file handling to stderr'
    Assert 'forbid-9: host-prep state is verified, never reconfigured' (($codeText -cnotmatch '\biptables\s+-[AI]\b') -and (-not (Has $codeText 'netfilter-persistent reload')) -and (-not (Has $codeText 'modprobe')) -and (-not (Has $codeText 'timedatectl set-timezone')) -and ($codeText -cnotmatch '\bapt(-get)?\s+install\b') -and ($codeText -cnotmatch '\bufw\s+(allow|deny|enable|default|reject|route|insert)\b')) 'iptables/modules/timezone/packages belong to host-prep.sh'
}

# ---------- TOKEN ----------
Test-Group 'tok' {
    Assert 'tok-1: no openssl rand in code (token is generated on the operator workstation)' (-not (Has $codeText 'openssl rand')) 'the script must not generate the token'
    Assert 'tok-2: no echo ... token line in code' ($codeText -cnotmatch '(?im)echo[^\n]*token') 'token content must never reach stdout/logs'
    Assert 'tok-3: no K3S_TOKEN= env usage' (-not (Has $codeText 'K3S_TOKEN=')) 'K3S_TOKEN would be persisted in k3s.service.env; token-file in config.yaml only'
    Assert 'tok-4: token file is never read into output (no cat/read/$(< of token paths)' (($codeText -cnotmatch 'cat[^\n]*(K3S_TOKEN_FILE|/etc/rancher/k3s/token|server/token)') -and ($codeText -cnotmatch '\$\(<[^\n]*TOKEN') -and ($codeText -cnotmatch '\bread\b[^\n]*<[^\n]*TOKEN')) 'token file content read found'
    $t = Get-FunctionBody $text 'check_token_file'
    Assert 'tok-5: token file checked for existence, mode 600, owner root:root, non-empty (die otherwise)' ($null -ne $t -and (Has $t '[ -f "$f" ] || die') -and (Has $t 'stat -c %a "$f"') -and (Has $t '[ "$mode" = 600 ] || die') -and (Has $t '[ "$owner" = root:root ] || die') -and (Has $t '[ -s "$f" ] || die')) 'check_token_file missing one of the guards'
    Assert 'tok-6: secure-format token (K10...) is rejected' ($null -ne $t -and (Has $t "grep -q '^K10' `"`$f`" || die")) 'first server needs the short-form token (K3S-D5)'
    Assert 'tok-7: single line, no whitespace, >= 32 chars' ($null -ne $t -and (Has $t "grep -c '' `"`$f`"") -and (Has $t '-eq 1 ] || die') -and (Has $t "'^[^[:space:]]{32,}[[:space:]]*$'")) 'line-count / whitespace guard missing'
    Assert 'tok-8: code never references the admin kubeconfig path (k3s.yaml)' (-not (Has $codeText 'k3s.yaml')) 'admin kubeconfig is fetched by the operator only (header procedure)'
    # tok-9: 토큰 파일을 읽어 값을 만들 수 있는 명령이 check_token_file 안에 아예 없어야 한다(로그·디버그 출력으로 새는 경로 차단).
    #        grep 은 허용하되 파일 인자를 받는 호출은 -q/-c(값을 찍지 않는 형태)여야 한다.
    $tokLines = @()
    if ($null -ne $t) { $tokLines = @(($t -split "`n") | Where-Object { $_ -cnotmatch '^\s*#' }) }
    $readCmds = @($tokLines | Where-Object { $_ -cmatch '(?<![-\w])(cat|head|tail|od|xxd|hexdump|base64|awk|sed|read)\s' })
    $badGrep = @($tokLines | Where-Object { $_ -cmatch '\bgrep\b' -and $_ -cmatch '"\$f"|\$K3S_TOKEN_FILE' -and $_ -cnotmatch '\bgrep\s+(-[A-Za-z]*[qc][A-Za-z]*\s)' })
    Assert 'tok-9: check_token_file never reads the token value (no cat/head/tail/od/xxd/hexdump/base64/awk/sed/read; file-arg greps use -q/-c)' ($null -ne $t -and $readCmds.Count -eq 0 -and $badGrep.Count -eq 0) "read-like commands: $($readCmds.Count) [$(($readCmds | ForEach-Object { $_.Trim() }) -join ' | ')]; non -q/-c greps: $($badGrep.Count) [$(($badGrep | ForEach-Object { $_.Trim() }) -join ' | ')]"
}

# ---------- VER ----------
Test-Group 'ver' {
    Assert 'ver-1: K3S_VERSION default v1.36.4+k3s1' (Has $codeText 'K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"') 'version pin missing'
    Assert 'ver-2: installer gets INSTALL_K3S_VERSION="$K3S_VERSION"' (Has $codeText 'INSTALL_K3S_VERSION="$K3S_VERSION"') 'INSTALL_K3S_VERSION not passed from K3S_VERSION'
    # sh 뒤에 올 수 있는 것은 '|| die …' 뿐 — 다른 인자가 붙으면 플래그가 config.yaml 밖으로 샌다
    Assert 'ver-3: INSTALL_K3S_EXEC=server only, no CLI flags (all flags in config.yaml, K3S-D1)' (($codeText -cmatch '(?m)INSTALL_K3S_EXEC=server sh "\$INSTALL_SCRIPT"(\s*\|\|\s*die[^\n]*)?\s*$') -and (-not (Has $codeText 'INSTALL_K3S_EXEC="')) -and ($codeText -cnotmatch 'sh "\$INSTALL_SCRIPT"\s+(?!\|\|)\S')) 'INSTALL_K3S_EXEC must be exactly server and sh gets no extra args'
    $ib = Get-FunctionBody $text 'install_k3s'
    Assert 'ver-4: a different installed version -> die mentioning system-upgrade-controller' ($null -ne $ib -and (Has $ib '[ "$have" != "$K3S_VERSION" ]') -and ($ib -cmatch 'die "[^\n]*system-upgrade-controller')) 'version mismatch must stop (upgrades belong to SUC)'
    Assert 'ver-5: same version + unit present -> installer skipped (return 0 before sh "$INSTALL_SCRIPT")' ($null -ne $ib -and (Has $ib '[ "$have" = "$K3S_VERSION" ] && [ -f "$K3S_UNIT" ]') -and (Has $ib 'return 0') -and ((Idx $ib 'return 0') -lt (Idx $ib 'sh "$INSTALL_SCRIPT"'))) 'skip guard missing or after the installer call'
    Assert 'ver-6: K3S_VERSION format validated (v<maj>.<min>.<patch>+k3s<n>)' (Has $codeText '^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$') 'version regex missing'
}

# ---------- PRE ----------
Test-Group 'pre' {
    $pb = Get-FunctionBody $text 'preflight'
    $hb = Get-FunctionBody $text 'check_host_prep'
    Assert 'pre-1: root check' ($null -ne $pb -and (Has $pb '[ "$(id -u)" -eq 0 ] || die')) 'root guard missing'
    Assert 'pre-2: Ubuntu 24.04 + aarch64 only' ($null -ne $pb -and (Has $pb '[ "${VERSION_ID:-}" = 24.04 ]') -and (Has $pb '[ "$(uname -m)" = aarch64 ] || die')) 'OS/arch guard missing'
    Assert 'pre-3: cgroup v2 check (stat -fc %T /sys/fs/cgroup == cgroup2fs)' ($null -ne $hb -and (Has $hb 'stat -fc %T /sys/fs/cgroup') -and (Has $hb '[ "$fs" = cgroup2fs ] || die')) 'cgroup2fs check missing'
    Assert 'pre-4: wireguard module loaded + modules-load entry verified (no modprobe here)' ($null -ne $hb -and (Has $hb '[ -d /sys/module/wireguard ] || die') -and (Has $hb 'grep -qxF wireguard "$WG_MODULES_CONF"') -and (Has $codeText 'WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf')) 'wireguard verification missing'
    Assert 'pre-5: rules.v4 must already contain 6443/tcp, 51820/udp, 10250/tcp INPUT rules' ($null -ne $hb -and (Has $codeText 'RULES_V4=/etc/iptables/rules.v4') -and (Has $hb '--dport 6443 -j ACCEPT') -and (Has $hb '--dport 51820 -j ACCEPT') -and (Has $hb '--dport 10250 -j ACCEPT') -and (Has $hb 'grep -qE "^-A INPUT -s [0-9./]+ $p\$" "$RULES_V4" || die')) 'rules.v4 verification missing'
    Assert 'pre-6: timezone Asia/Seoul verified, never set' ($null -ne $hb -and (Has $codeText 'TZ_WANT=Asia/Seoul') -and (Has $hb 'timedatectl show -p Timezone --value') -and (Has $hb '= "$TZ_WANT" ] || die')) 'timezone verification missing'
    Assert 'pre-7: ufw active -> die' ($null -ne $hb -and (Has $hb '"Status: active"') -and ($hb -cmatch 'Status: active"[^\n]*\n\s*die ')) 'ufw guard missing'
    $n = ([regex]::Matches($codeText, 'host-prep\.sh 먼저')).Count
    Assert 'pre-8: at least 6 "host-prep.sh 먼저" die messages' ($n -ge 6) "found $n"
    Assert 'pre-9: NODE_PRIVATE_IP default 10.0.7.78 and must be a local interface address (node A guard)' ($null -ne $pb -and (Has $codeText 'NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.7.78}"') -and (Has $pb 'ip -4 -o addr show') -and (Has $pb 'grep -qxF -- "$NODE_PRIVATE_IP" <<< "$addrs" || die') -and (Has $pb '노드 A 전용')) 'local-address guard missing'
    Assert 'pre-10: TLS_SAN_HOST default k8s.joshuatech.dev and validated as a hostname' ((Has $codeText 'TLS_SAN_HOST="${TLS_SAN_HOST:-k8s.joshuatech.dev}"') -and ($null -ne $pb) -and (Has $pb '"$TLS_SAN_HOST" =~')) 'TLS_SAN_HOST default/validation missing'
}

# ---------- INST ----------
Test-Group 'inst' {
    $cb = Get-FunctionBody $text 'check_install_script'
    $ib = Get-FunctionBody $text 'install_k3s'
    $sb = Get-FunctionBody $text 'ensure_service'
    $wb = Get-FunctionBody $text 'wait_node_ready'
    Assert 'inst-1: INSTALL_SCRIPT default /tmp/install-k3s.sh; missing -> die; copy sanity (#!/bin/sh, verify_binary)' ((Has $codeText 'INSTALL_SCRIPT="${INSTALL_SCRIPT:-/tmp/install-k3s.sh}"') -and ($null -ne $cb) -and (Has $cb '[ -f "$f" ] || die') -and (Has $cb "'#!/bin/sh'") -and (Has $cb "grep -q 'verify_binary'")) 'install script guard missing'
    Assert 'inst-2: optional INSTALL_SCRIPT_SHA256 compared with sha256sum, mismatch -> die' ($null -ne $cb -and (Has $cb 'sha256sum "$f"') -and (Has $cb '${INSTALL_SCRIPT_SHA256:-}') -and (Has $cb '[ "$have" = "$want" ] || die')) 'sha256 verification missing'
    Assert 'inst-3: installer runs isolated (env -i ... INSTALL_K3S_EXEC=server sh "$INSTALL_SCRIPT") and a non-zero exit dies' ($null -ne $ib -and ($ib -cmatch '(?m)^\s*env -i PATH="\$PATH" HOME=/root INSTALL_K3S_VERSION="\$K3S_VERSION" INSTALL_K3S_EXEC=server sh "\$INSTALL_SCRIPT" \|\| die "[^\n]*\$\?[^\n]*"\s*$')) 'env -i invocation line missing, or the installer failure is not turned into a die with $?'
    Assert 'inst-4: version re-checked after install (die on mismatch)' ($null -ne $ib -and ((Idx $ib 'sh "$INSTALL_SCRIPT"') -lt (Idx $ib '[ "$have" = "$K3S_VERSION" ] || die'))) 'post-install version check missing'
    Assert 'inst-5: is-enabled/is-active read before systemctl enable --now k3s' ($null -ne $sb -and (Has $sb 'systemctl is-enabled k3s') -and (Has $sb 'systemctl is-active k3s') -and (Has $sb 'systemctl enable --now k3s') -and ((Idx $sb 'systemctl is-enabled k3s') -lt (Idx $sb 'systemctl enable --now k3s')) -and ((Idx $sb 'systemctl is-active k3s') -lt (Idx $sb 'systemctl enable --now k3s'))) 'service guard missing or after enable'
    # STATUS 열은 cordon 시 'Ready,SchedulingDisabled' 가 되므로 정확 일치(== "Ready")가 아니라 접두 매칭이어야 한다
    Assert 'inst-6: node Ready wait: READY_TIMEOUT=180, k3s kubectl get nodes, $2 ~ /^Ready(,|$)/ (cordon-tolerant), timeout -> die' ((Has $codeText 'READY_TIMEOUT=180') -and ($null -ne $wb) -and (Has $wb 'READY_TIMEOUT / 5') -and (Has $wb 'k3s kubectl get nodes --no-headers') -and (Has $wb '$2 ~ /^Ready(,|$)/') -and (-not (Has $wb '$2 == "Ready"')) -and (Has $wb '[ "$ready" = 1 ] || die')) 'Ready wait missing or exact-match Ready (cordoned node would be missed)'
    $lb = Get-FunctionBody $text 'check_labels'
    Assert 'inst-7: labels role=platform + enablelb verified on a node (die otherwise)' ($null -ne $lb -and (Has $lb "-l 'role=platform,svccontroller.k3s.cattle.io/enablelb=true'") -and (Has $lb '-ge 1 ] || die')) 'label check missing'
    $eb = Get-FunctionBody $text 'check_secrets_encryption'
    # provider 표기: v1.36 의 status 는 키 타입을 XSalsa20-POLY1305 로 적는다 — secretbox 문자열만 찾으면 정상 클러스터에서 오탐 warn 이 난다
    Assert 'inst-8: k3s secrets-encrypt status must report Enabled (die otherwise) and accept XSalsa20|secretbox as the provider marker' ($null -ne $eb -and (Has $eb 'k3s secrets-encrypt status') -and (Has $eb "'^Encryption Status: Enabled'") -and ($eb -cmatch 'Encryption Status: Enabled[^\n]*\|\| die') -and (Has $eb "grep -qiE 'XSalsa20|secretbox'")) 'secrets-encryption verification missing or provider marker not XSalsa20|secretbox'
    Assert 'inst-9: config changed while k3s already running -> warn only (no restart)' ($null -ne $sb -and (Has $sb 'CONFIG_CHANGED') -and (Has $sb 'INSTALLED_THIS_RUN') -and ($sb -cmatch '(?m)^\s*warn ') -and (-not (Has $codeText 'systemctl restart'))) 'warn branch missing or restart present'
}

# ---------- IDEM ----------
Test-Group 'idem' {
    $b = Get-FunctionBody $text 'write_if_changed'
    Assert 'idem-1: write_if_changed compares with cmp -s before mv' ($null -ne $b -and (Has $b 'cmp -s') -and ((Idx $b 'cmp -s') -lt (Idx $b 'mv -f "$tmp" "$path"'))) 'cmp -s guard missing'
    Assert 'idem-2: same-directory mktemp -p + mv -f atomic replace (no cat > overwrite)' ($null -ne $b -and (Has $b 'mktemp -p "$dir"') -and (Has $b 'mv -f "$tmp" "$path"') -and (-not (Has $codeText 'cat "$tmp" >'))) 'atomic replace missing'
    Assert 'idem-3: same content but wrong mode -> only mode fixed (stat/chmod inside the unchanged branch)' ($null -ne $b -and (Has $b 'stat -c %a "$path"') -and (Has $b 'chmod "$mode" "$path"') -and ((Idx $b 'cmp -s') -lt (Idx $b 'stat -c %a "$path"')) -and ((Idx $b 'stat -c %a "$path"') -lt (Idx $b 'return 0'))) 'mode fix branch missing'
    $ib = Get-FunctionBody $text 'install_k3s'
    Assert 'idem-4: installed_k3s_version is consulted before the installer runs' ($null -ne $ib -and (Has $ib 'have=$(installed_k3s_version)') -and ((Idx $ib 'have=$(installed_k3s_version)') -lt (Idx $ib 'sh "$INSTALL_SCRIPT"'))) 'install guard missing'
}

# ---------- LOG ----------
Test-Group 'log' {
    Assert 'log-1: [k3s-server] prefixed log/warn/die helpers' ((Has $codeText "printf '[k3s-server] %s\n'") -and (Has $codeText "printf '[k3s-server] WARN: %s\n'") -and (Has $codeText "printf '[k3s-server] ERROR: %s\n'")) 'log helpers missing'
    Assert 'log-2: summary prints changes this run: N' (Has $codeText "printf 'changes this run: %d\n' `"`${#CHANGES[@]}`"") 'changes summary missing'
    $s = Get-FunctionBody $text 'summary'
    Assert 'log-3: summary shows installed/want version, node Ready count, config changed flag' ($null -ne $s -and (Has $s 'installed=%s want=%s') -and (Has $s 'Ready=%s') -and (Has $s 'changed=%s')) 'summary fields missing'
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
        '(?i)CLOUDFLARE_API_TOKEN\s*=\s*\S',
        'K10[0-9a-f]{20,}::',
        '(?m)^[0-9a-f]{64}$'
    )
    $hits = @()
    foreach ($p in $patterns) { if ($text -cmatch $p) { $hits += $p } }
    Assert 'secret-1: no secret-looking strings (private key blocks, cloud tokens, embedded keys/OCIDs, literal passwords, K10 tokens, bare 64-hex)' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
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
        Write-Host 'SKIP syntax-1 -- bash -n: no Git/POSIX bash found on this machine (WSL System32 bash is not used); run "bash -n infra/bootstrap/k3s-server.sh" where bash exists'
    } else {
        $unixPath = $target -replace '\\', '/'
        $out = & $bash -n $unixPath 2>&1 | Out-String
        $c = $LASTEXITCODE
        Assert "syntax-1: bash -n passes ($bash)" ($c -eq 0) "exit=$c; $($out.Trim())"
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
